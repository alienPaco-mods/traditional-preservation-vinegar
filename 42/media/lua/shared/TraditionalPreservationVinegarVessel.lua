-- Traditional Preservation (Vinegar): the Fermentation Vessel's record (TP Core's station rule; ROADMAP section 12),
-- kept in the vessel's movableData (VESSEL_KEY); the World steps it, the menu and Vessel Info pour, pitch and draw off.
-- Required by TraditionalPreservationVinegar.lua, whose V it adds to.
-- The vessel is one pool of TANK_ML (user, session 67, as the cask and the incubator): wort waiting, a batch
-- fermenting, or fermented wort, one at a time. Wort poured on fermented wort is refused: draw it off first. A batch
-- is all the wort in and a full packet of yeast. Its work is a FluidAgeing age on the alcoholic ledger: hours at full
-- speed where the vessel stands (by a fire by the clock; frozen it waits). At ALCOHOLIC_HOURS it is fermented wort,
-- less the lees. Waiting wort sours as it does in a bucket (V.ageTank), at the room's place: a fire counts as the room
-- it warms. Yeast needs no headspace, so a full vessel works at full speed; but above HEADSPACE_ML a batch in its
-- vigorous first half foams over and loses wort (at most FOAM_LOSS of what is above the line, by the working rate).
-- Wort poured in while a batch works joins it, the batch's progress shared out over the new volume; more than was in
-- before the day's pours (TOPUP_HOURS: ten small pours count as one big one, a little a day is a brewer's step
-- feeding), poured on a young batch, is too much for its yeast: under UNDERPITCH_PROGRESS it works at UNDERPITCH_RATE,
-- under ESTABLISHED_PROGRESS it waits LAG_HOURS a share added (at most LAG_MAX_HOURS), until a fresh packet is
-- pitched. Once pitched, the yeast is in: a batch is finished or poured away. Fermented wort is only drawn off or
-- pumped, never poured away.
TraditionalPreservationVinegar = TraditionalPreservationVinegar or {}
local V = TraditionalPreservationVinegar
local Fire = require "TraditionalPreservationCore/Fire"
local FluidAgeing = require "TraditionalPreservationCore/FluidAgeing"
local Station = require "TraditionalPreservationCore/Station"
local Weather = require "TraditionalPreservationCore/Weather"

-- Save key in the vessel's movableData: never rename it once the mod is out. { wortMl, fermentedMl, run, [FluidAgeing.KEY]
-- (the waiting wort's age) }, one of wortMl, run and fermentedMl in use at a time; run is { ml, work (a FluidAgeing
-- age), overMl (above the foam's line when pitched or last topped up), topUps ({ { hour, ml } } in the last
-- TOPUP_HOURS), underpitched, lagUntil (world hours), foamedMl } while a batch ferments.
V.VESSEL_KEY = "tpvVessel"
-- The vessel holds this much in all.
V.TANK_ML = 20000
-- The foam's line: above it a vigorous batch foams over.
V.HEADSPACE_ML = 16000
V.FOAM_LOSS = 0.5            -- the most of what is above the line that foams out, at full working rate
V.VIGOROUS = 0.5             -- a batch foams in this first share of its work
-- Topping up with more wort than is in: under the first share the yeast is underpitched, under the second it lags.
V.UNDERPITCH_PROGRESS, V.ESTABLISHED_PROGRESS = 0.2, 0.5
V.UNDERPITCH_RATE = 0.5
V.LAG_HOURS, V.LAG_MAX_HOURS = 24, 48
V.TOPUP_HOURS = 24           -- top-ups within this long count together
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

-- True while a topped-up batch waits for its yeast to catch up.
function V.lagging(run, now)
    return run.lagUntil ~= nil and now < run.lagUntil
end

-- The work since the last look, held back while underpitched or lagging, and the wort foamed over meanwhile.
local function holdBackAndFoam(run, before, from, now)
    local gained, elapsed = run.work.age - before, math.max(now - from, 0)
    if run.underpitched then gained = gained * V.UNDERPITCH_RATE end
    if run.lagUntil then
        local lagged = math.max(math.min(run.lagUntil, now) - from, 0)
        if elapsed > 0 then gained = gained * (1 - math.min(lagged / elapsed, 1)) else gained = 0 end
        if now >= run.lagUntil then run.lagUntil = nil end
    end
    run.work.age = before + gained
    local above = run.ml - V.HEADSPACE_ML
    if above <= 0 or elapsed <= 0 then return end
    local work = V.ALCOHOLIC_HOURS * V.VIGOROUS
    local vigorous = math.max(math.min(run.work.age, work) - math.min(before, work), 0) / work
    local lost = math.min((run.overMl or above) * V.FOAM_LOSS * vigorous * math.min(gained / elapsed, 1), above)
    if lost > 0 then
        run.ml = run.ml - lost
        run.foamedMl = (run.foamedMl or 0) + lost
    end
end

-- True while a batch above the line is in its vigorous first half and working: its foam runs over.
function V.foaming(run, rate)
    return run.ml > V.HEADSPACE_ML and V.runProgress(run) < V.VIGOROUS and (rate or 1) > 0
end

-- Brings a record up to now: the batch at place (fire as Fire.placeOf gives it), the waiting wort at wortPlace. A batch
-- that comes done becomes fermented wort. Returns true when one did.
function V.advanceVessel(record, now, place, fire, wortPlace, station, ledger)
    ledger = ledger or V.getLedger()
    V.ageTank(record, record.wortMl, wortPlace, now)
    local run = record.run
    if not run then return false end
    local before, from = run.work.age, run.work.hour or now
    FluidAgeing.advance(run.work, V.FERMENT_WORK, ledger, now, place)
    holdBackAndFoam(run, before, from, now)
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

-- Room for wort: in the running batch while there is one, none on fermented wort, else in the vessel.
function V.wortRoom(record)
    if record.run then return math.max(V.TANK_ML - record.run.ml, 0) end
    if record.fermentedMl > 0 then return 0 end
    return math.max(V.TANK_ML - record.wortMl, 0)
end

-- Why wort can't be poured in now, as a translation key, or nil when it can.
function V.pourRefusal(record)
    if record.fermentedMl > 0 then return "IGUI_TraditionalPreservationVinegar_DrawOffFirst" end
    if V.wortRoom(record) <= 0 then return "IGUI_TraditionalPreservationVinegar_VesselFull" end
    return nil
end

-- True when a running batch takes a fresh packet: its yeast underpitched or lagging.
function V.needsRepitch(run, now)
    return run ~= nil and (run.underpitched or V.lagging(run, now))
end

-- Why a batch can't be pitched now, as a translation key, or nil when it can (a running batch that needs it: a repitch).
function V.pitchRefusal(record, now, wortPlace)
    if record.run then return not V.needsRepitch(record.run, now) and "IGUI_TraditionalPreservationVinegar_InUse" or nil end
    if record.fermentedMl > 0 then return "IGUI_TraditionalPreservationVinegar_DrawOffFirst" end
    if record.wortMl <= 0 then return "IGUI_TraditionalPreservationVinegar_NeedsWort" end
    if V.isSour(V.peekWort(record, now, wortPlace)) then return "IGUI_TraditionalPreservationVinegar_WortSour" end
    return nil
end

-- A whole packet: the batch uses all of it.
function V.isFullYeast(item)
    return item:getFullType() == V.YEAST and item:getCurrentUsesFloat() >= 1
end

-- Starts a batch on all the wort in (call V.vesselNow first), or repitches a running one that needs it, which goes
-- on at full speed. Returns the batch's litres in ml, or nil.
function V.pitch(record, now, place)
    local run = record.run
    if run then
        if not V.needsRepitch(run, now) then return nil end
        run.underpitched, run.lagUntil = nil, nil
        return run.ml
    end
    local ml = record.wortMl
    if ml <= 0 or record.fermentedMl > 0 then return nil end
    record.wortMl = 0
    record[FluidAgeing.KEY] = nil
    record.run = { ml = ml, overMl = math.max(ml - V.HEADSPACE_ML, 0),
        work = FluidAgeing.newFluidAge(V.FERMENT_WORK, V.getLedger(), now, place) }
    return ml
end

-- The wort topped up in the last TOPUP_HOURS (dropping older pours from the record), and what was in before them.
local function recentTopUps(run, now)
    local kept, recent = {}, 0
    for _, pour in ipairs(run.topUps or {}) do
        if now - pour.hour < V.TOPUP_HOURS then
            table.insert(kept, pour)
            recent = recent + pour.ml
        end
    end
    run.topUps = kept
    return recent, run.ml - recent
end

-- What topping a running batch up with ml now would do to its yeast: "underpitched", "lag", or nil for nothing. The
-- day's pours count together, against what was in before them. Also the lag's hours.
function V.topUpRisk(run, ml, now)
    if not run or V.runProgress(run) >= V.ESTABLISHED_PROGRESS then return nil end
    local recent, before = recentTopUps(run, now)
    local added = recent + ml
    if added <= before then return nil end
    if V.runProgress(run) < V.UNDERPITCH_PROGRESS then return "underpitched" end
    -- The day's pours can outweigh what is in now once foam has taken some of it: nothing of the first batch is left
    -- to count against, so the longest lag.
    if before <= 0 then return "lag", V.LAG_MAX_HOURS end
    return "lag", math.min(V.LAG_HOURS * added / before, V.LAG_MAX_HOURS)
end

-- Fresh wort topping up a batch thins its progress by its share (call V.vesselNow first). More than was in before the
-- day's pours, on a young batch, is too much for its yeast: underpitched, or a lag of LAG_HOURS a share added.
function V.topUp(run, ml, now)
    local risk, lag = V.topUpRisk(run, ml, now)
    if risk == "underpitched" then run.underpitched = true end
    if risk == "lag" then run.lagUntil = math.max(run.lagUntil or now, now + lag) end
    run.topUps = run.topUps or {}
    table.insert(run.topUps, { hour = now, ml = ml })
    run.work.age = run.work.age * run.ml / (run.ml + ml)
    run.ml = run.ml + ml
    run.overMl = math.max(run.ml - V.HEADSPACE_ML, 0)
end

-- Wort poured in: into the running batch while there is one, else into the vessel, bringing its age (the older wins,
-- as with milk); none on fermented wort. Returns the millilitres taken.
function V.pourWortIn(record, ml, fluidAge, wortPlace, now)
    ml = math.min(ml, V.wortRoom(record))
    if ml <= 0 then return 0 end
    if record.run then
        V.topUp(record.run, ml, now or getGameTime():getWorldAgeHours())
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

-- How the batch is doing at placeC: { progress, rate, ml, underpitched, lagUntil, foamedMl, foaming, hoursLeft (nil
-- while it waits; a lag's hours not counted) }, or nil with none.
function V.runStatus(record, placeC)
    local run = record.run
    if not run then return nil end
    local rate = V.alcoholicRate(placeC)
    local status = { progress = V.runProgress(run), rate = rate, ml = run.ml, underpitched = run.underpitched,
        lagUntil = run.lagUntil, foamedMl = run.foamedMl, foaming = V.foaming(run, rate) }
    if run.underpitched then rate = rate * V.UNDERPITCH_RATE end
    if rate > 0 then status.hoursLeft = math.max(V.ALCOHOLIC_HOURS - run.work.age, 0) / rate end
    return status
end
