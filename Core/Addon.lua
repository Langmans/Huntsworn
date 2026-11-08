local addonName, ns = ...

-- The addon object, its saved settings and the module switches.
--
-- Every feature is an AceAddon module (Huntsworn:NewModule). What a module may declare is described
-- by AddonModule in annotations\Addon.lua. The core owns the switch: profile.modules[name] says
-- whether a module runs, and the options page and a profile change both go through
-- SetModuleOn/ApplyModuleStates. A module therefore never enables itself, and its OnDisable must
-- undo everything its OnEnable did (events, hooks, frames shown), because that is also how a
-- profile change reaches it: every running module is disabled, then enabled again from the new
-- profile, so OnEnable only has to read its settings once.

---@type Addon
local Addon = LibStub("AceAddon-3.0"):NewAddon(ns, addonName, "AceConsole-3.0", "AceEvent-3.0")
Addon.L = LibStub("AceLocale-3.0"):GetLocale(addonName)

-- The names the game and other addons see, all made from the folder's name: frames, macros and
-- other addons' registries start with NAME, the slash command is NAME in lower case (and
-- SLASH_ALIAS), messages start with NAME in upper case. What cannot be made from it is the
-- folder, the .tocs and Bindings.xml (docs\10-renaming.md).
Addon.NAME = addonName
Addon.SLASH_ALIAS = "hs"

-- The messages Huntsworn sends (docs\04-hooking.md), by key: messages.petGrowth is
-- "<NAME>_PET_GROWTH".
Addon.messages = {} --[[@as AddonMessages]]
for _, key in ipairs({
    "print",
    "toast",
    "ranksKnown",
    "abilityLearned",
    "petGrowth",
    "autocastWanted",
    "rareSeen",
    "huntStarted",
    "huntEnded",
    "petHappiness",
    "petDied",
    "petState",
    "petTamed",
    "ammo",
    "petAtPull",
}) do
    Addon.messages[key] = addonName:upper() .. "_" .. key:gsub("%u", "_%0"):upper()
end

---A global name of Huntsworn's own: a frame's or a macro's, NAME first ("HuntswornWindow").
---@param suffix string
---@return string
function Addon.Global(suffix)
    return addonName .. suffix
end

-- The game data. The pet ability ranks and the beasts that teach them are LibTameable-1.0's tables
-- (read only; empty on a client without Beast Training). The rest is generated into Huntsworn's own
-- Data folder, empty until the client's one fills it (its .toc lists them): a client without data
-- of its own (Burning Crusade, Mists, retail) keeps these.
---@type LibTameable
local Tameable = LibStub("LibTameable-1.0")
Addon.data = {
    petAbilityRanks = Tameable.ranks,
    beasts = Tameable.beasts,
    speeds = Tameable.speeds,
    trainers = {},
    ammo = {},
    ammoVendors = {},
} --[[@as AddonData]]

-- Every module can register events; anything else it embeds it lists itself.
Addon:SetDefaultModuleLibraries("AceEvent-3.0")

local consolePrint = Addon.Print

---AceConsole's Print, then HUNTSWORN_PRINT ({ module, line }) for whoever listens (docs\04-hooking.md).
---@param module string? the module that says it; nil for the core
---@param ... any
local function PrintFrom(module, ...)
    consolePrint(Addon, ...)
    Addon:SendMessage(Addon.messages.print, { module = module, line = strjoin(" ", tostringall(...)) })
end

---A line in chat from the core.
---@param ... any
function Addon:Print(...)
    PrintFrom(nil, ...)
end

-- What every module has: Print, naming the module in HUNTSWORN_PRINT.
Addon:SetDefaultModulePrototype({
    ---A line in chat from this module.
    ---@param self AddonModule
    ---@param ... any
    Print = function(self, ...)
        PrintFrom(self:GetName(), ...)
    end,
})

function Addon:OnInitialize()
    -- When the session began, for the Dev Probe's times since login.
    self.loginTime = GetTime()
    self:FindFeatures()
    -- A module is on unless it says otherwise; the saved file keeps only switches that differ.
    -- The same for the look a module gives a kind of toast.
    ---@type table<string, boolean>, table<string, string>
    local switches, kindSkins = {}, {}
    for name, module in pairs(self.modules) do
        switches[name] = module.enabledByDefault ~= false
        for kind, skin in pairs(module.toastSkins or {}) do
            kindSkins[name .. ":" .. kind] = skin
        end
    end
    self.db = LibStub("AceDB-3.0"):New(Addon.Global("DB"), {
        profile = {
            modules = switches,
            -- The toast every module shows (Core\Toast\): the skin for every toast, a skin per
            -- kind of toast where chosen or where its module gives one; pos is set once it is
            -- dragged. sink: LibSink's output choice (Integrations\LibSink\).
            toast = { duration = 6, scale = 1, skin = "card", skins = kindSkins, sink = {} },
            -- The look of Huntsworn's buttons and their holders (Core\Buttons.lua): a skin id or "auto".
            buttons = { skin = "auto", holder = "auto", crop = true },
            -- Huntsworn's window (Core\Window.lua): pos is set once it is dragged.
            window = {},
            -- How much goes to OAP Debug when it is installed (Core\Debug.lua).
            oapDebug = "metrics",
        },
        -- Per character: which modules made their macros already (Core\Macro.lua); each pet's
        -- training points total, level and loyalty as last seen, by name (HUNTSWORN_PET_GROWTH,
        -- Core\Listen.lua).
        char = { macrosMade = {}, growth = {} },
    }, true)

    for name, module in pairs(self.modules) do
        if module.defaults then module.db = self.db:RegisterNamespace(name, module.defaults) end
        module:SetEnabledState(self:IsModuleOn(name))
    end

    self.db.RegisterCallback(self, "OnProfileChanged", "ApplyModuleStates")
    self.db.RegisterCallback(self, "OnProfileCopied", "ApplyModuleStates")
    self.db.RegisterCallback(self, "OnProfileReset", "ApplyModuleStates")

    self:SetupOptions()
    self:SetupCommands()
    self:SetupMacros()
    self:ApplyDebugLevel()
end

-- A frame that tries an event on a client without C_EventUtils.
local probe = CreateFrame("Frame")

---Whether this client has an event. Registering one it lacks errors, and AceEvent has noted it by
---then, so unregistering it later (a module switched off, a profile change) errors as well.
---@param event string
---@return boolean
local function HasEvent(event)
    local utils = C_EventUtils
    if utils and utils.IsEventValid then return utils.IsEventValid(event) == true end
    local ok = pcall(probe.RegisterEvent, probe, event)
    if ok then probe:UnregisterEvent(event) end
    return ok
end

---Registers each of `events` this client has for `owner` (a module, or any table AceEvent takes),
---with `handler` (a method name or function; the event's name when nil).
---@param owner table
---@param events string[]
---@param handler (string|function)?
function Addon.RegisterEvents(owner, events, handler)
    for _, event in ipairs(events) do
        -- AceEvent takes a method name too, and nil for the event's own name.
        if HasEvent(event) then
            Addon.RegisterEvent(owner, event, handler --[[@as fun(event: FrameEvent, ...)]])
        end
    end
end

---A string enum whose keys are its values: { "meat", "fish" } gives { meat = "meat", fish = "fish" },
---so each value is written once (Core\Constants).
---@param values string[]
---@return table<string, string>
function Addon.SelfKeyedEnum(values)
    local enum = {}
    for _, value in ipairs(values) do
        enum[value] = value
    end
    return enum
end

---Whether the current profile has this module switched on; never for a module the client's game
---lacks a part of (Huntsworn:IsModuleUsable).
---@param name string
---@return boolean
function Addon:IsModuleOn(name)
    return self.db.profile.modules[name] == true and self:IsModuleUsable(name)
end

---Switches a module on or off in the current profile and starts or stops it now; a module the
---client's game cannot run stays off.
---@param name string
---@param on boolean
function Addon:SetModuleOn(name, on)
    self.db.profile.modules[name] = on
    self:Log("info", on and "module: {1} on" or "module: {1} off", name)
    local module = self.modules[name]
    if on and self:IsModuleUsable(name) then
        module:Enable()
    else
        module:Disable()
    end
end

---After a profile change: stops every module, then starts the ones the new profile has on; the
---new profile's OAP Debug level.
function Addon:ApplyModuleStates()
    for _, module in pairs(self.modules) do
        module:Disable()
    end
    for name, module in pairs(self.modules) do
        if self:IsModuleOn(name) then module:Enable() end
    end
    self:ApplyDebugLevel()
end
