# Libraries

Ace3, LibSink-2.0, LibDataBroker-1.1, LibDBIcon-1.0, LibAboutPanel-2.0,
Krowi_WorldMapButtons-1.4, LibGoThere-1.0, LibDataGrid-1.0 and LibTameable-1.0.

Ace3 is not committed. `.pkgmeta` lists each library as an external, pinned
to a commit of the Ace3 GitHub mirror. The packager fetches them for a
release; `tests/libs.lua` reads the same `.pkgmeta` block and fetches the
same commits into `Libs\` before the tests. To move to a newer Ace3, change
the commit in `.pkgmeta` (all entries) and run the tests: the libraries are
fetched again when the block changes.

A stable release would be the better pin, and the mirror has release tags
(`Release-r1403`, ...). But the latest, r1403 of 12 August 2026, came before
AceDB's WoW: Forever fixes of September (character keys without the
surname, profile name limits) and AceGUI's ColorPicker fix for Forever, so
Huntsworn stays on a commit that has them until a release does.

LibSink-2.0 and LibDBIcon-1.0 (the Data Broker module's minimap button) live
only in CurseForge's svn, so their externals are `type: svn` with a release
tag. `tests/libs.lua` needs no svn client for it: the svn
server lists each directory as a page of links and serves each file at its own
address, which curl downloads.

LibDataBroker-1.1 (tekkub's GitHub repository) has no release tags; its
external is pinned to its last commit. The Data Broker module makes Huntsworn's
data object with it.

LibAboutPanel-2.0 (Myrroddin's GitHub repository) makes the About page from
the `.toc`'s fields (Title, Notes, Version, Author, X-License, X-Website); its
external is pinned to the commit of a release tag.

Krowi_WorldMapButtons-1.4 (TheKrowi's GitHub repository, BSD-3-Clause) places
Beast Map's button on the world map: one row with Blizzard's map buttons and
those of other addons that embed it (MapNotes, RareScanner, Questie), so no
button covers another. Its external is pinned to the commit of a release tag.
LibStub keeps the highest MINOR of all copies loaded, and each copy places
every button made with any of them.

LibGoThere-1.0 is Huntsworn's own route library, in a repository of its own
([github.com/Langmans/LibGoThere-1.0](https://github.com/Langmans/LibGoThere-1.0)),
an external pinned to a commit like Ace3. Beast Map sends the hunter to a
beast through it. To move to a newer version, change the commit in `.pkgmeta`.
ReagentRecipeVendorTooltips embeds it too: until the library's first release
every copy has MINOR 1 and LibStub keeps whichever loads first, so both
addons must pin the same commit.

LibDataGrid-1.0 is Huntsworn's own grid library
([github.com/Langmans/LibDataGrid-1.0](https://github.com/Langmans/LibDataGrid-1.0)):
the Beasts tab's filter box, Builder and list of beasts, with filter text such as
`[Level] BETWEEN 10 AND 20 AND [Speed] < 2` and sorting on several columns. An
external pinned to a commit, like LibGoThere; while its MINOR is 1, every addon
embedding it pins the same commit.

The `.toc` lists Ace3 and LibStub as `OptionalDeps`, so a separately
installed Ace3 loads first and LibStub keeps the newest copy of each library.
