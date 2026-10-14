namespace Imladris {
    public class CodingView : Adw.Bin {
        public DocumentModel document { get; construct; }
        public Gtk.ScrolledWindow scrolled_window { get; private set; }
        public GtkSource.View source_view { get; private set; }
        public GtkSource.Buffer source_buffer { get; private set; }
        public ContextualPopover popover { get; private set; }

        private bool updating_from_model = false;

        public CodingView (DocumentModel document) {
            Object (document: document);
        }

        construct {
            hexpand = true;
            vexpand = true;

            scrolled_window = new Gtk.ScrolledWindow ();
            scrolled_window.hexpand = true;
            scrolled_window.vexpand = true;

            source_buffer = new GtkSource.Buffer (null);
            source_view = new GtkSource.View.with_buffer (source_buffer);

            source_view.show_line_numbers = true;
            source_view.auto_indent = true;
            source_view.highlight_current_line = true;
            source_view.wrap_mode = Gtk.WrapMode.WORD_CHAR;
            source_view.monospace = true;
            source_view.tab_width = 4;
            source_view.insert_spaces_instead_of_tabs = true;
            source_view.left_margin = 12;
            source_view.right_margin = 12;
            source_view.top_margin = 12;
            source_view.bottom_margin = 12;
            source_view.add_css_class ("imladris-editor");

            scrolled_window.set_child (source_view);
            set_child (scrolled_window);

            load_language ();
            update_style_scheme ();

            Adw.StyleManager.get_default ().notify["dark"].connect (() => {
                update_style_scheme ();
            });

            popover = new ContextualPopover (source_view);
            popover.format_requested.connect ((type) => {
                apply_formatting (type);
            });

            // Bidirectional synchronization between Buffer and DocumentModel
            source_buffer.changed.connect (() => {
                if (!updating_from_model) {
                    document.update_text_from_view (source_buffer.text);
                }
            });

            document.notify["raw-text"].connect (() => {
                if (source_buffer.text != document.raw_text) {
                    updating_from_model = true;
                    source_buffer.text = document.raw_text;
                    updating_from_model = false;
                }
            });

            // Track cursor position
            source_buffer.notify["cursor-position"].connect (() => {
                Gtk.TextIter iter;
                source_buffer.get_iter_at_mark (out iter, source_buffer.get_insert ());
                document.cursor_line = iter.get_line () + 1;
                document.cursor_offset = iter.get_offset ();
            });

            // Handle selection popover
            source_buffer.notify["has-selection"].connect (() => {
                if (source_buffer.has_selection) {
                    Gtk.TextIter start, end;
                    if (source_buffer.get_selection_bounds (out start, out end)) {
                        Gdk.Rectangle start_rect, end_rect;
                        source_view.get_iter_location (start, out start_rect);
                        source_view.get_iter_location (end, out end_rect);

                        int win_x, win_y;
                        source_view.buffer_to_window_coords (
                            Gtk.TextWindowType.WIDGET,
                            start_rect.x,
                            start_rect.y,
                            out win_x,
                            out win_y
                        );

                        int width = int.max (end_rect.x - start_rect.x, 24);
                        int height = start_rect.height;

                        var rect = Gdk.Rectangle () {
                            x = win_x,
                            y = win_y,
                            width = width,
                            height = height
                        };

                        popover.set_pointing_to (rect);
                        popover.popup ();
                    }
                } else {
                    popover.popdown ();
                }
            });

            if (document.raw_text.length > 0) {
                updating_from_model = true;
                source_buffer.text = document.raw_text;
                updating_from_model = false;
            }
        }

        private void load_language () {
            var lm = GtkSource.LanguageManager.get_default ();
            var lang = lm.get_language ("markdown-custom") ?? lm.get_language ("markdown");
            if (lang != null) {
                source_buffer.set_language (lang);
            }
        }

        private void update_style_scheme () {
            var sm = GtkSource.StyleSchemeManager.get_default ();
            bool is_dark = Adw.StyleManager.get_default ().dark;
            var scheme = sm.get_scheme (is_dark ? "adwaita-dark" : "adwaita");
            if (scheme == null) {
                scheme = sm.get_scheme (is_dark ? "oblivion" : "classic");
            }
            if (scheme != null) {
                source_buffer.set_style_scheme (scheme);
            }
        }

        public void apply_formatting (FormattingType type) {
            Gtk.TextIter start, end;
            bool has_sel = source_buffer.get_selection_bounds (out start, out end);
            if (!has_sel) {
                source_buffer.get_iter_at_mark (out start, source_buffer.get_insert ());
                end = start;
            }

            string selected_text = source_buffer.get_text (start, end, false);
            string prefix = "";
            string suffix = "";

            switch (type) {
                case FormattingType.BOLD:
                    prefix = "**";
                    suffix = "**";
                    break;
                case FormattingType.ITALIC:
                    prefix = "*";
                    suffix = "*";
                    break;
                case FormattingType.STRIKETHROUGH:
                    prefix = "~~";
                    suffix = "~~";
                    break;
                case FormattingType.CODE:
                    prefix = "`";
                    suffix = "`";
                    break;
                case FormattingType.LINK:
                    prefix = "[";
                    suffix = "](https://)";
                    break;
                case FormattingType.HEADING:
                    prefix = "# ";
                    suffix = "";
                    break;
            }

            source_buffer.begin_user_action ();
            if (has_sel) {
                source_buffer.delete (ref start, ref end);
            }
            string replacement = prefix + selected_text + suffix;
            source_buffer.insert (ref start, replacement, replacement.length);
            source_buffer.end_user_action ();
            source_view.grab_focus ();
        }
    }
}
