"""Signs for the supermarket's rebuilt fixtures (Pillow only).   python game/tools/blender/make_market_signs.py
Output: game/prototypes/market_props/tex/sign_<name>.png (512 x 128)"""
import os
from PIL import Image, ImageDraw, ImageFont
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "prototypes", "market_props", "tex")
os.makedirs(OUT, exist_ok=True)
IMPACT = "C:/Windows/Fonts/impact.ttf"
SIGNS = {"produce": ("FRESH PRODUCE", (30, 110, 50), (250, 245, 225)), "frozen": ("FROZEN FOODS", (20, 80, 150), (240, 248, 255)),
         "drinks": ("COLD DRINKS", (170, 25, 35), (255, 250, 240)), "dairy": ("DAIRY & MORE", (40, 90, 170), (255, 252, 245))}
for k, (t, bg, fg) in SIGNS.items():
    im = Image.new("RGB", (512, 128), bg)
    d = ImageDraw.Draw(im)
    d.rectangle((6, 6, 505, 121), outline=fg, width=4)
    f = ImageFont.truetype(IMPACT, 78)
    while d.textlength(t, font=f) > 470:
        f = ImageFont.truetype(IMPACT, f.size - 4)
    d.text((256, 66), t, font=f, fill=fg, anchor="mm")
    im.save(os.path.join(OUT, "sign_%s.png" % k))
print("signs ok")

# ---- game covers for the game shop's display case (review note #19) and a plain back
COVERS = [("STAR", "FORGE", (20, 30, 90), (255, 200, 60)), ("KART", "RALLY", (200, 50, 30), (255, 245, 200)), ("DUNGEON", "DEPTHS", (50, 25, 60), (200, 120, 255)),
          ("PIXEL", "FARM", (70, 150, 60), (255, 240, 150)), ("NINJA", "CITY", (20, 20, 25), (240, 40, 60)), ("SKY", "PILOT", (60, 140, 220), (255, 255, 255)),
          ("GOAL", "KICK", (30, 120, 60), (255, 255, 255)), ("MONSTER", "MASH", (230, 140, 30), (40, 20, 10))]
for i, (a, b, bg, fg) in enumerate(COVERS):
    im = Image.new("RGB", (128, 176), bg)
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, 127, 22), fill=fg)
    d.text((64, 11), "PLAYSTATION-STYLE  ·  ALL AGES", font=ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 9), fill=bg, anchor="mm")
    for k in range(7):
        d.polygon([(64, 120), (64 + 90 * (1 if k % 2 else -1) * (k + 1) / 7, 30), (64 + 90 * (1 if k % 2 else -1) * (k + 2) / 7, 30)], fill=tuple(min(255, c + 25) for c in bg))
    f1 = ImageFont.truetype(IMPACT, 40)
    f2 = ImageFont.truetype(IMPACT, 30)
    for ff, t, y in ((f1, a, 76), (f2, b, 112)):
        while d.textlength(t, font=ff) > 112:
            ff = ImageFont.truetype(IMPACT, ff.size - 3)
        for dx, dy in ((-2, 0), (2, 0), (0, -2), (0, 2)):
            d.text((64 + dx, y + dy), t, font=ff, fill=(10, 10, 10), anchor="mm")
        d.text((64, y), t, font=ff, fill=fg, anchor="mm")
    d.rectangle((0, 150, 127, 175), fill=(15, 15, 20))
    d.text((64, 163), "RATED T", font=ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 11), fill=(255, 255, 255), anchor="mm")
    im.save(os.path.join(OUT, "cover_%d.png" % i))
back = Image.new("RGB", (128, 176), (28, 28, 34))
d = ImageDraw.Draw(back)
d.rectangle((14, 20, 114, 110), fill=(55, 55, 66))
for k in range(0, 100, 5):
    d.rectangle((24 + k * 0.8, 128, 25 + k * 0.8 + (k % 3), 160), fill=(235, 235, 235))
back.save(os.path.join(OUT, "cover_back.png"))
print("covers ok")
