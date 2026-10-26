using Gtk;
using Adw;
using GLib;

namespace Imladris.UI {

    public enum PackageEcosystem {
        R_CRAN,
        PYTHON_PYPI
    }

    public class ProjectContext : Object {
        public string root_dir { get; set; }
        public bool is_sandboxed { get; set; }
        public PackageEcosystem default_ecosystem { get; set; }

        public ProjectContext (string root_dir, bool is_sandboxed, PackageEcosystem default_ecosystem) {
            this.root_dir = root_dir;
            this.is_sandboxed = is_sandboxed;
            this.default_ecosystem = default_ecosystem;
        }
    }

    /**
     * Thread-safe asynchronous cache for CRAN (PACKAGES) and PyPI (PEP 691 JSON) indices.
     */
    public class PackageIndexCache : Object {
        private GenericArray<string> cran_packages;
        private GenericArray<string> pypi_packages;
        private Soup.Session soup_session;

        public bool cran_ready { get; private set; default = false; }
        public bool pypi_ready { get; private set; default = false; }

        private static string[] DEFAULT_CRAN = {
            "ggplot2", "dplyr", "tidyr", "readr", "purrr", "tibble", "stringr", "forcats",
            "knitr", "rmarkdown", "shiny", "data.table", "devtools", "renv", "caret",
            "lubridate", "magrittr", "testthat", "patchwork", "plotly", "sf", "targets",
            "quarto", "jsonlite", "xml2", "httr2", "future", "DBI", "RSQLite"
        };

        private static string[] DEFAULT_PYPI = {
            "numpy", "pandas", "matplotlib", "scipy", "seaborn", "scikit-learn",
            "jupyter", "torch", "requests", "polars", "flask", "fastapi", "tensorflow",
            "pytest", "rich", "pillow", "beautifulsoup4", "sympy", "statsmodels",
            "pyyaml", "httpx", "altair", "plotly", "xgboost", "optuna", "uv"
        };

        public PackageIndexCache () {
            cran_packages = new GenericArray<string> ();
            pypi_packages = new GenericArray<string> ();
            soup_session = new Soup.Session ();
            soup_session.user_agent = "Imladris-IDE/1.0";

            foreach (var p in DEFAULT_CRAN) {
                cran_packages.add (p);
            }
            cran_packages.sort (strcmp);

            foreach (var p in DEFAULT_PYPI) {
                pypi_packages.add (p);
            }
            pypi_packages.sort (strcmp);
        }

        public async int refresh_cran_index (string mirror_url = "https://cloud.r-project.org") throws Error {
            string url = mirror_url.has_suffix ("/")
                ? mirror_url + "src/contrib/PACKAGES"
                : mirror_url + "/src/contrib/PACKAGES";

            var msg = new Soup.Message ("GET", url);
            Bytes bytes = yield soup_session.send_and_read_async (msg, Priority.DEFAULT, null);

            if (msg.status_code != Soup.Status.OK) {
                throw new IOError.FAILED ("CRAN HTTP %u: %s", msg.status_code, msg.reason_phrase);
            }

            unowned uint8[] raw_data = bytes.get_data ();
            string body = (string) raw_data;

            var temp_list = new GenericArray<string> ();
            foreach (unowned string line in body.split ("\n")) {
                if (line.has_prefix ("Package:")) {
                    string pkg = line.substring (8).strip ();
                    if (pkg.length > 0) {
                        temp_list.add (pkg);
                    }
                }
            }

            temp_list.sort (strcmp);
            cran_packages = temp_list;
            cran_ready = true;
            return cran_packages.length;
        }

        public async int refresh_pypi_index () throws Error {
            var msg = new Soup.Message ("GET", "https://pypi.org/simple/");
            msg.request_headers.append ("Accept", "application/vnd.pypi.simple.v1+json");

            Bytes bytes = yield soup_session.send_and_read_async (msg, Priority.DEFAULT, null);

            if (msg.status_code != Soup.Status.OK) {
                throw new IOError.FAILED ("PyPI HTTP %u: %s", msg.status_code, msg.reason_phrase);
            }

            var parser = new Json.Parser ();
            var stream = new MemoryInputStream.from_bytes (bytes);
            yield parser.load_from_stream_async (stream, null);

            var root_obj = parser.get_root ().get_object ();
            var projects_arr = root_obj.get_array_member ("projects");

            var temp_list = new GenericArray<string> ();
            uint len = projects_arr.get_length ();
            for (uint i = 0; i < len; i++) {
                var proj_obj = projects_arr.get_object_element (i);
                if (proj_obj.has_member ("name")) {
                    temp_list.add (proj_obj.get_string_member ("name"));
                }
            }

            temp_list.sort (strcmp);
            pypi_packages = temp_list;
            pypi_ready = true;
            return pypi_packages.length;
        }

        public GenericArray<string> query_prefix (PackageEcosystem eco, string prefix, int limit = 12) {
            var results = new GenericArray<string> ();
            string clean = prefix.strip ().down ();
            if (clean.length < 2) {
                return results;
            }

            unowned GenericArray<string> source = (eco == PackageEcosystem.R_CRAN)
                ? cran_packages
                : pypi_packages;

            for (int i = 0; i < source.length; i++) {
                string pkg = source[i];
                if (pkg.down ().has_prefix (clean)) {
                    results.add (pkg);
                    if (results.length >= limit) {
                        break;
                    }
                }
            }
            return results;
        }
    }

    /**
     * RStudio-style Package Installer Modal Dialog in Vala + Libadwaita
     */
    public class PackageInstallerModal : Adw.Dialog {
        public signal void execute_r_command (string r_code);
        public signal void execute_python_command (string python_bin, string[] args, string working_dir, bool is_sandboxed);

        private ProjectContext context;
        private PackageIndexCache cache;

        private Adw.ComboRow ecosystem_row;
        private Adw.ActionRow index_status_row;
        private Gtk.Spinner refresh_spinner;
        private Gtk.Entry package_entry;
        private Gtk.Popover completion_popover;
        private Gtk.ListBox completion_list;
        private Adw.ActionRow target_lib_row;
        private Gtk.Label sandbox_badge;
        private Adw.SwitchRow deps_switch_row;
        private Gtk.Button install_btn;

        public PackageInstallerModal (ProjectContext context, PackageIndexCache cache) {
            Object (
                title: "Install Packages",
                content_width: 520,
                content_height: 460
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
            toolbar_view.add_top_bar (header_bar);

            var main_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 16) {
                margin_top = 16,
                margin_bottom = 16,
                margin_start = 20,
                margin_end = 20
            };

            // 1. Repository & Ecosystem Group
            var ecosystem_group = new Adw.PreferencesGroup () {
                title = "Repository & Ecosystem"
            };

            var eco_model = new Gtk.StringList ({
                "Repository (CRAN) — R Packages",
                "Repository (PyPI) — Python Packages",
                "Package Archive File (.tar.gz, .whl)"
            });

            ecosystem_row = new Adw.ComboRow () {
                title = "Install from:",
                subtitle = "Repository source for packages",
                model = eco_model,
                selected = (context.default_ecosystem == PackageEcosystem.R_CRAN) ? 0 : 1
            };
            ecosystem_group.add (ecosystem_row);

            index_status_row = new Adw.ActionRow () {
                title = "Repository Index",
                subtitle = "Fetching package list for autocomplete..."
            };
            refresh_spinner = new Gtk.Spinner () {
                spinning = true,
                valign = Gtk.Align.CENTER
            };
            index_status_row.add_suffix (refresh_spinner);
            ecosystem_group.add (index_status_row);

            main_box.append (ecosystem_group);

            // 2. Package Input & Live Autocomplete Popover
            var input_group = new Adw.PreferencesGroup () {
                title = "Packages (separate multiple with space or comma)"
            };

            var entry_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 4);
            package_entry = new Gtk.Entry () {
                placeholder_text = "e.g., tidyverse, ggplot2, DESeq2",
                hexpand = true
            };

            completion_list = new Gtk.ListBox () {
                selection_mode = Gtk.SelectionMode.SINGLE
            };
            completion_list.add_css_class ("boxed-list");

            var completion_scroller = new Gtk.ScrolledWindow () {
                hscrollbar_policy = Gtk.PolicyType.NEVER,
                vscrollbar_policy = Gtk.PolicyType.AUTOMATIC,
                min_content_height = 160,
                max_content_height = 220,
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
            input_group.add (entry_box);
            main_box.append (input_group);

            // 3. Target Library & Dependencies
            var target_group = new Adw.PreferencesGroup () {
                title = "Target Environment & Dependencies"
            };

            target_lib_row = new Adw.ActionRow () {
                title = "Install to Library:"
            };

            sandbox_badge = new Gtk.Label ("") {
                valign = Gtk.Align.CENTER
            };
            target_lib_row.add_suffix (sandbox_badge);
            target_group.add (target_lib_row);

            deps_switch_row = new Adw.SwitchRow () {
                title = "Install dependencies",
                subtitle = "Automatically resolve and install required upstream packages",
                active = true
            };
            target_group.add (deps_switch_row);

            main_box.append (target_group);

            // 4. Bottom Action Buttons
            var action_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10) {
                halign = Gtk.Align.END,
                margin_top = 8
            };

            var cancel_btn = new Gtk.Button.with_label ("Cancel");
            cancel_btn.clicked.connect (() => {
                this.close ();
            });

            install_btn = new Gtk.Button.with_label ("Install") {
                sensitive = false
            };
            install_btn.add_css_class ("suggested-action");

            action_box.append (cancel_btn);
            action_box.append (install_btn);
            main_box.append (action_box);

            toolbar_view.set_content (main_box);
            this.set_child (toolbar_view);
        }

        private void connect_signals () {
            ecosystem_row.notify["selected"].connect (() => {
                completion_popover.popdown ();
                update_ui_for_ecosystem (ecosystem_row.selected);
            });

            package_entry.changed.connect (on_package_entry_changed);

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

            if (selected_idx == 0) {
                package_entry.placeholder_text = "e.g., tidyverse, data.table, lme4";
            } else if (selected_idx == 1) {
                package_entry.placeholder_text = "e.g., numpy, pandas, scipy==1.14.1";
            } else {
                package_entry.placeholder_text = "/path/to/package_archive.tar.gz";
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
        }

        private async void load_repositories_async () {
            try {
                if (!cache.cran_ready) {
                    yield cache.refresh_cran_index ();
                }
                if (!cache.pypi_ready) {
                    yield cache.refresh_pypi_index ();
                }
                index_status_row.subtitle = "Ready • CRAN & PyPI indices loaded for live autocomplete";
            } catch (Error e) {
                index_status_row.subtitle = "Offline / Partial Cache (%s)".printf (e.message);
            } finally {
                refresh_spinner.spinning = false;
                refresh_spinner.visible = false;
            }
        }

        private void on_package_entry_changed () {
            string raw_text = package_entry.get_text ();
            install_btn.sensitive = (raw_text.strip ().length > 0);

            if (ecosystem_row.selected == 2) {
                completion_popover.popdown ();
                return;
            }

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
            string raw_input = package_entry.get_text ().strip ();
            string[] raw_tokens = Regex.split_simple ("[\\s,]+", raw_input);

            var clean_pkgs = new GenericArray<string> ();
            foreach (string t in raw_tokens) {
                string clean = t.strip ();
                if (clean.length > 0) {
                    clean_pkgs.add (clean);
                }
            }

            if (clean_pkgs.length == 0) return;

            bool include_deps = deps_switch_row.active;
            uint mode = ecosystem_row.selected;

            if (mode == 0) {
                // R (CRAN)
                string r_cmd = build_r_install_command (clean_pkgs, include_deps, context.is_sandboxed);
                execute_r_command (r_cmd);
            } else if (mode == 1) {
                // Python (PyPI)
                string py_bin;
                string[] args;
                build_python_install_command (clean_pkgs, include_deps, out py_bin, out args);
                execute_python_command (py_bin, args, context.root_dir, context.is_sandboxed);
            } else {
                // Local Archive (.tar.gz / .whl)
                string archive_path = clean_pkgs[0];
                if (archive_path.has_suffix (".whl")) {
                    string py_bin;
                    string[] args;
                    build_python_install_command (clean_pkgs, include_deps, out py_bin, out args);
                    execute_python_command (py_bin, args, context.root_dir, context.is_sandboxed);
                } else {
                    string r_cmd = "install.packages(\"%s\", repos = NULL, type = \"source\")".printf (archive_path);
                    execute_r_command (r_cmd);
                }
            }

            this.close ();
        }

        private string build_r_install_command (GenericArray<string> pkgs, bool install_deps, bool is_sandboxed) {
            var builder = new StringBuilder ("c(");
            for (int i = 0; i < pkgs.length; i++) {
                if (i > 0) builder.append (", ");
                builder.append_printf ("\"%s\"", pkgs[i]);
            }
            builder.append (")");

            string pkg_vec = builder.str;
            string deps_str = install_deps ? "TRUE" : "FALSE";

            if (is_sandboxed) {
                return "renv::install(packages = %s, dependencies = %s); renv::snapshot(prompt = FALSE)".printf (
                    pkg_vec, deps_str
                );
            } else {
                return "install.packages(%s, repos = \"https://cloud.r-project.org\", dependencies = %s)".printf (
                    pkg_vec, deps_str
                );
            }
        }

        private void build_python_install_command (
            GenericArray<string> pkgs,
            bool install_deps,
            out string py_bin,
            out string[] args
        ) {
            py_bin = context.is_sandboxed
                ? Path.build_filename (context.root_dir, ".venv", "bin", "python")
                : "python3";

            var arg_list = new GenericArray<string> ();
            arg_list.add (py_bin);
            arg_list.add ("-m");
            arg_list.add ("pip");
            arg_list.add ("install");

            if (!install_deps) {
                arg_list.add ("--no-deps");
            }

            for (int i = 0; i < pkgs.length; i++) {
                arg_list.add (pkgs[i]);
            }

            string[] result = new string[arg_list.length];
            for (int i = 0; i < arg_list.length; i++) {
                result[i] = arg_list[i];
            }
            args = result;
        }
    }
}
