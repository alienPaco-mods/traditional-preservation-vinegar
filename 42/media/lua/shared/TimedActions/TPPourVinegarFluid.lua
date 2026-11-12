-- Traditional Preservation (Vinegar): moving liquid by hand between a container and a station.
-- "vesselIn" pours wort into a vessel, "vesselOut" draws fermented wort off into a container, and
-- "caskIn" pours fermented wort into a cask's pool, and "vesselDump" (no item) pours away the vessel's wort.
require "TimedActions/ISBaseTimedAction"
require "TraditionalPreservationVinegar"

TPPourVinegarFluid = ISBaseTimedAction:derive("TPPourVinegarFluid")

local V = TraditionalPreservationVinegar
local Action = require "TraditionalPreservationCore/Action"

local function tankFor(self)
    local input = self.mode == "vesselIn" or self.mode == "vesselDump"
    return V.vesselTank(self.station, input and ResourceIO.Input or ResourceIO.Output)
end

function TPPourVinegarFluid:isValid()
    if self.mode == "vesselDump" then
        local logic = self.station:getComponent(ComponentType.CraftLogic)
        return self.station:getSquare() ~= nil and V.litres(tankFor(self)) > 0 and not (logic and logic:isRunning())
    end
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

function TPPourVinegarFluid:waitToStart()
    self.character:faceThisObject(self.station)
    return self.character:shouldBeTurning()
end

function TPPourVinegarFluid:start()
    self:setActionAnim("Loot")
end

function TPPourVinegarFluid:complete()
    if TraditionalPreservationVinegarWorld then TraditionalPreservationVinegarWorld.track(self.station) end
    if self.mode == "vesselDump" then
        tankFor(self):getFluidContainer():Empty()
        V.tankAge(self.station)
        return true
    end
    local container = self.item:getFluidContainer()
    if self.mode == "vesselIn" then
        V.pourIntoTank(self.station, self.item, getGameTime():getWorldAgeHours())
        tankFor(self):drainFromItem(self.item)
    elseif self.mode == "vesselOut" then
        tankFor(self):drainToItem(self.item)
    else
        -- The cask catches up on its own souring first, so the new wort doesn't count time before it arrived.
        local state = V.caskState(self.station)
        V.updateCaskAt(state, V.getLedger(), self.station)
        local poured = V.pourIntoCask(state, math.floor(container:getAmount() * 1000 + 0.5))
        container:removeFluid(poured / 1000)
    end
    return true
end

function TPPourVinegarFluid:perform()
    ISBaseTimedAction.perform(self)
end

function TPPourVinegarFluid:getDuration()
    if self.mode == "vesselDump" then return Action.pourDuration(self.character, V.litres(tankFor(self)), 20) end
    local container = self.item:getFluidContainer()
    local amount = container and container:getAmount() or 0
    if self.mode == "vesselOut" then amount = container and container:getCapacity() or 0 end
    return Action.pourDuration(self.character, amount, 20)
end

function TPPourVinegarFluid:new(character, station, item, mode)
    local o = ISBaseTimedAction.new(self, character)
    o.station = station
    o.item = item
    o.mode = mode
    o.maxTime = o:getDuration()
    return o
end
