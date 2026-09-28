#!/usr/bin/env bash

set -Eeuo pipefail

readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d)"

cleanup() {
    rm -rf -- "${test_dir}"
}
trap cleanup EXIT

"${ROOT_DIR}/scripts/build.sh" --output "${test_dir}/dist"
"${ROOT_DIR}/scripts/validate.sh" --dist "${test_dir}/dist"

if "${ROOT_DIR}/scripts/build.sh" --output "${test_dir}/dist" >/dev/null 2>&1; then
    echo "Build unexpectedly accepted an existing custom output directory" >&2
    exit 1
fi

cmp \
    "${ROOT_DIR}/shared/PavverTheme/Theme.qml" \
    "${test_dir}/dist/themes/sddm/pavver-sddm-theme/PavverTheme/Theme.qml"
cmp \
    "${ROOT_DIR}/shared/PavverTheme/Theme.qml" \
    "${test_dir}/dist/themes/lockscreen/pavver-plasma-lockscreen/contents/lockscreen/PavverTheme/Theme.qml"
cmp \
    "${ROOT_DIR}/shared/PavverTheme/Theme.qml" \
    "${test_dir}/dist/themes/wallpaper/pavver-wallpaper/contents/ui/PavverTheme/Theme.qml"

if find "${test_dir}/dist" -type l -print -quit | grep -q .; then
    echo "Release output contains a symlink" >&2
    exit 1
fi

echo "Packaging integration test passed"
