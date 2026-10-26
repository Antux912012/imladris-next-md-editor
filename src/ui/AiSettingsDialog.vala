using GLib;
using Gtk;
using Adw;
using Imladris.Core;

namespace Imladris.UI {

    public class AiSettingsDialog : Adw.PreferencesDialog {

        private AiConfigManager config_mgr;
        private LlamaServerManager server_manager;

        public AiSettingsDialog (LlamaServerManager server_mgr) {
            Object (title: "AI Engine & Model Configuration");
            this.config_mgr = AiConfigManager.get_default ();
            this.server_manager = server_mgr;

            setup_pages ();
        }

        private void setup_pages () {
            // ==========================================
            // Page 1: Cloud Providers (Gemini, DeepSeek, Kimi, Qwen)
            // ==========================================
            var cloud_page = new Adw.PreferencesPage () {
                title = "Cloud AI Providers",
                icon_name = "network-server-symbolic"
            };

            // --- Google Gemini Group ---
            var gemini_group = new Adw.PreferencesGroup () {
                title = "Google Gemini",
                description = "Google DeepMind's flagship models with state-of-the-art multimodal reasoning"
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
            var gemini_btn = new Gtk.Button.with_label ("Get API Key ↗") {
                valign = Gtk.Align.CENTER
            };
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
            var oauth_btn = new Gtk.Button.with_label ("OAuth Info ↗") {
                valign = Gtk.Align.CENTER
            };
            oauth_btn.add_css_class ("flat");
            oauth_btn.clicked.connect (() => {
                AiConfigManager.open_url ("https://cloud.google.com/docs/authentication/token-types#access-contents");
            });
            gemini_oauth_row.add_suffix (oauth_btn);
            gemini_group.add (gemini_oauth_row);

            cloud_page.add (gemini_group);

            // --- DeepSeek Group ---
            var deepseek_group = new Adw.PreferencesGroup () {
                title = "DeepSeek",
                description = "High-performance coding (deepseek-chat) and reasoning (deepseek-reasoner / R1)"
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
            var ds_btn = new Gtk.Button.with_label ("Get API Key ↗") {
                valign = Gtk.Align.CENTER
            };
            ds_btn.add_css_class ("suggested-action");
            ds_btn.clicked.connect (() => {
                AiConfigManager.open_url ("https://platform.deepseek.com/api_keys");
            });
            ds_action_row.add_suffix (ds_btn);
            deepseek_group.add (ds_action_row);

            cloud_page.add (deepseek_group);

            // --- Kimi (Moonshot AI) Group ---
            var kimi_group = new Adw.PreferencesGroup () {
                title = "Kimi (Moonshot AI)",
                description = "Ultra-long context window and advanced conversational intelligence"
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
            var kimi_btn = new Gtk.Button.with_label ("Get API Key ↗") {
                valign = Gtk.Align.CENTER
            };
            kimi_btn.add_css_class ("suggested-action");
            kimi_btn.clicked.connect (() => {
                AiConfigManager.open_url ("https://platform.moonshot.cn/console/api-keys");
            });
            kimi_action_row.add_suffix (kimi_btn);
            kimi_group.add (kimi_action_row);

            cloud_page.add (kimi_group);

            // --- Qwen (Alibaba DashScope) Group ---
            var qwen_group = new Adw.PreferencesGroup () {
                title = "Qwen (Alibaba DashScope)",
                description = "Top-tier code generation and scientific modeling (Qwen 2.5 Coder)"
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
            var qwen_btn = new Gtk.Button.with_label ("Get API Key ↗") {
                valign = Gtk.Align.CENTER
            };
            qwen_btn.add_css_class ("suggested-action");
            qwen_btn.clicked.connect (() => {
                AiConfigManager.open_url ("https://dashscope.console.aliyun.com/apiKey");
            });
            qwen_action_row.add_suffix (qwen_btn);
            qwen_group.add (qwen_action_row);

            cloud_page.add (qwen_group);

            this.add (cloud_page);

            // ==========================================
            // Page 2: Local & Custom AI (Ollama, llama.cpp, Custom)
            // ==========================================
            var local_page = new Adw.PreferencesPage () {
                title = "Local & Custom",
                icon_name = "computer-symbolic"
            };

            // --- Ollama Group ---
            var ollama_group = new Adw.PreferencesGroup () {
                title = "Ollama (Local)",
                description = "Run open-weights models locally via Ollama service (no API key required)"
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

            // --- Offline llama-server Group ---
            var llama_group = new Adw.PreferencesGroup () {
                title = "Offline llama.cpp Server",
                description = "Built-in local inference using downloaded GGUF models"
            };

            var btn_download_1_5b = new Gtk.Button.with_label ("Download Qwen 2.5 Coder 1.5B (GGUF ~1.0 GB)") {
                valign = Gtk.Align.CENTER
            };
            btn_download_1_5b.clicked.connect (() => {
                server_manager.download_model_async.begin (
                    LlamaServerManager.DEFAULT_QWEN_1_5B_URL,
                    LlamaServerManager.DEFAULT_QWEN_1_5B_NAME,
                    (obj, res) => {
                        try {
                            server_manager.download_model_async.end (res);
                        } catch (GLib.Error e) {
                            GLib.warning ("Download error: %s", e.message);
                        }
                    }
                );
            });
            var row_1_5b = new Adw.ActionRow () {
                title = "Qwen 2.5 Coder 1.5B Instruct",
                subtitle = "Lightweight, fast CPU inference"
            };
            row_1_5b.add_suffix (btn_download_1_5b);
            llama_group.add (row_1_5b);

            var btn_download_7b = new Gtk.Button.with_label ("Download Qwen 2.5 Coder 7B (GGUF ~4.7 GB)") {
                valign = Gtk.Align.CENTER
            };
            btn_download_7b.clicked.connect (() => {
                server_manager.download_model_async.begin (
                    LlamaServerManager.DEFAULT_QWEN_7B_URL,
                    LlamaServerManager.DEFAULT_QWEN_7B_NAME,
                    (obj, res) => {
                        try {
                            server_manager.download_model_async.end (res);
                        } catch (GLib.Error e) {
                            GLib.warning ("Download error: %s", e.message);
                        }
                    }
                );
            });
            var row_7b = new Adw.ActionRow () {
                title = "Qwen 2.5 Coder 7B Instruct",
                subtitle = "High capability coding model (requires 8GB+ RAM)"
            };
            row_7b.add_suffix (btn_download_7b);
            llama_group.add (row_7b);

            local_page.add (llama_group);

            // --- Custom OpenAI Compatible Group ---
            var custom_group = new Adw.PreferencesGroup () {
                title = "Custom OpenAI-Compatible Endpoint",
                description = "Connect to any provider supporting standard OpenAI /v1/chat/completions"
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
