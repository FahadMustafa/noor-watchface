"""Render a TTF into a BMFont (.fnt + .png) that the Connect IQ resource compiler reads.

usage: mkfont.py TTF SIZE AXES CHARS OUT_BASENAME
  AXES   comma list of variation axis values, e.g. "400" for Outfit weight, "1,0,24,500" for Material Symbols
  CHARS  characters to include; "X=e87e" entries (separated by spaces) map ASCII X to a codepoint (icon fonts)
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ttf, size, axes, chars, out = sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4], Path(sys.argv[5])
font = ImageFont.truetype(ttf, size)
font.set_variation_by_axes([float(a) for a in axes.split(",")])

glyphs = []  # (ascii id, char to render)
if "=" in chars:
    for pair in chars.split():
        k, cp = pair.split("=")
        glyphs.append((ord(k), chr(int(cp, 16))))
else:
    glyphs = [(ord(c), c) for c in dict.fromkeys(chars)]

ascent, _ = font.getmetrics()
pad, atlas_w = 1, 512
x = y = row_h = 0
placed = []
for gid, ch in glyphs:
    l, t, r, b = font.getbbox(ch)
    w, h = max(r - l, 1), max(b - t, 1)
    if x + w > atlas_w:
        x, y, row_h = 0, y + row_h + pad, 0
    placed.append((gid, ch, x, y, w, h, l, t, round(font.getlength(ch))))
    x, row_h = x + w + pad, max(row_h, h)
atlas_h = y + row_h
# Tight vertical metrics: line box = union of glyph boxes, so TEXT_JUSTIFY_VCENTER centres on the ink.
top = min(g[7] for g in placed)
line_h = max(g[7] + g[5] for g in placed) - top

# White glyphs with coverage in alpha (and RGB, so either channel reads correctly).
img = Image.new("RGBA", (atlas_w, atlas_h), (0, 0, 0, 0))
for gid, ch, gx, gy, w, h, l, t, adv in placed:
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).text((-l, -t), ch, font=font, fill=255)
    img.paste(Image.merge("RGBA", (mask, mask, mask, mask)), (gx, gy))

out.parent.mkdir(parents=True, exist_ok=True)
img.save(out.with_suffix(".png"))
lines = [
    f'info face="{Path(ttf).stem}" size={size} bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=1 aa=1 padding=0,0,0,0 spacing={pad},{pad}',
    f"common lineHeight={line_h} base={ascent - top} scaleW={atlas_w} scaleH={atlas_h} pages=1 packed=0",
    f'page id=0 file="{out.with_suffix(".png").name}"',
    f"chars count={len(placed)}",
]
for gid, ch, gx, gy, w, h, l, t, adv in placed:
    lines.append(f"char id={gid} x={gx} y={gy} width={w} height={h} xoffset={l} yoffset={t - top} xadvance={adv} page=0 chnl=15")
out.with_suffix(".fnt").write_text("\n".join(lines) + "\n")
print(f"{out.name}: {len(placed)} glyphs, atlas {atlas_w}x{atlas_h}, lineHeight {line_h}")
