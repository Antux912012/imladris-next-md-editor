namespace Imladris {
    public class TabPageContent : Gtk.Box {
        public DocumentModel document { get; construct; }
        public CodingView coding_view { get; private set; }
        public PreviewView preview_view { get; private set; }
        public ViewManager view_manager { get; private set; }
        public Adw.ViewStack view_stack { get; private set; }

        private Gtk.Paned paned;
        private uint parse_timeout_id = 0;

        public TabPageContent (DocumentModel document) {
            Object (
                orientation: Gtk.Orientation.VERTICAL,
                spacing: 0,
                document: document
            );
        }

        construct {
            hexpand = true;
            vexpand = true;

            paned = new Gtk.Paned (Gtk.Orientation.HORIZONTAL);
            paned.hexpand = true;
            paned.vexpand = true;
            paned.add_css_class ("imladris-split-pane");

            coding_view = new CodingView (document);
            preview_view = new PreviewView ();

            paned.set_start_child (coding_view);
            paned.set_end_child (preview_view);
            paned.set_resize_start_child (true);
            paned.set_resize_end_child (true);
            paned.set_shrink_start_child (false);
            paned.set_shrink_end_child (false);

            append (paned);

            // Setup auxiliary ViewStack for Adw.ViewSwitcher
            view_stack = new Adw.ViewStack ();
            view_stack.add_titled_with_icon (new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0), "source", "Editor", "accessories-text-editor-symbolic");
            view_stack.add_titled_with_icon (new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0), "split", "Split", "view-dual-symbolic");
            view_stack.add_titled_with_icon (new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0), "preview", "Preview", "view-continuous-symbolic");
            view_stack.set_visible_child_name ("split");

            view_manager = new ViewManager (paned, coding_view, preview_view, document);

            view_stack.notify["visible-child-name"].connect (() => {
                string name = view_stack.visible_child_name;
                if (name != null) {
                    view_manager.mode = ViewMode.from_string (name);
                }
            });

            document.text_changed.connect (() => {
                schedule_render ();
            });

            document.parsed_html_ready.connect ((html) => {
                preview_view.update_html (html);
            });

            schedule_render ();
        }

        private void schedule_render () {
            if (parse_timeout_id != 0) {
                Source.remove (parse_timeout_id);
                parse_timeout_id = 0;
            }

            parse_timeout_id = Timeout.add (120, () => {
                parse_timeout_id = 0;
                render_document_async.begin ();
                return Source.REMOVE;
            });
        }

        private async void render_document_async () {
            try {
                string html = yield MarkdownParser.get_default ().render_html_async (document.raw_text, true);
                document.emit_parsed_html (html);
            } catch (Error e) {
                warning ("Markdown rendering error: %s", e.message);
            }
        }
    }
}
