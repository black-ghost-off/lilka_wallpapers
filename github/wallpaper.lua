-- Сітка внесків GitHub за останні пів року, як на сторінці профілю.
-- Дані: github-contributions-api.jogruber.de (без ключа API).
-- Застосунок завантажує дані в github.txt (потрібен Wi-Fi), шпалери лише читають цей файл.
-- Застосунок: A — оновити, START — вихід.

lilka.fullscreen = false

local USER = "torvalds" -- ваш логін на GitHub
local CACHE = "github.txt"
local REFRESH = 3 * 3600
local WEEKS = 24

local sin, floor = math.sin, math.floor
local function min(a, b) if a < b then return a end return b end
local function max(a, b) if a > b then return a end return b end
local function clamp(x, a, b) return min(b, max(a, x)) end
local function rgb(r, g, b) return display.color565(floor(clamp(r, 0, 255)), floor(clamp(g, 0, 255)), floor(clamp(b, 0, 255))) end

local W, H
local t = 0
local data, status, stats

local LEVELS = { { 22, 27, 34 }, { 14, 68, 41 }, { 0, 109, 50 }, { 38, 166, 65 }, { 57, 211, 83 } }

local function compute_stats(d)
    local n = #d.counts
    local s = { best = 0, best_i = 1, streak = 0 }
    for i = 1, n do
        if d.counts[i] > s.best then s.best, s.best_i = d.counts[i], i end
    end
    local i = n
    if d.counts[i] == 0 then i = i - 1 end
    while i >= 1 and d.counts[i] > 0 do
        s.streak = s.streak + 1
        i = i - 1
    end
    return s
end

local function parse_cache(text)
    if not text then return nil end
    local d = {}
    for k, v in text:gmatch("(%w+)=([^\n]*)") do d[k] = v end
    if not (d.at and d.levels and d.counts and d.start) then return nil end
    d.at, d.total = tonumber(d.at), tonumber(d.total) or 0
    local levels, counts = {}, {}
    for c in d.levels:gmatch("%d") do levels[#levels + 1] = tonumber(c) end
    for c in d.counts:gmatch("%d+") do counts[#counts + 1] = tonumber(c) end
    if #levels == 0 or #levels ~= #counts then return nil end
    d.levels, d.counts = levels, counts
    local y, m, dd = d.start:match("(%d+)-(%d+)-(%d+)")
    local ts0 = os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(dd), hour = 12 })
    local n = #levels
    local wday_last = (os.date("*t", ts0).wday - 1 + n - 1) % 7
    d.first = n - wday_last - (WEEKS - 1) * 7
    -- Підписи місяців над тижнями, що їх починають
    d.months = {}
    for c = 0, WEEKS - 1 do
        local i = d.first + c * 7
        if i >= 1 then
            local dt = os.date("*t", ts0 + (i - 1) * 86400)
            if dt.day <= 7 then d.months[#d.months + 1] = { c, dt.month } end
        end
    end
    return d
end

local function load()
    local ok, text = pcall(resources.read_file, CACHE)
    data = ok and parse_cache(text) or nil
    stats = data and compute_stats(data) or nil
end

local function download()
    if not (http and wifi) or wifi.get_status() ~= 3 then
        status = "Wi-Fi не під'єднано"
        return
    end
    collectgarbage()
    local ok, res = pcall(http.execute, { url = "https://github-contributions-api.jogruber.de/v4/" .. USER .. "?y=last" })
    local body = ok and res.code == 200 and res.response
    if not body then
        status = "Не вдалося завантажити"
        return
    end
    local levels, counts, start = {}, {}, nil
    for date, count, level in body:gmatch('"date":"([%d-]+)","count":(%d+),"level":(%d)') do
        start = start or date
        counts[#counts + 1] = count
        levels[#levels + 1] = level
    end
    if #levels == 0 then
        status = "Не вдалося розібрати відповідь"
        return
    end
    local text = table.concat({
        "user=" .. USER, "at=" .. os.time(), "total=" .. (body:match('"lastYear":(%d+)') or "0"),
        "start=" .. start, "levels=" .. table.concat(levels), "counts=" .. table.concat(counts, ","),
    }, "\n")
    pcall(resources.write_file, CACHE, text)
    load()
    status = nil
end

function lilka.init()
    W, H = display.width, display.height
    -- Застосунок стартує на весь екран, тож display.height = 240 навіть з fullscreen = false
    if not lilka.fullscreen and H > 216 then H = H - 24 end
    load()
    if controller and (not data or data.user ~= USER or os.time() - data.at > REFRESH) then download() end
end

function lilka.update(delta)
    t = t + delta
    if controller then
        local st = controller.get_state()
        if st.a.just_pressed then download() end
        if st.start.just_pressed then util.exit() end
    end
end

local function text(x, y, s, c, font)
    display.set_font(font or "6x13")
    display.set_text_size(1)
    display.set_text_color(c)
    display.set_cursor(floor(x), floor(y))
    display.print(s)
end

local MONTHS = { "січ", "лют", "бер", "кві", "тра", "чер", "лип", "сер", "вер", "жов", "лис", "гру" }
local DOWS = { [1] = "Пн", [3] = "Ср", [5] = "Пт" }

function lilka.draw()
    display.fill_screen(rgb(13, 17, 23))
    local white, grey = rgb(230, 237, 243), rgb(125, 133, 144)
    if not data then
        text(10, 30, "@" .. USER, white, "8x13")
        text(10, 70, "Немає даних", white, "9x15")
        text(10, 92, status or "Відкрийте wallpaper.lua", grey, "6x12")
        text(10, 106, "як застосунок з Wi-Fi", grey, "6x12")
        return
    end

    text(10, 20, "@" .. data.user, white, "8x13")
    local total = string.format("%d внесків за рік", data.total)
    text(W - 10 - utf8.len(total) * 6, 20, total, grey, "6x12")

    local n, first = #data.levels, data.first

    local cell, gap = 8, 2
    local gw = WEEKS * (cell + gap)
    local x0 = W - gw - 10
    local y0 = 52
    local sweep = (t * 6) % (WEEKS + 12)
    for c = 0, WEEKS - 1 do
        for r = 0, 6 do
            local i = first + c * 7 + r
            if i >= 1 and i <= n then
                local lv = data.levels[i]
                local col = LEVELS[lv + 1]
                local glow = max(0, 1 - math.abs(c - sweep) / 3) * 0.35
                local x, y = x0 + c * (cell + gap), y0 + r * (cell + gap)
                if lv > 0 then
                    display.fill_rect(x + 1, y + 1, cell, cell, rgb(col[1] * 0.5, col[2] * 0.5, col[3] * 0.5))
                    display.fill_rect(x, y, cell, cell, rgb(col[1] + 120 * glow, col[2] + 120 * glow, col[3] + 120 * glow))
                else
                    display.fill_rect(x, y, cell, cell, rgb(col[1] + 40 * glow, col[2] + 40 * glow, col[3] + 40 * glow))
                end
                if i == n and sin(t * 4) > 0 then
                    display.draw_rect(x - 1, y - 1, cell + 2, cell + 2, white)
                end
            end
        end
    end
    for _, m in ipairs(data.months) do
        text(x0 + m[1] * (cell + gap), y0 - 4, MONTHS[m[2]], grey, "5x7")
    end
    for r, name in pairs(DOWS) do
        text(x0 - 14, y0 + r * (cell + gap) + 7, name, grey, "5x7")
    end

    -- Легенда
    local ly = y0 + 7 * (cell + gap) + 8
    local lx = x0 + gw - 2 - 30 - 5 * (cell + gap) - 4
    text(lx - 29, ly + 7, "Менше", grey, "5x7")
    for lv = 0, 4 do
        local col = LEVELS[lv + 1]
        display.fill_rect(lx + lv * (cell + gap), ly, cell, cell, rgb(col[1], col[2], col[3]))
    end
    text(lx + 5 * (cell + gap) + 2, ly + 7, "Більше", grey, "5x7")

    -- Підсумки
    local sy = H - 46
    display.fill_rect(6, sy, W - 12, 40, rgb(22, 27, 34))
    local cw = (W - 12) / 3
    local items = {
        { string.format("%d", stats.streak), "днів поспіль" },
        { string.format("%d", stats.best), "найкращий день" },
        { string.format("%d", data.counts[n]), "сьогодні" },
    }
    for k, it in ipairs(items) do
        local cx = 6 + (k - 0.5) * cw
        text(cx - utf8.len(it[1]) * 5, sy + 20, it[1], rgb(57, 211, 83), "10x20")
        text(cx - utf8.len(it[2]) * 2.5, sy + 33, it[2], grey, "5x7")
    end
    if status and controller then text(10, sy - 4, status, rgb(255, 120, 100), "6x12") end
end
