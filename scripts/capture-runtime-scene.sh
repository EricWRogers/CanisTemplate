#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 SCENE OUTPUT.png [WIDTH HEIGHT [STOP_SECONDS]]" >&2
}

if (( $# < 2 || $# == 3 || $# > 5 )); then
  usage
  exit 2
fi

scene_path=$1
output_path=$2
window_width=${3:-1280}
window_height=${4:-720}
stop_seconds=${5:-1}
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
project_root=$(cd -- "${script_dir}/.." && pwd)
settings_path="${project_root}/project_settings/project.canis"
executable_name=$(sed -n 's/^[[:space:]]*executableName[[:space:]]*:[[:space:]]*["'\"']\{0,1\}\([^"'\"']*\)["'\"']\{0,1\}[[:space:]]*$/\1/p' "${settings_path}" | head -n 1)
runtime_path="${project_root}/project/${executable_name:-c-engine}"

if [[ ! -x "${runtime_path}" ]]; then
  echo "Runtime executable not found: ${runtime_path}" >&2
  exit 1
fi
if ! command -v xvfb-run >/dev/null 2>&1; then
  echo "Scene capture requires xvfb-run." >&2
  exit 1
fi

if [[ "${output_path}" != /* ]]; then
  output_path="${project_root}/${output_path}"
fi
mkdir -p -- "$(dirname -- "${output_path}")"
capture_dir=$(mktemp -d /tmp/canis-scene-capture.XXXXXX)
cleanup() {
  if [[ "${capture_dir}" == /tmp/canis-scene-capture.* ]]; then
    rm -rf -- "${capture_dir}"
  fi
}
trap cleanup EXIT

(
  cd -- "${project_root}/project"
  CANIS_EDITOR_RUNTIME=0 CANIS_EDITOR=0 \
  CANIS_WINDOW_WIDTH="${window_width}" CANIS_WINDOW_HEIGHT="${window_height}" \
    xvfb-run -a "./${executable_name:-c-engine}" \
      --force-game-only --launch-scene "${scene_path}" \
      --fixed-delta 0.0166667 --stop-at "${stop_seconds}" \
      --capture-dir "${capture_dir}" --capture-final --offscreen
)

capture_file=$(find "${capture_dir}" -maxdepth 1 -type f -name '*_final_*.png' -print -quit)
if [[ -z "${capture_file}" ]]; then
  echo "Runtime completed without producing a final capture." >&2
  exit 1
fi
cp -- "${capture_file}" "${output_path}"
printf 'Captured %s at %sx%s: %s\n' "${scene_path}" "${window_width}" "${window_height}" "${output_path}"
