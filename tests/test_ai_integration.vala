using GLib;
using Json;
using Gee;
using Imladris.Core;

namespace Imladris.Tests {

    public static int main (string[] args) {
        GLib.Test.init (ref args);

        GLib.Test.add_func ("/ai/provider_metadata", test_ai_provider_metadata);
        GLib.Test.add_func ("/ai/url_normalization", test_url_normalization);
        GLib.Test.add_func ("/ai/bytes_to_string", test_bytes_to_string);
        GLib.Test.add_func ("/ai/config_manager_defaults_and_persistence", test_config_manager);
        GLib.Test.add_func ("/ai/deepseek_reasoning_parsing", test_deepseek_reasoning_parsing);
        GLib.Test.add_func ("/ai/claude_messages_parsing", test_claude_messages_parsing);
        GLib.Test.add_func ("/ai/think_tag_extraction", test_think_tag_extraction);
        GLib.Test.add_func ("/ai/env_var_fallback", test_env_var_fallback);
        GLib.Test.add_func ("/theming/app_theme_metadata", test_app_theme);
        GLib.Test.add_func ("/theming/gnome_accent_metadata", test_gnome_accent_metadata);
        GLib.Test.add_func ("/core/distro_detection", test_distro_detection);

        return GLib.Test.run ();
    }

    private static void test_ai_provider_metadata () {
        // 1. Google Gemini
        var gemini = AiProvider.GEMINI;
        assert (gemini.to_string_id () == "gemini");
        assert (AiProvider.from_string_id ("gemini") == AiProvider.GEMINI);
        assert (gemini.get_default_endpoint () == "https://generativelanguage.googleapis.com/v1beta/openai");
        assert (gemini.get_default_model () == "gemini-2.0-flash");
        assert (gemini.get_api_key_help_url () == "https://aistudio.google.com/app/apikey");
        assert (gemini.get_env_var_name () == "GEMINI_API_KEY");
        assert (gemini.requires_api_key () == true);

        // 2. Claude (Anthropic)
        var claude = AiProvider.CLAUDE;
        assert (claude.to_string_id () == "claude");
        assert (AiProvider.from_string_id ("claude") == AiProvider.CLAUDE);
        assert (AiProvider.from_string_id ("anthropic") == AiProvider.CLAUDE);
        assert (claude.get_default_endpoint () == "https://api.anthropic.com/v1");
        assert (claude.get_default_model () == "claude-3-5-sonnet-20241022");
        assert (claude.get_api_key_help_url () == "https://console.anthropic.com/settings/keys");
        assert (claude.get_env_var_name () == "ANTHROPIC_API_KEY");
        assert (claude.requires_api_key () == true);

        // 3. OpenAI
        var openai = AiProvider.OPENAI;
        assert (openai.to_string_id () == "openai");
        assert (AiProvider.from_string_id ("openai") == AiProvider.OPENAI);
        assert (AiProvider.from_string_id ("chatgpt") == AiProvider.OPENAI);
        assert (openai.get_default_endpoint () == "https://api.openai.com/v1");
        assert (openai.get_default_model () == "gpt-4o");
        assert (openai.get_api_key_help_url () == "https://platform.openai.com/api-keys");
        assert (openai.get_env_var_name () == "OPENAI_API_KEY");
        assert (openai.requires_api_key () == true);

        // 4. DeepSeek
        var ds = AiProvider.DEEPSEEK;
        assert (ds.to_string_id () == "deepseek");
        assert (AiProvider.from_string_id ("deepseek") == AiProvider.DEEPSEEK);
        assert (ds.get_default_endpoint () == "https://api.deepseek.com/v1");
        assert (ds.get_default_model () == "deepseek-chat");
        assert (ds.get_api_key_help_url () == "https://platform.deepseek.com/api_keys");
        assert (ds.get_env_var_name () == "DEEPSEEK_API_KEY");
        assert (ds.requires_api_key () == true);

        // 5. Kimi
        var kimi = AiProvider.KIMI;
        assert (kimi.to_string_id () == "kimi");
        assert (AiProvider.from_string_id ("kimi") == AiProvider.KIMI);
        assert (kimi.get_default_endpoint () == "https://api.moonshot.cn/v1");
        assert (kimi.get_default_model () == "moonshot-v1-8k");
        assert (kimi.get_api_key_help_url () == "https://platform.moonshot.cn/console/api-keys");
        assert (kimi.get_env_var_name () == "MOONSHOT_API_KEY");
        assert (kimi.requires_api_key () == true);

        // 6. Qwen
        var qwen = AiProvider.QWEN;
        assert (qwen.to_string_id () == "qwen");
        assert (AiProvider.from_string_id ("qwen") == AiProvider.QWEN);
        assert (qwen.get_default_endpoint () == "https://dashscope-intl.aliyuncs.com/compatible-mode/v1");
        assert (qwen.get_default_model () == "qwen2.5-coder-32b-instruct");
        assert (qwen.get_api_key_help_url () == "https://dashscope.console.aliyun.com/apiKey");
        assert (qwen.get_env_var_name () == "DASHSCOPE_API_KEY");
        assert (qwen.requires_api_key () == true);

        // 7. Cursor API Compatibility
        var cursor = AiProvider.CURSOR;
        assert (cursor.to_string_id () == "cursor");
        assert (AiProvider.from_string_id ("cursor") == AiProvider.CURSOR);
        assert (cursor.get_default_endpoint () == "https://api.cursor.sh/v1");
        assert (cursor.get_default_model () == "cursor-small");
        assert (cursor.get_api_key_help_url () == "https://cursor.com");
        assert (cursor.get_env_var_name () == "CURSOR_API_KEY");
        assert (cursor.requires_api_key () == true);

        // 8. NVIDIA NIM
        var nvidia = AiProvider.NVIDIA_NIM;
        assert (nvidia.to_string_id () == "nvidia_nim");
        assert (AiProvider.from_string_id ("nvidia_nim") == AiProvider.NVIDIA_NIM);
        assert (AiProvider.from_string_id ("nvidia") == AiProvider.NVIDIA_NIM);
        assert (AiProvider.from_string_id ("nim") == AiProvider.NVIDIA_NIM);
        assert (nvidia.get_default_endpoint () == "https://integrate.api.nvidia.com/v1");
        assert (nvidia.get_default_model () == "meta/llama-3.3-70b-instruct");
        assert (nvidia.get_api_key_help_url () == "https://build.nvidia.com");
        assert (nvidia.get_env_var_name () == "NVIDIA_API_KEY");
        assert (nvidia.requires_api_key () == true);

        // 9. Local engines
        var ollama = AiProvider.OLLAMA;
        assert (ollama.requires_api_key () == false);
        assert (ollama.get_default_endpoint () == "http://localhost:11434/v1");

        var lm_studio = AiProvider.LM_STUDIO;
        assert (lm_studio.to_string_id () == "lm_studio");
        assert (AiProvider.from_string_id ("lm_studio") == AiProvider.LM_STUDIO);
        assert (AiProvider.from_string_id ("local_llama") == AiProvider.LM_STUDIO);
        assert (lm_studio.requires_api_key () == false);
        assert (lm_studio.get_default_endpoint () == "http://localhost:1234/v1");
        assert (lm_studio.get_default_model () == "default");
    }

    private static void test_url_normalization () {
        // Base URLs with and without trailing slashes
        assert (AiConfigManager.normalize_endpoint ("https://api.deepseek.com/v1") == "https://api.deepseek.com/v1/chat/completions");
        assert (AiConfigManager.normalize_endpoint ("https://api.deepseek.com/v1/") == "https://api.deepseek.com/v1/chat/completions");
        assert (AiConfigManager.normalize_endpoint ("https://api.deepseek.com/v1///") == "https://api.deepseek.com/v1/chat/completions");

        // Already contains endpoint
        assert (AiConfigManager.normalize_endpoint ("https://api.deepseek.com/v1/chat/completions") == "https://api.deepseek.com/v1/chat/completions");
        assert (AiConfigManager.normalize_endpoint ("https://api.deepseek.com/v1/chat/completions/") == "https://api.deepseek.com/v1/chat/completions");

        // Custom path
        assert (AiConfigManager.normalize_endpoint ("http://localhost:11434/v1", "/models") == "http://localhost:11434/v1/models");
    }

    private static void test_bytes_to_string () {
        string original = "Hello from Imladris AI with UTF-8 characters: 🌟🧠🌙⚡";
        var bytes = new GLib.Bytes (original.data);
        string converted = AiConfigManager.bytes_to_string (bytes);
        assert (converted == original);

        var empty_bytes = new GLib.Bytes (new uint8[0]);
        assert (AiConfigManager.bytes_to_string (empty_bytes) == "");
    }

    private static void test_config_manager () {
        var mgr = AiConfigManager.get_default ();

        // Test settings retrieval and modification
        mgr.set_provider_config (AiProvider.GEMINI, "https://generativelanguage.googleapis.com/v1beta/openai", "test_gemini_key", "gemini-2.0-flash");
        assert (mgr.get_api_key_for (AiProvider.GEMINI) == "test_gemini_key");
        assert (mgr.get_model_for (AiProvider.GEMINI) == "gemini-2.0-flash");
        assert (mgr.has_valid_key (AiProvider.GEMINI) == true);

        // Test Claude settings
        mgr.set_provider_config (AiProvider.CLAUDE, "https://api.anthropic.com/v1", "test_claude_key", "claude-3-5-sonnet-20241022");
        assert (mgr.get_api_key_for (AiProvider.CLAUDE) == "test_claude_key");
        assert (mgr.get_model_for (AiProvider.CLAUDE) == "claude-3-5-sonnet-20241022");
        assert (mgr.has_valid_key (AiProvider.CLAUDE) == true);

        // Test OpenAI settings
        mgr.set_provider_config (AiProvider.OPENAI, "https://api.openai.com/v1", "test_openai_key", "gpt-4o");
        assert (mgr.get_api_key_for (AiProvider.OPENAI) == "test_openai_key");
        assert (mgr.get_model_for (AiProvider.OPENAI) == "gpt-4o");
        assert (mgr.has_valid_key (AiProvider.OPENAI) == true);

        // Test Cursor settings
        mgr.set_provider_config (AiProvider.CURSOR, "https://api.cursor.sh/v1", "test_cursor_key", "cursor-small");
        assert (mgr.get_api_key_for (AiProvider.CURSOR) == "test_cursor_key");
        assert (mgr.get_model_for (AiProvider.CURSOR) == "cursor-small");
        assert (mgr.has_valid_key (AiProvider.CURSOR) == true);

        // Test NVIDIA NIM settings
        mgr.set_provider_config (AiProvider.NVIDIA_NIM, "https://integrate.api.nvidia.com/v1", "nvapi-test-key", "meta/llama-3.3-70b-instruct");
        assert (mgr.get_api_key_for (AiProvider.NVIDIA_NIM) == "nvapi-test-key");
        assert (mgr.get_model_for (AiProvider.NVIDIA_NIM) == "meta/llama-3.3-70b-instruct");
        assert (mgr.has_valid_key (AiProvider.NVIDIA_NIM) == true);

        // Test DeepSeek settings
        mgr.set_provider_config (AiProvider.DEEPSEEK, "https://api.deepseek.com/v1", "test_ds_key", "deepseek-reasoner");
        assert (mgr.get_api_key_for (AiProvider.DEEPSEEK) == "test_ds_key");
        assert (mgr.get_model_for (AiProvider.DEEPSEEK) == "deepseek-reasoner");

        // Test Kimi settings
        mgr.set_provider_config (AiProvider.KIMI, "https://api.moonshot.cn/v1", "test_kimi_key", "moonshot-v1-32k");
        assert (mgr.get_api_key_for (AiProvider.KIMI) == "test_kimi_key");
        assert (mgr.get_model_for (AiProvider.KIMI) == "moonshot-v1-32k");

        // Test Qwen settings
        mgr.set_provider_config (AiProvider.QWEN, "https://dashscope-intl.aliyuncs.com/compatible-mode/v1", "test_qwen_key", "qwen2.5-coder-32b-instruct");
        assert (mgr.get_api_key_for (AiProvider.QWEN) == "test_qwen_key");
        assert (mgr.get_model_for (AiProvider.QWEN) == "qwen2.5-coder-32b-instruct");

        // Local LM Studio and Ollama servers need no key
        assert (mgr.has_valid_key (AiProvider.LM_STUDIO) == true);
        assert (mgr.has_valid_key (AiProvider.OLLAMA) == true);
    }

    private static void test_deepseek_reasoning_parsing () {
        string mock_response = """
        {
            "id": "chatcmpl-test",
            "choices": [
                {
                    "index": 0,
                    "message": {
                        "role": "assistant",
                        "content": "Here is the ggplot code:\n```r\nggplot(mtcars, aes(wt, mpg)) + geom_point()\n```",
                        "reasoning_content": "The user wants an R plot using ggplot2. mtcars is a built-in dataset."
                    },
                    "finish_reason": "stop"
                }
            ]
        }
        """;

        var parser = new Json.Parser ();
        try {
            parser.load_from_data (mock_response, -1);
        } catch (GLib.Error e) {
            assert_not_reached ();
        }
        var root_obj = parser.get_root ().get_object ();
        var choices = root_obj.get_array_member ("choices");
        var first_choice = choices.get_object_element (0);
        var msg_obj = first_choice.get_object_member ("message");

        assert (msg_obj.has_member ("reasoning_content"));
        string reasoning = msg_obj.get_string_member ("reasoning_content");
        string content = msg_obj.get_string_member ("content");

        assert (reasoning.contains ("The user wants an R plot"));
        assert (content.contains ("ggplot(mtcars"));
    }

    private static void test_claude_messages_parsing () {
        string mock_claude_response = """
        {
            "id": "msg_01X9vy8u7K",
            "type": "message",
            "role": "assistant",
            "model": "claude-3-5-sonnet-20241022",
            "content": [
                {
                    "type": "thinking",
                    "thinking": "The user needs an R ggplot2 example using the iris dataset."
                },
                {
                    "type": "text",
                    "text": "```r\nlibrary(ggplot2)\nggplot(iris, aes(Sepal.Length, Sepal.Width, color = Species)) + geom_point()\n```"
                }
            ],
            "stop_reason": "end_turn"
        }
        """;

        var parser = new Json.Parser ();
        try {
            parser.load_from_data (mock_claude_response, -1);
        } catch (GLib.Error e) {
            assert_not_reached ();
        }

        var root_obj = parser.get_root ().get_object ();
        assert (root_obj.has_member ("content"));
        var content_arr = root_obj.get_array_member ("content");
        assert (content_arr.get_length () == 2);

        string text_content = "";
        string thinking_content = "";

        for (uint i = 0; i < content_arr.get_length (); i++) {
            var block = content_arr.get_object_element (i);
            string type_str = block.get_string_member ("type");
            if (type_str == "text") {
                text_content += block.get_string_member ("text");
            } else if (type_str == "thinking") {
                thinking_content += block.get_string_member ("thinking");
            }
        }

        assert (thinking_content.contains ("The user needs an R ggplot2 example"));
        assert (text_content.contains ("library(ggplot2)"));
    }

    private static void test_think_tag_extraction () {
        string raw_content = "<think>\nAnalyze user query: request for python pandas summary.\nCompute df.describe().\n</think>\nHere is the summary code:\n```python\nimport pandas as pd\ndf.describe()\n```";

        assert (raw_content.contains ("<think>") && raw_content.contains ("</think>"));
        int start_idx = raw_content.index_of ("<think>");
        int end_idx = raw_content.index_of ("</think>");
        string thought = raw_content.substring (start_idx + 7, end_idx - (start_idx + 7)).strip ();
        string ans = raw_content.substring (end_idx + 8).strip ();

        assert (thought.contains ("Analyze user query"));
        assert (ans.contains ("import pandas as pd"));
    }

    private static void test_env_var_fallback () {
        var mgr = AiConfigManager.get_default ();

        // Clear in-memory key for DeepSeek
        var ds_settings = mgr.get_settings_for (AiProvider.DEEPSEEK);
        string original_key = ds_settings.api_key;
        ds_settings.api_key = "";

        // Set env var
        GLib.Environment.set_variable ("DEEPSEEK_API_KEY", "sk-env-deepseek-12345", true);
        assert (mgr.get_api_key_for (AiProvider.DEEPSEEK) == "sk-env-deepseek-12345");
        assert (mgr.has_valid_key (AiProvider.DEEPSEEK) == true);

        // Restore
        ds_settings.api_key = original_key;
        GLib.Environment.unset_variable ("DEEPSEEK_API_KEY");
    }

    private static void test_app_theme () {
        assert (AppTheme.SYSTEM.to_string_id () == "system");
        assert (AppTheme.LIGHT.to_string_id () == "light");
        assert (AppTheme.DARK.to_string_id () == "dark");
        assert (AppTheme.EYE_FRIENDLY.to_string_id () == "eye-friendly");

        assert (AppTheme.from_string_id ("system") == AppTheme.SYSTEM);
        assert (AppTheme.from_string_id ("light") == AppTheme.LIGHT);
        assert (AppTheme.from_string_id ("dark") == AppTheme.DARK);
        assert (AppTheme.from_string_id ("eye-friendly") == AppTheme.EYE_FRIENDLY);
        assert (AppTheme.from_string_id ("sepia") == AppTheme.EYE_FRIENDLY);

        assert (AppTheme.SYSTEM.get_display_name () == "System Theme");
        assert (AppTheme.LIGHT.get_display_name () == "Light");
        assert (AppTheme.DARK.get_display_name () == "Dark");
        assert (AppTheme.EYE_FRIENDLY.get_display_name () == "Eye Friendly");

        var settings = SettingsManager.get_default ();
        settings.app_theme = AppTheme.EYE_FRIENDLY;
        assert (settings.app_theme == AppTheme.EYE_FRIENDLY);

        settings.app_theme = AppTheme.SYSTEM;
        assert (settings.app_theme == AppTheme.SYSTEM);
    }

    private static void test_gnome_accent_metadata () {
        // Test all 9 GNOME standard accent colors
        assert (GnomeAccent.BLUE.to_string_id () == "blue");
        assert (GnomeAccent.TEAL.to_string_id () == "teal");
        assert (GnomeAccent.GREEN.to_string_id () == "green");
        assert (GnomeAccent.YELLOW.to_string_id () == "yellow");
        assert (GnomeAccent.ORANGE.to_string_id () == "orange");
        assert (GnomeAccent.RED.to_string_id () == "red");
        assert (GnomeAccent.PINK.to_string_id () == "pink");
        assert (GnomeAccent.PURPLE.to_string_id () == "purple");
        assert (GnomeAccent.SLATE.to_string_id () == "slate");

        assert (GnomeAccent.from_string_id ("blue") == GnomeAccent.BLUE);
        assert (GnomeAccent.from_string_id ("teal") == GnomeAccent.TEAL);
        assert (GnomeAccent.from_string_id ("green") == GnomeAccent.GREEN);
        assert (GnomeAccent.from_string_id ("yellow") == GnomeAccent.YELLOW);
        assert (GnomeAccent.from_string_id ("orange") == GnomeAccent.ORANGE);
        assert (GnomeAccent.from_string_id ("red") == GnomeAccent.RED);
        assert (GnomeAccent.from_string_id ("pink") == GnomeAccent.PINK);
        assert (GnomeAccent.from_string_id ("purple") == GnomeAccent.PURPLE);
        assert (GnomeAccent.from_string_id ("slate") == GnomeAccent.SLATE);

        assert (GnomeAccent.BLUE.get_display_name () == "Blue");
        assert (GnomeAccent.TEAL.get_display_name () == "Teal");
        assert (GnomeAccent.GREEN.get_display_name () == "Green");
        assert (GnomeAccent.YELLOW.get_display_name () == "Yellow");
        assert (GnomeAccent.ORANGE.get_display_name () == "Orange");
        assert (GnomeAccent.RED.get_display_name () == "Red");
        assert (GnomeAccent.PINK.get_display_name () == "Pink");
        assert (GnomeAccent.PURPLE.get_display_name () == "Purple");
        assert (GnomeAccent.SLATE.get_display_name () == "Slate");

        assert (GnomeAccent.BLUE.get_hex_color () == "#3584e4");
        assert (GnomeAccent.TEAL.get_hex_color () == "#2190a4");
        assert (GnomeAccent.GREEN.get_hex_color () == "#3a944a");
        assert (GnomeAccent.YELLOW.get_hex_color () == "#c88800");
        assert (GnomeAccent.ORANGE.get_hex_color () == "#ed5b00");
        assert (GnomeAccent.RED.get_hex_color () == "#e62d42");
        assert (GnomeAccent.PINK.get_hex_color () == "#d56199");
        assert (GnomeAccent.PURPLE.get_hex_color () == "#9141ac");
        assert (GnomeAccent.SLATE.get_hex_color () == "#6f8396");

        var settings = SettingsManager.get_default ();
        settings.accent_color = GnomeAccent.PURPLE;
        assert (settings.accent_color == GnomeAccent.PURPLE);

        settings.accent_color = GnomeAccent.BLUE;
        assert (settings.accent_color == GnomeAccent.BLUE);
    }

    private static void test_distro_detection () {
        var distro = PlatformUtils.detect_linux_distro ();
        assert (distro != null);
        assert (distro.id.length > 0);
        assert (distro.name.length > 0);
        assert (distro.install_cmd.length > 0);
        assert (distro.install_cmd.contains ("llama"));
    }
}
