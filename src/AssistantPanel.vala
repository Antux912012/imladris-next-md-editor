namespace Imladris {

    public class AssistantPanel : Gtk.Box {

        public AiClient ai_client { get; private set; }
        public LlamaServerManager server_manager { get; private set; }

        private Gtk.TextView chat_view;
        private Gtk.Entry prompt_entry;
        private Gtk.Button send_btn;
        private Gtk.DropDown engine_dropdown;
        private Gtk.ProgressBar download_bar;
        private Gtk.Label status_lbl;
        private Window parent_window;

        public AssistantPanel (Window window) {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 6);
            this.parent_window = window;

            ai_client = new AiClient ();
            server_manager = new LlamaServerManager ();

            setup_ui ();
            connect_signals ();
        }

        private void setup_ui () {
            this.margin_top = 8;
            this.margin_bottom = 8;
            this.margin_start = 8;
            this.margin_end = 8;

            // 1. Header controls: Engine Selector + Settings
            var header_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
            header_box.append (new Gtk.Label ("AI Engine:"));

            engine_dropdown = new Gtk.DropDown.from_strings ({
                "Offline: Qwen 2.5 Coder (Local)",
                "Online: OpenAI / DeepSeek API",
                "Local: Ollama (localhost:11434)"
            });
            engine_dropdown.hexpand = true;
            header_box.append (engine_dropdown);

            var settings_btn = new Gtk.Button.from_icon_name ("emblem-system-symbolic") {
                tooltip_text = "Configure API Key & Endpoints"
            };
            settings_btn.add_css_class ("flat");
            settings_btn.clicked.connect (open_settings_dialog);
            header_box.append (settings_btn);

            this.append (header_box);

            // 2. Download progress bar
            download_bar = new Gtk.ProgressBar () {
                visible = false,
                margin_top = 2,
                margin_bottom = 2
            };
            this.append (download_bar);

            // 3. Quick Action Buttons Pill Strip
            var quick_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4);
            var btn_explain = new Gtk.Button.with_label ("Explain");
            btn_explain.add_css_class ("flat");
            btn_explain.clicked.connect (() => {
                var doc = parent_window.get_active_document ();
                if (doc != null) {
                    string sel = get_selected_or_buffer_text (doc);
                    send_prompt (@"Explain this code or document chunk in detail:\n\n$sel");
                }
            });

            var btn_fix = new Gtk.Button.with_label ("Fix Syntax");
            btn_fix.add_css_class ("flat");
            btn_fix.clicked.connect (() => {
                var doc = parent_window.get_active_document ();
                if (doc != null) {
                    string sel = get_selected_or_buffer_text (doc);
                    send_prompt (@"Check this code for errors or improvements and provide the corrected version:\n\n$sel");
                }
            });

            var btn_rplot = new Gtk.Button.with_label ("Add R Plot");
            btn_rplot.add_css_class ("flat");
            btn_rplot.clicked.connect (() => {
                send_prompt ("Generate a complete Quarto {r} code chunk creating a clean ggplot2 visualization for mtcars with custom theme.");
            });

            var btn_insert = new Gtk.Button.with_label ("Insert at Cursor ↵");
            btn_insert.add_css_class ("suggested-action");
            btn_insert.clicked.connect (() => {
                var doc = parent_window.get_active_document ();
                if (doc != null) {
                    Gtk.TextIter start, end;
                    chat_view.buffer.get_bounds (out start, out end);
                    string full_resp = chat_view.buffer.text;
                    // Extract code block if any or insert full text
                    doc.source_buffer.insert_at_cursor (full_resp + "\n", -1);
                }
            });

            quick_box.append (btn_explain);
            quick_box.append (btn_fix);
            quick_box.append (btn_rplot);
            quick_box.append (btn_insert);

            var quick_scroller = new Gtk.ScrolledWindow () {
                hscrollbar_policy = Gtk.PolicyType.AUTOMATIC,
                vscrollbar_policy = Gtk.PolicyType.NEVER,
                child = quick_box
            };
            this.append (quick_scroller);

            // 4. Conversation History / Output View
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

            // 5. Status Label
            status_lbl = new Gtk.Label ("Ready") {
                xalign = 0.0f
            };
            status_lbl.add_css_class ("dim-label");
            this.append (status_lbl);

            // 6. User Prompt Entry Box
            var input_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
            prompt_entry = new Gtk.Entry () {
                placeholder_text = "Ask AI Assistant or prompt for code...",
                hexpand = true
            };
            prompt_entry.activate.connect (() => {
                if (prompt_entry.text.strip ().length > 0) {
                    send_prompt (prompt_entry.text.strip ());
                    prompt_entry.text = "";
                }
            });
            input_box.append (prompt_entry);

            send_btn = new Gtk.Button.from_icon_name ("mail-send-symbolic") {
                tooltip_text = "Send Request"
            };
            send_btn.add_css_class ("suggested-action");
            send_btn.clicked.connect (() => {
                if (prompt_entry.text.strip ().length > 0) {
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
                if (sel == 0) {
                    ai_client.configure_offline ("http://127.0.0.1:8080/v1", "qwen2.5-coder");
                    status_lbl.label = "Configured for Offline llama-server (localhost:8080)";
                } else if (sel == 1) {
                    ai_client.configure_online (ai_client.endpoint_url, ai_client.api_key, ai_client.model_name);
                    status_lbl.label = @"Configured for Online API ($(ai_client.model_name))";
                } else if (sel == 2) {
                    ai_client.configure_offline ("http://127.0.0.1:11434/v1", "qwen2.5-coder");
                    status_lbl.label = "Configured for local Ollama (localhost:11434)";
                }
            });

            server_manager.download_progress.connect ((progress, text) => {
                download_bar.visible = progress < 1.0;
                download_bar.set_fraction (progress);
                status_lbl.label = text;
            });

            server_manager.server_state_changed.connect ((running, msg) => {
                status_lbl.label = msg;
            });
        }

        private string get_selected_or_buffer_text (DocumentPage doc) {
            Gtk.TextIter start, end;
            if (doc.source_buffer.get_selection_bounds (out start, out end)) {
                return doc.source_buffer.get_text (start, end, false);
            }
            return doc.source_buffer.text;
        }

        public void send_prompt (string user_prompt) {
            append_to_chat (@"👤 You:\n$user_prompt\n\n🤖 Thinking...");
            status_lbl.label = "Generating response...";
            send_btn.sensitive = false;

            string sys_prompt = "You are Imladris AI Assistant, an expert in scientific writing (Quarto, R Markdown, Jupyter) and modern web engineering (TypeScript, HTML5, Python). Deliver concise, correct code and explanations.";

            ai_client.send_chat_completion_async.begin (sys_prompt, user_prompt, (obj, res) => {
                send_btn.sensitive = true;
                try {
                    string response = ai_client.send_chat_completion_async.end (res);
                    append_to_chat (@"🤖 Assistant:\n$response\n");
                    status_lbl.label = "Ready";
                } catch (GLib.Error e) {
                    append_to_chat (@"✖ AI Request Error: $(e.message)\n");
                    status_lbl.label = "Error during generation";
                }
            });
        }

        private void append_to_chat (string text) {
            Gtk.TextIter end;
            chat_view.buffer.get_end_iter (out end);
            chat_view.buffer.insert (ref end, text + "\n", -1);
        }

        private void open_settings_dialog () {
            var dialog = new Adw.Window () {
                title = "AI Engine & Model Settings",
                transient_for = parent_window,
                modal = true,
                default_width = 460,
                default_height = 420
            };

            var vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 10) {
                margin_top = 16,
                margin_bottom = 16,
                margin_start = 16,
                margin_end = 16
            };
            dialog.set_content (vbox);

            // Online section
            vbox.append (new Gtk.Label ("<b>Online OpenAI-Compatible Configuration</b>") { use_markup = true, xalign = 0 });
            var entry_endpoint = new Gtk.Entry () { text = ai_client.endpoint_url };
            var entry_key = new Gtk.PasswordEntry () { text = ai_client.api_key };
            var entry_model = new Gtk.Entry () { text = ai_client.model_name };

            var grid = new Gtk.Grid () { row_spacing = 6, column_spacing = 10 };
            grid.attach (new Gtk.Label ("Base URL:"), 0, 0, 1, 1);
            grid.attach (entry_endpoint, 1, 0, 1, 1);
            grid.attach (new Gtk.Label ("API Key:"), 0, 1, 1, 1);
            grid.attach (entry_key, 1, 1, 1, 1);
            grid.attach (new Gtk.Label ("Model:"), 0, 2, 1, 1);
            grid.attach (entry_model, 1, 2, 1, 1);
            vbox.append (grid);

            vbox.append (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));

            // Offline section
            vbox.append (new Gtk.Label ("<b>Offline llama.cpp Local Models</b>") { use_markup = true, xalign = 0 });
            var btn_download_1_5b = new Gtk.Button.with_label ("Download Qwen 2.5 Coder 1.5B (GGUF ~1.0 GB)");
            btn_download_1_5b.clicked.connect (() => {
                dialog.close ();
                server_manager.download_model_async.begin (
                    LlamaServerManager.DEFAULT_QWEN_1_5B_URL,
                    LlamaServerManager.DEFAULT_QWEN_1_5B_NAME,
                    (obj, res) => {
                        try {
                            server_manager.download_model_async.end (res);
                        } catch (GLib.Error e) {
                            status_lbl.label = @"Download Error: $(e.message)";
                        }
                    }
                );
            });
            vbox.append (btn_download_1_5b);

            var btn_download_7b = new Gtk.Button.with_label ("Download Qwen 2.5 Coder 7B (GGUF ~4.7 GB)");
            btn_download_7b.clicked.connect (() => {
                dialog.close ();
                server_manager.download_model_async.begin (
                    LlamaServerManager.DEFAULT_QWEN_7B_URL,
                    LlamaServerManager.DEFAULT_QWEN_7B_NAME,
                    (obj, res) => {
                        try {
                            server_manager.download_model_async.end (res);
                        } catch (GLib.Error e) {
                            status_lbl.label = @"Download Error: $(e.message)";
                        }
                    }
                );
            });
            vbox.append (btn_download_7b);

            var btn_save = new Gtk.Button.with_label ("Save Configuration");
            btn_save.add_css_class ("suggested-action");
            btn_save.clicked.connect (() => {
                ai_client.endpoint_url = entry_endpoint.text;
                ai_client.api_key = entry_key.text;
                ai_client.model_name = entry_model.text;
                dialog.close ();
            });
            vbox.append (btn_save);

            dialog.present ();
        }
    }
}
