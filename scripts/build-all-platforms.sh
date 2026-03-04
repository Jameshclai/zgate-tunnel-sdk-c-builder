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
DEFAULT_PRESETS="ci-linux-x64;ci-linux-arm64;ci-linux-arm;ci-macOS-x64;ci-macOS-arm64;ci-windows-x64-mingw"
PRESETS="${TUNNEL_PRESETS:-$DEFAULT_PRESETS}"
# 若無 aarch64-w64-mingw32 或已設 SKIP_WINDOWS_ARM64，則略過 Windows arm64
if [[ "${SKIP_WINDOWS_ARM64:-0}" = "1" ]] || ! command -v aarch64-w64-mingw32-gcc &>/dev/null; then
    PRESETS="${PRESETS//ci-windows-arm64-mingw;/}"
    PRESETS="${PRESETS//ci-windows-arm64-mingw/}"
    [[ -n "${PRESETS}" ]] && [[ "${PRESETS}" != *ci-windows-arm64* ]] && echo "==> Skipping ci-windows-arm64-mingw (toolchain not available); building other presets."
fi
# 若 osxcross 建置失敗已設 SKIP_MACOS，則略過 macOS 平台
if [[ "${SKIP_MACOS:-0}" = "1" ]]; then
    PRESETS="${PRESETS//ci-macOS-x64;/}"
    PRESETS="${PRESETS//ci-macOS-x64/}"
    PRESETS="${PRESETS//ci-macOS-arm64;/}"
    PRESETS="${PRESETS//ci-macOS-arm64/}"
    echo "==> Skipping macOS presets (SKIP_MACOS=1); building other presets."
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
# macOS + osxcross：建立 overlay triplets，讓 vcpkg 子進程 (vcpkg install) 使用 osxcross 工具鏈；並建立 install_name_tool/otool wrapper 供 vcpkg fixup 使用
if [[ -n "${OSXCROSS_ROOT:-}" ]] && [[ -f "${ZGATE_TUNNEL_OUT}/toolchains/macOS-x64-osxcross.cmake" ]]; then
    OVERLAY_TRIPLETS_DIR="${ZGATE_TUNNEL_OUT}/vcpkg-overlays/triplets"
    mkdir -p "${OVERLAY_TRIPLETS_DIR}"
    OSXCROSS_BIN="${OSXCROSS_ROOT}/target/bin"
    for arch in x64 arm64; do
        if [[ "$arch" == "x64" ]]; then
            PREFIX="x86_64-apple-darwin20.4"
        else
            PREFIX="arm64-apple-darwin20.4"
        fi
        WRAPPER_DIR="${ZGATE_TUNNEL_OUT}/vcpkg-overlays/osxcross-path-${arch}"
        mkdir -p "${WRAPPER_DIR}"
        for tool in install_name_tool otool; do
            [[ -x "${OSXCROSS_BIN}/${PREFIX}-${tool}" ]] && ln -sf "${OSXCROSS_BIN}/${PREFIX}-${tool}" "${WRAPPER_DIR}/${tool}" 2>/dev/null || true
        done
    done
    echo "set(VCPKG_TARGET_ARCHITECTURE x64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE static)
set(VCPKG_CMAKE_SYSTEM_NAME Darwin)
set(VCPKG_OSX_ARCHITECTURES x86_64)
set(VCPKG_CHAINLOAD_TOOLCHAIN_FILE \"${ZGATE_TUNNEL_OUT}/toolchains/macOS-x64-osxcross.cmake\")" > "${OVERLAY_TRIPLETS_DIR}/x64-osx.cmake"
    echo "set(VCPKG_TARGET_ARCHITECTURE arm64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE static)
set(VCPKG_CMAKE_SYSTEM_NAME Darwin)
set(VCPKG_OSX_ARCHITECTURES arm64)
set(VCPKG_CHAINLOAD_TOOLCHAIN_FILE \"${ZGATE_TUNNEL_OUT}/toolchains/macOS-arm64-osxcross.cmake\")" > "${OVERLAY_TRIPLETS_DIR}/arm64-osx.cmake"
    export VCPKG_OVERLAY_TRIPLETS="${OVERLAY_TRIPLETS_DIR}"
    # 建立 vcpkg-tool-meson overlay（使用 vcpkg 內已含 Linux→OSX cross 修正的 port），供 stc 等使用
    MESON_OVERLAY="${ZGATE_TUNNEL_OUT}/vcpkg-overlays/vcpkg-tool-meson"
    if [[ -d "${VCPKG_ROOT:-/none}/ports/vcpkg-tool-meson" ]] && [[ -n "${VCPKG_ROOT:-}" ]]; then
        mkdir -p "${ZGATE_TUNNEL_OUT}/vcpkg-overlays"
        rm -rf "${MESON_OVERLAY}"
        cp -r "${VCPKG_ROOT}/ports/vcpkg-tool-meson" "${MESON_OVERLAY}"
    fi
fi

IFS=';' read -ra PRESET_ARRAY <<< "$PRESETS"
for preset in "${PRESET_ARRAY[@]}"; do
    preset="${preset// /}"
    [[ -z "$preset" ]] && continue
    echo "==> Configuring and building preset: ${preset}"
    EXTRA_CMAKE=()
    if [[ -n "${VCPKG_OVERLAY_TRIPLETS:-}" ]]; then
        EXTRA_CMAKE=(-DVCPKG_OVERLAY_TRIPLETS="${VCPKG_OVERLAY_TRIPLETS}")
        # 使用含 Meson 交叉編譯修正的 vcpkg-tool-meson overlay，避免 stc 等 port 在 Linux→OSX 時用 --native
        if [[ -d "${ZGATE_TUNNEL_OUT}/vcpkg-overlays/vcpkg-tool-meson" ]]; then
            EXTRA_CMAKE+=(-DVCPKG_OVERLAY_PORTS="${ZGATE_TUNNEL_OUT}/vcpkg-overlays/json-c-disable-duplocale;${ZGATE_TUNNEL_OUT}/vcpkg-overlays/vcpkg-tool-meson")
        fi
    fi
    if [[ "${preset}" == ci-macOS-arm64 ]] && [[ -f "${ZGATE_TUNNEL_OUT}/toolchains/macOS-arm64-osxcross.cmake" ]]; then
        # 確保 vcpkg detect_compiler 等子進程能取得 osxcross 路徑與工具；Meson 建置 stc 時需用 target 的 ar/ranlib
        if [[ -z "${OSXCROSS_ROOT:-}" ]] && [[ -d "${BUILDER_ROOT}/.cross-toolchains/osxcross/target/bin" ]]; then
            export OSXCROSS_ROOT="${BUILDER_ROOT}/.cross-toolchains/osxcross"
        fi
        [[ -n "${OSXCROSS_ROOT:-}" ]] && EXTRA_CMAKE+=(-DVCPKG_CHAINLOAD_TOOLCHAIN_FILE="${ZGATE_TUNNEL_OUT}/toolchains/macOS-arm64-osxcross.cmake")
        if [[ -d "${ZGATE_TUNNEL_OUT}/vcpkg-overlays/osxcross-path-arm64" ]]; then
            export PATH="${ZGATE_TUNNEL_OUT}/vcpkg-overlays/osxcross-path-arm64:${PATH}"
            OB="${OSXCROSS_ROOT:-}/target/bin/arm64-apple-darwin20.4"
            [[ -x "${OB}-ar" ]] && export AR="${OB}-ar" RANLIB="${OB}-ranlib"
        fi
    elif [[ "${preset}" == ci-macOS-x64 ]] && [[ -f "${ZGATE_TUNNEL_OUT}/toolchains/macOS-x64-osxcross.cmake" ]]; then
        if [[ -z "${OSXCROSS_ROOT:-}" ]] && [[ -d "${BUILDER_ROOT}/.cross-toolchains/osxcross/target/bin" ]]; then
            export OSXCROSS_ROOT="${BUILDER_ROOT}/.cross-toolchains/osxcross"
        fi
        [[ -n "${OSXCROSS_ROOT:-}" ]] && EXTRA_CMAKE+=(-DVCPKG_CHAINLOAD_TOOLCHAIN_FILE="${ZGATE_TUNNEL_OUT}/toolchains/macOS-x64-osxcross.cmake")
        if [[ -d "${ZGATE_TUNNEL_OUT}/vcpkg-overlays/osxcross-path-x64" ]]; then
            export PATH="${ZGATE_TUNNEL_OUT}/vcpkg-overlays/osxcross-path-x64:${PATH}"
            OB="${OSXCROSS_ROOT:-}/target/bin/x86_64-apple-darwin20.4"
            [[ -x "${OB}-ar" ]] && export AR="${OB}-ar" RANLIB="${OB}-ranlib"
        fi
        # tlsuv apple/keychain.c 使用 security/SecKey.h，macOS SDK 需改為 Security/（大寫）
        for keychain_c in "${ZGATE_SDK_DIR}/../../work/tlsuv-"*"/src/apple/keychain.c" "${ZGATE_SDK_DIR}/../work/tlsuv-"*"/src/apple/keychain.c"; do
            if [[ -f "${keychain_c}" ]]; then
                grep -q '<security/' "${keychain_c}" 2>/dev/null && sed -i 's|<security/|<Security/|g' "${keychain_c}" && echo "==> Patched ${keychain_c} (security -> Security)"
                break
            fi
        done
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
