# Traditional Preservation (Vinegar): developer help

These console commands load only when the game runs in **debug mode** (launch option `-debug`). Type them into the in-game Lua console, the **Command Console** window, and press Enter. Output goes to the console and to `~/Zomboid/console.txt`.

`TPV.help()` prints this list in the game.

| Command | What it does |
|---|---|
| `TPV.weather()` | The temperature in each place (open air, under an open roof, indoors, a basement, by a fire, by banked embers), and how fast malting, fermenting, souring and wort's own souring (`wort`) work there. By a fire counts by the clock, so `TPV.age` doesn't move it. |
| `TPV.here()` | Which kind of place you're standing in. |
| `TPV.age(hours)` | Gives every floor, vessel and cask this many hours of perfect weather. `TPV.age(120)` finishes a malting run, 240 a vessel run, 840 a cask from fresh. |
| `TPV.fast(hours)` | Test timers: every floor, vessel and cask run takes this many hours, with temperature ignored. `TPV.fast()` turns them off again. It replaces editing `V.TEST_HOURS`. |
| `TPV.timers()` | The hours each stage takes right now, the brewing effort and the temperature sensitivity. |
| `TPV.cask()` | The nearest cask (within 2 squares): litres, souring, bottles ready, mother, layers, litres to the next layer, starter bonus and hose. |
| `TPV.setCask(litres, percent)` | Sets the nearest cask's pool, e.g. `TPV.setCask(16, 100)` for a ready cask. |
| `TPV.mother(layers)` | Gives the nearest cask a mother with that many layers. `TPV.mother(2)` lets you test Split Mother, and `TPV.mother(0)` removes it. |
| `TPV.wort(litres)` | Fills the nearest vessel's Wort tank (20 if you leave the litres out). |
| `TPV.fermented(litres)` | Fills the nearest vessel's Fermented tank, to test drawing off and the hose. |
| `TPV.ageWort(hours)` | Adds this many hours at 20 C to every wort you carry and to the nearest vessel's Wort tank. `TPV.ageWort(48)` (the default) sours it: carried wort turns to Sour Wort at once, and the vessel then refuses to start. |
| `TPV.give(name, n)` | Spawns mod items such as `Malt` or `MotherOfVinegar`, or any full type such as `Base.Yeast` or `Base.RubberHose`. `TPV.give()` lists the names. |

Debug mode also adds **[Debug] Fill with Wort** and **[Debug] Fill with Fermented Wort** to a container's right-click menu.

**Typical check of the hose:** `TPV.give("Base.RubberHose")` and `TPV.give("Base.Pliers")`, attach the hose, then `TPV.fermented(19)` and `TPV.setCask(16, 100)`. Pump to Cask should offer 5 L, 10 L, the air line (6.5 L) and all that fits (14 L).

**Typical check of the mother:** `TPV.setCask(10, 100)`, `TPV.mother(1)`, `TPV.fermented(19)`, pump it all in, then `TPV.age(840)` and `TPV.cask()`. The mother should have grown a second layer.
