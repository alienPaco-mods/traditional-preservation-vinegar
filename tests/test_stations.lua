-- Checks the world file's stations and the batch popup with stand-ins for the engine. Run from the mod folder:
-- luajit tests/test_stations.lua
local H = dofile((os.getenv("TPCORE") or "../TraditionalPreservationCore") .. "/tests/harness.lua")
local check, near, list = H.check, H.near, H.list
H.useModPaths()
H.installClock(100)
H.installModData()
H.installEvents()
H.installGetText()

-- The mod's own modules and TP Core's load for real, vanilla's are left out.
local realRequire = require
require = function(name)
    if name:find("^TraditionalPreservationVinegar/") or name:find("^TraditionalPreservationCore/") then
        return realRequire(name)
    end
end

-- Engine stand-ins
local function noop() end
function isClient() return false end
ComponentType = { Resources = "Resources", CraftLogic = "CraftLogic" }
ResourceIO = { Input = "Input", Output = "Output" }
ResourceType = { Item = "Item", Fluid = "Fluid" }
ArrayList = { new = function() return list({}) end }
Fluid = { Get = function() return nil end }
function getPlayer() return {} end
local temperature = 25
function getClimateManager()
    return { getTemperature = function() return temperature end, getHumidity = function() return 50 end }
end
local loaders = {}
MapObjects = { OnLoadWithSprite = function(name, handler) loaders[name] = handler end }
local cellSquares = {}
function getCell()
    return { getGridSquare = function(_, x, y, z) return cellSquares[x .. "," .. y .. "," .. z] end }
end
CraftLogicUILogic = {
    new = function(_, _, logic)
        return { getCraftLogic = function() return logic end, getItemsInProgress = function() return logic.inProgress or {} end }
    end,
}
ScriptManager = { instance = { getCraftRecipe = function() return { Load = noop } end, getItem = function() return { DoParam = noop } end } }

local PREFIX = "traditionalpreservationvinegar_01_"

-- No fires here: nothing is a fireplace, and no station is a campfire.
function instanceof() return false end

local function square(x, z)
    local s = { objects = {} }
    function s:getX() return x end
    function s:getY() return 0 end
    function s:getZ() return z end
    function s:getObjects() return list(self.objects) end
    cellSquares[x .. ",0," .. z] = s
    return s
end

local function tank(litres)
    local container = { litres = litres }
    function container:getAmount() return self.litres end
    function container:getCapacity() return 20 end
    return { getFluidContainer = function() return container end }
end

-- A station on its own square, showing this sprite index. A vessel gets empty tanks and an idle run.
local function station(index, x, outside)
    local object = { square = square(x, 0), modData = {}, sprites = {}, clears = 0 }
    object.square.objects = { object }
    local logic = {}
    function logic:isRunning() return false end
    function logic:getInputsGroupName() return "in" end
    function logic:getOutputsGroupName() return "out" end
    local resources = {}
    function resources:getResourcesFromGroup(_, _, io, kind)
        if kind == "Fluid" then return list({ tank(0) }) end
        return list({ { getStoredItems = function() return list({}) end } })
    end
    function object:getComponent(kind) return kind == "Resources" and resources or logic end
    function object:getSprite() return { getName = function() return PREFIX .. index end } end
    function object:getName() return nil end
    function object:getSquare() return self.square end
    function object:getObjectIndex() return 0 end
    function object:isOutside() return outside end
    function object.square:isOutside() return outside end
    function object.square:isInARoom() return not outside end
    function object:getModData() return self.modData end
    function object:clearAttachedAnimSprite() self.sprites = {} self.clears = self.clears + 1 end
    function object:addAttachedAnimSpriteByName(name) table.insert(self.sprites, name) end
    return object
end

local function tick(times)
    for _ = 1, times or 30 do H.fire("OnTick") end
end

local function weather(hours)
    H.setHours(hours)
    H.fire("EveryTenMinutes")
end

dofile("42/media/lua/shared/TraditionalPreservationVinegar.lua")
dofile("42/media/lua/server/TraditionalPreservationVinegarWorld.lua")
local V, World = TraditionalPreservationVinegar, TraditionalPreservationVinegarWorld
V.getLedger()

-- Stations and the hose
check("the map loader knows every station face", loaders[PREFIX .. "0"] and loaders[PREFIX .. "11"] and loaders[PREFIX .. "25"])
local vessel = station(V.VESSEL_SPRITE + 1, 1, true)
local cask = station(V.CASK_SPRITE + 1, 2, true)
V.connectHose(vessel, cask)
local state = V.caskState(cask)
state.ml, state.strength = 20000, 0
loaders[PREFIX .. "1"](vessel)
tick()
check("an idle hosed vessel shows only the hose", table.concat(vessel.sprites, " ") == PREFIX .. (V.VESSEL_HOSE + 1))
tick()
check("the hose's other end is tracked from the vessel's refresh", table.concat(cask.sprites, " ")
    == PREFIX .. (V.CASK_FILLED + 1) .. " " .. PREFIX .. (V.CASK_HOSE + 1))
tick()
check("an unchanged station is left alone", cask.clears == 1 and vessel.clears == 1)

-- Weather
weather(124)
local ledger = V.getLedger()
check("the world file records the weather", ledger.temperature == 25 and near(ledger.aceticOpen, 24) and ledger.lastHour == 124)
tick()
check("a loaded cask sours", near(state.strength, 24 / V.ACETIC_HOURS * V.caskSpeed(state), 1e-3) and cask.sprites[1] == PREFIX .. (V.CASK_FILM[1] + 1))

-- The stale-station fix: once its chunk unloads the cell no longer returns its square, though the object keeps
-- it. The cask must not sour or change its marks from then on, and the vessel must keep its hose.
local strength, mark = state.strength, state.last.Open
cellSquares["2,0,0"] = nil
weather(200)
tick()
check("an unloaded cask is dropped, not refreshed", state.strength == strength and state.last.Open == mark)
check("the vessel keeps its hose while the cask is away", V.hoseLink(vessel) ~= nil and #vessel.square.objects == 1)
cellSquares["2,0,0"] = cask.square
World.track(cask)
tick()
check("a cask back in the cell catches up on the time away", near(V.getLedger().aceticOpen - mark, 76) and state.strength > strength)

-- A destroyed partner drops the hose on the floor.
local dropped = {}
function vessel.square:AddWorldInventoryItem(item) table.insert(dropped, item) end
cask.square.objects = {}
tick()
check("a hose to a station that is gone comes off", V.hoseLink(vessel) == nil and dropped[1] == V.HOSE_ITEM
    and #vessel.sprites == 0)

-- Popup
ISCraftLogicPanel = { ItemSlotAddItems = noop, createChildren = noop }
ISWidgetCraftLogicControl = { startCraft = noop }
ISWidgetCraftLogicInputControl = { updateOutputItems = noop }
ISItemSlot = { defaultVerifyItem = noop, onMouseUp = noop }
ISMoveableSpriteProps = { canPickUpMoveable = noop, getInfoPanelFlagsPerTile = noop }
ISWidgetCraftLogicOutputProgress = { updateProgressItems = function(self) self.vanillaRan = true end }
-- Cask Info derives TP Core's InfoWindow, which derives this.
local function class()
    return { derive = function() return class() end }
end
ISCollapsableWindow = class()
-- What TP Core's StationInfo derives from; the stations' provider is kept here instead of hooked.
ISPanel = H.class("ISPanel")
local stationInfo
require("TraditionalPreservationCore/StationInfo").add = function(provider) stationInfo = provider end
ISWorldMenuElements = { ContextEntity = noop }
dofile("42/media/lua/client/TraditionalPreservationVinegarUI.lua")

local function recipeData(name, hours)
    local data = { modData = {}, elapsed = 0 }
    function data:getModData() return self.modData end
    function data:setElapsedTime(value) self.elapsed = value end
    function data:getRecipe()
        return { getTime = function() return hours * 3600 end, getName = function() return "TraditionalPreservationVinegar." .. name end }
    end
    return data
end

local batch = recipeData("FermentWort", V.ALCOHOLIC_HOURS)
V.onFermentStart(batch)
batch.modData.place = "Open"
temperature = 38
weather(210)
V.onFermentUpdate(batch)
vessel.modData.vinegarRun = { ml = 20000, heat = 0 }
local slot, other = { craftRecipeData = batch }, { craftRecipeData = recipeData("SteepGrain", 2) }
local widget = { entity = vessel, progressItems = { getItemSlots = function() return { slot, other } end } }
ISWidgetCraftLogicOutputProgress.updateProgressItems(widget)
check("vanilla's list still runs, and only batches get the popup", widget.vanillaRan and slot.drawTooltip and not other.drawTooltip)

local lines = {}
local tooltip = { width = 0 }
function tooltip:getFont() end
function tooltip:DrawText() end
function tooltip:adjustWidth() end
function tooltip:getLineSpacing() return 10 end
function tooltip:beginLayout()
    return {
        addItem = function()
            local item = {}
            function item:setLabel(text) self.label = text end
            function item:setValue(text, r, g, b) self.value, self.colour = text, { r, g, b } end
            table.insert(lines, item)
            return item
        end,
        render = function() return 60 end,
    }
end
function tooltip:endLayout() end
function tooltip:setHeight() end
function tooltip:getWidth() return self.width end
function tooltip:setWidth(width) self.width = width end
slot.drawTooltip(slot, tooltip)
local shown = {}
for _, item in ipairs(lines) do table.insert(shown, item.label .. " " .. item.value) end
-- 10 hours at 38 C is 22% speed: 2.2 of 240 done, 237.8 left is 1081 hours. Every one of them over 35 C costs 1%.
check("the popup's lines", table.concat(shown, " | ") == "Progress: 1% | Fermenting: 20.0 L of wort | "
    .. "Time Remaining: 45d 1h, if the temperature holds | Temperature: 38 C (Open air) | Working Rate: 22%")
check("a slow rate is coloured, and no heat damage line", lines[5].colour[2] == 0.7 and lines[1].colour[2] == 1 and #lines == 5)
check("and no translator warnings", #H.textWarnings == 0)
check("the popup is wide enough", tooltip.width == 150)

-- The info block in the vessel's window, for the run in the open at 38 C: its tanks as rows, the run's bar.
local logic = vessel:getComponent("CraftLogic")
logic.inProgress = { [batch] = { yeast = 1 } }
function logic:getProgress() return 0.01 end
local block = stationInfo(vessel)
local rows = {}
for _, row in ipairs(block.rows) do table.insert(rows, getText(row[1]) .. " " .. row[2]) end
check("the vessel's rows", table.concat(rows, " | ") == "Place Open air | Temperature 38 C | Working rate 22% | "
    .. "Wort 0.0 of 20.0 L | Fermented 0.0 of 20.0 L")
check("the run's bar, slow", #block.bars == 1 and block.bars[1].text == "Wort: 20.0 L"
    and block.bars[1].value == "1%, 45 d 1 h left" and block.bars[1].colour[1] == 0.75)
check("and the weather note", table.concat(block.notes, " | ") == "Times left assume the temperature holds as it is now.")
local floor = station(V.FLOOR_SPRITE, 3, false)
check("an empty floor indoors", stationInfo(floor).rows[1][2] == "Indoors" and stationInfo(floor).notes[1] == "Nothing in it.")
check("the cask has no crafting window block", stationInfo(cask) == nil)
logic.inProgress = nil

-- A batch that has just finished hands its data back to the engine's pool before its slot goes.
function batch:getRecipe() return nil end
lines = {}
slot.drawTooltip(slot, tooltip)
check("a batch that has just finished draws nothing", #lines == 0)

H.done()
