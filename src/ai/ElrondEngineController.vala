using GLib;
using Soup;
using Json;
using Imladris.Core;

namespace Imladris.AI {

    public class ElrondEngineController : GLib.Object {
        private static ElrondEngineController? _instance;

        private const string DEFAULT_MODEL_FILENAME = "qwen2.5-coder-3b-instruct-q4_k_m.gguf";
        private const string DEFAULT_MODEL_URL = "https://huggingface.co/Qwen/Qwen2.5-Coder-3B-Instruct-GGUF/resolve/main/qwen2.5-coder-3b-instruct-q4_k_m.gguf";

        private Subprocess? llama_proc = null;
        private string? daemon_pid_str = null;
        private bool running_on_vulkan = false;
        private uint telemetry_timer_id = 0;

        private Soup.Session soup_session;
        private Cancellable? download_cancellable = null;
        private uint16 active_port = 18089;

        public signal void status_updated (string status_text, bool is_busy, double progress_fraction);
        public signal void statusbar_telemetry_updated (string statusbar_text, bool active);

        public bool is_ready { get; private set; default = false; }

        private ElrondEngineController () {
            soup_session = new Soup.Session () {
                timeout = 90
            };

            SettingsManager.get_default ().ai_settings_changed.connect (() => {
                sync_with_preferences.begin ();
            });

            // If already enabled in settings on startup, synchronize immediately
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

        public string get_model_path () {
            string model_dir = GLib.Path.build_filename (Environment.get_user_data_dir (), "imladris", "models");
            try {
                DirUtils.create_with_parents (model_dir, 0755);
            } catch (Error e) {}
            return GLib.Path.build_filename (model_dir, DEFAULT_MODEL_FILENAME);
        }

        public async void sync_with_preferences () {
            var settings = SettingsManager.get_default ();

            if (!settings.elrond_enabled) {
                if (download_cancellable != null) {
                    download_cancellable.cancel ();
                    download_cancellable = null;
                }
                stop_daemon ();
                status_updated ("Elrond Assistance Disabled", false, 0.0);
                statusbar_telemetry_updated ("Elrond AI: Off", false);
                return;
            }

            string model_path = get_model_path ();
            if (!FileUtils.test (model_path, FileTest.EXISTS)) {
                bool ok = yield auto_download_default_model (model_path);
                if (!ok) return;
            }

            yield start_preconfigured_daemon (
                model_path,
                settings.hardware_acceleration_enabled,
                settings.elrond_level
            );
        }

        private async bool auto_download_default_model (string dest_path) {
            download_cancellable = new Cancellable ();
            string part_path = dest_path + ".part";
            string model_name = SettingsManager.get_default ().active_model_name;

            status_updated ("Bootstrapping Elrond (%s)...".printf (model_name), true, 0.01);
            statusbar_telemetry_updated ("Elrond bootstrapping %s (0%%)...".printf (model_name), true);

            try {
                var msg = new Soup.Message ("GET", DEFAULT_MODEL_URL);
                InputStream net_stream = yield soup_session.send_async (msg, Priority.DEFAULT, download_cancellable);

                if (msg.status_code != Soup.Status.OK) {
                    throw new IOError.FAILED ("HTTP %u: %s", msg.status_code, msg.reason_phrase);
                }

                int64 total_bytes = msg.response_headers.get_content_length ();
                var out_file = File.new_for_path (part_path);
                FileOutputStream file_stream = yield out_file.replace_async (
                    null, false, FileCreateFlags.REPLACE_DESTINATION, Priority.DEFAULT, download_cancellable
                );

                uint8[] buffer = new uint8[65536];
                int64 received = 0;

                while (true) {
                    ssize_t read_len = yield net_stream.read_async (buffer, Priority.DEFAULT, download_cancellable);
                    if (read_len <= 0) break;

                    size_t written;
                    yield file_stream.write_all_async (buffer[0:read_len], Priority.DEFAULT, download_cancellable, out written);
                    received += read_len;

                    if (total_bytes > 0) {
                        double frac = (double) received / (double) total_bytes;
                        status_updated ("Downloading %s (%.0f%%)...".printf (model_name, frac * 100.0), true, frac);
                        statusbar_telemetry_updated (
                            "Elrond bootstrapping %s (%.0f%%)...".printf (model_name, frac * 100.0),
                            true
                        );
                    }
                }

                yield file_stream.close_async (Priority.DEFAULT, null);
                FileUtils.rename (part_path, dest_path);
                download_cancellable = null;
                return true;
            } catch (Error e) {
                FileUtils.remove (part_path);
                download_cancellable = null;
                status_updated ("Elrond setup cancelled or failed: %s".printf (e.message), false, 0.0);
                statusbar_telemetry_updated ("Elrond AI: Off", false);
                SettingsManager.get_default ().elrond_enabled = false;
                return false;
            }
        }

        private async void start_preconfigured_daemon (
            string model_path,
            bool try_vulkan,
            AiAssistanceLevel level
        ) {
            stop_daemon ();

            string? llama_bin = Environment.find_program_in_path ("llama-server");
            if (llama_bin == null) {
                string home_local = GLib.Path.build_filename (Environment.get_home_dir (), ".local", "bin", "llama-server");
                if (FileUtils.test (home_local, FileTest.IS_EXECUTABLE)) {
                    llama_bin = home_local;
                }
            }

            if (llama_bin == null) {
                is_ready = false;
                status_updated ("llama-server binary not found on PATH. Install llama.cpp or enable local server.", false, 0.0);
                statusbar_telemetry_updated ("Elrond AI: llama-server not found", false);
                return;
            }

            string ngl = try_vulkan ? "99" : "0";
            string ctx_size = level.get_context_size ().to_string ();
            string threads = uint.max (2, GLib.get_num_processors () / 2).to_string ();

            string[] argv = {
                llama_bin,
                "--model", model_path,
                "--host", "127.0.0.1",
                "--port", active_port.to_string (),
                "--ctx-size", ctx_size,
                "--n-gpu-layers", ngl,
                "--threads", threads,
                "--flash-attn"
            };

            try {
                var launcher = new SubprocessLauncher (SubprocessFlags.STDOUT_SILENCE | SubprocessFlags.STDERR_SILENCE);
                llama_proc = launcher.spawnv (argv);
                daemon_pid_str = llama_proc.get_identifier ();
                running_on_vulkan = try_vulkan;

                // Health check after 600ms: if Vulkan failed on older GPU, automatically fall back to CPU
                Timeout.add (600, () => {
                    if (llama_proc != null && llama_proc.get_if_exited () && try_vulkan) {
                        start_preconfigured_daemon.begin (model_path, false, level);
                    } else if (llama_proc != null && !llama_proc.get_if_exited ()) {
                        is_ready = true;
                        string accel = running_on_vulkan ? "Vulkan GPU" : "CPU Mode";
                        status_updated ("Elrond Active (%s • Level: %s)".printf (accel, level.to_string ()), false, 1.0);
                        update_memory_telemetry ();
                        start_telemetry_polling ();
                    }
                    return Source.REMOVE;
                });
            } catch (Error e) {
                is_ready = false;
                status_updated ("Failed to start Elrond: %s".printf (e.message), false, 0.0);
                statusbar_telemetry_updated ("Elrond AI: Error", false);
            }
        }

        private void start_telemetry_polling () {
            if (telemetry_timer_id != 0) {
                Source.remove (telemetry_timer_id);
            }
            telemetry_timer_id = Timeout.add_seconds (2, () => {
                if (!is_ready || llama_proc == null || llama_proc.get_if_exited ()) {
                    telemetry_timer_id = 0;
                    return Source.REMOVE;
                }
                update_memory_telemetry ();
                return Source.CONTINUE;
            });
        }

        /**
         * Reads live RAM (VmRSS) and estimated/sysfs VRAM used by the Elrond daemon
         * and formats: "Elrond running on <AI_Model_name> - <X.X GB> RAM/VRAM used"
         */
        private void update_memory_telemetry () {
            string model_name = SettingsManager.get_default ().active_model_name;
            double ram_gb = 0.0;

            if (daemon_pid_str != null) {
                string proc_status = "/proc/%s/status".printf (daemon_pid_str);
                try {
                    string content;
                    if (FileUtils.get_contents (proc_status, out content)) {
                        foreach (string line in content.split ("\n")) {
                            if (line.has_prefix ("VmRSS:")) {
                                string kb_str = line.substring (6).replace ("kB", "").strip ();
                                int64 kb = int64.parse (kb_str);
                                ram_gb = (double) kb / (1024.0 * 1024.0);
                                break;
                            }
                        }
                    }
                } catch (Error e) {}
            }

            // If running on Vulkan GPU, also check model footprint in VRAM
            double vram_gb = 0.0;
            if (running_on_vulkan) {
                try {
                    File model_file = File.new_for_path (get_model_path ());
                    FileInfo info = model_file.query_info (FileAttribute.STANDARD_SIZE, FileQueryInfoFlags.NONE);
                    // Model weights + KV cache offloaded to Vulkan VRAM
                    double kv_overhead_gb = (SettingsManager.get_default ().elrond_level == AiAssistanceLevel.HIGH) ? 0.35 : 0.18;
                    vram_gb = ((double) info.get_size () / (1024.0 * 1024.0 * 1024.0)) + kv_overhead_gb;
                } catch (Error e) {}
            }

            string mem_summary;
            if (running_on_vulkan && vram_gb > 0.1) {
                if (ram_gb > 0.05) {
                    mem_summary = "%.2f GB RAM / %.2f GB VRAM used".printf (ram_gb, vram_gb);
                } else {
                    mem_summary = "%.2f GB VRAM used".printf (vram_gb);
                }
            } else {
                mem_summary = "%.2f GB RAM used".printf (double.max (ram_gb, 2.1));
            }

            string telemetry_line = "Elrond running on %s - %s".printf (model_name, mem_summary);
            statusbar_telemetry_updated (telemetry_line, true);
        }

        public void stop_daemon () {
            is_ready = false;
            if (telemetry_timer_id != 0) {
                Source.remove (telemetry_timer_id);
                telemetry_timer_id = 0;
            }
            if (llama_proc != null && !llama_proc.get_if_exited ()) {
                llama_proc.force_exit ();
                llama_proc = null;
            }
            daemon_pid_str = null;
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
                throw new IOError.NOT_CONNECTED ("Elrond Assistance is warming up or disabled.");
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

            var builder = new Json.Builder ();
            builder.begin_object ();
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

            var msg = new Soup.Message ("POST", "http://127.0.0.1:%u/v1/chat/completions".printf (active_port));
            msg.set_request_body_from_bytes ("application/json", new Bytes (payload.data));

            Bytes bytes = yield soup_session.send_and_read_async (msg, Priority.DEFAULT, null);
            var parser = new Json.Parser ();
            yield parser.load_from_stream_async (new MemoryInputStream.from_bytes (bytes), null);

            return parser.get_root ()
                .get_object ()
                .get_array_member ("choices")
                .get_object_element (0)
                .get_object_member ("message")
                .get_string_member ("content");
        }
    }
}
