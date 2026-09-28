#!/usr/bin/env python3

import argparse
import configparser
import hashlib
import json
import os
import stat
import struct
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


def fail(message: str) -> None:
    raise ValueError(message)


def read_version(root: Path) -> str:
    version = (root / "VERSION").read_text(encoding="ascii").strip()
    if not version or any(char.isspace() for char in version):
        fail("VERSION must contain one non-empty token")
    return version


def load_json(path: Path) -> dict:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        fail(f"Invalid JSON in {path}: {error}")


def png_size(path: Path) -> tuple[int, int]:
    data = path.read_bytes()[:24]
    if len(data) != 24 or data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
        fail(f"{path} is not a valid PNG")
    return struct.unpack(">II", data[16:24])


def tree_hashes(path: Path) -> dict[str, str]:
    result: dict[str, str] = {}
    for file_path in sorted(item for item in path.rglob("*") if item.is_file()):
        relative = file_path.relative_to(path).as_posix()
        result[relative] = hashlib.sha256(file_path.read_bytes()).hexdigest()
    return result


def check_permissions(dist: Path) -> None:
    for current_root, directories, files in os.walk(dist, followlinks=False):
        root_path = Path(current_root)
        for name in directories + files:
            path = root_path / name
            if path.is_symlink():
                fail(f"Release artifact contains a symlink: {path}")
            mode = stat.S_IMODE(path.stat().st_mode)
            expected = 0o755 if path.is_dir() else 0o644
            if mode != expected:
                fail(f"Unexpected permissions on {path}: {mode:o}, expected {expected:o}")


def require_files(base: Path, paths: list[str]) -> None:
    for relative in paths:
        path = base / relative
        if not path.is_file():
            fail(f"Missing release file: {path}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--dist", type=Path, required=True)
    args = parser.parse_args()

    root = args.root.resolve()
    dist = args.dist.resolve()
    version = read_version(root)

    sddm = dist / "themes/sddm/pavver-sddm-theme"
    lockscreen = dist / "themes/lockscreen/pavver-plasma-lockscreen"
    wallpaper = dist / "themes/wallpaper/pavver-wallpaper"

    require_files(sddm, [
        "Main.qml", "SddmBackend.qml", "metadata.desktop", "theme.conf",
        "preview.png", "LICENSE", "PavverTheme/qmldir",
    ])
    require_files(lockscreen, [
        "metadata.json", "preview.png", "preview_unlock.png",
        "preview_screensaver.png", "preview_capslock.png", "LICENSE",
        "contents/lockscreen/LockScreen.qml",
        "contents/lockscreen/LockScreenUi.qml",
        "contents/lockscreen/LockScreenBackend.qml",
        "contents/lockscreen/PavverTheme/qmldir",
    ])
    require_files(wallpaper, [
        "metadata.json", "preview.png", "LICENSE",
        "contents/ui/main.qml", "contents/ui/config.qml",
        "contents/config/main.xml", "contents/ui/PavverTheme/qmldir",
    ])

    lock_metadata = load_json(lockscreen / "metadata.json")
    if lock_metadata.get("KPackageStructure") != "Plasma/Shell":
        fail("Lock screen must use KPackageStructure Plasma/Shell")
    lock_plugin = lock_metadata.get("KPlugin", {})
    if lock_plugin.get("Id") != "pavver-plasma-lockscreen":
        fail("Unexpected lock screen plugin Id")
    if lock_plugin.get("Version") != version:
        fail("Lock screen metadata version does not match VERSION")

    wallpaper_metadata = load_json(wallpaper / "metadata.json")
    if wallpaper_metadata.get("KPackageStructure") != "Plasma/Wallpaper":
        fail("Wallpaper must use KPackageStructure Plasma/Wallpaper")
    wallpaper_plugin = wallpaper_metadata.get("KPlugin", {})
    if wallpaper_plugin.get("Id") != "pavver-wallpaper":
        fail("Unexpected wallpaper plugin Id")
    if wallpaper_plugin.get("Version") != version:
        fail("Wallpaper metadata version does not match VERSION")
    if wallpaper_metadata.get("X-Plasma-API-Minimum-Version") != "6.0":
        fail("Wallpaper must declare Plasma 6 as its minimum API")

    desktop = configparser.ConfigParser(interpolation=None)
    desktop.optionxform = str
    desktop.read(sddm / "metadata.desktop", encoding="utf-8")
    if not desktop.has_section("SddmGreeterTheme"):
        fail("SDDM metadata is missing [SddmGreeterTheme]")
    sddm_metadata = desktop["SddmGreeterTheme"]
    expected_sddm = {
        "MainScript": "Main.qml",
        "ConfigFile": "theme.conf",
        "Screenshot": "preview.png",
        "Theme-Id": "pavver-sddm-theme",
        "Theme-API": "2.0",
        "QtVersion": "6",
        "Version": version,
    }
    for key, expected in expected_sddm.items():
        if sddm_metadata.get(key) != expected:
            fail(f"Unexpected SDDM metadata value for {key}")

    ET.parse(wallpaper / "contents/config/main.xml")

    source_hashes = tree_hashes(root / "shared/PavverTheme")
    shared_targets = [
        sddm / "PavverTheme",
        lockscreen / "contents/lockscreen/PavverTheme",
        wallpaper / "contents/ui/PavverTheme",
    ]
    for target in shared_targets:
        if tree_hashes(target) != source_hashes:
            fail(f"Packaged shared module differs from source: {target}")

    for preview in [
        sddm / "preview.png",
        lockscreen / "preview.png",
        lockscreen / "preview_unlock.png",
        lockscreen / "preview_screensaver.png",
        lockscreen / "preview_capslock.png",
        wallpaper / "preview.png",
    ]:
        width, height = png_size(preview)
        if width < 640 or height < 360:
            fail(f"Preview is too small for KDE UI: {preview} ({width}x{height})")

    if (wallpaper / "preview.png").read_bytes() != (
        root / "lockscreen/preview_screensaver.png"
    ).read_bytes():
        fail("Wallpaper preview is not the canonical screensaver preview")

    check_permissions(dist)
    print(f"Static package validation passed for {version}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, ET.ParseError) as error:
        print(f"validation error: {error}", file=sys.stderr)
        raise SystemExit(1)
