using GLib;
using Soup;
using Json;
using Imladris.Core;

namespace Imladris.AI {

    /**
     * ElrondEngineController
     *
     * Smart Local AI Server & Agent Harness Bridge.
     * Connects Imladris to running local inference servers (Ollama, LM Studio,
     * Cherry Studio, LocalAI, llama-server) and local agent harnesses (Antigravity agy,
     * OpenCode, OpenClaude, Pi).
     *
     * Eliminates container exit 127 crashes by relying on standard localhost HTTP
     * endpoints and host-managed agent harnesses instead of fragile in-container
     * process spawning.
     */
    public class ElrondEngineController : GLib.Object {
        private static ElrondEngineController? _instance;

        private Soup.Session soup_session;
        private Cancellable? probe_cancellable = null;

        public signal void status_updated (string status_text, bool is_busy, double progress_fraction);
        public signal void statusbar_telemetry_updated (string statusbar_text, bool active);

        public bool is_ready { get; private set; default = false; }
        public ElrondMode active_mode { get; private set; default = ElrondMode.AUTO_DETECT; }
        public string active_endpoint { get; private set; default = ""; }
        public string active_model_name { get; private set; default = ""; }
        public string active_display_name { get; private set; default = "Local AI"; }

        private ElrondEngineController () {
            soup_session = new Soup.Session () {
                idle_timeout = 30,
                timeout = 45
            };

            SettingsManager.get_default ().ai_settings_changed.connect (() => {
                sync_with_preferences.begin ();
            });

            if (SettingsManager.get_default ().elrond_enabled) {
                sync_with_preferences.begin ();
            }
        }

        public static ElrondEngineController get_default () {
            if (_instance == null) {
                _instance = new ElrondEngineController ();
            }
            return _instance;
        }

        public async void sync_with_preferences () {
            var settings = SettingsManager.get_default ();

            if (!settings.elrond_enabled) {
                stop_daemon ();
                status_updated ("Elrond Assistance Disabled", false, 0.0);
                statusbar_telemetry_updated ("Elrond AI: Off", false);
                return;
            }

            yield probe_servers_async ();
        }

        public void stop_daemon () {
            is_ready = false;
            active_endpoint = "";
            active_model_name = "";
            active_display_name = "Local AI";
            if (probe_cancellable != null) {
                probe_cancellable.cancel ();
                probe_cancellable = null;
            }
        }

        /**
         * Probes localhost for available AI engines and agent harnesses.
         */
        public async void probe_servers_async () {
            var settings = SettingsManager.get_default ();
            var mode = settings.elrond_mode;

            status_updated ("Probing local AI servers & agent harnesses...", true, 0.2);
            statusbar_telemetry_updated ("Elrond: Probing local servers...", true);

            bool connected = false;

            if (mode == ElrondMode.AUTO_DETECT) {
                // Priority 1: Ollama
                connected = yield probe_ollama_async ();

                // Priority 2: LM Studio
                if (!connected) {
                    connected = yield probe_lm_studio_async ();
                }

                // Priority 3: Cherry Studio / LocalAI (ports 23333 and 8080)
                if (!connected) {
                    connected = yield probe_cherry_or_localai_async ();
                }

                // Priority 4: Antigravity CLI (agy agent harness)
                if (!connected) {
                    connected = yield probe_antigravity_async ();
                }
            } else if (mode == ElrondMode.OLLAMA) {
                connected = yield probe_ollama_async ();
            } else if (mode == ElrondMode.LM_STUDIO) {
                connected = yield probe_lm_studio_async ();
            } else if (mode == ElrondMode.CHERRY_STUDIO) {
                connected = yield probe_cherry_or_localai_async ();
            } else if (mode == ElrondMode.ANTIGRAVITY) {
                connected = yield probe_antigravity_async ();
            } else if (mode == ElrondMode.CUSTOM) {
                connected = yield probe_custom_async (settings.custom_local_endpoint);
            }

            if (connected) {
                is_ready = true;
                settings.active_model_name = active_model_name;
                status_updated ("Connected to %s (%s)".printf (active_display_name, active_model_name), false, 1.0);
                statusbar_telemetry_updated ("Elrond Bridge: %s (%s) • Ready".printf (active_display_name, active_model_name), true);
            } else {
                is_ready = false;
                status_updated ("No local AI server found. Start Ollama, LM Studio, Cherry Studio, or Antigravity (agy).", false, 0.0);
                statusbar_telemetry_updated ("Elrond: Offline (No local AI server)", false);
            }
        }

        private async bool probe_ollama_async () {
            string detected_model = "";
            bool ok = yield probe_http_endpoint_async ("http://127.0.0.1:11434/api/tags", out detected_model);
            if (!ok) {
                ok = yield probe_http_endpoint_async ("http://127.0.0.1:11434/v1/models", out detected_model);
            }
            if (ok) {
                active_mode = ElrondMode.OLLAMA;
                active_display_name = "Ollama";
                active_endpoint = "http://127.0.0.1:11434/v1";
                active_model_name = (detected_model.length > 0) ? detected_model : "qwen2.5-coder:latest";
                return true;
            }
            return false;
        }

        private async bool probe_lm_studio_async () {
            string detected_model = "";
            bool ok = yield probe_http_endpoint_async ("http://127.0.0.1:1234/v1/models", out detected_model);
            if (ok) {
                active_mode = ElrondMode.LM_STUDIO;
                active_display_name = "LM Studio";
                active_endpoint = "http://127.0.0.1:1234/v1";
                active_model_name = (detected_model.length > 0) ? detected_model : "default";
                return true;
            }
            return false;
        }

        private async bool probe_cherry_or_localai_async () {
            string detected_model = "";
            // Check Cherry Studio default port 23333
            bool ok = yield probe_http_endpoint_async ("http://127.0.0.1:23333/v1/models", out detected_model);
            if (ok) {
                active_mode = ElrondMode.CHERRY_STUDIO;
                active_display_name = "Cherry Studio";
                active_endpoint = "http://127.0.0.1:23333/v1";
                active_model_name = (detected_model.length > 0) ? detected_model : "default";
                return true;
            }

            // Check LocalAI / standard llama-server port 8080
            ok = yield probe_http_endpoint_async ("http://127.0.0.1:8080/v1/models", out detected_model);
            if (ok) {
                active_mode = ElrondMode.CHERRY_STUDIO;
                active_display_name = "LocalAI / llama-server";
                active_endpoint = "http://127.0.0.1:8080/v1";
                active_model_name = (detected_model.length > 0) ? detected_model : "default";
                return true;
            }
            return false;
        }

        private async bool probe_antigravity_async () {
            string? agy_bin = find_agy_binary ();
            if (agy_bin != null) {
                string ver = yield get_agy_version_async (agy_bin);
                if (ver.length > 0) {
                    active_mode = ElrondMode.ANTIGRAVITY;
                    active_display_name = "Antigravity CLI (agy)";
                    active_endpoint = "local://agy";
                    active_model_name = @"agy $ver";
                    return true;
                }
            }
            return false;
        }

        private async bool probe_custom_async (string custom_endpoint) {
            string ep = custom_endpoint.strip ();
            if (ep.has_suffix ("/")) {
                ep = ep.substring (0, ep.length - 1);
            }
            string models_url = ep.has_suffix ("/v1") ? ep + "/models" : ep + "/v1/models";
            string detected_model = "";
            bool ok = yield probe_http_endpoint_async (models_url, out detected_model);
            if (ok) {
                active_mode = ElrondMode.CUSTOM;
                active_display_name = "Custom Local Server";
                active_endpoint = ep;
                active_model_name = (detected_model.length > 0) ? detected_model : "default";
                return true;
            }
            return false;
        }

        private async bool probe_http_endpoint_async (string url, out string detected_model) {
            detected_model = "";
            try {
                var msg = new Soup.Message ("GET", url);
                var cancellable = new Cancellable ();

                // Set a 2-second probe deadline to avoid delaying startup
                Timeout.add (2000, () => {
                    cancellable.cancel ();
                    return Source.REMOVE;
                });

                Bytes bytes = yield soup_session.send_and_read_async (msg, Priority.DEFAULT, cancellable);
                if (msg.status_code == Soup.Status.OK && bytes != null) {
                    detected_model = extract_model_from_json (bytes);
                    return true;
                }
            } catch (Error e) {}
            return false;
        }

        private static string extract_model_from_json (Bytes bytes) {
            try {
                var parser = new Json.Parser ();
                parser.load_from_data ((string) bytes.get_data (), -1);
                var root = parser.get_root ();
                if (root == null || root.get_node_type () != Json.NodeType.OBJECT) {
                    return "";
                }
                var obj = root.get_object ();

                // Ollama /api/tags format: {"models": [{"name": "qwen2.5-coder:latest"}]}
                if (obj.has_member ("models")) {
                    var arr = obj.get_array_member ("models");
                    if (arr.get_length () > 0) {
                        var first = arr.get_object_element (0);
                        if (first.has_member ("name")) {
                            return first.get_string_member ("name");
                        }
                    }
                }

                // OpenAI /v1/models format: {"data": [{"id": "model-id"}]}
                if (obj.has_member ("data")) {
                    var arr = obj.get_array_member ("data");
                    if (arr.get_length () > 0) {
                        var first = arr.get_object_element (0);
                        if (first.has_member ("id")) {
                            return first.get_string_member ("id");
                        }
                    }
                }
            } catch (Error e) {}
            return "";
        }

        /**
         * Resolves the Antigravity CLI binary on the host or system.
         */
        public static string? find_agy_binary () {
            string home_agy = GLib.Path.build_filename (Environment.get_home_dir (), ".local", "bin", "agy");
            if (FileUtils.test (home_agy, FileTest.IS_EXECUTABLE)) {
                return home_agy;
            }

            string? in_path = Environment.find_program_in_path ("agy");
            if (in_path != null && FileUtils.test (in_path, FileTest.IS_EXECUTABLE)) {
                return in_path;
            }

            string[] paths = { "/usr/local/bin/agy", "/usr/bin/agy" };
            foreach (var p in paths) {
                if (FileUtils.test (p, FileTest.IS_EXECUTABLE)) return p;
            }

            if (PlatformUtils.is_flatpak ()) {
                string? resolved = null;
                string? env_pfx = null;
                var source = PlatformUtils.resolve_runtime ("agy", null, out resolved, out env_pfx);
                if ((source == RuntimeSource.HOST_FLATPAK_SPAWN || source == RuntimeSource.HOST_NATIVE) && resolved != null) {
                    return resolved;
                }
            }
            return null;
        }

        private static async string get_agy_version_async (string agy_bin) {
            try {
                string[] argv;
                if (PlatformUtils.is_flatpak ()) {
                    argv = { "flatpak-spawn", "--host", agy_bin, "--version" };
                } else {
                    argv = { agy_bin, "--version" };
                }

                var launcher = new SubprocessLauncher (SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_SILENCE);
                var proc = launcher.spawnv (argv);

                string stdout_buf;
                yield proc.communicate_utf8_async (null, null, out stdout_buf, null);
                if (proc.get_if_exited () && proc.get_exit_status () == 0) {
                    return stdout_buf.strip ();
                }
            } catch (Error e) {}
            return "";
        }

        /**
         * Runs a non-interactive prompt via the Antigravity CLI harness (`agy -p`).
         */
        public static async string run_agy_prompt_async (string prompt, Cancellable? cancellable = null) throws GLib.Error {
            string? agy_bin = find_agy_binary ();
            if (agy_bin == null) {
                throw new GLib.IOError.NOT_FOUND ("Antigravity CLI (agy) not found in system or ~/.local/bin");
            }

            string[] argv;
            if (PlatformUtils.is_flatpak ()) {
                argv = { "flatpak-spawn", "--host", agy_bin, "-p", prompt, "--disable-slash-commands" };
            } else {
                argv = { agy_bin, "-p", prompt, "--disable-slash-commands" };
            }

            var launcher = new SubprocessLauncher (SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE);
            var proc = launcher.spawnv (argv);

            string stdout_buf;
            string stderr_buf;
            yield proc.communicate_utf8_async (null, cancellable, out stdout_buf, out stderr_buf);

            if (!proc.get_if_exited () || proc.get_exit_status () != 0) {
                string err_msg = stderr_buf.strip ().length > 0 ? stderr_buf.strip () : "Process exited with code %d".printf (proc.get_exit_status ());
                throw new GLib.IOError.FAILED ("Antigravity (agy) error: %s", err_msg);
            }

            return stdout_buf.strip ();
        }

        /**
         * Core "Write with Elrond Assistance (AI)" inference call.
         */
        public async string write_with_elrond (
            string active_language,
            string document_narrative,
            string dataframe_schemas,
            string current_code
        ) throws Error {
            if (!is_ready) {
                throw new IOError.NOT_CONNECTED ("No local AI server or agent harness is connected. Please start Ollama, LM Studio, Cherry Studio, or Antigravity (agy).");
            }

            var level = SettingsManager.get_default ().elrond_level;

            string system_prompt = """You are Elrond, the built-in local AI coding and data analysis assistant inside Imladris IDE.
You specialize in R (tidyverse, ggplot2, biostatistics), Python (pandas, numpy, scipy, matplotlib, seaborn), SQL, HTML, and Quarto/RMarkdown scientific reports.
Analyze the report narrative and active dataframe columns to suggest the optimal statistical graph, model function, or clean executable code chunk.""";

            string user_context;
            if (level == AiAssistanceLevel.LOW) {
                user_context = "[Language: %s]\n[Code]:\n%s".printf (active_language, current_code);
            } else if (level == AiAssistanceLevel.MEDIUM) {
                user_context = "[Language: %s]\n[Active Dataframes]:\n%s\n[Current Chunk]:\n%s".printf (
                    active_language, dataframe_schemas, current_code
                );
            } else {
                user_context = "[Language: %s]\n[Report Topic & Narrative]:\n%s\n[Active Dataframes & Columns]:\n%s\n[Current Chunk]:\n%s\nWrite or suggest the optimal code, statistical function, or visualization for this report.".printf (
                    active_language, document_narrative, dataframe_schemas, current_code
                );
            }

            if (active_mode == ElrondMode.ANTIGRAVITY) {
                string full_prompt = system_prompt + "\n\n" + user_context;
                return yield run_agy_prompt_async (full_prompt);
            }

            var builder = new Json.Builder ();
            builder.begin_object ();
            builder.set_member_name ("model");
            builder.add_string_value (active_model_name.length > 0 ? active_model_name : "default");
            builder.set_member_name ("temperature");
            builder.add_double_value (0.15);
            builder.set_member_name ("max_tokens");
            builder.add_int_value (level.get_max_tokens ());
            builder.set_member_name ("messages");
            builder.begin_array ();

            builder.begin_object ();
            builder.set_member_name ("role");
            builder.add_string_value ("system");
            builder.set_member_name ("content");
            builder.add_string_value (system_prompt);
            builder.end_object ();

            builder.begin_object ();
            builder.set_member_name ("role");
            builder.add_string_value ("user");
            builder.set_member_name ("content");
            builder.add_string_value (user_context);
            builder.end_object ();

            builder.end_array ();
            builder.end_object ();

            var gen = new Json.Generator ();
            gen.set_root (builder.get_root ());
            string payload = gen.to_data (null);

            string completions_url = active_endpoint.has_suffix ("/chat/completions")
                ? active_endpoint
                : active_endpoint + "/chat/completions";

            var msg = new Soup.Message ("POST", completions_url);
            msg.set_request_body_from_bytes ("application/json", new Bytes (payload.data));

            Bytes bytes = yield soup_session.send_and_read_async (msg, Priority.DEFAULT, null);
            if (msg.status_code != Soup.Status.OK) {
                throw new IOError.FAILED ("Local AI server error (HTTP %u: %s)", msg.status_code, msg.reason_phrase);
            }

            var parser = new Json.Parser ();
            yield parser.load_from_stream_async (new MemoryInputStream.from_bytes (bytes), null);

            var root = parser.get_root ();
            if (root == null || root.get_node_type () != Json.NodeType.OBJECT) {
                throw new IOError.INVALID_DATA ("Invalid JSON returned by local AI engine");
            }

            var root_obj = root.get_object ();
            if (root_obj.has_member ("error")) {
                var err_node = root_obj.get_member ("error");
                string detail = "Unknown error";
                if (err_node.get_node_type () == Json.NodeType.OBJECT) {
                    var err_obj = err_node.get_object ();
                    if (err_obj.has_member ("message")) detail = err_obj.get_string_member ("message");
                } else if (err_node.get_node_type () == Json.NodeType.VALUE) {
                    detail = err_node.get_string ();
                }
                throw new IOError.FAILED ("Local AI Error: %s", detail);
            }

            if (!root_obj.has_member ("choices")) {
                throw new IOError.INVALID_DATA ("No 'choices' returned in response");
            }

            var choices = root_obj.get_array_member ("choices");
            if (choices.get_length () == 0) return "";

            var first_choice = choices.get_object_element (0);
            if (!first_choice.has_member ("message")) return "";

            var message_obj = first_choice.get_object_member ("message");
            if (!message_obj.has_member ("content")) return "";

            return message_obj.get_string_member ("content");
        }

        private static string clean_completion_output (string raw) {
            string text = raw.strip ();
            if (text.has_prefix ("```")) {
                int first_nl = text.index_of ("\n");
                if (first_nl != -1) {
                    text = text.substring (first_nl + 1);
                }
                if (text.has_suffix ("```")) {
                    text = text.substring (0, text.length - 3);
                }
            }
            return text.strip ();
        }

        public async string complete_code_async (
            string prefix,
            string suffix,
            string language = "",
            Cancellable? cancellable = null
        ) throws Error {
            if (!is_ready) {
                throw new IOError.NOT_CONNECTED ("Local AI engine is not running.");
            }

            if (active_mode == ElrondMode.ANTIGRAVITY) {
                string p = "You are an expert AI code completion engine for %s. Return ONLY the code continuation to fill at the cursor. Do not wrap in markdown quotes, backticks, or conversational text.\n[PREFIX]\n%s\n[CURSOR]\n%s\n[COMPLETION]".printf (
                    language.length > 0 ? language : "code", prefix, suffix
                );
                string res = yield run_agy_prompt_async (p, cancellable);
                return clean_completion_output (res);
            }

            string system_prompt = "You are an expert AI code completion engine for %s. Return ONLY the code continuation to fill at the cursor. Do not wrap in markdown quotes, backticks, or conversational text.".printf (language.length > 0 ? language : "R, Python, and SQL");
            string user_prompt = "[PREFIX]\n%s\n[CURSOR]\n%s\n[COMPLETION]".printf (prefix, suffix);

            var builder = new Json.Builder ();
            builder.begin_object ();
            builder.set_member_name ("model");
            builder.add_string_value (active_model_name.length > 0 ? active_model_name : "default");
            builder.set_member_name ("temperature");
            builder.add_double_value (0.1);
            builder.set_member_name ("max_tokens");
            builder.add_int_value (128);
            builder.set_member_name ("messages");
            builder.begin_array ();

            builder.begin_object ();
            builder.set_member_name ("role");
            builder.add_string_value ("system");
            builder.set_member_name ("content");
            builder.add_string_value (system_prompt);
            builder.end_object ();

            builder.begin_object ();
            builder.set_member_name ("role");
            builder.add_string_value ("user");
            builder.set_member_name ("content");
            builder.add_string_value (user_prompt);
            builder.end_object ();

            builder.end_array ();
            builder.end_object ();

            var gen = new Json.Generator ();
            gen.set_root (builder.get_root ());
            string payload = gen.to_data (null);

            string completions_url = active_endpoint.has_suffix ("/chat/completions")
                ? active_endpoint
                : active_endpoint + "/chat/completions";

            var msg = new Soup.Message ("POST", completions_url);
            msg.set_request_body_from_bytes ("application/json", new Bytes (payload.data));

            Bytes bytes = yield soup_session.send_and_read_async (msg, Priority.DEFAULT, cancellable);
            var parser = new Json.Parser ();
            yield parser.load_from_stream_async (new MemoryInputStream.from_bytes (bytes), cancellable);

            var root = parser.get_root ();
            if (root == null || root.get_node_type () != Json.NodeType.OBJECT) {
                return "";
            }

            var root_obj = root.get_object ();
            if (!root_obj.has_member ("choices")) return "";

            var choices = root_obj.get_array_member ("choices");
            if (choices.get_length () == 0) return "";

            var choice = choices.get_object_element (0);
            if (!choice.has_member ("message")) return "";

            var message = choice.get_object_member ("message");
            if (!message.has_member ("content")) return "";

            return clean_completion_output (message.get_string_member ("content"));
        }

        // =========================================================================
        // Compatibility & Utility Methods (Preserved for unit test suites & tools)
        // =========================================================================

        public static bool is_binary_runnable (string bin_path, bool on_host = false) {
            try {
                string[] argv;
                if (on_host && PlatformUtils.is_flatpak ()) {
                    argv = { "flatpak-spawn", "--host", bin_path, "--version" };
                } else {
                    argv = { bin_path, "--version" };
                }

                var launcher = new SubprocessLauncher (SubprocessFlags.STDOUT_SILENCE | SubprocessFlags.STDERR_SILENCE);
                var proc = launcher.spawnv (argv);
                proc.wait (null);
                return (proc.get_if_exited () && proc.get_exit_status () == 0);
            } catch (Error e) {
                return false;
            }
        }

        public static string? find_llama_server_binary (ElrondBackend backend = ElrondBackend.VULKAN, out bool is_host = null) {
            is_host = false;
            string? in_path = Environment.find_program_in_path ("llama-server");
            if (in_path != null && is_binary_runnable (in_path, false)) {
                return in_path;
            }
            if (PlatformUtils.is_flatpak ()) {
                string? resolved = null;
                string? env_pfx = null;
                var source = PlatformUtils.resolve_runtime ("llama-server", null, out resolved, out env_pfx);
                if (source == RuntimeSource.HOST_FLATPAK_SPAWN && resolved != null && is_binary_runnable (resolved, true)) {
                    is_host = true;
                    return resolved;
                }
            }
            return null;
        }

        public async bool auto_install_llama_server (ElrondBackend backend = ElrondBackend.VULKAN) {
            status_updated ("Internal llama-server downloading deprecated. Use Ollama, LM Studio, or Cherry Studio instead.", false, 0.0);
            return false;
        }
    }
}
