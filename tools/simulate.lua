-- Plays the whole chain hour by hour with real timers and the weather from the game's forecasts, through
-- the mod's own rules: malting, kilning and mashing, a 2-bucket vessel run, the hose into a cask, souring,
-- bottling down to a starter, and a second batch pumped in over the top. It prints when each step ends
-- and checks that the litres add up.
-- Run from the mod folder: luajit tools/simulate.lua [path/to/climate.csv]
local hour = 0
function getGameTime() return { getWorldAgeHours = function() return hour end } end
local store = {}
ModData = { getOrCreate = function() return store end }
Events = { OnInitGlobalModData = { Add = function() end } }
dofile((os.getenv("TPCORE") or "../TraditionalPreservationCore") .. "/tests/harness.lua").useModPaths()
dofile("42/media/lua/shared/TraditionalPreservationVinegar.lua")
local V = TraditionalPreservationVinegar

local MONTHS = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }
-- Hands-on time between malting and fermenting at Normal effort: kiln 3 h, mash, heat 1.5 h, strain.
local HANDS_ON_HOURS = 6
local BOTTLE_KEEP_ML = 3000

local function readDays(path)
    local days = {}
    for line in io.lines(path) do
        local f = {}
        for field in line:gmatch("%S+") do table.insert(f, field) end
        -- Each month's forecast also holds the 10 days before it (offset below 0): skipped, so a month is 30 days.
        if #f >= 6 and tonumber(f[3]) >= 0 then table.insert(days, { world = tonumber(f[1]), offset = tonumber(f[3]), month = tonumber(f[2]), low = tonumber(f[4]), mean = tonumber(f[5]), high = tonumber(f[6]) }) end
    end
    return days
end

local function hourly(day, h)
    local swing = math.cos((h - 15) / 24 * 2 * math.pi)
    return swing >= 0 and day.mean + (day.high - day.mean) * swing or day.mean + (day.mean - day.low) * swing
end

-- The first sampled world's calendar year, settled (Weather.settledMeans).
local function settle(days)
    local year = {}
    for _, day in ipairs(days) do
        if day.world == days[1].world then table.insert(year, day) end
    end
    return require("TraditionalPreservationCore/Weather").settledMeans(year)
end
local settled

local function simulate(days, startIndex, place)
    hour = (startIndex - 1) * 24
    store.ledger = nil
    local ledger = V.getLedger()
    ledger.seasonTemperature, ledger.groundTemperature = settled(days[startIndex].month, days[startIndex].offset)
    local log = {}
    local function note(text) table.insert(log, string.format("  day %5.1f  %s", (hour - (startIndex - 1) * 24) / 24, text)) end
    local function tick()
        local index = math.floor(hour / 24) + 1
        if not days[index] then return false end
        hour = hour + 1
        V.advance(ledger, hour, hourly(days[index], hour % 24))
        return true
    end

    -- Malting, then the hands-on work.
    local heap = V.putHeap({ heaps = {}, nextId = 1 }, { getFullType = function() return V.STEEPED end, getModData = function() return {} end }, hour, place)
    repeat if not tick() then return nil end V.advanceHeap(heap, hour, place, nil, nil, ledger) until V.heapDone(heap)
    note("malt ready")
    for _ = 1, HANDS_ON_HOURS do tick() end

    -- Two vessel runs of 20 L each, back to back; the second starts as soon as the first is drawn off.
    local cask = { ml = 0, strength = 0 }
    V.updateCask(cask, ledger, place)
    local vessel = { wortMl = 0, fermentedMl = 0 }
    local wortIn, bottled, firstBottleDay = 0, 0, nil
    local runsLeft = 2
    local function startRun()
        V.pourWortIn(vessel, 20000, nil, place)
        V.pitch(vessel, hour, place)
        wortIn = wortIn + 20000
        runsLeft = runsLeft - 1
    end
    startRun()
    local guard = 0
    while guard < 24 * 400 do
        guard = guard + 1
        if not tick() then return nil, log end
        if V.advanceVessel(vessel, hour, place, nil, place, nil, ledger) then
            note(string.format("vessel done: %.1f L fermented wort", vessel.fermentedMl / 1000))
        end
        V.updateCask(cask, ledger, place)
        -- The player pumps a whole batch across once the cask has room for it.
        local batch = vessel.fermentedMl
        local pumped = V.caskRoom(cask) >= batch and V.pumpToCask(cask, vessel, batch) or 0
        if pumped > 0 then
            note(string.format("hose pumped %.1f L, cask now %.1f L at %.0f%%", pumped / 1000, cask.ml / 1000, cask.strength * 100))
            if runsLeft > 0 and not vessel.run then startRun() end
        end
        if cask.strength >= 1 and cask.ml > BOTTLE_KEEP_ML + V.BOTTLE_ML then
            local count = 0
            while cask.ml - V.BOTTLE_ML >= BOTTLE_KEEP_ML and V.takeBottle(cask) do count = count + 1 end
            bottled = bottled + count
            firstBottleDay = firstBottleDay or (hour - (startIndex - 1) * 24) / 24
            note(string.format("bottled %d, %.1f L left as starter, mother layers %d", count, cask.ml / 1000, V.motherLayers(cask)))
            if runsLeft == 0 and not vessel.run and vessel.fermentedMl < 50 then break end
        end
    end
    local vinegar = bottled + cask.ml / 1000
    note(string.format("in: %.0f L wort -> out: %d bottles + %.1f L starter = %.1f L (%.0f%%)", wortIn / 1000, bottled, cask.ml / 1000, vinegar, vinegar / (wortIn / 1000) * 100))
    return firstBottleDay, log
end

local days = readDays(arg[1] or "tools/climate_year.csv")
settled = settle(days)
-- An open roof reads as indoors (the season's mean), so it isn't run on its own.
local placeNames = { Open = "outdoors", Sheltered = "indoors", AiredRoom = "in an aired room", Basement = "in a basement" }
for _, month in ipairs({ 1, 4, 7, 10 }) do
    local first
    for index, day in ipairs(days) do if day.month == month then first = index break end end
    for _, place in ipairs({ "Open", "Sheltered", "AiredRoom", "Basement" }) do
        local firstBottle, log = simulate(days, first, place)
        print(string.format("%s, %s: first bottles on day %s", MONTHS[month], placeNames[place], firstBottle and string.format("%.0f", firstBottle) or "(past the forecasts)"))
        for _, line in ipairs(log or {}) do print(line) end
    end
end
