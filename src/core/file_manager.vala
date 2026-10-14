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
                title = "Open Document or Notebook",
                modal = true
            };

            var filter_list = new GLib.ListStore (typeof (Gtk.FileFilter));

            var all_supported_filter = new Gtk.FileFilter () {
                name = "All Supported Files (*.md, *.ipynb, *.qmd, *.Rmd)"
            };
            all_supported_filter.add_pattern ("*.md");
            all_supported_filter.add_pattern ("*.markdown");
            all_supported_filter.add_pattern ("*.ipynb");
            all_supported_filter.add_pattern ("*.qmd");
            all_supported_filter.add_pattern ("*.Rmd");
            all_supported_filter.add_pattern ("*.rmd");
            all_supported_filter.add_mime_type ("text/markdown");
            all_supported_filter.add_mime_type ("text/x-markdown");
            all_supported_filter.add_mime_type ("application/x-ipynb+json");
            all_supported_filter.add_mime_type ("application/json");
            filter_list.append (all_supported_filter);

            var md_filter = new Gtk.FileFilter () {
                name = "Markdown Files (*.md, *.markdown)"
            };
            md_filter.add_pattern ("*.md");
            md_filter.add_pattern ("*.markdown");
            md_filter.add_pattern ("*.mdown");
            md_filter.add_pattern ("*.mkd");
            filter_list.append (md_filter);

            var ipynb_filter = new Gtk.FileFilter () {
                name = "Jupyter Notebooks (*.ipynb)"
            };
            ipynb_filter.add_pattern ("*.ipynb");
            filter_list.append (ipynb_filter);

            var qmd_filter = new Gtk.FileFilter () {
                name = "Quarto & R-Markdown (*.qmd, *.Rmd)"
            };
            qmd_filter.add_pattern ("*.qmd");
            qmd_filter.add_pattern ("*.Rmd");
            qmd_filter.add_pattern ("*.rmd");
            filter_list.append (qmd_filter);

            var all_filter = new Gtk.FileFilter () {
                name = "All Files (*.*)"
            };
            all_filter.add_pattern ("*");
            filter_list.append (all_filter);

            dialog.set_filters (filter_list);
            dialog.set_default_filter (all_supported_filter);

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

                if (file.get_basename ().down ().has_suffix (".ipynb")) {
                    doc.raw_text = Imladris.Core.NotebookSerializer.ipynb_to_markdown (text);
                } else {
                    doc.raw_text = text;
                }
                doc.is_modified = false;
            } catch (Error e) {
                throw e;
            }
        }

        public async bool save_file_async (DocumentModel doc, Gtk.Window parent, bool save_as = false) throws GLib.Error {
            File? target_file = doc.location;

            if (target_file == null || save_as) {
                string default_ext = ".md";
                if (doc.is_jupyter) {
                    default_ext = ".ipynb";
                }

                var dialog = new Gtk.FileDialog () {
                    title = "Save Document or Notebook",
                    modal = true,
                    initial_name = doc.location != null ? doc.location.get_basename () : ("Untitled" + default_ext)
                };

                var filter_list = new GLib.ListStore (typeof (Gtk.FileFilter));

                var all_supported = new Gtk.FileFilter () {
                    name = "All Supported Files (*.md, *.ipynb, *.qmd, *.Rmd)"
                };
                all_supported.add_pattern ("*.md");
                all_supported.add_pattern ("*.ipynb");
                all_supported.add_pattern ("*.qmd");
                all_supported.add_pattern ("*.Rmd");
                filter_list.append (all_supported);

                var md_filter = new Gtk.FileFilter () {
                    name = "Markdown Files (*.md)"
                };
                md_filter.add_pattern ("*.md");
                md_filter.add_pattern ("*.markdown");
                filter_list.append (md_filter);

                var ipynb_filter = new Gtk.FileFilter () {
                    name = "Jupyter Notebooks (*.ipynb)"
                };
                ipynb_filter.add_pattern ("*.ipynb");
                filter_list.append (ipynb_filter);

                var qmd_filter = new Gtk.FileFilter () {
                    name = "Quarto & R-Markdown (*.qmd, *.Rmd)"
                };
                qmd_filter.add_pattern ("*.qmd");
                qmd_filter.add_pattern ("*.Rmd");
                filter_list.append (qmd_filter);

                dialog.set_filters (filter_list);
                dialog.set_default_filter (doc.is_jupyter ? ipynb_filter : md_filter);

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
                if (target_file.get_basename ().down ().has_suffix (".ipynb")) {
                    content = Imladris.Core.NotebookSerializer.markdown_to_ipynb (content);
                }

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
