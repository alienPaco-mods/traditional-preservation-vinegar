-- Traditional Preservation (Vinegar): the Fermentation Vessel's record (TP Core's station rule; ROADMAP section 12): the
-- Wort tank, the batch fermenting and the Fermented tank, kept in the vessel's movableData (VESSEL_KEY); the World steps
-- it, the menu and Vessel Info pour, pitch and draw off. Required by TraditionalPreservationVinegar.lua, whose V it adds to.
-- A batch is whole buckets of wort (V.batchMl) and a full packet of yeast. Its work is a FluidAgeing age on the alcoholic
-- ledger: hours at full speed where the vessel stands (by a fire by the clock; frozen it waits). At ALCOHOLIC_HOURS it
-- goes into the Fermented tank, less the lees. Waiting wort sours as it does in a bucket (V.ageTank), at the room's
-- place: a fire counts as the room it warms. Wort poured in while a batch works joins it (up to VESSEL_MAX_ML), the
-- batch's progress shared out over the new volume. Once pitched, the yeast is in: a batch is finished or poured away.
-- Fermented wort is only drawn off or pumped, never poured away.
TraditionalPreservationVinegar = TraditionalPreservationVinegar or {}
local V = TraditionalPreservationVinegar
local Fire = require "TraditionalPreservationCore/Fire"
local FluidAgeing = require "TraditionalPreservationCore/FluidAgeing"
local Station = require "TraditionalPreservationCore/Station"
local Weather = require "TraditionalPreservationCore/Weather"

-- Save key in the vessel's movableData: never rename it once the mod is out. { wortMl, fermentedMl, run, [FluidAgeing.KEY]
-- (the waiting wort's age) }; run is { ml, work (a FluidAgeing age) } while a batch ferments.
V.VESSEL_KEY = "tpvVessel"
-- Each tank holds this much.
V.TANK_ML = 20000
V.YEAST = "Base.Yeast"
V.FERMENT_WORK = { process = "alcoholic", rate = function(celsius) return V.alcoholicRate(celsius) end }

function V.vesselOf(station)
    local movableData = Station.movableData(station)
    local record = movableData[V.VESSEL_KEY]
    if not record then
        record = { wortMl = 0, fermentedMl = 0 }
        movableData[V.VESSEL_KEY] = record
    end
    return record
end

function V.runProgress(run)
    return math.min(run.work.age / V.ALCOHOLIC_HOURS, 1)
end

-- Brings a record up to now: the batch at place (fire as Fire.placeOf gives it), the waiting wort at wortPlace. A batch
-- that comes done goes into the Fermented tank. Returns true when one did.
function V.advanceVessel(record, now, place, fire, wortPlace, station, ledger)
    ledger = ledger or V.getLedger()
    V.ageTank(record, record.wortMl, wortPlace, now)
    local run = record.run
    if not run then return false end
    FluidAgeing.advance(run.work, V.FERMENT_WORK, ledger, now, place)
    if station then FluidAgeing.noteFire(run.work, fire, station, now) end
    if run.work.age < V.ALCOHOLIC_HOURS then return false end
    record.fermentedMl = record.fermentedMl + V.fermentedMl(run.ml)
    record.run = nil
    return true
end

-- Brings the vessel up to now where it stands. Returns the record, the batch's place, the fire and whether a batch came
-- done just now.
function V.vesselNow(station, now, place, fire)
    now = now or getGameTime():getWorldAgeHours()
    if not place then place, fire = Fire.placeOf(station) end
    local record = V.vesselOf(station)
    local finished = V.advanceVessel(record, now, place, fire, Weather.placeOf(station), station)
    record.place = place
    return record, place, fire, finished
end

-- The waiting wort's age as it stands now, without changing the record: for windows and menus. Nil with none.
function V.peekWort(record, now, wortPlace)
    local fluidAge = record[FluidAgeing.KEY]
    if not fluidAge or fluidAge.process ~= V.WORT_PROCESS or not V.WORT_SOURS or record.wortMl <= 0 then return nil end
    return FluidAgeing.advance(FluidAgeing.copy(fluidAge), V.WORT_FLUID_KIND, V.getLedger(), now, wortPlace)
end

-- Room for wort: in the running batch while there is one, else in the Wort tank.
function V.wortRoom(record)
    if record.run then return math.max(V.VESSEL_MAX_ML - record.run.ml, 0) end
    return math.max(V.TANK_ML - record.wortMl, 0)
end

-- Why a batch can't be pitched now, as a translation key, or nil when it can.
function V.pitchRefusal(record, now, wortPlace)
    if record.run then return "IGUI_TraditionalPreservationVinegar_InUse" end
    if V.batchMl(record.wortMl) <= 0 then return "IGUI_TraditionalPreservationVinegar_NeedsWort" end
    if V.isSour(V.peekWort(record, now, wortPlace)) then return "IGUI_TraditionalPreservationVinegar_WortSour" end
    if record.fermentedMl > 0 then return "IGUI_TraditionalPreservationVinegar_DrawOffFirst" end
    return nil
end

-- A whole packet: the batch uses all of it.
function V.isFullYeast(item)
    return item:getFullType() == V.YEAST and item:getCurrentUsesFloat() >= 1
end

-- Starts a batch on the whole buckets in the Wort tank (call V.vesselNow first). Returns its litres in ml, or nil.
function V.pitch(record, now, place)
    local ml = V.batchMl(record.wortMl)
    if record.run or ml <= 0 then return nil end
    record.wortMl = record.wortMl - ml
    -- Wort left over keeps its age; none left forgets it.
    V.ageTank(record, record.wortMl, record.place or place, now)
    record.run = { ml = ml, work = FluidAgeing.newFluidAge(V.FERMENT_WORK, V.getLedger(), now, place) }
    return ml
end

-- Fresh wort topping up a batch thins its progress by its share (call V.vesselNow first).
function V.topUp(run, ml)
    run.work.age = run.work.age * run.ml / (run.ml + ml)
    run.ml = run.ml + ml
end

-- Wort poured in: into the running batch while there is one, else into the Wort tank, bringing its age (the older
-- wins, as with milk). Returns the millilitres taken.
function V.pourWortIn(record, ml, fluidAge, wortPlace)
    ml = math.min(ml, V.wortRoom(record))
    if ml <= 0 then return 0 end
    if record.run then
        V.topUp(record.run, ml)
        return ml
    end
    if fluidAge then FluidAgeing.receive(record, fluidAge, record.wortMl > 0, wortPlace) end
    record.wortMl = record.wortMl + ml
    return ml
end

-- Takes up to ml of fermented wort out. Returns the millilitres taken.
function V.drawOff(record, ml)
    ml = math.min(ml, record.fermentedMl)
    if ml <= 0 then return 0 end
    record.fermentedMl = record.fermentedMl - ml
    return ml
end

-- Takes up to ml of the waiting wort out; the rest keeps its age, none left forgets it. Returns the millilitres taken.
function V.drawOffWort(record, ml, wortPlace, now)
    ml = math.min(ml, record.wortMl)
    if ml <= 0 then return 0 end
    record.wortMl = record.wortMl - ml
    V.ageTank(record, record.wortMl, wortPlace, now)
    return ml
end

function V.pourAwayWort(record)
    record.wortMl = 0
    record[FluidAgeing.KEY] = nil
end

-- The yeast went in with it, so nothing comes back.
function V.pourAwayBatch(record)
    record.run = nil
end

-- True while the vessel holds anything.
function V.vesselHolds(record)
    return record.run ~= nil or record.wortMl > 0 or record.fermentedMl > 0
end

-- How the batch is doing at placeC: { progress, rate, hoursLeft (nil while it waits) }, or nil with none.
function V.runStatus(record, placeC)
    local run = record.run
    if not run then return nil end
    local rate = V.alcoholicRate(placeC)
    local status = { progress = V.runProgress(run), rate = rate, ml = run.ml }
    if rate > 0 then status.hoursLeft = math.max(V.ALCOHOLIC_HOURS - run.work.age, 0) / rate end
    return status
end
