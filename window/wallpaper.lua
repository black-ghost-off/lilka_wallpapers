-- Живе вікно: небо над містом за справжнім часом.
-- Сонце й місяць (з фазою) ходять за астрономією для Києва, місяць видно після заходу сонця, вікна вмикаються ввечері.
-- Застосунок: A — прискорена доба, START — вихід.

lilka.fullscreen = false

local LAT, LON = 50.45, 30.52

local sin, cos, asin, atan2, sqrt, floor = math.sin, math.cos, math.asin, math.atan2, math.sqrt, math.floor
local rnd = math.random
local D2R = math.pi / 180

local function min(a, b) if a < b then return a end return b end
local function max(a, b) if a > b then return a end return b end
local function clamp(x, a, b) return min(b, max(a, x)) end
local function lerp(a, b, k) return a + (b - a) * k end
local function rgb(r, g, b) return display.color565(floor(clamp(r, 0, 255)), floor(clamp(g, 0, 255)), floor(clamp(b, 0, 255))) end
local function mix(c1, c2, k) return { lerp(c1[1], c2[1], k), lerp(c1[2], c2[2], k), lerp(c1[3], c2[3], k) } end

-- Детермінований генератор: місто однакове при кожному запуску
local seed = 20250
local function prand()
    seed = (seed * 1103515245 + 12345) % 2147483648
    return seed / 2147483648
end

local W, H, HY
local t, fast = 0, false
local stars, clouds, layers = {}, {}, {}
local sun_alt, sun_az, moon_alt, moon_az, moon_phase, light, minutes = 0, 0, 0, 0, 0, 1, 720

-- Колір неба (верх, горизонт) залежно від висоти сонця
local SKY = {
    { -18, { 4, 6, 20 }, { 12, 16, 38 } },
    { -10, { 10, 14, 44 }, { 34, 34, 80 } },
    { -4, { 26, 34, 90 }, { 190, 95, 90 } },
    { 0, { 50, 80, 160 }, { 255, 145, 85 } },
    { 8, { 65, 125, 215 }, { 250, 195, 150 } },
    { 25, { 50, 130, 230 }, { 165, 205, 245 } },
}

local function sky_colors(alt)
    if alt <= SKY[1][1] then return SKY[1][2], SKY[1][3] end
    for i = 2, #SKY do
        local a, b = SKY[i - 1], SKY[i]
        if alt <= b[1] then
            local k = (alt - a[1]) / (b[1] - a[1])
            return mix(a[2], b[2], k), mix(a[3], b[3], k)
        end
    end
    return SKY[#SKY][2], SKY[#SKY][3]
end

-- Висота й азимут (від півдня, захід додатний) для години UTC
local function sky_pos(utc_hours, decl, offset_deg)
    local ha = (15 * (utc_hours - 12) + LON - offset_deg) * D2R
    local lat = LAT * D2R
    local alt = asin(sin(lat) * sin(decl) + cos(lat) * cos(decl) * cos(ha))
    local az = atan2(sin(ha), cos(ha) * sin(lat) - sin(decl) / cos(decl) * cos(lat))
    return alt / D2R, az / D2R
end

local function update_sky(now)
    local u = os.date("!*t", now)
    local l = os.date("*t", now)
    minutes = l.hour * 60 + l.min
    local hours = u.hour + u.min / 60 + u.sec / 3600
    local decl = -23.44 * cos(2 * math.pi * (u.yday + 10) / 365) * D2R
    sun_alt, sun_az = sky_pos(hours, decl, 0)
    -- Вік місяця від відомого молодика 6.01.2000 18:14 UTC; великі числа — без math.*
    local age = ((now - 947182440) / 86400) % 29.530588853
    moon_phase = age / 29.530588853
    moon_alt, moon_az = sky_pos(hours, decl * cos(2 * math.pi * moon_phase), moon_phase * 360)
    light = clamp((sun_alt + 8) / 20, 0, 1)
end

local function screen_x(az) return W / 2 + az / 110 * (W / 2) end
local function screen_y(alt) return HY - alt / 60 * (HY - 10) end

local function build()
    for i = 1, 70 do
        stars[i] = { x = prand() * W, y = prand() * HY * 0.95, b = 0.4 + prand() * 0.6, ph = prand() * 6 }
    end
    for i = 1, 5 do
        local c = { x = prand() * (W + 80) - 40, y = 15 + prand() * HY * 0.45, v = 3 + prand() * 5, parts = {} }
        for j = 1, 4 do
            c.parts[j] = { (j - 2.5) * 11 + prand() * 6, prand() * 4 - 2, 9 + prand() * 6, 5 + prand() * 3 }
        end
        clouds[i] = c
    end
    local defs = {
        { hmin = 0.18, hmax = 0.36, wmin = 14, wmax = 28, base = { 40, 50, 70 }, night = { 14, 16, 30 }, win = 2, step = 5 },
        { hmin = 0.24, hmax = 0.46, wmin = 18, wmax = 32, base = { 60, 66, 84 }, night = { 10, 11, 22 }, win = 2, step = 6 },
        { hmin = 0.30, hmax = 0.58, wmin = 26, wmax = 44, base = { 82, 80, 92 }, night = { 6, 6, 14 }, win = 3, step = 7 },
    }
    for li, d in ipairs(defs) do
        local layer = { def = d, b = {} }
        local x = -prand() * 10
        while x < W do
            local w = floor(lerp(d.wmin, d.wmax, prand()))
            local h = floor(lerp(d.hmin, d.hmax, prand()) * H)
            local b = { x = floor(x), w = w, h = h, wins = {}, roof = prand() < 0.3 }
            if li > 1 then
                for wy = H - h + 6, H - 6, d.step + 1 do
                    for wx = b.x + 3, b.x + w - d.win - 3, d.step do
                        if prand() < 0.55 then
                            b.wins[#b.wins + 1] = {
                                x = wx, y = wy, th = 0.35 + prand() * 0.5,
                                wake = 330 + prand() * 150, sleep = 1290 + prand() * 240,
                                tv = prand() < 0.12, ph = prand() * 6,
                            }
                        end
                    end
                end
            end
            layer.b[#layer.b + 1] = b
            x = x + w + floor(prand() * 4)
        end
        layers[li] = layer
    end
end

function lilka.init()
    W, H = display.width, display.height
    -- Застосунок стартує на весь екран, тож display.height = 240 навіть з fullscreen = false
    if not lilka.fullscreen and H > 216 then H = H - 24 end
    HY = floor(H * 0.78)
    build()
end

function lilka.update(delta)
    t = t + delta
    if controller then
        local st = controller.get_state()
        if st.a.just_pressed then fast = not fast end
        if st.start.just_pressed then util.exit() end
    end
    local now = os.time()
    if now < 1700000000 or fast then
        now = 1791460800 + floor(t * 1440) -- доба за хвилину, поки немає годинника
    end
    update_sky(now)
    for _, c in ipairs(clouds) do
        c.x = c.x + c.v * delta
        if c.x > W + 50 then c.x = -50 end
    end
end

local function draw_moon(x, y, r, lit, dark)
    display.fill_circle(floor(x), floor(y), r, dark)
    local c = cos(2 * math.pi * moon_phase)
    for dy = -r, r do
        local w = sqrt(r * r - dy * dy)
        local xt = w * c
        if moon_phase < 0.5 then
            display.draw_line(floor(x + xt), floor(y + dy), floor(x + w), floor(y + dy), lit)
        else
            display.draw_line(floor(x - w), floor(y + dy), floor(x - xt), floor(y + dy), lit)
        end
    end
end

local function window_on(w)
    if light > w.th then return false end
    if minutes >= w.wake and minutes < w.sleep then return true end
    return w.sleep > 1440 and minutes < w.sleep - 1440
end

function lilka.draw()
    local top, hor = sky_colors(sun_alt)
    local bands = 16
    for i = 0, bands - 1 do
        local k = (i / (bands - 1)) ^ 1.6
        local c = mix(top, hor, k)
        local y0 = floor(i * HY / bands)
        local y1 = floor((i + 1) * HY / bands)
        display.fill_rect(0, y0, W, y1 - y0, rgb(c[1], c[2], c[3]))
    end
    display.fill_rect(0, HY, W, H - HY, rgb(hor[1], hor[2], hor[3]))

    local dark = clamp((-sun_alt - 4) / 10, 0, 1)
    if dark > 0.05 then
        for _, s in ipairs(stars) do
            local b = s.b * dark * (0.75 + 0.25 * sin(t * 2.5 + s.ph))
            local c = mix(top, { 255, 250, 230 }, b)
            display.draw_pixel(floor(s.x), floor(s.y), rgb(c[1], c[2], c[3]))
        end
    end

    -- Місяць проступає лише після заходу сонця
    local moon_k = clamp((-sun_alt - 1) / 7, 0, 1)
    if moon_alt > -4 and moon_k > 0 then
        local mx, my = screen_x(moon_az), screen_y(moon_alt)
        local lit = mix(top, { 245, 240, 215 }, 0.95 * moon_k)
        local shade = mix(top, { 60, 70, 100 }, 0.25 * moon_k)
        draw_moon(mx, my, 9, rgb(lit[1], lit[2], lit[3]), rgb(shade[1], shade[2], shade[3]))
    end

    if sun_alt > -4 then
        local sx, sy = screen_x(sun_az), screen_y(sun_alt)
        local warm = clamp(sun_alt / 15, 0, 1)
        local disk = mix({ 255, 150, 70 }, { 255, 245, 210 }, warm)
        local g1 = mix(hor, disk, 0.35)
        local g2 = mix(hor, disk, 0.6)
        display.fill_circle(floor(sx), floor(sy), 20, rgb(g1[1], g1[2], g1[3]))
        display.fill_circle(floor(sx), floor(sy), 15, rgb(g2[1], g2[2], g2[3]))
        display.fill_circle(floor(sx), floor(sy), 11, rgb(disk[1], disk[2], disk[3]))
    end

    local cloud = mix(mix(hor, { 255, 255, 255 }, 0.55), { 40, 44, 64 }, 1 - light)
    local cc = rgb(cloud[1], cloud[2], cloud[3])
    for _, c in ipairs(clouds) do
        for _, p in ipairs(c.parts) do
            display.fill_ellipse(floor(c.x + p[1]), floor(c.y + p[2]), floor(p[3]), floor(p[4]), cc)
        end
    end

    for li, layer in ipairs(layers) do
        local d = layer.def
        local haze = (3 - li) * 0.22
        local base = mix(mix(d.night, d.base, light), hor, haze)
        local bc = rgb(base[1], base[2], base[3])
        local edge = mix(base, { 0, 0, 0 }, 0.25)
        local ec = rgb(edge[1], edge[2], edge[3])
        for _, b in ipairs(layer.b) do
            display.fill_rect(b.x, H - b.h, b.w, b.h, bc)
            display.fill_rect(b.x + b.w - 2, H - b.h, 2, b.h, ec)
            if b.roof then display.fill_rect(b.x + b.w // 2 - 1, H - b.h - 6, 2, 6, ec) end
        end
        if li == 1 then
            -- Київська телевежа
            local tx = floor(W * 0.68)
            display.fill_rect(tx - 3, H - floor(H * 0.55), 6, floor(H * 0.55), bc)
            display.fill_rect(tx - 1, H - floor(H * 0.72), 2, floor(H * 0.17), bc)
            if dark > 0.2 and sin(t * 3) > 0 then
                display.fill_rect(tx - 1, H - floor(H * 0.72) - 1, 2, 2, rgb(255, 40, 40))
            end
        end
        if li == 3 and light > 0.4 then
            local g = mix(base, top, 0.45 * light)
            local gc = rgb(g[1], g[2], g[3])
            for _, b in ipairs(layer.b) do
                for _, w in ipairs(b.wins) do display.fill_rect(w.x, w.y, d.win, d.win, gc) end
            end
        elseif li > 1 then
            local warm = rgb(255, 205, 110)
            local soft = rgb(230, 160, 80)
            for _, b in ipairs(layer.b) do
                for _, w in ipairs(b.wins) do
                    if window_on(w) then
                        local c = w.th > 0.6 and soft or warm
                        if w.tv then
                            local f = 0.6 + 0.4 * sin(t * 7 + w.ph)
                            c = rgb(90 * f + 40, 140 * f + 50, 255 * f)
                        end
                        display.fill_rect(w.x, w.y, d.win, d.win, c)
                    end
                end
            end
        end
    end

    -- Рама вікна
    local frame = rgb(48, 34, 26)
    local frame_hi = rgb(88, 64, 46)
    display.fill_rect(0, 0, W, 4, frame)
    display.fill_rect(0, H - 4, W, 4, frame)
    display.fill_rect(0, 0, 4, H, frame)
    display.fill_rect(W - 4, 0, 4, H, frame)
    display.fill_rect(W // 2 - 2, 0, 4, H, frame)
    display.fill_rect(0, floor(H * 0.42) - 2, W, 4, frame)
    display.fill_rect(W // 2 - 2, 0, 1, H, frame_hi)
    display.fill_rect(0, floor(H * 0.42) - 2, W, 1, frame_hi)
end
