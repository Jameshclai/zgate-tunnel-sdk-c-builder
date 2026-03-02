#!/usr/bin/env bash
# Ensure zgate-sdk-c-{tunnel_ver} exists; if not, call zgate-sdk-c-builder to produce it.
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
SDK_BUILDER_OUTPUT="${ZGATE_SDK_BUILDER_OUTPUT:-/home/user/zgate-sdk-c-builder/output}"
SDK_DIR="${SDK_BUILDER_OUTPUT}/zgate-sdk-c-${VER}"

# If ZGATE_SDK_DIR already set and exists, use it
if [[ -n "${ZGATE_SDK_DIR:-}" ]] && [[ -d "${ZGATE_SDK_DIR}" ]]; then
    echo "==> Using existing ZGATE_SDK_DIR=${ZGATE_SDK_DIR}"
    export ZGATE_SDK_DIR
    exit 0
fi

# Check sdk-builder output for zgate-sdk-c-{ver}
if [[ -d "${SDK_DIR}" ]]; then
    export ZGATE_SDK_DIR="${SDK_DIR}"
    echo "==> Found zgate-sdk-c-${VER} at ${SDK_DIR}"
    exit 0
fi

# Build it via zgate-sdk-c-builder
SDK_BUILDER_ROOT="${ZGATE_SDK_BUILDER_ROOT:-/home/user/zgate-sdk-c-builder}"
if [[ ! -x "${SDK_BUILDER_ROOT}/build.sh" ]]; then
    echo "Error: zgate-sdk-c-${VER} not found at ${SDK_DIR} and zgate-sdk-c-builder not found at ${SDK_BUILDER_ROOT}." >&2
    echo "Run zgate-sdk-c-builder with ZITI_SDK_TAG=v${VER} first, or set ZGATE_SDK_DIR." >&2
    exit 1
fi

echo "==> Building zgate-sdk-c-${VER} via zgate-sdk-c-builder..."
export ZITI_SDK_TAG="v${VER}"
export OUTPUT_DIR="${SDK_BUILDER_OUTPUT}"
mkdir -p "${SDK_BUILDER_OUTPUT}"
"${SDK_BUILDER_ROOT}/build.sh"
export ZGATE_SDK_DIR="${SDK_BUILDER_OUTPUT}/zgate-sdk-c-${VER}"
if [[ ! -d "${ZGATE_SDK_DIR}" ]]; then
    echo "Error: zgate-sdk-c-builder did not produce ${ZGATE_SDK_DIR}" >&2
    exit 1
fi
echo "==> zgate-sdk-c-${VER} ready at ${ZGATE_SDK_DIR}"
