namespace Imladris {

    public class DocumentPage : Gtk.Box {

        public GtkSource.View source_view { get; private set; }
        public GtkSource.Buffer source_buffer { get; private set; }
        public Gtk.TextView console_view { get; private set; }
        public WebKit.WebView web_view { get; private set; }
        public Gtk.Stack right_stack { get; private set; }
        public Gtk.Revealer console_revealer { get; private set; }
        public string doc_type { get; private set; }

        public signal void stats_changed (int words, int lines, string lang_badge);

        public DocumentPage (string title, string lang_id) {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 0);
            this.doc_type = lang_id;

            var paned = new Gtk.Paned (Gtk.Orientation.HORIZONTAL) {
                hexpand = true,
                vexpand = true,
                position = 780
            };

            // 1. Setup GtkSource.Buffer with Syntax Highlighting + Rich TextTags
            var lang_manager = GtkSource.LanguageManager.get_default ();
            var language = lang_manager.get_language (lang_id == "rmd" ? "markdown" : lang_id);
            source_buffer = new GtkSource.Buffer.with_language (language);
            source_buffer.highlight_syntax = true;

            var scheme_manager = GtkSource.StyleSchemeManager.get_default ();
            var scheme = scheme_manager.get_scheme ("Adwaita");
            if (scheme != null) {
                source_buffer.style_scheme = scheme;
            }

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

            var editor_scroller = new Gtk.ScrolledWindow () {
                child = source_view,
                hexpand = true,
                vexpand = true
            };
            paned.set_start_child (editor_scroller);

            // 2. Setup Collapsible Right Split Pane (WebKit.WebView + Console Stack)
            console_revealer = new Gtk.Revealer () {
                transition_type = Gtk.RevealerTransitionType.SLIDE_LEFT,
                reveal_child = true
            };

            var right_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
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

            var refresh_btn = new Gtk.Button.from_icon_name ("view-refresh-symbolic") {
                tooltip_text = "Refresh WebKit Live Preview"
            };
            refresh_btn.add_css_class ("flat");
            refresh_btn.clicked.connect (() => {
                refresh_live_preview ();
            });
            right_header.append (refresh_btn);

            right_box.append (right_header);

            // Page 1: Embedded WebKitGTK 6.0 Live View
            web_view = new WebKit.WebView () {
                hexpand = true,
                vexpand = true
            };
            var settings = web_view.get_settings ();
            settings.enable_developer_extras = true;
            settings.enable_javascript = true;
            right_stack.add_titled (web_view, "preview", "Live Preview");

            // Page 2: Execution & Render Output Console
            console_view = new Gtk.TextView () {
                editable = false,
                monospace = true,
                wrap_mode = Gtk.WrapMode.WORD_CHAR,
                top_margin = 12,
                bottom_margin = 12,
                left_margin = 12,
                right_margin = 12
            };
            var console_scroller = new Gtk.ScrolledWindow () {
                child = console_view,
                hexpand = true,
                vexpand = true
            };
            right_stack.add_titled (console_scroller, "console", "Console Log");

            right_box.append (right_stack);
            console_revealer.set_child (right_box);
            paned.set_end_child (console_revealer);

            this.append (paned);

            refresh_live_preview ();

            source_buffer.changed.connect (() => {
                emit_buffer_stats ();
                refresh_live_preview ();
            });
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

        public void refresh_live_preview () {
            string raw = source_buffer.text;
            if (doc_type == "html") {
                web_view.load_html (raw, "file:///");
                return;
            }

            string escaped = GLib.Markup.escape_text (raw);
            string html = """<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  body {
    font-family: 'Inter', 'Cantarell', system-ui, -apple-system, sans-serif;
    line-height: 1.6;
    color: #1e242b;
    background: #ffffff;
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
  pre {
    background: #f6f8fa;
    border: 1px solid #d0d7de;
    border-radius: 6px;
    padding: 14px;
    overflow-x: auto;
    font-family: 'JetBrains Mono', monospace;
    font-size: 13px;
    white-space: pre-wrap;
  }
</style>
</head>
<body>
  <div class="badge">WebKitGTK 6.0 Live Preview • %s</div>
  <div id="content"><pre>%s</pre></div>
  <script>
    (function() {
      const raw = document.querySelector('#content pre').textContent;
      let html = raw
        .replace(/^---\n([\s\S]*?)\n---/m, '<pre style="background:#eef6ff;border-color:#b6d4fe;">$1</pre>')
        .replace(/```\{(\w+)\}\n([\s\S]*?)```/g, '<pre><strong>[$1 chunk]</strong>\n$2</pre>')
        .replace(/^### (.*$)/gm, '<h3>$1</h3>')
        .replace(/^## (.*$)/gm, '<h2>$1</h2>')
        .replace(/^# (.*$)/gm, '<h1>$1</h1>')
        .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
        .replace(/\*(.*?)\*/g, '<em>$1</em>');
      document.getElementById('content').innerHTML = html;
    })();
  </script>
</body>
</html>""".printf (doc_type.up (), escaped);

            web_view.load_html (html, "file:///");
        }

        public void show_live_preview (string? uri = null) {
            console_revealer.reveal_child = true;
            right_stack.visible_child_name = "preview";
            if (uri != null) {
                web_view.load_uri (uri);
            } else {
                refresh_live_preview ();
            }
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
            console_revealer.reveal_child = true;
            right_stack.visible_child_name = "console";
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
    }
}
