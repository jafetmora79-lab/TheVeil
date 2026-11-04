"""THE VEIL - build game/ui/fonts/VeilPixel.ttf: a true pixel font (every glyph is made of square pixels).
Glyph shapes are rasterised, without anti-aliasing, from DejaVu Sans Bold at a small pixel size. Each lit pixel
becomes a square contour (horizontal runs merged). Em = 13 pixels (ascent 10, descent 3). Render it
at multiples of 13 px with anti-aliasing off for crisp pixels; Godot's outline works on it like any TTF.
    python3 game/tools/make_pixel_font.py
"""
import os
from PIL import Image, ImageDraw, ImageFont
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen

SRC = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "ui", "fonts", "VeilPixel.ttf")
PX = 100                      # font units per pixel
SIZE = 10                     # raster size (px) of the source font
CHARS = [chr(c) for c in range(32, 127)] + list("—–’“”…·°")

src = ImageFont.truetype(SRC, SIZE)
asc, desc = src.getmetrics()
EM_PX, ASC_PX, DESC_PX = asc + desc, asc, desc      # 13 px em: render at 26 / 39 px
names = [".notdef"]
glyphs, metrics, cmap = {}, {}, {}


def raster(ch):
    img = Image.new("1", (SIZE * 2, SIZE * 2), 0)
    d = ImageDraw.Draw(img)
    d.fontmode = "1"
    d.text((2, 2), ch, font=src, fill=1)
    return img


def glyph_from(img, base_y, adv_px):
    pen = TTGlyphPen(None)
    w, h = img.size
    px = img.load()
    any_on = False
    for y in range(h):
        x = 0
        while x < w:
            if px[x, y]:
                x0 = x
                while x < w and px[x, y]:
                    x += 1
                top = (base_y - y) * PX
                pen.moveTo((x0 * PX, top))
                pen.lineTo((x * PX, top))
                pen.lineTo((x * PX, top - PX))
                pen.lineTo((x0 * PX, top - PX))
                pen.closePath()
                any_on = True
            else:
                x += 1
    return pen.glyph(), any_on


base = 2 + asc                 # baseline row inside the raster
empty = TTGlyphPen(None).glyph()
glyphs[".notdef"] = empty
metrics[".notdef"] = (6 * PX, 0)
for ch in CHARS:
    name = "uni%04X" % ord(ch)
    img = raster(ch)
    bbox = img.getbbox()
    if ch == " " or bbox is None:
        g, adv = empty, 4
    else:
        x0, _, x1, _ = bbox
        img = img.crop((x0, 0, x1, img.size[1]))
        adv = (x1 - x0) + 1
        g, _ = glyph_from(img, base, adv)
    names.append(name)
    glyphs[name] = g
    metrics[name] = (adv * PX, 0)
    cmap[ord(ch)] = name

fb = FontBuilder(EM_PX * PX, isTTF=True)
fb.setupGlyphOrder(names)
fb.setupCharacterMap(cmap)
fb.setupGlyf(glyphs)
fb.setupHorizontalMetrics(metrics)
fb.setupHorizontalHeader(ascent=ASC_PX * PX, descent=-DESC_PX * PX)
fb.setupNameTable({"familyName": "Veil Pixel", "styleName": "Regular"})
fb.setupOS2(sTypoAscender=ASC_PX * PX, sTypoDescender=-DESC_PX * PX, usWinAscent=ASC_PX * PX, usWinDescent=DESC_PX * PX)
fb.setupPost()
fb.save(os.path.normpath(OUT))
print("wrote", os.path.normpath(OUT), len(cmap), "glyphs; source raster", SIZE, "px, ascent", asc, "descent", desc)
