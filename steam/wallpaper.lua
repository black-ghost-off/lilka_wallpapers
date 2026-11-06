-- Steam: ваш статус, хто з друзів зараз у мережі й у що грає, і ваші ігри за останні 2 тижні.
-- Потрібен ключ Steam Web API (https://steamcommunity.com/dev/apikey) і ваш SteamID64
-- (17 цифр, видно, наприклад, на steamid.io). Список друзів має бути відкритим у налаштуваннях приватності.
-- Ключ лежить на SD-картці відкритим текстом: не давайте картку чужим.
-- Застосунок завантажує дані в steam.txt; шпалери на свіжій Keira оновлюють їх самі.
-- Застосунок: A — оновити, START — вихід.

lilka.fullscreen = false

local KEY = ""     -- ключ Steam Web API
local STEAMID = "" -- ваш SteamID64
local CACHE = "steam.txt"
local REFRESH = 5 * 60          -- статуси друзів
local FRIENDS_REFRESH = 60 * 60 -- список друзів і ігри за 2 тижні
local MAX_FRIENDS = 60
local PAGE_TIME = 6
local API = "https://api.steampowered.com/"

local floor, sin = math.floor, math.sin
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
local function cut(s, n)
    if (utf8.len(s) or #s) <= n then return s end
    return s:sub(1, (utf8.offset(s, n) or n) - 1) .. "."
end

local function unescape(s)
    s = s:gsub("\\u(%x%x%x%x)", function(h)
        local n = tonumber(h, 16)
        if n >= 0xD800 and n <= 0xDFFF then return "" end
        return utf8.char(n)
    end)
    return (s:gsub('\\(.)', { n = " ", t = " ", ['"'] = '"', ["\\"] = "\\", ["/"] = "/" }))
end

-- Рядок JSON за ключем, з урахуванням \" усередині
local function jstr(obj, key)
    local _, e = obj:find('"' .. key .. '":%s*"')
    if not e then return nil end
    local i = e + 1
    while i <= #obj do
        local ch = obj:sub(i, i)
        if ch == "\\" then i = i + 2
        elseif ch == '"' then return unescape(obj:sub(e + 1, i - 1))
        else i = i + 1 end
    end
    return nil
end

local W, H
local t = 0
local players = {}  -- { id, name, state, game }
local games = {}    -- { name, minutes }
local friend_ids = {}
local at, fat, status
local next_fetch = 0
local C = {}

local STATE = { [0] = "не в мережі", "в мережі", "зайнятий", "відійшов", "спить", "хоче обмін", "хоче грати" }

local function clean(s) return (tostring(s or ""):gsub("[|\n]", " ")) end

local function save()
    local lines = { "at=" .. (at or 0), "fat=" .. (fat or 0), "friends=" .. table.concat(friend_ids, ",") }
    for _, p in ipairs(players) do
        lines[#lines + 1] = "p|" .. p.id .. "|" .. p.state .. "|" .. clean(p.name) .. "|" .. clean(p.game)
    end
    for _, g in ipairs(games) do lines[#lines + 1] = "g|" .. g.minutes .. "|" .. clean(g.name) end
    pcall(resources.write_file, CACHE, table.concat(lines, "\n"))
end

local function load()
    local ok, s = pcall(resources.read_file, CACHE)
    if not ok or not s then return end
    at, fat = tonumber(s:match("at=(%d+)")), tonumber(s:match("fat=(%d+)"))
    if at == 0 then at = nil end
    friend_ids = {}
    for id in (s:match("friends=([%d,]*)") or ""):gmatch("%d+") do friend_ids[#friend_ids + 1] = id end
    players, games = {}, {}
    for id, st, name, game in s:gmatch("\np|(%d+)|(%d+)|([^|\n]*)|([^|\n]*)") do
        players[#players + 1] = { id = id, state = tonumber(st), name = name, game = game ~= "" and game or nil }
    end
    for m, name in s:gmatch("\ng|(%d+)|([^\n]*)") do games[#games + 1] = { minutes = tonumber(m), name = name } end
end

local function get(path)
    collectgarbage()
    local ok, res = pcall(http.execute, { url = API .. path })
    if not ok then return nil, 0 end
    return res.response, floor(res.code or 0)
end

local function fetch_friends()
    local body, code = get("ISteamUser/GetFriendList/v1/?relationship=friend&key=" .. KEY .. "&steamid=" .. STEAMID)
    if code == 403 then return code end -- невірний ключ
    if code == 200 and body then
        local ids = {}
        for id in body:gmatch('"steamid":%s*"(%d+)"') do
            if #ids < MAX_FRIENDS then ids[#ids + 1] = id end
        end
        friend_ids = ids
    end
    -- 401 тут буває і через закритий список друзів, тоді показуємо лише себе
    body, code = get("IPlayerService/GetRecentlyPlayedGames/v1/?count=3&key=" .. KEY .. "&steamid=" .. STEAMID)
    local gp = code == 200 and body and body:find('"games"')
    if gp then
        local list = {}
        for obj in body:sub(gp):gmatch("%b{}") do
            local m = tonumber(obj:match('"playtime_2weeks":%s*(%d+)'))
            local name = jstr(obj, "name")
            if m and name then list[#list + 1] = { name = name, minutes = m } end
        end
        games = list
    end
    fat = os.time()
    return nil
end

local function fetch_players()
    local ids = { STEAMID }
    for _, id in ipairs(friend_ids) do ids[#ids + 1] = id end
    local body, code = get("ISteamUser/GetPlayerSummaries/v2/?key=" .. KEY .. "&steamids=" .. table.concat(ids, ","))
    if code == 401 or code == 403 then return "Ключ API не підходить" end
    if code ~= 200 or not body then return "Не вдалося завантажити" end
    local p0 = body:find('"players"')
    if not p0 then return "Незрозуміла відповідь" end
    local list = {}
    for obj in body:sub(p0):gmatch("%b{}") do
        local id = obj:match('"steamid":%s*"(%d+)"')
        if id then
            list[#list + 1] = {
                id = id,
                name = jstr(obj, "personaname") or "?",
                state = tonumber(obj:match('"personastate":%s*(%d+)')) or 0,
                game = jstr(obj, "gameextrainfo"),
            }
        end
    end
    body = nil
    players = list
    at = os.time()
    return nil
end

local function fetch()
    if KEY == "" or STEAMID == "" then return end
    if not (http and wifi) or wifi.get_status() ~= 3 then
        status = "Wi-Fi не під'єднано"
        return
    end
    if not fat or os.time() - fat > FRIENDS_REFRESH or #friend_ids == 0 then
        if fetch_friends() then
            status = "Ключ API не підходить"
            return
        end
    end
    status = fetch_players()
    save()
end

local function me()
    for _, p in ipairs(players) do if p.id == STEAMID then return p end end
    return nil
end

-- Друзі в мережі: спершу ті, що грають, далі решта, за ім'ям
local function online()
    local out = {}
    for _, p in ipairs(players) do
        if p.id ~= STEAMID and p.state > 0 then out[#out + 1] = p end
    end
    table.sort(out, function(a, b)
        if (a.game ~= nil) ~= (b.game ~= nil) then return a.game ~= nil end
        if (a.state == 1) ~= (b.state == 1) then return a.state == 1 end
        return a.name:lower() < b.name:lower()
    end)
    return out
end

function lilka.init()
    W, H = display.width, display.height
    -- Застосунок стартує на весь екран, тож display.height = 240 навіть з fullscreen = false
    if not lilka.fullscreen and H > 216 then H = H - 24 end
    C.bg = rgb(23, 26, 33)
    C.top = rgb(27, 40, 56)
    C.row = rgb(30, 36, 46)
    C.text = rgb(220, 222, 223)
    C.gray = rgb(137, 137, 137)
    C.dim = rgb(60, 66, 78)
    C.game = rgb(144, 186, 60)
    C.online = rgb(87, 203, 222)
    C.away = rgb(70, 130, 150)
    C.bar = rgb(102, 192, 244)
    C.red = rgb(230, 90, 80)
    load()
    if controller then fetch(); next_fetch = REFRESH
    elseif not (at and os.time() - at < REFRESH) then next_fetch = 1
    else next_fetch = REFRESH - (os.time() - at) end
end

function lilka.update(delta)
    t = t + delta
    if controller then
        local s = controller.get_state()
        if s.start.just_pressed then util.exit() end
        if s.a.just_pressed then fat = nil; fetch(); next_fetch = REFRESH end
    end
    if http and wifi then
        next_fetch = next_fetch - delta
        if next_fetch <= 0 then
            next_fetch = REFRESH
            fetch()
        end
    end
end

local function state_color(p)
    if p.game then return C.game end
    if p.state == 1 or p.state >= 5 then return C.online end
    if p.state > 0 then return C.away end
    return C.gray
end

local function fmt_hours(m)
    if m < 60 then return m .. " хв" end
    local h = m / 60
    return (h < 10 and string.format("%.1f", h) or string.format("%.0f", h)) .. " год"
end

function lilka.draw()
    display.fill_screen(C.bg)
    display.fill_rect(0, 0, W, 40, C.top)
    if KEY == "" or STEAMID == "" then
        text("Steam", 8, 26, C.text, "10x20")
        text("Вкажіть KEY і STEAMID", 8, 66, C.text, "8x13")
        text("на початку wallpaper.lua", 8, 82, C.text, "8x13")
        text("Ключ: steamcommunity.com/dev/apikey", 8, 104, C.gray, "5x7")
        text("SteamID64: 17 цифр, напр. на steamid.io", 8, 116, C.gray, "5x7")
        return
    end

    -- Ви
    local m = me()
    if m then
        local c = state_color(m)
        display.fill_rect(6, 8, 26, 26, c)
        display.fill_rect(8, 10, 22, 22, C.top)
        if m.name ~= "" then text(m.name:sub(1, (utf8.offset(m.name, 2) or 2) - 1):upper(), 14, 27, c, "9x15") end
        text(cut(m.name, 16), 40, 19, c == C.gray and C.text or c, "9x15")
        text(m.game and ("грає в " .. cut(m.game, 30)) or STATE[m.state] or "", 40, 33, c, "6x12")
    else
        text("Steam", 8, 26, C.text, "10x20")
        text(status or "Відкрийте wallpaper.lua як застосунок", 70, 24, status and C.red or C.gray, "6x12")
    end

    -- Друзі в мережі
    local on = online()
    local games_h = #games > 0 and (14 + #games * 12) or 0
    local list_y, list_bot = 54, H - 10 - games_h
    local rh = 13
    local rows = max(1, (list_bot - list_y) // rh)
    local pages = max(1, (#on + rows - 1) // rows)
    local page = floor(t / PAGE_TIME) % pages
    local total = 0
    for _, p in ipairs(players) do if p.id ~= STEAMID then total = total + 1 end end
    text("Друзі в мережі", 6, 50, C.gray, "6x12")
    local cnt = #on .. "/" .. total
    if pages > 1 then cnt = (page + 1) .. "/" .. pages .. "  " .. cnt end
    text(cnt, W - 6 - #cnt * 6, 50, C.gray, "6x12")
    if #on == 0 and #players > 0 then
        text(total > 0 and "Нікого немає" or "Список друзів закритий або порожній", 6, list_y + 14, C.dim, "6x12")
    end
    for k = 1, rows do
        local p = on[page * rows + k]
        if not p then break end
        local y = list_y + (k - 1) * rh
        if k % 2 == 1 then display.fill_rect(4, y + 1, W - 8, rh, C.row) end
        local c = state_color(p)
        display.fill_circle(10, y + 7, 3, c)
        if p.game and floor(t * 2 + k) % 4 == 0 then display.draw_circle(10, y + 7, 5, c) end
        text(cut(p.name, 16), 18, y + 11, C.text, "6x12")
        local right = p.game and cut(p.game, 22) or (STATE[p.state] or "")
        text(right, W - 8 - utf8.len(right) * 5, y + 10, c, "5x7")
    end

    -- Ігри за 2 тижні
    if #games > 0 then
        local y = H - 8 - #games * 12
        display.fill_rect(4, y - 12, W - 8, 1, C.dim)
        text("За 2 тижні", 6, y - 2, C.gray, "5x7")
        local most = 1
        for _, g in ipairs(games) do most = max(most, g.minutes) end
        for k, g in ipairs(games) do
            local yy = y + (k - 1) * 12 + 2
            local bw = floor((W - 150) * g.minutes / most)
            display.fill_rect(80, yy, max(2, bw), 7, C.bar)
            text(cut(g.name, 12), 6, yy + 7, C.text, "5x7")
            text(fmt_hours(g.minutes), 86 + bw, yy + 7, C.gray, "5x7")
        end
    end

    if status and controller and m then text(status, 6, H - 1, C.red, "5x7")
    elseif at then text("оновлено " .. os.date("%H:%M", at), W - 80, H - 1, C.dim, "5x7") end
end
