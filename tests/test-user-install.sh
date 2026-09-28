#!/usr/bin/env bash

set -Eeuo pipefail

readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_home="$(mktemp -d)"

cleanup() {
    rm -rf -- "${test_home}"
}
trap cleanup EXIT

export HOME="${test_home}"
export XDG_DATA_HOME="${test_home}/data"

"${ROOT_DIR}/install.sh" --user
test -f "${XDG_DATA_HOME}/plasma/shells/pavver-plasma-lockscreen/metadata.json"
test -f "${XDG_DATA_HOME}/plasma/wallpapers/pavver-wallpaper/metadata.json"
test ! -e "${XDG_DATA_HOME}/sddm"

"${ROOT_DIR}/uninstall.sh" --user
test ! -e "${XDG_DATA_HOME}/plasma/shells/pavver-plasma-lockscreen"
test ! -e "${XDG_DATA_HOME}/plasma/wallpapers/pavver-wallpaper"

echo "User install/uninstall integration test passed"
