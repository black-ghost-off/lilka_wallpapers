-- Домашній улюбленець: кіт живе на головному екрані.
-- Голод і настрій ростуть зі справжнім часом, вночі (23:00–7:00) кіт спить.
-- Застосунок: A — нагодувати, B — погратися, C — погладити, START — вихід.
-- Вночі A і B будять кота ненадовго. Стан зберігається в pet.txt.

lilka.fullscreen = false

local NAME = "Мурчик"
local SAVE = "pet.txt"
local HUNGRY_AFTER = 10 * 3600
local BORED_AFTER = 14 * 3600

local sin, cos, floor = math.sin, math.cos, math.floor
local rnd = math.random
local function min(a, b) if a < b then return a end return b end
local function max(a, b) if a > b then return a end return b end
local function clamp(x, a, b) return min(b, max(a, x)) end
local function lerp(a, b, k) return a + (b - a) * k end
local function rgb(r, g, b) return display.color565(floor(clamp(r, 0, 255)), floor(clamp(g, 0, 255)), floor(clamp(b, 0, 255))) end

local W, H, FLOOR_Y, BOWL_X
local t = 0
local pet = {}
local synced = false
local hunger, joy = 0.3, 0.7
local cat = { x = 120, tx = 120, dir = 1, mode = "sit", timer = 2, blink = 0, food = 0 }
local ball, hearts, zs = nil, {}, {}
local awake, stroke = 0, 0
local stars = {}

local C = {}

local function now()
    local n = os.time()
    synced = n > 1700000000
    return n
end

local function save()
    if not synced then return end
    pcall(resources.write_file, SAVE, string.format("born=%d\nfed=%d\nplayed=%d\n", pet.born, pet.fed, pet.played))
end

local function load()
    local n = now()
    local ok, text = pcall(resources.read_file, SAVE)
    if ok and text then
        for k, v in text:gmatch("(%w+)=(%d+)") do pet[k] = tonumber(v) end
    end
    if not (pet.born and pet.fed and pet.played) then
        pet = { born = n, fed = n - 3 * 3600, played = n - 3 * 3600 }
        save()
    end
end

local function sleeping()
    if not synced then return false end
    local h = os.date("*t").hour
    return h >= 23 or h < 7
end

local function update_needs()
    local n = now()
    if synced then
        hunger = clamp((n - pet.fed) / HUNGRY_AFTER, 0, 1)
        joy = 1 - clamp((n - pet.played) / BORED_AFTER, 0, 1)
    end
end

local function add_heart(x, y)
    hearts[#hearts + 1] = { x = x + (rnd() - 0.5) * 20, y = y, life = 1.6 }
end

function lilka.init()
    W, H = display.width, display.height
    -- Застосунок стартує на весь екран, тож display.height = 240 навіть з fullscreen = false
    if not lilka.fullscreen and H > 216 then H = H - 24 end
    FLOOR_Y = floor(H * 0.6)
    BOWL_X = W - 46
    for i = 1, 14 do stars[i] = { x = rnd(), y = rnd(), ph = rnd() * 6 } end
    C = {
        wall = rgb(236, 214, 178), wall_dark = rgb(214, 190, 150),
        floor = rgb(160, 110, 70), plank = rgb(135, 90, 55),
        rug = rgb(190, 70, 80), rug_in = rgb(220, 110, 110),
        fur = rgb(235, 145, 60), fur_dark = rgb(200, 110, 40), belly = rgb(250, 215, 170),
        pink = rgb(250, 150, 160), eye = rgb(40, 30, 30), white = rgb(255, 255, 255),
        bowl = rgb(70, 120, 200), bowl_hi = rgb(110, 160, 230), kibble = rgb(130, 80, 40),
        text = rgb(70, 50, 40), bar_bg = rgb(200, 175, 140),
        skin = rgb(250, 205, 170), skin_dark = rgb(215, 155, 120), sleeve = rgb(80, 115, 175), cuff = rgb(55, 85, 140),
    }
    load()
    update_needs()
    cat.food = hunger < 0.4 and 1 or 0
end

local function pick_target()
    if hunger > 0.7 then return BOWL_X - 40 end
    return 40 + rnd() * (W - 140)
end

function lilka.update(delta)
    t = t + delta
    if t % 1 < delta then update_needs() end

    if controller then
        local st = controller.get_state()
        if st.a.just_pressed then
            awake = 30
            pet.fed = now()
            save()
            update_needs()
            cat.food = 1
            cat.mode, cat.tx, cat.timer = "to_bowl", BOWL_X - 40, 0
        end
        if st.b.just_pressed then
            awake = 30
            pet.played = now()
            save()
            update_needs()
            ball = { x = 40 + rnd() * (W - 80), y = FLOOR_Y - 40, vx = (rnd() - 0.5) * 160, vy = -60, life = 7 }
            cat.mode = "play"
        end
        if st.c.just_pressed then
            local n = now()
            pet.played = min(n, pet.played + BORED_AFTER // 4)
            save()
            update_needs()
            stroke = 3
            for _ = 1, 3 do add_heart(cat.x + cat.dir * 20, FLOOR_Y + 10) end
            if cat.mode ~= "sleep" then
                if cat.mode ~= "play" then cat.mode, cat.timer = "purr", 3 end
                cat.tx = cat.x
            end
        end
        if st.start.just_pressed then util.exit() end
    end

    awake = awake - delta
    stroke = max(0, stroke - delta)
    if sleeping() and awake <= 0 and not ball then
        cat.mode = "sleep"
        if rnd() < delta * 0.8 then zs[#zs + 1] = { x = cat.x + 20, y = FLOOR_Y + 10, life = 2.5 } end
    elseif cat.mode == "sleep" then
        cat.mode, cat.timer = "sit", 1
    end

    cat.blink = cat.blink - delta
    if cat.blink < -3 - rnd() * 3 then cat.blink = 0.15 end

    if ball then
        ball.life = ball.life - delta
        ball.vy = ball.vy + 260 * delta
        ball.x = ball.x + ball.vx * delta
        ball.y = ball.y + ball.vy * delta
        local ground = FLOOR_Y + 48
        if ball.y > ground then ball.y, ball.vy = ground, -ball.vy * 0.7 end
        if ball.x < 10 or ball.x > W - 10 then ball.vx = -ball.vx end
        cat.tx = ball.x
        if math.abs(cat.x - ball.x) < 24 and ball.y > ground - 6 then
            ball.vx, ball.vy = (ball.x > cat.x and 1 or -1) * (80 + rnd() * 80), -140
            add_heart(cat.x, FLOOR_Y)
        end
        if ball.life <= 0 then ball = nil; cat.mode, cat.timer = "sit", 2 end
    end

    if cat.mode ~= "sleep" and cat.mode ~= "eat" and cat.mode ~= "purr" then
        local speed = cat.mode == "play" and 70 or (joy < 0.3 and 14 or 26)
        local dx = cat.tx - cat.x
        if math.abs(dx) > 2 then
            cat.dir = dx > 0 and 1 or -1
            cat.x = cat.x + cat.dir * min(math.abs(dx), speed * delta)
            cat.walking = true
        else
            cat.walking = false
            if cat.mode == "to_bowl" then
                cat.mode, cat.timer, cat.dir = "eat", 3, 1
            elseif cat.mode ~= "play" then
                cat.timer = cat.timer - delta
                if cat.timer <= 0 then
                    cat.tx = pick_target()
                    cat.timer = 2 + rnd() * 4
                end
            end
        end
    end
    if cat.mode == "purr" then
        cat.walking = false
        cat.timer = cat.timer - delta
        if rnd() < delta * 1.5 then add_heart(cat.x + cat.dir * 20, FLOOR_Y + 5) end
        if cat.timer <= 0 then cat.mode, cat.timer = "sit", 2 end
    end
    if cat.mode == "eat" then
        cat.walking = false
        cat.timer = cat.timer - delta
        cat.food = max(0, cat.food - delta * 0.25)
        if rnd() < delta * 2 then add_heart(cat.x + 20, FLOOR_Y + 5) end
        if cat.timer <= 0 then cat.mode, cat.timer = "sit", 2 end
    end

    for i = #hearts, 1, -1 do
        local h = hearts[i]
        h.life, h.y = h.life - delta, h.y - 20 * delta
        if h.life <= 0 then table.remove(hearts, i) end
    end
    for i = #zs, 1, -1 do
        local z = zs[i]
        z.life, z.y, z.x = z.life - delta, z.y - 12 * delta, z.x + sin(t * 2 + i) * 8 * delta
        if z.life <= 0 then table.remove(zs, i) end
    end
end

local function text(x, y, s, c, font)
    display.set_font(font or "6x12")
    display.set_text_size(1)
    display.set_text_color(c)
    display.set_cursor(floor(x), floor(y))
    display.print(s)
end

local function draw_window()
    local wx, wy, ww, wh = 24, 18, 78, 62
    local h = synced and os.date("*t").hour or 12
    local sky
    if h >= 21 or h < 6 then sky = { 16, 22, 56 }
    elseif h < 8 or h >= 18 then sky = { 240, 150, 100 }
    else sky = { 120, 185, 240 } end
    display.fill_rect(wx - 4, wy - 4, ww + 8, wh + 8, rgb(250, 245, 235))
    display.fill_rect(wx, wy, ww, wh, rgb(sky[1], sky[2], sky[3]))
    if h >= 21 or h < 6 then
        for _, s in ipairs(stars) do
            local b = 170 + 80 * sin(t * 2 + s.ph)
            display.draw_pixel(floor(wx + s.x * ww), floor(wy + s.y * wh * 0.8), rgb(b, b, b))
        end
        display.fill_circle(wx + ww - 18, wy + 16, 7, rgb(245, 240, 210))
    elseif h >= 8 and h < 18 then
        display.fill_circle(wx + ww - 18, wy + 16, 8, rgb(255, 225, 90))
        display.fill_ellipse(wx + 22 + floor(sin(t * 0.2) * 6), wy + 30, 12, 5, rgb(255, 255, 255))
    else
        display.fill_circle(wx + ww - 20, wy + wh - 10, 10, rgb(255, 190, 110))
    end
    display.fill_rect(wx + ww // 2 - 1, wy, 3, wh, rgb(250, 245, 235))
    display.fill_rect(wx, wy + wh // 2 - 1, ww, 3, rgb(250, 245, 235))
    display.fill_rect(wx - 8, wy + wh + 4, ww + 16, 5, rgb(225, 215, 200))
end

local function draw_room()
    display.fill_rect(0, 0, W, FLOOR_Y, C.wall)
    for x = 0, W, 24 do display.fill_rect(x, 0, 2, FLOOR_Y, C.wall_dark) end
    display.fill_rect(0, FLOOR_Y, W, H - FLOOR_Y, C.floor)
    local y = FLOOR_Y
    local gap = 6
    while y < H do
        display.draw_line(0, floor(y), W, floor(y), C.plank)
        y = y + gap
        gap = gap * 1.35
    end
    display.fill_rect(0, FLOOR_Y - 4, W, 4, rgb(120, 85, 60))
    draw_window()
    display.fill_ellipse(W // 2 - 20, FLOOR_Y + 50, 90, 16, C.rug)
    display.fill_ellipse(W // 2 - 20, FLOOR_Y + 50, 76, 11, C.rug_in)

    local by = FLOOR_Y + 46
    display.fill_ellipse(BOWL_X, by + 4, 22, 7, C.bowl)
    display.fill_rect(BOWL_X - 22, by - 4, 44, 8, C.bowl)
    display.fill_ellipse(BOWL_X, by - 4, 22, 5, C.bowl_hi)
    if cat.food > 0.05 then
        local n = floor(cat.food * 9)
        for i = 0, n - 1 do
            display.fill_circle(BOWL_X - 14 + (i % 5) * 7, by - 5 - floor(i / 5) * 2, 2, C.kibble)
        end
    end
end

local function heart(x, y, c)
    display.fill_circle(x - 2, y, 2, c)
    display.fill_circle(x + 2, y, 2, c)
    display.fill_triangle(x - 4, y + 1, x + 4, y + 1, x, y + 6, c)
end

-- Рука, що гладить кота по спині; back_y — верх спини.
local function draw_hand(x, back_y, d)
    if stroke <= 0 then return end
    local k = clamp(min(3 - stroke, stroke) / 0.35, 0, 1)
    local cx = floor(x + sin(t * 6) * 10)
    local cy = floor(back_y - 3 + math.abs(sin(t * 6)) * 2 - (1 - k) * 70)
    local wx = cx - d * 6
    display.fill_rect(wx - 5, 0, 11, cy, C.skin)
    display.fill_rect(wx - 7, 0, 15, cy - 14, C.sleeve)
    display.fill_rect(wx - 8, cy - 18, 17, 5, C.cuff)
    display.fill_ellipse(cx, cy, 10, 5, C.skin)
    for i = 0, 2 do
        display.fill_ellipse(cx + d * 11, cy - 3 + i * 3, 6, 2, C.skin)
    end
    for i = 0, 1 do
        display.draw_line(cx + d * 7, cy - 1 + i * 3, cx + d * 16, cy - 1 + i * 3, C.skin_dark)
    end
    display.fill_ellipse(cx + d * 3, cy + 4, 4, 2, C.skin)
    display.draw_line(cx - d * 4, cy + 5, cx + d * 6, cy + 5, C.skin_dark)
end

local function draw_cat()
    local x, base = floor(cat.x), FLOOR_Y + 44
    local d = cat.dir
    local breathe = sin(t * 2.2) * 1.2
    local sad = hunger > 0.7 or joy < 0.3

    if cat.mode == "sleep" then
        local by = base - 6
        for i = 0, 5 do
            local a = 3.6 + i * 0.35
            display.fill_circle(floor(x + cos(a) * 26), floor(by + sin(a) * 8 + 6), 4, C.fur_dark)
        end
        display.fill_ellipse(x, by, 26, floor(12 + breathe), C.fur)
        display.fill_ellipse(x - 6, by - 4, 6, 3, C.fur_dark)
        display.fill_ellipse(x + 6, by - 6, 5, 3, C.fur_dark)
        local hx, hy = x + 20, by + 1
        display.fill_circle(hx, hy, 11, C.fur)
        display.fill_triangle(hx - 9, hy - 5, hx - 3, hy - 9, hx - 8, hy - 15, C.fur)
        display.fill_triangle(hx + 9, hy - 5, hx + 3, hy - 9, hx + 8, hy - 15, C.fur)
        display.draw_line(hx - 6, hy, hx - 2, hy + 1, C.eye)
        display.draw_line(hx + 2, hy + 1, hx + 6, hy, C.eye)
        display.fill_triangle(hx - 1, hy + 4, hx + 1, hy + 4, hx, hy + 5, C.pink)
        draw_hand(x - 2, by - 12, 1)
        return
    end

    local eating = cat.mode == "eat"
    local step = cat.walking and sin(t * 10) * 3 or 0
    local by = floor(base - 16 + breathe * 0.5)

    -- Хвіст
    local px, py = x - d * 20, by
    for i = 1, 7 do
        local sway = sin(t * (sad and 1.2 or 2.5) + i * 0.6) * (sad and 2 or 4)
        local nx = px - d * 3 + sway * 0.4
        local ny = py - (sad and -1 or 4)
        display.fill_circle(floor(nx), floor(ny), 3, i % 2 == 0 and C.fur_dark or C.fur)
        px, py = nx, ny
    end

    -- Лапи
    for i, ox in ipairs({ -14, -6, 8, 15 }) do
        local o = (i % 2 == 0) and step or -step
        display.fill_ellipse(x + d * ox + floor(o), base - 3, 4, 5, i <= 2 and C.fur_dark or C.fur)
    end
    display.fill_ellipse(x, by, 23, floor(13 + breathe), C.fur)
    display.fill_ellipse(x + d * 4, by + 5, 14, 6, C.belly)
    for i = -1, 1 do
        display.fill_ellipse(x - d * 4 + i * 9, by - 9, 2, 4, C.fur_dark)
    end

    local hx = x + d * 20
    local hy = eating and by + 6 or by - 14
    display.fill_triangle(hx - 11, hy - 4, hx - 3, hy - 9, hx - 10, hy - 19, C.fur)
    display.fill_triangle(hx + 11, hy - 4, hx + 3, hy - 9, hx + 10, hy - 19, C.fur)
    display.fill_triangle(hx - 9, hy - 6, hx - 5, hy - 9, hx - 9, hy - 15, C.pink)
    display.fill_triangle(hx + 9, hy - 6, hx + 5, hy - 9, hx + 9, hy - 15, C.pink)
    display.fill_circle(hx, hy, 13, C.fur)
    display.fill_ellipse(hx + d * 2, hy + 5, 8, 5, C.belly)

    local ex = 5
    if cat.blink > 0 or eating or cat.mode == "purr" then
        display.draw_line(hx - ex - 2, hy - 2, hx - ex + 2, hy - 2, C.eye)
        display.draw_line(hx + ex - 2, hy - 2, hx + ex + 2, hy - 2, C.eye)
    elseif sad then
        display.fill_ellipse(hx - ex + d, hy - 1, 2, 3, C.eye)
        display.fill_ellipse(hx + ex + d, hy - 1, 2, 3, C.eye)
        display.draw_line(hx - ex - 3, hy - 7, hx - ex + 2, hy - 5, C.eye)
        display.draw_line(hx + ex + 3, hy - 7, hx + ex - 2, hy - 5, C.eye)
    else
        display.fill_ellipse(hx - ex + d, hy - 2, 2, 3, C.eye)
        display.fill_ellipse(hx + ex + d, hy - 2, 2, 3, C.eye)
        display.draw_pixel(hx - ex + d, hy - 4, C.white)
        display.draw_pixel(hx + ex + d, hy - 4, C.white)
        display.fill_circle(hx - 9, hy + 3, 2, C.pink)
        display.fill_circle(hx + 9, hy + 3, 2, C.pink)
    end
    display.fill_triangle(hx - 2 + d, hy + 2, hx + 2 + d, hy + 2, hx + d, hy + 4, C.pink)
    if sad then
        display.draw_line(hx - 3 + d, hy + 8, hx + d, hy + 6, C.eye)
        display.draw_line(hx + d, hy + 6, hx + 3 + d, hy + 8, C.eye)
    else
        display.draw_line(hx - 3 + d, hy + 6, hx + d, hy + 7, C.eye)
        display.draw_line(hx + d, hy + 7, hx + 3 + d, hy + 6, C.eye)
    end
    for s = -1, 1, 2 do
        display.draw_line(hx + s * 6, hy + 4, hx + s * 16, hy + 2, C.white)
        display.draw_line(hx + s * 6, hy + 5, hx + s * 16, hy + 6, C.white)
    end

    draw_hand(x - d * 7, by - 13, d)

    if hunger > 0.7 and cat.mode ~= "eat" then
        local bx, bby = hx + d * 22, hy - 30
        display.fill_circle(hx + d * 10, hy - 16, 2, C.white)
        display.fill_circle(hx + d * 15, hy - 21, 3, C.white)
        display.fill_ellipse(bx, bby, 16, 10, C.white)
        display.fill_ellipse(bx - 2, bby, 7, 4, C.bowl)
        display.fill_triangle(bx + 4, bby, bx + 10, bby - 4, bx + 10, bby + 4, C.bowl)
    end
end

local function bar(x, y, label, v, c)
    text(x, y + 8, label, C.text, "5x8")
    display.fill_rect(x + 46, y + 1, 60, 7, C.bar_bg)
    display.fill_rect(x + 46, y + 1, floor(60 * v), 7, c)
end

function lilka.draw()
    draw_room()
    if ball then
        display.fill_circle(floor(ball.x), floor(ball.y), 6, rgb(80, 180, 110))
        display.draw_line(floor(ball.x) - 5, floor(ball.y), floor(ball.x) + 5, floor(ball.y), rgb(250, 250, 250))
    end
    draw_cat()
    for _, h in ipairs(hearts) do heart(floor(h.x), floor(h.y), rgb(240, 80, 110)) end
    for _, z in ipairs(zs) do
        local k = clamp(z.life / 2.5, 0, 1)
        text(z.x, z.y, "z", rgb(lerp(236, 70, k), lerp(214, 70, k), lerp(178, 140, k)), k > 0.5 and "9x15" or "6x12")
    end

    local px = W - 120
    text(px, 16, NAME, C.text, "7x13")
    if synced then
        local age = (os.time() - pet.born) // 86400
        local s = string.format("%d дн.", age)
        text(W - 10 - utf8.len(s) * 6, 16, s, C.text, "6x12")
        bar(px, 22, "Ситість", 1 - hunger, rgb(240, 160, 60))
        bar(px, 33, "Радість", joy, rgb(230, 90, 120))
        if not controller then
            text(px, 54, "Запусти з SD-картки,", C.text, "5x8")
            text(px, 63, "щоб годувати й грати", C.text, "5x8")
        end
    else
        text(px, 30, "чекаю годинник", C.text, "5x8")
    end
end
