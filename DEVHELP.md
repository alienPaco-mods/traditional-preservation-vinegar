# Traditional Preservation (Vinegar): developer help

These console commands load only when the game runs in **debug mode** (launch option `-debug`). Type them into the in-game Lua console, the **Command Console** window, and press Enter. Output goes to the console and to `~/Zomboid/console.txt`.

`TPV.help()` prints this list in the game.

| Command | What it does |
|---|---|
| `TPV.weather()` | The temperature in each place (open air, under an open roof, indoors, a basement, by a fire, by banked embers), and how fast malting, fermenting, souring and wort's own souring (`wort`) work there. By a fire counts by the clock, so `TPV.age` doesn't move it. |
| `TPV.here()` | Which kind of place you're standing in. |
| `TPV.age(hours)` | Gives every floor, vessel and cask this many hours of perfect weather. `TPV.age(120)` finishes every heap on a Malting Floor, 240 a vessel batch, 840 a cask from fresh. |
| `TPV.fast(hours)` | Test timers: every floor heap, vessel batch and cask run takes this many hours, with temperature ignored (heaps already down too). `TPV.fast()` turns them off again. It replaces editing `V.TEST_HOURS`. |
| `TPV.timers()` | The hours each stage takes right now, the brewing effort and the temperature sensitivity. |
| `TPV.floor()` | The nearest Malting Floor (within 2 squares): each heap's state, progress and hours, how old its Green Malt is once done, and its frozen hours. |
| `TPV.cask()` | The nearest cask (within 2 squares): litres, souring, bottles ready, mother, layers, litres to the next layer, starter bonus, the mother's frozen hours (in all and toward the next layer lost) and hose. |
| `TPV.setCask(litres, percent)` | Sets the nearest cask's pool, e.g. `TPV.setCask(16, 100)` for a ready cask. |
| `TPV.mother(layers)` | Gives the nearest cask a mother with that many layers. `TPV.mother(2)` lets you test Split Mother, and `TPV.mother(0)` removes it. |
| `TPV.vessel()` | The nearest vessel: the waiting wort and its hours to souring, the batch (litres, progress, hours), the fermented wort and the hose. |
| `TPV.wort(litres)` | Empties the nearest vessel and fills it with this much fresh wort (20 if you leave the litres out). |
| `TPV.batch(litres, pct, yeast)` | Empties the nearest vessel and sets its batch, as if pitched and worked this far: `TPV.batch(10, 50)` is 10 L half done. No yeast needed. `yeast` `"underpitched"` (half speed until repitched) or `"lag"` (a day's pause) as a big top-up on a young batch would leave it. `TPV.batch(18, 10)` is above the foam line in its vigorous half. `TPV.batch(0)` takes it away. |
| `TPV.fermented(litres)` | Empties the nearest vessel and fills it with this much fermented wort, to test drawing off and the hose. |
| `TPV.ageWort(hours)` | Adds this many hours at 20 C to every wort you carry and to the nearest vessel's waiting wort. `TPV.ageWort(48)` (the default) sours it: carried wort turns to Sour Wort at once, and the vessel then refuses Pitch Yeast. |
| `TPV.kit(kind)` | The things a test needs: `"build"` (hammer, saw, planks, nails, twine, a jar and ripped sheets for all three stations), `"malt"` (24 barley seeds, a bucket of water, an empty bucket, ripped sheets), `"ferment"` (2 buckets of wort, 2 yeast and an empty bucket: pitch on one, top up with the other, draw off into the third), `"cask"` (hose, pliers, a Mother of Vinegar, an empty jar, 3 empty Crafted Bottles), or `"all"`. `TPV.kit()` lists them. |
| `TPV.frost(hours)` | Freezes for hours (default 6) the Mothers of Vinegar in jars and the Steeped Grain on you and within 4 tiles, the nearest cask's mother and the nearest Malting Floor's sprouting heaps, as if they had been frozen that long (Frost harms aside): a jar's mother 1/48 of the way to dead an hour, the cask's mother a layer every 6 hours (never the last), Steeped Grain and heaps Spent Grain from 6 hours. |
| `TPV.give(name, n)` | Spawns mod items such as `Malt` or `MotherOfVinegar`, or any full type such as `Base.Yeast` or `Base.RubberHose`. `TPV.give()` lists the names. |

Debug mode also adds **[Debug] Fill with Wort** and **[Debug] Fill with Fermented Wort** to a container's right-click menu.

**Typical check of the hose:** `TPV.kit("cask")`, attach the hose, then `TPV.fermented(19)` and `TPV.setCask(16, 100)`. Pump to Cask should offer 5 L, 10 L, the air line (6.5 L) and all that fits (14 L).

**Typical check of the mother:** `TPV.setCask(10, 100)`, `TPV.mother(1)`, `TPV.fermented(19)`, pump it all in, then `TPV.age(840)` and `TPV.cask()`. The mother should have grown a second layer.

**Typical check of frost:** `TPV.mother(3)` on a cask, `TPV.give("SteepedGrain")`, spread one on the floor and keep one, then `TPV.frost(6)`: the cask's mother is down to 2 layers, the heap reads Spent Grain (the band *Frozen*) and the carried one is Spent Grain. `TPV.frost(48)` kills a Mother of Vinegar in a jar.
