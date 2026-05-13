#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

EMSDK_ROOT="${CANIS_EMSDK_ROOT:-${XDG_CACHE_HOME:-$HOME/.cache}/c-engine/emsdk}"
EMSDK_VERSION="${CANIS_EMSDK_VERSION:-latest}"

mkdir -p "$(dirname -- "${EMSDK_ROOT}")"

if [ -d "${EMSDK_ROOT}/.git" ]; then
    git -C "${EMSDK_ROOT}" pull --ff-only
else
    rm -rf "${EMSDK_ROOT}"
    git clone https://github.com/emscripten-core/emsdk "${EMSDK_ROOT}"
fi

"${EMSDK_ROOT}/emsdk" install "${EMSDK_VERSION}"
"${EMSDK_ROOT}/emsdk" activate "${EMSDK_VERSION}"

printf 'EMSDK is ready at %s\n' "${EMSDK_ROOT}"
