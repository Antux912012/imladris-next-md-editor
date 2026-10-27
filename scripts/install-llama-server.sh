#!/usr/bin/env bash
# Imladris: Automatic installer for local llama-server engine (llama.cpp)
set -euo pipefail

DEST_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/imladris/bin"
mkdir -p "${DEST_DIR}"

TARGET_BIN="${DEST_DIR}/llama-server"

# Check if already installed
if [ -x "${TARGET_BIN}" ]; then
    echo "✔ llama-server already installed at: ${TARGET_BIN}"
    "${TARGET_BIN}" --version 2>/dev/null || true
    exit 0
fi

echo "--> Fetching llama-server for Imladris Elrond Assistance..."

TMP_DIR=$(mktemp -d -t imladris-llama-XXXXXX)
trap 'rm -rf "${TMP_DIR}"' EXIT

ARCH=$(uname -m)
if [ "${ARCH}" != "x86_64" ]; then
    echo "✖ Unsupported architecture for prebuilt binary: ${ARCH}" >&2
    exit 1
fi

# Detect Vulkan support
HAS_VULKAN=false
if command -v vulkaninfo >/dev/null 2>&1 || [ -e /dev/dri/renderD128 ]; then
    HAS_VULKAN=true
fi

# Resolve latest release tag from GitHub API
RELEASE_TAG="b4834"
if command -v curl >/dev/null 2>&1; then
    LATEST_TAG=$(curl -sSf -m 8 "https://api.github.com/repos/ggml-org/llama.cpp/releases/latest" 2>/dev/null | grep '"tag_name":' | head -n1 | sed -E 's/.*"([^"]+)".*/\1/' || true)
    if [ -n "${LATEST_TAG}" ]; then
        RELEASE_TAG="${LATEST_TAG}"
    fi
fi

TARBALL="llama-${RELEASE_TAG}-bin-ubuntu-x64.tar.gz"
if [ "${HAS_VULKAN}" = true ]; then
    # Try vulkan build if available
    VULKAN_TARBALL="llama-${RELEASE_TAG}-bin-ubuntu-vulkan-x64.tar.gz"
    URL="https://github.com/ggml-org/llama.cpp/releases/download/${RELEASE_TAG}/${VULKAN_TARBALL}"
    echo "--> Attempting Vulkan-accelerated release: ${URL}"
    if curl -sSfL -m 60 -o "${TMP_DIR}/archive.tar.gz" "${URL}" 2>/dev/null; then
        echo "✔ Downloaded Vulkan build."
    else
        echo "--> Falling back to CPU/standard build..."
        URL="https://github.com/ggml-org/llama.cpp/releases/download/${RELEASE_TAG}/${TARBALL}"
        curl -sSfL -m 90 -o "${TMP_DIR}/archive.tar.gz" "${URL}"
    fi
else
    URL="https://github.com/ggml-org/llama.cpp/releases/download/${RELEASE_TAG}/${TARBALL}"
    echo "--> Downloading CPU release: ${URL}"
    curl -sSfL -m 90 -o "${TMP_DIR}/archive.tar.gz" "${URL}"
fi

tar -xzf "${TMP_DIR}/archive.tar.gz" -C "${TMP_DIR}"

# Locate llama-server executable inside extracted files
FOUND_BIN=$(find "${TMP_DIR}" -type f -name "llama-server" | head -n1)

if [ -z "${FOUND_BIN}" ]; then
    echo "✖ llama-server executable not found in release archive" >&2
    exit 1
fi

# Copy all shared libraries (.so) and the binary to DEST_DIR
find "${TMP_DIR}" -type f -name "*.so*" -exec cp -f {} "${DEST_DIR}/" \;
cp -f "${FOUND_BIN}" "${TARGET_BIN}"
chmod 755 "${TARGET_BIN}"

echo "✔ Successfully installed llama-server to ${TARGET_BIN}"
exit 0
