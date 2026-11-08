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
        for value in line:gmatch("%S+") do table.insert(f, value) end
        if #f >= 6 then table.insert(days, { month = tonumber(f[2]), low = tonumber(f[4]), mean = tonumber(f[5]), high = tonumber(f[6]) }) end
    end
    return days
end

local function hourly(day, h)
    local swing = math.cos((h - 15) / 24 * 2 * math.pi)
    return swing >= 0 and day.mean + (day.high - day.mean) * swing or day.mean + (day.mean - day.low) * swing
end

local function run(seconds)
    local data = { modData = {}, elapsed = 0 }
    function data:getModData() return self.modData end
    function data:setElapsedTime(value) self.elapsed = value end
    function data:getRecipe() return { getTime = function() return seconds end } end
    return data
end

local function simulate(days, startIndex, place)
    hour = (startIndex - 1) * 24
    store.ledger = nil
    local ledger = V.getLedger()
    ledger.seasonTemperature = days[startIndex].mean
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
    local floor = run(V.MALTING_HOURS * 3600)
    V.onMaltStart(floor)
    floor.modData.place = place
    repeat if not tick() then return nil end V.onMaltUpdate(floor) until floor.elapsed >= V.MALTING_HOURS * 3600
    note("malt ready")
    for _ = 1, HANDS_ON_HOURS do tick() end

    -- Two vessel runs of 20 L each, back to back; the second starts as soon as the first is drawn off.
    local cask = { ml = 0, strength = 0 }
    V.updateCask(cask, ledger, place)
    local vesselTank = { litres = 0 }
    function vesselTank:getAmount() return self.litres end
    function vesselTank:removeFluid(amount) self.litres = self.litres - amount end
    local wortIn, bottled, firstBottleDay = 0, 0, nil
    local runsLeft = 2
    local vessel
    local function startRun()
        vessel = run(V.ALCOHOLIC_HOURS * 3600)
        V.onFermentStart(vessel)
        vessel.modData.place = place
        wortIn = wortIn + 20000
        runsLeft = runsLeft - 1
    end
    startRun()
    local guard = 0
    while guard < 24 * 400 do
        guard = guard + 1
        if not tick() then return nil, log end
        if vessel then
            V.onFermentUpdate(vessel)
            if vessel.elapsed >= V.ALCOHOLIC_HOURS * 3600 then
                local made = V.fermentedMl(20000, vessel.modData.heat)
                vesselTank.litres = vesselTank.litres + made / 1000
                note(string.format("vessel done: %.1f L fermented wort", made / 1000))
                vessel = nil
            end
        end
        V.updateCask(cask, ledger, place)
        -- The player pumps a whole batch across once the cask has room for it.
        local batch = math.floor(vesselTank.litres * 1000 + 0.5)
        local pumped = V.caskRoom(cask) >= batch and V.pumpToCask(cask, vesselTank, batch) or 0
        if pumped > 0 then
            note(string.format("hose pumped %.1f L, cask now %.1f L at %.0f%%", pumped / 1000, cask.ml / 1000, cask.strength * 100))
            if runsLeft > 0 and not vessel then startRun() end
        end
        if cask.strength >= 1 and cask.ml > BOTTLE_KEEP_ML + V.BOTTLE_ML then
            local count = 0
            while cask.ml - V.BOTTLE_ML >= BOTTLE_KEEP_ML and V.takeBottle(cask) do count = count + 1 end
            bottled = bottled + count
            firstBottleDay = firstBottleDay or (hour - (startIndex - 1) * 24) / 24
            note(string.format("bottled %d, %.1f L left as starter, mother layers %d", count, cask.ml / 1000, V.motherLayers(cask)))
            if runsLeft == 0 and not vessel and vesselTank.litres < 0.05 then break end
        end
    end
    local vinegar = bottled + cask.ml / 1000
    note(string.format("in: %.0f L wort -> out: %d bottles + %.1f L starter = %.1f L (%.0f%%)", wortIn / 1000, bottled, cask.ml / 1000, vinegar, vinegar / (wortIn / 1000) * 100))
    return firstBottleDay, log
end

local days = readDays(arg[1] or "tools/climate_year.csv")
local placeNames = { Open = "outdoors", Sheltered = "under a roof", Basement = "in a basement" }
for _, month in ipairs({ 1, 4, 7, 10 }) do
    local first
    for index, day in ipairs(days) do if day.month == month then first = index break end end
    for _, place in ipairs(V.PLACES) do
        local firstBottle, log = simulate(days, first, place)
        print(string.format("%s, %s: first bottles on day %s", MONTHS[month], placeNames[place], firstBottle and string.format("%.0f", firstBottle) or "(past the forecasts)"))
        for _, line in ipairs(log or {}) do print(line) end
    end
end
