namespace Imladris {
    public class Window : Adw.ApplicationWindow {
        private Adw.ToastOverlay toast_overlay;
        private Adw.ToolbarView toolbar_view;
        private Adw.HeaderBar header_bar;
        private Adw.ViewSwitcher view_switcher;
        private Adw.TabBar tab_bar;
        private Adw.TabView tab_view;

        private Gee.HashMap<Adw.TabPage, TabPageContent> tab_pages;
        private Gee.ArrayList<DocumentModel> documents;

        public Window (Gtk.Application app) {
            Object (application: app);
        }

        construct {
            title = "Imladris";
            set_default_size (1080, 720);

            tab_pages = new Gee.HashMap<Adw.TabPage, TabPageContent> ();
            documents = new Gee.ArrayList<DocumentModel> ();

            toast_overlay = new Adw.ToastOverlay ();
            toolbar_view = new Adw.ToolbarView ();
            header_bar = new Adw.HeaderBar ();

            view_switcher = new Adw.ViewSwitcher ();
            view_switcher.policy = Adw.ViewSwitcherPolicy.WIDE;
            header_bar.set_title_widget (view_switcher);

            var new_btn = new Gtk.Button.from_icon_name ("tab-new-symbolic") {
                tooltip_text = "New Document (Ctrl+N)",
                action_name = "app.new-tab"
            };
            header_bar.pack_start (new_btn);

            var open_btn = new Gtk.Button.from_icon_name ("document-open-symbolic") {
                tooltip_text = "Open File (Ctrl+O)",
                action_name = "app.open"
            };
            header_bar.pack_start (open_btn);

            var save_btn = new Gtk.Button.from_icon_name ("document-save-symbolic") {
                tooltip_text = "Save Document (Ctrl+S)",
                action_name = "app.save"
            };
            header_bar.pack_end (save_btn);

            var primary_menu = build_primary_menu ();
            var menu_btn = new Gtk.MenuButton () {
                icon_name = "open-menu-symbolic",
                menu_model = primary_menu,
                tooltip_text = "Main Menu"
            };
            header_bar.pack_end (menu_btn);

            tab_view = new Adw.TabView ();
            tab_bar = new Adw.TabBar () {
                view = tab_view,
                autohide = false
            };

            toolbar_view.add_top_bar (header_bar);
            toolbar_view.add_top_bar (tab_bar);
            toolbar_view.set_content (tab_view);

            toast_overlay.set_child (toolbar_view);
            set_content (toast_overlay);

            setup_tab_signals ();
            setup_shortcuts ();

            create_initial_document ();
        }

        private GLib.MenuModel build_primary_menu () {
            var menu = new GLib.Menu ();

            var file_section = new GLib.Menu ();
            file_section.append ("Save As...", "app.save-as");
            file_section.append ("Close Tab", "app.close-tab");
            menu.append_section (null, file_section);

            var app_section = new GLib.Menu ();
            app_section.append ("About Imladris", "app.about");
            app_section.append ("Quit", "app.quit");
            menu.append_section (null, app_section);

            return menu;
        }

        private void setup_tab_signals () {
            tab_view.notify["selected-page"].connect (() => {
                var page = tab_view.selected_page;
                if (page != null && tab_pages.has_key (page)) {
                    var content = tab_pages.get (page);
                    view_switcher.stack = content.view_stack;
                    update_window_title ();
                }
            });

            tab_view.close_page.connect ((page) => {
                if (tab_pages.has_key (page)) {
                    var content = tab_pages.get (page);
                    if (content.document.is_modified) {
                        prompt_close_page_async.begin (page);
                        return true;
                    }
                }
                return false;
            });

            tab_view.page_detached.connect ((page, position) => {
                if (tab_pages.has_key (page)) {
                    var content = tab_pages.get (page);
                    documents.remove (content.document);
                    tab_pages.unset (page);
                }

                if (tab_view.get_n_pages () == 0) {
                    create_new_tab ();
                }
            });
        }

        private async void prompt_close_page_async (Adw.TabPage page) {
            if (!tab_pages.has_key (page)) {
                tab_view.close_page_finish (page, true);
                return;
            }

            var content = tab_pages.get (page);
            var dialog = new Adw.AlertDialog (
                "Save Changes?",
                "Document \"%s\" has unsaved changes. Do you want to save before closing?".printf (content.document.title)
            );
            dialog.add_response ("cancel", "Cancel");
            dialog.add_response ("discard", "Discard");
            dialog.add_response ("save", "Save");

            dialog.set_response_appearance ("discard", Adw.ResponseAppearance.DESTRUCTIVE);
            dialog.set_response_appearance ("save", Adw.ResponseAppearance.SUGGESTED);
            dialog.set_default_response ("save");
            dialog.set_close_response ("cancel");

            try {
                string response = yield dialog.choose (this, null);
                if (response == "save") {
                    bool saved = yield FileManager.get_default ().save_file_async (content.document, this, false);
                    if (saved) {
                        show_toast ("Saved " + content.document.title);
                        tab_view.close_page_finish (page, true);
                    } else {
                        tab_view.close_page_finish (page, false);
                    }
                } else if (response == "discard") {
                    tab_view.close_page_finish (page, true);
                } else {
                    tab_view.close_page_finish (page, false);
                }
            } catch (Error e) {
                show_toast ("Error: " + e.message);
                tab_view.close_page_finish (page, false);
            }
        }

        public Adw.TabPage create_new_tab (DocumentModel? doc_param = null) {
            DocumentModel doc = doc_param ?? new DocumentModel ();
            var content = new TabPageContent (doc);
            var page = tab_view.append (content);

            tab_pages.set (page, content);
            documents.add (doc);

            update_page_state (page, doc);

            doc.notify["title"].connect (() => {
                update_page_state (page, doc);
                update_window_title ();
            });

            doc.notify["is-modified"].connect (() => {
                update_page_state (page, doc);
            });

            tab_view.set_selected_page (page);
            view_switcher.stack = content.view_stack;
            update_window_title ();

            return page;
        }

        private void update_page_state (Adw.TabPage page, DocumentModel doc) {
            page.title = doc.title;
            page.needs_attention = doc.is_modified;
            if (doc.is_modified) {
                page.indicator_icon = new ThemedIcon ("media-record-symbolic");
                page.indicator_tooltip = "Document has unsaved changes";
            } else {
                page.indicator_icon = null;
                page.indicator_tooltip = "";
            }
        }

        private void update_window_title () {
            var page = tab_view.selected_page;
            if (page != null && tab_pages.has_key (page)) {
                var content = tab_pages.get (page);
                title = "%s%s — Imladris".printf (
                    content.document.title,
                    content.document.is_modified ? " *" : ""
                );
            } else {
                title = "Imladris";
            }
        }

        public void prompt_open_file () {
            prompt_open_file_async.begin ();
        }

        private async void prompt_open_file_async () {
            try {
                var file = yield FileManager.get_default ().open_file_dialog_async (this);
                if (file != null) {
                    open_file (file);
                }
            } catch (Error e) {
                show_toast ("Error opening file: " + e.message);
            }
        }

        public void open_file (File file) {
            open_file_async.begin (file);
        }

        private async void open_file_async (File file) {
            try {
                var doc = new DocumentModel (file);
                yield FileManager.get_default ().load_file_into_doc_async (file, doc);
                create_new_tab (doc);
                show_toast ("Opened " + doc.title);
            } catch (Error e) {
                show_toast ("Error loading file: " + e.message);
            }
        }

        public void save_current_tab (bool save_as = false) {
            save_current_tab_async.begin (save_as);
        }

        private async void save_current_tab_async (bool save_as) {
            var page = tab_view.selected_page;
            if (page == null || !tab_pages.has_key (page)) {
                return;
            }

            var content = tab_pages.get (page);
            try {
                bool saved = yield FileManager.get_default ().save_file_async (content.document, this, save_as);
                if (saved) {
                    show_toast ("Saved " + content.document.title);
                    update_page_state (page, content.document);
                    update_window_title ();
                }
            } catch (Error e) {
                show_toast ("Error saving file: " + e.message);
            }
        }

        public void close_current_tab () {
            var page = tab_view.selected_page;
            if (page != null) {
                tab_view.close_page (page);
            }
        }

        public void show_toast (string message) {
            var toast = new Adw.Toast (message) {
                timeout = 3
            };
            toast_overlay.add_toast (toast);
        }

        public void apply_formatting_to_current (FormattingType type) {
            var page = tab_view.selected_page;
            if (page != null && tab_pages.has_key (page)) {
                var content = tab_pages.get (page);
                content.coding_view.apply_formatting (type);
            }
        }

        private void setup_shortcuts () {
            var controller = new Gtk.ShortcutController ();
            controller.set_scope (Gtk.ShortcutScope.LOCAL);

            var trigger_b = Gtk.ShortcutTrigger.parse_string ("<Primary>b");
            var action_b = new Gtk.CallbackAction ((widget, args) => {
                apply_formatting_to_current (FormattingType.BOLD);
                return true;
            });
            controller.add_shortcut (new Gtk.Shortcut (trigger_b, action_b));

            var trigger_i = Gtk.ShortcutTrigger.parse_string ("<Primary>i");
            var action_i = new Gtk.CallbackAction ((widget, args) => {
                apply_formatting_to_current (FormattingType.ITALIC);
                return true;
            });
            controller.add_shortcut (new Gtk.Shortcut (trigger_i, action_i));

            add_controller (controller);
        }

        private void create_initial_document () {
            var doc = new DocumentModel ();
            doc.title = "Welcome.md";
            doc.raw_text = """# Welcome to Imladris 🌿

Imladris is a native Linux Markdown editor built with **Vala**, **GTK4**, **Libadwaita**, **GtkSourceView 5**, and **WebKitGTK**.

## Features

- **Dual-Engine Architecture:** GtkSourceView 5 editor + live WebKitGTK rendering.
- **Asynchronous Processing:** Powered by `libcmark` in a background worker thread.
- **Contextual Formatting:** Select any text to reveal the floating formatting popover.
- **Synchronized View:** Cursor line changes smoothly align the rendered preview.
- **Libadwaita Layout:** GNOME HIG-compliant ToolbarView, ViewSwitcher, and TabBar.

### Formatting Examples

You can style text with *italics*, **bold**, or ~~strikethrough~~.

Here is an inline `code` snippet and a code block:

```vala
public static int main (string[] args) {
    var app = new Imladris.Application ();
    return app.run (args);
}
```

> "Not all those who wander are lost."
> — *J.R.R. Tolkien, The Fellowship of the Ring*

| Shortcut | Action |
| :--- | :--- |
| `Ctrl+N` | New Tab |
| `Ctrl+O` | Open File |
| `Ctrl+S` | Save Document |
| `Ctrl+W` | Close Tab |
| `Ctrl+B` | Bold Selection |
| `Ctrl+I` | Italic Selection |
""";
            doc.is_modified = false;
            create_new_tab (doc);
        }
    }
}
