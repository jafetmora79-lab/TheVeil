"""Textures for the story props (paper sheets and wall pictures). Pillow only.  python game/tools/blender/make_paper_textures.py"""
import os, random
from PIL import Image, ImageDraw, ImageFont, ImageFilter
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "prototypes", "story_props", "tex")
os.makedirs(OUT, exist_ok=True)
random.seed(5)
FONT = ImageFont.load_default()


def paper_base(w, h, tint):
    im = Image.new("RGB", (w, h), tint)
    px = im.load()
    for y in range(h):
        for x in range(w):
            n = random.randint(-9, 9)
            r, g, b = px[x, y]
            px[x, y] = (max(0, r + n), max(0, g + n), max(0, b + n))
    return im


def stain(im, cx, cy, r, col):
    ov = Image.new("RGBA", im.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    for k in range(5):
        rr = r - k * r * 0.13
        d.ellipse((cx - rr, cy - rr * random.uniform(0.85, 1.0), cx + rr, cy + rr), outline=col + (60 + k * 10,), width=2 if k == 0 else 1)
    d.ellipse((cx - r * 0.6, cy - r * 0.6, cx + r * 0.6, cy + r * 0.6), fill=col + (28,))
    im.paste(Image.alpha_composite(im.convert("RGBA"), ov).convert("RGB"))


def memo(name, tint, title, lines, stamp=None, scribble=False):
    w, h = 256, 362
    im = paper_base(w, h, tint)
    d = ImageDraw.Draw(im)
    d.text((18, 16), title, fill=(30, 30, 40), font=FONT)
    d.line((16, 32, w - 16, 32), fill=(40, 40, 50), width=1)
    y = 46
    for ln in lines:
        if scribble:
            x = 18
            while x < w - 30:
                ln_w = random.randint(8, 40)
                d.line((x, y + random.randint(-1, 1), x + ln_w, y + random.randint(-2, 2)), fill=(35, 40, 70), width=1)
                x += ln_w + random.randint(4, 9)
        else:
            d.text((18, y), ln, fill=(25, 25, 32), font=FONT)
        y += 13
    if stamp:
        st = Image.new("RGBA", (130, 40), (0, 0, 0, 0))
        sd = ImageDraw.Draw(st)
        sd.rectangle((0, 0, 129, 39), outline=(150, 20, 20, 190), width=3)
        sd.text((14, 14), stamp, fill=(150, 20, 20, 200), font=FONT)
        st = st.rotate(-14, expand=True)
        im.paste(st, (60, 230), st)
    stain(im, random.randint(60, 200), random.randint(220, 330), random.randint(14, 24), (110, 78, 40))
    im = im.filter(ImageFilter.GaussianBlur(0.4))
    im.save(os.path.join(OUT, name))


memo("paper_a.png", (214, 208, 186), "GREYHAVEN PUBLIC WORKS  -  FORM 14-B", [
    "SUBSTATION 3  -  NIGHT INSPECTION", "", "Breaker bank B reads 4% under load.", "Humming in the lower conduits again.",
    "Told dispatch twice. No answer.", "", "Access door sticks when cold.", "Do NOT open the lower seal alone.", "",
    "Crew 2 did not report back.", "Crew 2 did not report back.", "", "signed  R. Calloway"], "OVERDUE")
memo("paper_b.png", (224, 218, 196), "HANDWRITTEN - DO NOT FILE", [""] * 18, None, True)
memo("paper_c.png", (205, 202, 180), "SHIFT LOG  /  LEVEL -1", [
    "06:10 pumps ok", "06:40 pumps ok", "07:15 noise from vent 7", "07:20 noise from vent 7", "07:25 it is IN the duct",
    "07:26 sealed the grate", "07:30 the grate is warm", "", "- - - - - - - - - - - -", "08:02 lights flicker", "08:03 do not go down"], "COPY")


def poster(name, w, h, bg, title, lines, accent):
    im = Image.new("RGB", (w, h), bg)
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, w - 1, 40), fill=accent)
    d.text((10, 14), title, fill=(15, 15, 15), font=FONT)
    for i in range(0, 32, 8):                        # hazard stripes (kept to the right edge, clear of the title)
        d.polygon([(w - 50 + i, 0), (w - 40 + i, 0), (w - 50 + i - 10, 40), (w - 60 + i, 40)], fill=(20, 20, 20))
    y = 54
    for ln in lines:
        d.text((12, y), ln, fill=(235, 235, 225), font=FONT)
        y += 14
    px = im.load()
    for yy in range(h):
        for xx in range(w):
            n = random.randint(-8, 8)
            r, g, b = px[xx, yy]
            px[xx, yy] = (max(0, min(255, r + n)), max(0, min(255, g + n)), max(0, min(255, b + n)))
    stain(im, random.randint(40, w - 40), random.randint(h // 2, h - 30), 22, (60, 50, 30))
    im.save(os.path.join(OUT, name))


poster("art_safety.png", 192, 256, (30, 70, 52), "SAFETY FIRST", ["", "ISOLATE BEFORE YOU OPEN", "TWO PEOPLE IN THE LOWER", "TUNNELS AT ALL TIMES", "", "IF YOU HEAR IT HUM:", "LEAVE.", "", "Days since last accident:", "      0"], (210, 170, 30))
poster("art_grid.png", 256, 192, (22, 34, 52), "GREYHAVEN POWER GRID", ["", "  [SUB 1]----[SUB 2]----[SUB 3]", "     |          |         |", "  [MILL]      [TOWN]   [FIELD]", "     |                    |", "  [SHELTER] - - - -  [CHURCH]", "", "  LINE 3: OFFLINE", "  LINE 4: OFFLINE", "  LINE 5: ???"], (90, 150, 190))
poster("art_schedule.png", 192, 256, (68, 60, 48), "MAINTENANCE ROTA", ["", "MON  ridge pumps", "TUE  sub 1 / sub 2", "WED  sub 3 (lower)", "THU  --", "FRI  --", "", "crossed out in pencil:", "  WED  sub 3 (lower)", "  WED  sub 3 (lower)"], (180, 80, 50))
poster("art_warning.png", 160, 200, (110, 22, 20), "DANGER", ["", "HIGH VOLTAGE", "", "AUTHORISED", "STAFF ONLY", "", "   ---  ", "KEEP CLEAR OF", "THE LOWER SEAL"], (230, 200, 40))


def photo_board(name):
    w, h = 256, 192
    im = Image.new("RGB", (w, h), (96, 70, 44))
    px = im.load()
    for yy in range(h):
        for xx in range(w):
            n = random.randint(-14, 14)
            r, g, b = px[xx, yy]
            px[xx, yy] = (r + n, g + n, b + n)
    d = ImageDraw.Draw(im)
    for _ in range(7):
        x, y = random.randint(8, w - 70), random.randint(8, h - 60)
        ww, hh = random.randint(40, 62), random.randint(34, 50)
        d.rectangle((x, y, x + ww, y + hh), fill=(225, 220, 205))
        d.rectangle((x + 3, y + 3, x + ww - 3, y + hh - 10), fill=(random.randint(40, 90), random.randint(50, 80), random.randint(50, 80)))
        d.ellipse((x + ww // 2 - 6, y + hh // 3 - 6, x + ww // 2 + 6, y + hh // 3 + 6), fill=(180, 160, 140))
        d.ellipse((x + ww // 2 - 9, y + hh // 3 + 4, x + ww // 2 + 9, y + hh - 6), fill=(60, 50, 45))
        d.ellipse((x + ww // 2 - 2, y - 2, x + ww // 2 + 2, y + 2), fill=(170, 20, 20))        # a pin
    d.line((30, 20, 120, 100), fill=(160, 20, 20), width=1)
    d.line((120, 100, 220, 40), fill=(160, 20, 20), width=1)
    im.save(os.path.join(OUT, name))


photo_board("art_pinboard.png")


def sign(name, bg, fg, title, lines, w=320, h=210):
    im = Image.new("RGB", (w, h), bg)
    d = ImageDraw.Draw(im)
    d.rectangle((6, 6, w - 7, h - 7), outline=fg, width=4)
    d.text((22, 24), title, fill=fg, font=FONT)
    d.line((20, 42, w - 20, 42), fill=fg, width=2)
    y = 60
    for ln in lines:
        d.text((22, y), ln, fill=fg, font=FONT)
        y += 16
    px = im.load()
    for yy in range(h):
        for xx in range(w):
            n = random.randint(-10, 10)
            r, g, b = px[xx, yy]
            px[xx, yy] = (max(0, min(255, r + n)), max(0, min(255, g + n)), max(0, min(255, b + n)))
    for _ in range(6):
        stain(im, random.randint(20, w - 20), random.randint(20, h - 20), random.randint(12, 26), (70, 45, 25))
    for _ in range(10):                      # chipped paint
        x, y = random.randint(8, w - 12), random.randint(8, h - 12)
        d2 = ImageDraw.Draw(im)
        d2.rectangle((x, y, x + random.randint(2, 7), y + random.randint(1, 4)), fill=(90, 80, 70))
    im.save(os.path.join(OUT, name))


sign("sign_restricted.png", (150, 28, 24), (240, 235, 225), "RESTRICTED AREA", ["", "NO ENTRY", "", "AUTHORISED PERSONNEL ONLY"])
sign("sign_order.png", (40, 52, 64), (225, 225, 215), "BY ORDER OF THE", ["TOWN OF GREYHAVEN", "", "THIS DISTRICT IS CLOSED", "PUBLIC WORKS DEPT.", "", "TRESPASSERS WILL BE", "REPORTED"])
sign("sign_danger.png", (214, 170, 24), (25, 25, 25), "DANGER", ["", "KEEP OUT", "", "UNSTABLE GROUND", "OLD WORKINGS BELOW"])
sign("sign_passage.png", (60, 66, 60), (230, 225, 200), "ACCESS 3", ["MAINTENANCE", "PASSAGE", "", "ONE PERSON AT A TIME"], 240, 160)
print("textures written to", OUT)
