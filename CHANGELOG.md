# Changelog: Traditional Preservation (Vinegar)

## 0.2.15
- **Docs pass, sweep step G** (2026-11-12): the guide describes the Malting Floor's window; `TPV.weather()` lists the loft and *In a shed*; README season table from the tool with Loft columns, the grid, a fire and embers; the room-heating caveat (README, Workshop text) says the grid and a fire count; Workshop text names Fish & Meat.
- Needs Build 42.22 or newer (`versionMin`, was 42.20: everything is checked on 42.22). Workshop text (sweep step F). The guide gives a powered room's times (22 C: ferment 10 days, first
  cask 35).
- **Souring loses a tenth to the air, not a fifth** (2026-11-12; user, after the realism pass: a breathing cask
  loses a few percent to a tenth). `V.ACETIC_LOSS` 0.1: 19 L of fermented wort gives about 17.2 L, 17 bottles, 85
  jars' worth (was 15.5 L, 15 bottles, 75 jars). The days to the first bottles are unchanged. Test, simulation
  golden re-recorded, guide, Collection guide, README, Workshop text.

## 0.2.14
- **On TP Core's shared modules** (2026-11-12): bottles come back through Core's `Handcraft` (in place of the mod's
  own wrap of `ISHandcraftAction.performRecipe`), a malting or fermenting run catches up through Core's
  `Hearth.catchUpRun` and `Hearth.updateRun`, and casks and stations in reach are found with Core's `Station.near`.
  One thing a player may see: **Bottle Vinegar from the crafting menu draws from the nearest ready cask**, where it
  took the first one the search met. In-game steps 10 and 101 of `TESTING_GUIDE.md`.
- Guide (2026-11-12): checked line by line against the code. The hose comes back on Detach (which wants the pliers
  again); Empty Cask is described; the first-bottles table has a Loft column; Spent Grain's keeping; whole chapter
  numbers (the Brewer's Notebook is chapter 11), a Credits page.


## 0.2.13
- **TP Core's loft** (2026-11-12, consistency sweep step H): a floor, vessel or cask in the top storey reads the
  loft's temperature: the first cask sours 3 to 5 days sooner there, and the first bottles come 4 to 5 days sooner
  from a January, April or October start. Season report and simulation have a loft column; goldens re-recorded.
  README, guide, Workshop text.

## 0.2.12
- Guide: no emojis (2026-11-12): the decorative bullets and margin-note marks are gone, warning signs read **Warning:**.
- **Info in the Malting Floor's and Fermentation Vessel's windows** (2026-11-12, consistency sweep step E, TP Core's
  StationInfo): the place, its temperature and the stage's working rate there (malting or alcoholic), the running
  batch's bar with its time left, and what is waiting or finished; the vessel also lists its Wort and Fermented tanks.
  The cask keeps its Info window.

## 0.2.11
- **The cellar runs a month behind** (2026-11-12, TP Core): a basement follows the ground, about 5 C from January to
  March and 13 C from July to September: cooler than a room until August, warmer in the autumn (a vessel started there
  in September ferments in 16 to 20 days). The season report and simulation start from a long-running save's weather
  and read 30-day months (each month's forecast also held the 10 days before it, which stretched the old tables):
  first bottles in January day 170 / 182 / 230, July day 65 / 53 / 88. Guide almanac, README, Workshop text.

## 0.2.10
- **By a fire** (2026-11-12, consistency sweep step C): the Malting Floor, Fermentation Vessel and cask work at 28 C
  within 2 tiles of a lit fire, 24 C by banked embers, for as long as the fuel lasts (`V.notePlace`,
  `V.updateCaskAt`; a cask notes its place in its state). TP Core's new places: an unheated room follows the season
  (22 C while the grid is on), a basement swings a third as far, so vinegar is a summer job without a fire.
- **Heat harm dropped**: the game's climate never passes 35 C. `HEAT_HARM_ABOVE`, `HEAT_LOSS_PER_HOUR`,
  `MAX_HEAT_LOSS`, `V.heatLoss`, the popup's Heat Damage line are gone; old saves' `ledger.heat` and runs' `heat`
  are left unread. The "steady" basement wording is gone too. Season report (basement and fire), simulation, README,
  guide almanac, Workshop text, DEVHELP.

## 0.2.9
- Debug console (2026-11-12, consistency sweep): `TPV.here()`, as the other mods have. DEVHELP, guide.

## 0.2.8
- Docs (2026-11-11 pass against the code): the README no longer says a forged bucket comes back plain (fixed in
  this version; a wooden bucket was never accepted) or that the installed copy runs test timers; the starter
  table's 6.5 L row starts at 25%; the Skills table lists the stations' Carpentry XP; `test_console` is listed.
  No change in play.
- Fixed: a Vinegar bottled into a wine bottle (or any bottle but a Crafted Bottle) gave back a Crafted Bottle when a
  hand craft such as Make Jar used it up. The game's own Crafted Bottle is now swapped for the bottle it was filled into.
- Menu icons: pour and draw-off rows show each container with its fluid's colour, bottle rows the bottle as the
  inventory draws it, and Cask Info has the cask's icon.
- Balance (series pass, F1): Fermentation Vessel and Vinegar Cask need a saw, kept (staves are sawn). Steep
  Grain gives Cooking 3 (was 2).
- Internal: new `tests/test_console.lua` loads the debug console (TPV) and calls every command, so one can't
  break unseen.
- New: with more than one cask in hose reach, Attach Hose to Cask opens a list of them, nearest first, each with
  its status line (litres, how far soured, mother), and you pick one. With one cask it works as before.
  `V.casksForHose` replaces `V.caskForHose`.
- Changed: pouring fermented wort into a cask by hand brings the cask up to date first, as pumping does, so the new
  wort doesn't count souring time from before it arrived.
- Changed: clicking a cask built this session starts tracking it, as its menu does. Cask Info is TP Core's info
  window now: one info window at a time across the series, refreshed twice a second instead of every frame.
- Changed: every timed action honours the debug cheat for instant actions (only the hose did).
- Internal (core consolidation, review group C): the menu helpers, the pick-up block, the click handler, the
  station lookup (`V.stationKind` is the core's `Station.kinds`), pouring times, the sensitivity scale and the
  season mean are TP Core's; console lines go through the core's `Log` (debug mode only). Timed actions are named
  `TP...` (were `IS...`), file and class. Removed `V.spriteIndex`, `V.inHoseReach`, `V.SENSITIVITY_SCALES`.
- Fixed: a Forged Bucket used for Mash Malt came back from Strain Mash as a plain Metal Bucket. The bucket's kind
  is now noted on the mash (TP Core's `Container`, new hook `onMashed`) and Strain Mash gives back the bucket that
  went in, with the wort in it. Mash made before this gives a plain bucket, as before.
- Fixed: Farming XP for a finished malting was usually lost when the run ended while you were away. Whether a
  floor is running is now kept on the floor itself (`vinegarMaltBefore` in its modData), not in the tracker's
  entry, which is forgotten when the area unloads.
- Fixed: Pump to Cask ran from wherever you right-clicked. You now walk to the vessel first, and a pump queued
  behind a Detach Hose no longer pumps (`ISPumpVinegarWort:isValid` checks the hose on both ends).
- Fixed: the cask's and vessel's menus answer vanilla's controller probe (`ISWorldObjectContextMenu.setTest()`), so
  a controller gets the interact prompt on them; the probe no longer brings the station up to date.
- Internal: `V.sour` stops if a step gains nothing, so rounding can never leave it looping.
- Docs: README and Workshop text say the mod needs TP Core (they said "no other mods").

## 0.2.7
- **Requires TP Core** (`TraditionalPreservationCore`), the shared Traditional Preservation mod: subscribe to it
  too. Vinegar no longer carries its own copy of the shared core (weather, places, station tracking, popups and
  slot rules) and loads TP Core's instead. Same code, same rules and timings; saves keep every vessel, cask, malting
  floor and hose as they were.
- Internal: the synced core copies name the core's new source path (TP Core is now a mod). Comment line only.
- Internal: the synced core copies name the core's new source path (TP Core is now a mod). Comment line only.
- Internal: the shared core's folder is now `TraditionalPreservationCore` (was `_tpcore`): comments and test
  paths only. No change in play.

## 0.2.6
- Art: the Malting Floor stands on two low battens, so it no longer seems to hover above the floor.

## 0.2.5
- Internal: comments on the public functions that lacked one, and an updated copy of the shared core
  (comments only). No change in play.

## 0.2.4
- Internal: the stations' slot rules (adding, green border, refused-drop message) run on the shared core's
  `UI.slotRules`. Same rules, same messages.

## 0.2.3
- Performance: the weather ledger is checked for missing totals once when the save loads, not every time a batch,
  cask or popup reads it.
- Internal: recipe times are set through the shared core (`Weather.setRecipeHours`). No change in play.

## 0.2.2
- Internal: tile numbers come from a `Tiles.lua` the art builder writes, instead of hand-kept numbers. Same art.
- Internal: dropped aliases of core values that only the tools and tests used.

## 0.2.1
- Fixed: a vessel, cask, malting floor or hose in a chunk that had just unloaded could still be written to (run and
  hose state), so the change was lost or went to a stale chunk. Stations are now checked against the live cell.
- Fixed: Cask Info closes when its cask unloads.
- Internal: runs on the shared Traditional Preservation core (weather ledger, station tracking, popups).
  Same brewing and souring times; saves carry over unchanged.
