# Bannerfall: siege engines, for the stormers and the walls

- **Date:** 2026-11-13
- **Status:** built (2026-11-13). Where the build differs from the plan, and the measured balance, are under *As built* at the end.
- **Goal:** a siege is something you *prepare* and something a town is *built* to
  resist. The attacker builds engines before the assault (a ram, ladders, screens for the
  bows, a tower, stone throwers) and works them in the battle; the walls answer with
  engines of their own (bolt throwers on the towers, oil over the gate, a stone thrower in
  the courtyard, fire for anything wooden, a postern to sally from). Both sides get
  choices that matter before and during the fight, and the numbers stay honest in the sim
  and in auto-resolve.

## What happens today

Sieges are already a real fight (see `siege-defence-plan.md`, built 2026-11-05): a wall
across the field with a gate, two ladders, stones from the gate tower, held ladder heads,
a crescent at the breach. What's missing is anything *built*:

- **The ram is just men at the gate.** Any attacker on foot within `GATE_REACH` (46 px)
  strikes the gate once a second (horse at half), under a roof that takes 60% of arrows
  (`RAM_ROOF` 0.4). Nobody built it, nobody can burn it, and it's there the moment you
  arrive.
- **The player storms off the march.** `siege_check` asks only that you're at war, at the
  walls and have men. *Storm the walls* starts the battle at once, with the same ram and
  ladders a marshal army has after two days.
- **A marshal army's preparation is a timer.** `SIEGE_PREP_HOURS` (48) passes, then
  `assault()`; "sieges construct rams and ladders" only in the README. Starvation
  (`SIEGE_FOOD_DAYS`: castle 4, town 6) and relief battles are real.
- **The walls are one strength.** The wall row is rock except the gate; it can't be
  damaged anywhere else. The garrison's only "engine" is men dropping stones
  (`STONE_DAMAGE` 6/s per man on the tower).
- **Auto-resolve is a flat multiplier**: castle ×1.6, town ×1.4 (`Lords.WALLS`,
  `AutoResolve.WALLS`), whatever either side brought.
- **Fiefs** have Granary, Palisade (villages only) and Mill: nothing for a castle or town
  you hold to make its walls harder to take.

Measured last time (AI against AI, castle): an even assault fails 8 of 8, half again wins
about 62% (32 seeds), twice wins 8 of 8.

## The idea

Two clocks and one field:

1. **The camp clock (campaign).** Laying siege starts building. Every engine has hours
   and silver; more men build faster. While you build, the garrison's food runs down and
   so does yours, relief may ride in, and the garrison may sally at night to burn what
   you've built. Storm whenever you like with whatever is ready, including straight off
   the march with ladders and axes (harder than today).
2. **The walls' works (campaign).** Every castle and town has defences by its kind and
   land; capitals have more; a fief you hold can buy more. Damage stays: a breach your
   trebuchet made, or a gate your ram broke, is still open tomorrow unless it's repaired.
3. **The field (battle).** Engines are things on the field with wood that can burn and a
   company working them. Attackers' throwers knock down wall sections (a second way in),
   a tower rolls up to the walk, mantlets cover the bows; the walls' bolt throwers and
   stone thrower hunt those engines, oil and fire answer the ram and the tower, and a
   company can slip out by the postern to burn a thrower.

Nothing here makes walls easier *in general*. The point is that preparation buys the
attacker what numbers buy today, and the defender's works take some of it back.

## 1. Engines on the field (shared model)

An engine is a new kind of thing in `battle_sim.gd`, beside squads:

```
Engine { id, kind, team, pos, hp, hp_max, burning (seconds left), crew_squad (id or -1),
         reload (seconds), target ({kind: "wall"/"gate"/"engine"/"squad"/"auto", ref}),
         state ("idle", "working", "moving", "docked", "burnt") }
```

- **Crews are your companies.** An engine works only while a company crews it: at least
  `CREW_MIN` (6) of its men within `CREW_REACH` (40 px), working it at a rate that scales
  with how many are there, up to `CREW_FULL` (12). A company on a trebuchet isn't
  fighting, which is the choice. No new troop type for now (see *Open questions*).
  Crews standing at an engine take arrows at `ENGINE_COVER` (0.6) behind its timbers.
- **Wood burns.** Engines have hp (first guesses below). Arrows do almost nothing (2%
  of their damage); stones and bolts do full damage; **fire** (oil, fire pots, fire
  arrows) sets an engine burning: `BURN_DPS` (8) for `BURN_TIME` (12 s), and a crew of 6
  or more standing at it puts the fire out in half the time instead of working it. Men
  hacking at an engine in melee set it alight. A burnt engine stays on the field as a
  black frame.
- **Cards, not buttons.** In the battle tray an engine is a small card after the
  companies: its icon, its hp bar, a crew dot (green crewed, grey idle), and what it's
  aimed at. Tap the card and its possible targets light on the field (wall sections,
  the gate, enemy engines, companies in range); tap one to aim. Unaimed engines choose for
  themselves (*auto*), the way the AI does.

## 2. Attackers' engines

Built in the camp (section 4), placed at deploy, worked in the battle.

| Engine | Build | Silver | Hp | What it does |
| --- | --- | --- | --- | --- |
| Ladders (2) | 4 h | 0 | — | As today. Two more (4 in all) for 6 h more. |
| Ram | 16 h | 60 | 900 | As today's ram: men at the gate strike it at full rate under the roof. **Without one, men hack at the gate with axes at `GATE_NO_RAM` 0.35 and no roof.** |
| Mantlets | 8 h | 40 | 250 each | Screens for the bow companies at their stand-off line: arrows at 50% (the same as the walk), so the bows' duel with the walk is even. One per bow company. |
| Siege tower | 40 h | 160 | 1400 | Rolls up to a wall section (`TOWER_PACE` 12 px/s) pushed by its crew, who are sheltered inside (arrows at 20%). Docked, it lays a bridge on the walk 2 cells wide: climbing at `TOWER_CLIMB` 0.9 of pace, two men abreast. The best way in, and the slowest and most burnable thing on the field. |
| Stone thrower | 30 h | 120 | 700 | Stands on the attackers' engine line (about y 1100, 600 px from the wall). A stone every `THROW_RELOAD` (10 s) at its target, landing within `THROW_SCATTER` (14 px + 6% of the range). On a **wall section** it takes `WALL_HIT` from the section's hp (section 5); on the **gate**, 60 blows; on men, `STONE_SPLASH` 45 damage within 20 px and a morale shock; on an **engine**, 220. Two at most. |

Every land builds the same five, drawn its own way; each has one **signature** (section
6).

### The ram becomes something built

This is the change with the most reach: today's ram is free. With a ram, battering is
exactly today's (`GATE_HP` 750 castle / 600 town, a blow a second a man, `RAM_ROOF` 0.4),
so every existing siege number holds for a *prepared* assault. Without one, the gate
takes `GATE_NO_RAM` (0.35) of that and the men at it have no roof, so storming off the
march is a real gamble. Existing tests and fixtures get `engines: ["ram", "ladders"]` so
they keep measuring what they measure now.

## 3. The walls' engines

What a place has comes from its kind, its land and its works (section 4). The garrison
crews them like the attacker does: the commander's `garrison_plan()` gives each a
company before it fills the other posts.

| Engine | Where | Who has it | What it does |
| --- | --- | --- | --- |
| Bolt thrower (springald) | On two of the wall's towers, one each side of the gate | every castle and town | Range 450 px, a bolt every 5 s along a line: 70 damage to the first man and 35 to the one behind him, 260 to an engine. Its job is crews and engines. |
| Murder holes and oil | Over the gate | castles (towns buy it) | Every `OIL_EVERY` (20 s) a pour on everything within `GATE_REACH`: 60 damage a man, roof or not, and sets the ram burning. Needs one company on the gate tower (the stone throwers already there). |
| Stone thrower | In the courtyard, behind the keep | capitals; bought | The attacker's thrower, turned round: counter-battery first (enemy engines in range), then massed foot near the wall. Range 600 px. |
| Fire | Bow companies on the walk | everyone | A bow company can be told *Burn* with an enemy engine as its mark: its arrows do fire to the engine (a hit in five sets it burning) and nothing to men. Kharzani walls burn better (section 6). |
| Postern | A small door in the wall section by the right-hand ladder | every castle and town | A company told to *Sally* at an engine goes out by the postern, hacks it (melee sets it burning) and comes back in by the postern, which shuts behind it. The postern is a cell that opens only for the garrison. |

### Walls that break

The wall row becomes **sections**: `WALL_SECTION` 3 cells wide, the gate and the two
ladder cells their own. Each section has hp (`WALL_HP` castle 900, town 650 per section;
a thrower's stone takes `WALL_HIT` 60, so a lone thrower needs about 15 hits, 150 s, to
bring a section down: most of a battle). When a section falls, its middle cell becomes
**rubble**: open to men on foot at `RUBBLE_PACE` 0.6, not to horse, and the breach
crescent (`breach_posts()`, built for the gate) can be formed at any breach. A siege can
now end with the attackers through a hole the defenders weren't guarding.

## 4. The camp and the works (campaign)

### Laying siege

A walled place you can storm (`siege_check` as today) offers two things on its sheet:

- **Storm the walls** — at once, with what you have: ladders always, the rest only if
  built.
- **Lay siege** — the company camps at the walls. The map rings the place with your camp
  (the ring armies already have). The sheet becomes the **siege sheet**: the walls' state
  and works, the garrison and its food, your food, any relief riding in, and a **build
  list**: each engine with its hours and silver, *Build*, and a progress bar. One thing
  builds at a time; hours shrink with men: `hours × 60 / men`, between ×0.5 and ×2.
  Friendly lords camped with you count as men. *Storm the walls* stays on the sheet.

While you camp: the garrison's food falls (`SIEGE_FOOD_DAYS`, as for armies; it gives up
when it runs out), your own food and wages run, relief lords at war with you who reach the
place fight you (the relief battle armies already have), and each night there's a chance
(`NIGHT_SALLY` 0.15, more for a big or daring garrison) that the garrison sallies at your
best engine: a small night battle by the camp, or settled at once, and a lost fight costs
the engine. Leaving the camp (riding away) abandons what's half built; what's finished
burns.

### Marshal armies

`SIEGE_PREP_HOURS` becomes the army's build list, chosen by size and land: a ram and
ladders always; a thrower over 150 men; a second thrower over 250; a tower at a castle
over 200 men. The army assaults when its list is done (never sooner than today's 48 h).
`siege_info` reports the engines and what's left to build, so the sheet reads "a ram and
ladders ready; a trebuchet in 11 h". Leading or defending an army's assault, the battle
has those engines.

### Works, damage and repair

- **Every walled place** has bolt throwers and a postern; castles have oil; capitals a
  stone thrower (section 3).
- **A fief you hold** (castle or town) gets two Manor works, beside Granary and Mill:
  **Siege works** (500 silver: oil over a town gate, a courtyard thrower) and
  **Tower bolts** (300: a third bolt thrower, and bolts 20% faster). Villages keep the
  Palisade.
- **Damage stays.** A wall section or gate an assault broke stays broken for
  `REPAIR_DAYS` (gate 2, section 4) unless the holder pays to hurry it. A failed assault
  that knocked down a section leaves a weaker place for the next one; the siege sheet and
  the place's vista show it. The AI repairs what it holds; a player fief's sheet has
  *Repair*.

### Auto-resolve

The wall multiplier is composed from what's there, not looked up:

```
walls = base (castle 1.6, town 1.4)
      + 0.05 per bolt thrower, + 0.05 oil, + 0.10 courtyard thrower
      + 0.25 if the attacker has no ram
      − 0.10 per attacker thrower (max 2), − 0.15 a tower, − 0.20 per breach already open
clamped to 1.0 … 2.2
```

The constants are set by the balance probe (section 8) so auto-resolve and the sim agree
within ten points on every case in the table there.

## 5. The battle, step by step

**Deploy.** Engines are placed with the companies: throwers on the engine line (dots
like the ladder circles), the tower and ram at the foot of the field, mantlets where the
bows stand off. *Auto-place* does it. The storm plan (first tap of *Storm*) gains two
jobs: tapping a company card cycles **ladder → ram → tower → engine crew**, and the plan
text says who works what: "Brann's Pikes push the tower; Nell's Bows shoot from the
mantlets; Wyn's Shields crew the trebuchet."

**The fight.** Throwers work from the first second on their aim (a wall section by
default for the attacker, the nearest engine for the defender's). The tower and ram move
off when *Storm* is given. The walls' bolt throwers shoot what's in range, engines first.
Oil pours when there are men at the gate. Fire shows on what's burning; a burning
engine's card flashes.

**Bars stay three buttons.** Attack: *Advance all · Hold all · Storm*. Defence:
*Sally · Hold all · Man the walls / Hold breach*. Engine orders live on engine cards;
*Burn* is a bow company aimed at an engine (tap the company, tap the engine); a sally at
an engine is a foot company aimed at an engine while the gate holds (it takes the
postern).

**Callouts** in the existing tiers: "Their trebuchet has the range!", "A breach in the
east wall!", "The tower is at the wall!", "Oil on the ram!", "Their tower is burning!",
"Our men burned their mangonel!".

**The result** adds tiles (stones thrown, sections broken, engines burned on each side)
and lines in the siege timeline ("12:40 · the trebuchet broke the east wall").

## 6. The three lands

Same five engines, each land's look and one signature:

- **Vardmark**: a counterweight trebuchet (slower, `THROW_RELOAD` 14 s, but `WALL_HIT`
  ×1.5: the wall-breaker) and a hide-roofed belfry; its walls have springalds and oil.
- **Kharzan**: a traction mangonel that can throw **naphtha** (its stones set an engine
  burning, and burn 20 px of ground for 6 s); its walls keep fire pots on the walk (*Burn*
  sets an engine alight in one hit in three, not five).
- **Ryumon**: **bamboo-bundle shields** that move with the men (mantlets that advance:
  the archers can shoot from 180 px, not 225, still covered) and a lighter hand-hauled
  thrower (cheaper, 20 h, 80 silver, `WALL_HIT` ×0.7); its walls have **yagura**: covered
  towers where bows stand at 35% arrows, and logs rolled down the ladders (a held ladder
  head kills the first man over twice as often).

## 7. Art and sound

Pixel art in the battle's own style (top-down, lit from the upper left, `sprite_data.gd`
palette), each land's engines in its own wood and cloth:

- ram under its roof (exists, gains hp damage and fire), mantlet (1 cell), tower (2×3
  cells, two rolling frames, a bridge frame), thrower (2×2 cells, four arm frames for the
  throw), bolt thrower on a wall tower (a frame for the shot), courtyard thrower;
- stones in flight on an arc with a shadow on the ground, bolts as streaks, a dust burst
  and falling blocks where a stone hits a wall, rubble cells for a breach, flame and smoke
  on burning engines, oil as a dark splash at the gate;
- on the map, the besiegers' ring shows the engines built so far, and a breached place
  shows a gap in its wall on the vista.

Sounds through `Sound.play_at`: the thrower's creak and thump, a stone on stone, falling
masonry, the bolt's crack, oil's hiss, fire's crackle; the camp's hammering on the
siege sheet. Under Reduced motion stones and bolts land without flight and fire is a
steady glow.

## 8. Balance

`tests/_partial_siegeprobe.gd` comes back as a kept probe (`tests/siege_probe.gd`, not in
the default suite): AI against AI on a castle, 32 seeds each.

| Assault (attacker vs garrison) | Attacker wins, target |
| --- | --- |
| Even 5 v 5, ladders only (off the march) | 0 of 32 |
| Half again 7 v 5, ladders only | at most 35% |
| Half again, ram and ladders (a day's camp) | 55–65% (today's 62%) |
| Even, ram, ladders, mantlets, tower, two throwers | 30–45% |
| Half again, the same full train | 75–85% |
| Half again, full train against full works (oil, courtyard thrower, three bolt throwers) | 50–60% |
| Twice, anything | 32 of 32 |

And per engine, so no engine decides a siege alone: a thrower kills at most 3 men a
stone; a tower that docks unopposed puts the first man on the walk 25–35 s after *Storm*;
a ram under oil without a crew to put the fire out burns in 30–45 s; the walls' bolt
throwers alone don't stop a tower with a full crew.

## Tests

New `tests/siege_engines_tests.gd`:

- **Engines.** An uncrewed engine does nothing; a crew of 6 works at half, 12 at full.
  Arrows barely mark an engine; fire burns it; a crew puts a fire out; melee at an engine
  sets it burning; a burnt engine stays and does nothing.
- **Ram.** With a ram, gate times as today (the existing siege tests, given
  `engines: ["ram", "ladders"]`, pass as they are); without, the gate takes about three times as long and
  the men at it take full arrows.
- **Throwers and walls.** Stones land within the scatter; a section falls after its hp,
  opens one rubble cell to foot and not horse, and the breach crescent forms there; the
  gate takes 60 blows a stone.
- **Tower.** It rolls, docks at its section, the bridge climbs two abreast at 0.9; a
  burning tower stops; one that burns out leaves its section shut.
- **Walls' engines.** A bolt hits the first man and the one behind; oil hits everything
  at the gate on its timer and sets the ram alight; *Burn* sets an engine alight in the
  expected share of hits; a postern sally reaches an engine, burns it and comes back in.
- **Camp.** Build hours scale with men and the clamp; silver is paid on *Build*; riding
  off abandons the half-built; a night sally can cost an engine; food runs on both sides.
- **Armies.** A marshal army's list by size; it assaults when the list is done, not
  before 48 h; its engines come into the battle when you lead or defend its assault.
- **Works and damage.** Fief works change the defence; a broken section stays broken for
  its days, then mends; *Repair* hurries it; all of it saves and loads.
- **Auto-resolve.** The composed multiplier for each case in the balance table, and
  agreement with the probe within ten points.
- **Boundaries.** A field battle runs as before (seeded, same end); a siege without
  engines on either side (`engines: []`, no works) is today's siege with axes at the
  gate.

## Order and sizes

1. **The engine model and the built ram** (section 1, the ram in 2): `Engine` in the sim,
   crews, hp and fire, cards in the tray; the ram becomes an engine and storming without
   it is the axes. Existing tests keep a ram. *Medium.*
2. **The camp and the armies' build lists** (section 4 up to *Works*): *Lay siege*, the
   siege sheet and build list, night sallies, marshal prep. Engines exist on campaign
   and come into battles. *Medium.*
3. **Throwers and breakable walls** (section 2's thrower, 3's walls): the centrepiece.
   Sections, rubble, breaches anywhere, targeting from the card, the arc and the dust.
   *Large.*
4. **The walls' engines**: bolt throwers, oil, *Burn*, the courtyard thrower. *Medium.*
5. **The tower and the mantlets.** *Medium.*
6. **The postern sally.** *Small.*
7. **Works, lasting damage and repair; the three lands' signatures.** *Medium.*
8. **Auto-resolve composition, the AI on both sides (what to aim at, when to sally, when
   to repair), and the balance run.** *Medium*, and the tuning.

Each step lands with its tests and screenshots next to today's in the scratchpad before it
is called done; the balance probe runs after 1, 3, 4 and 8.

## What does not change

- Field battles, raids and village fights: none of this runs outside `OBJECTIVE_SIEGE`.
- A prepared assault (ram and ladders) on plain walls plays as today, with today's
  numbers.
- The wall walk, stones, ladder heads and the breach crescent: they gain company, not
  changes.

## Open questions

- **Crews from your companies, or engineers?** Companies-as-crews needs no new troop and
  makes crewing a real cost. A later *Engineer* veteran role (beside Scout,
  Quartermaster, Drillmaster, Champion) could build faster and throw truer.
- **Bombard before the battle?** Throwers in the camp could knock at the walls over days
  (a section's hp a day, a few of the garrison) so a long siege softens the place before
  you storm it. More strategy, but another clock to watch.
- **How many engines can a phone show?** Up to 4 per side on top of 240 men, stones in
  the air and fire: worth a frame-rate check on a real phone after step 3.
- **Should the player's own fief garrison crew its engines automatically** when an army
  storms it and you're away (auto-resolve already counts them), or only when you're there
  to man the walls?

## As built

Everything above is in, with the two open questions answered as recommended: engines are
crewed by your own companies (an Engineer role can come later), and throwers in a camp
bombard the walls each day before any battle. Code: `scripts/battle/siege_works.gd` (the
field), `scripts/world/siege_camp.gd` (the campaign), hooks in `battle_sim.gd`,
`commander_ai.gd`, `battle_screen.gd`, `game_state.gd`, `marshal_armies.gd`, the map's siege
sheet and the fief's Manor card. Tests: `tests/siege_engines_tests.gd`; the balance probe is
`tests/siege_probe.gd` (not in the default suite).

Where it differs:

- **Engines are on the field, not cards in the tray.** Tap one of yours to pick it up and
  tap a wall section, the gate, an enemy engine or a company to aim it (tap it again: it
  chooses for itself). With a company picked, tap your engine to send it to work there,
  tap an enemy engine with bows to set it alight, or with foot while holding the walls to
  sally at it by the postern. A tap on an engine during deployment says what it is. The
  storm plan cycles a company through ladder, ram, tower and the throwers.
- **Crews.** Anyone can haul on a thrower's ropes, horsemen first (they can't climb and
  only half batter); the tower needs men on foot. The two throwers stand side by side as a
  battery one company works, and crews stand behind their engine (`CREW_REACH` 78), so
  the engine is seen.
- **A fallen section is rubble along its whole width**, not one cell: a one-man gap was a
  slaughter, not a breach.
- **The walls' thrower outranges the stormers'** (840 px to 720, on its platform), so
  counter-battery happens; at equal range the two never met.
- **Numbers that moved**: tower hp 2000 (bolts do 80 to an engine, not 260: two bolt
  throwers would have stopped every tower), stones 100 to a wall section and 40 to a man,
  scatter 14 + 4% of the range; reloads Vardish 11 s, Kharzani 8 s, Ryumon 7 s.
- **The AI.** A storming commander with crewed throwers waits for a breach (up to 100 s),
  sends nobody up ladders once the wall is down anywhere, and drops stones on the
  garrison's biggest company behind the breach, never within 70 px of its own men. A
  garrison forms a crescent at every breach, sets the moving tower alight with its nearest
  bows (not the ram: bows shooting fire at it aren't shooting the men under it, and the
  stormers did better for it), and sallies at an engine guarded by ten men or fewer.
- **The end of time**: the walls hold only if the gate stands *and* no section is down.
- **Damage is kept by column** (sections fall differently with four ladders): a section
  is as strong as its weakest stretch. It mends at half the gate a day and a quarter of a
  stretch, unless someone is camped before it; your fief's Manor card has *Mend* (120).
- **The camp follows the world's clock**, which moves only while you travel or wait.
- **The art** is pixel art in the men's style and at their size (`tools/siege_sprites.py`,
  2.4 arena units a pixel), each land's way: the Vardish trebuchet with its iron-bound
  counterweight, the Kharzani mangonel with its haul ropes and a pot of naphtha, the Ryumon
  bamboo thrower; towers roofed with hides, palm mats or lacquered planks, battlemented on
  top, rolling on their wheels and then lowering a bridge; a roofed ram that swings;
  mantlets of planks or bundles of bamboo; springalds on the wall. Every engine casts a
  shadow as long as it is tall, and what has burned is drawn charred. Stones and naphtha
  pots grow as they climb toward you; fire flickers in four frames; fallen wall is heaped
  rubble in the walls' own stone. Crews stand behind their engines (`CREW_REACH` 100),
  mantlets in front of their bows.

### Measured

`tests/siege_probe.gd`, AI against AI on a Vardish castle, 16 seeds a case:

| Assault | Attacker wins | Planned |
| --- | --- | --- |
| Even, ladders only (off the march) | 0 of 16 | 0% |
| Half again, ladders only | 3 of 16 | at most 35% |
| Half again, ram and ladders | 9 of 16 | 55–65% |
| Even, full train vs bolt throwers and a postern | 1 of 16 | 30–45% |
| Half again, the same | 15 of 16 | 75–85% |
| Half again, full train vs full works | 12 of 16 | 50–60% |
| Twice, ladders only vs full works | 15 of 16 | always |

Preparing a siege and building works both move the odds the way they should, but the
curve is steeper than planned: an even assault on a castle stays very hard even with a
full train (the garrison's foot meets the breach braced and the stormers' bows stand just
out of bowshot of the walk), and half again with engines is close to certain. The knobs,
if that should change: `STONE_SPLASH`, `TOWER_CLIMB`, the stand-off share, and how long the
AI waits for a breach.
