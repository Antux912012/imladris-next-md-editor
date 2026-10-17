namespace Imladris {
    public static int main (string[] args) {
        GtkSource.init ();
        var app = new Application ();
        return app.run (args);
    }
}
