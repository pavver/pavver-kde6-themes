#!/usr/bin/env bash

# Tries Plymouth in a separate ZFS boot environment, leaving the running system
# and the default boot entry untouched.
#
#   sudo plymouth/boot-environment-test.sh create   # build the test environment
#   sudo plymouth/boot-environment-test.sh remove   # delete it again
#   sudo plymouth/boot-environment-test.sh apply    # move Plymouth to the main system
#
# The test environment shows up in ZFSBootMenu as its own entry. Press Esc during
# the countdown to pick it. Any other boot still starts the unchanged system.

set -Eeuo pipefail

readonly SOURCE_DATASET="zssd/arch0/root"
# A sibling of the root keeps zfs-mount-local.sh mounting zssd/arch0/data/*.
readonly TEST_DATASET="zssd/arch0/root-plymouth"
readonly SNAPSHOT="${SOURCE_DATASET}@pre-plymouth-test"
readonly MAIN_SNAPSHOT="${SOURCE_DATASET}@pre-plymouth"
readonly MOUNT_POINT="/mnt/pavver-plymouth-test"
readonly THEME_DIR="usr/share/plymouth/themes/pavver"
readonly QUIET_SERVICE="pavver-quiet-shutdown.service"
readonly DRACUT_CONFIG="etc/dracut.conf.d/zfs.conf"
readonly INITRAMFS="boot/initramfs-linux.img"
# The cursor would otherwise blink on the console between a compositor and Plymouth.
readonly CONSOLE_ARGUMENTS="vt.global_cursor_default=0"
readonly SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

die() {
    echo "Error: $*" >&2
    exit 1
}

require_running_system() {
    [[ ${EUID} -eq 0 ]] || die "run this with sudo"
    [[ "$(findmnt -no SOURCE /)" == "${SOURCE_DATASET}" ]] \
        || die "/ must be ${SOURCE_DATASET}; boot the main system first"
}

dataset_exists() {
    zfs list -H -o name "$1" &>/dev/null
}

zfs_value() {
    zfs get -H -o value "$1" "$2"
}

unmount_test() {
    if mountpoint -q "${MOUNT_POINT}"; then
        umount -R "${MOUNT_POINT}"
    fi
    if [[ -d "${MOUNT_POINT}" ]]; then
        rmdir "${MOUNT_POINT}"
    fi
}

mount_test() {
    mkdir -p "${MOUNT_POINT}"
    mount -t zfs -o zfsutil "${TEST_DATASET}" "${MOUNT_POINT}"
    mount -t proc proc "${MOUNT_POINT}/proc"
    # rslave stops the later unmount from reaching the running system.
    mount --rbind /sys "${MOUNT_POINT}/sys"
    mount --make-rslave "${MOUNT_POINT}/sys"
    mount --rbind /dev "${MOUNT_POINT}/dev"
    mount --make-rslave "${MOUNT_POINT}/dev"
    mount -t tmpfs tmpfs "${MOUNT_POINT}/run"
}

in_test() {
    chroot "${MOUNT_POINT}" "$@"
}

list_initramfs() {
    lsinitrd "$1" | awk '{print $NF}' | sort -u
}

install_plymouth_files() {
    local root="$1"

    install -d -m 755 "${root}/${THEME_DIR}"
    install -m 644 \
        "${SOURCE_DIR}/pavver.plymouth" \
        "${SOURCE_DIR}/pavver.script" \
        "${SOURCE_DIR}"/frames/*.png \
        "${SOURCE_DIR}"/labels/*.png \
        "${root}/${THEME_DIR}/"
    install -m 644 "${SOURCE_DIR}/${QUIET_SERVICE}" "${root}/etc/systemd/system/"
}

verify_initramfs() {
    local image="$1"
    local entries required

    entries="$(list_initramfs "${image}")"
    for required in \
        'usr/bin/plymouthd$' \
        'usr/lib/plymouth/script.so$' \
        'usr/lib/plymouth/renderers/drm.so$' \
        "${THEME_DIR}/pavver.script\$" \
        "${THEME_DIR}/frame-99.png\$" \
        "${THEME_DIR}/label-boot.png\$" \
        '/zfs.ko' \
        '/nvidia-drm.ko' \
        '/nvidia.ko' \
        '/gpu_unlock.ko' \
        '/i915.ko' \
        'edid/1920x1080.bin$'; do
        grep -Eq "${required}" <<<"${entries}" \
            || die "${image} lacks ${required}; do not boot it"
    done
}

report_lost_entries() {
    local image="$1"

    echo "Entries missing from the test initramfs compared to the current one:"
    comm -23 <(list_initramfs "/${INITRAMFS}") <(list_initramfs "${image}") | sed 's/^/  /'
    echo "(end of list)"
}

create() {
    local kernel_version command_line root_prefix kernel

    require_running_system
    dataset_exists "${TEST_DATASET}" && die "${TEST_DATASET} already exists; run remove first"
    dataset_exists "${SNAPSHOT}" && die "${SNAPSHOT} already exists; run remove first"
    [[ -f "${SOURCE_DIR}/frames/frame-99.png" ]] || die "theme frames are missing"
    grep -Eq '^omit_dracutmodules.*\bplymouth\b' "/${DRACUT_CONFIG}" \
        || die "/${DRACUT_CONFIG} no longer omits plymouth; review this script first"

    kernel_version="$(uname -r)"
    command_line="$(zfs_value org.zfsbootmenu:commandline "${SOURCE_DATASET}")"
    root_prefix="$(zfs_value org.zfsbootmenu:rootprefix "${SOURCE_DATASET}")"
    kernel="$(zfs_value org.zfsbootmenu:kernel "${SOURCE_DATASET}")"
    [[ "${command_line}" != "-" && "${root_prefix}" != "-" && "${kernel}" != "-" ]] \
        || die "${SOURCE_DATASET} lacks ZFSBootMenu properties"

    # Downloaded first so the clone has it in its cache and needs no network.
    pacman -Sw --noconfirm --needed plymouth

    trap unmount_test EXIT

    zfs snapshot "${SNAPSHOT}"
    # ignore=on keeps the clone out of zfs-mount-generator on the main system.
    zfs clone \
        -o canmount=noauto \
        -o mountpoint=/ \
        -o org.openzfs.systemd:ignore=on \
        -o "org.zfsbootmenu:commandline=${command_line} splash ${CONSOLE_ARGUMENTS}" \
        -o "org.zfsbootmenu:rootprefix=${root_prefix}" \
        -o "org.zfsbootmenu:kernel=${kernel}" \
        "${SNAPSHOT}" "${TEST_DATASET}"

    mount_test

    in_test pacman -S --noconfirm --needed plymouth

    install_plymouth_files "${MOUNT_POINT}"
    in_test plymouth-set-default-theme pavver
    in_test systemctl enable "${QUIET_SERVICE}"

    sed -i -E '/^omit_dracutmodules/ s/[[:space:]]+plymouth\b//' "${MOUNT_POINT}/${DRACUT_CONFIG}"
    in_test dracut --force --no-hostonly-cmdline \
        "/${INITRAMFS}" --kver "${kernel_version}"

    verify_initramfs "${MOUNT_POINT}/${INITRAMFS}"
    report_lost_entries "${MOUNT_POINT}/${INITRAMFS}"
    unmount_test
    trap - EXIT

    cat <<DONE

Ready. The main system and the default boot entry are unchanged.
To test: reboot, press Esc during the ZFSBootMenu countdown, pick ${TEST_DATASET}.
If anything goes wrong, reset the machine: the default entry boots as before.
DONE
}

apply() {
    local kernel_version command_line

    require_running_system
    dataset_exists "${MAIN_SNAPSHOT}" && die "${MAIN_SNAPSHOT} already exists; apply ran before"
    [[ -f "${SOURCE_DIR}/frames/frame-99.png" ]] || die "theme frames are missing"
    grep -Eq '^omit_dracutmodules.*\bplymouth\b' "/${DRACUT_CONFIG}" \
        || die "/${DRACUT_CONFIG} no longer omits plymouth; review this script first"

    kernel_version="$(uname -r)"
    [[ -d "/usr/lib/modules/${kernel_version}" ]] \
        || die "modules for ${kernel_version} are missing; reboot into the installed kernel first"
    command_line="$(zfs_value org.zfsbootmenu:commandline "${SOURCE_DATASET}")"
    [[ "${command_line}" != "-" ]] || die "${SOURCE_DATASET} lacks ZFSBootMenu properties"
    [[ " ${command_line} " != *" splash "* ]] || die "the kernel command line already has splash"

    zfs snapshot "${MAIN_SNAPSHOT}"

    pacman -S --noconfirm --needed plymouth
    install_plymouth_files ""
    plymouth-set-default-theme pavver
    systemctl enable --now "${QUIET_SERVICE}"

    sed -i -E '/^omit_dracutmodules/ s/[[:space:]]+plymouth\b//' "/${DRACUT_CONFIG}"
    dracut --force --no-hostonly-cmdline "/${INITRAMFS}" --kver "${kernel_version}"
    verify_initramfs "/${INITRAMFS}"

    # Last, so a failure above leaves the boot entry without the splash.
    zfs set "org.zfsbootmenu:commandline=${command_line} splash ${CONSOLE_ARGUMENTS}" "${SOURCE_DATASET}"

    cat <<DONE

Done. Reboot normally. Keep ${TEST_DATASET} until the main system has booted.
If the main system fails to boot, press Esc in ZFSBootMenu, pick ${TEST_DATASET}, then run:
  sudo zfs rollback ${MAIN_SNAPSHOT}
  sudo zfs set 'org.zfsbootmenu:commandline=${command_line}' ${SOURCE_DATASET}
Once it boots fine, run: sudo $0 remove
DONE
}

remove() {
    require_running_system
    unmount_test
    if dataset_exists "${TEST_DATASET}"; then
        zfs destroy "${TEST_DATASET}"
    fi
    if dataset_exists "${SNAPSHOT}"; then
        zfs destroy "${SNAPSHOT}"
    fi
    echo "Removed ${TEST_DATASET} and its snapshot."
}

case "${1:-}" in
    create) create ;;
    remove) remove ;;
    apply) apply ;;
    *)
        echo "Usage: sudo $0 create|remove|apply" >&2
        exit 2
        ;;
esac
