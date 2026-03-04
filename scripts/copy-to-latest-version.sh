#!/usr/bin/env bash
# 將編譯成功的二進位複製到 latest_version/<VER>/，目錄結構與 auto_zgate_edge_tunnel_build_bot 一致。
# Copyright (c) eCloudseal Inc.  All rights reserved.
# 用法：由 build.sh 呼叫，需有 OUT（產出根目錄，如 output/zgate-tunnel-sdk-c-1.10.10）、BUILDER_ROOT。
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILDER_ROOT="${BUILDER_ROOT:-$(cd "${SCRIPT_DIR}/.." && pwd)}"
OUT="${1:-${ZGATE_TUNNEL_OUT:-}}"
if [[ -z "${OUT}" ]] || [[ ! -d "${OUT}" ]]; then
    echo "==> copy-to-latest-version: 略過（無產出目錄或未傳入 OUT）。" >&2
    exit 0
fi
VER="$(basename "${OUT}" | sed 's/^zgate-tunnel-sdk-c-//')"
[[ -z "${VER}" ]] && exit 0
LATEST_DIR="${BUILDER_ROOT}/latest_version"
VERSION_DIR="${LATEST_DIR}/${VER}"
LINUX_NAME="zgate-edge-tunnel"
WIN_NAME="zgate-edge-tunnel.exe"
WINTUN_NAME="wintun.dll"
COPIED=0

# Linux：ci-linux-x64 -> linux/x64, ci-linux-arm64 -> linux/arm64, ci-linux-arm -> linux/arm
for preset_arch in "ci-linux-x64:x64" "ci-linux-arm64:arm64" "ci-linux-arm:arm"; do
    preset="${preset_arch%%:*}"
    arch="${preset_arch##*:}"
    for src in "${OUT}/build-${preset}/programs/zgate-edge-tunnel/Release/${LINUX_NAME}" \
               "${OUT}/build-${preset}/programs/zgate-edge-tunnel/${LINUX_NAME}"; do
        if [[ -f "${src}" ]]; then
            dest_dir="${VERSION_DIR}/linux/${arch}"
            mkdir -p "${dest_dir}"
            cp -f "${src}" "${dest_dir}/${LINUX_NAME}"
            echo "==> 已複製至 latest_version: linux/${arch}/${LINUX_NAME}"
            COPIED=1
            break
        fi
    done
done

# Windows：ci-windows-x64-mingw -> windows/（含 wintun.dll）
WIN_PRESET="ci-windows-x64-mingw"
for exe_src in "${OUT}/build-${WIN_PRESET}/programs/zgate-edge-tunnel/Release/${WIN_NAME}" \
               "${OUT}/build-${WIN_PRESET}/programs/zgate-edge-tunnel/${WIN_NAME}"; do
    if [[ -f "${exe_src}" ]]; then
        WIN_SRCDIR="$(dirname "${exe_src}")"
        WINDOWS_DEST="${VERSION_DIR}/windows"
        mkdir -p "${WINDOWS_DEST}"
        cp -f "${exe_src}" "${WINDOWS_DEST}/${WIN_NAME}"
        echo "==> 已複製至 latest_version: windows/${WIN_NAME}"
        if [[ -f "${WIN_SRCDIR}/${WINTUN_NAME}" ]]; then
            cp -f "${WIN_SRCDIR}/${WINTUN_NAME}" "${WINDOWS_DEST}/${WINTUN_NAME}"
            echo "==> 已複製至 latest_version: windows/${WINTUN_NAME}"
        fi
        COPIED=1
        break
    fi
done

# macOS：ci-macOS-x64 -> macos/x64, ci-macOS-arm64 -> macos/arm64
for preset_arch in "ci-macOS-x64:x64" "ci-macOS-arm64:arm64"; do
    preset="${preset_arch%%:*}"
    arch="${preset_arch##*:}"
    for src in "${OUT}/build-${preset}/programs/zgate-edge-tunnel/Release/${LINUX_NAME}" \
               "${OUT}/build-${preset}/programs/zgate-edge-tunnel/${LINUX_NAME}"; do
        if [[ -f "${src}" ]]; then
            dest_dir="${VERSION_DIR}/macos/${arch}"
            mkdir -p "${dest_dir}"
            cp -f "${src}" "${dest_dir}/${LINUX_NAME}"
            echo "==> 已複製至 latest_version: macos/${arch}/${LINUX_NAME}"
            COPIED=1
            break
        fi
    done
done

if [[ "${COPIED}" -eq 1 ]]; then
    echo "==> 全部複製完成：${VERSION_DIR}"
else
    echo "==> 未找到可複製的二進位，略過 latest_version。" >&2
fi
