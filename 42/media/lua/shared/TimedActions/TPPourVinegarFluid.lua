-- Traditional Preservation (Vinegar): moving liquid by hand between a container and a station.
-- "vesselIn" pours wort into a vessel (its running batch, or else its Wort tank), "wortOut" draws the Wort tank's wort
-- off into a container (with its age), "vesselOut" draws fermented wort off into a container, and "caskIn" pours
-- fermented wort into a cask's pool. With no item, "vesselDump" pours away
-- the Wort tank and "batchDump" the batch fermenting, yeast and all.
require "TimedActions/ISBaseTimedAction"
require "TraditionalPreservationVinegar"

TPPourVinegarFluid = ISBaseTimedAction:derive("TPPourVinegarFluid")

local V = TraditionalPreservationVinegar
local Action = require "TraditionalPreservationCore/Action"
local Container = require "TraditionalPreservationCore/Container"
local FluidAgeing = require "TraditionalPreservationCore/FluidAgeing"
local Weather = require "TraditionalPreservationCore/Weather"

local DUMPS = { vesselDump = true, batchDump = true }

-- The millilitres a dump pours away.
local function dumpMl(self)
    local record = V.vesselOf(self.station)
    if self.mode == "batchDump" then return record.run and record.run.ml or 0 end
    return record.wortMl
end

function TPPourVinegarFluid:isValid()
    if not self.station:getSquare() then return false end
    if DUMPS[self.mode] then return dumpMl(self) > 0 end
    if not self.character:getInventory():containsRecursive(self.item) then return false end
    local container = self.item:getFluidContainer()
    if not container then return false end
    if self.mode == "vesselIn" then
        local record = V.vesselOf(self.station)
        return V.holdsOnly(container, V.WORT) and V.wortRoom(record) > 0
    elseif self.mode == "vesselOut" then
        return V.vesselOf(self.station).fermentedMl > 0 and container:isEmpty()
    elseif self.mode == "wortOut" then
        return V.vesselOf(self.station).wortMl > 0 and container:isEmpty()
    end
    return V.holdsOnly(container, V.FERMENTED) and V.caskRoom(V.caskModData(self.station)) > 0
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
    if self.mode == "caskIn" then
        -- The cask catches up on its own souring first, so the new wort doesn't count time before it arrived.
        local container = self.item:getFluidContainer()
        local caskModData = V.caskModData(self.station)
        V.updateCaskAt(caskModData, V.getLedger(), self.station)
        local poured = V.pourIntoCask(caskModData, Container.ml(container))
        container:removeFluid(poured / 1000)
        return true
    end
    -- The vessel catches up first, so the wort poured in or the batch poured away is reckoned from now.
    local now = getGameTime():getWorldAgeHours()
    local record = V.vesselNow(self.station, now)
    if self.mode == "vesselDump" then
        V.pourAwayWort(record)
    elseif self.mode == "batchDump" then
        V.pourAwayBatch(record)
    elseif self.mode == "vesselIn" then
        local container = self.item:getFluidContainer()
        local fluidAge = FluidAgeing.sourceFluidAge(self.item, now)
        local poured = V.pourWortIn(record, Container.ml(container), fluidAge, Weather.placeOf(self.station), now)
        container:removeFluid(poured / 1000)
        FluidAgeing.clearIfEmpty(self.item)
    elseif self.mode == "wortOut" then
        -- The container takes the tank's age before the tank forgets it (an emptied tank does).
        local container = self.item:getFluidContainer()
        local fluidAge = record[FluidAgeing.KEY]
        local drawn = V.drawOffWort(record, math.floor(container:getCapacity() * 1000 + 0.5), Weather.placeOf(self.station), now)
        container:addFluid(V.WORT, drawn / 1000)
        if fluidAge then FluidAgeing.receive(self.item:getModData(), fluidAge, false, FluidAgeing.placeOfItem(self.item)) end
    else
        local container = self.item:getFluidContainer()
        local drawn = V.drawOff(record, math.floor(container:getCapacity() * 1000 + 0.5))
        container:addFluid(V.FERMENTED, drawn / 1000)
    end
    if TraditionalPreservationVinegarWorld then TraditionalPreservationVinegarWorld.refresh(self.station) end
    return true
end

function TPPourVinegarFluid:perform()
    ISBaseTimedAction.perform(self)
end

function TPPourVinegarFluid:getDuration()
    if DUMPS[self.mode] then return Action.pourDuration(self.character, dumpMl(self) / 1000, V.POUR_MOST_LITRES) end
    local container = self.item:getFluidContainer()
    local amount = container and container:getAmount() or 0
    if self.mode == "vesselOut" or self.mode == "wortOut" then amount = container and container:getCapacity() or 0 end
    return Action.pourDuration(self.character, amount, V.POUR_MOST_LITRES)
end

function TPPourVinegarFluid:new(character, station, item, mode)
    local o = ISBaseTimedAction.new(self, character)
    o.station = station
    o.item = item
    o.mode = mode
    o.maxTime = o:getDuration()
    return o
end
