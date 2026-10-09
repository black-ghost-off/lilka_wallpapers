-- Зграя птахів (boids) над соняшниковим полем на заході сонця.
-- Кожен птах тримається сусідів, летить у їхній бік і не врізається в них.
-- Застосунок: START — вихід.

lilka.fullscreen = false

local N = 34

local sin, sqrt, floor = math.sin, math.sqrt, math.floor
local rnd = math.random
local function min(a, b) if a < b then return a end return b end
local function max(a, b) if a > b then return a end return b end
local function clamp(x, a, b) return min(b, max(a, x)) end
local function lerp(a, b, k) return a + (b - a) * k end
local function rgb(r, g, b) return display.color565(floor(clamp(r, 0, 255)), floor(clamp(g, 0, 255)), floor(clamp(b, 0, 255))) end

local seed = 31
local function prand()
    seed = (seed * 1103515245 + 12345) % 2147483648
    return seed / 2147483648
end

local W, H, HY
local t = 0
local birds, rows, sky = {}, {}, {}
local goal = { x = 0, y = 0 }

function lilka.init()
    W, H = display.width, display.height
    -- Застосунок стартує на весь екран, тож display.height = 240 навіть з fullscreen = false
    if not lilka.fullscreen and H > 216 then H = H - 24 end
    HY = floor(H * 0.6)
    for i = 1, N do
        local a = rnd() * 6.28
        birds[i] = { x = W * 0.3 + rnd() * 60, y = 30 + rnd() * 40, vx = math.cos(a) * 30, vy = sin(a) * 30, ph = rnd() * 6 }
    end
    for i = 0, 11 do
        local k = i / 11
        sky[i] = rgb(lerp(60, 255, k ^ 1.5), lerp(50, 150, k ^ 1.3), lerp(120, 90, k))
    end
    -- Ряди соняшників від горизонту до глядача: далі — менші й тісніші
    for r = 1, 7 do
        local k = r / 7
        local y = HY + (H - HY) * k ^ 1.6
        local size = 1 + k * k * 9
        local row = { y = y, size = size, k = k, items = {} }
        local x = -prand() * 10
        while x < W + 10 do
            row.items[#row.items + 1] = { x = x, h = size * (2 + prand()), ph = prand() * 6 }
            x = x + size * 2.4 + prand() * size
        end
        rows[r] = row
    end
end

function lilka.update(delta)
    t = t + delta
    if controller and controller.get_state().start.just_pressed then util.exit() end
    local dt = min(delta, 0.05)
    goal.x = W / 2 + sin(t * 0.23) * W * 0.38
    goal.y = HY * 0.42 + sin(t * 0.41) * HY * 0.25
    for i = 1, N do
        local b = birds[i]
        local cx, cy, ax, ay, sx, sy, n = 0, 0, 0, 0, 0, 0, 0
        for j = 1, N do
            if j ~= i then
                local o = birds[j]
                local dx, dy = o.x - b.x, o.y - b.y
                local d2 = dx * dx + dy * dy
                if d2 < 900 then
                    cx, cy = cx + o.x, cy + o.y
                    ax, ay = ax + o.vx, ay + o.vy
                    n = n + 1
                    if d2 < 196 and d2 > 0 then sx, sy = sx - dx / d2 * 14, sy - dy / d2 * 14 end
                end
            end
        end
        local fx, fy = 0, 0
        if n > 0 then
            fx = (cx / n - b.x) * 0.25 + (ax / n - b.vx) * 0.9
            fy = (cy / n - b.y) * 0.25 + (ay / n - b.vy) * 0.9
        end
        fx = fx + sx * 40 + (goal.x - b.x) * 0.15
        fy = fy + sy * 40 + (goal.y - b.y) * 0.15
        if b.y > HY - 20 then fy = fy - 80 end
        if b.y < 8 then fy = fy + 80 end
        if b.x < 15 then fx = fx + 80 end
        if b.x > W - 15 then fx = fx - 80 end
        b.vx = b.vx + fx * dt
        b.vy = b.vy + fy * dt
        local sp = sqrt(b.vx * b.vx + b.vy * b.vy)
        local lim = clamp(sp, 25, 55)
        if sp > 0 then b.vx, b.vy = b.vx / sp * lim, b.vy / sp * lim end
    end
    for _, b in ipairs(birds) do
        b.x = b.x + b.vx * dt
        b.y = b.y + b.vy * dt
        b.ph = b.ph + dt * 9
    end
end

function lilka.draw()
    for i = 0, 11 do
        local y0, y1 = floor(i * HY / 12), floor((i + 1) * HY / 12)
        display.fill_rect(0, y0, W, y1 - y0, sky[i])
    end
    local sx, sy = floor(W * 0.72), HY - 6
    display.fill_circle(sx, sy, 26, rgb(255, 170, 90))
    display.fill_circle(sx, sy, 20, rgb(255, 205, 120))
    display.fill_circle(sx, sy, 15, rgb(255, 235, 170))

    display.fill_rect(0, HY, W, H - HY, rgb(60, 70, 25))
    for r = 1, #rows do
        local row = rows[r]
        local k = row.k
        local ground = rgb(lerp(90, 40, k), lerp(95, 70, k), lerp(40, 20, k))
        local ny = rows[r + 1] and rows[r + 1].y or H
        display.fill_rect(0, floor(row.y), W, floor(ny - row.y) + 1, ground)
    end
    for r = 1, #rows do
        local row = rows[r]
        local s = row.size
        local stem = rgb(50, 110, 30)
        local petal = rgb(255, lerp(170, 205, row.k), 30)
        local core = rgb(90, 50, 20)
        for _, it in ipairs(row.items) do
            local sway = sin(t * 1.3 + it.ph + it.x * 0.02) * s * 0.25
            local fx, fy = it.x + sway, row.y - it.h
            if s < 2.5 then
                display.fill_rect(floor(fx), floor(fy), 2, 2, petal)
            else
                display.draw_line(floor(it.x), floor(row.y), floor(fx), floor(fy), stem)
                if s > 5 then
                    display.fill_ellipse(floor(lerp(it.x, fx, 0.5) + s * 0.5), floor(lerp(row.y, fy, 0.5)), floor(s * 0.45), floor(s * 0.2), stem)
                end
                display.fill_circle(floor(fx), floor(fy), floor(s * 0.75), petal)
                display.fill_circle(floor(fx), floor(fy), max(1, floor(s * 0.35)), core)
            end
        end
    end

    local bc = rgb(30, 20, 40)
    for _, b in ipairs(birds) do
        local f = sin(b.ph) * 2
        local x, y = floor(b.x), floor(b.y)
        display.draw_line(x - 4, floor(y - 1 - f), x, y, bc)
        display.draw_line(x, y, x + 4, floor(y - 1 - f), bc)
    end
end
