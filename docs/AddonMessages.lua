---@meta
-- Types for the messages Huntsworn sends (docs\04-hooking.md), for the Lua language server of an addon
-- that listens: add Huntsworn's docs folder to its library (in .luarc.json, "workspace.library":
-- ["<AddOns>/Huntsworn/docs"]) and annotate a handler's table, e.g. `---@param event AddonToastEvent`.
-- Never loaded in game: not in the .toc. Huntsworn's own code uses the same types.
--
-- Each message hands over one table. Fields may be added; the ones here keep their name and meaning.

---HUNTSWORN_TOAST: a toast is about to show, or to wait for the one that is up.
---@class AddonToastEvent
---@field module string? the part of the toast's key before the colon
---@field toast AddonToastInfo Addon's own table: change it and the toast shows the change

---HUNTSWORN_PRINT: Huntsworn printed a line in chat.
---@class AddonPrintEvent
---@field module string? the module that said it; nil for Addon's core
---@field line string the line as printed, without Addon's chat prefix

---HUNTSWORN_RANKS_KNOWN: Ability Learned learned of pet ability ranks the hunter knows that it did
---not know before; once per learn, once per opening of the Beast Training window.
---@class AddonRanksKnownEvent
---@field module string "AbilityLearned"
---@field source "learn"|"training" a learn it saw, or the Beast Training window
---@field ranks AddonKnownRank[] the ranks that were news

---HUNTSWORN_ABILITY_LEARNED: the hunter learned a pet ability from a tamed beast (Ability Learned saw
---it; Beast Training's window is HUNTSWORN_RANKS_KNOWN).
---@class AddonAbilityLearnedEvent
---@field module string "AbilityLearned"
---@field name string the ability's name in the client's language
---@field rank number 1 when the client named no rank
---@field pet string? the pet that taught it; nil when it was not out
---@field npc number? the NPC ID that pet was tamed as
---@field zone string? where it happened

---HUNTSWORN_PET_GROWTH (core, through Huntsworn:Listen): the pet out's training points total, level or
---loyalty level changed since it was last seen (kept per pet name, also across a relog).
---@class AddonPetGrowthEvent
---@field pet string
---@field level number
---@field loyalty number? nil when the client does not tell it
---@field loyaltyName string? the loyalty level's name, when the client gives one
---@field points number the training points total
---@field free number the points not spent
---@field before { level: number, loyalty: number?, points: number }

---HUNTSWORN_AUTOCAST_WANTED: what Autocast Check wants on autocast changed, or what decided it.
---@class AddonAutocastWantedEvent
---@field module string "AutocastCheck"
---@field wanted "growl"|"cower"
---@field why "solo"|"dungeon"|"chosen" alone or in a group outside, in a dungeon group, or a macro chose
---@field before "growl"|"cower"

---HUNTSWORN_RARE_SEEN: a rare beast that teaches a rank the hunter lacks came in sight; once per spawn.
---@class AddonRareSeenEvent
---@field module string "BeastMap"
---@field npc number
---@field name string in the client's language once it knows the beast, else English
---@field guid string the creature's GUID
---@field ranks number[] the spell IDs of the ranks it would teach

---HUNTSWORN_HUNT_STARTED: the hunter picked a beast to tame for a rank (Beast Map's hunt).
---@class AddonHuntStartedEvent
---@field module string "BeastMap"
---@field npc number
---@field spellID number the rank hunted for
---@field name string in the client's language once it knows the beast, else English

---HUNTSWORN_HUNT_ENDED: that hunt is over.
---@class AddonHuntEndedEvent: AddonHuntStartedEvent
---@field reason "learned"|"tamed"|"stopped" the hunter knows the rank now, tamed a beast that teaches it, or stopped the hunt

---HUNTSWORN_AMMO: the hunter's ammo count crossed a line: low, critically low, or back to enough.
---@class AddonAmmoEvent
---@field module string "Ammo"
---@field count number
---@field state "ok"|"low"|"critical"
---@field kind number what the hunter's ranged weapon shoots: Addon.ammoKinds.arrow (2) or .bullet (3)

---HUNTSWORN_PET_AT_PULL: combat started while something is wrong with the pet.
---@class AddonPetAtPullEvent
---@field module string "CareButton"
---@field state "missing"|"dead"|"passive" none out, dead (its body gone), or on Passive

---HUNTSWORN_PET_HAPPINESS (core, through Huntsworn:Listen): the pet out's happiness changed.
---@class AddonPetHappinessEvent
---@field happiness number Addon.happiness.unhappy (1), .content (2) or .happy (3)
---@field before number? nil for a pet just out

---HUNTSWORN_PET_STATE (core, through Huntsworn:Listen): the pet out became alive, dead or none.
---@class AddonPetStateEvent
---@field state "alive"|"dead"|"none" dead: its body is still out; none: no pet out (dismissed, or a dead one's body gone)
---@field before "alive"|"dead"|"none"

---HUNTSWORN_PET_DIED (core, through Huntsworn:Listen): the pet out died.
---@class AddonPetDiedEvent
---@field pet string?

---HUNTSWORN_PET_TAMED (core, through Huntsworn:Listen): the pet that came out after a Tame Beast cast.
---@class AddonPetTamedEvent
---@field pet string?
---@field npc number? the NPC ID it was tamed as
---@field petNumber number? the number the pet keeps through renames and the stable; nil until the next relog, while its GUID is still the beast's

---@class AddonKnownRank
---@field name string the ability's name in the client's language
---@field rank number

---A toast, as Huntsworn:ShowToast takes it and HUNTSWORN_TOAST hands it over.
---@class AddonToastInfo
---@field key string one toast per key; "<module>:<what>", so the module can drop its own
---@field type string? "<module>:<kind>", one of the module's toastTypes: picks the skin
---@field source string? who it comes from, such as the module's title (the splash shows it)
---@field title string
---@field text string?
---@field hint string? shown in grey below the text
---@field icon (number|string)? FileDataID or texture path; a question mark without
---@field accent number[]? { r, g, b } for the side bar, the title and the timer; amber without
---@field sound AddonSound?
---@field portrait string? a unit ("pet") whose portrait shows as a badge on the icon while it exists
---@field screenshot boolean? take a screenshot once the toast has faded in

---A toast sound: a sound file, or a sound kit.
---@class AddonSound
---@field file number? FileDataID for PlaySoundFile
---@field kit number? SoundKit ID for PlaySound
