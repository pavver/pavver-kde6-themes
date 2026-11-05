#!/usr/bin/env bash

# Regenerates plymouth/frames from LoginLoader. Needs a working GPU session:
# the offscreen Qt platform drops the blurred triangle layer.

set -Eeuo pipefail

readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work_dir="$(mktemp -d)"
trap 'rm -rf -- "${work_dir}"' EXIT

mkdir -p -- "${work_dir}/raw"
cat > "${work_dir}/render.sh" <<INNER
#!/usr/bin/env bash
QT_QPA_PLATFORM=wayland exec qml6 "${ROOT_DIR}/plymouth/tools/RenderFrames.qml" -- "${work_dir}/raw"
INNER
chmod +x "${work_dir}/render.sh"

env -u DISPLAY -u WAYLAND_DISPLAY dbus-run-session -- kwin_wayland --virtual \
    --no-lockscreen --no-global-shortcuts --width 1920 --height 1080 \
    --socket "pavver-render-$$" --exit-with-session "${work_dir}/render.sh"

rm -rf -- "${ROOT_DIR}/plymouth/frames"
python3 "${ROOT_DIR}/plymouth/tools/crop_frames.py" "${work_dir}/raw" "${ROOT_DIR}/plymouth/frames"
python3 "${ROOT_DIR}/plymouth/tools/render_labels.py" \
    "${ROOT_DIR}/shared/PavverTheme/fonts/CascadiaCode.ttf" "${ROOT_DIR}/plymouth/labels"
