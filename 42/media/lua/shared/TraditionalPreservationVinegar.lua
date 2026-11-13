-- Traditional Preservation (Vinegar): the fermentation rules shared by the recipes, the world and the menus.
-- Weather is the same everywhere, so running totals in global ModData tell every vessel and cask
-- how much work they have done, including while their chunk was unloaded.
TraditionalPreservationVinegar = TraditionalPreservationVinegar or {}
local V = TraditionalPreservationVinegar
local Weather = require "TraditionalPreservationCore/Weather"
local Hearth = require "TraditionalPreservationCore/Hearth"
local Station = require "TraditionalPreservationCore/Station"
local Container = require "TraditionalPreservationCore/Container"
local FluidAgeing = require "TraditionalPreservationCore/FluidAgeing"
local Tiles = require "TraditionalPreservationVinegar/Tiles"

V.MOD_DATA_KEY = "TraditionalPreservationVinegar"
V.SPRITE_PREFIX = Tiles.PREFIX

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

-- Hours at a rate of 1. These set the recipes' times, and the sandbox can replace them.
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
V.WORT_KIND = "wort"
V.WORT_SOUR_HOURS = 48
V.WORT_SOURS = true
-- A vessel run takes whole buckets of wort from its tank, one or two, and leaves 5% behind as lees.
V.BUCKET_ML = 10000
V.VESSEL_MAX_ML = 20000
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

local function scaled(rate)
    return Weather.scaled(rate, V.SENSITIVITY, V.MIN_RATE)
end

-- Each stage's speed at a temperature, 0 to 1, after the sandbox's sensitivity. Frozen a stage pauses (TP Core's
-- Weather.frozen); the floor holds above freezing only.
function V.maltingRate(celsius)
    if Weather.frozen(celsius, V.SENSITIVITY) then return 0 end
    return scaled(Weather.curve(MALTING_CURVE, celsius))
end

function V.alcoholicRate(celsius)
    if Weather.frozen(celsius, V.SENSITIVITY, V.FREEZE_C) then return 0 end
    return scaled(Weather.curve(ALCOHOLIC_CURVE, celsius))
end

function V.aceticRate(celsius)
    if Weather.frozen(celsius, V.SENSITIVITY, V.FREEZE_C) then return 0 end
    return scaled(Weather.curve(ACETIC_CURVE, celsius))
end

-- Not scaled by the sensitivity: that setting is for the brewer's own stages.
function V.wortRate(celsius)
    return Weather.curve(WORT_CURVE, celsius)
end

-- Places and their temperatures are shared with the other Traditional Preservation mods (TP Core's Weather):
-- open air, an open roof, indoors, a basement, and by a fire or by banked embers (TP Core's Hearth). These are the
-- mod's public names, used by the actions, the Dev console and the tools. PLACES are the weather's, which the
-- ledger keeps totals for; by a fire counts by the clock.
V.PLACES = Weather.PLACES
V.placeOf = Hearth.placeOf
V.placeTemperature = Hearth.placeTemperature

-- Ledger keys are kind .. place ("aceticBasement"), as in every save so far.
local KINDS = {
    malting = function(celsius) return V.maltingRate(celsius) end,
    alcoholic = function(celsius) return V.alcoholicRate(celsius) end,
    acetic = function(celsius) return V.aceticRate(celsius) end,
    [V.WORT_KIND] = function(celsius) return V.wortRate(celsius) end,
}

-- One total per stage and place. Saves from before 0.2.10 also keep ledger.heat, the hours too hot for an open
-- vessel; nothing reads it now.
function V.newLedger(now)
    return Weather.newLedger(now, KINDS)
end

-- Adds one stretch of weather to the totals.
function V.advance(ledger, now, temperature)
    Weather.advance(ledger, now, temperature, KINDS)
end

-- Filled once on OnInitGlobalModData (fillLedger), so this is a plain lookup.
function V.getLedger()
    return Weather.getLedger(V.MOD_DATA_KEY, V.newLedger)
end

-- A save from before malting or basements has no totals for them. Filled once as the save loads,
-- not on every getLedger: running batches, casks and popups ask for it many times a second.
function V.fillLedger()
    Weather.fillLedger(V.getLedger(), KINDS)
end

Events.OnInitGlobalModData.Add(V.fillLedger)

-- Wort in a bucket or any container ages through TP Core's FluidAgeing, as Dairy's milk does. It has one stage
-- only: Sour Wort is both its turned and its spoiled fluid. Fermented wort is not registered, so it keeps.
V.WORT_SPEC = FluidAgeing.register({
    kind = V.WORT_KIND,
    rate = V.wortRate,
    turnHours = V.WORT_SOUR_HOURS,
    spoilHours = V.WORT_SOUR_HOURS,
    fresh = { [V.WORT] = V.SOUR_WORT },
    spoiled = { [V.WORT] = V.SOUR_WORT },
    getLedger = function() return V.getLedger() end,
    enabled = function() return V.WORT_SOURS end,
})

-- A run's place, from a run saved before basements too.
local function runPlace(modData)
    return modData.place or (modData.sheltered and "Sheltered") or "Open"
end

-- The engine pools recipe data without clearing its ModData, so every run must set all of this.
local function startRun(craftRecipeData, kind)
    local ledger = V.getLedger()
    local modData = craftRecipeData:getModData()
    Weather.startRun(modData, ledger, kind)
    modData.sheltered = nil
    modData.mother = nil
end

-- Brings a run up to now at the place it was last told (V.notePlace), by a fire by the clock.
local function catchUpRun(modData, kind)
    if not modData.done then return end
    -- A run from before basements kept its last totals in two fields.
    modData.last = modData.last or { Open = modData.lastOpen, Sheltered = modData.lastSheltered }
    Hearth.catchUpRun(modData, V.getLedger(), kind, runPlace(modData), KINDS[kind])
end

-- Adds what the weather has given since the last update, at the place the station's World last told the run, so
-- a roof built over a running vessel counts from then on.
local function updateRun(craftRecipeData, kind, speed)
    local modData = craftRecipeData:getModData()
    if not modData.done then return end
    -- A run from before basements kept its last totals in two fields.
    modData.last = modData.last or { Open = modData.lastOpen, Sheltered = modData.lastSheltered }
    Hearth.updateRun(craftRecipeData, V.getLedger(), kind, runPlace(modData), KINDS[kind], speed)
end

-- Tells a running batch (kind "malting" or "alcoholic") where its station stands: the place, and the fire's fuel
-- when it is by one. A move first brings the run up to now where it was. Returns the place.
function V.notePlace(modData, station, kind, now)
    return Hearth.notePlace(modData, station, now, function(state) catchUpRun(state, kind) end)
end

-- OnStart and OnUpdate hooks the recipe scripts name, one pair per weather-timed stage.
function V.onMaltStart(craftRecipeData)
    startRun(craftRecipeData, "malting")
end

function V.onMaltUpdate(craftRecipeData)
    updateRun(craftRecipeData, "malting", 1)
end

function V.onFermentStart(craftRecipeData)
    startRun(craftRecipeData, "alcoholic")
end

function V.onFermentUpdate(craftRecipeData)
    updateRun(craftRecipeData, "alcoholic", 1)
end

-- How a running batch is doing right now, for its popup. hoursLeft assumes the temperature holds.
function V.batchStatus(kind, modData, recipeHours, ledger)
    return Weather.batchStatus(modData.done or 0, recipeHours, ledger, runPlace(modData), KINDS[kind])
end

-- The bucket becomes the mash. Its kind (plain or forged) is noted on it, and heating carries the note over
-- (see the core's Container).
function V.onMashed(craftRecipeData)
    Container.note(craftRecipeData, "TraditionalPreservationVinegar.BucketMash")
end

-- Strain Mash gives back the bucket that went in, and this pours the wort into it.
function V.onStrained(craftRecipeData, character)
    local bucket = Container.giveBack(craftRecipeData, character, "Base.BucketEmpty")
    local container = bucket and bucket:getFluidContainer()
    if container then
        container:Empty()
        -- New wort starts its own age, whatever the bucket held before.
        bucket:getModData()[FluidAgeing.KEY] = nil
        container:addFluid(V.WORT, math.min(10, container:getCapacity()))
    end
end

-- How much wort a run takes from a tank holding this many millilitres: whole buckets, at most two.
function V.batchMl(tankMl)
    return math.min(math.floor((tankMl + 1) / V.BUCKET_ML) * V.BUCKET_ML, V.VESSEL_MAX_ML)
end

-- What a run of this much wort gives back, after the lees.
function V.fermentedMl(wortMl)
    return math.floor(wortMl * V.FERMENT_YIELD + 0.5)
end

-- True when a container holds only the named fluid.
function V.holdsOnly(container, name)
    return Container.fluidIn(container) == name
end

-- Slots take anything unless told otherwise, and a wrong item leaves the recipe with no output.
local STATION_INPUTS = {
    floor = { "TraditionalPreservationVinegar.SteepedGrain", "IGUI_TraditionalPreservationVinegar_NeedsSteeped" },
    vessel = { "Base.Yeast", "IGUI_TraditionalPreservationVinegar_NeedsYeast" },
}

-- The translation key saying what this station takes, or nil if fullType is it.
function V.inputRefusal(kind, fullType)
    local input = STATION_INPUTS[kind]
    return fullType ~= input[1] and input[2] or nil
end

function V.spriteName(index)
    return V.SPRITE_PREFIX .. index
end

-- Each station has FACE_COUNT tiles from its base, one per facing.
V.STATION_SPRITES = { cask = V.CASK_SPRITE, vessel = V.VESSEL_SPRITE, floor = V.FLOOR_SPRITE }

-- Which station this is ("cask", "vessel" or "floor") and which way it faces, or nil for anything else.
V.stationKind = Station.kinds(V.SPRITE_PREFIX, V.FACE_COUNT, V.STATION_SPRITES)

function V.isCask(object)
    return V.stationKind(object) == "cask"
end

function V.isVessel(object)
    return V.stationKind(object) == "vessel"
end

function V.isFloor(object)
    return V.stationKind(object) == "floor"
end

-- The vessel's tank on one side, or nil.
function V.vesselTank(vessel, io)
    local resources = vessel:getComponent(ComponentType.Resources)
    local logic = vessel:getComponent(ComponentType.CraftLogic)
    if not resources or not logic then return nil end
    local group = io == ResourceIO.Input and logic:getInputsGroupName() or logic:getOutputsGroupName()
    -- This clears the list it is given, so each call needs its own.
    local tanks = resources:getResourcesFromGroup(group, ArrayList.new(), io, ResourceType.Fluid)
    return tanks:size() > 0 and tanks:get(0) or nil
end

-- The running batch's recipe data, or nil. CraftLogic's own list of runs isn't exposed to Lua, so
-- this goes through the window's logic, which needs a real player.
function V.runningBatch(station, logic, uiLogic)
    if not logic or not logic:isRunning() then return nil end
    if not uiLogic then
        local player = getPlayer()
        if not player then return nil end
        uiLogic = CraftLogicUILogic.new(player, station, logic)
    end
    for craftData, _ in pairs(uiLogic:getItemsInProgress()) do
        return craftData
    end
    return nil
end

function V.litres(tank)
    return tank and tank:getFluidContainer():getAmount() or 0
end

-- The Wort tank is a station resource, not an item, so FluidAgeing can't keep a record on it: the record sits on
-- the vessel's modData under FluidAgeing's key instead. Brings it up to now at place, starting one for wort that
-- has none, and forgets it once the tank is empty. Returns the record, or nil with no wort or souring off.
function V.ageTank(modData, ml, place, now)
    local key = FluidAgeing.KEY
    if ml <= 0 or not V.WORT_SOURS then
        modData[key] = nil
        return nil
    end
    local ledger, record = V.getLedger(), modData[key]
    if not record or record.kind ~= V.WORT_KIND then
        record = FluidAgeing.newRecord(V.WORT_SPEC, ledger, now, place)
        modData[key] = record
        return record
    end
    return FluidAgeing.advance(record, V.WORT_SPEC, ledger, now, place)
end

-- The vessel's tank record, brought up to now where the vessel stands. Items age by the weather's place, so the
-- tank does too (a fire counts as the room it warms).
function V.tankAge(vessel, now)
    local ml = math.floor(V.litres(V.vesselTank(vessel, ResourceIO.Input)) * 1000 + 0.5)
    return V.ageTank(vessel:getModData(), ml, Weather.placeOf(vessel), now or getGameTime():getWorldAgeHours())
end

-- The tank's record as it stands now, without changing the vessel: for windows and menus. Nil with no record yet.
function V.peekTank(vessel, now)
    local record = vessel:getModData()[FluidAgeing.KEY]
    if not record or record.kind ~= V.WORT_KIND or not V.WORT_SOURS then return nil end
    if V.litres(V.vesselTank(vessel, ResourceIO.Input)) <= 0 then return nil end
    return FluidAgeing.advance(FluidAgeing.copy(record), V.WORT_SPEC, V.getLedger(),
        now or getGameTime():getWorldAgeHours(), Weather.placeOf(vessel))
end

function V.isSour(record)
    return record ~= nil and FluidAgeing.stage(record, V.WORT_SPEC) ~= "Fresh"
end

-- Hours until a record sours at a temperature, or nil when it has or won't there (frozen).
function V.hoursToSour(record, celsius)
    local left, rate = FluidAgeing.hoursLeft(record, V.WORT_SPEC), V.wortRate(celsius)
    if not left or V.isSour(record) or rate <= 0 then return nil end
    return left / rate
end

-- Wort poured into the tank brings its age: the older wins, as with milk. Call it before the wort moves.
function V.pourIntoTank(vessel, item, now)
    local had = V.tankAge(vessel, now) ~= nil
    local record = FluidAgeing.sourceRecord(item, now)
    if record then FluidAgeing.receive(vessel:getModData(), record, had, Weather.placeOf(vessel)) end
end

-- The cask's own state. It sits in movableData because vanilla copies that onto the item when a
-- station is picked up and back when it is placed, so the pool and the mother move with the cask,
-- and there is only ever one of each.
function V.caskState(cask)
    local state = Station.movableData(cask)
    -- A cask from before the continuous pool held only finished vinegar.
    if state.vinegarMl then
        state.ml, state.strength, state.vinegarMl = state.vinegarMl, state.vinegarMl > 0 and 1 or 0, nil
    end
    state.ml = state.ml or 0
    state.strength = state.strength or 0
    return state
end

-- Millilitres the cask can still take.
function V.caskRoom(state)
    return math.max(V.CASK_ML - state.ml, 0)
end

-- New fermented wort has no acid, so it thins the pool's strength by its share.
function V.pourIntoCask(state, ml)
    ml = math.min(ml, V.caskRoom(state))
    if ml <= 0 then return 0 end
    state.strength = state.strength * state.ml / (state.ml + ml)
    state.ml = state.ml + ml
    return ml
end

-- A cask souring with air above it works best: full speed up to AIR_ML, slowing to CROWDED_RATE full.
function V.airShare(ml)
    if ml <= V.AIR_ML then return 1 end
    return lerp(1, V.CROWDED_RATE, math.min((ml - V.AIR_ML) / (V.CASK_ML - V.AIR_ML), 1))
end

-- A mother in vinegar at least STARTER_STRENGTH makes the pool sour faster (CULTURE_BONUS).
function V.hasStarter(state)
    return state.mother and state.strength >= V.STARTER_STRENGTH
end

-- How fast this pool sours compared with a plain one, before temperature.
function V.caskSpeed(state)
    local culture = V.hasStarter(state) and 1 / (1 - V.CULTURE_BONUS) or 1
    return culture * V.airShare(state.ml)
end

-- Spends rateHours of weather on the pool. A pool that reaches full strength grows a mother.
function V.sour(state, rateHours)
    while rateHours > 0 and state.ml > 0 and state.strength < 1 do
        local perHour = V.caskSpeed(state) / V.ACETIC_HOURS
        local gain = math.min(rateHours * perHour, SOUR_STEP, 1 - state.strength)
        if gain <= 0 then break end
        rateHours = rateHours - gain / perHour
        state.strength = state.strength + gain
        if state.mother then V.growMother(state, state.ml * gain) end
        state.ml = state.ml - state.ml * V.ACETIC_LOSS * gain
        if state.strength >= 1 - 1e-6 then
            state.strength = 1
            if not state.mother then V.addMother(state) end
        end
    end
end

-- Brings a cask up to date with the weather since it was last seen, at place (by a fire by the clock, until the
-- fuel noted in state ran out).
function V.updateCask(state, ledger, place)
    -- A cask from before basements kept its last totals in two fields.
    if state.lastOpen and not state.last then state.last = { Open = state.lastOpen, Sheltered = state.lastSheltered } end
    if state.last then
        V.sour(state, Hearth.catchUp(state, state.last, ledger, "acetic", place, V.aceticRate))
    else
        state.last = Weather.mark({}, ledger, "acetic")
    end
    state.lastOpen, state.lastSheltered = nil, nil
end

-- Brings a cask up to date where it stands: a move first catches it up where it was (state.place, kept from 0.2.10;
-- an older cask goes by its place now). Returns the place.
function V.updateCaskAt(state, ledger, cask)
    local now = getGameTime():getWorldAgeHours()
    local place = Hearth.notePlace(state, cask, now, function(was) V.updateCask(was, ledger, was.place) end)
    V.updateCask(state, ledger, place)
    return place
end

-- For the menus. hoursLeft is to fully soured and assumes the temperature holds; nil while frozen.
function V.caskStatus(state, ledger, place)
    local temperature = Weather.placeTemperature(ledger, place)
    local rate = V.aceticRate(temperature)
    return {
        temperature = temperature,
        place = place,
        rate = rate,
        hoursLeft = rate > 0 and (1 - state.strength) * V.ACETIC_HOURS / (V.caskSpeed(state) * rate) or nil,
    }
end

-- Only full-strength vinegar is drawn off.
function V.bottlesLeft(state)
    if state.strength < 1 then return 0 end
    return math.floor(state.ml / V.BOTTLE_ML)
end

-- What is left after the last whole bottle stays as starter for the next fill.
function V.takeBottle(state)
    if V.bottlesLeft(state) < 1 then return false end
    state.ml = state.ml - V.BOTTLE_ML
    return true
end

-- Pouring a cask out leaves the mother in it.
function V.emptyCask(state)
    state.ml, state.strength = 0, 0
end

-- 0 without a mother.
function V.motherLayers(state)
    return state.mother and (state.layers or 1) or 0
end

-- Every litre the pool sours feeds the mother, and it thickens a layer at a time.
function V.growMother(state, souredMl)
    state.souredMl = (state.souredMl or 0) + souredMl
    while state.souredMl >= V.MOTHER_LAYER_ML do
        state.souredMl = state.souredMl - V.MOTHER_LAYER_ML
        state.layers = V.motherLayers(state) + 1
    end
end

-- A new mother, grown or brought in a jar, is one thin layer.
function V.addMother(state)
    if state.mother then return false end
    state.mother, state.layers, state.souredMl = true, 1, 0
    return true
end

-- Lifting the whole mother out leaves the cask without one.
function V.takeMother(state)
    if not state.mother then return false end
    state.mother, state.layers, state.souredMl = nil, nil, 0
    return true
end

-- A mother needs two layers to split: one to take, one to stay.
function V.canSplitMother(state)
    return V.motherLayers(state) >= 2
end

-- How much more vinegar the cask must make before the mother grows its next layer.
function V.nextLayerMl(state)
    return math.max(V.MOTHER_LAYER_ML - (state.souredMl or 0), 0)
end

-- Peeling off a layer for a jar leaves the rest working in the cask.
function V.splitMother(state)
    if not V.canSplitMother(state) then return false end
    state.layers = state.layers - 1
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
        local object = objects:get(i)
        if test(object) then return object, true end
    end
    return nil, true
end

-- Every cask the vessel can reach with a hose (same floor, HOSE_REACH apart at most each way) that has none
-- of its own, nearest first. The menu offers the choice when there are several.
function V.casksForHose(vessel)
    return Station.near(vessel:getSquare(), V.HOSE_REACH, function(object)
        return V.isCask(object) and not V.hoseLink(object)
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

-- Pumps up to ml of the vessel's fermented wort into the cask, as far as the tank and the cask's room allow.
-- The player chooses how much, as Orléans vinegar makers topped up by hand.
function V.pumpToCask(state, container, ml)
    ml = math.min(ml, Container.ml(container), V.caskRoom(state))
    if ml < V.HOSE_MIN_ML then return 0 end
    local moved = V.pourIntoCask(state, ml)
    container:removeFluid(moved / 1000)
    return moved
end

-- The Pump to Cask presets: a few fixed amounts, up to the air line (the fullest the cask sours at full
-- speed), and all that fits. Each has the litres it would move, or a reason it can't, with the litres
-- the reason names.
function V.pumpChoices(state, availableMl)
    local room = V.caskRoom(state)
    local choices = {}
    local function choice(kind, ml, wanted)
        local entry = { kind = kind, ml = ml, wanted = wanted }
        if availableMl < V.HOSE_MIN_ML then
            entry.reason = "IGUI_TraditionalPreservationVinegar_PumpEmpty"
        elseif room < V.HOSE_MIN_ML then
            entry.reason, entry.reasonMl = "IGUI_TraditionalPreservationVinegar_PumpNoRoom", room
        elseif kind == "air" and ml < V.HOSE_MIN_ML then
            entry.reason, entry.reasonMl = "IGUI_TraditionalPreservationVinegar_PumpAtAirLine", V.AIR_ML
        elseif wanted and availableMl < wanted then
            entry.reason, entry.reasonMl = "IGUI_TraditionalPreservationVinegar_PumpNotEnough", availableMl
        elseif wanted and room < wanted then
            entry.reason, entry.reasonMl = "IGUI_TraditionalPreservationVinegar_PumpNoRoom", room
        end
        table.insert(choices, entry)
    end
    for _, step in ipairs(V.PUMP_STEPS) do choice("step", step, step) end
    choice("air", math.min(V.AIR_ML - state.ml, availableMl, room))
    choice("all", math.min(availableMl, room))
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

local function hasVinegar(object)
    return V.isCask(object) and V.bottlesLeft(V.caskState(object)) > 0
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
    if cask then V.takeBottle(V.caskState(cask)) end
    if not (craftRecipeData and V.markBottle) then return end
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

local function applyRecipeTime(name, hours)
    Weather.setRecipeHours(RECIPE_MODULE .. name, hours, "TraditionalPreservationVinegar")
end

-- Sets each recipe's script time from the sandbox, so the crafting window shows the right length.
-- TEST_HOURS (Dev console) overrides them all.
function V.applyRecipeTimes()
    V.applySandbox()
    if V.TEST_HOURS then
        print("[TraditionalPreservationVinegar] Test timers on: " .. V.TEST_HOURS .. " hours a batch")
        V.MALTING_HOURS, V.ALCOHOLIC_HOURS, V.ACETIC_HOURS, V.SENSITIVITY = V.TEST_HOURS, V.TEST_HOURS, V.TEST_HOURS, 0
    end
    applyRecipeTime("MaltGrain", V.MALTING_HOURS)
    applyRecipeTime("FermentWort", V.ALCOHOLIC_HOURS)
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
