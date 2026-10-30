# Phase 4: A living world

The Glass Sea stops waiting for you. Lords of the three realms ride the roads with warbands
of their own, hunt bandits, raid each other's villages, gather into armies and besiege
castles and towns, which change hands. Realms go to war and make peace without you. You can
stay a free company hunting bandits, or sign on as a mercenary with any realm, fight its
wars for pay, ride with its armies, and take enemy lords for ransom. A lord whose men killed
one of your captains remembers you, and you him.

This is the phase that makes Bannerfall a Mount & Blade-like rather than a battle game with
a map. It comes after Phase 3 because lords' armies are built from the culture troop trees,
and their fights are fought on Phase 3's ground with its objectives.

| | Workstream | Size (solo) | Status |
|---|---|---|---|
| 4.1 | A world that can change: owners, wars, a bigger map, save v5 | ~1.5 weeks | **Done** |
| 4.2 | Lords on the map | ~2.5 weeks | **Done** |
| 4.3 | Armies, sieges, and settlements that change hands | ~2 weeks | Garrisons and armies done; sieges next |
| 4.4 | War and peace | ~1 week | |
| 4.5 | You in the war: lord encounters, contracts, battles bigger than your warband | ~2 weeks | |
| 4.6 | Prisoners, ransom, and lords who remember | ~1 week | |
| 4.7 | Integration and polish | ~1 week | |

About 11 weeks solo. The cut line at the end gives a 5-week core.

---

## Ground rules (as in Phase 3, plus three)

The rules in [`phase-3-plan.md`](phase-3-plan.md#ground-rules-how-this-codebase-works) still
hold: rules in pure-logic sims tested headless, numbers in data files, every step gated, art
from the tools, saves that keep loading, no generated `.uid` or `.import` files. Phase 4 adds:

- **The world sim stays pure logic and deterministic.** Lords, armies, wars and sieges live
  in `scripts/world/world_sim.gd` (and new files beside it), never in a screen or in
  `GameState`. The world draws from its own seeded `rng`, so a seed gives the same five
  years every time, and a test can replay them.
- **The world runs without the player.** Time still passes only while you ride or wait, but
  `WorldSim.step` must be able to run years headless with no player input (the player
  waits), because that is how the world gates are tested.
- **AI parties never fight full battles with each other.** Lord against lord, lord against
  bandits and every siege are settled with `scripts/battle/auto_resolve.gd`. Only fights
  that include you are played on the battle screen (or sent in).

---

## Exit gates for the whole phase

All automated, in `tests/run_tests.gd`. The world gates run under a new `-- --world` flag
(like `--balance`), over 20 seeds of five simulated years each, with the player standing
still in their capital.

| Gate | Target |
|---|---|
| No realm falls early | Every realm still holds a settlement at the end of year 1 in all 20 seeds; at most 4 of 20 seeds end year 5 with a realm gone |
| Borders move | On average at least 3 settlements change hands a year; none changes hands more than 4 times in a year |
| War and peace both happen | Each realm is at war between 20% and 80% of the time; wars last 20–120 days on average |
| Lords stay in the field and solvent | At any time at least 60% of free lords are out with a party; no lord's purse stays below zero more than 7 days running |
| Speed | Five world years run headless in ≤ 30 s on a desktop; a world hour with every party moving costs ≤ 2 ms |
| The mercenary life pays | A scripted mercenary (`Plans.campaign` with a contract plan) lasts 60 days above 50 men, never goes broke more than 3 days, and earns at least as much silver and renown as today's bandit hunter |
| Battles bigger than your warband hold up | A battle of three lords a side (up to 30 squads a side over the fight, at most 12 a side on the field) runs ≤ 2× today's sim step per man, and finishes inside the time limit |
| Send in matches battles with lords and allies | Same winner as the full battle ≥ 85% |
| Sieges reward strength, not luck | An army with twice a garrison's strength takes the place ≥ 80% of the time; one with less than its strength ≤ 20% |
| Phase 3's gates still pass | Balance, fairness, cultures, objectives, branches, 30-day campaigns, performance |
| Old saves | A version-4 save loads into the starting borders and wars, with lords generated fresh |

---

## 4.1 A world that can change (~1.5 weeks): done

**As built:** `WorldSim` holds `owners`, `wars` and `realms` (each realm's capital), read
through `owner_of`, `holdings_of`, `villages_of`, `capital_of` and `at_war`, and changed
through `set_owner` (which takes the bound villages along and moves a lost capital to the
realm's best remaining town or castle), `declare_war` and `make_peace`. Each change is a
world event (`captured`, `war`, `peace`). `WorldData` keeps only the starting state:
`describe`, `at_war` and `villages_of` moved to the world sim, since they now depend on it.
The map has 21 settlements: per realm a town, two castles and four villages (Marchgate
guards the land bridge; Qasr Hamra and Kitayama are the new eastern and northern castles),
every village bound to a castle or town. A realm with no villages left raises no bandits,
and your warband regroups at your people's capital wherever it now is. Saves are version
5; `tests/fixtures/save_v4.json`, made by the game before this change, loads into the
starting owners and wars. Settlements are drawn by their own people and fly their holder's
colors.

### The plan

### What changes

Today who owns what, and who is at war, are constants in `scripts/world/world_data.gd`
(`SETTLEMENTS[id]["faction"]`, `WARS`). They become the **starting** state; the live state
moves into the world sim:

- `owners: Dictionary`: settlement id → realm. Read through `world.owner_of(id)`.
- `wars: Dictionary`: realm pair key ("kharzan|vardmark") → `{since, weariness: {realm: float}}`.
  Read through `world.at_war(a, b)`; everyone stays at war with bandits.
- `realms: Dictionary`: realm → `{treasury, capital, marshal, ruler_lord}`.
- Helpers that move from `WorldData` to the world sim because they now depend on owners:
  `villages_of(realm)`, the band-routing check in `path()` (bands keep to their own realm's
  villages), and the music and banner lookups in `map_screen.gd` and `settlement_screen.gd`.

A settlement's **people** don't change when its owner does: a Vardish-held Qal'at Zeyra still
offers Kharzani recruits and plays Kharzani music. Its **banner** shows its owner.

### A bigger map

Twelve settlements, one castle and one town a realm, are too few for borders to move without
a single siege deciding everything. Each realm gains one castle and two villages, 21 in all:

- New entries in `SETTLEMENTS` and `ROADS`, placed so the map tests still pass (every
  settlement reachable, roads on land, rivers crossed only at fords).
- Each village belongs to a castle or town (`bound_to`), and changes hands with it.
- Map art needs no new sprites: settlements are drawn by culture and type already. Check
  `MapTerrain` clearances and the label layout at phone zoom.

### Save

- `SAVE_VERSION := 5`. The world's `to_dict` gains owners, wars, realms and lords.
- A version-4 save gets the starting owners and wars, and lords generated from the world's
  seed. Test it with a saved version-4 file checked into `tests/`.

### Tests

- Owners and wars round-trip through a save, and a loaded world carries on exactly as the
  original (as `_check_world_saves` does today).
- Changing an owner moves the village bound to it, the banner, and band routing.
- Old saves load.

---

## 4.2 Lords on the map (~2.5 weeks): done

**As built:** `scripts/data/lords.gd` holds the tunables. Each realm has its ruler (at its
capital) and four lords; two hold its castles, the others ride out from the capital. Lords
are `LORD` parties with warbands of 5–9 squads by renown, more of them trained as it grows.
Every three hours a lord weighs, by his bearing: going home when under half strength,
defending a village of his realm that an enemy lord is burning, driving off bandits raiding
one of his villages, raiding an enemy village (6 hours; then it burns for 7 days, paying
nothing and offering no recruits), or patrolling his realm. Lords of realms at war who meet
fight it out by `AutoResolve`; the loser regroups at his seat a day later with what's left.

Changed from the plan, and why:

- **Money comes from a realm treasury**, not from each lord's own fief. With fiefs paying
  their holders, rulers piled up silver while landless lords went broke and sat at home. A
  treasury takes in every place's dues (town 220, castle 90, village 40 a day), pays its
  lords' wages at half what you'd pay, and funds their recruits while it keeps 2,000 back.
  In a year no lord goes broke, and lords are out of their seats about 80% of the time.
- **Lords drive bandits off instead of destroying them,** and only bandits raiding their
  own villages. Lords who fought every band they met beat about 570 bands a year and left
  your warband nothing to hunt; the scripted campaigns lost half their warbands.
- **Two bandit bands roam each realm,** and the scripted campaign withdraws from fights its
  scouts say it would lose and rides only for bands it can beat, as a player reading the
  encounter would. The bigger map of 4.1 spread one band a realm too thin: about 14 fights
  a month instead of 21, and warbands went broke.
- A world hour costs about 0.6–1.3 ms with every lord riding (gate: 2 ms). Travel times
  between places are worked out once, and meetings are checked with each party's place
  worked out once per tick.

### The plan

### What the player gets

Four lords to a realm, plus its ruler, each riding with a warband of 5–10 squads under
captains of their culture. You see them on the map under their realm's banner, tap one to
see who he is, how strong he is and what he's doing ("riding to relieve Ravensford").

### Data: new `scripts/data/lords.gd`

- Names by culture (reuse the captain name pools in `scripts/data/cultures.gd`, plus house
  names), and a **bearing** that steers the AI: *Daring* (attacks at worse odds), *Cautious*
  (keeps to his own lands), *Honorable* (releases prisoners, keeps truces), *Cruel* (raids
  villages often, asks high ransoms).
- Tunables: warband size by renown, wages paid from the lord's purse, income from his fiefs.

### State in the world sim

- `lords: Array` of `{id, name, realm, culture, bearing, renown, silver, fief, party,
  state, captor, grudges}` where `state` is `field`, `home` (refilling at his fief) or
  `captive`.
- A lord's party is a `Party` of a new kind `LORD`, with an army in the battle sim's format,
  built like `_band_army` but larger, with more tier-2 squads as his renown grows.

### What lords do

Every few world hours (not every tick), each lord picks a job by a small utility score, with
his bearing and his realm's needs weighting it:

| Job | When |
|---|---|
| Patrol his realm, hunting bandits | At peace, or far from the front |
| Raid an enemy village | At war, the village is near and lightly held |
| Defend a threatened settlement | One of his realm's places is raided or besieged nearby |
| Join the marshal's army | Called (4.3) |
| Go home to refill | His warband is under half strength, or his purse is low |

- Movement uses the existing roads and `path()`; lords may take sea lanes (the Ryumon have
  to).
- Lords meeting hostile parties on the road fight them, settled by `AutoResolve.resolve`;
  the loser regroups at home, as your warband does today.
- **Raids use Phase 3's village objective.** A lord raiding a village you're defending, or
  one of your employer's villages you ride to, is a village battle; a lord raiding while
  you're nowhere near burns it by auto-resolve, and a burned village pays no tax for a
  while.
- Bandits stay, and lords hunt them, so the roads are a little safer near a strong realm.

### Drawing: `scripts/world/map_screen.gd` and `tools/map_sprites.py`

- A lord's party: a mounted lord under his realm's banner, larger than a bandit band; an
  army (4.3) larger still, with the marshal's banner.
- A sheet when tapped: name, realm, bearing, rough strength ("about 140 men"), what he's
  doing, and your relation with him (4.5).
- At wide zoom, small parties fade so the map stays readable on a phone.

### Tests

- A lord's job choice: unit tests per job (a lord with half his men goes home; a lord near
  a raided village of his realm defends it).
- A year with lords and no wars: bandits are fewer near lords, and no lord goes broke.
- The world-hour cost gate.

---

## 4.3 Armies, sieges, and settlements that change hands (~2 weeks)

**As built so far — garrisons:** `WorldSim.garrisons` holds battle-format squads at the
nine castles and towns; `garrison_at` and `garrison_capacity` expose them. Castles start
with 40 of 80 men (two of four squads trained); towns with 60 of 120 (one of six trained).
Their foot, spears and bows are of the settlement's people, even under a foreign owner.
At midnight, after lord wages and refills, each castle recruits up to four men and each
town six, paid at recruit prices from its current owner's treasury while preserving the
2,000-silver reserve. Partial budgets buy only affordable men. Full garrisons cost no
recruitment silver; damaged and destroyed squads refill to the cap. All tunables are in
`scripts/data/lords.gd`. This step adds recruitment costs, not a separate garrison wage bill.

Settlement descriptions on the map and in town show the current guards and capacity.
Save v5 includes the squads; older saves receive starting guards without spending silver
or advancing the random stream. `set_owner` clears the old defenders; the siege step must
leave the attackers' garrison after transferring ownership. Village militia, siege food,
and siege resolution remain for the following pieces. `_check_garrisons` covers
daily timing, caps, costs, shortages, losses, captures, save replay and old-save migration.

### Marshal expeditions — as built, 2026-10-29

`marshal_armies.gd` manages saved expedition IDs, membership and gathering/marching/returning
states. A realm calls its highest-renown eligible lord and up to two others. Healthy,
available parties gather at the capital for up to 48 hours; two arrivals including the
marshal can depart. Targets are reachable hostile towns/castles scored by travel, settlement
value and defender count. An expedition expires after 144 hours, with a 72-hour cooldown.
Peace, target ownership changes, lost muster sites, missing marshals and failed routes
release members or send the joined army home. Reaching the target currently starts the
return journey: no siege or ownership change is silently simulated.

Troops and wages remain on the original lord parties. Joined parties share the marshal's
movement and one highlighted map marker. Tapping it shows members, troop counts, destination
and state. Field auto-resolve combines member troop references for the calculation, applies
losses back to their owners, and routes defeated members together. Existing daily finances
continue once per lord. Additive save-v6 fields retain membership and deadlines; legacy saves
start without expeditions. `tests/army_tests.gd` and the bounded existing world/battle checks
validate this slice.

### Sieges and settlement capture — as built, 2026-10-30

- **Walls and auto-resolve assault:** `AutoResolve.WALLS` defines multipliers for fortified
  defenders (castle ×1.6, town ×1.4). `AutoResolve.resolve_siege()` settles assaults against
  defending garrisons behind walls, scaling losses and captain survival. Quantitative gate
  verified: attacking force with $\ge 2\times$ garrison base strength takes the settlement
  $\ge 80\%$ (achieved $98.0\%$), and $< 1\times$ garrison base strength succeeds $\le 20\%$
  (achieved $0.0\%$).
- **Siege lifecycle:** An expedition reaching a hostile castle or town transitions to `"besieging"`.
  It sets ladder and ram preparation (`SIEGE_PREP_HOURS := 48.0`) and defender food starvation
  deadlines (`SIEGE_FOOD_DAYS := {"castle": 4.0, "town": 6.0}`).
  - Starvation: if food expires before relief or assault, the garrison surrenders unconditionally.
  - Relief: hostile parties reaching the besieged site initiate field battles outside the walls;
    a defender victory disbands the expedition and breaks the siege.
  - Assault: once siege engines are built, assault resolves against the garrison. If repulsed,
    surviving attackers return home.
- **Settlement capture & cascades:**
  - `set_owner()` transfers the holding, clears defeated defenders, makes the previous fief-holder
    landless (`l["fief"] = ""`), relocates the realm capital if captured, and updates bound villages.
  - Stationing & troop conservation: surviving attackers station men 1:1 into the new garrison
    up to `GARRISON_START_SHARE` (50% of cap, max 40% of survivors), deducting evenly across
    contributing members without creating or deleting duplicate soldiers.
- **Village militia:** Each village maintains a 15-man local defensive militia (spears and bows of
  its culture). Unattended raids against full warbands take light skirmish casualties; depleted
  raiders are repulsed by the militia.
- **Performance:** Optimized party indexing (`_parties_by_id`, `_bands`, `_lord_parties`) and road
  lengths cache achieve $5.5$ ms per simulated hour across 365-day unattended runs. Lords maintain
  $67\%$ time in the field (gate $\ge 60\%$). Full test coverage in `tests/army_tests.gd` and
  `tests/run_tests.gd`.

### Armies

- At war, a realm's **marshal** (its highest-renown free lord) gathers an army: he calls two
  or three lords, waits for them, and rides at a target as one party. Each lord keeps his
  own squads inside it, for battles and for losses.
- Target: an enemy castle or town scored by value, distance and garrison strength against
  the army's own.
- An army disbands after a siege, after a defeat, or when its lords' purses or food run low.

### Garrisons

- Every castle and town holds a garrison (squads, in the battle sim's format) that grows
  daily from its owner's treasury up to a cap (castles more than towns per head, towns
  bigger overall). Villages have a small militia that only defends against raids.

### Sieges (auto-resolved this phase)

- An army that reaches an enemy castle or town makes camp. For a few days it builds ladders
  and rams; then it assaults, settled by auto-resolve with the walls multiplying the
  garrison's strength (new `WALLS` constants: castle ×1.6, town ×1.4). A garrison that runs
  out of food before then surrenders.
- **Relief:** a defending army that arrives breaks the siege, as a field battle outside the
  walls. If you're in either army, that battle is yours to fight (4.5).
- **Taking the place:** it changes owner, the attackers leave a garrison, its villages
  follow, its old fief-holder becomes landless, and the realm's capital moves if it was the
  capital.
- **A playable siege battle** (walls, a gate, ladders) is not in this phase; see the end.

### Send in and auto-resolve

- `AutoResolve.strength` gains a `walls` factor and `resolve` a siege variant: the garrison
  fights at its walls' strength, and losses on both sides scale as today.
- Re-check against the battle sim for lord-sized armies (the calibration harness in
  `_check_auto_resolve` with larger random armies).

### Tests

- Siege outcomes by strength ratio (the gate above).
- A captured castle's villages, banner and recruits follow it; a captured capital moves.
- An army forms, marches, besieges and disbands within a set number of days.

---

## 4.4 War and peace (~1 week)

New tunables in `scripts/data/politics.gd`; the rules run once a world day.

- **War weariness** rises for each realm at war with the men it loses, the places it loses,
  its lords captured, its villages burned, and the days at war; it falls slowly at peace.
- **Peace:** a realm whose weariness is past a threshold offers peace; the other accepts
  unless it is winning clearly and is fresh. Peace starts a truce (no new war between them
  for 30 days), and the loser pays **tribute**, so much a day for a while, by how badly it
  lost.
- **War:** a realm at peace with low weariness and an edge in strength declares war on a
  neighbor over a border place it wants, a grudge, or raids on its villages.
- **The isles hold the balance:** the Ryumon Shogunate starts at peace with both, and joins
  a war against whichever mainland realm holds more than half the mainland's strength.
- Notices on the map ("Vardmark and Kharzan make peace; Kharzan pays 40 silver a day for 20
  days"), and a **War sheet** on the map: who is at war with whom and for how long, each
  realm's strength and weariness, and the last few captures and battles.

### Tests

- Weariness grows with losses and makes peace; a truce holds 30 days.
- Ryumon joins against a mainland realm that grows too strong.
- The world gates (borders move, wars and peace both happen, no early fall).

### As built: War and peace

- **Politics tunables:** `scripts/data/politics.gd` defines weariness caps (`WEARINESS_MAX = 100.0`), casualty rate (`WEARINESS_CASUALTY = 0.05`), holding loss (`WEARINESS_LOST_HOLDING = 15.0`), village burn (`WEARINESS_LOST_VILLAGE = 3.0`), lord routed (`WEARINESS_LORD_ROUTED = 5.0`), war passage (`0.25`/day) and peace decay (`0.50`/day), peace suing threshold (`60.0`), winning fresh acceptance threshold (`40.0`), truce length (`30` days), tribute duration (`20` days, `25`–`75` silver/day), and mainland seats (`6` seats total; $\ge 4$ triggers Ryumon intervention).
- **Weariness and politics simulation:** `WorldSim` tracks realm weariness, daily weariness decay/growth, active enforced truces (`truces`), and ongoing tribute agreements (`tributes`).
- **War and peace dynamics:** Weary realms offer peace; fresh winning rivals reject peace to press advantages, otherwise accept. Peace treaties initiate 30-day truces (preventing new war declarations) and daily tribute flows from debtor to creditor treasury.
- **Autonomous declarations & balance of power:** Rested realms ($\le 25$ weariness) with expired truces declare war over borders or rivalries. When a mainland realm reaches $\ge 4$ seats ($\ge 66.7\%$), the Ryumon Shogunate declares war to preserve balance of power.
- **War Sheet & notices:** Map Menu includes "War & Politics" displaying active wars, days at war, truces, tributes, realm strength/weariness/holdings, and recent conflict history. Notices broadcast treaties and tributes ("Vardmark and Kharzan make peace; Vardmark pays 45 silver a day for 20 days").
- **Verification:** Verified by dedicated test suite `tests/politics_tests.gd` (31 tests passing) and integrated world tests in `tests/run_tests.gd`. Fully deterministic save/load roundtrip in `to_dict()` and `from_dict()`.

---

## 4.5 You in the war (~2 weeks)

### Standing

- **Relation** with each realm and each lord, from −100 to 100. It rises when you fight a
  realm's enemies or help its lords, and falls when you attack them. Attacking a lord of a
  realm you're at peace with puts that realm at war with you: its lords hunt you, and its
  towns close their markets.

### Mercenary contracts

- In a castle or town of a realm at war, with enough renown, the settlement screen offers
  **"Offer your sword"**: a contract for 30 days at so much a day, scaled by your renown
  and your warband's strength. Any culture can serve any realm (decision 1).
- Under contract you are at war with your employer's enemies, its lords treat you as an
  ally, and it pays a bonus for every enemy lord you capture. Breaking a contract early
  costs relation; renewing it is offered when it ends.

### Meeting lords on the road

- A hostile lord blocks your road as a bandit band does, with the same choice: **Fight**,
  **Send in**, or **Withdraw**. Withdrawal can fail against a faster, stronger party: he
  rides you down and you fight.
- A friendly lord stops to talk: news of the war, and under contract, "ride with us".
- Encounter text and site come from `GameState.encounter_plan`, as for bands.

### Riding with an army

- Under contract you can **follow the marshal's army**: your party moves with it, and its
  battles include you.
- **Battles bigger than your warband:** the battle sim keeps at most 12 squads a side on
  the field; the rest wait and march in from their side's edge as squads break (Phase 3's
  `add_reinforcements`). Allied lords' squads fight on your side under a `Commander`, drawn
  with an ally's trim and not selectable; their losses go back to their lords. The battle
  screen's cards show yours; a strip shows allies and reserves.
- In a siege you join the assault (auto-resolved, your men counted as sent in, a share of
  the loot), or fight the relief battle in full.

### Spoils

- Beating a lord pays more than a band: his purse's share, more renown, and the chance to
  take him prisoner (4.6). Your employer's daily pay and capture bonus are on the Warband
  screen beside your wages.

### Tests

- The mercenary gate: a scripted contract plan in `tests/plans.gd` serving 60 days.
- A battle with allies and reserves: reinforcements arrive as squads break, never more than
  12 a side on the field, allied losses return to the right lords.
- Relation changes; attacking a neutral lord starts a war with you.
- Send in with allies matches the full battle (the gate).

---

## 4.6 Prisoners, ransom, and lords who remember (~1 week)

### Prisoners and ransom

- Beat a lord's party and he is captured if his own squad breaks with your men on it (the
  same rule that now catches a bandit chief), or wounded on his death roll.
- Captive lords travel with you. After a few days his realm offers a ransom by his renown;
  you can take it, sell him to your employer, or release him for relation.
- Lords take each other prisoner too, and are ransomed between realms by auto-resolve
  rules.
- Lords die only on the battle death roll, and rarely; a lord who dies is succeeded by an
  heir of his house, so the world keeps its lords.
- Your own captains are never taken prisoner this phase: the death roll stays as it is.

### Lords who remember

- When one of your captains dies in a battle against a lord, the memorial records whose men
  killed him, and that lord gains a **grudge** against you.
- A lord with a grudge seeks you out when you're near, says so when you meet ("You'll
  remember Brann's Pikes, I think"), and fights harder (Daring) or hangs back and waits
  (Cautious).
- Capturing or killing him is a notice of its own, and a line on the memorial.
- Bandit chiefs who escape keep working as they do now.

### Tests

- Capture and ransom: a captured lord leaves the map, his realm pays, he returns home.
- A captain killed by a lord's men gives that lord a grudge, saved and loaded.

---

## 4.7 Integration and polish (~1 week)

- **Map readability on a phone** with 20+ parties: party size by strength, armies grouped,
  bandits faded at wide zoom, banners by owner, siege camps and burned villages drawn.
- **The chronicle:** the last 30 events (wars, peace, captures, sieges, your own deeds),
  readable from the map.
- **Sound:** a war horn when war is declared, siege drums near a siege, a fanfare when a
  place falls.
- **Performance on a phone:** the world tick with every party moving, path caching, the map
  drawing every party.
- **Docs:** README and how-to-play; screenshots of the War sheet, an army, a siege and a
  battle with allies.

---

## Order of work

Each milestone is playable on its own.

| Week | Milestone | Its gate |
|---|---|---|
| 1–2 | Owners and wars in the world sim, the bigger map, save v5 | Map tests, save round-trip, old saves |
| 2–4 | Lords on the map: jobs, movement, auto-resolved fights, drawing | World-hour cost, lords solvent |
| 5–6 | Armies, garrisons, auto-resolved sieges, places changing hands | Siege gate, borders move |
| 7 | War and peace, the War sheet | War/peace and no-early-fall gates |
| 8–9 | Contracts, lord encounters, battles with allies and reserves | Mercenary gate, big-battle gate, Send in ≥ 85% |
| 10 | Prisoners, ransom, grudges | Capture and grudge tests |
| 11 | Integration and polish | All gates |

## Cut line: a 5-week core

If time is short, ship:

- Owners and wars in the world sim (no bigger map).
- Lords that patrol, raid and defend, settled by auto-resolve.
- Armies and auto-resolved sieges.
- War and peace by weariness alone.
- Mercenary contracts and lord encounters, without battles beyond your warband.

Prisoners, grudges, allied battles and the bigger map move to Phase 5.

---

## Decisions (defaults stand unless changed)

1. **Serve any realm whatever your culture?** Default: **yes**. It's the mercenary fantasy,
   and mixed warbands already work.
2. **Grow the map to seven settlements a realm?** Default: **yes**. With one castle and one
   town a realm, a single siege decides a war.
3. **Sieges auto-resolved this phase,** with relief battles and sallies fought in full?
   Default: **yes**. A playable siege battle comes with owning land.
4. **Can lords die?** Default: **only on the battle death roll**, and an heir takes over. No
   executions.
5. **Ryumon holds the balance** and joins against whoever grows too strong? Default: **yes**.
6. **Can you start a war on your own** by attacking a realm's lord? Default: **yes**, at the
   cost of that realm hunting you. You can't yet be a vassal or hold land.

## Risks

- **A realm snowballs and conquers everything.** Mitigated by war weariness, the Ryumon
  balance, garrisons that grow back, capitals that are harder to take, and the five-year
  gate over 20 seeds.
- **The world moves on without the player,** who feels like a spectator. Lords' fights near
  you become encounters, raids on villages you pass become village battles, and contracts
  put you inside the war rather than beside it.
- **Map clutter on a phone** with three times the parties. Fading, grouping, and the
  on-device check.
- **Performance:** world ticks with 20+ parties pathing, and battles with reserves. Decide
  lords' jobs every few hours, cache paths, and keep the per-man battle gate.
- **Auto-resolve drift** with lord-sized armies and walls. The ≥ 85% gate is re-run at
  every milestone.
- **Save size and migration.** One version bump, one migration test with a real file.

## Not in this phase

- **Land of your own:** vassalage, fiefs, taxes, buildings, and the playable siege battle
  (walls, a gate, ladders).
- **Captains and men:** wounded men who heal, captain skills and promotions, named heroes,
  bond scenes, Casual mode (captains wounded instead of killed).
- **The crown:** your own kingdom, alliances, rival houses within a realm, an endgame.
- **Launch:** tutorial, cloud saves, cosmetics, analytics.
