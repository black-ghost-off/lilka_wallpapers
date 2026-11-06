-- Втрати ворога за даними Генштабу ЗСУ (russianwarship.rip, без ключа API):
-- загальні цифри, приріст за добу і графік приросту за 30 днів, що по черзі показує різні категорії.
-- Застосунок завантажує дані в losses.txt; шпалери на свіжій Keira оновлюють їх самі щоранку.
-- Застосунок: ← → — категорія графіка, A — оновити, START — вихід.

lilka.fullscreen = false

local CACHE = "losses.txt"
local URL = "https://russianwarship.rip/api/v2/statistics"
local DAYS = 30        -- днів на графіку
local CHART_TIME = 8   -- секунд на категорію графіка
local RETRY = 20 * 60  -- як часто перевіряти, чи вийшло ранкове зведення

-- Порядок полів у кеші; не міняти без видалення losses.txt
local KEYS = { "personnel_units", "tanks", "armoured_fighting_vehicles", "artillery_systems", "mlrs",
    "aa_warfare_systems", "planes", "helicopters", "uav_systems", "cruise_missiles", "warships_cutters",
    "vehicles_fuel_tanks", "special_military_equip", "submarines" }
local NAMES = { "особовий склад", "танки", "ББМ", "артсистеми", "РСЗВ", "ППО", "літаки", "гелікоптери",
    "БпЛА", "ракети", "кораблі", "автотехніка", "спецтехніка", "підв. човни" }
local GRID = { 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13 } -- категорії в сітці (індекси KEYS)
local CHART = { 1, 9, 4, 12, 3, 2 }                     -- категорії, що по черзі йдуть на графік

local floor = math.floor
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
local function rtext(s, x, y, c, font, cw) text(s, x - utf8.len(s) * cw, y, c, font) end

-- 1601830 -> "1 601 830"
local function group(n)
    local s = tostring(floor(n))
    local out = s:reverse():gsub("(%d%d%d)", "%1 "):reverse()
    return (out:gsub("^ ", ""))
end

local W, H
local t = 0
local recs = {}  -- { date, day, totals = {}, inc = {} }, від старих до нових
local at, status
local retry = 0
local chart, ct = 1, 0
local grow = 0   -- 0..1: числа "набігають" після завантаження
local C = {}

local function parse_api(body)
    local out = {}
    for date, day, stats, inc in body:gmatch('"date":"([%d-]+)","day":(%d+).-"stats":(%b{}),"increase":(%b{})') do
        local r = { date = date, day = tonumber(day), totals = {}, inc = {} }
        for i, k in ipairs(KEYS) do
            r.totals[i] = tonumber(stats:match('"' .. k .. '":(%d+)')) or 0
            r.inc[i] = tonumber(inc:match('"' .. k .. '":(%d+)')) or 0
        end
        out[#out + 1] = r
    end
    table.sort(out, function(a, b) return a.date < b.date end)
    return out
end

local function serialize(list)
    local lines = { "at=" .. at }
    for _, r in ipairs(list) do
        lines[#lines + 1] = r.date .. "|" .. r.day .. "|" .. table.concat(r.totals, ",") .. "|" .. table.concat(r.inc, ",")
    end
    return table.concat(lines, "\n")
end

local function load()
    local ok, s = pcall(resources.read_file, CACHE)
    if not ok or not s then return end
    at = tonumber(s:match("^at=(%d+)"))
    local list = {}
    for date, day, tot, inc in s:gmatch("\n([%d-]+)|(%d+)|([%d,]+)|([%d,]+)") do
        local r = { date = date, day = tonumber(day), totals = {}, inc = {} }
        for v in tot:gmatch("%d+") do r.totals[#r.totals + 1] = tonumber(v) end
        for v in inc:gmatch("%d+") do r.inc[#r.inc + 1] = tonumber(v) end
        if #r.totals == #KEYS and #r.inc == #KEYS then list[#list + 1] = r end
    end
    if #list > 0 then recs = list end
end

local function fetch()
    if not (http and wifi) or wifi.get_status() ~= 3 then
        status = "Wi-Fi не під'єднано"
        return
    end
    if os.time() < 1700000000 then
        status = "Годинник ще не синхронізовано"
        return
    end
    collectgarbage()
    local now = os.time()
    local url = URL .. "?date_from=" .. os.date("%Y-%m-%d", now - DAYS * 86400) .. "&date_to=" .. os.date("%Y-%m-%d", now)
    local ok, res = pcall(http.execute, { url = url })
    if not (ok and res.code == 200 and res.response) then
        status = "Не вдалося завантажити"
        return
    end
    local list = parse_api(res.response)
    res = nil
    collectgarbage()
    if #list == 0 then
        status = "Незрозуміла відповідь"
        return
    end
    local new = not recs[#recs] or recs[#recs].date ~= list[#list].date
    recs, at, status = list, now, nil
    if new then grow = 0 end
    pcall(resources.write_file, CACHE, serialize(list))
end

local function latest() return recs[#recs] end

function lilka.init()
    W, H = display.width, display.height
    -- Застосунок стартує на весь екран, тож display.height = 240 навіть з fullscreen = false
    if not lilka.fullscreen and H > 216 then H = H - 24 end
    C.bg = rgb(10, 12, 18)
    C.panel = rgb(20, 24, 34)
    C.text = rgb(235, 238, 245)
    C.gray = rgb(130, 138, 155)
    C.dim = rgb(60, 66, 82)
    C.yellow = rgb(255, 213, 0)
    C.blue = rgb(40, 120, 230)
    C.bar = rgb(0, 87, 183)
    C.red = rgb(235, 70, 70)
    load()
    if controller then fetch() end
end

function lilka.update(delta)
    t = t + delta
    ct = ct + delta
    grow = min(1, grow + delta / 1.6)
    if controller then
        local s = controller.get_state()
        if s.start.just_pressed then util.exit() end
        if s.a.just_pressed then fetch() end
        if s.right.just_pressed then chart = chart % #CHART + 1; ct = 0 end
        if s.left.just_pressed then chart = (chart - 2) % #CHART + 1; ct = 0 end
    end
    if ct > CHART_TIME then chart = chart % #CHART + 1; ct = 0 end
    -- Зведення виходить зранку: доки його немає, перевіряємо раз на RETRY (на шпалерах — лише свіжа Keira)
    if http and wifi then
        local r = latest()
        local tm = os.date("*t")
        local need = not r or (r.date ~= os.date("%Y-%m-%d") and tm.hour >= 8) or (at and os.time() - at > 12 * 3600)
        if need then
            retry = retry - delta
            if retry <= 0 then
                retry = RETRY
                fetch()
            end
        end
    end
end

local function ease(x) return 1 - (1 - x) ^ 3 end

local function draw_chart(x0, y0, w, h)
    local idx = CHART[chart]
    local n = min(DAYS, #recs)
    local from = #recs - n + 1
    local peak, sum = 1, 0
    for i = from, #recs do
        peak = max(peak, recs[i].inc[idx])
        sum = sum + recs[i].inc[idx]
    end
    text(NAMES[idx] .. " за добу", x0, y0 + 8, C.gray, "5x7")
    rtext("сер. " .. group(sum / max(1, n)) .. "  макс. " .. group(peak), x0 + w, y0 + 8, C.gray, "5x7", 5)
    local gy, gh = y0 + 12, h - 12
    display.fill_rect(x0, gy + gh, w, 1, C.dim)
    local bw = w / DAYS
    local g = ease(clamp(ct / 0.6, 0, 1))
    for i = from, #recs do
        local k = i - from + (DAYS - n)
        local v = recs[i].inc[idx]
        local bh = floor(v / peak * gh * g + 0.5)
        local x = floor(x0 + k * bw)
        local c = (i == #recs) and C.yellow or C.bar
        if bh > 0 then display.fill_rect(x, gy + gh - bh, max(1, floor(bw) - 1), bh, c) end
    end
    -- Індикатор категорій
    for i = 1, #CHART do
        display.fill_rect(x0 + w - (#CHART - i + 1) * 6, y0 + h + 4, 4, 2, i == chart and C.yellow or C.dim)
    end
end

function lilka.draw()
    display.fill_screen(C.bg)
    -- Синьо-жовта смужка зверху
    display.fill_rect(0, 0, W, 2, C.blue)
    display.fill_rect(0, 2, W, 2, C.yellow)

    text("Втрати ворога", 6, 18, C.text, "8x13")
    local r = latest()
    if not r then
        text(status or "Відкрийте wallpaper.lua", 6, 70, C.gray, "6x12")
        if not status then text("як застосунок з Wi-Fi", 6, 84, C.gray, "6x12") end
        return
    end
    local y, m, d = r.date:match("(%d+)-(%d+)-(%d+)")
    local stale = r.date ~= os.date("%Y-%m-%d")
    rtext(d .. "." .. m, W - 6, 17, stale and C.gray or C.yellow, "6x12", 6)
    rtext("день " .. r.day, W - 46, 17, C.gray, "6x12", 6)

    local g = ease(grow)
    -- Особовий склад великим
    text(group(r.totals[1] * g), 6, 44, C.text, "10x20")
    rtext("+" .. group(r.inc[1]), W - 6, 36, C.yellow, "8x13", 8)
    rtext("особовий склад", W - 6, 46, C.gray, "5x7", 5)

    draw_chart(6, 50, W - 12, 52)

    -- Сітка: 2 стовпці по 6 рядків
    local gy0, rh, cw = 120, 15, (W - 12) // 2
    for i, idx in ipairs(GRID) do
        local col, row = (i - 1) // 6, (i - 1) % 6
        local x, yy = 6 + col * cw, gy0 + row * rh
        local on = idx == CHART[chart]
        if on then display.fill_rect(x - 2, yy - 10, cw - 2, rh - 1, C.panel) end
        text(NAMES[idx], x, yy, on and C.text or C.gray, "5x7")
        local inc = r.inc[idx]
        if inc > 0 then text("+" .. group(inc), x + cw - 32, yy, C.yellow, "5x7") end
        rtext(group(r.totals[idx] * g), x + cw - 35, yy + 1, C.text, "6x12", 6)
    end

    local note
    if status and controller then note = status
    elseif at then note = "Генштаб ЗСУ, оновлено " .. os.date("%H:%M", at) end
    if note then text(note, 6, H - 3, status and controller and C.red or C.dim, "5x7") end
end
