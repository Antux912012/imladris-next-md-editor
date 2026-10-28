using GLib;
using Gtk;
using Adw;
using Imladris.Core;

namespace Imladris.UI {

    public class AiSettingsDialog : Adw.PreferencesDialog {

        private AiConfigManager config_mgr;

        public AiSettingsDialog () {
            Object (title: "AI Engine & Model Configuration");
            this.config_mgr = AiConfigManager.get_default ();

            setup_pages ();
        }

        private void setup_pages () {
            // ==========================================
            // Page 1: Frontier Cloud AI (Gemini, Claude, OpenAI, Cursor)
            // ==========================================
            var frontier_page = new Adw.PreferencesPage () {
                title = "Frontier AI",
                icon_name = "network-server-symbolic"
            };

            // --- Google Gemini Group ---
            var gemini_group = new Adw.PreferencesGroup () {
                title = "Google Gemini",
                description = "Google DeepMind's flagship models with state-of-the-art multimodal reasoning",
                header_suffix = new Gtk.Image.from_icon_name (AiProvider.GEMINI.get_icon_name ()) { pixel_size = 28, valign = Gtk.Align.CENTER }
            };

            var gemini_settings = config_mgr.get_settings_for (AiProvider.GEMINI);

            var gemini_key_row = new Adw.PasswordEntryRow () {
                title = "Google API Key or OAuth Token",
                text = gemini_settings.api_key
            };
            gemini_key_row.notify["text"].connect (() => {
                gemini_settings.api_key = gemini_key_row.text;
                config_mgr.save ();
            });
            gemini_group.add (gemini_key_row);

            var gemini_endpoint_row = new Adw.EntryRow () {
                title = "Base Endpoint",
                text = gemini_settings.endpoint
            };
            gemini_endpoint_row.notify["text"].connect (() => {
                gemini_settings.endpoint = gemini_endpoint_row.text;
                config_mgr.save ();
            });
            gemini_group.add (gemini_endpoint_row);

            var gemini_model_row = new Adw.EntryRow () {
                title = "Model Name",
                text = gemini_settings.model
            };
            gemini_model_row.notify["text"].connect (() => {
                gemini_settings.model = gemini_model_row.text;
                config_mgr.save ();
            });
            gemini_group.add (gemini_model_row);

            var gemini_action_row = new Adw.ActionRow () {
                title = "Get Google AI Studio API Key",
                subtitle = "Free tier available at Google AI Studio (login with your Google Account)"
            };
            var gemini_btn = new Gtk.Button.with_label ("Get API Key ↗") { valign = Gtk.Align.CENTER };
            gemini_btn.add_css_class ("suggested-action");
            gemini_btn.clicked.connect (() => {
                AiConfigManager.open_url ("https://aistudio.google.com/app/apikey");
            });
            gemini_action_row.add_suffix (gemini_btn);
            gemini_group.add (gemini_action_row);

            var gemini_oauth_row = new Adw.ActionRow () {
                title = "Google Account / OAuth Access Token",
                subtitle = "Authenticate via gcloud auth print-access-token or Google Cloud OAuth2"
            };
            var oauth_btn = new Gtk.Button.with_label ("OAuth Info ↗") { valign = Gtk.Align.CENTER };
            oauth_btn.add_css_class ("flat");
            oauth_btn.clicked.connect (() => {
                AiConfigManager.open_url ("https://cloud.google.com/docs/authentication/token-types#access-contents");
            });
            gemini_oauth_row.add_suffix (oauth_btn);
            gemini_group.add (gemini_oauth_row);

            frontier_page.add (gemini_group);

            // --- Claude / Anthropic Group ---
            var claude_group = new Adw.PreferencesGroup () {
                title = "Claude (Anthropic)",
                description = "Anthropic's Claude 3.5 Sonnet, 3.7 Sonnet, Haiku, and Opus via native Messages API",
                header_suffix = new Gtk.Image.from_icon_name (AiProvider.CLAUDE.get_icon_name ()) { pixel_size = 28, valign = Gtk.Align.CENTER }
            };

            var claude_settings = config_mgr.get_settings_for (AiProvider.CLAUDE);

            var claude_key_row = new Adw.PasswordEntryRow () {
                title = "Anthropic API Key",
                text = claude_settings.api_key
            };
            claude_key_row.notify["text"].connect (() => {
                claude_settings.api_key = claude_key_row.text;
                config_mgr.save ();
            });
            claude_group.add (claude_key_row);

            var claude_endpoint_row = new Adw.EntryRow () {
                title = "Base Endpoint",
                text = claude_settings.endpoint
            };
            claude_endpoint_row.notify["text"].connect (() => {
                claude_settings.endpoint = claude_endpoint_row.text;
                config_mgr.save ();
            });
            claude_group.add (claude_endpoint_row);

            var claude_model_row = new Adw.EntryRow () {
                title = "Model Name",
                text = claude_settings.model
            };
            claude_model_row.notify["text"].connect (() => {
                claude_settings.model = claude_model_row.text;
                config_mgr.save ();
            });
            claude_group.add (claude_model_row);

            var claude_action_row = new Adw.ActionRow () {
                title = "Get Anthropic API Key",
                subtitle = "Manage API keys in the Anthropic Console"
            };
            var claude_btn = new Gtk.Button.with_label ("Get API Key ↗") { valign = Gtk.Align.CENTER };
            claude_btn.add_css_class ("suggested-action");
            claude_btn.clicked.connect (() => {
                AiConfigManager.open_url ("https://console.anthropic.com/settings/keys");
            });
            claude_action_row.add_suffix (claude_btn);
            claude_group.add (claude_action_row);

            frontier_page.add (claude_group);

            // --- OpenAI Group ---
            var openai_group = new Adw.PreferencesGroup () {
                title = "OpenAI",
                description = "OpenAI GPT-4o, GPT-4o-mini, o1, and o3-mini models",
                header_suffix = new Gtk.Image.from_icon_name (AiProvider.OPENAI.get_icon_name ()) { pixel_size = 28, valign = Gtk.Align.CENTER }
            };

            var openai_settings = config_mgr.get_settings_for (AiProvider.OPENAI);

            var openai_key_row = new Adw.PasswordEntryRow () {
                title = "OpenAI API Key",
                text = openai_settings.api_key
            };
            openai_key_row.notify["text"].connect (() => {
                openai_settings.api_key = openai_key_row.text;
                config_mgr.save ();
            });
            openai_group.add (openai_key_row);

            var openai_endpoint_row = new Adw.EntryRow () {
                title = "Base Endpoint",
                text = openai_settings.endpoint
            };
            openai_endpoint_row.notify["text"].connect (() => {
                openai_settings.endpoint = openai_endpoint_row.text;
                config_mgr.save ();
            });
            openai_group.add (openai_endpoint_row);

            var openai_model_row = new Adw.EntryRow () {
                title = "Model Name",
                text = openai_settings.model
            };
            openai_model_row.notify["text"].connect (() => {
                openai_settings.model = openai_model_row.text;
                config_mgr.save ();
            });
            openai_group.add (openai_model_row);

            var openai_action_row = new Adw.ActionRow () {
                title = "Get OpenAI API Key",
                subtitle = "Manage API keys on the OpenAI Developer Platform"
            };
            var openai_btn = new Gtk.Button.with_label ("Get API Key ↗") { valign = Gtk.Align.CENTER };
            openai_btn.add_css_class ("suggested-action");
            openai_btn.clicked.connect (() => {
                AiConfigManager.open_url ("https://platform.openai.com/api-keys");
            });
            openai_action_row.add_suffix (openai_btn);
            openai_group.add (openai_action_row);

            frontier_page.add (openai_group);

            // --- Cursor API Compatibility Group ---
            var cursor_group = new Adw.PreferencesGroup () {
                title = "Cursor API Compatibility",
                description = "Connect using Cursor API or OpenAI-compatible Cursor proxies",
                header_suffix = new Gtk.Image.from_icon_name (AiProvider.CURSOR.get_icon_name ()) { pixel_size = 28, valign = Gtk.Align.CENTER }
            };

            var cursor_settings = config_mgr.get_settings_for (AiProvider.CURSOR);

            var cursor_endpoint_row = new Adw.EntryRow () {
                title = "Base Endpoint",
                text = cursor_settings.endpoint
            };
            cursor_endpoint_row.notify["text"].connect (() => {
                cursor_settings.endpoint = cursor_endpoint_row.text;
                config_mgr.save ();
            });
            cursor_group.add (cursor_endpoint_row);

            var cursor_key_row = new Adw.PasswordEntryRow () {
                title = "Cursor API Key",
                text = cursor_settings.api_key
            };
            cursor_key_row.notify["text"].connect (() => {
                cursor_settings.api_key = cursor_key_row.text;
                config_mgr.save ();
            });
            cursor_group.add (cursor_key_row);

            var cursor_model_row = new Adw.EntryRow () {
                title = "Model Name",
                text = cursor_settings.model
            };
            cursor_model_row.notify["text"].connect (() => {
                cursor_settings.model = cursor_model_row.text;
                config_mgr.save ();
            });
            cursor_group.add (cursor_model_row);

            var cursor_action_row = new Adw.ActionRow () {
                title = "Cursor Information",
                subtitle = "Learn more about Cursor AI and developer API compatibility"
            };
            var cursor_btn = new Gtk.Button.with_label ("Visit cursor.com ↗") { valign = Gtk.Align.CENTER };
            cursor_btn.add_css_class ("suggested-action");
            cursor_btn.clicked.connect (() => {
                AiConfigManager.open_url ("https://cursor.com");
            });
            cursor_action_row.add_suffix (cursor_btn);
            cursor_group.add (cursor_action_row);

            frontier_page.add (cursor_group);

            this.add (frontier_page);

            // ==========================================
            // Page 2: Open Weights & Enterprise (DeepSeek, Kimi, Qwen, NVIDIA NIM)
            // ==========================================
            var enterprise_page = new Adw.PreferencesPage () {
                title = "Open & Enterprise",
                icon_name = "system-run-symbolic"
            };

            // --- DeepSeek Group ---
            var deepseek_group = new Adw.PreferencesGroup () {
                title = "DeepSeek",
                description = "High-performance coding (deepseek-chat) and reasoning (deepseek-reasoner / R1)",
                header_suffix = new Gtk.Image.from_icon_name (AiProvider.DEEPSEEK.get_icon_name ()) { pixel_size = 28, valign = Gtk.Align.CENTER }
            };

            var ds_settings = config_mgr.get_settings_for (AiProvider.DEEPSEEK);

            var ds_key_row = new Adw.PasswordEntryRow () {
                title = "DeepSeek API Key",
                text = ds_settings.api_key
            };
            ds_key_row.notify["text"].connect (() => {
                ds_settings.api_key = ds_key_row.text;
                config_mgr.save ();
            });
            deepseek_group.add (ds_key_row);

            var ds_endpoint_row = new Adw.EntryRow () {
                title = "Base Endpoint",
                text = ds_settings.endpoint
            };
            ds_endpoint_row.notify["text"].connect (() => {
                ds_settings.endpoint = ds_endpoint_row.text;
                config_mgr.save ();
            });
            deepseek_group.add (ds_endpoint_row);

            var ds_model_row = new Adw.EntryRow () {
                title = "Model Name",
                text = ds_settings.model
            };
            ds_model_row.notify["text"].connect (() => {
                ds_settings.model = ds_model_row.text;
                config_mgr.save ();
            });
            deepseek_group.add (ds_model_row);

            var ds_action_row = new Adw.ActionRow () {
                title = "Get DeepSeek API Key",
                subtitle = "Manage API keys on the DeepSeek Open Platform"
            };
            var ds_btn = new Gtk.Button.with_label ("Get API Key ↗") { valign = Gtk.Align.CENTER };
            ds_btn.add_css_class ("suggested-action");
            ds_btn.clicked.connect (() => {
                AiConfigManager.open_url ("https://platform.deepseek.com/api_keys");
            });
            ds_action_row.add_suffix (ds_btn);
            deepseek_group.add (ds_action_row);

            enterprise_page.add (deepseek_group);

            // --- NVIDIA NIM Group ---
            var nvidia_group = new Adw.PreferencesGroup () {
                title = "NVIDIA NIM",
                description = "NVIDIA Inference Microservices with GPU-accelerated Llama 3.3, Nemotron, and DeepSeek R1",
                header_suffix = new Gtk.Image.from_icon_name (AiProvider.NVIDIA_NIM.get_icon_name ()) { pixel_size = 28, valign = Gtk.Align.CENTER }
            };

            var nvidia_settings = config_mgr.get_settings_for (AiProvider.NVIDIA_NIM);

            var nvidia_key_row = new Adw.PasswordEntryRow () {
                title = "NVIDIA API Key (nvapi-...)",
                text = nvidia_settings.api_key
            };
            nvidia_key_row.notify["text"].connect (() => {
                nvidia_settings.api_key = nvidia_key_row.text;
                config_mgr.save ();
            });
            nvidia_group.add (nvidia_key_row);

            var nvidia_endpoint_row = new Adw.EntryRow () {
                title = "Base Endpoint",
                text = nvidia_settings.endpoint
            };
            nvidia_endpoint_row.notify["text"].connect (() => {
                nvidia_settings.endpoint = nvidia_endpoint_row.text;
                config_mgr.save ();
            });
            nvidia_group.add (nvidia_endpoint_row);

            var nvidia_model_row = new Adw.EntryRow () {
                title = "Model Name",
                text = nvidia_settings.model
            };
            nvidia_model_row.notify["text"].connect (() => {
                nvidia_settings.model = nvidia_model_row.text;
                config_mgr.save ();
            });
            nvidia_group.add (nvidia_model_row);

            var nvidia_action_row = new Adw.ActionRow () {
                title = "Get NVIDIA NIM API Key",
                subtitle = "Obtain free inference credits and keys at build.nvidia.com"
            };
            var nvidia_btn = new Gtk.Button.with_label ("Get API Key ↗") { valign = Gtk.Align.CENTER };
            nvidia_btn.add_css_class ("suggested-action");
            nvidia_btn.clicked.connect (() => {
                AiConfigManager.open_url ("https://build.nvidia.com");
            });
            nvidia_action_row.add_suffix (nvidia_btn);
            nvidia_group.add (nvidia_action_row);

            enterprise_page.add (nvidia_group);

            // --- Kimi (Moonshot AI) Group ---
            var kimi_group = new Adw.PreferencesGroup () {
                title = "Kimi (Moonshot AI)",
                description = "Ultra-long context window and advanced conversational intelligence",
                header_suffix = new Gtk.Image.from_icon_name (AiProvider.KIMI.get_icon_name ()) { pixel_size = 28, valign = Gtk.Align.CENTER }
            };

            var kimi_settings = config_mgr.get_settings_for (AiProvider.KIMI);

            var kimi_key_row = new Adw.PasswordEntryRow () {
                title = "Moonshot API Key",
                text = kimi_settings.api_key
            };
            kimi_key_row.notify["text"].connect (() => {
                kimi_settings.api_key = kimi_key_row.text;
                config_mgr.save ();
            });
            kimi_group.add (kimi_key_row);

            var kimi_endpoint_row = new Adw.EntryRow () {
                title = "Base Endpoint",
                text = kimi_settings.endpoint
            };
            kimi_endpoint_row.notify["text"].connect (() => {
                kimi_settings.endpoint = kimi_endpoint_row.text;
                config_mgr.save ();
            });
            kimi_group.add (kimi_endpoint_row);

            var kimi_model_row = new Adw.EntryRow () {
                title = "Model Name",
                text = kimi_settings.model
            };
            kimi_model_row.notify["text"].connect (() => {
                kimi_settings.model = kimi_model_row.text;
                config_mgr.save ();
            });
            kimi_group.add (kimi_model_row);

            var kimi_action_row = new Adw.ActionRow () {
                title = "Get Kimi / Moonshot API Key",
                subtitle = "Manage API keys in the Moonshot developer console"
            };
            var kimi_btn = new Gtk.Button.with_label ("Get API Key ↗") { valign = Gtk.Align.CENTER };
            kimi_btn.add_css_class ("suggested-action");
            kimi_btn.clicked.connect (() => {
                AiConfigManager.open_url ("https://platform.moonshot.cn/console/api-keys");
            });
            kimi_action_row.add_suffix (kimi_btn);
            kimi_group.add (kimi_action_row);

            enterprise_page.add (kimi_group);

            // --- Qwen (Alibaba DashScope) Group ---
            var qwen_group = new Adw.PreferencesGroup () {
                title = "Qwen (Alibaba DashScope)",
                description = "Top-tier code generation and scientific modeling (Qwen 2.5 Coder)",
                header_suffix = new Gtk.Image.from_icon_name (AiProvider.QWEN.get_icon_name ()) { pixel_size = 28, valign = Gtk.Align.CENTER }
            };

            var qwen_settings = config_mgr.get_settings_for (AiProvider.QWEN);

            var qwen_key_row = new Adw.PasswordEntryRow () {
                title = "DashScope API Key",
                text = qwen_settings.api_key
            };
            qwen_key_row.notify["text"].connect (() => {
                qwen_settings.api_key = qwen_key_row.text;
                config_mgr.save ();
            });
            qwen_group.add (qwen_key_row);

            var qwen_endpoint_row = new Adw.EntryRow () {
                title = "Base Endpoint",
                text = qwen_settings.endpoint
            };
            qwen_endpoint_row.notify["text"].connect (() => {
                qwen_settings.endpoint = qwen_endpoint_row.text;
                config_mgr.save ();
            });
            qwen_group.add (qwen_endpoint_row);

            var qwen_model_row = new Adw.EntryRow () {
                title = "Model Name",
                text = qwen_settings.model
            };
            qwen_model_row.notify["text"].connect (() => {
                qwen_settings.model = qwen_model_row.text;
                config_mgr.save ();
            });
            qwen_group.add (qwen_model_row);

            var qwen_action_row = new Adw.ActionRow () {
                title = "Get DashScope API Key",
                subtitle = "Manage API keys on Alibaba Cloud DashScope Console"
            };
            var qwen_btn = new Gtk.Button.with_label ("Get API Key ↗") { valign = Gtk.Align.CENTER };
            qwen_btn.add_css_class ("suggested-action");
            qwen_btn.clicked.connect (() => {
                AiConfigManager.open_url ("https://dashscope.console.aliyun.com/apiKey");
            });
            qwen_action_row.add_suffix (qwen_btn);
            qwen_group.add (qwen_action_row);

            enterprise_page.add (qwen_group);

            this.add (enterprise_page);

            // ==========================================
            // Page 3: Local & Custom AI (Ollama, LM Studio, Custom)
            // ==========================================
            var local_page = new Adw.PreferencesPage () {
                title = "Local & Custom",
                icon_name = "computer-symbolic"
            };

            // --- Ollama Group ---
            var ollama_group = new Adw.PreferencesGroup () {
                title = "Ollama (Local)",
                description = "Run open-weights models locally via Ollama service (no API key required)",
                header_suffix = new Gtk.Image.from_icon_name (AiProvider.OLLAMA.get_icon_name ()) { pixel_size = 28, valign = Gtk.Align.CENTER }
            };

            var ollama_settings = config_mgr.get_settings_for (AiProvider.OLLAMA);

            var ollama_endpoint_row = new Adw.EntryRow () {
                title = "Base Endpoint",
                text = ollama_settings.endpoint
            };
            ollama_endpoint_row.notify["text"].connect (() => {
                ollama_settings.endpoint = ollama_endpoint_row.text;
                config_mgr.save ();
            });
            ollama_group.add (ollama_endpoint_row);

            var ollama_model_row = new Adw.EntryRow () {
                title = "Model Name",
                text = ollama_settings.model
            };
            ollama_model_row.notify["text"].connect (() => {
                ollama_settings.model = ollama_model_row.text;
                config_mgr.save ();
            });
            ollama_group.add (ollama_model_row);

            local_page.add (ollama_group);

            // --- LM Studio (Local Server) Group ---
            var lm_studio_group = new Adw.PreferencesGroup () {
                title = "LM Studio (Local Server)",
                description = "Connect to LM Studio's OpenAI-compatible local inference server (port 1234)",
                header_suffix = new Gtk.Image.from_icon_name (AiProvider.LM_STUDIO.get_icon_name ()) { pixel_size = 28, valign = Gtk.Align.CENTER }
            };

            var lm_settings = config_mgr.get_settings_for (AiProvider.LM_STUDIO);

            var lm_endpoint_row = new Adw.EntryRow () {
                title = "Base Endpoint",
                text = lm_settings.endpoint
            };
            lm_endpoint_row.notify["text"].connect (() => {
                lm_settings.endpoint = lm_endpoint_row.text;
                config_mgr.save ();
            });
            lm_studio_group.add (lm_endpoint_row);

            var lm_model_row = new Adw.EntryRow () {
                title = "Model Name",
                text = lm_settings.model
            };
            lm_model_row.notify["text"].connect (() => {
                lm_settings.model = lm_model_row.text;
                config_mgr.save ();
            });
            lm_studio_group.add (lm_model_row);

            var lm_action_row = new Adw.ActionRow () {
                title = "LM Studio Website",
                subtitle = "Discover, download, and run any open-weights GGUF model locally with GPU acceleration"
            };
            var lm_btn = new Gtk.Button.with_label ("Visit lmstudio.ai ↗") { valign = Gtk.Align.CENTER };
            lm_btn.add_css_class ("suggested-action");
            lm_btn.clicked.connect (() => {
                AiConfigManager.open_url ("https://lmstudio.ai");
            });
            lm_action_row.add_suffix (lm_btn);
            lm_studio_group.add (lm_action_row);

            var lm_help_row = new Adw.ActionRow () {
                title = "Local Server Instructions",
                subtitle = "In LM Studio: click Developer tab (<->) on the left sidebar, load a model, and toggle 'Start Server'."
            };
            lm_studio_group.add (lm_help_row);

            local_page.add (lm_studio_group);

            // --- Cherry Studio / LocalAI Group ---
            var cherry_group = new Adw.PreferencesGroup () {
                title = "Cherry Studio / LocalAI (Local)",
                description = "Connect to Cherry Studio, LocalAI, or local llama.cpp servers (ports 23333 / 8080)",
                header_suffix = new Gtk.Image.from_icon_name (AiProvider.CHERRY_STUDIO.get_icon_name ()) { pixel_size = 28, valign = Gtk.Align.CENTER }
            };

            var cherry_settings = config_mgr.get_settings_for (AiProvider.CHERRY_STUDIO);

            var cherry_endpoint_row = new Adw.EntryRow () {
                title = "Base Endpoint",
                text = cherry_settings.endpoint
            };
            cherry_endpoint_row.notify["text"].connect (() => {
                cherry_settings.endpoint = cherry_endpoint_row.text;
                config_mgr.save ();
            });
            cherry_group.add (cherry_endpoint_row);

            var cherry_model_row = new Adw.EntryRow () {
                title = "Model Name",
                text = cherry_settings.model
            };
            cherry_model_row.notify["text"].connect (() => {
                cherry_settings.model = cherry_model_row.text;
                config_mgr.save ();
            });
            cherry_group.add (cherry_model_row);

            local_page.add (cherry_group);

            // --- Antigravity Agent Harness Group ---
            var agy_group = new Adw.PreferencesGroup () {
                title = "Antigravity CLI (agy Agent Harness)",
                description = "Use Google DeepMind's agentic CLI harness (~/.local/bin/agy) for local code tasks",
                header_suffix = new Gtk.Image.from_icon_name (AiProvider.ANTIGRAVITY.get_icon_name ()) { pixel_size = 28, valign = Gtk.Align.CENTER }
            };

            var agy_settings = config_mgr.get_settings_for (AiProvider.ANTIGRAVITY);

            var agy_model_row = new Adw.EntryRow () {
                title = "Preferred Model / Agent Profile",
                text = agy_settings.model
            };
            agy_model_row.notify["text"].connect (() => {
                agy_settings.model = agy_model_row.text;
                config_mgr.save ();
            });
            agy_group.add (agy_model_row);

            var agy_status_row = new Adw.ActionRow () {
                title = "Harness Status",
                subtitle = (Imladris.AI.ElrondEngineController.find_agy_binary () != null)
                    ? "Antigravity CLI detected: %s".printf (Imladris.AI.ElrondEngineController.find_agy_binary ())
                    : "Not found in ~/.local/bin or PATH"
            };
            agy_group.add (agy_status_row);

            local_page.add (agy_group);

            // --- Custom OpenAI Compatible Group ---
            var custom_group = new Adw.PreferencesGroup () {
                title = "Custom OpenAI-Compatible Endpoint",
                description = "Connect to any provider supporting standard OpenAI /v1/chat/completions",
                header_suffix = new Gtk.Image.from_icon_name (AiProvider.CUSTOM.get_icon_name ()) { pixel_size = 28, valign = Gtk.Align.CENTER }
            };

            var custom_settings = config_mgr.get_settings_for (AiProvider.CUSTOM);

            var custom_endpoint_row = new Adw.EntryRow () {
                title = "Base Endpoint",
                text = custom_settings.endpoint
            };
            custom_endpoint_row.notify["text"].connect (() => {
                custom_settings.endpoint = custom_endpoint_row.text;
                config_mgr.save ();
            });
            custom_group.add (custom_endpoint_row);

            var custom_key_row = new Adw.PasswordEntryRow () {
                title = "API Key (Optional)",
                text = custom_settings.api_key
            };
            custom_key_row.notify["text"].connect (() => {
                custom_settings.api_key = custom_key_row.text;
                config_mgr.save ();
            });
            custom_group.add (custom_key_row);

            var custom_model_row = new Adw.EntryRow () {
                title = "Model Name",
                text = custom_settings.model
            };
            custom_model_row.notify["text"].connect (() => {
                custom_settings.model = custom_model_row.text;
                config_mgr.save ();
            });
            custom_group.add (custom_model_row);

            local_page.add (custom_group);

            this.add (local_page);
        }
    }
}
