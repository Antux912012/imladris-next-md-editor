namespace Imladris {
    public class DocumentModel : GLib.Object {
        private string _raw_text = "";
        private bool _is_modified = false;
        private GLib.File? _location = null;
        private string _title = "Untitled";

        public GLib.File? location {
            get { return _location; }
            set {
                if (_location != value) {
                    _location = value;
                    if (_location != null) {
                        title = _location.get_basename ();
                    } else {
                        title = "Untitled";
                    }
                    location_changed (_location);
                    notify_property ("location");
                }
            }
        }

        public string title {
            get { return _title; }
            set {
                if (_title != value) {
                    _title = value;
                    notify_property ("title");
                }
            }
        }

        public string raw_text {
            get { return _raw_text; }
            set {
                if (_raw_text != value) {
                    _raw_text = value;
                    text_changed (_raw_text);
                    notify_property ("raw-text");
                }
            }
        }

        public bool is_modified {
            get { return _is_modified; }
            set {
                if (_is_modified != value) {
                    _is_modified = value;
                    modification_changed (_is_modified);
                    notify_property ("is-modified");
                }
            }
        }

        public int cursor_line { get; set; default = 1; }
        public int cursor_offset { get; set; default = 0; }

        public signal void text_changed (string new_text);
        public signal void parsed_html_ready (string html);
        public signal void modification_changed (bool modified);
        public signal void location_changed (GLib.File? new_location);

        public DocumentModel (GLib.File? file = null) {
            Object ();
            if (file != null) {
                this.location = file;
            }
        }

        construct {
            _raw_text = "";
            _is_modified = false;
            _title = "Untitled";
            cursor_line = 1;
            cursor_offset = 0;
        }

        public void update_text_from_view (string new_text) {
            if (_raw_text != new_text) {
                _raw_text = new_text;
                is_modified = true;
                text_changed (_raw_text);
                notify_property ("raw-text");
            }
        }

        public void emit_parsed_html (string html) {
            parsed_html_ready (html);
        }
    }
}
