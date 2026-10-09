lilka.fullscreen = true
lilka.show_fps = false

local sin, cos, abs, floor = math.sin, math.cos, math.abs, math.floor
local rnd = math.random

-- У Лілки свій math: min/max приймають таблицю, а random(a, b) не включає b,
-- тому — власні версії
local function min(a, b) if a < b then return a end return b end
local function max(a, b) if a > b then return a end return b end
local function irnd(a, b) return a + floor(rnd() * (b - a + 1)) end
local C = display.color565

local W, H, VY, FLOOR, FTOP
local t = 0
local FOG = { 14, 58, 105 }
local WHITE, BLACK = { 250, 250, 250 }, { 15, 15, 20 }
local SAND, PEBBLE, CAUSTIC = { 220, 190, 130 }, { 150, 125, 90 }, { 250, 235, 185 }

local function lerp(a, b, k) return a + (b - a) * k end

local function shade(c, k)
    return C(floor(lerp(c[1], FOG[1], k)), floor(lerp(c[2], FOG[2], k)), floor(lerp(c[3], FOG[3], k)))
end

local function project(x, y, z)
    local s = 1 - 0.55 * z
    return W / 2 + x * s, VY + (y - VY) * s, s
end

-- На залізі координати мають бути цілими
local function r(v) return floor(v + 0.5) end
local function fe(x, y, rx, ry, c) display.fill_ellipse(r(x), r(y), max(1, r(rx)), max(1, r(ry)), c) end
local function fc(x, y, rad, c) display.fill_circle(r(x), r(y), max(1, r(rad)), c) end
local function ft(x1, y1, x2, y2, x3, y3, c) display.fill_triangle(r(x1), r(y1), r(x2), r(y2), r(x3), r(y3), c) end
local function dl(x1, y1, x2, y2, c) display.draw_line(r(x1), r(y1), r(x2), r(y2), c) end

local SPECIES = {
    clown = {
        len = 26, hr = 0.55, speed = 16, fin_h = 0.75, anal = 0.6,
        body = { 255, 115, 20 }, fin = { 255, 140, 40 }, tail = { 255, 125, 30 }, edge = { 25, 20, 20 },
        stripes = { { 0.25, 0.07, 0.80, WHITE }, { -0.02, 0.08, 0.95, WHITE }, { -0.30, 0.06, 0.75, WHITE } },
    },
    tang = {
        len = 36, hr = 0.6, speed = 26, fin_h = 0.7, anal = 0.65,
        body = { 25, 75, 225 }, fin = { 20, 40, 130 }, tail = { 255, 215, 0 }, mark = { 15, 15, 45 },
    },
    yellow = {
        len = 30, hr = 0.8, speed = 22, fin_h = 0.85, anal = 0.8, snout = true,
        body = { 255, 225, 10 }, fin = { 250, 205, 0 }, tail = { 255, 235, 60 },
    },
    angel = {
        len = 30, hr = 1.0, speed = 14, fin_h = 1.3, anal = 1.25,
        body = { 235, 235, 215 }, fin = { 245, 205, 70 }, tail = { 225, 225, 205 },
        stripes = { { 0.18, 0.06, 0.88, BLACK }, { -0.08, 0.07, 0.95, BLACK }, { -0.32, 0.05, 0.70, BLACK } },
    },
    tetra = {
        len = 13, hr = 0.36, speed = 30, fin_h = 0.5, anal = 0.5,
        body = { 60, 210, 255 }, fin = { 150, 200, 220 }, tail = { 150, 200, 220 }, belly = { 235, 30, 45 },
    },
}

local fish, schools, bubbles, statics, pebbles, caustics, rays = {}, {}, {}, {}, {}, {}, {}
local BX, BZ

local function new_fish(kind, o)
    local sp = SPECIES[kind]
    local d = rnd() < 0.5 and -1 or 1
    o = o or {}
    o.kind, o.sp, o.dir, o.f = "fish", sp, d, d
    o.xl, o.xr = o.xl or -220, o.xr or 220
    o.ylo, o.yhi = o.ylo or 30, o.yhi or 195
    o.zlo, o.zhi = o.zlo or 0.05, o.zhi or 1
    o.x = o.x or lerp(o.xl, o.xr, rnd())
    o.y = o.y or lerp(o.ylo, o.yhi, rnd())
    o.z = o.z or lerp(o.zlo, o.zhi, rnd())
    o.ty, o.tz = o.y, o.z
    o.base = sp.speed * (0.8 + rnd() * 0.4)
    o.speed = o.base
    o.size = o.size or (0.85 + rnd() * 0.3)
    o.ph, o.timer = rnd() * 6, rnd() * 4
    return o
end

local function fish_colors(o)
    local q = floor(o.z * 20)
    if o.q ~= q then
        o.q = q
        local k, sp = o.z * 0.75, o.sp
        local p = o.pal or { st = {} }
        p.body, p.fin, p.tail = shade(sp.body, k), shade(sp.fin, k), shade(sp.tail, k)
        p.eye, p.pupil = shade(WHITE, k), shade(BLACK, k)
        if sp.mark then p.mark = shade(sp.mark, k) end
        if sp.belly then p.belly = shade(sp.belly, k) end
        if sp.edge then p.edge = shade(sp.edge, k) end
        if sp.stripes then
            for i, s in ipairs(sp.stripes) do p.st[i] = shade(s[4], k) end
        end
        o.pal = p
    end
    return o.pal
end

local function update_fish(o, dt)
    o.ph = o.ph + dt * (5 + o.speed * 0.12)
    o.timer = o.timer - dt
    if o.timer <= 0 then
        o.timer = 3 + rnd() * 6
        o.ty = lerp(o.ylo, o.yhi, rnd())
        o.tz = lerp(o.zlo, o.zhi, rnd())
        if rnd() < 0.3 then o.dir = -o.dir end
        o.speed = o.base * (0.6 + rnd() * 0.8)
    end
    if o.x > o.xr then o.dir = -1 elseif o.x < o.xl then o.dir = 1 end
    o.f = o.f + (o.dir - o.f) * min(1, dt * 2.2)
    o.x = o.x + o.f * o.speed * dt
    o.y = o.y + (o.ty - o.y) * min(1, dt * 0.6) + sin(o.ph * 0.25) * dt * 3
    o.z = o.z + (o.tz - o.z) * min(1, dt * 0.25)
end

local function draw_fish(o)
    local sp, p = o.sp, fish_colors(o)
    local sx, sy, s = project(o.x, o.y, o.z)
    local f = o.f
    local fa = abs(f)
    local d = f >= 0 and 1 or -1
    local L = sp.len * s * o.size
    local h = L * sp.hr
    local half = max(L * 0.5 * fa, h * 0.28)
    local wag = sin(o.ph) * h * 0.18

    local tx = sx - f * L * 0.42
    local tl = L * 0.32 * fa + 1
    ft(tx, sy, tx - d * tl, sy - h * 0.45 + wag, tx - d * tl, sy + h * 0.45 + wag, p.tail)

    ft(sx - f * L * 0.28, sy - h * 0.3, sx + f * L * 0.12, sy - h * 0.3,
        sx - f * L * 0.32, sy - h * sp.fin_h, p.fin)
    ft(sx - f * L * 0.22, sy + h * 0.3, sx + f * L * 0.02, sy + h * 0.3,
        sx - f * L * 0.3, sy + h * sp.anal, p.fin)

    fe(sx, sy, half, h * 0.5, p.body)

    if sp.mark then
        fe(sx - f * L * 0.05, sy - h * 0.1, half * 0.6, h * 0.16, p.mark)
    end
    if sp.belly then
        fe(sx - f * L * 0.14, sy + h * 0.16, half * 0.55, h * 0.17, p.belly)
    end
    if sp.snout and fa > 0.2 then
        local hx = sx + f * L * 0.46
        ft(hx, sy - h * 0.08, hx, sy + h * 0.12, hx + d * L * 0.13 * fa, sy + h * 0.06, p.body)
    end
    if sp.stripes then
        for i, st in ipairs(sp.stripes) do
            local px = sx + f * L * st[1]
            local w = L * st[2] * fa
            if p.edge then fe(px, sy, w + 1, h * 0.5 * st[3] + 0.5, p.edge) end
            fe(px, sy, w, h * 0.5 * st[3], p.st[i])
        end
    end

    if fa > 0.25 then
        local ex, ey = sx + f * L * 0.32, sy - h * 0.06
        local er = h * 0.1
        if er >= 1 then
            fc(ex, ey, er, p.pupil)
            display.draw_pixel(r(ex + d * er * 0.4), r(ey - er * 0.4), p.eye)
        else
            display.draw_pixel(r(ex), r(ey), p.pupil)
        end
    end
end

local function draw_weed(o)
    local px, py, s = project(o.x, FLOOR, o.z)
    local pw = o.w * s
    for k = 1, o.segs do
        local wx = o.x + sin(t * 1.1 + o.ph + k * 0.5) * k * 1.4
        local cx, cy = project(wx, FLOOR - k * o.seg, o.z)
        local cw = o.w * s * (1 - k / (o.segs + 1) * 0.75)
        local c = (k % 2 == 0) and o.c1 or o.c2
        ft(px - pw, py, px + pw, py, cx + cw, cy, c)
        ft(px - pw, py, cx + cw, cy, cx - cw, cy, c)
        px, py, pw = cx, cy, cw
    end
end

local function draw_rock(o)
    local sx, sy, s = project(o.x, FLOOR + 2, o.z)
    fe(sx, sy - o.ry * s * 0.55, o.rx * s, o.ry * s, o.c1)
    fe(sx - o.rx * s * 0.25, sy - o.ry * s * 0.85, o.rx * s * 0.5, o.ry * s * 0.4, o.c2)
end

local function draw_coral(o)
    local sx, sy, s = project(o.x, FLOOR, o.z)
    for _, b in ipairs(o.blobs) do
        local bx, by = sx + b[1] * s, sy - b[2] * s
        fc(bx, by, b[3] * s, o.c1)
        fc(bx - b[3] * s * 0.3, by - b[3] * s * 0.3, b[3] * s * 0.45, o.c2)
    end
end

local function draw_fan(o)
    local sx, sy, s = project(o.x, FLOOR, o.z)
    for i = 1, o.n do
        local a = (i / (o.n + 1) - 0.5) * 2 + sin(t * 0.8 + o.ph) * 0.05
        local mx, my = sx + sin(a) * 12 * s, sy - cos(a) * 12 * s
        local a2 = a * 1.4
        local tx, ty = mx + sin(a2) * 12 * s, my - cos(a2) * 12 * s
        dl(sx, sy, mx, my, o.c1); dl(sx + 1, sy, mx + 1, my, o.c1)
        dl(mx, my, tx, ty, o.c1); dl(mx + 1, my, tx + 1, ty, o.c1)
        fc(tx, ty, 2 * s, o.c2)
    end
end

local function draw_anem(o)
    local sx, sy, s = project(o.x, FLOOR, o.z)
    fe(sx, sy - 4 * s, 14 * s, 6 * s, o.cb)
    for i = 1, o.n do
        local a = (i / (o.n + 1) - 0.5) * 2.4
        local px, py = sx + sin(a) * 10 * s, sy - 6 * s
        for k = 1, 3 do
            local ang = a * (1 + k * 0.15) + sin(t * 1.6 + i * 0.7 + k * 0.6) * 0.25
            local nx, ny = px + sin(ang) * 7 * s, py - cos(ang) * 7 * s
            dl(px, py, nx, ny, o.ct); dl(px + 1, py, nx + 1, ny, o.ct)
            px, py = nx, ny
        end
        fc(px, py, 2 * s, o.tip)
    end
end

local function new_bubble(temp, x, z)
    local b = {
        kind = "bubble", temp = temp,
        x0 = x or BX + (rnd() - 0.5) * 6, z = z or BZ + (rnd() - 0.5) * 0.04,
        y = FLOOR - 14, r = 1 + rnd() * 2.5, ph = rnd() * 6,
    }
    b.x = b.x0
    b.vy = 25 + b.r * 10 + rnd() * 10
    b.c = shade({ 200, 240, 255 }, b.z * 0.7)
    b.hl = shade(WHITE, b.z * 0.7)
    return b
end

local function draw_bubble(b)
    local sx, sy, s = project(b.x, b.y, b.z)
    display.draw_circle(r(sx), r(sy), max(1, r(b.r * s)), b.c)
    display.draw_pixel(r(sx - b.r * s * 0.4), r(sy - b.r * s * 0.4), b.hl)
end

local DRAW = {
    fish = draw_fish, weed = draw_weed, rock = draw_rock, coral = draw_coral,
    fan = draw_fan, anem = draw_anem, bubble = draw_bubble,
}

local water_bands, sand_bands = {}, {}

local function build_bands()
    local nb = 16
    local bh = FTOP / nb
    for i = 0, nb - 1 do
        local k = i / (nb - 1)
        local c = { lerp(60, 14, k), lerp(170, 58, k), lerp(220, 105, k) }
        local lift = 20 * (1 - k) + 5
        water_bands[#water_bands + 1] = {
            y0 = floor(i * bh), y1 = floor((i + 1) * bh), k = k,
            c = C(floor(c[1]), floor(c[2]), floor(c[3])),
            rc = C(min(255, floor(c[1] + lift)), min(255, floor(c[2] + lift)), min(255, floor(c[3] + lift))),
        }
    end
    local ns = 14
    local sh = (H - FTOP) / ns
    for i = 0, ns - 1 do
        local y0 = FTOP + floor(i * sh)
        local y1 = FTOP + floor((i + 1) * sh)
        local s = ((y0 + y1) / 2 - VY) / (FLOOR - VY)
        local z = max(0, min(1, (1 - s) / 0.55))
        sand_bands[#sand_bands + 1] = { y0 = y0, y1 = y1, c = shade(SAND, z * 0.75) }
    end
end

local function draw_bg()
    for _, b in ipairs(water_bands) do
        display.fill_rect(0, b.y0, W, b.y1 - b.y0, b.c)
        for _, ray in ipairs(rays) do
            local cx = ray.x + sin(t * 0.3 + ray.ph) * 12 + b.y0 * ray.slant
            local w = ray.w * (0.5 + b.k * 1.3)
            display.fill_rect(r(cx - w / 2), b.y0, max(1, r(w)), b.y1 - b.y0, b.rc)
        end
    end
    for x = 0, W, 12 do
        local y = 3 + sin(t * 2 + x * 0.13) * 1.5
        dl(x, y, x + 6, y, water_bands[1].rc)
    end
    for _, b in ipairs(sand_bands) do
        display.fill_rect(0, b.y0, W, b.y1 - b.y0 + 1, b.c)
    end
    for _, p in ipairs(pebbles) do
        local sx, sy, s = project(p.x, FLOOR - p.dy, p.z)
        fe(sx, sy, p.rx * s, p.rx * s * 0.5, p.c)
    end
    for _, c in ipairs(caustics) do
        local z = c.z + sin(t * 0.5 + c.ph) * 0.05
        local sx, sy, s = project(c.x + sin(t * 0.7 + c.ph) * 15, FLOOR - 3, z)
        fe(sx, sy, (9 + sin(t * 1.3 + c.ph) * 3) * s, 2.5 * s, c.c)
    end
end

local function add_static(o) statics[#statics + 1] = o end

local function build_scene()
    for _, rk in ipairs({ { -150, 0.7, 30, 16 }, { -40, 0.95, 40, 22 }, { 90, 0.5, 26, 14 },
        { 170, 0.85, 34, 20 }, { 20, 0.15, 18, 9 } }) do
        local k = rk[2] * 0.75
        add_static({ kind = "rock", x = rk[1], z = rk[2], rx = rk[3], ry = rk[4],
            c1 = shade({ 95, 90, 100 }, k), c2 = shade({ 150, 145, 150 }, k) })
    end
    BX, BZ = 98, 0.48

    local greens = { { 30, 150, 60 }, { 60, 170, 50 }, { 20, 120, 80 }, { 110, 160, 40 } }
    for i = 1, 11 do
        local z = rnd()
        local g = greens[irnd(1, #greens)]
        local k = z * 0.75
        add_static({ kind = "weed", x = lerp(-230, 230, rnd()), z = z,
            segs = irnd(7, 11), seg = 10 + rnd() * 5, w = 3 + rnd() * 2.5, ph = rnd() * 6,
            c1 = shade(g, k), c2 = shade({ g[1] * 0.7, g[2] * 0.75, g[3] * 0.7 }, k) })
    end

    local corals = { { { 255, 110, 140 }, { 255, 170, 190 } }, { { 180, 90, 220 }, { 220, 150, 250 } },
        { { 255, 150, 60 }, { 255, 200, 120 } } }
    for i = 1, 4 do
        local z = rnd() * 0.9
        local cc = corals[irnd(1, #corals)]
        local blobs = {}
        for j = 1, irnd(4, 7) do
            blobs[j] = { (rnd() - 0.5) * 30, 4 + rnd() * 16, 5 + rnd() * 5 }
        end
        add_static({ kind = "coral", x = lerp(-200, 200, rnd()), z = z, blobs = blobs,
            c1 = shade(cc[1], z * 0.75), c2 = shade(cc[2], z * 0.75) })
    end
    for i = 1, 3 do
        local z = rnd()
        add_static({ kind = "fan", x = lerp(-200, 200, rnd()), z = z, n = irnd(6, 9), ph = rnd() * 6,
            c1 = shade({ 230, 60, 70 }, z * 0.75), c2 = shade({ 255, 180, 120 }, z * 0.75) })
    end

    local anems = { { -70, 0.3 }, { 140, 0.6 } }
    for _, a in ipairs(anems) do
        local k = a[2] * 0.75
        add_static({ kind = "anem", x = a[1], z = a[2], n = 11,
            cb = shade({ 140, 50, 120 }, k), ct = shade({ 200, 110, 200 }, k), tip = shade({ 255, 190, 240 }, k) })
    end

    for i = 1, 2 do
        local a = anems[i]
        fish[#fish + 1] = new_fish("clown", {
            xl = a[1] - 45, xr = a[1] + 45, ylo = 175, yhi = 215,
            zlo = max(0, a[2] - 0.12), zhi = a[2] + 0.12,
        })
    end
    fish[#fish + 1] = new_fish("clown", { xl = anems[1][1] - 45, xr = anems[1][1] + 45, ylo = 175, yhi = 215,
        zlo = 0.2, zhi = 0.4, size = 0.75 })
    for i = 1, 2 do fish[#fish + 1] = new_fish("tang") end
    for i = 1, 2 do fish[#fish + 1] = new_fish("yellow") end
    for i = 1, 2 do fish[#fish + 1] = new_fish("angel", { ylo = 40, yhi = 160 }) end

    local leader = new_fish("tetra", { ylo = 50, yhi = 170, zlo = 0.2, zhi = 0.9 })
    local school = { leader = leader, members = {} }
    for i = 1, 9 do
        local m = new_fish("tetra", { size = 0.8 + rnd() * 0.3 })
        m.ox, m.oy, m.oz = (rnd() - 0.5) * 40, (rnd() - 0.5) * 22, (rnd() - 0.5) * 0.15
        m.x, m.y, m.z = leader.x + m.ox, leader.y + m.oy, leader.z + m.oz
        m.lag, m.ph0 = rnd() * 2, rnd() * 6
        school.members[i] = m
    end
    schools[1] = school

    for i = 1, 14 do
        local b = new_bubble(false)
        b.y = lerp(10, FLOOR - 14, rnd())
        bubbles[i] = b
    end

    for i = 1, 4 do
        rays[i] = { x = lerp(0, W, (i - 0.5) / 4) + (rnd() - 0.5) * 30, w = 14 + rnd() * 14,
            ph = rnd() * 6, slant = 0.25 + rnd() * 0.15 }
    end
    for i = 1, 30 do
        local z = rnd()
        pebbles[i] = { x = lerp(-260, 260, rnd()), z = z, dy = rnd() * 2, rx = 2 + rnd() * 3,
            c = shade(rnd() < 0.5 and PEBBLE or { 235, 220, 200 }, z * 0.75) }
    end
    for i = 1, 9 do
        local z = rnd() * 0.9
        caustics[i] = { x = lerp(-200, 200, rnd()), z = z, ph = rnd() * 6, c = shade(CAUSTIC, z * 0.75) }
    end
end

function lilka.init()
    W, H = display.width, display.height
    VY = H * 0.45
    FLOOR = H - 6
    FTOP = floor(VY + (FLOOR - VY) * 0.45)
    build_bands()
    build_scene()
end

function lilka.update(delta)
    local dt = min(delta, 0.1)
    t = t + dt

    -- Як шпалери (/sd/wallpaper.lua) кнопки належать лаунчеру: controller і util немає
    if controller then
        local st = controller.get_state()
        if st.a.just_pressed then
            for i = 1, 12 do
                local b = new_bubble(true, lerp(-150, 150, rnd()), rnd() * 0.8)
                b.y = FLOOR - rnd() * 30
                bubbles[#bubbles + 1] = b
            end
        end
        if st.b.just_pressed then lilka.show_fps = not lilka.show_fps end
        if st.start.just_pressed then util.exit() end
    end

    for _, o in ipairs(fish) do update_fish(o, dt) end

    for _, sc in ipairs(schools) do
        local L = sc.leader
        update_fish(L, dt)
        for _, m in ipairs(sc.members) do
            m.ph = m.ph + dt * 9
            m.f = m.f + (L.f - m.f) * min(1, dt * (1.5 + m.lag))
            m.x = m.x + (L.x + m.ox - m.x) * min(1, dt * 1.3)
            m.y = m.y + (L.y + m.oy + sin(t * 1.3 + m.ph0) * 3 - m.y) * min(1, dt * 1.3)
            m.z = m.z + (L.z + m.oz - m.z) * min(1, dt)
        end
    end

    for i = #bubbles, 1, -1 do
        local b = bubbles[i]
        b.y = b.y - b.vy * dt
        b.ph = b.ph + dt * 3
        b.x = b.x0 + sin(b.ph) * 2.5
        if b.y < 8 then
            if b.temp then
                table.remove(bubbles, i)
            else
                bubbles[i] = new_bubble(false)
            end
        end
    end
end

local list = {}
local function by_depth(a, b) return a.z > b.z end

function lilka.draw()
    draw_bg()

    local n = 0
    for _, o in ipairs(statics) do n = n + 1; list[n] = o end
    for _, o in ipairs(fish) do n = n + 1; list[n] = o end
    for _, sc in ipairs(schools) do
        for _, m in ipairs(sc.members) do n = n + 1; list[n] = m end
    end
    for _, o in ipairs(bubbles) do n = n + 1; list[n] = o end
    for i = n + 1, #list do list[i] = nil end

    table.sort(list, by_depth)
    for i = 1, n do
        local o = list[i]
        DRAW[o.kind](o)
    end
end
