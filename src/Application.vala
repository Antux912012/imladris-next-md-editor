namespace Imladris {

    public class Application : Adw.Application {

        private const GLib.ActionEntry[] APP_ACTIONS = {
            { "new_qmd", on_new_qmd },
            { "new_rmd", on_new_rmd },
            { "new_ipynb", on_new_ipynb },
            { "new_ts", on_new_ts },
            { "new_html", on_new_html },
            { "open", on_open_document },
            { "save", on_save_document },
            { "export_pdf", on_export_pdf },
            { "export_html", on_export_html },
            { "print", on_print_document },
            { "quit", on_quit }
        };

        public Application () {
            Object (
                application_id: "org.imladris.app",
                flags: GLib.ApplicationFlags.DEFAULT_FLAGS
            );
        }

        protected override void startup () {
            base.startup ();

            this.add_action_entries (APP_ACTIONS, this);
            this.set_accels_for_action ("app.new_qmd", { "<Control>n" });
            this.set_accels_for_action ("app.open", { "<Control>o" });
            this.set_accels_for_action ("app.save", { "<Control>s" });
            this.set_accels_for_action ("app.quit", { "<Control>q" });

            var provider = new Gtk.CssProvider ();
            provider.load_from_resource ("/org/imladris/app/style.css");
            Gtk.StyleContext.add_provider_for_display (
                Gdk.Display.get_default (),
                provider,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            );
        }

        protected override void activate () {
            var win = this.active_window as Window;
            if (win == null) {
                win = new Window (this);
            }
            win.present ();
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

        private void on_new_ts () {
            var win = this.active_window as Window;
            if (win != null) win.add_document_tab ("module.ts", "typescript");
        }

        private void on_new_html () {
            var win = this.active_window as Window;
            if (win != null) win.add_document_tab ("index.html", "html");
        }

        private void on_open_document () {
            message ("Open file dialog requested");
        }

        private void on_save_document () {
            message ("Save current buffer requested");
        }

        private void on_export_pdf () {
            var win = this.active_window as Window;
            if (win != null) win.trigger_render ("pdf");
        }

        private void on_export_html () {
            var win = this.active_window as Window;
            if (win != null) win.trigger_render ("html");
        }

        private void on_print_document () {
            message ("Print requested");
        }

        private void on_quit () {
            this.quit ();
        }
    }
}
