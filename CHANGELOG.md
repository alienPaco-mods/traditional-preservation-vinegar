# Changelog: Traditional Preservation (Vinegar)

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
