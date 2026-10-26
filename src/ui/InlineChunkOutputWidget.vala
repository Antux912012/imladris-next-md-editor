using GLib;
using Gtk;

namespace Imladris.UI {

    /**
     * Pillar 11: Inline Document Code Chunk Execution & Output Card
     * Inherits from Execution.InlineChunkOutputWidget to provide seamless
     * integration with DocumentPage, GtkSource.View child anchors, and PersistentPanelRegistry.
     */
    public class InlineChunkOutputWidget : Execution.InlineChunkOutputWidget {

        public InlineChunkOutputWidget (int end_line = -1) {
            base (end_line);
        }
    }
}
