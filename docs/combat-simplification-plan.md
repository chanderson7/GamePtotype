# Bannerfall: fixing the flicker, and a simpler melee

- **Date:** 2026-11-13
- **Status:** proposed. Nothing here is built yet.
- **Goal:** two things seen in battle footage. First, men who flick left and right many
  times a second while their company moves. Second, attacks that end with four to nine
  companies piled onto one spot as a single mixed blob. The flicker has a small, safe fix.
  The pile-up needs a simpler melee: the company, not the man, is the thing that fights.

All numbers below come from `tools/battle_probe.gd`, which fights a seeded battle headless
with the computer on both sides:

```sh
godot --headless --path . -s tools/battle_probe.gd -- 40 12 12 open        # the trailer's closing battle
godot --headless --path . -s tools/battle_probe.gd -- 4 10 10 woods lines  # with formation_melee on
```

## 1. The flicker

### What it is

Men are drawn top-down and turned by their own facing: `battle_screen.gd:6137` draws each
man at `face.angle()`, and `face` is `so.facing`. In the 12 v 12 battle, 13,270 times a man's
facing turns more than 60° in a single 1/30 s step. In 9,219 of those it turns back the
other way within 0.2 s. On screen that is a man flicking left and right.

| What made his facing flip back and forth | Share |
| --- | --- |
| His **squad's own facing** flipped (he copies it) | 95.2% |
| His squad's engagement toggled on or off | 4.6% |
| His target changed | 0.2% |

### Cause 1: a moving squad faces wherever its next step goes, instantly

`_update_squad` (`battle_sim.gd:2456`) sets `sq.facing = dir` every step the squad moves:
a snap, with no turn rate. Every man of a squad that isn't engaged copies it the same
step (`so.facing = sq.facing`, `battle_sim.gd:3038`). So whenever `dir` swings, all 16 to
20 men of the company swing with it.

`dir` swings because the squad's goal and steering have hard boundaries, re-checked every
step, with nothing to stop them flipping back. Among unengaged squads whose facing flipped
and flipped back (543 such moments in the 12 v 12 battle):

| Branch | Share | Where |
| --- | --- | --- |
| Cavalry steered round a blocking squad, then not, then again | 32% | `_steer`, `battle_sim.gd:2895`: a squad counts as "blocking" only while it sits inside a sharp lateral band, and the side to pass on is the sign of a small offset |
| Cavalry goal jumped between a flank's spot and its "round the corner" waypoint | 27% | `_side_point`, `battle_sim.gd:2610`: `if rel.dot(dir) > 0.0` switches between two points about 100 units apart, and a squad on that line flips every step. The corner itself is picked by sign at `:2613` |
| Cavalry goal jumped, other reasons | 14% | the side spot is measured off the foe's own (moving) men, `_reach_out` |
| Foot hovering on top of its goal | 12% | `if dist > stop + 2.0` (`:2444`): with the goal on the foe's centre or edge, which moves every step, the squad keeps taking tiny steps in any direction and turns to each |
| Foot goal jumps and steering | 11% | as above |
| Wheeling, straight at goal | 4% | |

### Cause 2: engagement flickers at the edge of reach

`sq.engaged` is recomputed every step (`battle_sim.gd:2383`). The grace that keeps
contact from flickering (`ENGAGE_GRACE`) is applied only to line fights
(`_line_fight(...)`). Line fights belong to `formation_melee`, which is switched off
(`battle_sim.gd:437`). So in every real battle a company at the edge of reach goes
engaged, unengaged, engaged. Each time, its men snap between facing their target
(`:3061`) and facing their squad's way (`:3038`).

### Proof

These experiments were run and then reverted; the code is unchanged.

| 12 v 12, open ground | Flicks |
| --- | --- |
| As shipped | 9,219 |
| Squad facing turns at most 4 rad/s instead of snapping | 1,642 |
| That, plus `ENGAGE_GRACE` for every fight (not only line fights) | **33** |

The woods battle (10 v 10, seed 4) goes from 11,296 to **14** with both changes. A man's
facing is never read by the simulation, only by the screen. A squad's facing is read: it
places the men's slots, and it decides front, flank or rear, but only for squads already
engaged (`_side_of`, `:3312`). So the flicker doesn't miscount rear hits. It does cost
real time: a company dithering at a corner isn't advancing.

### The fix (phase 0, small, ship first)

1. **Turn rate.** A moving squad turns toward `dir` at most `SQUAD_TURN` rad/s (about 4; a
   little more for horse) instead of `sq.facing = dir`.
2. **Engagement grace for every fight.** Use `ENGAGE_GRACE` whenever the squad was engaged,
   at `:2383` and in the hold range at `:2307`.
3. **Hysteresis where goals switch:**
   - `_side_point` keeps the corner it chose (`sq.attack_corner`). It switches to the side
     spot only once `rel.dot(dir)` is past a margin, and doesn't switch back.
   - `_steer` keeps the side it chose to pass a blocker for about a second, and lets go of
     a blocker only past the band plus a margin.
   - Arrival gets a dead band: stop within `stop + 6`, and move again only beyond `stop + 14`.
4. **Men turn, they don't snap.** Ease each man's drawn facing toward `so.facing` in the
   screen; the screen already draws routers with a facing of its own (`_pf` in
   `_pose_now`). This is presentation only, so the battle's result can't change.
5. **A test.** `tests/battle_feel_tests.gd`: the seeded 12 v 12 above has fewer than 50
   flicks. `tools/battle_probe.gd` prints the number.

Items 1 to 3 change the simulation slightly, so run `-- --balance` before merging (see
"Checks").

## 2. Why attackers pile onto one point

Each piece below is reasonable alone; together they make the scrum.

- **Everyone goes for the middle.** An attacking squad's goal is its foe's centre,
  `foe.avg` (`:2336`, `:2347`), or a side spot hugging it (`_side_spot`, `:2620`).
  `best_target` (`:2979`) scores by matchup and distance, so several companies often pick
  the same foe. The side system lets two foot plus any number of horse onto one enemy.
- **On contact the block dissolves.** With `formation_melee` off, every engaged company
  fights loose. Each man picks the nearest enemy of his squad's focus (`_pick_target`,
  `:3191`) and walks straight at him. The squad's centre then follows its men into the
  press: `sq.center = sq.center.lerp(avg, 0.15)` (`:2408`). Nothing pulls a man back to
  his place.
- **Companies interleave.** A man keeps fighting anyone within 50 units, whatever squad
  they're in (`_target_ok`, `:3179`). Only the man-against-man push (`_separate`, `:3705`)
  keeps them from occupying the same spot, so the press is as dense as bodies allow.
- **Turning lines on doesn't save it.** With `formation_melee` on, 75% of engaged
  companies still fight loose. Horse and bowmen never keep rank (`_keeps_rank`, `:2702`),
  and anyone fighting them breaks rank too (`in_line`).

| 12 v 12, sampled each second of fighting | Lines off (shipped) | Lines on |
| --- | --- | --- |
| Most men within 50 units of one point | 35 (max 50) | 34 (max 44) |
| Companies those men come from | 4.3 (max 9) | 4.6 (max 8) |
| Men standing nearest a man of another friendly company | 11% | 16% |
| Engaged companies fighting loose | 100% | 75% |

## 3. The simpler model: blocks that meet at a front

**The company is what fights; its men are its picture.** A company is a block: a centre,
a facing, and so many files by so many ranks. It moves, turns at a limited rate, and stops
when it touches another block. When blocks touch, the combat is worked out along the line
where they touch, not man by man. Men always stand in their slots. The lunge, flinch,
shove and fall the screen already draws make them look alive.

### Approach: a stretch of a face, not the centre

- Every block has four faces (front, two flanks, rear). Each face's width comes from its
  files and ranks.
- An attacker claims a stretch of one face that is as wide as its own front, on its side
  of the foe. Its goal is that stretch, set back by its own half-depth. Its goal is never
  `foe.avg`.
- A second attacker on the same face lines up beside the first if there's room. Otherwise
  it takes another face, or another enemy, or waits behind as a reserve (as attack
  positions do today).
- The claim is made when the target is chosen. It is kept until that face fills up or the
  foe turns more than 45° (hysteresis built in). Going round a corner is two fixed
  waypoints, chosen once.

### Contact: blocks don't overlap

- Company-to-company collision uses oriented rectangles. A moving block stops at contact,
  friend or foe. A friend in the way is passed beside (today's `_make_room` idea, at block
  level).
- Contact records which face of the defender was touched, from the attacker's position
  against the defender's facing (the same rule `_side_of` uses). So flank and rear stay
  exactly as meaningful as now, and simpler to read.

### Resolution along the front

For each pair of blocks in contact, every tick:

- **Men fighting** = the overlap of the two touching edges ÷ man spacing, capped at the
  files. Spearmen also strike from the second rank (×1.5): that is the reach advantage,
  kept simple.
- **Damage** = men fighting × damage × the matchup bonus (`sq.bonus`). Then multiply in, as
  today: flank or rear (`FLANK_POWER`, `REAR_POWER`, rear morale shock), brace, shield wall,
  bonds, fury, captains, terrain (height, wood, ford, by where the block stands).
- **Casualties come off the back ranks.** The front stays full until the company is thin
  (`_rank_up` already does the bookkeeping). The screen draws a front-rank man falling and
  the man behind stepping up.
- **Ranged:** volleys and arrows as now, loosed from the block. Bowmen caught in contact
  fight at the front with blades (`SIDEARM`).
- **Cavalry:** a contact made above charge speed is the charge (impact and shove, as now).
  After a few seconds in contact the riders wheel out to charge again, which already
  exists. Horse never become a loose swarm.
- **Schiltron:** a block with no flanks or rear: every face counts as front.

### What goes away

- The loose melee: `_pick_target`, `_target_ok`, men walking in a fight, and the centre
  lerping after them.
- `_fight_in_line`, `_line_target`, `_wing_target`, the `formation_melee` flag and its
  grace exceptions.
- `_steer`'s step-by-step dodging; the side/corner machinery of attack positions
  (`_side_point`, `_side_cost`, `_reach_out`). Face claims and two-waypoint corners
  replace all of it.
- The man-against-man separation solver in fights (keep a cheap one for routers and the
  dead).

The cost of a fight drops from every man against every nearby man to one calculation per
pair of touching companies.

### What stays

All the orders and controls (Advance, Hold, targets, march, lines, slow time), abilities,
morale and routing, captains, the death roll, bonds, temperaments and the commander AI's
plans, terrain rules, and every bit of presentation in `combat-feel-plan.md`.

## 4. Phases

Each phase lands behind a flag, the way `formation_melee` did. Tests must be green at
every phase, and `-- --balance` must pass before a flag's default flips.

| Phase | What | Done when (probe, 12 v 12 seed 40) |
| --- | --- | --- |
| **0. Flicker** | Section 1's fix | flicks < 50 (from 9,219) |
| **1. Faces, not centres** | Approach by claimed face stretch, blocks stop at contact, men stay leashed to their slots in every fight (not only foot against foot) | most men at one point ≤ 22, from ≤ 2.5 companies (from 35 / 4.3); merged < 3% |
| **2. Front resolution** (`block_melee`) | Block collision and front-based damage. Old per-man melee still there for comparison | balance gates pass; sim cost per tick lower than now on the 12 v 12 |
| **3. Clean up** | Flip the default, delete what section 3 lists, update the README's battle section | no loose-melee code left outside sieges |

**Sieges stay as they are until the end.** The wall, gate, ladders and breach are fought
man by man on purpose (`siege-defence-plan.md`). Keep that path for `OBJECTIVE_SIEGE`
through phase 3 and decide separately whether ladder heads and the breach become faces too.

## 5. Checks

- `godot --headless --script res://tests/run_tests.gd -- --balance` (about an hour). Its
  gates: *Advance all* wins about half at most, the tactician at least 70%, mirrored maps
  fair both ways, holding ground pays, each culture a match for the others.
- `tests/battle_feel_tests.gd`: the same seeded battle ends the same with or without the
  screen.
- `tests/formation_tests.gd`, `tests/attack_positions_tests.gd`, `tests/collision_tests.gd`:
  each tests behaviour that phases 1 to 3 replace. Rewrite them to the new rules rather
  than delete them: two companies sent at one foe take two faces, a third waits; a flank
  hit lands as a flank hit; companies never overlap.
- The trailer recorder (`tools/trailer/`) re-shoots the same seeded battles, for a
  before-and-after you can see.

## 6. Open questions

1. How many companies may share one face: only as many as fit side by side (proposed), or
   one per face as the simplest rule?
2. Should men still visibly step out of the line to strike (a lunge and back), or hold
   the line exactly?
3. Phase 2 changes balance. Retune toward today's balance gates, or treat it as a fresh
   balance pass?
