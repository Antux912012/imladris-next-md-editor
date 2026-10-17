namespace Imladris {

    public class AiClient : GLib.Object {

        public bool is_online { get; set; default = false; }
        public string endpoint_url { get; set; default = "http://127.0.0.1:8080/v1"; }
        public string api_key { get; set; default = ""; }
        public string model_name { get; set; default = "qwen2.5-coder"; }
        public double temperature { get; set; default = 0.2; }

        private Soup.Session session;

        public AiClient () {
            session = new Soup.Session () {
                timeout = 60
            };
        }

        public void configure_online (string endpoint, string key, string model) {
            this.is_online = true;
            this.endpoint_url = endpoint.has_suffix ("/") ? endpoint.substring (0, endpoint.length - 1) : endpoint;
            this.api_key = key;
            this.model_name = model;
        }

        public void configure_offline (string local_endpoint = "http://127.0.0.1:8080/v1", string model = "qwen2.5-coder") {
            this.is_online = false;
            this.endpoint_url = local_endpoint.has_suffix ("/") ? local_endpoint.substring (0, local_endpoint.length - 1) : local_endpoint;
            this.api_key = "";
            this.model_name = model;
        }

        public async string send_chat_completion_async (string system_prompt, string user_prompt) throws GLib.Error {
            var builder = new Json.Builder ();
            builder.begin_object ();
            builder.set_member_name ("model");
            builder.add_string_value (model_name);

            builder.set_member_name ("temperature");
            builder.add_double_value (temperature);

            builder.set_member_name ("messages");
            builder.begin_array ();

            // System Message
            if (system_prompt.length > 0) {
                builder.begin_object ();
                builder.set_member_name ("role");
                builder.add_string_value ("system");
                builder.set_member_name ("content");
                builder.add_string_value (system_prompt);
                builder.end_object ();
            }

            // User Message
            builder.begin_object ();
            builder.set_member_name ("role");
            builder.add_string_value ("user");
            builder.set_member_name ("content");
            builder.add_string_value (user_prompt);
            builder.end_object ();

            builder.end_array ();
            builder.end_object ();

            var generator = new Json.Generator ();
            generator.set_root (builder.get_root ());
            string json_payload = generator.to_data (null);

            string target_url = @"$endpoint_url/chat/completions";
            var msg = new Soup.Message ("POST", target_url);
            msg.set_request_body_from_bytes ("application/json", new GLib.Bytes (json_payload.data));

            if (api_key.length > 0) {
                msg.request_headers.append ("Authorization", @"Bearer $api_key");
            }

            var bytes = yield session.send_and_read_async (msg, GLib.Priority.DEFAULT, null);
            if (msg.status_code < 200 || msg.status_code >= 300) {
                string err_body = (string) bytes.get_data ();
                throw new GLib.IOError.FAILED (@"HTTP Error $(msg.status_code): $(msg.reason_phrase) — $err_body");
            }

            string response_str = (string) bytes.get_data ();
            var parser = new Json.Parser ();
            parser.load_from_data (response_str, -1);

            var root_obj = parser.get_root ().get_object ();
            if (!root_obj.has_member ("choices")) {
                throw new GLib.IOError.INVALID_DATA ("No 'choices' returned in AI completion response.");
            }

            var choices = root_obj.get_array_member ("choices");
            if (choices.get_length () == 0) {
                return "";
            }

            var first_choice = choices.get_object_element (0);
            if (first_choice.has_member ("message")) {
                var message_obj = first_choice.get_object_member ("message");
                return message_obj.get_string_member ("content");
            } else if (first_choice.has_member ("text")) {
                return first_choice.get_string_member ("text");
            }

            return "";
        }

        public async string complete_code_async (string prefix, string suffix) throws GLib.Error {
            string system_prompt = "You are a code completion engine. Return ONLY the code completion to fill in between the prefix and suffix. Do not wrap in markdown quotes or explanations.";
            string prompt = @"[PREFIX]\n$prefix\n[SUFFIX]\n$suffix\n[COMPLETION]";
            return yield send_chat_completion_async (system_prompt, prompt);
        }
    }
}
