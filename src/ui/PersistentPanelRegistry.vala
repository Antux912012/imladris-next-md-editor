using Imladris.Core.Layout;

namespace Imladris.UI {

    public class PersistentPanelRegistry : GLib.Object {

        private Gee.HashMap<PanelId, Gtk.Widget> panels;
        private unowned DocumentPage doc_page;
        private unowned Window? main_window;

        // Exposed widgets for DocumentPage integration
        public Gtk.Box source_editor_panel { get; private set; }
        public Gtk.Box notebook_cell_toolbar { get; private set; }
        public Gtk.Box live_preview_panel { get; private set; }
        public Gtk.Box console_panel { get; private set; }
        public Gtk.TextView terminal_view { get; private set; }
        public Gtk.ListBox environment_list { get; private set; }
        public Gtk.ListBox outline_list { get; private set; }
        public Gtk.ListBox citations_list { get; private set; }
        public WebKit.WebView plots_webview { get; private set; }
        public Gtk.ListBox files_list { get; private set; }

        private Gtk.Label? files_dir_lbl = null;
        private string current_browser_dir = "";
        private string root_project_dir = "";

        private int execution_counter = 0;

        public PersistentPanelRegistry (DocumentPage page, Window? win) {
            this.doc_page = page;
            this.main_window = win;
            this.panels = new Gee.HashMap<PanelId, Gtk.Widget> ();

            build_all_persistent_panels ();
        }

        public Gtk.Widget? get_panel_widget (PanelId id) {
            return panels.get (id);
        }

        /**
         * Portal / Host Re-parenting Pattern:
         * Detaches the persistent widget from its previous parent container (if any)
         * and mounts it inside the target viewport without destroying the widget or undo stack.
         */
        public void mount_panel (PanelId id, Gtk.Box target_viewport) {
            var widget = panels.get (id);
            if (widget == null) return;

            var current_parent = widget.get_parent ();
            if (current_parent == target_viewport) {
                return;
            }
            if (current_parent != null) {
                var parent_box = current_parent as Gtk.Box;
                if (parent_box != null) {
                    parent_box.remove (widget);
                } else {
                    widget.unparent ();
                }
            }

            widget.hexpand = true;
            widget.vexpand = true;
            target_viewport.append (widget);
        }

        public void detach_all () {
            foreach (var entry in panels.entries) {
                var w = entry.value;
                var p = w.get_parent ();
                if (p != null) {
                    var pb = p as Gtk.Box;
                    if (pb != null) {
                        pb.remove (w);
                    } else {
                        w.unparent ();
                    }
                }
            }
        }

        private void build_all_persistent_panels () {
            // 1. SOURCE EDITOR PANEL (with .ipynb / RStudio Cell Execution Toolbar)
            source_editor_panel = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
                hexpand = true,
                vexpand = true
            };

            notebook_cell_toolbar = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
                margin_top = 4,
                margin_bottom = 4,
                margin_start = 8,
                margin_end = 8
            };
            notebook_cell_toolbar.add_css_class ("dock-subtoolbar");

            var cell_badge = new Gtk.Label ("Notebook / Chunk Actions:") {
                css_classes = { "dim-label", "caption" }
            };
            notebook_cell_toolbar.append (cell_badge);

            var run_cell_btn = new Gtk.Button () {
                tooltip_text = "Execute active code cell or chunk (Ctrl+Enter)"
            };
            run_cell_btn.add_css_class ("flat");
            run_cell_btn.add_css_class ("ribbon-compact-btn");
            var rc_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4);
            rc_box.append (new Gtk.Image.from_icon_name ("media-playback-start-symbolic"));
            rc_box.append (new Gtk.Label ("Run Cell (Ctrl+Enter)"));
            run_cell_btn.set_child (rc_box);
            run_cell_btn.clicked.connect (() => {
                execute_active_cell ();
            });
            notebook_cell_toolbar.append (run_cell_btn);

            var run_all_btn = new Gtk.Button () {
                tooltip_text = "Execute all code cells sequentially"
            };
            run_all_btn.add_css_class ("flat");
            run_all_btn.add_css_class ("ribbon-compact-btn");
            var ra_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4);
            ra_box.append (new Gtk.Image.from_icon_name ("media-seek-forward-symbolic"));
            ra_box.append (new Gtk.Label ("Run All"));
            run_all_btn.set_child (ra_box);
            run_all_btn.clicked.connect (() => {
                execute_all_cells ();
            });
            notebook_cell_toolbar.append (run_all_btn);

            var add_py_btn = new Gtk.Button.with_label ("+ Python Cell");
            add_py_btn.add_css_class ("flat");
            add_py_btn.add_css_class ("ribbon-compact-btn");
            add_py_btn.clicked.connect (() => {
                doc_page.insert_code_chunk ("python", "echo: true");
            });
            notebook_cell_toolbar.append (add_py_btn);

            var add_r_btn = new Gtk.Button.with_label ("+ R Cell");
            add_r_btn.add_css_class ("flat");
            add_r_btn.add_css_class ("ribbon-compact-btn");
            add_r_btn.clicked.connect (() => {
                doc_page.insert_code_chunk ("r", "echo: true");
            });
            notebook_cell_toolbar.append (add_r_btn);

            source_editor_panel.append (notebook_cell_toolbar);
            source_editor_panel.append (doc_page.editor_scroller);
            panels.set (PanelId.SOURCE_EDITOR, source_editor_panel);

            // 2. LIVE PREVIEW PANEL
            live_preview_panel = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
                hexpand = true,
                vexpand = true
            };
            var preview_bar = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
                margin_top = 4,
                margin_bottom = 4,
                margin_start = 8,
                margin_end = 8
            };
            var preview_lbl = new Gtk.Label ("Rendered Output (WebKitGTK 6.0)") {
                css_classes = { "dim-label", "caption" }
            };
            preview_bar.append (preview_lbl);
            preview_bar.append (new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) { hexpand = true });

            var refresh_btn = new Gtk.Button.from_icon_name ("view-refresh-symbolic") {
                tooltip_text = "Refresh Live Preview"
            };
            refresh_btn.add_css_class ("flat");
            refresh_btn.clicked.connect (() => {
                doc_page.refresh_live_preview ();
            });
            preview_bar.append (refresh_btn);

            live_preview_panel.append (preview_bar);
            live_preview_panel.append (doc_page.web_view);
            panels.set (PanelId.LIVE_PREVIEW, live_preview_panel);

            // 3. CONSOLE PANEL (REPL & Cell Execution Stream with In [n]: / Out [n]:)
            console_panel = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
                hexpand = true,
                vexpand = true
            };
            var console_scroller = new Gtk.ScrolledWindow () {
                child = doc_page.console_view,
                hexpand = true,
                vexpand = true
            };
            console_panel.append (console_scroller);

            var repl_bar = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
                margin_top = 4,
                margin_bottom = 4,
                margin_start = 6,
                margin_end = 6
            };
            var kernel_drop = new Gtk.DropDown.from_strings ({ "Python 3", "Rscript", "Bash" });
            repl_bar.append (kernel_drop);

            var repl_entry = new Gtk.Entry () {
                placeholder_text = "Evaluate expression in kernel (e.g. 2 + 2 or print(sys.version))...",
                hexpand = true
            };
            var eval_btn = new Gtk.Button.with_label ("Execute");
            eval_btn.add_css_class ("suggested-action");

            repl_entry.activate.connect (() => {
                eval_btn.activate ();
            });
            eval_btn.clicked.connect (() => {
                string cmd_text = repl_entry.text.strip ();
                if (cmd_text.length == 0) return;
                repl_entry.text = "";
                uint sel = kernel_drop.selected;
                string engine = sel == 1 ? "r" : (sel == 2 ? "bash" : "python");
                run_code_snippet_in_console (engine, cmd_text);
            });

            var clear_con_btn = new Gtk.Button.from_icon_name ("edit-clear-all-symbolic") {
                tooltip_text = "Clear Console"
            };
            clear_con_btn.add_css_class ("flat");
            clear_con_btn.clicked.connect (() => {
                doc_page.console_view.buffer.text = "";
            });

            repl_bar.append (repl_entry);
            repl_bar.append (eval_btn);
            repl_bar.append (clear_con_btn);
            console_panel.append (repl_bar);
            panels.set (PanelId.CONSOLE, console_panel);

            // 4. TERMINAL PANEL
            var term_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
                hexpand = true,
                vexpand = true
            };
            terminal_view = new Gtk.TextView () {
                editable = false,
                monospace = true,
                wrap_mode = Gtk.WrapMode.WORD_CHAR,
                top_margin = 10,
                bottom_margin = 10,
                left_margin = 10,
                right_margin = 10
            };
            terminal_view.buffer.text = "Imladris System Shell (bash)\nWorking Directory: " + GLib.Environment.get_current_dir () + "\n$ ";
            var term_scroll = new Gtk.ScrolledWindow () {
                child = terminal_view,
                hexpand = true,
                vexpand = true
            };
            var term_input_bar = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
                margin_top = 4,
                margin_bottom = 4,
                margin_start = 6,
                margin_end = 6
            };
            var term_prompt_lbl = new Gtk.Label ("$") { css_classes = { "monospace", "heading" } };
            var term_entry = new Gtk.Entry () {
                placeholder_text = "Run shell command (e.g. ls -la, git status, quarto --version)...",
                hexpand = true
            };
            term_entry.activate.connect (() => {
                string c = term_entry.text.strip ();
                if (c.length == 0) return;
                term_entry.text = "";
                run_shell_command (c);
            });
            term_input_bar.append (term_prompt_lbl);
            term_input_bar.append (term_entry);
            term_box.append (term_scroll);
            term_box.append (term_input_bar);
            panels.set (PanelId.TERMINAL, term_box);

            // 5. ENVIRONMENT PANEL (Active Dataframe & Variable Inspector)
            var env_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
                hexpand = true,
                vexpand = true
            };
            var env_toolbar = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
                margin_top = 4,
                margin_bottom = 4,
                margin_start = 8,
                margin_end = 8
            };
            env_toolbar.append (new Gtk.Label ("Global Environment & Dataframes") { css_classes = { "dim-label", "caption" } });
            env_toolbar.append (new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) { hexpand = true });
            var refresh_env_btn = new Gtk.Button.from_icon_name ("view-refresh-symbolic") {
                tooltip_text = "Inspect Variables from Buffer & Kernel"
            };
            refresh_env_btn.add_css_class ("flat");
            refresh_env_btn.clicked.connect (() => {
                refresh_environment_and_outline ();
            });
            env_toolbar.append (refresh_env_btn);
            env_box.append (env_toolbar);

            environment_list = new Gtk.ListBox () {
                selection_mode = Gtk.SelectionMode.NONE,
                css_classes = { "boxed-list" },
                margin_start = 8,
                margin_end = 8,
                margin_bottom = 8
            };
            var env_scroll = new Gtk.ScrolledWindow () {
                child = environment_list,
                hexpand = true,
                vexpand = true
            };
            env_box.append (env_scroll);
            panels.set (PanelId.ENVIRONMENT, env_box);

            // 6. OUTLINE PANEL (Document AST Table of Contents)
            var outline_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
                hexpand = true,
                vexpand = true
            };
            var outline_bar = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
                margin_top = 4,
                margin_bottom = 4,
                margin_start = 8,
                margin_end = 8
            };
            outline_bar.append (new Gtk.Label ("Document AST Outline (Click to jump)") { css_classes = { "dim-label", "caption" } });
            outline_box.append (outline_bar);

            outline_list = new Gtk.ListBox () {
                selection_mode = Gtk.SelectionMode.SINGLE,
                margin_start = 6,
                margin_end = 6,
                margin_bottom = 6
            };
            outline_list.row_activated.connect ((row) => {
                int target_line = (int) row.get_data<int> ("target-line");
                Gtk.TextIter iter;
                doc_page.source_buffer.get_iter_at_line (out iter, target_line);
                doc_page.source_buffer.place_cursor (iter);
                doc_page.source_view.scroll_to_iter (iter, 0.15, true, 0.0, 0.3);
                doc_page.source_view.grab_focus ();
            });
            var outline_scroll = new Gtk.ScrolledWindow () {
                child = outline_list,
                hexpand = true,
                vexpand = true
            };
            outline_box.append (outline_scroll);
            panels.set (PanelId.OUTLINE, outline_box);

            // 7. CITATIONS PANEL (BibTeX / CSL Bibliography Manager)
            var cit_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6) {
                hexpand = true,
                vexpand = true,
                margin_top = 6,
                margin_bottom = 6,
                margin_start = 8,
                margin_end = 8
            };
            var cit_input_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
            var cit_key_entry = new Gtk.Entry () {
                placeholder_text = "Citation key (e.g. knuth1984)...",
                hexpand = true
            };
            var cit_add_btn = new Gtk.Button.with_label ("Insert @key");
            cit_add_btn.clicked.connect (() => {
                string key = cit_key_entry.text.strip ().replace ("@", "");
                if (key.length > 0) {
                    doc_page.source_buffer.insert_at_cursor (@"[@$key]", -1);
                    cit_key_entry.text = "";
                    refresh_environment_and_outline ();
                }
            });
            cit_input_row.append (cit_key_entry);
            cit_input_row.append (cit_add_btn);
            cit_box.append (cit_input_row);

            citations_list = new Gtk.ListBox () {
                selection_mode = Gtk.SelectionMode.NONE,
                css_classes = { "boxed-list" }
            };
            var cit_scroll = new Gtk.ScrolledWindow () {
                child = citations_list,
                hexpand = true,
                vexpand = true
            };
            cit_box.append (cit_scroll);
            panels.set (PanelId.CITATIONS, cit_box);

            // 8. PLOTS PANEL (Rendered Graphic Outputs & Zoomable Figures)
            var plots_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
                hexpand = true,
                vexpand = true
            };
            var plots_bar = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
                margin_top = 4,
                margin_bottom = 4,
                margin_start = 8,
                margin_end = 8
            };
            plots_bar.append (new Gtk.Label ("Plots & Visual MIME Outputs") { css_classes = { "dim-label", "caption" } });
            plots_bar.append (new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) { hexpand = true });
            var render_plot_btn = new Gtk.Button.with_label ("Render Active Plot");
            render_plot_btn.add_css_class ("flat");
            render_plot_btn.add_css_class ("ribbon-compact-btn");
            render_plot_btn.clicked.connect (() => {
                render_default_scientific_plot ();
            });
            plots_bar.append (render_plot_btn);
            plots_box.append (plots_bar);

            plots_webview = new WebKit.WebView () {
                hexpand = true,
                vexpand = true
            };
            plots_box.append (plots_webview);
            render_default_scientific_plot ();
            panels.set (PanelId.PLOTS, plots_box);

            // 9. FILES PANEL (Project Directory Browser with Folder Traversal)
            var files_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
                hexpand = true,
                vexpand = true
            };
            var files_bar = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4) {
                margin_top = 4,
                margin_bottom = 4,
                margin_start = 8,
                margin_end = 8
            };
            files_dir_lbl = new Gtk.Label ("📁 Workspace") {
                css_classes = { "dim-label", "caption" },
                ellipsize = Pango.EllipsizeMode.START,
                max_width_chars = 24
            };
            files_bar.append (files_dir_lbl);
            files_bar.append (new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) { hexpand = true });

            var up_btn = new Gtk.Button.from_icon_name ("go-up-symbolic") {
                tooltip_text = "Up to Parent Directory"
            };
            up_btn.add_css_class ("flat");
            up_btn.clicked.connect (() => {
                navigate_files_up ();
            });
            files_bar.append (up_btn);

            var home_btn = new Gtk.Button.from_icon_name ("go-home-symbolic") {
                tooltip_text = "Go to Project Root"
            };
            home_btn.add_css_class ("flat");
            home_btn.clicked.connect (() => {
                navigate_files_home ();
            });
            files_bar.append (home_btn);

            var refresh_files_btn = new Gtk.Button.from_icon_name ("view-refresh-symbolic") {
                tooltip_text = "Refresh Workspace Files"
            };
            refresh_files_btn.add_css_class ("flat");
            refresh_files_btn.clicked.connect (() => {
                populate_files_browser ();
            });
            files_bar.append (refresh_files_btn);
            files_box.append (files_bar);

            files_list = new Gtk.ListBox () {
                selection_mode = Gtk.SelectionMode.SINGLE,
                margin_start = 6,
                margin_end = 6,
                margin_bottom = 6
            };
            files_list.row_activated.connect ((row) => {
                bool is_dir = row.get_data<bool> ("is-dir");
                string? fpath = row.get_data<string> ("file-path");
                if (fpath == null) return;
                if (is_dir) {
                    current_browser_dir = fpath;
                    populate_files_browser ();
                } else if (main_window != null) {
                    main_window.open_file_from_path.begin (fpath);
                }
            });
            var files_scroll = new Gtk.ScrolledWindow () {
                child = files_list,
                hexpand = true,
                vexpand = true
            };
            files_box.append (files_scroll);
            populate_files_browser ();
            panels.set (PanelId.FILES, files_box);

            // Connect PersistentSessionManager signals for pwd & plots sync
            Services.PersistentSessionManager.get_default ().working_directory_changed.connect ((new_dir) => {
                this.current_browser_dir = new_dir;
                this.root_project_dir = new_dir;
                populate_files_browser ();
                Gtk.TextIter end;
                terminal_view.buffer.get_end_iter (out end);
                terminal_view.buffer.insert (ref end, @"\n[Working Directory changed to: $new_dir]\n$$ ", -1);
            });
            Services.PersistentSessionManager.get_default ().plot_generated.connect ((plot_path) => {
                load_plot_image (plot_path);
            });

            // 10. HELP PANEL (Documentation & RStudio Workbench Reference)
            var help_view = new WebKit.WebView () {
                hexpand = true,
                vexpand = true
            };
            help_view.load_html ("""<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  body { font-family: system-ui, sans-serif; padding: 16px 20px; color: #1e293b; line-height: 1.5; font-size: 13px; }
  h2 { color: #1d4ed8; margin-top: 0; }
  h3 { color: #334155; margin-bottom: 6px; }
  code { background: #f1f5f9; padding: 2px 5px; border-radius: 4px; font-family: monospace; }
  ul { padding-left: 18px; }
</style>
</head>
<body>
  <h2>Imladris RStudio 4-Quadrant Workbench Help</h2>
  <h3>Drag-and-Drop Docking</h3>
  <ul>
    <li><strong>Reorder Tabs:</strong> Drag any panel tab horizontally within its quadrant header.</li>
    <li><strong>Move Across Quadrants:</strong> Drag a panel tab onto another quadrant's header or center viewport.</li>
    <li><strong>Auto-Collapse:</strong> Emptying a quadrant automatically minimizes it so its sibling expands to 100%.</li>
    <li><strong>4-Way Center Crosshair:</strong> Drag the center intersection handle to resize both horizontal and vertical splitters simultaneously at 60 FPS.</li>
  </ul>
  <h3>Supported Formats</h3>
  <ul>
    <li><code>.md</code> — Apostrophe distraction-free mode by default.</li>
    <li><code>.qmd</code> / <code>.Rmd</code> — RStudio 4-quadrant workbench with YAML frontmatter and <code>#|</code> chunk options.</li>
    <li><code>.ipynb</code> — Bidirectional Jupyter Notebook serializer with cell execution counters (<code>In [1]:</code> / <code>Out [1]:</code>).</li>
  </ul>
</body>
</html>""", null);
            panels.set (PanelId.HELP, help_view);

            // Initial AST & Environment scan
            refresh_environment_and_outline ();
        }

        /**
         * Pillar 4: Shared State Execution — Line or Selection (Ctrl+Enter)
         */
        public void execute_current_line_or_selection () {
            string code_to_run = "";
            Gtk.TextIter sel_start, sel_end;
            bool has_sel = doc_page.source_buffer.get_selection_bounds (out sel_start, out sel_end);

            if (has_sel) {
                code_to_run = doc_page.source_buffer.get_text (sel_start, sel_end, false).strip ();
            } else {
                Gtk.TextIter cursor;
                doc_page.source_buffer.get_iter_at_mark (out cursor, doc_page.source_buffer.get_insert ());
                int line_idx = cursor.get_line ();
                Gtk.TextIter line_start, line_end;
                doc_page.source_buffer.get_iter_at_line (out line_start, line_idx);
                line_end = line_start;
                line_end.forward_to_line_end ();
                code_to_run = doc_page.source_buffer.get_text (line_start, line_end, false).strip ();

                // Advance cursor to next line (RStudio & Jupyter behavior)
                if (line_end.forward_line ()) {
                    doc_page.source_buffer.place_cursor (line_end);
                    doc_page.source_view.scroll_to_iter (line_end, 0.1, false, 0.0, 0.0);
                }
            }

            if (code_to_run.length == 0) return;

            string engine = detect_engine_at_cursor ();
            run_code_snippet_in_console (engine, code_to_run);
        }

        private string detect_engine_at_cursor () {
            Gtk.TextIter cursor;
            doc_page.source_buffer.get_iter_at_mark (out cursor, doc_page.source_buffer.get_insert ());
            int cursor_line = cursor.get_line ();

            string[] lines = doc_page.source_buffer.text.split ("\n");
            bool inside_chunk = false;
            string chunk_engine = "python";

            for (int i = 0; i < lines.length; i++) {
                string trimmed = lines[i].strip ();
                if (!inside_chunk && (trimmed.has_prefix ("```{") || trimmed.has_prefix ("```python") || trimmed.has_prefix ("```r") || trimmed.has_prefix ("```bash"))) {
                    inside_chunk = true;
                    if (trimmed.contains ("r}") || trimmed.has_prefix ("```r")) chunk_engine = "r";
                    else if (trimmed.contains ("bash") || trimmed.contains ("sh}")) chunk_engine = "bash";
                    else chunk_engine = "python";
                    continue;
                }
                if (inside_chunk && trimmed == "```") {
                    if (cursor_line <= i) {
                        return chunk_engine;
                    }
                    inside_chunk = false;
                    continue;
                }
                if (inside_chunk && cursor_line == i) {
                    return chunk_engine;
                }
            }

            if (doc_page.doc_type == "r" || (doc_page.file_location != null && doc_page.file_location.get_basename ().has_suffix (".R"))) {
                return "r";
            }
            if (doc_page.doc_type == "rmd" || (doc_page.file_location != null && doc_page.file_location.get_basename ().has_suffix (".Rmd"))) {
                return "r";
            }
            return "python";
        }

        /**
         * Pillar 4 & 11: Chunk Execution (Ctrl+Shift+Enter) with Inline Card Output
         */
        public void execute_active_cell () {
            string text = doc_page.source_buffer.text;
            Gtk.TextIter cursor;
            doc_page.source_buffer.get_iter_at_mark (out cursor, doc_page.source_buffer.get_insert ());
            int cursor_line = cursor.get_line ();

            string[] lines = text.split ("\n");
            string engine = "python";
            var code_sb = new GLib.StringBuilder ();
            bool inside_chunk = false;
            bool found_target_chunk = false;
            int chunk_end_line = -1;

            for (int i = 0; i < lines.length; i++) {
                string trimmed = lines[i].strip ();
                if (!inside_chunk && (trimmed.has_prefix ("```{") || trimmed.has_prefix ("```python") || trimmed.has_prefix ("```r") || trimmed.has_prefix ("```bash"))) {
                    inside_chunk = true;
                    code_sb.truncate (0);
                    if (trimmed.contains ("r}") || trimmed.has_prefix ("```r")) engine = "r";
                    else if (trimmed.contains ("bash") || trimmed.contains ("sh}")) engine = "bash";
                    else engine = "python";
                    continue;
                }
                if (inside_chunk && trimmed == "```") {
                    if (cursor_line <= i) {
                        found_target_chunk = true;
                        chunk_end_line = i;
                        break;
                    }
                    inside_chunk = false;
                    continue;
                }
                if (inside_chunk && !trimmed.has_prefix ("#|")) {
                    code_sb.append (lines[i] + "\n");
                }
            }

            string code_to_run = code_sb.str.strip ();
            if (!found_target_chunk || code_to_run.length == 0) {
                // Fallback: execute current line or selection
                execute_current_line_or_selection ();
                return;
            }

            run_code_snippet_in_console (engine, code_to_run, chunk_end_line);
        }

        public void execute_all_cells () {
            string[] lines = doc_page.source_buffer.text.split ("\n");
            bool inside_chunk = false;
            string engine = "python";
            var code_sb = new GLib.StringBuilder ();

            for (int i = 0; i < lines.length; i++) {
                string trimmed = lines[i].strip ();
                if (!inside_chunk && (trimmed.has_prefix ("```{") || trimmed.has_prefix ("```python") || trimmed.has_prefix ("```r") || trimmed.has_prefix ("```bash"))) {
                    inside_chunk = true;
                    code_sb.truncate (0);
                    if (trimmed.contains ("r}") || trimmed.has_prefix ("```r")) engine = "r";
                    else if (trimmed.contains ("bash") || trimmed.contains ("sh}")) engine = "bash";
                    else engine = "python";
                    continue;
                }
                if (inside_chunk && trimmed == "```") {
                    inside_chunk = false;
                    string snippet = code_sb.str.strip ();
                    if (snippet.length > 0) {
                        run_code_snippet_in_console (engine, snippet, i);
                    }
                    continue;
                }
                if (inside_chunk && !trimmed.has_prefix ("#|")) {
                    code_sb.append (lines[i] + "\n");
                }
            }
        }

        public void run_code_snippet_in_console (string engine, string code, int inline_chunk_line = -1) {
            execution_counter++;
            int count = execution_counter;
            doc_page.append_console_log (@"\nIn [$count] ($engine):\n$code");

            if (engine == "r") {
                string? plot_file = null;
                Services.PersistentSessionManager.get_default ().execute_r.begin (code, (obj, res) => {
                    string output = Services.PersistentSessionManager.get_default ().execute_r.end (res, out plot_file).strip ();
                    if (output.length > 0) {
                        doc_page.append_console_log (@"Out [$count]:\n$output");
                    }
                    if (plot_file != null) {
                        load_plot_image (plot_file);
                        string base_plot = GLib.Path.get_basename (plot_file);
                        doc_page.append_console_log (@"📊 [Plot rendered in Quadrant 4: $base_plot]");
                    }
                    if (inline_chunk_line >= 0) {
                        doc_page.display_inline_chunk_output (inline_chunk_line, output, plot_file, count);
                    }
                    refresh_environment_and_outline ();
                });
            } else if (engine == "python") {
                string? plot_file = null;
                Services.PersistentSessionManager.get_default ().execute_python.begin (code, (obj, res) => {
                    string output = Services.PersistentSessionManager.get_default ().execute_python.end (res, out plot_file).strip ();
                    if (output.length > 0) {
                        doc_page.append_console_log (@"Out [$count]:\n$output");
                    }
                    if (plot_file != null) {
                        load_plot_image (plot_file);
                        string base_plot = GLib.Path.get_basename (plot_file);
                        doc_page.append_console_log (@"📊 [Plot rendered in Quadrant 4: $base_plot]");
                    }
                    if (inline_chunk_line >= 0) {
                        doc_page.display_inline_chunk_output (inline_chunk_line, output, plot_file, count);
                    }
                    refresh_environment_and_outline ();
                });
            } else {
                ExecutionEngine.capture_command_async.begin ({ "bash", "-c", code }, (obj, res) => {
                    string output = ExecutionEngine.capture_command_async.end (res).strip ();
                    if (output.length > 0) {
                        doc_page.append_console_log (@"Out [$count]:\n$output");
                    }
                    if (inline_chunk_line >= 0) {
                        doc_page.display_inline_chunk_output (inline_chunk_line, output, null, count);
                    }
                    refresh_environment_and_outline ();
                });
            }
        }

        private void run_shell_command (string cmd) {
            Gtk.TextIter end;
            terminal_view.buffer.get_end_iter (out end);
            terminal_view.buffer.insert (ref end, cmd + "\n", -1);

            ExecutionEngine.capture_command_async.begin ({ "bash", "-c", cmd }, (obj, res) => {
                string output = ExecutionEngine.capture_command_async.end (res);
                Gtk.TextIter e2;
                terminal_view.buffer.get_end_iter (out e2);
                terminal_view.buffer.insert (ref e2, output + "\n$ ", -1);
            });
        }

        public void refresh_environment_and_outline () {
            // Clear existing rows
            Gtk.Widget? child = environment_list.get_first_child ();
            while (child != null) {
                var next = child.get_next_sibling ();
                environment_list.remove (child);
                child = next;
            }

            child = outline_list.get_first_child ();
            while (child != null) {
                var next = child.get_next_sibling ();
                outline_list.remove (child);
                child = next;
            }

            child = citations_list.get_first_child ();
            while (child != null) {
                var next = child.get_next_sibling ();
                citations_list.remove (child);
                child = next;
            }

            string text = doc_page.source_buffer.text;
            string[] lines = text.split ("\n");

            int var_count = 0;
            int chunk_idx = 0;

            for (int i = 0; i < lines.length; i++) {
                string line = lines[i];
                string trimmed = line.strip ();

                // 1. Outline headings & chunks
                if (trimmed.has_prefix ("#")) {
                    var row = new Gtk.ListBoxRow ();
                    var hbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8) {
                        margin_top = 4, margin_bottom = 4, margin_start = 6, margin_end = 6
                    };
                    hbox.append (new Gtk.Image.from_icon_name ("format-text-bold-symbolic"));
                    hbox.append (new Gtk.Label (trimmed) { xalign = 0, hexpand = true });
                    hbox.append (new Gtk.Label (@"L$(i + 1)") { css_classes = { "dim-label", "caption" } });
                    row.set_child (hbox);
                    row.set_data<int> ("target-line", i);
                    outline_list.append (row);
                } else if (trimmed.has_prefix ("```{")) {
                    chunk_idx++;
                    var row = new Gtk.ListBoxRow ();
                    var hbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8) {
                        margin_top = 4, margin_bottom = 4, margin_start = 14, margin_end = 6
                    };
                    hbox.append (new Gtk.Image.from_icon_name ("utilities-terminal-symbolic"));
                    hbox.append (new Gtk.Label (@"Chunk #$chunk_idx: $trimmed") { xalign = 0, hexpand = true, css_classes = { "monospace", "caption" } });
                    hbox.append (new Gtk.Label (@"L$(i + 1)") { css_classes = { "dim-label", "caption" } });
                    row.set_child (hbox);
                    row.set_data<int> ("target-line", i);
                    outline_list.append (row);
                }

                // 2. Environment variable detection (Python / R / YAML assignments)
                if (trimmed.contains ("<-") || (trimmed.contains ("=") && !trimmed.has_prefix ("#") && !trimmed.has_prefix ("<"))) {
                    string[] parts = trimmed.contains ("<-") ? trimmed.split ("<-", 2) : trimmed.split ("=", 2);
                    if (parts.length == 2) {
                        string vname = parts[0].strip ();
                        string vval = parts[1].strip ();
                        if (vname.length > 0 && vname.length < 32 && !vname.contains (" ")) {
                            var_count++;
                            string vtype = "scalar";
                            if (vval.has_prefix ("[") || vval.has_prefix ("c(")) vtype = "vector / list";
                            else if (vval.contains ("read_") || vval.contains ("DataFrame") || vval.contains ("mtcars")) vtype = "data.frame";
                            else if (vval.has_prefix ("\"") || vval.has_prefix ("'")) vtype = "string";
                            add_env_row (vname, vtype, vval);
                        }
                    }
                }

                // 3. Citations detection (@key)
                if (trimmed.contains ("@") && !trimmed.has_prefix ("mailto:")) {
                    string[] words = trimmed.split_set (" [](),;.\t");
                    foreach (string w in words) {
                        if (w.has_prefix ("@") && w.length > 2) {
                            var crow = new Adw.ActionRow () {
                                title = w,
                                subtitle = @"Referenced on line $(i + 1)"
                            };
                            var ins_btn = new Gtk.Button.from_icon_name ("insert-text-symbolic") {
                                valign = Gtk.Align.CENTER,
                                tooltip_text = "Insert citation at cursor"
                            };
                            ins_btn.add_css_class ("flat");
                            string cite_key = w;
                            ins_btn.clicked.connect (() => {
                                doc_page.source_buffer.insert_at_cursor (@"[$cite_key]", -1);
                            });
                            crow.add_suffix (ins_btn);
                            citations_list.append (crow);
                        }
                    }
                }
            }

            // Always show standard active session objects in Environment
            add_env_row ("mtcars", "data.frame [32 × 11]", "mpg, cyl, disp, hp, drat, wt...");
            add_env_row ("session_executions", "integer", @"$execution_counter cell runs");
        }

        private void add_env_row (string name, string type_str, string val_preview) {
            var row = new Adw.ActionRow () {
                title = name,
                subtitle = @"$type_str — $val_preview"
            };
            row.add_prefix (new Gtk.Image.from_icon_name ("view-list-symbolic"));
            environment_list.append (row);
        }

        public void render_default_scientific_plot () {
            string svg_html = """<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  body {
    margin: 0;
    padding: 16px;
    background: #ffffff;
    font-family: system-ui, sans-serif;
    color: #1e293b;
    display: flex;
    flex-direction: column;
    align-items: center;
  }
  .plot-card {
    border: 1px solid #e2e8f0;
    border-radius: 8px;
    padding: 16px;
    background: #f8fafc;
    width: 92%;
    max-width: 560px;
    box-shadow: 0 1px 3px rgba(0,0,0,0.05);
  }
  .plot-title {
    font-size: 14px;
    font-weight: 700;
    margin-bottom: 4px;
    color: #0f172a;
  }
  .plot-sub {
    font-size: 11px;
    color: #64748b;
    margin-bottom: 12px;
  }
</style>
</head>
<body>
  <div class="plot-card">
    <div class="plot-title">mtcars: Miles Per Gallon (mpg) vs Horsepower (hp)</div>
    <div class="plot-sub">Rendered SVG Figure • RStudio Quadrant 4 Output</div>
    <svg viewBox="0 0 460 240" width="100%" height="auto" xmlns="http://www.w3.org/2000/svg">
      <rect x="40" y="10" width="400" height="195" fill="#ffffff" stroke="#cbd5e1" stroke-width="1"/>
      <!-- Grid lines -->
      <line x1="40" y1="50" x2="440" y2="50" stroke="#f1f5f9" stroke-width="1"/>
      <line x1="40" y1="100" x2="440" y2="100" stroke="#f1f5f9" stroke-width="1"/>
      <line x1="40" y1="150" x2="440" y2="150" stroke="#f1f5f9" stroke-width="1"/>
      <line x1="140" y1="10" x2="140" y2="205" stroke="#f1f5f9" stroke-width="1"/>
      <line x1="240" y1="10" x2="240" y2="205" stroke="#f1f5f9" stroke-width="1"/>
      <line x1="340" y1="10" x2="340" y2="205" stroke="#f1f5f9" stroke-width="1"/>
      <!-- Regression trend line -->
      <line x1="60" y1="35" x2="410" y2="185" stroke="#3b82f6" stroke-width="2" stroke-dasharray="5,4"/>
      <!-- Data scatter points -->
      <circle cx="85" cy="42" r="5" fill="#2563eb" opacity="0.85"/>
      <circle cx="110" cy="58" r="5" fill="#2563eb" opacity="0.85"/>
      <circle cx="135" cy="74" r="5" fill="#2563eb" opacity="0.85"/>
      <circle cx="160" cy="88" r="5" fill="#10b981" opacity="0.85"/>
      <circle cx="190" cy="95" r="5" fill="#10b981" opacity="0.85"/>
      <circle cx="220" cy="112" r="5" fill="#10b981" opacity="0.85"/>
      <circle cx="260" cy="128" r="5" fill="#f59e0b" opacity="0.85"/>
      <circle cx="305" cy="145" r="5" fill="#f59e0b" opacity="0.85"/>
      <circle cx="355" cy="168" r="5" fill="#ef4444" opacity="0.85"/>
      <circle cx="395" cy="180" r="5" fill="#ef4444" opacity="0.85"/>
      <!-- Axis labels -->
      <text x="240" y="230" font-size="11" text-anchor="middle" fill="#475569">Gross Horsepower (hp)</text>
      <text x="15" y="110" font-size="11" text-anchor="middle" fill="#475569" transform="rotate(-90 15,110)">MPG</text>
    </svg>
  </div>
</body>
</html>""";
            plots_webview.load_html (svg_html, null);
        }

        public void load_plot_image (string plot_file_path) {
            if (!GLib.FileUtils.test (plot_file_path, GLib.FileTest.EXISTS)) return;
            string uri;
            try {
                uri = GLib.Filename.to_uri (plot_file_path);
            } catch (GLib.ConvertError e) {
                uri = "file://" + plot_file_path;
            }
            string fname = GLib.Path.get_basename (plot_file_path);
            string html = """<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  body {
    margin: 0;
    padding: 16px;
    background: #ffffff;
    font-family: system-ui, sans-serif;
    color: #1e293b;
    display: flex;
    flex-direction: column;
    align-items: center;
  }
  .plot-card {
    border: 1px solid #e2e8f0;
    border-radius: 8px;
    padding: 14px;
    background: #f8fafc;
    width: 94%%;
    max-width: 650px;
    box-shadow: 0 1px 3px rgba(0,0,0,0.06);
    text-align: center;
  }
  .plot-img {
    max-width: 100%%;
    height: auto;
    border-radius: 6px;
    border: 1px solid #cbd5e1;
  }
  .plot-title {
    font-size: 13px;
    font-weight: 700;
    margin-top: 10px;
    color: #0f172a;
  }
  .plot-sub {
    font-size: 11px;
    color: #64748b;
    margin-top: 2px;
  }
</style>
</head>
<body>
  <div class="plot-card">
    <img class="plot-img" src="%s" alt="Generated Plot" />
    <div class="plot-title">%s</div>
    <div class="plot-sub">Rendered Graphic Output • Quadrant 4</div>
  </div>
</body>
</html>""".printf (uri, fname);
            plots_webview.load_html (html, null);
        }

        private void navigate_files_up () {
            if (current_browser_dir == "") return;
            var f = GLib.File.new_for_path (current_browser_dir);
            var parent = f.get_parent ();
            if (parent != null) {
                current_browser_dir = parent.get_path ();
                populate_files_browser ();
            }
        }

        private void navigate_files_home () {
            if (root_project_dir != "") {
                current_browser_dir = root_project_dir;
            } else {
                current_browser_dir = Services.PersistentSessionManager.get_default ().current_working_dir;
            }
            populate_files_browser ();
        }

        public void populate_files_browser () {
            Gtk.Widget? child = files_list.get_first_child ();
            while (child != null) {
                var next = child.get_next_sibling ();
                files_list.remove (child);
                child = next;
            }

            if (current_browser_dir == "") {
                if (doc_page.file_location != null && doc_page.file_location.get_parent () != null) {
                    current_browser_dir = doc_page.file_location.get_parent ().get_path ();
                } else {
                    current_browser_dir = Services.PersistentSessionManager.get_default ().current_working_dir;
                }
            }
            if (root_project_dir == "") {
                root_project_dir = current_browser_dir;
            }

            string dir_path = current_browser_dir;
            if (files_dir_lbl != null) {
                string base_name = GLib.Path.get_basename (dir_path);
                files_dir_lbl.label = @"📁 $base_name";
            }

            // Up row if deeper than root
            if (current_browser_dir != root_project_dir) {
                var up_row = new Gtk.ListBoxRow ();
                var up_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8) {
                    margin_top = 4, margin_bottom = 4, margin_start = 6, margin_end = 6
                };
                up_box.append (new Gtk.Image.from_icon_name ("go-up-symbolic"));
                up_box.append (new Gtk.Label (".. (Parent Directory)") { xalign = 0, hexpand = true });
                up_row.set_child (up_box);
                var f = GLib.File.new_for_path (current_browser_dir);
                var parent = f.get_parent ();
                if (parent != null) {
                    up_row.set_data<string> ("file-path", parent.get_path ());
                    up_row.set_data<bool> ("is-dir", true);
                    files_list.append (up_row);
                }
            }

            try {
                var dir = GLib.Dir.open (dir_path, 0);
                string? name = null;
                var dir_entries = new Gee.ArrayList<string> ();
                var file_entries = new Gee.ArrayList<string> ();

                while ((name = dir.read_name ()) != null) {
                    if (name.has_prefix (".")) continue;
                    string full = GLib.Path.build_filename (dir_path, name);
                    if (GLib.FileUtils.test (full, GLib.FileTest.IS_DIR)) {
                        dir_entries.add (name);
                    } else if (GLib.FileUtils.test (full, GLib.FileTest.IS_REGULAR)) {
                        file_entries.add (name);
                    }
                }

                dir_entries.sort ();
                file_entries.sort ();

                foreach (var dname in dir_entries) {
                    string full = GLib.Path.build_filename (dir_path, dname);
                    var row = new Gtk.ListBoxRow ();
                    var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8) {
                        margin_top = 4, margin_bottom = 4, margin_start = 6, margin_end = 6
                    };
                    box.append (new Gtk.Image.from_icon_name ("folder-symbolic"));
                    box.append (new Gtk.Label (dname + "/") { xalign = 0, hexpand = true });
                    row.set_child (box);
                    row.set_data<string> ("file-path", full);
                    row.set_data<bool> ("is-dir", true);
                    files_list.append (row);
                }

                foreach (var fname in file_entries) {
                    string full = GLib.Path.build_filename (dir_path, fname);
                    var row = new Gtk.ListBoxRow ();
                    var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8) {
                        margin_top = 4, margin_bottom = 4, margin_start = 6, margin_end = 6
                    };
                    string icon_name = "text-x-generic-symbolic";
                    if (fname.has_suffix (".R") || fname.has_suffix (".py") || fname.has_suffix (".sh")) {
                        icon_name = "utilities-terminal-symbolic";
                    } else if (fname.has_suffix (".ipynb") || fname.has_suffix (".qmd") || fname.has_suffix (".Rmd")) {
                        icon_name = "applications-science-symbolic";
                    } else if (fname.has_suffix (".html") || fname.has_suffix (".htm")) {
                        icon_name = "text-html-symbolic";
                    } else if (fname.has_suffix (".png") || fname.has_suffix (".jpg") || fname.has_suffix (".svg")) {
                        icon_name = "image-x-generic-symbolic";
                    }
                    box.append (new Gtk.Image.from_icon_name (icon_name));
                    box.append (new Gtk.Label (fname) { xalign = 0, hexpand = true });
                    row.set_child (box);
                    row.set_data<string> ("file-path", full);
                    row.set_data<bool> ("is-dir", false);
                    files_list.append (row);
                }
            } catch (GLib.Error e) {
                warning ("Directory scan error: %s", e.message);
            }
        }
    }
}
