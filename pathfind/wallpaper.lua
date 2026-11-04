-- Пошук шляху: генератор будує лабіринт, потім BFS, DFS, Дейкстра, A* і жадібний пошук
-- по черзі шукають шлях з лівого верхнього кута в правий нижній. Коричневе — болото (крок коштує 5).
-- Наприкінці — таблиця: скільки клітинок переглянуто і яка ціна знайденого шляху.
-- Застосунок: ← → — алгоритм, B — новий лабіринт, A — пауза, START — вихід.

lilka.fullscreen = false

local CS, TOP = 4, 16 -- розмір клітинки й висота верхньої панелі, px
local MUD_COST = 5

local floor, rnd, abs = math.floor, math.random, math.abs
local yield, cwrap = coroutine.yield, coroutine.wrap
local function min(a, b) if a < b then return a end return b end
local function max(a, b) if a > b then return a end return b end
local function clamp(x, a, b) return min(b, max(a, x)) end
local function rgb(r, g, b) return display.color565(floor(clamp(r, 0, 255)), floor(clamp(g, 0, 255)), floor(clamp(b, 0, 255))) end
local function rand_int(n) return min(n - 1, floor(rnd() * n)) end -- 0..n-1
local function shuffle(t)
    for i = #t, 2, -1 do
        local j = 1 + rand_int(i)
        t[i], t[j] = t[j], t[i]
    end
end

local function text(s, x, y, c, font)
    display.set_font(font)
    display.set_text_size(1)
    display.set_text_color(c)
    display.set_cursor(floor(x), floor(y))
    display.print(s)
end

local W, H, GW, GH, OX, OY, N
local grid = {} -- 0 стіна, 1 підлога, 2 болото
local st, ord, par = {}, {}, {} -- стан пошуку: 1 у черзі, 2 переглянуто; порядок перегляду; батько
local START, GOAL
local head = -1 -- клітинка, з якою зараз працює алгоритм

local function idx(x, y) return y * GW + x end

-- Генератори лабіринту. Кімнати — клітинки з непарними координатами, між ними стіни.

local function carve(i)
    grid[i] = 1
    head = i
    yield()
end

local function backtracker()
    local stack = { idx(1, 1) }
    carve(stack[1])
    local dirs = { { 2, 0 }, { -2, 0 }, { 0, 2 }, { 0, -2 } }
    while #stack > 0 do
        local c = stack[#stack]
        local x, y = c % GW, c // GW
        local opts = {}
        for _, d in ipairs(dirs) do
            local nx, ny = x + d[1], y + d[2]
            if nx > 0 and ny > 0 and nx < GW - 1 and ny < GH - 1 and grid[idx(nx, ny)] == 0 then
                opts[#opts + 1] = d
            end
        end
        if #opts == 0 then
            stack[#stack] = nil
            if #stack > 0 then head = stack[#stack] end
        else
            local d = opts[1 + rand_int(#opts)]
            grid[idx(x + d[1] // 2, y + d[2] // 2)] = 1
            local n = idx(x + d[1], y + d[2])
            stack[#stack + 1] = n
            carve(n)
        end
    end
end

local function prim()
    local walls = {}
    local function add_walls(x, y)
        if x > 1 then walls[#walls + 1] = { x - 1, y, x - 2, y } end
        if x < GW - 2 then walls[#walls + 1] = { x + 1, y, x + 2, y } end
        if y > 1 then walls[#walls + 1] = { x, y - 1, x, y - 2 } end
        if y < GH - 2 then walls[#walls + 1] = { x, y + 1, x, y + 2 } end
    end
    local sx, sy = 1 + 2 * rand_int((GW - 1) // 2), 1 + 2 * rand_int((GH - 1) // 2)
    carve(idx(sx, sy))
    add_walls(sx, sy)
    while #walls > 0 do
        local k = 1 + rand_int(#walls)
        local w = walls[k]
        walls[k] = walls[#walls]
        walls[#walls] = nil
        local t = idx(w[3], w[4])
        if grid[t] == 0 then
            grid[idx(w[1], w[2])] = 1
            carve(t)
            add_walls(w[3], w[4])
        end
    end
end

local function kruskal()
    local up, edges = {}, {}
    local function find(a)
        while up[a] ~= a do
            up[a] = up[up[a]]
            a = up[a]
        end
        return a
    end
    for y = 1, GH - 2, 2 do
        for x = 1, GW - 2, 2 do
            local i = idx(x, y)
            up[i] = i
            if x < GW - 2 then edges[#edges + 1] = { i, idx(x + 1, y), idx(x + 2, y) } end
            if y < GH - 2 then edges[#edges + 1] = { i, idx(x, y + 1), idx(x, y + 2) } end
        end
    end
    shuffle(edges)
    for _, e in ipairs(edges) do
        local a, b = find(e[1]), find(e[3])
        if a ~= b then
            up[a] = b
            grid[e[1]] = 1
            grid[e[2]] = 1
            grid[e[3]] = 1
            head = e[2]
            yield()
        end
    end
end

local GENS = { { "Backtracker", backtracker }, { "Prim", prim }, { "Kruskal", kruskal } }

-- Петлі й болота: без них усі алгоритми знаходили б той самий єдиний шлях
local function decorate()
    for y = 1, GH - 2 do
        for x = 1, GW - 2 do
            local i = idx(x, y)
            if grid[i] == 0 and (x + y) % 2 == 1 and rnd() < 0.09 then
                local h = grid[i - 1] ~= 0 and grid[i + 1] ~= 0
                local v = grid[i - GW] ~= 0 and grid[i + GW] ~= 0
                if h ~= v then grid[i] = 1 end
            end
        end
    end
    for _ = 1, 6 do
        local cx, cy, r = rand_int(GW), rand_int(GH), 3 + rand_int(5)
        for y = max(1, cy - r), min(GH - 2, cy + r) do
            for x = max(1, cx - r), min(GW - 2, cx + r) do
                local dx, dy = x - cx, y - cy
                local i = idx(x, y)
                if grid[i] == 1 and dx * dx + dy * dy <= r * r + rnd() * r then grid[i] = 2 end
            end
        end
    end
    grid[START], grid[GOAL] = 1, 1
end

-- Пошук. Двійкова купа для Дейкстри, A* та жадібного пошуку

local function heap_push(h, item, key)
    local n = #h + 1
    h[n] = { key, item }
    while n > 1 do
        local p = n // 2
        if h[p][1] <= h[n][1] then break end
        h[p], h[n] = h[n], h[p]
        n = p
    end
end

local function heap_pop(h)
    local top = h[1]
    local n = #h
    h[1] = h[n]
    h[n] = nil
    n = n - 1
    local i = 1
    while true do
        local l, r, s = 2 * i, 2 * i + 1, i
        if l <= n and h[l][1] < h[s][1] then s = l end
        if r <= n and h[r][1] < h[s][1] then s = r end
        if s == i then break end
        h[s], h[i] = h[i], h[s]
        i = s
    end
    return top[2]
end

local function cost(i) return grid[i] == 2 and MUD_COST or 1 end
local function dist(i)
    return abs(i % GW - GOAL % GW) + abs(i // GW - GOAL // GW)
end

-- kind: "fifo", "lifo" або функція пріоритету f(g, h). live = false — сухий прогін для підрахунку кроків
local function search(kind, live)
    local s, o, p, g = {}, {}, {}, {}
    if live then s, o, p = st, ord, par end
    local count = 0
    local nb = { 1, -1, GW, -GW }
    local list, qh, qt = { START }, 1, 1
    local heap = {}
    g[START] = 0
    s[START] = 1
    if type(kind) == "function" then heap_push(heap, START, 0) end
    while true do
        local c
        if kind == "fifo" then
            c = list[qh]
            list[qh] = nil
            if c then qh = qh + 1 end
        elseif kind == "lifo" then
            c = list[qt]
            list[qt] = nil
            if c then qt = qt - 1 end
        else
            c = #heap > 0 and heap_pop(heap) or nil
        end
        if not c then return count end
        if s[c] ~= 2 then
            s[c] = 2
            count = count + 1
            o[c] = count
            if live then
                head = c
                yield()
            end
            if c == GOAL then return count end
            for _, d in ipairs(nb) do
                local n = c + d
                if grid[n] ~= 0 and s[n] ~= 2 then
                    local ng = g[c] + cost(n)
                    if kind == "fifo" or kind == "lifo" then
                        if not s[n] then
                            s[n], p[n], g[n] = 1, c, ng
                            qt = qt + 1
                            list[qt] = n
                        elseif kind == "lifo" then
                            p[n], g[n] = c, ng -- DFS: останнє відкриття виграє
                            qt = qt + 1
                            list[qt] = n
                        end
                    elseif not g[n] or ng < g[n] then
                        s[n], p[n], g[n] = 1, c, ng
                        heap_push(heap, n, kind(ng, dist(n)))
                    end
                end
            end
        end
    end
end

local ALGOS = {
    { "BFS", "fifo" },
    { "DFS", "lifo" },
    { "Dijkstra", function(g) return g end },
    { "A*", function(g, h) return g + h * 1.001 end },
    { "Greedy", function(_, h) return h end },
}

local gen, algo = 0, 1
local phase, ptime, paused = "gen", 0, false
local co, done, rate, acc, total = nil, true, 0, 0, 1
local path, results = {}, {}
local pcost = 0

local PAL_N = 24
local C = {}
local pal_v, pal_m = {}, {}

local function run(f, steps, dur)
    total = max(1, steps)
    rate = total / dur
    acc = 0
    done = false
    co = cwrap(function() f(); done = true; head = -1 end)
end

local function clear_search()
    st, ord, par = {}, {}, {}
    path, pcost = {}, 0
    head = -1
end

local function start_algo(i)
    algo = (i - 1) % #ALGOS + 1
    clear_search()
    local kind = ALGOS[algo][2]
    local steps = search(kind, false)
    phase, ptime = "search", 0
    run(function() search(kind, true) end, steps, clamp(steps / 260, 2.5, 6))
end

local function new_maze()
    gen = gen % #GENS + 1
    for i = 0, N - 1 do grid[i] = 0 end
    clear_search()
    results = {}
    phase, ptime = "gen", 0
    local rooms = ((GW - 1) // 2) * ((GH - 1) // 2)
    run(GENS[gen][2], rooms, 4)
end

local function trace()
    path = {}
    local c = GOAL
    while c do
        path[#path + 1] = c
        if c ~= START then pcost = pcost + cost(c) end
        c = par[c]
    end
end

function lilka.init()
    W, H = display.width, display.height
    -- Застосунок стартує на весь екран, тож display.height = 240 навіть з fullscreen = false
    if not lilka.fullscreen and H > 216 then H = H - 24 end
    GW, GH = W // CS, (H - TOP) // CS
    if GW % 2 == 0 then GW = GW - 1 end
    if GH % 2 == 0 then GH = GH - 1 end
    N = GW * GH
    OX = (W - GW * CS) // 2
    OY = TOP + (H - TOP - GH * CS) // 2
    START, GOAL = idx(1, 1), idx(GW - 2, GH - 2)

    C.wall = rgb(36, 44, 78)
    C.floor = rgb(2, 3, 8)
    C.mud = rgb(70, 46, 22)
    C.front = rgb(255, 255, 255)
    C.path = rgb(255, 214, 60)
    C.start = rgb(60, 230, 120)
    C.goal = rgb(255, 70, 90)
    C.head = rgb(255, 255, 255)
    C.gray = rgb(150, 150, 165)
    for k = 0, PAL_N - 1 do
        local u = k / (PAL_N - 1)
        local r, g, b = 20 + 40 * u, 70 + 120 * u, 150 + 80 * u -- синій → бірюзовий
        if u > 0.5 then r, g, b = 40 + 180 * (u - 0.5), 190 - 20 * (u - 0.5), 230 - 80 * (u - 0.5) end
        pal_v[k] = rgb(r, g, b)
        pal_m[k] = rgb(r * 0.45 + 70, g * 0.4 + 30, b * 0.25 + 10)
    end
    new_maze()
end

local function advance(delta)
    acc = acc + rate * delta
    local k = floor(acc)
    acc = acc - k
    for _ = 1, k do
        if done then break end
        co()
    end
    return done
end

function lilka.update(delta)
    if controller then
        local s = controller.get_state()
        if s.start.just_pressed then util.exit() end
        if s.a.just_pressed then paused = not paused end
        if s.b.just_pressed then new_maze() end
        if phase ~= "gen" and phase ~= "mud" then
            if s.right.just_pressed then start_algo(algo + 1) end
            if s.left.just_pressed then start_algo(algo - 1) end
        end
    end
    if paused then return end
    delta = min(delta, 0.1)
    ptime = ptime + delta
    if phase == "gen" then
        if advance(delta) then
            decorate()
            phase, ptime = "mud", 0
        end
    elseif phase == "mud" then
        if ptime > 1 then start_algo(1) end
    elseif phase == "search" then
        if advance(delta) then
            trace()
            results[algo] = { ord[GOAL] or 0, pcost }
            phase, ptime = "path", 0
        end
    elseif phase == "path" then
        if ptime > 2.6 then
            if algo == #ALGOS then
                phase, ptime = "table", 0
            else
                start_algo(algo + 1)
            end
        end
    elseif phase == "table" then
        if ptime > 6 then new_maze() end
    end
end

function lilka.draw()
    display.fill_screen(0)
    local front, wall, fl, mud = C.front, C.wall, C.floor, C.mud
    local tot = ord[GOAL] or total
    local scale = (PAL_N - 1) / max(1, tot)
    for y = 0, GH - 1 do
        local py = OY + y * CS
        local row = y * GW
        for x = 0, GW - 1 do
            local i = row + x
            local g = grid[i]
            local c
            if g == 0 then
                c = wall
            else
                local s = st[i]
                if s == 2 then
                    local k = min(PAL_N - 1, floor(ord[i] * scale))
                    c = g == 2 and pal_m[k] or pal_v[k]
                elseif s == 1 then
                    c = front
                else
                    c = g == 2 and mud or fl
                end
            end
            display.fill_rect(OX + x * CS, py, CS, CS, c)
        end
    end

    -- Шлях проявляється від старту до фінішу
    if phase == "path" or phase == "table" then
        local n = #path
        local shown = phase == "table" and n or min(n, floor(ptime / 0.9 * n))
        for k = n, n - shown + 1, -1 do
            local i = path[k]
            display.fill_rect(OX + (i % GW) * CS, OY + (i // GW) * CS, CS, CS, C.path)
        end
    end
    if head >= 0 then
        display.fill_rect(OX + (head % GW) * CS - 1, OY + (head // GW) * CS - 1, CS + 2, CS + 2, C.head)
    end
    if phase ~= "gen" then
        display.fill_rect(OX + (START % GW) * CS, OY + (START // GW) * CS, CS, CS, C.start)
        display.fill_rect(OX + (GOAL % GW) * CS, OY + (GOAL // GW) * CS, CS, CS, C.goal)
    end

    -- Верхня панель
    local white, gray = 0xFFFF, C.gray
    local title, info
    if phase == "gen" or phase == "mud" then
        title, info = "Maze: " .. GENS[gen][1], phase == "mud" and "loops + mud" or "generating"
    elseif phase == "table" then
        title, info = "Results", GENS[gen][1]
    else
        title = ALGOS[algo][1]
        local seen = 0
        for _ in pairs(ord) do seen = seen + 1 end
        info = "visited " .. seen
        if phase == "path" then info = info .. "  cost " .. pcost end
    end
    if paused then info = "paused" end
    text(title, 4, 12, white, "6x13")
    text(info, W - 4 - #info * 5, 11, gray, "5x7")

    -- Підсумкова таблиця
    if phase == "table" then
        local bw, bh = 180, 38 + #ALGOS * 16
        local bx, by = (W - bw) // 2, OY + (GH * CS - bh) // 2
        display.fill_rect(bx, by, bw, bh, rgb(8, 10, 22))
        display.draw_rect(bx, by, bw, bh, gray)
        text("algorithm", bx + 10, by + 16, gray, "5x7")
        text("visited", bx + 86, by + 16, gray, "5x7")
        text("cost", bx + 142, by + 16, gray, "5x7")
        local best = 1e9
        for _, r in pairs(results) do best = min(best, r[2]) end
        for k, a in ipairs(ALGOS) do
            local r = results[k]
            local y = by + 32 + (k - 1) * 16
            text(a[1], bx + 10, y, white, "6x12")
            if r then
                text(tostring(r[1]), bx + 86, y, gray, "6x12")
                text(tostring(r[2]), bx + 142, y, r[2] == best and C.path or white, "6x12")
            end
        end
        text("BFS, DFS, Greedy ignore mud cost", bx + 10, by + bh - 6, gray, "5x7")
    end
end
