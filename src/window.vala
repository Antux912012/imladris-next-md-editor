namespace Imladris {

    public class Window : Adw.ApplicationWindow {

        private Adw.ToastOverlay toast_overlay;
        private Adw.ToolbarView toolbar_view;
        private Gtk.Stack ribbon_stack;
        private Adw.TabView tab_view;
        private Adw.TabBar tab_bar;
        private int doc_counter = 1;

        private Gee.HashMap<Adw.TabPage, TabPageContent> tab_pages;
        private Gee.ArrayList<DocumentModel> documents;

        public Window (Gtk.Application app) {
            Object (
                application: app,
                title: "Imladris",
                default_width: 1320,
                default_height: 820
            );
        }

        construct {
            tab_pages = new Gee.HashMap<Adw.TabPage, TabPageContent> ();
            documents = new Gee.ArrayList<DocumentModel> ();

            toast_overlay = new Adw.ToastOverlay ();
            toolbar_view = new Adw.ToolbarView ();
            toast_overlay.set_child (toolbar_view);
            this.set_content (toast_overlay);

            // Master Vertical Container for the 3-Tier Top Area
            var top_master_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            toolbar_view.add_top_bar (top_master_box);

            // =================================================================
            // TIER 1: DARK HEADER BAR & CATEGORY SWITCHER
            // =================================================================
            var win_handle = new Gtk.WindowHandle ();
            var tier1_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 2);
            tier1_box.add_css_class ("imladris-topbar");
            win_handle.set_child (tier1_box);

            // 1A. Branded "Imladris" Primary MenuButton
            var brand_menu = new GLib.Menu ();
            brand_menu.append ("New Document", "app.new");
            brand_menu.append ("New Project...", "app.new-project");
            brand_menu.append ("Open...", "app.open");
            brand_menu.append ("Save", "app.save");
            brand_menu.append ("Save As...", "app.save-as");
            brand_menu.append ("Export to PDF", "app.export_pdf");
            brand_menu.append ("Print...", "app.print");
            brand_menu.append ("About Imladris", "app.about");
            brand_menu.append ("Quit Imladris", "app.quit");

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

            // 1B. Category Switcher Tabs
            ribbon_stack = new Gtk.Stack () {
                transition_type = Gtk.StackTransitionType.CROSSFADE,
                transition_duration = 120
            };

            string[] categories = {
                "Home", "Insert", "Page Layout", "References", "Review", "View", "Section"
            };

            Gtk.ToggleButton? first_tab = null;
            foreach (string cat in categories) {
                var tab_btn = new Gtk.ToggleButton.with_label (cat);
                tab_btn.add_css_class ("ribbon-tab-btn");

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

            // Spacer + Native Window Controls (Minimize, Maximize, Close)
            tier1_box.append (new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) { hexpand = true });
            tier1_box.append (new Gtk.WindowControls (Gtk.PackType.END));
            top_master_box.append (win_handle);

            // =================================================================
            // TIER 2: DYNAMIC RIBBON DECK (All 7 Tabs)
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

            // Left: Quick Access Toolbar
            tier3_box.append (RibbonFactory.create_compact_button ("folder-open-symbolic", null, false, false, true, null, "app.open"));
            tier3_box.append (RibbonFactory.create_compact_button ("document-save-symbolic", null, false, false, true, null, "app.save"));
            tier3_box.append (RibbonFactory.create_compact_button ("document-send-symbolic", null, false, false, true, null, "app.export_pdf"));
            tier3_box.append (RibbonFactory.create_compact_button ("printer-symbolic", null, false, false, true, null, "app.print"));
            tier3_box.append (RibbonFactory.create_compact_button ("system-search-symbolic"));
            tier3_box.append (RibbonFactory.create_compact_button ("edit-undo-symbolic"));
            tier3_box.append (RibbonFactory.create_compact_button ("edit-redo-symbolic"));
            tier3_box.append (RibbonFactory.create_compact_button ("pan-down-symbolic", null, true));

            tier3_box.append (RibbonFactory.create_vseparator ());

            // Right: Document Tab Bar
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
                add_document_tab (@"Document$doc_counter");
            });
            tab_bar.set_end_action_widget (add_tab_btn);

            tier3_box.append (tab_bar);
            top_master_box.append (tier3_box);

            // =================================================================
            // MAIN DOCUMENT WORKSPACE
            // =================================================================
            toolbar_view.set_content (tab_view);

            setup_tab_signals ();
            setup_shortcuts ();

            add_document_tab ("Document1 *");
        }

        public void add_document_tab (string title) {
            var doc = new DocumentModel ();
            doc.title = title;
            if (title == "Document1 *") {
                doc.raw_text = """# Welcome to Imladris 🌿

Imladris is a native Linux Document & Markdown Studio built with **Vala**, **GTK4**, **Libadwaita**, **GtkSourceView 5**, and **WebKitGTK**.

## 3-Tier Ribbon Architecture

- **Tier 1:** Top Dark Header Bar, Branded `Imladris ▾` Menu, and 7 Category Switcher Tabs.
- **Tier 2:** Dynamic Ribbon Deck (`Home`, `Insert`, `Page Layout`, `References`, `Review`, `View`, `Section`).
- **Tier 3:** Quick Access Toolbar & `Adw.TabBar` with instant `+` tab creation.
""";
                doc.is_modified = false;
            }
            var page = create_new_tab (doc);
            page.icon = new GLib.ThemedIcon ("x-office-document-symbolic");
        }

        // =====================================================================
        // 1. HOME RIBBON (Screenshot 1)
        // =====================================================================
        private Gtk.Widget build_home_ribbon () {
            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4);

            // Group 1: Clipboard
            box.append (RibbonFactory.create_tall_button ("edit-paste-symbolic", "Paste", true));
            box.append (RibbonFactory.create_vertical_stack ({
                RibbonFactory.create_compact_button ("edit-cut-symbolic", "Cut"),
                RibbonFactory.create_compact_button ("edit-copy-symbolic", "Copy")
            }));
            box.append (RibbonFactory.create_tall_button ("applications-graphics-symbolic", "Format\nPainter"));
            box.append (RibbonFactory.create_vseparator ());

            // Group 2: Typography 2-Row Matrix
            var font_matrix = new Gtk.Box (Gtk.Orientation.VERTICAL, 6) { valign = Gtk.Align.CENTER };
            var f_row1 = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4);
            f_row1.append (new Gtk.DropDown.from_strings ({ "Calibri (Body)", "Inter", "Cantarell", "Liberation Serif" }));
            f_row1.append (new Gtk.DropDown.from_strings ({ "10", "11", "12", "14", "16", "18", "24", "36" }));
            f_row1.append (RibbonFactory.create_compact_button (null, "A⁺"));
            f_row1.append (RibbonFactory.create_compact_button (null, "A⁻"));
            f_row1.append (RibbonFactory.create_compact_button ("edit-clear-symbolic"));
            f_row1.append (RibbonFactory.create_compact_button (null, "Tt", true));

            var f_row2 = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 2);
            var btn_bold = (Gtk.ToggleButton) RibbonFactory.create_compact_button ("format-text-bold-symbolic", null, false, true);
            btn_bold.toggled.connect (() => {
                if (btn_bold.active) {
                    apply_formatting_to_current (FormattingType.BOLD);
                    btn_bold.active = false;
                }
            });
            var btn_italic = (Gtk.ToggleButton) RibbonFactory.create_compact_button ("format-text-italic-symbolic", null, false, true);
            btn_italic.toggled.connect (() => {
                if (btn_italic.active) {
                    apply_formatting_to_current (FormattingType.ITALIC);
                    btn_italic.active = false;
                }
            });
            f_row2.append (btn_bold);
            f_row2.append (btn_italic);
            f_row2.append (RibbonFactory.create_compact_button ("format-text-underline-symbolic", null, true));
            f_row2.append (RibbonFactory.create_compact_button ("format-text-strikethrough-symbolic", null, true));
            f_row2.append (RibbonFactory.create_compact_button (null, "x²", false, true));
            f_row2.append (RibbonFactory.create_compact_button (null, "x₂", false, true));
            f_row2.append (RibbonFactory.create_compact_button (null, "A", true));
            f_row2.append (RibbonFactory.create_compact_button (null, "ab", true));
            f_row2.append (RibbonFactory.create_compact_button (null, "A", true));

            font_matrix.append (f_row1);
            font_matrix.append (f_row2);
            box.append (font_matrix);
            box.append (RibbonFactory.create_vseparator ());

            // Group 3: Paragraph 2-Row Matrix
            var para_matrix = new Gtk.Box (Gtk.Orientation.VERTICAL, 6) { valign = Gtk.Align.CENTER };
            var p_row1 = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4);
            p_row1.append (RibbonFactory.create_compact_button ("view-list-bullet-symbolic", null, true));
            p_row1.append (RibbonFactory.create_compact_button ("view-list-ordered-symbolic", null, true));
            p_row1.append (RibbonFactory.create_compact_button ("format-indent-less-symbolic"));
            p_row1.append (RibbonFactory.create_compact_button ("format-indent-more-symbolic"));
            p_row1.append (RibbonFactory.create_compact_button ("format-text-direction-ltr-symbolic", null, true));
            p_row1.append (RibbonFactory.create_compact_button ("view-sort-ascending-symbolic"));
            p_row1.append (RibbonFactory.create_compact_button ("insert-object-symbolic", null, true));

            var p_row2 = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4);
            var align_left = (Gtk.ToggleButton) RibbonFactory.create_compact_button ("format-justify-left-symbolic", null, false, true);
            align_left.active = true;
            var align_center = (Gtk.ToggleButton) RibbonFactory.create_compact_button ("format-justify-center-symbolic", null, false, true);
            align_center.set_group (align_left);
            var align_right = (Gtk.ToggleButton) RibbonFactory.create_compact_button ("format-justify-right-symbolic", null, false, true);
            align_right.set_group (align_left);
            var align_fill = (Gtk.ToggleButton) RibbonFactory.create_compact_button ("format-justify-fill-symbolic", null, false, true);
            align_fill.set_group (align_left);

            p_row2.append (align_left);
            p_row2.append (align_center);
            p_row2.append (align_right);
            p_row2.append (align_fill);
            p_row2.append (RibbonFactory.create_compact_button ("view-continuous-symbolic", null, true));
            p_row2.append (RibbonFactory.create_compact_button ("applications-graphics-symbolic", null, true));
            p_row2.append (RibbonFactory.create_compact_button ("view-grid-symbolic", null, true));

            para_matrix.append (p_row1);
            para_matrix.append (p_row2);
            box.append (para_matrix);
            box.append (RibbonFactory.create_vseparator ());

            // Group 4: Inline Styles Gallery
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
                gallery.append (s_btn);
            }
            box.append (gallery);
            box.append (RibbonFactory.create_tall_button ("document-properties-symbolic", "New Style", true));
            box.append (RibbonFactory.create_vseparator ());

            // Group 5: Tools, Find & Settings
            box.append (RibbonFactory.create_tall_button ("tools-check-spelling-symbolic", "Word Tools", true));
            box.append (RibbonFactory.create_tall_button ("edit-find-replace-symbolic", "Find and\nReplace", true));
            box.append (RibbonFactory.create_tall_button ("edit-select-all-symbolic", "Select", true));
            box.append (RibbonFactory.create_tall_button ("emblem-system-symbolic", "Settings", true));

            return box;
        }

        // =====================================================================
        // 2. INSERT RIBBON (Screenshot 2)
        // =====================================================================
        private Gtk.Widget build_insert_ribbon () {
            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4);

            box.append (RibbonFactory.create_tall_button ("insert-object-symbolic", "Breaks", true));
            box.append (RibbonFactory.create_tall_button ("document-new-symbolic", "Blank\nPage", true));
            box.append (RibbonFactory.create_vseparator ());

            box.append (RibbonFactory.create_tall_button ("view-grid-symbolic", "Table", true));
            box.append (RibbonFactory.create_tall_button ("insert-image-symbolic", "Picture", true));
            box.append (RibbonFactory.create_tall_button ("applications-graphics-symbolic", "Shapes", true));
            box.append (RibbonFactory.create_vertical_stack ({
                RibbonFactory.create_compact_button ("view-list-symbolic", "SmartArt"),
                RibbonFactory.create_compact_button ("x-office-presentation-symbolic", "Chart")
            }));
            box.append (RibbonFactory.create_vseparator ());

            box.append (RibbonFactory.create_tall_button ("x-office-document-symbolic", "Header and\nFooter"));
            box.append (RibbonFactory.create_tall_button ("format-text-direction-ltr-symbolic", "Page\nNumber", true));
            box.append (RibbonFactory.create_tall_button ("image-x-generic-symbolic", "Watermark", true));
            box.append (RibbonFactory.create_vseparator ());

            box.append (RibbonFactory.create_tall_button ("user-available-symbolic", "Comment"));
            box.append (RibbonFactory.create_vseparator ());

            box.append (RibbonFactory.create_tall_button ("insert-text-symbolic", "Text Box", true));
            box.append (RibbonFactory.create_tall_button ("font-x-generic-symbolic", "WordArt", true));
            box.append (RibbonFactory.create_tall_button ("character-map-symbolic", "Symbol", true));

            var grid = new Gtk.Grid () { row_spacing = 4, column_spacing = 8, valign = Gtk.Align.CENTER };
            grid.attach (RibbonFactory.create_compact_button ("format-text-larger-symbolic", "Drop Cap", false, false, false), 0, 0, 1, 1);
            grid.attach (RibbonFactory.create_compact_button ("package-x-generic-symbolic", "Object", true), 0, 1, 1, 1);
            grid.attach (RibbonFactory.create_compact_button ("x-office-calendar-symbolic", "Date and Time"), 1, 0, 1, 1);
            grid.attach (RibbonFactory.create_compact_button ("text-x-generic-symbolic", "Quick Parts", true), 1, 1, 1, 1);
            box.append (grid);
            box.append (RibbonFactory.create_vseparator ());

            var link_btn = (Gtk.Button) RibbonFactory.create_tall_button ("insert-link-symbolic", "Hyperlink");
            link_btn.clicked.connect (() => {
                apply_formatting_to_current (FormattingType.LINK);
            });
            box.append (link_btn);
            box.append (RibbonFactory.create_vertical_stack ({
                RibbonFactory.create_compact_button ("emblem-symbolic-link", "Cross-reference"),
                RibbonFactory.create_compact_button ("user-bookmarks-symbolic", "Bookmark")
            }));

            return box;
        }

        // =====================================================================
        // 3. PAGE LAYOUT RIBBON
        // =====================================================================
        private Gtk.Widget build_page_layout_ribbon () {
            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4);

            box.append (RibbonFactory.create_tall_button ("applications-graphics-symbolic", "Themes", true));
            box.append (RibbonFactory.create_vseparator ());

            box.append (RibbonFactory.create_tall_button ("view-fullscreen-symbolic", "Margins", true));
            box.append (RibbonFactory.create_tall_button ("object-rotate-right-symbolic", "Orientation", true));
            box.append (RibbonFactory.create_tall_button ("x-office-document-symbolic", "Size", true));
            box.append (RibbonFactory.create_tall_button ("view-column-symbolic", "Columns", true));
            box.append (RibbonFactory.create_tall_button ("insert-object-symbolic", "Breaks", true));
            box.append (RibbonFactory.create_tall_button ("view-list-ordered-symbolic", "Line\nNumbers", true));
            box.append (RibbonFactory.create_vseparator ());

            box.append (RibbonFactory.create_tall_button ("image-x-generic-symbolic", "Watermark", true));
            box.append (RibbonFactory.create_tall_button ("preferences-color-symbolic", "Page\nColor", true));
            box.append (RibbonFactory.create_tall_button ("view-grid-symbolic", "Page\nBorders"));
            box.append (RibbonFactory.create_vseparator ());

            var indent_grid = new Gtk.Grid () { row_spacing = 4, column_spacing = 8, valign = Gtk.Align.CENTER };
            indent_grid.attach (new Gtk.Label ("Indent Left:") { xalign = 0.0f }, 0, 0, 1, 1);
            indent_grid.attach (new Gtk.SpinButton.with_range (0, 500, 1), 1, 0, 1, 1);
            indent_grid.attach (new Gtk.Label ("Indent Right:") { xalign = 0.0f }, 0, 1, 1, 1);
            indent_grid.attach (new Gtk.SpinButton.with_range (0, 500, 1), 1, 1, 1, 1);
            indent_grid.attach (new Gtk.Label ("Space Before:") { xalign = 0.0f }, 2, 0, 1, 1);
            indent_grid.attach (new Gtk.SpinButton.with_range (0, 500, 1), 3, 0, 1, 1);
            indent_grid.attach (new Gtk.Label ("Space After:") { xalign = 0.0f }, 2, 1, 1, 1);
            indent_grid.attach (new Gtk.SpinButton.with_range (0, 500, 1), 3, 1, 1, 1);
            box.append (indent_grid);

            return box;
        }

        // =====================================================================
        // 4. REFERENCES RIBBON (Screenshot 3)
        // =====================================================================
        private Gtk.Widget build_references_ribbon () {
            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4);

            box.append (RibbonFactory.create_tall_button ("view-list-ordered-symbolic", "Insert\nTOC"));
            box.append (RibbonFactory.create_tall_button ("view-refresh-symbolic", "Update TOC"));
            box.append (RibbonFactory.create_tall_button ("format-indent-more-symbolic", "TOC\nLevel", true));
            box.append (RibbonFactory.create_vseparator ());

            box.append (RibbonFactory.create_tall_button ("format-text-superscript-symbolic", "Insert\nFootnote"));
            box.append (RibbonFactory.create_tall_button ("go-previous-symbolic", "Previous\nFootnote"));
            box.append (RibbonFactory.create_tall_button ("go-next-symbolic", "Next\nFootnote"));
            box.append (RibbonFactory.create_vseparator ());

            box.append (RibbonFactory.create_tall_button ("x-office-document-symbolic", "Insert\nEndnote"));
            box.append (RibbonFactory.create_vertical_stack ({
                RibbonFactory.create_compact_button ("go-previous-symbolic", "Previous Endnote"),
                RibbonFactory.create_compact_button ("go-next-symbolic", "Next Endnote")
            }));
            box.append (RibbonFactory.create_vseparator ());

            box.append (RibbonFactory.create_tall_button ("view-dual-symbolic", "Footnote/Endnote\nSeparator", false, false, false, false));
            box.append (RibbonFactory.create_vseparator ());

            box.append (RibbonFactory.create_tall_button ("insert-text-symbolic", "Caption"));
            box.append (RibbonFactory.create_vertical_stack ({
                RibbonFactory.create_compact_button ("view-list-symbolic", "Insert Table of Figures"),
                RibbonFactory.create_compact_button ("emblem-symbolic-link", "Cross-reference")
            }));
            box.append (RibbonFactory.create_vseparator ());

            box.append (RibbonFactory.create_tall_button ("document-edit-symbolic", "Mark Entry"));
            box.append (RibbonFactory.create_vertical_stack ({
                RibbonFactory.create_compact_button ("view-list-symbolic", "Insert Index"),
                RibbonFactory.create_compact_button ("view-refresh-symbolic", "Update Index", false, false, false)
            }));
            box.append (RibbonFactory.create_vseparator ());

            box.append (RibbonFactory.create_tall_button ("emblem-system-symbolic", "Settings", true));
            return box;
        }

        // =====================================================================
        // 5. REVIEW RIBBON
        // =====================================================================
        private Gtk.Widget build_review_ribbon () {
            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4);

            box.append (RibbonFactory.create_tall_button ("tools-check-spelling-symbolic", "Spell\nCheck", true));
            box.append (RibbonFactory.create_tall_button ("accessories-dictionary-symbolic", "Thesaurus"));
            box.append (RibbonFactory.create_tall_button ("document-properties-symbolic", "Word\nCount"));
            box.append (RibbonFactory.create_vseparator ());

            box.append (RibbonFactory.create_tall_button ("user-available-symbolic", "New\nComment"));
            box.append (RibbonFactory.create_tall_button ("edit-delete-symbolic", "Delete", true));
            box.append (RibbonFactory.create_tall_button ("go-previous-symbolic", "Previous"));
            box.append (RibbonFactory.create_tall_button ("go-next-symbolic", "Next"));
            box.append (RibbonFactory.create_vseparator ());

            box.append (RibbonFactory.create_tall_button ("document-edit-symbolic", "Track\nChanges", false, true));
            box.append (RibbonFactory.create_tall_button ("object-select-symbolic", "Accept", true));
            box.append (RibbonFactory.create_tall_button ("window-close-symbolic", "Reject", true));
            box.append (RibbonFactory.create_vseparator ());

            box.append (RibbonFactory.create_tall_button ("view-dual-symbolic", "Compare"));
            box.append (RibbonFactory.create_tall_button ("changes-prevent-symbolic", "Restrict\nEditing"));

            return box;
        }

        // =====================================================================
        // 6. VIEW RIBBON (Screenshot 4)
        // =====================================================================
        private Gtk.Widget build_view_ribbon () {
            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4);

            // Document View Modes (Grouped ToggleButtons)
            box.append (RibbonFactory.create_tall_button ("view-fullscreen-symbolic", "Full\nScreen"));
            var print_layout_btn = (Gtk.ToggleButton) RibbonFactory.create_tall_button ("x-office-document-symbolic", "Print\nLayout", false, true, true);
            var outline_btn = (Gtk.ToggleButton) RibbonFactory.create_tall_button ("view-list-symbolic", "Outline", false, true, false);
            outline_btn.set_group (print_layout_btn);
            var web_btn = (Gtk.ToggleButton) RibbonFactory.create_tall_button ("applications-internet-symbolic", "Web Layout", false, true, false);
            web_btn.set_group (print_layout_btn);

            print_layout_btn.toggled.connect (() => {
                if (print_layout_btn.active) {
                    set_current_view_mode ("split");
                }
            });
            outline_btn.toggled.connect (() => {
                if (outline_btn.active) {
                    set_current_view_mode ("source");
                }
            });
            web_btn.toggled.connect (() => {
                if (web_btn.active) {
                    set_current_view_mode ("preview");
                }
            });

            box.append (print_layout_btn);
            box.append (outline_btn);
            box.append (web_btn);
            box.append (RibbonFactory.create_vseparator ());

            box.append (RibbonFactory.create_tall_button ("view-dual-symbolic", "Document\nMap", true));

            var chk_grid = new Gtk.Grid () { row_spacing = 4, column_spacing = 12, valign = Gtk.Align.CENTER };
            chk_grid.attach (new Gtk.CheckButton.with_label ("Ruler"), 0, 0, 1, 1);
            chk_grid.attach (new Gtk.CheckButton.with_label ("Markup") { active = true }, 0, 1, 1, 1);
            chk_grid.attach (new Gtk.CheckButton.with_label ("View Gridlines"), 1, 0, 1, 1);
            var chk_task_win = new Gtk.CheckButton.with_label ("Task Window");
            chk_task_win.toggled.connect (() => {
                toggle_terminal ();
            });
            chk_grid.attach (chk_task_win, 1, 1, 1, 1);
            chk_grid.attach (new Gtk.CheckButton.with_label ("Table Gridlines") { active = true }, 2, 0, 1, 1);
            chk_grid.attach (new Gtk.CheckButton.with_label ("Navigation Pane"), 2, 1, 1, 1);
            box.append (chk_grid);
            box.append (RibbonFactory.create_vseparator ());

            box.append (RibbonFactory.create_tall_button ("system-search-symbolic", "Zoom"));
            var z_grid = new Gtk.Grid () { row_spacing = 4, column_spacing = 8, valign = Gtk.Align.CENTER };
            z_grid.attach (RibbonFactory.create_compact_button ("zoom-original-symbolic", "100%"), 0, 0, 1, 1);
            z_grid.attach (RibbonFactory.create_compact_button ("zoom-fit-best-symbolic", "Page Width"), 0, 1, 1, 1);
            z_grid.attach (RibbonFactory.create_compact_button ("x-office-document-symbolic", "One Page"), 1, 0, 1, 1);
            z_grid.attach (RibbonFactory.create_compact_button ("view-grid-symbolic", "Multiple Pages"), 1, 1, 1, 1);
            box.append (z_grid);
            box.append (RibbonFactory.create_vseparator ());

            var btn_eye = RibbonFactory.create_compact_button ("weather-clear-symbolic", "Eye Protection Mode", false, true);
            var btn_night = (Gtk.ToggleButton) RibbonFactory.create_compact_button ("weather-clear-night-symbolic", "Night Mode", false, true);
            btn_night.toggled.connect (() => {
                var sm = Adw.StyleManager.get_default ();
                sm.color_scheme = btn_night.active ? Adw.ColorScheme.FORCE_DARK : Adw.ColorScheme.DEFAULT;
            });
            box.append (RibbonFactory.create_vertical_stack ({
                btn_eye,
                btn_night
            }));
            box.append (RibbonFactory.create_vseparator ());

            box.append (RibbonFactory.create_tall_button ("view-restore-symbolic", "Arrange\nAll", true));
            box.append (RibbonFactory.create_vertical_stack ({
                RibbonFactory.create_compact_button ("window-new-symbolic", "New Window"),
                RibbonFactory.create_compact_button ("view-dual-symbolic", "Split Window", true)
            }));
            box.append (RibbonFactory.create_tall_button ("view-dual-symbolic", "View\nSide by Side", false, false, false, false));

            return box;
        }

        // =====================================================================
        // 7. SECTION RIBBON (Screenshot 5)
        // =====================================================================
        private Gtk.Widget build_section_ribbon () {
            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4);

            box.append (RibbonFactory.create_tall_button ("view-list-symbolic", "Section\nNavigation"));
            box.append (RibbonFactory.create_vseparator ());

            box.append (RibbonFactory.create_tall_button ("object-rotate-right-symbolic", "Orientation", true));
            box.append (RibbonFactory.create_tall_button ("view-column-symbolic", "Columns", true));
            box.append (RibbonFactory.create_vseparator ());

            box.append (RibbonFactory.create_tall_button ("x-office-document-symbolic", "Cover\nPages", true));
            box.append (RibbonFactory.create_tall_button ("view-list-ordered-symbolic", "Contents\nPage", true));
            box.append (RibbonFactory.create_vseparator ());

            box.append (RibbonFactory.create_tall_button ("edit-cut-symbolic", "Split\nSection", true));
            box.append (RibbonFactory.create_vertical_stack ({
                RibbonFactory.create_compact_button ("list-add-symbolic", "Insert Section Before"),
                RibbonFactory.create_compact_button ("list-add-symbolic", "Insert Section After")
            }));
            box.append (RibbonFactory.create_tall_button ("edit-delete-symbolic", "Delete\nSection"));
            box.append (RibbonFactory.create_vseparator ());

            box.append (RibbonFactory.create_tall_button ("x-office-document-symbolic", "Page\nNumber", true));
            box.append (RibbonFactory.create_tall_button ("font-x-generic-symbolic", "Page Number\nFormat", true, false, false, false));

            // Reactive CheckButtons & SpinButton Grid
            var pg_grid = new Gtk.Grid () { row_spacing = 4, column_spacing = 12, valign = Gtk.Align.CENTER };
            var cb_diff_first = new Gtk.CheckButton.with_label ("Different First Page");
            var cb_restart = new Gtk.CheckButton.with_label ("Restart Page Number") { sensitive = false };
            var cb_show_first = new Gtk.CheckButton.with_label ("Show First Page Number") { sensitive = false };

            var spin_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4);
            var spin_lbl = new Gtk.Label ("Page Number Start:") { sensitive = false };
            var spin_btn = new Gtk.SpinButton.with_range (1, 999, 1) { sensitive = false };
            spin_box.append (spin_lbl);
            spin_box.append (spin_btn);

            // Wire reactive sensitivity: toggling "Different First Page" unlocks the dependent controls
            cb_diff_first.toggled.connect (() => {
                bool active = cb_diff_first.active;
                cb_restart.sensitive = active;
                cb_show_first.sensitive = active;
                spin_lbl.sensitive = active;
                spin_btn.sensitive = active;
            });

            pg_grid.attach (cb_diff_first, 0, 0, 1, 1);
            pg_grid.attach (cb_restart, 0, 1, 1, 1);
            pg_grid.attach (cb_show_first, 1, 0, 1, 1);
            pg_grid.attach (spin_box, 1, 1, 1, 1);
            box.append (pg_grid);
            box.append (RibbonFactory.create_vseparator ());

            box.append (RibbonFactory.create_tall_button ("x-office-document-symbolic", "Header and\nFooter"));
            return box;
        }

        private void set_current_view_mode (string mode_name) {
            var page = tab_view.selected_page;
            if (page != null && tab_pages.has_key (page)) {
                var content = tab_pages.get (page);
                content.view_stack.visible_child_name = mode_name;
            }
        }

        private void setup_tab_signals () {
            tab_view.notify["selected-page"].connect (() => {
                update_window_title ();
            });

            tab_view.close_page.connect ((page) => {
                if (tab_pages.has_key (page)) {
                    var content = tab_pages.get (page);
                    if (content.document.is_modified) {
                        prompt_close_page_async.begin (page);
                        return true;
                    }
                }
                return false;
            });

            tab_view.page_detached.connect ((page, position) => {
                if (tab_pages.has_key (page)) {
                    var content = tab_pages.get (page);
                    documents.remove (content.document);
                    tab_pages.unset (page);
                }

                if (tab_view.get_n_pages () == 0) {
                    doc_counter++;
                    add_document_tab (@"Document$doc_counter");
                }
            });
        }

        private async void prompt_close_page_async (Adw.TabPage page) {
            if (!tab_pages.has_key (page)) {
                tab_view.close_page_finish (page, true);
                return;
            }

            var content = tab_pages.get (page);
            var dialog = new Adw.AlertDialog (
                "Save Changes?",
                "Document \"%s\" has unsaved changes. Do you want to save before closing?".printf (content.document.title)
            );
            dialog.add_response ("cancel", "Cancel");
            dialog.add_response ("discard", "Discard");
            dialog.add_response ("save", "Save");

            dialog.set_response_appearance ("discard", Adw.ResponseAppearance.DESTRUCTIVE);
            dialog.set_response_appearance ("save", Adw.ResponseAppearance.SUGGESTED);
            dialog.set_default_response ("save");
            dialog.set_close_response ("cancel");

            try {
                string response = yield dialog.choose (this, null);
                if (response == "save") {
                    bool saved = yield FileManager.get_default ().save_file_async (content.document, this, false);
                    if (saved) {
                        show_toast ("Saved " + content.document.title);
                        tab_view.close_page_finish (page, true);
                    } else {
                        tab_view.close_page_finish (page, false);
                    }
                } else if (response == "discard") {
                    tab_view.close_page_finish (page, true);
                } else {
                    tab_view.close_page_finish (page, false);
                }
            } catch (Error e) {
                show_toast ("Error: " + e.message);
                tab_view.close_page_finish (page, false);
            }
        }

        public Adw.TabPage create_new_tab (DocumentModel? doc_param = null) {
            DocumentModel doc = doc_param ?? new DocumentModel ();
            var content = new TabPageContent (doc);
            var page = tab_view.append (content);
            page.icon = new GLib.ThemedIcon ("x-office-document-symbolic");

            tab_pages.set (page, content);
            documents.add (doc);

            update_page_state (page, doc);

            doc.notify["title"].connect (() => {
                update_page_state (page, doc);
                update_window_title ();
            });

            doc.notify["is-modified"].connect (() => {
                update_page_state (page, doc);
            });

            tab_view.set_selected_page (page);
            update_window_title ();

            return page;
        }

        private void update_page_state (Adw.TabPage page, DocumentModel doc) {
            page.title = doc.title;
            page.needs_attention = doc.is_modified;
            if (doc.is_modified) {
                page.indicator_icon = new ThemedIcon ("media-record-symbolic");
                page.indicator_tooltip = "Document has unsaved changes";
            } else {
                page.indicator_icon = null;
                page.indicator_tooltip = "";
            }
        }

        private void update_window_title () {
            var page = tab_view.selected_page;
            if (page != null && tab_pages.has_key (page)) {
                var content = tab_pages.get (page);
                title = "%s%s — Imladris".printf (
                    content.document.title,
                    content.document.is_modified ? " *" : ""
                );
            } else {
                title = "Imladris";
            }
        }

        public void prompt_open_file () {
            prompt_open_file_async.begin ();
        }

        private async void prompt_open_file_async () {
            try {
                var file = yield FileManager.get_default ().open_file_dialog_async (this);
                if (file != null) {
                    open_file (file);
                }
            } catch (Error e) {
                show_toast ("Error opening file: " + e.message);
            }
        }

        public void present_welcome_or_new_project () {
            var dialog = new NewProjectDialog ();
            dialog.project_created.connect ((file, config) => {
                this.open_document_in_tab (file);
            });
            dialog.present (this);
        }

        public void open_document_in_tab (File file) {
            open_file (file);
        }

        public void open_file (File file) {
            open_file_async.begin (file);
        }

        private async void open_file_async (File file) {
            try {
                var doc = new DocumentModel (file);
                yield FileManager.get_default ().load_file_into_doc_async (file, doc);
                create_new_tab (doc);
                show_toast ("Opened " + doc.title);
            } catch (Error e) {
                show_toast ("Error loading file: " + e.message);
            }
        }

        public void save_current_tab (bool save_as = false) {
            save_current_tab_async.begin (save_as);
        }

        private async void save_current_tab_async (bool save_as) {
            var page = tab_view.selected_page;
            if (page == null || !tab_pages.has_key (page)) {
                return;
            }

            var content = tab_pages.get (page);
            try {
                bool saved = yield FileManager.get_default ().save_file_async (content.document, this, save_as);
                if (saved) {
                    show_toast ("Saved " + content.document.title);
                    update_page_state (page, content.document);
                    update_window_title ();
                }
            } catch (Error e) {
                show_toast ("Error saving file: " + e.message);
            }
        }

        public void close_current_tab () {
            var page = tab_view.selected_page;
            if (page != null) {
                tab_view.close_page (page);
            }
        }

        public void show_toast (string message) {
            var toast = new Adw.Toast (message) {
                timeout = 3
            };
            toast_overlay.add_toast (toast);
        }

        public void apply_formatting_to_current (FormattingType type) {
            var page = tab_view.selected_page;
            if (page != null && tab_pages.has_key (page)) {
                var content = tab_pages.get (page);
                content.coding_view.apply_formatting (type);
            }
        }

        public void toggle_terminal () {
            var page = tab_view.selected_page;
            if (page != null && tab_pages.has_key (page)) {
                var content = tab_pages.get (page);
                content.terminal_visible = !content.terminal_visible;
            }
        }

        public void run_current_chunk () {
            var page = tab_view.selected_page;
            if (page != null && tab_pages.has_key (page)) {
                var content = tab_pages.get (page);
                string language;
                string code;
                if (content.coding_view.get_current_code_chunk (out language, out code)) {
                    content.terminal_visible = true;
                    content.terminal_view.execute_code_chunk (language, code);
                    show_toast ("Running %s chunk in terminal...".printf (language));
                } else {
                    show_toast ("No code chunk or text selected at cursor.");
                }
            }
        }

        private void setup_shortcuts () {
            var controller = new Gtk.ShortcutController ();
            controller.set_scope (Gtk.ShortcutScope.LOCAL);

            var trigger_b = Gtk.ShortcutTrigger.parse_string ("<Primary>b");
            var action_b = new Gtk.CallbackAction ((widget, args) => {
                apply_formatting_to_current (FormattingType.BOLD);
                return true;
            });
            controller.add_shortcut (new Gtk.Shortcut (trigger_b, action_b));

            var trigger_i = Gtk.ShortcutTrigger.parse_string ("<Primary>i");
            var action_i = new Gtk.CallbackAction ((widget, args) => {
                apply_formatting_to_current (FormattingType.ITALIC);
                return true;
            });
            controller.add_shortcut (new Gtk.Shortcut (trigger_i, action_i));

            var trigger_term = Gtk.ShortcutTrigger.parse_string ("<Primary>grave");
            var action_term = new Gtk.CallbackAction ((widget, args) => {
                toggle_terminal ();
                return true;
            });
            controller.add_shortcut (new Gtk.Shortcut (trigger_term, action_term));

            var trigger_run = Gtk.ShortcutTrigger.parse_string ("<Primary>Return");
            var action_run = new Gtk.CallbackAction ((widget, args) => {
                run_current_chunk ();
                return true;
            });
            controller.add_shortcut (new Gtk.Shortcut (trigger_run, action_run));

            var trigger_run_shift = Gtk.ShortcutTrigger.parse_string ("<Shift>Return");
            var action_run_shift = new Gtk.CallbackAction ((widget, args) => {
                run_current_chunk ();
                return true;
            });
            controller.add_shortcut (new Gtk.Shortcut (trigger_run_shift, action_run_shift));

            add_controller (controller);
        }
    }
}
