-- Банка Monobank: скільки зібрано, ціль, приріст за добу. Монетки падають у банку, коли сума росте.
-- Дані: send.monobank.ua (без ключа API). ID банки — останнє слово посилання send.monobank.ua/jar/XXXXXXXXXX.
-- Застосунок завантажує дані в jar_<ID>.txt; шпалери на свіжій Keira оновлюють їх самі.
-- Застосунок: ← → — інша банка (якщо їх кілька), A — оновити, START — вихід.

lilka.fullscreen = false

local JARS = { "3KnuZcZuKz" } -- одна або кілька банок
local REFRESH = 1 * 60
local SHOW_TIME = 15            -- секунд на банку, якщо їх кілька
local URL = "https://send.monobank.ua/api/handler"

local floor, sin, rnd = math.floor, math.sin, math.random
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

-- Суми великі (до мільярдів копійок), тож ділимо на 100 рядком, а не числом
local function hryvnias(s)
    if not s then return nil end
    if #s <= 2 then return 0 end
    return tonumber(s:sub(1, -3))
end
local function group(n)
    local s = string.format("%.0f", n)
    return (s:reverse():gsub("(%d%d%d)", "%1 "):reverse():gsub("^ ", ""))
end

local function unescape(s)
    s = s:gsub("\\u(%x%x%x%x)", function(h)
        local n = tonumber(h, 16)
        if n >= 0xD800 and n <= 0xDFFF then return "" end
        return utf8.char(n)
    end)
    return (s:gsub('\\(.)', { n = " ", t = " ", ['"'] = '"', ["\\"] = "\\", ["/"] = "/" }))
end

local function wrap(s, width)
    local out, line = {}, ""
    for word in s:gmatch("%S+") do
        local cand = line == "" and word or (line .. " " .. word)
        if (utf8.len(cand) or #cand) > width and line ~= "" then
            out[#out + 1] = line
            line = word
        else
            line = cand
        end
    end
    if line ~= "" then out[#out + 1] = line end
    return out
end

local W, H
local t = 0
local jars = {}  -- [i] = { id, name, owner, amount, goal, closed, at, hist = { {time, amount} } }
local cur, ct = 1, 0
local status
local next_fetch = 0
local coins = {}
local shown = 0  -- сума, що "набігає" на екрані
local C = {}

-- Банка на екрані
local JX, JW, JTOP, JBOT = 16, 92, 58, 198

local function cache_name(id) return "jar_" .. id .. ".txt" end

local function load(i)
    local id = JARS[i]
    local j = { id = id, hist = {} }
    jars[i] = j
    local ok, s = pcall(resources.read_file, cache_name(id))
    if not ok or not s then return end
    local d = {}
    for k, v in s:gmatch("(%w+)=([^\n]*)") do d[k] = v end
    j.name, j.owner = d.name, d.owner
    j.amount, j.goal = tonumber(d.amount), tonumber(d.goal)
    j.closed, j.at = d.closed == "1", tonumber(d.at)
    for tm, a in s:gmatch("\n(%d+)|(%d+)") do j.hist[#j.hist + 1] = { tonumber(tm), tonumber(a) } end
end

local function save(j)
    local lines = { "at=" .. j.at, "name=" .. j.name, "owner=" .. (j.owner or ""), "amount=" .. j.amount,
        "goal=" .. j.goal, "closed=" .. (j.closed and "1" or "0") }
    for _, h in ipairs(j.hist) do lines[#lines + 1] = h[1] .. "|" .. h[2] end
    pcall(resources.write_file, cache_name(j.id), table.concat(lines, "\n"))
end

local function drop_coins(n)
    for _ = 1, min(n, 14) do
        coins[#coins + 1] = { x = JX + 28 + rnd() * (JW - 56), y = -10 - rnd() * 80, vy = 0, sp = rnd() * 6 }
    end
end

local function fetch(i)
    local j = jars[i]
    if not (http and wifi) or wifi.get_status() ~= 3 then
        status = "Wi-Fi не під'єднано"
        return
    end
    collectgarbage()
    local body = '{"c":"hello","clientId":"' .. j.id .. '","Pc":"lilka"}'
    local ok, res = pcall(http.execute, { url = URL, method = "POST", body = body })
    if not (ok and res.code == 200 and res.response) then
        status = "Не вдалося завантажити"
        return
    end
    local s = res.response
    local amount = hryvnias(s:match('"jarAmount":(%d+)'))
    if not amount then
        status = s:find("errCode") and "Банку не знайдено" or "Незрозуміла відповідь"
        return
    end
    local old = j.amount
    j.amount = amount
    j.goal = hryvnias(s:match('"jarGoal":(%d+)')) or 0
    j.name = unescape(s:match('"name":"(.-)","') or j.id):gsub("[\n=]", " ")
    j.owner = unescape(s:match('"ownerName":"(.-)","') or ""):gsub("[\n=]", " ")
    j.closed = s:match('"jarStatus":"(%a+)"') == "CLOSED"
    local now = os.time()
    j.at = now
    -- Історія: точка не частіше ніж раз на 30 хв, не старіша за 2 доби
    local last = j.hist[#j.hist]
    if not last or now - last[1] >= 1800 then j.hist[#j.hist + 1] = { now, amount }
    else last[2] = amount end
    while #j.hist > 0 and now - j.hist[1][1] > 2 * 86400 do table.remove(j.hist, 1) end
    status = nil
    save(j)
    if i == cur and old and amount > old then drop_coins(1 + (amount - old) // 200) end
end

local function fetch_all()
    for i = 1, #JARS do fetch(i) end
end

local function show(i)
    cur = (i - 1) % #JARS + 1
    ct = 0
    shown = 0
    coins = {}
    drop_coins(4)
end

function lilka.init()
    W, H = display.width, display.height
    -- Застосунок стартує на весь екран, тож display.height = 240 навіть з fullscreen = false
    if not lilka.fullscreen and H > 216 then H = H - 24 end
    JBOT = H - 18
    C.bg = rgb(12, 12, 14)
    C.text = rgb(240, 240, 240)
    C.gray = rgb(140, 140, 150)
    C.dim = rgb(55, 55, 62)
    C.glass = rgb(150, 175, 195)
    C.glass_in = rgb(24, 28, 34)
    C.shine = rgb(210, 225, 240)
    C.lid = rgb(225, 70, 90)
    C.lid_dark = rgb(160, 40, 60)
    C.gold = rgb(240, 180, 50)
    C.gold_dark = rgb(190, 125, 25)
    C.gold_light = rgb(255, 225, 120)
    C.green = rgb(80, 210, 120)
    C.red = rgb(235, 80, 80)
    for i = 1, #JARS do load(i) end
    if controller then fetch_all(); next_fetch = REFRESH
    else
        local j = jars[1]
        if not (j.at and os.time() - j.at < REFRESH) then next_fetch = 1 else next_fetch = REFRESH - (os.time() - j.at) end
    end
    show(1)
end

local function level(j)
    if not j.amount then return 0 end
    if j.goal and j.goal > 0 then return clamp(j.amount / j.goal, 0, 1) end
    return 0.6
end

function lilka.update(delta)
    t = t + delta
    ct = ct + delta
    if controller then
        local s = controller.get_state()
        if s.start.just_pressed then util.exit() end
        if s.a.just_pressed then fetch_all(); next_fetch = REFRESH end
        if s.right.just_pressed then show(cur + 1) end
        if s.left.just_pressed then show(cur - 1) end
    end
    if #JARS > 1 and ct > SHOW_TIME then show(cur + 1) end
    if http and wifi then
        next_fetch = next_fetch - delta
        if next_fetch <= 0 then
            next_fetch = REFRESH
            fetch_all()
        end
    end
    local j = jars[cur]
    if j.amount then shown = shown + (j.amount - shown) * min(1, delta * 2.5) end
    -- Монетки падають до поверхні й зникають
    local surf = JBOT - 6 - (JBOT - 6 - JTOP - 4) * level(j)
    for k = #coins, 1, -1 do
        local c = coins[k]
        c.vy = c.vy + 260 * delta
        c.y = c.y + c.vy * delta
        if c.y >= surf - 2 then table.remove(coins, k) end
    end
    if rnd() < delta / 3 then drop_coins(1) end
end

local function draw_jar(j)
    local lv = level(j)
    local x0, x1 = JX, JX + JW
    -- Кришка й шийка
    display.fill_rect(x0 + 16, JTOP - 22, JW - 32, 12, C.lid)
    display.fill_rect(x0 + 16, JTOP - 12, JW - 32, 3, C.lid_dark)
    display.fill_rect(x0 + 20, JTOP - 9, JW - 40, 9, C.glass_in)
    display.draw_line(x0 + 20, JTOP - 9, x0 + 20, JTOP, C.glass)
    display.draw_line(x1 - 20, JTOP - 9, x1 - 20, JTOP, C.glass)
    -- Тіло
    display.fill_rect(x0, JTOP + 8, JW, JBOT - JTOP - 16, C.glass_in)
    display.fill_rect(x0 + 8, JTOP, JW - 16, JBOT - JTOP, C.glass_in)
    display.fill_circle(x0 + 8, JTOP + 8, 8, C.glass_in)
    display.fill_circle(x1 - 9, JTOP + 8, 8, C.glass_in)
    display.fill_circle(x0 + 8, JBOT - 9, 8, C.glass_in)
    display.fill_circle(x1 - 9, JBOT - 9, 8, C.glass_in)
    -- Монети всередині: золото з хвилястою поверхнею й "монетками" на зрізі
    local inner_top, inner_bot = JTOP + 4, JBOT - 6
    local surf = inner_bot - (inner_bot - inner_top) * lv
    for x = x0 + 4, x1 - 6, 2 do
        local edge = 0
        if x < x0 + 10 then edge = (x0 + 10 - x) // 2 elseif x > x1 - 12 then edge = (x - (x1 - 12)) // 2 end
        local sy = floor(surf + sin(x * 0.18 + t * 2.2) * 1.5)
        local bot = inner_bot - edge
        if sy < bot then
            display.fill_rect(x, sy, 2, bot - sy, C.gold)
            display.fill_rect(x, sy, 2, 2, C.gold_light)
        end
    end
    if lv > 0.04 then
        for k = 0, 40 do
            local cx = x0 + 10 + (k * 37) % (JW - 22)
            local cy = inner_bot - 6 - (k * 53) % 120
            if cy > surf + 5 then display.fill_ellipse(cx, cy, 5, 2, k % 3 == 0 and C.gold_light or C.gold_dark) end
        end
    end
    -- Контур і відблиск скла
    display.draw_line(x0, JTOP + 8, x0, JBOT - 9, C.glass)
    display.draw_line(x1 - 1, JTOP + 8, x1 - 1, JBOT - 9, C.glass)
    display.draw_line(x0 + 8, JBOT - 1, x1 - 9, JBOT - 1, C.glass)
    display.draw_line(x0 + 8, JTOP, x0 + 20, JTOP, C.glass)
    display.draw_line(x1 - 20, JTOP, x1 - 9, JTOP, C.glass)
    display.draw_line(x0 + 6, JTOP + 14, x0 + 6, JBOT - 20, C.shine)
    display.draw_line(x0 + 8, JTOP + 14, x0 + 8, JTOP + 40, C.shine)
    -- Монетки, що падають
    for _, c in ipairs(coins) do
        local w = 1 + floor((sin(t * 9 + c.sp) * 0.5 + 0.5) * 4)
        display.fill_ellipse(c.x, c.y, w, 4, C.gold)
        display.fill_ellipse(c.x, c.y, max(0, w - 2), 2, C.gold_light)
    end
end

-- Приріст за добу: різниця з найстарішою точкою, не старішою за 24 год
local function day_delta(j)
    local now = os.time()
    for _, h in ipairs(j.hist) do
        if now - h[1] <= 26 * 3600 then
            if now - h[1] < 6 * 3600 then return nil end
            return j.amount - h[2]
        end
    end
    return nil
end

local function draw_spark(j, x, y, w, h)
    local list = {}
    local now = os.time()
    for _, p in ipairs(j.hist) do if now - p[1] <= 86400 then list[#list + 1] = p end end
    if #list < 3 then return end
    local lo, hi = list[1][2], list[1][2]
    for _, p in ipairs(list) do lo, hi = min(lo, p[2]), max(hi, p[2]) end
    if hi == lo then hi = lo + 1 end
    local px, py
    for _, p in ipairs(list) do
        local xx = x + (p[1] - (now - 86400)) / 86400 * w
        local yy = y + h - (p[2] - lo) / (hi - lo) * h
        if px then display.draw_line(px, py, xx, yy, C.green) end
        px, py = xx, yy
    end
end

function lilka.draw()
    display.fill_screen(C.bg)
    local j = jars[cur]
    draw_jar(j)

    local x = JX + JW + 14
    local cw = (W - x - 6) // 8
    if not j.amount then
        text("Банка " .. j.id, x, 40, C.text, "8x13")
        text(status or "Відкрийте wallpaper.lua", x, 64, C.gray, "6x12")
        if not status then text("як застосунок з Wi-Fi", x, 78, C.gray, "6x12") end
        return
    end
    local y = 22
    for k, line in ipairs(wrap(j.name, cw)) do
        if k > 3 then break end
        text(line, x, y, C.text, "8x13")
        y = y + 14
    end
    for k, line in ipairs(wrap(j.owner, (W - x - 6) // 5)) do
        if k > 2 then break end
        text(line, x, y, C.gray, "5x7")
        y = y + 9
    end

    y = max(y + 18, 86)
    text(group(shown), x, y, C.gold_light, "10x20")
    text("грн", x + #group(j.amount) * 10 + 4, y, C.gray, "6x12")
    y = y + 14
    if j.goal > 0 then
        local pct = j.amount / j.goal * 100
        text("з " .. group(j.goal) .. " грн", x, y, C.gray, "6x12")
        y = y + 8
        local bw = W - x - 6
        display.fill_rect(x, y, bw, 6, C.dim)
        display.fill_rect(x, y, floor(bw * clamp(pct / 100, 0, 1)), 6, C.gold)
        y = y + 18
        text(string.format(pct >= 10 and "%.0f%%" or "%.1f%%", pct), x, y, C.text, "9x15")
    else
        text("без цілі", x, y, C.gray, "6x12")
        y = y + 26
    end

    local d = day_delta(j)
    if d then
        text((d >= 0 and "+" or "") .. group(d) .. " за добу", x + 54, y - 1, d > 0 and C.green or C.gray, "6x12")
        draw_spark(j, x, y + 8, W - x - 6, 16)
    end

    if j.closed then
        text("Збір закрито", x, H - 16, C.red, "8x13")
    end
    local note
    if status and controller then note = status
    elseif j.at then note = "оновлено " .. os.date("%H:%M", j.at) end
    if note then text(note, x, H - 4, status and controller and C.red or C.dim, "5x7") end
    if #JARS > 1 then text(cur .. "/" .. #JARS, W - 24, H - 4, C.gray, "5x7") end
end
