#!/usr/bin/env bash

set -Eeuo pipefail

file=""
group=""
key=""
default_value=""
value=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --file)
            file="$2"
            shift 2
            ;;
        --group)
            group="$2"
            shift 2
            ;;
        --key)
            key="$2"
            shift 2
            ;;
        --default)
            default_value="$2"
            shift 2
            ;;
        --notify)
            shift
            ;;
        *)
            value="$1"
            shift
            ;;
    esac
done

[[ -n "${file}" && -n "${group}" && -n "${key}" ]]
config_dir="${XDG_CONFIG_HOME:?}/.kconfig-mock"
config_path="${config_dir}/${file}.${group}.${key}"

case "$(basename "$0")" in
    kreadconfig6)
        if [[ -f "${config_path}" ]]; then
            cat -- "${config_path}"
        else
            printf '%s\n' "${default_value}"
        fi
        ;;
    kwriteconfig6)
        mkdir -p -- "${config_dir}"
        printf '%s\n' "${value}" > "${config_path}"
        ;;
    *)
        echo "Unsupported KConfig mock command: $0" >&2
        exit 2
        ;;
esac
