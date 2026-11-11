local _, ns = ...

-- A journal per pet, per character, kept under the pet's number (Huntsworn.PetNumber: the same
-- through renames, resummons and stable swaps); a pet tamed this session has no number until the
-- next relog and is kept under its Creature GUID, then moved to its number. It notes when and where a pet was tamed (a Tame
-- Beast cast before a new pet comes out) or first seen, its level, family and loyalty, the time
-- it was out, how often it died, the time out at which each loyalty rise came (for the forecast),
-- and the abilities in its spellbook. Options.lua shows it. Only a hunter has pets.

---@type Addon
local Addon = ns
local L = Addon.L

---@type AddonPetJournal
local M = Addon:NewModule("PetJournal")
M.title = L.PETJOURNAL_TITLE
M.description = L.PETJOURNAL_DESC
M.defaults = { profile = { tooltip = true }, char = { pets = {} } }

---The settings of the profile in use.
---@return AddonPetJournalSettings
function M:Settings()
    return self.db.profile --[[@as AddonPetJournalSettings]]
end

local BOOK_WAIT = 1 -- seconds for a new pet's spellbook to fill in
-- Deaths, tames and growth come from the core's HUNTSWORN_PET_DIED, _TAMED and _GROWTH.
local EVENTS = {
    "UNIT_PET",
    "PET_STABLE_SHOW",
    "PET_STABLE_UPDATE",
    "PLAYER_LOGOUT",
}
-- A stabled pet the stable gives no number for (Classic Era) is kept under this, its name and
-- family, until it comes out and its number is known.
local STABLE_KEY = "stable:%s|%s"

---This character's pets, by number (as a string).
---@return table<string, AddonJournalEntry>
function M:Pets()
    return self.db.char.pets --[[@as table<string, AddonJournalEntry>]]
end

---Whether a Creature GUID can be a pet of the hunter's: on WoW: Forever a fresh tame keeps one until
---the next login. On the classic clients a tamed pet's GUID is a Pet's at once; a Creature there is
---the beast a hunter taming quest lends through its Taming Rod.
---@return boolean
local function CreaturesArePets()
    return (LibStub("LibTameable-1.0") --[[@as LibTameable]]):GetClient() == "forever"
end

---The pet out's key, or nil: its number; for a pet tamed this session, which keeps the beast's
---Creature GUID until the next relog, that GUID.
---@return string?
local function Key()
    local number = Addon.PetNumber()
    if number then return tostring(number) end
    local guid = UnitGUID("pet")
    if CreaturesArePets() and Addon.NPCFromGUID(guid, "Creature") then
        return guid --[[@as string]]
    end
end

---Moves the entry of a pet tamed in an earlier session, kept under its Creature GUID, to its
---number `key` now that it has one: the newest such entry tamed as the same beast.
---@param pets table<string, AddonJournalEntry>
---@param key string
local function Adopt(pets, key)
    local npc = Addon.PetNPC()
    ---@type string?
    local found
    for other, entry in pairs(pets) do
        local fresh = other:find("^Creature%-") ~= nil and entry.first.npc == npc
        if fresh and (not found or entry.first.t > pets[found].first.t) then found = other end
    end
    if found then
        pets[key], pets[found] = pets[found], nil
    end
end

---The seconds a pet has been out, counting the current stretch.
---@param key string
---@return number
function M:Out(key)
    local entry = self:Pets()[key]
    local now = self.current == key and self.outSince and GetTime() - self.outSince or 0
    return entry.out + now
end

---The zone's name; nil while the client has none (right at login).
---@return string?
local function Zone()
    local zone = GetZoneText()
    if zone ~= "" then return zone end
end

---Notes the pet out's name, family, level and loyalty; a loyalty rise with the time out it took;
---the zone it was first seen in, when that had no name yet.
function M:Record()
    local entry = self.current and self:Pets()[self.current]
    if not entry or not UnitExists("pet") then return end
    entry.first.zone = entry.first.zone or Zone()
    entry.name = UnitName("pet") or entry.name
    entry.family = UnitCreatureFamily("pet") or entry.family
    local level = UnitLevel("pet")
    if type(level) == "number" and Addon.Readable(level) then entry.level = level end
    local _, total = Addon.PetTrainingPoints()
    local loyalty, name = Addon.PetLoyalty(total or 0, total and level or nil)
    if not loyalty then return end
    if entry.loyalty and loyalty > entry.loyalty then entry.rises[loyalty] = self:Out(self.current) end
    entry.loyalty, entry.loyaltyName = loyalty, name or entry.loyaltyName
end

---Keeps the pet out's abilities as "Claw (Rank 2)", sorted, and each one's rank by name (what it
---could still teach is worked out when shown: the hunter learns meanwhile).
function M:Snapshot()
    local entry = self.current and self:Pets()[self.current]
    if not entry or not UnitExists("pet") then return end
    wipe(entry.abilities)
    entry.ranks = entry.ranks and wipe(entry.ranks) or {}
    for name, spell in pairs(Addon.PetSpells()) do
        local rank = spell.rank or ""
        entry.abilities[#entry.abilities + 1] = rank ~= "" and ("%s (%s)"):format(name, rank) or name
        entry.ranks[name] = rank
    end
    table.sort(entry.abilities)
end

local function SnapshotLater()
    if M:IsEnabled() then M:Snapshot() end
end

---Adds the stretch out so far to the pet that was out.
function M:Close()
    if self.current and self.outSince then
        local entry = self:Pets()[self.current]
        entry.out = entry.out + GetTime() - self.outSince
    end
    self.current, self.outSince = nil, nil
end

---A pet's entry, made the first time it is seen: out, or in the stable's lists.
---@param key string
---@param npc number? the NPC ID it was tamed as, if known
---@return AddonJournalEntry
function M:Entry(key, npc)
    local pets = self:Pets()
    local entry = pets[key]
    if not entry then
        entry = {
            first = { t = GetServerTime(), zone = Zone(), npc = npc },
            out = 0,
            deaths = 0,
            rises = {},
            abilities = {},
        }
        pets[key] = entry
    end
    return entry
end

---A pet came out. One the stable showed without a number (Classic Era) moves to its number.
---@param key string
function M:Open(key)
    local pets = self:Pets()
    local stableKey = STABLE_KEY:format(UnitName("pet") or "", UnitCreatureFamily("pet") or "")
    if not pets[key] and pets[stableKey] then
        pets[key], pets[stableKey] = pets[stableKey], nil
    end
    if not pets[key] and not key:find("^Creature%-") then Adopt(pets, key) end
    self:Entry(key, Addon.PetNPC()).past = nil
    self.current, self.outSince = key, GetTime()
    self:Record()
    C_Timer.After(BOOK_WAIT, SnapshotLater)
end

-- A pet summoned, tamed, dismissed or swapped.
---@param _ string the event
---@param unit string
function M:UNIT_PET(_, unit)
    if unit ~= "player" then return end
    self:ReadStable()
    local key = Key()
    if key == self.current then
        self:Record()
        return
    end
    self:Close()
    if key then self:Open(key) end
    Addon:RefreshWindow("pets")
end

-- The keys of the pets the stable's lists name, refilled on each read.
---@type table<string, true>
local stableKeys = {}

---The journal key of a stable pet without a number (Classic Era): the pet out's when it has the
---same name and family (a released pet may share them), else the one entry of the same name and
---family, else its own under STABLE_KEY.
---@param pets table<string, AddonJournalEntry>
---@param name string
---@param family string?
---@param current string? the pet out's key
---@return string
local function NamedKey(pets, name, family, current)
    local out = current and pets[current]
    if out and out.name == name and out.family == family then
        return current --[[@as string]]
    end
    ---@type string?
    local found
    for key, entry in pairs(pets) do
        if entry.name == name and entry.family == family then
            if found then return STABLE_KEY:format(name, family or "") end
            found = key
        end
    end
    return found or STABLE_KEY:format(name, family or "")
end

---Takes what the stable's lists say of each pet: its name, level, family and loyalty, and the
---model it shows (displayID) and the beast it was tamed as (creatureID). A pet not in the journal
---yet gets an entry. Classic Era's lists give no number (NamedKey) and the loyalty as text; a
---number the client hides leaves the pet out. WoW: Forever's loyaltyLevel counts from 0 (a fresh
---tame, Rebellious, is 0 with an empty name; Unruly is 1), the journal's from 1 as the client's
---own texts do.
---@param list AddonStablePet[]
function M:ReadStableList(list)
    for _, info in ipairs(list) do
        local number = info.petNumber
        ---@type string?
        local key
        if type(number) == "number" and Addon.Readable(number) then
            key = tostring(number)
        elseif number == nil and info.name then
            key = NamedKey(self:Pets(), info.name, info.familyName, self.current)
        end
        if key and info.name then
            stableKeys[key] = true
            local entry = self:Entry(key, info.creatureID)
            entry.first.npc = info.creatureID or entry.first.npc
            entry.name, entry.level, entry.family = info.name, info.level, info.familyName
            entry.displayID = info.displayID or entry.displayID
            local level = info.loyaltyLevel and info.loyaltyLevel + 1
            local name = info.loyaltyName ~= "" and info.loyaltyName or nil
            if info.loyaltyText then
                local textLevel, textName = Addon.LoyaltyFromText(info.loyaltyText)
                level, name = level or textLevel, name or textName
            end
            entry.loyalty, entry.loyaltyName = level or entry.loyalty, name or entry.loyaltyName
        end
    end
end

---Moves what an entry the stable does not know holds into the stable's entry of the same pet: the
---time out, deaths, loyalty rises, abilities seen, the earlier first sight and a tame. The
---stable's NPC ID stays where it gave one (Classic Era's stable gives none).
---@param into AddonJournalEntry
---@param from AddonJournalEntry
local function Merge(into, from)
    into.out, into.deaths = into.out + from.out, into.deaths + from.deaths
    for level, at in pairs(from.rises) do
        into.rises[level] = into.rises[level] or at
    end
    if #into.abilities == 0 then
        into.abilities, into.ranks = from.abilities, from.ranks
    end
    if from.first.t < into.first.t then
        into.first.t, into.first.zone = from.first.t, from.first.zone or into.first.zone
    end
    into.first.tamed = into.first.tamed or from.first.tamed
    into.first.npc = into.first.npc or from.first.npc
end

---The one stable pet with this name and family; nil for none or several.
---@param pets table<string, AddonJournalEntry>
---@param entry AddonJournalEntry
---@return string?
local function StableTwin(pets, entry)
    ---@type string?
    local found
    for key in pairs(stableKeys) do
        local other = pets[key]
        if other.name == entry.name and other.family == entry.family then
            if found then return nil end
            found = key
        end
    end
    return found
end

---Reads the stable's lists (Huntsworn.C.StableInfo: WoW: Forever gives them anywhere, Classic Era
---while the stable master is open), then merges an entry they do not know (kept under the GUID's
---number, which is not the pet's on Forever) into the stable's entry of the same name and family.
---A pet tamed this session (a Creature GUID key) waits for Adopt, and a past pet is never merged:
---a new pet may carry a released one's name. A pet neither in the lists nor out is one the hunter
---no longer has (released, or lost): it is marked past, until it is seen again; so is a pet tamed
---this session once it is not out (Adopt still finds it after a relog). On the classic clients an
---entry under a Creature GUID, a taming quest's beast kept before the journal left those out, goes.
---So does an entry without a name that is not out: on WoW: Forever the pet is "Hunter Pet" (165189)
---for a few seconds after a tame, unnamed and not in the stable, under its GUID's number.
function M:ReadStable()
    local stable = Addon.C.StableInfo
    wipe(stableKeys)
    self:ReadStableList(stable.GetActivePetList())
    self:ReadStableList(stable.GetStabledPetList())
    local pets = self:Pets()
    for key, entry in pairs(pets) do
        local twin = not stableKeys[key] and not entry.past and not key:find("^Creature%-") and StableTwin(pets, entry)
        if twin then
            Merge(pets[twin], entry)
            pets[key] = nil
            if self.current == key then self.current = twin end
        end
    end
    local creatures = CreaturesArePets()
    for key, entry in pairs(pets) do
        local creature = key:find("^Creature%-") ~= nil
        local out = key == self.current
        local fleeting = not entry.name and not entry.first.tamed and not out and not stableKeys[key]
        if (creature and not creatures) or fleeting then
            pets[key] = nil
        else
            entry.past = not (stableKeys[key] or out) or nil
        end
    end
end

-- The stable master opened, or the stable's lists changed: what they say goes into the journal.
function M:PET_STABLE_UPDATE()
    self:ReadStable()
    Addon:RefreshWindow("pets")
end
M.PET_STABLE_SHOW = M.PET_STABLE_UPDATE

-- The core's HUNTSWORN_PET_GROWTH: the pet's level, points or loyalty changed.
function M:OnGrowth()
    self:Record()
    Addon:RefreshWindow("pets")
end

-- The core's HUNTSWORN_PET_DIED: the pet out died.
function M:OnDied()
    if not self.current then return end
    local entry = self:Pets()[self.current]
    entry.deaths = entry.deaths + 1
end

---The core's HUNTSWORN_PET_TAMED. It may come before or after this module sees the pet come out,
---so it makes the entry if need be.
---@param _ string the message
---@param event AddonPetTamedEvent
function M:OnTamed(_, event)
    -- Freshly tamed, the pet has no number yet: it goes under its Creature GUID (Key).
    local key = event.petNumber and tostring(event.petNumber) or Key()
    if key then self:Entry(key, Addon.PetNPC()).first.tamed = true end
end

function M:PLAYER_LOGOUT()
    self:Close()
end

function M:OnEnable()
    self.current, self.outSince = nil, nil
    local _, class = UnitClass("player")
    if class ~= "HUNTER" then return end
    Addon.RegisterEvents(self, EVENTS)
    Addon:Listen(self, Addon.messages.petDied, "OnDied")
    Addon:Listen(self, Addon.messages.petTamed, "OnTamed")
    Addon:Listen(self, Addon.messages.petGrowth, "OnGrowth")
    self:UNIT_PET("UNIT_PET", "player")
end

function M:OnDisable()
    Addon:StopListening(self)
    self:Close()
end
