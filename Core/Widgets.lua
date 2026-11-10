local _, ns = ...

-- Small widgets for the window's tabs, built from plain frames so they work the same on every
-- client (the game's dropdowns differ between Classic Era and WoW: Forever):
-- - a scrollbar beside a list of rows, which also takes the list's mouse wheel;
-- - a picker: a button saying "Ability: Claw" that opens the pick list, one list shared by every
--   picker, under it. A choice, a second click on the picker, Escape or the picker hiding closes it.

---@type Addon
local Addon = ns

local BAR_WIDTH, THUMB = 12, "Interface\\Buttons\\UI-ScrollBar-Knob"
local PICKER_HEIGHT, PICK_ROWS, PICK_HEIGHT, PICK_PAD = 20, 15, 18, 4
local ARROW = "Interface\\ChatFrame\\ChatFrameExpandArrow"
local CHOSEN, OTHER = { 1, 1, 1 }, { 0.75, 0.75, 0.75 }

---Moves the list to `offset` when it differs from where it is, and tells the list's owner.
---@param bar AddonScrollBar
---@param offset number
local function ScrollTo(bar, offset)
    offset = math.max(0, math.min(bar.last, math.floor(offset + 0.5)))
    if offset == bar.offset then return end
    bar.offset = offset
    bar:SetValue(offset)
    bar.OnScroll(offset)
end

---The bar dragged or clicked; also fired by its own SetValue, then with the offset it has.
---@param bar AddonScrollBar
---@param value number
local function OnValueChanged(bar, value)
    ScrollTo(bar, value)
end

---Sets how many rows there are and how many show: the bar shows only when they do not all fit,
---and the offset stays within them. Does not call OnScroll: the owner is filling the rows.
---@param bar AddonScrollBar
---@param total number
---@param visible number
local function SetRange(bar, total, visible)
    bar.last = math.max(0, total - visible)
    -- Set before the bar's range: a smaller range moves the thumb and fires OnValueChanged.
    bar.offset = math.min(bar.offset, bar.last)
    bar:SetMinMaxValues(0, bar.last)
    bar:SetValue(bar.offset)
    bar:SetShown(bar.last > 0)
end

---A scrollbar on the right of `list`, outside it; the list takes the mouse wheel. OnScroll gets the
---new offset (rows scrolled past) whenever the wheel or the bar moves it.
---@param list Frame
---@param OnScroll fun(offset: number)
---@return AddonScrollBar
function Addon.ScrollBar(list, OnScroll)
    local bar = CreateFrame("Slider", nil, list) --[[@as AddonScrollBar]]
    bar:SetOrientation("VERTICAL")
    bar:SetWidth(BAR_WIDTH)
    bar:SetPoint("TOPLEFT", list, "TOPRIGHT", 2, 0)
    bar:SetPoint("BOTTOMLEFT", list, "BOTTOMRIGHT", 2, 0)
    bar:SetValueStep(1)
    bar:SetObeyStepOnDrag(true)
    bar.track = bar:CreateTexture(nil, "BACKGROUND")
    bar.track:SetAllPoints()
    bar.track:SetColorTexture(1, 1, 1, 0.08)
    bar:SetThumbTexture(THUMB)
    bar.offset, bar.last, bar.OnScroll, bar.SetRange = 0, 0, OnScroll, SetRange
    bar:SetScript("OnValueChanged", OnValueChanged)
    list:EnableMouseWheel(true)
    ---@param _ Frame
    ---@param delta number 1 up, -1 down
    list:SetScript("OnMouseWheel", function(_, delta)
        ScrollTo(bar, bar.offset - delta)
    end)
    return bar
end

---The pick list, made the first time a picker opens it.
---@return AddonPickList
local function PickList()
    if Addon.pickList then return Addon.pickList end
    local list = CreateFrame("Frame", Addon.Global("PickList"), UIParent, "BackdropTemplate") --[[@as AddonPickList]]
    list:SetFrameStrata("DIALOG")
    list:SetClampedToScreen(true)
    list:Hide()
    table.insert(UISpecialFrames, Addon.Global("PickList"))
    local skin = Addon:StyleButtonHolder(list)
    list.inner = CreateFrame("Frame", nil, list)
    list.inner:SetPoint("TOPLEFT", PICK_PAD, -PICK_PAD)
    list.inner:SetPoint("BOTTOMRIGHT", -PICK_PAD - BAR_WIDTH - 2, PICK_PAD)
    list.rows = {}
    for index = 1, PICK_ROWS do
        local row = CreateFrame("Button", nil, list.inner) --[[@as AddonPickRow]]
        row:SetHeight(PICK_HEIGHT)
        row:SetPoint("TOPLEFT", 0, -(index - 1) * PICK_HEIGHT)
        row:SetPoint("RIGHT")
        row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.label:SetPoint("LEFT", 4, 0)
        row.label:SetPoint("RIGHT", -4, 0)
        row.label:SetJustifyH("LEFT")
        row.label:SetWordWrap(false)
        skin.Font(row.label, 12)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        row:SetScript("OnClick", function()
            local picker = list.picker --[[@as AddonPicker]]
            list:Hide()
            picker.OnPick(row.value --[[@as string|number]])
        end)
        list.rows[index] = row
    end
    list.bar = Addon.ScrollBar(list.inner, function()
        Addon.FillPickList()
    end)
    Addon.pickList = list
    return list
end

---Fills the pick list's rows from its picker's choices, from the offset on; the chosen one white.
function Addon.FillPickList()
    local list = Addon.pickList --[[@as AddonPickList]]
    local picker = list.picker --[[@as AddonPicker]]
    list.bar:SetRange(#picker.values, PICK_ROWS)
    for index, row in ipairs(list.rows) do
        local at = index + list.bar.offset
        local value = picker.values[at]
        row.value = value
        row:SetShown(value ~= nil)
        if value ~= nil then
            row.label:SetText(picker.texts[at])
            local colour = value == picker.value and CHOSEN or OTHER
            row.label:SetTextColor(colour[1], colour[2], colour[3])
        end
    end
end

---Opens the pick list under a picker, or closes it when it is open for that picker.
---@param picker AddonPicker
local function TogglePickList(picker)
    local list = PickList()
    if list:IsShown() and list.picker == picker then
        list:Hide()
        return
    end
    list.picker, list.bar.offset = picker, 0
    Addon.FillPickList()
    list:SetSize(picker:GetWidth() + BAR_WIDTH + 2, math.min(#picker.values, PICK_ROWS) * PICK_HEIGHT + 2 * PICK_PAD)
    list:ClearAllPoints()
    list:SetPoint("TOPLEFT", picker, "BOTTOMLEFT", 0, -2)
    list:Show()
end

---A picker hiding (its tab, the window) takes its open list along.
---@param picker AddonPicker
local function OnPickerHide(picker)
    local list = Addon.pickList
    if list and list.picker == picker then list:Hide() end
end

---A picker: a button saying "<title>: <choice>" that opens the pick list of its choices. The owner
---fills `values` and `texts` (in the order they list) and calls FillPicker; a choice clicked calls
---OnPick with its value.
---@param parent Frame
---@param skin AddonButtonHolderSkin
---@param width number
---@param title string
---@param OnPick fun(value: string|number)
---@return AddonPicker
function Addon.Picker(parent, skin, width, title, OnPick)
    local picker = CreateFrame("Button", nil, parent) --[[@as AddonPicker]]
    picker:SetSize(width, PICKER_HEIGHT)
    picker.back = picker:CreateTexture(nil, "BACKGROUND")
    picker.back:SetAllPoints()
    picker.back:SetColorTexture(0, 0, 0, 0.4)
    picker.arrow = picker:CreateTexture(nil, "ARTWORK")
    picker.arrow:SetSize(12, 12)
    picker.arrow:SetPoint("RIGHT", -4, 0)
    picker.arrow:SetTexture(ARROW)
    picker.label = picker:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    picker.label:SetPoint("LEFT", 6, 0)
    picker.label:SetPoint("RIGHT", picker.arrow, "LEFT", -2, 0)
    picker.label:SetJustifyH("LEFT")
    picker.label:SetWordWrap(false)
    skin.Font(picker.label, 12)
    picker:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    picker.title, picker.OnPick, picker.values, picker.texts = title, OnPick, {}, {}
    picker:SetScript("OnClick", TogglePickList)
    picker:SetScript("OnHide", OnPickerHide)
    return picker
end

---Shows a picker's choice: `value`, or its first choice when `value` is not one of them. Returns
---the value it shows.
---@param picker AddonPicker
---@param value string|number
---@return string|number
function Addon.FillPicker(picker, value)
    local at = 1
    for index, choice in ipairs(picker.values) do
        if choice == value then at = index end
    end
    picker.value = picker.values[at]
    picker.label:SetText(Addon.L.WINDOW_PICKED:format(picker.title, picker.texts[at]))
    return picker.value
end
