namespace Imladris {
    public static int main (string[] args) {
        // Ensure WebKitGTK 6.0 WebProcess runs reliably without nested bwrap
        // namespace aborts across all environments (Flatpak, Debian unprivileged userns, Wayland)
        GLib.Environment.set_variable ("WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS", "1", true);

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
