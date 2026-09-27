#!/usr/bin/env bash
# ==============================================================================
# Pavver SDDM Theme Installation Script
# ==============================================================================

set -Eeuo pipefail
umask 022

readonly THEME_NAME="pavver-sddm-theme"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly THEMES_DIR="/usr/share/sddm/themes"
readonly TARGET_DIR="${THEMES_DIR}/${THEME_NAME}"
readonly SDDM_CONF_DIR="/etc/sddm.conf.d"
readonly SDDM_THEME_CONF="${SDDM_CONF_DIR}/zz-pavver-theme.conf"
readonly SDDM_MAIN_CONF="/etc/sddm.conf"
readonly BACKUP_BASE="/var/backups/${THEME_NAME}"

staging_dir=""
config_tmp=""
backup_dir=""

cleanup() {
    if [[ -n "${staging_dir}" && -d "${staging_dir}" ]]; then
        rm -rf -- "${staging_dir}"
    fi
    if [[ -n "${config_tmp}" && -f "${config_tmp}" ]]; then
        rm -f -- "${config_tmp}"
    fi
}
trap cleanup EXIT

ensure_backup_dir() {
    if [[ -z "${backup_dir}" ]]; then
        install -d -m 700 "${BACKUP_BASE}"
        backup_dir="$(mktemp -d "${BACKUP_BASE}/$(date -u +%Y%m%d-%H%M%S).XXXXXX")"
        chmod 700 "${backup_dir}"
    fi
}

main_config_overrides_theme() {
    [[ -f "${SDDM_MAIN_CONF}" ]] || return 1
    awk '
        /^\[[^]]+\][[:space:]]*$/ {
            in_theme = ($0 ~ /^\[Theme\][[:space:]]*$/)
            next
        }
        in_theme && /^[[:space:]]*Current[[:space:]]*=/ { found = 1 }
        END { exit(found ? 0 : 1) }
    ' "${SDDM_MAIN_CONF}"
}

update_main_config() {
    local output_path="$1"
    awk -v theme="${THEME_NAME}" '
        /^\[[^]]+\][[:space:]]*$/ {
            in_theme = ($0 ~ /^\[Theme\][[:space:]]*$/)
            print
            next
        }
        in_theme && /^[[:space:]]*Current[[:space:]]*=/ {
            if (!updated) print "Current=" theme
            updated = 1
            next
        }
        { print }
    ' "${SDDM_MAIN_CONF}" > "${output_path}"
}

echo "======================================================="
echo "   Встановлення теми SDDM: ${THEME_NAME}"
echo "======================================================="

if [[ ${EUID} -ne 0 ]]; then
    echo "(!) Цей скрипт потребує прав адміністратора (root)."
    echo "    Запустіть його через sudo: sudo ./install.sh"
    exit 1
fi

for required_path in Main.qml SddmBackend.qml metadata.desktop theme.conf preview.png PavverTheme; do
    if [[ ! -e "${SCRIPT_DIR}/${required_path}" ]]; then
        echo "(!) Не знайдено обов'язковий файл або каталог: ${required_path}" >&2
        exit 1
    fi
done

echo "[1/5] Перевірка середовища..."
if ! command -v sddm-greeter-qt6 >/dev/null 2>&1; then
    echo "(!) Не знайдено sddm-greeter-qt6. Встановіть Qt 6 версію SDDM." >&2
    exit 1
fi
if command -v qmlimportscanner >/dev/null 2>&1; then
    if ! qmlimportscanner -rootPath "${SCRIPT_DIR}" >/dev/null; then
        echo "(!) Не вдалося просканувати QML-імпорти теми." >&2
        exit 1
    fi
fi

echo "[2/5] Підготовка файлів теми..."
install -d -m 755 "${THEMES_DIR}"
staging_dir="$(mktemp -d "${THEMES_DIR}/.${THEME_NAME}.XXXXXX")"
install -m 644 "${SCRIPT_DIR}/Main.qml" "${staging_dir}/Main.qml"
install -m 644 "${SCRIPT_DIR}/SddmBackend.qml" "${staging_dir}/SddmBackend.qml"
install -m 644 "${SCRIPT_DIR}/metadata.desktop" "${staging_dir}/metadata.desktop"
install -m 644 "${SCRIPT_DIR}/theme.conf" "${staging_dir}/theme.conf"
install -m 644 "${SCRIPT_DIR}/preview.png" "${staging_dir}/preview.png"
cp -RL "${SCRIPT_DIR}/PavverTheme" "${staging_dir}/PavverTheme"
find "${staging_dir}" -type d -exec chmod 755 {} +
find "${staging_dir}" -type f -exec chmod 644 {} +
chown -R root:root "${staging_dir}"

echo "[3/5] Резервне копіювання попередньої версії..."
if [[ -e "${TARGET_DIR}" ]]; then
    ensure_backup_dir
    mv -- "${TARGET_DIR}" "${backup_dir}/theme"
    echo "      Попередню тему переміщено до ${backup_dir}/theme"
else
    echo "      Попередню версію теми не знайдено."
fi

if ! mv -- "${staging_dir}" "${TARGET_DIR}"; then
    echo "(!) Не вдалося встановити нову версію теми." >&2
    if [[ -n "${backup_dir}" && -d "${backup_dir}/theme" && ! -e "${TARGET_DIR}" ]]; then
        mv -- "${backup_dir}/theme" "${TARGET_DIR}"
        echo "    Попередню версію відновлено." >&2
    fi
    exit 1
fi
staging_dir=""

echo "[4/5] Налаштування SDDM..."
install -d -m 755 "${SDDM_CONF_DIR}"
if [[ -f "${SDDM_THEME_CONF}" ]]; then
    ensure_backup_dir
    cp -a -- "${SDDM_THEME_CONF}" "${backup_dir}/zz-pavver-theme.conf"
    echo "      Резервна копія конфігурації: ${backup_dir}/zz-pavver-theme.conf"
fi

config_tmp="$(mktemp "${SDDM_CONF_DIR}/.zz-pavver-theme.conf.XXXXXX")"
printf '[Theme]\nCurrent=%s\n' "${THEME_NAME}" > "${config_tmp}"
chmod 644 "${config_tmp}"
chown root:root "${config_tmp}"
mv -f -- "${config_tmp}" "${SDDM_THEME_CONF}"
config_tmp=""

if main_config_overrides_theme; then
    ensure_backup_dir
    cp -a -- "${SDDM_MAIN_CONF}" "${backup_dir}/sddm.conf"
    config_tmp="$(mktemp "/etc/.sddm.conf.XXXXXX")"
    update_main_config "${config_tmp}"
    chmod --reference="${SDDM_MAIN_CONF}" "${config_tmp}"
    chown --reference="${SDDM_MAIN_CONF}" "${config_tmp}"
    mv -f -- "${config_tmp}" "${SDDM_MAIN_CONF}"
    config_tmp=""
    echo "      Узгоджено Current= у ${SDDM_MAIN_CONF}; резервна копія: ${backup_dir}/sddm.conf"
fi

echo "[5/5] Тему встановлено та активовано."
if [[ -n "${backup_dir}" ]]; then
    echo "      Резервні копії: ${backup_dir}"
fi
echo "======================================================="
echo "Перевірка без перезавантаження:"
echo "sddm-greeter-qt6 --test-mode --theme ${TARGET_DIR}"
echo "======================================================="
