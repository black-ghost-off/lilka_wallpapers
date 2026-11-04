-- Particle Life: частинки п'яти кольорів притягують або відштовхують одна одну за випадковою
-- таблицею правил. З простих правил виникають «клітини», ланцюжки й мандрівні «створіння».
-- Кожні 40 секунд — нові правила. Застосунок: B — нові правила, A — пауза, START — вихід.

lilka.fullscreen = false

local COUNT = 180
local TYPES = 5
local RMAX = 40        -- радіус взаємодії, px
local BETA = 0.3       -- частка RMAX, ближче якої частинки завжди відштовхуються
local FORCE = 260
local FRICTION = 0.12  -- частка швидкості, що лишається за секунду (^delta)
local DURATION = 40

local floor, rnd, sqrt = math.floor, math.random, math.sqrt
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

local W, H, GX, GY
local px, py, vx, vy, kind = {}, {}, {}, {}, {}
local rules = {}   -- rules[a * TYPES + b] — як тип a реагує на тип b, -1..1
local cols = {}
local cells = {}   -- сітка RMAX×RMAX для пошуку сусідів
local t, paused = 0, false

local function new_rules()
    for a = 0, TYPES - 1 do
        for b = 0, TYPES - 1 do rules[a * TYPES + b] = rnd() * 2 - 1 end
        rules[a * TYPES + a] = 0.3 + rnd() * 0.7 -- свої притягуються: інакше колір розсипається пилом
    end
    local base = rnd()
    for k = 0, TYPES - 1 do cols[k] = hsv(base + k / TYPES, 0.7, 1) end
    t = 0
end

local function scatter()
    for i = 1, COUNT do
        px[i], py[i] = rnd() * W, rnd() * H
        vx[i], vy[i] = 0, 0
        kind[i] = (i - 1) % TYPES
    end
end

function lilka.init()
    W, H = display.width, display.height
    -- Застосунок стартує на весь екран, тож display.height = 240 навіть з fullscreen = false
    if not lilka.fullscreen and H > 216 then H = H - 24 end
    GX, GY = W // RMAX, H // RMAX -- клітинки трохи більші за RMAX: краї загортаються
    new_rules()
    scatter()
end

local function step(dt)
    local cw, ch = W / GX, H / GY
    for c = 0, GX * GY - 1 do cells[c] = {} end
    local cx, cy = {}, {}
    for i = 1, COUNT do
        local x, y = floor(px[i] / cw) % GX, floor(py[i] / ch) % GY
        cx[i], cy[i] = x, y
        local cell = cells[y * GX + x]
        cell[#cell + 1] = i
    end
    local rmin = RMAX * BETA
    local r2max = RMAX * RMAX
    local hw, hh = W / 2, H / 2
    for i = 1, COUNT do
        local fx, fy = 0, 0
        local xi, yi = px[i], py[i]
        local row = kind[i] * TYPES
        for oy = -1, 1 do
            local yy = (cy[i] + oy) % GY
            for ox = -1, 1 do
                local cell = cells[yy * GX + (cx[i] + ox) % GX]
                for k = 1, #cell do
                    local j = cell[k]
                    if j ~= i then
                        local dx, dy = px[j] - xi, py[j] - yi
                        -- найкоротший шлях через загорнуті краї
                        if dx > hw then dx = dx - W elseif dx < -hw then dx = dx + W end
                        if dy > hh then dy = dy - H elseif dy < -hh then dy = dy + H end
                        local d2 = dx * dx + dy * dy
                        if d2 < r2max and d2 > 0.01 then
                            local d = sqrt(d2)
                            local f
                            if d < rmin then
                                f = d / rmin - 1 -- відштовхування на близькій відстані
                            else
                                local a = rules[row + kind[j]]
                                f = a * (1 - math.abs(2 * d - RMAX - rmin) / (RMAX - rmin))
                            end
                            fx, fy = fx + dx / d * f, fy + dy / d * f
                        end
                    end
                end
            end
        end
        vx[i] = vx[i] + fx * FORCE * dt
        vy[i] = vy[i] + fy * FORCE * dt
    end
    local damp = FRICTION ^ dt
    for i = 1, COUNT do
        vx[i], vy[i] = vx[i] * damp, vy[i] * damp
        px[i] = (px[i] + vx[i] * dt) % W
        py[i] = (py[i] + vy[i] * dt) % H
    end
end

function lilka.update(delta)
    if controller then
        local s = controller.get_state()
        if s.start.just_pressed then util.exit() end
        if s.a.just_pressed then paused = not paused end
        if s.b.just_pressed then new_rules() end
    end
    if paused then return end
    delta = min(delta, 0.06)
    t = t + delta
    if t > DURATION then new_rules() end
    step(delta)
end

function lilka.draw()
    display.fill_screen(0)
    for i = 1, COUNT do
        display.fill_rect(floor(px[i]) - 1, floor(py[i]) - 1, 3, 3, cols[kind[i]])
    end
    -- Таблиця правил у кутку: зелене — притягує, червоне — відштовхує
    local s = 4
    local ox, oy = W - TYPES * s - 4 - s, H - TYPES * s - 4 - s
    for a = 0, TYPES - 1 do
        display.fill_rect(ox, oy + s + a * s, s - 1, s - 1, cols[a])
        display.fill_rect(ox + s + a * s, oy, s - 1, s - 1, cols[a])
        for b = 0, TYPES - 1 do
            local r = rules[a * TYPES + b]
            local c = r > 0 and rgb(40, 60 + 195 * r, 70) or rgb(60 - 195 * r, 40, 50)
            display.fill_rect(ox + s + b * s, oy + s + a * s, s - 1, s - 1, c)
        end
    end
    if paused then text("paused", 4, 12, 0xFFFF, "6x13") end
end
