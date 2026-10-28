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
        private double cached_model_size_gb = 0.0;

        public signal void status_updated (string status_text, bool is_busy, double progress_fraction);
        public signal void statusbar_telemetry_updated (string statusbar_text, bool active);

        public bool is_ready { get; private set; default = false; }

        private ElrondEngineController () {
            soup_session = new Soup.Session () {
                idle_timeout = 60,
                timeout = 0
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

        private static string? scan_dir_for_gguf (string dir_path, int max_depth = 2) {
            if (!FileUtils.test (dir_path, FileTest.IS_DIR)) {
                return null;
            }
            try {
                var dir = Dir.open (dir_path, 0);
                string? name = null;
                while ((name = dir.read_name ()) != null) {
                    string full_path = GLib.Path.build_filename (dir_path, name);
                    if (FileUtils.test (full_path, FileTest.IS_DIR) && max_depth > 1) {
                        string? sub_found = scan_dir_for_gguf (full_path, max_depth - 1);
                        if (sub_found != null) return sub_found;
                    } else if (name.has_suffix (".gguf")) {
                        return full_path;
                    }
                }
            } catch (Error e) {}
            return null;
        }

        public static string? find_any_available_model () {
            var settings = SettingsManager.get_default ();
            if (settings.custom_model_path != "" && FileUtils.test (settings.custom_model_path, FileTest.EXISTS)) {
                return settings.custom_model_path;
            }

            string imladris_default = GLib.Path.build_filename (Environment.get_user_data_dir (), "imladris", "models", DEFAULT_MODEL_FILENAME);
            if (FileUtils.test (imladris_default, FileTest.EXISTS)) {
                return imladris_default;
            }

            // Check imladris models directory for any .gguf
            string imladris_models_dir = GLib.Path.build_filename (Environment.get_user_data_dir (), "imladris", "models");
            string? found = scan_dir_for_gguf (imladris_models_dir);
            if (found != null) return found;

            // Check LM Studio models directory
            string lmstudio_dir = GLib.Path.build_filename (Environment.get_home_dir (), ".var", "app", "ai.lmstudio.lm-studio", ".lmstudio", "models");
            found = scan_dir_for_gguf (lmstudio_dir, 4);
            if (found != null) return found;

            // Check HuggingFace hub cache
            string hf_dir = GLib.Path.build_filename (Environment.get_home_dir (), ".cache", "huggingface", "hub");
            found = scan_dir_for_gguf (hf_dir, 4);
            if (found != null) return found;

            // Check Ollama models directory
            string ollama_dir = GLib.Path.build_filename (Environment.get_home_dir (), ".ollama", "models");
            found = scan_dir_for_gguf (ollama_dir, 3);
            if (found != null) return found;

            return null;
        }

        public string get_model_path () {
            string? found = find_any_available_model ();
            if (found != null) {
                return found;
            }
            string model_dir = GLib.Path.build_filename (Environment.get_user_data_dir (), "imladris", "models");
            DirUtils.create_with_parents (model_dir, 0755);
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

            // Update active model display name if custom or discovered model is used
            string basename = GLib.Path.get_basename (model_path);
            if (basename.has_suffix (".gguf")) {
                settings.active_model_name = basename.substring (0, basename.length - 5);
            }

            yield start_preconfigured_daemon (
                model_path,
                settings.hardware_acceleration_enabled,
                settings.elrond_level
            );
        }

        private async bool download_url_to_file (string url, string dest_path, string label) {
            download_cancellable = new Cancellable ();
            string part_path = dest_path + ".part";

            status_updated ("Downloading %s...".printf (label), true, 0.01);
            statusbar_telemetry_updated ("Elrond bootstrapping %s (0%%)...".printf (label), true);

            try {
                var msg = new Soup.Message ("GET", url);
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
                        status_updated ("Downloading %s (%.0f%%)...".printf (label, frac * 100.0), true, frac);
                        statusbar_telemetry_updated (
                            "Elrond bootstrapping %s (%.0f%%)...".printf (label, frac * 100.0),
                            true
                        );
                    }
                }

                yield file_stream.close_async (Priority.DEFAULT, null);
                FileUtils.rename (part_path, dest_path);
                download_cancellable = null;
                return true;
            } catch (Error e) {
                if (FileUtils.test (part_path, FileTest.EXISTS)) {
                    FileUtils.remove (part_path);
                }
                download_cancellable = null;
                warning ("Download of %s failed: %s", url, e.message);
                return false;
            }
        }

        private async bool auto_download_default_model (string dest_path) {
            string model_name = SettingsManager.get_default ().active_model_name;
            status_updated ("Bootstrapping Elrond (%s)...".printf (model_name), true, 0.01);
            statusbar_telemetry_updated ("Elrond bootstrapping %s (0%%)...".printf (model_name), true);

            bool ok = yield download_url_to_file (DEFAULT_MODEL_URL, dest_path, model_name);
            if (!ok) {
                status_updated ("Elrond setup cancelled or failed", false, 0.0);
                statusbar_telemetry_updated ("Elrond AI: Off", false);
                SettingsManager.get_default ().elrond_enabled = false;
            }
            return ok;
        }

        public static string? find_llama_server_binary (ElrondBackend backend = ElrondBackend.VULKAN) {
            string data_dir = GLib.Path.build_filename (Environment.get_user_data_dir (), "imladris", "bin");
            string flavor_dir = (backend == ElrondBackend.CUDA) ? "cuda" : "vulkan";
            string specific_bin = (backend == ElrondBackend.CUDA) ? "llama-server-cuda" : "llama-server-vulkan";

            string[] search_candidates = {
                GLib.Path.build_filename (data_dir, flavor_dir, "llama-server"),
                GLib.Path.build_filename (data_dir, specific_bin),
                GLib.Path.build_filename (data_dir, "llama-server"),
                "/app/bin/" + specific_bin,
                "/app/bin/llama-server",
                GLib.Path.build_filename (Environment.get_home_dir (), ".local", "bin", specific_bin),
                GLib.Path.build_filename (Environment.get_home_dir (), ".local", "bin", "llama-server"),
                "/usr/local/bin/llama-server",
                "/usr/bin/llama-server"
            };
            foreach (var p in search_candidates) {
                if (FileUtils.test (p, FileTest.IS_EXECUTABLE)) {
                    return p;
                }
            }
            return Environment.find_program_in_path ("llama-server");
        }

        public async bool auto_install_llama_server (ElrondBackend backend = ElrondBackend.VULKAN) {
            string backend_name = backend.get_display_name ();
            status_updated ("Bootstrapping %s engine...".printf (backend_name), true, 0.05);
            statusbar_telemetry_updated ("Elrond bootstrapping %s...".printf (backend_name), true);

            string data_bin_dir = GLib.Path.build_filename (Environment.get_user_data_dir (), "imladris", "bin");
            string flavor_dir = (backend == ElrondBackend.CUDA) ? "cuda" : "vulkan";
            string target_subdir = GLib.Path.build_filename (data_bin_dir, flavor_dir);

            DirUtils.create_with_parents (target_subdir, 0755);

            string release_tag = "b11669";
            string tarball_name = (backend == ElrondBackend.CUDA)
                ? "llama-%s-bin-ubuntu-cuda-12.8-x64.tar.gz".printf (release_tag)
                : "llama-%s-bin-ubuntu-vulkan-x64.tar.gz".printf (release_tag);
            string download_url = "https://github.com/ggml-org/llama.cpp/releases/download/%s/%s".printf (release_tag, tarball_name);

            string tmp_tarball = GLib.Path.build_filename (Environment.get_tmp_dir (), "imladris_%s.tar.gz".printf (flavor_dir));
            bool downloaded = yield download_url_to_file (download_url, tmp_tarball, backend_name);

            if (!downloaded && backend == ElrondBackend.VULKAN) {
                string cpu_tarball = "llama-%s-bin-ubuntu-x64.tar.gz".printf (release_tag);
                string cpu_url = "https://github.com/ggml-org/llama.cpp/releases/download/%s/%s".printf (release_tag, cpu_tarball);
                downloaded = yield download_url_to_file (cpu_url, tmp_tarball, "Universal CPU fallback");
            }

            if (downloaded) {
                status_updated ("Extracting %s engine...".printf (backend_name), true, 0.95);
                statusbar_telemetry_updated ("Elrond extracting %s...".printf (backend_name), true);

                bool extracted = yield extract_and_install_engine (tmp_tarball, target_subdir, data_bin_dir, flavor_dir);
                FileUtils.remove (tmp_tarball);

                if (extracted && backend == ElrondBackend.CUDA) {
                    string cudart_tarball = "cudart-llama-%s-bin-ubuntu-cuda-12.8-x64.tar.gz".printf (release_tag);
                    string cudart_url = "https://github.com/ggml-org/llama.cpp/releases/download/%s/%s".printf (release_tag, cudart_tarball);
                    string tmp_cudart = GLib.Path.build_filename (Environment.get_tmp_dir (), "imladris_cudart.tar.gz");
                    if (yield download_url_to_file (cudart_url, tmp_cudart, "CUDA Runtime Libraries")) {
                        yield extract_and_install_engine (tmp_cudart, target_subdir, data_bin_dir, flavor_dir);
                        FileUtils.remove (tmp_cudart);
                    }
                }

                if (find_llama_server_binary (backend) != null) {
                    status_updated ("%s engine installed successfully".printf (backend_name), false, 1.0);
                    statusbar_telemetry_updated ("Elrond AI: Ready", false);
                    return true;
                }
            }

            // Fallback to shell installer script
            bool ok = yield run_installer_script (backend);
            if (ok) {
                status_updated ("%s engine installed successfully".printf (backend_name), false, 1.0);
                statusbar_telemetry_updated ("Elrond AI: Ready", false);
            } else {
                status_updated ("%s engine installation failed".printf (backend_name), false, 0.0);
                statusbar_telemetry_updated ("Elrond AI: Off", false);
            }
            return ok;
        }

        private async bool extract_and_install_engine (
            string tarball_path,
            string target_subdir,
            string data_bin_dir,
            string flavor_dir
        ) {
            try {
                string script = "tar -xzf \"$1\" -C \"$2\" && find \"$2\" -mindepth 2 -type f \\( -name '*.so*' -o -name 'llama-server' \\) -exec cp -f {} \"$2/\" \\; && chmod 755 \"$2/llama-server\" && cp -f \"$2/\"*.so* \"$3/\" 2>/dev/null || true && cp -f \"$2/llama-server\" \"$3/llama-server-$4\" && cp -f \"$2/llama-server\" \"$3/llama-server\" && chmod 755 \"$3/llama-server-$4\" \"$3/llama-server\" 2>/dev/null || true";
                string[] argv = { "sh", "-c", script, "_", tarball_path, target_subdir, data_bin_dir, flavor_dir };

                var launcher = new SubprocessLauncher (SubprocessFlags.STDOUT_SILENCE | SubprocessFlags.STDERR_SILENCE);
                var proc = launcher.spawnv (argv);
                yield proc.wait_async (null);

                string installed_bin = GLib.Path.build_filename (target_subdir, "llama-server");
                return FileUtils.test (installed_bin, FileTest.IS_EXECUTABLE);
            } catch (Error e) {
                warning ("Extraction failed: %s", e.message);
                return false;
            }
        }

        private async bool run_installer_script (ElrondBackend backend) {
            string flavor_arg = (backend == ElrondBackend.CUDA) ? "cuda" : "vulkan";
            string[] script_candidates = {
                "/app/share/imladris/scripts/install-llama-server.sh",
                "/usr/share/imladris/scripts/install-llama-server.sh",
                "/usr/local/share/imladris/scripts/install-llama-server.sh",
                GLib.Path.build_filename (Environment.get_current_dir (), "scripts", "install-llama-server.sh")
            };

            string? script_path = null;
            foreach (var p in script_candidates) {
                if (FileUtils.test (p, FileTest.EXISTS)) {
                    script_path = p;
                    break;
                }
            }

            try {
                string[] argv;
                if (script_path != null) {
                    argv = { "bash", script_path, flavor_arg };
                } else {
                    argv = { "bash", "-c", "curl -sSfL --connect-timeout 20 https://raw.githubusercontent.com/Antux912012/imladris-next-md-editor/main/scripts/install-llama-server.sh | bash -s -- " + flavor_arg };
                }
                var launcher = new SubprocessLauncher (SubprocessFlags.STDOUT_SILENCE | SubprocessFlags.STDERR_SILENCE);
                var proc = launcher.spawnv (argv);
                yield proc.wait_async (null);
                return find_llama_server_binary (backend) != null;
            } catch (Error e) {
                warning ("Fallback installer script failed: %s", e.message);
                return false;
            }
        }

        private async void start_preconfigured_daemon (
            string model_path,
            bool try_vulkan,
            AiAssistanceLevel level
        ) {
            stop_daemon ();

            var backend = SettingsManager.get_default ().elrond_backend;
            string? llama_bin = find_llama_server_binary (backend);
            if (llama_bin == null) {
                bool installed = yield auto_install_llama_server (backend);
                if (installed) {
                    llama_bin = find_llama_server_binary (backend);
                }
            }

            if (llama_bin == null) {
                is_ready = false;
                status_updated ("%s binary not found. Install or download via Preferences.".printf (backend.get_display_name ()), false, 0.0);
                statusbar_telemetry_updated ("Elrond AI: %s not found".printf (backend.to_string_id ()), false);
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
                "--threads", threads
            };

            try {
                var launcher = new SubprocessLauncher (SubprocessFlags.STDOUT_SILENCE | SubprocessFlags.STDERR_SILENCE);

                // Build comprehensive LD_LIBRARY_PATH including all flavor subdirectories and system library paths
                string bin_dir = GLib.Path.get_dirname (llama_bin);
                string user_bin_dir = GLib.Path.build_filename (Environment.get_user_data_dir (), "imladris", "bin");
                string vulkan_lib_dir = GLib.Path.build_filename (user_bin_dir, "vulkan");
                string cuda_lib_dir = GLib.Path.build_filename (user_bin_dir, "cuda");
                string existing_ld = Environment.get_variable ("LD_LIBRARY_PATH") ?? "";

                string custom_ld = string.join (":",
                    bin_dir,
                    vulkan_lib_dir,
                    cuda_lib_dir,
                    user_bin_dir,
                    "/app/lib",
                    "/usr/local/lib",
                    "/usr/lib64",
                    existing_ld
                );
                launcher.setenv ("LD_LIBRARY_PATH", custom_ld, true);

                status_updated ("Starting %s engine...".printf (backend.get_display_name ()), true, 0.2);
                statusbar_telemetry_updated ("Elrond: Starting...", true);

                llama_proc = launcher.spawnv (argv);
                daemon_pid_str = llama_proc.get_identifier ();
                running_on_vulkan = (backend == ElrondBackend.CUDA) ? true : try_vulkan;

                // Cache model size in memory to prevent synchronous disk I/O in the 2s telemetry loop
                try {
                    File model_file = File.new_for_path (model_path);
                    FileInfo info = model_file.query_info (FileAttribute.STANDARD_SIZE, FileQueryInfoFlags.NONE);
                    cached_model_size_gb = (double) info.get_size () / (1024.0 * 1024.0 * 1024.0);
                } catch (Error e) {
                    cached_model_size_gb = 2.0;
                }

                // Schedule health check polling
                Timeout.add (250, () => {
                    poll_daemon_health (model_path, try_vulkan, level, 1);
                    return Source.REMOVE;
                });
            } catch (Error e) {
                is_ready = false;
                status_updated ("Failed to start Elrond: %s".printf (e.message), false, 0.0);
                statusbar_telemetry_updated ("Elrond AI: Error", false);
            }
        }

        private void poll_daemon_health (string model_path, bool try_vulkan, AiAssistanceLevel level, int poll_count) {
            if (llama_proc == null) {
                return;
            }

            var backend = SettingsManager.get_default ().elrond_backend;

            if (llama_proc.get_if_exited ()) {
                int code = llama_proc.get_exit_status ();
                if (try_vulkan && backend == ElrondBackend.VULKAN) {
                    status_updated ("Vulkan GPU mode failed (code %d), falling back to CPU...".printf (code), true, 0.4);
                    start_preconfigured_daemon.begin (model_path, false, level);
                } else {
                    is_ready = false;
                    status_updated ("Elrond engine stopped (exit code %d)".printf (code), false, 0.0);
                    statusbar_telemetry_updated ("Elrond AI: Error", false);
                }
                return;
            }

            int max_polls = 40;
            check_server_health.begin ((obj, res) => {
                bool healthy = check_server_health.end (res);
                if (healthy) {
                    is_ready = true;
                    string accel = (backend == ElrondBackend.CUDA) ? "NVIDIA CUDA" : (running_on_vulkan ? "Vulkan GPU" : "CPU Mode");
                    status_updated ("Elrond Active (%s • Level: %s)".printf (accel, level.to_string ()), false, 1.0);
                    update_memory_telemetry ();
                    start_telemetry_polling ();
                } else if (poll_count < max_polls) {
                    status_updated ("Loading model into memory (attempt %d/%d)...".printf (poll_count, max_polls), true, 0.2 + 0.7 * ((double) poll_count / (double) max_polls));
                    Timeout.add (250, () => {
                        poll_daemon_health (model_path, try_vulkan, level, poll_count + 1);
                        return Source.REMOVE;
                    });
                } else {
                    if (try_vulkan && backend == ElrondBackend.VULKAN) {
                        start_preconfigured_daemon.begin (model_path, false, level);
                    } else {
                        is_ready = false;
                        status_updated ("Elrond initialization timed out after 10s", false, 0.0);
                        statusbar_telemetry_updated ("Elrond AI: Timeout", false);
                    }
                }
            });
        }

        private async bool check_server_health () {
            try {
                var msg = new Soup.Message ("GET", "http://127.0.0.1:%u/health".printf (active_port));
                yield soup_session.send_and_read_async (msg, Priority.DEFAULT, null);
                return (msg.status_code == Soup.Status.OK);
            } catch (Error e) {
                return false;
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

            // If running on Vulkan GPU, calculate VRAM footprint using cached model size
            double vram_gb = 0.0;
            if (running_on_vulkan) {
                double kv_overhead_gb = (SettingsManager.get_default ().elrond_level == AiAssistanceLevel.HIGH) ? 0.35 : 0.18;
                vram_gb = cached_model_size_gb + kv_overhead_gb;
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

            var backend = SettingsManager.get_default ().elrond_backend;
            string accel_tag = (backend == ElrondBackend.CUDA) ? " (CUDA)" : (running_on_vulkan ? " (Vulkan)" : " (CPU)");
            string telemetry_line = "Elrond running on %s%s - %s".printf (model_name, accel_tag, mem_summary);
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
                throw new IOError.NOT_CONNECTED ("Elrond Assistance is not running.");
            }

            string system_prompt = "You are an expert AI code completion engine for %s. Return ONLY the code continuation to fill at the cursor. Do not wrap in markdown quotes, backticks, or conversational text.".printf (language.length > 0 ? language : "R, Python, and SQL");
            string user_prompt = "[PREFIX]\n%s\n[CURSOR]\n%s\n[COMPLETION]".printf (prefix, suffix);

            var builder = new Json.Builder ();
            builder.begin_object ();
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

            var msg = new Soup.Message ("POST", "http://127.0.0.1:%u/v1/chat/completions".printf (active_port));
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
    }
}
