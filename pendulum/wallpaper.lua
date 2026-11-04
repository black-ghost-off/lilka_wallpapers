-- Подвійний маятник: п'ять маятників стартують майже однаково (різниця 0.001 радіана),
-- але за кілька секунд розходяться — це хаос. Кожні 45 секунд — новий старт.
-- Застосунок: B — новий старт, A — пауза, START — вихід.

lilka.fullscreen = false

local COUNT = 5
local SPREAD = 0.001 -- різниця початкових кутів, радіани
local DURATION = 45
local TRAIL = 90     -- точок у сліді
local G = 9.81

local floor, rnd, sin, cos = math.floor, math.random, math.sin, math.cos
local function min(a, b) if a < b then return a end return b end
local function max(a, b) if a > b then return a end return b end
local function clamp(x, a, b) return min(b, max(a, x)) end
local function rgb(r, g, b) return display.color565(floor(clamp(r, 0, 255)), floor(clamp(g, 0, 255)), floor(clamp(b, 0, 255))) end
local function hsv(h, s, v)
    h = (h % 1) * 6
    local i = floor(h) % 6
    local f = h - floor(h)
    local p, q, u = v * (1 - s), v * (1 - s * f), v * (1 - s * (1 - f))
    local r, g, b
    if i == 0 then r, g, b = v, u, p
    elseif i == 1 then r, g, b = q, v, p
    elseif i == 2 then r, g, b = p, v, u
    elseif i == 3 then r, g, b = p, q, v
    elseif i == 4 then r, g, b = u, p, v
    else r, g, b = v, p, q end
    return { r * 255, g * 255, b * 255 }
end

local function text(s, x, y, c, font)
    display.set_font(font)
    display.set_text_size(1)
    display.set_text_color(c)
    display.set_cursor(floor(x), floor(y))
    display.print(s)
end

local W, H, PX, PY, L
local pends = {}
local t, sample, paused = 0, 0, false
local C = {}

-- Похідні: стан {a1, a2, w1, w2}, маси й довжини однакові (= 1)
local function deriv(a1, a2, w1, w2)
    local d = a1 - a2
    local sd, cd = sin(d), cos(d)
    local den = 3 - cos(2 * d)
    local e1 = (-3 * G * sin(a1) - G * sin(a1 - 2 * a2) - 2 * sd * (w2 * w2 + w1 * w1 * cd)) / den
    local e2 = (2 * sd * (2 * w1 * w1 + 2 * G * cos(a1) + w2 * w2 * cd)) / den
    return w1, w2, e1, e2
end

local function rk4(p, h)
    local a1, a2, w1, w2 = p.a1, p.a2, p.w1, p.w2
    local k1a, k1b, k1c, k1d = deriv(a1, a2, w1, w2)
    local k2a, k2b, k2c, k2d = deriv(a1 + h / 2 * k1a, a2 + h / 2 * k1b, w1 + h / 2 * k1c, w2 + h / 2 * k1d)
    local k3a, k3b, k3c, k3d = deriv(a1 + h / 2 * k2a, a2 + h / 2 * k2b, w1 + h / 2 * k2c, w2 + h / 2 * k2d)
    local k4a, k4b, k4c, k4d = deriv(a1 + h * k3a, a2 + h * k3b, w1 + h * k3c, w2 + h * k3d)
    p.a1 = a1 + h / 6 * (k1a + 2 * k2a + 2 * k3a + k4a)
    p.a2 = a2 + h / 6 * (k1b + 2 * k2b + 2 * k3b + k4b)
    p.w1 = w1 + h / 6 * (k1c + 2 * k2c + 2 * k3c + k4c)
    p.w2 = w2 + h / 6 * (k1d + 2 * k2d + 2 * k3d + k4d)
end

local function tips(p)
    local x1, y1 = PX + L * sin(p.a1), PY + L * cos(p.a1)
    return x1, y1, x1 + L * sin(p.a2), y1 + L * cos(p.a2)
end

local function restart()
    local a1 = 1.8 + rnd() * 0.9 -- досить високо для хаосу
    local a2 = a1 + (rnd() - 0.5) * 1.5
    local base = rnd()
    pends = {}
    for k = 1, COUNT do
        local col = hsv(base + (k - 1) / COUNT, 0.75, 1)
        local p = { a1 = a1, a2 = a2 + (k - 1) * SPREAD, w1 = 0, w2 = 0, trail = {}, head = 0, shades = {} }
        for s = 1, 6 do p.shades[s] = rgb(col[1] * s / 7, col[2] * s / 7, col[3] * s / 7) end
        p.col = rgb(col[1], col[2], col[3])
        pends[k] = p
    end
    t, sample = 0, 0
end

function lilka.init()
    W, H = display.width, display.height
    -- Застосунок стартує на весь екран, тож display.height = 240 навіть з fullscreen = false
    if not lilka.fullscreen and H > 216 then H = H - 24 end
    L = floor(H * 0.24)
    PX, PY = W // 2, H // 2 - 4
    C.gray = rgb(120, 125, 150)
    C.arm = rgb(200, 205, 225)
    C.pivot = rgb(255, 255, 255)
    restart()
end

function lilka.update(delta)
    if controller then
        local s = controller.get_state()
        if s.start.just_pressed then util.exit() end
        if s.a.just_pressed then paused = not paused end
        if s.b.just_pressed then restart() end
    end
    if paused then return end
    delta = min(delta, 0.05)
    t = t + delta
    if t > DURATION then restart() return end
    local sub = 6
    local h = delta / sub * 1.6 -- трохи швидше за реальний час
    for _, p in ipairs(pends) do
        for _ = 1, sub do rk4(p, h) end
    end
    sample = sample + delta
    if sample >= 1 / 30 then
        sample = 0
        for _, p in ipairs(pends) do
            local _, _, x2, y2 = tips(p)
            p.head = p.head % TRAIL + 1
            p.trail[p.head] = { x2, y2 }
        end
    end
end

function lilka.draw()
    display.fill_screen(0)
    -- Сліди: старіші точки темніші
    for _, p in ipairs(pends) do
        local tr, n = p.trail, #p.trail
        local prev
        for k = n - 1, 0, -1 do
            local i = (p.head - k - 1) % TRAIL + 1
            local q = tr[i]
            if q and prev then
                local s = 1 + floor((n - k) / n * 5.99)
                display.draw_line(floor(prev[1]), floor(prev[2]), floor(q[1]), floor(q[2]), p.shades[s])
            end
            prev = q
        end
    end
    -- Маятники
    for _, p in ipairs(pends) do
        local x1, y1, x2, y2 = tips(p)
        display.draw_line(PX, PY, floor(x1), floor(y1), C.arm)
        display.draw_line(floor(x1), floor(y1), floor(x2), floor(y2), p.col)
        display.fill_circle(floor(x1), floor(y1), 3, C.arm)
        display.fill_circle(floor(x2), floor(y2), 4, p.col)
    end
    display.fill_circle(PX, PY, 3, C.pivot)
    text("Double pendulum", 4, 12, 0xFFFF, "6x13")
    local info = paused and "paused" or string.format("%d x, start +%.3f rad", COUNT, SPREAD)
    text(info, W - 4 - #info * 5, 11, C.gray, "5x7")
end
