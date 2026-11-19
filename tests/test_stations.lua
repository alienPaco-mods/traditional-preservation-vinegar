-- Checks the world file's stations, the weather and the hose with stand-ins for the engine (the vessel's own record,
-- menu and window: test_vessel.lua). Run from the mod folder:
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
    if name:find("^TraditionalPreservation") then
        return realRequire(name)
    end
end

-- Engine stand-ins
local function noop() end
function isClient() return false end
function getPlayer() return {} end
local temperature = 25
function getClimateManager()
    return { isUpdated = function() return true end, getTemperature = function() return temperature end, getHumidity = function() return 50 end }
end
local loaders = {}
MapObjects = { OnLoadWithSprite = function(name, handler) loaders[name] = handler end }
local cellSquares = {}
function getCell()
    return { getGridSquare = function(_, x, y, z) return cellSquares[x .. "," .. y .. "," .. z] end }
end
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

-- A station on its own square, showing this sprite index.
local function station(index, x, outside)
    local station = { square = square(x, 0), modData = {}, sprites = {}, clears = 0 }
    station.square.objects = { station }
    function station:getComponent() return nil end
    function station:getSprite() return { getName = function() return PREFIX .. index end } end
    function station:getName() return nil end
    function station:getSquare() return self.square end
    function station:getObjectIndex() return 0 end
    function station:isOutside() return outside end
    function station.square:isOutside() return outside end
    function station.square:isInARoom() return not outside end
    H.shutRoom(station.square)
    function station:getModData() return self.modData end
    function station:clearAttachedAnimSprite() self.sprites = {} self.clears = self.clears + 1 end
    function station:addAttachedAnimSpriteByName(name) table.insert(self.sprites, name) end
    return station
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
local caskModData = V.caskModData(cask)
caskModData.ml, caskModData.strength = 20000, 0
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
check("a loaded cask sours", near(caskModData.strength, 24 / V.ACETIC_HOURS * V.caskSpeed(caskModData), 1e-3) and cask.sprites[1] == PREFIX .. (V.CASK_FILM[1] + 1))

-- The stale-station fix: once its chunk unloads the cell no longer returns its square, though the object keeps
-- it. The cask must not sour or change its marks from then on, and the vessel must keep its hose.
local strength, mark = caskModData.strength, caskModData.marks.Open
cellSquares["2,0,0"] = nil
weather(200)
tick()
check("an unloaded cask is dropped, not refreshed", caskModData.strength == strength and caskModData.marks.Open == mark)
check("the vessel keeps its hose while the cask is away", V.hoseLink(vessel) ~= nil and #vessel.square.objects == 1)
cellSquares["2,0,0"] = cask.square
World.track(cask)
tick()
check("a cask back in the cell catches up on the time away", near(V.getLedger().aceticOpen - mark, 76) and caskModData.strength > strength)

-- A destroyed partner drops the hose on the floor.
local dropped = {}
function vessel.square:AddWorldInventoryItem(item) table.insert(dropped, item) end
cask.square.objects = {}
tick()
check("a hose to a station that is gone comes off", V.hoseLink(vessel) == nil and dropped[1] == V.HOSE_ITEM
    and #vessel.sprites == 0)

H.done()
