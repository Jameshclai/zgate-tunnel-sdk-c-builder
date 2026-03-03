#!/usr/bin/env bash
# Build zgate-tunnel-sdk-c for multiple platforms using CMake presets.
# Copyright (c) eCloudseal Inc.  All rights reserved.  Author: Lai Hou Chang (James Lai)
# Expects: ZGATE_TUNNEL_OUT (or OUTPUT_DIR + ZITI_TUNNEL_SDK_VERSION), ZGATE_SDK_DIR
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILDER_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ -f "${BUILDER_ROOT}/config.env" ]]; then
    set -a
    source "${BUILDER_ROOT}/config.env"
    set +a
fi

if [[ -z "${ZGATE_TUNNEL_OUT:-}" ]]; then
    if [[ -z "${OUTPUT_DIR:-}" ]] || [[ -z "${ZITI_TUNNEL_SDK_VERSION:-}" ]]; then
        echo "Error: ZGATE_TUNNEL_OUT or (OUTPUT_DIR + ZITI_TUNNEL_SDK_VERSION) must be set." >&2
        exit 1
    fi
    ZGATE_TUNNEL_OUT="${OUTPUT_DIR}/zgate-tunnel-sdk-c-${ZITI_TUNNEL_SDK_VERSION}"
fi
if [[ ! -d "${ZGATE_TUNNEL_OUT}" ]]; then
    echo "Error: Directory not found: ${ZGATE_TUNNEL_OUT}" >&2
    exit 1
fi

# 從產出目錄名取得 tunnel SDK 版本（與 ziti-tunnel-sdk-c 一致），傳給 CMake 避免 git describe 用到上層 repo 的 tag
TUNNEL_SDK_VERSION=$(basename "${ZGATE_TUNNEL_OUT}" | sed 's/^zgate-tunnel-sdk-c-//')
[[ -z "${TUNNEL_SDK_VERSION}" ]] && TUNNEL_SDK_VERSION="1.10.10"
echo "==> Using tunnel version for binary: ${TUNNEL_SDK_VERSION}"

# Presets to build (default: 7 平台；Windows 用 MinGW 以支援 Linux 主機交叉編譯)
DEFAULT_PRESETS="ci-linux-x64;ci-linux-arm64;ci-linux-arm;ci-macOS-x64;ci-macOS-arm64;ci-windows-x64-mingw;ci-windows-arm64-mingw"
PRESETS="${TUNNEL_PRESETS:-$DEFAULT_PRESETS}"
# 若無 aarch64-w64-mingw32 或已設 SKIP_WINDOWS_ARM64，則略過 Windows arm64
if [[ "${SKIP_WINDOWS_ARM64:-0}" = "1" ]] || ! command -v aarch64-w64-mingw32-gcc &>/dev/null; then
    PRESETS="${PRESETS//ci-windows-arm64-mingw;/}"
    PRESETS="${PRESETS//ci-windows-arm64-mingw/}"
    [[ -n "${PRESETS}" ]] && [[ "${PRESETS}" != *ci-windows-arm64* ]] && echo "==> Skipping ci-windows-arm64-mingw (toolchain not available); building other presets."
fi
# Pass ZGATE_SDK_DIR so deps can find zgate-sdk-c
export ZGATE_SDK_DIR="${ZGATE_SDK_DIR:-}"
if [[ -z "${ZGATE_SDK_DIR}" ]] && [[ -d "${ZGATE_SDK_BUILDER_OUTPUT:-/home/user/zgate-sdk-c-builder/output}/zgate-sdk-c-${ZITI_TUNNEL_SDK_VERSION:-}" ]]; then
    export ZGATE_SDK_DIR="${ZGATE_SDK_BUILDER_OUTPUT:-/home/user/zgate-sdk-c-builder/output}/zgate-sdk-c-${ZITI_TUNNEL_SDK_VERSION}"
fi
if [[ -z "${ZGATE_SDK_DIR}" ]] || [[ ! -d "${ZGATE_SDK_DIR}" ]]; then
    echo "Error: ZGATE_SDK_DIR must point to zgate-sdk-c-<version>. Run ensure-zgate-sdk.sh first." >&2
    exit 1
fi

if [[ -n "${VCPKG_ROOT:-}" ]]; then
    export VCPKG_ROOT
fi

cd "${ZGATE_TUNNEL_OUT}"
IFS=';' read -ra PRESET_ARRAY <<< "$PRESETS"
for preset in "${PRESET_ARRAY[@]}"; do
    preset="${preset// /}"
    [[ -z "$preset" ]] && continue
    echo "==> Configuring and building preset: ${preset}"
    EXTRA_CMAKE=()
    if [[ "${preset}" == ci-macOS-arm64 ]] && [[ -n "${OSXCROSS_ROOT:-}" ]] && [[ -f "${ZGATE_TUNNEL_OUT}/toolchains/macOS-arm64-osxcross.cmake" ]]; then
        EXTRA_CMAKE=(-DVCPKG_CHAINLOAD_TOOLCHAIN_FILE="${ZGATE_TUNNEL_OUT}/toolchains/macOS-arm64-osxcross.cmake")
    elif [[ "${preset}" == ci-macOS-x64 ]] && [[ -n "${OSXCROSS_ROOT:-}" ]] && [[ -f "${ZGATE_TUNNEL_OUT}/toolchains/macOS-x64-osxcross.cmake" ]]; then
        EXTRA_CMAKE=(-DVCPKG_CHAINLOAD_TOOLCHAIN_FILE="${ZGATE_TUNNEL_OUT}/toolchains/macOS-x64-osxcross.cmake")
    fi
    # MinGW 交叉編譯時避免 Ninja RPATH 錯誤（非 ELF 平台）
    [[ "${preset}" == ci-windows-x64-mingw* ]] || [[ "${preset}" == ci-windows-arm64-mingw* ]] && EXTRA_CMAKE+=(-DCMAKE_BUILD_WITH_INSTALL_RPATH=ON)
    cmake --preset "${preset}" -DZGATE_SDK_DIR="${ZGATE_SDK_DIR}" -DGIT_VERSION="v${TUNNEL_SDK_VERSION}" -DDISABLE_LIBSYSTEMD_FEATURE=ON "${EXTRA_CMAKE[@]}"
    BINARY_DIR="build-${preset}"
    if [[ ! -d "${BINARY_DIR}" ]]; then
        BINARY_DIR="build"
    fi
    if [[ ! -d "${BINARY_DIR}" ]]; then
        echo "Error: binaryDir not found for preset ${preset}" >&2
        exit 1
    fi
    cmake --build "${BINARY_DIR}" --config Release
    echo "==> Done: ${preset} -> ${BINARY_DIR}"
done
echo "==> All platform builds complete."
