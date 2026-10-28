using GLib;
using Imladris.Core;

namespace Imladris.Services {

    /**
     * MediaHelper
     *
     * Simplifies inserting images and videos into documents.
     * When inserting media into a Sandboxed project, any asset located outside
     * the project directory is automatically copied into the project's 'img/'
     * subfolder to ensure project reproducibility and encapsulation.
     *
     * Relative linking paths are generated from the document's location.
     */
    public class MediaHelper : GLib.Object {

        public static string process_and_link_media (
            string src_path,
            string? project_dir,
            bool is_sandboxed,
            string? doc_file_path,
            bool is_video,
            string? caption_override = null
        ) throws GLib.Error {
            if (!FileUtils.test (src_path, FileTest.EXISTS)) {
                throw new IOError.NOT_FOUND ("Media file not found at: %s", src_path);
            }

            string filename = GLib.Path.get_basename (src_path);

            string? effective_project_dir = null;
            if (project_dir != null && project_dir.length > 0 && FileUtils.test (project_dir, FileTest.IS_DIR)) {
                effective_project_dir = project_dir;
            } else if (doc_file_path != null && doc_file_path.length > 0) {
                effective_project_dir = GLib.Path.get_dirname (doc_file_path);
            }

            bool is_external = true;
            if (effective_project_dir != null) {
                string norm_proj = effective_project_dir.has_suffix ("/") ? effective_project_dir : effective_project_dir + "/";
                if (src_path.has_prefix (norm_proj) || src_path == effective_project_dir) {
                    is_external = false;
                }
            }

            File final_file = File.new_for_path (src_path);

            // If external to a sandboxed project -> copy into <project_dir>/img/
            if (is_sandboxed && effective_project_dir != null && is_external) {
                string img_dir = GLib.Path.build_filename (effective_project_dir, "img");
                DirUtils.create_with_parents (img_dir, 0755);

                string dest_path = GLib.Path.build_filename (img_dir, filename);
                bool needs_copy = true;

                // Handle file collision or reuse existing identical asset
                if (FileUtils.test (dest_path, FileTest.EXISTS) && dest_path != src_path) {
                    try {
                        var src_info = File.new_for_path (src_path).query_info (FileAttribute.STANDARD_SIZE, FileQueryInfoFlags.NONE);
                        var dst_info = File.new_for_path (dest_path).query_info (FileAttribute.STANDARD_SIZE, FileQueryInfoFlags.NONE);
                        if (src_info.get_size () == dst_info.get_size ()) {
                            // Exact same asset already in img/ -> reuse it
                            final_file = File.new_for_path (dest_path);
                            needs_copy = false;
                        } else {
                            string name_part = filename;
                            string ext_part = "";
                            int dot = filename.last_index_of (".");
                            if (dot > 0) {
                                name_part = filename.substring (0, dot);
                                ext_part = filename.substring (dot);
                            }
                            int counter = 1;
                            while (FileUtils.test (dest_path, FileTest.EXISTS)) {
                                dest_path = GLib.Path.build_filename (img_dir, @"$(name_part)_$counter$ext_part");
                                counter++;
                            }
                        }
                    } catch (Error e) {}
                }

                if (needs_copy) {
                    var src_f = File.new_for_path (src_path);
                    var dst_f = File.new_for_path (dest_path);
                    src_f.copy (dst_f, FileCopyFlags.OVERWRITE | FileCopyFlags.NOFOLLOW_SYMLINKS, null, null);
                    final_file = dst_f;
                }
            }

            // Determine relative link path for document
            string link_path;
            File? base_dir_file = null;
            if (doc_file_path != null && doc_file_path.length > 0) {
                base_dir_file = File.new_for_path (GLib.Path.get_dirname (doc_file_path));
            } else if (effective_project_dir != null) {
                base_dir_file = File.new_for_path (effective_project_dir);
            }

            if (base_dir_file != null) {
                string? rel = base_dir_file.get_relative_path (final_file);
                if (rel != null && !rel.has_prefix ("../../../../")) {
                    link_path = rel;
                } else {
                    link_path = final_file.get_path ();
                }
            } else {
                link_path = final_file.get_path ();
            }

            // Caption formatting
            string caption;
            if (caption_override != null && caption_override.strip ().length > 0) {
                caption = caption_override.strip ();
            } else {
                string name_no_ext = final_file.get_basename ();
                int dot = name_no_ext.last_index_of (".");
                if (dot > 0) name_no_ext = name_no_ext.substring (0, dot);
                caption = name_no_ext.replace ("_", " ").replace ("-", " ").strip ();
                if (caption.length > 0) {
                    caption = caption.substring (0, 1).up () + caption.substring (1);
                } else {
                    caption = is_video ? "Video" : "Image";
                }
            }

            if (is_video) {
                bool is_qmd = (doc_file_path != null && doc_file_path.has_suffix (".qmd"));
                if (is_qmd) {
                    return @"{{< video $link_path >}}\n";
                } else {
                    return @"<video src=\"$link_path\" controls width=\"100%\"></video>\n";
                }
            } else {
                return @"![$caption]($link_path)\n";
            }
        }
    }
}
