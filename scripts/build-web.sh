#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

PRESET="${1:-web-release}"

case "${PRESET}" in
    web-debug|web-release)
        ;;
    *)
        echo "Unsupported preset: ${PRESET}" >&2
        echo "Use web-debug or web-release." >&2
        exit 1
        ;;
esac

if [ "${CANIS_SKIP_EMSDK_BOOTSTRAP:-0}" != "1" ]; then
    "${SCRIPT_DIR}/ensure_emsdk.sh"
fi

EMSDK_ROOT="${CANIS_EMSDK_ROOT:-${XDG_CACHE_HOME:-$HOME/.cache}/c-engine/emsdk}"
if [ ! -f "${EMSDK_ROOT}/emsdk_env.sh" ]; then
    echo "Emscripten environment script not found at ${EMSDK_ROOT}/emsdk_env.sh" >&2
    exit 1
fi

CCACHE_ROOT="${CCACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/c-engine/ccache}"
mkdir -p "${CCACHE_ROOT}" "${CCACHE_ROOT}/tmp"

export CCACHE_DIR="${CCACHE_ROOT}"
export CCACHE_TEMPDIR="${CCACHE_ROOT}/tmp"

# shellcheck disable=SC1090
source "${EMSDK_ROOT}/emsdk_env.sh" >/dev/null

cmake --fresh --preset "${PRESET}"
cmake --build --preset "${PRESET}" -j"${JOBS:-$(nproc)}"

BUILD_DIR="${ROOT_DIR}/build-${PRESET}"
EXPORT_DIR="${BUILD_DIR}/web"
printf 'Web export is ready in %s\n' "${EXPORT_DIR}"
