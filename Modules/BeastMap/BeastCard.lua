local _, ns = ...

-- A beast's card in the Beasts tab (Beasts.lua): Back, its name, levels (rare, elite, attack speed
-- off 2.0), family and diet, the ranks it teaches coloured by standing, its model, and the map of
-- where it lives: the zone's art (C_Map's art layer tiles) with a dot per spawn spot (beast.pins),
-- the player's map first and a button per map when it lives on several. A dot click shows the way
-- to that spot; Hunt starts the hunt (Hunt.lua) for the first rank it teaches that the hunter
-- lacks, and stops it again. A beast in an instance has no map, only the instance's name.

---@type Addon
local Addon = ns
local L = Addon.L
local M = Addon:GetModule("BeastMap") --[[@as AddonBeastMap]]

local LEFT_WIDTH, MODEL_SIZE, MAP_X, MAP_TOP, MAP_WIDTH = 220, 190, 236, 52, 410
local MAP_BUTTONS, DOT_SIZE, BUTTON_HEIGHT = 4, 10, 18
local DISC = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local GOLD, DOT = { 1, 0.82, 0 }, { 0.2, 1, 0.2 }
---@type table
local NONE = {}

-- The beast's maps in the card's order, and its taught ranks' lines; refilled per beast. The
-- player's map while sorting.
---@type number[], string[]
local maps, lines = {}, {}
---@type number?
local hereMap

---A text in the skin's font.
---@param parent Frame
---@param skin AddonButtonHolderSkin
---@param size number?
---@param template string?
---@return FontString
local function Text(parent, skin, size, template)
    local text = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlight")
    text:SetJustifyH("LEFT")
    skin.Font(text, size or 12)
    return text
end

---Two maps in the card's order: the player's first, then by uiMapID.
---@param a number
---@param b number
---@return boolean
local function HereFirst(a, b)
    if (a == hereMap) ~= (b == hereMap) then return a == hereMap end
    return a < b
end

---The beast's maps in the card's order.
---@param beast AddonBeast
---@return number[]
local function Maps(beast)
    wipe(maps)
    ---@type table<number, number[]>
    local pins = beast.pins or NONE
    for map in pairs(pins) do
        maps[#maps + 1] = map
    end
    hereMap = C_Map.GetBestMapForUnit("player")
    table.sort(maps, HereFirst)
    return maps
end

---A map's name, "?" when the client has none.
---@param map number
---@return string
local function MapName(map)
    local info = C_Map.GetMapInfo(map)
    return info and info.name or "?"
end

---The art tile at `index`, made the first time.
---@param card AddonBeastCard
---@param index number
---@return Texture
local function Tile(card, index)
    local tile = card.tiles[index]
    if tile then return tile end
    tile = card.map:CreateTexture(nil, "ARTWORK")
    card.tiles[index] = tile
    return tile
end

---A dot clicked: the way to its spot.
---@param dot AddonBeastDot
local function OnDotClick(dot)
    local card = dot.card
    M:GoToBeast(card.npc --[[@as number]], card.shownMap, dot.x / 100, dot.y / 100)
end

---The spawn dot at `index`, made the first time.
---@param card AddonBeastCard
---@param index number
---@return AddonBeastDot
local function Dot(card, index)
    local dot = card.dots[index]
    if dot then return dot end
    dot = CreateFrame("Button", nil, card.map) --[[@as AddonBeastDot]]
    dot:SetSize(DOT_SIZE, DOT_SIZE)
    dot.disc = dot:CreateTexture(nil, "OVERLAY")
    dot.disc:SetAllPoints()
    dot.disc:SetTexture(DISC)
    dot.disc:SetVertexColor(DOT[1], DOT[2], DOT[3])
    dot:SetHighlightTexture(DISC, "ADD")
    dot.card = card
    dot:SetScript("OnClick", OnDotClick)
    card.dots[index] = dot
    return dot
end

---Lays the map's art tiles out at the map's width, the last column and row cut to the layer's
---size; none where the client has no art. Sets the map's height to the art's.
---@param card AddonBeastCard
---@param map number
local function FillArt(card, map)
    local layers = C_Map.GetMapArtLayers(map)
    local info = layers and layers[1]
    local files = info and C_Map.GetMapArtLayerTextures(map, 1)
    local used = 0
    if info and files then
        local scale = MAP_WIDTH / info.layerWidth
        card.map:SetHeight(info.layerHeight * scale)
        local cols = math.ceil(info.layerWidth / info.tileWidth)
        for row = 1, math.ceil(info.layerHeight / info.tileHeight) do
            for col = 1, cols do
                used = used + 1
                local width = math.min(info.tileWidth, info.layerWidth - (col - 1) * info.tileWidth)
                local height = math.min(info.tileHeight, info.layerHeight - (row - 1) * info.tileHeight)
                local tile = Tile(card, used)
                tile:SetTexture(files[used])
                tile:SetSize(width * scale, height * scale)
                tile:ClearAllPoints()
                tile:SetPoint("TOPLEFT", (col - 1) * info.tileWidth * scale, -(row - 1) * info.tileHeight * scale)
                tile:SetTexCoord(0, width / info.tileWidth, 0, height / info.tileHeight)
                tile:Show()
            end
        end
    else
        card.map:SetHeight(MAP_WIDTH * 2 / 3)
    end
    for index = used + 1, #card.tiles do
        card.tiles[index]:Hide()
    end
end

---A dot per spawn spot on the map; the rest hidden.
---@param card AddonBeastCard
---@param flat number[] x1, y1, x2, y2, ... in percent
local function FillDots(card, flat)
    local width, height = MAP_WIDTH, card.map:GetHeight()
    local used = 0
    for i = 1, #flat, 2 do
        used = used + 1
        local dot = Dot(card, used)
        dot.x, dot.y = flat[i], flat[i + 1]
        dot:ClearAllPoints()
        dot:SetPoint("CENTER", card.map, "TOPLEFT", dot.x / 100 * width, -dot.y / 100 * height)
        dot:Show()
    end
    for index = used + 1, #card.dots do
        card.dots[index]:Hide()
    end
end

---Fills the map part: the shown map's name, art and dots, the map buttons; or for a beast in an
---instance, the instance's name.
---@param card AddonBeastCard
---@param beast AddonBeast
local function FillMap(card, beast)
    local list = Maps(beast)
    if not tContains(list, card.shownMap) then card.shownMap = list[1] end
    local map = card.shownMap
    card.map:SetShown(map ~= nil)
    for index, button in ipairs(card.maps) do
        button.map = list[index]
        button:SetShown(#list > 1 and button.map ~= nil)
        if button.map then
            button.label:SetText(MapName(button.map))
            local colour = button.map == map and GOLD or DOT
            button.label:SetTextColor(colour[1], colour[2], colour[3])
            button:SetWidth(button.label:GetStringWidth() + 12)
        end
    end
    if not map then
        card.mapName:SetText(L.BEASTS_INSIDE:format(C_Map.GetAreaInfo((beast.zones or NONE)[1]) or "?"))
        FillDots(card, NONE)
        return
    end
    card.mapName:SetText(MapName(map))
    FillArt(card, map)
    FillDots(card, (beast.pins --[[@as table<number, number[]> ]])[map])
end

---Hunt clicked: the hunt for the card's rank, or its end.
---@param button Button
local function OnHuntClick(button)
    local card = button:GetParent() --[[@as AddonBeastCard]]
    if M:IsHunting(card.npc, card.spellID) then
        M:StopHunt()
    else
        M:StartHunt(card.npc --[[@as number]], card.spellID --[[@as number]])
    end
end

---A map button clicked: that map on the card.
---@param button AddonBeastMapButton
local function OnMapClick(button)
    local card = button:GetParent() --[[@as AddonBeastCard]]
    card.shownMap = button.map
    Addon:RefreshWindow("beasts")
end

---Builds a beast's card on the Beasts tab's panel, hidden.
---@param panel AddonBeastsPanel
---@param skin AddonButtonHolderSkin
---@return AddonBeastCard
function M.CreateBeastCard(panel, skin)
    local card = CreateFrame("Frame", nil, panel) --[[@as AddonBeastCard]]
    card:SetAllPoints()
    card:Hide()
    card.back = CreateFrame("Button", nil, card, "UIPanelButtonTemplate")
    card.back:SetSize(80, 22)
    card.back:SetPoint("TOPLEFT")
    card.back:SetText(L.BEASTS_BACK)
    if skin.Button then skin.Button(card.back) end
    card.back:SetScript("OnClick", function()
        panel.chosen = nil
        Addon:RefreshWindow("beasts")
    end)
    card.title = Text(card, skin, 16, "GameFontNormalLarge")
    card.title:SetPoint("LEFT", card.back, "RIGHT", 10, 0)
    card.level = Text(card, skin)
    card.level:SetPoint("TOPLEFT", 0, -32)
    card.level:SetWidth(LEFT_WIDTH)
    card.family = Text(card, skin)
    card.family:SetPoint("TOPLEFT", card.level, "BOTTOMLEFT", 0, -4)
    card.family:SetWidth(LEFT_WIDTH)
    card.teaches = Text(card, skin)
    card.teaches:SetPoint("TOPLEFT", card.family, "BOTTOMLEFT", 0, -8)
    card.teaches:SetWidth(LEFT_WIDTH)
    card.model = CreateFrame("PlayerModel", nil, card)
    card.model:SetSize(MODEL_SIZE, MODEL_SIZE)
    card.model:SetPoint("TOPLEFT", 0, -150)
    card.hunt = CreateFrame("Button", nil, card, "UIPanelButtonTemplate")
    card.hunt:SetSize(120, 22)
    card.hunt:SetPoint("TOPLEFT", card.model, "BOTTOMLEFT", 0, -6)
    card.hunt:SetScript("OnClick", OnHuntClick)
    if skin.Button then skin.Button(card.hunt) end
    card.mapName = Text(card, skin, 14, "GameFontNormal")
    card.mapName:SetPoint("TOPLEFT", MAP_X, -32)
    card.mapName:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    card.map = CreateFrame("Frame", nil, card)
    card.map:SetSize(MAP_WIDTH, MAP_WIDTH * 2 / 3)
    card.map:SetPoint("TOPLEFT", MAP_X, -MAP_TOP)
    card.map:SetClipsChildren(true)
    local back = card.map:CreateTexture(nil, "BACKGROUND")
    back:SetAllPoints()
    back:SetColorTexture(0, 0, 0, 0.5)
    card.tiles, card.dots, card.maps = {}, {}, {}
    for index = 1, MAP_BUTTONS do
        local button = CreateFrame("Button", nil, card) --[[@as AddonBeastMapButton]]
        button:SetHeight(BUTTON_HEIGHT)
        if index == 1 then
            button:SetPoint("TOPLEFT", card.map, "BOTTOMLEFT", 0, -4)
        else
            button:SetPoint("LEFT", card.maps[index - 1], "RIGHT", 4, 0)
        end
        button.label = Text(button, skin)
        button.label:SetPoint("LEFT", 6, 0)
        button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        button:SetScript("OnClick", OnMapClick)
        card.maps[index] = button
    end
    return card
end

---Fills the card with beast `npc`; a new beast's card starts on its first map.
---@param card AddonBeastCard
---@param npc number
function M.FillBeastCard(card, npc)
    local beast = Addon.data.beasts[npc] --[[@as AddonBeast]]
    if card.npc ~= npc then
        card.npc, card.shownMap = npc, nil
    end
    local name = M.BeastName(npc)
    card.title:SetText(beast.rare and L.BEASTS_RARE_NAME:format(name) or name)
    card.level:SetText(M.LevelText(beast))
    local family, diet = Addon.FamilyName(beast.family) or "?", Addon.DietText(beast.family)
    card.family:SetText(diet and L.BEASTS_FAMILY_DIET:format(family, diet) or family)
    wipe(lines)
    card.spellID = nil
    ---@type number[]
    local spells = M.TeachesOf(npc) or NONE
    for _, spellID in ipairs(spells) do
        lines[#lines + 1] = M.StandingText(spellID)
        if not card.spellID and M.Lacking(spellID) then card.spellID = spellID end
    end
    card.teaches:SetText(table.concat(lines, "\n"))
    -- By display ID the model shows at once; by NPC ID only once the client has the creature cached.
    card.model:ClearModel()
    if beast.display then
        card.model:SetDisplayInfo(beast.display)
    else
        card.model:SetCreature(npc)
    end
    card.hunt:SetShown(card.spellID ~= nil)
    card.hunt:SetText(M:IsHunting(npc, card.spellID) and L.BEASTS_HUNT_STOP or L.BEASTS_HUNT)
    FillMap(card, beast)
end
