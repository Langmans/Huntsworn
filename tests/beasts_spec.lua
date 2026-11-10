-- The beast data Huntsworn gets from LibTameable-1.0: pet ability ranks and the beasts that teach
-- them, loaded here on its own per client, with the family table Huntsworn shows them by (the module
-- specs use a small data set instead).

-- WOW_PROJECT_ID of each client the library has data for.
local PROJECTS = { era = 2, tbc = 5, forever = 18 }

---@param client string? a PROJECTS key, WoW: Forever by default
---@return table<number, AddonPetAbilityRank>, table<number, AddonBeast>, table<number, AddonFamilyInfo>
local function Load(client)
    -- Core\Addon.lua's Huntsworn.SelfKeyedEnum, which needs the whole addon to load.
    local ns = { L = {}, SelfKeyedEnum = NewClient().Addon.SelfKeyedEnum }
    assert(loadfile("Core/Constants/Enums.lua"))("Huntsworn", ns)
    assert(loadfile("Core/Constants/Families.lua"))("Huntsworn", ns)
    -- The loaded files read these from _G, not from the spec's own environment.
    _G.WOW_PROJECT_ID = PROJECTS[client or "forever"]
    _G.LibStub = nil
    assert(loadfile("Libs/LibStub/LibStub.lua"))()
    assert(loadfile("Libs/LibTameable-1.0/LibTameable-1.0.lua"))()
    for _, file in ipairs({ "Era", "TBC", "Forever" }) do
        assert(loadfile("Libs/LibTameable-1.0/Data/" .. file .. ".lua"))()
    end
    local lib = LibStub("LibTameable-1.0")
    return lib.ranks, lib.beasts, ns.familyInfo
end

---@param list number[]
---@param value number
---@return boolean
local function tContains(list, value)
    for _, v in ipairs(list) do
        if v == value then return true end
    end
    return false
end

local BITE, CLAW_2, SWIPE = 17253, 16828, 1264494
local FOREST_SPIDER, GRIZZLED_BLACK_BEAR, NIGHT_WEB_SPIDER = 30, 1188, 1505
local ELWYNN, SPIDER, CAT, BEAR = 1429, 3, 2, 4

describe("the beast data", function()
    local ranks, beasts, families = Load()

    for client in pairs(PROJECTS) do
        it("names only families Huntsworn's family table has (" .. client .. ")", function()
            local clientRanks, clientBeasts = Load(client)
            assert.is_not_nil(next(clientBeasts))
            for npc, beast in pairs(clientBeasts) do
                assert.is_truthy(families[beast.family], npc .. " " .. beast.name)
            end
            for spellID, rank in pairs(clientRanks) do
                for _, family in ipairs(rank.families) do
                    assert.is_truthy(families[family], spellID)
                end
            end
        end)
    end

    it("gives a beast one rank of each ability", function()
        ---@type table<number, table<number, true>>
        local seen = {}
        for spellID, rank in pairs(ranks) do
            for _, npc in ipairs(rank.teachers) do
                seen[npc] = seen[npc] or {}
                assert.is_nil(seen[npc][rank.ability], npc .. " teaches two ranks of " .. rank.ability)
                seen[npc][rank.ability] = true
            end
        end
    end)

    it("knows a rank's ability, number, pet level and the families that learn it", function()
        local claw = ranks[CLAW_2]
        assert.are.equal(16827, claw.ability)
        assert.are.equal(2, claw.rank)
        assert.is_true(claw.level > 0)
        assert.is_true(tContains(claw.families, CAT))
    end)

    it("ties every rank to its ability's rank 1", function()
        for id, rank in pairs(ranks) do
            local first = ranks[rank.ability]
            assert.is_not_nil(first, id)
            assert.are.equal(1, first.rank, id)
        end
    end)

    it("names only beasts it has, and only beasts that teach", function()
        local teaches = {}
        for id, rank in pairs(ranks) do
            for _, npc in ipairs(rank.teachers) do
                assert.is_not_nil(beasts[npc], ("rank %d: beast %d"):format(id, npc))
                teaches[npc] = true
                if #rank.families > 0 then
                    assert.is_true(tContains(rank.families, beasts[npc].family), ("rank %d: beast %d"):format(id, npc))
                end
            end
        end
        for npc in pairs(beasts) do
            assert.is_true(teaches[npc], npc)
        end
    end)

    it("places a beast by pins on a map, or by zone when Wowhead has no map", function()
        for npc, beast in pairs(beasts) do
            assert.is_true(beast.minLevel <= beast.maxLevel, npc)
            assert.are_not.equal(beast.pins == nil, beast.zones == nil, npc)
            for map, flat in pairs(beast.pins or {}) do
                assert.is_true(#flat > 0 and #flat % 2 == 0, ("%d on map %d"):format(npc, map))
                for _, v in ipairs(flat) do
                    assert.is_true(v >= 0 and v <= 100, ("%d on map %d"):format(npc, map))
                end
            end
        end
        local spider = beasts[FOREST_SPIDER]
        assert.are.equal(SPIDER, spider.family)
        assert.is_not_nil(spider.pins[ELWYNN])
        assert.is_true(tContains(ranks[BITE].teachers, FOREST_SPIDER))
    end)

    it("has the pet trainers and stable masters, each with a faction it serves and its spots", function()
        local ns = {}
        assert(loadfile("Core/Constants/Enums.lua"))("Huntsworn", ns)
        assert(loadfile("Data/Forever/Trainers.lua"))("Huntsworn", ns)
        local count = { trainer = 0, stable = 0 }
        for npc, trainer in pairs(ns.data.trainers) do
            count[trainer.kind] = count[trainer.kind] + 1
            assert.is_string(trainer.name, npc)
            assert.is_true(trainer.side == nil or trainer.side == "Alliance" or trainer.side == "Horde", npc)
            assert.is_nil(beasts[npc], "no trainer is a beast too")
            for map, flat in pairs(trainer.pins) do
                assert.is_true(#flat > 0 and #flat % 2 == 0, ("%d on map %d"):format(npc, map))
                for _, v in ipairs(flat) do
                    assert.is_true(v >= 0 and v <= 100, ("%d on map %d"):format(npc, map))
                end
            end
        end
        assert.is_true(count.trainer >= 10, "pet trainers")
        assert.is_true(count.stable >= 30, "stable masters")
    end)

    it("has what Wowhead's hunter-pets tool says a beast teaches, and no more", function()
        assert.is_true(tContains(ranks[SWIPE].teachers, GRIZZLED_BLACK_BEAR))
        assert.are.equal(BEAR, beasts[GRIZZLED_BLACK_BEAR].family)
        assert.is_nil(beasts[NIGHT_WEB_SPIDER], "only can learn Bite: teaches nothing")
        assert.is_not_nil(beasts[FOREST_SPIDER].pins[ELWYNN])
    end)
end)
