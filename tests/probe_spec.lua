-- The Dev Probe (Modules\DevProbe): a module only in a copy straight from the repository, off until
-- switched on, that keeps in HuntswornDB what Huntsworn cannot know from the API documentation: what the
-- stable's lists hold, when and how a pet gets a new spell, what each family eats, the client's
-- family names, a lower rank learned after a higher one, and the pet's GUID around a tame.

local TAME_BEAST = 1515

---A development copy with the probe switched on.
---@param opts TestClientOptions?
---@return table client
---@return table probe its saved findings (db.global)
local function probing(opts)
    opts = opts or {}
    opts.dev = true
    local client = NewClient(opts):login()
    assert.is_false(client.Addon:GetModule("DevProbe"):IsEnabled(), "off until switched on")
    client.Addon:SetModuleOn("DevProbe", true)
    return client, client.Addon:GetModule("DevProbe").db.global
end

describe("the Dev Probe", function()
    it("is not there in a release", function()
        assert.is_nil(NewClient():login().Addon:GetModule("DevProbe", true))
    end)

    it("keeps what the stable's lists say of each pet", function()
        local client, probe = probing()
        client.stable.stabled = {
            {
                petNumber = 77,
                name = "Shadow",
                familyName = "Wolf",
                specialization = "Default",
                petAbilities = { 17253 },
            },
        }
        client:fire("PET_STABLE_UPDATE")
        local shadow = probe.stable["77"]
        assert.are.equal("Shadow", shadow.name)
        assert.are.equal("Default", shadow.specialization)
        assert.are.same({ 17253 }, shadow.petAbilities)
    end)

    it("notes a spell the pet gets, with its level and how it came", function()
        local client, probe = probing()
        client:advance(1)
        table.insert(client.petBook, { CLAW_3 })
        client:petLevelUp(4)
        client:fire("UNIT_LEVEL", "pet"):fire("PET_BAR_UPDATE")
        local gained = probe.petSpells[#probe.petSpells]
        assert.are.equal("Claw", gained.spell)
        assert.are.equal("Rank 3", gained.rank)
        assert.are.equal("Rank 2", gained.before)
        assert.are.equal(16, gained.level)
        assert.are.equal(2, gained.family)
        assert.are.equal("level", gained.how)
        client:fire("PET_BAR_UPDATE")
        assert.are.equal(1, #probe.petSpells, "once")
    end)

    it("notes a spell that comes while the trainer window is open", function()
        local client, probe = probing()
        client:advance(5)
        client:openTrainer({})
        table.insert(client.petBook, { CLAW_3 })
        client:fire("TRAINER_UPDATE")
        assert.are.equal("training", probe.petSpells[#probe.petSpells].how)
    end)

    it("keeps the last 200 of a list, and stops when switched off", function()
        local client, probe = probing()
        for i = 1, 200 do
            probe.guids[i] = { event = "old", guid = tostring(i) }
        end
        client:summon("Whiskers", {})
        assert.are.equal(200, #probe.guids)
        assert.are.equal("2", probe.guids[1].guid)
        client.Addon:SetModuleOn("DevProbe", false)
        client:summon("Shadow", {})
        assert.are.equal("UNIT_PET", probe.guids[200].event)
        assert.are.equal("Whiskers", probe.guids[200].name)
    end)

    it("keeps what each family eats and the client's family names", function()
        local client, probe = probing()
        client.familyNames = { [1] = "Wolf", [2] = "Cat" }
        client:fire("PLAYER_ENTERING_WORLD")
        assert.are.same({ "Meat", "Fish" }, probe.foods[2])
        assert.are.same({ [1] = "Wolf", [2] = "Cat" }, probe.families)
    end)

    it("notes a rank learned below the highest the hunter knew", function()
        local client, probe = probing()
        client:advance(5)
        client:openTrainer({ { "Claw", "used", CLAW_3 } }):closeTrainer()
        client:learnLine("Claw (Rank 2)"):advance(0.3)
        assert.are.same({ name = "Claw", rank = 2, highest = 3, t = client.serverTime }, probe.lowerRanks[1])
    end)

    it("notes the pet's GUID when it comes out and when the client says a pet was tamed", function()
        local client, probe = probing()
        client.petGUID = "Creature-0-1-1-1-3825-00000ABCDE"
        client:fire("LOCALPLAYER_PET_RENAMED")
        client:summon("Whiskers", {})
        local events = {}
        for _, seen in ipairs(probe.guids) do
            events[#events + 1] = seen.event .. " " .. seen.guid
        end
        assert.is_truthy(tContains(events, "LOCALPLAYER_PET_RENAMED Creature-0-1-1-1-3825-00000ABCDE"))
        assert.is_truthy(tContains(events, "UNIT_PET Creature-0-1-1-1-3825-00000ABCDE"))
    end)

    it("keeps what the client is: its build, project, the library's client, the APIs Huntsworn leans on", function()
        local client, probe = probing()
        client:fire("PLAYER_ENTERING_WORLD")
        local found = probe.client
        assert.are.same({ "1.16.0", "60000", "Oct 1 2026", 11600 }, found.build)
        assert.are.equal(18, found.project)
        assert.are.equal("forever", found.tameable)
        assert.is_true(found.api.GetPlayerFacing)
        assert.is_true(found.api.OnMapChanged)
        assert.is_table(found.unitPosition, "its returns, or why there are none")
        assert.is_table(found.ammo)
    end)

    it("keeps whether the client hides the pet's health and the player's place in combat", function()
        local client, probe = probing()
        client:enterCombat()
        assert.is_table(probe.combat.petHealth)
        assert.is_table(probe.combat.unitPosition)
        local first = probe.combat
        client:leaveCombat():enterCombat()
        assert.are.equal(first, probe.combat, "the first fight only")
    end)

    it("keeps what the pet's happiness, loyalty and training points say, both ways", function()
        local client, probe = probing()
        client:summon("Whiskers", {})
        local pet = probe.pet
        assert.is_table(pet.happiness)
        assert.is_table(pet.loyalty)
        assert.is_table(pet.trainingPoints)
    end)

    it("notes the pet's events in the first minute after login, with what the client gives then", function()
        local client, probe = probing()
        client.trainingPoints, client.loyalty = { 0, 0 }, nil
        client:advance(2):fire("UNIT_PET", "player")
        client.trainingPoints, client.loyalty = { 50, 7 }, "Loyalty Level 4 (Dependable)"
        client:advance(4):fire("UNIT_PET_TRAINING_POINTS", "pet"):fire("PET_UI_UPDATE")
        local events = probe.petEvents
        assert.are.equal(3, #events)
        assert.are.same({ "UNIT_PET", "UNIT_PET_TRAINING_POINTS", "PET_UI_UPDATE" }, {
            events[1].event,
            events[2].event,
            events[3].event,
        })
        assert.is_true(events[1].after >= 2, "seconds since login")
        assert.near(events[1].after + 4, events[2].after, 1e-9)
        assert.are.same({ 0, 0 }, events[1].points)
        assert.are.same({}, events[1].loyalty, "no loyalty yet")
        assert.are.same({ 50, 7 }, events[2].points)
        assert.are.same({ "Loyalty Level 4 (Dependable)" }, events[2].loyalty)
        assert.are.same({ 15 }, events[2].level)
        client:advance(60):fire("PET_UI_UPDATE")
        assert.are.equal(3, #probe.petEvents, "not after the first minute")
    end)

    it("keeps the trainer's first rows as the client gives them", function()
        local client, probe = probing()
        client:advance(5)
        client:openTrainer({ { "Claw", "used", CLAW_3 } })
        assert.are.same({ "Claw", "used" }, probe.trainer[1])
    end)

    it("keeps after a tame what the pet knows beside what LibTameable says the beast teaches", function()
        local client, probe = probing({ noPet = true })
        client:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", TAME_BEAST)
        client.petGUID = "Pet-0-5250-0-1-3825-0100ABCDEF"
        client:summon("Whiskers", { 17253 }):advance(3)
        local tame = probe.tames[1]
        assert.are.equal(3825, tame.npc)
        assert.are.same({ "Bite 1" }, tame.knows)
        -- Ghostpaw Alpha teaches Bite 4 and Furious Howl 2 (named as the client names them).
        assert.are.equal(2, #tame.expected)
        assert.is_false(tame.match)
    end)

    it("keeps where a beast in the data was seen, and whether the data has it on that map", function()
        local client, probe = probing()
        client:hoverUnit("Creature-0-5250-0-12-3825-0000ABCDEF")
        local seen = probe.beasts[3825]
        assert.are.equal(1429, seen.map)
        assert.are.same({ 50, 50 }, { seen.x, seen.y })
        assert.is_false(seen.onDataMap)
        assert.are.same({ 1440 }, seen.dataMaps)
        client.mapPos = { 0.1, 0.1 }
        client:hoverUnit("Creature-0-5250-0-12-3825-0000ABCDEF")
        assert.are.equal(50, probe.beasts[3825].x, "the first sighting only")
    end)

    it("forgets everything from its page", function()
        local client, probe = probing()
        client:fire("PET_STABLE_UPDATE")
        client.Addon:GetModule("DevProbe"):GetOptions().args.forget.func()
        assert.are.same({}, probe.stable)
        assert.are.same({}, probe.guids)
    end)
end)
