-- Traditional Preservation (Vinegar): keeps the weather totals, sours each cask's pool, steps the floor's heaps and
-- the vessel's batch, and shows what each station is doing: it reads each station and layers sprites itself.
if isClient() then return end

TraditionalPreservationVinegarWorld = TraditionalPreservationVinegarWorld or {}
local V = TraditionalPreservationVinegar
local World = TraditionalPreservationVinegarWorld
local Station = require "TraditionalPreservationCore/Station"
local Weather = require "TraditionalPreservationCore/Weather"
local Tiles = require "TraditionalPreservationVinegar/Tiles"
local log = require "TraditionalPreservationCore/Log"

-- Bubbling gives way to settling lees for the last part of a run.
local SEDIMENT_FROM = 0.7

-- The floor's overlay for its heaps (V.floorLook), or nil when it is bare.
local FLOOR_LOOKS = { steeped = V.FLOOR_STEEPED, sprouting = V.FLOOR_SPROUTING, rootlets = V.FLOOR_ROOTLETS, finished = V.FLOOR_FINISHED }

function World.floorSprite(record)
    local look = V.floorLook(record)
    return look and FLOOR_LOOKS[look] or nil
end

-- Sediment shows from SEDIMENT_FROM through a run.
function World.vesselSprite(waiting, progress, finished)
    if progress then
        return progress >= SEDIMENT_FROM and V.VESSEL_SEDIMENT or V.VESSEL_BUBBLING
    end
    if finished > 0 then return V.VESSEL_FINISHED end
    if waiting > 0 then return V.VESSEL_FILLED end
    return nil
end

-- Fresh wort shows bare, the skin thickens as the pool sours, and a mother is a whole skin at once.
function World.caskSprite(caskModData)
    if caskModData.ml <= 0 then
        return caskModData.mother and V.CASK_MOTHER or nil
    end
    if caskModData.strength >= 1 then return V.CASK_FINISHED end
    if caskModData.mother then return V.CASK_FILM[#V.CASK_FILM] end
    if caskModData.strength <= 0 then return V.CASK_FILLED end
    return V.CASK_FILM[math.min(math.floor(caskModData.strength * #V.CASK_FILM) + 1, #V.CASK_FILM)]
end

-- Singleplayer: the station's work goes to the player.
local function award(perk, amount)
    local player = getPlayer()
    if player then player:getXp():AddXP(perk, amount) end
end

local function stationSprite(station, sessionState)
    if sessionState.base == V.CASK_SPRITE then
        local caskModData = V.caskModData(station)
        local before = caskModData.strength
        V.updateCaskAt(caskModData, V.getLedger(), station)
        if before < 1 and caskModData.strength >= 1 then
            log("TPV", "cask fully soured: %.2f L, mother layers %d", caskModData.ml / 1000, V.motherLayers(caskModData))
        end
        return World.caskSprite(caskModData)
    end

    -- The floor's heaps come done while its area is unloaded too; the XP goes once for those done since the last look,
    -- as it went once a run.
    if sessionState.base == V.FLOOR_SPRITE then
        local record, _, _, finished = V.floorNow(station)
        if finished > 0 then award(Perks.Farming, V.MALTING_XP) end
        return World.floorSprite(record)
    end

    local record, _, _, finished = V.vesselNow(station)
    if finished then
        award(Perks.Cooking, V.FERMENT_XP)
        log("TPV", "vessel batch finished: %.2f L of fermented wort", record.fermentedMl / 1000)
    end
    return World.vesselSprite(record.wortMl, record.run and V.runProgress(record.run), record.fermentedMl)
end

-- Keeps a hose's link, and ends it if the station at the other end has gone. Pumping is by hand, from
-- either station's menu. True while a hose is on this station.
local function tendHose(station)
    if not V.hoseLink(station) then return false end
    local partner, loaded = V.hosePartner(station)
    if not partner then
        if not loaded then return true end
        station:getModData().vinegarHose = nil
        station:getSquare():AddWorldInventoryItem(V.HOSE_ITEM, 0.5, 0.5, 0)
        log("TPV", "hose dropped: the station at its other end is gone")
        return false
    end
    World.track(partner)
    return true
end

local HOSE_SPRITES = { [V.VESSEL_SPRITE] = V.VESSEL_HOSE, [V.CASK_SPRITE] = V.CASK_HOSE }

local function refresh(station, sessionState)
    local sprite = stationSprite(station, sessionState)
    local hosed = HOSE_SPRITES[sessionState.base] ~= nil and tendHose(station)
    sessionState.sprite = sprite
    local names = {}
    if sprite then table.insert(names, V.spriteName(sprite + sessionState.faceIndex)) end
    if hosed then table.insert(names, V.spriteName(HOSE_SPRITES[sessionState.base] + sessionState.faceIndex)) end
    Station.showSprites(station, sessionState, tostring(sprite) .. ":" .. tostring(hosed), names)
end

-- Only this mod's stations: the base sprite and which way it faces.
local function newSessionState(station)
    local kind, face = V.stationKind(station)
    if not kind then return nil end
    return { base = V.STATION_SPRITES[kind], faceIndex = face }
end

local tracker = Station.tracker({ sprites = Tiles.STATIONS, newSessionState = newSessionState, refresh = refresh })

World.track = tracker.track

-- Redraws a tracked station now, without waiting for the next tick, e.g. after a pour.
function World.refresh(station)
    local sessionState = tracker.sessionStateOf(station)
    if sessionState then refresh(station, sessionState) end
end

Weather.onReading(function(now, climate)
    V.advance(V.getLedger(), now, climate:getTemperature())
end)

tracker.start()
