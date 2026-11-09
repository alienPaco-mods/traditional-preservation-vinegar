-- Traditional Preservation (Vinegar): the fermentation rules shared by the recipes, the world and the menus.
-- Weather is the same everywhere, so running totals in global ModData tell every vessel and cask
-- how much work they have done, including while their chunk was unloaded.
TraditionalPreservationVinegar = TraditionalPreservationVinegar or {}
local V = TraditionalPreservationVinegar
local Weather = require "TraditionalPreservationVinegar/Core/Weather"
local Station = require "TraditionalPreservationVinegar/Core/Station"

V.MOD_DATA_KEY = "TraditionalPreservationVinegar"
V.SPRITE_PREFIX = "traditionalpreservationvinegar_01_"

-- Keep in step with the tile numbers in tools/build_tileset.py. Each sprite is the east facing, and
-- the next one is the south facing.
V.VESSEL_SPRITE, V.CASK_SPRITE, V.FLOOR_SPRITE = 0, 10, 24
V.VESSEL_FILLED, V.VESSEL_BUBBLING, V.VESSEL_SEDIMENT, V.VESSEL_FINISHED = 2, 4, 6, 8
V.CASK_FILLED, V.CASK_FILM = 12, { 14, 16, 18 }
V.CASK_FINISHED, V.CASK_MOTHER = 20, 22
V.FLOOR_STEEPED, V.FLOOR_SPROUTING, V.FLOOR_ROOTLETS, V.FLOOR_FINISHED = 26, 28, 30, 32
-- Drawn over either station while a hose joins them.
V.VESSEL_HOSE, V.CASK_HOSE = 34, 36
V.FACE_COUNT = 2

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
-- Off, Forgiving, Normal, Harsh: how much of a temperature's slowdown applies.
V.SENSITIVITY_SCALES = { 0, 0.5, 1, 1.5 }
V.SENSITIVITY = 1
V.MIN_RATE = 0.02

-- All volumes are whole millilitres, so bottling can't drift.
-- The vanilla jarring recipe takes 2 uses of vinegar for a 1 L jar, and a real jar takes about
-- 0.2 L, so a use is 0.1 L and a bottle of 10 uses is 1 L. Vanilla bottles hold 1 L too.
V.BOTTLE_ML = 1000
V.WORT = "MaltWort"
V.FERMENTED = "MaltFermentedWort"
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
V.ACETIC_LOSS = 0.2
-- The mother only speeds a cask that still has this much sour vinegar in it as a starter.
V.STARTER_STRENGTH = 0.25
-- A mother grows a new layer for about every full batch it sours, and one with two or more can be split.
V.MOTHER_LAYER_ML = 15000
V.MOTHER_ITEM = "TraditionalPreservationVinegar.MotherOfVinegar"
-- Long gaps are worked through in steps this big, as the speed changes on the way.
local SOUR_STEP = 0.02

-- Each hour hotter than this costs an open vessel some of its yield, up to the most it can lose.
V.HEAT_HARM_ABOVE = 35
V.HEAT_LOSS_PER_HOUR = 0.01
V.MAX_HEAT_LOSS = 0.25

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

local SECONDS_PER_HOUR = 3600
local RECIPE_MODULE = "TraditionalPreservationVinegar."

local function lerp(from, to, amount)
    return from + (to - from) * amount
end

-- Below 10 C barely works, slower to 18, best to 25, active to 30, then falling away.
local ALCOHOLIC_CURVE = { { 9.9, 0.05 }, { 10, 0.35 }, { 18, 1 }, { 25, 1 }, { 30, 0.85 }, { 35, 0.4 }, { 40, 0.1 } }
-- Below 10 C barely works, slower to 20, best to 30, then falling away.
local ACETIC_CURVE = { { 9.9, 0.05 }, { 10, 0.3 }, { 20, 1 }, { 30, 1 }, { 35, 0.6 }, { 40, 0.25 } }

-- Sprouting grain likes it cool: best from 12 to 20 C, and it stalls in frost or heat.
local MALTING_CURVE = { { 4.9, 0.05 }, { 5, 0.3 }, { 12, 1 }, { 20, 1 }, { 28, 0.35 }, { 33, 0.05 } }

local function scaled(rate)
    return Weather.scaled(rate, V.SENSITIVITY, V.MIN_RATE)
end

function V.maltingRate(celsius)
    return scaled(Weather.curve(MALTING_CURVE, celsius))
end

function V.alcoholicRate(celsius)
    return scaled(Weather.curve(ALCOHOLIC_CURVE, celsius))
end

function V.aceticRate(celsius)
    return scaled(Weather.curve(ACETIC_CURVE, celsius))
end

-- Places and their temperatures are shared with the other Traditional Preservation mods: outdoors, under
-- a roof (the cellar, which follows the season), or below ground in a basement, at one temperature all year.
-- These three are the mod's public names, used by the actions, the Dev console and the tools.
V.PLACES = Weather.PLACES
V.placeOf = Weather.placeOf
V.placeTemperature = Weather.placeTemperature

-- Ledger keys are kind .. place ("aceticBasement"), as in every save so far.
local KINDS = {
    malting = function(celsius) return V.maltingRate(celsius) end,
    alcoholic = function(celsius) return V.alcoholicRate(celsius) end,
    acetic = function(celsius) return V.aceticRate(celsius) end,
}

function V.newLedger(now)
    local ledger = Weather.newLedger(now, KINDS)
    ledger.heat = 0
    return ledger
end

-- Adds one stretch of weather to the totals, and counts the hours too hot for an open vessel.
function V.advance(ledger, now, temperature)
    local hours = Weather.advance(ledger, now, temperature, KINDS)
    if hours and temperature > V.HEAT_HARM_ABOVE then
        ledger.heat = ledger.heat + hours
    end
end

-- A save from before malting or basements has no totals for them.
function V.getLedger()
    return Weather.fillLedger(Weather.getLedger(V.MOD_DATA_KEY, V.newLedger), KINDS)
end

-- A run's place, from a run saved before basements too.
local function runPlace(modData)
    return modData.place or (modData.sheltered and "Sheltered") or "Open"
end

-- The engine pools recipe data without clearing its ModData, so every run must set all of this.
local function startRun(craftRecipeData, kind)
    local ledger = V.getLedger()
    local modData = craftRecipeData:getModData()
    Weather.startRun(modData, ledger, kind)
    modData.lastHeat = ledger.heat
    modData.heat = 0
    modData.sheltered = nil
    modData.mother = nil
end

-- Adds what the weather has given since the last update. It goes by the station's place now,
-- so a roof built over a running vessel counts from then on. Only open stations overheat.
local function updateRun(craftRecipeData, kind, speed)
    local ledger = V.getLedger()
    local modData = craftRecipeData:getModData()
    if not modData.done then return end
    -- A run from before basements kept its last totals in two fields.
    modData.last = modData.last or { Open = modData.lastOpen, Sheltered = modData.lastSheltered }

    local place = runPlace(modData)
    modData.done = modData.done + Weather.catchUp(modData.last, ledger, kind, place)
    if place == "Open" then
        modData.heat = modData.heat + ledger.heat - modData.lastHeat
    end
    modData.lastHeat = ledger.heat
    Weather.showProgress(craftRecipeData, ledger, kind, place, speed, getGameTime():getWorldAgeHours())
end

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
    local status = Weather.batchStatus(modData.done or 0, recipeHours, ledger, runPlace(modData), KINDS[kind])
    status.heatLoss = kind == "alcoholic" and V.heatLoss(modData.heat or 0) or 0
    return status
end

function V.heatLoss(heatHours)
    return math.min(heatHours * V.HEAT_LOSS_PER_HOUR * V.SENSITIVITY, V.MAX_HEAT_LOSS)
end

-- Strain Mash gives back the bucket, and this pours the wort into it.
function V.onStrained(craftRecipeData)
    local created = craftRecipeData:getAllCreatedItems()
    for i = 0, created:size() - 1 do
        local container = created:get(i):getFluidContainer()
        if container then
            container:Empty()
            container:addFluid(V.WORT, math.min(10, container:getCapacity()))
            return
        end
    end
end

-- How much wort a run takes from a tank holding this many millilitres: whole buckets, at most two.
function V.batchMl(tankMl)
    return math.min(math.floor((tankMl + 1) / V.BUCKET_ML) * V.BUCKET_ML, V.VESSEL_MAX_ML)
end

-- What a run of this much wort gives back, after lees and any heat damage.
function V.fermentedMl(wortMl, heatHours)
    return math.floor(wortMl * V.FERMENT_YIELD * (1 - V.heatLoss(heatHours or 0)) + 0.5)
end

-- True when a container holds only the named fluid.
function V.holdsOnly(container, name)
    if not container or container:isEmpty() then return false end
    local fluid = container:getPrimaryFluid()
    return fluid ~= nil and fluid:getFluidTypeString() == name and container:getPrimaryFluidAmount() >= container:getAmount() - 0.001
end

-- Slots take anything unless told otherwise, and a wrong item leaves the recipe with no output.
local STATION_INPUTS = {
    floor = { "TraditionalPreservationVinegar.SteepedGrain", "IGUI_TraditionalPreservationVinegar_NeedsSteeped" },
    vessel = { "Base.Yeast", "IGUI_TraditionalPreservationVinegar_NeedsYeast" },
}

function V.inputRefusal(kind, fullType)
    local input = STATION_INPUTS[kind]
    return fullType ~= input[1] and input[2] or nil
end

function V.spriteIndex(name)
    if string.sub(name, 1, #V.SPRITE_PREFIX) ~= V.SPRITE_PREFIX then return nil end
    return tonumber(string.sub(name, #V.SPRITE_PREFIX + 1))
end

function V.spriteName(index)
    return V.SPRITE_PREFIX .. index
end

local function stationBase(object, base)
    local sprite = object and object:getSprite()
    local index = sprite and sprite:getName() and V.spriteIndex(sprite:getName())
    return index and index >= base and index < base + V.FACE_COUNT
end

function V.isCask(object)
    return stationBase(object, V.CASK_SPRITE)
end

function V.isVessel(object)
    return stationBase(object, V.VESSEL_SPRITE)
end

function V.isFloor(object)
    return stationBase(object, V.FLOOR_SPRITE)
end

-- Which station this is, or nil for anything else.
function V.stationKind(object)
    if V.isCask(object) then return "cask" end
    if V.isVessel(object) then return "vessel" end
    if V.isFloor(object) then return "floor" end
    return nil
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

function V.airShare(ml)
    if ml <= V.AIR_ML then return 1 end
    return lerp(1, V.CROWDED_RATE, math.min((ml - V.AIR_ML) / (V.CASK_ML - V.AIR_ML), 1))
end

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

-- Brings a cask up to date with the weather since it was last seen, by its place now.
function V.updateCask(state, ledger, place)
    -- A cask from before basements kept its last totals in two fields.
    if state.lastOpen and not state.last then state.last = { Open = state.lastOpen, Sheltered = state.lastSheltered } end
    if state.last then
        V.sour(state, Weather.catchUp(state.last, ledger, "acetic", place))
    else
        state.last = Weather.mark({}, ledger, "acetic")
    end
    state.lastOpen, state.lastSheltered = nil, nil
end

-- For the menus. hoursLeft is to fully soured and assumes the temperature holds.
function V.caskStatus(state, ledger, place)
    local temperature = Weather.placeTemperature(ledger, place)
    local rate = V.aceticRate(temperature)
    return {
        temperature = temperature,
        place = place,
        rate = rate,
        hoursLeft = (1 - state.strength) * V.ACETIC_HOURS / (V.caskSpeed(state) * rate),
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

function V.inHoseReach(a, b)
    return a.z == b.z and math.abs(a.x - b.x) <= V.HOSE_REACH and math.abs(a.y - b.y) <= V.HOSE_REACH
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

-- A cask the vessel can reach with a hose, without one of its own.
function V.caskForHose(vessel)
    local here = squareOf(vessel)
    for x = here.x - V.HOSE_REACH, here.x + V.HOSE_REACH do
        for y = here.y - V.HOSE_REACH, here.y + V.HOSE_REACH do
            local square = getCell():getGridSquare(x, y, here.z)
            local objects = square and square:getObjects()
            for i = 0, objects and objects:size() - 1 or -1 do
                local object = objects:get(i)
                if V.isCask(object) and not V.hoseLink(object) then return object end
            end
        end
    end
    return nil
end

function V.connectHose(vessel, cask)
    vessel:getModData().vinegarHose = squareOf(cask)
    cask:getModData().vinegarHose = squareOf(vessel)
end

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
    local available = math.floor(container:getAmount() * 1000 + 0.5)
    ml = math.min(ml, available, V.caskRoom(state))
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

function V.findPliers(inventory)
    return inventory:getFirstTagEvalRecurse(ItemTag.PLIERS, function(item) return not item:isBroken() end)
end

-- Calls test for each station in reach and returns the first it accepts.
function V.findNear(character, test)
    local square = character and character:getCurrentSquare()
    if not square then return nil end
    local cell = getCell()
    for x = square:getX() - V.REACH, square:getX() + V.REACH do
        for y = square:getY() - V.REACH, square:getY() + V.REACH do
            local near = cell:getGridSquare(x, y, square:getZ())
            if near then
                local objects = near:getObjects()
                for i = 0, objects:size() - 1 do
                    local object = objects:get(i)
                    if test(object) then return object end
                end
            end
        end
    end
    return nil
end

local function hasVinegar(object)
    return V.isCask(object) and V.bottlesLeft(V.caskState(object)) > 0
end

function V.findCaskWithVinegar(character)
    return V.findNear(character, hasVinegar)
end

function V.isEmptyBottle(item)
    local fluid = item:getFluidContainer()
    return fluid ~= nil and fluid:isEmpty()
end

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

function V.applySandbox()
    local options = SandboxVars and SandboxVars.TraditionalPreservationVinegar
    if not options then return end
    if options.MaltingDays then V.MALTING_HOURS = options.MaltingDays * 24 end
    if options.AlcoholicDays then V.ALCOHOLIC_HOURS = options.AlcoholicDays * 24 end
    if options.AceticDays then V.ACETIC_HOURS = options.AceticDays * 24 end
    if options.CultureBonus then V.CULTURE_BONUS = options.CultureBonus / 100 end
    if options.TemperatureSensitivity then V.SENSITIVITY = V.SENSITIVITY_SCALES[options.TemperatureSensitivity] or 1 end
    if options.BrewingEffort then V.EFFORT = V.EFFORT_SCALES[options.BrewingEffort] or V.EFFORT end
end

local function applyRecipeTime(name, hours)
    local fullName = RECIPE_MODULE .. name
    local recipe = ScriptManager.instance:getCraftRecipe(fullName)
    if not recipe then
        print("[TraditionalPreservationVinegar] Could not find " .. fullName)
        return
    end
    recipe:Load(fullName, "{ time = " .. tostring(math.floor(hours * SECONDS_PER_HOUR)) .. ", }")
end

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
