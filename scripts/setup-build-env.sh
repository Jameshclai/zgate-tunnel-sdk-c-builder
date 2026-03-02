#!/usr/bin/env bash
# Ensure build environment and required packages are installed (for fresh Ubuntu).
# Copyright (c) eCloudseal Inc.  All rights reserved.  Author: Lai Hou Chang (James Lai)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILDER_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ -f "${BUILDER_ROOT}/config.env" ]]; then
    set -a
    source "${BUILDER_ROOT}/config.env"
    set +a
fi

[[ "${SKIP_ENV_CHECK:-0}" = "1" ]] && { echo "==> Skipping build env check (SKIP_ENV_CHECK=1)"; exit 0; }

echo "==> Checking build environment..."
REQUIRED=(git curl cmake ninja gcc g++ pkg-config zip)
MISSING=()
for cmd in "${REQUIRED[@]}"; do
    command -v "$cmd" &>/dev/null || MISSING+=("$cmd")
done

if [[ ${#MISSING[@]} -gt 0 ]]; then
    echo "    Missing required: ${MISSING[*]}"
    echo ""
    read -r -p "Install missing packages now? [y/N] " ans
    if [[ "${ans,,}" = "y" || "${ans,,}" = "yes" ]]; then
        sudo -v || { echo "Error: sudo access failed." >&2; exit 1; }
        sudo apt-get update
        sudo apt-get install -y build-essential cmake ninja-build git curl pkg-config zip
        echo "    Packages installed."
    else
        echo "Please install the missing packages and re-run." >&2
        exit 1
    fi
fi

# Check vcpkg (required for build); auto clone and bootstrap if missing
VCPKG_ROOT="${VCPKG_ROOT:-}"
if [[ -z "${VCPKG_ROOT}" ]]; then
    VCPKG_ROOT="${HOME}/vcpkg"
fi
if [[ ! -d "${VCPKG_ROOT}" ]] || [[ ! -x "${VCPKG_ROOT}/vcpkg" ]]; then
    echo "    vcpkg not found at ${VCPKG_ROOT}"
    echo ""
    echo "vcpkg is required for dependency management. Options:"
    echo "  1) Clone and bootstrap vcpkg to ${VCPKG_ROOT} (no sudo)"
    echo "  2) Set VCPKG_ROOT in config.env to your existing vcpkg path"
    echo "  3) Exit and install vcpkg manually"
    echo ""
    read -r -p "Clone and bootstrap vcpkg to ${VCPKG_ROOT} now? [y/N] " ans
    if [[ "${ans,,}" = "y" || "${ans,,}" = "yes" ]]; then
        mkdir -p "$(dirname "${VCPKG_ROOT}")"
        if [[ -d "${VCPKG_ROOT}/.git" ]]; then
            echo "    vcpkg directory exists; bootstrapping..."
            (cd "${VCPKG_ROOT}" && ./bootstrap-vcpkg.sh -disableMetrics)
        else
            echo "    Cloning vcpkg..."
            git clone --depth 1 https://github.com/microsoft/vcpkg.git "${VCPKG_ROOT}"
            (cd "${VCPKG_ROOT}" && ./bootstrap-vcpkg.sh -disableMetrics)
        fi
        echo "    vcpkg ready at ${VCPKG_ROOT}"
        echo "    Consider adding to config.env: export VCPKG_ROOT=${VCPKG_ROOT}"
    else
        echo "Error: vcpkg is required. Set VCPKG_ROOT in config.env or install vcpkg, then re-run." >&2
        exit 1
    fi
else
    echo "    vcpkg: OK (${VCPKG_ROOT})"
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
echo "==> Build environment ready."
