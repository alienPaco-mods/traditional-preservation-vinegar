-- Traditional Preservation (Vinegar): what frost does, on TP Core's Frost (hours at or below a freezing point, counted
-- by place, so a thing left alone catches up when it is next looked at). A Mother of Vinegar in a jar freezes at
-- FREEZE_C, and every hour frozen takes it 1/Frost.STARTER_RUIN_HOURS of the way to rotten. A mother in a cask freezes
-- there too and loses a layer for every Frost.THROUGH_HOURS frozen, never its last: it lives through. Steeped Grain,
-- carried or on the Malting Floor, freezes at 0 C, and frozen through (Frost.THROUGH_HOURS in all) its sprout is dead:
-- it is Spent Grain. Green Malt, Malt, the worts, the mash, the vessel and the cask's vinegar only wait while frozen.
-- A basement never freezes, nor a place by a lit fire or banked embers, nor a powered fridge. The sandbox's Frost
-- harms off: frost does no harm, and the records go on. Required by TraditionalPreservationVinegar.lua, whose V it
-- adds to.
TraditionalPreservationVinegar = TraditionalPreservationVinegar or {}
local V = TraditionalPreservationVinegar
local Frost = require "TraditionalPreservationCore/Frost"
local FluidAgeing = require "TraditionalPreservationCore/FluidAgeing"
local Action = require "TraditionalPreservationCore/Action"

-- Freezing points, named at load so every stretch is counted: the mother at the vinegar's, the wet grain at water's.
V.MOTHER_FROST = Frost.point(V.FREEZE_C)
V.GRAIN_FROST = Frost.point(0)
-- Save keys: never rename them. Item modData: a Mother of Vinegar's or a Steeped Grain's frost record (a Steeped
-- Grain's says sproutDead once frozen through). The cask's movableData: its mother's frost record, with layerHours,
-- the hours frozen toward the next layer lost.
V.FROST_KEY = "tpvFrost"
V.CASK_FROST_KEY = "tpvMotherFrost"
V.SPENT_GRAIN = "TraditionalPreservationVinegar.SpentGrain"

-- The sandbox's "Frost harms"; off, frost does no harm.
function V.frostHarms()
    local options = SandboxVars and SandboxVars.TraditionalPreservationVinegar
    return not options or options.FrostDamage ~= false
end

-- Where an item is now for its frost look (Frost.see's seen): its place (FluidAgeing.placeOfItem: a powered fridge or
-- freezer, else whatever holds it, by a fire too) with the fire noted. Nil when nothing holds it.
function V.itemSeen(item, now)
    local place, fire, holder = FluidAgeing.placeOfItem(item)
    if not place then return nil end
    local seen = { place = place }
    if holder then FluidAgeing.noteFire(seen, fire, holder, now) end
    return seen
end

-- Cooked or burnt items keep vanilla's timers and never freeze: no record, no harm.
function V.frostPasses(item)
    return item:isCooked() or item:isBurnt()
end

-- Brings an item's frost record up to now (place: where it is, else where the item is). Returns the hours frozen
-- since the last look, and the record (0 and nil for a cooked or burnt item).
local function seeFrost(item, kind, now, place)
    if V.frostPasses(item) then return 0, nil end
    now = now or getGameTime():getWorldAgeHours()
    local seen = place and { place = place } or V.itemSeen(item, now)
    if not seen then return 0, item:getModData()[V.FROST_KEY] end
    return Frost.see(item:getModData(), V.FROST_KEY, kind, now, seen)
end

-- A Mother of Vinegar in a jar

-- Moves a mother in a jar hours of frost nearer rotten (vanilla's clock, never past rotten). Also the console's.
function V.frostMother(item, hours)
    if V.frostPasses(item) then return end
    Frost.bite(item, hours, Frost.STARTER_RUIN_HOURS)
end

-- Brings a mother in a jar's frost up to now, and moves it that much nearer rotten.
function V.lookAtMother(item, now, place)
    local hours = seeFrost(item, V.MOTHER_FROST, now, place)
    if hours > 0 and V.frostHarms() then V.frostMother(item, hours) end
end

-- Steeped Grain

-- Hours of frost just added to a Steeped Grain's record: its sprout is dead once they froze it through.
function V.frostSprout(record, hours)
    if Frost.frozenThrough(record, hours) then record.sproutDead = true end
end

-- Brings a carried (or stored) Steeped Grain's frost up to now. True once its sprout is dead: it is to become Spent
-- Grain (V.killSprout), which waits until nothing is moving it.
function V.lookAtSteepedGrain(item, now, place)
    local hours, record = seeFrost(item, V.GRAIN_FROST, now, place)
    if hours > 0 and V.frostHarms() then V.frostSprout(record, hours) end
    return V.sproutDead(item)
end

function V.sproutDead(item)
    local record = item:getModData()[V.FROST_KEY]
    return record ~= nil and record.sproutDead == true
end

-- Puts Spent Grain where a Steeped Grain with a dead sprout is (in a container or on the ground). Returns it, or nil
-- when the grain is nowhere.
function V.killSprout(item)
    return Action.replaceItem(item, instanceItem(V.SPENT_GRAIN))
end

-- A heap on the Malting Floor: hours of frost just added to its record (heap.frost) kill its sprout once they froze it
-- through; from now it is Spent Grain.
function V.frostHeap(heap, hours, now)
    if Frost.frozenThrough(heap.frost, hours) then heap.deadAt = now end
end

-- A mother in a cask

local LAYER_SLACK = 1e-6

-- Takes a layer off a cask's mother for every THROUGH_HOURS frozen, never the last; the hours short of a layer wait
-- for the next frost. Also the console's.
function V.frostCaskMother(caskModData, hours)
    local record = caskModData[V.CASK_FROST_KEY]
    if not caskModData.mother or not record then return end
    local frozen = (record.layerHours or 0) + hours
    -- Ten-minute readings add up to a hair under the whole hours: LAYER_SLACK lets six hours be six.
    local lost = math.floor(frozen / Frost.THROUGH_HOURS + LAYER_SLACK)
    record.layerHours = math.max(frozen - lost * Frost.THROUGH_HOURS, 0)
    caskModData.layers = math.max(V.motherLayers(caskModData) - lost, 1)
end

-- Brings a cask's mother's frost up to now at the cask's place, by its fire notes (as its souring), and takes the
-- layers off. A cask without a mother keeps no record; a new mother starts one.
function V.caskFrost(caskModData, now, place)
    if not caskModData.mother then
        caskModData[V.CASK_FROST_KEY] = nil
        return
    end
    local record = caskModData[V.CASK_FROST_KEY]
    if not record then
        caskModData[V.CASK_FROST_KEY] = Frost.newRecord(V.MOTHER_FROST, now, place)
        return
    end
    local hours = Frost.catchUp(record, V.MOTHER_FROST, now, place, caskModData)
    if hours > 0 and V.frostHarms() then V.frostCaskMother(caskModData, hours) end
end
