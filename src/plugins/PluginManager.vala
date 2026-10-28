/* PluginManager.vala
 *
 * Copyright 2026 Antonio Antux
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

using GLib;
using JSC;
using Gee;

namespace Imladris.Plugins {

    public interface PluginHostWindow : GLib.Object {
        public abstract void show_toast (string message);
        public abstract string get_active_editor_text ();
        public abstract string get_active_selected_text ();
        public abstract void insert_in_active_editor (string text);
        public abstract void ask_elrond (string prompt);
        public abstract void append_console_log (string text);
        public abstract string[] list_workspace_files (string pattern);
        public abstract string read_workspace_file (string relative_path);
        public abstract void open_workspace_file (string relative_path, int line);
        public abstract string get_workspace_root ();
        public abstract string get_active_file_path ();
        public abstract void show_web_dialog (string title, string html_content, int width, int height);
    }

    public class PluginManifest : GLib.Object {
        public string id { get; set; default = ""; }
        public string name { get; set; default = ""; }
        public string version { get; set; default = "1.0.0"; }
        public string author { get; set; default = "Unknown"; }
        public string description { get; set; default = ""; }
        public string license { get; set; default = "GPL-3.0-or-later"; }
        public string icon { get; set; default = "application-x-addon-symbolic"; }
        public ArrayList<string> permissions { get; set; default = new ArrayList<string> (); }

        public bool has_permission (string perm) {
            return permissions.contains (perm);
        }

        public string format_permissions_summary () {
            if (permissions.is_empty) {
                return "None (Safe, isolated UI only)";
            }
            var parts = new ArrayList<string> ();
            foreach (var p in permissions) {
                switch (p) {
                    case "editor":
                        parts.add ("Editor Access");
                        break;
                    case "repl_r":
                        parts.add ("R Console Execution");
                        break;
                    case "repl_python":
                        parts.add ("Python Console Execution");
                        break;
                    case "elrond_ai":
                        parts.add ("Elrond AI Access");
                        break;
                    case "workspace":
                        parts.add ("Workspace Files Access");
                        break;
                    case "export":
                        parts.add ("Export Automation");
                        break;
                    default:
                        parts.add (p);
                        break;
                }
            }
            return string.joinv (", ", parts.to_array ());
        }

        public static PluginManifest? from_json (string json_content) {
            try {
                var parser = new Json.Parser ();
                parser.load_from_data (json_content);
                var root = parser.get_root ();
                if (root == null || root.get_node_type () != Json.NodeType.OBJECT) {
                    return null;
                }
                var obj = root.get_object ();

                var m = new PluginManifest ();
                m.id = obj.has_member ("id") ? obj.get_string_member ("id") : "";
                m.name = obj.has_member ("name") ? obj.get_string_member ("name") : m.id;
                m.version = obj.has_member ("version") ? obj.get_string_member ("version") : "1.0.0";
                m.author = obj.has_member ("author") ? obj.get_string_member ("author") : "Unknown";
                m.description = obj.has_member ("description") ? obj.get_string_member ("description") : "";
                m.license = obj.has_member ("license") ? obj.get_string_member ("license") : "GPL-3.0-or-later";
                m.icon = obj.has_member ("icon") ? obj.get_string_member ("icon") : "application-x-addon-symbolic";

                if (obj.has_member ("permissions")) {
                    var perm_arr = obj.get_array_member ("permissions");
                    if (perm_arr != null) {
                        for (uint i = 0; i < perm_arr.get_length (); i++) {
                            m.permissions.add (perm_arr.get_string_element (i));
                        }
                    }
                }

                if (m.id.strip () == "") return null;
                return m;
            } catch (GLib.Error e) {
                debug ("Failed to parse plugin manifest: %s", e.message);
                return null;
            }
        }
    }

    public class PluginInstance : GLib.Object {
        public PluginManifest manifest { get; construct; }
        public string dir_path { get; construct; }
        public bool is_enabled { get; set; default = false; }
        public JSC.Context? context { get; private set; default = null; }
        public ArrayList<string> registered_buttons { get; private set; }
        public unowned PluginManager manager { get; construct; }

        public PluginInstance (PluginManifest manifest, string dir_path, PluginManager manager) {
            Object (manifest: manifest, dir_path: dir_path, manager: manager);
            this.registered_buttons = new ArrayList<string> ();
        }

        public bool load () {
            if (is_enabled && context != null) return true;

            string main_js_path = Path.build_filename (dir_path, "main.js");
            if (!FileUtils.test (main_js_path, FileTest.EXISTS)) {
                warning ("Plugin [%s] missing main.js at %s", manifest.id, main_js_path);
                return false;
            }

            string script;
            try {
                FileUtils.get_contents (main_js_path, out script);
            } catch (GLib.Error e) {
                warning ("Plugin [%s] could not read main.js: %s", manifest.id, e.message);
                return false;
            }

            context = new JSC.Context ();
            context.push_exception_handler ((ctx, ex) => {
                warning ("Plugin [%s] JS exception: %s", manifest.name, ex.to_string ());
                manager.show_toast (@"Plugin '$(manifest.name)' error: $(ex.to_string ())");
            });

            var jsc_class = context.register_class ("NativeHostBridge", null, null, null);

                jsc_class.add_method ("showToast", (instance, jsc_args) => {
                    unowned PluginInstance plugin = (PluginInstance) instance;
                    if (jsc_args != null && jsc_args.length > 0) {
                        string msg = jsc_args.get (0).to_string ();
                        plugin.manager.show_toast (msg);
                    }
                    return new JSC.Value.@null (plugin.context);
                }, typeof (JSC.Value));

                jsc_class.add_method ("addRibbonButton", (instance, jsc_args) => {
                    unowned PluginInstance plugin = (PluginInstance) instance;
                    if (jsc_args != null && jsc_args.length >= 3) {
                        string btn_id = jsc_args.get (0).to_string ();
                        string label = jsc_args.get (1).to_string ();
                        string icon = jsc_args.get (2).to_string ();
                        if (!plugin.registered_buttons.contains (btn_id)) {
                            plugin.registered_buttons.add (btn_id);
                        }
                        plugin.manager.add_ribbon_button (plugin.manifest.id, btn_id, label, icon);
                    }
                    return new JSC.Value.@null (plugin.context);
                }, typeof (JSC.Value));

                jsc_class.add_method ("getText", (instance, jsc_args) => {
                    unowned PluginInstance plugin = (PluginInstance) instance;
                    if (!plugin.manifest.has_permission ("editor")) {
                        plugin.manager.show_toast (@"Plugin '$(plugin.manifest.name)' denied: missing 'editor' permission.");
                        return new JSC.Value.string (plugin.context, "");
                    }
                    string text = plugin.manager.get_active_editor_text ();
                    return new JSC.Value.string (plugin.context, text);
                }, typeof (JSC.Value));

                jsc_class.add_method ("getSelectedText", (instance, jsc_args) => {
                    unowned PluginInstance plugin = (PluginInstance) instance;
                    if (!plugin.manifest.has_permission ("editor")) {
                        plugin.manager.show_toast (@"Plugin '$(plugin.manifest.name)' denied: missing 'editor' permission.");
                        return new JSC.Value.string (plugin.context, "");
                    }
                    string text = plugin.manager.get_active_selected_text ();
                    return new JSC.Value.string (plugin.context, text);
                }, typeof (JSC.Value));

                jsc_class.add_method ("insertAtCursor", (instance, jsc_args) => {
                    unowned PluginInstance plugin = (PluginInstance) instance;
                    if (!plugin.manifest.has_permission ("editor")) {
                        plugin.manager.show_toast (@"Plugin '$(plugin.manifest.name)' denied: missing 'editor' permission.");
                        return new JSC.Value.@null (plugin.context);
                    }
                    if (jsc_args != null && jsc_args.length > 0) {
                        string insert_text = jsc_args.get (0).to_string ();
                        plugin.manager.insert_in_active_editor (insert_text);
                    }
                    return new JSC.Value.@null (plugin.context);
                }, typeof (JSC.Value));

                jsc_class.add_method ("runR", (instance, jsc_args) => {
                    unowned PluginInstance plugin = (PluginInstance) instance;
                    if (!plugin.manifest.has_permission ("repl_r")) {
                        plugin.manager.show_toast (@"Plugin '$(plugin.manifest.name)' denied: missing 'repl_r' permission.");
                        return new JSC.Value.@null (plugin.context);
                    }
                    if (jsc_args != null && jsc_args.length > 0) {
                        string code = jsc_args.get (0).to_string ();
                        plugin.manager.run_r_code (code);
                    }
                    return new JSC.Value.@null (plugin.context);
                }, typeof (JSC.Value));

                jsc_class.add_method ("runPython", (instance, jsc_args) => {
                    unowned PluginInstance plugin = (PluginInstance) instance;
                    if (!plugin.manifest.has_permission ("repl_python")) {
                        plugin.manager.show_toast (@"Plugin '$(plugin.manifest.name)' denied: missing 'repl_python' permission.");
                        return new JSC.Value.@null (plugin.context);
                    }
                    if (jsc_args != null && jsc_args.length > 0) {
                        string code = jsc_args.get (0).to_string ();
                        plugin.manager.run_python_code (code);
                    }
                    return new JSC.Value.@null (plugin.context);
                }, typeof (JSC.Value));

                jsc_class.add_method ("askElrond", (instance, jsc_args) => {
                    unowned PluginInstance plugin = (PluginInstance) instance;
                    if (!plugin.manifest.has_permission ("elrond_ai")) {
                        plugin.manager.show_toast (@"Plugin '$(plugin.manifest.name)' denied: missing 'elrond_ai' permission.");
                        return new JSC.Value.@null (plugin.context);
                    }
                    if (jsc_args != null && jsc_args.length > 0) {
                        string prompt = jsc_args.get (0).to_string ();
                        plugin.manager.ask_elrond (prompt);
                    }
                    return new JSC.Value.@null (plugin.context);
                }, typeof (JSC.Value));

                jsc_class.add_method ("listFiles", (instance, jsc_args) => {
                    unowned PluginInstance plugin = (PluginInstance) instance;
                    if (!plugin.manifest.has_permission ("workspace")) {
                        plugin.manager.show_toast (@"Plugin '$(plugin.manifest.name)' denied: missing 'workspace' permission.");
                        return plugin.context.evaluate ("[]", -1);
                    }
                    string pattern = (jsc_args != null && jsc_args.length > 0) ? jsc_args.get (0).to_string () : "*.md";
                    string[] files = plugin.manager.list_workspace_files (pattern);
                    var builder = new Json.Builder ();
                    builder.begin_array ();
                    foreach (var f in files) {
                        builder.add_string_value (f);
                    }
                    builder.end_array ();
                    var gen = new Json.Generator ();
                    gen.set_root (builder.get_root ());
                    string json_str = gen.to_data (null);
                    return plugin.context.evaluate (json_str, -1);
                }, typeof (JSC.Value));

                jsc_class.add_method ("readFile", (instance, jsc_args) => {
                    unowned PluginInstance plugin = (PluginInstance) instance;
                    if (!plugin.manifest.has_permission ("workspace")) {
                        plugin.manager.show_toast (@"Plugin '$(plugin.manifest.name)' denied: missing 'workspace' permission.");
                        return new JSC.Value.string (plugin.context, "");
                    }
                    if (jsc_args != null && jsc_args.length > 0) {
                        string rel_path = jsc_args.get (0).to_string ();
                        string content = plugin.manager.read_workspace_file (rel_path);
                        return new JSC.Value.string (plugin.context, content);
                    }
                    return new JSC.Value.string (plugin.context, "");
                }, typeof (JSC.Value));

                jsc_class.add_method ("openFile", (instance, jsc_args) => {
                    unowned PluginInstance plugin = (PluginInstance) instance;
                    if (!plugin.manifest.has_permission ("workspace")) {
                        plugin.manager.show_toast (@"Plugin '$(plugin.manifest.name)' denied: missing 'workspace' permission.");
                        return new JSC.Value.@null (plugin.context);
                    }
                    if (jsc_args != null && jsc_args.length > 0) {
                        string rel_path = jsc_args.get (0).to_string ();
                        int line = (jsc_args.length > 1) ? (int) jsc_args.get (1).to_double () : 1;
                        plugin.manager.open_workspace_file (rel_path, line);
                    }
                    return new JSC.Value.@null (plugin.context);
                }, typeof (JSC.Value));

                jsc_class.add_method ("getWorkspaceRoot", (instance, jsc_args) => {
                    unowned PluginInstance plugin = (PluginInstance) instance;
                    if (!plugin.manifest.has_permission ("workspace")) {
                        return new JSC.Value.string (plugin.context, "");
                    }
                    return new JSC.Value.string (plugin.context, plugin.manager.get_workspace_root ());
                }, typeof (JSC.Value));

                jsc_class.add_method ("getActiveFilePath", (instance, jsc_args) => {
                    unowned PluginInstance plugin = (PluginInstance) instance;
                    return new JSC.Value.string (plugin.context, plugin.manager.get_active_file_path ());
                }, typeof (JSC.Value));

                jsc_class.add_method ("showWebDialog", (instance, jsc_args) => {
                    unowned PluginInstance plugin = (PluginInstance) instance;
                    if (jsc_args != null && jsc_args.length >= 2) {
                        string title = jsc_args.get (0).to_string ();
                        string html = jsc_args.get (1).to_string ();
                        int width = (jsc_args.length > 2) ? (int) jsc_args.get (2).to_double () : 950;
                        int height = (jsc_args.length > 3) ? (int) jsc_args.get (3).to_double () : 700;
                        plugin.manager.show_web_dialog (title, html, width, height);
                    }
                    return new JSC.Value.@null (plugin.context);
                }, typeof (JSC.Value));

                jsc_class.add_method ("readAsset", (instance, jsc_args) => {
                    unowned PluginInstance plugin = (PluginInstance) instance;
                    if (jsc_args != null && jsc_args.length > 0) {
                        string asset_rel = jsc_args.get (0).to_string ();
                        if (!asset_rel.contains ("..")) {
                            string asset_path = Path.build_filename (plugin.dir_path, asset_rel);
                            if (FileUtils.test (asset_path, FileTest.EXISTS)) {
                                try {
                                    string content;
                                    FileUtils.get_contents (asset_path, out content);
                                    return new JSC.Value.string (plugin.context, content);
                                } catch (GLib.Error e) {
                                    debug ("Error reading plugin asset: %s", e.message);
                                }
                            }
                        }
                    }
                    return new JSC.Value.string (plugin.context, "");
                }, typeof (JSC.Value));

                var host_obj = new JSC.Value.object (context, this, jsc_class);
                context.set_value ("_host", host_obj);

                // Inject declarative imladris bridge
                context.evaluate ("""
                    var imladris = {
                        ui: {
                            showToast: function(msg) { _host.showToast(String(msg)); },
                            addRibbonButton: function(id_or_options, label, icon, callback) {
                                var id, lbl, icn, cb;
                                if (typeof id_or_options === 'object' && id_or_options !== null) {
                                    id = id_or_options.id;
                                    lbl = id_or_options.label;
                                    icn = id_or_options.icon;
                                    cb = id_or_options.onClick || id_or_options.callback;
                                } else {
                                    id = id_or_options;
                                    lbl = label;
                                    icn = icon;
                                    cb = callback;
                                }
                                _host.addRibbonButton(String(id), String(lbl), String(icn));
                                imladris._callbacks = imladris._callbacks || {};
                                imladris._callbacks[id] = cb;
                            },
                            openWebDialog: function(options) {
                                var opts = options || {};
                                _host.showWebDialog(
                                    String(opts.title || "Imladris View"),
                                    String(opts.html || ""),
                                    Number(opts.width || 950),
                                    Number(opts.height || 700)
                                );
                            }
                        },
                        workspace: {
                            listFiles: function(pattern) { return _host.listFiles(pattern || "*.md"); },
                            readFile: function(path) { return _host.readFile(String(path)); },
                            openFile: function(path, line) { return _host.openFile(String(path), Number(line || 1)); },
                            getRoot: function() { return _host.getWorkspaceRoot(); },
                            getActiveFile: function() { return _host.getActiveFilePath(); }
                        },
                        plugin: {
                            readAsset: function(path) { return _host.readAsset(String(path)); }
                        },
                        editor: {
                            getText: function() { return _host.getText(); },
                            getSelectedText: function() { return _host.getSelectedText(); },
                            insertAtCursor: function(text) { _host.insertAtCursor(String(text)); }
                        },
                        repl: {
                            runR: function(code) { return _host.runR(String(code)); },
                            runPython: function(code) { return _host.runPython(String(code)); }
                        },
                        elrond: {
                            ask: function(prompt) { return _host.askElrond(String(prompt)); }
                        }
                    };
                """, -1);

                // Load plugin script
                context.evaluate_with_source_uri (script, -1, main_js_path, 1);
                context.evaluate ("if (typeof onload === 'function') { onload(); }", -1);

                is_enabled = true;
                return true;
        }

        public void trigger_ribbon_button (string button_id) {
            if (context != null && is_enabled) {
                context.evaluate (@"if (imladris._callbacks && typeof imladris._callbacks['$button_id'] === 'function') { imladris._callbacks['$button_id'](); }", -1);
            }
        }

        public void unload () {
            if (context != null) {
                context.evaluate ("if (typeof onunload === 'function') { onunload(); }", -1);
            }

            foreach (var btn_id in registered_buttons) {
                manager.remove_ribbon_button (manifest.id, btn_id);
            }
            registered_buttons.clear ();

            context = null;
            is_enabled = false;
        }
    }

    public class PluginManager : GLib.Object {
        private static PluginManager? instance = null;

        public signal void ribbon_button_added (string plugin_id, string button_id, string label, string icon);
        public signal void ribbon_button_removed (string plugin_id, string button_id);
        public signal void toast_requested (string message);
        public signal void plugins_changed ();

        public unowned PluginHostWindow? active_window { get; set; default = null; }
        public Gee.HashMap<string, PluginInstance> plugins { get; private set; }
        public string user_plugins_dir { get; private set; }
        public string state_file_path { get; private set; }

        public string test_editor_text { get; set; default = ""; }
        public string test_last_r_code { get; set; default = ""; }
        public string test_last_python_code { get; set; default = ""; }
        public string test_last_elrond_prompt { get; set; default = ""; }

        private PluginManager () {
            plugins = new Gee.HashMap<string, PluginInstance> ();
            user_plugins_dir = Path.build_filename (Environment.get_user_data_dir (), "imladris", "plugins");
            state_file_path = Path.build_filename (Environment.get_user_config_dir (), "imladris", "plugins_state.json");
        }

        public static PluginManager get_default () {
            if (instance == null) {
                instance = new PluginManager ();
            }
            return instance;
        }

        public void initialize () {
            ensure_directories ();
            seed_default_plugins_if_empty ();
            load_all_plugins ();
        }

        private void ensure_directories () {
            try {
                var dir = File.new_for_path (user_plugins_dir);
                if (!dir.query_exists ()) {
                    dir.make_directory_with_parents ();
                }
                var config_dir = File.new_for_path (Path.get_dirname (state_file_path));
                if (!config_dir.query_exists ()) {
                    config_dir.make_directory_with_parents ();
                }
            } catch (GLib.Error e) {
                warning ("Could not create plugins directory: %s", e.message);
            }
        }

        private void seed_default_plugins_if_empty () {
            string word_counter_dir = Path.build_filename (user_plugins_dir, "word-counter");
            if (!FileUtils.test (word_counter_dir, FileTest.IS_DIR)) {
                try {
                    File.new_for_path (word_counter_dir).make_directory_with_parents ();

                    string manifest_json = """{
  "id": "word-counter",
  "name": "Word & Text Counter",
  "version": "1.0.0",
  "author": "Imladris Community",
  "description": "Calculates words, characters, lines and reading time stats in the active document.",
  "license": "GPL-3.0-or-later",
  "icon": "format-text-bold-symbolic",
  "permissions": ["editor"]
}""";
                    FileUtils.set_contents (Path.build_filename (word_counter_dir, "manifest.json"), manifest_json);

                    string main_js = """function onload() {
    imladris.ui.addRibbonButton("calc-stats", "Word Stats", "format-text-bold-symbolic", function() {
        var text = imladris.editor.getText();
        var words = text.trim().length > 0 ? text.trim().split(/\\s+/).length : 0;
        var chars = text.length;
        var lines = text.length > 0 ? text.split("\\n").length : 0;
        var reading_min = Math.max(1, Math.ceil(words / 200));
        imladris.ui.showToast("📊 Stats: " + words + " words | " + chars + " chars | " + lines + " lines (~" + reading_min + " min read)");
    });
}

function onunload() {
}
""";
                    FileUtils.set_contents (Path.build_filename (word_counter_dir, "main.js"), main_js);
                } catch (GLib.Error e) {
                    warning ("Failed to seed word-counter plugin: %s", e.message);
                }
            }

            string timestamp_dir = Path.build_filename (user_plugins_dir, "timestamp-injector");
            if (!FileUtils.test (timestamp_dir, FileTest.IS_DIR)) {
                try {
                    File.new_for_path (timestamp_dir).make_directory_with_parents ();

                    string manifest_json = """{
  "id": "timestamp-injector",
  "name": "Timestamp Injector",
  "version": "1.0.0",
  "author": "Imladris Community",
  "description": "Inserts current ISO timestamp comment at cursor position.",
  "license": "GPL-3.0-or-later",
  "icon": "alarm-symbolic",
  "permissions": ["editor"]
}""";
                    FileUtils.set_contents (Path.build_filename (timestamp_dir, "manifest.json"), manifest_json);

                    string main_js = """function onload() {
    imladris.ui.addRibbonButton("insert-time", "Insert Date", "alarm-symbolic", function() {
        var now = new Date();
        var dateStr = "<!-- Updated: " + now.toISOString() + " -->\\n";
        imladris.editor.insertAtCursor(dateStr);
        imladris.ui.showToast("Inserted timestamp at cursor.");
    });
}

function onunload() {
}
""";
                    FileUtils.set_contents (Path.build_filename (timestamp_dir, "main.js"), main_js);
                } catch (GLib.Error e) {
                    warning ("Failed to seed timestamp-injector plugin: %s", e.message);
                }
            }
        }

        public void load_all_plugins () {
            plugins.clear ();
            var enabled_set = load_enabled_set ();

            try {
                var dir = Dir.open (user_plugins_dir, 0);
                string? name = null;
                while ((name = dir.read_name ()) != null) {
                    string plugin_dir = Path.build_filename (user_plugins_dir, name);
                    if (FileUtils.test (plugin_dir, FileTest.IS_DIR)) {
                        load_plugin_from_directory (plugin_dir, enabled_set);
                    }
                }
            } catch (GLib.Error e) {
                warning ("Error reading user plugins dir: %s", e.message);
            }

            plugins_changed ();
        }

        public PluginInstance? load_plugin_from_directory (string plugin_dir, ArrayList<string>? enabled_set = null) {
            string manifest_path = Path.build_filename (plugin_dir, "manifest.json");
            if (!FileUtils.test (manifest_path, FileTest.EXISTS)) return null;

            string json_content;
            try {
                FileUtils.get_contents (manifest_path, out json_content);
            } catch (GLib.Error e) {
                warning ("Could not read manifest at %s: %s", manifest_path, e.message);
                return null;
            }

            var manifest = PluginManifest.from_json (json_content);
            if (manifest == null) return null;

            var instance = new PluginInstance (manifest, plugin_dir, this);
            plugins.set (manifest.id, instance);

            bool should_enable = false;
            if (enabled_set != null) {
                should_enable = enabled_set.contains (manifest.id);
            } else {
                var current_enabled = load_enabled_set ();
                should_enable = current_enabled.contains (manifest.id);
            }

            if (should_enable) {
                instance.load ();
            }

            return instance;
        }

        private ArrayList<string> load_enabled_set () {
            var list = new ArrayList<string> ();
            if (!FileUtils.test (state_file_path, FileTest.EXISTS)) {
                // By default enable word-counter and timestamp-injector
                list.add ("word-counter");
                list.add ("timestamp-injector");
                save_enabled_set (list);
                return list;
            }

            try {
                string content;
                FileUtils.get_contents (state_file_path, out content);
                var parser = new Json.Parser ();
                parser.load_from_data (content);
                var root = parser.get_root ();
                if (root != null && root.get_node_type () == Json.NodeType.OBJECT) {
                    var obj = root.get_object ();
                    if (obj.has_member ("enabled")) {
                        var arr = obj.get_array_member ("enabled");
                        for (uint i = 0; i < arr.get_length (); i++) {
                            list.add (arr.get_string_element (i));
                        }
                    }
                }
            } catch (GLib.Error e) {
                warning ("Error reading plugin state: %s", e.message);
            }
            return list;
        }

        private void save_enabled_set (ArrayList<string> list) {
            try {
                var builder = new Json.Builder ();
                builder.begin_object ();
                builder.set_member_name ("enabled");
                builder.begin_array ();
                foreach (var id in list) {
                    builder.add_string_value (id);
                }
                builder.end_array ();
                builder.end_object ();

                var generator = new Json.Generator ();
                generator.set_root (builder.get_root ());
                generator.set_pretty (true);
                generator.to_file (state_file_path);
            } catch (GLib.Error e) {
                warning ("Could not save plugin state: %s", e.message);
            }
        }

        public void enable_plugin (string plugin_id) {
            if (!plugins.has_key (plugin_id)) return;
            var instance = plugins.get (plugin_id);
            if (!instance.is_enabled) {
                instance.load ();
                var list = load_enabled_set ();
                if (!list.contains (plugin_id)) {
                    list.add (plugin_id);
                    save_enabled_set (list);
                }
                plugins_changed ();
            }
        }

        public void disable_plugin (string plugin_id) {
            if (!plugins.has_key (plugin_id)) return;
            var instance = plugins.get (plugin_id);
            if (instance.is_enabled) {
                instance.unload ();
                var list = load_enabled_set ();
                if (list.contains (plugin_id)) {
                    list.remove (plugin_id);
                    save_enabled_set (list);
                }
                plugins_changed ();
            }
        }

        public bool delete_plugin (string plugin_id) {
            if (!plugins.has_key (plugin_id)) return false;
            var instance = plugins.get (plugin_id);
            if (instance.is_enabled) {
                instance.unload ();
            }
            plugins.unset (plugin_id);

            var list = load_enabled_set ();
            list.remove (plugin_id);
            save_enabled_set (list);

            try {
                delete_directory_recursive (File.new_for_path (instance.dir_path));
            } catch (GLib.Error e) {
                warning ("Could not delete plugin directory: %s", e.message);
                return false;
            }

            plugins_changed ();
            return true;
        }

        public void trigger_ribbon_button (string plugin_id, string button_id) {
            if (plugins.has_key (plugin_id)) {
                plugins.get (plugin_id).trigger_ribbon_button (button_id);
            }
        }

        public void show_toast (string message) {
            toast_requested (message);
            if (active_window != null) {
                active_window.show_toast (message);
            }
        }

        public void add_ribbon_button (string plugin_id, string button_id, string label, string icon) {
            ribbon_button_added (plugin_id, button_id, label, icon);
        }

        public void remove_ribbon_button (string plugin_id, string button_id) {
            ribbon_button_removed (plugin_id, button_id);
        }

        public string get_active_editor_text () {
            if (active_window != null) {
                return active_window.get_active_editor_text ();
            }
            return test_editor_text;
        }

        public string get_active_selected_text () {
            if (active_window != null) {
                return active_window.get_active_selected_text ();
            }
            return "";
        }

        public void insert_in_active_editor (string text) {
            if (active_window != null) {
                active_window.insert_in_active_editor (text);
            } else {
                test_editor_text += text;
            }
        }

        public void run_r_code (string code) {
            test_last_r_code = code;
            Services.PersistentSessionManager.get_default ().execute_r.begin (code, (obj, res) => {
                string? plot_file = null;
                string output = Services.PersistentSessionManager.get_default ().execute_r.end (res, out plot_file);
                if (active_window != null) {
                    active_window.append_console_log (@"▶ [Plugin R] $code\n$output");
                }
            });
        }

        public void run_python_code (string code) {
            test_last_python_code = code;
            Services.PersistentSessionManager.get_default ().execute_python.begin (code, (obj, res) => {
                string? plot_file = null;
                string output = Services.PersistentSessionManager.get_default ().execute_python.end (res, out plot_file);
                if (active_window != null) {
                    active_window.append_console_log (@"▶ [Plugin Python] $code\n$output");
                }
            });
        }

        public void ask_elrond (string prompt) {
            test_last_elrond_prompt = prompt;
            if (active_window != null) {
                active_window.ask_elrond (prompt);
            }
        }

        public string[] test_workspace_files = {};
        public Gee.HashMap<string, string> test_workspace_file_contents = new Gee.HashMap<string, string> ();
        public string test_last_opened_file = "";
        public string test_last_web_dialog_title = "";
        public string test_last_web_dialog_html = "";

        public string[] list_workspace_files (string pattern) {
            if (active_window != null) {
                return active_window.list_workspace_files (pattern);
            }
            return test_workspace_files;
        }

        public string read_workspace_file (string relative_path) {
            if (active_window != null) {
                return active_window.read_workspace_file (relative_path);
            }
            if (test_workspace_file_contents.has_key (relative_path)) {
                return test_workspace_file_contents.get (relative_path);
            }
            return "";
        }

        public void open_workspace_file (string relative_path, int line) {
            if (active_window != null) {
                active_window.open_workspace_file (relative_path, line);
            }
            test_last_opened_file = relative_path;
        }

        public string get_workspace_root () {
            if (active_window != null) {
                return active_window.get_workspace_root ();
            }
            return "";
        }

        public string get_active_file_path () {
            if (active_window != null) {
                return active_window.get_active_file_path ();
            }
            return "";
        }

        public void show_web_dialog (string title, string html_content, int width, int height) {
            if (active_window != null) {
                active_window.show_web_dialog (title, html_content, width, height);
            }
            test_last_web_dialog_title = title;
            test_last_web_dialog_html = html_content;
        }

        public async bool import_plugin_archive (string archive_path, Gtk.Window parent_window) throws GLib.Error {
            if (!FileUtils.test (archive_path, FileTest.EXISTS)) {
                throw new IOError.NOT_FOUND (@"Archive file not found: $archive_path");
            }

            string tmp_dir = DirUtils.make_tmp ("imladris_plugin_import_XXXXXX");
            try {
                // Extract using python3 -m zipfile
                string[] argv = { "python3", "-m", "zipfile", "-e", archive_path, tmp_dir };
                var subp = new Subprocess.newv (argv, SubprocessFlags.STDOUT_SILENCE | SubprocessFlags.STDERR_SILENCE);
                yield subp.wait_check_async ();

                // Search for manifest.json
                string? found_manifest_path = find_manifest_file (tmp_dir);
                if (found_manifest_path == null) {
                    throw new IOError.INVALID_DATA ("Invalid plugin archive: manifest.json not found in package.");
                }

                string plugin_root_extracted = Path.get_dirname (found_manifest_path);
                string main_js_path = Path.build_filename (plugin_root_extracted, "main.js");
                if (!FileUtils.test (main_js_path, FileTest.EXISTS)) {
                    throw new IOError.INVALID_DATA ("Invalid plugin archive: main.js not found alongside manifest.json.");
                }

                string manifest_json;
                FileUtils.get_contents (found_manifest_path, out manifest_json);
                var manifest = PluginManifest.from_json (manifest_json);
                if (manifest == null || manifest.id == "") {
                    throw new IOError.INVALID_DATA ("Invalid plugin manifest: missing id or corrupted JSON.");
                }

                // Check consent via Adw.AlertDialog
                var alert = new Adw.AlertDialog (
                    @"Install Plugin: $(manifest.name)",
                    @"Author: $(manifest.author)\n" +
                    @"Version: $(manifest.version)\n" +
                    @"License: $(manifest.license)\n\n" +
                    @"Description:\n$(manifest.description)\n\n" +
                    @"Requested Permissions:\n" + format_permissions_list (manifest.permissions)
                );
                alert.add_response ("cancel", "Cancel");
                alert.add_response ("install", "Install & Enable");
                alert.set_response_appearance ("install", Adw.ResponseAppearance.SUGGESTED);
                alert.set_default_response ("install");
                alert.set_close_response ("cancel");

                string response = yield alert.choose (parent_window, null);
                if (response != "install") {
                    delete_directory_recursive (File.new_for_path (tmp_dir));
                    return false;
                }

                // Destination
                string target_dir = Path.build_filename (user_plugins_dir, manifest.id);
                var target_file = File.new_for_path (target_dir);
                if (target_file.query_exists ()) {
                    if (plugins.has_key (manifest.id)) {
                        disable_plugin (manifest.id);
                    }
                    delete_directory_recursive (target_file);
                }

                copy_directory_recursive (File.new_for_path (plugin_root_extracted), target_file);
                delete_directory_recursive (File.new_for_path (tmp_dir));

                // Load and enable
                var inst = load_plugin_from_directory (target_dir);
                if (inst != null) {
                    enable_plugin (manifest.id);
                    show_toast (@"Plugin '$(manifest.name)' installed and activated!");
                }

                return true;
            } catch (GLib.Error e) {
                delete_directory_recursive (File.new_for_path (tmp_dir));
                throw e;
            }
        }

        private static string format_permissions_list (ArrayList<string> permissions) {
            if (permissions.is_empty) return "  • None (Declarative UI only, sandboxed)\n";
            var sb = new StringBuilder ();
            foreach (var p in permissions) {
                switch (p) {
                    case "editor":
                        sb.append ("  • Editor Access (Read and insert buffer text)\n");
                        break;
                    case "repl_r":
                        sb.append ("  • R Console Execution (Run R scripts)\n");
                        break;
                    case "repl_python":
                        sb.append ("  • Python Console Execution (Run Python code)\n");
                        break;
                    case "elrond_ai":
                        sb.append ("  • Elrond AI Access (Send queries to AI engine)\n");
                        break;
                    case "workspace":
                        sb.append ("  • Workspace Access (Read and navigate project files)\n");
                        break;
                    case "export":
                        sb.append ("  • Export Automation (Trigger document exports)\n");
                        break;
                    default:
                        sb.append (@"  • Custom: $p\n");
                        break;
                }
            }
            return sb.str;
        }

        private static string? find_manifest_file (string search_dir) {
            string direct = Path.build_filename (search_dir, "manifest.json");
            if (FileUtils.test (direct, FileTest.EXISTS)) return direct;

            try {
                var dir = Dir.open (search_dir, 0);
                string? name = null;
                while ((name = dir.read_name ()) != null) {
                    string sub = Path.build_filename (search_dir, name);
                    if (FileUtils.test (sub, FileTest.IS_DIR)) {
                        string candidate = Path.build_filename (sub, "manifest.json");
                        if (FileUtils.test (candidate, FileTest.EXISTS)) {
                            return candidate;
                        }
                    }
                }
            } catch (GLib.Error e) {
                // Ignore
            }
            return null;
        }

        public static void copy_directory_recursive (File source, File destination) throws GLib.Error {
            if (!destination.query_exists ()) {
                destination.make_directory_with_parents ();
            }
            var enumerator = source.enumerate_children (
                FileAttribute.STANDARD_NAME + "," + FileAttribute.STANDARD_TYPE,
                FileQueryInfoFlags.NOFOLLOW_SYMLINKS
            );
            FileInfo? info = null;
            while ((info = enumerator.next_file ()) != null) {
                var child_src = source.get_child (info.get_name ());
                var child_dest = destination.get_child (info.get_name ());
                if (info.get_file_type () == FileType.DIRECTORY) {
                    copy_directory_recursive (child_src, child_dest);
                } else {
                    child_src.copy (child_dest, FileCopyFlags.OVERWRITE);
                }
            }
        }

        public static void delete_directory_recursive (File dir) throws GLib.Error {
            if (!dir.query_exists ()) return;
            var enumerator = dir.enumerate_children (
                FileAttribute.STANDARD_NAME + "," + FileAttribute.STANDARD_TYPE,
                FileQueryInfoFlags.NOFOLLOW_SYMLINKS
            );
            FileInfo? info = null;
            while ((info = enumerator.next_file ()) != null) {
                var child = dir.get_child (info.get_name ());
                if (info.get_file_type () == FileType.DIRECTORY) {
                    delete_directory_recursive (child);
                } else {
                    child.delete ();
                }
            }
            dir.delete ();
        }
    }
}
