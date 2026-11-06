# Crypto Ticker

BTC, ETH, SOL and BNB prices in USDT with the change and a chart for the chosen period: 1 hour, 24 hours (default), week, month or year, from the public [Binance market data API](https://developers.binance.com/docs/binance-spot-api-docs/rest-api) (no API key). The dashed line marks the price at the start of the period. To change the coins, edit `COINS` at the top of the script.

![screenshot](screenshot.png)

## Install

Copy `wallpaper.lua` to the SD card as `/sd/wallpaper.lua`. Connect to Wi-Fi in Keira, then open `/sd/wallpaper.lua` from the file manager once: the app downloads the data into `ticker.txt`. With a recent Keira the wallpaper also refreshes one coin at a time: every minute for the hour, up to every 6 hours for the year. The chosen period is saved in `ticker.txt` too, so the wallpaper keeps it. To change the default, edit `PERIOD`. On older firmware it only shows the saved data, so open the app again to refresh it.

## Controls (app only)

| Button | Action |
| --- | --- |
| ← → | Change the period |
| A | Refresh |
| START | Exit |
