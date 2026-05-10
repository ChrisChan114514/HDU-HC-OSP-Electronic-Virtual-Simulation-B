#!/usr/bin/env python3
"""Convert an input image into an RGB hex file for ROM initialization.

Each output line contains one pixel encoded as RRGGBB (hex, uppercase),
scanned in row-major order from the top-left corner.
"""

from __future__ import annotations

import argparse
from pathlib import Path
from typing import Tuple

from PIL import Image, ImageEnhance


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path, help="Path to the source image (any Pillow-supported format)")
    parser.add_argument(
        "output",
        type=Path,
        nargs="?",
        default=Path("rom/lcd_image.hex"),
        help="Destination file for the generated hex data (default: rom/lcd_image.hex)",
    )
    parser.add_argument(
        "--size",
        type=str,
        default="150x150",
        metavar="WxH",
        help="Resize target resolution (default: 150x150)",
    )
    parser.add_argument(
        "--no-crop",
        action="store_true",
        help="Disable automatic center-cropping to a square before resizing",
    )
    parser.add_argument(
        "--coe",
        type=Path,
        default=None,
        help="Optional path to also dump a Xilinx-style .coe file for the same data",
    )
    parser.add_argument(
        "--mif",
        type=Path,
        default=Path("rom/lcd_image.mif"),
        help="Path to generate a Quartus-compatible .mif file (default: rom/lcd_image.mif)",
    )
    parser.add_argument(
        "--brightness",
        type=float,
        default=1.0,
        help="Apply brightness scaling before export (1.0 = unchanged)",
    )
    parser.add_argument(
        "--contrast",
        type=float,
        default=1.0,
        help="Apply contrast scaling before export (1.0 = unchanged)",
    )
    parser.add_argument(
        "--saturation",
        type=float,
        default=1.0,
        help="Apply color saturation scaling before export (1.0 = unchanged)",
    )
    parser.add_argument(
        "--gamma",
        type=float,
        default=1.0,
        help="Apply gamma correction (values < 1 brighten shadows, > 1 darken)",
    )
    parser.add_argument(
        "--invert",
        action="store_true",
        help="Invert RGB values after all adjustments to enhance contrast on bright displays",
    )
    parser.add_argument(
        "--bgr",
        action="store_true",
        help="Output in BGR format instead of RGB (for some LCD screens)",
    )
    return parser.parse_args()


def parse_size(size_str: str) -> Tuple[int, int]:
    try:
        width_str, height_str = size_str.lower().split("x")
        width = int(width_str)
        height = int(height_str)
    except ValueError as exc:
        raise argparse.ArgumentTypeError("--size must be in WxH format, e.g. 150x150") from exc
    if width <= 0 or height <= 0:
        raise argparse.ArgumentTypeError("Width and height must be positive integers")
    return width, height


def apply_gamma(image: Image.Image, gamma: float) -> Image.Image:
    if gamma == 1.0:
        return image

    inv_gamma = 1.0 / gamma
    lut = [int(((i / 255.0) ** inv_gamma) * 255.0 + 0.5) for i in range(256)]
    return image.point(lut * 3)


def prepare_image(
    src: Path,
    target_size: Tuple[int, int],
    crop_to_square: bool,
    brightness: float,
    contrast: float,
    saturation: float,
    gamma: float,
    invert: bool,
) -> Image.Image:
    image = Image.open(src)
    # 先转为RGBA，处理透明像素
    image = image.convert("RGBA")
    # 将透明像素填充为黑色
    new_image = Image.new("RGBA", image.size, (0,0,0,255))
    new_image.paste(image, (0,0), image)
    image = new_image.convert("RGB")

    if crop_to_square:
        min_side = min(image.width, image.height)
        left = (image.width - min_side) // 2
        top = (image.height - min_side) // 2
        right = left + min_side
        bottom = top + min_side
        image = image.crop((left, top, right, bottom))

    if image.size != target_size:
        image = image.resize(target_size, resample=Image.LANCZOS)

    if brightness != 1.0:
        image = ImageEnhance.Brightness(image).enhance(brightness)
    if contrast != 1.0:
        image = ImageEnhance.Contrast(image).enhance(contrast)
    if saturation != 1.0:
        image = ImageEnhance.Color(image).enhance(saturation)
    if gamma != 1.0:
        image = apply_gamma(image, gamma)

    if invert:
        image = Image.eval(image, lambda p: 255 - p)

    return image


def write_hex(image: Image.Image, dst: Path, bgr_mode: bool = False) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    with dst.open("w", encoding="ascii") as fp:
        width, height = image.size
        for y in range(height):
            for x in range(width):
                r, g, b = image.getpixel((x, y))
                if bgr_mode:
                    fp.write(f"{b:02X}{g:02X}{r:02X}\n")  # BGR顺序
                else:
                    fp.write(f"{r:02X}{g:02X}{b:02X}\n")  # RGB顺序


def write_coe(image: Image.Image, dst: Path, bgr_mode: bool = False) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    width, height = image.size
    pixel_values = []
    for y in range(height):
        for x in range(width):
            r, g, b = image.getpixel((x, y))
            if bgr_mode:
                pixel_values.append(f"{b:02X}{g:02X}{r:02X}")  # BGR顺序
            else:
                pixel_values.append(f"{r:02X}{g:02X}{b:02X}")  # RGB顺序

    with dst.open("w", encoding="ascii") as fp:
        fp.write("memory_initialization_radix=16;\n")
        fp.write("memory_initialization_vector=\n")
        fp.write(",\n".join(pixel_values))
        fp.write(";\n")


def write_mif(image: Image.Image, dst: Path, data_width: int = 24, bgr_mode: bool = False) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    width, height = image.size
    depth = width * height

    with dst.open("w", encoding="ascii") as fp:
        fp.write(f"WIDTH={data_width};\n")
        fp.write(f"DEPTH={depth};\n")
        fp.write("ADDRESS_RADIX=DEC;\n")
        fp.write("DATA_RADIX=HEX;\n\n")
        fp.write("CONTENT BEGIN\n")

        addr = 0
        for y in range(height):
            for x in range(width):
                r, g, b = image.getpixel((x, y))
                if bgr_mode:
                    fp.write(f"    {addr} : {b:02X}{g:02X}{r:02X};\n")  # BGR顺序
                else:
                    fp.write(f"    {addr} : {r:02X}{g:02X}{b:02X};\n")  # RGB顺序
                addr += 1

        fp.write("END;\n")


def main() -> None:
    args = parse_args()
    target_size = parse_size(args.size)
    image = prepare_image(
        args.input,
        target_size,
        crop_to_square=not args.no_crop,
        brightness=args.brightness,
        contrast=args.contrast,
        saturation=args.saturation,
        gamma=args.gamma,
        invert=args.invert,
    )

    write_hex(image, args.output, bgr_mode=args.bgr)
    if args.coe is not None:
        write_coe(image, args.coe, bgr_mode=args.bgr)
    if args.mif is not None:
        write_mif(image, args.mif, bgr_mode=args.bgr)

    width, height = image.size
    num_pixels = width * height
    print(f"Generated {num_pixels} pixels ({width}x{height}) -> {args.output}")
    if args.coe is not None:
        print(f"Also wrote COE file -> {args.coe}")
    if args.mif is not None:
        print(f"Also wrote MIF file -> {args.mif}")


if __name__ == "__main__":
    main()
