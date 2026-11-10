-- Traditional Preservation (Vinegar): pumping fermented wort from a vessel into the cask its hose joins,
-- in the amount the player chose. It takes as long as pouring that much by hand.
require "TimedActions/ISBaseTimedAction"
require "TraditionalPreservationVinegar"

TPPumpVinegarWort = ISBaseTimedAction:derive("TPPumpVinegarWort")

local V = TraditionalPreservationVinegar
local Action = require "TraditionalPreservationCore/Action"
local log = require "TraditionalPreservationCore/Log"

function TPPumpVinegarWort:isValid()
    if not self.vessel:getSquare() or not self.cask:getSquare() then return false end
    if not V.hoseLink(self.vessel) or not V.hoseLink(self.cask) then return false end
    local tank = V.vesselTank(self.vessel, ResourceIO.Output)
    return tank ~= nil and not tank:isEmpty() and V.caskRoom(V.caskState(self.cask)) >= V.HOSE_MIN_ML
end

function TPPumpVinegarWort:waitToStart()
    self.character:faceThisObject(self.vessel)
    return self.character:shouldBeTurning()
end

function TPPumpVinegarWort:update()
    self.character:setMetabolicTarget(Metabolics.LightWork)
end

function TPPumpVinegarWort:start()
    self:setActionAnim("Loot")
end

function TPPumpVinegarWort:complete()
    if TraditionalPreservationVinegarWorld then
        TraditionalPreservationVinegarWorld.track(self.vessel)
        TraditionalPreservationVinegarWorld.track(self.cask)
    end
    -- The cask catches up on its own souring first, so the new wort doesn't count time before it arrived.
    local state = V.caskState(self.cask)
    V.updateCask(state, V.getLedger(), V.placeOf(self.cask))
    local moved = V.pumpToCask(state, V.vesselTank(self.vessel, ResourceIO.Output):getFluidContainer(), self.ml)
    log("TPV", "hose pumped %.2f L of fermented wort into the cask", moved / 1000)
    return true
end

function TPPumpVinegarWort:perform()
    ISBaseTimedAction.perform(self)
end

function TPPumpVinegarWort:getDuration()
    return Action.pourDuration(self.character, self.ml / 1000, 20)
end

function TPPumpVinegarWort:new(character, vessel, cask, ml)
    local o = ISBaseTimedAction.new(self, character)
    o.vessel = vessel
    o.cask = cask
    o.ml = ml
    o.maxTime = o:getDuration()
    return o
end
