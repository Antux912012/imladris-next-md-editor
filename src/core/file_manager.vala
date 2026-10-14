namespace Imladris {
    public class FileManager : GLib.Object {
        private static FileManager? instance = null;

        public static FileManager get_default () {
            if (instance == null) {
                instance = new FileManager ();
            }
            return instance;
        }

        public FileManager () {
            Object ();
        }

        construct {
        }

        public async File? open_file_dialog_async (Gtk.Window parent) throws GLib.Error {
            var dialog = new Gtk.FileDialog () {
                title = "Open Markdown Document",
                modal = true
            };

            var filter_list = new GLib.ListStore (typeof (Gtk.FileFilter));

            var md_filter = new Gtk.FileFilter () {
                name = "Markdown Files (*.md, *.markdown)"
            };
            md_filter.add_pattern ("*.md");
            md_filter.add_pattern ("*.markdown");
            md_filter.add_pattern ("*.mdown");
            md_filter.add_pattern ("*.mkd");
            md_filter.add_mime_type ("text/markdown");
            md_filter.add_mime_type ("text/x-markdown");
            filter_list.append (md_filter);

            var all_filter = new Gtk.FileFilter () {
                name = "All Files (*.*)"
            };
            all_filter.add_pattern ("*");
            filter_list.append (all_filter);

            dialog.set_filters (filter_list);
            dialog.set_default_filter (md_filter);

            try {
                return yield dialog.open (parent, null);
            } catch (Error e) {
                throw e;
            }
        }

        public async void load_file_into_doc_async (File file, DocumentModel doc) throws GLib.Error {
            try {
                uint8[] contents;
                string etag;
                yield file.load_contents_async (null, out contents, out etag);

                string text = (string) contents;
                doc.location = file;
                doc.raw_text = text;
                doc.is_modified = false;
            } catch (Error e) {
                throw e;
            }
        }

        public async bool save_file_async (DocumentModel doc, Gtk.Window parent, bool save_as = false) throws GLib.Error {
            File? target_file = doc.location;

            if (target_file == null || save_as) {
                var dialog = new Gtk.FileDialog () {
                    title = "Save Markdown Document",
                    modal = true,
                    initial_name = doc.location != null ? doc.location.get_basename () : "Untitled.md"
                };

                var filter_list = new GLib.ListStore (typeof (Gtk.FileFilter));
                var md_filter = new Gtk.FileFilter () {
                    name = "Markdown Files (*.md)"
                };
                md_filter.add_pattern ("*.md");
                md_filter.add_pattern ("*.markdown");
                filter_list.append (md_filter);
                dialog.set_filters (filter_list);
                dialog.set_default_filter (md_filter);

                try {
                    target_file = yield dialog.save (parent, null);
                } catch (Error e) {
                    return false;
                }

                if (target_file == null) {
                    return false;
                }
            }

            try {
                string content = doc.raw_text;
                string new_etag;
                yield target_file.replace_contents_async (
                    content.data,
                    null,
                    false,
                    GLib.FileCreateFlags.REPLACE_DESTINATION,
                    null,
                    out new_etag
                );

                doc.location = target_file;
                doc.is_modified = false;
                return true;
            } catch (Error e) {
                throw e;
            }
        }
    }
}
