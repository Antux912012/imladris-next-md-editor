# Plugin API Reference

When your plugin's `main.js` is evaluated inside its isolated `JSC.Context` virtual machine, Imladris automatically exposes the global host namespace object **`imladris`**. 

---

## 1. `imladris.ui` (User Interface Bridge)

### `imladris.ui.showToast(message)`
Displays a native non-blocking Libadwaita toast notification at the bottom of the main window.
* **Parameters**: `message` (string) — The notification text.
* **Example**:
  ```javascript
  imladris.ui.showToast("Export completed successfully!");
  ```

### `imladris.ui.addRibbonButton(options)`
Registers a custom action button in the Ribbon bar.
* **Parameters**: `options` (Object) containing:
  * `id` (string): Unique button identifier.
  * `label` (string): Button display text.
  * `icon` (string): Papirus symbolic icon name (e.g., `"applications-science-symbolic"`).
  * `onClick` (Function): Callback invoked when the button is clicked.
* **Example**:
  ```javascript
  imladris.ui.addRibbonButton({
      id: "my-custom-btn",
      label: "Run Lint",
      icon: "preferences-system-symbolic",
      onClick: () => { console.log("Linting clicked"); }
  });
  ```

### `imladris.ui.openWebDialog(options)`
Opens a hardware-accelerated WebKitGTK modal dialog (`Adw.Dialog`) rendering custom HTML5 Canvas or WebGL content.
* **Parameters**: `options` (Object) containing:
  * `title` (string): Dialog window title.
  * `html` (string): HTML content string to load.
  * `width` (number, optional): Preferred window width (default `950`).
  * `height` (number, optional): Preferred window height (default `700`).
* **IPC Messaging**: JavaScript inside the webview can communicate with the host via:
  ```javascript
  window.webkit.messageHandlers.imladrisHost.postMessage({
      action: "open_file",
      path: "notes/chapter1.md"
  });
  ```

---

## 2. `imladris.editor` (Source Editor Bridge)

> [!NOTE]
> Requires the `"editor"` permission declared in your `manifest.json`.

### `imladris.editor.getText()`
Returns the full text content of the active editor buffer.
* **Returns**: `string`

### `imladris.editor.getSelectedText()`
Returns the currently highlighted text selection in the editor.
* **Returns**: `string` (or empty string if no selection).

### `imladris.editor.insertAtCursor(text)`
Inserts text directly at the current cursor position in the active document.
* **Parameters**: `text` (string) — The string to insert.
* **Example**:
  ```javascript
  imladris.editor.insertAtCursor("# New Section Heading\n");
  ```

---

## 3. `imladris.repl` (R & Python Console Bridge)

> [!NOTE]
> Requires `"repl_r"` or `"repl_python"` permissions declared in your `manifest.json`.

### `imladris.repl.runR(code)`
Dispatches R code directly to the persistent interactive R session.
* **Parameters**: `code` (string) — Valid R expression or script.
* **Example**:
  ```javascript
  imladris.repl.runR("summary(mtcars); cat('Evaluated via plugin\\n')");
  ```

### `imladris.repl.runPython(code)`
Dispatches Python code directly to the persistent interactive Python / IPython session.
* **Parameters**: `code` (string) — Valid Python statement or script.
* **Example**:
  ```javascript
  imladris.repl.runPython("import pandas as pd; print(pd.__version__)");
  ```

---

## 4. `imladris.elrond` (Local AI Assistant Bridge)

> [!NOTE]
> Requires the `"elrond_ai"` permission declared in your `manifest.json`.

### `imladris.elrond.ask(prompt)`
Queries the local Vulkan/CPU **Elrond Assistance (AI)** engine using the active document narrative and dataframe context.
* **Parameters**: `prompt` (string) — Custom instructions or questions for Elrond.
* **Returns**: `Promise<string>` — The generated response from the local GGUF model.
* **Example**:
  ```javascript
  // Async usage with Elrond
  async function suggestPlot() {
      const advice = await imladris.elrond.ask("Suggest a ggplot2 command for these variables.");
      imladris.editor.insertAtCursor(advice);
  }
  suggestPlot();
  ```

---

## 5. `imladris.workspace` (Project & Filesystem Bridge)

> [!IMPORTANT]
> Requires the `"workspace"` permission declared in your `manifest.json`.

### `imladris.workspace.listFiles(pattern)`
Recursively enumerates all matching files within the currently active workspace directory.
* **Parameters**: `pattern` *(string, optional)* — Glob pattern (e.g., `"*.md"`, `"*.qmd"`). Default is `"*.md"`.
* **Returns**: `string[]` — Array of relative file paths.

### `imladris.workspace.readFile(relativePath)`
Reads the complete plain text contents of a file within the project directory.
* **Parameters**: `relativePath` *(string)* — Relative path to the project file. Path traversal (`..`) is strictly blocked.
* **Returns**: `string` — File contents.

### `imladris.workspace.openFile(relativePath, line)`
Opens the target project file in an editor tab in Imladris.
* **Parameters**:
  * `relativePath` *(string)* — Relative path to the project file.
  * `line` *(number, optional)* — Line number to scroll to (default `1`).

### `imladris.workspace.getRoot()`
Returns the absolute path to the active workspace project root folder.
* **Returns**: `string`

### `imladris.workspace.getActiveFile()`
Returns the path to the currently active open document.
* **Returns**: `string`

---

## 6. `imladris.plugin` (Asset Bridge)

### `imladris.plugin.readAsset(relativePath)`
Reads an asset file bundled inside the plugin's own directory (e.g. templates, CSS, or JSON schemas).
* **Parameters**: `relativePath` *(string)* — Relative asset path within the plugin folder.
* **Returns**: `string` — File contents.
