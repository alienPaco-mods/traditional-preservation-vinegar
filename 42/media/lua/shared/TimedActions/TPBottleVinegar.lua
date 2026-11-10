-- Traditional Preservation (Vinegar): filling one bottle straight from a cask, from its right-click menu.
-- It does the same as the Bottle Vinegar recipe, without opening the crafting window.
require "TimedActions/ISBaseTimedAction"
require "TraditionalPreservationVinegar"
require "TraditionalPreservationVinegarBottles"

TPBottleVinegar = ISBaseTimedAction:derive("TPBottleVinegar")

local V = TraditionalPreservationVinegar
local Action = require "TraditionalPreservationCore/Action"
local log = require "TraditionalPreservationCore/Log"
local DURATION = 40

function TPBottleVinegar:isValid()
    if not self.cask:getSquare() or not self.character:getInventory():containsRecursive(self.bottle) then return false end
    return V.isEmptyBottle(self.bottle) and V.bottlesLeft(V.caskState(self.cask)) > 0
end

function TPBottleVinegar:waitToStart()
    self.character:faceThisObject(self.cask)
    return self.character:shouldBeTurning()
end

function TPBottleVinegar:start()
    self:setActionAnim("Loot")
end

function TPBottleVinegar:complete()
    local state = V.caskState(self.cask)
    if V.takeBottle(state) then
        log("TPV", "bottled 1 L, %.2f L left in the cask", state.ml / 1000)
        self.character:removeFromHands(self.bottle)
        self.bottle:getContainer():Remove(self.bottle)
        V.markBottle(self.character:getInventory():AddItem("Base.Vinegar2"), self.bottle:getFullType())
        self.character:getXp():AddXP(Perks.Cooking, V.BOTTLE_XP)
    end
    return true
end

function TPBottleVinegar:perform()
    ISBaseTimedAction.perform(self)
end

function TPBottleVinegar:getDuration()
    return Action.duration(self.character, DURATION)
end

function TPBottleVinegar:new(character, cask, bottle)
    local o = ISBaseTimedAction.new(self, character)
    o.cask = cask
    o.bottle = bottle
    o.maxTime = o:getDuration()
    return o
end
