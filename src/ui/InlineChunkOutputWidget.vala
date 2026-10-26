namespace Imladris.UI {

    /**
     * Pillar 11: Inline Document Code Chunk Execution & Output Card
     * Rendered directly beneath code chunks inside GtkSource.View via Gtk.TextChildAnchor
     */
    public class InlineChunkOutputWidget : Gtk.Box {
        public int chunk_end_line { get; set; }
        private Gtk.Label header_lbl;
        private Gtk.TextView output_view;
        private Gtk.Picture plot_picture;
        private Gtk.Box content_box;
        private Gtk.Revealer revealer;
        private Gtk.Button toggle_btn;

        public InlineChunkOutputWidget (int end_line) {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 4);
            this.chunk_end_line = end_line;
            this.add_css_class ("inline-chunk-card");
            this.margin_start = 24;
            this.margin_end = 24;
            this.margin_top = 4;
            this.margin_bottom = 6;

            var top_bar = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
                margin_start = 8,
                margin_end = 8,
                margin_top = 4,
                margin_bottom = 4
            };
            top_bar.add_css_class ("inline-chunk-header");

            header_lbl = new Gtk.Label ("Console & Plot Output") {
                css_classes = { "dim-label", "caption", "monospace" },
                xalign = 0
            };
            top_bar.append (header_lbl);
            top_bar.append (new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) { hexpand = true });

            toggle_btn = new Gtk.Button.from_icon_name ("pan-down-symbolic") {
                tooltip_text = "Collapse / Expand Output"
            };
            toggle_btn.add_css_class ("flat");
            top_bar.append (toggle_btn);
            this.append (top_bar);

            content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6) {
                margin_start = 8,
                margin_end = 8,
                margin_bottom = 8
            };

            output_view = new Gtk.TextView () {
                editable = false,
                monospace = true,
                wrap_mode = Gtk.WrapMode.WORD_CHAR,
                visible = false
            };
            output_view.add_css_class ("inline-chunk-output-text");
            content_box.append (output_view);

            plot_picture = new Gtk.Picture () {
                content_fit = Gtk.ContentFit.CONTAIN,
                can_shrink = true,
                height_request = 260,
                visible = false
            };
            content_box.append (plot_picture);

            revealer = new Gtk.Revealer () {
                child = content_box,
                reveal_child = true
            };
            this.append (revealer);

            toggle_btn.clicked.connect (() => {
                revealer.reveal_child = !revealer.reveal_child;
                toggle_btn.icon_name = revealer.reveal_child ? "pan-down-symbolic" : "pan-end-symbolic";
            });
        }

        public void set_output (string text_output, string? plot_path, int execution_count = 1) {
            header_lbl.label = @"Out [$execution_count]:";

            string trimmed = text_output.strip ();
            if (trimmed.length > 0) {
                output_view.buffer.text = trimmed;
                output_view.visible = true;
            } else {
                output_view.visible = false;
            }

            if (plot_path != null && GLib.FileUtils.test (plot_path, GLib.FileTest.EXISTS)) {
                plot_picture.set_filename (plot_path);
                plot_picture.visible = true;
            } else {
                plot_picture.visible = false;
            }

            revealer.reveal_child = true;
            this.visible = (output_view.visible || plot_picture.visible);
        }
    }
}
