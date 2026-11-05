#!/usr/bin/env python3
"""Crops rendered LoginLoader frames to the fixed box used by pavver.script."""

import sys
from pathlib import Path

from PIL import Image, ImageChops

SCREEN = (1920, 1080)
BOX = (690, 95, 1230, 985)  # Centred on the screen, so the script only centres it.
# The blur leaves a residue a few levels off the background across its whole
# layer. Plymouth also rounds opaque sprites one level down. Either would show
# as a faint rectangle on the flat boot screen, so the background is transparent.
BLUR_RESIDUE = 3


def main() -> int:
    source, target = Path(sys.argv[1]), Path(sys.argv[2])
    frames = sorted(source.glob("frame-*.png"))
    if len(frames) != 100:
        print(f"Expected 100 frames, found {len(frames)}", file=sys.stderr)
        return 1

    target.mkdir(parents=True, exist_ok=True)
    for index, path in enumerate(frames):
        image = Image.open(path).convert("RGB")
        if image.size != SCREEN:
            print(f"{path.name}: expected {SCREEN}, got {image.size}", file=sys.stderr)
            return 1

        background = Image.new("RGB", SCREEN, image.getpixel((0, 0)))
        red, green, blue = ImageChops.difference(image, background).split()
        difference = ImageChops.lighter(ImageChops.lighter(red, green), blue)
        visible = difference.point(lambda level: 255 if level > BLUR_RESIDUE else 0)
        image.putalpha(visible)

        left, top, right, bottom = visible.getbbox()
        if left < BOX[0] or top < BOX[1] or right > BOX[2] or bottom > BOX[3]:
            print(f"{path.name}: loader leaves the crop box", file=sys.stderr)
            return 1

        image.crop(BOX).save(target / f"frame-{index}.png", optimize=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
