-- Курс гривні: долар і євро за даними НБУ з графіком за 30 днів (без ключа API).
-- Застосунок завантажує курси в currency.txt (потрібен Wi-Fi), шпалери лише читають цей файл.
-- Застосунок: A — оновити, START — вихід.

lilka.fullscreen = false

local CODES = { "USD", "EUR" }
local DAYS = 30
local CACHE = "currency.txt"
local REFRESH = 3 * 3600

local sin, floor = math.sin, math.floor
local function min(a, b) if a < b then return a end return b end
local function max(a, b) if a > b then return a end return b end
local function clamp(x, a, b) return min(b, max(a, x)) end
local function rgb(r, g, b) return display.color565(floor(clamp(r, 0, 255)), floor(clamp(g, 0, 255)), floor(clamp(b, 0, 255))) end

local W, H
local t = 0
local data, status

local BG = { 12, 16, 28 }
local COLORS = { USD = { 80, 200, 120 }, EUR = { 90, 150, 255 } }

local function parse_cache(text)
    if not text then return nil end
    local d = { rates = {} }
    for k, v in text:gmatch("(%w+)=([^\n]*)") do
        if k == "at" then
            d.at = tonumber(v)
        elseif k == "date" then
            d.date = v
        else
            local list = {}
            for x in v:gmatch("[^,]+") do list[#list + 1] = tonumber(x) end
            if #list > 0 then d.rates[k] = list end
        end
    end
    if not d.at then return nil end
    for _, c in ipairs(CODES) do
        if not d.rates[c] then return nil end
    end
    return d
end

local function load()
    local ok, text = pcall(resources.read_file, CACHE)
    data = ok and parse_cache(text) or nil
end

local function fetch(code, from, to)
    local url = "https://bank.gov.ua/NBU_Exchange/exchange_site?start=" .. from .. "&end=" .. to
        .. "&valcode=" .. code:lower() .. "&sort=exchangedate&order=asc&json"
    local ok, res = pcall(http.execute, { url = url })
    if not (ok and res.code == 200 and res.response) then return nil end
    local rates, last = {}, nil
    for obj in res.response:gmatch("%b{}") do
        local r = obj:match('"rate":([%d.]+)')
        local d = obj:match('"exchangedate":"([^"]+)"')
        if r then rates[#rates + 1] = r; last = d end
    end
    if #rates < 2 then return nil end
    return rates, last
end

local function download()
    if not (http and wifi) or wifi.get_status() ~= 3 then
        status = "Wi-Fi не під'єднано"
        return
    end
    collectgarbage()
    local now = os.time()
    local from = os.date("%Y%m%d", now - DAYS * 86400)
    local to = os.date("%Y%m%d", now + 86400)
    local lines = { "at=" .. now }
    for _, c in ipairs(CODES) do
        local rates, last = fetch(c, from, to)
        if not rates then
            status = "Не вдалося завантажити"
            return
        end
        lines[#lines + 1] = c .. "=" .. table.concat(rates, ",")
        lines[#lines + 1] = "date=" .. last
    end
    pcall(resources.write_file, CACHE, table.concat(lines, "\n"))
    load()
    status = nil
end

function lilka.init()
    W, H = display.width, display.height
    -- Застосунок стартує на весь екран, тож display.height = 240 навіть з fullscreen = false
    if not lilka.fullscreen and H > 216 then H = H - 24 end
    load()
    if controller and (not data or os.time() - data.at > REFRESH) then download() end
end

function lilka.update(delta)
    t = t + delta
    if controller then
        local st = controller.get_state()
        if st.a.just_pressed then download() end
        if st.start.just_pressed then util.exit() end
    end
end

local function text(x, y, s, c, font, size)
    display.set_font(font or "6x13")
    display.set_text_size(size or 1)
    display.set_text_color(c)
    display.set_cursor(floor(x), floor(y))
    display.print(s)
end

local function card(code, rates, x, y, w, h)
    local col = COLORS[code] or { 220, 220, 220 }
    local c = rgb(col[1], col[2], col[3])
    local dim = rgb(col[1] * 0.25 + BG[1], col[2] * 0.25 + BG[2], col[3] * 0.25 + BG[3])
    display.fill_rect(x, y, w, h, rgb(20, 26, 42))
    display.fill_rect(x, y, 3, h, c)

    local n = #rates
    local last, prev = rates[n], rates[n - 1]
    local diff = last - prev
    text(x + 10, y + 16, code, c, "8x13")
    text(x + 10, y + 46, string.format("%.2f", last), rgb(240, 244, 255), "10x20", 2)

    local up = diff >= 0
    local dc = up and rgb(255, 110, 100) or rgb(90, 220, 130)
    local ax, ay = x + 14, y + 60
    if up then
        display.fill_triangle(ax - 4, ay, ax + 4, ay, ax, ay - 7, dc)
    else
        display.fill_triangle(ax - 4, ay - 7, ax + 4, ay - 7, ax, ay, dc)
    end
    text(x + 22, y + 60, string.format("%.2f", diff < 0 and -diff or diff), dc, "6x12")

    -- Графік за 30 днів: заливка під лінією, лінія, мітка останнього дня
    local lo, hi = rates[1], rates[1]
    for _, r in ipairs(rates) do lo = min(lo, r); hi = max(hi, r) end
    if hi - lo < 0.01 then hi = lo + 0.01 end
    local gx, gy, gw, gh = x + 130, y + 13, w - 140, h - 25
    local function px(i) return gx + (i - 1) / (n - 1) * gw end
    local function py(r) return gy + gh - (r - lo) / (hi - lo) * gh end
    local reveal = min(n, 2 + floor(t * 20))
    for i = 2, reveal do
        local x0, y0, x1, y1 = px(i - 1), py(rates[i - 1]), px(i), py(rates[i])
        display.fill_triangle(floor(x0), floor(y0), floor(x1), floor(y1), floor(x0), gy + gh, dim)
        display.fill_triangle(floor(x1), floor(y1), floor(x1), gy + gh, floor(x0), gy + gh, dim)
    end
    for i = 2, reveal do
        display.draw_line(floor(px(i - 1)), floor(py(rates[i - 1])), floor(px(i)), floor(py(rates[i])), c)
        display.draw_line(floor(px(i - 1)), floor(py(rates[i - 1])) - 1, floor(px(i)), floor(py(rates[i])) - 1, c)
    end
    if reveal == n then
        local lx, ly = floor(px(n)), floor(py(last))
        local pulse = floor(3 + 2 * (0.5 + 0.5 * sin(t * 4)))
        display.draw_circle(lx, ly, pulse + 1, c)
        display.fill_circle(lx, ly, 2, rgb(255, 255, 255))
    end
    text(gx, y + h - 3, string.format("%.2f", lo), rgb(120, 130, 155), "5x7")
    text(gx, y + 10, string.format("%.2f", hi), rgb(120, 130, 155), "5x7")
end

function lilka.draw()
    display.fill_screen(rgb(BG[1], BG[2], BG[3]))
    text(10, 18, "Курс НБУ", rgb(240, 244, 255), "8x13")
    if data then
        local note = data.date or ""
        text(W - 10 - utf8.len(note) * 6, 18, note, rgb(150, 160, 185), "6x12")
        local ch = floor((H - 34) / #CODES)
        for i, c in ipairs(CODES) do
            card(c, data.rates[c], 6, 26 + (i - 1) * ch, W - 12, ch - 6)
        end
        if status and controller then text(10, H - 4, status, rgb(255, 120, 100), "6x12") end
    else
        text(10, 70, "Немає даних", rgb(240, 244, 255), "9x15")
        text(10, 92, status or "Відкрийте wallpaper.lua", rgb(150, 160, 185), "6x12")
        text(10, 106, "як застосунок з Wi-Fi", rgb(150, 160, 185), "6x12")
    end
end
