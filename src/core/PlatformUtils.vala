namespace Imladris.Core {

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
         * Checks if a program is available either in the local environment or on the host system.
         */
        public static bool is_program_available (string program) {
            init_caches ();

            if (_availability_cache.contains (program)) {
                return _availability_cache.lookup (program);
            }

            // 1. Check local environment first
            if (GLib.Environment.find_program_in_path (program) != null) {
                _availability_cache.insert (program, true);
                return true;
            }

            // 2. If running inside Flatpak, check the host system via flatpak-spawn
            if (is_flatpak ()) {
                bool on_host = check_host_program_available (program);
                _availability_cache.insert (program, on_host);
                return on_host;
            }

            _availability_cache.insert (program, false);
            return false;
        }

        /**
         * Returns the resolved binary path for a program, checking local PATH first then host.
         */
        public static string? find_program (string program) {
            init_caches ();

            if (_path_cache.contains (program)) {
                return _path_cache.lookup (program);
            }

            string? local_path = GLib.Environment.find_program_in_path (program);
            if (local_path != null) {
                _path_cache.insert (program, local_path);
                return local_path;
            }

            if (is_flatpak ()) {
                string? host_path = resolve_host_program_path (program);
                _path_cache.insert (program, host_path);
                return host_path;
            }

            _path_cache.insert (program, null);
            return null;
        }

        /**
         * Checks if R or Rscript is available either locally or on the host.
         */
        public static bool is_r_available () {
            return is_program_available ("R") || is_program_available ("Rscript");
        }

        /**
         * Builds a command that transparently routes through the host system via flatpak-spawn
         * if running inside a Flatpak container.
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
         * Returns a host-accessible shared directory for cache, plots, and temporary files.
         * In Flatpak, ~/.cache/imladris is mounted into the sandbox and is identical on both host and sandbox.
         */
        public static string get_shared_cache_dir (string subdir = "") {
            string cache_dir = GLib.Path.build_filename (GLib.Environment.get_home_dir (), ".cache", "imladris");
            if (subdir != "") {
                cache_dir = GLib.Path.build_filename (cache_dir, subdir);
            }
            GLib.DirUtils.create_with_parents (cache_dir, 0755);
            return cache_dir;
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
