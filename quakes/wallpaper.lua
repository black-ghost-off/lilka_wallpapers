-- Землетруси за тиждень (магнітуда 4.5+, USGS) на карті світу. Свіжіші — червоніші,
-- сильніші — більші. Найсильніші по черзі підсвічуються з описом унизу.
-- Застосунок завантажує дані в quakes.txt; шпалери на свіжій Keira оновлюють їх самі.
-- Застосунок: ← → — землетрус, A — оновити, START — вихід.

lilka.fullscreen = false

local URL = "https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/4.5_week.csv"
local CACHE = "quakes.txt"
local REFRESH = 30 * 60
local KEEP = 80       -- скільки землетрусів зберігати
local SHOW_TIME = 5   -- секунд на один підсвічений

-- Карта суходолу: tools/gen_map.py з Natural Earth 110m. 8 символів на прямокутник
local MAP_W, MAP_H, LAT_TOP = 280, 107, 80
local LAND = "A1AAABABDSAAAKABCuAAAHABCUAAAOABA5AAAFABA/AABBABCcABAEABDZABAFABCWABAFABAzABAEABAvABADABA6ABBDABA0ACABABCWACAEABC7ACAHABBUACAqABA8ACAUABAtACAGABDYACANABA2ACACABA8ADASABAsADADABC3ADAIABD2ADAMABBWADADABAwADAKABDPADAWABBcADAhABBfAEAeABC1AEAFABDrAEABABA9AEATABAzAEAEABD/AEACABAqAEAIABD4AEAFABA5AEACABDKAEAfABD4AFAEABA8AFAJABC0AFAFABDBAFAEABBGAFALABDJAFAoABBgAFAcABDGAFABABBgAGAbABChAGABABA+AGAGABC/AGAyABDyAGAPABASAGACABBFAGAPABAqAFARACEGAGABABCfAGABABC0AGAEABBhAHAbABC/AHBKABANAHARABA/AHAGABBGAHASABC1AHAEABEQAHAFABAAAGACACArAHADABAlAHAEABCaAHALABAvAHAPABEXAGABACC7AHABABAAAIABABBJAIAEABBhAIAYABCYAIARABCtAIABABAKAIA+ABC1AIAKABDAAIBYABBQAIAIABCXAJAVABAAAJAEABCtAJBrABBiAJATABBPAJALABBQAKABABBSAKAKABCVAKCDABBiAKAQABB5AKACABAKAJBDACB9AKAEABCqALBuABCfALAKABBOALANABAJALBDABB5ALAJABCVALAJABBjALAMABAAAKAIACBjAMAKABALAMBDABB6AMAHABAEAMAFABCSAMCFABBPAMALABCQANAKABBJANARABBlANAGABAHANACABCcANB8ABALANA7ABCcAOB4ABBlAOAHABCPAOALABBYAOABABAKAOA5ABBNAOAJABAJAPAQABBZAPACABBPAPAHABCdAPBnABBpAPACABAaAPApABCQAPALABEIAPAJABBOAQAOABCIAQACABEBAQAEABANAQAKABCQAQADABAgAQAkABCeAQBiABCUAQAGABEIAQADABBPARAOABAQARAGABAjARAjABCcARBdABCRARAIABCcASBbABAOASAEABCHARAEACAUASABABBQASANABEFARAGACAlASAlABCSASAHABEEATAHABCFATAHABCSATAFABALATAFABAlATA7ABD6ATABABCYATBfABEFAUAEABCEAUAJABAkAUACABCEAVAKABBOAUATACEFAVADABCPAUBtACAlAVABABAnAUAmACCFAWABABEFAWABABCIAWB0ABAoAWA5ABAoAXA2ABCHAXB1ABBfAXAEABD8AYABABCIAYBxABAqAYAyABBdAYAGABD6AYABABCJAZApABArAZAwABBcAZAIABC2AZBCACArAaAzABCLAaAmABD9AbABABC2AbBBABArAbAyABCKAbAaABD6AZACADC0AbABABClAbALABCYAcALABCEAcATABC1AcBBABBYAcACABCrAcAFABD5AcAFABArAcAsABC3AdA7ABD4AdAEABArAdArABClAdADABCsAdAFABCaAdAIABCEAdALABCSAdAHABC3AeA6ABArAeAqABCFAeAJABD4AeACABCWAeAcABArAfAoABC2AfA6ABD4AfADABCSAeACACCgAfASABCXAfAIABCVAgAEABDsAgAEABC2AgA0ABAsAgAmABCEAfAJACD4AgACABCgAgARABD2AhAEABCcAgADACCFAhAGABC2AhA2ABAsAhAlABCMAhAJABChAhASABCWAhACABDzAiAHABCeAiADABCHAiAOABDuAhADACAtAiAlABCjAiABABDxAjAIABCGAjAPABAuAjAjABDuAjACABClAiBFACCfAjABABCnAkBEABCEAkATABDwAkAGABCcAkACABAwAkAfABAxAlAdABCbAlAHABDxAlACABCjAlBIABCEAlAVABDxAmABABCEAmBnABAxAmAcABCDAnAvABCzAnA4ABAyAnAVABBJAnABABBLAnADACCBAoAyABC0AoA3ABBMApAFABC1ApA1ABCAApAnABCoApAMABAyAoAPACBMAqACABA0AqANABC2AqA1ABCAAqA1ABBPAqABACCpArARABB/ArApABA4ArAJABDAArArABA1ArACABA5AsAHABB/AsAqABDBAsAmABBKAsAGABDpAsACABAPAsACABA2AsABABB+AtArABBNAtAFABAPAtAEABDpAtABABDBAtAkABBFAtAGABCqAsARACA5AtAIACBFAuAEABB/AuAqABBPAuAHABCqAuAQABDDAuANABDTAuAQABCrAvAOABA6AvAOABDUAvALABDgAvACABASAuACACDEAvALABB/AvArACBSAvAHACDVAwAKABDEAwAJABCsAwAMABDhAwABABBPAvACACA8AwAMABA+AxANABCtAxAKABDFAxAHABDVAxAMABDpAvADADB/AxAsABBAAyABABB+AyA3ABBDAyAJABDYAyAJABDpAyACABDFAyAGABDYAzAKABDpAzAEABB+AzA0ABBEAzAIABB/A0AxABBTA0ADABDYA0AJABBHA0AFABCzA0ABABDpA0AFABDoA1ABABCvA1AFABBRA1AGABBIA1ADABB/A1AvABDGAzAFADBYA1AFABDcA1AFABDqA1AEABBNA2ACABDoA2AHABDHA2AEABCAA2A0ABBQA2ANABDdA2ADABBJA2ADABDdA3ABABBKA3AUABDrA3AEABDnA3ABABCBA3AzABDYA1ACADDHA3AFABBMA4ACABDIA4ABABDYA4AEABBPA4AQABDqA4AFABDmA4ACABCBA4AyABCDA5AvABBPA5AUABDsA5ADABDKA4ACACDWA5ABABDZA5AEABDlA5AEABCQA6AiABCEA6AIABDkA6AFABCSA7AfABDiA7AGABBPA6AWACDWA6AHACDhA8AHABDXA8AHABDtA8ABABDvA8ABABCTA8AeABBOA8AYABDgA9AOABDYA9AGABDvA9ACABBNA9AZABCTA9AcABBNA+AbABDpA+AEABDgA+AIABDvA+AGABDZA+AEABDxA/AEABD2A/ADABDaA/AEABBNA/AdABCSA+AbACDoA/AEACDhA/AGACBNBAAgABDtBAAPABCTBAAZABEBBAACABDaBAAFABDzBBABABD1BBAIABDuBBABABDbBBAEABBMBBAkABDpBBADABCUBBAXABDlBBACABEBBBADABDxBBABABBMBCAlABDcBCAEABEEBCABABDrBCABABD3BCAMABDoBCACABEEBDAEABDdBDAHABD3BDAKABD0BCABACBNBDAkABCVBCAWACDnBEAFABEHBEADABDgBEAGABDtBEADABBOBEAjABD3BEAJABEIBFACABD9BFAEABDlBFAGABD5BFADABDsBFACABBPBFAiABCWBEAVACDyBGABABD/BGADABDpBGABABBPBGAhABEJBGACABDsBGABABCyBHABABCWBGAWACDuBIABABDxBHAGACD6BGACADCxBIACABBQBHAfACENBJABABBQBJAeABCxBJADABDtBJAJABD6BJAEABCVBIAXADBRBKAdABENBKACABDrBKANABCuBKAGABD5BKAFABEXBKABABAABKABACEOBLABABCVBLAWABDrBLATABEWBLACABCVBMAUABBUBLAaACEVBMACABDqBMAUABCVBNATABBVBNAZABELBNABABDoBNAYABCuBLAFADELBOACABDlBOAcABBVBOAYACCWBOASACCtBOAFACEMBPACABCtBQAEABBVBQAXABDkBPAeACBVBRASABCXBQARACDkBRAfABCuBRADABCvBSABABCXBSAPACBUBSATADDkBSAgADCYBUAOABCZBVAMABDlBVAfACCZBWALABBUBVARACCZBXAKABDlBXALABDyBXARABCaBYAIABD0BYAOABBUBXAQACDlBYAIABDmBZADABESBZACABD1BZANABCaBZACABBTBZAPABETBaACABBTBaANABBSBbAOABD4BaAJACBTBcALABETBbAEACD6BcAFABD8BdADABEUBdACABESBdABABERBeAEABD8BeAEABBSBdAKACD9BfADABBSBfAJABEQBfAEABD9BgACABEOBgAFABBSBgAIABBRBhAJABENBhAFABENBiAEABBRBiAIACDBBkACABBeBlABABBRBkAHACBcBmAEABBRBmAGACBTBoAHABBUBpAGAB"

local floor, sin = math.floor, math.sin
local function min(a, b) if a < b then return a end return b end
local function max(a, b) if a > b then return a end return b end
local function clamp(x, a, b) return min(b, max(a, x)) end
local function rgb(r, g, b) return display.color565(floor(clamp(r, 0, 255)), floor(clamp(g, 0, 255)), floor(clamp(b, 0, 255))) end

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local IDX = {}
for i = 1, #B64 do IDX[B64:byte(i)] = i - 1 end

local function text(s, x, y, c, font)
    display.set_font(font)
    display.set_text_size(1)
    display.set_text_color(c)
    display.set_cursor(floor(x), floor(y))
    display.print(s)
end

local W, H, OX, OY
local t = 0
local quakes = {}   -- { time, lat, lon, depth, mag, place }, від нових до старих
local top = {}      -- індекси найсильніших
local at, status
local sel, sel_t = 1, 0
local next_fetch = 0
local land = {}
local C = {}

-- Unix-час з UTC-дати (os.time рахує в місцевому часі)
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
    local y, mo, d, h, mi, se = s:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
    if not y then return nil end
    return days_from_civil(tonumber(y), tonumber(mo), tonumber(d)) * 86400 + tonumber(h) * 3600 + tonumber(mi) * 60 + tonumber(se)
end

local function csv_fields(line)
    local f, i, n = {}, 1, #line
    while i <= n + 1 do
        if line:sub(i, i) == '"' then
            local j = line:find('"', i + 1, true) or n + 1
            f[#f + 1] = line:sub(i + 1, j - 1)
            i = j + 2
        else
            local j = line:find(",", i, true) or n + 1
            f[#f + 1] = line:sub(i, j - 1)
            i = j + 1
        end
    end
    return f
end

local function pick_top()
    top = {}
    for i = 1, #quakes do top[i] = i end
    table.sort(top, function(a, b) return quakes[a][5] > quakes[b][5] end)
    for i = #top, 7, -1 do top[i] = nil end
    sel, sel_t = 1, 0
end

local function load()
    local ok, s = pcall(resources.read_file, CACHE)
    if not ok or not s then return end
    quakes = {}
    at = tonumber(s:match("^at=(%d+)"))
    for line in s:gmatch("[^\n]+") do
        local tm, la, lo, de, ma, pl = line:match("^(%d+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)|(.*)$")
        if tm then quakes[#quakes + 1] = { tonumber(tm), tonumber(la), tonumber(lo), tonumber(de), tonumber(ma), pl } end
    end
    pick_top()
end

local function fetch()
    if not (http and wifi) or wifi.get_status() ~= 3 then
        status = "Wi-Fi не під'єднано"
        return
    end
    collectgarbage()
    local ok, res = pcall(http.execute, { url = URL })
    if not (ok and res.code == 200 and res.response) then
        status = "Не вдалося завантажити"
        return
    end
    local out = {}
    for line in res.response:gmatch("[^\r\n]+") do
        if #out < KEEP and line:match("^%d") then
            local f = csv_fields(line)
            local tm = utc(f[1])
            if tm and tonumber(f[5]) then
                out[#out + 1] = table.concat({ tm, f[2], f[3], f[4], f[5], ((f[14] or ""):gsub("|", " ")) }, "|")
            end
        end
    end
    if #out == 0 then
        status = "Незрозуміла відповідь"
        return
    end
    at, status = os.time(), nil
    pcall(resources.write_file, CACHE, "at=" .. at .. "\n" .. table.concat(out, "\n"))
    load()
end

function lilka.init()
    W, H = display.width, display.height
    -- Застосунок стартує на весь екран, тож display.height = 240 навіть з fullscreen = false
    if not lilka.fullscreen and H > 216 then H = H - 24 end
    OX, OY = (W - MAP_W) // 2, 16
    for i = 1, #LAND, 8 do
        local a, b, c, d, e, f, g, h = LAND:byte(i, i + 7)
        land[#land + 1] = { IDX[a] * 64 + IDX[b], IDX[c] * 64 + IDX[d], IDX[e] * 64 + IDX[f], IDX[g] * 64 + IDX[h] }
    end
    C.sea = rgb(8, 18, 40)
    C.land = rgb(38, 52, 72)
    C.grid = rgb(18, 32, 60)
    C.text = rgb(235, 240, 255)
    C.gray = rgb(130, 140, 165)
    C.age = { rgb(255, 60, 50), rgb(255, 130, 40), rgb(240, 200, 60), rgb(150, 140, 90) }
    load()
    if controller then fetch(); next_fetch = REFRESH
    elseif not (at and os.time() - at < REFRESH) then next_fetch = 1 end
end

function lilka.update(delta)
    t = t + delta
    sel_t = sel_t + delta
    if controller then
        local s = controller.get_state()
        if s.start.just_pressed then util.exit() end
        if s.a.just_pressed then fetch(); next_fetch = REFRESH end
        if s.right.just_pressed and #top > 0 then sel, sel_t = sel % #top + 1, 0 end
        if s.left.just_pressed and #top > 0 then sel, sel_t = (sel - 2) % #top + 1, 0 end
    end
    if sel_t > SHOW_TIME and #top > 0 then sel, sel_t = sel % #top + 1, 0 end
    if http and wifi then
        next_fetch = next_fetch - delta
        if next_fetch <= 0 then
            next_fetch = REFRESH
            fetch()
        end
    end
end

local function to_map(lat, lon)
    return OX + (lon + 180) / 360 * MAP_W, OY + clamp((LAT_TOP - lat) / 360 * MAP_W, 0, MAP_H - 1)
end

local function ago(s)
    if s < 3600 then return max(1, s // 60) .. " хв тому" end
    if s < 86400 then return s // 3600 .. " год тому" end
    return s // 86400 .. " дн тому"
end

local function age_col(s)
    if s < 6 * 3600 then return C.age[1] end
    if s < 86400 then return C.age[2] end
    if s < 3 * 86400 then return C.age[3] end
    return C.age[4]
end

local function short_place(p)
    -- "207 km ESE of Sarangani, Philippines" → "Sarangani, Philippines"
    return (p:gsub("^%d+ km %a+ of ", ""))
end

function lilka.draw()
    display.fill_screen(0)
    display.fill_rect(OX, OY, MAP_W, MAP_H, C.sea)
    for lon = -150, 150, 30 do
        local x = floor((to_map(0, lon)))
        for y = OY + 1, OY + MAP_H - 1, 4 do display.fill_rect(x, y, 1, 1, C.grid) end
    end
    for _, r in ipairs(land) do display.fill_rect(OX + r[1], OY + r[2], r[3], r[4], C.land) end

    local now = os.time()
    -- Від старих до нових, щоб свіжі були зверху
    for k = #quakes, 1, -1 do
        local q = quakes[k]
        local x, y = to_map(q[2], q[3])
        local r = max(1, floor((q[5] - 4) * 2))
        display.fill_circle(floor(x), floor(y), r, age_col(now - q[1]))
    end
    -- Найсвіжіший пульсує
    if quakes[1] then
        local x, y = to_map(quakes[1][2], quakes[1][3])
        local ph = (t % 1.6) / 1.6
        display.draw_circle(floor(x), floor(y), floor(3 + ph * 12), C.age[1])
    end
    -- Підсвічений сильний: перехрестя й кільця
    local q = top[sel] and quakes[top[sel]]
    if q then
        local x, y = to_map(q[2], q[3])
        x, y = floor(x), floor(y)
        display.fill_rect(OX, y, MAP_W, 1, C.gray)
        display.fill_rect(x, OY, 1, MAP_H, C.gray)
        local r = floor(6 + 3 * sin(t * 5))
        display.draw_circle(x, y, r, C.text)
        display.draw_circle(x, y, r + 4, C.age[1])
    end

    -- Заголовок
    text("Землетруси", 4, 13, C.text, "8x13")
    text("7 днів, M4.5+", 90, 12, C.gray, "6x12")
    local note = status and controller and status or (#quakes .. " шт.")
    text(note, W - 4 - utf8.len(note) * 6, 12, status and C.age[1] or C.gray, "6x12")

    -- Опис підсвіченого
    local y0 = OY + MAP_H + 4
    if q then
        text(string.format("M%.1f", q[5]), 6, y0 + 18, age_col(now - q[1]), "10x20")
        local place = short_place(q[6])
        if #place > 36 then place = place:sub(1, 35) .. "." end
        text(place, 58, y0 + 10, C.text, "6x12")
        text(ago(now - q[1]) .. ", глибина " .. floor(q[4]) .. " км", 58, y0 + 23, C.gray, "6x12")
    elseif not at then
        text("Немає даних", 6, y0 + 16, C.text, "9x15")
        text("відкрийте wallpaper.lua як застосунок з Wi-Fi", 6, y0 + 30, C.gray, "6x12")
    end
    -- Останні
    local ly = y0 + 40
    text("останні:", 6, ly, C.gray, "5x7")
    for k = 1, min(4, #quakes) do
        local e = quakes[k]
        local y = ly + 11 * k
        if y > H - 2 then break end
        local pl = short_place(e[6])
        if #pl > 26 then pl = pl:sub(1, 25) .. "." end
        text(string.format("M%.1f", e[5]), 6, y, age_col(now - e[1]), "6x12")
        text(pl, 38, y, C.text, "6x12")
        local a = ago(now - e[1])
        text(a, W - 4 - utf8.len(a) * 6, y, C.gray, "6x12")
    end
end
