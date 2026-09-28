#!/usr/bin/env bash

set -Eeuo pipefail

readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dist_dir="${ROOT_DIR}/dist"

usage() {
    cat <<'EOF'
Usage: scripts/validate.sh [--dist DIR]

Validates built theme artifacts. Optional KDE tools are used when available.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dist)
            [[ $# -ge 2 ]] || { echo "Missing value for --dist" >&2; exit 2; }
            dist_dir="$2"
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

command -v python3 >/dev/null 2>&1 || {
    echo "python3 is required for package validation" >&2
    exit 1
}

dist_dir="$(realpath -m -- "${dist_dir}")"
python3 "${ROOT_DIR}/scripts/validate.py" --root "${ROOT_DIR}" --dist "${dist_dir}"

scanner=""
if command -v qmlimportscanner6 >/dev/null 2>&1; then
    scanner="qmlimportscanner6"
elif command -v qmlimportscanner >/dev/null 2>&1; then
    scanner="qmlimportscanner"
fi

if [[ -n "${scanner}" ]]; then
    for qml_root in \
        "${dist_dir}/themes/sddm/pavver-sddm-theme" \
        "${dist_dir}/themes/lockscreen/pavver-plasma-lockscreen" \
        "${dist_dir}/themes/wallpaper/pavver-wallpaper"; do
        "${scanner}" -rootPath "${qml_root}" >/dev/null
    done
    echo "QML import scan passed"
else
    echo "QML import scan skipped: qmlimportscanner not found"
fi

if command -v kpackagetool6 >/dev/null 2>&1; then
    kpackage_tmp="$(mktemp -d)"
    cleanup() {
        rm -rf -- "${kpackage_tmp}"
    }
    trap cleanup EXIT

    install -d -m 755 "${kpackage_tmp}/data" "${kpackage_tmp}/cache"
    XDG_DATA_HOME="${kpackage_tmp}/data" \
    XDG_CACHE_HOME="${kpackage_tmp}/cache" \
        kpackagetool6 --type Plasma/Shell --install \
        "${dist_dir}/themes/lockscreen/pavver-plasma-lockscreen" >/dev/null
    XDG_DATA_HOME="${kpackage_tmp}/data" \
    XDG_CACHE_HOME="${kpackage_tmp}/cache" \
        kpackagetool6 --type Plasma/Wallpaper --install \
        "${dist_dir}/themes/wallpaper/pavver-wallpaper" >/dev/null

    echo "KPackage installation validation passed"
else
    echo "KPackage validation skipped: kpackagetool6 not found"
fi
