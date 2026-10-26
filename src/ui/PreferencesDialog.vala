using GLib;
using Gtk;
using Adw;
using Imladris.Core;

namespace Imladris.UI {

    public class PreferencesDialog : Adw.PreferencesDialog {

        public PreferencesDialog () {
            Object (title: "Preferences");

            // Page 1: General & Rendering
            var gen_page = new Adw.PreferencesPage () {
                title = "General",
                icon_name = "preferences-system-symbolic"
            };

            // Appearance & Theming Group
            var appearance_group = new Adw.PreferencesGroup () {
                title = "Appearance",
                description = "Choose your color scheme and editor styling"
            };

            var theme_row = new Adw.ActionRow () {
                title = "Theme",
                subtitle = "System Theme / Light / Dark / Eye Friendly"
            };

            var theme_selector = new ThemeSelectorWidget ();
            theme_row.add_suffix (theme_selector);
            appearance_group.add (theme_row);
            gen_page.add (appearance_group);

            var hw_group = new Adw.PreferencesGroup () {
                title = "Hardware & Rendering",
                description = "Configure GPU acceleration for previews and plots"
            };

            var hw_row = new Adw.SwitchRow () {
                title = "Hardware Acceleration",
                subtitle = "Use the GPU for WebKit previews. Turn off if you see crashes or artifacts on older hardware, virtual machines or problematic drivers.",
                active = Core.SettingsManager.get_default ().hardware_acceleration_enabled
            };
            hw_row.notify["active"].connect (() => {
                Core.SettingsManager.get_default ().hardware_acceleration_enabled = hw_row.active;
            });

            hw_group.add (hw_row);
            gen_page.add (hw_group);
            this.add (gen_page);

            // Page 2: AI Engine Configuration
            var ai_config_mgr = AiConfigManager.get_default ();

            var ai_page = new Adw.PreferencesPage () {
                title = "AI Assistant",
                icon_name = "system-run-symbolic"
            };

            var ai_general_group = new Adw.PreferencesGroup () {
                title = "Active AI Provider",
                description = "Select the default AI provider for code explanation, error repair, and plot generation"
            };

            var provider_dropdown_row = new Adw.ComboRow () {
                title = "Active Provider",
                subtitle = "Choose from Google Gemini, Claude, OpenAI, DeepSeek, Kimi, Qwen, Cursor, NVIDIA NIM, Ollama, LM Studio, or Custom"
            };

            var provider_list = new Gtk.StringList (null);
            provider_list.append ("🌟 Google Gemini (Google AI Studio)");
            provider_list.append ("🎭 Claude (Anthropic API)");
            provider_list.append ("🟢 OpenAI (GPT-4o / o1 / o3)");
            provider_list.append ("🧠 DeepSeek (Chat & R1 Reasoner)");
            provider_list.append ("🌙 Kimi (Moonshot AI)");
            provider_list.append ("⚡ Qwen (Alibaba DashScope)");
            provider_list.append ("🖱️ Cursor API Compatibility");
            provider_list.append ("🟩 NVIDIA NIM (integrate.api.nvidia.com)");
            provider_list.append ("🦙 Ollama (localhost:11434)");
            provider_list.append ("🔮 LM Studio (localhost:1234)");
            provider_list.append ("⚙️ Custom OpenAI-Compatible");
            provider_dropdown_row.model = provider_list;
            provider_dropdown_row.selected = (uint) ai_config_mgr.active_provider;

            provider_dropdown_row.notify["selected"].connect (() => {
                ai_config_mgr.active_provider = (AiProvider) provider_dropdown_row.selected;
            });
            ai_general_group.add (provider_dropdown_row);

            var temp_row = new Adw.ActionRow () {
                title = "Temperature",
                subtitle = "Higher values increase creativity; lower values yield deterministic code"
            };
            var temp_spin = new Gtk.SpinButton.with_range (0.0, 1.0, 0.05) {
                valign = Gtk.Align.CENTER,
                value = ai_config_mgr.temperature
            };
            temp_spin.value_changed.connect (() => {
                ai_config_mgr.temperature = temp_spin.value;
            });
            temp_row.add_suffix (temp_spin);
            ai_general_group.add (temp_row);

            ai_page.add (ai_general_group);

            // Cloud API Keys Quick Links Group
            var keys_group = new Adw.PreferencesGroup () {
                title = "API Credentials & Portals",
                description = "Quick access to generate and manage developer API keys"
            };

            // Gemini Quick Row
            var gemini_key_row = new Adw.ActionRow () {
                title = "Google Gemini (Google AI Studio)",
                subtitle = "Free API keys with generous rate limits for Gemini 2.0 Flash and 1.5 Pro"
            };
            var btn_gemini_link = new Gtk.Button.with_label ("Get Key ↗") { valign = Gtk.Align.CENTER };
            btn_gemini_link.clicked.connect (() => {
                AiConfigManager.open_url ("https://aistudio.google.com/app/apikey");
            });
            gemini_key_row.add_suffix (btn_gemini_link);
            keys_group.add (gemini_key_row);

            // Claude Quick Row
            var claude_key_row = new Adw.ActionRow () {
                title = "Claude (Anthropic Console)",
                subtitle = "Access Claude 3.5 Sonnet, Haiku, and Opus models"
            };
            var btn_claude_link = new Gtk.Button.with_label ("Get Key ↗") { valign = Gtk.Align.CENTER };
            btn_claude_link.clicked.connect (() => {
                AiConfigManager.open_url ("https://console.anthropic.com/settings/keys");
            });
            claude_key_row.add_suffix (btn_claude_link);
            keys_group.add (claude_key_row);

            // OpenAI Quick Row
            var openai_key_row = new Adw.ActionRow () {
                title = "OpenAI Platform",
                subtitle = "Access GPT-4o, GPT-4o-mini, o1, and o3-mini models"
            };
            var btn_openai_link = new Gtk.Button.with_label ("Get Key ↗") { valign = Gtk.Align.CENTER };
            btn_openai_link.clicked.connect (() => {
                AiConfigManager.open_url ("https://platform.openai.com/api-keys");
            });
            openai_key_row.add_suffix (btn_openai_link);
            keys_group.add (openai_key_row);

            // DeepSeek Quick Row
            var deepseek_key_row = new Adw.ActionRow () {
                title = "DeepSeek API",
                subtitle = "Access DeepSeek V3 and DeepSeek R1 reasoning models"
            };
            var btn_ds_link = new Gtk.Button.with_label ("Get Key ↗") { valign = Gtk.Align.CENTER };
            btn_ds_link.clicked.connect (() => {
                AiConfigManager.open_url ("https://platform.deepseek.com/api_keys");
            });
            deepseek_key_row.add_suffix (btn_ds_link);
            keys_group.add (deepseek_key_row);

            // Kimi Quick Row
            var kimi_key_row = new Adw.ActionRow () {
                title = "Kimi (Moonshot AI)",
                subtitle = "Access Moonshot v1 8k/32k/128k long-context models"
            };
            var btn_kimi_link = new Gtk.Button.with_label ("Get Key ↗") { valign = Gtk.Align.CENTER };
            btn_kimi_link.clicked.connect (() => {
                AiConfigManager.open_url ("https://platform.moonshot.cn/console/api-keys");
            });
            kimi_key_row.add_suffix (btn_kimi_link);
            keys_group.add (kimi_key_row);

            // Qwen Quick Row
            var qwen_key_row = new Adw.ActionRow () {
                title = "Qwen (Alibaba DashScope)",
                subtitle = "Access Qwen 2.5 Coder 32B/7B and Qwen-Plus/Max"
            };
            var btn_qwen_link = new Gtk.Button.with_label ("Get Key ↗") { valign = Gtk.Align.CENTER };
            btn_qwen_link.clicked.connect (() => {
                AiConfigManager.open_url ("https://dashscope.console.aliyun.com/apiKey");
            });
            qwen_key_row.add_suffix (btn_qwen_link);
            keys_group.add (qwen_key_row);

            // Cursor Quick Row
            var cursor_key_row = new Adw.ActionRow () {
                title = "Cursor API Compatibility",
                subtitle = "Use Cursor account keys or Cursor-compatible proxy endpoints"
            };
            var btn_cursor_link = new Gtk.Button.with_label ("Portal ↗") { valign = Gtk.Align.CENTER };
            btn_cursor_link.clicked.connect (() => {
                AiConfigManager.open_url ("https://cursor.com");
            });
            cursor_key_row.add_suffix (btn_cursor_link);
            keys_group.add (cursor_key_row);

            // NVIDIA NIM Quick Row
            var nvidia_key_row = new Adw.ActionRow () {
                title = "NVIDIA NIM (build.nvidia.com)",
                subtitle = "High-throughput cloud endpoints for Llama 3.3, Nemotron, and DeepSeek R1"
            };
            var btn_nvidia_link = new Gtk.Button.with_label ("Get Key ↗") { valign = Gtk.Align.CENTER };
            btn_nvidia_link.clicked.connect (() => {
                AiConfigManager.open_url ("https://build.nvidia.com");
            });
            nvidia_key_row.add_suffix (btn_nvidia_link);
            keys_group.add (nvidia_key_row);

            ai_page.add (keys_group);
            this.add (ai_page);
        }
    }
}
