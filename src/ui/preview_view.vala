namespace Imladris {
    public class PreviewView : Gtk.Box {
        public WebKit.WebView web_view { get; private set; }
        private string current_html_body = "";

        public PreviewView () {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 0);
        }

        construct {
            hexpand = true;
            vexpand = true;
            add_css_class ("imladris-preview-box");

            web_view = new WebKit.WebView ();
            web_view.hexpand = true;
            web_view.vexpand = true;

            var settings = web_view.get_settings ();
            settings.enable_javascript = true;
            settings.enable_developer_extras = true;

            append (web_view);

            Adw.StyleManager.get_default ().notify["dark"].connect (() => {
                if (current_html_body.length > 0) {
                    update_html (current_html_body);
                }
            });
        }

        public void update_html (string html_body) {
            current_html_body = html_body;
            bool is_dark = Adw.StyleManager.get_default ().dark;
            string mode_class = is_dark ? "dark-mode" : "light-mode";

            string full_document = """<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
:root {
    --bg-color: #ffffff;
    --text-color: #2e3436;
    --link-color: #1c71d8;
    --border-color: #deddda;
    --code-bg: #f6f8fa;
    --quote-border: #3584e4;
    --table-stripe: #f8f9fa;
}

body.dark-mode {
    --bg-color: #242424;
    --text-color: #ffffff;
    --link-color: #78aeed;
    --border-color: #383838;
    --code-bg: #2d2d2d;
    --quote-border: #78aeed;
    --table-stripe: #1e1e1e;
}

body.light-mode {
    --bg-color: #ffffff;
    --text-color: #2e3436;
    --link-color: #1c71d8;
    --border-color: #deddda;
    --code-bg: #f6f8fa;
    --quote-border: #3584e4;
    --table-stripe: #f8f9fa;
}

body {
    font-family: -apple-system, BlinkMacSystemFont, "Cantarell", "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    font-size: 16px;
    line-height: 1.6;
    color: var(--text-color);
    background-color: var(--bg-color);
    padding: 24px 32px;
    margin: 0 auto;
    max-width: 860px;
    box-sizing: border-box;
    transition: background-color 0.15s, color 0.15s;
}

h1, h2, h3, h4, h5, h6 {
    margin-top: 24px;
    margin-bottom: 16px;
    font-weight: 700;
    line-height: 1.25;
}

h1 { font-size: 2em; border-bottom: 1px solid var(--border-color); padding-bottom: 0.3em; }
h2 { font-size: 1.5em; border-bottom: 1px solid var(--border-color); padding-bottom: 0.3em; }
h3 { font-size: 1.25em; }

p, ul, ol, dl, table, pre, blockquote {
    margin-top: 0;
    margin-bottom: 16px;
}

a {
    color: var(--link-color);
    text-decoration: none;
}
a:hover {
    text-decoration: underline;
}

code {
    font-family: "Source Code Pro", "Cascadia Code", "Fira Code", monospace;
    font-size: 85%;
    padding: 0.2em 0.4em;
    margin: 0;
    background-color: var(--code-bg);
    border-radius: 6px;
}

pre {
    padding: 16px;
    overflow: auto;
    font-size: 85%;
    line-height: 1.45;
    background-color: var(--code-bg);
    border-radius: 8px;
    border: 1px solid var(--border-color);
}

pre code {
    padding: 0;
    background-color: transparent;
    font-size: 100%;
}

blockquote {
    padding: 0 1em;
    color: var(--text-color);
    border-left: 4px solid var(--quote-border);
    opacity: 0.85;
}

table {
    border-collapse: collapse;
    width: 100%;
    margin-bottom: 16px;
}

table th, table td {
    padding: 8px 12px;
    border: 1px solid var(--border-color);
}

table tr:nth-child(even) {
    background-color: var(--table-stripe);
}

hr {
    height: 2px;
    padding: 0;
    margin: 24px 0;
    background-color: var(--border-color);
    border: 0;
}

img {
    max-width: 100%;
    box-sizing: border-box;
    border-radius: 6px;
}

input[type="checkbox"] {
    margin-right: 0.5em;
}
</style>
<script>
window.scrollToLine = function(targetLine) {
    const elements = document.querySelectorAll('[data-sourcepos]');
    if (!elements || elements.length === 0) return;
    let closestElem = null;
    let minDiff = 999999;

    for (let i = 0; i < elements.length; i++) {
        const pos = elements[i].getAttribute('data-sourcepos');
        if (!pos) continue;
        const parts = pos.split(':');
        if (parts.length > 0) {
            const startLine = parseInt(parts[0], 10);
            if (!isNaN(startLine)) {
                const diff = Math.abs(startLine - targetLine);
                if (diff < minDiff) {
                    minDiff = diff;
                    closestElem = elements[i];
                }
                if (startLine === targetLine) {
                    closestElem = elements[i];
                    break;
                }
            }
        }
    }

    if (closestElem) {
        closestElem.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
    }
};
</script>
</head>
<body class="THEME_MODE_CLASS">
DOCUMENT_HTML_BODY
</body>
</html>""".replace ("THEME_MODE_CLASS", mode_class).replace ("DOCUMENT_HTML_BODY", html_body);

            web_view.load_html (full_document, "file:///");
        }

        public void scroll_to_line (int line) {
            string script = "if (window.scrollToLine) { window.scrollToLine(%d); }".printf (line);
            web_view.evaluate_javascript.begin (
                script,
                (ssize_t) script.length,
                null,
                null,
                null,
                (obj, res) => {
                    try {
                        web_view.evaluate_javascript.end (res);
                    } catch (Error e) {
                        // Ignore JS evaluation errors during fast typing
                    }
                }
            );
        }
    }
}
