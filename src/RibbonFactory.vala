namespace Imladris {

    public class RibbonFactory : Object {

        private static GLib.Menu create_placeholder_menu (string title) {
            var menu = new GLib.Menu ();
            menu.append (@"$title Default", null);
            menu.append (@"Configure $title...", null);
            return menu;
        }

        public static Gtk.Widget create_tall_button (
            string icon_name,
            string label_text,
            bool has_dropdown = false,
            bool is_toggle = false,
            bool active = false,
            bool sensitive = true,
            GLib.MenuModel? menu_model = null,
            string? action_name = null,
            Gtk.Popover? custom_popover = null
        ) {
            var vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 4) {
                valign = Gtk.Align.CENTER,
                halign = Gtk.Align.CENTER
            };

            var img = new Gtk.Image.from_icon_name (icon_name) {
                pixel_size = 28
            };
            vbox.append (img);

            string clean_title = label_text.replace ("\n", " ");
            string final_text = (has_dropdown || custom_popover != null) ? @"$label_text ▾" : label_text;
            var lbl = new Gtk.Label (final_text) {
                justify = Gtk.Justification.CENTER
            };
            vbox.append (lbl);

            if (custom_popover != null) {
                var mbtn = new Gtk.MenuButton () {
                    popover = custom_popover,
                    sensitive = sensitive,
                    valign = Gtk.Align.CENTER
                };
                mbtn.add_css_class ("flat");
                mbtn.add_css_class ("ribbon-tall-btn");
                mbtn.set_child (vbox);
                return mbtn;
            }

            if (has_dropdown || menu_model != null) {
                var mbtn = new Gtk.MenuButton () {
                    menu_model = menu_model ?? create_placeholder_menu (clean_title),
                    sensitive = sensitive,
                    valign = Gtk.Align.CENTER
                };
                mbtn.add_css_class ("flat");
                mbtn.add_css_class ("ribbon-tall-btn");
                mbtn.set_child (vbox);
                return mbtn;
            }

            Gtk.Button btn = is_toggle ? new Gtk.ToggleButton () : new Gtk.Button ();
            btn.add_css_class ("flat");
            btn.add_css_class ("ribbon-tall-btn");
            btn.sensitive = sensitive;
            btn.valign = Gtk.Align.CENTER;

            if (action_name != null) {
                btn.action_name = action_name;
            }

            if (is_toggle && active) {
                ((Gtk.ToggleButton) btn).active = true;
            }

            btn.set_child (vbox);
            return btn;
        }

        public static Gtk.Widget create_compact_button (
            string? icon_name = null,
            string? label_text = null,
            bool has_dropdown = false,
            bool is_toggle = false,
            bool sensitive = true,
            GLib.MenuModel? menu_model = null,
            string? action_name = null,
            Gtk.Popover? custom_popover = null
        ) {
            var hbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4) {
                valign = Gtk.Align.CENTER
            };

            if (icon_name != null) {
                var img = new Gtk.Image.from_icon_name (icon_name) {
                    pixel_size = 16
                };
                hbox.append (img);
            }

            if (label_text != null) {
                string final_text = (has_dropdown || custom_popover != null) ? @"$label_text ▾" : label_text;
                var lbl = new Gtk.Label (final_text) {
                    xalign = 0.0f
                };
                hbox.append (lbl);
            }

            if (custom_popover != null) {
                var mbtn = new Gtk.MenuButton () {
                    popover = custom_popover,
                    sensitive = sensitive,
                    valign = Gtk.Align.CENTER
                };
                mbtn.add_css_class ("flat");
                mbtn.add_css_class ("ribbon-compact-btn");
                mbtn.set_child (hbox);
                return mbtn;
            }

            if (has_dropdown || menu_model != null) {
                var mbtn = new Gtk.MenuButton () {
                    menu_model = menu_model ?? create_placeholder_menu (label_text ?? "Options"),
                    sensitive = sensitive,
                    valign = Gtk.Align.CENTER
                };
                mbtn.add_css_class ("flat");
                mbtn.add_css_class ("ribbon-compact-btn");
                mbtn.set_child (hbox);
                return mbtn;
            }

            Gtk.Button btn = is_toggle ? new Gtk.ToggleButton () : new Gtk.Button ();
            btn.add_css_class ("flat");
            btn.add_css_class ("ribbon-compact-btn");
            btn.sensitive = sensitive;
            btn.valign = Gtk.Align.CENTER;

            if (action_name != null) {
                btn.action_name = action_name;
            }

            btn.set_child (hbox);
            return btn;
        }

        public static Gtk.Box create_vertical_stack (Gtk.Widget[] widgets) {
            var col = new Gtk.Box (Gtk.Orientation.VERTICAL, 4) {
                valign = Gtk.Align.CENTER
            };
            foreach (unowned Gtk.Widget w in widgets) {
                col.append (w);
            }
            return col;
        }

        public static Gtk.Separator create_vseparator () {
            return new Gtk.Separator (Gtk.Orientation.VERTICAL) {
                margin_top = 4,
                margin_bottom = 4,
                margin_start = 4,
                margin_end = 4
            };
        }
    }
}
