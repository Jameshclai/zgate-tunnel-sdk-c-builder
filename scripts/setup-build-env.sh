#!/usr/bin/env bash
# Ensure build environment and required packages are installed (for fresh Ubuntu).
# Copyright (c) eCloudseal Inc.  All rights reserved.  Author: Lai Hou Chang (James Lai)
# 缺少套件時自動安裝（不詢問）；若設定 SUDO_PASS 則以 sudo -S 非互動執行，未設定時仍會詢問 sudo 密碼。
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILDER_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ -f "${BUILDER_ROOT}/config.env" ]]; then
    set -a
    source "${BUILDER_ROOT}/config.env"
    set +a
fi

[[ "${SKIP_ENV_CHECK:-0}" = "1" ]] && { echo "==> Skipping build env check (SKIP_ENV_CHECK=1)"; exit 0; }

# 非互動模式：若有 SUDO_PASS 則用 sudo -S 執行後續 sudo 指令（一鍵建置不詢問）
sudo_cmd() {
    if [[ -n "${SUDO_PASS:-}" ]]; then
        echo "${SUDO_PASS}" | sudo -S -p "" "$@"
    else
        sudo "$@"
    fi
}

echo "==> Step 1a: Checking build environment (basic tools + cross-compilation)..."
REQUIRED=(git curl cmake ninja gcc g++ pkg-config zip unzip tar)
MISSING=()
for cmd in "${REQUIRED[@]}"; do
    command -v "$cmd" &>/dev/null || MISSING+=("$cmd")
done

# 若有需 sudo 的套件或交叉工具鏈，先取得 sudo（不詢問：有 SUDO_PASS 則非互動，否則 sudo 會問一次）
SUDO_OK=0
NEED_SUDO=
[[ ${#MISSING[@]} -gt 0 ]] && NEED_SUDO=1
[[ "${SKIP_CROSS_TOOLCHAINS:-0}" != "1" ]] && NEED_SUDO=1
if [[ -n "${NEED_SUDO}" ]]; then
    if [[ -n "${SUDO_PASS:-}" ]]; then
        if echo "${SUDO_PASS}" | sudo -S -v 2>/dev/null; then
            SUDO_OK=1
            echo "    sudo 已就緒（非互動模式）。"
        else
            echo "Error: sudo 權限取得失敗（SUDO_PASS 無效）。" >&2
            exit 1
        fi
    else
        echo "    取得 sudo 權限中（若未設定 SUDO_PASS，請輸入密碼）..."
        if sudo -v 2>/dev/null; then
            SUDO_OK=1
            echo "    sudo 已就緒，接著安裝所需套件。"
        else
            echo "Error: sudo 權限取得失敗。請設定 SUDO_PASS 於 config.env 或手動安裝套件後再執行。" >&2
            exit 1
        fi
    fi
fi

if [[ ${#MISSING[@]} -gt 0 ]]; then
    echo "    Missing required: ${MISSING[*]} — 自動安裝中（不詢問）..."
    echo "    正在安裝基本建置套件..."
    sudo_cmd apt-get update -qq
    sudo_cmd apt-get install -y build-essential cmake ninja-build git curl pkg-config zip unzip tar
    if ! command -v jq &>/dev/null; then
        sudo_cmd apt-get install -y jq
    fi
    echo "    基本套件已安裝。"
fi

# 再次檢查必備指令
MISSING=()
for cmd in "${REQUIRED[@]}"; do
    command -v "$cmd" &>/dev/null || MISSING+=("$cmd")
done
if [[ ${#MISSING[@]} -gt 0 ]]; then
    echo "Error: Still missing: ${MISSING[*]}. Install them and re-run." >&2
    exit 1
fi

# Check vcpkg (required for build); 缺少則自動 clone 並 bootstrap（不詢問）
VCPKG_ROOT="${VCPKG_ROOT:-}"
if [[ -z "${VCPKG_ROOT}" ]]; then
    VCPKG_ROOT="${HOME}/vcpkg"
fi
if [[ ! -d "${VCPKG_ROOT}" ]] || [[ ! -x "${VCPKG_ROOT}/vcpkg" ]]; then
    echo "    vcpkg not found at ${VCPKG_ROOT} — 自動 clone 並 bootstrap（不詢問）..."
    mkdir -p "$(dirname "${VCPKG_ROOT}")"
    if [[ -d "${VCPKG_ROOT}/.git" ]]; then
        echo "    vcpkg directory exists; bootstrapping..."
        (cd "${VCPKG_ROOT}" && ./bootstrap-vcpkg.sh -disableMetrics)
    else
        echo "    Cloning vcpkg..."
        git clone --depth 1 https://github.com/microsoft/vcpkg.git "${VCPKG_ROOT}"
        (cd "${VCPKG_ROOT}" && ./bootstrap-vcpkg.sh -disableMetrics)
    fi
    if (cd "${VCPKG_ROOT}" && git rev-parse --is-shallow-repository 2>/dev/null) | grep -q true; then
        echo "    Fetching vcpkg full history (for baseline)..."
        (cd "${VCPKG_ROOT}" && git fetch --unshallow)
    fi
    echo "    vcpkg ready at ${VCPKG_ROOT}"
else
    echo "    vcpkg: OK (${VCPKG_ROOT})"
    if (cd "${VCPKG_ROOT}" && git rev-parse --is-shallow-repository 2>/dev/null) | grep -q true; then
        echo "    Fetching vcpkg full history (for baseline)..."
        (cd "${VCPKG_ROOT}" && git fetch --unshallow)
    fi
fi

# Write VCPKG_ROOT so parent build.sh can source it (needed when we just cloned vcpkg)
export VCPKG_ROOT
printf 'export VCPKG_ROOT=%q\n' "${VCPKG_ROOT}" > "${BUILDER_ROOT}/.build-env.vcpkg"

echo "    Build tools and vcpkg: OK"

# Darwin 與 Windows 交叉編譯工具鏈：安裝後不准失敗/略過
"${BUILDER_ROOT}/scripts/setup-cross-toolchains.sh"
# 寫入供後續 build 步驟 source（子進程需讀取）
CROSS_DIR="${CROSS_TOOLCHAINS_DIR:-${BUILDER_ROOT}/.cross-toolchains}"
OSXCROSS_ROOT="${CROSS_DIR}/osxcross"
: > "${BUILDER_ROOT}/.build-env.cross"
if [[ -d "${OSXCROSS_ROOT}/target/bin" ]]; then
    echo "export OSXCROSS_ROOT=\"${OSXCROSS_ROOT}\"" >> "${BUILDER_ROOT}/.build-env.cross"
    echo "export PATH=\"${OSXCROSS_ROOT}/target/bin:\${PATH}\"" >> "${BUILDER_ROOT}/.build-env.cross"
fi
[[ -f "${BUILDER_ROOT}/.cross-toolchains.env" ]] && cat "${BUILDER_ROOT}/.cross-toolchains.env" >> "${BUILDER_ROOT}/.build-env.cross"
echo "==> Build environment ready."
