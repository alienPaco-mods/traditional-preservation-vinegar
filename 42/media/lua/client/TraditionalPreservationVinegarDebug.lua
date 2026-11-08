-- Traditional Preservation (Vinegar): debug-mode shortcuts for testing. Wort and fermented wort are
-- liquids, so the item list can't spawn them, and these fill a container instead.
if not isDebugEnabled() then return end

local V = TraditionalPreservationVinegar

local function fill(item, fluid)
    local container = item:getFluidContainer()
    container:Empty()
    container:addFluid(fluid, container:getCapacity())
end

local function onFillInventoryMenu(_, context, items)
    for _, entry in ipairs(items) do
        local item = type(entry) == "table" and entry.items[1] or entry
        if item and item:getFluidContainer() then
            context:addOption("[Debug] Fill with Wort", item, fill, V.WORT)
            context:addOption("[Debug] Fill with Fermented Wort", item, fill, V.FERMENTED)
            return
        end
    end
end

Events.OnFillInventoryObjectContextMenu.Add(onFillInventoryMenu)
