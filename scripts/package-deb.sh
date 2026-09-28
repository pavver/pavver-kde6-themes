#!/usr/bin/env bash

set -Eeuo pipefail
umask 022

readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly VERSION="$(<"${ROOT_DIR}/VERSION")"
output_dir="${ROOT_DIR}/dist/packages/debian"
work_dir=""

usage() {
    echo "Usage: scripts/package-deb.sh [--output DIR]"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output)
            [[ $# -ge 2 ]] || { echo "Missing value for --output" >&2; exit 2; }
            output_dir="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            exit 2
            ;;
    esac
done

command -v dpkg-deb >/dev/null 2>&1 || {
    echo "dpkg-deb is required to build Debian packages." >&2
    exit 1
}

output_dir="$(realpath -m -- "${output_dir}")"
mkdir -p -- "${output_dir}"
work_dir="$(mktemp -d)"

cleanup() {
    rm -rf -- "${work_dir}"
}
trap cleanup EXIT

"${ROOT_DIR}/scripts/build.sh" --output "${work_dir}/dist"

build_component() {
    local package_name="$1"
    local source_dir="$2"
    local install_path="$3"
    local depends="$4"
    local summary="$5"
    local details="$6"
    local readme_path="$7"
    local package_root="${work_dir}/${package_name}"
    local installed_size

    mkdir -p -- "${package_root}/DEBIAN" "${package_root}$(dirname "${install_path}")"
    cp -a -- "${source_dir}" "${package_root}${install_path}"
    install -d -m 755 "${package_root}/usr/share/doc/${package_name}"
    install -m 644 "${ROOT_DIR}/LICENSE" \
        "${package_root}/usr/share/doc/${package_name}/copyright"
    install -m 644 "${readme_path}" \
        "${package_root}/usr/share/doc/${package_name}/README.md"

    installed_size="$(du -sk "${package_root}" | awk '{ print $1 }')"
    {
        printf 'Package: %s\n' "${package_name}"
        printf 'Version: %s\n' "${VERSION}"
        printf 'Section: kde\n'
        printf 'Priority: optional\n'
        printf 'Architecture: all\n'
        printf 'Multi-Arch: foreign\n'
        printf 'Maintainer: pavver <pavvers1@gmail.com>\n'
        printf 'Depends: %s\n' "${depends}"
        printf 'Installed-Size: %s\n' "${installed_size}"
        printf 'Homepage: https://github.com/pavver/pavver-kde6-themes\n'
        printf 'Description: %s\n' "${summary}"
        printf ' %s\n' "${details}"
    } > "${package_root}/DEBIAN/control"

    find "${package_root}" -type d -exec chmod 755 {} +
    find "${package_root}" -type f -exec chmod 644 {} +

    dpkg-deb --root-owner-group --build \
        "${package_root}" \
        "${output_dir}/${package_name}_${VERSION}_all.deb" >/dev/null
}

build_component \
    pavver-sddm-theme \
    "${work_dir}/dist/themes/sddm/pavver-sddm-theme" \
    /usr/share/sddm/themes/pavver-sddm-theme \
    'sddm (>= 0.20), plasma-workspace (>= 6.0), qml6-module-qtquick, qml6-module-qtquick-controls, qml6-module-qtquick-window, qml6-module-qtquick-shapes, qml6-module-qt5compat-graphicaleffects, qml6-module-org-kde-kirigami' \
    'Pavver login theme for Qt 6 SDDM' \
    'Installs the standalone Pavver SDDM theme and its System Settings preview.' \
    "${ROOT_DIR}/sddm/README.md"

build_component \
    pavver-plasma-lockscreen \
    "${work_dir}/dist/themes/lockscreen/pavver-plasma-lockscreen" \
    /usr/share/plasma/shells/pavver-plasma-lockscreen \
    'plasma-desktop (>= 6.0), plasma-workspace (>= 6.0), qml6-module-qtquick, qml6-module-qtquick-controls, qml6-module-qtquick-window, qml6-module-qtquick-shapes, qml6-module-qt5compat-graphicaleffects, qml6-module-org-kde-kirigami' \
    'Pavver lock screen shell package for Plasma 6' \
    'Installs the standalone Pavver lock screen and release preview assets.' \
    "${ROOT_DIR}/lockscreen/README.md"

build_component \
    pavver-wallpaper \
    "${work_dir}/dist/themes/wallpaper/pavver-wallpaper" \
    /usr/share/plasma/wallpapers/pavver-wallpaper \
    'plasma-workspace (>= 6.0), qml6-module-qtquick, qml6-module-qtquick-controls, qml6-module-qtquick-window, qml6-module-qtquick-shapes, qml6-module-qt5compat-graphicaleffects, qml6-module-org-kde-kirigami' \
    'Pavver animated wallpaper for Plasma 6' \
    'Installs a configurable animated wallpaper visible in Desktop settings.' \
    "${ROOT_DIR}/wallpaper/README.md"

meta_root="${work_dir}/pavver-kde6-themes"
mkdir -p -- "${meta_root}/DEBIAN" "${meta_root}/usr/share/doc/pavver-kde6-themes"
install -m 644 "${ROOT_DIR}/LICENSE" "${meta_root}/usr/share/doc/pavver-kde6-themes/copyright"
install -m 644 "${ROOT_DIR}/README.md" "${meta_root}/usr/share/doc/pavver-kde6-themes/README.md"
{
    printf 'Package: pavver-kde6-themes\n'
    printf 'Version: %s\n' "${VERSION}"
    printf 'Section: kde\n'
    printf 'Priority: optional\n'
    printf 'Architecture: all\n'
    printf 'Multi-Arch: foreign\n'
    printf 'Maintainer: pavver <pavvers1@gmail.com>\n'
    printf 'Depends: pavver-sddm-theme (= %s), pavver-plasma-lockscreen (= %s), pavver-wallpaper (= %s)\n' \
        "${VERSION}" "${VERSION}" "${VERSION}"
    printf 'Installed-Size: 1\n'
    printf 'Homepage: https://github.com/pavver/pavver-kde6-themes\n'
    printf 'Description: Complete Pavver visual theme family for KDE Plasma 6\n'
    printf ' Pulls in the SDDM, lock screen, and animated wallpaper packages.\n'
} > "${meta_root}/DEBIAN/control"
find "${meta_root}" -type d -exec chmod 755 {} +
find "${meta_root}" -type f -exec chmod 644 {} +
dpkg-deb --root-owner-group --build \
    "${meta_root}" \
    "${output_dir}/pavver-kde6-themes_${VERSION}_all.deb" >/dev/null

for package_path in "${output_dir}"/*_"${VERSION}"_all.deb; do
    dpkg-deb --info "${package_path}" >/dev/null
done

printf 'Built Debian packages in %s\n' "${output_dir}"
