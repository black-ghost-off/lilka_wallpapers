"""Bake the static world map (graticule + coastlines) into iss_tracker/map.bmp.

Usage: python3 tools/gen_map.py ne_110m_coastline.geojson iss_tracker/map.bmp
Coastlines: Natural Earth 110m (public domain).
Background pixels use BG, which main.lua passes as the transparent colour, so
the night shading drawn underneath shows through.
"""
import json, sys
from PIL import Image, ImageDraw

W, H = 280, 216  # full screen under the 24 px status bar
BG = (8, 24, 88)  # exact in RGB565: must match C.bg in main.lua
GRID = (32, 64, 152)
COAST = (152, 200, 248)

src, dst = sys.argv[1], sys.argv[2]
img = Image.new("RGB", (W, H), BG)
d = ImageDraw.Draw(img)

def px(lon, lat):
    x = min(W - 1, max(0, int((lon + 180) / 360 * W)))
    y = min(H - 1, max(0, int((90 - lat) / 180 * H)))
    return x, y

# dotted graticule every 30 degrees
for lon in range(-150, 180, 30):
    x, _ = px(lon, 0)
    for y in range(2, H, 4):
        d.point((x, y), GRID)
for lat in range(-60, 90, 30):
    _, y = px(0, lat)
    for x in range(2, W, 4):
        d.point((x, y), GRID)

for f in json.load(open(src))["features"]:
    g = f["geometry"]
    parts = [g["coordinates"]] if g["type"] == "LineString" else g["coordinates"]
    for p in parts:
        d.line([px(lon, lat) for lon, lat in p], fill=COAST, width=1)

img.save(dst, "BMP")  # 24-bit, bottom-up, 840-byte rows (no padding needed)
print("wrote", dst)
