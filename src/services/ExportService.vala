namespace Imladris.Services {

    public class ExportService : GLib.Object {

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
                GLib.Environment.find_program_in_path ("quarto") != null) {
                try {
                    var launcher = new GLib.SubprocessLauncher (GLib.SubprocessFlags.STDOUT_PIPE | GLib.SubprocessFlags.STDERR_MERGE);
                    launcher.set_cwd (out_dir);
                    string[] argv = { "quarto", "render", input_path, "--to", "odt", "--output", out_file };
                    var proc = launcher.spawnv (argv);
                    cli_succeeded = proc.wait_check ();
                } catch (GLib.Error e) {
                    cli_succeeded = false;
                }
            } else if (fmt == DocumentFormat.RMD &&
                       GLib.Environment.find_program_in_path ("Rscript") != null) {
                try {
                    string r_expr = "if (requireNamespace('rmarkdown', quietly=TRUE)) rmarkdown::render('%s', output_format = 'odt_document', output_file = '%s', quiet = TRUE) else stop('no rmarkdown')".printf (
                        input_path.replace ("'", "\\'"),
                        output_path.replace ("'", "\\'")
                    );
                    string[] argv = { "Rscript", "-e", r_expr };
                    var proc = new GLib.Subprocess.newv (argv, GLib.SubprocessFlags.STDOUT_PIPE | GLib.SubprocessFlags.STDERR_MERGE);
                    cli_succeeded = proc.wait_check ();
                } catch (GLib.Error e) {
                    cli_succeeded = false;
                }
            }

            if (!cli_succeeded && GLib.Environment.find_program_in_path ("pandoc") != null) {
                try {
                    string[] argv = { "pandoc", input_path, "-f", "markdown", "-t", "odt", "-o", output_path, "--standalone" };
                    var proc = new GLib.Subprocess.newv (argv, GLib.SubprocessFlags.STDOUT_PIPE | GLib.SubprocessFlags.STDERR_MERGE);
                    cli_succeeded = proc.wait_check ();
                } catch (GLib.Error e) {
                    cli_succeeded = false;
                }
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

            string? soffice_bin = GLib.Environment.find_program_in_path ("soffice")
                ?? GLib.Environment.find_program_in_path ("libreoffice");

            if (soffice_bin != null) {
                string tmp_pptx = GLib.Path.build_filename (
                    GLib.Environment.get_tmp_dir (),
                    @"imladris_slides_$(GLib.Random.next_int ()).pptx"
                );
                bool pptx_ready = false;

                if ((fmt == DocumentFormat.QMD || fmt == DocumentFormat.IPYNB) &&
                    GLib.Environment.find_program_in_path ("quarto") != null) {
                    try {
                        string[] q_argv = { "quarto", "render", input_path, "--to", "pptx", "-o", tmp_pptx };
                        var q_proc = new GLib.Subprocess.newv (q_argv, GLib.SubprocessFlags.STDOUT_PIPE | GLib.SubprocessFlags.STDERR_MERGE);
                        pptx_ready = q_proc.wait_check () && GLib.FileUtils.test (tmp_pptx, GLib.FileTest.EXISTS);
                    } catch (GLib.Error e) {
                        pptx_ready = false;
                    }
                }

                if (!pptx_ready && GLib.Environment.find_program_in_path ("pandoc") != null) {
                    try {
                        string[] p_argv = { "pandoc", input_path, "-t", "pptx", "-o", tmp_pptx, "--standalone" };
                        var p_proc = new GLib.Subprocess.newv (p_argv, GLib.SubprocessFlags.STDOUT_PIPE | GLib.SubprocessFlags.STDERR_MERGE);
                        pptx_ready = p_proc.wait_check () && GLib.FileUtils.test (tmp_pptx, GLib.FileTest.EXISTS);
                    } catch (GLib.Error e) {
                        pptx_ready = false;
                    }
                }

                if (pptx_ready) {
                    try {
                        string[] lo_argv = { soffice_bin, "--headless", "--convert-to", "odp", tmp_pptx, "--outdir", out_dir };
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
                    if (format_target.down () == "odp") {
                        export_to_odp (src_path, output_path, raw_text);
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
