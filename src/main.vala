namespace Imladris {
    public static int main (string[] args) {
        // In Flatpak sandboxes, WebKitGTK 6.0 inner bwrap sandbox collides with
        // the host Bubblewrap credentials / a11y portal, causing WebProcess abort (SIGABRT).
        // Disabling WebKit's internal nested sandbox inside the already-sandboxed Flatpak container
        // restores 100% reliable live preview rendering across all kernels and distributions.
        if (GLib.FileUtils.test ("/.flatpak-info", GLib.FileTest.EXISTS) ||
            GLib.Environment.get_variable ("FLATPAK_ID") != null) {
            GLib.Environment.set_variable ("WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS", "1", false);
        }

        if ("--mcp-server" in args) {
            var loop = new GLib.MainLoop ();
            McpServer.run_stdio_server_async.begin (null);
            loop.run ();
            return 0;
        }

        GtkSource.init ();
        var app = new Application ();
        return app.run (args);
    }
}
