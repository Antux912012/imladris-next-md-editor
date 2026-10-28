namespace Imladris.Core {

    public class FrontmatterData : GLib.Object {
        public string? title { get; set; default = null; }
        public string? author { get; set; default = null; }
        public string? date { get; set; default = null; }
        public string? bibliography { get; set; default = null; }
        public string? format_type { get; set; default = null; }
        public string? output { get; set; default = null; }
        public string? abstract_text { get; set; default = null; }

        public bool is_empty () {
            return title == null && author == null && date == null &&
                   bibliography == null && format_type == null &&
                   output == null && abstract_text == null;
        }

        public string to_html () {
            if (is_empty ()) {
                return "";
            }

            var builder = new StringBuilder ();
            builder.append ("<header class=\"document-frontmatter-card\">\n");

            if (title != null && title.strip () != "") {
                builder.append_printf ("  <h1 class=\"frontmatter-title\">%s</h1>\n", GLib.Markup.escape_text (title));
            }

            builder.append ("  <div class=\"frontmatter-meta-grid\">\n");

            if (author != null && author.strip () != "") {
                builder.append_printf (
                    "    <div class=\"frontmatter-meta-item\"><span class=\"frontmatter-label\">Author</span><span class=\"frontmatter-value\">%s</span></div>\n",
                    GLib.Markup.escape_text (author)
                );
            }

            if (date != null && date.strip () != "") {
                builder.append_printf (
                    "    <div class=\"frontmatter-meta-item\"><span class=\"frontmatter-label\">Date</span><span class=\"frontmatter-value\">%s</span></div>\n",
                    GLib.Markup.escape_text (date)
                );
            }

            if (bibliography != null && bibliography.strip () != "") {
                builder.append_printf (
                    "    <div class=\"frontmatter-meta-item\"><span class=\"frontmatter-label\">Bibliography</span><span class=\"frontmatter-value\"><code>%s</code></span></div>\n",
                    GLib.Markup.escape_text (bibliography)
                );
            }

            string? fmt = format_type ?? output;
            if (fmt != null && fmt.strip () != "") {
                builder.append_printf (
                    "    <div class=\"frontmatter-meta-item\"><span class=\"frontmatter-label\">Format</span><span class=\"frontmatter-badge\">%s</span></div>\n",
                    GLib.Markup.escape_text (fmt)
                );
            }

            builder.append ("  </div>\n");

            if (abstract_text != null && abstract_text.strip () != "") {
                builder.append_printf (
                    "  <div class=\"frontmatter-abstract\"><strong>Abstract:</strong> %s</div>\n",
                    GLib.Markup.escape_text (abstract_text)
                );
            }

            builder.append ("</header>\n");
            return builder.str;
        }
    }

    public class FrontmatterParser : GLib.Object {

        public static void split_frontmatter (string content, out FrontmatterData? data, out string markdown_body) {
            data = null;
            markdown_body = content;

            int first_delim = -1;
            int len = content.length;
            for (int i = 0; i < len; i++) {
                char c = content[i];
                if (c == ' ' || c == '\t' || c == '\r' || c == '\n') continue;
                if (c == '-' && i + 2 < len && content[i+1] == '-' && content[i+2] == '-') {
                    first_delim = i;
                }
                break;
            }
            if (first_delim == -1) {
                return;
            }

            int search_start = first_delim + 3;

            int second_delim = content.index_of ("\n---", search_start);
            int delim_len = 4;
            if (second_delim == -1) {
                second_delim = content.index_of ("\r\n---", search_start);
                delim_len = 5;
            }
            if (second_delim == -1) {
                second_delim = content.index_of ("\n...", search_start);
                delim_len = 4;
            }

            if (second_delim == -1) {
                return;
            }

            string yaml_block = content.substring (search_start, second_delim - search_start);
            int body_start = second_delim + delim_len;
            if (body_start < content.length && content[body_start] == '\n') {
                body_start++;
            } else if (body_start < content.length && content[body_start] == '\r' && body_start + 1 < content.length && content[body_start + 1] == '\n') {
                body_start += 2;
            }

            markdown_body = content.substring (body_start);
            data = parse_yaml_block (yaml_block);
        }

        private static FrontmatterData parse_yaml_block (string yaml) {
            var meta = new FrontmatterData ();
            string[] lines = yaml.split ("\n");

            foreach (var raw_line in lines) {
                string line = raw_line.strip ();
                if (line.has_prefix ("#") || line == "") {
                    continue;
                }

                int colon_idx = line.index_of (":");
                if (colon_idx == -1) {
                    continue;
                }

                string key = line.substring (0, colon_idx).strip ().down ();
                string val = clean_val (line.substring (colon_idx + 1).strip ());

                switch (key) {
                    case "title":
                        meta.title = val;
                        break;
                    case "author":
                        meta.author = val;
                        break;
                    case "date":
                        meta.date = val;
                        break;
                    case "bibliography":
                        meta.bibliography = val;
                        break;
                    case "format":
                        meta.format_type = val;
                        break;
                    case "output":
                        meta.output = val;
                        break;
                    case "abstract":
                        meta.abstract_text = val;
                        break;
                }
            }
            return meta;
        }

        private static string clean_val (string val) {
            string cleaned = val;
            if ((cleaned.has_prefix ("\"") && cleaned.has_suffix ("\"")) ||
                (cleaned.has_prefix ("'") && cleaned.has_suffix ("'"))) {
                cleaned = cleaned.substring (1, cleaned.length - 2);
            }
            return cleaned.strip ();
        }
    }
}
