-- Traditional Preservation (Vinegar): moving liquid by hand between a container and a station.
-- "vesselIn" pours wort into a vessel, "vesselOut" draws fermented wort off into a container, and
-- "caskIn" pours fermented wort into a cask's pool.
require "TimedActions/ISBaseTimedAction"
require "TraditionalPreservationVinegar"

ISPourVinegarFluid = ISBaseTimedAction:derive("ISPourVinegarFluid")

local V = TraditionalPreservationVinegar
local BASE_DURATION = 40
local DURATION_PER_LITRE = 12

local function tankFor(self)
    return V.vesselTank(self.station, self.mode == "vesselIn" and ResourceIO.Input or ResourceIO.Output)
end

function ISPourVinegarFluid:isValid()
    if not self.station:getSquare() or not self.character:getInventory():containsRecursive(self.item) then return false end
    local container = self.item:getFluidContainer()
    if not container then return false end
    if self.mode == "vesselIn" then
        local tank = tankFor(self)
        return tank ~= nil and V.holdsOnly(container, V.WORT) and not tank:isFull()
    elseif self.mode == "vesselOut" then
        local tank = tankFor(self)
        return tank ~= nil and not tank:isEmpty() and container:isEmpty()
    end
    return V.holdsOnly(container, V.FERMENTED) and V.caskRoom(V.caskState(self.station)) > 0
end

function ISPourVinegarFluid:waitToStart()
    self.character:faceThisObject(self.station)
    return self.character:shouldBeTurning()
end

function ISPourVinegarFluid:start()
    self:setActionAnim("Loot")
end

function ISPourVinegarFluid:complete()
    if TraditionalPreservationVinegarWorld then TraditionalPreservationVinegarWorld.track(self.station) end
    local container = self.item:getFluidContainer()
    if self.mode == "vesselIn" then
        tankFor(self):drainFromItem(self.item)
    elseif self.mode == "vesselOut" then
        tankFor(self):drainToItem(self.item)
    else
        local poured = V.pourIntoCask(V.caskState(self.station), math.floor(container:getAmount() * 1000 + 0.5))
        container:removeFluid(poured / 1000)
    end
    return true
end

function ISPourVinegarFluid:perform()
    ISBaseTimedAction.perform(self)
end

function ISPourVinegarFluid:getDuration()
    local container = self.item:getFluidContainer()
    local amount = container and container:getAmount() or 0
    if self.mode == "vesselOut" then amount = container and container:getCapacity() or 0 end
    return BASE_DURATION + math.floor(math.min(amount, 20) * DURATION_PER_LITRE)
end

function ISPourVinegarFluid:new(character, station, item, mode)
    local o = ISBaseTimedAction.new(self, character)
    o.station = station
    o.item = item
    o.mode = mode
    o.maxTime = o:getDuration()
    return o
end
