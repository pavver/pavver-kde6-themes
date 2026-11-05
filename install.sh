#!/usr/bin/env bash

set -Eeuo pipefail
umask 022

readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
scope=""
component="all"
activate=false
work_dir=""

usage() {
    cat <<'EOF'
Usage: ./install.sh [--user|--system] [--component NAME] [--activate]

Components: all, sddm, lockscreen, wallpaper, splash

Without --activate, files are installed but no current theme setting is changed.
User scope installs lockscreen, wallpaper, and splash. SDDM requires system scope.
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
        --activate)
            activate=true
            shift
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
    all|sddm|lockscreen|wallpaper|splash) ;;
    *)
        echo "Unknown component: ${component}" >&2
        exit 2
        ;;
esac

if [[ -z "${scope}" ]]; then
    if [[ ${EUID} -eq 0 ]]; then
        scope="system"
    else
        scope="user"
    fi
fi

if [[ "${scope}" == "system" && ${EUID} -ne 0 ]]; then
    echo "System installation requires root. Run: sudo ./install.sh --system" >&2
    exit 1
fi
if [[ "${scope}" == "user" && ${EUID} -eq 0 ]]; then
    echo "Refusing a user installation as root. Run without sudo." >&2
    exit 1
fi
if [[ "${scope}" == "user" && ( -z "${HOME:-}" || "${HOME}" == "/" ) ]]; then
    echo "A valid HOME is required for user installation." >&2
    exit 1
fi
if [[ "${scope}" == "user" && "${component}" == "sddm" ]]; then
    echo "SDDM can only be installed with --system." >&2
    exit 1
fi

work_dir="$(mktemp -d)"

cleanup() {
    rm -rf -- "${work_dir}"
}
trap cleanup EXIT

"${ROOT_DIR}/scripts/build.sh" --output "${work_dir}/dist"

if [[ "${scope}" == "system" ]]; then
    data_root="/usr/share"
else
    data_root="${XDG_DATA_HOME:-${HOME}/.local/share}"
fi
lockscreen_target="${data_root}/plasma/shells/pavver-plasma-lockscreen"

is_selected() {
    [[ "${component}" == "all" || "${component}" == "$1" ]]
}

managed_file() {
    local marker="$1"
    [[ -e "${marker}" ]] || return 1

    if command -v pacman >/dev/null 2>&1 && pacman -Qo "${marker}" >/dev/null 2>&1; then
        return 0
    fi
    if command -v dpkg-query >/dev/null 2>&1 && dpkg-query -S "${marker}" >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

install_tree() {
    local source_dir="$1"
    local target_dir="$2"
    local marker="$3"
    local target_parent
    local target_name
    local stage
    local backup=""

    if managed_file "${target_dir}/${marker}"; then
        echo "Refusing to overwrite package-managed files in ${target_dir}." >&2
        echo "Upgrade or remove the distribution package with its package manager." >&2
        exit 1
    fi

    target_parent="$(dirname "${target_dir}")"
    target_name="$(basename "${target_dir}")"
    install -d -m 755 "${target_parent}"
    stage="$(mktemp -d "${target_parent}/.${target_name}.install.XXXXXX")"
    cp -a -- "${source_dir}/." "${stage}/"

    find "${stage}" -type d -exec chmod 755 {} +
    find "${stage}" -type f -exec chmod 644 {} +
    if [[ "${scope}" == "system" ]]; then
        chown -R root:root "${stage}"
    fi

    if [[ -e "${target_dir}" || -L "${target_dir}" ]]; then
        backup="$(mktemp -d "${target_parent}/.${target_name}.backup.XXXXXX")"
        rmdir -- "${backup}"
        mv -- "${target_dir}" "${backup}"
    fi

    if mv -- "${stage}" "${target_dir}"; then
        if [[ -n "${backup}" ]]; then
            rm -rf -- "${backup}"
        fi
    else
        rm -rf -- "${stage}"
        if [[ -n "${backup}" && -e "${backup}" ]]; then
            mv -- "${backup}" "${target_dir}"
        fi
        return 1
    fi

    printf 'Installed %s\n' "${target_dir}"
}


if is_selected sddm; then
    if [[ "${scope}" == "user" ]]; then
        echo "Skipping SDDM in user scope; use sudo ./install.sh --system."
    else
        install_tree \
            "${work_dir}/dist/themes/sddm/pavver-sddm-theme" \
            "/usr/share/sddm/themes/pavver-sddm-theme" \
            "metadata.desktop"
    fi
fi

if is_selected lockscreen; then
    install_tree \
        "${work_dir}/dist/themes/lockscreen/pavver-plasma-lockscreen" \
        "${lockscreen_target}" \
        "metadata.json"
fi

if is_selected wallpaper; then
    install_tree \
        "${work_dir}/dist/themes/wallpaper/pavver-wallpaper" \
        "${data_root}/plasma/wallpapers/pavver-wallpaper" \
        "metadata.json"
fi

if is_selected splash; then
    install_tree \
        "${work_dir}/dist/themes/splash/pavver-splash" \
        "${data_root}/plasma/look-and-feel/pavver-splash" \
        "metadata.json"
fi

if [[ "${activate}" == true ]]; then
    if is_selected sddm && [[ "${scope}" == "system" ]]; then
        install -d -m 755 /etc/sddm.conf.d
        config_tmp="$(mktemp /etc/sddm.conf.d/.zz-pavver-theme.conf.XXXXXX)"
        printf '[Theme]\nCurrent=pavver-sddm-theme\n' > "${config_tmp}"
        chmod 644 "${config_tmp}"
        chown root:root "${config_tmp}"
        mv -f -- "${config_tmp}" /etc/sddm.conf.d/zz-pavver-theme.conf
        echo "Activated the SDDM theme."
        if [[ -f /etc/sddm.conf ]] && awk '
            /^\[Theme\][[:space:]]*$/ { in_theme = 1; next }
            /^\[/ { in_theme = 0 }
            in_theme && /^[[:space:]]*Current[[:space:]]*=/ { found = 1 }
            END { exit(found ? 0 : 1) }
        ' /etc/sddm.conf; then
            echo "Warning: /etc/sddm.conf has its own Theme/Current and may override the drop-in." >&2
        fi
    fi

    if is_selected lockscreen; then
        if [[ "${scope}" == "system" ]]; then
            sys_lock_dir="/usr/share/plasma/shells/org.kde.plasma.desktop/contents/lockscreen"
            sys_lock_backup="/usr/share/plasma/shells/org.kde.plasma.desktop/contents/.lockscreen.orig"
            if [[ -d "${sys_lock_dir}" ]]; then
                # Plasma upgrades restore stock QML, which makes any earlier backup stale.
                if ! grep -q LockScreenBackend "${sys_lock_dir}/LockScreenUi.qml"; then
                    rm -rf -- "${sys_lock_backup}"
                    cp -a -- "${sys_lock_dir}" "${sys_lock_backup}"
                    rm -rf -- "${sys_lock_backup}/LockScreenBackend.qml" "${sys_lock_backup}/PavverTheme"
                fi
                cp -a -- "${work_dir}/dist/themes/lockscreen/pavver-plasma-lockscreen/contents/lockscreen/." "${sys_lock_dir}/"
                echo "Activated the lock screen in KDE Plasma 6 (desktop session and panels preserved)."
            else
                echo "Warning: ${sys_lock_dir} not found; lock screen installed as standalone package only." >&2
            fi
        else
            echo "Lock screen installed in user scope."
            echo "To safely replace the active system lock screen in Plasma 6, run: sudo ./install.sh --system --component lockscreen --activate"
        fi

        # Always protect desktop panels: ensure plasmashellrc does not use pavver-plasma-lockscreen as full shell
        if command -v kreadconfig6 >/dev/null 2>&1 && command -v kwriteconfig6 >/dev/null 2>&1; then
            current_shell="$(kreadconfig6 --file plasmashellrc --group Shell --key ShellPackage 2>/dev/null || true)"
            if [[ "${current_shell}" == "pavver-plasma-lockscreen" ]]; then
                kwriteconfig6 --file plasmashellrc --group Shell --key ShellPackage "org.kde.plasma.desktop" --notify
                echo "Restored plasmashellrc ShellPackage to org.kde.plasma.desktop to protect desktop panels."
            fi
        fi
    fi
fi

if [[ "${activate}" == true ]] && is_selected splash; then
    if [[ "${scope}" == "user" ]]; then
        command -v kwriteconfig6 >/dev/null 2>&1 || {
            echo "kwriteconfig6 is required to activate the splash screen." >&2
            exit 1
        }
        kwriteconfig6 --file ksplashrc --group KSplash --key Engine KSplashQML
        kwriteconfig6 --file ksplashrc --group KSplash --key Theme pavver-splash
        echo "Activated the splash screen for the next login."
    else
        echo "The splash screen is selected per user. Run: ./install.sh --user --component splash --activate"
    fi
fi

if is_selected wallpaper; then
    echo "Select 'Pavver Animated Wallpaper' in Desktop and Wallpaper settings."
fi
if is_selected splash && [[ "${activate}" == false ]]; then
    echo "Select 'Pavver Splash' in Splash Screen settings, or run: ./install.sh --user --component splash --activate"
fi
if is_selected sddm && [[ "${scope}" == "system" && "${activate}" == false ]]; then
    echo "Select 'Pavver SDDM Theme' in Login Screen settings, or rerun with --activate."
fi
if is_selected lockscreen && [[ "${activate}" == false ]]; then
    echo "To activate the lock screen in Plasma 6, rerun with: sudo ./install.sh --system --component lockscreen --activate"
fi
