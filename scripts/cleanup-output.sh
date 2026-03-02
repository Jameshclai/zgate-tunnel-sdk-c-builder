#!/usr/bin/env bash
# Remove unnecessary files from the built tunnel output.
# Copyright (c) eCloudseal Inc.  All rights reserved.  Author: Lai Hou Chang (James Lai)
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
        exit 0
    fi
    ZGATE_TUNNEL_OUT="${OUTPUT_DIR}/zgate-tunnel-sdk-c-${ZITI_TUNNEL_SDK_VERSION}"
fi
[[ "${SKIP_CLEANUP:-0}" = "1" ]] && exit 0
[[ ! -d "${ZGATE_TUNNEL_OUT}" ]] && exit 0

echo "==> Cleaning unnecessary files in ${ZGATE_TUNNEL_OUT}"
for b in "${ZGATE_TUNNEL_OUT}"/build-*/; do
    [[ -d "${b}vcpkg_installed" ]] && rm -rf "${b}vcpkg_installed" && echo "    removed ${b}vcpkg_installed"
    [[ -d "${b}.cmake" ]] && rm -rf "${b}.cmake"
done
[[ -d "${ZGATE_TUNNEL_OUT}/build/vcpkg_installed" ]] && rm -rf "${ZGATE_TUNNEL_OUT}/build/vcpkg_installed"
echo "==> Cleanup done."
