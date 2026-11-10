local _, ns = ...

-- The Beasts tab of Huntsworn's window (Core\Window.lua): every beast that teaches a pet ability
-- rank, like Wowhead's hunter pets tool but measured against this hunter. By level, then name, each
-- with its family, levels, the ranks it teaches coloured by how the hunter stands to each (new
-- green, skipped yellow, known grey, as on the beast's tooltip), its attack speed when not 2.0, and
-- a button that shows the way there. Filters on top, kept in the profile: a name search, ability,
-- family, diet, zone (all, the player's own, one), whether the hunter has every rank already or not
-- yet, in reach (at most the hunter's level), rares only. A click on a row opens the beast's card
-- (BeastCard.lua) in the list's place.

---@type Addon
local Addon = ns
local L = Addon.L
local M = Addon:GetModule("BeastMap") --[[@as AddonBeastMap]]

local LINE_HEIGHT, ROW_HEIGHT, LIST_TOP, ROWS = 24, 18, 68, 18
local ICON_X, NAME_X, FAMILY_X, LEVEL_X, TEACHES_X = 2, 22, 178, 272, 322
local SPEED_WIDTH, SEARCH_WIDTH = 34, 140
local GO_ICON = "Interface\\Icons\\INV_Misc_Map_01"
local CHECK_BOX, CHECK_MARK = "Interface\\Buttons\\UI-CheckBox-Up", "Interface\\Buttons\\UI-CheckBox-Check"
local GOLD, DIM = { 1, 0.82, 0 }, { 0.6, 0.6, 0.6 }
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
---@type number[]
local NONE = {}

-- The choices of the Ability, Family, Diet and Zone pickers apart from ALL and ZONE_HERE, in
-- order; built the first time from the data.
---@type number[], number[], string[], number[]
local abilities, families, diets, zones
-- The beasts that pass the filters in list order, and every teaching beast's name; refilled for
-- each look. The ranks named in a row's Teaches column, refilled for each row.
---@type number[], table<number, string>, string[]
local shown, names, parts = {}, {}, {}

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
    abilities, families, diets, zones = {}, {}, {}, {}
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

---Whether a beast passes the filters. With an ability chosen, only that ability's ranks count for
---the You filter.
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

---The beasts that pass the filters, in list order.
---@param filter AddonBeastsFilter
---@return number[]
local function Matching(filter)
    wipe(shown)
    local search, here = filter.search:lower(), C_Map.GetBestMapForUnit("player")
    for npc, beast in
        pairs(Addon.data.beasts --[[@as table<number, AddonBeast>]])
    do
        names[npc] = M.BeastName(npc)
        if Passes(npc, beast, filter, search, here) then shown[#shown + 1] = npc end
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

---A filter changed: back to the top of the list.
---@param panel AddonBeastsPanel
local function Changed(panel)
    panel.bar.offset = 0
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
    local box = button:CreateTexture(nil, "ARTWORK")
    box:SetTexture(CHECK_BOX)
    box:SetSize(ROW_HEIGHT, ROW_HEIGHT)
    box:SetPoint("LEFT")
    button.check = button:CreateTexture(nil, "OVERLAY")
    button.check:SetTexture(CHECK_MARK)
    button.check:SetAllPoints(box)
    button:SetScript("OnClick", function()
        local filter = Filter()
        filter[key] = not filter[key]
        Changed(panel)
    end)
    return button
end

---A picker for one filter.
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

---The tooltip of a row's map button.
---@param go Button
local function OnGoEnter(go)
    local row = go:GetParent() --[[@as AddonBeastRow]]
    GameTooltip:SetOwner(go, "ANCHOR_RIGHT")
    GameTooltip:SetText(L.BEASTS_GO:format(names[row.npc]))
    GameTooltip:Show()
end

local function OnGoLeave()
    GameTooltip:Hide()
end

---A row of the list: icon, name, family, levels, what it teaches, speed, the map button.
---@param panel AddonBeastsPanel
---@param skin AddonButtonHolderSkin
---@param index number
---@return AddonBeastRow
local function Row(panel, skin, index)
    local row = CreateFrame("Button", nil, panel.list) --[[@as AddonBeastRow]]
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
    row:SetPoint("RIGHT")
    row.stripe = row:CreateTexture(nil, "BACKGROUND")
    row.stripe:SetAllPoints()
    row.stripe:SetColorTexture(1, 1, 1, 0.05)
    row.stripe:SetShown(index % 2 == 0)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ROW_HEIGHT - 2, ROW_HEIGHT - 2)
    row.icon:SetPoint("LEFT", ICON_X, 0)
    Addon:CropIcon(row.icon, skin.CropIcon)
    row.name = Text(row, skin)
    row.name:SetPoint("LEFT", NAME_X, 0)
    row.name:SetWidth(FAMILY_X - NAME_X - 4)
    row.family = Text(row, skin)
    row.family:SetPoint("LEFT", FAMILY_X, 0)
    row.family:SetWidth(LEVEL_X - FAMILY_X - 4)
    row.level = Text(row, skin)
    row.level:SetPoint("LEFT", LEVEL_X, 0)
    row.level:SetWidth(TEACHES_X - LEVEL_X - 4)
    row.go = CreateFrame("Button", nil, row)
    row.go:SetSize(ROW_HEIGHT - 2, ROW_HEIGHT - 2)
    row.go:SetPoint("RIGHT", -2, 0)
    row.go:SetNormalTexture(GO_ICON)
    row.go:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    row.go:SetScript("OnClick", function()
        M:GoToBeast(row.npc --[[@as number]])
    end)
    row.go:SetScript("OnEnter", OnGoEnter)
    row.go:SetScript("OnLeave", OnGoLeave)
    row.speed = Text(row, skin, "RIGHT")
    row.speed:SetWidth(SPEED_WIDTH)
    row.speed:SetPoint("RIGHT", row.go, "LEFT", -6, 0)
    row.teaches = Text(row, skin)
    row.teaches:SetPoint("LEFT", TEACHES_X, 0)
    row.teaches:SetPoint("RIGHT", row.speed, "LEFT", -4, 0)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row:SetScript("OnClick", function()
        panel.chosen = row.npc
        Addon:RefreshWindow("beasts")
    end)
    return row
end

---The column heads above the rows, in gold.
---@param panel AddonBeastsPanel
---@param skin AddonButtonHolderSkin
local function Heads(panel, skin)
    ---@param x number
    ---@param label string
    ---@param right boolean?
    local function Head(x, label, right)
        local text = Text(panel.browse, skin, right and "RIGHT" or nil)
        if right then
            text:SetPoint("TOPRIGHT", panel.list, "TOPRIGHT", x, ROW_HEIGHT)
        else
            text:SetPoint("TOPLEFT", panel.list, "TOPLEFT", x, ROW_HEIGHT)
        end
        text:SetText(label)
        text:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    end
    Head(NAME_X, L.BEASTS_COLUMN_BEAST)
    Head(FAMILY_X, L.BEASTS_COLUMN_FAMILY)
    Head(LEVEL_X, L.BEASTS_COLUMN_LEVEL)
    Head(TEACHES_X, L.BEASTS_COLUMN_TEACHES)
    Head(-ROW_HEIGHT - 8, L.BEASTS_COLUMN_SPEED, true)
end

---Builds the panel: in `browse` two lines of filters, the count, the column heads, the rows and
---their bar; beside it the beast's card, which takes its place.
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
    panel.list = CreateFrame("Frame", nil, panel.browse)
    panel.list:SetPoint("TOPLEFT", 0, -LIST_TOP)
    panel.list:SetPoint("BOTTOMRIGHT", -16, 0)
    panel.bar = Addon.ScrollBar(panel.list, function()
        Addon:RefreshWindow("beasts")
    end)
    Heads(panel, skin)
    panel.rows = {}
    for index = 1, ROWS do
        panel.rows[index] = Row(panel, skin, index)
    end
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

---Fills a row with a beast.
---@param row AddonBeastRow
---@param npc number
local function FillRow(row, npc)
    local beast = Addon.data.beasts[npc] --[[@as AddonBeast]]
    ---@type number[]
    local spells = M.TeachesOf(npc) or NONE
    row.npc = npc
    row.name:SetText(beast.rare and L.BEASTS_RARE_NAME:format(names[npc]) or names[npc])
    row.family:SetText(Addon.FamilyName(beast.family) or "?")
    row.level:SetText(Levels(beast))
    wipe(parts)
    ---@type number?
    local first
    for _, spellID in ipairs(spells) do
        parts[#parts + 1] = Coloured(spellID)
        if not first and M.Lacking(spellID) then first = spellID end
    end
    row.teaches:SetText(table.concat(parts, ", "))
    local _, icon = Addon.SpellInfo(first or spells[1])
    row.icon:SetTexture(icon or QUESTION_MARK)
    local speed = M.AttackSpeed(npc)
    row.speed:SetText(speed and ("%.1f"):format(speed) or "")
    row.go:SetShown(beast.pins ~= nil)
    row:Show()
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

---Fills the pickers and switches from the filters.
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

---Fills the chosen beast's card, or else the filters, the count and the rows.
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
    local list = Matching(filter)
    panel.count:SetText(#list == 0 and L.BEASTS_NONE or L.BEASTS_COUNT:format(#list))
    panel.bar:SetRange(#list, ROWS)
    for index, row in ipairs(panel.rows) do
        local npc = list[index + panel.bar.offset]
        if npc then
            FillRow(row, npc)
        else
            row:Hide()
        end
    end
end

Addon:RegisterWindowTab({
    id = "beasts",
    title = L.BEASTS_TAB,
    order = 25,
    module = "BeastMap",
    Create = Create,
    Refresh = Refresh,
})
