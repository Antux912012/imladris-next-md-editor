[CCode (cheader_filename = "cmark.h", cprefix = "cmark_", lower_case_cprefix = "cmark_")]
namespace CMark {
    [CCode (cname = "cmark_node_type", cprefix = "CMARK_NODE_")]
    public enum NodeType {
        NONE,
        DOCUMENT,
        BLOCK_QUOTE,
        LIST,
        ITEM,
        CODE_BLOCK,
        HTML_BLOCK,
        CUSTOM_BLOCK,
        PARAGRAPH,
        HEADING,
        THEMATIC_BREAK,
        TEXT,
        SOFTBREAK,
        LINEBREAK,
        CODE,
        HTML_INLINE,
        CUSTOM_INLINE,
        EMPH,
        STRONG,
        LINK,
        IMAGE
    }

    [CCode (cname = "CMARK_OPT_DEFAULT")]
    public const int OPT_DEFAULT;
    [CCode (cname = "CMARK_OPT_SOURCEPOS")]
    public const int OPT_SOURCEPOS;
    [CCode (cname = "CMARK_OPT_HARDBREAKS")]
    public const int OPT_HARDBREAKS;
    [CCode (cname = "CMARK_OPT_SAFE")]
    public const int OPT_SAFE;
    [CCode (cname = "CMARK_OPT_UNSAFE")]
    public const int OPT_UNSAFE;
    [CCode (cname = "CMARK_OPT_VALIDATE_UTF8")]
    public const int OPT_VALIDATE_UTF8;
    [CCode (cname = "CMARK_OPT_SMART")]
    public const int OPT_SMART;

    [CCode (cname = "cmark_markdown_to_html")]
    public static string markdown_to_html (string text, size_t len, int options = OPT_DEFAULT);

    [CCode (cname = "cmark_node", has_type_id = false, free_function = "cmark_node_free")]
    [Compact]
    public class Node {
        [CCode (cname = "cmark_node_new")]
        public Node (NodeType type);

        [CCode (cname = "cmark_node_get_type")]
        public NodeType get_node_type ();

        [CCode (cname = "cmark_node_get_literal")]
        public unowned string? get_literal ();

        [CCode (cname = "cmark_node_set_literal")]
        public int set_literal (string content);

        [CCode (cname = "cmark_node_get_start_line")]
        public int get_start_line ();

        [CCode (cname = "cmark_node_get_start_column")]
        public int get_start_column ();

        [CCode (cname = "cmark_node_get_end_line")]
        public int get_end_line ();

        [CCode (cname = "cmark_node_get_end_column")]
        public int get_end_column ();

        [CCode (cname = "cmark_node_first_child")]
        public unowned Node? first_child ();

        [CCode (cname = "cmark_node_next")]
        public unowned Node? next ();

        [CCode (cname = "cmark_render_html")]
        public string render_html (int options = OPT_DEFAULT);
    }

    [CCode (cname = "cmark_parser", has_type_id = false, free_function = "cmark_parser_free")]
    [Compact]
    public class Parser {
        [CCode (cname = "cmark_parser_new")]
        public Parser (int options = OPT_DEFAULT);

        [CCode (cname = "cmark_parser_feed")]
        public void feed (string buffer, size_t len);

        [CCode (cname = "cmark_parser_finish")]
        public Node finish ();
    }
}
