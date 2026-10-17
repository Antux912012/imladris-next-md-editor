namespace Imladris {

    public class LlamaServerManager : GLib.Object {

        public bool is_running { get; private set; default = false; }
        public int current_port { get; private set; default = 8080; }
        public string active_model_path { get; private set; default = ""; }

        public signal void server_state_changed (bool running, string message);
        public signal void download_progress (double progress, string status_text);

        private GLib.Subprocess? server_process = null;
        private GLib.Cancellable? download_cancellable = null;

        public const string DEFAULT_QWEN_1_5B_URL = "https://huggingface.co/Qwen/Qwen2.5-Coder-1.5B-Instruct-GGUF/resolve/main/qwen2.5-coder-1.5b-instruct-q4_k_m.gguf";
        public const string DEFAULT_QWEN_1_5B_NAME = "qwen2.5-coder-1.5b-instruct-q4_k_m.gguf";

        public const string DEFAULT_QWEN_7B_URL = "https://huggingface.co/Qwen/Qwen2.5-Coder-7B-Instruct-GGUF/resolve/main/qwen2.5-coder-7b-instruct-q4_k_m.gguf";
        public const string DEFAULT_QWEN_7B_NAME = "qwen2.5-coder-7b-instruct-q4_k_m.gguf";

        public static string get_models_directory () {
            string dir = GLib.Path.build_filename (GLib.Environment.get_user_data_dir (), "imladris", "models");
            GLib.DirUtils.create_with_parents (dir, 0755);
            return dir;
        }

        public string? find_llama_server_binary () {
            string[] search_paths = {
                GLib.Path.build_filename (GLib.Environment.get_home_dir (), ".local", "bin", "llama-server"),
                "/usr/bin/llama-server",
                "/usr/local/bin/llama-server",
                "/app/bin/llama-server"
            };

            foreach (string path in search_paths) {
                if (GLib.FileUtils.test (path, GLib.FileTest.IS_EXECUTABLE)) {
                    return path;
                }
            }

            string? path_env = GLib.Environment.get_variable ("PATH");
            if (path_env != null) {
                foreach (string dir in path_env.split (":")) {
                    string full_path = GLib.Path.build_filename (dir, "llama-server");
                    if (GLib.FileUtils.test (full_path, GLib.FileTest.IS_EXECUTABLE)) {
                        return full_path;
                    }
                }
            }

            return null;
        }

        public string[] list_downloaded_models () {
            var models = new GLib.GenericArray<string> ();
            string models_dir = get_models_directory ();

            try {
                var dir = GLib.Dir.open (models_dir, 0);
                string? filename = null;
                while ((filename = dir.read_name ()) != null) {
                    if (filename.has_suffix (".gguf")) {
                        models.add (GLib.Path.build_filename (models_dir, filename));
                    }
                }
            } catch (GLib.Error e) {
                warning (@"Error reading models directory: $(e.message)");
            }

            string[] result = new string[models.length];
            for (int i = 0; i < models.length; i++) {
                result[i] = models.get (i);
            }
            return result;
        }

        public async void download_model_async (string url, string target_filename) throws GLib.Error {
            string destination = GLib.Path.build_filename (get_models_directory (), target_filename);
            download_cancellable = new GLib.Cancellable ();

            download_progress (0.05, @"Starting download of $target_filename...");

            string[] argv = {
                "curl",
                "-L",
                "-f",
                "--retry", "3",
                "-o", destination,
                url
            };

            var proc = new GLib.Subprocess.newv (
                argv,
                GLib.SubprocessFlags.STDOUT_PIPE | GLib.SubprocessFlags.STDERR_MERGE
            );

            proc.wait_check_async.begin (download_cancellable, (obj, res) => {
                try {
                    proc.wait_check_async.end (res);
                    download_progress (1.0, @"✔ $target_filename downloaded successfully.");
                } catch (GLib.Error e) {
                    download_progress (0.0, @"✖ Download failed: $(e.message)");
                }
            });
        }

        public async void start_server_async (string model_path, int port = 8080) throws GLib.Error {
            if (is_running) {
                stop_server ();
            }

            string? server_bin = find_llama_server_binary ();
            if (server_bin == null) {
                // If llama-server binary is not found, check if Ollama is running or inform user
                throw new GLib.IOError.NOT_FOUND ("llama-server executable not found in PATH or ~/.local/bin/llama-server.");
            }

            string[] argv = {
                server_bin,
                "-m", model_path,
                "--port", port.to_string (),
                "-c", "8192",
                "-ngl", "99"
            };

            server_process = new GLib.Subprocess.newv (
                argv,
                GLib.SubprocessFlags.STDOUT_PIPE | GLib.SubprocessFlags.STDERR_MERGE
            );

            this.is_running = true;
            this.current_port = port;
            this.active_model_path = model_path;
            server_state_changed (true, @"Offline llama-server running on port $port with $(GLib.Path.get_basename (model_path))");

            // Monitor process exit in background
            server_process.wait_async.begin (null, (obj, res) => {
                this.is_running = false;
                server_state_changed (false, "Offline llama-server stopped.");
            });
        }

        public void stop_server () {
            if (server_process != null && is_running) {
                server_process.force_exit ();
                server_process = null;
                is_running = false;
                server_state_changed (false, "Offline llama-server stopped.");
            }
        }
    }
}
