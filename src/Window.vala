namespace Imladris {

    public class Window : Adw.ApplicationWindow {

        private Gtk.Stack ribbon_stack;
        private Gtk.ScrolledWindow ribbon_scroller;
        private Gtk.Button? btn_collapse_ribbon = null;
        private Adw.TabView tab_view;
        private Adw.TabBar tab_bar;
        private Gtk.Label status_badge_lbl;
        private Gtk.Label status_env_badge_lbl;
        private Gtk.Label status_words_lbl;
        private Gtk.Label status_kernel_lbl;
        private Gtk.Scale zoom_scale;
        private Gtk.Label zoom_lbl;
        private int current_zoom = 100;

        public string current_project_dir { get; private set; default = ""; }
        public ProjectType current_project_type { get; private set; default = ProjectType.STANDARD; }

        // Ribbon buttons tracked for Context-Aware State Machine (Pillar 2)
        private Gtk.Widget? btn_insert_r = null;
        private Gtk.Widget? btn_insert_py = null;
        private Gtk.Widget? btn_run_chunk = null;
        private Gtk.Widget? btn_run_all = null;
        private Gtk.Widget? btn_run_above = null;
        private Gtk.Widget? btn_run_below = null;
        private Gtk.Widget? btn_run_line = null;
        private Gtk.Widget? btn_source_file = null;
        private Gtk.Widget? btn_interrupt = null;
        private Gtk.Widget? btn_restart_kernel = null;
        private Gtk.Widget? btn_package_installer = null;
        private Gtk.Widget? btn_snapshot_env = null;
        private Gtk.Widget? btn_restore_env = null;
        private Gtk.Widget? btn_render_html = null;
        private Gtk.Widget? btn_render_pdf = null;
        private Gtk.Widget? btn_export_odt = null;
        private Gtk.Widget? btn_export_odp = null;
        private Gtk.Widget? btn_export_mallorn = null;
        private Gtk.Widget? btn_export_rstudio = null;
        private Gtk.Widget? btn_export_jupyter = null;
        private Gtk.Widget? btn_live_preview = null;

        private UI.PackageIndexCache pkg_index_cache = new UI.PackageIndexCache ();

        public Window (Adw.Application app) {
            Object (
                application: app,
                title: "Imladris — Polyglot Scientific & Web Studio",
                default_width: 1380,
                default_height: 860
            );
        }

        construct {
            setup_actions ();

            var settings = Core.SettingsManager.get_default ();
            if (settings.app_theme == Core.AppTheme.EYE_FRIENDLY) {
                this.add_css_class ("eye-friendly");
            }
            settings.theme_changed.connect ((theme) => {
                if (theme == Core.AppTheme.EYE_FRIENDLY) {
                    this.add_css_class ("eye-friendly");
                } else {
                    this.remove_css_class ("eye-friendly");
                }
            });

            var toolbar_view = new Adw.ToolbarView ();
            this.set_content (toolbar_view);

            var top_master_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            toolbar_view.add_top_bar (top_master_box);

            // =================================================================
            // TIER 1: DARK HEADER BAR & CATEGORY SWITCHER (5 Modernized Tabs)
            // =================================================================
            var win_handle = new Gtk.WindowHandle ();
            var tier1_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 2);
            tier1_box.add_css_class ("imladris-topbar");
            win_handle.set_child (tier1_box);

            // Branded "Imladris" Primary Menu
            var brand_menu = new GLib.Menu ();
            var new_sec = new GLib.Menu ();
            new_sec.append ("New Project or Document...", "app.new_project_modal");
            new_sec.append ("New Quarto Document (.qmd)", "app.new_qmd");
            new_sec.append ("New R Markdown (.Rmd)", "app.new_rmd");
            new_sec.append ("New Jupyter Notebook (.ipynb)", "app.new_ipynb");
            new_sec.append ("New Simple Markdown (.md)", "app.new_md");
            new_sec.append ("New R Script (.R)", "app.new_r");
            new_sec.append ("New Python Script (.py)", "app.new_py");
            new_sec.append ("New HTML5 Document (.html)", "app.new_html");
            brand_menu.append_section ("Create New", new_sec);

            var io_sec = new GLib.Menu ();
            io_sec.append ("Open Document or Project...", "app.open");
            io_sec.append ("Save", "app.save");
            io_sec.append ("Render to HTML", "app.export_html");
            io_sec.append ("Render to PDF", "app.export_pdf");
            io_sec.append ("Export OpenDocument Text (.odt)", "app.export_odt");
            io_sec.append ("Export OpenDocument Presentation (.odp)", "app.export_odp");
            io_sec.append ("Export Portable .mallorn Archive", "app.export_mallorn");
            io_sec.append ("Export for RStudio", "app.export_rstudio");
            io_sec.append ("Export for Jupyter", "app.export_jupyter");
            io_sec.append ("Quit Imladris", "app.quit");
            brand_menu.append_section ("File & Export", io_sec);

            var prefs_sec = new GLib.Menu ();
            prefs_sec.append ("Preferences", "app.preferences");
            brand_menu.append_section (null, prefs_sec);

            var brand_btn = new Gtk.MenuButton () {
                menu_model = brand_menu,
                valign = Gtk.Align.CENTER
            };
            brand_btn.add_css_class ("imladris-brand-btn");
            var brand_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
            brand_box.append (new Gtk.Image.from_icon_name ("document-edit-symbolic"));
            brand_box.append (new Gtk.Label ("Imladris ▾"));
            brand_btn.set_child (brand_box);
            tier1_box.append (brand_btn);

            ribbon_stack = new Gtk.Stack () {
                transition_type = Gtk.StackTransitionType.CROSSFADE,
                transition_duration = 120
            };

            string[] categories = {
                "Home", "Insert", "Computation", "Publish", "View"
            };

            Gtk.ToggleButton? first_tab = null;
            foreach (string cat in categories) {
                var tab_btn = new Gtk.ToggleButton.with_label (cat);
                tab_btn.add_css_class ("ribbon-tab-btn");
                if (cat == "Computation") tab_btn.add_css_class ("ribbon-tab-scientific");
                if (cat == "Publish") tab_btn.add_css_class ("ribbon-tab-web");

                if (first_tab == null) {
                    first_tab = tab_btn;
                    tab_btn.active = true;
                } else {
                    tab_btn.set_group (first_tab);
                }

                string target_cat = cat;
                tab_btn.toggled.connect (() => {
                    if (tab_btn.active) {
                        ribbon_stack.visible_child_name = target_cat;
                    }
                });

                tier1_box.append (tab_btn);
            }

            tier1_box.append (new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) { hexpand = true });

            btn_collapse_ribbon = new Gtk.Button.from_icon_name ("pan-up-symbolic") {
                tooltip_text = "Toggle Ribbon (Ctrl+F1)",
                valign = Gtk.Align.CENTER
            };
            btn_collapse_ribbon.add_css_class ("flat");
            btn_collapse_ribbon.clicked.connect (() => {
                toggle_ribbon_visibility ();
            });
            tier1_box.append (btn_collapse_ribbon);

            tier1_box.append (new Gtk.WindowControls (Gtk.PackType.END));
            top_master_box.append (win_handle);

            // =================================================================
            // TIER 2: DYNAMIC MODERN RIBBON DECK (5 High-Density Tabs)
            // =================================================================
            ribbon_scroller = new Gtk.ScrolledWindow () {
                vscrollbar_policy = Gtk.PolicyType.NEVER,
                hscrollbar_policy = Gtk.PolicyType.AUTOMATIC
            };
            ribbon_scroller.add_css_class ("ribbon-deck");
            ribbon_scroller.set_child (ribbon_stack);
            top_master_box.append (ribbon_scroller);

            ribbon_stack.add_named (build_home_ribbon (), "Home");
            ribbon_stack.add_named (build_insert_ribbon (), "Insert");
            ribbon_stack.add_named (build_computation_ribbon (), "Computation");
            ribbon_stack.add_named (build_publish_ribbon (), "Publish");
            ribbon_stack.add_named (build_view_ribbon (), "View");

            // =================================================================
            // TIER 3: QUICK ACCESS TOOLBAR & ADW.TABBAR
            // =================================================================
            var tier3_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4);
            tier3_box.add_css_class ("imladris-subbar");

            tier3_box.append (RibbonFactory.create_compact_button ("folder-open-symbolic", null, false, false, true, null, "app.open"));
            tier3_box.append (RibbonFactory.create_compact_button ("document-save-symbolic", null, false, false, true, null, "app.save"));
            tier3_box.append (RibbonFactory.create_compact_button ("document-send-symbolic", "PDF", false, false, true, null, "app.export_pdf"));
            tier3_box.append (RibbonFactory.create_compact_button ("applications-internet-symbolic", "HTML", false, false, true, null, "app.export_html"));
            tier3_box.append (RibbonFactory.create_compact_button ("edit-undo-symbolic", null, false, false, true, null, "win.undo"));
            tier3_box.append (RibbonFactory.create_compact_button ("edit-redo-symbolic", null, false, false, true, null, "win.redo"));
            var ai_quick_btn = RibbonFactory.create_compact_button ("system-run-symbolic", "AI Assistant");
            ((Gtk.Button) ai_quick_btn).clicked.connect (() => {
                trigger_ai_assistant ();
            });
            tier3_box.append (ai_quick_btn);

            var rstudio_toggle_btn = RibbonFactory.create_compact_button ("view-grid-symbolic", "RStudio / Focus");
            ((Gtk.Button) rstudio_toggle_btn).clicked.connect (() => {
                var mgr = Services.WorkspaceStateManager.get_default ();
                var next_mode = mgr.active_layout == Services.LayoutMode.RSTUDIO
                    ? Services.LayoutMode.APOSTROPHE
                    : Services.LayoutMode.RSTUDIO;
                mgr.set_layout_mode (next_mode, true);
            });
            tier3_box.append (rstudio_toggle_btn);
            tier3_box.append (RibbonFactory.create_vseparator ());

            tab_view = new Adw.TabView ();
            tab_bar = new Adw.TabBar () {
                view = tab_view,
                autohide = false,
                expand_tabs = false,
                hexpand = true
            };

            var add_tab_btn = new Gtk.Button.from_icon_name ("list-add-symbolic") {
                tooltip_text = "New Project or Document (Ctrl+N)"
            };
            add_tab_btn.add_css_class ("flat");
            add_tab_btn.clicked.connect (() => {
                show_new_project_modal ();
            });
            tab_bar.set_end_action_widget (add_tab_btn);

            tier3_box.append (tab_bar);
            top_master_box.append (tier3_box);

            // =================================================================
            // BOTTOM STATUS BAR (Live Metrics, Kernel Status & Zoom Slider)
            // =================================================================
            var status_bar = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
            status_bar.add_css_class ("imladris-statusbar");

            status_badge_lbl = new Gtk.Label ("QUARTO / MD");
            status_badge_lbl.add_css_class ("status-badge");
            status_bar.append (status_badge_lbl);

            status_env_badge_lbl = new Gtk.Label ("[Sandboxed - Reproducible]");
            status_env_badge_lbl.add_css_class ("status-badge");
            status_env_badge_lbl.add_css_class ("env-badge");
            status_bar.append (status_env_badge_lbl);

            status_kernel_lbl = new Gtk.Label ("Kernels: R • Python 3");
            status_bar.append (status_kernel_lbl);

            status_words_lbl = new Gtk.Label ("Words: 0 | Lines: 1");
            status_bar.append (status_words_lbl);

            status_bar.append (new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) { hexpand = true });

            zoom_lbl = new Gtk.Label ("100%");
            zoom_scale = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, 50, 200, 10) {
                draw_value = false,
                width_request = 110
            };
            zoom_scale.set_value (100);
            zoom_scale.value_changed.connect (() => {
                apply_zoom ((int) zoom_scale.get_value ());
            });
            status_bar.append (new Gtk.Label ("Zoom:"));
            status_bar.append (zoom_scale);
            status_bar.append (zoom_lbl);

            toolbar_view.add_bottom_bar (status_bar);

            // =================================================================
            // MAIN WORKSPACE & STATE MACHINE LISTENERS
            // =================================================================
            toolbar_view.set_content (tab_view);

            Services.WorkspaceStateManager.get_default ().layout_changed.connect ((mode) => {
                apply_workspace_layout (mode);
            });

            Services.WorkspaceStateManager.get_default ().split_changed.connect ((split) => {
                var d = get_active_document ();
                if (d != null) {
                    d.set_split_orientation (split);
                }
            });

            tab_view.notify["selected-page"].connect (() => {
                var d = get_active_document ();
                if (d != null) {
                    string fname = d.file_location != null ? d.file_location.get_basename () : @"untitled.$(d.doc_type)";
                    Services.WorkspaceStateManager.get_default ().resolve_mode_for_file (fname);
                    d.set_split_orientation (Services.WorkspaceStateManager.get_default ().active_split);
                    var fmt = d.get_document_format ();
                    update_ribbon_state_machine (fmt, current_project_type);
                    if (d.file_location != null && d.file_location.get_parent () != null) {
                        Services.PersistentSessionManager.get_default ().set_working_directory (
                            d.file_location.get_parent ().get_path (), current_project_type
                        );
                    }
                }
            });

            add_document_tab ("Document1.qmd", "markdown");

            // Check for crash recovery snapshots on launch
            GLib.Idle.add (() => {
                check_and_prompt_recovery ();
                return GLib.Source.REMOVE;
            });
        }

        private void apply_workspace_layout (Services.LayoutMode mode) {
            var doc = get_active_document ();
            ribbon_stack.visible = true;
            if (doc != null) {
                doc.set_workbench_mode (mode);
            }
        }

        private void check_and_prompt_recovery () {
            var recs = Services.RecoveryService.get_default ().check_recoverable_sessions ();
            if (recs.size > 0) {
                var toast = new Adw.Toast (@"Imladris detected $(recs.size) unsaved document(s) from a previous session.") {
                    button_label = "Restore",
                    timeout = 0
                };
                toast.button_clicked.connect (() => {
                    foreach (var rec in recs) {
                        string title = rec.file_path != null ? GLib.Path.get_basename (rec.file_path) : "Recovered-Document.md";
                        GLib.File? f = rec.file_path != null ? GLib.File.new_for_path (rec.file_path) : null;
                        add_document_tab (title, rec.doc_type, rec.content, f);
                    }
                });
                // Find toast overlay if present or notify via document log
                var d = get_active_document ();
                if (d != null) {
                    d.append_console_log (@"⚠ Crash Recovery: $(recs.size) unsaved snapshot(s) found in cache.");
                }
            }
        }

        public DocumentPage? get_active_document () {
            if (tab_view.selected_page == null) return null;
            return tab_view.selected_page.child as DocumentPage;
        }

        public void trigger_ai_assistant () {
            var doc = get_active_document ();
            if (doc != null) {
                doc.show_ai_assistant ();
            }
        }

        public void add_document_tab (string title, string lang_id, string? initial_text = null, GLib.File? file = null) {
            var doc_page = new DocumentPage (title, lang_id, this);
            if (initial_text != null) {
                doc_page.source_buffer.text = initial_text;
            }
            if (file != null) {
                doc_page.file_location = file;
            }
            doc_page.project_type = current_project_type;
            doc_page.stats_changed.connect ((words, lines, badge) => {
                status_badge_lbl.label = badge;
                status_words_lbl.label = @"Words: $words | Lines: $lines";
            });

            var page = tab_view.append (doc_page);
            page.title = title;
            page.icon = new GLib.ThemedIcon ("x-office-document-symbolic");
            tab_view.selected_page = page;
            doc_page.emit_buffer_stats ();

            var fmt = doc_page.get_document_format ();
            update_ribbon_state_machine (fmt, current_project_type);
        }

        public void show_new_project_modal () {
            var dlg = new UI.NewProjectDialog ();
            dlg.item_created.connect ((file, config, is_standalone) => {
                this.current_project_type = config.project_type;
                if (file.get_parent () != null) {
                    this.current_project_dir = file.get_parent ().get_path ();
                    Services.PersistentSessionManager.get_default ().set_working_directory (
                        this.current_project_dir, config.project_type
                    );
                }
                update_environment_badge (config.project_type);
                open_file_from_path.begin (file.get_path ());
            });
            dlg.present (this);
        }

        public void update_environment_badge (ProjectType ptype) {
            if (ptype == ProjectType.SANDBOXED) {
                status_env_badge_lbl.label = "[Sandboxed - Reproducible]";
                status_env_badge_lbl.remove_css_class ("env-standard");
                status_env_badge_lbl.add_css_class ("env-sandboxed");
            } else {
                status_env_badge_lbl.label = "[System Libraries - Non-Portable]";
                status_env_badge_lbl.remove_css_class ("env-sandboxed");
                status_env_badge_lbl.add_css_class ("env-standard");
            }
        }

        public async void open_file_from_path (string fpath) {
            try {
                var file = GLib.File.new_for_path (fpath);
                string name = file.get_basename ();

                // Check if opening an RStudio .Rproj or .mallorn project marker / archive
                if (name.has_suffix (".mallorn") || name.has_suffix (".Rproj")) {
                    if (name.has_suffix (".mallorn") && MallornManager.is_mallorn_archive (fpath)) {
                        string dest_dir = GLib.Path.build_filename (
                            file.get_parent ().get_path (),
                            name.substring (0, name.length - 8)
                        );
                        try {
                            var unpacked_cfg = MallornManager.unpack_mallorn_archive (fpath, dest_dir);
                            update_environment_badge (unpacked_cfg.project_type);
                            var d = get_active_document ();
                            if (d != null) {
                                d.append_console_log (@"✔ Extracted .mallorn archive to $dest_dir");
                            }
                            // Search for primary notebook in the extracted directory
                            string[] candidates = { "analysis.qmd", "report.Rmd", "notebook.ipynb", "index.qmd" };
                            foreach (var cand in candidates) {
                                string cand_path = GLib.Path.build_filename (dest_dir, cand);
                                if (GLib.FileUtils.test (cand_path, GLib.FileTest.EXISTS)) {
                                    yield open_file_from_path (cand_path);
                                    return;
                                }
                            }
                        } catch (GLib.Error e) {
                            warning ("Failed to unpack mallorn archive: %s", e.message);
                        }
                    } else {
                        // Opened an .Rproj or .mallorn project file in a project folder
                        var proj_dir = file.get_parent ();
                        var ptype = Services.SandboxController.detect_project_type (proj_dir.get_path ());
                        update_environment_badge (ptype);
                        string[] candidates = { "analysis.qmd", "report.Rmd", "notebook.ipynb", "index.qmd", "main.R", "main.py" };
                        foreach (var cand in candidates) {
                            string cand_path = GLib.Path.build_filename (proj_dir.get_path (), cand);
                            if (GLib.FileUtils.test (cand_path, GLib.FileTest.EXISTS)) {
                                yield open_file_from_path (cand_path);
                                return;
                            }
                        }
                    }
                }

                // Normal document opening
                uint8[] contents;
                string etag;
                yield file.load_contents_async (null, out contents, out etag);
                string raw_text = (string) contents;

                var fmt = DocumentFormat.from_filename (name);
                string text = Adapters.DocumentAdapter.load_to_editor_buffer (raw_text, fmt);

                string lang = "markdown";
                if (name.has_suffix (".ipynb")) lang = "json";
                else if (name.has_suffix (".ts")) lang = "typescript";
                else if (name.has_suffix (".html") || name.has_suffix (".htm")) lang = "html";
                else if (name.has_suffix (".rmd") || name.has_suffix (".Rmd")) lang = "rmd";
                else if (name.has_suffix (".r") || name.has_suffix (".R")) lang = "r";
                else if (name.has_suffix (".py")) lang = "python3";

                add_document_tab (name, lang, text, file);

                // Detect surrounding project sandbox/standard status
                var parent_dir = file.get_parent ();
                if (parent_dir != null) {
                    var ptype = Services.SandboxController.detect_project_type (parent_dir.get_path ());
                    this.current_project_type = ptype;
                    this.current_project_dir = parent_dir.get_path ();
                    Services.PersistentSessionManager.get_default ().set_working_directory (this.current_project_dir, ptype);
                    update_environment_badge (ptype);
                    update_ribbon_state_machine (fmt, ptype);
                }

                Services.WorkspaceStateManager.get_default ().resolve_mode_for_file (name);
            } catch (GLib.Error e) {
                warning ("Failed to open file from path %s: %s", fpath, e.message);
            }
        }

        public async void open_document_async () {
            var dialog = new Gtk.FileDialog () {
                title = "Open Document or Project",
                modal = true
            };
            try {
                var file = yield dialog.open (this, null);
                if (file != null) {
                    yield open_file_from_path (file.get_path ());
                }
            } catch (GLib.Error e) {
                warning ("Failed to open file: %s", e.message);
            }
        }

        public async void save_document_async () {
            var doc = get_active_document ();
            if (doc == null) return;

            if (doc.file_location != null) {
                try {
                    string editor_content = doc.source_buffer.text;
                    var fmt = DocumentFormat.from_filename (doc.file_location.get_basename ());
                    string to_save = Adapters.DocumentAdapter.save_from_editor_buffer (editor_content, fmt);
                    string etag;
                    yield doc.file_location.replace_contents_async (
                        to_save.data,
                        null,
                        false,
                        GLib.FileCreateFlags.REPLACE_DESTINATION,
                        null,
                        out etag
                    );
                    Services.RecoveryService.get_default ().purge_document_cache (doc.doc_id);
                    doc.append_console_log (@"✔ Saved $(doc.file_location.get_basename ())");
                } catch (GLib.Error e) {
                    doc.append_console_log (@"✖ Save failed: $(e.message)");
                }
            } else {
                var dialog = new Gtk.FileDialog () {
                    title = "Save Document",
                    modal = true
                };
                try {
                    var file = yield dialog.save (this, null);
                    if (file != null) {
                        doc.file_location = file;
                        string editor_content = doc.source_buffer.text;
                        var fmt = DocumentFormat.from_filename (file.get_basename ());
                        string to_save = Adapters.DocumentAdapter.save_from_editor_buffer (editor_content, fmt);
                        string etag;
                        yield file.replace_contents_async (
                            to_save.data,
                            null,
                            false,
                            GLib.FileCreateFlags.REPLACE_DESTINATION,
                            null,
                            out etag
                        );
                        Services.RecoveryService.get_default ().purge_document_cache (doc.doc_id);
                        if (tab_view.selected_page != null) {
                            tab_view.selected_page.title = file.get_basename ();
                        }
                        doc.append_console_log (@"✔ Saved $(file.get_basename ())");
                    }
                } catch (GLib.Error e) {
                    doc.append_console_log (@"✖ Save failed: $(e.message)");
                }
            }
        }

        public async bool confirm_standard_project_export_if_needed () {
            if (current_project_type == ProjectType.STANDARD) {
                var alert = new Adw.AlertDialog (
                    "System Libraries (Non-Portable)",
                    "This project relies on system libraries and may fail to run on other machines if required packages are missing."
                );
                alert.add_response ("cancel", "Cancel");
                alert.add_response ("continue", "Continue Export");
                alert.set_response_appearance ("continue", Adw.ResponseAppearance.SUGGESTED);
                alert.set_default_response ("continue");
                alert.set_close_response ("cancel");
                string response = yield alert.choose (this, null);
                return (response == "continue");
            }
            return true;
        }

        public async void export_document_dialog_async (string format) {
            var doc = get_active_document ();
            if (doc == null || doc.file_location == null) {
                if (doc != null) {
                    doc.append_console_log (@"⚠ Please save the document before exporting to $(format.up ()).");
                }
                return;
            }

            if (!(yield confirm_standard_project_export_if_needed ())) {
                return;
            }

            var dialog = new Gtk.FileDialog () {
                title = @"Export to $(format.up ())",
                modal = true
            };
            string base_name = doc.file_location.get_basename ();
            int dot_idx = base_name.last_index_of (".");
            string base_prefix = dot_idx >= 0 ? base_name.substring (0, dot_idx) : base_name;
            dialog.initial_name = @"$base_prefix.$format";

            try {
                var file = yield dialog.save (this, null);
                if (file != null) {
                    yield save_document_async ();
                    doc.append_console_log (@"▶ Exporting $(doc.file_location.get_basename ()) to $(file.get_basename ())...");
                    bool ok = yield Services.ExportService.get_default ().export_document_async (
                        doc.file_location.get_path (),
                        file.get_path (),
                        format,
                        doc.source_buffer.text
                    );
                    if (ok) {
                        doc.append_console_log (@"✔ Successfully exported to $(file.get_path ())");
                    } else {
                        doc.append_console_log (@"✖ Export to $(format.up ()) failed. Check console output.");
                    }
                }
            } catch (GLib.Error e) {
                if (doc != null) {
                    doc.append_console_log (@"✖ Export dialog failed: $(e.message)");
                }
            }
        }

        public async void export_mallorn_archive_async () {
            var doc = get_active_document ();
            if (doc == null || doc.file_location == null) {
                if (doc != null) {
                    doc.append_console_log ("⚠ Please save the document or project before exporting as .mallorn archive.");
                }
                return;
            }

            if (!(yield confirm_standard_project_export_if_needed ())) {
                return;
            }

            var project_dir = doc.file_location.get_parent ();
            string proj_name = project_dir.get_basename ();

            var dialog = new Gtk.FileDialog () {
                title = "Export Portable .mallorn Archive (1:1 RStudio)",
                modal = true
            };
            dialog.initial_name = @"$proj_name.mallorn";

            try {
                var file = yield dialog.save (this, null);
                if (file != null) {
                    yield save_document_async ();
                    doc.append_console_log (@"▶ Packaging workspace '$proj_name' into $(file.get_basename ())...");
                    try {
                        MallornManager.pack_mallorn_archive (project_dir.get_path (), file.get_path ());
                        doc.append_console_log (@"✔ Successfully packed .mallorn archive to $(file.get_path ())");
                    } catch (GLib.Error e) {
                        doc.append_console_log (@"✖ Failed to create .mallorn archive: $(e.message)");
                    }
                }
            } catch (GLib.Error e) {
                if (doc != null) {
                    doc.append_console_log (@"✖ Export .mallorn dialog failed: $(e.message)");
                }
            }
        }

        public async void export_to_rstudio_async () {
            var doc = get_active_document ();
            if (doc == null || doc.file_location == null) {
                if (doc != null) {
                    doc.append_console_log ("⚠ Please save the document or project before exporting for RStudio.");
                }
                return;
            }

            if (!(yield confirm_standard_project_export_if_needed ())) {
                return;
            }

            var project_dir = doc.file_location.get_parent ();
            string proj_name = project_dir.get_basename ();

            var dialog = new Gtk.FileDialog () {
                title = "Export Project for RStudio",
                modal = true
            };

            try {
                var folder = yield dialog.select_folder (this, null);
                if (folder != null) {
                    yield save_document_async ();
                    string target_dir = Path.build_filename (folder.get_path (), proj_name);
                    doc.append_console_log (@"▶ Exporting project '$proj_name' to RStudio workspace at $target_dir...");
                    try {
                        Services.SandboxController.export_to_rstudio (project_dir.get_path (), target_dir);
                        doc.append_console_log (@"✔ Successfully exported RStudio project to $target_dir");
                    } catch (GLib.Error e) {
                        doc.append_console_log (@"✖ Failed to export for RStudio: $(e.message)");
                    }
                }
            } catch (GLib.Error e) {
                if (doc != null) {
                    doc.append_console_log (@"✖ Export to RStudio dialog cancelled or failed: $(e.message)");
                }
            }
        }

        public async void export_to_jupyter_async () {
            var doc = get_active_document ();
            if (doc == null || doc.file_location == null) {
                if (doc != null) {
                    doc.append_console_log ("⚠ Please save the document or project before exporting for Jupyter.");
                }
                return;
            }

            if (!(yield confirm_standard_project_export_if_needed ())) {
                return;
            }

            var project_dir = doc.file_location.get_parent ();
            string proj_name = project_dir.get_basename ();

            var dialog = new Gtk.FileDialog () {
                title = "Export Project for Jupyter Notebook",
                modal = true
            };

            try {
                var folder = yield dialog.select_folder (this, null);
                if (folder != null) {
                    yield save_document_async ();
                    string target_dir = Path.build_filename (folder.get_path (), proj_name);
                    doc.append_console_log (@"▶ Exporting project '$proj_name' to Jupyter workspace at $target_dir...");
                    try {
                        Services.SandboxController.export_to_jupyter (project_dir.get_path (), target_dir);
                        doc.append_console_log (@"✔ Successfully exported Jupyter project to $target_dir");
                    } catch (GLib.Error e) {
                        doc.append_console_log (@"✖ Failed to export for Jupyter: $(e.message)");
                    }
                }
            } catch (GLib.Error e) {
                if (doc != null) {
                    doc.append_console_log (@"✖ Export to Jupyter dialog cancelled or failed: $(e.message)");
                }
            }
        }

        public void trigger_render (string target_format) {
            var doc = get_active_document ();
            if (doc != null) {
                if (target_format == "html") {
                    doc.show_live_preview ();
                }
                ExecutionEngine.run_command_async.begin (
                    { "quarto", "--version" },
                    doc
                );
                doc.append_console_log (@"▶ Preparing Quarto / RMarkdown render pipeline for format: $(target_format.up ())");
            }
        }

        private void setup_actions () {
            var action_undo = new GLib.SimpleAction ("undo", null);
            action_undo.activate.connect (() => {
                var d = get_active_document ();
                if (d != null) d.undo ();
            });
            this.add_action (action_undo);

            var action_redo = new GLib.SimpleAction ("redo", null);
            action_redo.activate.connect (() => {
                var d = get_active_document ();
                if (d != null) d.redo ();
            });
            this.add_action (action_redo);

            var action_collapse = new GLib.SimpleAction ("collapse_ribbon", null);
            action_collapse.activate.connect (() => {
                toggle_ribbon_visibility ();
            });
            this.add_action (action_collapse);

            var action_zoom_in = new GLib.SimpleAction ("zoom_in", null);
            action_zoom_in.activate.connect (() => {
                apply_zoom (current_zoom + 10);
            });
            this.add_action (action_zoom_in);

            var action_zoom_out = new GLib.SimpleAction ("zoom_out", null);
            action_zoom_out.activate.connect (() => {
                apply_zoom (current_zoom - 10);
            });
            this.add_action (action_zoom_out);

            var action_zoom_reset = new GLib.SimpleAction ("zoom_reset", null);
            action_zoom_reset.activate.connect (() => {
                apply_zoom (100);
            });
            this.add_action (action_zoom_reset);

            var action_run_chunk = new GLib.SimpleAction ("run_chunk", null);
            action_run_chunk.activate.connect (() => {
                run_active_chunk ();
            });
            this.add_action (action_run_chunk);

            var action_run_line = new GLib.SimpleAction ("run_line", null);
            action_run_line.activate.connect (() => {
                run_line_or_selection ();
            });
            this.add_action (action_run_line);
        }

        public void toggle_ribbon_visibility () {
            ribbon_scroller.visible = !ribbon_scroller.visible;
            if (btn_collapse_ribbon != null) {
                btn_collapse_ribbon.icon_name = ribbon_scroller.visible ? "pan-up-symbolic" : "pan-down-symbolic";
                btn_collapse_ribbon.tooltip_text = ribbon_scroller.visible ? "Collapse Ribbon (Ctrl+F1)" : "Expand Ribbon (Ctrl+F1)";
            }
        }

        public void apply_zoom (int percent) {
            current_zoom = percent.clamp (50, 200);
            if ((int) zoom_scale.get_value () != current_zoom) {
                zoom_scale.set_value (current_zoom);
            }
            zoom_lbl.label = @"$current_zoom%";
            var d = get_active_document ();
            if (d != null) {
                d.set_zoom (current_zoom);
            }
        }

        // =====================================================================
        // 1. HOME RIBBON (Modernized Libadwaita Linked Groups)
        // =====================================================================
        private Gtk.Widget build_home_ribbon () {
            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4);

            // Group 1: Clipboard & History
            var btn_undo = RibbonFactory.create_tool_button ("edit-undo-symbolic", null, "Undo (Ctrl+Z)", false, false, true, null, "win.undo");
            var btn_redo = RibbonFactory.create_tool_button ("edit-redo-symbolic", null, "Redo (Ctrl+Shift+Z)", false, false, true, null, "win.redo");
            box.append (RibbonFactory.create_linked_group ({ btn_undo, btn_redo }));

            var btn_cut = RibbonFactory.create_tool_button ("edit-cut-symbolic", null, "Cut");
            ((Gtk.Button) btn_cut).clicked.connect (() => {
                var d = get_active_document ();
                if (d != null) d.source_buffer.cut_clipboard (d.get_clipboard (), true);
            });
            var btn_copy = RibbonFactory.create_tool_button ("edit-copy-symbolic", null, "Copy");
            ((Gtk.Button) btn_copy).clicked.connect (() => {
                var d = get_active_document ();
                if (d != null) d.source_buffer.copy_clipboard (d.get_clipboard ());
            });
            var btn_paste = RibbonFactory.create_tool_button ("edit-paste-symbolic", null, "Paste");
            ((Gtk.Button) btn_paste).clicked.connect (() => {
                var d = get_active_document ();
                if (d != null) d.source_buffer.paste_clipboard (d.get_clipboard (), null, true);
            });
            box.append (RibbonFactory.create_linked_group ({ btn_cut, btn_copy, btn_paste }));
            box.append (RibbonFactory.create_vseparator ());

            // Group 2: Typography & Formatting
            var btn_bold = RibbonFactory.create_tool_button ("format-text-bold-symbolic", null, "Bold (**text**)");
            ((Gtk.Button) btn_bold).clicked.connect (() => {
                var d = get_active_document ();
                if (d != null) d.apply_tag_or_syntax ("bold", "**");
            });

            var btn_italic = RibbonFactory.create_tool_button ("format-text-italic-symbolic", null, "Italic (*text*)");
            ((Gtk.Button) btn_italic).clicked.connect (() => {
                var d = get_active_document ();
                if (d != null) d.apply_tag_or_syntax ("italic", "*");
            });

            var btn_under = RibbonFactory.create_tool_button ("format-text-underline-symbolic", null, "Underline (__text__)");
            ((Gtk.Button) btn_under).clicked.connect (() => {
                var d = get_active_document ();
                if (d != null) d.apply_tag_or_syntax ("underline", "__");
            });

            var btn_strike = RibbonFactory.create_tool_button ("format-text-strikethrough-symbolic", null, "Strikethrough (~~text~~)");
            ((Gtk.Button) btn_strike).clicked.connect (() => {
                var d = get_active_document ();
                if (d != null) d.apply_tag_or_syntax ("strikethrough", "~~");
            });

            var btn_code = RibbonFactory.create_tool_button ("utilities-terminal-symbolic", null, "Inline Code (`code`)");
            ((Gtk.Button) btn_code).clicked.connect (() => {
                var d = get_active_document ();
                if (d != null) d.apply_tag_or_syntax ("code", "`");
            });

            var color_pop = PopoverFactory.create_color_palette_popover ((hex) => {
                var d = get_active_document ();
                if (d != null) d.source_buffer.insert_at_cursor (@"<span style=\"color:$hex;\">text</span>", -1);
            });
            var btn_color = RibbonFactory.create_tool_button ("applications-graphics-symbolic", null, "Text Color", false, false, true, null, null, color_pop);

            box.append (RibbonFactory.create_linked_group ({ btn_bold, btn_italic, btn_under, btn_strike, btn_code, btn_color }));
            box.append (RibbonFactory.create_vseparator ());

            // Group 3: Headings & Paragraph Styles
            var btn_h1 = new Gtk.Button.with_label ("H1") { tooltip_text = "Heading 1 (#)" };
            btn_h1.add_css_class ("flat");
            btn_h1.add_css_class ("ribbon-tool-btn");
            btn_h1.clicked.connect (() => {
                var d = get_active_document ();
                if (d != null) d.apply_heading (1);
            });
            var btn_h2 = new Gtk.Button.with_label ("H2") { tooltip_text = "Heading 2 (##)" };
            btn_h2.add_css_class ("flat");
            btn_h2.add_css_class ("ribbon-tool-btn");
            btn_h2.clicked.connect (() => {
                var d = get_active_document ();
                if (d != null) d.apply_heading (2);
            });
            var btn_h3 = new Gtk.Button.with_label ("H3") { tooltip_text = "Heading 3 (###)" };
            btn_h3.add_css_class ("flat");
            btn_h3.add_css_class ("ribbon-tool-btn");
            btn_h3.clicked.connect (() => {
                var d = get_active_document ();
                if (d != null) d.apply_heading (3);
            });
            box.append (RibbonFactory.create_linked_group ({ btn_h1, btn_h2, btn_h3 }));

            var btn_bullet = RibbonFactory.create_tool_button ("view-list-bullet-symbolic", null, "Bullet List (- )");
            ((Gtk.Button) btn_bullet).clicked.connect (() => {
                var d = get_active_document ();
                if (d != null) d.insert_list_item ("- ");
            });
            var btn_number = RibbonFactory.create_tool_button ("view-list-ordered-symbolic", null, "Numbered List (1. )");
            ((Gtk.Button) btn_number).clicked.connect (() => {
                var d = get_active_document ();
                if (d != null) d.insert_list_item ("1. ");
            });
            var btn_quote = RibbonFactory.create_tool_button ("format-text-direction-ltr-symbolic", null, "Blockquote (> )");
            ((Gtk.Button) btn_quote).clicked.connect (() => {
                var d = get_active_document ();
                if (d != null) d.insert_list_item ("> ");
            });
            box.append (RibbonFactory.create_linked_group ({ btn_bullet, btn_number, btn_quote }));
            box.append (RibbonFactory.create_vseparator ());

            // Group 4: Assistant & Settings
            var btn_ai_home = RibbonFactory.create_tool_button ("system-run-symbolic", "AI Assistant", "Invoke AI Assistant");
            ((Gtk.Button) btn_ai_home).clicked.connect (() => {
                trigger_ai_assistant ();
            });
            box.append (btn_ai_home);

            box.append (RibbonFactory.create_tool_button ("emblem-system-symbolic", "Preferences", "Open Preferences (Ctrl+,)", false, false, true, null, "app.preferences"));

            return box;
        }

        // =====================================================================
        // 2. INSERT RIBBON (Modernized High-Density Layout)
        // =====================================================================
        private Gtk.Widget build_insert_ribbon () {
            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4);

            // Group 1: Structure & Chunks
            var table_popover = SmartRibbonHelpers.create_table_builder_popover ((rows, cols) => {
                var d = get_active_document ();
                if (d != null) d.insert_markdown_table (rows, cols);
            });
            var btn_table = RibbonFactory.create_tool_button ("view-grid-symbolic", "Table", "Insert Markdown Table", false, false, true, null, null, table_popover);

            var code_popover = SmartRibbonHelpers.create_code_chunk_popover ((snippet) => {
                var d = get_active_document ();
                if (d != null) d.source_buffer.insert_at_cursor (snippet, -1);
            });
            var btn_chunk = RibbonFactory.create_tool_button ("utilities-terminal-symbolic", "Code Chunk", "Insert Code Chunk", false, false, true, null, null, code_popover);

            var btn_math = RibbonFactory.create_tool_button ("insert-text-symbolic", "LaTeX Math", "Insert LaTeX Math Block ($$...$$)");
            ((Gtk.Button) btn_math).clicked.connect (() => {
                var d = get_active_document ();
                if (d != null) d.source_buffer.insert_at_cursor ("\n$$\n\\frac{a}{b}\n$$\n", -1);
            });

            box.append (RibbonFactory.create_linked_group ({ btn_table, btn_chunk, btn_math }));
            box.append (RibbonFactory.create_vseparator ());

            // Group 2: Citations, References & Footnotes
            var cite_popover = SmartRibbonHelpers.create_citation_popover ((cite) => {
                var d = get_active_document ();
                if (d != null) d.source_buffer.insert_at_cursor (cite, -1);
            });
            var btn_cite = RibbonFactory.create_tool_button ("book-open-symbolic", "Citation", "Insert Citation (@cite)", false, false, true, null, null, cite_popover);

            var btn_xref = RibbonFactory.create_tool_button ("emblem-symbolic-link", "Cross-ref", "Insert Cross-Reference (@fig-)");
            ((Gtk.Button) btn_xref).clicked.connect (() => {
                var d = get_active_document ();
                if (d != null) d.source_buffer.insert_at_cursor ("@fig-", -1);
            });

            var btn_fn = RibbonFactory.create_tool_button ("format-text-superscript-symbolic", "Footnote", "Insert Footnote (^[])");
            ((Gtk.Button) btn_fn).clicked.connect (() => {
                var d = get_active_document ();
                if (d != null) d.source_buffer.insert_at_cursor ("^[Footnote text]", -1);
            });

            box.append (RibbonFactory.create_linked_group ({ btn_cite, btn_xref, btn_fn }));
            box.append (RibbonFactory.create_vseparator ());

            // Group 3: Media & Web Elements
            var btn_img = RibbonFactory.create_tool_button ("insert-image-symbolic", "Image", "Insert Image");
            ((Gtk.Button) btn_img).clicked.connect (() => {
                var d = get_active_document ();
                if (d != null) d.source_buffer.insert_at_cursor ("![Image caption](image.png)\n", -1);
            });

            var btn_link = RibbonFactory.create_tool_button ("insert-link-symbolic", "Hyperlink", "Insert Hyperlink");
            ((Gtk.Button) btn_link).clicked.connect (() => {
                var d = get_active_document ();
                if (d != null) d.source_buffer.insert_at_cursor ("[Link text](https://example.com)", -1);
            });

            var btn_break = RibbonFactory.create_tool_button ("view-more-horizontal-symbolic", "Divider", "Insert Horizontal Rule (---)");
            ((Gtk.Button) btn_break).clicked.connect (() => {
                var d = get_active_document ();
                if (d != null) d.source_buffer.insert_at_cursor ("\n---\n", -1);
            });

            box.append (RibbonFactory.create_linked_group ({ btn_img, btn_link, btn_break }));
            box.append (RibbonFactory.create_vseparator ());

            // Group 4: Symbols, Diagrams & Visuals
            var sym_popover = SmartRibbonHelpers.create_symbols_popover ((sym) => {
                var d = get_active_document ();
                if (d != null) d.source_buffer.insert_at_cursor (sym, -1);
            });
            var btn_sym = RibbonFactory.create_tool_button ("character-map-symbolic", "Symbols", "Insert Math / Special Symbol", false, false, true, null, null, sym_popover);

            var emoji_popover = SmartRibbonHelpers.create_emoji_popover ((em) => {
                var d = get_active_document ();
                if (d != null) d.source_buffer.insert_at_cursor (em, -1);
            });
            var btn_emoji = RibbonFactory.create_tool_button ("face-smile-symbolic", "Emoji", "Insert Emoji", false, false, true, null, null, emoji_popover);

            var btn_mermaid = RibbonFactory.create_tool_button ("view-list-symbolic", "Mermaid", "Insert Mermaid Diagram");
            ((Gtk.Button) btn_mermaid).clicked.connect (() => {
                var d = get_active_document ();
                if (d != null) d.source_buffer.insert_at_cursor ("\n```{mermaid}\nflowchart TD\n  A[Start] --> B[Process]\n  B --> C[Result]\n```\n", -1);
            });

            var btn_plot = RibbonFactory.create_tool_button ("x-office-presentation-symbolic", "ggplot", "Insert ggplot2 snippet");
            ((Gtk.Button) btn_plot).clicked.connect (() => {
                var d = get_active_document ();
                if (d != null) d.source_buffer.insert_at_cursor ("\n```{r}\n#| label: fig-plot\n#| fig-cap: 'Scatter Plot'\nlibrary(ggplot2)\nggplot(mtcars, aes(x = wt, y = mpg)) + geom_point()\n```\n", -1);
            });

            box.append (RibbonFactory.create_linked_group ({ btn_sym, btn_emoji, btn_mermaid, btn_plot }));

            return box;
        }

        // =====================================================================
        // 3. COMPUTATION RIBBON (Polyglot R, Python & Quarto)
        // =====================================================================
        private Gtk.Widget build_computation_ribbon () {
            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4);

            // Group 1: Insert Code Chunks
            btn_insert_r = RibbonFactory.create_tool_button ("utilities-terminal-symbolic", "R Chunk", "Insert R Code Chunk ({r})");
            ((Gtk.Button) btn_insert_r).clicked.connect (() => {
                var d = get_active_document ();
                if (d != null) d.insert_code_chunk ("r", "echo: true");
            });

            btn_insert_py = RibbonFactory.create_tool_button ("utilities-terminal-symbolic", "Python Chunk", "Insert Python Code Chunk ({python})");
            ((Gtk.Button) btn_insert_py).clicked.connect (() => {
                var d = get_active_document ();
                if (d != null) d.insert_code_chunk ("python", "echo: true");
            });

            box.append (RibbonFactory.create_linked_group ({ btn_insert_r, btn_insert_py }));
            box.append (RibbonFactory.create_vseparator ());

            // Group 2: Chunk Execution Controls
            btn_run_chunk = RibbonFactory.create_tool_button ("media-playback-start-symbolic", "Run Chunk", "Run Active Chunk (Ctrl+Shift+Enter)");
            ((Gtk.Button) btn_run_chunk).clicked.connect (() => {
                run_active_chunk ();
            });

            btn_run_all = RibbonFactory.create_tool_button ("media-seek-forward-symbolic", "Run All", "Run All Chunks in Document");
            ((Gtk.Button) btn_run_all).clicked.connect (() => {
                run_all_chunks ();
            });

            btn_run_above = RibbonFactory.create_tool_button ("media-skip-backward-symbolic", "Run Above", "Run All Chunks Above");
            ((Gtk.Button) btn_run_above).clicked.connect (() => {
                run_all_chunks ();
            });

            btn_run_below = RibbonFactory.create_tool_button ("media-skip-forward-symbolic", "Run Below", "Run Active and Below Chunks");
            ((Gtk.Button) btn_run_below).clicked.connect (() => {
                run_active_chunk ();
            });

            box.append (RibbonFactory.create_linked_group ({ btn_run_chunk, btn_run_all, btn_run_above, btn_run_below }));
            box.append (RibbonFactory.create_vseparator ());

            // Group 3: Script Execution Controls
            btn_run_line = RibbonFactory.create_tool_button ("media-playback-start-symbolic", "Run Line", "Run Current Line or Selection (Ctrl+Enter)");
            ((Gtk.Button) btn_run_line).clicked.connect (() => {
                run_line_or_selection ();
            });

            btn_source_file = RibbonFactory.create_tool_button ("document-send-symbolic", "Source", "Source Entire File in Kernel");
            ((Gtk.Button) btn_source_file).clicked.connect (() => {
                source_active_file ();
            });

            btn_interrupt = RibbonFactory.create_tool_button ("process-stop-symbolic", "Interrupt", "Interrupt Active Execution (SIGINT)");
            ((Gtk.Button) btn_interrupt).clicked.connect (() => {
                interrupt_active_execution ();
            });

            box.append (RibbonFactory.create_linked_group ({ btn_run_line, btn_source_file, btn_interrupt }));
            box.append (RibbonFactory.create_vseparator ());

            // Group 4: Package Manager & Environment Sandboxing
            btn_restart_kernel = RibbonFactory.create_tool_button ("system-run-symbolic", "Restart Kernel", "Restart Active Kernel Sessions");
            ((Gtk.Button) btn_restart_kernel).clicked.connect (() => {
                restart_active_kernel ();
            });

            btn_package_installer = RibbonFactory.create_tool_button ("software-properties-symbolic", "Packages", "Open Package Installer (Ctrl+Shift+P)");
            ((Gtk.Button) btn_package_installer).clicked.connect (() => {
                show_package_installer_dialog ();
            });

            btn_snapshot_env = RibbonFactory.create_tool_button ("security-high-symbolic", "Snapshot", "Snapshot Environment Lockfile (renv/venv)");
            ((Gtk.Button) btn_snapshot_env).clicked.connect (() => {
                snapshot_current_environment ();
            });

            btn_restore_env = RibbonFactory.create_tool_button ("view-refresh-symbolic", "Restore", "Restore Environment from Lockfile");
            ((Gtk.Button) btn_restore_env).clicked.connect (() => {
                restore_current_environment ();
            });

            box.append (RibbonFactory.create_linked_group ({ btn_restart_kernel, btn_package_installer, btn_snapshot_env, btn_restore_env }));
            box.append (RibbonFactory.create_vseparator ());

            var btn_comp_ai = RibbonFactory.create_tool_button ("system-run-symbolic", "AI Assistant", "Invoke AI Coding Assistant");
            ((Gtk.Button) btn_comp_ai).clicked.connect (() => {
                trigger_ai_assistant ();
            });
            box.append (btn_comp_ai);

            return box;
        }

        // =====================================================================
        // 4. PUBLISH RIBBON (Export Pipeline, WebKit Preview & Artifacts)
        // =====================================================================
        private Gtk.Widget build_publish_ribbon () {
            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4);

            // Group 1: Primary Document Render & Export
            btn_render_html = RibbonFactory.create_tool_button ("applications-internet-symbolic", "HTML", "Render Document to HTML", false, false, true, null, "app.export_html");
            btn_render_pdf = RibbonFactory.create_tool_button ("document-send-symbolic", "PDF", "Render Document to PDF", false, false, true, null, "app.export_pdf");
            btn_export_odt = RibbonFactory.create_tool_button ("x-office-document-symbolic", "ODT", "Export to OpenDocument Text (.odt)", false, false, true, null, "app.export_odt");
            btn_export_odp = RibbonFactory.create_tool_button ("x-office-presentation-symbolic", "ODP", "Export to OpenDocument Presentation (.odp)", false, false, true, null, "app.export_odp");

            box.append (RibbonFactory.create_linked_group ({ btn_render_html, btn_render_pdf, btn_export_odt, btn_export_odp }));
            box.append (RibbonFactory.create_vseparator ());

            // Group 2: Interoperability & Reproducibility Exports
            btn_export_mallorn = RibbonFactory.create_tool_button ("package-x-generic-symbolic", ".mallorn", "Export Portable Reproducible Archive", false, false, true, null, "app.export_mallorn");
            btn_export_rstudio = RibbonFactory.create_tool_button ("utilities-terminal-symbolic", "RStudio", "Export Project for RStudio", false, false, true, null, "app.export_rstudio");
            btn_export_jupyter = RibbonFactory.create_tool_button ("applications-science-symbolic", "Jupyter", "Export Project for Jupyter Notebook", false, false, true, null, "app.export_jupyter");

            box.append (RibbonFactory.create_linked_group ({ btn_export_mallorn, btn_export_rstudio, btn_export_jupyter }));
            box.append (RibbonFactory.create_vseparator ());

            // Group 3: Live Preview & Diagnostics
            btn_live_preview = RibbonFactory.create_tool_button ("view-refresh-symbolic", "Live Preview", "Render and Open Live WebKit Preview");
            ((Gtk.Button) btn_live_preview).clicked.connect (() => {
                var d = get_active_document ();
                if (d != null) d.show_live_preview ();
            });
            box.append (btn_live_preview);

            var btn_preview = (Gtk.ToggleButton) RibbonFactory.create_tool_button ("view-dual-symbolic", "Console", "Toggle Output Console Panel", true, true, true);
            btn_preview.toggled.connect (() => {
                var d = get_active_document ();
                if (d != null) d.console_revealer.reveal_child = btn_preview.active;
            });
            box.append (btn_preview);
            box.append (RibbonFactory.create_vseparator ());

            var btn_pub_ai = RibbonFactory.create_tool_button ("system-run-symbolic", "AI Assistant", "Invoke AI Publishing Assistant");
            ((Gtk.Button) btn_pub_ai).clicked.connect (() => {
                trigger_ai_assistant ();
            });
            box.append (btn_pub_ai);

            return box;
        }

        /**
         * Pillar 2: Context-Aware Ribbon State Machine
         * Dynamically adapts visible and sensitive states based on active Project Type and Document Format
         */
        public void update_ribbon_state_machine (DocumentFormat fmt, ProjectType ptype) {
            bool is_md = (fmt == DocumentFormat.MD);
            bool is_html = (fmt == DocumentFormat.HTML);
            bool is_script = (fmt == DocumentFormat.RSCRIPT || fmt == DocumentFormat.PYSCRIPT);
            bool is_notebook = (fmt == DocumentFormat.RMD || fmt == DocumentFormat.QMD || fmt == DocumentFormat.IPYNB);
            bool is_sandboxed = (ptype == ProjectType.SANDBOXED);

            // 1. Insert Chunks
            if (btn_insert_r != null) {
                btn_insert_r.visible = is_notebook;
                btn_insert_r.sensitive = is_notebook;
            }
            if (btn_insert_py != null) {
                btn_insert_py.visible = is_notebook;
                btn_insert_py.sensitive = is_notebook;
            }

            // 2. Chunk Execution Controls
            if (btn_run_chunk != null) {
                btn_run_chunk.visible = !is_html;
                btn_run_chunk.sensitive = is_notebook;
            }
            if (btn_run_all != null) {
                btn_run_all.visible = !is_html;
                btn_run_all.sensitive = is_notebook;
            }
            if (btn_run_above != null) {
                btn_run_above.visible = is_notebook;
                btn_run_above.sensitive = is_notebook;
            }
            if (btn_run_below != null) {
                btn_run_below.visible = is_notebook;
                btn_run_below.sensitive = is_notebook;
            }

            // 3. Script Execution Controls
            if (btn_run_line != null) {
                btn_run_line.visible = is_script || is_notebook;
                btn_run_line.sensitive = is_script || is_notebook;
            }
            if (btn_source_file != null) {
                btn_source_file.visible = is_script || is_notebook;
                btn_source_file.sensitive = is_script || is_notebook;
            }
            if (btn_interrupt != null) {
                btn_interrupt.visible = is_script || is_notebook;
                btn_interrupt.sensitive = is_script || is_notebook;
            }

            // 4. Kernel / Persistent Sessions
            if (btn_restart_kernel != null) {
                btn_restart_kernel.visible = !is_md && !is_html;
                btn_restart_kernel.sensitive = is_script || is_notebook;
            }

            // 5. Package Installer
            if (btn_package_installer != null) {
                btn_package_installer.visible = !is_md && !is_html;
                btn_package_installer.sensitive = is_script || is_notebook;
            }

            // 6. Snapshot & Restore Environment (Pillar 2 rules)
            if (btn_snapshot_env != null) {
                btn_snapshot_env.visible = is_notebook || (is_script && is_sandboxed);
                if (is_sandboxed) {
                    btn_snapshot_env.sensitive = true;
                    btn_snapshot_env.tooltip_text = "Lock environment package versions (renv::snapshot / pip freeze)";
                } else {
                    btn_snapshot_env.sensitive = false;
                    btn_snapshot_env.tooltip_text = "Only available in Sandboxed Projects";
                }
            }
            if (btn_restore_env != null) {
                btn_restore_env.visible = is_notebook || (is_script && is_sandboxed);
                if (is_sandboxed) {
                    btn_restore_env.sensitive = true;
                    btn_restore_env.tooltip_text = "Restore exact package versions from lockfile (renv::restore / pip install -r)";
                } else {
                    btn_restore_env.sensitive = false;
                    btn_restore_env.tooltip_text = "Only available in Sandboxed Projects";
                }
            }

            // 7. Knit / Render / Export
            if (btn_render_html != null) {
                btn_render_html.visible = true;
                btn_render_html.sensitive = !is_script;
            }
            if (btn_render_pdf != null) {
                btn_render_pdf.visible = !is_html;
                btn_render_pdf.sensitive = !is_script;
            }
            if (btn_export_odt != null) {
                btn_export_odt.visible = !is_html;
                btn_export_odt.sensitive = is_md || is_notebook;
            }
            if (btn_export_odp != null) {
                btn_export_odp.visible = !is_html;
                btn_export_odp.sensitive = is_md || is_notebook;
            }
            if (btn_export_mallorn != null) {
                btn_export_mallorn.visible = is_notebook;
                btn_export_mallorn.sensitive = is_notebook;
            }
            if (btn_export_rstudio != null) {
                btn_export_rstudio.visible = is_notebook;
                btn_export_rstudio.sensitive = is_notebook;
            }
            if (btn_export_jupyter != null) {
                btn_export_jupyter.visible = is_notebook;
                btn_export_jupyter.sensitive = is_notebook;
            }

            // 8. Live preview
            if (btn_live_preview != null) {
                btn_live_preview.visible = true;
                btn_live_preview.sensitive = is_md || is_html || is_notebook;
            }
        }

        // Action Handlers for Pillars 2, 3, 4
        public void show_package_installer_dialog () {
            var doc = get_active_document ();
            var fmt = DocumentFormat.QMD;
            if (doc != null) {
                fmt = doc.get_document_format ();
            }
            var eco = (fmt == DocumentFormat.PYSCRIPT || fmt == DocumentFormat.IPYNB)
                ? UI.PackageEcosystem.PYTHON_PYPI
                : UI.PackageEcosystem.R_CRAN;
            string pdir = current_project_dir != "" ? current_project_dir : Services.PersistentSessionManager.get_default ().current_working_dir;
            if (pdir == "") pdir = GLib.Environment.get_current_dir ();
            bool is_sandboxed = (current_project_type == ProjectType.SANDBOXED);

            var ctx = new UI.ProjectContext (pdir, is_sandboxed, eco);
            var modal = new UI.PackageInstallerModal (ctx, pkg_index_cache);

            modal.execute_r_command.connect ((r_code) => {
                var d = get_active_document ();
                if (d != null) {
                    d.panel_registry.run_code_snippet_in_console ("r", r_code);
                }
            });

            modal.execute_python_command.connect ((py_bin, args, working_dir, sandboxed) => {
                run_python_pip_and_snapshot.begin (py_bin, args, working_dir, sandboxed);
            });

            modal.present (this);
        }

        public async void run_python_pip_and_snapshot (string py_bin, string[] args, string working_dir, bool sandboxed) {
            var doc = get_active_document ();
            if (doc != null) {
                string cmd_disp = string.joinv (" ", args);
                doc.append_console_log (@"▶ [Python/pip] Executing: $cmd_disp");
            }

            try {
                var launcher = new GLib.SubprocessLauncher (
                    GLib.SubprocessFlags.STDOUT_PIPE | GLib.SubprocessFlags.STDERR_MERGE
                );
                if (working_dir != "" && GLib.FileUtils.test (working_dir, GLib.FileTest.IS_DIR)) {
                    launcher.set_cwd (working_dir);
                }

                var proc = launcher.spawnv (args);
                var dis = new GLib.DataInputStream (proc.get_stdout_pipe ());
                string? line = null;
                while ((line = yield dis.read_line_async (GLib.Priority.DEFAULT, null)) != null) {
                    if (doc != null && line.strip ().length > 0) {
                        doc.append_console_log (line);
                    }
                }
                yield proc.wait_async (null);

                if (doc != null) {
                    doc.append_console_log ("✔ Package installation finished.");
                }

                if (sandboxed && working_dir != "") {
                    Services.SandboxController.snapshot_environment (working_dir);
                    if (doc != null) {
                        doc.append_console_log ("✔ Sandboxed project requirements.txt updated.");
                    }
                }
            } catch (GLib.Error e) {
                if (doc != null) {
                    doc.append_console_log (@"✖ Package installer error: $(e.message)");
                }
            }
        }

        public void snapshot_current_environment () {
            if (current_project_type != ProjectType.SANDBOXED) {
                var doc = get_active_document ();
                if (doc != null) {
                    doc.append_console_log ("⚠ Environment snapshot is only available in Sandboxed Projects.");
                }
                return;
            }
            string pdir = current_project_dir != "" ? current_project_dir : GLib.Environment.get_current_dir ();
            var doc = get_active_document ();
            try {
                Services.SandboxController.snapshot_environment (pdir);
                if (doc != null) {
                    doc.append_console_log (@"✔ Environment lockfile snapshotted in $pdir");
                }
            } catch (GLib.Error e) {
                if (doc != null) {
                    doc.append_console_log (@"✖ Snapshot error: $(e.message)");
                }
            }
        }

        public void restore_current_environment () {
            if (current_project_type != ProjectType.SANDBOXED) {
                var doc = get_active_document ();
                if (doc != null) {
                    doc.append_console_log ("⚠ Environment restore is only available in Sandboxed Projects.");
                }
                return;
            }
            string pdir = current_project_dir != "" ? current_project_dir : GLib.Environment.get_current_dir ();
            var doc = get_active_document ();
            try {
                Services.SandboxController.restore_environment (pdir);
                if (doc != null) {
                    doc.append_console_log (@"✔ Restoring isolated packages in $pdir (renv / venv)...");
                }
            } catch (GLib.Error e) {
                if (doc != null) {
                    doc.append_console_log (@"✖ Restore error: $(e.message)");
                }
            }
        }

        public void restart_active_kernel () {
            Services.PersistentSessionManager.get_default ().restart_all_sessions ();
            var doc = get_active_document ();
            if (doc != null) {
                doc.append_console_log ("✔ Active persistent R and Python sessions restarted.");
            }
        }

        public void interrupt_active_execution () {
            Services.PersistentSessionManager.get_default ().interrupt_active_execution ();
            var doc = get_active_document ();
            if (doc != null) {
                doc.append_console_log ("⏹ Execution interrupted (SIGINT sent).");
            }
        }

        public void run_line_or_selection () {
            var doc = get_active_document ();
            if (doc != null) {
                doc.panel_registry.execute_current_line_or_selection ();
            }
        }

        public void run_active_chunk () {
            var doc = get_active_document ();
            if (doc != null) {
                doc.panel_registry.execute_active_cell ();
            }
        }

        public void run_all_chunks () {
            var doc = get_active_document ();
            if (doc != null) {
                doc.panel_registry.execute_all_cells ();
            }
        }

        public void source_active_file () {
            var doc = get_active_document ();
            if (doc == null) return;
            string code = doc.source_buffer.text.strip ();
            if (code.length == 0) return;
            var fmt = doc.get_document_format ();
            string engine = (fmt == DocumentFormat.RSCRIPT || fmt == DocumentFormat.RMD) ? "r" : "python";
            doc.panel_registry.run_code_snippet_in_console (engine, code);
        }

        // =====================================================================
        // 5. VIEW RIBBON (Layouts, Split Modes, Zoom & Display Options)
        // =====================================================================
        private Gtk.Widget build_view_ribbon () {
            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4);

            // Group 1: Workspace Mode Toggle
            var btn_mode_apostrophe = (Gtk.ToggleButton) RibbonFactory.create_tool_button ("edit-find-symbolic", "Focus Mode", "Apostrophe Distraction-Free Layout", true, true, true);
            var btn_mode_rstudio = (Gtk.ToggleButton) RibbonFactory.create_tool_button ("view-grid-symbolic", "RStudio 4-Quad", "RStudio-Style 4-Quadrant Workbench Layout", true, false, true);
            btn_mode_rstudio.set_group (btn_mode_apostrophe);

            btn_mode_apostrophe.toggled.connect (() => {
                if (btn_mode_apostrophe.active) {
                    Services.WorkspaceStateManager.get_default ().set_layout_mode (Services.LayoutMode.APOSTROPHE, true);
                }
            });
            btn_mode_rstudio.toggled.connect (() => {
                if (btn_mode_rstudio.active) {
                    Services.WorkspaceStateManager.get_default ().set_layout_mode (Services.LayoutMode.RSTUDIO, true);
                }
            });

            box.append (RibbonFactory.create_linked_group ({ btn_mode_apostrophe, btn_mode_rstudio }));
            box.append (RibbonFactory.create_vseparator ());

            // Group 2: Split Mode Switcher
            var btn_split_v = (Gtk.ToggleButton) RibbonFactory.create_tool_button ("view-column-symbolic", "Vertical", "Side-by-Side Split", true, true, true);
            var btn_split_h = (Gtk.ToggleButton) RibbonFactory.create_tool_button ("view-paged-symbolic", "Horizontal", "Top-and-Bottom Split", true, false, true);
            var btn_edit_only = (Gtk.ToggleButton) RibbonFactory.create_tool_button ("x-office-document-symbolic", "Editor Only", "Editor-Only Mode", true, false, true);
            var btn_prev_only = (Gtk.ToggleButton) RibbonFactory.create_tool_button ("applications-internet-symbolic", "Preview Only", "Preview-Only Mode", true, false, true);

            btn_split_h.set_group (btn_split_v);
            btn_edit_only.set_group (btn_split_v);
            btn_prev_only.set_group (btn_split_v);

            btn_split_v.toggled.connect (() => {
                if (btn_split_v.active) Services.WorkspaceStateManager.get_default ().set_split_mode (Services.SplitMode.VERTICAL_SPLIT);
            });
            btn_split_h.toggled.connect (() => {
                if (btn_split_h.active) Services.WorkspaceStateManager.get_default ().set_split_mode (Services.SplitMode.HORIZONTAL_SPLIT);
            });
            btn_edit_only.toggled.connect (() => {
                if (btn_edit_only.active) Services.WorkspaceStateManager.get_default ().set_split_mode (Services.SplitMode.EDITOR_ONLY);
            });
            btn_prev_only.toggled.connect (() => {
                if (btn_prev_only.active) Services.WorkspaceStateManager.get_default ().set_split_mode (Services.SplitMode.PREVIEW_ONLY);
            });

            box.append (RibbonFactory.create_linked_group ({ btn_split_v, btn_split_h, btn_edit_only, btn_prev_only }));
            box.append (RibbonFactory.create_vseparator ());

            // Group 3: Zoom Controls
            var btn_zoom_out = RibbonFactory.create_tool_button ("zoom-out-symbolic", null, "Zoom Out (Ctrl+-)", false, false, true, null, "win.zoom_out");
            var btn_zoom_100 = RibbonFactory.create_tool_button ("zoom-original-symbolic", "100%", "Zoom 100% (Ctrl+0)", false, false, true, null, "win.zoom_reset");
            var btn_zoom_in = RibbonFactory.create_tool_button ("zoom-in-symbolic", null, "Zoom In (Ctrl++)", false, false, true, null, "win.zoom_in");

            box.append (RibbonFactory.create_linked_group ({ btn_zoom_out, btn_zoom_100, btn_zoom_in }));
            box.append (RibbonFactory.create_vseparator ());

            // Group 4: Editor Display Options
            var chk_grid = new Gtk.Grid () { row_spacing = 2, column_spacing = 8, valign = Gtk.Align.CENTER };
            var chk_line_no = new Gtk.CheckButton.with_label ("Line Numbers") { active = true };
            chk_line_no.toggled.connect (() => {
                var d = get_active_document ();
                if (d != null) d.source_view.show_line_numbers = chk_line_no.active;
            });
            var chk_syntax = new Gtk.CheckButton.with_label ("Highlight") { active = true };
            chk_syntax.toggled.connect (() => {
                var d = get_active_document ();
                if (d != null) d.source_buffer.highlight_syntax = chk_syntax.active;
            });
            var chk_wrap = new Gtk.CheckButton.with_label ("Word Wrap") { active = true };
            chk_wrap.toggled.connect (() => {
                var d = get_active_document ();
                if (d != null) d.source_view.wrap_mode = chk_wrap.active ? Gtk.WrapMode.WORD_CHAR : Gtk.WrapMode.NONE;
            });
            var chk_console = new Gtk.CheckButton.with_label ("Console");
            chk_console.toggled.connect (() => {
                var d = get_active_document ();
                if (d != null) d.console_revealer.reveal_child = chk_console.active;
            });

            chk_grid.attach (chk_line_no, 0, 0, 1, 1);
            chk_grid.attach (chk_syntax, 0, 1, 1, 1);
            chk_grid.attach (chk_wrap, 1, 0, 1, 1);
            chk_grid.attach (chk_console, 1, 1, 1, 1);
            box.append (chk_grid);

            return box;
        }
    }
}
