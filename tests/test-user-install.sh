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
export XDG_CONFIG_HOME="${test_home}/config"
export XDG_STATE_HOME="${test_home}/state"

mkdir -p -- "${test_home}/bin"
ln -s -- "${ROOT_DIR}/tests/kconfig-mock.sh" "${test_home}/bin/kreadconfig6"
ln -s -- "${ROOT_DIR}/tests/kconfig-mock.sh" "${test_home}/bin/kwriteconfig6"
export PATH="${test_home}/bin:${PATH}"

"${ROOT_DIR}/install.sh" --user
test -f "${XDG_DATA_HOME}/plasma/shells/pavver-plasma-lockscreen/metadata.json"
test -f "${XDG_DATA_HOME}/plasma/wallpapers/pavver-wallpaper/metadata.json"
test ! -e "${XDG_DATA_HOME}/sddm"

"${ROOT_DIR}/uninstall.sh" --user
test ! -e "${XDG_DATA_HOME}/plasma/shells/pavver-plasma-lockscreen"
test ! -e "${XDG_DATA_HOME}/plasma/wallpapers/pavver-wallpaper"

kwriteconfig6 --file plasmashellrc --group Shell \
    --key ShellPackage example.custom.shell

"${ROOT_DIR}/install.sh" --user --component lockscreen --activate
test "$(kreadconfig6 --file plasmashellrc --group Shell --key ShellPackage)" = \
    "pavver-plasma-lockscreen"
test "$(cat "${XDG_STATE_HOME}/pavver-kde6-themes/previous-shell-package")" = \
    "example.custom.shell"
python3 - "${XDG_DATA_HOME}/plasma/shells/pavver-plasma-lockscreen/metadata.json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as metadata_file:
    metadata = json.load(metadata_file)
assert metadata["X-Plasma-FallbackPackage"] == "example.custom.shell"
PY

"${ROOT_DIR}/install.sh" --user --component lockscreen --activate
test "$(cat "${XDG_STATE_HOME}/pavver-kde6-themes/previous-shell-package")" = \
    "example.custom.shell"
python3 -c 'import json, sys; assert json.load(open(sys.argv[1]))["X-Plasma-FallbackPackage"] == "example.custom.shell"' \
    "${XDG_DATA_HOME}/plasma/shells/pavver-plasma-lockscreen/metadata.json"

"${ROOT_DIR}/uninstall.sh" --user --component lockscreen
test "$(kreadconfig6 --file plasmashellrc --group Shell --key ShellPackage)" = \
    "example.custom.shell"
test ! -e "${XDG_STATE_HOME}/pavver-kde6-themes/previous-shell-package"

echo "User install/uninstall integration test passed"
