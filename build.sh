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

echo "==> Step 1: Ensure build environment"
"${BUILDER_ROOT}/scripts/setup-build-env.sh"

echo "==> Step 2: Fetch latest ziti-tunnel-sdk-c"
source "${BUILDER_ROOT}/scripts/fetch-latest.sh"

echo "==> Step 3: Ensure zgate-sdk-c-${ZITI_TUNNEL_SDK_VERSION} exists"
source "${BUILDER_ROOT}/scripts/ensure-zgate-sdk.sh"

echo "==> Step 4: Apply zgate patch"
"${BUILDER_ROOT}/scripts/apply-patch.sh"

echo "==> Step 5: Build all platforms"
"${BUILDER_ROOT}/scripts/build-all-platforms.sh"

echo "==> Step 6: Cleanup unnecessary files"
"${BUILDER_ROOT}/scripts/cleanup-output.sh"

echo "==> All done. Output: ${ZGATE_TUNNEL_OUT:-${OUTPUT_DIR}/zgate-tunnel-sdk-c-${ZITI_TUNNEL_SDK_VERSION}}"
