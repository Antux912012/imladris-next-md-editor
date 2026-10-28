using GLib;
using Gtk;
using GtkSource;
using Imladris.Core;

namespace Imladris.AI {

    public class AiCompletionProposal : GLib.Object, GtkSource.CompletionProposal {
        public string text { get; set; }
        public string label { get; set; }
        public string summary { get; set; }

        public AiCompletionProposal (string text, string label, string summary = "") {
            this.text = text;
            this.label = label;
            this.summary = summary;
        }
    }

    public class AiCompletionProvider : GLib.Object, GtkSource.CompletionProvider {

        public AiCompletionProvider () {
        }

        public string? get_title () {
            return "Elrond AI";
        }

        public int get_priority (GtkSource.CompletionContext context) {
            return 5; // Higher priority than dictionary words (10)
        }

        public bool is_trigger (Gtk.TextIter iter, unichar ch) {
            if (!SettingsManager.get_default ().inline_completion_enabled) {
                return false;
            }
            // Trigger on code-relevant characters or alphanumeric
            return ch.isalnum () || ch == '.' || ch == '$' || ch == '_' || ch == '>' || ch == '(';
        }

        public bool key_activates (GtkSource.CompletionContext context, GtkSource.CompletionProposal proposal, uint keyval, Gdk.ModifierType state) {
            return false;
        }

        public GenericArray<GtkSource.CompletionProposal>? list_alternates (GtkSource.CompletionContext context, GtkSource.CompletionProposal proposal) {
            return null;
        }

        public void activate (GtkSource.CompletionContext context, GtkSource.CompletionProposal proposal) {
            var p = proposal as AiCompletionProposal;
            if (p != null) {
                Gtk.TextIter iter;
                context.get_bounds (out iter, null);
                var buffer = context.get_buffer ();
                buffer.begin_user_action ();
                buffer.insert (ref iter, p.text, -1);
                buffer.end_user_action ();
            }
        }

        public void display (GtkSource.CompletionContext context, GtkSource.CompletionProposal proposal, GtkSource.CompletionCell cell) {
            var p = proposal as AiCompletionProposal;
            if (p == null) return;

            switch (cell.get_column ()) {
                case GtkSource.CompletionColumn.ICON:
                    cell.set_icon_name ("system-run-symbolic");
                    break;
                case GtkSource.CompletionColumn.TYPED_TEXT:
                    cell.set_text (p.label);
                    break;
                case GtkSource.CompletionColumn.DETAILS:
                    cell.set_text (p.summary.length > 0 ? p.summary : "Elrond AI");
                    break;
                default:
                    break;
            }
        }

        public async GLib.ListModel populate_async (GtkSource.CompletionContext context, GLib.Cancellable? cancellable) throws GLib.Error {
            var store = new GLib.ListStore (typeof (AiCompletionProposal));
            var settings = SettingsManager.get_default ();

            if (!settings.inline_completion_enabled) {
                return store;
            }

            var elrond = ElrondEngineController.get_default ();
            var config_mgr = AiConfigManager.get_default ();
            bool elrond_ready = elrond.is_ready;
            bool cloud_ready = config_mgr.has_valid_key (config_mgr.active_provider);

            if (!elrond_ready && !cloud_ready) {
                return store;
            }

            Gtk.TextIter cursor_iter;
            context.get_bounds (out cursor_iter, null);
            var buffer = context.get_buffer ();

            // Inspect line before cursor
            Gtk.TextIter line_start = cursor_iter;
            line_start.set_line_offset (0);
            string line_prefix = buffer.get_text (line_start, cursor_iter, false);
            if (line_prefix.strip ().length < 2) {
                return store; // Don't trigger on trivial or empty lines
            }

            // Extract window of context before and after cursor
            Gtk.TextIter prefix_start = cursor_iter;
            prefix_start.backward_chars (800);
            string prefix = buffer.get_text (prefix_start, cursor_iter, false);

            Gtk.TextIter suffix_end = cursor_iter;
            suffix_end.forward_chars (200);
            string suffix = buffer.get_text (cursor_iter, suffix_end, false);

            string completion_code = "";
            try {
                if (elrond_ready) {
                    completion_code = yield elrond.complete_code_async (prefix, suffix, "", cancellable);
                } else if (cloud_ready) {
                    var client = new AiClient ();
                    completion_code = yield client.complete_code_async (prefix, suffix, cancellable);
                }
            } catch (GLib.IOError.CANCELLED c) {
                return store;
            } catch (GLib.Error e) {
                return store;
            }

            if (completion_code.strip ().length > 0) {
                string first_line = completion_code.strip ().split ("\n")[0];
                if (first_line.length > 50) first_line = first_line.substring (0, 47) + "...";
                string summary = (completion_code.contains ("\n")) ? "Multi-line code" : "Inline completion";
                store.append (new AiCompletionProposal (completion_code, first_line, summary));
            }

            return store;
        }

        public void refilter (GtkSource.CompletionContext context, GLib.ListModel model) {
            // Proposals are generated contextually
        }
    }
}
