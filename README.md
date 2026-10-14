# Imladris 🌿

Native Linux Markdown Editor built with **Vala**, **GTK4**, **Libadwaita**, **GtkSourceView 5**, and **WebKitGTK**.

## Features

- **Dual-Engine Architecture:** High-performance source editing via `GtkSourceView 5` paired with pixel-perfect live HTML rendering via `WebKitGTK 6.0`.
- **Asynchronous Markdown Pipeline:** Powered by `libcmark` running in background worker threads to keep the UI thread completely responsive.
- **Libadwaita Modern Layout:** GNOME HIG-compliant `Adw.ToolbarView`, `Adw.TabBar`, `Adw.TabView`, and `Adw.ViewSwitcher` (Editor, Split, and Preview modes).
- **Contextual Formatting Popover:** Floating formatting toolbar on text selection for instant Markdown formatting (Bold, Italic, Strikethrough, Code, Link, Heading).
- **Scroll & Cursor Alignment:** Live synchronization between editor line position and rendered HTML elements using CommonMark sourcepos attributes and smooth DOM scrolling.
- **GResource Packaging:** All stylesheets, language specifications, and assets bundled into `org.gnome.Imladris.gresource`.

## Dependencies

- `valac` (>= 0.56)
- `meson` (>= 0.60)
- `ninja`
- `gtk4` (>= 4.10)
- `libadwaita-1` (>= 1.4)
- `gtksourceview-5` (>= 5.6)
- `webkitgtk-6.0` (>= 2.40)
- `gee-0.8`
- `libcmark` (automatically retrieved via subproject wrap fallback if missing from system)

## Building & Running

### Using Meson directly

```bash
meson setup build
ninja -C build
./build/src/imladris
```

### Using the GNOME SDK (Flatpak)

```bash
flatpak run --filesystem=host --command=bash org.gnome.Sdk//50 -c "meson setup build && ninja -C build && ./build/src/imladris"
```

## Keyboard Shortcuts

| Shortcut | Action |
| :--- | :--- |
| `Ctrl+N` | New Document Tab |
| `Ctrl+O` | Open File Dialog |
| `Ctrl+S` | Save Document |
| `Ctrl+Shift+S` | Save Document As... |
| `Ctrl+W` | Close Current Tab |
| `Ctrl+B` | Bold Selection (`**text**`) |
| `Ctrl+I` | Italic Selection (`*text*`) |
| `Ctrl+Q` | Quit Application |
