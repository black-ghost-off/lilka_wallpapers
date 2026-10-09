# Lilka Wallpapers

Live home-screen wallpapers for the [Lilka](https://lilka.dev) console (KeiraOS Lua).

Each wallpaper is one `wallpaper.lua`. Copy it to the SD card as `/sd/wallpaper.lua`, and the launcher shows it on the home screen. Every script also runs as an app: open it from Keira's file manager.

| | |
| --- | --- |
| [**Aquarium**](aquarium/) — tropical fish in 2.5D<br>![](aquarium/screenshot.png) | [**Living Window**](window/) — sky and city by the real time<br>![](window/screenshot.png) |
| [**Weather**](weather/) — Open-Meteo, animated *(Wi-Fi)*<br>![](weather/screenshot.png) | [**Currency**](currency/) — NBU rates, 30-day charts *(Wi-Fi)*<br>![](currency/screenshot.png) |
| [**GitHub**](github/) — contribution grid *(Wi-Fi)*<br>![](github/screenshot.png) | [**Synthwave**](synthwave/) — neon grid and sun<br>![](synthwave/screenshot.png) |
| [**Boids**](boids/) — flock over sunflowers<br>![](boids/screenshot.png) | [**Campfire**](fire/) — Doom fire effect<br>![](fire/screenshot.png) |
| [**Rain**](rain/) — drops on the window<br>![](rain/screenshot.png) | [**Pet Cat**](pet/) — feed and play in the app<br>![](pet/screenshot.png) |
| [**Kyiv Metro**](metro/) — trains on schedule<br>![](metro/screenshot.png) | [**Air Raid Alerts**](alerts/) — live map by oblast *(Wi-Fi)*<br>![](alerts/screenshot.png) |
| [**Home Assistant**](ha/) — sensors and switches *(Wi-Fi)*<br>![](ha/screenshot.png) | |
| [**Starfield**](starfield/) — Keira's example<br>![](starfield/screenshot.png) | [**ISS Tracker**](iss_tracker/) — live ISS position *(Wi-Fi)*<br>![](iss_tracker/image.png) |

*(Wi-Fi)*: open the script as an app once to download data. Most of these wallpapers only show what is saved, because the launcher couldn't make network requests on older firmware. Air Raid Alerts and Home Assistant also refresh on the wallpaper with a recent Keira.

## Credits

- [alerts](alerts/) uses oblast borders from [geoBoundaries](https://www.geoboundaries.org) (CC BY 4.0).
- [starfield](starfield/) is the example from [lilka-dev/keira](https://github.com/lilka-dev/keira/blob/main/data/wallpaper.lua), unchanged.
- [iss_tracker](iss_tracker/) is a copy of [black-ghost-off/lilka_iss_tracker](https://github.com/black-ghost-off/lilka_iss_tracker), unchanged. See its own README for installing it.