local _, ns = ...

-- The feed button beside the pet frame. Only a secure button the player presses may cast Feed Pet
-- on a bag slot, so its macro text holds the first food's slot; the module rewrites it outside
-- combat. It shows while the pet is alive (Huntsworn.PetState), not happy and not eating (Feed Pet
-- Effect on it): none is a macro condition, so the module shows and hides it itself, also only
-- outside combat (Feed Pet cannot be cast in combat anyway).
-- The border shows the happiness; the tooltip the feeding order. Shift-drag moves it; the place
-- is kept per profile.

---@type Addon
local Addon = ns
local L = Addon.L
local M = Addon:GetModule("Feeding") --[[@as AddonFeeding]]

local H = Addon.happiness
-- Border colour per happiness, and food line colour per bite.
local HAPPINESS = {
    [H.unhappy] = { name = L.FEEDING_UNHAPPY, color = { 1, 0, 0 } },
    [H.content] = { name = L.FEEDING_CONTENT, color = { 1, 1, 0 } },
    [H.happy] = { name = L.FEEDING_HAPPY, color = { 0, 1, 0 } },
}
local HINT_COLOR = { 0.5, 0.5, 0.5 }
local SIZE = 36

local button = CreateFrame("Button", Addon.Global("FeedButton"), UIParent, "SecureActionButtonTemplate")
button:SetSize(SIZE, SIZE)
button:SetFrameStrata("MEDIUM")
-- Down and up registered, acting on the up (useOnKeyDown false, set in ApplyButton, out of combat):
-- a secure button registered for up alone does nothing while the game's ActionButtonUseKeyDown is
-- on (Classic Era's default).
button:RegisterForClicks("AnyUp", "AnyDown")
button:RegisterForDrag("LeftButton")
button:SetMovable(true)
button:Hide()
local icon = button:CreateTexture(nil, "ARTWORK")
icon:SetAllPoints()
button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

-- Styled by the chosen button skin (Core\Buttons.lua) the first time it is given its look, when
-- the settings are there; that gives how to colour the border.
---@type fun(r: number, g: number, b: number)?
local SetBorderColor

M.button = button
-- A right-click runs the module's own handler: a secure button calls a function field named
-- after an action type it does not know, outside the secure path.
button.foodlist = function()
    M:ToggleFoodList()
end

---Puts the button where the profile keeps it, or beside the pet frame (Huntsworn.PetFrame).
function M:PlaceButton()
    local at = self:Settings().position
    button:ClearAllPoints()
    if at then
        button:SetPoint(at[1], UIParent, at[2], at[3], at[4])
    else
        button:SetPoint("LEFT", Addon.PetFrame(), "RIGHT", 4, 0)
    end
end

---Gives the button the first food and its look, and shows it while the pet is not happy; after
---combat when in it. Off, or on another class, it has no food and stays hidden.
function M:ApplyButton()
    Addon:OutOfCombat("Feeding:button", function()
        local _, class = UnitClass("player")
        -- Before Feed Pet (the quest Training the Beast) there is nothing to feed with.
        local active = self:IsEnabled() and class == "HUNTER" and Addon.KnowsSpell(M.FEED_PET)
        local first = active and self:Foods()[1]
        button:SetAttribute("useOnKeyDown", false)
        button:SetAttribute("type2", active and "foodlist" or nil)
        if first then
            button:SetAttribute("type", "macro")
            button:SetAttribute("macrotext", M.FeedMacro(first))
        else
            button:SetAttribute("type", nil)
            button:SetAttribute("macrotext", nil)
        end
        self:PlaceButton()
        local _, feedIcon = Addon.SpellInfo(M.FEED_PET)
        icon:SetTexture(first and C_Item.GetItemIconByID(first.itemID) or feedIcon)
        local watching = active and Addon.PetState() == "alive"
        local happiness = watching and M.Happiness() or H.happy
        local mood = HAPPINESS[happiness]
        SetBorderColor = SetBorderColor or Addon:StyleButton(button, { icon = icon, group = "Feeding" })
        SetBorderColor(mood.color[1], mood.color[2], mood.color[3])
        button:SetShown(happiness < H.happy and not (watching and M.Eating()))
    end)
end

---The tooltip: the pet's happiness, then every food in feeding order.
---@param self Button
local function OnEnter(self)
    local pet = UnitName("pet") or ""
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L.FEEDING_TOOLTIP:format(pet))
    local happiness = HAPPINESS[M.Happiness() or H.happy]
    GameTooltip:AddLine(happiness.name, happiness.color[1], happiness.color[2], happiness.color[3])
    local foods = M:Foods()
    for _, food in ipairs(foods) do
        local text = L.FEEDING_FOOD:format(M.FoodName(food), food.count)
        GameTooltip:AddLine(food.wellFed and text .. L.FEEDING_WELL_FED or text, M.FoodColor(food))
    end
    if #foods == 0 then GameTooltip:AddLine(L.FEEDING_NO_FOOD:format(pet), 1, 1, 1) end
    GameTooltip:AddLine(L.FEEDING_CLICK, HINT_COLOR[1], HINT_COLOR[2], HINT_COLOR[3])
    GameTooltip:Show()
end

local function OnLeave()
    GameTooltip:Hide()
end

---Shift-drag moves the button, outside combat (a secure button cannot move in it).
---@param self Button
local function OnDragStart(self)
    if IsShiftKeyDown() and not InCombatLockdown() then self:StartMoving() end
end

---Dropped: keeps the place in the profile.
---@param self Button
local function OnDragStop(self)
    self:StopMovingOrSizing()
    local point, _, relativePoint, x, y = self:GetPoint()
    M:Settings().position = { point, relativePoint, x, y }
end

button:SetScript("OnEnter", OnEnter)
button:SetScript("OnLeave", OnLeave)
button:SetScript("OnDragStart", OnDragStart)
button:SetScript("OnDragStop", OnDragStop)
