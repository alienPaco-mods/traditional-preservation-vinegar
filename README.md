# Traditional Preservation (Vinegar) — Build 42 prototype (v0.2.45)

**Status: experimental.** The whole chain, from steeped grain to bottled vinegar, has been played in the game with test timers. Temperature effects have only been checked offline so far (see the test plan). Back up your save before enabling.

Make your own malt vinegar from grain you grow. It ends in the same vanilla Vinegar you find in kitchens, so it works in every vanilla recipe, including pickling. It's built for long playthroughs, after the looted vinegar has run out. Together with Traditional Preservation (Yeast) and (Salt), the whole pickling pantry becomes renewable.

## History

Vinegar is what alcohol becomes when it meets air. English malt vinegar, once called alegar, began as soured ale made from malted barley. Yeast can't eat the starch in grain, so grain is first sprouted to make the enzymes that turn starch into sugar, then dried to stop it, and later soaked hot to do that work. The sweet liquid strained off, the wort, is fermented by yeast into a weak ale.

The ale was then soured by the **Orléans method**, used in France since the Middle Ages. A barrel is kept about three quarters full, with air holes above the liquid, and a pale skin, the mother, floats on top. Every week or two some vinegar is drawn off from the bottom and the same amount of new ale is poured in under the mother. The barrel is never emptied: what stays behind is the starter that keeps the next lot sour and safe. A thick mother can have a layer peeled off and passed to another barrel.

## Install

Copy this folder to `~/Zomboid/mods/TraditionalPreservationVinegar`, as a real copy rather than a symlink. It needs the **TP Core** mod (`TraditionalPreservationCore`, the series' shared mod) installed and enabled the same way, and no other mods.

## Getting started

1. **Grow barley, wheat or rye.** Sow from August to October, dry the sheaves on a drying rack and thresh them. Threshed grain doesn't spoil, so one harvest lasts all year. A full batch takes 48 grain, about 16 plants at base yield.
2. **Malt in spring or autumn.** Malt keeps forever, so make it once and brew from it all year.
3. **Keep yeast to hand.** Each vessel run takes one full packet of vanilla Yeast. Traditional Preservation (Yeast) can make more.
4. **Brew and sour indoors from May to August.** In winter only a fire keeps it going: set the vessel and cask within 2 tiles of one.
5. **Save your empty bottles and jars.** Each Vinegar uses up one bottle, and a Mother of Vinegar lives in a jar.
6. **Never empty the cask.** Before topping up, keep at least a third as much vinegar in the cask as the fermented wort you're about to add: about 6–7 L before a full batch, 3–4 L before a half batch. Then the mother's speed bonus works from the start.

From threshed grain, the first vinegar takes about 55 to 60 days in good weather. After that, a cask that is kept topped up gives more every week or so.

## The chain at a glance

| # | Step | Where | In | Out | Time |
|---|---|---|---|---|---|
| 1 | Steep Grain | Crafting menu | 24 grain, 4 L water | Steeped Grain | a craft |
| 2 | Spread Steeped Grain | Malting Floor | up to 4 Steeped Grain, each its own heap | Green Malt (rots in 5 days) | 5 days |
| 3 | Kiln | Fire or oven | Green Malt | Malt (keeps forever) | 3 hours* |
| 4 | Mash Malt | Crafting menu | 1 Malt, a metal bucket with 10 L water | Bucket of Mash | a craft |
| 5 | Heat the mash | Fire or oven | Bucket of Mash | Bucket of Prepared Mash | 1.5 hours* |
| 6 | Strain Mash | Crafting menu | Prepared Mash, a cloth (kept) | 10 L Wort in the bucket, Spent Grain | a craft |
| 7 | Pitch Yeast | Fermentation Vessel | 10 or 20 L Wort, 1 packet of Yeast | 95% as Fermented Wort | 10 days |
| 8 | Pour into the cask | By hand | Fermented Wort | joins the cask's pool | |
| 9 | Sour | Orléans Vinegar Cask | | the pool sours to 100% | 35 days, 26 with a mother |
| 10 | Bottle Vinegar | Cask's right-click menu | 1 L and an empty bottle | 1 vanilla Vinegar | a moment |

\* At the default Brewing effort (Normal). Days are at the best temperature.

| One full batch (2 buckets) | |
|---|---|
| Grain | 48 |
| Water | 28 L: 8 to steep, 20 to mash |
| Fire or oven | 2 kiln loads and 2 mash heatings |
| Yeast | 1 packet |
| Cloth | 1 Ripped Sheet or Cheesecloth, kept |
| Metal buckets | 2, all returned |
| Byproducts | 2 Spent Grain |
| Vinegar | about 17.2 L, which is 17 bottles |
| Pickling | about 85 jars |

## Stations

All three are under Furniture in the Build menu, need a hammer (kept) and have two facings. The twine stands in for the hoops coopers once bound from saplings, so everything here can be made again from what you grow and forage.

| Station | Skill | Materials |
|---|---|---|
| **Malting Floor** | Carpentry 2 | 6 planks, 8 nails |
| **Fermentation Vessel** | Carpentry 3 | 8 planks, 12 nails, 4 twine, 1 jar (the clear airlock on its side); a saw (kept) |
| **Orléans Vinegar Cask** | Carpentry 4 | 10 planks, 16 nails, 6 twine, 1 cloth (Ripped Sheet, Burlap Piece or Cheesecloth); a saw (kept) |

Twine is renewable in vanilla: twist it from Dogbane, scutched hemp, flax tow or sinew.

## How it works

### 1. Steep Grain

Crafting menu, Cooking. 24 barley, wheat or rye seeds and 4 L of water from any container (the container is kept) give one **Steeped Grain**, enough for one bucket of wort. The real day or two of soaking is part of the Malting Floor's time.

### 2. Malting Floor

Right-click the floor, **Malting Floor > Spread Steeped Grain** (One or All). It holds 4 heaps, one a Steeped Grain, and each heap has its own clock: a new heap can go down beside heaps already sprouting, as real floor maltings laid out each steeping as its own "piece". A heap sprouts into **Green Malt** in 5 days at the best temperature (12 to 20 C).

**Malting Floor Info** (in the floor's menu, and at the bottom of the main menu) lists every heap with a bar: how far on and the time left, or, once done, when the Green Malt goes stale. Hover a row for its progress, the place's temperature and the working rate. **Take Done** takes the Green Malt off; **Take Everything Off** (Take All in the window) takes the rest too: a heap taken off part way comes back as Steeped Grain that keeps how far it sprouted, and carries on from there when spread again (off the floor it waits). Drop Steeped Grain on the window's drop square to spread it. A floor with any heap on it can't be picked up.

### 3. Kiln

Put the Green Malt on a lit fire or in an oven. It dries into **Malt** in about 3 hours at Normal effort, and burns if left for a day. Malt keeps forever. Green Malt is food as far as the game is concerned, so it cooks like food, but nobody can eat it.

Green Malt doesn't wait: real sprouted grain keeps growing and then moulds unless it is kilned. It stays fresh for 2 days and is rotten after 5, counting from when its heap finishes (on the floor or off it), so collect it and kiln it soon. Stale Green Malt still kilns into good Malt. Rotten Green Malt doesn't: the game skips its change into Malt, so it stays rotten Green Malt on the fire. Put it in a composter instead.

### 4. Mash Malt

Crafting menu, Cooking. 1 Malt and a metal bucket holding 10 L of water give a **Bucket of Mash**. Crushing the malt is folded into this step.

### 5. Heat the mash

Put the Bucket of Mash on a fire or in an oven. In about 1.5 hours at Normal effort it becomes a **Bucket of Prepared Mash**, as the heat turns the starch to sugar.

### 6. Strain Mash

Crafting menu, Cooking, with a Ripped Sheet or Cheesecloth (kept). The bucket that went in, plain or forged, comes back holding **10 L of Wort**, and the grain left in the cloth is **Spent Grain**.

Wort and Fermented Wort are real liquids, added by this mod, not vanilla ones. They sit in any vanilla container: buckets, bottles, pots, mugs. Both are drinkable: wort is sweet and filling, and fermented wort is a weak, flat, unhopped ale (4% alcohol) that leaves you a little less happy than a proper beer would. Neither mixes with any other liquid, so a container of wort stays pure.

**Wort sours if it waits for the yeast** (sandbox **Wort sours**, on by default). Lactic bacteria from the grain get there first: wort left in a bucket, any container or waiting in the vessel becomes **Sour Wort** in 2 days at 20 C, 1 day at 30 C, about 5 days in a cool cellar, and never while frozen. Sour wort is still drinkable (a little unhappiness), but the vessel won't take it: pour it away. It ages by where it stands, as Dairy's milk does (TP Core's `FluidAgeing`), also while you're away; mixing old and new wort keeps the older age. Once a run has started the wort is safe, and fermented wort keeps.

| Wort sours (days, `tools/season_report.lua`) | Outdoors | Indoors | Grid on (22 C) | Basement |
|---|---|---|---|---|
| January | 36-70 | 46-87 | 1.6 | 12-14 |
| April | 3-12 | 6-9 | 1.6 | 8-11 |
| July | 1.2-2.8 | 1.5-2.2 | 1.6 | 4.3-5.2 |
| October | 7-31 | 4-8 | 1.6 | 5-6 |

**Spent Grain** weighs 0.8: a bucket's 24 grain weigh about 0.5 dry and soak up water in the mash. It rots in about 3 to 6 days. Put it in a composter, or feed it to farm animals from a trough: cows, sheep, pigs, chickens and turkeys all eat it.

### 7. Fermentation Vessel

Everything is in the vessel's right-click **Fermentation Vessel Info** submenu, and **Fermentation Vessel** (in the submenu, and at the bottom of the main menu) opens on a band with its state, the worst first: *Soured*, *Empty*, *Foaming over* (red: wort is spilling), *Underpitched*, *Lagging* (with how long), *Paused* below freezing, *Fermenting*, *Ready*, *Waiting* for yeast. Then TP Core's Station block (the vessel's outline icon, Place, Season, Working Rate, Hose: *Cask Connected*), and its one pool as a tank named by what it holds, with a dashed line at **16 L** and alegar's lore beside it: **Wort** (*Souring (2d)* in amber, or *soured* in red), **Fermenting** (wort turning to fermented wort from the foot by the share done, bubbles rising by the working rate, half as fast underpitched, still while it lags or is paused, a foam cap that thins as it nears done and runs down the side while it foams over; *74%, 3d* under it, and *1.0 L lost to foam* in red once any is), or **Fermented** (*keeps*). Under the tank **Pitch Yeast** with the yeast's icon (to start a batch, or to repitch one underpitched or lagging), or **Draw Off** once fermented wort is in (a menu of your empty containers under the button). Containers of wort dragged onto the tank pour in, or top up the batch while one works (`TraditionalPreservationVinegarUI.wortJudge`, as Pour Wort takes them). Its band, tank, rows and notes are `TraditionalPreservationVinegarUI.vesselBand`, `vesselHoldings`, `vesselRows` and `vesselNotes`.

The vessel is **one pool of 20 L**, as the cask and the incubator are: wort waiting, a batch fermenting, or fermented wort, one at a time.

1. **Pour Wort**: pick a container, or All. Only containers holding nothing but wort are offered. Any amount up to 20 L. Not on fermented wort: draw that off first (the row is greyed and says so).
2. **Pitch Yeast** with **one full packet of vanilla Yeast** on you. A part-used packet won't do, as the batch uses the whole packet.

A batch takes all the wort in, any amount. It takes 10 days at the best temperature (18 to 25 C), however full, and gives back 95%, as the lees stay behind. One packet whatever the size.

**Leave headspace.** Yeast needs no air to ferment, so a full vessel works at full speed, but a vigorous batch throws up a head of foam, the krausen. Above the **16 L line**, while the batch is in its first half, the foam climbs out and takes wort with it: up to half of what is above the line, by the working rate (a warm, lively batch loses it all, a cool one less). A brimming 20 L batch at 20 C comes out about 18 L before the lees, 17.1 L of fermented wort; 16 L loses nothing and gives 15.2 L. The window's band says *foaming over* while it happens.

Pitch Yeast is greyed out, and says why, when:
- a batch is already working (and its yeast is fine: see repitching below),
- there is no wort in,
- the wort has soured (use **Pour Away the Wort**),
- the vessel still holds the last batch's fermented wort,
- you carry no full packet of yeast.

**Top Up the Batch**: while a batch works, Pour Wort becomes Top Up the Batch, and the wort goes into the batch, up to 20 L. The batch slows by the new wort's share: 10 L into a 10 L batch half done makes 20 L a quarter done.

**A young batch can't take a big top-up.** More wort than was in before the day's pours (top-ups within 24 hours count together, so ten small pours are one big one, while a little a day is a brewer's step feeding), poured on a batch under half done, is too much for its yeast (Top Up the Batch's hover says so before you pour):
- under 20% done the batch is **underpitched**: it works at half speed until you pitch a fresh packet;
- from 20% to 50% it **lags**: no work for a day for each share added (10 L on 8 L, a day and a quarter), at most 2 days, unless you pitch a fresh packet;
- from 50% the yeast is established, and a top-up only slows it by its share.

While underpitched or lagging, **Pitch Yeast** comes back for the running batch: a fresh packet sets it going at full speed at once.

**Pour Away the Batch** (last in the submenu, while a batch works) asks yes or no first: the yeast is in it, so nothing comes back. Fermented wort is never poured away, only drawn off or pumped.

Waiting wort sours as it does in a bucket; the Fermentation Vessel window says how long it keeps where the vessel stands (*Souring (2d)*), or that it has soured. **Draw Off Wort** takes it back out into empty containers, keeping its age. **Pour Away the Wort** empties it onto the ground.

When the batch finishes, use **Draw Off Fermented Wort**. Only completely empty containers are offered, so nothing is ever topped up into a mixture. A vessel holding anything can't be picked up.

### 8–9. Orléans Vinegar Cask

The cask is one continuous pool of up to **30 L**, not a batch station, so it has no crafting window. Everything is in its right-click **Orléans Vinegar Cask** submenu.

- **Pour Fermented Wort**: pick a container holding nothing but fermented wort. It goes in up to the cask's room, and anything over stays in the container.
- The pool has a **souring** value from 0 to 100%. New fermented wort thins it by its share: 15 L at 100% topped up with 5 L becomes 20 L at 75%.
- Souring takes **35 days** from nothing to 100% at the best temperature (20 to 30 C). A well-kept cask with a mother gives about 21 bottles a month in summer.
- Souring loses about **a tenth of the liquid to the air** (`V.ACETIC_LOSS`, 0.1), so 19 L of fermented wort becomes about 17.2 L of vinegar.
- The culture works on the surface and needs air. Above **22.5 L** it slows, down to half speed when brimming at 30 L.
- **Bottle Vinegar** appears once the pool is 100% soured.

The grey status line reads like `Orléans Vinegar Cask: 9.5 L, 40% soured, about 3 days left, mother established`, or `Orléans Vinegar Cask: 17.2 L, ready to bottle, mother established`. Hover it for the temperature, how fast it's souring, and notes about air and the mother. The time left assumes today's temperature holds.

**Orléans Vinegar Cask Info** (in the submenu) opens on a band with the pool's state, the worst first: *Empty*, *Paused* below freezing, *Ready* (litres and bottles), *Crowded* (amber, above the air line, with its speed), *Souring* (with the mother at work, or the litres, and its speed). Then TP Core's Station block (the cask's outline icon, Place, Season, Working Rate: temperature, mother and air together, Mother: *3 layers, next in 4 L*, Hose: *Vessel Connected*), and the pool as one 30 L tank with the guild's lore beside it: **Souring** while it works (the fermented wort turning to vinegar's brown from the foot by its strength, *62%, 9d* under it, amber while crowded or paused) or **Vinegar** at full strength, the mother's layers floating on top as pale bands, a dashed line at **22.5 L** (the air line). No bubbles: acetic bacteria make no gas. **Bottle Vinegar (n)** sits under the tank once it is ready, the bottle menu under it, and one mother button by the mother's size (`motherButton`): **Add Mother** with none (a living one carried), **Take Mother** at one layer, **Split Mother** from two, greyed with the reason (no empty jar, none carried, a dead one). The right-click keeps Take Mother at any size, to lift a thick mother out whole. Fermented wort dragged onto the tank pours in, as Pour Fermented Wort takes it; the hint warns in amber when the pour would thin a working starter below 25% (`TraditionalPreservationVinegarUI.caskJudge`). Its band, tank and rows are `caskBand`, `caskHoldings`, `caskRows`. It updates while open and closes when you walk more than 6 squares away.

**Empty Cask** pours everything away and keeps the mother.

### 10. Bottling

Right-click the cask, **Orléans Vinegar Cask**, **Bottle Vinegar**:
- **Any Bottle** fills one.
- **All Bottles** fills as many as you have bottles or vinegar for.
- With more than one kind of bottle on you, each kind gets its own row.

It uses empty bottles on you and in containers nearby, and leaves favourited ones alone. The recipe is also in the crafting menu, within two squares of a fully soured cask.

Vanilla Vinegar (`Base.Vinegar2`) holds no liquid, just 10 uses. The vanilla jarring recipe takes 2 uses for a 1 L jar, and a real jar takes about 0.2 L of vinegar, so a use is 0.1 L and **one Vinegar is 1 L**, which is also what most vanilla bottles hold. Any empty bottle of 1 L or more works: vanilla glass bottles of every kind, crafted bottles, and plastic water, pop and milk bottles. Beer bottles hold 0.3 L, so they don't.

What's left after the last whole bottle stays in the cask as starter for the next top-up.

**A gameplay convention, not physics.** Vanilla's Vinegar weighs 0.2, far less than a real litre of liquid (about 1.0 in inventory terms), so 17 bottles carry 17 L for about 3 weight. The mod keeps the output identical to vanilla Vinegar rather than inventing heavier filled bottles, as working with vanilla recipes and other mods comes first. The litre per bottle only sets how much the cask yields; it isn't a claim about what the bottle weighs.

**Bottles come back.** A used-up Vinegar gives its bottle back, as the Salt mod does with shakers. In a hand craft such as pickling, it's the same kind of bottle it was filled into (a Water Bottle comes back as an empty Water Bottle). Used up any other way, for example as a dressing, or for looted vinegar, it leaves an empty Crafted Bottle: vanilla's own replacement can name only one item, and the other bottles spawn full of their drink.

### The hose

A rubber hose can join a vessel to a cask, so fermented wort is pumped across instead of carried in buckets.

- **Attach Hose to Cask** (right-click the vessel): needs an Orléans Vinegar Cask without a hose within **2 squares of the vessel**, on the same floor, a **Rubber Hose** (used up) and **pliers** (kept). Greyed out with the reason otherwise.
- **Pump to Cask** (right-click either station while joined) sends fermented wort across in the amount you pick: **5 L**, **10 L**, **Up to the air line** (fills the cask to 22.5 L, the most it holds at full souring speed) or **All that fits**. Each shows how many litres it would move, and is greyed out with the reason when the vessel hasn't enough or the cask hasn't room. Pumping takes as long as pouring that much by hand, and the cask catches up on its own souring first, so the new wort doesn't count time from before it arrived. Nothing moves on its own: pump when you're there, and top up the Orléans way, a measured amount at a time.
- **Detach Hose** (right-click either station) needs pliers, kept, and gives the hose back.
- Both stations show a grey line naming the other end, and a hose drawn from the vessel's tap and over the cask's rim, coiled on the ground.
- Neither station can be picked up while joined. If either is destroyed, the link ends and the hose drops on the ground.
- Pouring and drawing off by hand still work as usual.

### The Mother of Vinegar

A cask grows its own mother the first time its pool reaches 100%. It doesn't replace yeast: yeast turns sugar into alcohol in the vessel, and the mother turns alcohol into vinegar in the cask.

- **Speed**: a mother makes the cask **25% quicker** (35 days becomes 26), but only while the pool is at least **25% soured**. Fresh wort in an empty cask starts slow and speeds up once it passes 25%. The Orléans rule gets the most from it: **before topping up, keep at least a third as much vinegar in the cask as the fermented wort you're about to add**, so the pool starts over 25%.

  | Kept in the cask | Added | Starts at | Days to 100% at best |
  |---|---|---|---|
  | 0 L | 19 L | 0% | 28.5 |
  | 3 L | 19 L | 14% | 23.7 |
  | 6.5 L | 19 L | 25% | **21.5** |
  | 11 L | 19 L | 37% | 27.2 (too full, short of air) |
  | 3.5 L | 9.5 L | 27% | **19.2** |

  Keeping much more than a third fills the cask past 22.5 L, and the lack of air costs more than the starter gains.
- **Layers**: the mother thickens by a layer for about every **15 L of new vinegar** the cask makes after it forms, roughly one full batch. Its first souring only creates it. The Orléans Vinegar Cask window shows its layers and how many litres until the next.
- **Take Mother**: lifts the whole mother into an empty jar (Empty Jar or Crafted Jar). The cask loses its speed.
- **Split Mother**: once it has 2 layers or more, peels one off into an empty jar and leaves the rest in the cask. Use it to start a second cask. Before then it shows greyed out, and hovering it, or the Orléans Vinegar Cask window, says how much more vinegar the next layer needs.
- **Add Mother**: lays a living mother from its jar into a cask that has none, and gives the jar back.
- **In the jar** a mother is like food: fresh for about 30 days, dead at 40. A fridge slows it down, as it does for food. A dead mother can't be added.

The mother only grows as fast as you make vinegar, so it can't be farmed. Splitting just lets a second cask start at full speed.

The mother also travels with its cask: pick up an empty cask and put it down elsewhere, and the mother is still in it.

## What the stations show

| Malting Floor | When | What you see |
|---|---|---|
| Empty | Nothing on it | A bare wooden tray |
| Steeped | Just spread | Dark, wet grain |
| Sprouting | First half of the 5 days | Paler grain with a few sprouts |
| Rootlets | Second half | Pale rootlets matting the grain together |
| Finished | Done, until taken off | Thick rootlets, and a wooden malt shovel on the bed |

The tray shows one look: the stage most heaps are at, a tie going to the one further on.

| Vessel | When | What you see |
|---|---|---|
| Empty | Nothing in it | Clean lid, still water in the jar |
| Filled | Wort in the tank, not started | A wet ring round the bung |
| Bubbling | First 70% of a run | Foam round the bung, bubbles in the jar |
| Sediment | Last 30% of a run | Foam dropped to a crust, a cloudy sample cup under the tap |
| Finished | Fermented wort waiting | A clear sample cup with lees in it, and a chalk cross on the staves |

| Cask | When | What you see |
|---|---|---|
| Empty | No mother | Open top, dark inside |
| Fresh | Wort just poured in, no mother | Amber liquid under a slate cloth |
| Film | Souring, no mother | A pale film spreading in three steps as it sours |
| Skin | Souring, with a mother | A whole skin, as the mother covers the surface |
| Ready | 100% soured | A whole skin, with three bottles at the foot of the cask |
| Mother at rest | Empty, with a mother | Cloth on, and a pale skin low in the cask |

## Right-click menus

- **Fermentation Vessel**: a grey status line (empty, wort waiting, wort soured, fermenting with its progress, or fermented wort ready), **Pour Wort** (greyed with "Sour wort won't ferment" when all you carry is sour), **Pour Away the Wort** when the tank holds some, and **Draw Off Fermented Wort** when there is some. Options you can't use yet are greyed out, and hovering says why.
- **Orléans Vinegar Cask Info**: one submenu with the status line, **Orléans Vinegar Cask**, **Pour Fermented Wort**, **Bottle Vinegar**, **Take Mother** / **Split Mother** / **Add Mother**, **Empty Cask**, and the hose line and **Detach Hose** when joined.
- **Hose** (on the vessel): **Attach Hose to Cask**, or a grey line and **Detach Hose** when joined.

## Picking stations up

A station can break when picked up, so:
- a **cask** holding liquid can't be picked up,
- a **vessel** with anything in either tank, or a batch running, can't be picked up,
- neither can be picked up while a hose joins them.

The pick-up cursor shows vanilla's red "Has items in container" line. Bottle, draw off or empty first. An empty cask keeps its mother when moved.

## Temperature and places

Time counts by the game clock, at any Day Length, and keeps counting while the area is unloaded. The rate follows the temperature where each station stands, recorded every 10 in-game minutes.

| | Very slow (5%) | Slower | Best | Still working | Falling away |
|---|---|---|---|---|---|
| Malting Floor | below 5 C | 5–12 C | 12–20 C | | above 20 C, 5% by 33 C |
| Vessel | below 10 C | 10–18 C | 18–25 C | 25–30 C (85% or more) | above 30 C, 10% by 40 C |
| Cask | below 10 C | 10–20 C | 20–30 C | | above 30 C, 25% by 40 C |

**Frozen work waits.** The malting floor stops at 0 C and below, the vessel and the cask at -3 C and below (a brew freezes a little under water): nothing is killed, the batch picks up where it stopped when it thaws, and the window says *Paused here (frozen)*. Temperature sensitivity Off ignores it.

The places are TP Core's, from the game's own flags:

- **Open air** and **under an open roof** (a porch, an open shed): the weather, hour by hour.
- **Indoors** (a shut room: every window to the outside shut or boarded): an unheated room follows the average of the last 3 days, 2 C warmer in the cold months and up to 2 C warmer in summer (stuffy). A room is **22 C while the power grid is on**, as vanilla's are.
- **Aired room** (a room with a window to the outside open, smashed, without its glass or an empty frame): the day's average, at most 1 C warmer in winter; 22 C while the power grid is on.
- **In a basement** (any level below ground): the earth takes the edge off the seasons, running a month behind the season: about 5 C from January to March and 13 C from July to September. Cooler than a room until August, warmer in the autumn (a September vessel ferments in 16 to 20 days there), and under 10 C from December to May.
- **By a fire**: any lit fire within 2 tiles on the same floor holds a station in a shut room at **28 C** (banked embers 24 C) for as long as the fuel lasts: the vessel takes 11 days and a fresh cask 35, in any month. Too warm for malting (14 days instead of 5). With a window open or outside, the air carries the heat off: in an aired room or under an open roof the fire gives the air +15 C, in the open +10 C, never past 28 C (banked embers +10 and +5, up to 24 C).

That gives the year a shape: malt in spring or autumn, brew and sour indoors from May to August, and keep a cask going through winter by an indoor fire. A batch that runs into the cold waits under 10 C until it warms again, and stops altogether once it freezes.

Hover a running batch in the floor's window for its progress, time left at today's temperature, the temperature and place, and its working rate.

These are the days a run takes by the month it starts, on the game's sampled weather for default settings, the grid off (`tools/season_report.lua`).

| Month | Ferment, open air | Ferment, indoors (shut room) | Ferment, aired room | Ferment, basement | Cask from fresh, open air | Cask from fresh, indoors (shut room) | Cask from fresh, aired room | Cask from fresh, basement |
|---|---|---|---|---|---|---|---|---|
| Jan | 87–117 | 89–121 | 89–120 | 130–156 | 127–157 | 127–155 | 127–156 | 185–211 |
| Feb | 58–88 | 61–93 | 61–93 | 104–130 | 98–128 | 98–126 | 98–127 | 157–184 |
| Mar | 34–60 | 34–66 | 35–65 | 77–103 | 71–98 | 69–98 | 70–98 | 130–157 |
| Apr | 16–36 | 15–38 | 15–38 | 50–76 | 50–72 | 46–70 | 48–70 | 102–129 |
| May | 11–18 | 10–16 | 10–17 | 23–50 | 41–51 | 37–47 | 38–48 | 75–104 |
| Jun | 11–12 | 10 | 10–11 | 17–23 | 39–43 | 36–38 | 36–39 | 66–75 |
| Jul | 10–14 | 10–11 | 10–12 | 15–18 | 40–54 | 35–43 | 37–48 | 63–67 |
| Aug | 11–17 | 10–12 | 10–13 | 15–16 | 48–239 | 40–230 | 42–238 | 67–151 |
| Sep | 11–137 | 10–93 | 10–146 | 16–20 | 236–241 | 231–236 | 237–241 | 161–265 |
| Oct | 139–175 | 100–185 | 148–185 | 20–143 | 215–236 | 212–233 | 214–236 | 262–266 |
| Nov | 142–168 | 145–171 | 146–170 | 150–200 | 186–214 | 184–211 | 186–213 | 239–262 |
| Dec | 115–141 | 117–144 | 118–146 | 156–181 | 157–185 | 156–183 | 156–185 | 212–238 |

While the grid is on, any room (22 C) ferments in 10 days and sours a fresh cask in 35, any month. By a fire in a shut room (28 C): 11 and 35, malting 14; by banked embers (24 C): 10 and 35, malting 7. A shut room no longer keeps the summer into autumn: a September ferment there takes 10 to 93 days, so from September brew by the fire or in the basement.

By a fire outside, the same days for malting, fermenting and a fresh cask:

| Month | Malting, fire under a roof | Malting, fire in the open | Ferment, fire under a roof | Ferment, fire in the open | Cask, fire under a roof | Cask, fire in the open |
|---|---|---|---|---|---|---|
| Jan | 5–9 | 7–16 | 17–29 | 29–56 | 53–75 | 77–105 |
| Feb | 5–8 | 6–14 | 12–23 | 20–38 | 44–58 | 58–82 |
| Mar | 5–7 | 5–9 | 10–15 | 12–22 | 37–45 | 42–58 |
| Apr | 5–10 | 5–7 | 10–11 | 11–14 | 35–38 | 36–44 |
| May | 10–14 | 6–12 | 11 | 10–11 | 35 | 35–36 |
| Jun | 13–14 | 9–12 | 11 | 11 | 35 | 35 |
| Jul | 12–14 | 9–14 | 11 | 10–11 | 35 | 35 |
| Aug | 11–14 | 7–12 | 11 | 10–11 | 35 | 35–38 |
| Sep | 7–13 | 6–11 | 11 | 10–12 | 35–39 | 38–83 |
| Oct | 6–7 | 5–6 | 11–13 | 12–22 | 40–74 | 85–138 |
| Nov | 5–7 | 6–14 | 14–28 | 26–66 | 78–90 | 126–138 |
| Dec | 5–9 | 8–17 | 19–26 | 50–66 | 72–82 | 103–125 |

A porch fire is the winter malting floor: the cold air takes the fire down to the grain's 12 to 20 C.

## Skills

| Step | XP |
|---|---|
| Steep Grain | Cooking 3 |
| Mash Malt | Cooking 3 |
| Strain Mash | Cooking 3 |
| A finished vessel run | Cooking 10 |
| A finished malting run | Farming 5 |
| Each bottle of vinegar | Cooking 1 |
| Build a Malting Floor | Carpentry 10 |
| Build a Fermentation Vessel | Carpentry 15 |
| Build an Orléans Vinegar Cask | Carpentry 20 |

Station runs pay out when they finish, so cancelling and restarting gives nothing.

## Sandbox options

Under Traditional Preservation (Vinegar):

| Option | Default | What it does |
|---|---|---|
| Malting (days) | 5 | Malting Floor time at the best temperature |
| Alcoholic fermentation (days) | 10 | Vessel time at the best temperature |
| Acetic fermentation (days) | 35 | Cask time from fresh to fully soured, without a mother |
| Established-culture speed bonus (percent) | 25 | How much quicker a mother with a starter makes the cask |
| Temperature sensitivity | Normal | Off, Forgiving, Normal or Harsh |
| Brewing effort | Normal | How long the hands-on work takes, below |
| Wort sours | On | Wort waiting for the yeast sours (2 days at 20 C); off, it keeps for ever |

| Brewing effort | Light | Normal | Hard |
|---|---|---|---|
| Multiplier | ×1 | ×1.5 | ×2 |
| Kiln Green Malt | 2 hours | 3 hours | 4 hours |
| Heat the mash | 1 hour | 1.5 hours | 2 hours |
| Steep Grain, Mash Malt, Strain Mash crafts | 120, 300, 200 | 180, 450, 300 | 240, 600, 400 |

Steeping water stays 4 L at every level.

## Tuning

Times, volumes, yields, temperature curves, the cask and mother rules, XP and the effort multipliers are at the top of `42/media/lua/shared/TraditionalPreservationVinegar.lua`. Grain and water amounts are in `42/media/scripts/TraditionalPreservationVinegar.txt`, and the liquids in `42/media/scripts/TraditionalPreservationVinegar_fluids.txt`.

`tools/build_tileset.py` repaints the stations and overlays, writes the item icons and textures from vanilla art, and writes `42/media/scripts/TraditionalPreservationVinegar_items.txt` (needs Pillow and the game files). It also writes the generated `42/media/lua/shared/TraditionalPreservationVinegar/Tiles.lua`, the tile numbers the Lua reads (don't edit it by hand), and `luajit tests/test_tiles.lua` checks the entity scripts against it. `luajit tests/test_vinegar.lua` checks the rules, `luajit tests/test_world.lua` the sprites, `luajit tests/test_stations.lua` the world file and the batch popup on stand-ins for the engine, `luajit tests/test_scripts.lua` the scripts against the game's (every grain steeps, every item named exists), `luajit tests/test_console.lua` the debug commands, `luajit tools/season_report.lua` prints the season table, and `luajit tools/simulate.lua` plays two full batches hour by hour with real timers and the game's weather, from the malting floor to bottling, starting in January, April, July and October outdoors, indoors and in a basement, and checks the litres in against the litres out (40 L of wort gives about 31 L of vinegar).

In debug mode, right-clicking any liquid container in your inventory offers **[Debug] Fill with Wort** and **[Debug] Fill with Fermented Wort**, since liquids can't be spawned from the item list.

## Realism notes for review

The real-world claims the design rests on, and the simplifications made for play. Each is worth checking.

**Claims taken as real practice**
1. English malt vinegar ("alegar") was made by souring an unhopped ale brewed from malted barley.
2. Malting is steeping grain (a day or two), germinating it on a floor (about 4–6 days in total with the steep), then kilning it to stop growth and dry it. Floor malting was cool-season work, best around 12–20 C.
3. Malt keeps for a long time once kilned and dry.
4. Mashing holds crushed malt in hot water for about an hour, so the malt's enzymes turn starch into sugar. Straining (lautering) separates the sweet wort from the spent grain.
5. Spent grain is used as livestock feed and compost.
6. Ale yeast ferments wort into a weak alcohol best at about 18–25 C, in roughly 1–2 weeks, leaving yeast sediment (lees). Unhopped wort ferments to roughly 4% alcohol.
7. A yeast pitch for about 20 L is in the order of one packet of dried yeast.
8. Acetic bacteria turn alcohol into acetic acid best at about 20–30 C. They need oxygen and work at the surface, so vinegar barrels were left part-full (about three quarters) with air holes, covered against insects.
9. The Orléans method: draw off part of the finished vinegar and add new wine or ale under the mother, never emptying the barrel. The vinegar left behind acts as a starter, protecting and speeding the next lot.
10. The mother of vinegar is a cellulose mat made by the bacteria, floating on the surface, that thickens over time and can be divided and passed on to start other barrels. Out of the barrel it doesn't keep indefinitely.
11. Souring a batch in a barrel takes weeks, around a month in good conditions. Some volume is lost to evaporation over that time.
12. Coopers' barrels were bound with wooden hoops (split saplings, often willow or hazel) before iron hoops. Twine here stands in for that binding.
13. A cellar or basement stays near the year's average temperature, about 14–16 C in a Kentucky climate, with little seasonal swing.
14. Vinegar for pickling is used at roughly 0.2 L per 1 L jar.

**Simplifications made for play**
- Crushing the malt is folded into Mash Malt, and steeping into the Malting Floor's time.
- 24 seeds per bucket, about 0.5 kg of grain for 10 L, is a much weaker wort than a real one (roughly 1–2 kg per 10 L). It was chosen so a batch needs about 15 barley plants, one per bottle.
- A whole yeast packet per batch, whatever its size.
- Fermentation yields 95% by volume (lees), and souring loses about a tenth overall.
- Wort sours on one curve (2 days at 20 C, 1 at 30 C, about 5 at 13 C, stopped at 0 C) and goes straight to Wort (Soured); real wild souring varies with the grain and the vessel, and spoils further into mould, which is left out.
- The mother grows one layer per 15 L of vinegar made, and a split always gives one layer.
- The mother speeds a cask by 25% only while the pool is at least 25% soured.
- The cask slows above 22.5 L of 30 L (three quarters), down to half speed when full.
- One vanilla Vinegar counts as 1 L (10 uses at 0.1 L each, from the jarring recipe), although vanilla gives it the weight of about 0.2 L. That mismatch is accepted so the output stays exactly vanilla.
- A room or an open roof uses the 10-day mean temperature (22 C while the grid is on); a basement follows the ground (the 10-day mean's own 30-day mean, a month behind) two fifths as far from 10 C. Room heating isn't modelled beyond a fire within 2 tiles.
- No heat harm: the sampled climate never passes 35 C.
- Hops, boiling the wort, and clarifying or pasteurising the vinegar are left out.
- Barley, wheat and rye are interchangeable.

## Engineering notes

- The vessel has no crafting window: its one pool is its record in its `movableData` (`tpvVessel`, `TraditionalPreservationVinegarVessel.lua`; `wortMl`, `run` or `fermentedMl`, one in use at a time), stepped by the World. Foam: `V.HEADSPACE_ML`, `V.FOAM_LOSS` of `run.overMl` (above the line at the pitch or last top-up) over the first `V.VIGOROUS` of the work, by the working rate. A top-up on a young batch: `V.topUp` sets `run.underpitched` (`V.UNDERPITCH_RATE`) or `run.lagUntil` (`V.LAG_HOURS` a share added, `V.LAG_MAX_HOURS`), `V.pitch` repitches. The batch's work is a FluidAgeing age on the alcoholic ledger, as the floor's heaps are on the malting one.
- The waiting wort's age: the vessel is not an item, so FluidAgeing can't keep a record on it. The record sits on the vessel's record under FluidAgeing's key (`V.ageTank`), the tank's wort is never renamed (the tank only takes wort), and the vessel checks the record instead (`V.isSour`). Wort drawn off takes the age with it.
- The cask's pool, souring, mother and layers live in the cask's `movableData`, which vanilla copies onto the item when a station is picked up and back when it's placed. So the mother moves with the cask and can't be duplicated.
- Weather is kept as running totals in global ModData, per stage and place, so stations catch up exactly when their area loads again.
- Station sprites are layered by the mod rather than with `SpriteOverlayConfig`, which can only show one overlay for a first batch.
- The shared core (weather, places, station tracking, popups) is the required TP Core mod (id `TraditionalPreservationCore`), loaded as `require "TraditionalPreservationCore/Weather"`. Edit it there. The rate curves, heat damage, the cask, the hose and the old-save migrations stay in this mod's own files.

## Debug commands

In debug mode, `TPV.help()` in the Lua console lists commands for testing this mod. They are described in `DEVHELP.md`.

## Known prototype caveats

- **Temperature hasn't been seen in play.** The in-game runs so far used test timers (`TPV.fast`), which ignore temperature. Check a cold and a hot month with real timers before relying on the season table.
- A room is warmed only by the power grid (22 C, as vanilla keeps it) or a fire within 2 tiles; a generator or a heater doesn't change a station's temperature.
- Mash Malt takes a metal bucket, plain or forged (not a wooden one), and Strain Mash gives back the kind that went in.
- The bottle list is written out, as no tag covers plastic bottles, so bottles from other mods aren't accepted.
- Apples, grapes and other fruit aren't used, as vanilla can't grow apples or grapes.
- The pick-up cursor is wrapped through TP Core (`UI.keepInPlace`), so compare it with vanilla after a game update.
- The tiledef number 5130 must be unique among your active mods.
- Multiplayer is not supported. This mod is singleplayer only for now.

## Test plan

Already passed in the game with test timers: building all three stations; Steep Grain, the floor, kilning, Mash Malt, heating, Strain Mash and the wort it gives; the vessel's tanks, yeast slot, 1-bucket and 2-bucket runs, its Craft refusals and lossless cancel; drawing off; the cask's pool, souring, finishing, mother, bottling menu, topping up and its pick-up block; the mother jar (take, add). Offline: the rules, sprites, places, effort levels and a world load on a headless server.

Still to check in the game:

1. Twine in both station recipes.
2. Brewing effort: kiln and mash heat take 3 and 1.5 hours at Normal, and change with Light and Hard.
3. Splitting a two-layer mother; a dead mother refused.
4. A full vessel and a running vessel refuse to be picked up, with the red line.
5. Spent Grain eaten from a trough, and taken by the composter.
6. Wort refuses to mix with another drink in a vanilla container.
7. "(Basement)" and its temperature on a station below ground; "(By a fire)" at 28 C within 2 tiles of a lit fire indoors, "(By a fire, under a roof)" and "(By a fire, in the open)" outside; *Paused here (frozen)* on a vessel or cask at -3 C and below.
8. A run with real timers and temperature on, in a cold month and a hot month, indoors, outdoors, in a basement and by a fire.
9. The hose: attach; Pump to Cask from both stations, with 5 L, 10 L, the air line and all that fits each moving what it says; greyed options giving their reasons (empty vessel, short tank, no room, already at the air line); detach; and a destroyed station dropping the hose.
10. The Orléans Vinegar Cask window: opens from the cask's submenu, fills its bars, counts down while souring, shows bottles once ready and the hose when joined, and closes past 6 squares or when the cask is picked up.
11. Green Malt: fresh for 2 days and rotten after 5. Stale Green Malt still kilns into Malt; rotten Green Malt stays rotten on the fire, and the composter takes it.
12. Wort that sours: `TPV.ageWort(48)` turns carried wort into Wort (Soured) and the tank's wort to soured; Craft refuses with the reason, Pour Wort is greyed with "Sour wort won't ferment", Pour Away the Wort empties the tank; the info block's "sours in about"; a cancelled run gives back wort with its age.
13. `console.txt` shows no repeating Lua errors after an hour of play, including with the other Traditional Preservation mods on.
