namespace Imladris {

    public class ExecutionEngine : Object {

        /**
         * Asynchronously runs a CLI command (Rscript, python3, deno, tsc, quarto)
         * and streams stdout/stderr to the active DocumentPage's console pane.
         */
        public static async void run_command_async (string[] argv, DocumentPage page) {
            if (argv.length == 0) return;
            page.append_console_log (@"▶ Executing: $(string.joinv (" ", argv))");

            string? working_dir = (page.file_location != null && page.file_location.get_parent () != null)
                ? page.file_location.get_parent ().get_path ()
                : null;

            try {
                var launcher = new GLib.SubprocessLauncher (
                    GLib.SubprocessFlags.STDOUT_PIPE | GLib.SubprocessFlags.STDERR_MERGE
                );

                string prog = argv[0];
                string? resolved_path = null;
                string? env_prefix = null;
                var source = Core.PlatformUtils.resolve_runtime (prog, working_dir, out resolved_path, out env_prefix);

                string[] final_argv;
                if (source == Core.RuntimeSource.HOST_FLATPAK_SPAWN) {
                    final_argv = Core.PlatformUtils.build_host_command (argv, working_dir);
                } else if (source == Core.RuntimeSource.MANAGED_GLOBAL || source == Core.RuntimeSource.PROJECT_SANDBOX) {
                    Core.PlatformUtils.configure_managed_env (launcher, env_prefix);
                    final_argv = new string[argv.length];
                    final_argv[0] = (resolved_path != null) ? resolved_path : prog;
                    for (int i = 1; i < argv.length; i++) final_argv[i] = argv[i];
                } else {
                    final_argv = argv;
                }

                if (working_dir != null && working_dir != "") {
                    launcher.set_cwd (working_dir);
                }

                var proc = launcher.spawnv (final_argv);
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
            return yield capture_command_in_dir_async (argv, null);
        }

        public static async string capture_command_in_dir_async (string[] argv, string? working_dir) {
            if (argv.length == 0) return "";
            try {
                var launcher = new GLib.SubprocessLauncher (
                    GLib.SubprocessFlags.STDOUT_PIPE | GLib.SubprocessFlags.STDERR_MERGE
                );

                string prog = argv[0];
                string? resolved_path = null;
                string? env_prefix = null;
                var source = Core.PlatformUtils.resolve_runtime (prog, working_dir, out resolved_path, out env_prefix);

                string[] final_argv;
                if (source == Core.RuntimeSource.HOST_FLATPAK_SPAWN) {
                    final_argv = Core.PlatformUtils.build_host_command (argv, working_dir);
                } else if (source == Core.RuntimeSource.MANAGED_GLOBAL || source == Core.RuntimeSource.PROJECT_SANDBOX) {
                    Core.PlatformUtils.configure_managed_env (launcher, env_prefix);
                    final_argv = new string[argv.length];
                    final_argv[0] = (resolved_path != null) ? resolved_path : prog;
                    for (int i = 1; i < argv.length; i++) final_argv[i] = argv[i];
                } else {
                    final_argv = argv;
                }

                if (working_dir != null && working_dir != "") {
                    launcher.set_cwd (working_dir);
                }

                var proc = launcher.spawnv (final_argv);
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
