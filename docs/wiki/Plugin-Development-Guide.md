# Plugin Development Guide

Imladris features an Obsidian-inspired third-party extension system that allows community developers and researchers to build lightweight add-ons using simple JavaScript. Extensions execute within isolated **JavaScriptCore (`JSC.Context`)** virtual machines provided by `javascriptcoregtk-6.0`, ensuring that a bug or crash in an extension never brings down the main IDE thread.

> [!NOTE]
> All plugin UI elements must be built declaratively through the `imladris.ui` host bridge and use **Papirus** symbolic icon names. This ensures extensions automatically respect GNOME Libadwaita styling, accent colors, and Light/Dark theme switching.

---

## 1. Quickstart: Build an Extension in 5 Minutes

### Step A: Create the Plugin Folder
Plugins live in your user data directory:
```bash
mkdir -p ~/.local/share/imladris/plugins/my-stats-plugin
cd ~/.local/share/imladris/plugins/my-stats-plugin
```

### Step B: Create `manifest.json`
Every extension requires a `manifest.json` file declaring its identity, license, and requested capabilities:

```json
{
  "id": "my-stats-plugin",
  "name": "Text Statistics & Metrics",
  "version": "1.0.0",
  "author": "Dr. Jane Doe",
  "description": "Calculates word, character, and line counts with reading time estimates.",
  "license": "GPL-3.0-or-later",
  "icon": "format-text-bold-symbolic",
  "permissions": [
    "editor"
  ]
}
```

#### Manifest Field Breakdown:
- **`id`** *(Required, string)*: Unique identifier slug (`[a-z0-9\-]`).
- **`name`** *(Required, string)*: Human-readable name displayed in Preferences and tooltips.
- **`version`** *(Required, string)*: SemVer version string (e.g., `1.0.0`).
- **`author`** *(Optional, string)*: Author or team name.
- **`description`** *(Optional, string)*: Description shown in the Preferences extension expander row.
- **`license`** *(Required, string)*: License identifier (e.g. `GPL-3.0-or-later`, `MIT`, `Apache-2.0`).
- **`icon`** *(Optional, string)*: Standard Papirus symbolic icon name (e.g., `format-text-bold-symbolic`, `edit-find-symbolic`, `view-grid-symbolic`).
- **`permissions`** *(Optional, array)*: Requested access tokens:
  - `"editor"`: Read and modify active editor buffer.
  - `"repl_r"`: Dispatch code to the persistent R console.
  - `"repl_python"`: Dispatch code to the persistent Python console.
  - `"elrond_ai"`: Send queries to the local or configured Elrond AI engine.
  - `"export"`: Trigger document export pipelines.

---

### Step C: Write `main.js`
Create `main.js` in the same directory:

```javascript
/* Text Statistics & Metrics Extension */

function onload() {
    // 1. Add an action button with a Papirus symbolic icon into the Extensions ribbon
    imladris.ui.addRibbonButton(
        "calc-stats",
        "Text Stats",
        "format-text-bold-symbolic",
        function() {
            // Read active document text
            const text = imladris.editor.getText();
            
            // Calculate metrics
            const words = text.trim().length > 0 ? text.trim().split(/\s+/).length : 0;
            const chars = text.length;
            const lines = text.length > 0 ? text.split("\n").length : 0;
            const readingMin = Math.max(1, Math.ceil(words / 200));

            // Show a native Adw.Toast notification
            imladris.ui.showToast(
                `📊 Stats: ${words} words | ${chars} characters | ${lines} lines (~${readingMin} min read)`
            );

            // Optionally append an updated comment at cursor
            imladris.editor.insertAtCursor(`\n<!-- Word count verified: ${words} words -->\n`);
        }
    );

    imladris.ui.showToast("Text Statistics extension loaded!");
}

function onunload() {
    // Cleanup tasks if necessary. Dynamic ribbon buttons are automatically unmounted.
    imladris.ui.showToast("Text Statistics extension unloaded.");
}
```

---

## 2. Testing and Activating Your Plugin

1. Launch Imladris or open **Preferences (`Ctrl+,`) → Extensions**.
2. Locate **"Text Statistics & Metrics"** under **Installed Plugins**.
3. Toggle the switch to **Active**.
4. Switch to the **Home** tab in the Ribbon. You will see a new **"Text Stats"** button with a symbolic icon in the **Extensions** group.
5. Click it to verify that metrics appear in an `Adw.Toast` at the bottom of the window!

---

## 3. Packaging into `.implugin` for Distribution

To distribute your extension to collaborators:
1. Ensure your directory contains `manifest.json` and `main.js`.
2. Package the files into a `.zip` archive named `<plugin-id>.implugin`:
   ```bash
   cd ~/.local/share/imladris/plugins/my-stats-plugin
   zip -r ../my-stats-plugin.implugin manifest.json main.js
   ```
3. A user can install your `.implugin` with one click:
   - Go to **Preferences → Extensions**.
   - Click **"Import Plugin…"**.
   - Select `my-stats-plugin.implugin`.
   - Imladris displays a security consent modal showing the plugin author, license, and requested permissions (`Editor Access`).
   - Clicking **"Install & Enable"** extracts the bundle into user storage and enables it instantly.
