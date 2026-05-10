#!/usr/bin/env python3
"""Quick helper to convert the generated hex file back into a PNG preview."""

from pathlib import Path

from PIL import Image


def hex_to_image(hex_path: Path, width: int, height: int, out_path: Path) -> None:
    data = [line.strip() for line in hex_path.read_text().splitlines() if line.strip()]
    if len(data) != width * height:
        raise ValueError(f"Pixel count mismatch: expected {width*height}, got {len(data)}")

    image = Image.new("RGB", (width, height))
    pixels = image.load()

    for idx, value in enumerate(data):
        r = int(value[0:2], 16)
        g = int(value[2:4], 16)
        b = int(value[4:6], 16)
        x = idx % width
        y = idx // width
        pixels[x, y] = (r, g, b)

    image.save(out_path)
    print(f"Saved preview -> {out_path}")


if __name__ == "__main__":
    hex_to_image(Path("rom/lcd_image.hex"), 150, 150, Path("rom/preview.png"))
