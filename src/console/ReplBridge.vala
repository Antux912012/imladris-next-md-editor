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

            string[] raw_argv;
            if (runtime == LanguageRuntime.R) {
                // R interactive REPL mode
                raw_argv = { "R", "--no-save", "--no-restore", "--interactive" };
            } else {
                // Python interactive REPL mode
                raw_argv = { "python3", "-u", "-i" };
            }

            string[] argv = (runtime == LanguageRuntime.R)
                ? Core.PlatformUtils.build_host_command (raw_argv, project_root)
                : raw_argv;

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
