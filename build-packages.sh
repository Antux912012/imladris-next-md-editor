#!/usr/bin/env bash
# Imladris Package Builder: .deb & Flatpak only (AppImage is strictly excluded)
set -euo pipefail

# Ensure ambient/inheritable capabilities are cleared if running inside a rootless Podman container
# so bubblewrap (bwrap) and flatpak commands work cleanly
if [ "$(id -u)" != "0" ] && command -v setpriv >/dev/null 2>&1; then
    if ! grep -q '^CapEff:[[:space:]]*0000000000000000$' /proc/self/status 2>/dev/null; then
        exec setpriv --inh-caps=-all --ambient-caps=-all "$0" "$@"
    fi
fi

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${PROJECT_DIR}"

APP_ID="io.github.Antux912012.Imladris"
BUNDLE_NAME="${APP_ID}.flatpak"
VERSION=$(grep -m1 "version:" "${PROJECT_DIR}/meson.build" | sed -E "s/.*'([^']+)'.*/\1/")
ARCH="amd64"

echo "=== Building ${APP_ID} v${VERSION} Packaging ==="

run_meson_build() {
    local build_dir="$1"
    local prefix_dir="$2"
    local dest_dir="$3"
    local sdk_ver="50"
    if flatpak info org.gnome.Sdk//51 >/dev/null 2>&1; then
        sdk_ver="51"
    fi
    if pkg-config --atleast-version=4.12 gtk4 && pkg-config --atleast-version=1.5 libadwaita-1 && pkg-config --exists gtksourceview-5 webkitgtk-6.0; then
        rm -rf "${build_dir}"
        meson setup "${build_dir}" --prefix="${prefix_dir}"
        meson compile -C "${build_dir}"
        DESTDIR="${dest_dir}" meson install -C "${build_dir}"
    else
        flatpak run --system --command=bash --devel --filesystem="${PROJECT_DIR}" org.gnome.Sdk//${sdk_ver} -c \
            "cd '${PROJECT_DIR}' && rm -rf '${build_dir}' && meson setup '${build_dir}' --prefix='${prefix_dir}' && meson compile -C '${build_dir}' && DESTDIR='${dest_dir}' meson install -C '${build_dir}'"
    fi
}

if [[ "${1:-}" != "--deb-only" ]]; then
  # 1. Build Flatpak Bundle (.flatpak)
  echo "--> 1. Building Flatpak (${BUNDLE_NAME})..."
  rm -rf build-flatpak-app repo Imladris.flatpak "${BUNDLE_NAME}"
  mkdir -p build-flatpak-app/files build-flatpak-app/var

  PLATFORM_VER="51"
  if ! flatpak info org.gnome.Platform//51 >/dev/null 2>&1; then
      PLATFORM_VER="50"
  fi
  SDK_VER="50"
  if flatpak info org.gnome.Sdk//51 >/dev/null 2>&1; then
      SDK_VER="51"
  fi

  cat << EOF_META > build-flatpak-app/metadata
[Application]
name=${APP_ID}
runtime=org.gnome.Platform/x86_64/${PLATFORM_VER}
sdk=org.gnome.Sdk/x86_64/${SDK_VER}
command=imladris

[Context]
shared=ipc;network;
sockets=fallback-x11;wayland;
devices=dri;
filesystems=home;~/.cache/imladris:create;
env=WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS=1;

[Session Bus Policy]
org.freedesktop.Flatpak=talk
EOF_META

  run_meson_build "build-flatpak" "/app" "${PROJECT_DIR}/build-flatpak-app/files"

  # Move /app prefix files to Flatpak root
  if [ -d "build-flatpak-app/files/app" ]; then
    cp -r build-flatpak-app/files/app/* build-flatpak-app/files/
    rm -rf build-flatpak-app/files/app
  fi

  # Bundle llama-server (Vulkan / Universal) inside Flatpak bundle
  if [ ! -f "build-flatpak-app/files/bin/llama-server" ]; then
    echo "--> Installing Vulkan llama-server inside Flatpak bundle..."
    if [ -d "${HOME}/.local/share/imladris/bin/vulkan" ]; then
      mkdir -p build-flatpak-app/files/bin build-flatpak-app/files/lib
      cp -f "${HOME}/.local/share/imladris/bin/vulkan/llama-server" build-flatpak-app/files/bin/
      cp -f "${HOME}/.local/share/imladris/bin/vulkan/llama-server" build-flatpak-app/files/bin/llama-server-vulkan
      cp -f "${HOME}/.local/share/imladris/bin/vulkan/"*.so* build-flatpak-app/files/lib/ 2>/dev/null || true
      echo "✔ Bundled Vulkan llama-server from local cache."
    else
      XDG_DATA_HOME="${PROJECT_DIR}/build-flatpak-app/files/share" "${PROJECT_DIR}/scripts/install-llama-server.sh" vulkan || true
      if [ -f "${PROJECT_DIR}/build-flatpak-app/files/share/imladris/bin/llama-server" ]; then
        mkdir -p build-flatpak-app/files/bin build-flatpak-app/files/lib
        cp -f "${PROJECT_DIR}/build-flatpak-app/files/share/imladris/bin/llama-server" build-flatpak-app/files/bin/
        cp -f "${PROJECT_DIR}/build-flatpak-app/files/share/imladris/bin/llama-server" build-flatpak-app/files/bin/llama-server-vulkan
        cp -f "${PROJECT_DIR}/build-flatpak-app/files/share/imladris/bin/vulkan/"*.so* build-flatpak-app/files/lib/ 2>/dev/null || true
        echo "✔ Bundled Vulkan llama-server from installer script."
      fi
    fi
  fi

  # Generate AppStream catalog XML for Software Center & Bazaar
  mkdir -p "build-flatpak-app/files/share/app-info/xmls" \
           "build-flatpak-app/files/share/app-info/icons/flatpak/128x128" \
           "build-flatpak-app/files/share/app-info/icons/flatpak/64x64"
  cp "data/icons/hicolor/128x128/apps/${APP_ID}.png" "build-flatpak-app/files/share/app-info/icons/flatpak/128x128/${APP_ID}.png"
  cp "data/icons/hicolor/64x64/apps/${APP_ID}.png" "build-flatpak-app/files/share/app-info/icons/flatpak/64x64/${APP_ID}.png"

  python3 - "build-flatpak-app/files/share/app-info/xmls/${APP_ID}.xml.gz" "data/${APP_ID}.metainfo.xml" "${APP_ID}" << 'PYEOF'
import gzip, sys
xml_gz, metainfo_path, app_id = sys.argv[1], sys.argv[2], sys.argv[3]
with open(metainfo_path, "r", encoding="utf-8") as mf:
    raw = mf.read()
body = raw.split("<component", 1)[1]
composed = f'<?xml version="1.0" encoding="UTF-8"?>\n<components version="0.8" origin="{app_id}">\n  <component{body}\n</components>\n'
with gzip.open(xml_gz, "wt", encoding="utf-8") as f:
    f.write(composed)
PYEOF

  # Compile GSettings schemas for Flatpak
  if [ -d "build-flatpak-app/files/share/glib-2.0/schemas" ]; then
    glib-compile-schemas "build-flatpak-app/files/share/glib-2.0/schemas"
  fi

  flatpak build-finish build-flatpak-app \
    --command=imladris \
    --share=ipc \
    --share=network \
    --socket=fallback-x11 \
    --socket=wayland \
    --device=dri \
    --filesystem=home \
    --filesystem=~/.cache/imladris:create \
    --env=WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS=1 \
    --talk-name=org.freedesktop.Flatpak \
    --metadata=X-DConf=default-settings

  flatpak build-export repo build-flatpak-app master
  flatpak build-update-repo repo || true
  flatpak build-bundle repo "${BUNDLE_NAME}" "${APP_ID}" master
  echo "✔ Flatpak bundle generated: ${BUNDLE_NAME} ($(du -h "${BUNDLE_NAME}" | cut -f1))"
fi

# 2. Build Debian Package (.deb)
echo "--> 2. Building Debian package via staging & dpkg-deb..."
rm -rf build-deb deb-root imladris_*.deb
run_meson_build "build-deb" "/usr" "${PROJECT_DIR}/deb-root"

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
Depends: libc6 (>= 2.34), libglib2.0-0t64 | libglib2.0-0 (>= 2.76), libgtk-4-1 (>= 4.12), libadwaita-1-0 (>= 1.5), libgtksourceview-5-0 (>= 5.10), libwebkitgtk-6.0-4 (>= 2.40), libsoup-3.0-0, libjson-glib-1.0-0, libgee-0.8-2
Recommends: llama.cpp | llama-cpp
Homepage: https://github.com/Antux912012/imladris-next-md-editor
Description: Native Polyglot Studio with AI Assistance, Auto-Completion and MCP Server
 Imladris is a native Linux Markdown and Polyglot Studio built with
 Vala, GTK4, Libadwaita, GtkSourceView 5, and WebKitGTK 6.0.
 Features Multi-Provider AI Assistance (Google Gemini, DeepSeek, Kimi, Qwen, Ollama, and LM Studio),
 Model Context Protocol (MCP) server, and 4-Quadrant RStudio Docking.
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
    if which glib-compile-schemas >/dev/null 2>&1; then
        glib-compile-schemas /usr/share/glib-2.0/schemas || true
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
    if which glib-compile-schemas >/dev/null 2>&1; then
        glib-compile-schemas /usr/share/glib-2.0/schemas || true
    fi
fi
exit 0
EOF

chmod 755 deb-root/DEBIAN/postinst deb-root/DEBIAN/postrm
DEB_NAME="imladris_${VERSION}_${ARCH}.deb"
dpkg-deb --build --root-owner-group deb-root "${DEB_NAME}"
echo "✔ Debian package generated: ${DEB_NAME} ($(du -h "${DEB_NAME}" | cut -f1))"

echo "=== Packaging Complete (.deb and Flatpak built; AppImage excluded) ==="
