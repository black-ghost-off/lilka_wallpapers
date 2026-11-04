-- Пінг-понг двох ботів: кожен рахує, куди прилетить м'яч з урахуванням відскоків,
-- але трохи помиляється, тож іноді пропускає. Гра до 7 очок.
-- Застосунок: ↑ ↓ — керувати лівою ракеткою, A — пауза, START — вихід.

lilka.fullscreen = false

local WIN = 7
local PW, PH, BS = 4, 30, 5 -- ракетка й м'яч, px
local BOT_SPEED = 150       -- px/с

local floor, rnd, sin, abs = math.floor, math.random, math.sin, math.abs
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

local W, H, TOPY, BOTY
local ball = { x = 0, y = 0, vx = 0, vy = 0 }
local trail = {}
local pads = {}
local phase, t, paused = "serve", 0, false
local human, human_t = false, 0
local server = 1
local flash = 0
local C = {}

-- Куди по y прилетить м'яч на лінію x, з відскоками від стін
local function predict(x)
    if (x - ball.x) * ball.vx <= 0 then return (TOPY + BOTY) / 2 end
    local time = (x - ball.x) / ball.vx
    local y = ball.y + ball.vy * time
    local lo, hi = TOPY + BS / 2, BOTY - BS / 2
    local span = hi - lo
    local k = (y - lo) % (2 * span)
    if k > span then k = 2 * span - k end
    return lo + k
end

local function new_error(p)
    -- Похибка зростає з швидкістю м'яча: на довгих розіграшах хтось врешті промахнеться
    local sp = abs(ball.vx) / 120
    p.err = (rnd() - 0.5) * (PH * 0.6 + 34 * max(0, sp - 1)) + (rnd() < 0.12 and (rnd() - 0.5) * 70 or 0)
end

local function serve()
    phase, t = "serve", 0
    ball.x, ball.y = W / 2, TOPY + (BOTY - TOPY) * (0.3 + rnd() * 0.4)
    ball.vx = (server == 1 and 1 or -1) * 110
    ball.vy = (rnd() - 0.5) * 140
    trail = {}
    for _, p in ipairs(pads) do new_error(p) end
end

local function reset_game()
    pads[1].score, pads[2].score = 0, 0
    server = rnd() < 0.5 and 1 or 2
    serve()
end

function lilka.init()
    W, H = display.width, display.height
    -- Застосунок стартує на весь екран, тож display.height = 240 навіть з fullscreen = false
    if not lilka.fullscreen and H > 216 then H = H - 24 end
    TOPY, BOTY = 3, H - 3
    pads[1] = { x = 10, y = H / 2, score = 0, col = rgb(60, 220, 255), err = 0 }
    pads[2] = { x = W - 10 - PW, y = H / 2, score = 0, col = rgb(255, 80, 200), err = 0 }
    C.net = rgb(40, 44, 70)
    C.wall = rgb(70, 76, 110)
    C.score = rgb(60, 66, 100)
    C.ball = rgb(255, 255, 255)
    C.trail = {}
    for k = 1, 8 do C.trail[k] = rgb(255 * k / 10, 230 * k / 10, 120 * k / 10) end
    reset_game()
end

local function move_pad(p, target, delta, speed)
    local d = target - p.y
    local step = speed * delta
    p.y = p.y + clamp(d, -step, step)
    p.y = clamp(p.y, TOPY + PH / 2, BOTY - PH / 2)
end

local function hit(p, side)
    local off = (ball.y - p.y) / (PH / 2) -- -1..1: куди влучив м'яч у ракетку
    local sp = min(320, abs(ball.vx) * 1.07 + 4)
    ball.vx = sp * side
    ball.vy = clamp(ball.vy * 0.4 + off * 170, -230, 230)
    flash = 0.12
    for _, q in ipairs(pads) do new_error(q) end
end

function lilka.update(delta)
    local up, down = false, false
    if controller then
        local s = controller.get_state()
        if s.start.just_pressed then util.exit() end
        if s.a.just_pressed then paused = not paused end
        up, down = s.up.pressed, s.down.pressed
        if up or down then human, human_t = true, 0 end
    end
    if paused then return end
    delta = min(delta, 0.05)
    t = t + delta
    flash = max(0, flash - delta)
    if human then
        human_t = human_t + delta
        if human_t > 10 then human = false end -- 10 с без кнопок — знову бот
    end

    -- Ракетки
    for k, p in ipairs(pads) do
        if k == 1 and human then
            local d = (down and 1 or 0) - (up and 1 or 0)
            move_pad(p, p.y + d * 1000, delta, 200)
        else
            local coming = (k == 1 and ball.vx < 0) or (k == 2 and ball.vx > 0)
            local target
            if coming and phase == "play" then
                target = predict(k == 1 and p.x + PW or p.x) + p.err
            else
                target = (TOPY + BOTY) / 2 + sin(t * 0.7 + k) * 20 -- повертаємось у центр
            end
            move_pad(p, target, delta, BOT_SPEED)
        end
    end

    if phase == "serve" then
        if t > 1 then phase, t = "play", 0 end
        return
    elseif phase == "point" then
        if t > 1.2 then
            local a, b = pads[1].score, pads[2].score
            if a >= WIN or b >= WIN then phase, t = "won", 0 else serve() end
        end
        return
    elseif phase == "won" then
        if t > 3.5 then reset_game() end
        return
    end

    -- М'яч
    table.insert(trail, 1, { ball.x, ball.y })
    if #trail > 8 then trail[9] = nil end
    ball.x = ball.x + ball.vx * delta
    ball.y = ball.y + ball.vy * delta
    local r = BS / 2
    if ball.y - r < TOPY then ball.y, ball.vy = TOPY + r, abs(ball.vy) end
    if ball.y + r > BOTY then ball.y, ball.vy = BOTY - r, -abs(ball.vy) end
    local L, R = pads[1], pads[2]
    if ball.vx < 0 and ball.x - r <= L.x + PW and ball.x - r > L.x - 6 and abs(ball.y - L.y) <= PH / 2 + r then
        ball.x = L.x + PW + r
        hit(L, 1)
    elseif ball.vx > 0 and ball.x + r >= R.x and ball.x + r < R.x + PW + 6 and abs(ball.y - R.y) <= PH / 2 + r then
        ball.x = R.x - r
        hit(R, -1)
    end
    if ball.x < -10 then
        R.score = R.score + 1
        server = 1
        phase, t = "point", 0
    elseif ball.x > W + 10 then
        L.score = L.score + 1
        server = 2
        phase, t = "point", 0
    end
end

-- Великі цифри з прямокутників (7-сегментні)
local SEG = { [0] = "abcdef", "bc", "abged", "abgcd", "fgbc", "afgcd", "afgedc", "abc", "abcdefg", "abcdfg" }
local function digit(n, x, y, s, c)
    local l, w = s * 4, s
    local segs = SEG[n]
    local function on(ch) return segs:find(ch, 1, true) end
    if on("a") then display.fill_rect(x, y, l, w, c) end
    if on("g") then display.fill_rect(x, y + l - w // 2 - w // 2, l, w, c) end
    if on("d") then display.fill_rect(x, y + 2 * l - w, l, w, c) end
    if on("f") then display.fill_rect(x, y, w, l, c) end
    if on("b") then display.fill_rect(x + l - w, y, w, l, c) end
    if on("e") then display.fill_rect(x, y + l - w, w, l, c) end
    if on("c") then display.fill_rect(x + l - w, y + l - w, w, l, c) end
end

function lilka.draw()
    display.fill_screen(0)
    -- Рахунок і сітка
    local s = 4
    digit(pads[1].score % 10, W / 2 - 22 - s * 4, 14, s, C.score)
    digit(pads[2].score % 10, W / 2 + 22, 14, s, C.score)
    for y = TOPY + 4, BOTY - 6, 12 do display.fill_rect(W / 2 - 1, y, 2, 6, C.net) end
    display.fill_rect(0, TOPY - 2, W, 2, C.wall)
    display.fill_rect(0, BOTY, W, 2, C.wall)

    -- Ракетки
    for k, p in ipairs(pads) do
        local c = p.col
        if flash > 0 and ((k == 1 and ball.vx > 0) or (k == 2 and ball.vx < 0)) then c = 0xFFFF end
        display.fill_rect(floor(p.x), floor(p.y - PH / 2), PW, PH, c)
    end

    -- М'яч зі слідом
    if phase == "play" or phase == "point" then
        for k = #trail, 1, -1 do
            local q = trail[k]
            local sz = max(1, BS - floor(k / 2))
            display.fill_rect(floor(q[1] - sz / 2), floor(q[2] - sz / 2), sz, sz, C.trail[9 - k])
        end
        display.fill_rect(floor(ball.x - BS / 2), floor(ball.y - BS / 2), BS, BS, C.ball)
    elseif phase == "serve" and floor(t * 6) % 2 == 0 then
        display.fill_rect(floor(ball.x - BS / 2), floor(ball.y - BS / 2), BS, BS, C.ball)
    end

    if human then text("YOU", 20, H - 10, pads[1].col, "6x12") end
    if phase == "won" then
        local p = pads[1].score > pads[2].score and pads[1] or pads[2]
        local msg = (p == pads[1] and (human and "YOU WIN" or "LEFT WINS") or "RIGHT WINS")
        local bw = #msg * 10 + 24
        display.fill_rect((W - bw) // 2, H // 2 - 16, bw, 28, 0)
        display.draw_rect((W - bw) // 2, H // 2 - 16, bw, 28, p.col)
        text(msg, (W - #msg * 10) // 2, H // 2 + 4, p.col, "10x20")
    end
    if paused then text("paused", W / 2 - 18, H - 10, 0xFFFF, "6x12") end
end
