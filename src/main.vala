namespace Imladris {
    public static int main (string[] args) {
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
