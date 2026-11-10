# Huntsworn

[![CI](https://github.com/Langmans/Huntsworn/actions/workflows/ci.yml/badge.svg)](https://github.com/Langmans/Huntsworn/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/Langmans/Huntsworn?include_prereleases)](https://github.com/Langmans/Huntsworn/releases)
![Coverage](https://img.shields.io/badge/coverage-100%25-brightgreen)
![WoW: Forever](https://img.shields.io/badge/WoW-Forever%20%2816001%29-c79c6e)
![Classic Era](https://img.shields.io/badge/WoW-Classic%20Era%20%2811509%29-c79c6e)
![Ace3](https://img.shields.io/badge/Ace3-yes-blue)
[![License: MIT](https://img.shields.io/badge/license-MIT-yellow)](https://github.com/Langmans/Huntsworn/blob/main/LICENSE)

Hunter pet tools in one addon. Each tool is a module that can be turned on or
off on its own, in the game's settings window under **AddOns → Huntsworn**.

Huntsworn is being put together from separate addons by the same author; the
modules move in one at a time.

## Clients

| Client | What runs |
|---|---|
| WoW: Forever, Classic Era (Season of Discovery, Hardcore), Burning Crusade Classic | every module, with beast, trainer, ammo vendor and (Classic Era, Burning Crusade) food data of its own |
| Mists of Pandaria Classic, retail, and any other | Care Button, Autocast Check, Pet Journal, Data Broker: the game has no pet happiness, training points or ammo any more |

A module whose part of the game the client lacks stays off and is left off the
settings page. The beasts that teach pet abilities, and on Classic Era and Burning Crusade
what a pet eats, come from
[LibTameable-1.0](https://github.com/Langmans/LibTameable-1.0) (GPL-3.0; for
those two clients from the CMaNGOS databases).

## Use

- `/huntsworn` opens or closes Huntsworn's window: Pets and Stable (the Pet
  Journal), Abilities, Beasts and Families (Beast Map). Also from the data broker,
  its minimap button, or a key binding (Esc > Options > Keybindings > AddOns
  > Huntsworn). It takes the look of your button skin (Huntsworn's own, ElvUI or
  EllesmereUI); drag it to move it.
- With [OAP Debug](https://www.curseforge.com/wow/addons/oap-debug)
  installed, Huntsworn sends it what it does: its messages with their details,
  its chat lines, counts and timings, and its Lua errors under its own name.
  How much is the "OAP Debug" setting on Huntsworn's page.
- `/huntsworn config` opens the settings page: a switch per module, and the
  toast's settings. Each module with settings has a page of its own below it.
- `/huntsworn help` lists the commands the modules offer. Commands exist for what
  a macro needs; everything else is in the window or on the settings page.
- **Profiles** (a page under Huntsworn): every character uses the `Default`
  profile until you pick another. The module switches are part of the
  profile, so a profile can, for instance, turn a module off on one character
  only.
- **The toast**: modules tell you things with a toast. Drag it to move it,
  right-click to close it, hover over it to keep it up. On Huntsworn's page you
  choose how long it stays, how big it is, and its look: a small **card** near
  the top, or a large **splash** in the middle. Every kind of toast (such as
  Autocast Check's) can have a look of its own; other addons can add looks.
  With EllesmereUI or ElvUI loaded, both also come in that UI's look (its
  font, border and theme colour; with Eltruism's shadows on, its shadow too).
  Or as the game's raid warning: one line of
  big text in the middle of the screen.

### Autocast Check

Growl or Cower on autocast, as fits what you are doing:

| When | Growl | Cower |
| --- | --- | --- |
| In a dungeon or raid group: the tank holds the mobs | off | on |
| Anywhere else: your pet holds the mobs | on | off |
| You pressed **HuntswornKite** (kiting: the mob is on you) | off | on |
| You pressed **HuntswornGrowl** (stop kiting, or your pet tanks the group) | on | off |

Your choice holds until you enter or leave a dungeon group. A toast shows when
something stops fitting (you zone into a dungeon with Growl on, summon a pet
with Cower on) and goes away by itself once it fits again. When combat starts,
whatever is still wrong toasts again. Growl and Cower are seen whether they are
on the pet bar or only in the pet's spellbook. It plays your pet's call (the
raid warning for a pet without one), or nothing.

The game lets only a macro or a button you press change autocast, so:

- **One key sets it right**: Esc > Options > Keybindings > AddOns > Huntsworn >
  "Autocast Check: set Growl and Cower as fits", or the **HuntswornAutocast**
  macro. The toast says which to press.
- **HuntswornKite** puts Cower on and Growl off, and casts Distracting Shot.
- **HuntswornGrowl** puts Growl on and Cower off.

Huntsworn makes the three macros for each hunter the first time (`/macro`).
Deleted ones stay gone; **Make the macros** on the module's page makes them
again. The page also has which of Growl and Cower are watched, the combat
reminder, the sound, and a button for an example toast. On other classes it
does nothing.

### Care Button

One key for your pet: **Mend Pet** while it lives, **Revive Pet** when it is
dead, **Call Pet** when it is not out. The usual macro for this,
`/cast [mod:shift][@pet,dead] Revive Pet; [@pet,nodead] Mend Pet; Call Pet`,
has one hole: once a dead pet's body is gone, the game no longer sees a dead
pet and the macro picks Call Pet. The button remembers that the pet died, in
combat too and across a relog, and casts Revive Pet until the pet lives again.
Shift still forces Revive Pet and Ctrl Call Pet.

- Press it with the key binding (Esc > Options > Keybindings > AddOns >
  Huntsworn > "Care Button: mend, revive or call pet"), with the **HuntswornCare**
  macro Huntsworn makes for each hunter the first time, or click it **on
  screen**: below your pet's portrait, showing what a click casts now (green
  Mend Pet, red Revive Pet, yellow Call Pet), in your button skin's look.
  Shift-drag to move it; the page hides it or puts it back. The macro's cast line
  follows the button (outside combat); lines you add to it stay.
- It also learns from failed casts: Call Pet failing (or "Your pet is dead")
  means the pet is dead; Revive Pet failing at once means there is none to
  revive. In combat the button cannot switch: the toast says to hold Shift,
  and it switches when combat ends.
- Toasts when your pet **dies** (and again at the pull while it is still
  dead), when **combat starts without a pet** or **with your pet on Passive**
  (it will not attack; the toast goes once you change its stance), and when
  its **health drops** to a set line (40% by default, 0 for never). Each kind can have a look of
  its own on Huntsworn's page; each goes away once solved. They play your pet's
  own death sound, wound cry or attack call, the raid warning, or nothing.
- **Low health marker**: Mend Pet's icon lights up left of your pet's
  portrait while its health is below that line. WoW: Forever may hide your
  pet's health from addons in combat, so the toast cannot tell then; the
  marker lets the game itself decide, and still shows it.
- The module's page has those switches, the sound, buttons to tell the button
  your pet is dead or alive when it guessed wrong, an example toast and the
  macro. Switched off, the key and the macro do nothing.

### Ability Learned

A toast when your hunter learns a pet ability from a tamed beast (Claw rank 2
from a Nightstalker, say): the ability and its rank, the pet that taught it
with its portrait on the icon, and that pet's free training points. It starts
on the splash look. Only abilities learned in the wild count: Bite, Charge,
Claw, Cower, Dash, Demoralizing Screech, Dive, Furious Howl, Lightning Breath,
Prowl, Scorpid Poison, Shell Shield, Thunderstomp, and Forever's Dismember,
Dust Cloud, Mine!, Pinch, Savage Rend, Sonic Blast, Swipe, Tendon Rip and Web.
What a pet trainer sells, and anything learned while a trainer window is open,
does not.

- **Training points**: a toast when your pet gains training points, naming
  why: "Fluffy reached level 16" or "Fluffy now has loyalty level 5
  (Faithful)", with the points gained and how many are free for Beast
  Training; "Fluffy gained 19 training points" when both happened, or while
  it was away. Huntsworn keeps each pet's points, level and loyalty, so a pet you
  summon again is told what changed. Spending points says nothing, and so does
  a level-up at loyalty level 1, which brings none.
- **Loyalty**: a toast when your pet's loyalty level drops, with the new level
  and the training points that cost. The loyalty name is coloured from
  friendly green (level 1) to exalted teal (level 6).
- The points and loyalty toasts use the look for every toast, and each has
  its own sound choice.
- **Sound**, chosen apart for a learn, training points and loyalty: your pet's
  own (its call; its wound cry when loyalty drops; the level-up sound for a
  family without one), the level-up sound, or none. Optionally a **screenshot** of each learn.
- **History**: every learn, per character, with pet, zone and time; on the
  module's page, newest first. A learn from your pet also keeps the beast it
  was tamed as, and a button lists the learns whose beast Huntsworn's beast data
  does not have as a teacher yet: tell us, and Beast Map shows them too.
- **Hints**: when you summon or tame a pet, chat says which of its abilities it
  has at a higher rank than you know ("Fluffy can teach you: Claw (Rank 3).").
  Huntsworn knows your ranks from what it saw you learn and from the **Beast
  Training** window: open that once and the hints are complete.
- The module's page has the sounds, the screenshot, and the hints, training
  points and loyalty switches, an example toast, a
  simulated learn (the game's own chat line through the detection, kept out of
  the history), a "What can my pet teach?" button and the history. On other
  classes it does nothing.

### Feed Emotes

A random `/emote` every time you feed your pet, the way Feed-O-Matic did in
2008: "Langmans feeds Fluffy some Mystery Meat. Tastes like well-aged gnome."
**Off until you switch it on**: others in range see the emotes.

- It works with any way of feeding (Feed Pet: Forever's button, a macro, the
  spellbook and a click on food, dragging food onto the pet) and names the
  food as a clickable item link.
- Lines fit the pet and the food: some for every pet, for males or females,
  for the kind of food and for each of the 17 tameable families; in English
  and German the opening sentence varies too, and now and then the whole
  emote is a small scene. English, German, Spanish, French, Korean and
  Russian lines; other languages get the English ones.
- The emote goes out on your next key press or click, as WoW: Forever only
  lets an addon send chat then; with the MessageQueue addon, any input counts.
- WoW: Forever does not tell a hunter pet's sex: pick it on the module's page
  (kept per pet, through renames and stable swaps), or tick "Always use the
  pet's name".
- Your own lines, on the module's page: placeholders `{pet}`, `{food}` and the
  language's own (`{he}`, `{boy}`, `{his}` in English), conditions in front
  (`[cat,fish] Good hunter!`, or the boxes above the new line), a chance of an
  own line, a fallback when none fits, and one list shared by all characters
  if you want. An example button prints an emote only to you.

### Feeding

A button beside your pet's portrait, there while your pet is not happy: click
it to feed the next food from your bags.

- **The order**, in its tooltip: food that gives the most happiness first
  (food far below your pet's level gives less, or nothing, and is left out),
  then the lowest level, so the better food lasts; then the smallest stack.
  Food that also makes you Well Fed comes last. What your pet eats, the game
  says itself.
- **Right-click** for a list of all that food: click a row to feed that one
  instead (bags full: feed what you carry least of).
- The border shows the happiness: yellow content, red unhappy. Shift-drag to
  move the button; the page puts it back. It takes the look of Masque, ElvUI
  or EllesmereUI when one is loaded (choose under Buttons on Huntsworn's page),
  and sits beside EllesmereUI's pet frame.
- **Toasts** when your pet becomes content or unhappy, with the food that is
  next, and when the last food it eats leaves your bags. Each has a switch.

### Ammo

Your ammo count in data broker displays (EllesmereUI's data bars, Titan
Panel, ...) as "Huntsworn Ammo": orange below 500 and red below 250, with a toast
each time (both lines on its page). The toast and the tooltip say how long
the ammo lasts ("~17 min of Auto Shot"): at the pace of the fight you are in,
else of your last fight, else at one Auto Shot per weapon swing. Hover for the
nearest vendor of your
faction that sells your kind of ammo (arrows for a bow or crossbow, bullets
for a gun), click for the way there (Shortest Path Forever, TomTom, the game's
map pin), right-click for its page. At a vendor that sells your kind, it buys
the best ammo for your level: enough to fill your quiver or ammo pouch, or
the stacks set on its page without one (1 by default). Hunters with a bow,
gun or crossbow only.

### Data Broker

Huntsworn in Titan Panel, ChocolateBar, ElvUI's datatexts or any other data
broker display: your pet's name, happiness and free training points
("Fluffy: Happy, 43 TP"); hover for its level, loyalty and the Pet Journal in
brief; click for Huntsworn's window, right-click for the settings. The same as
a button on the minimap, which the module's page can hide.

### Pet Journal

A page for every pet your hunter had out (Huntsworn > Pet Journal), per
character: when and where you tamed it (or first had it out with Huntsworn), its
level, family and loyalty, what it eats ("Eats: Meat, Fish", also in its
tooltip and on its card), how long you were out together and how often it
died, when its next loyalty level may come (from how long the rises Huntsworn saw
took), and the abilities it had the last time it was out, so your stabled
pets are there too, with the ranks each could still teach you. Hover your
pet or its portrait for the short version in its tooltip.

In Huntsworn's window, the Pets tab lists them, the newest tame first and the
pets you no longer have under Past pets, with a card for each: its model (drag
to turn it), level, loyalty, its specialization (Ferocity, Cunning or Tenacity;
before Wrath its category and modifiers), the journal, and its abilities, the ones it
could still teach you in green. Visit a stable master once: Huntsworn then
knows your stabled pets' models and names too. The Stable tab puts all your
pets side by side, with how many ranks each could still teach you.

![The Pets tab: a boar's card with its loyalty, family modifiers, training advice choice, journal and abilities](docs/images/pets-tab.webp)

![The Stable tab: each pet you have, with its model, loyalty and abilities](docs/images/stable-tab.webp)

### Beast Map

With [HandyNotes](https://www.curseforge.com/wow/addons/handynotes): a pin on
the world map and the minimap for every beast that can teach your hunter a pet
ability rank, with that ability's icon. Hover a pin for the beast's level
(rare, elite) and the ranks it teaches, green for the ones you lack; click it
to go there, through the route or waypoint addon you have (Shortest Path
Forever, Move Fast, TomTom, the game's own map pin, or a map pin link in chat).

- By default only beasts you can tame now (at most your level) that teach a
  rank above the highest you know. What you know comes from Ability Learned:
  the learns it saw and the Beast Training window, so open that once.
- Switches on the module's page, also under HandyNotes' plugins: a missing
  lower rank too (Claw 2 when you know Claw 1, 3 and 4: it suits a young pet
  and costs fewer points), every beast in reach whatever it teaches, beasts
  above your level. Until you know Tame Beast no beast gets a pin (a switch
  too); trainers and stable masters do.
- **The tame key** (Esc > Options > Keybindings > AddOns > Huntsworn > "Beast
  Map: target and mark the beast to tame"; on a bar: a macro with
  `/click HuntswornTameButton`) targets the beast the rare alarm named, or whose
  pin you clicked, and puts a skull on it; with Shift it casts Tame Beast.
- **The hunt**: pick the beast you mean to tame for a rank, with a rank's
  button in the Abilities tab or a click on the beast's pin. Huntsworn shows the
  way there, gives it to the tame key, and marks the areas it lives in on the
  world map and the minimap. The hunt ends once you know the rank, or
  already when you tame a beast that teaches it (the hunted one or another;
  a switch, on by default), or with the button again, a right-click on the
  tame button or `/huntsworn hunt stop`.
- **Pet trainers and stable masters** of your faction get a pin too (Beast
  Training's and Call Pet's icons), each kind with its own switch.
- **In Huntsworn's window**, also without HandyNotes: the Abilities tab lists
  every ability beasts teach and how many ranks you know; per rank the
  nearest beast that teaches it (in a straight line, across zone borders; the
  five nearest by travel time with a route addon), a button that starts the
  hunt for it, and every teacher in its tooltip; a click on the rank unfolds
  it to every beast that teaches it, each with its own hunt button (scroll
  with the mouse wheel). The Beasts tab lists every beast that teaches a
  rank, by level, with its family, levels, the ranks it teaches (green new,
  yellow skipped, grey known), its attack speed when not 2.0 and a button
  that shows the way there; filter by name, ability, family, diet, zone (or
  the one you are in), what you have already or not yet, in reach and rares.
  Click the Distance head to put the nearest first (in a straight line, in
  yards), the Level head for level again. The filters and the order stay as
  you left them. Click a beast for its card: its model,
  what it teaches, and the map of its zone with a dot where it spawns (click
  a dot to go there), plus a Hunt button. The Families tab shows
  per family its specialization, diet, what it can learn and where to tame
  one. Its list goes by family or by role (on Classic the damage families
  first by their damage bonus, the tanks by armor and health), with a Rares
  item per group when "Rares" is ticked: that group's rare beasts, nearest
  first. On Classic the roles are named Offense, Defense and General, or
  Ferocity, Tenacity and Cunning with that switch on the Beast Map page.

  ![The Abilities tab: Bite's ranks, the ones known in green, each missing rank's nearest teacher with a hunt button](docs/images/abilities-tab.webp)
- **Rare alarm**, also without HandyNotes: a toast with the raid warning
  sound when a rare beast that teaches a rank you lack comes in sight (on the
  minimap, as a nameplate, your target or under the mouse), once per spawn.
- **On a beast's tooltip**, also without HandyNotes: a line per rank it
  teaches, green when you lack it, yellow for a lower rank you never
  learned, grey when you know it. On Classic Era any tameable beast's
  attack speed where it is not the usual 2.0 ("Attack speed 1.7"): a tamed
  beast keeps it.
- **On a pet ability's tooltip** (the pet's spellbook, the pet bar, Beast
  Training): the pet level it needs, its training points once Beast Training
  showed them, the families that learn it, and whether you know the rank; if
  not, the three nearest beasts that teach it and how many more do.
- **A round button** in the world map's top-right corner, in one row with
  the map buttons of other addons, shows or hides the pins (greyed while
  they are off). The button itself can be switched off on
  the page.
- **At a level-up**, also without HandyNotes: a toast when the new level
  brings a beast in reach that teaches a rank you lack and no lower beast
  taught ("Now in reach: Charge (Rank 1)", "Cave Boar in Wailing Caverns
  teaches it"), several ranks in one toast. It has its own switch, and one
  to say it in chat too.
- The ranks and the beasts that teach them come from LibTameable-1.0: on WoW:
  Forever 106 ranks and 409 beasts, on Classic Era 59 and 302, on Burning
  Crusade 97 and 357. Beast names come from
  your game, in its language, once it knows the beast; English before that.
  Beasts in a dungeon share one pin at its entrance; hover it for which
  beasts are inside.

## For developers

How Huntsworn is built, how to add to it, and how other addons can hook into it:

1. [Layout](https://github.com/Langmans/Huntsworn/blob/main/docs/01-layout.md):
   what each file and folder is.
2. [Modules](https://github.com/Langmans/Huntsworn/blob/main/docs/02-modules.md):
   writing a module, and the rules the core relies on.
3. [What the core offers modules](https://github.com/Langmans/Huntsworn/blob/main/docs/03-core-for-modules.md):
   toast, macros, pet helpers, chat, combat, key bindings, the beast data.
4. [Hooking into Huntsworn](https://github.com/Langmans/Huntsworn/blob/main/docs/04-hooking.md):
   the messages other addons (and Huntsworn's own modules) listen to through
   `Huntsworn:Listen`, a flowchart of who sends what, an example addon
   and [their types](https://github.com/Langmans/Huntsworn/blob/main/docs/AddonMessages.lua)
   for a language server.
5. [Toast skins](https://github.com/Langmans/Huntsworn/blob/main/docs/05-toast-skins.md):
   drawing Huntsworn's toast in your own look.
6. [Libraries](https://github.com/Langmans/Huntsworn/blob/main/docs/06-libraries.md):
   Ace3, LibSink and LibGoThere, pinned through `.pkgmeta`.
7. [Development](https://github.com/Langmans/Huntsworn/blob/main/docs/07-development.md):
   tests, lint, coverage, and screenshots while testing in game.
8. [CI and releases](https://github.com/Langmans/Huntsworn/blob/main/docs/08-ci-and-releases.md):
   the workflows, the packager, and playing the repository's copy.
9. [Button skins](https://github.com/Langmans/Huntsworn/blob/main/docs/09-button-skins.md):
   Huntsworn's buttons and lists in your own look; Masque, ElvUI, EllesmereUI.
10. [Renaming](https://github.com/Langmans/Huntsworn/blob/main/docs/10-renaming.md):
   what follows the folder's name, and what to change by hand.

## License

MIT, see [LICENSE](https://github.com/Langmans/Huntsworn/blob/main/LICENSE).
