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
        GLib.Test.add_func ("/ai/env_var_fallback", test_env_var_fallback);

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

        // 2. DeepSeek
        var ds = AiProvider.DEEPSEEK;
        assert (ds.to_string_id () == "deepseek");
        assert (AiProvider.from_string_id ("deepseek") == AiProvider.DEEPSEEK);
        assert (ds.get_default_endpoint () == "https://api.deepseek.com/v1");
        assert (ds.get_default_model () == "deepseek-chat");
        assert (ds.get_api_key_help_url () == "https://platform.deepseek.com/api_keys");
        assert (ds.get_env_var_name () == "DEEPSEEK_API_KEY");
        assert (ds.requires_api_key () == true);

        // 3. Kimi
        var kimi = AiProvider.KIMI;
        assert (kimi.to_string_id () == "kimi");
        assert (AiProvider.from_string_id ("kimi") == AiProvider.KIMI);
        assert (kimi.get_default_endpoint () == "https://api.moonshot.cn/v1");
        assert (kimi.get_default_model () == "moonshot-v1-8k");
        assert (kimi.get_api_key_help_url () == "https://platform.moonshot.cn/console/api-keys");
        assert (kimi.get_env_var_name () == "MOONSHOT_API_KEY");
        assert (kimi.requires_api_key () == true);

        // 4. Qwen
        var qwen = AiProvider.QWEN;
        assert (qwen.to_string_id () == "qwen");
        assert (AiProvider.from_string_id ("qwen") == AiProvider.QWEN);
        assert (qwen.get_default_endpoint () == "https://dashscope-intl.aliyuncs.com/compatible-mode/v1");
        assert (qwen.get_default_model () == "qwen2.5-coder-32b-instruct");
        assert (qwen.get_api_key_help_url () == "https://dashscope.console.aliyun.com/apiKey");
        assert (qwen.get_env_var_name () == "DASHSCOPE_API_KEY");
        assert (qwen.requires_api_key () == true);

        // 5. Local engines
        var ollama = AiProvider.OLLAMA;
        assert (ollama.requires_api_key () == false);
        assert (ollama.get_default_endpoint () == "http://localhost:11434/v1");

        var llama = AiProvider.LOCAL_LLAMA;
        assert (llama.requires_api_key () == false);
        assert (llama.get_default_endpoint () == "http://127.0.0.1:8080/v1");
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

        // Local llama server needs no key
        assert (mgr.has_valid_key (AiProvider.LOCAL_LLAMA) == true);
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
}
