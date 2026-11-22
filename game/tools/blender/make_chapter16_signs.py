"""THE VEIL - every piece of WORDS baked into a picture for Chapter 16's places (the facility, the service galleries, the plaque, the town map), made from one text table so a LANGUAGE is a
column, not a re-draw (review note #68: "eventually we will need a Spanish version, so all items that have letters or words need a Spanish asset"). Pillow only.
   python game/tools/blender/make_chapter16_signs.py            # writes en + es
Output: game/prototypes/ch16/tex/<name>_<lang>.png.  In the game: `VeilLoc.tex("plaque")` (game/world/loc.gd) picks the file for Game.language, falling back to English.
To add a language: add a column to TEXT below, run this, and add the language to game/data/languages.json. Anything with baked words (a new sign, a stencil, a map label) MUST be added here, never drawn by hand."""
import os, random
from PIL import Image, ImageDraw, ImageFont

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "prototypes", "ch16", "tex")
os.makedirs(OUT, exist_ok=True)
IMPACT = "C:/Windows/Fonts/impact.ttf"
ARIAL = "C:/Windows/Fonts/arialbd.ttf"
MONO = "C:/Windows/Fonts/consolab.ttf"

TEXT = {
    "plaque": {"en": ["GREYHAVEN PUBLIC WORKS", "SERVICE GALLERY 7  -  19##", "THIS CHAMBER IS NOT TO BE OPENED"],
               "es": ["OBRAS PUBLICAS DE GREYHAVEN", "GALERIA DE SERVICIO 7  -  19##", "ESTA CAMARA NO DEBE ABRIRSE"]},
    "gallery7": {"en": ["GALLERY 7", "SECTION B"], "es": ["GALERIA 7", "SECCION B"]},
    "valve": {"en": ["VALVE B-12", "CLOSED"], "es": ["VALVULA B-12", "CERRADA"]},
    "noentry": {"en": ["NO ENTRY", "STRUCTURAL DAMAGE"], "es": ["PROHIBIDO PASAR", "DANO ESTRUCTURAL"]},
    "exit": {"en": ["EXIT"], "es": ["SALIDA"]},
    "staff": {"en": ["AUTHORISED", "PERSONNEL ONLY"], "es": ["SOLO PERSONAL", "AUTORIZADO"]},
    "map_title": {"en": ["GREYHAVEN", "1 : 2000"], "es": ["GREYHAVEN", "1 : 2000"]},
    "map_legend": {"en": ["ROAD", "THE OLD DISTRICT", "THE PASSAGE"], "es": ["CARRETERA", "EL BARRIO VIEJO", "EL PASO"]},
}


def font(path, size):
    try:
        return ImageFont.truetype(path, size)
    except Exception:
        return ImageFont.load_default()


def sign(name, lang, size, bg, fg, border, font_path=IMPACT, rivets=True):
    lines = TEXT[name][lang]
    im = Image.new("RGB", size, bg)
    d = ImageDraw.Draw(im)
    w, h = size
    d.rectangle((3, 3, w - 4, h - 4), outline=border, width=4)
    if rivets:
        for (x, y) in ((12, 12), (w - 13, 12), (12, h - 13), (w - 13, h - 13)):
            d.ellipse((x - 4, y - 4, x + 4, y + 4), fill=border)
    n = len(lines)
    for i, t in enumerate(lines):
        fs = int((h - 30) / n * 0.8)
        f = font(font_path, fs)
        while d.textlength(t, font=f) > w - 40 and fs > 8:
            fs -= 2
            f = font(font_path, fs)
        d.text((w // 2, 20 + (i + 0.5) * (h - 40) / n), t, font=f, fill=fg, anchor="mm")
    random.seed(hash(name + lang) & 0xffff)
    px = im.load()
    for _ in range(int(w * h * 0.02)):
        x, y = random.randrange(w), random.randrange(h)
        r, g, b = px[x, y]
        k = random.randint(-25, 25)
        px[x, y] = (max(0, min(255, r + k)), max(0, min(255, g + k)), max(0, min(255, b + k)))
    return im


def town_map(lang):
    im = Image.new("RGB", (512, 384), (212, 196, 160))
    d = ImageDraw.Draw(im)
    random.seed(11)
    for x in range(0, 512, 64):
        d.line((x, 0, x, 384), fill=(190, 172, 135), width=1)
    for y in range(0, 384, 64):
        d.line((0, y, 512, y), fill=(190, 172, 135), width=1)
    for (x0, y0, x1, y1) in ((0, 180, 512, 200), (250, 0, 270, 384), (60, 60, 420, 74), (100, 300, 480, 312)):
        d.rectangle((x0, y0, x1, y1), fill=(120, 110, 100))                        # the roads
    for gx in range(20, 500, 52):
        for gy in range(20, 360, 46):
            if abs(gx - 260) < 30 or abs(gy - 190) < 22:
                continue
            d.rectangle((gx, gy, gx + 30, gy + 22), fill=(165, 140, 110), outline=(110, 95, 75))
    # the route: from the station west of the town, along the road, to the old district and the passage
    pts = [(40, 300), (120, 250), (230, 215), (250, 150), (300, 100), (380, 80)]
    d.line(pts, fill=(170, 30, 30), width=4)
    for (x, y) in pts:
        d.ellipse((x - 5, y - 5, x + 5, y + 5), fill=(170, 30, 30))
    d.ellipse((370, 70, 390, 90), outline=(20, 20, 20), width=3)
    d.line((366, 66, 394, 94), fill=(20, 20, 20), width=3)
    d.line((394, 66, 366, 94), fill=(20, 20, 20), width=3)
    f = font(IMPACT, 30)
    t = TEXT["map_title"][lang]
    d.text((18, 12), t[0], font=f, fill=(60, 45, 30))
    d.text((18, 48), t[1], font=font(ARIAL, 14), fill=(60, 45, 30))
    lg = TEXT["map_legend"][lang]
    d.text((300, 330), lg[1], font=font(ARIAL, 13), fill=(120, 20, 20))
    d.text((300, 346), lg[2], font=font(ARIAL, 13), fill=(20, 20, 20))
    d.text((300, 362), lg[0], font=font(ARIAL, 13), fill=(60, 55, 50))
    for _ in range(900):
        x, y = random.randrange(512), random.randrange(384)
        r, g, b = im.getpixel((x, y))
        k = random.randint(-14, 14)
        im.putpixel((x, y), (max(0, min(255, r + k)), max(0, min(255, g + k)), max(0, min(255, b + k))))
    return im


for lang in ("en", "es"):
    sign("plaque", lang, (512, 160), (150, 125, 70), (40, 30, 10), (95, 78, 40), ARIAL).save(os.path.join(OUT, "plaque_%s.png" % lang))
    sign("gallery7", lang, (256, 96), (200, 190, 60), (25, 25, 25), (25, 25, 25)).save(os.path.join(OUT, "gallery7_%s.png" % lang))
    sign("valve", lang, (192, 96), (170, 30, 30), (240, 235, 220), (240, 235, 220)).save(os.path.join(OUT, "valve_%s.png" % lang))
    sign("noentry", lang, (256, 128), (200, 190, 60), (160, 20, 20), (25, 25, 25)).save(os.path.join(OUT, "noentry_%s.png" % lang))
    sign("exit", lang, (192, 64), (30, 110, 50), (240, 245, 235), (240, 245, 235)).save(os.path.join(OUT, "exit_%s.png" % lang))
    sign("staff", lang, (256, 96), (60, 70, 90), (230, 230, 235), (200, 200, 205)).save(os.path.join(OUT, "staff_%s.png" % lang))
    town_map(lang).save(os.path.join(OUT, "map_%s.png" % lang))
print("ch16 signs ok ->", OUT)
