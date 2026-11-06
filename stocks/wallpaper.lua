-- Акції: ціна, зміна й графік за обраний період (Yahoo Finance, без ключа API).
-- Застосунок завантажує дані в stocks.txt (потрібен Wi-Fi); шпалери на свіжій Keira
-- оновлюють їх самі, по одному тікеру за раз. Обраний період зберігається там само.
-- Застосунок: ← → — період, A — оновити, START — вихід.

lilka.fullscreen = false

-- Тікери Yahoo Finance: ^GSPC — S&P 500, ^IXIC — Nasdaq, AAPL, NVDA, MSFT, TSLA...
local SYMBOLS = { "^GSPC", "AAPL", "NVDA" }
local NAMES = { ["^GSPC"] = "S&P 500", ["^IXIC"] = "NASDAQ", ["^DJI"] = "DOW" }
local CACHE = "stocks.txt"
local PERIOD = "1mo"   -- типовий період, поки його не змінили стрілками

-- range/interval для Yahoo; keep — скільки останніх точок лишити; refresh — секунд між оновленнями
local PERIODS = {
    { key = "1h",  label = "1 год",   range = "1d",  interval = "2m",  keep = 30, refresh = 2 * 60 },
    { key = "1d",  label = "день",    range = "1d",  interval = "5m",  refresh = 5 * 60 },
    { key = "5d",  label = "5 днів",  range = "5d",  interval = "30m", refresh = 15 * 60 },
    { key = "1mo", label = "місяць",  range = "1mo", interval = "1d",  refresh = 15 * 60 },
    { key = "6mo", label = "6 міс",   range = "6mo", interval = "1d",  refresh = 60 * 60 },
    { key = "1y",  label = "рік",     range = "1y",  interval = "1wk", refresh = 60 * 60 },
    { key = "5y",  label = "5 років", range = "5y",  interval = "1mo", refresh = 6 * 60 * 60 },
}
local API = "https://query2.finance.yahoo.com/v8/finance/chart/"

local sin, floor = math.sin, math.floor
local function min(a, b) if a < b then return a end return b end
local function max(a, b) if a > b then return a end return b end
local function clamp(x, a, b) return min(b, max(a, x)) end
local function rgb(r, g, b) return display.color565(floor(clamp(r, 0, 255)), floor(clamp(g, 0, 255)), floor(clamp(b, 0, 255))) end

local W, H
local t = 0
local data = {}   -- data[sym] = { closes = { база, ... }, name = "Apple Inc.", cur = "USD", open_at, close_at }
local at, status
local period = 1
local next_sym, next_fetch = 1, 1.5

local BG = { 12, 16, 28 }
local PALETTE = { { 90, 150, 255 }, { 230, 230, 240 }, { 120, 220, 120 }, { 250, 170, 60 }, { 200, 120, 255 } }

local function label(sym) return NAMES[sym] or sym end

local function find_period(key)
    for i, p in ipairs(PERIODS) do if p.key == key then return i end end
end
period = find_period(PERIOD) or 4
local function P() return PERIODS[period] end

local function save()
    local lines = { "at=" .. (at or 0), "period=" .. P().key }
    for _, s in ipairs(SYMBOLS) do
        local d = data[s]
        if d then
            lines[#lines + 1] = s .. "=" .. table.concat(d.closes, ",")
            lines[#lines + 1] = s .. "#" .. (d.name or "") .. "|" .. (d.cur or "") .. "|" .. (d.open_at or 0) .. "|" .. (d.close_at or 0)
        end
    end
    pcall(resources.write_file, CACHE, table.concat(lines, "\n"))
end

local function load()
    local ok, text = pcall(resources.read_file, CACHE)
    if not ok or not text then return end
    for line in text:gmatch("[^\n]+") do
        local k, v = line:match("^([^=#]+)=(.*)$")
        if k == "at" then
            at = tonumber(v)
        elseif k == "period" then
            period = find_period(v) or period
        elseif k then
            local list = {}
            for x in v:gmatch("[^,]+") do list[#list + 1] = tonumber(x) end
            if #list > 1 then
                data[k] = data[k] or {}
                data[k].closes = list
            end
        else
            local s, name, cur, o, c = line:match("^([^#]+)#([^|]*)|([^|]*)|(%d*)|(%d*)$")
            if s and data[s] then
                data[s].name, data[s].cur = name, cur
                data[s].open_at, data[s].close_at = tonumber(o), tonumber(c)
            end
        end
    end
end

local function fetch(sym)
    if not (http and wifi) or wifi.get_status() ~= 3 then
        status = "Wi-Fi не під'єднано"
        return false
    end
    collectgarbage()
    local p = P()
    local url = API .. sym:gsub("%^", "%%5E") .. "?range=" .. p.range .. "&interval=" .. p.interval
    local ok, res = pcall(http.execute, { url = url })
    if not (ok and res.code == 200 and res.response) then
        status = "Не вдалося завантажити"
        return false
    end
    local body = res.response
    local list = {}
    local closes = body:match('"close":(%b[])')
    if closes then
        for v in closes:gmatch("[^%[%],]+") do
            local n = tonumber(v)
            if n then list[#list + 1] = n end -- null (свято, пауза) пропускаємо
        end
    end
    -- Поточна ціна точніша за останню свічку, поки біржа відкрита
    local price = tonumber(body:match('"regularMarketPrice":([%d.]+)'))
    if price and #list > 0 then list[#list] = price end
    if p.keep and #list > p.keep then
        local cut = {}
        for k = #list - p.keep + 1, #list do cut[#cut + 1] = list[k] end
        list = cut
    end
    if #list < 2 then
        status = "Незрозуміла відповідь"
        return false
    end
    -- Перша точка — база для зміни: закриття перед періодом (або початок години)
    local base = not p.keep and tonumber(body:match('"chartPreviousClose":([%d.]+)'))
    if base then table.insert(list, 1, base) end
    for k, v in ipairs(list) do list[k] = tonumber(string.format("%.2f", v)) end
    local reg = body:match('"regular":(%b{})') or ""
    data[sym] = {
        closes = list,
        name = (body:match('"shortName":"([^"]*)"') or ""):gsub("|", " "),
        cur = body:match('"currency":"(%a+)"') or "",
        open_at = tonumber(reg:match('"start":(%d+)')),
        close_at = tonumber(reg:match('"end":(%d+)')),
    }
    at, status = os.time(), nil
    save()
    return true
end

local function fetch_all()
    for _, s in ipairs(SYMBOLS) do
        if not fetch(s) then break end
    end
end

function lilka.init()
    W, H = display.width, display.height
    -- Застосунок стартує на весь екран, тож display.height = 240 навіть з fullscreen = false
    if not lilka.fullscreen and H > 216 then H = H - 24 end
    load()
    if controller then
        fetch_all()
        next_fetch = P().refresh
    end
end

-- Новий період: старі дані вже не підходять, тож завантажуємо тікери наново по одному
local function switch(d)
    period = (period - 1 + d) % #PERIODS + 1
    data, at, status, t = {}, nil, nil, 0
    save()
    next_sym, next_fetch = 1, 0
end

function lilka.update(delta)
    t = t + delta
    if controller then
        local st = controller.get_state()
        if st.a.just_pressed then fetch_all(); next_fetch = P().refresh end
        if st.right.just_pressed then switch(1) end
        if st.left.just_pressed then switch(-1) end
        if st.start.just_pressed then util.exit() end
    end
    -- Свіжа Keira: шпалери теж оновлюють тікери по черзі
    if http and wifi then
        next_fetch = next_fetch - delta
        if next_fetch <= 0 then
            local refresh = P().refresh
            if next_sym > 1 or not (at and os.time() - at < refresh) then
                fetch(SYMBOLS[next_sym])
                next_sym = next_sym % #SYMBOLS + 1
                -- у застосунку кадр усе одно чекає на мережу, тож без пауз між тікерами
                next_fetch = next_sym == 1 and refresh or (controller and 0 or 2)
            else
                next_fetch = refresh - (os.time() - at)
            end
        end
    end
end

local function text(x, y, s, c, font, size)
    display.set_font(font or "6x13")
    display.set_text_size(size or 1)
    display.set_text_color(c)
    display.set_cursor(floor(x), floor(y))
    display.print(s)
end

local function fmt(p)
    if p >= 10000 then
        local s = string.format("%.0f", p)
        return (s:reverse():gsub("(%d%d%d)", "%1 "):reverse():gsub("^ ", ""))
    end
    return string.format("%.2f", p)
end

local function card(sym, k, x, y, w, h)
    local col = PALETTE[(k - 1) % #PALETTE + 1]
    local c = rgb(col[1], col[2], col[3])
    display.fill_rect(x, y, w, h, rgb(20, 26, 42))
    display.fill_rect(x, y, 3, h, c)
    text(x + 10, y + 14, label(sym), c, "8x13")
    local d = data[sym]
    if not d then
        text(x + 10, y + 32, "немає даних", rgb(120, 130, 155), "6x12")
        return
    end
    local rates = d.closes
    local n = #rates
    local last, prev = rates[n], rates[1]
    local diff = last - prev
    local pct = diff / prev * 100
    if d.name and d.name ~= "" and not NAMES[sym] then
        local name = d.name
        if #name > 14 then name = name:sub(1, 13) .. "." end
        text(x + 14 + #label(sym) * 8, y + 13, name, rgb(120, 130, 155), "5x7")
    end
    text(x + 10, y + 34, fmt(last), rgb(240, 244, 255), "10x20")
    if d.cur ~= "" and not NAMES[sym] then text(x + 14 + #fmt(last) * 10, y + 33, d.cur, rgb(120, 130, 155), "5x7") end

    -- Акції: ріст — зелений, падіння — червоне
    local up = diff >= 0
    local dc = up and rgb(90, 220, 130) or rgb(255, 110, 100)
    local ax, ay = x + 14, y + h - 5
    if up then
        display.fill_triangle(ax - 4, ay, ax + 4, ay, ax, ay - 7, dc)
    else
        display.fill_triangle(ax - 4, ay - 7, ax + 4, ay - 7, ax, ay, dc)
    end
    text(x + 22, y + h - 4, string.format("%.2f (%s%.2f%%)", diff < 0 and -diff or diff, up and "+" or "-", pct < 0 and -pct or pct), dc, "6x12")

    -- Графік за період: заливка під лінією, лінія, пунктир на рівні бази, мітка останньої ціни
    local dim = rgb(col[1] * 0.25 + BG[1], col[2] * 0.25 + BG[2], col[3] * 0.25 + BG[3])
    local lo, hi = rates[1], rates[1]
    for _, r in ipairs(rates) do lo = min(lo, r); hi = max(hi, r) end
    if hi - lo < 0.01 then hi = lo + 0.01 end
    local gx, gy, gw, gh = x + 136, y + 10, w - 146, h - 20
    local function px(i) return gx + (i - 1) / (n - 1) * gw end
    local function py(r) return gy + gh - (r - lo) / (hi - lo) * gh end
    local reveal = min(n, 2 + floor(t / 1.5 * n))  -- графік «малюється» за 1.5 с
    local base = floor(py(prev))
    for bx = gx, gx + gw, 6 do display.fill_rect(floor(bx), base, 3, 1, rgb(80, 90, 115)) end
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
    text(gx, y + h - 2, fmt(lo), rgb(120, 130, 155), "5x7")
    text(gx, y + 8, fmt(hi), rgb(120, 130, 155), "5x7")
end

-- Чи відкрита біржа: за розкладом сьогоднішньої сесії з відповіді Yahoo
local function market()
    local d = data[SYMBOLS[1]]
    if not (d and d.open_at and d.close_at) then return nil end
    local now = os.time()
    if now >= d.open_at and now < d.close_at then return true end
    return false
end

function lilka.draw()
    display.fill_screen(rgb(BG[1], BG[2], BG[3]))
    text(10, 18, "Акції", rgb(240, 244, 255), "8x13")
    local m = market()
    if m ~= nil then
        local mc = m and rgb(90, 220, 130) or rgb(150, 160, 185)
        display.fill_circle(58, 14, 3, mc)
        text(66, 18, m and "біржа відкрита" or "біржа закрита", mc, "6x12")
    end
    local note = ""
    if at then note = os.date(os.time() - at > 12 * 3600 and "%d.%m %H:%M" or "%H:%M", at) end
    text(W - 10 - #note * 6, 18, note, rgb(150, 160, 185), "6x12")
    local pl = P().label
    text(W - 10 - #note * 6 - 10 - utf8.len(pl) * 6, 18, pl, rgb(240, 244, 255), "6x12")
    local any = false
    for _, s in ipairs(SYMBOLS) do if data[s] then any = true end end
    if any then
        local ch = floor((H - 26) / #SYMBOLS)
        for k, s in ipairs(SYMBOLS) do
            card(s, k, 6, 26 + (k - 1) * ch, W - 12, ch - 5)
        end
        if status and controller then text(10, H - 4, status, rgb(255, 120, 100), "6x12") end
    else
        text(10, 70, "Немає даних", rgb(240, 244, 255), "9x15")
        text(10, 92, status or "Відкрийте wallpaper.lua", rgb(150, 160, 185), "6x12")
        text(10, 106, "як застосунок з Wi-Fi", rgb(150, 160, 185), "6x12")
    end
end
