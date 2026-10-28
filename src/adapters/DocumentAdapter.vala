namespace Imladris.Adapters {

    public class DocumentAdapter : GLib.Object {

        private static GLib.Regex? chunk_regex = null;

        public static Imladris.DocumentFormat detect_format (string? filename) {
            if (filename == null || filename == "") return Imladris.DocumentFormat.MD;
            return Imladris.DocumentFormat.from_filename (filename);
        }

        public static string load_to_editor_buffer (string raw_content, Imladris.DocumentFormat format) {
            if (format == Imladris.DocumentFormat.IPYNB) {
                try {
                    return Core.NotebookSerializer.ipynb_to_markdown (raw_content);
                } catch (GLib.Error e) {
                    GLib.warning ("Failed to deserialize .ipynb JSON: %s", e.message);
                    return raw_content;
                }
            }
            return raw_content;
        }

        public static string save_from_editor_buffer (string editor_text, Imladris.DocumentFormat format, string? existing_raw_file = null) {
            if (format == Imladris.DocumentFormat.IPYNB) {
                try {
                    return Core.NotebookSerializer.markdown_to_ipynb (editor_text, existing_raw_file ?? "python");
                } catch (GLib.Error e) {
                    GLib.warning ("Failed to serialize editor buffer to .ipynb JSON: %s", e.message);
                    return editor_text;
                }
            }
            return editor_text;
        }

        public static string render_html (string editor_text, Imladris.DocumentFormat format) {
            Core.FrontmatterData? meta;
            string body;
            Core.FrontmatterParser.split_frontmatter (editor_text, out meta, out body);

            var builder = new StringBuilder ();
            if (meta != null && !meta.is_empty ()) {
                builder.append (meta.to_html ());
            }

            // Convert Code chunk annotations ```{r} or ```{python} to styled blocks
            string processed_body = transform_code_chunks (body);
            processed_body = transform_media_tags (processed_body);
            builder.append (basic_markdown_to_html (processed_body));

            return builder.str;
        }

        private static GLib.Regex? img_regex = null;
        private static GLib.Regex? video_regex = null;

        private static string transform_media_tags (string text) {
            string result = text;
            try {
                // Quarto video shortcodes: {{< video path >}}
                if (video_regex == null) {
                    video_regex = new GLib.Regex ("\\{\\{<\\s*video\\s+([^\\s>]+)[^>]*>\\}\\}");
                }
                result = video_regex.replace_eval (result, -1, 0, 0, (match_info, res) => {
                    string vpath = match_info.fetch (1);
                    res.append_printf ("<div class=\"media-video-container\" style=\"margin: 16px 0; text-align: center;\"><video src=\"%s\" controls style=\"max-width: 100%%; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.1);\"></video></div>", vpath);
                    return false;
                });

                // Markdown images: ![caption](path)
                if (img_regex == null) {
                    img_regex = new GLib.Regex ("!\\[([^\\]]*)\\]\\(([^\\)]+)\\)");
                }
                result = img_regex.replace_eval (result, -1, 0, 0, (match_info, res) => {
                    string alt = match_info.fetch (1);
                    string ipath = match_info.fetch (2);
                    res.append_printf ("<figure style=\"margin: 16px 0; text-align: center;\"><img src=\"%s\" alt=\"%s\" style=\"max-width: 100%%; height: auto; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.1);\"/>", ipath, GLib.Markup.escape_text (alt));
                    if (alt.strip ().length > 0) {
                        res.append_printf ("<figcaption style=\"font-size: 0.9em; color: #64748b; margin-top: 6px;\">%s</figcaption>", GLib.Markup.escape_text (alt));
                    }
                    res.append ("</figure>");
                    return false;
                });
            } catch (GLib.RegexError e) {}
            return result;
        }

        private static string transform_code_chunks (string text) {
            try {
                if (chunk_regex == null) {
                    chunk_regex = new GLib.Regex ("```\\{([a-zA-Z0-9_-]+)([^\\}]*)\\}([\\s\\S]*?)```");
                }
                return chunk_regex.replace_eval (text, -1, 0, 0, (match_info, result) => {
                    string lang = match_info.fetch (1);
                    string opts = match_info.fetch (2).strip ();
                    string code = match_info.fetch (3);

                    result.append ("<div class=\"code-chunk-card\">\n");
                    result.append_printf ("  <div class=\"code-chunk-header\"><span class=\"badge\">%s</span>", GLib.Markup.escape_text (lang.up ()));
                    if (opts != "") {
                        result.append_printf (" <span class=\"chunk-opts\">%s</span>", GLib.Markup.escape_text (opts));
                    }
                    result.append ("</div>\n");
                    result.append_printf ("  <pre><code class=\"language-%s\">%s</code></pre>\n", lang, GLib.Markup.escape_text (code));
                    result.append ("</div>\n");
                    return false;
                });
            } catch (GLib.RegexError e) {
                return text;
            }
        }

        private static string basic_markdown_to_html (string text) {
            var lines = text.split ("\n");
            var res = new StringBuilder ();
            bool in_pre = false;
            bool in_ul = false;

            foreach (var line in lines) {
                if (line.has_prefix ("<div class=\"code-chunk-card\"") || line.has_prefix ("</div>") || line.has_prefix ("<header") ||
                    line.has_prefix ("<figure") || line.has_prefix ("</figure>") || line.has_prefix ("<div class=\"media-video-container\"") ||
                    line.has_prefix ("<video") || line.has_prefix ("</video>")) {
                    res.append (line);
                    res.append ("\n");
                    continue;
                }

                if (line.has_prefix ("```")) {
                    if (!in_pre) {
                        string lang = line.substring (3).strip ();
                        res.append_printf ("<pre><code class=\"language-%s\">", lang != "" ? lang : "text");
                        in_pre = true;
                    } else {
                        res.append ("</code></pre>\n");
                        in_pre = false;
                    }
                    continue;
                }

                if (in_pre) {
                    res.append (GLib.Markup.escape_text (line));
                    res.append ("\n");
                    continue;
                }

                if (line.has_prefix ("### ")) {
                    res.append_printf ("<h3>%s</h3>\n", GLib.Markup.escape_text (line.substring (4)));
                } else if (line.has_prefix ("## ")) {
                    res.append_printf ("<h2>%s</h2>\n", GLib.Markup.escape_text (line.substring (3)));
                } else if (line.has_prefix ("# ")) {
                    res.append_printf ("<h1>%s</h1>\n", GLib.Markup.escape_text (line.substring (2)));
                } else if (line.has_prefix ("- ") || line.has_prefix ("* ")) {
                    if (!in_ul) {
                        res.append ("<ul>\n");
                        in_ul = true;
                    }
                    res.append_printf ("  <li>%s</li>\n", GLib.Markup.escape_text (line.substring (2)));
                } else {
                    if (in_ul) {
                        res.append ("</ul>\n");
                        in_ul = false;
                    }
                    string trimmed = line.strip ();
                    if (trimmed == "") {
                        res.append ("\n");
                    } else {
                        res.append_printf ("<p>%s</p>\n", GLib.Markup.escape_text (line));
                    }
                }
            }

            if (in_ul) res.append ("</ul>\n");
            if (in_pre) res.append ("</code></pre>\n");

            return res.str;
        }
    }
}
