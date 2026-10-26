namespace Imladris.Core {

    public enum RuntimeSource {
        PROJECT_SANDBOX,
        MANAGED_GLOBAL,
        HOST_FLATPAK_SPAWN,
        HOST_NATIVE,
        MISSING;

        public string to_display_string () {
            switch (this) {
                case PROJECT_SANDBOX:
                    return "Project Sandbox (.imladris-env)";
                case MANAGED_GLOBAL:
                    return "Managed Global Toolchain (base-ds)";
                case HOST_FLATPAK_SPAWN:
                    return "Host System (via Flatpak Portal)";
                case HOST_NATIVE:
                    return "Host System (Native PATH)";
                case MISSING:
                default:
                    return "Missing / Not Installed";
            }
        }
    }

    public class PlatformUtils : GLib.Object {

        private static bool? _is_flatpak_cached = null;
        private static GLib.HashTable<string, bool> _availability_cache = null;
        private static GLib.HashTable<string, string?> _path_cache = null;

        /**
         * Returns true if Imladris is running inside a Flatpak container sandbox.
         */
        public static bool is_flatpak () {
            if (_is_flatpak_cached == null) {
                bool exists = GLib.FileUtils.test ("/.flatpak-info", GLib.FileTest.EXISTS);
                bool env_set = GLib.Environment.get_variable ("FLATPAK_ID") != null;
                _is_flatpak_cached = exists || env_set;
            }
            return _is_flatpak_cached;
        }

        /**
         * Multi-Tier Runtime Resolution Hierarchy:
         * 1. Tier 1: Project-Local Sandbox (<project_dir>/.imladris-env or .venv)
         * 2. Tier 2: Managed Global Toolchain ($XDG_DATA_HOME/imladris/toolchains/mamba_root/envs/base-ds)
         * 3. Tier 3: Host System Fallback (flatpak-spawn --host or native PATH)
         * 4. Tier 4: Missing (not found)
         */
        public static RuntimeSource resolve_runtime (
            string binary_name,
            string? project_dir,
            out string? resolved_path,
            out string? env_prefix
        ) {
            resolved_path = null;
            env_prefix = null;

            // Direct executable path support
            if (binary_name.contains ("/") && GLib.FileUtils.test (binary_name, GLib.FileTest.IS_EXECUTABLE)) {
                resolved_path = binary_name;
                return RuntimeSource.HOST_NATIVE;
            }

            // Tier 1: Project-Local Sandbox
            if (project_dir != null && project_dir != "") {
                string imladris_env_bin = GLib.Path.build_filename (project_dir, ".imladris-env", "bin", binary_name);
                if (GLib.FileUtils.test (imladris_env_bin, GLib.FileTest.IS_EXECUTABLE)) {
                    resolved_path = imladris_env_bin;
                    env_prefix = GLib.Path.build_filename (project_dir, ".imladris-env");
                    return RuntimeSource.PROJECT_SANDBOX;
                }

                // Check Python virtual environment (.venv)
                if (binary_name == "python" || binary_name == "python3") {
                    string venv_py = GLib.Path.build_filename (project_dir, ".venv", "bin", "python");
                    if (GLib.FileUtils.test (venv_py, GLib.FileTest.IS_EXECUTABLE)) {
                        resolved_path = venv_py;
                        env_prefix = GLib.Path.build_filename (project_dir, ".venv");
                        return RuntimeSource.PROJECT_SANDBOX;
                    }
                }
            }

            // Tier 2: Managed Global Toolchain
            var tm = ToolchainManager.get_default ();
            string managed_bin = GLib.Path.build_filename (tm.default_env, "bin", binary_name);
            if (GLib.FileUtils.test (managed_bin, GLib.FileTest.IS_EXECUTABLE)) {
                resolved_path = managed_bin;
                env_prefix = tm.default_env;
                return RuntimeSource.MANAGED_GLOBAL;
            }

            // Tier 3: Host / System Environment Fallback
            string? local_path = GLib.Environment.find_program_in_path (binary_name);
            if (local_path != null) {
                resolved_path = local_path;
                return RuntimeSource.HOST_NATIVE;
            }

            if (is_flatpak ()) {
                if (check_host_program_available (binary_name)) {
                    resolved_path = resolve_host_program_path (binary_name) ?? binary_name;
                    return RuntimeSource.HOST_FLATPAK_SPAWN;
                }
            }

            // Tier 4: Missing
            return RuntimeSource.MISSING;
        }

        /**
         * Injects environment variables for a micromamba / conda-managed prefix.
         * Sets PATH, CONDA_PREFIX, PKG_CONFIG_PATH, R_HOME, QUARTO_PYTHON, and QUARTO_R.
         */
        public static void configure_managed_env (GLib.SubprocessLauncher launcher, string env_prefix) {
            string bin_dir = GLib.Path.build_filename (env_prefix, "bin");
            string lib_dir = GLib.Path.build_filename (env_prefix, "lib");
            string pkg_dir = GLib.Path.build_filename (lib_dir, "pkgconfig");
            string r_home = GLib.Path.build_filename (lib_dir, "R");

            string? current_path = GLib.Environment.get_variable ("PATH");
            string path_val = (current_path != null && current_path != "") ? @"$bin_dir:$current_path" : bin_dir;

            launcher.set_environ (GLib.Environment.list_variables ());
            launcher.setenv ("PATH", path_val, true);
            launcher.setenv ("CONDA_PREFIX", env_prefix, true);
            launcher.setenv ("PKG_CONFIG_PATH", pkg_dir, true);
            launcher.setenv ("R_HOME", r_home, true);

            string py_bin = GLib.Path.build_filename (bin_dir, "python3");
            if (GLib.FileUtils.test (py_bin, GLib.FileTest.EXISTS)) {
                launcher.setenv ("QUARTO_PYTHON", py_bin, true);
            }
            string r_bin = GLib.Path.build_filename (bin_dir, "R");
            if (GLib.FileUtils.test (r_bin, GLib.FileTest.EXISTS)) {
                launcher.setenv ("QUARTO_R", r_bin, true);
            }
        }

        /**
         * Checks if a program is available in any tier (Project sandbox, Managed global, or Host).
         */
        public static bool is_program_available (string program, string? project_dir = null) {
            init_caches ();

            string cache_key = (project_dir != null && project_dir != "") ? @"$program@$project_dir" : program;
            if (_availability_cache.contains (cache_key)) {
                return _availability_cache.lookup (cache_key);
            }

            string? resolved = null;
            string? env_pfx = null;
            RuntimeSource src = resolve_runtime (program, project_dir, out resolved, out env_pfx);
            bool available = (src != RuntimeSource.MISSING);

            _availability_cache.insert (cache_key, available);
            return available;
        }

        /**
         * Returns the resolved binary path for a program according to the 4-tier resolution hierarchy.
         */
        public static string? find_program (string program, string? project_dir = null) {
            init_caches ();

            string cache_key = (project_dir != null && project_dir != "") ? @"$program@$project_dir" : program;
            if (_path_cache.contains (cache_key)) {
                return _path_cache.lookup (cache_key);
            }

            string? resolved = null;
            string? env_pfx = null;
            resolve_runtime (program, project_dir, out resolved, out env_pfx);

            _path_cache.insert (cache_key, resolved);
            return resolved;
        }

        /**
         * Checks if R or Rscript is available in any tier.
         */
        public static bool is_r_available (string? project_dir = null) {
            return is_program_available ("R", project_dir) || is_program_available ("Rscript", project_dir);
        }

        /**
         * Builds a command that routes through the host system via flatpak-spawn
         * if running inside Flatpak.
         */
        public static string[] build_host_command (string[] argv, string? working_dir = null) {
            if (!is_flatpak ()) {
                return argv;
            }

            var list = new GLib.GenericArray<string> ();
            list.add ("flatpak-spawn");
            list.add ("--host");
            list.add ("--watch-bus");

            if (working_dir != null && working_dir != "") {
                list.add ("--directory=" + working_dir);
            }

            for (int i = 0; i < argv.length; i++) {
                list.add (argv[i]);
            }

            string[] result = new string[list.length];
            for (int i = 0; i < list.length; i++) {
                result[i] = list[i];
            }
            return result;
        }

        /**
         * Builds runtime command argv according to the 4-tier hierarchy.
         */
        public static string[] build_runtime_command (
            string binary_name,
            string[] sub_args,
            string? project_dir,
            out RuntimeSource source,
            out string? env_prefix
        ) {
            string? resolved_path = null;
            source = resolve_runtime (binary_name, project_dir, out resolved_path, out env_prefix);

            if (source == RuntimeSource.HOST_FLATPAK_SPAWN) {
                var full_argv = new string[1 + sub_args.length];
                full_argv[0] = binary_name;
                for (int i = 0; i < sub_args.length; i++) {
                    full_argv[i + 1] = sub_args[i];
                }
                return build_host_command (full_argv, project_dir);
            }

            string exe = (resolved_path != null) ? resolved_path : binary_name;
            var result = new string[1 + sub_args.length];
            result[0] = exe;
            for (int i = 0; i < sub_args.length; i++) {
                result[i + 1] = sub_args[i];
            }
            return result;
        }

        /**
         * Returns a host-accessible shared directory for cache, plots, and temporary files.
         * Creates directories with secure 0700 permissions.
         */
        public static string get_shared_cache_dir (string subdir = "") {
            string cache_dir = GLib.Path.build_filename (GLib.Environment.get_home_dir (), ".cache", "imladris");
            if (subdir != "") {
                cache_dir = GLib.Path.build_filename (cache_dir, subdir);
            }
            GLib.DirUtils.create_with_parents (cache_dir, 0700);
            return cache_dir;
        }

        /**
         * Clears runtime caches when a new toolchain is installed or removed.
         */
        public static void clear_caches () {
            if (_availability_cache != null) {
                _availability_cache.remove_all ();
            }
            if (_path_cache != null) {
                _path_cache.remove_all ();
            }
        }

        private static void init_caches () {
            if (_availability_cache == null) {
                _availability_cache = new GLib.HashTable<string, bool> (GLib.str_hash, GLib.str_equal);
            }
            if (_path_cache == null) {
                _path_cache = new GLib.HashTable<string, string?> (GLib.str_hash, GLib.str_equal);
            }
        }

        private static bool check_host_program_available (string program) {
            try {
                string[] argv = { "flatpak-spawn", "--host", "sh", "-c", "command -v \"$1\"", "_", program };
                var proc = new GLib.Subprocess.newv (argv, GLib.SubprocessFlags.STDOUT_PIPE | GLib.SubprocessFlags.STDERR_SILENCE);
                return proc.wait_check ();
            } catch (GLib.Error e) {
                return false;
            }
        }

        private static string? resolve_host_program_path (string program) {
            try {
                string[] argv = { "flatpak-spawn", "--host", "sh", "-c", "command -v \"$1\"", "_", program };
                var proc = new GLib.Subprocess.newv (argv, GLib.SubprocessFlags.STDOUT_PIPE | GLib.SubprocessFlags.STDERR_SILENCE);
                string? output = null;
                proc.communicate_utf8 (null, null, out output, null);
                if (output != null && output.strip ().length > 0) {
                    return output.strip ();
                }
            } catch (GLib.Error e) {}
            return null;
        }
    }
}
