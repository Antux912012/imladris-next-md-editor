using GLib;
using Json;
using Gee;

namespace Imladris.Core {

    public enum AiProvider {
        GEMINI,
        CLAUDE,
        OPENAI,
        DEEPSEEK,
        KIMI,
        QWEN,
        CURSOR,
        NVIDIA_NIM,
        OLLAMA,
        LM_STUDIO,
        CHERRY_STUDIO,
        ANTIGRAVITY,
        CUSTOM;

        public string to_string_id () {
            switch (this) {
                case GEMINI: return "gemini";
                case CLAUDE: return "claude";
                case OPENAI: return "openai";
                case DEEPSEEK: return "deepseek";
                case KIMI: return "kimi";
                case QWEN: return "qwen";
                case CURSOR: return "cursor";
                case NVIDIA_NIM: return "nvidia_nim";
                case OLLAMA: return "ollama";
                case LM_STUDIO: return "lm_studio";
                case CHERRY_STUDIO: return "cherry_studio";
                case ANTIGRAVITY: return "antigravity";
                case CUSTOM: return "custom";
                default: return "gemini";
            }
        }

        public static AiProvider from_string_id (string id) {
            switch (id.down ()) {
                case "gemini": return GEMINI;
                case "claude":
                case "anthropic": return CLAUDE;
                case "openai":
                case "chatgpt": return OPENAI;
                case "deepseek": return DEEPSEEK;
                case "kimi": return KIMI;
                case "qwen": return QWEN;
                case "cursor": return CURSOR;
                case "nvidia":
                case "nvidia_nim":
                case "nim": return NVIDIA_NIM;
                case "ollama": return OLLAMA;
                case "lm_studio":
                case "local_llama": return LM_STUDIO;
                case "cherry":
                case "cherry_studio": return CHERRY_STUDIO;
                case "antigravity":
                case "agy": return ANTIGRAVITY;
                case "custom": return CUSTOM;
                default: return GEMINI;
            }
        }

        public string get_display_name () {
            switch (this) {
                case GEMINI: return "Google Gemini (Google AI Studio)";
                case CLAUDE: return "Claude (Anthropic API)";
                case OPENAI: return "OpenAI (GPT-4o / o1 / o3)";
                case DEEPSEEK: return "DeepSeek (deepseek-chat / R1)";
                case KIMI: return "Kimi (Moonshot AI)";
                case QWEN: return "Qwen (Alibaba DashScope)";
                case CURSOR: return "Cursor API (Cursor Compatibility)";
                case NVIDIA_NIM: return "NVIDIA NIM (integrate.api.nvidia.com)";
                case OLLAMA: return "Ollama (localhost:11434)";
                case LM_STUDIO: return "LM Studio (localhost:1234)";
                case CHERRY_STUDIO: return "Cherry Studio / LocalAI (localhost:23333 / 8080)";
                case ANTIGRAVITY: return "Antigravity (agy Agent Harness)";
                case CUSTOM: return "Custom OpenAI-Compatible API";
                default: return "Unknown";
            }
        }

        public string get_short_name () {
            switch (this) {
                case GEMINI: return "Gemini";
                case CLAUDE: return "Claude";
                case OPENAI: return "OpenAI";
                case DEEPSEEK: return "DeepSeek";
                case KIMI: return "Kimi";
                case QWEN: return "Qwen";
                case CURSOR: return "Cursor";
                case NVIDIA_NIM: return "NVIDIA NIM";
                case OLLAMA: return "Ollama";
                case LM_STUDIO: return "LM Studio";
                case CHERRY_STUDIO: return "Cherry Studio";
                case ANTIGRAVITY: return "Antigravity";
                case CUSTOM: return "Custom";
                default: return "AI";
            }
        }

        public string get_icon_name () {
            switch (this) {
                case GEMINI: return "ai-gemini";
                case CLAUDE: return "ai-claude";
                case OPENAI: return "ai-openai";
                case DEEPSEEK: return "ai-deepseek";
                case KIMI: return "ai-kimi";
                case QWEN: return "ai-qwen";
                case CURSOR: return "ai-cursor";
                case NVIDIA_NIM: return "ai-nvidia";
                case OLLAMA: return "ai-ollama";
                case LM_STUDIO: return "ai-lmstudio";
                case CHERRY_STUDIO: return "ai-custom";
                case ANTIGRAVITY: return "ai-elrond";
                case CUSTOM: return "ai-custom";
                default: return "system-run-symbolic";
            }
        }

        public string get_default_endpoint () {
            switch (this) {
                case GEMINI: return "https://generativelanguage.googleapis.com/v1beta/openai";
                case CLAUDE: return "https://api.anthropic.com/v1";
                case OPENAI: return "https://api.openai.com/v1";
                case DEEPSEEK: return "https://api.deepseek.com/v1";
                case KIMI: return "https://api.moonshot.cn/v1";
                case QWEN: return "https://dashscope-intl.aliyuncs.com/compatible-mode/v1";
                case CURSOR: return "https://api.cursor.sh/v1";
                case NVIDIA_NIM: return "https://integrate.api.nvidia.com/v1";
                case OLLAMA: return "http://localhost:11434/v1";
                case LM_STUDIO: return "http://localhost:1234/v1";
                case CHERRY_STUDIO: return "http://localhost:23333/v1";
                case ANTIGRAVITY: return "local://agy";
                case CUSTOM: return "https://api.openai.com/v1";
                default: return "";
            }
        }

        public string get_default_model () {
            switch (this) {
                case GEMINI: return "gemini-2.0-flash";
                case CLAUDE: return "claude-3-5-sonnet-20241022";
                case OPENAI: return "gpt-4o";
                case DEEPSEEK: return "deepseek-chat";
                case KIMI: return "moonshot-v1-8k";
                case QWEN: return "qwen2.5-coder-32b-instruct";
                case CURSOR: return "cursor-small";
                case NVIDIA_NIM: return "meta/llama-3.3-70b-instruct";
                case OLLAMA: return "qwen2.5-coder:latest";
                case LM_STUDIO: return "default";
                case CHERRY_STUDIO: return "default";
                case ANTIGRAVITY: return "gemini-2.5-pro";
                case CUSTOM: return "gpt-4o";
                default: return "";
            }
        }

        public string[] get_recommended_models () {
            switch (this) {
                case GEMINI:
                    return { "gemini-2.0-flash", "gemini-1.5-flash", "gemini-1.5-pro", "gemini-2.0-flash-thinking-exp-01-21" };
                case CLAUDE:
                    return { "claude-3-5-sonnet-20241022", "claude-3-7-sonnet-20250219", "claude-3-5-haiku-20241022", "claude-3-opus-20240229" };
                case OPENAI:
                    return { "gpt-4o", "gpt-4o-mini", "o1", "o3-mini", "gpt-4-turbo" };
                case DEEPSEEK:
                    return { "deepseek-chat", "deepseek-reasoner" };
                case KIMI:
                    return { "moonshot-v1-8k", "moonshot-v1-32k", "moonshot-v1-128k", "kimi-latest" };
                case QWEN:
                    return { "qwen2.5-coder-32b-instruct", "qwen2.5-coder-7b-instruct", "qwen-plus", "qwen-turbo", "qwen-max" };
                case CURSOR:
                    return { "cursor-small", "claude-3-5-sonnet", "gpt-4o", "cursor-fast" };
                case NVIDIA_NIM:
                    return { "meta/llama-3.3-70b-instruct", "deepseek-ai/deepseek-r1", "nvidia/llama-3.1-nemotron-70b-instruct", "qwen/qwen2.5-coder-32b-instruct" };
                case OLLAMA:
                    return { "qwen2.5-coder:latest", "deepseek-r1:latest", "llama3.2:latest", "codellama:latest" };
                case LM_STUDIO:
                    return { "default", "loaded-model", "qwen2.5-coder-7b", "deepseek-r1-distill-qwen-7b", "llama-3.2-3b" };
                case CHERRY_STUDIO:
                    return { "default", "loaded-model", "qwen2.5-coder", "deepseek-r1" };
                case ANTIGRAVITY:
                    return { "gemini-2.5-pro", "gemini-2.5-flash", "auto" };
                case CUSTOM:
                    return { "gpt-4o", "gpt-4o-mini", "claude-3-5-sonnet", "deepseek-chat" };
                default:
                    return {};
            }
        }

        public string? get_api_key_help_url () {
            switch (this) {
                case GEMINI: return "https://aistudio.google.com/app/apikey";
                case CLAUDE: return "https://console.anthropic.com/settings/keys";
                case OPENAI: return "https://platform.openai.com/api-keys";
                case DEEPSEEK: return "https://platform.deepseek.com/api_keys";
                case KIMI: return "https://platform.moonshot.cn/console/api-keys";
                case QWEN: return "https://dashscope.console.aliyun.com/apiKey";
                case CURSOR: return "https://cursor.com";
                case NVIDIA_NIM: return "https://build.nvidia.com";
                case LM_STUDIO: return "https://lmstudio.ai";
                case CHERRY_STUDIO: return "https://cherry-ai.com";
                case CUSTOM: return "https://platform.openai.com/api-keys";
                default: return null;
            }
        }

        public string? get_env_var_name () {
            switch (this) {
                case GEMINI: return "GEMINI_API_KEY";
                case CLAUDE: return "ANTHROPIC_API_KEY";
                case OPENAI: return "OPENAI_API_KEY";
                case DEEPSEEK: return "DEEPSEEK_API_KEY";
                case KIMI: return "MOONSHOT_API_KEY";
                case QWEN: return "DASHSCOPE_API_KEY";
                case CURSOR: return "CURSOR_API_KEY";
                case NVIDIA_NIM: return "NVIDIA_API_KEY";
                case CUSTOM: return "OPENAI_API_KEY";
                default: return null;
            }
        }

        public bool requires_api_key () {
            switch (this) {
                case OLLAMA:
                case LM_STUDIO:
                case CHERRY_STUDIO:
                case ANTIGRAVITY:
                    return false;
                default:
                    return true;
            }
        }
    }

    public class ProviderSettings : GLib.Object {
        public string endpoint { get; set; default = ""; }
        public string api_key { get; set; default = ""; }
        public string model { get; set; default = ""; }
        public string auth_type { get; set; default = "api_key"; } // "api_key" or "oauth_token"

        public ProviderSettings clone () {
            var copy = new ProviderSettings ();
            copy.endpoint = this.endpoint;
            copy.api_key = this.api_key;
            copy.model = this.model;
            copy.auth_type = this.auth_type;
            return copy;
        }
    }

    public class AiConfigManager : GLib.Object {
        private static AiConfigManager? _instance = null;

        private AiProvider _active_provider = AiProvider.GEMINI;
        public AiProvider active_provider {
            get { return _active_provider; }
            set {
                if (_active_provider != value) {
                    _active_provider = value;
                    provider_changed (value);
                    config_changed ();
                    save ();
                }
            }
        }

        private double _temperature = 0.2;
        public double temperature {
            get { return _temperature; }
            set {
                if (_temperature != value) {
                    _temperature = value;
                    config_changed ();
                    save ();
                }
            }
        }

        private Gee.HashMap<string, ProviderSettings> providers;

        public signal void config_changed ();
        public signal void provider_changed (AiProvider provider);

        public static AiConfigManager get_default () {
            if (_instance == null) {
                _instance = new AiConfigManager ();
            }
            return _instance;
        }

        private AiConfigManager () {
            providers = new Gee.HashMap<string, ProviderSettings> ();
            init_defaults ();
            load ();
            auto_detect_env_keys ();
        }

        private void init_defaults () {
            AiProvider[] all = {
                AiProvider.GEMINI,
                AiProvider.CLAUDE,
                AiProvider.OPENAI,
                AiProvider.DEEPSEEK,
                AiProvider.KIMI,
                AiProvider.QWEN,
                AiProvider.CURSOR,
                AiProvider.NVIDIA_NIM,
                AiProvider.OLLAMA,
                AiProvider.LM_STUDIO,
                AiProvider.CHERRY_STUDIO,
                AiProvider.ANTIGRAVITY,
                AiProvider.CUSTOM
            };

            foreach (var prov in all) {
                string id = prov.to_string_id ();
                if (!providers.has_key (id)) {
                    var s = new ProviderSettings ();
                    s.endpoint = prov.get_default_endpoint ();
                    s.model = prov.get_default_model ();
                    s.api_key = "";
                    s.auth_type = "api_key";
                    providers.set (id, s);
                }
            }
        }

        private void auto_detect_env_keys () {
            // Check if user has environment variables set and use them if config has no key
            AiProvider[] check_order = {
                AiProvider.GEMINI,
                AiProvider.CLAUDE,
                AiProvider.OPENAI,
                AiProvider.DEEPSEEK,
                AiProvider.KIMI,
                AiProvider.QWEN,
                AiProvider.CURSOR,
                AiProvider.NVIDIA_NIM,
                AiProvider.CUSTOM
            };

            bool had_active_key = has_valid_key (active_provider);

            foreach (var prov in check_order) {
                string? env_var = prov.get_env_var_name ();
                string? env_val = null;
                if (env_var != null) {
                    env_val = GLib.Environment.get_variable (env_var);
                }
                if (prov == AiProvider.GEMINI && (env_val == null || env_val == "")) {
                    env_val = GLib.Environment.get_variable ("GOOGLE_API_KEY");
                }
                if (prov == AiProvider.CLAUDE && (env_val == null || env_val == "")) {
                    env_val = GLib.Environment.get_variable ("CLAUDE_API_KEY");
                }
                if (prov == AiProvider.KIMI && (env_val == null || env_val == "")) {
                    env_val = GLib.Environment.get_variable ("KIMI_API_KEY");
                }
                if (prov == AiProvider.QWEN && (env_val == null || env_val == "")) {
                    env_val = GLib.Environment.get_variable ("QWEN_API_KEY");
                }
                if (prov == AiProvider.NVIDIA_NIM && (env_val == null || env_val == "")) {
                    env_val = GLib.Environment.get_variable ("NIM_API_KEY");
                }

                if (env_val != null && env_val.strip ().length > 0) {
                    var s = get_settings_for (prov);
                    if (s.api_key == "") {
                        s.api_key = env_val.strip ();
                    }
                    if (!had_active_key) {
                        _active_provider = prov;
                        had_active_key = true;
                    }
                }
            }
        }

        public ProviderSettings get_settings_for (AiProvider provider) {
            string id = provider.to_string_id ();
            if (!providers.has_key (id)) {
                var s = new ProviderSettings ();
                s.endpoint = provider.get_default_endpoint ();
                s.model = provider.get_default_model ();
                s.api_key = "";
                s.auth_type = "api_key";
                providers.set (id, s);
            }
            return providers.get (id);
        }

        public string get_endpoint_for (AiProvider provider) {
            var s = get_settings_for (provider);
            if (s.endpoint.strip ().length > 0) {
                return s.endpoint.strip ();
            }
            return provider.get_default_endpoint ();
        }

        public string get_api_key_for (AiProvider provider) {
            var s = get_settings_for (provider);
            if (s.api_key.strip ().length > 0) {
                return s.api_key.strip ();
            }

            // Fallback to environment variables
            string? env_var = provider.get_env_var_name ();
            if (env_var != null) {
                string? env_val = GLib.Environment.get_variable (env_var);
                if (env_val != null && env_val.strip ().length > 0) {
                    return env_val.strip ();
                }
            }

            if (provider == AiProvider.GEMINI) {
                string? g_key = GLib.Environment.get_variable ("GOOGLE_API_KEY");
                if (g_key != null && g_key.strip ().length > 0) {
                    return g_key.strip ();
                }
            } else if (provider == AiProvider.CLAUDE) {
                string? c_key = GLib.Environment.get_variable ("CLAUDE_API_KEY");
                if (c_key != null && c_key.strip ().length > 0) {
                    return c_key.strip ();
                }
            } else if (provider == AiProvider.KIMI) {
                string? k_key = GLib.Environment.get_variable ("KIMI_API_KEY");
                if (k_key != null && k_key.strip ().length > 0) {
                    return k_key.strip ();
                }
            } else if (provider == AiProvider.QWEN) {
                string? q_key = GLib.Environment.get_variable ("QWEN_API_KEY");
                if (q_key != null && q_key.strip ().length > 0) {
                    return q_key.strip ();
                }
            } else if (provider == AiProvider.NVIDIA_NIM) {
                string? n_key = GLib.Environment.get_variable ("NIM_API_KEY");
                if (n_key != null && n_key.strip ().length > 0) {
                    return n_key.strip ();
                }
            }

            return "";
        }

        public string get_model_for (AiProvider provider) {
            var s = get_settings_for (provider);
            if (s.model.strip ().length > 0) {
                return s.model.strip ();
            }
            return provider.get_default_model ();
        }

        public bool has_valid_key (AiProvider provider) {
            if (!provider.requires_api_key ()) {
                return true;
            }
            return get_api_key_for (provider).length > 0;
        }

        public void set_provider_config (AiProvider provider, string endpoint, string api_key, string model, string auth_type = "api_key") {
            var s = get_settings_for (provider);
            s.endpoint = endpoint.strip ();
            s.api_key = api_key.strip ();
            s.model = model.strip ();
            s.auth_type = auth_type.strip ();
            config_changed ();
            save ();
        }

        public static string normalize_endpoint (string base_url, string path = "/chat/completions") {
            string clean = base_url.strip ();
            while (clean.has_suffix ("/")) {
                clean = clean.substring (0, clean.length - 1);
            }
            if (clean.has_suffix (path)) {
                return clean;
            }
            return clean + path;
        }

        public static string bytes_to_string (GLib.Bytes bytes) {
            size_t size = bytes.get_size ();
            if (size == 0) return "";
            uint8[] buf = new uint8[size + 1];
            GLib.Memory.copy (buf, bytes.get_data (), size);
            buf[size] = '\0';
            return (string) buf;
        }

        public static void open_url (string url) {
            try {
                GLib.AppInfo.launch_default_for_uri (url, null);
            } catch (GLib.Error e) {
                GLib.warning ("Failed to open URL '%s': %s", url, e.message);
            }
        }

        private string get_config_file_path () {
            string dir = GLib.Path.build_filename (GLib.Environment.get_user_config_dir (), "imladris");
            GLib.DirUtils.create_with_parents (dir, 0700);
            return GLib.Path.build_filename (dir, "ai_config.json");
        }

        public void load () {
            string config_file = get_config_file_path ();
            if (!GLib.FileUtils.test (config_file, GLib.FileTest.EXISTS)) {
                return;
            }

            try {
                string content;
                GLib.FileUtils.get_contents (config_file, out content);
                var parser = new Json.Parser ();
                parser.load_from_data (content, -1);
                var root = parser.get_root ();
                if (root == null || root.get_node_type () != Json.NodeType.OBJECT) {
                    return;
                }

                var root_obj = root.get_object ();
                if (root_obj.has_member ("active_provider")) {
                    _active_provider = AiProvider.from_string_id (root_obj.get_string_member ("active_provider"));
                }
                if (root_obj.has_member ("temperature")) {
                    _temperature = root_obj.get_double_member ("temperature");
                }

                if (root_obj.has_member ("providers")) {
                    var provs_obj = root_obj.get_object_member ("providers");
                    foreach (var member_name in provs_obj.get_members ()) {
                        var prov_data = provs_obj.get_object_member (member_name);
                        var s = new ProviderSettings ();
                        if (prov_data.has_member ("endpoint")) s.endpoint = prov_data.get_string_member ("endpoint");
                        if (prov_data.has_member ("api_key")) s.api_key = prov_data.get_string_member ("api_key");
                        if (prov_data.has_member ("model")) s.model = prov_data.get_string_member ("model");
                        if (prov_data.has_member ("auth_type")) s.auth_type = prov_data.get_string_member ("auth_type");
                        providers.set (member_name, s);
                    }
                }
            } catch (GLib.Error e) {
                GLib.warning ("Failed to load AI configuration: %s", e.message);
            }
        }

        public void save () {
            try {
                string config_file = get_config_file_path ();
                var builder = new Json.Builder ();
                builder.begin_object ();

                builder.set_member_name ("active_provider");
                builder.add_string_value (active_provider.to_string_id ());

                builder.set_member_name ("temperature");
                builder.add_double_value (temperature);

                builder.set_member_name ("providers");
                builder.begin_object ();

                foreach (var entry in providers.entries) {
                    builder.set_member_name (entry.key);
                    builder.begin_object ();
                    builder.set_member_name ("endpoint");
                    builder.add_string_value (entry.value.endpoint);
                    builder.set_member_name ("api_key");
                    builder.add_string_value (entry.value.api_key);
                    builder.set_member_name ("model");
                    builder.add_string_value (entry.value.model);
                    builder.set_member_name ("auth_type");
                    builder.add_string_value (entry.value.auth_type);
                    builder.end_object ();
                }

                builder.end_object ();
                builder.end_object ();

                var generator = new Json.Generator ();
                generator.set_root (builder.get_root ());
                generator.pretty = true;
                string json_data = generator.to_data (null);

                GLib.FileUtils.set_contents (config_file, json_data);

                // Ensure file is only readable by current user (0600)
                try {
                    var gfile = GLib.File.new_for_path (config_file);
                    gfile.set_attribute_uint32 (GLib.FileAttribute.UNIX_MODE, 0600, GLib.FileQueryInfoFlags.NONE, null);
                } catch (GLib.Error err) {
                    // Ignore filesystem attribute errors
                }
            } catch (GLib.Error e) {
                GLib.warning ("Failed to save AI configuration: %s", e.message);
            }
        }
    }
}
