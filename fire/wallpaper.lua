-- Багаття: вогонь за алгоритмом із Doom (PSX), іскри й поліна.
-- Застосунок: A — загасити або розпалити, START — вихід.

lilka.fullscreen = false

local CW, CH = 7, 6 -- розмір клітинки вогню в пікселях

local sin, floor = math.sin, math.floor
local rnd = math.random
local function min(a, b) if a < b then return a end return b end
local function max(a, b) if a > b then return a end return b end
local function clamp(x, a, b) return min(b, max(a, x)) end
local function rgb(r, g, b) return display.color565(floor(clamp(r, 0, 255)), floor(clamp(g, 0, 255)), floor(clamp(b, 0, 255))) end

-- Палітра з Doom, зведена до 12 кольорів: довші однакові відрізки — менше викликів малювання
local PAL_RGB = {
    { 7, 7, 7 }, { 47, 15, 7 }, { 87, 23, 7 }, { 119, 31, 7 }, { 159, 47, 7 }, { 191, 71, 7 },
    { 223, 87, 7 }, { 215, 103, 15 }, { 207, 127, 15 }, { 199, 151, 31 }, { 191, 175, 47 },
    { 223, 223, 159 }, { 255, 255, 255 },
}
local MAXH = 36

local W, H, FW, FH
local fire, pal, sparks = {}, {}, {}
local t, acc, burning = 0, 0, true

local function idx(x, y) return y * FW + x + 1 end

local function source_heat(x)
    local d = math.abs(x - FW / 2) / (FW * 0.24)
    if d >= 1 then return 0 end
    return floor(MAXH * (1 - d * d * 0.5))
end

function lilka.init()
    W, H = display.width, display.height
    -- Застосунок стартує на весь екран, тож display.height = 240 навіть з fullscreen = false
    if not lilka.fullscreen and H > 216 then H = H - 24 end
    FW, FH = floor(W / CW) + 1, floor((H - 24) / CH)
    for i = 1, FW * FH do fire[i] = 0 end
    for v = 0, MAXH do
        local k = v / MAXH * (#PAL_RGB - 1)
        local c = PAL_RGB[floor(k + 0.5) + 1]
        pal[v] = rgb(c[1], c[2], c[3])
    end
    for i = 1, 24 do sparks[i] = { life = 0 } end
end

local function step()
    for x = 0, FW - 1 do
        fire[idx(x, FH - 1)] = burning and source_heat(x) or 0
    end
    for y = 1, FH - 1 do
        for x = 0, FW - 1 do
            local v = fire[idx(x, y)]
            if v == 0 then
                fire[idx(x, y - 1)] = 0
            else
                local r = floor(rnd() * 3) % 3
                local dx = clamp(x + r - 1, 0, FW - 1)
                local cool = 1 + floor(rnd() * 2) % 2 + (rnd() < 0.3 and 1 or 0)
                fire[idx(dx, y - 1)] = max(0, v - cool)
            end
        end
    end
end

function lilka.update(delta)
    t = t + delta
    if controller then
        local st = controller.get_state()
        if st.a.just_pressed then burning = not burning end
        if st.start.just_pressed then util.exit() end
    end
    acc = acc + delta
    local n = 0
    while acc > 1 / 24 and n < 3 do
        step()
        acc = acc - 1 / 24
        n = n + 1
    end
    if acc > 1 / 24 then acc = 0 end
    for _, s in ipairs(sparks) do
        if s.life <= 0 then
            if burning and rnd() < delta * 2 then
                s.x = W / 2 + (rnd() - 0.5) * W * 0.4
                s.y = H - 30
                s.vx = (rnd() - 0.5) * 30
                s.vy = -40 - rnd() * 60
                s.life = 1 + rnd() * 1.5
            end
        else
            s.life = s.life - delta
            s.x = s.x + (s.vx + sin(t * 5 + s.y * 0.1) * 15) * delta
            s.y = s.y + s.vy * delta
        end
    end
end

function lilka.draw()
    display.fill_screen(pal[0])
    local fy = H - 24 - FH * CH
    for y = 0, FH - 1 do
        local x = 0
        local py = fy + y * CH
        while x < FW do
            local v = fire[idx(x, y)]
            local c = pal[v]
            local x0 = x
            x = x + 1
            while x < FW and pal[fire[idx(x, y)]] == c do x = x + 1 end
            if v > 0 then display.fill_rect(x0 * CW, py, (x - x0) * CW, CH, c) end
        end
    end

    for _, s in ipairs(sparks) do
        if s.life > 0 then
            local k = clamp(s.life, 0, 1)
            display.fill_rect(floor(s.x), floor(s.y), 2, 2, rgb(255, 160 + 80 * k, 60 * k))
        end
    end

    -- Земля й поліна
    display.fill_rect(0, H - 24, W, 24, rgb(28, 18, 14))
    local cx = W // 2
    local log, log_end, ember = rgb(84, 50, 30), rgb(150, 105, 70), rgb(255, 90, 20)
    display.fill_triangle(cx - 70, H - 10, cx - 64, H - 22, cx + 64, H - 26, log)
    display.fill_triangle(cx - 70, H - 10, cx + 64, H - 26, cx + 70, H - 14, log)
    display.fill_triangle(cx + 70, H - 10, cx + 64, H - 22, cx - 64, H - 26, rgb(70, 42, 26))
    display.fill_triangle(cx + 70, H - 10, cx - 64, H - 26, cx - 70, H - 14, rgb(70, 42, 26))
    display.fill_ellipse(cx - 67, H - 16, 4, 6, log_end)
    display.fill_ellipse(cx + 67, H - 16, 4, 6, log_end)
    if burning then
        for i = -3, 3 do
            local g = 0.5 + 0.5 * sin(t * 6 + i * 1.7)
            display.fill_circle(cx + i * 14, H - 18, 3, rgb(200 + 55 * g, 60 + 80 * g, 10))
        end
    else
        display.fill_circle(cx, H - 18, 3, ember)
    end
    for i = 0, 8 do
        local x = 20 + i * 30
        display.fill_ellipse(x, H - 4, 9, 3, rgb(48, 40, 38))
    end
end
