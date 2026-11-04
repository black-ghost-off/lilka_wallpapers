-- Сортування: кожен рядок 2D-градієнта перемішано, а потім алгоритм сортує всі рядки одночасно.
-- Алгоритми змінюють один одного; кольори за замовчуванням — ocean.
-- Застосунок: ← → — алгоритм, ↑ ↓ — кольори, A — пауза, START — вихід.

lilka.fullscreen = false

local CS, TOP = 4, 16 -- розмір клітинки й висота верхньої панелі, px

local floor, rnd = math.floor, math.random
local yield, cwrap = coroutine.yield, coroutine.wrap
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

-- Алгоритми працюють з об'єктом c: c.n, c.a (масив 1..n) та операціями,
-- кожна з яких — один крок анімації: less(i, j), lessv(x, y, k), get(i), swap(i, j), set(i, v)

local function bubble(c)
    local n = c.n
    for i = n, 2, -1 do
        local sw = false
        for j = 1, i - 1 do
            if c.less(j + 1, j) then c.swap(j, j + 1); sw = true end
        end
        if not sw then return end
    end
end

local function cocktail(c)
    local lo, hi = 1, c.n
    while lo < hi do
        local sw = false
        for j = lo, hi - 1 do
            if c.less(j + 1, j) then c.swap(j, j + 1); sw = true end
        end
        hi = hi - 1
        for j = hi, lo + 1, -1 do
            if c.less(j, j - 1) then c.swap(j, j - 1); sw = true end
        end
        lo = lo + 1
        if not sw then return end
    end
end

local function odd_even(c)
    local n, sorted = c.n, false
    while not sorted do
        sorted = true
        for start = 1, 2 do
            for i = start, n - 1, 2 do
                if c.less(i + 1, i) then c.swap(i, i + 1); sorted = false end
            end
        end
    end
end

local function insertion(c)
    for i = 2, c.n do
        local j = i
        while j > 1 and c.less(j, j - 1) do
            c.swap(j, j - 1)
            j = j - 1
        end
    end
end

local function selection(c)
    local n = c.n
    for i = 1, n - 1 do
        local m = i
        for j = i + 1, n do
            if c.less(j, m) then m = j end
        end
        if m ~= i then c.swap(i, m) end
    end
end

local function gnome(c)
    local i = 2
    while i <= c.n do
        if i == 1 or not c.less(i, i - 1) then
            i = i + 1
        else
            c.swap(i, i - 1)
            i = i - 1
        end
    end
end

local function comb(c)
    local n, gap, sorted = c.n, c.n, false
    while not sorted do
        gap = floor(gap / 1.3)
        if gap <= 1 then gap = 1; sorted = true end
        for i = 1, n - gap do
            if c.less(i + gap, i) then c.swap(i, i + gap); sorted = false end
        end
    end
end

local function shell(c)
    local n = c.n
    for _, gap in ipairs({ 23, 10, 4, 1 }) do
        if gap < n then
            for i = gap + 1, n do
                local j = i
                while j > gap and c.less(j, j - gap) do
                    c.swap(j, j - gap)
                    j = j - gap
                end
            end
        end
    end
end

local function merge(c)
    local a, aux = c.a, {}
    local function ms(lo, hi)
        if hi <= lo then return end
        local mid = (lo + hi) // 2
        ms(lo, mid)
        ms(mid + 1, hi)
        for k = lo, hi do aux[k] = a[k] end
        local i, j = lo, mid + 1
        for k = lo, hi do
            if i > mid then c.set(k, aux[j]); j = j + 1
            elseif j > hi then c.set(k, aux[i]); i = i + 1
            elseif c.lessv(aux[j], aux[i], k) then c.set(k, aux[j]); j = j + 1
            else c.set(k, aux[i]); i = i + 1 end
        end
    end
    ms(1, c.n)
end

local function quick(c)
    local function qs(lo, hi)
        if lo >= hi then return end
        local m = (lo + hi) // 2
        if m ~= hi then c.swap(m, hi) end
        local p = lo
        for j = lo, hi - 1 do
            if c.less(j, hi) then
                if p ~= j then c.swap(p, j) end
                p = p + 1
            end
        end
        if p ~= hi then c.swap(p, hi) end
        qs(lo, p - 1)
        qs(p + 1, hi)
    end
    qs(1, c.n)
end

local function heap(c)
    local n = c.n
    local function sift(root, e)
        while 2 * root <= e do
            local ch = 2 * root
            if ch + 1 <= e and c.less(ch, ch + 1) then ch = ch + 1 end
            if c.less(root, ch) then
                c.swap(root, ch)
                root = ch
            else
                return
            end
        end
    end
    for s = n // 2, 1, -1 do sift(s, n) end
    for e = n, 2, -1 do
        c.swap(1, e)
        sift(1, e - 1)
    end
end

local function radix(c) -- LSD, основа 4
    local n, a, buf = c.n, c.a, {}
    local exp = 1
    while exp < n do
        local count, digit = { 0, 0, 0, 0 }, {}
        for i = 1, n do
            local d = (c.get(i) // exp) % 4 + 1
            digit[i] = d
            count[d] = count[d] + 1
        end
        local pos = { 0, 0, 0, 0 }
        for d = 2, 4 do pos[d] = pos[d - 1] + count[d - 1] end
        for i = 1, n do
            local d = digit[i]
            pos[d] = pos[d] + 1
            buf[pos[d]] = a[i]
        end
        for i = 1, n do c.set(i, buf[i]) end
        exp = exp * 4
    end
end

local function shuffle(c)
    for i = c.n, 2, -1 do
        local j = 1 + rand_int(i)
        if j ~= i then c.swap(i, j) end
    end
end

local ALGOS = {
    { "Bubble sort", "O(n^2)", bubble },
    { "Quicksort", "O(n log n)", quick },
    { "Insertion sort", "O(n^2)", insertion },
    { "Merge sort", "O(n log n)", merge },
    { "Selection sort", "O(n^2)", selection },
    { "Heapsort", "O(n log n)", heap },
    { "Cocktail shaker", "O(n^2)", cocktail },
    { "Shellsort", "O(n^1.3)", shell },
    { "Gnome sort", "O(n^2)", gnome },
    { "Radix sort LSD", "O(n k)", radix },
    { "Odd-even sort", "O(n^2)", odd_even },
    { "Comb sort", "O(n^2/2^p)", comb },
}

local W, H, COLS, ROWS, OX, OY
local rows, pal = {}, {}
local stats = { cmp = 0, wr = 0 }
local cur, phase, ptime, paused = 1, "wait", 0, false
local acc, rate, steps, total = 0, 0, 0, 1

-- Операції для одного рядка. live = false — «сухий» прогін, щоб порахувати кроки
local function make_ctx(row, live)
    local a = row.a
    local c = { n = COLS, a = a, steps = 0 }
    local function step(i, j)
        c.steps = c.steps + 1
        if live then
            row.h1, row.h2 = i, j
            yield()
        end
    end
    function c.less(i, j)
        if live then stats.cmp = stats.cmp + 1 end
        step(i, j)
        return a[i] < a[j]
    end
    function c.lessv(x, y, k)
        if live then stats.cmp = stats.cmp + 1 end
        step(k, 0)
        return x < y
    end
    function c.get(i)
        step(i, 0)
        return a[i]
    end
    function c.swap(i, j)
        a[i], a[j] = a[j], a[i]
        if live then stats.wr = stats.wr + 2 end
        step(i, j)
    end
    function c.set(i, v)
        a[i] = v
        if live then stats.wr = stats.wr + 1 end
        step(i, 0)
    end
    return c
end

-- Кольорові режими: f(u, v, base) → колір; u — значення (0..1, вздовж рядка), v — номер рядка (0..1)
local function lerp(a, b, k) return a + (b - a) * k end
local function ramp(stops, k) -- лінійна шкала через кілька кольорів {r, g, b}
    k = clamp(k, 0, 1) * (#stops - 1)
    local i = min(#stops - 1, floor(k) + 1)
    local f, a, b = k - (i - 1), stops[i], stops[i + 1]
    return lerp(a[1], b[1], f), lerp(a[2], b[2], f), lerp(a[3], b[3], f)
end
local HEAT = { { 0, 0, 0 }, { 120, 0, 10 }, { 230, 50, 0 }, { 255, 170, 0 }, { 255, 245, 140 }, { 255, 255, 255 } }
local OCEAN = { { 2, 6, 30 }, { 0, 40, 110 }, { 0, 120, 170 }, { 40, 200, 190 }, { 210, 250, 230 } }
local CORNERS = {
    { { 255, 60, 120 }, { 255, 200, 40 }, { 40, 60, 200 }, { 0, 220, 170 } },
    { { 250, 120, 30 }, { 120, 20, 160 }, { 255, 230, 120 }, { 20, 120, 200 } },
    { { 20, 230, 120 }, { 30, 40, 120 }, { 250, 250, 120 }, { 230, 40, 90 } },
}

local CMODES = {
    { "rainbow", function(u, v, base) return hsv(base + u * 0.72 + v * 0.12, 0.9 - 0.25 * v, 1 - 0.55 * v) end },
    { "hue 2D", function(u, v, base) return hsv(base + u * 0.5 + v * 0.5, 0.85, 0.95) end },
    { "corners", function(u, v, base)
        local q = CORNERS[floor(base * #CORNERS) % #CORNERS + 1]
        local a, b, c, d = q[1], q[2], q[3], q[4]
        local w1, w2, w3, w4 = (1 - u) * (1 - v), u * (1 - v), (1 - u) * v, u * v
        return rgb(a[1] * w1 + b[1] * w2 + c[1] * w3 + d[1] * w4,
            a[2] * w1 + b[2] * w2 + c[2] * w3 + d[2] * w4,
            a[3] * w1 + b[3] * w2 + c[3] * w3 + d[3] * w4)
    end },
    { "heat", function(u, v) return rgb(ramp(HEAT, u * (1 - 0.3 * v) + 0.15 * v)) end },
    { "ocean", function(u, v) return rgb(ramp(OCEAN, u * 0.85 + v * 0.15)) end },
    { "pastel", function(u, v, base) return hsv(base + u * 0.8, 0.35 + 0.2 * v, 1 - 0.1 * v) end },
    { "mono", function(u, v)
        local k = u * 255
        return rgb(k * (0.75 + 0.25 * v), k * 0.9, k * (1 - 0.25 * v)) -- рядки трохи тонуються
    end },
}
local CMODE_DEFAULT = "ocean"
local cmode, toast = 1, 0
for i, m in ipairs(CMODES) do if m[1] == CMODE_DEFAULT then cmode = i end end

local function new_palette()
    local base, f = rnd(), CMODES[cmode][2]
    for r = 1, ROWS do
        local v = (r - 1) / max(1, ROWS - 1)
        local p = {}
        for x = 0, COLS - 1 do p[x] = f(x / (COLS - 1), v, base) end
        pal[r] = p
    end
end

local function set_cmode(i)
    cmode = (i - 1) % #CMODES + 1
    toast = 1.5
    new_palette()
end

-- Запускає f на всіх рядках; тривалість — від кількості кроків, у межах min_dur..max_dur
local function start_run(f, min_dur, max_dur)
    -- Сухий прогін на копії першого рядка
    local probe = { a = {} }
    for i = 1, COLS do probe.a[i] = rows[1].a[i] end
    local pc = make_ctx(probe, false)
    f(pc)
    total = max(1, pc.steps)
    rate = total / clamp(total / 110, min_dur, max_dur)
    steps, acc = 0, 0
    for _, row in ipairs(rows) do
        local c = make_ctx(row, true)
        row.done, row.h1, row.h2 = false, 0, 0
        row.co = cwrap(function() f(c); row.done = true; row.h1, row.h2 = 0, 0 end)
    end
end

local function enter(phase_name)
    phase, ptime = phase_name, 0
    if phase == "wait" then
        new_palette() -- новий градієнт помітно лише на перемішаних клітинках
    elseif phase == "shuffle" then
        start_run(shuffle, 1.2, 1.2)
    elseif phase == "sort" then
        stats.cmp, stats.wr = 0, 0
        start_run(ALGOS[cur][3], 3, 10)
    end
end

local function pick(i)
    cur = (i - 1) % #ALGOS + 1
    enter("shuffle")
end

function lilka.init()
    W, H = display.width, display.height
    -- Застосунок стартує на весь екран, тож display.height = 240 навіть з fullscreen = false
    if not lilka.fullscreen and H > 216 then H = H - 24 end
    COLS = W // CS
    ROWS = (H - TOP) // CS
    OX = (W - COLS * CS) // 2
    OY = TOP + (H - TOP - ROWS * CS) // 2
    for r = 1, ROWS do
        local a = {}
        for i = 1, COLS do a[i] = i - 1 end
        for i = COLS, 2, -1 do
            local j = 1 + rand_int(i)
            a[i], a[j] = a[j], a[i]
        end
        rows[r] = { a = a, h1 = 0, h2 = 0, done = true }
    end
    enter("wait")
end

local function advance(delta)
    acc = acc + rate * delta
    local k = floor(acc)
    acc = acc - k
    local all_done = true
    for _, row in ipairs(rows) do
        for _ = 1, k do
            if row.done then break end
            row.co()
        end
        if not row.done then all_done = false end
    end
    steps = steps + k
    return all_done
end

function lilka.update(delta)
    if controller then
        local s = controller.get_state()
        if s.start.just_pressed then util.exit() end
        if s.right.just_pressed then pick(cur + 1) end
        if s.left.just_pressed then pick(cur - 1) end
        if s.a.just_pressed then paused = not paused end
        if s.up.just_pressed then set_cmode(cmode - 1) end
        if s.down.just_pressed then set_cmode(cmode + 1) end
    end
    toast = max(0, toast - delta)
    if paused then return end
    delta = min(delta, 0.1)
    ptime = ptime + delta
    if phase == "shuffle" then
        if advance(delta) then enter("wait") end
    elseif phase == "wait" then
        if ptime > 0.7 then enter("sort") end
    elseif phase == "sort" then
        if advance(delta) then enter("done") end
    elseif phase == "done" then
        if ptime > 3 then pick(cur + 1) end
    end
end

local WHITE = 0xFFFF

function lilka.draw()
    display.fill_screen(0)

    -- Сітка
    local sweep = -1
    if phase == "done" then sweep = floor(ptime / 0.9 * (COLS + 4)) end
    for r = 1, ROWS do
        local row, p = rows[r], pal[r]
        local a = row.a
        local y = OY + (r - 1) * CS
        local h1, h2 = row.h1, row.h2
        for i = 1, COLS do
            local col = p[a[i]]
            if i == h1 or i == h2 or i - 1 == sweep then col = WHITE end
            display.fill_rect(OX + (i - 1) * CS, y, CS, CS, col)
        end
    end

    -- Верхня панель
    local algo = ALGOS[cur]
    local gray = rgb(150, 150, 160)
    text(algo[1], 4, 12, WHITE, "6x13")
    text(algo[2], 8 + #algo[1] * 6, 12, gray, "6x13")
    local info
    if phase == "sort" or phase == "done" then
        info = "cmp " .. stats.cmp .. "  wr " .. stats.wr
    elseif phase == "shuffle" then
        info = "shuffling"
    else
        info = "random"
    end
    if paused then info = "paused" end
    if toast > 0 then info = "colors: " .. CMODES[cmode][1] end
    text(info, W - 4 - #info * 5, 11, gray, "5x7")
    local prog = 0
    if phase == "sort" then prog = min(1, steps / total)
    elseif phase == "done" then prog = 1 end
    if prog > 0 then
        display.fill_rect(0, TOP - 2, floor(W * prog), 1, pal[1][COLS - 1])
    end
end
