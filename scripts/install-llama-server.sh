#!/usr/bin/env bash
# Imladris: Installer & Manager for llama-server engines (Vulkan & CUDA)
set -euo pipefail

FLAVOR="${1:-vulkan}"
DEST_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/imladris/bin"
mkdir -p "${DEST_DIR}"

ARCH=$(uname -m)
if [ "${ARCH}" != "x86_64" ]; then
    echo "✖ Unsupported architecture for prebuilt binary: ${ARCH}" >&2
    exit 1
fi

TMP_DIR=$(mktemp -d -t imladris-llama-XXXXXX)
trap 'rm -rf "${TMP_DIR}"' EXIT

# Resolve active nightly release tag
RELEASE_TAG="b11669"
if command -v curl >/dev/null 2>&1; then
    RESOLVED_TAG=$(curl -sL -m 6 "https://github.com/ggml-org/llama.cpp/releases/download/v0.7.0/nightly-tag.txt" 2>/dev/null | tr -d '[:space:]' || true)
    if [ -n "${RESOLVED_TAG}" ]; then
        RELEASE_TAG="${RESOLVED_TAG}"
    fi
fi

echo "--> Target engine flavor: [${FLAVOR}], release tag: [${RELEASE_TAG}]"

if [ "${FLAVOR}" = "cuda" ]; then
    TARGET_SUBDIR="${DEST_DIR}/cuda"
    TARGET_BIN="${DEST_DIR}/llama-server-cuda"
    mkdir -p "${TARGET_SUBDIR}"

    CUDA_TARBALL="llama-${RELEASE_TAG}-bin-ubuntu-cuda-12.8-x64.tar.gz"
    CUDART_TARBALL="cudart-llama-${RELEASE_TAG}-bin-ubuntu-cuda-12.8-x64.tar.gz"

    URL_CUDA="https://github.com/ggml-org/llama.cpp/releases/download/${RELEASE_TAG}/${CUDA_TARBALL}"
    URL_CUDART="https://github.com/ggml-org/llama.cpp/releases/download/${RELEASE_TAG}/${CUDART_TARBALL}"

    echo "--> Downloading NVIDIA CUDA binary package: ${URL_CUDA}"
    curl -sSfL --connect-timeout 20 --max-time 1800 -o "${TMP_DIR}/cuda.tar.gz" "${URL_CUDA}"
    tar -xzf "${TMP_DIR}/cuda.tar.gz" --strip-components=1 -C "${TARGET_SUBDIR}"

    echo "--> Downloading CUDA runtime libraries: ${URL_CUDART}"
    if curl -sSfL --connect-timeout 20 --max-time 900 -o "${TMP_DIR}/cudart.tar.gz" "${URL_CUDART}" 2>/dev/null; then
        tar -xzf "${TMP_DIR}/cudart.tar.gz" --strip-components=1 -C "${TARGET_SUBDIR}" || true
    fi

    # Ensure symlinks exist
    for so in "${TARGET_SUBDIR}"/lib*.so.*.*.*; do
        [ -f "$so" ] || continue
        base="${so%.*.*}"
        major="${so%.*}"
        [ ! -e "$major" ] && ln -sf "$(basename "$so")" "$major" 2>/dev/null || true
        [ ! -e "$base" ] && ln -sf "$(basename "$major")" "$base" 2>/dev/null || true
    done

    chmod 755 "${TARGET_SUBDIR}/llama-server" 2>/dev/null || true

    # Create wrapper launcher script
    cat << 'EOF_LAUNCHER' > "${TARGET_BIN}"
#!/bin/sh
DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$DIR/cuda/llama-server" "$@"
EOF_LAUNCHER
    chmod 755 "${TARGET_BIN}"
    cp -f "${TARGET_BIN}" "${DEST_DIR}/llama-server"
    echo "✔ Successfully installed NVIDIA CUDA engine to ${TARGET_SUBDIR}/llama-server"

else
    # Default: Vulkan / Universal GPU & CPU
    TARGET_SUBDIR="${DEST_DIR}/vulkan"
    TARGET_BIN="${DEST_DIR}/llama-server-vulkan"
    mkdir -p "${TARGET_SUBDIR}"

    VULKAN_TARBALL="llama-${RELEASE_TAG}-bin-ubuntu-vulkan-x64.tar.gz"
    URL_VULKAN="https://github.com/ggml-org/llama.cpp/releases/download/${RELEASE_TAG}/${VULKAN_TARBALL}"

    echo "--> Downloading Vulkan/Universal binary package: ${URL_VULKAN}"
    if ! curl -sSfL --connect-timeout 20 --max-time 1800 -o "${TMP_DIR}/vulkan.tar.gz" "${URL_VULKAN}" 2>/dev/null; then
        echo "--> Vulkan download failed, falling back to CPU archive..."
        CPU_TARBALL="llama-${RELEASE_TAG}-bin-ubuntu-x64.tar.gz"
        URL_CPU="https://github.com/ggml-org/llama.cpp/releases/download/${RELEASE_TAG}/${CPU_TARBALL}"
        curl -sSfL --connect-timeout 20 --max-time 1800 -o "${TMP_DIR}/vulkan.tar.gz" "${URL_CPU}"
    fi

    tar -xzf "${TMP_DIR}/vulkan.tar.gz" --strip-components=1 -C "${TARGET_SUBDIR}"

    # Ensure symlinks exist
    for so in "${TARGET_SUBDIR}"/lib*.so.*.*.*; do
        [ -f "$so" ] || continue
        base="${so%.*.*}"
        major="${so%.*}"
        [ ! -e "$major" ] && ln -sf "$(basename "$so")" "$major" 2>/dev/null || true
        [ ! -e "$base" ] && ln -sf "$(basename "$major")" "$base" 2>/dev/null || true
    done

    chmod 755 "${TARGET_SUBDIR}/llama-server" 2>/dev/null || true

    # Create wrapper launcher script
    cat << 'EOF_LAUNCHER' > "${TARGET_BIN}"
#!/bin/sh
DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$DIR/vulkan/llama-server" "$@"
EOF_LAUNCHER
    chmod 755 "${TARGET_BIN}"
    cp -f "${TARGET_BIN}" "${DEST_DIR}/llama-server"
    echo "✔ Successfully installed Vulkan/Universal engine to ${TARGET_SUBDIR}/llama-server"
fi

exit 0
