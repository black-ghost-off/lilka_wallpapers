# ISS Tracker for Lilka

Live ISS position, ground track and day/night map for the [Lilka](https://lilka.dev) console (KeiraOS Lua). Runs as an app or as the home-screen wallpaper.

![ISS tracker on Lilka](image.png)

The position is computed on the device from the ISS orbital elements (TLE) and the NTP clock, so the app starts instantly and keeps working offline. The TLE is cached in `tle.txt` and refreshed from [CelesTrak](https://celestrak.org) (or [ARISS](https://live.ariss.org)) when it is older than 12 hours.

## Install

1. Copy the `iss_tracker/` folder to the SD card, for example as `/sd/iss/`.
2. Connect to Wi-Fi in Keira.
3. Open `main.lua` from the file manager. Press **B** to exit.

## Wallpaper

Copy `iss_tracker` into `/sd` and rename `main.lua` to `wallpaper.lua` to use as wallpaper (adjust the folder name if needed):

The wallpaper only reads the cached `tle.txt`. It never downloads: the launcher's 8 KB stack is too small for an HTTP request. Open the app once in a while to refresh the TLE.

## Files

| File | Purpose |
| --- | --- |
| `iss_tracker/main.lua` | App and wallpaper |
| `iss_tracker/map.bmp` | World map, 280×216 (coastlines and grid) |
| `iss_tracker/tle.txt` | Cached ISS TLE |
| `tools/gen_map.py` | Regenerates `map.bmp` from Natural Earth coastlines |

To regenerate the map (needs Pillow):

```sh
curl -LO https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_110m_coastline.geojson
python3 tools/gen_map.py ne_110m_coastline.geojson iss_tracker/map.bmp
```
