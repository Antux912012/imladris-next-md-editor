using GLib;
using Gtk;
using Imladris.Core.Layout;
using Imladris.UI;

namespace Imladris.Tests {

    public class DockEnvironmentTests : GLib.Object {

        public static void register_tests (bool has_display) {
            Test.add_func ("/dock/panel_id_metadata", test_panel_id_metadata);
            Test.add_func ("/dock/layout_topology_states", test_layout_topology_states);
            Test.add_func ("/dock/layout_persistence", test_layout_persistence);
            Test.add_func ("/dock/undock_redock_flow", test_undock_redock_flow);
            Test.add_func ("/dock/layout_serializer_presets", test_layout_serializer_presets);
            Test.add_func ("/grid/data_row", test_data_row);
            if (has_display) {
                Test.add_func ("/grid/data_viewer_widget", test_data_viewer_widget);
            }
            Test.add_func ("/environment/variable_item_parsing", test_variable_item_parsing);
        }

        private static void test_panel_id_metadata () {
            var p_ai = PanelId.ELROND_AI;
            assert (p_ai.to_id_string () == "elrond-ai");
            assert (p_ai.to_title () == "Elrond AI");
            assert (p_ai.to_icon_name () == "ai-elrond");
            assert (PanelId.from_id_string ("elrond-ai") == PanelId.ELROND_AI);

            var p_grid = PanelId.DATA_VIEWER;
            assert (p_grid.to_id_string () == "data-viewer");
            assert (p_grid.to_title () == "Data Viewer");
            assert (p_grid.to_icon_name () == "view-grid-symbolic");
            assert (PanelId.from_id_string ("data-viewer") == PanelId.DATA_VIEWER);
        }

        private static void test_layout_topology_states () {
            assert (LayoutTopology.QUAD_4.to_id_string () == "QUAD_4");
            assert (LayoutTopology.LEFT_TALL_3.to_id_string () == "LEFT_TALL_3");
            assert (LayoutTopology.RIGHT_TALL_3.to_id_string () == "RIGHT_TALL_3");

            assert (LayoutTopology.from_id_string ("QUAD_4") == LayoutTopology.QUAD_4);
            assert (LayoutTopology.from_id_string ("LEFT_TALL_3") == LayoutTopology.LEFT_TALL_3);
            assert (LayoutTopology.from_id_string ("RIGHT_TALL_3") == LayoutTopology.RIGHT_TALL_3);

            var state = new RStudioDockLayoutState ();
            assert (state.topology == LayoutTopology.QUAD_4);

            var q1 = state.quadrants.get (QuadrantId.Q1_TOP_LEFT);
            assert (q1 != null);
            assert (q1.tabs.contains (PanelId.SOURCE_EDITOR));
            assert (q1.tabs.contains (PanelId.DATA_VIEWER));

            var q2 = state.quadrants.get (QuadrantId.Q2_BOTTOM_LEFT);
            assert (q2 != null);
            assert (q2.tabs.contains (PanelId.CONSOLE));
            assert (q2.tabs.contains (PanelId.TERMINAL));
            assert (q2.tabs.contains (PanelId.ELROND_AI));
        }

        private static void test_layout_persistence () {
            var state = new RStudioDockLayoutState ();
            state.switch_topology (LayoutTopology.LEFT_TALL_3);
            assert (state.topology == LayoutTopology.LEFT_TALL_3);

            state.save_to_disk ();

            var loaded_state = new RStudioDockLayoutState ();
            loaded_state.load_from_disk ();
            assert (loaded_state.topology == LayoutTopology.LEFT_TALL_3);

            // Clean up to default
            loaded_state.reset_to_default ();
            loaded_state.save_to_disk ();
        }

        private static void test_undock_redock_flow () {
            var state = new RStudioDockLayoutState ();
            assert (!state.popped_out_panels.contains (PanelId.LIVE_PREVIEW));

            state.undock_panel (PanelId.LIVE_PREVIEW);
            assert (state.popped_out_panels.contains (PanelId.LIVE_PREVIEW));

            state.redock_panel (PanelId.LIVE_PREVIEW);
            assert (!state.popped_out_panels.contains (PanelId.LIVE_PREVIEW));
        }

        private static void test_layout_serializer_presets () {
            var state = new RStudioDockLayoutState ();
            LayoutSerializer.apply_topology_preset (LayoutTopology.RIGHT_TALL_3, state);
            assert (state.topology == LayoutTopology.RIGHT_TALL_3);

            try {
                LayoutSerializer.save_layout ("test-biostat-layout", state);
                string[] saved = LayoutSerializer.list_saved_layouts ();
                bool found = false;
                foreach (var s in saved) {
                    if (s == "test-biostat-layout") found = true;
                }
                assert (found);

                var new_state = new RStudioDockLayoutState ();
                bool ok = LayoutSerializer.load_layout ("test-biostat-layout", new_state);
                assert (ok);
                assert (new_state.topology == LayoutTopology.RIGHT_TALL_3);
            } catch (GLib.Error e) {
                assert_not_reached ();
            }
        }

        private static void test_data_row () {
            string[] cells = { "21.0", "6", "160", "110" };
            var row = new DataRow (1, cells);
            assert (row.row_index == 1);
            assert (row.get_cell (0) == "21.0");
            assert (row.get_cell (1) == "6");
            assert (row.get_cell (3) == "110");
            assert (row.get_cell (10) == ""); // Out of bounds returns empty string
        }

        private static void test_data_viewer_widget () {
            string[] cells = { "21.0", "6", "160", "110" };
            var row = new DataRow (1, cells);
            var viewer = new DataGridViewer ();
            assert (viewer.active_object_name == "");

            var list = new Gee.ArrayList<DataRow> ();
            list.add (row);
            viewer.populate_grid_data ("test_df", { "mpg", "cyl", "disp", "hp" }, list);
            assert (viewer.active_object_name == "test_df");
        }

        private static void test_variable_item_parsing () {
            var item = new EnvVariableItem ("mtcars", "data.frame", "32 × 11", "7.2 Kb", true);
            assert (item.name == "mtcars");
            assert (item.var_type == "data.frame");
            assert (item.dimensions == "32 × 11");
            assert (item.is_dataframe == true);
        }
    }

    public static int main (string[] args) {
        bool has_display = Gtk.init_check ();
        Test.init (ref args);
        DockEnvironmentTests.register_tests (has_display);
        return Test.run ();
    }
}
