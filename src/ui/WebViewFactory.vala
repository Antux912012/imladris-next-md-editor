namespace Imladris.UI {

    /**
     * Central place to create WebKit views so the hardware acceleration
     * preference is applied consistently, and live, to every preview.
     */
    public class WebViewFactory : GLib.Object {

        public static WebKit.WebView create () {
            var web_view = new WebKit.WebView () {
                hexpand = true,
                vexpand = true
            };

            var manager = Core.SettingsManager.get_default ();
            apply_policy (web_view.get_settings (), manager.hardware_acceleration_enabled);

            // Weak reference so the handler never keeps a destroyed view alive.
            var weak_view = GLib.WeakRef (web_view);
            ulong handler = 0;
            handler = manager.hardware_acceleration_changed.connect ((enabled) => {
                var view = (WebKit.WebView?) weak_view.get ();
                if (view == null) {
                    manager.disconnect (handler);
                    return;
                }
                apply_policy (view.get_settings (), enabled);
                view.reload ();
            });

            return web_view;
        }

        private static void apply_policy (WebKit.Settings settings, bool hw_accel) {
            settings.hardware_acceleration_policy = hw_accel
                ? WebKit.HardwareAccelerationPolicy.ALWAYS
                : WebKit.HardwareAccelerationPolicy.NEVER;
            settings.enable_webgl = hw_accel;
        }
    }
}
