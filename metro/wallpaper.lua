-- Схема Київського метро з потягами, що їздять за розкладом: частіше в години пік, вночі метро зачинене.
-- Кожні кілька секунд підсвічується випадкова станція.
-- Застосунок: ліво/право — інша станція, START — вихід.

lilka.fullscreen = false

local OPEN, CLOSE = 6 * 60, 23 * 60 -- години роботи метро, хвилини від півночі

local sin, floor = math.sin, math.floor
local function min(a, b) if a < b then return a end return b end
local function max(a, b) if a > b then return a end return b end
local function clamp(x, a, b) return min(b, max(a, x)) end
local function rgb(r, g, b) return display.color565(floor(clamp(r, 0, 255)), floor(clamp(g, 0, 255)), floor(clamp(b, 0, 255))) end

-- Станції: назва, x, y на екрані 280x216
local LINES = {
    {
        id = "M1", color = { 230, 50, 50 },
        { "Академмістечко", 10, 56 }, { "Житомирська", 20, 62 }, { "Святошин", 30, 68 }, { "Нивки", 40, 74 },
        { "Берестейська", 50, 80 }, { "Шулявська", 60, 86 }, { "Політехнічний інститут", 70, 92 },
        { "Вокзальна", 80, 98 }, { "Університет", 90, 98 }, { "Театральна", 100, 98 },
        { "Хрещатик", 128, 98 }, { "Арсенальна", 150, 98 }, { "Дніпро", 162, 98 }, { "Гідропарк", 182, 98 },
        { "Лівобережна", 206, 98 }, { "Дарниця", 218, 92 }, { "Чернігівська", 230, 86 },
        { "Лісова", 242, 80 },
    },
    {
        id = "M2", color = { 40, 120, 230 },
        { "Героїв Дніпра", 138, 6 }, { "Мінська", 138, 16 }, { "Оболонь", 138, 26 }, { "Почайна", 138, 36 },
        { "Тараса Шевченка", 138, 46 }, { "Контрактова площа", 138, 56 }, { "Поштова площа", 138, 66 },
        { "Майдан Незалежності", 138, 88 }, { "Площа Українських Героїв", 138, 120 },
        { "Олімпійська", 138, 130 }, { "Палац \"Україна\"", 138, 140 }, { "Либідська", 138, 150 },
        { "Деміївська", 132, 158 }, { "Голосіївська", 126, 164 }, { "Васильківська", 120, 170 },
        { "Виставковий центр", 114, 176 }, { "Іподром", 108, 182 }, { "Теремки", 102, 188 },
    },
    {
        id = "M3", color = { 40, 170, 80 },
        { "Сирець", 66, 44 }, { "Дорогожичі", 76, 53 }, { "Лук'янівська", 86, 62 },
        { "Золоті ворота", 96, 82 }, { "Палац спорту", 150, 116 }, { "Кловська", 157, 124 },
        { "Печерська", 162, 132 }, { "Звіринецька", 166, 141 }, { "Видубичі", 170, 150 },
        { "Славутич", 200, 158 }, { "Осокорки", 210, 162 }, { "Позняки", 220, 166 },
        { "Харківська", 230, 170 }, { "Вирлиця", 240, 174 }, { "Бориспільська", 250, 178 },
        { "Червоний хутір", 260, 182 },
    },
}
local TRANSFERS = { { 1, 10, 3, 4 }, { 1, 11, 2, 8 }, { 2, 9, 3, 5 } }
-- Береги Дніпра: x лівого і правого берега для кожного y
local RIVER = { { 0, 150, 178 }, { 40, 154, 180 }, { 80, 160, 190 }, { 98, 168, 198 }, { 125, 174, 198 },
    { 150, 178, 194 }, { 175, 184, 206 }, { 216, 192, 216 } }

local W, H
local t = 0
local featured, feat_t = nil, 0
local stations = {}

local function pick(step)
    if step then
        featured = (featured - 1 + step) % #stations + 1
    else
        featured = floor(math.random() * #stations) % #stations + 1
    end
    feat_t = 0
end

function lilka.init()
    W, H = display.width, display.height
    if not lilka.fullscreen and H > 216 then H = H - 24 end
    for li, line in ipairs(LINES) do
        for si, s in ipairs(line) do stations[#stations + 1] = { li, si } end
    end
    pick()
end

-- Скільки потягів на лінії (в один бік) у цю хвилину доби
local function trains_now(m)
    if m < OPEN or m >= CLOSE then return 0 end
    local h = m / 60
    if (h >= 7.5 and h < 10) or (h >= 17 and h < 19.5) then return 7 end
    if h >= 21 then return 3 end
    return 5
end

function lilka.update(delta)
    t = t + delta
    feat_t = feat_t + delta
    if feat_t > 6 then pick() end
    if controller then
        local st = controller.get_state()
        if st.right.just_pressed or st.down.just_pressed then pick(1) end
        if st.left.just_pressed or st.up.just_pressed then pick(-1) end
        if st.start.just_pressed then util.exit() end
    end
end

local function text(x, y, s, c, font)
    display.set_font(font or "6x13")
    display.set_text_size(1)
    display.set_text_color(c)
    display.set_cursor(floor(x), floor(y))
    display.print(s)
end

local function thick(x0, y0, x1, y1, c)
    display.draw_line(x0, y0, x1, y1, c)
    display.draw_line(x0, y0 + 1, x1, y1 + 1, c)
    display.draw_line(x0 + 1, y0, x1 + 1, y1, c)
end

local function river(c)
    for i = 2, #RIVER do
        local a, b = RIVER[i - 1], RIVER[i]
        display.fill_triangle(a[2], a[1], a[3], a[1], b[2], b[1], c)
        display.fill_triangle(a[3], a[1], b[3], b[1], b[2], b[1], c)
    end
end

-- Позиція потяга: їде від станції до станції, стоїть на кожній, на кінцевій розвертається
local function train_pos(line, u)
    local n = #line
    local cycle = 2 * (n - 1)
    u = u % cycle
    if u >= n - 1 then u = cycle - u end
    local i = floor(u)
    local f = u - i
    f = clamp((f - 0.25) / 0.75, 0, 1)
    f = f * f * (3 - 2 * f)
    local a, b = line[i + 1], line[min(n, i + 2)]
    return a[2] + (b[2] - a[2]) * f, a[3] + (b[3] - a[3]) * f
end

function lilka.draw()
    local d = os.date("*t")
    local m = d.hour * 60 + d.min
    local open = trains_now(m) > 0
    local dim = open and 1 or 0.45

    display.fill_screen(rgb(14, 16, 24))
    river(rgb(24, 46, 78))
    display.fill_ellipse(185, 104, 6, 14, rgb(30, 54, 40))

    for _, line in ipairs(LINES) do
        local c = line.color
        local lc = rgb(c[1] * dim, c[2] * dim, c[3] * dim)
        for i = 2, #line do
            thick(line[i - 1][2], line[i - 1][3], line[i][2], line[i][3], lc)
        end
    end
    local link = rgb(200 * dim, 200 * dim, 210 * dim)
    for _, tr in ipairs(TRANSFERS) do
        local a, b = LINES[tr[1]][tr[2]], LINES[tr[3]][tr[4]]
        thick(a[2], a[3], b[2], b[3], link)
    end
    for _, line in ipairs(LINES) do
        local c = line.color
        for i, s in ipairs(line) do
            display.fill_circle(s[2], s[3], 2, rgb(c[1] * dim, c[2] * dim, c[3] * dim))
            display.draw_pixel(s[2], s[3], rgb(14, 16, 24))
        end
    end

    -- Потяги: рух прив'язаний до годинника, тож після перезапуску вони там само
    local secs = m * 60 + d.sec + (t % 1)
    local count = trains_now(m)
    for _, line in ipairs(LINES) do
        local cycle = 2 * (#line - 1)
        for k = 0, count * 2 - 1 do
            local u = secs / 7 + k * cycle / (count * 2)
            local x, y = train_pos(line, u)
            local c = line.color
            display.fill_circle(floor(x), floor(y), 3, rgb(c[1] * 0.5 + 120, c[2] * 0.5 + 120, c[3] * 0.5 + 120))
            display.fill_circle(floor(x), floor(y), 1, rgb(255, 255, 240))
        end
    end

    -- Підсвічена станція
    local li, si = stations[featured][1], stations[featured][2]
    local line = LINES[li]
    local s = line[si]
    local c = line.color
    local r = 4 + (t * 8) % 8
    local k = 1 - (r - 4) / 8
    display.draw_circle(s[2], s[3], floor(r), rgb(255 * k + 14, 255 * k + 16, 255 * k + 24))
    display.fill_circle(s[2], s[3], 3, rgb(255, 255, 255))
    display.fill_circle(s[2], s[3], 1, rgb(c[1], c[2], c[3]))

    local white, grey = rgb(240, 244, 255), rgb(140, 150, 175)
    text(6, 18, "Метро Києва", white, "8x13")
    text(W - 58, 24, string.format("%02d:%02d", d.hour, d.min), white, "10x20")
    local note = open and string.format("до %02d:%02d", CLOSE // 60, CLOSE % 60)
        or string.format("зачинено до %02d:%02d", OPEN // 60, OPEN % 60)
    text(W - 6 - utf8.len(note) * 6, 38, note, open and grey or rgb(255, 150, 110), "6x12")

    local bx, by = 6, H - 19
    display.fill_rect(bx, by, 20, 15, rgb(c[1], c[2], c[3]))
    text(bx + 3, by + 12, line.id, rgb(255, 255, 255), "7x13")
    text(bx + 26, by + 12, s[1], white, "7x13")
end
