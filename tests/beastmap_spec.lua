-- Beast Map: a HandyNotes plugin with a pin for every beast that can teach the hunter a pet ability
-- rank. The specs use a small data set of their own instead of the generated Data\Beasts.lua.

local BITE, CHARGE, TAME_BEAST = 17253, 7371, 1515
local ELWYNN, TIRISFAL, BARRENS, STORMWIND = 1429, 1420, 1413, 1453
local BORDER = 1430 -- the simulated map right east of Elwynn Forest
local TRAINER_ICON, STABLE_ICON = 132162, 132161
local CLAW_ICON, BITE_ICON, CHARGE_ICON = 132140, 132278, 132183

---@param Addon Addon
local function SmallData(Addon)
    Addon.data = {
        petAbilityRanks = {
            [CLAW] = { ability = CLAW, rank = 1, level = 1, families = { 2 }, teachers = { 101 } },
            [CLAW_2] = { ability = CLAW, rank = 2, level = 8, families = { 2 }, teachers = { 101 } },
            [CLAW_3] = { ability = CLAW, rank = 3, level = 16, families = { 2 }, teachers = { 102, 104, 106 } },
            [BITE] = { ability = BITE, rank = 1, level = 1, families = { 1, 3 }, teachers = { 103 } },
            [CHARGE] = { ability = CHARGE, rank = 1, level = 1, families = { 5 }, teachers = { 105, 107 } },
        },
        beasts = {
            [101] = { name = "Low Cat", family = 2, minLevel = 5, maxLevel = 6, pins = { [ELWYNN] = { 40, 50 } } },
            [102] = { name = "High Cat", family = 2, minLevel = 65, maxLevel = 66, pins = { [ELWYNN] = { 60, 60 } } },
            [103] = {
                name = "Spider",
                family = 3,
                minLevel = 5,
                maxLevel = 5,
                pins = { [ELWYNN] = { 10, 10, 20, 20 } },
                radii = { [ELWYNN] = { 3, 5 } },
            },
            [104] = {
                name = "Rare Cat",
                family = 2,
                minLevel = 10,
                maxLevel = 10,
                rare = true,
                elite = true,
                pins = { [TIRISFAL] = { 30, 30 } },
            },
            [105] = { name = "Cave Boar", family = 5, minLevel = 12, maxLevel = 12, zones = { 718 } },
            -- Teaches Claw 3 like Rare Cat, but from level 11: no news at 11.
            [106] = { name = "Late Cat", family = 2, minLevel = 11, maxLevel = 11, pins = { [9999] = { 50, 50 } } },
            -- Teaches Charge like Cave Boar, at the same level, out in the open.
            [107] = { name = "Field Boar", family = 5, minLevel = 12, maxLevel = 12, pins = { [ELWYNN] = { 70, 70 } } },
        },
        -- In Stormwind, apart from the beasts' maps. The simulated hunter is Alliance.
        trainers = {
            [201] = { name = "Trainer Bob", kind = "trainer", pins = { [STORMWIND] = { 60, 70 } } },
            [202] = { name = "Stabler Sue", kind = "stable", side = "Alliance", pins = { [STORMWIND] = { 50, 50 } } },
            [203] = { name = "Horde Stabler", kind = "stable", side = "Horde", pins = { [STORMWIND] = { 40, 40 } } },
        },
    }
end

---A hunter at `level` with HandyNotes, logged in and past AbilityLearned's login wait.
---@param level number?
---@param opts TestClientOptions?
local function hunter(level, opts)
    opts = opts or {}
    opts.handyNotes = opts.handyNotes ~= false
    opts.modules = SmallData
    local client = NewClient(opts)
    client.playerLevel = level or 10
    return client:login():advance(5)
end

---The pins on a map as "x,y" -> icon.
---@param client table
---@param uiMapID number
---@return table<string, number>
local function pins(client, uiMapID)
    local out = {}
    for _, pin in ipairs(client:mapPins(uiMapID)) do
        out[pin.x .. "," .. pin.y] = pin.icon
    end
    return out
end

---Ticks or unticks a setting on the module's page, as the player would.
---@param client table
---@param key string
---@param value boolean
local function set(client, key, value)
    client.Addon:GetModule("BeastMap"):GetOptions().args[key].set(nil, value)
end

---Huntsworn's button on the world map, if it made one.
---@param client table
---@return table?
local function mapButton(client)
    for _, frame in ipairs(client.frames) do
        if frame.icon and (frame.name or ""):find("^Krowi_WorldMapButtons") then return frame end
    end
end

---The mouse over the map button: the tooltip's title and lines.
---@param client table
---@return string? title
---@return table[] lines
local function hoverMapButton(client)
    client.tooltipLines, GameTooltip.text = {}, nil
    local button = mapButton(client) --[[@as table]]
    button:GetScript("OnEnter")(button)
    return GameTooltip.text, client.tooltipLines
end

describe("Beast Map", function()
    describe("its button on the world map", function()
        it("switches the pins off and on", function()
            local client = hunter(10)
            local button = mapButton(client) --[[@as table]]
            assert.is_true(button:IsShown())
            local title, lines = hoverMapButton(client)
            assert.are.equal("Beast Map", title)
            assert.are.equal("Pins shown. Click to hide them.", lines[1].text)
            local before = client.mapUpdates.world
            button:GetScript("OnClick")(button, "LeftButton")
            assert.are.same({}, client:mapPins(ELWYNN))
            assert.are.same({}, client:mapPins(ELWYNN, true), "the minimap too")
            assert.are.equal(before + 1, client.mapUpdates.world)
            assert.is_false(client.Addon:GetModule("BeastMap"):Settings().pins)
            assert.are.equal("Pins hidden. Click to show them.", select(2, hoverMapButton(client))[1].text)
            button:GetScript("OnClick")(button, "LeftButton")
            assert.are.equal(3, #client:mapPins(ELWYNN))
            button:GetScript("OnLeave")(button)
            assert.is_false(GameTooltip:IsShown())
        end)

        it("takes its place in the row other addons' map buttons share (Krowi_WorldMapButtons)", function()
            local client = hunter(10)
            local button = mapButton(client) --[[@as table]]
            local corner = WorldMapFrame:GetCanvasContainer()
            assert.are.equal(WorldMapFrame.ScrollContainer, button.parent, "Classic's map: above its scroll frame")
            local other = LibStub("Krowi_WorldMapButtons-1.4"):Add(nil, "Button")
            other.Refresh = function() end
            assert.are.same({ "TOPRIGHT", corner, -4, -2 }, button.points[#button.points])
            assert.are.same({ "TOPRIGHT", corner, -36, -2 }, other.points[#other.points], "the next one to its left")
            set(client, "mapButton", false)
            assert.are.same({ "TOPRIGHT", corner, -4, -2 }, other.points[#other.points], "no gap where it was")
            client:showWorldMap(ELWYNN)
            assert.is_false(button:IsShown(), "a map change keeps it hidden")
        end)

        it("is a setting, also on the page; the pins switch is there too", function()
            local client = hunter(10)
            set(client, "mapButton", false)
            assert.is_false(mapButton(client):IsShown())
            set(client, "mapButton", true)
            assert.is_true(mapButton(client):IsShown())
            set(client, "pins", false)
            assert.are.same({}, client:mapPins(ELWYNN))
        end)

        it("is not there without HandyNotes, or while the module is off", function()
            assert.is_nil(mapButton(hunter(10, { handyNotes = false })))
            local client = hunter(10)
            client.Addon:GetModule("BeastMap"):Disable()
            assert.is_false(mapButton(client):IsShown())
            client.Addon:GetModule("BeastMap"):Enable()
            assert.is_true(mapButton(client):IsShown())
        end)
    end)

    it("joins HandyNotes as the Huntsworn plugin, and stays out without it", function()
        local client = hunter()
        assert.is_not_nil(HandyNotes.plugins.Huntsworn)
        assert.is_not_nil(HandyNotes.pluginOptions)
        assert.has_no.errors(function()
            hunter(10, { handyNotes = false })
        end)
    end)

    it("is for hunters only", function()
        hunter(10, { class = "MAGE" })
        assert.is_nil(HandyNotes.plugins.Huntsworn)
    end)

    it("pins the beasts at or below the hunter's level that teach a rank it lacks", function()
        local client = hunter(10)
        -- High Cat is level 65; Cave Boar lives in an instance, which has no map to pin it on.
        assert.are.same({ ["40,50"] = CLAW_ICON, ["10,10"] = BITE_ICON, ["20,20"] = BITE_ICON }, pins(client, ELWYNN))
        assert.are.same({ ["30,30"] = CLAW_ICON }, pins(client, TIRISFAL))
        assert.are.same({}, pins(client, 1411))
        assert.are.equal(3, #client:mapPins(ELWYNN, true), "the minimap too")
    end)

    it("leaves out a beast that teaches only ranks the hunter has, or lower", function()
        local client = hunter(10)
        client:openTrainer({ { "Claw", "used", CLAW_2 } }):closeTrainer()
        assert.are.same({ ["10,10"] = BITE_ICON, ["20,20"] = BITE_ICON }, pins(client, ELWYNN))
        assert.are.same({ ["30,30"] = CLAW_ICON }, pins(client, TIRISFAL), "Rare Cat teaches Claw 3")
    end)

    it("shows a missing lower rank when asked to", function()
        local client = hunter(10)
        client:openTrainer({ { "Claw", "used", CLAW }, { "Claw", "used", CLAW_3 } }):closeTrainer()
        assert.is_nil(pins(client, ELWYNN)["40,50"])
        set(client, "gaps", true)
        assert.are.equal(CLAW_ICON, pins(client, ELWYNN)["40,50"], "Low Cat teaches Claw 2")
    end)

    it("shows every beast in reach, or above the hunter's level too, when asked to", function()
        local client = hunter(10)
        client:openTrainer({ { "Claw", "used", CLAW_3 }, { "Bite", "used", BITE } }):closeTrainer()
        assert.are.same({}, pins(client, ELWYNN))
        set(client, "usefulOnly", false)
        assert.are.same({ ["40,50"] = CLAW_ICON, ["10,10"] = BITE_ICON, ["20,20"] = BITE_ICON }, pins(client, ELWYNN))
        set(client, "aboveLevel", true)
        assert.are.equal(CLAW_ICON, pins(client, ELWYNN)["60,60"])
    end)

    it("shows no beast before the hunter knows Tame Beast, unless asked to; trainers still", function()
        local client = hunter(5)
        client.unknownSpells[TAME_BEAST] = true
        client:fire("SPELLS_CHANGED")
        assert.are.same({}, pins(client, ELWYNN))
        assert.is_true(next(pins(client, STORMWIND)) ~= nil, "the trainers and stable masters")
        set(client, "untilTame", false)
        assert.are.equal(CLAW_ICON, pins(client, ELWYNN)["40,50"])
        set(client, "untilTame", true)
        client.unknownSpells[TAME_BEAST] = nil
        client:fire("SPELLS_CHANGED")
        assert.are.equal(CLAW_ICON, pins(client, ELWYNN)["40,50"], "learned at 10")
    end)

    it("indents the options that refine another, greyed while that one is off", function()
        local client = hunter(10)
        local args = client.Addon:GetModule("BeastMap"):GetOptions().args
        for parent, children in pairs({
            usefulOnly = { "gaps", "aboveLevel", "untilTame" },
            levelToast = { "levelChat" },
        }) do
            for _, key in ipairs(children) do
                local indent = args[key .. "Indent"]
                assert.are.equal("description", indent.type, key)
                assert.is_true(indent.order < args[key].order and args[key].order > args[parent].order, key)
                set(client, parent, false)
                assert.is_true(args[key].disabled(), key .. " greyed")
                set(client, parent, true)
                assert.is_false(args[key].disabled(), key)
            end
        end
    end)

    it("names the beast, its level and the ranks it teaches, green for one the hunter lacks", function()
        local client = hunter(10)
        client:openTrainer({ { "Claw", "used", CLAW } }):closeTrainer()
        local low = client:mapPins(ELWYNN)[1]
        local title, lines = client:hoverPin(ELWYNN, low.coord)
        assert.are.equal("Low Cat", title)
        assert.are.equal("Level 5-6", lines[1].text)
        assert.are.equal("Claw (Rank 1)", lines[2].text)
        assert.are.same({ 0.5, 0.5, 0.5 }, lines[2].color)
        assert.are.equal("Claw (Rank 2)", lines[3].text)
        assert.are.same({ 0, 1, 0 }, lines[3].color)
        assert.are.equal("Click to go there.", lines[#lines].text)
        local rare = client:mapPins(TIRISFAL)[1]
        title, lines = client:hoverPin(TIRISFAL, rare.coord)
        assert.are.equal("Rare Cat", title)
        assert.are.equal("Level 10, rare elite", lines[1].text)
        -- Classic Era: a tamed beast keeps its attack speed; the usual 2.0 goes unsaid.
        client.Addon.data.beasts[104].speed = 1.225
        client.Addon.data.beasts[101].speed = 2
        title, lines = client:hoverPin(TIRISFAL, rare.coord)
        assert.are.equal("Level 10, rare elite, attack speed 1.2", lines[1].text)
        _, lines = client:hoverPin(ELWYNN, low.coord)
        assert.are.equal("Level 5-6", lines[1].text)
        local spider = client:mapPins(ELWYNN)[2]
        _, lines = client:hoverPin(ELWYNN, spider.coord)
        assert.are.equal("Level 5", lines[1].text)
        assert.is_true(GameTooltip:IsShown())
        HandyNotes.plugins.Huntsworn.OnLeave()
        assert.is_false(GameTooltip:IsShown())
        assert.has_no.errors(function()
            client:hoverPin(ELWYNN, 1)
        end)
    end)

    it("names a beast as the client does, in English while the client has no name yet", function()
        local client = hunter(10)
        local low = client:mapPins(ELWYNN)[1]
        assert.are.equal("Low Cat", (client:hoverPin(ELWYNN, low.coord)))
        client.creatureNames[101] = "Kleine Katze"
        assert.are.equal("Kleine Katze", (client:hoverPin(ELWYNN, low.coord)))
        client:clickPin(ELWYNN, low.coord)
        assert.is_true(client:printedContains("Kleine Katze"), "the label of the target")
        client = hunter(11)
        client.creatureNames[105] = "Höhleneber"
        client:fire("PLAYER_LEVEL_UP", 12)
        assert.are.equal("Höhleneber in Wailing Caverns teaches it.", client:toast().Text.text)
    end)

    it("pins the beasts in a dungeon at its entrance, named in the tooltip", function()
        local client = hunter(11)
        assert.are.same({}, client:mapPins(BARRENS), "Cave Boar is level 12")
        client = hunter(12)
        local pin = client:mapPins(BARRENS)[1]
        assert.are.equal(1, #client:mapPins(BARRENS), "Razorfen Kraul has no beast in the data")
        assert.are.same({ 46, 36, CHARGE_ICON }, { pin.x, pin.y, pin.icon })
        local title, lines = client:hoverPin(BARRENS, pin.coord)
        assert.are.equal("Wailing Caverns", title)
        assert.are.equal("Cave Boar: Level 12", lines[1].text)
        assert.are.same({ 1, 1, 1 }, lines[1].color)
        assert.are.equal("Charge (Rank 1)", lines[2].text)
        assert.are.same({ 0, 1, 0 }, lines[2].color)
        assert.are.equal("Click to go there.", lines[#lines].text)
        client:clickPin(BARRENS, pin.coord)
        assert.is_true(client:printedContains("46.0, 36.0"), "to the entrance")
        assert.is_true(client:printedContains("Wailing Caverns"))
    end)

    it("finds a dungeon's entrances by name also when they word it otherwise than its area", function()
        local client = hunter(12)
        local data = client.Addon.data
        data.beasts[108] = { name = "Spire Hound", family = 5, minLevel = 12, maxLevel = 12, zones = { 1583 } }
        data.beasts[109] = { name = "Temple Boar", family = 5, minLevel = 12, maxLevel = 12, zones = { 1417 } }
        data.petAbilityRanks[CHARGE].teachers = { 105, 107, 108, 109 }
        local steppes = {}
        for _, pin in ipairs(client:mapPins(1428)) do
            steppes[#steppes + 1] = pin.x .. "," .. pin.y
        end
        table.sort(steppes)
        assert.are.same({ "20,30", "21,31" }, steppes, "Lower and Upper Blackrock Spire, not Blackrock Depths")
        local temple = client:mapPins(1435)
        assert.are.equal(1, #temple, "Sunken Temple: The Temple of Atal'Hakkar")
        assert.are.same({ 70, 54 }, { temple[1].x, temple[1].y })
    end)

    describe("on a beast's tooltip", function()
        ---A creature's GUID, as the client gives it.
        local function creature(npc)
            return ("Creature-0-5250-0-12-%d-0000ABCDEF"):format(npc)
        end

        it("says what it teaches and whether the hunter lacks it", function()
            local client = hunter(10)
            client:openTrainer({ { "Claw", "used", CLAW } }):closeTrainer()
            local lines = client:hoverUnit(creature(101))
            assert.are.equal("|T132140:0|t Teaches Claw (Rank 1): known", lines[1].text, "with the ability's icon")
            assert.are.same({ 0.5, 0.5, 0.5 }, lines[1].color)
            assert.are.equal("|T132140:0|t Teaches Claw (Rank 2): new", lines[2].text)
            assert.are.same({ 0, 1, 0 }, lines[2].color)
        end)

        it("names a lower rank the hunter never learned", function()
            local client = hunter(20)
            client:openTrainer({ { "Claw", "used", CLAW }, { "Claw", "used", CLAW_3 } }):closeTrainer()
            local lines = client:hoverUnit(creature(101))
            assert.are.equal("|T132140:0|t Teaches Claw (Rank 2): skipped", lines[2].text)
            assert.are.same({ 1, 1, 0 }, lines[2].color)
        end)

        it("says nothing on another unit, a hidden GUID, another tooltip, or switched off", function()
            local client = hunter(10)
            assert.are.same({}, client:hoverUnit(creature(999)), "a beast that teaches nothing")
            assert.are.same({}, client:hoverUnit("Player-5250-0ABCDEF0"))
            assert.are.same({}, client:hoverUnit(SECRET))
            assert.are.same({}, client:hoverUnit(creature(101), {}), "a tooltip other than the game's")
            set(client, "tooltip", false)
            assert.are.same({}, client:hoverUnit(creature(101)))
            set(client, "tooltip", true)
            client.Addon:GetModule("BeastMap"):Disable()
            assert.are.same({}, client:hoverUnit(creature(101)))
            assert.are.same({}, hunter(10, { class = "MAGE" }):hoverUnit(creature(101)))
        end)

        it("says the attack speed of any tameable beast where it is not 2.0, teaching or not", function()
            local client = hunter(10)
            local data = client.Addon.data
            data.speeds = { [525] = 1.7 }
            data.beasts[101].speed = 1.2
            data.beasts[103].speed = 2
            local lines = client:hoverUnit(creature(525))
            assert.are.equal(1, #lines, "a beast that teaches nothing")
            assert.are.same({ "Attack speed 1.7", { 1, 1, 1 } }, { lines[1].text, lines[1].color })
            assert.are.equal("Attack speed 1.2", client:hoverUnit(creature(101))[1].text, "a teacher, first")
            assert.are.equal(
                "|T132278:0|t Teaches Bite (Rank 1): new",
                client:hoverUnit(creature(103))[1].text,
                "2.0: nothing"
            )
        end)

        it("is there without HandyNotes too", function()
            local lines = hunter(10, { handyNotes = false }):hoverUnit(creature(101))
            assert.are.equal("|T132140:0|t Teaches Claw (Rank 2): new", lines[2].text)
        end)
    end)

    describe("on a pet ability's tooltip", function()
        local WHITE, GREY, GREEN, YELLOW = { 1, 1, 1 }, { 0.5, 0.5, 0.5 }, { 0, 1, 0 }, { 1, 1, 0 }

        ---The lines' texts and colours, for one comparison.
        ---@param lines table[]
        ---@return table[]
        local function shown(lines)
            local out = {}
            for i, line in ipairs(lines) do
                out[i] = { line.text, line.color }
            end
            return out
        end

        it("says the pet level, the families, and the beasts that teach a rank the hunter lacks", function()
            local client = hunter(10)
            client:openTrainer({ { "Claw", "used", CLAW } }):closeTrainer()
            assert.are.same({
                { "Pet level 16", WHITE },
                { "Families: Cat", WHITE },
                { "Tame one of these beasts, then let it use the ability:", GREEN },
                { "Rare Cat in Tirisfal Glades: Level 10, rare elite", WHITE },
                { "Late Cat: Level 11", GREY },
                { "High Cat in Elwynn Forest: Level 65-66", GREY },
            }, shown(client:hoverSpell(CLAW_3)), "those in reach first; above the hunter's level in grey")
        end)

        it("names every family that learns it, and lists a few beasts and how many more", function()
            local client = hunter(10)
            local data = client.Addon.data
            data.beasts[108] = { name = "Far Wolf", family = 1, minLevel = 70, maxLevel = 70, zones = { 718 } }
            data.beasts[109] = { name = "Farther Wolf", family = 1, minLevel = 71, maxLevel = 71, zones = { 718 } }
            data.petAbilityRanks[BITE].teachers = { 103, 108, 109, 101, 105 }
            local lines = client:hoverSpell(BITE)
            assert.are.equal("Families: Wolf, Spider", lines[2].text)
            assert.are.equal(7, #lines, "three beasts and the count")
            assert.are.same({ "2 more in Huntsworn's Abilities tab.", GREY }, shown(lines)[7])
        end)

        it("says so for a rank the hunter knows, and in yellow for a lower one it skipped", function()
            local client = hunter(20)
            client:openTrainer({ { "Claw", "used", CLAW }, { "Claw", "used", CLAW_3 } }):closeTrainer()
            assert.are.same({
                { "Pet level 1", WHITE },
                { "Families: Cat", WHITE },
                { "You know this rank.", GREY },
            }, shown(client:hoverSpell(CLAW)))
            local skipped = shown(client:hoverSpell(CLAW_2))
            assert.are.same(
                { "You skipped this rank. Tame one of these beasts, then let it use the ability:", YELLOW },
                skipped[3]
            )
            assert.are.equal("Low Cat in Elwynn Forest: Level 5-6", skipped[4][1])
        end)

        it("is on the pet bar's tooltip too", function()
            local lines = hunter(10):hoverPetAction(4)
            assert.are.equal("Pet level 8", lines[1].text)
        end)

        it("says nothing on another spell, another tooltip, or switched off", function()
            local client = hunter(10)
            assert.are.same({}, client:hoverSpell(2649), "Growl: no beast teaches it")
            assert.are.same({}, client:hoverSpell(CLAW, {}), "a tooltip other than the game's")
            set(client, "spellTooltip", false)
            assert.are.same({}, client:hoverSpell(CLAW))
            set(client, "spellTooltip", true)
            client.Addon:GetModule("BeastMap"):Disable()
            assert.are.same({}, client:hoverSpell(CLAW))
            assert.are.same({}, hunter(10, { class = "MAGE" }):hoverSpell(CLAW))
        end)

        describe("on Classic Era", function()
            it("works through the tooltip's spell script, the pet bar, and Beast Training with its cost", function()
                local client = hunter(10, { era = true })
                assert.are.equal("Pet level 16", client:hoverSpell(CLAW_3)[1].text)
                assert.are.same({}, client:hoverSpell(CLAW_3, { hooks = {} }), "a tooltip other than the game's")
                assert.are.equal("Pet level 8", client:hoverPetAction(4)[1].text)
                assert.are.same({}, client:hoverPetAction(1), "Attack")
                client:openCraft({ { "Growl", "", "used", 0, 1 }, { "Claw", "Rank 2", "used", 10, 8 } })
                assert.are.same({
                    { "Pet level 8, 10 training points", WHITE },
                    { "Families: Cat", WHITE },
                    { "You know this rank.", GREY },
                }, shown(client:hoverCraft(2)))
                assert.are.same({}, client:hoverCraft(1), "Growl")
            end)

            it("adds the lines once when the client also runs the spell script", function()
                local client = hunter(10, { era = true })
                GameTooltip.spell = CLAW_2
                local lines = client:hoverPetAction(4)
                GameTooltip.spell = nil
                assert.are.same({}, lines, "the spell script's turn, not run here")
            end)
        end)
    end)

    describe("the tame key", function()
        local TARGET_RARE_CAT = "/cast [mod:shift] Tame Beast\n/stopmacro [mod:shift]\n/targetexact Rare Cat\n/tm 8"

        ---The key's release, as the client runs a key binding's click.
        local function press(client)
            local button = _G.HuntswornTameButton
            for _, hook in ipairs(button.hooks.OnClick or {}) do
                hook(button, "LeftButton", false)
            end
            return client
        end

        it("targets and marks the beast the rare alarm named; Shift tames it", function()
            local client = hunter(10)
            client.unitGUIDs.nameplate1 = "Creature-0-5250-0-12-104-0000ABCDEF"
            client:fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
            assert.are.equal(TARGET_RARE_CAT, _G.HuntswornTameButton.attributes.macrotext)
            assert.are.equal("macro", _G.HuntswornTameButton.attributes.type)
            assert.is_true(client:printedContains("The tame key now targets Rare Cat."))
            assert.are.equal(
                "Beast Map: target and mark the beast to tame",
                _G["BINDING_NAME_CLICK HuntswornTameButton:LeftButton"]
            )
        end)

        it("takes the beast whose pin was clicked, after combat when in it", function()
            local client = hunter(10):enterCombat()
            client:clickPin(TIRISFAL, client:mapPins(TIRISFAL)[1].coord)
            assert.is_nil(_G.HuntswornTameButton.attributes.macrotext)
            client:leaveCombat()
            assert.are.equal(TARGET_RARE_CAT, _G.HuntswornTameButton.attributes.macrotext)
        end)

        it("says how to set a beast when there is none yet, and stays empty while switched off", function()
            local client = press(hunter(10))
            assert.is_true(client:printedContains("No beast to target yet"))
            client.Addon:GetModule("BeastMap"):Disable()
            client:clickPin(TIRISFAL, 1)
            assert.is_nil(_G.HuntswornTameButton.attributes.macrotext)
        end)
    end)

    describe("the hunt", function()
        ---The Abilities tab on `ability`'s row (its index in the list).
        local function abilities(client, index)
            client.Addon:OpenWindow("abilities")
            local panel = client.Addon.window.panels.abilities
            local row = panel.rows[index]
            row:GetScript("OnClick")(row, "LeftButton")
            return panel
        end

        ---Clicks a button by its script.
        local function click(button)
            button:GetScript("OnClick")(button, "LeftButton")
        end

        ---What HUNTSWORN_HUNT_STARTED and HUNTSWORN_HUNT_ENDED told, in order.
        local function heard(client)
            local events = {}
            local listener = {}
            for _, message in ipairs({ "HUNTSWORN_HUNT_STARTED", "HUNTSWORN_HUNT_ENDED" }) do
                client.Addon:Listen(listener, message, function(_, event)
                    events[#events + 1] = { message, event }
                end)
            end
            return events
        end

        it("starts from a rank's button: the route, the tame key, a line in chat, a message", function()
            local client = hunter(10)
            local events = heard(client)
            local panel = abilities(client, 3)
            click(panel.ranks[3].go)
            local M = client.Addon:GetModule("BeastMap")
            assert.are.same({ npc = 104, spellID = CLAW_3 }, M.db.char.hunt, "kept for the character")
            assert.is_true(client:printedContains("Hunting Rare Cat for Claw (Rank 3)."))
            assert.is_true(client:printedContains("Tirisfal Glades 30.0, 30.0"), "the route")
            assert.are.equal("Rare Cat", M.tameTarget)
            assert.are.equal("HUNTSWORN_HUNT_STARTED", events[1][1])
            assert.are.same({ module = "BeastMap", npc = 104, spellID = CLAW_3, name = "Rare Cat" }, events[1][2])
            assert.is_true(panel.ranks[3].go.active.shown, "the hunted rank's button lit")
        end)

        it("shows the tame key's button on screen while hunting, movable, and hides it after", function()
            local client = hunter(10)
            local button = _G.HuntswornTameButton
            assert.is_false(button:IsShown(), "no hunt yet")
            local panel = abilities(client, 3)
            click(panel.ranks[3].go)
            assert.is_true(button:IsShown())
            assert.are.equal(132164, button.icon.texture, "Tame Beast's icon")
            client.tooltipLines, GameTooltip.text = {}, nil
            button:GetScript("OnEnter")(button)
            assert.are.equal("Rare Cat", GameTooltip.text)
            assert.are.equal(
                "Click: target and mark. Shift-click: Tame Beast. Right-click: stop the hunt. Shift-drag to move.",
                client.tooltipLines[1].text
            )
            button:GetScript("OnLeave")(button)
            assert.is_false(GameTooltip:IsShown())
            client.mods.shift = true
            button:GetScript("OnDragStart")(button)
            button:GetScript("OnDragStop")(button)
            local M = client.Addon:GetModule("BeastMap")
            assert.are.same({ "TOPLEFT", "BOTTOMLEFT", 300, 700 }, M.db.profile.tamePosition)
            click(panel.ranks[3].go)
            assert.is_false(button:IsShown(), "the hunt stopped")
            click(panel.ranks[3].go)
            assert.are.same({ "TOPLEFT", UIParent, "BOTTOMLEFT", 300, 700 }, { button:GetPoint() }, "where it was put")
            M:GetOptions().args.tameButton.set(nil, false)
            assert.is_false(button:IsShown(), "switched off, at once")
        end)

        it("stops on that button again, or with /huntsworn hunt stop", function()
            local client = hunter(10)
            local events = heard(client)
            local panel = abilities(client, 3)
            click(panel.ranks[3].go)
            click(panel.ranks[3].go)
            local M = client.Addon:GetModule("BeastMap")
            assert.is_nil(M.db.char.hunt)
            assert.is_true(client:printedContains("Stopped hunting Rare Cat."))
            assert.are.same(
                { module = "BeastMap", npc = 104, spellID = CLAW_3, name = "Rare Cat", reason = "stopped" },
                events[2][2]
            )
            assert.is_false(panel.ranks[3].go.active.shown)
            client:advance(1) -- the minimap's redraws stop with the hunt
            click(panel.ranks[3].go)
            client:slash("hunt stop")
            assert.is_nil(M.db.char.hunt)
            client.printed = {}
            client:slash("hunt stop")
            assert.is_true(client:printedContains("Not hunting a beast."))
        end)

        it("stops on a right-click on the tame key's button, after combat when in it", function()
            local client = hunter(10)
            click(abilities(client, 3).ranks[3].go)
            local button = _G.HuntswornTameButton
            -- SecureActionButtonTemplate runs the button's own function named by type2 for the
            -- right button, instead of the macro its type gives every button.
            local handler = button.attributes.type2
            assert.are.equal("function", type(rawget(button, handler)))
            client:enterCombat()
            rawget(button, handler)(button, nil, "RightButton")
            local M = client.Addon:GetModule("BeastMap")
            assert.is_nil(M.db.char.hunt)
            assert.is_true(client:printedContains("Stopped hunting Rare Cat."))
            assert.is_true(button:IsShown(), "hidden only after combat")
            client:leaveCombat()
            assert.is_false(button:IsShown())
        end)

        ---Tame Beast brings beast `npc` as the pet.
        local function tame(client, npc)
            client:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", TAME_BEAST)
            client.petGUID = ("Pet-0-5250-0-1-%d-0100ABCDEF"):format(npc)
            return client:summon("Whiskers", {})
        end

        it("ends when a beast that teaches the rank is tamed, the hunted one or another", function()
            local client = hunter(10)
            local events = heard(client)
            click(abilities(client, 3).ranks[3].go) -- Rare Cat, Claw 3
            local M = client.Addon:GetModule("BeastMap")
            tame(client, 103) -- Spider: Bite only
            assert.is_not_nil(M.db.char.hunt)
            tame(client, 106) -- Late Cat: Claw 3 too
            assert.is_nil(M.db.char.hunt)
            assert.is_true(
                client:printedContains(
                    "Tamed Whiskers, which teaches Claw (Rank 3): the hunt for Rare Cat is over. Let it use the ability to learn it."
                )
            )
            assert.are.equal("tamed", events[2][2].reason)
        end)

        it("goes on after such a tame with its switch off", function()
            local client = hunter(10)
            set(client, "huntEndsAtTame", false)
            click(abilities(client, 3).ranks[3].go)
            tame(client, 104)
            assert.is_not_nil(client.Addon:GetModule("BeastMap").db.char.hunt)
        end)

        it("ends the hunt on when another starts", function()
            local client = hunter(10)
            local events = heard(client)
            local panel = abilities(client, 3)
            click(panel.ranks[3].go) -- Rare Cat, Claw 3
            click(abilities(client, 1).ranks[1].go) -- Spider, Bite 1
            assert.are.same({ "HUNTSWORN_HUNT_STARTED", "HUNTSWORN_HUNT_ENDED", "HUNTSWORN_HUNT_STARTED" }, {
                events[1][1],
                events[2][1],
                events[3][1],
            })
            assert.are.equal("Rare Cat", events[2][2].name)
            assert.are.same({ npc = 103, spellID = BITE }, client.Addon:GetModule("BeastMap").db.char.hunt)
        end)

        it("ends once the hunter knows the rank", function()
            local client = hunter(10)
            local events = heard(client)
            click(abilities(client, 3).ranks[3].go)
            client:openTrainer({ { "Claw", "used", CLAW_3 } }):closeTrainer()
            assert.is_nil(client.Addon:GetModule("BeastMap").db.char.hunt)
            assert.is_true(client:printedContains("Learned Claw (Rank 3): the hunt for Rare Cat is over."))
            assert.are.equal("learned", events[2][2].reason)
        end)

        it("starts from a beast's pin, for the rank its pin shows, going to that pin", function()
            local client = hunter(10)
            local spider = client:mapPins(ELWYNN)
            local pin
            for _, p in ipairs(spider) do
                if p.x == 20 then pin = p end
            end
            client:clickPin(ELWYNN, pin.coord)
            assert.are.same({ npc = 103, spellID = BITE }, client.Addon:GetModule("BeastMap").db.char.hunt)
            assert.is_true(client:printedContains("Elwynn Forest 20.0, 20.0"))
        end)

        ---The areas shown in one of Beast Map's pools (worldAreas, minimapAreas): where each sits
        ---(its CENTER's offset) and its size.
        local function shownAreas(client, pool)
            local out = {}
            for _, disc in ipairs(client.Addon:GetModule("BeastMap")[pool] or {}) do
                if disc.shown then
                    local point = disc.points[#disc.points]
                    out[#out + 1] = { x = point[4], y = point[5], width = disc.width, height = disc.height }
                end
            end
            return out
        end

        ---@param actual number
        ---@param expected number
        local function near(actual, expected, what)
            assert.is_true(math.abs(actual - expected) < 0.01, ("%s: %s, not %s"):format(what, actual, expected))
        end

        it("marks the hunted beast's areas on the world map, only on its own map", function()
            local client = hunter(10)
            client:showWorldMap(ELWYNN)
            assert.are.same({}, shownAreas(client, "worldAreas"), "no hunt, no areas")
            click(abilities(client, 1).ranks[1].go) -- Spider, Bite 1
            local areas = shownAreas(client, "worldAreas")
            -- Its two pins on a 1000 by 667 canvas, with radius 3 and 5 (percent).
            assert.are.equal(2, #areas)
            near(areas[1].x, 100, "x")
            near(areas[1].y, -66.7, "y")
            near(areas[1].width, 60, "width")
            near(areas[1].height, 40.02, "height")
            near(areas[2].width, 100, "width")
            client:showWorldMap(TIRISFAL)
            assert.are.same({}, shownAreas(client, "worldAreas"), "not on another map")
            client:showWorldMap(ELWYNN)
            client:slash("hunt stop")
            assert.are.same({}, shownAreas(client, "worldAreas"))
        end)

        it("marks them on the minimap too, around where the hunter stands", function()
            local client = hunter(10)
            client.mapPos = { 0.15, 0.10 }
            click(abilities(client, 1).ranks[1].go)
            client:advance(1)
            -- Elwynn is 3470 by 2314 yards; the minimap, 140 wide, shows 466.67 yards across.
            local perYard = 140 / (1400 / 3)
            local east, south = 34.7 * perYard, 23.14 * perYard
            local across = (34.7 + 23.14) / 2 * perYard
            local areas = shownAreas(client, "minimapAreas")
            assert.are.equal(2, #areas)
            near(areas[1].x, -5 * east, "5% west")
            near(areas[1].y, 0, "level with the hunter")
            near(areas[1].width, 2 * 3 * across, "radius 3%")
            near(areas[2].x, 5 * east, "5% east")
            near(areas[2].y, -10 * south, "10% south")
            near(areas[2].width, 2 * 5 * across, "radius 5%")
            client.cvars.rotateMinimap = "1"
            client.facing = math.pi / 2 -- facing west: west is up
            client:advance(1)
            areas = shownAreas(client, "minimapAreas")
            near(areas[1].x, 0, "rotated")
            near(areas[1].y, 5 * east, "west is up")
        end)

        it("leaves the minimap when the hunter is on another map", function()
            local client = hunter(10)
            client.mapPos = nil
            click(abilities(client, 1).ranks[1].go)
            client:advance(1)
            assert.are.same({}, shownAreas(client, "minimapAreas"))
        end)
    end)

    describe("pet trainers and stable masters", function()
        it("have a pin each, for the hunter's faction or both", function()
            local client = hunter(10)
            assert.are.same({ ["60,70"] = TRAINER_ICON, ["50,50"] = STABLE_ICON }, pins(client, STORMWIND))
        end)

        it("say what they are in the tooltip, and a click goes there", function()
            local client = hunter(10)
            local trainer, stable = client:mapPins(STORMWIND)[1], client:mapPins(STORMWIND)[2]
            local title, lines = client:hoverPin(STORMWIND, trainer.coord)
            assert.are.equal("Trainer Bob", title)
            assert.are.equal("Pet Trainer", lines[1].text)
            assert.are.equal("Click to go there.", lines[#lines].text)
            title, lines = client:hoverPin(STORMWIND, stable.coord)
            assert.are.equal("Stabler Sue", title)
            assert.are.equal("Stable Master", lines[1].text)
            client:clickPin(STORMWIND, stable.coord)
            assert.is_true(client:printedContains("Stabler Sue"))
        end)

        it("each have a switch", function()
            local client = hunter(10)
            set(client, "trainers", false)
            assert.are.same({ ["50,50"] = STABLE_ICON }, pins(client, STORMWIND))
            set(client, "stables", false)
            assert.are.same({}, pins(client, STORMWIND))
        end)
    end)

    describe("the rare alarm", function()
        local RARE_CAT = "Creature-0-5250-0-12-104-0000ABCDEF"

        ---The toasts shown from now on.
        local function toasts(client)
            local seen = {}
            client.Addon.RegisterMessage(seen, "HUNTSWORN_TOAST", function(_, event)
                seen[#seen + 1] = event.toast
            end)
            return seen
        end

        ---A nameplate showing the unit with this GUID.
        local function nameplate(client, guid)
            client.unitGUIDs.nameplate1 = guid
            return client:fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
        end

        it("toasts a rare beast that teaches a rank the hunter lacks, once per spawn", function()
            local client = hunter(10)
            local seen = toasts(client)
            nameplate(client, RARE_CAT)
            assert.are.equal(1, #seen)
            local toast = seen[1]
            assert.are.equal("BeastMap:rare", toast.type)
            assert.are.equal("Rare beast nearby: Rare Cat", toast.title)
            assert.are.equal("Teaches Claw (Rank 3)", toast.text)
            assert.are.equal("Level 10, rare elite", toast.hint)
            assert.are.equal(CLAW_ICON, toast.icon)
            nameplate(client, RARE_CAT)
            client.unitGUIDs.target = RARE_CAT
            client:fire("PLAYER_TARGET_CHANGED")
            assert.are.equal(1, #seen, "the same spawn")
            nameplate(client, "Creature-0-5250-0-12-104-0000FEDCBA")
            assert.are.equal(2, #seen, "another spawn")
        end)

        it("waits for Beast Training: before it, a beast can teach the hunter nothing", function()
            local client = hunter(10)
            client.unknownSpells[5149] = true -- Beast Training comes with the quest Training the Beast
            local seen, heard = toasts(client), {}
            client.Addon:Listen(heard, "HUNTSWORN_RARE_SEEN", function(_, event)
                heard[#heard + 1] = event
            end)
            nameplate(client, RARE_CAT)
            assert.are.same({}, seen)
            assert.are.same({}, heard)
            client.unknownSpells[5149] = nil
            client:fire("SPELLS_CHANGED")
            nameplate(client, RARE_CAT)
            assert.are.equal(1, #seen, "the same spawn, once it can teach")
        end)

        it("is told to other addons as HUNTSWORN_RARE_SEEN, also with the toast off", function()
            local client = hunter(10)
            local heard = {}
            client.Addon:Listen(heard, "HUNTSWORN_RARE_SEEN", function(_, event)
                heard[#heard + 1] = event
            end)
            local seen = toasts(client)
            set(client, "rareToast", false)
            nameplate(client, RARE_CAT)
            nameplate(client, RARE_CAT)
            assert.are.same({}, seen)
            assert.are.same({
                { module = "BeastMap", npc = 104, name = "Rare Cat", guid = RARE_CAT, ranks = { CLAW_3 } },
            }, heard)
        end)

        it("sees it as a target, under the mouse, or on the minimap", function()
            local client = hunter(10)
            local seen = toasts(client)
            client.unitGUIDs.target = RARE_CAT
            client:fire("PLAYER_TARGET_CHANGED")
            assert.are.equal(1, #seen)
            client = hunter(10)
            seen = toasts(client)
            client.unitGUIDs.mouseover = RARE_CAT
            client:fire("UPDATE_MOUSEOVER_UNIT")
            assert.are.equal(1, #seen)
            client = hunter(10)
            seen = toasts(client)
            client.vignettes["Vignette-1"] = { objectGUID = RARE_CAT, name = "Rare Cat" }
            client:fire("VIGNETTE_MINIMAP_UPDATED", "Vignette-1", true)
            client:fire("VIGNETTE_MINIMAP_UPDATED", "Vignette-2", true)
            assert.are.equal(1, #seen)
        end)

        it(
            "stays quiet for an ordinary beast, a rank the hunter has, a beast above its level, or switched off",
            function()
                local client = hunter(10)
                local seen = toasts(client)
                nameplate(client, "Creature-0-5250-0-12-101-0000ABCDEF")
                nameplate(client, "Player-5250-0ABCDEF0")
                nameplate(client, SECRET)
                assert.are.same({}, seen)
                client = hunter(10)
                client:openTrainer({ { "Claw", "used", CLAW_3 } }):closeTrainer()
                seen = toasts(client)
                nameplate(client, RARE_CAT)
                assert.are.same({}, seen, "Claw 3 known")
                client = hunter(9)
                seen = toasts(client)
                nameplate(client, RARE_CAT)
                assert.are.same({}, seen, "level 10, the hunter 9")
                set(client, "aboveLevel", true)
                nameplate(client, RARE_CAT)
                assert.are.equal(1, #seen, "when beasts above the hunter's level count")
                client = hunter(10)
                seen = toasts(client)
                set(client, "rareToast", false)
                nameplate(client, RARE_CAT)
                client.Addon:GetModule("BeastMap"):Disable()
                set(client, "rareToast", true)
                nameplate(client, "Creature-0-5250-0-12-104-0000FEDCBA")
                assert.are.same({}, seen)
            end
        )
    end)

    describe("the Abilities tab", function()
        ---The tab, opened in Huntsworn's window.
        local function tab(client)
            client.Addon:OpenWindow("abilities")
            return client.Addon.window.panels.abilities
        end

        ---The shown rows' label texts of a list.
        local function texts(rows, field)
            local out = {}
            for _, row in ipairs(rows) do
                if row.shown then out[#out + 1] = row[field or "label"].text end
            end
            return out
        end

        ---Clicks a button by its script.
        local function click(button)
            button:GetScript("OnClick")(button, "LeftButton")
        end

        it("lists every ability with how many of its ranks the hunter knows", function()
            local client = hunter(10)
            client:openTrainer({ { "Claw", "used", CLAW } }):closeTrainer()
            local panel = tab(client)
            assert.are.same({ "Bite", "Charge", "Claw" }, texts(panel.rows))
            assert.are.same({ "0/1", "0/1", "1/3" }, texts(panel.rows, "count"))
            assert.are.equal("Bite", panel.title.text, "the first is chosen")
            assert.are.equal(BITE_ICON, panel.rows[1].icon.texture, "each with its icon")
            assert.are.equal(CLAW_ICON, panel.rows[3].icon.texture)
            assert.are.equal(BITE_ICON, panel.titleIcon.texture)
        end)

        it("marks with a quest giver's ! an ability with a rank to learn now, its tooltip saying which", function()
            local client = hunter(10)
            client:openTrainer({ { "Claw", "used", CLAW } }):closeTrainer()
            local panel = tab(client)
            local marks = {}
            for i = 1, 3 do
                marks[i] = panel.rows[i].learnable.shown
            end
            -- Bite from the Spider (5); Charge only from level-12 boars; Claw 2 from Low Cat (5), Claw 3
            -- from Rare Cat (10).
            assert.are.same({ true, false, true }, marks)
            assert.are.equal("Interface\\GossipFrame\\AvailableQuestIcon", panel.rows[1].learnable.texture)
            ---The tooltip over a row: its title, then its lines.
            local function hover(row)
                client.tooltipLines, GameTooltip.text = {}, nil
                row:GetScript("OnEnter")(row)
                local lines = { GameTooltip.text }
                for _, line in ipairs(client.tooltipLines) do
                    lines[#lines + 1] = line.text
                end
                return lines
            end
            assert.are.same({ "Claw", "Known: Rank 1", "Learn now: Rank 2, Rank 3" }, hover(panel.rows[3]))
            assert.are.same({ "Charge", "Known: none" }, hover(panel.rows[2]))
            panel.rows[2]:GetScript("OnLeave")(panel.rows[2])
            assert.is_false(GameTooltip:IsShown())
        end)

        it("marks the chosen ability with a bar, and a fully known one in green", function()
            local client = hunter(10)
            client:openTrainer({ { "Bite", "used", BITE } }):closeTrainer()
            local panel = tab(client)
            click(panel.rows[3])
            assert.is_false(panel.rows[1].selected.shown)
            assert.is_true(panel.rows[3].selected.shown, "Claw")
            assert.are.same({ 0.25, 1, 0.25 }, panel.rows[1].count.textColor, "Bite: every rank known")
            assert.are.same({ 0.6, 0.6, 0.6 }, panel.rows[3].count.textColor)
        end)

        it("heads the ranks' columns, keeps each rank on one line, and stripes every other row", function()
            local client = hunter(10)
            local panel = tab(client)
            click(panel.rows[3])
            assert.are.same(
                { "Rank", "Pet level", "Nearest teacher" },
                { panel.header.rank.text, panel.header.level.text, panel.header.text.text }
            )
            for _, row in ipairs(panel.ranks) do
                assert.is_false(row.text.wordWrap)
            end
            assert.is_false(panel.ranks[1].stripe.shown)
            assert.is_true(panel.ranks[2].stripe.shown)
        end)

        it("draws the plus and minus as ElvUI's own with ElvUI loaded", function()
            local client = hunter(10, { elvui = true })
            local panel = tab(client)
            click(panel.rows[3])
            local claw3 = panel.ranks[3]
            assert.are.equal(ElvUI[1].Media.Textures.PlusButton, claw3.toggle.texture)
            click(claw3)
            assert.are.equal(ElvUI[1].Media.Textures.MinusButton, claw3.toggle.texture)
        end)

        it("unfolds a rank to every beast that teaches it, each with its own hunt button", function()
            local client = hunter(10)
            local panel = tab(client)
            click(panel.rows[3])
            local claw3 = panel.ranks[3]
            assert.is_true(claw3.toggle.shown, "three beasts teach Claw 3")
            assert.is_false(panel.ranks[1].toggle.shown, "one teaches Claw 1")
            assert.is_false(panel.ranks[4].shown)
            assert.are.equal("Interface\\Buttons\\UI-PlusButton-Up", claw3.toggle.texture)
            click(claw3)
            assert.are.equal("Interface\\Buttons\\UI-MinusButton-Up", claw3.toggle.texture)
            assert.are.same({ "Rank 1", "Rank 2", "Rank 3", "", "", "" }, texts(panel.ranks, "rank"))
            assert.are.same(
                { "Rare Cat in Tirisfal Glades", "Late Cat", "High Cat in Elwynn Forest" },
                { panel.ranks[4].text.text, panel.ranks[5].text.text, panel.ranks[6].text.text },
                "nearest first"
            )
            assert.are.same({ "10", "11", "65-66" }, {
                panel.ranks[4].level.text,
                panel.ranks[5].level.text,
                panel.ranks[6].level.text,
            }, "the beasts' levels")
            assert.are.same({ 1, 0.6, 0.3 }, panel.ranks[6].text.textColor, "above the hunter's level")
            click(panel.ranks[6].go)
            assert.are.same({ npc = 102, spellID = CLAW_3 }, client.Addon:GetModule("BeastMap").db.char.hunt)
            assert.is_true(panel.ranks[6].go.active.shown)
            click(panel.ranks[3])
            assert.is_false(panel.ranks[4].shown, "folded again")
        end)

        it("scrolls a long list with the mouse wheel", function()
            local client = hunter(70)
            local beasts, teachers = client.Addon.data.beasts, {}
            for i = 1, 20 do
                beasts[400 + i] =
                    { name = "Cat " .. i, family = 2, minLevel = 10, maxLevel = 10, pins = { [ELWYNN] = { i, 50 } } }
                teachers[i] = 400 + i
            end
            client.Addon.data.petAbilityRanks[CLAW].teachers = teachers
            local panel = tab(client)
            click(panel.rows[3])
            click(panel.ranks[1])
            assert.are.equal("Rank 1", panel.ranks[1].rank.text)
            local wheel = panel:GetScript("OnMouseWheel")
            wheel(panel, -1)
            assert.are.equal("", panel.ranks[1].rank.text, "one line down: a beast of Claw 1")
            for _ = 1, 30 do
                wheel(panel, -1)
            end
            assert.are.equal("Rank 3", panel.ranks[#panel.ranks].rank.text, "no further than the last line")
            wheel(panel, 1)
            for _ = 1, 30 do
                wheel(panel, 1)
            end
            assert.are.equal("Rank 1", panel.ranks[1].rank.text)
        end)

        it("names a rank's go button in its tooltip", function()
            local client = hunter(10)
            local panel = tab(client)
            click(panel.rows[3])
            local go = panel.ranks[3].go
            go:GetScript("OnEnter")(go)
            assert.are.equal("Hunt Rare Cat: the way there, the tame key, its areas on the map", GameTooltip.text)
            click(go)
            go:GetScript("OnEnter")(go)
            assert.are.equal("Stop hunting Rare Cat", GameTooltip.text)
            go:GetScript("OnLeave")(go)
            assert.is_false(GameTooltip.shown)
        end)

        it("shows every rank: its pet level, known, or the nearest beast that teaches it", function()
            local client = hunter(10)
            client:openTrainer({ { "Claw", "used", CLAW } }):closeTrainer()
            local panel = tab(client)
            click(panel.rows[3])
            assert.are.equal("Claw", panel.title.text)
            assert.are.same({ "Rank 1", "Rank 2", "Rank 3" }, texts(panel.ranks, "rank"))
            assert.are.same({ "1", "8", "16" }, texts(panel.ranks, "level"))
            assert.are.same({
                "Known",
                "Low Cat in Elwynn Forest",
                "Rare Cat in Tirisfal Glades",
            }, texts(panel.ranks, "text"), "Rare Cat: the one in reach, before Late Cat and High Cat")
            assert.are.same({ "", "", "+2" }, texts(panel.ranks, "more"), "how many more teach it")
            assert.is_false(panel.ranks[1].go.shown, "nothing to go to for a known rank")
            assert.is_true(panel.ranks[3].go.shown)
        end)

        it("says so when every teacher is above the hunter's level, or no beast teaches the rank", function()
            local client = hunter(4)
            local panel = tab(client)
            click(panel.rows[3])
            assert.are.equal("Low Cat in Elwynn Forest, above your level", panel.ranks[1].text.text)
            client.Addon.data.petAbilityRanks[CLAW_2].teachers = {}
            client.Addon:RefreshWindow("abilities")
            assert.are.equal("No beast teaches it", panel.ranks[2].text.text)
            assert.is_false(panel.ranks[2].go.shown)
            local row = panel.ranks[2]
            GameTooltip.shown = false
            row:GetScript("OnEnter")(row)
            assert.is_false(GameTooltip.shown, "no tooltip without teachers")
        end)

        it("puts the beast reached first on top, with its travel time, when a route addon knows them", function()
            local client = hunter(70)
            LibStub("LibGoThere-1.0"):RegisterProvider({
                id = "test",
                order = 1,
                Usable = function()
                    return true
                end,
                Navigate = function()
                    return true
                end,
                TravelTime = function(_, _, _, _, map)
                    if map == TIRISFAL then return 600 end
                    if map == ELWYNN then return 125 end
                end,
            })
            local panel = tab(client)
            click(panel.rows[3])
            assert.are.equal("High Cat in Elwynn Forest, ~2 min", panel.ranks[3].text.text)
        end)

        it("asks the route addon once per beast, and again only after half a minute", function()
            local client = hunter(70)
            local asked = 0
            LibStub("LibGoThere-1.0"):RegisterProvider({
                id = "test",
                order = 1,
                Usable = function()
                    return true
                end,
                Navigate = function()
                    return true
                end,
                TravelTime = function()
                    asked = asked + 1
                    return 60
                end,
            })
            local panel = tab(client)
            click(panel.rows[3])
            local first = asked
            assert.is_true(first <= 5, "one per beast at most: " .. first)
            client.Addon:RefreshWindow("abilities")
            assert.are.equal(first, asked, "kept")
            client:advance(31)
            client.Addon:RefreshWindow("abilities")
            assert.is_true(asked > first, "the hunter may have moved")
        end)

        it("without travel times puts beasts on the hunter's map first, then the closest in level", function()
            local client = hunter(70)
            local panel = tab(client)
            click(panel.rows[3])
            assert.are.equal("High Cat in Elwynn Forest", panel.ranks[3].text.text)
            client.Addon.data.beasts[102].pins = { [TIRISFAL] = { 1, 1 } }
            client.Addon:RefreshWindow("abilities")
            assert.are.equal("High Cat in Tirisfal Glades", panel.ranks[3].text.text, "65 is closer to 70")
        end)

        it("puts the beasts in reach in order of distance in a straight line, across zone borders", function()
            local client = hunter(70)
            -- At Elwynn Forest's east edge; Late Cat lives in Elwynn's west and just over the border.
            client.worldPos = { -9000, 400 - 0.45 * 3470, 0 }
            client.Addon.data.beasts[106].pins = { [ELWYNN] = { 5, 50 }, [BORDER] = { 10, 50 } }
            local panel = tab(client)
            click(panel.rows[3])
            assert.are.equal("Late Cat in Border Valley", panel.ranks[3].text.text)
            click(panel.ranks[3].go)
            assert.is_true(client:printedContains("Border Valley 10.0, 50.0"), "its nearest pin")
        end)

        it("asks the route addon about the 5 nearest beasts in reach only", function()
            local client = hunter(70)
            local beasts, teachers = client.Addon.data.beasts, {}
            for i = 1, 7 do
                beasts[300 + i] = {
                    name = "Cat " .. i,
                    family = 2,
                    minLevel = 10,
                    maxLevel = 10,
                    pins = { [ELWYNN] = { 10 * i, 55 } },
                }
                teachers[i] = 300 + i
            end
            client.Addon.data.petAbilityRanks[CLAW_3].teachers = teachers
            local asked = {}
            LibStub("LibGoThere-1.0"):RegisterProvider({
                id = "test",
                order = 1,
                Usable = function()
                    return true
                end,
                Navigate = function()
                    return true
                end,
                TravelTime = function(_, _, _, _, _, x, y)
                    -- The cats only; the other ranks' beasts are asked about too.
                    if y == 0.55 then asked[#asked + 1] = x end
                    return x < 0.5 and 60 or 30
                end,
            })
            local panel = tab(client)
            click(panel.rows[3])
            table.sort(asked)
            assert.are.same({ 0.3, 0.4, 0.5, 0.6, 0.7 }, asked, "the 5 nearest the middle")
            assert.are.equal("Cat 5 in Elwynn Forest, ~1 min", panel.ranks[3].text.text)
            assert.are.equal("+6", panel.ranks[3].more.text)
        end)

        it("goes to the nearest of a beast's pins", function()
            local client = hunter(10)
            local panel = tab(client)
            click(panel.rows[1])
            click(panel.ranks[1].go)
            assert.is_true(client:printedContains("Elwynn Forest 20.0, 20.0"), "Spider's pin at 20/20")
        end)

        it("sends the hunter to the beast on a click, and makes it the tame key's", function()
            local client = hunter(10)
            local panel = tab(client)
            click(panel.rows[3])
            click(panel.ranks[3].go)
            assert.is_true(client:printedContains("Tirisfal Glades 30.0, 30.0"), "LibGoThere's spot in chat")
            assert.is_true(client:printedContains("The tame key now targets Rare Cat."))
        end)

        it("lists every teacher in the rank's tooltip, in order", function()
            local client = hunter(10)
            local panel = tab(client)
            click(panel.rows[3])
            client.tooltipLines, GameTooltip.text = {}, nil
            local row = panel.ranks[3]
            row:GetScript("OnEnter")(row)
            local lines = {}
            for _, line in ipairs(client.tooltipLines) do
                lines[#lines + 1] = line.text
            end
            assert.are.equal("Claw (Rank 3)", GameTooltip.text)
            assert.are.same({
                "Rare Cat in Tirisfal Glades: Level 10, rare elite",
                "Late Cat: Level 11",
                "High Cat in Elwynn Forest: Level 65-66",
            }, lines)
            row:GetScript("OnLeave")(row)
            assert.is_false(GameTooltip.shown)
        end)

        it("follows what the hunter learns while it is open", function()
            local client = hunter(10)
            local panel = tab(client)
            client:openTrainer({ { "Bite", "used", BITE } }):closeTrainer()
            assert.are.equal("1/1", panel.rows[1].count.text)
        end)

        it("is a tab only while Beast Map is on", function()
            local client = hunter(10)
            tab(client)
            client.Addon:GetModule("BeastMap"):Disable()
            client.Addon:ToggleWindow()
            client.Addon:OpenWindow("abilities")
            assert.are.equal("pets", client.Addon.window.current)
        end)
    end)

    describe("the Families tab", function()
        local function tab(client)
            client.Addon:OpenWindow("families")
            return client.Addon.window.panels.families
        end

        local function shown(rows, field)
            local out = {}
            for _, row in ipairs(rows) do
                if row.shown then out[#out + 1] = row[field or "label"].text end
            end
            return out
        end

        local function click(button)
            button:GetScript("OnClick")(button, "LeftButton")
        end

        it("lists every family by name, with how many of your pets are of it; the pet out's chosen", function()
            local client = hunter(10)
            client.familyNames[2] = "Cat"
            local panel = tab(client)
            local rows = shown(panel.rows)
            assert.are.equal(18, #rows, "WoW: Forever's: the Fox, no Burning Crusade families")
            assert.are.equal("Bat", rows[1])
            assert.is_truthy(tContains(rows, "Cat (1)"), "Fluffy")
            assert.are.equal("Cat", panel.title.text)
        end)

        it("shows each family's portrait beside its name, and the chosen one's by the title", function()
            local client = hunter(10)
            client.familyNames[2], client.familyIcons[2] = "Cat", 132185
            local panel = tab(client)
            local cat
            for _, row in ipairs(panel.rows) do
                if row.shown and row.familyID == 2 then cat = row end
            end
            assert.are.equal(132185, cat.icon.texture)
            assert.are.equal(132185, panel.titleIcon.texture, "Fluffy's family is chosen")
            assert.are.equal(134400, panel.rows[1].icon.texture, "the question mark without the client's icon")
        end)

        it("says its specialization, diet and what it can learn, an ability a row", function()
            local client = hunter(10)
            client:openTrainer({ { "Claw", "used", CLAW } }):closeTrainer()
            local panel = tab(client)
            assert.are.equal("Ferocity", panel.spec.text)
            assert.are.equal("Eats: Meat, Fish", panel.diet.text)
            local row = panel.abilityRows[1]
            assert.is_true(row.shown)
            assert.are.equal("Claw", row.label.text)
            assert.are.equal("1/3", row.count.text)
            assert.are.equal(CLAW_ICON, row.icon.texture)
            assert.is_true(row.learnable.shown, "Claw 2 from a beast at level 5")
            assert.is_false(panel.abilityRows[2].shown, "the cat learns nothing else here")
            client.tooltipLines, GameTooltip.text = {}, nil
            row:GetScript("OnEnter")(row)
            assert.are.equal("Claw", GameTooltip.text)
            assert.are.equal("Known: Rank 1", client.tooltipLines[1].text)
            row:GetScript("OnLeave")(row)
            assert.is_false(GameTooltip:IsShown())
            -- A rank for every family (no families listed) is the cat's too: by name, Bite first.
            client.Addon.data.petAbilityRanks[BITE].families = {}
            client.Addon:RefreshWindow("families")
            assert.are.same({ "Bite", "Claw" }, { panel.abilityRows[1].label.text, panel.abilityRows[2].label.text })
        end)

        it("opens an ability's teachers in the Abilities tab on a click", function()
            local client = hunter(10)
            local panel = tab(client)
            click(panel.abilityRows[1])
            local abilities = client.Addon.window.panels.abilities
            assert.is_true(abilities.shown)
            assert.are.equal("Claw", abilities.title.text)
        end)

        it("names up to six beasts of the family, nearest first", function()
            local client = hunter(10)
            local panel = tab(client)
            assert.are.equal(6, #panel.beasts)
        end)

        it("says the family's category and modifiers where pets have no specialization", function()
            -- Before Wrath (but on WoW: Forever) a family has a category and fixed modifiers.
            local client = hunter(10, { era = true })
            local panel = tab(client)
            assert.are.equal("Offense: +10% damage, -2% health", panel.spec.text, "the Cat")
            assert.are.equal("Eats: Meat, Fish", panel.diet.text)
            client.familyNames[21] = "Turtle"
            for _, row in ipairs(panel.rows) do
                if row.shown and row.familyID == 21 then row:GetScript("OnClick")(row, "LeftButton") end
            end
            assert.are.equal("Defense: -10% damage, +13% armor", panel.spec.text)
        end)

        it("shows the nearest beast's model by its display ID, else by its NPC ID", function()
            local client = hunter(10)
            client.Addon.data.beasts[101].display = 892
            local panel = tab(client)
            assert.are.same({ displayID = 892 }, panel.model.shownModel)
            client.Addon.data.beasts[101].display = nil
            client.Addon:RefreshWindow("families")
            assert.are.same({ creature = 101 }, panel.model.shownModel)
        end)

        it("names the beasts of the family the hunter can tame, nearest first, and goes there", function()
            local client = hunter(10)
            local panel = tab(client)
            assert.are.same({
                "Low Cat in Elwynn Forest: Level 5-6",
                "Rare Cat in Tirisfal Glades: Level 10, rare elite",
                "Late Cat: Level 11",
                "High Cat in Elwynn Forest: Level 65-66",
            }, shown(panel.beasts, "text"))
            assert.are.same({ creature = 101 }, panel.model.shownModel)
            click(panel.beasts[2].go)
            assert.is_true(client:printedContains("The tame key now targets Rare Cat."))
            for _, row in ipairs(panel.rows) do
                if row.shown and row.label.text == "Boar" then click(row) end
            end
            assert.are.equal("Cave Boar in Wailing Caverns: Level 12", panel.beasts[2].text.text)
            assert.is_false(panel.beasts[2].go.shown, "no pin to go to")
        end)

        it("shows another family on a click, also one Huntsworn knows little of", function()
            local client = hunter(10)
            client.familyNames[40] = "Fuchs"
            local panel = tab(client)
            local fox
            for _, row in ipairs(panel.rows) do
                if row.shown and row.label.text == "Fuchs" then fox = row end
            end
            click(fox)
            assert.are.equal("Fuchs", panel.title.text)
            assert.are.equal("", panel.spec.text)
            assert.are.equal("", panel.diet.text)
            assert.is_false(panel.abilityRows[1].shown, "no abilities known for it")
            assert.are.same({}, shown(panel.beasts, "text"))
            assert.are.equal("No beast of this family in Huntsworn's data.", panel.none.text)
            assert.is_false(panel.model.shown)
        end)

        it("falls back to the first family without a pet out", function()
            local client = hunter(10, { noPet = true })
            assert.are.equal("Bat", tab(client).title.text)
        end)

        ---The list's rows as shown: a heading as "# Name", a group's rares as "> Rares", a family as
        ---its name.
        local function listed(panel)
            local out = {}
            for _, row in ipairs(panel.rows) do
                if row.shown then
                    local kind = row.heading and "# " or row.rares and "> " or ""
                    out[#out + 1] = kind .. row.label.text
                end
            end
            return out
        end

        it("groups the families by role on Classic: by category, named so or as Wrath's specializations", function()
            local client = hunter(10, { era = true })
            local panel = tab(client)
            assert.are.equal("Family", panel.groupBy[1].label.text)
            assert.are.equal("Role", panel.groupBy[2].label.text)
            click(panel.groupBy[2])
            assert.are.equal("role", client.Addon:GetModule("BeastMap"):Settings().familyGroup, "kept")
            local rows = listed(panel)
            assert.are.same({ "# Offense", "Cat (1)", "Raptor", "Bat", "Bird of Prey", "Spider", "Wind Serpent" }, {
                unpack(rows, 1, 7),
            }, "the most damage first")
            assert.are.same({ "# Defense", "Bear", "Boar", "Turtle" }, { unpack(rows, 8, 11) })
            set(client, "familySpecNames", true)
            rows = listed(panel)
            assert.are.same({ "# Ferocity", "# Tenacity" }, { rows[1], rows[8] }, "the same groups, other names")
            local cat, boar
            for _, row in ipairs(panel.rows) do
                if row.familyID == 2 then cat = row end
                if row.familyID == 5 then boar = row end
            end
            assert.are.equal("+10% damage", cat.note.text)
            assert.are.equal("+9% armor", boar.note.text)
            -- A long name ("Wind Serpent") stops short of its note instead of running under it.
            assert.are.same({ "RIGHT", cat.note, "LEFT", -4, 0 }, cat.label.points[2])
            assert.is_false(cat.label.wordWrap)
            assert.are.same({ 1, 0.82, 0 }, panel.rows[1].label.textColor, "a heading in gold")
            click(panel.rows[1])
            assert.are.equal("Cat", panel.title.text, "a heading picks nothing")
            assert.is_true(client.Addon:GetModule("BeastMap"):GetOptions().args.familySpecNames.hidden() == false)
            click(panel.groupBy[1])
            assert.are.equal("Bat", listed(panel)[1], "by name again")
            assert.are.equal("", cat.note.text)
        end)

        it("scrolls the list with the mouse wheel", function()
            local client = hunter(10, { era = true })
            local panel = tab(client)
            click(panel.groupBy[2])
            local wheel = panel.list:GetScript("OnMouseWheel")
            wheel(panel.list, -1)
            assert.are.equal("Cat (1)", listed(panel)[1])
            wheel(panel.list, -10)
            local rows = listed(panel)
            assert.are.equal("Wolf", rows[#rows], "no further than the end")
            wheel(panel.list, 10)
            assert.are.equal("# Offense", listed(panel)[1])
        end)

        it("groups by the family's own specialization on WoW: Forever", function()
            local client = hunter(10)
            local panel = tab(client)
            click(panel.groupBy[2])
            local heading
            for _, row in ipairs(panel.rows) do
                if row.heading then heading = row.label.text end
                if row.familyID == 5 then break end
            end
            assert.are.equal("Cunning", heading, "the Boar is Cunning there")
            assert.is_true(client.Addon:GetModule("BeastMap"):GetOptions().args.familySpecNames.hidden(), "no choice")
        end)

        ---The first shown row of the list for which `test` holds.
        local function rowWhere(panel, test)
            for _, row in ipairs(panel.rows) do
                if row.shown and test(row) then return row end
            end
        end

        it("gives each family with rares a Rares item with Rares ticked: its rares, nearest first", function()
            local client = hunter(10)
            local panel = tab(client)
            assert.are.equal("Rares", panel.rares.label.text)
            assert.is_false(panel.rares.check.shown)
            assert.is_nil(rowWhere(panel, function(row)
                return row.rares
            end))
            click(panel.rares)
            assert.is_true(panel.rares.check.shown)
            assert.is_true(client.Addon:GetModule("BeastMap"):Settings().familyRares, "kept")
            local rows, at = listed(panel), nil
            for index, text in ipairs(rows) do
                if text == "Cat (1)" then at = index end
            end
            assert.are.equal("> Rares", rows[at + 1], "under the Cat, which has one")
            assert.are.equal("Bear", rows[2], "none under the Bat, without rares")
            click(rowWhere(panel, function(row)
                return row.rares == 2
            end))
            assert.are.equal("Cat: rares", panel.title.text)
            assert.are.same({ "Rare Cat in Tirisfal Glades: Level 10, rare elite" }, shown(panel.beasts, "text"))
            assert.are.same({ creature = 104 }, panel.model.shownModel)
        end)

        it("gives each role a Rares item: the rares of all its families", function()
            local client = hunter(10)
            local panel = tab(client)
            click(panel.groupBy[2])
            click(panel.rares)
            local item = rowWhere(panel, function(row)
                return row.rares == "ferocity"
            end)
            assert.are.equal("Rares", item.label.text)
            click(item)
            assert.are.equal("Ferocity: rares", panel.title.text)
            assert.are.same({ "Rare Cat in Tirisfal Glades: Level 10, rare elite" }, shown(panel.beasts, "text"))
            assert.are.equal("", panel.spec.text)
            click(panel.rares)
            assert.is_nil(
                rowWhere(panel, function(row)
                    return row.rares
                end),
                "unticked: gone"
            )
            assert.are.equal("Cat", panel.title.text, "back to the family")
        end)
    end)

    it("sends the hunter to a beast with a left click on its pin, through LibGoThere", function()
        local client = hunter(10)
        local low = client:mapPins(ELWYNN)[1]
        client:clickPin(ELWYNN, low.coord, "RightButton")
        assert.is_false(client:printedContains("Elwynn Forest 40.0, 50.0"), "a right click does nothing")
        client:clickPin(ELWYNN, low.coord)
        -- No route addon and no game waypoint in the simulated client: LibGoThere's spot in chat.
        local links = 0
        for _, line in ipairs(client.printed) do
            if line:find("Low Cat, Elwynn Forest 40.0, 50.0", 1, true) then links = links + 1 end
        end
        assert.are.equal(1, links, "once, as the button comes up")
        assert.has_no.errors(function()
            client:clickPin(ELWYNN, 1)
        end)
    end)

    it("redraws when the hunter levels, learns a rank or changes a setting", function()
        local client = hunter(10)
        local before = client.mapUpdates.world
        client.playerLevel = 11
        client:fire("PLAYER_LEVEL_UP", 11)
        assert.are.equal(before + 1, client.mapUpdates.world)
        assert.are.equal(client.mapUpdates.world, client.mapUpdates.minimap)
        client:openTrainer({ { "Claw", "used", CLAW } }):closeTrainer()
        assert.are.equal(before + 2, client.mapUpdates.world)
        set(client, "gaps", true)
        assert.is_true(client.Addon:GetModule("BeastMap"):Settings().gaps)
        assert.are.equal(before + 3, client.mapUpdates.world)
    end)

    it("pins nothing while switched off", function()
        local client = hunter(10)
        client.Addon:GetModule("BeastMap"):Disable()
        assert.are.same({}, client:mapPins(ELWYNN))
        assert.is_true(client.mapUpdates.world > 0)
        client.Addon:GetModule("BeastMap"):Enable()
        assert.are.equal(3, #client:mapPins(ELWYNN))
    end)

    describe("at a level-up", function()
        ---The hunter reaches `level`; gives the toast's title and text, or nil.
        ---@param client table
        ---@param level number
        local function levelUp(client, level)
            client:fire("PLAYER_LEVEL_UP", level)
            local toast = client:toast()
            if not (toast and toast.shown) then return nil end
            return client:toastTitle(), toast.Text.text
        end

        it("toasts the ranks a beast of the new level brings in reach, where to tame it", function()
            local client = hunter(11)
            local title, text = levelUp(client, 12)
            assert.are.equal("Now in reach: Charge (Rank 1)", title)
            assert.are.equal("Cave Boar in Wailing Caverns teaches it.", text)
        end)

        it("lists several ranks, each with a beast", function()
            local client = hunter(4)
            local title, text = levelUp(client, 5)
            assert.are.equal("3 pet ability ranks now in reach", title)
            assert.are.equal(
                "Claw (Rank 1): Low Cat in Elwynn Forest\nClaw (Rank 2): Low Cat in Elwynn Forest\nBite (Rank 1): Spider in Elwynn Forest",
                text
            )
        end)

        it("says nothing before Beast Training: no beast can teach the hunter yet", function()
            local client = hunter(11)
            client.unknownSpells[5149] = true -- Beast Training comes with the quest Training the Beast
            assert.is_nil(levelUp(client, 12))
        end)

        it("names the rank from the data while the client has no subtext for the spell yet", function()
            local client = hunter(11)
            client.uncached[7371] = true -- Charge
            assert.are.equal("Now in reach: Charge (Rank 1)", (levelUp(client, 12)))
        end)

        it("leaves out ranks the hunter has, and ranks a lower beast taught already", function()
            local client = hunter(4)
            -- Beast Training read without Cower: the pet's Cower would toast for autocast too.
            client.Addon:GetModule("AutocastCheck"):Disable()
            client:openTrainer({ { "Claw", "used", CLAW_2 } }):closeTrainer()
            assert.are.equal("Now in reach: Bite (Rank 1)", (levelUp(client, 5)))
            client = hunter(10)
            assert.is_nil(levelUp(client, 11), "Claw 3 was in reach at 10 already")
        end)

        it("names the beast reached first, when a route addon knows the travel times", function()
            local client = hunter(11)
            local GoThere = LibStub("LibGoThere-1.0")
            GoThere:RegisterProvider({
                id = "test",
                order = 1,
                Usable = function()
                    return true
                end,
                Navigate = function()
                    return true
                end,
                TravelTime = function(_, _, _, _, map, x, y)
                    -- Field Boar's pin, 70/70 on Elwynn Forest; Cave Boar has none.
                    if map == 1429 and x == 0.7 and y == 0.7 then return 45 end
                end,
            })
            local _, text = levelUp(client, 12)
            assert.are.equal("Field Boar in Elwynn Forest teaches it.", text)
        end)

        it("names an ordinary beast before a rare, and the beast alone when its map has no name", function()
            local client = hunter(9)
            client.Addon.data.beasts[104].minLevel = 11 -- Rare Cat now comes with Late Cat
            local _, text = levelUp(client, 11)
            assert.are.equal("Late Cat teaches it.", text)
        end)

        it("says it in chat too when asked to", function()
            local client = hunter(11)
            levelUp(client, 12)
            assert.is_false(client:printedContains("Now in reach"), "off by default")
            client = hunter(4)
            set(client, "levelChat", true)
            levelUp(client, 5)
            assert.is_true(client:printedContains("3 pet ability ranks now in reach"))
            assert.is_true(client:printedContains("Bite (Rank 1): Spider in Elwynn Forest"))
        end)

        it("stays quiet when switched off, also without HandyNotes", function()
            local client = hunter(4)
            set(client, "levelToast", false)
            assert.is_nil(levelUp(client, 5))
            client = hunter(11, { handyNotes = false })
            assert.are.equal("Now in reach: Charge (Rank 1)", (levelUp(client, 12)))
        end)
    end)
end)
