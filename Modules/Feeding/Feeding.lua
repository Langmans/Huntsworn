local _, ns = ...

-- Feeding the pet: the food in the bags it eats, in the order the button (Button.lua) feeds it,
-- and toasts when its happiness drops or the bags run out of food it eats.
--
-- A feeding gives the pet 8, 17 or 35 happiness a bite, by how far the food's item level lies
-- below the pet's (BITES); food further below gives nothing and is left out. The order: the most
-- happiness first, then the lowest level (keep the better food for later), then the smallest
-- stack (frees a slot). Food that also makes the hunter Well Fed comes last, whatever it gives.
-- Whether the pet eats an item is the client's answer (C_PetInfo.CanPetEatItem).
--
-- Only a hunter has a pet to feed: on any other class the module watches nothing.

---@type Addon
local Addon = ns
local L = Addon.L

---@type AddonFeeding
local M = Addon:NewModule("Feeding")
M.title = L.FEEDING_TITLE
M.description = L.FEEDING_DESC
M.requires = { "happiness" }
M.toastTypes = {
    content = L.FEEDING_TOASTTYPE_CONTENT,
    unhappy = L.FEEDING_TOASTTYPE_UNHAPPY,
    nofood = L.FEEDING_TOASTTYPE_NOFOOD,
}
M.defaults = { profile = { content = true, unhappy = true, noFood = true } }

M.FEED_PET = Addon.FEED_PET
-- The buff on the pet while it eats (the same ID on Classic Era and WoW: Forever).
local FEED_PET_EFFECT = 1539
local FEED_PET_NAME = "Feed Pet" -- for a client that cannot name the spell itself
local FEED_PET_ICON = 132165
local WELL_FED = 19705 -- a Well Fed buff: its name is what a food's tooltip says
-- Happiness a bite by levels below the pet: at most `below` levels lower gives `bite`.
local BITES = { { below = 10, bite = 35 }, { below = 20, bite = 17 }, { below = 30, bite = 8 } }
local HAPPY, CONTENT, UNHAPPY = Addon.happiness.happy, Addon.happiness.content, Addon.happiness.unhappy

---The settings of the profile in use.
---@return AddonFeedingSettings
function M:Settings()
    return self.db.profile --[[@as AddonFeedingSettings]]
end

---Feed Pet's name as the client calls it, for the button's macro.
---@return string
function M.FeedPetName()
    return Addon.SpellInfo(M.FEED_PET) or FEED_PET_NAME
end

---The happiness a bite of food at `level` gives a pet at `petLevel`: 35, 17, 8, or 0.
---@param level number
---@param petLevel number
---@return number
local function Bite(level, petLevel)
    for _, step in ipairs(BITES) do
        if petLevel - level <= step.below then return step.bite end
    end
    return 0
end

-- Per item, whether it makes the hunter Well Fed: its tooltip never changes once loaded.
---@type table<number, boolean>
local wellFed = {}

---Whether an item's tooltip (Huntsworn.C.TooltipInfo) says it makes the eater Well Fed (any case:
---"you will become well fed"). Kept per item once the client has loaded it; asked again while it
---has not.
---@param itemID number
---@return boolean
local function MakesWellFed(itemID)
    if wellFed[itemID] ~= nil then return wellFed[itemID] end
    local buff = (Addon.SpellInfo(WELL_FED) or "Well Fed"):lower()
    local found = false
    local lines = Addon.C.TooltipInfo.GetItemByID(itemID).lines
    for _, line in ipairs(lines) do
        local text = line.leftText
        if Addon.Readable(text) and type(text) == "string" and text:lower():find(buff, 1, true) then found = true end
    end
    if #lines > 0 then wellFed[itemID] = found end
    return found
end

-- The food in the bags, in feeding order; the entries are reused from scan to scan.
---@type AddonFood[]
local foods, pool = {}, {}

---Two foods in feeding order.
---@param a AddonFood
---@param b AddonFood
---@return boolean
local function Before(a, b)
    if a.wellFed ~= b.wellFed then return b.wellFed end
    if a.bite ~= b.bite then return a.bite > b.bite end
    if a.level ~= b.level then return a.level < b.level end
    if a.count ~= b.count then return a.count < b.count end
    return a.bag * 1000 + a.slot < b.bag * 1000 + b.slot
end

-- Food the client has not loaded yet, by item ID: waited on once, then the bags are read again.
---@type table<number, true>
local waiting = {}

---Adds the food in one bag slot to `foods` when the pet eats it and it pleases the pet. Food the
---client has not loaded has no level to judge it by: once loaded, the bags are read again.
---@param bag number
---@param slot number
---@param petLevel number
local function AddSlot(bag, slot, petLevel)
    local item = C_Container.GetContainerItemInfo(bag, slot)
    if not item or not Addon.C.PetInfo.CanPetEatItem(item.itemID) then return end
    local itemID = item.itemID
    local level = select(4, C_Item.GetItemInfo(itemID))
    if not level and not waiting[itemID] then
        waiting[itemID] = true
        Addon.WhenItemLoaded(itemID, function()
            waiting[itemID] = nil
            if M:IsEnabled() then M:Update() end
        end)
    end
    local bite = level and Bite(level, petLevel) or 0
    if bite == 0 then return end
    local food = pool[#foods + 1] or {}
    pool[#foods + 1] = food
    food.bag, food.slot, food.itemID, food.count = bag, slot, item.itemID, item.stackCount
    food.level, food.bite, food.wellFed = level, bite, MakesWellFed(item.itemID)
    foods[#foods + 1] = food
end

---Reads the bags again: the food the pet out eats, in feeding order. Empty without a pet.
---@return AddonFood[]
function M:Scan()
    wipe(foods)
    local petLevel = UnitExists("pet") and UnitLevel("pet")
    if not petLevel then return foods end
    for bag = 0, NUM_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            AddSlot(bag, slot, petLevel)
        end
    end
    table.sort(foods, Before)
    return foods
end

---The food in feeding order, as of the last scan.
---@return AddonFood[]
function M:Foods()
    return foods
end

---A food's name, as the client gives it.
---@param food AddonFood
---@return string
function M.FoodName(food)
    return C_Item.GetItemInfo(food.itemID) or ("item:" .. food.itemID)
end

---The macro that feeds a food: Feed Pet, then its bag slot as the item it waits for.
---@param food AddonFood
---@return string
function M.FeedMacro(food)
    return ("/cast %s\n/use %d %d"):format(M.FeedPetName(), food.bag, food.slot)
end

-- A food's colour by the happiness a bite gives; Well Fed food grey.
local BITE_COLORS = { [35] = { 0, 1, 0 }, [17] = { 1, 1, 0 }, [8] = { 1, 0.5, 0 } }
local WELL_FED_COLOR = { 0.6, 0.6, 0.6 }

---A food's colour in the tooltip and the list.
---@param food AddonFood
---@return number r, number g, number b
function M.FoodColor(food)
    local color = food.wellFed and WELL_FED_COLOR or BITE_COLORS[food.bite]
    return color[1], color[2], color[3]
end

local Happiness = Addon.PetHappiness
M.Happiness = Happiness

-- Per toast: its title (%s: the pet's name) and text.
---@type table<string, {title: string, text: string}>
local TOASTS = {
    content = { title = L.FEEDING_TOAST_CONTENT, text = L.FEEDING_REASON_CONTENT },
    unhappy = { title = L.FEEDING_TOAST_UNHAPPY, text = L.FEEDING_REASON_UNHAPPY },
    nofood = { title = L.FEEDING_TOAST_NOFOOD, text = L.FEEDING_REASON_NOFOOD },
}

---The toast for `kind`: for a happiness drop with the food the button feeds next as its hint.
---@param kind "content"|"unhappy"|"nofood"
---@return AddonToastInfo
function M:Toast(kind)
    local first = foods[1]
    local hint = first and L.FEEDING_NEXT:format(M.FoodName(first)) or L.FEEDING_HINT_NO_FOOD
    local _, feedIcon = Addon.SpellInfo(M.FEED_PET)
    return {
        key = "Feeding:" .. kind,
        type = "Feeding:" .. kind,
        source = self.title,
        title = TOASTS[kind].title:format(UnitName("pet") or ""),
        text = TOASTS[kind].text,
        hint = kind ~= "nofood" and hint or nil,
        icon = first and C_Item.GetItemIconByID(first.itemID) or feedIcon or FEED_PET_ICON,
    }
end

---Toasts a happiness drop (once per level reached) and takes away the toasts a rise answers. The
---first reading of a pet (at login, or another pet summoned) only takes note: nothing dropped. Not
---while the hunter revives the pet or tames a beast: the drop is not taken in then, so the pet
---that comes back hungry still gets its toast (UNIT_PET checks again).
function M:CheckHappiness()
    self:ApplyButton()
    if Addon.IsCasting(Addon.REVIVE_PET) or Addon.IsTaming() then return end
    -- Here and not in UNIT_PET: the core's happiness message may come before that event.
    local key = Addon.PetKey()
    if key and key ~= self.happinessPet then
        self.happiness, self.happinessPet = nil, key
    end
    local happiness = Happiness()
    if not happiness then return end
    local last = self.happiness
    self.happiness = happiness
    local settings = self:Settings()
    if happiness > UNHAPPY then Addon:DropToast("Feeding:unhappy") end
    if happiness > CONTENT then Addon:DropToast("Feeding:content") end
    if not last or happiness >= last or not Addon.KnowsSpell(M.FEED_PET) then return end
    if happiness == CONTENT and settings.content then Addon:ShowToast(self:Toast("content")) end
    if happiness == UNHAPPY and settings.unhappy then Addon:ShowToast(self:Toast("unhappy")) end
end

---Scans the bags, gives the button its food, and says when the last food the pet eats has gone.
function M:Update()
    local had = #foods > 0
    self:Scan()
    self:CloseFoodList()
    self:ApplyButton()
    if #foods > 0 then
        Addon:DropToast("Feeding:nofood")
    elseif had and UnitExists("pet") and self:Settings().noFood and Addon.KnowsSpell(M.FEED_PET) then
        Addon:ShowToast(self:Toast("nofood"))
    end
end

function M:BAG_UPDATE_DELAYED()
    self:Update()
end

-- A pet summoned or dismissed: another pet, another diet and level. The same pet back (revived,
-- or summoned again) keeps its last happiness, so a drop meanwhile still toasts.
---@param _ string the event
---@param unit string
function M:UNIT_PET(_, unit)
    if unit ~= "player" then return end
    wipe(foods)
    self:Update()
    self:CheckHappiness()
end

---@param _ string the event
---@param unit string
function M:UNIT_LEVEL(_, unit)
    if unit == "pet" then self:Update() end
end

---Whether the pet is eating: Feed Pet Effect is on it. False where the client cannot tell.
---@return boolean
function M.Eating()
    local name = Addon.SpellInfo(FEED_PET_EFFECT)
    return name ~= nil and C_UnitAuras ~= nil and C_UnitAuras.GetAuraDataBySpellName("pet", name, "HELPFUL") ~= nil
end

-- The pet's buffs changed: the button again when it started or stopped eating (UNIT_AURA comes
-- often, the button changes only then).
---@param _ string the event
---@param unit string
function M:UNIT_AURA(_, unit)
    if unit ~= "pet" then return end
    local eating = M.Eating()
    if eating == self.eating then return end
    self.eating = eating
    self:ApplyButton()
end

-- The core's HUNTSWORN_PET_HAPPINESS: the pet's happiness changed.
function M:OnHappiness()
    self:CheckHappiness()
end

-- The core's HUNTSWORN_PET_STATE: the pet died, came back or went; no button for a dead pet.
function M:OnPetState()
    self:ApplyButton()
end

-- Not every client has every one; a missing one is skipped.
local EVENTS = { "BAG_UPDATE_DELAYED", "UNIT_PET", "UNIT_LEVEL", "SPELLS_CHANGED", "UNIT_AURA" }

---Feed Pet learned (or the spellbook changed otherwise): the button again when that changed.
function M:SPELLS_CHANGED()
    local canFeed = Addon.KnowsSpell(M.FEED_PET)
    if canFeed == self.canFeed then return end
    self.canFeed = canFeed
    self:Update()
end

function M:OnEnable()
    local _, class = UnitClass("player")
    if class ~= "HUNTER" then return end
    Addon.RegisterEvents(self, EVENTS)
    Addon:Listen(self, Addon.messages.petHappiness, "OnHappiness")
    Addon:Listen(self, Addon.messages.petState, "OnPetState")
    self.happiness = nil
    self.canFeed = Addon.KnowsSpell(M.FEED_PET)
    wipe(foods)
    self:Update()
end

-- AceEvent drops the events by itself; the toasts and the button go here.
function M:OnDisable()
    Addon:StopListening(self)
    Addon:DropToasts("Feeding:")
    wipe(foods)
    self:CloseFoodList()
    self:ApplyButton()
end
