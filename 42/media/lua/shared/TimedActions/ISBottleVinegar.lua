-- Traditional Preservation (Vinegar): filling one bottle straight from a cask, from its right-click menu.
-- It does the same as the Bottle Vinegar recipe, without opening the crafting window.
require "TimedActions/ISBaseTimedAction"
require "TraditionalPreservationVinegar"
require "TraditionalPreservationVinegarBottles"

ISBottleVinegar = ISBaseTimedAction:derive("ISBottleVinegar")

local V = TraditionalPreservationVinegar
local DURATION = 40

function ISBottleVinegar:isValid()
    if not self.cask:getSquare() or not self.character:getInventory():containsRecursive(self.bottle) then return false end
    return V.isEmptyBottle(self.bottle) and V.bottlesLeft(V.caskState(self.cask)) > 0
end

function ISBottleVinegar:waitToStart()
    self.character:faceThisObject(self.cask)
    return self.character:shouldBeTurning()
end

function ISBottleVinegar:start()
    self:setActionAnim("Loot")
end

function ISBottleVinegar:complete()
    local state = V.caskState(self.cask)
    if V.takeBottle(state) then
        print(string.format("[TPV] bottled 1 L, %.2f L left in the cask", state.ml / 1000))
        self.character:removeFromHands(self.bottle)
        self.bottle:getContainer():Remove(self.bottle)
        V.markBottle(self.character:getInventory():AddItem("Base.Vinegar2"), self.bottle:getFullType())
        self.character:getXp():AddXP(Perks.Cooking, V.BOTTLE_XP)
    end
    return true
end

function ISBottleVinegar:perform()
    ISBaseTimedAction.perform(self)
end

function ISBottleVinegar:getDuration()
    return DURATION
end

function ISBottleVinegar:new(character, cask, bottle)
    local o = ISBaseTimedAction.new(self, character)
    o.cask = cask
    o.bottle = bottle
    o.maxTime = o:getDuration()
    return o
end
