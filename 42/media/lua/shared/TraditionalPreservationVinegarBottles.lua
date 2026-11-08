-- Traditional Preservation (Vinegar): a used-up Vinegar gives its bottle back, as Salt does with shakers.
-- Bottling writes the bottle's type on the Vinegar. Hand crafts such as jarring give that same bottle
-- back, emptied. Anything else that uses one up, and looted vinegar, leaves a plain Crafted Bottle, as
-- vanilla's own replacement can only name one item and the other bottles spawn full of their drink.
require "Entity/TimedActions/ISHandcraftAction"
require "TraditionalPreservationVinegar"

local V = TraditionalPreservationVinegar
V.VINEGAR_ITEM = "Base.Vinegar2"
V.SPARE_BOTTLE = "Base.BottleCrafted"

-- Remembers which bottle a Vinegar was filled into. ModData is saved with the item.
function V.markBottle(vinegar, bottleType)
    if vinegar then vinegar:getModData().bottleType = bottleType end
end

function V.bottleBack(vinegar)
    return vinegar:getModData().bottleType or V.SPARE_BOTTLE
end

function V.needsBottleBack(item)
    return item:getFullType() == V.VINEGAR_ITEM and item:getCurrentUses() <= 0 and not item:getModData().bottleGiven
end

-- Gives an empty bottle of the right kind for each Vinegar the craft used up. sparesGiven is how many
-- Crafted Bottles the engine already handed over for them, so none comes twice.
function V.returnBottles(character, usedItems, sparesGiven)
    for i = 0, usedItems:size() - 1 do
        local item = usedItems:get(i)
        if V.needsBottleBack(item) then
            item:getModData().bottleGiven = true
            if sparesGiven > 0 then
                sparesGiven = sparesGiven - 1
            else
                local bottle = instanceItem(V.bottleBack(item))
                local fluid = bottle and bottle:getFluidContainer()
                if fluid then fluid:Empty() end
                if bottle then Actions.addOrDropItem(character, bottle) end
            end
        end
    end
end

local performRecipe = ISHandcraftAction.performRecipe
function ISHandcraftAction:performRecipe()
    local inventory = self.character:getInventory()
    local sparesBefore = inventory:getCountTypeRecurse(V.SPARE_BOTTLE)
    performRecipe(self)
    local recipeData = self.logic and self.logic:getRecipeData()
    if not recipeData then return end
    local sparesGiven = math.max(inventory:getCountTypeRecurse(V.SPARE_BOTTLE) - sparesBefore, 0)
    V.returnBottles(self.character, recipeData:getAllConsumedItems(), sparesGiven)
end

-- Vanilla Vinegar leaves nothing when used up. This covers every other way of using it up.
function V.applyVinegarBottle()
    local vinegar = ScriptManager.instance:getItem(V.VINEGAR_ITEM)
    if vinegar then vinegar:DoParam("ReplaceOnDeplete = " .. V.SPARE_BOTTLE) end
end

Events.OnInitGlobalModData.Add(V.applyVinegarBottle)
