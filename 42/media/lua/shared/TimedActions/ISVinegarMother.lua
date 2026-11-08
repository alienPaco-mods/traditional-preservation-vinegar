-- Traditional Preservation (Vinegar): moving a Mother of Vinegar between a cask and a jar.
-- "take" lifts the whole mother into an empty jar, "split" peels one layer off into a jar and leaves
-- the rest in the cask, and "add" lays a living mother from a jar into a cask that has none.
require "TimedActions/ISBaseTimedAction"
require "TraditionalPreservationVinegar"

ISVinegarMother = ISBaseTimedAction:derive("ISVinegarMother")

local V = TraditionalPreservationVinegar
local DURATION = 120

function ISVinegarMother:isValid()
    if not self.cask:getSquare() or not self.character:getInventory():containsRecursive(self.item) then return false end
    local state = V.caskState(self.cask)
    if self.mode == "add" then
        return not state.mother and self.item:getFullType() == V.MOTHER_ITEM and not self.item:isRotten()
    end
    if not V.isEmptyJar(self.item) then return false end
    if self.mode == "split" then return V.canSplitMother(state) end
    return state.mother == true
end

function ISVinegarMother:waitToStart()
    self.character:faceThisObject(self.cask)
    return self.character:shouldBeTurning()
end

function ISVinegarMother:start()
    self:setActionAnim("Loot")
end

-- Swaps the item in hand for another in the same container, keeping the jar's kind on the mother.
local function swap(character, item, fullType)
    local container = item:getContainer()
    character:removeFromHands(item)
    container:Remove(item)
    return container:AddItem(fullType)
end

function ISVinegarMother:complete()
    local state = V.caskState(self.cask)
    if self.mode == "add" then
        if V.addMother(state) then
            swap(self.character, self.item, self.item:getModData().jarType or "Base.EmptyJar")
        end
        return true
    end
    local moved = self.mode == "split" and V.splitMother(state) or self.mode == "take" and V.takeMother(state)
    if moved then
        local jarType = self.item:getFullType()
        local mother = swap(self.character, self.item, V.MOTHER_ITEM)
        if mother then mother:getModData().jarType = jarType end
    end
    return true
end

function ISVinegarMother:perform()
    ISBaseTimedAction.perform(self)
end

function ISVinegarMother:getDuration()
    return DURATION
end

function ISVinegarMother:new(character, cask, item, mode)
    local o = ISBaseTimedAction.new(self, character)
    o.cask = cask
    o.item = item
    o.mode = mode
    o.maxTime = o:getDuration()
    return o
end
