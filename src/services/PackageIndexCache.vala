using Gtk;
using Adw;
using GLib;

namespace Imladris.UI {

    public enum PackageEcosystem {
        R_CRAN,
        PYTHON_PYPI
    }

    public enum InstallSourceMode {
        REPOSITORY,      // CRAN or PyPI (Search & Autocomplete)
        LOCAL_ARCHIVE,   // Local .tar.gz, .tgz, .zip, .whl via Gtk.FileDialog
        GIT_REMOTE       // GitHub/GitLab URL or user/repo (remotes::install_github / pip git+)
    }

    public enum PythonEngine {
        AUTO,  // Uses uv if found on PATH, otherwise pip
        UV,    // Force uv
        PIP    // Force python -m pip
    }

    public class EnvironmentTools : GLib.Object {
        public static bool has_uv () {
            return Core.PlatformUtils.is_program_available ("uv");
        }

        public static string get_uv_path () {
            return Core.PlatformUtils.find_program ("uv") ?? "uv";
        }

        public static bool has_r () {
            return Core.PlatformUtils.is_r_available ();
        }
    }

    public class ProjectContext : Object {
        public string root_dir { get; set; }
        public bool is_sandboxed { get; set; }
        public PackageEcosystem default_ecosystem { get; set; }
        public bool has_uv { get; private set; }

        public ProjectContext (string root_dir, bool is_sandboxed, PackageEcosystem default_ecosystem) {
            this.root_dir = root_dir;
            this.is_sandboxed = is_sandboxed;
            this.default_ecosystem = default_ecosystem;
            this.has_uv = EnvironmentTools.has_uv ();
        }
    }

    /**
     * Thread-safe asynchronous cache for CRAN (PACKAGES) and PyPI (PEP 691 JSON) indices
     * with ETag disk caching and O(log N) binary search autocomplete.
     */
    public class PackageIndexCache : Object {
        private GenericArray<string> cran_packages;
        private GenericArray<string> pypi_packages;
        private Soup.Session soup_session;
        private string cache_dir;

        public bool cran_ready { get; private set; default = false; }
        public bool pypi_ready { get; private set; default = false; }

        private static string[] DEFAULT_CRAN = {
            "BiocManager", "DBI", "RSQLite", "caret", "data.table", "devtools",
            "dplyr", "forcats", "future", "ggplot2", "httr2", "jsonlite",
            "knitr", "lme4", "lubridate", "magrittr", "patchwork", "plotly",
            "purrr", "quarto", "readr", "renv", "rmarkdown", "sf",
            "shiny", "stringr", "targets", "testthat", "tibble", "tidyr", "xml2"
        };

        private static string[] DEFAULT_PYPI = {
            "altair", "beautifulsoup4", "duckdb", "fastapi", "flask", "httpx",
            "jupyter", "matplotlib", "numpy", "optuna", "pandas", "pillow",
            "plotly", "polars", "pytest", "pyyaml", "requests", "rich",
            "scikit-learn", "scipy", "seaborn", "statsmodels", "sympy",
            "tensorflow", "torch", "transformers", "uv", "xgboost"
        };

        public PackageIndexCache () {
            cran_packages = new GenericArray<string> ();
            pypi_packages = new GenericArray<string> ();
            soup_session = new Soup.Session ();
            soup_session.user_agent = "Imladris-IDE/1.0";

            cache_dir = Path.build_filename (Environment.get_user_cache_dir (), "imladris", "indices");
            DirUtils.create_with_parents (cache_dir, 0755);

            load_from_disk_or_defaults ();
            check_and_refresh_indices.begin ();
        }

        private void load_from_disk_or_defaults () {
            string cran_file = Path.build_filename (cache_dir, "cran_index.txt");
            if (FileUtils.test (cran_file, FileTest.EXISTS)) {
                try {
                    string content;
                    FileUtils.get_contents (cran_file, out content);
                    string[] lines = content.split ("\n");
                    foreach (string l in lines) {
                        string s = l.strip ();
                        if (s.length > 0) cran_packages.add (s);
                    }
                    cran_packages.sort (strcmp);
                    cran_ready = true;
                } catch (Error e) {
                    populate_default_cran ();
                }
            } else {
                populate_default_cran ();
            }

            string pypi_file = Path.build_filename (cache_dir, "pypi_index.txt");
            if (FileUtils.test (pypi_file, FileTest.EXISTS)) {
                try {
                    string content;
                    FileUtils.get_contents (pypi_file, out content);
                    string[] lines = content.split ("\n");
                    foreach (string l in lines) {
                        string s = l.strip ();
                        if (s.length > 0) pypi_packages.add (s);
                    }
                    pypi_packages.sort (strcmp);
                    pypi_ready = true;
                } catch (Error e) {
                    populate_default_pypi ();
                }
            } else {
                populate_default_pypi ();
            }
        }

        private void populate_default_cran () {
            cran_packages.remove_range (0, cran_packages.length);
            foreach (var p in DEFAULT_CRAN) {
                cran_packages.add (p);
            }
            cran_packages.sort (strcmp);
        }

        private void populate_default_pypi () {
            pypi_packages.remove_range (0, pypi_packages.length);
            foreach (var p in DEFAULT_PYPI) {
                pypi_packages.add (p);
            }
            pypi_packages.sort (strcmp);
        }

        private async void check_and_refresh_indices () {
            int64 now = get_real_time () / 1000000;
            string last_sync_file = Path.build_filename (cache_dir, "last_sync.txt");
            int64 last_sync = 0;
            if (FileUtils.test (last_sync_file, FileTest.EXISTS)) {
                try {
                    string content;
                    FileUtils.get_contents (last_sync_file, out content);
                    last_sync = int64.parse (content.strip ());
                } catch (Error e) {}
            }

            // Only perform conditional network sync if cache is older than 24 hours (86400 seconds)
            if (now - last_sync > 86400) {
                try {
                    yield refresh_cran_index ();
                    yield refresh_pypi_index ();
                    FileUtils.set_contents (last_sync_file, now.to_string ());
                } catch (Error e) {
                    // Silently retain cached indices if offline
                }
            }
        }

        public async int refresh_cran_index (string mirror_url = "https://cloud.r-project.org") throws Error {
            string url = mirror_url.has_suffix ("/")
                ? mirror_url + "src/contrib/PACKAGES"
                : mirror_url + "/src/contrib/PACKAGES";

            string etag_file = Path.build_filename (cache_dir, "cran_etag.txt");
            string? stored_etag = null;
            if (FileUtils.test (etag_file, FileTest.EXISTS)) {
                try {
                    FileUtils.get_contents (etag_file, out stored_etag);
                    stored_etag = stored_etag.strip ();
                } catch (Error e) {}
            }

            var msg = new Soup.Message ("GET", url);
            if (stored_etag != null && stored_etag.length > 0) {
                msg.request_headers.append ("If-None-Match", stored_etag);
            }

            Bytes bytes = yield soup_session.send_and_read_async (msg, Priority.LOW, null);

            if (msg.status_code == Soup.Status.NOT_MODIFIED) {
                cran_ready = true;
                return cran_packages.length;
            }

            if (msg.status_code != Soup.Status.OK) {
                throw new IOError.FAILED ("CRAN HTTP %u: %s", msg.status_code, msg.reason_phrase);
            }

            unowned uint8[] raw_data = bytes.get_data ();
            string body = (string) raw_data;

            var temp_list = new GenericArray<string> ();
            var file_buf = new StringBuilder ();
            foreach (unowned string line in body.split ("\n")) {
                if (line.has_prefix ("Package:")) {
                    string pkg = line.substring (8).strip ();
                    if (pkg.length > 0) {
                        temp_list.add (pkg);
                        file_buf.append (pkg);
                        file_buf.append_c ('\n');
                    }
                }
            }

            temp_list.sort (strcmp);
            cran_packages = temp_list;
            cran_ready = true;

            // Persist to disk cache
            string cran_file = Path.build_filename (cache_dir, "cran_index.txt");
            FileUtils.set_contents (cran_file, file_buf.str);

            string? new_etag = msg.response_headers.get_one ("ETag");
            if (new_etag != null) {
                FileUtils.set_contents (etag_file, new_etag);
            }

            return cran_packages.length;
        }

        public async int refresh_pypi_index () throws Error {
            string etag_file = Path.build_filename (cache_dir, "pypi_etag.txt");
            string? stored_etag = null;
            if (FileUtils.test (etag_file, FileTest.EXISTS)) {
                try {
                    FileUtils.get_contents (etag_file, out stored_etag);
                    stored_etag = stored_etag.strip ();
                } catch (Error e) {}
            }

            var msg = new Soup.Message ("GET", "https://pypi.org/simple/");
            msg.request_headers.append ("Accept", "application/vnd.pypi.simple.v1+json");
            if (stored_etag != null && stored_etag.length > 0) {
                msg.request_headers.append ("If-None-Match", stored_etag);
            }

            Bytes bytes = yield soup_session.send_and_read_async (msg, Priority.LOW, null);

            if (msg.status_code == Soup.Status.NOT_MODIFIED) {
                pypi_ready = true;
                return pypi_packages.length;
            }

            if (msg.status_code != Soup.Status.OK) {
                throw new IOError.FAILED ("PyPI HTTP %u: %s", msg.status_code, msg.reason_phrase);
            }

            var parser = new Json.Parser ();
            var stream = new MemoryInputStream.from_bytes (bytes);
            yield parser.load_from_stream_async (stream, null);

            var root_obj = parser.get_root ().get_object ();
            var projects_arr = root_obj.get_array_member ("projects");

            var temp_list = new GenericArray<string> ();
            var file_buf = new StringBuilder ();
            uint len = projects_arr.get_length ();
            for (uint i = 0; i < len; i++) {
                var proj_obj = projects_arr.get_object_element (i);
                if (proj_obj.has_member ("name")) {
                    string name = proj_obj.get_string_member ("name");
                    temp_list.add (name);
                    file_buf.append (name);
                    file_buf.append_c ('\n');
                }
            }

            temp_list.sort (strcmp);
            pypi_packages = temp_list;
            pypi_ready = true;

            // Persist to disk cache
            string pypi_file = Path.build_filename (cache_dir, "pypi_index.txt");
            FileUtils.set_contents (pypi_file, file_buf.str);

            string? new_etag = msg.response_headers.get_one ("ETag");
            if (new_etag != null) {
                FileUtils.set_contents (etag_file, new_etag);
            }

            return pypi_packages.length;
        }

        /**
         * O(log N) binary search lower-bound lookup followed by prefix matching
         */
        public GenericArray<string> query_prefix (PackageEcosystem eco, string prefix, int limit = 12) {
            var results = new GenericArray<string> ();
            string clean = prefix.strip ().down ();
            if (clean.length < 2) {
                return results;
            }

            unowned GenericArray<string> source = (eco == PackageEcosystem.R_CRAN)
                ? cran_packages
                : pypi_packages;

            int n = source.length;
            if (n == 0) return results;

            // Binary search lower bound
            int low = 0;
            int high = n - 1;
            int start_idx = n;

            while (low <= high) {
                int mid = low + (high - low) / 2;
                string item_down = source[mid].down ();
                if (strcmp (item_down, clean) >= 0) {
                    start_idx = mid;
                    high = mid - 1;
                } else {
                    low = mid + 1;
                }
            }

            for (int i = start_idx; i < n && results.length < limit; i++) {
                string pkg = source[i];
                if (pkg.down ().has_prefix (clean)) {
                    results.add (pkg);
                } else {
                    break;
                }
            }

            return results;
        }
    }
}
