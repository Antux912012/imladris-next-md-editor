namespace Imladris.Services {

    public enum LayoutMode {
        APOSTROPHE,
        RSTUDIO;

        public static LayoutMode from_extension (string filename) {
            string lower = filename.down ();
            if (lower.has_suffix (".qmd") || lower.has_suffix (".rmd")) {
                return RSTUDIO;
            }
            // Markdown and notebooks default to Apostrophe writer mode, with notebook 1-click toggle to RStudio
            return APOSTROPHE;
        }

        public string to_label () {
            switch (this) {
                case RSTUDIO:
                    return "RStudio Workbench (4-Quadrant)";
                case APOSTROPHE:
                default:
                    return "Apostrophe Mode (Focused Writer)";
            }
        }
    }

    public enum SplitMode {
        EDITOR_ONLY,
        PREVIEW_ONLY,
        VERTICAL_SPLIT,
        HORIZONTAL_SPLIT;

        public string to_label () {
            switch (this) {
                case EDITOR_ONLY:
                    return "Editor Only";
                case PREVIEW_ONLY:
                    return "Preview Only";
                case HORIZONTAL_SPLIT:
                    return "Horizontal Split (Top/Bottom)";
                case VERTICAL_SPLIT:
                default:
                    return "Vertical Split (Side-by-Side)";
            }
        }
    }

    public class WorkspaceStateManager : GLib.Object {
        private static WorkspaceStateManager? instance = null;

        public static WorkspaceStateManager get_default () {
            if (instance == null) {
                instance = new WorkspaceStateManager ();
            }
            return instance;
        }

        public LayoutMode active_layout { get; set; default = LayoutMode.APOSTROPHE; }
        public SplitMode active_split { get; set; default = SplitMode.VERTICAL_SPLIT; }
        public bool user_override_lock { get; set; default = false; }

        public signal void layout_changed (LayoutMode new_layout);
        public signal void split_changed (SplitMode new_split);

        public void set_layout_mode (LayoutMode mode, bool user_manual_override = false) {
            if (user_manual_override) {
                user_override_lock = true;
            }
            if (active_layout != mode) {
                active_layout = mode;
                layout_changed (mode);
            }
        }

        public void set_split_mode (SplitMode mode) {
            if (active_split != mode) {
                active_split = mode;
                split_changed (mode);
            }
        }

        public void resolve_mode_for_file (string filename) {
            if (user_override_lock) {
                return; // Respect user manual choice during session
            }
            var target_mode = LayoutMode.from_extension (filename);
            set_layout_mode (target_mode, false);
        }
    }
}
