using GLib;

namespace Imladris.Core {

    public enum AppTheme {
        SYSTEM,
        LIGHT,
        DARK,
        EYE_FRIENDLY;

        public string to_string_id () {
            switch (this) {
                case SYSTEM: return "system";
                case LIGHT: return "light";
                case DARK: return "dark";
                case EYE_FRIENDLY: return "eye-friendly";
                default: return "system";
            }
        }

        public static AppTheme from_string_id (string id) {
            switch (id) {
                case "system": return SYSTEM;
                case "light": return LIGHT;
                case "dark": return DARK;
                case "eye-friendly":
                case "sepia": return EYE_FRIENDLY;
                default: return SYSTEM;
            }
        }

        public string get_display_name () {
            switch (this) {
                case SYSTEM: return "System Theme";
                case LIGHT: return "Light";
                case DARK: return "Dark";
                case EYE_FRIENDLY: return "Eye Friendly";
                default: return "System Theme";
            }
        }
    }

    /**
     * Persistent user preferences backed by GSettings. If the schema is not
     * installed (e.g. running straight from a build tree), it degrades to an
     * in-memory value instead of aborting the application.
     */
    public class SettingsManager : GLib.Object {
        public const string SCHEMA_ID = "io.github.Antux912012.Imladris";

        private static SettingsManager? _instance = null;
        private GLib.Settings? gsettings = null;
        private bool _hw_fallback = true;
        private AppTheme _theme_fallback = AppTheme.SYSTEM;

        public signal void hardware_acceleration_changed (bool enabled);
        public signal void theme_changed (AppTheme theme);

        public bool hardware_acceleration_enabled {
            get { return gsettings != null ? gsettings.get_boolean ("hw-acceleration") : _hw_fallback; }
            set {
                if (gsettings != null) {
                    gsettings.set_boolean ("hw-acceleration", value);
                } else if (_hw_fallback != value) {
                    _hw_fallback = value;
                    hardware_acceleration_changed (value);
                }
            }
        }

        public AppTheme app_theme {
            get {
                if (gsettings != null) {
                    return AppTheme.from_string_id (gsettings.get_string ("theme"));
                }
                return _theme_fallback;
            }
            set {
                if (gsettings != null) {
                    gsettings.set_string ("theme", value.to_string_id ());
                } else if (_theme_fallback != value) {
                    _theme_fallback = value;
                    theme_changed (value);
                }
                apply_theme (value);
            }
        }

        private SettingsManager () {
            var source = GLib.SettingsSchemaSource.get_default ();
            if (source != null && source.lookup (SCHEMA_ID, true) != null) {
                gsettings = new GLib.Settings (SCHEMA_ID);
                gsettings.changed["hw-acceleration"].connect (() => {
                    hardware_acceleration_changed (hardware_acceleration_enabled);
                });
                gsettings.changed["theme"].connect (() => {
                    apply_theme (app_theme);
                });
            } else {
                GLib.debug ("GSettings schema %s not installed; preferences will not persist.", SCHEMA_ID);
            }
        }

        public void apply_theme (AppTheme theme) {
            if (Gtk.is_initialized ()) {
                var style_mgr = Adw.StyleManager.get_default ();
                switch (theme) {
                    case AppTheme.SYSTEM:
                        style_mgr.color_scheme = Adw.ColorScheme.DEFAULT;
                        break;
                    case AppTheme.LIGHT:
                        style_mgr.color_scheme = Adw.ColorScheme.FORCE_LIGHT;
                        break;
                    case AppTheme.DARK:
                        style_mgr.color_scheme = Adw.ColorScheme.FORCE_DARK;
                        break;
                    case AppTheme.EYE_FRIENDLY:
                        style_mgr.color_scheme = Adw.ColorScheme.FORCE_LIGHT;
                        break;
                }

                var app = GLib.Application.get_default () as Gtk.Application;
                if (app != null) {
                    foreach (var win in app.get_windows ()) {
                        if (theme == AppTheme.EYE_FRIENDLY) {
                            win.add_css_class ("eye-friendly");
                        } else {
                            win.remove_css_class ("eye-friendly");
                        }
                    }
                }
            }
            theme_changed (theme);
        }

        public static SettingsManager get_default () {
            if (_instance == null) {
                _instance = new SettingsManager ();
            }
            return _instance;
        }
    }
}
