-- Traditional Preservation (Vinegar): the hand jobs at a Malting Floor (TraditionalPreservationVinegarFloor.lua). "put"
-- spreads one carried Steeped Grain (if there is still room when the hands are done), "take" takes one heap off by its id
-- (Green Malt, or the grain as it was, V.heapOutput). One heap an action, so a queue of them shows its progress and stops
-- where the player stops it.
require "TimedActions/ISBaseTimedAction"
require "TraditionalPreservationVinegar"

TPVinegarFloor = ISBaseTimedAction:derive("TPVinegarFloor")

local V = TraditionalPreservationVinegar
local Action = require "TraditionalPreservationCore/Action"
local DURATIONS = { put = 40, take = 30 }

local function carried(self)
    return self.item ~= nil and self.character:getInventory():containsRecursive(self.item)
end

function TPVinegarFloor:isValid()
    if not self.station:getSquare() then return false end
    local record = V.floorOf(self.station)
    if self.mode == "put" then return carried(self) and V.floorRoom(record) > 0 end
    return V.heapById(record, self.id) ~= nil
end

function TPVinegarFloor:waitToStart()
    self.character:faceThisObject(self.station)
    return self.character:shouldBeTurning()
end

function TPVinegarFloor:start()
    self:setActionAnim("Loot")
end

function TPVinegarFloor:complete()
    local now = getGameTime():getWorldAgeHours()
    local record, place = V.floorNow(self.station, now)
    if self.mode == "put" then
        if carried(self) and V.putHeap(record, self.item, now, place) then Action.removeItem(self.item) end
    else
        local heap = V.takeHeap(record, self.id)
        if heap then Actions.addOrDropItem(self.character, V.heapOutput(heap, now)) end
    end
    if TraditionalPreservationVinegarWorld then TraditionalPreservationVinegarWorld.refresh(self.station) end
    return true
end

function TPVinegarFloor:perform()
    ISBaseTimedAction.perform(self)
end

function TPVinegarFloor:getDuration()
    return Action.duration(self.character, DURATIONS[self.mode])
end

-- "put": item is the carried Steeped Grain; "take": id is the heap's id on this floor.
function TPVinegarFloor:new(character, station, mode, item, id)
    local o = ISBaseTimedAction.new(self, character)
    o.station = station
    o.mode = mode
    o.item = item
    o.id = id
    o.maxTime = o:getDuration()
    return o
end
