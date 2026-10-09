-- Погода: анімована сцена за даними Open-Meteo (без ключа API).
-- Застосунок завантажує погоду в weather.txt (потрібен Wi-Fi), шпалери лише читають цей файл:
-- у лаунчера замало стека для HTTP.
-- Застосунок: A — оновити, START — вихід.

lilka.fullscreen = false

local CITY, LAT, LON = "Київ", 50.45, 30.52
local CACHE = "weather.txt"
local REFRESH = 30 * 60

local sin, cos, floor = math.sin, math.cos, math.floor
local rnd = math.random
local function min(a, b) if a < b then return a end return b end
local function max(a, b) if a > b then return a end return b end
local function clamp(x, a, b) return min(b, max(a, x)) end
local function lerp(a, b, k) return a + (b - a) * k end
local function rgb(r, g, b) return display.color565(floor(clamp(r, 0, 255)), floor(clamp(g, 0, 255)), floor(clamp(b, 0, 255))) end

local W, H
local t = 0
local data, status
local drops, flakes, stars, clouds = {}, {}, {}, {}
local flash, next_flash, bolt = 0, 3, nil

local KINDS = {
    clear = "Ясно", partly = "Мінлива хмарність", cloudy = "Хмарно", fog = "Туман",
    drizzle = "Мряка", rain = "Дощ", snow = "Сніг", storm = "Гроза",
}

local function kind_of(code)
    if code == 0 then return "clear" end
    if code <= 2 then return "partly" end
    if code == 3 then return "cloudy" end
    if code == 45 or code == 48 then return "fog" end
    if code >= 51 and code <= 57 then return "drizzle" end
    if (code >= 61 and code <= 67) or (code >= 80 and code <= 82) then return "rain" end
    if (code >= 71 and code <= 77) or code == 85 or code == 86 then return "snow" end
    if code >= 95 then return "storm" end
    return "cloudy"
end

local function parse_cache(text)
    if not text then return nil end
    local d = { days = {} }
    for k, v in text:gmatch("(%w+)=([^\n]*)") do
        if k == "day" then
            local date, code, hi, lo = v:match("([^,]+),([^,]+),([^,]+),([^,]+)")
            d.days[#d.days + 1] = { date = date, code = tonumber(code), hi = tonumber(hi), lo = tonumber(lo) }
        else
            d[k] = tonumber(v) or v
        end
    end
    if not (d.at and d.temp and d.code) then return nil end
    return d
end

local function parse_api(body)
    local cur = body and body:match('"current":(%b{})')
    local daily = body and body:match('"daily":(%b{})')
    if not (cur and daily) then return nil end
    local lines = {
        "at=" .. os.time(),
        "temp=" .. cur:match('"temperature_2m":(-?[%d.]+)'),
        "code=" .. cur:match('"weather_code":(%d+)'),
        "wind=" .. cur:match('"wind_speed_10m":([%d.]+)'),
        "isday=" .. cur:match('"is_day":(%d)'),
    }
    local function list(name, pat)
        local out = {}
        local arr = daily:match('"' .. name .. '":(%b[])')
        for v in arr:gmatch(pat) do out[#out + 1] = v end
        return out
    end
    local dates = list("time", '"([^"]+)"')
    local codes = list("weather_code", "(-?[%d.]+)")
    local his = list("temperature_2m_max", "(-?[%d.]+)")
    local los = list("temperature_2m_min", "(-?[%d.]+)")
    for i = 1, #dates do
        lines[#lines + 1] = "day=" .. dates[i] .. "," .. codes[i] .. "," .. his[i] .. "," .. los[i]
    end
    return table.concat(lines, "\n")
end

local function load()
    local ok, text = pcall(resources.read_file, CACHE)
    data = ok and parse_cache(text) or nil
end

local function download()
    if not (http and wifi) or wifi.get_status() ~= 3 then
        status = "Wi-Fi не під'єднано"
        return
    end
    collectgarbage()
    local url = "https://api.open-meteo.com/v1/forecast?latitude=" .. LAT .. "&longitude=" .. LON
        .. "&current=temperature_2m,weather_code,wind_speed_10m,is_day"
        .. "&daily=weather_code,temperature_2m_max,temperature_2m_min&timezone=auto&forecast_days=4"
    local ok, res = pcall(http.execute, { url = url })
    local text = ok and res.code == 200 and parse_api(res.response)
    if text then
        pcall(resources.write_file, CACHE, text)
        load()
        status = nil
    else
        status = "Не вдалося завантажити"
    end
end

local function kind() return data and kind_of(data.code) or "cloudy" end
local function night()
    if data and data.isday then return data.isday == 0 end
    local h = os.date("*t").hour
    return h < 7 or h >= 19
end

local function reset_drop(d, top)
    d.x = rnd() * (W + 40) - 20
    d.y = top and -rnd() * H or rnd() * H
    d.v = 180 + rnd() * 120
end

local function reset_flake(f, top)
    f.x = rnd() * W
    f.y = top and -5 or rnd() * H
    f.v = 15 + rnd() * 25
    f.r = rnd() < 0.3 and 2 or 1
    f.ph = rnd() * 6
end

function lilka.init()
    W, H = display.width, display.height
    -- Застосунок стартує на весь екран, тож display.height = 240 навіть з fullscreen = false
    if not lilka.fullscreen and H > 216 then H = H - 24 end
    load()
    if controller and (not data or os.time() - data.at > REFRESH) then download() end
    for i = 1, 70 do drops[i] = {}; reset_drop(drops[i], false) end
    for i = 1, 60 do flakes[i] = {}; reset_flake(flakes[i], false) end
    for i = 1, 40 do stars[i] = { x = rnd() * W, y = rnd() * H * 0.5, ph = rnd() * 6 } end
    for i = 1, 6 do
        local c = { x = rnd() * W, y = 20 + rnd() * 60, v = 4 + rnd() * 6, s = 0.7 + rnd() * 0.6, parts = {} }
        for j = 1, 4 do c.parts[j] = { (j - 2.5) * 13, rnd() * 6 - 3, 12 + rnd() * 6, 7 + rnd() * 3 } end
        clouds[i] = c
    end
end

function lilka.update(delta)
    t = t + delta
    if controller then
        local st = controller.get_state()
        if st.a.just_pressed then download() end
        if st.start.just_pressed then util.exit() end
    end
    local k = kind()
    for _, c in ipairs(clouds) do
        c.x = c.x + c.v * delta
        if c.x > W + 60 then c.x = -60 end
    end
    if k == "rain" or k == "drizzle" or k == "storm" then
        for _, d in ipairs(drops) do
            d.y = d.y + d.v * delta
            d.x = d.x - d.v * 0.15 * delta
            if d.y > H then reset_drop(d, true) end
        end
    end
    if k == "snow" then
        for _, f in ipairs(flakes) do
            f.y = f.y + f.v * delta
            f.x = f.x + sin(t + f.ph) * 10 * delta
            if f.y > H then reset_flake(f, true) end
        end
    end
    if k == "storm" then
        flash = max(0, flash - delta)
        next_flash = next_flash - delta
        if next_flash <= 0 then
            flash = 0.25
            next_flash = 4 + rnd() * 8
            local x, y = 40 + rnd() * (W - 80), 0
            bolt = {}
            while y < H * 0.6 do
                local nx, ny = x + rnd() * 24 - 12, y + 10 + rnd() * 12
                bolt[#bolt + 1] = { x, y, nx, ny }
                x, y = nx, ny
            end
        end
    end
end

local function sky(k, is_night)
    local top, bot
    if is_night then
        top, bot = { 6, 10, 30 }, { 22, 30, 60 }
    elseif k == "clear" or k == "partly" then
        top, bot = { 40, 120, 220 }, { 150, 200, 245 }
    elseif k == "snow" then
        top, bot = { 95, 108, 130 }, { 150, 160, 178 }
    elseif k == "fog" then
        top, bot = { 140, 150, 165 }, { 200, 205, 212 }
    else
        top, bot = { 70, 82, 100 }, { 125, 135, 150 }
    end
    if flash > 0 then top, bot = { 200, 200, 230 }, { 230, 230, 250 } end
    for i = 0, 11 do
        local y0, y1 = floor(i * H / 12), floor((i + 1) * H / 12)
        local q = i / 11
        display.fill_rect(0, y0, W, y1 - y0, rgb(lerp(top[1], bot[1], q), lerp(top[2], bot[2], q), lerp(top[3], bot[3], q)))
    end
end

local function cloud(x, y, s, c)
    display.fill_ellipse(floor(x - 7 * s), floor(y + 2 * s), floor(8 * s), floor(5 * s), c)
    display.fill_ellipse(floor(x + 6 * s), floor(y + 2 * s), floor(8 * s), floor(5 * s), c)
    display.fill_circle(floor(x), floor(y - 2 * s), floor(7 * s), c)
end

-- Маленька іконка для прогнозу
local function icon(k, x, y)
    local sun, cl, dark = rgb(255, 210, 60), rgb(235, 235, 240), rgb(150, 160, 175)
    if k == "clear" then
        display.fill_circle(x, y, 6, sun)
    elseif k == "partly" then
        display.fill_circle(x + 4, y - 3, 5, sun)
        cloud(x - 1, y + 2, 0.55, cl)
    elseif k == "fog" then
        for i = -1, 1 do display.fill_rect(x - 8, y + i * 4, 16, 2, cl) end
    else
        cloud(x, y - 1, 0.6, (k == "cloudy" or k == "snow") and cl or dark)
        if k == "rain" or k == "drizzle" then
            for i = -1, 1 do display.draw_line(x + i * 5, y + 6, x + i * 5 - 2, y + 10, rgb(110, 170, 255)) end
        elseif k == "snow" then
            for i = -1, 1 do display.fill_rect(x + i * 5, y + 7, 2, 2, cl) end
        elseif k == "storm" then
            display.fill_triangle(x, y + 3, x - 3, y + 10, x + 2, y + 8, sun)
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

local DOW = { "Нд", "Пн", "Вт", "Ср", "Чт", "Пт", "Сб" }

local function day_name(date)
    local y, m, d = date:match("(%d+)-(%d+)-(%d+)")
    if not y then return "" end
    local ts = os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 })
    return DOW[os.date("*t", ts).wday]
end

local function round(x) return floor(x + 0.5) end

function lilka.draw()
    local k = kind()
    local is_night = night()
    sky(k, is_night)

    if is_night and (k == "clear" or k == "partly") then
        for _, s in ipairs(stars) do
            local b = 140 + 100 * sin(t * 2 + s.ph)
            display.draw_pixel(floor(s.x), floor(s.y), rgb(b, b, b * 0.9))
        end
    end

    local cx, cy = W - 60, 52
    if k == "clear" or k == "partly" then
        if is_night then
            display.fill_circle(cx, cy, 18, rgb(240, 236, 210))
            display.fill_circle(cx + 9, cy - 6, 16, rgb(14, 20, 44))
        else
            local a0 = t * 0.4
            for i = 0, 11 do
                local a = a0 + i * math.pi / 6
                local r1, r2 = 26, 34 + 3 * sin(t * 3 + i)
                display.draw_line(floor(cx + cos(a) * r1), floor(cy + sin(a) * r1), floor(cx + cos(a) * r2),
                    floor(cy + sin(a) * r2), rgb(255, 220, 90))
            end
            display.fill_circle(cx, cy, 22, rgb(255, 200, 50))
            display.fill_circle(cx, cy, 18, rgb(255, 225, 90))
        end
    end

    local cloudy = ({ clear = 0, partly = 3, cloudy = 6, fog = 6, drizzle = 6, rain = 6, snow = 6, storm = 6 })[k]
    local cc = (k == "rain" or k == "storm") and rgb(95, 100, 115) or (is_night and rgb(60, 66, 90) or rgb(240, 242, 248))
    for i = 1, cloudy do
        local c = clouds[i]
        for _, p in ipairs(c.parts) do
            display.fill_ellipse(floor(c.x + p[1] * c.s), floor(c.y + p[2] * c.s), floor(p[3] * c.s), floor(p[4] * c.s), cc)
        end
    end

    if k == "storm" and bolt and flash > 0 then
        for _, b in ipairs(bolt) do
            display.draw_line(floor(b[1]), floor(b[2]), floor(b[3]), floor(b[4]), rgb(255, 255, 220))
            display.draw_line(floor(b[1]) + 1, floor(b[2]), floor(b[3]) + 1, floor(b[4]), rgb(255, 255, 220))
        end
    end

    if k == "rain" or k == "drizzle" or k == "storm" then
        local n = k == "drizzle" and 30 or #drops
        local dc = rgb(150, 180, 230)
        for i = 1, n do
            local d = drops[i]
            local len = k == "drizzle" and 3 or 7
            display.draw_line(floor(d.x), floor(d.y), floor(d.x + len * 0.15), floor(d.y - len), dc)
        end
    elseif k == "snow" then
        local fc = rgb(255, 255, 255)
        for _, f in ipairs(flakes) do display.fill_rect(floor(f.x), floor(f.y), f.r, f.r, fc) end
    elseif k == "fog" then
        local fc = rgb(215, 218, 222)
        for i = 0, 5 do
            local y = 30 + i * 26
            local x = floor(sin(t * 0.3 + i) * 30) - 30
            display.fill_rect(x, y, W + 60, 6, fc)
        end
    end

    -- Інформація
    local white = rgb(255, 255, 255)
    local light_text = is_night or k == "rain" or k == "storm" or k == "snow"
    local soft = light_text and rgb(190, 200, 220) or rgb(40, 50, 70)
    local main = light_text and white or rgb(20, 28, 45)
    text(10, 22, CITY, soft, "8x13")
    if data then
        local tt = round(data.temp)
        local s = (tt > 0 and "+" or "") .. string.format("%d", tt)
        text(10, 68, s, main, "10x20", 2)
        local dx = 10 + utf8.len(s) * 20 + 6
        display.draw_circle(dx, 34, 4, main)
        display.draw_circle(dx, 34, 3, main)
        text(10, 88, KINDS[k], main, "7x13")
        text(10, 104, string.format("Вітер %d км/год", round(data.wind)), soft, "6x12")

        local panel_y = H - 58
        local pc = is_night and rgb(14, 20, 42) or rgb(30, 40, 60)
        display.fill_rect(6, panel_y, W - 12, 52, pc)
        local n = min(4, #data.days)
        local cw = (W - 12) / max(1, n)
        for i = 1, n do
            local d = data.days[i]
            local x = floor(6 + (i - 0.5) * cw)
            text(x - 6, panel_y + 13, i == 1 and "Сьог" or day_name(d.date), rgb(180, 190, 210), "6x12")
            icon(kind_of(d.code), x, panel_y + 26)
            text(x - 16, panel_y + 48, string.format("%d/%d", round(d.hi), round(d.lo)), white, "6x12")
        end

        local age = os.time() - data.at
        local note
        if os.time() < 1700000000 then
            note = nil
        elseif age > 6 * 3600 then
            note = "дані застаріли"
        else
            note = "оновлено " .. os.date("%H:%M", data.at)
        end
        if note then text(W - 8 - utf8.len(note) * 6, 22, note, soft, "6x12") end
    else
        text(10, 70, "Немає даних", main, "9x15")
        text(10, 92, status or "Відкрийте wallpaper.lua", soft, "6x12")
        text(10, 106, "як застосунок з Wi-Fi", soft, "6x12")
    end
    if status and data and controller then text(10, 120, status, rgb(255, 120, 100), "6x12") end
end
