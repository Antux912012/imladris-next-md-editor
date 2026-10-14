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
                int options = CMark.OPT_VALIDATE_UTF8;
                if (include_sourcepos) {
                    options |= CMark.OPT_SOURCEPOS;
                }
                rendered_html = CMark.markdown_to_html (markdown_text, markdown_text.length, options);

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
            int options = CMark.OPT_VALIDATE_UTF8;
            if (include_sourcepos) {
                options |= CMark.OPT_SOURCEPOS;
            }
            return CMark.markdown_to_html (markdown_text, markdown_text.length, options);
        }

        public CMark.Node parse_to_ast (string markdown_text, int options = CMark.OPT_DEFAULT) {
            var parser = new CMark.Parser (options);
            parser.feed (markdown_text, markdown_text.length);
            return parser.finish ();
        }
    }
}
