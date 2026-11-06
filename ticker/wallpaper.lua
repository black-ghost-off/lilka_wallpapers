-- Криптовалюти: ціна в USDT, зміна й графік за обраний період (Binance, без ключа API).
-- Дані й обраний період зберігаються в ticker.txt. Застосунок оновлює їх при запуску; шпалери
-- на свіжій Keira теж оновлюють, по одній монеті за раз, щоб не зависати надовго.
-- Застосунок: ← → — період, A — оновити, START — вихід.

lilka.fullscreen = false

local COINS = { "BTC", "ETH", "SOL", "BNB" }
local QUOTE = "USDT"
local CACHE = "ticker.txt"
local PERIOD = "1d"        -- типовий період, поки його не змінили стрілками
local API = "https://data-api.binance.vision/api/v3/klines"

-- interval × limit свічок Binance; refresh — секунд між оновленнями
local PERIODS = {
    { key = "1h", label = "1 год",   interval = "1m",  limit = 60, refresh = 60 },
    { key = "1d", label = "24 год",  interval = "30m", limit = 48, refresh = 5 * 60 },
    { key = "1w", label = "тиждень", interval = "4h",  limit = 42, refresh = 30 * 60 },
    { key = "1M", label = "місяць",  interval = "1d",  limit = 30, refresh = 60 * 60 },
    { key = "1y", label = "рік",     interval = "1w",  limit = 52, refresh = 6 * 60 * 60 },
}

local floor, sin = math.floor, math.sin
local function min(a, b) if a < b then return a end return b end
local function max(a, b) if a > b then return a end return b end
local function clamp(x, a, b) return min(b, max(a, x)) end
local function rgb(r, g, b) return display.color565(floor(clamp(r, 0, 255)), floor(clamp(g, 0, 255)), floor(clamp(b, 0, 255))) end

local W, H
local t = 0
local data = {}            -- data[coin] = { closes... }
local at                   -- коли оновлено (os.time)
local status
local next_coin, next_fetch = 1, 1.5
local C = {}

local function find_period(key)
    for i, p in ipairs(PERIODS) do if p.key == key then return i end end
end
local period = find_period(PERIOD) or 2
local function P() return PERIODS[period] end

local function save()
    local lines = { "at=" .. (at or 0), "period=" .. P().key }
    for _, c in ipairs(COINS) do
        if data[c] then lines[#lines + 1] = c .. "=" .. table.concat(data[c], ",") end
    end
    pcall(resources.write_file, CACHE, table.concat(lines, "\n"))
end

local function load()
    local ok, text = pcall(resources.read_file, CACHE)
    if not ok or not text then return end
    for k, v in text:gmatch("(%w+)=([^\n]*)") do
        if k == "at" then
            at = tonumber(v)
        elseif k == "period" then
            period = find_period(v) or period
        else
            local list = {}
            for x in v:gmatch("[^,]+") do list[#list + 1] = x end
            if #list > 1 then data[k] = list end
        end
    end
end

local function fetch(coin)
    if not (http and wifi) or wifi.get_status() ~= 3 then
        status = "Wi-Fi не під'єднано"
        return false
    end
    collectgarbage()
    local p = P()
    local url = API .. "?interval=" .. p.interval .. "&limit=" .. p.limit .. "&symbol=" .. coin .. QUOTE
    local ok, res = pcall(http.execute, { url = url })
    if not (ok and res.code == 200 and res.response) then
        status = "Не вдалося завантажити"
        return false
    end
    local list = {}
    -- [час,"open","high","low","close",...]: беремо open першої свічки й close кожної
    for open, close in res.response:gmatch('%[%d+,"([%d.]+)","[%d.]+","[%d.]+","([%d.]+)"') do
        if #list == 0 then list[1] = open end
        list[#list + 1] = close
    end
    if #list < 3 then
        status = "Незрозуміла відповідь"
        return false
    end
    data[coin] = list
    at = os.time()
    status = nil
    save()
    return true
end

function lilka.init()
    W, H = display.width, display.height
    -- Застосунок стартує на весь екран, тож display.height = 240 навіть з fullscreen = false
    if not lilka.fullscreen and H > 216 then H = H - 24 end
    C.bg = rgb(8, 10, 18)
    C.panel = rgb(16, 20, 34)
    C.text = rgb(235, 240, 255)
    C.gray = rgb(130, 140, 165)
    C.up, C.up_dim = rgb(60, 220, 130), rgb(14, 60, 40)
    C.down, C.down_dim = rgb(255, 80, 90), rgb(70, 18, 26)
    C.coin = { BTC = rgb(247, 147, 26), ETH = rgb(140, 150, 255), SOL = rgb(170, 90, 255), BNB = rgb(240, 200, 40) }
    load()
    if controller then
        for _, c in ipairs(COINS) do fetch(c) end
        next_fetch = P().refresh
    end
end

-- Новий період: старі дані вже не підходять, тож завантажуємо монети наново по одній
local function switch(d)
    period = (period - 1 + d) % #PERIODS + 1
    data, at, status, t = {}, nil, nil, 0
    save()
    next_coin, next_fetch = 1, 0
end

function lilka.update(delta)
    t = t + delta
    if controller then
        local s = controller.get_state()
        if s.start.just_pressed then util.exit() end
        if s.a.just_pressed then
            for _, c in ipairs(COINS) do fetch(c) end
            next_fetch = P().refresh
        end
        if s.right.just_pressed then switch(1) end
        if s.left.just_pressed then switch(-1) end
    end
    -- На шпалерах (і в застосунку) оновлюємо монети по черзі
    if http and wifi then
        next_fetch = next_fetch - delta
        if next_fetch <= 0 then
            local refresh = P().refresh
            local fresh = at and os.time() - at < refresh
            if not fresh or next_coin > 1 then
                fetch(COINS[next_coin])
                next_coin = next_coin % #COINS + 1
                -- у застосунку кадр усе одно чекає на мережу, тож без пауз між монетами
                next_fetch = next_coin == 1 and refresh or (controller and 0 or 2)
            else
                next_fetch = refresh - (os.time() - at)
            end
        end
    end
end

local function text(s, x, y, c, font)
    display.set_font(font)
    display.set_text_size(1)
    display.set_text_color(c)
    display.set_cursor(floor(x), floor(y))
    display.print(s)
end

local function fmt_price(p)
    if p >= 10000 then
        -- Розряди через пробіл: 77 400
        local s = string.format("%.0f", p)
        return (s:reverse():gsub("(%d%d%d)", "%1 "):reverse():gsub("^ ", ""))
    elseif p >= 100 then return string.format("%.1f", p)
    elseif p >= 10 then return string.format("%.2f", p)
    elseif p >= 1 then return string.format("%.3f", p) end
    return string.format("%.5f", p)
end

local function row(coin, y, h)
    local list = data[coin]
    local cc = C.coin[coin] or C.text
    display.fill_rect(4, y, W - 8, h - 4, C.panel)
    display.fill_rect(4, y, 3, h - 4, cc)
    text(coin, 13, y + 14, cc, "8x13")
    if not list then
        text("немає даних", 13, y + 32, C.gray, "6x12")
        return
    end
    local n = #list
    local first, last = tonumber(list[1]), tonumber(list[n])
    local ch = (last / first - 1) * 100
    local up = ch >= 0
    local col, dim = up and C.up or C.down, up and C.up_dim or C.down_dim
    text(fmt_price(last), 13, y + 33, C.text, "9x15")
    local pct = string.format("%s%.2f%%", up and "+" or "", ch)
    local ax, ay = 50, y + 14
    if up then
        display.fill_triangle(ax - 3, ay - 1, ax + 3, ay - 1, ax, ay - 7, col)
    else
        display.fill_triangle(ax - 3, ay - 7, ax + 3, ay - 7, ax, ay - 1, col)
    end
    text(pct, 56, y + 14, col, "6x12")

    -- Графік за період
    local lo, hi = last, last
    local v = {}
    for k = 1, n do
        v[k] = tonumber(list[k])
        lo, hi = min(lo, v[k]), max(hi, v[k])
    end
    if hi - lo < hi * 1e-6 then hi = lo + hi * 1e-6 + 1e-9 end
    local gx, gy, gw, gh = 128, y + 5, W - 140, h - 14
    local function px(k) return floor(gx + (k - 1) / (n - 1) * gw) end
    local function py(p) return floor(gy + gh - (p - lo) / (hi - lo) * gh) end
    local base = py(first)
    local reveal = min(n, 2 + floor(t / 1.5 * n))  -- графік «малюється» за 1.5 с
    -- Пунктир на рівні ціни на початку періоду
    for x = gx, gx + gw, 6 do display.fill_rect(x, base, 3, 1, C.gray) end
    for k = 2, reveal do
        local x0, y0, x1, y1 = px(k - 1), py(v[k - 1]), px(k), py(v[k])
        display.fill_triangle(x0, y0, x1, y1, x0, gy + gh, dim)
        display.fill_triangle(x1, y1, x1, gy + gh, x0, gy + gh, dim)
    end
    for k = 2, reveal do
        display.draw_line(px(k - 1), py(v[k - 1]), px(k), py(v[k]), col)
    end
    if reveal == n then
        local lx, ly = px(n), py(last)
        local r = 2 + floor(1.5 + 1.5 * sin(t * 4))
        display.draw_circle(lx, ly, r + 1, col)
        display.fill_circle(lx, ly, 2, C.text)
    end
end

function lilka.draw()
    display.fill_screen(C.bg)
    text("Crypto", 6, 13, C.text, "8x13")
    text("/ " .. QUOTE .. ", " .. P().label, 58, 12, C.gray, "6x12")
    local note
    if status and controller then
        note = status
    elseif at then
        note = os.date("%H:%M", at)
        if os.time() - at > 3600 then note = os.date("%d.%m %H:%M", at) end
    else
        note = "відкрийте як застосунок"
    end
    text(note, W - 6 - utf8.len(note) * 6, 12, status and C.down or C.gray, "6x12")
    local top = 18
    local rh = (H - top) // #COINS
    for k, c in ipairs(COINS) do row(c, top + (k - 1) * rh, rh) end
end
