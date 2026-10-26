namespace Imladris.UI {

    public class PreferencesDialog : Adw.PreferencesDialog {

        public PreferencesDialog () {
            Object (title: "Preferences");

            var page = new Adw.PreferencesPage ();
            var group = new Adw.PreferencesGroup () {
                title = "Hardware & Rendering",
                description = "Configure GPU acceleration for previews and plots"
            };

            var hw_row = new Adw.SwitchRow () {
                title = "Hardware Acceleration",
                subtitle = "Use the GPU for WebKit previews. Turn off if you see crashes or artifacts on older hardware, virtual machines or problematic drivers.",
                active = Core.SettingsManager.get_default ().hardware_acceleration_enabled
            };
            hw_row.notify["active"].connect (() => {
                Core.SettingsManager.get_default ().hardware_acceleration_enabled = hw_row.active;
            });

            group.add (hw_row);
            page.add (group);
            this.add (page);
        }
    }
}
