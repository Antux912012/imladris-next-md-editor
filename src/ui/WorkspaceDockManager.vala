using GLib;
using Gtk;
using Adw;
using Imladris.Core.Layout;

namespace Imladris.UI {

    /**
     * WorkspaceDockManager
     * Controls dynamic detachable floating windows, quadrant moves/swaps,
     * and topology layout restructuring.
     */
    public class WorkspaceDockManager : GLib.Object {

        private unowned RStudioDockLayoutState dock_state;
        private unowned PersistentPanelRegistry registry;
        private unowned Window? main_window;

        private Gee.HashMap<PanelId, Adw.Window> undocked_windows;

        public signal void panel_dock_changed ();

        public WorkspaceDockManager (RStudioDockLayoutState state, PersistentPanelRegistry reg, Window? win) {
            this.dock_state = state;
            this.registry = reg;
            this.main_window = win;
            this.undocked_windows = new Gee.HashMap<PanelId, Adw.Window> ();
        }

        /**
         * Undocks a persistent panel into a dedicated floating Adw.Window.
         */
        public void undock_panel (PanelId pid) {
            if (undocked_windows.has_key (pid)) {
                var existing = undocked_windows.get (pid);
                existing.present ();
                return;
            }

            var widget = registry.get_panel_widget (pid);
            if (widget == null) return;

            // Detach widget from current parent container
            var parent = widget.get_parent ();
            if (parent != null) {
                var pbox = parent as Gtk.Box;
                if (pbox != null) {
                    pbox.remove (widget);
                } else {
                    widget.unparent ();
                }
            }

            var win = new Adw.Window () {
                title = @"$(pid.to_title ()) — Imladris Workbench",
                default_width = 800,
                default_height = 560
            };
            if (main_window != null) {
                win.set_transient_for (main_window);
            }

            var toolbar_view = new Adw.ToolbarView ();
            var header = new Adw.HeaderBar ();

            // Add "Re-dock" button in header
            var btn_redock = new Gtk.Button.from_icon_name ("window-minimize-symbolic") {
                tooltip_text = "Re-dock into Workbench"
            };
            btn_redock.add_css_class ("flat");
            btn_redock.clicked.connect (() => {
                redock_panel (pid);
            });
            header.pack_end (btn_redock);

            toolbar_view.add_top_bar (header);
            toolbar_view.set_content (widget);
            win.set_content (toolbar_view);

            win.close_request.connect (() => {
                redock_panel (pid);
                return false;
            });

            undocked_windows.set (pid, win);
            dock_state.undock_panel (pid);
            win.present ();
            panel_dock_changed ();
        }

        /**
         * Re-docks a popped-out floating window back into its quadrant.
         */
        public void redock_panel (PanelId pid) {
            if (!undocked_windows.has_key (pid)) return;

            var win = undocked_windows.get (pid);
            undocked_windows.unset (pid);

            var widget = registry.get_panel_widget (pid);
            if (widget != null) {
                var parent = widget.get_parent ();
                if (parent != null) {
                    var pbox = parent as Gtk.Box;
                    if (pbox != null) {
                        pbox.remove (widget);
                    } else {
                        widget.unparent ();
                    }
                }
            }

            win.close ();
            dock_state.redock_panel (pid);
            panel_dock_changed ();
        }

        public bool is_panel_undocked (PanelId pid) {
            return undocked_windows.has_key (pid);
        }

        /**
         * Creates a Popover menu for moving a panel to any of the 4 quadrants.
         */
        public Gtk.PopoverMenu create_move_panel_menu (QuadrantId current_quad, PanelId pid) {
            var menu = new GLib.Menu ();

            var section = new GLib.Menu ();
            if (current_quad != QuadrantId.Q1_TOP_LEFT) {
                section.append ("Move to Top-Left (Editor)", @"win.move_panel_$(pid.to_id_string ())_Q1");
            }
            if (current_quad != QuadrantId.Q2_BOTTOM_LEFT) {
                section.append ("Move to Bottom-Left (Console)", @"win.move_panel_$(pid.to_id_string ())_Q2");
            }
            if (current_quad != QuadrantId.Q3_TOP_RIGHT) {
                section.append ("Move to Top-Right (Environment)", @"win.move_panel_$(pid.to_id_string ())_Q3");
            }
            if (current_quad != QuadrantId.Q4_BOTTOM_RIGHT) {
                section.append ("Move to Bottom-Right (Outputs)", @"win.move_panel_$(pid.to_id_string ())_Q4");
            }
            menu.append_section ("Move Panel To Quadrant", section);

            return new Gtk.PopoverMenu.from_model (menu);
        }
    }
}
