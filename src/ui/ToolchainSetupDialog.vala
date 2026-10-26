using Gtk;
using Adw;
using GLib;

namespace Imladris.UI {

    public class ToolchainSetupDialog : Adw.Dialog {

        public signal void installation_completed ();

        private Adw.SwitchRow r_switch;
        private Adw.SwitchRow tidy_switch;
        private Adw.SwitchRow py_switch;
        private Adw.SwitchRow quarto_switch;

        private Gtk.Button install_btn;
        private Gtk.ProgressBar progress_bar;
        private Gtk.Label status_lbl;
        private Gtk.TextView log_view;
        private Gtk.ScrolledWindow log_scroller;
        private Gtk.Box progress_box;

        private ulong progress_sig_id = 0;
        private ulong log_sig_id = 0;

        public ToolchainSetupDialog () {
            Object (
                title: "Data Science Toolchain Manager",
                content_width: 660,
                content_height: 700
            );
            build_ui ();
        }

        private void build_ui () {
            var toolbar_view = new Adw.ToolbarView ();
            var header = new Adw.HeaderBar ();
            toolbar_view.add_top_bar (header);

            var page = new Adw.PreferencesPage ();

            // =================================================================
            // GROUP 1: Overview & Location
            // =================================================================
            var info_group = new Adw.PreferencesGroup () {
                title = "Automated Toolchain Provisioning",
                description = "Self-contained, pre-compiled Data Science runtimes powered by micromamba. Works seamlessly inside Flatpak with zero host dependencies and pre-compiled C/C++ libraries."
            };

            var tm = Core.ToolchainManager.get_default ();
            var location_row = new Adw.ActionRow () {
                title = "Installation Location",
                subtitle = tm.base_dir
            };
            location_row.add_prefix (new Gtk.Image.from_icon_name ("drive-harddisk-symbolic"));

            int64 usage = tm.get_toolchain_disk_usage ();
            if (usage > 0) {
                double mb = (double) usage / (1024.0 * 1024.0);
                var size_badge = new Gtk.Label ("%.1f MB installed".printf (mb)) {
                    valign = Gtk.Align.CENTER,
                    css_classes = { "dim-label", "caption" }
                };
                location_row.add_suffix (size_badge);
            }
            info_group.add (location_row);
            page.add (info_group);

            // =================================================================
            // GROUP 2: Component Bundles
            // =================================================================
            var comp_group = new Adw.PreferencesGroup () {
                title = "Toolchain Components",
                description = "Select packages to install or update in the shared base-ds environment:"
            };

            r_switch = new Adw.SwitchRow () {
                title = "R 4.4 + IRkernel + Build Tools",
                subtitle = "Pre-compiled R interpreter, dev compilers (gcc/gfortran), make, and headers for instant package compilation.",
                active = true
            };
            r_switch.add_prefix (new Gtk.Image.from_icon_name ("utilities-terminal-symbolic"));
            comp_group.add (r_switch);

            tidy_switch = new Adw.SwitchRow () {
                title = "R Tidyverse & RMarkdown Bundle",
                subtitle = "Pre-compiled binary packages: tidyverse, data.table, rmarkdown, and knitr (Zero compilation time).",
                active = true
            };
            tidy_switch.add_prefix (new Gtk.Image.from_icon_name ("x-office-document-symbolic"));
            comp_group.add (tidy_switch);

            py_switch = new Adw.SwitchRow () {
                title = "Python 3.12 + Jupyter Kernel + uv",
                subtitle = "Modern Python 3.12 stack with ipykernel for computational cells and fast uv package manager.",
                active = true
            };
            py_switch.add_prefix (new Gtk.Image.from_icon_name ("applications-science-symbolic"));
            comp_group.add (py_switch);

            quarto_switch = new Adw.SwitchRow () {
                title = "Quarto CLI + Typst Engine",
                subtitle = "Publishing system for reproducible HTML, PDF, ODT, and presentation slides via Pandoc and Typst.",
                active = true
            };
            quarto_switch.add_prefix (new Gtk.Image.from_icon_name ("document-edit-symbolic"));
            comp_group.add (quarto_switch);

            r_switch.notify["active"].connect (() => {
                tidy_switch.sensitive = r_switch.active;
                if (!r_switch.active) tidy_switch.active = false;
            });

            page.add (comp_group);

            // =================================================================
            // GROUP 3: Action & Live Progress
            // =================================================================
            var action_group = new Adw.PreferencesGroup () {
                title = "Installation & Logs"
            };

            var action_row = new Adw.ActionRow () {
                title = "Start Provisioning",
                subtitle = "Downloads and links conda-forge pre-compiled binaries into Imladris's data directory."
            };

            install_btn = new Gtk.Button.with_label ("Install Toolchain") {
                valign = Gtk.Align.CENTER
            };
            install_btn.add_css_class ("suggested-action");
            install_btn.clicked.connect (on_install_clicked);
            action_row.add_suffix (install_btn);
            action_group.add (action_row);

            progress_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 8) {
                margin_top = 10,
                margin_bottom = 10,
                visible = false
            };

            status_lbl = new Gtk.Label ("Preparing installation...") {
                xalign = 0.0f,
                wrap = true,
                css_classes = { "dim-label" }
            };
            progress_box.append (status_lbl);

            progress_bar = new Gtk.ProgressBar () {
                fraction = 0.0,
                show_text = true
            };
            progress_box.append (progress_bar);

            log_scroller = new Gtk.ScrolledWindow () {
                height_request = 180,
                hexpand = true,
                vexpand = false
            };
            log_scroller.add_css_class ("view");
            log_scroller.add_css_class ("frame");

            log_view = new Gtk.TextView () {
                editable = false,
                cursor_visible = false,
                monospace = true,
                wrap_mode = Gtk.WrapMode.NONE,
                left_margin = 8,
                right_margin = 8,
                top_margin = 8,
                bottom_margin = 8
            };
            log_scroller.set_child (log_view);
            progress_box.append (log_scroller);

            action_group.add (progress_box);
            page.add (action_group);

            toolbar_view.content = page;
            this.child = toolbar_view;
        }

        private void on_install_clicked () {
            install_btn.sensitive = false;
            r_switch.sensitive = false;
            tidy_switch.sensitive = false;
            py_switch.sensitive = false;
            quarto_switch.sensitive = false;

            progress_box.visible = true;
            progress_bar.fraction = 0.05;
            status_lbl.label = "Initializing micromamba engine...";

            var tm = Core.ToolchainManager.get_default ();

            progress_sig_id = tm.progress_changed.connect ((step, fraction, detail) => {
                progress_bar.fraction = fraction;
                status_lbl.label = @"$step: $detail";
            });

            log_sig_id = tm.log_output.connect ((line) => {
                append_log (line);
            });

            bool do_r = r_switch.active;
            bool do_tidy = tidy_switch.active;
            bool do_py = py_switch.active;
            bool do_quarto = quarto_switch.active;

            tm.create_or_update_base_environment_async.begin (do_r, do_py, do_quarto, do_tidy, (obj, res) => {
                bool ok = tm.create_or_update_base_environment_async.end (res);
                tm.disconnect (progress_sig_id);
                tm.disconnect (log_sig_id);

                Core.PlatformUtils.clear_caches ();

                if (ok) {
                    progress_bar.fraction = 1.0;
                    status_lbl.label = "✔ Installation Complete! R, Python and Quarto are ready.";
                    install_btn.label = "Done";
                    install_btn.sensitive = true;
                    install_btn.remove_css_class ("suggested-action");
                    install_btn.add_css_class ("success");
                    install_btn.clicked.disconnect (on_install_clicked);
                    install_btn.clicked.connect (() => {
                        this.close ();
                    });
                    installation_completed ();
                } else {
                    status_lbl.label = "✖ Installation encountered an error. Check logs above.";
                    install_btn.label = "Retry";
                    install_btn.sensitive = true;
                }
            });
        }

        private void append_log (string line) {
            var buffer = log_view.buffer;
            Gtk.TextIter end;
            buffer.get_end_iter (out end);
            buffer.insert (ref end, line + "\n", -1);

            // Auto-scroll to bottom
            GLib.Idle.add (() => {
                var mark = buffer.create_mark (null, end, false);
                log_view.scroll_to_mark (mark, 0.0f, true, 0.0f, 1.0f);
                return GLib.Source.REMOVE;
            });
        }
    }
}
