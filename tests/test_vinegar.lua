-- Checks the vinegar rules outside the game. Run from the mod folder: luajit tests/test_vinegar.lua
local H = dofile((os.getenv("TPCORE") or "../TraditionalPreservationCore") .. "/tests/harness.lua")
H.useModPaths()
local hours = 100
function getGameTime() return { getWorldAgeHours = function() return hours end } end
function getText(key, a, b) return (a or key) .. " (" .. tostring(b) .. " L)" end
local store = {}
ModData = { getOrCreate = function() return store end }
local onInit
Events = { OnInitGlobalModData = { Add = function(handler) onInit = handler end } }
local loaded = {}
ScriptManager = { instance = {} }
function ScriptManager.instance:getCraftRecipe()
    return { Load = function(_, name, text) loaded[name] = text end }
end
local params = {}
function ScriptManager.instance:getItem(fullType)
    return { DoParam = function(_, text) params[fullType] = text end }
end
dofile("42/media/lua/shared/TraditionalPreservationVinegar.lua")
local V = TraditionalPreservationVinegar

local check = H.check

local list = H.list

local function recipeData(time)
    local data = { modData = {}, elapsed = 0 }
    function data:getModData() return self.modData end
    function data:getElapsedTime() return self.elapsed end
    function data:setElapsedTime(value) self.elapsed = value end
    function data:getRecipe() return { getTime = function() return time end } end
    function data:getAllInputItemsWithFlag() return list(self.inputs) end
    function data:getAllCreatedItems() return list(self.created) end
    function data:getAllConsumedItems() return list(self.used or {}) end
    return data
end

-- Temperature
check("alcohol: best at 18 to 25 C", V.alcoholicRate(18) == 1 and V.alcoholicRate(25) == 1)
check("alcohol: slower at 14 C", V.alcoholicRate(14) < 1 and V.alcoholicRate(14) > V.alcoholicRate(10))
check("alcohol: very slow below 10 C", V.alcoholicRate(5) < 0.051)
check("alcohol: still active at 28 C", V.alcoholicRate(28) > 0.85)
check("alcohol: slows above 30 C", V.alcoholicRate(36) < 0.5)
check("acetic: best at 20 to 30 C", V.aceticRate(20) == 1 and V.aceticRate(30) == 1)
check("acetic: very slow below 10 C", V.aceticRate(5) < 0.051)
check("acetic: reduced above 30 C", V.aceticRate(33) < 1)
V.SENSITIVITY = 0
check("sensitivity off runs at full speed", V.alcoholicRate(-20) == 1 and V.aceticRate(45) == 1)
V.SENSITIVITY = 1.5
check("harsh never stops a batch above freezing", V.aceticRate(-2) >= V.MIN_RATE and V.alcoholicRate(-2) >= V.MIN_RATE
    and V.maltingRate(1) >= V.MIN_RATE)
check("wort and vinegar pause frozen, at -3 C", V.alcoholicRate(-3) == 0 and V.aceticRate(-20) == 0)
V.SENSITIVITY = 1
local Weather = require "TraditionalPreservationCore/Weather"
check("a room is the season's mean, a little warmer in a cool one", Weather.placeTemperature({ temperature = 30, seasonTemperature = 12 }, "Sheltered") == Weather.roomTemperature(12)
    and Weather.roomTemperature(12) > 12)

check("malting: best at 12 to 20 C", V.maltingRate(12) == 1 and V.maltingRate(20) == 1)
check("malting: stalls in frost", V.maltingRate(1) < 0.051)
check("malting: wet grain pauses frozen at 0 C", V.maltingRate(0) == 0)
check("a frozen cask has no time left, it waits", V.caskStatus({ ml = 1000, strength = 0.5 }, { temperature = -10, seasonTemperature = -10 }, "Open").hoursLeft == nil)
check("malting: suffers in heat", V.maltingRate(30) < 0.35)

-- Timers
local function runHours(temperature, count, data, update)
    for _ = 1, count do
        hours = hours + 1
        V.advance(V.getLedger(), hours, temperature)
        update(data)
    end
end

local ALCOHOL_TIME = V.ALCOHOLIC_HOURS * 3600
local batch = recipeData(ALCOHOL_TIME)
V.onFermentStart(batch)
runHours(22, 120, batch, V.onFermentUpdate)
check("120 hours at the best temperature is half of a 10 day batch", math.abs(batch.elapsed - ALCOHOL_TIME / 2) < 1)
hours = hours + 200
V.advance(V.getLedger(), hours, 22)
V.onFermentUpdate(batch)
check("hours spent unloaded count on return", math.abs(batch.elapsed - 320 * 3600) < 1 or batch.elapsed == ALCOHOL_TIME)
hours = hours + 500
V.advance(V.getLedger(), hours, 22)
V.onFermentUpdate(batch)
check("and it stops at done", batch.elapsed == ALCOHOL_TIME)

local malt = recipeData(V.MALTING_HOURS * 3600)
V.onMaltStart(malt)
runHours(16, 60, malt, V.onMaltUpdate)
check("60 hours at the best temperature is half of a 5 day malting", math.abs(malt.elapsed - 60 * 3600) < 1)
local oldLedger = { lastHour = hours, alcoholicOpen = 0, alcoholicSheltered = 0, aceticOpen = 0, aceticSheltered = 0, heat = 0 }
store.ledger, oldLedger = oldLedger, store.ledger
V.fillLedger()
check("a save from before malting gets its totals", V.getLedger().maltingOpen == 0)
store.ledger = oldLedger

local smooth = recipeData(ALCOHOL_TIME)
V.onFermentStart(smooth)
runHours(22, 1, smooth, V.onFermentUpdate)
local atRecord = smooth.elapsed
hours = hours + 0.1
V.onFermentUpdate(smooth)
check("the bar keeps moving between weather records", math.abs(smooth.elapsed - atRecord - 360) < 0.01)
local doneBefore = smooth.modData.done
hours = hours + 0.1
V.onFermentUpdate(smooth)
check("without counting that time twice", smooth.modData.done == doneBefore)
hours = hours + 0.8
V.advance(V.getLedger(), hours, 22)
V.onFermentUpdate(smooth)
check("and the next record lands where the bar already was", math.abs(smooth.elapsed - 2 * 3600) < 0.01)

local chilled = recipeData(ALCOHOL_TIME)
V.onFermentStart(chilled)
runHours(0, 100, chilled, V.onFermentUpdate)
check("cold barely moves a batch", chilled.elapsed <= 100 * 3600 * 0.06)

local roofed = recipeData(ALCOHOL_TIME)
V.onFermentStart(roofed)
roofed.modData.sheltered = true
V.getLedger().seasonTemperature = 20
runHours(-5, 10, roofed, V.onFermentUpdate)
check("a sheltered vessel goes by the season, not the frost", roofed.elapsed > 10 * 3600 * 0.5)

local pooled = recipeData(ALCOHOL_TIME)
pooled.modData = { done = 500, sheltered = true, place = "Hearth", fireUntil = 9, under = "Open" }
V.onFermentStart(pooled)
check("a reused recipe object starts clean", pooled.modData.done == 0 and pooled.modData.sheltered == nil
    and pooled.modData.place == nil and pooled.modData.fireUntil == nil and pooled.modData.under == nil)

-- The popup
local ledger = V.newLedger(0)
ledger.temperature, ledger.seasonTemperature = 22, 15
local status = V.batchStatus("alcoholic", { done = 120 }, 240, ledger)
check("the popup shows progress", status.progress == 0.5)
check("and the time left at the best temperature", status.hoursLeft == 120 and status.rate == 1)
ledger.temperature = 5
status = V.batchStatus("alcoholic", { done = 120 }, 240, ledger)
check("the cold stretches the time left", status.hoursLeft > 2000 and status.temperature == 5)
status = V.batchStatus("alcoholic", { done = 120, sheltered = true }, 240, ledger)
check("a sheltered batch goes by the season, a room's", status.temperature == Weather.roomTemperature(15) and status.place == "Sheltered")
ledger.temperature = 25
check("the floor goes by its own temperature range", V.batchStatus("malting", { done = 60 }, 120, ledger).rate < 0.7)
check("a run saved with heat hours loses nothing (heat harm is gone, 0.2.10)", V.fermentedMl(20000) == math.floor(20000 * V.FERMENT_YIELD + 0.5)
    and V.batchStatus("alcoholic", { done = 0, heat = 10 }, 240, ledger).heatLoss == nil)

-- Liquids
local function container(name, amount, capacity, other)
    local c = { name = name, amount = amount, capacity = capacity or 10, other = other or 0 }
    function c:isEmpty() return self.amount + self.other <= 0 end
    function c:getAmount() return self.amount + self.other end
    function c:getPrimaryFluidAmount() return self.amount end
    function c:getCapacity() return self.capacity end
    function c:getPrimaryFluid() return self.name and { getFluidTypeString = function() return self.name end } or nil end
    function c:Empty() self.amount, self.other = 0, 0 end
    function c:addFluid(fluid, litres) self.name, self.amount = fluid, self.amount + litres end
    return c
end
check("a bucket of wort counts as wort", V.holdsOnly(container(V.WORT, 10), V.WORT))
check("a mixture doesn't", not V.holdsOnly(container(V.WORT, 8, 10, 2), V.WORT))
check("nor an empty bucket", not V.holdsOnly(container(nil, 0), V.WORT))
check("nor another liquid", not V.holdsOnly(container(V.FERMENTED, 10), V.WORT))

local function bucketItem(fullType)
    local item = { modData = {} }
    function item:getFullType() return fullType end
    function item:getModData() return self.modData end
    function item:getFluidContainer() self.fluid = self.fluid or container(nil, 0); return self.fluid end
    function item:getContainer() return { DoRemoveItem = function() item.removed = true end } end
    function item:getWorldItem() return nil end
    return item
end
local bucketOut = bucketItem("Base.BucketEmpty")
local grain = { getFluidContainer = function() return nil end, getFullType = function() return "TraditionalPreservationVinegar.SpentGrain" end }
local strain = recipeData(200)
strain.created = { grain, bucketOut }
V.onStrained(strain, "player")
check("straining leaves 10 L of wort in the bucket", V.holdsOnly(bucketOut.fluid, V.WORT) and bucketOut.fluid.amount == 10)

-- A Forged Bucket goes in at Mash Malt and comes back at Strain Mash
local forgedIn, mash = bucketItem("Base.BucketForged"), bucketItem("TraditionalPreservationVinegar.BucketMash")
local mashing = recipeData(300)
mashing.used, mashing.created = { { getFluidContainer = function() return nil end }, forgedIn }, { mash }
V.onMashed(mashing)
local forgedOut
instanceItem = function(fullType) forgedOut = bucketItem(fullType); return forgedOut end
Actions = { addOrDropItem = function() end }
local plainOut = bucketItem("Base.BucketEmpty")
local strainForged = recipeData(200)
strainForged.used, strainForged.created = { mash }, { plainOut, grain }
V.onStrained(strainForged, "player")
check("a forged bucket comes back forged, with the wort in it", forgedOut and forgedOut:getFullType() == "Base.BucketForged"
    and V.holdsOnly(forgedOut.fluid, V.WORT) and forgedOut.fluid.amount == 10 and plainOut.removed)
check("a run takes one bucket of wort", V.batchMl(10000) == 10000 and V.batchMl(15000) == 10000)
check("or two, and never more", V.batchMl(20000) == 20000 and V.batchMl(25000) == 20000)
check("and nothing short of a bucket", V.batchMl(9000) == 0)
check("a bucket's dregs still count as a bucket", V.batchMl(9999.5) == 10000)
check("a run gives back 95%", V.fermentedMl(10000) == 9500 and V.fermentedMl(20000) == 19000)

-- The cask: one continuous pool
local cask = { ml = 0, strength = 0 }
check("a fresh cask has room for 30 L", V.caskRoom(cask) == 30000)
check("a full vessel run goes in", V.pourIntoCask(cask, 19000) == 19000 and cask.strength == 0)
check("no bottles before full strength", V.bottlesLeft(cask) == 0 and not V.takeBottle(cask))

V.getLedger().seasonTemperature = 25
local function sourHours(state, count, temperature, sheltered)
    for _ = 1, count do
        hours = hours + 1
        V.advance(V.getLedger(), hours, temperature)
        V.updateCask(state, V.getLedger(), type(sheltered) == "string" and sheltered or sheltered and "Sheltered" or "Open")
    end
end
V.updateCask(cask, V.getLedger(), "Open")
sourHours(cask, V.ACETIC_HOURS / 2, 25, false)
check("half soured halfway through the cask time at the best temperature", math.abs(cask.strength - 0.5) < 0.001)
sourHours(cask, V.ACETIC_HOURS / 2 + 1, 25, false)
check("fully soured after the cask time (35 days by default)", cask.strength == 1 and V.ACETIC_HOURS == 35 * 24)
check("and the first full pool grows a mother", cask.mother == true)
check("souring loses a tenth to the air, so 19 L gives 17 bottles", V.bottlesLeft(cask) == 17 and math.abs(cask.ml - 19000 * math.exp(-0.1)) < 300)

local bottled = 0
while V.takeBottle(cask) do bottled = bottled + 1 end
check("exactly that many come out", bottled == 17)
check("what is left after the last bottle stays as starter", cask.ml > 0 and cask.ml < 1000 and cask.strength == 1)

local topped = { ml = 15000, strength = 1, mother = true }
V.pourIntoCask(topped, 5000)
check("new wort thins the pool by its share", topped.ml == 20000 and topped.strength == 0.75)
check("with sour vinegar left in, the mother speeds it up", V.hasStarter(topped) and math.abs(V.caskSpeed(topped) - 1 / 0.75) < 1e-9)
local drained = { ml = 20000, strength = 0, mother = true }
check("an emptied cask refilled has no starter, so no bonus", not V.hasStarter(drained) and V.caskSpeed(drained) == 1)
check("past 22.5 L the culture slows for want of air", V.airShare(22500) == 1 and V.airShare(30000) == V.CROWDED_RATE and V.airShare(26250) == 0.75)
local brimming = { ml = 29000, strength = 0 }
check("the cask takes no more than 30 L", V.pourIntoCask(brimming, 5000) == 1000 and brimming.ml == 30000)

local quick = { ml = 20000, strength = 0.75, mother = true }
V.updateCask(quick, V.getLedger(), "Open")
sourHours(quick, math.ceil(V.ACETIC_HOURS * 0.25 * (1 - V.CULTURE_BONUS)) + 2, 25, false)
check("a quarter's souring goes a quarter faster with a starter", math.abs(quick.strength - 1) < 0.01)

local away = { ml = 10000, strength = 0 }
V.updateCask(away, V.getLedger(), "Open")
hours = hours + V.ACETIC_HOURS
V.advance(V.getLedger(), hours, 25)
V.updateCask(away, V.getLedger(), "Open")
check("time away from the cask still counts", away.strength == 1)

local cold = { ml = 10000, strength = 0 }
V.updateCask(cold, V.getLedger(), "Open")
sourHours(cold, 24, 0, false)
check("frost barely sours an open cask", cold.strength < 0.003)
local cellar = { ml = 10000, strength = 0 }
V.updateCask(cellar, V.getLedger(), "Sheltered")
V.getLedger().seasonTemperature = 25
sourHours(cellar, 24, -5, true)
check("but a room in a warm season keeps working", cellar.strength > 24 * 0.8 / V.ACETIC_HOURS)

local deep = { ml = 10000, strength = 0 }
V.updateCask(deep, V.getLedger(), "Basement")
sourHours(deep, 24, -15, "Basement")
-- The season slips towards the frost; the basement only a third as far, so no slower than its last hour's rate.
check("a basement cask keeps souring through a frost", deep.strength >= 24 * V.aceticRate(V.placeTemperature(V.getLedger(), "Basement")) / V.ACETIC_HOURS - 1e-6
    and deep.strength > 10 * cold.strength)
check("a basement swings two fifths as far as the ground", V.placeTemperature({ temperature = 35, seasonTemperature = 30, groundTemperature = 27.5 }, "Basement") == 17)
check("which malts at full speed in summer", V.maltingRate(17) == 1)
-- No fire anywhere: the cell has no squares round a station.
function getCell() return { getGridSquare = function() return nil end } end
local function stationAt(z, outside)
    return { getSquare = function() return { getX = function() return 0 end, getY = function() return 0 end,
        getZ = function() return z end, isOutside = function() return outside end,
        isInARoom = function() return not outside end } end }
end
check("below ground is a basement", V.placeOf(stationAt(-1, false)) == "Basement")
check("a room is sheltered", V.placeOf(stationAt(0, false)) == "Sheltered")
check("and the yard is open", V.placeOf(stationAt(0, true)) == "Open")

-- A cask by a fire sours at 28 C by the clock until the fire's noted fuel runs out, then as the place under it.
local Hearth = require "TraditionalPreservationCore/Hearth"
local hearthside = { ml = 10000, strength = 0 }
V.updateCask(hearthside, V.getLedger(), "Open")
hearthside.fireUntil, hearthside.under = hours + 12, "Open"
sourHours(hearthside, 24, -15, Hearth.PLACE)
check("a cask by a fire in a frost sours 12 hours at 28 C, then barely",
    math.abs(hearthside.strength - 12 * V.aceticRate(Hearth.FIRE_C) / V.ACETIC_HOURS) < 0.002)
local downstairs = recipeData(ALCOHOL_TIME)
V.onFermentStart(downstairs)
downstairs.modData.place = "Basement"
V.getLedger().seasonTemperature = 25
runHours(-10, 10, downstairs, V.onFermentUpdate)
check("a basement vessel in summer works through a cold snap",
    downstairs.elapsed >= 10 * 3600 * V.alcoholicRate(V.placeTemperature(V.getLedger(), "Basement")) - 1
    and downstairs.elapsed > 2 * 10 * 3600 * V.alcoholicRate(-10))
local oldRun = recipeData(ALCOHOL_TIME)
oldRun.modData = { done = 5, lastOpen = V.getLedger().alcoholicOpen, lastSheltered = V.getLedger().alcoholicSheltered, lastHeat = V.getLedger().heat, heat = 0, sheltered = true }
runHours(22, 1, oldRun, V.onFermentUpdate)
check("a run saved before basements carries on under its roof", oldRun.modData.done > 5 and oldRun.modData.last.Basement ~= nil)
local oldCask = { ml = 10000, strength = 0, lastOpen = V.getLedger().aceticOpen, lastSheltered = V.getLedger().aceticSheltered }
sourHours(oldCask, 1, 25, true)
check("and so does a cask", oldCask.strength > 0 and oldCask.lastSheltered == nil)

local caskStatus = V.caskStatus({ ml = 20000, strength = 0.5 }, { temperature = 25 }, "Open")
check("the menu says how long to full strength", math.abs(caskStatus.hoursLeft - V.ACETIC_HOURS / 2) < 0.001)

local poured = { ml = 12200, strength = 1, mother = true }
V.emptyCask(poured)
check("emptying a cask pours it all away", poured.ml == 0 and poured.strength == 0 and V.bottlesLeft(poured) == 0)
check("and keeps the mother", poured.mother == true)

local old = { vinegarMl = 3000, mother = true }
local oldCask = { modData = { movableData = old }, getModData = function(self) return self.modData end }
local migrated = V.caskState(oldCask)
check("a cask from before the pool keeps its vinegar at full strength", migrated.ml == 3000 and migrated.strength == 1 and migrated.vinegarMl == nil)

-- The mother
local grown = { ml = 0, strength = 0 }
V.pourIntoCask(grown, 19000)
V.sour(grown, V.ACETIC_HOURS * 2)
check("a cask that first fully sours grows a one-layer mother", grown.mother and V.motherLayers(grown) == 1)
local feeding = { ml = 0, strength = 0, mother = true, layers = 1, souredMl = 0 }
V.pourIntoCask(feeding, 20000)
V.sour(feeding, V.ACETIC_HOURS * 2)
check("a full batch thickens it by a layer", V.motherLayers(feeding) == 2 and V.canSplitMother(feeding))
local thin = { ml = 0, mother = true, layers = 1 }
check("a one-layer mother can't be split", not V.canSplitMother(thin) and not V.splitMother(thin))
check("splitting peels one layer off and leaves the rest", V.splitMother(feeding) and feeding.mother and V.motherLayers(feeding) == 1)
check("taking lifts it all out", V.takeMother(thin) and not thin.mother and V.motherLayers(thin) == 0)
check("nothing to take from a cask without one", not V.takeMother(thin))
check("a jar's mother goes into an empty cask as one layer", V.addMother(thin) and V.motherLayers(thin) == 1)
check("but not into a cask that has one", not V.addMother(thin))
local function jar(tagged, empty)
    return { hasTag = function() return tagged end, getFluidContainer = function() return { isEmpty = function() return empty end } end }
end
ItemTag = { JAR = "jar" }
check("an empty jar takes a mother", V.isEmptyJar(jar(true, true)))
check("a full jar doesn't", not V.isEmptyJar(jar(true, false)))
check("nor anything that isn't a jar", not V.isEmptyJar(jar(false, true)))

-- The next mother layer
local young = { ml = 0, strength = 0 }
V.addMother(young)
check("a new mother needs a full layer's vinegar to grow another", V.nextLayerMl(young) == V.MOTHER_LAYER_ML and not V.canSplitMother(young))
V.growMother(young, 6000)
check("and counts down as the cask makes vinegar", V.nextLayerMl(young) == V.MOTHER_LAYER_ML - 6000)
V.growMother(young, V.MOTHER_LAYER_ML - 6000)
check("then it can be split", V.canSplitMother(young) and V.nextLayerMl(young) == V.MOTHER_LAYER_ML)

-- The hose
local function tank(litres)
    local t = { litres = litres }
    function t:getAmount() return self.litres end
    function t:removeFluid(amount) self.litres = self.litres - amount end
    return t
end
local roomy, out = { ml = 5000, strength = 1, mother = true }, tank(19)
check("the hose pumps the amount asked for", V.pumpToCask(roomy, out, 10000) == 10000 and roomy.ml == 15000 and math.abs(out.litres - 9) < 1e-9)
check("and it thins the pool like any pour", math.abs(roomy.strength - 5 / 15) < 1e-9)
check("no more than the tank holds", V.pumpToCask(roomy, out, 20000) == 9000 and math.abs(out.litres) < 1e-9)
local nearlyFull, rest = { ml = 25000, strength = 1 }, tank(19)
check("no more than the cask has room for", V.pumpToCask(nearlyFull, rest, 19000) == 5000 and nearlyFull.ml == 30000 and math.abs(rest.litres - 14) < 1e-9)
check("an empty tank pumps nothing", V.pumpToCask({ ml = 0, strength = 0 }, tank(0), 5000) == 0)
check("nor do dregs", V.pumpToCask({ ml = 0, strength = 0 }, tank(0.03), 5000) == 0)
local function choices(caskMl, available)
    local byKind = {}
    for _, choice in ipairs(V.pumpChoices({ ml = caskMl, strength = 1 }, available)) do byKind[choice.kind .. (choice.wanted or "")] = choice end
    return byKind
end
local c = choices(16400, 19000)
check("with 13.6 L of room, 5 and 10 L can be pumped", not c.step5000.reason and not c.step10000.reason and c.step10000.ml == 10000)
check("up to the air line is 6.1 L", not c.air.reason and c.air.ml == 6100)
check("and all that fits is 13.6 L", not c.all.reason and c.all.ml == 13600)
c = choices(25000, 19000)
check("past the air line, that option says so", c.air.reason == "IGUI_TraditionalPreservationVinegar_PumpAtAirLine" and c.air.reasonMl == V.AIR_ML)
check("and 10 L is refused for room", c.step10000.reason == "IGUI_TraditionalPreservationVinegar_PumpNoRoom" and c.step10000.reasonMl == 5000)
c = choices(5000, 4000)
check("a short tank refuses 5 L and names what's there", c.step5000.reason == "IGUI_TraditionalPreservationVinegar_PumpNotEnough" and c.step5000.reasonMl == 4000)
check("but all that fits takes the 4 L", not c.all.reason and c.all.ml == 4000 and c.air.ml == 4000)
c = choices(30000, 19000)
check("a full cask refuses everything", c.all.reason == "IGUI_TraditionalPreservationVinegar_PumpNoRoom" and c.air.reason ~= nil)
c = choices(5000, 0)
check("an empty vessel refuses everything", c.all.reason == "IGUI_TraditionalPreservationVinegar_PumpEmpty" and c.step5000.reason == "IGUI_TraditionalPreservationVinegar_PumpEmpty")

local function station(x, y, z, kindIndex)
    local object = { modData = {}, square = { getX = function() return x end, getY = function() return y end, getZ = function() return z end } }
    function object:getModData() return self.modData end
    function object:getSquare() return self.square end
    function object:getSprite() return { getName = function() return V.spriteName(kindIndex) end } end
    return object
end
local vesselObject, caskNear, caskFar = station(10, 10, 0, V.VESSEL_SPRITE), station(11, 12, 0, V.CASK_SPRITE), station(14, 10, 0, V.CASK_SPRITE)
local caskNext, caskCorner, caskAbove = station(10, 11, 0, V.CASK_SPRITE), station(12, 8, 0, V.CASK_SPRITE), station(10, 11, 1, V.CASK_SPRITE)
local world = { ["10,10,0"] = { vesselObject }, ["11,12,0"] = { caskNear }, ["14,10,0"] = { caskFar }, ["10,11,1"] = { caskAbove } }
local savedGetCell = getCell
function getCell()
    return { getGridSquare = function(_, x, y, z)
        local here = world[x .. "," .. y .. "," .. z]
        if here == false then return { getObjects = function() return list({}) end } end
        return here and { getObjects = function() return list(here) end } or nil
    end }
end
local inReach = V.casksForHose(vesselObject)
check("a vessel finds a cask in hose reach, not one 4 squares off or up a floor", #inReach == 1 and inReach[1] == caskNear)
world["10,11,0"], world["12,8,0"] = { caskNext }, { caskCorner }
inReach = V.casksForHose(vesselObject)
check("with several in reach it lists them all, nearest first", #inReach == 3 and inReach[1] == caskNext
    and inReach[2] == caskNear and inReach[3] == caskCorner)
world["10,11,0"], world["12,8,0"] = nil, nil
V.connectHose(vesselObject, caskNear)
check("joining marks both ends", V.hoseLink(vesselObject).x == 11 and V.hoseLink(caskNear).x == 10)
check("each end finds the other", V.hosePartner(vesselObject) == caskNear and V.hosePartner(caskNear) == vesselObject)
check("a joined cask isn't offered for another hose", #V.casksForHose(vesselObject) == 0)
world["11,12,0"] = false
local gone, goneLoaded = V.hosePartner(vesselObject)
check("a destroyed cask is noticed when its square is loaded", gone == nil and goneLoaded)
world["11,12,0"] = nil
local away, awayLoaded = V.hosePartner(vesselObject)
check("but an unloaded one isn't mistaken for gone", away == nil and not awayLoaded)
world["11,12,0"] = { caskNear }
V.disconnectHose(caskNear)
check("detaching from either end clears both", V.hoseLink(vesselObject) == nil and V.hoseLink(caskNear) == nil)
getCell = savedGetCell

-- Bottles back
ISHandcraftAction = { performRecipe = function() end }
package.preload["Entity/TimedActions/ISHandcraftAction"] = function() end
package.preload["TraditionalPreservationVinegar"] = function() end
local given = {}
Actions = { addOrDropItem = function(_, item) table.insert(given, item) end }
function instanceItem(fullType)
    local fluid = { emptied = false }
    function fluid:Empty() self.emptied = true end
    return { fullType = fullType, fluid = fluid, getFluidContainer = function(self) return self.fluid end }
end
local mainInit = onInit
dofile("42/media/lua/shared/TraditionalPreservationVinegarBottles.lua")
local bottleInit = onInit
onInit = mainInit
local function vinegarItem(uses, bottleType)
    local item = { modData = { bottleType = bottleType }, uses = uses }
    function item:getFullType() return "Base.Vinegar2" end
    function item:getCurrentUses() return self.uses end
    function item:getModData() return self.modData end
    return item
end
local fromWater, looted, halfUsed = vinegarItem(0, "Base.WaterBottle"), vinegarItem(0, nil), vinegarItem(4, "Base.Wine")
V.returnBottles(nil, list({ fromWater, looted, halfUsed }), {})
check("a used-up Vinegar gives back the bottle it was filled into", given[1].fullType == "Base.WaterBottle")
check("emptied, as water bottles spawn full", given[1].fluid.emptied)
check("looted vinegar gives a Crafted Bottle", given[2].fullType == "Base.BottleCrafted")
check("and one with uses left gives nothing", #given == 2)
V.returnBottles(nil, list({ fromWater }), {})
check("a bottle only comes back once", #given == 2)
-- The engine's own Crafted Bottle (ReplaceOnDeplete), handed over during the craft.
local function engineSpare()
    local spare = { removed = false }
    spare.container = { DoRemoveItem = function(_, item) item.removed = true end }
    function spare:getContainer() return self.container end
    return spare
end
local inWine, spare = vinegarItem(0, "Base.Wine"), engineSpare()
V.returnBottles(nil, list({ inWine }), { spare })
check("a wine bottle comes back in place of the game's Crafted Bottle",
    spare.removed and #given == 3 and given[3].fullType == "Base.Wine" and inWine.modData.bottleGiven)
local lootedToo, keptSpare = vinegarItem(0, nil), engineSpare()
V.returnBottles(nil, list({ lootedToo }), { keptSpare })
check("looted vinegar keeps the game's Crafted Bottle, none extra", not keptSpare.removed and #given == 3)
local marked = { modData = {} }
function marked:getModData() return self.modData end
V.markBottle(marked, "Base.MilkBottle")
check("bottling writes the bottle's type on the Vinegar", marked.modData.bottleType == "Base.MilkBottle")
local vinegarParam
local realGetItem = ScriptManager.instance.getItem
ScriptManager.instance.getItem = function(_, fullType)
    return fullType == "Base.Vinegar2" and { DoParam = function(_, text) vinegarParam = text end } or { DoParam = function() end }
end
bottleInit()
ScriptManager.instance.getItem = realGetItem
check("every Vinegar used up some other way leaves a Crafted Bottle", vinegarParam == "ReplaceOnDeplete = Base.BottleCrafted")

-- Bottling from the world
local function bottle(fluidEmpty)
    return { getFluidContainer = function() return fluidEmpty ~= nil and { isEmpty = function() return fluidEmpty end } or nil end }
end
local caskObject = {
    modData = { movableData = { ml = 2000, strength = 1 } },
    getModData = function(self) return self.modData end,
    getSprite = function() return { getName = function() return V.spriteName(V.CASK_SPRITE) end } end,
}
local objects = list({ caskObject })
local nearby = { getObjects = function() return objects end }
function getCell() return { getGridSquare = function(_, x, y) return x == 10 and y == 10 and nearby or nil end } end
local player = { getCurrentSquare = function() return { getX = function() return 9 end, getY = function() return 9 end, getZ = function() return 0 end } end }
check("an empty bottle near vinegar can be filled", V.canBottle(bottle(true), player))
check("a bottle of water can't", not V.canBottle(bottle(false), player))
check("nor something that isn't a bottle", not V.canBottle(bottle(nil), player))
V.onBottled(nil, player)
check("bottling takes exactly one bottle's worth", caskObject.modData.movableData.ml == 1000)
V.onBottled(nil, player)
check("an empty cask stops bottling", not V.canBottle(bottle(true), player))
caskObject.modData.movableData = { ml = 5000, strength = 0.9 }
check("a cask short of full strength can't be bottled", not V.canBottle(bottle(true), player))

-- The bottle menu
local function named(fullType, name)
    return { getFullType = function() return fullType end, getDisplayName = function() return name end }
end
local crafted, water, water2 = named("Base.BottleCrafted", "Glass Bottle"), named("Base.WaterBottle", "Water Bottle"), named("Base.WaterBottle", "Water Bottle")
local groups = V.groupBottles({ water, crafted, water2 })
check("bottles group by kind, in name order", #groups == 2 and groups[1].name == "Glass Bottle" and groups[2].name == "Water Bottle")
check("and each group holds its bottles", #groups[1].items == 1 and #groups[2].items == 2)

-- Station inputs
check("the vessel's slot takes a packet of yeast", V.inputRefusal("vessel", "Base.Yeast") == nil)
check("and nothing else", V.inputRefusal("vessel", "Base.BucketEmpty") ~= nil)
check("the floor takes steeped grain", V.inputRefusal("floor", "TraditionalPreservationVinegar.SteepedGrain") == nil)
check("and nothing else", V.inputRefusal("floor", "Base.BarleySeed") ~= nil)

-- Sandbox
onInit()
check("the default vessel run is 10 days", loaded["TraditionalPreservationVinegar.FermentWort"]:find("864000", 1, true) ~= nil)
-- Wort that sours
check("wort: 2 days at 20 C", V.WORT_SOUR_HOURS / V.wortRate(20) == 48)
check("wort: 1 day at 30 C", V.WORT_SOUR_HOURS / V.wortRate(30) == 24)
check("wort: about 5 days in a summer cellar", math.abs(V.WORT_SOUR_HOURS / V.wortRate(13) / 24 - 5) < 0.01)
check("wort: never while frozen", V.wortRate(0) == 0 and V.wortRate(-10) == 0)
check("wort: not scaled by the sensitivity", (function() local was = V.SENSITIVITY; V.SENSITIVITY = 0
    local rate = V.wortRate(0); V.SENSITIVITY = was; return rate == 0 end)())
check("sour wort is both stages", V.WORT_SPEC.fresh[V.WORT] == V.SOUR_WORT and V.WORT_SPEC.spoiled[V.WORT] == V.SOUR_WORT)

local function wortHours(span, temperature, tank)
    for _ = 1, span do
        hours = hours + 1
        V.advance(V.getLedger(), hours, temperature)
    end
    return V.ageTank(tank, 10000, "Open", hours)
end
local tank = {}
local record = V.ageTank(tank, 10000, "Open", hours)
check("a filled tank starts a record", record and record.age == 0 and tank.tpFluidAge == record)
record = wortHours(47, 20, tank)
check("47 hours at 20 C: still wort", not V.isSour(record) and math.abs(V.hoursToSour(record, 20) - 1) < 0.01)
record = wortHours(1, 20, tank)
check("48 hours at 20 C: soured", V.isSour(record) and V.hoursToSour(record, 20) == nil)
tank = {}
V.ageTank(tank, 10000, "Open", hours)
record = wortHours(100, -5, tank)
check("frozen wort waits", record.age == 0 and V.hoursToSour(record, -5) == nil)
record = wortHours(24, 30, tank)
check("a day at 30 C sours it", V.isSour(record))
check("an empty tank forgets its record", V.ageTank(tank, 0, "Open", hours) == nil and tank.tpFluidAge == nil)
V.WORT_SOURS = false
check("souring off keeps no record", V.ageTank(tank, 10000, "Open", hours) == nil and tank.tpFluidAge == nil)
V.WORT_SOURS = true

SandboxVars = { TraditionalPreservationVinegar = { MaltingDays = 3, AlcoholicDays = 5, AceticDays = 14, CultureBonus = 50, TemperatureSensitivity = 1, WortSours = false } }
onInit()
check("the sandbox sets the vessel time", loaded["TraditionalPreservationVinegar.FermentWort"]:find("432000", 1, true) ~= nil)
check("the sandbox sets the malting time", loaded["TraditionalPreservationVinegar.MaltGrain"]:find("259200", 1, true) ~= nil)
check("and the cask's days, bonus and sensitivity", V.ACETIC_HOURS == 336 and V.CULTURE_BONUS == 0.5 and V.SENSITIVITY == 0)
check("Normal effort is the default, half as long again as Light", params["TraditionalPreservationVinegar.GreenMalt"] == "MinutesToCook = 180")
check("the sandbox can turn souring off", V.WORT_SOURS == false)
V.WORT_SOURS = true
check("for the mash heat and the crafts too", params["TraditionalPreservationVinegar.BucketMash"] == "MinutesToCook = 90" and loaded["TraditionalPreservationVinegar.MashMalt"]:find("450", 1, true) ~= nil)
SandboxVars.TraditionalPreservationVinegar.BrewingEffort = 3
onInit()
check("Hard effort doubles them", params["TraditionalPreservationVinegar.GreenMalt"] == "MinutesToCook = 240" and loaded["TraditionalPreservationVinegar.StrainMash"]:find("400", 1, true) ~= nil)
SandboxVars.TraditionalPreservationVinegar.BrewingEffort = 1
onInit()
check("and Light keeps the base times", params["TraditionalPreservationVinegar.BucketMash"] == "MinutesToCook = 60" and loaded["TraditionalPreservationVinegar.SteepGrain"]:find("120", 1, true) ~= nil)

V.TEST_HOURS = 1
onInit()
check("test timers set every recipe to an hour", loaded["TraditionalPreservationVinegar.MaltGrain"]:find("3600", 1, true) ~= nil and loaded["TraditionalPreservationVinegar.FermentWort"]:find("3600", 1, true) ~= nil)
check("and the cask to an hour", V.ACETIC_HOURS == 1)
check("and ignore the weather", V.aceticRate(-20) == 1)

H.done()
