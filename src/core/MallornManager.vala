namespace Imladris {

    public class MallornManager : GLib.Object {

        public const string MALLORN_SPEC_VERSION = "1.0";

        /**
         * Checks if a .mallorn file is a binary archive (.tar.zst or .zip) or a DCF text manifest.
         */
        public static bool is_mallorn_archive (string mallorn_path) {
            try {
                var file = File.new_for_path (mallorn_path);
                if (!file.query_exists ()) return false;
                var dis = new DataInputStream (file.read (null));
                uint8[] header = new uint8[4];
                size_t bytes_read = 0;
                dis.read_all (header, out bytes_read, null);
                bool is_zip = (bytes_read >= 4 && header[0] == 0x50 && header[1] == 0x4b && header[2] == 0x03 && header[3] == 0x04);
                bool is_zstd = (bytes_read >= 4 && header[0] == 0x28 && header[1] == 0xb5 && header[2] == 0x2f && header[3] == 0xfd);
                return is_zip || is_zstd;
            } catch (GLib.Error e) {
                return false;
            }
        }

        /**
         * Generates the 1:1 RStudio-compatible DCF/INI manifest header with
         * extended Imladris* metadata.
         */
        public static string generate_rproj_manifest (ProjectConfig config) {
            var sb = new StringBuilder ();
            sb.append ("Version: 1.0\n");
            sb.append ("RestoreWorkspace: Default\n");
            sb.append ("SaveWorkspace: Default\n");
            sb.append ("AlwaysSaveHistory: Default\n");
            sb.append ("EnableCodeIndexing: Yes\n");
            sb.append ("UseSpacesForTab: Yes\n");
            sb.append ("NumSpacesForTab: 2\n");
            sb.append ("Encoding: UTF-8\n");
            sb.append ("RnwWeave: knitr\n");
            sb.append ("LaTeX: pdfLaTeX\n");
            sb.append ("\n");
            sb.append ("# Imladris Extended Metadata\n");
            sb.append_printf ("ImladrisVersion: %s\n", config.imladris_version != "" ? config.imladris_version : MALLORN_SPEC_VERSION);
            sb.append_printf ("ImladrisProjectType: %s\n", config.project_type.to_string ());
            sb.append_printf ("ImladrisPrimaryFormat: %s\n", config.format.get_short_code ());
            if (config.project_name.strip () != "") {
                sb.append_printf ("ImladrisProjectName: %s\n", config.project_name.strip ());
            }
            if (config.author.strip () != "") {
                sb.append_printf ("ImladrisAuthor: %s\n", config.author.strip ());
            }
            sb.append_printf ("ImladrisSandboxed: %s\n", config.sandboxed ? "true" : "false");
            return sb.str;
        }

        /**
         * Parses a .mallorn or .Rproj DCF/INI manifest into a ProjectConfig instance.
         */
        public static ProjectConfig parse_manifest (string content) {
            var config = new ProjectConfig ();
            string[] lines = content.split ("\n");

            foreach (string raw_line in lines) {
                string line = raw_line.strip ();
                if (line.length == 0 || line.has_prefix ("#")) {
                    continue;
                }
                int colon_idx = line.index_of (":");
                if (colon_idx < 0) continue;

                string key = line.substring (0, colon_idx).strip ();
                string val = line.substring (colon_idx + 1).strip ();

                if (key == "ImladrisProjectType") {
                    config.project_type = ProjectType.from_string (val);
                } else if (key == "ImladrisPrimaryFormat") {
                    config.format = DocumentFormat.from_short_code (val);
                } else if (key == "ImladrisProjectName") {
                    config.project_name = val;
                } else if (key == "ImladrisAuthor") {
                    config.author = val;
                } else if (key == "ImladrisVersion") {
                    config.imladris_version = val;
                } else if (key == "ImladrisSandboxed") {
                    config.sandboxed = (val.down () == "true" || val == "1");
                }
            }
            return config;
        }

        /**
         * Writes <project_name>.mallorn, <project_name>.Rproj (1:1 RStudio parity),
         * .mallorn.json (Imladris workspace state) and imladris.toml in project_dir.
         */
        public static void write_project_manifests (string project_dir, ProjectConfig config) throws GLib.Error {
            File dir = File.new_for_path (project_dir);
            if (!dir.query_exists ()) {
                dir.make_directory_with_parents (null);
            }

            string clean_name = ProjectScaffolder.sanitize_dirname (config.project_name);
            string manifest_content = generate_rproj_manifest (config);

            // 1. Write <project_name>.mallorn
            string mallorn_file_path = Path.build_filename (project_dir, clean_name + ".mallorn");
            FileUtils.set_contents (mallorn_file_path, manifest_content);

            // 2. Write 1:1 <project_name>.Rproj
            string rproj_file_path = Path.build_filename (project_dir, clean_name + ".Rproj");
            FileUtils.set_contents (rproj_file_path, manifest_content);

            // 3. Write .mallorn.json (State, UI layout, metadata)
            string now_iso = new DateTime.now_utc ().format_iso8601 ();
            string json_content = """{
  "imladris_version": "%s",
  "project_name": "%s",
  "author": "%s",
  "project_type": "%s",
  "primary_format": "%s",
  "sandboxed": %s,
  "created_at": "%s",
  "rstudio_compatible": true
}
""".printf (
                config.imladris_version,
                config.project_name,
                config.author,
                config.project_type.to_string (),
                config.format.get_short_code (),
                config.sandboxed ? "true" : "false",
                now_iso
            );
            string json_file_path = Path.build_filename (project_dir, ".mallorn.json");
            FileUtils.set_contents (json_file_path, json_content);

            // 4. Write imladris.toml
            string toml_content = """[project]
name = "%s"
version = "%s"
sandboxed = %s
format = "%s"
author = "%s"
""".printf (
                config.project_name,
                config.imladris_version,
                config.sandboxed ? "true" : "false",
                config.format.get_short_code (),
                config.author
            );
            string toml_file_path = Path.build_filename (project_dir, "imladris.toml");
            FileUtils.set_contents (toml_file_path, toml_content);
        }

        /**
         * Ensures <name>.mallorn and <name>.Rproj stay 1:1 synchronized in project_dir.
         */
        public static void sync_rproj_and_mallorn (string project_dir) throws GLib.Error {
            File dir = File.new_for_path (project_dir);
            if (!dir.query_exists ()) return;

            string? mallorn_path = null;
            string? rproj_path = null;

            var enumerator = dir.enumerate_children ("standard::name", FileQueryInfoFlags.NONE, null);
            FileInfo? info = null;
            while ((info = enumerator.next_file (null)) != null) {
                string name = info.get_name ();
                if (name.has_suffix (".mallorn")) {
                    mallorn_path = Path.build_filename (project_dir, name);
                } else if (name.has_suffix (".Rproj")) {
                    rproj_path = Path.build_filename (project_dir, name);
                }
            }

            if (mallorn_path != null && rproj_path == null) {
                string base_no_ext = mallorn_path.substring (0, mallorn_path.length - 8);
                string new_rproj = base_no_ext + ".Rproj";
                string content;
                FileUtils.get_contents (mallorn_path, out content);
                FileUtils.set_contents (new_rproj, content);
            } else if (rproj_path != null && mallorn_path == null) {
                string base_no_ext = rproj_path.substring (0, rproj_path.length - 6);
                string new_mallorn = base_no_ext + ".mallorn";
                string content;
                FileUtils.get_contents (rproj_path, out content);
                FileUtils.set_contents (new_mallorn, content);
            }
        }

        /**
         * Packages the workspace as a standard .mallorn exchange archive (.tar.zst or .zip)
         */
        public static void pack_mallorn_archive (string project_dir, string output_path) throws GLib.Error {
            File pdir = File.new_for_path (project_dir);
            if (!pdir.query_exists ()) {
                throw new IOError.NOT_FOUND (@"Project directory not found: $project_dir");
            }

            // Sync manifests before archiving
            sync_rproj_and_mallorn (project_dir);

            // Ensure destination folder exists
            string? out_parent = Path.get_dirname (output_path);
            if (out_parent != null) {
                File op = File.new_for_path (out_parent);
                if (!op.query_exists ()) op.make_directory_with_parents (null);
            }

            // Attempt tar --zstd first
            bool success = false;
            try {
                string[] argv = { "tar", "-C", project_dir, "--zstd", "-cf", output_path, "." };
                var proc = new Subprocess.newv (argv, SubprocessFlags.STDOUT_SILENCE | SubprocessFlags.STDERR_PIPE);
                success = proc.wait_check ();
            } catch (GLib.Error e) {
                success = false;
            }

            if (!success) {
                // Fallback to python3 zipfile
                string py_code = "import zipfile, os, sys\n"
                    + "src, dst = sys.argv[1], sys.argv[2]\n"
                    + "with zipfile.ZipFile(dst, 'w', zipfile.ZIP_DEFLATED) as zf:\n"
                    + "    for root, dirs, files in os.walk(src):\n"
                    + "        for f in files:\n"
                    + "            p = os.path.join(root, f)\n"
                    + "            rel = os.path.relpath(p, src)\n"
                    + "            zf.write(p, rel)\n";

                string[] py_argv = { "python3", "-c", py_code, project_dir, output_path };
                var py_proc = new Subprocess.newv (py_argv, SubprocessFlags.STDOUT_SILENCE | SubprocessFlags.STDERR_PIPE);
                py_proc.wait_check ();
            }
        }

        /**
         * Unpacks a .mallorn exchange archive or initializes from a DCF project file,
         * ensuring 1:1 RStudio parity and returning the loaded ProjectConfig.
         */
        public static ProjectConfig unpack_mallorn_archive (string mallorn_path, string target_dir) throws GLib.Error {
            File mfile = File.new_for_path (mallorn_path);
            if (!mfile.query_exists ()) {
                throw new IOError.NOT_FOUND (@"Mallorn path not found: $mallorn_path");
            }

            File tdir = File.new_for_path (target_dir);
            if (!tdir.query_exists ()) {
                tdir.make_directory_with_parents (null);
            }

            // Inspect header bytes
            uint8[] header = new uint8[8];
            size_t bytes_read = 0;
            var dis = new DataInputStream (mfile.read (null));
            dis.read_all (header, out bytes_read, null);

            bool is_zip = (bytes_read >= 4 && header[0] == 0x50 && header[1] == 0x4b && header[2] == 0x03 && header[3] == 0x04);
            bool is_zstd = (bytes_read >= 4 && header[0] == 0x28 && header[1] == 0xb5 && header[2] == 0x2f && header[3] == 0xfd);

            if (is_zstd) {
                string[] argv = { "tar", "-C", target_dir, "--zstd", "-xf", mallorn_path };
                var proc = new Subprocess.newv (argv, SubprocessFlags.STDOUT_SILENCE | SubprocessFlags.STDERR_PIPE);
                proc.wait_check ();
            } else if (is_zip) {
                string[] argv = { "python3", "-m", "zipfile", "-e", mallorn_path, target_dir };
                var proc = new Subprocess.newv (argv, SubprocessFlags.STDOUT_SILENCE | SubprocessFlags.STDERR_PIPE);
                proc.wait_check ();
            } else {
                // If it's a plain DCF text file, copy into target_dir
                string content;
                FileUtils.get_contents (mallorn_path, out content);
                string base_filename = mfile.get_basename ();
                FileUtils.set_contents (Path.build_filename (target_dir, base_filename), content);
            }

            // Guarantee 1:1 synchronicity in extracted folder
            sync_rproj_and_mallorn (target_dir);

            // Locate manifest in target_dir to return ProjectConfig
            string? found_manifest = null;
            var enumerator = tdir.enumerate_children ("standard::name", FileQueryInfoFlags.NONE, null);
            FileInfo? info = null;
            while ((info = enumerator.next_file (null)) != null) {
                string name = info.get_name ();
                if (name.has_suffix (".mallorn") || name.has_suffix (".Rproj")) {
                    found_manifest = Path.build_filename (target_dir, name);
                    if (name.has_suffix (".mallorn")) break; // Prefer .mallorn
                }
            }

            if (found_manifest != null) {
                string text;
                FileUtils.get_contents (found_manifest, out text);
                var cfg = parse_manifest (text);
                cfg.custom_project_dir = target_dir;
                return cfg;
            }

            // Fallback default
            var fallback_cfg = new ProjectConfig ();
            fallback_cfg.project_name = tdir.get_basename ();
            fallback_cfg.custom_project_dir = target_dir;
            return fallback_cfg;
        }
    }
}
