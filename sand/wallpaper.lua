-- Пісок: невидимі руки сиплють кольоровий пісок і ллють воду на кам'яні виступи.
-- Пісок тоне у воді, вода розтікається. Коли екран заповниться, дно відкривається і все висипається.
-- Застосунок: A — пауза, B — злити все, START — вихід.

lilka.fullscreen = false

local CS = 4          -- розмір піщинки, px
local FILL = 0.5      -- частка заповнення, після якої дно відкривається
local MAX_TIME = 75   -- секунд на одну картину

local floor, rnd, sin = math.floor, math.random, math.sin
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
    return rgb(r * 255, g * 255, b * 255)
end
local function rand_int(n) return min(n - 1, floor(rnd() * n)) end -- 0..n-1

-- Значення клітинки — індекс палітри: 0 порожньо, 1 камінь, 2..5 вода, 6.. пісок
local STONE, W0, W1, S0 = 1, 2, 5, 6
local SAND_N = 48

local W, H, GW, GH, N, OX, OY
local g, mv = {}, {} -- поле й позначки «вже рухалась на цьому кроці»
local tick = 0
local pal = {}
local bg
local emitters = {}
local phase, t, acc, paused = "pour", 0, 0, false
local count = 0
local theme = 0

local function stone_line(x0, y0, x1, y1, th)
    local n = max(math.abs(x1 - x0), math.abs(y1 - y0))
    for k = 0, n do
        local x = floor(x0 + (x1 - x0) * k / n + 0.5)
        local y = floor(y0 + (y1 - y0) * k / n + 0.5)
        for d = 0, th - 1 do
            if x >= 0 and x < GW and y + d >= 0 and y + d < GH then g[(y + d) * GW + x] = STONE end
        end
    end
end

local function new_scene()
    for i = 0, N - 1 do g[i], mv[i] = 0, 0 end
    theme = theme + 1
    -- Палітра піску: кожна сцена — своя гама
    local base, spread = rnd(), 0.15 + rnd() * 0.5
    for k = 0, SAND_N - 1 do
        local u = k / SAND_N
        local h = base + spread * sin(u * 6.283)
        pal[S0 + k] = hsv(h, 0.55 + 0.35 * sin(u * 12.566 + 1) ^ 2, 0.75 + 0.25 * sin(u * 18.85) ^ 2)
    end
    -- Виступи: кілька похилих полиць і, можливо, лійка посередині
    local shelves = 3 + rand_int(3)
    for _ = 1, shelves do
        local len = 8 + rand_int(14)
        local x = rand_int(GW - len)
        local y = 12 + rand_int(GH - 24)
        local slope = (rnd() - 0.5) * 0.9
        stone_line(x, y, x + len, floor(y + len * slope), 2)
    end
    if rnd() < 0.6 then
        local cx, cy, gap = GW // 2 + rand_int(21) - 10, 10 + rand_int(GH // 3), 2
        stone_line(cx - 16, cy - 8, cx - gap, cy, 2)
        stone_line(cx + gap, cy, cx + 16, cy - 8, 2)
    end
    emitters = {}
    local ne = 2 + rand_int(2)
    for k = 1, ne do
        emitters[k] = {
            x = rnd() * GW, sp = (6 + rnd() * 10) * (rnd() < 0.5 and -1 or 1),
            c = rand_int(SAND_N), water = (k == ne and rnd() < 0.7),
            on = true, sw = 1 + rnd() * 4,
        }
    end
    phase, t, count = "pour", 0, 0
end

-- Один крок фізики. Знизу вгору; напрямок обходу рядка чергується, щоб не було перекосу
local function step()
    tick = tick + 1
    local tk = tick
    local drain = phase == "drain"
    if drain then
        local last = (GH - 1) * GW
        for x = 0, GW - 1 do g[last + x] = 0 end
    end
    local dir = tick % 2 == 0 and 1 or -1
    for y = GH - 2, 0, -1 do
        local row, below = y * GW, (y + 1) * GW
        local x0, x1 = 0, GW - 1
        if dir < 0 then x0, x1 = GW - 1, 0 end
        for x = x0, x1, dir do
            local i = row + x
            local v = g[i]
            if v >= W0 and mv[i] ~= tk then
                local d = below + x
                local b = g[d]
                local water = v <= W1
                if b == 0 or (not water and b >= W0 and b <= W1) then
                    g[i], g[d] = b, v
                    mv[d] = tk
                else
                    local s = rnd() < 0.5 and 1 or -1
                    local moved = false
                    for _ = 1, 2 do
                        local nx = x + s
                        if nx >= 0 and nx < GW then
                            local dd = below + nx
                            local bb = g[dd]
                            if bb == 0 or (not water and bb >= W0 and bb <= W1) then
                                g[i], g[dd] = bb, v
                                mv[dd] = tk
                                moved = true
                                break
                            end
                        end
                        s = -s
                    end
                    if not moved and water then -- вода розтікається вбік
                        local nx = x + s
                        if nx >= 0 and nx < GW and g[row + nx] == 0 then
                            g[i], g[row + nx] = 0, v
                            mv[row + nx] = tk
                        end
                    end
                end
            end
        end
    end
end

local function pour(delta)
    for _, e in ipairs(emitters) do
        e.x = e.x + e.sp * delta
        if e.x < 1 then e.x, e.sp = 1, -e.sp end
        if e.x > GW - 2 then e.x, e.sp = GW - 2, -e.sp end
        e.sw = e.sw - delta
        if e.sw <= 0 then -- іноді пауза, іноді зміна швидкості
            e.on = rnd() < 0.8
            e.sp = (5 + rnd() * 12) * (e.sp < 0 and -1 or 1) * (rnd() < 0.25 and -1 or 1)
            e.sw = 1 + rnd() * 4
        end
        if e.on then
            e.c = (e.c + delta * 6) % SAND_N
            for k = 0, 1 do
                local x = floor(e.x) + k
                local i = x
                if g[i] == 0 and (not e.water or rnd() < 0.4) then
                    if e.water then
                        g[i] = W0 + rand_int(W1 - W0 + 1)
                    else
                        g[i] = S0 + floor(e.c + rnd() * 1.5) % SAND_N
                    end
                    count = count + 1
                end
            end
        end
    end
end

function lilka.init()
    W, H = display.width, display.height
    -- Застосунок стартує на весь екран, тож display.height = 240 навіть з fullscreen = false
    if not lilka.fullscreen and H > 216 then H = H - 24 end
    GW, GH = W // CS, H // CS
    N = GW * GH
    OX, OY = (W - GW * CS) // 2, (H - GH * CS) // 2
    bg = rgb(10, 12, 22)
    pal[STONE] = rgb(88, 92, 110)
    pal[W0] = rgb(40, 110, 220)
    pal[W0 + 1] = rgb(50, 125, 230)
    pal[W0 + 2] = rgb(36, 100, 205)
    pal[W0 + 3] = rgb(70, 145, 240)
    new_scene()
end

function lilka.update(delta)
    if controller then
        local s = controller.get_state()
        if s.start.just_pressed then util.exit() end
        if s.a.just_pressed then paused = not paused end
        if s.b.just_pressed and phase == "pour" then phase, t = "drain", 0 end
    end
    if paused then return end
    delta = min(delta, 0.1)
    t = t + delta
    if phase == "pour" then
        pour(delta)
        if count > N * FILL or t > MAX_TIME then phase, t = "drain", 0 end
    elseif phase == "drain" then
        if t > 0.6 and t < 0.7 then -- камінь розсипається разом з усім
            for i = 0, N - 1 do if g[i] == STONE then g[i] = S0 + rand_int(SAND_N) end end
        end
        if t > 6 then new_scene() end
    end
    acc = acc + 30 * delta
    local k = min(floor(acc), 3)
    acc = min(acc - floor(acc), 1)
    for _ = 1, k do step() end
end

function lilka.draw()
    display.fill_screen(bg)
    local p = pal
    for y = 0, GH - 1 do
        local py, row = OY + y * CS, y * GW
        local x = 0
        while x < GW do
            local v = g[row + x]
            if v ~= 0 then
                -- Сусідні однакові клітинки малюємо одним прямокутником
                local x2 = x + 1
                while x2 < GW and g[row + x2] == v do x2 = x2 + 1 end
                display.fill_rect(OX + x * CS, py, (x2 - x) * CS, CS, p[v])
                x = x2
            else
                x = x + 1
            end
        end
    end
    if phase == "pour" then
        for _, e in ipairs(emitters) do
            if e.on then
                local c = e.water and p[W0 + 3] or p[S0 + floor(e.c) % SAND_N]
                display.fill_rect(OX + floor(e.x) * CS - 2, 0, CS * 2 + 4, 2, c)
            end
        end
    end
end
