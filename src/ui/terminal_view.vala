namespace Imladris.UI {
    public class TerminalView : Gtk.Box {
        public Vte.Terminal terminal { get; private set; }
        public bool run_on_host { get; set; default = true; }

        private Gtk.Label status_label;

        public signal void close_requested ();

        public TerminalView (bool run_on_host = true) {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 0);
            this.run_on_host = run_on_host;

            add_css_class ("imladris-terminal-container");

            var header = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
            header.add_css_class ("imladris-terminal-header");
            header.margin_start = 8;
            header.margin_end = 8;
            header.margin_top = 4;
            header.margin_bottom = 4;

            var title_icon = new Gtk.Image.from_icon_name ("utilities-terminal-symbolic");
            header.append (title_icon);

            status_label = new Gtk.Label (run_on_host ? "Host Terminal (flatpak-spawn --host)" : "Sandbox Terminal");
            status_label.add_css_class ("dim-label");
            status_label.hexpand = true;
            status_label.halign = Gtk.Align.START;
            header.append (status_label);

            var clear_btn = new Gtk.Button.from_icon_name ("edit-clear-symbolic") {
                tooltip_text = "Clear Terminal"
            };
            clear_btn.clicked.connect (() => {
                terminal.reset (true, true);
            });
            header.append (clear_btn);

            var restart_btn = new Gtk.Button.from_icon_name ("view-refresh-symbolic") {
                tooltip_text = "Restart Shell"
            };
            restart_btn.clicked.connect (() => {
                spawn_shell (this.run_on_host);
            });
            header.append (restart_btn);

            var close_btn = new Gtk.Button.from_icon_name ("window-close-symbolic") {
                tooltip_text = "Hide Terminal (Ctrl+`)"
            };
            close_btn.clicked.connect (() => {
                close_requested ();
            });
            header.append (close_btn);

            append (header);

            terminal = new Vte.Terminal ();
            terminal.set_scrollback_lines (10000);
            terminal.hexpand = true;
            terminal.vexpand = true;

            update_terminal_colors ();
            Adw.StyleManager.get_default ().notify["dark"].connect (() => {
                update_terminal_colors ();
            });

            var scroll = new Gtk.ScrolledWindow ();
            scroll.hexpand = true;
            scroll.vexpand = true;
            scroll.set_child (terminal);
            append (scroll);

            spawn_shell (this.run_on_host);
        }

        private void update_terminal_colors () {
            bool is_dark = Adw.StyleManager.get_default ().dark;
            Gdk.RGBA fg = Gdk.RGBA ();
            Gdk.RGBA bg = Gdk.RGBA ();

            if (is_dark) {
                fg.parse ("#f6f6f6");
                bg.parse ("#1e1e1e");
            } else {
                fg.parse ("#1e1e1e");
                bg.parse ("#fafafa");
            }
            terminal.set_colors (fg, bg, null);
        }

        public void spawn_shell (bool on_host) {
            string[] argv;

            bool is_flatpak = GLib.File.new_for_path ("/.flatpak-info").query_exists ();
            if (on_host && is_flatpak) {
                argv = { "flatpak-spawn", "--host", "bash" };
                status_label.label = "Host Terminal (flatpak-spawn --host)";
            } else {
                string? shell_env = Environment.get_variable ("SHELL");
                argv = { shell_env ?? "/bin/bash" };
                status_label.label = "Sandbox Terminal (/bin/bash)";
            }

            try {
                terminal.spawn_async (
                    Vte.PtyFlags.DEFAULT,
                    null,
                    argv,
                    null,
                    GLib.SpawnFlags.SEARCH_PATH,
                    null,
                    -1,
                    null,
                    null
                );
            } catch (GLib.Error e) {
                warning ("Failed to spawn terminal shell: %s", e.message);
            }
        }

        public void execute_code_chunk (string language, string code) {
            string lang = language.down ().strip ();
            string command = "";

            if (lang == "python" || lang == "py") {
                command = "python3 -c " + Shell.quote (code) + "\n";
            } else if (lang == "r") {
                command = "Rscript -e " + Shell.quote (code) + "\n";
            } else if (lang == "quarto" || lang == "qmd") {
                command = "quarto render\n";
            } else if (lang == "sh" || lang == "bash") {
                command = code.has_suffix ("\n") ? code : (code + "\n");
            } else {
                command = code.has_suffix ("\n") ? code : (code + "\n");
            }

            if (command != "") {
                terminal.feed_child (command.data);
            }
        }

        public void grab_focus_terminal () {
            terminal.grab_focus ();
        }
    }
}
