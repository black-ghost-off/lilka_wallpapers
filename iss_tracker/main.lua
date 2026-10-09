-- ISS tracker for Lilka: app (run main.lua) and home-screen wallpaper
-- (copy wallpaper.lua to the SD card root).
-- Position is propagated on the device from the ISS TLE (cached in tle.txt,
-- refreshed over HTTP when older than 12 h) using the NTP clock.
-- Lilka's math.* is 32-bit float: big numbers (time) stay in plain Lua math.

local DIR = ISS_DIR or ""
local TLE_URLS = {
    "http://celestrak.org/NORAD/elements/gp.php?CATNR=25544&FORMAT=TLE",
    "http://live.ariss.org/iss.txt",
}
local MU, RE, J2, F = 398600.4418, 6378.137, 1.08262668e-3, 1 / 298.257
local TAU, D2R = 2 * math.pi, math.pi / 180
local sin, cos, floor, atan2 = math.sin, math.cos, math.floor, math.atan2
-- map fills the 280x216 canvas under the status bar (map.bmp is 280x216)
local MX, MY, MW, MH = 0, 0, 280, 216
lilka.fullscreen = false

local function rgb(r, g, b) return display.color565(r, g, b) end
local BG, NIGHT, TERM = rgb(8, 24, 88), rgb(0, 8, 48), rgb(104, 160, 248)
local ISS, ISS_EDGE, TRACK, PAST = rgb(255, 220, 0), rgb(255, 136, 0), rgb(120, 220, 255), rgb(56, 104, 192)

local el, failed, night, sun_lat, sun_lon
local tx, ty = {}, {} -- ground track points (flat arrays: RAM is tight)
local track_at, night_at = -1e9, -1e9

-- TLE text -> orbital elements with J2 secular rates
local function parse(text)
    local l1 = text and text:match("1 25544U[^\r\n]+")
    local l2 = text and text:match("2 25544 [^\r\n]+")
    if not (l1 and l2) then return nil end
    local yy, doy = tonumber(l1:sub(19, 20)), tonumber(l1:sub(21, 32))
    local y = 2000 + yy - 1
    local days = 365 * (y + 1 - 1970) + y // 4 - 492 - (y // 100 - 19) + (y // 400 - 4)
    local i, e = tonumber(l2:sub(9, 16)) * D2R, tonumber("0." .. l2:sub(27, 33))
    local n = tonumber(l2:sub(53, 63)) * TAU / 86400
    local a = (MU / (n * n)) ^ (1 / 3)
    local p = a * (1 - e * e)
    local k = 1.5 * J2 * (RE / p) ^ 2 * n
    return {
        epoch = (days + doy - 1) * 86400, i = i, e = e, n = n,
        raan = tonumber(l2:sub(18, 25)) * D2R, raan_dot = -k * cos(i),
        argp = tonumber(l2:sub(35, 42)) * D2R, argp_dot = k * (2 - 2.5 * sin(i) ^ 2),
        m0 = tonumber(l2:sub(44, 51)) * D2R, ndot = tonumber(l1:sub(34, 43)) * TAU,
    }
end

local function gmst(t) return ((280.46061837 + 360.98564736629 * (t / 86400 - 10957.5)) % 360) * D2R end

-- unix time -> lat, lon (deg)
local function position(t)
    local dt = t - el.epoch
    local M = (el.m0 + el.n * dt + el.ndot * (dt / 86400) ^ 2) % TAU
    local nu = M + 2 * el.e * sin(M)
    local u = (el.argp + el.argp_dot * dt + nu) % TAU
    local lat = math.asin(sin(el.i) * sin(u))
    local lon = (el.raan + el.raan_dot * dt + atan2(cos(el.i) * sin(u), cos(u)) - gmst(t)) / D2R
    return atan2(sin(lat), cos(lat) * (1 - F) ^ 2) / D2R, (lon + 180) % 360 - 180 -- geodetic
end

local function to_map(lat, lon)
    return floor(MX + (lon + 180) / 360 * MW), floor(MY + (90 - lat) / 180 * MH)
end

-- subsolar point and terminator y per 4-px column
local function build_night(t)
    local d = t / 86400 - 10957.5
    local g = ((357.529 + 0.98560028 * d) % 360) * D2R
    local L = (((280.459 + 0.98564736 * d) % 360) + 1.915 * sin(g)) * D2R
    local dec = math.asin(0.3978 * sin(L))
    sun_lat = dec / D2R
    sun_lon = ((atan2(0.9175 * sin(L), cos(L)) - gmst(t)) / D2R + 180) % 360 - 180
    night = {}
    for x = 0, MW - 1, 4 do
        local h = ((x + 2) / MW * 360 - 180 - sun_lon) * D2R
        night[#night + 1] = floor(MY + (90 - math.atan(-cos(h) / math.tan(dec)) / D2R) / 180 * MH)
    end
end

local function build_track(t)
    for k = 1, 93 do -- 90 s steps: half an orbit back (k <= 31), one ahead
        tx[k], ty[k] = to_map(position(t + (k - 31) * 90))
    end
end

-- Cached TLE; refreshed when stale. Runs before anything else is loaded:
-- DNS/HTTP fail when the heap is low (other services eat RAM).
do
    local ok, cached = pcall(resources.read_file, DIR .. "tle.txt")
    el = ok and parse(cached) or nil
    -- Only the app downloads (controller exists only there): the wallpaper runs
    -- on the launcher's 8 KB stack and an HTTP request there overflows it.
    local online = controller and http and wifi and wifi.get_status() == 3
    if online and (not el or os.time() - el.epoch > 43200) then
        collectgarbage()
        for _, url in ipairs(TLE_URLS) do
            local ok2, res = pcall(http.execute, { url = url })
            local fresh = ok2 and res.code == 200 and parse(res.response)
            if fresh then
                pcall(resources.write_file, DIR .. "tle.txt", res.response)
                el = fresh
                break
            end
            if not ok2 or res.code < 0 then break end -- network down, not the source
        end
    end
    if not el then
        failed = not controller and "NO TLE: OPEN THE ISS APP ONCE"
            or online and "NO TLE: DOWNLOAD FAILED" or "NO TLE: WI-FI OFFLINE"
    end
end

local map = resources.load_image(DIR .. "map.bmp", BG) -- BG is transparent

local function text(x, y, s, color, font)
    display.set_font(font or "6x12")
    display.set_text_color(color)
    display.set_cursor(x, y)
    display.print(s)
end

function lilka.update(delta)
    if controller and controller.get_state().b.just_pressed then util.exit() end
    local t = os.time()
    if t < 1700000000 then return end -- clock not synced yet
    if t - night_at >= 60 then build_night(t); night_at = t end
    if el and t - track_at >= 30 then build_track(t); track_at = t end
end

function lilka.draw()
    local t = os.time()
    display.fill_screen(BG)
    if t < 1700000000 then return text(10, MH - 8, "WAITING FOR CLOCK (WI-FI)", ISS) end

    for i, ty in ipairs(night) do -- night side, then map with transparent sea
        local x = MX + (i - 1) * 4
        if sun_lat > 0 then display.fill_rect(x, ty, 4, MY + MH - ty, NIGHT)
        else display.fill_rect(x, MY, 4, ty - MY, NIGHT) end
        if i > 1 then display.draw_line(x - 4, night[i - 1], x, ty, TERM) end
    end
    display.draw_image(map, MX, MY)

    if not el then return text(10, MH - 8, failed, ISS) end
    for i = 2, #tx do
        if math.abs(tx[i] - tx[i - 1]) < MW / 2 then display.draw_line(tx[i - 1], ty[i - 1], tx[i], ty[i], i <= 31 and PAST or TRACK) end
    end

    local lat, lon = position(t)
    local x, y = to_map(lat, lon)
    if t % 2 == 0 then display.draw_circle(x, y, 8, ISS_EDGE) end
    display.fill_circle(x, y, 5, ISS_EDGE)
    display.fill_circle(x, y, 4, ISS)
    text(x + 9 > MW - 20 and x - 27 or x + 9, y - 3 < MY + 9 and MY + 9 or y - 3, "ISS", ISS)
end
