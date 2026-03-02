#!/usr/bin/env bash
# Install Darwin (macOS) and Windows cross-compilation toolchains so builds do not fail or get skipped.
# Copyright (c) eCloudseal Inc.  All rights reserved.  Author: Lai Hou Chang (James Lai)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILDER_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CROSS_DIR="${CROSS_TOOLCHAINS_DIR:-${BUILDER_ROOT}/.cross-toolchains}"
OSXCROSS_ROOT="${CROSS_DIR}/osxcross"
MACOS_SDK_VERSION="${MACOS_SDK_VERSION:-14.0}"

if [[ -f "${BUILDER_ROOT}/config.env" ]]; then
    set -a
    source "${BUILDER_ROOT}/config.env"
    set +a
fi

[[ "${SKIP_CROSS_TOOLCHAINS:-0}" = "1" ]] && { echo "==> Skipping cross toolchains (SKIP_CROSS_TOOLCHAINS=1)"; exit 0; }

echo "==> Ensuring Darwin and Windows cross-compilation toolchains..."

need_sudo=
# ---- Windows x86_64: MinGW（由 setup-build-env 階段已取得 sudo，此處直接安裝）----
if ! command -v x86_64-w64-mingw32-gcc &>/dev/null && ! command -v x86_64-w64-mingw32-g++ &>/dev/null; then
    echo "    Installing MinGW-w64 for Windows x86_64..."
    sudo apt-get update -qq
    sudo apt-get install -y gcc-mingw-w64 g++-mingw-w64
    echo "    MinGW-w64 (x86_64) installed."
fi

# ---- Windows arm64: MinGW（若無法安裝則略過此平台，其餘平台照常建置）----
rm -f "${BUILDER_ROOT}/.cross-toolchains.env"
if [[ "${SKIP_WINDOWS_ARM64:-0}" = "1" ]]; then
    echo "    Skipping Windows arm64 toolchain (SKIP_WINDOWS_ARM64=1)."
    echo 'export SKIP_WINDOWS_ARM64=1' > "${BUILDER_ROOT}/.cross-toolchains.env"
elif ! command -v aarch64-w64-mingw32-gcc &>/dev/null; then
    echo "    Installing MinGW-w64 for Windows arm64 (gcc-aarch64-w64-mingw32, g++-aarch64-w64-mingw32)..."
    sudo apt-get update -qq
    sudo apt-get install -y gcc-aarch64-w64-mingw32 g++-aarch64-w64-mingw32 2>/dev/null || true
    if ! command -v aarch64-w64-mingw32-gcc &>/dev/null; then
        echo "    (若出現 Unable to locate package：此套件多數 Ubuntu/Debian 預設源沒有，屬正常；將略過 Windows arm64 或嘗試從來源編譯)"
        echo "    Trying to build aarch64-w64-mingw32 from source (Windows-on-ARM-Experiments)..."
        BUILD_DIR="${CROSS_DIR}/mingw-woarm64-build"
        mkdir -p "${CROSS_DIR}"
        if [[ ! -d "${BUILD_DIR}/.git" ]]; then
            git clone --depth 1 https://github.com/Windows-on-ARM-Experiments/mingw-woarm64-build.git "${BUILD_DIR}" 2>/dev/null || true
        fi
        if [[ -x "${BUILD_DIR}/build.sh" ]]; then
            (cd "${BUILD_DIR}" && ./build.sh 2>&1) && export PATH="${BUILD_DIR}/install/bin:${PATH}" || true
        fi
    fi
    if ! command -v aarch64-w64-mingw32-gcc &>/dev/null; then
        echo "    Warning: aarch64-w64-mingw32 not found. Skipping Windows arm64 (ci-windows-arm64-mingw); other platforms will still build."
        echo "    To enable: install gcc-aarch64-w64-mingw32 (e.g. from PPA) or set TUNNEL_PRESETS in config.env without ci-windows-arm64-mingw."
        echo 'export SKIP_WINDOWS_ARM64=1' > "${BUILDER_ROOT}/.cross-toolchains.env"
    else
        echo "    MinGW-w64 (Windows arm64) ready."
    fi
else
    echo "    MinGW-w64 (Windows arm64) already available."
fi

# ---- Darwin (macOS): osxcross ----
if [[ "$(uname -s)" != "Darwin" ]]; then
    if [[ ! -x "${OSXCROSS_ROOT}/target/bin/o64-clang" ]] && [[ ! -x "${OSXCROSS_ROOT}/target/bin/arm64-apple-darwin20.4-clang" ]]; then
        echo "    Setting up osxcross for Darwin (macOS) cross-compile..."
        mkdir -p "${CROSS_DIR}"
        if [[ ! -d "${OSXCROSS_ROOT}/.git" ]]; then
            if [[ -d "${OSXCROSS_ROOT}" ]]; then
                rm -rf "${OSXCROSS_ROOT}"
            fi
            git clone --depth 1 https://github.com/tpoechtrager/osxcross.git "${OSXCROSS_ROOT}"
        fi
        SDK_TARBALL="${CROSS_DIR}/MacOSX${MACOS_SDK_VERSION}.sdk.tar.xz"
        if [[ ! -f "${SDK_TARBALL}" ]]; then
            echo "    Downloading MacOSX SDK..."
            for ver in 12.3 11.3; do
                if curl -sSL -o "${CROSS_DIR}/MacOSX${ver}.sdk.tar.xz" "https://github.com/phracker/MacOSX-SDKs/releases/download/${ver}/MacOSX${ver}.sdk.tar.xz" 2>/dev/null && [[ -f "${CROSS_DIR}/MacOSX${ver}.sdk.tar.xz" ]]; then
                    SDK_TARBALL="${CROSS_DIR}/MacOSX${ver}.sdk.tar.xz"
                    MACOS_SDK_VERSION="${ver}"
                    break
                fi
            done
        fi
        if [[ ! -f "${SDK_TARBALL}" ]]; then
            echo "    Error: Could not download MacOSX SDK. Place SDK tarball in ${CROSS_DIR} (e.g. MacOSX12.3.sdk.tar.xz) and re-run." >&2
            exit 1
        fi
        cp -f "${SDK_TARBALL}" "${OSXCROSS_ROOT}/tarballs/" 2>/dev/null || true
        (cd "${OSXCROSS_ROOT}" && UNATTENDED=1 OSX_VERSION_MIN=10.13 ./build.sh 2>&1) || {
            echo "    Error: osxcross build failed. Cannot build Darwin targets." >&2
            exit 1
        }
        if [[ -d "${OSXCROSS_ROOT}/target/bin" ]]; then
            echo "    osxcross ready at ${OSXCROSS_ROOT}"
            export PATH="${OSXCROSS_ROOT}/target/bin:${PATH}"
        else
            echo "    Error: osxcross target/bin not found after build." >&2
            exit 1
        fi
    else
        echo "    osxcross already present at ${OSXCROSS_ROOT}"
        export PATH="${OSXCROSS_ROOT}/target/bin:${PATH}"
    fi
else
    echo "    Host is Darwin; native macOS build (no osxcross needed)."
fi

echo "==> Cross toolchains check done."
