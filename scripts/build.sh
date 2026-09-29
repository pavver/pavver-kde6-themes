#!/usr/bin/env bash

set -Eeuo pipefail
umask 022

readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly SHARED_DIR="${ROOT_DIR}/shared/PavverTheme"
output_dir="${ROOT_DIR}/dist"
custom_output=false
staging_dir=""

usage() {
    cat <<'EOF'
Usage: scripts/build.sh [--output DIR]

Builds standalone SDDM, lock screen, and wallpaper packages.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output)
            [[ $# -ge 2 ]] || { echo "Missing value for --output" >&2; exit 2; }
            output_dir="$2"
            custom_output=true
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

for required_path in \
    VERSION \
    LICENSE \
    shared/PavverTheme/qmldir \
    sddm/Main.qml \
    sddm/SddmBackend.qml \
    sddm/metadata.desktop \
    sddm/theme.conf \
    sddm/preview.png \
    lockscreen/metadata.json \
    lockscreen/contents/lockscreen/LockScreen.qml \
    lockscreen/contents/lockscreen/LockScreenUi.qml \
    lockscreen/contents/lockscreen/LockScreenBackend.qml \
    lockscreen/contents/lockscreen/LockOsd.qml \
    lockscreen/contents/lockscreen/PasswordSync.qml \
    lockscreen/contents/lockscreen/qmldir \
    lockscreen/preview.png \
    lockscreen/preview_screensaver.png \
    wallpaper/metadata.json \
    wallpaper/contents/ui/main.qml \
    wallpaper/contents/ui/config.qml \
    wallpaper/contents/config/main.xml; do
    [[ -e "${ROOT_DIR}/${required_path}" ]] || {
        echo "Missing required source path: ${required_path}" >&2
        exit 1
    }
done

output_dir="$(realpath -m -- "${output_dir}")"
readonly default_output="${ROOT_DIR}/dist"

case "${output_dir}" in
    /|"${ROOT_DIR}"|"${ROOT_DIR}/"|"${HOME:-/nonexistent}")
        echo "Refusing unsafe output directory: ${output_dir}" >&2
        exit 1
        ;;
esac

if [[ "${custom_output}" == false && "${output_dir}" != "${default_output}" ]]; then
    echo "Refusing a default output path redirected outside the repository." >&2
    exit 1
fi
if [[ "${custom_output}" == true && ( -e "${output_dir}" || -L "${output_dir}" ) ]]; then
    echo "Custom output directory already exists: ${output_dir}" >&2
    exit 1
fi

output_parent="$(dirname "${output_dir}")"
mkdir -p -- "${output_parent}"
staging_dir="$(mktemp -d "${output_parent}/.pavver-build.XXXXXX")"

cleanup() {
    if [[ -n "${staging_dir}" && -d "${staging_dir}" ]]; then
        rm -rf -- "${staging_dir}"
    fi
}
trap cleanup EXIT

sddm_target="${staging_dir}/themes/sddm/pavver-sddm-theme"
lock_target="${staging_dir}/themes/lockscreen/pavver-plasma-lockscreen"
wallpaper_target="${staging_dir}/themes/wallpaper/pavver-wallpaper"

mkdir -p -- "${sddm_target}" "${lock_target}" "${wallpaper_target}"

install -m 644 "${ROOT_DIR}/sddm/Main.qml" "${sddm_target}/Main.qml"
install -m 644 "${ROOT_DIR}/sddm/SddmBackend.qml" "${sddm_target}/SddmBackend.qml"
install -m 644 "${ROOT_DIR}/sddm/metadata.desktop" "${sddm_target}/metadata.desktop"
install -m 644 "${ROOT_DIR}/sddm/theme.conf" "${sddm_target}/theme.conf"
install -m 644 "${ROOT_DIR}/sddm/preview.png" "${sddm_target}/preview.png"
install -m 644 "${ROOT_DIR}/LICENSE" "${sddm_target}/LICENSE"
cp -a -- "${SHARED_DIR}" "${sddm_target}/PavverTheme"

install -m 644 "${ROOT_DIR}/lockscreen/metadata.json" "${lock_target}/metadata.json"
install -m 644 "${ROOT_DIR}/LICENSE" "${lock_target}/LICENSE"
mkdir -p -- "${lock_target}/contents/lockscreen"
install -m 644 \
    "${ROOT_DIR}/lockscreen/contents/lockscreen/LockScreen.qml" \
    "${ROOT_DIR}/lockscreen/contents/lockscreen/LockScreenUi.qml" \
    "${ROOT_DIR}/lockscreen/contents/lockscreen/LockScreenBackend.qml" \
    "${ROOT_DIR}/lockscreen/contents/lockscreen/LockOsd.qml" \
    "${ROOT_DIR}/lockscreen/contents/lockscreen/PasswordSync.qml" \
    "${ROOT_DIR}/lockscreen/contents/lockscreen/qmldir" \
    "${lock_target}/contents/lockscreen/"
cp -a -- "${SHARED_DIR}" "${lock_target}/contents/lockscreen/PavverTheme"
for preview in "${ROOT_DIR}"/lockscreen/preview*.png; do
    install -m 644 "${preview}" "${lock_target}/$(basename "${preview}")"
done

install -m 644 "${ROOT_DIR}/wallpaper/metadata.json" "${wallpaper_target}/metadata.json"
install -m 644 "${ROOT_DIR}/lockscreen/preview_screensaver.png" "${wallpaper_target}/preview.png"
install -m 644 "${ROOT_DIR}/LICENSE" "${wallpaper_target}/LICENSE"
cp -a -- "${ROOT_DIR}/wallpaper/contents" "${wallpaper_target}/contents"
cp -a -- "${SHARED_DIR}" "${wallpaper_target}/contents/ui/PavverTheme"

find "${staging_dir}" -type d -exec chmod 755 {} +
find "${staging_dir}" -type f -exec chmod 644 {} +

"${ROOT_DIR}/scripts/validate.sh" --dist "${staging_dir}"

if [[ -e "${output_dir}" || -L "${output_dir}" ]]; then
    rm -rf -- "${output_dir}"
fi
mv -- "${staging_dir}" "${output_dir}"
staging_dir=""

printf 'Built Pavver themes in %s\n' "${output_dir}"
