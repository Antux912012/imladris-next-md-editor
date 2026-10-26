namespace Imladris.Core {

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

        public signal void hardware_acceleration_changed (bool enabled);

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

        private SettingsManager () {
            var source = GLib.SettingsSchemaSource.get_default ();
            if (source != null && source.lookup (SCHEMA_ID, true) != null) {
                gsettings = new GLib.Settings (SCHEMA_ID);
                gsettings.changed["hw-acceleration"].connect (() => {
                    hardware_acceleration_changed (hardware_acceleration_enabled);
                });
            } else {
                GLib.warning ("GSettings schema %s not installed; preferences will not persist.", SCHEMA_ID);
            }
        }

        public static SettingsManager get_default () {
            if (_instance == null) {
                _instance = new SettingsManager ();
            }
            return _instance;
        }
    }
}
