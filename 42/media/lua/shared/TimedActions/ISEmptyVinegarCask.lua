-- Traditional Preservation (Vinegar): pouring away what is stored in a cask, which leaves the mother behind.
require "TimedActions/ISBaseTimedAction"
require "TraditionalPreservationVinegar"

ISEmptyVinegarCask = ISBaseTimedAction:derive("ISEmptyVinegarCask")

local V = TraditionalPreservationVinegar
local DURATION = 150

function ISEmptyVinegarCask:isValid()
    return self.cask:getSquare() ~= nil and V.caskState(self.cask).ml > 0
end

function ISEmptyVinegarCask:waitToStart()
    self.character:faceThisObject(self.cask)
    return self.character:shouldBeTurning()
end

function ISEmptyVinegarCask:start()
    self:setActionAnim("Loot")
end

function ISEmptyVinegarCask:complete()
    V.emptyCask(V.caskState(self.cask))
    return true
end

function ISEmptyVinegarCask:perform()
    ISBaseTimedAction.perform(self)
end

function ISEmptyVinegarCask:getDuration()
    return DURATION
end

function ISEmptyVinegarCask:new(character, cask)
    local o = ISBaseTimedAction.new(self, character)
    o.cask = cask
    o.maxTime = o:getDuration()
    return o
end
