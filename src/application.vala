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
                { "new-tab", on_new_tab },
                { "open", on_open_file },
                { "save", on_save_file },
                { "save-as", on_save_file_as },
                { "close-tab", on_close_tab },
                { "toggle-terminal", on_toggle_terminal },
                { "run-chunk", on_run_chunk },
                { "about", on_about },
                { "quit", on_quit }
            };
            add_action_entries (action_entries, this);

            set_accels_for_action ("app.new-tab", { "<Primary>n" });
            set_accels_for_action ("app.open", { "<Primary>o" });
            set_accels_for_action ("app.save", { "<Primary>s" });
            set_accels_for_action ("app.save-as", { "<Primary><Shift>s" });
            set_accels_for_action ("app.close-tab", { "<Primary>w" });
            set_accels_for_action ("app.toggle-terminal", { "<Primary>grave" });
            set_accels_for_action ("app.run-chunk", { "<Primary>Return", "<Shift>Return" });
            set_accels_for_action ("app.quit", { "<Primary>q" });
        }

        protected override void startup () {
            base.startup ();

            var provider = new Gtk.CssProvider ();
            provider.load_from_resource ("/org/gnome/Imladris/css/style.css");
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

        private void on_new_tab () {
            if (active_app_window != null) {
                active_app_window.create_new_tab ();
            }
        }

        private void on_open_file () {
            if (active_app_window != null) {
                active_app_window.prompt_open_file ();
            }
        }

        private void on_save_file () {
            if (active_app_window != null) {
                active_app_window.save_current_tab (false);
            }
        }

        private void on_save_file_as () {
            if (active_app_window != null) {
                active_app_window.save_current_tab (true);
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
                    application_icon = "accessories-text-editor",
                    developer_name = "Imladris Developers",
                    version = "0.1.0",
                    comments = "A native GTK4 & Libadwaita Markdown Editor with asynchronous libcmark rendering and WebKit preview.",
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
