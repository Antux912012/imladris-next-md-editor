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
