---@meta
-- Editor-only types for Huntsworn's own tables: the addon object and the module contract. Not
-- listed in the .toc, so the game never loads this file. The Ace3 types (AceModule,
-- AceDBObject-3.0, AceConfig.OptionsTable, ...) come with WoW Lua LS.

---One slash command of a module: `/huntsworn <module.command> <name> <args>`.
---@class AddonCommand
---@field desc string one line for /huntsworn help
---@field func fun(module: AddonModule, args: string) gets the rest of the line, "" when there is none

---What a module may declare, besides AceAddon's OnInitialize/OnEnable/OnDisable. OnDisable must
---undo everything OnEnable did: it also runs on every profile change (see Core\Addon.lua).
---@class AddonModule: AceModule, AceEvent-3.0
---@field title string? shown on its switch and its options page; the module name otherwise
---@field description string? the tooltip of its switch
---@field enabledByDefault boolean? false keeps it off until switched on; on otherwise
---@field requires string[]? the parts of the game it needs (Addon.features' keys); off without one
---@field defaults AceDB.Schema? AceDB defaults; the module then has db, its own namespace
---@field db AceDBObject-3.0? set by the core before the module's OnInitialize, when it has defaults
---@field command string? the word after /huntsworn that reaches its commands
---@field commands table<string, AddonCommand>? by the word after `command`, lowercase
---@field toastTypes table<string, string>? the kinds of toast it shows, by kind with a localized name; each can have a look of its own
---@field toastSkins table<string, string>? the look a kind starts on (a skin id), until the player picks another
---@field GetOptions (fun(self: AddonModule): table)? an AceConfig group (args, and name if not title); the core adds type and disabled
---@field Print fun(self: AddonModule, ...: any) a line in chat, sent on as HUNTSWORN_PRINT with the module's name

---A module whose settings Huntsworn:Setting reads and writes.
---@class AddonSettingsModule: AddonModule
---@field Settings fun(self: AddonSettingsModule): table

---A module that offers macros (Huntsworn:OfferMacros, Huntsworn:CreateMacros).
---@class AddonMacroModule: AddonModule
---@field Macros fun(self: AddonMacroModule): AddonMacro[]

---A macro a module makes for the player.
---@class AddonMacro
---@field name string at most 16 characters
---@field icon number|string FileDataID or texture path
---@field body string the macro text
---@field desc string? what it does, shown in the tooltip of an action button that holds it

-- AddonToastInfo, AddonSound and the message tables (AddonToastEvent and the rest) are public:
-- they are in docs\AddonMessages.lua, which ships with the addon.

---A skin frame with a portrait badge (Huntsworn:AddToastPortrait).
---A toast skin's frame (Huntsworn:NewToastFrame).
---@class AddonToastFrame: Frame
---@field dragging boolean? the mouse drags it: nothing places it meanwhile
---@field placed boolean? the card has slid in and is left where it is

---@class AddonPortraitFrame: AddonToastFrame
---@field Portrait Texture
---@field PortraitRing Texture

---The toast's saved settings, profile.toast.
---@class AddonToastSettings
---@field duration number seconds it stays before it fades
---@field scale number
---@field pos [string, string, number, number]? point, relativePoint, x, y, once dragged
---@field skin string the skin id for every toast
---@field skins table<string, string> a skin id per kind of toast ("<module>:<kind>"), where chosen
---@field sink table LibSink's output choice, kept by LibSink itself

---What draws a toast (Core\Toast\). Huntsworn brings "card" and "splash"; another addon adds its
---own with Huntsworn:RegisterToastSkin(id, skin), to draw in its own style or to hand the toast to
---something else. The engine keeps the queue and the clock and calls, for one toast: Show once,
---Update every frame until the fade is done, then Hide. Huntsworn:NewToastFrame gives a frame that
---drags and closes like the others, Huntsworn:PlaceToast puts it where the player dragged it.
---@class AddonToastSkin
---@field name string shown in the look choice; localized
---@field Show fun(self: AddonToastSkin, info: AddonToastInfo, settings: AddonToastSettings) fill it in and show it; Update follows at once
---@field Update (fun(self: AddonToastSkin, intro: number, fade: number, left: number))? each 0 to 1: how far the intro is, how far the fade is (1 = gone), how much of its stay is left; required unless instant
---@field Hide (fun(self: AddonToastSkin))? required unless instant
---@field IsMouseOver (fun(self: AddonToastSkin): boolean)? while true, its stay does not count down; required unless instant
---@field Frame (fun(self: AddonToastSkin): Frame?)? its frame, when it has one
---@field instant boolean? it hands the toast on in Show and is done: the next toast follows at once
---@field GetOptions (fun(self: AddonToastSkin): table)? an AceConfig group of its own on Addon's page

---A skin from Huntsworn:NewToastSkin: it draws in self.frame, and Hide, IsMouseOver and Frame are
---done; it adds Show and Update.
---@class AddonFrameSkin: AddonToastSkin
---@field frame Frame? made by its Show, with Addon:NewToastFrame

---The card skin's frame, with its parts as fields like a template's parentKeys.
---@class AddonCardFrame: AddonPortraitFrame
---@field Accent Texture the coloured side bar
---@field Icon Texture
---@field Title FontString
---@field Text FontString
---@field Hint FontString
---@field Timer Texture the bar along the bottom that runs down

---How a card or splash skin looks (Huntsworn:NewCardSkin, Huntsworn:NewSplashSkin).
---@class AddonSkinStyle
---@field frameName string the frame's global name
---@field accent fun(): number[] { r, g, b } for a toast that brings no accent
---@field panel number[]? { r, g, b, a } of the panel; the splash fades its own black one without
---@field edge number[]? { r, g, b, a } of a 1-pixel edge (card only)
---@field Border fun(frame: Frame)? draws an edge itself
---@field Font fun(text: FontString, size: number)? sets a font; the game's fonts without

---@class AddonCardSkin: AddonFrameSkin
---@field style AddonSkinStyle
---@field frame AddonCardFrame? made on its first toast

---The splash skin's frame.
---@class AddonSplashFrame: AddonPortraitFrame
---@field Source FontString the module's name at the top
---@field Divider Texture the line under it
---@field Diamond Texture the accent square turned 45 degrees
---@field Inner Texture the dark square inside it
---@field Icon Texture
---@field Title FontString
---@field Text FontString
---@field Hint FontString
---@field Timer Texture

---@class AddonSplashSkin: AddonFrameSkin
---@field style AddonSkinStyle
---@field frame AddonSplashFrame?

---AutocastCheck's saved settings, its namespace's profile.
---@class AddonAutocastSettings
---@field growl boolean watch Growl
---@field cower boolean watch Cower
---@field learnCower boolean Cower on beside Growl while the pet has a rank the hunter can learn from it
---@field remind boolean toast what is still wrong when combat starts
---@field remindEvery number minutes between two reminders of one problem; 0: every pull
---@field sound "family"|"warning"|"off"

---@class AddonAutocastCheck: AddonMacroModule, AddonSettingsModule
---@field db AceDBObject-3.0 always set: the module has defaults
---@field active table<string, true> the problems the last check found, by problem key
---@field toasted table<string, number> when each problem last toasted (GetTime), by problem key
---@field ReminderDue fun(self: AddonAutocastCheck, key: string): boolean
---@field checkPending boolean? a check is on its way (CheckAfter)
---@field choice ("growl"|"cower")? what the player chose (HuntswornKite, HuntswornGrowl)
---@field choiceInDungeon boolean? whether the player was in a dungeon group then
---@field lastWanted ("growl"|"cower")? what fitted at the last check (HUNTSWORN_AUTOCAST_WANTED)
---@field lastWhy ("solo"|"dungeon"|"chosen")? what decided it then
---@field TellWanted fun(self: AddonAutocastCheck)
---@field SPELLS table<"growl"|"cower", number>
---@field Spell fun(id: number): string, (number|string)?
---@field Settings fun(self: AddonAutocastCheck): AddonAutocastSettings used by Options.lua too
---@field Check fun(self: AddonAutocastCheck, remindAll: boolean?) used by Options.lua too
---@field TestToast fun(self: AddonAutocastCheck) used by Options.lua too
---@field Wanted fun(self: AddonAutocastCheck): "growl"|"cower", "solo"|"dungeon"|"chosen"
---@field Choose fun(self: AddonAutocastCheck, ability: "growl"|"cower")
---@field AutocastLines fun(on: "growl"|"cower", both: boolean?): string
---@field ApplyButton fun(self: AddonAutocastCheck)
---@field LearningCower fun(self: AddonAutocastCheck): boolean
---@field WantedLines fun(self: AddonAutocastCheck): string

---An ability that can autocast, as AutocastCheck reads it from the pet.
---@class AddonAutocastState
---@field on boolean
---@field icon (number|string)? from the pet bar; nil for one only in the spellbook

---Feeding's saved settings, its namespace's profile.
---@class AddonFeedingSettings
---@field content boolean toast when the pet becomes content
---@field unhappy boolean toast when the pet becomes unhappy
---@field noFood boolean toast when the last food the pet eats leaves the bags
---@field position [string, string, number, number]? the button's point, UIParent's point, x, y; nil beside the pet frame

---A food in the bags the pet eats, as Feeding orders it.
---@class AddonFood
---@field bag number
---@field slot number
---@field itemID number
---@field count number
---@field level number its item level
---@field bite number happiness a bite gives the pet out: 35, 17 or 8
---@field wellFed boolean it also makes the hunter Well Fed: fed last

---What a button skin is handed besides the button.
---@class AddonButtonParts
---@field icon Texture the button's icon
---@field group string the module the button belongs to, such as "Feeding" (Masque's group)

---The look of one of Huntsworn's buttons (Core\Buttons.lua, docs\09-button-skins.md).
---@class AddonButtonSkin
---@field name string shown in the choice on Addon's page
---@field priority number? "auto" takes the highest; Addon's own is 0
---@field Style fun(button: Button, parts: AddonButtonParts): (fun(r: number, g: number, b: number))? styles it once; gives how to colour its border, or nil when it has none to colour

---The look of what holds Huntsworn's buttons, and of the text and icons in its rows.
---@class AddonButtonHolderSkin
---@field name string
---@field priority number?
---@field Style fun(frame: Frame) styles the panel once (a frame made with BackdropTemplate)
---@field Font fun(text: FontString, size: number) a row's text
---@field CropIcon (fun(icon: Texture))? a row's icon, as the UI trims its own
---@field CropsIcons (fun(): boolean)? whether the UI's own setting crops icons; Addon's switch follows it, greyed
---@field Accent (fun(): number[])? the colour that marks what is chosen (the tab that shows); the game's gold without one
---@field Close (fun(button: Button))? a close button (UIPanelCloseButton), in the UI's own look

---The button skin choices in the profile.
---@class AddonButtonSettings
---@field skin string a button skin id, or "auto"
---@field holder string a holder skin id, or "auto"
---@field crop boolean icons lose their border, unless the look's UI decides (CropsIcons)

---The Data Broker module: Huntsworn's LibDataBroker-1.1 data source.
---@class AddonBroker: AddonModule
---@field db AceDBObject-3.0 always set: the module has defaults
---@field object table? the data object ("Addon"), made for a hunter on the first enable
---@field Update fun(self: AddonBroker)
---@field ApplyMinimapButton fun(self: AddonBroker)
---@field GetOptions fun(self: AddonBroker): table

---Where and when a pet came to the journal.
---@class AddonJournalFirst
---@field t number server time
---@field zone string?
---@field tamed boolean? seen tamed (a Tame Beast cast before it came out)
---@field npc number? the NPC ID it was tamed as

---One pet's journal (PetJournal), per character.
---@class AddonJournalEntry
---@field first AddonJournalFirst
---@field name string?
---@field family string? its family, in the client's language
---@field level number?
---@field loyalty number?
---@field loyaltyName string?
---@field out number seconds out, before the current stretch
---@field deaths number
---@field rises table<number, number> per loyalty level reached while seen, the seconds out then
---@field abilities string[] "Claw (Rank 2)", sorted, as of the last time out
---@field ranks table<string, string>? each ability's rank text by name ("" without ranks)
---@field displayID number? its model, as the stable's lists gave it
---@field past true? no longer the hunter's: in neither stable list at the last read, and not out
---@field advice string? its training advice, an AbilityLearned adviceRoles value; nil for upgrades

---PetJournal's saved settings, its namespace's profile.
---@class AddonPetJournalSettings
---@field tooltip boolean the journal in the pet's tooltip

---@class AddonPetJournal: AddonModule, AddonSettingsModule
---@field db AceDBObject-3.0 always set: the module has defaults
---@field current string? the pet out's key
---@field outSince number? GetTime() when it came out
---@field picked string? the pet chosen on the page
---@field Pets fun(self: AddonPetJournal): table<string, AddonJournalEntry>
---@field Entry fun(self: AddonPetJournal, key: string, npc: number?): AddonJournalEntry
---@field ReadStableList fun(self: AddonPetJournal, list: fun(): table[])
---@field LevelLine fun(entry: AddonJournalEntry): string
---@field AbilitiesLine fun(entry: AddonJournalEntry, highlight: boolean?): string?
---@field TeachCount fun(entry: AddonJournalEntry): number
---@field PetOrder fun(): string[] the journal's pets, the pet out first, then by name
---@field ShowModel fun(model: PlayerModel, key: string, entry: AddonJournalEntry)
---@field ADVICE_NAMES table<string, string> each kind of training advice's name, by its adviceRoles value
---@field OnDied fun(self: AddonPetJournal)
---@field OnTamed fun(self: AddonPetJournal, message: string, event: AddonPetTamedEvent)
---@field OnGrowth fun(self: AddonPetJournal)
---@field ReadStable fun(self: AddonPetJournal)
---@field Out fun(self: AddonPetJournal, key: string): number
---@field Record fun(self: AddonPetJournal)
---@field Snapshot fun(self: AddonPetJournal)
---@field Close fun(self: AddonPetJournal)
---@field Open fun(self: AddonPetJournal, key: string)
---@field Settings fun(self: AddonPetJournal): AddonPetJournalSettings
---@field JournalLines fun(self: AddonPetJournal, key: string, brief: boolean?, noAdvice: boolean?): string[]
---@field AdviceLines fun(key: string, entry: AddonJournalEntry): string?, string? the pet out's training advice and what to save for
---@field JournalText fun(self: AddonPetJournal, key: string): string
---@field Chosen fun(self: AddonPetJournal): string?
---@field GetOptions fun(self: AddonPetJournal): table

---A row of Feeding's food list: a secure button that feeds one food.
---@class AddonFoodRow: Button
---@field icon Texture
---@field label FontString

---@class AddonFeeding: AddonSettingsModule
---@field db AceDBObject-3.0 always set: the module has defaults
---@field happiness number? the pet's happiness at the last check; nil for a new pet
---@field canFeed boolean? whether the hunter knew Feed Pet at the last look
---@field eating boolean? whether the pet was eating at the last UNIT_AURA
---@field SPELLS_CHANGED fun(self: AddonFeeding)
---@field UNIT_AURA fun(self: AddonFeeding, event: string, unit: string)
---@field Eating fun(): boolean
---@field OnPetState fun(self: AddonFeeding)
---@field button Button the feed button (HuntswornFeedButton)
---@field FEED_PET number
---@field FeedMacro fun(food: AddonFood): string
---@field FoodColor fun(food: AddonFood): number, number, number
---@field ToggleFoodList fun(self: AddonFeeding)
---@field CloseFoodList fun(self: AddonFeeding)
---@field Settings fun(self: AddonFeeding): AddonFeedingSettings
---@field FeedPetName fun(): string
---@field FoodName fun(food: AddonFood): string
---@field Happiness fun(): number?
---@field Scan fun(self: AddonFeeding): AddonFood[]
---@field Foods fun(self: AddonFeeding): AddonFood[]
---@field Toast fun(self: AddonFeeding, kind: "content"|"unhappy"|"nofood"): AddonToastInfo
---@field CheckHappiness fun(self: AddonFeeding)
---@field Update fun(self: AddonFeeding)
---@field PlaceButton fun(self: AddonFeeding)
---@field ApplyButton fun(self: AddonFeeding)
---@field GetOptions fun(self: AddonFeeding): table

---CareButton's saved settings, its namespace's profile.
---@class AddonCareButtonSettings
---@field died boolean toast when the pet dies
---@field nopet boolean toast when combat starts without a pet
---@field passive boolean toast when combat starts with the pet on Passive
---@field low number the health percentage for the low toast; 0 is never
---@field marker boolean the low health marker beside the pet frame
---@field visible boolean the button shown on screen
---@field position [string, string, number, number]? its point, UIParent's point, x, y; nil below the pet frame
---@field sound "family"|"warning"|"off"

---@class AddonCareButton: AddonMacroModule, AddonSettingsModule
---@field db AceDBObject-3.0 always set: the module has defaults
---@field ApplyMacroTexts fun(self: AddonCareButton) the button's macro texts again, for the spells known now
---@field IsCareLine fun(self: AddonCareButton, line: string): boolean a /use line of the care spells alone
---@field TrainingOnAlt fun(self: AddonCareButton): string?, number? Beast Training's name and the free points while Alt opens it
---@field OnPetPoints fun(self: AddonCareButton, event: string, unit: string) the macro texts again for the pet's points
---@field lowShown boolean the low toast was given and health has not been above the line since
---@field deadAfterCombat boolean a failed cast in combat showed the pet is dead
---@field reviveCasts table<string, true> Revive Pet casts that started, by cast GUID
---@field MEND_PET number
---@field REVIVE_PET number
---@field CALL_PET number
---@field PET_STATES string
---@field Settings fun(self: AddonCareButton): AddonCareButtonSettings
---@field SpellName fun(id: number): string
---@field Toast fun(self: AddonCareButton, kind: "dead"|"nopet"|"low"|"passive", reason: string?, percent: number?): AddonToastInfo
---@field CheckHealth fun(self: AddonCareButton)
---@field UpdateMarker fun(self: AddonCareButton)
---@field button Button the secure button (AddonCareButton)
---@field NextCast fun(self: AddonCareButton): number
---@field UpdateLook fun(self: AddonCareButton)
---@field PlaceButton fun(self: AddonCareButton)
---@field ShowOnScreen fun(self: AddonCareButton)
---@field OnPetState fun(self: AddonCareButton, state: string)
---@field MacroText fun(self: AddonCareButton, petDead: boolean): string
---@field PetDead fun(self: AddonCareButton): boolean
---@field SetPetDead fun(self: AddonCareButton, dead: boolean): boolean
---@field ApplyButton fun(self: AddonCareButton)
---@field UpdateMacro fun(self: AddonCareButton)

---A spell in the active pet's spellbook (Huntsworn.PetSpells).
---@class AddonPetSpell
---@field id number
---@field rank string? "Rank 2"; nil for a spell without ranks
---@field icon (number|string)?

---AbilityLearned's saved settings, its namespace's profile.
---@class AddonAbilityLearnedSettings
---@field sound "family"|"levelup"|"off"
---@field screenshot boolean
---@field hints boolean say in chat what a summoned pet can teach
---@field points boolean toast when the pet gains training points
---@field pointsSound "family"|"levelup"|"off" that toast's sound
---@field loyalty boolean toast when the pet's loyalty level drops
---@field loyaltySound "family"|"levelup"|"off" that toast's sound

---AbilityLearned's per-character data, its namespace's char.
---@class AddonAbilityLearnedChar
---@field history AddonLearnEntry[] oldest first, the last 200
---@field known table<string, number> the highest rank known per ability name
---@field ranks table<string, table<number, true>> every rank known per ability name
---@field trainingRead boolean Beast Training has been read once

---How a pet stood when the core last saw it (HuntswornDB char.growth, by pet name).
---@class AddonGrowthSeen
---@field total number its training points total
---@field level number
---@field loyalty number? its loyalty level; nil on a client without GetPetLoyalty

---A learn as AbilityLearned shows it.
---@class AddonLearn
---@field name string
---@field rank string?
---@field icon (number|string)?
---@field teacher string? the name of the pet out, when it has the ability
---@field simulated boolean? from the page's simulation: shown, not kept

---A learn as the history keeps it.
---@class AddonLearnEntry
---@field name string
---@field rank string?
---@field pet string?
---@field npc number? the NPC ID the pet was tamed as (Addon.PetNPC)
---@field familyID number?
---@field zone string?
---@field t number GetServerTime()

---A rank's price in Beast Training.
---@class AddonTrainingCost
---@field cost number training points
---@field level number the pet level it needs

---AbilityLearned's global data: the same for every character.
---@class AddonAbilityLearnedGlobal
---@field costs table<string, table<number, AddonTrainingCost>> per ability name and rank
---@field taught table<number, table<string, true>> per pet family, the abilities Beast Training shows it

---What to train with the pet out's free points (AbilityLearned:Advice): the same table each time.
---@class AddonAdvice
---@field buy string[] the ranks to buy, in order: "Bite rank 2 (10)"
---@field free number the free points
---@field left number what is left once they are bought
---@field saving string? the next rank in line the points do not reach yet
---@field short number? the points short of it

---@class AddonAbilityLearned: AddonSettingsModule
---@field db AceDBObject-3.0 always set: the module has defaults
---@field ready boolean the login wait is over
---@field atTrainer boolean a trainer window was opened and not closed
---@field Settings fun(self: AddonAbilityLearned): AddonAbilityLearnedSettings
---@field Toast fun(self: AddonAbilityLearned, learn: AddonLearn): AddonToastInfo
---@field ShowLearn fun(self: AddonAbilityLearned, learn: AddonLearn)
---@field TrainerOpen fun(self: AddonAbilityLearned): boolean
---@field IsWildAbility fun(name: string): boolean
---@field OnChat fun(self: AddonAbilityLearned, line: GameValue): boolean
---@field SpellLearned fun(self: AddonAbilityLearned, spellID: number)
---@field Example fun(): string, string, number|string|nil, AddonPetSpell?
---@field Simulate fun(self: AddonAbilityLearned)
---@field MarkKnown fun(self: AddonAbilityLearned, name: string, rank: number): boolean
---@field ReadBeastCraft fun(self: AddonAbilityLearned) Beast Training's craft window (Classic Era, Burning Crusade)
---@field Advice fun(self: AddonAbilityLearned, role: string?): AddonAdvice what to train with the pet out's free points
---@field adviceRoles {upgrades: string, tank: string, dps: string} the kinds of advice
---@field HighestRank fun(self: AddonAbilityLearned, name: string): number?
---@field CanTeach fun(self: AddonAbilityLearned, name: string, rank: string?): boolean
---@field SurelyTeaches fun(self: AddonAbilityLearned, name: string, rank: string?): boolean
---@field HasRank fun(self: AddonAbilityLearned, name: string, rank: number): boolean
---@field TrainingCost fun(self: AddonAbilityLearned, name: string, rank: number): AddonTrainingCost?
---@field RecordLearn fun(self: AddonAbilityLearned, entry: AddonLearnEntry)
---@field HistoryText fun(self: AddonAbilityLearned): string
---@field ReportMissingTeachers fun(self: AddonAbilityLearned)
---@field ReadBeastTraining fun(self: AddonAbilityLearned)
---@field CheckHints fun(self: AddonAbilityLearned)
---@field OnGrowth fun(self: AddonAbilityLearned, message: string, event: AddonPetGrowthEvent)
---@field Sound fun(self: AddonAbilityLearned, key: "sound"|"pointsSound"|"loyaltySound", petSound: "AGGRO"|"WOUND"|nil): AddonSound?
---@field ReportTeachable fun(self: AddonAbilityLearned)

---FeedEmotes' saved settings, its namespace's profile.
---@class AddonFeedEmotesSettings
---@field petName boolean always the pet's name, never he/she
---@field customChance number 0: every fitting line counts the same; else the share of emotes that wants an own line
---@field customFallback boolean a built-in line when an own one is wanted but none fits

---FeedEmotes' per-character data, its namespace's char.
---@class AddonFeedEmotesChar
---@field sharedLines boolean use the account-wide own lines (global.customLines)
---@field customLines string[] this character's own lines
---@field petSex table<number, number> pet number -> 2 male or 3 female

---What a pronoun placeholder becomes: by the pet's sex, and with the sex unknown a format with %s
---for the name or a function of it (the pet's name when there is neither).
---@class AddonPronoun
---@field male string
---@field female string
---@field unknown (string|fun(name: string): string)?

---The built-in lines of one language (FeedEmotes\Lines\<locale>.lua).
---@class AddonEmoteLines
---@field feed string|fun(pet: string, food: string): string the sentence in front: a format of the pet and the food, or a function
---@field feedNoFood string the same without a known food
---@field article (fun(name: string): string)? the article for {a}
---@field pronouns table<string, AddonPronoun>?
---@field emotes AddonEmoteLists

---@class AddonEmoteLists
---@field any string[]
---@field male string[]?
---@field female string[]?
---@field openings string[]? sentences in front, in place of feed now and then
---@field whole string[]? emotes on their own, no sentence in front
---@field wholeFamily table<number, string[]>? the same per family ID
---@field food table<string, string[]> per food group (FoodGroups)
---@field foodType table<string, string[]>? per food type (FoodTypes)
---@field family table<number, string[]> per family ID

---The conditions of an own line, by tag. An alias, so a function type can return it next to
---another value (a comma inside table<...> would end the first return).
---@alias AddonTagSet table<string, true>

---A condition an own line can start with.
---@class AddonFeedCondition
---@field tag string what is typed between the brackets
---@field group "sex"|"foodType"|"family"
---@field value number|string what the feeding must hold for that group

---What the lines are picked by for one feeding.
---@class AddonFeedSituation
---@field sex number?
---@field foodType string?
---@field family number?

---@class AddonFeedEmotes: AddonSettingsModule
---@field db AceDBObject-3.0 always set: the module has defaults
---@field watching boolean? on a hunter, where there is a pet to feed
---@field FEED_PET number
---@field CUSTOM_LINE_MAX number
---@field Lines table<string, AddonEmoteLines>
---@field FoodGroups table<number, string>
---@field FoodTypes table<number, string>
---@field Family table<string, number>
---@field ExoticFamily table<number, true>
---@field Conditions AddonFeedCondition[]
---@field ConditionByTag table<string, AddonFeedCondition>
---@field Tracker AddonFoodTracker
---@field Settings fun(self: AddonFeedEmotes): AddonFeedEmotesSettings
---@field Char fun(self: AddonFeedEmotes): AddonFeedEmotesChar
---@field LinesInUse fun(self: AddonFeedEmotes): AddonEmoteLines
---@field CustomLines fun(self: AddonFeedEmotes): string[]
---@field PetSex fun(self: AddonFeedEmotes): number?
---@field ChoosePetSex fun(self: AddonFeedEmotes, sex: number?): boolean
---@field PrunePetSex fun(self: AddonFeedEmotes)
---@field Feed fun(self: AddonFeedEmotes, itemID: number?)
---@field ParseCustomLine fun(line: string): AddonTagSet?, string
---@field FormatCustomLine fun(tags: table<string, true>, text: string): string
---@field ConditionsHold fun(tags: table<string, true>, situation: AddonFeedSituation): boolean
---@field AddCustomLine fun(self: AddonFeedEmotes, text: string?, extraTags: table<string, true>?): boolean, string
---@field ReplaceCustomLine fun(self: AddonFeedEmotes, index: number, text: string?): boolean, string
---@field RemoveCustomLine fun(self: AddonFeedEmotes, index: number): string?
---@field PlaceholderList fun(self: AddonFeedEmotes): string
---@field LinePools fun(self: AddonFeedEmotes, itemID: number?, foodName: string?): string[], string[]
---@field EmotePool fun(self: AddonFeedEmotes, itemID: number?, foodName: string?): string[]
---@field PickLine fun(self: AddonFeedEmotes, itemID: number?, foodName: string?): string?
---@field FillPlaceholders fun(self: AddonFeedEmotes, line: string, pet: string, food: string?, article: string?): string
---@field BuildEmote fun(self: AddonFeedEmotes, itemID: number?): string?

---The sound tables, Huntsworn.sounds.<KIND>_PER_FAMILY (Core\Sounds.lua).
---@class AddonSounds
---@field AGGRO_PER_FAMILY table<number, number>
---@field DEATH_PER_FAMILY table<number, number>
---@field WOUND_PER_FAMILY table<number, number>

---DevScreenshots: screenshots for development, only in a copy from the repository.
---@class AddonDevScreenshots: AddonModule
---@field db AceDBObject-3.0 global.shots: what has a screenshot, by kind
---@field HUNTSWORN_TOAST fun(self: AddonDevScreenshots, message: string, event: AddonToastEvent)
---@field HUNTSWORN_PRINT fun(self: AddonDevScreenshots, message: string, event: AddonPrintEvent)

---BeastMap: a HandyNotes plugin with a pin for every beast that can teach the hunter a rank.
---@class AddonBeastMap: AddonSettingsModule
---@field db AceDBObject-3.0
---@field AbilityName fun(ability: number): string the Abilities tab's: the client's name, else "?"
---@field AbilityIcon fun(ability: number): number|string the Abilities tab's: the icon, else the question mark
---@field AnyLearnable fun(ability: number): boolean whether a rank of it can be learned now
---@field OnAbilityEnter fun(row: {ability: number?}) the Abilities tab's tooltip for an ability row
---@field ShowAbility fun(self: AddonBeastMap, ability: number) opens the Abilities tab on that ability
---@field pickAbility number? the ability the Abilities tab shows at its next refresh
---@field level number? the level PLAYER_LEVEL_UP gave, until UnitLevel catches up
---@field canTame boolean? whether the hunter knows Tame Beast, as SPELLS_CHANGED last found
---@field SPELLS_CHANGED fun(self: AddonBeastMap)
---@field Settings fun(self: AddonBeastMap): AddonBeastMapSettings
---@field PlayerLevel fun(self: AddonBeastMap): number
---@field Refresh fun(self: AddonBeastMap)
---@field TeachesOf fun(npc: number): number[]?
---@field RankText fun(spellID: number): string?
---@field Lacking fun(spellID: number): "above"|"gap"|nil
---@field LevelText fun(beast: AddonBeast): string
---@field BeastName fun(npc: number): string
---@field SeeCreature fun(self: AddonBeastMap, guid: GameValue)
---@field tameTarget string? the beast the tame key goes for
---@field SetTameTarget fun(self: AddonBeastMap, name: string)
---@field OnRareSeen fun(self: AddonBeastMap, message: string, event: AddonRareSeenEvent)
---@field Place fun(npc: number): string the beast and its zone, "Rare Cat in Tirisfal Glades"
---@field Nearest fun(teachers: number[]): number[] the window's order, a new list
---@field TravelTimeTo fun(npc: number): number? seconds, when a route addon gives travel times
---@field GoToBeast fun(self: AddonBeastMap, npc: number, pinMap: number?, pinX: number?, pinY: number?): boolean
---@field PinSpell fun(npc: number): number? the rank a beast's pin shows
---@field AttackSpeed fun(npc: number): number? a tameable beast's attack speed where it is not 2.0 (Tooltip.lua)
---@field StandingText fun(spellID: number): string a rank's text in the colour of the hunter's standing (Beasts.lua)
---@field CreateBeastCard fun(panel: AddonBeastsPanel, skin: AddonButtonHolderSkin): AddonBeastCard
---@field FillBeastCard fun(card: AddonBeastCard, npc: number)
---@field Hunt fun(self: AddonBeastMap): AddonHunt? the hunt on (Hunt.lua)
---@field IsHunting fun(self: AddonBeastMap, npc: number?, spellID: number?): boolean
---@field StartHunt fun(self: AddonBeastMap, npc: number, spellID: number, map: number?, x: number?, y: number?)
---@field StopHunt fun(self: AddonBeastMap, reason: "learned"|"tamed"|"stopped"?, pet: string?)
---@field OnPetTamed fun(self: AddonBeastMap, message: string, event: AddonPetTamedEvent)
---@field OnRanksKnown fun(self: AddonBeastMap)
---@field ShowHunt fun(self: AddonBeastMap) the hunted beast's areas (Areas.lua)
---@field DrawWorldAreas fun(self: AddonBeastMap)
---@field DrawMinimapAreas fun(self: AddonBeastMap)
---@field worldAreas Texture[] the discs on the world map
---@field minimapAreas Texture[] the discs on the minimap
---@field ApplyTameButton fun(self: AddonBeastMap)
---@field WatchRares fun(self: AddonBeastMap)
---@field CreateMapButton fun(self: AddonBeastMap)
---@field UpdateMapButton fun(self: AddonBeastMap)
---@field ToastReach fun(self: AddonBeastMap, level: number)
---@field GetOptions fun(self: AddonBeastMap): table

---The beast the hunter hunts, to tame it for one rank (Beast Map's db.char.hunt).
---@class AddonHunt
---@field npc number
---@field spellID number the rank

---@class AddonBeastMapSettings
---@field tooltip boolean a beast's tooltip says what it teaches
---@field spellTooltip boolean a pet ability's tooltip says its pet level, families and teachers
---@field rareToast boolean a toast when a rare beast worth taming comes in sight
---@field trainers boolean pins for pet trainers
---@field stables boolean pins for stable masters
---@field tameButton boolean the tame key's button on screen during a hunt
---@field huntEndsAtTame boolean the hunt ends once a beast that teaches its rank is tamed
---@field tamePosition [string, string, number, number]? where the tame button was put: point, relative point, x, y
---@field pins boolean the pins shown at all (the map button switches this)
---@field mapButton boolean the button on the world map
---@field usefulOnly boolean only beasts that teach a rank the hunter lacks
---@field gaps boolean a missing rank below the highest counts as lacking
---@field aboveLevel boolean beasts above the hunter's level too
---@field untilTame boolean with usefulOnly: no beast pins before the hunter knows Tame Beast
---@field levelToast boolean a toast when a level-up brings a teaching beast in reach
---@field levelChat boolean that toast's ranks and beasts in chat too
---@field familyGroup "family"|"role" how the Families tab groups its list
---@field familyRares boolean a Rares item in each group of that list
---@field familySpecNames boolean the classic clients' groups by role named Ferocity, Tenacity, Cunning
---@field beasts AddonBeastsFilter the Beasts tab's filters

---The Beasts tab's filters (Modules\BeastMap\Beasts.lua); "all" for no filter.
---@class AddonBeastsFilter
---@field search string part of a beast's name, "" for any
---@field ability string|number "all", or an ability (its rank 1's spell ID)
---@field family string|number "all", or a CreatureFamily ID
---@field diet string "all", or a Huntsworn.diets value the beast's family eats
---@field zone string|number "all", "here" (the player's map), a uiMapID, or minus an instance's AreaTable ID
---@field you "all"|"has"|"lacks" every rank the beast teaches known already, or some not yet
---@field reach boolean only beasts at or below the hunter's level
---@field rares boolean only rare beasts

---A map's pins as npc, coord pairs, with the position of each coord's npc.
---@class AddonBeastMapPins
---@field [integer] number
---@field at table<number, integer>

---A spellbook entry, as C_SpellBook gives it (Huntsworn.C.SpellBook.GetSpellBookItemInfo).
---@class AddonBookItem
---@field name GameValue
---@field subName GameValue the rank text, "" without one
---@field spellID GameValue none for a command

---An item's or a link's tooltip data, as C_TooltipInfo gives it (Huntsworn.C.TooltipInfo).
---@class AddonTooltipData
---@field lines {leftText: GameValue}[]

---@class AddonCompatPetInfo
---@field GetPetHappiness fun(): GameValue
---@field GetPetTrainingPoints fun(): GameValue, GameValue total and used
---@field GetPetLoyalty fun(): GameValue
---@field GetPetFoodTypes fun(): string[]
---@field CanPetEatItem fun(itemID: number): boolean

---@class AddonCompatSpellBook
---@field HasPetSpells fun(): GameValue the entry count
---@field IsSpellKnown fun(spellID: number): boolean? nil on a client that cannot tell
---@field GetSpellBookItemInfo fun(index: number, bank: number): AddonBookItem?
---@field GetSpellBookItemAutoCast fun(index: number, bank: number): GameValue, GameValue allowed and enabled

---@class AddonCompatTooltipInfo
---@field GetItemByID fun(itemID: number): AddonTooltipData
---@field GetHyperlink fun(link: string): AddonTooltipData?

---A pet in the stable's lists, as C_StableInfo gives it; Classic Era gives no petNumber,
---creatureID or displayID, and its loyalty as loyaltyText ("Loyalty Level 6 (Best Friend)").
---@class AddonStablePet
---@field slotID number?
---@field petNumber GameValue
---@field name string?
---@field level number?
---@field familyName string?
---@field icon (number|string)?
---@field creatureID number?
---@field displayID number?
---@field loyaltyLevel number?
---@field loyaltyName string?
---@field loyaltyText string?

---@class AddonCompatStableInfo
---@field GetActivePetList fun(): AddonStablePet[]
---@field GetStabledPetList fun(): AddonStablePet[]

---Huntsworn.C (Core\Compat.lua): the modern API on every client, the classic way where it is missing.
---@class AddonCompat
---@field PetInfo AddonCompatPetInfo
---@field SpellBook AddonCompatSpellBook
---@field TooltipInfo AddonCompatTooltipInfo
---@field StableInfo AddonCompatStableInfo
---@field Has fun(namespace: "PetInfo", name: string): boolean

---Generated game data (Data\*.lua).
---@class AddonData
---@field petAbilityRanks table<number, AddonPetAbilityRank> by the rank's spell ID
---@field beasts table<number, AddonBeast> by NPC ID
---@field speeds table<number, number>? every tameable beast's attack speed where not 2.0, by NPC ID (Classic Era)
---@field trainers table<number, AddonTrainer>? pet trainers and stable masters by NPC ID (Data\Trainers.lua)
---@field ammo table<number, AddonAmmoItem> the arrows and bullets vendors sell, by item ID (Data\Ammo.lua)
---@field ammoVendors table<number, AddonAmmoVendor> the vendors that sell them, by NPC ID
---A kind of ammo: its Projectile item subclass, a Huntsworn.ammoKinds value (arrow 2, bullet 3).
---@alias AddonAmmoKind number

---Ammo a vendor sells.
---@class AddonAmmoItem
---@field name string English, from the data
---@field kind AddonAmmoKind
---@field level number the level it needs

---A vendor that sells ammo.
---@class AddonAmmoVendor
---@field name string English, from the data
---@field sells number[] the ammo it sells, item IDs
---@field side ("Alliance"|"Horde")? the one faction it serves; both without
---@field pins table<number, number[]> per uiMapID its spots, flattened x1, y1, x2, y2 in percent

---Ammo's saved settings, its namespace's profile.
---@class AddonAmmoSettings
---@field low number the count turns orange, with a toast, below this
---@field critical number red, with a toast, below this
---@field toasts boolean
---@field buy boolean buy at a vendor
---@field bagOnly boolean never buy more than the ammo bag's free slots hold
---@field stacks number stacks to keep without an ammo bag
---@field equippedOnly boolean count only the ammo slot's kind; off: every kind the weapon shoots

---@class AddonAmmo: AddonModule, AddonSettingsModule
---@field db AceDBObject-3.0 always set: the module has defaults
---@field object table? the data object ("Addon Ammo"), made for a hunter on the first enable
---@field state ("ok"|"low"|"critical")? where the count stood at the last update
---@field Settings fun(self: AddonAmmo): AddonAmmoSettings
---@field Kind fun(): AddonAmmoKind?
---@field AmmoName fun(itemID: number): string
---@field State fun(self: AddonAmmo, count: number): "ok"|"low"|"critical"
---@field NearestVendor fun(self: AddonAmmo): LibGoTherePoint?, number?
---@field Update fun(self: AddonAmmo)
---@field MERCHANT_SHOW fun(self: AddonAmmo)
---@field GetOptions fun(self: AddonAmmo): table

---A hunter pet trainer or a stable master.
---@class AddonTrainer
---@field name string in English, from the data
---@field kind "trainer"|"stable"
---@field side ("Alliance"|"Horde")? the one faction it serves; both without
---@field pins table<number, number[]> per uiMapID its spots, flattened x1, y1, x2, y2 in percent

---One rank of a pet ability learned from beasts in the wild.
---@class AddonPetAbilityRank
---@field ability number the spell ID of the ability's rank 1
---@field rank number
---@field level number the pet level it needs
---@field families number[] the pet families (CreatureFamily IDs) that can learn it
---@field teachers number[] NPC IDs of the tameable beasts that teach it

---A tameable beast that teaches a pet ability rank.
---@class AddonBeast
---@field name string English, as Wowhead names it
---@field family number CreatureFamily ID
---@field minLevel number
---@field maxLevel number
---@field elite true?
---@field rare true?
---@field display number? its display ID (model), shown without the creature in the client's cache
---@field speed number? its melee attack speed in seconds, on Classic Era and WoW: Forever (a tamed beast keeps it there)
---@field pins table<number, number[]>? per uiMapID, pin positions as x1, y1, x2, y2, ... (percent)
---@field radii table<number, number[]>? per uiMapID, each pin's area radius (percent)
---@field zones number[]? AreaTable IDs, for a beast Wowhead has no map of (in an instance)

---The Dev Probe (Modules\DevProbe, repository copies only).
---@class AddonDevProbe: AddonModule
---@field db AceDBObject-3.0
---@field ReadStable fun(self: AddonDevProbe)
---@field CompareSpells fun(self: AddonDevProbe)
---@field OnLearned fun(self: AddonDevProbe, message: string, event: AddonAbilityLearnedEvent)
---@field GetOptions fun(self: AddonDevProbe): table

---The Dev Probe's findings, its global namespace.
---@class AddonProbeData
---@field stable table<string, table> C_StableInfo's entry per pet number
---@field petSpells table[] { spell, rank, before, level, family, how, t }
---@field foods table<number, string[]> food types per family ID
---@field families table<number, string> the client's family names
---@field lowerRanks table[] { name, rank, highest, t }
---@field guids table[] { event, guid, name, t }
---@field client table at each login: build, project, season, tameable, api, unitPosition, mapPosition, ammo, rangedSpeed, bags
---@field combat table? the first fight's: petHealth, unitPosition, mapPosition
---@field pet table happiness, loyalty, trainingPoints, each { modern, old }
---@field petEvents table[] { event, after, points, loyalty, level } per pet event in the first minute after login
---@field trainer (table|string)[] the trainer's first rows, raw
---@field tames table[] { npc, family, knows, expected, match, t }
---@field beasts table<number, table> per NPC its first sighting: { name, map, x, y, onDataMap, dataMaps, t }

---A tab of Huntsworn's window (Core\Window.lua), added by Huntsworn:RegisterWindowTab.
---@class AddonWindowTab
---@field id string
---@field title string
---@field order number left to right
---@field module string? the module that adds it: the tab shows while that module is on
---@field Create fun(panel: Frame, skin: AddonButtonHolderSkin) builds the panel, once
---@field Refresh fun(panel: Frame) fills it, each time it shows and on Addon:RefreshWindow

---Huntsworn's window frame.
---@class AddonWindow: Frame
---@field skin AddonButtonHolderSkin
---@field title FontString
---@field current string? the tab showing
---@field tabs table<string, AddonWindowTabButton>
---@field panels table<string, Frame>
---@field divider Texture the line under the tabs
---@field close Button

---Huntsworn.petSpecs, a SelfKeyedEnum.
---Huntsworn.petCategories, a SelfKeyedEnum: a family's category before Wrath.
---@class AddonPetCategories
---@field offense string
---@field defense string
---@field general string

---A family's category and modifiers to the pet's health, armor and damage, in percent, on the
---classic clients (Huntsworn.familyMods).
---@class AddonFamilyMods
---@field category string a Addon.petCategories value
---@field health number
---@field armor number
---@field damage number

---@class AddonPetSpecs
---@field ferocity string
---@field cunning string
---@field tenacity string

---Huntsworn.diets, a SelfKeyedEnum.
---@class AddonDiets
---@field meat string
---@field fish string
---@field cheese string
---@field bread string
---@field fungus string
---@field fruit string
---@field rawFish string

---What Huntsworn knows of a pet family (Core\Constants\Families.lua).
---@class AddonFamilyInfo
---@field name string English, when the client gives no name
---@field spec string? a Addon.petSpecs value
---@field diet string[]? Addon.diets values
---@field client string? the only client it is on, as LibTameable names it ("tbc", "forever"); nil for every client

---Huntsworn's window's settings (profile.window): where it was dragged to.
---@class AddonWindowSettings
---@field pos { point: string, relativePoint: string, x: number, y: number }?

---@class AddonWindowTabButton: Button
---@field label FontString
---@field selected Texture the underline of the tab that shows

---The Pets tab's panel (Modules\PetJournal\Window.lua).
---@class AddonPetsPanel: Frame
---@field skin AddonButtonHolderSkin
---@field rows AddonPetRow[]
---@field model AddonPetModel
---@field name FontString
---@field level FontString
---@field spec FontString
---@field adviceLabel FontString
---@field advice AddonAdviceButton[] the kinds of training advice, Upgrades first
---@field adviceText FontString the advice for the pet out, indented under the choice
---@field journal FontString
---@field abilities FontString

---Beast Map's button on the world map, made by Krowi_WorldMapButtons.
---@class AddonMapButton: Button
---@field icon Texture
---@field Refresh fun() the library's call after every map change

---@class AddonAdviceButton: Button
---@field label FontString
---@field role string the kind of advice, an AbilityLearned adviceRoles value

---@class AddonPetRow: Button
---@field label FontString
---@field key string? the pet it shows

---The Abilities tab's panel (Modules\BeastMap\Abilities.lua).
---@class AddonAbilitiesPanel: Frame
---@field rows AddonAbilityRow[]
---@field ranks AddonRankRow[]
---@field title FontString
---@field titleIcon Texture the chosen ability's icon
---@field header AddonRankHeader
---@field chosen number? the ability shown, by its rank 1's spell ID
---@field shownAbility number? the ability the lines below were made for
---@field expanded table<number, true?> the ranks unfolded to their teachers
---@field offset number how many lines the list is scrolled down
---@field lineSpells number[] per line its rank
---@field lineBeasts (number|false)[] per line its teacher, false on a rank's own line

---A rank's button that sends the hunter to the beast.
---@class AddonGoButton: Button
---@field icon Texture
---@field active Texture lit while its rank is the one hunted

---The ranks' column heads.
---@class AddonRankHeader: Frame
---@field rank FontString
---@field level FontString
---@field text FontString

---@class AddonAbilityRow: Button
---@field icon Texture the ability's
---@field label FontString the ability
---@field count FontString how many of its ranks the hunter knows
---@field learnable Texture a quest giver's "!" while a rank can be learned now
---@field selected Texture the bar behind the chosen one
---@field ability number?

---@class AddonRankRow: Button
---@field rank FontString
---@field level FontString
---@field text FontString the nearest teacher, or known
---@field more FontString how many more teach it
---@field stripe Texture every other row's background
---@field toggle Texture plus or minus, on a rank that folds open to its teachers
---@field npc number? on a teacher's line, the beast
---@field go AddonGoButton
---@field spellID number?
---@field teachers number[]? the beasts that teach it, in the window's order; nil when known
---@field best number? the first of them

---The Stable tab's panel (Modules\PetJournal\Stable.lua).
---@class AddonStablePanel: Frame
---@field cards AddonStableCard[]

---@class AddonStableCard: Button
---@field key string? the pet it shows
---@field model PlayerModel
---@field name FontString
---@field level FontString
---@field spec FontString
---@field abilities FontString
---@field teach FontString

---The Families tab's panel (Modules\BeastMap\Families.lua).
---@class AddonFamiliesPanel: Frame
---@field rows AddonFamilyRow[]
---@field beasts AddonFamilyBeastRow[]
---@field model PlayerModel
---@field title FontString
---@field titleIcon Texture the chosen family's portrait
---@field spec FontString
---@field diet FontString
---@field abilityRows AddonFamilyAbilityRow[] the family's abilities, a row each
---@field none FontString
---@field chosen number? the family shown
---@field chosenRares (number|string)? the group whose rares are shown instead: a family ID or a role
---@field groupBy AddonTextButton[] Family, Role
---@field rares AddonCheckText the Rares switch
---@field offset number rows scrolled past
---@field list Frame holds the rows; takes the mouse wheel

---@class AddonFamilyRow: Button
---@field icon Texture the family's portrait
---@field label FontString
---@field note FontString the family's strongest modifier, grouped by role on the classic clients
---@field familyID number?
---@field heading true? a group's name, not clickable
---@field rares (number|string)? a group's Rares item: the family ID or the role

---@class AddonTextButton: Button
---@field label FontString
---@field value string

---@class AddonCheckText: Button
---@field label FontString
---@field check Texture shown while on

---A family's ability in the Families tab; a click shows its teachers in the Abilities tab.
---@class AddonFamilyAbilityRow: Button
---@field icon Texture
---@field label FontString
---@field count FontString known ranks of the family's
---@field learnable Texture the quest giver's "!" while a rank can be learned now
---@field ability number? the spell ID of its rank 1

---The Beasts tab's panel (Modules\BeastMap\Beasts.lua).
---@class AddonBeastsPanel: Frame
---@field search EditBox the name search
---@field hint FontString the search box's grey word while empty
---@field pickers {ability: AddonPicker, family: AddonPicker, diet: AddonPicker, zone: AddonPicker, you: AddonPicker}
---@field reach AddonCheckText the In reach switch
---@field rares AddonCheckText the Rares switch
---@field count FontString how many beasts match
---@field list Frame holds the rows; takes the mouse wheel
---@field bar AddonScrollBar
---@field rows AddonBeastRow[]
---@field browse Frame holds the filters, count and list; hidden while a card shows
---@field card AddonBeastCard
---@field chosen number? the beast whose card shows

---A beast's card on the Beasts tab (Modules\BeastMap\BeastCard.lua).
---@class AddonBeastCard: Frame
---@field back Button
---@field title FontString
---@field level FontString
---@field family FontString with its diet
---@field teaches FontString a coloured line per rank
---@field model PlayerModel
---@field hunt Button
---@field mapName FontString the shown map's name, or the instance's
---@field map Frame the map's art and dots
---@field tiles Texture[] the art tiles, made as needed
---@field dots AddonBeastDot[] the spawn dots, made as needed
---@field maps AddonBeastMapButton[] a button per map the beast lives on
---@field npc number? the beast shown
---@field shownMap number? the uiMapID shown
---@field spellID number? the first rank it teaches that the hunter lacks: Hunt's

---@class AddonBeastDot: Button
---@field disc Texture
---@field card AddonBeastCard
---@field x number percent
---@field y number

---@class AddonBeastMapButton: Button
---@field label FontString
---@field map number?

---@class AddonBeastRow: Button
---@field stripe Texture every other row
---@field icon Texture the first rank it teaches that the hunter lacks, else its first
---@field name FontString
---@field family FontString
---@field level FontString
---@field teaches FontString its ranks, coloured by standing
---@field speed FontString its attack speed when not 2.0
---@field go Button shows the way there
---@field npc number?

---A scrollbar beside a list of rows (Core\Widgets.lua).
---@class AddonScrollBar: Slider
---@field track Texture
---@field offset number rows scrolled past
---@field last number the highest offset
---@field OnScroll fun(offset: number)
---@field SetRange fun(self: AddonScrollBar, total: number, visible: number)

---A dropdown of the window's tabs (Core\Widgets.lua).
---@class AddonPicker: Button
---@field back Texture
---@field arrow Texture
---@field label FontString "<title>: <choice>"
---@field title string
---@field values (string|number)[] the choices, in order
---@field texts string[] each choice's text
---@field value (string|number)? the choice shown
---@field OnPick fun(value: string|number)

---The list a picker opens, one for every picker.
---@class AddonPickList: Frame
---@field inner Frame holds the rows; takes the mouse wheel
---@field rows AddonPickRow[]
---@field bar AddonScrollBar
---@field picker AddonPicker? the picker it is open for

---@class AddonPickRow: Button
---@field label FontString
---@field value (string|number)?

---@class AddonFamilyBeastRow: Frame
---@field text FontString
---@field go Button
---@field npc number?

---@class AddonPetModel: PlayerModel
---@field dragX number? the cursor's x while the mouse drags it

---One of the core's sources (Core\Listen.lua): the game events it watches while its message has a
---listener, a method per event of the same name, and Start, which takes stock when it begins.
---@class AddonSource
---@field events string[]
---@field running boolean? watching now
---@field pending boolean? a check is on its way (the growth source)
---@field Start fun(self: AddonSource)
---@field [string] any its own state and event methods

---The names of the messages Huntsworn sends: "<NAME>_TOAST" and so on (Core\Addon.lua).
---@class AddonMessages
---@field print string
---@field toast string
---@field ranksKnown string
---@field abilityLearned string
---@field petGrowth string
---@field autocastWanted string
---@field rareSeen string
---@field huntStarted string
---@field huntEnded string
---@field petHappiness string
---@field petDied string
---@field petState string
---@field petTamed string
---@field ammo string
---@field petAtPull string

---Any value the game hands over, before the addon checks its type.
---@alias GameValue string|number|boolean|table|nil

---The addon object, which is also the files' namespace (`local _, ns = ...`).
---@class Addon: AceAddon, AceConsole-3.0, AceEvent-3.0
---@field NAME string the folder's name, which every name the game sees is made from (Core\Addon.lua)
---@field SLASH_ALIAS string the slash command's short form, beside NAME in lower case
---@field messages AddonMessages the messages Huntsworn sends, by key
---@field petArrived boolean? the session's first UNIT_PET has come: the pet's values can be read (Core\Listen.lua)
---@field L table<string, string> the AceLocale strings
---@field db AceDBObject-3.0 HuntswornDB; profile.modules[name] holds each module's switch
---@field modules table<string, AddonModule> AceAddon's own module table, by name
---@field features {happiness: boolean, ammo: boolean, beastTraining: boolean, beastData: boolean} what the client's game has (Core\Features.lua)
---@field C AddonCompat the modern pet, spellbook and tooltip API on every client (Core\Compat.lua)
---@field optionsCategoryID string|number the settings page, for Settings.OpenToCategory
---@field moduleCategoryIDs table<string, string|number> each module's page, by module name
---@field PROFILE_OPTIONS string[] the keys of AceDBOptions' own Profiles entries, see Core\Options.lua
---@field data AddonData
---@field window AddonWindow? made the first time it opens
---@field WINDOW_PANEL_WIDTH number a window tab's panel width
---@field families table<string, number> CreatureFamily IDs by key: families.cat is 2
---@field petSpecs AddonPetSpecs the families' specializations
---@field diets AddonDiets the kinds of food a family eats
---@field happiness {unhappy: number, content: number, happy: number} GetPetHappiness's values
---@field sex {unknown: number, male: number, female: number} UnitSex's values
---@field factions {alliance: string, horde: string} UnitFactionGroup's first return
---@field raidMarks {star: number, circle: number, diamond: number, triangle: number, moon: number, square: number, cross: number, skull: number} SetRaidTarget's and /tm's indexes
---@field ammoKinds {arrow: AddonAmmoKind, bullet: AddonAmmoKind} Projectile item subclasses (Data\Ammo.lua)
---@field familyInfo table<number, AddonFamilyInfo> by CreatureFamily ID
---@field petCategories AddonPetCategories the families' categories before Wrath
---@field familyMods table<number, AddonFamilyMods> by CreatureFamily ID, the classic clients'
---@field FamilyModsText fun(familyID: number?): string?
---@field DietText fun(familyID: number?): string?
---@field FoodName fun(food: string): string a Huntsworn.diets value's name
---@field ScrollBar fun(list: Frame, OnScroll: fun(offset: number)): AddonScrollBar (Core\Widgets.lua)
---@field Picker fun(parent: Frame, skin: AddonButtonHolderSkin, width: number, title: string, OnPick: fun(value: string|number)): AddonPicker
---@field FillPicker fun(picker: AddonPicker, value: string|number): string|number shows a choice, the first when `value` is none
---@field FillPickList fun()
---@field pickList AddonPickList? made the first time a picker opens
---@field FamilyLine fun(familyID: number?): string the category and modifiers before Wrath, else the specialization
---@field LoyaltyFromText fun(text: string): number?, string? a loyalty text's level and name, in each client's wording
