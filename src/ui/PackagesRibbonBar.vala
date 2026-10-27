using Gtk;
using Adw;
using GLib;

namespace Imladris.UI {

    public class PackagesRibbonBar : Gtk.Box {
        public signal void dispatch_r_install (string r_command, string display_label);
        public signal void dispatch_python_install (string[] argv, string working_dir, bool is_sandboxed, string display_label);

        public string project_root { get; set; default = ""; }
        public bool is_sandboxed { get; set; default = true; }

        private PackageIndexCache index_cache;

        private Gtk.Entry r_search_entry;
        private Gtk.Spinner r_spinner;
        private Gtk.MenuButton r_more_btn;
        private Gtk.Popover r_autocomplete_popover;
        private Gtk.ListBox r_autocomplete_list;

        private Gtk.Entry py_search_entry;
        private Gtk.Spinner py_spinner;
        private Gtk.MenuButton py_more_btn;
        private Gtk.Popover py_autocomplete_popover;
        private Gtk.ListBox py_autocomplete_list;

        private Gtk.CheckButton deps_check;
        private Gtk.Label env_badge;

        private uint r_debounce_id = 0;
        private uint py_debounce_id = 0;

        public PackagesRibbonBar (PackageIndexCache cache) {
            Object (
                orientation: Gtk.Orientation.HORIZONTAL,
                spacing: 12,
                margin_start: 12,
                margin_end: 12,
                margin_top: 6,
                margin_bottom: 6
            );

            this.index_cache = cache;
            build_ui ();
            update_target_badge ();
        }

        private void build_ui () {
            // ==========================================
            // 1. R PACKAGES RIBBON GROUP (CRAN + "..." Menu)
            // ==========================================
            var r_group = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8) {
                valign = Gtk.Align.CENTER
            };

            var r_icon = new Gtk.Image.from_icon_name ("text-x-r-symbolic") {
                pixel_size = 24,
                tooltip_text = "R Packages (CRAN, GitHub, Local)"
            };

            var r_label = new Gtk.Label ("<b>R</b>") {
                use_markup = true,
                margin_end = 2
            };

            r_search_entry = new Gtk.Entry () {
                placeholder_text = "Install R package from CRAN (e.g. tidyverse, lme4)...",
                secondary_icon_name = "folder-download-symbolic",
                secondary_icon_tooltip_text = "Install from CRAN (Enter)",
                width_chars = 34
            };

            r_spinner = new Gtk.Spinner () {
                halign = Gtk.Align.END,
                valign = Gtk.Align.CENTER,
                margin_end = 8,
                visible = false
            };

            var r_overlay = new Gtk.Overlay ();
            r_overlay.set_child (r_search_entry);
            r_overlay.add_overlay (r_spinner);

            r_more_btn = new Gtk.MenuButton () {
                icon_name = "view-more-horizontal-symbolic",
                tooltip_text = "Install R Package from GitHub or Local File...",
                popover = build_more_sources_popover (true)
            };
            r_more_btn.add_css_class ("flat");

            r_group.append (r_icon);
            r_group.append (r_label);
            r_group.append (r_overlay);
            r_group.append (r_more_btn);

            this.append (r_group);
            this.append (new Gtk.Separator (Gtk.Orientation.VERTICAL));

            // ==========================================
            // 2. PYTHON PACKAGES RIBBON GROUP (PyPI + "..." Menu)
            // ==========================================
            var py_group = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8) {
                valign = Gtk.Align.CENTER
            };

            var py_icon = new Gtk.Image.from_icon_name ("text-x-python-symbolic") {
                pixel_size = 24,
                tooltip_text = "Python Packages (PyPI, GitHub, Local Wheel)"
            };

            var py_label = new Gtk.Label ("<b>Python</b>") {
                use_markup = true,
                margin_end = 2
            };

            py_search_entry = new Gtk.Entry () {
                placeholder_text = "Install Python package from PyPI (e.g. numpy, scipy)...",
                secondary_icon_name = "folder-download-symbolic",
                secondary_icon_tooltip_text = "Install from PyPI (Enter)",
                width_chars = 34
            };

            py_spinner = new Gtk.Spinner () {
                halign = Gtk.Align.END,
                valign = Gtk.Align.CENTER,
                margin_end = 8,
                visible = false
            };

            var py_overlay = new Gtk.Overlay ();
            py_overlay.set_child (py_search_entry);
            py_overlay.add_overlay (py_spinner);

            py_more_btn = new Gtk.MenuButton () {
                icon_name = "view-more-horizontal-symbolic",
                tooltip_text = "Install Python Package from GitHub or Local File...",
                popover = build_more_sources_popover (false)
            };
            py_more_btn.add_css_class ("flat");

            py_group.append (py_icon);
            py_group.append (py_label);
            py_group.append (py_overlay);
            py_group.append (py_more_btn);

            this.append (py_group);
            this.append (new Gtk.Separator (Gtk.Orientation.VERTICAL));

            // ==========================================
            // 3. DEPENDENCIES & TARGET ENVIRONMENT BADGE
            // ==========================================
            deps_check = new Gtk.CheckButton.with_label ("With dependencies") {
                active = true,
                tooltip_text = "Automatically install required upstream dependencies",
                valign = Gtk.Align.CENTER
            };
            this.append (deps_check);

            env_badge = new Gtk.Label ("") {
                valign = Gtk.Align.CENTER,
                hexpand = true,
                halign = Gtk.Align.END
            };
            env_badge.add_css_class ("target-env-pill");
            this.append (env_badge);

            setup_autocomplete ();
            connect_signals ();
        }

        public void update_target_badge () {
            if (is_sandboxed) {
                env_badge.label = "[Target: Sandboxed (renv / .venv)]";
                env_badge.remove_css_class ("system");
                env_badge.remove_css_class ("warning");
                env_badge.add_css_class ("sandboxed");
                env_badge.add_css_class ("success");
                env_badge.tooltip_text = "Packages install into project-local sandbox. Reproducibility guaranteed.";
            } else {
                env_badge.label = "[Target: System Library]";
                env_badge.remove_css_class ("sandboxed");
                env_badge.remove_css_class ("success");
                env_badge.add_css_class ("system");
                env_badge.add_css_class ("warning");
                env_badge.tooltip_text = "Packages install into host system libraries. Non-isolated environment.";
            }
        }

        public void set_r_busy (bool busy, string? display_label = null) {
            r_spinner.visible = busy;
            if (busy) {
                r_spinner.start ();
                r_search_entry.secondary_icon_name = null;
                r_search_entry.sensitive = false;
                r_more_btn.sensitive = false;
            } else {
                r_spinner.stop ();
                r_search_entry.secondary_icon_name = "folder-download-symbolic";
                r_search_entry.sensitive = true;
                r_more_btn.sensitive = true;
            }
        }

        public void set_python_busy (bool busy, string? display_label = null) {
            py_spinner.visible = busy;
            if (busy) {
                py_spinner.start ();
                py_search_entry.secondary_icon_name = null;
                py_search_entry.sensitive = false;
                py_more_btn.sensitive = false;
            } else {
                py_spinner.stop ();
                py_search_entry.secondary_icon_name = "folder-download-symbolic";
                py_search_entry.sensitive = true;
                py_more_btn.sensitive = true;
            }
        }

        public void focus_search (bool is_python = false) {
            if (is_python) {
                py_search_entry.grab_focus ();
            } else {
                r_search_entry.grab_focus ();
            }
        }

        /**
         * Sets up the non-modal prefix autocomplete popovers attached to each Entry.
         */
        private void setup_autocomplete () {
            // R Autocomplete Popover
            r_autocomplete_popover = new Gtk.Popover () {
                autohide = true,
                has_arrow = true,
                position = Gtk.PositionType.BOTTOM
            };
            r_autocomplete_popover.set_parent (r_search_entry);

            r_autocomplete_list = new Gtk.ListBox () {
                selection_mode = Gtk.SelectionMode.SINGLE
            };
            r_autocomplete_list.add_css_class ("navigation-sidebar");

            var r_scroller = new Gtk.ScrolledWindow () {
                hscrollbar_policy = Gtk.PolicyType.NEVER,
                vscrollbar_policy = Gtk.PolicyType.AUTOMATIC,
                max_content_height = 200,
                propagate_natural_height = true,
                child = r_autocomplete_list
            };
            r_scroller.set_size_request (280, -1);
            r_autocomplete_popover.set_child (r_scroller);

            r_autocomplete_list.row_activated.connect ((row) => {
                var lbl = row.get_child () as Gtk.Box;
                if (lbl != null) {
                    var name_lbl = lbl.get_last_child () as Gtk.Label;
                    if (name_lbl != null) {
                        apply_autocomplete_selection (r_search_entry, name_lbl.label);
                    }
                }
                r_autocomplete_popover.popdown ();
                r_search_entry.grab_focus ();
            });

            // Python Autocomplete Popover
            py_autocomplete_popover = new Gtk.Popover () {
                autohide = true,
                has_arrow = true,
                position = Gtk.PositionType.BOTTOM
            };
            py_autocomplete_popover.set_parent (py_search_entry);

            py_autocomplete_list = new Gtk.ListBox () {
                selection_mode = Gtk.SelectionMode.SINGLE
            };
            py_autocomplete_list.add_css_class ("navigation-sidebar");

            var py_scroller = new Gtk.ScrolledWindow () {
                hscrollbar_policy = Gtk.PolicyType.NEVER,
                vscrollbar_policy = Gtk.PolicyType.AUTOMATIC,
                max_content_height = 200,
                propagate_natural_height = true,
                child = py_autocomplete_list
            };
            py_scroller.set_size_request (280, -1);
            py_autocomplete_popover.set_child (py_scroller);

            py_autocomplete_list.row_activated.connect ((row) => {
                var lbl = row.get_child () as Gtk.Box;
                if (lbl != null) {
                    var name_lbl = lbl.get_last_child () as Gtk.Label;
                    if (name_lbl != null) {
                        apply_autocomplete_selection (py_search_entry, name_lbl.label);
                    }
                }
                py_autocomplete_popover.popdown ();
                py_search_entry.grab_focus ();
            });
        }

        private string get_active_token (string text) {
            string[] parts = text.split (",");
            if (parts.length == 0) return "";
            string last_part = parts[parts.length - 1];
            string[] words = last_part.split (" ");
            if (words.length == 0) return "";
            return words[words.length - 1].strip ();
        }

        private void apply_autocomplete_selection (Gtk.Entry entry, string selected_pkg) {
            string full = entry.text;
            int last_comma = full.last_index_of (",");
            if (last_comma >= 0) {
                string prefix = full.substring (0, last_comma + 1).strip ();
                entry.text = @"$prefix $selected_pkg, ";
            } else {
                entry.text = @"$selected_pkg, ";
            }
            entry.set_position (-1);
        }

        private void connect_signals () {
            // R Live Autocomplete with 150ms debounce
            r_search_entry.changed.connect (() => {
                if (r_debounce_id > 0) {
                    Source.remove (r_debounce_id);
                    r_debounce_id = 0;
                }
                r_debounce_id = Timeout.add (150, () => {
                    r_debounce_id = 0;
                    update_autocomplete (true);
                    return false;
                });
            });

            // Python Live Autocomplete with 150ms debounce
            py_search_entry.changed.connect (() => {
                if (py_debounce_id > 0) {
                    Source.remove (py_debounce_id);
                    py_debounce_id = 0;
                }
                py_debounce_id = Timeout.add (150, () => {
                    py_debounce_id = 0;
                    update_autocomplete (false);
                    return false;
                });
            });

            // CRAN Enter or Secondary Icon Click
            r_search_entry.activate.connect (trigger_cran_install);
            r_search_entry.icon_release.connect ((pos) => {
                if (pos == Gtk.EntryIconPosition.SECONDARY) {
                    trigger_cran_install ();
                }
            });

            // PyPI Enter or Secondary Icon Click
            py_search_entry.activate.connect (trigger_pypi_install);
            py_search_entry.icon_release.connect ((pos) => {
                if (pos == Gtk.EntryIconPosition.SECONDARY) {
                    trigger_pypi_install ();
                }
            });
        }

        private void update_autocomplete (bool is_r) {
            var entry = is_r ? r_search_entry : py_search_entry;
            var popover = is_r ? r_autocomplete_popover : py_autocomplete_popover;
            var list = is_r ? r_autocomplete_list : py_autocomplete_list;

            string token = get_active_token (entry.text);
            if (token.length < 2) {
                popover.popdown ();
                return;
            }

            var eco = is_r ? PackageEcosystem.R_CRAN : PackageEcosystem.PYTHON_PYPI;
            var results = index_cache.query_prefix (eco, token, 12);

            // Clear previous items
            Gtk.Widget? child = list.get_first_child ();
            while (child != null) {
                Gtk.Widget? next = child.get_next_sibling ();
                list.remove (child);
                child = next;
            }

            if (results.length == 0) {
                popover.popdown ();
                return;
            }

            for (int i = 0; i < results.length; i++) {
                string name = results[i];
                var row = new Gtk.ListBoxRow ();
                var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8) {
                    margin_start = 8,
                    margin_end = 8,
                    margin_top = 4,
                    margin_bottom = 4
                };
                var icon = new Gtk.Image.from_icon_name (is_r ? "text-x-r-symbolic" : "text-x-python-symbolic") {
                    pixel_size = 16
                };
                var lbl = new Gtk.Label (name) {
                    halign = Gtk.Align.START,
                    hexpand = true
                };
                box.append (icon);
                box.append (lbl);
                row.set_child (box);
                list.append (row);
            }

            popover.popup ();
        }

        /**
         * Builds the "..." Popover for installing from GitHub or a Local File
         */
        private Gtk.Popover build_more_sources_popover (bool is_r) {
            var pop = new Gtk.Popover () {
                has_arrow = true
            };

            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 10) {
                margin_top = 10,
                margin_bottom = 10,
                margin_start = 10,
                margin_end = 10,
                width_request = 300
            };

            // Option A: Install from GitHub Repo
            var gh_title = new Gtk.Label (is_r ? "<b>Install R Package from GitHub</b>" : "<b>Install Python Package from GitHub</b>") {
                use_markup = true,
                halign = Gtk.Align.START
            };

            var gh_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
            var gh_entry = new Gtk.Entry () {
                placeholder_text = is_r ? "owner/repo (e.g. tidyverse/dplyr)" : "owner/repo (e.g. pallets/flask)",
                hexpand = true
            };
            var gh_install_btn = new Gtk.Button.from_icon_name ("folder-download-symbolic") {
                tooltip_text = "Install from GitHub"
            };
            gh_install_btn.add_css_class ("suggested-action");

            gh_box.append (gh_entry);
            gh_box.append (gh_install_btn);

            // Option B: Install from Local Archive File
            var local_btn = new Gtk.Button () {
                halign = Gtk.Align.FILL
            };
            var btn_content = new Adw.ButtonContent () {
                icon_name = "document-open-symbolic",
                label = is_r ? "Select Local File (.tar.gz, .zip)..." : "Select Local File (.whl, .tar.gz)..."
            };
            local_btn.set_child (btn_content);

            box.append (gh_title);
            box.append (gh_box);
            box.append (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));
            box.append (local_btn);

            pop.set_child (box);

            // Wire GitHub Install Action
            gh_install_btn.clicked.connect (() => {
                string repo = gh_entry.text.strip ();
                if (repo.length == 0) return;
                pop.popdown ();
                gh_entry.text = "";
                install_from_github (is_r, repo);
            });
            gh_entry.activate.connect (() => {
                gh_install_btn.activate ();
            });

            // Wire Local File Picker Action
            local_btn.clicked.connect (() => {
                pop.popdown ();
                prompt_local_file_install.begin (is_r);
            });

            return pop;
        }

        private void trigger_cran_install () {
            string raw = r_search_entry.text.strip ();
            if (raw.length == 0) return;

            string[] tokens = Regex.split_simple ("[\\s,]+", raw);
            var builder = new StringBuilder ("c(");
            int count = 0;
            foreach (string t in tokens) {
                string clean = t.strip ();
                if (clean.length > 0) {
                    if (count > 0) builder.append (", ");
                    builder.append_printf ("\"%s\"", clean);
                    count++;
                }
            }
            builder.append (")");
            if (count == 0) return;

            string deps = deps_check.active ? "TRUE" : "FALSE";
            string pkg_vec = builder.str;
            string r_cmd;

            // Fast-path: check if pak is available for accelerated parallel install, otherwise standard renv/install.packages
            if (is_sandboxed) {
                r_cmd = "if (requireNamespace('pak', quietly = TRUE)) { pak::pkg_install(%s); renv::snapshot(prompt = FALSE) } else { renv::install(packages = %s, dependencies = %s); renv::snapshot(prompt = FALSE) }".printf (
                    pkg_vec, pkg_vec, deps
                );
            } else {
                r_cmd = "if (requireNamespace('pak', quietly = TRUE)) { pak::pkg_install(%s) } else { install.packages(%s, repos = \"https://cloud.r-project.org\", dependencies = %s) }".printf (
                    pkg_vec, pkg_vec, deps
                );
            }

            r_search_entry.text = "";
            dispatch_r_install (r_cmd, raw);
        }

        private void trigger_pypi_install () {
            string raw = py_search_entry.text.strip ();
            if (raw.length == 0) return;

            string[] tokens = Regex.split_simple ("[\\s,]+", raw);
            var args = build_base_pip_argv ();
            int count = 0;
            foreach (string t in tokens) {
                string clean = t.strip ();
                if (clean.length > 0) {
                    args.add (clean);
                    count++;
                }
            }
            if (count == 0) return;

            py_search_entry.text = "";
            dispatch_python_install (args.data, project_root, is_sandboxed, raw);
        }

        private void install_from_github (bool is_r, string repo_spec) {
            if (is_r) {
                string deps = deps_check.active ? "TRUE" : "FALSE";
                string r_cmd;
                if (is_sandboxed) {
                    r_cmd = "if (requireNamespace('pak', quietly = TRUE)) { pak::pkg_install(\"%s\"); renv::snapshot(prompt = FALSE) } else { renv::install(\"%s\"); renv::snapshot(prompt = FALSE) }".printf (
                        repo_spec, repo_spec
                    );
                } else {
                    r_cmd = "if (requireNamespace('pak', quietly = TRUE)) { pak::pkg_install(\"%s\") } else { if (!requireNamespace('remotes', quietly = TRUE)) install.packages('remotes', repos = 'https://cloud.r-project.org'); remotes::install_github(\"%s\", dependencies = %s) }".printf (
                        repo_spec, repo_spec, deps
                    );
                }
                dispatch_r_install (r_cmd, repo_spec);
            } else {
                string git_url = repo_spec.has_prefix ("git+")
                    ? repo_spec
                    : (repo_spec.has_prefix ("http://") || repo_spec.has_prefix ("https://")
                        ? @"git+$repo_spec"
                        : @"git+https://github.com/$repo_spec.git");

                var args = build_base_pip_argv ();
                args.add (git_url);
                dispatch_python_install (args.data, project_root, is_sandboxed, repo_spec);
            }
        }

        private async void prompt_local_file_install (bool is_r) {
            var file_dialog = new Gtk.FileDialog () {
                title = is_r ? "Select Local R Package Archive" : "Select Local Python Package (.whl / .tar.gz)"
            };

            var filter = new Gtk.FileFilter ();
            if (is_r) {
                filter.name = "R Package Archives (*.tar.gz, *.zip)";
                filter.add_pattern ("*.tar.gz");
                filter.add_pattern ("*.tgz");
                filter.add_pattern ("*.zip");
            } else {
                filter.name = "Python Wheels & Source Archives (*.whl, *.tar.gz, *.zip)";
                filter.add_pattern ("*.whl");
                filter.add_pattern ("*.tar.gz");
                filter.add_pattern ("*.zip");
            }

            var filters = new GLib.ListStore (typeof (Gtk.FileFilter));
            filters.append (filter);
            file_dialog.filters = filters;

            try {
                var root_win = this.get_root () as Gtk.Window;
                File? file = yield file_dialog.open (root_win, null);
                if (file == null) return;

                string local_path = file.get_path ();
                if (is_r) {
                    string deps = deps_check.active ? "TRUE" : "FALSE";
                    string r_cmd = is_sandboxed
                        ? "renv::install(\"%s\"); renv::snapshot(prompt = FALSE)".printf (local_path)
                        : "install.packages(\"%s\", repos = NULL, type = \"source\", dependencies = %s)".printf (local_path, deps);
                    dispatch_r_install (r_cmd, Path.get_basename (local_path));
                } else {
                    var args = build_base_pip_argv ();
                    args.add (local_path);
                    dispatch_python_install (args.data, project_root, is_sandboxed, Path.get_basename (local_path));
                }
            } catch (Error e) {
                // User cancelled dialog
            }
        }

        private GenericArray<string> build_base_pip_argv () {
            var argv = new GenericArray<string> ();
            string? uv_bin = Environment.find_program_in_path ("uv");

            if (uv_bin != null) {
                argv.add (uv_bin);
                argv.add ("pip");
                argv.add ("install");
                if (is_sandboxed) {
                    string venv_py = Path.build_filename (project_root, ".venv", "bin", "python");
                    if (FileUtils.test (venv_py, FileTest.EXISTS)) {
                        argv.add ("--python");
                        argv.add (venv_py);
                    }
                } else {
                    argv.add ("--system");
                }
            } else {
                string venv_py = Path.build_filename (project_root, ".venv", "bin", "python");
                string py_bin = (is_sandboxed && FileUtils.test (venv_py, FileTest.EXISTS))
                    ? venv_py
                    : "python3";
                argv.add (py_bin);
                argv.add ("-m");
                argv.add ("pip");
                argv.add ("install");
            }

            if (!deps_check.active) {
                argv.add ("--no-deps");
            }
            return argv;
        }
    }
}
