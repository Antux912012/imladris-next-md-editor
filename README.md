<p align="center">
  <img src="data/icons/hicolor/256x256/apps/io.github.Antux912012.Imladris.png" alt="Imladris Logo" width="128" height="128">
</p>

<h1 align="center">Imladris</h1>
<h3 align="center">Polyglot Scientific & Web Studio with AI & MCP</h3>

<p align="center">
  <a href="https://github.com/Antux912012/imladris-next-md-editor/releases"><img src="https://img.shields.io/github/v/release/Antux912012/imladris-next-md-editor?include_prereleases&style=flat-square&color=blue" alt="Release"></a>
  <a href="https://gitlab.gnome.org/GNOME/libadwaita"><img src="https://img.shields.io/badge/platform-Linux%20(GTK4%20%2F%20Libadwaita)-blue?style=flat-square" alt="Platform"></a>
  <a href="https://github.com/Antux912012/imladris-next-md-editor/releases/tag/v0.6.0"><img src="https://img.shields.io/badge/Flatpak-io.github.Antux912012.Imladris-blue?style=flat-square&logo=flatpak" alt="Flatpak"></a>
  <a href="https://github.com/Antux912012/imladris-next-md-editor/releases/tag/v0.6.0"><img src="https://img.shields.io/badge/Debian%20.deb-supported-red?style=flat-square&logo=debian" alt="Debian"></a>
</p>

<p align="center">
  <img src="data/screenshots/imladris-screenshot.png" alt="Imladris Polyglot Studio Screenshot" width="850">
</p>

**Imladris** is a native Linux scientific authoring studio, data science notebook IDE, and Markdown editor built with **Vala**, **GTK4**, **Libadwaita**, **GtkSourceView 5**, and **WebKitGTK 6.0**. It features reproducible **Standard vs. Sandboxed Project Engines**, the 1:1 RStudio-compatible **`.mallorn`** project format, comprehensive **ODT & ODP OpenDocument Export Pipelines**, **Dual-Mode AI Assistance** (Online OpenAI-compatible + Offline `llama.cpp` with Qwen 2.5 Coder), an embedded **Model Context Protocol (MCP)** server, and smart language auto-completion.

---

## 🚀 Supported Formats & Creation Targets

Imladris features a dedicated launch modal with 9 creation targets:

### 1. Workspace Projects (Multi-file, Stateful — `.Rmd`, `.Qmd`, `.ipynb`)
- **Standard Projects**: Direct binding to system R (`R_LIBS_USER`) and Python (`sys.path`) libraries with portability warnings.
- **Sandboxed Projects**: Isolated environments utilizing `renv` for R and `venv`/`uv` for Python, tracking pinned dependencies for zero-drift reproducibility.
- **1:1 RStudio Parity**: Automatic `.Rproj` and `.mallorn` dual-manifest synchronization.
- **Single-File Portable Archives**: Pack and unpack `.mallorn` bundles containing project state and dependencies.

### 2. Standalone Simple Files (Single-file mode, lightweight editor)
| Format | Extension | Capabilities |
| :--- | :--- | :--- |
| **Simple Markdown** | `.md` | Lightweight prose editing with live WebKit preview |
| **Simple HTML5** | `.html` | HTML5 boilerplate with interactive DOM preview |
| **R Script** | `.R` | Bound to host R interpreter with execution controls |
| **R Markdown** | `.Rmd` | YAML frontmatter, Knitr chunks, live preview |
| **Quarto Document** | `.Qmd` | Polyglot execution (`{r}`, `{python}`, `{ts}`), math & diagrams |
| **Jupyter Notebook** | `.ipynb` | Valid v4 JSON notebook schema, interactive code execution |
| **Python Script** | `.py` | Bound to Python interpreter |
| **TypeScript / OJS** | `.ts` | TypeScript compiler (`tsc`) integration and esbuild bundling |

---

## ✨ Core Feature Pillars

- **📁 Categorized Launch & Creation Dialog:** 9 distinct creation targets with live status badging (`[Sandboxed - Reproducible]` vs `[System Libraries - Non-Portable]`).
- **🛡️ Sandbox & Dependency Controller:** Automated `renv::init(bare = TRUE)` and `venv` creation, snapshotting (`renv.lock`, `requirements.txt`, `environment.yml`), and clean 1-click export for RStudio and Jupyter.
- **📦 The `.mallorn` Exchange Format:** Dual-nature Debian Control File (DCF) project marker matching RStudio's `.Rproj` parser 1:1 with namespaced `Imladris*` metadata, plus single-file `.tar.zst` and `.zip` exchange bundles.
- **📄 ODT and ODP Export Pipelines:** Full OpenDocument pipeline for `.md`, `.Rmd`, `.Qmd`, and `.ipynb` documents and slide presentations via `quarto`, `Rscript`, `pandoc`, and headless LibreOffice (`soffice`), backed by a built-in OASIS XML container generator.
- **🤖 Dual-Engine AI Assistance:**
  - **Online:** Connects to any OpenAI-compatible endpoint (OpenAI, DeepSeek, OpenRouter, Groq, vLLM).
  - **Offline (`llama.cpp` / Ollama):** Runs locally via `llama-server` sidecar or Ollama with one-click downloader for **Qwen 2.5 Coder** models.
- **⚡ Smart Language Auto-Completion:** GtkSourceView 5 completion subsystem across all supported scientific and prose languages.
- **🔌 Embedded Model Context Protocol (MCP) Server:** Standard JSON-RPC MCP server (`imladris --mcp-server`) exposing editor tools.
- **🎭 Dynamic UI Morphing:** Distraction-free Apostrophe mode and 4-quadrant RStudio workbench mode.
- **🛡️ Atomic Crash Recovery:** Non-blocking background shadow buffers persisting unsaved edits to `~/.cache/imladris/recovery/`.
- **🪟 Multi-Mode Split View Engine:** Flexible instant toggling between Editor Only, Preview Only, Vertical Split (Side-by-Side), and Horizontal Split (Top-and-Bottom).
- **🌐 Embedded WebKitGTK 6.0 Live Preview:** Real-time HTML5, CSS, and Reveal.js rendering directly inside an expandable right-hand split pane.
- **⚡ Asynchronous Execution Engine:** Non-blocking background execution of `quarto`, `Rscript`, `python3`, `tsc`, and `deno` via `GLib.Subprocess`.
- **🎛 Dynamic 9-Tab Ribbon Deck:** Modern Libadwaita ribbon categorized into *Home*, *Insert*, *Computation*, *Web & Publish*, *Page Layout*, *References*, *Review*, *View*, and *Section*.
- **🎨 Native GNOME HIG & Libadwaita:** Adaptive toolbar view, multi-tab document tabs (`Adw.TabView`), and dark titlebar styling.

---

## 📦 Installation & Downloads

Official releases are distributed exclusively as **Debian packages (`.deb`)** and **Flatpak bundles (`.flatpak`)**. AppImage builds are intentionally excluded.

### Option 1: Debian / Ubuntu / Pop!_OS (`.deb`)
Download the latest `.deb` package from the [v0.6.0 Release](https://github.com/Antux912012/imladris-next-md-editor/releases/tag/v0.6.0):

```bash
# Download and install
wget https://github.com/Antux912012/imladris-next-md-editor/releases/download/v0.6.0/imladris_0.6.0_amd64.deb
sudo dpkg -i imladris_0.6.0_amd64.deb

# Fix missing dependencies if needed
sudo apt-get install -f
```

### Option 2: Flatpak (Any Linux distribution)
Download the standalone single-file bundle (`io.github.Antux912012.Imladris`):

```bash
wget https://github.com/Antux912012/imladris-next-md-editor/releases/download/v0.6.0/io.github.Antux912012.Imladris.flatpak
flatpak install --user io.github.Antux912012.Imladris.flatpak
flatpak run io.github.Antux912012.Imladris
```

---

## 🔌 Running as an MCP Server

Imladris can run headlessly as an MCP server over stdio for external AI agents (e.g. Claude Desktop, Antigravity):

```bash
imladris --mcp-server
```

Example configuration for Claude Desktop (`claude_desktop_config.json`):
```json
{
  "mcpServers": {
    "imladris": {
      "command": "imladris",
      "args": ["--mcp-server"]
    }
  }
}
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
- `libsoup-3.0` (>= 3.0)
- `json-glib-1.0` (>= 1.0)
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
