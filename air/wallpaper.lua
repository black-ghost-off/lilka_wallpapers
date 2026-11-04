-- Якість повітря (Open-Meteo, без ключа API): європейський індекс AQI, PM2.5, PM10, NO2, O3
-- і графік індексу за вчора й сьогодні. Чим брудніше повітря, тим густіший серпанок на тлі.
-- Застосунок завантажує дані в air.txt; шпалери на свіжій Keira оновлюють їх самі.
-- Застосунок: A — оновити, START — вихід.

lilka.fullscreen = false

local LAT, LON = 50.45, 30.52 -- Київ
local PLACE = "Київ"
local CACHE = "air.txt"
local REFRESH = 60 * 60
local URL = "https://air-quality-api.open-meteo.com/v1/air-quality?latitude=" .. LAT .. "&longitude=" .. LON
    .. "&current=european_aqi,pm2_5,pm10,nitrogen_dioxide,ozone&hourly=european_aqi&past_days=1&forecast_days=1&timezone=Europe%2FKyiv"

local floor, rnd, sin = math.floor, math.random, math.sin
local function min(a, b) if a < b then return a end return b end
local function max(a, b) if a > b then return a end return b end
local function clamp(x, a, b) return min(b, max(a, x)) end
local function rgb(r, g, b) return display.color565(floor(clamp(r, 0, 255)), floor(clamp(g, 0, 255)), floor(clamp(b, 0, 255))) end

local function text(s, x, y, c, font)
    display.set_font(font)
    display.set_text_size(1)
    display.set_text_color(c)
    display.set_cursor(floor(x), floor(y))
    display.print(s)
end

local W, H
local t = 0
local cur = {}     -- aqi, pm25, pm10, no2, o3
local hourly = {}  -- 48 значень індексу (вчора + сьогодні)
local at, status
local next_fetch = 0
local haze = {}
local C = {}

-- Шкала EAQI: межі, назви, кольори
local LEVELS = {
    { 20, "Добре", { 80, 220, 230 } },
    { 40, "Задовільно", { 80, 200, 140 } },
    { 60, "Помірно", { 240, 220, 70 } },
    { 80, "Погано", { 250, 130, 60 } },
    { 100, "Дуже погано", { 230, 60, 70 } },
    { 1e9, "Жахливо", { 160, 60, 160 } },
}
local function level(v)
    for i, l in ipairs(LEVELS) do if v < l[1] then return i end end
    return #LEVELS
end

local function parse(s)
    local c = s:match('"current":(%b{})')
    if not c then return false end
    local function num(k) return tonumber(c:match('"' .. k .. '":([%d.]+)')) end
    local n = { aqi = num("european_aqi"), pm25 = num("pm2_5"), pm10 = num("pm10"), no2 = num("nitrogen_dioxide"), o3 = num("ozone") }
    if not n.aqi then return false end
    cur = n
    hourly = {}
    local list = s:match('"hourly":%b{}')
    list = list and list:match('"european_aqi":(%b[])')
    if list then
        for v in list:gmatch("[^%[%],]+") do hourly[#hourly + 1] = tonumber(v) or false end
    end
    return true
end

local function load()
    local ok, s = pcall(resources.read_file, CACHE)
    if not ok or not s then return end
    at = tonumber(s:match("^at=(%d+)"))
    parse(s)
end

local function fetch()
    if not (http and wifi) or wifi.get_status() ~= 3 then
        status = "Wi-Fi не під'єднано"
        return
    end
    collectgarbage()
    local ok, res = pcall(http.execute, { url = URL })
    if not (ok and res.code == 200 and res.response and parse(res.response)) then
        status = "Не вдалося завантажити"
        return
    end
    at, status = os.time(), nil
    pcall(resources.write_file, CACHE, "at=" .. at .. "\n" .. res.response)
end

function lilka.init()
    W, H = display.width, display.height
    -- Застосунок стартує на весь екран, тож display.height = 240 навіть з fullscreen = false
    if not lilka.fullscreen and H > 216 then H = H - 24 end
    C.bg = rgb(10, 14, 24)
    C.text = rgb(235, 240, 255)
    C.gray = rgb(130, 140, 165)
    C.grid = rgb(30, 36, 54)
    C.lv, C.lv_dim, C.haze = {}, {}, {}
    for i, l in ipairs(LEVELS) do
        local c = l[3]
        C.lv[i] = rgb(c[1], c[2], c[3])
        C.lv_dim[i] = rgb(c[1] * 0.3, c[2] * 0.3, c[3] * 0.3)
        C.haze[i] = rgb(c[1] * 0.18 + 10, c[2] * 0.18 + 14, c[3] * 0.18 + 24)
    end
    for k = 1, 90 do haze[k] = { rnd() * W, rnd() * H, 4 + rnd() * 10, 0.5 + rnd() * 2.5 } end
    load()
    if controller then fetch(); next_fetch = REFRESH
    elseif not (at and os.time() - at < REFRESH) then next_fetch = 1 end
end

function lilka.update(delta)
    t = t + delta
    for _, p in ipairs(haze) do
        p[1] = p[1] + p[3] * delta
        p[2] = p[2] + sin(t * 0.5 + p[4] * 3) * 3 * delta
        if p[1] > W + 4 then p[1], p[2] = -4, rnd() * H end
    end
    if controller then
        local s = controller.get_state()
        if s.start.just_pressed then util.exit() end
        if s.a.just_pressed then fetch(); next_fetch = REFRESH end
    end
    if http and wifi then
        next_fetch = next_fetch - delta
        if next_fetch <= 0 then
            next_fetch = REFRESH
            fetch()
        end
    end
end

local function tile(x, y, w, label, v, unit)
    display.fill_rect(x, y, w, 34, C.grid)
    text(label, x + 5, y + 11, C.gray, "5x7")
    text(v and string.format(v < 10 and "%.1f" or "%.0f", v) or "-", x + 5, y + 28, C.text, "9x15")
    text(unit, x + w - 4 - #unit * 5, y + 11, C.gray, "5x7")
end

function lilka.draw()
    display.fill_screen(C.bg)
    local aqi = cur.aqi
    local lv = aqi and level(aqi) or 1
    -- Серпанок: кількість частинок залежить від PM2.5
    local n = aqi and clamp(floor((cur.pm25 or 0) * 2.2), 4, #haze) or 0
    for k = 1, n do
        local p = haze[k]
        display.fill_rect(floor(p[1]), floor(p[2]), 3, 2, C.haze[lv])
    end

    text("Повітря", 6, 14, C.text, "8x13")
    text(PLACE, 68, 13, C.gray, "6x12")
    local note
    if status and controller then note = status
    elseif at then note = "оновлено " .. os.date("%H:%M", at)
    else note = "відкрийте як застосунок" end
    text(note, W - 6 - utf8.len(note) * 6, 13, status and C.lv[5] or C.gray, "6x12")

    if not aqi then
        text("Немає даних", 10, 80, C.text, "9x15")
        text("Відкрийте wallpaper.lua", 10, 100, C.gray, "6x12")
        text("як застосунок з Wi-Fi", 10, 114, C.gray, "6x12")
        return
    end

    -- Велике коло з індексом
    local cx, cy = 50, 66
    local pulse = floor(2 * sin(t * 1.5))
    display.fill_circle(cx, cy, 38 + pulse, C.lv_dim[lv])
    display.fill_circle(cx, cy, 31, C.lv[lv])
    display.fill_circle(cx, cy, 27, C.bg)
    local s = tostring(floor(aqi + 0.5))
    text(s, cx - #s * 10 // 2, cy + 7, C.text, "10x20")
    text("AQI", cx - 7, cy + 18, C.gray, "5x7")
    text(LEVELS[lv][2], 100, 46, C.lv[lv], "10x20")
    text("європейський індекс", 100, 62, C.gray, "6x12")

    local tw = (W - 100 - 6 - 6) // 2
    tile(100, 70, tw, "PM2.5", cur.pm25, "мкг")
    tile(100 + tw + 6, 70, tw, "PM10", cur.pm10, "мкг")
    tile(100, 108, tw, "NO2", cur.no2, "мкг")
    tile(100 + tw + 6, 108, tw, "O3", cur.o3, "мкг")

    -- Графік індексу: вчора й сьогодні по годинах
    local gx, gy, gw, gh = 8, 158, W - 16, 42
    local m = #hourly
    if m > 1 then
        local hi = 60
        for _, v in ipairs(hourly) do if v then hi = max(hi, v) end end
        for k, l in ipairs(LEVELS) do -- лінії меж
            if l[1] < hi then display.fill_rect(gx, floor(gy + gh - l[1] / hi * gh), gw, 1, C.lv_dim[k]) end
        end
        local now_h = 24 + os.date("*t").hour
        local bw = gw / m
        for k, v in ipairs(hourly) do
            if v then
                local bh = max(1, floor(v / hi * gh))
                local c = C.lv[level(v)]
                if k - 1 > now_h then c = C.lv_dim[level(v)] end -- прогноз тьмяніший
                display.fill_rect(floor(gx + (k - 1) * bw), gy + gh - bh, max(1, floor(bw) - 1), bh, c)
            end
        end
        local nx = floor(gx + (now_h + 0.5) * bw)
        display.fill_rect(nx, gy - 4, 1, gh + 6, C.text)
        text("вчора", gx, gy + gh + 11, C.gray, "5x7")
        text("сьогодні", floor(gx + gw / 2), gy + gh + 11, C.gray, "5x7")
        text("зараз", min(nx - 12, W - 30), gy - 6, C.text, "5x7")
    end
end
