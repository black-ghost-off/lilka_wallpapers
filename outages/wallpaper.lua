-- Графік відключень світла від YASNO для вашої черги: смуги на сьогодні й завтра,
-- чи є світло зараз і скільки до наступної зміни.
-- Застосунок завантажує графік в outages.txt; шпалери на свіжій Keira оновлюють його самі.
-- Застосунок: A — оновити, START — вихід.

lilka.fullscreen = false

local GROUP = "1.1"          -- ваша черга (підчерга), як на сайті YASNO
local REGION, DSO = 25, 902  -- Київ; Дніпро — 3, 301
local CACHE = "outages.txt"
local REFRESH = 15 * 60
local URL = "https://app.yasno.ua/api/blackout-service/public/shutdowns/regions/" .. REGION .. "/dsos/" .. DSO .. "/planned-outages"

local floor, sin = math.floor, math.sin
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
local raw, at     -- JSON-блок нашої черги та час завантаження
local days = {}   -- days["2026-11-04"] = { status = "...", slots = { {from, to, kind}... } }
local status
local next_fetch = 0
local C = {}

local function parse_day(block)
    if not block then return nil end
    local d = { status = block:match('"status":"(%w+)"') or "", slots = {} }
    local date = block:match('"date":"(%d+%-%d+%-%d+)')
    local list = block:match('"slots":(%b[])')
    if list then
        for obj in list:gmatch("%b{}") do
            local s, e = tonumber(obj:match('"start":(%d+)')), tonumber(obj:match('"end":(%d+)'))
            local kind = obj:match('"type":"(%w+)"') or "Definite"
            if s and e and kind ~= "NotPlanned" then d.slots[#d.slots + 1] = { s, e, kind } end
        end
    end
    return date, d
end

local function apply()
    days = {}
    if not raw then return end
    for _, key in ipairs({ "today", "tomorrow" }) do
        local date, d = parse_day(raw:match('"' .. key .. '":(%b{})'))
        if date then days[date] = d end
    end
end

local function load()
    local ok, s = pcall(resources.read_file, CACHE)
    if not ok or not s then return end
    at = tonumber(s:match("^at=(%d+)"))
    raw = s:match("\n(.*)$")
    apply()
end

local function fetch()
    if not (http and wifi) or wifi.get_status() ~= 3 then
        status = "Wi-Fi не під'єднано"
        return
    end
    collectgarbage()
    local ok, res = pcall(http.execute, { url = URL })
    if not (ok and res.code == 200 and res.response) then
        status = "Не вдалося завантажити"
        return
    end
    local key = '"' .. GROUP:gsub("%.", "%%.") .. '":'
    local p = res.response:find(key)
    local block = p and res.response:match("%b{}", p)
    if not block then
        status = "Немає черги " .. GROUP
        return
    end
    raw, at, status = block, os.time(), nil
    pcall(resources.write_file, CACHE, "at=" .. at .. "\n" .. raw)
    apply()
end

function lilka.init()
    W, H = display.width, display.height
    -- Застосунок стартує на весь екран, тож display.height = 240 навіть з fullscreen = false
    if not lilka.fullscreen and H > 216 then H = H - 24 end
    C.bg = rgb(10, 12, 20)
    C.text = rgb(235, 240, 255)
    C.gray = rgb(130, 140, 165)
    C.on = rgb(255, 210, 70)
    C.on_dim = rgb(60, 52, 20)
    C.off = rgb(230, 60, 70)
    C.maybe = rgb(240, 140, 50)
    C.bar = rgb(40, 120, 70)
    C.grid = rgb(30, 34, 50)
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

local function hm(m)
    m = floor(m) % 1440
    return string.format("%02d:%02d", m // 60, m % 60)
end

local function dur(m)
    m = floor(m)
    if m < 60 then return m .. " хв" end
    if m % 60 == 0 then return (m // 60) .. " год" end
    return (m // 60) .. " год " .. (m % 60) .. " хв"
end

-- Шукає, чи йде відключення в хвилину now і коли наступна зміна (через два дні)
local function state(today, tomorrow, now)
    local list = {}
    if today then for _, s in ipairs(today.slots) do list[#list + 1] = { s[1], s[2], s[3] } end end
    if tomorrow then for _, s in ipairs(tomorrow.slots) do list[#list + 1] = { s[1] + 1440, s[2] + 1440, s[3] } end end
    table.sort(list, function(a, b) return a[1] < b[1] end)
    -- зливаємо суміжні проміжки
    local merged = {}
    for _, s in ipairs(list) do
        local last = merged[#merged]
        if last and s[1] <= last[2] then last[2] = max(last[2], s[2]) else merged[#merged + 1] = { s[1], s[2], s[3] } end
    end
    for _, s in ipairs(merged) do
        if now >= s[1] and now < s[2] then return true, s[2], s[3] end
        if s[1] > now then return false, s[1], s[3] end
    end
    return false, nil
end

local function bulb(x, y, on)
    if on then
        local r = 16 + floor(2 * sin(t * 2))
        display.fill_circle(x, y, r + 6, C.on_dim)
        display.fill_circle(x, y, 13, C.on)
    else
        display.fill_circle(x, y, 13, rgb(60, 64, 80))
        display.draw_line(x - 6, y - 6, x + 6, y + 6, C.off)
        display.draw_line(x - 6, y + 6, x + 6, y - 6, C.off)
    end
    display.fill_rect(x - 6, y + 13, 12, 7, rgb(150, 150, 160))
    display.fill_rect(x - 4, y + 21, 8, 2, rgb(110, 110, 120))
end

local function day_bar(label, d, y, now)
    local x0, w, h = 52, W - 62, 22
    text(label, 6, y + 15, C.gray, "6x12")
    display.fill_rect(x0, y, w, h, C.bar)
    if d then
        for _, s in ipairs(d.slots) do
            local a, b = x0 + s[1] / 1440 * w, x0 + s[2] / 1440 * w
            display.fill_rect(floor(a), y, max(1, floor(b) - floor(a)), h, s[3] == "Definite" and C.off or C.maybe)
        end
        if d.status ~= "ScheduleApplies" and #d.slots == 0 then
            display.fill_rect(x0, y, w, h, C.grid)
            local msg = d.status == "EmergencyShutdowns" and "екстрені відключення" or "графіка ще немає"
            text(msg, x0 + 6, y + 15, C.gray, "6x12")
        end
    else
        display.fill_rect(x0, y, w, h, C.grid)
        text("немає даних", x0 + 6, y + 15, C.gray, "6x12")
    end
    for hr = 0, 24, 3 do
        local x = floor(x0 + hr / 24 * (w - 1))
        display.fill_rect(x, y + h, 1, 3, C.gray)
        if hr % 6 == 0 then text(tostring(hr), x - (hr >= 10 and 6 or 3), y + h + 11, C.gray, "5x7") end
    end
    if now then
        local x = floor(x0 + now / 1440 * w)
        display.fill_rect(x - 1, y - 3, 3, h + 6, C.text)
    end
end

function lilka.draw()
    display.fill_screen(C.bg)
    text("Світло", 6, 14, C.text, "8x13")
    text("черга " .. GROUP, 62, 13, C.gray, "6x12")
    local note
    if status and controller then note = status
    elseif at then note = "оновлено " .. os.date("%H:%M", at)
    else note = "відкрийте як застосунок" end
    text(note, W - 6 - utf8.len(note) * 6, 13, status and C.off or C.gray, "6x12")

    local now_t = os.time()
    local tm = os.date("*t", now_t)
    local now = tm.hour * 60 + tm.min + tm.sec / 60
    local today = days[os.date("%Y-%m-%d", now_t)]
    local tomorrow = days[os.date("%Y-%m-%d", now_t + 86400)]

    -- Головний рядок
    local off, change, kind = state(today, tomorrow, now)
    local sure = kind == "Definite"
    bulb(28, 50, not off)
    local l1, l2
    if not today then
        l1, l2 = "Графік невідомий", raw and "дані застаріли" or "потрібен Wi-Fi"
    elseif today.status == "EmergencyShutdowns" and #today.slots == 0 then
        l1, l2 = "Екстрені відключення", "графіки зараз не діють"
    elseif off then
        l1 = sure and "Світла немає" or "Можливо, немає"
        l2 = change and ("до " .. hm(change) .. ", ще " .. dur(change - now)) or ""
    else
        l1 = "Світло є"
        l2 = change and ((sure and "вимкнуть о " or "можливе з ") .. hm(change) .. (change >= 1440 and " завтра" or "") .. ", через " .. dur(change - now)) or "відключень не заплановано"
    end
    text(l1, 56, 48, off and C.off or C.on, "10x20")
    text(l2, 56, 66, C.text, "6x12")

    day_bar("Сьог.", today, 96, now)
    day_bar("Завтра", tomorrow, 146, nil)

    -- Легенда
    local ly = H - 8
    display.fill_rect(6, ly - 7, 8, 8, C.bar)
    text("є", 18, ly, C.gray, "6x12")
    display.fill_rect(36, ly - 7, 8, 8, C.off)
    text("відключення", 48, ly, C.gray, "6x12")
    display.fill_rect(124, ly - 7, 8, 8, C.maybe)
    text("можливе", 136, ly, C.gray, "6x12")
    text(os.date("%H:%M", now_t), W - 36, ly, C.text, "6x12")
end
