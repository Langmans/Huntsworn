local addonName, ns = ...

-- The bridge to the debug addons, the only file that talks to them. Huntsworn sends to each one that
-- is installed:
--
-- - OAP Debug (a debug window: log, inspector, metrics, Lua errors). Huntsworn registers with it under
--   its folder (so its Lua errors are filed under Huntsworn), sends its own HUNTSWORN_* messages to the
--   log with their table, copies its chat lines and counts the messages; the window's tabs are
--   timed.
-- - _DebugLog (DLAPI: a window of log tabs). The same lines go to a "Huntsworn" tab as text, a table
--   written out; flags before the text colour it (ERR~, WARN~), mark detail (2~, the verbosity
--   column) or name a category (Chat~). It has no counters or timers.
--
-- How much goes is the setting every OAP addon has: errors only, normal, normal + metrics (the
-- default), detailed; it is kept as profile.oapDebug. Without either addon nothing is sent and
-- Huntsworn listens to nothing for them.

---@type Addon
local Addon = ns
local L = Addon.L

local SOURCE = Addon.NAME
local ICON = "Interface\\Icons\\Ability_Hunter_BeastCall"
local ERRORS, NORMAL, METRICS, DETAILED = 1, 2, 3, 4
local LEVELS = { errors = ERRORS, normal = NORMAL, metrics = METRICS, detailed = DETAILED }
-- What a log line of each kind needs.
local NEEDS = { error = ERRORS, warn = NORMAL, info = NORMAL, debug = DETAILED }
-- DebugLog's flags for a line of each kind.
local FLAGS = { error = "ERR~", warn = "WARN~", info = "", debug = "2~" }
-- How deep a table is written out in a DebugLog line.
local DEPTH = 2
-- Huntsworn's messages that go to the log; HUNTSWORN_PRINT goes to its chat tab instead.
local MESSAGES = {
    Addon.messages.toast,
    Addon.messages.ranksKnown,
    Addon.messages.abilityLearned,
    Addon.messages.petGrowth,
    Addon.messages.autocastWanted,
    Addon.messages.rareSeen,
    Addon.messages.huntStarted,
    Addon.messages.huntEnded,
    Addon.messages.petHappiness,
    Addon.messages.petDied,
    Addon.messages.petState,
    Addon.messages.petTamed,
}

local level = METRICS
-- OAP Debug's table, found once when Huntsworn's settings load (OptionalDeps loads it first); nil
-- without it.
---@type OAPDebugApi?
local api
-- DebugLog's table, found the same way; nil without it.
---@type DebugLogApi?
local dl
-- The table Huntsworn listens with, to its own messages.
local listener = {}

---Finds the debug addons and registers Huntsworn with OAP Debug, once.
local function Connect()
    dl = dl or rawget(_G, "DLAPI") --[[@as DebugLogApi?]]
    if api then return end
    api = rawget(_G, "OAPDebug") --[[@as OAPDebugApi?]]
    if api then api.Register(SOURCE, { title = addonName, folder = addonName, icon = ICON }) end
end

---Whether a debug addon is installed.
---@return boolean
function Addon.HasDebugAddon()
    return api ~= nil or dl ~= nil
end

---A value as text for DebugLog: a table as {key=value, ...}, keys in order, written out DEPTH
---levels deep.
---@param value GameValue
---@param depth number
---@return string
local function Written(value, depth)
    if type(value) ~= "table" then return tostring(value) end
    if depth >= DEPTH then return "{...}" end
    ---@type string[]
    local parts = {}
    for key, inner in
        pairs(value --[[@as table<GameValue, GameValue>]])
    do
        parts[#parts + 1] = tostring(key) .. "=" .. Written(inner, depth + 1)
    end
    table.sort(parts)
    return "{" .. table.concat(parts, ", ") .. "}"
end

---A line to DebugLog's Huntsworn tab, as text: "%s" keeps a % in it from being read as a format.
---DebugLog reads every "~" as the end of a flag and has no escape, so a "~" in the text ("~8 min")
---becomes "≈"; the flags ("ERR~", "Chat~") come in separately.
---@param flags string
---@param text string
local function ToDebugLog(flags, text)
    if dl then dl.DebugLog(SOURCE, "%s", flags .. text:gsub("~", "≈")) end
end

---A log line: "error", "warn", "info" or "debug"; values fill {1}, {2}, ... (OAP Debug makes
---tables links, DebugLog gets them written out). A word and a colon first ("probe: ...") is the
---line's category in DebugLog.
---@param kind "error"|"warn"|"info"|"debug"
---@param msg string
---@param ... any
function Addon:Log(kind, msg, ...)
    if level < NEEDS[kind] then return end
    if api then api.Log(SOURCE, msg, kind, ...) end
    if not dl then return end
    local values = { ... } ---@type GameValue[]
    local text = msg:gsub(
        "{(%d+)}",
        ---@param n string
        ---@return string
        function(n)
            return Written(values[tonumber(n)], 0)
        end
    )
    -- "probe: ..." puts the line in DebugLog's category "probe".
    local category, rest = text:match("^([%w_]+): (.*)$")
    if category then
        ToDebugLog(FLAGS[kind] .. category .. "~", rest)
    else
        ToDebugLog(FLAGS[kind], text)
    end
end

---Counts something that happens, from Normal + metrics.
---@param name string
function Addon:Count(name)
    if api and level >= METRICS then api.Count(SOURCE, name) end
end

---Runs fn, timed from Normal + metrics.
---@param name string
---@param fn fun(...)
---@param ... any
function Addon:Time(name, fn, ...)
    if api and level >= METRICS then
        api.Time(SOURCE, name, fn, ...)
    else
        fn(...)
    end
end

---A Huntsworn message: to the log with its table, and counted.
---@param message string
---@param event table
local function OnMessage(message, event)
    Addon:Log("info", message .. ": {1}", event)
    Addon:Count(message)
end

---A chat line Huntsworn printed: to OAP Debug's chat tab, and to DebugLog as a Chat line.
---@param _ string the message
---@param event AddonPrintEvent
local function OnPrint(_, event)
    if api then api.Chat(SOURCE, event.line) end
    ToDebugLog("Chat~", event.line)
end

---Takes the profile's level; listens to Huntsworn's messages while a debug addon is there and the
---level logs them, stops otherwise.
function Addon:ApplyDebugLevel()
    Connect()
    level = LEVELS[self.db.profile.oapDebug] or METRICS
    self:StopListening(listener)
    if level < NORMAL or not Addon.HasDebugAddon() then return end
    self:Listen(listener, Addon.messages.print, OnPrint)
    for _, message in ipairs(MESSAGES) do
        self:Listen(listener, message, OnMessage)
    end
end

---The OAP Debug setting, as on every OAP addon's page.
---@return AceConfig.OptionsTable
function Addon:GetDebugOptions()
    return {
        type = "group",
        inline = true,
        name = L.DEBUG,
        order = 120,
        args = {
            level = {
                type = "select",
                name = L.DEBUG_LEVEL,
                desc = function()
                    return Addon.HasDebugAddon() and L.DEBUG_DESC or L.DEBUG_DESC .. " " .. L.DEBUG_MISSING
                end,
                order = 1,
                values = {
                    errors = L.DEBUG_ERRORS,
                    normal = L.DEBUG_NORMAL,
                    metrics = L.DEBUG_METRICS,
                    detailed = L.DEBUG_DETAILED,
                },
                get = function()
                    return self.db.profile.oapDebug --[[@as string]]
                end,
                ---@param _ table AceConfig's info about the option
                ---@param value string
                set = function(_, value)
                    self.db.profile.oapDebug = value
                    self:ApplyDebugLevel()
                end,
            },
        },
    }
end
