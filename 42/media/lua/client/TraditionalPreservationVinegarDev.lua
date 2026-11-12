-- Traditional Preservation (Vinegar): commands for the debug Lua console, loaded only in debug mode.
-- Type TPV.help() in the console for the list. See DEVHELP.md in the mod folder.
if not isDebugEnabled() then return end

local V = TraditionalPreservationVinegar
local Hearth = require "TraditionalPreservationCore/Hearth"
TPV = {}

local KINDS = { "malting", "alcoholic", "acetic" }
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
    say("TPV.cask()                the nearest cask: litres, souring, mother, layers, starter, hose")
    say("TPV.setCask(litres, pct)  set the nearest cask's pool, e.g. TPV.setCask(16, 100)")
    say("TPV.mother(layers)        give the nearest cask a mother with this many layers. TPV.mother(0) takes it away")
    say("TPV.wort(litres)          fill the nearest vessel's Wort tank")
    say("TPV.fermented(litres)     fill the nearest vessel's Fermented tank")
    say("TPV.give(name, n)         spawn mod items. TPV.give() lists the names")
    say("Stations must be within " .. V.REACH .. " squares. Right-click a container in debug mode to fill it with wort.")
end

function TPV.weather()
    local ledger = V.getLedger()
    say(string.format("Temperature now %.1f C, season (10-day average) %.1f C", ledger.temperature or 0, ledger.seasonTemperature or 0))
    for _, place in ipairs(V.PLACES) do
        local speeds = {}
        for _, kind in ipairs(KINDS) do
            table.insert(speeds, string.format("%s %.0f%%", kind, (ledger[kind .. place .. "Rate"] or 0) * 100))
        end
        say(string.format("%-9s %.1f C: %s", place, V.placeTemperature(ledger, place), table.concat(speeds, ", ")))
    end
    for _, place in ipairs({ Hearth.PLACE, Hearth.EMBERS }) do
        local speeds = {}
        for _, kind in ipairs(KINDS) do
            table.insert(speeds, string.format("%s %.0f%%", kind, V[kind .. "Rate"](Hearth.fireC(place)) * 100))
        end
        say(string.format("%-9s %.1f C: %s (by the clock: TPV.age skips it)", place, Hearth.fireC(place), table.concat(speeds, ", ")))
    end
end

function TPV.here()
    say("You're in: " .. tostring(V.placeOf(getPlayer())))
end

function TPV.age(hours)
    hours = hours or 24
    local ledger = V.getLedger()
    for _, kind in ipairs(KINDS) do
        for _, place in ipairs(V.PLACES) do ledger[kind .. place] = (ledger[kind .. place] or 0) + hours end
    end
    say(string.format("Added %.0f hours of perfect weather. Stations update within a few seconds; a cask when you next look at it.", hours))
end

function TPV.fast(hours)
    V.TEST_HOURS = hours
    V.applyRecipeTimes()
    if hours then
        say(string.format("Test timers on: %s hours a run, temperature ignored. Runs already going keep their old recipe time in the window.", tostring(hours)))
    else
        say("Test timers off: back to the sandbox times.")
    end
end

function TPV.timers()
    say(string.format("Malting %.1f h, fermenting %.1f h, souring %.1f h, effort x%.1f, temperature sensitivity %.1f%s",
        V.MALTING_HOURS, V.ALCOHOLIC_HOURS, V.ACETIC_HOURS, V.EFFORT, V.SENSITIVITY, V.TEST_HOURS and " (test timers on)" or ""))
end

function TPV.cask()
    local cask = near(V.isCask, "cask")
    if not cask then return end
    local state = V.caskState(cask)
    V.updateCaskAt(state, V.getLedger(), cask)
    say(string.format("Cask at %d,%d,%d (%s): %.2f L, %.1f%% soured, %d bottles ready",
        cask:getX(), cask:getY(), cask:getZ(), V.placeOf(cask), state.ml / 1000, state.strength * 100, V.bottlesLeft(state)))
    if state.mother then
        say(string.format("Mother: %d layer(s), next in %.1f L, starter bonus %s", V.motherLayers(state),
            V.nextLayerMl(state) / 1000, V.hasStarter(state) and "on" or "off"))
    else
        say("No mother.")
    end
    say("Hose: " .. (V.hoseLink(cask) and "connected" or "none"))
end

function TPV.setCask(litres, percent)
    local cask = near(V.isCask, "cask")
    if not cask then return end
    local state = V.caskState(cask)
    V.updateCaskAt(state, V.getLedger(), cask)
    state.ml = math.floor(math.min(litres or 0, V.CASK_ML / 1000) * 1000 + 0.5)
    state.strength = math.max(0, math.min((percent or 100) / 100, 1))
    say(string.format("Cask set to %.2f L at %.0f%%.", state.ml / 1000, state.strength * 100))
end

function TPV.mother(layers)
    local cask = near(V.isCask, "cask")
    if not cask then return end
    local state = V.caskState(cask)
    if not layers or layers < 1 then
        V.takeMother(state)
        return say("Mother removed.")
    end
    V.addMother(state)
    state.layers, state.souredMl = layers, 0
    say("Mother set to " .. layers .. " layer(s).")
end

local function fillTank(io, fluid, litres, label)
    local vessel = near(V.isVessel, "vessel")
    if not vessel then return end
    local container = V.vesselTank(vessel, io):getFluidContainer()
    container:Empty()
    container:addFluid(fluid, math.min(litres or container:getCapacity(), container:getCapacity()))
    say(string.format("%s tank filled with %.1f L.", label, container:getAmount()))
end

function TPV.wort(litres) fillTank(ResourceIO.Input, V.WORT, litres, "Wort") end
function TPV.fermented(litres) fillTank(ResourceIO.Output, V.FERMENTED, litres, "Fermented") end

function TPV.give(name, count)
    if not name then return say("Items: " .. table.concat(ITEMS, ", ") .. ", plus any full type such as Base.Yeast or Base.RubberHose") end
    local fullType = name:find("%.") and name or "TraditionalPreservationVinegar." .. name
    local inventory = getPlayer():getInventory()
    for _ = 1, count or 1 do inventory:AddItem(fullType) end
    say(string.format("Gave %d %s.", count or 1, fullType))
end

say("Debug commands loaded. Type TPV.help() in the Lua console.")
