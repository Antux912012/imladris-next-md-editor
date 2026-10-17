namespace Imladris {

    public class ExecutionEngine : Object {

        /**
         * Asynchronously runs a CLI command (Rscript, python3, deno, tsc, quarto)
         * and streams stdout/stderr to the active DocumentPage's console pane.
         */
        public static async void run_command_async (string[] argv, DocumentPage page) {
            page.append_console_log (@"▶ Executing: $(string.joinv (" ", argv))");
            try {
                var proc = new GLib.Subprocess.newv (
                    argv,
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
    }
}
