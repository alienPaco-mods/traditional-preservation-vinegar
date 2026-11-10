-- Traditional Preservation (Vinegar): joining a vessel to a cask with a rubber hose, or taking it off.
-- Pass a cask and a hose to attach from the vessel, or neither to detach from either end. Either way
-- takes pliers, which are kept.
require "TimedActions/ISBaseTimedAction"
require "TraditionalPreservationVinegar"

TPVinegarHose = ISBaseTimedAction:derive("TPVinegarHose")

local V = TraditionalPreservationVinegar
local Action = require "TraditionalPreservationCore/Action"
local DURATION = 150

function TPVinegarHose:isValid()
    if not self.station:getSquare() then return false end
    if not self.pliers:isInPlayerInventory() or self.pliers:isBroken() then return false end
    if not self.cask then return V.hoseLink(self.station) ~= nil end
    return self.cask:getSquare() ~= nil and self.hose:isInPlayerInventory()
        and not V.hoseLink(self.station) and not V.hoseLink(self.cask)
end

function TPVinegarHose:waitToStart()
    self.character:faceThisObject(self.station)
    return self.character:shouldBeTurning()
end

function TPVinegarHose:update()
    self.character:faceThisObject(self.station)
    self.character:setMetabolicTarget(Metabolics.LightWork)
end

function TPVinegarHose:start()
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Low")
end

function TPVinegarHose:complete()
    local inventory = self.character:getInventory()
    if self.cask then
        V.connectHose(self.station, self.cask)
        self.hose:getContainer():Remove(self.hose)
    else
        V.disconnectHose(self.station)
        inventory:AddItem(V.HOSE_ITEM)
    end
    if TraditionalPreservationVinegarWorld then
        TraditionalPreservationVinegarWorld.track(self.station)
        if self.cask then TraditionalPreservationVinegarWorld.track(self.cask) end
    end
    return true
end

function TPVinegarHose:perform()
    ISBaseTimedAction.perform(self)
end

function TPVinegarHose:getDuration()
    return Action.duration(self.character, DURATION)
end

function TPVinegarHose:new(character, station, pliers, cask, hose)
    local o = ISBaseTimedAction.new(self, character)
    o.station = station
    o.pliers = pliers
    o.cask = cask
    o.hose = hose
    o.maxTime = o:getDuration()
    return o
end
