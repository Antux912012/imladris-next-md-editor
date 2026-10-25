namespace Imladris {

    public delegate void StringInsertCallback (string text_to_insert);

    public class SmartRibbonHelpers : Object {

        /**
         * 1. Table Builder Helper with M x N grid and GFM alignment options
         */
        public static Gtk.Popover create_table_builder_popover (owned TableInsertCallback cb) {
            return PopoverFactory.create_table_picker_popover ((owned) cb);
        }

        /**
         * 2. Code Chunk Inserter with language selector
         */
        public static Gtk.Popover create_code_chunk_popover (owned StringInsertCallback cb) {
            var popover = new Gtk.Popover ();
            var vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 6) {
                margin_top = 8,
                margin_bottom = 8,
                margin_start = 8,
                margin_end = 8
            };

            vbox.append (new Gtk.Label ("Insert Code Chunk / Fenced Block") {
                css_classes = { "heading" }
            });

            string[] langs = { "r", "python", "julia", "bash", "sql", "typescript", "json", "yaml" };
            var grid = new Gtk.Grid () { row_spacing = 4, column_spacing = 6 };
            int row = 0;
            int col = 0;
            foreach (string l in langs) {
                string lang = l;
                var btn = new Gtk.Button.with_label (lang.up ());
                btn.clicked.connect (() => {
                    popover.popdown ();
                    string snippet = @"\n```{$lang}\n#| echo: true\n\n```\n";
                    cb (snippet);
                });
                grid.attach (btn, col, row, 1, 1);
                col++;
                if (col >= 4) {
                    col = 0;
                    row++;
                }
            }
            vbox.append (grid);
            popover.set_child (vbox);
            return popover;
        }

        /**
         * 3. Citations & Bibliography Helper
         */
        public static Gtk.Popover create_citation_popover (owned StringInsertCallback cb) {
            var popover = new Gtk.Popover ();
            var vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 6) {
                margin_top = 8,
                margin_bottom = 8,
                margin_start = 8,
                margin_end = 8,
                width_request = 280
            };

            vbox.append (new Gtk.Label ("Insert Citation (@key)") {
                css_classes = { "heading" }
            });

            var entry = new Gtk.Entry () {
                placeholder_text = "e.g. knuth1984, wickham2019"
            };
            vbox.append (entry);

            var btn = new Gtk.Button.with_label ("Insert Citation (@key)");
            btn.add_css_class ("suggested-action");
            btn.clicked.connect (() => {
                string key = entry.text.strip ();
                if (key != "") {
                    popover.popdown ();
                    if (!key.has_prefix ("@")) key = "@" + key;
                    cb (key + " ");
                }
            });
            vbox.append (btn);

            var bib_btn = new Gtk.Button.with_label ("Insert Bibliography Block");
            bib_btn.clicked.connect (() => {
                popover.popdown ();
                cb ("\n## References\n\n::: {#refs}\n:::\n");
            });
            vbox.append (bib_btn);

            popover.set_child (vbox);
            return popover;
        }

        /**
         * 4. Special Symbols Picker (Math, Greek, Arrows, Logic)
         */
        public static Gtk.Popover create_symbols_popover (owned StringInsertCallback cb) {
            var popover = new Gtk.Popover ();
            var vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 6) {
                margin_top = 8,
                margin_bottom = 8,
                margin_start = 8,
                margin_end = 8,
                width_request = 300
            };

            vbox.append (new Gtk.Label ("Special Symbols & Operators") {
                css_classes = { "heading" }
            });

            string[] symbols = {
                "α", "β", "γ", "δ", "ε", "θ", "λ", "μ", "π", "σ", "ω", "Δ", "Ω",
                "±", "×", "÷", "≠", "≈", "≤", "≥", "∑", "∏", "∫", "∂", "√", "∞",
                "←", "→", "↑", "↓", "↔", "⇒", "⇔", "∈", "∉", "⊂", "⊆", "∪", "∩"
            };

            var grid = new Gtk.Grid () { row_spacing = 4, column_spacing = 4, halign = Gtk.Align.CENTER };
            int row = 0;
            int col = 0;
            foreach (string sym in symbols) {
                string s = sym;
                var b = new Gtk.Button.with_label (s);
                b.clicked.connect (() => {
                    popover.popdown ();
                    cb (s);
                });
                grid.attach (b, col, row, 1, 1);
                col++;
                if (col >= 8) {
                    col = 0;
                    row++;
                }
            }

            vbox.append (grid);
            popover.set_child (vbox);
            return popover;
        }

        /**
         * 5. Emoji & Unicode Picker
         */
        public static Gtk.Popover create_emoji_popover (owned StringInsertCallback cb) {
            var popover = new Gtk.Popover ();
            var vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 6) {
                margin_top = 8,
                margin_bottom = 8,
                margin_start = 8,
                margin_end = 8,
                width_request = 320
            };

            vbox.append (new Gtk.Label ("Emoji & Shortcodes") {
                css_classes = { "heading" }
            });

            string[] emojis = {
                "🚀", "✨", "🔥", "💡", "📊", "📈", "📉", "🔬", "💻", "📝",
                "📌", "✅", "⚠️", "❌", "🎉", "🧠", "⚡", "🐧", "📦", "📚"
            };

            var grid = new Gtk.Grid () { row_spacing = 4, column_spacing = 4, halign = Gtk.Align.CENTER };
            int row = 0;
            int col = 0;
            foreach (string em in emojis) {
                string e = em;
                var b = new Gtk.Button.with_label (e);
                b.clicked.connect (() => {
                    popover.popdown ();
                    cb (e + " ");
                });
                grid.attach (b, col, row, 1, 1);
                col++;
                if (col >= 7) {
                    col = 0;
                    row++;
                }
            }

            vbox.append (grid);
            popover.set_child (vbox);
            return popover;
        }
    }
}
