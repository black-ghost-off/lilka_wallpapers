-- Гравітація: задача N тіл зі слідами. Сцени змінюють одна одну: «вісімка» трьох тіл,
-- подвійна зоря з планетами й кометою та випадкове скупчення, де тіла злипаються при зіткненні.
-- Застосунок: ← → — сцена, A — пауза, START — вихід.

lilka.fullscreen = false

local DURATION = 40
local TRAIL = 70
local SOFT = 0.02 -- згладжування, щоб близькі прольоти не вибухали

local floor, rnd, sin, cos, sqrt = math.floor, math.random, math.sin, math.cos, math.sqrt
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

local W, H, CX, CY
local bodies = {}
local scale, speed = 70, 1
local t, sample, paused = 0, 0, false
local scene = 0
local stars = {}
local C = {}

local function body(m, x, y, vx, vy, col)
    local b = { m = m, x = x, y = y, vx = vx, vy = vy, trail = {}, head = 0 }
    b.col = rgb(col[1], col[2], col[3])
    b.shades = {}
    for s = 1, 5 do b.shades[s] = rgb(col[1] * s / 7, col[2] * s / 7, col[3] * s / 7) end
    bodies[#bodies + 1] = b
    return b
end

-- Прибираємо рух центру мас, щоб система не відпливала з екрана
local function center()
    local M, px, py, mx, my = 0, 0, 0, 0, 0
    for _, b in ipairs(bodies) do
        M = M + b.m
        px, py = px + b.m * b.vx, py + b.m * b.vy
        mx, my = mx + b.m * b.x, my + b.m * b.y
    end
    for _, b in ipairs(bodies) do
        b.vx, b.vy = b.vx - px / M, b.vy - py / M
        b.x, b.y = b.x - mx / M, b.y - my / M
    end
end

local SCENES = {
    { "Figure eight", function()
        scale, speed = 62, 1.2
        local x, y, vx, vy = 0.97000436, -0.24308753, -0.93240737, -0.86473146
        body(1, x, y, -vx / 2, -vy / 2, { 255, 120, 90 })
        body(1, -x, -y, -vx / 2, -vy / 2, { 90, 200, 255 })
        body(1, 0, 0, vx, vy, { 255, 230, 120 })
    end },
    { "Binary star", function()
        scale, speed = 48, 0.9
        local v = sqrt(2 / 0.6) / 2 -- кругова орбіта двох зір масою 1 на відстані 0.6
        body(1, -0.3, 0, 0, -v, { 255, 220, 140 })
        body(1, 0.3, 0, 0, v, { 255, 150, 90 })
        local cols = { { 120, 200, 255 }, { 140, 255, 160 }, { 255, 120, 200 } }
        for k, r in ipairs({ 1.15, 1.55, 1.95 }) do
            local a = rnd() * 6.283
            local vv = sqrt(2 / r)
            body(0.002, r * cos(a), r * sin(a), -vv * sin(a), vv * cos(a), cols[k])
        end
        body(0.0005, 2.1, 0.4, -0.15, 0.55, { 230, 230, 255 }) -- комета
    end },
    { "Cluster", function()
        scale, speed = 50, 0.6
        for _ = 1, 9 do
            local a, r = rnd() * 6.283, 0.4 + rnd() * 1.5
            local m = 0.1 + rnd() * 0.35
            local v = 0.7 / sqrt(r)
            body(m, r * cos(a), r * sin(a) * 0.8, -v * sin(a), v * cos(a),
                { 120 + rnd() * 135, 120 + rnd() * 135, 120 + rnd() * 135 })
        end
    end },
}

local function pick(k)
    scene = (k - 1) % #SCENES + 1
    bodies = {}
    SCENES[scene][2]()
    center()
    t, sample = 0, 0
end

local function radius(b) return max(1, floor(2 + 4 * b.m ^ (1 / 3))) end

local function step(h)
    local n = #bodies
    for i = 1, n do
        local a = bodies[i]
        a.ax, a.ay = 0, 0
    end
    for i = 1, n - 1 do
        local a = bodies[i]
        for j = i + 1, n do
            local b = bodies[j]
            local dx, dy = b.x - a.x, b.y - a.y
            local r2 = dx * dx + dy * dy + SOFT * SOFT
            local inv = 1 / (r2 * sqrt(r2))
            a.ax, a.ay = a.ax + dx * b.m * inv, a.ay + dy * b.m * inv
            b.ax, b.ay = b.ax - dx * a.m * inv, b.ay - dy * a.m * inv
        end
    end
    for i = 1, n do -- напівнеявний Ейлер: стабільний для орбіт
        local a = bodies[i]
        a.vx, a.vy = a.vx + a.ax * h, a.vy + a.ay * h
        a.x, a.y = a.x + a.vx * h, a.y + a.vy * h
    end
end

-- У скупченні тіла, що торкнулися, злипаються (імпульс зберігається)
local function merge()
    local i = 1
    while i <= #bodies do
        local a = bodies[i]
        local j = i + 1
        while j <= #bodies do
            local b = bodies[j]
            local dx, dy = (b.x - a.x) * scale, (b.y - a.y) * scale
            local rr = radius(a) + radius(b) - 2
            if dx * dx + dy * dy < rr * rr then
                local m = a.m + b.m
                a.x, a.y = (a.x * a.m + b.x * b.m) / m, (a.y * a.m + b.y * b.m) / m
                a.vx, a.vy = (a.vx * a.m + b.vx * b.m) / m, (a.vy * a.m + b.vy * b.m) / m
                if b.m > a.m then a.col, a.shades = b.col, b.shades end
                a.m = m
                table.remove(bodies, j)
            else
                j = j + 1
            end
        end
        i = i + 1
    end
end

function lilka.init()
    W, H = display.width, display.height
    -- Застосунок стартує на весь екран, тож display.height = 240 навіть з fullscreen = false
    if not lilka.fullscreen and H > 216 then H = H - 24 end
    CX, CY = W // 2, H // 2 + 4
    C.gray = rgb(120, 125, 150)
    for k = 1, 60 do
        local v = 40 + floor(rnd() * 80)
        stars[k] = { floor(rnd() * W), floor(rnd() * H), rgb(v, v, v + 20) }
    end
    pick(1 + floor(rnd() * #SCENES))
end

function lilka.update(delta)
    if controller then
        local s = controller.get_state()
        if s.start.just_pressed then util.exit() end
        if s.a.just_pressed then paused = not paused end
        if s.right.just_pressed then pick(scene + 1) end
        if s.left.just_pressed then pick(scene - 1) end
    end
    if paused then return end
    delta = min(delta, 0.05)
    t = t + delta
    local sub = 12
    local h = delta * speed / sub
    for _ = 1, sub do step(h) end
    if scene == 3 then merge() end
    sample = sample + delta
    if sample >= 1 / 25 then
        sample = 0
        for _, b in ipairs(bodies) do
            b.head = b.head % TRAIL + 1
            b.trail[b.head] = { CX + b.x * scale, CY + b.y * scale }
        end
    end
    -- Нова сцена: за часом або коли все розлетілося чи злиплося
    local away = 0
    for _, b in ipairs(bodies) do
        if b.x * b.x + b.y * b.y > 25 then away = away + 1 end
    end
    if t > DURATION or (scene == 3 and #bodies - away < 2 and t > 8) then pick(scene + 1) end
end

function lilka.draw()
    display.fill_screen(0)
    for _, s in ipairs(stars) do display.fill_rect(s[1], s[2], 1, 1, s[3]) end
    for _, b in ipairs(bodies) do
        local tr, n = b.trail, #b.trail
        local prev
        for k = n - 1, 0, -1 do
            local q = tr[(b.head - k - 1) % TRAIL + 1]
            if q and prev then
                display.draw_line(floor(prev[1]), floor(prev[2]), floor(q[1]), floor(q[2]), b.shades[1 + floor((n - k) / n * 4.99)])
            end
            prev = q
        end
    end
    for _, b in ipairs(bodies) do
        local x, y = floor(CX + b.x * scale), floor(CY + b.y * scale)
        local r = radius(b)
        if b.m > 0.5 then display.fill_circle(x, y, r + 2, b.shades[2]) end -- сяйво зорі
        display.fill_circle(x, y, r, b.col)
    end
    text(SCENES[scene][1], 4, 12, 0xFFFF, "6x13")
    local info = paused and "paused" or (#bodies .. " bodies")
    text(info, W - 4 - #info * 5, 11, C.gray, "5x7")
end
