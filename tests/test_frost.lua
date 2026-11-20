-- Checks what frost does (TraditionalPreservationVinegarFrost.lua): a Mother of Vinegar in a jar 1/48 of the way to
-- rotten an hour frozen, a cask's mother a layer for every 6 h frozen and never its last, Steeped Grain (carried or a
-- heap on the Malting Floor) Spent Grain once frozen through (6 h, not 5), a basement and a fire never freezing, the
-- sandbox's Frost harms off, and cooked or burnt items left to vanilla. Run from the mod folder: luajit tests/test_frost.lua
local H = dofile((os.getenv("TPCORE") or "../TraditionalPreservationCore") .. "/tests/harness.lua")
local check, near = H.check, H.near
H.useModPaths()
H.installClock(100)
H.installModData()
H.installEvents()
ScriptManager = { instance = {} }
function ScriptManager.instance:getCraftRecipe() return { Load = function() end } end
function ScriptManager.instance:getItem() return { DoParam = function() end } end

-- A food item: its age, its rotten day, its modData; added to and taken from a container.
local function newItem(fullType, rotten)
    local item = { fullType = fullType, age = 0, rotten = rotten or 0, modData = {} }
    function item:getFullType() return self.fullType end
    function item:getModData() return self.modData end
    function item:getAge() return self.age end
    function item:setAge(age) self.age = age end
    function item:getOffAgeMax() return self.rotten end
    function item:isCooked() return self.cooked == true end
    function item:isBurnt() return self.burnt == true end
    function item:getContainer() return self.container end
    function item:getWorldItem() return nil end
    return item
end
function instanceItem(fullType) return newItem(fullType, 6) end
local bag = { items = {} }
function bag:Remove(item) self.items[item] = nil item.container = nil end
function bag:AddItem(item) self.items[item] = true item.container = self end

dofile("42/media/lua/shared/TraditionalPreservationVinegar.lua")
local V = TraditionalPreservationVinegar
local Frost = require "TraditionalPreservationCore/Frost"
local Fire = require "TraditionalPreservationCore/Fire"

-- Hours of weather at celsius, ten minutes at a time, on the mod's ledger and the frost ledger (TP Core records the
-- frost ledger in game).
local function frostWeather(hours, celsius)
    for _ = 1, hours * 6 do
        H.setHours(H.hours + 1 / 6)
        V.advance(V.getLedger(), H.hours, celsius)
        Frost.recordWeather(H.hours, celsius)
    end
end
frostWeather(1, 5)

-- A mother in a jar: 1/48 of the way to rotten (40 days) an hour frozen.
local openJar, cellarJar, offJar = newItem(V.MOTHER_ITEM, 40), newItem(V.MOTHER_ITEM, 40), newItem(V.MOTHER_ITEM, 40)
local cookedJar = newItem(V.MOTHER_ITEM, 40)
cookedJar.cooked = true
for _, jar in ipairs({ openJar, offJar, cookedJar }) do V.lookAtMother(jar, H.hours, "Open") end
V.lookAtMother(cellarJar, H.hours, "Basement")
check("the first look starts a frost record", openJar.modData[V.FROST_KEY] ~= nil and openJar.age == 0)
frostWeather(3, -5)
V.lookAtMother(openJar, H.hours, "Open")
V.lookAtMother(cellarJar, H.hours, "Basement")
V.lookAtMother(cookedJar, H.hours, "Open")
SandboxVars = { TraditionalPreservationVinegar = { FrostDamage = false } }
V.lookAtMother(offJar, H.hours, "Open")
SandboxVars = nil
check("three hours at -5 C cost a mother in a jar 3/48 of its 40 days", near(openJar.age, 3 / 48 * 40, 0.05))
check("a basement never freezes", cellarJar.age == 0)
check("Frost harms off: no harm, but the record goes on", offJar.age == 0 and offJar.modData[V.FROST_KEY].age > 2.9)
check("a cooked mother keeps vanilla's timer: no record, no harm", cookedJar.age == 0 and cookedJar.modData[V.FROST_KEY] == nil)
frostWeather(3, -2)
V.lookAtMother(openJar, H.hours, "Open")
check("-2 C doesn't freeze a mother (it freezes at -3 C)", near(openJar.age, 3 / 48 * 40, 0.05))
frostWeather(60, -5)
V.lookAtMother(openJar, H.hours, "Open")
check("two days and more of frost: rotten, and no older than that", near(openJar.age, 40))

-- A mother in a cask: a layer for every 6 h frozen, never the last.
local cask = { ml = 10000, strength = 1, mother = true, layers = 3, souredMl = 0 }
local hearthCask = { ml = 10000, strength = 1, mother = true, layers = 3, souredMl = 0 }
local offCask = { ml = 10000, strength = 1, mother = true, layers = 3, souredMl = 0 }
V.updateCask(cask, V.getLedger(), "Open", H.hours)
V.updateCask(offCask, V.getLedger(), "Open", H.hours)
V.updateCask(hearthCask, V.getLedger(), "Open", H.hours)
hearthCask.fireUntil, hearthCask.placeWithoutFire = H.hours + 100, "Open"
V.updateCask(hearthCask, V.getLedger(), Fire.PLACE, H.hours)
check("a cask's mother starts a frost record", cask[V.CASK_FROST_KEY] ~= nil and cask[V.CASK_FROST_KEY].age == 0)
frostWeather(5, -5)
V.updateCask(cask, V.getLedger(), "Open", H.hours)
check("five hours frozen: every layer still there", V.motherLayers(cask) == 3)
frostWeather(1, -5)
V.updateCask(cask, V.getLedger(), "Open", H.hours)
check("six hours: a layer lost", V.motherLayers(cask) == 2)
frostWeather(3, -5)
V.updateCask(cask, V.getLedger(), "Open", H.hours)
check("the hours short of the next layer wait", V.motherLayers(cask) == 2 and near(cask[V.CASK_FROST_KEY].layerHours, 3, 0.05))
frostWeather(30, -5)
V.updateCask(cask, V.getLedger(), "Open", H.hours)
check("never below one layer: the mother lives through", V.motherLayers(cask) == 1 and cask.mother == true)
V.updateCask(hearthCask, V.getLedger(), Fire.PLACE, H.hours)
check("a cask by a lit fire never freezes", V.motherLayers(hearthCask) == 3 and hearthCask[V.CASK_FROST_KEY].age == 0)
SandboxVars = { TraditionalPreservationVinegar = { FrostDamage = false } }
V.updateCask(offCask, V.getLedger(), "Open", H.hours)
SandboxVars = nil
check("Frost harms off: the cask keeps its layers", V.motherLayers(offCask) == 3 and offCask[V.CASK_FROST_KEY].age > 30)
V.takeMother(cask)
V.updateCask(cask, V.getLedger(), "Open", H.hours)
check("a cask without a mother keeps no frost record", cask[V.CASK_FROST_KEY] == nil)

-- Steeped Grain carried: Spent Grain once frozen through, 6 h, not 5.
frostWeather(1, 5)
local grain, cellarGrain, burntGrain = newItem(V.STEEPED), newItem(V.STEEPED), newItem(V.STEEPED)
burntGrain.burnt = true
bag:AddItem(grain)
V.lookAtSteepedGrain(grain, H.hours, "Open")
V.lookAtSteepedGrain(cellarGrain, H.hours, "Basement")
V.lookAtSteepedGrain(burntGrain, H.hours, "Open")
frostWeather(5, -5)
check("five hours frozen: the sprout lives", not V.lookAtSteepedGrain(grain, H.hours, "Open"))
frostWeather(1, -5)
-- Ten-minute readings add up to a hair under six hours: TP Core's Frost.frozenThrough sees six at the next one.
frostWeather(1 / 6, -5)
check("six hours: the sprout is dead", V.lookAtSteepedGrain(grain, H.hours, "Open"))
check("a basement never freezes it", not V.lookAtSteepedGrain(cellarGrain, H.hours, "Basement"))
check("a burnt one is left to vanilla", not V.lookAtSteepedGrain(burntGrain, H.hours, "Open") and burntGrain.modData[V.FROST_KEY] == nil)
local spent = V.killSprout(grain)
check("and it becomes Spent Grain where it was", spent and spent:getFullType() == V.SPENT_GRAIN and bag.items[spent] and not bag.items[grain])
check("a dead one won't go on the floor", V.putHeap({ heaps = {}, nextId = 1 }, grain, H.hours, "Open") == nil)

-- Heaps on the Malting Floor: the same, and the frost a carried grain had goes on with it.
frostWeather(1, 5)
local floor = { heaps = {}, nextId = 1 }
local carried = newItem(V.STEEPED)
V.lookAtSteepedGrain(carried, H.hours, "Open")
frostWeather(4, -5)
V.lookAtSteepedGrain(carried, H.hours, "Open")
local fromBag = V.putHeap(floor, carried, H.hours, "Open")
local fresh = V.putHeap(floor, newItem(V.STEEPED), H.hours, "Open")
local function advanceFloor() for _, heap in ipairs(floor.heaps) do V.advanceHeap(heap, H.hours, "Open", nil, nil, V.getLedger()) end end
advanceFloor()
frostWeather(2 + 1 / 6, -5)
advanceFloor()
check("a heap carries the frost its grain had: 4 h and 2 more, dead", V.heapState(fromBag, H.hours) == "dead")
frostWeather(3, -5)
advanceFloor()
check("a new heap beside it, a little over 5 hours frozen: still sprouting", V.heapState(fresh, H.hours) == "sprouting")
frostWeather(1 + 1 / 6, -5)
advanceFloor()
check("6 hours: dead", V.heapState(fresh, H.hours) == "dead" and V.heapStatus(fresh, -5, H.hours).state == "dead")
frostWeather(48, 15)
advanceFloor()
check("a dead heap no longer malts", fresh.work.age == 0 and not V.heapDone(fresh))
local off = V.heapOutput(fresh, H.hours)
check("it comes off as Spent Grain, as old as it has been dead", off:getFullType() == V.SPENT_GRAIN and near(off:getAge(), 2, 0.05))
local cellarFloor = V.putHeap({ heaps = {}, nextId = 1 }, newItem(V.STEEPED), H.hours, "Basement")
local offHeap = V.putHeap(floor, newItem(V.STEEPED), H.hours, "Open")
V.advanceHeap(cellarFloor, H.hours, "Basement", nil, nil, V.getLedger())
V.advanceHeap(offHeap, H.hours, "Open", nil, nil, V.getLedger())
frostWeather(12, -10)
V.advanceHeap(cellarFloor, H.hours, "Basement", nil, nil, V.getLedger())
SandboxVars = { TraditionalPreservationVinegar = { FrostDamage = false } }
V.advanceHeap(offHeap, H.hours, "Open", nil, nil, V.getLedger())
SandboxVars = nil
check("a floor in a basement never freezes", V.heapState(cellarFloor, H.hours) == "sprouting" and cellarFloor.frost.age == 0)
check("Frost harms off: the heap lives, its record goes on", V.heapState(offHeap, H.hours) == "sprouting" and offHeap.frost.age > 11)
local back = V.heapOutput(offHeap, H.hours)
check("Steeped Grain taken off keeps its frost record", back.modData[V.FROST_KEY].age == offHeap.frost.age)

H.done()
