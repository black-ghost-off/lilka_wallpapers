# Stocks

The S&P 500, Apple and NVIDIA with the price, the change since the previous close and a 30-day chart, from Yahoo Finance (no API key). The header shows whether the US market is open. To change the tickers, edit `SYMBOLS` at the top of the script; any Yahoo Finance ticker works (for example `^IXIC`, `MSFT`, `TSLA`).

![screenshot](screenshot.png)

## Install

Copy `wallpaper.lua` to the SD card as `/sd/wallpaper.lua`. Connect to Wi-Fi in Keira, then open `/sd/wallpaper.lua` from the file manager once: the app downloads the data into `stocks.txt`. With a recent Keira the wallpaper also refreshes it every 15 minutes, one ticker at a time. On older firmware it only shows the saved data, so open the app again to refresh it.

Yahoo Finance has no official public API, so this may stop working if Yahoo changes it.

## Controls (app only)

| Button | Action |
| --- | --- |
| A | Refresh |
| START | Exit |
