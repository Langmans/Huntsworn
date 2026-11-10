# Changelog

## Unreleased

- Renamed from Kennel (a 2008 addon already has the name on CurseForge), then
  from Beastkeeper to Huntsworn, a name for the whole hunter and not only the
  pet. The slash command is /huntsworn, or /hs; the macros, the messages
  (HUNTSWORN_TOAST, ...) and the saved settings (HuntswornDB) carry the new
  name.

### Clients

- WoW: Forever, Classic Era (Season of Discovery, Hardcore too) and Burning
  Crusade Classic, each with its own data: the beasts that teach pet
  abilities, pet trainers and stable masters (Outland's too), ammo vendors
  (Burning Crusade's new arrows and bullets too), and on Classic Era and
  Burning Crusade each food's kind. Mists of Pandaria Classic and retail load
  too, with the modules their game has.
- The beasts that teach pet abilities come from LibTameable-1.0, for Classic
  Era, Burning Crusade and WoW: Forever; Burning Crusade gets Beast Map and
  its families (Dragonhawk, Ravager, Warp Stalker, Sporebat, Nether Ray,
  Serpent). Each client loads only its own beast data. On WoW: Forever each
  beast teaches what Wowhead's hunter pets tool says it knows when tamed, every
  teaching beast has its map pins (or its instance), and
  Forever's new beasts (Zephras Isle and others) are in.
- What a pet eats on Classic Era and Burning Crusade comes from LibTameable
  too, each family's diet from the client's own tables.

### Huntsworn itself

- A settings page under AddOns → Huntsworn with a switch per module, a page per
  module with options, and profiles.
- `/huntsworn` opens Huntsworn's window, `/huntsworn config` the settings page;
  `/huntsworn help` lists the module commands, as does an unknown command
  after saying so. The window has a tab per part,
  takes the button skin's look, moves by dragging, and opens from the data
  broker and a key binding too.
- Huntsworn's macros say what they do in the tooltip of the action button they
  are on.

### Toasts

- A toast for every module, in two looks: a small card near the top of the
  screen, or a large splash in the middle. Both have a timer bar; drag to
  move, right-click to close, hover to keep it up. Duration, size and look on
  Huntsworn's page, and a look per kind of toast. Other addons can add looks.
- A kind of toast can start on a look its module picks; the pet's portrait on
  the icon; an optional screenshot per toast.
- A look that shows toasts as the game's raid warning, and one that sends
  them through LibSink: Blizzard's floating text, chat, raid warning, MikSBT
  and the other outputs LibSink knows.

### Modules

- Care Button (from Pet Care Button): one key and the HuntswornCare macro for
  Mend Pet, Revive Pet and Call Pet that remember a dead pet, also once the
  body is gone; toasts when the pet dies, is missing at the pull or runs low,
  or combat starts with it on Passive; a low health marker beside the pet
  frame that works while the game hides the pet's health; the button on
  screen too, showing what a click casts.
- Ability Learned (from Pet Ability Learned): a toast, on the splash by
  default, when your hunter learns a pet ability from a tamed beast, with the
  pet's portrait and free training points; a history per character of every
  rank learned and the beast it came from, with a list of learns from beasts
  Huntsworn's data does not know as teachers; hints on what a summoned pet can
  still teach, from what Beast Training shows; a toast when your pet gains
  training points, naming the level-up or loyalty level behind them, and one
  when its loyalty drops; a sound choice for each.
- Feed Emotes (from Feed Pet Emotes, which it replaces): a random /emote
  every time you feed your pet, with your own lines, conditions and the pet's
  sex per pet. Off until switched on. Lines for Forever's foxes in all six
  languages.
- Autocast Check (from Pet Autocast Check): Growl or Cower on autocast as
  fits, Cower in a dungeon group and Growl elsewhere; the HuntswornKite macro
  (Cower, Distracting Shot) and HuntswornGrowl macro choose until a dungeon group
  is entered or left. A toast when it does not fit, again at a pull at most
  every 5 minutes (a slider, 0 for every pull), and one key or the
  HuntswornAutocast macro that sets it right.
- Feeding: a button beside the pet frame while the pet is alive and not happy (and not eating), feeding
  the food that keeps it happy cheapest (Well Fed food last), the order in
  its tooltip, a list to pick another food on a right-click; toasts when the
  pet becomes content or unhappy and when the last food it eats is gone.
- Data Broker: Huntsworn as a LibDataBroker source (Titan Panel, ChocolateBar,
  ElvUI datatexts): the pet's name, happiness and free training points, more
  in its tooltip, Huntsworn's window on a click; and as a minimap button.
- Pet Journal: a page per pet with when and where it was tamed, its level and
  loyalty, what it eats, the time out together, its deaths, a forecast of the next loyalty
  level and its abilities, stabled pets included, with what each could still
  teach you; the short version in the pet's tooltip. In Huntsworn's window a
  Pets tab with a card per pet: its model, specialization, journal and
  abilities, and a Stable tab with every pet side by side. Stabled pets'
  models and names come from the stable master.
- Beast Map: with HandyNotes, a pin for every beast your hunter can tame now
  that teaches a pet ability rank you lack, with the ability's icon and a
  tooltip of the ranks it teaches; switches for missing lower ranks, every
  beast in reach and beasts above your level. At a level-up, also without
  HandyNotes, a toast for the ranks a beast of the new level brings in reach.
  A click on a pin takes you there, through LibGoThere-1.0: Shortest Path
  Forever, Move Fast, TomTom, the game's map pin or a pin link. Beast names
  in your game's language once it knows the beast. A button on the world map
  shows or hides the pins. Beasts in a dungeon get a pin at its entrance. A
  beast's tooltip says which ranks it teaches and whether you lack them. A
  toast when a rare beast that teaches a rank you lack comes in sight, and a
  tame key that targets and marks that beast (or the one whose pin you
  clicked), Shift for Tame Beast. Pins for the pet trainers and stable
  masters of your faction. In Huntsworn's window an Abilities tab (every rank,
  known or the nearest beast that teaches it) and a Families tab
  (specialization, diet, what each family learns, where to tame one).
- Ammo: your ammo count as a data broker source (EllesmereUI's data bars,
  Titan Panel), orange when low and red when critically low with a toast at
  each, both saying how long the ammo lasts at the pace of your fight; a click
  shows the way to the nearest ammo vendor of your faction for
  your kind of ammo; at a vendor it buys the best ammo for your level to fill
  your quiver or ammo pouch.

### Other addons

- Button skins: Huntsworn's buttons and lists in the look of Masque, ElvUI or
  EllesmereUI, chosen on Huntsworn's page (Automatic by default). Other addons
  add theirs with Huntsworn:RegisterButtonSkin and RegisterButtonHolderSkin.
- With EllesmereUI loaded: the card and the splash in EllesmereUI's look;
  with ElvUI loaded, in ElvUI's.
- With MessageQueue loaded: a LibSink output that says toasts in a chat
  channel (say, party, group, a custom channel); say, yell and channels go out
  on your next key press or click, as WoW: Forever requires.
- With OAP Debug installed: Huntsworn's messages, chat lines, counts, the
  window's timings and its Lua errors in OAP Debug's window; with DebugLog
  installed, the messages and chat lines in a Huntsworn tab, sorted into
  categories. As much as the "Debug" setting on Huntsworn's page says.
- With LS: Toasts loaded: a toast look that hands Huntsworn's toasts to it.
- Care Button: Alt-click opens Beast Training while the pet has training
  points to spend; the tooltip says how many.
- Data Broker: a middle-click opens the window on the pet abilities.
- Ammo: "Count only the ammo in the ammo slot" (on by default); switched off,
  it counts every kind of ammo your weapon shoots and your level allows. The
  low-ammo toast names the ammo it counts ("Rough Arrow low: 400 left").
- Beast Training is read on Classic Era and Burning Crusade too (the craft
  window), and its training point costs are kept: the pet's journal advises
  what to train with its free points ("Train (Upgrades), 43 free points: Bite
  rank 2 (10); 33 left.") and what to save for. On the Pets card a choice per
  pet: Upgrades (what it has first), Tank (Growl, armor, resistances first) or
  DPS (Bite, Claw, Dash first). Only abilities the pet's family can learn:
  Classic Era's Beast Training also lists the others, without a cost.
- HUNTSWORN_PET_AT_PULL for other addons: combat started without a pet, with
  a dead one, or with one on Passive.
- Beast Map: during a hunt the tame key shows as a button on screen: a click
  targets and marks the beast, Shift-click casts Tame Beast; Shift-drag moves it.
  A right-click stops the hunt.
- Beast Map: the hunt ends when you tame a beast that teaches its rank, the
  hunted one or another ("Tamed Whiskers, which teaches Claw (Rank 3): the
  hunt for Rare Cat is over."). A switch on Beast Map's page, on by default.
- The HuntswornAutocast macro set nothing: a macro that /clicks a button
  cannot run that button's macro lines. It holds the /petautocaston and
  /petautocastoff lines itself now, rewritten after combat when what fits
  changes; an existing macro is turned over by itself, your own lines stay.
- Autocast Check: while your pet has a Cower rank you do not know yet, Cower
  belongs on beside Growl (you learn it only once the pet uses it): the toast
  says so, the key and the HuntswornAutocast macro put both on, and once
  learned Cower goes off again. A switch on its page, on by default.
- Ammo at a vendor: passes over ammo you cannot buy for gold, the reputation
  ammo your standing does not reach and ammo paid in tokens; never buys ammo
  worse than the ammo slot's (no Rough Arrows while you shoot Sharp ones);
  and with "Buy only what fits in the quiver or ammo pouch" (on by default)
  never more than its free slots hold.
- Beast Map: a pet ability's tooltip (the pet's spellbook, the pet bar, Beast
  Training) says the pet level it needs and its training points, the
  families that learn it, and whether you know the rank; if not, the nearest
  beasts that teach it. A switch on Beast Map's page, on by default.
- Classic Era and WoW: Forever: a beast's attack speed beside its level where
  it is not the usual 2.0 ("Level 37, rare, attack speed 1.0"), in the pin's
  tooltip, the Families tab and the rare alarm: a tamed beast keeps it there.
  On Classic Era also in the tooltip of any tameable beast ("Attack speed
  1.7"), teaching or not, by Petopia's list of tamed pets' speeds.
- Beasts tab (Beast Map): every beast that teaches a pet ability rank, by
  level, like Wowhead's hunter pets tool but measured against your hunter.
  Each row has the beast's family, levels, the ranks it teaches (green new,
  yellow skipped, grey known), its attack speed when not 2.0 and a button
  that shows the way there. Filters, kept in the profile: a name search,
  ability, family, diet, zone (all, the one you are in, or one), "You: has
  already / not yet", in reach and rares. A scrollbar beside the rows. A
  click on a beast opens its card: levels, family and diet, what it teaches,
  its model, and its zone's map with a dot per spawn spot (a click shows the
  way there; a button per map when it lives on several), and Hunt for the
  first rank it teaches that you lack.
- Families tab: the list by family or by role (Offense, Defense, General on
  Classic, the strongest first; or named Ferocity, Tenacity, Cunning with a
  switch on the Beast Map page), scrolled with the mouse wheel, and with
  "Rares" ticked a Rares item per group that shows its rare beasts. A
  family's abilities a row each (icon, "2/8" known, the "!" for a rank to
  learn now); a click opens that ability in the Abilities tab. Six of its
  beasts instead of three.
- Beast Map's level-up toast and rare alarm wait for Beast Training: before
  the quest Training the Beast no beast can teach your hunter anything.
- Beast Map's button on the world map lines up with the map buttons of other
  addons (MapNotes, RareScanner, Questie) instead of sitting under them,
  through Krowi_WorldMapButtons.
- Abilities tab: a quest giver's "!" on an ability with a rank you can learn
  now (from a beast at or below your level); its tooltip names the rank you
  know and those to learn.
- Pets tab: the pets you no longer have (released, or lost) under a Past pets
  heading; the Stable tab shows only the pets you have. On Classic Era a new
  pet with the name and family of one you released keeps its own page at the
  stable master, and a stabled pet's page no longer takes the pet out's beast.
- Toasts at the right moments only: the low-ammo toast not on the way back
  up while restocking; the pet's low health only in combat (not right after
  Revive Pet), or at the pull; no "content" for a pet that was content when
  logged in with or summoned; no training points or loyalty drop for a newly
  tamed pet that has the name of one released before it.
- An About page in the settings: title, notes, version, author, license and
  website (LibAboutPanel-2.0).
- Messages with a table of details, heard through Huntsworn:Listen:
  HUNTSWORN_TOAST, HUNTSWORN_PRINT, HUNTSWORN_RANKS_KNOWN, HUNTSWORN_ABILITY_LEARNED,
  HUNTSWORN_AUTOCAST_WANTED, HUNTSWORN_RARE_SEEN, HUNTSWORN_AMMO, and from the core
  HUNTSWORN_PET_HAPPINESS, HUNTSWORN_PET_STATE (alive, dead or none),
  HUNTSWORN_PET_DIED, HUNTSWORN_PET_TAMED and
  HUNTSWORN_PET_GROWTH (training points, level and loyalty, up or down), which
  it works out only while something listens. Huntsworn's own modules listen the
  same way. See docs/04-hooking.md, with an example addon, and
  docs/AddonMessages.lua for their types.
