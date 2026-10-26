using GLib;
using Gtk;
using Imladris.Core;

namespace Imladris.UI {

    /**
     * AccentColorSelectorWidget renders circular color swatches matching the standard
     * GNOME Settings Appearance panel (Blue, Teal, Green, Yellow, Orange, Red, Pink, Purple, Slate)
     * with a centered checkmark and outline ring on the active selection.
     */
    public class AccentColorSelectorWidget : Gtk.Box {

        private SettingsManager settings;
        private Gee.HashMap<GnomeAccent, Gtk.Button> buttons;
        private Gee.HashMap<GnomeAccent, Gtk.Image> check_icons;

        public signal void accent_selected (GnomeAccent accent);

        public AccentColorSelectorWidget () {
            Object (orientation: Gtk.Orientation.HORIZONTAL, spacing: 6);
            this.valign = Gtk.Align.CENTER;
            this.settings = SettingsManager.get_default ();

            buttons = new Gee.HashMap<GnomeAccent, Gtk.Button> ();
            check_icons = new Gee.HashMap<GnomeAccent, Gtk.Image> ();

            GnomeAccent[] accents = {
                GnomeAccent.BLUE,
                GnomeAccent.TEAL,
                GnomeAccent.GREEN,
                GnomeAccent.YELLOW,
                GnomeAccent.ORANGE,
                GnomeAccent.RED,
                GnomeAccent.PINK,
                GnomeAccent.PURPLE,
                GnomeAccent.SLATE
            };

            foreach (var accent in accents) {
                Gtk.Image check_icon;
                var btn = create_accent_button (accent, out check_icon);
                buttons.set (accent, btn);
                check_icons.set (accent, check_icon);
                this.append (btn);
            }

            update_selection (settings.accent_color);

            settings.accent_color_changed.connect ((accent) => {
                update_selection (accent);
            });
        }

        private Gtk.Button create_accent_button (GnomeAccent accent, out Gtk.Image check_icon) {
            var btn = new Gtk.Button ();
            btn.add_css_class ("flat");
            btn.add_css_class ("accent-swatch-button");
            btn.tooltip_text = accent.get_display_name ();
            btn.valign = Gtk.Align.CENTER;

            var overlay = new Gtk.Overlay ();

            var circle = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            circle.add_css_class ("accent-circle");
            circle.add_css_class ("accent-circle-" + accent.to_string_id ());
            overlay.set_child (circle);

            check_icon = new Gtk.Image.from_icon_name ("object-select-symbolic") {
                pixel_size = 14,
                halign = Gtk.Align.CENTER,
                valign = Gtk.Align.CENTER,
                visible = false
            };
            check_icon.add_css_class ("accent-check-icon");
            overlay.add_overlay (check_icon);

            btn.set_child (overlay);

            btn.clicked.connect (() => {
                settings.accent_color = accent;
                accent_selected (accent);
            });

            return btn;
        }

        private void update_selection (GnomeAccent active_accent) {
            foreach (var entry in buttons.entries) {
                var accent = entry.key;
                var btn = entry.value;
                var check = check_icons.get (accent);

                bool is_active = (accent == active_accent);
                if (is_active) {
                    btn.add_css_class ("is-selected");
                } else {
                    btn.remove_css_class ("is-selected");
                }

                if (check != null) {
                    check.visible = is_active;
                }
            }
        }
    }
}
