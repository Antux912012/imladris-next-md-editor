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

            this.add_action_entries (APP_ACTIONS, this);
            this.set_accels_for_action ("app.new_project_modal", { "<Control>n", "<Control><Shift>n" });
            this.set_accels_for_action ("app.open", { "<Control>o" });
            this.set_accels_for_action ("app.save", { "<Control>s" });
            this.set_accels_for_action ("app.quit", { "<Control>q" });

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

        private void on_print_document () {
            message ("Print requested");
        }

        private void on_quit () {
            this.quit ();
        }
    }
}
