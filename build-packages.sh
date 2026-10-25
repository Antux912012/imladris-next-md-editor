#!/usr/bin/env bash
# Imladris Package Builder: .deb & Flatpak only (AppImage is strictly excluded)
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${PROJECT_DIR}"

APP_ID="org.gnome.Imladris"
VERSION=$(grep -m1 "version:" "${PROJECT_DIR}/meson.build" | sed -E "s/.*'([^']+)'.*/\1/")
ARCH="amd64"

echo "=== Building Imladris v${VERSION} Packaging ==="

if [[ "${1:-}" != "--deb-only" ]]; then
  # 1. Build Flatpak Bundle (.flatpak)
  echo "--> 1. Building Flatpak via Flatpak SDK staging & build-bundle..."
  rm -rf build-flatpak-app repo
  mkdir -p build-flatpak-app/files build-flatpak-app/var

  cat << 'EOF_META' > build-flatpak-app/metadata
[Application]
name=org.gnome.Imladris
runtime=org.gnome.Platform/x86_64/50
sdk=org.gnome.Sdk/x86_64/50
command=imladris

[Context]
shared=ipc;
sockets=fallback-x11;wayland;
devices=dri;
filesystems=home;
EOF_META

  flatpak run --system --command=bash --devel --filesystem="${PROJECT_DIR}" org.gnome.Sdk//50 -c \
    "cd '${PROJECT_DIR}' && rm -rf build-flatpak && meson setup build-flatpak --prefix=/app && meson compile -C build-flatpak && DESTDIR='${PROJECT_DIR}/build-flatpak-app/files' meson install -C build-flatpak"

  # Move /app prefix files to Flatpak root
  if [ -d "build-flatpak-app/files/app" ]; then
    cp -r build-flatpak-app/files/app/* build-flatpak-app/files/
    rm -rf build-flatpak-app/files/app
  fi

  flatpak build-finish build-flatpak-app \
    --command=imladris \
    --share=ipc \
    --socket=fallback-x11 \
    --socket=wayland \
    --device=dri \
    --filesystem=home \
    --talk-name=org.freedesktop.Flatpak

  flatpak build-export repo build-flatpak-app master
  flatpak build-bundle repo Imladris.flatpak "${APP_ID}" master
  echo "✔ Flatpak bundle generated: Imladris.flatpak ($(du -h Imladris.flatpak | cut -f1))"
fi

# 2. Build Debian Package (.deb)
echo "--> 2. Building Debian package via Flatpak SDK staging & dpkg-deb..."
rm -rf build-deb deb-root
flatpak run --system --command=bash --devel --filesystem="${PROJECT_DIR}" org.gnome.Sdk//50 -c \
  "cd '${PROJECT_DIR}' && meson setup build-deb --prefix=/usr && meson compile -C build-deb && DESTDIR='${PROJECT_DIR}/deb-root' meson install -C build-deb"

mkdir -p deb-root/DEBIAN
INSTALLED_SIZE=$(du -s deb-root/usr | cut -f1)

cat <<EOF > deb-root/DEBIAN/control
Package: imladris
Version: ${VERSION}
Section: editors
Priority: optional
Architecture: ${ARCH}
Installed-Size: ${INSTALLED_SIZE}
Maintainer: Antonio De Gaetano <antux912012@users.noreply.github.com>
Depends: libc6 (>= 2.34), libglib2.0-0t64 | libglib2.0-0 (>= 2.76), libgtk-4-1 (>= 4.12), libadwaita-1-0 (>= 1.5), libgtksourceview-5-0 (>= 5.10), libwebkitgtk-6.0-4 (>= 2.40), libsoup-3.0-0, libjson-glib-1.0-0
Homepage: https://github.com/Antux912012/imladris-next-md-editor
Description: Native Polyglot Studio with AI Assistance, Auto-Completion and MCP Server
 Imladris is a native Linux Markdown and Polyglot Studio built with
 Vala, GTK4, Libadwaita, GtkSourceView 5, and WebKitGTK 6.0.
 Features Dual AI Assistance (Online OpenAI-compatible + Offline llama.cpp),
 Model Context Protocol (MCP) server, and polyglot auto-completion.
 Supports Quarto (.qmd), R Markdown (.Rmd), Jupyter (.ipynb),
 TypeScript (.ts), HTML5 (.html), and Markdown (.md).
EOF

cat <<'EOF' > deb-root/DEBIAN/postinst
#!/bin/sh
set -e
if [ "$1" = "configure" ]; then
    if which update-desktop-database >/dev/null 2>&1; then
        update-desktop-database -q /usr/share/applications || true
    fi
    if which gtk-update-icon-cache >/dev/null 2>&1; then
        gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor || true
    fi
fi
exit 0
EOF

cat <<'EOF' > deb-root/DEBIAN/postrm
#!/bin/sh
set -e
if [ "$1" = "remove" ] || [ "$1" = "purge" ]; then
    if which update-desktop-database >/dev/null 2>&1; then
        update-desktop-database -q /usr/share/applications || true
    fi
    if which gtk-update-icon-cache >/dev/null 2>&1; then
        gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor || true
    fi
fi
exit 0
EOF

chmod 755 deb-root/DEBIAN/postinst deb-root/DEBIAN/postrm
DEB_NAME="imladris_${VERSION}_${ARCH}.deb"
dpkg-deb --build --root-owner-group deb-root "${DEB_NAME}"
echo "✔ Debian package generated: ${DEB_NAME} ($(du -h "${DEB_NAME}" | cut -f1))"

echo "=== Packaging Complete (.deb and Flatpak built; AppImage excluded) ==="
