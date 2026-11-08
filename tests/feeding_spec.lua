-- Feeding: a button beside the pet frame that feeds the pet the next food from the bags, in the
-- order that keeps it happy cheapest, the order in its tooltip, and toasts when the pet's
-- happiness drops or the bags run out of food it eats. The simulated pet eats meat and is level
-- 15 and happy unless a spec says otherwise; the bags start empty.

local JERKY, HAUNCH, MUTTON, MYSTERY, WOLF, BREAD = 117, 2287, 3770, 12037, 2680, 4540

---The toasts shown from now on, as Huntsworn hands them to listeners.
---@param client table
---@return AddonToastInfo[]
local function toasts(client)
    local seen = {}
    client.Addon.RegisterMessage(seen, "HUNTSWORN_TOAST", function(_, event)
        seen[#seen + 1] = event.toast
    end)
    return seen
end

---The toast with `key` among those seen, if any.
---@param seen AddonToastInfo[]
---@param key string
---@return AddonToastInfo?
local function toastFor(seen, key)
    for _, toast in ipairs(seen) do
        if toast.key == key then return toast end
    end
end

---The mouse over the button: the tooltip's title and its lines' texts and colours.
---@param client table
---@return string? title
---@return table[] lines
local function hover(client)
    client.tooltipLines, GameTooltip.text = {}, nil
    local button = _G.HuntswornFeedButton
    button:GetScript("OnEnter")(button)
    return GameTooltip.text, client.tooltipLines
end

---A level 30 pet and bags with food of every kind.
---@return table
local function stocked()
    local client = NewClient():login()
    client.petLevel = 30
    client:stock(BREAD, 4):stock(JERKY, 6):stock(HAUNCH, 2):stock(MYSTERY, 3):stock(MUTTON, 5):stock(WOLF, 2)
    return client
end

describe("Feeding", function()
    describe("the order", function()
        it("is food for full happiness first, the lowest level, then small stacks; Well Fed food last", function()
            local title, lines = hover(stocked())
            assert.are.equal("Feed Fluffy", title)
            assert.are.equal("Happy", lines[1].text)
            local names = {}
            for i = 2, #lines - 1 do
                names[#names + 1] = lines[i].text
            end
            assert.are.same({
                "Mutton Chop x5",
                "Mystery Meat x3",
                "Haunch of Meat x2",
                "Tough Jerky x6",
                "Spiced Wolf Meat x2 (makes you Well Fed: last)",
            }, names)
            assert.are.same({ 0, 1, 0 }, lines[2].color, "full happiness: green")
            assert.are.same({ 1, 1, 0 }, lines[4].color, "half: yellow")
            assert.are.same({ 1, 0.5, 0 }, lines[5].color, "little: orange")
            assert.are.equal("Click to feed the first, right-click to choose. Shift-drag to move.", lines[#lines].text)
            _G.HuntswornFeedButton:GetScript("OnLeave")(_G.HuntswornFeedButton)
            assert.is_false(GameTooltip:IsShown())
        end)

        it("offers food the client has not loaded yet once it has", function()
            local client = NewClient():login()
            client.unloadedItems[MUTTON] = true
            client:stock(MUTTON, 5):stock(JERKY, 2)
            local function ids()
                local out = {}
                for _, food in ipairs(client.Addon:GetModule("Feeding"):Foods()) do
                    out[#out + 1] = food.itemID
                end
                return out
            end
            assert.are.same({ JERKY }, ids(), "no level to judge it by yet")
            client:loadItem(MUTTON)
            assert.are.same({ JERKY, MUTTON }, ids(), "scanned again once loaded")
        end)

        it("puts the smaller stack first among food of one level", function()
            local client = NewClient():login():stock(MUTTON, 5)
            client.bag[#client.bag + 1] = { itemID = MUTTON, count = 2 }
            client:fire("BAG_UPDATE_DELAYED")
            assert.are.equal("/cast Feed Pet\n/use 0 2", _G.HuntswornFeedButton.attributes.macrotext)
        end)

        it("leaves out food the pet does not eat, and food too far below its level to please it", function()
            local client = stocked()
            client.petLevel = 40
            client:fire("UNIT_LEVEL", "pet")
            local _, lines = hover(client)
            for _, line in ipairs(lines) do
                assert.is_nil(line.text:find("Tough Jerky", 1, true), "35 levels below the pet")
                assert.is_nil(line.text:find("Bread", 1, true), "not eaten by this pet")
            end
        end)

        it("says so when the bags hold nothing the pet eats", function()
            local client = NewClient():login():stock(BREAD, 4)
            local _, lines = hover(client)
            assert.are.equal("Nothing in your bags that Fluffy eats.", lines[2].text)
        end)
    end)

    describe("the button", function()
        it("feeds the first food: Feed Pet on its bag slot", function()
            local client = stocked()
            local button = _G.HuntswornFeedButton
            assert.are.equal("macro", button.attributes.type)
            assert.are.equal("/cast Feed Pet\n/use 0 5", button.attributes.macrotext, "Mutton Chop's slot")
            client:eat(MUTTON):eat(MUTTON):eat(MUTTON):eat(MUTTON):eat(MUTTON)
            assert.are.equal("/cast Feed Pet\n/use 0 4", button.attributes.macrotext, "then Mystery Meat")
        end)

        it("changes after combat, when it cannot before", function()
            local client = NewClient():login():stock(MUTTON, 1):enterCombat()
            client:stock(HAUNCH, 2)
            assert.are.equal("/cast Feed Pet\n/use 0 1", _G.HuntswornFeedButton.attributes.macrotext)
            client:leaveCombat()
            assert.are.equal("/cast Feed Pet\n/use 0 2", _G.HuntswornFeedButton.attributes.macrotext)
        end)

        it("acts on a click as it comes up, whatever ActionButtonUseKeyDown says, the list's rows too", function()
            local client = stocked()
            local button = _G.HuntswornFeedButton
            assert.are.same({ "AnyUp", "AnyDown" }, button.clicks)
            assert.is_false(button.attributes.useOnKeyDown)
            rawget(button, "foodlist")(button)
            local row = _G.HuntswornFeedChoice1
            assert.are.same({ "AnyUp", "AnyDown" }, row.clicks)
            assert.is_false(row.attributes.useOnKeyDown)
            assert.is_not_nil(client)
        end)

        it("waits for Feed Pet: no button, no toasts until the hunter knows it", function()
            local client = NewClient()
            client.unknownSpells[6991] = true -- Feed Pet comes with the quest Training the Beast
            client:login():stock(MUTTON, 5)
            local seen = toasts(client)
            client:setHappiness(2)
            assert.is_false(_G.HuntswornFeedButton.shown, "the pet is content, yet nothing to feed with")
            assert.is_nil(_G.HuntswornFeedButton.attributes.macrotext)
            assert.are.same({}, seen, "no content toast")
            client:eat(MUTTON):eat(MUTTON):eat(MUTTON):eat(MUTTON):eat(MUTTON)
            assert.are.same({}, seen, "no out-of-food toast")
            client.unknownSpells[6991] = nil
            client:fire("SPELLS_CHANGED"):stock(MUTTON, 1)
            assert.is_true(_G.HuntswornFeedButton.shown, "learned: the button for the content pet")
            assert.are.equal("/cast Feed Pet\n/use 0 1", _G.HuntswornFeedButton.attributes.macrotext)
        end)

        it("has nothing to do without food", function()
            NewClient():login()
            assert.is_nil(_G.HuntswornFeedButton.attributes.macrotext)
        end)

        it("shows beside the pet frame only while the pet is not happy, changing after combat", function()
            local client = NewClient():login()
            local button = _G.HuntswornFeedButton
            assert.is_false(button:IsShown(), "a happy pet")
            client:setHappiness(2)
            assert.is_true(button:IsShown())
            assert.are.same({ "LEFT", PetFrame, "RIGHT", 4, 0 }, { button:GetPoint() })
            client:enterCombat():setHappiness(3)
            assert.is_true(button:IsShown(), "a secure button cannot hide in combat")
            client:leaveCombat()
            assert.is_false(button:IsShown())
            client:setHappiness(1):petGone():fire("UNIT_PET", "player")
            assert.is_false(button:IsShown(), "no pet")
        end)

        it("hides while the pet is dead, and comes back once it is revived", function()
            local client = NewClient():login()
            local button = _G.HuntswornFeedButton
            client:setHappiness(2)
            client:petDies()
            assert.is_false(button:IsShown(), "dead")
            client:petBack()
            assert.is_true(button:IsShown(), "revived, still content")
            client:petDies():petGone():fire("UNIT_PET", "player")
            assert.is_false(button:IsShown(), "the dead pet's body gone")
        end)

        it("hides while the pet eats, and comes back after if it is still not happy", function()
            local client = NewClient():login()
            local button = _G.HuntswornFeedButton
            client:setHappiness(2)
            client:petAura(1539, true) -- Feed Pet Effect
            assert.is_false(button:IsShown(), "eating")
            client:petAura(1539, false)
            assert.is_true(button:IsShown(), "done eating, still content")
        end)

        it("moves with Shift held, and stays where it was dropped", function()
            local client = NewClient():login()
            local button = _G.HuntswornFeedButton
            button:GetScript("OnDragStart")(button)
            assert.is_falsy(button.moving, "a plain drag does not move it")
            client.mods.shift = true
            button:GetScript("OnDragStart")(button)
            assert.is_true(button.moving)
            button:GetScript("OnDragStop")(button)
            client:logout()
            local again = NewClient({ saved = Saved() }):login()
            assert.are.same({ "TOPLEFT", UIParent, "BOTTOMLEFT", 300, 700 }, { _G.HuntswornFeedButton:GetPoint() })
            again.Addon:GetModule("Feeding"):GetOptions().args.resetPosition.func()
            assert.are.same({ "LEFT", PetFrame, "RIGHT", 4, 0 }, { _G.HuntswornFeedButton:GetPoint() })
        end)

        it("is gone while the module is off, and on another class", function()
            local client = NewClient():login():stock(MUTTON, 1)
            client.Addon:SetModuleOn("Feeding", false)
            assert.is_nil(_G.HuntswornFeedButton.attributes.macrotext)
            assert.is_false(_G.HuntswornFeedButton:IsShown())
            client.Addon:SetModuleOn("Feeding", true)
            assert.is_not_nil(_G.HuntswornFeedButton.attributes.macrotext)
            NewClient({ class = "MAGE" }):login():stock(MUTTON, 1)
            assert.is_nil(_G.HuntswornFeedButton.attributes.macrotext)
        end)
    end)

    describe("the list on a right-click", function()
        ---A right-click on the feed button: the secure button calls the module's own handler.
        local function rightClick()
            local button = _G.HuntswornFeedButton
            assert.are.equal("foodlist", button.attributes.type2)
            rawget(button, "foodlist")(button, nil, "RightButton")
        end

        ---A click on one row of the list, as the client runs its scripts.
        local function choose(index)
            local choice = _G["HuntswornFeedChoice" .. index]
            for _, hook in ipairs(choice.hooks.OnClick) do
                hook(choice, "LeftButton", false)
            end
        end

        it("shows every food to pick from; a row feeds that food and closes the list", function()
            stocked()
            rightClick()
            assert.is_true(_G.HuntswornFeedList:IsShown())
            local rows = {}
            for i = 1, 5 do
                local choice = _G["HuntswornFeedChoice" .. i]
                assert.is_true(choice:IsShown())
                rows[i] = choice.label.text .. " = " .. choice.attributes.macrotext
            end
            assert.are.same({
                "Mutton Chop x5 = /cast Feed Pet\n/use 0 5",
                "Mystery Meat x3 = /cast Feed Pet\n/use 0 4",
                "Haunch of Meat x2 = /cast Feed Pet\n/use 0 3",
                "Tough Jerky x6 = /cast Feed Pet\n/use 0 2",
                "Spiced Wolf Meat x2 = /cast Feed Pet\n/use 0 6",
            }, rows)
            choose(3)
            assert.is_false(_G.HuntswornFeedList:IsShown())
        end)

        it("hides the rows it no longer needs", function()
            local client = stocked()
            rightClick()
            rightClick()
            assert.is_false(_G.HuntswornFeedList:IsShown(), "a second right-click closes it")
            client:eat(HAUNCH):eat(HAUNCH)
            rightClick()
            assert.is_true(_G.HuntswornFeedChoice4:IsShown())
            assert.is_false(_G.HuntswornFeedChoice5:IsShown())
        end)

        it("closes with Escape, and does not open in combat or without food", function()
            local client = stocked()
            assert.is_true(tContains(UISpecialFrames, "HuntswornFeedList"))
            client:enterCombat()
            rightClick()
            assert.is_false(_G.HuntswornFeedList:IsShown())
            NewClient():login()
            rightClick()
            assert.is_false(_G.HuntswornFeedList:IsShown())
        end)
    end)

    describe("the toasts", function()
        it("say when the pet becomes content, then unhappy, naming the next food", function()
            local client = NewClient():login():stock(MUTTON, 5)
            local seen = toasts(client)
            client:setHappiness(2)
            local content = toastFor(seen, "Feeding:content") --[[@as AddonToastInfo]]
            assert.are.equal("Fluffy is content", content.title)
            assert.are.equal("Feed it: a happy pet does 125% damage.", content.text)
            assert.are.equal("Next: Mutton Chop", content.hint)
            client:setHappiness(1)
            local unhappy = toastFor(seen, "Feeding:unhappy") --[[@as AddonToastInfo]]
            assert.are.equal("Fluffy is unhappy", unhappy.title)
            assert.are.equal("It does 75% damage, and its loyalty drops.", unhappy.text)
            client:setHappiness(1)
            assert.are.equal(2, #seen, "not again while it stays down")
        end)

        it("wait while the hunter casts Revive Pet or tames, and come once the pet is back", function()
            local client = NewClient():login():stock(MUTTON, 5)
            local seen = toasts(client)
            client.cast = 982 -- Revive Pet
            client:setHappiness(1)
            assert.are.same({}, seen, "not while reviving")
            client.cast = nil
            client:petGone():fire("UNIT_PET", "player") -- the body was gone
            -- Each summon counts up the GUID's last field's first byte; the pet number stays.
            client.petGUID = "Pet-0-5250-0-1-165189-02002ED5F4"
            client:petBack():fire("UNIT_PET", "player")
            assert.are.equal("Fluffy is unhappy", toastFor(seen, "Feeding:unhappy").title, "the pet revived, hungry")
            client = NewClient():login():stock(MUTTON, 5)
            seen = toasts(client)
            client.channel = 1515 -- Tame Beast
            client:setHappiness(2)
            assert.are.same({}, seen, "not while taming")
        end)

        it("say nothing of how a pet comes in: logged in with, or a summon of, another content pet", function()
            local client = NewClient()
            client.happiness = 2
            client:login():stock(MUTTON, 5)
            assert.is_nil(client:toastTitle(), "content at login: nothing became content")
            local seen = toasts(client)
            client:petGone():fire("UNIT_PET", "player")
            client.petGUID = "Pet-0-5250-0-1-3126-0100ABCDEF"
            client.happiness = 1
            client:summon("Snapper", {})
            assert.are.same({}, seen, "another pet, unhappy already")
            client:setHappiness(2)
            assert.are.same({}, seen, "it got happier")
            client:setHappiness(1)
            assert.are.equal("Snapper is unhappy", toastFor(seen, "Feeding:unhappy").title)
            -- A beast tamed for a taming quest: a Creature, no pet number.
            client:setHappiness(3)
            client:petGone():fire("UNIT_PET", "player")
            client.petGUID = "Creature-0-5250-0-1-1998-00005E1A20"
            client.happiness = 2
            client:summon("Webwood Lurker", {})
            assert.is_nil(toastFor(seen, "Feeding:content"), "content from the start, not compared with Snapper")
        end)

        it("go once the pet is happy again", function()
            local client = NewClient():login():setHappiness(2)
            assert.are.equal("Fluffy is content", client:toastTitle())
            client:setHappiness(3):animate(1)
            assert.is_false(client:toast().shown)
        end)

        it("name the empty bags instead of a food", function()
            local client = NewClient():login()
            local seen = toasts(client)
            client:setHappiness(2)
            assert.are.equal("Your bags hold nothing it eats.", toastFor(seen, "Feeding:content").hint)
        end)

        it("say when the last food the pet eats leaves the bags, and go when there is food again", function()
            local client = NewClient():login():stock(MUTTON, 1):stock(BREAD, 3)
            local seen = toasts(client)
            client:eat(MUTTON)
            local none = toastFor(seen, "Feeding:nofood") --[[@as AddonToastInfo]]
            assert.are.equal("Nothing for Fluffy to eat", none.title)
            assert.are.equal("Your bags hold no food it eats. Buy some before you go.", none.text)
            client:eat(BREAD)
            assert.are.equal(1, #seen, "once")
            client:stock(HAUNCH, 1):animate(1)
            assert.is_false(client:toast().shown)
        end)

        it("each have a switch", function()
            local client = NewClient():login():stock(MUTTON, 1)
            local args = client.Addon:GetModule("Feeding"):GetOptions().args
            for _, key in ipairs({ "content", "unhappy", "noFood" }) do
                args[key].set(nil, false)
            end
            local seen = toasts(client)
            client:setHappiness(2):setHappiness(1):eat(MUTTON)
            assert.are.same({}, seen)
        end)

        it("say nothing without a pet", function()
            local client = NewClient({ noPet = true }):login():stock(MUTTON, 1)
            local seen = toasts(client)
            client:eat(MUTTON)
            assert.are.same({}, seen)
        end)
    end)
end)
