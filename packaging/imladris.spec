Name:           imladris
Version:        0.12.1
Release:        1%{?dist}
Summary:        Scientific notebook studio and Markdown editor

License:        GPL-3.0-or-later
URL:            https://github.com/Antux912012/imladris-next-md-editor
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  gcc
BuildRequires:  meson >= 0.60
BuildRequires:  ninja-build
BuildRequires:  valac >= 0.56
BuildRequires:  desktop-file-utils
BuildRequires:  libappstream-glib
BuildRequires:  pkgconfig(gtk4) >= 4.12
BuildRequires:  pkgconfig(libadwaita-1) >= 1.5
BuildRequires:  pkgconfig(gtksourceview-5) >= 5.10
BuildRequires:  pkgconfig(webkitgtk-6.0)
BuildRequires:  pkgconfig(libsoup-3.0)
BuildRequires:  pkgconfig(json-glib-1.0)
BuildRequires:  pkgconfig(gee-0.8)
BuildRequires:  pkgconfig(gio-2.0)
BuildRequires:  pkgconfig(glib-2.0)

Requires:       hicolor-icon-theme
Recommends:     llama-cpp

%description
Imladris is a native Linux polyglot document studio and scientific Markdown
editor built with Vala, GTK4, Libadwaita, GtkSourceView 5, and WebKitGTK 6.0.
Featuring an adaptive ribbon interface, Imladris provides a distraction-free
writing environment for technical authors, data scientists, and researchers.

%prep
%autosetup -n %{name}-%{version}

%build
%meson
%meson_build

%install
%meson_install

%check
export GSETTINGS_BACKEND=memory
%meson_test

%files
%doc README.md
%{_bindir}/imladris
%{_datadir}/applications/io.github.Antux912012.Imladris.desktop
%{_datadir}/metainfo/io.github.Antux912012.Imladris.metainfo.xml
%{_datadir}/glib-2.0/schemas/io.github.Antux912012.Imladris.gschema.xml
%{_datadir}/icons/hicolor/*/apps/io.github.Antux912012.Imladris.*
%{_datadir}/icons/hicolor/scalable/actions/ribbon-toggle-symbolic.svg
%{_datadir}/imladris/

%changelog
* Wed Oct 28 2026 Antonio De Gaetano <antux912012@users.noreply.github.com> - 0.12.1-1
- Release 0.12.1: Elrond Local AI Server Bridge (Ollama, LM Studio, Cherry Studio, LocalAI) and Antigravity CLI (agy) harness integration; interactive file manager picker for image and video insertion with sandboxed /img auto-copy; Quarto video shortcodes and live HTML5 video preview rendering; About Imladris dialog.

* Wed Oct 28 2026 Antonio De Gaetano <antux912012@users.noreply.github.com> - 0.12.0-1
- Release 0.12.0: Internal llama.cpp engine rework, GNOME 51 Adw.Spinner modernization, inline editing toggle, left/right side panel docking, official vector AI model logos, and comprehensive architecture blueprint.

* Wed Oct 28 2026 Antonio De Gaetano <antux912012@users.noreply.github.com> - 0.11.0-1
- Release 0.11.0: 3-stop Elrond assistance slider, distro-aware llama.cpp setup, Vulkan/CUDA backend toggle, and comprehensive codebase deduplication and performance optimizations.

* Tue Oct 27 2026 Antonio De Gaetano <antux912012@users.noreply.github.com> - 0.10.0-1
- Release 0.10.0: Unified 'Write with Elrond Assistance (AI)' zero-config local copilot with Qwen2.5-Coder-3B, live RAM/VRAM telemetry status bar, and dedicated Packages Ribbon Tab with O(log N) binary search autocomplete and pak/uv acceleration.

* Mon Oct 26 2026 Antonio De Gaetano <antux912012@users.noreply.github.com> - 0.9.0-1
- Release 0.9.0: Automated micromamba data science toolchain manager and runtime resolution hierarchy.

* Mon Oct 26 2026 Antonio De Gaetano <antux912012@users.noreply.github.com> - 0.8.0-1
- Release 0.8.0: Transparent host R interpreter discovery and execution in Flatpak via flatpak-spawn, shared cache for plotting artifacts, and real-time package compilation log streaming.

* Mon Oct 26 2026 Antonio De Gaetano <antux912012@users.noreply.github.com> - 0.7.0-1
- Release 0.7.0: 11-pillar expansion with clean UI launch modal, ribbon state machine, RStudio-style package installer, interactive console and inline code chunk outputs, pwd synchronization, and RStudio/Jupyter sandboxed exports.

* Mon Oct 26 2026 Antonio De Gaetano <antux912012@users.noreply.github.com> - 0.6.0-1
- Release 0.6.0: Categorized creation pop-up dialog, Sandboxed vs Standard project engine, .mallorn format, ODT/ODP export pipeline.
