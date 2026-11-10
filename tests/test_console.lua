-- Checks the debug console (TPV) loads and its commands run. Run from the mod folder: luajit tests/test_console.lua
local H = dofile((os.getenv("TPCORE") or "../TraditionalPreservationCore") .. "/tests/harness.lua")
local check = H.check
H.useModPaths()
H.installClock(100)
H.installModData()
H.installEvents()

-- Engine stand-ins
function getClimateManager()
    return { getTemperature = function() return 25 end, getHumidity = function() return 50 end }
end
local loaded = {}
ScriptManager = { instance = {} }
function ScriptManager.instance:getCraftRecipe()
    return { Load = function(_, name, text) loaded[name] = text end }
end
function ScriptManager.instance:getItem()
    return { DoParam = function() end }
end
ResourceIO = { Input = "Input", Output = "Output" }
SandboxVars = { TraditionalPreservationVinegar = {} }
-- Nothing is built near the player.
function getCell() return { getGridSquare = function() return nil end } end
local player = H.player()
function getPlayer() return player end

dofile("42/media/lua/shared/TraditionalPreservationVinegar.lua")
local V = TraditionalPreservationVinegar
local TPV, run = H.checkConsole("42/media/lua/client/TraditionalPreservationVinegarDev.lua", "TPV")

check("weather names every place", (function()
    local text = run("weather")
    for _, place in ipairs(V.PLACES) do
        if not text:find(place, 1, true) then return false end
    end
    return true
end)())
check("timers prints the three stages", run("timers"):find("Malting", 1, true) ~= nil)

local key = "acetic" .. V.PLACES[1]
local before = V.getLedger()[key] or 0
run("age", 6)
check("age adds its hours to every stage and place", V.getLedger()[key] == before + 6)

run("fast", 1)
check("fast turns the test timers on and reloads the recipes", V.TEST_HOURS == 1 and next(loaded) ~= nil)
run("fast")
check("fast with no number turns them off", V.TEST_HOURS == nil)

for _, command in ipairs({ "cask", "setCask", "mother" }) do
    check(command .. " says so when no cask is near", run(command):find("No cask", 1, true) ~= nil)
end
for _, command in ipairs({ "wort", "fermented" }) do
    check(command .. " says so when no vessel is near", run(command):find("No vessel", 1, true) ~= nil)
end

check("give with no name lists the items", run("give"):find("Items: ", 1, true) ~= nil and #player.given == 0)
run("give", "Malt", 2)
run("give", "Base.Yeast")
check("give takes a mod item's short name or a full type", #player.given == 3
    and player.given[1] == "TraditionalPreservationVinegar.Malt" and player.given[3] == "Base.Yeast")

H.done()
