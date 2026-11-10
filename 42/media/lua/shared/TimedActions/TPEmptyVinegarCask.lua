-- Traditional Preservation (Vinegar): pouring away what is stored in a cask, which leaves the mother behind.
require "TimedActions/ISBaseTimedAction"
require "TraditionalPreservationVinegar"

TPEmptyVinegarCask = ISBaseTimedAction:derive("TPEmptyVinegarCask")

local V = TraditionalPreservationVinegar
local Action = require "TraditionalPreservationCore/Action"
local DURATION = 150

function TPEmptyVinegarCask:isValid()
    return self.cask:getSquare() ~= nil and V.caskState(self.cask).ml > 0
end

function TPEmptyVinegarCask:waitToStart()
    self.character:faceThisObject(self.cask)
    return self.character:shouldBeTurning()
end

function TPEmptyVinegarCask:start()
    self:setActionAnim("Loot")
end

function TPEmptyVinegarCask:complete()
    V.emptyCask(V.caskState(self.cask))
    return true
end

function TPEmptyVinegarCask:perform()
    ISBaseTimedAction.perform(self)
end

function TPEmptyVinegarCask:getDuration()
    return Action.duration(self.character, DURATION)
end

function TPEmptyVinegarCask:new(character, cask)
    local o = ISBaseTimedAction.new(self, character)
    o.cask = cask
    o.maxTime = o:getDuration()
    return o
end
