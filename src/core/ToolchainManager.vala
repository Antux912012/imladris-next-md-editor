namespace Imladris.Core {

    public class ToolchainManager : GLib.Object {

        private static ToolchainManager? _instance = null;

        public static ToolchainManager get_default () {
            if (_instance == null) {
                _instance = new ToolchainManager ();
            }
            return _instance;
        }

        public signal void progress_changed (string step, double fraction, string detail);
        public signal void log_output (string line);

        private string _base_dir;
        public string base_dir { get { return _base_dir; } }

        private string _bin_dir;
        public string bin_dir { get { return _bin_dir; } }

        private string _mamba_bin;
        public string mamba_bin { get { return _mamba_bin; } }

        private string _mamba_root;
        public string mamba_root { get { return _mamba_root; } }

        private string _default_env;
        public string default_env { get { return _default_env; } }

        private string _state_file;
        public string state_file { get { return _state_file; } }

        public ToolchainManager () {
            _base_dir = GLib.Path.build_filename (GLib.Environment.get_user_data_dir (), "imladris", "toolchains");
            _bin_dir = GLib.Path.build_filename (_base_dir, "bin");
            _mamba_bin = GLib.Path.build_filename (_bin_dir, "micromamba");
            _mamba_root = GLib.Path.build_filename (_base_dir, "mamba_root");
            _default_env = GLib.Path.build_filename (_mamba_root, "envs", "base-ds");
            _state_file = GLib.Path.build_filename (_base_dir, "state.json");
        }

        /**
         * Returns the platform architecture string expected by micromamba APIs.
         */
        public static string get_platform_arch () {
            try {
                string output;
                GLib.Process.spawn_command_line_sync ("uname -m", out output, null, null);
                string arch = output.strip ();
                if (arch == "aarch64" || arch == "arm64") {
                    return "linux-aarch64";
                }
            } catch (GLib.Error e) {}
            return "linux-64";
        }

        public bool is_micromamba_installed () {
            return GLib.FileUtils.test (mamba_bin, GLib.FileTest.IS_EXECUTABLE);
        }

        public bool is_base_environment_installed () {
            return has_r () || has_python ();
        }

        public bool has_r () {
            string r_path = GLib.Path.build_filename (default_env, "bin", "R");
            return GLib.FileUtils.test (r_path, GLib.FileTest.IS_EXECUTABLE);
        }

        public bool has_python () {
            string py_path = GLib.Path.build_filename (default_env, "bin", "python3");
            return GLib.FileUtils.test (py_path, GLib.FileTest.IS_EXECUTABLE);
        }

        public bool has_quarto () {
            string q_path = GLib.Path.build_filename (default_env, "bin", "quarto");
            return GLib.FileUtils.test (q_path, GLib.FileTest.IS_EXECUTABLE);
        }

        /**
         * Ensures the micromamba binary exists at $XDG_DATA_HOME/imladris/toolchains/bin/micromamba.
         * Downloads and extracts the official static binary if absent.
         */
        public async bool ensure_micromamba_async () {
            if (is_micromamba_installed ()) {
                return true;
            }

            progress_changed ("Preparing toolchain directory...", 0.05, "Creating directories");
            GLib.DirUtils.create_with_parents (bin_dir, 0755);
            GLib.DirUtils.create_with_parents (mamba_root, 0755);

            string arch = get_platform_arch ();
            string url = @"https://micro.mamba.pm/api/micromamba/$arch/latest";

            log_output (@"▶ Downloading micromamba ($arch) from $url...");
            progress_changed ("Downloading micromamba...", 0.15, url);

            try {
                // Safely stream download through curl and tar extracting only bin/micromamba
                string[] argv = {
                    "sh", "-c",
                    "curl -Ls \"$1\" | tar -xvj -C \"$2\" --strip-components=1 bin/micromamba",
                    "_",
                    url,
                    bin_dir
                };

                var proc = new GLib.Subprocess.newv (argv, GLib.SubprocessFlags.STDOUT_PIPE | GLib.SubprocessFlags.STDERR_PIPE);
                var stdout_stream = new GLib.DataInputStream (proc.get_stdout_pipe ());
                var stderr_stream = new GLib.DataInputStream (proc.get_stderr_pipe ());

                // Read output concurrently
                read_stream_to_log.begin (stdout_stream);
                read_stream_to_log.begin (stderr_stream);

                yield proc.wait_check_async ();

                if (is_micromamba_installed ()) {
                    GLib.FileUtils.chmod (mamba_bin, 0755);
                    log_output ("✔ micromamba binary installed successfully: " + mamba_bin);
                    progress_changed ("micromamba engine ready", 0.30, mamba_bin);
                    return true;
                } else {
                    log_output ("✖ micromamba binary not found after extraction.");
                    return false;
                }
            } catch (GLib.Error e) {
                log_output (@"✖ Failed to download or extract micromamba: $(e.message)");
                return false;
            }
        }

        /**
         * Installs or updates the shared Data Science environment (base-ds) using micromamba.
         */
        public async bool create_or_update_base_environment_async (
            bool install_r = true,
            bool install_python = true,
            bool install_quarto = true,
            bool install_tidyverse = true
        ) {
            bool mamba_ok = yield ensure_micromamba_async ();
            if (!mamba_ok) {
                log_output ("✖ Aborting environment creation: micromamba binary is missing.");
                return false;
            }

            var pkgs = new GLib.GenericArray<string> ();

            if (install_python) {
                pkgs.add ("python=3.12");
                pkgs.add ("pip");
                pkgs.add ("ipykernel");
                pkgs.add ("jupyter_client");
                pkgs.add ("uv");
            }

            if (install_r) {
                pkgs.add ("r-base=4.4");
                pkgs.add ("r-irkernel");
                pkgs.add ("r-remotes");
                pkgs.add ("r-pak");
                pkgs.add ("compilers");
                pkgs.add ("make");
                pkgs.add ("pkg-config");
                pkgs.add ("libcurl");
                pkgs.add ("openssl");
                pkgs.add ("libxml2");

                if (install_tidyverse) {
                    pkgs.add ("r-tidyverse");
                    pkgs.add ("r-data.table");
                    pkgs.add ("r-rmarkdown");
                    pkgs.add ("r-knitr");
                }
            }

            if (install_quarto) {
                pkgs.add ("quarto");
                pkgs.add ("typst");
            }

            if (pkgs.length == 0) {
                log_output ("ℹ No components selected for installation.");
                return true;
            }

            progress_changed ("Resolving conda-forge packages...", 0.35, "Connecting to conda-forge");
            log_output (@"▶ Provisioning base-ds environment with $(pkgs.length) packages from conda-forge...");

            var cmd = new GLib.GenericArray<string> ();
            cmd.add (mamba_bin);
            cmd.add ("create");
            cmd.add ("-y");
            cmd.add ("-r");
            cmd.add (mamba_root);
            cmd.add ("-n");
            cmd.add ("base-ds");
            cmd.add ("-c");
            cmd.add ("conda-forge");
            cmd.add ("--override-channels");

            for (int i = 0; i < pkgs.length; i++) {
                cmd.add (pkgs[i]);
            }

            string[] argv = new string[cmd.length];
            for (int i = 0; i < cmd.length; i++) {
                argv[i] = cmd[i];
            }

            try {
                var launcher = new GLib.SubprocessLauncher (
                    GLib.SubprocessFlags.STDOUT_PIPE | GLib.SubprocessFlags.STDERR_MERGE
                );
                launcher.setenv ("MAMBA_ROOT_PREFIX", mamba_root, true);

                var proc = launcher.spawnv (argv);
                var stdout_stream = new GLib.DataInputStream (proc.get_stdout_pipe ());

                double progress_val = 0.35;
                while (true) {
                    string? line = yield stdout_stream.read_line_async (GLib.Priority.DEFAULT, null);
                    if (line == null) break;

                    string trimmed = line.strip ();
                    if (trimmed.length > 0) {
                        log_output (trimmed);

                        // Parse simple download/extraction progress hints
                        if (trimmed.contains ("Downloading") || trimmed.contains ("Extracting")) {
                            if (progress_val < 0.90) {
                                progress_val += 0.02;
                                progress_changed ("Downloading and extracting packages...", progress_val, trimmed);
                            }
                        } else if (trimmed.contains ("Transaction finished") || trimmed.contains ("Linking")) {
                            progress_val = 0.92;
                            progress_changed ("Linking packages into base-ds environment...", progress_val, trimmed);
                        }
                    }
                }

                yield proc.wait_check_async ();

                // Phase 4: Configure Rprofile.site for seamless CRAN source compilation
                if (install_r && has_r ()) {
                    configure_rprofile_site (default_env);
                }

                save_state (install_r, install_python, install_quarto, install_tidyverse);
                progress_changed ("Toolchain installed successfully", 1.0, "Ready to execute R, Python & Quarto");
                log_output ("✔ Imladris Managed Toolchain (base-ds) provisioned successfully.");
                return true;
            } catch (GLib.Error e) {
                log_output (@"✖ Failed to create base-ds toolchain: $(e.message)");
                progress_changed ("Installation failed", 0.0, e.message);
                return false;
            }
        }

        /**
         * Configures $MAMBA_ROOT_PREFIX/envs/<env>/lib/R/etc/Rprofile.site so standard
         * install.packages() calls automatically use cloud CRAN and multi-core compilation.
         */
        public void configure_rprofile_site (string env_prefix) {
            string etc_dir = GLib.Path.build_filename (env_prefix, "lib", "R", "etc");
            GLib.DirUtils.create_with_parents (etc_dir, 0755);

            string rprofile_path = GLib.Path.build_filename (etc_dir, "Rprofile.site");
            string existing = "";
            if (GLib.FileUtils.test (rprofile_path, GLib.FileTest.EXISTS)) {
                try {
                    GLib.FileUtils.get_contents (rprofile_path, out existing);
                } catch (GLib.Error e) {}
            }

            if (!existing.contains ("Managed by Imladris Toolchain Manager")) {
                string snippet = """

# --- Managed by Imladris Toolchain Manager ---
local({
  r_repos <- getOption("repos")
  if (is.null(r_repos) || identical(r_repos["CRAN"], "@CRAN@")) {
    r_repos["CRAN"] <- "https://cloud.r-project.org"
    options(repos = r_repos)
  }
  # Ensure parallel compilation uses available CPU cores
  options(Ncpus = max(1L, parallel::detectCores() - 1L))
})
""";
                try {
                    GLib.FileUtils.set_contents (rprofile_path, existing + snippet);
                    log_output ("✔ Configured Rprofile.site for automated CRAN package compilation.");
                } catch (GLib.Error e) {
                    log_output (@"✖ Warning: Could not write Rprofile.site: $(e.message)");
                }
            }
        }

        /**
         * Creates an isolated project sandbox prefix at <project_path>/.imladris-env
         * reusing packages already cached in mamba_root/pkgs via hardlinks.
         */
        public async bool create_project_sandbox_async (
            string project_path,
            bool include_r = true,
            bool include_python = true,
            bool include_quarto = false
        ) {
            if (!is_micromamba_installed ()) {
                bool ok = yield ensure_micromamba_async ();
                if (!ok) return false;
            }

            string sandbox_prefix = GLib.Path.build_filename (project_path, ".imladris-env");
            log_output (@"▶ Initializing project sandbox in $sandbox_prefix...");

            var cmd = new GLib.GenericArray<string> ();
            cmd.add (mamba_bin);
            cmd.add ("create");
            cmd.add ("-y");
            cmd.add ("-r");
            cmd.add (mamba_root);
            cmd.add ("-p");
            cmd.add (sandbox_prefix);
            cmd.add ("-c");
            cmd.add ("conda-forge");
            cmd.add ("--override-channels");

            if (include_python) {
                cmd.add ("python=3.12");
                cmd.add ("ipykernel");
                cmd.add ("uv");
            }
            if (include_r) {
                cmd.add ("r-base=4.4");
                cmd.add ("r-irkernel");
                cmd.add ("r-pak");
                cmd.add ("compilers");
                cmd.add ("make");
                cmd.add ("pkg-config");
            }
            if (include_quarto) {
                cmd.add ("quarto");
            }

            string[] argv = new string[cmd.length];
            for (int i = 0; i < cmd.length; i++) {
                argv[i] = cmd[i];
            }

            try {
                var launcher = new GLib.SubprocessLauncher (
                    GLib.SubprocessFlags.STDOUT_PIPE | GLib.SubprocessFlags.STDERR_MERGE
                );
                launcher.setenv ("MAMBA_ROOT_PREFIX", mamba_root, true);

                var proc = launcher.spawnv (argv);
                var stdout_stream = new GLib.DataInputStream (proc.get_stdout_pipe ());

                while (true) {
                    string? line = yield stdout_stream.read_line_async (GLib.Priority.DEFAULT, null);
                    if (line == null) break;
                    string trimmed = line.strip ();
                    if (trimmed.length > 0) {
                        log_output (trimmed);
                    }
                }

                yield proc.wait_check_async ();

                if (include_r) {
                    configure_rprofile_site (sandbox_prefix);
                }

                log_output ("✔ Project sandbox .imladris-env initialized.");
                return true;
            } catch (GLib.Error e) {
                log_output (@"✖ Failed to scaffold project sandbox: $(e.message)");
                return false;
            }
        }

        /**
         * Returns estimated disk space occupied by toolchains directory in bytes.
         */
        public int64 get_toolchain_disk_usage () {
            if (!GLib.FileUtils.test (base_dir, GLib.FileTest.IS_DIR)) {
                return 0;
            }
            return compute_dir_size (base_dir);
        }

        private int64 compute_dir_size (string path) {
            int64 total = 0;
            try {
                var dir = GLib.Dir.open (path, 0);
                string? name = null;
                while ((name = dir.read_name ()) != null) {
                    string sub = GLib.Path.build_filename (path, name);
                    if (GLib.FileUtils.test (sub, GLib.FileTest.IS_DIR) && !GLib.FileUtils.test (sub, GLib.FileTest.IS_SYMLINK)) {
                        total += compute_dir_size (sub);
                    } else {
                        var file = GLib.File.new_for_path (sub);
                        try {
                            var info = file.query_info (GLib.FileAttribute.STANDARD_SIZE, GLib.FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
                            total += info.get_size ();
                        } catch (GLib.Error e) {}
                    }
                }
            } catch (GLib.Error e) {}
            return total;
        }

        private async void read_stream_to_log (GLib.DataInputStream stream) {
            try {
                while (true) {
                    string? line = yield stream.read_line_async (GLib.Priority.DEFAULT, null);
                    if (line == null) break;
                    string trimmed = line.strip ();
                    if (trimmed.length > 0) {
                        log_output (trimmed);
                    }
                }
            } catch (GLib.Error e) {}
        }

        private void save_state (bool has_r_pkg, bool has_py_pkg, bool has_q_pkg, bool has_tidy_pkg) {
            try {
                var builder = new Json.Builder ();
                builder.begin_object ();
                builder.set_member_name ("installed_at");
                builder.add_string_value (new GLib.DateTime.now_local ().to_string ());

                builder.set_member_name ("components");
                builder.begin_object ();
                builder.set_member_name ("r");
                builder.add_boolean_value (has_r_pkg);
                builder.set_member_name ("r_tidyverse");
                builder.add_boolean_value (has_tidy_pkg);
                builder.set_member_name ("python");
                builder.add_boolean_value (has_py_pkg);
                builder.set_member_name ("quarto");
                builder.add_boolean_value (has_q_pkg);
                builder.end_object ();

                builder.end_object ();

                var generator = new Json.Generator ();
                var root = builder.get_root ();
                generator.set_root (root);
                generator.to_file (state_file);
            } catch (GLib.Error e) {}
        }
    }
}
