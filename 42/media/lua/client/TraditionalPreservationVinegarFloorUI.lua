-- Traditional Preservation (Vinegar) B42: the Malting Floor's right-click menu (what it holds, Info, Spread Steeped
-- Grain, Take Done, Take Everything Off; TPVinegarFloor does the hand jobs) and Floor Info, its info window (TP Core's
-- InfoWindow, a row a heap in TP Core's scrolling list, the buttons and the drop square). A floor holding anything stays
-- where it is.
require "TimedActions/TPVinegarFloor"
local InfoWindow = require "TraditionalPreservationCore/InfoWindow"
local PiecesUI = require "TraditionalPreservationCore/PiecesUI"
local UI = require "TraditionalPreservationCore/UI"
local Weather = require "TraditionalPreservationCore/Weather"

TraditionalPreservationVinegarFloorUI = TraditionalPreservationVinegarFloorUI or {}
local FloorUI = TraditionalPreservationVinegarFloorUI
local V = TraditionalPreservationVinegar

local KEY = "IGUI_TraditionalPreservationVinegar_"
local MENU = "ContextMenu_TraditionalPreservationVinegar_"
local FLOOR_ICON = "media/textures/Item_MaltingFloor.png"
local COLOURS = { sprouting = { 0.35, 0.7, 0.35 }, done = { 0.35, 0.7, 0.35 }, stale = { 0.8, 0.6, 0.2 },
    rotten = { 0.6, 0.3, 0.25 } }

local function say(key, ...) return UI.say(KEY .. key, ...) end

local function floorNow(station)
    if TraditionalPreservationVinegarWorld then
        TraditionalPreservationVinegarWorld.track(station)
        TraditionalPreservationVinegarWorld.refresh(station)
    end
    return V.floorNow(station)
end

local function iconOf(state)
    return getTexture(state == "sprouting" and "media/textures/Item_SteepedGrain.png" or "media/textures/Item_GreenMalt.png")
end

local function nameOf(state)
    return getItemNameFromFullType(state == "sprouting" and V.STEEPED or V.GREEN_MALT)
end

-- What the bar says.
function FloorUI.barText(status)
    if status.state == "sprouting" then
        if not status.hoursLeft then return say("HeapWaits", UI.percent(status.progress)) end
        return say("HeapLeft", UI.percent(status.progress), UI.durationText(status.hoursLeft))
    end
    return say("Heap_" .. status.state)
end

-- The line under the bar: when done Green Malt goes stale or rots.
function FloorUI.noteText(status)
    if status.staleIn then return say("HeapStaleIn", UI.durationText(status.staleIn * 24)) end
    if status.rottenIn then return say("HeapRottenIn", UI.durationText(status.rottenIn * 24)) end
    return nil
end

local function drawPopup(tooltip, status, place, placeC)
    UI.drawTooltip(tooltip, function(layout)
        UI.addLine(layout, KEY .. "Progress", UI.percent(status.progress))
        if status.hoursLeft then UI.addLine(layout, KEY .. "TimeLeft", UI.durationText(status.hoursLeft)) end
        local note = FloorUI.noteText(status)
        if note then UI.addLine(layout, KEY .. "Watch", note) end
        UI.addLine(layout, KEY .. "Temperature", UI.placeText(place, placeC))
        UI.addRateLine(layout, KEY .. "RateLabel", status.rate)
    end)
end

-- One list row a heap (TP Core's PieceList).
function FloorUI.heapRow(heap, place, placeC, now)
    local status = V.heapStatus(heap, placeC, now)
    return {
        icon = iconOf(status.state), name = nameOf(status.state), share = status.progress,
        colour = COLOURS[status.state], text = FloorUI.barText(status), note = FloorUI.noteText(status),
        popup = function(tooltip) drawPopup(tooltip, status, place, placeC) end,
        status = status,
    }
end

-- Everything the menu and Floor Info show: { place, placeC, rows, doneIds, allIds, waitText, count }.
function FloorUI.view(record, place, now)
    now = now or getGameTime():getWorldAgeHours()
    local placeC = Weather.placeTemperature(V.getLedger(), place)
    local rows, doneIds, allIds, soonest = {}, {}, {}, nil
    for _, heap in ipairs(record.heaps) do
        local row = FloorUI.heapRow(heap, place, placeC, now)
        table.insert(rows, row)
        table.insert(allIds, heap.id)
        if row.status.state ~= "sprouting" then table.insert(doneIds, heap.id) end
        if row.status.hoursLeft then soonest = math.min(soonest or math.huge, row.status.hoursLeft) end
    end
    local waitText
    if #record.heaps == 0 then
        waitText = say("FloorEmpty")
    elseif soonest then
        waitText = say("NoneDone", UI.durationText(soonest))
    else
        waitText = say("NoneDoneStopped")
    end
    return { place = place, placeC = placeC, rows = rows, doneIds = doneIds, allIds = allIds, waitText = waitText,
        count = #record.heaps }
end

local function viewOf(station)
    local record, place = floorNow(station)
    return FloorUI.view(record, place)
end

-- The jobs, queued: the grain into the inventory first, then the walk, then the hand jobs (vanilla's order).
function FloorUI.put(playerObj, station, items)
    if #items == 0 then return end
    for _, item in ipairs(items) do ISInventoryPaneContextMenu.transferIfNeeded(playerObj, item) end
    if not UI.walkTo(playerObj, station) then return end
    for _, item in ipairs(items) do ISTimedActionQueue.add(TPVinegarFloor:new(playerObj, station, "put", item)) end
end

function FloorUI.take(playerObj, station, ids)
    if #ids == 0 or not UI.walkTo(playerObj, station) then return end
    for _, id in ipairs(ids) do ISTimedActionQueue.add(TPVinegarFloor:new(playerObj, station, "take", nil, id)) end
end

-- The carried Steeped Grain, the furthest sprouted first (it finishes soonest).
local function carriedGrain(playerObj)
    local grain = UI.findItems(playerObj, function(item) return item:getFullType() == V.STEEPED end)
    local sprouted = {}
    for _, item in ipairs(grain) do sprouted[item] = item:getModData()[V.SPROUTED_KEY] or 0 end
    table.sort(grain, function(a, b) return sprouted[a] > sprouted[b] end)
    return grain
end

-- What Floor Info's drop square makes of a dragged selection: the grain it would spread, as many as fit.
function FloorUI.dropJudge(record, items)
    local take, refused = {}, nil
    local room = V.floorRoom(record)
    for _, item in ipairs(items) do
        if item:getFullType() ~= V.STEEPED then
            refused = refused or say("NeedsSteeped")
        elseif #take >= room then
            refused = refused or say("FloorFull")
        else
            table.insert(take, item)
        end
    end
    if #take == 0 then return { take = take, lines = { refused or say("FloorFull") }, refused = refused } end
    local lines = { say("DropSpread", tostring(#take), tostring(#items)), say("DropRoom", tostring(room)) }
    return { take = take, lines = lines, refused = #take < #items and refused or nil }
end

-- Floor Info

local FloorWindow = InfoWindow:derive("TraditionalPreservationVinegarFloorWindow")

function FloorWindow:new(playerObj, station)
    local o = InfoWindow.new(self, playerObj, station)
    o.title = say("FloorInfo")
    return o
end

function FloorWindow:refresh()
    self.floorView = viewOf(self.station)
end

function FloorWindow:render()
    ISCollapsableWindow.render(self)
    if self.isCollapsed or not self.floorView then return end
    local view = self.floorView
    local station, playerObj = self.station, self.playerObj
    local y = self:top()
    y = self:row(y, KEY .. "InfoPlace", UI.placeText(view.place, view.placeC))
    y = self:row(y, KEY .. "RateLabel", UI.percent(V.maltingRate(view.placeC)))
    y = self:row(y, KEY .. "InfoHolds", say("InfoHeapsValue", tostring(view.count), tostring(V.FLOOR_HEAPS)))
    y = self:pieceList(y, KEY .. "InfoHeaps", view.rows)
    local done, all = view.doneIds, view.allIds
    y = self:buttonRow(y, {
        { title = UI.say(MENU .. "TakeDone", tostring(#done)), enabled = #done > 0,
          tooltip = #done == 0 and view.waitText or nil, onClick = function() FloorUI.take(playerObj, station, done) end },
        { title = UI.say(MENU .. "TakeAllCount", tostring(#all)), enabled = #all > 0,
          tooltip = #all > #done and say("TakeAllHelp") or nil, onClick = function() FloorUI.take(playerObj, station, all) end },
    })
    y = self:dropZone(y, say("DropIdle"), function(items) return FloorUI.dropJudge(V.floorOf(station), items) end,
        function(take) FloorUI.put(playerObj, station, take) end)
    local notes = { say("NoteMalting", tostring(V.GREEN_MALT_DAYS[1])) }
    if view.count == 0 then table.insert(notes, 1, say("NoteFloorEmpty")) end
    self:drawNotes(y, notes)
end

function FloorUI.open(playerObj, station)
    InfoWindow.open(FloorWindow, playerObj, station)
end

-- The menu

function FloorUI.addMenu(context, playerObj, station)
    local record, place = floorNow(station)
    local view = FloorUI.view(record, place)
    local floorIcon = getTexture(FLOOR_ICON)
    local option = context:addOption(getText("IGUI_CraftingWindow_MaltingFloor"))
    option.iconTexture = floorIcon
    local menu = context:getNew(context)
    context:addSubMenu(option, menu)

    local status = menu:addOption(say("MenuHeaps", tostring(view.count), tostring(V.FLOOR_HEAPS)))
    status.isDisabled = true
    status.iconTexture = floorIcon
    local lines = { UI.placeText(view.place, view.placeC) }
    for index, row in ipairs(view.rows) do table.insert(lines, index .. ". " .. row.name .. ": " .. row.text) end
    UI.tooltip(status, table.concat(lines, " <LINE> "))
    local info = menu:addOption(say("FloorInfo"), playerObj, FloorUI.open, station)
    info.iconTexture = floorIcon
    UI.topInfo(context, say("FloorInfo"), floorIcon, playerObj, FloorUI.open, station)

    local grain = carriedGrain(playerObj)
    if #grain > 0 then
        local row = { label = getText(MENU .. "Spread"), room = V.floorRoom(record), pieces = grain,
            help = say("SpreadHelp"), noRoom = say("FloorFull") }
        local spread = PiecesUI.row(menu, row, function(chosen)
            if row.room > 0 then FloorUI.put(playerObj, station, chosen) end
        end)
        spread.iconTexture = grain[1]:getTex()
    end

    -- Take Done is always there: greyed until a heap is done, saying when the next will be.
    local done, all = view.doneIds, view.allIds
    local finished = menu:addOption(UI.say(MENU .. "TakeDone", tostring(#done)), playerObj, FloorUI.take, station, done)
    finished.iconTexture = getTexture("media/textures/Item_GreenMalt.png")
    if #done == 0 then UI.disable(finished, view.waitText) end
    if #all > #done then
        local takeAll = menu:addOption(getText(MENU .. "TakeAll"), playerObj, FloorUI.take, station, all)
        takeAll.iconTexture = floorIcon
        UI.tooltip(takeAll, say("TakeAllHelp"))
    end
end

-- A floor with any heap on it stays where it is (no station moves mid-process).
UI.keepInPlace(function(isoObject)
    if not V.isFloor(isoObject) or not isoObject:hasModData() then return nil end
    local movableData = isoObject:getModData().movableData
    local record = movableData and movableData[V.FLOOR_KEY]
    return (record ~= nil and #record.heaps > 0) or nil
end)
