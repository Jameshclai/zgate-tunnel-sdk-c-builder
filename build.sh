#!/usr/bin/env bash
# zgate-tunnel-sdk-c-builder - fetch, patch, and build zgate-tunnel-sdk-c (multi-platform).
# Copyright (c) eCloudseal Inc.  All rights reserved.  Author: Lai Hou Chang (James Lai)
set -euo pipefail
BUILDER_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${BUILDER_ROOT}"

if [[ -f "${BUILDER_ROOT}/config.env" ]]; then
    set -a
    source "${BUILDER_ROOT}/config.env"
    set +a
fi
export OUTPUT_DIR="${OUTPUT_DIR:-${BUILDER_ROOT}/output}"

echo ""
echo "=============================================="
echo "  zgate-tunnel-sdk-c 建置流程"
echo "=============================================="
echo "  本腳本將依序執行：環境檢查 → 取得原始碼 → 套用 patch → 多平台編譯 → 清理。"
echo "  完成後會列出所有成功產出的可執行檔位置。"
echo "=============================================="
echo ""

echo "【步驟 1/6】建置編譯環境"
echo "  說明：檢查並安裝建置所需工具（如 cmake、ninja、gcc）與交叉編譯工具鏈（MinGW、osxcross 等），若需要會詢問 sudo 密碼。"
echo "  目前狀態：正在執行環境檢查與套件安裝…"
"${BUILDER_ROOT}/scripts/setup-build-env.sh"
[[ -f "${BUILDER_ROOT}/.build-env.vcpkg" ]] && source "${BUILDER_ROOT}/.build-env.vcpkg"
[[ -f "${BUILDER_ROOT}/.build-env.cross" ]] && source "${BUILDER_ROOT}/.build-env.cross"
echo "  步驟 1 完成：建置環境已就緒。"
echo ""

echo "【步驟 2/6】取得 ziti-tunnel-sdk-c 原始碼"
echo "  說明：從 GitHub 取得最新版 ziti-tunnel-sdk-c 並下載至本地工作目錄。"
echo "  目前狀態：正在取得最新版本並 clone 原始碼…"
source "${BUILDER_ROOT}/scripts/fetch-latest.sh"
echo "  步驟 2 完成：原始碼已就緒（版本 ${ZITI_TUNNEL_SDK_VERSION}）。"
echo ""

echo "【步驟 3/6】確認 zgate-sdk-c 依賴"
echo "  說明：編譯 tunnel 需要對應版本的 zgate-sdk-c，此步驟會使用或檢查 zgate-sdk-c-builder 的產出目錄。"
echo "  目前狀態：正在檢查 zgate-sdk-c…"
source "${BUILDER_ROOT}/scripts/ensure-zgate-sdk.sh"
echo "  步驟 3 完成：zgate-sdk-c 已就緒（${ZGATE_SDK_DIR}）。"
echo ""

echo "【步驟 4/6】套用 zgate patch"
echo "  說明：將 ziti 品牌改為 zgate（目錄、檔名、程式內容），產出至 output 目錄。"
echo "  目前狀態：正在複製並套用 patch…"
"${BUILDER_ROOT}/scripts/apply-patch.sh"
echo "  步驟 4 完成：已產出 zgate-tunnel-sdk-c 原始碼至 ${ZGATE_TUNNEL_OUT:-${OUTPUT_DIR}/zgate-tunnel-sdk-c-${ZITI_TUNNEL_SDK_VERSION}}。"
echo ""

echo "【步驟 5/6】多平台編譯"
echo "  說明：依設定的 TUNNEL_PRESETS 對各平台進行 configure 與編譯（如 Linux x64/arm64/arm、Darwin、Windows MinGW）。"
echo "  目前狀態：正在編譯各平台…"
"${BUILDER_ROOT}/scripts/build-all-platforms.sh"
echo "  步驟 5 完成：所有平台編譯完成。"
echo ""

echo "【步驟 6/6】清理暫存檔案"
echo "  說明：移除編譯產出目錄中不必要的檔案（如 vcpkg_installed、.cmake 快取），縮小產出體積。"
echo "  目前狀態：正在清理…"
"${BUILDER_ROOT}/scripts/cleanup-output.sh"
echo "  步驟 6 完成：清理完成。"
echo ""

# 列出成功編譯產出的可執行檔位置
OUT="${ZGATE_TUNNEL_OUT:-${OUTPUT_DIR}/zgate-tunnel-sdk-c-${ZITI_TUNNEL_SDK_VERSION}}"
echo "=============================================="
echo "  建置完成 － 成功產出的編譯檔案位置"
echo "=============================================="
echo "  產出根目錄：${OUT}"
echo ""
if [[ -d "${OUT}" ]]; then
    FOUND=0
    for build_dir in "${OUT}"/build-*/; do
        [[ -d "${build_dir}" ]] || continue
        preset_name=$(basename "${build_dir}")
        # 主要可執行檔：zgate-edge-tunnel（Unix）或 zgate-edge-tunnel.exe（Windows）
        for exe in "${build_dir}programs/zgate-edge-tunnel/Release/zgate-edge-tunnel" "${build_dir}programs/zgate-edge-tunnel/Release/zgate-edge-tunnel.exe"; do
            if [[ -f "${exe}" ]]; then
                echo "  [${preset_name}]"
                echo "    ${exe}"
                echo ""
                FOUND=1
                break
            fi
        done
    done
    if [[ "${FOUND}" -eq 0 ]]; then
        echo "  （未找到可執行檔，請檢查步驟 5 編譯日誌。）"
        echo ""
    fi
else
    echo "  （產出目錄不存在，請檢查建置流程。）"
    echo ""
fi
echo "=============================================="
echo "  全部步驟已完成。"
echo "=============================================="
echo ""
