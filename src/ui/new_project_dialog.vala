namespace Imladris {

    public class NewProjectDialog : Adw.Dialog {
        public signal void project_created (File main_document_file, ProjectConfig config);

        private Adw.EntryRow title_row;
        private Adw.EntryRow author_row;
        private Adw.ComboRow format_row;

        private Adw.ActionRow project_dir_row;
        private Adw.ActionRow data_dir_row;
        private Adw.ActionRow images_dir_row;
        private Adw.ActionRow bib_dir_row;

        private string custom_project_dir = "";
        private string custom_data_dir = "";
        private string custom_images_dir = "";
        private string custom_bib_dir = "";

        public NewProjectDialog () {
            Object (
                title: "New Document / Project",
                content_width: 560,
                content_height: 620
            );
            build_ui ();
        }

        private void build_ui () {
            var toolbar_view = new Adw.ToolbarView ();
            var header = new Adw.HeaderBar ();
            toolbar_view.add_top_bar (header);

            var page = new Adw.PreferencesPage ();

            // --- Group 1: Document Essentials ---
            var core_group = new Adw.PreferencesGroup ();
            core_group.title = "Document Format & Metadata";
            core_group.description = "Choose the document format and project name.";

            var format_list = new Gtk.StringList ({
                "Standard Markdown (.md)",
                "Quarto Document (.qmd)",
                "R Markdown (.Rmd)",
                "Jupyter Notebook (.ipynb)"
            });

            format_row = new Adw.ComboRow ();
            format_row.title = "Document Type";
            format_row.model = format_list;
            format_row.selected = 1; // Default to Quarto (.qmd)

            title_row = new Adw.EntryRow ();
            title_row.title = "Project / Document Name";
            title_row.text = "My-Research-Project";

            author_row = new Adw.EntryRow ();
            author_row.title = "Author (Optional)";
            author_row.text = Environment.get_real_name ();

            core_group.add (format_row);
            core_group.add (title_row);
            core_group.add (author_row);
            page.add (core_group);

            // --- Group 2: Optional Folder Overrides ---
            var paths_group = new Adw.PreferencesGroup ();
            paths_group.title = "Workspace Directories (Optional)";
            paths_group.description = "Leave unset to auto-generate inside ~/Documents/<Project Name>/ with data/, images/, and bibliography/.";

            project_dir_row = create_folder_picker_row (
                "Project Root Folder",
                get_default_root_preview (),
                (path) => {
                    custom_project_dir = path;
                    project_dir_row.subtitle = path;
                }
            );

            data_dir_row = create_folder_picker_row (
                "Data Folder",
                "Auto (./data)",
                (path) => {
                    custom_data_dir = path;
                    data_dir_row.subtitle = path;
                }
            );

            images_dir_row = create_folder_picker_row (
                "Pictures / Figures Folder",
                "Auto (./images)",
                (path) => {
                    custom_images_dir = path;
                    images_dir_row.subtitle = path;
                }
            );

            bib_dir_row = create_folder_picker_row (
                "Bibliography Folder",
                "Auto (./bibliography)",
                (path) => {
                    custom_bib_dir = path;
                    bib_dir_row.subtitle = path;
                }
            );

            // Live-update the default path preview as the user types the project name
            title_row.changed.connect (() => {
                if (custom_project_dir == "") {
                    project_dir_row.subtitle = get_default_root_preview ();
                }
            });

            paths_group.add (project_dir_row);
            paths_group.add (data_dir_row);
            paths_group.add (images_dir_row);
            paths_group.add (bib_dir_row);
            page.add (paths_group);

            // --- Group 3: Action Buttons ---
            var action_group = new Adw.PreferencesGroup ();
            var create_btn = new Gtk.Button.with_label ("Create Project Workspace");
            create_btn.halign = Gtk.Align.END;
            create_btn.add_css_class ("suggested-action");
            create_btn.add_css_class ("pill");
            create_btn.clicked.connect (on_create_clicked);

            action_group.add (create_btn);
            page.add (action_group);

            toolbar_view.content = page;
            this.child = toolbar_view;
        }

        private string get_default_root_preview () {
            string clean_name = title_row.text.strip () != "" ? title_row.text.strip ().replace (" ", "_") : "Untitled_Project";
            return Path.build_filename (Environment.get_home_dir (), "Documents", clean_name);
        }

        private delegate void FolderSelectedCallback (string path);

        private Adw.ActionRow create_folder_picker_row (string title, string initial_subtitle, owned FolderSelectedCallback cb) {
            var row = new Adw.ActionRow ();
            row.title = title;
            row.subtitle = initial_subtitle;

            var browse_btn = new Gtk.Button.from_icon_name ("folder-open-symbolic");
            browse_btn.valign = Gtk.Align.CENTER;
            browse_btn.tooltip_text = "Select Custom Folder";
            browse_btn.add_css_class ("flat");

            browse_btn.clicked.connect (() => {
                var dialog = new Gtk.FileDialog ();
                dialog.title = "Select " + title;
                var root_win = this.get_root () as Gtk.Window;
                dialog.select_folder.begin (root_win, null, (obj, res) => {
                    try {
                        File folder = dialog.select_folder.end (res);
                        if (folder != null && folder.get_path () != null) {
                            cb (folder.get_path ());
                        }
                    } catch (Error e) {
                        // User cancelled dialog
                    }
                });
            });

            row.add_suffix (browse_btn);
            return row;
        }

        private void on_create_clicked () {
            var cfg = new ProjectConfig () {
                project_name = title_row.text,
                author = author_row.text,
                format = (DocumentFormat) format_row.selected,
                custom_project_dir = this.custom_project_dir,
                custom_data_dir = this.custom_data_dir,
                custom_images_dir = this.custom_images_dir,
                custom_bib_dir = this.custom_bib_dir
            };

            try {
                File created_doc = ProjectScaffolder.create_project (cfg);
                project_created (created_doc, cfg);
                this.close ();
            } catch (Error e) {
                warning ("Failed to scaffold project: %s", e.message);
            }
        }
    }
}
