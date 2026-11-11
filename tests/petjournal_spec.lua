-- Pet Journal: per character, a page per pet the hunter had out: when and where it was tamed or
-- first seen, its level and loyalty, the time out together, its deaths, when the next loyalty
-- level may come, and the abilities it had. The simulated pet is Fluffy, a level 15 cat with
-- loyalty 4, in Darkshore.

local TAME_BEAST = 1515
local FLUFFY = 3069428 -- the default pet's number

---The journal's page as the settings window has it.
---@param client table
---@return table<string, table>
local function page(client)
    return client.Addon:GetModule("PetJournal"):GetOptions().args
end

---The journal text of the chosen pet (the pet out, unless another was picked).
---@param client table
---@return string
local function journal(client)
    return page(client).journal.name()
end

---Whether the journal says `text`.
---@param client table
---@param text string
---@return boolean
local function says(client, text)
    return journal(client):find(text, 1, true) ~= nil
end

describe("Pet Journal", function()
    it("keeps the pet out: first seen, level, loyalty and abilities", function()
        local client = NewClient():login():advance(1)
        local when = date("%Y-%m-%d %H:%M", client.serverTime)
        assert.is_true(says(client, "First seen " .. when .. " in Darkshore."), journal(client))
        assert.is_true(says(client, "Level 15 Cat, loyalty 4 ("), journal(client))
        assert.is_true(says(client, "Eats: Meat, Fish"), "the family's diet")
        assert.is_true(
            says(client, "Abilities: Bite (Rank 1), Claw (Rank 2), Cower (Rank 1), Great Stamina (Rank 1), Growl.")
        )
    end)

    it("leaves out a taming quest's beast on Classic Era, which stays a creature", function()
        local client = NewClient({ era = true, noPet = true }):login()
        -- The hunter's taming quests lend a beast through the Taming Rod: its GUID stays a
        -- Creature's, where a tamed pet's is a Pet's at once (seen 2026-10-25 on Season of Discovery).
        client.petGUID = "Creature-0-5211-1-143-1998-00005E1A20"
        client:summon("Webwood Lurker", {}):advance(1)
        assert.are.same({}, client.Addon:GetModule("PetJournal"):Pets())
        client.petGUID = "Pet-0-5211-1-143-1995-0101235792"
        client:summon("Owl", { 17253 }):advance(1)
        assert.is_not_nil(next(client.Addon:GetModule("PetJournal"):Pets()), "the tamed one")
    end)

    it("records a tame: when, where and as which beast", function()
        local client = NewClient({ noPet = true }):login()
        client:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", TAME_BEAST)
        client.petGUID = "Pet-0-5250-0-1-3825-0100ABCDEF"
        client:summon("Whiskers", { 17253 }):advance(1)
        local when = date("%Y-%m-%d %H:%M", client.serverTime)
        assert.is_true(says(client, "Tamed " .. when .. " in Darkshore, as NPC 3825."), journal(client))
        assert.is_true(says(client, "Abilities: Bite (Rank 1)."))
    end)

    it("merges an entry the stable does not know into the stable's pet of that name and family", function()
        local client = NewClient()
        client.petGUID = "Pet-0-4615-1-1-165189-3AA8C65C43"
        client:login():advance(600)
        local M = client.Addon:GetModule("PetJournal")
        local old = tostring(0xA8C65C43)
        assert.is_truthy(M:Pets()[old], "kept under the GUID's number at first")
        client:petDies():petBack()
        M:Pets()[old].rises[5] = 300
        M:Pets()[old].first.t = client.serverTime - 3600
        client.stable.active = {
            { petNumber = 3069428, name = "Fluffy", familyName = "Cat", level = 15, creatureID = 1984, displayID = 5 },
        }
        client:fire("UNIT_PET", "player"):advance(60)
        local pets = M:Pets()
        assert.is_nil(pets[old])
        local entry = pets["3069428"]
        assert.are.equal(1, entry.deaths)
        assert.are.equal(1984, entry.first.npc)
        assert.are.equal(client.serverTime - 3600, entry.first.t, "the earlier first sight")
        assert.are.equal(300, entry.rises[5])
        assert.are.equal(5, entry.displayID)
        assert.are.equal("3069428", M.current)
        assert.is_true(says(client, "Out together: 11 min."), journal(client))
    end)

    it("leaves an entry alone that matches no stable pet, or two", function()
        local client = NewClient()
        client.petGUID = "Pet-0-4615-1-1-165189-3AA8C65C43"
        client:login()
        local M = client.Addon:GetModule("PetJournal")
        client.stable.stabled = {
            { petNumber = 10, name = "Fluffy", familyName = "Cat" },
            { petNumber = 11, name = "Fluffy", familyName = "Cat" },
        }
        client:fire("PET_STABLE_UPDATE")
        assert.is_truthy(M:Pets()[tostring(0xA8C65C43)])
        client.stable.stabled = { { petNumber = 12, name = "Fluffy", familyName = "Wolf" } }
        client:fire("PET_STABLE_UPDATE")
        assert.is_truthy(M:Pets()[tostring(0xA8C65C43)], "another family")
    end)

    it("reads WoW: Forever's stable loyalty, which counts from 0, without a false rise", function()
        -- Seen 2026-11-11: a fresh tame (Rebellious) listed as 0 with no name, an Unruly cat as 1.
        local client = NewClient()
        client.stable.active = {
            { petNumber = FLUFFY, name = "Fluffy", familyName = "Cat", loyaltyLevel = 3, loyaltyName = "Dependable" },
        }
        client.stable.stabled =
            { { petNumber = 20, name = "Rex", familyName = "Boar", loyaltyLevel = 0, loyaltyName = "" } }
        client:login():advance(1)
        client:fire("PET_STABLE_UPDATE"):fire("UNIT_PET", "player")
        local pets = client.Addon:GetModule("PetJournal"):Pets()
        assert.are.same({ 4, "Dependable" }, { pets[tostring(FLUFFY)].loyalty, pets[tostring(FLUFFY)].loyaltyName })
        assert.are.same({}, pets[tostring(FLUFFY)].rises, "no rise from the stable's count")
        assert.are.same({ 1 }, { pets["20"].loyalty, pets["20"].loyaltyName })
    end)

    it("drops a nameless entry of a pet out for a moment while a tame settles", function()
        -- WoW: Forever, 2026-11-11: right after each tame the pet was "Hunter Pet" (165189) for a few
        -- seconds, without a name or a stable entry, and got an entry under its GUID's number.
        local client = NewClient():login():advance(1)
        local pets = client.Addon:GetModule("PetJournal"):Pets()
        pets["507632844"] = { first = { t = 1, npc = 165189 }, out = 8, deaths = 0, rises = {}, abilities = {} }
        client:fire("PET_STABLE_UPDATE")
        assert.is_nil(pets["507632844"])
        assert.is_truthy(pets[tostring(FLUFFY)], "the named pet out stays")
    end)

    it("counts a fresh tame that is no longer out as past, until it comes back", function()
        local client = NewClient({ noPet = true }):login()
        local fresh = "Creature-0-5250-0-1-3825-0000ABCDEF"
        client.petGUID = fresh
        client:summon("Whiskers", { 17253 }):advance(1)
        client:petGone():fire("UNIT_PET", "player"):fire("PET_STABLE_UPDATE")
        local pets = client.Addon:GetModule("PetJournal"):Pets()
        assert.is_true(pets[fresh].past)
        client:summon("Whiskers", { 17253 }):advance(1)
        assert.is_nil(pets[fresh].past)
    end)

    it("takes the zone later when the client has none yet at login", function()
        local client = NewClient()
        client.zone = ""
        client:login():advance(1)
        assert.is_true(says(client, "First seen " .. date("%Y-%m-%d %H:%M", client.serverTime) .. " in ?."))
        client.zone = "Darkshore"
        client:advance(5):petLevelUp(4)
        assert.is_true(says(client, " in Darkshore."), journal(client))
    end)

    it("keeps a pet tamed this session, which has its creature GUID until relog, then its number", function()
        local client = NewClient({ noPet = true }):login()
        local fresh = "Creature-0-5250-0-1-3825-0000ABCDEF"
        client:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", TAME_BEAST)
        client.petGUID = fresh
        client:summon("Whiskers", { 17253 }):advance(60)
        local when = date("%Y-%m-%d %H:%M", client.serverTime)
        assert.is_true(says(client, "Tamed " .. when .. " in Darkshore, as NPC 3825."), journal(client))
        local pets = client.Addon:GetModule("PetJournal"):Pets()
        assert.is_truthy(pets[fresh])
        client:logout()
        client = NewClient({ saved = Saved() })
        client.petGUID = "Pet-0-5250-0-1-3825-0100ABCDEF"
        client.pet.name = "Whiskers"
        client:login():advance(60)
        pets = client.Addon:GetModule("PetJournal"):Pets()
        assert.is_nil(pets[fresh], "moved")
        local entry = pets[tostring(0xABCDEF)]
        assert.is_true(entry.first.tamed)
        assert.are.equal(3825, entry.first.npc)
        assert.is_true(says(client, "Out together: 2 min."), journal(client))
    end)

    it("does not take a fresh pet's entry for another beast's pet", function()
        local client = NewClient({ noPet = true }):login()
        client.petGUID = "Creature-0-5250-0-1-3825-0000ABCDEF"
        client:summon("Whiskers", {}):advance(1)
        client:logout()
        client = NewClient({ saved = Saved() })
        client.petGUID = "Pet-0-5250-0-1-1188-0100ABCDEF"
        client:login():advance(1)
        local pets = client.Addon:GetModule("PetJournal"):Pets()
        assert.is_truthy(pets["Creature-0-5250-0-1-3825-0000ABCDEF"], "still waiting for its own pet")
        assert.is_nil(pets[tostring(0xABCDEF)].first.tamed)
    end)

    it("counts the time out together, across a relog, and the deaths", function()
        local client = NewClient():login():advance(3900)
        assert.is_true(says(client, "Out together: 1 h 5 min."), journal(client))
        client:petDies():petBack():petDies():petBack()
        assert.is_true(says(client, "Died 2 |4time:times;."), journal(client))
        client:logout()
        client = NewClient({ saved = Saved() }):login():advance(600)
        assert.is_true(says(client, "Out together: 1 h 15 min."), journal(client))
        assert.is_false(says(client, "Died 3"))
    end)

    it("forecasts the next loyalty level from the rises it saw", function()
        local client = NewClient()
        client.loyalty = "Loyalty Level 3 (Submissive)"
        client:login():advance(600)
        client:loyaltyChange("Loyalty Level 4 (Dependable)", 15)
        assert.is_true(says(client, "Next loyalty level: not enough seen yet."), journal(client))
        client:advance(1200):loyaltyChange("Loyalty Level 5 (Faithful)", 15)
        client:advance(200)
        assert.is_true(says(client, "Next loyalty level in about 16 min out."), journal(client))
        client:advance(1500)
        assert.is_true(says(client, "Next loyalty level any moment now."), journal(client))
        client:loyaltyChange("Loyalty Level 6 (Best Friend)", 15)
        assert.is_false(says(client, "Next loyalty level"), "the highest")
    end)

    it("keeps every pet had out, to pick and read", function()
        local client = NewClient():login():advance(1)
        client.petGUID = "Pet-0-5250-0-1-3825-0100ABCDEF"
        client:summon("Whiskers", { 17253 }):advance(1)
        local select = page(client).pet
        local values = select.values()
        assert.are.equal("Fluffy (level 15 Cat)", values[tostring(FLUFFY)])
        assert.are.equal(tostring(0x00ABCDEF), select.get(), "the pet out")
        select.set(nil, tostring(FLUFFY))
        assert.is_true(says(client, "Claw (Rank 2)"), "Fluffy's own abilities")
        assert.are.equal("", journal(NewClient({ noPet = true }):login()), "no pet had out yet")
    end)

    it("says what a pet could still teach the hunter, also once it is stabled", function()
        local client = NewClient():login():advance(1)
        assert.is_true(says(client, "Can teach you: Bite (Rank 1), Claw (Rank 2), Cower (Rank 1)."), journal(client))
        client:openTrainer({ { "Claw", "used", CLAW_3 } }):closeTrainer()
        client.petGUID = "Pet-0-5250-0-1-3825-0100ABCDEF"
        client:summon("Whiskers", { 17253 }):advance(1)
        page(client).pet.set(nil, tostring(FLUFFY))
        assert.is_true(says(client, "Can teach you: Bite (Rank 1), Cower (Rank 1)."), journal(client))
        client.Addon:SetModuleOn("AbilityLearned", false)
        assert.is_false(says(client, "Can teach you"), "without Ability Learned's ranks")
    end)

    it("says a pet can teach only once the hunter knows Beast Training", function()
        local client = NewClient()
        client.unknownSpells[5149] = true -- Beast Training comes with the quest Training the Beast
        client:login():advance(1)
        assert.is_true(
            says(client, "Can teach you once you know Beast Training: Bite (Rank 1), Claw (Rank 2), Cower (Rank 1)."),
            journal(client)
        )
    end)

    describe("in the pet's tooltip", function()
        ---The texts of the lines the journal adds to a tooltip of the unit with `guid`.
        local function tooltip(client, guid, frame)
            local texts = {}
            for _, line in ipairs(client:hoverUnit(guid, frame)) do
                texts[#texts + 1] = line.text
            end
            return texts
        end

        it("adds when it came, the time out, deaths, the forecast and what it could teach", function()
            local client = NewClient():login():advance(3900)
            client:petDies():petBack()
            local when = date("%Y-%m-%d %H:%M", client.serverTime)
            assert.are.same({
                "First seen " .. when .. " in Darkshore.",
                "Eats: Meat, Fish",
                "Out together: 1 h 5 min.",
                "Died 1 |4time:times;.",
                "Next loyalty level: not enough seen yet.",
                "Can teach you: Bite (Rank 1), Claw (Rank 2), Cower (Rank 1).",
            }, tooltip(client, client.petGUID))
            assert.are.same({ 0.6, 0.6, 0.6 }, client:hoverUnit(client.petGUID)[1].color)
        end)

        it("stays out of another pet's, another tooltip, or when switched off", function()
            local client = NewClient():login():advance(1)
            assert.are.same({}, tooltip(client, "Pet-0-5250-0-1-3825-0100ABCDEF"), "a pet not in the journal")
            assert.are.same({}, tooltip(client, "Creature-0-5250-0-12-101-0000ABCDEF"))
            assert.are.same({}, tooltip(client, SECRET))
            assert.are.same({}, tooltip(client, client.petGUID, {}))
            page(client).tooltip.set(nil, false)
            assert.are.same({}, tooltip(client, client.petGUID))
            page(client).tooltip.set(nil, true)
            client.Addon:SetModuleOn("PetJournal", false)
            assert.are.same({}, tooltip(client, client.petGUID))
        end)
    end)

    it("is for hunters only, and keeps nothing while switched off", function()
        local mage = NewClient({ class = "MAGE" }):login():advance(1)
        assert.are.same({}, page(mage).pet.values())
        local client = NewClient({ noPet = true }):login()
        client.Addon:SetModuleOn("PetJournal", false)
        client:summon("Whiskers", { 17253 }):advance(1)
        assert.are.same({}, page(client).pet.values())
    end)
end)
