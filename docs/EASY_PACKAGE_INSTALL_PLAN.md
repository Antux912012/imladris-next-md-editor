# Architectural Plan: Easy R & Python Package Installer for Imladris

This document specifies the step-by-step implementation plan for **Gemini 3.8** to enhance the package management subsystem in **Imladris** (`src/ui/PackageInstallerDialog.vala` and `src/Window.vala`). 

The goal is to provide a seamless, modern Libadwaita UI to install:
1. **R Packages**: From **CRAN** (with autocomplete, popular bundles, mirror selection) and **Manually** (local `.tar.gz`/`.zip` source archives via `Gtk.FileDialog`, or remote Git/GitHub repositories).
2. **Python Packages**: Using **`uv`** (ultra-fast installer) or **`pip`** (standard fallback), supporting both PyPI packages and **Manual** local archives (`.whl`/`.tar.gz`) or editable local directories.

---

## 1. Architectural Design & Enums

### 1.1 New Enums & Detection
In `src/ui/PackageInstallerDialog.vala`:

```vala
namespace Imladris.UI {

    public enum PackageEcosystem {
        R_CRAN,
        PYTHON_PYPI
    }

    public enum InstallSourceMode {
        REPOSITORY,      // CRAN or PyPI (Search & Autocomplete)
        LOCAL_ARCHIVE,   // Local .tar.gz, .tgz, .zip, .whl via Gtk.FileDialog
        GIT_REMOTE       // GitHub/GitLab URL or user/repo (remotes::install_github / pip git+)
    }

    public enum PythonEngine {
        AUTO,  // Uses uv if found on PATH, otherwise pip
        UV,    // Force uv
        PIP    // Force python -m pip
    }
}
```

### 1.2 Binary Detection Utility (`uv`)
Add a helper to detect `uv` presence on host or virtual environment:

```vala
public class EnvironmentTools {
    public static bool has_uv () {
        string? uv_path = GLib.Environment.find_program_in_path ("uv");
        return uv_path != null && uv_path.length > 0;
    }

    public static string get_uv_path () {
        return GLib.Environment.find_program_in_path ("uv") ?? "uv";
    }
}
```

---

## 2. UI/UX Specification (Libadwaita 1.5+)

The modal dialog (`Adw.Dialog`) is redesigned with an `Adw.ViewSwitcher` / `Adw.ViewStack` dividing install sources into three clean tabs:

```
┌────────────────────────────────────────────────────────┐
│ [Cancel]             Install Packages        [Install] │
├────────────────────────────────────────────────────────┤
│     [  Repository  ]  [ Local File ]  [  Git URL  ]    │
├────────────────────────────────────────────────────────┤
│ Ecosystem:  (•) R (CRAN)     ( ) Python (PyPI)         │
│ Python Installer: [ ⚡ uv (Fastest)  |  pip (Standard) ]│
│                                                        │
│ [Tab 1: Repository]                                    │
│ Quick Curated Bundles:                                 │
│ [tidyverse] [data.table] [ggplot2] [shiny] [quarto]   │
│ Package Names: [ tidyverse, dplyr                    ] │
│                                                        │
│ [Tab 2: Local File]                                    │
│ Archive File: [/home/user/Downloads/pkg.tar.gz] [Browse│
│ Type: Source Archive (R repos=NULL / pip wheel)        │
│                                                        │
│ [Tab 3: Git URL]                                       │
│ Git Repo / Spec: [ tidyverse/ggplot2 or https://... ]  │
│                                                        │
│ Target Library: .venv/site-packages [Sandboxed Badge]  │
│ [x] Install dependencies automatically                 │
└────────────────────────────────────────────────────────┘
```

---

## 3. Step-by-Step Implementation Tasks

### Task 1: Update `PackageInstallerDialog.vala` Header & Models
- **File**: `src/ui/PackageInstallerDialog.vala`
- Add `InstallSourceMode` and `PythonEngine` enums.
- Update `ProjectContext` to store detected `has_uv` boolean and preferred `PythonEngine`.
- Update `PackageIndexCache` to include curated popular packages for R (`tidyverse`, `data.table`, `ggplot2`, `shiny`, `quarto`, `lme4`, `BiocManager`) and Python (`numpy`, `pandas`, `polars`, `scipy`, `matplotlib`, `torch`, `scikit-learn`, `jupyter`).

### Task 2: Build Multi-Tab Modal UI (`PackageInstallerModal`)
- Replace the single `Gtk.Entry` box with an `Adw.ViewStack` and `Adw.ViewSwitcher`:
  1. **Page 1: Repository (`REPOSITORY`)**:
     - Quick-add chip buttons for top data science bundles.
     - Live search entry with autocomplete popover (existing logic preserved).
     - CRAN Mirror selector row (`Cloud R-Project (default)`, `Posit PPM (Binaries)`).
  2. **Page 2: Local Archive (`LOCAL_ARCHIVE`)**:
     - `Adw.ActionRow` with path entry and `Browse...` button.
     - Click handler opens modern `Gtk.FileDialog` with filters for `*.tar.gz`, `*.tgz`, `*.zip`, `*.whl`.
     - Auto-detects ecosystem from file extension (`.whl` -> Python, `.tar.gz` -> contextual or user toggle).
  3. **Page 3: Git Remote (`GIT_REMOTE`)**:
     - Entry for `username/repo` or full `https://github.com/...` URL.
     - Branch / Tag optional entry.
- **Python Installer Row**:
  - Show an `Adw.ComboRow` or segmented switcher for Python installer:
    - If `has_uv == true`: Show `⚡ uv (Ultra-fast)` and `pip`.
    - If `has_uv == false`: Disable/dim `uv` with subtitle `uv not installed in PATH`.

### Task 3: Command Generator Logic
Update command builders in `src/ui/PackageInstallerDialog.vala`:

#### 3.1 R Commands:
```vala
private string build_r_command (InstallSourceMode mode, GenericArray<string> pkgs, bool deps, bool sandboxed, string? mirror_url) {
    string deps_str = deps ? "TRUE" : "FALSE";
    string repo_str = mirror_url ?? "https://cloud.r-project.org";

    switch (mode) {
        case InstallSourceMode.REPOSITORY:
            string pkg_vec = format_r_vector (pkgs);
            if (sandboxed) {
                return @"renv::install(packages = $pkg_vec, dependencies = $deps_str); renv::snapshot(prompt = FALSE)";
            } else {
                return @"install.packages($pkg_vec, repos = \"$repo_str\", dependencies = $deps_str)";
            }

        case InstallSourceMode.LOCAL_ARCHIVE:
            string file_path = pkgs[0];
            return @"install.packages(\"$file_path\", repos = NULL, type = \"source\", dependencies = $deps_str)";

        case InstallSourceMode.GIT_REMOTE:
            string repo_spec = pkgs[0];
            return @"if (!requireNamespace(\"remotes\", quietly = TRUE)) install.packages(\"remotes\"); remotes::install_github(\"$repo_spec\", dependencies = $deps_str)";

        default:
            return "";
    }
}
```

#### 3.2 Python Commands (`uv` vs `pip`):
```vala
private void build_python_command (
    InstallSourceMode mode,
    PythonEngine engine,
    GenericArray<string> pkgs,
    bool deps,
    out string binary,
    out string[] args
) {
    bool use_uv = (engine == PythonEngine.UV) || (engine == PythonEngine.AUTO && EnvironmentTools.has_uv ());
    bool is_sandboxed = context.is_sandboxed;
    string venv_dir = Path.build_filename (context.root_dir, ".venv");
    string venv_py = Path.build_filename (venv_dir, "bin", "python");

    var arg_list = new GenericArray<string> ();

    if (use_uv) {
        binary = EnvironmentTools.get_uv_path ();
        arg_list.add (binary);
        arg_list.add ("pip");
        arg_list.add ("install");

        if (is_sandboxed && FileUtils.test (venv_py, FileTest.EXISTS)) {
            arg_list.add ("--python");
            arg_list.add (venv_py);
        } else if (!is_sandboxed) {
            arg_list.add ("--system");
        }

        if (!deps) {
            arg_list.add ("--no-deps");
        }
    } else {
        // Standard pip fallback
        binary = (is_sandboxed && FileUtils.test (venv_py, FileTest.EXISTS)) ? venv_py : "python3";
        arg_list.add (binary);
        arg_list.add ("-m");
        arg_list.add ("pip");
        arg_list.add ("install");

        if (!deps) {
            arg_list.add ("--no-deps");
        }
    }

    // Add targets
    if (mode == InstallSourceMode.GIT_REMOTE) {
        arg_list.add (@"git+$(pkgs[0])");
    } else {
        for (int i = 0; i < pkgs.length; i++) {
            arg_list.add (pkgs[i]);
        }
    }

    args = to_array (arg_list);
}
```

### Task 4: Window Execution & Lockfile Sync
- **File**: `src/Window.vala`
- Update `run_python_pip_and_snapshot`:
  - Dynamically display `[Python/uv]` or `[Python/pip]` in console logs.
  - After successful installation in sandboxed projects:
    - If `uv` was used: Run `uv pip freeze > requirements.txt` or `SandboxController.snapshot_environment`.
    - If `pip` was used: Run standard lockfile freeze.
- For R:
  - Echo clean installation banner in dock console before running command.

### Task 5: Compilation, Testing & Verification
1. Recompile project:
   ```bash
   meson compile -C build
   ```
2. Run test suites:
   ```bash
   meson test -C build --print-errorlogs
   ```
3. Rebuild distributable packages:
   ```bash
   ./build-packages.sh
   ./build-rpm.sh
   ```

---

## 4. Key Verification Checklist for Gemini 3.8

- [ ] Does clicking `Browse...` open a native GTK4 `Gtk.FileDialog` filtering `.tar.gz`, `.tgz`, `.zip`, `.whl`?
- [ ] If `uv` is installed, is it detected automatically and labeled with `⚡ uv`?
- [ ] Does installing an R local archive execute `install.packages(..., repos = NULL, type = "source")`?
- [ ] Does installing via `uv` properly point to the sandboxed `.venv` without corrupting system Python?
- [ ] Do quick-add bundle chips (e.g. `[tidyverse]`, `[numpy]`) append cleanly to the package text entry?
