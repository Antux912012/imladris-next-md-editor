using GLib;
using Gtk;

namespace Imladris.Execution {

    public enum LanguageRuntime {
        R,
        PYTHON
    }

    /**
     * Pillar 4: Persistent asynchronous REPL subprocess bridge for R and Python.
     * Maintains shared session state and bidirectional stdin/stdout/stderr pipes.
     */
    public class ReplBridge : Object {
        private Subprocess? process;
        private DataOutputStream? stdin_stream;
        private DataInputStream? stdout_stream;
        private DataInputStream? stderr_stream;
        private LanguageRuntime runtime;
        private string project_root;

        public signal void output_received (string text);
        public signal void error_received (string text);

        private bool _is_running = false;

        public bool is_running {
            get { return process != null && _is_running; }
        }

        public ReplBridge (LanguageRuntime runtime, string project_root) {
            this.runtime = runtime;
            this.project_root = project_root;
        }

        public async void start () throws Error {
            var launcher = new SubprocessLauncher (
                SubprocessFlags.STDIN_PIPE |
                SubprocessFlags.STDOUT_PIPE |
                SubprocessFlags.STDERR_PIPE
            );
            launcher.set_cwd (project_root); // Pillar 5: Enforce pwd project root

            string prog_name = (runtime == LanguageRuntime.R) ? "R" : "python3";
            string? resolved_path = null;
            string? env_prefix = null;
            var source = Core.PlatformUtils.resolve_runtime (prog_name, project_root, out resolved_path, out env_prefix);

            if (source == Core.RuntimeSource.MISSING && runtime == LanguageRuntime.PYTHON) {
                source = Core.PlatformUtils.resolve_runtime ("python", project_root, out resolved_path, out env_prefix);
            }

            string[] raw_args;
            if (runtime == LanguageRuntime.R) {
                raw_args = { "--no-save", "--no-restore", "--interactive" };
            } else {
                raw_args = { "-u", "-i" };
            }

            string[] argv;
            if (source == Core.RuntimeSource.MANAGED_GLOBAL || source == Core.RuntimeSource.PROJECT_SANDBOX) {
                Core.PlatformUtils.configure_managed_env (launcher, env_prefix);
                argv = new string[1 + raw_args.length];
                argv[0] = (resolved_path != null) ? resolved_path : prog_name;
                for (int i = 0; i < raw_args.length; i++) argv[i + 1] = raw_args[i];
            } else if (source == Core.RuntimeSource.HOST_FLATPAK_SPAWN) {
                string[] host_raw = new string[1 + raw_args.length];
                host_raw[0] = prog_name;
                for (int i = 0; i < raw_args.length; i++) host_raw[i + 1] = raw_args[i];
                argv = Core.PlatformUtils.build_host_command (host_raw, project_root);
            } else {
                argv = new string[1 + raw_args.length];
                argv[0] = (resolved_path != null) ? resolved_path : prog_name;
                for (int i = 0; i < raw_args.length; i++) argv[i + 1] = raw_args[i];
            }

            process = launcher.spawnv (argv);
            _is_running = true;
            process.wait_async.begin (null, (obj, res) => {
                _is_running = false;
            });
            stdin_stream = new DataOutputStream (process.get_stdin_pipe ());
            stdout_stream = new DataInputStream (process.get_stdout_pipe ());
            stderr_stream = new DataInputStream (process.get_stderr_pipe ());

            // Start asynchronous background readers
            read_stdout_loop.begin ();
            read_stderr_loop.begin ();
        }

        private async void read_stdout_loop () {
            try {
                while (is_running && stdout_stream != null) {
                    size_t length;
                    string? line = yield stdout_stream.read_line_async (Priority.DEFAULT, null, out length);
                    if (line != null) {
                        output_received (line + "\n");
                    } else {
                        break;
                    }
                }
            } catch (Error e) {
                // Stream closed or terminated
            }
        }

        private async void read_stderr_loop () {
            try {
                while (is_running && stderr_stream != null) {
                    size_t length;
                    string? line = yield stderr_stream.read_line_async (Priority.DEFAULT, null, out length);
                    if (line != null) {
                        error_received (line + "\n");
                    } else {
                        break;
                    }
                }
            } catch (Error e) {
                // Stream closed or terminated
            }
        }

        public async void send_command (string code) throws Error {
            if (!is_running || stdin_stream == null) {
                throw new IOError.NOT_CONNECTED ("REPL session is not active.");
            }

            string payload = code.has_suffix ("\n") ? code : code + "\n";
            yield stdin_stream.write_all_async (payload.data, Priority.DEFAULT, null, null);
            yield stdin_stream.flush_async (Priority.DEFAULT, null);
        }

        public void stop () {
            _is_running = false;
            if (process != null) {
                process.force_exit ();
                process = null;
            }
        }
    }
}
