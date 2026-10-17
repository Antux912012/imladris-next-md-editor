# Imladris 🌿
### Polyglot Scientific & Web Studio for Linux

[![Release](https://img.shields.io/github/v/release/Antux912012/imladris-next-md-editor?include_prereleases&style=flat-square&color=blue)](https://github.com/Antux912012/imladris-next-md-editor/releases)
[![Platform](https://img.shields.io/badge/platform-Linux%20(GTK4%20%2F%20Libadwaita)-blue?style=flat-square)](https://gitlab.gnome.org/GNOME/libadwaita)
[![Flatpak](https://img.shields.io/badge/Flatpak-supported-blue?style=flat-square&logo=flatpak)](https://github.com/Antux912012/imladris-next-md-editor/releases/tag/v0.3.0)
[![Debian](https://img.shields.io/badge/Debian%20.deb-supported-red?style=flat-square&logo=debian)](https://github.com/Antux912012/imladris-next-md-editor/releases/tag/v0.3.0)

**Imladris** is a native Linux polyglot document studio and Markdown editor built with **Vala**, **GTK4**, **Libadwaita**, **GtkSourceView 5**, and **WebKitGTK 6.0**. It combines high-performance source editing with live interactive rendering and asynchronous execution for scientific computing, web development, and technical writing.

---

## 🚀 Supported Formats

| Format | Extension | Capabilities |
| :--- | :--- | :--- |
| **Quarto** | `.qmd` | YAML frontmatter, executable `{r}`, `{python}`, `{ts}` code chunks, PDF/HTML render pipeline |
| **R Markdown** | `.Rmd` | Knitr syntax, inline code execution via `Rscript`, live HTML preview |
| **Jupyter Notebooks** | `.ipynb` | JSON structure awareness, chunk controls, kernel execution |
| **TypeScript / OJS** | `.ts` | Syntax highlighting, TypeScript compiler (`tsc`) integration, esbuild bundling |
| **HTML5** | `.html` | Full HTML5 boilerplate generation, live interactive WebKit preview |
| **Markdown** | `.md` | Rich text formatting, LaTeX math (`$$`), Mermaid diagrams, footnotes, citations |

---

## ✨ Features

- **🌐 Embedded WebKitGTK 6.0 Live Preview:** Real-time HTML5, CSS, and Reveal.js rendering directly inside an expandable right-hand split pane.
- **⚡ Asynchronous Execution Engine:** Non-blocking background execution of `quarto`, `Rscript`, `python3`, `tsc`, and `deno` via `GLib.Subprocess` with live terminal streaming.
- **🎛 Dynamic 9-Tab Ribbon Deck:** Modern Libadwaita ribbon categorized into:
  - **Home:** Font family/size, bold/italic/underline, color palette, style presets (H1–H3), find & replace.
  - **Insert:** 6×6 interactive Markdown table grid picker, image/figure links, LaTeX math, citations, cross-references.
  - **Computation:** Code chunk insertion (`{r}`, `{python}`, `{ts}`), chunk execution, chunk options matrix (`echo`, `eval`, `warning`, `cache`).
  - **Web & Publish:** Quarto HTML/PDF rendering, TypeScript compilation, Reveal.js export, and live WebKit toggle.
  - **Page Layout:** Document margins, orientation, size, and columns.
  - **References:** Table of contents generator, footnotes, BibTeX citations.
  - **Review:** Word count, spell checking, and annotations.
  - **View:** Source editor / visual mode toggling, line numbers, word wrap, and zoom scale.
  - **Section:** YAML frontmatter inspector and section splitting.
- **🎨 Native GNOME HIG & Libadwaita:** Adaptive toolbar view, multi-tab document tabs (`Adw.TabView`), and dark titlebar styling.

---

## 📦 Installation & Downloads

Official releases are distributed exclusively as **Debian packages (`.deb`)** and **Flatpak bundles (`.flatpak`)**. AppImage builds are intentionally excluded.

### Option 1: Debian / Ubuntu / Pop!_OS (`.deb`)
Download the latest `.deb` package from the [v0.3.0 Release](https://github.com/Antux912012/imladris-next-md-editor/releases/tag/v0.3.0):

```bash
# Download and install
wget https://github.com/Antux912012/imladris-next-md-editor/releases/download/v0.3.0/imladris_0.3.0_amd64.deb
sudo dpkg -i imladris_0.3.0_amd64.deb

# Fix missing dependencies if needed
sudo apt-get install -f
```

### Option 2: Flatpak (Any Linux distribution)
Download the standalone single-file bundle:

```bash
wget https://github.com/Antux912012/imladris-next-md-editor/releases/download/v0.3.0/Imladris.flatpak
flatpak install --user Imladris.flatpak
flatpak run org.gnome.Imladris
```

---

## 🛠 Building From Source

### Dependencies
- `valac` (>= 0.56)
- `meson` (>= 0.60)
- `ninja`
- `gtk4` (>= 4.12)
- `libadwaita-1` (>= 1.5)
- `gtksourceview-5` (>= 5.10)
- `webkitgtk-6.0` (>= 2.40)
- `glib-2.0` (>= 2.76)

### Building via GNOME SDK (Recommended)
```bash
flatpak run --filesystem=host --command=bash org.gnome.Sdk//50 -c \
  "meson setup builddir && ninja -C builddir && ./builddir/imladris"
```

### Generating `.deb` and Flatpak Packages
Use the automated package builder:
```bash
./build-packages.sh
```

---

## ⌨ Keyboard Shortcuts

| Shortcut | Action |
| :--- | :--- |
| `Ctrl+N` | New Quarto Document (`.qmd`) |
| `Ctrl+O` | Open File |
| `Ctrl+S` | Save Document |
| `Ctrl+Q` | Quit Imladris |

---

## 📄 License
This project is licensed under the **GNU General Public License v3.0 or later** (GPL-3.0-or-later).
