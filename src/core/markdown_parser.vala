namespace Imladris {
    public class MarkdownParser : GLib.Object {
        private static MarkdownParser? instance = null;

        public static MarkdownParser get_default () {
            if (instance == null) {
                instance = new MarkdownParser ();
            }
            return instance;
        }

        public MarkdownParser () {
            Object ();
        }

        construct {
        }

        public async string render_html_async (string markdown_text, bool include_sourcepos = true) throws GLib.Error {
            SourceFunc callback = render_html_async.callback;
            string rendered_html = "";
            GLib.Error? background_error = null;

            new Thread<void*> ("cmark-worker", () => {
                Imladris.Core.FrontmatterData? meta;
                string markdown_body;
                Imladris.Core.FrontmatterParser.split_frontmatter (markdown_text, out meta, out markdown_body);

                int options = CMark.OPT_VALIDATE_UTF8;
                if (include_sourcepos) {
                    options |= CMark.OPT_SOURCEPOS;
                }
                string cmark_html = CMark.markdown_to_html (markdown_body, markdown_body.length, options);
                string header_html = (meta != null) ? meta.to_html () : "";
                rendered_html = header_html + cmark_html;

                Idle.add ((owned) callback);
                return null;
            });

            yield;

            if (background_error != null) {
                throw background_error;
            }

            return rendered_html;
        }

        public string render_html_sync (string markdown_text, bool include_sourcepos = true) {
            Imladris.Core.FrontmatterData? meta;
            string markdown_body;
            Imladris.Core.FrontmatterParser.split_frontmatter (markdown_text, out meta, out markdown_body);

            int options = CMark.OPT_VALIDATE_UTF8;
            if (include_sourcepos) {
                options |= CMark.OPT_SOURCEPOS;
            }
            string cmark_html = CMark.markdown_to_html (markdown_body, markdown_body.length, options);
            string header_html = (meta != null) ? meta.to_html () : "";
            return header_html + cmark_html;
        }

        public CMark.Node parse_to_ast (string markdown_text, int options = CMark.OPT_DEFAULT) {
            Imladris.Core.FrontmatterData? meta;
            string markdown_body;
            Imladris.Core.FrontmatterParser.split_frontmatter (markdown_text, out meta, out markdown_body);

            var parser = new CMark.Parser (options);
            parser.feed (markdown_body, markdown_body.length);
            return parser.finish ();
        }
    }
}
