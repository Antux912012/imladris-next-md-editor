namespace Imladris {
    public class Application : Adw.Application {
        public Window? active_app_window { get; private set; default = null; }

        public Application () {
            Object (
                application_id: "org.gnome.Imladris",
                flags: ApplicationFlags.HANDLES_OPEN
            );
        }

        construct {
            ActionEntry[] action_entries = {
                { "new", on_new_document },
                { "new-tab", on_new_tab },
                { "new-project", on_new_project },
                { "open", on_open_file },
                { "save", on_save_file },
                { "save-as", on_save_file_as },
                { "export_pdf", on_export_pdf },
                { "print", on_print_document },
                { "close-tab", on_close_tab },
                { "toggle-terminal", on_toggle_terminal },
                { "run-chunk", on_run_chunk },
                { "about", on_about },
                { "quit", on_quit }
            };
            add_action_entries (action_entries, this);

            set_accels_for_action ("app.new", { "<Control>n" });
            set_accels_for_action ("app.new-project", { "<Primary><Shift>n" });
            set_accels_for_action ("app.open", { "<Control>o" });
            set_accels_for_action ("app.save", { "<Control>s" });
            set_accels_for_action ("app.save-as", { "<Primary><Shift>s" });
            set_accels_for_action ("app.print", { "<Control>p" });
            set_accels_for_action ("app.close-tab", { "<Primary>w" });
            set_accels_for_action ("app.toggle-terminal", { "<Primary>grave" });
            set_accels_for_action ("app.run-chunk", { "<Primary>Return", "<Shift>Return" });
            set_accels_for_action ("app.quit", { "<Control>q" });
        }

        protected override void startup () {
            base.startup ();

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
        }

        protected override void activate () {
            base.activate ();

            var win = active_app_window;
            if (win == null) {
                win = new Window (this);
                active_app_window = win;
            }
            win.present ();
        }

        protected override void open (File[] files, string hint) {
            base.open (files, hint);

            var win = active_app_window;
            if (win == null) {
                win = new Window (this);
                active_app_window = win;
            }
            win.present ();

            foreach (var file in files) {
                win.open_file (file);
            }
        }

        private void on_new_document () {
            if (active_app_window != null) {
                active_app_window.add_document_tab ("Untitled");
            }
        }

        private void on_new_tab () {
            if (active_app_window != null) {
                active_app_window.add_document_tab ("Untitled");
            }
        }

        private void on_new_project () {
            if (active_app_window != null) {
                active_app_window.present_welcome_or_new_project ();
            }
        }

        private void on_open_file () {
            message ("Action: Open Document triggered");
            if (active_app_window != null) {
                active_app_window.prompt_open_file ();
            }
        }

        private void on_save_file () {
            message ("Action: Save Document triggered");
            if (active_app_window != null) {
                active_app_window.save_current_tab (false);
            }
        }

        private void on_save_file_as () {
            if (active_app_window != null) {
                active_app_window.save_current_tab (true);
            }
        }

        private void on_export_pdf () {
            message ("Action: Export to PDF triggered");
            if (active_app_window != null) {
                active_app_window.show_toast ("Export to PDF triggered");
            }
        }

        private void on_print_document () {
            message ("Action: Print Document triggered");
            if (active_app_window != null) {
                active_app_window.show_toast ("Print Document triggered");
            }
        }

        private void on_close_tab () {
            if (active_app_window != null) {
                active_app_window.close_current_tab ();
            }
        }

        private void on_toggle_terminal () {
            if (active_app_window != null) {
                active_app_window.toggle_terminal ();
            }
        }

        private void on_run_chunk () {
            if (active_app_window != null) {
                active_app_window.run_current_chunk ();
            }
        }

        private void on_about () {
            if (active_app_window != null) {
                string[] developers = { "Imladris Team", "DeepMind Team" };
                var dialog = new Adw.AboutDialog () {
                    application_name = "Imladris",
                    application_icon = "org.gnome.Imladris",
                    developer_name = "Imladris Developers",
                    version = "0.1.0",
                    comments = "A native GTK4 & Libadwaita Document & Markdown Studio with 3-Tier Ribbon UI.",
                    website = "https://github.com/imladris-editor/imladris",
                    issue_url = "https://github.com/imladris-editor/imladris/issues",
                    license_type = Gtk.License.GPL_3_0,
                    developers = developers
                };
                dialog.present (active_app_window);
            }
        }

        private void on_quit () {
            quit ();
        }
    }
}
