local _, ns = ...

-- A pet family's ID, name and specialization, from Huntsworn.familyInfo (Constants\Families.lua) and
-- the client.

---@type Addon
local Addon = ns
local L = Addon.L
local S = Addon.petSpecs
local SPEC_NAMES =
    { [S.ferocity] = L.FAMILY_FEROCITY, [S.cunning] = L.FAMILY_CUNNING, [S.tenacity] = L.FAMILY_TENACITY }
local K = Addon.petCategories
local CATEGORY_NAMES =
    { [K.offense] = L.FAMILY_OFFENSE, [K.defense] = L.FAMILY_DEFENSE, [K.general] = L.FAMILY_GENERAL }
-- A family's modifiers in words, refilled for each one.
---@type string[]
local parts = {}

---A family's category and modifiers before Wrath (Huntsworn.familyMods): "Offense: +10% damage, -2%
---health", damage first; the category alone for a family without modifiers; nil for one Huntsworn has
---none for.
---@param familyID number?
---@return string?
function Addon.FamilyModsText(familyID)
    local mods = familyID and Addon.familyMods[familyID]
    if not mods then return nil end
    wipe(parts)
    if mods.damage ~= 0 then parts[#parts + 1] = L.FAMILY_DAMAGE:format(mods.damage) end
    if mods.health ~= 0 then parts[#parts + 1] = L.FAMILY_HEALTH:format(mods.health) end
    if mods.armor ~= 0 then parts[#parts + 1] = L.FAMILY_ARMOR:format(mods.armor) end
    local category = CATEGORY_NAMES[mods.category]
    if #parts == 0 then return category end
    return L.FAMILY_MODS:format(category, table.concat(parts, ", "))
end

-- Each food type's name, by its Huntsworn.diets value.
local FOOD_NAMES = {
    meat = L.FAMILY_FOOD_MEAT,
    fish = L.FAMILY_FOOD_FISH,
    cheese = L.FAMILY_FOOD_CHEESE,
    bread = L.FAMILY_FOOD_BREAD,
    fungus = L.FAMILY_FOOD_FUNGUS,
    fruit = L.FAMILY_FOOD_FRUIT,
    rawFish = L.FAMILY_FOOD_RAWFISH,
}

---A food type's name, by its Huntsworn.diets value.
---@param food string
---@return string
function Addon.FoodName(food)
    return FOOD_NAMES[food] --[[@as string]]
end

---What a family eats: "Eats: Meat, Fish"; nil for a family Huntsworn knows no diet of.
---@param familyID number?
---@return string?
function Addon.DietText(familyID)
    local info = familyID and Addon.familyInfo[familyID]
    if not info or not info.diet then return nil end
    wipe(parts)
    for _, food in ipairs(info.diet) do
        parts[#parts + 1] = FOOD_NAMES[food]
    end
    return L.FAMILY_EATS:format(table.concat(parts, ", "))
end

---A family's ID from its name as Huntsworn.FamilyName gives it (a pet's UnitCreatureFamily, a stable
---list's familyName); nil for a name Huntsworn does not know.
---@param name string?
---@return number?
function Addon.FamilyID(name)
    if not name then return nil end
    for familyID in pairs(Addon.familyInfo) do
        if Addon.FamilyName(familyID) == name then return familyID end
    end
end

---A family's line on a card: before Wrath (Classic Era, Burning Crusade) its category and
---modifiers, from Wrath on (WoW: Forever, and the clients LibTameable has no data for) its
---specialization; "" without either.
---@param familyID number?
---@return string
function Addon.FamilyLine(familyID)
    local client = (LibStub("LibTameable-1.0") --[[@as LibTameable]]):GetClient()
    if client == "era" or client == "tbc" then return Addon.FamilyModsText(familyID) or "" end
    return Addon.SpecName(familyID) or ""
end

-- Before Wrath a category stands for the specialization that took its place: the damage pets,
-- the tanks, the rest.
local ROLE_OF_CATEGORY = { [K.offense] = S.ferocity, [K.defense] = S.tenacity, [K.general] = S.cunning }

---A family's role, a Huntsworn.petSpecs value: before Wrath (Classic Era, Burning Crusade) from its
---category (Offense as Ferocity, Defense as Tenacity, General as Cunning), from Wrath on its
---specialization; nil without either.
---@param familyID number
---@return string?
function Addon.FamilyRole(familyID)
    local client = (LibStub("LibTameable-1.0") --[[@as LibTameable]]):GetClient()
    if client == "era" or client == "tbc" then
        local mods = Addon.familyMods[familyID]
        return mods and ROLE_OF_CATEGORY[mods.category]
    end
    local info = Addon.familyInfo[familyID]
    return info and info.spec
end

local CATEGORY_OF_ROLE = { [S.ferocity] = K.offense, [S.tenacity] = K.defense, [S.cunning] = K.general }

---A role's name: Ferocity, Cunning or Tenacity; with `asCategory` the category it stands for
---before Wrath: Offense, General or Defense.
---@param role string a Huntsworn.petSpecs value
---@param asCategory boolean?
---@return string
function Addon.RoleName(role, asCategory)
    if asCategory then return CATEGORY_NAMES[CATEGORY_OF_ROLE[role]] end
    return SPEC_NAMES[role]
end

---A family's specialization, named: Ferocity, Cunning or Tenacity, as Wowhead sorts the families
---(the client says "Default" for every pet); nil without one.
---@param familyID number?
---@return string?
function Addon.SpecName(familyID)
    local info = familyID and Addon.familyInfo[familyID]
    return info and info.spec and SPEC_NAMES[info.spec]
end

---A family's name as the client words it, else the English one; nil for a family Huntsworn does not
---know.
---@param familyID number
---@return string?
function Addon.FamilyName(familyID)
    local info = C_CreatureInfo and C_CreatureInfo.GetCreatureFamilyInfo(familyID)
    if info and info.name then return info.name end
    local known = Addon.familyInfo[familyID]
    return known and known.name
end

---A family's portrait as the client gives it; the question mark when it gives none.
---@param familyID number
---@return number|string
function Addon.FamilyIcon(familyID)
    local info = C_CreatureInfo and C_CreatureInfo.GetCreatureFamilyInfo(familyID)
    return info and info.iconFile or 134400
end
