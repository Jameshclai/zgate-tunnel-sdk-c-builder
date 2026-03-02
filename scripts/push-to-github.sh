#!/usr/bin/env bash
# Push current branch and tags to GitHub (origin). Uses GITHUB_TOKEN from env if set.
# Copyright (c) eCloudseal Inc.  All rights reserved.  Author: Lai Hou Chang (James Lai)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILDER_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${BUILDER_ROOT}"

REMOTE="${GIT_REMOTE:-origin}"
BRANCH="${GIT_PUSH_BRANCH:-$(git rev-parse --abbrev-ref HEAD)}"

push_url="$(git remote get-url "${REMOTE}" 2>/dev/null || true)"
if [[ -z "${push_url}" ]]; then
    echo "Error: remote '${REMOTE}' not found. Add GitHub remote first." >&2
    exit 1
fi

# If GITHUB_TOKEN is set, use it for HTTPS push (non-interactive)
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    if [[ "${push_url}" =~ ^https://([^@]+@)?github\.com[:/](.+)$ ]]; then
        push_url="https://${GITHUB_TOKEN}@github.com/${BASH_REMATCH[2]}"
    elif [[ "${push_url}" =~ ^https://github\.com[:/](.+)$ ]]; then
        push_url="https://${GITHUB_TOKEN}@github.com/${BASH_REMATCH[1]}"
    fi
fi

echo "==> Pushing to ${REMOTE} (branch: ${BRANCH})..."
git push "${push_url}" "${BRANCH}"
# 若目前為 master，一併更新遠端 main（GitHub 預設分支常為 main，須同步以免首頁顯示舊程式）
if [[ "${BRANCH}" = "master" ]]; then
    echo "==> Syncing remote main with master..."
    git push "${push_url}" "${BRANCH}:refs/heads/main"
fi
echo "==> Pushing tags..."
git push "${push_url}" --tags
echo "==> Push to GitHub done."
