-- Traditional Preservation (Vinegar): commands for the debug Lua console, loaded only in debug mode.
-- Type TPV.help() in the console for the list. See DEVHELP.md in the mod folder.
if not isDebugEnabled() then return end

require "TraditionalPreservationVinegarBottles"
local V = TraditionalPreservationVinegar
local Fire = require "TraditionalPreservationCore/Fire"
local Weather = require "TraditionalPreservationCore/Weather"
local FluidAgeing = require "TraditionalPreservationCore/FluidAgeing"
TPV = {}

local PROCESSES = { "malting", "alcoholic", "acetic", "wort" }
local ITEMS = { "SteepedGrain", "GreenMalt", "Malt", "BucketMash", "BucketPreparedMash", "SpentGrain", "MotherOfVinegar" }

local function say(text) print("[TPV] " .. text) end

local function near(test, label)
    local station = V.findNear(getPlayer(), test)
    if not station then say("No " .. label .. " within " .. V.REACH .. " squares of you.") end
    return station
end

function TPV.help()
    say("TPV.weather()             the temperature by place, and each stage's working speed there")
    say("TPV.here()                which place you're standing in (open air, an open roof, indoors, a basement, by a fire)")
    say("TPV.age(hours)            give every floor, vessel and cask this many hours of perfect weather")
    say("TPV.fast(hours)           test timers: every floor, vessel and cask run takes this many hours. TPV.fast() turns them off")
    say("TPV.timers()              the hours each stage takes right now")
    say("TPV.floor()               the nearest Malting Floor: each heap, how far on, and done Green Malt's age")
    say("TPV.cask()                the nearest cask: litres, souring, mother, layers, starter, hose")
    say("TPV.setCask(litres, pct)  set the nearest cask's pool, e.g. TPV.setCask(16, 100)")
    say("TPV.mother(layers)        give the nearest cask a mother with this many layers. TPV.mother(0) takes it away")
    say("TPV.vessel()              the nearest vessel: waiting wort and its age, the batch, fermented wort, hose")
    say("TPV.wort(litres)          fill the nearest vessel with wort (emptying it first)")
    say("TPV.batch(litres, pct, y) set the nearest vessel's batch, e.g. TPV.batch(18, 10); y \"underpitched\" or \"lag\". TPV.batch(0) takes it away")
    say("TPV.fermented(litres)     fill the nearest vessel with fermented wort (emptying it first)")
    say("TPV.ageWort(hours)        age the wort you carry and the nearest vessel's tank by hours at 20 C. TPV.ageWort(48) sours it")
    say("TPV.give(name, n)         spawn mod items. TPV.give() lists the names")
    say("TPV.kit(kind)             the things a test needs: \"build\" (all three stations), \"malt\", \"ferment\", \"cask\" or \"all\". TPV.kit() lists them")
    say("Stations must be within " .. V.REACH .. " squares. Right-click a container in debug mode to fill it with wort.")
end

function TPV.weather()
    local ledger = V.getLedger()
    say(string.format("Temperature now %.1f C, season (10-day average) %.1f C", ledger.temperature or 0, ledger.seasonTemperature or 0))
    for _, place in ipairs(V.PLACES) do
        local speeds = {}
        for _, process in ipairs(PROCESSES) do
            table.insert(speeds, string.format("%s %.0f%%", process, (ledger[process .. place .. "Rate"] or 0) * 100))
        end
        say(string.format("%-9s %.1f C: %s", place, V.placeTemperature(ledger, place), table.concat(speeds, ", ")))
    end
    for _, place in ipairs({ Fire.PLACE, Fire.EMBERS }) do
        local speeds = {}
        for _, process in ipairs(PROCESSES) do
            table.insert(speeds, string.format("%s %.0f%%", process, V[process .. "Rate"](Fire.fireC(place)) * 100))
        end
        say(string.format("%-9s %.1f C: %s (by the clock: TPV.age skips it)", place, Fire.fireC(place), table.concat(speeds, ", ")))
    end
end

function TPV.here()
    say("You're in: " .. tostring(V.placeOf(getPlayer())))
end

function TPV.age(hours)
    hours = hours or 24
    local ledger = V.getLedger()
    for _, process in ipairs(PROCESSES) do
        for _, place in ipairs(V.PLACES) do ledger[process .. place] = (ledger[process .. place] or 0) + hours end
    end
    say(string.format("Added %.0f hours of perfect weather. Stations update within a few seconds; a cask when you next look at it.", hours))
end

function TPV.fast(hours)
    V.TEST_HOURS = hours
    V.applyRecipeTimes()
    if hours then
        say(string.format("Test timers on: %s hours a run, temperature ignored, for heaps and batches already going too.", tostring(hours)))
    else
        say("Test timers off: back to the sandbox times.")
    end
end

function TPV.timers()
    say(string.format("Malting %.1f h, fermenting %.1f h, souring %.1f h, effort x%.1f, temperature sensitivity %.1f%s",
        V.MALTING_HOURS, V.ALCOHOLIC_HOURS, V.ACETIC_HOURS, V.EFFORT, V.SENSITIVITY, V.TEST_HOURS and " (test timers on)" or ""))
end

function TPV.floor()
    local floor = near(V.isFloor, "Malting Floor")
    if not floor then return end
    local now = getGameTime():getWorldAgeHours()
    local record, place = V.floorNow(floor, now)
    say(string.format("Floor at %d,%d,%d (%s): %d of %d heaps", floor:getX(), floor:getY(), floor:getZ(), tostring(place),
        #record.heaps, V.FLOOR_HEAPS))
    for _, heap in ipairs(record.heaps) do
        say(string.format("  heap %d: %s, %.0f%% (%.1f of %.0f h), Green Malt %.1f days old", heap.id, V.heapState(heap, now),
            V.heapProgress(heap) * 100, heap.work.age, V.MALTING_HOURS, V.heapAgeDays(heap, now)))
    end
end

function TPV.cask()
    local cask = near(V.isCask, "cask")
    if not cask then return end
    local caskModData = V.caskModData(cask)
    V.updateCaskAt(caskModData, V.getLedger(), cask)
    say(string.format("Cask at %d,%d,%d (%s): %.2f L, %.1f%% soured, %d bottles ready",
        cask:getX(), cask:getY(), cask:getZ(), V.placeOf(cask), caskModData.ml / 1000, caskModData.strength * 100, V.bottlesLeft(caskModData)))
    if caskModData.mother then
        say(string.format("Mother: %d layer(s), next in %.1f L, starter bonus %s", V.motherLayers(caskModData),
            V.nextLayerMl(caskModData) / 1000, V.hasStarter(caskModData) and "on" or "off"))
    else
        say("No mother.")
    end
    say("Hose: " .. (V.hoseLink(cask) and "connected" or "none"))
end

function TPV.setCask(litres, percent)
    local cask = near(V.isCask, "cask")
    if not cask then return end
    local caskModData = V.caskModData(cask)
    V.updateCaskAt(caskModData, V.getLedger(), cask)
    caskModData.ml = math.floor(math.min(litres or 0, V.CASK_ML / 1000) * 1000 + 0.5)
    caskModData.strength = math.max(0, math.min((percent or 100) / 100, 1))
    say(string.format("Cask set to %.2f L at %.0f%%.", caskModData.ml / 1000, caskModData.strength * 100))
end

function TPV.mother(layers)
    local cask = near(V.isCask, "cask")
    if not cask then return end
    local caskModData = V.caskModData(cask)
    if not layers or layers < 1 then
        V.takeMother(caskModData)
        return say("Mother removed.")
    end
    V.addMother(caskModData)
    caskModData.layers, caskModData.souredMl = layers, 0
    say("Mother set to " .. layers .. " layer(s).")
end

-- The nearest vessel brought up to now, and its record.
local function nearVessel()
    local vessel = near(V.isVessel, "vessel")
    if not vessel then return nil end
    return vessel, V.vesselNow(vessel)
end

function TPV.vessel()
    local vessel, record, place = nearVessel()
    if not vessel then return end
    local fluidAge = V.peekWort(record, getGameTime():getWorldAgeHours(), Weather.placeOf(vessel))
    say(string.format("Vessel at %d,%d,%d (%s): wort %.1f L%s, fermented %.1f L", vessel:getX(), vessel:getY(), vessel:getZ(),
        tostring(place), record.wortMl / 1000, fluidAge and string.format(" (%.0f of %d h to sour)", fluidAge.age, V.WORT_SOUR_HOURS) or "",
        record.fermentedMl / 1000))
    if record.run then
        say(string.format("Batch: %.1f L, %.0f%% (%.1f of %.0f h)", record.run.ml / 1000, V.runProgress(record.run) * 100,
            record.run.work.age, V.ALCOHOLIC_HOURS))
    else
        say("No batch.")
    end
    say("Hose: " .. (V.hoseLink(vessel) and "connected" or "none"))
end

-- Litres to whole millilitres, no more than most.
local function ml(litres, most)
    return math.floor(math.max(math.min(litres or most / 1000, most / 1000), 0) * 1000 + 0.5)
end

function TPV.wort(litres)
    local vessel, record = nearVessel()
    if not vessel then return end
    V.pourAwayWort(record)
    record.run, record.fermentedMl = nil, 0   -- one pool: the wort alone
    record.wortMl = ml(litres, V.TANK_ML)
    V.ageTank(record, record.wortMl, Weather.placeOf(vessel), getGameTime():getWorldAgeHours())
    say(string.format("Vessel set to %.1f L of wort, fresh.", record.wortMl / 1000))
end

function TPV.fermented(litres)
    local vessel, record = nearVessel()
    if not vessel then return end
    V.pourAwayWort(record)
    record.run = nil
    record.fermentedMl = ml(litres, V.TANK_ML)
    say(string.format("Vessel set to %.1f L of fermented wort.", record.fermentedMl / 1000))
end

-- A batch of this many litres this far on, as if pitched and worked; no yeast needed. yeast "underpitched" or "lag"
-- sets it as a top-up too big for a young batch would (a lag of a day from now).
function TPV.batch(litres, percent, yeast)
    local vessel, record, place = nearVessel()
    if not vessel then return end
    local batchMl = ml(litres, V.TANK_ML)
    if batchMl <= 0 then
        V.pourAwayBatch(record)
        return say("Batch taken away.")
    end
    local now = getGameTime():getWorldAgeHours()
    record.run = { ml = batchMl, overMl = math.max(batchMl - V.HEADSPACE_ML, 0),
        work = FluidAgeing.newFluidAge(V.FERMENT_WORK, V.getLedger(), now, place) }
    record.run.work.age = V.ALCOHOLIC_HOURS * math.max(math.min((percent or 0) / 100, 1), 0)
    V.pourAwayWort(record)
    record.fermentedMl = 0
    if yeast == "underpitched" then record.run.underpitched = true end
    if yeast == "lag" then record.run.lagUntil = now + V.LAG_HOURS end
    if TraditionalPreservationVinegarWorld then TraditionalPreservationVinegarWorld.refresh(vessel) end
    say(string.format("Batch set to %.1f L at %.0f%%%s.", batchMl / 1000, V.runProgress(record.run) * 100,
        yeast and (", " .. yeast) or ""))
end

-- Adds hours at 20 C to every wort fluidAge you carry and to the nearest vessel's tank, then renames what has soured.
function TPV.ageWort(hours)
    hours = hours or V.WORT_SOUR_HOURS
    local now, count = getGameTime():getWorldAgeHours(), 0
    local items = getPlayer():getInventory():getAllEvalRecurse(function(item) return item:getFluidContainer() ~= nil end)
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        local fluidAge = FluidAgeing.look(item, now)
        if fluidAge and fluidAge.process == V.WORT_PROCESS then
            fluidAge.age = fluidAge.age + hours
            FluidAgeing.look(item, now)
            count = count + 1
        end
    end
    local vessel = V.findNear(getPlayer(), V.isVessel)
    local tank = vessel and V.vesselNow(vessel, now)[FluidAgeing.KEY]
    if tank then tank.age = tank.age + hours end
    say(string.format("Aged %d carried container(s)%s by %.0f hours at 20 C.", count, tank and " and the vessel's tank" or "", hours))
end

function TPV.give(name, count)
    if not name then return say("Items: " .. table.concat(ITEMS, ", ") .. ", plus any full type such as Base.Yeast or Base.RubberHose") end
    local fullType = name:find("%.") and name or "TraditionalPreservationVinegar." .. name
    local inventory = getPlayer():getInventory()
    for _ = 1, count or 1 do inventory:AddItem(fullType) end
    say(string.format("Gave %d %s.", count or 1, fullType))
end

-- A container of this type, filled to the brim with the fluid.
local function addFilled(inventory, fullType, fluid)
    local container = inventory:AddItem(fullType):getFluidContainer()
    container:Empty()
    container:addFluid(fluid, container:getCapacity())
end

local function addEmpty(inventory, fullType, count)
    for _ = 1, count do
        inventory:AddItem(fullType):getFluidContainer():Empty()
    end
end

local function addItems(inventory, counts)
    for fullType, count in pairs(counts) do
        for _ = 1, count do inventory:AddItem(fullType) end
    end
end

-- One kit per part of the chain, each enough on its own; "all" is every kit.
local KITS = {
    build = {
        about = "a hammer, a saw, 24 planks, 36 nails, 10 twine, a jar and ripped sheets, to build the Malting Floor "
            .. "(Woodwork 2), the Fermentation Vessel (Woodwork 3) and the Vinegar Cask (Woodwork 4)",
        give = function(inventory)
            addItems(inventory, { ["Base.Hammer"] = 1, ["Base.Saw"] = 1, ["Base.Plank"] = 24, ["Base.Nails"] = 36,
                ["Base.Twine"] = 10, ["Base.EmptyJar"] = 1, ["Base.RippedSheets"] = 1 })
        end,
    },
    malt = {
        about = "24 barley seeds and a bucket of water to steep them, an empty bucket for the mash and ripped sheets "
            .. "to strain it",
        give = function(inventory)
            addItems(inventory, { ["Base.BarleySeed"] = 24, ["Base.RippedSheets"] = 1 })
            addFilled(inventory, "Base.BucketEmpty", "Water")
            addEmpty(inventory, "Base.BucketEmpty", 1)
        end,
    },
    ferment = {
        about = "2 buckets of wort and 2 yeast, for the vessel (pitch on one, top up with the other) and an empty bucket "
            .. "to draw off",
        give = function(inventory)
            addItems(inventory, { ["Base.Yeast"] = 2 })
            addFilled(inventory, "Base.BucketEmpty", V.WORT)
            addFilled(inventory, "Base.BucketEmpty", V.WORT)
            addEmpty(inventory, "Base.BucketEmpty", 1)
        end,
    },
    cask = {
        about = "a rubber hose and pliers, a Mother of Vinegar, an empty jar and 3 empty Crafted Bottles; "
            .. "TPV.setCask(16, 100) fills the nearest cask",
        give = function(inventory)
            addItems(inventory, { [V.HOSE_ITEM] = 1, ["Base.Pliers"] = 1, [V.MOTHER_ITEM] = 1, ["Base.EmptyJar"] = 1 })
            addEmpty(inventory, V.SPARE_BOTTLE, 3)
        end,
    },
}

local KIT_NAMES = {}
for name in pairs(KITS) do table.insert(KIT_NAMES, name) end
table.sort(KIT_NAMES)

local PARTS = { unpack(KIT_NAMES) }
KITS.all = {
    about = "every kit (" .. table.concat(PARTS, ", ") .. ")",
    give = function(inventory)
        for _, name in ipairs(PARTS) do KITS[name].give(inventory) end
    end,
}
table.insert(KIT_NAMES, 1, "all")

function TPV.kit(kind)
    local kit = KITS[kind]
    if not kit then
        for _, name in ipairs(KIT_NAMES) do say("TPV.kit(\"" .. name .. "\"): " .. KITS[name].about) end
        return
    end
    kit.give(getPlayer():getInventory())
    say("Gave " .. kit.about .. ".")
end

say("Debug commands loaded. Type TPV.help() in the Lua console.")
