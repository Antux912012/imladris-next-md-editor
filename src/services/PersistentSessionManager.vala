namespace Imladris.Services {

    public class PersistentSessionManager : GLib.Object {

        private static PersistentSessionManager? _instance = null;

        public static PersistentSessionManager get_default () {
            if (_instance == null) {
                _instance = new PersistentSessionManager ();
            }
            return _instance;
        }

        public string current_working_dir { get; private set; default = ""; }
        public ProjectType active_project_type { get; private set; default = ProjectType.STANDARD; }

        public signal void working_directory_changed (string new_dir);
        public signal void session_output_received (string engine, string output, bool is_error);
        public signal void plot_generated (string plot_file_path);

        private GLib.Subprocess? r_process = null;
        private GLib.DataOutputStream? r_stdin = null;
        private GLib.DataInputStream? r_stdout = null;

        private GLib.Subprocess? py_process = null;
        private GLib.DataOutputStream? py_stdin = null;
        private GLib.DataInputStream? py_stdout = null;

        private bool r_initialized = false;
        private bool py_initialized = false;

        public PersistentSessionManager () {
            this.current_working_dir = GLib.Environment.get_current_dir ();
        }

        /**
         * Pillar 5: Automatic Working Directory (pwd) Synchronization
         * Updates process working directory, sets R working directory, sets Python working directory,
         * and notifies the Files quadrant and integrated terminal.
         */
        public void set_working_directory (string dir_path, ProjectType ptype = ProjectType.STANDARD) {
            if (!GLib.FileUtils.test (dir_path, GLib.FileTest.IS_DIR)) return;

            this.current_working_dir = dir_path;
            this.active_project_type = ptype;

            if (GLib.Environment.set_current_dir (dir_path) != 0) {
                GLib.warning ("Failed to change process current dir to %s", dir_path);
            }

            // Sync R session
            if (r_initialized && r_stdin != null) {
                try {
                    string escaped = dir_path.replace ("\\", "/").replace ("\"", "\\\"");
                    r_stdin.put_string (@"setwd(\"$escaped\"); invisible()\n", null);
                    r_stdin.flush ();
                } catch (GLib.Error e) {
                    // Session may have terminated
                }
            }

            // Sync Python session
            if (py_initialized && py_stdin != null) {
                try {
                    string escaped = dir_path.replace ("\\", "/").replace ("\"", "\\\"");
                    py_stdin.put_string (@"import os; os.chdir(\"$escaped\")\n", null);
                    py_stdin.flush ();
                } catch (GLib.Error e) {
                    // Session may have terminated
                }
            }

            working_directory_changed (dir_path);
        }

        /**
         * Pillar 4: Shared State & Bidirectional Execution Session
         * Evaluates code in the persistent R session. Variables, functions, and imports
         * remain alive across calls.
         */
        public async string execute_r (string code, out string? generated_plot) {
            generated_plot = null;
            ensure_r_session ();

            if (r_stdin == null || r_stdout == null) {
                return "✖ R interpreter (R/Rscript) not available on host system.";
            }

            string plot_dir = GLib.Path.build_filename (GLib.Environment.get_tmp_dir (), "imladris_plots");
            GLib.DirUtils.create_with_parents (plot_dir, 0755);
            string plot_file = GLib.Path.build_filename (plot_dir, @"plot_$(GLib.Random.next_int ()).png");

            bool has_plot = code.contains ("plot(") || code.contains ("plot (") ||
                            code.contains ("ggplot") || code.contains ("qplot") ||
                            code.contains ("hist(") || code.contains ("barplot(") ||
                            code.contains ("boxplot(") || code.contains ("pairs(");

            var cmd_sb = new GLib.StringBuilder ();
            if (has_plot) {
                cmd_sb.append_printf ("png('%s', width = 800, height = 500, res = 120)\n", plot_file.replace ("\\", "/"));
                cmd_sb.append ("tryCatch({\n");
                cmd_sb.append (code + "\n");
                cmd_sb.append ("}, finally = { if (dev.cur() > 1) dev.off() })\n");
            } else {
                cmd_sb.append (code + "\n");
            }

            string sentinel = @"__IMLADRIS_R_DONE_$(GLib.Random.next_int ())__";
            cmd_sb.append_printf ("cat('\\n%s\\n')\n", sentinel);

            try {
                r_stdin.put_string (cmd_sb.str, null);
                r_stdin.flush ();

                var output_sb = new GLib.StringBuilder ();
                string? line = null;
                while (true) {
                    line = yield r_stdout.read_line_async (GLib.Priority.DEFAULT, null);
                    if (line == null) break;
                    if (line.contains (sentinel)) break;
                    output_sb.append (line + "\n");
                }

                if (has_plot && GLib.FileUtils.test (plot_file, GLib.FileTest.EXISTS)) {
                    var f = GLib.File.new_for_path (plot_file);
                    try {
                        var info = f.query_info (GLib.FileAttribute.STANDARD_SIZE, GLib.FileQueryInfoFlags.NONE);
                        if (info.get_size () > 100) {
                            generated_plot = plot_file;
                            plot_generated (plot_file);
                        }
                    } catch (GLib.Error e) {}
                }

                return output_sb.str.strip ();
            } catch (GLib.Error e) {
                r_initialized = false;
                return @"✖ R evaluation error: $(e.message)";
            }
        }

        /**
         * Pillar 4: Shared State & Bidirectional Execution Session
         * Evaluates code in the persistent Python REPL. Variables, dataframes, and imports
         * remain alive in the workspace.
         */
        public async string execute_python (string code, out string? generated_plot) {
            generated_plot = null;
            ensure_python_session ();

            if (py_stdin == null || py_stdout == null) {
                return "✖ Python 3 interpreter not available on host system.";
            }

            string plot_dir = GLib.Path.build_filename (GLib.Environment.get_tmp_dir (), "imladris_plots");
            GLib.DirUtils.create_with_parents (plot_dir, 0755);
            string plot_file = GLib.Path.build_filename (plot_dir, @"plot_$(GLib.Random.next_int ()).png");

            bool has_plot = code.contains ("plt.") || code.contains ("matplotlib") ||
                            code.contains (".plot(") || code.contains ("sns.") ||
                            code.contains ("seaborn");

            var cmd_sb = new GLib.StringBuilder ();
            if (has_plot) {
                cmd_sb.append ("try:\n");
                cmd_sb.append ("    import matplotlib\n    matplotlib.use('Agg')\n    import matplotlib.pyplot as plt\n");
                string[] lines = code.split ("\n");
                foreach (var l in lines) {
                    cmd_sb.append ("    " + l + "\n");
                }
                cmd_sb.append_printf ("    plt.savefig('%s', dpi=120, bbox_inches='tight')\n", plot_file.replace ("\\", "/"));
                cmd_sb.append ("finally:\n");
                cmd_sb.append ("    try:\n        import matplotlib.pyplot as plt\n        plt.close('all')\n    except Exception:\n        pass\n\n");
            } else {
                cmd_sb.append (code + "\n\n");
            }

            string sentinel = @"__IMLADRIS_PY_DONE_$(GLib.Random.next_int ())__";
            cmd_sb.append_printf ("print('\\n%s')\n", sentinel);

            try {
                py_stdin.put_string (cmd_sb.str, null);
                py_stdin.flush ();

                var output_sb = new GLib.StringBuilder ();
                string? line = null;
                while (true) {
                    line = yield py_stdout.read_line_async (GLib.Priority.DEFAULT, null);
                    if (line == null) break;
                    if (line.contains (sentinel)) break;
                    output_sb.append (line + "\n");
                }

                if (has_plot && GLib.FileUtils.test (plot_file, GLib.FileTest.EXISTS)) {
                    var f = GLib.File.new_for_path (plot_file);
                    try {
                        var info = f.query_info (GLib.FileAttribute.STANDARD_SIZE, GLib.FileQueryInfoFlags.NONE);
                        if (info.get_size () > 100) {
                            generated_plot = plot_file;
                            plot_generated (plot_file);
                        }
                    } catch (GLib.Error e) {}
                }

                return output_sb.str.strip ();
            } catch (GLib.Error e) {
                py_initialized = false;
                return @"✖ Python evaluation error: $(e.message)";
            }
        }

        public void restart_all_sessions () {
            terminate_r ();
            terminate_python ();
        }

        public void interrupt_active_execution () {
            if (r_process != null) {
                r_process.send_signal (2); // SIGINT
            }
            if (py_process != null) {
                py_process.send_signal (2); // SIGINT
            }
        }

        private void ensure_r_session () {
            if (r_initialized && r_process != null) return;

            string? r_bin = GLib.Environment.find_program_in_path ("R");
            if (r_bin == null) r_bin = GLib.Environment.find_program_in_path ("Rscript");
            if (r_bin == null) return;

            try {
                // In sandboxed projects, .Rprofile sources renv/activate.R, so don't pass --no-init-file
                string[] argv = { r_bin, "--no-save", "--no-restore", "--quiet", "--interactive" };
                var launcher = new GLib.SubprocessLauncher (
                    GLib.SubprocessFlags.STDIN_PIPE | GLib.SubprocessFlags.STDOUT_PIPE | GLib.SubprocessFlags.STDERR_MERGE
                );
                if (current_working_dir != "" && GLib.FileUtils.test (current_working_dir, GLib.FileTest.IS_DIR)) {
                    launcher.set_cwd (current_working_dir);
                }

                r_process = launcher.spawnv (argv);
                r_stdin = new GLib.DataOutputStream (r_process.get_stdin_pipe ());
                r_stdout = new GLib.DataInputStream (r_process.get_stdout_pipe ());
                r_initialized = true;

                r_stdin.put_string ("options(prompt = '', continue = '', width = 120, warn = 1)\n", null);
                r_stdin.flush ();
            } catch (GLib.Error e) {
                r_initialized = false;
                GLib.warning ("Failed to launch persistent R session: %s", e.message);
            }
        }

        private void ensure_python_session () {
            if (py_initialized && py_process != null) return;

            string py_bin = "python3";
            // Check for sandboxed virtual environment python binary
            if (current_working_dir != "") {
                string venv_py = GLib.Path.build_filename (current_working_dir, ".venv", "bin", "python");
                if (GLib.FileUtils.test (venv_py, GLib.FileTest.IS_EXECUTABLE)) {
                    py_bin = venv_py;
                }
            }

            try {
                string[] argv = { py_bin, "-i", "-u" };
                var launcher = new GLib.SubprocessLauncher (
                    GLib.SubprocessFlags.STDIN_PIPE | GLib.SubprocessFlags.STDOUT_PIPE | GLib.SubprocessFlags.STDERR_MERGE
                );
                if (current_working_dir != "" && GLib.FileUtils.test (current_working_dir, GLib.FileTest.IS_DIR)) {
                    launcher.set_cwd (current_working_dir);
                }

                py_process = launcher.spawnv (argv);
                py_stdin = new GLib.DataOutputStream (py_process.get_stdin_pipe ());
                py_stdout = new GLib.DataInputStream (py_process.get_stdout_pipe ());
                py_initialized = true;

                py_stdin.put_string ("import sys\nsys.ps1 = ''\nsys.ps2 = ''\n", null);
                py_stdin.flush ();
            } catch (GLib.Error e) {
                py_initialized = false;
                GLib.warning ("Failed to launch persistent Python session: %s", e.message);
            }
        }

        private void terminate_r () {
            if (r_process != null) {
                try {
                    if (r_stdin != null) {
                        r_stdin.put_string ("q(save = 'no')\n", null);
                    }
                    r_process.force_exit ();
                } catch (GLib.Error e) {}
                r_process = null;
                r_stdin = null;
                r_stdout = null;
                r_initialized = false;
            }
        }

        private void terminate_python () {
            if (py_process != null) {
                try {
                    if (py_stdin != null) {
                        py_stdin.put_string ("exit()\n", null);
                    }
                    py_process.force_exit ();
                } catch (GLib.Error e) {}
                py_process = null;
                py_stdin = null;
                py_stdout = null;
                py_initialized = false;
            }
        }
    }
}
