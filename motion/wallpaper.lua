-- Motion Demo: демосцена з десяти анімованих сцен, що змінюють одна одну з переходами.
-- Застосунок: ← → — попередня/наступна сцена, A — пауза автозміни, START — вихід.

lilka.fullscreen = false

local DUR, TR = 9, 0.45 -- тривалість сцени і переходу, с

local sin, cos, floor, sqrt, atan2 = math.sin, math.cos, math.floor, math.sqrt, math.atan2
local PI, TAU = math.pi, math.pi * 2
local rnd = math.random
local function min(a, b) if a < b then return a end return b end
local function max(a, b) if a > b then return a end return b end
local function clamp(x, a, b) return min(b, max(a, x)) end
local function lerp(a, b, k) return a + (b - a) * k end
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
    return rgb(r * 255, g * 255, b * 255)
end

local function text(s, x, y, c, font)
    display.set_font(font or "6x13")
    display.set_text_size(1)
    display.set_text_color(c)
    display.set_cursor(floor(x), floor(y))
    display.print(s)
end

-- Функції пом'якшення (easing)
local E = {}
E.linear = function(x) return x end
E.in_out_quad = function(x) if x < 0.5 then return 2 * x * x end return 1 - (2 - 2 * x) ^ 2 / 2 end
E.out_cubic = function(x) return 1 - (1 - x) ^ 3 end
E.in_out_cubic = function(x) if x < 0.5 then return 4 * x * x * x end return 1 - (2 - 2 * x) ^ 3 / 2 end
E.out_back = function(x) local c = 1.70158; return 1 + (c + 1) * (x - 1) ^ 3 + c * (x - 1) ^ 2 end
E.in_back = function(x) local c = 1.70158; return (c + 1) * x * x * x - c * x * x end
E.out_elastic = function(x)
    if x <= 0 then return 0 end
    if x >= 1 then return 1 end
    return 2 ^ (-10 * x) * sin((x * 10 - 0.75) * TAU / 3) + 1
end
E.out_bounce = function(x)
    local n, d = 7.5625, 2.75
    if x < 1 / d then return n * x * x
    elseif x < 2 / d then x = x - 1.5 / d; return n * x * x + 0.75
    elseif x < 2.5 / d then x = x - 2.25 / d; return n * x * x + 0.9375
    else x = x - 2.625 / d; return n * x * x + 0.984375 end
end

local W, H
local BLACK, WHITE
local RAINBOW = {} -- 64 відтінки, повна яскравість
local FADE = {}    -- FADE[hue 0..7][level 0..15]

-- Синусна таблиця: 256 кроків на період, значення 0..63
local SN = {}

---------------------------------------------------------------- Plasma
local plasma = { name = "Plasma" }
do
    local CS = 8
    local cols, rows, rad, pal = 0, 0, {}, {}
    local cx, ry = {}, {}
    function plasma.init()
        cols, rows = (W + CS - 1) // CS, (H + CS - 1) // CS
        for j = 0, rows - 1 do
            for i = 0, cols - 1 do
                local dx, dy = i - cols / 2, (j - rows / 2) * 1.2
                rad[j * cols + i] = floor(sqrt(dx * dx + dy * dy) * 14)
            end
        end
        for k = 0, 255 do
            local a = k / 256 * TAU
            pal[k] = rgb(128 + 127 * sin(a), 128 + 127 * sin(a * 2 + 2.1), 140 + 115 * sin(a * 3 + 4.2))
        end
    end
    function plasma.draw(t)
        local a1, a2, a3, a4 = floor(t * 47), floor(t * -31), floor(t * 23), floor(t * -61)
        local shift = floor(t * 40)
        local wob = sin(t * 0.6) * 4 + 9
        for i = 0, cols - 1 do cx[i] = SN[floor(i * wob + a1) % 256] end
        for j = 0, rows - 1 do ry[j] = SN[floor(j * 11 + a2 + SN[(j * 6 + a3) % 256]) % 256] end
        for j = 0, rows - 1 do
            local y, base, rj = j * CS, j * cols, ry[j]
            local run_x, run_c = 0, nil
            for i = 0, cols - 1 do
                local v = cx[i] + rj + SN[((i + j) * 7 + a3) % 256] + SN[(rad[base + i] + a4) % 256]
                local c = pal[(v + shift) % 256]
                if c ~= run_c then
                    if run_c then display.fill_rect(run_x, y, i * CS - run_x, CS, run_c) end
                    run_x, run_c = i * CS, c
                end
            end
            display.fill_rect(run_x, y, W - run_x, CS, run_c)
        end
    end
end

---------------------------------------------------------------- Tunnel
local tunnel = { name = "Tunnel" }
do
    local N, SPEED = 20, 3.2
    local ca, cb, dots = {}, {}, {}
    function tunnel.init()
        for l = 0, 31 do
            local k = (1 - l / 31) ^ 1.6
            ca[l] = rgb(30 + 220 * k, 20 + 60 * k, 90 + 160 * k)
            cb[l] = rgb(10 + 40 * k, 10 + 120 * k, 40 + 160 * k)
            dots[l] = rgb(80 + 175 * k, 80 + 175 * k, 60 + 120 * k)
        end
    end
    function tunnel.draw(t)
        local go = t * SPEED
        local frac, base = go % 1, floor(go)
        display.fill_screen((base % 2 == 0) and cb[0] or ca[0])
        local x0, y0 = W / 2, H / 2
        for k = 0, N - 1 do
            local z = 0.3 + (k + 1 - frac) * 0.42
            if z > 0.4 then
                local r = 75 / z
                local bend = 1 - 1 / (1 + z * 0.4)
                local cx = x0 + sin(t * 0.8 + z * 0.3) * 30 * bend
                local cy = y0 + cos(t * 0.6 + z * 0.25) * 18 * bend
                local l = floor(clamp(z / (N * 0.42), 0, 1) * 31)
                local c = ((k + base) % 2 == 0) and ca[l] or cb[l]
                display.fill_circle(floor(cx), floor(cy), floor(r), c)
                if r > 3 then
                    local tw = t * 1.4 + (k + base) * 0.35
                    local dr = max(1, floor(r * 0.07))
                    for m = 0, 5 do
                        local a = tw + m * PI / 3
                        display.fill_circle(floor(cx + cos(a) * r * 0.86), floor(cy + sin(a) * r * 0.86), dr, dots[l])
                    end
                end
            end
        end
    end
end

---------------------------------------------------------------- Morph
local morph = { name = "Morph" }
do
    local NP = 162
    local shapes, cur, pal = {}, {}, {}
    local function sphere()
        local s = {}
        for i = 0, NP - 1 do
            local y = 1 - (i + 0.5) / NP * 2
            local r = sqrt(1 - y * y)
            local a = i * 2.39996
            s[i] = { cos(a) * r, y, sin(a) * r }
        end
        return s
    end
    local function torus()
        local s = {}
        for i = 0, NP - 1 do
            local u, v = (i % 18) / 18 * TAU, (i // 18) / 9 * TAU
            local r = 0.75 + 0.32 * cos(u)
            s[i] = { cos(v) * r, 0.32 * sin(u), sin(v) * r }
        end
        return s
    end
    local function cube()
        local s, V = {}, {}
        for i = 0, 7 do V[i] = { (i & 1) * 2 - 1, ((i >> 1) & 1) * 2 - 1, ((i >> 2) & 1) * 2 - 1 } end
        local edges = {}
        for a = 0, 7 do for b = a + 1, 7 do
            local d = (a ~ b)
            if d == 1 or d == 2 or d == 4 then edges[#edges + 1] = { a, b } end
        end end
        for i = 0, NP - 1 do
            local e = edges[i % 12 + 1]
            local k = (i // 12) / (NP // 12)
            local A, B = V[e[1]], V[e[2]]
            s[i] = { lerp(A[1], B[1], k) * 0.7, lerp(A[2], B[2], k) * 0.7, lerp(A[3], B[3], k) * 0.7 }
        end
        return s
    end
    local function helix()
        local s = {}
        for i = 0, NP - 1 do
            local k = (i // 2) / (NP // 2)
            local a = k * TAU * 2.5 + (i % 2) * PI
            s[i] = { cos(a) * 0.55, k * 2 - 1, sin(a) * 0.55 }
        end
        return s
    end
    local function knot()
        local s = {}
        for i = 0, NP - 1 do
            local a = i / NP * TAU
            local r = 0.55 + 0.25 * cos(3 * a)
            s[i] = { r * cos(2 * a), 0.3 * sin(3 * a), r * sin(2 * a) }
        end
        return s
    end
    function morph.init()
        shapes = { sphere(), torus(), cube(), knot(), helix() }
        for i = 0, NP - 1 do cur[i] = { 0, 0, 0 } end
        for l = 0, 3 do
            pal[l] = {}
            for h = 0, 31 do pal[l][h] = hsv(h / 32, 0.75 - l * 0.1, 0.35 + l * 0.22) end
        end
    end
    function morph.draw(t, st)
        local seg = 1.8
        local n = #shapes
        local si = floor(st / seg)
        local A, B = shapes[si % n + 1], shapes[(si + 1) % n + 1]
        local u = (st % seg) / seg
        local ay, ax = t * 0.9, sin(t * 0.55) * 0.7
        local cy, sy, cx, sx = cos(ay), sin(ay), cos(ax), sin(ax)
        local bg = rgb(6, 4, 16)
        display.fill_screen(bg)
        local x0, y0, F = W / 2, H / 2, H * 1.15
        local hshift = floor(t * 12)
        for i = 0, NP - 1 do
            local k = E.in_out_cubic(clamp((u - 0.55 - (i / NP) * 0.25) / 0.2, 0, 1))
            local a, b = A[i], B[i]
            local x, y, z = lerp(a[1], b[1], k), lerp(a[2], b[2], k), lerp(a[3], b[3], k)
            local x1 = x * cy - z * sy
            local z1 = x * sy + z * cy
            local y1 = y * cx - z1 * sx
            local z2 = y * sx + z1 * cx
            local d = 1 / (z2 + 2.8)
            local l = floor(clamp((1 - z2) * 2, 0, 3))
            local sz = l // 2 + 1
            display.fill_rect(floor(x0 + x1 * F * d), floor(y0 + y1 * F * d), sz + (l == 3 and 1 or 0), sz + (l == 3 and 1 or 0), pal[l][(i // 5 + hshift) % 32])
        end
    end
end

---------------------------------------------------------------- Bounce (куб зі сплющенням і розтягом)
local bounce = { name = "Squash & Stretch" }
do
    local V, FACES, FCOL = {}, {}, {}
    local CAMY, CAMZ, TILT, F = 2.6, -7.5, 0.2, 0
    local ct, stl = cos(TILT), sin(TILT)
    local sky, floorc = {}, {}
    local shadow
    local function proj(x, y, z)
        y, z = y - CAMY, z - CAMZ
        local y2 = y * ct + z * stl
        local z2 = -y * stl + z * ct
        return W / 2 + x * F / z2, H * 0.56 - y2 * F / z2
    end
    function bounce.init()
        F = H * 1.1
        for i = 0, 7 do V[i] = { (i & 1) * 2 - 1, ((i >> 1) & 1) * 2 - 1, ((i >> 2) & 1) * 2 - 1 } end
        -- вершини граней проти годинникової стрілки, якщо дивитися ззовні
        FACES = {
            { 0, 2, 3, 1, 0, 0, -1 }, { 4, 5, 7, 6, 0, 0, 1 },
            { 0, 1, 5, 4, 0, -1, 0 }, { 2, 6, 7, 3, 0, 1, 0 },
            { 0, 4, 6, 2, -1, 0, 0 }, { 1, 3, 7, 5, 1, 0, 0 },
        }
        local hues = { 0.0, 0.08, 0.55, 0.62, 0.3, 0.85 }
        for f = 1, 6 do
            FCOL[f] = {}
            for l = 0, 15 do FCOL[f][l] = hsv(hues[f], 0.7, 0.2 + 0.8 * l / 15) end
        end
        for i = 0, 11 do sky[i] = rgb(lerp(20, 255, (i / 11) ^ 2), lerp(30, 150, i / 11), lerp(80, 120, i / 11)) end
        for i = 0, 15 do floorc[i] = rgb(255 - i * 12, 80 - i * 4, 200 - i * 9) end
        shadow = rgb(10, 4, 22)
    end
    function bounce.draw(t, st)
        local _, hy = proj(0, 0, 60)
        hy = floor(hy)
        for i = 0, 11 do
            local y0, y1 = floor(i * hy / 12), floor((i + 1) * hy / 12)
            display.fill_rect(0, y0, W, y1 - y0, sky[i])
        end
        display.fill_rect(0, hy, W, H - hy, rgb(24, 8, 40))
        -- підлога, що їде назустріч
        local off = (t * 3) % 2
        for k = 0, 14 do
            local z = 30 - k * 2 + off
            local xa, ya = proj(-14, 0, z)
            local xb, yb = proj(14, 0, z)
            display.draw_line(floor(xa), floor(ya), floor(xb), floor(yb), floorc[clamp(floor(z / 2), 0, 15)])
        end
        for k = -7, 7 do
            local xa, ya = proj(k * 2, 0, -3)
            local xb, yb = proj(k * 2, 0, 32)
            display.draw_line(floor(xa), floor(ya), floor(xb), floor(yb), floorc[6])
        end

        local per = 1.1
        local ph = (st / per) % 1
        local h = 4 * ph * (1 - ph) * 1.5
        -- сплющення в момент удару, розтяг у польоті
        local sq = 0
        if ph < 0.12 then sq = 1 - ph / 0.12 elseif ph > 0.92 then sq = (ph - 0.92) / 0.08 end
        sq = E.out_cubic(sq)
        local vel = math.abs(1 - 2 * ph)
        local syk = 1 - 0.38 * sq + 0.18 * vel * (1 - sq)
        local sxk = 1 / sqrt(syk)
        local ry = t * 0.8
        local rx = E.in_out_quad(ph) * PI / 2 -- чверть оберту на стрибок: куб приземляється на грань
        local cr, sr, cx, sx = cos(ry), sin(ry), cos(rx), sin(rx)
        local S = 0.85
        local cyw = S * syk + h

        local sxp, syp = proj(0, 0, 0)
        local sh = 1 / (1 + h * 0.4)
        display.fill_ellipse(floor(sxp), floor(syp), floor(F * 0.13 * sh * sxk), floor(F * 0.025 * sh), shadow)

        local P, N = {}, {}
        for i = 0, 7 do
            local v = V[i]
            local y1 = v[2] * cx - v[3] * sx
            local z1 = v[2] * sx + v[3] * cx
            local x2 = v[1] * cr + z1 * sr
            local z2 = -v[1] * sr + z1 * cr
            local px, py = proj(x2 * S * sxk, y1 * S * syk + cyw, z2 * S * sxk)
            P[i] = { px, py }
        end
        local lx, ly, lz = -0.45, 0.75, -0.5
        for f = 1, 6 do
            local fc = FACES[f]
            local a, b, c, d = P[fc[1]], P[fc[2]], P[fc[3]], P[fc[4]]
            local cross = (b[1] - a[1]) * (c[2] - a[2]) - (b[2] - a[2]) * (c[1] - a[1])
            if cross > 0 then
                local nx, ny, nz = fc[5], fc[6], fc[7]
                local ny1 = ny * cx - nz * sx
                local nz1 = ny * sx + nz * cx
                local nx2 = nx * cr + nz1 * sr
                local nz2 = -nx * sr + nz1 * cr
                local lit = clamp(nx2 * lx + ny1 * ly + nz2 * lz, 0, 1)
                local col = FCOL[f][floor(3 + lit * 12)]
                display.fill_triangle(floor(a[1]), floor(a[2]), floor(b[1]), floor(b[2]), floor(c[1]), floor(c[2]), col)
                display.fill_triangle(floor(a[1]), floor(a[2]), floor(c[1]), floor(c[2]), floor(d[1]), floor(d[2]), col)
            end
        end
    end
end

---------------------------------------------------------------- Twister
local twister = { name = "Twister" }
do
    local FC, stars = {}, {}
    local hues = { 0.95, 0.12, 0.5, 0.75 }
    function twister.init()
        for k = 0, 3 do
            FC[k] = {}
            for l = 0, 15 do FC[k][l] = hsv(hues[k + 1], 0.75, 0.15 + 0.85 * l / 15) end
        end
        for i = 1, 70 do stars[i] = { x = rnd() * W, y = rnd() * H, z = 1 + (i % 3) } end
    end
    function twister.draw(t)
        display.fill_screen(BLACK)
        for _, s in ipairs(stars) do
            local x = (s.x - t * 18 * s.z) % W
            local b = 50 + s.z * 60
            display.fill_rect(floor(x), floor(s.y), s.z, 1, rgb(b, b, b + 30))
        end
        local R = 34
        local amp = 1.6 + sin(t * 0.7) * 1.4
        for y = 0, H - 1, 2 do
            local cx = W / 2 + sin(y * 0.021 + t * 1.9) * 38
            local a = t * 1.3 + sin(t * 0.8 + y * 0.011) * amp
            local s, c = sin(a), cos(a)
            local xs = { cx + R * s, cx + R * c, cx - R * s, cx - R * c }
            for k = 0, 3 do
                local x1, x2 = xs[k + 1], xs[(k + 1) % 4 + 1]
                if x2 > x1 + 0.5 then
                    local l = floor(clamp((x2 - x1) / (R * 1.42), 0, 1) * 15)
                    display.fill_rect(floor(x1), y, floor(x2) - floor(x1), 2, FC[k][l])
                end
            end
        end
    end
end

---------------------------------------------------------------- Scroller
local scroller = { name = "Copper & Scroll" }
do
    local MSG = "     LILKA MOTION DEMO  ***  PLASMA - TUNNEL - MORPH - SQUASH & STRETCH - TWISTER - EASING - FIREWORKS - WAVES - HARMONOGRAPH  ***  MADE IN UKRAINE  ***  GREETINGS TO EVERY LILKA OWNER!     "
    local LOGO = "LILKA"
    local bars = {}
    function scroller.init()
        local hues = { 0.0, 0.08, 0.16, 0.33, 0.55, 0.75 }
        for b = 1, #hues do
            bars[b] = {}
            for l = 0, 7 do
                local k = sin((l + 0.5) / 8 * PI)
                bars[b][l] = hsv(hues[b], 0.8 - 0.5 * k ^ 4, 0.2 + 0.8 * k)
            end
        end
    end
    function scroller.draw(t, st)
        display.fill_screen(BLACK)
        local order = {}
        for b = 1, #bars do
            local a = t * 1.7 + b * 0.55
            order[b] = { b = b, y = H * 0.5 + sin(a) * H * 0.34, z = cos(a) }
        end
        table.sort(order, function(p, q) return p.z < q.z end)
        for _, o in ipairs(order) do
            local y0 = floor(o.y) - 8
            for l = 0, 7 do display.fill_rect(0, y0 + l * 2, W, 2, bars[o.b][l]) end
        end

        -- літери логотипа падають з відскоком
        local lw = 30
        local lx = W / 2 - #LOGO * lw / 2 + 4
        for i = 1, #LOGO do
            local u = clamp((st - 0.3 - i * 0.15) / 1.1, 0, 1)
            local y = lerp(-30, 52, E.out_bounce(u)) + sin(t * 3 + i) * 3 * u
            local ch = LOGO:sub(i, i)
            display.set_font("10x20")
            display.set_text_size(3)
            display.set_text_color(rgb(40, 0, 60))
            display.set_cursor(floor(lx + (i - 1) * lw + 3), floor(y + 3))
            display.print(ch)
            display.set_text_color(RAINBOW[(i * 8 + floor(t * 30)) % 64])
            display.set_cursor(floor(lx + (i - 1) * lw), floor(y))
            display.print(ch)
        end
        display.set_text_size(1)

        -- синусний скролер
        local cw = 10
        local total = #MSG * cw
        local off = (t * 80) % total
        local first = floor(off / cw)
        for n = 0, W // cw + 1 do
            local idx = (first + n) % #MSG + 1
            local ch = MSG:sub(idx, idx)
            if ch ~= " " then
                local x = n * cw - (off % cw)
                local y = H - 34 + sin(x * 0.035 + t * 4) * 14
                text(ch, x, y, RAINBOW[floor(x * 0.25 + t * 40) % 64], "10x20")
            end
        end
    end
end

---------------------------------------------------------------- Easing
local easing = { name = "Easing" }
do
    local list = {
        { "linear", E.linear }, { "in-out quad", E.in_out_quad }, { "out cubic", E.out_cubic },
        { "out back", E.out_back }, { "out elastic", E.out_elastic }, { "out bounce", E.out_bounce },
    }
    local ghost = {}
    function easing.init()
        for i = 1, #list do
            ghost[i] = {}
            for g = 0, 5 do ghost[i][g] = hsv(i / #list, 0.8, 1 - g * 0.15) end
        end
    end
    function easing.draw(t, st)
        display.fill_screen(rgb(8, 10, 20))
        local rh = (H - 8) / #list
        local X0, X1 = 16, W - 64
        local GX, GW = W - 52, 40
        local cyc = 2.2
        local ph = st % cyc
        local dir = floor(st / cyc) % 2
        local track, axis = rgb(40, 46, 70), rgb(70, 76, 110)
        for i, e in ipairs(list) do
            local y = floor(4 + (i - 0.5) * rh)
            text(e[1], X0, y - 6, rgb(150, 160, 200), "5x7")
            display.draw_line(X0, y + 4, X1, y + 4, track)
            -- графік функції
            local gy0, gh = y + 10, rh - 8
            display.draw_line(GX, gy0, GX + GW, gy0, axis)
            local px, py = GX, gy0
            for s = 1, 16 do
                local qx = GX + GW * s / 16
                local qy = gy0 - gh * e[2](s / 16)
                display.draw_line(floor(px), floor(py), floor(qx), floor(qy), ghost[i][3])
                px, py = qx, qy
            end
            -- кулька зі шлейфом
            for g = 5, 0, -1 do
                local u = clamp((ph - g * 0.035) / 1.6, 0, 1)
                local v = e[2](u)
                if dir == 1 then v = 1 - v end
                local x = lerp(X0 + 5, X1 - 5, v)
                display.fill_circle(floor(x), y + 4, g == 0 and 5 or 4 - g // 2, ghost[i][g])
                if g == 0 then
                    local gu = clamp(ph / 1.6, 0, 1)
                    local gx = GX + GW * (dir == 1 and 1 - gu or gu)
                    local gv = e[2](dir == 1 and 1 - gu or gu)
                    display.fill_circle(floor(gx), floor(gy0 - gh * gv), 2, WHITE)
                end
            end
        end
    end
end

---------------------------------------------------------------- Fireworks
local fireworks = { name = "Fireworks" }
do
    local parts, rockets, city = {}, {}, {}
    local next_launch = 0
    local sky
    local GRAV = 70
    function fireworks.init()
        sky = {}
        for i = 0, 7 do sky[i] = rgb(2 + i * 3, 2 + i * 2, 14 + i * 5) end
        local x = 0
        while x < W do
            local w = 10 + floor(rnd() * 22)
            local h = 10 + floor(rnd() * 36)
            local wins = {}
            for k = 1, floor(w * h / 60) do wins[k] = { floor(rnd() * (w - 4)) + 2, floor(rnd() * (h - 6)) + 3 } end
            city[#city + 1] = { x = x, w = w, h = h, wins = wins }
            x = x + w + 1
        end
    end
    function fireworks.enter()
        parts, rockets, next_launch = {}, {}, 0
    end
    local function explode(r)
        local hue = floor(rnd() * 8) % 8
        local n = 36 + floor(rnd() * 20)
        local sp = 45 + rnd() * 30
        local ring = rnd() < 0.35
        for i = 1, n do
            local a = i / n * TAU + rnd() * 0.1
            local s = ring and sp or sp * (0.3 + 0.7 * sqrt(rnd()))
            parts[#parts + 1] = { x = r.x, y = r.y, px = r.x, py = r.y, vx = cos(a) * s, vy = sin(a) * s, life = 1.4 + rnd() * 0.7, age = 0, hue = hue }
        end
    end
    function fireworks.update(dt)
        next_launch = next_launch - dt
        if next_launch <= 0 then
            next_launch = 0.35 + rnd() * 0.6
            rockets[#rockets + 1] = { x = W * (0.15 + 0.7 * rnd()), y = H, vx = (rnd() - 0.5) * 20, vy = -(H * 0.55 + rnd() * H * 0.25) }
        end
        for i = #rockets, 1, -1 do
            local r = rockets[i]
            r.x, r.y = r.x + r.vx * dt, r.y + r.vy * dt
            r.vy = r.vy + GRAV * 1.3 * dt
            if r.vy > -15 then explode(r); table.remove(rockets, i) end
        end
        local drag = 1 - 1.4 * dt
        for i = #parts, 1, -1 do
            local p = parts[i]
            p.px, p.py = p.x, p.y
            p.vx, p.vy = p.vx * drag, p.vy * drag + GRAV * dt
            p.x, p.y = p.x + p.vx * dt, p.y + p.vy * dt
            p.age = p.age + dt
            if p.age > p.life then
                parts[i] = parts[#parts]
                parts[#parts] = nil
            end
        end
    end
    function fireworks.draw(t)
        for i = 0, 7 do
            local y0, y1 = floor(i * H / 8), floor((i + 1) * H / 8)
            display.fill_rect(0, y0, W, y1 - y0, sky[i])
        end
        for _, r in ipairs(rockets) do
            display.draw_line(floor(r.x), floor(r.y), floor(r.x - r.vx * 0.06), floor(r.y - r.vy * 0.06), FADE[1][8])
            display.fill_rect(floor(r.x), floor(r.y), 2, 2, WHITE)
        end
        for _, p in ipairs(parts) do
            local k = p.age / p.life
            local l = floor((1 - k) * 15)
            if k > 0.6 and rnd() < 0.3 then l = 15 end -- мерехтіння
            local c = FADE[p.hue][l]
            display.draw_line(floor(p.px), floor(p.py), floor(p.x), floor(p.y), FADE[p.hue][l // 2])
            display.fill_rect(floor(p.x), floor(p.y), 2, 2, c)
        end
        local bc, wc = rgb(4, 4, 10), rgb(255, 210, 120)
        for _, b in ipairs(city) do
            display.fill_rect(b.x, H - b.h, b.w, b.h, bc)
            for k, w in ipairs(b.wins) do
                if sin(t * 0.3 + k * 1.7 + b.x) > -0.6 then display.fill_rect(b.x + w[1], H - b.h + w[2], 2, 2, wc) end
            end
        end
    end
end

---------------------------------------------------------------- Waves (3D сітка)
local waves = { name = "Waves" }
do
    local G = 18
    local pal = {}
    local PX, PY = {}, {}
    function waves.init()
        for l = 0, 31 do pal[l] = hsv(0.5 + l / 31 * 0.45, 0.8, 0.35 + 0.65 * l / 31) end
    end
    function waves.draw(t)
        display.fill_screen(rgb(4, 2, 14))
        local ay = t * 0.25
        local ca, sa = cos(ay), sin(ay)
        local F = H * 1.0
        local tilt = 0.5 + sin(t * 0.4) * 0.12
        local ct, stl = cos(tilt), sin(tilt)
        local mx, mz = sin(t * 0.7) * 0.5, cos(t * 0.5) * 0.5
        local HV = {}
        for j = 0, G do
            for i = 0, G do
                local x, z = (i / G) * 2 - 1, (j / G) * 2 - 1
                local d1 = sqrt((x - mx) ^ 2 + (z - mz) ^ 2)
                local h = sin(d1 * 9 - t * 4) * 0.12 * (1.2 - d1 * 0.5) + sin(x * 4 + t * 1.3) * 0.05
                local xr = x * ca - z * sa
                local zr = x * sa + z * ca
                local y2 = h * ct - zr * stl
                local z2 = h * stl + zr * ct + 2.6
                local k = j * (G + 1) + i
                PX[k] = W / 2 + xr * F / z2
                PY[k] = H * 0.52 - y2 * F / z2
                HV[k] = floor(clamp((h + 0.17) / 0.34, 0, 1) * 31)
            end
        end
        for j = 0, G do
            for i = 0, G do
                local k = j * (G + 1) + i
                local x0, y0 = floor(PX[k]), floor(PY[k])
                if i < G then display.draw_line(x0, y0, floor(PX[k + 1]), floor(PY[k + 1]), pal[HV[k]]) end
                if j < G then display.draw_line(x0, y0, floor(PX[k + G + 1]), floor(PY[k + G + 1]), pal[HV[k]]) end
            end
        end
    end
end

---------------------------------------------------------------- Harmonograph
local harmono = { name = "Harmonograph" }
do
    local NS = 260
    function harmono.draw(t)
        display.fill_screen(rgb(6, 6, 12))
        local cx, cy = W / 2, H / 2
        local A = H * 0.24
        local p1, p2, p3 = t * 0.31, t * 0.23 + 1, t * 0.17 + 2
        local px, py
        local hs = floor(t * 25)
        for i = 0, NS do
            local s = i / NS * TAU * 4
            local damp = 1 - i / NS * 0.65
            local x = cx + (sin(3 * s + p1) + sin(2 * s + p3) * 0.6) * A * damp * 1.15
            local y = cy + (sin(4 * s + p2) * 0.8 + cos(3 * s) * 0.45) * A * damp
            if px then display.draw_line(floor(px), floor(py), floor(x), floor(y), RAINBOW[(i // 3 + hs) % 64]) end
            px, py = x, y
        end
        -- перо
        local s = (t * 0.8) % (TAU * 4)
        local i = s / (TAU * 4)
        local damp = 1 - i * 0.65
        local x = cx + (sin(3 * s + p1) + sin(2 * s + p3) * 0.6) * A * damp * 1.15
        local y = cy + (sin(4 * s + p2) * 0.8 + cos(3 * s) * 0.45) * A * damp
        display.fill_circle(floor(x), floor(y), 4, WHITE)
        display.draw_circle(floor(x), floor(y), 6 + floor(sin(t * 8) * 2), RAINBOW[hs % 64])
    end
end

---------------------------------------------------------------- Режисер
local SCENES = { plasma, tunnel, morph, bounce, twister, scroller, easing, fireworks, waves, harmono }
local cur, st, t = 1, 0, 0
local paused = false

local function enter(i)
    cur = (i - 1) % #SCENES + 1
    st = 0
    if SCENES[cur].enter then SCENES[cur].enter() end
end

function lilka.init()
    W, H = display.width, display.height
    -- Застосунок стартує на весь екран, тож display.height = 240 навіть з fullscreen = false
    if not lilka.fullscreen and H > 216 then H = H - 24 end
    BLACK, WHITE = rgb(0, 0, 0), rgb(255, 255, 255)
    for k = 0, 255 do SN[k] = floor(31.5 + 31.5 * sin(k / 256 * TAU) + 0.5) end
    for h = 0, 63 do RAINBOW[h] = hsv(h / 64, 0.85, 1) end
    for h = 0, 7 do
        FADE[h] = {}
        for l = 0, 15 do
            local k = l / 15
            FADE[h][l] = hsv(h / 8, 0.9 - 0.6 * k ^ 3, k)
        end
    end
    for _, s in ipairs(SCENES) do if s.init then s.init() end end
    enter(1)
end

function lilka.update(delta)
    local dt = min(delta, 0.1)
    t = t + dt
    if not paused then st = st + dt end
    if controller then
        local s = controller.get_state()
        if s.start.just_pressed then util.exit() end
        if s.right.just_pressed then enter(cur + 1) end
        if s.left.just_pressed then enter(cur - 1) end
        if s.a.just_pressed then paused = not paused end
    end
    if st >= DUR then enter(cur + 1) end
    if SCENES[cur].update then SCENES[cur].update(dt) end
end

local function transition(p, kind)
    if p <= 0 then return end
    if kind == 0 then
        local n = 12
        local sh = (H + n - 1) // n
        for j = 0, n - 1 do display.fill_rect(0, j * sh, W, floor(sh * p + 0.99), BLACK) end
    elseif kind == 1 then
        local n = 14
        local sw = (W + n - 1) // n
        for i = 0, n - 1 do display.fill_rect(i * sw, 0, floor(sw * p + 0.99), H, BLACK) end
    else
        local C = 20
        local cols, rows = (W + C - 1) // C, (H + C - 1) // C
        for j = 0, rows - 1 do
            for i = 0, cols - 1 do
                local d = (i + j) / (cols + rows - 2) * 0.5
                local q = clamp((p - d) / 0.5, 0, 1)
                local s = floor(C * q + 0.99)
                if s > 0 then display.fill_rect(i * C + (C - s) // 2, j * C + (C - s) // 2, s, s, BLACK) end
            end
        end
    end
end

function lilka.draw()
    SCENES[cur].draw(t, st)

    -- назва сцени виїжджає і ховається
    local sc = SCENES[cur]
    local tx
    if st < 2.6 then tx = lerp(-150, 6, E.out_back(clamp((st - 0.3) / 0.6, 0, 1)))
    else tx = lerp(6, -150, E.in_back(clamp((st - 2.6) / 0.4, 0, 1))) end
    if tx > -140 then
        local label = string.format("%02d/%02d %s", cur, #SCENES, sc.name)
        display.fill_rect(floor(tx) - 6, H - 22, #label * 7 + 12, 16, BLACK)
        display.fill_rect(floor(tx) - 6, H - 22, 3, 16, RAINBOW[floor(t * 30) % 64])
        text(label, tx, H - 10, WHITE, "7x13")
    end

    -- смужка прогресу
    display.fill_rect(0, H - 2, floor(W * st / DUR), 2, RAINBOW[floor(t * 20) % 64])
    if paused then
        display.fill_rect(W - 14, 6, 3, 10, WHITE)
        display.fill_rect(W - 9, 6, 3, 10, WHITE)
    end

    if not paused and st > DUR - TR then
        transition((st - (DUR - TR)) / TR, cur % 3)
    elseif st < TR then
        transition(1 - st / TR, (cur - 2) % 3)
    end
end
