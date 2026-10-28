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

            var accent_row = new Adw.ActionRow () {
                title = "Accent Color",
                subtitle = Core.SettingsManager.get_default ().accent_color.get_display_name ()
            };

            var accent_selector = new AccentColorSelectorWidget ();
            accent_selector.accent_selected.connect ((accent) => {
                accent_row.subtitle = accent.get_display_name ();
            });
            Core.SettingsManager.get_default ().accent_color_changed.connect ((accent) => {
                accent_row.subtitle = accent.get_display_name ();
            });
            accent_row.add_suffix (accent_selector);
            appearance_group.add (accent_row);

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

            var about_group = new Adw.PreferencesGroup () {
                title = "About Imladris",
                description = "Scientific writing, notebooks and data work • Proudly developed with Gemini Assistance"
            };

            var about_row = new Adw.ActionRow () {
                title = "Imladris v0.12.0",
                subtitle = "Documentation, credits, and project inspiration"
            };
            about_row.add_prefix (new Gtk.Image.from_icon_name ("help-browser-symbolic") { pixel_size = 22 });

            var btn_open_about = new Gtk.Button.with_label ("About...") {
                valign = Gtk.Align.CENTER
            };
            btn_open_about.clicked.connect (() => {
                var app = GLib.Application.get_default () as Application;
                if (app != null) {
                    var win = app.active_window as Window;
                    if (win != null) win.show_about_dialog ();
                }
            });
            about_row.add_suffix (btn_open_about);
            about_group.add (about_row);
            gen_page.add (about_group);

            this.add (gen_page);

            // Page 2: AI Engine Configuration
            var ai_config_mgr = AiConfigManager.get_default ();

            var ai_page = new Adw.PreferencesPage () {
                title = "AI & Elrond",
                icon_name = "system-run-symbolic"
            };

            // Write with Elrond Assistance (AI) Group
            var elrond_group = new Adw.PreferencesGroup () {
                title = "Write with Elrond Assistance (AI)",
                description = "Zero-configuration local coding and data science copilot for R, Python, SQL, and HTML",
                header_suffix = new Gtk.Image.from_icon_name ("ai-elrond") { pixel_size = 28, valign = Gtk.Align.CENTER }
            };

            var settings = Core.SettingsManager.get_default ();
            var elrond_engine = Imladris.AI.ElrondEngineController.get_default ();

            var elrond_enable_row = new Adw.SwitchRow () {
                title = "Enable Elrond Assistance (AI)",
                subtitle = "Automatically configures and runs the local AI engine in the background",
                active = settings.elrond_enabled
            };

            var elrond_level_row = new Adw.ActionRow () {
                title = "Elrond Assistance Level",
                sensitive = settings.elrond_enabled
            };

            var level_scale = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, 0.0, 2.0, 1.0) {
                valign = Gtk.Align.CENTER,
                hexpand = false,
                width_request = 200,
                draw_value = false,
                round_digits = 0
            };
            level_scale.add_mark (0.0, Gtk.PositionType.BOTTOM, "Low");
            level_scale.add_mark (1.0, Gtk.PositionType.BOTTOM, "Medium");
            level_scale.add_mark (2.0, Gtk.PositionType.BOTTOM, "High");
            level_scale.set_value ((double) settings.elrond_level);

            void update_level_subtitle (int val) {
                switch (val) {
                    case 0:
                        elrond_level_row.subtitle = "Low: On-Demand Only (Manual 'Write with Elrond' trigger)";
                        break;
                    case 1:
                        elrond_level_row.subtitle = "Medium: Smart Autocomplete & Dataframe Awareness (Recommended)";
                        break;
                    case 2:
                        elrond_level_row.subtitle = "High: Full Elrond Copilot & Proactive Code/Graph Suggestions";
                        break;
                    default:
                        elrond_level_row.subtitle = "Select assistance level";
                        break;
                }
            }
            update_level_subtitle ((int) settings.elrond_level);

            level_scale.value_changed.connect (() => {
                int val = (int) (level_scale.get_value () + 0.5);
                settings.elrond_level = (Core.AiAssistanceLevel) val;
                update_level_subtitle (val);
            });
            elrond_level_row.add_suffix (level_scale);

            var elrond_status_row = new Adw.ActionRow () {
                title = "Elrond Engine Status",
                subtitle = settings.elrond_enabled ? "Starting..." : "Disabled"
            };
            var dl_progress = new Gtk.ProgressBar () {
                valign = Gtk.Align.CENTER,
                width_request = 140,
                visible = false
            };
            elrond_status_row.add_suffix (dl_progress);

            elrond_enable_row.notify["active"].connect (() => {
                settings.elrond_enabled = elrond_enable_row.active;
                elrond_level_row.sensitive = elrond_enable_row.active;
            });

            elrond_engine.status_updated.connect ((status_text, is_busy, frac) => {
                elrond_status_row.subtitle = status_text;
                dl_progress.visible = is_busy;
                dl_progress.fraction = frac;
            });

            elrond_group.add (elrond_enable_row);
            elrond_group.add (elrond_level_row);

            var inline_autocomplete_row = new Adw.SwitchRow () {
                title = "Inline AI Autocomplete",
                subtitle = "Suggest code completions inline as you type in R, Python, SQL, and Markdown",
                active = settings.inline_completion_enabled
            };
            inline_autocomplete_row.notify["active"].connect (() => {
                settings.inline_completion_enabled = inline_autocomplete_row.active;
            });
            elrond_group.add (inline_autocomplete_row);

            var inline_edit_row = new Adw.SwitchRow () {
                title = "Inline AI Editing Popover",
                subtitle = "Show inline prompt popover at cursor on 'Write with Elrond Assistance' (Ctrl+Shift+E)",
                active = settings.inline_editing_enabled
            };
            inline_edit_row.notify["active"].connect (() => {
                settings.inline_editing_enabled = inline_edit_row.active;
            });
            elrond_group.add (inline_edit_row);

            var panel_pos_row = new Adw.ActionRow () {
                title = "AI Chat & Side Panel Position",
                subtitle = "Keep the LLM chat and preview panel docked on the left or right side of the editor"
            };

            var pos_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) {
                valign = Gtk.Align.CENTER
            };
            pos_box.add_css_class ("linked");

            var btn_pos_left = new Gtk.ToggleButton.with_label ("◀ Left") {
                active = (settings.chat_panel_position == Core.SidePanelPosition.LEFT)
            };
            var btn_pos_right = new Gtk.ToggleButton.with_label ("Right ▶") {
                active = (settings.chat_panel_position == Core.SidePanelPosition.RIGHT),
                group = btn_pos_left
            };

            btn_pos_left.toggled.connect (() => {
                if (btn_pos_left.active) {
                    settings.chat_panel_position = Core.SidePanelPosition.LEFT;
                }
            });
            btn_pos_right.toggled.connect (() => {
                if (btn_pos_right.active) {
                    settings.chat_panel_position = Core.SidePanelPosition.RIGHT;
                }
            });

            pos_box.append (btn_pos_left);
            pos_box.append (btn_pos_right);
            panel_pos_row.add_suffix (pos_box);
            elrond_group.add (panel_pos_row);

            // Local AI Server Mode Selector (Auto-detect, Ollama, LM Studio, Cherry Studio, Antigravity, Custom)
            var mode_strings = new Gtk.StringList (null);
            mode_strings.append ("⚡ Auto-Detect Local AI (Recommended)");
            mode_strings.append ("🦙 Ollama (localhost:11434)");
            mode_strings.append ("🧪 LM Studio (localhost:1234)");
            mode_strings.append ("🍒 Cherry Studio / LocalAI (localhost:23333 / 8080)");
            mode_strings.append ("🚀 Antigravity CLI (agy Agent Harness)");
            mode_strings.append ("⚙️ Custom Local Server");

            var mode_row = new Adw.ComboRow () {
                title = "Local AI Server & Harness Bridge",
                subtitle = "Connect to running local inference servers or host agent harnesses",
                model = mode_strings,
                selected = (uint) settings.elrond_mode
            };
            mode_row.add_prefix (new Gtk.Image.from_icon_name ("ai-elrond") { pixel_size = 22 });

            var custom_endpoint_row = new Adw.EntryRow () {
                title = "Custom Local Endpoint",
                text = settings.custom_local_endpoint,
                visible = (settings.elrond_mode == Core.ElrondMode.CUSTOM)
            };
            custom_endpoint_row.notify["text"].connect (() => {
                settings.custom_local_endpoint = custom_endpoint_row.text;
            });

            mode_row.notify["selected"].connect (() => {
                var sel_mode = (Core.ElrondMode) mode_row.selected;
                settings.elrond_mode = sel_mode;
                custom_endpoint_row.visible = (sel_mode == Core.ElrondMode.CUSTOM);
                elrond_engine.probe_servers_async.begin ();
            });
            elrond_group.add (mode_row);
            elrond_group.add (custom_endpoint_row);

            var btn_probe = new Gtk.Button.from_icon_name ("view-refresh-symbolic") {
                valign = Gtk.Align.CENTER,
                tooltip_text = "Probe and refresh local AI servers"
            };
            btn_probe.clicked.connect (() => {
                elrond_engine.probe_servers_async.begin ();
            });
            elrond_status_row.add_suffix (btn_probe);
            elrond_group.add (elrond_status_row);

            // Local AI Ecosystem Setup Guide
            var guide_expander = new Adw.ExpanderRow () {
                title = "Local AI & Agent Harness Setup Guide",
                subtitle = "Supported local engines: Ollama, LM Studio, Cherry Studio, and Antigravity"
            };
            guide_expander.add_prefix (new Gtk.Image.from_icon_name ("dialog-information-symbolic"));

            var guide_ollama_row = new Adw.ActionRow () {
                title = "Ollama (Port 11434)",
                subtitle = "Terminal command: ollama run qwen2.5-coder  (or deepseek-r1 / llama3.2)"
            };
            guide_ollama_row.add_prefix (new Gtk.Image.from_icon_name ("ai-ollama") { pixel_size = 22 });
            guide_expander.add_row (guide_ollama_row);

            var guide_lm_row = new Adw.ActionRow () {
                title = "LM Studio (Port 1234)",
                subtitle = "Open LM Studio -> Developer tab (<->) -> Select model and click 'Start Server'"
            };
            guide_lm_row.add_prefix (new Gtk.Image.from_icon_name ("ai-lmstudio") { pixel_size = 22 });
            guide_expander.add_row (guide_lm_row);

            var guide_cherry_row = new Adw.ActionRow () {
                title = "Cherry Studio & LocalAI (Port 23333 or 8080)",
                subtitle = "Runs local OpenAI-compatible inference servers across multiple backends"
            };
            guide_cherry_row.add_prefix (new Gtk.Image.from_icon_name ("ai-custom") { pixel_size = 22 });
            guide_expander.add_row (guide_cherry_row);

            var guide_agy_row = new Adw.ActionRow () {
                title = "Antigravity Agent Harness (agy)",
                subtitle = "Google DeepMind's agentic CLI harness (~/.local/bin/agy) for local code tasks"
            };
            guide_agy_row.add_prefix (new Gtk.Image.from_icon_name ("ai-elrond") { pixel_size = 22 });
            guide_expander.add_row (guide_agy_row);

            elrond_group.add (guide_expander);
            ai_page.add (elrond_group);

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

            var config_row = new Adw.ActionRow () {
                title = "Provider Credentials & Models",
                subtitle = "Configure API keys, custom base URLs, and model identifiers"
            };
            var btn_configure_keys = new Gtk.Button.with_label ("Configure Providers...") {
                valign = Gtk.Align.CENTER
            };
            btn_configure_keys.add_css_class ("suggested-action");
            btn_configure_keys.clicked.connect (() => {
                new UI.AiSettingsDialog ().present (this);
            });
            config_row.add_suffix (btn_configure_keys);
            ai_general_group.add (config_row);

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

        private Adw.ActionRow create_distro_cmd_row (string distro_name, string command_str) {
            var row = new Adw.ActionRow () {
                title = distro_name,
                subtitle = command_str
            };
            var copy_btn = new Gtk.Button.from_icon_name ("edit-copy-symbolic") {
                valign = Gtk.Align.CENTER,
                tooltip_text = "Copy command to clipboard"
            };
            copy_btn.clicked.connect (() => {
                var clipboard = copy_btn.get_clipboard ();
                clipboard.set_text (command_str);
            });
            row.add_suffix (copy_btn);
            return row;
        }
    }
}
