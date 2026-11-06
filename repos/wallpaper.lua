-- Ваші репозиторії на GitHub: зірки (і скільки додалось за сьогодні), форки, issues, мова,
-- коли був останній push і чи пройшла остання збірка GitHub Actions на основній гілці.
-- Дані: api.github.com без ключа (60 запитів на годину, тут 2 на репозиторій за оновлення).
-- Застосунок завантажує дані в repos.txt; шпалери на свіжій Keira оновлюють їх самі.
-- Застосунок: ← → — сторінка (якщо репозиторіїв більше 4), A — оновити, START — вихід.

lilka.fullscreen = false

local REPOS = { "lilka-dev/lilka", "lilka-dev/keira", "lilka-dev/sdk", "lilka-dev/lilka-web-ide" }
local CACHE = "repos.txt"
local REFRESH = 30 * 60
local PER_PAGE = 4
local PAGE_TIME = 12
local API = "https://api.github.com/repos/"

local LANG = { -- кольори мов як на GitHub
    ["C++"] = { 243, 75, 125 }, C = { 160, 160, 160 }, Lua = { 80, 110, 230 }, Python = { 53, 114, 165 },
    JavaScript = { 241, 224, 90 }, TypeScript = { 49, 120, 198 }, Makefile = { 66, 120, 25 },
    Rust = { 222, 165, 132 }, Go = { 0, 173, 216 }, Java = { 176, 114, 25 }, Shell = { 137, 224, 81 },
    HTML = { 227, 76, 38 }, CSS = { 86, 61, 124 }, Kotlin = { 169, 123, 255 }, Swift = { 240, 81, 56 },
}

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

local function days_from_civil(y, m, d)
    if m <= 2 then y = y - 1 end
    local era = (y >= 0 and y or y - 399) // 400
    local yoe = y - era * 400
    local mp = (m + 9) % 12
    local doy = (153 * mp + 2) // 5 + d - 1
    local doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
    return era * 146097 + doe - 719468
end
local function utc(s)
    local y, mo, d, h, mi, se = (s or ""):match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
    if not y then return 0 end
    return days_from_civil(tonumber(y), tonumber(mo), tonumber(d)) * 86400 + tonumber(h) * 3600 + tonumber(mi) * 60 + tonumber(se)
end

local function ago(sec)
    if sec < 120 then return "щойно" end
    if sec < 3600 then return (sec // 60) .. " хв тому" end
    if sec < 86400 then return (sec // 3600) .. " год тому" end
    if sec < 60 * 86400 then return (sec // 86400) .. " дн тому" end
    if sec < 730 * 86400 then return (sec // (30 * 86400)) .. " міс тому" end
    return (sec // (365 * 86400)) .. " р тому"
end

local W, H
local t = 0
local repos = {}  -- [full_name] = { stars, forks, issues, pushed, lang, ci, ci_name, base, base_day }
local at, status
local next_fetch = 0
local page, pt = 1, 0
local C = {}

local FIELDS = { "stars", "forks", "issues", "pushed", "lang", "ci", "ci_name", "base", "base_day" }
local NUM = { stars = true, forks = true, issues = true, pushed = true, base = true }

local function load()
    local ok, s = pcall(resources.read_file, CACHE)
    if not ok or not s then return end
    at = tonumber(s:match("^at=(%d+)"))
    for line in s:gmatch("[^\n]+") do
        local parts = {}
        for p in (line .. "|"):gmatch("([^|]*)|") do parts[#parts + 1] = p end
        if #parts == #FIELDS + 1 then
            local r = {}
            for i, f in ipairs(FIELDS) do
                local v = parts[i + 1]
                r[f] = NUM[f] and (tonumber(v) or 0) or v
            end
            repos[parts[1]] = r
        end
    end
end

local function save()
    local lines = { "at=" .. at }
    for _, name in ipairs(REPOS) do
        local r = repos[name]
        if r then
            local parts = { name }
            for _, f in ipairs(FIELDS) do parts[#parts + 1] = tostring(r[f] or ""):gsub("[|\n]", " ") end
            lines[#lines + 1] = table.concat(parts, "|")
        end
    end
    pcall(resources.write_file, CACHE, table.concat(lines, "\n"))
end

local function get(url)
    collectgarbage()
    local ok, res = pcall(http.execute, { url = url })
    if not ok then return nil, 0 end
    return res.response, floor(res.code or 0)
end

local function fetch_repo(name)
    local body, code = get(API .. name)
    if code == 403 or code == 429 then return "limit" end
    if code == 404 then return "missing" end
    if code ~= 200 or not body then return "fail" end
    local stars = tonumber(body:match('"stargazers_count":%s*(%d+)'))
    if not stars then return "fail" end
    local old = repos[name] or {}
    local r = {
        stars = stars,
        forks = tonumber(body:match('"forks_count":%s*(%d+)')) or 0,
        issues = tonumber(body:match('"open_issues_count":%s*(%d+)')) or 0,
        pushed = utc(body:match('"pushed_at":%s*"([^"]+)"')),
        lang = body:match('"language":%s*"([^"]+)"') or "",
        ci = old.ci or "", ci_name = old.ci_name or "",
    }
    local branch = body:match('"default_branch":%s*"([^"]+)"') or "main"
    body = nil
    -- Зірки на початок дня: від них рахуємо "+N сьогодні"
    local today = os.date("%Y-%m-%d")
    if old.base_day == today and old.base then r.base, r.base_day = old.base, today
    else r.base, r.base_day = old.stars or stars, today end

    local runs, rc = get(API .. name .. "/actions/runs?per_page=1&exclude_pull_requests=true&branch=" .. branch)
    if rc == 200 and runs then
        local st = runs:match('"status":%s*"([^"]+)"')
        local con = runs:match('"conclusion":%s*"?([%a_]*)')
        if not st then r.ci, r.ci_name = "", ""
        elseif st ~= "completed" then r.ci = "running"
        else r.ci = con ~= "" and con or "neutral" end
        local wf = runs:match('"workflow_runs":%s*%[%s*{.-"name":%s*"([^"]*)"') or ""
        r.ci_name = wf:match("([^/]+)%.ya?ml$") or wf -- без назви GitHub дає шлях до файлу
    end
    repos[name] = r
    return nil
end

local function fetch()
    if not (http and wifi) or wifi.get_status() ~= 3 then
        status = "Wi-Fi не під'єднано"
        return
    end
    if os.time() < 1700000000 then
        status = "Годинник ще не синхронізовано"
        return
    end
    local err
    for _, name in ipairs(REPOS) do
        local e = fetch_repo(name)
        if e == "limit" then err = "Ліміт GitHub, пізніше" break end
        if e and not err then err = e == "missing" and ("Немає " .. name) or "Не вдалося завантажити" end
    end
    at, status = os.time(), err
    save()
end

local function pages() return max(1, (#REPOS + PER_PAGE - 1) // PER_PAGE) end

function lilka.init()
    W, H = display.width, display.height
    -- Застосунок стартує на весь екран, тож display.height = 240 навіть з fullscreen = false
    if not lilka.fullscreen and H > 216 then H = H - 24 end
    C.bg = rgb(13, 17, 23)
    C.card = rgb(22, 27, 34)
    C.border = rgb(48, 54, 61)
    C.text = rgb(230, 237, 243)
    C.gray = rgb(125, 133, 144)
    C.blue = rgb(88, 166, 255)
    C.green = rgb(63, 185, 80)
    C.red = rgb(248, 81, 73)
    C.yellow = rgb(210, 153, 34)
    C.star = rgb(227, 179, 65)
    load()
    if controller then fetch(); next_fetch = REFRESH
    elseif not (at and os.time() - at < REFRESH) then next_fetch = 1
    else next_fetch = REFRESH - (os.time() - at) end
end

function lilka.update(delta)
    t = t + delta
    pt = pt + delta
    if controller then
        local s = controller.get_state()
        if s.start.just_pressed then util.exit() end
        if s.a.just_pressed then fetch(); next_fetch = REFRESH end
        if s.right.just_pressed then page = page % pages() + 1; pt = 0 end
        if s.left.just_pressed then page = (page - 2) % pages() + 1; pt = 0 end
    end
    if pt > PAGE_TIME then page = page % pages() + 1; pt = 0 end
    if http and wifi then
        next_fetch = next_fetch - delta
        if next_fetch <= 0 then
            next_fetch = REFRESH
            fetch()
        end
    end
end

local function star(x, y, c)
    display.fill_triangle(x, y - 4, x - 4, y + 3, x + 4, y + 3, c)
    display.fill_triangle(x - 4, y - 1, x + 4, y - 1, x, y + 5, c)
end
local function fork(x, y, c)
    display.fill_circle(x - 3, y - 3, 1, c)
    display.fill_circle(x + 3, y - 3, 1, c)
    display.fill_circle(x, y + 4, 1, c)
    display.draw_line(x - 3, y - 3, x - 3, y, c)
    display.draw_line(x + 3, y - 3, x + 3, y, c)
    display.draw_line(x - 3, y, x + 3, y, c)
    display.draw_line(x, y, x, y + 4, c)
end
local function issue(x, y, c)
    display.draw_circle(x, y, 4, c)
    display.fill_rect(x, y, 1, 1, c)
end

local CI = {
    success = { "збірка ок", "green" }, failure = { "збірка впала", "red" }, cancelled = { "скасовано", "gray" },
    running = { "збирається", "yellow" }, timed_out = { "тайм-аут", "red" }, neutral = { "збірка", "gray" },
    skipped = { "пропущено", "gray" }, action_required = { "чекає дії", "yellow" }, startup_failure = { "збірка впала", "red" },
}

local function draw_ci(r, xr, y)
    local info = CI[r.ci]
    if not info then return end
    local c = C[info[2]]
    if r.ci == "running" and floor(t * 2) % 2 == 0 then c = C.border end
    local w = utf8.len(info[1]) * 5 + 14
    local x = xr - w
    display.draw_rect(x, y - 8, w, 11, c)
    display.fill_circle(x + 5, y - 3, 2, c)
    text(info[1], x + 10, y + 1, c, "5x7")
end

local function draw_card(name, x, y, w, h)
    display.fill_rect(x, y, w, h, C.card)
    display.draw_rect(x, y, w, h, C.border)
    local owner, repo = name:match("([^/]+)/(.+)")
    owner, repo = owner or "", repo or name
    text(owner .. "/", x + 6, y + 13, C.gray, "6x12")
    text(repo, x + 6 + (#owner + 1) * 6, y + 14, C.blue, "8x13")
    local r = repos[name]
    if not r then
        text("ще немає даних", x + 6, y + 30, C.gray, "5x7")
        return
    end
    draw_ci(r, x + w - 6, y + 11)

    local yy = y + 30
    local cx = x + 10
    local tw = 0.5 + 0.5 * sin(t * 3 + #name)
    star(cx, yy - 3, r.stars - (r.base or r.stars) > 0 and rgb(227, 179 + 50 * tw, 65 + 120 * tw) or C.star)
    text(tostring(r.stars), cx + 8, yy, C.text, "6x12")
    cx = cx + 10 + #tostring(r.stars) * 6
    local d = r.stars - (r.base or r.stars)
    if d ~= 0 then
        local ds = (d > 0 and "+" or "") .. d
        text(ds, cx + 2, yy - 1, d > 0 and C.green or C.red, "5x7")
        cx = cx + 4 + #ds * 5
    end
    cx = cx + 12
    fork(cx, yy - 4, C.gray)
    text(tostring(r.forks), cx + 7, yy, C.text, "6x12")
    cx = cx + 22 + #tostring(r.forks) * 6
    issue(cx, yy - 4, r.issues > 0 and C.green or C.gray)
    text(tostring(r.issues), cx + 7, yy, C.text, "6x12")
    if r.lang ~= "" then
        local lc = LANG[r.lang] or { 140, 140, 140 }
        local lx = x + w - 8 - #r.lang * 6
        display.fill_circle(lx - 7, yy - 4, 3, rgb(lc[1], lc[2], lc[3]))
        text(r.lang, lx, yy, C.gray, "6x12")
    end
    local info = "push " .. ago(max(0, os.time() - r.pushed))
    if r.ci_name ~= "" then info = info .. ",  " .. r.ci_name end
    text(info, x + 6, y + h - 5, C.gray, "5x7")
end

function lilka.draw()
    display.fill_screen(C.bg)
    local n = min(PER_PAGE, #REPOS)
    local gap = 4
    local ch = (H - 10 - gap * (n - 1)) // n
    ch = min(ch, 52)
    local from = (page - 1) * PER_PAGE
    for k = 1, PER_PAGE do
        local name = REPOS[from + k]
        if not name then break end
        draw_card(name, 4, 2 + (k - 1) * (ch + gap), W - 8, ch)
    end
    local note
    if status then note = status
    elseif at then note = "GitHub, оновлено " .. os.date("%H:%M", at)
    else note = "Відкрийте wallpaper.lua як застосунок з Wi-Fi" end
    text(note, 6, H - 1, status and C.red or C.gray, "5x7")
    if pages() > 1 then
        local s = page .. "/" .. pages()
        text(s, W - 6 - #s * 5, H - 1, C.gray, "5x7")
    end
end
