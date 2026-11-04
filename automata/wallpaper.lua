-- Клітинні автомати: Життя Конвея, циклічний автомат, Brian's Brain, мурахи Ленгтона
-- та елементарні одновимірні правила (30, 90, 110...). Автомати змінюють один одного.
-- Застосунок: ← → — автомат, B — перезапуск, A — пауза, START — вихід.

lilka.fullscreen = false

local CS, TOP = 5, 16 -- розмір клітинки й висота верхньої панелі, px
local DURATION = 30   -- секунд на автомат

local floor, rnd = math.floor, math.random
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

local function text(s, x, y, c, font)
    display.set_font(font)
    display.set_text_size(1)
    display.set_text_color(c)
    display.set_cursor(floor(x), floor(y))
    display.print(s)
end

local W, H, GW, GH, N, OX, OY
local XL, XR, YU, YD = {}, {}, {}, {} -- сусіди з загортанням країв
local a, b = {}, {}                   -- поточне й наступне покоління
local col = {}                        -- колір клітинки (індекс у палітрі), 0 — фон
local gen = 0
local pal = {}

local function set_pal(list) pal = list end

-- Кожен автомат: name, rate (поколінь/с), init(), step(), color(i) → індекс палітри, info()

local life = { name = "Game of Life", rate = 10 }
-- a[i] > 0 — вік живої клітинки; a[i] < 0 — скільки кроків тому вона померла (слід)
function life.init()
    local p = {}
    for k = 0, 15 do p[k + 1] = hsv(0.48 + k * 0.03, 0.75, 1 - k * 0.025) end -- вік
    for k = 1, 6 do p[16 + k] = rgb(0, 40 - k * 6, 70 - k * 10) end           -- слід
    set_pal(p)
    for i = 0, N - 1 do a[i] = rnd() < 0.3 and 1 or 0 end
end
function life.step()
    local alive = 0
    for y = 0, GH - 1 do
        local u, r, d = YU[y], y * GW, YD[y]
        for x = 0, GW - 1 do
            local l, rr = XL[x], XR[x]
            local n = 0
            if a[u + l] > 0 then n = n + 1 end
            if a[u + x] > 0 then n = n + 1 end
            if a[u + rr] > 0 then n = n + 1 end
            if a[r + l] > 0 then n = n + 1 end
            if a[r + rr] > 0 then n = n + 1 end
            if a[d + l] > 0 then n = n + 1 end
            if a[d + x] > 0 then n = n + 1 end
            if a[d + rr] > 0 then n = n + 1 end
            local i, v = r + x, a[r + x]
            if v > 0 then
                if n == 2 or n == 3 then b[i] = v + 1; alive = alive + 1 else b[i] = -1 end
            elseif n == 3 then
                b[i] = 1; alive = alive + 1
            elseif v < 0 and v > -6 then
                b[i] = v - 1
            else
                b[i] = 0
            end
        end
    end
    a, b = b, a
    -- Підкидаємо нові клітини, коли поле вимирає
    if alive < N // 40 then
        local cx, cy = rand_int(GW), rand_int(GH)
        for _ = 1, 40 do
            local x, y = (cx + rand_int(9)) % GW, (cy + rand_int(9)) % GH
            a[y * GW + x] = 1
        end
    end
    life.alive = alive
end
function life.color(i)
    local v = a[i]
    if v > 0 then return min(16, v) end
    if v < 0 then return 16 - v end
    return 0
end
function life.info() return "alive " .. (life.alive or 0) end

local cyclic = { name = "Cyclic CA", rate = 14 }
local CYC = 8
function cyclic.init()
    local p, base = {}, rnd()
    for k = 0, CYC - 1 do p[k + 1] = hsv(base + k / CYC * 0.7, 0.75, 0.3 + 0.7 * k / (CYC - 1)) end
    set_pal(p)
    for i = 0, N - 1 do a[i] = rand_int(CYC) end
end
function cyclic.step()
    local changed = 0
    for y = 0, GH - 1 do
        local u, r, d = YU[y], y * GW, YD[y]
        for x = 0, GW - 1 do
            local i = r + x
            local v = a[i]
            local nx = v + 1
            if nx == CYC then nx = 0 end
            if a[u + x] == nx or a[d + x] == nx or a[r + XL[x]] == nx or a[r + XR[x]] == nx then
                b[i] = nx
                changed = changed + 1
            else
                b[i] = v
            end
        end
    end
    a, b = b, a
    if changed == 0 then cyclic.init() end
end
function cyclic.color(i) return a[i] + 1 end
function cyclic.info() return CYC .. " states" end

local brain = { name = "Brian's Brain", rate = 10 }
-- 0 спокій, 1 збудження, 2 відновлення
function brain.init()
    set_pal({ rgb(255, 250, 220), rgb(200, 60, 140) })
    for i = 0, N - 1 do a[i] = rnd() < 0.18 and 1 or 0 end
end
function brain.step()
    local on = 0
    for y = 0, GH - 1 do
        local u, r, d = YU[y], y * GW, YD[y]
        for x = 0, GW - 1 do
            local i = r + x
            local v = a[i]
            if v == 1 then
                b[i] = 2
            elseif v == 2 then
                b[i] = 0
            else
                local l, rr = XL[x], XR[x]
                local n = 0
                if a[u + l] == 1 then n = n + 1 end
                if a[u + x] == 1 then n = n + 1 end
                if a[u + rr] == 1 then n = n + 1 end
                if a[r + l] == 1 then n = n + 1 end
                if a[r + rr] == 1 then n = n + 1 end
                if a[d + l] == 1 then n = n + 1 end
                if a[d + x] == 1 then n = n + 1 end
                if a[d + rr] == 1 then n = n + 1 end
                if n == 2 then b[i] = 1; on = on + 1 else b[i] = 0 end
            end
        end
    end
    a, b = b, a
    if on < N // 50 then -- на малому полі мозок згасає: підкидаємо іскри
        for _ = 1, 3 do
            local x, y = rand_int(GW - 1), rand_int(GH)
            a[y * GW + x], a[y * GW + x + 1] = 1, 1
        end
    end
    brain.on = on
end
function brain.color(i) return a[i] end
function brain.info() return "firing " .. (brain.on or 0) end

local ants = { name = "Langton's ants", rate = 400 }
local DX, DY = { 0, 1, 0, -1 }, { -1, 0, 1, 0 }
-- a[i]: 0 — порожня клітинка, k > 0 — її перефарбувала мурашка k
function ants.init()
    set_pal({ hsv(0.08, 0.8, 1), hsv(0.55, 0.8, 1), hsv(0.85, 0.6, 1), rgb(255, 255, 255) })
    for i = 0, N - 1 do a[i] = 0 end
    ants.list = {}
    for k = 1, 3 do
        ants.list[k] = { x = GW // 2 + rand_int(21) - 10, y = GH // 2 + rand_int(15) - 7, d = 1 + rand_int(4) }
    end
end
function ants.step()
    for k, t in ipairs(ants.list) do
        local i = t.y * GW + t.x
        if a[i] == 0 then
            t.d = t.d % 4 + 1      -- праворуч
            a[i] = k
        else
            t.d = (t.d + 2) % 4 + 1 -- ліворуч
            a[i] = 0
        end
        t.x = (t.x + DX[t.d]) % GW
        t.y = (t.y + DY[t.d]) % GH
    end
end
function ants.color(i) return a[i] end
function ants.info() return "step " .. gen end

local elem = { name = "Rule 30", rate = 16 }
local RULES = { 30, 90, 110, 45, 150, 73, 105, 22 }
local rule_k = 0
-- Нове покоління з'являється внизу, старі піднімаються вгору; a[y * GW + x] — рядок y
function elem.init()
    rule_k = rule_k % #RULES + 1
    elem.rule = RULES[rule_k]
    elem.name = "Rule " .. elem.rule
    local h = rnd()
    set_pal({ hsv(h, 0.6, 1), hsv(h + 0.1, 0.7, 0.75) })
    for i = 0, N - 1 do a[i] = 0 end
    local last = (GH - 1) * GW
    if rnd() < 0.5 then
        a[last + GW // 2] = 1
    else
        for x = 0, GW - 1 do a[last + x] = rnd() < 0.5 and 1 or 0 end
    end
end
function elem.step()
    for i = 0, N - GW - 1 do a[i] = a[i + GW] end
    local last, prev = (GH - 1) * GW, (GH - 2) * GW
    local rule = elem.rule
    for x = 0, GW - 1 do
        local k = (a[prev + XL[x]] > 0 and 4 or 0) + (a[prev + x] > 0 and 2 or 0) + (a[prev + XR[x]] > 0 and 1 or 0)
        a[last + x] = (rule >> k) & 1
    end
    -- Свіжі рядки світліші
    for x = 0, GW - 1 do
        local i = last - GW + x
        if a[i] > 0 then a[i] = 2 end
    end
end
function elem.color(i) return a[i] end
function elem.info() return "1D, wraps" end

local AUTOMATA = { life, cyclic, brain, ants, elem }
local cur, t, acc, paused = 1, 0, 0, false

local function pick(k)
    cur = (k - 1) % #AUTOMATA + 1
    t, acc, gen = 0, 0, 0
    AUTOMATA[cur].init()
end

function lilka.init()
    W, H = display.width, display.height
    -- Застосунок стартує на весь екран, тож display.height = 240 навіть з fullscreen = false
    if not lilka.fullscreen and H > 216 then H = H - 24 end
    GW, GH = W // CS, (H - TOP) // CS
    N = GW * GH
    OX = (W - GW * CS) // 2
    OY = TOP + (H - TOP - GH * CS) // 2
    for x = 0, GW - 1 do XL[x], XR[x] = (x - 1) % GW, (x + 1) % GW end
    for y = 0, GH - 1 do YU[y], YD[y] = ((y - 1) % GH) * GW, ((y + 1) % GH) * GW end
    for i = 0, N - 1 do a[i], b[i] = 0, 0 end
    pick(1 + rand_int(#AUTOMATA))
end

function lilka.update(delta)
    if controller then
        local s = controller.get_state()
        if s.start.just_pressed then util.exit() end
        if s.a.just_pressed then paused = not paused end
        if s.b.just_pressed then pick(cur) end
        if s.right.just_pressed then pick(cur + 1) end
        if s.left.just_pressed then pick(cur - 1) end
    end
    if paused then return end
    delta = min(delta, 0.1)
    t = t + delta
    if t > DURATION and not controller then pick(cur + 1) return end
    local m = AUTOMATA[cur]
    acc = acc + m.rate * delta
    local k = min(floor(acc), m.rate >= 30 and 40 or 2) -- на повільному пристрої просто сповільнюємось
    acc = min(acc - floor(acc), 1)
    for _ = 1, k do
        m.step()
        gen = gen + 1
    end
end

function lilka.draw()
    display.fill_screen(0)
    local m = AUTOMATA[cur]
    local color, p = m.color, pal
    for y = 0, GH - 1 do
        local py, r = OY + y * CS, y * GW
        for x = 0, GW - 1 do
            local c = color(r + x)
            if c > 0 then display.fill_rect(OX + x * CS, py, CS, CS, p[c]) end
        end
    end
    if m == ants then
        for _, a1 in ipairs(ants.list) do
            display.fill_rect(OX + a1.x * CS - 1, OY + a1.y * CS - 1, CS + 2, CS + 2, 0xFFFF)
        end
    end
    display.fill_rect(0, 0, W, TOP, 0)
    local info = m.info()
    if m ~= ants then info = info .. "  gen " .. gen end
    if paused then info = "paused" end
    text(m.name, 4, 12, 0xFFFF, "6x13")
    text(info, W - 4 - #info * 5, 11, rgb(150, 150, 165), "5x7")
    if not controller then
        display.fill_rect(0, TOP - 2, floor(W * min(1, t / DURATION)), 1, p[#p > 2 and 3 or 1])
    end
end
