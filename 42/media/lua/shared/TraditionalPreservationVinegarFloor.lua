-- Traditional Preservation (Vinegar): the Malting Floor's record, one heap a Steeped Grain, each on its own clock (TP
-- Core's station rule: pieces put on a station; ROADMAP section 12). It holds FLOOR_HEAPS heaps, kept in the floor's
-- movableData (FLOOR_KEY); the World steps it, the menu and Floor Info put on and take off. Required by
-- TraditionalPreservationVinegar.lua, whose V it adds to.
-- A heap's work is a FluidAgeing age on the malting ledger: hours at full speed at the floor's place (the malting curve;
-- frozen it waits). At MALTING_HOURS it is Green Malt, which goes stale and rots on the floor as it does anywhere
-- (vanilla's food age, counted from the hour it was done). A heap taken off part way comes back as Steeped Grain that
-- remembers its sprouting; off the floor it waits. Frozen through, a sprouting heap's sprout is dead and it is Spent
-- Grain (TraditionalPreservationVinegarFrost.lua), which ages as Green Malt does from the hour it died.
TraditionalPreservationVinegar = TraditionalPreservationVinegar or {}
local V = TraditionalPreservationVinegar
local Fire = require "TraditionalPreservationCore/Fire"
local FluidAgeing = require "TraditionalPreservationCore/FluidAgeing"
local Station = require "TraditionalPreservationCore/Station"
local Frost = require "TraditionalPreservationCore/Frost"

-- Save key in the floor's movableData: never rename it once the mod is out. { heaps = { heap ... }, nextId }; a heap is
-- { id, work (a FluidAgeing age), doneAt (the world hour it was done), paid (its XP given), frost (its frost record,
-- TP Core's Frost, while it sprouts), deadAt (the world hour frost killed its sprout) }.
V.FLOOR_KEY = "tpvFloor"
V.FLOOR_HEAPS = 4
V.STEEPED = "TraditionalPreservationVinegar.SteepedGrain"
V.GREEN_MALT = "TraditionalPreservationVinegar.GreenMalt"
-- Green Malt's DaysFresh and DaysTotallyRotten (the item script; tests/test_scripts.lua holds them together).
V.GREEN_MALT_DAYS = { 2, 5 }
-- On a Steeped Grain taken off part way: the hours of sprouting it had.
V.SPROUTED_KEY = "tpvSprouted"
V.MALT_WORK = { process = "malting", rate = function(celsius) return V.maltingRate(celsius) end }

function V.floorOf(station)
    local movableData = Station.movableData(station)
    local record = movableData[V.FLOOR_KEY]
    if not record then
        record = { heaps = {}, nextId = 1 }
        movableData[V.FLOOR_KEY] = record
    end
    return record
end

function V.heapDone(heap)
    return heap.doneAt ~= nil
end

function V.heapDead(heap)
    return heap.deadAt ~= nil
end

function V.heapProgress(heap)
    if V.heapDone(heap) then return 1 end
    return math.min(heap.work.age / V.MALTING_HOURS, 1)
end

-- Days the Green Malt (or the Spent Grain of a dead heap) has aged on the floor, as vanilla counts a food's age (the
-- sandbox's Food Spoilage on it).
function V.heapAgeDays(heap, now)
    local since = heap.doneAt or heap.deadAt
    if not since then return 0 end
    return math.max(now - since, 0) / 24 * FluidAgeing.foodRotSpeed()
end

-- "sprouting", "dead" (frozen through: Spent Grain), "done", "stale" or "rotten".
function V.heapState(heap, now)
    if V.heapDead(heap) then return "dead" end
    if not V.heapDone(heap) then return "sprouting" end
    local days = V.heapAgeDays(heap, now)
    if days >= V.GREEN_MALT_DAYS[2] then return "rotten" end
    return days >= V.GREEN_MALT_DAYS[1] and "stale" or "done"
end

-- Brings one heap up to now at place. Done part way through a stretch, its Green Malt ages from that point of it. A
-- sprouting heap's frost is brought up to now too (at the place and fire its work was seen at), and frozen through
-- it is dead: no more work.
function V.advanceHeap(heap, now, place, fire, station, ledger)
    if V.heapDead(heap) then return end
    local workWas, hourWas = heap.work.age, heap.work.hour or now
    FluidAgeing.advance(heap.work, V.MALT_WORK, ledger, now, place)
    if station then FluidAgeing.noteFire(heap.work, fire, station, now) end
    if not V.heapDone(heap) then
        local hours = Frost.see(heap, "frost", V.GRAIN_FROST, now, heap.work)
        if hours > 0 and V.frostHarms() then V.frostHeap(heap, hours, now) end
        if V.heapDead(heap) then return end
    end
    if V.heapDone(heap) or heap.work.age < V.MALTING_HOURS then return end
    local worked = heap.work.age - workWas
    local share = worked > 0 and (V.MALTING_HOURS - workWas) / worked or 1
    heap.doneAt = hourWas + (now - hourWas) * math.max(math.min(share, 1), 0)
end

-- Brings every heap on the floor up to now. Returns the record, the place, the fire and how many heaps came done
-- since the last look and have not had their XP (marked paid here).
function V.floorNow(station, now, place, fire)
    now = now or getGameTime():getWorldAgeHours()
    if not place then place, fire = Fire.placeOf(station) end
    local record = V.floorOf(station)
    local ledger, finished = V.getLedger(), 0
    for _, heap in ipairs(record.heaps) do
        V.advanceHeap(heap, now, place, fire, station, ledger)
        if V.heapDone(heap) and not heap.paid then
            heap.paid = true
            finished = finished + 1
        end
    end
    record.place = place
    return record, place, fire, finished
end

function V.floorRoom(record)
    return V.FLOOR_HEAPS - #record.heaps
end

-- Spreads a carried Steeped Grain on the floor, as far on as it had sprouted and with the frost it had. Returns the
-- heap, or nil when full (or the grain's sprout is dead).
function V.putHeap(record, item, now, place)
    if V.floorRoom(record) <= 0 or item:getFullType() ~= V.STEEPED or V.sproutDead(item) then return nil end
    local work = FluidAgeing.newFluidAge(V.MALT_WORK, V.getLedger(), now, place)
    work.age = item:getModData()[V.SPROUTED_KEY] or 0
    local frost = item:getModData()[V.FROST_KEY]
    local heap = { id = record.nextId, work = work, frost = frost and FluidAgeing.copy(frost) or nil }
    record.nextId = record.nextId + 1
    table.insert(record.heaps, heap)
    return heap
end

function V.heapById(record, id)
    for _, heap in ipairs(record.heaps) do
        if heap.id == id then return heap end
    end
end

-- Takes the heap off the record. Returns it, or nil.
function V.takeHeap(record, id)
    for index, heap in ipairs(record.heaps) do
        if heap.id == id then return table.remove(record.heaps, index) end
    end
end

-- What a heap comes off as, a new item: Green Malt as old as it has been done, Spent Grain as old as it has been dead,
-- or Steeped Grain that keeps its sprouting and its frost.
function V.heapOutput(heap, now)
    if V.heapDead(heap) then
        local spent = instanceItem(V.SPENT_GRAIN)
        spent:setAge(V.heapAgeDays(heap, now))
        return spent
    end
    if V.heapDone(heap) then
        local malt = instanceItem(V.GREEN_MALT)
        malt:setAge(V.heapAgeDays(heap, now))
        return malt
    end
    local grain = instanceItem(V.STEEPED)
    if heap.work.age > 0 then grain:getModData()[V.SPROUTED_KEY] = heap.work.age end
    if heap.frost then grain:getModData()[V.FROST_KEY] = FluidAgeing.copy(heap.frost) end
    return grain
end

-- How a heap is doing at placeC: { state, progress (0 to 1), rate, hoursLeft (to done at this rate; nil when it waits),
-- ageDays, staleIn, rottenIn (days, done) }.
function V.heapStatus(heap, placeC, now)
    local state = V.heapState(heap, now)
    local rate = V.maltingRate(placeC)
    local status = { state = state, progress = V.heapProgress(heap), rate = rate }
    if state == "dead" then
        status.ageDays = V.heapAgeDays(heap, now)
        return status
    end
    if state ~= "sprouting" then
        local speed = FluidAgeing.foodRotSpeed()
        status.ageDays = V.heapAgeDays(heap, now)
        if state == "done" then status.staleIn = (V.GREEN_MALT_DAYS[1] - status.ageDays) / speed end
        if state ~= "rotten" then status.rottenIn = (V.GREEN_MALT_DAYS[2] - status.ageDays) / speed end
        return status
    end
    if rate > 0 then status.hoursLeft = (V.MALTING_HOURS - heap.work.age) / rate end
    return status
end

-- The floor's look (one overlay for the whole floor): the stage most heaps are at, a tie going to the further on.
-- Rootlets show from halfway.
V.ROOTLETS_FROM = 0.5
local LOOK_ORDER = { "steeped", "sprouting", "rootlets", "finished" }

function V.heapLook(heap)
    if V.heapDone(heap) then return "finished" end
    local progress = V.heapProgress(heap)
    if progress >= V.ROOTLETS_FROM then return "rootlets" end
    return progress > 0 and "sprouting" or "steeped"
end

function V.floorLook(record)
    local counts, best = {}, nil
    for _, heap in ipairs(record.heaps) do
        local look = V.heapLook(heap)
        counts[look] = (counts[look] or 0) + 1
    end
    for _, look in ipairs(LOOK_ORDER) do
        if counts[look] and counts[look] >= (counts[best] or 0) then best = look end
    end
    return best
end
