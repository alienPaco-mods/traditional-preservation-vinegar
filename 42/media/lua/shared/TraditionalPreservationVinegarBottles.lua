-- Traditional Preservation (Vinegar): a used-up Vinegar gives its bottle back, as Salt does with shakers.
-- Bottling writes the bottle's type on the Vinegar. Hand crafts such as jarring give that same bottle
-- back, emptied. Anything else that uses one up, and looted vinegar, leaves a plain Crafted Bottle, as
-- vanilla's own replacement can only name one item and the other bottles spawn full of their drink.
require "TraditionalPreservationVinegar"
local Handcraft = require "TraditionalPreservationCore/Handcraft"

local V = TraditionalPreservationVinegar
V.VINEGAR_ITEM = "Base.Vinegar2"
V.SPARE_BOTTLE = "Base.BottleCrafted"

-- Remembers which bottle a Vinegar was filled into. ModData is saved with the item.
function V.markBottle(vinegar, bottleType)
    if vinegar then vinegar:getModData().bottleType = bottleType end
end

-- The bottle a used-up Vinegar gives back: the kind it was filled into, else a Crafted Bottle.
function V.bottleBack(vinegar)
    return vinegar:getModData().bottleType or V.SPARE_BOTTLE
end

-- A Vinegar the craft used up and nobody has given back a bottle for yet.
function V.needsBottleBack(item)
    return item:getFullType() == V.VINEGAR_ITEM and item:getCurrentUses() <= 0 and not item:getModData().bottleGiven
end

-- Gives an empty bottle of the right kind for each Vinegar the craft used up. spares lists the Crafted Bottles
-- the engine already handed over for them (its ReplaceOnDeplete): a Vinegar bottled into a Crafted Bottle keeps
-- one, any other bottle takes its place, so none comes twice and none comes as the wrong kind.
function V.returnBottles(character, usedItems, spares)
    for i = 0, usedItems:size() - 1 do
        local item = usedItems:get(i)
        if V.needsBottleBack(item) then
            item:getModData().bottleGiven = true
            local spare = table.remove(spares)
            local bottleType = V.bottleBack(item)
            if not (spare and bottleType == V.SPARE_BOTTLE) then
                if spare then spare:getContainer():DoRemoveItem(spare) end
                local bottle = instanceItem(bottleType)
                local fluid = bottle and bottle:getFluidContainer()
                if fluid then fluid:Empty() end
                if bottle then Actions.addOrDropItem(character, bottle) end
            end
        end
    end
end

-- The Crafted Bottles in the inventory that aren't in before (a set of items).
local function newSpares(inventory, before)
    local spares = {}
    local all = inventory:getAllTypeRecurse(V.SPARE_BOTTLE)
    for i = 0, all:size() - 1 do
        local bottle = all:get(i)
        if not before[bottle] then table.insert(spares, bottle) end
    end
    return spares
end

-- Vanilla gives every used-up Vinegar back as a Crafted Bottle, so after a hand craft (TP Core's Handcraft, the one
-- wrap of ISHandcraftAction.performRecipe, which Salt uses for its shakers too) the right bottles are given: the
-- Crafted Bottles the craft itself handed over are the ones not carried before it.
Handcraft.around(function(action)
    local inventory = action.character:getInventory()
    local before = {}
    local all = inventory:getAllTypeRecurse(V.SPARE_BOTTLE)
    for i = 0, all:size() - 1 do before[all:get(i)] = true end
    return before
end, function(action, recipeData, before)
    V.returnBottles(action.character, recipeData:getAllConsumedItems(), newSpares(action.character:getInventory(), before))
end)

-- Vanilla Vinegar leaves nothing when used up. This covers every other way of using it up.
function V.applyVinegarBottle()
    local vinegar = ScriptManager.instance:getItem(V.VINEGAR_ITEM)
    if vinegar then vinegar:DoParam("ReplaceOnDeplete = " .. V.SPARE_BOTTLE) end
end

Events.OnInitGlobalModData.Add(V.applyVinegarBottle)
