using GLib;
using Gtk;

namespace Imladris.Execution {

    public class Nap {
        public static async void sleep (uint ms) {
            GLib.Timeout.add (ms, () => {
                sleep.callback ();
                return GLib.Source.REMOVE;
            });
            yield;
        }
    }

    /**
     * Pillar 11: Inline Document Code Chunk Execution & Plot/Stdout Capture Engine.
     */
    public class ChunkExecutionEngine : GLib.Object {
        private ReplBridge r_bridge;
        private ReplBridge python_bridge;
        private string project_root;

        public class ChunkResult {
            public string stdout { get; set; default = ""; }
            public string stderr { get; set; default = ""; }
            public string? plot_path { get; set; default = null; }
            public bool success { get; set; default = true; }
        }

        public ChunkExecutionEngine (string project_root, ReplBridge r_bridge, ReplBridge python_bridge) {
            this.project_root = project_root;
            this.r_bridge = r_bridge;
            this.python_bridge = python_bridge;
        }

        /**
         * Wraps user chunk code with plotting capture harnesses and executes it.
         */
        public async ChunkResult execute_chunk (LanguageRuntime lang, string raw_code, string chunk_id) throws GLib.Error {
            var result = new ChunkResult ();
            string tmp_dir = Core.PlatformUtils.get_shared_cache_dir ("tmp");
            string plot_filename = GLib.Path.build_filename (tmp_dir, "imladris_plot_%s.png".printf (chunk_id));

            string sentinel = "__IMLADRIS_CHUNK_DONE_%s__".printf (chunk_id);
            string wrapped_code;

            if (lang == LanguageRuntime.R) {
                // R Capture Harness: Redirects graphics device to high-DPI PNG and captures output
                wrapped_code = """
{
  .imladris.plot.file <- "%s"
  png(filename = .imladris.plot.file, width = 1200, height = 800, res = 150)
  .imladris.has.plot <- FALSE
  .imladris.plot.hook <- function(...) { .imladris.has.plot <<- TRUE }
  # Execute user code safely
  .imladris.res <- tryCatch({
%s
  }, error = function(e) {
    message(e)
    invisible(NULL)
  })
  if (dev.cur() > 1) dev.off()
  if (file.exists(.imladris.plot.file) && file.info(.imladris.plot.file)$size > 68) {
    cat(paste0("\n[IMLADRIS_PLOT:", .imladris.plot.file, "]\n"))
  } else {
    unlink(.imladris.plot.file)
  }
  cat(paste0("\n", "%s", "\n"))
}
""".printf (plot_filename.replace ("\\", "/"), raw_code, sentinel);

            } else {
                // Python Capture Harness: Hooks matplotlib and captures stdout
                // Base64 encoding ensures multiline, quotation marks, and indentation safety
                string b64_code = GLib.Base64.encode (raw_code.data);
                wrapped_code = """
import sys, io, os, base64
from contextlib import redirect_stdout, redirect_stderr

_imladris_plot_file = r"%s"
_imladris_stdout = io.StringIO()
_imladris_stderr = io.StringIO()

try:
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    plt.clf()
    _imladris_has_mpl = True
except ImportError:
    _imladris_has_mpl = False

with redirect_stdout(_imladris_stdout), redirect_stderr(_imladris_stderr):
    try:
        _imladris_raw = base64.b64decode("%s").decode('utf-8')
        exec(compile(_imladris_raw, '<chunk>', 'exec'), globals())
    except Exception as e:
        import traceback
        traceback.print_exc(file=sys.stderr)

if _imladris_has_mpl and plt.get_fignums():
    plt.savefig(_imladris_plot_file, dpi=150, bbox_inches='tight')
    plt.close('all')
    if os.path.exists(_imladris_plot_file):
        print(f"\n[IMLADRIS_PLOT:{_imladris_plot_file}]")

sys.stdout.write(_imladris_stdout.getvalue())
sys.stderr.write(_imladris_stderr.getvalue())
print(f"\n%s")
""".printf (plot_filename, b64_code, sentinel);
            }

            // Route execution to active bridge
            ReplBridge active_bridge = (lang == LanguageRuntime.R) ? r_bridge : python_bridge;

            // Capture output streams via signal connection temporarily
            var output_buffer = new GLib.StringBuilder ();
            var error_buffer = new GLib.StringBuilder ();

            ulong out_id = active_bridge.output_received.connect ((text) => {
                output_buffer.append (text);
            });
            ulong err_id = active_bridge.error_received.connect ((text) => {
                error_buffer.append (text);
            });

            yield active_bridge.send_command (wrapped_code);

            // Wait for sentinel with timeout
            int elapsed = 0;
            while (!output_buffer.str.contains (sentinel) && elapsed < 30000 && active_bridge.is_running) {
                yield Nap.sleep (50);
                elapsed += 50;
            }

            active_bridge.disconnect (out_id);
            active_bridge.disconnect (err_id);

            string full_output = output_buffer.str;
            result.stderr = error_buffer.str;

            // Strip sentinel
            if (full_output.contains (sentinel)) {
                full_output = full_output.replace (sentinel, "").strip ();
            }

            // Extract plot tag if generated
            if (full_output.contains ("[IMLADRIS_PLOT:")) {
                int start_idx = full_output.index_of ("[IMLADRIS_PLOT:") + 15;
                int end_idx = full_output.index_of_char (']', start_idx);
                if (end_idx > start_idx) {
                    result.plot_path = full_output.substring (start_idx, end_idx - start_idx);
                    // Strip plot tag from clean stdout
                    full_output = full_output.substring (0, start_idx - 15) + full_output.substring (end_idx + 1);
                }
            }

            result.stdout = full_output.strip ();
            result.success = (result.stderr.length == 0);
            return result;
        }
    }

    /**
     * Inline UI Widget rendered directly beneath code chunks in GtkSourceView.
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

        public void update_output (ChunkExecutionEngine.ChunkResult res) {
            log_view.get_buffer ().set_text (res.stdout + (res.stderr.length > 0 ? "\n[STDERR]:\n" + res.stderr : ""));

            if (res.plot_path != null && GLib.FileUtils.test (res.plot_path, GLib.FileTest.EXISTS)) {
                plot_picture.set_filename (res.plot_path);
                plot_picture.set_visible (true);
            } else {
                plot_picture.set_visible (false);
            }
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
