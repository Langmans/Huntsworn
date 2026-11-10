-- AbilityLearned: a toast when the hunter learns a pet ability from a tamed beast, the history of
-- those learns per character, and what a pet out can still teach.

local LEVEL_UP = 888
local CAT_CALL = 562387 -- Huntsworn.sounds.AGGRO_PER_FAMILY[2]

---A hunter past the login wait, with a cat named Fluffy that has Claw rank 2 and Bite; chat
---emptied of the hint said for it.
local function ready(opts)
    local client = NewClient(opts):login()
    client.petBook = { { CLAW_2 }, { 17253 } }
    client:advance(5)
    client.printed = {}
    return client
end

---The module's settings and per-character data.
local function module(client)
    return client.Addon:GetModule("AbilityLearned")
end

---How the core last saw Fluffy grow (HUNTSWORN_PET_GROWTH's saved state).
local function fluffy(client)
    return client.Addon.db.char.growth.Fluffy
end

---Lets the merge window pass, so the learn shows.
local function settle(client)
    return client:advance(0.3)
end

describe("AbilityLearned", function()
    describe("a learn", function()
        it("toasts a wild ability with its rank, the pet that taught it and its free points", function()
            local client = settle(ready():learnLine("Claw (Rank 2)"))
            local toast = client:toast()
            assert.are.equal("New pet ability: Claw (Rank 2)", toast.Title.text)
            assert.are.equal("Fluffy has taught you Claw.", toast.Text.text)
            assert.are.equal("Fluffy has 43 training |4point:points; free.", toast.Hint.text)
            assert.are.equal("Ability Learned", toast.Source.text, "the splash, by default")
            assert.are.equal(132140, toast.Icon.texture)
            assert.are.equal("pet", toast.Portrait.portrait)
            assert.are.same({ file = CAT_CALL, channel = "Master" }, client.sounds[#client.sounds])
        end)

        it("counts the Fox's Trickster's Dance, new in WoW: Forever", function()
            local client = ready()
            client.pet = nil
            settle(client:learnLine("Trickster's Dance (Rank 1)"))
            assert.are.equal("New pet ability: Trickster's Dance (Rank 1)", client:toastTitle())
        end)

        it("reads the name from a spell link, and the rank from its spell", function()
            local client = settle(ready():learnLine("|cff71d5ff|Hspell:16828:0|h[Claw]|h|r"))
            assert.are.equal("New pet ability: Claw (Rank 2)", client:toastTitle())
        end)

        it("takes the rank and icon from the pet's spellbook when the line has none", function()
            local client = settle(ready():learnLine("Claw"))
            assert.are.equal("New pet ability: Claw (Rank 2)", client:toastTitle())
        end)

        it("keeps the spellbook's rank as it was at the learn, whatever reads the book meanwhile", function()
            local client = ready():learnLine("Claw")
            client.petBook = { { CLAW_3 } }
            client.Addon.PetSpells() -- a hint or another learn reading the book within the window
            assert.are.equal("New pet ability: Claw (Rank 2)", settle(client):toastTitle())
        end)

        it("without the pet that has it, points to Beast Training and plays the level-up sound", function()
            local client = ready()
            client.pet = nil
            settle(client:learnLine("Charge (Rank 1)"))
            local toast = client:toast()
            assert.are.equal("New pet ability: Charge (Rank 1)", toast.Title.text)
            assert.are.equal("Teach it to your pet from the Beast Training window.", toast.Text.text)
            assert.are.equal("", toast.Hint.text)
            assert.is_false(toast.Portrait.shown)
            assert.are.same({ kit = LEVEL_UP, channel = "Master" }, client.sounds[#client.sounds])
        end)

        it("shows once when the chat line and the spellbook event both report it", function()
            local client = ready():learnLine("Claw (Rank 2)")
            client:fire("LEARNED_SPELL_IN_TAB", CLAW_2)
            client:fire("LEARNED_SPELL_IN_SKILL_LINE", CLAW_2)
            settle(client):animate(10)
            assert.are.equal(1, #module(client).db.char.history)
            assert.is_nil(client:toastTitle(), "no second toast")
        end)

        it("takes a rank the chat line lacks from the spellbook event merged into it", function()
            local client = ready()
            client.pet = nil
            client:learnLine("Claw"):fire("LEARNED_SPELL_IN_TAB", CLAW_3)
            assert.are.equal("New pet ability: Claw (Rank 3)", settle(client):toastTitle())
        end)

        it("comes from the spellbook event alone as well", function()
            local client = settle(ready():fire("LEARNED_SPELL_IN_TAB", CLAW_2))
            assert.are.equal("New pet ability: Claw (Rank 2)", client:toastTitle())
        end)

        it("shows two different abilities one after the other", function()
            local client = ready():learnLine("Claw (Rank 2)"):learnLine("Bite (Rank 1)")
            settle(client)
            assert.are.equal("New pet ability: Claw (Rank 2)", client:toastTitle())
            client:animate(8)
            assert.are.equal("New pet ability: Bite (Rank 1)", client:toastTitle())
        end)

        it("works in another language, from the client's own names and line", function()
            local client = settle(ready({ locale = "deDE" }):learnLine("Klaue (Rang 2)"))
            assert.truthy(client:toastTitle():find("Klaue (Rang 2)", 1, true))
        end)

        it("leaves out what a trainer sells, other spells and other lines", function()
            local client = ready()
            client:learnLine("Great Stamina (Rank 1)")
            client:fire("CHAT_MSG_SYSTEM", "You have learned a new spell: Distracting Shot.")
            client:fire("CHAT_MSG_SYSTEM", "Langmans has come online.")
            client:fire("CHAT_MSG_SYSTEM", SECRET)
            client:fire("CHAT_MSG_SYSTEM", "")
            client:fire("LEARNED_SPELL_IN_TAB", 99999)
            settle(client)
            assert.is_nil(client:toast())
        end)

        it("is not news while a trainer window is open", function()
            local client = ready():openTrainer({}, true)
            settle(client:learnLine("Claw (Rank 2)"))
            assert.is_nil(client:toast())
            client:closeTrainer()
            assert.is_not_nil(settle(client:learnLine("Claw (Rank 2)")):toast())
        end)

        it("counts again once the trainer window is gone, also when no close event came", function()
            local client = ready():openTrainer({}, true)
            ClassTrainerFrame:Hide()
            assert.is_not_nil(settle(client:learnLine("Claw (Rank 2)")):toast())
            client = ready():openTrainer({})
            client:closeTrainer("TRADE_SKILL_CLOSE")
            assert.is_not_nil(settle(client:learnLine("Claw (Rank 2)")):toast())
        end)

        it("is not news in the first seconds after login, when spells are replayed", function()
            local client = NewClient():login()
            settle(client:learnLine("Claw (Rank 2)"))
            assert.is_nil(client:toast())
        end)

        it("shows the same ability once, also when a late duplicate comes after the window", function()
            local client = settle(ready():learnLine("Claw (Rank 2)"))
            client:animate(8)
            settle(client:advance(2):learnLine("Claw (Rank 2)"))
            assert.is_nil(client:toastTitle())
            assert.are.equal(1, #module(client).db.char.history)
        end)

        it("has the screenshot asked of the toast when that is on", function()
            local client = ready()
            module(client).db.profile.screenshot = true
            settle(client:learnLine("Claw (Rank 2)")):animate(1)
            assert.are.equal(1, client.screenshots)
        end)

        it("plays the level-up sound, or none, as set", function()
            local client = ready()
            module(client).db.profile.sound = "levelup"
            settle(client:learnLine("Claw (Rank 2)"))
            assert.are.same({ kit = LEVEL_UP, channel = "Master" }, client.sounds[#client.sounds])
            client = ready()
            module(client).db.profile.sound = "off"
            settle(client:learnLine("Claw (Rank 2)"))
            assert.are.same({}, client.sounds)
        end)

        it("plays the level-up sound for a family without a call", function()
            local client = ready()
            client.familyID = 6 -- a crocolisk
            settle(client:learnLine("Claw (Rank 2)"))
            assert.are.same({ kit = LEVEL_UP, channel = "Master" }, client.sounds[#client.sounds])
        end)

        it("is watched only on a hunter", function()
            local client = NewClient({ class = "MAGE" }):login():advance(5)
            settle(client:learnLine("Claw (Rank 2)"))
            assert.is_nil(client:toast())
        end)

        it("is watched on a client without the learn lines, through the spellbook event", function()
            local client = settle(ready({ noLearnLines = true }):fire("LEARNED_SPELL_IN_TAB", CLAW_2))
            assert.are.equal("New pet ability: Claw (Rank 2)", client:toastTitle())
        end)
    end)

    describe("the history", function()
        it("keeps each learn with its pet, the beast it was tamed as, family, zone and time, per character", function()
            local client = settle(ready():learnLine("Claw (Rank 2)"))
            assert.are.same({
                {
                    name = "Claw",
                    rank = "Rank 2",
                    pet = "Fluffy",
                    npc = 165189,
                    familyID = 2,
                    zone = "Darkshore",
                    t = 1791374580,
                },
            }, module(client).db.char.history)
            client:logout()
            local relogged = NewClient({ saved = Saved() }):login()
            assert.are.equal(1, #module(relogged).db.char.history)
        end)

        it("is told to other addons as HUNTSWORN_ABILITY_LEARNED, a simulated learn not", function()
            local client = ready()
            local heard = {}
            client.Addon:Listen(heard, "HUNTSWORN_ABILITY_LEARNED", function(_, event)
                heard[#heard + 1] = event
            end)
            settle(client:learnLine("Claw (Rank 2)"))
            assert.are.same({
                {
                    module = "AbilityLearned",
                    name = "Claw",
                    rank = 2,
                    pet = "Fluffy",
                    npc = 165189,
                    zone = "Darkshore",
                },
            }, { heard[1] })
            module(client):ShowLearn({ name = "Bite", rank = "Rank 1", simulated = true })
            assert.are.equal(1, #heard)
        end)

        it("keeps the last 200", function()
            local client = ready()
            local history = module(client).db.char.history
            for i = 1, 200 do
                history[i] = { name = "Old " .. i, t = i }
            end
            settle(client:learnLine("Claw (Rank 2)"))
            assert.are.equal(200, #history)
            assert.are.equal("Old 2", history[1].name)
            assert.are.equal("Claw", history[200].name)
        end)

        it("lists the learns from a beast Huntsworn's beast data does not have as a teacher", function()
            local client = ready()
            local M = module(client)
            local missing = M:GetOptions().args.teachers
            missing.func()
            assert.is_true(client:printedContains("Every learn from a pet is in Huntsworn's beast data."))
            M.db.char.history = {
                -- Black Bear Patriarch (1189) teaches Claw 3 in the data.
                { name = "Claw", rank = "Rank 3", pet = "Scraps", npc = 1189, zone = "Westfall", t = 1 },
                { name = "Claw", rank = "Rank 2", pet = "Fluffy", npc = 165189, zone = "Darkshore", t = 2 },
                { name = "Charge", rank = "Rank 1", zone = "Darkshore", t = 3 },
                -- A rank the data has no entry for at all.
                { name = "Claw", rank = "Rank 9", pet = "Scraps", npc = 154, zone = "Westfall", t = 4 },
            }
            client.printed = {}
            missing.func()
            assert.are.equal(2, #client.printed, client.printed[1])
            assert.is_true(client:printedContains("Claw (Rank 2): Fluffy, tamed as NPC 165189, Darkshore"))
            assert.is_true(client:printedContains("Claw (Rank 9): Scraps, tamed as NPC 154, Westfall"))
        end)

        it("is a line per learn, newest first, on the module's page", function()
            local client = settle(ready():learnLine("Claw (Rank 2)"))
            client:animate(8)
            client.pet = nil
            settle(client:learnLine("Charge (Rank 1)"))
            local text = module(client):GetOptions().args.history.name()
            local claw = text:find("Claw (Rank 2), from Fluffy, Darkshore", 1, true)
            local charge = text:find("Charge (Rank 1), Darkshore", 1, true)
            assert.truthy(claw and charge and charge < claw, text)
            assert.truthy(text:find("^%d%d%d%d%-%d%d%-%d%d %d%d:%d%d  Charge"), "the date and time first")
            assert.are.equal("Nothing learned on this character yet.", module(ready()):GetOptions().args.history.name())
        end)
    end)

    describe("what a pet can teach", function()
        it("is said in chat when a pet is summoned, once per pet, until there is something new", function()
            local client = ready()
            module(client).db.char.known = { Claw = 2, Bite = 1 }
            client:summon("Shadow", { CLAW_3, 17253, 4187 }):advance(1)
            assert.is_true(client:printedContains("Shadow can teach you: Claw (Rank 3)."))
            client.printed = {}
            client:summon("Shadow", { CLAW_3, 17253 }):advance(1)
            assert.are.same({}, client.printed, "said before")
            client:summon("Rex", { 17253 }):advance(1)
            assert.are.same({}, client.printed, "nothing to teach")
        end)

        it("asks to open Beast Training once while a rank may simply be unknown", function()
            local client = ready()
            client:summon("Shadow", { CLAW_2 }):advance(1)
            assert.is_true(client:printedContains("Shadow can teach you: Claw (Rank 2)."))
            assert.is_true(client:printedContains("Open Beast Training once"))
        end)

        it("says nothing with hints off, or before the login wait is over", function()
            local client = ready()
            module(client).db.profile.hints = false
            client:summon("Shadow", { CLAW_3 }):advance(1)
            assert.are.same({}, client.printed)
            local early = NewClient():login()
            early.printed = {}
            early:summon("Shadow", { CLAW_3 }):advance(1)
            assert.are.same({}, early.printed)
        end)

        it("is said for a pet already out once the login wait is over", function()
            local client = NewClient():login()
            client.petBook = { { CLAW_3 } }
            client:advance(5)
            assert.is_true(client:printedContains("Fluffy can teach you: Claw (Rank 3)."))
        end)

        it("is said on the page's button whenever asked, also when it is nothing", function()
            local client = ready()
            local check = module(client):GetOptions().args.check.func
            module(client).db.char.known = { Claw = 2, Bite = 1 }
            check()
            assert.is_true(client:printedContains("Fluffy has nothing left to teach you."))
            client.petBook = { { CLAW_3 }, { 7371 } }
            check()
            assert.is_true(client:printedContains("Fluffy can teach you: Charge (Rank 1), Claw (Rank 3)."))
            assert.is_true(client:printedContains("Open Beast Training once"))
            client.pet = nil
            check()
            assert.is_true(client:printedContains("No pet out to check."))
        end)
    end)

    describe("Beast Training", function()
        it("tells which ranks the hunter knows, so the hints are sure", function()
            local client = ready()
            client:openTrainer({ { "Claw", "used", CLAW_3 }, { "Pets", "header" }, { "Bite", "used", 17253 } })
            local char = module(client).db.char
            assert.are.same({ Claw = 3, Bite = 1 }, char.known)
            assert.is_true(char.trainingRead)
            client:fire("TRAINER_UPDATE")
            client:closeTrainer()
            client.printed = {}
            client:summon("Shadow", { CLAW_3 }):advance(1)
            assert.are.same({}, client.printed)
        end)

        it("keeps each rank's training point cost and pet level, and the abilities the family is shown", function()
            local client = ready()
            client:openTrainer({ { "Claw", "used", CLAW_3, cost = 15, level = 16 } })
            local global = module(client).db.global
            assert.are.same({ cost = 15, level = 16 }, global.costs.Claw[3])
            assert.is_true(global.taught[2].Claw, "the cat's family")
        end)

        it("reads Classic Era's Beast Training, the craft window, and leaves Enchanting alone", function()
            local client = ready({ era = true })
            client:openCraft({
                { "Claw", "Rank 3", "available", 15, 16 },
                { "Pets", nil, "header" },
                { "Bite", "Rank 2", "used", 10, 8 },
            })
            local M = module(client)
            assert.are.equal(3, M:HighestRank("Claw"))
            assert.are.equal(2, M:HighestRank("Bite"))
            assert.is_true(M.db.char.trainingRead)
            assert.are.same({ cost = 10, level = 8 }, M.db.global.costs.Bite[2])
            client = ready({ era = true })
            client:openCraft({ { "Enchant Bracer - Minor Health", "", "optimal" } })
            assert.is_nil(module(client):HighestRank("Enchant Bracer - Minor Health"))
            assert.is_false(module(client).db.char.trainingRead)
        end)

        describe("advises what to train with the free points", function()
            ---Fluffy: level 15, 43 points free, Claw 2 and Bite 1; Beast Training read.
            local function training()
                local client = ready({ era = true })
                client:openCraft({
                    { "Bite", "Rank 1", "used", 1, 1 },
                    { "Bite", "Rank 2", "available", 10, 8 },
                    { "Bite", "Rank 3", "unavailable", 20, 16 }, -- the pet's level is too low
                    { "Claw", "Rank 2", "used", 8, 8 },
                    { "Growl", "Rank 2", "available", 30, 10 },
                    { "Cower", "Rank 1", "available", 5, 5 },
                })
                return client
            end

            it(
                "upgrades first, then new abilities, each its highest known rank that fits, within the points",
                function()
                    local advice = module(training()):Advice()
                    assert.are.same({ "Bite rank 2 (10)", "Cower rank 1 (5)" }, advice.buy)
                    assert.are.equal(43, advice.free)
                    assert.are.equal(28, advice.left)
                    assert.are.equal("Growl rank 2 (30)", advice.saving, "next in line, not yet in reach")
                    assert.are.equal(2, advice.short)
                end
            )

            it("puts the role's abilities first: Growl for a tank, then the rest as for upgrades", function()
                local client = training()
                local advice = module(client):Advice("tank")
                assert.are.same({ "Growl rank 2 (30)", "Bite rank 2 (10)" }, advice.buy)
                assert.are.equal(3, advice.left)
                assert.are.equal("Cower rank 1 (5)", advice.saving)
                assert.are.equal(2, advice.short)
                advice = module(client):Advice("dps")
                assert.are.same({ "Bite rank 2 (10)", "Cower rank 1 (5)" }, advice.buy, "Bite is damage")
            end)

            it("leaves out what the family cannot learn, and keeps the cost a family that can showed", function()
                local client = training()
                -- A boar: Era's Beast Training lists the hunter's Claw ranks too, without a cost.
                client.familyID, client.petBook = 5, { { 17253 } }
                client:openCraft({
                    { "Bite", "Rank 2", "available", 10, 8 },
                    { "Claw", "Rank 2", "available", 0, 8 },
                    { "Claw", "Rank 3", "available", 0, 8 },
                })
                local M = module(client)
                assert.are.same({ cost = 8, level = 8 }, M.db.global.costs.Claw[2], "the cat's cost stays")
                assert.is_nil(M.db.global.costs.Claw[3])
                assert.is_nil(M.db.global.taught[5].Claw)
                assert.are.same({ "Bite rank 2 (10)" }, M:Advice().buy)
                M.db.global.taught[5].Claw = true -- a family entry from saved data
                M.db.global.costs.Claw[3] = { cost = 0, level = 8 }
                local advice = M:Advice()
                assert.are.same({ "Bite rank 2 (10)" }, advice.buy, "no Claw for a boar")
                assert.is_nil(advice.saving)
            end)

            it("has nothing to buy or save for without points, costs or a pet", function()
                local client = training()
                client.trainingPoints = { 50, 50 }
                local advice = module(client):Advice()
                assert.are.same({}, advice.buy, "nothing free")
                assert.are.equal("Bite rank 2 (10)", advice.saving)
                assert.are.equal(10, advice.short)
                advice = module(ready({ era = true })):Advice()
                assert.are.same({}, advice.buy, "Beast Training not read")
                assert.is_nil(advice.saving)
            end)
        end)

        it("never lowers a rank, and leaves a pet trainer's ranks for sale alone", function()
            local client = ready()
            module(client).db.char.known = { Claw = 3 }
            client:openTrainer({ { "Bite", "available", 17253 } }, true):closeTrainer()
            assert.is_nil(module(client).db.char.known.Bite)
            assert.is_false(module(client).db.char.trainingRead)
            client:openTrainer({ { "Claw", "used", CLAW_2 } })
            assert.are.equal(3, module(client).db.char.known.Claw)
        end)

        it("skips a row it cannot read, and a window with nothing it can read", function()
            local client = ready()
            client:openTrainer({ { broken = true }, { "Claw", "used", CLAW_2 } })
            assert.are.same({ Claw = 2 }, module(client).db.char.known)
            client = ready()
            client:openTrainer({ { "Claw", "used" } })
            assert.is_false(module(client).db.char.trainingRead)
        end)

        it("keeps every rank learned, not only the highest, and says when that changed", function()
            local client = ready()
            local M, heard = module(client), {}
            client.Addon.RegisterMessage({}, "HUNTSWORN_RANKS_KNOWN", function(_, event)
                heard[#heard + 1] = event
            end)
            client:openTrainer({ { "Claw", "used", CLAW }, { "Claw", "used", CLAW_3 } })
            assert.are.same({ Claw = { [1] = true, [3] = true } }, M.db.char.ranks)
            assert.are.equal(3, M:HighestRank("Claw"))
            assert.is_true(M:HasRank("Claw", 3))
            assert.is_false(M:HasRank("Claw", 2))
            assert.is_nil(M:HighestRank("Bite"))
            assert.is_false(M:HasRank("Bite", 1))
            assert.are.same({
                {
                    module = "AbilityLearned",
                    source = "training",
                    ranks = { { name = "Claw", rank = 1 }, { name = "Claw", rank = 3 } },
                },
            }, heard)
            client:fire("TRAINER_UPDATE")
            assert.are.equal(1, #heard, "nothing new")
            client:closeTrainer()
            settle(client:advance(5):learnLine("Claw (Rank 2)"))
            assert.is_true(M:HasRank("Claw", 2))
            assert.are.equal(3, M:HighestRank("Claw"))
            assert.are.same(
                { module = "AbilityLearned", source = "learn", ranks = { { name = "Claw", rank = 2 } } },
                heard[2]
            )
        end)

        it("counts a learn already known by its rank", function()
            local client = settle(ready():learnLine("Claw (Rank 2)"))
            assert.are.equal(2, module(client).db.char.known.Claw)
            client:animate(8)
            client.pet = nil
            settle(client:advance(5):learnLine("Charge"))
            assert.are.equal(1, module(client).db.char.known.Charge, "no rank: rank 1")
        end)
    end)

    describe("training points gained", function()
        it("toast how many the pet got and how many are free", function()
            local client = ready():gainPoints(3)
            local toast = client:toast()
            assert.are.equal("Fluffy gained 3 training |4point:points;", toast.Title.text)
            assert.are.equal("46 free to spend at Beast Training.", toast.Text.text)
            assert.are.equal("Interface\\Icons\\Ability_Hunter_BeastTraining", toast.Icon.texture)
            assert.are.equal("pet", toast.Portrait.portrait)
            assert.are.same({ file = CAT_CALL, channel = "Master" }, client.sounds[#client.sounds])
            assert.are.equal("card", client.Addon:ToastSkinFor("AbilityLearned:points"), "the look for every toast")
        end)

        it("say nothing when points are spent, or the event comes without a change", function()
            local client = ready()
            client.trainingPoints = { 50, 20 }
            client:fire("UNIT_PET_TRAINING_POINTS", "pet")
            client:fire("UNIT_PET_TRAINING_POINTS", "player")
            assert.is_nil(client:toast())
        end)

        it("are counted per pet: a new pet is only noted, one back with more is told", function()
            local client = ready()
            client.trainingPoints = { 10, 0 }
            client:summon("Shadow", {}):advance(1)
            assert.is_nil(client:toast(), "first time Huntsworn sees Shadow")
            client.trainingPoints = { 50, 7 }
            client:summon("Fluffy", {}):advance(1)
            assert.is_nil(client:toast(), "Fluffy as it was")
            client.trainingPoints = { 14, 0 }
            client:summon("Shadow", {}):advance(1)
            assert.are.equal("Shadow gained 4 training |4point:points;", client:toastTitle())
        end)

        it("are kept per character across a relog, and told once the login wait is over", function()
            local client = ready()
            client:logout()
            local relogged = NewClient({ saved = Saved() })
            relogged.trainingPoints = { 52, 7 }
            relogged:login()
            assert.is_nil(relogged:toast(), "not in the login wait")
            relogged:advance(5)
            assert.are.equal("Fluffy gained 2 training |4point:points;", relogged:toastTitle())
        end)

        it("are noted but not told with the toast off, or on a client without them", function()
            local client = ready()
            module(client).db.profile.points = false
            client:gainPoints(3)
            assert.is_nil(client:toast())
            module(client).db.profile.points = true
            client:fire("UNIT_PET_TRAINING_POINTS", "pet")
            assert.is_nil(client:toast(), "the 3 were noted")
            client = ready({ noTrainingAPI = true }):gainPoints(3)
            assert.is_nil(client:toast())
        end)

        it("have a sound of their own, apart from the learn's", function()
            local client = ready()
            local settings = module(client).db.profile
            settings.pointsSound = "levelup"
            client:gainPoints(3)
            assert.are.same({ kit = LEVEL_UP, channel = "Master" }, client.sounds[#client.sounds])
            client:animate(8)
            settle(client:learnLine("Claw (Rank 2)"))
            assert.are.same({ file = CAT_CALL, channel = "Master" }, client.sounds[#client.sounds], "learn: family")
            client:animate(8)
            settings.pointsSound = "off"
            local count = #client.sounds
            client:gainPoints(1)
            assert.are.equal("Fluffy gained 1 training |4point:points;", client:toastTitle())
            assert.are.equal(count, #client.sounds)
        end)

        it("are toasted from the core's HUNTSWORN_PET_GROWTH", function()
            local client = ready()
            client.Addon:SendMessage("HUNTSWORN_PET_GROWTH", {
                pet = "Shadow",
                level = 30,
                loyalty = 2,
                points = 35,
                free = 12,
                before = { level = 29, loyalty = 2, points = 30 },
            })
            assert.are.equal("Shadow reached level 30", client:toastTitle())
        end)

        it("are not watched with the module off", function()
            local client = ready()
            client.Addon:SetModuleOn("AbilityLearned", false)
            assert.is_nil(client:gainPoints(3):toast())
        end)

        it("name a pet level-up as their cause", function()
            local toast = ready():petLevelUp(4):toast()
            assert.are.equal("Fluffy reached level 16", toast.Title.text)
            assert.are.equal("+4 training |4point:points;, 47 free for Beast Training.", toast.Text.text)
        end)

        it("are not there for a level-up at loyalty level 1, which says nothing", function()
            local client = ready()
            client.loyalty = "Loyalty Level 1 (Rebellious)"
            fluffy(client).loyalty = 1
            assert.is_nil(client:petLevelUp(0):toast())
            assert.are.equal(16, fluffy(client).level, "the level is noted")
        end)

        it("name a loyalty level-up as their cause", function()
            local toast = ready():loyaltyChange("Loyalty Level 5 (Faithful)", 15):toast()
            assert.are.equal("Fluffy now has loyalty level 5 (|cff00cca3Faithful|r)", toast.Title.text)
            assert.are.equal("+15 training |4point:points;, 58 free for Beast Training.", toast.Text.text)
        end)

        it("name no cause when level and loyalty rose together", function()
            local client = ready()
            client.petLevel, client.loyalty = 16, "Loyalty Level 5 (Faithful)"
            client:gainPoints(19)
            assert.are.equal("Fluffy gained 19 training |4point:points;", client:toastTitle())
        end)

        it("name the level without a way to read loyalty", function()
            assert.are.equal("Fluffy reached level 16", ready({ noLoyaltyAPI = true }):petLevelUp(4):toastTitle())
        end)
    end)

    describe("loyalty dropping", function()
        it("toasts with the new loyalty level, the pet's wound cry and the look for every toast", function()
            local client = ready():loyaltyChange("Loyalty Level 3 (Submissive)", -15)
            local toast = client:toast()
            assert.are.equal("Fluffy's loyalty dropped", toast.Title.text)
            assert.are.equal(
                "Now loyalty level 3 (|cff00cc52Submissive|r). Keep it happy, or it may run away.",
                toast.Text.text,
                "the name coloured from friendly green at level 1 to exalted teal at 6"
            )
            assert.are.equal("-15 training |4point:points;, 28 free.", toast.Hint.text, "a lower loyalty costs points")
            assert.are.equal("pet", toast.Portrait.portrait)
            assert.are.same({ file = 562395, channel = "Master" }, client.sounds[#client.sounds])
            assert.are.equal("card", client.Addon:ToastSkinFor("AbilityLearned:loyalty"))
        end)

        it("is noted but not told with its toast off, and has a sound setting of its own", function()
            local client = ready()
            module(client).db.profile.loyalty = false
            assert.is_nil(client:loyaltyChange("Loyalty Level 3 (Submissive)", -15):toast())
            client = ready()
            module(client).db.profile.loyaltySound = "off"
            client:loyaltyChange("Loyalty Level 3 (Submissive)", -15)
            assert.are.equal("Fluffy's loyalty dropped", client:toastTitle())
            assert.are.same({}, client.sounds)
        end)

        it("is seen on the pet window's update too", function()
            local client = ready()
            client.loyalty = "Loyalty Level 3 (Submissive)"
            assert.are.equal("Fluffy's loyalty dropped", client:fire("PET_UI_UPDATE"):toastTitle())
        end)
    end)

    describe("loyalty as the client gives it", function()
        ---A hunter past the login wait whose level-15 pet has `loyalty` and `total` points.
        local function withLoyalty(loyalty, total, opts)
            local client = NewClient(opts)
            client.loyalty, client.trainingPoints = loyalty, { total, 7 }
            client:login():advance(5)
            return client
        end

        it("reads Forever's bare name, the level coming from the points", function()
            local client = withLoyalty("Dependable", 45) -- 15 × (4 − 1)
            assert.are.equal(4, fluffy(client).loyalty)
            local title = client:loyaltyChange("Faithful", 15):toastTitle()
            assert.are.equal("Fluffy now has loyalty level 5 (|cff00cca3Faithful|r)", title)
        end)

        it("reads a bare number, without a name", function()
            local client = withLoyalty(4, 45)
            assert.are.equal("Fluffy now has loyalty level 5", client:loyaltyChange(5, 15):toastTitle())
        end)

        it("reads the classic text through the old global", function()
            local client = withLoyalty("Loyalty Level 4 (Dependable)", 45, { oldLoyaltyAPI = true })
            local title = client:loyaltyChange("Loyalty Level 5 (Faithful)", 15):toastTitle()
            assert.are.equal("Fluffy now has loyalty level 5 (|cff00cca3Faithful|r)", title)
        end)

        it("leaves loyalty out, without an error, when neither it nor the points tell the level", function()
            local client = withLoyalty("Dependable", 50) -- 50 is no multiple of 15
            assert.is_nil(fluffy(client).loyalty)
            assert.are.equal("Fluffy reached level 16", client:petLevelUp(4):toastTitle())
            client = withLoyalty(SECRET, 45)
            assert.are.equal(4, fluffy(client).loyalty, "hidden: from the points")
            client = withLoyalty("Dependable", 45)
            client.petLevel = 0
            client:gainPoints(1)
            assert.are.same({}, client.errors)
        end)
    end)

    describe("the page", function()
        it("sets the sound, the screenshot and the hints", function()
            local client = ready()
            local args = module(client):GetOptions().args
            local settings = module(client).db.profile
            assert.are.equal("family", args.sound.get())
            args.sound.set({}, "off")
            assert.are.equal("off", settings.sound)
            assert.is_false(args.screenshot.get())
            args.screenshot.set({}, true)
            assert.is_true(settings.screenshot)
            assert.is_true(args.hints.get())
            args.hints.set({}, false)
            assert.is_false(settings.hints)
            assert.is_true(args.points.get())
            args.points.set({}, false)
            assert.is_false(settings.points)
            assert.are.equal("family", args.pointsSound.get())
            args.pointsSound.set({}, "off")
            assert.are.equal("off", settings.pointsSound)
            assert.is_true(args.loyalty.get())
            args.loyalty.set({}, false)
            assert.is_false(settings.loyalty)
            assert.are.equal("family", args.loyaltySound.get())
            args.loyaltySound.set({}, "levelup")
            assert.are.equal("levelup", settings.loyaltySound)
        end)

        it("shows an example toast, kept out of the history", function()
            local client = ready()
            module(client):GetOptions().args.test.func()
            assert.are.equal("New pet ability: Bite (Rank 1)", client:toastTitle(), "one of the pet's own")
            assert.are.same({}, module(client).db.char.history)
            client:animate(8)
            client.pet = nil
            module(client):GetOptions().args.test.func()
            assert.are.equal("New pet ability: Claw (Rank 2)", client:toastTitle(), "Claw without a pet")
        end)

        it("simulates a learn through the detection, also in the login wait, kept out of the history", function()
            local client = NewClient():login()
            client.petBook = { { CLAW_2 } }
            module(client):GetOptions().args.simulate.func()
            assert.is_true(client:printedContains("Simulating: You have learned a new ability: Claw (Rank 2)."))
            settle(client)
            assert.are.equal("New pet ability: Claw (Rank 2)", client:toastTitle())
            assert.are.same({}, module(client).db.char.history)
            assert.are.same({}, module(client).db.char.known)
            settle(client:learnLine("Claw (Rank 2)"))
            assert.are.same({}, module(client).db.char.history, "the wait holds again for real lines")
        end)

        it("says so when the client has no line to simulate", function()
            local client = ready({ noLearnLines = true })
            module(client):GetOptions().args.simulate.func()
            assert.is_true(client:printedContains("This client has no learn message to imitate."))
        end)

        it("names Claw from the locale when the client cannot", function()
            local client = ready({ noSpellAPI = true })
            client.pet = nil
            module(client):GetOptions().args.test.func()
            assert.are.equal("New pet ability: Claw (Rank 2)", client:toastTitle())
            module(client):GetOptions().args.simulate.func()
            assert.is_true(client:printedContains("Claw is not a pet ability learned in the wild."))
        end)
    end)

    it("starts on the splash look", function()
        assert.are.equal("splash", ready().Addon:ToastSkinFor("AbilityLearned:learned"))
    end)

    it("does not show a learn still waiting to merge when switched off", function()
        local client = ready():learnLine("Claw (Rank 2)")
        client.Addon:SetModuleOn("AbilityLearned", false)
        settle(client)
        assert.is_nil(client:toast())
    end)

    it("drops its toasts and stops watching when switched off", function()
        local client = ready():learnLine("Claw (Rank 2)")
        settle(client)
        client.Addon:SetModuleOn("AbilityLearned", false)
        client:animate(1)
        assert.is_nil(client:toastTitle())
        settle(client:advance(10):learnLine("Bite (Rank 1)"))
        assert.is_nil(client:toastTitle())
        client:summon("Shadow", { CLAW_3 }):advance(1)
        assert.is_false(client:printedContains("Shadow can teach you"))
    end)
end)
