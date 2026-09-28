#!/usr/bin/env bash

set -Eeuo pipefail
umask 022

readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly VERSION="$(<"${ROOT_DIR}/VERSION")"
output_dir="${ROOT_DIR}/dist/packages/source"
work_dir=""

usage() {
    echo "Usage: scripts/package-source.sh [--output DIR]"
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

command -v tar >/dev/null 2>&1 || { echo "tar is required" >&2; exit 1; }
command -v gzip >/dev/null 2>&1 || { echo "gzip is required" >&2; exit 1; }

output_dir="$(realpath -m -- "${output_dir}")"
mkdir -p -- "${output_dir}"
work_dir="$(mktemp -d)"

cleanup() {
    rm -rf -- "${work_dir}"
}
trap cleanup EXIT

archive_root="pavver-kde6-themes-${VERSION}"
mkdir -p -- "${work_dir}/${archive_root}"

tar \
    --exclude='./.git' \
    --exclude='./.cache' \
    --exclude='./build' \
    --exclude='./dist' \
    --exclude='*/__pycache__' \
    --exclude='*.pyc' \
    -C "${ROOT_DIR}" -cf - . \
    | tar -C "${work_dir}/${archive_root}" -xf -

if [[ -n "${SOURCE_DATE_EPOCH:-}" ]]; then
    archive_mtime="${SOURCE_DATE_EPOCH}"
elif git -C "${ROOT_DIR}" log -1 --format=%ct >/dev/null 2>&1; then
    archive_mtime="$(git -C "${ROOT_DIR}" log -1 --format=%ct)"
else
    archive_mtime=0
fi

archive_path="${output_dir}/${archive_root}.tar.gz"
tar \
    --sort=name \
    --mtime="@${archive_mtime}" \
    --owner=0 \
    --group=0 \
    --numeric-owner \
    -C "${work_dir}" -cf - "${archive_root}" \
    | gzip -n > "${archive_path}"

printf 'Built source archive %s\n' "${archive_path}"
