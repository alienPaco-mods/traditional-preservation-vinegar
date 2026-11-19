-- Traditional Preservation (Vinegar): pitching a full packet of yeast into a Fermentation Vessel. The batch takes the
-- whole buckets of wort in the Wort tank (V.pitch), and the packet is used up.
require "TimedActions/ISBaseTimedAction"
require "TraditionalPreservationVinegar"

TPPitchVinegarYeast = ISBaseTimedAction:derive("TPPitchVinegarYeast")

local V = TraditionalPreservationVinegar
local Action = require "TraditionalPreservationCore/Action"
local Weather = require "TraditionalPreservationCore/Weather"
local log = require "TraditionalPreservationCore/Log"

local DURATION = 60

function TPPitchVinegarYeast:isValid()
    if not self.vessel:getSquare() or not self.character:getInventory():containsRecursive(self.item) then return false end
    if not V.isFullYeast(self.item) then return false end
    local now = getGameTime():getWorldAgeHours()
    return V.pitchRefusal(V.vesselOf(self.vessel), now, Weather.placeOf(self.vessel)) == nil
end

function TPPitchVinegarYeast:waitToStart()
    self.character:faceThisObject(self.vessel)
    return self.character:shouldBeTurning()
end

function TPPitchVinegarYeast:start()
    self:setActionAnim("Loot")
end

function TPPitchVinegarYeast:complete()
    if TraditionalPreservationVinegarWorld then TraditionalPreservationVinegarWorld.track(self.vessel) end
    local now = getGameTime():getWorldAgeHours()
    local record, place = V.vesselNow(self.vessel, now)
    if V.pitchRefusal(record, now, Weather.placeOf(self.vessel)) then return true end
    local ml = V.pitch(record, now, place)
    if ml then
        Action.removeItem(self.item)
        log("TPV", "vessel batch pitched: %.1f L of wort", ml / 1000)
    end
    if TraditionalPreservationVinegarWorld then TraditionalPreservationVinegarWorld.refresh(self.vessel) end
    return true
end

function TPPitchVinegarYeast:perform()
    ISBaseTimedAction.perform(self)
end

function TPPitchVinegarYeast:getDuration()
    return Action.duration(self.character, DURATION)
end

function TPPitchVinegarYeast:new(character, vessel, item)
    local o = ISBaseTimedAction.new(self, character)
    o.vessel = vessel
    o.item = item
    o.maxTime = o:getDuration()
    return o
end
