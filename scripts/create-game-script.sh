#!/usr/bin/env bash

set -euo pipefail

usage() {
    cat <<'EOF'
Usage:
  ./scripts/create-game-script.sh [--root PATH] [--force] <Namespace/ScriptName> [required_component ...]

Examples:
  ./scripts/create-game-script.sh RollABall/EnemySpawner
  ./scripts/create-game-script.sh RollABall/EnemySpawner Canis::Transform Canis::Rigidbody
  ./scripts/create-game-script.sh --force SpaceGold::MiningLaser

Notes:
  - The target can use either / or :: separators.
  - Required components are inserted into DEFAULT_CONFIG_AND_REQUIRED(...) exactly as provided.
EOF
}

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/.." && pwd)"
output_root="${repo_root}"
force_overwrite=false

while (($# > 0)); do
    case "$1" in
        --root)
            if (($# < 2)); then
                echo "error: --root requires a path." >&2
                usage >&2
                exit 1
            fi
            output_root="$2"
            shift 2
            ;;
        --force)
            force_overwrite=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            break
            ;;
        -*)
            echo "error: unknown option '$1'." >&2
            usage >&2
            exit 1
            ;;
        *)
            break
            ;;
    esac
done

if (($# < 1)); then
    echo "error: missing script name." >&2
    usage >&2
    exit 1
fi

raw_target="$1"
shift

required_components=("$@")

normalized_target="$(printf '%s' "${raw_target}" | sed -e 's#::#/#g' -e 's#^/*##' -e 's#/*$##')"

if [[ -z "${normalized_target}" ]]; then
    echo "error: script name cannot be empty." >&2
    exit 1
fi

IFS='/' read -r -a path_parts <<< "${normalized_target}"

if ((${#path_parts[@]} == 0)); then
    echo "error: invalid script name '${raw_target}'." >&2
    exit 1
fi

class_name="${path_parts[${#path_parts[@]} - 1]}"
unset 'path_parts[${#path_parts[@]} - 1]'
namespace_parts=("${path_parts[@]}")

if [[ ! "${class_name}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
    echo "error: '${class_name}' is not a valid C++ type name." >&2
    exit 1
fi

for namespace_part in "${namespace_parts[@]}"; do
    if [[ ! "${namespace_part}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
        echo "error: '${namespace_part}' is not a valid C++ namespace segment." >&2
        exit 1
    fi
done

relative_dir=""
if ((${#namespace_parts[@]} > 0)); then
    relative_dir="$(IFS=/; printf '%s' "${namespace_parts[*]}")"
fi

relative_header="${class_name}.hpp"
relative_source="${class_name}.cpp"
script_symbol_name="${class_name}"

if [[ -n "${relative_dir}" ]]; then
    relative_header="${relative_dir}/${relative_header}"
    relative_source="${relative_dir}/${relative_source}"
    script_symbol_name="${relative_dir//\//::}::${class_name}"
fi

header_path="${output_root}/game/include/${relative_header}"
source_path="${output_root}/game/src/${relative_source}"

if [[ -e "${header_path}" || -e "${source_path}" ]] && [[ "${force_overwrite}" != true ]]; then
    echo "error: target file already exists." >&2
    echo "  header: ${header_path}" >&2
    echo "  source: ${source_path}" >&2
    echo "Use --force to overwrite both files." >&2
    exit 1
fi

mkdir -p "$(dirname -- "${header_path}")" "$(dirname -- "${source_path}")"

print_indent() {
    local indent_level="$1"
    printf '%*s' "${indent_level}" ''
}

write_namespace_open() {
    local indent_level="$1"
    local namespace_name="$2"
    print_indent "${indent_level}"
    printf 'namespace %s\n' "${namespace_name}"
    print_indent "${indent_level}"
    printf '{\n'
}

write_namespace_close() {
    local indent_level="$1"
    print_indent "${indent_level}"
    printf '}\n'
}

write_namespaces_open() {
    local indent_level=0
    local namespace_name

    for namespace_name in "${namespace_parts[@]}"; do
        write_namespace_open "${indent_level}" "${namespace_name}"
        indent_level=$((indent_level + 4))
    done
}

write_namespaces_close() {
    local indent_level=$((${#namespace_parts[@]} * 4))
    local index

    for ((index=${#namespace_parts[@]} - 1; index>=0; --index)); do
        indent_level=$((indent_level - 4))
        write_namespace_close "${indent_level}"
    done
}

config_macro="DEFAULT_CONFIG(scriptConf, ${script_symbol_name});"
if ((${#required_components[@]} > 0)); then
    required_component_list=""
    for required_component in "${required_components[@]}"; do
        if [[ -n "${required_component_list}" ]]; then
            required_component_list+=", "
        fi
        required_component_list+="${required_component}"
    done
    config_macro="DEFAULT_CONFIG_AND_REQUIRED(scriptConf, ${script_symbol_name}, ${required_component_list});"
fi

{
    printf '#pragma once\n\n'
    printf '#include <Canis/Entity.hpp>\n\n'
    printf 'namespace Canis\n{\n    class App;\n}\n'

    if ((${#namespace_parts[@]} > 0)); then
        printf '\n'
        write_namespaces_open
    else
        printf '\n'
    fi

    class_indent=$((${#namespace_parts[@]} * 4))
    access_indent="${class_indent}"
    body_indent=$((class_indent + 4))

    print_indent "${class_indent}"
    printf 'class %s : public Canis::ScriptableEntity\n' "${class_name}"
    print_indent "${class_indent}"
    printf '{\n'
    print_indent "${access_indent}"
    printf 'public:\n'
    print_indent "${body_indent}"
    printf 'static constexpr const char* ScriptName = "%s";\n\n' "${script_symbol_name}"
    print_indent "${body_indent}"
    printf 'explicit %s(Canis::Entity& _entity) : Canis::ScriptableEntity(_entity) {}\n\n' "${class_name}"
    print_indent "${body_indent}"
    printf 'void Create() override;\n'
    print_indent "${body_indent}"
    printf 'void Ready() override;\n'
    print_indent "${body_indent}"
    printf 'void Destroy() override;\n'
    print_indent "${body_indent}"
    printf 'void Update(float _dt) override;\n'
    print_indent "${class_indent}"
    printf '};\n\n'
    print_indent "${class_indent}"
    printf 'void Register%sScript(Canis::App& _app);\n' "${class_name}"
    print_indent "${class_indent}"
    printf 'void UnRegister%sScript(Canis::App& _app);\n' "${class_name}"

    if ((${#namespace_parts[@]} > 0)); then
        write_namespaces_close
    fi
} > "${header_path}"

{
    printf '#include <%s>\n\n' "${relative_header}"
    printf '#include <Canis/App.hpp>\n'
    printf '#include <Canis/ConfigHelper.hpp>\n\n'

    if ((${#namespace_parts[@]} > 0)); then
        write_namespaces_open
    fi

    source_indent=$((${#namespace_parts[@]} * 4))
    block_indent=$((source_indent + 4))

    print_indent "${source_indent}"
    printf 'namespace\n'
    print_indent "${source_indent}"
    printf '{\n'
    print_indent "${block_indent}"
    printf 'Canis::ScriptConf scriptConf = {};\n'
    print_indent "${source_indent}"
    printf '}\n\n'

    print_indent "${source_indent}"
    printf 'void Register%sScript(Canis::App& _app)\n' "${class_name}"
    print_indent "${source_indent}"
    printf '{\n'
    print_indent "${block_indent}"
    printf '// REGISTER_PROPERTY(scriptConf, %s, exampleProperty);\n\n' "${script_symbol_name}"
    print_indent "${block_indent}"
    printf '%s\n\n' "${config_macro}"
    print_indent "${block_indent}"
    printf 'scriptConf.DEFAULT_DRAW_INSPECTOR(%s);\n\n' "${script_symbol_name}"
    print_indent "${block_indent}"
    printf '_app.RegisterScript(scriptConf);\n'
    print_indent "${source_indent}"
    printf '}\n\n'

    print_indent "${source_indent}"
    printf 'DEFAULT_UNREGISTER_SCRIPT(scriptConf, %s)\n\n' "${class_name}"

    print_indent "${source_indent}"
    printf 'void %s::Create() {}\n\n' "${class_name}"
    print_indent "${source_indent}"
    printf 'void %s::Ready() {}\n\n' "${class_name}"
    print_indent "${source_indent}"
    printf 'void %s::Destroy() {}\n\n' "${class_name}"
    print_indent "${source_indent}"
    printf 'void %s::Update(float) {}\n' "${class_name}"

    if ((${#namespace_parts[@]} > 0)); then
        write_namespaces_close
    fi
} > "${source_path}"

printf 'Created %s\n' "${header_path}"
printf 'Created %s\n' "${source_path}"
