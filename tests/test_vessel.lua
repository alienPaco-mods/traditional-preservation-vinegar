-- Checks the Fermentation Vessel with stand-ins for the engine: the World stepping its batch (overlay, XP once), the
-- right-click menu (status, Vessel Info, Pour Wort, Pitch Yeast, Top Up the Batch, Draw Off Wort, Pour Away the Batch
-- behind a yes or no) and its hand jobs (TPPourVinegarFluid, TPPitchVinegarYeast), the hose pump from the record, and
-- that a vessel holding anything stays put. The record's rules are in test_vinegar.lua. Run from the mod folder:
-- luajit tests/test_vessel.lua
local H = dofile((os.getenv("TPCORE") or "../TraditionalPreservationCore") .. "/tests/harness.lua")
local check, near, list = H.check, H.near, H.list
H.useModPaths()
H.installClock(100)
H.installModData()
H.installEvents()
H.installGetText()

-- The mod's own modules, TP Core's and the mod's actions load for real, vanilla's are left out.
local realRequire = require
require = function(name)
    if name:find("^TraditionalPreservation") or name:find("^TimedActions/TP") then return realRequire(name) end
end

local ui = H.installMenus()
function isClient() return false end
function isServer() return false end
function getNumActivePlayers() return 0 end
local temperature = 20
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
local xp = 0
Perks = { Farming = "Farming", Cooking = "Cooking" }
function getPlayer() return { getXp = function() return { AddXP = function(_, _, amount) xp = xp + amount end } end } end
ItemTag.JAR = "base:jar"
Metabolics = {}
-- Vanilla's yes or no box: the test answers it.
local asked = {}
ISModalDialog = {}
function ISModalDialog:new(_, _, _, _, text, _, target, onclick)
    local modal = { text = text, target = target, onclick = onclick }
    function modal:initialise() end
    function modal:addToUIManager() table.insert(asked, self) end
    return modal
end
local function answer(modal, internal) modal.onclick(modal.target, { internal = internal, parent = modal }) end
JoypadState = { players = {} }

local function square(x)
    local s = {}
    function s:getX() return x end
    function s:getY() return 0 end
    function s:getZ() return 0 end
    function s:getObjects() return list({}) end
    function s:isOutside() return false end
    function s:isInARoom() return true end
    H.shutRoom(s)
    cellSquares[x .. ",0,0"] = s
    return s
end

-- A vessel facing faceIndex (0 east, 1 south) at x.
local PREFIX = "traditionalpreservationvinegar_01_"
local function vesselAt(faceIndex, x)
    local self = { square = square(x), sprites = {}, clears = 0, modData = {} }
    function self:getSprite() return { getName = function() return PREFIX .. faceIndex end } end
    function self:getSquare() return self.square end
    function self:getModData() return self.modData end
    function self:hasModData() return true end
    function self:getObjectIndex() return 0 end
    function self:isOutside() return false end
    function self:getComponent() return nil end
    function self:getX() return x end
    function self:getY() return 0 end
    function self:getZ() return 0 end
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
function inventory:getFirstTagEvalRecurse() return nil end
function inventory:getAllEvalRecurse(test)
    local found = {}
    for _, carried in ipairs(ui.carried) do if test(carried) then table.insert(found, carried) end end
    return list(found)
end
local playerObj = { getInventory = function() return inventory end, isTimedActionInstant = function() return false end,
    getPlayerNum = function() return 0 end }
function getSpecificPlayer() return playerObj end

-- A bucket holding litres of fluid (nil for none), 10 L to the brim.
local function bucket(fluid, litres)
    local container = { fluid = fluid, litres = litres or 0 }
    function container:isEmpty() return self.litres <= 0 end
    function container:getAmount() return self.litres end
    function container:getCapacity() return 10 end
    function container:getPrimaryFluid()
        local name = self.fluid
        return self.litres > 0 and { getFluidTypeString = function() return name end } or nil
    end
    function container:getPrimaryFluidAmount() return self.litres end
    function container:removeFluid(amount) self.litres = self.litres - amount end
    function container:addFluid(name, amount) self.fluid, self.litres = name, self.litres + amount end
    return H.vessel("Bucket", fluid, litres or 0, 10, {
        getFluidContainer = function() return container end,
        getFullType = function() return "Base.BucketEmpty" end,
        getContainer = function() return inventory end,
        getOutermostContainer = function() return nil end,
        getWorldItem = function() return nil end,
    })
end

local function yeast(uses)
    return { getFullType = function() return "Base.Yeast" end, getCurrentUsesFloat = function() return uses end,
        isFavorite = function() return false end, getFluidContainer = function() return nil end,
        getContainer = function() return inventory end, getTex = function() return "Yeast.png" end }
end

dofile("42/media/lua/shared/TraditionalPreservationVinegar.lua")
dofile("42/media/lua/server/TraditionalPreservationVinegarWorld.lua")
dofile("42/media/lua/client/TraditionalPreservationVinegarFloorUI.lua")
dofile("42/media/lua/client/TraditionalPreservationVinegarUI.lua")
local V = TraditionalPreservationVinegar

local function tick(times)
    for _ = 1, times or 30 do H.fire("OnTick") end
end
local function pass(hours)
    for _ = 1, hours do
        H.setHours(H.hours + 1)
        H.fire("EveryTenMinutes")
    end
end

local function menuFor(station)
    local context = H.menu()
    H.fire("OnFillWorldObjectContextMenu", 0, context, { station }, false)
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
        action.character = action.character or playerObj
        if action:isValid() then
            action:start()
            action:complete()
        end
    end
end

V.getLedger().seasonTemperature = 20
local cellar = vesselAt(0, 1)
loaders[PREFIX .. "0"](cellar)
tick()
local function canPickUp() return ISMoveableSpriteProps.canPickUpMoveable({}, playerObj, cellar:getSquare(), cellar) end
check("an empty vessel can be picked up", canPickUp() ~= false)

-- The menu on an empty vessel, a bucket of wort carried and a packet of yeast.
local wort, packet = bucket(V.WORT, 10), yeast(1)
ui.carried = { wort, packet }
local context, menu = menuFor(cellar)
check("the vessel's own entry, with its icon", context.options[1].name == "Fermentation Vessel"
    and context.options[1].iconTexture == "media/textures/Item_FermentationVessel.png")
check("the status row first, greyed", menu.options[1].name == "Fermentation Vessel: empty" and menu.options[1].isDisabled)
check("then Vessel Info, and Info at the bottom of the main menu", menu.options[2].name == "Vessel Info"
    and context.options[2].name == "Vessel Info")
local pitch = named(menu, "Pitch Yeast")
check("Pitch Yeast greyed with no wort in", pitch.isDisabled and pitch.toolTip.description == "Needs at least 10 L of wort in the tank")
check("every row has an icon", (function()
    for _, option in ipairs(menu.options) do if not option.iconTexture then return false end end
    return true
end)())

choose(named(menu, "Pour Wort").subOption.options[1])
runQueued()
local record = V.vesselOf(cellar)
check("Pour Wort fills the tank", record.wortMl == 10000 and wort:getFluidContainer():isEmpty())
check("a vessel with wort in it can't be picked up (no station moves mid-process)", canPickUp() == false)

-- Pitch Yeast: a half packet won't do, a full one starts the batch.
ui.carried = { yeast(0.5) }
context, menu = menuFor(cellar)
check("a half packet won't do", named(menu, "Pitch Yeast").toolTip.description == "Needs a full packet of yeast"
    and named(menu, "Pitch Yeast").isDisabled)
ui.carried = { packet }
context, menu = menuFor(cellar)
check("a full packet will, on the tank's whole buckets", named(menu, "Pitch Yeast").toolTip.description
    == "Uses a full packet of yeast on 10.0 L of wort.")
choose(named(menu, "Pitch Yeast"))
runQueued()
check("the batch starts on 10 L and the yeast is used up", record.run and record.run.ml == 10000 and record.wortMl == 0
    and #ui.carried == 0)
tick()
check("a working batch shows bubbling", cellar.sprites[1] == PREFIX .. V.VESSEL_BUBBLING)

-- Topping up: wort poured in while a batch works joins it.
pass(V.ALCOHOLIC_HOURS / 2)
V.vesselNow(cellar)
check("half way after half the time at 20 C", near(V.runProgress(record.run), 0.5, 0.01))
local more = bucket(V.WORT, 10)
ui.carried = { more }
context, menu = menuFor(cellar)
check("the status says how far on", menu.options[1].name:find("fermenting 10.0 L of wort, 5", 1, true) ~= nil)
check("Pitch Yeast is gone while a batch works", named(menu, "Pitch Yeast") == nil)
local topUp = named(menu, "Top Up the Batch")
check("Pour Wort becomes Top Up the Batch, saying how much more fits", topUp and topUp.toolTip.description:find("up to 10.0 L more", 1, true))
choose(topUp.subOption.options[1])
runQueued()
check("the batch is 20 L, its progress shared out", record.run.ml == 20000 and near(V.runProgress(record.run), 0.25, 0.01))
check("and the tank is still empty", record.wortMl == 0)

-- Pour Away the Batch asks first.
context, menu = menuFor(cellar)
local dump = named(menu, "Pour Away the Batch")
check("Pour Away the Batch is the last row", dump == menu.options[#menu.options])
choose(dump)
check("and asks yes or no first", #asked == 1 and asked[1].text == "Pour away the 20.0 L batch? The yeast is in it, so nothing comes back."
    and #ui.queued == 0)
answer(asked[1], "NO")
check("No leaves it be", #ui.queued == 0 and record.run ~= nil)

-- Finished: the Fermented tank, the XP once.
xp = 0
pass(V.ALCOHOLIC_HOURS)
tick()
check("a done batch goes into the Fermented tank", record.run == nil and record.fermentedMl == V.fermentedMl(20000))
check("the vessel shows it finished", cellar.sprites[1] == PREFIX .. V.VESSEL_FINISHED)
check("and the Cooking XP comes once", xp == V.FERMENT_XP)
tick()
check("not again", xp == V.FERMENT_XP)

-- Draw Off: fermented wort into empty containers, never poured away.
local empty = bucket(nil, 0)
ui.carried = { empty }
context, menu = menuFor(cellar)
check("no Pour Away row for fermented wort", named(menu, "Pour Away") == nil)
choose(named(menu, "Draw Off Fermented Wort").subOption.options[1])
runQueued()
check("Draw Off fills the container", empty:getFluidContainer().fluid == V.FERMENTED and near(empty:getFluidContainer().litres, 10)
    and record.fermentedMl == V.fermentedMl(20000) - 10000)

-- Waiting wort drawn back off keeps its age.
record.fermentedMl = 0
record.wortMl = 15000
V.vesselNow(cellar)
record.tpFluidAge.age = 20
local jug = bucket(nil, 0)
ui.carried = { jug }
context, menu = menuFor(cellar)
choose(named(menu, "Draw Off Wort").subOption.options[1])
runQueued()
check("Draw Off Wort fills the container with wort", jug:getFluidContainer().fluid == V.WORT and near(jug:getFluidContainer().litres, 10)
    and record.wortMl == 5000)
check("and the wort keeps its age in it", jug:getModData().tpFluidAge and near(jug:getModData().tpFluidAge.age, 20, 0.5))
check("and in the tank", record.tpFluidAge and near(record.tpFluidAge.age, 20, 0.5))
context, menu = menuFor(cellar)
choose(named(menu, "Pour Away the Wort"))
runQueued()
check("Pour Away the Wort empties the tank", record.wortMl == 0 and record.tpFluidAge == nil)

-- Pour Away the Batch, answered yes.
record.run = { ml = 10000, work = { age = 10, process = "alcoholic" } }
context, menu = menuFor(cellar)
asked = {}
choose(named(menu, "Pour Away the Batch"))
answer(asked[1], "YES")
runQueued()
check("Yes pours the batch away, nothing comes back", record.run == nil and not V.vesselHolds(record))
check("an emptied vessel can be picked up again", canPickUp() ~= false)

-- The hose pumps from the record.
record.fermentedMl = 19000
local caskModData = { ml = 0, strength = 0 }
check("the pump takes from the Fermented tank", V.pumpToCask(caskModData, record, 10000) == 10000 and record.fermentedMl == 9000)
check("and no translator warnings", #H.textWarnings == 0)

H.done()
