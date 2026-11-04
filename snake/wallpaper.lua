-- Змійка, що грає сама: шукає найкоротший шлях до яблука (BFS) і йде ним, лише якщо
-- після цього ще зможе дістатися власного хвоста. Інакше тягнеться за хвостом.
-- Застосунок: стрілки — перехопити керування, A — пауза, START — вихід.

lilka.fullscreen = false

local CS, TOP = 8, 16 -- розмір клітинки й висота верхньої панелі, px
local SPEED = 12      -- кроків за секунду (бот)
local HUMAN_SPEED = 8

local floor, rnd, sin = math.floor, math.random, math.sin
local function min(a, b) if a < b then return a end return b end
local function max(a, b) if a > b then return a end return b end
local function clamp(x, a, b) return min(b, max(a, x)) end
local function rgb(r, g, b) return display.color565(floor(clamp(r, 0, 255)), floor(clamp(g, 0, 255)), floor(clamp(b, 0, 255))) end
local function rand_int(n) return min(n - 1, floor(rnd() * n)) end -- 0..n-1

local function text(s, x, y, c, font)
    display.set_font(font)
    display.set_text_size(1)
    display.set_text_color(c)
    display.set_cursor(floor(x), floor(y))
    display.print(s)
end

local W, H, GW, GH, N, OX, OY
local body = {}   -- клітинки змійки, body[1] — голова
local occ = {}    -- occ[i] = true, якщо клітинку займає тіло
local food
local dir = 2     -- 1 вгору, 2 праворуч, 3 вниз, 4 ліворуч
local DX, DY = { 0, 1, 0, -1 }, { -1, 0, 1, 0 }
local phase, t, acc, paused = "play", 0, 0, false
local human = false
local score, best, since_food = 0, 0, 0
local grow = 0
local C = {}
local body_pal = {}

local function nb(i, d)
    local x, y = i % GW + DX[d], i // GW + DY[d]
    if x < 0 or y < 0 or x >= GW or y >= GH then return nil end
    return y * GW + x
end

local function place_food()
    local free = {}
    for i = 0, N - 1 do if not occ[i] then free[#free + 1] = i end end
    food = #free > 0 and free[1 + rand_int(#free)] or nil
end

local function reset()
    for i = 0, N - 1 do occ[i] = nil end
    body = {}
    local y, x = GH // 2, 4
    for k = 0, 3 do
        local i = y * GW + x - k
        body[#body + 1] = i
        occ[i] = true
    end
    dir, score, grow, since_food = 2, 0, 0, 0
    phase, t = "play", 0
    place_food()
end

-- BFS з голови; blocked — множина зайнятих клітинок. Повертає батьків і відстані
local function bfs(from, blocked, target)
    local par, dist = { [from] = -1 }, { [from] = 0 }
    local q, qh = { from }, 1
    while q[qh] do
        local c = q[qh]
        qh = qh + 1
        if c == target then break end
        for d = 1, 4 do
            local n = nb(c, d)
            if n and par[n] == nil and (not blocked[n] or n == target) then
                par[n] = c
                dist[n] = dist[c] + 1
                q[#q + 1] = n
            end
        end
    end
    return par, dist
end

local function first_step(par, target)
    local c = target
    while par[c] ~= -1 and par[par[c]] ~= -1 do c = par[c] end
    return c
end

-- Чи досяжний хвіст, якщо змійка пройде шлях path (від голови до цілі)
local function safe_after(path, eat)
    local vb = {}
    for k = 1, #body do vb[k] = body[k] end
    for k = 1, #path do
        table.insert(vb, 1, path[k])
        if not (eat and k == #path) then table.remove(vb) end
    end
    local blocked = {}
    for k = 1, #vb - 1 do blocked[vb[k]] = true end
    local par = bfs(vb[1], blocked, vb[#vb])
    return par[vb[#vb]] ~= nil
end

local function path_to(par, target)
    local p = {}
    local c = target
    while par[c] ~= -1 do
        table.insert(p, 1, c)
        c = par[c]
    end
    return p
end

local function dir_to(from, to)
    for d = 1, 4 do if nb(from, d) == to then return d end end
    return dir
end

local function flood(start, blocked)
    local seen, q, qh = { [start] = true }, { start }, 1
    while q[qh] do
        local c = q[qh]
        qh = qh + 1
        for d = 1, 4 do
            local n = nb(c, d)
            if n and not seen[n] and not blocked[n] then
                seen[n] = true
                q[#q + 1] = n
            end
        end
    end
    return #q
end

local function think()
    local head = body[1]
    local blocked = {}
    for k = 1, #body - (grow > 0 and 0 or 1) do blocked[body[k]] = true end -- хвіст звільниться, якщо не ростемо
    if food then
        local par = bfs(head, blocked, food)
        if par[food] then
            local p = path_to(par, food)
            if safe_after(p, true) then return dir_to(head, p[1]) end
        end
    end
    -- За хвостом: з сусідів, з яких хвіст досяжний, беремо найдальший від яблука
    local best_d, best_s
    for d = 1, 4 do
        local n = nb(head, d)
        if n and not blocked[n] and d ~= (dir + 1) % 4 + 1 then
            local ok = safe_after({ n }, false)
            local s = flood(n, blocked)
            if ok then s = s + N end
            if food then s = s + (math.abs(n % GW - food % GW) + math.abs(n // GW - food // GW)) * 0.01 end
            if not best_s or s > best_s then best_d, best_s = d, s end
        end
    end
    return best_d or dir
end

local function move()
    if not human then dir = think() end
    local n = nb(body[1], dir)
    local tail = body[#body]
    local hits = n == nil or (occ[n] and not (n == tail and grow == 0))
    if hits then
        phase, t = "over", 0
        best = max(best, score)
        return
    end
    table.insert(body, 1, n)
    since_food = since_food + 1
    if n == food then
        score = score + 1
        grow = grow + 2
        since_food = 0
    end
    if grow > 0 then
        grow = grow - 1
    else
        occ[tail] = nil
        table.remove(body)
    end
    occ[n] = true
    if n == food then
        place_food()
        if not food then phase, t = "over", 0; best = max(best, score) end
    end
    if since_food > N * 2 then phase, t = "over", 0 end -- зациклилась
end

function lilka.init()
    W, H = display.width, display.height
    -- Застосунок стартує на весь екран, тож display.height = 240 навіть з fullscreen = false
    if not lilka.fullscreen and H > 216 then H = H - 24 end
    GW, GH = W // CS, (H - TOP) // CS
    N = GW * GH
    OX = (W - GW * CS) // 2
    OY = TOP + (H - TOP - GH * CS) // 2
    C.bg1, C.bg2 = rgb(14, 22, 18), rgb(18, 28, 22)
    C.food, C.leaf = rgb(240, 60, 70), rgb(80, 200, 90)
    C.head = rgb(200, 255, 120)
    C.eye = rgb(10, 20, 10)
    C.gray = rgb(150, 160, 150)
    for k = 0, 31 do
        local u = k / 31
        body_pal[k] = rgb(120 - 80 * u, 230 - 120 * u, 90 + 60 * u)
    end
    reset()
end

function lilka.update(delta)
    if controller then
        local s = controller.get_state()
        if s.start.just_pressed then util.exit() end
        if s.a.just_pressed then paused = not paused end
        local want
        if s.up.just_pressed then want = 1 end
        if s.right.just_pressed then want = 2 end
        if s.down.just_pressed then want = 3 end
        if s.left.just_pressed then want = 4 end
        if want then
            if not human then human = true; reset() end
            if want ~= (dir + 1) % 4 + 1 then dir = want end
        end
    end
    if paused then return end
    delta = min(delta, 0.1)
    t = t + delta
    if phase == "over" then
        if t > 2.5 then
            human = false
            reset()
        end
        return
    end
    acc = acc + (human and HUMAN_SPEED or SPEED) * delta
    local k = min(floor(acc), 3)
    acc = acc - k
    for _ = 1, k do
        if phase == "play" then move() end
    end
end

function lilka.draw()
    display.fill_screen(0)
    -- Шахове поле
    for y = 0, GH - 1 do
        for x = 0, GW - 1 do
            display.fill_rect(OX + x * CS, OY + y * CS, CS, CS, (x + y) % 2 == 0 and C.bg1 or C.bg2)
        end
    end
    -- Яблуко
    if food then
        local fx, fy = OX + (food % GW) * CS + CS // 2, OY + (food // GW) * CS + CS // 2
        local r = 3 + floor(0.5 + 0.6 * sin(t * 6))
        display.fill_circle(fx, fy + 1, r, C.food)
        display.fill_rect(fx, fy - r - 1, 2, 2, C.leaf)
    end
    -- Тіло: від хвоста до голови, колір темнішає до хвоста
    local n = #body
    local over = phase == "over"
    for k = n, 1, -1 do
        local i = body[k]
        local x, y = OX + (i % GW) * CS, OY + (i // GW) * CS
        local c = body_pal[floor((k - 1) / max(1, n - 1) * 31)]
        if over and floor(t * 6) % 2 == 0 then c = C.food end
        if k == 1 then c = over and C.food or C.head end
        display.fill_rect(x + 1, y + 1, CS - 2, CS - 2, c)
        -- Перемички між сегментами, щоб тіло було суцільним
        if k < n then
            local j = body[k + 1]
            local d = j - i
            if d == 1 then display.fill_rect(x + CS - 1, y + 1, 2, CS - 2, c)
            elseif d == -1 then display.fill_rect(x - 1, y + 1, 2, CS - 2, c)
            elseif d == GW then display.fill_rect(x + 1, y + CS - 1, CS - 2, 2, c)
            elseif d == -GW then display.fill_rect(x + 1, y - 1, CS - 2, 2, c) end
        end
    end
    -- Очі
    local h = body[1]
    if h then
        local x, y = OX + (h % GW) * CS + CS // 2, OY + (h // GW) * CS + CS // 2
        local px, py = -DY[dir], DX[dir]
        local fx, fy = DX[dir] * 1, DY[dir] * 1
        display.fill_rect(x + px * 2 + fx - 1, y + py * 2 + fy - 1, 2, 2, C.eye)
        display.fill_rect(x - px * 2 + fx - 1, y - py * 2 + fy - 1, 2, 2, C.eye)
    end

    -- Верхня панель
    local who = human and "You" or "Snake AI"
    text(who, 4, 12, 0xFFFF, "6x13")
    local info = "length " .. #body .. "  score " .. score .. "  best " .. best
    if paused then info = "paused" end
    text(info, W - 4 - #info * 5, 11, C.gray, "5x7")
    if over then
        local msg = (food == nil) and "PERFECT!" or "GAME OVER"
        local bw = #msg * 9 + 20
        display.fill_rect((W - bw) // 2, H // 2 - 14, bw, 24, rgb(0, 0, 0))
        text(msg, (W - #msg * 9) // 2, H // 2 + 4, 0xFFFF, "9x15")
    end
end
