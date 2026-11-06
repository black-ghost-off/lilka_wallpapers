-- Наступні запуски ракет у світі: зворотний відлік до найближчого, ракета, місія, космодром,
-- статус і ймовірність гарної погоди, а нижче — ще кілька запусків. Час — київський.
-- Дані: Launch Library 2 від The Space Devs (ll.thespacedevs.com, без ключа, до 15 запитів на годину).
-- Застосунок завантажує дані в launches.txt; шпалери на свіжій Keira оновлюють їх самі.
-- Застосунок: ← → — який запуск показувати великим, A — оновити, START — вихід.

lilka.fullscreen = false

local CACHE = "launches.txt"
local URL = "https://ll.thespacedevs.com/2.3.0/launches/upcoming/?limit=6&mode=normal&hide_recent_previous=true"
local REFRESH = 60 * 60
local MIN_GAP = 15 * 60 -- не частіше, навіть коли запуск уже відбувся
local MONTHS = { "січ", "лют", "бер", "кві", "тра", "чер", "лип", "сер", "вер", "жов", "лис", "гру" }

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
local function cut(s, n)
    if (utf8.len(s) or #s) <= n then return s end
    return s:sub(1, (utf8.offset(s, n) or n) - 1) .. "."
end

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
    local y, mo, d, h, mi, se = (s or ""):match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
    if not y then return nil end
    return days_from_civil(tonumber(y), tonumber(mo), tonumber(d)) * 86400 + tonumber(h) * 3600 + tonumber(mi) * 60 + tonumber(se)
end

local function unescape(s)
    s = s:gsub("\\u(%x%x%x%x)", function(h)
        local n = tonumber(h, 16)
        if n >= 0xD800 and n <= 0xDFFF then return "" end
        return utf8.char(n)
    end)
    return (s:gsub('\\(.)', { n = " ", t = " ", ['"'] = '"', ["\\"] = "\\", ["/"] = "/" }))
end

local W, H
local t = 0
local list = {}  -- { net, prec, status, rocket, mission, provider, place, orbit, prob }
local at, status
local next_fetch = 0
local sel = 1
local stars, smoke = {}, {}
local C = {}

local FIELDS = { "net", "prec", "status", "rocket", "mission", "provider", "place", "orbit", "prob" }

-- Шукає "name" у першому об'єкті після ключа key
local function name_after(chunk, key)
    local p = chunk:find('"' .. key .. '":%s*{')
    if not p then return nil end
    return chunk:match('"name":%s*"(.-)"', p)
end

local function parse(body)
    local out = {}
    local starts = {}
    local pos = 1
    while true do
        local s = body:find('{"id":"[%x%-]+","url":"https://ll.thespacedevs.com/[%d.]+/launches/', pos)
        if not s then break end
        starts[#starts + 1] = s
        pos = s + 10
    end
    for i, s in ipairs(starts) do
        local chunk = body:sub(s, (starts[i + 1] or #body + 1) - 1)
        local name = unescape(chunk:match('"name":"(.-)","') or "?")
        local rocket, mission = name:match("^(.-)%s*|%s*(.+)$")
        local p = chunk:find('"net_precision":%s*{')
        local e = {
            net = utc(chunk:match('"net":"([^"]+)"')),
            prec = p and chunk:match('"abbrev":"([^"]*)"', p) or "MIN",
            status = chunk:match('"status":%s*{.-"abbrev":"([^"]*)"') or "",
            rocket = rocket or name,
            mission = mission or "",
            provider = unescape(name_after(chunk, "launch_service_provider") or ""),
            place = "",
            orbit = "",
            prob = tonumber(chunk:match('"probability":(%d+)')) or -1,
        }
        local lp = chunk:find('"location":%s*{')
        if lp then e.place = unescape(chunk:match('"name":%s*"(.-)"', lp) or "") end
        local op = chunk:find('"orbit":%s*{')
        if op then e.orbit = chunk:match('"abbrev":%s*"(.-)"', op) or "" end
        if e.net then out[#out + 1] = e end
    end
    return out
end

local function save()
    local lines = { "at=" .. at }
    for _, e in ipairs(list) do
        local parts = {}
        for _, f in ipairs(FIELDS) do parts[#parts + 1] = (tostring(e[f]):gsub("[|\n]", " ")) end
        lines[#lines + 1] = table.concat(parts, "|")
    end
    pcall(resources.write_file, CACHE, table.concat(lines, "\n"))
end

local function load()
    local ok, s = pcall(resources.read_file, CACHE)
    if not ok or not s then return end
    at = tonumber(s:match("^at=(%d+)"))
    list = {}
    for line in s:gmatch("[^\n]+") do
        local parts = {}
        for p in (line .. "|"):gmatch("([^|]*)|") do parts[#parts + 1] = p end
        if #parts == #FIELDS then
            local e = {}
            for i, f in ipairs(FIELDS) do e[f] = parts[i] end
            e.net, e.prob = tonumber(e.net), tonumber(e.prob) or -1
            if e.net then list[#list + 1] = e end
        end
    end
end

local function fetch()
    if not (http and wifi) or wifi.get_status() ~= 3 then
        status = "Wi-Fi не під'єднано"
        return
    end
    collectgarbage()
    local ok, res = pcall(http.execute, { url = URL })
    if ok and res.code == 429 then
        status = "Ліміт запитів, пізніше"
        return
    end
    if not (ok and res.code == 200 and res.response) then
        status = "Не вдалося завантажити"
        return
    end
    local out = parse(res.response)
    res = nil
    collectgarbage()
    if #out == 0 then
        status = "Незрозуміла відповідь"
        return
    end
    list, at, status = out, os.time(), nil
    save()
end

-- Запуски, що ще попереду (або були щойно — до 30 хв тому)
local function upcoming()
    local now, out = os.time(), {}
    for _, e in ipairs(list) do
        if e.net > now - 30 * 60 then out[#out + 1] = e end
    end
    return out
end

function lilka.init()
    W, H = display.width, display.height
    -- Застосунок стартує на весь екран, тож display.height = 240 навіть з fullscreen = false
    if not lilka.fullscreen and H > 216 then H = H - 24 end
    C.sky = rgb(6, 8, 22)
    C.text = rgb(235, 240, 255)
    C.gray = rgb(130, 140, 165)
    C.dim = rgb(45, 50, 70)
    C.accent = rgb(255, 160, 60)
    C.green = rgb(70, 210, 120)
    C.yellow = rgb(240, 210, 70)
    C.red = rgb(235, 80, 80)
    C.body = rgb(225, 228, 235)
    C.shade = rgb(150, 155, 170)
    C.nose = rgb(220, 70, 60)
    C.tower = rgb(70, 75, 90)
    C.ground = rgb(20, 22, 32)
    for k = 1, 40 do
        local v = 60 + floor(rnd() * 120)
        stars[k] = { floor(rnd() * 96), floor(rnd() * 150), rgb(v, v, v + 30), rnd() * 6 }
    end
    load()
    if controller then fetch(); next_fetch = REFRESH
    elseif not (at and os.time() - at < REFRESH) then next_fetch = 1
    else next_fetch = REFRESH - (os.time() - at) end
end

function lilka.update(delta)
    t = t + delta
    local n = #upcoming()
    if controller then
        local s = controller.get_state()
        if s.start.just_pressed then util.exit() end
        if s.a.just_pressed then fetch(); next_fetch = REFRESH end
        if s.right.just_pressed and n > 0 then sel = sel % n + 1 end
        if s.left.just_pressed and n > 0 then sel = (sel - 2) % n + 1 end
    end
    if sel > max(1, n) then sel = 1 end
    if http and wifi then
        next_fetch = next_fetch - delta
        -- Найближчий запуск минув або список закінчується — оновити раніше
        if n < 3 and at and os.time() - at > MIN_GAP then next_fetch = min(next_fetch, 0) end
        if next_fetch <= 0 then
            next_fetch = REFRESH
            fetch()
        end
    end
    -- Пара біля ракети
    if rnd() < delta * 6 then smoke[#smoke + 1] = { x = 48 + (rnd() - 0.5) * 10, y = 0, r = 2, life = 0 } end
    for k = #smoke, 1, -1 do
        local p = smoke[k]
        p.life = p.life + delta
        p.x = p.x + (p.x < 48 and -1 or 1) * delta * 14
        p.r = p.r + delta * 4
        if p.life > 1.6 then table.remove(smoke, k) end
    end
end

-- Т-мінус у вигляді "2д 04:13:27"
local function countdown(dt)
    local sign = dt >= 0 and "T- " or "T+ "
    dt = dt >= 0 and dt or -dt
    local d, h, m, s = dt // 86400, dt % 86400 // 3600, dt % 3600 // 60, dt % 60
    local hms = string.format("%02d:%02d:%02d", h, m, s)
    if d > 0 then return sign .. d .. "д " .. hms end
    return sign .. hms
end

local function when(e)
    local tm = os.date("*t", e.net)
    local day = tm.day .. " " .. MONTHS[tm.month]
    if e.prec == "SEC" or e.prec == "MIN" then return day .. " " .. string.format("%02d:%02d", tm.hour, tm.min) end
    if e.prec == "HR" then return day .. " ~" .. string.format("%02d:00", tm.hour) end
    if e.prec == "DAY" then return day end
    return MONTHS[tm.month] .. " " .. tm.year .. "?"
end

local STATUS = { Go = { "GO", "green" }, TBC = { "TBC", "yellow" }, TBD = { "TBD", "gray" }, Hold = { "HOLD", "red" },
    ["In Flight"] = { "У ПОЛЬОТІ", "accent" }, Success = { "УСПІХ", "green" }, Failure = { "АВАРІЯ", "red" },
    ["Partial Failure"] = { "ЧАСТКОВО", "yellow" } }

-- Ракета на стартовому столі; liftoff — секунд після старту (злітає)
local function draw_rocket(cx, ground, liftoff)
    local rise = 0
    if liftoff and liftoff > 0 then rise = min(400, liftoff * liftoff * 3) end
    -- Вежа обслуговування
    display.fill_rect(cx - 22, ground - 92, 5, 92, C.tower)
    for y = ground - 88, ground - 8, 10 do display.draw_line(cx - 22, y, cx - 17, y + 8, C.dim) end
    display.fill_rect(cx - 17, ground - 70, 8, 2, C.tower)
    local by = ground - 6 - rise
    -- Полум'я при зльоті
    if rise > 0 or (liftoff and liftoff > -3) then
        local fl = 14 + floor(sin(t * 40) * 4 + 4)
        display.fill_triangle(cx - 6, by, cx + 6, by, cx, by + fl, C.accent)
        display.fill_triangle(cx - 3, by, cx + 3, by, cx, by + fl * 0.6, C.yellow)
    end
    display.fill_rect(cx - 6, by - 64, 12, 64, C.body)
    display.fill_rect(cx + 2, by - 64, 4, 64, C.shade)
    display.fill_rect(cx - 6, by - 40, 12, 2, C.dim)
    display.fill_triangle(cx - 6, by - 64, cx + 6, by - 64, cx, by - 82, C.nose)
    display.fill_triangle(cx - 6, by - 14, cx - 6, by, cx - 13, by, C.nose)
    display.fill_triangle(cx + 6, by - 14, cx + 6, by, cx + 13, by, C.nose)
    display.fill_rect(cx - 2, by - 56, 4, 4, C.dim)
    -- Стіл і земля
    display.fill_rect(0, ground, 96, H - ground, C.ground)
    display.fill_rect(cx - 16, ground - 4, 32, 4, C.tower)
    for _, p in ipairs(smoke) do
        local v = floor(160 - p.life * 80)
        display.fill_circle(p.x, ground - 3 - p.life * 4, p.r, rgb(v, v, v + 10))
    end
end

function lilka.draw()
    display.fill_screen(C.sky)
    for _, s in ipairs(stars) do
        if sin(t * 1.5 + s[4]) > -0.6 then display.fill_rect(s[1], s[2], 1, 1, s[3]) end
    end
    local ups = upcoming()
    local e = ups[sel]
    local now = os.time()
    local ground = 150
    draw_rocket(48, ground, e and (now - e.net) or nil)

    local x = 104
    if not e then
        text("Запуски ракет", x, 24, C.text, "8x13")
        text(status or "Відкрийте wallpaper.lua", x, 48, C.gray, "6x12")
        if not status then text("як застосунок з Wi-Fi", x, 62, C.gray, "6x12") end
        return
    end
    local cw = (W - x - 4) // 6
    text(cut(e.rocket, (W - x - 4) // 8), x, 16, C.text, "8x13")
    text(cut(e.mission, cw), x, 30, C.accent, "6x12")
    text(cut(e.provider, cw), x, 43, C.gray, "6x12")
    local place = e.place:match("^([^,]+)") or e.place
    text(cut(place, (W - x - 4) // 5), x, 54, C.gray, "5x7")

    -- Відлік
    local exact = e.prec == "SEC" or e.prec == "MIN" or e.prec == "HR"
    if exact then
        text(countdown(e.net - now), x, 80, C.text, "10x20")
    else
        text("дата не точна", x, 78, C.gray, "8x13")
    end
    text(when(e), x, 94, C.gray, "6x12")

    -- Статус, орбіта, погода
    local st = STATUS[e.status] or { e.status ~= "" and e.status:upper() or "?", "gray" }
    local sc = C[st[2]]
    local sw = utf8.len(st[1]) * 5 + 8
    display.draw_rect(x, 100, sw, 11, sc)
    text(st[1], x + 4, 109, sc, "5x7")
    local ix = x + sw + 6
    if e.orbit ~= "" and e.orbit ~= "N/A" then
        text("орбіта " .. e.orbit, ix, 109, C.gray, "5x7")
        ix = ix + (7 + #e.orbit) * 5 + 6
    end
    if e.prob >= 0 then text("погода " .. e.prob .. "%", ix, 109, e.prob >= 70 and C.green or C.yellow, "5x7") end

    -- Наступні запуски
    local y = 132
    display.fill_rect(x, y - 10, W - x - 4, 1, C.dim)
    for k = 1, #ups do
        if y > H - 4 then break end
        if k ~= sel then
            local u = ups[k]
            local tm = os.date("*t", u.net)
            local date = (u.prec == "SEC" or u.prec == "MIN" or u.prec == "HR")
                and string.format("%02d.%02d %02d:%02d", tm.day, tm.month, tm.hour, tm.min)
                or string.format("%02d.%02d  ?   ", tm.day, tm.month)
            text(date, x, y, C.gray, "5x7")
            text(cut(u.rocket, (W - x - 64) // 5), x + 60, y, C.text, "5x7")
            text(cut(u.mission, (W - x - 64) // 5), x + 60, y + 9, C.gray, "5x7")
            y = y + 20
        end
    end

    if status and controller then text(status, 4, H - 3, C.red, "5x7")
    elseif at then text("оновлено " .. os.date("%H:%M", at), 4, H - 3, C.dim, "5x7") end
end
