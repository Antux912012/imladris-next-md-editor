Name:           imladris
Version:        0.7.0
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
%meson_test

%files
%doc README.md
%{_bindir}/imladris
%{_datadir}/applications/io.github.Antux912012.Imladris.desktop
%{_datadir}/metainfo/io.github.Antux912012.Imladris.metainfo.xml
%{_datadir}/glib-2.0/schemas/io.github.Antux912012.Imladris.gschema.xml
%{_datadir}/icons/hicolor/*/apps/io.github.Antux912012.Imladris.*
%{_datadir}/icons/hicolor/scalable/actions/ribbon-toggle-symbolic.svg

%changelog
* Mon Oct 26 2026 Antonio De Gaetano <antux912012@users.noreply.github.com> - 0.7.0-1
- Release 0.7.0: 11-pillar expansion with clean UI launch modal, ribbon state machine, RStudio-style package installer, interactive console and inline code chunk outputs, pwd synchronization, and RStudio/Jupyter sandboxed exports.

* Mon Oct 26 2026 Antonio De Gaetano <antux912012@users.noreply.github.com> - 0.6.0-1
- Release 0.6.0: Categorized creation pop-up dialog, Sandboxed vs Standard project engine, .mallorn format, ODT/ODP export pipeline.
