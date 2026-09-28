#!/usr/bin/env bash

set -Eeuo pipefail

scope=""
component="all"

usage() {
    cat <<'EOF'
Usage: ./uninstall.sh [--user|--system] [--component NAME]

Components: all, sddm, lockscreen, wallpaper
Use the distribution package manager instead when the files are package-managed.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --user)
            scope="user"
            shift
            ;;
        --system)
            scope="system"
            shift
            ;;
        --component)
            [[ $# -ge 2 ]] || { echo "Missing value for --component" >&2; exit 2; }
            component="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

case "${component}" in
    all|sddm|lockscreen|wallpaper) ;;
    *)
        echo "Unknown component: ${component}" >&2
        exit 2
        ;;
esac

if [[ -z "${scope}" ]]; then
    [[ ${EUID} -eq 0 ]] && scope="system" || scope="user"
fi
if [[ "${scope}" == "system" && ${EUID} -ne 0 ]]; then
    echo "System removal requires root." >&2
    exit 1
fi
if [[ "${scope}" == "user" && ${EUID} -eq 0 ]]; then
    echo "Refusing a user removal as root." >&2
    exit 1
fi
if [[ "${scope}" == "user" && ( -z "${HOME:-}" || "${HOME}" == "/" ) ]]; then
    echo "A valid HOME is required for user removal." >&2
    exit 1
fi
if [[ "${scope}" == "user" && "${component}" == "sddm" ]]; then
    echo "SDDM can only be removed with --system." >&2
    exit 1
fi

if [[ "${scope}" == "system" ]]; then
    data_root="/usr/share"
else
    data_root="${XDG_DATA_HOME:-${HOME}/.local/share}"
fi
lockscreen_target="${data_root}/plasma/shells/pavver-plasma-lockscreen"

is_selected() {
    [[ "${component}" == "all" || "${component}" == "$1" ]]
}

refuse_if_managed() {
    local marker="$1"
    [[ -e "${marker}" ]] || return 0

    if command -v pacman >/dev/null 2>&1 && pacman -Qo "${marker}" >/dev/null 2>&1; then
        echo "${marker} is managed by pacman; remove its package with pacman." >&2
        exit 1
    fi
    if command -v dpkg-query >/dev/null 2>&1 && dpkg-query -S "${marker}" >/dev/null 2>&1; then
        echo "${marker} is managed by dpkg; remove its package with apt or dpkg." >&2
        exit 1
    fi
}

remove_tree() {
    local target_dir="$1"
    local marker="$2"

    refuse_if_managed "${target_dir}/${marker}"
    if [[ -e "${target_dir}" || -L "${target_dir}" ]]; then
        rm -rf -- "${target_dir}"
        printf 'Removed %s\n' "${target_dir}"
    else
        printf 'Not installed: %s\n' "${target_dir}"
    fi
}

if is_selected lockscreen && [[ "${scope}" == "user" ]]; then
    state_dir="${XDG_STATE_HOME:-${HOME}/.local/state}/pavver-kde6-themes"
    state_file="${state_dir}/previous-shell-package"
    if command -v kreadconfig6 >/dev/null 2>&1 \
        && command -v kwriteconfig6 >/dev/null 2>&1 \
        && [[ "$(kreadconfig6 --file plasmashellrc --group Shell --key ShellPackage)" == "pavver-plasma-lockscreen" ]]; then
        previous_shell_package="org.kde.plasma.desktop"
        if [[ -f "${state_file}" ]]; then
            IFS= read -r saved_shell_package < "${state_file}" || true
            if [[ "${saved_shell_package:-}" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ \
                && "${saved_shell_package}" != "pavver-plasma-lockscreen" ]]; then
                previous_shell_package="${saved_shell_package}"
            fi
        fi
        kwriteconfig6 --file plasmashellrc --group Shell \
            --key ShellPackage "${previous_shell_package}" --notify
        echo "Restored the previous Plasma shell before removing the lock screen."
    fi
fi

if is_selected sddm; then
    if [[ "${scope}" == "user" ]]; then
        echo "Skipping SDDM in user scope."
    else
        remove_tree /usr/share/sddm/themes/pavver-sddm-theme metadata.desktop
        if [[ -f /etc/sddm.conf.d/zz-pavver-theme.conf ]] \
            && grep -Eq \
                '^[[:space:]]*Current[[:space:]]*=[[:space:]]*pavver-sddm-theme[[:space:]]*$' \
                /etc/sddm.conf.d/zz-pavver-theme.conf; then
            rm -f -- /etc/sddm.conf.d/zz-pavver-theme.conf
            echo "Removed the Pavver SDDM activation drop-in."
        fi
    fi
fi

if is_selected lockscreen; then
    remove_tree "${lockscreen_target}" metadata.json
    if [[ "${scope}" == "user" && -n "${state_file:-}" ]]; then
        rm -f -- "${state_file}"
        rmdir -- "${state_dir}" 2>/dev/null || true
    fi
fi

if is_selected wallpaper; then
    remove_tree "${data_root}/plasma/wallpapers/pavver-wallpaper" metadata.json
    echo "If the wallpaper was active, select another wallpaper in System Settings."
fi
