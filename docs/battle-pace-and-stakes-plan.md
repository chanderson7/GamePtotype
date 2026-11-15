# Vaskaria: battle pace and stakes

- **Date:** 2026-11-15
- **Status:** plan. Nothing here is built.
- **Question:** is a battle too quick for someone playing on a phone, and does it feel
  high-stakes?
- **Short answer:** the whole battle is not much too short. The time you have to *decide*
  is. The lines meet about five seconds after *Fight*, a melee shows nothing for twenty
  seconds and then drops a third of a company at once, and "wavering" comes one man's
  fall before "broken". The stakes are real (captains die, a wiped warband ends the
  campaign) but the battle never shows them until they have already been settled.

**Not run.** Godot isn't installed in the session that wrote this, so nothing below was
measured by it. Each number is marked: *(repo)* is a measurement already written down in
this repository, *(rules)* is worked from the constants in the code, *(model)* is a
40-line stand-in for one melee built from those constants. Stage 0 replaces the last two
with real measurements before anything is tuned.

## 1. Where a battle's time goes today

| Beat | Today | Why |
| --- | --- | --- |
| Deploy | untimed | Time stands still until *Fight*. This part is right for a phone. |
| Approach | about 3 to 8 s *(rules)* | *Auto-place* stands each front 120 from the midline, so the lines start 240 apart (`battle_sim.gd:1464`). Marching is 38 a second. Reckless commits after 3 to 8 s, Hammer after 2 to 4 (`commander_ai.gd:124`). |
| Melee | 56 s foot against foot *(repo)* | 600 hit points against 13 a blow, two men at most on one. |
| After the first break | the rest | A whole battle is 85 s for ten companies a side *(repo, `combat-simplification-plan.md` §8)*; the test allows 40 to 150 s (`run_tests.gd:177`). |

At 2× all of it halves.

### Three things that make it feel quicker than it is

1. **There is no approach.** You see their line while you deploy, but you never see what
   it *does* before it reaches you. Bows get a volley or two off. The Patient commander is
   the only one who gives you time to look.
2. **A melee is silent, then sudden.** Every man of a kind has the same hit points and
   takes nearly the same blows, so the men of a front rank fall together. In an even
   fight of swords the first man falls at about 23 s and the seventh at about 24 s; the
   next seven fall around 46 s *(model)*. Morale moves only when a man dies or a shock
   lands (`_damage`, `battle_sim.gd:3975`), so the bar on the standard is flat, drops a
   third, is flat again. For most of a melee there is nothing on screen that says who is
   winning it.
3. **The break gives no warning and no answer.**
   - *Wavering* is morale 35 and *broken* is 30 (`battle_screen.gd:225`,
     `battle_sim.gd:34`). A man's fall costs a led company 4.8, so the warning is one
     fall ahead of the rout *(rules)*.
   - The ticker says "Pull them back or send help", but nothing raises morale except a
     bond and a Steadfast captain's grief. Pulling back saves nobody's nerve.
   - A rout is for good. Broken companies run off the edge and are not chased (only a
     side that was cut off as it withdrew is ridden down, `battle_sim.gd:2693`).
   - So the first break usually decides the battle, and what follows is mopping up.

Put together: one real decision (how you deploy and your opening orders), then ability
timings. On a phone, where a thumb covers the squad it is ordering, that is over before
the player has found their feet.

### Why it doesn't feel high-stakes

- **The danger is hidden until it is settled.** A captain has four times a man's hit
  points, so he falls late, and the first the player hears of his odds is the die
  already rolling. The odds depend on things the player controls (his company still at
  half strength, a friendly company within 160) and nothing says so beforehand.
- **Nothing is ever committed.** There is no order that can't be taken back and nothing
  that can be spent once. Stakes come from commitments.
- **A loss is cheap.** Half of every man lost comes back as wounded, win or lose
  (`game_state.gd:5005`). A defeat puts you at your capital twelve hours later with your
  silver and food untouched (`world_sim.gd:3239`). Outside Ironman the game keeps a save
  from just before the battle, so any result can be undone.

## 2. What to aim for

| | Today | Aim |
| --- | --- | --- |
| A full battle (10 a side, 1×) | 85 s *(repo)* | 2.5 to 3 minutes |
| An early skirmish (4 a side) | not measured | about 90 s |
| *Fight* to first contact | 3 to 8 s | 14 to 20 s |
| A melee with nothing to read | about 20 s before the first man falls, then 20 s more | never: the fight's bar moves from the first blow (1A); the first man falls by about 13 s and others every few seconds after (2B) |
| Warning before one of yours breaks | about one man's fall | at least 8 s, with something to do about it |
| Times the lead changes hands | not measured | once or more in a third of even battles |
| Decisions after *Fight* (windows of 8 s or more where an order changes the result) | about one | four or more |

Three minutes is still a phone-sized battle. The time added goes to the approach and to
the break, where there is something to decide, and none of it to the grind.

## 3. The plan, in five stages

Each stage stands on its own and ships with its tests. Stage 1 changes no rule, so it
can't move balance and can go first.

### Stage 0: measure (half a day)

Add to `tools/battle_probe.gd`, and print for the four battles the simplification plan
used (seeds 40, 8, 21 open; seed 4 woods) plus a 4-a-side:

- seconds from start to first contact, to the first break, and from the first break to
  the end;
- men down in each 5 s of the battle, and the longest stretch with none;
- for each company that breaks: seconds between morale 35 and the rout;
- how often the stronger side (by `strength()`) changes;
- companies that never fought.

These are the numbers in the table above. If the model in section 1 is wrong about the
waves, Stage 2B goes away.

### Stage 1: show the stakes (screen only, no rule changes)

Everything here reads the sim and never writes it, like `combat-feel-plan.md`. The same
seeded battle ends the same.

- **1A. Who is winning each fight.** Between two standards locked together, a small
  two-colour bar: the blows each side landed in the last five seconds. It moves from the
  first second of a melee, long before a man falls, and tells the player where to send
  help. The same reading tints the edge of the company's card.
- **1B. The captain's odds, live.** Once a captain is under half his hit points his card
  shows *"If Brann falls: 30%"*, from `Captains.death_chance` with what is true this
  second, and what would change it: *"a company within reach: 15%"*. The rules for this
  already exist. Showing them turns a die roll into a gamble the player is making.
- **1C. A crisis gets a beat.** When one of yours starts to waver, a charge is about to
  land on a flank of yours, or a captain's odds come up, the fight drops to the pace the
  death roll already uses (`SLOW_PACE`, 0.35) for a second and a half, with the camera
  nudged toward it. *Settings › In a crisis: slow · pause · carry on.* Orders already work
  while paused, so "pause" gives a tactical pause to anyone who wants one. This is the
  thumb-friendly version of holding the hourglass.
- **1D. 2× lets go when it matters.** 2× is for the march. It drops to 1× when the lines
  first meet and on any crisis in 1C (a setting keeps it locked for those who want that).
- **1E. What is at stake, before and after.** The deploy screen and the title card gain
  one line: the captains riding into this one who are wounded, bonded or one battle from
  a role, and what the field is worth. The result card says what the win or the loss
  cost in the same terms.

Tests: the boundary test in `battle_feel_tests.gd` still passes; the bar reads zero with
no blows and full one way in a one-sided fight; the odds on the card equal the roll's
`needed` if the captain falls that tick; a crisis never slows the sim's own clock.

### Stage 2: give the battle a shape (small rule changes)

- **2A. An approach.** *Auto-place* fronts at about 190 from the midline, not 120, so the
  lines start 380 apart, and Reckless and Hammer wait six seconds longer before they
  commit. Bows get to matter before the lines meet, horse have room to be seen going for
  a wing, and the player gets one look at what their commander is doing. Check twelve
  companies still fit the zone.
- **2B. Men fall one at a time.** Each man's hit points are drawn at spawn from 40% to
  160% of his kind's (captains keep theirs), from the sim's own RNG. The average is the
  same. In the model the first man falls near 13 s, not 23, the rest follow every few
  seconds with no waves, and the fight runs about a sixth longer because the hardier men
  hold the front *(model)*. Morale then falls steadily too, which is what makes 1A, the
  wavering warning and the music's "who is winning" worth watching. A narrower spread
  (60% to 140%) still leaves 16 s before the first fall.
- **2C. Wavering means something.** Wavering starts at morale 50, about four falls ahead
  of the break, and the ticker's advice changes to what Stage 3 makes true.

Both 2A and 2B change every seeded battle, so: `-- --balance` (the best part of an
hour), the auto-resolve agreement check (`auto_resolve.gd` is fitted to the sim), and a
version stamp on a battle kept for resume so an older one isn't replayed under new rules.
The length test's window moves from 40–150 s to about 100–240 s and `TIME_LIMIT` from 300
to 420.

### Stage 3: a break you can fight (new rules)

This is where the stakes come from: something you care about is going, there is a clock
on it, and there is a thing you can do.

- **3A. Breaking takes six seconds.** At morale 30 a company doesn't run at once. It is
  *breaking*: a ring drains on its standard and its card, and it fights at four fifths.
  If its morale is back over 30 when the ring empties, it holds. If not, it runs. A
  charge or a blow from behind on a breaking company breaks it there and then, which is
  how you finish theirs.
- **3B. Three ways to save it.**
  - *Rally*: the captain's call, once a battle, on the company's card. Morale +25; the
    company stands still for two seconds to hear it. No captain, no rally. This is the
    Rally from `battle-controls-plan.md` §2, without the wheel.
  - *Relief*: a fresh company of yours joining the fight against its attacker steadies
    it, +10, once.
  - *Their man breaks first*: +15 to whoever was fighting him.
- **3C. A rout is felt.** Friends within bond range of a company that breaks lose 6;
  the company that broke it gains 6. A chief's or a lord's fall stays at 35.
- **3D. Runners come back unless you ride them down.** A broken company with its captain
  alive and six men or more, left alone for eight seconds, forms up again at its edge
  once a battle at morale 55. Any company can be sent after runners (tap them); men
  running take double. So a break opens a choice with a cost either way: turn the horse
  onto the next flank now, or ride down the men who will otherwise be back.
- **The commanders use all of it.** Each temperament rallies and pursues in character
  (Reckless chases, Patient rallies early, Hammer keeps its horse for the flank).

3D is the largest piece and can wait for a second pass; 3A to 3C are worth having without
it. All of Stage 3 needs the full balance run, and auto-resolve refitted once.

### Stage 4: the price (campaign)

- **4A. The field belongs to the winner.** Today half of everyone's losses come back
  wounded. Make it six in ten for the side that holds the field and one in four for the
  side that left it. Winning a hard fight now saves men, and losing one is felt for days.
- **4B. The baggage.** A defeat costs a quarter of your food and 15% of your silver (with
  a ceiling), and the band or lord that beat you carries it. Beat them and it comes back
  with the spoils, which gives a loss a second act.
- **4C. Captains taken.** Beaten by a lord, a captain who fell wounded may be taken and
  ransomed back, through the envoy and ransom rules lords already have. A second pass.
- **Casual mode** keeps today's gentler numbers. Auto-resolve applies the same rules, so
  sending the men in is never the safe way round them.

The before-battle save undoes any of this outside Ironman. Leave it alone for the first
release: a phone game that takes your captain and offers no way back loses players, and
Ironman is there for those who want the price to stick. Say so on the new-campaign
screen, where the choice is made.

## 4. Order and size

| # | Stage | Size | Risk to balance | Do it when |
| --- | --- | --- | --- | --- |
| 0 | Measure | S | none | first |
| 1 | Show the stakes | M | none | next; it helps even if nothing else is done |
| 2 | A shape | S to M | some: every seeded battle changes | after 0 confirms the waves and the short approach |
| 3A–C | Fight the break | M to L | real: new rules, AI, auto-resolve | after a playtest of 1 and 2 on a phone |
| 4A–B | The price | M | campaign economy (`Plans.campaign`) | alongside or after 3 |
| 3D, 4C | Rally at the edge; captains taken | L | real | second pass |

## 5. Files

- `tools/battle_probe.gd`: Stage 0.
- `scripts/battle/battle_screen.gd`: 1A to 1E; the ring, the Rally button and the tap on
  runners for Stage 3.
- `scripts/menu/settings.gd`, `scripts/audio/sound.gd`: the crisis and 2× settings.
- `scripts/battle/battle_sim.gd`: 2A (`auto_deploy`), 2B (`_spawn`), 3A to 3D
  (`_update_squad`, `rout`, a `rally` order through `command` so resume replays it).
- `scripts/battle/commander_ai.gd`: 2A patience; rallying and pursuit.
- `scripts/data/captains.gd`, `scripts/data/troops.gd`: the new numbers, where the
  tuning lives.
- `scripts/battle/auto_resolve.gd`: refit after 2 and after 3; 4A.
- `scripts/game_state.gd`, `scripts/world/world_sim.gd`, `scripts/data/economy.gd`: 4A
  to 4C.
- `tests/run_tests.gd` (length window, new rules), `tests/battle_feel_tests.gd`,
  `tests/battle_controls_tests.gd`, `tests/battle_resume_tests.gd`,
  `tests/casualty_and_healing_tests.gd`.

## 6. Decisions to make

1. **The length.** 2.5 to 3 minutes for a full battle, 90 s for a skirmish, is the
   recommendation. If a battle must stay under two minutes, do Stages 1, 2B and 2C and
   3A to 3C with a four-second ring, and skip 2A and 3D.
2. **New rules in the battle.** Stage 3 costs a balance pass and a refit of auto-resolve.
   Stages 0 to 2 are worth doing whatever is decided here.
3. **How much a loss should hurt.** 4A and 4B as written, or milder; and whether Casual
   is the only gentle setting.

## Not in this plan

- Sieges. They pace themselves by the gate and the ladders; 1A to 1E apply to them, and
  Stage 3 should be tried on a field first.
- New orders beyond Rally (Fall back, Flank and Wait stay in `battle-controls-plan.md`).
- Removing or limiting saves.
- Longer melees. The grind is long enough; it is the time around it that is short.
