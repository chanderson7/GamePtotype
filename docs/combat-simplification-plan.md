# Bannerfall: fixing the flicker, and a simpler melee

- **Date:** 2026-11-13
- **Status:** proposed. Nothing here is built yet.
- **Goal:** two things seen in battle footage. First, men who flick left and right many
  times a second while their company moves. Second, attacks that end with four to nine
  companies piled onto one spot as a single mixed blob. The flicker has a small, safe fix.
  The pile-up needs a clearer split of roles: the **company** decides where to fight (a
  stretch of one side of its foe, never its centre), and each **man** fights from his place
  in the ranks, stepping out of line to strike and back, on a short tether.

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

## 3. How other games do it

Most games handle automatic melee in one of four ways:

1. **Every man for himself.** Each soldier goes for the nearest enemy. This is Bannerfall
   today, and it's what Total War does when a group is ordered onto one target: a
   Warhammer guide warns that attacking with a hotkey group makes them "converge and blob
   up on the single target you've selected" ([gamepressure][tww-blob]). Bannerlord's
   *Charge* is the same: troops advance into melee and break the formation's shape
   ([gamepressure][bl-charge]).
2. **A formation with a tether.** Men fight one on one but are held to their place.
   - Bannerlord splits formation AI from individual AI. A soldier "told to hold in a shield
     wall formation … should act defensively and try to maintain its position"
     ([altchar][bl-ai], [gamebanshee][bl-blog]). Its *Engage* order closes with the enemy
     while keeping the unit's spread ([gamepressure][bl-charge]).
   - A popular mod adds an aggression setting per formation: aggressive breaks ranks more
     often, defensive keeps formation ([nexus][bl-mod]).
   - Total War: Rome II made "guard mode" the default, so units don't chase unless ordered
     ([forums.totalwar.org][rome2-guard]).
   - Rome II and Warhammer III Cathay infantry have a *formation attack* toggle that keeps
     the unit clustered and hard to break ([steam][r2-fa], [steam][tww3-fa]).
3. **Combat along the front.** Medieval: Total War worked out melee for the men in contact.
   Each man strikes one adjacent enemy but can be struck by many. A spear unit's rear
   ranks add defence and charge (two ranks for spears, four for pikes). Each round, a man's
   chance to kill is about 1.9% × 1.2^(attack − defence) ([MTW wiki][mtw], [totalwar.org
   guide][mtw-guide], [forum][mtw-forum]). Field of Glory and Ultimate General resolve
   whole units the same way.
4. **Attack slots round a target.** Classic RTS melee (Warcraft III-style surrounds): the
   target has a ring of evenly spaced slots, each attacker takes the nearest free one, and
   a latecomer with no free slot waits or picks another target. This is common practice
   rather than anything one game documents; searching found only developers asking for it
   ([unity][rts-surround], [unreal][ue-block]).

**What Bannerfall takes from them.** Approach 2 for men, so they still step out and
strike, as you want. Approach 4 at company level, so companies claim a stretch of a
foe's side instead of its centre. And one idea from approach 3: rear ranks stay back and
step up, while spears strike from the second rank. The code for approach 2 already exists:
it's the line fight behind `formation_melee` (`FORMATION_LEASH := 10`, `CAV_LEASH := 22`,
`WING_LEASH := 40`). It is switched off, though, and even switched on it covers only foot
fighting foot.

## 4. The model: companies take a side, men fight on a tether

### The company: where to fight

- Every company has four faces (front, two flanks, rear). Each face's width comes from its
  files and ranks.
- An attacker claims a stretch of one face, as wide as its own front, on its side of the
  foe. Its goal is that stretch, set back by its own half-depth. Its goal is never
  `foe.avg`.
- A second attacker on the same face lines up beside the first if there's room. Otherwise
  it takes another face, or another enemy, or waits behind as a reserve (as attack
  positions do today).
- The claim is made when the target is chosen and kept until that face fills up or the foe
  turns more than 45° (hysteresis built in). Going round a corner is two fixed waypoints,
  chosen once.
- **Companies don't overlap.** A moving company stops when its front touches another
  company, friend or foe, and passes a friend beside it (today's `_make_room` idea, at
  company level).
- **The centre never follows the men.** The company's place moves only when the company
  moves. This deletes `sq.center = sq.center.lerp(avg, 0.15)` (`:2408`), the line that
  drags a company into the press after its own men.

### The man: whom to hit, and how far he may go

- **His place.** Every man has a slot in the ranks (`line_slot`, kept by `_rank_up`). When
  a front-rank man falls, the man behind steps into his place.
- **His foe.** He looks for the nearest enemy ahead of his place, favouring his own lane
  (`_line_target`, today's line-fight rule). This applies to every troop type, against
  every enemy: foot against horse and bowmen no longer goes loose.
- **No dogpiles.** At most two men may set on one enemy at a time (a per-man attacker
  count, like the per-squad `focused_by`). If his first choice is taken, he takes the next.
- **The tether.** To strike, he may step out of his place by up to the leash, strike
  (the existing swing, cooldown, lunge and recoil), and walk back once no foe is within
  reach plus leash. The leash depends on what the company is doing:

  | Stance | Leash | Notes |
  | --- | --- | --- |
  | Hold, braced, shield wall | about 4 | barely a step: the line takes the blow |
  | Advance or attack | 10 (`FORMATION_LEASH`) | a step and a lunge |
  | Schiltron | 0 | the ring doesn't open |
  | Horse | 22 (`CAV_LEASH`) | ride into the press, then *Wheel* out to charge again |
  | A front man with no foe ahead | 40 (`WING_LEASH`) | folds in on an overlapped flank |

- **Rear ranks** stay in their slots and push up. Spears strike from the second rank
  where their reach allows.
- **He turns, he doesn't snap.** His facing turns at a capped rate toward his foe. This is
  presentation only.
- Blows, damage, matchups, flank and rear (`_side_of`), brace, shield wall, bonds, fury and
  captains are all **unchanged**. That keeps the balance shift smaller than replacing them
  would.

### Rejected alternative: front math only

Approach 3 alone (damage worked out from the men in contact, men just a picture) is simpler
and cheaper. But nobody would step out to strike, and the death roll, kill counts and
individual blows would lose their footing. Keep it in reserve if phones can't afford
per-man fighting in the biggest battles.

### What goes away

- The loose melee: `_pick_target`'s scramble, `_target_ok`'s "anyone within 50 units",
  and the centre following the men.
- The exceptions that send a fight loose (`_keeps_rank`: horse, bowmen and anyone fighting
  them) and the `formation_melee` flag. Its line fight becomes the only fight.
- `_steer`'s step-by-step dodging, and attack positions' side and corner machinery
  (`_side_point`, `_side_cost`, `_reach_out`). Face claims and two-waypoint corners replace
  them.

### What stays

- All the orders and controls (Advance, Hold, targets, march, lines, slow time).
- Abilities, morale and routing, captains, the death roll, bonds.
- Temperaments and the commander AI's plans, and the terrain rules.
- Every bit of presentation in `combat-feel-plan.md`.
- Sieges keep their man-by-man fight at the wall for now (see below).

## 5. Phases

Each phase lands behind a flag, the way `formation_melee` did. Tests must be green at
every phase, and `-- --balance` must pass before a flag's default flips.

| Phase | What | Done when (probe, 12 v 12 seed 40) |
| --- | --- | --- |
| **0. Flicker** | Section 1's fix | flicks < 50 (from 9,219) |
| **1. Take a side** | Companies claim face stretches, never aim at `foe.avg`, don't overlap, and their centre stops following their men | companies in the busiest spot ≤ 2.5 (from 4.3); merged < 3% (from 11%) |
| **2. The tether** (`tethered_melee`) | The line fight for every troop type and foe, the two-man cap, leashes by stance, horse on the long leash with *Wheel* | most men at one point ≤ 22 (from 35); no man further from his place than his leash plus a body (a new probe line); balance gates pass |
| **3. Clean up** | Flip the default, delete what section 4 lists, update the README's battle section | no loose-melee code outside sieges |

**Sieges stay as they are until the end.** The wall, gate, ladders and breach are fought
man by man on purpose (`siege-defence-plan.md`). Keep that path for `OBJECTIVE_SIEGE`
through phase 3, and decide separately whether ladder heads and the breach become faces
too.

## 6. Checks

- `godot --headless --script res://tests/run_tests.gd -- --balance` (about an hour). Its
  gates: *Advance all* wins about half at most, the tactician at least 70%, mirrored maps
  fair both ways, holding ground pays, each culture a match for the others.
- `tests/battle_feel_tests.gd`: the same seeded battle ends the same with or without the
  screen.
- `tests/formation_tests.gd`, `tests/attack_positions_tests.gd`, `tests/collision_tests.gd`:
  each tests behaviour that phases 1 to 3 replace. Rewrite them to the new rules rather
  than delete them:
  - two companies sent at one foe take two faces, and a third waits;
  - a man never strays further than his leash;
  - no enemy has more than two men on him;
  - a flank hit lands as a flank hit;
  - companies never overlap.
- The trailer recorder (`tools/trailer/`) re-shoots the same seeded battles, for a
  before-and-after you can see.

## 7. Decided, and still open

- **Decided (2026-11-13):** men step out of line to strike, on a tether (section 4).
- **Open:**
  1. How many companies may share one face: as many as fit side by side (proposed), or
     one per face?
  2. Should there be an explicit free-for-all *Charge* order (Bannerlord's *Charge*, or
     Total War with guard mode off), or should the tether always hold?
  3. Phase 2 changes balance. Retune toward today's balance gates, or treat it as a fresh
     balance pass?

[tww-blob]: https://www.gamepressure.com/total-war-warhammer-3/battles/z9f97c
[bl-charge]: https://www.gamepressure.com/newsroom/bannerlord-difference-between-charge-and-engage-tactical-tips/z74f8e
[bl-ai]: https://www.altchar.com/game-news/mount-blade-2-bannerlord-dev-shows-off-ai-melee-combat-overhaul-aFJSl3w4fuLj
[bl-blog]: https://gamebanshee.com/3ua66
[bl-mod]: https://nexusmods.com/mountandblade2bannerlord/mods/791
[rome2-guard]: https://forums.totalwar.org/vb/showthread.php/148720-Help-with-missile-troops
[r2-fa]: https://steamcommunity.com/sharedfiles/filedetails/comments/196851285
[tww3-fa]: https://steamcommunity.com/app/1142710/discussions/0/6171701201027827561
[mtw]: https://forums.totalwar.org/wiki/index.php/MTW_Melee_Combat
[mtw-guide]: https://totalwar.org/strategy/twug/mtw/C3.html
[mtw-forum]: https://forums.totalwar.org/vb/archive/index.php/t-87642.html
[rts-surround]: https://discussions.unity.com/t/how-to-force-units-to-surround-the-enemy/841816
[ue-block]: https://forums.unrealengine.com/t/ai-enemies-block-each-other-while-attacking-player-help/157178
