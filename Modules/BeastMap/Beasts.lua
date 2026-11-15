local _, ns = ...

-- The Beasts tab of Huntsworn's window (Core\Window.lua): every beast that teaches a pet ability
-- rank, like Wowhead's hunter pets tool but measured against this hunter. Each with its family,
-- levels, the ranks it teaches coloured by how the hunter stands to each (new green, skipped
-- yellow, known grey, as on the beast's tooltip), the yards to it in a straight line with a button
-- that shows the way there, and its attack speed when not 2.0.
--
-- Two kinds of filter, both kept in the profile. On top, quick ones: a name search, ability,
-- family, diet, zone (all, the player's own, one), whether the hunter has every rank already or not
-- yet, in reach (at most the hunter's level), rares only. Under them, filter text and its Builder
-- (LibDataGrid-1.0), which filter what the quick ones let through: `[Level] BETWEEN 10 AND 20 AND
-- [Speed] < 2`. The list is LibDataGrid's grid: a click on a head sorts by it (up, down, off), Ctrl
-- adds a second column; unsorted, by level then name. A click on a row opens the beast's card
-- (BeastCard.lua) in the list's place.

---@type Addon
local Addon = ns
local L = Addon.L
local M = Addon:GetModule("BeastMap") --[[@as AddonBeastMap]]
local DG = LibStub("LibDataGrid-1.0") --[[@as LibDataGrid]]
local T = DG.types

local LINE_HEIGHT, ROW_HEIGHT, SEARCH_WIDTH = 24, 18, 140
-- Where the filter box and the grid start, and the grid's height: its header and 15 rows.
local BOX_TOP, GRID_TOP, GRID_HEIGHT = 48, 88, 20 + 15 * ROW_HEIGHT
local GO_ICON = "Interface\\Icons\\INV_Misc_Map_01"
local CHECK_BOX, CHECK_MARK = "Interface\\Buttons\\UI-CheckBox-Up", "Interface\\Buttons\\UI-CheckBox-Check"
local DIM = { 0.6, 0.6, 0.6 }
local QUESTION_MARK = 134400
-- A rank's colour code in the Teaches column, by how the hunter stands to it (M.Lacking).
local STANDING = { above = "ff00ff00", gap = "ffffff00", known = "ff808080" }
-- Every picker's first choice: no filter.
local ALL = "all"
-- The Zone filter's choice for the player's own map; the others are uiMapIDs, or minus an
-- instance's AreaTable ID for beasts in one.
local ZONE_HERE = "here"
-- The You filter's choices.
local YOU = { all = ALL, has = "has", lacks = "lacks" }
-- The grid's columns, by key (the names filter text also takes).
local COLUMNS = {
    name = "name",
    family = "family",
    level = "level",
    teaches = "teaches",
    distance = "distance",
    speed = "speed",
    rare = "rare",
}
---@type number[]
local NONE = {}

-- The choices of the Ability, Family, Diet and Zone pickers apart from ALL and ZONE_HERE, in
-- order; built the first time from the data. The Family column's choices, from the same families.
---@type number[], number[], string[], number[], LibDataGridChoice[]
local abilities, families, diets, zones, familyChoices
-- The beasts that pass the quick filters, by level then name, and every teaching beast's name;
-- refilled for each look. The ranks named in a Teaches cell, refilled for each cell.
---@type number[], table<number, string>, string[]
local shown, names, parts = {}, {}, {}
-- The yards to each beast shown, worked out once per look (BeastMap.lua's YardsTo).
---@type table<number, number>
local yards = {}

---A zone choice's name: a map's, or an instance's area.
---@param zone number
---@return string?
local function ZoneName(zone)
    if zone < 0 then return C_Map.GetAreaInfo(-zone) end
    local info = C_Map.GetMapInfo(zone)
    return info and info.name
end

---@param a number
---@param b number
---@return boolean
local function ByAbilityName(a, b)
    return M.AbilityName(a) < M.AbilityName(b)
end

---@param a number
---@param b number
---@return boolean
local function ByFamilyName(a, b)
    return (Addon.FamilyName(a) or "") < (Addon.FamilyName(b) or "")
end

---@param a string
---@param b string
---@return boolean
local function ByFoodName(a, b)
    return Addon.FoodName(a) < Addon.FoodName(b)
end

---@param a number
---@param b number
---@return boolean
local function ByZoneName(a, b)
    return (ZoneName(a) or "") < (ZoneName(b) or "")
end

---Adds `value` to a list unless it is there (the list's `seen`).
---@param list (string|number)[]
---@param seen table<string|number, true>
---@param value string|number
local function AddOnce(list, seen, value)
    if seen[value] then return end
    seen[value] = true
    list[#list + 1] = value
end

---The pickers' choices from the data: the abilities beasts teach, the families with beasts, what
---those eat, the maps and instances beasts live in that the client can name; each by name.
local function Choices()
    if zones then return end
    abilities, families, diets, zones, familyChoices = {}, {}, {}, {}, {}
    ---@type table<string|number, true>, table<string|number, true>, table<string|number, true>, table<string|number, true>
    local seenAbility, seenFamily, seenDiet, seenZone = {}, {}, {}, {}
    for _, rank in pairs(Addon.data.petAbilityRanks) do
        AddOnce(abilities, seenAbility, rank.ability)
    end
    for _, beast in
        pairs(Addon.data.beasts --[[@as table<number, AddonBeast>]])
    do
        AddOnce(families, seenFamily, beast.family)
        for map in pairs(beast.pins or NONE) do
            if ZoneName(map) then AddOnce(zones, seenZone, map) end
        end
        for _, area in ipairs(beast.zones or NONE) do
            if ZoneName(-area) then AddOnce(zones, seenZone, -area) end
        end
    end
    for _, familyID in
        ipairs(families --[[@as number[] ]])
    do
        local info = Addon.familyInfo[familyID]
        for _, food in ipairs(info and info.diet or NONE) do
            AddOnce(diets, seenDiet, food)
        end
    end
    table.sort(abilities, ByAbilityName)
    table.sort(families, ByFamilyName)
    table.sort(diets, ByFoodName)
    table.sort(zones, ByZoneName)
    for index, familyID in
        ipairs(families --[[@as number[] ]])
    do
        familyChoices[index] = { value = familyID, text = Addon.FamilyName(familyID) or "?" }
    end
end

---The tab's filters in the profile.
---@return AddonBeastsFilter
local function Filter()
    return M:Settings().beasts
end

---Whether a family eats a kind of food.
---@param familyID number
---@param food string
---@return boolean
local function Eats(familyID, food)
    local info = Addon.familyInfo[familyID]
    return info ~= nil and tContains(info.diet or NONE, food)
end

---Whether a beast lives in a zone choice: on the map, or in the instance.
---@param beast AddonBeast
---@param zone number?
---@return boolean
local function LivesIn(beast, zone)
    if not zone then return false end
    if zone < 0 then return tContains(beast.zones or NONE, -zone) end
    return beast.pins ~= nil and beast.pins[zone] ~= nil
end

---Whether a beast passes the quick filters. With an ability chosen, only that ability's ranks count
---for the You filter.
---@param npc number
---@param beast AddonBeast
---@param filter AddonBeastsFilter
---@param search string the search in lower case
---@param here number? the player's map
---@return boolean
local function Passes(npc, beast, filter, search, here)
    if filter.rares and not beast.rare then return false end
    if filter.reach and beast.minLevel > M:PlayerLevel() then return false end
    if filter.family ~= ALL and beast.family ~= filter.family then return false end
    if
        filter.diet ~= ALL and not Eats(beast.family, filter.diet --[[@as string]])
    then
        return false
    end
    if filter.zone ~= ALL then
        local zone = filter.zone == ZONE_HERE and here or filter.zone --[[@as number?]]
        if not LivesIn(beast, zone) then return false end
    end
    if search ~= "" and not names[npc]:lower():find(search, 1, true) then return false end
    local teaches, lacks = filter.ability == ALL, false
    ---@type number[]
    local spells = M.TeachesOf(npc) or NONE
    for _, spellID in ipairs(spells) do
        if filter.ability == ALL or Addon.data.petAbilityRanks[spellID].ability == filter.ability then
            teaches = true
            lacks = lacks or M.Lacking(spellID) ~= nil
        end
    end
    if not teaches then return false end
    if filter.you == YOU.has then return not lacks end
    if filter.you == YOU.lacks then return lacks end
    return true
end

---Two beasts in list order: by lowest level, then name.
---@param a number
---@param b number
---@return boolean
local function ByLevel(a, b)
    local beasts = Addon.data.beasts
    local la, lb = beasts[a].minLevel, beasts[b].minLevel
    if la ~= lb then return la < lb end
    if names[a] ~= names[b] then return names[a] < names[b] end
    return a < b
end

---The beasts that pass the quick filters, by level then name, with the yards to each in `yards`.
---The grid filters and sorts them further.
---@param filter AddonBeastsFilter
---@return number[]
local function Matching(filter)
    wipe(shown)
    wipe(yards)
    local search, here = filter.search:lower(), C_Map.GetBestMapForUnit("player")
    for npc, beast in
        pairs(Addon.data.beasts --[[@as table<number, AddonBeast>]])
    do
        names[npc] = M.BeastName(npc)
        if Passes(npc, beast, filter, search, here) then
            shown[#shown + 1] = npc
            yards[npc] = M.YardsTo(npc)
        end
    end
    table.sort(shown, ByLevel)
    return shown
end

---A text in the skin's font, on one line.
---@param parent Frame
---@param skin AddonButtonHolderSkin
---@param justify string?
---@return FontString
local function Text(parent, skin, justify)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetJustifyH(justify or "LEFT")
    text:SetWordWrap(false)
    skin.Font(text, 12)
    return text
end

---A rank in the colour of how the hunter stands to it.
---@param spellID number
---@return string
local function Coloured(spellID)
    return ("|c%s%s|r"):format(STANDING[M.Lacking(spellID) or "known"], M.RankText(spellID) or "?")
end
-- For the beast's card (BeastCard.lua).
M.StandingText = Coloured

---"5" or "5-6".
---@param beast AddonBeast
---@return string
local function Levels(beast)
    if beast.minLevel == beast.maxLevel then return tostring(beast.minLevel) end
    return ("%d-%d"):format(beast.minLevel, beast.maxLevel)
end

---The ranks a beast teaches, coloured by standing or plain (what filter text searches), with ", ".
---@param npc number
---@param colour boolean
---@return string
local function TeachesText(npc, colour)
    wipe(parts)
    for _, spellID in
        ipairs(M.TeachesOf(npc) or NONE --[[@as number[] ]])
    do
        parts[#parts + 1] = colour and Coloured(spellID) or (M.RankText(spellID) or "?")
    end
    return table.concat(parts, ", ")
end

---The tooltip of a row's map button.
---@param go Button
local function OnGoEnter(go)
    local line = (go:GetParent() --[[@as Frame]]):GetParent() --[[@as LibDataGridGridLine]]
    GameTooltip:SetOwner(go, "ANCHOR_RIGHT")
    GameTooltip:SetText(L.BEASTS_GO:format(names[
        line.row --[[@as number]]
    ]))
    GameTooltip:Show()
end

local function OnGoLeave()
    GameTooltip:Hide()
end

---@param go Button
local function OnGoClick(go)
    local line = (go:GetParent() --[[@as Frame]]):GetParent() --[[@as LibDataGridGridLine]]
    M:GoToBeast(line.row --[[@as number]])
end

---The Beast column's cells: the icon of the first rank the beast teaches that the hunter lacks
---(else its first), then its name, marked when rare.
---@param skin AddonButtonHolderSkin
---@return LibDataGridRenderer
local function NameCells(skin)
    ---@type LibDataGridRenderer
    local renderer = {}

    ---@param line Button
    ---@return Region
    function renderer:Create(line)
        local cell = CreateFrame("Frame", nil, line) --[[@as AddonBeastNameCell]]
        cell:SetHeight(ROW_HEIGHT)
        cell.icon = cell:CreateTexture(nil, "ARTWORK")
        cell.icon:SetSize(ROW_HEIGHT - 2, ROW_HEIGHT - 2)
        cell.icon:SetPoint("LEFT", 2, 0)
        Addon:CropIcon(cell.icon, skin.CropIcon)
        cell.label = Text(cell, skin)
        cell.label:SetPoint("LEFT", cell.icon, "RIGHT", 4, 0)
        cell.label:SetPoint("RIGHT", -4, 0)
        return cell
    end

    ---@param region Region
    ---@param row LibDataGridRow
    function renderer:Fill(region, row)
        local cell = region --[[@as AddonBeastNameCell]]
        local npc = row --[[@as number]]
        ---@type number[]
        local spells = M.TeachesOf(npc) or NONE
        ---@type number?
        local first
        for _, spellID in ipairs(spells) do
            if not first and M.Lacking(spellID) then first = spellID end
        end
        local _, icon = Addon.SpellInfo(first or spells[1])
        cell.icon:SetTexture(icon or QUESTION_MARK)
        local beast = Addon.data.beasts[npc] --[[@as AddonBeast]]
        cell.label:SetText(beast.rare and L.BEASTS_RARE_NAME:format(names[npc]) or names[npc])
    end

    return renderer
end

---The Distance column's cells: the yards, and the button that shows the way, for a beast out in
---the open.
---@param skin AddonButtonHolderSkin
---@return LibDataGridRenderer
local function DistanceCells(skin)
    ---@type LibDataGridRenderer
    local renderer = {}

    ---@param line Button
    ---@return Region
    function renderer:Create(line)
        local cell = CreateFrame("Frame", nil, line) --[[@as AddonBeastDistanceCell]]
        cell:SetHeight(ROW_HEIGHT)
        cell.go = CreateFrame("Button", nil, cell)
        cell.go:SetSize(ROW_HEIGHT - 2, ROW_HEIGHT - 2)
        cell.go:SetPoint("RIGHT", -2, 0)
        cell.go:SetNormalTexture(GO_ICON)
        cell.go:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        cell.go:SetScript("OnClick", OnGoClick)
        cell.go:SetScript("OnEnter", OnGoEnter)
        cell.go:SetScript("OnLeave", OnGoLeave)
        cell.label = Text(cell, skin, "RIGHT")
        cell.label:SetPoint("LEFT", 2, 0)
        cell.label:SetPoint("RIGHT", cell.go, "LEFT", -4, 0)
        return cell
    end

    ---@param region Region
    ---@param row LibDataGridRow
    function renderer:Fill(region, row)
        local cell = region --[[@as AddonBeastDistanceCell]]
        local npc = row --[[@as number]]
        local distance = yards[npc]
        cell.label:SetText(distance ~= math.huge and L.BEASTS_YARDS:format(math.floor(distance + 0.5)) or "")
        cell.go:SetShown(Addon.data.beasts[npc].pins ~= nil)
    end

    return renderer
end

---The beasts' columns, for the grid and filter text.
---@param skin AddonButtonHolderSkin
---@return LibDataGridSchema
local function Schema(skin)
    local beasts = Addon.data.beasts
    return DG:NewSchema({
        {
            key = COLUMNS.name,
            label = L.BEASTS_COLUMN_BEAST,
            value = function(npc)
                return names[npc]
            end,
            renderer = NameCells(skin),
        },
        {
            key = COLUMNS.family,
            label = L.BEASTS_COLUMN_FAMILY,
            type = T.enum,
            value = function(npc)
                return beasts[npc].family
            end,
            choices = function()
                Choices()
                return familyChoices
            end,
        },
        {
            key = COLUMNS.level,
            label = L.BEASTS_COLUMN_LEVEL,
            type = T.number,
            value = function(npc)
                return beasts[npc].minLevel
            end,
            text = function(npc)
                return Levels(beasts[npc])
            end,
        },
        {
            key = COLUMNS.teaches,
            label = L.BEASTS_COLUMN_TEACHES,
            value = function(npc)
                return TeachesText(npc, false)
            end,
            text = function(npc)
                return TeachesText(npc, true)
            end,
        },
        {
            key = COLUMNS.distance,
            label = L.BEASTS_COLUMN_DISTANCE,
            type = T.number,
            align = DG.aligns.right,
            -- Those it cannot place have no distance, so they sort last either way.
            value = function(npc)
                local distance = yards[npc]
                return distance ~= math.huge and distance or nil
            end,
            renderer = DistanceCells(skin),
        },
        {
            key = COLUMNS.speed,
            label = L.BEASTS_COLUMN_SPEED,
            type = T.number,
            align = DG.aligns.right,
            -- Without a speed in the data a beast attacks at the usual 2.0, which the cell leaves out.
            value = function(npc)
                return M.AttackSpeed(npc) or 2
            end,
            text = function(npc)
                local speed = M.AttackSpeed(npc)
                return speed and ("%.1f"):format(speed) or ""
            end,
        },
        {
            key = COLUMNS.rare,
            label = L.BEASTS_COLUMN_RARE,
            type = T.boolean,
            value = function(npc)
                return beasts[npc].rare == true
            end,
        },
    })
end

---LibDataGrid's skin in Huntsworn's: the panel style, fonts, buttons, boxes and fields.
---@param skin AddonButtonHolderSkin
---@return LibDataGridSkinMixin
local function GridSkin(skin)
    ---@type LibDataGridSkinMixin
    local own = CreateFromMixins(DG.SkinMixin)

    ---@param frame Frame
    function own:Backdrop(frame)
        skin.Style(frame)
    end

    ---@param text FontString
    function own:Font(text)
        skin.Font(text, 12)
    end

    -- Where the skin has no look of its own for one, LibDataGrid's plain one stays.
    local Button, EditBox, Field, ScrollBar, Close = skin.Button, skin.EditBox, skin.Field, skin.ScrollBar, skin.Close
    if Close then
        ---@param button Button
        function own:CloseButton(button)
            Close(button)
        end
    end
    if ScrollBar then
        ---@param bar Slider
        function own:ScrollBar(bar)
            ScrollBar(bar)
        end
    end
    if Button then
        ---@param button Button
        function own:Button(button)
            Button(button)
        end
    end
    if EditBox then
        ---@param box EditBox
        function own:EditBox(box)
            EditBox(box)
        end
    end
    if Field then
        ---@param frame Frame
        function own:Field(frame)
            Field(frame)
        end
    end
    return own
end

---A quick filter changed: back to the top of the list.
---@param panel AddonBeastsPanel
local function Changed(panel)
    panel.grid.bar.offset = 0
    Addon:RefreshWindow("beasts")
end

---A switch with its word: In reach, Rares.
---@param panel AddonBeastsPanel
---@param skin AddonButtonHolderSkin
---@param label string
---@param key "reach"|"rares"
---@return AddonCheckText
local function Switch(panel, skin, label, key)
    local button = CreateFrame("Button", nil, panel.browse) --[[@as AddonCheckText]]
    button.label = Text(button, skin)
    button.label:SetPoint("LEFT", ROW_HEIGHT + 2, 0)
    button.label:SetText(label)
    button:SetSize(button.label:GetStringWidth() + ROW_HEIGHT + 6, ROW_HEIGHT)
    button.box = CreateFrame("Frame", nil, button)
    button.box:SetSize(ROW_HEIGHT, ROW_HEIGHT)
    button.box:SetPoint("LEFT")
    if skin.Field then
        skin.Field(button.box)
    else
        local square = button.box:CreateTexture(nil, "ARTWORK")
        square:SetAllPoints()
        square:SetTexture(CHECK_BOX)
    end
    button.check = button.box:CreateTexture(nil, "OVERLAY")
    button.check:SetTexture(CHECK_MARK)
    button.check:SetAllPoints()
    button:SetScript("OnClick", function()
        local filter = Filter()
        filter[key] = not filter[key]
        Changed(panel)
    end)
    return button
end

---A picker for one quick filter.
---@param panel AddonBeastsPanel
---@param skin AddonButtonHolderSkin
---@param width number
---@param title string
---@param key "ability"|"family"|"diet"|"zone"|"you"
---@return AddonPicker
local function FilterPicker(panel, skin, width, title, key)
    return Addon.Picker(panel.browse, skin, width, title, function(value)
        Filter()[key] = value
        Changed(panel)
    end)
end

---The search box, with its grey word while empty.
---@param panel AddonBeastsPanel
---@param skin AddonButtonHolderSkin
---@return EditBox
local function SearchBox(panel, skin)
    local box = CreateFrame("EditBox", nil, panel.browse, "InputBoxTemplate")
    box:SetSize(SEARCH_WIDTH, 20)
    box:SetAutoFocus(false)
    box:SetPoint("TOPLEFT", 6, 0)
    if skin.EditBox then skin.EditBox(box) end
    panel.hint = Text(box, skin)
    panel.hint:SetPoint("LEFT", 2, 0)
    panel.hint:SetText(L.BEASTS_SEARCH)
    panel.hint:SetTextColor(DIM[1], DIM[2], DIM[3])
    ---@param _ EditBox
    ---@param byUser boolean false when Refresh puts the saved search back
    box:SetScript("OnTextChanged", function(_, byUser)
        panel.hint:SetShown(box:GetText() == "")
        if not byUser then return end
        Filter().search = box:GetText()
        Changed(panel)
    end)
    box:SetScript("OnEscapePressed", box.ClearFocus)
    box:SetScript("OnEnterPressed", box.ClearFocus)
    return box
end

---The filter text and the sort changed: kept in the profile, and the count follows.
---@param panel AddonBeastsPanel
local function OnGridChanged(panel)
    local settings = Filter().grid
    settings.filter, settings.sort = panel.view:GetFilterModel(), panel.view:GetSort()
    Addon:RefreshWindow("beasts")
end

---Builds the panel: in `browse` two lines of quick filters and the count, the filter box, and the
---grid; beside it the beast's card, which takes its place.
---@param panel AddonBeastsPanel
---@param skin AddonButtonHolderSkin
local function Create(panel, skin)
    panel.browse = CreateFrame("Frame", nil, panel)
    panel.browse:SetAllPoints()
    panel.card = M.CreateBeastCard(panel, skin)
    panel.search = SearchBox(panel, skin)
    panel.pickers = {
        ability = FilterPicker(panel, skin, 170, L.BEASTS_ABILITY, "ability"),
        family = FilterPicker(panel, skin, 150, L.BEASTS_FAMILY, "family"),
        diet = FilterPicker(panel, skin, 140, L.BEASTS_DIET, "diet"),
        zone = FilterPicker(panel, skin, 220, L.BEASTS_ZONE, "zone"),
        you = FilterPicker(panel, skin, 150, L.BEASTS_YOU, "you"),
    }
    local pickers = panel.pickers
    pickers.ability:SetPoint("LEFT", panel.search, "RIGHT", 10, 0)
    pickers.family:SetPoint("LEFT", pickers.ability, "RIGHT", 6, 0)
    pickers.diet:SetPoint("LEFT", pickers.family, "RIGHT", 6, 0)
    pickers.zone:SetPoint("TOPLEFT", 0, -LINE_HEIGHT)
    pickers.you:SetPoint("LEFT", pickers.zone, "RIGHT", 6, 0)
    panel.reach = Switch(panel, skin, L.BEASTS_REACH, "reach")
    panel.reach:SetPoint("LEFT", pickers.you, "RIGHT", 10, 0)
    panel.rares = Switch(panel, skin, L.BEASTS_RARES, "rares")
    panel.rares:SetPoint("LEFT", panel.reach, "RIGHT", 8, 0)
    panel.count = Text(panel.browse, skin, "RIGHT")
    panel.count:SetPoint("TOPRIGHT", 0, -LINE_HEIGHT - 4)
    panel.count:SetTextColor(DIM[1], DIM[2], DIM[3])

    local gridSkin, settings = GridSkin(skin), Filter().grid
    panel.view = Schema(skin):NewView()
    panel.view:SetFilterModel(settings.filter)
    panel.view:SetSort(settings.sort)
    panel.filterBox = DG:CreateFilterBox(panel.browse, panel.view, gridSkin)
    panel.filterBox:SetPoint("TOPLEFT", 0, -BOX_TOP)
    panel.filterBox:SetPoint("TOPRIGHT", 0, -BOX_TOP)
    ---A click on a row opens the beast's card.
    ---@type table
    local opensCard = {}
    ---@param row LibDataGridRow
    function opensCard:OnRowClick(row)
        panel.chosen = row --[[@as number]]
        Addon:RefreshWindow("beasts")
    end
    panel.grid = DG:CreateGrid(panel.browse, panel.view, gridSkin, opensCard)
    panel.grid:SetPoint("TOPLEFT", 0, -GRID_TOP)
    panel.grid:SetSize(Addon.WINDOW_PANEL_WIDTH, GRID_HEIGHT)
    panel.grid:AddFixedWidthColumn(COLUMNS.name, 176)
    panel.grid:AddFixedWidthColumn(COLUMNS.family, 94)
    panel.grid:AddFixedWidthColumn(COLUMNS.level, 50)
    panel.grid:AddFillColumn(COLUMNS.teaches)
    panel.grid:AddFixedWidthColumn(COLUMNS.distance, 84)
    panel.grid:AddFixedWidthColumn(COLUMNS.speed, 44)
    for _, event in pairs(DG.events) do
        panel.view:RegisterCallback(event, OnGridChanged, panel)
    end
end

---Refills a picker's choices: ALL first with its text, then `values` named by `Name`. Returns the
---choice it shows (the filter's, or ALL when that is gone).
---@param picker AddonPicker
---@param allText string
---@param values (number|string)[]
---@param Name fun(value: number|string): string?
---@param current string|number
---@return string|number
local function FillChoices(picker, allText, values, Name, current)
    wipe(picker.values)
    wipe(picker.texts)
    picker.values[1], picker.texts[1] = ALL, allText
    for index, value in ipairs(values) do
        picker.values[index + 1], picker.texts[index + 1] = value, Name(value) or "?"
    end
    return Addon.FillPicker(picker, current)
end

-- The You picker's choices after ALL, and their texts.
local YOU_VALUES = { YOU.has, YOU.lacks }
local YOU_TEXTS = { [YOU.has] = L.BEASTS_YOU_HAS, [YOU.lacks] = L.BEASTS_YOU_LACKS }

---@param value string
---@return string
local function YouText(value)
    return YOU_TEXTS[value]
end

---@param familyID number
---@return string?
local function FamilyText(familyID)
    return Addon.FamilyName(familyID)
end

---Fills the pickers and switches from the quick filters.
---@param panel AddonBeastsPanel
---@param filter AddonBeastsFilter
local function FillFilters(panel, filter)
    Choices()
    local pickers = panel.pickers
    filter.ability = FillChoices(pickers.ability, L.BEASTS_ABILITY_ALL, abilities, M.AbilityName, filter.ability)
    filter.family = FillChoices(pickers.family, L.BEASTS_FAMILY_ALL, families, FamilyText, filter.family)
    filter.diet = FillChoices(pickers.diet, L.BEASTS_DIET_ALL, diets, Addon.FoodName, filter.diet) --[[@as string]]
    filter.you = FillChoices(pickers.you, L.BEASTS_YOU_ALL, YOU_VALUES, YouText, filter.you) --[[@as "all"|"has"|"lacks"]]
    -- The zones, with the player's own second.
    local zone = pickers.zone
    FillChoices(zone, L.BEASTS_ZONE_ALL, zones, ZoneName, filter.zone)
    local here = C_Map.GetBestMapForUnit("player")
    table.insert(zone.values, 2, ZONE_HERE)
    table.insert(zone.texts, 2, L.BEASTS_ZONE_HERE:format(here and ZoneName(here) or "?"))
    filter.zone = Addon.FillPicker(zone, filter.zone)
    panel.reach.check:SetShown(filter.reach)
    panel.rares.check:SetShown(filter.rares)
    if panel.search:GetText() ~= filter.search then panel.search:SetText(filter.search) end
    panel.hint:SetShown(filter.search == "")
end

---Fills the chosen beast's card, or else the quick filters, the grid and the count.
---@param panel AddonBeastsPanel
local function Refresh(panel)
    local chosen = panel.chosen and Addon.data.beasts[panel.chosen] and panel.chosen
    panel.browse:SetShown(not chosen)
    panel.card:SetShown(chosen ~= nil)
    if chosen then
        M.FillBeastCard(panel.card, chosen)
        return
    end
    local filter = Filter()
    FillFilters(panel, filter)
    panel.grid:SetRows(Matching(filter))
    local count = panel.grid.count
    panel.count:SetText(count == 0 and L.BEASTS_NONE or L.BEASTS_COUNT:format(count))
end

Addon:RegisterWindowTab({
    id = "beasts",
    title = L.BEASTS_TAB,
    order = 25,
    module = "BeastMap",
    Create = Create,
    Refresh = Refresh,
})
