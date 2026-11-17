local _, ns = ...

-- The Abilities tab of Huntsworn's window (Core\Window.lua): every pet ability beasts teach, with how
-- many of its ranks the hunter knows; for the chosen one every rank with its pet level, and
-- whether the hunter knows it or which beast teaches it, nearest first (BeastMap.lua's Nearest):
-- the beast's place, the travel time when a route addon gives one, and in a column of its own how
-- many more teach it. A rank's button sends the hunter there; its tooltip lists every teacher.
-- Each rank keeps to one line (a long place is cut short; the tooltip has it whole), every other
-- row striped, under column heads; the chosen ability has a bar in the look's accent. An ability
-- with a rank to learn now (above the highest known, from a beast at or below the hunter's level)
-- has a quest giver's "!" in the list; its row's tooltip names the rank known and those to learn.

---@type Addon
local Addon = ns
local L = Addon.L
local M = Addon:GetModule("BeastMap") --[[@as AddonBeastMap]]

local LIST_WIDTH, ROW_HEIGHT, LIST_ROWS = 170, 18, 21
local RANK_ROWS, RANK_HEIGHT, RANK_WIDTH, LEVEL_WIDTH, MORE_WIDTH = 15, 22, 64, 80, 30
local TOGGLE_SIZE, TEACHER_INDENT = 12, 14
local PLUS, MINUS = "Interface\\Buttons\\UI-PlusButton-Up", "Interface\\Buttons\\UI-MinusButton-Up"
local RANKS_TOP, HEADER_TOP = 46, 26
-- The pet level column, right-aligned, with room before the teacher.
local LEVEL_COLUMN = LEVEL_WIDTH - 14
local GO_ICON = "Interface\\Icons\\INV_Misc_Map_01"
local KNOWN, MISSING, DIM, ABOVE = { 0.25, 1, 0.25 }, { 1, 1, 1 }, { 0.6, 0.6, 0.6 }, { 1, 0.6, 0.3 }
local GOLD = { 1, 0.82, 0 }
local LEARN_ICON, LEARN_SIZE = "Interface\\GossipFrame\\AvailableQuestIcon", 14

-- The ranks named in an ability row's tooltip, refilled for each.
---@type string[]
local rankNames = {}

-- Per ability (its rank 1's spell ID), its rank spells in rank order; built the first time.
---@type table<number, number[]>?
local groups
-- The abilities in list order, refilled for each look.
---@type number[]
local order = {}

---Two rank spells of one ability in rank order.
---@param a number
---@param b number
---@return boolean
local function ByRank(a, b)
    local ranks = Addon.data.petAbilityRanks
    return ranks[a].rank < ranks[b].rank
end

---Per ability, its rank spells in order.
---@return table<number, number[]>
local function Groups()
    if groups then return groups end
    ---@type table<number, number[]>
    local built = {}
    local ranks = Addon.data.petAbilityRanks --[[@as table<number, AddonPetAbilityRank>]]
    for spellID, rank in pairs(ranks) do
        built[rank.ability] = built[rank.ability] or {}
        table.insert(built[rank.ability], spellID)
    end
    for _, spells in pairs(built) do
        table.sort(spells, ByRank)
    end
    groups = built
    return built
end

---An ability's name as the client words it; "?" when it cannot.
---@param ability number
---@return string
local function AbilityName(ability)
    return Addon.SpellInfo(ability) or "?"
end

---An ability's icon; the question mark when the client cannot say.
---@param ability number
---@return number|string
local function AbilityIcon(ability)
    local _, icon = Addon.SpellInfo(ability)
    return icon or 134400
end

---@param a number
---@param b number
---@return boolean
local function ByName(a, b)
    return AbilityName(a) < AbilityName(b)
end

---The abilities, by name.
---@return number[]
local function Order()
    wipe(order)
    for ability in pairs(Groups()) do
        order[#order + 1] = ability
    end
    table.sort(order, ByName)
    return order
end

---How many of an ability's ranks the hunter knows.
---@param ability number
---@return number known
---@return number total
local function Counts(ability)
    local spells = Groups()[ability]
    local known = 0
    for _, spellID in ipairs(spells) do
        if not M.Lacking(spellID) then known = known + 1 end
    end
    return known, #spells
end

---Whether the hunter can learn a rank now: above the highest it knows of the ability, and taught
---by a beast at or below the hunter's level.
---@param spellID number
---@return boolean
local function Learnable(spellID)
    if M.Lacking(spellID) ~= "above" then return false end
    local level = M:PlayerLevel()
    for _, npc in ipairs(Addon.data.petAbilityRanks[spellID].teachers) do
        local beast = Addon.data.beasts[npc] --[[@as AddonBeast?]]
        if beast and beast.minLevel <= level then return true end
    end
    return false
end

---Whether the hunter can learn any rank of an ability now.
---@param ability number
---@return boolean
local function AnyLearnable(ability)
    for _, spellID in ipairs(Groups()[ability]) do
        if Learnable(spellID) then return true end
    end
    return false
end

---An ability row's tooltip (this tab's, or the Families tab's): the highest rank known, and the
---ranks to learn now.
---@param row AddonAbilityRow|AddonFamilyAbilityRow
local function OnAbilityEnter(row)
    local ranks = Addon.data.petAbilityRanks --[[@as table<number, AddonPetAbilityRank>]]
    local highest = 0
    wipe(rankNames)
    for _, spellID in ipairs(Groups()[row.ability]) do
        local rank = ranks[spellID].rank
        if not M.Lacking(spellID) then highest = math.max(highest, rank) end
        if Learnable(spellID) then rankNames[#rankNames + 1] = L.BEASTMAP_RANK:format(rank) end
    end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetText(AbilityName(row.ability --[[@as number]]))
    local known = highest > 0 and L.BEASTMAP_RANK:format(highest) or L.BEASTMAP_ABILITY_NONE
    GameTooltip:AddLine(L.BEASTMAP_ABILITY_KNOWN:format(known), 1, 1, 1)
    if #rankNames > 0 then
        GameTooltip:AddLine(L.BEASTMAP_ABILITY_LEARN:format(table.concat(rankNames, ", ")), GOLD[1], GOLD[2], GOLD[3])
    end
    GameTooltip:Show()
end

---The text of a missing rank's row: the nearest teacher's place, its travel time, whether it is
---above the hunter's level (and so whether it is).
---@param teachers number[] in the window's order
---@return string text
---@return boolean above
local function TeacherText(teachers)
    local best = teachers[1]
    local parts = { M.Place(best) }
    local seconds = M.TravelTimeTo(best)
    if seconds then parts[#parts + 1] = L.BEASTMAP_TRAVEL:format(math.max(1, math.floor(seconds / 60 + 0.5))) end
    local above = Addon.data.beasts[best].minLevel > M:PlayerLevel()
    if above then parts[#parts + 1] = L.BEASTMAP_ABOVE end
    return table.concat(parts, ", "), above
end

---A rank's tooltip: every teacher in order, with its level.
---@param row AddonRankRow
local function OnEnter(row)
    if not row.teachers then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetText(M.RankText(row.spellID --[[@as number]]) or "?")
    for _, npc in ipairs(row.teachers) do
        local line = L.BEASTMAP_TEACHER_LINE:format(M.Place(npc), M.LevelText(Addon.data.beasts[npc]))
        GameTooltip:AddLine(line, 1, 1, 1)
    end
    GameTooltip:Show()
end

local function OnLeave()
    GameTooltip:Hide()
end

---A go button's tooltip: the beast it leads to.
---@param go Button
local function OnGoEnter(go)
    local row = go:GetParent() --[[@as AddonRankRow]]
    GameTooltip:SetOwner(go, "ANCHOR_RIGHT")
    local hunting = M:IsHunting(row.best, row.spellID)
    GameTooltip:SetText(
        (hunting and L.BEASTMAP_GO_STOP or L.BEASTMAP_GO):format(M.BeastName(row.best --[[@as number]]))
    )
    GameTooltip:Show()
end

---A text in the skin's font, on one line.
---@param parent Frame
---@param skin AddonButtonHolderSkin
---@param justify string? "LEFT" by default
---@return FontString
local function Text(parent, skin, justify)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetJustifyH(justify or "LEFT")
    text:SetWordWrap(false)
    skin.Font(text, 12)
    return text
end

---An ability's icon, cropped as the look crops icons (Huntsworn:CropIcon).
---@param parent Frame
---@param skin AddonButtonHolderSkin
---@param size number
---@return Texture
local function Icon(parent, skin, size)
    local icon = parent:CreateTexture(nil, "ARTWORK")
    icon:SetSize(size, size)
    Addon:CropIcon(icon, skin.CropIcon)
    return icon
end

---A row of the abilities' list: its icon and name, how many ranks are known, a bar when chosen.
---@param panel AddonAbilitiesPanel
---@param skin AddonButtonHolderSkin
---@param index number
---@return AddonAbilityRow
local function AbilityRow(panel, skin, index)
    local row = CreateFrame("Button", nil, panel) --[[@as AddonAbilityRow]]
    row:SetSize(LIST_WIDTH, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
    local accent = skin.Accent and skin.Accent() or GOLD
    row.selected = row:CreateTexture(nil, "BACKGROUND")
    row.selected:SetAllPoints()
    row.selected:SetColorTexture(accent[1], accent[2], accent[3], 0.2)
    row.icon = Icon(row, skin, ROW_HEIGHT - 4)
    row.icon:SetPoint("LEFT", 4, 0)
    row.label = Text(row, skin)
    row.label:SetPoint("LEFT", row.icon, "RIGHT", 5, 0)
    row.count = Text(row, skin, "RIGHT")
    row.count:SetPoint("RIGHT", -6, 0)
    row.learnable = row:CreateTexture(nil, "OVERLAY")
    row.learnable:SetSize(LEARN_SIZE, LEARN_SIZE)
    row.learnable:SetTexture(LEARN_ICON)
    row.learnable:SetPoint("RIGHT", row.count, "LEFT", -2, 0)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row:SetScript("OnClick", function()
        panel.chosen = row.ability
        Addon:RefreshWindow("abilities")
    end)
    row:SetScript("OnEnter", OnAbilityEnter)
    row:SetScript("OnLeave", OnLeave)
    return row
end

---The column heads above the ranks.
---@param panel AddonAbilitiesPanel
---@param skin AddonButtonHolderSkin
---@return AddonRankHeader
local function Header(panel, skin)
    local header = CreateFrame("Frame", nil, panel) --[[@as AddonRankHeader]]
    header:SetHeight(16)
    header:SetPoint("TOPLEFT", LIST_WIDTH + 16, -HEADER_TOP)
    header:SetPoint("RIGHT")
    ---@param x number
    ---@param label string
    ---@param justify string?
    ---@return FontString
    local function Head(x, label, justify)
        local text = Text(header, skin, justify)
        text:SetPoint("LEFT", x, 0)
        text:SetText(label)
        text:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        return text
    end
    header.rank = Head(4, L.BEASTMAP_COLUMN_RANK)
    header.level = Head(RANK_WIDTH, L.BEASTMAP_COLUMN_LEVEL, "RIGHT")
    header.level:SetWidth(LEVEL_COLUMN)
    header.text = Head(RANK_WIDTH + LEVEL_WIDTH, L.BEASTMAP_COLUMN_TEACHER)
    return header
end

---A rank's row: rank, pet level, the teacher on one line, how many more, the go button.
---@param panel AddonAbilitiesPanel
---@param skin AddonButtonHolderSkin
---@param index number
---@return AddonRankRow
local function RankRow(panel, skin, index)
    local row = CreateFrame("Button", nil, panel) --[[@as AddonRankRow]]
    row:SetHeight(RANK_HEIGHT)
    row:SetPoint("TOPLEFT", LIST_WIDTH + 16, -RANKS_TOP - (index - 1) * RANK_HEIGHT)
    row:SetPoint("RIGHT")
    row.stripe = row:CreateTexture(nil, "BACKGROUND")
    row.stripe:SetAllPoints()
    row.stripe:SetColorTexture(1, 1, 1, 0.05)
    row.stripe:SetShown(index % 2 == 0)
    row.toggle = row:CreateTexture(nil, "ARTWORK")
    row.toggle:SetSize(TOGGLE_SIZE, TOGGLE_SIZE)
    row.toggle:SetPoint("LEFT", 2, 0)
    local plus, minus
    if skin.Folds then
        plus, minus = skin.Folds()
    end
    row.plus, row.minus = plus or PLUS, minus or MINUS
    row.rank = Text(row, skin)
    row.rank:SetPoint("LEFT", TOGGLE_SIZE + 4, 0)
    row.level = Text(row, skin, "RIGHT")
    row.level:SetWidth(LEVEL_COLUMN)
    row.level:SetPoint("LEFT", RANK_WIDTH, 0)
    row.go = CreateFrame("Button", nil, row) --[[@as AddonGoButton]]
    row.go:SetSize(RANK_HEIGHT - 4, RANK_HEIGHT - 4)
    row.go:SetPoint("RIGHT", -2, 0)
    row.go.icon = row.go:CreateTexture(nil, "ARTWORK")
    row.go.icon:SetAllPoints()
    row.go.icon:SetTexture(GO_ICON)
    Addon:CropIcon(row.go.icon, skin.CropIcon)
    row.go:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    row.go.active = row.go:CreateTexture(nil, "OVERLAY")
    row.go.active:SetAllPoints()
    row.go.active:SetTexture("Interface\\Buttons\\CheckButtonHilight")
    row.go.active:SetBlendMode("ADD")
    row.go:SetScript("OnClick", function()
        if M:IsHunting(row.best, row.spellID) then
            M:StopHunt()
        else
            M:StartHunt(row.best --[[@as number]], row.spellID --[[@as number]])
        end
    end)
    row.go:SetScript("OnEnter", OnGoEnter)
    row.go:SetScript("OnLeave", OnLeave)
    row.more = Text(row, skin, "RIGHT")
    row.more:SetWidth(MORE_WIDTH)
    row.more:SetPoint("RIGHT", row.go, "LEFT", -6, 0)
    row.text = Text(row, skin)
    -- A rank with more than one teacher folds open to them all, and closed again.
    row:SetScript("OnClick", function()
        if not row.npc and row.teachers and #row.teachers > 1 then
            panel.expanded[row.spellID] = not panel.expanded[row.spellID] or nil
            Addon:RefreshWindow("abilities")
        end
    end)
    row:SetScript("OnEnter", OnEnter)
    row:SetScript("OnLeave", OnLeave)
    return row
end

---Lays out a row's text column: a teacher's sits in a little under its rank.
---@param row AddonRankRow
---@param teacher boolean
local function PlaceText(row, teacher)
    row.text:ClearAllPoints()
    row.text:SetPoint("LEFT", RANK_WIDTH + LEVEL_WIDTH + (teacher and TEACHER_INDENT or 0), 0)
    row.text:SetPoint("RIGHT", row.more, "LEFT", -4, 0)
end

---Builds the panel: the abilities' rows, the title, the column heads, the ranks' rows.
---@param panel AddonAbilitiesPanel
---@param skin AddonButtonHolderSkin
local function Create(panel, skin)
    panel.rows, panel.ranks = {}, {}
    for index = 1, LIST_ROWS do
        panel.rows[index] = AbilityRow(panel, skin, index)
    end
    panel.titleIcon = Icon(panel, skin, 20)
    panel.titleIcon:SetPoint("TOPLEFT", LIST_WIDTH + 20, 0)
    panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    panel.title:SetPoint("LEFT", panel.titleIcon, "RIGHT", 6, 0)
    skin.Font(panel.title, 16)
    panel.header = Header(panel, skin)
    panel.expanded, panel.offset, panel.lineSpells, panel.lineBeasts = {}, 0, {}, {}
    for index = 1, RANK_ROWS do
        panel.ranks[index] = RankRow(panel, skin, index)
    end
    panel:EnableMouseWheel(true)
    ---@param _ Frame
    ---@param delta number 1 up, -1 down
    panel:SetScript("OnMouseWheel", function(_, delta)
        local last = math.max(0, #panel.lineSpells - RANK_ROWS)
        panel.offset = math.min(last, math.max(0, panel.offset - delta))
        Addon:RefreshWindow("abilities")
    end)
end

---Fills one rank's row.
---@param row AddonRankRow
---@param spellID number
---@param expanded boolean? its teachers show below it
local function FillRank(row, spellID, expanded)
    local rank = Addon.data.petAbilityRanks[spellID] --[[@as AddonPetAbilityRank]]
    row.spellID, row.npc = spellID, nil
    row.rank:SetText(L.BEASTMAP_RANK:format(rank.rank))
    row.level:SetText(tostring(rank.level))
    row.more:SetText("")
    PlaceText(row, false)
    local folds = M.Lacking(spellID) ~= nil and #rank.teachers > 1
    row.toggle:SetShown(folds)
    row.toggle:SetTexture(expanded and row.minus or row.plus)
    if M.Lacking(spellID) and #rank.teachers == 0 then
        row.teachers, row.best = nil, nil
        row.text:SetText(L.BEASTMAP_NO_TEACHER)
        row.text:SetTextColor(DIM[1], DIM[2], DIM[3])
        row.go:Hide()
    elseif M.Lacking(spellID) then
        local teachers = M.Nearest(rank.teachers)
        row.teachers, row.best = teachers, teachers[1]
        local text, above = TeacherText(teachers)
        local colour = above and ABOVE or MISSING
        row.text:SetText(text)
        row.text:SetTextColor(colour[1], colour[2], colour[3])
        if #teachers > 1 then row.more:SetText(L.BEASTMAP_MORE:format(#teachers - 1)) end
        row.more:SetTextColor(DIM[1], DIM[2], DIM[3])
        row.go:SetShown(Addon.data.beasts[teachers[1]].pins ~= nil)
        row.go.active:SetShown(M:IsHunting(row.best, spellID))
    else
        row.teachers, row.best = nil, nil
        row.text:SetText(L.BEASTMAP_KNOWN)
        row.text:SetTextColor(KNOWN[1], KNOWN[2], KNOWN[3])
        row.go:Hide()
    end
    row:Show()
end

---Fills a row with one of a rank's teachers: its levels, its place and travel time, its own hunt
---button.
---@param row AddonRankRow
---@param spellID number
---@param npc number
local function FillTeacher(row, spellID, npc)
    local beast = Addon.data.beasts[npc]
    row.spellID, row.npc, row.best, row.teachers = spellID, npc, npc, nil
    row.toggle:Hide()
    row.rank:SetText("")
    local levels = beast.minLevel == beast.maxLevel and tostring(beast.minLevel)
        or ("%d-%d"):format(beast.minLevel, beast.maxLevel)
    row.level:SetText(levels)
    row.more:SetText("")
    PlaceText(row, true)
    local text = M.Place(npc)
    local seconds = M.TravelTimeTo(npc)
    if seconds then text = text .. ", " .. L.BEASTMAP_TRAVEL:format(math.max(1, math.floor(seconds / 60 + 0.5))) end
    row.text:SetText(text)
    local colour = beast.minLevel > M:PlayerLevel() and ABOVE or MISSING
    row.text:SetTextColor(colour[1], colour[2], colour[3])
    row.go:SetShown(beast.pins ~= nil)
    row.go.active:SetShown(M:IsHunting(npc, spellID))
    row:Show()
end

---The chosen ability's lines, in `panel.lineSpells` and `panel.lineBeasts`: each rank, and below
---an unfolded one each of its teachers, nearest first (lineBeasts false on a rank's line).
---@param panel AddonAbilitiesPanel
---@param spells number[]
local function Lines(panel, spells)
    local lineSpells, lineBeasts = panel.lineSpells, panel.lineBeasts
    wipe(lineSpells)
    wipe(lineBeasts)
    for _, spellID in ipairs(spells) do
        lineSpells[#lineSpells + 1], lineBeasts[#lineSpells + 1] = spellID, false
        local rank = Addon.data.petAbilityRanks[spellID]
        if panel.expanded[spellID] and M.Lacking(spellID) then
            for _, npc in ipairs(M.Nearest(rank.teachers)) do
                lineSpells[#lineSpells + 1], lineBeasts[#lineSpells + 1] = spellID, npc
            end
        end
    end
end

---Fills the list and the chosen ability's ranks.
---@param panel AddonAbilitiesPanel
local function Refresh(panel)
    if M.pickAbility then
        panel.chosen, M.pickAbility = M.pickAbility, nil
    end
    local abilities = Order()
    if not panel.chosen or not Groups()[panel.chosen] then panel.chosen = abilities[1] end
    if panel.chosen ~= panel.shownAbility then
        panel.shownAbility, panel.offset = panel.chosen, 0
        wipe(panel.expanded)
    end
    for index, row in ipairs(panel.rows) do
        local ability = abilities[index]
        row.ability = ability
        row:SetShown(ability ~= nil)
        if ability then
            local known, total = Counts(ability)
            row.label:SetText(AbilityName(ability))
            row.icon:SetTexture(AbilityIcon(ability))
            row.count:SetText(L.BEASTMAP_ABILITY_COUNT:format(known, total))
            row.learnable:SetShown(AnyLearnable(ability))
            local chosen = ability == panel.chosen
            local colour = chosen and MISSING or DIM
            row.label:SetTextColor(colour[1], colour[2], colour[3])
            local count = known == total and KNOWN or DIM
            row.count:SetTextColor(count[1], count[2], count[3])
            row.selected:SetShown(chosen)
        end
    end
    local spells = Groups()[panel.chosen] or {}
    panel.title:SetText(panel.chosen and AbilityName(panel.chosen) or "")
    panel.titleIcon:SetTexture(panel.chosen and AbilityIcon(panel.chosen))
    Lines(panel, spells)
    panel.offset = math.min(panel.offset, math.max(0, #panel.lineSpells - RANK_ROWS))
    for index, row in ipairs(panel.ranks) do
        local line = index + panel.offset
        local spellID, npc = panel.lineSpells[line], panel.lineBeasts[line]
        if npc then
            FillTeacher(row, spellID, npc)
        elseif spellID then
            FillRank(row, spellID, panel.expanded[spellID])
        else
            row:Hide()
        end
    end
end

-- For the Families tab (Families.lua): an ability's name, icon, whether a rank of it can be
-- learned now, and its tooltip, as this tab has them.
M.AbilityName, M.AbilityIcon, M.AnyLearnable, M.OnAbilityEnter = AbilityName, AbilityIcon, AnyLearnable, OnAbilityEnter

---Opens the window on this tab with `ability` chosen.
---@param ability number the spell ID of the ability's rank 1
function M:ShowAbility(ability)
    M.pickAbility = ability
    Addon:OpenWindow("abilities")
end

Addon:RegisterWindowTab({
    id = "abilities",
    title = L.BEASTMAP_TAB_ABILITIES,
    order = 20,
    module = "BeastMap",
    Create = Create,
    Refresh = Refresh,
})
