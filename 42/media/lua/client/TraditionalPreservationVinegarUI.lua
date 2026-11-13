-- Traditional Preservation (Vinegar): keeps wrong items out of the station slots, shows the vessel's
-- tanks in its window, and adds a running batch's popup, the info block in the floor's and the vessel's crafting
-- windows (TP Core's StationInfo) and the right-click options on the vessel and cask.
require "Entity/ISUI/Components/Crafting/ISCraftLogicPanel"
require "Entity/ISUI/Components/Crafting/ISWidgetCraftLogicControl"
require "Entity/ISUI/Components/Crafting/ISWidgetCraftLogicInputControl"
require "Entity/ISUI/Controls/ISItemSlot"
require "Entity/ISUI/Controls/ISFluidSlotPanel"
require "Entity/ISUI/Components/Crafting/ISWidgetCraftLogicOutputProgress"
require "Context/World/ISContextEntity"
require "TimedActions/TPVinegarMother"
require "TimedActions/TPBottleVinegar"
require "TimedActions/TPEmptyVinegarCask"
require "TimedActions/TPPourVinegarFluid"
require "TimedActions/TPVinegarHose"
require "TimedActions/TPPumpVinegarWort"
local UI = require "TraditionalPreservationCore/UI"
local InfoWindow = require "TraditionalPreservationCore/InfoWindow"
local StationInfo = require "TraditionalPreservationCore/StationInfo"
local Weather = require "TraditionalPreservationCore/Weather"
local Container = require "TraditionalPreservationCore/Container"

local V = TraditionalPreservationVinegar
local vanillaCreateChildren = ISCraftLogicPanel.createChildren
local vanillaStartCraft = ISWidgetCraftLogicControl.startCraft
local vanillaOutputTeaser = ISWidgetCraftLogicInputControl.updateOutputItems

local BATCH_RECIPES = { MaltGrain = "malting", FermentWort = "alcoholic" }
local VINEGAR_ICON = "Item_Vinegar"
local HOSE_ICON = "Item_RubberHose"
local WORT_ICON = "media/textures/Item_BucketWort.png"
local FERMENTED_ICON = "media/textures/Item_BucketFermentedWort.png"
local STATION_ICONS = {
    floor = "media/textures/Item_MaltingFloor.png",
    vessel = "media/textures/Item_FermentationVessel.png",
    cask = "media/textures/Item_VinegarCask.png",
}

local say, percent = UI.say, UI.percent
local tooltipFor, findItems = UI.tooltip, UI.findItems

local function isStation(entity)
    return V.stationKind(entity) ~= nil
end

local function litresText(litres)
    return UI.litres(litres * 1000)
end

local function timeText(hours)
    return UI.timeText(hours, "IGUI_TraditionalPreservationVinegar_Time")
end

-- queued lists the items already on their way in.
local function refusal(slot, item, queued)
    local kind = V.stationKind(slot.entity)
    local wrongItem = V.inputRefusal(kind, item:getFullType())
    if wrongItem then return wrongItem end
    -- The run uses the whole packet, so it has to be a whole packet.
    if kind == "vessel" and item:getCurrentUsesFloat() < 1 then return "IGUI_TraditionalPreservationVinegar_FullYeast" end
    if slot.component:isRunning() then return "IGUI_TraditionalPreservationVinegar_InUse" end
    if slot.resource:getFreeItemCapacity() <= #queued then return "IGUI_TraditionalPreservationVinegar_Full" end
    return nil
end

UI.slotRules{
    station = function(entity)
        return isStation(entity) and entity:getComponent(ComponentType.CraftLogic) or nil
    end,
    refusal = refusal,
    added = function(entity)
        if TraditionalPreservationVinegarWorld then TraditionalPreservationVinegarWorld.track(entity) end
    end,
}

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
UI.keepInPlace(holdsLiquid)

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
        elseif V.isSour(V.peekTank(self.entity)) then
            reason = "IGUI_TraditionalPreservationVinegar_WortSour"
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

-- Vanilla's popup goes by the recipe's time alone, so a running batch gets this instead.
local function drawBatchTooltip(slot, tooltip, name, station)
    local kind = BATCH_RECIPES[name]
    local data = slot.craftRecipeData
    local status = V.batchStatus(kind, data:getModData(), data:getRecipe():getTime() / 3600, V.getLedger())
    UI.drawTooltip(tooltip, function(layout)
        UI.addLine(layout, "IGUI_TraditionalPreservationVinegar_Progress", percent(status.progress))
        -- The run holds its wort, so the vessel's Wort tank reads empty while it ferments.
        local run = kind == "alcoholic" and station and station:getModData().vinegarRun
        if run then UI.addLine(layout, "IGUI_TraditionalPreservationVinegar_InRun", say("IGUI_TraditionalPreservationVinegar_Litres", litresText(run.ml / 1000))) end
        UI.addLine(layout, "IGUI_TraditionalPreservationVinegar_TimeLeft", timeText(status.hoursLeft))
        UI.addLine(layout, "IGUI_TraditionalPreservationVinegar_Temperature", UI.placeText(status.place, status.temperature))
        UI.addRateLine(layout, "IGUI_TraditionalPreservationVinegar_RateLabel", status.rate)
    end)
end

UI.progressTooltips({ MaltGrain = drawBatchTooltip, FermentWort = drawBatchTooltip })

-- How long the tank's wort keeps where the vessel stands, or that it has soured; nil when neither applies.
local function wortKeeps(vessel, ledger)
    local record = V.peekTank(vessel)
    if not record then return nil end
    if V.isSour(record) then return getText("IGUI_TraditionalPreservationVinegar_InfoSoured") end
    local hours = V.hoursToSour(record, Weather.placeTemperature(ledger, Weather.placeOf(vessel)))
    return hours and say("IGUI_TraditionalPreservationVinegar_InfoSours", timeText(hours)) or nil
end

-- The block in the floor's and the vessel's own windows: where the station stands, the temperature and the stage's
-- rate there, the running batch's bar, and what waits or is done. The vessel's tanks have their own columns, so its
-- rows only say what is in them. The cask has no crafting window: its Info window does this.
local function stationInfo(entity)
    local kind = V.stationKind(entity)
    if kind ~= "floor" and kind ~= "vessel" then return nil end
    local contents = StationInfo.contents(entity)
    if not contents then return nil end
    local stage = kind == "floor" and "malting" or "alcoholic"
    local ledger = V.getLedger()
    local place = V.placeOf(entity)
    local temperature = Weather.placeTemperature(ledger, place)
    local rate = stage == "malting" and V.maltingRate(temperature) or V.alcoholicRate(temperature)
    local run = entity:getModData().vinegarRun
    local batches = {}
    for _, batch in ipairs(contents.batches) do
        local status = V.batchStatus(stage, batch.data:getModData(), batch.data:getRecipe():getTime() / 3600, ledger)
        local name = stage == "malting" and say("IGUI_TraditionalPreservationVinegar_InfoGrain", tostring(batch.count))
            or say("IGUI_TraditionalPreservationVinegar_InfoWort", litresText(run and run.ml / 1000 or 0))
        table.insert(batches, { name = name, progress = status.progress, hoursLeft = status.hoursLeft })
    end
    local options = { place = place, temperature = temperature, rate = rate, batches = batches,
        waiting = #contents.waiting, finished = #contents.finished }
    if kind == "vessel" then
        options.finished = 0  -- the marker the run leaves becomes the Fermented tank
        options.rows = {}
        for _, io in ipairs({ ResourceIO.Input, ResourceIO.Output }) do
            local tank = V.vesselTank(entity, io)
            local capacity = tank and tank:getFluidContainer():getCapacity() or 0
            local text = say("IGUI_TraditionalPreservationVinegar_InfoLitres", litresText(V.litres(tank)), litresText(capacity))
            local keeps = io == ResourceIO.Input and wortKeeps(entity, ledger)
            table.insert(options.rows, { TANK_TITLES[io], keeps and text .. ", " .. keeps or text })
        end
    end
    return StationInfo.block(options)
end

StationInfo.add(stationInfo)

local function onPour(playerObj, station, items, mode)
    if not ISEntityUI.WalkToEntity(playerObj, station) then return end
    for _, item in ipairs(items) do
        ISInventoryPaneContextMenu.transferIfNeeded(playerObj, item)
        ISTimedActionQueue.add(TPPourVinegarFluid:new(playerObj, station, item, mode))
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
        -- Drawn as the inventory draws it: a bucket shows the colour of what is in it.
        entry.itemForTexture = item
    end
end

local function onHose(playerObj, station, pliers, cask, hose)
    if not ISEntityUI.WalkToEntity(playerObj, station) then return end
    ISInventoryPaneContextMenu.transferIfNeeded(playerObj, pliers)
    if hose then ISInventoryPaneContextMenu.transferIfNeeded(playerObj, hose) end
    ISTimedActionQueue.add(TPVinegarHose:new(playerObj, station, pliers, cask, hose))
end

local function disableWith(option, key)
    UI.disable(option, getText(key))
end

local function onPump(playerObj, vessel, cask, ml)
    if not ISEntityUI.WalkToEntity(playerObj, vessel) then return end
    ISTimedActionQueue.add(TPPumpVinegarWort:new(playerObj, vessel, cask, ml))
end

-- Pump to Cask, on either station while joined: fixed amounts, up to the air line and all that fits,
-- each greyed out with the reason when it can't be done.
local function addPumpMenu(menu, playerObj, station, partner)
    local vessel, cask = station, partner
    if not V.isVessel(station) then vessel, cask = partner, station end
    local tank = V.vesselTank(vessel, ResourceIO.Output)
    local available = tank and Container.ml(tank:getFluidContainer()) or 0
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

local caskStatus -- below, with the cask's own menu

-- The hose options on either station: a grey line naming the other end, Pump to Cask and Detach Hose
-- when joined, and on a vessel, Attach Hose to Cask when not. With more than one cask in reach, Attach
-- Hose opens a list of them, nearest first, each with its status line, so the player picks one.
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
    local casks = V.casksForHose(station)
    local hose = findItems(playerObj, function(item) return item:getFullType() == V.HOSE_ITEM end)[1]
    local label = getText("ContextMenu_TraditionalPreservationVinegar_AttachHose")
    local several = #casks > 1 and hose and pliers
    local attach = several and menu:addOption(label) or menu:addOption(label, playerObj, onHose, station, pliers, casks[1], hose)
    attach.iconTexture = getTexture(HOSE_ICON)
    if #casks == 0 then
        disableWith(attach, "IGUI_TraditionalPreservationVinegar_NoCaskInReach")
    elseif not hose then
        disableWith(attach, "IGUI_TraditionalPreservationVinegar_NeedHose")
    elseif not pliers then
        disableWith(attach, "IGUI_TraditionalPreservationVinegar_NeedPliers")
    else
        tooltipFor(attach, getText("IGUI_TraditionalPreservationVinegar_HoseHelp"))
    end
    if not several then return end
    local choice = menu:getNew(menu)
    menu:addSubMenu(attach, choice)
    for _, cask in ipairs(casks) do
        local entry = choice:addOption(caskStatus(cask, V.caskState(cask)), playerObj, onHose, station, pliers, cask, hose)
        entry.iconTexture = getTexture(STATION_ICONS.cask)
    end
end

local function onPourAway(playerObj, vessel)
    if not ISEntityUI.WalkToEntity(playerObj, vessel) then return end
    ISTimedActionQueue.add(TPPourVinegarFluid:new(playerObj, vessel, nil, "vesselDump"))
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
    if input > 0 then
        local key = V.isSour(V.peekTank(vessel)) and "IGUI_TraditionalPreservationVinegar_VesselSour" or "IGUI_TraditionalPreservationVinegar_VesselWaiting"
        return say(key, litresText(input))
    end
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
        -- Someone carrying only sour wort is told why it won't go in.
        local none = "IGUI_TraditionalPreservationVinegar_NoWort"
        if #worts == 0 and #findItems(playerObj, function(item) return V.holdsOnly(item:getFluidContainer(), V.SOUR_WORT) end) > 0 then
            none = "IGUI_TraditionalPreservationVinegar_NoSourWort"
        end
        addPourMenu(context, getText("ContextMenu_TraditionalPreservationVinegar_PourWort"), playerObj, vessel, worts, "vesselIn", getText(none), WORT_ICON)
    end
    if V.litres(input) > 0 and not (logic and logic:isRunning()) then
        local dump = context:addOption(getText("ContextMenu_TraditionalPreservationVinegar_PourAwayWort"), playerObj, onPourAway, vessel)
        dump.iconTexture = getTexture(WORT_ICON)
    end
    if output and not output:isEmpty() then
        -- Only empty containers, so nothing is ever topped up into a mixture.
        local empties = findItems(playerObj, Container.isEmptyVessel)
        addPourMenu(context, getText("ContextMenu_TraditionalPreservationVinegar_DrawOff"), playerObj, vessel, empties, "vesselOut", getText("IGUI_TraditionalPreservationVinegar_NoContainer"), FERMENTED_ICON)
    end
    addHoseMenu(context, playerObj, vessel)
end

local function onBottle(playerObj, cask, bottles, count)
    if not ISEntityUI.WalkToEntity(playerObj, cask) then return end
    for index = 1, math.min(count, #bottles) do
        ISInventoryPaneContextMenu.transferIfNeeded(playerObj, bottles[index])
        ISTimedActionQueue.add(TPBottleVinegar:new(playerObj, cask, bottles[index]))
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
    local function setIcon(option)
        if #groups == 1 then option.itemForTexture = bottles[1] else option.iconTexture = getTexture(VINEGAR_ICON) end
    end
    setIcon(menu:addOption(getText("ContextMenu_TraditionalPreservationVinegar_AnyBottle"), playerObj, onBottle, cask, bottles, 1))
    local most = math.min(#bottles, V.bottlesLeft(state))
    setIcon(menu:addOption(say("ContextMenu_TraditionalPreservationVinegar_AllBottles", tostring(most)), playerObj, onBottle, cask, bottles, most))
    -- Picking a kind only helps when there is more than one.
    if #groups < 2 then return end
    for _, group in ipairs(groups) do
        local kind = menu:addOption(group.name .. " (" .. #group.items .. ")", playerObj, onBottle, cask, group.items, 1)
        kind.itemForTexture = group.items[1]
    end
end

local function onMother(playerObj, cask, item, mode)
    if not ISEntityUI.WalkToEntity(playerObj, cask) then return end
    ISInventoryPaneContextMenu.transferIfNeeded(playerObj, item)
    ISTimedActionQueue.add(TPVinegarMother:new(playerObj, cask, item, mode))
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
        ISTimedActionQueue.add(TPEmptyVinegarCask:new(playerObj, cask))
    end
end

-- Whole days, or hours under a day, as the test timers and a nearly soured pool need them.
local function leftText(hours)
    if not hours then return getText("IGUI_TraditionalPreservationCore_Paused") end
    if hours >= 24 then return say("IGUI_TraditionalPreservationVinegar_DaysLeft", tostring(math.ceil(hours / 24))) end
    if hours <= 1 then return getText("IGUI_TraditionalPreservationVinegar_UnderHour") end
    return say("IGUI_TraditionalPreservationVinegar_HoursLeft", tostring(math.ceil(hours)))
end

function caskStatus(cask, state)
    local mother = getText(state.mother and "IGUI_TraditionalPreservationVinegar_MotherYes" or "IGUI_TraditionalPreservationVinegar_MotherNo")
    if state.ml <= 0 then return say("IGUI_TraditionalPreservationVinegar_CaskEmpty", mother) end
    if state.strength >= 1 then return say("IGUI_TraditionalPreservationVinegar_CaskReady", litresText(state.ml / 1000), mother) end
    local hours = V.caskStatus(state, V.getLedger(), V.placeOf(cask)).hoursLeft
    return say("IGUI_TraditionalPreservationVinegar_CaskStatus", litresText(state.ml / 1000), percent(state.strength), leftText(hours), mother)
end

-- Today's temperature and what it means for the pool.
local function caskDetail(cask, state)
    local status = V.caskStatus(state, V.getLedger(), V.placeOf(cask))
    local lines = { say("IGUI_TraditionalPreservationVinegar_Rate", UI.placeText(status.place, status.temperature), percent(status.rate)) }
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

-- Cask Info (TP Core's InfoWindow): the same facts as the status line and its hover, with bars, kept up
-- to date while open.
local CASK_BAR_COLOURS = { contents = { 0.62, 0.42, 0.18 }, souring = { 0.55, 0.6, 0.25 } }

local CaskWindow = InfoWindow:derive("TraditionalPreservationVinegarCaskWindow")

function CaskWindow:new(playerObj, cask)
    local o = InfoWindow.new(self, playerObj, cask)
    o.title = getText("IGUI_CraftingWindow_VinegarCask")
    return o
end

function CaskWindow.open(playerObj, cask)
    InfoWindow.open(CaskWindow, playerObj, cask)
end

function CaskWindow:refresh()
    local cask = self.station
    local state = V.caskState(cask)
    self.info = { state = state, status = V.caskStatus(state, V.getLedger(), V.placeOf(cask)), hosed = V.hoseLink(cask) ~= nil }
end

function CaskWindow:render()
    ISCollapsableWindow.render(self)
    if self.isCollapsed or not self.info then return end
    local state, status = self.info.state, self.info.status
    local y = self:top()

    y = self:bar(y, "IGUI_TraditionalPreservationVinegar_InfoContents", state.ml / V.CASK_ML, CASK_BAR_COLOURS.contents,
        say("IGUI_TraditionalPreservationVinegar_InfoLitres", litresText(state.ml / 1000), litresText(V.CASK_ML / 1000)))
    local soured = state.strength >= 1 and getText("IGUI_TraditionalPreservationVinegar_InfoReady") or percent(state.strength)
    y = self:bar(y, "IGUI_TraditionalPreservationVinegar_InfoSouring", state.ml > 0 and state.strength or 0, CASK_BAR_COLOURS.souring,
        state.ml > 0 and soured or "-")
    local left = "-"
    if state.ml > 0 and state.strength < 1 then left = leftText(status.hoursLeft) end
    y = self:row(y, "IGUI_TraditionalPreservationVinegar_InfoTimeLeft", left)
    y = self:row(y, "IGUI_TraditionalPreservationVinegar_InfoBottles", tostring(V.bottlesLeft(state)))
    y = self:row(y, "IGUI_TraditionalPreservationVinegar_Temperature", UI.placeText(status.place, status.temperature))
    y = self:row(y, "IGUI_TraditionalPreservationVinegar_RateLabel", percent(status.rate * V.caskSpeed(state)))
    local mother = state.mother and say("IGUI_TraditionalPreservationVinegar_InfoMotherLayers", tostring(V.motherLayers(state)), litresText(V.nextLayerMl(state) / 1000))
        or getText("IGUI_TraditionalPreservationVinegar_InfoMotherNone")
    y = self:row(y, "IGUI_TraditionalPreservationVinegar_InfoMother", mother)
    y = self:row(y, "IGUI_TraditionalPreservationVinegar_InfoHose",
        getText(self.info.hosed and "IGUI_TraditionalPreservationVinegar_HoseToVessel" or "IGUI_TraditionalPreservationVinegar_InfoNoHose"))

    local notes = {}
    if state.ml > V.AIR_ML then table.insert(notes, say("IGUI_TraditionalPreservationVinegar_Crowded", litresText(V.AIR_ML / 1000))) end
    if state.mother then
        local key = V.hasStarter(state) and "IGUI_TraditionalPreservationVinegar_StarterYes" or "IGUI_TraditionalPreservationVinegar_StarterNo"
        table.insert(notes, say(key, percent(V.CULTURE_BONUS), percent(V.STARTER_STRENGTH)))
    end
    if state.ml > 0 and state.strength < 1 then table.insert(notes, getText("IGUI_TraditionalPreservationVinegar_InfoAssumes")) end
    self:drawNotes(y, notes)
end

-- Clicking a cask opens Cask Info, as clicking a door opens it.
InfoWindow.clickOpens(V.isCask, function(playerObj, cask)
    if TraditionalPreservationVinegarWorld then TraditionalPreservationVinegarWorld.track(cask) end
    CaskWindow.open(playerObj, cask)
end)

local function addCaskMenu(context, playerObj, cask)
    local state = V.caskState(cask)
    local option = context:addOption(getText("IGUI_CraftingWindow_VinegarCask"))
    option.iconTexture = getTexture(STATION_ICONS.cask)
    local menu = context:getNew(context)
    context:addSubMenu(option, menu)

    local status = menu:addOption(caskStatus(cask, state))
    status.isDisabled = true
    tooltipFor(status, caskDetail(cask, state))
    local info = menu:addOption(getText("ContextMenu_TraditionalPreservationVinegar_CaskInfo"), playerObj, CaskWindow.open, cask)
    info.iconTexture = getTexture(STATION_ICONS.cask)

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

local function onFillContextMenu(playerNum, context, worldobjects, test)
    local playerObj = getSpecificPlayer(playerNum)
    local seen = {}
    for _, object in ipairs(worldobjects) do
        local kind = V.stationKind(object)
        -- Vanilla's probe for a controller's prompt: say there is a menu, do no work.
        if test and (kind == "cask" or kind == "vessel") then return ISWorldObjectContextMenu.setTest() end
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
