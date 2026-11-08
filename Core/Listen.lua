local _, ns = ...

-- Huntsworn:Listen, and the core's sources: messages about the pet out that the core works out from
-- game events (HUNTSWORN_PET_HAPPINESS, _STATE, _DIED, _TAMED, _GROWTH). One source serves every
-- listener, Huntsworn's own modules and other addons alike, and watches the game only while at least
-- one listens through Listen. A message a module sends itself needs no source; Listen hands it on
-- just the same (docs\04-hooking.md).

---@type Addon
local Addon = ns

local TAME_BEAST = Addon.TAME_BEAST

-- Per message, who listens through Listen.
---@type table<string, table<table, true>>
local listeners = {}

-- Per message, the source that sends it: a table with the game events it watches, a method of the
-- same name for each, and Start, which takes stock when it begins to watch.
---@type table<string, AddonSource>
local sources = {}

---Starts the message's source when it has a listener and is not running, stops it when it has none.
---@param message string
local function Follow(message)
    local source = sources[message]
    if not source then return end
    local owners = listeners[message]
    local wanted = owners ~= nil and next(owners) ~= nil
    if wanted == source.running then return end
    source.running = wanted
    if wanted then
        -- Not every client has every event; a missing one is skipped.
        Addon.RegisterEvents(source, source.events)
        source:Start()
    else
        Addon.UnregisterAllEvents(source)
    end
end

---Listens to a Huntsworn message: `handler` gets the message's name and its table. The owner is any
---table, the key StopListening takes; asking again for the same message replaces the handler.
---@param owner table
---@param message string
---@param handler string|function a method of the owner, or a function
function Addon:Listen(owner, message, handler)
    Addon.RegisterMessage(owner, message, handler)
    listeners[message] = listeners[message] or {}
    listeners[message][owner] = true
    Follow(message)
end

---Stops listening to one message, or to every message the owner listens to.
---@param owner table
---@param message string?
function Addon:StopListening(owner, message)
    for name, owners in pairs(listeners) do
        if owners[owner] and (message == nil or message == name) then
            Addon.UnregisterMessage(owner, name)
            owners[owner] = nil
            Follow(name)
        end
    end
end

-- HUNTSWORN_PET_HAPPINESS: the pet out's happiness changed; before is nil for a pet just out.
---@type AddonSource
local happiness = { events = { "UNIT_HAPPINESS", "PET_UI_UPDATE", "UNIT_PET" } }
sources[Addon.messages.petHappiness] = happiness

function happiness:Start()
    self.guid, self.last = nil, nil
    self:Read(true)
end

---Reads the happiness and says when it changed; at the start (`quiet`) it only takes note.
---@param quiet boolean?
function happiness:Read(quiet)
    if not UnitExists("pet") then
        self.key, self.last = nil, nil
        return
    end
    local now = Addon.PetHappiness()
    if not now then return end
    local key = Addon.PetKey()
    local before = key ~= nil and key == self.key and self.last or nil
    self.key, self.last = key, now
    if now ~= before and not quiet then
        Addon:SendMessage(Addon.messages.petHappiness, { happiness = now, before = before })
    end
end

---@param _ string the event
---@param unit string
function happiness:UNIT_HAPPINESS(_, unit)
    if unit == "pet" then self:Read() end
end

function happiness:PET_UI_UPDATE()
    self:Read()
end

---@param _ string the event
---@param unit string
function happiness:UNIT_PET(_, unit)
    if unit == "player" then self:Read() end
end

---Whether the pet out is dead; false without a pet.
---@return boolean
local function PetDead()
    return UnitExists("pet") and UnitIsDead("pet") == true
end

---The pet out's state, shared by every button about the pet: alive, dead (its body still out), or
---none.
---@return "alive"|"dead"|"none"
function Addon.PetState()
    if not UnitExists("pet") then return "none" end
    return PetDead() and "dead" or "alive"
end

-- HUNTSWORN_PET_STATE: the pet out became alive, dead or none; before is what it was.
---@type AddonSource
local state = { events = { "UNIT_HEALTH", "UNIT_PET" } }
sources[Addon.messages.petState] = state

function state:Start()
    self.state = Addon.PetState()
end

---Sends the message when the state changed.
function state:Check()
    local now = Addon.PetState()
    if now == self.state then return end
    Addon:SendMessage(Addon.messages.petState, { state = now, before = self.state })
    self.state = now
end

---@param _ string the event
---@param unit string
function state:UNIT_HEALTH(_, unit)
    if unit == "pet" then self:Check() end
end

---@param _ string the event
---@param unit string
function state:UNIT_PET(_, unit)
    if unit == "player" then self:Check() end
end

-- HUNTSWORN_PET_DIED: the pet out died, seen going from alive to dead.
---@type AddonSource
local death = { events = { "UNIT_HEALTH", "UNIT_PET" } }
sources[Addon.messages.petDied] = death

function death:Start()
    self.dead = PetDead()
end

---@param _ string the event
---@param unit string
function death:UNIT_HEALTH(_, unit)
    if unit ~= "pet" then return end
    local dead = PetDead()
    if dead and not self.dead then Addon:SendMessage(Addon.messages.petDied, { pet = UnitName("pet") }) end
    self.dead = dead
end

-- Another pet out (or none): a pet summoned dead was not seen dying.
---@param _ string the event
---@param unit string
function death:UNIT_PET(_, unit)
    if unit == "player" then self.dead = PetDead() end
end

-- HUNTSWORN_PET_GROWTH: the pet out's training points total, level or loyalty level changed since it
-- was last seen, kept per pet name in HuntswornDB (char.growth), so a pet summoned again, or the pet
-- after a relog, tells what changed while away. A pet seen the first time is only noted, and so is a
-- pet just tamed, whatever an earlier pet of the same name left behind. Not before
-- the session's first UNIT_PET: until then the client may not have the pet's values (Classic Era
-- sends it 8 seconds after a /reload, the values complete). Spending points changes only what is
-- free, not the total: no growth.
local SUMMON_WAIT = 1 -- seconds for a new pet's values to fill in

---Sets Addon.petArrived at the session's first UNIT_PET, whether anyone listens yet or not.
---@param _ Frame
---@param _event string
---@param unit string
local function OnArrival(_, _event, unit)
    if unit == "player" then Addon.petArrived = true end
end
local arrival = CreateFrame("Frame")
arrival:RegisterEvent("UNIT_PET")
arrival:SetScript("OnEvent", OnArrival)

---@type AddonSource
local growth = {
    events = { "UNIT_PET_TRAINING_POINTS", "PET_UI_UPDATE", "UNIT_LEVEL", "UNIT_PET", "UNIT_SPELLCAST_SUCCEEDED" },
}
sources[Addon.messages.petGrowth] = growth

local function CheckGrowthLater()
    growth.pending = false
    if growth.running then growth:Check() end
end

---Checks after `delay` seconds, once however often asked meanwhile.
---@param delay number
function growth:CheckAfter(delay)
    if self.pending then return end
    self.pending = true
    C_Timer.After(delay, CheckGrowthLater)
end

-- Takes stock at once when the pet's first UNIT_PET has come; else UNIT_PET will.
function growth:Start()
    self.pending = false
    self:Check()
end

---Compares the pet out with how it stood last time and sends what changed.
function growth:Check()
    if self.pending or not Addon.petArrived then return end
    local free, total = Addon.PetTrainingPoints()
    if not total then return end
    -- Right after a /reload a classic client may give no loyalty yet and the points as 0, which
    -- would read as loyalty 1: a fall now and a rise once the values come in. Where the client has
    -- loyalty, nothing counts until it gives one; a later event checks again.
    local given = Addon.C.PetInfo.GetPetLoyalty()
    local none = given == nil or (Addon.Readable(given) and given == "")
    if none and Addon.C.Has("PetInfo", "GetPetLoyalty") then return end
    local pet, level = UnitName("pet"), UnitLevel("pet")
    local loyalty, loyaltyName = Addon.PetLoyalty(total, level)
    local pets = Addon.db.char.growth --[[@as table<string, AddonGrowthSeen>]]
    local seen = pets[pet]
    -- A tamed pet may carry the name of one released before it: it starts afresh.
    if not seen or self.tamed then
        self.tamed = false
        pets[pet] = { total = total, level = level, loyalty = loyalty }
        return
    end
    if total == seen.total and level == seen.level and loyalty == seen.loyalty then return end
    local before = { level = seen.level, loyalty = seen.loyalty, points = seen.total }
    seen.total, seen.level, seen.loyalty = total, level, loyalty
    Addon:SendMessage(Addon.messages.petGrowth, {
        pet = pet,
        level = level,
        loyalty = loyalty,
        loyaltyName = loyaltyName,
        points = total,
        free = free,
        before = before,
    })
end

---@param _ string the event
---@param unit string
function growth:UNIT_PET_TRAINING_POINTS(_, unit)
    if unit == "pet" then self:Check() end
end
growth.UNIT_LEVEL = growth.UNIT_PET_TRAINING_POINTS

function growth:PET_UI_UPDATE()
    self:Check()
end

---@param _ string the event
---@param unit string
function growth:UNIT_PET(_, unit)
    if unit == "player" then self:CheckAfter(SUMMON_WAIT) end
end

-- Tame Beast needs the pet away, so the next pet the check reads is the tamed one.
---@param _ string the event
---@param unit string
---@param _castGUID GameValue
---@param spellID GameValue
function growth:UNIT_SPELLCAST_SUCCEEDED(_, unit, _castGUID, spellID)
    if unit == "player" and Addon.Readable(spellID) and spellID == TAME_BEAST then self.tamed = true end
end

-- HUNTSWORN_PET_TAMED: the pet that came out after a Tame Beast cast. It has no pet number until the
-- next relog (its GUID is still the beast's), so petNumber is nil then.
---@type AddonSource
local tame = { events = { "UNIT_SPELLCAST_SUCCEEDED", "UNIT_PET" } }
sources[Addon.messages.petTamed] = tame

function tame:Start()
    self.taming = false
end

---@param _ string the event
---@param unit string
---@param _castGUID GameValue
---@param spellID GameValue
function tame:UNIT_SPELLCAST_SUCCEEDED(_, unit, _castGUID, spellID)
    if unit == "player" and Addon.Readable(spellID) and spellID == TAME_BEAST then self.taming = true end
end

---@param _ string the event
---@param unit string
function tame:UNIT_PET(_, unit)
    if unit ~= "player" or not self.taming or not UnitExists("pet") then return end
    self.taming = false
    Addon:SendMessage(
        Addon.messages.petTamed,
        { pet = UnitName("pet"), npc = Addon.PetNPC(), petNumber = Addon.PetNumber() }
    )
end
