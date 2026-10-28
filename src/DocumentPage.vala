using Imladris.Core.Layout;
using Imladris.UI;

namespace Imladris {

    public class DocumentPage : Gtk.Box {

        public GtkSource.View source_view { get; private set; }
        public GtkSource.Buffer source_buffer { get; private set; }
        public Gtk.TextView console_view { get; private set; }
        public WebKit.WebView web_view { get; private set; }
        public Gtk.Stack right_stack { get; private set; }
        public Gtk.Revealer console_revealer { get; private set; }
        public string doc_type { get; private set; }

        public AssistantPanel? assistant_panel { get; private set; default = null; }
        public GLib.File? file_location { get; set; default = null; }
        private Window? parent_window;
        private uint update_debounce_id = 0;

        // Apostrophe Shell Containers
        public Gtk.Paned paned { get; private set; }
        public Gtk.Box apostrophe_editor_host { get; private set; }
        public Gtk.Box apostrophe_preview_host { get; private set; }
        public Gtk.ScrolledWindow editor_scroller { get; private set; }
        public Gtk.Box right_box { get; private set; }
        public string doc_id { get; private set; }

        // Phase 1.1.3 Portal Registry & 4-Quadrant RStudio Docking Grid
        public RStudioDockLayoutState dock_layout_state { get; private set; }
        public PersistentPanelRegistry panel_registry { get; private set; }
        public RStudioDockGrid rstudio_dock_grid { get; private set; }
        public ProjectType project_type { get; set; default = ProjectType.STANDARD; }
        private Services.LayoutMode current_layout_mode = Services.LayoutMode.APOSTROPHE;
        private ulong ai_settings_handler_id = 0;

        public DocumentFormat get_document_format () {
            if (file_location != null) {
                return DocumentFormat.from_filename (file_location.get_basename ());
            }
            return DocumentFormat.from_short_code (doc_type);
        }

        private Gee.HashMap<int, UI.InlineChunkOutputWidget> inline_chunk_widgets = new Gee.HashMap<int, UI.InlineChunkOutputWidget> ();

        /**
         * Pillar 11: Embeds an inline output card directly below the executed chunk
         */
        public void display_inline_chunk_output (int end_line, string text_output, string? plot_path, int count) {
            UI.InlineChunkOutputWidget? widget = inline_chunk_widgets.get (end_line);
            if (widget == null) {
                Gtk.TextIter iter;
                source_buffer.get_iter_at_line (out iter, end_line);
                iter.forward_to_line_end ();

                // Insert newline and child anchor
                source_buffer.insert (ref iter, "\n", 1);
                var anchor = source_buffer.create_child_anchor (iter);
                widget = new UI.InlineChunkOutputWidget (end_line);
                source_view.add_child_at_anchor (widget, anchor);
                inline_chunk_widgets.set (end_line, widget);
            }

            widget.set_output (text_output, plot_path, count);
        }

        public signal void stats_changed (int words, int lines, string lang_badge);

        public DocumentPage (string title, string lang_id, Window? win = null) {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 0);
            this.doc_type = lang_id;
            this.parent_window = win;
            this.doc_id = GLib.Uuid.string_random ();

            // 1. Setup GtkSource.Buffer with Syntax Highlighting + Rich TextTags
            var lang_manager = GtkSource.LanguageManager.get_default ();
            var language = lang_manager.get_language (lang_id == "rmd" ? "markdown" : lang_id);
            source_buffer = new GtkSource.Buffer.with_language (language);
            source_buffer.highlight_syntax = true;

            update_style_scheme ();

            Core.SettingsManager.get_default ().theme_changed.connect ((t) => {
                update_style_scheme ();
                refresh_live_preview ();
            });

            Adw.StyleManager.get_default ().notify["dark"].connect (() => {
                if (Core.SettingsManager.get_default ().app_theme == Core.AppTheme.SYSTEM) {
                    update_style_scheme ();
                    refresh_live_preview ();
                }
            });

            setup_text_tags ();
            populate_starter_template (title, lang_id);

            source_view = new GtkSource.View.with_buffer (source_buffer) {
                show_line_numbers = true,
                highlight_current_line = true,
                auto_indent = true,
                indent_width = 2,
                wrap_mode = Gtk.WrapMode.WORD_CHAR,
                top_margin = 32,
                bottom_margin = 32,
                left_margin = 48,
                right_margin = 48,
                monospace = true
            };

            setup_completion ();
            setup_cell_execution_shortcut ();

            var editor_context_menu = new GLib.Menu ();
            editor_context_menu.append ("Write with Elrond Assistance (AI)", "app.elrond_assist");
            source_view.extra_menu = editor_context_menu;

            editor_scroller = new Gtk.ScrolledWindow () {
                child = source_view,
                hexpand = true,
                vexpand = true
            };

            // 2. Shared WebKitGTK 6.0 & Console Instances (Kept alive in PersistentPanelRegistry)
            web_view = UI.WebViewFactory.create ();
            var settings = web_view.get_settings ();
            settings.enable_developer_extras = true;
            settings.enable_javascript = true;

            console_view = new Gtk.TextView () {
                editable = false,
                monospace = true,
                wrap_mode = Gtk.WrapMode.WORD_CHAR,
                top_margin = 12,
                bottom_margin = 12,
                left_margin = 12,
                right_margin = 12
            };

            // 3. Initialize PersistentPanelRegistry & RStudioDockGrid
            dock_layout_state = new RStudioDockLayoutState ();
            dock_layout_state.load_from_disk ();

            panel_registry = new PersistentPanelRegistry (this, parent_window);
            rstudio_dock_grid = new RStudioDockGrid (dock_layout_state, panel_registry);

            // 4. Build Apostrophe Shell (Single-Pane / Clean Split Writer View)
            paned = new Gtk.Paned (Gtk.Orientation.HORIZONTAL) {
                hexpand = true,
                vexpand = true,
                position = 780
            };

            apostrophe_editor_host = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
                hexpand = true,
                vexpand = true
            };

            console_revealer = new Gtk.Revealer () {
                transition_type = Gtk.RevealerTransitionType.SLIDE_LEFT,
                reveal_child = true
            };

            right_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
                width_request = 480
            };

            var right_header = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
                margin_top = 4,
                margin_bottom = 4,
                margin_start = 8,
                margin_end = 8
            };

            right_stack = new Gtk.Stack () {
                transition_type = Gtk.StackTransitionType.CROSSFADE,
                hexpand = true,
                vexpand = true
            };

            var stack_switcher = new Gtk.StackSwitcher () {
                stack = right_stack
            };
            right_header.append (stack_switcher);
            right_header.append (new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) { hexpand = true });

            var btn_close_panel = new Gtk.Button.from_icon_name ("window-close-symbolic") {
                tooltip_text = "Close Panel",
                valign = Gtk.Align.CENTER
            };
            btn_close_panel.add_css_class ("flat");
            btn_close_panel.clicked.connect (() => {
                console_revealer.reveal_child = false;
            });
            right_header.append (btn_close_panel);

            right_box.append (right_header);

            apostrophe_preview_host = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
                hexpand = true,
                vexpand = true
            };
            right_stack.add_titled (apostrophe_preview_host, "preview", "Live Preview");

            if (parent_window != null) {
                assistant_panel = new AssistantPanel (parent_window);
                right_stack.add_titled (assistant_panel, "assistant", "Elrond Assistance");
            }

            right_box.append (right_stack);
            console_revealer.set_child (right_box);

            apply_panel_position ();
            ai_settings_handler_id = Core.SettingsManager.get_default ().ai_settings_changed.connect (apply_panel_position);

            this.append (paned);
            this.append (rstudio_dock_grid);

            // Mount initial layout based on file extension
            var initial_mode = Services.LayoutMode.from_extension (title);
            set_workbench_mode (initial_mode);

            refresh_live_preview ();

            source_buffer.changed.connect (() => {
                if (update_debounce_id != 0) {
                    GLib.Source.remove (update_debounce_id);
                    update_debounce_id = 0;
                }
                update_debounce_id = GLib.Timeout.add (250, () => {
                    update_debounce_id = 0;
                    emit_buffer_stats ();
                    refresh_live_preview ();
                    panel_registry.refresh_environment_and_outline ();

                    // Non-blocking shadow buffer write for crash resilience
                    int line = 0;
                    int col = 0;
                    Gtk.TextIter insert_iter;
                    source_buffer.get_iter_at_mark (out insert_iter, source_buffer.get_insert ());
                    line = insert_iter.get_line ();
                    col = insert_iter.get_line_offset ();
                    string? path = file_location != null ? file_location.get_path () : null;

                    Services.RecoveryService.get_default ().snapshot_async.begin (
                        doc_id,
                        path,
                        doc_type,
                        source_buffer.text,
                        line,
                        col,
                        true
                    );

                    return GLib.Source.REMOVE;
                });
            });
        }

        ~DocumentPage () {
            if (ai_settings_handler_id != 0) {
                Core.SettingsManager.get_default ().disconnect (ai_settings_handler_id);
                ai_settings_handler_id = 0;
            }
            if (update_debounce_id != 0) {
                GLib.Source.remove (update_debounce_id);
                update_debounce_id = 0;
            }
        }

        private void setup_cell_execution_shortcut () {
            var key_ctrl = new Gtk.EventControllerKey ();
            key_ctrl.key_pressed.connect ((keyval, keycode, state) => {
                if ((state & Gdk.ModifierType.CONTROL_MASK) != 0 &&
                    (keyval == Gdk.Key.Return || keyval == Gdk.Key.KP_Enter)) {
                    if ((state & Gdk.ModifierType.SHIFT_MASK) != 0) {
                        panel_registry.execute_active_cell ();
                    } else {
                        panel_registry.execute_current_line_or_selection ();
                    }
                    return true;
                }
                return false;
            });
            source_view.add_controller (key_ctrl);
        }

        /**
         * Transitions seamlessly between Apostrophe Mode (single-pane writer)
         * and RStudio Mode (4-quadrant dock grid) by re-parenting the persistent
         * panel widgets without losing undo/redo stack or cursor focus.
         */
        public void set_workbench_mode (Services.LayoutMode mode) {
            current_layout_mode = mode;

            if (mode == Services.LayoutMode.APOSTROPHE) {
                rstudio_dock_grid.visible = false;
                paned.visible = true;

                panel_registry.notebook_cell_toolbar.visible = false;
                source_view.left_margin = 72;
                source_view.right_margin = 72;

                panel_registry.mount_panel (PanelId.SOURCE_EDITOR, apostrophe_editor_host);
                panel_registry.mount_panel (PanelId.LIVE_PREVIEW, apostrophe_preview_host);
            } else {
                paned.visible = false;
                rstudio_dock_grid.visible = true;

                panel_registry.notebook_cell_toolbar.visible = true;
                source_view.left_margin = 28;
                source_view.right_margin = 28;

                rstudio_dock_grid.refresh_dock_layout ();
            }
        }

        private void setup_text_tags () {
            source_buffer.create_tag ("bold", "weight", Pango.Weight.BOLD);
            source_buffer.create_tag ("italic", "style", Pango.Style.ITALIC);
            source_buffer.create_tag ("underline", "underline", Pango.Underline.SINGLE);
            source_buffer.create_tag ("strike", "strikethrough", true);
            source_buffer.create_tag ("h1", "scale", 1.7, "weight", Pango.Weight.BOLD);
            source_buffer.create_tag ("h2", "scale", 1.4, "weight", Pango.Weight.BOLD);
            source_buffer.create_tag ("h3", "scale", 1.2, "weight", Pango.Weight.BOLD);
        }

        private void populate_starter_template (string title, string lang_id) {
            if (lang_id == "markdown" || lang_id == "rmd") {
                source_buffer.text = """---
title: "%s"
format:
  html: default
  pdf: default
---

# Introduction

Write your scientific narrative or documentation here.

```{r}
#| echo: true
#| warning: false
summary(mtcars[, 1:4])
```

```{python}
import sys
print("Python Kernel Ready:", sys.version.split()[0])
```
""".printf (title);
            } else if (lang_id == "typescript") {
                source_buffer.text = """// Imladris TypeScript Module
export interface DataPoint {
  id: number;
  label: string;
  value: number;
}

export function summarize(points: DataPoint[]): number {
  return points.reduce((acc, item) => acc + item.value, 0);
}
""";
            } else if (lang_id == "r") {
                source_buffer.text = """# Imladris R Script Session
# Author: %s
summary(mtcars[, 1:4])
""".printf (GLib.Environment.get_real_name ());
            } else if (lang_id == "python3") {
                source_buffer.text = """#!/usr/bin/env python3
# Imladris Python Script Session
import sys
print("Python Interpreter:", sys.version.split()[0])
""";
            } else if (lang_id == "html") {
                source_buffer.text = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Imladris Live HTML Document</title>
  <style>
    body { font-family: system-ui, sans-serif; padding: 2rem; color: #1e293b; }
    h1 { color: #2b73d2; }
  </style>
</head>
<body>
  <h1>Imladris HTML5 Studio</h1>
  <p>Live rendered via <strong>WebKitGTK 6.0</strong>.</p>
</body>
</html>
""";
            }
        }

        private void update_style_scheme () {
            var sm = GtkSource.StyleSchemeManager.get_default ();
            var theme = Core.SettingsManager.get_default ().app_theme;
            bool is_dark = Adw.StyleManager.get_default ().dark;

            GtkSource.StyleScheme? scheme = null;
            if (theme == Core.AppTheme.DARK || (theme == Core.AppTheme.SYSTEM && is_dark)) {
                scheme = sm.get_scheme ("Adwaita-dark") ?? sm.get_scheme ("classic-dark");
            } else if (theme == Core.AppTheme.EYE_FRIENDLY) {
                scheme = sm.get_scheme ("solarized-light") ?? sm.get_scheme ("tango") ?? sm.get_scheme ("Adwaita");
            } else {
                scheme = sm.get_scheme ("Adwaita") ?? sm.get_scheme ("classic");
            }

            if (scheme != null) {
                source_buffer.style_scheme = scheme;
            }
        }

        public void refresh_live_preview () {
            string raw = source_buffer.text;
            if (doc_type == "html") {
                web_view.load_html (raw, null);
                return;
            }

            var fmt = DocumentFormat.from_filename (file_location != null ? file_location.get_basename () : @"untitled.$doc_type");
            string body_html = Adapters.DocumentAdapter.render_html (raw, fmt);

            var app_theme = Core.SettingsManager.get_default ().app_theme;
            bool is_dark = Adw.StyleManager.get_default ().dark;
            bool use_dark = (app_theme == Core.AppTheme.DARK) || (app_theme == Core.AppTheme.SYSTEM && is_dark);
            bool use_sepia = (app_theme == Core.AppTheme.EYE_FRIENDLY);

            string bg_color = use_dark ? "#1e1e1e" : (use_sepia ? "#faf5ee" : "#ffffff");
            string text_color = use_dark ? "#e2e8f0" : (use_sepia ? "#383431" : "#1e242b");
            string card_bg = use_dark ? "#262626" : (use_sepia ? "#f0e7dc" : "#f8fafc");
            string card_border = use_dark ? "#404040" : (use_sepia ? "#dcd0c2" : "#cbd5e1");
            string header_bg = use_dark ? "#333333" : (use_sepia ? "#e6dcce" : "#e2e8f0");
            string header_color = use_dark ? "#94a3b8" : (use_sepia ? "#5c534b" : "#475569");

            string html = """<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  body {
    font-family: 'Inter', 'Cantarell', system-ui, -apple-system, sans-serif;
    line-height: 1.6;
    color: %s;
    background: %s;
    padding: 24px 32px;
    margin: 0;
  }
  .badge {
    display: inline-block;
    background: #e8f0fe;
    color: #1967d2;
    font-weight: 700;
    font-size: 11px;
    padding: 3px 8px;
    border-radius: 4px;
    margin-bottom: 12px;
    text-transform: uppercase;
  }
  .code-chunk-card {
    background: %s;
    border: 1px solid %s;
    border-radius: 8px;
    margin: 16px 0;
    overflow: hidden;
  }
  .code-chunk-header {
    background: %s;
    padding: 6px 12px;
    font-size: 12px;
    font-weight: 600;
    color: %s;
    display: flex;
    align-items: center;
    gap: 8px;
  }
  .chunk-opts {
    font-family: monospace;
    font-size: 11px;
    color: #64748b;
  }
  .document-frontmatter-card {
    background: %s;
    border: 1px solid %s;
    border-radius: 8px;
    padding: 16px 20px;
    margin-bottom: 24px;
  }
  .frontmatter-title {
    margin-top: 0;
    color: %s;
  }
  .frontmatter-meta-grid {
    display: flex;
    flex-wrap: wrap;
    gap: 12px 24px;
    font-size: 13px;
    color: %s;
  }
  .frontmatter-label {
    font-weight: 600;
    margin-right: 6px;
  }
  .frontmatter-badge {
    background: #38bdf8;
    color: #0369a1;
    font-weight: 600;
    padding: 2px 6px;
    border-radius: 4px;
  }
  pre {
    background: %s;
    border: 1px solid %s;
    border-radius: 6px;
    padding: 14px;
    overflow-x: auto;
    font-family: 'JetBrains Mono', monospace;
    font-size: 13px;
    white-space: pre-wrap;
    margin: 8px 12px;
  }
</style>
</head>
<body>
  <div class="badge">WebKitGTK 6.0 Live Preview • %s</div>
  <div id="content">%s</div>
</body>
</html>""".printf (
                text_color, bg_color,
                card_bg, card_border,
                header_bg, header_color,
                card_bg, card_border,
                text_color, header_color,
                card_bg, card_border,
                fmt.to_badge_label (), body_html
            );

            web_view.load_html (html, null);
        }

        public void set_split_orientation (Services.SplitMode split) {
            if (current_layout_mode == Services.LayoutMode.RSTUDIO) {
                // In RStudio mode, activate the corresponding panel in Q4
                dock_layout_state.activate_tab (QuadrantId.Q4_BOTTOM_RIGHT, PanelId.LIVE_PREVIEW);
                return;
            }

            switch (split) {
                case Services.SplitMode.EDITOR_ONLY:
                    apostrophe_editor_host.visible = true;
                    console_revealer.visible = false;
                    break;
                case Services.SplitMode.PREVIEW_ONLY:
                    apostrophe_editor_host.visible = false;
                    console_revealer.visible = true;
                    console_revealer.reveal_child = true;
                    right_stack.visible_child_name = "preview";
                    break;
                case Services.SplitMode.HORIZONTAL_SPLIT:
                    apostrophe_editor_host.visible = true;
                    console_revealer.visible = true;
                    console_revealer.reveal_child = true;
                    paned.orientation = Gtk.Orientation.VERTICAL;
                    right_stack.visible_child_name = "preview";
                    int h = paned.get_height ();
                    if (h > 100) paned.set_position (h / 2);
                    break;
                case Services.SplitMode.VERTICAL_SPLIT:
                default:
                    apostrophe_editor_host.visible = true;
                    console_revealer.visible = true;
                    console_revealer.reveal_child = true;
                    paned.orientation = Gtk.Orientation.HORIZONTAL;
                    right_stack.visible_child_name = "preview";
                    int w = paned.get_width ();
                    if (w > 100) paned.set_position (w / 2);
                    break;
            }
        }

        public void show_live_preview (string? uri = null) {
            if (current_layout_mode == Services.LayoutMode.RSTUDIO) {
                dock_layout_state.activate_tab (QuadrantId.Q4_BOTTOM_RIGHT, PanelId.LIVE_PREVIEW);
            } else {
                console_revealer.reveal_child = true;
                right_stack.visible_child_name = "preview";
            }
            if (uri != null) {
                web_view.load_uri (uri);
            } else {
                refresh_live_preview ();
            }
        }

        public void apply_panel_position () {
            var settings = Core.SettingsManager.get_default ();
            var pos = settings.chat_panel_position;

            bool is_currently_left = (paned.get_start_child () == console_revealer);
            if (pos == Core.SidePanelPosition.LEFT && is_currently_left) {
                return;
            }
            if (pos == Core.SidePanelPosition.RIGHT && !is_currently_left && paned.get_end_child () == console_revealer) {
                return;
            }

            paned.set_start_child (null);
            paned.set_end_child (null);

            if (pos == Core.SidePanelPosition.LEFT) {
                console_revealer.transition_type = Gtk.RevealerTransitionType.SLIDE_RIGHT;
                paned.set_start_child (console_revealer);
                paned.set_end_child (apostrophe_editor_host);
                paned.position = 480;
            } else {
                console_revealer.transition_type = Gtk.RevealerTransitionType.SLIDE_LEFT;
                paned.set_start_child (apostrophe_editor_host);
                paned.set_end_child (console_revealer);
                int total_w = paned.get_width ();
                paned.position = total_w > 500 ? (total_w - 480) : 780;
            }
        }

        public void show_ai_assistant () {
            if (current_layout_mode == Services.LayoutMode.RSTUDIO) {
                set_workbench_mode (Services.LayoutMode.APOSTROPHE);
            }
            apply_panel_position ();
            console_revealer.visible = true;
            console_revealer.reveal_child = true;
            right_stack.visible_child_name = "assistant";
            if (assistant_panel != null) {
                assistant_panel.focus_input ();
            }
        }

        private void setup_completion () {
            var completion = source_view.get_completion ();

            var ai_provider = new AI.AiCompletionProvider ();
            completion.add_provider (ai_provider);

            var words_provider = new GtkSource.CompletionWords ("Document Vocabulary");
            words_provider.register (source_buffer);
            words_provider.minimum_word_size = 2;
            words_provider.priority = 10;
            completion.add_provider (words_provider);

            var snippets_provider = new GtkSource.CompletionSnippets ();
            snippets_provider.priority = 20;
            completion.add_provider (snippets_provider);
        }

        public string get_selected_text () {
            Gtk.TextIter start, end;
            if (source_buffer.get_selection_bounds (out start, out end)) {
                return source_buffer.get_text (start, end, false);
            }
            return "";
        }

        public void insert_ai_code_at_cursor (string code) {
            string cleaned = code.strip ();
            source_buffer.begin_user_action ();
            Gtk.TextIter start, end;
            if (source_buffer.get_selection_bounds (out start, out end)) {
                source_buffer.delete (ref start, ref end);
                source_buffer.insert (ref start, cleaned, -1);
            } else {
                source_buffer.insert_at_cursor ("\n" + cleaned + "\n", -1);
            }
            source_buffer.end_user_action ();
        }

        public void insert_media_snippet (string snippet) {
            source_buffer.begin_user_action ();
            Gtk.TextIter start, end;
            if (source_buffer.get_selection_bounds (out start, out end)) {
                source_buffer.delete (ref start, ref end);
                source_buffer.insert (ref start, snippet, -1);
            } else {
                source_buffer.insert_at_cursor (snippet, -1);
            }
            source_buffer.end_user_action ();
            refresh_live_preview ();
        }

        public void show_inline_prompt_popover () {
            Gtk.TextIter cursor_iter;
            source_buffer.get_iter_at_mark (out cursor_iter, source_buffer.get_insert ());
            Gdk.Rectangle rect;
            source_view.get_iter_location (cursor_iter, out rect);

            int win_x, win_y;
            source_view.buffer_to_window_coords (Gtk.TextWindowType.WIDGET, rect.x, rect.y, out win_x, out win_y);
            var pointing_rect = Gdk.Rectangle () {
                x = win_x,
                y = win_y,
                width = 1,
                height = rect.height
            };

            var popover = new Gtk.Popover ();
            popover.set_parent (source_view);
            popover.set_pointing_to (pointing_rect);
            popover.has_arrow = true;
            popover.autohide = true;

            var content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 8) {
                margin_top = 8,
                margin_bottom = 8,
                margin_start = 8,
                margin_end = 8,
                width_request = 380
            };

            var header_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
            var icon = new Gtk.Image.from_icon_name ("ai-elrond") { pixel_size = 20 };
            var title_lbl = new Gtk.Label ("Write with Elrond Assistance (AI)") {
                css_classes = { "heading" },
                hexpand = true,
                xalign = 0.0f
            };
            header_box.append (icon);
            header_box.append (title_lbl);
            content_box.append (header_box);

            var prompt_entry = new Gtk.Entry () {
                placeholder_text = "Prompt Elrond (e.g. plot scatter, clean dataframe, linear model)...",
                hexpand = true
            };
            content_box.append (prompt_entry);

            var actions_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
                halign = Gtk.Align.END
            };
            var spinner = new Adw.Spinner () { visible = false };
            var btn_generate = new Gtk.Button.with_label ("Generate & Insert") {
                css_classes = { "suggested-action" }
            };

            actions_box.append (spinner);
            actions_box.append (btn_generate);
            content_box.append (actions_box);

            SourceFunc execute_generation = () => {
                string prompt = prompt_entry.text.strip ();
                if (prompt.length == 0) return Source.REMOVE;

                prompt_entry.sensitive = false;
                btn_generate.sensitive = false;
                spinner.visible = true;

                string sel = get_selected_text ();
                string doc_lang = this.doc_type;
                string doc_text = source_buffer.text;

                var elrond = Imladris.AI.ElrondEngineController.get_default ();
                if (elrond.is_ready) {
                    elrond.write_with_elrond.begin (doc_lang, doc_text, "", prompt + (sel.length > 0 ? "\n[Selected Code]:\n" + sel : ""), (obj, res) => {
                        spinner.visible = false;
                        popover.popdown ();
                        try {
                            string generated = elrond.write_with_elrond.end (res);
                            insert_ai_code_at_cursor (generated);
                        } catch (Error e) {
                            warning ("Elrond inline generation error: %s", e.message);
                        }
                    });
                } else {
                    var ai_client = new AiClient ();
                    string sys_prompt = "You are Elrond Assistance (AI), an expert scientific and coding assistant. Generate clean, correct code or statistical functions. Return only the code or visualization chunk.";
                    ai_client.send_chat_completion_async.begin (sys_prompt, prompt + (sel.length > 0 ? "\n[Selected Code]:\n" + sel : ""), null, (obj, res) => {
                        spinner.visible = false;
                        popover.popdown ();
                        try {
                            string generated = ai_client.send_chat_completion_async.end (res);
                            insert_ai_code_at_cursor (generated);
                        } catch (Error e) {
                            warning ("AI client inline generation error: %s", e.message);
                        }
                    });
                }
                return Source.REMOVE;
            };

            prompt_entry.activate.connect (() => {
                execute_generation ();
            });
            btn_generate.clicked.connect (() => {
                execute_generation ();
            });

            popover.set_child (content_box);
            popover.popup ();
            prompt_entry.grab_focus ();
        }

        public void apply_tag_or_syntax (string tag_name, string md_wrapper) {
            Gtk.TextIter start, end;
            if (source_buffer.get_selection_bounds (out start, out end)) {
                source_buffer.apply_tag_by_name (tag_name, start, end);
            } else {
                source_buffer.insert_at_cursor (@"$md_wrapper$md_wrapper", -1);
            }
        }

        public void insert_code_chunk (string engine, string options = "") {
            string opt_line = options.length > 0 ? @"#| $options\n" : "";
            string snippet = @"\n```{$engine}\n$opt_line\n```\n";
            source_buffer.insert_at_cursor (snippet, -1);
        }

        public void insert_markdown_table (int rows, int cols) {
            var sb = new GLib.StringBuilder ("\n|");
            for (int c = 1; c <= cols; c++) sb.append (@" Header $c |");
            sb.append ("\n|");
            for (int c = 1; c <= cols; c++) sb.append (" --- |");
            for (int r = 1; r <= rows; r++) {
                sb.append ("\n|");
                for (int c = 1; c <= cols; c++) sb.append (" Cell |");
            }
            sb.append ("\n");
            source_buffer.insert_at_cursor (sb.str, -1);
        }

        public void append_console_log (string text) {
            if (current_layout_mode == Services.LayoutMode.RSTUDIO) {
                dock_layout_state.activate_tab (QuadrantId.Q2_BOTTOM_LEFT, PanelId.CONSOLE);
            }
            Gtk.TextIter end;
            console_view.buffer.get_end_iter (out end);
            console_view.buffer.insert (ref end, text + "\n", -1);
        }

        public void emit_buffer_stats () {
            string txt = source_buffer.text.strip ();
            int words = txt.length == 0 ? 0 : txt.split_set (" \n\t\r").length;
            int lines = source_buffer.get_line_count ();
            stats_changed (words, lines, doc_type.up ());
        }

        public void undo () {
            if (source_buffer.can_undo) {
                source_buffer.undo ();
            }
        }

        public void redo () {
            if (source_buffer.can_redo) {
                source_buffer.redo ();
            }
        }

        public void set_zoom (int percent) {
            web_view.zoom_level = (double) percent / 100.0;
        }

        public void apply_heading (int level) {
            if (level <= 0) return;
            string prefix = string.nfill (level, '#') + " ";
            Gtk.TextIter insert_iter;
            source_buffer.get_iter_at_mark (out insert_iter, source_buffer.get_insert ());
            insert_iter.set_line_offset (0);
            source_buffer.insert (ref insert_iter, prefix, -1);
        }

        public void insert_list_item (string prefix) {
            Gtk.TextIter insert_iter;
            source_buffer.get_iter_at_mark (out insert_iter, source_buffer.get_insert ());
            insert_iter.set_line_offset (0);
            source_buffer.insert (ref insert_iter, prefix, -1);
        }
    }
}
