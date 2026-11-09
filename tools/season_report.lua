-- Shows how a batch goes through the year, from forecasts read from the real game.
-- Run from the mod folder: luajit tools/season_report.lua [path/to/climate.csv]
-- Each line of the file: world month offset tempMin tempMean tempMax humMin humMean humMax rainy snowy
ModData = { getOrCreate = function() return {} end }
Events = { OnInitGlobalModData = { Add = function() end } }
dofile((os.getenv("TPCORE") or "../_tpcore") .. "/tests/harness.lua").useModPaths()
dofile("42/media/lua/shared/TraditionalPreservationVinegar.lua")
local V = TraditionalPreservationVinegar

local MONTHS = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }

local function readDays(path)
    local days = {}
    for line in io.lines(path) do
        local f = {}
        for value in line:gmatch("%S+") do table.insert(f, value) end
        if #f >= 6 then
            table.insert(days, { month = tonumber(f[2]), low = tonumber(f[4]), mean = tonumber(f[5]), high = tonumber(f[6]) })
        end
    end
    return days
end

-- The day's hours, coldest before dawn and warmest mid-afternoon.
local function hourly(day, hour)
    local swing = math.cos((hour - 15) / 24 * 2 * math.pi)
    return swing >= 0 and day.mean + (day.high - day.mean) * swing or day.mean + (day.mean - day.low) * swing
end

-- Days until a batch started on this day is done, or nil if the forecasts run out first.
local function daysToFinish(days, first, target, rate, sheltered)
    local done, season = 0, days[first].mean
    for index = first, #days do
        for hour = 0, 23 do
            local temperature = hourly(days[index], hour)
            season = season + (temperature - season) / V.SEASON_HOURS
            done = done + rate(sheltered and V.shelterTemperature(season) or temperature)
            if done >= target then return index - first + hour / 24 end
        end
    end
    return nil
end

local function range(days, month, target, rate, sheltered)
    local low, high
    for index, day in ipairs(days) do
        if day.month == month then
            local taken = daysToFinish(days, index, target, rate, sheltered)
            if taken then
                low, high = math.min(low or taken, taken), math.max(high or taken, taken)
            end
        end
    end
    if not low then return "" end
    return string.format("%.0f-%.0f", low, high)
end

local days = readDays(arg[1] or "tools/climate_year.csv")
print("| Month | Ferment, outdoors | Ferment, indoors | First cask, outdoors | First cask, indoors |")
print("|---|---|---|---|---|")
for month = 1, 12 do
    print(string.format("| %s | %s | %s | %s | %s |", MONTHS[month],
        range(days, month, V.ALCOHOLIC_HOURS, V.alcoholicRate, false), range(days, month, V.ALCOHOLIC_HOURS, V.alcoholicRate, true),
        range(days, month, V.ACETIC_HOURS, V.aceticRate, false), range(days, month, V.ACETIC_HOURS, V.aceticRate, true)))
end
