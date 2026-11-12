# Changelog: Traditional Preservation (Vinegar)

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
