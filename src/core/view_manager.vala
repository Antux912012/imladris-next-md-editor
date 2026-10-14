namespace Imladris {
    public enum ViewMode {
        SOURCE,
        SPLIT,
        PREVIEW;

        public static ViewMode from_string (string mode_str) {
            switch (mode_str) {
                case "source":
                    return SOURCE;
                case "preview":
                    return PREVIEW;
                case "split":
                default:
                    return SPLIT;
            }
        }

        public string to_string () {
            switch (this) {
                case SOURCE:
                    return "source";
                case PREVIEW:
                    return "preview";
                case SPLIT:
                default:
                    return "split";
            }
        }
    }

    public class ViewManager : GLib.Object {
        private ViewMode _mode = ViewMode.SPLIT;
        private Gtk.Paned paned;
        private CodingView coding_view;
        private PreviewView preview_view;
        private DocumentModel document;

        public ViewMode mode {
            get { return _mode; }
            set {
                if (_mode != value) {
                    _mode = value;
                    apply_view_mode ();
                    notify_property ("mode");
                }
            }
        }

        public ViewManager (Gtk.Paned paned, CodingView coding_view, PreviewView preview_view, DocumentModel document) {
            Object ();
            this.paned = paned;
            this.coding_view = coding_view;
            this.preview_view = preview_view;
            this.document = document;

            document.notify["cursor-line"].connect (() => {
                if (_mode == ViewMode.SPLIT || _mode == ViewMode.PREVIEW) {
                    sync_cursor_to_preview (document.cursor_line);
                }
            });

            apply_view_mode ();
        }

        construct {
        }

        public void apply_view_mode () {
            switch (_mode) {
                case ViewMode.SOURCE:
                    coding_view.visible = true;
                    preview_view.visible = false;
                    break;
                case ViewMode.PREVIEW:
                    coding_view.visible = false;
                    preview_view.visible = true;
                    break;
                case ViewMode.SPLIT:
                default:
                    coding_view.visible = true;
                    preview_view.visible = true;
                    int width = paned.get_width ();
                    if (width > 0) {
                        paned.set_position (width / 2);
                    }
                    break;
            }
        }

        public void sync_cursor_to_preview (int line) {
            preview_view.scroll_to_line (line);
        }
    }
}
