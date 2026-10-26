namespace Imladris.Core {

    public class CodeChunk : GLib.Object {
        public int start_line { get; set; }
        public int end_line { get; set; }
        public string language { get; set; }
        public string code { get; set; }
        public string header { get; set; }

        public CodeChunk (int start_line, int end_line, string language, string code, string header = "") {
            this.start_line = start_line;
            this.end_line = end_line;
            this.language = language;
            this.code = code;
            this.header = header;
        }
    }

    /**
     * Pillar 11: Scans .Rmd, .Qmd, and .ipynb buffers for code chunk blocks.
     */
    public class ChunkParser : GLib.Object {

        public static Gee.ArrayList<CodeChunk> parse_chunks (string buffer_text) {
            var list = new Gee.ArrayList<CodeChunk> ();
            string[] lines = buffer_text.split ("\n");

            bool inside_chunk = false;
            int start_line = -1;
            string language = "r";
            string header = "";
            var code_sb = new GLib.StringBuilder ();

            for (int i = 0; i < lines.length; i++) {
                string trimmed = lines[i].strip ();

                if (!inside_chunk && (trimmed.has_prefix ("```{") || trimmed.has_prefix ("```r") || trimmed.has_prefix ("```python") || trimmed.has_prefix ("```bash"))) {
                    inside_chunk = true;
                    start_line = i;
                    header = trimmed;
                    code_sb.truncate (0);
                    if (trimmed.contains ("r}") || trimmed.has_prefix ("```r")) language = "r";
                    else if (trimmed.contains ("bash") || trimmed.contains ("sh}")) language = "bash";
                    else language = "python";
                    continue;
                }

                if (inside_chunk && trimmed == "```") {
                    inside_chunk = false;
                    list.add (new CodeChunk (start_line, i, language, code_sb.str.strip (), header));
                    continue;
                }

                if (inside_chunk) {
                    if (!trimmed.has_prefix ("#|")) {
                        code_sb.append (lines[i] + "\n");
                    }
                }
            }

            return list;
        }

        public static CodeChunk? find_chunk_at_line (string buffer_text, int line_num) {
            var chunks = parse_chunks (buffer_text);
            foreach (var ch in chunks) {
                if (line_num >= ch.start_line && line_num <= ch.end_line) {
                    return ch;
                }
            }
            return null;
        }
    }
}
