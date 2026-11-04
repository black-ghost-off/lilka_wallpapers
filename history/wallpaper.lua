-- Цей день в історії: вибрані події з української Вікіпедії, по одній, ніби друкарською машинкою.
-- Застосунок завантажує події на сьогодні в history.txt; шпалери на свіжій Keira
-- самі завантажують нові, коли настає новий день.
-- Застосунок: ← → — подія, A — оновити, START — вихід.

lilka.fullscreen = false

local CACHE = "history.txt"
local SHOW_TIME = 14 -- секунд на подію (разом з друком)
local CPS = 28       -- символів за секунду
local URL = "https://uk.wikipedia.org/api/rest_v1/feed/onthisday/selected/"
local MONTHS = { "січня", "лютого", "березня", "квітня", "травня", "червня", "липня", "серпня", "вересня", "жовтня", "листопада", "грудня" }

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
local events = {}  -- { year, text }
local day          -- "11-04", для якого дня події
local status
local cur, ct = 1, 0
local lines = {}   -- поточна подія, розбита на рядки
local retry = 0
local C = {}
local FONT, CW, LH = "8x13", 8, 15

local function unescape(s)
    s = s:gsub("\\u(%x%x%x%x)", function(h)
        local n = tonumber(h, 16)
        if n >= 0xD800 and n <= 0xDFFF then return "" end -- сурогатні пари не потрібні для українського тексту
        return utf8.char(n)
    end)
    s = s:gsub('\\(.)', { n = " ", t = " ", ['"'] = '"', ["\\"] = "\\", ["/"] = "/" })
    return s
end

-- Перенесення за словами; ширина — у символах UTF-8
local function wrap(s, width)
    local out, line = {}, ""
    for word in s:gmatch("%S+") do
        local cand = line == "" and word or (line .. " " .. word)
        if utf8.len(cand) and utf8.len(cand) > width and line ~= "" then
            out[#out + 1] = line
            line = word
        else
            line = cand
        end
    end
    if line ~= "" then out[#out + 1] = line end
    return out
end

local function show(k)
    if #events == 0 then return end
    cur = (k - 1) % #events + 1
    ct = 0
    lines = wrap(events[cur][2], (W - 20) // CW)
end

local function today_key() return os.date("%m-%d") end

local function load()
    local ok, s = pcall(resources.read_file, CACHE)
    if not ok or not s then return end
    day = s:match("^day=([%d-]+)")
    events = {}
    for y, txt in s:gmatch("\n(%-?%d+)|([^\n]*)") do events[#events + 1] = { tonumber(y), txt } end
    show(1)
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
    local key = today_key()
    local ok, res = pcall(http.execute, { url = URL .. key:gsub("%-", "/") })
    if not (ok and res.code == 200 and res.response) then
        status = "Не вдалося завантажити"
        return
    end
    local body = res.response
    local out, pos = {}, 1
    while true do
        local s, e, txt = body:find('"text":"(.-)","pages":', pos)
        if not s then break end
        local _, e2, y = body:find('"year":(%-?%d+)', e)
        if not y then break end
        out[#out + 1] = y .. "|" .. unescape(txt):gsub("[\n|]", " ")
        pos = e2 + 1
    end
    res, body = nil, nil
    collectgarbage()
    if #out == 0 then
        status = "Незрозуміла відповідь"
        return
    end
    status = nil
    pcall(resources.write_file, CACHE, "day=" .. key .. "\n" .. table.concat(out, "\n"))
    load()
end

function lilka.init()
    W, H = display.width, display.height
    -- Застосунок стартує на весь екран, тож display.height = 240 навіть з fullscreen = false
    if not lilka.fullscreen and H > 216 then H = H - 24 end
    C.bg = rgb(16, 14, 12)
    C.paper = rgb(28, 24, 20)
    C.text = rgb(240, 232, 214)
    C.gray = rgb(150, 140, 125)
    C.accent = rgb(240, 170, 60)
    C.line = rgb(60, 50, 40)
    load()
    if controller or day ~= today_key() then fetch() end
end

function lilka.update(delta)
    t = t + delta
    ct = ct + delta
    if controller then
        local s = controller.get_state()
        if s.start.just_pressed then util.exit() end
        if s.a.just_pressed then fetch() end
        if s.right.just_pressed then show(cur + 1) end
        if s.left.just_pressed then show(cur - 1) end
    end
    if ct > SHOW_TIME then show(cur + 1) end
    -- Новий день — нові події (на шпалерах лише зі свіжою Keira)
    if http and wifi and day ~= today_key() then
        retry = retry - delta
        if retry <= 0 then
            retry = 300
            fetch()
        end
    end
end

function lilka.draw()
    display.fill_screen(C.bg)
    local tm = os.date("*t")
    local d = day and tonumber(day:sub(4, 5)) or tm.day
    local m = day and tonumber(day:sub(1, 2)) or tm.month
    text("Цей день в історії", 8, 16, C.gray, "6x12")
    local date = d .. " " .. MONTHS[m]
    text(date, W - 8 - utf8.len(date) * 8, 17, C.accent, "8x13")
    display.fill_rect(8, 22, W - 16, 1, C.line)

    local e = events[cur]
    if not e then
        text("Немає подій", 10, 70, C.text, "9x15")
        text(status or "Відкрийте wallpaper.lua", 10, 92, C.gray, "6x12")
        if not status then text("як застосунок з Wi-Fi", 10, 106, C.gray, "6x12") end
        return
    end

    -- Рік і скільки років тому
    local y = e[1]
    text(tostring(y), 10, 50, C.accent, "10x20")
    local ago = tm.year - y
    if ago > 0 then text(ago .. " р. тому", 14 + #tostring(y) * 10, 50, C.gray, "6x12") end
    text(cur .. "/" .. #events, W - 10 - #(cur .. "/" .. #events) * 6, 50, C.gray, "6x12")

    -- Текст друкується
    local budget = floor(ct * CPS)
    local ty = 74
    local last_x, last_y = 10, ty
    for _, line in ipairs(lines) do
        if budget <= 0 or ty > H - 18 then break end
        local n = utf8.len(line)
        local shown = line
        if budget < n then shown = line:sub(1, utf8.offset(line, budget + 1) - 1) end
        text(shown, 10, ty, C.text, FONT)
        last_x, last_y = 10 + utf8.len(shown) * CW, ty
        budget = budget - n - 1
        ty = ty + LH
    end
    if floor(t * 2) % 2 == 0 then display.fill_rect(last_x + 1, last_y - 10, 6, 11, C.accent) end

    -- Смужка часу до наступної події
    display.fill_rect(8, H - 6, floor((W - 16) * min(1, ct / SHOW_TIME)), 2, C.line)
    if status and controller then text(status, 10, H - 10, C.accent, "5x7") end
end
