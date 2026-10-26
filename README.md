<p align="center">
  <img src="data/icons/hicolor/256x256/apps/io.github.Antux912012.Imladris.png" alt="Imladris Logo" width="128" height="128">
</p>

<h1 align="center">Imladris</h1>
<h3 align="center">A GNOME-native home for scientific writing, notebooks and data work</h3>

<p align="center">
  <a href="https://github.com/Antux912012/imladris-next-md-editor/releases"><img src="https://img.shields.io/github/v/release/Antux912012/imladris-next-md-editor?include_prereleases&style=flat-square&color=blue" alt="Release"></a>
  <img src="https://img.shields.io/badge/GTK4%20%2F%20Libadwaita-1.5%2B-blue?style=flat-square" alt="Toolkit">
  <img src="https://img.shields.io/badge/Vala-GPL--3.0--or--later-green?style=flat-square" alt="Vala, GPL-3.0-or-later">
  <img src="https://img.shields.io/badge/Flatpak-io.github.Antux912012.Imladris-blue?style=flat-square&logo=flatpak" alt="Flatpak">
</p>

<p align="center">
  <img src="data/screenshots/imladris-screenshot.png" alt="Imladris screenshot" width="850">
</p>

Imladris is a desktop editor for people who write with code in it: Quarto and R Markdown reports, Jupyter notebooks, R and Python scripts, and plain Markdown or HTML when that's all you need. It's written in **Vala** on **GTK4 + Libadwaita**, and it tries hard to feel like it belongs on a GNOME desktop.

The itch it scratches is simple. RStudio is great for analysis but heavy for prose; Apostrophe is lovely for prose but can't run a chunk. Imladris switches between the two depending on what you opened: a `.md` file gets a calm, quick writing view, while a `.qmd` or `.ipynb` gets a full four-quadrant workbench with editor, console, environment and files.

> Imladris is an independent project. It is not affiliated with or endorsed by Posit, RStudio or Project Jupyter.

---

## What it does

### Two modes, picked automatically
- **Writer mode** for `.md` and `.html`: no kernels are started, nothing computational is shown, and the ribbon shows only formatting, live preview and export.
- **Workbench mode** for `.Rmd`, `.qmd`, `.ipynb`, `.R` and `.py`: source editor, environment/outline pane, console + terminal, and a files/plots/packages pane.

### Modernized Libadwaita Ribbon Menu
The Ribbon menu has been modernized to integrate seamlessly with GNOME Libadwaita and GTK4 design language:
- **5 High-Density Tabs**: Consolidated 9 fragmented tabs into 5 high-utility tabs: `Home`, `Insert`, `Computation`, `Publish`, and `View`.
- **Linked Controls & Design Tokens**: Uses native `@headerbar_bg_color`, `@window_bg_color`, and `@accent_color` tokens with linked button groups (`.linked`), reducing vertical height by ~35px to a sleek ~52px deck.
- **Collapsible Ribbon (`Ctrl+F1`)**: Quickly collapse or expand the ribbon deck on demand with the top-bar chevron button or `<Control>F1` shortcut for maximum editor focus.
- **Wired Functional Tools**: Built-in undo/redo (`Ctrl+Z` / `Ctrl+Shift+Z`), headings (`#`, `##`, `###`), lists and blockquotes, interactive 6x6 table picker popover, code chunk popover, citation popovers, LaTeX math (`$$`), Mermaid diagrams, ggplot2 snippets, and live zoom slider.
- **Context-Aware State Machine**: A dedicated engine (`Window.update_ribbon_state_machine`) adapts visible and sensitive states based on document format and project sandbox type, avoiding irrelevant actions.

### Running code
- Persistent **R** and **Python** sessions (`ReplBridge`) run as long-lived subprocesses, so variables survive between chunks like they do in a real REPL.
- Chunks run inline (`Ctrl+Shift+Enter`). Output and plots land in a card under the chunk, anchored in the `GtkSourceView` buffer.
- R plots are captured through a PNG device; Python figures through matplotlib's Agg backend. Multi-line Python is shipped base64-encoded to dodge quoting and indentation problems.
- The working directory is the project root everywhere: processes are spawned with `set_cwd`, and R (`setwd`), Python (`os.chdir`), the terminal and the Files pane all follow along.

### Projects: Standard vs Sandboxed
| | Standard | Sandboxed |
| :--- | :--- | :--- |
| R packages | your user library | project-local `renv` |
| Python packages | system / user site-packages | project-local `.venv` |
| Portable? | No, and the UI tells you so | Yes, via `renv.lock` + `requirements.txt` |
| Status badge | `[System Libraries - Non-Portable]` | `[Sandboxed - Reproducible]` |

Exporting a Standard project asks for confirmation first, because it may not run elsewhere. Sandboxed projects can be exported for **RStudio** (`.Rproj`, `.Rprofile`, `renv/activate.R`) or **Jupyter** (`requirements.txt`, `environment.yml`, a bootstrap script).

### The `.mallorn` format
A `.mallorn` file is RStudio's `.Rproj` DCF syntax with a few namespaced `Imladris*` keys added. Imladris keeps `<name>.mallorn` and `<name>.Rproj` in sync, so a project opens in both tools. A whole project can also be packed into a single portable archive (`.tar.zst`, with a `.zip` fallback) that leaves out heavy library folders and keeps the lockfiles.

### Package installer
An RStudio-style dialog for CRAN and PyPI. It fetches both indices with libsoup, parses them with json-glib, and autocompletes comma- or space-separated package lists. Installs go to the right place automatically (system library, or the project's `renv` / `.venv`, followed by a lockfile snapshot).

### Export
Documents go to HTML, PDF, **ODT** and **ODP**. Imladris uses Quarto, rmarkdown or Pandoc when they're installed, goes through LibreOffice for slides, and falls back to a built-in OpenDocument writer when none of that is available.

### The creation dialog
One dialog, nine plain-labelled choices: *Create a Project*, *Create a Sandboxed project*, *Create a simple .md*, *Create a simple .html*, *Create a R script file*, *Create a .Rmd*, *Create a .Qmd*, *Create a .ipynb*, *Create a Python script*.

### AI Assistant & Writing Co-Author
Imladris includes a dedicated AI writing and coding panel with out-of-the-box support for the leading scientific and coding models:
- **Google Gemini**: First-class support via **Google AI Studio** free API keys or **Google Account OAuth** tokens (`gemini-2.0-flash`, `gemini-1.5-flash`, `gemini-1.5-pro`, `gemini-2.0-flash-thinking-exp`).
- **Claude (Anthropic API)**: Native `/v1/messages` protocol support with reasoning/thinking block extraction (`claude-3-5-sonnet-20241022`, `claude-3-5-haiku-20241022`, `claude-3-opus-20240229`).
- **OpenAI API**: Official OpenAI endpoints for `gpt-4o`, `gpt-4o-mini`, `o1`, and `o3-mini`.
- **DeepSeek API**: Access `deepseek-chat` and `deepseek-reasoner` (DeepSeek-R1) with native extraction and display of the reasoning/thought chain.
- **Kimi API (Moonshot AI)**: `moonshot-v1-8k`, `moonshot-v1-32k`, and `kimi-latest` for ultra-long context documents.
- **Qwen API (Alibaba Cloud DashScope)**: Direct integration with `qwen2.5-coder-32b-instruct` and `qwen-plus`.
- **Cursor API Compatibility**: Connect seamlessly with Cursor accounts or Cursor-compatible endpoints (`cursor-small`, `claude-3-5-sonnet`, `gpt-4o`).
- **NVIDIA NIM**: High-performance inference endpoints at `integrate.api.nvidia.com` for models like `meta/llama-3.3-70b-instruct`, `deepseek-ai/deepseek-r1`, and `nvidia/llama-3.1-nemotron-70b-instruct`.
- **Local Ollama & LM Studio**: Zero-cloud offline privacy via Ollama (`localhost:11434`) or LM Studio Local Server (`localhost:1234`).
- **Custom OpenAI-Compatible**: Connect to any endpoint (Groq, Mistral, Together, vLLM, private proxies).

<p align="center">
  <img src="data/screenshots/imladris-preferences-ai.png" alt="Multi-Provider AI Assistant Configuration" width="700">
</p>

Credentials and model choices are persisted locally in `~/.config/imladris/ai_config.json` (restricted to user read-write mode `0600`) and automatically detect standard environment variables (`GEMINI_API_KEY`, `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `DEEPSEEK_API_KEY`, `MOONSHOT_API_KEY`, `DASHSCOPE_API_KEY`, `CURSOR_API_KEY`, `NVIDIA_API_KEY`).

### Extras
- **Appearance & GNOME Accents** (menu → Preferences, `Ctrl+,`): switch between System Theme, Light, Dark, and Eye Friendly (warm sepia) palettes. Includes GNOME Settings-style circular accent color swatches (Blue, Teal, Green, Yellow, Orange, Red, Pink, Purple, Slate) with live synchronization to `org.gnome.desktop.interface accent-color`.
- **Hardware acceleration toggle** (menu → Preferences, `Ctrl+,`): switches every WebKit view between GPU compositing and pure software rendering, live, with the choice stored in GSettings. Handy on VMs, older hardware or flaky drivers.

<p align="center">
  <img src="data/screenshots/imladris-preferences-theming.png" alt="Appearance Preferences and GNOME Accent Colors" width="700">
</p>

Built-in MCP server (`imladris --mcp-server`), and crash recovery that keeps shadow copies of unsaved work in `~/.cache/imladris/recovery/`. The AI assistant is off the critical path: nothing is sent anywhere unless you configure an endpoint and use it.

---

## Install

Packages for each release live on the [Releases page](https://github.com/Antux912012/imladris-next-md-editor/releases).

**Flatpak**
```bash
flatpak install --user io.github.Antux912012.Imladris.flatpak
flatpak run io.github.Antux912012.Imladris
```
The Flatpak requests network access (package indices, optional AI endpoints), home-folder access (your projects) and the usual display/GPU sockets. Note that R, Python, Quarto and Pandoc are looked up on the sandbox's `PATH`; use the native packages if you want Imladris to see your host toolchain.

**Fedora**
```bash
sudo dnf install ./imladris-0.7.0-1.fc44.x86_64.rpm
```

**Debian / Ubuntu**
```bash
sudo dpkg -i imladris_0.7.0_amd64.deb && sudo apt-get install -f
```

## Build from source

Needs `valac` ≥ 0.56, `meson`, `ninja`, GTK4 ≥ 4.12, libadwaita ≥ 1.5, GtkSourceView 5, WebKitGTK 6.0, libsoup 3, json-glib, libgee and GLib ≥ 2.76.

```bash
meson setup build
meson compile -C build
meson test -C build --print-errorlogs
./build/imladris
```

Packaging helpers: `./build-rpm.sh` (Fedora) and `./build-packages.sh` (`.deb` + Flatpak bundle).

## MCP server

```bash
imladris --mcp-server
```
```json
{ "mcpServers": { "imladris": { "command": "imladris", "args": ["--mcp-server"] } } }
```

## Shortcuts

| Shortcut | Action |
| :--- | :--- |
| `Ctrl+N` | New project / document dialog |
| `Ctrl+O` / `Ctrl+S` | Open / Save |
| `Ctrl+F1` | Toggle Ribbon collapse / expand |
| `Ctrl+Z` / `Ctrl+Shift+Z` | Undo / Redo |
| `Ctrl++` / `Ctrl+-` / `Ctrl+0` | Zoom In / Zoom Out / Reset Zoom (100%) |
| `Ctrl+Shift+P` | Package installer |
| `Ctrl+Enter` | Run line or selection |
| `Ctrl+Shift+Enter` | Run current chunk |
| `Ctrl+,` | Preferences (Appearance & AI Providers) |
| `Ctrl+Q` | Quit |

---

## AI disclosure (code provenance)

In the spirit of transparency, and to meet Flathub's expectations around AI-generated contributions:

- **A large share of this codebase was written with AI coding assistants** (large language models used as pair-programming agents), including much of the Vala source, build scripts, packaging files, tests and this documentation.
- **The maintainer directs the work and is accountable for it.** Design decisions, feature scope and releases are the maintainer's; AI output is treated as a draft, not as authority.
- **Verification is mechanical, and you should know its limits.** Changes are built and run through the Meson test suite (11 test cases covering data models, `.mallorn` round-trips, sandboxes, exports, sessions, the chunk parser and the REPL bridge), plus `appstreamcli` and `desktop-file-validate`. Passing tests is not the same as a line-by-line human audit, and some areas, especially UI behaviour, have had less scrutiny than others.
- **Licensing.** All code is distributed under GPL-3.0-or-later. If you spot code that looks copied from another project, please open an issue so it can be checked and fixed or attributed.
- **Runtime AI is opt-in.** The optional assistant and MCP server only talk to endpoints *you* configure. No telemetry is collected.
- **Bug reports and human review are very welcome**, particularly for security-relevant paths: subprocess spawning, archive extraction and file export.

## Contributing

Issues and pull requests are welcome. If you used an AI tool for a contribution, just say so in the PR description; nobody's judging, it just helps reviewers know where to look harder.

## License

GPL-3.0-or-later.
