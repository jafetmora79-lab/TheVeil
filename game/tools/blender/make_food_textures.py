"""Label textures for the supermarket's products (one small PNG per product variant). Pillow only.   python game/tools/blender/make_food_textures.py
Output: game/prototypes/food/tex/<variant>.png  (128 x 128, drawn big and flat for the PSX look)"""
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


def draw(name, spec):
    t1, t2, main, acc, style = spec
    random.seed(hash(name) & 0xffff)
    W = H = 128
    im = Image.new("RGB", (W, H), main)
    d = ImageDraw.Draw(im)
    if style == "band":
        d.rectangle((0, 0, W, 14), fill=acc)
        d.rectangle((0, H - 14, W, H), fill=acc)
        d.rectangle((0, 14, W, 20), fill=tuple(max(0, c - 40) for c in main))
    elif style == "burst":
        cx, cy = W // 2, H // 2 + 6
        for i in range(16):
            import math
            a0 = i * math.tau / 16 if hasattr(math, "tau") else i * 6.2832 / 16
            a1 = a0 + 0.2
            d.polygon([(cx, cy), (cx + 90 * math.cos(a0), cy + 90 * math.sin(a0)), (cx + 90 * math.cos(a1), cy + 90 * math.sin(a1))], fill=tuple(min(255, c + 25) for c in main))
        d.ellipse((cx - 38, cy - 38, cx + 38, cy + 38), fill=acc)
    elif style == "stripes":
        for i in range(-2, 9):
            d.polygon([(i * 22, 0), (i * 22 + 11, 0), (i * 22 - 20, H), (i * 22 - 31, H)], fill=acc)
    elif style == "panel":
        d.rectangle((10, 10, W - 10, H - 10), fill=acc)
        d.rectangle((14, 14, W - 14, H - 14), outline=main, width=2)
    elif style == "fruit":
        d.ellipse((24, 40, 104, 120), fill=acc)
        d.ellipse((34, 50, 94, 110), fill=main)
        d.polygon([(64, 40), (78, 22), (88, 34)], fill=(60, 150, 50))
    elif style == "water":
        for i in range(5):
            d.arc((10, 20 + i * 18, 118, 60 + i * 18), 200, 340, fill=acc, width=3)
    # the words: big, centred, with a dark outline so they read at any size
    for line, y, big in ((t1, 40, True), (t2, 74, True)):
        txt = line
        w = d.textlength(txt, font=FONT)
        # the default bitmap font is small: draw it scaled up 2x through a temp image
        tmp = Image.new("L", (int(w) + 4, 14), 0)
        ImageDraw.Draw(tmp).text((2, 1), txt, fill=255, font=FONT)
        sc = max(1, min(int(104 / max(w, 1)), 3))
        tmp = tmp.resize((tmp.width * sc, tmp.height * sc), Image.NEAREST)
        x = (W - tmp.width) // 2
        dark = tuple(max(0, c - 120) for c in main)
        for dx, dy in ((-2, 0), (2, 0), (0, -2), (0, 2)):
            im.paste(Image.new("RGB", tmp.size, dark), (x + dx, y + dy), tmp)
        im.paste(Image.new("RGB", tmp.size, (255, 255, 255) if sum(main) < 520 else (20, 20, 20)), (x, y), tmp)
    # print wear
    px = im.load()
    for _ in range(90):
        x, y = random.randrange(W), random.randrange(H)
        r, g, b = px[x, y]
        k = random.randint(-22, 22)
        px[x, y] = (max(0, min(255, r + k)), max(0, min(255, g + k)), max(0, min(255, b + k)))
    return im


import math
for n, spec in V.items():
    draw(n, spec).save(os.path.join(OUT, n + ".png"))
print(len(V), "label textures ->", OUT)
