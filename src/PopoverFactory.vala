namespace Imladris {

    public delegate void TableInsertCallback (int rows, int cols);
    public delegate void ColorSelectCallback (string hex_color);

    public class PopoverFactory : Object {

        /**
         * Builds an interactive 6x6 Table Grid Picker Popover that inserts Markdown/HTML tables.
         */
        public static Gtk.Popover create_table_picker_popover (owned TableInsertCallback cb) {
            var popover = new Gtk.Popover ();
            var vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 6) {
                margin_top = 8,
                margin_bottom = 8,
                margin_start = 8,
                margin_end = 8
            };

            var status_lbl = new Gtk.Label ("Insert Table (Markdown / HTML)");
            vbox.append (status_lbl);

            var grid = new Gtk.Grid () {
                row_spacing = 3,
                column_spacing = 3,
                halign = Gtk.Align.CENTER
            };

            for (int r = 1; r <= 6; r++) {
                for (int c = 1; c <= 6; c++) {
                    int row_val = r;
                    int col_val = c;
                    var cell_btn = new Gtk.Button () {
                        tooltip_text = @"$row_val × $col_val Table"
                    };
                    cell_btn.add_css_class ("table-cell-btn");
                    cell_btn.clicked.connect (() => {
                        popover.popdown ();
                        cb (row_val, col_val);
                    });
                    grid.attach (cell_btn, c - 1, r - 1, 1, 1);
                }
            }

            vbox.append (grid);
            popover.set_child (vbox);
            return popover;
        }

        /**
         * Builds a Color Palette Swatch Popover for text foreground or background highlighting.
         */
        public static Gtk.Popover create_color_palette_popover (owned ColorSelectCallback cb) {
            var popover = new Gtk.Popover ();
            var vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 6) {
                margin_top = 8,
                margin_bottom = 8,
                margin_start = 8,
                margin_end = 8
            };

            vbox.append (new Gtk.Label ("Select Color"));

            string[] colors = {
                "#000000", "#e01b24", "#ff7800", "#f6d32d",
                "#2ec27e", "#3584e4", "#9141ac", "#ffffff"
            };

            var flow = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4);
            foreach (string hex in colors) {
                string target_hex = hex;
                var btn = new Gtk.Button () {
                    tooltip_text = target_hex
                };
                btn.add_css_class ("color-swatch-btn");
                btn.clicked.connect (() => {
                    popover.popdown ();
                    cb (target_hex);
                });
                flow.append (btn);
            }

            vbox.append (flow);
            popover.set_child (vbox);
            return popover;
        }
    }
}
