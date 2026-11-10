-- Checks which sprite each station shows. Run from the mod folder: luajit tests/test_world.lua
local H = dofile((os.getenv("TPCORE") or "../TraditionalPreservationCore") .. "/tests/harness.lua")
H.useModPaths()
function isClient() return false end
local function noop() end
Events = { OnInitGlobalModData = { Add = noop }, OnTick = { Add = noop }, EveryTenMinutes = { Add = noop } }
MapObjects = { OnLoadWithSprite = noop }
dofile("42/media/lua/shared/TraditionalPreservationVinegar.lua")
dofile("42/media/lua/server/TraditionalPreservationVinegarWorld.lua")
local V, World = TraditionalPreservationVinegar, TraditionalPreservationVinegarWorld

local check = H.check

check("an empty floor shows nothing", World.floorSprite(0, nil, 0) == nil)
check("steeped grain", World.floorSprite(2, nil, 0) == V.FLOOR_STEEPED)
check("sprouting", World.floorSprite(0, 0.2, 0) == V.FLOOR_SPROUTING)
check("rootlets", World.floorSprite(0, 0.7, 0) == V.FLOOR_ROOTLETS)
check("finished until collected", World.floorSprite(0, nil, 3) == V.FLOOR_FINISHED)

check("a filled vessel", World.vesselSprite(2, nil, 0) == V.VESSEL_FILLED)
check("bubbling", World.vesselSprite(0, 0.2, 0) == V.VESSEL_BUBBLING)
check("lees settling", World.vesselSprite(0, 0.8, 0) == V.VESSEL_SEDIMENT)
check("finished until collected", World.vesselSprite(0, nil, 2) == V.VESSEL_FINISHED)

check("a new cask shows nothing", World.caskSprite({ ml = 0, strength = 0 }) == nil)
check("fresh wort shows bare", World.caskSprite({ ml = 19000, strength = 0 }) == V.CASK_FILLED)
check("the film starts thin", World.caskSprite({ ml = 19000, strength = 0.1 }) == V.CASK_FILM[1])
check("and thickens", World.caskSprite({ ml = 19000, strength = 0.5 }) == V.CASK_FILM[2])
check("until it is whole", World.caskSprite({ ml = 19000, strength = 0.99 }) == V.CASK_FILM[3])
check("a mother is a whole skin at once", World.caskSprite({ ml = 19000, strength = 0.75, mother = true }) == V.CASK_FILM[3])
check("full strength shows as finished", World.caskSprite({ ml = 15000, strength = 1, mother = true }) == V.CASK_FINISHED)
check("an emptied cask shows its mother", World.caskSprite({ ml = 0, strength = 0, mother = true }) == V.CASK_MOTHER)

H.done()
