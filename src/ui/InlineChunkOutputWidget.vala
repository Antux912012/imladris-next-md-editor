using GLib;
using Gtk;

namespace Imladris.UI {

    /**
     * Pillar 11: Inline Document Code Chunk Execution & Output Card
     * Rendered directly beneath code chunks in GtkSourceView.
     */
    public class InlineChunkOutputWidget : Gtk.Box {
        public int chunk_end_line { get; set; default = -1; }
        private Gtk.TextView log_view;
        private Gtk.Picture plot_picture;
        private Gtk.Expander expander;

        public InlineChunkOutputWidget (int end_line = -1) {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 6);
            this.chunk_end_line = end_line;
            this.add_css_class ("card");
            this.add_css_class ("inline-chunk-card");
            this.margin_top = 4;
            this.margin_bottom = 8;
            this.margin_start = 12;
            this.margin_end = 12;

            expander = new Gtk.Expander ("Chunk Execution Output") {
                expanded = true
            };

            var content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);

            log_view = new Gtk.TextView () {
                editable = false,
                monospace = true,
                cursor_visible = false,
                wrap_mode = Gtk.WrapMode.WORD_CHAR
            };
            log_view.add_css_class ("dim-label");

            var scroller = new Gtk.ScrolledWindow () {
                min_content_height = 60,
                max_content_height = 180,
                child = log_view
            };
            content_box.append (scroller);

            plot_picture = new Gtk.Picture () {
                halign = Gtk.Align.CENTER,
                visible = false
            };
            content_box.append (plot_picture);

            expander.set_child (content_box);
            this.append (expander);
        }

        public void set_output (string text_output, string? plot_path, int execution_count = 1) {
            expander.label = @"Out [$execution_count]:";
            log_view.get_buffer ().set_text (text_output);

            if (plot_path != null && GLib.FileUtils.test (plot_path, GLib.FileTest.EXISTS)) {
                plot_picture.set_filename (plot_path);
                plot_picture.set_visible (true);
            } else {
                plot_picture.set_visible (false);
            }
        }
    }
}
