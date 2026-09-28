#!/usr/bin/env bash

set -Eeuo pipefail
umask 022

readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly VERSION="$(<"${ROOT_DIR}/VERSION")"
output_dir="${ROOT_DIR}/dist/packages/arch"
work_dir=""

usage() {
    echo "Usage: scripts/package-arch.sh [--output DIR]"
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

command -v makepkg >/dev/null 2>&1 || {
    echo "makepkg is required to build Arch packages." >&2
    exit 1
}
if [[ ${EUID} -eq 0 ]]; then
    echo "makepkg refuses to run as root; run this script as an unprivileged user." >&2
    exit 1
fi

output_dir="$(realpath -m -- "${output_dir}")"
mkdir -p -- "${output_dir}"
work_dir="$(mktemp -d)"

cleanup() {
    rm -rf -- "${work_dir}"
}
trap cleanup EXIT

build_dir="${work_dir}/pkgbuild"
mkdir -p -- "${build_dir}" "${work_dir}/source"
install -m 644 "${ROOT_DIR}/packaging/arch/PKGBUILD" "${build_dir}/PKGBUILD"
"${ROOT_DIR}/scripts/package-source.sh" --output "${work_dir}/source"
cp -- "${work_dir}/source/pavver-kde6-themes-${VERSION}.tar.gz" "${build_dir}/"
source_hash="$(sha256sum "${build_dir}/pavver-kde6-themes-${VERSION}.tar.gz" | awk '{ print $1 }')"
sed -i "s/sha256sums=('SKIP')/sha256sums=('${source_hash}')/" "${build_dir}/PKGBUILD"


(
    cd "${build_dir}"
    PKGDEST="${output_dir}" \
    SRCDEST="${work_dir}/sources" \
    BUILDDIR="${work_dir}/build" \
        makepkg --cleanbuild --clean --force --noconfirm --nodeps
)

printf 'Built Arch packages in %s\n' "${output_dir}"
