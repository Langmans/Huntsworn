-- BeastMap's English strings: the "BeastMap" namespace on the CurseForge translation page (see
-- Locales\README.md). Beast names come from the data in English; ability names and ranks come
-- from the client.
local addonName = ...
local L = LibStub("AceLocale-3.0"):NewLocale(addonName, "enUS", true)

-- One string per line, however long: see Locales\README.md.
-- stylua: ignore start

-- Settings window: the module's switch and page title, and its tooltip. The title also names the
-- plugin in HandyNotes' list.
L.BEASTMAP_TITLE = "Beast Map"
L.BEASTMAP_DESC = "With HandyNotes: a pin on the world map and the minimap for every beast that can teach your hunter a pet ability rank, with the ability's icon. Hover a pin for the beast's level and the ranks it teaches."

-- The module's page when HandyNotes is not loaded.
L.BEASTMAP_NO_HANDYNOTES = "Beast Map shows its pins through the HandyNotes addon, which is not loaded."

-- Settings: the pins at all, and the round button in the world map's top-right corner that switches them.
L.BEASTMAP_OPTION_PINS = "Show the pins"
L.BEASTMAP_OPTION_PINS_DESC = "On the world map and the minimap. The button on the world map switches this too."
L.BEASTMAP_OPTION_BUTTON = "Button on the world map"
L.BEASTMAP_OPTION_BUTTON_DESC = "A round button in the map's top-right corner that shows or hides the pins."
-- The map button's tooltip, under BEASTMAP_TITLE.
L.BEASTMAP_PINS_SHOWN = "Pins shown. Click to hide them."
L.BEASTMAP_PINS_HIDDEN = "Pins hidden. Click to show them."

-- Settings: which beasts get a pin.
L.BEASTMAP_OPTION_USEFUL = "Only beasts that teach a rank I lack"
L.BEASTMAP_OPTION_USEFUL_DESC = "Leave out a beast whose ranks you know already, or know a higher rank of. What you know comes from Ability Learned: your learns, and Beast Training once you have opened it."
L.BEASTMAP_OPTION_GAPS = "Also a missing lower rank"
L.BEASTMAP_OPTION_GAPS_DESC = "Count a rank below your highest that you never learned (Claw 2 when you know Claw 1, 3 and 4): a lower rank suits a young pet and costs fewer training points."
L.BEASTMAP_OPTION_ABOVE = "Also beasts above my level"
L.BEASTMAP_OPTION_ABOVE_DESC = "A hunter can only tame a beast up to its own level. Turn this on to see the ones for later too."

-- Settings: the level-up toast.
L.BEASTMAP_OPTION_UNTIL_TAME = "No beasts before I can tame"
L.BEASTMAP_OPTION_UNTIL_TAME_DESC = "Until you know Tame Beast (level 10), no beast gets a pin: there is nothing to learn from one yet. Trainers and stable masters keep theirs."
L.BEASTMAP_OPTION_CHAT = "Also in chat"
L.BEASTMAP_OPTION_CHAT_DESC = "Say the level-up toast's ranks and beasts in chat too, so they are still there after the toast is gone."
L.BEASTMAP_OPTION_TOAST = "Toast at a level-up"
L.BEASTMAP_OPTION_TOAST_DESC = "When a new level brings a beast in reach that teaches a rank you lack, and no lower beast taught it, say which rank and where. Works without HandyNotes."

-- Settings: the lines on a beast's tooltip.
L.BEASTMAP_OPTION_TOOLTIP = "Say on a beast's tooltip what it teaches"
L.BEASTMAP_OPTION_TOOLTIP_DESC = "Hover a beast: a line per pet ability rank it teaches, green and \"new\" when you lack it, yellow and \"skipped\" for a lower rank you never learned, grey and \"known\" when you know it. Works without HandyNotes."

-- A beast's tooltip, a line per rank it teaches, after the ability's icon. First %s: the ability
-- with its rank, such as "Claw (Rank 3)"; second: one of the three short endings below (a rank the
-- hunter lacks; a lower rank the hunter skipped; a rank the hunter knows).
L.BEASTMAP_TOOLTIP_TEACHES = "Teaches %s: %s"
-- A tameable beast's tooltip, above those lines, where its attack speed is not the usual 2.0 (a
-- tamed beast keeps it on Classic Era and WoW: Forever). %.1f: seconds.
L.BEASTMAP_TOOLTIP_SPEED = "Attack speed %.1f"
L.BEASTMAP_TOOLTIP_NEW = "new"
L.BEASTMAP_TOOLTIP_GAP = "skipped"
L.BEASTMAP_TOOLTIP_KNOWN = "known"

-- Settings: the lines on a pet ability's tooltip.
L.BEASTMAP_OPTION_SPELL_TOOLTIP = "Say on a pet ability's tooltip where to learn it"
L.BEASTMAP_OPTION_SPELL_TOOLTIP_DESC = "Hover a pet ability in the pet's spellbook, on the pet bar or in Beast Training: the pet level it needs (and its training points, once Beast Training showed them), the families that learn it, and whether you know the rank; if not, the nearest beasts that teach it."

-- A pet ability's tooltip. The pet level the rank needs; with its training point cost once Beast
-- Training showed it.
L.BEASTMAP_SPELL_LEVEL = "Pet level %d"
L.BEASTMAP_SPELL_LEVEL_COST = "Pet level %d, %d training points"
-- The families that learn it, comma-separated, such as "Cat, Wolf"; BEASTMAP_SPELL_ALL_FAMILIES
-- when every family does.
L.BEASTMAP_SPELL_FAMILIES = "Families: %s"
L.BEASTMAP_SPELL_ALL_FAMILIES = "all"
-- How the hunter stands to the rank: known (grey); above the highest known (green) or a lower rank
-- never learned (yellow), both followed by the nearest beasts that teach it (BEASTMAP_TEACHER_LINE).
L.BEASTMAP_SPELL_KNOWN = "You know this rank."
L.BEASTMAP_SPELL_TAME = "Tame one of these beasts, then let it use the ability:"
L.BEASTMAP_SPELL_SKIPPED = "You skipped this rank. Tame one of these beasts, then let it use the ability:"
-- After the first few beasts. %d: how many more teach it.
L.BEASTMAP_SPELL_MORE = "%d more in Huntsworn's Abilities tab."

-- Settings: pins for the hunter's other NPCs.
L.BEASTMAP_OPTION_TRAINERS = "Pet trainers"
L.BEASTMAP_OPTION_TRAINERS_DESC = "A pin for every pet trainer of your faction, where your pet learns the abilities beasts do not teach."
L.BEASTMAP_OPTION_STABLES = "Stable masters"
L.BEASTMAP_OPTION_STABLES_DESC = "A pin for every stable master of your faction."
-- Their pins' tooltips, under the NPC's name.
L.BEASTMAP_PET_TRAINER = "Pet Trainer"
L.BEASTMAP_STABLE_MASTER = "Stable Master"

-- The tame key: its name in Esc > Options > Keybindings, and what it says in chat. %s: the beast's name.
L.BEASTMAP_TAME_BINDING = "Beast Map: target and mark the beast to tame"
L.BEASTMAP_TAME_SET = "The tame key now targets %s."
L.BEASTMAP_TAME_NONE = "No beast to target yet: a rare alarm or a click on a beast's pin on the map sets one."
-- The tooltip of the tame key's button on screen during a hunt, under the beast's name.
L.BEASTMAP_TAME_HINT =
    "Click: target and mark. Shift-click: Tame Beast. Right-click: stop the hunt. Shift-drag to move."
-- The module's page: the switch for that button.
L.BEASTMAP_OPTION_TAME_BUTTON = "Show the tame button during a hunt"
L.BEASTMAP_OPTION_TAME_BUTTON_DESC = "A button on screen that does what the tame key does: a click targets and marks the hunted beast, Shift-click casts Tame Beast. A right-click stops the hunt. Shift-drag to move it."
L.BEASTMAP_OPTION_HUNT_TAME = "End the hunt at a tame that teaches the rank"
L.BEASTMAP_OPTION_HUNT_TAME_DESC = "The hunt is over once you tame a beast that teaches its rank, the hunted beast or another one. Off: it lasts until you know the rank, which takes the pet using the ability."

-- Settings: the rare alarm.
L.BEASTMAP_OPTION_RARE = "Toast when a rare beast I could learn from is near"
L.BEASTMAP_OPTION_RARE_DESC = "Once per spawn, when a rare beast that teaches a rank you lack shows on the minimap, as a nameplate, as your target or under the mouse. Follows the choices above (lower ranks, beasts above your level). Works without HandyNotes."

-- Settings window, Huntsworn's page: the kind of toast, for choosing its look. Shown after "Beast Map: ".
L.BEASTMAP_TOASTTYPE_REACH = "pet ability rank in reach"
L.BEASTMAP_TOASTTYPE_RARE = "rare beast nearby"

-- Rare alarm toast. Title, %s: the beast's name. Text, a line per rank; %s: the ability with its rank.
L.BEASTMAP_RARE_TOAST = "Rare beast nearby: %s"
L.BEASTMAP_RARE_TEACHES = "Teaches %s"

-- Toast title for one rank. %s: the ability with its rank, such as "Claw (Rank 3)".
L.BEASTMAP_REACH_ONE = "Now in reach: %s"
-- Toast text under it. %s: the beast and its place, BEASTMAP_REACH_PLACE, or the beast alone.
L.BEASTMAP_REACH_TEACHES = "%s teaches it."
-- Toast title for several ranks. %d: how many.
L.BEASTMAP_REACH_MANY = "%d pet ability ranks now in reach"
-- Toast text, one line per rank. First %s: the ability with its rank; second: the beast and place.
L.BEASTMAP_REACH_LINE = "%s: %s"
-- A beast and where it lives. First %s: the beast's name (English); second: the zone or instance.
L.BEASTMAP_REACH_PLACE = "%s in %s"

-- Pin tooltip, under the beast's name. %s: its level or level range, such as "5-6".
L.BEASTMAP_LEVEL = "Level %s"
-- Tooltip of a dungeon entrance's pin, under the instance's name: a line per beast inside, its ranks
-- under it. First %s: the beast's name; second: BEASTMAP_LEVEL with the rare/elite addition.
L.BEASTMAP_INSIDE = "%s: %s"
-- Pin tooltip, last line, in grey.
L.BEASTMAP_CLICK = "Click to go there."
-- Added after the level for a rare, elite or rare elite beast.
L.BEASTMAP_RARE = ", rare"
L.BEASTMAP_ELITE = ", elite"
L.BEASTMAP_RARE_ELITE = ", rare elite"
-- Added after that on Classic Era and WoW: Forever, where a tamed beast keeps its melee attack speed, for one that is not the usual 2.0. %.1f: the seconds between its attacks, such as 1.2.
L.BEASTMAP_SPEED = ", attack speed %.1f"

-- Huntsworn's window, the Abilities tab: its name; beside an ability in the list, first %d the ranks
-- the hunter knows, second the ranks beasts teach; a rank (%d); a rank the hunter knows; the heads
-- of the ranks' columns; a rank's go button's tooltip (%s the beast).
L.BEASTMAP_TAB_ABILITIES = "Abilities"
L.BEASTMAP_ABILITY_COUNT = "%d/%d"
-- The tooltip over an ability in that list. %s: the highest rank known (BEASTMAP_RANK, or BEASTMAP_ABILITY_NONE); then the ranks a beast at or below your level teaches, such as "Rank 2, Rank 3".
L.BEASTMAP_ABILITY_KNOWN = "Known: %s"
L.BEASTMAP_ABILITY_NONE = "none"
L.BEASTMAP_ABILITY_LEARN = "Learn now: %s"
L.BEASTMAP_RANK = "Rank %d"
L.BEASTMAP_KNOWN = "Known"
L.BEASTMAP_COLUMN_RANK = "Rank"
L.BEASTMAP_COLUMN_LEVEL = "Pet level"
L.BEASTMAP_COLUMN_TEACHER = "Nearest teacher"
L.BEASTMAP_GO = "Hunt %s: the way there, the tame key, its areas on the map"
L.BEASTMAP_GO_STOP = "Stop hunting %s"
-- The hunt (one beast the hunter means to tame for one rank): its start (first %s the beast, second
-- the rank, such as "Claw (Rank 3)"); its end when stopped (%s the beast); its end when the rank is
-- learned (the rank, the beast); /huntsworn hunt stop without a hunt; that command in /huntsworn help.
L.BEASTMAP_HUNT_START = "Hunting %s for %s."
L.BEASTMAP_HUNT_STOPPED = "Stopped hunting %s."
L.BEASTMAP_HUNT_LEARNED = "Learned %s: the hunt for %s is over."
-- A tamed pet teaches the hunted rank. First %s: the pet's name; second: the rank, such as
-- "Claw (Rank 3)"; third: the hunted beast.
L.BEASTMAP_HUNT_TAMED = "Tamed %s, which teaches %s: the hunt for %s is over. Let it use the ability to learn it."
L.BEASTMAP_HUNT_NONE = "Not hunting a beast."
L.BEASTMAP_CMD_STOP = "stop the hunt for a beast"
-- A rank the hunter lacks that no beast in Huntsworn's data teaches (Forever's family abilities: the pet may get them itself).
L.BEASTMAP_NO_TEACHER = "No beast teaches it"
-- After the nearest beast that teaches a rank (BEASTMAP_REACH_PLACE), comma-separated: the travel
-- time (%d minutes), that it is above the hunter's level. In a column of its own: how many more
-- beasts teach it (%d).
L.BEASTMAP_TRAVEL = "~%d min"
L.BEASTMAP_ABOVE = "above your level"
L.BEASTMAP_MORE = "+%d"
-- Huntsworn's window, the Families tab: its name; a family in the list with how many of the hunter's
-- pets are of it (%s the family, %d the count).
L.BEASTMAP_TAB_FAMILIES = "Families"
L.BEASTMAP_FAMILY_ROW = "%s (%d)"
-- Under the family's beasts list when Huntsworn's data has none of that family.
L.BEASTMAP_NO_BEASTS = "No beast of this family in Huntsworn's data."
-- The Families tab: how the list is grouped (by family, or under Ferocity, Tenacity and Cunning), and the switch that adds a Rares item to each group.
L.BEASTMAP_GROUP_FAMILY = "Family"
L.BEASTMAP_GROUP_ROLE = "Role"
L.BEASTMAP_RARES = "Rares"
-- The page (Classic Era and Burning Crusade only): the Families tab's groups by role named as the pet specializations of Wrath of the Lich King instead of the client's own categories.
L.BEASTMAP_OPTION_SPEC_NAMES = "Name pet roles Ferocity, Tenacity and Cunning"
L.BEASTMAP_OPTION_SPEC_NAMES_DESC = "In the Families tab, grouped by role: the names pets have from Wrath of the Lich King on, instead of this game's Offense, Defense and General. The groups stay the same."
-- The heading for families Huntsworn knows no role of.
L.BEASTMAP_ROLE_OTHER = "Other"
-- The card for a group's rares. %s: the family or the role, such as "Cat" or "Ferocity".
L.BEASTMAP_RARES_OF = "%s: rares"
-- A rank's tooltip, a line per beast that teaches it. First %s: the beast and its place; second: its level (BEASTMAP_LEVEL).
L.BEASTMAP_TEACHER_LINE = "%s: %s"

-- Huntsworn's window, the Beasts tab: its name; every beast that teaches a pet ability rank.
L.BEASTS_TAB = "Beasts"
-- The filters on top. Each dropdown shows "<what>: <choice>" (WINDOW_PICKED); the first choice of each is everything.
L.BEASTS_ABILITY = "Ability"
L.BEASTS_ABILITY_ALL = "All abilities"
L.BEASTS_FAMILY = "Family"
L.BEASTS_FAMILY_ALL = "All families"
-- What the beast's family eats (Meat, Fish, ...).
L.BEASTS_DIET = "Diet"
L.BEASTS_DIET_ALL = "All diets"
L.BEASTS_ZONE = "Zone"
L.BEASTS_ZONE_ALL = "All zones"
-- The zone the player is in. %s: its name.
L.BEASTS_ZONE_HERE = "Here (%s)"
-- How the hunter stands to what a beast teaches: every rank known already, or some rank not yet.
L.BEASTS_YOU = "You"
L.BEASTS_YOU_ALL = "All"
L.BEASTS_YOU_HAS = "Has already"
L.BEASTS_YOU_LACKS = "Not yet"
-- Switches: only beasts at or below the hunter's level; only rare beasts.
L.BEASTS_REACH = "In reach"
L.BEASTS_RARES = "Rares"
-- The grey text in the empty search box (it searches the beasts' names).
L.BEASTS_SEARCH = "Search"
-- The count above the list (%d: how many beasts match), and the line when none does.
L.BEASTS_COUNT = "%d beasts"
L.BEASTS_NONE = "No beast matches."
-- The column heads.
L.BEASTS_COLUMN_BEAST = "Beast"
L.BEASTS_COLUMN_FAMILY = "Family"
L.BEASTS_COLUMN_LEVEL = "Level"
L.BEASTS_COLUMN_TEACHES = "Teaches"
L.BEASTS_COLUMN_SPEED = "Speed"
-- A rare beast's name in the list. %s: the name.
L.BEASTS_RARE_NAME = "%s (rare)"
-- The tooltip of a row's map button. %s: the beast's name.
L.BEASTS_GO = "The way to %s"

-- stylua: ignore end
