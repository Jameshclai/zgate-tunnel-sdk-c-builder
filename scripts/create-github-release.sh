#!/usr/bin/env bash
# Create a GitHub Release from an existing tag (via API). Requires GITHUB_TOKEN.
# Usage: GITHUB_TOKEN=xxx ./scripts/create-github-release.sh [tag_name] [release_name] [body]
# Example: GITHUB_TOKEN=xxx ./scripts/create-github-release.sh v1.0.2 "Release 1.0.2" "zgate-tunnel-sdk-c-builder 1.0.2"
# Copyright (c) eCloudseal Inc.  All rights reserved.  Author: Lai Hou Chang (James Lai)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILDER_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${BUILDER_ROOT}"

TAG_NAME="${1:-v1.0.2}"
RELEASE_NAME="${2:-Release ${TAG_NAME#v}}"
RELEASE_BODY="${3:-Build zgate-tunnel-sdk-c from ziti-tunnel-sdk-c with zgate patch and multi-platform output.}"

if [[ -z "${GITHUB_TOKEN:-}" ]]; then
    echo "Error: GITHUB_TOKEN is required. Example: GITHUB_TOKEN=xxx $0 $*" >&2
    exit 1
fi

# Parse repo from origin URL (e.g. https://github.com/Jameshclai/zgate-tunnel-sdk-c-builder.git -> Jameshclai/zgate-tunnel-sdk-c-builder)
REMOTE_URL="$(git remote get-url origin 2>/dev/null || true)"
if [[ "${REMOTE_URL}" =~ github\.com[:/]([^/]+/[^/]+?)(\.git)?$ ]]; then
    REPO="${BASH_REMATCH[1]}"
else
    REPO="Jameshclai/zgate-tunnel-sdk-c-builder"
fi

API_URL="https://api.github.com/repos/${REPO}/releases"
JSON=$(cat <<EOF
{
  "tag_name": "${TAG_NAME}",
  "name": "${RELEASE_NAME}",
  "body": "${RELEASE_BODY//\"/\\\"}",
  "draft": false,
  "prerelease": false
}
EOF
)

echo "==> Creating GitHub Release for tag ${TAG_NAME}..."
RESP=$(curl -sS -X POST \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  -H "Content-Type: application/json" \
  "${API_URL}" \
  -d "${JSON}")

if echo "${RESP}" | grep -q '"id"'; then
    echo "==> Release created: $(echo "${RESP}" | grep '"html_url"' | head -1 | sed 's/.*"\(https:[^"]*\)".*/\1/')"
else
    echo "Error: Failed to create release (token 需具 repo 權限). Response: ${RESP}" >&2
    echo "可改在 GitHub 網頁建立：Releases → Draft a new release → 選擇標籤 ${TAG_NAME} → Publish." >&2
    exit 1
fi
