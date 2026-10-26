namespace Imladris.UI {

    public class NewProjectDialog : Adw.Dialog {

        public signal void item_created (GLib.File created_file, ProjectConfig config, bool is_standalone);

        private Adw.EntryRow title_row;
        private Adw.EntryRow author_row;
        private Adw.ComboRow project_format_row;
        private Adw.ActionRow project_dir_row;
        private Gtk.Label portability_warning_lbl;

        private ProjectType selected_project_type = ProjectType.SANDBOXED;
        private string custom_project_dir = "";

        public NewProjectDialog () {
            Object (
                title: "New Project or Document",
                content_width: 680,
                content_height: 720
            );
            build_ui ();
        }

        private void build_ui () {
            var toolbar_view = new Adw.ToolbarView ();
            var header = new Adw.HeaderBar ();
            toolbar_view.add_top_bar (header);

            var page = new Adw.PreferencesPage ();

            // =================================================================
            // GROUP 0: Common Metadata (Name & Author)
            // =================================================================
            var meta_group = new Adw.PreferencesGroup () {
                title = "Metadata & Location",
                description = "Configure the project or standalone file name, author, and target directory."
            };

            title_row = new Adw.EntryRow () {
                title = "Name / Title",
                text = "Research-Analysis"
            };

            author_row = new Adw.EntryRow () {
                title = "Author",
                text = GLib.Environment.get_real_name ()
            };

            project_dir_row = new Adw.ActionRow () {
                title = "Target Directory",
                subtitle = get_default_root_preview ()
            };
            var browse_btn = new Gtk.Button.from_icon_name ("folder-open-symbolic") {
                valign = Gtk.Align.CENTER,
                tooltip_text = "Choose Custom Directory"
            };
            browse_btn.add_css_class ("flat");
            browse_btn.clicked.connect (on_browse_folder);
            project_dir_row.add_suffix (browse_btn);

            title_row.changed.connect (() => {
                if (custom_project_dir == "") {
                    project_dir_row.subtitle = get_default_root_preview ();
                }
            });

            meta_group.add (title_row);
            meta_group.add (author_row);
            meta_group.add (project_dir_row);
            page.add (meta_group);

            // =================================================================
            // SECTION 1: Workspace Projects (Multi-File, Stateful)
            // =================================================================
            var proj_group = new Adw.PreferencesGroup () {
                title = "Workspace Projects",
                description = "Full project scaffolding with data/, images/, bibliography/, and 1:1 RStudio (.Rproj / .mallorn) compatibility."
            };

            var notebook_formats = new Gtk.StringList ({
                "Quarto Document (.qmd)",
                "R Markdown (.Rmd)",
                "Jupyter Notebook (.ipynb)"
            });

            project_format_row = new Adw.ComboRow () {
                title = "Primary Project Notebook Format",
                subtitle = "Projects are restricted to computational notebook formats (.Rmd, .Qmd, .ipynb)",
                model = notebook_formats,
                selected = 0
            };
            proj_group.add (project_format_row);

            // Target: Standard Project
            var row_standard = new Adw.ActionRow () {
                title = "Create a Project",
                subtitle = "Uses your computer's global R and Python packages. Fast setup, best for local analysis."
            };
            row_standard.add_prefix (new Gtk.Image.from_icon_name ("folder-symbolic"));
            var btn_create_standard = new Gtk.Button.with_label ("Create Project") {
                valign = Gtk.Align.CENTER
            };
            btn_create_standard.add_css_class ("flat");
            btn_create_standard.clicked.connect (() => {
                selected_project_type = ProjectType.STANDARD;
                create_workspace_project (ProjectType.STANDARD);
            });
            row_standard.add_suffix (btn_create_standard);
            proj_group.add (row_standard);

            // Target: Sandboxed Project
            var row_sandboxed = new Adw.ActionRow () {
                title = "Create a Sandboxed project",
                subtitle = "Isolated, reproducible environment using local renv (R) and .venv (Python). Best for sharing and publishing."
            };
            row_sandboxed.add_prefix (new Gtk.Image.from_icon_name ("security-high-symbolic"));
            var btn_create_sandboxed = new Gtk.Button.with_label ("Create Sandboxed") {
                valign = Gtk.Align.CENTER
            };
            btn_create_sandboxed.add_css_class ("suggested-action");
            btn_create_sandboxed.clicked.connect (() => {
                selected_project_type = ProjectType.SANDBOXED;
                create_workspace_project (ProjectType.SANDBOXED);
            });
            row_sandboxed.add_suffix (btn_create_sandboxed);
            proj_group.add (row_sandboxed);

            portability_warning_lbl = new Gtk.Label (
                "ℹ Note: Standard projects use system libraries. Sandboxed projects include lockfiles for 1:1 RStudio & Jupyter export."
            ) {
                wrap = true,
                xalign = 0.0f,
                margin_top = 6
            };
            portability_warning_lbl.add_css_class ("dim-label");
            portability_warning_lbl.add_css_class ("caption");
            proj_group.add (portability_warning_lbl);

            page.add (proj_group);

            // =================================================================
            // SECTION 2: Standalone Simple Files (Single-File Mode)
            // =================================================================
            var standalone_group = new Adw.PreferencesGroup () {
                title = "Standalone Simple Files",
                description = "Create a single self-contained file with starter boilerplate."
            };

            add_standalone_target_row (
                standalone_group,
                "Create a simple .md",
                "Lightweight prose editing in Apostrophe mode with live preview, bypassing compute kernels.",
                "text-x-generic-symbolic",
                DocumentFormat.MD
            );
            add_standalone_target_row (
                standalone_group,
                "Create a simple .html",
                "Standard HTML5 boilerplate with live WebKitGTK 6.0 DOM preview.",
                "text-html-symbolic",
                DocumentFormat.HTML
            );
            add_standalone_target_row (
                standalone_group,
                "Create a R script file",
                "Standard R script bound to system Rscript executable.",
                "utilities-terminal-symbolic",
                DocumentFormat.RSCRIPT
            );
            add_standalone_target_row (
                standalone_group,
                "Create a .Rmd",
                "Standalone R Markdown document with YAML frontmatter and knitr setup chunk.",
                "x-office-document-symbolic",
                DocumentFormat.RMD
            );
            add_standalone_target_row (
                standalone_group,
                "Create a .Qmd",
                "Standalone Quarto scientific document with YAML frontmatter template.",
                "document-edit-symbolic",
                DocumentFormat.QMD
            );
            add_standalone_target_row (
                standalone_group,
                "Create a .ipynb",
                "Valid JSON schema v4 notebook structure with bidirectional cell editing.",
                "applications-science-symbolic",
                DocumentFormat.IPYNB
            );
            add_standalone_target_row (
                standalone_group,
                "Create a Python script",
                "Standard Python 3 script bound to system Python interpreter.",
                "utilities-terminal-symbolic",
                DocumentFormat.PYSCRIPT
            );

            page.add (standalone_group);

            toolbar_view.content = page;
            this.child = toolbar_view;
        }

        private void add_standalone_target_row (
            Adw.PreferencesGroup group,
            string title,
            string subtitle,
            string icon_name,
            DocumentFormat fmt
        ) {
            var row = new Adw.ActionRow () {
                title = title,
                subtitle = subtitle
            };
            row.add_prefix (new Gtk.Image.from_icon_name (icon_name));

            var btn = new Gtk.Button.with_label (@"New $(fmt.get_extension ())") {
                valign = Gtk.Align.CENTER
            };
            btn.add_css_class ("flat");
            DocumentFormat target_fmt = fmt;
            btn.clicked.connect (() => {
                create_standalone_document (target_fmt);
            });
            row.add_suffix (btn);
            row.activatable_widget = btn;
            group.add (row);
        }

        private DocumentFormat get_selected_project_format () {
            uint sel = project_format_row.selected;
            switch (sel) {
                case 1:  return DocumentFormat.RMD;
                case 2:  return DocumentFormat.IPYNB;
                case 0:
                default: return DocumentFormat.QMD;
            }
        }

        private string get_default_root_preview () {
            string clean_name = ProjectScaffolder.sanitize_dirname (title_row.text);
            return GLib.Path.build_filename (GLib.Environment.get_home_dir (), "Documents", clean_name);
        }

        private void on_browse_folder () {
            var dialog = new Gtk.FileDialog () {
                title = "Select Target Folder"
            };
            var root_win = this.get_root () as Gtk.Window;
            dialog.select_folder.begin (root_win, null, (obj, res) => {
                try {
                    var folder = dialog.select_folder.end (res);
                    if (folder != null && folder.get_path () != null) {
                        custom_project_dir = folder.get_path ();
                        project_dir_row.subtitle = custom_project_dir;
                    }
                } catch (GLib.Error e) {
                    // User cancelled
                }
            });
        }

        private void create_workspace_project (ProjectType ptype) {
            var cfg = new ProjectConfig () {
                project_name = title_row.text.strip () != "" ? title_row.text.strip () : "Untitled-Project",
                author = author_row.text.strip (),
                project_type = ptype,
                format = get_selected_project_format (),
                custom_project_dir = this.custom_project_dir
            };

            try {
                GLib.File created_doc = ProjectScaffolder.create_project (cfg);
                item_created (created_doc, cfg, false);
                this.close ();
            } catch (GLib.Error e) {
                GLib.warning ("Failed to scaffold workspace project: %s", e.message);
            }
        }

        private void create_standalone_document (DocumentFormat fmt) {
            string base_docs = this.custom_project_dir != ""
                ? this.custom_project_dir
                : GLib.Path.build_filename (GLib.Environment.get_home_dir (), "Documents");
            string name = title_row.text.strip () != "" ? title_row.text.strip () : "Untitled";

            var cfg = new ProjectConfig () {
                project_name = name,
                author = author_row.text.strip (),
                project_type = ProjectType.STANDARD,
                format = fmt,
                custom_project_dir = base_docs
            };

            try {
                GLib.File created_file = ProjectScaffolder.create_standalone_file (
                    base_docs,
                    name,
                    fmt,
                    cfg.author
                );
                item_created (created_file, cfg, true);
                this.close ();
            } catch (GLib.Error e) {
                GLib.warning ("Failed to create standalone file: %s", e.message);
            }
        }
    }
}
