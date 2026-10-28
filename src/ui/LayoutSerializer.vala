using GLib;
using Json;
using Imladris.Core.Layout;

namespace Imladris.UI {

    /**
     * LayoutSerializer
     * Handles saving, loading, and managing custom dock layout presets
     * in ~/.config/imladris/layouts/<name>.json.
     */
    public class LayoutSerializer : GLib.Object {

        public static string get_layouts_dir () {
            string dir = GLib.Path.build_filename (GLib.Environment.get_user_config_dir (), "imladris", "layouts");
            GLib.DirUtils.create_with_parents (dir, 0755);
            return dir;
        }

        public static string[] list_saved_layouts () {
            var list = new Gee.ArrayList<string> ();
            string dir = get_layouts_dir ();
            try {
                var d = GLib.Dir.open (dir, 0);
                string? name = null;
                while ((name = d.read_name ()) != null) {
                    if (name.has_suffix (".json")) {
                        list.add (name.substring (0, name.length - 5));
                    }
                }
            } catch (GLib.Error e) {
                // Directory might be empty
            }
            return list.to_array ();
        }

        public static void save_layout (string name, RStudioDockLayoutState state) throws GLib.Error {
            string sanitized = name.strip ().replace ("/", "_").replace ("\\", "_");
            if (sanitized.length == 0) sanitized = "custom-layout";

            string file_path = GLib.Path.build_filename (get_layouts_dir (), sanitized + ".json");

            var builder = new Json.Builder ();
            builder.begin_object ();
            builder.set_member_name ("name");
            builder.add_string_value (sanitized);
            builder.set_member_name ("topology");
            builder.add_string_value (state.topology.to_id_string ());

            builder.set_member_name ("ratios");
            builder.begin_object ();
            builder.set_member_name ("mainVertical");
            builder.add_double_value (state.ratios.main_vertical);
            builder.set_member_name ("leftHorizontal");
            builder.add_double_value (state.ratios.left_horizontal);
            builder.set_member_name ("rightHorizontal");
            builder.add_double_value (state.ratios.right_horizontal);
            builder.end_object ();

            builder.set_member_name ("quadrants");
            builder.begin_object ();
            foreach (var qid in QuadrantId.all ()) {
                var qc = state.quadrants.get (qid);
                if (qc == null) continue;
                builder.set_member_name (qid.to_id_string ());
                builder.begin_object ();
                builder.set_member_name ("sizeState");
                builder.add_string_value (qc.size_state.to_id_string ());
                builder.set_member_name ("activeTab");
                if (qc.active_tab != null) {
                    builder.add_string_value (qc.active_tab.to_id_string ());
                } else {
                    builder.add_null_value ();
                }
                builder.set_member_name ("tabs");
                builder.begin_array ();
                foreach (var p in qc.tabs) {
                    builder.add_string_value (p.to_id_string ());
                }
                builder.end_array ();
                builder.end_object ();
            }
            builder.end_object ();
            builder.end_object ();

            var gen = new Json.Generator ();
            gen.set_root (builder.get_root ());
            gen.pretty = true;
            string json_str = gen.to_data (null);
            GLib.FileUtils.set_contents (file_path, json_str);
        }

        public static bool load_layout (string name, RStudioDockLayoutState state) {
            string file_path = GLib.Path.build_filename (get_layouts_dir (), name + ".json");
            if (!GLib.FileUtils.test (file_path, GLib.FileTest.EXISTS)) return false;

            try {
                string contents;
                GLib.FileUtils.get_contents (file_path, out contents);
                var parser = new Json.Parser ();
                parser.load_from_data (contents, -1);
                var root = parser.get_root ();
                if (root == null || root.get_node_type () != Json.NodeType.OBJECT) return false;
                var obj = root.get_object ();

                if (obj.has_member ("topology")) {
                    state.topology = LayoutTopology.from_id_string (obj.get_string_member ("topology"));
                }

                if (obj.has_member ("ratios")) {
                    var r_obj = obj.get_object_member ("ratios");
                    double mv = r_obj.has_member ("mainVertical") ? r_obj.get_double_member ("mainVertical") : 0.55;
                    double lh = r_obj.has_member ("leftHorizontal") ? r_obj.get_double_member ("leftHorizontal") : 0.68;
                    double rh = r_obj.has_member ("rightHorizontal") ? r_obj.get_double_member ("rightHorizontal") : 0.45;
                    state.ratios.set_clamped (mv, lh, rh);
                }

                if (obj.has_member ("quadrants")) {
                    var q_obj = obj.get_object_member ("quadrants");
                    foreach (var qid in QuadrantId.all ()) {
                        string qkey = qid.to_id_string ();
                        if (!q_obj.has_member (qkey)) continue;
                        var q_item = q_obj.get_object_member (qkey);
                        var qc = state.quadrants.get (qid);
                        if (qc == null) continue;

                        if (q_item.has_member ("sizeState")) {
                            qc.size_state = QuadrantSizeState.from_id_string (q_item.get_string_member ("sizeState"));
                        }

                        if (q_item.has_member ("tabs")) {
                            qc.tabs.clear ();
                            var t_arr = q_item.get_array_member ("tabs");
                            for (uint i = 0; i < t_arr.get_length (); i++) {
                                PanelId? pid = PanelId.from_id_string (t_arr.get_string_element (i));
                                if (pid != null) {
                                    qc.tabs.add (pid);
                                }
                            }
                        }

                        if (q_item.has_member ("activeTab") && !q_item.get_null_member ("activeTab")) {
                            qc.active_tab = PanelId.from_id_string (q_item.get_string_member ("activeTab"));
                        } else {
                            qc.active_tab = qc.tabs.size > 0 ? qc.tabs.get (0) : (PanelId?) null;
                        }
                    }
                }

                state.save_to_disk ();
                state.state_updated ();
                return true;
            } catch (GLib.Error e) {
                warning ("Failed to load dock layout '%s': %s", name, e.message);
                return false;
            }
        }

        public static void apply_topology_preset (LayoutTopology topo, RStudioDockLayoutState state) {
            state.topology = topo;
            state.maximized_quadrant = null;

            switch (topo) {
                case LayoutTopology.LEFT_TALL_3:
                    // Q1 tall on left (Editor + Console), Q3 & Q4 stacked on right
                    state.ratios.set_clamped (0.60, 0.70, 0.50);
                    var q1 = state.quadrants.get (QuadrantId.Q1_TOP_LEFT);
                    var q2 = state.quadrants.get (QuadrantId.Q2_BOTTOM_LEFT);
                    if (q2 != null) q2.size_state = QuadrantSizeState.MINIMIZED;
                    if (q1 != null) q1.size_state = QuadrantSizeState.NORMAL;
                    break;

                case LayoutTopology.RIGHT_TALL_3:
                    // Q1 and Q2 stacked on left, Q4 tall on right
                    state.ratios.set_clamped (0.45, 0.50, 0.70);
                    var q3 = state.quadrants.get (QuadrantId.Q3_TOP_RIGHT);
                    var q4 = state.quadrants.get (QuadrantId.Q4_BOTTOM_RIGHT);
                    if (q3 != null) q3.size_state = QuadrantSizeState.MINIMIZED;
                    if (q4 != null) q4.size_state = QuadrantSizeState.NORMAL;
                    break;

                case LayoutTopology.QUAD_4:
                default:
                    state.ratios.set_clamped (0.55, 0.68, 0.45);
                    foreach (var qid in QuadrantId.all ()) {
                        var q = state.quadrants.get (qid);
                        if (q != null) q.size_state = QuadrantSizeState.NORMAL;
                    }
                    break;
            }

            state.save_to_disk ();
            state.state_updated ();
        }
    }
}
