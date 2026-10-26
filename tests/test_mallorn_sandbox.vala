namespace Imladris.Tests {

    public static int main (string[] args) {
        GLib.Test.init (ref args);

        GLib.Test.add_func ("/data_models/document_format", test_document_format);
        GLib.Test.add_func ("/data_models/project_type", test_project_type);
        GLib.Test.add_func ("/mallorn/manifest_generation_and_parsing", test_manifest_roundtrip);
        GL_Test_scaffolding_and_archive ();
        GLib.Test.add_func ("/sandbox/r_and_py_sandboxes", test_sandbox_controllers);
        GLib.Test.add_func ("/sandbox/export_rstudio_jupyter", test_sandbox_exports);
        GLib.Test.add_func ("/sandbox/restore_environment", test_sandbox_restore);
        GLib.Test.add_func ("/sessions/persistent_session_and_pwd_sync", test_persistent_session_and_pwd_sync);
        GLib.Test.add_func ("/export/odt_and_odp_pipeline", test_export_pipeline_odt_odp);
        GLib.Test.add_func ("/chunks/chunk_parser", test_chunk_parser);

        return GLib.Test.run ();
    }

    private static void GL_Test_scaffolding_and_archive () {
        GLib.Test.add_func ("/mallorn/scaffold_and_pack_unpack", test_scaffold_pack_unpack);
    }

    private static void test_document_format () {
        assert (DocumentFormat.MD.get_extension () == ".md");
        assert (DocumentFormat.HTML.get_extension () == ".html");
        assert (DocumentFormat.RSCRIPT.get_extension () == ".R");
        assert (DocumentFormat.RMD.get_extension () == ".Rmd");
        assert (DocumentFormat.QMD.get_extension () == ".qmd");
        assert (DocumentFormat.IPYNB.get_extension () == ".ipynb");
        assert (DocumentFormat.PYSCRIPT.get_extension () == ".py");

        assert (DocumentFormat.from_filename ("report.qmd") == DocumentFormat.QMD);
        assert (DocumentFormat.from_filename ("analysis.Rmd") == DocumentFormat.RMD);
        assert (DocumentFormat.from_filename ("notebook.ipynb") == DocumentFormat.IPYNB);
        assert (DocumentFormat.from_filename ("script.R") == DocumentFormat.RSCRIPT);
        assert (DocumentFormat.from_filename ("app.py") == DocumentFormat.PYSCRIPT);
        assert (DocumentFormat.from_filename ("index.html") == DocumentFormat.HTML);
        assert (DocumentFormat.from_filename ("README.md") == DocumentFormat.MD);

        assert (DocumentFormat.QMD.is_computational_notebook ());
        assert (DocumentFormat.RMD.is_computational_notebook ());
        assert (DocumentFormat.IPYNB.is_computational_notebook ());
        assert (!DocumentFormat.MD.is_computational_notebook ());
    }

    private static void test_project_type () {
        assert (ProjectType.STANDARD.to_string () == "Standard");
        assert (ProjectType.SANDBOXED.to_string () == "Sandboxed");
        assert (ProjectType.from_string ("sandboxed") == ProjectType.SANDBOXED);
        assert (ProjectType.from_string ("Standard") == ProjectType.STANDARD);

        assert (ProjectType.SANDBOXED.get_badge_label () == "[Sandboxed - Reproducible]");
        assert (ProjectType.STANDARD.get_badge_label () == "[System Libraries - Non-Portable]");
    }

    private static void test_manifest_roundtrip () {
        var cfg = new ProjectConfig () {
            project_name = "QuantumAnalysis",
            author = "Ada Lovelace",
            project_type = ProjectType.SANDBOXED,
            format = DocumentFormat.QMD,
            imladris_version = "1.0"
        };

        string dcf = MallornManager.generate_rproj_manifest (cfg);
        assert (dcf.contains ("Version: 1.0"));
        assert (dcf.contains ("RestoreWorkspace: Default"));
        assert (dcf.contains ("ImladrisProjectType: Sandboxed"));
        assert (dcf.contains ("ImladrisPrimaryFormat: Qmd"));
        assert (dcf.contains ("ImladrisProjectName: QuantumAnalysis"));
        assert (dcf.contains ("ImladrisAuthor: Ada Lovelace"));
        assert (dcf.contains ("ImladrisSandboxed: true"));

        var parsed = MallornManager.parse_manifest (dcf);
        assert (parsed.project_name == "QuantumAnalysis");
        assert (parsed.author == "Ada Lovelace");
        assert (parsed.project_type == ProjectType.SANDBOXED);
        assert (parsed.format == DocumentFormat.QMD);
        assert (parsed.sandboxed == true);
    }

    private static void test_scaffold_pack_unpack () {
        string tmp_dir = Path.build_filename (Environment.get_tmp_dir (), @"test_imladris_$(GLib.Random.next_int ())");
        string proj_dir = Path.build_filename (tmp_dir, "My_Test_Project");

        var cfg = new ProjectConfig () {
            project_name = "My_Test_Project",
            author = "Test Suite",
            project_type = ProjectType.STANDARD,
            format = DocumentFormat.QMD,
            custom_project_dir = proj_dir
        };

        try {
            File main_doc = ProjectScaffolder.create_project (cfg);
            assert (main_doc.query_exists ());
            assert (FileUtils.test (Path.build_filename (proj_dir, "My_Test_Project.qmd"), FileTest.EXISTS));
            assert (FileUtils.test (Path.build_filename (proj_dir, "My_Test_Project.mallorn"), FileTest.EXISTS));
            assert (FileUtils.test (Path.build_filename (proj_dir, "My_Test_Project.Rproj"), FileTest.EXISTS));
            assert (FileUtils.test (Path.build_filename (proj_dir, ".mallorn.json"), FileTest.EXISTS));
            assert (FileUtils.test (Path.build_filename (proj_dir, "imladris.toml"), FileTest.EXISTS));
            assert (FileUtils.test (Path.build_filename (proj_dir, "bibliography", "references.bib"), FileTest.EXISTS));

            // Pack archive
            string archive_path = Path.build_filename (tmp_dir, "bundle.mallorn");
            MallornManager.pack_mallorn_archive (proj_dir, archive_path);
            assert (FileUtils.test (archive_path, FileTest.EXISTS));

            // Unpack archive to target_unpacked
            string unpack_dir = Path.build_filename (tmp_dir, "unpacked_proj");
            var unpacked_cfg = MallornManager.unpack_mallorn_archive (archive_path, unpack_dir);

            assert (FileUtils.test (Path.build_filename (unpack_dir, "My_Test_Project.mallorn"), FileTest.EXISTS));
            assert (FileUtils.test (Path.build_filename (unpack_dir, "My_Test_Project.Rproj"), FileTest.EXISTS));
            assert (FileUtils.test (Path.build_filename (unpack_dir, "My_Test_Project.qmd"), FileTest.EXISTS));
            assert (unpacked_cfg.project_name == "My_Test_Project");
            assert (unpacked_cfg.format == DocumentFormat.QMD);

        } catch (GLib.Error e) {
            GLib.error ("Scaffold & pack failed: %s", e.message);
        }
    }

    private static void test_sandbox_controllers () {
        string tmp_dir = Path.build_filename (Environment.get_tmp_dir (), @"test_sandbox_$(GLib.Random.next_int ())");
        try {
            // Test R Sandbox initialization
            Services.SandboxController.init_r_sandbox (tmp_dir);
            assert (FileUtils.test (Path.build_filename (tmp_dir, ".Rprofile"), FileTest.EXISTS));
            assert (FileUtils.test (Path.build_filename (tmp_dir, "renv", "activate.R"), FileTest.EXISTS));
            assert (FileUtils.test (Path.build_filename (tmp_dir, "renv.lock"), FileTest.EXISTS));
            assert (Services.SandboxController.is_r_sandbox_active (tmp_dir));

            // Test Py Sandbox initialization
            Services.SandboxController.init_py_sandbox (tmp_dir);
            assert (FileUtils.test (Path.build_filename (tmp_dir, "requirements.txt"), FileTest.EXISTS));
            assert (FileUtils.test (Path.build_filename (tmp_dir, ".venv", "share", "jupyter", "kernels", "imladris-sandbox", "kernel.json"), FileTest.EXISTS));
            assert (Services.SandboxController.detect_project_type (tmp_dir) == ProjectType.SANDBOXED);

        } catch (GLib.Error e) {
            GLib.error ("Sandbox test failed: %s", e.message);
        }
    }

    private static void test_sandbox_exports () {
        string tmp_dir = Path.build_filename (Environment.get_tmp_dir (), @"test_export_$(GLib.Random.next_int ())");
        string src_dir = Path.build_filename (tmp_dir, "source");
        string rstudio_export_dir = Path.build_filename (tmp_dir, "export_rstudio");
        string jupyter_export_dir = Path.build_filename (tmp_dir, "export_jupyter");

        try {
            var cfg = new ProjectConfig () {
                project_name = "ExportBio",
                author = "Darwin",
                project_type = ProjectType.SANDBOXED,
                format = DocumentFormat.RMD,
                custom_project_dir = src_dir
            };
            ProjectScaffolder.create_project (cfg);

            // Export for RStudio
            Services.SandboxController.export_for_rstudio (src_dir, rstudio_export_dir);
            assert (FileUtils.test (Path.build_filename (rstudio_export_dir, "ExportBio.Rproj"), FileTest.EXISTS));
            assert (FileUtils.test (Path.build_filename (rstudio_export_dir, ".Rprofile"), FileTest.EXISTS));
            assert (FileUtils.test (Path.build_filename (rstudio_export_dir, "renv", "activate.R"), FileTest.EXISTS));
            assert (FileUtils.test (Path.build_filename (rstudio_export_dir, "renv.lock"), FileTest.EXISTS));

            // Export for Jupyter
            Services.SandboxController.export_for_jupyter (src_dir, jupyter_export_dir);
            assert (FileUtils.test (Path.build_filename (jupyter_export_dir, "requirements.txt"), FileTest.EXISTS));
            assert (FileUtils.test (Path.build_filename (jupyter_export_dir, "environment.yml"), FileTest.EXISTS));
            assert (FileUtils.test (Path.build_filename (jupyter_export_dir, "setup_environment.sh"), FileTest.EXISTS));

        } catch (GLib.Error e) {
            GLib.error ("Export test failed: %s", e.message);
        }
    }

    private static void test_export_pipeline_odt_odp () {
        string tmp_dir = Path.build_filename (Environment.get_tmp_dir (), @"test_export_pipeline_$(GLib.Random.next_int ())");
        DirUtils.create_with_parents (tmp_dir, 0755);

        string sample_md = Path.build_filename (tmp_dir, "document.md");
        string out_odt = Path.build_filename (tmp_dir, "output.odt");
        string out_odp = Path.build_filename (tmp_dir, "output.odp");

        try {
            FileUtils.set_contents (sample_md, "# Sample Title\n\nThis is paragraph one.\n\n## Slide 2\n- Bullet point A\n- Bullet point B\n");

            Services.ExportService.export_to_odt (sample_md, out_odt);
            assert (FileUtils.test (out_odt, FileTest.EXISTS));

            Services.ExportService.export_to_odp (sample_md, out_odp);
            assert (FileUtils.test (out_odp, FileTest.EXISTS));

            // Verify both are valid non-empty files (at least > 200 bytes)
            File f_odt = File.new_for_path (out_odt);
            var info_odt = f_odt.query_info ("standard::size", FileQueryInfoFlags.NONE);
            assert (info_odt.get_size () > 200);

            File f_odp = File.new_for_path (out_odp);
            var info_odp = f_odp.query_info ("standard::size", FileQueryInfoFlags.NONE);
            assert (info_odp.get_size () > 200);
        } catch (GLib.Error e) {
            GLib.error ("ODT/ODP Export test failed: %s", e.message);
        }
    }

    private static void test_sandbox_restore () {
        string tmp_dir = Path.build_filename (Environment.get_tmp_dir (), "imladris_test_restore_" + Random.next_int ().to_string ());
        DirUtils.create_with_parents (tmp_dir, 0755);

        try {
            Services.SandboxController.init_r_sandbox (tmp_dir);
            Services.SandboxController.init_py_sandbox (tmp_dir);

            // Execute restore_environment and ensure it executes without crashing
            Services.SandboxController.restore_environment (tmp_dir);

            // Verify .Rprofile and requirements.txt still intact
            assert (FileUtils.test (Path.build_filename (tmp_dir, ".Rprofile"), FileTest.EXISTS));
            assert (FileUtils.test (Path.build_filename (tmp_dir, "requirements.txt"), FileTest.EXISTS));
        } catch (GLib.Error e) {
            GLib.error ("Sandbox restore test failed: %s", e.message);
        }
    }

    private static void test_persistent_session_and_pwd_sync () {
        var sm = Services.PersistentSessionManager.get_default ();
        assert (sm != null);

        string target_dir = Environment.get_tmp_dir ();
        bool signal_received = false;
        string received_dir = "";

        ulong handler_id = sm.working_directory_changed.connect ((new_dir) => {
            signal_received = true;
            received_dir = new_dir;
        });

        sm.set_working_directory (target_dir, ProjectType.SANDBOXED);

        assert (signal_received);
        assert (received_dir == target_dir);
        assert (sm.current_working_dir == target_dir);
        assert (sm.active_project_type == ProjectType.SANDBOXED);

        sm.disconnect (handler_id);
    }

    private static void test_chunk_parser () {
        string doc = """# Sample Document

Here is an intro paragraph.

```{r}
#| label: setup
x <- 1:10
plot(x)
```

And some text in between.

```python
import numpy as np
print(np.mean([1, 2, 3]))
```
""";
        var chunks = Core.ChunkParser.parse_chunks (doc);
        assert (chunks.size == 2);
        assert (chunks[0].language == "r");
        assert (chunks[0].code.contains ("x <- 1:10"));
        assert (chunks[0].start_line == 4);
        assert (chunks[0].end_line == 8);

        assert (chunks[1].language == "python");
        assert (chunks[1].code.contains ("import numpy as np"));
        assert (chunks[1].start_line == 12);
        assert (chunks[1].end_line == 15);

        var ch_at_line_6 = Core.ChunkParser.find_chunk_at_line (doc, 6);
        assert (ch_at_line_6 != null);
        assert (ch_at_line_6.language == "r");

        var ch_at_line_13 = Core.ChunkParser.find_chunk_at_line (doc, 13);
        assert (ch_at_line_13 != null);
        assert (ch_at_line_13.language == "python");

        var ch_outside = Core.ChunkParser.find_chunk_at_line (doc, 2);
        assert (ch_outside == null);
    }
}
