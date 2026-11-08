-- Huntsworn:Listen and the core's sources: messages about the pet out (happiness, a death, a tame)
-- that the core works out from game events, for its own modules and for other addons alike. A
-- source watches the game only while something listens to its message through Huntsworn:Listen.

local TAME_BEAST = 1515

---Whether any frame has `event` registered.
---@param client table
---@param event string
---@return boolean
local function watched(client, event)
    for _, frame in ipairs(client.frames) do
        if frame.events[event] then return true end
    end
    return false
end

---A client with every module off: only what a spec listens to runs.
---@return table
local function bare()
    local client = NewClient():login()
    for name in pairs(client.Addon.modules) do
        client.Addon:SetModuleOn(name, false)
    end
    return client
end

---Listens to `message` as another addon would, keeping what it hears.
---@param client table
---@param message string
---@return table owner, table[] heard
local function listen(client, message)
    local owner, heard = {}, {}
    client.Addon:Listen(owner, message, function(_, event)
        heard[#heard + 1] = event
    end)
    return owner, heard
end

describe("Huntsworn:Listen", function()
    it("watches the game for a core message only while something listens", function()
        local client = bare()
        assert.is_false(watched(client, "UNIT_HAPPINESS"))
        local owner = listen(client, "HUNTSWORN_PET_HAPPINESS")
        assert.is_true(watched(client, "UNIT_HAPPINESS"))
        local other = listen(client, "HUNTSWORN_PET_HAPPINESS")
        client.Addon:StopListening(owner)
        assert.is_true(watched(client, "UNIT_HAPPINESS"), "one still listens")
        client.Addon:StopListening(other, "HUNTSWORN_PET_HAPPINESS")
        assert.is_false(watched(client, "UNIT_HAPPINESS"))
    end)

    it("hands a module's own message on as well, with no source to start", function()
        local client = bare()
        local owner, heard = listen(client, "HUNTSWORN_PRINT")
        client.Addon:Print("hello")
        assert.are.same({ { line = "hello" } }, heard)
        client.Addon:StopListening(owner)
        client.Addon:Print("again")
        assert.are.equal(1, #heard)
    end)

    it("counts a listener once, however often it asks", function()
        local client = bare()
        local owner, heard = listen(client, "HUNTSWORN_PET_HAPPINESS")
        client.Addon:Listen(owner, "HUNTSWORN_PET_HAPPINESS", function(_, event)
            heard[#heard + 1] = event
        end)
        client:setHappiness(2)
        assert.are.equal(1, #heard, "the second handler replaced the first")
        client.Addon:StopListening(owner)
        assert.is_false(watched(client, "UNIT_HAPPINESS"))
    end)

    it("is stopped for a module when it is switched off", function()
        local client = NewClient():login()
        assert.is_true(watched(client, "UNIT_HAPPINESS"), "Feeding and the broker listen")
        client.Addon:SetModuleOn("Feeding", false)
        client.Addon:SetModuleOn("Broker", false)
        assert.is_false(watched(client, "UNIT_HAPPINESS"))
    end)
end)

describe("HUNTSWORN_PET_HAPPINESS", function()
    it("says when the pet's happiness changes, with what it was", function()
        local client = bare()
        local _, heard = listen(client, "HUNTSWORN_PET_HAPPINESS")
        client:setHappiness(3)
        assert.are.same({}, heard, "no change from the reading at the start")
        client:setHappiness(2):setHappiness(2):setHappiness(1)
        assert.are.same({ { happiness = 2, before = 3 }, { happiness = 1, before = 2 } }, heard)
    end)

    it("knows the pet again through a new GUID, as each summon or revive gives it", function()
        local client = bare()
        local _, heard = listen(client, "HUNTSWORN_PET_HAPPINESS")
        client.petGUID = "Pet-0-5250-0-1-165189-02002ED5F4" -- the pet number stays 0x002ED5F4
        client.happiness = 2
        client:fire("UNIT_PET", "player")
        assert.are.same({ { happiness = 2, before = 3 } }, heard)
    end)

    it("has no before for a pet just summoned, and says nothing without a pet", function()
        local client = bare()
        local _, heard = listen(client, "HUNTSWORN_PET_HAPPINESS")
        client:petGone()
        client:fire("UNIT_PET", "player")
        client.happiness = nil
        client:fire("PET_UI_UPDATE")
        assert.are.same({}, heard)
        client.happiness = 2
        client:summon("Shadow", {})
        assert.are.same({ { happiness = 2 } }, heard)
    end)
end)

describe("HUNTSWORN_PET_GROWTH", function()
    ---A client past the login wait, with every module off, hearing the message.
    local function growing(opts)
        local client = NewClient(opts):login()
        for name in pairs(client.Addon.modules) do
            client.Addon:SetModuleOn(name, false)
        end
        local _, heard = listen(client, "HUNTSWORN_PET_GROWTH")
        client:advance(5)
        return client, heard
    end

    it("says what changed of the pet's points, level and loyalty, and what it was", function()
        local client, heard = growing()
        client:petLevelUp(4)
        assert.are.same({
            {
                pet = "Fluffy",
                level = 16,
                loyalty = 4,
                loyaltyName = "Dependable",
                points = 54,
                free = 47,
                before = { level = 15, loyalty = 4, points = 50 },
            },
        }, heard)
        client:fire("UNIT_PET_TRAINING_POINTS", "pet")
        assert.are.equal(1, #heard, "nothing changed")
    end)

    it("notes a pet the first time, and tells one summoned again what changed while away", function()
        local client, heard = growing()
        client.trainingPoints = { 10, 0 }
        client:summon("Shadow", {}):advance(1)
        assert.are.same({}, heard, "first time Huntsworn sees Shadow")
        client.trainingPoints = { 14, 0 }
        client:summon("Shadow", {}):advance(1)
        assert.are.equal(14, heard[1].points)
    end)

    it("starts afresh for a tamed pet that has the name of one before it", function()
        local client, heard = growing()
        client:petGone()
        client:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", TAME_BEAST)
        client.trainingPoints, client.loyalty = { 0, 0 }, "Loyalty Level 1 (Rebellious)"
        client:summon("Fluffy", {}):advance(1)
        assert.are.same({}, heard, "a new pet: no loyalty drop, no lost points")
        client:petLevelUp(4)
        assert.are.equal(0, heard[1].before.points, "from the new pet's stand")
    end)

    it("waits for the pet's first UNIT_PET after login, then tells what changed since the last session", function()
        local client = NewClient():login():advance(1)
        client:logout()
        -- The client's UNIT_PET comes some seconds after login (8 on Classic Era after a /reload).
        client = NewClient({ saved = Saved(), petLate = true })
        client.trainingPoints = { 52, 7 }
        client:login()
        local _, heard = listen(client, "HUNTSWORN_PET_GROWTH")
        client:fire("UNIT_PET_TRAINING_POINTS", "pet"):advance(10)
        assert.are.same({}, heard, "not before the pet's first UNIT_PET, however long")
        client:fire("UNIT_PET", "player"):advance(1)
        assert.are.equal(52, heard[1].points)
    end)

    it("waits while the client has the pet's points as 0 and no loyalty text yet, as after a reload", function()
        local client = NewClient():login():advance(5)
        client:logout()
        client = NewClient({ saved = Saved() })
        -- Right after a /reload on Classic Era: no loyalty text, the points not in yet.
        client.trainingPoints, client.loyalty = { 0, 0 }, nil
        client:login()
        local _, heard = listen(client, "HUNTSWORN_PET_GROWTH")
        client:advance(5)
        assert.are.same({}, heard, "no fall to loyalty 1")
        client.trainingPoints, client.loyalty = { 50, 7 }, "Loyalty Level 4 (Dependable)"
        client:fire("UNIT_PET_TRAINING_POINTS", "pet")
        assert.are.same({}, heard, "the values it had: nothing changed, no rise either")
    end)

    it("takes stock at once for a listener that comes after the login wait", function()
        local client = bare()
        client:advance(10)
        local _, heard = listen(client, "HUNTSWORN_PET_GROWTH")
        client:petLevelUp(4)
        assert.are.equal(16, heard[1].level)
    end)

    it("says nothing on a client without training points", function()
        local client, heard = growing({ noTrainingAPI = true })
        client:petLevelUp(4)
        assert.are.same({}, heard)
    end)
end)

describe("HUNTSWORN_PET_DIED", function()
    it("says once when the pet out dies", function()
        local client = bare()
        local _, heard = listen(client, "HUNTSWORN_PET_DIED")
        client:petDies():fire("UNIT_HEALTH", "pet")
        assert.are.same({ { pet = "Fluffy" } }, heard)
        client:petBack():petDies()
        assert.are.equal(2, #heard)
        client:fire("UNIT_HEALTH", "target")
        assert.are.equal(2, #heard)
    end)

    it("does not take a pet summoned dead for a death", function()
        local client = bare()
        client:petGone()
        local _, heard = listen(client, "HUNTSWORN_PET_DIED")
        client:summon("Shadow", {})
        client.pet.dead = true
        client:fire("UNIT_PET", "player"):fire("UNIT_HEALTH", "pet")
        assert.are.same({}, heard)
    end)
end)

describe("HUNTSWORN_PET_STATE", function()
    it("says when the pet out dies, comes back or goes, with what it was before", function()
        local client = bare()
        assert.are.equal("alive", client.Addon.PetState())
        local _, heard = listen(client, "HUNTSWORN_PET_STATE")
        client:petDies()
        assert.are.equal("dead", client.Addon.PetState())
        client:fire("UNIT_HEALTH", "pet"):fire("UNIT_HEALTH", "target")
        client:petBack()
        client:petGone():fire("UNIT_PET", "player")
        assert.are.same({
            { state = "dead", before = "alive" },
            { state = "alive", before = "dead" },
            { state = "none", before = "alive" },
        }, heard)
        assert.are.equal("none", client.Addon.PetState())
    end)
end)

describe("HUNTSWORN_PET_TAMED", function()
    it("names the pet a Tame Beast cast brought, and the beast it was", function()
        local client = NewClient({ noPet = true }):login()
        local _, heard = listen(client, "HUNTSWORN_PET_TAMED")
        client:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", TAME_BEAST)
        client.petGUID = "Pet-0-5250-0-1-3825-0100ABCDEF"
        client:summon("Whiskers", {})
        assert.are.same({ { pet = "Whiskers", npc = 3825, petNumber = 0xABCDEF } }, heard)
        client:petGone():summon("Shadow", {})
        assert.are.equal(1, #heard, "an ordinary summon")
    end)

    it("leaves other spells, other units and hidden spell IDs alone", function()
        local client = NewClient({ noPet = true }):login()
        local _, heard = listen(client, "HUNTSWORN_PET_TAMED")
        client:fire("UNIT_SPELLCAST_SUCCEEDED", "party1", "Cast-1", TAME_BEAST)
        client:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-2", 883)
        client:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3", SECRET)
        client:summon("Shadow", {})
        assert.are.same({}, heard)
    end)
end)
