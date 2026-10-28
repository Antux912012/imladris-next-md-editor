/* test_plugin_engine.vala
 *
 * Unit tests for Imladris JavaScriptCore Plugin Engine
 */

using GLib;
using Imladris.Plugins;
using Gee;

public class PluginEngineTests {

    public static void test_manifest_parsing () {
        string json_valid = """{
  "id": "sample-plugin",
  "name": "Sample Analysis Plugin",
  "version": "1.2.3",
  "author": "Ada Lovelace",
  "description": "Performs statistical analysis on markdown files.",
  "license": "GPL-3.0-or-later",
  "icon": "utilities-terminal-symbolic",
  "permissions": ["editor", "repl_r", "repl_python", "elrond_ai"]
}""";

        var manifest = PluginManifest.from_json (json_valid);
        assert (manifest != null);
        assert (manifest.id == "sample-plugin");
        assert (manifest.name == "Sample Analysis Plugin");
        assert (manifest.version == "1.2.3");
        assert (manifest.author == "Ada Lovelace");
        assert (manifest.description == "Performs statistical analysis on markdown files.");
        assert (manifest.license == "GPL-3.0-or-later");
        assert (manifest.icon == "utilities-terminal-symbolic");
        assert (manifest.has_permission ("editor"));
        assert (manifest.has_permission ("repl_r"));
        assert (manifest.has_permission ("repl_python"));
        assert (manifest.has_permission ("elrond_ai"));
        assert (!manifest.has_permission ("export"));

        string summary = manifest.format_permissions_summary ();
        assert (summary.contains ("Editor Access"));
        assert (summary.contains ("R Console Execution"));
        assert (summary.contains ("Python Console Execution"));
        assert (summary.contains ("Elrond AI Access"));

        // Invalid JSON
        var invalid = PluginManifest.from_json ("{ invalid: json ");
        assert (invalid == null);

        // Missing ID
        var missing_id = PluginManifest.from_json ("{\"name\": \"No ID\"}");
        assert (missing_id == null);
    }

    public static void test_plugin_execution_and_bridge () {
        var pm = PluginManager.get_default ();
        pm.test_editor_text = "Hello World";
        pm.test_last_r_code = "";
        pm.test_last_python_code = "";
        pm.test_last_elrond_prompt = "";
        pm.test_workspace_files = { "chapter1.md", "notes/index.md" };
        pm.test_workspace_file_contents.set ("chapter1.md", "# Chapter 1\nSee [[notes/index]]");
        pm.test_last_opened_file = "";
        pm.test_last_web_dialog_title = "";

        string last_toast = "";
        pm.toast_requested.connect ((msg) => {
            last_toast = msg;
        });

        string last_btn_added = "";
        pm.ribbon_button_added.connect ((pid, bid, label, icon) => {
            last_btn_added = bid;
        });

        string last_btn_removed = "";
        pm.ribbon_button_removed.connect ((pid, bid) => {
            last_btn_removed = bid;
        });

        try {
            string tmp_dir = DirUtils.make_tmp ("imladris_test_plugin_XXXXXX");

            string manifest_json = """{
  "id": "full-test-plugin",
  "name": "Full Test Plugin",
  "version": "1.0.0",
  "author": "Tester",
  "license": "GPL-3.0-or-later",
  "permissions": ["editor", "repl_r", "repl_python", "elrond_ai", "workspace"]
}""";
            FileUtils.set_contents (Path.build_filename (tmp_dir, "manifest.json"), manifest_json);

            string main_js = """
function onload() {
    imladris.ui.showToast("Test Plugin Initialized");
    imladris.ui.addRibbonButton("run-full-test", "Run Test", "system-run-symbolic", function() {
        var current = imladris.editor.getText();
        imladris.ui.showToast("Read text: " + current);
        imladris.editor.insertAtCursor(" — Processed");
        imladris.repl.runR("r_test_command()");
        imladris.repl.runPython("py_test_command()");
        imladris.elrond.ask("How to optimize Julia code?");

        var files = imladris.workspace.listFiles("*.md");
        var ch1 = imladris.workspace.readFile("chapter1.md");
        imladris.workspace.openFile("chapter1.md", 5);
        imladris.ui.openWebDialog({ title: "Custom Graph", html: "<h1>Graph</h1>", width: 800, height: 600 });
    });
}

function onunload() {
    imladris.ui.showToast("Test Plugin Finalized");
}
""";
            FileUtils.set_contents (Path.build_filename (tmp_dir, "main.js"), main_js);

            var manifest = PluginManifest.from_json (manifest_json);
            assert (manifest != null);

            var plugin = new PluginInstance (manifest, tmp_dir, pm);
            bool loaded = plugin.load ();
            assert (loaded);
            assert (plugin.is_enabled);
            assert (last_toast == "Test Plugin Initialized");
            assert (last_btn_added == "run-full-test");

            // Trigger button
            plugin.trigger_ribbon_button ("run-full-test");
            assert (last_toast == "Read text: Hello World");
            assert (pm.test_editor_text == "Hello World — Processed");
            assert (pm.test_last_r_code == "r_test_command()");
            assert (pm.test_last_python_code == "py_test_command()");
            assert (pm.test_last_elrond_prompt == "How to optimize Julia code?");
            assert (pm.test_last_opened_file == "chapter1.md");
            assert (pm.test_last_web_dialog_title == "Custom Graph");

            // Unload
            plugin.unload ();
            assert (!plugin.is_enabled);
            assert (last_toast == "Test Plugin Finalized");
            assert (last_btn_removed == "run-full-test");

            PluginManager.delete_directory_recursive (File.new_for_path (tmp_dir));
        } catch (GLib.Error e) {
            assert_not_reached ();
        }
    }

    public static void test_permission_guardrails () {
        var pm = PluginManager.get_default ();
        pm.test_editor_text = "Restricted Document Text";
        pm.test_last_r_code = "";
        pm.test_last_python_code = "";
        pm.test_last_elrond_prompt = "";
        pm.test_last_opened_file = "";

        string last_toast = "";
        pm.toast_requested.connect ((msg) => {
            last_toast = msg;
        });

        try {
            string tmp_dir = DirUtils.make_tmp ("imladris_guardrail_plugin_XXXXXX");

            string manifest_json = """{
  "id": "restricted-plugin",
  "name": "Restricted Plugin",
  "version": "1.0.0",
  "author": "Untrusted Author",
  "license": "GPL-3.0-or-later",
  "permissions": []
}""";
            FileUtils.set_contents (Path.build_filename (tmp_dir, "manifest.json"), manifest_json);

            string main_js = """
function onload() {
    imladris.ui.addRibbonButton("test-guardrails", "Test Guardrails", "security-high-symbolic", function() {
        var txt = imladris.editor.getText();
        imladris.editor.insertAtCursor("malicious");
        imladris.repl.runR("system('rm -rf /')");
        imladris.repl.runPython("os.system('id')");
        imladris.elrond.ask("malicious prompt");
        imladris.workspace.listFiles("*.md");
        imladris.workspace.readFile("secret.md");
        imladris.workspace.openFile("secret.md");
    });
}

function onunload() {}
""";
            FileUtils.set_contents (Path.build_filename (tmp_dir, "main.js"), main_js);

            var manifest = PluginManifest.from_json (manifest_json);
            assert (manifest != null);

            var plugin = new PluginInstance (manifest, tmp_dir, pm);
            bool loaded = plugin.load ();
            assert (loaded);

            plugin.trigger_ribbon_button ("test-guardrails");

            // Verify that calls without permission were blocked and did NOT alter state
            assert (pm.test_editor_text == "Restricted Document Text");
            assert (pm.test_last_r_code == "");
            assert (pm.test_last_python_code == "");
            assert (pm.test_last_elrond_prompt == "");
            assert (pm.test_last_opened_file == "");
            assert (last_toast.contains ("denied") || last_toast.contains ("permission"));

            plugin.unload ();
            PluginManager.delete_directory_recursive (File.new_for_path (tmp_dir));
        } catch (GLib.Error e) {
            assert_not_reached ();
        }
    }

    public static int main (string[] args) {
        Test.init (ref args);

        Test.add_func ("/plugins/manifest_parsing", test_manifest_parsing);
        Test.add_func ("/plugins/execution_and_bridge", test_plugin_execution_and_bridge);
        Test.add_func ("/plugins/permission_guardrails", test_permission_guardrails);

        return Test.run ();
    }
}
