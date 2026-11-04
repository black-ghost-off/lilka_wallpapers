"""Bake the world land mask into rectangles for quakes/wallpaper.lua.

Usage: python3 tools/gen_map.py ne_110m_land.geojson > land.txt
Land: Natural Earth 110m (public domain). Prints MAP_W, MAP_H and a LAND string:
8 characters per rectangle (x, y, w, h, two base64 digits each), the same format
as alerts/wallpaper.lua.
"""
import json, sys
from PIL import Image, ImageDraw

W = 280
LAT_TOP, LAT_BOT = 80, -58  # Antarctica and the far north are cut off
H = round((LAT_TOP - LAT_BOT) / 360 * W)
ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

def px(lon, lat):
    return (lon + 180) / 360 * W, (LAT_TOP - lat) / 360 * W

img = Image.new("1", (W, H), 0)
d = ImageDraw.Draw(img)
for f in json.load(open(sys.argv[1]))["features"]:
    g = f["geometry"]
    polys = [g["coordinates"]] if g["type"] == "Polygon" else g["coordinates"]
    for poly in polys:
        d.polygon([px(lon, lat) for lon, lat in poly[0]], fill=1)
        for hole in poly[1:]:
            d.polygon([px(lon, lat) for lon, lat in hole], fill=0)

# Runs per row, then merge identical runs in consecutive rows into rectangles
open_r, rects = {}, []
for y in range(H + 1):
    runs = set()
    if y < H:
        x = 0
        while x < W:
            if img.getpixel((x, y)):
                s = x
                while x < W and img.getpixel((x, y)):
                    x += 1
                runs.add((s, x - s))
            x += 1
    nxt = {}
    for r in runs:
        nxt[r] = open_r.pop(r) if r in open_r else y
    for (x0, w), y0 in open_r.items():
        rects.append((x0, y0, w, y - y0))
    open_r = nxt

enc = lambda n: ALPHABET[n // 64] + ALPHABET[n % 64]
print("MAP_W, MAP_H, LAT_TOP =", W, H, LAT_TOP)
print('LAND = "' + "".join(enc(a) + enc(b) + enc(c) + enc(e) for a, b, c, e in rects) + '"')
print("rects", len(rects), file=sys.stderr)
