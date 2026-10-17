namespace Imladris {

    public class McpServer : GLib.Object {

        public static string handle_json_rpc (string request_json, Window? window) {
            try {
                var parser = new Json.Parser ();
                parser.load_from_data (request_json, -1);
                var req = parser.get_root ().get_object ();

                int64 id = req.has_member ("id") ? req.get_int_member ("id") : 1;
                string method = req.has_member ("method") ? req.get_string_member ("method") : "";

                var builder = new Json.Builder ();
                builder.begin_object ();
                builder.set_member_name ("jsonrpc");
                builder.add_string_value ("2.0");
                builder.set_member_name ("id");
                builder.add_int_value (id);

                if (method == "initialize") {
                    builder.set_member_name ("result");
                    builder.begin_object ();
                    builder.set_member_name ("protocolVersion");
                    builder.add_string_value ("2024-11-05");

                    builder.set_member_name ("capabilities");
                    builder.begin_object ();
                    builder.set_member_name ("tools");
                    builder.begin_object ();
                    builder.end_object ();
                    builder.end_object ();

                    builder.set_member_name ("serverInfo");
                    builder.begin_object ();
                    builder.set_member_name ("name");
                    builder.add_string_value ("imladris-mcp");
                    builder.set_member_name ("version");
                    builder.add_string_value ("0.4.0");
                    builder.end_object ();

                    builder.end_object ();
                } else if (method == "tools/list") {
                    builder.set_member_name ("result");
                    builder.begin_object ();
                    builder.set_member_name ("tools");
                    builder.begin_array ();

                    add_tool_definition (builder, "get_active_document", "Retrieve the text content, language, line count and stats of the active tab in Imladris");
                    add_tool_definition (builder, "insert_text", "Insert text at cursor in the active document", "text", "The string content to insert");
                    add_tool_definition (builder, "insert_code_chunk", "Insert a computational chunk {r}, {python}, or {ts}", "engine", "r, python, or ts", "options", "Chunk options like 'echo: true'");
                    add_tool_definition (builder, "execute_code", "Asynchronously execute CLI command or script via the execution engine", "command", "CLI command (e.g. 'python3 -c ...' or 'Rscript -e ...')");
                    add_tool_definition (builder, "render_document", "Trigger Quarto render pipeline for HTML or PDF", "format", "Target format: 'html' or 'pdf'");
                    add_tool_definition (builder, "get_open_tabs", "List all open document tabs in Imladris");

                    builder.end_array ();
                    builder.end_object ();
                } else if (method == "tools/call") {
                    var params_obj = req.get_object_member ("params");
                    string tool_name = params_obj.get_string_member ("name");
                    Json.Object? args = params_obj.has_member ("arguments") ? params_obj.get_object_member ("arguments") : null;

                    string tool_result = execute_tool (tool_name, args, window);

                    builder.set_member_name ("result");
                    builder.begin_object ();
                    builder.set_member_name ("content");
                    builder.begin_array ();
                    builder.begin_object ();
                    builder.set_member_name ("type");
                    builder.add_string_value ("text");
                    builder.set_member_name ("text");
                    builder.add_string_value (tool_result);
                    builder.end_object ();
                    builder.end_array ();
                    builder.end_object ();
                } else {
                    builder.set_member_name ("error");
                    builder.begin_object ();
                    builder.set_member_name ("code");
                    builder.add_int_value (-32601);
                    builder.set_member_name ("message");
                    builder.add_string_value (@"Method '$method' not found.");
                    builder.end_object ();
                }

                builder.end_object ();
                var generator = new Json.Generator ();
                generator.set_root (builder.get_root ());
                return generator.to_data (null);
            } catch (GLib.Error e) {
                return "{\"jsonrpc\":\"2.0\",\"error\":{\"code\":-32700,\"message\":\"" + e.message + "\"}}";
            }
        }

        private static void add_tool_definition (Json.Builder b, string name, string desc, string? param1 = null, string? p1_desc = null, string? param2 = null, string? p2_desc = null) {
            b.begin_object ();
            b.set_member_name ("name");
            b.add_string_value (name);
            b.set_member_name ("description");
            b.add_string_value (desc);
            b.set_member_name ("inputSchema");
            b.begin_object ();
            b.set_member_name ("type");
            b.add_string_value ("object");
            b.set_member_name ("properties");
            b.begin_object ();

            if (param1 != null) {
                b.set_member_name (param1);
                b.begin_object ();
                b.set_member_name ("type");
                b.add_string_value ("string");
                if (p1_desc != null) {
                    b.set_member_name ("description");
                    b.add_string_value (p1_desc);
                }
                b.end_object ();
            }

            if (param2 != null) {
                b.set_member_name (param2);
                b.begin_object ();
                b.set_member_name ("type");
                b.add_string_value ("string");
                if (p2_desc != null) {
                    b.set_member_name ("description");
                    b.add_string_value (p2_desc);
                }
                b.end_object ();
            }

            b.end_object ();
            b.end_object ();
            b.end_object ();
        }

        private static string execute_tool (string name, Json.Object? args, Window? window) {
            if (window == null) {
                return "Error: No active Imladris window.";
            }

            var doc = window.get_active_document ();
            if (name == "get_active_document") {
                if (doc == null) return "No active document open.";
                return @"Language: $(doc.doc_type)\nLines: $(doc.source_buffer.get_line_count ())\n\nContent:\n$(doc.source_buffer.text)";
            } else if (name == "insert_text") {
                if (doc == null) return "No active document open.";
                string txt = (args != null && args.has_member ("text")) ? args.get_string_member ("text") : "";
                doc.source_buffer.insert_at_cursor (txt, -1);
                return "✔ Text inserted successfully at cursor.";
            } else if (name == "insert_code_chunk") {
                if (doc == null) return "No active document open.";
                string engine = (args != null && args.has_member ("engine")) ? args.get_string_member ("engine") : "python";
                string opt = (args != null && args.has_member ("options")) ? args.get_string_member ("options") : "";
                doc.insert_code_chunk (engine, opt);
                return @"✔ Code chunk {$engine} inserted successfully.";
            } else if (name == "execute_code") {
                if (doc == null) return "No active document open.";
                string cmd = (args != null && args.has_member ("command")) ? args.get_string_member ("command") : "";
                if (cmd.length == 0) return "Error: No command provided.";
                string[] parts = cmd.split (" ");
                ExecutionEngine.run_command_async.begin (parts, doc);
                return @"▶ Executing command asynchronously: $cmd";
            } else if (name == "render_document") {
                string fmt = (args != null && args.has_member ("format")) ? args.get_string_member ("format") : "html";
                window.trigger_render (fmt);
                return @"▶ Render pipeline triggered for target: $fmt";
            } else if (name == "get_open_tabs") {
                return @"Active Tab: $(doc != null ? doc.doc_type : "None")";
            }

            return @"Unknown tool: $name";
        }

        public static async void run_stdio_server_async (Window? win) {
            new GLib.Thread<void*> ("mcp-stdio-worker", () => {
                string? line = null;
                while ((line = GLib.stdin.read_line ()) != null) {
                    if (line.strip ().length == 0) continue;
                    string resp = handle_json_rpc (line, win);
                    GLib.stdout.printf ("%s\n", resp);
                    GLib.stdout.flush ();
                }
                return null;
            });
        }
    }
}
