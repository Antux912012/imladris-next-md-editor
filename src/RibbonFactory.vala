namespace Imladris {

    public class RibbonFactory : Object {

        public static Gtk.Box create_linked_group (Gtk.Widget[] widgets) {
            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            box.add_css_class ("linked");
            box.valign = Gtk.Align.CENTER;
            foreach (unowned Gtk.Widget w in widgets) {
                box.append (w);
            }
            return box;
        }

        public static Gtk.Widget create_tool_button (
            string icon_name,
            string? label_text = null,
            string? tooltip = null,
            bool is_toggle = false,
            bool active = false,
            bool sensitive = true,
            GLib.MenuModel? menu_model = null,
            string? action_name = null,
            Gtk.Popover? custom_popover = null
        ) {
            Gtk.Widget child_widget;
            if (label_text != null && label_text.length > 0) {
                var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
                    valign = Gtk.Align.CENTER,
                    halign = Gtk.Align.CENTER
                };
                box.append (new Gtk.Image.from_icon_name (icon_name) { pixel_size = 16 });
                box.append (new Gtk.Label (label_text) { xalign = 0.0f });
                child_widget = box;
            } else {
                child_widget = new Gtk.Image.from_icon_name (icon_name) { pixel_size = 16 };
            }

            if (custom_popover != null) {
                var mbtn = new Gtk.MenuButton () {
                    popover = custom_popover,
                    sensitive = sensitive,
                    valign = Gtk.Align.CENTER
                };
                mbtn.add_css_class ("flat");
                mbtn.add_css_class ("ribbon-tool-btn");
                if (tooltip != null) mbtn.tooltip_text = tooltip;
                mbtn.set_child (child_widget);
                return mbtn;
            }

            if (menu_model != null) {
                var mbtn = new Gtk.MenuButton () {
                    menu_model = menu_model,
                    sensitive = sensitive,
                    valign = Gtk.Align.CENTER
                };
                mbtn.add_css_class ("flat");
                mbtn.add_css_class ("ribbon-tool-btn");
                if (tooltip != null) mbtn.tooltip_text = tooltip;
                mbtn.set_child (child_widget);
                return mbtn;
            }

            Gtk.Button btn = is_toggle ? new Gtk.ToggleButton () : new Gtk.Button ();
            btn.add_css_class ("flat");
            btn.add_css_class ("ribbon-tool-btn");
            btn.sensitive = sensitive;
            btn.valign = Gtk.Align.CENTER;
            if (tooltip != null) btn.tooltip_text = tooltip;

            if (action_name != null) {
                btn.action_name = action_name;
            }

            if (is_toggle && active) {
                ((Gtk.ToggleButton) btn).active = true;
            }

            btn.set_child (child_widget);
            return btn;
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
            var vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 2) {
                valign = Gtk.Align.CENTER,
                halign = Gtk.Align.CENTER
            };

            var img = new Gtk.Image.from_icon_name (icon_name) {
                pixel_size = 18
            };
            vbox.append (img);

            var lbl = new Gtk.Label (label_text) {
                justify = Gtk.Justification.CENTER
            };
            lbl.add_css_class ("caption");
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

            if (menu_model != null) {
                var mbtn = new Gtk.MenuButton () {
                    menu_model = menu_model,
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
            return create_tool_button (
                icon_name ?? "system-run-symbolic",
                label_text,
                null,
                is_toggle,
                false,
                sensitive,
                menu_model,
                action_name,
                custom_popover
            );
        }

        public static Gtk.Box create_vertical_stack (Gtk.Widget[] widgets) {
            var col = new Gtk.Box (Gtk.Orientation.VERTICAL, 2) {
                valign = Gtk.Align.CENTER
            };
            foreach (unowned Gtk.Widget w in widgets) {
                col.append (w);
            }
            return col;
        }

        public static Gtk.Separator create_vseparator () {
            return new Gtk.Separator (Gtk.Orientation.VERTICAL) {
                margin_top = 6,
                margin_bottom = 6,
                margin_start = 6,
                margin_end = 6
            };
        }
    }
}
