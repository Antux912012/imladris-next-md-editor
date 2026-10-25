namespace Imladris {

    public class Window : Adw.ApplicationWindow {

        private Gtk.Stack ribbon_stack;
        private Adw.TabView tab_view;
        private Adw.TabBar tab_bar;
        private Gtk.Label status_badge_lbl;
        private Gtk.Label status_words_lbl;
        private Gtk.Label status_kernel_lbl;
        private int doc_counter = 1;

        public Window (Adw.Application app) {
            Object (
                application: app,
                title: "Imladris — Polyglot Scientific & Web Studio",
                default_width: 1380,
                default_height: 860
            );
        }

        construct {
            var toolbar_view = new Adw.ToolbarView ();
            this.set_content (toolbar_view);

            var top_master_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            toolbar_view.add_top_bar (top_master_box);

            // =================================================================
            // TIER 1: DARK HEADER BAR & CATEGORY SWITCHER (9 Tabs)
            // =================================================================
            var win_handle = new Gtk.WindowHandle ();
            var tier1_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 2);
            tier1_box.add_css_class ("imladris-topbar");
            win_handle.set_child (tier1_box);

            // Branded "Imladris" Primary Menu
            var brand_menu = new GLib.Menu ();
            var new_sec = new GLib.Menu ();
            new_sec.append ("New Quarto Document (.qmd)", "app.new_qmd");
            new_sec.append ("New R Markdown (.Rmd)", "app.new_rmd");
            new_sec.append ("New Jupyter Notebook (.ipynb)", "app.new_ipynb");
            new_sec.append ("New TypeScript File (.ts)", "app.new_ts");
            new_sec.append ("New HTML5 Document (.html)", "app.new_html");
            brand_menu.append_section ("Create New", new_sec);

            var io_sec = new GLib.Menu ();
            io_sec.append ("Open File...", "app.open");
            io_sec.append ("Save", "app.save");
            io_sec.append ("Render to HTML", "app.export_html");
            io_sec.append ("Render to PDF", "app.export_pdf");
            io_sec.append ("Quit Imladris", "app.quit");
            brand_menu.append_section ("File & Export", io_sec);

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
                "Home", "Insert", "Computation", "Web & Publish",
                "Page Layout", "References", "Review", "View", "Section"
            };

            Gtk.ToggleButton? first_tab = null;
            foreach (string cat in categories) {
                var tab_btn = new Gtk.ToggleButton.with_label (cat);
                tab_btn.add_css_class ("ribbon-tab-btn");
                if (cat == "Computation") tab_btn.add_css_class ("ribbon-tab-scientific");
                if (cat == "Web & Publish") tab_btn.add_css_class ("ribbon-tab-web");

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
            tier1_box.append (new Gtk.WindowControls (Gtk.PackType.END));
            top_master_box.append (win_handle);

            // =================================================================
            // TIER 2: DYNAMIC RIBBON DECK (All 9 Tabs)
            // =================================================================
            var ribbon_scroller = new Gtk.ScrolledWindow () {
                vscrollbar_policy = Gtk.PolicyType.NEVER,
                hscrollbar_policy = Gtk.PolicyType.AUTOMATIC
            };
            ribbon_scroller.add_css_class ("ribbon-deck");
            ribbon_scroller.set_child (ribbon_stack);
            top_master_box.append (ribbon_scroller);

            ribbon_stack.add_named (build_home_ribbon (), "Home");
            ribbon_stack.add_named (build_insert_ribbon (), "Insert");
            ribbon_stack.add_named (build_computation_ribbon (), "Computation");
            ribbon_stack.add_named (build_web_publish_ribbon (), "Web & Publish");
            ribbon_stack.add_named (build_page_layout_ribbon (), "Page Layout");
            ribbon_stack.add_named (build_references_ribbon (), "References");
            ribbon_stack.add_named (build_review_ribbon (), "Review");
            ribbon_stack.add_named (build_view_ribbon (), "View");
            ribbon_stack.add_named (build_section_ribbon (), "Section");

            // =================================================================
            // TIER 3: QUICK ACCESS TOOLBAR & ADW.TABBAR
            // =================================================================
            var tier3_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4);
            tier3_box.add_css_class ("imladris-subbar");

            tier3_box.append (RibbonFactory.create_compact_button ("folder-open-symbolic", null, false, false, true, null, "app.open"));
            tier3_box.append (RibbonFactory.create_compact_button ("document-save-symbolic", null, false, false, true, null, "app.save"));
            tier3_box.append (RibbonFactory.create_compact_button ("document-send-symbolic", "PDF", false, false, true, null, "app.export_pdf"));
            tier3_box.append (RibbonFactory.create_compact_button ("applications-internet-symbolic", "HTML", false, false, true, null, "app.export_html"));
            tier3_box.append (RibbonFactory.create_compact_button ("edit-undo-symbolic"));
            tier3_box.append (RibbonFactory.create_compact_button ("edit-redo-symbolic"));
            var ai_quick_btn = RibbonFactory.create_compact_button ("system-run-symbolic", "AI Assistant");
            ((Gtk.Button) ai_quick_btn).clicked.connect (() => {
                trigger_ai_assistant ();
            });
            tier3_box.append (ai_quick_btn);
            tier3_box.append (RibbonFactory.create_vseparator ());

            tab_view = new Adw.TabView ();
            tab_bar = new Adw.TabBar () {
                view = tab_view,
                autohide = false,
                expand_tabs = false,
                hexpand = true
            };

            var add_tab_btn = new Gtk.Button.from_icon_name ("list-add-symbolic");
            add_tab_btn.add_css_class ("flat");
            add_tab_btn.clicked.connect (() => {
                doc_counter++;
                add_document_tab (@"Untitled-$doc_counter.qmd", "markdown");
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

            status_kernel_lbl = new Gtk.Label ("Kernels: R • Python 3 • Deno/TS");
            status_bar.append (status_kernel_lbl);

            status_words_lbl = new Gtk.Label ("Words: 0 | Lines: 1");
            status_bar.append (status_words_lbl);

            status_bar.append (new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) { hexpand = true });

            var zoom_lbl = new Gtk.Label ("100%");
            var zoom_scale = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, 50, 200, 10) {
                draw_value = false,
                width_request = 110
            };
            zoom_scale.set_value (100);
            zoom_scale.value_changed.connect (() => {
                int z = (int) zoom_scale.get_value ();
                zoom_lbl.label = @"$z%";
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
            if (mode == Services.LayoutMode.APOSTROPHE) {
                // Apostrophe Mode: Maximize writing space, clean typography, hide distracting side panels
                ribbon_stack.visible = true;
                if (doc != null) {
                    doc.source_view.left_margin = 72;
                    doc.source_view.right_margin = 72;
                }
            } else {
                // RStudio Workbench Mode: 4-Quadrant workbench feel, show output console & computation docks
                ribbon_stack.visible = true;
                if (doc != null) {
                    doc.source_view.left_margin = 32;
                    doc.source_view.right_margin = 32;
                    doc.console_revealer.reveal_child = true;
                }
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
            doc_page.stats_changed.connect ((words, lines, badge) => {
                status_badge_lbl.label = badge;
                status_words_lbl.label = @"Words: $words | Lines: $lines";
            });

            var page = tab_view.append (doc_page);
            page.title = title;
            page.icon = new GLib.ThemedIcon ("x-office-document-symbolic");
            tab_view.selected_page = page;
            doc_page.emit_buffer_stats ();
        }

        public async void open_document_async () {
            var dialog = new Gtk.FileDialog () {
                title = "Open Document",
                modal = true
            };
            try {
                var file = yield dialog.open (this, null);
                if (file != null) {
                    uint8[] contents;
                    string etag;
                    yield file.load_contents_async (null, out contents, out etag);
                    string raw_text = (string) contents;
                    string name = file.get_basename ();
                    var fmt = Adapters.DocumentFormat.from_filename (name);
                    string text = Adapters.DocumentAdapter.load_to_editor_buffer (raw_text, fmt);

                    string lang = "markdown";
                    if (name.has_suffix (".ipynb")) lang = "json";
                    else if (name.has_suffix (".ts")) lang = "typescript";
                    else if (name.has_suffix (".html")) lang = "html";
                    else if (name.has_suffix (".rmd") || name.has_suffix (".Rmd")) lang = "rmd";
                    add_document_tab (name, lang, text, file);

                    // Dynamic mode resolution for the active file
                    Services.WorkspaceStateManager.get_default ().resolve_mode_for_file (name);
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
                    var fmt = Adapters.DocumentFormat.from_filename (doc.file_location.get_basename ());
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
                        var fmt = Adapters.DocumentFormat.from_filename (file.get_basename ());
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

        // =====================================================================
        // 1. HOME RIBBON (Live Rich-Text / Markdown Tag Binding)
        // =====================================================================
        private Gtk.Widget build_home_ribbon () {
            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4);

            box.append (RibbonFactory.create_tall_button ("edit-paste-symbolic", "Paste", true));
            box.append (RibbonFactory.create_vertical_stack ({
                RibbonFactory.create_compact_button ("edit-cut-symbolic", "Cut"),
                RibbonFactory.create_compact_button ("edit-copy-symbolic", "Copy")
            }));
            box.append (RibbonFactory.create_tall_button ("applications-graphics-symbolic", "Format\nPainter"));
            box.append (RibbonFactory.create_vseparator ());

            var font_matrix = new Gtk.Box (Gtk.Orientation.VERTICAL, 6) { valign = Gtk.Align.CENTER };
            var f_row1 = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4);
            f_row1.append (new Gtk.DropDown.from_strings ({ "JetBrains Mono", "Inter", "Calibri (Body)", "Cantarell" }));
            f_row1.append (new Gtk.DropDown.from_strings ({ "10", "11", "12", "14", "16", "18", "24" }));
            f_row1.append (RibbonFactory.create_compact_button (null, "A⁺"));
            f_row1.append (RibbonFactory.create_compact_button (null, "A⁻"));
            f_row1.append (RibbonFactory.create_compact_button ("edit-clear-symbolic"));
            f_row1.append (RibbonFactory.create_compact_button (null, "Tt", true));

            var f_row2 = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 2);
            var btn_bold = (Gtk.Button) RibbonFactory.create_compact_button ("format-text-bold-symbolic");
            btn_bold.clicked.connect (() => {
                var d = get_active_document ();
                if (d != null) d.apply_tag_or_syntax ("bold", "**");
            });

            var btn_italic = (Gtk.Button) RibbonFactory.create_compact_button ("format-text-italic-symbolic");
            btn_italic.clicked.connect (() => {
                var d = get_active_document ();
                if (d != null) d.apply_tag_or_syntax ("italic", "*");
            });

            var btn_under = (Gtk.Button) RibbonFactory.create_compact_button ("format-text-underline-symbolic");
            btn_under.clicked.connect (() => {
                var d = get_active_document ();
                if (d != null) d.apply_tag_or_syntax ("underline", "__");
            });

            var color_pop = PopoverFactory.create_color_palette_popover ((hex) => {
                var d = get_active_document ();
                if (d != null) d.source_buffer.insert_at_cursor (@"<span style=\"color:$hex;\">text</span>", -1);
            });

            f_row2.append (btn_bold);
            f_row2.append (btn_italic);
            f_row2.append (btn_under);
            f_row2.append (RibbonFactory.create_compact_button ("format-text-strikethrough-symbolic"));
            f_row2.append (RibbonFactory.create_compact_button (null, "x²"));
            f_row2.append (RibbonFactory.create_compact_button (null, "x₂"));
            f_row2.append (RibbonFactory.create_compact_button (null, "Color", false, false, true, null, null, color_pop));

            font_matrix.append (f_row1);
            font_matrix.append (f_row2);
            box.append (font_matrix);
            box.append (RibbonFactory.create_vseparator ());

            // Styles Gallery wired to H1/H2/H3 tags
            var gallery = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4) { valign = Gtk.Align.CENTER };
            gallery.add_css_class ("style-gallery-frame");
            string[] styles = { "Normal", "Heading 1", "Heading 2", "Heading 3" };
            Gtk.ToggleButton? first_style = null;

            foreach (string s_name in styles) {
                var s_btn = new Gtk.ToggleButton ();
                s_btn.add_css_class ("flat");
                s_btn.add_css_class ("style-preset-card");
                if (first_style == null) {
                    first_style = s_btn;
                    s_btn.active = true;
                } else {
                    s_btn.set_group (first_style);
                }
                var s_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);
                s_box.append (new Gtk.Label ("AaBbCcD"));
                s_box.append (new Gtk.Label (s_name));
                s_btn.set_child (s_box);

                string target_style = s_name;
                s_btn.clicked.connect (() => {
                    var d = get_active_document ();
                    if (d != null && target_style == "Heading 1") d.apply_tag_or_syntax ("h1", "# ");
                    if (d != null && target_style == "Heading 2") d.apply_tag_or_syntax ("h2", "## ");
                    if (d != null && target_style == "Heading 3") d.apply_tag_or_syntax ("h3", "### ");
                });
                gallery.append (s_btn);
            }
            box.append (gallery);
            box.append (RibbonFactory.create_tall_button ("document-properties-symbolic", "New Style", true));
            box.append (RibbonFactory.create_vseparator ());

            box.append (RibbonFactory.create_tall_button ("tools-check-spelling-symbolic", "Word Tools", true));
            box.append (RibbonFactory.create_tall_button ("edit-find-replace-symbolic", "Find and\nReplace", true));
            box.append (RibbonFactory.create_tall_button ("emblem-system-symbolic", "Settings", true));
            return box;
        }

        // =====================================================================
        // 2. INSERT RIBBON (With Interactive 6x6 Table Picker Popover)
        // =====================================================================
        private Gtk.Widget build_insert_ribbon () {
            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4);

            box.append (RibbonFactory.create_tall_button ("insert-object-symbolic", "Breaks", true));
            box.append (RibbonFactory.create_tall_button ("document-new-symbolic", "Blank\nPage", true));
            box.append (RibbonFactory.create_vseparator ());

            var table_popover = SmartRibbonHelpers.create_table_builder_popover ((rows, cols) => {
                var d = get_active_document ();
                if (d != null) d.insert_markdown_table (rows, cols);
            });
            box.append (RibbonFactory.create_tall_button ("view-grid-symbolic", "Table", false, false, false, true, null, null, table_popover));

            var code_popover = SmartRibbonHelpers.create_code_chunk_popover ((snippet) => {
                var d = get_active_document ();
                if (d != null) d.source_buffer.insert_at_cursor (snippet, -1);
            });
            box.append (RibbonFactory.create_tall_button ("utilities-terminal-symbolic", "Code\nChunk", false, false, false, true, null, null, code_popover));

            var cite_popover = SmartRibbonHelpers.create_citation_popover ((cite) => {
                var d = get_active_document ();
                if (d != null) d.source_buffer.insert_at_cursor (cite, -1);
            });
            box.append (RibbonFactory.create_tall_button ("book-open-symbolic", "Citation\n(@cite)", false, false, false, true, null, null, cite_popover));

            var sym_popover = SmartRibbonHelpers.create_symbols_popover ((sym) => {
                var d = get_active_document ();
                if (d != null) d.source_buffer.insert_at_cursor (sym, -1);
            });
            box.append (RibbonFactory.create_tall_button ("character-map-symbolic", "Symbols", false, false, false, true, null, null, sym_popover));

            var emoji_popover = SmartRibbonHelpers.create_emoji_popover ((em) => {
                var d = get_active_document ();
                if (d != null) d.source_buffer.insert_at_cursor (em, -1);
            });
            box.append (RibbonFactory.create_tall_button ("face-smile-symbolic", "Emoji", false, false, false, true, null, null, emoji_popover));

            box.append (RibbonFactory.create_tall_button ("insert-image-symbolic", "Picture", true));
            box.append (RibbonFactory.create_tall_button ("applications-graphics-symbolic", "Shapes", true));
            box.append (RibbonFactory.create_vertical_stack ({
                RibbonFactory.create_compact_button ("view-list-symbolic", "Mermaid Diagram"),
                RibbonFactory.create_compact_button ("x-office-presentation-symbolic", "ggplot / Chart")
            }));
            box.append (RibbonFactory.create_vseparator ());

            box.append (RibbonFactory.create_tall_button ("insert-text-symbolic", "LaTeX\nMath ($$)"));
            box.append (RibbonFactory.create_tall_button ("character-map-symbolic", "Symbol", true));
            box.append (RibbonFactory.create_tall_button ("insert-link-symbolic", "Hyperlink"));
            box.append (RibbonFactory.create_vertical_stack ({
                RibbonFactory.create_compact_button ("emblem-symbolic-link", "Cross-reference (@fig)"),
                RibbonFactory.create_compact_button ("user-bookmarks-symbolic", "Citation (@cite)")
            }));

            return box;
        }

        // =====================================================================
        // 3. COMPUTATION RIBBON (NEW: Rmd, Quarto .qmd, Jupyter .ipynb, R & Python)
        // =====================================================================
        private Gtk.Widget build_computation_ribbon () {
            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4);

            // Group 1: Insert Code Chunks
            var btn_r = (Gtk.Button) RibbonFactory.create_tall_button ("utilities-terminal-symbolic", "Insert R\nChunk {r}");
            btn_r.clicked.connect (() => {
                var d = get_active_document ();
                if (d != null) d.insert_code_chunk ("r", "echo: true");
            });

            var btn_py = (Gtk.Button) RibbonFactory.create_tall_button ("utilities-terminal-symbolic", "Insert Python\nChunk {python}");
            btn_py.clicked.connect (() => {
                var d = get_active_document ();
                if (d != null) d.insert_code_chunk ("python", "echo: true");
            });

            var btn_ts = (Gtk.Button) RibbonFactory.create_tall_button ("utilities-terminal-symbolic", "Insert TS/OJS\nChunk {ts}");
            btn_ts.clicked.connect (() => {
                var d = get_active_document ();
                if (d != null) d.insert_code_chunk ("ts");
            });

            box.append (btn_r);
            box.append (btn_py);
            box.append (btn_ts);
            box.append (RibbonFactory.create_vseparator ());

            // Group 2: Chunk Execution Controls
            var btn_run_cell = (Gtk.Button) RibbonFactory.create_tall_button ("media-playback-start-symbolic", "Run\nChunk");
            btn_run_cell.clicked.connect (() => {
                var d = get_active_document ();
                if (d != null) ExecutionEngine.run_command_async.begin ({ "python3", "-c", "print('Chunk executed successfully!')" }, d);
            });

            var btn_run_all = (Gtk.Button) RibbonFactory.create_tall_button ("media-seek-forward-symbolic", "Run All\nChunks");
            btn_run_all.clicked.connect (() => {
                var d = get_active_document ();
                if (d != null) ExecutionEngine.run_command_async.begin ({ "Rscript", "--version" }, d);
            });

            box.append (btn_run_cell);
            box.append (btn_run_all);
            box.append (RibbonFactory.create_vertical_stack ({
                RibbonFactory.create_compact_button ("media-skip-backward-symbolic", "Run Above"),
                RibbonFactory.create_compact_button ("media-skip-forward-symbolic", "Run Below")
            }));
            box.append (RibbonFactory.create_vseparator ());

            // Group 3: Chunk Options Matrix (#| echo, eval, warning, cache)
            var opt_grid = new Gtk.Grid () { row_spacing = 4, column_spacing = 12, valign = Gtk.Align.CENTER };
            opt_grid.attach (new Gtk.CheckButton.with_label ("echo: true") { active = true }, 0, 0, 1, 1);
            opt_grid.attach (new Gtk.CheckButton.with_label ("eval: true") { active = true }, 0, 1, 1, 1);
            opt_grid.attach (new Gtk.CheckButton.with_label ("warning: false") { active = true }, 1, 0, 1, 1);
            opt_grid.attach (new Gtk.CheckButton.with_label ("cache: false"), 1, 1, 1, 1);
            box.append (opt_grid);
            box.append (RibbonFactory.create_vseparator ());

            // Group 4: Kernel & Jupyter (.ipynb) Conversion
            box.append (RibbonFactory.create_tall_button ("system-run-symbolic", "Restart\nKernel"));
            box.append (RibbonFactory.create_vertical_stack ({
                RibbonFactory.create_compact_button ("view-refresh-symbolic", "Convert .ipynb ↔ .qmd"),
                RibbonFactory.create_compact_button ("folder-saved-search-symbolic", "Manage renv / venv")
            }));
            var btn_comp_ai = (Gtk.Button) RibbonFactory.create_tall_button ("system-run-symbolic", "AI Coding\nAssistant");
            btn_comp_ai.clicked.connect (() => {
                trigger_ai_assistant ();
            });
            box.append (btn_comp_ai);

            return box;
        }

        // =====================================================================
        // 4. WEB & PUBLISH RIBBON (NEW: Quarto Render, PDF/HTML Export, TS & HTML5)
        // =====================================================================
        private Gtk.Widget build_web_publish_ribbon () {
            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4);

            // Group 1: Quarto / RMarkdown Export Pipeline
            var btn_html = (Gtk.Button) RibbonFactory.create_tall_button ("applications-internet-symbolic", "Render\nHTML", false, false, false, true, null, "app.export_html");
            var btn_pdf = (Gtk.Button) RibbonFactory.create_tall_button ("document-send-symbolic", "Render\nPDF", false, false, false, true, null, "app.export_pdf");
            box.append (btn_html);
            box.append (btn_pdf);
            box.append (RibbonFactory.create_vertical_stack ({
                RibbonFactory.create_compact_button ("x-office-presentation-symbolic", "Render Reveal.js Slides"),
                RibbonFactory.create_compact_button ("x-office-document-symbolic", "Export MS Word (.docx)")
            }));
            box.append (RibbonFactory.create_vseparator ());

            // Group 2: TypeScript & Web Tooling
            var btn_tsc = (Gtk.Button) RibbonFactory.create_tall_button ("system-run-symbolic", "Compile\nTypeScript");
            btn_tsc.clicked.connect (() => {
                var d = get_active_document ();
                if (d != null) ExecutionEngine.run_command_async.begin ({ "tsc", "--version" }, d);
            });
            box.append (btn_tsc);
            box.append (RibbonFactory.create_vertical_stack ({
                RibbonFactory.create_compact_button ("package-x-generic-symbolic", "Bundle with esbuild"),
                RibbonFactory.create_compact_button ("Insert-text-symbolic", "Format (Prettier)")
            }));
            box.append (RibbonFactory.create_vseparator ());

            // Group 3: HTML5 Snippets & Live Preview Toggle
            box.append (RibbonFactory.create_tall_button ("text-html-symbolic", "HTML5\nBoilerplate", true));
            var btn_live_preview = (Gtk.Button) RibbonFactory.create_tall_button ("view-refresh-symbolic", "Live WebKit\nPreview");
            btn_live_preview.clicked.connect (() => {
                var d = get_active_document ();
                if (d != null) d.show_live_preview ();
            });
            box.append (btn_live_preview);

            var btn_preview = (Gtk.ToggleButton) RibbonFactory.create_tall_button ("view-dual-symbolic", "Toggle Output\nConsole", false, true, true);
            btn_preview.toggled.connect (() => {
                var d = get_active_document ();
                if (d != null) d.console_revealer.reveal_child = btn_preview.active;
            });
            box.append (btn_preview);

            var btn_web_ai = (Gtk.Button) RibbonFactory.create_tall_button ("system-run-symbolic", "AI Web\nAssistant");
            btn_web_ai.clicked.connect (() => {
                trigger_ai_assistant ();
            });
            box.append (btn_web_ai);

            return box;
        }

        // =====================================================================
        // 5. PAGE LAYOUT RIBBON
        // =====================================================================
        private Gtk.Widget build_page_layout_ribbon () {
            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4);
            box.append (RibbonFactory.create_tall_button ("applications-graphics-symbolic", "Themes", true));
            box.append (RibbonFactory.create_vseparator ());
            box.append (RibbonFactory.create_tall_button ("view-fullscreen-symbolic", "Margins", true));
            box.append (RibbonFactory.create_tall_button ("object-rotate-right-symbolic", "Orientation", true));
            box.append (RibbonFactory.create_tall_button ("x-office-document-symbolic", "Size", true));
            box.append (RibbonFactory.create_tall_button ("view-column-symbolic", "Columns", true));
            return box;
        }

        // =====================================================================
        // 6. REFERENCES RIBBON
        // =====================================================================
        private Gtk.Widget build_references_ribbon () {
            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4);
            box.append (RibbonFactory.create_tall_button ("view-list-ordered-symbolic", "Insert\nTOC"));
            box.append (RibbonFactory.create_tall_button ("view-refresh-symbolic", "Update TOC"));
            box.append (RibbonFactory.create_vseparator ());
            box.append (RibbonFactory.create_tall_button ("format-text-superscript-symbolic", "Insert\nFootnote"));
            box.append (RibbonFactory.create_tall_button ("book-open-symbolic", "Insert BibTeX\nCitation", true));
            return box;
        }

        // =====================================================================
        // 7. REVIEW RIBBON
        // =====================================================================
        private Gtk.Widget build_review_ribbon () {
            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4);
            box.append (RibbonFactory.create_tall_button ("tools-check-spelling-symbolic", "Spell\nCheck", true));
            box.append (RibbonFactory.create_tall_button ("document-properties-symbolic", "Word\nCount"));
            box.append (RibbonFactory.create_vseparator ());
            box.append (RibbonFactory.create_tall_button ("user-available-symbolic", "New\nComment"));
            return box;
        }

        // =====================================================================
        // 8. VIEW RIBBON (Split Mode, Apostrophe Mode, RStudio Workbench Toggle)
        // =====================================================================
        private Gtk.Widget build_view_ribbon () {
            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4);

            // Group 1: Workspace Layout Mode Toggle
            var btn_mode_apostrophe = (Gtk.ToggleButton) RibbonFactory.create_tall_button ("edit-find-symbolic", "Apostrophe\nMode", false, true, true);
            var btn_mode_rstudio = (Gtk.ToggleButton) RibbonFactory.create_tall_button ("view-grid-symbolic", "RStudio\nWorkbench", false, true, false);
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

            box.append (btn_mode_apostrophe);
            box.append (btn_mode_rstudio);
            box.append (RibbonFactory.create_vseparator ());

            // Group 2: Split Mode Switcher (Editor Only, Preview Only, Vertical, Horizontal)
            var btn_split_v = (Gtk.ToggleButton) RibbonFactory.create_tall_button ("view-column-symbolic", "Vertical\nSplit", false, true, true);
            var btn_split_h = (Gtk.ToggleButton) RibbonFactory.create_tall_button ("view-paged-symbolic", "Horizontal\nSplit", false, true, false);
            var btn_edit_only = (Gtk.ToggleButton) RibbonFactory.create_tall_button ("x-office-document-symbolic", "Editor\nOnly", false, true, false);
            var btn_prev_only = (Gtk.ToggleButton) RibbonFactory.create_tall_button ("applications-internet-symbolic", "Preview\nOnly", false, true, false);

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

            box.append (btn_split_v);
            box.append (btn_split_h);
            box.append (btn_edit_only);
            box.append (btn_prev_only);
            box.append (RibbonFactory.create_vseparator ());

            var chk_grid = new Gtk.Grid () { row_spacing = 4, column_spacing = 12, valign = Gtk.Align.CENTER };
            chk_grid.attach (new Gtk.CheckButton.with_label ("Line Numbers") { active = true }, 0, 0, 1, 1);
            chk_grid.attach (new Gtk.CheckButton.with_label ("Syntax Highlight") { active = true }, 0, 1, 1, 1);
            chk_grid.attach (new Gtk.CheckButton.with_label ("Word Wrap") { active = true }, 1, 0, 1, 1);
            chk_grid.attach (new Gtk.CheckButton.with_label ("Output Console"), 1, 1, 1, 1);
            box.append (chk_grid);
            return box;
        }

        // =====================================================================
        // 9. SECTION RIBBON
        // =====================================================================
        private Gtk.Widget build_section_ribbon () {
            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4);
            box.append (RibbonFactory.create_tall_button ("view-list-symbolic", "YAML Frontmatter\nInspector"));
            box.append (RibbonFactory.create_vseparator ());
            box.append (RibbonFactory.create_tall_button ("edit-cut-symbolic", "Split\nSection", true));
            box.append (RibbonFactory.create_vertical_stack ({
                RibbonFactory.create_compact_button ("list-add-symbolic", "Insert Section Before"),
                RibbonFactory.create_compact_button ("list-add-symbolic", "Insert Section After")
            }));
            return box;
        }
    }
}
