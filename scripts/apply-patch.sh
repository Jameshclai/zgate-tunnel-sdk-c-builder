#!/usr/bin/env bash
# Copy ziti-tunnel-sdk-c to zgate-tunnel-sdk-c-{version}, apply ziti->zgate renames and content replacement.
# Copyright (c) eCloudseal Inc.  All rights reserved.  Author: Lai Hou Chang (James Lai)
# Expects: ZITI_TUNNEL_SRC, ZITI_TUNNEL_SDK_VERSION, OUTPUT_DIR, ZGATE_SDK_DIR (from ensure-zgate-sdk)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILDER_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ -f "${BUILDER_ROOT}/config.env" ]]; then
    set -a
    source "${BUILDER_ROOT}/config.env"
    set +a
fi
OUTPUT_DIR="${OUTPUT_DIR:-${BUILDER_ROOT}/output}"
if [[ -z "${ZITI_TUNNEL_SRC:-}" ]] || [[ -z "${ZITI_TUNNEL_SDK_VERSION:-}" ]]; then
    echo "Error: ZITI_TUNNEL_SRC and ZITI_TUNNEL_SDK_VERSION must be set (run fetch-latest.sh first)." >&2
    exit 1
fi
VER="${ZITI_TUNNEL_SDK_VERSION}"
OUT="${OUTPUT_DIR}/zgate-tunnel-sdk-c-${VER}"
echo "==> Applying patch: ${ZITI_TUNNEL_SRC} -> ${OUT}"

mkdir -p "${OUTPUT_DIR}"
rm -rf "${OUT}"
cp -a "${ZITI_TUNNEL_SRC}" "${OUT}"
rm -rf "${OUT}/.git" "${OUT}/.github" 2>/dev/null || true

# ---- Directory renames ----
mv "${OUT}/lib/ziti-tunnel" "${OUT}/lib/zgate-tunnel" 2>/dev/null || true
mv "${OUT}/lib/ziti-tunnel-cbs" "${OUT}/lib/zgate-tunnel-cbs" 2>/dev/null || true
mv "${OUT}/programs/ziti-edge-tunnel" "${OUT}/programs/zgate-edge-tunnel" 2>/dev/null || true

# ---- lib/zgate-tunnel: source and include renames ----
[[ -f "${OUT}/lib/zgate-tunnel/ziti_tunnel.c" ]] && mv "${OUT}/lib/zgate-tunnel/ziti_tunnel.c" "${OUT}/lib/zgate-tunnel/zgate_tunnel.c"
[[ -f "${OUT}/lib/zgate-tunnel/ziti_tunnel_priv.h" ]] && mv "${OUT}/lib/zgate-tunnel/ziti_tunnel_priv.h" "${OUT}/lib/zgate-tunnel/zgate_tunnel_priv.h"
if [[ -d "${OUT}/lib/zgate-tunnel/include/ziti" ]]; then
    mv "${OUT}/lib/zgate-tunnel/include/ziti" "${OUT}/lib/zgate-tunnel/include/zgate"
fi
[[ -f "${OUT}/lib/zgate-tunnel/include/zgate/ziti_tunnel.h" ]] && mv "${OUT}/lib/zgate-tunnel/include/zgate/ziti_tunnel.h" "${OUT}/lib/zgate-tunnel/include/zgate/zgate_tunnel.h"

# ---- programs/zgate-edge-tunnel ----
[[ -f "${OUT}/programs/zgate-edge-tunnel/ziti-edge-tunnel.c" ]] && mv "${OUT}/programs/zgate-edge-tunnel/ziti-edge-tunnel.c" "${OUT}/programs/zgate-edge-tunnel/zgate-edge-tunnel.c"

# ---- scripts ----
[[ -f "${OUT}/scripts/ziti-builder.sh" ]] && mv "${OUT}/scripts/ziti-builder.sh" "${OUT}/scripts/zgate-builder.sh"
[[ -f "${OUT}/scripts/ziti-edge-tunnel-debug.bash" ]] && mv "${OUT}/scripts/ziti-edge-tunnel-debug.bash" "${OUT}/scripts/zgate-edge-tunnel-debug.bash"

# ---- Content replacement (sed) ----
find "${OUT}" -type f \( \
    -name '*.c' -o -name '*.h' -o -name '*.cpp' -o -name '*.md' -o -name 'CMakeLists.txt' \
    -o -name '*.in' -o -name '*.cmake' -o -name '*.json' -o -name '*.bash' \
\) ! -path "${OUT}/.git/*" -exec sed -i -e 's/ZITI_/ZGATE_/g' -e 's/Ziti/Zgate/g' -e 's/ziti/zgate/g' -e 's/ZITI/ZGATE/g' -e 's/openziti/openzgate/g' {} \;

# Restore subcommands.c GIT_REPOSITORY (must stay openziti)
sed -i 's|openzgate/subcommands\.c|openziti/subcommands.c|g' "${OUT}/programs/CMakeLists.txt" 2>/dev/null || true

# ---- Root CMakeLists.txt: ZITI_SDK_* -> ZGATE_SDK_*, project name, version fallback ----
sed -i 's/set(ZITI_SDK_DIR/set(ZGATE_SDK_DIR/g' "${OUT}/CMakeLists.txt"
sed -i 's/set(ZITI_SDK_VERSION/set(ZGATE_SDK_VERSION/g' "${OUT}/CMakeLists.txt"
sed -i 's/option(TUNNEL_SDK_ONLY "build only ziti-tunnel-sdk/option(TUNNEL_SDK_ONLY "build only zgate-tunnel-sdk/g' "${OUT}/CMakeLists.txt"
sed -i 's/ZITI_DEBUG)/ZGATE_DEBUG)/g' "${OUT}/CMakeLists.txt"
sed -i 's/project(ziti-tunnel-sdk-c/project(zgate-tunnel-sdk-c/' "${OUT}/CMakeLists.txt"
sed -i 's|HOMEPAGE_URL "https://github.com/openziti/ziti-tunneler-sdk-c"|HOMEPAGE_URL "https://github.com/ecloudseal/zgate-tunnel-sdk-c"|' "${OUT}/CMakeLists.txt"
sed -i 's/ZITI_TUNNEL_BUILD_TESTS/ZGATE_TUNNEL_BUILD_TESTS/g' "${OUT}/CMakeLists.txt"
sed -i 's/ZITI_TUNNEL_ASAN/ZGATE_TUNNEL_ASAN/g' "${OUT}/CMakeLists.txt"
sed -i 's/ZITI_TUNNEL_PROF/ZGATE_TUNNEL_PROF/g' "${OUT}/CMakeLists.txt"
sed -i 's/add_subdirectory(lib\/ziti-tunnel)/add_subdirectory(lib\/zgate-tunnel)/' "${OUT}/CMakeLists.txt"
sed -i 's/add_subdirectory(lib\/ziti-tunnel-cbs)/add_subdirectory(lib\/zgate-tunnel-cbs)/' "${OUT}/CMakeLists.txt"
sed -i 's/if (ZITI_TUNNEL_BUILD_TESTS)/if (ZGATE_TUNNEL_BUILD_TESTS)/' "${OUT}/CMakeLists.txt"

# Version fallback when not from git (so SEMVER verification passes)
sed -i "s/set(GIT_VERSION v0.0.0-unknown)/set(GIT_VERSION v${VER})/" "${OUT}/CMakeLists.txt"
sed -i "s/set(PROJECT_SEMVER \"\${DUMMY_SEMVER}\")/set(PROJECT_SEMVER \"${VER}\")/" "${OUT}/CMakeLists.txt"
# Quoted bundle_processor for cross-compile (upstream may have unquoted CMAKE_SYSTEM_PROCESSOR)
sed -i 's/string(TOLOWER \${CMAKE_SYSTEM_PROCESSOR} bundle_processor)/string(TOLOWER "${CMAKE_SYSTEM_PROCESSOR}" bundle_processor)/' "${OUT}/CMakeLists.txt"

# CPACK_PACKAGE_VENDOR（整行替換，避免多出 set(）
(grep -q 'CPACK_PACKAGE_VENDOR' "${OUT}/CMakeLists.txt" && sed -i 's/.*set(CPACK_PACKAGE_VENDOR.*/    set(CPACK_PACKAGE_VENDOR "eCloudseal")/' "${OUT}/CMakeLists.txt") || true

# ---- deps/CMakeLists.txt: use ZGATE_SDK_DIR (inject path from env at build time or use cache) ----
SDK_DIR_ESC="${ZGATE_SDK_DIR:-/none}"
SDK_DIR_ESC="${SDK_DIR_ESC//\//\\/}"
cat > "${OUT}/deps/CMakeLists.txt" << DEPS_CMAKE
include(FetchContent)

if(NOT TUNNEL_SDK_ONLY)
    if (ZGATE_SDK_DIR)
        add_subdirectory(\${ZGATE_SDK_DIR} \${CMAKE_CURRENT_BINARY_DIR}/zgate-sdk)
    else ()
        if(DEFINED ENV{ZGATE_SDK_DIR} AND EXISTS "\$ENV{ZGATE_SDK_DIR}")
            set(ZGATE_SDK_DIR "\$ENV{ZGATE_SDK_DIR}" CACHE FILEPATH "zgate-sdk-c path")
            add_subdirectory(\${ZGATE_SDK_DIR} \${CMAKE_CURRENT_BINARY_DIR}/zgate-sdk)
        else ()
            message(FATAL_ERROR "ZGATE_SDK_DIR or env ZGATE_SDK_DIR must point to zgate-sdk-c-\${ZGATE_SDK_VERSION}")
        endif ()
    endif ()
endif()

FetchContent_Declare(lwip
        GIT_REPOSITORY https://github.com/lwip-tcpip/lwip.git
        GIT_TAG STABLE-2_2_1_RELEASE
        SOURCE_SUBDIR dont/load/lwip/cmakelists
        )
FetchContent_MakeAvailable(lwip)

FetchContent_Declare(lwip-contrib
        GIT_REPOSITORY https://github.com/netfoundry/lwip-contrib.git
        GIT_TAG STABLE-2_1_0_RELEASE
)
FetchContent_MakeAvailable(lwip-contrib)
DEPS_CMAKE

# ---- programs/CMakeLists.txt: subdir and executable name ----
sed -i 's/DEFAULT_EXECUTABLE_NAME="ziti-edge-tunnel"/DEFAULT_EXECUTABLE_NAME="zgate-edge-tunnel"/' "${OUT}/programs/CMakeLists.txt"
sed -i 's/add_subdirectory(ziti-edge-tunnel)/add_subdirectory(zgate-edge-tunnel)/' "${OUT}/programs/CMakeLists.txt"

# ---- lib/zgate-tunnel/CMakeLists.txt: source file names and target names (ziti -> zgate) ----
sed -i 's/ziti_tunnel\.c/zgate_tunnel.c/g' "${OUT}/lib/zgate-tunnel/CMakeLists.txt"
sed -i 's/ziti-tunnel-sdk-c/zgate-tunnel-sdk-c/g' "${OUT}/lib/zgate-tunnel/CMakeLists.txt"
sed -i 's/PUBLIC ziti$/PUBLIC zgate/' "${OUT}/lib/zgate-tunnel/CMakeLists.txt"
sed -i 's/ziti-tunnel-sdk-c-deps/zgate-tunnel-sdk-c-deps/g' "${OUT}/lib/zgate-tunnel/CMakeLists.txt"
sed -i 's/ZITI_TUNNEL_BUILD_TESTS/ZGATE_TUNNEL_BUILD_TESTS/g' "${OUT}/lib/zgate-tunnel/CMakeLists.txt"

# ---- lib/zgate-tunnel-cbs: source renames ----
for base in tunnel_cbs hosting tunnel_ctrl instance dns tunnel_model; do
    for ext in c h; do
        [[ -f "${OUT}/lib/zgate-tunnel-cbs/ziti_${base}.${ext}" ]] && mv "${OUT}/lib/zgate-tunnel-cbs/ziti_${base}.${ext}" "${OUT}/lib/zgate-tunnel-cbs/zgate_${base}.${ext}"
    done
done
[[ -f "${OUT}/lib/zgate-tunnel-cbs/zgate_hosting.c" ]] && [[ -f "${OUT}/lib/zgate-tunnel-cbs/ziti_hosting.h" ]] && mv "${OUT}/lib/zgate-tunnel-cbs/ziti_hosting.h" "${OUT}/lib/zgate-tunnel-cbs/zgate_hosting.h" 2>/dev/null || true
# lib/zgate-tunnel-cbs/include: ziti -> zgate 目錄與標頭檔，讓 #include <zgate/zgate_dns.h> 等可找到
if [[ -d "${OUT}/lib/zgate-tunnel-cbs/include/ziti" ]]; then
    mv "${OUT}/lib/zgate-tunnel-cbs/include/ziti" "${OUT}/lib/zgate-tunnel-cbs/include/zgate"
fi
while IFS= read -r -d '' h; do
    mv "$h" "${h//ziti_/zgate_}"
done < <(find "${OUT}/lib/zgate-tunnel-cbs/include/zgate" -maxdepth 1 -name 'ziti_*.h' -print0 2>/dev/null)

# ---- lib/zgate-tunnel-cbs/CMakeLists.txt (target names and source list updated by global sed; ensure consistency) ----
[[ -f "${OUT}/lib/zgate-tunnel-cbs/CMakeLists.txt" ]] && sed -i 's/ziti-tunnel-sdk-c/zgate-tunnel-sdk-c/g' "${OUT}/lib/zgate-tunnel-cbs/CMakeLists.txt" && sed -i 's/ziti_tunnel_cbs/zgate_tunnel_cbs/g' "${OUT}/lib/zgate-tunnel-cbs/CMakeLists.txt" && sed -i 's/ziti_hosting/zgate_hosting/g' "${OUT}/lib/zgate-tunnel-cbs/CMakeLists.txt" && sed -i 's/ziti_tunnel_ctrl/zgate_tunnel_ctrl/g' "${OUT}/lib/zgate-tunnel-cbs/CMakeLists.txt" && sed -i 's/ziti_instance/zgate_instance/g' "${OUT}/lib/zgate-tunnel-cbs/CMakeLists.txt" && sed -i 's/ziti_dns/zgate_dns/g' "${OUT}/lib/zgate-tunnel-cbs/CMakeLists.txt" && sed -i 's/ziti_tunnel_model/zgate_tunnel_model/g' "${OUT}/lib/zgate-tunnel-cbs/CMakeLists.txt"

# ---- programs/zgate-edge-tunnel/CMakeLists.txt: target and source file names ----
if [[ -f "${OUT}/programs/zgate-edge-tunnel/CMakeLists.txt" ]]; then
    sed -i 's/ziti-edge-tunnel/zgate-edge-tunnel/g' "${OUT}/programs/zgate-edge-tunnel/CMakeLists.txt"
    sed -i 's/ZITI_LOG_MODULE/ZGATE_LOG_MODULE/g' "${OUT}/programs/zgate-edge-tunnel/CMakeLists.txt"
fi

# ---- lib/tests and tests: ziti -> zgate in CMakeLists ----
for f in "${OUT}/lib/tests/CMakeLists.txt" "${OUT}/tests/CMakeLists.txt"; do
    [[ -f "$f" ]] && sed -i 's/ziti-tunnel/zgate-tunnel/g' "$f" && sed -i 's/ziti_edge/zgate_edge/g' "$f"
done

# ---- CMakePresets.json: unique binaryDir per preset for multi-platform builds ----
PRESETS_JSON="${OUT}/CMakePresets.json"
if [[ -f "${PRESETS_JSON}" ]]; then
    python3 -c "
import json
with open(\"${PRESETS_JSON}\", \"r\") as f:
    data = json.load(f)
for p in data.get(\"configurePresets\", []):
    name = p.get(\"name\", \"\")
    if not name or p.get(\"hidden\"):
        continue
    inherits = p.get(\"inherits\", [])
    if isinstance(inherits, str):
        inherits = [inherits]
    # 為可選用的 ci- preset 設定獨立 binaryDir（ci-linux-arm64 等 inherits 為字串時也要有）
    if name.startswith(\"ci-\") and (\"ci-build\" in inherits or any(s and s.startswith(\"ci-\") for s in inherits)):
        p[\"binaryDir\"] = \"\${sourceDir}/build-\" + name
    elif \"ci-build\" in inherits:
        p[\"binaryDir\"] = \"\${sourceDir}/build-\" + name
with open(\"${PRESETS_JSON}\", \"w\") as f:
    json.dump(data, f, indent=2)
"
fi

export ZGATE_TUNNEL_OUT="${OUT}"
echo "==> Patched output: ${OUT}"
