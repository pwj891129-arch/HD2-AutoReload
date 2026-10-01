import argparse
import hashlib
import json
import math
import struct
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


parser = argparse.ArgumentParser(description="Build an OFL Korean glyph mask atlas, not a game font resource.")
parser.add_argument("font", type=Path)
args = parser.parse_args()
root = Path(__file__).resolve().parent.parent
names = json.loads((root / "assets/stratagem-names-ko.json").read_text(encoding="utf-8"))
chars = sorted(set("".join(row["ko"] for row in names["names"]) + "스트라타젬" + "".join(chr(i) for i in range(32, 127))))
data = args.font.read_bytes()
font = ImageFont.truetype(str(args.font), 64)
missing = bytes(font.getmask("\uffff"))
assert all(char == " " or bytes(font.getmask(char)) != missing for char in chars), "Font must cover every label"
tile, width = 80, 2048
columns = width // tile
height = 2 ** math.ceil(math.log2(math.ceil(len(chars) / columns) * tile))
mask = Image.new("L", (width, height))
draw = ImageDraw.Draw(mask)
glyphs = {}
for index, char in enumerate(chars):
    left, top, right, bottom = font.getbbox(char, anchor="ls")
    w, h = right - left, bottom - top
    assert w <= tile - 8 and h <= tile - 8
    x, y = (index % columns) * tile + 4, (index // columns) * tile + 4
    if w and h:
        draw.text((x - left, y - top), char, font=font, anchor="ls", fill=255)
    glyphs[char] = [x, y, w, h, left, -bottom, font.getlength(char)]
# Native icon-mask material uses the red channel as coverage; the other masks are empty.
zero = Image.new("L", mask.size)
Image.merge("RGBA", (mask, zero, zero, Image.new("L", mask.size, 255))).save(root / "assets/wheel-glyphs.png", optimize=True)
copyright_text = None
for index in range(struct.unpack_from(">H", data, 4)[0]):
    tag, _, offset, _ = struct.unpack_from(">4sIII", data, 12 + index * 16)
    if tag != b"name":
        continue
    _, count, strings = struct.unpack_from(">HHH", data, offset)
    for row in range(count):
        platform, _, _, name, length, at = struct.unpack_from(">6H", data, offset + 6 + row * 12)
        if name == 0 and platform == 3:
            copyright_text = data[offset + strings + at:offset + strings + at + length].decode("utf-16-be")
assert copyright_text, "Preserve the font's original copyright notice"
metadata = {
    "resource": "mods/hd2_helper/wheel_glyphs",
    "font": "Noto Sans CJK KR Regular",
    "license": "SIL Open Font License 1.1",
    "copyright": copyright_text,
    "source": "https://github.com/notofonts/noto-cjk/tree/main/Sans/OTF/Korean",
    "fontSha256": hashlib.sha256(data).hexdigest(),
    "baseSize": 64,
    "width": width,
    "height": height,
    "glyphs": glyphs,
}
(root / "assets/wheel-glyphs.json").write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(f"PASS {len(chars)} OFL glyphs, {width}x{height}, font SHA256 {metadata['fontSha256']}")
