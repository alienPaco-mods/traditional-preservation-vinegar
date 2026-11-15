-- Traditional Preservation (Vinegar): debug-mode shortcuts for testing. Wort and fermented wort are
-- liquids, so the item list can't spawn them, and these fill a container instead.
if not isDebugEnabled() then return end

local V = TraditionalPreservationVinegar
local UI = require "TraditionalPreservationCore/UI"

local function fill(item, fluid)
    local container = item:getFluidContainer()
    container:Empty()
    container:addFluid(fluid, container:getCapacity())
end

local function onFillInventoryMenu(_, context, items)
    local item = UI.firstSelected(items, function(item) return item:getFluidContainer() ~= nil end)
    if not item then return end
    context:addOption("[Debug] Fill with Wort", item, fill, V.WORT)
    context:addOption("[Debug] Fill with Fermented Wort", item, fill, V.FERMENTED)
end

Events.OnFillInventoryObjectContextMenu.Add(onFillInventoryMenu)
