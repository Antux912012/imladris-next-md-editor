/* Word & Text Counter Plugin for Imladris */

function onload() {
    imladris.ui.addRibbonButton("calc-stats", "Word Stats", "format-text-bold-symbolic", function() {
        var text = imladris.editor.getText();
        var words = text.trim().length > 0 ? text.trim().split(/\s+/).length : 0;
        var chars = text.length;
        var lines = text.length > 0 ? text.split("\n").length : 0;
        var reading_min = Math.max(1, Math.ceil(words / 200));
        imladris.ui.showToast("📊 Stats: " + words + " words | " + chars + " chars | " + lines + " lines (~" + reading_min + " min read)");
    });
}

function onunload() {
}
