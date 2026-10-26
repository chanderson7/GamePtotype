# Phase 3: Battles that differ

Every fight should play differently depending on **where** it happens, **whose troops** you
lead, and **what** you're fighting for, and each culture should feel different in your hands.
This comes before lords and kingdoms (Phase 4) because their armies are built from culture
troops, on varied ground.

| | Workstream | Size (solo) | Status |
|---|---|---|---|
| 3.1 | Orders and readability | 3–4 days | **Done** (`965d729`) |
| 3.2 | Battlefield terrain | ~2 weeks | **Done** |
| 3.3 | Culture troop trees | ~2 weeks | **Done** |
| 3.4 | Objectives and encounter variety | ~1.5 weeks | **Done** |
| 3.5 | Integration and polish | ~1 week | **Done** |

Phase 3's work is complete, and each exit gate below passed when last measured. The first drafts of 3.2–3.5
(`5b65a41`…`e9049f5`) didn't load; `02e4ab8` made them load, pass and play fair, and the
commit after it finished what that one listed as left. Where the result differs from the
plan below, it says so here.

## Where Phase 3 stands

**In the game, with tests:**

- **Terrain** (hills, woods, river fords, rocky passes, villages):
  - Effects: slopes, woods cover, fords, charges (see the rules as built, below).
  - Pathing through fords and around rock. Men slide along banks and rock faces and never
    stand in deep water or on rock. Routers still leave the field.
  - The enemy AI lines up on the ground and keeps it (below).
  - Woods drawn as stands of trees on a dark forest floor, the treetops over the men
    nearly solid. Hint cards for each kind of ground.
- **Rivers on the world map.** The Raven, the Qamar and the Kumo run down to the sea, each
  forded where a road crosses it (four fords). A fight within 28 map units of a river is
  fought across it, and the encounter says so ("You meet them at a ford over the Raven");
  no fight far from water is. Trees, peaks and dunes stand clear of the rivers.
- **Chosen ground.** On hills and in woods, a band that isn't raiding or ambushing has
  picked its ground 30% of the time: a ridge across its half, or stands of trees at its
  edge. It waits there (a Patient commander), and the encounter says so.
- **Troop trees.** 24 tier-2 branches, chosen when training to level 2, each with its own
  sprite and portrait (`tools/unit_sprites.py`): men-at-arms in plate, sergeants with
  maces, halberdiers, crossbowmen with pavises, horse archers, ronin without banners,
  mounted samurai with the horo, and the rest. The upgrade choice shows both branches.
  - Mechanics: armor, piercing, javelins (only before the lines meet), horse archers,
    sweep, steady.
  - Saves migrate from version 3 to 4.
- **Objectives** (the matching fights on the map):
  - **Chief.** A named chief leads the band from behind his line with his bodyguard, which
    rides out to finish a fight or meet a threat, and runs once it's down to 45% of its
    men. Break the guard while your men are on it and the chief goes down in the rout,
    with no one to drag him clear; the death roll decides whether he dies (about 4 wins in
    10) or is carried off after all, to come back 5 days later. (As drafted he always got
    away, so the chief could never be slain in a battle you led.)
  - **Ambush.** On roads through the woods the map draws, never in the desert. You start
    strung out three abreast, foot at both ends of the column, 5 morale down, and can't
    re-form; the ambushers come from both ends.
  - **Village defence.** The village lies behind your line. Hold the square for 2 minutes
    while raiders come in thirds, at 30 s and 60 s, from east and west. Raiders who hold
    it two to one for 25 s in all burn it, and the fight is lost; a ring of flame shows how
    near they are.
- **Send in** knows terrain and trained units: each unit's counters come from its own
  bonuses, its mechanics are worth so much a man, a band on chosen ground fights 1.3×
  stronger, and a chief dies in 4 wins in 10, as in the full battle.
- **Sound.** Crossbows, javelins and horse archers each have their own sound; a river runs
  under a ford battle and birds sing in a wood; a fanfare when a chief's guard breaks or he
  falls, and an alarm when raiders' reinforcements arrive.
- **Performance.** On open ground a sim step costs what it did before Phase 3; on the four
  kinds of rough ground, 3–15% more per man on the field (gate: ≤ 25%).

**The rules as built, where they differ from the plan:**

- **Slopes, not heights.** A blow struck up a full slope loses 40% of its force and one
  struck down gains as much, by the slope where the striker stands. The planned rule, by
  the height difference between the two men, did almost nothing: two men close enough to
  trade blows are never far apart in height.
- **Woods cover in melee.** Blows struck into the trees from outside land 20% softer.
  Without it a wood's edge was worth nothing to its holders.
- **Fords cut both ways.** Men in the water take 25% more and deal 20% less.
- **The enemy AI fits its whole line to the ground** instead of scoring spots squad by
  squad, which scattered its army: it shifts the line (keeping its shape) onto the best
  footing in reach (height, the drop in front of it, a wood's edge), keeps horse out of
  woods and water, and puts archers on the heights. Except a Reckless commander, it keeps
  good ground for up to 90 s and never wades a river to attack.
- **Send in's strength** uses mechanics only for trained units. Counting their stat
  changes too made it agree with the battle sim less, not more.

**Gates changed from the plan, and why:**

- **"Terrain matters"** is measured as what holding ground is worth, not as a scripted
  terrain player against the tactician. Both sides of a fair map can use its ground, so a
  terrain-using player gained little over a good tactician against an AI that now uses it
  too (about 58–61% against 50%). The gate is now: an army 15% stronger, pressing
  *Advance all* against a band that holds a ridge, a ford or a wood's edge, wins at least
  15 points less often than on open ground. Over 24 seeds per commander it measures 21
  points: a ridge costs the attacker 38, a ford 15, a wood's edge 11. (With 8 seeds, as
  first written, chance moved it about 7 points either way; one draw read 8.)
- **"Objectives ask for something different"** is measured on each objective: the
  tactician plays it (hunts the chief with its horse, strikes back at once when ambushed,
  holds the village square) and must win each at least 60% of the time and, on average,
  15 points more often than *Advance all*. The tactician clears 60% on each, and the gap
  averages about 18 points.
- **"Branch choices are real"** is measured against every kind of recruit, not head to
  head. A head-to-head duel between, say, crossbowmen and longbowmen is decided by range
  alone, and one side wins 12 of 12 whatever the tuning.
- **Terrain fairness** plays each seed both ways round, 48 battles per map, and allows
  35–65%. With 24 battles one way round, chance alone moves the result about 10 points.
  A fair field is now mirrored across its middle, not turned half round: both sides lay out
  their lines from the same end of the field (the scripted players and the AI's tuning
  count on that), so on a half-turned field they stood differently on the ground, and the
  side at the top won about two in three on rivers. A fair river therefore runs straight
  across. Even mirrored, a batch of 48 battles swings about ±10 points (river: 38%, 62%,
  44% on three batches of seeds), which the window allows for.
- **Culture balance** fields each culture's trained army (both branches of each role) and
  plays each seed both ways round. With recruits, who are the same in every culture, all
  three pairings came out alike and the gate tested nothing. All three pairings now land
  inside 35–65%.
- **Performance** is measured per man on the field, and each battle is timed twice with
  the faster run kept. Measured per step, a pass looked 28% dearer than open ground, but
  only because its armies meet later and so still have more men alive 30 seconds in: even
  the parts of a step that never look at the ground cost a third more.
- **Halberdiers** still lose to footmen, because footmen counter spearmen. The test checks
  that the sweep makes footmen pay for it instead.
- **Crossbowmen** were retuned (damage 60, reload 1.8 s, range 230, piercing 0.8). As
  drafted they hit for less per second than plain bowmen and lost every duel with
  men-at-arms.
- **Recruits renamed where they clashed with branch names:**
  - Vardish Men-at-arms, Pikemen, Crossbowmen and Knights became Footmen, Spearmen, Bowmen
    and Horsemen, and now look it: spear and shield, hood and self bow, a steel cap on
    horseback.
  - Kharzani Spear guard became Spearmen.
  - Ryumon Mounted samurai became Riders.

---

## Ground rules (how this codebase works)

- **Rules are pure logic, screens only draw.** `scripts/battle/battle_sim.gd` and
  `scripts/world/world_sim.gd` never touch the screen and are tested headless. Anything a
  player can see that changes outcomes belongs in a sim, with a test.
- **Tune in data files.** Numbers go in `scripts/data/*.gd` (troops, economy, captains), or in
  new data files, with a comment saying what each one does.
- **Every step is gated.** Run the tests and the balance check before committing:
  ```
  godot --headless --path . --script res://tests/run_tests.gd               # ~6 min
  godot --headless --path . --script res://tests/run_tests.gd -- --balance  # ~45 min
  godot --headless --path . -- --autoplay                                    # smoke test
  ```
- **Pixel art comes from tools.** Edit `tools/unit_sprites.py` or `tools/map_sprites.py` and
  re-run them. Don't hand-edit the generated `scripts/art/*_data.gd` files.
- **Saves must keep loading.** Bump `SAVE_VERSION` in `scripts/game_state.gd` (now 5) and give
  every new field a default in `from_dict`.
- **Don't commit generated `.uid` or `.import` files.**

---

## Exit gates for the whole phase

All automated, in `tests/run_tests.gd` (with `--balance` where noted).

| Gate | Target |
|---|---|
| Existing balance holds on open ground and on each terrain type (`--balance`) | Advance-all-only ≤ 55%, scripted tactician ≥ 70% |
| Terrain is fair: AI vs AI on mirrored maps, 24 seeds per type, each fought both ways round | Each side wins 35–65% |
| Terrain matters: an army 15% stronger attacking a band on a ridge, at a ford or at a wood's edge, against every kind of commander | Wins ≥ 15 points less often than on open ground |
| Cultures are balanced: each culture's trained army vs each other's, AI both sides, 24 seeds both ways round | 35–65% |
| Every new unit wins its intended matchup duel | ≥ 80% |
| Branch choices are real: the two tier-2 options of a role, at equal cost | Neither beats the other by more than 65/35 |
| Objectives ask for something different | Tactician wins each ≥ 60%, and on average ≥ 15 points more often than Advance-all |
| Send in matches real battles, with terrain and new units | Same winner ≥ 85% |
| 30-day scripted campaigns (`Plans.campaign`) | Still pass |
| Performance: a sim step per man on the field, on each kind of ground | ≤ 25% slower than on open ground |
| Old saves | Phase 2/3 saves load |

---

## 3.1 Orders and readability: done

Shipped in `965d729`:

- **Drag a line.** The whole army or a selected squad forms up along it, with a live preview
  while dragging. Before the battle it places everyone at once.
- **Attack targets marked.** A pulsing ring and crossed swords sit on any enemy squad you've
  ordered an attack on.
- **Hold fire** for archers.

In the sim: `order_line`, `line_preview`, `line_spots`, `set_hold_fire`, `Squad.face`,
`Squad.files`, `Squad.hold_fire`.

---

## 3.2 Battlefield terrain (~2 weeks)

### What the player gets

Fights take place on hills, in woods, at river fords and in rocky passes, chosen by where
the fight happens on the world map. Each kind of ground changes the fighting in ways the
player can see and use.

### Data model: new `scripts/battle/terrain.gd` (RefCounted, logic only)

- A grid over the arena, `CELL := 30.0` units, so 28 × 42 cells for the 840 × 1260 field.
  Packed arrays per cell:
  - `height: PackedFloat32Array`, from 0 to 1
  - `woods: PackedByteArray`, 0 or 1
  - `water: PackedByteArray`: 0 none, 1 shallow ford, 2 deep (impassable)
  - `rock: PackedByteArray`: 1 is impassable
- Lookups are instant, since every soldier calls them every step:
  `height_at(p)`, `in_woods(p)`, `water_at(p)`, `passable(p)`, `speed_factor(p, mounted)`.
- `features: Array` for drawing only: woods outlines, hill contours, the river's path, the
  fords.
- `to_dict()` / `from_dict()`, so a battle can be replayed and tested.

### Battlefield types: new `scripts/battle/battle_site.gd`

Each type is generated from `seed`, `biome` and `fair` (mirrored between the halves with
side-to-side variation; `fair = false` lets the enemy hold the better ground on purpose):

| Type | Contents | Picked when (from `MapTerrain` at the fight's position) |
|---|---|---|
| `open` | Today's field | Default; more often on Kharzan steppe |
| `hills` | One or two hills, or a ridge between the armies | `height_at` high, or hilly nearby |
| `woods` | 2–4 stands of trees, often on the flanks | High woods noise (Vardmark, Ryumon) |
| `river` | A river across the middle with 2–3 fords | Near a river (see decision 3), or 15% at random |
| `pass` | Impassable rock outcrops narrowing the middle | Near mesas or mountains |
| `village` | Houses and fences as obstacles | Only for the village objective (3.4) |

- `BattleSite.pick(world, position, objective) -> {type, seed, biome, fair}` is stored in
  `GameState.pending_battle["site"]`, so the battle screen, the sim and Send in all see the
  same site.
- `MapTerrain`'s woods noise is private (`_woods`); add a public `woods_at(p)`.

### Effects (tunable constants in a new `scripts/data/terrain_rules.gd`)

| Terrain | Movement | Arrows | Melee and morale |
|---|---|---|---|
| Woods | Foot ×0.75, horse ×0.5 | Arrows into woods: 50% hit trees (they stick there) | No charges into or out of woods; volley shock ×0.5 |
| Height | Uphill ×(1 − 0.3·slope), downhill ×(1 + 0.1·slope) | Range × (1 + 0.5·max(0, shooter height − target height)), capped at +25% | Damage × (1 + 0.5·clamp(attacker height − defender height, −0.5, 0.5)); no charge bonus when charging uphill |
| Ford (shallow) | ×0.5 | — | Men in water take +25% damage; can't brace; no charges through water |
| Deep water, rock | Impassable | Arrows fly over | — |

Where each effect goes in `battle_sim.gd`:
- `_walk` / `_pace`: speed factor
- `_strike`: height bonus, water penalty, charge rules
- `_update_projectiles`: woods blocking, before the damage is applied
- the range check through `_fighting_reach` and `_in_range`: height bonus to range
- brace / `still` in `_update_squad`: no bracing in water

### Pathfinding: new `scripts/battle/pathing.gd`

- Grid A* over the terrain cells (1,176 nodes). The cost of a cell is 1 over its speed
  factor; impassable cells are infinite.
- A route is computed when a squad's goal changes, and re-planned every 1 second while it
  advances. The squad follows the waypoints; the existing `_steer` still steers around enemy
  squads on top of that.
- Soldiers walking toward their spot in formation are pushed back out if it falls in an
  impassable cell, so formations loosen at fords instead of men walking into deep water.

### Enemy AI: `scripts/battle/commander_ai.gd`

- Deploy by scoring candidate spots in its own zone: height and nearby woods for archers,
  hills and wood edges for foot, keeping cavalry out of woods. This replaces the plain
  `auto_deploy` call, with `auto_deploy` kept as the fallback.
- Cavalry don't choose targets across water or through woods (`target_score` penalty).
- A Patient commander on a `river` map holds the fords; on `hills`, it holds the crest.

### Drawing: `scripts/battle/battle_screen.gd` and `scripts/art/unit_art.gd`

- Build a shaded height image once per battle (as `scripts/world/map_terrain.gd` does for the
  world map), with contour lines every 0.2 of height.
- Woods: clusters of tree sprites. Reuse the map's tree, pine and blossom sprites at battle
  scale, or add larger ones to `tools/map_sprites.py`. Draw the treetops over the men at about
  60% opacity so squads in woods stay visible.
- River: a water strip (reuse the look of `shaders/map_water.gdshader`) with lighter shallows
  at the fords. Rocks: the existing rock sprites, scaled up and outlined.
- Tapping empty ground shows what it does in the hint line, for example "Woods: slows horse,
  shelters from arrows."
- The first time each terrain type appears, a one-time hint card explains it (store
  "seen" flags in `user://settings.cfg` through `Sound`'s settings file, or a new settings
  helper).

### Send in: `scripts/battle/auto_resolve.gd`

- Bonus strength for whoever holds the better ground: ×1.1 to the enemy when the site isn't
  fair, and small per-type adjustments (fords hurt cavalry-heavy armies).
- Re-fit and re-check against real battles on terrain (`_check_auto_resolve` gains a terrain
  pass).

### Tests

- **Effect duels, one per rule:**
  - Uphill attackers lose more.
  - Arrows into woods hit about half as often.
  - Charges into woods do no charge damage.
  - Fords slow troops.
  - Men in fords take more damage.
- **Pathing:**
  - A squad crosses a river only at a ford and arrives.
  - Nothing ever stands in deep water or rock.
- **Fairness:** AI vs AI on mirrored maps of every type (`--balance`).
- **Terrain matters:** add a `terrain` plan to `tests/plans.gd` (archers on high ground,
  holding behind woods, fighting at fords) and compare it against `tactician` on each type.
- **Performance:** time 6 full battles per type against an open-field baseline.

---

## 3.3 Culture troop trees (~2 weeks)

### What the player gets

Each culture fights differently. Training a squad to level 2 means choosing between two
branches, and level 3 strengthens that branch. Recruits stay as they are today. Squads hired
abroad use their own culture's tree, so mixing cultures becomes a strategy (Kharzani horse
archers in a Vardish army).

### New mechanics (deliberately few)

| Mechanic | Rule | Where in the sim |
|---|---|---|
| **Armor** (0–0.4) | Arrow damage × (1 − armor); melee damage × (1 − armor / 2) | `_damage` or before it in `_strike` and `_update_projectiles` |
| **Piercing** (0–1) | Ignores that share of armor and of the shield wall's arrow protection | Same places |
| **Javelins** (n per man) | Thrown when an enemy squad comes within 90 units and before contact; uses the projectile code; then melee | `_update_soldier` |
| **Horse archers** | Cavalry with `ranged = true`. Skirmish: keep away from enemy foot, ride clear when engaged, shoot from the saddle. Arrows run out as for foot | New skirmish branch in `_update_squad`; uses the archers' code paths |
| **Sweep** | Each melee blow also hits a second enemy within reach at 50% | `_strike` |
| **Steady** | Morale loss × 0.8 | wherever morale is reduced |
| **Squad size** | 16 or 24 men instead of 20 | `size` in the unit data |

### The trees: option A / option B at level 2

| Role | Vardish: heavy, disciplined | Kharzani: fast, shooting | Ryumon: elite warriors |
|---|---|---|---|
| Infantry | **Men-at-arms**: armor 0.3, shield wall stronger, speed ×0.9 / **Sergeants**: damage +15%, speed +10%, wage −15% | **Javelin askari**: 2 javelins each, speed +10% / **Guard askari**: armor 0.2, steady | **Hatamoto**: 16 elite, damage +20%, health +20%, steady / **Ronin**: damage +25%, always Vengeful when their captain falls |
| Spearmen | **Pikemen**: reach 32, longer schiltron, speed ×0.9 / **Halberdiers**: sweep, bonus vs infantry ×1.2, vs horse ×1.8 | **Spear guard**: armor 0.2, steady / **Levy spears**: 24 men, wage −20%, health −10% | **Yari ashigaru**: reach 30, 24 men / **Naginata**: sweep, vs horse ×2.0, vs infantry ×1.15 |
| Archers | **Crossbowmen**: piercing 0.7, damage +30%, reload +40%, range 210 / **Longbowmen**: range 290, reload −10% | **Composite bowmen**: range +15%, reload −15% / **Desert archers**: speed +20%, step back from foot | **Yumi samurai**: fight like infantry when caught, range +10% / **Ashigaru archers**: 24 men, volley cooldown −30% |
| Cavalry | **Knights**: armor 0.35, charge ×7.5, speed ×0.9 / **Mounted sergeants**: speed +15%, wheel cooldown −40%, wage −15% | **Horse archers** (signature): 8 arrows, weak melee / **Faris lancers**: charge ×7, speed +10% | **Mounted samurai**: lance, steady / **Mounted archers**: 5 arrows, good melee |

Level 3 of a branch: +10% damage and health (today's `power_for`), plus that branch's
strength again at half size.

### Data: new `scripts/data/units.gd`

- `UNITS := { "vardish_men_at_arms": {role, culture, tier, branch_of, name, blurb, stats: {...}, mechanics: {...}, cost_mult, wage_mult}, ... }`
- `role` stays one of the four types in `troops.gd`, so the counter loop, the enemy AI's
  targeting (`COUNTERED_BY`) and the troop icons keep working.
- `Units.stats(unit_id)` returns `Troops.TYPES[role]` with the unit's overrides merged in.
- `Units.recruit(culture, role)` gives the tier-1 id; `Units.branches(unit_id)` gives the
  two tier-2 options.
- Battle entries gain `unit`. `_to_entries` and `_spawn` in `battle_sim.gd` read stats
  through `Units`.

### Campaign

- **Save:** each squad gets a `unit` field; `SAVE_VERSION := 4`. Old squads get their
  culture's tier-1 unit. Old level 2–3 squads are marked unassigned and choose a branch for
  free at the next town.
- **Training:** in `scripts/world/settlement_screen.gd`, the Train button on a level-1 squad
  opens a two-card choice showing each branch's name, blurb and stat differences. Training a
  tier-2 squad to level 3 works as today.
- **Costs:** `scripts/data/economy.gd` multiplies recruit cost, wages and training cost by
  the unit's `cost_mult` and `wage_mult`.
- **Enemies:** bandit bands field tier-2 units more often as the days pass (in `_band_army`,
  `scripts/world/world_sim.gd`). This also prepares lords' armies in Phase 4.

### Art and sound

- `tools/unit_sprites.py`: add per-unit details through parameters to the existing culture
  builders: heavier armor (steel torso), plumes, pavise shields, horse barding, quivers on
  horse archers. Every unit gets a portrait.
- New sounds in `tools/music.py`: a crossbow thunk and horse-archer hoofbeats.

### Send in

- Each unit's strength value comes from its stats and mechanics. Re-fit `VALUE` and
  `COUNTER_WEIGHT` with the calibration harness (random armies of mixed units) and keep the
  ≥ 85% gate.

### Tests

- Every unit's intended matchup duel ≥ 80%.
- Branch balance at equal cost.
- Culture vs culture balance (`--balance`).
- A save migrates from version 3 to 4.
- Training offers both branches and charges the right price.
- 30-day economy campaigns re-run with the new wages.

---

## 3.4 Objectives and encounter variety (~1.5 weeks)

### Reinforcements: `battle_sim.gd`

- `add_reinforcements(team, entries, at_time, edge)`: squads that march in from a map edge at
  a given time.
- Needed for the village objective, and by Phase 4 for battles bigger than the squad cap.

### Objectives

A new `objective` field in setup and in `pending_battle`; `_check_end` grows to handle each
type.

| Objective | How it plays | Win / lose | Where it comes from on the world map |
|---|---|---|---|
| `rout` | Today's fight | Today's rules | Default |
| `chief` | The band is led by a named chief (for example "Rask the Red") at the head of a tier-2 bodyguard squad. | Break or kill the bodyguard and every other squad loses 35 morale. Killing the chief: double bounty, +10 renown. If the chief's squad flees the field he **escapes** | Some bands, more often as your renown grows |
| `ambush` | You start as a narrow column in the middle, unbraced; the enemy deploys at both ends and charges at once | Rout | A band catches you on a road through woods (high `woods_at` at your position) |
| `village` | Hold a marked circle around the village for 120 s against two waves (reinforcements at 30 s and 60 s) | Win: the enemy routs, or time runs out with more of your men inside the circle than theirs. Lose: you rout, or they hold it | A band stops to raid a village; you arrive while it's happening |

### World side: `scripts/world/world_sim.gd`

- **Chiefs:** a registry of chiefs (name, culture, grudge, times beaten). A chief who
  escapes returns 5–8 days later with a bigger band; the encounter text remembers you.
- **Raids:** a band sometimes stops at a village and raids for a few hours. A map notice
  warns you, and arriving in time triggers the `village` objective. Saving it: food, a
  refreshed recruit offer, and a note kept for Phase 4 village relations.
- **Ambushes:** when a band intercepts you on a wooded road, the encounter becomes an ambush.
  The future Scout captain skill (Phase 5) will lower the chance.
- **Withdraw rules:** you can't withdraw from an ambush. Send in is allowed but costs more.

### Screen

- An objective banner at deployment ("Kill Rask the Red", "Hold Thornwall for 2 minutes").
- On the field: a ring on the chief, the circle to hold with a timer, and an arrow at the
  edge where the next reinforcement wave will come in.
- Result text and spoils that fit the objective.

### Enemy AI

- The chief stays back with his bodyguard and flees early when hurt.
- In village fights, the attackers go for the circle.
- Ambushers charge at once.

### Send in

Rules per objective: a chance the chief escapes, a strength penalty when ambushed, and the
village fought as both waves together.

### Tests

- Win and loss conditions for every objective.
- Tactician vs Advance-all rates (see the gates).
- A chief who escapes comes back.
- Raid timing on the world map.
- Reinforcements arrive on time at the right edge.

---

## 3.5 Integration and polish (~1 week)

- Sounds: river, birds in woods, crossbow, horse archers. Optional: a short music cue for the
  objective banner.
- Balance passes across terrain types × cultures; re-fit Send in; re-run the economy
  campaigns.
- Hint cards for each terrain type and objective (shown once).
- Performance: profile terrain lookups and pathfinding on a phone-class CPU. Cache path
  routes per squad.
- Tests for save migration; README and how-to-play updated; screenshots of each terrain type
  and objective.

---

## Order of work

Each milestone is playable on its own.

| Week | Milestone | Its gate |
|---|---|---|
| 1–2 | Terrain core: grid, hills and woods, effects, drawing, enemy AI deployment | Effect duels, fairness, "terrain matters" |
| 2–3 | Rivers and fords, pathfinding, linking to the world map, Send in | Ford crossing, performance, Send in ≥ 85% |
| 3–4 | Unit data and the new mechanics (armor, piercing, javelins, horse archers, sweep, steady) | Matchup duels |
| 4–5 | Tree content, training choice, art, save migration, costs | Culture and branch balance, economy |
| 6–7 | Reinforcements, objectives, chiefs, raids, ambushes | Objective gates |
| 7 | Integration and polish | All gates |

## Cut line: a 3-week core

If time is short, ship:

- Hills, woods and fords (river maps generated at random, without adding rivers to the
  world map).
- Culture stat identity plus horse archers, without branching trees.
- The `chief` objective only.

Everything else moves to a later phase.

---

## Decisions (defaults stand unless changed)

1. **Branching trees, or culture stat identity only?** Default: **branching** (as above).
2. **Horse archers for both Kharzan and Ryumon?** Default: **yes**, played differently.
   Kharzani: more arrows, better at keeping away. Ryumon: fewer arrows, strong in melee.
3. **Add 2–3 rivers to the world map**, so fords line up with real crossings? Default: **yes**.
   This adds rivers to `scripts/world/world_data.gd` and to the map drawing, and the land and
   road checks must still pass.
4. **Chiefs who escape and come back?** Default: **yes**.

## Risks

- **Too many combinations to balance** (36 unit types × 6 battlefield types). Mitigated by
  the short mechanics list and the automated gates; tune in data, not code.
- **Formations crossing fords.** Keep the pathfinding grid coarse and accept loose
  formations in water.
- **Reading terrain on a small screen.** Strong shapes, the treetops drawn see-through, and
  the hint cards.
- **Phone performance.** Lookups precomputed in packed arrays, route caching, and the
  per-step cost check in the tests.
- **Send in drifting from real battles.** The ≥ 85% gate is re-run every milestone.

## Not in this phase (Phase 4 and later)

- Lords and kingdoms, armies, castles changing hands, prisoners and ransom (Phase 4)
- Wounded men, captain skills and promotions, named heroes, bond scenes, Casual mode (Phase 5)
- Sieges, tutorial, monetization, cloud saves (Phase 6 and launch preparation)
