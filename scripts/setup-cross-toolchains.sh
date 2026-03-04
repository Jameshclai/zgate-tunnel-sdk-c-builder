#!/usr/bin/env bash
# Install Darwin (macOS) and Windows cross-compilation toolchains so builds do not fail or get skipped.
# Copyright (c) eCloudseal Inc.  All rights reserved.  Author: Lai Hou Chang (James Lai)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILDER_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CROSS_DIR="${CROSS_TOOLCHAINS_DIR:-${BUILDER_ROOT}/.cross-toolchains}"
OSXCROSS_ROOT="${CROSS_DIR}/osxcross"
MACOS_SDK_VERSION="${MACOS_SDK_VERSION:-11.3}"

if [[ -f "${BUILDER_ROOT}/config.env" ]]; then
    set -a
    source "${BUILDER_ROOT}/config.env"
    set +a
fi

[[ "${SKIP_CROSS_TOOLCHAINS:-0}" = "1" ]] && { echo "==> Skipping cross toolchains (SKIP_CROSS_TOOLCHAINS=1)"; exit 0; }

# 僅在 TUNNEL_PRESETS 有指定對應平台時才安裝該工具鏈，避免一鍵建置 Linux+Windows 時安裝 osxcross
PRESETS="${TUNNEL_PRESETS:-}"
NEED_MACOS=0
NEED_WINDOWS_ARM64=0
[[ "${PRESETS}" = *ci-macOS-x64* || "${PRESETS}" = *ci-macOS-arm64* ]] && NEED_MACOS=1
[[ "${PRESETS}" = *ci-windows-arm64-mingw* ]] && NEED_WINDOWS_ARM64=1
# 若 TUNNEL_PRESETS 未設定則預設全部需要（相容舊行為）
[[ -z "${PRESETS}" ]] && NEED_MACOS=1 && NEED_WINDOWS_ARM64=1

echo "==> Ensuring Darwin and Windows cross-compilation toolchains..."

need_sudo=
# 非互動模式：若有 SUDO_PASS 則用 sudo -S 執行後續 sudo 指令
sudo_cmd() {
    if [[ -n "${SUDO_PASS:-}" ]]; then
        echo "${SUDO_PASS}" | sudo -S -p "" "$@"
    else
        sudo "$@"
    fi
}

# ---- Linux ARM：當 TUNNEL_PRESETS 含 ci-linux-arm64 / ci-linux-arm 時，確保交叉編譯器已安裝 ----
[[ "${PRESETS}" = *ci-linux-arm64* ]] && NEED_LINUX_ARM64=1 || NEED_LINUX_ARM64=0
[[ "${PRESETS}" = *ci-linux-arm* ]] && NEED_LINUX_ARM=1 || NEED_LINUX_ARM=0
[[ -z "${PRESETS}" ]] && NEED_LINUX_ARM64=1 && NEED_LINUX_ARM=1
if [[ "${NEED_LINUX_ARM64}" = "1" ]] && ! command -v aarch64-linux-gnu-gcc &>/dev/null; then
    echo "    Installing cross-compiler for Linux arm64 (aarch64-linux-gnu-gcc)..."
    sudo_cmd apt-get update -qq
    sudo_cmd apt-get install -y gcc-aarch64-linux-gnu g++-aarch64-linux-gnu
    echo "    Linux arm64 cross-compiler installed."
fi
if [[ "${NEED_LINUX_ARM}" = "1" ]] && ! command -v arm-linux-gnueabihf-gcc &>/dev/null; then
    echo "    Installing cross-compiler for Linux arm (arm-linux-gnueabihf-gcc)..."
    sudo_cmd apt-get update -qq
    sudo_cmd apt-get install -y gcc-arm-linux-gnueabihf g++-arm-linux-gnueabihf
    echo "    Linux arm cross-compiler installed."
fi

# ---- Windows x86_64: MinGW（由 setup-build-env 階段已取得 sudo，此處直接安裝）----
if ! command -v x86_64-w64-mingw32-gcc &>/dev/null && ! command -v x86_64-w64-mingw32-g++ &>/dev/null; then
    echo "    Installing MinGW-w64 for Windows x86_64..."
    sudo_cmd apt-get update -qq
    sudo_cmd apt-get install -y gcc-mingw-w64 g++-mingw-w64
    echo "    MinGW-w64 (x86_64) installed."
fi

# ---- Windows arm64: MinGW（若 TUNNEL_PRESETS 未含 ci-windows-arm64-mingw 則略過）----
rm -f "${BUILDER_ROOT}/.cross-toolchains.env"
if [[ "${NEED_WINDOWS_ARM64}" = "0" ]]; then
    echo "    Skipping Windows arm64 toolchain (not in TUNNEL_PRESETS)."
    echo 'export SKIP_WINDOWS_ARM64=1' > "${BUILDER_ROOT}/.cross-toolchains.env"
elif [[ "${SKIP_WINDOWS_ARM64:-0}" = "1" ]]; then
    echo "    Skipping Windows arm64 toolchain (SKIP_WINDOWS_ARM64=1)."
    echo 'export SKIP_WINDOWS_ARM64=1' > "${BUILDER_ROOT}/.cross-toolchains.env"
elif ! command -v aarch64-w64-mingw32-gcc &>/dev/null; then
    echo "    Installing MinGW-w64 for Windows arm64 (gcc-aarch64-w64-mingw32, g++-aarch64-w64-mingw32)..."
    sudo_cmd apt-get update -qq
    sudo_cmd apt-get install -y gcc-aarch64-w64-mingw32 g++-aarch64-w64-mingw32 2>/dev/null || true
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

# ---- Darwin (macOS): osxcross（僅當 TUNNEL_PRESETS 含 ci-macOS-* 時執行）----
# 驗證是否為有效 XZ 壓縮檔（避免 404 被存成 "Not Found"）
is_valid_sdk() {
    [[ -f "${1}" ]] && [[ -s "${1}" ]] && xz -t "${1}" 2>/dev/null
}
if [[ "${NEED_MACOS}" = "0" ]]; then
    echo "    Skipping osxcross (no macOS preset in TUNNEL_PRESETS)."
elif [[ "$(uname -s)" != "Darwin" ]]; then
    if [[ ! -x "${OSXCROSS_ROOT}/target/bin/o64-clang" ]] && [[ ! -x "${OSXCROSS_ROOT}/target/bin/arm64-apple-darwin20.4-clang" ]]; then
        echo "    Setting up osxcross for Darwin (macOS) cross-compile..."
        mkdir -p "${CROSS_DIR}"
        if [[ ! -d "${OSXCROSS_ROOT}/.git" ]]; then
            if [[ -d "${OSXCROSS_ROOT}" ]]; then
                rm -rf "${OSXCROSS_ROOT}"
            fi
            git clone --depth 1 https://github.com/tpoechtrager/osxcross.git "${OSXCROSS_ROOT}"
        fi
        SDK_TARBALL=""
        # 優先使用已存在且有效的快取
        for v in ${MACOS_SDK_VERSION} 11.3 11.1 11.0 10.15; do
            candidate="${CROSS_DIR}/MacOSX${v}.sdk.tar.xz"
            if is_valid_sdk "${candidate}"; then
                SDK_TARBALL="${candidate}"
                MACOS_SDK_VERSION="${v}"
                echo "    Using cached MacOSX SDK: MacOSX${v}.sdk.tar.xz"
                break
            fi
            [[ -f "${candidate}" ]] && rm -f "${candidate}"
        done
        if [[ -z "${SDK_TARBALL}" ]]; then
            echo "    Downloading MacOSX SDK from phracker/MacOSX-SDKs..."
            for ver in 11.3 11.1 11.0 10.15; do
                url="https://github.com/phracker/MacOSX-SDKs/releases/download/${ver}/MacOSX${ver}.sdk.tar.xz"
                dest="${CROSS_DIR}/MacOSX${ver}.sdk.tar.xz"
                if curl -sSLf -o "${dest}" "${url}" 2>/dev/null && is_valid_sdk "${dest}"; then
                    SDK_TARBALL="${dest}"
                    MACOS_SDK_VERSION="${ver}"
                    echo "    Downloaded MacOSX${ver}.sdk.tar.xz"
                    break
                fi
                rm -f "${dest}"
            done
        fi
        if [[ -z "${SDK_TARBALL}" ]] || [[ ! -f "${SDK_TARBALL}" ]]; then
            echo "    Error: Could not download valid MacOSX SDK. Place a valid SDK tarball in ${CROSS_DIR} (e.g. MacOSX11.3.sdk.tar.xz from phracker/MacOSX-SDKs) and re-run." >&2
            exit 1
        fi
        mkdir -p "${OSXCROSS_ROOT}/tarballs"
        cp -f "${SDK_TARBALL}" "${OSXCROSS_ROOT}/tarballs/"
        (cd "${OSXCROSS_ROOT}" && UNATTENDED=1 OSX_VERSION_MIN=10.13 ./build.sh 2>&1) || {
            echo "    Error: osxcross build failed. Skipping macOS presets; other platforms will still build." >&2
            echo 'export SKIP_MACOS=1' >> "${BUILDER_ROOT}/.cross-toolchains.env"
            exit 0
        }
        if [[ -d "${OSXCROSS_ROOT}/target/bin" ]]; then
            echo "    osxcross ready at ${OSXCROSS_ROOT}"
            export PATH="${OSXCROSS_ROOT}/target/bin:${PATH}"
        else
            echo "    Error: osxcross target/bin not found after build." >&2
            echo 'export SKIP_MACOS=1' >> "${BUILDER_ROOT}/.cross-toolchains.env"
            exit 0
        fi
    else
        echo "    osxcross already present at ${OSXCROSS_ROOT}"
        export PATH="${OSXCROSS_ROOT}/target/bin:${PATH}"
    fi
else
    echo "    Host is Darwin; native macOS build (no osxcross needed)."
fi

echo "==> Cross toolchains check done."
