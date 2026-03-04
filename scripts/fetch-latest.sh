#!/usr/bin/env bash
# Fetch latest (or pinned) ziti-tunnel-sdk-c from GitHub, clone to WORK_DIR.
# Copyright (c) eCloudseal Inc.  All rights reserved.  Author: Lai Hou Chang (James Lai)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILDER_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ -f "${BUILDER_ROOT}/config.env" ]]; then
    set -a
    source "${BUILDER_ROOT}/config.env"
    set +a
fi
export WORK_DIR="${WORK_DIR:-${BUILDER_ROOT}/work}"
mkdir -p "${WORK_DIR}"
cd "${WORK_DIR}"

get_latest_tag() {
    local repo="$1"
    local override_var="$2"
    if [[ -n "${!override_var:-}" ]]; then
        echo "${!override_var}"
        return
    fi
    local url="https://api.github.com/repos/${repo}/releases/latest"
    local tag=""
    if command -v jq &>/dev/null; then
        tag="$(curl -sSLf "${url}" 2>/dev/null | jq -r '.tag_name // empty')" || true
    else
        tag="$(curl -sSLf "${url}" 2>/dev/null | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)" || true
    fi
    if [[ -z "${tag}" ]] && [[ -d "${WORK_DIR:-.}" ]]; then
        local existing
        existing="$(find "${WORK_DIR}" -maxdepth 1 -type d -name 'ziti-tunnel-sdk-c-*' 2>/dev/null | head -1)"
        if [[ -n "${existing}" ]]; then
            tag="v$(basename "${existing}" | sed 's/^ziti-tunnel-sdk-c-//')"
            echo "    (GitHub API unavailable, using existing work dir: ${tag})" >&2
        fi
    fi
    [[ -n "${tag}" ]] && echo "${tag}"
}

norm_ver() {
    local v="$1"
    echo "${v#v}"
}

echo "==> Fetching latest ziti-tunnel-sdk-c release tag..."
TUNNEL_TAG="${ZITI_TUNNEL_SDK_TAG:-$(get_latest_tag "openziti/ziti-tunnel-sdk-c" "ZITI_TUNNEL_SDK_TAG")}"
TUNNEL_VER="$(norm_ver "$TUNNEL_TAG")"
echo "    ziti-tunnel-sdk-c: ${TUNNEL_TAG} (version ${TUNNEL_VER})"

TUNNEL_SRC="${WORK_DIR}/ziti-tunnel-sdk-c-${TUNNEL_VER}"

if [[ -d "${TUNNEL_SRC}/.git" ]]; then
    echo "==> ziti-tunnel-sdk-c-${TUNNEL_VER} already cloned, skipping."
else
    echo "==> Cloning openziti/ziti-tunnel-sdk-c @ ${TUNNEL_TAG}..."
    rm -rf "${TUNNEL_SRC}"
    git clone --depth 1 --branch "${TUNNEL_TAG}" \
        https://github.com/openziti/ziti-tunnel-sdk-c.git "${TUNNEL_SRC}"
fi

export ZITI_TUNNEL_SRC="${TUNNEL_SRC}"
export ZITI_TUNNEL_SDK_VERSION="${TUNNEL_VER}"
export ZITI_TUNNEL_SDK_TAG="${TUNNEL_TAG}"
echo "==> Done. ZITI_TUNNEL_SRC=${ZITI_TUNNEL_SRC}"
