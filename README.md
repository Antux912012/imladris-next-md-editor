<p align="center">
  <img src="data/icons/hicolor/256x256/apps/io.github.Antux912012.Imladris.png" alt="Imladris Logo" width="128" height="128">
</p>

<h1 align="center">Imladris</h1>
<h3 align="center">Scientific Authoring Studio, Data Science Notebook IDE & Polyglot Markdown Workbench</h3>

<p align="center">
  <a href="https://github.com/Antux912012/imladris-next-md-editor/releases"><img src="https://img.shields.io/github/v/release/Antux912012/imladris-next-md-editor?include_prereleases&style=flat-square&color=blue" alt="Release"></a>
  <a href="https://gitlab.gnome.org/GNOME/libadwaita"><img src="https://img.shields.io/badge/platform-Linux%20(GTK4%20%2F%20Libadwaita)-blue?style=flat-square" alt="Platform"></a>
  <a href="https://github.com/Antux912012/imladris-next-md-editor/releases/tag/v0.7.0"><img src="https://img.shields.io/badge/Fedora%20.rpm-v0.7.0-blue?style=flat-square&logo=fedora" alt="Fedora RPM"></a>
  <a href="https://github.com/Antux912012/imladris-next-md-editor/releases/tag/v0.7.0"><img src="https://img.shields.io/badge/Flatpak-io.github.Antux912012.Imladris-blue?style=flat-square&logo=flatpak" alt="Flatpak"></a>
  <a href="https://github.com/Antux912012/imladris-next-md-editor/releases/tag/v0.7.0"><img src="https://img.shields.io/badge/Debian%20.deb-v0.7.0-red?style=flat-square&logo=debian" alt="Debian"></a>
</p>

<p align="center">
  <img src="data/screenshots/imladris-screenshot.png" alt="Imladris Polyglot Studio Screenshot" width="850">
</p>

**Imladris** is an advanced native Linux scientific authoring studio, data science notebook IDE, and polyglot document workbench engineered in **Vala**, **GTK4**, **Libadwaita (>= 1.5)**, **GtkSourceView 5**, **WebKitGTK 6.0**, **libsoup-3.0**, and **json-glib-1.0**.

Designed for researchers, data scientists, statisticians, and technical authors, Imladris unifies the distraction-free flow of GNOME Apostrophe with the interactive analytical power of RStudio and Jupyter Notebooks into a seamless, high-performance desktop experience.

---

## 🏛 The 11 Core Architectural Pillars

Imladris is architected around 11 core functional pillars:

### Pillar 1: Clean Creation Pop-up Modal
When opening the **New / Launch** modal dialog (`Adw.Dialog`), options are presented with clean, unencumbered labels:
- **Create a Project** (Supports `.Rmd`, `.Qmd`, or `.ipynb`)
- **Create a Sandboxed project** (Supports `.Rmd`, `.Qmd`, or `.ipynb` with isolated dependencies)
- **Create a simple .md**
- **Create a simple .html**
- **Create a R script file**
- **Create a .Rmd**
- **Create a .Qmd**
- **Create a .ipynb**
- **Create a Python script**

### Pillar 2: Context-Aware Ribbon State Machine
The top ribbon dynamically adapts its `visible` and `sensitive/enabled` states depending on the active document format and project mode:
- **Simple `.md`**: Formatting tools, Live Preview toggle, Export (`.html`, `.pdf`, `.odt`, `.odp`). Computational buttons (Run Chunk, Run All, Kernel controls, Package Installer) are cleanly hidden.
- **Simple `.html`**: HTML tag helpers, Live DOM WebKit preview, browser preview. Kernel and Pandoc exports hidden.
- **Standalone `.R` / `.py` scripts**: Script execution controls (Run Line / Selection, Source File, Interrupt, Restart Kernel). Chunk insertion hidden.
- **Notebooks (`.Rmd`, `.Qmd`, `.ipynb`)**: Full computational suite (Insert Chunks, Run Active Chunk, Run All Chunks, Run Above, Run Below, Package Installer, Environment Snapshot/Restore, Export to RStudio/Jupyter, ODT/ODP pipelines).

### Pillar 3: RStudio-Style Package Installer (CRAN & PyPI)
A dedicated `Adw.Dialog` modal (`PackageInstallerModal`) mirroring RStudio's package management workflow:
- **Live Index Caching**: Asynchronously fetches and caches CRAN (`src/contrib/PACKAGES`) and PyPI (`/simple/` JSON API) indices using `Soup.Session` and `Json.Parser`.
- **Multi-Package Autocomplete**: Debounced autocompletion matching comma- or space-separated lists (e.g. `tidyverse, ggplot2, DESeq2`).
- **Smart Target Routing**: Automatically routes package installations to the appropriate destination:
  - *Standard Projects*: System global library (`install.packages()` for R, `python3 -m pip install` for Python).
  - *Sandboxed Projects*: Project-isolated library (`renv::install()` with automatic lockfile snapshot for R, `.venv/bin/python -m pip install` with automatic `requirements.txt` freeze for Python).

### Pillar 4: Persistent Interactive R & Python REPL Subprocess Bridges
Imladris maintains long-lived, bidirectional background subprocesses (`Imladris.Execution.ReplBridge`) for both R (`R --no-save --no-restore --interactive`) and Python (`python3 -u -i`):
- Persistent variables, imported modules, dataframes, and custom functions stay in memory across individual chunk runs.
- Non-blocking asynchronous I/O loops capture stdout and stderr in real time.
- Integrated interrupt support sends `SIGINT` directly to the active process without crashing the session.

### Pillar 5: Files Quadrant & Automatic Root Working Directory (`pwd`)
Enforces strict working directory synchronicity across the workbench:
- When a project is loaded, `PersistentSessionManager` updates process `pwd`, executes `setwd("<project_root>")` in the persistent R session, and executes `os.chdir("<project_root>")` in the persistent Python session.
- Subprocesses spawned via `GLib.SubprocessLauncher` strictly enforce `launcher.set_cwd(project_root)`.
- Quadrant 4 (Files tab) roots directly to `project_root`, providing breadcrumb navigation and click-to-open file management.
- Integrated terminal synchronizes working directory automatically.

### Pillar 6: Project Engine (Standard vs. Sandboxed)
- **Standard Projects (`ProjectType.STANDARD`)**:
  - Bound to host system global R and Python libraries.
  - Displays persistent status badge: `[System Libraries - Non-Portable]`.
  - Prompts with an `Adw.AlertDialog` warning when exporting or sharing: *"This project relies on system libraries and may fail to run on other machines if required packages are missing."*
- **Sandboxed Projects (`ProjectType.SANDBOXED`)**:
  - Isolated dependencies: Initializes `renv` (`.Rprofile`, `renv/activate.R`, `renv.lock`) for R and `.venv` (`requirements.txt`, local Jupyter kernelspec) for Python.
  - Displays persistent status badge: `[Sandboxed - Reproducible]`.
  - One-click snapshot and restore via `renv::snapshot()`, `renv::restore()`, and `pip freeze`.

### Pillar 7: Sandboxed Export to RStudio & Jupyter Notebook
- **Export to RStudio (`SandboxController.export_to_rstudio`)**:
  - Automatically snapshots `renv.lock`.
  - Generates valid `<project_name>.Rproj`, `.Rprofile`, and `renv/activate.R`.
  - Opening the exported folder in RStudio automatically triggers `renv::restore()`.
- **Export to Jupyter (`SandboxController.export_to_jupyter`)**:
  - Exports `.ipynb` with pinned `requirements.txt` and Conda-compatible `environment.yml`.
  - Generates executable `setup_environment.sh` bootstrapping virtual environment and local kernel registration.

### Pillar 8: The `.mallorn` Exchange Format
A dual-nature exchange specification for scientific computing workspaces:
- **1:1 RStudio DCF Syntax**: Human-readable Debian Control File format mirroring RStudio's `.Rproj` file with namespaced `Imladris*` metadata headers.
- **Dual-Manifest Sync**: Synchronizes `<project_name>.mallorn` and `<project_name>.Rproj` simultaneously so projects open natively in both Imladris and RStudio.
- **Portable Single-File Bundles**: Pack and unpack `.mallorn` archives (`.tar.zst` or `.zip`), automatically excluding heavy binaries while preserving lockfiles.

### Pillar 9: OpenDocument Text (ODT) & Presentation (ODP) Export Pipelines
Headless export service for `.md`, `.Rmd`, `.Qmd`, and `.ipynb` documents:
- **ODT Pipeline**: Dispatches through Quarto (`quarto render --to odt`), RMarkdown (`rmarkdown::render(output_format='odt_document')`), or Pandoc (`pandoc -t odt`), with automatic fallback to built-in OASIS OpenDocument XML container generator.
- **ODP Pipeline**: Converts via Quarto/Pandoc to intermediate PPTX decks, then executes headless LibreOffice (`soffice --headless --convert-to odp`), with fallback to native OASIS presentation packager.

### Pillar 10: Lightweight Standalone Mode vs Full Notebook Mode
Dynamic layout engine adapting to user workflow:
- **Fast-Path Apostrophe Mode**: Simple `.md` and `.html` files launch instantly in a clean, distraction-free writing view bypassing heavyweight scientific runtimes.
- **4-Quadrant RStudio Workbench**: Computational projects launch into a 4-quadrant layout:
  - *Quadrant 1 (Top-Left)*: Source editor with syntax highlighting and inline output anchors.
  - *Quadrant 2 (Top-Right)*: Environment variables inspector, document outline, citations viewer, and history.
  - *Quadrant 3 (Bottom-Left)*: Interactive R & Python console and embedded shell terminal.
  - *Quadrant 4 (Bottom-Right)*: Files browser, high-DPI plot viewer, package manager, and help docs.

### Pillar 11: Inline Document Code Chunk Execution & Output Cards
Rich inline computational feedback directly inside the document editor:
- **Chunk Parser**: Scans document buffers for `{r}`, `python`, and `bash` chunk blocks with YAML options (`#| echo: true`).
- **Capture Harnesses**:
  - *R Chunks*: Automatically redirects graphics to high-DPI PNG devices (`png(res=150)`) and intercepts plot generation.
  - *Python Chunks*: Safely executes base64-encoded multiline code blocks, captures `matplotlib.pyplot` figures, and extracts stdout/stderr cleanly.
- **Inline Output Cards (`InlineChunkOutputWidget`)**: Rendered directly below executed code chunks inside `GtkSource.View` child anchors, displaying expandable stdout/stderr logs and zoomable plot previews.

---

## 🚀 Supported Formats & Creation Targets

| Target | Primary Format | Default Mode | Dependency Model |
| :--- | :--- | :--- | :--- |
| **Workspace Project** | `.qmd`, `.Rmd`, `.ipynb` | 4-Quadrant Workbench | System Libraries (Non-Portable) |
| **Sandboxed Project** | `.qmd`, `.Rmd`, `.ipynb` | 4-Quadrant Workbench | Isolated `renv` & `.venv` (Reproducible) |
| **Simple Markdown** | `.md` | Apostrophe Writer | Lightweight / No Kernels |
| **Simple HTML5** | `.html` | Apostrophe Writer + DOM | Lightweight / WebKit Preview |
| **R Script** | `.R` | 4-Quadrant Workbench | Host R Interpreter |
| **R Markdown** | `.Rmd` | 4-Quadrant Workbench | R / Knitr / renv |
| **Quarto Document** | `.Qmd` | 4-Quadrant Workbench | Polyglot (R + Python + JS) |
| **Jupyter Notebook** | `.ipynb` | 4-Quadrant Workbench | Python / IPython Kernel |
| **Python Script** | `.py` | 4-Quadrant Workbench | Host Python 3 |

---

## 📦 Installation & Downloads

Official releases are provided for **Fedora / Red Hat (`.rpm`)**, **Debian / Ubuntu (`.deb`)**, and universal **Flatpak (`.flatpak`)**.

### Option 1: Fedora / RHEL / CentOS Stream (`.rpm`)
Download the latest RPM packages from the [v0.7.0 Release](https://github.com/Antux912012/imladris-next-md-editor/releases/tag/v0.7.0):

```bash
# Download and install binary RPM
wget https://github.com/Antux912012/imladris-next-md-editor/releases/download/v0.7.0/imladris-0.7.0-1.fc44.x86_64.rpm
sudo dnf install ./imladris-0.7.0-1.fc44.x86_64.rpm
```

### Option 2: Flatpak (Universal Linux)
Download the standalone single-file bundle (`io.github.Antux912012.Imladris`):

```bash
wget https://github.com/Antux912012/imladris-next-md-editor/releases/download/v0.7.0/io.github.Antux912012.Imladris.flatpak
flatpak install --user io.github.Antux912012.Imladris.flatpak
flatpak run io.github.Antux912012.Imladris
```

### Option 3: Debian / Ubuntu / Pop!_OS (`.deb`)
Download the `.deb` package from the [v0.7.0 Release](https://github.com/Antux912012/imladris-next-md-editor/releases/tag/v0.7.0):

```bash
wget https://github.com/Antux912012/imladris-next-md-editor/releases/download/v0.7.0/imladris_0.7.0_amd64.deb
sudo dpkg -i imladris_0.7.0_amd64.deb
sudo apt-get install -f
```

---

## 🔌 Running as an MCP Server

Imladris includes a built-in Model Context Protocol (MCP) server over stdio for external AI coding agents (Claude Desktop, Antigravity, Cursor):

```bash
imladris --mcp-server
```

Configuration example for Claude Desktop (`claude_desktop_config.json`):
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
- `gee-0.8` (>= 0.20)
- `glib-2.0` (>= 2.76)

### Build & Run Tests
```bash
meson setup build
meson compile -C build
meson test -C build --print-errorlogs
```

### Packaging
```bash
# Build Fedora RPMs
./build-rpm.sh

# Build Debian .deb & Flatpak bundle
./build-packages.sh
```

---

## ⌨ Keyboard Shortcuts

| Shortcut | Action |
| :--- | :--- |
| `Ctrl+N` / `Ctrl+Shift+N` | Open New Project / Document Dialog |
| `Ctrl+O` | Open File |
| `Ctrl+S` | Save Document |
| `Ctrl+Shift+P` | Open CRAN / PyPI Package Installer |
| `Ctrl+Enter` | Run Current Line / Selection in Active REPL |
| `Ctrl+Shift+Enter` | Execute Active Code Chunk (Inline Output Card) |
| `Ctrl+Q` | Quit Imladris |

---

## 📄 License
This project is licensed under the **GNU General Public License v3.0 or later** (GPL-3.0-or-later).
