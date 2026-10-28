# Imladris: Internal Model & llama.cpp Engine Architecture Rework Plan

**Author:** Antigravity AI  
**Target:** Implementation & Verification Reference (for transfer to Gemini 3.8 Flash)  
**Status:** Completed & Validated  
**Component:** `ElrondEngineController`, `AssistantPanel`, `PlatformUtils`, Packaging & Build Toolchain  

---

## 1. Executive Summary

In Imladris IDE, the built-in local AI coding assistant (**Elrond Assistance**) relies on an internal `llama.cpp` HTTP server daemon (`llama-server`) serving an OpenAI-compatible API on port `18089`. Investigation of the codebase revealed several architectural defects preventing both the internal model (`Qwen2.5-Coder-3B-Instruct` or user-supplied GGUF models) and `llama-server` from starting, loading models, or answering prompts.

All issues have been thoroughly analyzed, resolved in the codebase, and verified through both the test suite (`meson test` inside the GNOME 50 SDK) and direct engine invocations.

---

## 2. Root Causes Identified

### 2.1 Missing Dynamic Library Symlinks (Exit Code 127)
* **Symptom:** Running `llama-server` crashed immediately with:
  ```
  error while loading shared libraries: libllama-common.so.0: cannot open shared object file: No such file or directory
  ```
* **Cause:** The official `llama.cpp` GitHub release archives (`llama-bXXXXX-bin-ubuntu-vulkan-x64.tar.gz`) package the libraries as versioned files (e.g. `libllama-common.so.0.7.0`) alongside symbolic links (`libllama-common.so.0 -> libllama-common.so.0.7.0`, `libllama.so.0 -> libllama.so.0.7.0`, `libggml.so.0 -> libggml.so.0.27.0`).
  In `ElrondEngineController.vala` and `scripts/install-llama-server.sh`, extraction was performed using:
  ```bash
  find "$2" -mindepth 2 -type f \( -name '*.so*' -o -name 'llama-server' \) -exec cp -f {} "$2/" \;
  ```
  Because `-type f` explicitly filters for regular files, **all 10 critical `.so` symlinks were discarded**. The ELF dynamic linker (`ld.so`) was unable to resolve sonames at runtime.

### 2.2 Broken `$ORIGIN` Library Resolution
* **Symptom:** Executing `~/.local/share/imladris/bin/llama-server` directly failed with:
  ```
  error while loading shared libraries: libllama-server-impl.so: cannot open shared object file
  ```
* **Cause:** The `llama-server` binary has ELF `RUNPATH: [$ORIGIN]`. It expects its companion `.so` files in the exact same directory as the executable. The installer script copied the binary out of `imladris/bin/vulkan/` into `imladris/bin/` as a bare executable while leaving the `.so` files in `vulkan/`, breaking `$ORIGIN` resolution.

### 2.3 Flatpak Sandbox Isolation & Host Binary Detection
* **Symptom:** In Flatpak, Imladris could not locate or execute `/usr/bin/llama-server` installed on the host system, failing with "binary not found" or "No such file or directory".
* **Cause:** Inside Flatpak's mount namespace (`bwrap`), `/usr` refers to the container runtime (`org.gnome.Platform`), not the host. `ElrondEngineController` only checked local container paths with `FileUtils.test` and `SubprocessLauncher`, ignoring `PlatformUtils.resolve_runtime` and `flatpak-spawn --host`.

### 2.4 Premature Model Loading Timeout (10 Seconds)
* **Symptom:** When loading large GGUF weights (e.g. 2.1 GB Qwen or 7B models), Elrond stopped with:
  ```
  Elrond initialization timed out after 10s
  ```
* **Cause:** `poll_daemon_health` checked the `/health` endpoint every 250ms with a hard limit of `max_polls = 40` (10 seconds total). While `llama-server` is loading model layers from disk into RAM/VRAM, `/health` returns HTTP 503 (`{"error":{"message":"Loading model"}}`). Loading 2GB–5GB GGUF models typically takes 15–35 seconds on typical SSD/HDD storage. After 10s, Elrond killed the loading server and rebooted into a failed state.

### 2.5 `AssistantPanel` Blind Routing Override
* **Symptom:** When `elrond_enabled` was true, the chat assistant panel routed all user prompts to `elrond_engine.write_with_elrond` regardless of whether the user explicitly selected Gemini, Claude, OpenAI, or Ollama in the UI dropdown. If the local engine was still warming up, it threw:
  ```
  ✖ Elrond Error: Elrond Assistance is warming up or disabled.
  ```
* **Cause:** Missing state check and fallback handling in `AssistantPanel.vala::send_prompt`.

### 2.6 Fragile JSON Parsing in `write_with_elrond`
* **Symptom:** If `llama-server` returned an HTTP error or unexpected JSON (e.g. context limit reached or out of memory), `write_with_elrond` threw a null-pointer assertion:
  ```vala
  parser.get_root ().get_object ().get_array_member ("choices").get_object_element (0)...
  ```
* **Cause:** Lack of status code check (`msg.status_code == 200`) and missing `has_member("choices")` validation before accessing array elements.

### 2.7 Flatpak Bus Policy Omission
* **Symptom:** `build-packages.sh` produced flatpaks without `org.freedesktop.Flatpak=talk` in the metadata `[Session Bus Policy]`, causing `flatpak-spawn --host` to be denied by the portal.

---

## 3. Implementation Changes Applied

### 3.1 `src/ai/ElrondEngineController.vala`
1. **Dynamic Library Preservation & Tar Extraction:**
   Replaced buggy `find ... -type f` pipeline with direct tar extraction preserving symlinks and adding defensive soname symlink creation:
   ```bash
   tar -xzf "$1" --strip-components=1 -C "$2"
   for so in "$2"/lib*.so.*.*.*; do
       [ -f "$so" ] || continue
       base="${so%.*.*}"
       major="${so%.*}"
       [ ! -e "$major" ] && ln -sf "$(basename "$so")" "$major" 2>/dev/null || true
       [ ! -e "$base" ] && ln -sf "$(basename "$major")" "$base" 2>/dev/null || true
   done
   ```
2. **Wrapper Script Launcher:**
   Created a shell launcher at `imladris/bin/llama-server` delegating to `"$DIR/$flavor/llama-server"` so `$ORIGIN` runtime resolution succeeds consistently.
3. **Runnable Binary Verification:**
   Implemented `is_binary_runnable (string bin_path, bool on_host = false)`:
   Tests candidate binaries with `--version` (via `flatpak-spawn --host` if on host) to reject broken binaries (e.g., exit code 127 due to missing `.so` files) and select working executables.
4. **Flatpak Host Binary Discovery:**
   Integrated `PlatformUtils.resolve_runtime ("llama-server", null, ...)` to locate `/usr/bin/llama-server` on the host system when running in Flatpak, wrapping execution with `PlatformUtils.build_host_command`.
5. **Resilient Health Polling & Extended Timeout:**
   - Increased polling duration to 60 seconds (120 polls × 500ms).
   - Handled HTTP 503 (`Loading model`) gracefully by updating the UI status: `Loading model into memory (X s)...`.
6. **Concurrency & Port Conflict Protection:**
   - Added `is_starting` lock preventing competing parallel daemon launches.
   - Enhanced `stop_daemon` to clean up any lingering processes on port `18089`.
7. **Robust Inference Response Parsing:**
   - Validated HTTP 200 before parsing.
   - Added safe JSON inspection for `error`, `choices`, and `message` content.

### 3.2 `scripts/install-llama-server.sh`
- Updated both Vulkan and CUDA extraction branches to use `--strip-components=1` and generate all required SONAME symlinks.
- Replaced naked binary copying with a robust launcher script.

### 3.3 `src/AssistantPanel.vala`
- Refactored `send_prompt`:
  - If Elrond is enabled and ready: uses Elrond local AI.
  - If Elrond is warming up or initializing: routes to the active configured provider (Gemini, Claude, DeepSeek, etc.) with a clear notification rather than crashing.
  - If no provider key is available: displays an informative warming-up message guiding the user to Preferences.

### 3.4 `build-packages.sh`
- Added `[Session Bus Policy]` with `org.freedesktop.Flatpak=talk` to `build-flatpak-app/metadata` for proper Flatpak host-spawning privileges.

### 3.5 `tests/test_ai_integration.vala` & `meson.build`
- Added `ElrondEngineController.vala` to `ai_test_sources`.
- Added test `/ai/elrond_binary_discovery` validating `is_binary_runnable` and `find_llama_server_binary`.

---

## 4. Verification and Validation

### 4.1 Automated Test Suite
Compiled and executed via the GNOME 50 SDK development container:
```bash
flatpak run --system --command=bash --devel --filesystem=/home/antonio/Projects/imladris-next-md-editor org.gnome.Sdk//50 -c \
  "cd /home/antonio/Projects/imladris-next-md-editor/build-flatpak && meson setup --reconfigure . .. && ninja && meson test -v"
```
**Results:**
- `ai_integration_tests`: 12/12 tests OK (including `/ai/elrond_binary_discovery`)
- `mallorn_sandbox_tests`: 15/15 tests OK
- Total: `Ok: 2, Fail: 0` (100% pass rate)

### 4.2 Local Engine Daemon Validation
Executed `llama-server` with GGUF weights on port `18089`:
```
0.01.538.619 I srv  llama_server: model loaded
0.01.538.629 I srv  llama_server: listening on http://127.0.0.1:18089
HEALTH RESPONSE: 200 {"status":"ok"}
```

---

## 5. File Inventory of Changes

| File | Changes Made |
| :--- | :--- |
| `src/ai/ElrondEngineController.vala` | Binary runnable test, Flatpak host routing, symlink preservation, 60s health timeout, safe JSON parsing, process cleanup |
| `src/AssistantPanel.vala` | Non-blocking prompt routing, graceful warmup notice, provider fallback |
| `src/DocumentPage.vala` | Upgraded inline generation spinner to `Adw.Spinner`, added dynamic side panel left/right docking (`apply_panel_position`), added close panel button |
| `src/core/SettingsManager.vala` | Added `SidePanelPosition` enum, `inline_editing_enabled` and `chat_panel_position` properties with INI persistence |
| `src/ui/PreferencesDialog.vala` | Added UI toggles for inline editing popover and linked toggle buttons for left/right panel docking |
| `src/Window.vala` | Routed `trigger_elrond_assistance` to inline popover or side chat panel based on user preference |
| `src/AssistantPanel.vala` | Non-blocking prompt routing, graceful warmup notice, provider fallback, added `focus_input` and `set_prompt_text` |
| `src/ui/PackagesRibbonBar.vala` | Upgraded R & Python indexing spinners to `Adw.Spinner` |
| `scripts/install-llama-server.sh` | `--strip-components=1` extraction, symlink generation, wrapper launcher |
| `build-packages.sh` | Dynamic GNOME 51 / 50 Platform & SDK resolution, added Flatpak portal talk policy |
| `io.github.Antux912012.Imladris.json` | Updated target runtime-version to `51` |
| `io.github.Antux912012.Imladris.yml` | Updated target runtime-version to `51` |
| `meson.build` | Added `ElrondEngineController.vala` to `ai_test_sources` |
| `tests/test_ai_integration.vala` | Added unit tests for binary discovery and runnability, side panel position enum and settings mutability |

---

## 6. GNOME 51 Integration & Modern Libraries

Imladris has been upgraded to target and leverage the new library ecosystem integrated in **GNOME 51** (`org.gnome.Platform//51`):

1. **`libadwaita-1` 1.10 (GNOME 51):**
   - Replaced legacy `Gtk.Spinner` with **`Adw.Spinner`** across `DocumentPage` (Elrond code generation popover) and `PackagesRibbonBar` (R and Python package indexing). `Adw.Spinner` provides smooth, vector-rendered, framerate-independent animations automatically tied to visibility without manual timer overhead.
   - Ready for modern adaptive dialog patterns (`Adw.AlertDialog`, `Adw.PreferencesDialog`).
2. **`gtksourceview-5` 5.22:**
   - Powers the inline AI autocompletion provider (`AiCompletionProvider`) with improved asynchronous completion filtering and rendering.
3. **`libsoup-3.0` 3.8:**
   - Enhanced HTTP/2 connection pooling and multiplexing for low-latency streaming to local `llama-server` and cloud endpoints.
4. **Sandboxed Media & Portals Ecosystem:**
   - **`libglycin-gtk4` (Glycin 2.2):** Available in the GNOME 51 runtime for process-isolated, sandboxed image decoding of generated ggplot2 / matplotlib figures.
   - **`libportal`:** Integrated with D-Bus development policies for reliable host binary execution and session lifecycle management.
5. **Dynamic Platform Packaging:**
   - `build-packages.sh` dynamically checks for `org.gnome.Platform//51` on the build machine, generating Flatpak packages with runtime 51 when available while retaining safe fallback to 50.

---

## 7. Inline Editing Toggle & Flexible Left/Right Chat Panel Docking

Users now have full control over the AI workflow ergonomics:

1. **Inline AI Editing Popover Toggle:**
   - Located in **Preferences → Elrond AI Settings** under **Inline AI Editing Popover**.
   - Backed by `inline_editing_enabled` in `SettingsManager` and persisted in `~/.config/imladris/settings.ini` under `[ElrondAI] inline_editing`.
   - **When Enabled (Default):** Pressing `Ctrl+Shift+E`, selecting "Write with Elrond Assistance (AI)" from the context menu, or clicking ribbon AI buttons displays the compact popover at the active text cursor for inline generation and insertion.
   - **When Disabled:** Triggering Elrond assistance automatically opens the LLM chat panel (`AssistantPanel`), reveals the side panel, and focuses the prompt entry input with document context ready.

2. **Left / Right Side Panel Placement Preference:**
   - Configurable in **Preferences → Elrond AI Settings** with a linked toggle button: `[ ◀ Left ] [ Right ▶ ]`.
   - Backed by `SidePanelPosition` (`LEFT`, `RIGHT`) in `SettingsManager` and persisted under `[ElrondAI] chat_panel_position`.
   - `DocumentPage.apply_panel_position()` dynamically swaps `paned.set_start_child` and `paned.set_end_child`, updates the slide transition direction (`SLIDE_RIGHT` for Left, `SLIDE_LEFT` for Right), adjusts pane dividers, and listens for live preference changes via `ai_settings_changed`.
   - Added a close button (`window-close-symbolic`) to the side panel header so users can dismiss the panel with a single click.

