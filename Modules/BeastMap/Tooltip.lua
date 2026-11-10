local _, ns = ...

-- Lines on the game's tooltips, from the beast data; also without HandyNotes, only for a hunter.
--
-- A beast's tooltip says which pet ability ranks it teaches and how the hunter stands to each: new
-- (above the highest it knows), a lower rank it never learned, or known (Huntsworn.OnUnitTooltip);
-- the creature's NPC ID is its GUID's sixth field.
--
-- A pet ability rank's tooltip (the pet's spellbook, the pet bar, Beast Training:
-- Huntsworn.OnSpellTooltip) says the pet level it needs, with its training point cost once Beast
-- Training showed it, the families that learn it, and whether the hunter knows it; if not, the
-- nearest few beasts that teach it (BeastMap.lua's Nearest) and how many more there are.

---@type Addon
local Addon = ns
local L = Addon.L
local M = Addon:GetModule("BeastMap") --[[@as AddonBeastMap]]

local WHITE, GREY, GREEN, YELLOW = { 1, 1, 1 }, { 0.5, 0.5, 0.5 }, { 0, 1, 0 }, { 1, 1, 0 }
-- Per standing: the beast tooltip line's ending and its colour.
---@type table<string, {text: string, color: number[]}>
local STANDING = {
    above = { text = L.BEASTMAP_TOOLTIP_NEW, color = GREEN },
    gap = { text = L.BEASTMAP_TOOLTIP_GAP, color = YELLOW },
    known = { text = L.BEASTMAP_TOOLTIP_KNOWN, color = GREY },
}
-- How many beasts a pet ability's tooltip names.
local TEACHERS_SHOWN = 3
-- For a unit that teaches nothing: every hovered unit passes here.
---@type number[]
local NOTHING = {}
-- The family names on a pet ability's tooltip, refilled for each.
---@type string[]
local familyNames = {}

---Whether the game's tooltip gets the lines: the module on, the setting on, for a hunter.
---@param tooltip GameTooltip
---@param setting "tooltip"|"spellTooltip"
---@return boolean
local function Wanted(tooltip, setting)
    local _, class = UnitClass("player")
    return tooltip == GameTooltip and M:IsEnabled() and M:Settings()[setting] and class == "HUNTER"
end

---@param tooltip GameTooltip
---@param text string
---@param color number[]
local function AddLine(tooltip, text, color)
    tooltip:AddLine(text, color[1], color[2], color[3])
end

---A tameable beast's attack speed where it is not the usual 2.0: any tameable beast's from the
---data's speeds (Classic Era), else a teacher's own; nil otherwise.
---@param npc number
---@return number?
local function AttackSpeed(npc)
    local speeds, beast = Addon.data.speeds, Addon.data.beasts[npc]
    local speed = speeds and speeds[npc] or beast and beast.speed
    if speed and speed ~= 2 then return speed end
end
-- For the Beasts tab (Beasts.lua).
M.AttackSpeed = AttackSpeed

---Adds a beast's attack speed and the ranks it teaches to the game's tooltip of it.
---@param tooltip GameTooltip
---@param guid GameValue
local function OnUnitTooltip(tooltip, guid)
    if not Wanted(tooltip, "tooltip") then return end
    local npc = Addon.NPCFromGUID(guid, "Creature")
    local speed = npc and AttackSpeed(npc)
    if speed then AddLine(tooltip, L.BEASTMAP_TOOLTIP_SPEED:format(speed), WHITE) end
    ---@type number[]
    local ranks = npc and M.TeachesOf(npc) or NOTHING
    for _, spellID in ipairs(ranks) do
        local rank = M.RankText(spellID)
        if rank then
            local standing = STANDING[M.Lacking(spellID) or "known"]
            local _, icon = Addon.SpellInfo(spellID)
            local line = L.BEASTMAP_TOOLTIP_TEACHES:format(rank, standing.text)
            if icon then line = ("|T%s:0|t %s"):format(icon, line) end
            AddLine(tooltip, line, standing.color)
        end
    end
end

---"Pet level 8", with the training point cost once Beast Training showed it (every rank costs
---points: a cost of 0 is one it did not show).
---@param rank AddonPetAbilityRank
---@return string
local function LevelLine(rank)
    local name = Addon.SpellInfo(rank.ability)
    local learned = Addon:GetModule("AbilityLearned", true) --[[@as AddonAbilityLearned?]]
    local cost = name and learned and learned:TrainingCost(name, rank.rank)
    if cost and cost.cost > 0 then return L.BEASTMAP_SPELL_LEVEL_COST:format(rank.level, cost.cost) end
    return L.BEASTMAP_SPELL_LEVEL:format(rank.level)
end

---"Families: Cat, Wolf", or every family.
---@param rank AddonPetAbilityRank
---@return string
local function FamiliesLine(rank)
    wipe(familyNames)
    for _, familyID in ipairs(rank.families) do
        familyNames[#familyNames + 1] = Addon.FamilyName(familyID) or "?"
    end
    local names = #familyNames > 0 and table.concat(familyNames, ", ") or L.BEASTMAP_SPELL_ALL_FAMILIES
    return L.BEASTMAP_SPELL_FAMILIES:format(names)
end

---Adds where to learn a pet ability rank to the game's tooltip of it.
---@param tooltip GameTooltip
---@param spellID number
local function OnSpellTooltip(tooltip, spellID)
    local rank = Addon.data.petAbilityRanks[spellID] --[[@as AddonPetAbilityRank?]]
    if not rank or not Wanted(tooltip, "spellTooltip") then return end
    AddLine(tooltip, LevelLine(rank), WHITE)
    AddLine(tooltip, FamiliesLine(rank), WHITE)
    local lacking = M.Lacking(spellID)
    if not lacking then
        AddLine(tooltip, L.BEASTMAP_SPELL_KNOWN, GREY)
        return
    end
    local gap = lacking == "gap"
    AddLine(tooltip, gap and L.BEASTMAP_SPELL_SKIPPED or L.BEASTMAP_SPELL_TAME, gap and YELLOW or GREEN)
    local teachers, level = M.Nearest(rank.teachers), M:PlayerLevel()
    for i = 1, math.min(#teachers, TEACHERS_SHOWN) do
        local beast = Addon.data.beasts[teachers[i]]
        local line = L.BEASTMAP_TEACHER_LINE:format(M.Place(teachers[i]), M.LevelText(beast))
        AddLine(tooltip, line, beast.minLevel > level and GREY or WHITE)
    end
    if #teachers > TEACHERS_SHOWN then
        AddLine(tooltip, L.BEASTMAP_SPELL_MORE:format(#teachers - TEACHERS_SHOWN), GREY)
    end
end

Addon.OnUnitTooltip(OnUnitTooltip)
Addon.OnSpellTooltip(OnSpellTooltip)
