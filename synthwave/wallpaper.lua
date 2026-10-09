-- Synthwave: неонова сітка мчить до смугастого сонця за горами.
-- Застосунок: START — вихід.

lilka.fullscreen = false

local sin, floor = math.sin, math.floor
local function min(a, b) if a < b then return a end return b end
local function max(a, b) if a > b then return a end return b end
local function clamp(x, a, b) return min(b, max(a, x)) end
local function lerp(a, b, k) return a + (b - a) * k end
local function rgb(r, g, b) return display.color565(floor(clamp(r, 0, 255)), floor(clamp(g, 0, 255)), floor(clamp(b, 0, 255))) end

local seed = 7
local function prand()
    seed = (seed * 1103515245 + 12345) % 2147483648
    return seed / 2147483648
end

local W, H, HY
local t = 0
local stars, far, near, sky = {}, {}, {}, {}
local SUN_R = 46

local function ridge(n, base, amp)
    local pts = {}
    for i = 0, n do
        local edge = math.abs(i / n - 0.5) * 2
        pts[i] = base - amp * (0.35 + 0.65 * prand()) * (0.15 + 0.85 * edge)
    end
    return pts
end

function lilka.init()
    W, H = display.width, display.height
    -- Застосунок стартує на весь екран, тож display.height = 240 навіть з fullscreen = false
    if not lilka.fullscreen and H > 216 then H = H - 24 end
    HY = floor(H * 0.58)
    for i = 1, 50 do stars[i] = { x = prand() * W, y = prand() * HY * 0.7, ph = prand() * 6 } end
    far = ridge(14, HY, 34)
    near = ridge(10, HY, 22)
    for i = 0, 13 do
        local k = i / 13
        sky[i] = rgb(lerp(12, 120, k ^ 1.4), lerp(4, 20, k), lerp(36, 110, k))
    end
end

function lilka.update(delta)
    t = t + delta
    if controller and controller.get_state().start.just_pressed then util.exit() end
end

local function draw_ridge(pts, n, fill, edge)
    local step = W / n
    for i = 0, n - 1 do
        local x0, x1 = floor(i * step), floor((i + 1) * step)
        local y0, y1 = floor(pts[i]), floor(pts[i + 1])
        display.fill_triangle(x0, y0, x1, y1, x0, HY, fill)
        display.fill_triangle(x1, y1, x1, HY, x0, HY, fill)
        display.draw_line(x0, y0, x1, y1, edge)
    end
end

function lilka.draw()
    for i = 0, 13 do
        local y0, y1 = floor(i * HY / 14), floor((i + 1) * HY / 14)
        display.fill_rect(0, y0, W, y1 - y0, sky[i])
    end
    for _, s in ipairs(stars) do
        local b = 150 + 100 * sin(t * 2 + s.ph)
        display.draw_pixel(floor(s.x), floor(s.y), rgb(b, b * 0.8, b))
    end

    -- Сонце зі смугами, що повзуть донизу
    local cx, cy = W // 2, HY - 12
    local shift = (t * 6) % 8
    for dy = -SUN_R, 12 do
        local y = cy + dy
        local k = (dy + SUN_R) / (SUN_R + 12)
        local gap = dy > -SUN_R * 0.35 and ((dy + shift) % 8) < 1 + k * 4
        if not gap and y < HY then
            local w = floor((SUN_R * SUN_R - dy * dy) ^ 0.5)
            display.draw_line(cx - w, y, cx + w, y, rgb(255, lerp(230, 50, k), lerp(90, 150, k)))
        end
    end

    draw_ridge(far, 14, rgb(52, 14, 74), rgb(140, 50, 170))
    draw_ridge(near, 10, rgb(24, 6, 40), rgb(230, 60, 200))

    -- Підлога і сітка
    display.fill_rect(0, HY, W, H - HY, rgb(14, 2, 26))
    display.draw_line(0, HY, W, HY, rgb(255, 120, 230))
    local glow, line = rgb(90, 20, 110), rgb(255, 60, 220)
    local vx = W / 2
    for i = -14, 14 do
        local xb = vx + i * 34
        local xt = vx + i * 3
        display.draw_line(floor(xt), HY, floor(xb), H, line)
    end
    local phase = (t * 1.6) % 1
    for n = 0, 9 do
        local z = 1 + n - phase
        local y = HY + (H - HY) * 1.2 / z
        if y < H and y > HY + 1 then
            local k = clamp(1.3 / z, 0, 1)
            display.draw_line(0, floor(y) + 1, W, floor(y) + 1, glow)
            display.draw_line(0, floor(y), W, floor(y), rgb(lerp(110, 255, k), lerp(20, 80, k), lerp(140, 230, k)))
        end
    end
end
