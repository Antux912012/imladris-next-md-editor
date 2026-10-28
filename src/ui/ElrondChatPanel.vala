using GLib;
using Gtk;
using Adw;
using Imladris.AI;

namespace Imladris.UI {

    /**
     * ElrondChatMessage
     * Represents a single prompt or AI response in the chat timeline.
     */
    public class ElrondChatMessage : GLib.Object {
        public string sender { get; construct set; } // "user" or "assistant"
        public string text { get; construct set; }
        public int64 timestamp { get; construct set; }

        public ElrondChatMessage (string sender, string text) {
            Object (
                sender: sender,
                text: text,
                timestamp: GLib.get_real_time ()
            );
        }
    }

    /**
     * ElrondChatPanel
     * Integrated Elrond Local AI Copilot Chat Tab.
     * Features context toggle chips, interactive code blocks,
     * "Insert at Cursor", and "Run in Console".
     */
    public class ElrondChatPanel : Gtk.Box {

        private Gtk.ListBox message_list;
        private Gtk.ScrolledWindow scroller;
        private Gtk.TextView prompt_input;
        private Gtk.Button send_btn;
        private Gtk.Button stop_btn;
        private Gtk.Spinner generating_spinner;
        private Gtk.Label status_indicator;

        private Gtk.ToggleButton chip_active_file;
        private Gtk.ToggleButton chip_dataframes;
        private Gtk.ToggleButton chip_last_error;

        private unowned DocumentPage doc_page;
        private unowned PersistentPanelRegistry panel_reg;
        private unowned Window? parent_window;

        private Cancellable? cancellable = null;
        private bool is_busy = false;

        public ElrondChatPanel (DocumentPage page, PersistentPanelRegistry reg, Window? win) {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 0);
            this.doc_page = page;
            this.panel_reg = reg;
            this.parent_window = win;
            this.hexpand = true;
            this.vexpand = true;
            this.add_css_class ("elrond-chat-panel");

            setup_header_bar ();
            setup_context_chips ();
            setup_message_stream ();
            setup_input_bar ();

            add_welcome_message ();
        }

        private void setup_header_bar () {
            var header = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
                margin_top = 4,
                margin_bottom = 4,
                margin_start = 8,
                margin_end = 8
            };
            header.add_css_class ("dock-subtoolbar");

            var icon = new Gtk.Image.from_icon_name ("ai-elrond");
            header.append (icon);

            var title = new Gtk.Label ("Elrond AI") {
                css_classes = { "heading" },
                xalign = 0
            };
            header.append (title);

            status_indicator = new Gtk.Label ("Local Copilot") {
                css_classes = { "dim-label", "caption" },
                margin_start = 4
            };
            header.append (status_indicator);

            generating_spinner = new Gtk.Spinner () {
                spinning = false,
                visible = false,
                margin_start = 4
            };
            header.append (generating_spinner);

            header.append (new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) { hexpand = true });

            var btn_clear = new Gtk.Button.from_icon_name ("edit-clear-all-symbolic") {
                tooltip_text = "Clear Chat History"
            };
            btn_clear.add_css_class ("flat");
            btn_clear.clicked.connect (clear_chat_history);
            header.append (btn_clear);

            var btn_settings = new Gtk.Button.from_icon_name ("preferences-system-symbolic") {
                tooltip_text = "Elrond AI Settings"
            };
            btn_settings.add_css_class ("flat");
            btn_settings.clicked.connect (() => {
                if (parent_window != null) {
                    var dlg = new AiSettingsDialog ();
                    dlg.present (parent_window);
                }
            });
            header.append (btn_settings);

            this.append (header);
        }

        private void setup_context_chips () {
            var chips_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
                margin_start = 8,
                margin_end = 8,
                margin_top = 2,
                margin_bottom = 4
            };

            var lbl = new Gtk.Label ("Context:") {
                css_classes = { "dim-label", "caption" }
            };
            chips_box.append (lbl);

            chip_active_file = new Gtk.ToggleButton.with_label ("+ Active File") {
                active = true,
                tooltip_text = "Feed active document text into AI context"
            };
            chip_active_file.add_css_class ("suggested-chip");
            chips_box.append (chip_active_file);

            chip_dataframes = new Gtk.ToggleButton.with_label ("+ Dataframes") {
                active = true,
                tooltip_text = "Feed active dataframe columns & shapes into AI context"
            };
            chip_dataframes.add_css_class ("suggested-chip");
            chips_box.append (chip_dataframes);

            chip_last_error = new Gtk.ToggleButton.with_label ("+ Last Error") {
                active = false,
                tooltip_text = "Feed recent console execution errors to debug"
            };
            chip_last_error.add_css_class ("suggested-chip");
            chips_box.append (chip_last_error);

            this.append (chips_box);
        }

        private void setup_message_stream () {
            message_list = new Gtk.ListBox () {
                selection_mode = Gtk.SelectionMode.NONE,
                css_classes = { "boxed-list", "elrond-messages-list" },
                margin_start = 8,
                margin_end = 8,
                margin_top = 4,
                margin_bottom = 6
            };

            scroller = new Gtk.ScrolledWindow () {
                child = message_list,
                hexpand = true,
                vexpand = true,
                hscrollbar_policy = Gtk.PolicyType.NEVER,
                vscrollbar_policy = Gtk.PolicyType.AUTOMATIC
            };

            this.append (scroller);
        }

        private void setup_input_bar () {
            var input_container = new Gtk.Box (Gtk.Orientation.VERTICAL, 4) {
                margin_start = 8,
                margin_end = 8,
                margin_bottom = 8,
                margin_top = 2
            };

            var input_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);

            var input_scroller = new Gtk.ScrolledWindow () {
                hscrollbar_policy = Gtk.PolicyType.NEVER,
                vscrollbar_policy = Gtk.PolicyType.AUTOMATIC,
                height_request = 48,
                hexpand = true
            };
            input_scroller.add_css_class ("card");

            prompt_input = new Gtk.TextView () {
                wrap_mode = Gtk.WrapMode.WORD_CHAR,
                accepts_tab = false,
                margin_start = 4,
                margin_end = 4,
                margin_top = 4,
                margin_bottom = 4
            };
            input_scroller.set_child (prompt_input);
            input_row.append (input_scroller);

            send_btn = new Gtk.Button.from_icon_name ("send-symbolic") {
                tooltip_text = "Send to Elrond (Enter)",
                valign = Gtk.Align.END
            };
            send_btn.add_css_class ("suggested-action");
            send_btn.clicked.connect (() => {
                send_prompt.begin ();
            });
            input_row.append (send_btn);

            stop_btn = new Gtk.Button.from_icon_name ("process-stop-symbolic") {
                tooltip_text = "Cancel Generation",
                valign = Gtk.Align.END,
                visible = false
            };
            stop_btn.add_css_class ("destructive-action");
            stop_btn.clicked.connect (() => {
                if (cancellable != null && !cancellable.is_cancelled ()) {
                    cancellable.cancel ();
                }
            });
            input_row.append (stop_btn);

            input_container.append (input_row);
            this.append (input_container);

            // Handle Enter key (Shift+Enter for newline)
            var key_controller = new Gtk.EventControllerKey ();
            key_controller.key_pressed.connect ((keyval, keycode, state) => {
                if (keyval == Gdk.Key.Return || keyval == Gdk.Key.KP_Enter) {
                    if ((state & Gdk.ModifierType.SHIFT_MASK) == 0) {
                        send_prompt.begin ();
                        return true;
                    }
                }
                return false;
            });
            prompt_input.add_controller (key_controller);
        }

        private void add_welcome_message () {
            append_assistant_card (
                "👋 Hello! I am **Elrond**, your local scientific AI assistant.\n\n" +
                "I can write **R** (tidyverse, ggplot2), **Python** (pandas, scipy), and **Quarto** code, summarize dataframes, or debug errors. Ask me anything!"
            );
        }

        public void clear_chat_history () {
            Gtk.Widget? child = message_list.get_first_child ();
            while (child != null) {
                var next = child.get_next_sibling ();
                message_list.remove (child);
                child = next;
            }
            add_welcome_message ();
        }

        private async void send_prompt () {
            if (is_busy) return;
            string prompt = prompt_input.buffer.text.strip ();
            if (prompt.length == 0) return;

            prompt_input.buffer.text = "";
            append_user_card (prompt);

            is_busy = true;
            send_btn.visible = false;
            stop_btn.visible = true;
            generating_spinner.visible = true;
            generating_spinner.spinning = true;
            status_indicator.label = "Thinking...";

            cancellable = new Cancellable ();

            // Assemble context based on chips
            var context_sb = new GLib.StringBuilder ();
            if (chip_active_file.active) {
                string doc_text = doc_page.source_buffer.text;
                if (doc_text.length > 4000) {
                    doc_text = doc_text.substring (0, 4000) + "\n... [truncated]";
                }
                context_sb.append_printf ("[Active File Content (%s)]:\n%s\n\n", doc_page.doc_type, doc_text);
            }

            if (chip_dataframes.active) {
                context_sb.append ("[Dataframe Schemas]:\nmtcars: 32 rows × 11 cols (mpg, cyl, disp, hp, drat, wt...)\n\n");
            }

            if (chip_last_error.active) {
                string console_text = doc_page.console_view.buffer.text;
                if (console_text.contains ("Error") || console_text.contains ("✖")) {
                    context_sb.append_printf ("[Recent Console Output]:\n%s\n\n", console_text.slice (-500, console_text.length));
                }
            }

            string combined_prompt = context_sb.str + "[User Query]:\n" + prompt;

            try {
                var controller = ElrondEngineController.get_default ();
                string response;
                if (controller.is_ready) {
                    response = yield controller.write_with_elrond (
                        doc_page.doc_type,
                        chip_active_file.active ? doc_page.source_buffer.text : "",
                        chip_dataframes.active ? "mtcars [32x11]" : "",
                        prompt
                    );
                } else {
                    // Antigravity or demo reply
                    response = yield ElrondEngineController.run_agy_prompt_async (combined_prompt, cancellable);
                }

                append_assistant_card (response);
            } catch (GLib.Error e) {
                if (e is GLib.IOError.CANCELLED) {
                    append_assistant_card ("*Generation cancelled.*");
                } else {
                    append_assistant_card (@"⚠️ **Elrond Error:** $(e.message)\n\nPlease check your local server (Ollama, LM Studio, or agy) in AI Settings.");
                }
            } finally {
                is_busy = false;
                send_btn.visible = true;
                stop_btn.visible = false;
                generating_spinner.spinning = false;
                generating_spinner.visible = false;
                status_indicator.label = "Local Copilot";
                scroll_to_bottom ();
            }
        }

        private void append_user_card (string text) {
            var row = new Gtk.ListBoxRow ();
            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 4) {
                margin_start = 24,
                margin_end = 4,
                margin_top = 4,
                margin_bottom = 4
            };
            box.add_css_class ("card");
            box.add_css_class ("user-message-card");

            var header = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4) {
                margin_start = 8,
                margin_end = 8,
                margin_top = 6
            };
            header.append (new Gtk.Image.from_icon_name ("avatar-default-symbolic"));
            header.append (new Gtk.Label ("You") { css_classes = { "heading", "caption" } });
            box.append (header);

            var lbl = new Gtk.Label (text) {
                xalign = 0,
                wrap = true,
                wrap_mode = Pango.WrapMode.WORD_CHAR,
                selectable = true,
                margin_start = 8,
                margin_end = 8,
                margin_bottom = 8
            };
            box.append (lbl);
            row.set_child (box);
            message_list.append (row);
            scroll_to_bottom ();
        }

        private void append_assistant_card (string raw_text) {
            var row = new Gtk.ListBoxRow ();
            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6) {
                margin_start = 4,
                margin_end = 24,
                margin_top = 4,
                margin_bottom = 4
            };
            box.add_css_class ("card");
            box.add_css_class ("assistant-message-card");

            var header = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4) {
                margin_start = 8,
                margin_end = 8,
                margin_top = 6
            };
            header.append (new Gtk.Image.from_icon_name ("ai-elrond"));
            header.append (new Gtk.Label ("Elrond AI") { css_classes = { "heading", "caption" } });
            box.append (header);

            // Parse text and code blocks
            render_markdown_blocks (box, raw_text);

            row.set_child (box);
            message_list.append (row);
            scroll_to_bottom ();
        }

        private void render_markdown_blocks (Gtk.Box container, string raw) {
            string[] lines = raw.split ("\n");
            var text_buf = new GLib.StringBuilder ();
            var code_buf = new GLib.StringBuilder ();
            bool in_code = false;
            string code_lang = "r";

            for (int i = 0; i < lines.length; i++) {
                string line = lines[i];
                if (line.has_prefix ("```")) {
                    if (!in_code) {
                        // Flush previous text block
                        if (text_buf.len > 0) {
                            add_text_label (container, text_buf.str.strip ());
                            text_buf.truncate (0);
                        }
                        in_code = true;
                        string info = line.substring (3).strip ();
                        code_lang = info.length > 0 ? info : "r";
                    } else {
                        // End code block
                        in_code = false;
                        add_code_card (container, code_buf.str.strip (), code_lang);
                        code_buf.truncate (0);
                    }
                } else if (in_code) {
                    code_buf.append (line + "\n");
                } else {
                    text_buf.append (line + "\n");
                }
            }

            if (in_code && code_buf.len > 0) {
                add_code_card (container, code_buf.str.strip (), code_lang);
            } else if (text_buf.len > 0) {
                add_text_label (container, text_buf.str.strip ());
            }
        }

        private void add_text_label (Gtk.Box container, string text) {
            if (text.length == 0) return;
            var lbl = new Gtk.Label (text) {
                xalign = 0,
                wrap = true,
                wrap_mode = Pango.WrapMode.WORD_CHAR,
                selectable = true,
                margin_start = 8,
                margin_end = 8,
                margin_bottom = 4
            };
            container.append (lbl);
        }

        private void add_code_card (Gtk.Box container, string code, string lang) {
            if (code.length == 0) return;

            var code_card = new Gtk.Box (Gtk.Orientation.VERTICAL, 2) {
                margin_start = 8,
                margin_end = 8,
                margin_top = 4,
                margin_bottom = 6
            };
            code_card.add_css_class ("code-snippet-box");

            // Code card header with action buttons
            var code_header = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4) {
                margin_start = 6,
                margin_end = 6,
                margin_top = 4
            };
            code_header.append (new Gtk.Label (lang.up ()) { css_classes = { "dim-label", "caption", "monospace" } });
            code_header.append (new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) { hexpand = true });

            string code_copy = code;
            string code_engine = (lang.down () == "python" || lang.down () == "py") ? "python" : "r";

            // Action: Insert at cursor
            var btn_insert = new Gtk.Button.from_icon_name ("insert-text-symbolic") {
                tooltip_text = "Insert code snippet at active cursor"
            };
            btn_insert.add_css_class ("flat");
            btn_insert.clicked.connect (() => {
                doc_page.source_buffer.insert_at_cursor (code_copy, -1);
                if (parent_window != null) {
                    parent_window.show_toast ("Inserted code at cursor");
                }
            });
            code_header.append (btn_insert);

            // Action: Run in Console
            var btn_run = new Gtk.Button.from_icon_name ("media-playback-start-symbolic") {
                tooltip_text = @"Run directly in $code_engine Console"
            };
            btn_run.add_css_class ("flat");
            btn_run.clicked.connect (() => {
                panel_reg.run_code_snippet_in_console (code_engine, code_copy);
                if (parent_window != null) {
                    parent_window.show_toast (@"Running snippet in $code_engine console");
                }
            });
            code_header.append (btn_run);

            // Action: Copy to clipboard
            var btn_copy = new Gtk.Button.from_icon_name ("edit-copy-symbolic") {
                tooltip_text = "Copy code to clipboard"
            };
            btn_copy.add_css_class ("flat");
            btn_copy.clicked.connect (() => {
                var disp = Gdk.Display.get_default ();
                if (disp != null) {
                    disp.get_clipboard ().set_text (code_copy);
                    if (parent_window != null) {
                        parent_window.show_toast ("Copied code to clipboard");
                    }
                }
            });
            code_header.append (btn_copy);

            code_card.append (code_header);

            var code_scroller = new Gtk.ScrolledWindow () {
                hscrollbar_policy = Gtk.PolicyType.AUTOMATIC,
                vscrollbar_policy = Gtk.PolicyType.NEVER,
                margin_start = 6,
                margin_end = 6,
                margin_bottom = 6
            };
            var code_lbl = new Gtk.Label (code) {
                xalign = 0,
                selectable = true,
                css_classes = { "monospace", "caption" }
            };
            code_scroller.set_child (code_lbl);
            code_card.append (code_scroller);

            container.append (code_card);
        }

        private void scroll_to_bottom () {
            GLib.Idle.add (() => {
                var vadj = scroller.get_vadjustment ();
                if (vadj != null) {
                    vadj.set_value (vadj.get_upper () - vadj.get_page_size ());
                }
                return GLib.Source.REMOVE;
            });
        }
    }
}
