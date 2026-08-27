#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
project_root=$(cd -- "${script_dir}/.." && pwd)
build_dir="${project_root}/build-native-release"
package_dir="${build_dir}/package"
jobs="${JOBS:-$(nproc)}"

cmake -E remove_directory "${package_dir}"
cmake -S "${project_root}" -B "${build_dir}" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCANIS_ENABLE_EDITOR=OFF \
  "-DCANIS_DESKTOP_RUNTIME_OUTPUT_DIRECTORY=${package_dir}"
cmake --build "${build_dir}" -j"${jobs}"
cmake -E copy_directory "${project_root}/project/assets" "${package_dir}/assets"

printf 'Native package is ready in %s\n' "${package_dir}"
