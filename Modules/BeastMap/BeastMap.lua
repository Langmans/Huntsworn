local _, ns = ...

-- A HandyNotes plugin ("Huntsworn"): a pin on the world map and the minimap for every beast that can
-- teach the hunter a pet ability rank, with the icon of the best rank it has to offer. The beasts
-- and their pins come from Data\Beasts.lua; what the hunter knows from AbilityLearned (the ranks it
-- learned, and the highest per ability). On another class than a hunter the module does nothing.
--
-- A beast gets a pin when the hunter can tame it now (its lowest level at most the hunter's) and
-- it teaches a rank the hunter lacks: above the highest it knows, or, when asked, a lower one it
-- never learned. Settings turn both checks off.
--
-- A beast in an instance has no map of its own: its instance gets one pin at the dungeon entrance
-- the client lists for a map (C_EncounterJournal), standing for every beast inside.
--
-- At a level-up, also without HandyNotes, a toast names the ranks the hunter lacks that a beast of
-- just that level brings in reach, where no lower beast taught them already.

---@type Addon
local Addon = ns
local L = Addon.L

---@type AddonBeastMap
local M = Addon:NewModule("BeastMap")
M.title = L.BEASTMAP_TITLE
M.description = L.BEASTMAP_DESC
M.requires = { "beastTraining", "beastData" }
M.toastTypes = { reach = L.BEASTMAP_TOASTTYPE_REACH, rare = L.BEASTMAP_TOASTTYPE_RARE }
M.defaults = {
    profile = {
        pins = true,
        mapButton = true,
        usefulOnly = true,
        gaps = false,
        aboveLevel = false,
        untilTame = true,
        levelToast = true,
        levelChat = false,
        tooltip = true,
        spellTooltip = true,
        rareToast = true,
        trainers = true,
        stables = true,
        tameButton = true,
        huntEndsAtTame = true,
        familyGroup = "family",
        familyRares = false,
        familySpecNames = false,
        beasts = {
            search = "",
            ability = "all",
            family = "all",
            diet = "all",
            zone = "all",
            you = "all",
            sort = "level",
            descending = false,
            reach = false,
            rares = false,
        },
    },
}

local PLUGIN = Addon.NAME
-- The route library (Libs\LibGoThere-1.0): sends the hunter to a beast.
local GoThere = LibStub("LibGoThere-1.0") --[[@as LibGoThere]]
local LACKING, KNOWN = { 0, 1, 0 }, { 0.5, 0.5, 0.5 }
-- Per kind of trainer (Data\Trainers.lua): its setting, its pin's icon (Beast Training, Call
-- Pet) and the line under its name.
---@type table<string, {setting: string, icon: number, label: string}>
local TRAINER_KINDS = {
    trainer = { setting = "trainers", icon = 132162, label = L.BEASTMAP_PET_TRAINER },
    stable = { setting = "stables", icon = 132161, label = L.BEASTMAP_STABLE_MASTER },
}

---@return AddonBeastMapSettings
function M:Settings()
    return self.db.profile --[[@as AddonBeastMapSettings]]
end

-- Built on first use from the data: per map, its pins as npc, coord pairs (pins.at: coord ->
-- position, for the iterator); per beast, the ranks it teaches by ability and rank.
---@type table<number, AddonBeastMapPins>?
local byMap
---@type table<number, number[]>?
local teaches
-- Per instance (AreaTable ID), the beasts in it, by NPC ID; filled with byMap. The maps whose
-- dungeon entrances were looked up.
---@type table<number, number[]>
local inInstance = {}
---@type table<number, true>
local entrancesRead = {}
-- The pin's icon per beast, or false for none; emptied when anything it depends on changes.
---@type table<number, number|string|false>
local shown = {}
-- The rank a beast's pin shows (its icon's), filled with shown.
---@type table<number, number>
local pinSpell = {}
---@type AddonBeastMapPins
local NO_PINS = { at = {} } --[[@as AddonBeastMapPins]]

---The beast data (Data\Beasts.lua), read when used: the specs put a small set in its place.
---@return AddonData
local function Data()
    return Addon.data
end

---Two rank spells in order: by ability, then rank.
---@param a number
---@param b number
---@return boolean
local function Before(a, b)
    local ranks = Data().petAbilityRanks
    if ranks[a].ability ~= ranks[b].ability then return ranks[a].ability < ranks[b].ability end
    return ranks[a].rank < ranks[b].rank
end

---Per beast, the rank spells it teaches in order; built once.
---@return table<number, number[]>
local function Teaches()
    if teaches then return teaches end
    ---@type table<number, number[]>
    local list = {}
    teaches = list
    for spellID, rank in pairs(Data().petAbilityRanks) do
        for _, npc in ipairs(rank.teachers) do
            list[npc] = list[npc] or {}
            table.insert(list[npc], spellID)
        end
    end
    for _, spells in pairs(list) do
        table.sort(spells, Before)
    end
    return list
end

---Adds a pin to a map's pins, unless the spot has one: a second there would make the iterator skip.
---@param maps table<number, AddonBeastMapPins>
---@param map number uiMapID
---@param id number a beast's NPC ID, or minus an instance's AreaTable ID
---@param coord number
local function AddPin(maps, map, id, coord)
    local pins = maps[map] or { at = {} } --[[@as AddonBeastMapPins]]
    maps[map] = pins
    if pins.at[coord] then return end
    pins[#pins + 1] = id
    pins[#pins + 1] = coord
    pins.at[coord] = #pins - 1
end

---Per map, its pins; built once. A beast in an instance waits in `inInstance` for its entrance.
---@param handyNotes HandyNotesApi
---@return table<number, AddonBeastMapPins>
local function Pins(handyNotes)
    if byMap then return byMap end
    ---@type table<number, AddonBeastMapPins>
    local maps = {}
    byMap = maps
    local beasts = Data().beasts
    ---@type number[]
    local npcs = {}
    for npc in pairs(beasts) do
        npcs[#npcs + 1] = npc
    end
    table.sort(npcs)
    for _, npc in ipairs(npcs) do
        for map, flat in pairs(beasts[npc].pins or {}) do
            for i = 1, #flat, 2 do
                AddPin(maps, map, npc, handyNotes:getCoord(flat[i] / 100, flat[i + 1] / 100))
            end
        end
        for _, area in ipairs(beasts[npc].zones or {}) do
            inInstance[area] = inInstance[area] or {}
            table.insert(inInstance[area], npc)
        end
    end
    -- Pet trainers and stable masters (Data\Trainers.lua), after the beasts; NPC IDs of their own.
    local trainers = Data().trainers or {}
    wipe(npcs)
    for npc in pairs(trainers) do
        npcs[#npcs + 1] = npc
    end
    table.sort(npcs)
    for _, npc in ipairs(npcs) do
        for map, flat in pairs(trainers[npc].pins) do
            for i = 1, #flat, 2 do
                AddPin(maps, map, npc, handyNotes:getCoord(flat[i] / 100, flat[i + 1] / 100))
            end
        end
    end
    return maps
end

-- Instance areas whose entrance carries another name altogether, by AreaTable ID: the area's
-- English name stands in for the client's (an alias matches in English clients only).
local ENTRANCE_NAMES = {
    [1417] = "Temple of Atal'Hakkar", -- Sunken Temple
}

---A name to compare entrances by: lower case, without a leading "The ".
---@param name string
---@return string
local function Plain(name)
    return (name:lower():gsub("^the ", ""))
end

---Whether an entrance leads into an instance area: the same name, or one in the other ("Upper
---Blackrock Spire" for Blackrock Spire, a wing of Scarlet Monastery), or the area's alias.
---@param entrance string
---@param area number
---@return boolean
local function LeadsInto(entrance, area)
    local name = C_Map.GetAreaInfo(area)
    if not name or name == "" then return false end
    local door, inside = Plain(entrance), Plain(ENTRANCE_NAMES[area] or name)
    return door:find(inside, 1, true) ~= nil or inside:find(door, 1, true) ~= nil
end

---Adds a pin at each dungeon entrance on a map whose instance has beasts, the first time the map
---is asked for. Entrances are matched to the instance's area by name (LeadsInto).
---@param handyNotes HandyNotesApi
---@param uiMapID number
local function AddEntrances(handyNotes, uiMapID)
    local maps = Pins(handyNotes)
    if entrancesRead[uiMapID] or not C_EncounterJournal then return end
    entrancesRead[uiMapID] = true
    for _, entrance in ipairs(C_EncounterJournal.GetDungeonEntrancesForMap(uiMapID)) do
        for area in pairs(inInstance) do
            if LeadsInto(entrance.name, area) then
                AddPin(maps, uiMapID, -area, handyNotes:getCoord(entrance.position:GetXY()))
            end
        end
    end
end

---Whether the hunter lacks a rank: above the highest it knows of the ability ("above"), below it
---but never learned ("gap"), or not at all (nil). Without AbilityLearned's data, or a name for the
---ability, every rank counts as lacking.
---@param spellID number
---@return "above"|"gap"|nil
local function Lacking(spellID)
    local rank = Data().petAbilityRanks[spellID]
    local name = Addon.SpellInfo(rank.ability)
    local known = Addon:GetModule("AbilityLearned", true) --[[@as AddonAbilityLearned?]]
    if not name or not known then return "above" end
    if rank.rank > (known:HighestRank(name) or 0) then return "above" end
    if not known:HasRank(name, rank.rank) then return "gap" end
    return nil
end

---A trainer's or stable master's entry, or nil for a beast.
---@param npc number
---@return AddonTrainer?
local function Trainer(npc)
    local trainers = Data().trainers
    return trainers and trainers[npc]
end

---The hunter's level; PLAYER_LEVEL_UP gives the new one before UnitLevel does.
---@return number
function M:PlayerLevel()
    return self.level or UnitLevel("player")
end

---The icon of the pin for a beast, or false for no pin. An instance's pin (a negative ID) has the
---icon of the first beast in it that gets one.
---@param npc number
---@return number|string|false
local function Icon(npc)
    if npc < 0 then
        for _, inside in ipairs(inInstance[-npc]) do
            local icon = Icon(inside)
            if icon then return icon end
        end
        return false
    end
    local cached = shown[npc]
    if cached ~= nil then return cached end
    local settings = M:Settings()
    local trainer = Trainer(npc)
    -- A trainer: its kind's pin, when that kind is switched on and it serves the hunter's faction.
    if trainer then
        local kind = TRAINER_KINDS[trainer.kind]
        local forUs = not trainer.side or trainer.side == UnitFactionGroup("player")
        shown[npc] = settings[kind.setting] and forUs and kind.icon or false
        return shown[npc]
    end
    -- Nothing to learn from a beast before the hunter can tame one.
    if settings.usefulOnly and settings.untilTame and not M.canTame then
        shown[npc] = false
        return false
    end
    local beast = Data().beasts[npc]
    ---@type number?
    local best, wanted
    if settings.aboveLevel or beast.minLevel <= M:PlayerLevel() then
        for _, spellID in ipairs(Teaches()[npc]) do
            local lacking = Lacking(spellID)
            if lacking == "above" or (lacking == "gap" and settings.gaps) then wanted = spellID end
            best = spellID
        end
    end
    local pick = wanted or (not settings.usefulOnly and best)
    if not pick then
        shown[npc] = false
        return false
    end
    local _, icon = Addon.SpellInfo(pick)
    pinSpell[npc] = pick
    shown[npc] = icon or 134400 -- the question mark icon
    return shown[npc]
end

---The rank beast `npc`'s pin shows, nil for a beast without a pin.
---@param npc number
---@return number?
function M.PinSpell(npc)
    if not Icon(npc) then return nil end
    return pinSpell[npc]
end

---HandyNotes' iterator over a map's pins: the coord of the last pin returned leads to the next.
---@param pins AddonBeastMapPins
---@param coord number?
---@return number? coord
---@return nil uiMapID the map asked for
---@return (number|string)? icon
local function NextPin(pins, coord)
    local i = coord and pins.at[coord] + 2 or 1
    while pins[i] do
        local icon = Icon(pins[i])
        ---@type number
        local at = pins[i + 1]
        if icon then return at, nil, icon end
        i = i + 2
    end
    return nil
end

-- The handler HandyNotes calls. OnEnter and OnLeave get the pin as self.
local handler = {}

---@param uiMapID number
---@return function, AddonBeastMapPins, nil
function handler:GetNodes2(uiMapID)
    -- HandyNotes is loaded: it is the one asking.
    if not M:IsEnabled() or not M:Settings().pins then return NextPin, NO_PINS, nil end
    local handyNotes = HandyNotes --[[@as HandyNotesApi]]
    AddEntrances(handyNotes, uiMapID)
    return NextPin, Pins(handyNotes)[uiMapID] or NO_PINS, nil
end

---"Level 5-6", "Level 10, rare elite", "Level 37, rare, attack speed 1.0".
---@param beast AddonBeast
---@return string
local function LevelText(beast)
    local level = beast.minLevel == beast.maxLevel and tostring(beast.minLevel)
        or beast.minLevel .. "-" .. beast.maxLevel
    local kind = beast.rare and beast.elite and L.BEASTMAP_RARE_ELITE
        or beast.rare and L.BEASTMAP_RARE
        or beast.elite and L.BEASTMAP_ELITE
        or ""
    -- Classic Era and WoW: Forever: a tamed beast keeps its attack speed, worth knowing where it is
    -- not the usual 2.0. Burning Crusade's data has none: every pet attacks at 2.0 there.
    local speed = beast.speed and beast.speed ~= 2 and L.BEASTMAP_SPEED:format(beast.speed) or ""
    return L.BEASTMAP_LEVEL:format(level) .. kind .. speed
end

---A beast's name as the client words it, else as the data has it (English).
---@param npc number
---@return string
local function BeastName(npc)
    return Addon.CreatureName(npc) or Data().beasts[npc].name
end

---"Claw (Rank 2)" as the client names it; nil when it cannot name the spell.
---@param spellID number
---@return string?
local function RankText(spellID)
    local name, _, rank = Addon.SpellInfo(spellID)
    -- A spell the client has not cached yet has no subtext: the rank number from the data then.
    local data = Addon.data.petAbilityRanks[spellID] --[[@as AddonPetAbilityRank?]]
    if not rank and data and RANK then rank = ("%s %d"):format(RANK, data.rank) end
    return name and rank and ("%s (%s)"):format(name, rank) or name
end

-- For the unit tooltip (Tooltip.lua) and the rare alarm (Rare.lua): what a beast teaches, how the
-- hunter stands to a rank, a beast's name and level.
M.RankText, M.Lacking, M.LevelText, M.BeastName = RankText, Lacking, LevelText, BeastName

---The rank spells a beast teaches, in order; nil for a beast that teaches none.
---@param npc number
---@return number[]?
function M.TeachesOf(npc)
    return Teaches()[npc]
end

---A pin's name: the beast's or trainer's (as the client words it once it knows the NPC), or the
---instance's for a dungeon entrance (a negative ID).
---@param id number
---@return string
local function PinName(id)
    if id < 0 then
        return C_Map.GetAreaInfo(-id) --[[@as string]]
    end
    local trainer = Trainer(id)
    if trainer then return Addon.CreatureName(id) or trainer.name end
    return BeastName(id)
end

---Every rank a beast teaches, in the tooltip; green for one the hunter lacks.
---@param npc number
local function AddRanks(npc)
    for _, spellID in ipairs(Teaches()[npc]) do
        local text = RankText(spellID)
        if text then
            local color = Lacking(spellID) and LACKING or KNOWN
            GameTooltip:AddLine(text, color[1], color[2], color[3])
        end
    end
end

---The tooltip: the beast's name, level and ranks; at a dungeon entrance, the instance's name and
---so for each beast inside that gets a pin.
---@param pin Frame
---@param uiMapID number
---@param coord number
function handler.OnEnter(pin, uiMapID, coord)
    local pins = byMap and byMap[uiMapID]
    local at = pins and pins.at[coord]
    if not at then return end
    ---@type number
    local id = pins[at]
    GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
    GameTooltip:SetText(PinName(id))
    if id < 0 then
        for _, npc in ipairs(inInstance[-id]) do
            if Icon(npc) then
                GameTooltip:AddLine(L.BEASTMAP_INSIDE:format(BeastName(npc), LevelText(Data().beasts[npc])), 1, 1, 1)
                AddRanks(npc)
            end
        end
    elseif Trainer(id) then
        GameTooltip:AddLine(
            TRAINER_KINDS[
                (Trainer(id) --[[@as AddonTrainer]]).kind
            ].label,
            1,
            1,
            1
        )
    else
        GameTooltip:AddLine(LevelText(Data().beasts[id]), 1, 1, 1)
        AddRanks(id)
    end
    GameTooltip:AddLine(L.BEASTMAP_CLICK, KNOWN[1], KNOWN[2], KNOWN[3])
    GameTooltip:Show()
end

function handler.OnLeave()
    GameTooltip:Hide()
end

---A left click (as the button comes up) sends the hunter to the pin, through LibGoThere-1.0: a
---route, an arrow or the game's waypoint, whichever addon the player has, else a pin link. On a
---beast's pin it starts the hunt for the rank the pin shows (Hunt.lua), which goes there too.
---@param _ Frame the pin
---@param button string
---@param down boolean
---@param uiMapID number
---@param coord number
function handler.OnClick(_, button, down, uiMapID, coord)
    local pins = byMap and byMap[uiMapID]
    local at = pins and pins.at[coord]
    if button ~= "LeftButton" or down or not at then return end
    ---@type number
    local id = pins[at]
    local x, y = (HandyNotes --[[@as HandyNotesApi]]):getXY(coord)
    local spellID = id > 0 and not Trainer(id) and M.PinSpell(id)
    if spellID then
        M:StartHunt(id, spellID, uiMapID, x, y)
    else
        GoThere:Navigate(Addon.NAME, uiMapID, x, y, PinName(id))
    end
end

---Forgets the pins' icons and has HandyNotes draw them again; shows or hides the map button;
---fills the window's tabs again.
function M:Refresh()
    wipe(shown)
    wipe(pinSpell)
    self:UpdateMapButton()
    Addon:RefreshWindow("abilities")
    Addon:RefreshWindow("beasts")
    if not HandyNotes then return end
    HandyNotes:UpdateWorldMapPlugin(PLUGIN)
    HandyNotes:UpdateMinimapPlugin(PLUGIN)
end

---A beast's first map by uiMapID; nil for a beast in an instance, which has only zones.
---@param beast AddonBeast
---@return number?
local function FirstMap(beast)
    ---@type number?
    local first
    for map in pairs(beast.pins or {}) do
        if not first or map < first then first = map end
    end
    return first
end

-- Where each beast's pins lie in the world, worked out once per beast (and again when its pins
-- change): flattened continent, x, y (Huntsworn.InWorld) per pin, in the order of `pinsOf`'s map, x,
-- y; false for a pin the client cannot place.
---@type table<number, (number|false)[]>, table<number, number[]>, table<number, table>
local worldOf, pinsOf, pinsFrom = {}, {}, {}
-- What an instance beast's pins count as.
local NO_SPOTS = {}

---A beast's pins and where they lie in the world, flattened (map, x, y and continent, x, y each).
---@param npc number
---@return number[] pins
---@return (number|false)[] world
local function Spots(npc)
    local from = Data().beasts[npc].pins or NO_SPOTS
    if pinsFrom[npc] ~= from then
        pinsFrom[npc] = from
        ---@type number[], (number|false)[]
        local pins, world = {}, {}
        for map, flat in pairs(from) do
            for i = 1, #flat, 2 do
                local x, y = flat[i] / 100, flat[i + 1] / 100
                pins[#pins + 1], pins[#pins + 2], pins[#pins + 3] = map, x, y
                local continent, wx, wy = Addon.InWorld(map, x, y)
                world[#world + 1], world[#world + 2], world[#world + 3] = continent or false, wx, wy
            end
        end
        pinsOf[npc], worldOf[npc] = pins, world
    end
    return pinsOf[npc], worldOf[npc]
end

---A beast's pin nearest the player in a straight line, across zone borders: its map, x, y and the
---yards to it; the first pin by map with a huge distance when the player or the pins cannot be
---placed on one continent; nil for a beast in an instance.
---@param npc number
---@return number? map
---@return number x
---@return number y
---@return number yards
local function NearestPin(npc)
    local pins, world = Spots(npc)
    local continent, px, py = Addon.PlayerInWorld()
    ---@type integer?, number
    local best, bestYards = nil, math.huge
    for i = 1, #world, 3 do
        if continent and world[i] == continent then
            local yards = math.sqrt((world[i + 1] - px) ^ 2 + (world[i + 2] - py) ^ 2)
            if yards < bestYards then
                best, bestYards = i, yards
            end
        end
    end
    if best then return pins[best], pins[best + 1], pins[best + 2], bestYards end
    local map = FirstMap(Data().beasts[npc])
    if not map then return nil, 0, 0, math.huge end
    local pin = (Data().beasts[npc].pins --[[@as table<number, number[]> ]])[map]
    return map, pin[1] / 100, pin[2] / 100, math.huge
end

---Yards in a straight line to a beast's nearest pin; huge when the player and the beast cannot be
---placed on one continent, or it lives in an instance.
---@param npc number
---@return number
function M.YardsTo(npc)
    local _, _, _, yards = NearestPin(npc)
    return yards
end

---Seconds to a beast's nearest pin, as the player's route addon works it out (LibGoThere); a huge
---number when there is none to ask, or no route.
---@param npc number
---@return number
local function AskTravelTime(npc)
    local map, x, y = NearestPin(npc)
    if not map then return math.huge end
    return GoThere:TravelTime(map, x, y) or math.huge
end

-- Travel times by beast, kept TRAVEL_KEEP seconds: a route addon's answer takes time, and sorting
-- a rank's teachers asks for the same beasts again and again.
local TRAVEL_KEEP = 30
---@type table<number, number>
local travel = {}
local travelSince = 0

---Seconds to a beast, kept for a while (AskTravelTime).
---@param npc number
---@return number
local function TravelSeconds(npc)
    local now = GetTime()
    if now - travelSince > TRAVEL_KEEP then
        wipe(travel)
        travelSince = now
    end
    local seconds = travel[npc]
    if not seconds then
        seconds = AskTravelTime(npc)
        travel[npc] = seconds
    end
    return seconds
end

-- The yards to each beast being sorted, filled before each sort (M.Nearest).
---@type table<number, number>
local yardsTo = {}
-- A route addon weighs only the TRAVEL_FEW beasts in reach nearest in a straight line.
local TRAVEL_FEW = 5

---Two teaching beasts in the order the window lists them: the ones the hunter can tame now first,
---above the hunter's level the lowest first. Then the nearer in a straight line (yardsTo), else the
---one on the hunter's map, then the closest in level.
---@param a number
---@param b number
---@return boolean
local function Closer(a, b)
    local beasts, level = Data().beasts, M:PlayerLevel()
    local ba, bb = beasts[a], beasts[b]
    local inA, inB = ba.minLevel <= level, bb.minLevel <= level
    if inA ~= inB then return inA end
    if not inA and ba.minLevel ~= bb.minLevel then return ba.minLevel < bb.minLevel end
    if yardsTo[a] ~= yardsTo[b] then return yardsTo[a] < yardsTo[b] end
    local here = C_Map.GetBestMapForUnit("player")
    local hereA, hereB = FirstMap(ba) == here, FirstMap(bb) == here
    if hereA ~= hereB then return hereA end
    return math.abs(ba.minLevel - level) < math.abs(bb.minLevel - level)
end

---A rank's teachers in the window's order (Closer); with travel times, the first TRAVEL_FEW in
---reach in the order a route addon reaches them. A new list.
---@param teachers number[]
---@return number[]
function M.Nearest(teachers)
    ---@type number[]
    local list = {}
    wipe(yardsTo)
    for i, npc in ipairs(teachers) do
        list[i] = npc
        yardsTo[npc] = select(4, NearestPin(npc))
    end
    table.sort(list, Closer)
    if not GoThere:HasTravelTimes() then return list end
    local beasts, level = Data().beasts, M:PlayerLevel()
    local few = 0
    while few < TRAVEL_FEW and list[few + 1] and beasts[list[few + 1]].minLevel <= level do
        few = few + 1
    end
    -- An insertion sort keeps the straight-line order among equal travel times.
    for i = 2, few do
        local npc, seconds = list[i], TravelSeconds(list[i])
        local j = i - 1
        while j >= 1 and TravelSeconds(list[j]) > seconds do
            list[j + 1] = list[j]
            j = j - 1
        end
        list[j + 1] = npc
    end
    return list
end

---Sends the hunter to a beast's nearest pin (or the pin given) through LibGoThere, and makes it the
---tame key's beast. False for a beast in an instance, which has no pin.
---@param npc number
---@param pinMap number? a pin's map, with its x and y (0 to 1)
---@param pinX number?
---@param pinY number?
---@return boolean
function M:GoToBeast(npc, pinMap, pinX, pinY)
    local map, x, y = pinMap, pinX, pinY
    if not map then
        map, x, y = NearestPin(npc)
    end
    if not map then return false end
    GoThere:Navigate(Addon.NAME, map, x, y, BeastName(npc))
    self:SetTameTarget(BeastName(npc))
    return true
end

---Seconds to a beast, when a route addon gives travel times; nil otherwise.
---@param npc number
---@return number?
function M.TravelTimeTo(npc)
    if not GoThere:HasTravelTimes() then return nil end
    local seconds = TravelSeconds(npc)
    if seconds ~= math.huge then return seconds end
end

---Whether beast `npc` is the better one to name than `pick`: an ordinary one before a rare, then
---the one reached first.
---@param npc number
---@param pick number?
---@return boolean
local function Better(npc, pick)
    if not pick then return true end
    local beasts = Data().beasts
    if beasts[npc].rare ~= beasts[pick].rare then return not beasts[npc].rare end
    return TravelSeconds(npc) < TravelSeconds(pick)
end

---The beast of exactly `level` that teaches a rank, the better one when there are several; nil
---when a lower beast teaches it already, or none of that level does.
---@param rank AddonPetAbilityRank
---@param level number
---@return number?
local function NewTeacher(rank, level)
    local beasts = Data().beasts
    ---@type number?
    local pick
    for _, npc in ipairs(rank.teachers) do
        local beast = beasts[npc]
        if beast.minLevel < level then return nil end
        if beast.minLevel == level and Better(npc, pick) then pick = npc end
    end
    return pick
end

---"Ridge Stalker in Badlands": the beast and the map of its nearest pin, or its zone when it lives
---in an instance; the beast alone when the client has no name for either.
---@param npc number
---@return string
local function Place(npc)
    local beast = Data().beasts[npc]
    ---@type string?
    local where
    local map = NearestPin(npc)
    if map then
        local info = C_Map.GetMapInfo(map)
        where = info and info.name
    else
        -- A beast has pins or, in an instance, zones (the data spec checks it).
        where = C_Map.GetAreaInfo((beast.zones --[[@as number[] ]])[1])
    end
    local name = BeastName(npc)
    return where and L.BEASTMAP_REACH_PLACE:format(name, where) or name
end
M.Place = Place

---The toast for the ranks a level-up brings in reach, if any.
---@param level number
function M:ToastReach(level)
    local settings = self:Settings()
    ---@type number[], table<number, number>
    local found, teacherOf = {}, {}
    for spellID, rank in pairs(Data().petAbilityRanks) do
        local lacking = Lacking(spellID)
        local teacher = (lacking == "above" or (lacking == "gap" and settings.gaps)) and NewTeacher(rank, level)
        if teacher then
            found[#found + 1] = spellID
            teacherOf[spellID] = teacher
        end
    end
    if #found == 0 then return end
    table.sort(found, Before)
    local title, text
    if #found == 1 then
        title = L.BEASTMAP_REACH_ONE:format(RankText(found[1]) or "?")
        text = L.BEASTMAP_REACH_TEACHES:format(Place(teacherOf[found[1]]))
    else
        title = L.BEASTMAP_REACH_MANY:format(#found)
        ---@type string[]
        local lines = {}
        for i, spellID in ipairs(found) do
            lines[i] = L.BEASTMAP_REACH_LINE:format(RankText(spellID) or "?", Place(teacherOf[spellID]))
        end
        text = table.concat(lines, "\n")
    end
    local _, icon = Addon.SpellInfo(found[1])
    Addon:ShowToast({
        key = "BeastMap:reach",
        type = "BeastMap:reach",
        source = self.title,
        title = title,
        text = text,
        icon = icon,
    })
    if settings.levelChat then
        self:Print(title)
        for line in text:gmatch("[^\n]+") do
            self:Print(line)
        end
    end
end

---Redraws the pins once the hunter learns Tame Beast (or, on a respec of sorts, loses it).
function M:SPELLS_CHANGED()
    local canTame = Addon.KnowsSpell(Addon.TAME_BEAST)
    if canTame == self.canTame then return end
    self.canTame = canTame
    self:Refresh()
end

---@param _ string the event
---@param level number the new level
function M:PLAYER_LEVEL_UP(_, level)
    self.level = level
    self:Refresh()
    -- Before Beast Training (the quest Training the Beast) no beast can teach the hunter anything.
    if self:Settings().levelToast and Addon.KnowsSpell(Addon.BEAST_TRAINING) then self:ToastReach(level) end
end

-- Registered once: HandyNotes keeps a plugin for the session.
local registered = false

function M:OnEnable()
    local _, class = UnitClass("player")
    if class ~= "HUNTER" then return end
    if HandyNotes and not registered then
        registered = true
        HandyNotes:RegisterPluginDB(
            PLUGIN,
            handler,
            { type = "group", name = L.BEASTMAP_TITLE, args = self:GetOptions().args }
        )
        self:CreateMapButton()
    end
    self.level = nil
    self.canTame = Addon.KnowsSpell(Addon.TAME_BEAST)
    self:RegisterEvent("PLAYER_LEVEL_UP")
    self:RegisterEvent("SPELLS_CHANGED")
    Addon:Listen(self, Addon.messages.ranksKnown, "OnRanksKnown")
    Addon:Listen(self, Addon.messages.rareSeen, "OnRareSeen")
    Addon:Listen(self, Addon.messages.petTamed, "OnPetTamed")
    self:WatchRares()
    self:ApplyTameButton()
    self:Refresh()
    self:ShowHunt()
end

function M:OnDisable()
    Addon:StopListening(self)
    self:ApplyTameButton()
    self:Refresh()
    self:ShowHunt()
end
