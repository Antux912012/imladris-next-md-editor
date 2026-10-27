namespace Imladris {

    public class Application : Adw.Application {

        private const GLib.ActionEntry[] APP_ACTIONS = {
            { "new_project_modal", on_new_project_modal },
            { "new_md", on_new_md },
            { "new_qmd", on_new_qmd },
            { "new_rmd", on_new_rmd },
            { "new_ipynb", on_new_ipynb },
            { "new_r", on_new_r },
            { "new_py", on_new_py },
            { "new_ts", on_new_ts },
            { "new_html", on_new_html },
            { "open", on_open_document },
            { "save", on_save_document },
            { "export_pdf", on_export_pdf },
            { "export_html", on_export_html },
            { "export_odt", on_export_odt },
            { "export_odp", on_export_odp },
            { "export_mallorn", on_export_mallorn },
            { "export_rstudio", on_export_rstudio },
            { "export_jupyter", on_export_jupyter },
            { "package_installer", on_package_installer },
            { "elrond_assist", on_elrond_assist },
            { "toolchain_setup", on_toolchain_setup },
            { "snapshot_environment", on_snapshot_environment },
            { "restore_environment", on_restore_environment },
            { "restart_kernel", on_restart_kernel },
            { "run_cell", on_run_cell },
            { "run_all_cells", on_run_all_cells },
            { "run_line_selection", on_run_line_selection },
            { "interrupt_execution", on_interrupt_execution },
            { "preferences", on_preferences },
            { "print", on_print_document },
            { "quit", on_quit }
        };

        public Application () {
            Object (
                application_id: "io.github.Antux912012.Imladris",
                flags: GLib.ApplicationFlags.DEFAULT_FLAGS
            );
        }

        protected override void startup () {
            base.startup ();

            setup_papirus_icon_theme ();

            this.add_action_entries (APP_ACTIONS, this);
            this.set_accels_for_action ("app.new_project_modal", { "<Control>n", "<Control><Shift>n" });
            this.set_accels_for_action ("app.open", { "<Control>o" });
            this.set_accels_for_action ("app.save", { "<Control>s" });
            this.set_accels_for_action ("app.package_installer", { "<Control><Shift>p" });
            this.set_accels_for_action ("app.elrond_assist", { "<Control><Shift>e" });
            this.set_accels_for_action ("app.preferences", { "<Control>comma" });
            this.set_accels_for_action ("app.quit", { "<Control>q" });
            this.set_accels_for_action ("win.undo", { "<Control>z" });
            this.set_accels_for_action ("win.redo", { "<Control><Shift>z", "<Control>y" });
            this.set_accels_for_action ("win.collapse_ribbon", { "<Control>F1" });
            this.set_accels_for_action ("win.zoom_in", { "<Control>plus", "<Control>equal" });
            this.set_accels_for_action ("win.zoom_out", { "<Control>minus" });
            this.set_accels_for_action ("win.zoom_reset", { "<Control>0" });
            this.set_accels_for_action ("win.run_chunk", { "<Control><Shift>Return" });
            this.set_accels_for_action ("win.run_line", { "<Control>Return" });

            var provider = new Gtk.CssProvider ();
            provider.load_from_resource ("/org/imladris/app/style.css");
            var display = Gdk.Display.get_default ();
            if (display != null) {
                Gtk.StyleContext.add_provider_for_display (
                    display,
                    provider,
                    Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
                );
            }

            Core.SettingsManager.get_default ().apply_theme (Core.SettingsManager.get_default ().app_theme);
            Core.SettingsManager.get_default ().apply_accent_color (Core.SettingsManager.get_default ().accent_color);
        }

        protected override void activate () {
            var win = this.active_window as Window;
            if (win == null) {
                win = new Window (this);
            }
            win.present ();
        }

        private void on_new_project_modal () {
            var win = this.active_window as Window;
            if (win != null) win.show_new_project_modal ();
        }

        private void on_new_md () {
            var win = this.active_window as Window;
            if (win != null) win.add_document_tab ("notes.md", "markdown");
        }

        private void on_new_qmd () {
            var win = this.active_window as Window;
            if (win != null) win.add_document_tab ("analysis.qmd", "markdown");
        }

        private void on_new_rmd () {
            var win = this.active_window as Window;
            if (win != null) win.add_document_tab ("report.Rmd", "rmd");
        }

        private void on_new_ipynb () {
            var win = this.active_window as Window;
            if (win != null) win.add_document_tab ("notebook.ipynb", "json");
        }

        private void on_new_r () {
            var win = this.active_window as Window;
            if (win != null) win.add_document_tab ("script.R", "r");
        }

        private void on_new_py () {
            var win = this.active_window as Window;
            if (win != null) win.add_document_tab ("script.py", "python3");
        }

        private void on_new_ts () {
            var win = this.active_window as Window;
            if (win != null) win.add_document_tab ("module.ts", "typescript");
        }

        private void on_new_html () {
            var win = this.active_window as Window;
            if (win != null) win.add_document_tab ("index.html", "html");
        }

        private void on_open_document () {
            var win = this.active_window as Window;
            if (win != null) win.open_document_async.begin ();
        }

        private void on_save_document () {
            var win = this.active_window as Window;
            if (win != null) win.save_document_async.begin ();
        }

        private void on_export_pdf () {
            var win = this.active_window as Window;
            if (win != null) win.trigger_render ("pdf");
        }

        private void on_export_html () {
            var win = this.active_window as Window;
            if (win != null) win.trigger_render ("html");
        }

        private void on_export_odt () {
            var win = this.active_window as Window;
            if (win != null) win.export_document_dialog_async.begin ("odt");
        }

        private void on_export_odp () {
            var win = this.active_window as Window;
            if (win != null) win.export_document_dialog_async.begin ("odp");
        }

        private void on_export_mallorn () {
            var win = this.active_window as Window;
            if (win != null) win.export_mallorn_archive_async.begin ();
        }

        private void on_export_rstudio () {
            var win = this.active_window as Window;
            if (win != null) win.export_to_rstudio_async.begin ();
        }

        private void on_export_jupyter () {
            var win = this.active_window as Window;
            if (win != null) win.export_to_jupyter_async.begin ();
        }

        private void on_package_installer () {
            var win = this.active_window as Window;
            if (win != null) win.show_package_installer_dialog ();
        }

        private void on_elrond_assist () {
            var win = this.active_window as Window;
            if (win != null) win.trigger_elrond_assistance ();
        }

        private void on_toolchain_setup () {
            var win = this.active_window as Window;
            if (win != null) win.show_toolchain_setup_dialog ();
        }

        private void on_snapshot_environment () {
            var win = this.active_window as Window;
            if (win != null) win.snapshot_current_environment ();
        }

        private void on_restore_environment () {
            var win = this.active_window as Window;
            if (win != null) win.restore_current_environment ();
        }

        private void on_restart_kernel () {
            var win = this.active_window as Window;
            if (win != null) win.restart_active_kernel ();
        }

        private void on_run_cell () {
            var win = this.active_window as Window;
            if (win != null) win.run_active_chunk ();
        }

        private void on_run_all_cells () {
            var win = this.active_window as Window;
            if (win != null) win.run_all_chunks ();
        }

        private void on_run_line_selection () {
            var win = this.active_window as Window;
            if (win != null) win.run_line_or_selection ();
        }

        private void on_interrupt_execution () {
            var win = this.active_window as Window;
            if (win != null) win.interrupt_active_execution ();
        }

        private void on_preferences () {
            var win = this.active_window;
            if (win != null) new UI.PreferencesDialog ().present (win);
        }

        private void on_print_document () {
            message ("Print requested");
        }

        private void setup_papirus_icon_theme () {
            var gtk_settings = Gtk.Settings.get_default ();
            if (gtk_settings != null) {
                gtk_settings.gtk_icon_theme_name = "Papirus";
            }

            var display = Gdk.Display.get_default ();
            if (display != null) {
                var icon_theme = Gtk.IconTheme.get_for_display (display);
                icon_theme.set_theme_name ("Papirus");

                // Add bundled Papirus SVG resource path as a guaranteed fallback
                icon_theme.add_resource_path ("/org/imladris/icons/papirus");

                // If system has Papirus installed in standard XDG data dirs, prioritize it
                string[]? search_path = icon_theme.get_search_path ();
                bool has_usr_share = false;
                if (search_path != null) {
                    foreach (var p in search_path) {
                        if (p == "/usr/share/icons") {
                            has_usr_share = true;
                            break;
                        }
                    }
                }
                if (!has_usr_share) {
                    icon_theme.add_search_path ("/usr/share/icons");
                }

                // Also add local project data/icons path if running in development mode
                var cur_dir = GLib.Environment.get_current_dir ();
                var local_icon_path = GLib.Path.build_filename (cur_dir, "data", "icons", "hicolor");
                if (GLib.FileUtils.test (local_icon_path, GLib.FileTest.IS_DIR)) {
                    icon_theme.add_search_path (local_icon_path);
                }
            }
        }

        private void on_quit () {
            this.quit ();
        }
    }
}
