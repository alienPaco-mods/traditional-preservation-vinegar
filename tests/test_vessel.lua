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
check("then its Info row, the station's full name, and the same at the bottom of the main menu",
    menu.options[2].name == "Fermentation Vessel Info" and context.options[2].name == "Fermentation Vessel Info")
local pitch = named(menu, "Pitch Yeast")
check("Pitch Yeast greyed with no wort in", pitch.isDisabled and pitch.toolTip.description == "Pour in wort first")
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
check("a done batch is fermented wort, less what foamed over (20 L topped up at a quarter: 1 L of the 4 above the line)",
    record.run == nil and near(record.fermentedMl, V.fermentedMl(19000), 30), record.fermentedMl)
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
local fermentedBefore = V.fermentedMl(19000)
check("Draw Off fills the container", empty:getFluidContainer().fluid == V.FERMENTED and near(empty:getFluidContainer().litres, 10)
    and near(record.fermentedMl, fermentedBefore - 10000, 30))

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

-- Vessel Info's band and its one tank (art/vessel_one_pool_mock.png), from a view as the window builds it.
local InfoWindow = require "TraditionalPreservationCore/InfoWindow"
local VinegarUI = TraditionalPreservationVinegarUI
local function view(wortMl, fermentedMl, status, soured, soursIn)
    return { record = { wortMl = wortMl, fermentedMl = fermentedMl, run = status and { ml = status.ml } or nil },
        status = status, soured = soured, soursIn = soursIn, placeC = 20, now = 100 }
end
local function band(v)
    local word, text = VinegarUI.vesselBand(v)
    return getText(word) .. ": " .. text
end
local working = { ml = 10000, progress = 0.3, hoursLeft = 170, rate = 1 }
check("band: empty", band(view(0, 0)) == "Empty: pour in wort to start", band(view(0, 0)))
check("band: soured wort", band(view(6000, 0, nil, true)) == "Soured: 6.0 L of wort soured: pour it away")
check("band: foaming over comes before the rest", band(view(0, 0, { ml = 18000, progress = 0.2, hoursLeft = 190, rate = 1,
    foaming = true, underpitched = true })) == "Foaming over: above the 16 L line: wort is spilling")
check("band: underpitched", band(view(0, 0, { ml = 20000, progress = 0.04, hoursLeft = 400, rate = 1, underpitched = true }))
    == "Underpitched: too much wort for its yeast: half speed")
check("band: lagging, with the time left of it", band(view(0, 0, { ml = 18000, progress = 0.3, hoursLeft = 170, rate = 1,
    lagUntil = 130 })) == "Lagging: its yeast is catching up: 30h")
check("band: a batch too cold to work", band(view(0, 0, { ml = 10000, progress = 0.3 })) == "Paused: a 10.0 L batch, too cold to work")
check("band: fermenting", band(view(0, 0, working)) == "Fermenting: a 10.0 L batch")
check("band: fermented wort ready", band(view(0, 8000)) == "Ready: 8.0 L of fermented wort to draw off")
check("band: wort waits for its yeast, any amount", band(view(6000, 0)) == "Waiting: 6.0 L of wort, pitch yeast to start")

local tank = VinegarUI.vesselHoldings(view(6000, 0, nil, false, 30))[2]
check("one tank: Wort, its litres, souring in amber, the 16 L line", tank.name == "Wort" and tank.amount == "6.0 / 20 L"
    and tank.state == "Souring (30h)" and tank.stateColour == InfoWindow.BAND_WAITING[1]
    and tank.line.share == 0.8 and tank.line.text == "16 L", tank.state)
tank = VinegarUI.vesselHoldings(view(6000, 0, nil, true))[2]
check("soured wort says so in red", tank.state == "soured" and tank.stateColour == InfoWindow.BAND_AT_RISK[1])
tank = VinegarUI.vesselHoldings(view(0, 0, { ml = 18000, progress = 0.25, hoursLeft = 180, rate = 1, foaming = true, foamedMl = 1000 }))[2]
check("a batch: Fermenting, turning from the foot, bubbling, spilling while it foams over, its loss in red",
    tank.name == "Fermenting" and tank.amount == "18.0 / 20 L" and math.abs(tank.settled.share - 0.225) < 1e-9
    and math.abs(tank.share - 0.675) < 1e-9 and tank.working.speed == 1 and tank.working.spill
    and tank.state == "25%, 8d" and tank.under == "1.0 L lost to foam" and tank.underColour == InfoWindow.BAND_AT_RISK[1], tank.state)
tank = VinegarUI.vesselHoldings(view(0, 0, { ml = 20000, progress = 0.04, hoursLeft = 400, rate = 1, underpitched = true }))[2]
check("underpitched: half the bubbles, the state in amber", tank.working.speed == 0.5 and tank.stateColour == InfoWindow.BAND_WAITING[1])
tank = VinegarUI.vesselHoldings(view(0, 0, { ml = 10000, progress = 0.5, rate = 0 }))[2]
check("paused: still, the state in amber, no loss told", tank.working.speed == 0 and tank.under == nil
    and tank.state == "50%, " .. getText("IGUI_TraditionalPreservationCore_Paused"))
tank = VinegarUI.vesselHoldings(view(0, 8000))[2]
check("fermented: keeps", tank.name == "Fermented" and tank.state == "keeps" and tank.amount == "8.0 / 20 L")
local rows = VinegarUI.vesselRows(view(0, 0), true)
check("station rows: the working rate, then the hose to the cask", rows[1][1] == "IGUI_TraditionalPreservationVinegar_RateLabel"
    and getText(rows[2][1]) == "Hose" and rows[2][2] == "Cask Connected")
check("the batch's state line: done and the time left", VinegarUI.batchText({ ml = 10000, progress = 0.45, hoursLeft = 52 }) == "45%, 2d")
local notes = VinegarUI.vesselNotes("IGUI_TraditionalPreservationVinegar_VesselBandWaiting")
check("notes before a batch: the headspace, the drag", notes[1]:find("^Fill to 16 L") ~= nil and notes[2]:find("^Drag containers of wort") ~= nil)
notes = VinegarUI.vesselNotes("IGUI_TraditionalPreservationVinegar_VesselBandUnderpitched", {})
check("notes while underpitched: repitch first", notes[1]:find("fresh packet", 1, true) ~= nil)

-- Dragging onto the tank: wort pours in as Pour Wort would.
local judged = VinegarUI.wortJudge({ wortMl = 6000, fermentedMl = 0 }, { bucket(V.WORT, 10), bucket(V.WORT, 10), bucket(V.FERMENTED, 10) })
check("two buckets of wort into 6 L: 14 L to fill it (the second pours in part), fermented wort is refused",
    #judged.take == 2 and judged.lines[1] == "Pour in 14.0 L (2)" and math.abs(judged.adds - 0.7) < 1e-9
    and judged.refused == "The vessel takes containers of wort.", judged.lines[1] .. " / " .. tostring(judged.refused))
judged = VinegarUI.wortJudge({ wortMl = 20000, fermentedMl = 0 }, { bucket(V.WORT, 10) })
check("a full vessel refuses", #judged.take == 0 and judged.lines[1] == "The vessel is full.")
judged = VinegarUI.wortJudge({ wortMl = 0, fermentedMl = 0, run = { ml = 10000 } }, { bucket(V.WORT, 10) })
check("while a batch works the pour tops it up", #judged.take == 1 and judged.lines[1] == "Top up the batch with 10.0 L (1)")
judged = VinegarUI.wortJudge({ wortMl = 0, fermentedMl = 8000 }, { bucket(V.WORT, 10) })
check("none on fermented wort: draw it off first", #judged.take == 0 and judged.lines[1] == "Draw off the fermented wort first")
judged = VinegarUI.wortJudge({ wortMl = 0, fermentedMl = 0 }, { bucket(V.SOUR_WORT, 10) })
check("soured wort is refused", #judged.take == 0 and judged.lines[1] == "The vessel takes containers of wort.")
local drop = {}
check("the drop sits on the one tank", VinegarUI.vesselHoldings(view(6000, 0), drop)[2].drop == drop)
-- Cask Info (art/cask_one_tank_mock.png): band, tank, rows, the drag.
local function caskBand(caskModData, status)
    local word, text = VinegarUI.caskBand(caskModData, status)
    return getText(word) .. ": " .. text
end
local warm = { rate = 1, hoursLeft = 200 }
check("cask band: empty", caskBand({ ml = 0, strength = 0 }, warm) == "Empty: pour in fermented wort to start")
check("cask band: ready, its bottles", caskBand({ ml = 22000, strength = 1 }, warm) == "Ready: 22.0 L of vinegar: 22 bottles")
check("cask band: too cold", caskBand({ ml = 10000, strength = 0.3 }, { rate = 0 }) == "Paused: too cold to work")
check("cask band: crowded above the air line, its slower speed", caskBand({ ml = 27000, strength = 0.2 }, warm)
    == "Crowded: above the 22.5 L line: short of air, 70% speed", caskBand({ ml = 27000, strength = 0.2 }, warm))
check("cask band: the mother at work with a starter", caskBand({ ml = 20000, strength = 0.5, mother = true }, warm)
    == "Souring: the mother at work, 133% speed", caskBand({ ml = 20000, strength = 0.5, mother = true }, warm))
check("cask band: souring without", caskBand({ ml = 20000, strength = 0.1 }, warm) == "Souring: 20.0 L at work, 100% speed")
local caskTank = VinegarUI.caskHoldings({ ml = 22000, strength = 0.62, mother = true, layers = 3 }, { rate = 1, hoursLeft = 216 })[2]
check("cask tank: Souring, vinegar rising from the foot by its strength, the mother's layers, the air line",
    caskTank.name == "Souring" and caskTank.amount == "22.0 / 30 L" and math.abs(caskTank.settled.share - 22 / 30 * 0.62) < 1e-9
    and caskTank.layers == 3 and caskTank.line.text == "22.5 L" and caskTank.state == "62%, 9d" and not caskTank.stateColour, caskTank.state)
caskTank = VinegarUI.caskHoldings({ ml = 27000, strength = 0.2 }, { rate = 1, hoursLeft = 500 })[2]
check("crowded: the state in amber", caskTank.stateColour == InfoWindow.BAND_WAITING[1])
caskTank = VinegarUI.caskHoldings({ ml = 22000, strength = 1, mother = true }, warm)[2]
check("full strength: Vinegar", caskTank.name == "Vinegar" and caskTank.state == "full strength" and caskTank.settled == nil)
rows = VinegarUI.caskRows({ ml = 22000, strength = 0.62, mother = true, layers = 3, souredMl = 0 }, warm, true)
check("cask rows: the rate, the mother's layers and the next, the hose to the vessel", getText(rows[2][1]) == "Mother"
    and rows[2][2]:find("^3 layers, next in ") ~= nil and rows[3][2] == "Vessel Connected", rows[2][2])
judged = VinegarUI.caskJudge({ ml = 20000, strength = 0.35, mother = true }, { bucket(V.FERMENTED, 10), bucket(V.WORT, 10) })
check("the cask takes fermented wort, to its room, and says when the starter thins",
    #judged.take == 1 and judged.lines[1] == "Pour in 10.0 L (1)" and judged.lines[2] == "thins the starter below 25%"
    and judged.refused == "The cask takes containers of fermented wort.", table.concat(judged.lines, " / "))
judged = VinegarUI.caskJudge({ ml = 20000, strength = 0.9, mother = true }, { bucket(V.FERMENTED, 10) })
check("a strong pool keeps its starter: no warning", #judged.lines == 1)
judged = VinegarUI.caskJudge({ ml = 30000, strength = 0.5 }, { bucket(V.FERMENTED, 10) })
check("a full cask refuses", #judged.take == 0 and judged.lines[1] == "The cask is full.")
-- The starter slots (art/starter_path_mock.png): the vessel's yeast, the cask's mother in and out.
local function item(fullType, uses, rotten)
    return { getFullType = function() return fullType end, getCurrentUsesFloat = function() return uses or 1 end,
        isRotten = function() return rotten or false end }
end
local actions = { drop = {}, click = function() end, menu = function() end, split = function() end }
local holdings = VinegarUI.vesselHoldings(view(6000, 0), drop, actions)
local slot = holdings[1]
check("vessel: the yeast's slot left of the tank, Add Starter greyed, it takes the drag", #holdings == 2 and slot.kind == "slot"
    and slot.look == "empty" and slot.name == "Add Starter" and slot.drop == actions.drop and slot.arrow == "")
slot = VinegarUI.yeastSlot(view(0, 0, working), actions)
check("a batch at work: used, nothing taken", slot.name == "used" and slot.drop == nil and slot.click == nil)
local lagging = { ml = 18000, progress = 0.3, hoursLeft = 170, rate = 1, lagUntil = 130 }
local lagView = view(0, 0, lagging)
lagView.record.run.lagUntil = 130
slot = VinegarUI.yeastSlot(lagView, actions)
check("lagging: Repitch in amber, it takes the drag", slot.name == "Repitch" and slot.nameColour == InfoWindow.BAND_WAITING[1]
    and slot.drop == actions.drop, slot.name)
check("fermented wort in: used", VinegarUI.yeastSlot(view(0, 8000), actions).name == "used")
local yeast = item(V.YEAST, 1)
judged = VinegarUI.yeastJudge(view(6000, 0), { yeast, item(V.YEAST, 1) })
check("a full packet pitches, one a batch", #judged.take == 1 and judged.take[1] == yeast and judged.lines[1] == "Pitch the yeast"
    and judged.refused == "One packet a batch: the rest stay with you.")
judged = VinegarUI.yeastJudge(view(6000, 0), { item(V.YEAST, 0.5) })
check("a part packet is refused", #judged.take == 0 and judged.lines[1] == "Needs a full packet of yeast")
local refusing = view(0, 0)
refusing.refusal = "IGUI_TraditionalPreservationVinegar_NeedsWort"
check("no wort: the pitch's refusal", #VinegarUI.yeastJudge(refusing, { yeast }).take == 0)
holdings = VinegarUI.caskHoldings({ ml = 10000, strength = 0.3 }, warm, nil, actions)
check("cask with no mother: Add Mother greyed left of the tank, no out slot", #holdings == 2 and holdings[1].look == "empty"
    and holdings[1].name == "Add Mother" and holdings[1].drop == actions.drop and holdings[2].arrow == nil)
holdings = VinegarUI.caskHoldings({ ml = 10000, strength = 0.3, mother = true, layers = 1, souredMl = 0 }, warm, nil, actions)
check("one layer: the mother in, +1 greyed out with the litres to it", #holdings == 3 and holdings[1].look == "in"
    and holdings[1].count == "1" and holdings[1].amount == "1 layer" and holdings[1].drop == nil
    and holdings[3].look == "pending" and holdings[3].count == "+1" and holdings[3].name:find("^next in ") ~= nil
    and holdings[3].click == nil and holdings[2].arrow == "", holdings[3].name)
holdings = VinegarUI.caskHoldings({ ml = 10000, strength = 0.3, mother = true, layers = 3 }, warm, nil, actions)
check("three layers: a green Split to click, the arrow green", holdings[1].amount == "3 layers" and holdings[3].look == "ready"
    and holdings[3].name == "Split" and holdings[3].click == actions.split and holdings[2].arrowColour == holdings[3].nameColour)
local mother = item(V.MOTHER_ITEM)
judged = VinegarUI.motherJudge({ ml = 0, strength = 0 }, { item(V.MOTHER_ITEM, 1, true), mother })
check("a living mother goes in, the dead one stays", #judged.take == 1 and judged.take[1] == mother and judged.lines[1] == "Add the mother")
judged = VinegarUI.motherJudge({ ml = 0, strength = 0 }, { item(V.MOTHER_ITEM, 1, true) })
check("only a dead one: it has died", #judged.take == 0 and judged.lines[1] == getText("IGUI_TraditionalPreservationVinegar_DeadMother"))
check("a cask with a mother takes no other", #VinegarUI.motherJudge({ ml = 0, strength = 0, mother = true }, { mother }).take == 0)
rows = VinegarUI.caskRows({ ml = 1000, strength = 0.5, mother = true, layers = 1, souredMl = 0 }, warm, false)
check("one layer reads as one", rows[2][2]:find("^1 layer, next in ") ~= nil, rows[2][2])
check("and no translator warnings", #H.textWarnings == 0)

H.done()
