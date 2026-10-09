-- Дощова ніч: вулиця під ліхтарем, мокрий асфальт відбиває вогні, калюжі брижаться, інколи блискавка.
-- Застосунок: START — вихід.

lilka.fullscreen = false

local sin, floor = math.sin, math.floor
local rnd = math.random
local function min(a, b) if a < b then return a end return b end
local function max(a, b) if a > b then return a end return b end
local function clamp(x, a, b) return min(b, max(a, x)) end
local function lerp(a, b, k) return a + (b - a) * k end
local function rgb(r, g, b) return display.color565(floor(clamp(r, 0, 255)), floor(clamp(g, 0, 255)), floor(clamp(b, 0, 255))) end
local function mix(c1, c2, k) return rgb(lerp(c1[1], c2[1], k), lerp(c1[2], c2[2], k), lerp(c1[3], c2[3], k)) end

-- Детермінований генератор: місто однакове при кожному запуску
local seed = 7331
local function prand()
    seed = (seed * 1103515245 + 12345) % 2147483648
    return seed / 2147483648
end

local W, H, HY, ROAD_Y
local t = 0
local far, near = {}, {}
local drops, ripples = {}, {}
local lamp, sign = {}, {}
local glints = {}
local flash, next_flash, bolt = 0, 7, {}

local SKY_TOP, SKY_LOW = { 8, 10, 22 }, { 38, 32, 54 }
local ROAD, WALK = { 14, 16, 26 }, { 30, 30, 40 }
local WARM, SOFT, COLD = { 255, 200, 110 }, { 225, 145, 70 }, { 160, 200, 255 }
local LAMP_C, NEON = { 255, 215, 150 }, { 255, 70, 160 }

local function build_layer(list, hmin, hmax, wmin, wmax, lit, sx, sy, ww, wh)
    local x = -floor(prand() * 12)
    while x < W do
        local b = { x = x, w = floor(lerp(wmin, wmax, prand())), h = floor(lerp(hmin, hmax, prand())), wins = {} }
        for wy = HY - b.h + 6, HY - 10, sy do
            for wx = b.x + 3, b.x + b.w - ww - 3, sx do
                if prand() < lit then
                    local r = prand()
                    b.wins[#b.wins + 1] = { x = wx, y = wy, c = r < 0.6 and WARM or (r < 0.85 and SOFT or COLD), on = true }
                end
            end
        end
        b.ww, b.wh = ww, wh
        list[#list + 1] = b
        x = x + b.w + floor(prand() * 3)
    end
end

local function new_drop(d, anywhere)
    d = d or {}
    d.near = rnd() < 0.35
    d.v = d.near and 300 + rnd() * 80 or 190 + rnd() * 60
    d.len = d.near and 9 + floor(rnd() * 5) or 4 + floor(rnd() * 3)
    d.x = rnd() * (W + 60)
    d.y = anywhere and rnd() * H or -rnd() * 60
    -- Ближчі краплі падають нижче на дорогу
    d.gy = d.near and lerp(ROAD_Y + 20, H - 2, rnd()) or lerp(HY + 2, ROAD_Y + 24, rnd())
    return d
end

function lilka.init()
    W, H = display.width, display.height
    -- Застосунок стартує на весь екран, тож display.height = 240 навіть з fullscreen = false
    if not lilka.fullscreen and H > 216 then H = H - 24 end
    HY = floor(H * 0.64)
    ROAD_Y = HY + 9

    build_layer(far, 50, 100, 22, 40, 0.10, 6, 7, 2, 3)
    build_layer(near, 34, 82, 30, 54, 0.16, 7, 9, 3, 4)

    lamp = { x = floor(W * 0.2), top = HY - 74 }
    lamp.hx, lamp.hy = lamp.x + 11, lamp.top + 4

    local sb = near[1]
    for _, b in ipairs(near) do
        if b.x <= W * 0.66 and b.x + b.w > W * 0.66 then sb = b end
    end
    sign = { x = sb.x + floor(sb.w / 2) - 16, y = HY - 26, w = 32, h = 15 }

    -- Відблиски на мокрій дорозі: ліхтар, вивіска і кілька нижніх вікон
    local low = {}
    for _, b in ipairs(near) do
        for _, w in ipairs(b.wins) do
            if w.y > HY - 34 and (w.x + 3 < sign.x or w.x > sign.x + sign.w) then low[#low + 1] = w end
        end
    end
    for i = 1, min(4, #low) do glints[i] = low[1 + floor(prand() * #low) % #low] end

    for i = 1, 80 do drops[i] = new_drop(nil, true) end
end

local function strike()
    flash = 0.45
    next_flash = 9 + rnd() * 16
    bolt = {}
    local x, y = 30 + rnd() * (W - 60), 0
    bolt[1] = { x, y }
    while y < HY - 50 do
        y = y + 6 + rnd() * 10
        x = x + (rnd() - 0.5) * 18
        bolt[#bolt + 1] = { x, y }
    end
end

function lilka.update(delta)
    t = t + delta
    if controller and controller.get_state().start.just_pressed then util.exit() end

    local wind = 0.22 + 0.1 * sin(t * 0.25)
    for _, d in ipairs(drops) do
        d.y = d.y + d.v * delta
        d.x = d.x - d.v * wind * delta
        if d.y >= d.gy then
            if d.gy > ROAD_Y and #ripples < 24 then
                ripples[#ripples + 1] = { x = d.x, y = d.gy, age = 0, big = d.near }
            elseif d.gy <= ROAD_Y and #ripples < 24 then
                ripples[#ripples + 1] = { x = d.x, y = d.gy, age = 0, splash = true }
            end
            new_drop(d, false)
        end
    end
    for i = #ripples, 1, -1 do
        local r = ripples[i]
        r.age = r.age + delta
        if r.age > (r.splash and 0.18 or 0.6) then table.remove(ripples, i) end
    end

    -- Хтось вмикає чи вимикає світло
    if rnd() < delta * 0.25 then
        local b = near[1 + floor(rnd() * #near) % #near]
        if #b.wins > 0 then
            local w = b.wins[1 + floor(rnd() * #b.wins) % #b.wins]
            w.on = not w.on
        end
    end

    flash = max(0, flash - delta)
    next_flash = next_flash - delta
    if next_flash <= 0 then strike() end
end

local function lamp_lit(x, y)
    if y < lamp.hy or y > HY then return false end
    return math.abs(x - lamp.hx) < (y - lamp.hy) * 28 / (HY - lamp.hy) + 4
end

-- Відблиск: тремтливі горизонтальні риски під джерелом світла
local function reflection(x, half, c, ph, strength, f)
    local road = { ROAD[1] + 40 * f, ROAD[2] + 40 * f, ROAD[3] + 55 * f }
    for y = ROAD_Y + 2, H - 1, 3 do
        local k = 1 - (y - ROAD_Y) / (H - ROAD_Y)
        local j = sin(t * 3.5 + y * 0.8 + ph) * (1.5 + (1 - k) * 3)
        local hw = max(1, floor(half * (0.5 + 0.5 * k) + sin(t * 5 + y + ph)))
        display.draw_line(floor(x + j - hw), y, floor(x + j + hw), y, mix(road, c, strength * (0.3 + 0.7 * k)))
    end
end

function lilka.draw()
    local f = 0
    if flash > 0 then f = (sin(flash * 45) > 0 and 1 or 0.35) * min(1, flash * 4) end

    -- Небо з відсвітом міста
    for i = 0, 7 do
        local y0, y1 = floor(i * HY / 8), floor((i + 1) * HY / 8)
        local k = (i / 7) ^ 1.5
        display.fill_rect(0, y0, W, y1 - y0, rgb(lerp(SKY_TOP[1], SKY_LOW[1], k) + 80 * f,
            lerp(SKY_TOP[2], SKY_LOW[2], k) + 80 * f, lerp(SKY_TOP[3], SKY_LOW[3], k) + 100 * f))
    end
    if f > 0.5 then
        local bc = rgb(235, 235, 255)
        for i = 2, #bolt do
            display.draw_line(floor(bolt[i - 1][1]), floor(bolt[i - 1][2]), floor(bolt[i][1]), floor(bolt[i][2]), bc)
        end
    end

    -- Будинки
    local fc, nc = rgb(24 + 10 * f, 25 + 10 * f, 42 + 14 * f), rgb(12, 13, 22)
    for _, b in ipairs(far) do
        display.fill_rect(b.x, HY - b.h, b.w, b.h, fc)
    end
    for _, b in ipairs(far) do
        for _, w in ipairs(b.wins) do display.fill_rect(w.x, w.y, b.ww, b.wh, mix({ 24, 25, 42 }, w.c, 0.45)) end
    end
    local edge = rgb(30 + 30 * f, 31 + 30 * f, 46 + 40 * f)
    for _, b in ipairs(near) do
        display.fill_rect(b.x, HY - b.h, b.w, b.h, nc)
        display.fill_rect(b.x, HY - b.h, b.w, 1, edge)
    end
    -- Світловий конус ліхтаря в дощовому тумані
    for i, k in ipairs({ 0.06, 0.1 }) do
        local c, s = mix({ 12, 13, 22 }, LAMP_C, k), 34 - i * 10
        display.fill_triangle(lamp.hx - 3, lamp.hy + 3, lamp.hx + 3, lamp.hy + 3, lamp.hx + s, HY, c)
        display.fill_triangle(lamp.hx - 3, lamp.hy + 3, lamp.hx - s, HY, lamp.hx + s, HY, c)
    end
    for _, b in ipairs(near) do
        for _, w in ipairs(b.wins) do
            if w.on then display.fill_rect(w.x, w.y, b.ww, b.wh, rgb(w.c[1], w.c[2], w.c[3])) end
        end
    end

    -- Неонова вивіска, що інколи блимає
    local neon_on = not (t % 9 > 8.2 and sin(t * 60) > 0)
    local nk = neon_on and 1 or 0.25
    display.fill_rect(sign.x - 1, sign.y - 1, sign.w + 2, sign.h + 2, mix({ 12, 13, 22 }, NEON, 0.25 * nk))
    display.fill_rect(sign.x, sign.y, sign.w, sign.h, rgb(20, 10, 22))
    display.draw_rect(sign.x, sign.y, sign.w, sign.h, mix({ 20, 10, 22 }, NEON, nk))
    display.set_font("6x12")
    display.set_text_size(1)
    display.set_text_color(mix({ 20, 10, 22 }, { 255, 160, 210 }, nk))
    display.set_cursor(sign.x + 4, sign.y + 12)
    display.print("КАВА")

    -- Тротуар і дорога
    display.fill_rect(0, HY, W, ROAD_Y - HY, rgb(WALK[1] + 40 * f, WALK[2] + 40 * f, WALK[3] + 50 * f))
    display.fill_ellipse(lamp.hx, HY + 4, 36, 4, mix(WALK, LAMP_C, 0.3))
    display.fill_ellipse(lamp.hx, HY + 4, 20, 2, mix(WALK, LAMP_C, 0.5))
    display.fill_rect(0, ROAD_Y - 1, W, 2, rgb(52, 52, 64))
    display.fill_rect(0, ROAD_Y + 1, W, H - ROAD_Y - 1, rgb(ROAD[1] + 40 * f, ROAD[2] + 40 * f, ROAD[3] + 55 * f))

    reflection(lamp.hx, 5, LAMP_C, 0, 0.75, f)
    reflection(sign.x + sign.w / 2, 11, NEON, 2, 0.6 * nk, f)
    for i, w in ipairs(glints) do
        if w.on then reflection(w.x + 1, 1, w.c, i * 1.7, 0.4, f) end
    end

    -- Ліхтар
    local pole = rgb(34, 34, 42)
    display.fill_rect(lamp.x - 1, lamp.top, 3, HY + 6 - lamp.top, pole)
    display.fill_rect(lamp.x - 3, HY + 2, 7, 5, pole)
    display.draw_line(lamp.x, lamp.top, lamp.hx, lamp.top, pole)
    display.draw_line(lamp.x, lamp.top + 1, lamp.hx, lamp.top + 1, pole)
    local glow = 0.93 + 0.07 * sin(t * 13)
    display.fill_circle(lamp.hx, lamp.hy + 2, 13, mix({ 26, 24, 40 }, LAMP_C, 0.3 * glow))
    display.fill_circle(lamp.hx, lamp.hy + 2, 8, mix({ 26, 24, 40 }, LAMP_C, 0.55 * glow))
    display.fill_circle(lamp.hx, lamp.hy + 2, 4, mix({ 26, 24, 40 }, LAMP_C, 0.85 * glow))
    display.fill_triangle(lamp.hx - 6, lamp.hy, lamp.hx + 6, lamp.hy, lamp.hx, lamp.hy - 5, pole)
    display.fill_circle(lamp.hx, lamp.hy + 1, 2, rgb(255, 245, 210))

    -- Брижі на калюжах і бризки на тротуарі
    for _, r in ipairs(ripples) do
        if r.splash then
            display.draw_pixel(floor(r.x - 1), floor(r.y - 1 - r.age * 10), rgb(110, 120, 150))
            display.draw_pixel(floor(r.x + 1), floor(r.y - 1 - r.age * 10), rgb(110, 120, 150))
        else
            local k = r.age / 0.6
            local rx = 1 + floor(k * (r.big and 8 or 5))
            local base = lamp_lit(r.x, ROAD_Y) and math.abs(r.x - lamp.hx) < 30 and { 200, 170, 120 } or { 120, 130, 170 }
            display.draw_ellipse(floor(r.x), floor(r.y), rx, max(1, rx // 3), mix(base, ROAD, k))
        end
    end

    -- Дощ: далекий тьмяний, близький яскравий, у світлі ліхтаря теплий
    local wind = 0.22 + 0.1 * sin(t * 0.25)
    local far_c, near_c = rgb(60 + 60 * f, 68 + 60 * f, 96 + 60 * f), rgb(118 + 60 * f, 128 + 60 * f, 165 + 60 * f)
    local lit_far, lit_near = rgb(190, 160, 110), rgb(255, 230, 170)
    for _, d in ipairs(drops) do
        local x, y = floor(d.x), floor(d.y)
        local c
        if lamp_lit(x, y) then c = d.near and lit_near or lit_far else c = d.near and near_c or far_c end
        display.draw_line(x, y, floor(x + d.len * wind), y - d.len, c)
    end
end
