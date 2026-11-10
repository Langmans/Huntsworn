local _, ns = ...

-- The hunt: the hunter picks one beast to tame for one rank ("I'm taming this one for Claw 3"),
-- from a rank's button in the Abilities tab or a beast's pin. Huntsworn then shows the way there,
-- gives the beast to the tame key, and marks the beast's areas on the world map and the minimap
-- (Areas.lua). The hunt is kept per character and ends once the hunter knows the rank; with the
-- huntEndsAtTame switch already when a beast that teaches the rank is tamed, the hunted one or any
-- other (the pet still has to use the ability to teach it). It also ends on the button again, a
-- right-click on the tame key's button, or /huntsworn hunt stop. HUNTSWORN_HUNT_STARTED and
-- HUNTSWORN_HUNT_ENDED tell other addons.

---@type Addon
local Addon = ns
local L = Addon.L
local M = Addon:GetModule("BeastMap") --[[@as AddonBeastMap]]

---The hunt on, if any.
---@return AddonHunt?
function M:Hunt()
    return self.db.char.hunt --[[@as AddonHunt?]]
end

---Whether the hunt on is for beast `npc` and rank `spellID`.
---@param npc number?
---@param spellID number?
---@return boolean
function M:IsHunting(npc, spellID)
    local hunt = self:Hunt()
    return hunt ~= nil and hunt.npc == npc and hunt.spellID == spellID
end

---Starts hunting beast `npc` for rank `spellID`, going to its nearest spot or to the one given.
---@param npc number
---@param spellID number
---@param map number? a pin's map, with x and y (0 to 1)
---@param x number?
---@param y number?
function M:StartHunt(npc, spellID, map, x, y)
    if not self:IsEnabled() then return end
    if self:Hunt() then self:StopHunt() end
    self.db.char.hunt = { npc = npc, spellID = spellID }
    local name = M.BeastName(npc)
    self:Print(L.BEASTMAP_HUNT_START:format(name, M.RankText(spellID) or "?"))
    self:GoToBeast(npc, map, x, y)
    Addon:SendMessage(
        Addon.messages.huntStarted,
        { module = self:GetName(), npc = npc, spellID = spellID, name = name }
    )
    self:ShowHunt()
    self:ApplyTameButton()
    Addon:RefreshWindow("abilities")
    Addon:RefreshWindow("beasts")
end

---Ends the hunt on: "learned" when the hunter knows the rank now, "tamed" when a pet that teaches
---it was tamed, else "stopped".
---@param reason "learned"|"tamed"|"stopped"?
---@param pet string? the tamed pet's name, for "tamed"
function M:StopHunt(reason, pet)
    local hunt = self:Hunt()
    if not hunt then
        self:Print(L.BEASTMAP_HUNT_NONE)
        return
    end
    self.db.char.hunt = nil
    local name = M.BeastName(hunt.npc)
    if reason == "learned" then
        self:Print(L.BEASTMAP_HUNT_LEARNED:format(M.RankText(hunt.spellID) or "?", name))
    elseif reason == "tamed" then
        self:Print(L.BEASTMAP_HUNT_TAMED:format(pet or "?", M.RankText(hunt.spellID) or "?", name))
    else
        self:Print(L.BEASTMAP_HUNT_STOPPED:format(name))
    end
    Addon:SendMessage(
        Addon.messages.huntEnded,
        { module = self:GetName(), npc = hunt.npc, spellID = hunt.spellID, name = name, reason = reason or "stopped" }
    )
    self:ShowHunt()
    self:ApplyTameButton()
    Addon:RefreshWindow("abilities")
    Addon:RefreshWindow("beasts")
end

---HUNTSWORN_RANKS_KNOWN: the pins again, and the hunt over once its rank is known.
function M:OnRanksKnown()
    self:Refresh()
    local hunt = self:Hunt()
    if hunt and not M.Lacking(hunt.spellID) then self:StopHunt("learned") end
end

---HUNTSWORN_PET_TAMED: with its switch on, the hunt is over once the tamed beast teaches its rank.
---@param _ string the message
---@param event AddonPetTamedEvent
function M:OnPetTamed(_, event)
    local hunt = self:Hunt()
    ---@type number[]?
    local teaches = event.npc and M.TeachesOf(event.npc) or nil
    if not hunt or not teaches or not self:Settings().huntEndsAtTame then return end
    for _, spellID in ipairs(teaches) do
        if spellID == hunt.spellID then
            self:StopHunt("tamed", event.pet)
            return
        end
    end
end

M.command = "hunt"
M.commands = {
    stop = {
        desc = L.BEASTMAP_CMD_STOP,
        ---@param self AddonBeastMap
        func = function(self)
            self:StopHunt()
        end,
    },
}
