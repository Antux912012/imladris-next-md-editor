# Codebase & UX Audit Report — Project Imladris

**Date:** 2026-10-25  
**Version:** 0.4.0  
**Repository:** `imladris-next-md-editor`  
**Author:** Principal Software Architect & Lead UI/UX Engineer (Gemini 3.8)

---

## 1. Executive Summary

This audit assesses the state of `imladris-next-md-editor` prior to executing the Phase 0 cleanup and Phase 1 multi-format / dynamic layout architectural plan. 

The application is a native Linux Markdown and Polyglot Studio built in **Vala**, targeting **GTK4 (>= 4.12)**, **Libadwaita (>= 1.5)**, **GtkSourceView 5 (>= 5.10)**, and **WebKitGTK 6.0**. While the core application builds and links cleanly using the GNOME 50 Flatpak SDK, the codebase has accumulated architectural debt from historical transitions (specifically from an earlier tab/pane prototype to a multi-tiered ribbon UI in v0.4.0).

---

## 2. Dependency & Architecture Mapping

### 2.1 Build System & Toolchain
- **Build System:** Meson 1.9.2 + Ninja 1.13.2
- **Compiler:** Vala (`valac 0.56.19`) generating C, compiled by GCC 15.2.0 via `ccache`.
- **Packaging:** Flatpak bundle (`org.gnome.Imladris`, GNOME 50 runtime/SDK) + Debian package generator (`build-packages.sh`).

### 2.2 Active Component Tree (Referenced by `meson.build`)
```
src/
├── main.vala               # Application entry point
├── Application.vala        # Adw.Application subclass, action handlers (app.*)
├── Window.vala             # Adw.ApplicationWindow, 9-tier ribbon stack, TabView/TabBar
├── RibbonFactory.vala      # Factory methods for top ribbon toolbars & tall/compact buttons
├── PopoverFactory.vala     # Dropdown popovers (Color palette, Insert helpers)
├── DocumentPage.vala       # Gtk.Box containing Paned editor + preview + console + AI assistant
├── AssistantPanel.vala     # Side panel for llama.cpp / OpenAI LLM assistant
├── ExecutionEngine.vala    # Host execution runner for code chunks
├── LlamaServerManager.vala # Local llama-server lifecycle manager
├── McpServer.vala          # Model Context Protocol server over stdin/stdout
└── AiClient.vala           # Soup 3.0 HTTP client for LLM streaming completions
```

### 2.3 Dormant / Orphaned Modules (Unreferenced in `meson.build`)
The repository contains 10 source files and directories left over from an earlier architectural iteration that are **not** listed in the root `meson.build`:
1. `src/application.vala`: Duplicate, lowercase counterpart to `src/Application.vala`.
2. `src/window.vala`: Duplicate, lowercase counterpart to `src/Window.vala`.
3. `src/core/document_model.vala`: Early DocumentModel definition.
4. `src/core/file_manager.vala`: FileManager utility.
5. `src/core/frontmatter_parser.vala`: Regex-based frontmatter parser.
6. `src/core/markdown_parser.vala`: Libcmark wrapper parser.
7. `src/core/notebook_serializer.vala`: Early Jupyter JSON serializer.
8. `src/core/project_scaffolder.vala`: Template generator for projects.
9. `src/core/view_manager.vala`: Early view manager.
10. `src/ui/`: `coding_view.vala`, `preview_view.vala`, `contextual_popover.vala`, `new_project_dialog.vala`, `tab_page_content.vala`, `terminal_view.vala`.
11. `src/vapi/`: `cmark.vapi`, `libcmark.vapi` (unused since `cmark` is not linked in root `meson.build`).
12. `src/meson.build`: Unused secondary Meson file.

---

## 3. Compiler & Linter Warnings Log

During `ninja -C build`, valac and GCC report several warnings that must be resolved in Phase 0.3:

1. **Deprecated GTK API in `src/Application.vala:37`:**
   - `Gtk.StyleContext.add_provider_for_display` is deprecated since GTK 4.10. Needs migration to `Gtk.StyleContext` free replacement or modern provider registration.
2. **Unreachable Catch Clauses in `src/AssistantPanel.vala:272, 286`:**
   - `catch (GLib.Error e)` is flagged because the enclosed statements do not throw checked exceptions.
3. **Type Mismatches in `src/RibbonFactory.vala:41, 112`:**
   - Passing `GtkPopover *` to `gtk_menu_button_set_popover` triggers incompatible pointer warnings.
4. **Const Discard Warnings in `src/AiClient.vala:6-8`:**
   - Assignment discards `const` qualifier on default string properties.
5. **Type Mismatch in `src/Window.vala:246`:**
   - Passing `guint8 **` to `g_file_load_contents_finish` expecting `char **`.
6. **Type Mismatches in `src/Window.vala:341, 342`:**
   - Passing `gchar **` to `gtk_drop_down_new_from_strings` expecting `const char * const *`.

---

## 4. UX Friction & Performance Analysis

1. **Apostrophe Mode Deficit:**
   - Currently, opening a plain `.md` file loads the full 9-tier ribbon bar (`Home`, `Insert`, `Layout`, `AI Assistant`, `Tools`, `Console`, etc.) with dense buttons, cluttering what should be a distraction-free writing environment.
2. **Missing 4-Quadrant RStudio Workbench:**
   - Computational notebooks (`.ipynb`, `.Rmd`, `.Qmd`) are currently constrained to a horizontal split between the editor and WebKit preview, lacking the standard Top-Left (Source), Bottom-Left (Console/Terminal), Top-Right (Environment/Outline), and Bottom-Right (Plots/Viewer) docking grid.
3. **Typing Latency on Large Documents:**
   - `DocumentPage.vala` updates WebKit and recalculates word/line stats on every buffer change with a basic debounce. Heavy documents with complex math (KaTeX) or Mermaid diagrams stutter without AST chunking or incremental DOM patching.
4. **Lack of Shadow-Buffer Recovery:**
   - If the application or OS crashes, unsaved editor state is completely lost. There is no background atomic auto-cache or crash-recovery prompt on startup.

---

## 5. Phase 0 Action Items

1. **Eliminate Duplicate & Dormant Files:** Remove `src/application.vala`, `src/window.vala`, `src/meson.build`, and integrate/prune orphaned `src/core/` and `src/ui/` files.
2. **Resolve All Warnings:** Fix all Vala compiler and C warnings so `ninja` compiles with zero warnings.
3. **Consolidate Clean Architecture:** Establish the 4-layer architecture outlined in `GEMINI.md` in preparation for Phase 1.

---

## 6. Dead & Duplicate Code Log (Phase 0.2)
- `src/application.vala`: **REMOVED** (Obsolete duplicate of `src/Application.vala`).
- `src/window.vala`: **REMOVED** (Obsolete duplicate of `src/Window.vala`).
- `src/meson.build`: **REMOVED** (Unused duplicate build file superseded by root `meson.build`).

