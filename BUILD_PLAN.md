# Project Imladris (`imladris-next-md-editor`) — Master Building Plan

**Repository:** `https://github.com/Antux912012/imladris-next-md-editor`  
**Target Agent:** Gemini 3.8 / Autonomous Coding Agent  
**Objective:** Refactor, optimize, and expand Project Imladris into a context-aware, dynamic Markdown and Scientific Notebook editor supporting `.md`, `.Rmd`, `.Qmd`, and `.ipynb` formats with adaptive UI layouts (Apostrophe-style vs. RStudio-style).

---

## Agent Execution Guidelines
1. **Incremental Commits:** Execute one sub-phase at a time. Run linters, type checks, and tests after each task before moving to the next.
2. **State Preservation:** Do not break existing core editor bindings during Phase 0 refactoring.
3. **Architecture First:** Before writing UI components in Phase 1, establish the underlying state management and file-type detection schemas.
4. **Verification:** Provide a brief summary of touched files and verification steps at the end of every phase.

---

## Phase 0: Codebase Audit, Cleanup & Optimization

**Objective:** Establish a clean, modular, and performant baseline before introducing multi-format parsing and dynamic docking layouts.

### 0.1 Software & UX Audit
- [x] **Dependency & Architecture Mapping:** Scan the repository to map the current component tree, state management flow, and third-party dependencies.
- [x] **UX Friction Log:** Identify UI bottlenecks, unaligned styling, slow rendering paths in the current editor/preview loop, and inconsistent keyboard shortcuts.
- [x] **Deliverable:** Generate an `AUDIT_REPORT.md` in `/docs` detailing architectural bottlenecks, unused dependencies, and UX inconsistencies.

### 0.2 Removal of Dormant & Duplicate Code
- [x] **Dead Code Elimination:** Locate and remove commented-out blocks, unreachable functions, orphaned components, and unused assets/icons.
- [x] **Dependency Pruning:** Remove unused packages from the dependency manifest (`package.json` / `Cargo.toml` / build config).
- [x] **DRY Consolidation:** Identify duplicate utility functions (e.g., file I/O helpers, string parsers, theme toggles, modal wrappers) and consolidate them into a centralized `/utils` or `/core` module.

### 0.3 Code Optimization
- [x] **Editor Loop Performance:** Debounce or throttle the live-preview rendering pipeline to prevent frame drops during rapid typing on large documents.
- [x] **Memory & Bundle Optimization:** Implement lazy loading for heavy syntax highlighters, math renderers (KaTeX/MathJax), and diagram engines (Mermaid).
- [x] **Strict Typing & Linting:** Resolve all existing compiler/linter warnings and enforce strict type definitions across all modules.

---

## Phase 1: Core Multi-Format Editor & Resilience

**Objective:** Expand file compatibility beyond standard Markdown to support scientific/computational notebooks, flexible split views, and crash recovery.

### 1.1 Multi-Format Compatibility (`.md`, `.Rmd`, `.Qmd`, `.ipynb`)
- [x] **Unified Document Abstraction Layer:** Create a file adapter service that ingests different formats and normalizes them into an internal Editor AST/State:
  - **`.md` (Standard Markdown):** Direct text buffer with CommonMark/GFM parsing.
  - **`.Rmd` (R Markdown) & `.Qmd` (Quarto):** Support YAML frontmatter parsing and executable/attributed code chunk delimiters (e.g., ```` ```{r} ```` or ```` ```{python} ```` with `#|` chunk options).
  - **`.ipynb` (Jupyter Notebook):** Build a bidirectional serializer/deserializer that parses the `.ipynb` JSON schema (`cells`, `metadata`, `nbformat`) into editable markdown blocks and code cells, and serializes back to valid JSON upon saving.
- [x] **Syntax Highlighting & AST Extensions:** Register language grammars for R, Python, Julia, YAML frontmatter, and Quarto callout blocks.

### 1.2 Crash Recovery & Auto-Cache System
- [x] **Shadow Buffer / Local Storage Engine:** Implement a background persistence worker that snapshots the active document state (including unsaved buffers, cursor position, and dirty flags) every `N` seconds (e.g., 3000ms) or on idle.
- [x] **Dirty State & Lockfile:** Maintain a session lock or dirty-state manifest in the local application data/cache directory.
- [x] **Recovery Routine:** On application boot, check if the previous session terminated unexpectedly (dirty state = `true`). If detected, prompt the user with a non-destructive recovery banner or automatically restore the cached workspace buffers.
- [x] **Cache Cleanup:** Flush temporary recovery caches cleanly upon explicit file save or normal application exit.

### 1.3 Multi-Mode Preview & Split View Engine
- [x] **View Mode State Machine:** Implement a layout controller supporting four distinct viewing states, switchable via top ribbon controls and keyboard shortcuts:
  1. **Editor Only:** Distraction-free source editing.
  2. **Preview Only:** Read-only rendered output mode.
  3. **Vertical Split (Side-by-Side):** Editor on the left, live rendered preview on the right (resizable divider).
  4. **Horizontal Split (Top-and-Bottom):** Editor on top, live rendered preview on the bottom (resizable divider).
- [x] **Synchronized Scrolling:** Implement proportional scroll-sync between the active editor buffer and the preview pane across both Horizontal and Vertical split modes.

---

## Phase 1.1: Dynamic UI Adaptation & Workspace Layouts

**Objective:** Dynamically morph the application's UI paradigm based on the active file extension—transitioning seamlessly between a distraction-free writer (Apostrophe style) and a full scientific IDE layout (RStudio style).

### 1.1.1 Context-Aware Layout Engine
- [x] **File-Type Watcher:** Bind a layout-switching listener to the file loader and tab switcher.
- [x] **Dynamic Mode Resolution:**
  - When opening/focusing `.md` $\rightarrow$ Trigger **Apostrophe Mode (Simplified Writer UI)**.
  - When opening/focusing `.Rmd` or `.Qmd` $\rightarrow$ Trigger **RStudio Mode (Multi-Pane IDE UI)** automatically.
  - When opening/focusing `.ipynb` $\rightarrow$ Default to Notebook View, with an explicit toggle in the ribbon to switch into **RStudio Mode**.
- [x] **Manual Override:** Allow the user to manually lock or switch layouts regardless of file extension via a workspace layout selector.

### 1.1.2 Apostrophe Mode (For `.md` Files)
- [x] **Minimalist Chrome:** Hide secondary IDE docks (Environment, Console, Plots) to maximize writing focus, adopting clean typography and generous margins inspired by GNOME Apostrophe.
- [x] **Smart Top Ribbon Menu:** Retain a streamlined, high-utility top toolbar featuring quick-insert dropdown menus and helpers:
  - **Table Builder:** Interactive grid picker (e.g., hover $M \times N$ grid) + modal helper to insert formatted Markdown tables instantly.
  - **Code Chunk Inserter:** One-click insertion of fenced code blocks with a searchable language selector dropdown.
  - **Citations & Bibliography Manager:** Dropdown UI to link a `.bib` / CSL JSON file, search citation keys (`@author2026`), insert inline citations, and auto-append the bibliography block.
  - **Special Symbols Picker:** Categorized dropdown popover for rapid insertion of mathematical operators, Greek letters ($\alpha, \beta, \Delta$), arrows, and scientific notation.
  - **Emoji Picker:** Searchable popover menu with categorized emojis and shortcode autocomplete (`:rocket:`).

### 1.1.3 RStudio Mode & Drag-and-Drop Docking (For `.Rmd`, `.Qmd`, `.ipynb`)
- [x] **4-Quadrant Workbench Architecture:** Implement a multi-pane docking grid modeled after RStudio:
  - **Quadrant 1 (Top-Left):** Source Editor (`.Rmd` / `.Qmd` / `.ipynb` document).
  - **Quadrant 2 (Bottom-Left):** Interactive Console / Terminal / Execution Log.
  - **Quadrant 3 (Top-Right):** Environment / Variables Inspector, Document Outline (TOC), & Citations list.
  - **Quadrant 4 (Bottom-Right):** Live Preview / Rendered Output, Plots, Files Browser, & Help.
- [x] **Drag-and-Drop Panel Management:**
  - Integrate a flexible docking/grid system allowing users to drag panel tabs between quadrants, reorder tabs within a pane, or resize quadrant splitters smoothly.
  - Support maximizing/minimizing individual quadrants and persisting the user's custom panel arrangement in local settings.
- [x] **`.ipynb` RStudio Layout Adaptation:** When `.ipynb` is switched to RStudio Mode, map the notebook cells to the Source quadrant while routing cell outputs, plots, and variable states to the corresponding RStudio quadrants.

---

## Verification & Definition of Done (DoD)
1. **Zero Regressions:** All Phase 0 optimizations pass build, lint, and unit test suites with zero warnings.
2. **Format Integrity:** Opening, editing, and saving `.md`, `.Rmd`, `.Qmd`, and `.ipynb` files preserves file structure and metadata without corruption.
3. **Crash Simulation:** Force-killing the application (`SIGKILL`) during active editing triggers the cache recovery flow upon restart with zero data loss.
4. **Layout Fluidity:** Switching between a `.md` tab and a `.Qmd` tab smoothly transitions the workspace between the Apostrophe-style ribbon view and the 4-quadrant RStudio dockable layout.
