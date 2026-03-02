#!/usr/bin/env bash
# Use zgate-sdk-c from /home/user/zgate-sdk-c-builder output (do not build here).
# Copyright (c) eCloudseal Inc.  All rights reserved.  Author: Lai Hou Chang (James Lai)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILDER_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ -f "${BUILDER_ROOT}/config.env" ]]; then
    set -a
    source "${BUILDER_ROOT}/config.env"
    set +a
fi

if [[ -z "${ZITI_TUNNEL_SDK_VERSION:-}" ]]; then
    echo "Error: ZITI_TUNNEL_SDK_VERSION must be set (run fetch-latest.sh first)." >&2
    exit 1
fi

VER="${ZITI_TUNNEL_SDK_VERSION}"
# 參考使用 zgate-sdk-c-builder 的產出目錄，不在此專案內編譯 ziti-sdk-c
# 若未設定 ZGATE_SDK_BUILDER_OUTPUT，優先使用與本專案同層的 zgate-sdk-c-builder/output（一鍵建置友善）
if [[ -n "${ZGATE_SDK_BUILDER_OUTPUT:-}" ]]; then
    SDK_BUILDER_OUTPUT="${ZGATE_SDK_BUILDER_OUTPUT}"
else
    PARENT="$(dirname "${BUILDER_ROOT}")"
    if [[ -d "${PARENT}/zgate-sdk-c-builder/output" ]]; then
        SDK_BUILDER_OUTPUT="${PARENT}/zgate-sdk-c-builder/output"
    else
        SDK_BUILDER_OUTPUT="/home/user/zgate-sdk-c-builder/output"
    fi
fi
SDK_DIR="${SDK_BUILDER_OUTPUT}/zgate-sdk-c-${VER}"

# 被 source 時 return 0 會結束此腳本並回到 build.sh；直接執行時 exit 0
# If ZGATE_SDK_DIR already set and exists, use it
if [[ -n "${ZGATE_SDK_DIR:-}" ]] && [[ -d "${ZGATE_SDK_DIR}" ]]; then
    echo "==> Using existing ZGATE_SDK_DIR=${ZGATE_SDK_DIR}"
    export ZGATE_SDK_DIR
    [[ "${BASH_SOURCE[0]}" != "${0}" ]] && return 0 || exit 0
fi

# 優先使用同版本 zgate-sdk-c-{ver}
if [[ -d "${SDK_DIR}" ]]; then
    export ZGATE_SDK_DIR="${SDK_DIR}"
    echo "==> Found zgate-sdk-c-${VER} at ${SDK_DIR} (from zgate-sdk-c-builder)"
    [[ "${BASH_SOURCE[0]}" != "${0}" ]] && return 0 || exit 0
fi

# 否則使用 zgate-sdk-c-builder/output 下已有的最新版本
LATEST=$(ls -d "${SDK_BUILDER_OUTPUT}"/zgate-sdk-c-* 2>/dev/null | tail -1)
if [[ -n "${LATEST}" ]] && [[ -d "${LATEST}" ]]; then
    export ZGATE_SDK_DIR="${LATEST}"
    echo "==> Using ${ZGATE_SDK_DIR} (from zgate-sdk-c-builder, tunnel ${VER} may work with this SDK)"
    [[ "${BASH_SOURCE[0]}" != "${0}" ]] && return 0 || exit 0
fi

echo "Error: No zgate-sdk-c found under ${SDK_BUILDER_OUTPUT}" >&2
echo "Please run /home/user/zgate-sdk-c-builder/build.sh first, or set ZGATE_SDK_DIR / ZGATE_SDK_BUILDER_OUTPUT." >&2
exit 1
