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

# Presets to build (default: Linux x64 and arm64; can override with TUNNEL_PRESETS)
DEFAULT_PRESETS="ci-linux-x64;ci-linux-arm64"
PRESETS="${TUNNEL_PRESETS:-$DEFAULT_PRESETS}"
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
    cmake --preset "${preset}" -DZGATE_SDK_DIR="${ZGATE_SDK_DIR}"
    # binaryDir is build-<preset> after our patch
    BINARY_DIR="build-${preset}"
    if [[ ! -d "${BINARY_DIR}" ]]; then
        BINARY_DIR="build"
    fi
    cmake --build "${BINARY_DIR}" --config Release
    echo "==> Done: ${preset} -> ${BINARY_DIR}"
done
echo "==> All platform builds complete."
