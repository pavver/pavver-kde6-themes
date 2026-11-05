#!/usr/bin/env python3
"""Renders the captions of pavver.script, because the initramfs has no fonts."""

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

# File names follow Plymouth.GetMode(). Keep the size in step with LoginLoader.qml.
LABELS = {
    "boot": "Завантаження",
    "shutdown": "Вимкнення",
    "reboot": "Перезавантаження",
}
PIXEL_SIZE = 30
COLOR = (255, 255, 255, 255)


def main() -> int:
    font_path, target = sys.argv[1], Path(sys.argv[2])
    font = ImageFont.truetype(font_path, PIXEL_SIZE)
    font.set_variation_by_name("Regular")
    ascent, descent = font.getmetrics()

    target.mkdir(parents=True, exist_ok=True)
    for mode, text in LABELS.items():
        size = (round(font.getlength(text)), ascent + descent)
        image = Image.new("RGBA", size, COLOR[:3] + (0,))
        ImageDraw.Draw(image).text((0, 0), text, font=font, fill=COLOR)
        image.save(target / f"label-{mode}.png", optimize=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
