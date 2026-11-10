# Traditional Preservation (Vinegar) — Build 42 prototype (v0.2.6)

**Status: experimental.** The whole chain, from steeped grain to bottled vinegar, has been played in the game with test timers. Temperature effects have only been checked offline so far (see the test plan). Back up your save before enabling.

Make your own malt vinegar from grain you grow. It ends in the same vanilla Vinegar you find in kitchens, so it works in every vanilla recipe, including pickling. It's built for long playthroughs, after the looted vinegar has run out. Together with Traditional Preservation (Yeast) and (Salt), the whole pickling pantry becomes renewable.

## History

Vinegar is what alcohol becomes when it meets air. English malt vinegar, once called alegar, began as soured ale made from malted barley. Yeast can't eat the starch in grain, so grain is first sprouted to make the enzymes that turn starch into sugar, then dried to stop it, and later soaked hot to do that work. The sweet liquid strained off, the wort, is fermented by yeast into a weak ale.

The ale was then soured by the **Orléans method**, used in France since the Middle Ages. A barrel is kept about three quarters full, with air holes above the liquid, and a pale skin, the mother, floats on top. Every week or two some vinegar is drawn off from the bottom and the same amount of new ale is poured in under the mother. The barrel is never emptied: what stays behind is the starter that keeps the next lot sour and safe. A thick mother can have a layer peeled off and passed to another barrel.

## Install

Copy this folder to `~/Zomboid/mods/TraditionalPreservationVinegar`, as a real copy rather than a symlink. It needs no other mods.

## Getting started

1. **Grow barley, wheat or rye.** Sow from August to October, dry the sheaves on a drying rack and thresh them. Threshed grain doesn't spoil, so one harvest lasts all year. A full batch takes 48 grain, about 16 plants at base yield.
2. **Malt in autumn, or any time in a basement.** Malt keeps forever, so make it once and brew from it all year.
3. **Keep yeast to hand.** Each vessel run takes one full packet of vanilla Yeast. Traditional Preservation (Yeast) can make more.
4. **Brew and sour from spring to early autumn, under a roof.** Or below ground, where it carries on slowly through winter.
5. **Save your empty bottles and jars.** Each Vinegar uses up one bottle, and a Mother of Vinegar lives in a jar.
6. **Never empty the cask.** Before topping up, keep at least a third as much vinegar in the cask as the fermented wort you're about to add: about 6–7 L before a full batch, 3–4 L before a half batch. Then the mother's speed bonus works from the start.

From threshed grain, the first vinegar takes about 55 to 60 days in good weather. After that, a cask that is kept topped up gives more every week or so.

## The chain at a glance

| # | Step | Where | In | Out | Time |
|---|---|---|---|---|---|
| 1 | Steep Grain | Crafting menu | 24 grain, 4 L water | Steeped Grain | a craft |
| 2 | Malt Grain | Malting Floor | up to 4 Steeped Grain | Green Malt (rots in 5 days) | 5 days |
| 3 | Kiln | Fire or oven | Green Malt | Malt (keeps forever) | 3 hours* |
| 4 | Mash Malt | Crafting menu | 1 Malt, a metal bucket with 10 L water | Bucket of Mash | a craft |
| 5 | Heat the mash | Fire or oven | Bucket of Mash | Bucket of Prepared Mash | 1.5 hours* |
| 6 | Strain Mash | Crafting menu | Prepared Mash, a cloth (kept) | 10 L Wort in the bucket, Spent Grain | a craft |
| 7 | Ferment Wort | Fermentation Vessel | 10 or 20 L Wort, 1 packet of Yeast | 95% as Fermented Wort | 10 days |
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
| Vinegar | about 15.5 L, which is 15 bottles |
| Pickling | about 75 jars |

## Stations

All three are under Furniture in the Build menu, need a hammer (kept) and have two facings. The twine stands in for the hoops coopers once bound from saplings, so everything here can be made again from what you grow and forage.

| Station | Skill | Materials |
|---|---|---|
| **Malting Floor** | Carpentry 2 | 6 planks, 8 nails |
| **Fermentation Vessel** | Carpentry 3 | 8 planks, 12 nails, 4 twine, 1 jar (the clear airlock on its side) |
| **Orléans Vinegar Cask** | Carpentry 4 | 10 planks, 16 nails, 6 twine, 1 cloth (Ripped Sheet, Burlap Piece or Cheesecloth) |

Twine is renewable in vanilla: twist it from Dogbane, scutched hemp, flax tow or sinew.

## How it works

### 1. Steep Grain

Crafting menu, Cooking. 24 barley, wheat or rye seeds and 4 L of water from any container (the container is kept) give one **Steeped Grain**, enough for one bucket of wort. The real day or two of soaking is part of the Malting Floor's time.

### 2. Malting Floor

Open the floor, load up to 4 Steeped Grain and press **Craft**. It sprouts into **Green Malt** in 5 days at the best temperature (12 to 20 C). The floor takes only Steeped Grain and says why when you try anything else.

### 3. Kiln

Put the Green Malt on a lit fire or in an oven. It dries into **Malt** in about 3 hours at Normal effort, and burns if left for a day. Malt keeps forever. Green Malt is food as far as the game is concerned, so it cooks like food, but nobody can eat it.

Green Malt doesn't wait: real sprouted grain keeps growing and then moulds unless it is kilned. It stays fresh for 2 days and is rotten after 5, counting from when the floor finishes, so collect it and kiln it soon. Stale Green Malt still kilns into good Malt. Rotten Green Malt doesn't: the game skips its change into Malt, so it stays rotten Green Malt on the fire. Put it in a composter instead.

### 4. Mash Malt

Crafting menu, Cooking. 1 Malt and a metal bucket holding 10 L of water give a **Bucket of Mash**. Crushing the malt is folded into this step.

### 5. Heat the mash

Put the Bucket of Mash on a fire or in an oven. In about 1.5 hours at Normal effort it becomes a **Bucket of Prepared Mash**, as the heat turns the starch to sugar.

### 6. Strain Mash

Crafting menu, Cooking, with a Ripped Sheet or Cheesecloth (kept). The bucket comes back holding **10 L of Wort**, and the grain left in the cloth is **Spent Grain**.

Wort and Fermented Wort are real liquids, added by this mod, not vanilla ones. They sit in any vanilla container: buckets, bottles, pots, mugs. Both are drinkable: wort is sweet and filling, and fermented wort is a weak, flat, unhopped ale (4% alcohol) that leaves you a little less happy than a proper beer would. Neither mixes with any other liquid, so a container of wort stays pure.

**Spent Grain** weighs 0.8: a bucket's 24 grain weigh about 0.5 dry and soak up water in the mash. It rots in about 3 to 6 days. Put it in a composter, or feed it to farm animals from a trough: cows, sheep, pigs, chickens and turkeys all eat it.

### 7. Fermentation Vessel

The vessel's window has a slot for yeast and two tanks: **Wort** on the left and **Fermented** on the right.

1. Right-click the vessel and use **Pour Wort**. Pick a container, or All. Only containers holding nothing but wort are offered.
2. Put **one full packet of vanilla Yeast** in the slot. A part-used packet is refused, as the run uses the whole packet.
3. Press **Craft** on **Ferment Wort**.

A run takes whole buckets from the tank: **10 L** with one bucket's worth in, **20 L** with two. Anything over a whole bucket stays in the tank for later. It takes 10 days at the best temperature (18 to 25 C) and gives back 95%, so 9.5 or 19 L, as the lees stay behind. One packet either way, so two buckets is the efficient run and one bucket the quick one.

Craft won't start, and says why, when:
- the vessel is already working,
- there is less than 10 L of wort in the tank,
- the Fermented tank still holds the last batch.

When a run starts, its wort leaves the Wort tank and is held by the run, so the tank reads empty while it ferments. The status line and the batch's hover show how many litres are fermenting.

**Cancel** stops the run and gives everything back: the wort to the tank and the yeast to the slot.

When it finishes, right-click and use **Draw Off Fermented Wort**. Only completely empty containers are offered, so nothing is ever topped up into a mixture.

### 8–9. Orléans Vinegar Cask

The cask is one continuous pool of up to **30 L**, not a batch station, so it has no crafting window. Everything is in its right-click **Orléans Vinegar Cask** submenu.

- **Pour Fermented Wort**: pick a container holding nothing but fermented wort. It goes in up to the cask's room, and anything over stays in the container.
- The pool has a **souring** value from 0 to 100%. New fermented wort thins it by its share: 15 L at 100% topped up with 5 L becomes 20 L at 75%.
- Souring takes **35 days** from nothing to 100% at the best temperature (20 to 30 C). A well-kept cask with a mother gives about 21 bottles a month in summer.
- Souring loses about **a fifth of the liquid to the air**, so 19 L of fermented wort becomes about 15.5 L of vinegar.
- The culture works on the surface and needs air. Above **22.5 L** it slows, down to half speed when brimming at 30 L.
- **Bottle Vinegar** appears once the pool is 100% soured.

The grey status line reads like `Orléans Vinegar Cask: 9.5 L, 40% soured, about 3 days left, mother established`, or `Orléans Vinegar Cask: 15.5 L, ready to bottle, mother established`. Hover it for the temperature, how fast it's souring, and notes about air and the mother. The time left assumes today's temperature holds.

**Cask Info** (in the submenu, or just click the cask) opens a small window with the same facts laid out: a bar for how full the cask is and one for its souring, the time left, bottles ready, the temperature and place, the working rate (temperature, mother and air together), the mother's layers and the hose. It updates while open and closes when you walk more than 6 squares away.

**Empty Cask** pours everything away and keeps the mother.

### 10. Bottling

Right-click the cask, **Orléans Vinegar Cask**, **Bottle Vinegar**:
- **Any Bottle** fills one.
- **All Bottles** fills as many as you have bottles or vinegar for.
- With more than one kind of bottle on you, each kind gets its own row.

It uses empty bottles on you and in containers nearby, and leaves favourited ones alone. The recipe is also in the crafting menu, within two squares of a fully soured cask.

Vanilla Vinegar (`Base.Vinegar2`) holds no liquid, just 10 uses. The vanilla jarring recipe takes 2 uses for a 1 L jar, and a real jar takes about 0.2 L of vinegar, so a use is 0.1 L and **one Vinegar is 1 L**, which is also what most vanilla bottles hold. Any empty bottle of 1 L or more works: vanilla glass bottles of every kind, crafted bottles, and plastic water, pop and milk bottles. Beer bottles hold 0.3 L, so they don't.

What's left after the last whole bottle stays in the cask as starter for the next top-up.

**A gameplay convention, not physics.** Vanilla's Vinegar weighs 0.2, far less than a real litre of liquid (about 1.0 in inventory terms), so 15 bottles carry 15 L for about 3 weight. The mod keeps the output identical to vanilla Vinegar rather than inventing heavier filled bottles, as working with vanilla recipes and other mods comes first. The litre per bottle only sets how much the cask yields; it isn't a claim about what the bottle weighs.

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
  | 6.5 L | 19 L | 26% | **21.5** |
  | 11 L | 19 L | 37% | 27.1 (too full, short of air) |
  | 3.5 L | 9.5 L | 27% | **19.2** |

  Keeping much more than a third fills the cask past 22.5 L, and the lack of air costs more than the starter gains.
- **Layers**: the mother thickens by a layer for about every **15 L of new vinegar** the cask makes after it forms, roughly one full batch. Its first souring only creates it. Cask Info shows its layers and how many litres until the next.
- **Take Mother**: lifts the whole mother into an empty jar (Empty Jar or Crafted Jar). The cask loses its speed.
- **Split Mother**: once it has 2 layers or more, peels one off into an empty jar and leaves the rest in the cask. Use it to start a second cask. Before then it shows greyed out, and hovering it, or Cask Info, says how much more vinegar the next layer needs.
- **Add Mother**: lays a living mother from its jar into a cask that has none, and gives the jar back.
- **In the jar** a mother is like food: fresh for about 30 days, dead at 40. A fridge slows it down, as it does for food. A dead mother can't be added.

The mother only grows as fast as you make vinegar, so it can't be farmed. Splitting just lets a second cask start at full speed.

The mother also travels with its cask: pick up an empty cask and put it down elsewhere, and the mother is still in it.

## What the stations show

| Malting Floor | When | What you see |
|---|---|---|
| Empty | Nothing in it | A bare wooden tray |
| Steeped | Loaded, not started | Dark, wet grain |
| Sprouting | First half of the run | Paler grain with a few sprouts |
| Rootlets | Second half of the run | Pale rootlets matting the grain together |
| Finished | Until collected | Thick rootlets, and a wooden malt shovel on the bed |

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

- **Fermentation Vessel**: a grey status line (empty, wort waiting, fermenting with its progress, or fermented wort ready), **Pour Wort**, and **Draw Off Fermented Wort** when there is some. Options you can't use yet are greyed out, and hovering says why.
- **Orléans Vinegar Cask**: one submenu with the status line, **Cask Info**, **Pour Fermented Wort**, **Bottle Vinegar**, **Take Mother** / **Split Mother** / **Add Mother**, **Empty Cask**, and the hose line and **Detach Hose** when joined.
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

There are three kinds of place, from the game's own flags:

- **Outdoors**: the day's weather. Above 35 C an outdoor vessel loses 1% of its batch an hour, up to 25%.
- **Under a roof** (indoors on the ground floor or above): a building evens out the weather, so it follows the average outdoor temperature of the last 10 days or so, plus 10 C, and never goes above 28 C. A warm afternoon or a cold night makes no difference. A roofed vessel never overheats.
- **In a basement** (any level below ground): the earth holds it at **15 C all year**. Malting runs at full speed in any month. The vessel takes about 13 days and the cask about 54 (40 with a mother and starter), summer or winter.

That gives the year a shape: malt in a cool season or a basement, brew and sour in a warm room from spring to autumn, and keep going slowly below ground through winter.

Hover a running batch in the floor's window for its progress, time left at today's temperature, the temperature and place, its working rate and any heat damage.

These are the days a run takes by the month it starts, on the game's forecasts for default weather (`tools/season_report.lua`). A basement takes the same in every month.

| Month | Ferment, outdoors | Ferment, under a roof | Cask from fresh, outdoors | Cask from fresh, under a roof |
|---|---|---|---|---|
| Jan | 106–140 | 68–112 | 160–198 | 110–153 |
| Feb | 70–112 | 18–76 | 123–162 | 73–116 |
| Mar | 39–76 | 10–40 | 88–126 | 44–76 |
| Apr | 22–44 | 10–17 | 59–89 | 35–49 |
| May | 12–22 | 10–11 | 44–60 | 35–38 |
| Jun | 11–15 | 10–11 | 39–46 | 35 |
| Jul | 10–12 | 10–11 | 39–47 | 35 |
| Aug | 10–17 | 10–11 | 45–86 | 35 |
| Sep | 11–30 | 10–11 | 88–287 | 35–39 |
| Oct | 29–157 | 10–17 | 269–290 | 37–194 |
| Nov | 157–178 | 10–140 | 235–268 | 182–206 |
| Dec | 136–162 | 86–119 | 197–234 | 148–182 |

## Skills

| Step | XP |
|---|---|
| Steep Grain | Cooking 2 |
| Mash Malt | Cooking 3 |
| Strain Mash | Cooking 3 |
| A finished vessel run | Cooking 10 |
| A finished malting run | Farming 5 |
| Each bottle of vinegar | Cooking 1 |

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

| Brewing effort | Light | Normal | Hard |
|---|---|---|---|
| Multiplier | ×1 | ×1.5 | ×2 |
| Kiln Green Malt | 2 hours | 3 hours | 4 hours |
| Heat the mash | 1 hour | 1.5 hours | 2 hours |
| Steep Grain, Mash Malt, Strain Mash crafts | 120, 300, 200 | 180, 450, 300 | 240, 600, 400 |

Steeping water stays 4 L at every level.

## Tuning

Times, volumes, yields, temperature curves, the cask and mother rules, XP and the effort multipliers are at the top of `42/media/lua/shared/TraditionalPreservationVinegar.lua`. Grain and water amounts are in `42/media/scripts/TraditionalPreservationVinegar.txt`, and the liquids in `42/media/scripts/TraditionalPreservationVinegar_fluids.txt`.

`tools/build_tileset.py` repaints the stations and overlays, writes the item icons and textures from vanilla art, and writes `42/media/scripts/TraditionalPreservationVinegar_items.txt` (needs Pillow and the game files). It also writes the generated `42/media/lua/shared/TraditionalPreservationVinegar/Tiles.lua`, the tile numbers the Lua reads (don't edit it by hand), and `luajit tests/test_tiles.lua` checks the entity scripts against it. `luajit tests/test_vinegar.lua` checks the rules, `luajit tests/test_world.lua` the sprites, `luajit tests/test_stations.lua` the world file and the batch popup on stand-ins for the engine, `luajit tests/test_scripts.lua` the scripts against the game's (every grain steeps, every item named exists), `luajit tools/season_report.lua` prints the season table, and `luajit tools/simulate.lua` plays two full batches hour by hour with real timers and the game's weather, from the malting floor to bottling, starting in January, April, July and October outdoors, under a roof and in a basement, and checks the litres in against the litres out (40 L of wort gives about 31 L of vinegar).

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
- A whole yeast packet per run, as a station slot can't take part of one.
- Fermentation yields 95% by volume (lees), and souring loses about 20% overall.
- The mother grows one layer per 15 L of vinegar made, and a split always gives one layer.
- The mother speeds a cask by 25% only while the pool is at least 25% soured.
- The cask slows above 22.5 L of 30 L (three quarters), down to half speed when full.
- One vanilla Vinegar counts as 1 L (10 uses at 0.1 L each, from the jarring recipe), although vanilla gives it the weight of about 0.2 L. That mismatch is accepted so the output stays exactly vanilla.
- A roofed station uses the 10-day mean temperature plus 10 C, capped at 28 C. A basement is a flat 15 C. Room heating isn't modelled.
- Hops, boiling the wort, and clarifying or pasteurising the vinegar are left out.
- Barley, wheat and rye are interchangeable.

## Engineering notes

- The vessel's liquid is handled by the mod, not the engine. The engine doesn't hold a liquid recipe to its amounts, and runs whichever recipe it likes. So Ferment Wort takes only the yeast as a recipe input and gives a marker item, the world code takes 10 or 20 L from the tank when it sees the run start, and turns the marker into fermented wort in the other tank when the run ends.
- A station slot consumes a drainable item whole, which is why a run takes a full yeast packet rather than 5 uses.
- The cask's pool, souring, mother and layers live in the cask's `movableData`, which vanilla copies onto the item when a station is picked up and back when it's placed. So the mother moves with the cask and can't be duplicated.
- Weather is kept as running totals in global ModData, per stage and place, so stations catch up exactly when their area loads again.
- Station sprites are layered by the mod rather than with `SpriteOverlayConfig`, which can only show one overlay for a first batch.
- The shared core (weather, places, station tracking, popups) is the required TP Core mod (`~/MODS/TraditionalPreservationCore`, id `TraditionalPreservationCore`), loaded as `require "TraditionalPreservationCore/Weather"`. Edit it there. The rate curves, heat damage, the cask, the hose and the old-save migrations stay in this mod's own files.

## Debug commands

In debug mode, `TPV.help()` in the Lua console lists commands for testing this mod. They are described in `DEVHELP.md`.

## Known prototype caveats

- **Temperature hasn't been seen in play.** The installed test copy runs every stage in an hour with temperature switched off. Check a cold and a hot month with real timers before relying on the season table.
- Stations indoors go by the outdoor weather and the season, so heating a room doesn't speed them up.
- A forged or wooden bucket used for mashing comes back as a plain metal bucket.
- The bottle list is written out, as no tag covers plastic bottles, so bottles from other mods aren't accepted.
- Apples, grapes and other fruit aren't used, as vanilla can't grow apples or grapes.
- Several vanilla UI functions are wrapped (the station window, slot adds, the Craft button, the pick-up cursor and the station's right-click entry), so compare them with vanilla after a game update.
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
7. "15 C in a basement" on a station below ground.
8. A run with real timers and temperature on, in a cold month and a hot month, under a roof, outdoors and in a basement.
9. The hose: attach; Pump to Cask from both stations, with 5 L, 10 L, the air line and all that fits each moving what it says; greyed options giving their reasons (empty vessel, short tank, no room, already at the air line); detach; and a destroyed station dropping the hose.
10. Cask Info: opens from the cask's submenu, fills its bars, counts down while souring, shows bottles once ready and the hose when joined, and closes past 6 squares or when the cask is picked up.
11. Green Malt: fresh for 2 days and rotten after 5. Stale Green Malt still kilns into Malt; rotten Green Malt stays rotten on the fire, and the composter takes it.
12. `console.txt` shows no repeating Lua errors after an hour of play, including with the other Traditional Preservation mods on.
