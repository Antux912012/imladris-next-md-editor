namespace Imladris {

    public class ExecutionEngine : Object {

        private static string[] resolve_cmd_argv (string[] argv) {
            if (argv.length == 0) return argv;
            if (Core.PlatformUtils.is_flatpak ()) {
                string prog = argv[0];
                if (GLib.Environment.find_program_in_path (prog) == null ||
                    prog == "R" || prog == "Rscript" || prog == "quarto" || prog == "pandoc") {
                    return Core.PlatformUtils.build_host_command (argv);
                }
            }
            return argv;
        }

        /**
         * Asynchronously runs a CLI command (Rscript, python3, deno, tsc, quarto)
         * and streams stdout/stderr to the active DocumentPage's console pane.
         */
        public static async void run_command_async (string[] argv, DocumentPage page) {
            page.append_console_log (@"▶ Executing: $(string.joinv (" ", argv))");
            try {
                var proc = new GLib.Subprocess.newv (
                    resolve_cmd_argv (argv),
                    GLib.SubprocessFlags.STDOUT_PIPE | GLib.SubprocessFlags.STDERR_MERGE
                );
                string? output = null;
                yield proc.communicate_utf8_async (null, null, out output, null);
                if (output != null && output.strip ().length > 0) {
                    page.append_console_log (output.strip ());
                } else {
                    page.append_console_log ("✔ Completed successfully.");
                }
            } catch (GLib.Error e) {
                page.append_console_log (@"✖ Execution Notice: $(e.message)");
            }
        }

        public static async string capture_command_async (string[] argv) {
            try {
                var proc = new GLib.Subprocess.newv (
                    resolve_cmd_argv (argv),
                    GLib.SubprocessFlags.STDOUT_PIPE | GLib.SubprocessFlags.STDERR_MERGE
                );
                string? output = null;
                yield proc.communicate_utf8_async (null, null, out output, null);
                if (output != null && output.strip ().length > 0) {
                    return output.strip ();
                }
                return "✔ Completed (no output).";
            } catch (GLib.Error e) {
                return @"✖ Execution Notice: $(e.message)";
            }
        }
    }
}
