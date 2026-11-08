-- Checks the mod's scripts against the game's. Run from the mod folder: luajit tests/test_scripts.lua [game folder]
-- Needs the game files for the vanilla checks, and skips them with a note if they aren't there.
local GAME = arg[1] or (os.getenv("HOME") .. "/.local/share/Steam/steamapps/common/ProjectZomboid/projectzomboid")
local GENERATED = GAME .. "/media/scripts/generated"
local MOD = "42/media/scripts"
local GRAINS = { "Base.BarleySeed", "Base.WheatSeed", "Base.RyeSeed" }

local function check(name, condition)
    print((condition and "ok   " or "FAIL ") .. name)
    if not condition then os.exit(1) end
end

local function read(path)
    local file = io.open(path, "r")
    if not file then return nil end
    local text = file:read("*a")
    file:close()
    return text
end

local function listFiles(folder)
    local files = {}
    local pipe = io.popen('find "' .. folder .. '" -name "*.txt" 2>/dev/null')
    for path in pipe:lines() do table.insert(files, path) end
    pipe:close()
    return files
end

-- The body of a block such as "craftRecipe SteepGrain", up to its matching brace.
local function block(text, header)
    local start = text:find(header .. "%s*\n%s*{")
    if not start then return nil end
    local open = text:find("{", start, true)
    local depth = 0
    for i = open, #text do
        local c = text:sub(i, i)
        if c == "{" then depth = depth + 1 elseif c == "}" then depth = depth - 1 end
        if depth == 0 then return text:sub(open, i) end
    end
end

-- Every "item Name" defined in a set of script files, as Module.Name.
local function definedItems(files)
    local items = {}
    for _, path in ipairs(files) do
        local text = read(path)
        local module
        for line in text:gmatch("[^\n]+") do
            module = line:match("^%s*module%s+([%w_]+)") or module
            local name = line:match("^%s*item%s+([%w_]+)%s*$")
            if name and module then items[module .. "." .. name] = true end
        end
    end
    return items
end

local modText = ""
local modFiles = listFiles(MOD)
for _, path in ipairs(modFiles) do modText = modText .. read(path) .. "\n" end
local steep = block(modText, "craftRecipe SteepGrain")
check("the mod has a Steep Grain recipe", steep ~= nil)

-- Steep Grain takes any of the three grains, 24 of them, counted together.
local count, list = steep:match("item%s+(%d+)%s+%[([^%]]*)%]")
check("Steep Grain takes 24 grain", tonumber(count) == 24)
for _, grain in ipairs(GRAINS) do
    check("and accepts " .. grain, list:find(grain, 1, true) ~= nil)
end
check("counted together, so a mix of grains works", steep:find("flags%[ItemCount%]") ~= nil)
check("with 4 L of water from a kept container", steep:find("%-fluid 4%.0 %[Water%]") ~= nil and steep:find("item 1 %[%*%]") ~= nil)

local vanillaFiles = listFiles(GENERATED)
if #vanillaFiles == 0 then
    print("skip vanilla checks: no game files at " .. GAME)
    print("all passed")
    return
end
local vanillaText = ""
for _, path in ipairs(vanillaFiles) do vanillaText = vanillaText .. read(path) .. "\n" end

-- Each grain exists, and is the same kind of item, so none behaves differently in the recipe.
local function seedProps(grain)
    local name = grain:match("Base%.(.+)")
    local body = block(vanillaText, "item " .. name)
    if not body then return nil end
    return { weight = body:match("Weight%s*=%s*([%d%.]+)"), feed = body:match("AnimalFeedType%s*=%s*([%w_]+)"), type = body:match("ItemType%s*=%s*([%w_:]+)") }
end
local barley = seedProps("Base.BarleySeed")
for _, grain in ipairs(GRAINS) do
    local props = seedProps(grain)
    check(grain .. " exists in vanilla", props ~= nil)
    check(grain .. " is the same kind of item as barley", props.weight == barley.weight and props.type == barley.type and props.feed == barley.feed)
end

-- Vanilla threshing gives exactly these grains, so every grain crop a player grows can be steeped.
local thresh = block(vanillaText, "craftRecipe ThreshGrain")
check("vanilla has a threshing recipe", thresh ~= nil)
for _, grain in ipairs(GRAINS) do
    check("threshing gives " .. grain, thresh:find(grain .. " = ", 1, true) ~= nil)
end

-- Green Malt spoils, so it must be kilned soon, and a rotten one can be composted.
local greenMalt = block(modText, "item GreenMalt")
check("Green Malt goes stale and then rots", greenMalt:find("DaysFresh = 2,", 1, true) ~= nil and greenMalt:find("DaysTotallyRotten = 5,", 1, true) ~= nil)
check("rotten Green Malt is compostable", greenMalt:find("base:iscompostable", 1, true) ~= nil)
check("Green Malt still kilns into Malt", greenMalt:find("ReplaceOnCooked = TraditionalPreservationVinegar.Malt,", 1, true) ~= nil)

-- Every item our recipes and stations name exists in vanilla or in the mod.
local known = definedItems(vanillaFiles)
for name in pairs(definedItems(modFiles)) do known[name] = true end
local missing = {}
for list in modText:gmatch("item%s+%d+%s+%[([^%]]+)%]") do
    for name in list:gmatch("[^;%s]+") do
        local fullName = name:match("^%d+:(.+)") or name
        if fullName ~= "*" and not known[fullName] then table.insert(missing, fullName) end
    end
end
for name in modText:gmatch("item%s+%d+%s+([%w_]+%.[%w_]+)%s*,") do
    if not known[name] then table.insert(missing, name) end
end
check("every item the recipes name exists (" .. table.concat(missing, ", ") .. ")", #missing == 0)

print("all passed")
