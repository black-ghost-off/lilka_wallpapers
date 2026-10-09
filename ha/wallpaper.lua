-- Панель Home Assistant: датчики, світло й розетки плитками. Без токена показує демо.
-- Стан оновлюється і в застосунку, і на шпалерах (потрібен Wi-Fi та свіжа Keira з модулем net),
-- останні значення зберігаються в ha.txt.
-- Застосунок: стрілки — вибір плитки, A — увімкнути/вимкнути, B — оновити, START — вихід.

lilka.fullscreen = false

local HA_HOST = "192.168.1.10" -- IP Home Assistant (імена .local зазвичай не працюють)
local HA_PORT = 8123
local HA_TOKEN = "" -- Long-lived access token: Профіль -> Безпека -> Створити токен
-- До 6 плиток на сторінку, сторінки гортаються самі. kind можна не вказувати:
-- temp, humidity, power, light, switch, door, motion
local ENTITIES = {
    { id = "sensor.outdoor_temperature", name = "Надворі" },
    { id = "sensor.living_room_temperature", name = "Вітальня" },
    { id = "sensor.living_room_humidity", name = "Вологість" },
    { id = "light.living_room", name = "Світло" },
    { id = "switch.kettle", name = "Чайник" },
    { id = "binary_sensor.front_door", name = "Двері", kind = "door" },
}
local CACHE = "ha.txt"
local REFRESH = 15
local PAGE_TIME = 8

local sin, floor = math.sin, math.floor
local function min(a, b) if a < b then return a end return b end
local function max(a, b) if a > b then return a end return b end
local function clamp(x, a, b) return min(b, max(a, x)) end
local function rgb(r, g, b) return display.color565(floor(clamp(r, 0, 255)), floor(clamp(g, 0, 255)), floor(clamp(b, 0, 255))) end

local W, H
local t = 0
local demo = HA_TOKEN == ""
local states = {} -- states[id] = { state = "21.5", unit = "°C" }
local queue, next_poll = {}, 1
local status, online
local sel, page, page_t = 1, 1, 0

local DEMO = {
    ["sensor.outdoor_temperature"] = { state = "7.4", unit = "°C" },
    ["sensor.living_room_temperature"] = { state = "22.1", unit = "°C" },
    ["sensor.living_room_humidity"] = { state = "46", unit = "%" },
    ["light.living_room"] = { state = "on" },
    ["switch.kettle"] = { state = "off" },
    ["binary_sensor.front_door"] = { state = "off" },
}

local function kind_of(e)
    if e.kind then return e.kind end
    local domain = e.id:match("^(%w+)%.")
    local s = states[e.id]
    local unit = s and s.unit or ""
    if domain == "light" then return "light" end
    if domain == "switch" or domain == "input_boolean" or domain == "fan" then return "switch" end
    if domain == "binary_sensor" then return e.id:find("motion") and "motion" or "door" end
    if unit:find("C$") then return "temp" end
    if unit == "%" then return "humidity" end
    if unit == "W" or unit == "kW" then return "power" end
    return "sensor"
end

local function save()
    local lines = {}
    for _, e in ipairs(ENTITIES) do
        local s = states[e.id]
        if s then lines[#lines + 1] = e.id .. "=" .. s.state .. "|" .. (s.unit or "") end
    end
    pcall(resources.write_file, CACHE, table.concat(lines, "\n"))
end

local function load()
    if demo then
        for k, v in pairs(DEMO) do states[k] = { state = v.state, unit = v.unit } end
        return
    end
    local ok, text = pcall(resources.read_file, CACHE)
    if not (ok and text) then return end
    for id, st, unit in text:gmatch("([%w_%.]+)=([^|\n]*)|([^\n]*)") do
        states[id] = { state = st, unit = unit ~= "" and unit or nil }
    end
end

-- HTTP через сокет, бо http.execute не вміє передати заголовок Authorization
local function request(method, path, body)
    if not net then return nil, "немає модуля net" end
    local fd, err = net.connect(HA_HOST, HA_PORT, 2000)
    if not fd then return nil, err end
    local req = method .. " " .. path .. " HTTP/1.0\r\nHost: " .. HA_HOST .. "\r\nAuthorization: Bearer " .. HA_TOKEN
        .. "\r\nConnection: close\r\n"
    if body then req = req .. "Content-Type: application/json\r\nContent-Length: " .. #body .. "\r\n" end
    req = req .. "\r\n" .. (body or "")
    while #req > 0 do
        local n = net.send(fd, req)
        if not n then net.close(fd); return nil, "send" end
        req = req:sub(n + 1)
    end
    local parts = {}
    while true do
        local chunk = net.receive(fd, 1024, 2000)
        if not chunk then break end
        parts[#parts + 1] = chunk
    end
    net.close(fd)
    local resp = table.concat(parts)
    return tonumber(resp:match("^HTTP/%d%.%d (%d+)")), resp:match("\r\n\r\n(.*)$")
end

local function poll(id)
    local ok, code, body = pcall(request, "GET", "/api/states/" .. id)
    if not ok or not code then
        online, status = false, "Немає зв'язку з HA"
        return
    end
    online = true
    if code == 401 then status = "Неправильний токен"; return end
    if code ~= 200 or not body then status = "Помилка " .. code; return end
    status = nil
    local st = body:match('"state":%s*"([^"]*)"')
    if st then
        states[id] = { state = st, unit = body:match('"unit_of_measurement":%s*"([^"]*)"') }
        save()
    end
end

local function toggle(e)
    local k = kind_of(e)
    if k ~= "light" and k ~= "switch" then return end
    local s = states[e.id]
    if demo then
        if s then s.state = s.state == "on" and "off" or "on" end
        return
    end
    local domain = e.id:match("^(%w+)%.")
    pcall(request, "POST", "/api/services/" .. domain .. "/toggle", '{"entity_id":"' .. e.id .. '"}')
    if s then s.state = s.state == "on" and "off" or "on" end
    queue[#queue + 1] = e.id
end

function lilka.init()
    W, H = display.width, display.height
    if not lilka.fullscreen and H > 216 then H = H - 24 end
    load()
end

function lilka.update(delta)
    t = t + delta
    local pages = (#ENTITIES + 5) // 6
    page_t = page_t + delta
    if not controller and page_t > PAGE_TIME then
        page_t, page = 0, page % pages + 1
    end

    if demo then
        local s = states["sensor.outdoor_temperature"]
        if s then s.state = string.format("%.1f", 7.4 + sin(t * 0.05) * 1.5) end
    else
        -- Один запит на кадр, щоб не підвисати надовго
        next_poll = next_poll - delta
        if next_poll <= 0 and #queue == 0 then
            next_poll = REFRESH
            for _, e in ipairs(ENTITIES) do queue[#queue + 1] = e.id end
        end
        if #queue > 0 then
            if wifi and wifi.get_status() == 3 then
                poll(table.remove(queue, 1))
            else
                queue, status = {}, "Wi-Fi не під'єднано"
            end
        end
    end

    if controller then
        local st = controller.get_state()
        local n = #ENTITIES
        if st.right.just_pressed then sel = sel % n + 1 end
        if st.left.just_pressed then sel = (sel - 2) % n + 1 end
        if st.down.just_pressed then sel = min(n, sel + 3) end
        if st.up.just_pressed then sel = max(1, sel - 3) end
        page = (sel - 1) // 6 + 1
        if st.a.just_pressed then toggle(ENTITIES[sel]) end
        if st.b.just_pressed then next_poll = 0; queue = {} end
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

local function num(s)
    return tonumber(s.state)
end

-- Іконки з примітивів, (x, y) — центр
local function icon(k, x, y, s, on)
    local white = rgb(235, 240, 250)
    if k == "temp" then
        local v = num(s) or 20
        local c = v < 10 and rgb(90, 170, 255) or v < 24 and rgb(255, 190, 80) or rgb(255, 100, 80)
        display.fill_rect(x - 2, y - 10, 5, 14, white)
        display.fill_circle(x, y + 6, 5, white)
        display.fill_circle(x, y + 6, 3, c)
        local lvl = floor(clamp((v + 10) / 45, 0.1, 1) * 11)
        display.fill_rect(x - 1, y + 3 - lvl, 3, lvl + 2, c)
    elseif k == "humidity" then
        local c = rgb(80, 170, 255)
        display.fill_circle(x, y + 4, 6, c)
        display.fill_triangle(x - 6, y + 3, x + 6, y + 3, x, y - 9, c)
        display.fill_circle(x - 2, y + 5, 1, white)
    elseif k == "power" then
        local c = rgb(255, 210, 60)
        display.fill_triangle(x + 3, y - 10, x - 6, y + 2, x + 1, y + 1, c)
        display.fill_triangle(x - 1, y - 1, x + 6, y - 2, x - 3, y + 10, c)
    elseif k == "light" then
        local c = on and rgb(255, 220, 100) or rgb(90, 96, 110)
        if on then
            for i = 0, 7 do
                local a = i * math.pi / 4 + t * 0.6
                local r0, r1 = 10, 12 + sin(t * 4 + i) * 1.5
                display.draw_line(floor(x + math.cos(a) * r0), floor(y - 2 + sin(a) * r0),
                    floor(x + math.cos(a) * r1), floor(y - 2 + sin(a) * r1), c)
            end
        end
        display.fill_circle(x, y - 2, 7, c)
        display.fill_rect(x - 3, y + 5, 7, 5, rgb(170, 175, 190))
    elseif k == "switch" then
        local c = on and rgb(70, 220, 130) or rgb(90, 96, 110)
        display.fill_circle(x, y, 9, c)
        display.fill_circle(x, y, 6, rgb(20, 26, 40))
        display.fill_rect(x - 3, y - 11, 7, 8, rgb(20, 26, 40))
        display.fill_rect(x - 1, y - 10, 3, 9, c)
    elseif k == "door" then
        local c = on and rgb(255, 140, 80) or rgb(140, 150, 170)
        display.draw_rect(x - 7, y - 10, 14, 21, c)
        if on then
            display.fill_triangle(x - 6, y - 9, x + 3, y - 6, x - 6, y + 9, c)
            display.fill_triangle(x + 3, y - 6, x + 3, y + 7, x - 6, y + 9, c)
        else
            display.fill_rect(x - 5, y - 8, 10, 17, c)
            display.fill_circle(x + 2, y + 1, 1, rgb(20, 26, 40))
        end
    elseif k == "motion" then
        local c = on and rgb(255, 140, 80) or rgb(140, 150, 170)
        display.fill_circle(x, y - 6, 3, c)
        display.fill_rect(x - 2, y - 2, 5, 8, c)
        display.draw_line(x - 1, y + 5, x - 4, y + 11, c)
        display.draw_line(x + 1, y + 5, x + 4, y + 11, c)
        if on then display.draw_circle(x, y, 12 + floor(t * 6) % 4, c) end
    else
        display.fill_circle(x, y, 6, rgb(140, 150, 170))
    end
end

local function value(k, s)
    if not s then return "...", "" end
    local st = s.state
    if st == "unavailable" or st == "unknown" then return "н/д", "" end
    if k == "light" or k == "switch" then return st == "on" and "Увімк." or "Вимк.", "" end
    if k == "door" then return st == "on" and "Відчинено" or "Зачинено", "" end
    if k == "motion" then return st == "on" and "Рух" or "Тихо", "" end
    local v = num(s)
    local unit = (s.unit or ""):gsub("°", "")
    if v then
        if v ~= floor(v) or k == "temp" then st = string.format("%.1f", v) end
    end
    return st, unit
end

local function tile(e, x, y, w, h, selected)
    local s = states[e.id]
    local k = kind_of(e)
    local on = s and s.state == "on"
    local bg = { 22, 28, 44 }
    if on and k == "light" then
        local p = 0.85 + 0.15 * sin(t * 2)
        bg = { 70 * p, 58 * p, 24 * p }
    elseif on and k == "switch" then
        bg = { 22, 58, 40 }
    elseif on then
        bg = { 70, 36, 24 }
    end
    display.fill_rect(x, y, w, h, rgb(bg[1], bg[2], bg[3]))
    if selected then
        display.draw_rect(x, y, w, h, rgb(255, 255, 255))
        display.draw_rect(x + 1, y + 1, w - 2, h - 2, rgb(255, 255, 255))
    end
    icon(k, x + 18, y + 22, s, on)
    local v, unit = value(k, s)
    local big = #v <= 5
    text(x + 8, y + (big and 64 or 60), v, rgb(245, 248, 255), big and "10x20" or "7x13")
    if unit ~= "" then
        local vw = big and #v * 10 or utf8.len(v) * 7
        if unit == "C" then
            display.draw_circle(x + 11 + vw, y + 48, 2, rgb(170, 180, 200))
            text(x + 15 + vw, y + 58, "C", rgb(170, 180, 200), "7x13")
        else
            text(x + 10 + vw, y + 64, unit, rgb(170, 180, 200), "6x12")
        end
    end
    text(x + 8, y + h - 7, e.name, rgb(150, 160, 185), "6x12")
end

function lilka.draw()
    display.fill_screen(rgb(12, 16, 28))
    local white, grey = rgb(240, 244, 255), rgb(140, 150, 175)
    local d = os.date("*t")
    text(8, 17, "Дім", white, "8x13")
    local dot = demo and rgb(255, 190, 80) or online and rgb(70, 220, 130) or online == false and rgb(255, 90, 80)
        or grey
    display.fill_circle(40, 12, 3, dot)
    if demo then text(48, 16, "демо", rgb(255, 190, 80), "6x12") end
    text(W - 48, 17, string.format("%02d:%02d", d.hour, d.min), white, "8x13")

    local cols, gap = 3, 6
    local tw = floor((W - gap * (cols + 1)) / cols)
    local th = floor((H - 24 - gap * 3) / 2)
    local first = (page - 1) * 6 + 1
    for i = first, min(#ENTITIES, first + 5) do
        local j = i - first
        local x = gap + (j % cols) * (tw + gap)
        local y = 24 + gap + (j // cols) * (th + gap)
        tile(ENTITIES[i], x, y, tw, th, controller and i == sel)
    end
    local pages = (#ENTITIES + 5) // 6
    if pages > 1 then
        for p = 1, pages do
            display.fill_circle(W / 2 - (pages - 1) * 4 + (p - 1) * 8, 13, 2, p == page and white or grey)
        end
    end
    if status and not demo then text(72, 16, status, rgb(255, 120, 100), "6x12") end
end
