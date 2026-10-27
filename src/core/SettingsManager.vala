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

    public enum AiAssistanceLevel {
        LOW = 0,
        MEDIUM = 1,
        HIGH = 2;

        public int get_context_size () {
            switch (this) {
                case LOW: return 2048;
                case MEDIUM: return 4096;
                case HIGH: return 8192;
                default: return 4096;
            }
        }

        public int get_max_tokens () {
            switch (this) {
                case LOW: return 128;
                case MEDIUM: return 256;
                case HIGH: return 512;
                default: return 256;
            }
        }

        public uint get_debounce_ms () {
            switch (this) {
                case LOW: return 0;      // On-demand only
                case MEDIUM: return 600; // 600ms pause
                case HIGH: return 280;   // 280ms proactive copilot
                default: return 600;
            }
        }

        public string to_string () {
            switch (this) {
                case LOW: return "Low";
                case MEDIUM: return "Medium";
                case HIGH: return "High";
                default: return "Medium";
            }
        }
    }

    public enum ElrondBackend {
        VULKAN = 0,
        CUDA = 1;

        public string to_string_id () {
            switch (this) {
                case CUDA: return "cuda";
                default: return "vulkan";
            }
        }

        public string get_display_name () {
            switch (this) {
                case CUDA: return "NVIDIA CUDA";
                default: return "Vulkan / Universal GPU";
            }
        }
    }

    /**
     * Standard GNOME default system accent colors introduced in GNOME 47 / Libadwaita 1.6.
     */
    public enum GnomeAccent {
        BLUE,
        TEAL,
        GREEN,
        YELLOW,
        ORANGE,
        RED,
        PINK,
        PURPLE,
        SLATE;

        public string to_string_id () {
            switch (this) {
                case BLUE: return "blue";
                case TEAL: return "teal";
                case GREEN: return "green";
                case YELLOW: return "yellow";
                case ORANGE: return "orange";
                case RED: return "red";
                case PINK: return "pink";
                case PURPLE: return "purple";
                case SLATE: return "slate";
                default: return "blue";
            }
        }

        public static GnomeAccent from_string_id (string id) {
            switch (id.down ()) {
                case "blue": return BLUE;
                case "teal": return TEAL;
                case "green": return GREEN;
                case "yellow": return YELLOW;
                case "orange": return ORANGE;
                case "red": return RED;
                case "pink": return PINK;
                case "purple": return PURPLE;
                case "slate": return SLATE;
                default: return BLUE;
            }
        }

        public string get_display_name () {
            switch (this) {
                case BLUE: return "Blue";
                case TEAL: return "Teal";
                case GREEN: return "Green";
                case YELLOW: return "Yellow";
                case ORANGE: return "Orange";
                case RED: return "Red";
                case PINK: return "Pink";
                case PURPLE: return "Purple";
                case SLATE: return "Slate";
                default: return "Blue";
            }
        }

        public string get_hex_color () {
            switch (this) {
                case BLUE: return "#3584e4";
                case TEAL: return "#2190a4";
                case GREEN: return "#3a944a";
                case YELLOW: return "#c88800";
                case ORANGE: return "#ed5b00";
                case RED: return "#e62d42";
                case PINK: return "#d56199";
                case PURPLE: return "#9141ac";
                case SLATE: return "#6f8396";
                default: return "#3584e4";
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
        private GLib.Settings? gnome_interface_settings = null;
        private bool _hw_fallback = true;
        private AppTheme _theme_fallback = AppTheme.SYSTEM;
        private GnomeAccent _accent_fallback = GnomeAccent.BLUE;
        private Gtk.CssProvider? accent_css_provider = null;

        public signal void hardware_acceleration_changed (bool enabled);
        public signal void theme_changed (AppTheme theme);
        public signal void accent_color_changed (GnomeAccent accent);
        public signal void ai_settings_changed ();

        private bool _elrond_enabled = false;
        private AiAssistanceLevel _elrond_level = AiAssistanceLevel.MEDIUM;
        private ElrondBackend _elrond_backend = ElrondBackend.VULKAN;
        private string _active_model_name = "Qwen2.5-Coder-3B";
        private KeyFile config_keyfile = new KeyFile ();
        private string config_ini_path = "";

        public bool elrond_enabled {
            get { return _elrond_enabled; }
            set {
                if (_elrond_enabled != value) {
                    _elrond_enabled = value;
                    save_ini ();
                    ai_settings_changed ();
                }
            }
        }

        public ElrondBackend elrond_backend {
            get { return _elrond_backend; }
            set {
                if (_elrond_backend != value) {
                    _elrond_backend = value;
                    save_ini ();
                    ai_settings_changed ();
                }
            }
        }

        public AiAssistanceLevel elrond_level {
            get { return _elrond_level; }
            set {
                if (_elrond_level != value) {
                    _elrond_level = value;
                    save_ini ();
                    ai_settings_changed ();
                }
            }
        }

        public string active_model_name {
            get { return _active_model_name; }
            set {
                if (_active_model_name != value) {
                    _active_model_name = value;
                    save_ini ();
                    ai_settings_changed ();
                }
            }
        }

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

        public GnomeAccent accent_color {
            get {
                if (gsettings != null) {
                    string val = gsettings.get_string ("accent-color");
                    if (val.length > 0) {
                        return GnomeAccent.from_string_id (val);
                    }
                }
                if (gnome_interface_settings != null) {
                    string sys_val = gnome_interface_settings.get_string ("accent-color");
                    if (sys_val.length > 0) {
                        return GnomeAccent.from_string_id (sys_val);
                    }
                }
                return _accent_fallback;
            }
            set {
                if (gsettings != null) {
                    gsettings.set_string ("accent-color", value.to_string_id ());
                }
                if (gnome_interface_settings != null && gnome_interface_settings.is_writable ("accent-color")) {
                    gnome_interface_settings.set_string ("accent-color", value.to_string_id ());
                }
                if (_accent_fallback != value) {
                    _accent_fallback = value;
                }
                apply_accent_color (value);
            }
        }

        private SettingsManager () {
            var source = GLib.SettingsSchemaSource.get_default ();
            if (source != null) {
                if (source.lookup (SCHEMA_ID, true) != null) {
                    gsettings = new GLib.Settings (SCHEMA_ID);
                    gsettings.changed["hw-acceleration"].connect (() => {
                        hardware_acceleration_changed (hardware_acceleration_enabled);
                    });
                    gsettings.changed["theme"].connect (() => {
                        apply_theme (app_theme);
                    });
                    gsettings.changed["accent-color"].connect (() => {
                        apply_accent_color (accent_color);
                    });
                } else {
                    GLib.debug ("GSettings schema %s not installed; preferences will not persist.", SCHEMA_ID);
                }

                if (source.lookup ("org.gnome.desktop.interface", true) != null) {
                    gnome_interface_settings = new GLib.Settings ("org.gnome.desktop.interface");
                    string sys_accent = gnome_interface_settings.get_string ("accent-color");
                    if (sys_accent.length > 0) {
                        _accent_fallback = GnomeAccent.from_string_id (sys_accent);
                    }
                    gnome_interface_settings.changed["accent-color"].connect (() => {
                        var new_accent = GnomeAccent.from_string_id (gnome_interface_settings.get_string ("accent-color"));
                        if (_accent_fallback != new_accent) {
                            _accent_fallback = new_accent;
                            apply_accent_color (new_accent);
                        }
                    });
                }
            }

            load_ini ();
        }

        private void load_ini () {
            string conf_dir = Path.build_filename (Environment.get_user_config_dir (), "imladris");
            DirUtils.create_with_parents (conf_dir, 0755);
            config_ini_path = Path.build_filename (conf_dir, "settings.ini");

            if (FileUtils.test (config_ini_path, FileTest.EXISTS)) {
                try {
                    config_keyfile.load_from_file (config_ini_path, KeyFileFlags.NONE);
                    if (config_keyfile.has_key ("ElrondAI", "enabled")) {
                        _elrond_enabled = config_keyfile.get_boolean ("ElrondAI", "enabled");
                    }
                    if (config_keyfile.has_key ("ElrondAI", "level")) {
                        _elrond_level = (AiAssistanceLevel) config_keyfile.get_integer ("ElrondAI", "level");
                    }
                    if (config_keyfile.has_key ("ElrondAI", "backend")) {
                        _elrond_backend = (ElrondBackend) config_keyfile.get_integer ("ElrondAI", "backend");
                    }
                    if (config_keyfile.has_key ("ElrondAI", "model_name")) {
                        _active_model_name = config_keyfile.get_string ("ElrondAI", "model_name");
                    }
                } catch (Error e) {}
            }
        }

        private void save_ini () {
            if (config_ini_path == "") {
                string conf_dir = Path.build_filename (Environment.get_user_config_dir (), "imladris");
                DirUtils.create_with_parents (conf_dir, 0755);
                config_ini_path = Path.build_filename (conf_dir, "settings.ini");
            }
            try {
                config_keyfile.set_boolean ("ElrondAI", "enabled", _elrond_enabled);
                config_keyfile.set_integer ("ElrondAI", "level", (int) _elrond_level);
                config_keyfile.set_integer ("ElrondAI", "backend", (int) _elrond_backend);
                config_keyfile.set_string ("ElrondAI", "model_name", _active_model_name);
                FileUtils.set_contents (config_ini_path, config_keyfile.to_data ());
            } catch (Error e) {}
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

        public void apply_accent_color (GnomeAccent accent) {
            if (Gtk.is_initialized ()) {
                string hex = accent.get_hex_color ();
                string css = """
                    @define-color accent_color %s;
                    @define-color accent_bg_color %s;
                    @define-color accent_fg_color #ffffff;
                """.printf (hex, hex);

                if (accent_css_provider == null) {
                    accent_css_provider = new Gtk.CssProvider ();
                    var display = Gdk.Display.get_default ();
                    if (display != null) {
                        Gtk.StyleContext.add_provider_for_display (
                            display,
                            accent_css_provider,
                            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION + 10
                        );
                    }
                }

                accent_css_provider.load_from_string (css);
            }
            accent_color_changed (accent);
        }

        public static SettingsManager get_default () {
            if (_instance == null) {
                _instance = new SettingsManager ();
            }
            return _instance;
        }
    }
}
