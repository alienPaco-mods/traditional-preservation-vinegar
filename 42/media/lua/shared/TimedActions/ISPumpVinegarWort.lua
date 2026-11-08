-- Traditional Preservation (Vinegar): pumping fermented wort from a vessel into the cask its hose joins,
-- in the amount the player chose. It takes as long as pouring that much by hand.
require "TimedActions/ISBaseTimedAction"
require "TraditionalPreservationVinegar"

ISPumpVinegarWort = ISBaseTimedAction:derive("ISPumpVinegarWort")

local V = TraditionalPreservationVinegar
local BASE_DURATION = 40
local DURATION_PER_LITRE = 12

function ISPumpVinegarWort:isValid()
    if not self.vessel:getSquare() or not self.cask:getSquare() then return false end
    local tank = V.vesselTank(self.vessel, ResourceIO.Output)
    return tank ~= nil and not tank:isEmpty() and V.caskRoom(V.caskState(self.cask)) >= V.HOSE_MIN_ML
end

function ISPumpVinegarWort:waitToStart()
    self.character:faceThisObject(self.vessel)
    return self.character:shouldBeTurning()
end

function ISPumpVinegarWort:update()
    self.character:setMetabolicTarget(Metabolics.LightWork)
end

function ISPumpVinegarWort:start()
    self:setActionAnim("Loot")
end

function ISPumpVinegarWort:complete()
    if TraditionalPreservationVinegarWorld then
        TraditionalPreservationVinegarWorld.track(self.vessel)
        TraditionalPreservationVinegarWorld.track(self.cask)
    end
    -- The cask catches up on its own souring first, so the new wort doesn't count time before it arrived.
    local state = V.caskState(self.cask)
    V.updateCask(state, V.getLedger(), V.placeOf(self.cask))
    local moved = V.pumpToCask(state, V.vesselTank(self.vessel, ResourceIO.Output):getFluidContainer(), self.ml)
    print(string.format("[TPV] hose pumped %.2f L of fermented wort into the cask", moved / 1000))
    return true
end

function ISPumpVinegarWort:perform()
    ISBaseTimedAction.perform(self)
end

function ISPumpVinegarWort:getDuration()
    return BASE_DURATION + math.floor(math.min(self.ml / 1000, 20) * DURATION_PER_LITRE)
end

function ISPumpVinegarWort:new(character, vessel, cask, ml)
    local o = ISBaseTimedAction.new(self, character)
    o.vessel = vessel
    o.cask = cask
    o.ml = ml
    o.maxTime = o:getDuration()
    return o
end
