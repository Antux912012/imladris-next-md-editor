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
        GLib.Test.add_func ("/execution/repl_bridge_and_chunk_engine", test_repl_bridge_and_chunk_engine);
        GLib.Test.add_func ("/core/platform_utils", test_platform_utils);
        GLib.Test.add_func ("/core/toolchain_manager", test_toolchain_manager);
        GLib.Test.add_func ("/core/runtime_resolution_tiers", test_runtime_resolution_tiers);
        GLib.Test.add_func ("/sessions/host_r_session", test_host_r_session);
        GLib.Test.add_func ("/media/image_and_video_processing", test_media_processing);

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

    private static void test_repl_bridge_and_chunk_engine () {
        string tmp_dir = Path.build_filename (Environment.get_tmp_dir (), "imladris_repl_test_" + Random.next_int ().to_string ());
        DirUtils.create_with_parents (tmp_dir, 0755);

        var py_bridge = new Execution.ReplBridge (Execution.LanguageRuntime.PYTHON, tmp_dir);
        var r_bridge = new Execution.ReplBridge (Execution.LanguageRuntime.R, tmp_dir);

        var loop = new MainLoop ();
        bool test_passed = false;

        py_bridge.start.begin ((obj, res) => {
            try {
                py_bridge.start.end (res);

                var engine = new Execution.ChunkExecutionEngine (tmp_dir, r_bridge, py_bridge);
                string test_code = "a = 21\nb = 2\nprint('Computed Result:', a * b)";

                engine.execute_chunk.begin (Execution.LanguageRuntime.PYTHON, test_code, "test1", (obj2, res2) => {
                    try {
                        var chunk_res = engine.execute_chunk.end (res2);
                        assert (chunk_res.stdout.contains ("Computed Result: 42"));

                        if (Gtk.init_check ()) {
                            var widget = new Execution.InlineChunkOutputWidget (10);
                            widget.update_output (chunk_res);
                        }

                        py_bridge.stop ();
                        test_passed = true;
                    } catch (GLib.Error e) {
                        GLib.warning ("Chunk execution test failed: %s", e.message);
                    }
                    loop.quit ();
                });

            } catch (GLib.Error e) {
                GLib.warning ("ReplBridge start failed: %s", e.message);
                loop.quit ();
            }
        });

        // Safety timeout
        Timeout.add_seconds (15, () => {
            if (!test_passed) {
                py_bridge.stop ();
                loop.quit ();
            }
            return Source.REMOVE;
        });

        loop.run ();
        assert (test_passed);
    }

    private static void test_platform_utils () {
        // 1. Shared cache directory creation
        string cache_plots = Core.PlatformUtils.get_shared_cache_dir ("plots");
        assert (cache_plots.length > 0);
        assert (FileUtils.test (cache_plots, FileTest.IS_DIR));

        string cache_tmp = Core.PlatformUtils.get_shared_cache_dir ("tmp");
        assert (cache_tmp.length > 0);
        assert (FileUtils.test (cache_tmp, FileTest.IS_DIR));

        // 2. Host command wrapping
        string[] cmd = { "R", "--interactive" };
        string[] wrapped = Core.PlatformUtils.build_host_command (cmd, "/test/path");
        if (Core.PlatformUtils.is_flatpak ()) {
            assert (wrapped[0] == "flatpak-spawn");
            assert (wrapped[1] == "--host");
            assert (wrapped[2] == "--watch-bus");
            assert (wrapped[3] == "--directory=/test/path");
            assert (wrapped[4] == "R");
            assert (wrapped[5] == "--interactive");
        } else {
            assert (wrapped.length == 2);
            assert (wrapped[0] == "R");
            assert (wrapped[1] == "--interactive");
        }

        // 3. Program availability check
        assert (Core.PlatformUtils.is_program_available ("sh"));
        assert (!Core.PlatformUtils.is_program_available ("__non_existent_binary_xyz_123__"));
    }

    private static void test_toolchain_manager () {
        var tm = Core.ToolchainManager.get_default ();
        assert (tm != null);
        assert (tm.base_dir.length > 0);
        assert (tm.bin_dir.length > 0);
        assert (tm.mamba_bin.length > 0);
        assert (tm.mamba_root.length > 0);
        assert (tm.default_env.length > 0);

        string arch = Core.ToolchainManager.get_platform_arch ();
        assert (arch == "linux-64" || arch == "linux-aarch64");

        // Test Rprofile.site configuration writing
        string dummy_env = Path.build_filename (Environment.get_tmp_dir (), @"test_env_$(GLib.Random.next_int ())");
        tm.configure_rprofile_site (dummy_env);

        string rprofile_path = Path.build_filename (dummy_env, "lib", "R", "etc", "Rprofile.site");
        assert (FileUtils.test (rprofile_path, FileTest.EXISTS));

        string content;
        try {
            FileUtils.get_contents (rprofile_path, out content);
            assert (content.contains ("Managed by Imladris Toolchain Manager"));
            assert (content.contains ("https://cloud.r-project.org"));
            assert (content.contains ("Ncpus"));
        } catch (GLib.Error e) {
            assert_not_reached ();
        }
    }

    private static void test_runtime_resolution_tiers () {
        string dummy_proj = Path.build_filename (Environment.get_tmp_dir (), @"test_proj_$(GLib.Random.next_int ())");
        string env_bin_dir = Path.build_filename (dummy_proj, ".imladris-env", "bin");
        DirUtils.create_with_parents (env_bin_dir, 0755);

        string dummy_exe = Path.build_filename (env_bin_dir, "custom_r_engine");
        try {
            FileUtils.set_contents (dummy_exe, "#!/bin/sh\necho custom\n");
            FileUtils.chmod (dummy_exe, 0755);
        } catch (GLib.Error e) {
            assert_not_reached ();
        }

        // Test Tier 1: Project sandbox resolution
        string? resolved_path = null;
        string? env_prefix = null;
        var source = Core.PlatformUtils.resolve_runtime ("custom_r_engine", dummy_proj, out resolved_path, out env_prefix);
        assert (source == Core.RuntimeSource.PROJECT_SANDBOX);
        assert (resolved_path == dummy_exe);
        assert (env_prefix == Path.build_filename (dummy_proj, ".imladris-env"));

        // Test Tier 4: Missing binary resolution
        string? missing_path = null;
        string? missing_env = null;
        var missing_source = Core.PlatformUtils.resolve_runtime ("__missing_binary_404__", dummy_proj, out missing_path, out missing_env);
        assert (missing_source == Core.RuntimeSource.MISSING);
        assert (missing_path == null);
        assert (missing_env == null);

        // Test environment configuration injection
        var launcher = new GLib.SubprocessLauncher (GLib.SubprocessFlags.NONE);
        Core.PlatformUtils.configure_managed_env (launcher, env_prefix);
    }

    private static void test_host_r_session () {
        if (!Core.PlatformUtils.is_r_available ()) {
            GLib.Test.message ("R is not available in test runner; skipping host R session test.");
            return;
        }

        var sm = Services.PersistentSessionManager.get_default ();
        var loop = new MainLoop ();
        bool test_passed = false;

        string? plot_file = null;
        sm.execute_r.begin ("host_val <- 21 * 2; cat('R_RESULT:', host_val, '\\n');", (obj, res) => {
            string output = sm.execute_r.end (res, out plot_file);
            assert (output.contains ("R_RESULT: 42"));

            // Check persistence across calls
            sm.execute_r.begin ("cat('PERSIST_TEST:', host_val + 8, '\\n');", (obj2, res2) => {
                string? p2 = null;
                string output2 = sm.execute_r.end (res2, out p2);
                assert (output2.contains ("PERSIST_TEST: 50"));
                test_passed = true;
                loop.quit ();
            });
        });

        Timeout.add_seconds (15, () => {
            if (!test_passed) {
                loop.quit ();
            }
            return Source.REMOVE;
        });

        loop.run ();
        assert (test_passed);
    }

    private static void test_media_processing () {
        string tmp_dir = Path.build_filename (Environment.get_tmp_dir (), @"test_media_$(GLib.Random.next_int ())");
        string proj_dir = Path.build_filename (tmp_dir, "my_sandboxed_project");
        string ext_dir = Path.build_filename (tmp_dir, "external_downloads");
        string ext_img = Path.build_filename (ext_dir, "statistical_plot.png");
        string ext_vid = Path.build_filename (ext_dir, "simulation_run.mp4");
        string doc_qmd = Path.build_filename (proj_dir, "report.qmd");
        string doc_md = Path.build_filename (proj_dir, "notes.md");
        string expected_img_dest = Path.build_filename (proj_dir, "img", "statistical_plot.png");
        string expected_vid_dest = Path.build_filename (proj_dir, "img", "simulation_run.mp4");
        string ext_dir2 = Path.build_filename (tmp_dir, "external_downloads_2");
        string ext_img2 = Path.build_filename (ext_dir2, "statistical_plot.png");
        string expected_collision_dest = Path.build_filename (proj_dir, "img", "statistical_plot_1.png");

        try {
            DirUtils.create_with_parents (proj_dir, 0755);
            DirUtils.create_with_parents (ext_dir, 0755);
            DirUtils.create_with_parents (ext_dir2, 0755);

            FileUtils.set_contents (ext_img, "DUMMY_PNG_DATA");
            FileUtils.set_contents (ext_vid, "DUMMY_MP4_DATA");
            FileUtils.set_contents (doc_qmd, "# Report\n");
            FileUtils.set_contents (doc_md, "# Notes\n");

            // 1. External image into sandboxed project -> copied to /img and linked
            string img_snippet = Services.MediaHelper.process_and_link_media (
                ext_img,
                proj_dir,
                true, // is_sandboxed
                doc_qmd,
                false // is_video
            );

            assert (FileUtils.test (expected_img_dest, FileTest.EXISTS));
            assert (img_snippet == "![Statistical plot](img/statistical_plot.png)\n");

            // 2. External video into sandboxed project (.qmd Quarto shortcode)
            string vid_qmd_snippet = Services.MediaHelper.process_and_link_media (
                ext_vid,
                proj_dir,
                true,
                doc_qmd,
                true // is_video
            );

            assert (FileUtils.test (expected_vid_dest, FileTest.EXISTS));
            assert (vid_qmd_snippet == "{{< video img/simulation_run.mp4 >}}\n");

            // 3. External video into Markdown (.md HTML5 video tag)
            string vid_md_snippet = Services.MediaHelper.process_and_link_media (
                ext_vid,
                proj_dir,
                true,
                doc_md,
                true
            );
            assert (vid_md_snippet == "<video src=\"img/simulation_run.mp4\" controls width=\"100%\"></video>\n");

            // 4. File collision resolution when copying different external file with same name
            FileUtils.set_contents (ext_img2, "DIFFERENT_CONTENT_FOR_COLLISION_TESTING");

            string collision_snippet = Services.MediaHelper.process_and_link_media (
                ext_img2,
                proj_dir,
                true,
                doc_qmd,
                false
            );
            assert (FileUtils.test (expected_collision_dest, FileTest.EXISTS));
            assert (collision_snippet == "![Statistical plot 1](img/statistical_plot_1.png)\n");

            // 5. Custom caption override
            string custom_caption_snippet = Services.MediaHelper.process_and_link_media (
                expected_img_dest,
                proj_dir,
                true,
                doc_qmd,
                false,
                "Figure 1: Gene Expression Correlation"
            );
            assert (custom_caption_snippet == "![Figure 1: Gene Expression Correlation](img/statistical_plot.png)\n");
        } catch (Error e) {
            assert_not_reached ();
        }

        // Clean up
        FileUtils.remove (expected_collision_dest);
        FileUtils.remove (expected_img_dest);
        FileUtils.remove (expected_vid_dest);
        FileUtils.remove (doc_qmd);
        FileUtils.remove (doc_md);
        FileUtils.remove (ext_img);
        FileUtils.remove (ext_img2);
        FileUtils.remove (ext_vid);
        DirUtils.remove (Path.build_filename (proj_dir, "img"));
        DirUtils.remove (proj_dir);
        DirUtils.remove (ext_dir);
        DirUtils.remove (ext_dir2);
        DirUtils.remove (tmp_dir);
    }
}
