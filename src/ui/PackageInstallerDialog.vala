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
            try {
                DirUtils.create_with_parents (cache_dir, 0755);
            } catch (Error e) {
                // Ignore directory creation error
            }

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

    /**
     * Modern Libadwaita Package Installer Modal Dialog with CRAN, Manual and uv/pip integration
     */
    public class PackageInstallerModal : Adw.Dialog {
        public signal void execute_r_command (string r_code);
        public signal void execute_python_command (string python_bin, string[] args, string working_dir, bool is_sandboxed);

        private ProjectContext context;
        private PackageIndexCache cache;

        private Adw.ViewStack view_stack;
        private Adw.ViewSwitcher view_switcher;
        private Adw.ComboRow ecosystem_row;
        private Adw.ComboRow py_engine_row;
        private Adw.ComboRow cran_mirror_row;
        private Gtk.Entry package_entry;
        private Gtk.FlowBox curated_flow_box;
        private Gtk.Entry archive_entry;
        private Gtk.Button browse_archive_btn;
        private Adw.SwitchRow editable_switch_row;
        private Gtk.Entry git_entry;
        private Gtk.Entry git_branch_entry;

        private Gtk.Popover completion_popover;
        private Gtk.ListBox completion_list;
        private Adw.ActionRow target_lib_row;
        private Gtk.Label sandbox_badge;
        private Adw.SwitchRow deps_switch_row;
        private Gtk.Button install_btn;

        public PackageInstallerModal (ProjectContext context, PackageIndexCache cache) {
            Object (
                title: "Install Packages",
                content_width: 580,
                content_height: 520
            );
            this.context = context;
            this.cache = cache;

            build_ui ();
            connect_signals ();
            update_ui_for_ecosystem (ecosystem_row.selected);
            load_repositories_async.begin ();
        }

        private void build_ui () {
            var toolbar_view = new Adw.ToolbarView ();
            var header_bar = new Adw.HeaderBar ();

            view_stack = new Adw.ViewStack ();
            view_switcher = new Adw.ViewSwitcher () {
                stack = view_stack,
                policy = Adw.ViewSwitcherPolicy.WIDE
            };
            header_bar.title_widget = view_switcher;

            var cancel_btn = new Gtk.Button.with_label ("Cancel");
            cancel_btn.clicked.connect (() => {
                this.close ();
            });
            header_bar.pack_start (cancel_btn);

            install_btn = new Gtk.Button.with_label ("Install") {
                sensitive = false
            };
            install_btn.add_css_class ("suggested-action");
            header_bar.pack_end (install_btn);

            toolbar_view.add_top_bar (header_bar);

            var main_scroller = new Gtk.ScrolledWindow () {
                hscrollbar_policy = Gtk.PolicyType.NEVER,
                vscrollbar_policy = Gtk.PolicyType.AUTOMATIC,
                vexpand = true,
                hexpand = true
            };

            var main_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 16) {
                margin_top = 16,
                margin_bottom = 16,
                margin_start = 20,
                margin_end = 20
            };

            // 1. Ecosystem & Shared Engine Configuration
            var config_group = new Adw.PreferencesGroup () {
                title = "Environment & Tooling"
            };

            var eco_model = new Gtk.StringList ({
                "R Language (CRAN)",
                "Python (PyPI / Virtual Environment)"
            });

            ecosystem_row = new Adw.ComboRow () {
                title = "Ecosystem:",
                subtitle = "Package language and environment target",
                model = eco_model,
                selected = (context.default_ecosystem == PackageEcosystem.R_CRAN) ? 0 : 1
            };
            config_group.add (ecosystem_row);

            string py_subtitle = context.has_uv
                ? "⚡ uv detected in PATH (10-100x faster execution)"
                : "Standard python3 -m pip (uv not found in PATH)";

            py_engine_row = new Adw.ComboRow () {
                title = "Python Package Engine:",
                subtitle = py_subtitle,
                model = new Gtk.StringList ({
                    context.has_uv ? "⚡ uv (Ultra-fast — Recommended)" : "uv (Not installed)",
                    "pip (Standard Python Installer)"
                }),
                selected = context.has_uv ? 0 : 1
            };
            config_group.add (py_engine_row);

            var mirror_model = new Gtk.StringList ({
                "Cloud R-Project (https://cloud.r-project.org)",
                "Posit Package Manager (Precompiled Linux Binaries)"
            });
            cran_mirror_row = new Adw.ComboRow () {
                title = "CRAN Repository Mirror:",
                subtitle = "Source mirror for R packages",
                model = mirror_model,
                selected = 0
            };
            config_group.add (cran_mirror_row);

            target_lib_row = new Adw.ActionRow () {
                title = "Target Library:"
            };
            sandbox_badge = new Gtk.Label ("") {
                valign = Gtk.Align.CENTER
            };
            target_lib_row.add_suffix (sandbox_badge);
            config_group.add (target_lib_row);

            deps_switch_row = new Adw.SwitchRow () {
                title = "Install Dependencies",
                subtitle = "Automatically resolve and install required upstream packages",
                active = true
            };
            config_group.add (deps_switch_row);

            main_box.append (config_group);

            // =================================================================
            // TAB 1: REPOSITORY (Search, Autocomplete, Quick Bundles)
            // =================================================================
            var repo_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);

            var curated_label = new Gtk.Label ("Curated Popular Packages (click to add):") {
                halign = Gtk.Align.START,
                css_classes = { "dim-label", "caption", "heading" }
            };
            repo_box.append (curated_label);

            curated_flow_box = new Gtk.FlowBox () {
                selection_mode = Gtk.SelectionMode.NONE,
                max_children_per_line = 6,
                min_children_per_line = 3,
                row_spacing = 4,
                column_spacing = 4
            };
            repo_box.append (curated_flow_box);

            var repo_input_group = new Adw.PreferencesGroup () {
                title = "Package Names (separate multiple with space or comma)"
            };

            var entry_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 4);
            package_entry = new Gtk.Entry () {
                placeholder_text = "e.g., tidyverse, data.table, ggplot2",
                hexpand = true
            };

            completion_list = new Gtk.ListBox () {
                selection_mode = Gtk.SelectionMode.SINGLE
            };
            completion_list.add_css_class ("boxed-list");

            var completion_scroller = new Gtk.ScrolledWindow () {
                hscrollbar_policy = Gtk.PolicyType.NEVER,
                vscrollbar_policy = Gtk.PolicyType.AUTOMATIC,
                min_content_height = 140,
                max_content_height = 200,
                child = completion_list
            };

            completion_popover = new Gtk.Popover () {
                autohide = false,
                has_arrow = false,
                position = Gtk.PositionType.BOTTOM,
                child = completion_scroller
            };
            completion_popover.set_parent (package_entry);

            entry_box.append (package_entry);
            repo_input_group.add (entry_box);
            repo_box.append (repo_input_group);

            // =================================================================
            // TAB 2: LOCAL ARCHIVE (.tar.gz, .tgz, .zip, .whl)
            // =================================================================
            var local_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            var local_group = new Adw.PreferencesGroup () {
                title = "Install From Local Package Archive"
            };

            var archive_row = new Adw.ActionRow () {
                title = "Package File:",
                subtitle = "Select a local source or binary package archive (.tar.gz, .tgz, .whl, .zip)"
            };

            archive_entry = new Gtk.Entry () {
                placeholder_text = "/path/to/package_archive.tar.gz",
                hexpand = true,
                valign = Gtk.Align.CENTER
            };
            archive_row.add_suffix (archive_entry);

            browse_archive_btn = new Gtk.Button.from_icon_name ("folder-open-symbolic") {
                tooltip_text = "Browse for local package archive...",
                valign = Gtk.Align.CENTER
            };
            browse_archive_btn.add_css_class ("flat");
            browse_archive_btn.clicked.connect (on_browse_archive);
            archive_row.add_suffix (browse_archive_btn);
            local_group.add (archive_row);

            editable_switch_row = new Adw.SwitchRow () {
                title = "Editable Development Mode (-e)",
                subtitle = "Install local directory in editable mode for active code development",
                active = false
            };
            local_group.add (editable_switch_row);
            local_box.append (local_group);

            // =================================================================
            // TAB 3: GIT REMOTE (GitHub, GitLab, Git URL)
            // =================================================================
            var git_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            var git_group = new Adw.PreferencesGroup () {
                title = "Install From Remote Git Repository"
            };

            var git_repo_row = new Adw.ActionRow () {
                title = "Git Repository:",
                subtitle = "R: username/repo or URL • Python: git+https://... URL"
            };
            git_entry = new Gtk.Entry () {
                placeholder_text = "e.g., tidyverse/ggplot2 or https://github.com/psf/requests.git",
                hexpand = true,
                valign = Gtk.Align.CENTER
            };
            git_repo_row.add_suffix (git_entry);
            git_group.add (git_repo_row);

            var git_branch_row = new Adw.ActionRow () {
                title = "Branch / Tag / Ref (Optional):",
                subtitle = "Specify branch, tag, or commit SHA"
            };
            git_branch_entry = new Gtk.Entry () {
                placeholder_text = "e.g., main, dev, v2.0.0 (default: HEAD)",
                hexpand = true,
                valign = Gtk.Align.CENTER
            };
            git_branch_row.add_suffix (git_branch_entry);
            git_group.add (git_branch_row);
            git_box.append (git_group);

            // Add pages to ViewStack
            view_stack.add_titled_with_icon (repo_box, "repo", "Repository", "network-server-symbolic");
            view_stack.add_titled_with_icon (local_box, "local", "Local Archive", "folder-symbolic");
            view_stack.add_titled_with_icon (git_box, "git", "Git URL", "emblem-symbolic-link");

            main_box.append (view_stack);
            main_scroller.set_child (main_box);
            toolbar_view.set_content (main_scroller);
            this.set_child (toolbar_view);
        }

        private void connect_signals () {
            ecosystem_row.notify["selected"].connect (() => {
                completion_popover.popdown ();
                update_ui_for_ecosystem (ecosystem_row.selected);
                populate_curated_chips ();
                update_install_button_sensitivity ();
            });

            view_stack.notify["visible-child-name"].connect (() => {
                completion_popover.popdown ();
                update_install_button_sensitivity ();
            });

            package_entry.changed.connect (() => {
                on_package_entry_changed ();
                update_install_button_sensitivity ();
            });

            archive_entry.changed.connect (() => {
                update_install_button_sensitivity ();
            });

            git_entry.changed.connect (() => {
                update_install_button_sensitivity ();
            });

            completion_list.row_activated.connect ((row) => {
                var label = row.get_child () as Gtk.Label;
                if (label == null) return;

                string selected_pkg = label.get_text ();
                string current_text = package_entry.get_text ();

                int last_sep = -1;
                for (int i = current_text.length - 1; i >= 0; i--) {
                    char c = current_text[i];
                    if (c == ',' || c == ' ') {
                        last_sep = i;
                        break;
                    }
                }

                string new_text;
                if (last_sep >= 0) {
                    string prefix = current_text.substring (0, last_sep + 1).strip ();
                    if (!prefix.has_suffix (",")) {
                        prefix += ",";
                    }
                    new_text = "%s %s, ".printf (prefix, selected_pkg);
                } else {
                    new_text = "%s, ".printf (selected_pkg);
                }

                package_entry.set_text (new_text);
                package_entry.set_position (-1);
                completion_popover.popdown ();
            });

            var key_ctrl = new Gtk.EventControllerKey ();
            key_ctrl.key_pressed.connect ((keyval, keycode, state) => {
                if (keyval == Gdk.Key.Escape && completion_popover.get_visible ()) {
                    completion_popover.popdown ();
                    return true;
                }
                return false;
            });
            package_entry.add_controller (key_ctrl);

            install_btn.clicked.connect (on_install_clicked);
        }

        private void update_ui_for_ecosystem (uint selected_idx) {
            bool is_r = (selected_idx == 0);

            py_engine_row.visible = !is_r;
            cran_mirror_row.visible = is_r;
            editable_switch_row.visible = !is_r;

            if (is_r) {
                package_entry.placeholder_text = "e.g., tidyverse, data.table, ggplot2, DESeq2";
            } else {
                package_entry.placeholder_text = "e.g., numpy, pandas, polars, scipy==1.14.1";
            }

            if (context.is_sandboxed) {
                sandbox_badge.set_text ("Sandboxed (Isolated)");
                sandbox_badge.set_css_classes ({ "success", "caption", "heading" });
                string rel_path = is_r
                    ? Path.build_filename (context.root_dir, "renv", "library")
                    : Path.build_filename (context.root_dir, ".venv", "lib", "python", "site-packages");
                target_lib_row.subtitle = "%s [Portable Lockfile Active]".printf (rel_path);
            } else {
                sandbox_badge.set_text ("System Global");
                sandbox_badge.set_css_classes ({ "warning", "caption", "heading" });
                target_lib_row.subtitle = is_r
                    ? "System User Library (R_LIBS_USER) — Non-portable across machines"
                    : "System Python Site-Packages — Non-portable across machines";
            }

            populate_curated_chips ();
        }

        private void populate_curated_chips () {
            // Remove previous chips
            Gtk.Widget? child = curated_flow_box.get_first_child ();
            while (child != null) {
                Gtk.Widget? next = child.get_next_sibling ();
                curated_flow_box.remove (child);
                child = next;
            }

            bool is_r = (ecosystem_row.selected == 0);
            string[] bundles;
            if (is_r) {
                bundles = { "tidyverse", "data.table", "ggplot2", "shiny", "rmarkdown", "quarto", "devtools", "BiocManager" };
            } else {
                bundles = { "numpy", "pandas", "polars", "matplotlib", "scipy", "scikit-learn", "torch", "jupyter" };
            }

            foreach (string pkg in bundles) {
                var btn = new Gtk.Button.with_label (pkg);
                btn.add_css_class ("flat");
                btn.add_css_class ("chip-button");
                btn.clicked.connect (() => {
                    append_package_to_entry (pkg);
                });
                curated_flow_box.append (btn);
            }
        }

        private void append_package_to_entry (string pkg) {
            string current = package_entry.get_text ().strip ();
            if (current.length == 0) {
                package_entry.set_text (pkg);
            } else {
                string[] parts = current.split (",");
                bool already_there = false;
                foreach (var p in parts) {
                    if (p.strip ().down () == pkg.down ()) {
                        already_there = true;
                        break;
                    }
                }
                if (!already_there) {
                    if (!current.has_suffix (",")) current += ", ";
                    else current += " ";
                    package_entry.set_text (current + pkg);
                }
            }
            package_entry.set_position (-1);
        }

        private void on_browse_archive () {
            var dialog = new Gtk.FileDialog () {
                title = "Select Package Archive"
            };

            var filter = new Gtk.FileFilter ();
            filter.set_filter_name ("Package Archives (*.tar.gz, *.tgz, *.zip, *.whl)");
            filter.add_pattern ("*.tar.gz");
            filter.add_pattern ("*.tgz");
            filter.add_pattern ("*.zip");
            filter.add_pattern ("*.whl");

            var filters_list = new GLib.ListStore (typeof (Gtk.FileFilter));
            filters_list.append (filter);

            var all_filter = new Gtk.FileFilter ();
            all_filter.set_filter_name ("All Files");
            all_filter.add_pattern ("*");
            filters_list.append (all_filter);

            dialog.set_filters (filters_list);
            dialog.set_default_filter (filter);

            var root_win = this.get_root () as Gtk.Window;
            dialog.open.begin (root_win, null, (obj, res) => {
                try {
                    var file = dialog.open.end (res);
                    if (file != null && file.get_path () != null) {
                        string path = file.get_path ();
                        archive_entry.set_text (path);
                        // Auto-detect ecosystem
                        if (path.has_suffix (".whl")) {
                            ecosystem_row.selected = 1;
                        } else if (path.has_suffix (".tgz") || path.contains ("_") && path.has_suffix (".tar.gz")) {
                            ecosystem_row.selected = 0;
                        }
                        update_install_button_sensitivity ();
                    }
                } catch (GLib.Error e) {
                    // Cancelled by user
                }
            });
        }

        private void update_install_button_sensitivity () {
            string tab = view_stack.visible_child_name ?? "repo";
            bool has_content = false;

            if (tab == "repo") {
                has_content = (package_entry.get_text ().strip ().length > 0);
            } else if (tab == "local") {
                has_content = (archive_entry.get_text ().strip ().length > 0);
            } else if (tab == "git") {
                has_content = (git_entry.get_text ().strip ().length > 0);
            }

            install_btn.sensitive = has_content;
        }

        private async void load_repositories_async () {
            try {
                if (!cache.cran_ready) {
                    yield cache.refresh_cran_index ();
                }
                if (!cache.pypi_ready) {
                    yield cache.refresh_pypi_index ();
                }
            } catch (Error e) {
                // Offline fallback is fine
            }
        }

        private void on_package_entry_changed () {
            string raw_text = package_entry.get_text ();

            // Extract trailing token after comma or space
            string[] tokens = Regex.split_simple ("[\\s,]+", raw_text);
            if (tokens.length == 0) {
                completion_popover.popdown ();
                return;
            }

            string current_token = tokens[tokens.length - 1].strip ();
            if (current_token.length < 2) {
                completion_popover.popdown ();
                return;
            }

            PackageEcosystem active_eco = (ecosystem_row.selected == 0)
                ? PackageEcosystem.R_CRAN
                : PackageEcosystem.PYTHON_PYPI;

            var matches = cache.query_prefix (active_eco, current_token, 12);

            // Clear old items
            Gtk.Widget? child = completion_list.get_first_child ();
            while (child != null) {
                Gtk.Widget? next = child.get_next_sibling ();
                completion_list.remove (child);
                child = next;
            }

            if (matches.length == 0) {
                completion_popover.popdown ();
                return;
            }

            for (int i = 0; i < matches.length; i++) {
                var row_label = new Gtk.Label (matches[i]) {
                    halign = Gtk.Align.START,
                    margin_top = 6,
                    margin_bottom = 6,
                    margin_start = 10,
                    margin_end = 10
                };
                completion_list.append (row_label);
            }

            completion_popover.set_size_request (int.max (package_entry.get_width (), 320), -1);
            completion_popover.popup ();
        }

        private void on_install_clicked () {
            string tab = view_stack.visible_child_name ?? "repo";
            bool include_deps = deps_switch_row.active;
            bool is_r = (ecosystem_row.selected == 0);

            var clean_pkgs = new GenericArray<string> ();

            if (tab == "repo") {
                string raw_input = package_entry.get_text ().strip ();
                string[] raw_tokens = Regex.split_simple ("[\\s,]+", raw_input);
                foreach (string t in raw_tokens) {
                    string clean = t.strip ();
                    if (clean.length > 0) clean_pkgs.add (clean);
                }
            } else if (tab == "local") {
                string archive_path = archive_entry.get_text ().strip ();
                if (archive_path.length > 0) clean_pkgs.add (archive_path);
            } else if (tab == "git") {
                string git_spec = git_entry.get_text ().strip ();
                string branch = git_branch_entry.get_text ().strip ();
                if (git_spec.length > 0) {
                    if (branch.length > 0) {
                        clean_pkgs.add (@"$git_spec@$branch");
                    } else {
                        clean_pkgs.add (git_spec);
                    }
                }
            }

            if (clean_pkgs.length == 0) return;

            InstallSourceMode mode = (tab == "local")
                ? InstallSourceMode.LOCAL_ARCHIVE
                : ((tab == "git") ? InstallSourceMode.GIT_REMOTE : InstallSourceMode.REPOSITORY);

            if (is_r) {
                string mirror = (cran_mirror_row.selected == 1)
                    ? "https://packagemanager.posit.co/cran/__linux__/latest"
                    : "https://cloud.r-project.org";

                string r_cmd = build_r_command (mode, clean_pkgs, include_deps, context.is_sandboxed, mirror);
                execute_r_command (r_cmd);
            } else {
                string py_bin;
                string[] args;
                bool use_uv = (py_engine_row.selected == 0 && context.has_uv);
                PythonEngine engine = use_uv ? PythonEngine.UV : PythonEngine.PIP;
                bool is_editable = (mode == InstallSourceMode.LOCAL_ARCHIVE && editable_switch_row.active);

                build_python_command (mode, engine, clean_pkgs, include_deps, is_editable, out py_bin, out args);
                execute_python_command (py_bin, args, context.root_dir, context.is_sandboxed);
            }

            this.close ();
        }

        private string build_r_command (InstallSourceMode mode, GenericArray<string> pkgs, bool deps, bool sandboxed, string mirror_url) {
            string deps_str = deps ? "TRUE" : "FALSE";

            switch (mode) {
                case InstallSourceMode.REPOSITORY:
                    var builder = new StringBuilder ("c(");
                    for (int i = 0; i < pkgs.length; i++) {
                        if (i > 0) builder.append (", ");
                        builder.append_printf ("\"%s\"", pkgs[i]);
                    }
                    builder.append (")");
                    string pkg_vec = builder.str;

                    if (sandboxed) {
                        return @"renv::install(packages = $pkg_vec, dependencies = $deps_str); renv::snapshot(prompt = FALSE)";
                    } else {
                        return @"install.packages($pkg_vec, repos = \"$mirror_url\", dependencies = $deps_str)";
                    }

                case InstallSourceMode.LOCAL_ARCHIVE:
                    string archive_path = pkgs[0];
                    if (sandboxed) {
                        return @"renv::install(\"$archive_path\"); renv::snapshot(prompt = FALSE)";
                    } else {
                        return @"install.packages(\"$archive_path\", repos = NULL, type = \"source\", dependencies = $deps_str)";
                    }

                case InstallSourceMode.GIT_REMOTE:
                    string spec = pkgs[0];
                    string snapshot_sub = sandboxed ? "; renv::snapshot(prompt = FALSE)" : "";
                    return @"if (!requireNamespace(\"remotes\", quietly = TRUE)) install.packages(\"remotes\", repos = \"$mirror_url\"); remotes::install_github(\"$spec\", dependencies = $deps_str)$snapshot_sub";

                default:
                    return "";
            }
        }

        private void build_python_command (
            InstallSourceMode mode,
            PythonEngine engine,
            GenericArray<string> pkgs,
            bool deps,
            bool is_editable,
            out string py_bin,
            out string[] args
        ) {
            bool use_uv = (engine == PythonEngine.UV);
            bool is_sandboxed = context.is_sandboxed;
            string venv_dir = Path.build_filename (context.root_dir, ".venv");
            string venv_py = Path.build_filename (venv_dir, "bin", "python");

            var arg_list = new GenericArray<string> ();

            if (use_uv) {
                py_bin = EnvironmentTools.get_uv_path ();
                arg_list.add (py_bin);
                arg_list.add ("pip");
                arg_list.add ("install");

                if (is_sandboxed && FileUtils.test (venv_py, FileTest.EXISTS)) {
                    arg_list.add ("--python");
                    arg_list.add (venv_py);
                } else if (!is_sandboxed) {
                    arg_list.add ("--system");
                }

                if (!deps) {
                    arg_list.add ("--no-deps");
                }
            } else {
                py_bin = (is_sandboxed && FileUtils.test (venv_py, FileTest.EXISTS)) ? venv_py : "python3";
                arg_list.add (py_bin);
                arg_list.add ("-m");
                arg_list.add ("pip");
                arg_list.add ("install");

                if (!deps) {
                    arg_list.add ("--no-deps");
                }
            }

            if (is_editable && mode == InstallSourceMode.LOCAL_ARCHIVE) {
                arg_list.add ("-e");
            }

            if (mode == InstallSourceMode.GIT_REMOTE) {
                string spec = pkgs[0];
                if (!spec.has_prefix ("git+")) {
                    if (spec.has_prefix ("http://") || spec.has_prefix ("https://")) {
                        spec = @"git+$spec";
                    } else {
                        spec = @"git+https://github.com/$spec";
                    }
                }
                arg_list.add (spec);
            } else {
                for (int i = 0; i < pkgs.length; i++) {
                    arg_list.add (pkgs[i]);
                }
            }

            string[] result = new string[arg_list.length];
            for (int i = 0; i < arg_list.length; i++) {
                result[i] = arg_list[i];
            }
            args = result;
        }
    }
}
