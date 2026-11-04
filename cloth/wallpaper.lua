-- Прапор на вітрі: тканина — сітка точок на пружинах (інтеграція Верле), вітер міняє силу й пориви.
-- Складки темніші, бо там тканина стиснута. Над прапором пливуть хмари.
-- Застосунок: A — пауза, B — сильний порив, START — вихід.

lilka.fullscreen = false

local NX, NY = 22, 14   -- точок по горизонталі й вертикалі
local GAP = 7           -- відстань між точками, px
local ITER = 3          -- проходів обмежень за крок
local GRAVITY = 170
local WIND = 640

local floor, rnd, sin, cos, sqrt = math.floor, math.random, math.sin, math.cos, math.sqrt
local function min(a, b) if a < b then return a end return b end
local function max(a, b) if a > b then return a end return b end
local function clamp(x, a, b) return min(b, max(a, x)) end
local function rgb(r, g, b) return display.color565(floor(clamp(r, 0, 255)), floor(clamp(g, 0, 255)), floor(clamp(b, 0, 255))) end

local W, H, POLE_X, POLE_Y
local x, y, ox, oy = {}, {}, {}, {}
local t, paused, gust = 0, false, 0
local SHADES = 10
local blue, yellow = {}, {}
local sky = {}
local clouds = {}
local C = {}

local function id(i, j) return j * NX + i end

local function reset()
    for j = 0, NY - 1 do
        for i = 0, NX - 1 do
            local k = id(i, j)
            x[k], y[k] = POLE_X + i * GAP, POLE_Y + j * GAP
            ox[k], oy[k] = x[k], y[k]
        end
    end
end

function lilka.init()
    W, H = display.width, display.height
    -- Застосунок стартує на весь екран, тож display.height = 240 навіть з fullscreen = false
    if not lilka.fullscreen and H > 216 then H = H - 24 end
    POLE_X, POLE_Y = 60, 34
    for s = 0, SHADES - 1 do
        local k = 0.45 + 0.55 * s / (SHADES - 1)
        blue[s] = rgb(0 * k, 91 * k + 10, 187 * k + 20)
        yellow[s] = rgb(255 * k, 213 * k, 0)
    end
    for k = 0, 15 do
        local u = k / 15
        sky[k] = rgb(40 + 90 * u, 90 + 90 * u, 170 + 60 * u)
    end
    C.pole = rgb(170, 170, 180)
    C.pole_dark = rgb(90, 90, 100)
    C.cloud = rgb(235, 240, 250)
    C.cloud2 = rgb(205, 215, 235)
    C.ground = rgb(60, 110, 50)
    C.ground2 = rgb(45, 90, 40)
    for k = 1, 5 do
        clouds[k] = { x = rnd() * W, y = 10 + rnd() * (H * 0.45), s = 0.6 + rnd() * 0.8, v = 4 + rnd() * 8 }
    end
    reset()
end

local function step(dt)
    local dt2 = dt * dt
    -- Вітер: базова сила повільно дихає, хвиля біжить уздовж прапора, плюс пориви
    local base = WIND * (0.75 + 0.18 * sin(t * 0.37) + 0.1 * sin(t * 1.3)) + gust * 600
    for j = 0, NY - 1 do
        for i = 1, NX - 1 do
            local k = id(i, j)
            local wx = base * (0.7 + 0.3 * sin(t * 5.1 - i * 0.55 + j * 0.2))
            local wy = base * 0.35 * sin(t * 3.7 - i * 0.6 + j * 0.45)
            local nx, ny = x[k], y[k]
            local vx, vy = (nx - ox[k]) * 0.985, (ny - oy[k]) * 0.985
            ox[k], oy[k] = nx, ny
            x[k] = nx + vx + wx * dt2
            y[k] = ny + vy + (GRAVITY + wy) * dt2
        end
    end
    for _ = 1, ITER do
        for j = 0, NY - 1 do
            for i = 0, NX - 1 do
                local a = id(i, j)
                -- Праворуч і вниз; лівий стовпчик прибитий до древка
                for d = 1, 2 do
                    local b
                    if d == 1 and i < NX - 1 then b = a + 1 elseif d == 2 and j < NY - 1 then b = a + NX end
                    if b then
                        local dx, dy = x[b] - x[a], y[b] - y[a]
                        local dist = sqrt(dx * dx + dy * dy)
                        if dist > 0.001 then
                            local diff = (dist - GAP) / dist * 0.5
                            local pa, pb = i > 0, (b % NX) > 0
                            if not pa then diff = diff * 2 end
                            if pa then x[a], y[a] = x[a] + dx * diff, y[a] + dy * diff end
                            if pb then x[b], y[b] = x[b] - dx * diff, y[b] - dy * diff end
                        end
                    end
                end
            end
        end
        for j = 0, NY - 1 do -- древко
            local k = id(0, j)
            x[k], y[k] = POLE_X, POLE_Y + j * GAP
        end
    end
end

function lilka.update(delta)
    if controller then
        local s = controller.get_state()
        if s.start.just_pressed then util.exit() end
        if s.a.just_pressed then paused = not paused end
        if s.b.just_pressed then gust = 1 end
    end
    if paused then return end
    delta = min(delta, 0.05)
    t = t + delta
    -- Випадкові пориви
    if gust <= 0.01 and rnd() < delta * 0.08 then gust = 0.6 + rnd() * 0.4 end
    gust = gust * (0.6 ^ delta)
    for _, c in ipairs(clouds) do
        c.x = c.x + c.v * delta * (1 + gust)
        if c.x > W + 40 then c.x, c.y = -40, 10 + rnd() * (H * 0.45) end
    end
    local sub = 2
    for _ = 1, sub do step(delta / sub) end
end

local function cloud(c)
    local s = c.s
    local cx, cy = floor(c.x), floor(c.y)
    display.fill_circle(cx, cy, floor(9 * s), C.cloud2)
    display.fill_circle(cx + floor(12 * s), cy - floor(5 * s), floor(11 * s), C.cloud)
    display.fill_circle(cx + floor(26 * s), cy, floor(8 * s), C.cloud2)
    display.fill_rect(cx, cy, floor(26 * s), floor(8 * s), C.cloud2)
end

function lilka.draw()
    -- Небо смугами
    local band = H / 16
    for k = 0, 15 do display.fill_rect(0, floor(k * band), W, floor(band) + 1, sky[k]) end
    for _, c in ipairs(clouds) do cloud(c) end
    display.fill_rect(0, H - 18, W, 18, C.ground)
    display.fill_rect(0, H - 18, W, 3, C.ground2)
    -- Древко
    display.fill_rect(POLE_X - 3, POLE_Y - 8, 4, H - POLE_Y - 10, C.pole)
    display.fill_rect(POLE_X, POLE_Y - 8, 1, H - POLE_Y - 10, C.pole_dark)
    display.fill_circle(POLE_X - 1, POLE_Y - 9, 3, rgb(230, 200, 90))
    -- Тканина: кожна клітинка — два трикутники; світлість залежить від ширини клітинки
    local half = (NY - 1) / 2
    for j = 0, NY - 2 do
        local pal = j < half and blue or yellow
        for i = 0, NX - 2 do
            local a = id(i, j)
            local b, c, d = a + 1, a + NX, a + NX + 1
            local w = (x[b] - x[a] + x[d] - x[c]) / (2 * GAP)
            local tilt = (y[b] - y[a]) / GAP
            local s = clamp(floor((w * 0.9 - tilt * 0.35) * (SHADES - 1)), 0, SHADES - 1)
            local col = pal[s]
            local ax, ay, bx, by = floor(x[a]), floor(y[a]), floor(x[b]), floor(y[b])
            local cx, cy, dx, dy = floor(x[c]), floor(y[c]), floor(x[d]), floor(y[d])
            display.fill_triangle(ax, ay, bx, by, cx, cy, col)
            display.fill_triangle(bx, by, dx, dy, cx, cy, col)
        end
    end
end
