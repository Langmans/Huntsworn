-- Beast Map's Beasts tab: every beast that teaches a pet ability rank, filtered by name, ability,
-- family, diet, zone, what the hunter knows, reach and rarity; a click on a beast opens its card.
-- The specs use a small data set of their own.

local BITE, CHARGE = 17253, 7371
local ELWYNN, TIRISFAL = 1429, 1420
local CLAW_ICON, BITE_ICON = 132140, 132278

---@param Addon Addon
local function SmallData(Addon)
    Addon.data = {
        petAbilityRanks = {
            [CLAW] = { ability = CLAW, rank = 1, level = 1, families = { 2 }, teachers = { 101 } },
            [CLAW_2] = { ability = CLAW, rank = 2, level = 8, families = { 2 }, teachers = { 101 } },
            [CLAW_3] = { ability = CLAW, rank = 3, level = 16, families = { 2 }, teachers = { 102, 104 } },
            [BITE] = { ability = BITE, rank = 1, level = 1, families = { 1, 3 }, teachers = { 103 } },
            [CHARGE] = { ability = CHARGE, rank = 1, level = 1, families = { 5 }, teachers = { 105, 107 } },
        },
        beasts = {
            [101] = {
                name = "Low Cat",
                family = 2,
                minLevel = 5,
                maxLevel = 6,
                pins = { [ELWYNN] = { 40, 50, 45, 55 } },
            },
            [102] = { name = "High Cat", family = 2, minLevel = 65, maxLevel = 66, pins = { [ELWYNN] = { 60, 60 } } },
            [103] = {
                name = "Spider",
                family = 3,
                minLevel = 5,
                maxLevel = 5,
                speed = 1.2,
                pins = { [ELWYNN] = { 10, 10 }, [TIRISFAL] = { 20, 20, 25, 25, 30, 30 } },
            },
            [104] = {
                name = "Rare Cat",
                family = 2,
                minLevel = 10,
                maxLevel = 10,
                rare = true,
                speed = 2,
                pins = { [TIRISFAL] = { 30, 30 } },
            },
            [105] = { name = "Cave Boar", family = 5, minLevel = 12, maxLevel = 12, zones = { 718 } },
            [107] = {
                name = "Field Boar",
                family = 5,
                minLevel = 12,
                maxLevel = 12,
                display = 1234,
                pins = { [ELWYNN] = { 70, 70 } },
            },
        },
    }
end

---A hunter at `level`, logged in and past AbilityLearned's login wait.
---@param level number?
---@param modules fun(Addon: Addon)?
local function hunter(level, modules)
    local client = NewClient({ modules = modules or SmallData })
    client.playerLevel = level or 10
    return client:login():advance(5)
end

---The tab, opened in Huntsworn's window.
local function tab(client)
    client.Addon:OpenWindow("beasts")
    return client.Addon.window.panels.beasts
end

---The shown rows' texts of one column.
local function column(panel, field)
    local out = {}
    for _, row in ipairs(panel.rows) do
        if row.shown then out[#out + 1] = row[field or "name"].text end
    end
    return out
end

local function click(button)
    button:GetScript("OnClick")(button, "LeftButton")
end

---The texts of the open pick list's shown rows.
local function choices(client)
    local out = {}
    for _, row in ipairs(client.Addon.pickList.rows) do
        if row.shown then out[#out + 1] = row.label.text end
    end
    return out
end

---Opens a picker's list and clicks the choice with `text`.
local function pick(client, picker, text)
    click(picker)
    for _, row in ipairs(client.Addon.pickList.rows) do
        if row.shown and row.label.text == text then return click(row) end
    end
    error("no choice " .. text)
end

---Types into the search box, as the player would.
local function search(panel, text)
    panel.search:SetText(text)
    panel.search:GetScript("OnTextChanged")(panel.search, true)
end

describe("the Beasts tab", function()
    it("lists every teaching beast by level, then name, under a count", function()
        local panel = tab(hunter(10))
        assert.are.same(
            { "Low Cat", "Spider", "Rare Cat (rare)", "Cave Boar", "Field Boar", "High Cat" },
            column(panel)
        )
        assert.are.equal("6 beasts", panel.count.text)
        assert.are.same({ "Cat", "Spider", "Cat", "Boar", "Boar", "Cat" }, column(panel, "family"))
        assert.are.same({ "5-6", "5", "10", "12", "12", "65-66" }, column(panel, "level"))
    end)

    it("shows what each teaches coloured by how the hunter stands to it, and a speed off 2.0", function()
        local client = hunter(10)
        client:openTrainer({ { "Claw", "used", CLAW_2 } }):closeTrainer()
        local panel = tab(client)
        local low, spider, rare, high = panel.rows[1], panel.rows[2], panel.rows[3], panel.rows[6]
        assert.are.equal("|cffffff00Claw (Rank 1)|r, |cff808080Claw (Rank 2)|r", low.teaches.text, "skipped, known")
        assert.are.equal("|cff00ff00Claw (Rank 3)|r", high.teaches.text, "new")
        assert.are.equal("|cff00ff00Bite (Rank 1)|r", spider.teaches.text)
        assert.are.equal("1.2", spider.speed.text)
        assert.are.equal("", rare.speed.text, "2.0 is the usual")
        assert.are.equal("", low.speed.text)
        assert.are.equal(CLAW_ICON, low.icon.texture, "the icon of the first rank it lacks")
        assert.are.equal(BITE_ICON, spider.icon.texture)
    end)

    it("has a go pin on a beast out in the open, which sends the hunter there", function()
        local client = hunter(10)
        local panel = tab(client)
        assert.is_true(panel.rows[1].go.shown)
        assert.is_false(panel.rows[4].go.shown, "Cave Boar lives in an instance")
        local go = panel.rows[1].go
        go:GetScript("OnEnter")(go)
        assert.are.equal("The way to Low Cat", GameTooltip.text)
        go:GetScript("OnLeave")(go)
        assert.is_false(GameTooltip:IsShown())
        click(go)
        assert.are.equal("Low Cat", client.Addon:GetModule("BeastMap").tameTarget)
    end)

    it("searches by name, and filters by ability, family and diet through pick lists", function()
        local client = hunter(70)
        local panel = tab(client)
        search(panel, "CAT")
        assert.are.same({ "Low Cat", "Rare Cat (rare)", "High Cat" }, column(panel))
        search(panel, "")
        click(panel.pickers.ability)
        assert.are.same({ "All abilities", "Bite", "Charge", "Claw" }, choices(client))
        pick(client, panel.pickers.ability, "Bite")
        assert.is_false(client.Addon.pickList.shown, "a choice closes the list")
        assert.are.same({ "Spider" }, column(panel))
        assert.are.equal("Ability: Bite", panel.pickers.ability.label.text)
        pick(client, panel.pickers.ability, "All abilities")
        pick(client, panel.pickers.family, "Boar")
        assert.are.same({ "Cave Boar", "Field Boar" }, column(panel))
        click(panel.pickers.family)
        assert.are.same({ "All families", "Boar", "Cat", "Spider" }, choices(client), "the families with beasts")
        pick(client, panel.pickers.family, "All families")
        click(panel.pickers.diet)
        assert.are.same(
            { "All diets", "Bread", "Cheese", "Fish", "Fruit", "Fungus", "Meat" },
            choices(client),
            "what those families eat"
        )
        pick(client, panel.pickers.diet, "Fish")
        assert.are.same({ "Low Cat", "Rare Cat (rare)", "Cave Boar", "Field Boar", "High Cat" }, column(panel))
    end)

    it("filters by zone: all, the player's own, or one", function()
        local client = hunter(70)
        local panel = tab(client)
        click(panel.pickers.zone)
        assert.are.same(
            { "All zones", "Here (Elwynn Forest)", "Elwynn Forest", "Tirisfal Glades", "Wailing Caverns" },
            choices(client)
        )
        pick(client, panel.pickers.zone, "Here (Elwynn Forest)")
        assert.are.same({ "Low Cat", "Spider", "Field Boar", "High Cat" }, column(panel))
        pick(client, panel.pickers.zone, "Tirisfal Glades")
        assert.are.same({ "Spider", "Rare Cat (rare)" }, column(panel))
        pick(client, panel.pickers.zone, "Wailing Caverns")
        assert.are.same({ "Cave Boar" }, column(panel))
    end)

    it("filters by what the hunter has already, or not yet", function()
        local client = hunter(70)
        client:openTrainer({ { "Claw", "used", CLAW }, { "Claw", "used", CLAW_2 }, { "Claw", "used", CLAW_3 } })
        client:closeTrainer()
        local panel = tab(client)
        click(panel.pickers.you)
        assert.are.same({ "All", "Has already", "Not yet" }, choices(client))
        pick(client, panel.pickers.you, "Has already")
        assert.are.same({ "Low Cat", "Rare Cat (rare)", "High Cat" }, column(panel))
        assert.are.equal("You: Has already", panel.pickers.you.label.text)
        pick(client, panel.pickers.you, "Not yet")
        assert.are.same({ "Spider", "Cave Boar", "Field Boar" }, column(panel))
    end)

    it("shows only beasts in reach, or only rares, with their switches", function()
        local client = hunter(10)
        local panel = tab(client)
        click(panel.reach)
        assert.are.same({ "Low Cat", "Spider", "Rare Cat (rare)" }, column(panel))
        assert.is_true(panel.reach.check.shown)
        click(panel.rares)
        assert.are.same({ "Rare Cat (rare)" }, column(panel))
        click(panel.reach)
        click(panel.rares)
        assert.are.equal(6, #column(panel))
        search(panel, "nothing like it")
        assert.are.equal("No beast matches.", panel.count.text)
    end)

    it("keeps its filters in the profile", function()
        local client = hunter(10)
        local panel = tab(client)
        pick(client, panel.pickers.family, "Cat")
        click(panel.reach)
        search(panel, "low")
        client:logout()
        client = NewClient({ saved = Saved(), modules = SmallData })
        client.playerLevel = 10
        panel = tab(client:login():advance(5))
        assert.are.same({ "Low Cat" }, column(panel))
        assert.are.equal("low", panel.search.text)
        assert.are.equal("Family: Cat", panel.pickers.family.label.text)
    end)

    it("sorts by straight-line distance with a click on Distance's head, and back by Level's", function()
        local client = hunter(10)
        local panel = tab(client)
        assert.are.equal("Level", panel.sorts.level.label.text)
        click(panel.sorts.distance)
        -- The player stands in the middle of Elwynn Forest; Tirisfal Glades cannot be placed in
        -- the simulated world, and Cave Boar lives in an instance: those last, by level.
        assert.are.same(
            { "Low Cat", "High Cat", "Field Boar", "Spider", "Rare Cat (rare)", "Cave Boar" },
            column(panel)
        )
        local yards = column(panel, "distance")
        assert.is_truthy(yards[1]:match("^%d+ yd$"), yards[1])
        assert.are.same({ "", "" }, { yards[5], yards[6] }, "no distance for those")
        assert.are.same({ 1, 1, 1 }, panel.sorts.distance.label.textColor, "the sort in white")
        assert.are.same({ 1, 0.82, 0 }, panel.sorts.level.label.textColor, "the other in gold")
        assert.are.equal("distance", client.Addon:GetModule("BeastMap"):Settings().beasts.sort)
        click(panel.sorts.level)
        assert.are.equal("Low Cat", column(panel)[1])
        assert.are.equal("Spider", column(panel)[2])
    end)

    it("sorts by any column head; a second click on it turns the order round", function()
        local client = hunter(10)
        local panel = tab(client)
        local sorts, filter = panel.sorts, client.Addon:GetModule("BeastMap"):Settings().beasts
        click(sorts.speed)
        assert.are.same(
            { "Spider", "Low Cat", "Rare Cat (rare)", "Cave Boar", "Field Boar", "High Cat" },
            column(panel),
            "1.2 first; the rest attack at 2.0, by level"
        )
        assert.is_true(sorts.speed.arrow.shown)
        assert.are.equal("Interface\\Buttons\\Arrow-Up-Up", sorts.speed.arrow.texture)
        assert.is_false(sorts.level.arrow.shown, "only the head it is sorted by")
        click(sorts.speed)
        assert.is_true(filter.descending)
        assert.are.equal("Interface\\Buttons\\Arrow-Down-Up", sorts.speed.arrow.texture)
        assert.are.same(
            { "Low Cat", "Rare Cat (rare)", "Cave Boar", "Field Boar", "High Cat", "Spider" },
            column(panel),
            "ties stay by level"
        )
        click(sorts.name)
        assert.is_false(filter.descending, "another head starts ascending")
        assert.are.same(
            { "Cave Boar", "Field Boar", "High Cat", "Low Cat", "Rare Cat (rare)", "Spider" },
            column(panel)
        )
        click(sorts.family)
        assert.are.same(
            { "Cave Boar", "Field Boar", "Low Cat", "Rare Cat (rare)", "High Cat", "Spider" },
            column(panel)
        )
        click(sorts.level)
        click(sorts.level)
        assert.are.same(
            { "High Cat", "Cave Boar", "Field Boar", "Rare Cat (rare)", "Low Cat", "Spider" },
            column(panel)
        )
        click(sorts.distance)
        click(sorts.distance)
        assert.are.same(
            { "Spider", "Field Boar", "High Cat", "Low Cat", "Rare Cat (rare)", "Cave Boar" },
            column(panel),
            "farthest first; those it cannot place stay last"
        )
    end)

    it("closes a pick list with a second click on its picker", function()
        local client = hunter(10)
        local panel = tab(client)
        click(panel.pickers.zone)
        assert.is_true(client.Addon.pickList.shown)
        click(panel.pickers.zone)
        assert.is_false(client.Addon.pickList.shown)
        click(panel.pickers.zone)
        click(panel.pickers.you)
        assert.is_true(client.Addon.pickList.shown, "another picker's click opens it for that one")
        assert.are.same({ "All", "Has already", "Not yet" }, choices(client))
    end)

    it("closes a pick list with its picker, as the window closes", function()
        local client = hunter(10)
        local panel = tab(client)
        click(panel.pickers.zone)
        local picker = panel.pickers.zone
        picker:GetScript("OnHide")(picker)
        assert.is_false(client.Addon.pickList.shown)
        click(panel.pickers.zone)
        local other = panel.pickers.family
        other:GetScript("OnHide")(other)
        assert.is_true(client.Addon.pickList.shown, "another picker hiding leaves it open")
    end)

    describe("a beast's card", function()
        ---Opens the card of the beast named `name` in the list.
        local function open(panel, name)
            for _, row in ipairs(panel.rows) do
                if row.shown and row.name.text == name then
                    click(row)
                    return panel.card
                end
            end
            error("no row " .. name)
        end

        ---The shown dots on the card's map, as "x,y" in percent.
        local function dots(card)
            local out = {}
            for _, dot in ipairs(card.dots) do
                if dot.shown then out[#out + 1] = dot.x .. "," .. dot.y end
            end
            return out
        end

        ---The shown map buttons' texts.
        local function maps(card)
            local out = {}
            for _, button in ipairs(card.maps) do
                if button.shown then out[#out + 1] = button.label.text end
            end
            return out
        end

        it("opens with a click on its row, and Back returns to the list as it was", function()
            local client = hunter(10)
            local panel = tab(client)
            pick(client, panel.pickers.family, "Cat")
            local card = open(panel, "Low Cat")
            assert.is_true(card.shown)
            assert.is_false(panel.browse.shown)
            assert.are.equal("Low Cat", card.title.text)
            assert.are.equal("Level 5-6", card.level.text)
            assert.are.equal("Cat. Eats: Meat, Fish", card.family.text)
            assert.are.equal("|cff00ff00Claw (Rank 1)|r\n|cff00ff00Claw (Rank 2)|r", card.teaches.text)
            assert.are.same({ creature = 101 }, card.model.shownModel)
            click(card.back)
            assert.is_false(card.shown)
            assert.is_true(panel.browse.shown)
            assert.are.same({ "Low Cat", "Rare Cat (rare)", "High Cat" }, column(panel))
            pick(client, panel.pickers.family, "Boar")
            card = open(panel, "Field Boar")
            assert.are.same({ displayID = 1234 }, card.model.shownModel, "by display ID when the data has it")
            assert.are.equal("Level 12", card.level.text)
        end)

        it("names a rare, and its attack speed off 2.0, in the level line", function()
            local client = hunter(10)
            local panel = tab(client)
            assert.are.equal("Rare Cat (rare)", open(panel, "Rare Cat (rare)").title.text)
            click(panel.card.back)
            assert.are.equal("Level 5, attack speed 1.2", open(panel, "Spider").level.text)
        end)

        it("shows the beast's map with its spawn dots, the player's map first; a dot goes there", function()
            local client = hunter(10)
            local panel = tab(client)
            local card = open(panel, "Spider")
            assert.are.equal("Elwynn Forest", card.mapName.text, "the player is in Elwynn Forest")
            assert.are.same({ "Elwynn Forest", "Tirisfal Glades" }, maps(card))
            assert.are.same({ "10,10" }, dots(card))
            assert.are.equal(ELWYNN * 100 + 1, card.tiles[1].texture)
            click(card.maps[2])
            assert.are.equal("Tirisfal Glades", card.mapName.text)
            assert.are.same({ "20,20", "25,25", "30,30" }, dots(card))
            -- 12 tiles of 256 pixels for 1002 by 668: the last column and row cut to fit.
            local shown = 0
            for _, tile in ipairs(card.tiles) do
                if tile.shown then shown = shown + 1 end
            end
            assert.are.equal(12, shown)
            assert.are.equal(TIRISFAL * 100 + 1, card.tiles[1].texture)
            assert.are.same({ 0, (1002 - 768) / 256, 0, 1 }, card.tiles[4].texCoord, "tile 4 ends the first row")
            assert.are.same({ 0, 1, 0, (668 - 512) / 256 }, card.tiles[9].texCoord, "tile 9 starts the last row")
            click(card.dots[1])
            assert.is_true(client:printedContains("Spider, Tirisfal Glades 20.0, 20.0"))
            assert.are.equal("Spider", client.Addon:GetModule("BeastMap").tameTarget)
        end)

        it("shows one map without map buttons, and dots without art where the client has none", function()
            local client = hunter(10)
            local panel = tab(client)
            local card = open(panel, "Rare Cat (rare)")
            assert.are.equal("Tirisfal Glades", card.mapName.text, "its only map")
            assert.are.same({}, maps(card))
            click(card.back)
            client.Addon.data.beasts[104].pins[1430] = { 5, 5, 6, 6 }
            card = open(panel, "Rare Cat (rare)")
            assert.are.same({ "Tirisfal Glades", "Border Valley" }, maps(card), "neither here: by uiMapID")
            click(card.maps[2])
            assert.are.equal("Border Valley", card.mapName.text)
            assert.are.same({ "5,5", "6,6" }, dots(card))
            assert.is_false(card.tiles[1].shown)
        end)

        it("says where a beast in an instance lives, without a map", function()
            local client = hunter(10)
            local panel = tab(client)
            local card = open(panel, "Cave Boar")
            assert.is_false(card.map.shown)
            assert.are.equal("In Wailing Caverns", card.mapName.text)
            assert.are.same({}, dots(card))
        end)

        it("hunts the beast for the first rank the hunter lacks, and stops again", function()
            local client = hunter(10)
            client:openTrainer({ { "Claw", "used", CLAW } }):closeTrainer()
            local panel = tab(client)
            local card = open(panel, "Low Cat")
            local M = client.Addon:GetModule("BeastMap")
            assert.are.equal("Hunt", card.hunt:GetText())
            click(card.hunt)
            assert.are.same({ npc = 101, spellID = CLAW_2 }, M:Hunt())
            assert.are.equal("Stop the hunt", card.hunt:GetText())
            click(card.hunt)
            assert.is_nil(M:Hunt())
            assert.are.equal("Hunt", card.hunt:GetText())
            click(card.back)
            client:openTrainer({ { "Bite", "used", BITE } }):closeTrainer()
            card = open(panel, "Spider")
            assert.is_false(card.hunt.shown, "nothing left to learn from it")
        end)
    end)

    describe("with more beasts than rows", function()
        ---SmallData and 40 more cats, level 20 each, each also in a den of its own.
        local function many(Addon)
            SmallData(Addon)
            local areaName = C_Map.GetAreaInfo
            C_Map.GetAreaInfo = function(area)
                return area > 5000 and ("Den %02d"):format(area - 5000) or areaName(area)
            end
            for i = 1, 40 do
                Addon.data.beasts[1000 + i] = {
                    name = ("Cat %02d"):format(i),
                    family = 2,
                    minLevel = 20,
                    maxLevel = 20,
                    pins = { [ELWYNN] = { 50, 50 } },
                }
                -- More zones than the pick list has rows.
                Addon.data.beasts[1000 + i].zones = { 5000 + i }
                table.insert(Addon.data.petAbilityRanks[CLAW].teachers, 1000 + i)
            end
        end

        it("scrolls with the mouse wheel and the scrollbar beside the rows", function()
            local client = hunter(10, many)
            local panel = tab(client)
            assert.are.equal("46 beasts", panel.count.text)
            assert.is_true(panel.bar.shown)
            assert.are.equal("Low Cat", panel.rows[1].name.text)
            panel.list:GetScript("OnMouseWheel")(panel.list, -1)
            assert.are.equal("Spider", panel.rows[1].name.text)
            assert.are.equal(1, panel.bar.value, "the bar follows the wheel")
            panel.bar:GetScript("OnValueChanged")(panel.bar, 3)
            assert.are.equal("Cave Boar", panel.rows[1].name.text)
            panel.list:GetScript("OnMouseWheel")(panel.list, 10)
            assert.are.equal("Low Cat", panel.rows[1].name.text, "not above the top")
            panel.bar:GetScript("OnValueChanged")(panel.bar, 999)
            assert.are.equal("High Cat", panel.rows[#panel.rows].name.text, "nor past the end")
            search(panel, "spider")
            assert.is_false(panel.bar.shown, "no bar when all fit")
            assert.are.equal("Spider", panel.rows[1].name.text, "back at the top")
        end)

        it("scrolls a long pick list the same way", function()
            local client = hunter(10, many)
            local panel = tab(client)
            click(panel.pickers.zone)
            local list = client.Addon.pickList
            assert.is_true(list.bar.shown)
            assert.are.equal("All zones", choices(client)[1])
            list.inner:GetScript("OnMouseWheel")(list.inner, -2)
            assert.are.equal("Den 01", choices(client)[1])
            assert.are.equal(15, #choices(client))
        end)
    end)
end)
