"""Label textures for the supermarket's products (one small PNG per product variant). Pillow only.   python game/tools/blender/make_food_textures.py
Output: game/prototypes/food/tex/<variant>.png  (256 x 256, drawn big and flat for the PSX look)"""
import os, random
from PIL import Image, ImageDraw, ImageFont

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "prototypes", "food", "tex")
os.makedirs(OUT, exist_ok=True)
FONT = ImageFont.load_default()

# variant: (text, line 2, main colour, accent colour, style)  styles: band / burst / stripes / panel / fruit / water
V = {
    "can_beans": ("BAKED", "BEANS", (150, 80, 30), (240, 220, 160), "band"),
    "can_soup": ("TOMATO", "SOUP", (190, 30, 30), (250, 245, 235), "band"),
    "can_tomato": ("WHOLE", "TOMATOES", (200, 40, 35), (90, 140, 50), "band"),
    "can_corn": ("SWEET", "CORN", (235, 195, 40), (80, 150, 60), "band"),
    "can_tuna": ("TUNA", "IN WATER", (40, 90, 160), (230, 235, 240), "band"),
    "can_peach": ("PEACH", "SLICES", (240, 150, 80), (250, 220, 150), "band"),
    "bottle_water": ("SPRING", "WATER", (70, 140, 210), (240, 248, 255), "water"),
    "bottle_sport": ("SPORT", "DRINK", (40, 170, 90), (30, 90, 170), "stripes"),
    "bottle_cola": ("COLA", "ORIGINAL", (170, 20, 25), (240, 240, 240), "burst"),
    "bottle_orange": ("ORANGE", "SODA", (240, 140, 20), (255, 240, 200), "fruit"),
    "bottle_lime": ("LIME", "FIZZ", (120, 190, 40), (255, 255, 220), "fruit"),
    "bottle_tea": ("ICED", "TEA", (190, 120, 40), (250, 230, 180), "band"),
    "bottle_volt": ("VOLT", "ENERGY", (240, 215, 30), (25, 25, 30), "stripes"),
    "bottle_berry": ("BERRY", "BLAST", (120, 40, 150), (250, 190, 220), "fruit"),
    "bag_rice_a": ("LONG GRAIN", "RICE", (235, 230, 215), (200, 150, 40), "panel"),
    "bag_rice_b": ("BROWN", "RICE", (200, 170, 120), (110, 70, 30), "panel"),
    "bag_rice_c": ("JASMINE", "RICE", (230, 235, 240), (60, 130, 90), "panel"),
    "bag_beans_a": ("PINTO", "BEANS", (200, 150, 110), (120, 60, 30), "panel"),
    "bag_beans_b": ("BLACK", "BEANS", (70, 70, 80), (230, 230, 230), "panel"),
    "bag_beans_c": ("RED", "BEANS", (170, 50, 40), (240, 220, 200), "panel"),
    "bag_chips_a": ("CRUNCH", "CHIPS", (200, 40, 30), (250, 210, 60), "burst"),
    "bag_chips_b": ("SALTY", "CHIPS", (245, 205, 50), (190, 40, 35), "burst"),
    "bag_chips_c": ("SOUR", "CREAM", (60, 160, 70), (250, 250, 230), "burst"),
    "bag_chips_d": ("SEA", "SALT", (50, 100, 180), (250, 250, 250), "burst"),
    "bag_tortilla_a": ("NACHO", "CHIPS", (230, 120, 30), (250, 220, 80), "burst"),
    "bag_tortilla_b": ("CORN", "CHIPS", (240, 200, 60), (190, 100, 30), "burst"),
    "bag_tortilla_c": ("SPICY", "CHIPS", (200, 40, 40), (20, 20, 20), "burst"),
    "box_pasta_a": ("SPAGHETTI", "500g", (230, 190, 60), (190, 40, 40), "panel"),
    "box_pasta_b": ("PENNE", "500g", (225, 120, 40), (250, 240, 200), "panel"),
    "box_pasta_c": ("MACARONI", "& CHEESE", (245, 190, 40), (200, 60, 30), "panel"),
    "box_cereal_a": ("CORN", "FLAKES", (230, 190, 50), (200, 50, 40), "burst"),
    "box_cereal_b": ("CHOCO", "PUFFS", (110, 60, 30), (250, 220, 190), "burst"),
    "box_cereal_c": ("OATY", "RINGS", (190, 120, 40), (240, 235, 200), "burst"),
    "box_cereal_d": ("FRUITY", "LOOPS", (200, 40, 120), (80, 190, 230), "burst"),
    "box_crackers_a": ("SALTED", "CRACKERS", (60, 110, 180), (250, 250, 250), "panel"),
    "box_crackers_b": ("CHEESE", "CRACKERS", (240, 150, 40), (250, 240, 190), "panel"),
    "box_crackers_c": ("WHEAT", "THINS", (150, 100, 50), (240, 225, 180), "panel"),
    "box_cookies_a": ("CHOC CHIP", "COOKIES", (150, 90, 50), (250, 235, 200), "panel"),
    "box_cookies_b": ("OAT", "COOKIES", (200, 150, 80), (90, 50, 30), "panel"),
    "box_cookies_c": ("CREME", "SANDWICH", (40, 50, 110), (240, 240, 250), "panel"),
    "box_snack_a": ("CHEESE", "PUFFS", (240, 160, 30), (250, 240, 200), "burst"),
    "box_snack_b": ("TRAIL", "MIX", (130, 90, 50), (230, 190, 70), "panel"),
    "box_snack_c": ("POPCORN", "BUTTER", (230, 200, 70), (200, 40, 40), "burst"),
    "candy_bar_a": ("CARAMEL", "CRUNCH", (200, 130, 40), (90, 40, 20), "stripes"),
    "candy_bar_b": ("MINT", "CHOC", (40, 160, 140), (250, 250, 250), "stripes"),
    "candy_bar_c": ("PEANUT", "SNACK BAR", (160, 90, 40), (240, 200, 90), "stripes"),
    "candy_bar_d": ("BERRY", "CHEW", (170, 40, 100), (250, 200, 230), "stripes"),
    "choc_a": ("MILK", "CHOCOLATE", (110, 60, 30), (230, 190, 90), "band"),
    "choc_b": ("DARK", "CHOCOLATE", (50, 25, 30), (200, 160, 90), "band"),
    "choc_c": ("HAZELNUT", "CHOCOLATE", (130, 80, 40), (240, 220, 160), "band"),
}


IMPACT = "C:/Windows/Fonts/impact.ttf"
ARIAL = "C:/Windows/Fonts/arialbd.ttf"
W = H = 256


def font(path, size):
    try:
        return ImageFont.truetype(path, size)
    except Exception:
        return ImageFont.load_default()


def fit(d, text, path, max_w, start):
    size = start
    while size > 8:
        f = font(path, size)
        if d.textlength(text, font=f) <= max_w:
            return f
        size -= 2
    return font(path, 8)


def shade(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c)


def outlined(d, xy, text, f, fill, edge, w=3):
    x, y = xy
    for dx in range(-w, w + 1):
        for dy in range(-w, w + 1):
            if dx * dx + dy * dy <= w * w:
                d.text((x + dx, y + dy), text, font=f, fill=edge, anchor="mm")
    d.text((x, y), text, font=f, fill=fill, anchor="mm")


def draw(name, spec):
    t1, t2, main, acc, style = spec
    random.seed(hash(name) & 0xffff)
    im = Image.new("RGB", (W, H), main)
    d = ImageDraw.Draw(im)
    light = sum(main) > 480
    ink = (25, 25, 30) if light else (255, 255, 255)
    edge = shade(main, 0.35) if not light else shade(acc, 0.5)
    brand = {"can": "HOMESTEAD", "bottle": "FIZZ & CO", "bag": "CRUNCHTOWN", "box": "PANTRY PRIDE", "candy": "SWEETWORKS", "choc": "CHOCOLATIER"}[name.split("_")[0]]
    if style == "band":
        d.rectangle((0, 0, W, 34), fill=acc)
        d.rectangle((0, H - 34, W, H), fill=acc)
        d.rectangle((0, 34, W, 42), fill=shade(main, 0.6))
        d.ellipse((W // 2 - 62, 120, W // 2 + 62, 244), fill=shade(main, 1.25))
    elif style == "burst":
        import math
        cx, cy = W // 2, int(H * 0.60)
        for i in range(20):
            a0 = i * math.tau / 20
            a1 = a0 + 0.17
            d.polygon([(cx, cy), (cx + 220 * math.cos(a0), cy + 220 * math.sin(a0)), (cx + 220 * math.cos(a1), cy + 220 * math.sin(a1))], fill=shade(main, 1.18))
        d.ellipse((cx - 96, cy - 96, cx + 96, cy + 96), fill=acc)
    elif style == "stripes":
        for i in range(-3, 9):
            d.polygon([(i * 44, 0), (i * 44 + 22, 0), (i * 44 - 40, H), (i * 44 - 62, H)], fill=acc)
        d.rectangle((14, 70, W - 14, 190), fill=main)
    elif style == "panel":
        d.rectangle((16, 16, W - 16, H - 16), fill=acc)
        d.rectangle((24, 24, W - 24, H - 24), outline=main, width=4)
        d.rectangle((24, H - 70, W - 24, H - 24), fill=main)
    elif style == "fruit":
        d.ellipse((46, 96, 210, 252), fill=acc)
        d.ellipse((66, 116, 190, 240), fill=main)
        d.polygon([(128, 96), (158, 52), (182, 80)], fill=(60, 150, 50))
        d.ellipse((92, 140, 120, 168), fill=shade(main, 1.4))
    elif style == "water":
        for i in range(6):
            d.arc((20, 50 + i * 30, 236, 120 + i * 30), 200, 340, fill=acc, width=5)
    # brand strip, the big name (Impact), the second line, a small print line
    fb = fit(d, brand, ARIAL, W - 40, 18 if style == "band" else 22)
    strip_col = ink if style not in ("stripes", "band") else (25, 25, 30)
    if style in ("band", "panel"):
        d.text((W // 2, 19 if style == "band" else 44), brand, font=fb, fill=ink if style == "panel" and False else (25, 25, 30) if light or style == "panel" else (255, 255, 255), anchor="mm")
    else:
        d.text((W // 2, 24), brand, font=fb, fill=strip_col if not light else (25, 25, 30), anchor="mm")
    f1 = fit(d, t1, IMPACT, W - 36, 78)
    f2 = fit(d, t2, IMPACT, W - 36, 56)
    c1 = ink if style != "panel" else shade(main, 0.45)
    if style == "panel":
        edge = acc
    c2 = acc if (style not in ("panel",) and sum(acc) > 380 and not light) else ink
    outlined(d, (W // 2, 108), t1, f1, c1, edge, 1 if style == "panel" else 3)
    outlined(d, (W // 2, 168), t2, f2, c2 if style != "panel" else shade(main, 0.45), edge, 2)
    fs = font(ARIAL, 16)
    small = "NET WT 12 OZ" if name.startswith(("bag", "box", "candy", "choc")) else "FRESH  .  NATURAL"
    d.text((W // 2, H - 22 if style != "band" else H - 16), small, font=fs, fill=(25, 25, 30) if (light or style == "band") else (255, 255, 255), anchor="mm")
    px = im.load()
    for _ in range(220):
        x, y = random.randrange(W), random.randrange(H)
        r, g, b = px[x, y]
        k = random.randint(-18, 18)
        px[x, y] = (max(0, min(255, r + k)), max(0, min(255, g + k)), max(0, min(255, b + k)))
    return im


import math
for n, spec in V.items():
    draw(n, spec).save(os.path.join(OUT, n + ".png"))
print(len(V), "label textures ->", OUT)
