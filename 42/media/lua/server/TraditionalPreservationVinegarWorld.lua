-- Traditional Preservation (Vinegar): keeps the weather totals, sours each cask's pool, takes a hot
-- vessel's losses, and shows what each station is doing. SpriteOverlayConfig can't show a station
-- waiting to start or a mother at rest, so this reads each station and layers sprites itself.
if isClient() then return end

TraditionalPreservationVinegarWorld = TraditionalPreservationVinegarWorld or {}
local V = TraditionalPreservationVinegar
local World = TraditionalPreservationVinegarWorld

local TICKS_PER_REFRESH = 30
local MAP_PRIORITY = 5
-- Bubbling gives way to settling lees for the last part of a run.
local SEDIMENT_FROM = 0.7
local ROOTLETS_FROM = 0.5

local tracked = {}
local ticksSinceRefresh = 0

local function countItems(resources, group, io)
    local count = 0
    local items = resources:getResourcesFromGroup(group, ArrayList.new(), io, ResourceType.Item)
    for i = 0, items:size() - 1 do
        count = count + items:get(i):storedSize()
    end
    return count
end

local litres = V.litres

-- Each tank takes only its own liquid, whatever vanilla's transfer window offers.
local function restrictTank(tank, name)
    local fluid = tank and Fluid.Get(name)
    if not fluid then return end
    local filter = FluidFilter.new()
    filter:setFilterType(FluidFilter.FilterType.Whitelist)
    filter:add(fluid)
    tank:getFluidContainer():setWhitelist(filter)
end

-- A progress of 0 to 1, or nil with nothing running. Tells the run where it stands.
local function readRun(station, logic, entry, place)
    if not entry.uiLogic or entry.uiLogic:getCraftLogic() ~= logic then
        local player = getPlayer()
        if not player then return nil end
        entry.uiLogic = CraftLogicUILogic.new(player, station, logic)
    end
    local craftData = V.runningBatch(station, logic, entry.uiLogic)
    if not craftData then return nil end
    craftData:getModData().place = place
    return logic:getProgress(craftData), craftData
end

-- Rootlets show from halfway through a run.
function World.floorSprite(waiting, progress, finished)
    if progress then
        return progress >= ROOTLETS_FROM and V.FLOOR_ROOTLETS or V.FLOOR_SPROUTING
    end
    if finished > 0 then return V.FLOOR_FINISHED end
    if waiting > 0 then return V.FLOOR_STEEPED end
    return nil
end

function World.vesselSprite(waiting, progress, finished)
    if progress then
        return progress >= SEDIMENT_FROM and V.VESSEL_SEDIMENT or V.VESSEL_BUBBLING
    end
    if finished > 0 then return V.VESSEL_FINISHED end
    if waiting > 0 then return V.VESSEL_FILLED end
    return nil
end

-- Fresh wort shows bare, the skin thickens as the pool sours, and a mother is a whole skin at once.
function World.caskSprite(state)
    if state.ml <= 0 then
        return state.mother and V.CASK_MOTHER or nil
    end
    if state.strength >= 1 then return V.CASK_FINISHED end
    if state.mother then return V.CASK_FILM[#V.CASK_FILM] end
    if state.strength <= 0 then return V.CASK_FILLED end
    return V.CASK_FILM[math.min(math.floor(state.strength * #V.CASK_FILM) + 1, #V.CASK_FILM)]
end

-- Singleplayer: the station's work goes to the player.
local function award(perk, amount)
    local player = getPlayer()
    if player then player:getXp():AddXP(perk, amount) end
end

local MARKER = "TraditionalPreservationVinegar.FermentedBatch"

-- Takes the finished-run marker out of the vessel's output slot. True if there was one.
local function takeMarker(resources, logic)
    local found = false
    local slots = resources:getResourcesFromGroup(logic:getOutputsGroupName(), ArrayList.new(), ResourceIO.Output, ResourceType.Item)
    for i = 0, slots:size() - 1 do
        local slot = slots:get(i)
        local stored = slot:getStoredItems()
        for j = stored:size() - 1, 0, -1 do
            if stored:get(j):getFullType() == MARKER then
                slot:removeItem(stored:get(j))
                found = true
            end
        end
    end
    return found
end

-- The engine can't hold a liquid recipe to its amounts, so the vessel's wort is handled here. A run
-- that has just started takes its wort, a finished one gives back fermented wort, and a cancelled one
-- pours its wort back, as the engine gives back the yeast. The run is kept on the vessel, so this
-- works however long it was away.
local function settleRun(vessel, resources, logic, craftData, input, output)
    local modData = vessel:getModData()
    local run = modData.vinegarRun
    if craftData then
        if not run then
            local ml = V.batchMl(litres(input) * 1000)
            input:getFluidContainer():removeFluid(ml / 1000)
            run = { ml = ml, heat = 0 }
            modData.vinegarRun = run
            print(string.format("[TPV] vessel run took %.1f L of wort", ml / 1000))
        end
        run.heat = craftData:getModData().heat or 0
        return
    end
    if takeMarker(resources, logic) then
        local ml = run and V.fermentedMl(run.ml, run.heat) or 0
        if ml > 0 then output:getFluidContainer():addFluid(V.FERMENTED, ml / 1000) end
        award(Perks.Cooking, V.FERMENT_XP)
        print(string.format("[TPV] vessel run finished with %.2f L of fermented wort", ml / 1000))
        modData.vinegarRun = nil
    elseif run and not logic:isRunning() then
        input:getFluidContainer():addFluid(V.WORT, run.ml / 1000)
        print(string.format("[TPV] vessel run cancelled, %.1f L of wort back in the tank", run.ml / 1000))
        modData.vinegarRun = nil
    end
end

local function stationSprite(station, entry)
    if entry.base == V.CASK_SPRITE then
        local state = V.caskState(station)
        local before = state.strength
        V.updateCask(state, V.getLedger(), V.placeOf(station))
        if before < 1 and state.strength >= 1 then
            print(string.format("[TPV] cask fully soured: %.2f L, mother layers %d", state.ml / 1000, V.motherLayers(state)))
        end
        return World.caskSprite(state)
    end

    local resources = station:getComponent(ComponentType.Resources)
    local logic = station:getComponent(ComponentType.CraftLogic)
    if not resources or not logic then return entry.sprite end
    local progress, craftData = readRun(station, logic, entry, V.placeOf(station))

    if entry.base == V.FLOOR_SPRITE then
        local waiting = countItems(resources, logic:getInputsGroupName(), ResourceIO.Input)
        local finished = countItems(resources, logic:getOutputsGroupName(), ResourceIO.Output)
        -- A run that ended with more malt to collect than it started with finished; a cancelled one didn't.
        local running = logic:isRunning()
        if running and not entry.malting then entry.maltBefore = finished end
        if entry.malting and not running and finished > (entry.maltBefore or 0) then award(Perks.Farming, V.MALTING_XP) end
        entry.malting = running
        return World.floorSprite(waiting, progress, finished)
    end

    local input, output = V.vesselTank(station, ResourceIO.Input), V.vesselTank(station, ResourceIO.Output)
    if not entry.restricted then
        restrictTank(input, V.WORT)
        restrictTank(output, V.FERMENTED)
        entry.restricted = true
    end
    settleRun(station, resources, logic, craftData, input, output)
    return World.vesselSprite(litres(input), progress, litres(output))
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
        print("[TPV] hose dropped: the station at its other end is gone")
        return false
    end
    World.track(partner)
    return true
end

local HOSE_SPRITES = { [V.VESSEL_SPRITE] = V.VESSEL_HOSE, [V.CASK_SPRITE] = V.CASK_HOSE }

function World.refresh(station)
    local entry = tracked[station]
    if not entry then return end
    local sprite = stationSprite(station, entry)
    local hosed = HOSE_SPRITES[entry.base] ~= nil and tendHose(station)
    if sprite == entry.sprite and hosed == entry.hosed then return end
    entry.sprite, entry.hosed = sprite, hosed
    station:clearAttachedAnimSprite()
    if sprite then station:addAttachedAnimSpriteByName(V.spriteName(sprite + entry.faceIndex)) end
    if hosed then station:addAttachedAnimSpriteByName(V.spriteName(HOSE_SPRITES[entry.base] + entry.faceIndex)) end
end

function World.track(station)
    if tracked[station] then return end
    local sprite = station:getSprite()
    local index = sprite and V.spriteIndex(sprite:getName())
    if not index then return end
    tracked[station] = { base = index - index % V.FACE_COUNT, faceIndex = index % V.FACE_COUNT }
end

local function onTick()
    ticksSinceRefresh = ticksSinceRefresh + 1
    if ticksSinceRefresh < TICKS_PER_REFRESH then return end
    ticksSinceRefresh = 0

    for station in pairs(tracked) do
        if station:getSquare() and station:getObjectIndex() >= 0 then
            World.refresh(station)
        else
            tracked[station] = nil
        end
    end
end

local function recordWeather()
    V.advance(V.getLedger(), getGameTime():getWorldAgeHours(), getClimateManager():getTemperature())
end

Events.OnTick.Add(onTick)
Events.EveryTenMinutes.Add(recordWeather)

for _, base in ipairs({ V.VESSEL_SPRITE, V.CASK_SPRITE, V.FLOOR_SPRITE }) do
    for faceIndex = 0, V.FACE_COUNT - 1 do
        MapObjects.OnLoadWithSprite(V.spriteName(base + faceIndex), World.track, MAP_PRIORITY)
    end
end
