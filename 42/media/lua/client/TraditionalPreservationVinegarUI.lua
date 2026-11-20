-- Traditional Preservation (Vinegar): the right-click menus on the vessel and the cask, and their Info windows (TP
-- Core's InfoWindow). The Malting Floor's menu and window are TraditionalPreservationVinegarFloorUI.lua's.
require "TimedActions/TPVinegarMother"
require "TimedActions/TPBottleVinegar"
require "TimedActions/TPEmptyVinegarCask"
require "TimedActions/TPPourVinegarFluid"
require "TimedActions/TPVinegarHose"
require "TimedActions/TPPumpVinegarWort"
require "TimedActions/TPPitchVinegarYeast"
local UI = require "TraditionalPreservationCore/UI"
local InfoWindow = require "TraditionalPreservationCore/InfoWindow"
local Weather = require "TraditionalPreservationCore/Weather"
local Container = require "TraditionalPreservationCore/Container"

local V = TraditionalPreservationVinegar

local VINEGAR_ICON = "Item_Vinegar"
local HOSE_ICON = "Item_RubberHose"
local WORT_ICON = "media/textures/Item_BucketWort.png"
local FERMENTED_ICON = "media/textures/Item_BucketFermentedWort.png"
local MOTHER_ICON = "media/textures/Item_MotherOfVinegar.png"
local STATION_ICONS = {
    floor = "media/textures/Item_MaltingFloor.png",
    vessel = "media/textures/Item_FermentationVessel.png",
    cask = "media/textures/Item_VinegarCask.png",
}

local say, percent = UI.say, UI.percent
local tooltipFor, findItems = UI.tooltip, UI.findItems

-- Starts the World watching a station now. The World is the server's file: a multiplayer client has none.
local function track(station)
    if TraditionalPreservationVinegarWorld then TraditionalPreservationVinegarWorld.track(station) end
end

-- The containers the player carries that hold only this fluid.
local function carrying(playerObj, fluid)
    return findItems(playerObj, function(item) return V.holdsOnly(item:getFluidContainer(), fluid) end)
end

-- A cask's pool, a vessel's tanks and its batch don't go with a station into a backpack.
local function holdsLiquid(isoObject)
    if not isoObject then return false end
    -- A hosed station would leave the hose and its partner behind.
    if (V.isCask(isoObject) or V.isVessel(isoObject)) and V.hoseLink(isoObject) then return true end
    if V.isCask(isoObject) then return V.caskModData(isoObject).ml > 0 end
    return V.isVessel(isoObject) and V.vesselHolds(V.vesselOf(isoObject))
end

-- Picking up can break a station, and a broken one would lose what it holds.
UI.keepInPlace(holdsLiquid)
-- No station is put down in front of a door (TP Core's Doors).
UI.keepDoorsFree(require("TraditionalPreservationVinegar/Tiles").STATIONS)

local function onPour(playerObj, station, items, mode)
    if not ISEntityUI.WalkToEntity(playerObj, station) then return end
    for _, item in ipairs(items) do
        ISInventoryPaneContextMenu.transferIfNeeded(playerObj, item)
        ISTimedActionQueue.add(TPPourVinegarFluid:new(playerObj, station, item, mode))
    end
end

-- A row per container, plus "all" when there are several (a submenu's, or the window's Draw Off button's menu).
local function addPourRows(menu, playerObj, station, items, mode)
    if #items > 1 then
        menu:addOption(say("ContextMenu_TraditionalPreservationVinegar_AllContainers", tostring(#items)), playerObj, onPour, station, items, mode)
    end
    for _, item in ipairs(items) do
        local fluid = item:getFluidContainer()
        -- Empty containers are told apart by what they hold, full ones by what is in them.
        local label = (mode == "vesselOut" or mode == "wortOut") and say("IGUI_TraditionalPreservationVinegar_Holds", UI.litres(fluid:getCapacity() * 1000))
            or UI.litres(fluid:getAmount() * 1000) .. " L"
        local itemOption = menu:addOption(item:getDisplayName() .. " (" .. label .. ")", playerObj, onPour, station, { item }, mode)
        -- Drawn as the inventory draws it: a bucket shows the colour of what is in it.
        itemOption.itemForTexture = item
    end
end

-- One option per container holding the right liquid, plus "all" when there are several.
local function addPourMenu(context, label, playerObj, station, items, mode, emptyText, icon)
    local option = context:addOption(label)
    option.iconTexture = getTexture(icon)
    if #items == 0 then
        UI.disable(option, emptyText)
        return option
    end
    local menu = context:getNew(context)
    context:addSubMenu(option, menu)
    addPourRows(menu, playerObj, station, items, mode)
    return option
end

local function onHose(playerObj, station, pliers, cask, hose)
    if not ISEntityUI.WalkToEntity(playerObj, station) then return end
    ISInventoryPaneContextMenu.transferIfNeeded(playerObj, pliers)
    if hose then ISInventoryPaneContextMenu.transferIfNeeded(playerObj, hose) end
    ISTimedActionQueue.add(TPVinegarHose:new(playerObj, station, pliers, cask, hose))
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
    local available = V.vesselOf(vessel).fermentedMl
    local option = menu:addOption(getText("ContextMenu_TraditionalPreservationVinegar_PumpToCask"))
    option.iconTexture = getTexture(FERMENTED_ICON)
    local pumps = menu:getNew(menu)
    menu:addSubMenu(option, pumps)
    for _, choice in ipairs(V.pumpChoices(V.caskModData(cask), available)) do
        local litres = UI.litres(choice.wanted or choice.ml)
        local label = choice.fill == "step" and say("ContextMenu_TraditionalPreservationVinegar_PumpLitres", litres)
            or say(choice.fill == "air" and "ContextMenu_TraditionalPreservationVinegar_PumpAirLine" or "ContextMenu_TraditionalPreservationVinegar_PumpAll", litres)
        local pumpOption = pumps:addOption(label, playerObj, onPump, vessel, cask, choice.ml)
        if choice.reason then
            UI.disable(pumpOption, say(choice.reason, UI.litres(choice.reasonMl or 0)))
        elseif choice.fill == "air" then
            tooltipFor(pumpOption, say("IGUI_TraditionalPreservationVinegar_PumpAirHelp", UI.litres(V.AIR_ML)))
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
        UI.disable(line, getText("IGUI_TraditionalPreservationVinegar_HoseHelp"))
        local partner = V.hosePartner(station)
        if partner then addPumpMenu(menu, playerObj, station, partner) end
        local detach = menu:addOption(getText("ContextMenu_TraditionalPreservationVinegar_DetachHose"), playerObj, onHose, station, pliers)
        detach.iconTexture = getTexture(HOSE_ICON)
        if pliers then tooltipFor(detach, getText("IGUI_TraditionalPreservationVinegar_DetachHelp")) else UI.disable(detach, getText("IGUI_TraditionalPreservationVinegar_NeedPliers")) end
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
        UI.disable(attach, getText("IGUI_TraditionalPreservationVinegar_NoCaskInReach"))
    elseif not hose then
        UI.disable(attach, getText("IGUI_TraditionalPreservationVinegar_NeedHose"))
    elseif not pliers then
        UI.disable(attach, getText("IGUI_TraditionalPreservationVinegar_NeedPliers"))
    else
        tooltipFor(attach, getText("IGUI_TraditionalPreservationVinegar_HoseHelp"))
    end
    if not several then return end
    local choice = menu:getNew(menu)
    menu:addSubMenu(attach, choice)
    for _, cask in ipairs(casks) do
        local caskOption = choice:addOption(caskStatus(cask, V.caskModData(cask)), playerObj, onHose, station, pliers, cask, hose)
        caskOption.iconTexture = getTexture(STATION_ICONS.cask)
    end
end

local function onPourAway(playerObj, vessel, mode)
    if not UI.walkTo(playerObj, vessel) then return end
    ISTimedActionQueue.add(TPPourVinegarFluid:new(playerObj, vessel, nil, mode))
end

-- The batch is lost for good, yeast and all, so it asks first.
local function onPourAwayBatch(playerObj, vessel)
    local record = V.vesselOf(vessel)
    if not record.run then return end
    UI.confirm(playerObj, say("IGUI_TraditionalPreservationVinegar_PourAwayBatchConfirm", UI.litres(record.run.ml)),
        function() onPourAway(playerObj, vessel, "batchDump") end)
end

local function onPitch(playerObj, vessel, yeast)
    ISInventoryPaneContextMenu.transferIfNeeded(playerObj, yeast)
    if not UI.walkTo(playerObj, vessel) then return end
    ISTimedActionQueue.add(TPPitchVinegarYeast:new(playerObj, vessel, yeast))
end

-- The vessel brought up to now where it stands: { record, place, placeC, wortPlace, status (the batch's, or nil),
-- refusal (why Pitch Yeast can't go now, a key, or nil) }.
local function vesselView(vessel)
    track(vessel)
    if TraditionalPreservationVinegarWorld then TraditionalPreservationVinegarWorld.refresh(vessel) end
    local now = getGameTime():getWorldAgeHours()
    local record, place = V.vesselNow(vessel, now)
    local ledger = V.getLedger()
    local placeC = Weather.placeTemperature(ledger, place)
    local wortPlace = Weather.placeOf(vessel)
    return { record = record, place = place, placeC = placeC, wortPlace = wortPlace, now = now,
        status = V.runStatus(record, placeC), refusal = V.pitchRefusal(record, now, wortPlace) }
end

local function vesselStatus(view)
    local record = view.record
    if view.status then
        return say("IGUI_TraditionalPreservationVinegar_VesselRunning", UI.litres(view.status.ml), percent(view.status.progress))
    end
    if record.fermentedMl > 0 then return say("IGUI_TraditionalPreservationVinegar_VesselReady", UI.litres(record.fermentedMl)) end
    if record.wortMl > 0 then
        local key = view.refusal == "IGUI_TraditionalPreservationVinegar_WortSour" and "IGUI_TraditionalPreservationVinegar_VesselSour"
            or "IGUI_TraditionalPreservationVinegar_VesselWaiting"
        return say(key, UI.litres(record.wortMl))
    end
    return getText("IGUI_TraditionalPreservationVinegar_VesselEmpty")
end

-- The first full packet of yeast carried, or nil.
local function fullYeast(playerObj)
    return findItems(playerObj, V.isFullYeast)[1]
end

-- Pitch Yeast: what it does now, or why it can't (a refusal key, or no full packet carried).
local function pitchState(view, playerObj)
    local yeast = fullYeast(playerObj)
    local reason = view.refusal and getText(view.refusal)
    if not reason and not yeast then reason = getText("IGUI_TraditionalPreservationVinegar_FullYeast") end
    return yeast, reason
end

-- Vessel Info (TP Core's InfoWindow) on the settled look (art/vessel_one_pool_mock.png): a band with the vessel's
-- state, the Station block (Place, Season, the working rate, the hose), its one pool as a tank named by what it holds
-- (Wort, Fermenting, Fermented) with the 16 L line and alegar's lore, Pitch Yeast or Draw Off, then notes. Kept up to
-- date while open.
TraditionalPreservationVinegarUI = TraditionalPreservationVinegarUI or {}
local VinegarUI = TraditionalPreservationVinegarUI
local KEY = "IGUI_TraditionalPreservationVinegar_"
local STATION_ICON = "media/textures/TPStation_FermentationVessel.png"
local AMBER, RED = InfoWindow.BAND_WAITING[1], InfoWindow.BAND_AT_RISK[1]
local FOAM_SHOWN_ML = 50   -- wort lost to foam is told from this much

-- Whether the waiting wort has soured where the vessel stands, and the hours it keeps if not (nil: no wort, or it
-- won't sour there).
local function wortState(view)
    local fluidAge = V.peekWort(view.record, view.now, view.wortPlace)
    if not fluidAge then return false, nil end
    if V.isSour(fluidAge) then return true, nil end
    return false, V.hoursToSour(fluidAge, Weather.placeTemperature(V.getLedger(), view.wortPlace))
end

-- The band, the worst first: wort soured; empty; foaming over; underpitched; lagging; too cold to work; fermenting;
-- fermented wort ready; wort waiting for its yeast. Returns the word's key, the text and the colours.
function VinegarUI.vesselBand(view)
    local record, status = view.record, view.status
    if view.soured then
        return KEY .. "VesselBandSoured", say(KEY .. "VesselBandSouredText", UI.litres(record.wortMl)), InfoWindow.BAND_AT_RISK
    end
    if not status and record.wortMl <= 0 and record.fermentedMl <= 0 then
        return KEY .. "VesselBandEmpty", getText(KEY .. "VesselBandEmptyText"), InfoWindow.BAND_IDLE
    end
    if status then
        if status.foaming and status.hoursLeft then
            return KEY .. "VesselBandFoaming", say(KEY .. "VesselBandFoamingText", string.format("%.0f", V.HEADSPACE_ML / 1000)), InfoWindow.BAND_AT_RISK
        end
        if status.underpitched then return KEY .. "VesselBandUnderpitched", getText(KEY .. "VesselBandUnderpitchedText"), InfoWindow.BAND_WAITING end
        if status.lagUntil and status.lagUntil > view.now then
            return KEY .. "VesselBandLagging", say(KEY .. "VesselBandLaggingText", UI.shortDuration(status.lagUntil - view.now)), InfoWindow.BAND_WAITING
        end
        if not status.hoursLeft then
            return KEY .. "VesselBandPaused", say(KEY .. "VesselBandPausedText", UI.litres(status.ml)), InfoWindow.BAND_WAITING
        end
        return KEY .. "VesselBandFermenting", say(KEY .. "VesselBandFermentingText", UI.litres(status.ml)), InfoWindow.BAND_WORKING
    end
    if record.fermentedMl > 0 then
        return KEY .. "VesselBandReady", say(KEY .. "VesselBandReadyText", UI.litres(record.fermentedMl)), InfoWindow.BAND_WORKING
    end
    return KEY .. "VesselBandWaiting", say(KEY .. "VesselBandPitchText", UI.litres(record.wortMl)), InfoWindow.BAND_WAITING
end

-- The tank's amount, "6.0 / 20 L".
local function tankAmount(ml)
    return say(KEY .. "VesselTankAmount", UI.litres(ml), string.format("%.0f", V.TANK_ML / 1000))
end

-- The batch's state line: done and the time left (or paused).
function VinegarUI.batchText(status)
    return say(KEY .. "VesselBatchState", percent(status.progress),
        status.hoursLeft and UI.shortDuration(status.hoursLeft) or getText("IGUI_TraditionalPreservationCore_Paused"))
end

-- The vessel's one pool as a tank, named by what it holds, with the 16 L line: waiting wort (souring, or soured), a
-- batch Fermenting (wort turning to fermented wort from the foot by the share done, bubbling by the working rate,
-- still when it waits, the foam thinning as it nears done and running over while it foams over; the wort it has lost
-- to foam under it), or Fermented wort (keeps). drop (the window's: containers of wort dragged on pour in) on it.
function VinegarUI.vesselHoldings(view, drop)
    local record, status = view.record, view.status
    local tank = { kind = "tank", drop = drop,
        line = { share = V.HEADSPACE_ML / V.TANK_ML, text = say(KEY .. "VesselLine", string.format("%.0f", V.HEADSPACE_ML / 1000)) } }
    local wortColour = Container.fluidColour(V.WORT) or { 0.95, 0.65, 0.4 }
    local fermentedColour = Container.fluidColour(V.FERMENTED) or { 0.82, 0.71, 0.55 }
    if status then
        local share = status.ml / V.TANK_ML
        local waits = not status.hoursLeft or status.underpitched or (status.lagUntil and status.lagUntil > view.now)
        tank.name, tank.amount = getText(KEY .. "VesselFermenting"), tankAmount(status.ml)
        tank.share, tank.colour = share * (1 - status.progress), wortColour
        tank.settled = { share = share * status.progress, colour = fermentedColour }
        local speed = status.hoursLeft and not (status.lagUntil and status.lagUntil > view.now) and status.rate or 0
        if status.underpitched then speed = speed * V.UNDERPITCH_RATE end
        tank.working = { speed = speed, foam = 1 - 0.7 * status.progress, spill = status.foaming and speed > 0 }
        tank.state, tank.stateColour = VinegarUI.batchText(status), waits and AMBER or nil
        if (status.foamedMl or 0) >= FOAM_SHOWN_ML then
            tank.under, tank.underColour = say(KEY .. "VesselFoamLost", UI.litres(status.foamedMl)), RED
        end
    elseif record.fermentedMl > 0 then
        tank.name, tank.amount = getText(KEY .. "TankFermented"), tankAmount(record.fermentedMl)
        tank.share, tank.colour, tank.state = record.fermentedMl / V.TANK_ML, fermentedColour, getText(KEY .. "VesselKeeps")
    else
        tank.name, tank.amount = getText(KEY .. "TankWort"), tankAmount(record.wortMl)
        tank.share = record.wortMl / V.TANK_ML
        tank.colour = view.soured and Container.fluidColour(V.SOUR_WORT) or wortColour
        if view.soured then
            tank.state, tank.stateColour = getText(KEY .. "InfoSoured"), RED
        elseif view.soursIn then
            tank.state, tank.stateColour = say(KEY .. "VesselSouring", UI.shortDuration(view.soursIn)), AMBER
        end
    end
    return { tank }
end

-- Containers dragged onto the vessel, judged as Pour Wort would take them: wort alone, up to the room there is (the
-- batch's while one works, topping it up), none on fermented wort. Returns DropZone's judgement and adds, the share
-- of the tank the pour would fill.
function VinegarUI.wortJudge(record, items)
    local room, poured, take, refused = V.wortRoom(record), 0, {}, nil
    local refusal = V.pourRefusal(record)
    for _, item in ipairs(items) do
        local container = item.getFluidContainer and item:getFluidContainer()
        local why
        if not container or not V.holdsOnly(container, V.WORT) then
            why = getText(KEY .. "WortDropTakes")
        elseif refusal == "IGUI_TraditionalPreservationVinegar_DrawOffFirst" then
            why = getText(refusal)
        elseif poured >= room then
            why = getText(KEY .. (record.run and "WortDropBatchFull" or "WortDropFull"))
        else
            poured = poured + math.min(Container.ml(container), room - poured)
            table.insert(take, item)
        end
        if why then refused = refused or why end
    end
    local lines = { #take > 0 and say(KEY .. (record.run and "WortDropTopUp" or "WortDropPour"), UI.litres(poured), tostring(#take))
        or refused or getText(KEY .. "WortDropTakes") }
    return { take = take, lines = lines, refused = #take < #items and refused or nil, adds = poured / V.TANK_ML }
end

-- Pitch Yeast's help: the wort it starts, or the repitch that sets a struggling batch going again.
function VinegarUI.pitchHelp(record)
    if record.run then return getText(KEY .. "RepitchHelp") end
    return say(KEY .. "PitchHelp", UI.litres(record.wortMl))
end

-- The Station block's own rows under Place and Season: the working rate, and the hose.
function VinegarUI.vesselRows(view, hosed)
    return { { "IGUI_TraditionalPreservationVinegar_RateLabel", percent(V.alcoholicRate(view.placeC)) },
        { "IGUI_TraditionalPreservationVinegar_InfoHose", getText(hosed and KEY .. "InfoHoseCask" or KEY .. "InfoNoHose") } }
end

-- The notes under the window, by its state (the band's word key).
function VinegarUI.vesselNotes(word, status)
    local notes = {}
    local byState = { VesselBandFoaming = "VesselNoteFoaming", VesselBandUnderpitched = "VesselNoteRepitch",
        VesselBandLagging = "VesselNoteRepitch", VesselBandReady = "VesselNoteReady", VesselBandSoured = "VesselNoteSoured" }
    local own = byState[string.gsub(word, "^" .. KEY, "")]
    if own then table.insert(notes, getText(KEY .. own)) end
    if status then
        table.insert(notes, getText(KEY .. "VesselNoteTopUp"))
        table.insert(notes, getText(KEY .. "VesselNoteDragBatch"))
        table.insert(notes, getText(KEY .. "InfoAssumes"))
    elseif word ~= KEY .. "VesselBandReady" then
        table.insert(notes, getText(KEY .. "VesselNoteHeadspace"))
        table.insert(notes, getText(KEY .. "VesselNoteDrag"))
    end
    return notes
end

local function yeastIcon()
    local script = getScriptManager():FindItem(V.YEAST)
    return script and script:getNormalTexture()
end

-- Draw Off opens a menu of the empty containers under the button, as the right-click's submenu.
local function openDrawOff(window, button)
    local playerObj = window.playerObj
    local x, y = window:getAbsoluteX() + button.x, window:getAbsoluteY() + button.y + button.height
    local context = ISContextMenu.get(playerObj:getPlayerNum(), x, y)
    addPourRows(context, playerObj, window.station, findItems(playerObj, Container.isEmptyVessel), "vesselOut")
end

local VesselWindow = InfoWindow:derive("TraditionalPreservationVinegarVesselWindow")

function VesselWindow:new(playerObj, vessel)
    local o = InfoWindow.new(self, playerObj, vessel)
    o.title = getText("IGUI_CraftingWindow_FermentationVessel")
    return o
end

function VesselWindow.open(playerObj, vessel)
    InfoWindow.open(VesselWindow, playerObj, vessel)
end

function VesselWindow:refresh()
    local view = vesselView(self.station)
    view.soured, view.soursIn = wortState(view)
    if view.record.fermentedMl > 0 then view.empties = #findItems(self.playerObj, Container.isEmptyVessel) end
    self.vesselView = view
    local playerObj, vessel = self.playerObj, self.station
    self.drop = self.drop or { judge = function(items) return VinegarUI.wortJudge(V.vesselOf(vessel), items) end,
        drop = function(take) onPour(playerObj, vessel, take, "vesselIn") end }
end

-- Pitch Yeast while it can start or repitch a batch (greyed with the reason), Draw Off once fermented wort is in.
function VesselWindow:vesselButtons(y)
    local view, record = self.vesselView, self.vesselView.record
    local playerObj, vessel, window = self.playerObj, self.station, self
    local buttons = {}
    if record.fermentedMl > 0 then
        table.insert(buttons, { title = getText("ContextMenu_TraditionalPreservationVinegar_DrawOff"), icon = FERMENTED_ICON,
            enabled = (view.empties or 0) > 0, tooltip = (view.empties or 0) == 0 and getText(KEY .. "NoContainer") or nil,
            onClick = function(button) openDrawOff(window, button) end })
    elseif not record.run or V.needsRepitch(record.run, view.now) then
        local yeast, reason = pitchState(view, playerObj)
        table.insert(buttons, { title = getText("ContextMenu_TraditionalPreservationVinegar_PitchYeast"), icon = yeastIcon(),
            enabled = reason == nil, tooltip = reason or VinegarUI.pitchHelp(record),
            onClick = function() if yeast then onPitch(playerObj, vessel, yeast) end end })
    end
    return self:buttonRow(y, buttons)
end

function VesselWindow:render()
    ISCollapsableWindow.render(self)
    if self.isCollapsed or not self.vesselView then return end
    local view = self.vesselView
    local word, text, look = VinegarUI.vesselBand(view)
    local y = self:band(getText(word), text, look[1], look[2])
    y = self:stationBlock(y, STATION_ICON, view.place, view.placeC, VinegarUI.vesselRows(view, V.hoseLink(self.station)))
    y = self:section(y, "IGUI_TraditionalPreservationCore_SectionHolds")
    y = self:holds(y, VinegarUI.vesselHoldings(view, self.drop), getText(KEY .. "VesselLore"))
    y = self:vesselButtons(y)
    self:drawNotes(y, VinegarUI.vesselNotes(word, view.status))
end

local function addVesselMenu(context, playerObj, vessel)
    local view = vesselView(vessel)
    local record = view.record
    local vesselIcon = getTexture(STATION_ICONS.vessel)
    local option = context:addOption(getText("IGUI_CraftingWindow_FermentationVessel"))
    option.iconTexture = vesselIcon
    local menu = context:getNew(context)
    context:addSubMenu(option, menu)

    local status = menu:addOption(vesselStatus(view))
    status.iconTexture = vesselIcon
    UI.disable(status, getText("IGUI_TraditionalPreservationVinegar_VesselHelp"))
    local infoOption = menu:addOption(getText("IGUI_TraditionalPreservationVinegar_VesselInfo"), playerObj, VesselWindow.open, vessel)
    infoOption.iconTexture = vesselIcon
    UI.topInfo(context, getText("IGUI_TraditionalPreservationVinegar_VesselInfo"), vesselIcon, playerObj, VesselWindow.open, vessel)

    -- Wort goes into the batch while one works (Top Up the Batch), else into the vessel; on fermented wort it waits
    -- until that is drawn off.
    if V.pourRefusal(record) == "IGUI_TraditionalPreservationVinegar_DrawOffFirst" then
        local pour = menu:addOption(getText("ContextMenu_TraditionalPreservationVinegar_PourWort"))
        pour.iconTexture = getTexture(WORT_ICON)
        UI.disable(pour, getText("IGUI_TraditionalPreservationVinegar_DrawOffFirst"))
    elseif V.wortRoom(record) > 0 then
        local worts = carrying(playerObj, V.WORT)
        -- Someone carrying only sour wort is told why it won't go in.
        local none = "IGUI_TraditionalPreservationVinegar_NoWort"
        if #worts == 0 and #carrying(playerObj, V.SOUR_WORT) > 0 then
            none = "IGUI_TraditionalPreservationVinegar_NoSourWort"
        end
        local label = record.run and "ContextMenu_TraditionalPreservationVinegar_TopUp" or "ContextMenu_TraditionalPreservationVinegar_PourWort"
        local pour = addPourMenu(menu, getText(label), playerObj, vessel, worts, "vesselIn", getText(none), WORT_ICON)
        if record.run and #worts > 0 then
            local help = say("IGUI_TraditionalPreservationVinegar_TopUpHelp", UI.litres(V.wortRoom(record)))
            local risk = V.topUpRisk(record.run, math.min(V.wortRoom(record), Container.ml(worts[1]:getFluidContainer())), view.now)
            if risk then help = help .. " <LINE> " .. getText("IGUI_TraditionalPreservationVinegar_TopUpRisk_" .. risk) end
            tooltipFor(pour, help)
        end
    end

    if not record.run or V.needsRepitch(record.run, view.now) then
        local yeast, reason = pitchState(view, playerObj)
        local pitch = menu:addOption(getText("ContextMenu_TraditionalPreservationVinegar_PitchYeast"), playerObj, onPitch, vessel, yeast)
        pitch.iconTexture = getTexture("Item_Yeast")
        if reason then UI.disable(pitch, reason) else tooltipFor(pitch, VinegarUI.pitchHelp(record)) end
    end
    if record.wortMl > 0 then
        -- Only empty containers; the wort keeps its age in them.
        local empties = findItems(playerObj, Container.isEmptyVessel)
        addPourMenu(menu, getText("ContextMenu_TraditionalPreservationVinegar_DrawOffWort"), playerObj, vessel, empties, "wortOut", getText("IGUI_TraditionalPreservationVinegar_NoContainer"), WORT_ICON)
        local dump = menu:addOption(getText("ContextMenu_TraditionalPreservationVinegar_PourAwayWort"), playerObj, onPourAway, vessel, "vesselDump")
        dump.iconTexture = getTexture(WORT_ICON)
    end
    if record.fermentedMl > 0 then
        -- Only empty containers, so nothing is ever topped up into a mixture.
        local empties = findItems(playerObj, Container.isEmptyVessel)
        addPourMenu(menu, getText("ContextMenu_TraditionalPreservationVinegar_DrawOff"), playerObj, vessel, empties, "vesselOut", getText("IGUI_TraditionalPreservationVinegar_NoContainer"), FERMENTED_ICON)
    end
    addHoseMenu(menu, playerObj, vessel)
    -- Last, apart from the rest: the yeast went in with the wort, so nothing comes back.
    if record.run then
        local dumpBatch = menu:addOption(getText("ContextMenu_TraditionalPreservationVinegar_PourAwayBatch"), playerObj, onPourAwayBatch, vessel)
        dumpBatch.iconTexture = getTexture(WORT_ICON)
        tooltipFor(dumpBatch, say("IGUI_TraditionalPreservationVinegar_PourAwayBatchHelp", UI.litres(record.run.ml)))
    end
end

local function onBottle(playerObj, cask, bottles, count)
    if not ISEntityUI.WalkToEntity(playerObj, cask) then return end
    for index = 1, math.min(count, #bottles) do
        ISInventoryPaneContextMenu.transferIfNeeded(playerObj, bottles[index])
        ISTimedActionQueue.add(TPBottleVinegar:new(playerObj, cask, bottles[index]))
    end
end

local function addBottleMenu(context, playerObj, cask, caskModData)
    local option = context:addOption(getText("ContextMenu_TraditionalPreservationVinegar_Bottle"))
    option.iconTexture = getTexture(VINEGAR_ICON)
    local types = V.bottleTypes()
    local bottles = findItems(playerObj, function(item) return types[item:getFullType()] and V.isEmptyBottle(item) end)
    if #bottles == 0 then
        UI.disable(option, getText("IGUI_TraditionalPreservationVinegar_NoBottles"))
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
    local most = math.min(#bottles, V.bottlesLeft(caskModData))
    setIcon(menu:addOption(say("ContextMenu_TraditionalPreservationVinegar_AllBottles", tostring(most)), playerObj, onBottle, cask, bottles, most))
    -- Picking a kind only helps when there is more than one.
    if #groups < 2 then return end
    for _, group in ipairs(groups) do
        local groupOption = menu:addOption(group.name .. " (" .. #group.items .. ")", playerObj, onBottle, cask, group.items, 1)
        groupOption.itemForTexture = group.items[1]
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
    option.iconTexture = getTexture(MOTHER_ICON)
    if item then
        tooltipFor(option, getText(help))
    else
        UI.disable(option, getText(missing))
    end
end

local function addMotherMenu(menu, playerObj, cask, caskModData)
    if caskModData.mother then
        local jar = findItems(playerObj, V.isEmptyJar)[1]
        addMotherOption(menu, "ContextMenu_TraditionalPreservationVinegar_TakeMother", playerObj, cask, jar, "take",
            "IGUI_TraditionalPreservationVinegar_TakeMother", "IGUI_TraditionalPreservationVinegar_NoJar")
        if V.canSplitMother(caskModData) then
            addMotherOption(menu, "ContextMenu_TraditionalPreservationVinegar_SplitMother", playerObj, cask, jar, "split",
                "IGUI_TraditionalPreservationVinegar_SplitMother", "IGUI_TraditionalPreservationVinegar_NoJar")
        else
            -- Shown greyed, so the player knows it exists and what it's waiting for.
            local split = menu:addOption(getText("ContextMenu_TraditionalPreservationVinegar_SplitMother"))
            split.iconTexture = getTexture(MOTHER_ICON)
            UI.disable(split, say("IGUI_TraditionalPreservationVinegar_SplitNotYet", tostring(V.motherLayers(caskModData)), UI.litres(V.nextLayerMl(caskModData))))
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

-- The pool's souring where the cask stands now.
local function caskNow(cask, caskModData)
    return V.caskStatus(caskModData, V.getLedger(), V.placeOf(cask))
end

-- What crowds or speeds the pool: past the air line, and the mother's starter.
local function caskNotes(caskModData)
    local notes = {}
    if caskModData.ml > V.AIR_ML then table.insert(notes, say("IGUI_TraditionalPreservationVinegar_Crowded", UI.litres(V.AIR_ML))) end
    if caskModData.mother then
        local key = V.hasStarter(caskModData) and "IGUI_TraditionalPreservationVinegar_StarterYes" or "IGUI_TraditionalPreservationVinegar_StarterNo"
        table.insert(notes, say(key, percent(V.CULTURE_BONUS), percent(V.STARTER_STRENGTH)))
    end
    return notes
end

function caskStatus(cask, caskModData)
    local mother = getText(caskModData.mother and "IGUI_TraditionalPreservationVinegar_MotherYes" or "IGUI_TraditionalPreservationVinegar_MotherNo")
    if caskModData.ml <= 0 then return say("IGUI_TraditionalPreservationVinegar_CaskEmpty", mother) end
    if caskModData.strength >= 1 then return say("IGUI_TraditionalPreservationVinegar_CaskReady", UI.litres(caskModData.ml), mother) end
    local hours = caskNow(cask, caskModData).hoursLeft
    return say("IGUI_TraditionalPreservationVinegar_CaskStatus", UI.litres(caskModData.ml), percent(caskModData.strength), leftText(hours), mother)
end

-- Today's temperature and what it means for the pool.
local function caskDetail(cask, caskModData)
    local status = caskNow(cask, caskModData)
    local lines = { say("IGUI_TraditionalPreservationVinegar_Rate", UI.placeText(status.place, status.temperature), percent(status.rate)) }
    for _, note in ipairs(caskNotes(caskModData)) do table.insert(lines, note) end
    if caskModData.mother then
        table.insert(lines, say("IGUI_TraditionalPreservationVinegar_Layers", tostring(V.motherLayers(caskModData)), UI.litres(V.MOTHER_LAYER_ML)))
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
    local caskModData = V.caskModData(cask)
    self.caskView = { caskModData = caskModData, status = caskNow(cask, caskModData), hosed = V.hoseLink(cask) ~= nil }
end

function CaskWindow:render()
    ISCollapsableWindow.render(self)
    if self.isCollapsed or not self.caskView then return end
    local caskModData, status = self.caskView.caskModData, self.caskView.status
    local y = self:top()

    y = self:bar(y, "IGUI_TraditionalPreservationVinegar_InfoContents", caskModData.ml / V.CASK_ML, CASK_BAR_COLOURS.contents,
        say("IGUI_TraditionalPreservationVinegar_InfoLitres", UI.litres(caskModData.ml), UI.litres(V.CASK_ML)))
    local soured = caskModData.strength >= 1 and getText("IGUI_TraditionalPreservationVinegar_InfoReady") or percent(caskModData.strength)
    y = self:bar(y, "IGUI_TraditionalPreservationVinegar_InfoSouring", caskModData.ml > 0 and caskModData.strength or 0, CASK_BAR_COLOURS.souring,
        caskModData.ml > 0 and soured or "-")
    local left = "-"
    if caskModData.ml > 0 and caskModData.strength < 1 then left = leftText(status.hoursLeft) end
    y = self:row(y, "IGUI_TraditionalPreservationVinegar_InfoTimeLeft", left)
    y = self:row(y, "IGUI_TraditionalPreservationVinegar_InfoBottles", tostring(V.bottlesLeft(caskModData)))
    y = self:row(y, "IGUI_TraditionalPreservationVinegar_Temperature", UI.placeText(status.place, status.temperature))
    y = self:row(y, "IGUI_TraditionalPreservationVinegar_RateLabel", percent(status.rate * V.caskSpeed(caskModData)))
    local mother = caskModData.mother and say("IGUI_TraditionalPreservationVinegar_InfoMotherLayers", tostring(V.motherLayers(caskModData)), UI.litres(V.nextLayerMl(caskModData)))
        or getText("IGUI_TraditionalPreservationVinegar_InfoMotherNone")
    y = self:row(y, "IGUI_TraditionalPreservationVinegar_InfoMother", mother)
    y = self:row(y, "IGUI_TraditionalPreservationVinegar_InfoHose",
        getText(self.caskView.hosed and "IGUI_TraditionalPreservationVinegar_HoseToVessel" or "IGUI_TraditionalPreservationVinegar_InfoNoHose"))

    local notes = caskNotes(caskModData)
    if caskModData.ml > 0 and caskModData.strength < 1 then table.insert(notes, getText("IGUI_TraditionalPreservationVinegar_InfoAssumes")) end
    self:drawNotes(y, notes)
end

-- Clicking a cask opens Cask Info, as clicking a door opens it.
local function addCaskMenu(context, playerObj, cask)
    local caskModData = V.caskModData(cask)
    local option = context:addOption(getText("IGUI_CraftingWindow_VinegarCask"))
    option.iconTexture = getTexture(STATION_ICONS.cask)
    local menu = context:getNew(context)
    context:addSubMenu(option, menu)

    local status = menu:addOption(caskStatus(cask, caskModData))
    UI.disable(status, caskDetail(cask, caskModData))
    local infoOption = menu:addOption(getText("ContextMenu_TraditionalPreservationVinegar_CaskInfo"), playerObj, CaskWindow.open, cask)
    infoOption.iconTexture = getTexture(STATION_ICONS.cask)
    UI.topInfo(context, getText("ContextMenu_TraditionalPreservationVinegar_CaskInfo"), getTexture(STATION_ICONS.cask), playerObj, CaskWindow.open, cask)

    if V.caskRoom(caskModData) > 0 then
        local fermented = carrying(playerObj, V.FERMENTED)
        addPourMenu(menu, getText("ContextMenu_TraditionalPreservationVinegar_PourFermented"), playerObj, cask, fermented, "caskIn", getText("IGUI_TraditionalPreservationVinegar_NoFermented"), FERMENTED_ICON)
    end
    if V.bottlesLeft(caskModData) > 0 then addBottleMenu(menu, playerObj, cask, caskModData) end

    addMotherMenu(menu, playerObj, cask, caskModData)
    addHoseMenu(menu, playerObj, cask)

    local empty = menu:addOption(getText("ContextMenu_TraditionalPreservationVinegar_EmptyCask"), playerObj, onEmptyCask, cask)
    tooltipFor(empty, getText("IGUI_TraditionalPreservationVinegar_EmptyCask"))
    empty.isDisabled = caskModData.ml <= 0
end

local function onFillContextMenu(playerNum, context, worldobjects, test)
    local playerObj = getSpecificPlayer(playerNum)
    local seen = {}
    for _, isoObject in ipairs(worldobjects) do
        local kind = V.stationKind(isoObject)
        -- Vanilla's probe for a controller's prompt: say there is a menu, do no work.
        if test and kind then return ISWorldObjectContextMenu.setTest() end
        if kind and not seen[kind] then
            seen[kind] = true
            -- A station built this session isn't tracked until its area reloads, and the cask has no
            -- slot to start it, so its menu does.
            track(isoObject)
            if kind == "cask" then
                addCaskMenu(context, playerObj, isoObject)
            elseif kind == "vessel" then
                addVesselMenu(context, playerObj, isoObject)
            else
                TraditionalPreservationVinegarFloorUI.addMenu(context, playerObj, isoObject)
            end
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillContextMenu)
