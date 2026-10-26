namespace Imladris.Core.Layout {

    public enum QuadrantId {
        Q1_TOP_LEFT,
        Q2_BOTTOM_LEFT,
        Q3_TOP_RIGHT,
        Q4_BOTTOM_RIGHT;

        public string to_id_string () {
            switch (this) {
                case Q1_TOP_LEFT: return "Q1_TOP_LEFT";
                case Q2_BOTTOM_LEFT: return "Q2_BOTTOM_LEFT";
                case Q3_TOP_RIGHT: return "Q3_TOP_RIGHT";
                case Q4_BOTTOM_RIGHT: return "Q4_BOTTOM_RIGHT";
                default: return "Q1_TOP_LEFT";
            }
        }

        public static QuadrantId from_id_string (string str) {
            switch (str) {
                case "Q2_BOTTOM_LEFT": return Q2_BOTTOM_LEFT;
                case "Q3_TOP_RIGHT": return Q3_TOP_RIGHT;
                case "Q4_BOTTOM_RIGHT": return Q4_BOTTOM_RIGHT;
                case "Q1_TOP_LEFT":
                default: return Q1_TOP_LEFT;
            }
        }

        public static QuadrantId[] all () {
            return { Q1_TOP_LEFT, Q2_BOTTOM_LEFT, Q3_TOP_RIGHT, Q4_BOTTOM_RIGHT };
        }
    }

    public enum PanelId {
        SOURCE_EDITOR,
        LIVE_PREVIEW,
        CONSOLE,
        TERMINAL,
        ENVIRONMENT,
        OUTLINE,
        CITATIONS,
        PLOTS,
        FILES,
        HELP;

        public string to_id_string () {
            switch (this) {
                case SOURCE_EDITOR: return "source-editor";
                case LIVE_PREVIEW: return "live-preview";
                case CONSOLE: return "console";
                case TERMINAL: return "terminal";
                case ENVIRONMENT: return "environment";
                case OUTLINE: return "outline";
                case CITATIONS: return "citations";
                case PLOTS: return "plots";
                case FILES: return "files";
                case HELP: return "help";
                default: return "source-editor";
            }
        }

        public static PanelId? from_id_string (string str) {
            switch (str) {
                case "source-editor": return SOURCE_EDITOR;
                case "live-preview": return LIVE_PREVIEW;
                case "console": return CONSOLE;
                case "terminal": return TERMINAL;
                case "environment": return ENVIRONMENT;
                case "outline": return OUTLINE;
                case "citations": return CITATIONS;
                case "plots": return PLOTS;
                case "files": return FILES;
                case "help": return HELP;
                default: return null;
            }
        }

        public string to_title () {
            switch (this) {
                case SOURCE_EDITOR: return "Source Editor";
                case LIVE_PREVIEW: return "Preview";
                case CONSOLE: return "Console";
                case TERMINAL: return "Terminal";
                case ENVIRONMENT: return "Environment";
                case OUTLINE: return "Outline";
                case CITATIONS: return "Citations";
                case PLOTS: return "Plots";
                case FILES: return "Files";
                case HELP: return "Help";
                default: return "Panel";
            }
        }

        public string to_icon_name () {
            switch (this) {
                case SOURCE_EDITOR: return "document-edit-symbolic";
                case LIVE_PREVIEW: return "applications-internet-symbolic";
                case CONSOLE: return "utilities-terminal-symbolic";
                case TERMINAL: return "utilities-terminal-symbolic";
                case ENVIRONMENT: return "view-list-symbolic";
                case OUTLINE: return "view-list-bullet-symbolic";
                case CITATIONS: return "accessories-dictionary-symbolic";
                case PLOTS: return "x-office-presentation-symbolic";
                case FILES: return "folder-symbolic";
                case HELP: return "help-browser-symbolic";
                default: return "application-x-addon-symbolic";
            }
        }
    }

    public enum QuadrantSizeState {
        NORMAL,
        MINIMIZED,
        MAXIMIZED;

        public string to_id_string () {
            switch (this) {
                case MINIMIZED: return "MINIMIZED";
                case MAXIMIZED: return "MAXIMIZED";
                case NORMAL:
                default: return "NORMAL";
            }
        }

        public static QuadrantSizeState from_id_string (string s) {
            switch (s) {
                case "MINIMIZED": return MINIMIZED;
                case "MAXIMIZED": return MAXIMIZED;
                default: return NORMAL;
            }
        }
    }

    public class QuadrantConfig : GLib.Object {
        public QuadrantId id { get; set; }
        public Gee.ArrayList<PanelId> tabs { get; owned set; }
        public PanelId? active_tab = null;
        public QuadrantSizeState size_state { get; set; default = QuadrantSizeState.NORMAL; }

        public QuadrantConfig (QuadrantId id, PanelId[] initial_tabs, PanelId? active = null) {
            this.id = id;
            this.tabs = new Gee.ArrayList<PanelId> ();
            foreach (var p in initial_tabs) {
                this.tabs.add (p);
            }
            if (active != null) {
                this.active_tab = active;
            } else if (initial_tabs.length > 0) {
                this.active_tab = initial_tabs[0];
            } else {
                this.active_tab = null;
            }
            this.size_state = QuadrantSizeState.NORMAL;
        }
    }

    public class SplitterRatios : GLib.Object {
        public double main_vertical { get; set; default = 0.55; }
        public double left_horizontal { get; set; default = 0.68; }
        public double right_horizontal { get; set; default = 0.45; }

        public static double clamp_ratio (double val) {
            if (val < 0.15) return 0.15;
            if (val > 0.85) return 0.85;
            return val;
        }

        public void set_clamped (double main_v, double left_h, double right_h) {
            main_vertical = clamp_ratio (main_v);
            left_horizontal = clamp_ratio (left_h);
            right_horizontal = clamp_ratio (right_h);
        }
    }

    public class RStudioDockLayoutState : GLib.Object {
        public string mode { get; set; default = "RSTUDIO"; }
        public bool user_locked_mode { get; set; default = false; }
        public QuadrantId? maximized_quadrant = null;
        public SplitterRatios ratios { get; owned set; }
        public Gee.HashMap<QuadrantId, QuadrantConfig> quadrants { get; owned set; }

        public signal void state_updated ();

        public RStudioDockLayoutState () {
            ratios = new SplitterRatios ();
            quadrants = new Gee.HashMap<QuadrantId, QuadrantConfig> ();
            reset_to_default ();
        }

        public void reset_to_default () {
            mode = "RSTUDIO";
            user_locked_mode = false;
            maximized_quadrant = null;
            ratios.set_clamped (0.55, 0.68, 0.45);
            quadrants.clear ();

            quadrants.set (
                QuadrantId.Q1_TOP_LEFT,
                new QuadrantConfig (QuadrantId.Q1_TOP_LEFT, { PanelId.SOURCE_EDITOR }, PanelId.SOURCE_EDITOR)
            );
            quadrants.set (
                QuadrantId.Q2_BOTTOM_LEFT,
                new QuadrantConfig (QuadrantId.Q2_BOTTOM_LEFT, { PanelId.CONSOLE, PanelId.TERMINAL }, PanelId.CONSOLE)
            );
            quadrants.set (
                QuadrantId.Q3_TOP_RIGHT,
                new QuadrantConfig (QuadrantId.Q3_TOP_RIGHT, { PanelId.ENVIRONMENT, PanelId.OUTLINE, PanelId.CITATIONS }, PanelId.ENVIRONMENT)
            );
            quadrants.set (
                QuadrantId.Q4_BOTTOM_RIGHT,
                new QuadrantConfig (QuadrantId.Q4_BOTTOM_RIGHT, { PanelId.LIVE_PREVIEW, PanelId.PLOTS, PanelId.FILES, PanelId.HELP }, PanelId.LIVE_PREVIEW)
            );
            state_updated ();
        }

        // 1. Intra-Quadrant Tab Reorder
        public void reorder_tab (QuadrantId quad_id, int source_index, int dest_index) {
            var q = quadrants.get (quad_id);
            if (q == null) return;
            if (source_index < 0 || source_index >= q.tabs.size) return;
            int clamped_dest = dest_index.clamp (0, q.tabs.size - 1);
            if (source_index == clamped_dest) return;

            PanelId moved = q.tabs.remove_at (source_index);
            q.tabs.insert (clamped_dest, moved);
            save_to_disk ();
            state_updated ();
        }

        // 2. Cross-Quadrant Tab Move + Empty Quadrant Auto-Collapse
        public void move_tab (QuadrantId source_quad_id, QuadrantId target_quad_id, PanelId panel_id, int insert_index = -1) {
            var src = quadrants.get (source_quad_id);
            var dst = quadrants.get (target_quad_id);
            if (src == null || dst == null) return;

            if (source_quad_id == target_quad_id) {
                int cur_idx = src.tabs.index_of (panel_id);
                if (cur_idx >= 0 && insert_index >= 0) {
                    reorder_tab (source_quad_id, cur_idx, insert_index);
                }
                return;
            }

            // 1. Remove PanelId from sourceQuadrant.tabs
            src.tabs.remove (panel_id);

            // 2. If sourceQuadrant.activeTab === panelId, fallback to sourceQuadrant.tabs[0] ?? null
            if (src.active_tab == panel_id) {
                src.active_tab = src.tabs.size > 0 ? src.tabs.get (0) : (PanelId?) null;
            }

            // Empty Quadrant Auto-Collapse: automatically set sourceQuadrant.sizeState = 'MINIMIZED'
            if (src.tabs.size == 0) {
                src.size_state = QuadrantSizeState.MINIMIZED;
                if (maximized_quadrant == source_quad_id) {
                    maximized_quadrant = null;
                }
            }

            // 3. Append/insert PanelId into targetQuadrant.tabs and set targetQuadrant.activeTab = panelId
            if (!dst.tabs.contains (panel_id)) {
                if (insert_index >= 0 && insert_index <= dst.tabs.size) {
                    dst.tabs.insert (insert_index, panel_id);
                } else {
                    dst.tabs.add (panel_id);
                }
            }
            dst.active_tab = panel_id;
            if (dst.size_state == QuadrantSizeState.MINIMIZED) {
                dst.size_state = QuadrantSizeState.NORMAL;
            }

            save_to_disk ();
            state_updated ();
        }

        public void activate_tab (QuadrantId quad_id, PanelId panel_id) {
            var q = quadrants.get (quad_id);
            if (q == null) return;
            if (q.tabs.contains (panel_id)) {
                q.active_tab = panel_id;
                if (q.size_state == QuadrantSizeState.MINIMIZED) {
                    q.size_state = QuadrantSizeState.NORMAL;
                }
                save_to_disk ();
                state_updated ();
            }
        }

        public void toggle_minimize (QuadrantId quad_id) {
            var q = quadrants.get (quad_id);
            if (q == null) return;
            if (maximized_quadrant == quad_id) {
                maximized_quadrant = null;
            }
            if (q.size_state == QuadrantSizeState.MINIMIZED) {
                q.size_state = QuadrantSizeState.NORMAL;
            } else {
                q.size_state = QuadrantSizeState.MINIMIZED;
            }
            save_to_disk ();
            state_updated ();
        }

        public void toggle_maximize (QuadrantId quad_id) {
            var q = quadrants.get (quad_id);
            if (q == null) return;
            if (maximized_quadrant == quad_id) {
                maximized_quadrant = null;
                q.size_state = QuadrantSizeState.NORMAL;
            } else {
                maximized_quadrant = quad_id;
                q.size_state = QuadrantSizeState.MAXIMIZED;
            }
            save_to_disk ();
            state_updated ();
        }

        private string get_config_file_path () {
            string dir = GLib.Path.build_filename (GLib.Environment.get_user_config_dir (), "imladris");
            GLib.DirUtils.create_with_parents (dir, 0755);
            return GLib.Path.build_filename (dir, "dock-layout.json");
        }

        public void save_to_disk () {
            try {
                var builder = new Json.Builder ();
                builder.begin_object ();
                builder.set_member_name ("mode");
                builder.add_string_value (mode);
                builder.set_member_name ("userLockedMode");
                builder.add_boolean_value (user_locked_mode);

                builder.set_member_name ("maximizedQuadrant");
                if (maximized_quadrant != null) {
                    builder.add_string_value (maximized_quadrant.to_id_string ());
                } else {
                    builder.add_null_value ();
                }

                builder.set_member_name ("ratios");
                builder.begin_object ();
                builder.set_member_name ("mainVertical");
                builder.add_double_value (ratios.main_vertical);
                builder.set_member_name ("leftHorizontal");
                builder.add_double_value (ratios.left_horizontal);
                builder.set_member_name ("rightHorizontal");
                builder.add_double_value (ratios.right_horizontal);
                builder.end_object ();

                builder.set_member_name ("quadrants");
                builder.begin_object ();
                foreach (var qid in QuadrantId.all ()) {
                    var qc = quadrants.get (qid);
                    if (qc == null) continue;
                    builder.set_member_name (qid.to_id_string ());
                    builder.begin_object ();
                    builder.set_member_name ("id");
                    builder.add_string_value (qid.to_id_string ());
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
                GLib.FileUtils.set_contents (get_config_file_path (), json_str);
            } catch (GLib.Error e) {
                warning ("Failed to persist RStudio dock layout state: %s", e.message);
            }
        }

        public void load_from_disk () {
            string path = get_config_file_path ();
            if (!GLib.FileUtils.test (path, GLib.FileTest.EXISTS)) return;
            try {
                string contents;
                GLib.FileUtils.get_contents (path, out contents);
                var parser = new Json.Parser ();
                parser.load_from_data (contents, -1);
                var root = parser.get_root ();
                if (root == null || root.get_node_type () != Json.NodeType.OBJECT) return;
                var obj = root.get_object ();

                if (obj.has_member ("ratios")) {
                    var r_obj = obj.get_object_member ("ratios");
                    double mv = r_obj.has_member ("mainVertical") ? r_obj.get_double_member ("mainVertical") : 0.55;
                    double lh = r_obj.has_member ("leftHorizontal") ? r_obj.get_double_member ("leftHorizontal") : 0.68;
                    double rh = r_obj.has_member ("rightHorizontal") ? r_obj.get_double_member ("rightHorizontal") : 0.45;
                    ratios.set_clamped (mv, lh, rh);
                }

                if (obj.has_member ("maximizedQuadrant") && !obj.get_null_member ("maximizedQuadrant")) {
                    maximized_quadrant = QuadrantId.from_id_string (obj.get_string_member ("maximizedQuadrant"));
                } else {
                    maximized_quadrant = null;
                }

                if (obj.has_member ("quadrants")) {
                    var q_obj = obj.get_object_member ("quadrants");
                    foreach (var qid in QuadrantId.all ()) {
                        string qkey = qid.to_id_string ();
                        if (!q_obj.has_member (qkey)) continue;
                        var q_item = q_obj.get_object_member (qkey);
                        var qc = quadrants.get (qid);
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
            } catch (GLib.Error e) {
                warning ("Failed to load RStudio dock layout state: %s", e.message);
            }
        }
    }
}
