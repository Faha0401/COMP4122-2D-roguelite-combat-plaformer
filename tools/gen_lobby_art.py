#!/usr/bin/env python3
"""Generate the lobby's wasteland pixel art.

Everything is drawn at 1x world pixels (the camera zooms the world 2x) with a
fixed palette, then a contact sheet is written at 4x so the result can be
inspected without opening Godot.

    .venv/bin/python tools/gen_lobby_art.py

Outputs to Assets/Lobby/ and a 4x preview at Assets/Lobby/_preview/contact_sheet.png.
"""
from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent.parent / "Assets" / "Lobby"

# Wasteland palette, shared with UI/theme: ash, rust, bone, one warm lamp.
VOID = (11, 7, 8, 255)
SOIL = (28, 21, 18, 255)
SOIL_LIGHT = (38, 29, 24, 255)
WOOD_DARK = (42, 29, 22, 255)
WOOD = (59, 42, 30, 255)
WOOD_LIGHT = (87, 64, 44, 255)
RUST = (107, 59, 34, 255)
BONE = (217, 210, 198, 255)
ASH = (156, 147, 138, 255)
CRIMSON = (176, 42, 49, 255)
LAMP = (232, 184, 75, 255)
LAMP_DIM = (150, 108, 44, 255)
GLOW = (232, 184, 75, 60)

HOUSE_SHEET = Path(__file__).resolve().parent.parent / "Assets" / "Scene" / "Backgrounds" / "House Tiles.png"

FONT_3X5 = {
    "S": ["111", "100", "111", "001", "111"],
    "H": ["101", "101", "111", "101", "101"],
    "O": ["111", "101", "101", "101", "111"],
    "P": ["111", "101", "111", "100", "100"],
    "A": ["111", "101", "111", "101", "101"],
    "R": ["111", "101", "110", "101", "101"],
    "D": ["110", "101", "101", "101", "110"],
    "E": ["111", "100", "111", "100", "111"],
    "T": ["111", "010", "010", "010", "010"],
    "L": ["100", "100", "100", "100", "111"],
    "M": ["101", "111", "111", "101", "101"],
    "N": ["101", "111", "111", "111", "101"],
    "I": ["111", "010", "010", "010", "111"],
    "G": ["111", "100", "101", "101", "111"],
}


def new(width, height):
    return Image.new("RGBA", (width, height), (0, 0, 0, 0))


def text(draw, x, y, string, color, spacing=1):
    cursor = x
    for char in string:
        glyph = FONT_3X5.get(char)
        if glyph is None:
            cursor += 4
            continue
        for row, bits in enumerate(glyph):
            for col, bit in enumerate(bits):
                if bit == "1":
                    draw.point((cursor + col, y + row), fill=color)
        cursor += 3 + spacing


def text_scaled(draw, x, y, string, color, scale=3, spacing=1):
    """Draw the 3x5 font with each pixel blown up, for signage."""
    cursor = x
    for char in string:
        glyph = FONT_3X5.get(char)
        if glyph is None:
            cursor += 4 * scale
            continue
        for row, bits in enumerate(glyph):
            for col, bit in enumerate(bits):
                if bit == "1":
                    px, py = cursor + col * scale, y + row * scale
                    draw.rectangle([px, py, px + scale - 1, py + scale - 1], fill=color)
        cursor += (3 + spacing) * scale


def speckle(draw, box, color, step=3, offset=0):
    x0, y0, x1, y1 = box
    for y in range(y0 + offset, y1, step):
        for x in range(x0 + offset, x1, step):
            if (x * 7 + y * 13) % 5 == 0:
                draw.point((x, y), fill=color)


# ---------------------------------------------------------------------------
# Shop: a patched wooden shack with a hanging sign and a lit doorway
# ---------------------------------------------------------------------------

def shop_house():
    w, h = 132, 116
    img = new(w, h)
    d = ImageDraw.Draw(img)

    # Roof: a shingled triangle, edges chipped by the wind.
    apex = (w // 2, 2)
    left = (1, 40)
    right = (w - 2, 40)
    d.polygon([left, apex, right], fill=WOOD_DARK)
    for y in range(8, 40, 8):
        half = int((y - 2) / 38.0 * (w // 2))
        d.line([w // 2 - half, y, w // 2 + half, y], fill=WOOD)
        for x in range(w // 2 - half + 3, w // 2 + half, 8):
            d.line([x, y + 1, x, y + 6], fill=WOOD_DARK)
    d.line([left, apex], fill=WOOD_LIGHT)
    d.line([apex, right], fill=WOOD_LIGHT)
    # A hole in the roof: the wasteland gets in.
    d.rectangle([w - 38, 22, w - 26, 30], fill=VOID)

    # Body: horizontal planks with visible seams and patches.
    roof_bottom = 42
    body_top = roof_bottom
    d.rectangle([6, body_top, w - 7, h - 1], fill=WOOD)
    for y in range(body_top, h, 9):
        d.line([6, y, w - 7, y], fill=WOOD_DARK)
    d.rectangle([10, body_top + 6, 34, body_top + 22], fill=WOOD_LIGHT)
    d.rectangle([10, body_top + 6, 34, body_top + 22], outline=WOOD_DARK)
    d.rectangle([w - 42, body_top + 40, w - 16, body_top + 58], fill=WOOD_LIGHT)
    d.rectangle([w - 42, body_top + 40, w - 16, body_top + 58], outline=WOOD_DARK)
    speckle(d, (7, body_top, w - 8, h - 1), WOOD_DARK, 4, 1)

    # Doorway: a lit opening, so the old man is readable against the dark.
    door_x0, door_x1 = w // 2 - 17, w // 2 + 17
    door_top = h - 52
    d.rectangle([door_x0 - 2, door_top - 2, door_x1 + 2, h - 1], fill=WOOD_DARK)
    d.rectangle([door_x0, door_top, door_x1, h - 1], fill=(24, 16, 12, 255))
    # Warm light from a lamp inside, falling down the back wall.
    for y in range(door_top, h):
        t = (y - door_top) / max(1, (h - door_top))
        d.line([door_x0 + 1, y, door_x1 - 1, y],
               fill=(int(58 + 46 * t), int(38 + 30 * t), int(20 + 14 * t), 255))
    d.rectangle([door_x0 + 2, door_top + 2, door_x1 - 2, door_top + 4], fill=(126, 84, 40, 255))
    d.rectangle([door_x0, door_top, door_x0 + 1, h - 1], fill=WOOD_LIGHT)
    d.rectangle([door_x1 - 1, door_top, door_x1, h - 1], fill=WOOD_DARK)
    d.rectangle([door_x0 - 1, door_top - 1, door_x1 + 1, door_top], fill=WOOD_LIGHT)
    # Step.
    d.rectangle([door_x0 - 8, h - 8, door_x1 + 8, h - 1], fill=WOOD_LIGHT)
    d.line([door_x0 - 8, h - 8, door_x1 + 8, h - 8], fill=WOOD_DARK)

    # Hanging sign above the door, chained to the beam.
    sign_w, sign_h = 62, 20
    sx = w // 2 - sign_w // 2
    sy = roof_bottom - 4
    d.line([sx + 10, roof_bottom - 8, sx + 10, sy], fill=ASH)
    d.line([sx + sign_w - 10, roof_bottom - 8, sx + sign_w - 10, sy], fill=ASH)
    d.rectangle([sx, sy, sx + sign_w, sy + sign_h], fill=WOOD_LIGHT)
    d.rectangle([sx, sy, sx + sign_w, sy + sign_h], outline=WOOD_DARK)
    d.rectangle([sx + 1, sy + 1, sx + sign_w - 1, sy + 3], fill=WOOD)
    d.rectangle([sx + 1, sy + sign_h - 2, sx + sign_w - 1, sy + sign_h - 1], fill=WOOD_DARK)
    text(d, sx + 8, sy + 7, "SHOP", SOIL, spacing=2)

    # A lamp beside the door, the only warm thing in the frame.
    lx, ly = door_x1 + 8, door_top - 6
    d.rectangle([lx, ly, lx + 1, ly + 10], fill=WOOD_DARK)
    d.rectangle([lx - 3, ly + 10, lx + 4, ly + 16], fill=LAMP)
    d.rectangle([lx - 3, ly + 10, lx + 4, ly + 16], outline=WOOD_DARK)
    d.rectangle([lx - 1, ly + 12, lx, ly + 14], fill=(255, 240, 200, 255))

    # Ground shadow so the hut sits on the floor instead of floating.
    d.rectangle([2, h - 4, w - 3, h - 1], fill=(0, 0, 0, 70))
    return img


def old_man():
    """The shopkeeper as a bust, in the reference's style: red hat, long beard,
    teal robe. Drawn waist-up because the counter hides everything below it."""
    w, h = 28, 32
    img = new(w, h)
    d = ImageDraw.Draw(img)

    skin = (196, 156, 124, 255)
    skin_shade = (160, 122, 94, 255)
    beard = (206, 202, 194, 255)
    beard_shade = (166, 162, 154, 255)
    hat = (128, 56, 52, 255)
    hat_dark = (94, 38, 36, 255)
    robe = (52, 90, 96, 255)
    robe_light = (74, 120, 124, 255)

    # Shoulders and robe.
    d.polygon([(2, h - 1), (4, 22), (10, 18), (18, 18), (24, 22), (26, h - 1)], fill=robe)
    d.polygon([(2, h - 1), (4, 22), (8, 20), (8, h - 1)], fill=robe_light)
    d.line([(4, 24), (24, 24)], fill=hat_dark)          # collar seam
    d.rectangle([12, 20, 16, 24], fill=skin_shade)      # neck in shadow

    # Beard: full at the chin, tapering, with a moustache line.
    d.polygon([(8, 16), (20, 16), (18, 26), (14, 30), (10, 26)], fill=beard)
    d.line([(10, 16), (18, 16)], fill=beard_shade)
    d.line([(11, 20), (12, 26)], fill=beard_shade)
    d.line([(17, 20), (16, 26)], fill=beard_shade)
    d.line([(14, 18), (14, 28)], fill=beard_shade)

    # Face: forehead, eyes, nose, cheeks lit from the lantern side.
    d.rectangle([9, 8, 19, 16], fill=skin)
    d.rectangle([9, 8, 19, 9], fill=skin_shade)          # brow line
    d.rectangle([11, 11, 12, 12], fill=(38, 30, 26, 255))  # eyes
    d.rectangle([16, 11, 17, 12], fill=(38, 30, 26, 255))
    d.rectangle([14, 12, 15, 14], fill=skin_shade)       # nose
    d.line([(9, 10), (9, 16)], fill=skin_shade)          # cheeks
    d.line([(19, 10), (19, 16)], fill=skin_shade)
    d.point((13, 10), fill=(216, 178, 146, 255))         # lit brow

    # Hat: wide brim, banded crown.
    d.rectangle([3, 6, 24, 8], fill=hat_dark)
    d.rectangle([4, 6, 23, 7], fill=hat)
    d.polygon([(8, 1), (19, 1), (21, 6), (6, 6)], fill=hat)
    d.polygon([(8, 1), (13, 1), (12, 6), (6, 6)], fill=(150, 70, 62, 255))
    d.rectangle([8, 4, 20, 5], fill=hat_dark)           # band
    d.point((18, 2), fill=(196, 150, 96, 255))          # buckle catch

    return img


def arrow_sign():
    w, h = 44, 34
    img = new(w, h)
    d = ImageDraw.Draw(img)
    # Post.
    d.rectangle([18, 14, 21, h - 1], fill=WOOD)
    d.line([18, 14, 18, h - 1], fill=WOOD_LIGHT)
    d.rectangle([14, h - 5, 25, h - 1], fill=WOOD_DARK)
    # Board with a pointed end, weathered edges.
    d.polygon([(2, 3), (34, 3), (w - 2, 9), (34, 15), (2, 15)], fill=WOOD_LIGHT)
    d.polygon([(2, 3), (34, 3), (w - 2, 9), (34, 15), (2, 15)], outline=WOOD_DARK)
    d.line([(3, 4), (33, 4)], fill=(120, 92, 62, 255))
    # Chevron.
    d.line([(12, 6), (19, 9)], fill=CRIMSON)
    d.line([(19, 9), (12, 12)], fill=CRIMSON)
    d.line([(13, 6), (20, 9)], fill=BONE)
    d.line([(20, 9), (13, 12)], fill=BONE)
    return img


def dead_tree():
    w, h = 52, 78
    img = new(w, h)
    d = ImageDraw.Draw(img)
    trunk = [(24, h - 1), (27, h - 1), (27, 46), (25, 40), (24, 46)]
    d.polygon(trunk, fill=WOOD_DARK)
    branches = [
        [(26, 46), (12, 30)],
        [(26, 44), (40, 26)],
        [(25, 36), (18, 22)],
        [(26, 32), (34, 18)],
        [(25, 28), (22, 12)],
    ]
    for (x0, y0), (x1, y1) in branches:
        d.line([(x0, y0), (x1, y1)], fill=WOOD_DARK, width=2)
        d.line([(x1, y1), (x1 + 3, y1 - 5)], fill=WOOD_DARK)
        d.line([(x1, y1), (x1 - 4, y1 - 4)], fill=WOOD_DARK)
    d.rectangle([15, h - 3, 36, h - 1], fill=(0, 0, 0, 60))
    return img


def rocks():
    w, h = 46, 20
    img = new(w, h)
    d = ImageDraw.Draw(img)
    d.polygon([(2, 19), (8, 8), (18, 4), (30, 7), (42, 18)], fill=(52, 46, 42, 255))
    d.polygon([(8, 8), (18, 4), (22, 10), (12, 14)], fill=(74, 66, 60, 255))
    d.polygon([(30, 7), (42, 18), (30, 18)], fill=(38, 33, 30, 255))
    d.line([(2, 19), (43, 19)], fill=(0, 0, 0, 70))
    return img


def lamp_post():
    w, h = 16, 74
    img = new(w, h)
    d = ImageDraw.Draw(img)
    d.rectangle([7, 12, 9, h - 1], fill=WOOD_DARK)
    d.line([7, 12, 7, h - 1], fill=(70, 54, 40, 255))
    d.rectangle([5, h - 5, 11, h - 1], fill=WOOD)
    # Arm and lamp.
    d.line([(8, 12), (12, 8)], fill=WOOD_DARK)
    d.rectangle([10, 6, 15, 12], fill=WOOD_DARK)
    d.rectangle([11, 12, 14, 17], fill=LAMP)
    d.rectangle([11, 12, 14, 17], outline=WOOD_DARK)
    d.point((12, 14), fill=(255, 246, 214, 255))
    return img



def shop_sign():
    """A hanging plank sign, sized to hang over the merchant tent's entrance."""
    w, h = 58, 18
    img = new(w, h)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, w - 1, h - 1], fill=WOOD_LIGHT)
    d.rectangle([0, 0, w - 1, h - 1], outline=WOOD_DARK)
    d.rectangle([1, 1, w - 2, 3], fill=WOOD)
    d.rectangle([1, h - 2, w - 2, h - 1], fill=WOOD_DARK)
    text(d, 7, 6, "SHOP", SOIL, spacing=2)
    # Chains, drawn beyond the board so they read against the tent.
    d.line([(10, -8), (10, 0)], fill=ASH)
    d.line([(w - 11, -8), (w - 11, 0)], fill=ASH)
    return img


def logs():
    """A small stack of firewood, the pack's camping staple."""
    w, h = 40, 26
    img = new(w, h)
    d = ImageDraw.Draw(img)
    for row, (count, y) in enumerate([(3, 16), (2, 8)]):
        for i in range(count):
            x = 4 + i * 12 + row * 4
            d.rectangle([x, y, x + 13, y + 9], fill=WOOD)
            d.rectangle([x, y, x + 13, y + 9], outline=WOOD_DARK)
            d.ellipse([x + 9, y + 2, x + 13, y + 7], fill=WOOD_LIGHT)
    d.rectangle([0, 24, w - 1, h - 1], fill=(0, 0, 0, 60))
    return img


def shop_building():
    """The pack's own timber-and-stone house, cropped off its sheet.

    The sheet draws the house as a cutaway with an open front, which is exactly
    what a shop needs: the counter and the merchant live inside the opening.
    """
    sheet = Image.open(HOUSE_SHEET).convert("RGBA")
    house = sheet.crop((224, 0, 448, 224))
    return house.crop(house.getbbox())


def counter():
    """A plank counter to stand inside the shop's opening."""
    w, h = 64, 26
    img = new(w, h)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 2, w - 1, 9], fill=WOOD_LIGHT)
    d.rectangle([0, 2, w - 1, 9], outline=WOOD_DARK)
    d.line([1, 4, w - 2, 4], fill=(126, 96, 64, 255))
    d.rectangle([3, 10, w - 4, 16], fill=WOOD)
    for x in range(6, w - 6, 9):
        d.line([x, 10, x, 16], fill=WOOD_DARK)
    d.rectangle([3, 16, 6, h - 1], fill=WOOD_DARK)
    d.rectangle([w - 7, 16, w - 4, h - 1], fill=WOOD_DARK)
    return img


def shop_stall():
    """A weathered wooden store: leaning posts, patched roof, torn awning.

    Drawn from the reference: sign across the roof, cloth awning over the
    counter, a lantern on each post, crates and a barrel at the base. Every
    "broken" detail is deliberate — missing shingles, a chipped sign corner,
    a cracked post, a torn awning patch.
    """
    w, h = 200, 190
    img = new(w, h)
    d = ImageDraw.Draw(img)

    roof_dark, roof, roof_light = (46, 27, 30, 255), (74, 42, 44, 255), (107, 58, 54, 255)
    cloth, cloth_dark = (185, 169, 138, 255), (142, 127, 99, 255)
    inner = (20, 16, 13, 255)

    # --- roof: wide gable, shingled, chipped -------------------------------
    d.polygon([(2, 66), (26, 16), (174, 16), (198, 66)], fill=roof_dark)
    for row_y in range(18, 66, 7):
        half = int((row_y - 16) / 50.0 * 86) + 22
        left, right = 100 - half, 100 + half
        for x in range(left, right, 11):
            tone = roof if (x * 7 + row_y * 13) % 3 else roof_light
            d.rectangle([x + 1, row_y, min(x + 10, right), row_y + 6], fill=tone)
            d.line([x, row_y, x, row_y + 6], fill=roof_dark)
        d.line([left, row_y + 6, right, row_y + 6], fill=roof_dark)
    # Missing shingles and a patched plank.
    for hx, hy in [(58, 25), (86, 32), (132, 46)]:
        d.rectangle([hx, hy, hx + 10, hy + 6], fill=inner)
    d.rectangle([110, 39, 132, 45], fill=WOOD_LIGHT)
    d.rectangle([110, 39, 132, 45], outline=WOOD_DARK)

    for x in range(58, 148, 11):
        tone = roof_light if (x * 5) % 3 == 0 else roof
        d.rectangle([x + 1, 17, x + 10, 21], fill=tone)

    # --- sign: carved board, chipped corner -------------------------------
    d.rectangle([46, 22, 154, 58], fill=WOOD_LIGHT)
    d.rectangle([46, 22, 154, 58], outline=WOOD_DARK)
    d.line([47, 24, 153, 24], fill=(120, 92, 62, 255))
    d.polygon([(46, 58), (56, 48), (56, 58)], fill=inner)   # chipped corner
    for lx in (40, 160):                                     # rope to the roof
        d.line([lx, 20, lx, 30], fill=ASH)
    text_scaled(d, 56, 32, "SHOP", SOIL, scale=4, spacing=1)
    # Nail heads, skipped where the letters bite into the board.
    for dx in (52, 148):
        d.point((dx, 26), fill=(120, 92, 62, 255))

    # --- posts: one straight, one leaning ---------------------------------
    d.rectangle([10, 58, 26, 190], fill=WOOD)
    d.line([10, 58, 10, 190], fill=WOOD_LIGHT)
    d.line([26, 58, 26, 190], fill=WOOD_DARK)
    d.polygon([(174, 58), (190, 58), (194, 190), (178, 190)], fill=WOOD)
    d.line([174, 58, 178, 190], fill=WOOD_LIGHT)
    for y in range(72, 186, 26):                 # grain + cracks
        d.line([12, y, 24, y + 2], fill=WOOD_DARK)
        d.line([176, y, 192, y + 3], fill=WOOD_DARK)
    d.line([18, 120, 22, 140], fill=WOOD_DARK)

    # --- beam under the roof ----------------------------------------------
    d.rectangle([8, 64, 194, 74], fill=WOOD_LIGHT)
    d.line([8, 64, 194, 64], fill=(126, 96, 64, 255))
    d.line([8, 74, 194, 74], fill=WOOD_DARK)

    # --- interior: shelves with stock -------------------------------------
    d.rectangle([26, 74, 174, 160], fill=inner)
    for shelf_y in (104, 128):
        d.rectangle([30, shelf_y, 170, shelf_y + 3], fill=WOOD_DARK)
        for i in range(6):
            bx = 36 + i * 22 + (i % 2) * 3
            jar = [(58, 42, 34), (74, 88, 52), (110, 70, 40)][i % 3]
            d.rectangle([bx, shelf_y - 9, bx + 6, shelf_y - 1], fill=jar + (255,))
            d.rectangle([bx, shelf_y - 10, bx + 6, shelf_y - 9], fill=WOOD_DARK)
    # Hanging herbs from the beam.
    for hx in range(40, 160, 24):
        d.line([hx, 74, hx, 86], fill=(70, 92, 52, 255))
        d.rectangle([hx - 2, 86, hx + 2, 92], fill=(84, 108, 58, 255))

    # --- awning: torn cloth over the counter ------------------------------
    d.polygon([(22, 76), (178, 76), (170, 104), (30, 104)], fill=cloth)
    d.polygon([(22, 76), (178, 76), (170, 104), (30, 104)], outline=cloth_dark)
    for x in range(34, 168, 16):
        d.line([x, 78, x - 2, 102], fill=cloth_dark)
    for x in range(30, 170, 8):                  # scalloped hem
        d.line([x, 104, x + 4, 100], fill=cloth_dark)
    d.polygon([(96, 80), (116, 80), (108, 98)], fill=cloth_dark)   # patch
    d.polygon([(96, 80), (116, 80), (108, 98)], outline=WOOD_DARK)

    # --- counter ----------------------------------------------------------
    d.rectangle([28, 150, 172, 176], fill=WOOD_LIGHT)
    d.rectangle([28, 150, 172, 150], fill=(126, 96, 64, 255))
    d.rectangle([28, 176, 172, 190], fill=WOOD)
    for x in range(34, 170, 18):
        d.line([x, 154, x, 174], fill=WOOD_DARK)
    d.line([28, 162, 172, 162], fill=WOOD_DARK)
    # Goods on the counter.
    d.rectangle([52, 142, 70, 150], fill=(150, 96, 52, 255))
    d.ellipse([78, 138, 92, 150], fill=(176, 122, 62, 255))
    d.rectangle([120, 144, 134, 150], fill=(96, 74, 58, 255))

    # --- lanterns on both posts ------------------------------------------
    for lx in (13, 177):
        d.rectangle([lx, 86, lx + 12, 88], fill=ASH)
        d.rectangle([lx + 2, 88, lx + 10, 102], fill=LAMP_DIM)
        d.rectangle([lx + 3, 90, lx + 9, 100], fill=LAMP)
        d.rectangle([lx + 5, 92, lx + 7, 98], fill=(255, 244, 208, 255))
        d.line([lx + 6, 102, lx + 6, 106], fill=ASH)

    # --- crates and barrel ------------------------------------------------
    d.rectangle([176, 160, 196, 182], fill=WOOD_LIGHT)
    d.rectangle([176, 160, 196, 182], outline=WOOD_DARK)
    d.line([176, 171, 196, 171], fill=WOOD_DARK)
    d.rectangle([180, 148, 196, 160], fill=WOOD)
    d.rectangle([180, 148, 196, 160], outline=WOOD_DARK)
    d.rectangle([2, 162, 22, 186], fill=WOOD)
    d.rectangle([2, 162, 22, 186], outline=WOOD_DARK)
    for y in (168, 176, 183):
        d.line([3, y, 21, y], fill=WOOD_DARK)

    # --- fallen leaves ----------------------------------------------------
    for lx, ly in [(34, 60), (92, 20), (150, 30), (64, 78), (140, 62)]:
        d.point((lx, ly), fill=(196, 118, 42, 255))
        d.point((lx + 1, ly + 1), fill=(140, 78, 28, 255))

    d.rectangle([2, 186, 198, 190], fill=(0, 0, 0, 70))
    return img

def ground_tile():
    w, h = 32, 24
    img = Image.new("RGBA", (w, h), SOIL)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, w - 1, 5], fill=SOIL_LIGHT)
    for x in range(0, w, 6):
        d.line([x, 0, x, 4], fill=(30, 23, 19, 255))
    speckle(d, (0, 6, w, h), (22, 17, 14, 255), 4, 2)
    for x, y in [(3, 9), (17, 14), (25, 20), (9, 18)]:
        d.point((x, y), fill=(60, 50, 42, 255))
    return img


def glow_haze():
    """Soft lamp haze, drawn as dithered alpha so it stays pixel-y."""
    w, h = 96, 96
    img = new(w, h)
    d = ImageDraw.Draw(img)
    cx, cy = w / 2, h / 2
    for y in range(h):
        for x in range(w):
            dist = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
            if dist > 46:
                continue
            alpha = int(max(0, (1 - dist / 46) ** 2) * 70)
            if (x + y) % 2 == 0:  # dither keeps it from looking airbrushed
                d.point((x, y), fill=(232, 184, 75, alpha))
    return img


def soft_glow():
    """Warm additive light, used as a 2D light stand-in."""
    size = 128
    img = new(size, size)
    d = ImageDraw.Draw(img)
    c = size / 2
    for y in range(size):
        for x in range(size):
            dist = ((x - c) ** 2 + (y - c) ** 2) ** 0.5
            if dist > c:
                continue
            falloff = (1 - dist / c) ** 2
            d.point((x, y), fill=(255, 208, 130, int(falloff * 150)))
    return img


def vignette():
    """Screen overlay: dark corners, clear middle. Draws the eye inward."""
    w, h = 288, 162
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy = w / 2, h / 2
    for y in range(h):
        for x in range(w):
            dx = abs(x - cx) / cx
            dy = abs(y - cy) / cy
            v = max(dx ** 2.2, dy ** 2.2)
            alpha = int(min(1.0, max(0.0, (v - 0.35) / 0.65)) * 165)
            if alpha > 0:
                d.point((x, y), fill=(6, 5, 4, alpha))
    return img


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    pieces = {
        "shop_house": shop_house(),
        "shop_building": shop_building(),
        "shop_stall": shop_stall(),
        "counter": counter(),
        "shop_sign": shop_sign(),
        "logs": logs(),
        "soft_glow": soft_glow(),
        "vignette": vignette(),
        "old_man": old_man(),
        "arrow_sign": arrow_sign(),
        "dead_tree": dead_tree(),
        "rocks": rocks(),
        "lamp_post": lamp_post(),
        "ground_tile": ground_tile(),
        "lamp_glow": glow_haze(),
    }
    for name, image in pieces.items():
        image.save(OUT / f"{name}.png")

    # Contact sheet at 4x so the pixels are legible without Godot.
    scale = 4
    pad = 12
    width = sum(i.width * scale + pad for i in pieces.values()) + pad
    height = max(i.height for i in pieces.values()) * scale + pad * 2
    sheet = Image.new("RGB", (width, height), (18, 14, 16))
    x = pad
    for image in pieces.values():
        scaled = image.resize((image.width * scale, image.height * scale), Image.NEAREST)
        sheet.paste(scaled, (x, pad), scaled)
        x += scaled.width + pad
    # Kept outside Godot's import scan: _preview/.gdignore stops the editor
    # from importing the 4x sheet as a game texture.
    preview = OUT / "_preview"
    preview.mkdir(exist_ok=True)
    (preview / ".gdignore").touch(exist_ok=True)
    sheet.save(preview / "contact_sheet.png")
    print(f"wrote {len(pieces)} sprites to {OUT}")
    for name, image in pieces.items():
        print(f"  {name:12s} {image.width}x{image.height}")


if __name__ == "__main__":
    main()
