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
REQUIRED=(git curl cmake ninja gcc g++ pkg-config)
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
        sudo apt-get install -y build-essential cmake ninja-build git curl pkg-config
        echo "    Packages installed."
    else
        echo "Please install the missing packages and re-run." >&2
        exit 1
    fi
fi

VCPKG_ROOT="${VCPKG_ROOT:-$HOME/vcpkg}"
if [[ ! -d "${VCPKG_ROOT}" ]] || [[ ! -x "${VCPKG_ROOT}/vcpkg" ]]; then
    echo "    vcpkg not found at ${VCPKG_ROOT}. Set VCPKG_ROOT or install vcpkg." >&2
    exit 1
fi
echo "    Build tools and vcpkg: OK"
echo "==> Build environment ready."
