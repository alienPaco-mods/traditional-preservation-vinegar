-- Checks the Malting Floor with stand-ins for the engine: each heap on its own clock (a new one beside heaps already
-- sprouting), Green Malt ageing from the hour it was done, a heap taken off part way keeping its sprouting, the World's
-- overlay and XP, the right-click menu (status, Info, Spread Steeped Grain, Take Done, Take Everything Off) and its hand
-- jobs (TPVinegarFloor), what Floor Info lists, its drop square, and that a floor holding anything stays put. Run from
-- the mod folder: luajit tests/test_floor.lua
local H = dofile((os.getenv("TPCORE") or "../TraditionalPreservationCore") .. "/tests/harness.lua")
local check, near, list = H.check, H.near, H.list
H.useModPaths()
H.installClock(100)
H.installModData()
H.installEvents()
H.installGetText()

-- The mod's own modules, TP Core's and the mod's action load for real, vanilla's are left out.
local realRequire = require
require = function(name)
    if name:find("^TraditionalPreservation") or name:find("^TimedActions/TP") then return realRequire(name) end
end

local ui = H.installMenus()
function isClient() return false end
function isServer() return false end
function getNumActivePlayers() return 0 end
local temperature = 16
function getClimateManager()
    return { isUpdated = function() return true end, getTemperature = function() return temperature end, getHumidity = function() return 50 end }
end
local loaders = {}
MapObjects = { OnLoadWithSprite = function(name, handler) loaders[name] = handler end }
local cellSquares = {}
function getCell()
    return { getGridSquare = function(_, x, y, z) return cellSquares[x .. "," .. y .. "," .. z] end }
end
ISPanel = H.class("ISPanel")
local given = {}
Actions = { addOrDropItem = function(_, item) table.insert(given, item) end }
local xp = 0
Perks = { Farming = "Farming", Cooking = "Cooking" }
function getPlayer() return { getXp = function() return { AddXP = function(_, _, amount) xp = xp + amount end } end } end

local function square(x, outside)
    local s = {}
    function s:getX() return x end
    function s:getY() return 0 end
    function s:getZ() return 0 end
    function s:getObjects() return list({}) end
    function s:isOutside() return outside end
    function s:isInARoom() return not outside end
    H.shutRoom(s)
    cellSquares[x .. ",0,0"] = s
    return s
end

-- A Malting Floor facing faceIndex (0 east, 1 south) at x.
local PREFIX = "traditionalpreservationvinegar_01_"
local function floorAt(faceIndex, x)
    local self = { square = square(x, false), sprites = {}, clears = 0, modData = {} }
    function self:getSprite() return { getName = function() return PREFIX .. (24 + faceIndex) end } end
    function self:getSquare() return self.square end
    function self:getModData() return self.modData end
    function self:hasModData() return true end
    function self:getObjectIndex() return 0 end
    function self:isOutside() return false end
    function self:getComponent() return nil end
    function self:clearAttachedAnimSprite() self.sprites = {} self.clears = self.clears + 1 end
    function self:addAttachedAnimSpriteByName(name) table.insert(self.sprites, name) end
    return self
end

local inventory = { Remove = function(_, item)
    for i, carried in ipairs(ui.carried) do
        if carried == item then return table.remove(ui.carried, i) end
    end
end }
function inventory:containsRecursive(item)
    for _, carried in ipairs(ui.carried) do if carried == item then return true end end
    return false
end
function inventory:getAllEvalRecurse(test)
    local found = {}
    for _, carried in ipairs(ui.carried) do if test(carried) then table.insert(found, carried) end end
    return list(found)
end
local playerObj = { getInventory = function() return inventory end, isTimedActionInstant = function() return false end }
function getSpecificPlayer() return playerObj end

local function newItem(fullType)
    local item = { fullType = fullType, modData = {} }
    function item:getFullType() return self.fullType end
    function item:getModData() return self.modData end
    function item:getContainer() return inventory end
    function item:getWorldItem() return nil end
    function item:getOutermostContainer() return nil end
    function item:isFavorite() return false end
    function item:getTex() return self.fullType .. ".png" end
    function item:getAge() return self.age or 0 end
    function item:setAge(age) self.age = age end
    return item
end
function instanceItem(fullType) return newItem(fullType) end

dofile("42/media/lua/shared/TraditionalPreservationVinegar.lua")
dofile("42/media/lua/server/TraditionalPreservationVinegarWorld.lua")
dofile("42/media/lua/client/TraditionalPreservationVinegarFloorUI.lua")
local V, World, FloorUI = TraditionalPreservationVinegar, TraditionalPreservationVinegarWorld, TraditionalPreservationVinegarFloorUI

local function tick(times)
    for _ = 1, times or 30 do H.fire("OnTick") end
end
-- Hours of weather at the temperature set, an hour at a time.
local function pass(hours)
    for _ = 1, hours do
        H.setHours(H.hours + 1)
        H.fire("EveryTenMinutes")
    end
end

-- The record: each heap its own clock, in a room at 16 C (full speed).
local barn = floorAt(0, 1)
local record = V.floorOf(barn)
local first = V.putHeap(record, newItem(V.STEEPED), H.hours, "Sheltered")
check("a heap goes on", first ~= nil and V.heapState(first, H.hours) == "sprouting" and V.heapProgress(first) == 0)
check("only Steeped Grain", V.putHeap(record, newItem(V.GREEN_MALT), H.hours, "Sheltered") == nil)
V.getLedger().seasonTemperature = 16
pass(60)
V.floorNow(barn)
check("60 hours at full speed is half of a 5 day malting", near(V.heapProgress(first), 0.5, 0.02))
local second = V.putHeap(record, newItem(V.STEEPED), H.hours, "Sheltered")
pass(62)
local _, _, _, finished = V.floorNow(barn)
check("a heap put down beside it starts its own clock", near(V.heapProgress(second), 0.52, 0.02))
check("the first is done, the second still sprouting", V.heapDone(first) and not V.heapDone(second) and finished == 1)
check("its done hour falls inside the stretch", first.doneAt > H.hours - 62 and first.doneAt <= H.hours - 1)
local _, _, _, again = V.floorNow(barn)
check("a done heap counts for XP once", again == 0)
local status = V.heapStatus(first, 16, H.hours)
check("done Green Malt says when it goes stale", status.state == "done" and status.staleIn and status.staleIn < 2)
check("Green Malt's days match its item script", V.GREEN_MALT_DAYS[1] == 2 and V.GREEN_MALT_DAYS[2] == 5)

-- Coming off: Green Malt as old as it has been done; part way, Steeped Grain that keeps its sprouting.
local malt = V.heapOutput(first, first.doneAt + 36)
check("Green Malt comes off a day and a half old", malt:getFullType() == V.GREEN_MALT and near(malt:getAge(), 1.5))
check("and stale after two days on the floor", V.heapState(first, first.doneAt + 49) == "stale"
    and V.heapState(first, first.doneAt + 121) == "rotten")
local grain = V.heapOutput(second, H.hours)
check("a heap part way comes back as Steeped Grain with its sprouting", grain:getFullType() == V.STEEPED
    and near(grain.modData[V.SPROUTED_KEY], second.work.age))
local back = V.putHeap({ heaps = {}, nextId = 1 }, grain, H.hours, "Sheltered")
check("and spread again it carries on from there", near(V.heapProgress(back), V.heapProgress(second)))
check("the floor holds four", V.floorRoom({ heaps = { 1, 2, 3, 4 } }) == 0
    and V.putHeap({ heaps = { 1, 2, 3, 4 }, nextId = 5 }, newItem(V.STEEPED), H.hours, "Sheltered") == nil)

-- Too cold: a heap waits.
temperature = -10
V.getLedger().seasonTemperature = -10
local cold = floorAt(0, 5)
cold.square.isInARoom = function() return false end
cold.square.isOutside = function() return true end
local coldHeap = V.putHeap(V.floorOf(cold), newItem(V.STEEPED), H.hours, "Open")
pass(24)
V.floorNow(cold)
check("frozen grain waits", coldHeap.work.age == 0 and V.heapStatus(coldHeap, -10, H.hours).hoursLeft == nil)
temperature = 16
V.getLedger().seasonTemperature = 16

-- The World: one overlay, and the XP once for heaps done since the last look.
local shed = floorAt(1, 7)
V.putHeap(V.floorOf(shed), newItem(V.STEEPED), H.hours, "Sheltered")
loaders[PREFIX .. "25"](shed)
tick()
check("a fresh heap shows steeped grain", table.concat(shed.sprites, " ") == PREFIX .. (V.FLOOR_STEEPED + 1))
pass(V.MALTING_HOURS + 2)
xp = 0
tick()
check("done, it shows finished malt", table.concat(shed.sprites, " ") == PREFIX .. (V.FLOOR_FINISHED + 1))
check("and the Farming XP comes once", xp == V.MALTING_XP)
tick()
check("not again", xp == V.MALTING_XP)

-- The menu: an empty floor, two Steeped Grain carried, one sprouted part way.
local empty = floorAt(0, 9)
loaders[PREFIX .. "24"](empty)
local function menuFor(station)
    local context = H.menu()
    FloorUI.addMenu(context, playerObj, station)
    return context, context.options[1].subOption
end
local function named(menu, prefix)
    for _, option in ipairs(menu.options) do
        if option.name:sub(1, #prefix) == prefix then return option end
    end
end
local function choose(option) option.onSelect(option.target, unpack(option.args)) end
local function runQueued()
    local queued = ui.queued
    ui.queued = {}
    for _, action in ipairs(queued) do
        action.setActionAnim = function() end
        if action:isValid() then
            action:start()
            action:complete()
        end
    end
end

local sprouted = newItem(V.STEEPED)
sprouted.modData[V.SPROUTED_KEY] = 30
ui.carried = { newItem(V.STEEPED), sprouted }
local context, menu = menuFor(empty)
check("the floor's own entry, with its icon", context.options[1].name == "Malting Floor"
    and context.options[1].iconTexture == "media/textures/Item_MaltingFloor.png")
check("the status row first, greyed: what it holds", menu.options[1].name == "Heaps: 0 / 4" and menu.options[1].isDisabled)
check("then Floor Info, and Info at the bottom of the main menu", menu.options[2].name == "Floor Info"
    and context.options[2].name == "Floor Info")
local spread = named(menu, "Spread Steeped Grain")
check("Spread Steeped Grain: One, All (2)", spread and spread.subOption.options[1].name == "One"
    and spread.subOption.options[2].name == "All (2)")
check("One is the grain furthest sprouted", spread.subOption.options[1].target[1] == sprouted)
local done = named(menu, "Take Done (0)")
check("Take Done (0) greyed: nothing on it", done.isDisabled and done.toolTip.description == "Nothing is on the floor.")
check("every row has an icon", (function()
    for _, option in ipairs(menu.options) do if not option.iconTexture then return false end end
    return true
end)())

choose(spread.subOption.options[2])
check("All queues one action a heap, the moves first", #ui.queued == 2 and ui.queued[1].mode == "put" and #ui.moved == 2)
runQueued()
record = V.floorOf(empty)
check("two heaps on, gone from the hands", #record.heaps == 2 and #ui.carried == 0)
check("the sprouted one carries on", near(record.heaps[1].work.age, 30))
local function canPickUp() return ISMoveableSpriteProps.canPickUpMoveable({}, playerObj, empty:getSquare(), empty) end
check("a floor holding heaps can't be picked up (no station moves mid-process)", canPickUp() == false)

-- Floor Info's rows and drop square.
pass(V.MALTING_HOURS - 20)
local floorRecord, place = V.floorNow(empty)
local view = FloorUI.view(floorRecord, place)
check("a row a heap, by what it is now", #view.rows == 2 and view.rows[1].name == "GreenMalt"
    and view.rows[2].name == "SteepedGrain")
check("a sprouting row says how long is left", view.rows[2].text:find("left", 1, true) ~= nil)
check("a done row says to kiln it, and when it goes stale", view.rows[1].text == "Done: kiln it soon"
    and view.rows[1].note:find("Stale in", 1, true) ~= nil)
check("Take Done counts the done heap", #view.doneIds == 1 and #view.allIds == 2)
local judged = FloorUI.dropJudge(floorRecord, { newItem(V.STEEPED), newItem(V.GREEN_MALT) })
check("the drop square takes Steeped Grain only, saying why not the rest", #judged.take == 1
    and judged.refused == "Only Steeped Grain goes on the floor.")
check("and refuses on a full floor", #FloorUI.dropJudge({ heaps = { 1, 2, 3, 4 } }, { newItem(V.STEEPED) }).take == 0)

-- Taking off.
given = {}
context, menu = menuFor(empty)
choose(named(menu, "Take Done (1)"))
runQueued()
check("Take Done gives the Green Malt", #given == 1 and given[1]:getFullType() == V.GREEN_MALT)
FloorUI.take(playerObj, empty, { V.floorOf(empty).heaps[1].id })
runQueued()
check("Take All gives the rest back as Steeped Grain", #given == 2 and given[2]:getFullType() == V.STEEPED
    and given[2].modData[V.SPROUTED_KEY] > 0)
check("an empty floor can be picked up", canPickUp() ~= false)
check("and no translator warnings", #H.textWarnings == 0)

H.done()
