# Captain bond talks: a talk that is theirs

A plan, with a runnable prototype of the part that matters: `tools/bond_talks_proto.py`
composes talks from facts with real written lines, prints samples, and measures how often
lines repeat over simulated campaigns. The rule from the earlier bonds plan still holds:
a talk changes no battle values or campaign resources; it only remembers it was read.

## What's there now

The screen is `scripts/menu/bond_conversation.gd`; the text comes from
`GameState.bond_conversation()` and three constants in `scripts/game_state.gd`: nine
four-line exchanges, three rank vignettes and three "voice lines", 45 lines in all.

- Only one captain's temperament chooses the exchange, and which captain that is comes
  from roster order, so the other captain has no character and swapping the pair can
  change the talk.
- Three scripts per rank serve every pair in the company. Six captains make fifteen
  pairs; every Steadfast-led pair at a rank says the same four lines.
- The voice line repeats the exchange: a Steadfast pair at rank C reads "Same distance
  tomorrow" twice on one screen.
- The talk knows nothing of the battle. Place, siege or ford, who nearly died on the
  death roll, who cut down the most, bandits or a lord's host, first battles and the
  fallen's last words are in the save and unused. "With 4 of the company lost" is
  printed every time, so it stops meaning anything.
- The lines are quips. Every one is a reversal or a maxim ("close enough to help, far
  enough to breathe"), nobody says a plain thing, nothing mundane is in it, and both
  captains speak in the same cadence. The rank vignettes reach for epic ("forged in
  iron", "the annals of the company"), which nothing else in the game does.
- Rereads can change, because the wounded and fallen passages read current state.
- A bond that death ended has no talk: "The fire has gone quiet", and a Back button.
- `hero_companion_tests.gd` asserts the text "Rank C" inside a passage, which locks the
  label into the prose.

## What a talk is

A talk is composed from parts. Every part is chosen by a fact about the pair or the last
battle they shared, and the exchange itself is *about* what happened, not about the
relationship in general. The prototype's first sample shows the shape:

```
== Brann & Tariq, rank C, after the Raven ford  [hook: close_call, about Tariq]
   Brann has brought bread. Tariq has brought dates. Neither has mentioned the
   other's. Tariq has the bad leg out toward the fire.
   At Ravensford, Tariq went down with the Fenland cutthroats over them. Brann's
   Shields were close enough to drag Tariq clear.
     TARIQ: I keep thinking I'm still down. Stupid. I'm sitting right here.
     BRANN: You're out. That's the part I care about.
     TARIQ: I'd still be lying there if your lads hadn't come. I don't know what
            to do with that.
     BRANN: They know.
     BRANN: Tomorrow, stay where I can reach you.
     TARIQ: I will. I'll be there.
   Nothing is settled. But tomorrow each will know where the other is.
```

`mockups/bond-talk-example.png` shows this one on the phone screen, with which fact
chose each part. Run the prototype for three more, and `campaign` for all 45 talks of a
simulated campaign in order, which is the honest test of repetition. The parts:

1. **Where they sit.** One line of narration by the two cultures (six pairings, two
   variants each) with the things of those peoples: bread, ale and a whetstone; tea,
   dates and sand in boots; rice and the sashimono drying by the fire. A mixed pair
   notices the other's things. A wounded captain has the bad leg out toward the fire.

2. **What happened.** One factual sentence: the hook. The most particular fact of the
   battle wins, in this order:
   - *a bonded friend fell* (a captain both were bonded to);
   - *a close call* (one survived the death roll by ten or less; the rescue by the
     partner's squad, if it was within reach, is said);
   - *gutted* (one's own squad lost half its men or more);
   - *a heavy day* (the company lost a quarter or more of the men who fought);
   - *the walls* (storming; defending gets its own lines);
   - *the ford*;
   - *first blood* (one's first battle with the company);
   - *the hardest fighting* (one of the two cut down the most of anyone, four or more);
   - *a lord's host*, won or lost;
   - *the chief* (killed or escaped, on a bounty);
   - *a night fight*;
   - *bandits*, by their region's name;
   - *plain*: the place and the outcome, with no number in it.
   Losses are spoken of only by the first four hooks, and about the people: "Three of
   your Shields stayed at the ford", never "4 lost". Ordinary attrition is never mentioned.
   When several pairs reach a rank after one battle, each talk takes the most particular
   hook no earlier talk from that battle used, so the player doesn't read the same fact
   three times at one sitting.

3. **The beats.** Four spoken lines, S P S P, where S is the captain the hook is about
   (the one who nearly died, whose squad was gutted, who did the cutting; otherwise the
   one with more kills, then more battles) and P the partner. Each beat has a line per
   temperament of whoever speaks it, in two or three variants. Every line of a beat is
   written to follow any line of the beat before, so the three temperaments combine
   freely: a Fragile S with a Vengeful P and a Steadfast S with a Fragile P are different
   talks from the same hook. Both captains' temperaments matter, and S is never roster
   order.

4. **What the rank means.** The partner says it, by rank and their temperament, and the
   other answers by theirs. Any reply must follow any line of that rank. Three variants
   of each. These say in plain words what the chip already shows: at C where the other
   will be, at B moving before the other calls, at A that the men say their names
   together. No "(Rank C)" anywhere in the prose.

5. **Closing.** One line of narration by rank. At B and A it names the battle the
   earlier talk was about ("since the Raven ford"), from the record.

### Voices and things

- **Voice.** Each captain gets one at creation: *plain*, *talks*, *short* or *formal*.
  Lines are written in sentences; a sentence marked for talkers is said only by one, a
  sentence marked optional is dropped by a captain of few words, and a formal captain
  addresses the other by name the first time they speak. The same beat reads differently
  in Brann's mouth and Tariq's. Nothing is generated: every sentence is written.
- **Things.** Slots for what a captain handles, loses and passes: the weapon by culture
  and troop type (pike, scimitar, yumi), the lost thing (left boot, water skin, straw
  hat), the food (bread, dates, rice). The same beat with a different object reads as a
  different line, and it is what people actually talk about after a fight.
- **Quirks and specializations** swap one line where they fit (a Mentor's line about the
  young ones, a Scout who saw them first, a Quartermaster counting rations). A hero
  companion with authored dialogue keeps their own voice through a per-hero override of
  their side's lines.

### Register

The lines follow the game's own voice, as the camp moments and the romance visits set it,
with these rules, which the first draft of this plan got wrong:

- One mundane, concrete thing in every talk: a boot, the tea, a ladder, a horse.
- Lines of uneven length. At least one plain line that says the thing straight, and at
  least one that answers nothing.
- No aphorisms, no reversals for their own sake, no line that would work as a motto.
  Nobody speaks in finished sentences about the relationship; the feeling comes through
  sideways, from what they do with the boot.
- The two speakers differ: temperament sets what they say, voice sets how much.
- Narration states facts and never explains what a line meant. No "annals", "forged in
  iron", "impossible odds". No euphemism in narration ("keeping his cup" is out).
- Names are used where a line needs one, not as a tag. No bubble longer than two lines
  on a phone, about 110 characters. Read every line aloud before it goes in.

### A talk for a bond that death ended

When one captain of a bonded pair falls, the survivor gets a one-sided talk at the fire:
the empty place, the fallen's portrait greyed from the memorial's face record, lines by
the survivor's temperament and the rank they had reached, naming the battle and quoting
the fallen's last words from the memorial entry. It is listed with the other talks
("Fenwick remembers Brann"), read once, and reread from the memorial.

### The player's part

Optional, after the rest. One reply at the end of a talk, expressive only: sit with them a
while, leave them to it, or raise a cup to the absent. Kept in the record and the only
thing that can change a later closing line. It pays nothing, as the note on screen says.

## Variation, measured

Fifteen pairs in a company of six, three ranks each: up to 45 talks a campaign. The
prototype simulates 300 campaigns of 30 battles with random companies and battles and
counts repeats. With its present lines (one to three variants each, ten hooks):

| | per campaign |
|---|---|
| talks | 45 |
| exact duplicate talks | 0.03 |
| same hook, temperaments and rank reused | 9.3 |
| times the most-heard line is heard | 5.7 |

The skeleton reuse is fine: the words differ by voice, objects, names and variants. The
number to drive down is the last one, the worst single line. It comes from temperament
skew (a company with four Steadfast captains hears the Steadfast lines of the common
hooks over and over) and from the two commonest hooks, bandits and the hardest fighting,
which between them are half of all talks. Padding every line to a given number of
variants shows what the writing buys:

| variants per line | most-heard line, per campaign |
|---|---|
| 1 to 3 (prototype) | 5.7 |
| 2 | 4.8 |
| 3 | 3.8 |
| 4 | 3.1 |

So the budget is three variants for the common hooks (bandits, hardest, lord, plain) and
the rank lines, two for the rest. Target: no exact duplicate talk in a campaign, and no
single line heard more than four times in 45 talks. Both are tests on the simulation.

Three mechanisms make this cheap:

- **Least-heard variant.** The save keeps a count of every variant heard, company-wide.
  The composer takes the least-heard variant of each line, opening and closing included,
  the seed breaking ties. It is deterministic given the save, so rereads hold.
- **Hook spreading within a battle**, as above.
- **Voice and objects**, which vary a line without new writing.

### What reading a whole campaign found

The numbers are necessary and not sufficient. Reading all 45 talks of one simulated
campaign in order (`campaign` mode) found what they miss:

- **A reply that only follows one line.** The beat model lets any temperament's line
  follow any line of the beat before, so a partner's reply must answer the *fact*, not
  the words. Two replies in the prototype broke that: Wenna's "Good. It goes back to
  his family" was written for the line where the other took a trinket off a dead bandit,
  and read as monstrous after Brann said his men had killed a boy. The rule for the
  writing pass: every partner line is read after all three lines it can follow, nine
  readings per beat pair, before it goes in. Where a reply has to answer the words, the
  specific content moves into the subject's line and the reply stays about the fact.
- **The plain hook is heard too much.** With bandits and the hardest fighting sharing
  half of all talks and spreading pushing a second pair off them, "plain" rose to a sixth
  of talks, and its single-variant Fragile opener was the most-heard line of the campaign.
  The hooks for a night fight, the chief, the enemy's region and defending walls are
  there to make plain rare, and plain gets three variants like the common hooks.
- **The same opening twice running** for two pairs with the same cultures, until openings
  went through the least-heard rule too.
- **Won and lost need their own lines** where the hook's point changes with the outcome:
  "They'll want that banner back" is wrong after a defeat. The lord, walls and bandits
  hooks carry both.

## Data and saves

- `captain.voice`, set in `Captains.make()`; old saves get one from the id.
- The bond record gains, at `apply_result`: `last_place`, `last_objective`, `last_site`,
  `last_enemy` (name, is_lord, region), `last_night`, the company's share of men lost,
  and for each captain: `fate`, `kills`, `roll`, `needed`, `first_battle`, `men_before`,
  `men_after`, `rescued_by_partner`.
- `conversations` becomes a list of `{rank, battle, hook, subject, choices, said}`.
  Rank letters in old saves become entries with no hook. A reread composes from the
  stored choices; a new talk composes fresh and stores them.
- `bond_talk_heard`: the campaign-wide variant counts, `{key: count}`, capped by dropping
  the oldest keys past a few hundred.
- A fallen captain's memorial entry already keeps `words`; the memorial talk reads it.

## How much writing

| Part | Keys | Variants | Lines |
|---|---|---|---|
| Where they sit | 6 culture pairs | 2 | 12 |
| Hook sentence | 14 hooks | 1, with won/lost where it matters | about 20 |
| Beats | 14 hooks × 4 beats × 3 temperaments | 2–3 | about 420 |
| Rank line and reply | 3 ranks × 3 temperaments × 2 | 3 | 54 |
| Closing | 3 ranks | 3 | 9 |
| Quirk and specialization swaps | 7 | 1 | 7 |
| Death ended it | 3 temperaments × 3 ranks | 1 | about 40 |
| Hero overrides | per hero × 3 ranks | 1 | about 20 each |

About 560 lines against 45 today. The prototype holds about 170 of them, in the shape
the GDScript data will take: dictionaries of strings with `{slots}`, sentences split by
`|`, `+` for talkers and `-` for the short. `bond_talks.gd` will be pure data and a pure
`compose(facts, avoid, heard)` with no dependence on `GameState`, so it is tested with a
dictionary of facts, as the prototype is.

## Order of work

1. **Port the composer.** `scripts/data/bond_talks.gd` from the prototype's tables and
   `compose`; `bond_conversation()` gathers facts and calls it; the voice line and the
   labelled vignettes go; `conversations` becomes records with migration. Tests: a reread
   at rank C after reaching A is the same text; swapping the two captains gives the same
   talk; no passage contains "(Rank"; no sentence appears twice in one talk; every beat
   and rank key exists for every temperament. Update the vignette test to check the chip.
2. **Record the facts** at `apply_result`, and add `voice` to captains. Tests: each hook
   fires on a crafted result and the most particular one wins; three men lost of two
   hundred produce no loss line; two pairs from one battle take different hooks.
3. **The writing pass**, to the budget above, in the register above. Tests on the data:
   every key present; variant counts meet the budget; every line within the length
   limit; every slot filled by the facts the composer provides; the simulation's two
   targets.
4. **The talk a death ended**, reachable from the memorial.
5. **The Bonds tab line**: each pair's row shows its last talk's hook.
6. **The player's reply**, if wanted.

Steps 1 and 2 are the engineering. Step 3 is where the game gets its talks, and the
simulation says when it is enough.

## Open questions

- The close-call window: ten points on the roll in the prototype. The real death chance
  runs from 10 to 90, so the window may want to be a share of the needed value.
- Night fights and defending walls have no lines in the prototype; they are in the budget.
- Whether a pair's third talk should ever be the same hook as its first. The record
  knows; the composer could skip it when another hook applies.
