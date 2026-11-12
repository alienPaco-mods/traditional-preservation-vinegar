-- Shows how a batch goes through the year, from forecasts read from the real game.
-- Run from the mod folder: luajit tools/season_report.lua [path/to/climate.csv]
-- Each line of the file: world month offset tempMin tempMean tempMax humMin humMean humMax rainy snowy
ModData = { getOrCreate = function() return {} end }
Events = { OnInitGlobalModData = { Add = function() end } }
dofile((os.getenv("TPCORE") or "../TraditionalPreservationCore") .. "/tests/harness.lua").useModPaths()
dofile("42/media/lua/shared/TraditionalPreservationVinegar.lua")
local V = TraditionalPreservationVinegar
local Weather = require "TraditionalPreservationCore/Weather"

local MONTHS = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }

local function readDays(path)
    local days = {}
    for line in io.lines(path) do
        local f = {}
        for value in line:gmatch("%S+") do table.insert(f, value) end
        -- Each month's forecast also holds the 10 days before it (offset below 0): skipped, so a month is 30 days.
        if #f >= 6 and tonumber(f[3]) >= 0 then
            table.insert(days, { world = tonumber(f[1]), offset = tonumber(f[3]), month = tonumber(f[2]), low = tonumber(f[4]), mean = tonumber(f[5]), high = tonumber(f[6]) })
        end
    end
    return days
end

-- The day's hours, coldest before dawn and warmest mid-afternoon.
local function hourly(day, hour)
    local swing = math.cos((hour - 15) / 24 * 2 * math.pi)
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

-- Days until a batch started on this day is done, or nil if the forecasts run out first.
local function daysToFinish(days, first, target, rate, place)
    local season, ground = settled(days[first].month, days[first].offset)
    local done = 0
    for index = first, #days do
        for hour = 0, 23 do
            local temperature = hourly(days[index], hour)
            season = season + (temperature - season) / Weather.SEASON_HOURS
            ground = ground + (season - ground) / Weather.GROUND_HOURS
            done = done + rate(Weather.placeTemperature({ temperature = temperature, seasonTemperature = season,
                groundTemperature = ground }, place))
            if done >= target then return index - first + hour / 24 end
        end
    end
    return nil
end

local function range(days, month, target, rate, place)
    local low, high
    for index, day in ipairs(days) do
        if day.month == month then
            local taken = daysToFinish(days, index, target, rate, place)
            if taken then
                low, high = math.min(low or taken, taken), math.max(high or taken, taken)
            end
        end
    end
    if not low then return "" end
    return string.format("%.0f-%.0f", low, high)
end

local days = readDays(arg[1] or "tools/climate_year.csv")
settled = settle(days)
-- Indoors and under an open roof read the same (the season's mean), so one column serves both.
local PLACES = { "Open", "Sheltered", "Loft", "Basement" }
print("| Month | Ferment, outdoors | Ferment, indoors | Ferment, loft | Ferment, basement | First cask, outdoors | First cask, indoors | First cask, loft | First cask, basement |")
print("|---|---|---|---|---|---|---|---|---|")
for month = 1, 12 do
    local cells = { MONTHS[month] }
    for _, place in ipairs(PLACES) do table.insert(cells, range(days, month, V.ALCOHOLIC_HOURS, V.alcoholicRate, place)) end
    for _, place in ipairs(PLACES) do table.insert(cells, range(days, month, V.ACETIC_HOURS, V.aceticRate, place)) end
    print("| " .. table.concat(cells, " | ") .. " |")
end
-- By a fire the temperature holds while the fuel lasts, whatever the month.
local Hearth = require "TraditionalPreservationCore/Hearth"
print("")
for _, place in ipairs({ Hearth.PLACE, Hearth.EMBERS }) do
    local celsius = Hearth.fireC(place)
    print(string.format("%s (%d C), any month: malting %.1f days, ferment %.1f, first cask %.1f", place, celsius,
        V.MALTING_HOURS / V.maltingRate(celsius) / 24, V.ALCOHOLIC_HOURS / V.alcoholicRate(celsius) / 24,
        V.ACETIC_HOURS / V.aceticRate(celsius) / 24))
end
