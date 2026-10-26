using GLib;
using Soup;
using Json;
using Imladris.Core;

namespace Imladris {

    public class AiClient : GLib.Object {

        private Soup.Session session;
        private AiConfigManager config_mgr;
        private Cancellable? active_cancellable = null;

        public bool is_online {
            get {
                return config_mgr.active_provider != AiProvider.LM_STUDIO && config_mgr.active_provider != AiProvider.OLLAMA;
            }
            set {
                if (!value) {
                    config_mgr.active_provider = AiProvider.LM_STUDIO;
                }
            }
        }

        public string endpoint_url {
            owned get { return config_mgr.get_endpoint_for (config_mgr.active_provider); }
            set {
                var s = config_mgr.get_settings_for (config_mgr.active_provider);
                s.endpoint = value;
                config_mgr.save ();
            }
        }

        public string api_key {
            owned get { return config_mgr.get_api_key_for (config_mgr.active_provider); }
            set {
                var s = config_mgr.get_settings_for (config_mgr.active_provider);
                s.api_key = value;
                config_mgr.save ();
            }
        }

        public string model_name {
            owned get { return config_mgr.get_model_for (config_mgr.active_provider); }
            set {
                var s = config_mgr.get_settings_for (config_mgr.active_provider);
                s.model = value;
                config_mgr.save ();
            }
        }

        public double temperature {
            get { return config_mgr.temperature; }
            set { config_mgr.temperature = value; }
        }

        public AiClient () {
            config_mgr = AiConfigManager.get_default ();
            session = new Soup.Session () {
                timeout = 90
            };
        }

        public void cancel_current_request () {
            if (active_cancellable != null && !active_cancellable.is_cancelled ()) {
                active_cancellable.cancel ();
                active_cancellable = null;
            }
        }

        public void configure_online (string endpoint, string key, string model) {
            config_mgr.set_provider_config (config_mgr.active_provider, endpoint, key, model);
        }

        public void configure_offline (string local_endpoint = "http://localhost:1234/v1", string model = "default") {
            config_mgr.active_provider = AiProvider.LM_STUDIO;
            config_mgr.set_provider_config (AiProvider.LM_STUDIO, local_endpoint, "", model);
        }

        public async string send_chat_completion_async (string system_prompt, string user_prompt, Cancellable? cancellable = null) throws GLib.Error {
            var provider = config_mgr.active_provider;
            string key = config_mgr.get_api_key_for (provider);
            string model = config_mgr.get_model_for (provider);
            string base_endpoint = config_mgr.get_endpoint_for (provider);

            // 1. Validation
            if (provider.requires_api_key () && key.length == 0) {
                string help_url = provider.get_api_key_help_url () ?? "";
                string url_hint = help_url.length > 0 ? @"\nGet your key at: $help_url" : "";
                throw new GLib.IOError.NOT_INITIALIZED (
                    @"No API key found for $(provider.get_display_name ()). Please configure your key in AI Settings or set the $(provider.get_env_var_name () ?? "appropriate") environment variable.$url_hint"
                );
            }

            var req_cancellable = cancellable ?? new Cancellable ();

            // Claude / Anthropic uses /v1/messages API with custom headers and body format
            if (provider == AiProvider.CLAUDE) {
                return yield send_anthropic_message_async (base_endpoint, key, model, system_prompt, user_prompt, req_cancellable);
            }

            // 2. Prepare JSON Payload
            var builder = new Json.Builder ();
            builder.begin_object ();
            builder.set_member_name ("model");
            builder.add_string_value (model);

            builder.set_member_name ("temperature");
            builder.add_double_value (config_mgr.temperature);

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

            // 3. Build Target URL
            string target_url = AiConfigManager.normalize_endpoint (base_endpoint, "/chat/completions");

            var msg = new Soup.Message ("POST", target_url);
            msg.set_request_body_from_bytes ("application/json", new GLib.Bytes (json_payload.data));

            // Set Authorization Header
            if (key.length > 0) {
                msg.request_headers.append ("Authorization", @"Bearer $key");
            }

            // Specific header adjustments for providers
            if (provider == AiProvider.GEMINI) {
                // Google AI Studio OpenAI endpoint accepts standard Bearer token
                msg.request_headers.append ("User-Agent", "Imladris-IDE/1.0");
            } else if (provider == AiProvider.QWEN) {
                msg.request_headers.append ("X-DashScope-Client", "Imladris-IDE");
            }

            // Manage Cancellable
            active_cancellable = req_cancellable;

            GLib.Bytes? bytes = null;
            try {
                bytes = yield session.send_and_read_async (msg, GLib.Priority.DEFAULT, req_cancellable);
            } finally {
                if (active_cancellable == req_cancellable) {
                    active_cancellable = null;
                }
            }

            if (bytes == null) {
                throw new GLib.IOError.FAILED ("No response received from server.");
            }

            string response_str = AiConfigManager.bytes_to_string (bytes);

            // 4. Handle HTTP Errors
            if (msg.status_code < 200 || msg.status_code >= 300) {
                string friendly_err = parse_error_response (response_str, msg.status_code, msg.reason_phrase, provider);
                throw new GLib.IOError.FAILED (friendly_err);
            }

            // 5. Parse Successful JSON Response
            var parser = new Json.Parser ();
            try {
                parser.load_from_data (response_str, -1);
            } catch (GLib.Error e) {
                throw new GLib.IOError.INVALID_DATA (@"Invalid JSON response from $(provider.get_short_name ()): $(e.message)");
            }

            var root = parser.get_root ();
            if (root == null || root.get_node_type () != Json.NodeType.OBJECT) {
                throw new GLib.IOError.INVALID_DATA ("Root node in completion response is not a valid JSON object.");
            }

            var root_obj = root.get_object ();
            if (!root_obj.has_member ("choices")) {
                if (root_obj.has_member ("error")) {
                    string err_msg = extract_json_error_message (root_obj.get_object_member ("error"));
                    throw new GLib.IOError.FAILED (@"$(provider.get_short_name ()) Error: $err_msg");
                }
                throw new GLib.IOError.INVALID_DATA (@"No 'choices' returned in $(provider.get_short_name ()) response.");
            }

            var choices = root_obj.get_array_member ("choices");
            if (choices.get_length () == 0) {
                return "";
            }

            var first_choice = choices.get_object_element (0);
            if (first_choice.has_member ("message")) {
                var message_obj = first_choice.get_object_member ("message");

                string reasoning = "";
                if (message_obj.has_member ("reasoning_content") && !message_obj.get_null_member ("reasoning_content")) {
                    reasoning = message_obj.get_string_member ("reasoning_content");
                }

                string content = "";
                if (message_obj.has_member ("content") && !message_obj.get_null_member ("content")) {
                    content = message_obj.get_string_member ("content");
                }

                if (reasoning.strip ().length > 0) {
                    return @"💭 *Reasoning Process:*\n$reasoning\n\n$content";
                }

                if (content.contains ("<think>") && content.contains ("</think>")) {
                    int start_idx = content.index_of ("<think>");
                    int end_idx = content.index_of ("</think>");
                    string thought = content.substring (start_idx + 7, end_idx - (start_idx + 7)).strip ();
                    string ans = content.substring (end_idx + 8).strip ();
                    if (thought.length > 0) {
                        return @"💭 *Reasoning Process:*\n$thought\n\n$ans";
                    }
                }

                return content;
            } else if (first_choice.has_member ("text")) {
                return first_choice.get_string_member ("text");
            }

            return "";
        }

        private async string send_anthropic_message_async (string base_endpoint, string key, string model, string system_prompt, string user_prompt, Cancellable cancellable) throws GLib.Error {
            var builder = new Json.Builder ();
            builder.begin_object ();
            builder.set_member_name ("model");
            builder.add_string_value (model);

            builder.set_member_name ("max_tokens");
            builder.add_int_value (4096);

            builder.set_member_name ("temperature");
            builder.add_double_value (config_mgr.temperature);

            if (system_prompt.length > 0) {
                builder.set_member_name ("system");
                builder.add_string_value (system_prompt);
            }

            builder.set_member_name ("messages");
            builder.begin_array ();
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

            string target_url = AiConfigManager.normalize_endpoint (base_endpoint, "/messages");
            var msg = new Soup.Message ("POST", target_url);
            msg.set_request_body_from_bytes ("application/json", new GLib.Bytes (json_payload.data));
            msg.request_headers.append ("x-api-key", key);
            msg.request_headers.append ("anthropic-version", "2023-06-01");

            active_cancellable = cancellable;
            GLib.Bytes? bytes = null;
            try {
                bytes = yield session.send_and_read_async (msg, GLib.Priority.DEFAULT, cancellable);
            } finally {
                if (active_cancellable == cancellable) {
                    active_cancellable = null;
                }
            }

            if (bytes == null) {
                throw new GLib.IOError.FAILED ("No response received from Anthropic API.");
            }

            string response_str = AiConfigManager.bytes_to_string (bytes);

            if (msg.status_code < 200 || msg.status_code >= 300) {
                string friendly_err = parse_error_response (response_str, msg.status_code, msg.reason_phrase, AiProvider.CLAUDE);
                throw new GLib.IOError.FAILED (friendly_err);
            }

            var parser = new Json.Parser ();
            try {
                parser.load_from_data (response_str, -1);
            } catch (GLib.Error e) {
                throw new GLib.IOError.INVALID_DATA (@"Invalid JSON response from Claude: $(e.message)");
            }

            var root = parser.get_root ();
            if (root == null || root.get_node_type () != Json.NodeType.OBJECT) {
                throw new GLib.IOError.INVALID_DATA ("Invalid response structure from Claude.");
            }

            var root_obj = root.get_object ();
            if (!root_obj.has_member ("content")) {
                if (root_obj.has_member ("error")) {
                    string err_msg = extract_json_error_message (root_obj.get_object_member ("error"));
                    throw new GLib.IOError.FAILED (@"Claude Error: $err_msg");
                }
                throw new GLib.IOError.INVALID_DATA ("No 'content' returned in Claude response.");
            }

            var content_arr = root_obj.get_array_member ("content");
            string full_text = "";
            string full_thinking = "";

            for (uint i = 0; i < content_arr.get_length (); i++) {
                var block = content_arr.get_object_element (i);
                string type_str = block.has_member ("type") ? block.get_string_member ("type") : "";
                if (type_str == "text" && block.has_member ("text")) {
                    full_text += block.get_string_member ("text");
                } else if (type_str == "thinking" && block.has_member ("thinking")) {
                    full_thinking += block.get_string_member ("thinking");
                }
            }

            if (full_thinking.strip ().length > 0) {
                return @"💭 *Reasoning Process:*\n$full_thinking\n\n$full_text";
            }
            return full_text;
        }

        private string parse_error_response (string body, uint status_code, string reason, AiProvider provider) {
            string detail = "";
            try {
                var parser = new Json.Parser ();
                parser.load_from_data (body, -1);
                var root = parser.get_root ();
                if (root != null && root.get_node_type () == Json.NodeType.OBJECT) {
                    var obj = root.get_object ();
                    if (obj.has_member ("error")) {
                        var err_node = obj.get_member ("error");
                        if (err_node.get_node_type () == Json.NodeType.OBJECT) {
                            detail = extract_json_error_message (err_node.get_object ());
                        } else if (err_node.get_node_type () == Json.NodeType.VALUE) {
                            detail = err_node.get_string ();
                        }
                    } else if (obj.has_member ("message")) {
                        detail = obj.get_string_member ("message");
                    }
                }
            } catch (GLib.Error e) {
                // Could not parse as JSON; use raw body if brief
                if (body.strip ().length > 0 && body.length < 200) {
                    detail = body.strip ();
                }
            }

            string provider_name = provider.get_display_name ();
            string? help_url = provider.get_api_key_help_url ();
            string help_suffix = help_url != null ? @"\nVisit: $help_url" : "";

            if (detail.length > 0) {
                return @"$provider_name Error (HTTP $status_code): $detail$help_suffix";
            } else {
                return @"$provider_name Error (HTTP $status_code: $reason)$help_suffix";
            }
        }

        private string extract_json_error_message (Json.Object err_obj) {
            if (err_obj.has_member ("message")) {
                return err_obj.get_string_member ("message");
            }
            if (err_obj.has_member ("code")) {
                return @"Code: $(err_obj.get_string_member ("code"))";
            }
            return "Unknown error";
        }

        public async string complete_code_async (string prefix, string suffix, Cancellable? cancellable = null) throws GLib.Error {
            string system_prompt = "You are a specialized code completion engine for scientific and technical documents (Quarto, R Markdown, Python, R, Julia). Return ONLY the code completion to fill in between the prefix and suffix. Do not wrap in markdown quotes, backticks, or conversational explanations.";
            string prompt = @"[PREFIX]\n$prefix\n[SUFFIX]\n$suffix\n[COMPLETION]";
            return yield send_chat_completion_async (system_prompt, prompt, cancellable);
        }
    }
}
