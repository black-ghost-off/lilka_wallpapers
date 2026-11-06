# Weather

Current weather from [Open-Meteo](https://open-meteo.com) as an animated scene (sun, clouds, rain, snow, fog, storm) with a 4-day forecast.

![screenshot](screenshot.png)

## Install

Copy `wallpaper.lua` to the SD card as `/sd/wallpaper.lua`. Connect to Wi-Fi in Keira, then open `/sd/wallpaper.lua` from the file manager once: the app downloads the data into `weather.txt`. The wallpaper only reads that file (the launcher can't make network requests), so open the app again from time to time to refresh it.

## City

By default the city is found from your IP address (via [ipwho.is](https://ipwho.is), no key); with a VPN that is the VPN server's city. To choose a city, set its name in `CITY` at the top of the script, in Ukrainian or English, for example `local CITY = "Львів"` or `"Warsaw"`: [Open-Meteo geocoding](https://open-meteo.com/en/docs/geocoding-api) finds it.

## Controls (app only)

| Button | Action |
| --- | --- |
| A | Refresh |
| START | Exit |
