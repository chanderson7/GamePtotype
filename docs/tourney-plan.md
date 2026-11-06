# Riding the lists: a pass you play, and tourneys abroad

**Status: planned.** Builds on the tourney in `docs/crown-court-and-muster-plan.md`: today only
your crown holds one, and your captains' bouts resolve as lines of text.

Two changes, built together:

1. **A pass you play.** When one of your captains rides, you ride the pass: a lance to
   couch and one tap to strike as the riders close. Your timing moves the odds. Lords'
   bouts against each other run on their own.
2. **Tourneys abroad.** Rulers and rich lords of other realms sometimes call lance games
   instead of a feast. You're invited like any gathering, enter up to three captains, and
   ride for the purse, renown and the host's Regard.

Nothing here makes *you* a fighter. Your captains still ride; your hand is on the lance
for the moment that decides a pass. Whether you can be hurt is a question for another plan.

## 1. The pass

### What you see

A scene of its own, `scenes/lists.tscn` (`scripts/menu/lists.gd`), entered from the hall's
*Ride the lists* and returning to it, the way the dance does (`Scenes.dance_return`).

- The tilt from the side: the barrier across the middle, the stands behind it hung with the
  banners of the lords in the hall (`Heraldry.realm_banner`), your rider on the left and
  the champion on the right, drawn from the cavalry sprites each culture already has
  (`vardish_knights`, the Kharzani and Ryumon horse), scaled up the way the hall draws its
  people.
- Above the riders, a **strike bar**: a marker runs from your side to the champion's as the
  horses close, with a lit window near the middle. Under it, the names: "Ansel against
  Bahram's champion · second pass of the bracket".
- The crowd under the stands as a row of heads; they rise on a strike.

### How a pass plays

- Horn. Both riders start at a walk, then the pass runs **2.4 seconds** from spur to
  strike; the marker runs with it.
- Hold the screen to **couch** the lance (the rider leans, the marker's window lights).
  Release to **strike**. One tap decides it; there's no second chance in a pass.
- Where the release lands against the window sets the strike's quality:

  | Release | Quality | Your skill is multiplied by |
  |---|---|---|
  | inside the inner window | **true** | 2.0 |
  | inside the outer window | fair | 1.3 |
  | outside it, early or late | glancing | 0.7 |
  | never released | the lance drops | 0.4 |

- The pass is then decided by the odds the bracket already uses (`CrownCourt._skill`:
  60 + 4 per battle + kills ÷ 10, +25 for a hero, against 60 + a quarter of the lord's
  renown), with your side multiplied as above. A green captain (60) against a renowned
  lord's champion (85) rides at 41% left to himself, 59% on a true strike, 33% glancing. A
  hero (85) on a true strike: 67%.
- The window widens with the captain: **±0.08 s** inner and **±0.22 s** outer for a green
  captain, +0.01 s per battle up to +0.10 s, +0.06 s for a hero. A veteran is easier to
  time, so the roster matters as well as your hand.
- Impact: the loser's rider lifts and falls (the battle's fall, stretched), a clash, the
  crowd's cheer, the screen's shake at the Settings level. A line under the bar says it:
  "Ansel unhorses Bahram's champion at the first pass."
- A captain unhorsed is hurt as now (`TOURNEY_WOUND_CHANCE`, 15%), never killed.

### Bouts you don't ride

- Lords' champions against each other run as a **quick pass** (about 1.2 s, no bar), so
  the bracket is seen rather than read. A toggle, *Skip to mine*, jumps straight to your
  bouts and prints the rest.
- A bracket of three captains and eight lords is ten passes; yours are three or four. With
  the quick passes, a tourney takes well under a minute.

### Leaving it to them

- A button on the lists page, **Let them ride**, resolves the whole bracket as it does today,
  without the scene. It's the same odds at quality 1.0, so nobody is worse off for not
  playing.
- **Reduced motion** keeps the scene but stills the riders and the crowd; the marker still
  runs. The hit flash and the fall are drawn without the shake.

### Where the rules move

`CrownCourt.ride_tourney` becomes three steps, so a scene can drive them one pass at a
time and tests can drive them without a scene:

- `tourney_field(gs, g, squad_ids)`: the shuffled entrants.
- `tourney_pass(gs, g, a, b, quality)`: one bout at the given quality (1.0 when nobody
  played it); returns the winner and the line, applies a wound.
- `tourney_finish(gs, g, winner, lines, mine)`: purse, renown, bonds, Regard, the record.

The record moves from `gs.hosted["tourney"]` to the gathering's own record
(`gathering_record(g)["tourney"]`), so a tourney abroad has one too.

## 2. Tourneys abroad

### Who calls one

- When a realm at peace calls a gathering of its own (not a peace or victory feast), it's
  **lance games one time in four** (`TOURNEY_ABROAD_CHANCE := 0.25`), named by the host's
  culture: tourney, lance games, archery contest.
- Only a host who can pay the purse calls one: the ruler, or a lord with **300 silver**
  in his purse (`TOURNEY_HOST_SILVER`). The purse (100) comes out of it when the lists
  are ridden.
- Your crown's tourneys are unchanged.

### Being there

- You're invited like any gathering (`gathering_invite`): you serve the realm, hold land
  in it, your crowns are allied, or the host thinks well of you. The banner and the journal
  entry say what it is: "King Aldwin's lance games · purse 100 · Ride there".
- At the gathering, the hall's Court tab shows **The lists** to a guest as it does to the
  host: your captains' faces to tap (up to three), *Ride the lists*, and after, who won with
  the bouts folded away. You can come uninvited and still enter; the host's champion rides
  against you all the same.
- The bracket is the **host's champion**, a champion for each lord in the hall, and your
  captains. Ridden once per gathering, on any night.

### What's at stake

| Outcome | Effect |
|---|---|
| Your captain wins | the purse (100 silver), +10 renown, bonds among your riders (as now); **host +3 Regard** ("a fine showing in my lists"), unless the host is Cruel or Daring: **−2** ("a sore loser") |
| A lord's champion wins | that lord +5 Regard with the host, the purse to him (as now); nothing to you |
| Any lord whose champion rode | +2 with you (as now), lords like being asked |
| A captain unhorsed | hurt 15% of the time, as now |

Losing costs you nothing beyond the wound; nobody rides to be mocked.

### Tourneys you miss

- A tourney abroad you don't attend resolves on its last night among the lords present,
  with no scene: the winning lord takes the purse and +5 with the host.
- It's one line of news: "At King Aldwin's lance games, Lord Varo's champion took the
  purse." Cheap, and the world's tourneys exist whether or not you're there.

## Files

- `scripts/menu/lists.gd`, `scenes/lists.tscn` (new): the scene above.
- `scripts/world/crown_court.gd`: `ride_tourney` split into field, pass and finish;
  `tourney_check` for a guest; the host's champion as an entrant.
- `scripts/world/world_sim.gd`: the kind choice and the host's purse when a realm calls a
  gathering; the silent resolution on the last night; the news line.
- `scripts/game_state.gd`: the tourney record on `gathering_record`; `Scenes.lists_return`.
- `scripts/world/settlement_screen.gd`: the lists card for guests; *Ride the lists* opens
  the scene; *Let them ride*.
- `scripts/world/map_screen.gd`: the invitation banner and journal entry name the games
  and the purse.
- `scripts/data/gatherings.gd`: `TOURNEY_ABROAD_CHANCE`, `TOURNEY_HOST_SILVER`,
  `HOST_LISTS_REGARD` (3), `HOST_SORE_REGARD` (−2), the pass length and windows, the
  quality multipliers.
- `tests/tourney_tests.gd` (new): the three steps at each quality; windows by captain;
  a realm calls lance games and a poor lord can't; the invitation; a guest's bracket and
  prizes; the host's Regard by bearing; the silent resolution; the scene opens from the
  hall and returns to it; *Let them ride* matches the odds at quality 1.0.
- README, this doc.

## Order of work

1. The rules: the three steps and the record on the gathering, with tests. Nothing on
   screen changes yet; the hall still rides a whole bracket.
2. Tourneys abroad: calling, inviting, the guest's lists card, prizes, the silent
   resolution. Playable end to end with text results.
3. The scene: the pass, the quick pass, *Skip to mine*, *Let them ride*, reduced motion.
4. Renders and the README.

Roughly two days. Step 3 is the one with feel in it; the rest is rules.

## Later, not here

- The same pass could decide a **duel** ("Your champion and mine") instead of a roll.
- **You in the lists**: your own arms, a skill that grows with tourneys and duels, and the
  question of what happens when you're the one carried off.
- An **archery contest** for Ryumon that is a different game from the lance: hold to draw,
  release on the breath.
