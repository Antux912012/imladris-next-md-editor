using Imladris.Core.Layout;

namespace Imladris.UI {

    public class DockQuadrant : Gtk.Box {

        public QuadrantId quad_id { get; private set; }
        private unowned RStudioDockLayoutState dock_state;
        private unowned PersistentPanelRegistry registry;

        private Gtk.Box header_box;
        private Gtk.Box tab_list_box;
        private Gtk.Overlay body_overlay;
        private Gtk.Box viewport_box;
        private Gtk.Box drop_overlay_indicator;
        private Gtk.Label drop_overlay_label;

        public DockQuadrant (QuadrantId id, RStudioDockLayoutState state, PersistentPanelRegistry reg) {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 0);
            this.quad_id = id;
            this.dock_state = state;
            this.registry = reg;
            this.hexpand = true;
            this.vexpand = true;
            this.add_css_class ("rstudio-quadrant");

            // 1. QuadrantHeader (36px height)
            header_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4) {
                margin_start = 4,
                margin_end = 4,
                margin_top = 2,
                margin_bottom = 2
            };
            header_box.add_css_class ("rstudio-quadrant-header");

            tab_list_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 2) {
                hexpand = true
            };
            var tab_scroller = new Gtk.ScrolledWindow () {
                hscrollbar_policy = Gtk.PolicyType.AUTOMATIC,
                vscrollbar_policy = Gtk.PolicyType.NEVER,
                hexpand = true,
                child = tab_list_box
            };
            header_box.append (tab_scroller);

            // QuadrantWindowControls (Minimize, Maximize/Restore, Reset)
            var controls_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 2);

            if (quad_id == QuadrantId.Q3_TOP_RIGHT) {
                var reset_btn = new Gtk.Button.from_icon_name ("view-refresh-symbolic") {
                    tooltip_text = "Reset 4-Quadrant RStudio Preset Layout"
                };
                reset_btn.add_css_class ("flat");
                reset_btn.add_css_class ("DockControlBtn");
                reset_btn.clicked.connect (() => {
                    dock_state.reset_to_default ();
                    dock_state.save_to_disk ();
                });
                controls_box.append (reset_btn);
            }

            var min_btn = new Gtk.Button.from_icon_name ("window-minimize-symbolic") {
                tooltip_text = "Minimize / Collapse Quadrant"
            };
            min_btn.add_css_class ("flat");
            min_btn.add_css_class ("DockControlBtn");
            min_btn.clicked.connect (() => {
                dock_state.toggle_minimize (quad_id);
            });
            controls_box.append (min_btn);

            var max_btn = new Gtk.Button.from_icon_name ("window-maximize-symbolic") {
                tooltip_text = "Maximize / Restore Quadrant"
            };
            max_btn.add_css_class ("flat");
            max_btn.add_css_class ("DockControlBtn");
            max_btn.clicked.connect (() => {
                dock_state.toggle_maximize (quad_id);
            });
            controls_box.append (max_btn);

            header_box.append (controls_box);
            this.append (header_box);

            // 2. QuadrantViewport + DragDropOverlay
            body_overlay = new Gtk.Overlay () {
                hexpand = true,
                vexpand = true
            };

            viewport_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
                hexpand = true,
                vexpand = true
            };
            body_overlay.set_child (viewport_box);

            drop_overlay_indicator = new Gtk.Box (Gtk.Orientation.VERTICAL, 6) {
                hexpand = true,
                vexpand = true,
                halign = Gtk.Align.FILL,
                valign = Gtk.Align.FILL,
                visible = false,
                can_target = false
            };
            drop_overlay_indicator.add_css_class ("dock-drop-overlay");
            drop_overlay_label = new Gtk.Label ("Drop Panel Here") {
                halign = Gtk.Align.CENTER,
                valign = Gtk.Align.CENTER,
                vexpand = true,
                css_classes = { "heading" }
            };
            drop_overlay_indicator.append (drop_overlay_label);
            body_overlay.add_overlay (drop_overlay_indicator);

            this.append (body_overlay);

            // 3. Setup Drop-Target Hit Detection on Quadrant
            setup_quadrant_drop_target ();
        }

        private void setup_quadrant_drop_target () {
            var drop_target = new Gtk.DropTarget (typeof (string), Gdk.DragAction.MOVE);

            drop_target.motion.connect ((x, y) => {
                drop_overlay_indicator.visible = true;
                if (y < 36.0) {
                    int idx = (int) (x / 95.0);
                    drop_overlay_label.label = @"Insert into $(quad_id.to_id_string ()) Header (Tab #$(idx + 1))";
                    header_box.add_css_class ("dock-header-drop-active");
                } else {
                    drop_overlay_label.label = @"Dock in $(quad_id.to_id_string ()) Viewport";
                    header_box.remove_css_class ("dock-header-drop-active");
                }
                return Gdk.DragAction.MOVE;
            });

            drop_target.leave.connect (() => {
                drop_overlay_indicator.visible = false;
                header_box.remove_css_class ("dock-header-drop-active");
            });

            drop_target.drop.connect ((val, x, y) => {
                drop_overlay_indicator.visible = false;
                header_box.remove_css_class ("dock-header-drop-active");

                string payload = val.get_string ();
                // Payload format: "SOURCE_QUAD_ID:PANEL_ID:SOURCE_INDEX"
                string[] parts = payload.split (":");
                if (parts.length < 3) return false;

                QuadrantId src_quad = QuadrantId.from_id_string (parts[0]);
                PanelId? panel_id = PanelId.from_id_string (parts[1]);
                int src_idx = int.parse (parts[2]);

                if (panel_id == null) return false;

                if (y < 36.0) {
                    // Header Zone (y < 36px): Insert at exact tab index based on cursor x coordinate
                    int dest_idx = (int) (x / 95.0);
                    if (src_quad == this.quad_id) {
                        dock_state.reorder_tab (this.quad_id, src_idx, dest_idx);
                    } else {
                        dock_state.move_tab (src_quad, this.quad_id, panel_id, dest_idx);
                    }
                } else {
                    // Center Body Zone: Append to the quadrant's tabs list and immediately focus it
                    dock_state.move_tab (src_quad, this.quad_id, panel_id, -1);
                }
                return true;
            });

            this.add_controller (drop_target);
        }

        public void sync_from_state () {
            var qconfig = dock_state.quadrants.get (quad_id);
            if (qconfig == null) return;

            // Rebuild DraggableTabList
            Gtk.Widget? child = tab_list_box.get_first_child ();
            while (child != null) {
                var next = child.get_next_sibling ();
                tab_list_box.remove (child);
                child = next;
            }

            for (int i = 0; i < qconfig.tabs.size; i++) {
                PanelId pid = qconfig.tabs.get (i);
                int tab_index = i;
                bool is_active = (qconfig.active_tab == pid);

                var tab_btn = new Gtk.Button ();
                tab_btn.add_css_class ("dock-tab-btn");
                if (is_active) {
                    tab_btn.add_css_class ("dock-tab-active");
                }

                var tbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 5);
                tbox.append (new Gtk.Image.from_icon_name (pid.to_icon_name ()));
                tbox.append (new Gtk.Label (pid.to_title ()));
                tab_btn.set_child (tbox);

                tab_btn.clicked.connect (() => {
                    dock_state.activate_tab (quad_id, pid);
                });

                // Attach DragSource to each <DockTab/>
                var drag_source = new Gtk.DragSource () {
                    actions = Gdk.DragAction.MOVE
                };
                string drag_payload = @"$(quad_id.to_id_string ()):$(pid.to_id_string ()):$tab_index";
                drag_source.prepare.connect ((x, y) => {
                    GLib.Value v = GLib.Value (typeof (string));
                    v.set_string (drag_payload);
                    return new Gdk.ContentProvider.for_value (v);
                });
                drag_source.drag_begin.connect ((drag) => {
                    var paintable = new Gtk.WidgetPaintable (tab_btn);
                    drag_source.set_icon (paintable, 12, 12);
                });
                tab_btn.add_controller (drag_source);

                // Attach Intra-Quadrant Tab DropTarget for direct tab-on-tab reordering
                var tab_drop = new Gtk.DropTarget (typeof (string), Gdk.DragAction.MOVE);
                tab_drop.drop.connect ((val, x, y) => {
                    string p_str = val.get_string ();
                    string[] p_parts = p_str.split (":");
                    if (p_parts.length < 3) return false;
                    QuadrantId s_quad = QuadrantId.from_id_string (p_parts[0]);
                    PanelId? s_panel = PanelId.from_id_string (p_parts[1]);
                    int s_idx = int.parse (p_parts[2]);
                    if (s_panel == null) return false;

                    if (s_quad == this.quad_id) {
                        dock_state.reorder_tab (this.quad_id, s_idx, tab_index);
                    } else {
                        dock_state.move_tab (s_quad, this.quad_id, s_panel, tab_index);
                    }
                    return true;
                });
                tab_btn.add_controller (tab_drop);

                tab_list_box.append (tab_btn);
            }

            // Clear viewport children without destroying persistent panels
            Gtk.Widget? vp_child = viewport_box.get_first_child ();
            while (vp_child != null) {
                var next = vp_child.get_next_sibling ();
                viewport_box.remove (vp_child);
                vp_child = next;
            }

            // Check minimized or empty state
            if (qconfig.size_state == QuadrantSizeState.MINIMIZED || qconfig.tabs.size == 0 || qconfig.active_tab == null) {
                body_overlay.visible = false;
                this.vexpand = false;
            } else {
                body_overlay.visible = true;
                this.vexpand = true;
                registry.mount_panel (qconfig.active_tab, viewport_box);
            }
        }
    }

    public class RStudioDockGrid : Gtk.Box {

        public RStudioDockLayoutState dock_state { get; private set; }
        private unowned PersistentPanelRegistry registry;

        private Gtk.Overlay root_overlay;
        private Gtk.Paned main_hpaned;
        private Gtk.Paned left_vpaned;
        private Gtk.Paned right_vpaned;

        private Gee.HashMap<QuadrantId, DockQuadrant> quadrant_widgets;
        private Gtk.Box center_crosshair;

        private double drag_start_col_px = 0;
        private double drag_start_left_px = 0;
        private double drag_start_right_px = 0;
        private bool syncing_ratios = false;

        public RStudioDockGrid (RStudioDockLayoutState state, PersistentPanelRegistry reg) {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 0);
            this.dock_state = state;
            this.registry = reg;
            this.hexpand = true;
            this.vexpand = true;
            this.add_css_class ("rstudio-dock-grid");

            root_overlay = new Gtk.Overlay () {
                hexpand = true,
                vexpand = true
            };
            this.append (root_overlay);

            quadrant_widgets = new Gee.HashMap<QuadrantId, DockQuadrant> ();
            foreach (var qid in QuadrantId.all ()) {
                quadrant_widgets.set (qid, new DockQuadrant (qid, dock_state, registry));
            }

            // Build 2x2 Resizable Split Grid
            left_vpaned = new Gtk.Paned (Gtk.Orientation.VERTICAL) {
                start_child = quadrant_widgets.get (QuadrantId.Q1_TOP_LEFT),
                end_child = quadrant_widgets.get (QuadrantId.Q2_BOTTOM_LEFT),
                resize_start_child = true,
                resize_end_child = true,
                shrink_start_child = false,
                shrink_end_child = false,
                wide_handle = true,
                hexpand = true,
                vexpand = true
            };

            right_vpaned = new Gtk.Paned (Gtk.Orientation.VERTICAL) {
                start_child = quadrant_widgets.get (QuadrantId.Q3_TOP_RIGHT),
                end_child = quadrant_widgets.get (QuadrantId.Q4_BOTTOM_RIGHT),
                resize_start_child = true,
                resize_end_child = true,
                shrink_start_child = false,
                shrink_end_child = false,
                wide_handle = true,
                hexpand = true,
                vexpand = true
            };

            main_hpaned = new Gtk.Paned (Gtk.Orientation.HORIZONTAL) {
                start_child = left_vpaned,
                end_child = right_vpaned,
                resize_start_child = true,
                resize_end_child = true,
                shrink_start_child = false,
                shrink_end_child = false,
                wide_handle = true,
                hexpand = true,
                vexpand = true
            };

            root_overlay.set_child (main_hpaned);

            // 4-Way Center Intersection Crosshair Handle (14x14px hit target)
            center_crosshair = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) {
                width_request = 14,
                height_request = 14,
                halign = Gtk.Align.CENTER,
                valign = Gtk.Align.CENTER,
                tooltip_text = "Drag 4-Way Splitter Intersection (60 FPS Simultaneous Resize)"
            };
            center_crosshair.add_css_class ("dock-center-crosshair");
            center_crosshair.set_cursor_from_name ("move");

            var drag_gesture = new Gtk.GestureDrag ();
            drag_gesture.drag_begin.connect ((start_x, start_y) => {
                drag_start_col_px = main_hpaned.position;
                drag_start_left_px = left_vpaned.position;
                drag_start_right_px = right_vpaned.position;
            });

            drag_gesture.drag_update.connect ((offset_x, offset_y) => {
                int total_w = main_hpaned.get_width ();
                int total_h = main_hpaned.get_height ();
                if (total_w < 200 || total_h < 200) return;

                syncing_ratios = true;
                double new_col_ratio = SplitterRatios.clamp_ratio ((drag_start_col_px + offset_x) / (double) total_w);
                double new_left_ratio = SplitterRatios.clamp_ratio ((drag_start_left_px + offset_y) / (double) total_h);
                double new_right_ratio = SplitterRatios.clamp_ratio ((drag_start_right_px + offset_y) / (double) total_h);

                main_hpaned.position = (int) (new_col_ratio * total_w);
                left_vpaned.position = (int) (new_left_ratio * total_h);
                right_vpaned.position = (int) (new_right_ratio * total_h);

                dock_state.ratios.set_clamped (new_col_ratio, new_left_ratio, new_right_ratio);
                syncing_ratios = false;
            });

            drag_gesture.drag_end.connect ((offset_x, offset_y) => {
                dock_state.save_to_disk ();
            });
            center_crosshair.add_controller (drag_gesture);
            root_overlay.add_overlay (center_crosshair);

            // Connect state changes
            dock_state.state_updated.connect (() => {
                refresh_dock_layout ();
            });

            // Apply initial ratios once widget is allocated
            GLib.Idle.add (() => {
                apply_splitter_ratios ();
                return GLib.Source.REMOVE;
            });
        }

        public void apply_splitter_ratios () {
            int total_w = main_hpaned.get_width ();
            int total_h = main_hpaned.get_height ();
            if (total_w < 200) total_w = 1280;
            if (total_h < 200) total_h = 720;

            syncing_ratios = true;
            main_hpaned.position = (int) (dock_state.ratios.main_vertical * total_w);

            // Handle auto-collapse / minimized states on left column
            var q1 = dock_state.quadrants.get (QuadrantId.Q1_TOP_LEFT);
            var q2 = dock_state.quadrants.get (QuadrantId.Q2_BOTTOM_LEFT);
            if (q2 != null && (q2.size_state == QuadrantSizeState.MINIMIZED || q2.tabs.size == 0)) {
                left_vpaned.position = total_h - 38;
            } else if (q1 != null && (q1.size_state == QuadrantSizeState.MINIMIZED || q1.tabs.size == 0)) {
                left_vpaned.position = 38;
            } else {
                left_vpaned.position = (int) (dock_state.ratios.left_horizontal * total_h);
            }

            // Handle auto-collapse / minimized states on right column
            var q3 = dock_state.quadrants.get (QuadrantId.Q3_TOP_RIGHT);
            var q4 = dock_state.quadrants.get (QuadrantId.Q4_BOTTOM_RIGHT);
            if (q4 != null && (q4.size_state == QuadrantSizeState.MINIMIZED || q4.tabs.size == 0)) {
                right_vpaned.position = total_h - 38;
            } else if (q3 != null && (q3.size_state == QuadrantSizeState.MINIMIZED || q3.tabs.size == 0)) {
                right_vpaned.position = 38;
            } else {
                right_vpaned.position = (int) (dock_state.ratios.right_horizontal * total_h);
            }
            syncing_ratios = false;
        }

        public void refresh_dock_layout () {
            // Check if a single quadrant is maximized
            if (dock_state.maximized_quadrant != null) {
                QuadrantId max_id = dock_state.maximized_quadrant;
                bool is_left = (max_id == QuadrantId.Q1_TOP_LEFT || max_id == QuadrantId.Q2_BOTTOM_LEFT);
                left_vpaned.visible = is_left;
                right_vpaned.visible = !is_left;
                center_crosshair.visible = false;

                foreach (var qid in QuadrantId.all ()) {
                    var qw = quadrant_widgets.get (qid);
                    if (qw != null) {
                        qw.visible = (qid == max_id);
                        if (qid == max_id) {
                            qw.sync_from_state ();
                        }
                    }
                }
                return;
            }

            // Normal 4-Quadrant view
            left_vpaned.visible = true;
            right_vpaned.visible = true;
            center_crosshair.visible = true;

            foreach (var qid in QuadrantId.all ()) {
                var qw = quadrant_widgets.get (qid);
                if (qw != null) {
                    qw.visible = true;
                    qw.sync_from_state ();
                }
            }

            apply_splitter_ratios ();
        }
    }
}
