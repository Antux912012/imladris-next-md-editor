namespace Imladris {
    public enum FormattingType {
        BOLD,
        ITALIC,
        STRIKETHROUGH,
        CODE,
        LINK,
        HEADING
    }

    public class ContextualPopover : Gtk.Popover {
        public signal void format_requested (FormattingType type);

        public ContextualPopover (Gtk.Widget parent) {
            Object ();
            set_parent (parent);
        }

        construct {
            has_arrow = true;
            position = Gtk.PositionType.TOP;
            autohide = true;
            add_css_class ("imladris-contextual-popover");

            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 2);
            box.add_css_class ("imladris-formatting-bar");
            box.add_css_class ("linked");

            var bold_btn = create_format_button ("format-text-bold-symbolic", "Bold (**text**)", FormattingType.BOLD);
            var italic_btn = create_format_button ("format-text-italic-symbolic", "Italic (*text*)", FormattingType.ITALIC);
            var strike_btn = create_format_button ("format-text-strikethrough-symbolic", "Strikethrough (~~text~~)", FormattingType.STRIKETHROUGH);
            var code_btn = create_format_button ("insert-text-symbolic", "Inline Code (`text`)", FormattingType.CODE);
            var link_btn = create_format_button ("insert-link-symbolic", "Link ([text](url))", FormattingType.LINK);
            var heading_btn = create_format_button ("format-text-rich-symbolic", "Heading (# text)", FormattingType.HEADING);

            box.append (bold_btn);
            box.append (italic_btn);
            box.append (strike_btn);
            box.append (code_btn);
            box.append (link_btn);
            box.append (heading_btn);

            set_child (box);
        }

        private Gtk.Button create_format_button (string icon_name, string tooltip, FormattingType type) {
            var btn = new Gtk.Button.from_icon_name (icon_name);
            btn.tooltip_text = tooltip;
            btn.add_css_class ("flat");
            btn.clicked.connect (() => {
                format_requested (type);
                popdown ();
            });
            return btn;
        }
    }
}
