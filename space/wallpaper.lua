-- Космічна погода (NOAA SWPC, без ключа API): геомагнітний індекс Kp за останні дні й прогноз,
-- рівень бурі G0-G5 і чи можна побачити полярне сяйво в Україні. Сяйво над містом росте разом з Kp.
-- Застосунок завантажує дані в space.txt; шпалери на свіжій Keira оновлюють їх самі.
-- Застосунок: A — оновити, START — вихід.

lilka.fullscreen = false

local URL = "https://services.swpc.noaa.gov/products/noaa-planetary-k-index-forecast.json"
local CACHE = "space.txt"
local REFRESH = 60 * 60
local DAYS_BACK = 3 -- скільки днів спостережень показувати

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

local W, H, SKY
local t = 0
local kp = {}     -- { time, value, kind } kind: o — виміряно, e — оцінка, p — прогноз
local at, status
local next_fetch = 0
local stars, city = {}, {}
local C = {}

local function days_from_civil(y, m, d)
    if m <= 2 then y = y - 1 end
    local era = (y >= 0 and y or y - 399) // 400
    local yoe = y - era * 400
    local mp = (m + 9) % 12
    local doy = (153 * mp + 2) // 5 + d - 1
    local doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
    return era * 146097 + doe - 719468
end
local function utc(s)
    local y, mo, d, h = s:match("(%d+)-(%d+)-(%d+)T(%d+)")
    if not y then return nil end
    return days_from_civil(tonumber(y), tonumber(mo), tonumber(d)) * 86400 + tonumber(h) * 3600
end

local function parse(s)
    local list = {}
    for obj in s:gmatch("%b{}") do
        local tm = utc(obj:match('"time_tag":"([^"]+)"') or "")
        local v = tonumber(obj:match('"kp":([%d.]+)'))
        local kind = (obj:match('"observed":"(%a)') or "p")
        if tm and v then list[#list + 1] = { tm, v, kind } end
    end
    if #list < 4 then return false end
    kp = list
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

-- Поточний Kp: останнє виміряне або оцінене значення, що вже настало
local function current()
    local now, best = os.time(), nil
    for _, e in ipairs(kp) do
        if e[1] <= now then best = e end
    end
    return best
end

local function g_scale(v)
    if v >= 9 then return 5 elseif v >= 8 then return 4 elseif v >= 7 then return 3
    elseif v >= 6 then return 2 elseif v >= 5 then return 1 end
    return 0
end

local function kp_col(v)
    if v >= 7 then return C.red elseif v >= 5 then return C.orange elseif v >= 4 then return C.yellow end
    return C.green
end

-- Україна на геомагнітних широтах ~45-48°: сяйво видно на півночі горизонту з Kp 7, високо — з Kp 8-9
local function aurora_text(v)
    if v >= 8 then return "Сяйво: ймовірне по всій Україні"
    elseif v >= 7 then return "Сяйво: можливе низько на півночі"
    elseif v >= 6 then return "Сяйво: лише на фото, на півночі"
    end
    return "Сяйво в Україні: не очікується"
end

function lilka.init()
    W, H = display.width, display.height
    -- Застосунок стартує на весь екран, тож display.height = 240 навіть з fullscreen = false
    if not lilka.fullscreen and H > 216 then H = H - 24 end
    SKY = 112
    C.sky = rgb(4, 6, 18)
    C.text = rgb(235, 240, 255)
    C.gray = rgb(130, 140, 165)
    C.green, C.yellow, C.orange, C.red = rgb(60, 210, 120), rgb(240, 220, 70), rgb(250, 140, 50), rgb(235, 60, 70)
    C.city, C.win = rgb(10, 12, 20), rgb(150, 120, 60)
    C.au = {}
    for k = 0, 7 do -- зелений знизу, фіолетовий вгорі
        local u = k / 7
        C.au[k] = rgb(40 + 140 * u, 220 - 160 * u, 110 + 80 * u)
    end
    for k = 1, 45 do
        local v = 50 + floor(rnd() * 100)
        stars[k] = { floor(rnd() * W), floor(rnd() * (SKY - 20)), rgb(v, v, v + 30) }
    end
    local x = 0
    while x < W do -- силует міста
        local w, h = 8 + floor(rnd() * 16), 6 + floor(rnd() * 22)
        city[#city + 1] = { x, w, h }
        x = x + w
    end
    load()
    if controller then fetch(); next_fetch = REFRESH
    elseif not (at and os.time() - at < REFRESH) then next_fetch = 1 end
end

function lilka.update(delta)
    t = t + delta
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

local function draw_sky(v)
    display.fill_rect(0, 0, W, SKY, C.sky)
    for _, s in ipairs(stars) do display.fill_rect(s[1], s[2], 1, 1, s[3]) end
    -- Завіси сяйва: вертикальні промені, висота й яскравість ростуть з Kp
    local strength = clamp((v - 1) / 7, 0.18, 1)
    local base = SKY - 14
    for x = 0, W - 1, 2 do
        local wave = sin(x * 0.045 + t * 0.7) * 0.5 + sin(x * 0.11 - t * 1.3) * 0.3 + sin(x * 0.023 + t * 0.4) * 0.2
        local h = floor((0.35 + 0.65 * (wave * 0.5 + 0.5)) * strength * (SKY - 22))
        if h > 2 then
            local y0 = base - h + floor(sin(x * 0.03 + t) * 4)
            local seg = max(1, h // 8)
            for k = 0, 7 do
                local yy = y0 + (7 - k) * seg
                if yy < base then display.fill_rect(x, yy, 2, min(seg, base - yy), C.au[k]) end
            end
        end
    end
    for _, b in ipairs(city) do
        display.fill_rect(b[1], SKY - b[3], b[2], b[3], C.city)
        if b[3] > 12 then
            for wy = SKY - b[3] + 3, SKY - 4, 5 do
                for wx = b[1] + 2, b[1] + b[2] - 3, 4 do
                    if (wx * 7 + wy * 13) % 5 == 0 then display.fill_rect(wx, wy, 1, 2, C.win) end
                end
            end
        end
    end
end

function lilka.draw()
    display.fill_screen(0)
    local e = current()
    local v = e and e[2] or 0
    draw_sky(v)

    text("Космічна погода", 4, 13, C.text, "8x13")
    local note
    if status and controller then note = status
    elseif at then note = os.date("%H:%M", at)
    else note = "немає даних" end
    text(note, W - 4 - utf8.len(note) * 6, 12, status and C.red or C.gray, "6x12")

    -- Kp і рівень бурі
    local y = SKY + 2
    if e then
        local g = g_scale(v)
        text(string.format("Kp %.1f", v), 6, y + 18, kp_col(v), "10x20")
        text(g > 0 and ("буря G" .. g) or "спокійно", 84, y + 12, kp_col(v), "6x12")
        text(aurora_text(v), 84, y + 24, C.gray, "6x12")
    else
        text("Відкрийте wallpaper.lua як застосунок з Wi-Fi", 6, y + 16, C.gray, "6x12")
    end

    -- Стовпчики Kp: останні дні виміряно, далі прогноз (тьмяніше)
    local now = os.time()
    local from = now - DAYS_BACK * 86400
    local list = {}
    for _, k in ipairs(kp) do if k[1] >= from then list[#list + 1] = k end end
    local gx, gy, gw, gh = 6, y + 34, W - 12, H - y - 34 - 12
    local n = #list
    if n > 0 then
        local bw = gw / n
        for lvl = 3, 9, 3 do display.fill_rect(gx, floor(gy + gh - lvl / 9 * gh), gw, 1, rgb(26, 30, 46)) end
        display.fill_rect(gx, floor(gy + gh - 5 / 9 * gh), gw, 1, rgb(70, 40, 30)) -- поріг бурі
        local now_x
        for i, k in ipairs(list) do
            local bh = max(1, floor(k[2] / 9 * gh))
            local c = kp_col(k[2])
            local x = floor(gx + (i - 1) * bw)
            if k[3] == "p" then
                -- прогноз: лише контур
                display.draw_rect(x, gy + gh - bh, max(2, floor(bw) - 1), bh, c)
            else
                display.fill_rect(x, gy + gh - bh, max(1, floor(bw) - 1), bh, c)
            end
            if k[1] <= now then now_x = x + floor(bw) end
            -- підписи днів опівночі за UTC
            if k[1] % 86400 == 0 then
                text(os.date("%d.%m", k[1]), x, gy + gh + 10, C.gray, "5x7")
            end
        end
        if now_x then display.fill_rect(now_x, gy - 2, 1, gh + 4, C.text) end
    end
end
