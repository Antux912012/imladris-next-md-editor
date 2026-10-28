namespace Imladris.Services {

    public class ExportService : GLib.Object {

        /**
         * Pillar 9: OpenDocument Text (.odt) Export Pipeline via Quarto, RMarkdown, Pandoc.
         */
        public static async void export_to_odt_async (
            string project_root,
            string input_file,
            string output_odt,
            DocumentFormat fmt
        ) throws GLib.Error {
            bool ok = false;
            switch (fmt) {
                case DocumentFormat.QMD:
                case DocumentFormat.IPYNB:
                    ok = yield run_tool_process_async ("quarto", { "render", input_file, "--to", "odt", "--output", output_odt }, project_root);
                    break;
                case DocumentFormat.RMD:
                    string r_expr = "rmarkdown::render('%s', output_format = 'odt_document', output_file = '%s')".printf (
                        input_file, output_odt
                    );
                    ok = yield run_tool_process_async ("Rscript", { "-e", r_expr }, project_root);
                    break;
                default:
                    ok = yield run_tool_process_async ("pandoc", { input_file, "-f", "markdown", "-t", "odt", "-o", output_odt, "--standalone" }, project_root);
                    break;
            }

            if (!ok) {
                export_to_odt (input_file, output_odt);
            }
        }

        /**
         * Pillar 9: OpenDocument Presentation (.odp) Export Pipeline via Quarto/Pandoc -> PPTX -> LibreOffice.
         */
        public static async void export_to_odp_async (
            string project_root,
            string input_file,
            string output_odp_dir,
            DocumentFormat fmt
        ) throws GLib.Error {
            var launcher = new SubprocessLauncher (SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_MERGE);
            launcher.set_cwd (project_root);

            string base_name = Path.get_basename (input_file);
            string temp_pptx = Path.build_filename (Core.PlatformUtils.get_shared_cache_dir ("tmp"), "%s_slides.pptx".printf (base_name));

            // Stage 1: Render intermediate slide deck to PPTX
            string[] raw_stage1_argv;
            if (fmt == DocumentFormat.QMD || fmt == DocumentFormat.IPYNB) {
                raw_stage1_argv = { "quarto", "render", input_file, "--to", "pptx", "--output", temp_pptx };
            } else if (fmt == DocumentFormat.RMD) {
                string r_expr = "rmarkdown::render('%s', output_format = 'powerpoint_presentation', output_file = '%s')".printf (
                    input_file, temp_pptx
                );
                raw_stage1_argv = { "Rscript", "-e", r_expr };
            } else {
                raw_stage1_argv = { "pandoc", input_file, "-t", "pptx", "-o", temp_pptx, "--standalone" };
            }

            try {
                string[] stage1_argv = Core.PlatformUtils.build_host_command (raw_stage1_argv, project_root);
                var stage1_proc = launcher.spawnv (stage1_argv);
                yield stage1_proc.wait_check_async ();

                // Stage 2: Convert PPTX -> ODP using headless LibreOffice
                string? soffice_bin = Core.PlatformUtils.find_program ("soffice")
                    ?? Core.PlatformUtils.find_program ("libreoffice");

                if (soffice_bin != null) {
                    string[] raw_stage2_argv = {
                        soffice_bin,
                        "--headless",
                        "--convert-to",
                        "odp",
                        temp_pptx,
                        "--outdir",
                        output_odp_dir
                    };
                    string[] stage2_argv = Core.PlatformUtils.build_host_command (raw_stage2_argv, project_root);
                    var stage2_proc = launcher.spawnv (stage2_argv);
                    yield stage2_proc.wait_check_async ();
                    FileUtils.remove (temp_pptx);
                } else {
                    export_to_odp (input_file, Path.build_filename (output_odp_dir, base_name + ".odp"));
                }
            } catch (GLib.Error e) {
                export_to_odp (input_file, Path.build_filename (output_odp_dir, base_name + ".odp"));
            }
        }

        private static bool run_tool_process (string tool_name, string[] sub_args, string working_dir) {
            string? resolved_path = null;
            string? env_prefix = null;
            var source = Core.PlatformUtils.resolve_runtime (tool_name, working_dir, out resolved_path, out env_prefix);
            if (source == Core.RuntimeSource.MISSING) {
                return false;
            }

            try {
                var launcher = new GLib.SubprocessLauncher (GLib.SubprocessFlags.STDOUT_PIPE | GLib.SubprocessFlags.STDERR_MERGE);
                launcher.set_cwd (working_dir);

                string[] full_raw = new string[1 + sub_args.length];
                full_raw[0] = (resolved_path != null) ? resolved_path : tool_name;
                for (int i = 0; i < sub_args.length; i++) full_raw[i + 1] = sub_args[i];

                string[] argv;
                if (source == Core.RuntimeSource.HOST_FLATPAK_SPAWN) {
                    string[] host_raw = new string[1 + sub_args.length];
                    host_raw[0] = tool_name;
                    for (int i = 0; i < sub_args.length; i++) host_raw[i + 1] = sub_args[i];
                    argv = Core.PlatformUtils.build_host_command (host_raw, working_dir);
                } else if (source == Core.RuntimeSource.MANAGED_GLOBAL || source == Core.RuntimeSource.PROJECT_SANDBOX) {
                    Core.PlatformUtils.configure_managed_env (launcher, env_prefix);
                    argv = full_raw;
                } else {
                    argv = full_raw;
                }

                var proc = launcher.spawnv (argv);
                return proc.wait_check ();
            } catch (GLib.Error e) {
                return false;
            }
        }

        private static async bool run_tool_process_async (string tool_name, string[] sub_args, string working_dir) {
            string? resolved_path = null;
            string? env_prefix = null;
            var source = Core.PlatformUtils.resolve_runtime (tool_name, working_dir, out resolved_path, out env_prefix);
            if (source == Core.RuntimeSource.MISSING) {
                return false;
            }

            try {
                var launcher = new GLib.SubprocessLauncher (GLib.SubprocessFlags.STDOUT_PIPE | GLib.SubprocessFlags.STDERR_MERGE);
                launcher.set_cwd (working_dir);

                string[] full_raw = new string[1 + sub_args.length];
                full_raw[0] = (resolved_path != null) ? resolved_path : tool_name;
                for (int i = 0; i < sub_args.length; i++) full_raw[i + 1] = sub_args[i];

                string[] argv;
                if (source == Core.RuntimeSource.HOST_FLATPAK_SPAWN) {
                    string[] host_raw = new string[1 + sub_args.length];
                    host_raw[0] = tool_name;
                    for (int i = 0; i < sub_args.length; i++) host_raw[i + 1] = sub_args[i];
                    argv = Core.PlatformUtils.build_host_command (host_raw, working_dir);
                } else if (source == Core.RuntimeSource.MANAGED_GLOBAL || source == Core.RuntimeSource.PROJECT_SANDBOX) {
                    Core.PlatformUtils.configure_managed_env (launcher, env_prefix);
                    argv = full_raw;
                } else {
                    argv = full_raw;
                }

                var proc = launcher.spawnv (argv);
                yield proc.wait_check_async ();
                return true;
            } catch (GLib.Error e) {
                return false;
            }
        }

        /**
         * Exports a source document (.md, .Rmd, .Qmd, .ipynb) to OpenDocument Text (.odt).
         * Automatically selects quarto, Rscript (rmarkdown), or pandoc based on extension,
         * falling back to the built-in OASIS OpenDocument Text ZIP packager if CLI tools
         * are unavailable on the host.
         */
        public static void export_to_odt (string input_path, string output_path, string? raw_buffer_fallback = null) throws GLib.Error {
            var fmt = DocumentFormat.from_filename (input_path);
            bool cli_succeeded = false;

            string out_dir = GLib.Path.get_dirname (output_path);
            string out_file = GLib.Path.get_basename (output_path);
            ensure_parent_dir (output_path);

            if ((fmt == DocumentFormat.QMD || fmt == DocumentFormat.IPYNB) &&
                Core.PlatformUtils.is_program_available ("quarto", out_dir)) {
                cli_succeeded = run_tool_process ("quarto", { "render", input_path, "--to", "odt", "--output", out_file }, out_dir);
            } else if (fmt == DocumentFormat.RMD &&
                       Core.PlatformUtils.is_program_available ("Rscript", out_dir)) {
                string r_expr = "if (requireNamespace('rmarkdown', quietly=TRUE)) rmarkdown::render('%s', output_format = 'odt_document', output_file = '%s', quiet = TRUE) else stop('no rmarkdown')".printf (
                    input_path.replace ("'", "\\'"),
                    output_path.replace ("'", "\\'")
                );
                cli_succeeded = run_tool_process ("Rscript", { "-e", r_expr }, out_dir);
            }

            if (!cli_succeeded && Core.PlatformUtils.is_program_available ("pandoc", out_dir)) {
                cli_succeeded = run_tool_process ("pandoc", { input_path, "-f", "markdown", "-t", "odt", "-o", output_path, "--standalone" }, out_dir);
            }

            if (!cli_succeeded || !GLib.FileUtils.test (output_path, GLib.FileTest.EXISTS)) {
                string source_text = read_source_or_fallback (input_path, raw_buffer_fallback);
                build_oasis_odt_container (source_text, output_path);
            }
        }

        /**
         * Exports a source document (.md, .Rmd, .Qmd, .ipynb) to OpenDocument Presentation (.odp).
         * Primary bridge: Quarto/Pandoc -> intermediate .pptx -> LibreOffice headless (--convert-to odp).
         * Fallback: Native OASIS application/vnd.oasis.opendocument.presentation ZIP container builder.
         */
        public static void export_to_odp (string input_path, string output_path, string? raw_buffer_fallback = null) throws GLib.Error {
            var fmt = DocumentFormat.from_filename (input_path);
            bool bridge_succeeded = false;

            string out_dir = GLib.Path.get_dirname (output_path);
            ensure_parent_dir (output_path);

            string? soffice_bin = Core.PlatformUtils.find_program ("soffice", out_dir)
                ?? Core.PlatformUtils.find_program ("libreoffice", out_dir);

            if (soffice_bin != null) {
                string tmp_pptx = GLib.Path.build_filename (
                    Core.PlatformUtils.get_shared_cache_dir ("tmp"),
                    @"imladris_slides_$(GLib.Random.next_int ()).pptx"
                );
                bool pptx_ready = false;

                if ((fmt == DocumentFormat.QMD || fmt == DocumentFormat.IPYNB) &&
                    Core.PlatformUtils.is_program_available ("quarto", out_dir)) {
                    pptx_ready = run_tool_process ("quarto", { "render", input_path, "--to", "pptx", "-o", tmp_pptx }, out_dir)
                                 && GLib.FileUtils.test (tmp_pptx, GLib.FileTest.EXISTS);
                }

                if (!pptx_ready && Core.PlatformUtils.is_program_available ("pandoc", out_dir)) {
                    pptx_ready = run_tool_process ("pandoc", { input_path, "-t", "pptx", "-o", tmp_pptx, "--standalone" }, out_dir)
                                 && GLib.FileUtils.test (tmp_pptx, GLib.FileTest.EXISTS);
                }

                if (pptx_ready) {
                    try {
                        string[] raw_lo_argv = { soffice_bin, "--headless", "--convert-to", "odp", tmp_pptx, "--outdir", out_dir };
                        string[] lo_argv = Core.PlatformUtils.build_host_command (raw_lo_argv, out_dir);
                        var lo_proc = new GLib.Subprocess.newv (lo_argv, GLib.SubprocessFlags.STDOUT_PIPE | GLib.SubprocessFlags.STDERR_MERGE);
                        if (lo_proc.wait_check ()) {
                            string converted_name = GLib.Path.get_basename (tmp_pptx);
                            if (converted_name.has_suffix (".pptx")) {
                                converted_name = converted_name.substring (0, converted_name.length - 5) + ".odp";
                            }
                            string converted_path = GLib.Path.build_filename (out_dir, converted_name);
                            if (GLib.FileUtils.test (converted_path, GLib.FileTest.EXISTS)) {
                                var src_f = GLib.File.new_for_path (converted_path);
                                var dst_f = GLib.File.new_for_path (output_path);
                                src_f.move (dst_f, GLib.FileCopyFlags.OVERWRITE, null, null);
                                bridge_succeeded = true;
                            }
                        }
                    } catch (GLib.Error e) {
                        bridge_succeeded = false;
                    }
                }

                if (GLib.FileUtils.test (tmp_pptx, GLib.FileTest.EXISTS)) {
                    GLib.FileUtils.remove (tmp_pptx);
                }
            }

            if (!bridge_succeeded || !GLib.FileUtils.test (output_path, GLib.FileTest.EXISTS)) {
                string source_text = read_source_or_fallback (input_path, raw_buffer_fallback);
                build_oasis_odp_container (source_text, output_path);
            }
        }

        /**
         * Exports a document to standalone HTML using Pandoc (or Quarto/RMarkdown for notebooks),
         * with fallback to the high-fidelity internal DocumentAdapter HTML generator.
         */
        public static void export_to_html (string input_path, string output_path, string? raw_buffer_fallback = null) throws GLib.Error {
            var fmt = DocumentFormat.from_filename (input_path);
            bool cli_succeeded = false;

            string out_dir = GLib.Path.get_dirname (output_path);
            string out_file = GLib.Path.get_basename (output_path);
            ensure_parent_dir (output_path);

            string? actual_input = input_path;
            string? temp_md = null;
            if (!GLib.FileUtils.test (input_path, GLib.FileTest.EXISTS) && raw_buffer_fallback != null) {
                temp_md = GLib.Path.build_filename (
                    Core.PlatformUtils.get_shared_cache_dir ("tmp"),
                    @"imladris_export_$(GLib.Random.next_int ()).md"
                );
                GLib.FileUtils.set_contents (temp_md, raw_buffer_fallback);
                actual_input = temp_md;
            }

            if ((fmt == DocumentFormat.QMD || fmt == DocumentFormat.IPYNB) &&
                Core.PlatformUtils.is_program_available ("quarto", out_dir)) {
                cli_succeeded = run_tool_process ("quarto", { "render", actual_input, "--to", "html", "--output", out_file }, out_dir);
            } else if (fmt == DocumentFormat.RMD &&
                       Core.PlatformUtils.is_program_available ("Rscript", out_dir)) {
                string r_expr = "if (requireNamespace('rmarkdown', quietly=TRUE)) rmarkdown::render('%s', output_format = 'html_document', output_file = '%s', quiet = TRUE) else stop('no rmarkdown')".printf (
                    actual_input.replace ("'", "\\'"),
                    output_path.replace ("'", "\\'")
                );
                cli_succeeded = run_tool_process ("Rscript", { "-e", r_expr }, out_dir);
            }

            if (!cli_succeeded && Core.PlatformUtils.is_program_available ("pandoc", out_dir)) {
                cli_succeeded = run_tool_process ("pandoc", { actual_input, "-f", "markdown", "-t", "html5", "--standalone", "--embed-resources", "-o", output_path }, out_dir);
                if (!cli_succeeded) {
                    cli_succeeded = run_tool_process ("pandoc", { actual_input, "-f", "markdown", "-t", "html5", "--standalone", "-o", output_path }, out_dir);
                }
            }

            if (temp_md != null && GLib.FileUtils.test (temp_md, GLib.FileTest.EXISTS)) {
                GLib.FileUtils.remove (temp_md);
            }

            if (!cli_succeeded || !GLib.FileUtils.test (output_path, GLib.FileTest.EXISTS)) {
                string source_text = read_source_or_fallback (input_path, raw_buffer_fallback);
                string body_html = Adapters.DocumentAdapter.render_html (source_text, fmt);
                string doc_title = GLib.Path.get_basename (input_path);
                string html = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>%s</title>
  <style>
    body {
      font-family: 'Inter', system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      line-height: 1.6;
      color: #1e293b;
      background: #ffffff;
      max-width: 860px;
      margin: 0 auto;
      padding: 40px 24px;
    }
    h1, h2, h3, h4 { color: #0f172a; margin-top: 1.5em; margin-bottom: 0.5em; font-weight: 700; }
    h1 { font-size: 2.25rem; border-bottom: 1px solid #e2e8f0; padding-bottom: 0.3em; }
    h2 { font-size: 1.75rem; border-bottom: 1px solid #f1f5f9; padding-bottom: 0.2em; }
    p, li { font-size: 1.05rem; }
    pre {
      background: #f8fafc;
      border: 1px solid #e2e8f0;
      border-radius: 8px;
      padding: 16px;
      overflow-x: auto;
      font-family: 'JetBrains Mono', 'Fira Code', monospace;
      font-size: 0.92rem;
    }
    code { font-family: monospace; background: #f1f5f9; padding: 2px 6px; border-radius: 4px; }
    pre code { background: transparent; padding: 0; }
    .badge { display: inline-block; background: #e0f2fe; color: #0284c7; padding: 2px 8px; border-radius: 4px; font-weight: 600; font-size: 0.8rem; }
    .code-chunk-card { background: #f8fafc; border: 1px solid #cbd5e1; border-radius: 8px; margin: 16px 0; overflow: hidden; }
    .code-chunk-header { background: #e2e8f0; padding: 6px 12px; font-size: 12px; font-weight: 600; color: #475569; }
    blockquote { border-left: 4px solid #38bdf8; margin: 16px 0; padding-left: 16px; color: #64748b; }
    table { border-collapse: collapse; width: 100%%; margin: 20px 0; }
    th, td { border: 1px solid #cbd5e1; padding: 8px 12px; text-align: left; }
    th { background: #f1f5f9; font-weight: 600; }
  </style>
</head>
<body>
%s
</body>
</html>""".printf (doc_title, body_html);

                GLib.FileUtils.set_contents (output_path, html);
            }
        }

        /**
         * Exports a document to PDF using Pandoc (with typst/latex/weasyprint engine),
         * falling back to headless LibreOffice via intermediate ODT.
         */
        public static void export_to_pdf (string input_path, string output_path, string? raw_buffer_fallback = null) throws GLib.Error {
            var fmt = DocumentFormat.from_filename (input_path);
            bool cli_succeeded = false;

            string out_dir = GLib.Path.get_dirname (output_path);
            string out_file = GLib.Path.get_basename (output_path);
            ensure_parent_dir (output_path);

            string? actual_input = input_path;
            string? temp_md = null;
            if (!GLib.FileUtils.test (input_path, GLib.FileTest.EXISTS) && raw_buffer_fallback != null) {
                temp_md = GLib.Path.build_filename (
                    Core.PlatformUtils.get_shared_cache_dir ("tmp"),
                    @"imladris_export_$(GLib.Random.next_int ()).md"
                );
                GLib.FileUtils.set_contents (temp_md, raw_buffer_fallback);
                actual_input = temp_md;
            }

            // Stage 1: Try Quarto / RMarkdown direct PDF render if notebook
            if ((fmt == DocumentFormat.QMD || fmt == DocumentFormat.IPYNB) &&
                Core.PlatformUtils.is_program_available ("quarto", out_dir)) {
                cli_succeeded = run_tool_process ("quarto", { "render", actual_input, "--to", "pdf", "--output", out_file }, out_dir);
            } else if (fmt == DocumentFormat.RMD &&
                       Core.PlatformUtils.is_program_available ("Rscript", out_dir)) {
                string r_expr = "if (requireNamespace('rmarkdown', quietly=TRUE)) rmarkdown::render('%s', output_format = 'pdf_document', output_file = '%s', quiet = TRUE) else stop('no rmarkdown')".printf (
                    actual_input.replace ("'", "\\'"),
                    output_path.replace ("'", "\\'")
                );
                cli_succeeded = run_tool_process ("Rscript", { "-e", r_expr }, out_dir);
            }

            // Stage 2: Try Pandoc with detected PDF engines
            if (!cli_succeeded && Core.PlatformUtils.is_program_available ("pandoc", out_dir)) {
                string[] pdf_engines = { "typst", "weasyprint", "xelatex", "pdflatex", "lualatex", "wkhtmltopdf" };
                string? detected_engine = null;
                foreach (var eng in pdf_engines) {
                    if (Core.PlatformUtils.is_program_available (eng, out_dir)) {
                        detected_engine = eng;
                        break;
                    }
                }

                if (detected_engine != null) {
                    cli_succeeded = run_tool_process ("pandoc", { actual_input, "-f", "markdown", @"--pdf-engine=$detected_engine", "--standalone", "-o", output_path }, out_dir);
                } else {
                    cli_succeeded = run_tool_process ("pandoc", { actual_input, "-f", "markdown", "--standalone", "-o", output_path }, out_dir);
                }
            }

            // Stage 3: High-fidelity LibreOffice headless fallback via intermediate ODT
            if (!cli_succeeded || !GLib.FileUtils.test (output_path, GLib.FileTest.EXISTS)) {
                string? soffice_bin = Core.PlatformUtils.find_program ("soffice", out_dir)
                    ?? Core.PlatformUtils.find_program ("libreoffice", out_dir);

                if (soffice_bin != null) {
                    string tmp_odt = GLib.Path.build_filename (
                        Core.PlatformUtils.get_shared_cache_dir ("tmp"),
                        @"imladris_pdf_$(GLib.Random.next_int ()).odt"
                    );
                    export_to_odt (actual_input, tmp_odt, raw_buffer_fallback);
                    if (GLib.FileUtils.test (tmp_odt, GLib.FileTest.EXISTS)) {
                        try {
                            string[] raw_lo_argv = { soffice_bin, "--headless", "--convert-to", "pdf", tmp_odt, "--outdir", out_dir };
                            string[] lo_argv = Core.PlatformUtils.build_host_command (raw_lo_argv, out_dir);
                            var lo_proc = new GLib.Subprocess.newv (lo_argv, GLib.SubprocessFlags.STDOUT_PIPE | GLib.SubprocessFlags.STDERR_MERGE);
                            if (lo_proc.wait_check ()) {
                                string converted_name = GLib.Path.get_basename (tmp_odt);
                                if (converted_name.has_suffix (".odt")) {
                                    converted_name = converted_name.substring (0, converted_name.length - 4) + ".pdf";
                                }
                                string converted_path = GLib.Path.build_filename (out_dir, converted_name);
                                if (GLib.FileUtils.test (converted_path, GLib.FileTest.EXISTS)) {
                                    var src_f = GLib.File.new_for_path (converted_path);
                                    var dst_f = GLib.File.new_for_path (output_path);
                                    src_f.move (dst_f, GLib.FileCopyFlags.OVERWRITE, null, null);
                                    cli_succeeded = true;
                                }
                            }
                        } catch (GLib.Error e) {}
                        GLib.FileUtils.remove (tmp_odt);
                    }
                }
            }

            if (temp_md != null && GLib.FileUtils.test (temp_md, GLib.FileTest.EXISTS)) {
                GLib.FileUtils.remove (temp_md);
            }

            if (!cli_succeeded || !GLib.FileUtils.test (output_path, GLib.FileTest.EXISTS)) {
                throw new GLib.IOError.FAILED (
                    "PDF export requires Pandoc (with typst, weasyprint, or pdflatex) or LibreOffice. Please install pandoc or typst via your package manager."
                );
            }
        }

        private static ExportService? _instance = null;

        public static ExportService get_default () {
            if (_instance == null) {
                _instance = new ExportService ();
            }
            return _instance;
        }

        public async bool export_document_async (string input_path, string output_path, string format_target, string? raw_buffer = null) {
            string ext_label = format_target.up ();
            string src_path = input_path;

            string raw_text = raw_buffer != null ? raw_buffer : read_source_or_fallback (input_path, null);
            bool ok = false;
            string err_msg = "";

            GLib.SourceFunc callback = export_document_async.callback;
            new GLib.Thread<void*> ("imladris-export-worker", () => {
                try {
                    string target = format_target.down ();
                    if (target == "odp") {
                        export_to_odp (src_path, output_path, raw_text);
                    } else if (target == "html" || target == "htm") {
                        export_to_html (src_path, output_path, raw_text);
                    } else if (target == "pdf") {
                        export_to_pdf (src_path, output_path, raw_text);
                    } else {
                        export_to_odt (src_path, output_path, raw_text);
                    }
                    ok = true;
                } catch (GLib.Error e) {
                    err_msg = e.message;
                }
                GLib.Idle.add ((owned) callback);
                return null;
            });
            yield;

            if (!ok && err_msg != "") {
                GLib.warning ("Export to %s failed: %s", ext_label, err_msg);
            }
            return ok;
        }

        private static void ensure_parent_dir (string file_path) throws GLib.Error {
            string? parent = GLib.Path.get_dirname (file_path);
            if (parent != null && parent != "") {
                var dir = GLib.File.new_for_path (parent);
                if (!dir.query_exists ()) {
                    dir.make_directory_with_parents (null);
                }
            }
        }

        private static string read_source_or_fallback (string input_path, string? fallback) {
            if (GLib.FileUtils.test (input_path, GLib.FileTest.EXISTS)) {
                try {
                    string content;
                    GLib.FileUtils.get_contents (input_path, out content);
                    var fmt = DocumentFormat.from_filename (input_path);
                    return Adapters.DocumentAdapter.load_to_editor_buffer (content, fmt);
                } catch (GLib.FileError e) {
                    // Use fallback
                }
            }
            return fallback ?? "";
        }

        /**
         * Standards-compliant OASIS OpenDocument Text (.odt) ZIP container generator.
         */
        private static void build_oasis_odt_container (string markdown_source, string output_path) throws GLib.Error {
            Core.FrontmatterData? meta;
            string body;
            Core.FrontmatterParser.split_frontmatter (markdown_source, out meta, out body);

            var body_xml = new GLib.StringBuilder ();
            if (meta != null && meta.title != null && meta.title.strip () != "") {
                body_xml.append_printf (
                    "<text:h text:style-name=\"Heading_20_1\" text:outline-level=\"1\">%s</text:h>\n",
                    GLib.Markup.escape_text (meta.title.strip ())
                );
            }

            foreach (string raw_line in body.split ("\n")) {
                string line = raw_line.strip ();
                if (line == "") continue;
                if (line.has_prefix ("### ")) {
                    body_xml.append_printf (
                        "<text:h text:style-name=\"Heading_20_3\" text:outline-level=\"3\">%s</text:h>\n",
                        GLib.Markup.escape_text (line.substring (4))
                    );
                } else if (line.has_prefix ("## ")) {
                    body_xml.append_printf (
                        "<text:h text:style-name=\"Heading_20_2\" text:outline-level=\"2\">%s</text:h>\n",
                        GLib.Markup.escape_text (line.substring (3))
                    );
                } else if (line.has_prefix ("# ")) {
                    body_xml.append_printf (
                        "<text:h text:style-name=\"Heading_20_1\" text:outline-level=\"1\">%s</text:h>\n",
                        GLib.Markup.escape_text (line.substring (2))
                    );
                } else {
                    body_xml.append_printf (
                        "<text:p text:style-name=\"Standard\">%s</text:p>\n",
                        GLib.Markup.escape_text (raw_line)
                    );
                }
            }

            string content_xml = """<?xml version="1.0" encoding="UTF-8"?>
<office:document-content xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0"
  xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0"
  xmlns:style="urn:oasis:names:tc:opendocument:xmlns:style:1.0"
  office:version="1.2">
  <office:body>
    <office:text>
%s    </office:text>
  </office:body>
</office:document-content>
""".printf (body_xml.str);

            package_oasis_zip (
                "application/vnd.oasis.opendocument.text",
                content_xml,
                output_path
            );
        }

        /**
         * Standards-compliant OASIS OpenDocument Presentation (.odp) ZIP container generator.
         */
        private static void build_oasis_odp_container (string markdown_source, string output_path) throws GLib.Error {
            Core.FrontmatterData? meta;
            string body;
            Core.FrontmatterParser.split_frontmatter (markdown_source, out meta, out body);

            var pages_xml = new GLib.StringBuilder ();
            int slide_num = 0;

            string[] lines = body.split ("\n");
            string current_title = (meta != null && meta.title != null && meta.title.strip () != "")
                ? meta.title.strip ()
                : "Slide 1";
            var current_bullets = new GLib.StringBuilder ();

            foreach (string raw_line in lines) {
                string trimmed = raw_line.strip ();
                if (trimmed == "---" || trimmed.has_prefix ("# ") || trimmed.has_prefix ("## ")) {
                    if (slide_num > 0 || current_bullets.len > 0) {
                        slide_num++;
                        append_odp_slide (pages_xml, slide_num, current_title, current_bullets.str);
                        current_bullets.truncate (0);
                    }
                    if (trimmed.has_prefix ("## ")) {
                        current_title = trimmed.substring (3).strip ();
                    } else if (trimmed.has_prefix ("# ")) {
                        current_title = trimmed.substring (2).strip ();
                    } else {
                        current_title = @"Slide $(slide_num + 1)";
                    }
                    continue;
                }
                if (trimmed != "") {
                    string clean_item = (trimmed.has_prefix ("- ") || trimmed.has_prefix ("* "))
                        ? trimmed.substring (2).strip ()
                        : trimmed;
                    current_bullets.append_printf (
                        "          <text:p>%s</text:p>\n",
                        GLib.Markup.escape_text (clean_item)
                    );
                }
            }

            slide_num++;
            append_odp_slide (pages_xml, slide_num, current_title, current_bullets.str);

            string content_xml = """<?xml version="1.0" encoding="UTF-8"?>
<office:document-content xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0"
  xmlns:draw="urn:oasis:names:tc:opendocument:xmlns:drawing:1.0"
  xmlns:presentation="urn:oasis:names:tc:opendocument:xmlns:presentation:1.0"
  xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0"
  xmlns:svg="urn:oasis:names:tc:opendocument:xmlns:svg-compatible:1.0"
  office:version="1.2">
  <office:body>
    <office:presentation>
%s    </office:presentation>
  </office:body>
</office:document-content>
""".printf (pages_xml.str);

            package_oasis_zip (
                "application/vnd.oasis.opendocument.presentation",
                content_xml,
                output_path
            );
        }

        private static void append_odp_slide (GLib.StringBuilder sb, int index, string title, string body_paragraphs) {
            sb.append_printf ("      <draw:page draw:name=\"page%d\" draw:master-page-name=\"Default\">\n", index);
            sb.append ("        <draw:frame presentation:class=\"title\" svg:x=\"2cm\" svg:y=\"1.5cm\" svg:width=\"24cm\" svg:height=\"3cm\">\n");
            sb.append ("          <draw:text-box>\n");
            sb.append_printf ("            <text:p>%s</text:p>\n", GLib.Markup.escape_text (title));
            sb.append ("          </draw:text-box>\n");
            sb.append ("        </draw:frame>\n");
            sb.append ("        <draw:frame presentation:class=\"outline\" svg:x=\"2cm\" svg:y=\"5cm\" svg:width=\"24cm\" svg:height=\"12cm\">\n");
            sb.append ("          <draw:text-box>\n");
            sb.append (body_paragraphs);
            sb.append ("          </draw:text-box>\n");
            sb.append ("        </draw:frame>\n");
            sb.append ("      </draw:page>\n");
        }

        private static void package_oasis_zip (string mimetype, string content_xml, string output_path) throws GLib.Error {
            string styles_xml = """<?xml version="1.0" encoding="UTF-8"?>
<office:document-styles xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0"
  xmlns:style="urn:oasis:names:tc:opendocument:xmlns:style:1.0"
  office:version="1.2">
  <office:styles/>
  <office:master-styles>
    <style:master-page style:name="Default"/>
  </office:master-styles>
</office:document-styles>
""";

            string manifest_xml = """<?xml version="1.0" encoding="UTF-8"?>
<manifest:manifest xmlns:manifest="urn:oasis:names:tc:opendocument:xmlns:manifest:1.0" manifest:version="1.2">
  <manifest:file-entry manifest:full-path="/" manifest:media-type="%s"/>
  <manifest:file-entry manifest:full-path="content.xml" manifest:media-type="text/xml"/>
  <manifest:file-entry manifest:full-path="styles.xml" manifest:media-type="text/xml"/>
</manifest:manifest>
""".printf (mimetype);

            string py_packer = """import sys, zipfile
out_path, mime, content_xml, styles_xml, manifest_xml = sys.argv[1:6]
with zipfile.ZipFile(out_path, 'w') as zf:
    zf.writestr('mimetype', mime, compress_type=zipfile.ZIP_STORED)
    zf.writestr('content.xml', content_xml, compress_type=zipfile.ZIP_DEFLATED)
    zf.writestr('styles.xml', styles_xml, compress_type=zipfile.ZIP_DEFLATED)
    zf.writestr('META-INF/manifest.xml', manifest_xml, compress_type=zipfile.ZIP_DEFLATED)
""";

            string[] argv = { "python3", "-c", py_packer, output_path, mimetype, content_xml, styles_xml, manifest_xml };
            var proc = new GLib.Subprocess.newv (argv, GLib.SubprocessFlags.STDOUT_SILENCE | GLib.SubprocessFlags.STDERR_PIPE);
            proc.wait_check ();
        }
    }
}
