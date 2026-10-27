using GLib;
using Gtk;
using Adw;
using Imladris.Core;

namespace Imladris {

    public class AssistantPanel : Gtk.Box {

        public AiClient ai_client { get; private set; }

        private AiConfigManager config_mgr;
        private Gtk.TextView chat_view;
        private Gtk.Entry prompt_entry;
        private Gtk.Button send_btn;
        private Gtk.Button stop_btn;
        private Gtk.DropDown engine_dropdown;
        private Gtk.DropDown model_dropdown;
        private Gtk.StringList model_string_list;
        private Adw.Banner api_key_banner;
        private Gtk.Label status_lbl;
        private Window parent_window;
        private bool is_generating = false;
        private bool updating_model_list = false;

        public AssistantPanel (Window window) {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 6);
            this.parent_window = window;
            this.config_mgr = AiConfigManager.get_default ();

            ai_client = new AiClient ();

            setup_ui ();
            connect_signals ();
            sync_with_config ();
        }

        private void setup_ui () {
            this.margin_top = 8;
            this.margin_bottom = 8;
            this.margin_start = 8;
            this.margin_end = 8;

            // 1. Header controls: Engine Selector + Model Selector + Settings
            var header_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);

            engine_dropdown = new Gtk.DropDown.from_strings ({
                "🌟 Google Gemini",
                "🎭 Claude (Anthropic)",
                "🟢 OpenAI (GPT-4o / o1)",
                "🧠 DeepSeek (Chat & R1)",
                "🌙 Kimi (Moonshot)",
                "⚡ Qwen (DashScope)",
                "🖱️ Cursor API Compatibility",
                "🟩 NVIDIA NIM",
                "🦙 Ollama (Local)",
                "🔮 LM Studio (Local: 1234)",
                "⚙️ Custom Provider"
            });
            engine_dropdown.hexpand = true;
            engine_dropdown.tooltip_text = "Select active AI provider";
            header_box.append (engine_dropdown);

            model_string_list = new Gtk.StringList (null);
            model_dropdown = new Gtk.DropDown (model_string_list, null) {
                tooltip_text = "Select model"
            };
            header_box.append (model_dropdown);

            var settings_btn = new Gtk.Button.from_icon_name ("emblem-system-symbolic") {
                tooltip_text = "Configure AI Keys & Endpoints"
            };
            settings_btn.add_css_class ("flat");
            settings_btn.clicked.connect (open_settings_dialog);
            header_box.append (settings_btn);

            this.append (header_box);

            // 2. Missing API Key Banner
            api_key_banner = new Adw.Banner ("No API key configured") {
                button_label = "Configure Key",
                revealed = false
            };
            api_key_banner.button_clicked.connect (open_settings_dialog);
            this.append (api_key_banner);

            // 3. Quick Action Buttons Pill Strip
            var quick_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4);

            var btn_explain = new Gtk.Button.with_label ("Explain");
            btn_explain.add_css_class ("flat");
            btn_explain.tooltip_text = "Explain selected text or active document";
            btn_explain.clicked.connect (() => {
                var doc = parent_window.get_active_document ();
                if (doc != null) {
                    string sel = get_selected_or_buffer_text (doc);
                    send_prompt (@"Explain this code or document chunk in detail:\n\n$sel");
                }
            });

            var btn_fix = new Gtk.Button.with_label ("Fix Syntax");
            btn_fix.add_css_class ("flat");
            btn_fix.tooltip_text = "Check syntax and fix errors in selection";
            btn_fix.clicked.connect (() => {
                var doc = parent_window.get_active_document ();
                if (doc != null) {
                    string sel = get_selected_or_buffer_text (doc);
                    send_prompt (@"Check this code for errors or improvements and provide the corrected version:\n\n$sel");
                }
            });

            var btn_rplot = new Gtk.Button.with_label ("Add R Plot");
            btn_rplot.add_css_class ("flat");
            btn_rplot.tooltip_text = "Generate a Quarto ggplot2 visualization chunk";
            btn_rplot.clicked.connect (() => {
                send_prompt ("Generate a complete Quarto {r} code chunk creating a clean ggplot2 visualization for mtcars with custom theme.");
            });

            var btn_insert = new Gtk.Button.with_label ("Insert at Cursor ↵");
            btn_insert.add_css_class ("suggested-action");
            btn_insert.tooltip_text = "Insert output into active document at cursor";
            btn_insert.clicked.connect (() => {
                var doc = parent_window.get_active_document ();
                if (doc != null) {
                    string full_resp = chat_view.buffer.text;
                    doc.source_buffer.insert_at_cursor (full_resp + "\n", -1);
                }
            });

            var btn_clear = new Gtk.Button.from_icon_name ("user-trash-symbolic") {
                tooltip_text = "Clear Chat History"
            };
            btn_clear.add_css_class ("flat");
            btn_clear.clicked.connect (() => {
                chat_view.buffer.text = "";
                status_lbl.label = @"Ready ($(config_mgr.active_provider.get_short_name ()))";
            });

            quick_box.append (btn_explain);
            quick_box.append (btn_fix);
            quick_box.append (btn_rplot);
            quick_box.append (btn_insert);
            quick_box.append (btn_clear);

            var quick_scroller = new Gtk.ScrolledWindow () {
                hscrollbar_policy = Gtk.PolicyType.AUTOMATIC,
                vscrollbar_policy = Gtk.PolicyType.NEVER,
                child = quick_box
            };
            this.append (quick_scroller);

            // 5. Conversation History / Output View
            chat_view = new Gtk.TextView () {
                editable = false,
                wrap_mode = Gtk.WrapMode.WORD_CHAR,
                monospace = true,
                top_margin = 8,
                bottom_margin = 8,
                left_margin = 8,
                right_margin = 8
            };
            var chat_scroller = new Gtk.ScrolledWindow () {
                child = chat_view,
                hexpand = true,
                vexpand = true
            };
            this.append (chat_scroller);

            // 6. Status Label
            status_lbl = new Gtk.Label ("Ready") {
                xalign = 0.0f
            };
            status_lbl.add_css_class ("dim-label");
            this.append (status_lbl);

            // 7. User Prompt Entry Box + Send / Stop Buttons
            var input_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
            prompt_entry = new Gtk.Entry () {
                placeholder_text = "Write with Elrond Assistance (AI) or ask for code/plots...",
                hexpand = true
            };
            prompt_entry.activate.connect (() => {
                if (!is_generating && prompt_entry.text.strip ().length > 0) {
                    send_prompt (prompt_entry.text.strip ());
                    prompt_entry.text = "";
                }
            });
            input_box.append (prompt_entry);

            stop_btn = new Gtk.Button.from_icon_name ("process-stop-symbolic") {
                tooltip_text = "Cancel Request",
                visible = false
            };
            stop_btn.add_css_class ("destructive-action");
            stop_btn.clicked.connect (() => {
                ai_client.cancel_current_request ();
            });
            input_box.append (stop_btn);

            send_btn = new Gtk.Button.from_icon_name ("mail-send-symbolic") {
                tooltip_text = "Send Request"
            };
            send_btn.add_css_class ("suggested-action");
            send_btn.clicked.connect (() => {
                if (!is_generating && prompt_entry.text.strip ().length > 0) {
                    send_prompt (prompt_entry.text.strip ());
                    prompt_entry.text = "";
                }
            });
            input_box.append (send_btn);

            this.append (input_box);
        }

        private void connect_signals () {
            engine_dropdown.notify["selected"].connect (() => {
                uint sel = engine_dropdown.selected;
                if ((uint) config_mgr.active_provider != sel) {
                    config_mgr.active_provider = (AiProvider) sel;
                }
                update_model_dropdown_for_provider (config_mgr.active_provider);
                check_key_status ();
            });

            model_dropdown.notify["selected"].connect (() => {
                if (updating_model_list) return;
                var item = model_string_list.get_string (model_dropdown.selected);
                if (item != null && item.length > 0) {
                    var s = config_mgr.get_settings_for (config_mgr.active_provider);
                    s.model = item;
                    config_mgr.save ();
                    status_lbl.label = @"Ready ($(config_mgr.active_provider.get_short_name ()) - $item)";
                }
            });

            config_mgr.config_changed.connect (() => {
                check_key_status ();
            });

            config_mgr.provider_changed.connect ((prov) => {
                sync_with_config ();
            });
        }

        private void sync_with_config () {
            uint target_idx = (uint) config_mgr.active_provider;
            if (engine_dropdown.selected != target_idx) {
                engine_dropdown.selected = target_idx;
            }
            update_model_dropdown_for_provider (config_mgr.active_provider);
            check_key_status ();
        }

        private void update_model_dropdown_for_provider (AiProvider provider) {
            updating_model_list = true;
            while (model_string_list.get_n_items () > 0) {
                model_string_list.remove (0);
            }

            string[] rec = provider.get_recommended_models ();
            string current_model = config_mgr.get_model_for (provider);
            uint selected_idx = 0;

            for (uint i = 0; i < rec.length; i++) {
                model_string_list.append (rec[i]);
                if (rec[i] == current_model) {
                    selected_idx = i;
                }
            }

            // If current model is custom and not in recommended list, append it
            if (current_model.length > 0) {
                bool found = false;
                for (uint i = 0; i < rec.length; i++) {
                    if (rec[i] == current_model) {
                        found = true;
                        break;
                    }
                }
                if (!found) {
                    model_string_list.append (current_model);
                    selected_idx = model_string_list.get_n_items () - 1;
                }
            }

            model_dropdown.selected = selected_idx;
            updating_model_list = false;

            status_lbl.label = @"Ready ($(provider.get_short_name ()) - $current_model)";
        }

        private void check_key_status () {
            if (Core.SettingsManager.get_default ().elrond_enabled) {
                api_key_banner.revealed = false;
                return;
            }
            var prov = config_mgr.active_provider;
            if (prov.requires_api_key () && !config_mgr.has_valid_key (prov)) {
                api_key_banner.title = @"No API key for $(prov.get_short_name ()).";
                api_key_banner.revealed = true;
            } else {
                api_key_banner.revealed = false;
            }
        }

        private string get_selected_or_buffer_text (DocumentPage doc) {
            Gtk.TextIter start, end;
            if (doc.source_buffer.get_selection_bounds (out start, out end)) {
                return doc.source_buffer.get_text (start, end, false);
            }
            return doc.source_buffer.text;
        }

        public void send_prompt (string user_prompt) {
            var settings = Core.SettingsManager.get_default ();
            if (settings.elrond_enabled) {
                var elrond_engine = Imladris.AI.ElrondEngineController.get_default ();
                string model_name = settings.active_model_name;

                append_to_chat (@"👤 You:\n$user_prompt\n\n🤖 Thinking ($model_name)...");
                status_lbl.label = @"Generating response via Elrond Local AI ($model_name)...";
                set_generating_state (true);

                var doc = parent_window != null ? parent_window.get_active_document () : null;
                string doc_lang = doc != null ? doc.doc_type : "markdown";
                string doc_text = doc != null ? doc.source_buffer.text : "";

                elrond_engine.write_with_elrond.begin (doc_lang, doc_text, "", user_prompt, (obj, res) => {
                    set_generating_state (false);
                    try {
                        string response = elrond_engine.write_with_elrond.end (res);
                        append_to_chat (@"🧙 Elrond ($model_name):\n$response\n");
                        status_lbl.label = @"Ready (Elrond Local AI - $model_name)";
                    } catch (GLib.IOError.CANCELLED c_err) {
                        append_to_chat ("⚠️ Request cancelled.\n");
                        status_lbl.label = "Request cancelled";
                    } catch (GLib.Error e) {
                        append_to_chat (@"✖ Elrond Error: $(e.message)\n");
                        status_lbl.label = "Error during generation";
                    }
                });
                return;
            }

            var provider = config_mgr.active_provider;
            string model = config_mgr.get_model_for (provider);

            append_to_chat (@"👤 You:\n$user_prompt\n\n🤖 Thinking ($model)...");
            status_lbl.label = @"Generating response via $(provider.get_short_name ())...";

            set_generating_state (true);

            string sys_prompt = "You are Elrond Assistance (AI), an expert data science and scientific writing copilot inside Imladris IDE (R, Python, SQL, HTML, Quarto, R Markdown). Deliver concise, correct code, statistical functions, visualizations, and explanations.";

            ai_client.send_chat_completion_async.begin (sys_prompt, user_prompt, null, (obj, res) => {
                set_generating_state (false);
                try {
                    string response = ai_client.send_chat_completion_async.end (res);
                    append_to_chat (@"🧙 Elrond ($model):\n$response\n");
                    status_lbl.label = @"Ready ($(provider.get_short_name ()))";
                } catch (GLib.IOError.CANCELLED c_err) {
                    append_to_chat ("⚠️ Request cancelled.\n");
                    status_lbl.label = "Request cancelled";
                } catch (GLib.Error e) {
                    append_to_chat (@"✖ AI Request Error: $(e.message)\n");
                    status_lbl.label = "Error during generation";
                    check_key_status ();
                }
            });
        }

        private void set_generating_state (bool generating) {
            is_generating = generating;
            send_btn.visible = !generating;
            stop_btn.visible = generating;
            prompt_entry.sensitive = !generating;
        }

        private void append_to_chat (string text) {
            Gtk.TextIter end;
            chat_view.buffer.get_end_iter (out end);
            chat_view.buffer.insert (ref end, text + "\n", -1);

            // Auto-scroll to bottom
            var mark = chat_view.buffer.create_mark (null, end, false);
            chat_view.scroll_to_mark (mark, 0.05f, false, 0.0f, 1.0f);
        }

        private void open_settings_dialog () {
            var dialog = new UI.AiSettingsDialog ();
            dialog.present (parent_window);
        }
    }
}
