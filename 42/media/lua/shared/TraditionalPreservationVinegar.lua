-- Traditional Preservation (Vinegar): the fermentation rules shared by the recipes, the world and the menus.
-- Weather is the same everywhere, so running totals in global ModData tell every vessel and cask
-- how much work they have done, including while their chunk was unloaded.
TraditionalPreservationVinegar = TraditionalPreservationVinegar or {}
local V = TraditionalPreservationVinegar
local Weather = require "TraditionalPreservationCore/Weather"
local Fire = require "TraditionalPreservationCore/Fire"
local StoneHearth = require "TraditionalPreservationCore/StoneHearth"
local Station = require "TraditionalPreservationCore/Station"
local Container = require "TraditionalPreservationCore/Container"
local FluidAgeing = require "TraditionalPreservationCore/FluidAgeing"
local Tiles = require "TraditionalPreservationVinegar/Tiles"

V.MOD_DATA_KEY = "TraditionalPreservationVinegar"
V.SPRITE_PREFIX = Tiles.PREFIX

-- The mash is heated in its bucket on the hob (Core's Stone Hearth sets its pot in the hole for it).
StoneHearth.cooksOn(StoneHearth.STOVE, "TraditionalPreservationVinegar.BucketMash")

-- Tile numbers, from the Tiles.lua that tools/build_tileset.py writes. Each sprite is the east facing,
-- and the next one is the south facing.
local OVERLAYS = Tiles.OVERLAYS
V.VESSEL_SPRITE, V.CASK_SPRITE, V.FLOOR_SPRITE = Tiles.VESSEL, Tiles.CASK, Tiles.FLOOR
V.VESSEL_FILLED, V.VESSEL_BUBBLING = OVERLAYS.vessel.filled, OVERLAYS.vessel.bubbling
V.VESSEL_SEDIMENT, V.VESSEL_FINISHED = OVERLAYS.vessel.sediment, OVERLAYS.vessel.finished
V.CASK_FILLED, V.CASK_FILM = OVERLAYS.cask.filled, { OVERLAYS.cask.film1, OVERLAYS.cask.film2, OVERLAYS.cask.film3 }
V.CASK_FINISHED, V.CASK_MOTHER = OVERLAYS.cask.finished, OVERLAYS.cask.mother
V.FLOOR_STEEPED, V.FLOOR_SPROUTING = OVERLAYS.floor.steeped, OVERLAYS.floor.sprouting
V.FLOOR_ROOTLETS, V.FLOOR_FINISHED = OVERLAYS.floor.rootlets, OVERLAYS.floor.finished
-- Drawn over either station while a hose joins them.
V.VESSEL_HOSE, V.CASK_HOSE = Tiles.HOSE.vessel, Tiles.HOSE.cask
V.FACE_COUNT = Tiles.FACE_COUNT

-- Hours at a rate of 1 for each stage; the sandbox can replace them.
V.MALTING_HOURS = 120
V.ALCOHOLIC_HOURS = 240
V.ACETIC_HOURS = 840
-- For testing: set this to run every batch in that many hours, whatever the sandbox and weather say.
V.TEST_HOURS = nil
-- An established mother takes this share off the cask's time.
V.CULTURE_BONUS = 0.25
-- Light, Normal, Hard: how much longer the hands-on work takes than Light. The base times are the
-- scripts' own (cooking minutes and craft action times).
V.EFFORT_SCALES = { 1, 1.5, 2 }
V.EFFORT = 1.5
local COOK_MINUTES = { ["TraditionalPreservationVinegar.GreenMalt"] = 120, ["TraditionalPreservationVinegar.BucketMash"] = 60 }
local CRAFT_TIMES = { SteepGrain = 120, MashMalt = 300, StrainMash = 200 }
V.SENSITIVITY = 1
V.MIN_RATE = 0.02
-- Wort and vinegar freeze below water, as their alcohol and acid keep them liquid a little longer: the vessel and
-- the cask pause at this, the malting floor's wet grain at 0 C.
V.FREEZE_C = -3

-- All volumes are whole millilitres, so bottling can't drift.
-- The vanilla jarring recipe takes 2 uses of vinegar for a 1 L jar, and a real jar takes about
-- 0.2 L, so a use is 0.1 L and a bottle of 10 uses is 1 L. Vanilla bottles hold 1 L too.
V.BOTTLE_ML = 1000
V.WORT = "MaltWort"
V.FERMENTED = "MaltFermentedWort"
-- Wort left waiting for the yeast sours: lactic bacteria from the grain get there first. It goes by this name
-- once it has, and the vessel won't take it. Hours against 20 C; WORT_CURVE scales them by the place.
V.SOUR_WORT = "MaltSourWort"
V.WORT_PROCESS = "wort"
V.WORT_SOUR_HOURS = 48
V.WORT_SOURS = true
-- A vessel run takes whole buckets of wort from its tank, one or two, and leaves 5% behind as lees.
V.BUCKET_ML = 10000
V.FERMENT_YIELD = 0.95

-- The cask is one continuous pool, as in the Orleans method. It holds 30 L, but the culture needs
-- air above the liquid, so past three quarters full it slows, down to this share when brimming.
V.CASK_ML = 30000
V.AIR_ML = 22500
V.CROWDED_RATE = 0.5
-- Souring from nothing to full strength loses this share of the liquid to the air.
V.ACETIC_LOSS = 0.1
-- The mother only speeds a cask that still has this much sour vinegar in it as a starter.
V.STARTER_STRENGTH = 0.25
-- A mother grows a new layer for about every full batch it sours, and one with two or more can be split.
V.MOTHER_LAYER_ML = 15000
V.MOTHER_ITEM = "TraditionalPreservationVinegar.MotherOfVinegar"
-- Long gaps are worked through in steps this big, as the speed changes on the way.
local SOUR_STEP = 0.02

-- Skill XP, on vanilla's scale, where most cooking crafts give 3. Station runs pay out when they
-- finish, so cancelling and restarting can't farm it.
V.BOTTLE_XP = 1
V.FERMENT_XP = 10
V.MALTING_XP = 5

-- A hose joins a vessel to a cask this many squares away or less, on the same floor.
V.HOSE_ITEM = "Base.RubberHose"
V.HOSE_REACH = 2

-- How many squares away a cask can be for bottling, pouring or moving its mother.
V.REACH = 2
-- Pouring or pumping takes no longer past this many litres.
V.POUR_MOST_LITRES = 20

local RECIPE_MODULE = "TraditionalPreservationVinegar."

local function lerp(from, to, amount)
    return from + (to - from) * amount
end

-- Below 10 C barely works, slower to 18, best to 25, active to 30, then falling away.
local ALCOHOLIC_CURVE = { { 9.9, 0.05 }, { 10, 0.35 }, { 18, 1 }, { 25, 1 }, { 30, 0.85 }, { 35, 0.4 }, { 40, 0.1 } }
-- Below 10 C barely works, slower to 20, best to 30, then falling away.
local ACETIC_CURVE = { { 9.9, 0.05 }, { 10, 0.3 }, { 20, 1 }, { 30, 1 }, { 35, 0.6 }, { 40, 0.25 } }

-- Souring speed against 20 C: 2 days there, 1 at 30 C, about 5 in a summer cellar (13 C), two weeks in a winter
-- one; frozen it waits. Past 40 C the heat starts to kill the bacteria.
local WORT_CURVE = { { 0, 0 }, { 5, 0.15 }, { 13, 0.4 }, { 20, 1 }, { 30, 2 }, { 40, 2 }, { 50, 0.5 }, { 60, 0 } }

-- Sprouting grain likes it cool: best from 12 to 20 C, and it stalls in frost or heat.
local MALTING_CURVE = { { 4.9, 0.05 }, { 5, 0.3 }, { 12, 1 }, { 20, 1 }, { 28, 0.35 }, { 33, 0.05 } }

-- Each stage's speed at a temperature, 0 to 1, after the sandbox's sensitivity. Frozen a stage pauses (TP Core's
-- Weather.frozen); the floor holds above freezing only.
function V.maltingRate(celsius)
    return Weather.rate(MALTING_CURVE, celsius, V.SENSITIVITY, V.MIN_RATE)
end

function V.alcoholicRate(celsius)
    return Weather.rate(ALCOHOLIC_CURVE, celsius, V.SENSITIVITY, V.MIN_RATE, V.FREEZE_C)
end

function V.aceticRate(celsius)
    return Weather.rate(ACETIC_CURVE, celsius, V.SENSITIVITY, V.MIN_RATE, V.FREEZE_C)
end

-- Not scaled by the sensitivity: that setting is for the brewer's own stages.
function V.wortRate(celsius)
    return Weather.curve(WORT_CURVE, celsius)
end

-- Places and their temperatures are shared with the other Traditional Preservation mods (TP Core's Weather):
-- open air, an open roof, indoors, a basement, and by a fire or by banked embers (TP Core's Fire). These are the
-- mod's public names, used by the actions, the Dev console and the tools. PLACES are the weather's, which the
-- ledger keeps totals for; by a fire counts by the clock.
V.PLACES = Weather.PLACES
V.placeOf = Fire.placeOf
V.placeTemperature = Weather.placeTemperature

-- Ledger keys are kind .. place ("aceticBasement"), as in every save so far.
local PROCESSES = {
    malting = V.maltingRate,
    alcoholic = V.alcoholicRate,
    acetic = V.aceticRate,
    [V.WORT_PROCESS] = V.wortRate,
}

-- One total per stage and place.
function V.newLedger(now)
    return Weather.newLedger(now, PROCESSES)
end

-- Adds one stretch of weather to the totals.
function V.advance(ledger, now, temperature)
    Weather.advance(ledger, now, temperature, PROCESSES)
end

-- Filled once on OnInitGlobalModData (fillLedger), so this is a plain lookup.
function V.getLedger()
    return Weather.getLedger(V.MOD_DATA_KEY, V.newLedger)
end

-- A ledger saved before a kind or place was added has no totals for it. Filled once as the save loads,
-- not on every getLedger: running batches, casks and popups ask for it many times a second.
function V.fillLedger()
    Weather.fillLedger(V.getLedger(), PROCESSES)
end

Events.OnInitGlobalModData.Add(V.fillLedger)

-- Wort in a bucket or any container ages through TP Core's FluidAgeing, as Dairy's milk does. It has one stage
-- only: Wort (Soured) is both its turned and its spoiled fluid. Fermented wort is not registered, so it keeps.
V.WORT_FLUID_KIND = FluidAgeing.register({
    process = V.WORT_PROCESS,
    rate = V.wortRate,
    turnHours = V.WORT_SOUR_HOURS,
    spoilHours = V.WORT_SOUR_HOURS,
    fresh = { [V.WORT] = V.SOUR_WORT },
    spoiled = { [V.WORT] = V.SOUR_WORT },
    getLedger = function() return V.getLedger() end,
    enabled = function() return V.WORT_SOURS end,
})

-- The bucket becomes the mash. Its kind (plain or forged) is noted on it, and heating carries the note over
-- (see the core's Container).
function V.onMashed(craftRecipeData)
    Container.note(craftRecipeData, "TraditionalPreservationVinegar.BucketMash")
end

-- Strain Mash gives back the bucket that went in (the script's output is a plain one), and this pours a bucket of
-- wort into it.
V.STRAINED_BUCKET = "Base.BucketEmpty"

function V.onStrained(craftRecipeData, character)
    local bucket = Container.giveBack(craftRecipeData, character, V.STRAINED_BUCKET)
    local container = bucket and bucket:getFluidContainer()
    if container then
        container:Empty()
        -- New wort starts its own age, whatever the bucket held before.
        bucket:getModData()[FluidAgeing.KEY] = nil
        container:addFluid(V.WORT, math.min(V.BUCKET_ML / 1000, container:getCapacity()))
    end
end

-- What a run of this much wort gives back, after the lees.
function V.fermentedMl(wortMl)
    return math.floor(wortMl * V.FERMENT_YIELD + 0.5)
end

-- True when a container holds only the named fluid.
function V.holdsOnly(container, name)
    return Container.fluidIn(container) == name
end

function V.spriteName(index)
    return V.SPRITE_PREFIX .. index
end

-- Each station has FACE_COUNT tiles from its base, one per facing.
V.STATION_SPRITES = { cask = V.CASK_SPRITE, vessel = V.VESSEL_SPRITE, floor = V.FLOOR_SPRITE }

-- Which station this is ("cask", "vessel" or "floor") and which way it faces, or nil for anything else.
V.stationKind = Station.kinds(V.SPRITE_PREFIX, V.FACE_COUNT, V.STATION_SPRITES)

function V.isCask(isoObject)
    return V.stationKind(isoObject) == "cask"
end

function V.isVessel(isoObject)
    return V.stationKind(isoObject) == "vessel"
end

function V.isFloor(isoObject)
    return V.stationKind(isoObject) == "floor"
end

-- The Wort tank is the vessel's record, not an item, so FluidAgeing can't keep a fluidAge on it: the fluidAge sits on
-- the record under FluidAgeing's key instead. Brings it up to now at place, starting one for wort that
-- has none, and forgets it once the tank is empty. Returns the fluidAge, or nil with no wort or souring off.
function V.ageTank(modData, ml, place, now)
    local key = FluidAgeing.KEY
    if ml <= 0 or not V.WORT_SOURS then
        modData[key] = nil
        return nil
    end
    local ledger, fluidAge = V.getLedger(), modData[key]
    if not fluidAge or fluidAge.process ~= V.WORT_PROCESS then
        fluidAge = FluidAgeing.newFluidAge(V.WORT_FLUID_KIND, ledger, now, place)
        modData[key] = fluidAge
        return fluidAge
    end
    return FluidAgeing.advance(fluidAge, V.WORT_FLUID_KIND, ledger, now, place)
end

function V.isSour(fluidAge)
    return fluidAge ~= nil and FluidAgeing.stage(fluidAge, V.WORT_FLUID_KIND) ~= "Fresh"
end

-- Hours until a fluidAge sours at a temperature, or nil when it has or won't there (frozen).
function V.hoursToSour(fluidAge, celsius)
    local left, rate = FluidAgeing.hoursLeft(fluidAge, V.WORT_FLUID_KIND), V.wortRate(celsius)
    if not left or V.isSour(fluidAge) or rate <= 0 then return nil end
    return left / rate
end

-- The cask's own modData. It sits in movableData because vanilla copies that onto the item when a
-- station is picked up and back when it is placed, so the pool and the mother move with the cask,
-- and there is only ever one of each.
function V.caskModData(cask)
    local caskModData = Station.movableData(cask)
    caskModData.ml = caskModData.ml or 0
    caskModData.strength = caskModData.strength or 0
    return caskModData
end

-- Millilitres the cask can still take.
function V.caskRoom(caskModData)
    return math.max(V.CASK_ML - caskModData.ml, 0)
end

-- New fermented wort has no acid, so it thins the pool's strength by its share.
function V.pourIntoCask(caskModData, ml)
    ml = math.min(ml, V.caskRoom(caskModData))
    if ml <= 0 then return 0 end
    caskModData.strength = caskModData.strength * caskModData.ml / (caskModData.ml + ml)
    caskModData.ml = caskModData.ml + ml
    return ml
end

-- A cask souring with air above it works best: full speed up to AIR_ML, slowing to CROWDED_RATE full.
function V.airShare(ml)
    if ml <= V.AIR_ML then return 1 end
    return lerp(1, V.CROWDED_RATE, math.min((ml - V.AIR_ML) / (V.CASK_ML - V.AIR_ML), 1))
end

-- A mother in vinegar at least STARTER_STRENGTH makes the pool sour faster (CULTURE_BONUS).
function V.hasStarter(caskModData)
    return caskModData.mother and caskModData.strength >= V.STARTER_STRENGTH
end

-- How fast this pool sours compared with a plain one, before temperature.
function V.caskSpeed(caskModData)
    local culture = V.hasStarter(caskModData) and 1 / (1 - V.CULTURE_BONUS) or 1
    return culture * V.airShare(caskModData.ml)
end

-- Spends rateHours of weather on the pool. A pool that reaches full strength grows a mother.
function V.sour(caskModData, rateHours)
    while rateHours > 0 and caskModData.ml > 0 and caskModData.strength < 1 do
        local perHour = V.caskSpeed(caskModData) / V.ACETIC_HOURS
        local gain = math.min(rateHours * perHour, SOUR_STEP, 1 - caskModData.strength)
        if gain <= 0 then break end
        rateHours = rateHours - gain / perHour
        caskModData.strength = caskModData.strength + gain
        if caskModData.mother then V.growMother(caskModData, caskModData.ml * gain) end
        caskModData.ml = caskModData.ml - caskModData.ml * V.ACETIC_LOSS * gain
        if caskModData.strength >= 1 - 1e-6 then
            caskModData.strength = 1
            if not caskModData.mother then V.addMother(caskModData) end
        end
    end
end

-- Brings a cask up to date with the weather since it was last seen, at place (by a fire by the clock, until the
-- fuel noted in caskModData ran out): its souring, and its mother's frost (V.caskFrost) up to now (default the
-- game's hour).
function V.updateCask(caskModData, ledger, place, now)
    if caskModData.marks then
        V.sour(caskModData, Fire.catchUp(caskModData, caskModData.marks, ledger, "acetic", place, V.aceticRate))
    else
        caskModData.marks = Weather.mark({}, ledger, "acetic")
    end
    V.caskFrost(caskModData, now or getGameTime():getWorldAgeHours(), place)
end

-- Brings a cask up to date where it stands: a move first catches it up where it was (caskModData.place). Returns the
-- place.
function V.updateCaskAt(caskModData, ledger, cask)
    local now = getGameTime():getWorldAgeHours()
    local place = Fire.notePlace(caskModData, cask, now, function(was) V.updateCask(was, ledger, was.place, now) end)
    V.updateCask(caskModData, ledger, place, now)
    return place
end

-- For the menus. hoursLeft is to fully soured and assumes the temperature holds; nil while frozen.
function V.caskStatus(caskModData, ledger, place)
    local temperature = Weather.placeTemperature(ledger, place)
    local rate = V.aceticRate(temperature)
    return {
        temperature = temperature,
        place = place,
        rate = rate,
        hoursLeft = rate > 0 and (1 - caskModData.strength) * V.ACETIC_HOURS / (V.caskSpeed(caskModData) * rate) or nil,
    }
end

-- Only full-strength vinegar is drawn off.
function V.bottlesLeft(caskModData)
    if caskModData.strength < 1 then return 0 end
    return math.floor(caskModData.ml / V.BOTTLE_ML)
end

-- What is left after the last whole bottle stays as starter for the next fill.
function V.takeBottle(caskModData)
    if V.bottlesLeft(caskModData) < 1 then return false end
    caskModData.ml = caskModData.ml - V.BOTTLE_ML
    return true
end

-- Pouring a cask out leaves the mother in it.
function V.emptyCask(caskModData)
    caskModData.ml, caskModData.strength = 0, 0
end

-- 0 without a mother.
function V.motherLayers(caskModData)
    return caskModData.mother and (caskModData.layers or 1) or 0
end

-- Every litre the pool sours feeds the mother, and it thickens a layer at a time.
function V.growMother(caskModData, souredMl)
    caskModData.souredMl = (caskModData.souredMl or 0) + souredMl
    while caskModData.souredMl >= V.MOTHER_LAYER_ML do
        caskModData.souredMl = caskModData.souredMl - V.MOTHER_LAYER_ML
        caskModData.layers = V.motherLayers(caskModData) + 1
    end
end

-- A new mother, grown or brought in a jar, is one thin layer.
function V.addMother(caskModData)
    if caskModData.mother then return false end
    caskModData.mother, caskModData.layers, caskModData.souredMl = true, 1, 0
    return true
end

-- Lifting the whole mother out leaves the cask without one.
function V.takeMother(caskModData)
    if not caskModData.mother then return false end
    caskModData.mother, caskModData.layers, caskModData.souredMl = nil, nil, 0
    return true
end

-- A mother needs two layers to split: one to take, one to stay.
function V.canSplitMother(caskModData)
    return V.motherLayers(caskModData) >= 2
end

-- How much more vinegar the cask must make before the mother grows its next layer.
function V.nextLayerMl(caskModData)
    return math.max(V.MOTHER_LAYER_ML - (caskModData.souredMl or 0), 0)
end

-- Peeling off a layer for a jar leaves the rest working in the cask.
function V.splitMother(caskModData)
    if not V.canSplitMother(caskModData) then return false end
    caskModData.layers = caskModData.layers - 1
    return true
end

-- An empty jar for the mother: any jar holding no liquid.
function V.isEmptyJar(item)
    local fluid = item:getFluidContainer()
    return item:hasTag(ItemTag.JAR) and fluid ~= nil and fluid:isEmpty()
end

-- The hose. Each end keeps the other's square in its ModData. Neither station can be picked up while
-- joined, so the squares stay right.
function V.hoseLink(station)
    return station:getModData().vinegarHose
end

local function squareOf(station)
    local square = station:getSquare()
    return { x = square:getX(), y = square:getY(), z = square:getZ() }
end

-- The station at the other end, and whether its square is loaded at all. A loaded square with no
-- station on it means the other end was destroyed.
function V.hosePartner(station)
    local link = V.hoseLink(station)
    if not link then return nil, false end
    local square = getCell():getGridSquare(link.x, link.y, link.z)
    if not square then return nil, false end
    local test = V.isVessel(station) and V.isCask or V.isVessel
    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        local isoObject = objects:get(i)
        if test(isoObject) then return isoObject, true end
    end
    return nil, true
end

-- Every cask the vessel can reach with a hose (same floor, HOSE_REACH apart at most each way) that has none
-- of its own, nearest first. The menu offers the choice when there are several.
function V.casksForHose(vessel)
    return Station.near(vessel:getSquare(), V.HOSE_REACH, function(isoObject)
        return V.isCask(isoObject) and not V.hoseLink(isoObject)
    end)
end

-- Each end keeps the other's square in its modData, so the link survives either being unloaded.
function V.connectHose(vessel, cask)
    vessel:getModData().vinegarHose = squareOf(cask)
    cask:getModData().vinegarHose = squareOf(vessel)
end

-- Clears both ends, or only this one if the other isn't loaded; that end drops its hose when it next
-- loads and finds no station here (World's tendHose).
function V.disconnectHose(station)
    local partner = V.hosePartner(station)
    if partner then partner:getModData().vinegarHose = nil end
    station:getModData().vinegarHose = nil
end

-- Less than this in the vessel's Fermented tank is dregs, not worth a pump.
V.HOSE_MIN_ML = 50
V.PUMP_STEPS = { 5000, 10000 }

-- Pumps up to ml of the vessel's fermented wort (its record, V.vesselOf) into the cask, as far as the tank and the
-- cask's room allow. The player chooses how much, as Orléans vinegar makers topped up by hand.
function V.pumpToCask(caskModData, record, ml)
    ml = math.min(ml, record.fermentedMl, V.caskRoom(caskModData))
    if ml < V.HOSE_MIN_ML then return 0 end
    local moved = V.pourIntoCask(caskModData, ml)
    V.drawOff(record, moved)
    return moved
end

-- Why a Pump to Cask preset can't run, as translation keys (V.pumpChoices).
V.PUMP_REFUSALS = {
    pumpEmpty = "IGUI_TraditionalPreservationVinegar_PumpEmpty",
    pumpNoRoom = "IGUI_TraditionalPreservationVinegar_PumpNoRoom",
    pumpAtAirLine = "IGUI_TraditionalPreservationVinegar_PumpAtAirLine",
    pumpNotEnough = "IGUI_TraditionalPreservationVinegar_PumpNotEnough",
}

-- The Pump to Cask presets: a few fixed amounts, up to the air line (the fullest the cask sours at full
-- speed), and all that fits. Each has the litres it would move, or a reason it can't, with the litres
-- the reason names.
function V.pumpChoices(caskModData, availableMl)
    local room = V.caskRoom(caskModData)
    local choices = {}
    local function addChoice(fill, ml, wanted)
        local choice = { fill = fill, ml = ml, wanted = wanted }
        if availableMl < V.HOSE_MIN_ML then
            choice.reason = V.PUMP_REFUSALS.pumpEmpty
        elseif room < V.HOSE_MIN_ML then
            choice.reason, choice.reasonMl = V.PUMP_REFUSALS.pumpNoRoom, room
        elseif fill == "air" and ml < V.HOSE_MIN_ML then
            choice.reason, choice.reasonMl = V.PUMP_REFUSALS.pumpAtAirLine, V.AIR_ML
        elseif wanted and availableMl < wanted then
            choice.reason, choice.reasonMl = V.PUMP_REFUSALS.pumpNotEnough, availableMl
        elseif wanted and room < wanted then
            choice.reason, choice.reasonMl = V.PUMP_REFUSALS.pumpNoRoom, room
        end
        table.insert(choices, choice)
    end
    for _, step in ipairs(V.PUMP_STEPS) do addChoice("step", step, step) end
    addChoice("air", math.min(V.AIR_ML - caskModData.ml, availableMl, room))
    addChoice("all", math.min(availableMl, room))
    return choices
end

-- Attaching or detaching the hose takes pliers; a broken pair won't do.
function V.findPliers(inventory)
    return inventory:getFirstTagEvalRecurse(ItemTag.PLIERS, function(item) return not item:isBroken() end)
end

-- The nearest station in reach that test accepts, or nil.
function V.findNear(character, test)
    local square = character and character:getCurrentSquare()
    return square and Station.near(square, V.REACH, test)[1] or nil
end

local function hasVinegar(isoObject)
    return V.isCask(isoObject) and V.bottlesLeft(V.caskModData(isoObject)) > 0
end

-- A cask in reach with at least a bottle's worth of finished vinegar.
function V.findCaskWithVinegar(character)
    return V.findNear(character, hasVinegar)
end

function V.isEmptyBottle(item)
    local fluid = item:getFluidContainer()
    return fluid ~= nil and fluid:isEmpty()
end

-- The bottling recipe's OnTest. It scans the squares in reach, but only while a menu is built.
function V.canBottle(item, character)
    return V.isEmptyBottle(item) and V.findCaskWithVinegar(character) ~= nil
end

-- The bottles the recipe takes, by full type, so the right-click menu can't disagree with it.
function V.bottleTypes()
    if V.bottleTypeSet then return V.bottleTypeSet end
    local types = {}
    local recipe = ScriptManager.instance:getCraftRecipe("TraditionalPreservationVinegar.BottleVinegar")
    local items = recipe:getInputs():get(0):getPossibleInputItems()
    for i = 0, items:size() - 1 do
        types[items:get(i):getFullName()] = true
    end
    V.bottleTypeSet = types
    return types
end

-- Sorts bottles into one group per kind, in name order, each with its display name and items.
function V.groupBottles(bottles)
    local groups, byType = {}, {}
    for _, bottle in ipairs(bottles) do
        local fullType = bottle:getFullType()
        local group = byType[fullType]
        if not group then
            group = { name = bottle:getDisplayName(), items = {} }
            byType[fullType] = group
            table.insert(groups, group)
        end
        table.insert(group.items, bottle)
    end
    table.sort(groups, function(a, b) return a.name < b.name end)
    return groups
end

-- Takes the litre from the cask and writes the bottle's type on the Vinegar, so it can be given back.
function V.onBottled(craftRecipeData, character)
    local cask = V.findCaskWithVinegar(character)
    if cask then V.takeBottle(V.caskModData(cask)) end
    local used, made = craftRecipeData:getAllConsumedItems(), craftRecipeData:getAllCreatedItems()
    if used:size() > 0 and made:size() > 0 then V.markBottle(made:get(0), used:get(0):getFullType()) end
end

-- Reads the sandbox options into the stage times, culture bonus, sensitivity and effort.
function V.applySandbox()
    local options = SandboxVars and SandboxVars.TraditionalPreservationVinegar
    if not options then return end
    if options.MaltingDays then V.MALTING_HOURS = options.MaltingDays * 24 end
    if options.AlcoholicDays then V.ALCOHOLIC_HOURS = options.AlcoholicDays * 24 end
    if options.AceticDays then V.ACETIC_HOURS = options.AceticDays * 24 end
    if options.CultureBonus then V.CULTURE_BONUS = options.CultureBonus / 100 end
    if options.TemperatureSensitivity then V.SENSITIVITY = Weather.sensitivity(options.TemperatureSensitivity) end
    if options.BrewingEffort then V.EFFORT = V.EFFORT_SCALES[options.BrewingEffort] or V.EFFORT end
    if options.WortSours ~= nil then V.WORT_SOURS = options.WortSours end
end

-- Reads the sandbox into the stage times and sets the hand recipes' times and cooking minutes for the effort.
-- TEST_HOURS (Dev console) overrides the stage times.
function V.applyRecipeTimes()
    V.applySandbox()
    if V.TEST_HOURS then
        print("[TraditionalPreservationVinegar] Test timers on: " .. V.TEST_HOURS .. " hours a batch")
        V.MALTING_HOURS, V.ALCOHOLIC_HOURS, V.ACETIC_HOURS, V.SENSITIVITY = V.TEST_HOURS, V.TEST_HOURS, V.TEST_HOURS, 0
    end
    for name, time in pairs(CRAFT_TIMES) do
        local fullName = RECIPE_MODULE .. name
        local recipe = ScriptManager.instance:getCraftRecipe(fullName)
        if recipe then recipe:Load(fullName, "{ time = " .. tostring(math.floor(time * V.EFFORT)) .. ", }") end
    end
    for fullType, minutes in pairs(COOK_MINUTES) do
        local item = ScriptManager.instance:getItem(fullType)
        if item then item:DoParam("MinutesToCook = " .. tostring(math.floor(minutes * V.EFFORT))) end
    end
end

Events.OnInitGlobalModData.Add(V.applyRecipeTimes)

require "TraditionalPreservationVinegarFrost"
require "TraditionalPreservationVinegarFloor"
require "TraditionalPreservationVinegarVessel"
