namespace Imladris.Core {
    public class NotebookCell : GLib.Object {
        public string cell_type { get; set; default = "code"; }
        public string language { get; set; default = "python"; }
        public string source { get; set; default = ""; }

        public NotebookCell (string cell_type, string source, string language = "python") {
            Object (cell_type: cell_type, source: source, language: language);
        }
    }

    public class NotebookSerializer : GLib.Object {

        public static string ipynb_to_markdown (string json_content) throws GLib.Error {
            var parser = new Json.Parser ();
            parser.load_from_data (json_content);

            var root_node = parser.get_root ();
            if (root_node == null || root_node.get_node_type () != Json.NodeType.OBJECT) {
                return "";
            }

            var root = root_node.get_object ();
            if (!root.has_member ("cells")) {
                return "";
            }

            string default_lang = "python";
            if (root.has_member ("metadata")) {
                var meta = root.get_object_member ("metadata");
                if (meta.has_member ("kernelspec")) {
                    var ks = meta.get_object_member ("kernelspec");
                    if (ks.has_member ("language")) {
                        default_lang = ks.get_string_member ("language").down ();
                    }
                } else if (meta.has_member ("language_info")) {
                    var li = meta.get_object_member ("language_info");
                    if (li.has_member ("name")) {
                        default_lang = li.get_string_member ("name").down ();
                    }
                }
            }
            if (default_lang == "" || default_lang == null) {
                default_lang = "python";
            }

            var cells = root.get_array_member ("cells");
            var builder = new StringBuilder ();

            for (uint i = 0; i < cells.get_length (); i++) {
                var cell = cells.get_object_element (i);
                string cell_type = cell.has_member ("cell_type") ? cell.get_string_member ("cell_type") : "markdown";

                var cell_text = new StringBuilder ();
                if (cell.has_member ("source")) {
                    var source_node = cell.get_member ("source");
                    if (source_node.get_node_type () == Json.NodeType.ARRAY) {
                        var source_arr = source_node.get_array ();
                        for (uint j = 0; j < source_arr.get_length (); j++) {
                            cell_text.append (source_arr.get_string_element (j));
                        }
                    } else if (source_node.get_node_type () == Json.NodeType.VALUE) {
                        cell_text.append (source_node.get_string ());
                    }
                }

                string text = cell_text.str;

                if (cell_type == "markdown") {
                    builder.append (text);
                    if (!text.has_suffix ("\n")) {
                        builder.append ("\n");
                    }
                    builder.append ("\n");
                } else if (cell_type == "code") {
                    builder.append ("```{");
                    builder.append (default_lang);
                    builder.append ("}\n");
                    builder.append (text);
                    if (!text.has_suffix ("\n")) {
                        builder.append ("\n");
                    }
                    builder.append ("```\n\n");
                } else if (cell_type == "raw") {
                    builder.append ("```raw\n");
                    builder.append (text);
                    if (!text.has_suffix ("\n")) {
                        builder.append ("\n");
                    }
                    builder.append ("```\n\n");
                }
            }

            return builder.str;
        }

        public static string markdown_to_ipynb (string markdown_content, string default_lang = "python") throws GLib.Error {
            var builder = new Json.Builder ();
            builder.begin_object ();

            builder.set_member_name ("cells");
            builder.begin_array ();

            string[] lines = markdown_content.split ("\n");
            bool in_code_chunk = false;
            string current_chunk_lang = default_lang;
            var current_source = new StringBuilder ();

            for (int i = 0; i < lines.length; i++) {
                string line = lines[i];
                string trimmed = line.strip ();

                if (!in_code_chunk && trimmed.has_prefix ("```")) {
                    if (current_source.len > 0) {
                        add_cell_to_builder (builder, "markdown", current_source.str);
                        current_source.truncate ();
                    }

                    in_code_chunk = true;
                    string tag = trimmed.substring (3).strip ();
                    if (tag.has_prefix ("{") && tag.has_suffix ("}")) {
                        current_chunk_lang = tag.slice (1, tag.length - 1).strip ().down ();
                    } else if (tag.length > 0) {
                        current_chunk_lang = tag.down ();
                    } else {
                        current_chunk_lang = default_lang;
                    }
                } else if (in_code_chunk && trimmed == "```") {
                    in_code_chunk = false;
                    add_cell_to_builder (builder, "code", current_source.str);
                    current_source.truncate ();
                } else {
                    current_source.append (line);
                    if (i < lines.length - 1) {
                        current_source.append ("\n");
                    }
                }
            }

            if (current_source.len > 0) {
                if (in_code_chunk) {
                    add_cell_to_builder (builder, "code", current_source.str);
                } else {
                    string rem = current_source.str.strip ();
                    if (rem.length > 0) {
                        add_cell_to_builder (builder, "markdown", current_source.str);
                    }
                }
            }

            builder.end_array (); // end cells

            // metadata
            builder.set_member_name ("metadata");
            builder.begin_object ();

            builder.set_member_name ("kernelspec");
            builder.begin_object ();
            builder.set_member_name ("display_name");
            builder.add_string_value (default_lang == "r" ? "R" : "Python 3");
            builder.set_member_name ("language");
            builder.add_string_value (default_lang);
            builder.set_member_name ("name");
            builder.add_string_value (default_lang == "r" ? "ir" : "python3");
            builder.end_object ();

            builder.set_member_name ("language_info");
            builder.begin_object ();
            builder.set_member_name ("name");
            builder.add_string_value (default_lang);
            builder.end_object ();

            builder.end_object (); // end metadata

            builder.set_member_name ("nbformat");
            builder.add_int_value (4);
            builder.set_member_name ("nbformat_minor");
            builder.add_int_value (5);

            builder.end_object (); // end root

            var generator = new Json.Generator ();
            generator.set_root (builder.get_root ());
            generator.pretty = true;
            generator.indent = 2;
            return generator.to_data (null);
        }

        private static void add_cell_to_builder (Json.Builder builder, string cell_type, string source_text) {
            builder.begin_object ();
            builder.set_member_name ("cell_type");
            builder.add_string_value (cell_type);

            builder.set_member_name ("metadata");
            builder.begin_object ();
            builder.end_object ();

            if (cell_type == "code") {
                builder.set_member_name ("execution_count");
                builder.add_null_value ();
                builder.set_member_name ("outputs");
                builder.begin_array ();
                builder.end_array ();
            }

            builder.set_member_name ("source");
            builder.begin_array ();
            string[] cell_lines = source_text.split ("\n");
            for (int k = 0; k < cell_lines.length; k++) {
                string l = cell_lines[k];
                if (k < cell_lines.length - 1) {
                    builder.add_string_value (l + "\n");
                } else if (l.length > 0) {
                    builder.add_string_value (l);
                }
            }
            builder.end_array ();

            builder.end_object ();
        }
    }
}
