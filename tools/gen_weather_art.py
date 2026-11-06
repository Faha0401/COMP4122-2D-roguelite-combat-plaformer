#!/usr/bin/env python3
"""Weather particle textures for the backdrop system.

Tiny on purpose: the particles are drawn at screen scale, so a 3x14 streak is
enough for rain and keeps the whole effect readable at the game's pixel size.

    .venv/bin/python tools/gen_weather_art.py
"""
from pathlib import Path

from PIL import Image

OUT = Path(__file__).resolve().parent.parent / "Assets" / "FX" / "weather"


def rain():
    img = Image.new("RGBA", (3, 16), (0, 0, 0, 0))
    for y in range(16):
        fade = 90 + int(y * 8)
        for x in range(3):
            if x == 1 or (y % 4 == 0 and x != 1):
                img.putpixel((x, y), (176, 196, 210, min(255, fade)))
    return img


def snow():
    img = Image.new("RGBA", (5, 5), (0, 0, 0, 0))
    for x, y, a in [(2, 0, 140), (2, 4, 140), (0, 2, 140), (4, 2, 140)]:
        img.putpixel((x, y), (235, 240, 245, a))
    for x in range(1, 4):
        for y in range(1, 4):
            img.putpixel((x, y), (250, 252, 255, 190))
    return img


def leaf():
    img = Image.new("RGBA", (7, 5), (0, 0, 0, 0))
    body = (196, 118, 42, 235)
    edge = (140, 78, 28, 235)
    for x, y in [(1, 1), (2, 1), (3, 1), (4, 1), (0, 2), (1, 2), (2, 2),
                 (3, 2), (4, 2), (5, 2), (1, 3), (2, 3), (3, 3), (4, 3)]:
        img.putpixel((x, y), body)
    for x, y in [(0, 1), (5, 1), (0, 3), (5, 3), (2, 0), (3, 0), (2, 4), (3, 4)]:
        img.putpixel((x, y), edge)
    return img


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, image in {"rain_streak": rain(), "snowflake": snow(), "leaf": leaf()}.items():
        image.save(OUT / f"{name}.png")
        print(f"  {name:14s} {image.width}x{image.height}")
    print(f"wrote weather textures to {OUT}")


if __name__ == "__main__":
    main()
