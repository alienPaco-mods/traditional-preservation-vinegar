-- Traditional Preservation (Vinegar): keeps wrong items out of the station slots, shows the vessel's
-- tanks in its window, and adds a running batch's popup and the right-click options on the vessel and cask.
require "Entity/ISUI/Components/Crafting/ISCraftLogicPanel"
require "Entity/ISUI/Components/Crafting/ISWidgetCraftLogicControl"
require "Entity/ISUI/Components/Crafting/ISWidgetCraftLogicInputControl"
require "Entity/ISUI/Controls/ISItemSlot"
require "Entity/ISUI/Controls/ISFluidSlotPanel"
require "Entity/ISUI/Components/Crafting/ISWidgetCraftLogicOutputProgress"
require "Moveables/ISMoveableSpriteProps"
require "Context/World/ISContextEntity"
require "TimedActions/ISVinegarMother"
require "TimedActions/ISBottleVinegar"
require "TimedActions/ISEmptyVinegarCask"
require "TimedActions/ISPourVinegarFluid"
require "TimedActions/ISVinegarHose"
require "TimedActions/ISPumpVinegarWort"
require "ISUI/ISCollapsableWindow"

local V = TraditionalPreservationVinegar
local vanillaItemSlotAddItems = ISCraftLogicPanel.ItemSlotAddItems
local vanillaCreateChildren = ISCraftLogicPanel.createChildren
local vanillaVerifyItem = ISItemSlot.defaultVerifyItem
local vanillaMouseUp = ISItemSlot.onMouseUp
local vanillaCanPickUp = ISMoveableSpriteProps.canPickUpMoveable
local vanillaInfoFlags = ISMoveableSpriteProps.getInfoPanelFlagsPerTile
local vanillaProgressItems = ISWidgetCraftLogicOutputProgress.updateProgressItems
local vanillaStartCraft = ISWidgetCraftLogicControl.startCraft
local vanillaOutputTeaser = ISWidgetCraftLogicInputControl.updateOutputItems

local BATCH_RECIPES = { MaltGrain = "malting", FermentWort = "alcoholic" }
local TOOLTIP_PADDING = 5
local TOOLTIP_MIN_WIDTH = 150
local SLOW_RATE = 0.5
local VINEGAR_ICON = "Item_Vinegar"
local HOSE_ICON = "Item_RubberHose"
local WORT_ICON = "media/textures/Item_BucketWort.png"
local FERMENTED_ICON = "media/textures/Item_BucketFermentedWort.png"
local STATION_ICONS = {
    floor = "media/textures/Item_MaltingFloor.png",
    vessel = "media/textures/Item_FermentationVessel.png",
    cask = "media/textures/Item_VinegarCask.png",
}

-- The game's translator reads a finished line again as a format pattern, so a percentage followed by
-- a word ("40% soured") makes it throw, and so does a line with %1 given no values. So it is given
-- plain tokens, and the values go in here.
local function say(key, ...)
    local values = { ... }
    local tokens = {}
    for index = 1, select("#", ...) do tokens[index] = "@" .. index .. "@" end
    return (string.gsub(getText(key, unpack(tokens)), "@(%d)@", function(index) return tostring(values[tonumber(index)]) end))
end

local PLACE_TEXT = {
    Open = "IGUI_TraditionalPreservationVinegar_TemperatureOpen",
    Sheltered = "IGUI_TraditionalPreservationVinegar_TemperatureRoof",
    Basement = "IGUI_TraditionalPreservationVinegar_TemperatureBasement",
}

local function isStation(entity)
    return V.stationKind(entity) ~= nil
end

local function shortName(recipe)
    return string.gsub(recipe:getName(), "^.*%.", "")
end

local function percent(share)
    return string.format("%.0f%%", share * 100)
end

local function litresText(litres)
    return string.format("%.1f", litres)
end

-- A basement holds one temperature all year, so its time left needs no caveat.
local function timeText(hours, place)
    local whole = math.ceil(hours)
    local key = place == "Basement" and "IGUI_TraditionalPreservationVinegar_TimeSteady" or "IGUI_TraditionalPreservationVinegar_Time"
    return say(key, string.format("%.0f", math.floor(whole / 24)), string.format("%.0f", whole % 24))
end

local function tooltipFor(option, text)
    local tooltip = ISWorldObjectContextMenu.addToolTip()
    tooltip.description = text
    option.toolTip = tooltip
end

-- queued is how many items are already on their way in.
local function refusal(entity, component, resource, item, queued)
    local kind = V.stationKind(entity)
    local wrongItem = V.inputRefusal(kind, item:getFullType())
    if wrongItem then return wrongItem end
    -- The run uses the whole packet, so it has to be a whole packet.
    if kind == "vessel" and item:getCurrentUsesFloat() < 1 then return "IGUI_TraditionalPreservationVinegar_FullYeast" end
    if component:isRunning() then return "IGUI_TraditionalPreservationVinegar_InUse" end
    if resource:getFreeItemCapacity() <= queued then return "IGUI_TraditionalPreservationVinegar_Full" end
    return nil
end

local function canAdd(action)
    return not refusal(action.entity, action.component, action.resource, action.item, 0)
end

-- Vanilla's ItemSlotAddItems with canAdd in place of its limit, because each queued action
-- has to re-check it when it runs. Compare this with vanilla after a game update.
function ISCraftLogicPanel.ItemSlotAddItems(player, entity, itemSlot, itemList, component)
    if not isStation(entity) then
        return vanillaItemSlotAddItems(player, entity, itemSlot, itemList, component)
    end
    if TraditionalPreservationVinegarWorld then TraditionalPreservationVinegarWorld.track(entity) end

    for index, item in ipairs(itemList) do
        local reason = refusal(entity, component, itemSlot.resource, item, index - 1)
        if reason then
            HaloTextHelper.addBadText(player, getText(reason))
            return
        end
        if index == 1 and not ISEntityUI.WalkToEntity(player, entity) then return end

        local action = ISItemSlotAddAction:new(player, entity, item, itemSlot.resource, itemSlot)
        action.component = component
        action.canAddItem = canAdd
        ISTimedActionQueue.add(action)
    end
end

-- The station an input slot belongs to, or nil for any other slot.
local function slotStation(itemSlot)
    local resource = itemSlot and itemSlot.resource
    if not resource or resource:getIO() ~= ResourceIO.Input then return nil end
    local entity = resource:getGameEntity()
    if not isStation(entity) then return nil end
    local component = entity:getComponent(ComponentType.CraftLogic)
    if not component then return nil end
    return entity, component
end

function ISItemSlot:defaultVerifyItem(itemSlot, item)
    if not vanillaVerifyItem(self, itemSlot, item) then return false end
    local entity, component = slotStation(itemSlot)
    if not entity then return true end
    return not refusal(entity, component, itemSlot.resource, item, 0)
end

-- The reason to show when nothing being dragged can go in this slot.
local function dropRefusal(itemSlot)
    if not ISMouseDrag.dragging or ISMouseDrag.draggingFocus == itemSlot then return nil end
    local entity, component = slotStation(itemSlot)
    if not entity then return nil end

    local reason
    for _, item in ipairs(ISInventoryPane.getActualItems(ISMouseDrag.dragging)) do
        local itemReason = refusal(entity, component, itemSlot.resource, item, 0)
        if not itemReason then return nil end
        reason = reason or itemReason
    end
    return reason
end

-- A refused drop does nothing in vanilla, so this says why.
function ISItemSlot:onMouseUp(x, y)
    local reason = dropRefusal(self)
    if reason then HaloTextHelper.addBadText(getPlayer(), getText(reason)) end
    return vanillaMouseUp(self, x, y)
end

-- A cask's pool, a vessel's tanks and a running batch don't go with a station into a backpack.
local function holdsLiquid(object)
    if not object then return false end
    -- A hosed station would leave the hose and its partner behind.
    if (V.isCask(object) or V.isVessel(object)) and V.hoseLink(object) then return true end
    if V.isCask(object) then return V.caskState(object).ml > 0 end
    if not V.isVessel(object) then return false end
    local logic = object:getComponent(ComponentType.CraftLogic)
    return (logic ~= nil and logic:isRunning())
        or V.litres(V.vesselTank(object, ResourceIO.Input)) > 0
        or V.litres(V.vesselTank(object, ResourceIO.Output)) > 0
end

-- Picking up can break a station, and a broken one would lose what it holds.
function ISMoveableSpriteProps:canPickUpMoveable(character, square, object)
    if holdsLiquid(object) then return false end
    return vanillaCanPickUp(self, character, square, object)
end

-- And the pick-up cursor says why, with vanilla's own line for a full container.
function ISMoveableSpriteProps:getInfoPanelFlagsPerTile(square, object, player, mode)
    vanillaInfoFlags(self, square, object, player, mode)
    if mode == "pickup" and holdsLiquid(object) then InfoPanelFlags.hasItems = true end
end

local TANK_TITLES = { [ResourceIO.Input] = "IGUI_TraditionalPreservationVinegar_TankWort", [ResourceIO.Output] = "IGUI_TraditionalPreservationVinegar_TankFermented" }

-- Vanilla never shows a station's fluid tanks, so the vessel's window gets a column for each, named
-- for what it holds. The title has to be set before the panel builds its label.
function ISCraftLogicPanel:createChildren()
    vanillaCreateChildren(self)
    if not (self.tableLayout and V.isVessel(self.entity)) then return end
    for _, io in ipairs({ ResourceIO.Input, ResourceIO.Output }) do
        local tank = V.vesselTank(self.entity, io)
        if tank then
            local panel = ISXuiSkin.build(self.xuiSkin, nil, ISFluidSlotPanel, 0, 0, 20, 20, self.player, self.entity, nil)
            panel.title = getText(TANK_TITLES[io])
            panel:initialise()
            panel:instantiate()
            panel:addResource(tank, nil, nil, nil, nil)
            local column = self.tableLayout:addColumn(nil)
            self.tableLayout:setElement(column:index(), 0, panel)
        end
    end
end

-- The vessel's recipe gives a marker item that the world code turns into fermented wort, so the window's
-- output preview would show the marker. The box stays, empty: the Fermented tank shows what comes out.
function ISWidgetCraftLogicInputControl:updateOutputItems()
    vanillaOutputTeaser(self)
    if self.outputItems and V.isVessel(self.entity) then
        self.outputItems:removeAllSlots()
        self.outputItems:addDisplayEmptySlot("S_ItemSlot_OutputAux")
    end
end

-- Vanilla leaves Craft enabled when the vessel can't run and then does nothing, and each press asks for
-- one more run even with one going, so this checks first and says why.
function ISWidgetCraftLogicControl:startCraft()
    if V.isVessel(self.entity) then
        local logic = self.entity:getComponent(ComponentType.CraftLogic)
        local reason
        if logic and logic:isRunning() then
            reason = "IGUI_TraditionalPreservationVinegar_InUse"
        elseif V.batchMl(V.litres(V.vesselTank(self.entity, ResourceIO.Input)) * 1000) <= 0 then
            reason = "IGUI_TraditionalPreservationVinegar_NeedsWort"
        elseif V.litres(V.vesselTank(self.entity, ResourceIO.Output)) > 0 then
            reason = "IGUI_TraditionalPreservationVinegar_DrawOffFirst"
        end
        if reason then
            HaloTextHelper.addBadText(self.player, getText(reason))
            return
        end
    end
    return vanillaStartCraft(self)
end

local function addLine(layout, label, value, r, g, b)
    local item = layout:addItem()
    item:setLabel(getText(label) .. ":", 1, 1, 0.8, 1)
    item:setValue(value, r or 1, g or 1, b or 1, 1)
end

-- Vanilla's popup goes by the recipe's time alone, so a running batch gets this instead. It runs
-- twice, once to measure and once to draw.
local function drawBatchTooltip(slot, tooltip, kind, station)
    local data = slot.craftRecipeData
    -- A batch that has just finished hands its data back to the engine's pool before the slot goes.
    local recipe = data and data:getRecipe()
    if not recipe then return end
    local status = V.batchStatus(kind, data:getModData(), recipe:getTime() / 3600, V.getLedger())
    local title = getText("EC_CraftLogic_Progress")
    tooltip:DrawText(tooltip:getFont(), title, TOOLTIP_PADDING, TOOLTIP_PADDING, 1, 1, 0.8, 1)
    tooltip:adjustWidth(TOOLTIP_PADDING, title)

    local layout = tooltip:beginLayout()
    addLine(layout, "IGUI_TraditionalPreservationVinegar_Progress", percent(status.progress))
    -- The run holds its wort, so the vessel's Wort tank reads empty while it ferments.
    local run = kind == "alcoholic" and station and station:getModData().vinegarRun
    if run then addLine(layout, "IGUI_TraditionalPreservationVinegar_InRun", say("IGUI_TraditionalPreservationVinegar_Litres", litresText(run.ml / 1000))) end
    addLine(layout, "IGUI_TraditionalPreservationVinegar_TimeLeft", timeText(status.hoursLeft, status.place))
    local place = PLACE_TEXT[status.place]
    addLine(layout, "IGUI_TraditionalPreservationVinegar_Temperature", say(place, string.format("%.0f", status.temperature)))
    if status.rate < SLOW_RATE then
        addLine(layout, "IGUI_TraditionalPreservationVinegar_RateLabel", percent(status.rate), 1, 0.7, 0.4)
    else
        addLine(layout, "IGUI_TraditionalPreservationVinegar_RateLabel", percent(status.rate))
    end
    if status.heatLoss > 0 then
        addLine(layout, "IGUI_TraditionalPreservationVinegar_Heat", say("IGUI_TraditionalPreservationVinegar_HeatLoss", percent(status.heatLoss)), 1, 0.35, 0.3)
    end
    local bottom = layout:render(TOOLTIP_PADDING, TOOLTIP_PADDING + tooltip:getLineSpacing(), tooltip)
    tooltip:endLayout(layout)
    tooltip:setHeight(bottom + TOOLTIP_PADDING)
    tooltip:setWidth(math.max(tooltip:getWidth(), TOOLTIP_MIN_WIDTH))
end

function ISWidgetCraftLogicOutputProgress:updateProgressItems()
    vanillaProgressItems(self)
    for _, slot in ipairs(self.progressItems:getItemSlots()) do
        local recipe = slot.craftRecipeData and slot.craftRecipeData:getRecipe()
        local kind = recipe and BATCH_RECIPES[shortName(recipe)]
        if kind then
            local station = self.entity
            slot.drawTooltip = function(itemSlot, tooltip) drawBatchTooltip(itemSlot, tooltip, kind, station) end
        end
    end
end

-- Every item on the player or in containers in reach that passes test.
local function findItems(playerObj, test)
    local found = {}
    local containers = ISInventoryPaneContextMenu.getContainers(playerObj)
    for i = 0, containers:size() - 1 do
        local items = containers:get(i):getItems()
        for j = 0, items:size() - 1 do
            local item = items:get(j)
            if not item:isFavorite() and test(item) then table.insert(found, item) end
        end
    end
    return found
end

local function onPour(playerObj, station, items, mode)
    if not ISEntityUI.WalkToEntity(playerObj, station) then return end
    for _, item in ipairs(items) do
        ISInventoryPaneContextMenu.transferIfNeeded(playerObj, item)
        ISTimedActionQueue.add(ISPourVinegarFluid:new(playerObj, station, item, mode))
    end
end

-- One option per container holding the right liquid, plus "all" when there are several.
local function addPourMenu(context, label, playerObj, station, items, mode, emptyText, icon)
    local option = context:addOption(label)
    option.iconTexture = getTexture(icon)
    if #items == 0 then
        option.isDisabled = true
        tooltipFor(option, emptyText)
        return
    end
    local menu = context:getNew(context)
    context:addSubMenu(option, menu)
    if #items > 1 then
        menu:addOption(say("ContextMenu_TraditionalPreservationVinegar_AllContainers", tostring(#items)), playerObj, onPour, station, items, mode)
    end
    for _, item in ipairs(items) do
        local fluid = item:getFluidContainer()
        -- Empty containers are told apart by what they hold, full ones by what is in them.
        local label = mode == "vesselOut" and say("IGUI_TraditionalPreservationVinegar_Holds", litresText(fluid:getCapacity()))
            or litresText(fluid:getAmount()) .. " L"
        local entry = menu:addOption(item:getDisplayName() .. " (" .. label .. ")", playerObj, onPour, station, { item }, mode)
        entry.iconTexture = item:getTex()
    end
end

local function onHose(playerObj, station, pliers, cask, hose)
    if not ISEntityUI.WalkToEntity(playerObj, station) then return end
    ISInventoryPaneContextMenu.transferIfNeeded(playerObj, pliers)
    if hose then ISInventoryPaneContextMenu.transferIfNeeded(playerObj, hose) end
    ISTimedActionQueue.add(ISVinegarHose:new(playerObj, station, pliers, cask, hose))
end

local function disableWith(option, key)
    option.isDisabled = true
    tooltipFor(option, getText(key))
end

local function onPump(playerObj, vessel, cask, ml)
    ISTimedActionQueue.add(ISPumpVinegarWort:new(playerObj, vessel, cask, ml))
end

-- Pump to Cask, on either station while joined: fixed amounts, up to the air line and all that fits,
-- each greyed out with the reason when it can't be done.
local function addPumpMenu(menu, playerObj, station, partner)
    local vessel, cask = station, partner
    if not V.isVessel(station) then vessel, cask = partner, station end
    local tank = V.vesselTank(vessel, ResourceIO.Output)
    local available = tank and math.floor(V.litres(tank) * 1000 + 0.5) or 0
    local option = menu:addOption(getText("ContextMenu_TraditionalPreservationVinegar_PumpToCask"))
    option.iconTexture = getTexture(FERMENTED_ICON)
    local pumps = menu:getNew(menu)
    menu:addSubMenu(option, pumps)
    for _, choice in ipairs(V.pumpChoices(V.caskState(cask), available)) do
        local litres = litresText((choice.wanted or choice.ml) / 1000)
        local label = choice.kind == "step" and say("ContextMenu_TraditionalPreservationVinegar_PumpLitres", litres)
            or say(choice.kind == "air" and "ContextMenu_TraditionalPreservationVinegar_PumpAirLine" or "ContextMenu_TraditionalPreservationVinegar_PumpAll", litres)
        local entry = pumps:addOption(label, playerObj, onPump, vessel, cask, choice.ml)
        if choice.reason then
            entry.isDisabled = true
            tooltipFor(entry, say(choice.reason, litresText((choice.reasonMl or 0) / 1000)))
        elseif choice.kind == "air" then
            tooltipFor(entry, say("IGUI_TraditionalPreservationVinegar_PumpAirHelp", litresText(V.AIR_ML / 1000)))
        end
    end
end

-- The hose options on either station: a grey line naming the other end, Pump to Cask and Detach Hose
-- when joined, and on a vessel, Attach Hose to Cask when not.
local function addHoseMenu(menu, playerObj, station)
    local pliers = V.findPliers(playerObj:getInventory())
    if V.hoseLink(station) then
        local line = menu:addOption(getText(V.isVessel(station) and "IGUI_TraditionalPreservationVinegar_HoseToCask" or "IGUI_TraditionalPreservationVinegar_HoseToVessel"))
        line.isDisabled = true
        tooltipFor(line, getText("IGUI_TraditionalPreservationVinegar_HoseHelp"))
        local partner = V.hosePartner(station)
        if partner then addPumpMenu(menu, playerObj, station, partner) end
        local detach = menu:addOption(getText("ContextMenu_TraditionalPreservationVinegar_DetachHose"), playerObj, onHose, station, pliers)
        detach.iconTexture = getTexture(HOSE_ICON)
        if pliers then tooltipFor(detach, getText("IGUI_TraditionalPreservationVinegar_DetachHelp")) else disableWith(detach, "IGUI_TraditionalPreservationVinegar_NeedPliers") end
        return
    end
    if not V.isVessel(station) then return end
    local cask = V.caskForHose(station)
    local hose = findItems(playerObj, function(item) return item:getFullType() == V.HOSE_ITEM end)[1]
    local attach = menu:addOption(getText("ContextMenu_TraditionalPreservationVinegar_AttachHose"), playerObj, onHose, station, pliers, cask, hose)
    attach.iconTexture = getTexture(HOSE_ICON)
    if not cask then
        disableWith(attach, "IGUI_TraditionalPreservationVinegar_NoCaskInReach")
    elseif not hose then
        disableWith(attach, "IGUI_TraditionalPreservationVinegar_NeedHose")
    elseif not pliers then
        disableWith(attach, "IGUI_TraditionalPreservationVinegar_NeedPliers")
    else
        tooltipFor(attach, getText("IGUI_TraditionalPreservationVinegar_HoseHelp"))
    end
end

local function vesselStatus(vessel)
    local logic = vessel:getComponent(ComponentType.CraftLogic)
    local input = V.litres(V.vesselTank(vessel, ResourceIO.Input))
    local output = V.litres(V.vesselTank(vessel, ResourceIO.Output))
    local craftData = V.runningBatch(vessel, logic)
    if craftData then
        local run = vessel:getModData().vinegarRun
        return say("IGUI_TraditionalPreservationVinegar_VesselRunning", litresText(run and run.ml / 1000 or 0), percent(logic:getProgress(craftData)))
    end
    if output > 0 then return say("IGUI_TraditionalPreservationVinegar_VesselReady", litresText(output)) end
    if input > 0 then return say("IGUI_TraditionalPreservationVinegar_VesselWaiting", litresText(input)) end
    return getText("IGUI_TraditionalPreservationVinegar_VesselEmpty")
end

local function addVesselMenu(context, playerObj, vessel)
    local status = context:addOption(vesselStatus(vessel))
    status.isDisabled = true
    status.iconTexture = getTexture(STATION_ICONS.vessel)
    tooltipFor(status, getText("IGUI_TraditionalPreservationVinegar_VesselHelp"))

    local logic = vessel:getComponent(ComponentType.CraftLogic)
    local input, output = V.vesselTank(vessel, ResourceIO.Input), V.vesselTank(vessel, ResourceIO.Output)
    if input and not input:isFull() and not (logic and logic:isRunning()) then
        local worts = findItems(playerObj, function(item) return V.holdsOnly(item:getFluidContainer(), V.WORT) end)
        addPourMenu(context, getText("ContextMenu_TraditionalPreservationVinegar_PourWort"), playerObj, vessel, worts, "vesselIn", getText("IGUI_TraditionalPreservationVinegar_NoWort"), WORT_ICON)
    end
    if output and not output:isEmpty() then
        -- Only empty containers, so nothing is ever topped up into a mixture.
        local empties = findItems(playerObj, function(item)
            local fluid = item:getFluidContainer()
            return fluid ~= nil and fluid:isEmpty() and fluid:getCapacity() > 0
        end)
        addPourMenu(context, getText("ContextMenu_TraditionalPreservationVinegar_DrawOff"), playerObj, vessel, empties, "vesselOut", getText("IGUI_TraditionalPreservationVinegar_NoContainer"), FERMENTED_ICON)
    end
    addHoseMenu(context, playerObj, vessel)
end

local function onBottle(playerObj, cask, bottles, count)
    if not ISEntityUI.WalkToEntity(playerObj, cask) then return end
    for index = 1, math.min(count, #bottles) do
        ISInventoryPaneContextMenu.transferIfNeeded(playerObj, bottles[index])
        ISTimedActionQueue.add(ISBottleVinegar:new(playerObj, cask, bottles[index]))
    end
end

local function addBottleMenu(context, playerObj, cask, state)
    local option = context:addOption(getText("ContextMenu_TraditionalPreservationVinegar_Bottle"))
    option.iconTexture = getTexture(VINEGAR_ICON)
    local types = V.bottleTypes()
    local bottles = findItems(playerObj, function(item) return types[item:getFullType()] and V.isEmptyBottle(item) end)
    if #bottles == 0 then
        option.isDisabled = true
        tooltipFor(option, getText("IGUI_TraditionalPreservationVinegar_NoBottles"))
        return
    end

    local menu = context:getNew(context)
    context:addSubMenu(option, menu)
    -- With one kind of bottle, its own icon shows what gets filled. With several, the rows below show each.
    local groups = V.groupBottles(bottles)
    local icon = #groups == 1 and bottles[1]:getTex() or getTexture(VINEGAR_ICON)
    local any = menu:addOption(getText("ContextMenu_TraditionalPreservationVinegar_AnyBottle"), playerObj, onBottle, cask, bottles, 1)
    any.iconTexture = icon
    local most = math.min(#bottles, V.bottlesLeft(state))
    local all = menu:addOption(say("ContextMenu_TraditionalPreservationVinegar_AllBottles", tostring(most)), playerObj, onBottle, cask, bottles, most)
    all.iconTexture = icon
    -- Picking a kind only helps when there is more than one.
    if #groups < 2 then return end
    for _, group in ipairs(groups) do
        local kind = menu:addOption(group.name .. " (" .. #group.items .. ")", playerObj, onBottle, cask, group.items, 1)
        kind.iconTexture = group.items[1]:getTex()
    end
end

local function onMother(playerObj, cask, item, mode)
    if not ISEntityUI.WalkToEntity(playerObj, cask) then return end
    ISInventoryPaneContextMenu.transferIfNeeded(playerObj, item)
    ISTimedActionQueue.add(ISVinegarMother:new(playerObj, cask, item, mode))
end

-- One option for the mother, greyed with the reason when it can't be done.
local function addMotherOption(menu, label, playerObj, cask, item, mode, help, missing)
    local option = menu:addOption(getText(label), playerObj, onMother, cask, item, mode)
    option.iconTexture = getTexture("media/textures/Item_MotherOfVinegar.png")
    if item then
        tooltipFor(option, getText(help))
    else
        option.isDisabled = true
        tooltipFor(option, getText(missing))
    end
end

local function addMotherMenu(menu, playerObj, cask, state)
    if state.mother then
        local jar = findItems(playerObj, V.isEmptyJar)[1]
        addMotherOption(menu, "ContextMenu_TraditionalPreservationVinegar_TakeMother", playerObj, cask, jar, "take",
            "IGUI_TraditionalPreservationVinegar_TakeMother", "IGUI_TraditionalPreservationVinegar_NoJar")
        if V.canSplitMother(state) then
            addMotherOption(menu, "ContextMenu_TraditionalPreservationVinegar_SplitMother", playerObj, cask, jar, "split",
                "IGUI_TraditionalPreservationVinegar_SplitMother", "IGUI_TraditionalPreservationVinegar_NoJar")
        else
            -- Shown greyed, so the player knows it exists and what it's waiting for.
            local split = menu:addOption(getText("ContextMenu_TraditionalPreservationVinegar_SplitMother"))
            split.iconTexture = getTexture("media/textures/Item_MotherOfVinegar.png")
            split.isDisabled = true
            tooltipFor(split, say("IGUI_TraditionalPreservationVinegar_SplitNotYet", tostring(V.motherLayers(state)), litresText(V.nextLayerMl(state) / 1000)))
        end
        return
    end
    local mothers = findItems(playerObj, function(item) return item:getFullType() == V.MOTHER_ITEM end)
    local living
    for _, mother in ipairs(mothers) do
        if not mother:isRotten() then living = mother break end
    end
    local missing = #mothers > 0 and "IGUI_TraditionalPreservationVinegar_DeadMother" or "IGUI_TraditionalPreservationVinegar_NoMother"
    addMotherOption(menu, "ContextMenu_TraditionalPreservationVinegar_AddMother", playerObj, cask, living, "add",
        "IGUI_TraditionalPreservationVinegar_AddMother", missing)
end

local function onEmptyCask(playerObj, cask)
    if ISEntityUI.WalkToEntity(playerObj, cask) then
        ISTimedActionQueue.add(ISEmptyVinegarCask:new(playerObj, cask))
    end
end

-- Whole days, or hours under a day, as the test timers and a nearly soured pool need them.
local function leftText(hours)
    if hours >= 24 then return say("IGUI_TraditionalPreservationVinegar_DaysLeft", tostring(math.ceil(hours / 24))) end
    if hours <= 1 then return getText("IGUI_TraditionalPreservationVinegar_UnderHour") end
    return say("IGUI_TraditionalPreservationVinegar_HoursLeft", tostring(math.ceil(hours)))
end

local function caskStatus(cask, state)
    local mother = getText(state.mother and "IGUI_TraditionalPreservationVinegar_MotherYes" or "IGUI_TraditionalPreservationVinegar_MotherNo")
    if state.ml <= 0 then return say("IGUI_TraditionalPreservationVinegar_CaskEmpty", mother) end
    if state.strength >= 1 then return say("IGUI_TraditionalPreservationVinegar_CaskReady", litresText(state.ml / 1000), mother) end
    local hours = V.caskStatus(state, V.getLedger(), V.placeOf(cask)).hoursLeft
    return say("IGUI_TraditionalPreservationVinegar_CaskStatus", litresText(state.ml / 1000), percent(state.strength), leftText(hours), mother)
end

-- Today's temperature and what it means for the pool.
local function caskDetail(cask, state)
    local status = V.caskStatus(state, V.getLedger(), V.placeOf(cask))
    local place = PLACE_TEXT[status.place]
    local rateKey = status.place == "Basement" and "IGUI_TraditionalPreservationVinegar_RateSteady" or "IGUI_TraditionalPreservationVinegar_Rate"
    local lines = { say(rateKey, say(place, string.format("%.0f", status.temperature)), percent(status.rate)) }
    if state.ml > V.AIR_ML then
        table.insert(lines, say("IGUI_TraditionalPreservationVinegar_Crowded", litresText(V.AIR_ML / 1000)))
    end
    if state.mother then
        local key = V.hasStarter(state) and "IGUI_TraditionalPreservationVinegar_StarterYes" or "IGUI_TraditionalPreservationVinegar_StarterNo"
        table.insert(lines, say(key, percent(V.CULTURE_BONUS), percent(V.STARTER_STRENGTH)))
        table.insert(lines, say("IGUI_TraditionalPreservationVinegar_Layers", tostring(V.motherLayers(state)), litresText(V.MOTHER_LAYER_ML / 1000)))
    end
    return table.concat(lines, " <LINE> ")
end

-- Cask Info: the same facts as the status line and its hover, with bars, kept up to date while
-- open. It closes when the player walks off or the cask is gone.
local CASK_WINDOW_WIDTH = 360
local CASK_WINDOW_REACH = 6
local CASK_WINDOW_PADDING = 10
local CASK_LABEL_WIDTH = 110
local CASK_BAR_HEIGHT = 12
local CASK_BAR_COLOURS = { contents = { 0.62, 0.42, 0.18 }, souring = { 0.55, 0.6, 0.25 } }

local CaskWindow = ISCollapsableWindow:derive("TraditionalPreservationVinegarCaskWindow")

function CaskWindow:new(playerObj, cask)
    local x = getCore():getScreenWidth() / 2 - CASK_WINDOW_WIDTH / 2
    local o = ISCollapsableWindow.new(self, x, getCore():getScreenHeight() / 3, CASK_WINDOW_WIDTH, 200)
    o.playerObj, o.cask = playerObj, cask
    o.title = getText("IGUI_CraftingWindow_VinegarCask")
    o.resizable = false
    return o
end

function CaskWindow.open(playerObj, cask)
    if CaskWindow.instance then CaskWindow.instance:close() end
    local window = CaskWindow:new(playerObj, cask)
    window:initialise()
    window:addToUIManager()
    CaskWindow.instance = window
end

function CaskWindow:close()
    ISCollapsableWindow.close(self)
    self:removeFromUIManager()
    if CaskWindow.instance == self then CaskWindow.instance = nil end
end

function CaskWindow:update()
    ISCollapsableWindow.update(self)
    local square, player = self.cask:getSquare(), self.playerObj
    if not square or self.cask:getObjectIndex() < 0 or player:isDead() or player:getZ() ~= square:getZ()
            or IsoUtils.DistanceTo(player:getX(), player:getY(), square:getX() + 0.5, square:getY() + 0.5) > CASK_WINDOW_REACH then
        self:close()
    end
end

-- Words that run past the window go on to the next line.
local function wrapped(text, width)
    local lines, line = {}, ""
    for word in string.gmatch(text, "%S+") do
        local longer = line == "" and word or line .. " " .. word
        if line ~= "" and getTextManager():MeasureStringX(UIFont.Small, longer) > width then
            table.insert(lines, line)
            line = word
        else
            line = longer
        end
    end
    if line ~= "" then table.insert(lines, line) end
    return lines
end

function CaskWindow:row(y, label, value)
    self:drawText(label, CASK_WINDOW_PADDING, y, 0.7, 0.7, 0.7, 1, UIFont.Small)
    self:drawText(value, CASK_WINDOW_PADDING + CASK_LABEL_WIDTH, y, 1, 1, 1, 1, UIFont.Small)
    return y + getTextManager():getFontHeight(UIFont.Small) + 2
end

function CaskWindow:bar(y, label, share, colour, value)
    local lineHeight = getTextManager():getFontHeight(UIFont.Small)
    local x = CASK_WINDOW_PADDING + CASK_LABEL_WIDTH
    local width = self.width - x - CASK_WINDOW_PADDING
    local top = y + (lineHeight - CASK_BAR_HEIGHT) / 2
    self:drawText(label, CASK_WINDOW_PADDING, y, 0.7, 0.7, 0.7, 1, UIFont.Small)
    self:drawRect(x, top, width, CASK_BAR_HEIGHT, 0.6, 0.1, 0.1, 0.1)
    self:drawRect(x, top, width * math.max(0, math.min(share, 1)), CASK_BAR_HEIGHT, 0.9, colour[1], colour[2], colour[3])
    self:drawRectBorder(x, top, width, CASK_BAR_HEIGHT, 0.8, 0.4, 0.4, 0.4)
    self:drawTextCentre(value, x + width / 2, y, 1, 1, 1, 1, UIFont.Small)
    return y + lineHeight + 4
end

function CaskWindow:render()
    ISCollapsableWindow.render(self)
    if self.isCollapsed then return end
    local state = V.caskState(self.cask)
    local status = V.caskStatus(state, V.getLedger(), V.placeOf(self.cask))
    local y = self:titleBarHeight() + CASK_WINDOW_PADDING

    y = self:bar(y, getText("IGUI_TraditionalPreservationVinegar_InfoContents"), state.ml / V.CASK_ML, CASK_BAR_COLOURS.contents,
        say("IGUI_TraditionalPreservationVinegar_InfoLitres", litresText(state.ml / 1000), litresText(V.CASK_ML / 1000)))
    local soured = state.strength >= 1 and getText("IGUI_TraditionalPreservationVinegar_InfoReady") or percent(state.strength)
    y = self:bar(y, getText("IGUI_TraditionalPreservationVinegar_InfoSouring"), state.ml > 0 and state.strength or 0, CASK_BAR_COLOURS.souring,
        state.ml > 0 and soured or "-")
    local left = "-"
    if state.ml > 0 and state.strength < 1 then left = leftText(status.hoursLeft) end
    y = self:row(y, getText("IGUI_TraditionalPreservationVinegar_InfoTimeLeft"), left)
    y = self:row(y, getText("IGUI_TraditionalPreservationVinegar_InfoBottles"), tostring(V.bottlesLeft(state)))
    y = self:row(y, getText("IGUI_TraditionalPreservationVinegar_Temperature"), say(PLACE_TEXT[status.place], string.format("%.0f", status.temperature)))
    y = self:row(y, getText("IGUI_TraditionalPreservationVinegar_RateLabel"), percent(status.rate * V.caskSpeed(state)))
    local mother = state.mother and say("IGUI_TraditionalPreservationVinegar_InfoMotherLayers", tostring(V.motherLayers(state)), litresText(V.nextLayerMl(state) / 1000))
        or getText("IGUI_TraditionalPreservationVinegar_InfoMotherNone")
    y = self:row(y, getText("IGUI_TraditionalPreservationVinegar_InfoMother"), mother)
    local hose = getText("IGUI_TraditionalPreservationVinegar_InfoNoHose")
    if V.hoseLink(self.cask) then hose = getText("IGUI_TraditionalPreservationVinegar_HoseToVessel") end
    y = self:row(y, getText("IGUI_TraditionalPreservationVinegar_InfoHose"), hose)

    local notes = {}
    if state.ml > V.AIR_ML then table.insert(notes, say("IGUI_TraditionalPreservationVinegar_Crowded", litresText(V.AIR_ML / 1000))) end
    if state.mother then
        local key = V.hasStarter(state) and "IGUI_TraditionalPreservationVinegar_StarterYes" or "IGUI_TraditionalPreservationVinegar_StarterNo"
        table.insert(notes, say(key, percent(V.CULTURE_BONUS), percent(V.STARTER_STRENGTH)))
    end
    if state.ml > 0 and state.strength < 1 and status.place ~= "Basement" then table.insert(notes, getText("IGUI_TraditionalPreservationVinegar_InfoAssumes")) end
    local lineHeight = getTextManager():getFontHeight(UIFont.Small)
    for _, note in ipairs(notes) do
        y = y + 4
        for _, line in ipairs(wrapped(note, self.width - CASK_WINDOW_PADDING * 2)) do
            self:drawText(line, CASK_WINDOW_PADDING, y, 0.8, 0.8, 0.65, 1, UIFont.Small)
            y = y + lineHeight
        end
    end
    local height = y + CASK_WINDOW_PADDING
    if self.height ~= height then self:setHeight(height) end
end

-- Clicking a cask opens Cask Info, as clicking a door opens it. Vanilla's own checks come first: not
-- while paused, aiming or dead, and only a cask on the player's floor within reach of the window.
local function caskInReach(playerObj, cask)
    local square = cask:getSquare()
    return square and square:getZ() == playerObj:getZ()
        and IsoUtils.DistanceTo(playerObj:getX(), playerObj:getY(), square:getX() + 0.5, square:getY() + 0.5) <= CASK_WINDOW_REACH
end

-- The click handler is in vanilla's server folder, which loads after this one, so it is wrapped once the
-- game has started.
local function wrapClickHandler()
    if not ISObjectClickHandler or ISObjectClickHandler.tpvCaskClick then return end
    local vanillaClickObject = ISObjectClickHandler.doClickSpecificObject
    ISObjectClickHandler.tpvCaskClick = true
    function ISObjectClickHandler.doClickSpecificObject(object, playerNum, playerObj)
        if object and V.isCask(object) and playerObj and not playerObj:isDead() and not playerObj:isAiming()
                and not (UIManager.getSpeedControls() and UIManager.getSpeedControls():getCurrentGameSpeed() == 0)
                and caskInReach(playerObj, object) then
            CaskWindow.open(playerObj, object)
            return true
        end
        return vanillaClickObject(object, playerNum, playerObj)
    end
end

Events.OnGameStart.Add(wrapClickHandler)

local function addCaskMenu(context, playerObj, cask)
    local state = V.caskState(cask)
    local option = context:addOption(getText("IGUI_CraftingWindow_VinegarCask"))
    option.iconTexture = getTexture(STATION_ICONS.cask)
    local menu = context:getNew(context)
    context:addSubMenu(option, menu)

    local status = menu:addOption(caskStatus(cask, state))
    status.isDisabled = true
    tooltipFor(status, caskDetail(cask, state))
    menu:addOption(getText("ContextMenu_TraditionalPreservationVinegar_CaskInfo"), playerObj, CaskWindow.open, cask)

    if V.caskRoom(state) > 0 then
        local fermented = findItems(playerObj, function(item) return V.holdsOnly(item:getFluidContainer(), V.FERMENTED) end)
        addPourMenu(menu, getText("ContextMenu_TraditionalPreservationVinegar_PourFermented"), playerObj, cask, fermented, "caskIn", getText("IGUI_TraditionalPreservationVinegar_NoFermented"), FERMENTED_ICON)
    end
    if V.bottlesLeft(state) > 0 then addBottleMenu(menu, playerObj, cask, state) end

    addMotherMenu(menu, playerObj, cask, state)
    addHoseMenu(menu, playerObj, cask)

    local empty = menu:addOption(getText("ContextMenu_TraditionalPreservationVinegar_EmptyCask"), playerObj, onEmptyCask, cask)
    tooltipFor(empty, getText("IGUI_TraditionalPreservationVinegar_EmptyCask"))
    empty.isDisabled = state.ml <= 0
end

local function onFillContextMenu(playerNum, context, worldobjects)
    local playerObj = getSpecificPlayer(playerNum)
    local seen = {}
    for _, object in ipairs(worldobjects) do
        local kind = V.stationKind(object)
        if kind and not seen[kind] then
            seen[kind] = true
            -- A station built this session isn't tracked until its area reloads, and the cask has no
            -- slot to start it, so its menu does.
            if TraditionalPreservationVinegarWorld then TraditionalPreservationVinegarWorld.track(object) end
            if kind == "cask" then
                addCaskMenu(context, playerObj, object)
            elseif kind == "vessel" then
                addVesselMenu(context, playerObj, object)
            end
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillContextMenu)

-- Vanilla adds the option that opens a station's window with no icon, so this gives ours theirs.
local vanillaContextEntity = ISWorldMenuElements.ContextEntity

function ISWorldMenuElements.ContextEntity()
    local element = vanillaContextEntity()
    local vanillaCreateMenu = element.createMenu

    function element.createMenu(data)
        vanillaCreateMenu(data)
        for _, object in ipairs(data.objects) do
            local station = object:getMasterObject()
            if isStation(station) then
                local option = data.context:getOptionFromName(station:getEntityDisplayName())
                if option then option.iconTexture = getTexture(STATION_ICONS[V.stationKind(station)]) end
                return
            end
        end
    end

    return element
end
