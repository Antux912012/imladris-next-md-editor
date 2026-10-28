# Imladris Nexus: Knowledge Graph & Book Weaver Plugin

An Obsidian-inspired **Knowledge Graph & Linear Book Weaver** extension for **Imladris IDE**, built with JavaScriptCore (`JSC.Context`), WebKitGTK 6.0, and HTML5 Canvas.

![Graph View Preview](https://static0.xdaimages.com/wordpress/wp-content/uploads/wm/2024/07/how-to-use-obsidian-graph-view-8.jpg?q=49&fit=crop&w=825&dpr=2)

---

## 🌟 Key Features

1. **Obsidian-Style Interactive Force Graph**:
   - Hardware-accelerated 60 FPS physics simulation (Coulomb charge repulsion, spring links, and gravity).
   - Dynamic node sizing based on connection degree (centrality).
   - Color-coded taxonomy:
     - 🔵 **Markdown Documents** (`#58a6ff`)
     - 🟢 **Tags & Keywords** (`#3fb950`)
     - 🟣 **Book Chapters** (`#bc8cff`)
     - 🔴 **Ghost Notes** (Referenced pages that do not yet exist)
   - Interactive zoom, pan, node dragging, and live hover cards.
   - **Click to Navigate**: Clicking any node immediately opens that markdown note in the Imladris editor!

2. **Wiki-Links & Keyword Interconnections**:
   - Bi-directional Wiki-links: `[[Note Title]]` or `[[Note Title|Alias]]`.
   - Standard relative Markdown links: `[Chapter 1](chapter1.md)`.
   - Inline hashtags: `#biostats`, `#genetics/crispr`.
   - YAML Frontmatter metadata:
     ```yaml
     ---
     title: "Statistical Methods"
     tags: [statistics, regression, bayesian]
     keywords: [mcmc, stan]
     order: 2
     chapter: "Methodology"
     ---
     ```

3. **Multiple Exploration Modes**:
   - **Global Universe Graph**: Visualizes all interconnected notes in the workspace.
   - **Local Ego Graph (1-Hop)**: Focuses exclusively on the currently open document and its immediate neighbors.
   - **Book Outline Mode**: Hierarchical reading flow ordered by chapters and topological links.

4. **"Book Weaver" Manuscript Compiler**:
   - Topologically sorts your interconnected notes into a contiguous, coherent reading order.
   - Generates a formatted Table of Contents (TOC).
   - Concatenates the notes into a unified master book manuscript with page breaks (`\newpage`) ready for Pandoc/Quarto PDF, ODT, or ODP export!

---

## 📦 Installation & Packaging

### One-Click Installation in Imladris
1. Download or package `imladris-nexus-graph.implugin`.
2. Open Imladris and navigate to **Preferences (`Ctrl+,`) → Extensions**.
3. Under **Import Plugin Bundle**, click **"Import Plugin…"**.
4. Select `imladris-nexus-graph.implugin`.
5. Review the requested permissions (**Editor Access** and **Workspace Access**), and click **"Install & Enable"**.
6. Switch to the **Home** tab in the Ribbon. You will see the new **"Graph View"** and **"Weave Book"** buttons in the **Extensions** group!

### Packaging into `.implugin`
To package the extension into an installable `.implugin` archive:

```bash
cd examples/plugins/imladris-nexus-graph
zip -r ../imladris-nexus-graph.implugin manifest.json main.js README.md
```

---

## 🔒 Security & Sandbox Boundary

- **Isolated VM**: Executes within an isolated WebKitGTK `JSC.Context` virtual machine.
- **Strict Project Scoping**: Only accesses files inside the active workspace project. Path traversal (`../`) is strictly rejected by the Vala host.
- **Offline & Zero Dependencies**: Fully self-contained physics simulation on HTML5 Canvas without external CDNs or network calls.

---

## 📄 License

Licensed under the **GNU General Public License v3.0 or later (GPL-3.0-or-later)**.
