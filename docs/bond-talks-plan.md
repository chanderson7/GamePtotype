# Captain bond talks: making each one its own

A plan, not yet built. The talks at the fire between bonded captains ("supports", ranks
C, B and A) read the same for almost every pair. This plan says why, what a talk should
be made of instead, how much writing that is, and in what order to build it. The rule in
the earlier bonds plan still holds: a talk changes no battle values or campaign
resources; it only remembers that it was read.

## What's there now

The screen is `scripts/menu/bond_conversation.gd`; the text comes from
`GameState.bond_conversation()` and three constants in `scripts/game_state.gd`.
A talk is five or six passages of narration followed by a four-line exchange:

1. **Opening**: "X and Y sit near the edge of the fire. They have fought close enough to
   rely on one another in N battles." Always this sentence.
2. **Last fight**: "Their last shared fight ended in victory, with 3 of the company lost.
   Neither needs to make the cost sound smaller." Always this sentence.
3. **Wounded** (if one is): one fixed line.
4. **The absent** (if either has lost a bonded friend): one fixed line with the names.
5. **Rank vignette**: one fixed paragraph per rank, labelled in the text ("The bond between
   them is forged in iron (Rank C). Across the watchfire..."). Its register (iron, blood,
   annals, impossible odds) is unlike every other line in the game.
6. **Voice line** (`_bond_voice_line`): one of three sentences chosen by the first
   captain's temperament.
7. **Exchange** (`BOND_EXCHANGES`): four lines, chosen by rank and by the first captain's
   temperament. Vengeful and Fragile have their own; Steadfast gets the default.

Counted: 9 exchanges (36 lines), 3 vignettes, 3 voice lines, 4 context sentences.
That is the whole of it. The problems follow from the count and from how the pieces are
chosen:

- **Only one captain's temperament matters**, and which captain is "first" is roster
  order (`bonds()` pairs squad i with squad j > i), so Mira & Brann can be a Vengeful talk
  and Brann & Mira a Fragile one. The other captain is a voice with no character.
- **Three scripts per rank for every pair in the company.** Six captains make fifteen
  pairs. Every Steadfast-led pair, at a given rank, says exactly the same four lines.
- **The voice line repeats the exchange.** The Vengeful voice line *is* the rank A
  exchange's first two lines, and the Steadfast one *is* the rank C exchange's first two.
  A Steadfast pair at rank C reads "Same distance tomorrow" twice on one screen.
- **The talk doesn't know what happened.** Facts the game already has (where the fight
  was, whether it was a siege or a ford, who was nearly killed, who cut down the most,
  whether it was bandits or a lord's host, whose first battle it was, the fallen captain's
  last words) never reach it. A rank B talk after storming Highcliff reads like one after
  a skirmish with brigands.
- **Culture is invisible.** A Kharzani faris and a Ryumon samurai share bread and a
  whetstone like two Vardish footmen. Nothing marks a pair from different peoples.
- **Rereading can change the text.** The wounded and the-absent passages come from the
  captains' current state, so the rank C tab read later says different things. Nothing
  records what a talk said when it was new.
- **A bond ended by death has no talk.** The screen says "The fire has gone quiet" and
  offers Back. The survivor, the rank they reached and the friend's last words are all
  in the save and unused.
- **The tests lock in the label.** `hero_companion_tests.gd` asserts that a passage
  contains the text "Rank C", which keeps the "(Rank C)" label inside the prose.

## What a talk should be

Each talk is assembled from parts. Each part is chosen by facts about the pair and the
last battle they shared, and each has a few variants. Three ranks of one pair then tell
a story that is theirs: how they met the line, the day one of them nearly died, what they
call each other by rank A. The chip on the nameplate already states the rank and its
effect, so the prose never has to.

### Parts, in order

1. **Where they sit** (one line, narration). By the two cultures, six combinations
   (three same-people pairs, three mixed), with two variants each. Same-people lines use
   their own things: Vardish bread and ale and a whetstone; Kharzani tea, dates and sand
   shaken from boots; Ryumon rice, the sashimono planted by the fire, oiling a blade.
   Mixed pairs notice each other's: "Tariq has given up explaining the tea. Brann drinks it
   anyway." Wounds and the hour can colour it: at night the fire; a wounded captain sits
   with the bad leg out.

2. **What happened** (one or two lines, narration). The hook, from the last battle they
   shared, most particular fact first:
   - *A close call*: one of them survived the death roll by a few points ("needed 45,
     rolled 48" is in every captain row). "The roll" is never said; the line says how close
     it was: "Another hand's width and we would be keeping your cup."
   - *Pulled clear*: one fell and was carried out with the other's squad within rescue
     range. The battle report knows `friends_near`; keep whether the friend was this
     partner.
   - *The walls*: the battle was a siege, storming or defending, by `objective`.
   - *The ford*: the site was a river crossing.
   - *First blood*: it was one captain's first battle with the company.
   - *The hardest fighting*: one of them cut down the most of anyone.
   - *The enemy*: a lord's host under a banner, or outlaws by their region's name
     (brigands, reavers, ronin, Wako pirates); the chief killed or escaped.
   - *A heavy day*: see below; losses are a hook only when they were heavy.
   - Otherwise the outcome and the place, with no number in it.
   About fourteen hooks, each written once with name slots, with a short variant for a
   victory and one for a defeat where the difference matters.

   **When losses are spoken of.** Today every talk prints the cost ("with 4 of the
   company lost"), and since nearly every battle costs a few men the line becomes
   wallpaper. Losses get a line only when they are what these two would talk about:
   - a captain they were both bonded to fell (the absent, below: it is the whole hook of
     that talk, named, and only once);
   - one of the pair's own squads lost half or more of its men in the fight;
   - the company as a whole lost a quarter or more of the men who fought.
   Ordinary attrition is never mentioned, and when a loss is, the line is about the
   people, not the count: "Three of your Shields stayed at the ford", not "4 lost".

3. **The exchange** (four to six lines, bubbles). Chosen by rank and by **both**
   temperaments, as an unordered pair: VV, VS, VF, SS, SF, FF. Who speaks first is the one
   the hook is about (the one who nearly died, the one who did the cutting), else the one
   with more battles; never roster order. Two variants per key, chosen by a seed from the
   pair and rank so a reread is the same.
   That is 6 × 3 × 2 = 36 exchanges, about 180 lines. Each pair of temperaments has a
   shape: two Vengeful captains compete; a Fragile one with a Steadfast one is steadied;
   two Fragile ones admit it to each other; Vengeful with Fragile is the odd one out, a
   protector and someone who hates needing one.
   Quirks and specializations swap one line where they fit: a Mentor's line about the
   young ones; a Scout who saw the enemy first; a Quartermaster counting rations; a
   Champion who says nothing of their own kills.
   A hero companion (`is_hero`) with authored dialogue keeps their own voice: their lines
   come from a per-hero table that overrides the exchange's lines for their side.

4. **What it comes to** (one line, narration). By rank, three variants each, in plain
   words and without a label: at C, they know where the other will be; at B, they move
   before the other calls; at A, the company has started to say their names together.

5. **The absent** (when a captain both were bonded to fell since the last talk): the hook
   of that talk, by the mourner's temperament, naming the friend and where they fell. Only
   in the talk at the rank reached after the loss, never repeated in later ranks.

### Memory between ranks

The bond record (`bond_records[key]`) keeps, per rank reached, what the talk was made of:
`conversations` becomes a list of `{rank, battle, hook, keys, said}` instead of a list of
rank letters. Old saves' letters become entries with no hook. With that:

- a reread shows the talk as it was, whatever has happened since;
- the rank B and A talks can call back: "Since the ford" or "the day at Highcliff" names
  the battle the rank C talk was about;
- the Warband's Bonds tab can show one line under each pair, the last talk's hook.

Facts to add to the record when a battle is applied, beside `shared_battles` and
`last_outcome`: `last_place`, `last_objective` (rout, chief, village, siege, defence),
`last_site` (ford or not), `last_enemy` (band name and whether a lord), the share of the
company's men lost, and for each of the two: `fate`, `kills`, `roll`, `needed`,
`first_battle`, and their squad's men before and after. All of these exist in the
result or the report at that moment and are dropped today.

### A talk for a bond that death ended

When one captain of a bonded pair falls, the survivor gets a one-sided talk at the fire:
the empty place, the fallen's portrait greyed (the memorial already keeps a face record),
the survivor's lines by temperament and the rank they had reached, naming the battle and
quoting the fallen's last words from the memorial entry. Three temperaments × three ranks,
one each, about 40 lines. It is listed with the other talks ("Fenwick remembers Brann"),
read once, and reread from the memorial.

### The player's part

Optional, after the rest. One reply at the end of a talk, expressive only: sit with them
a while, leave them to it, or raise a cup to the absent. The choice is kept in the record's
`said` and is the only thing that can change a later talk's closing line. It pays nothing
and changes no value, which the note on screen keeps saying.

## Register

The lines follow the game's own voice, which the romance visits and camp moments set:
short sentences, plain words, dry, a joke that is someone's and not the narrator's, and no
grandeur. No "annals", "forged in iron", "impossible odds". Names are used where a line
needs one and not as a tag on every sentence. No bubble is longer than two lines on a
phone, about 110 characters. Narration never explains what a line meant.

## How much writing

| Part | Keys | Variants | Lines |
|---|---|---|---|
| Where they sit | 6 culture pairs | 2 | 12 |
| What happened | 14 hooks | win/loss where it matters | about 20 |
| The exchange | 6 temper pairs × 3 ranks | 2 | about 180 |
| Quirk and specialization swaps | 7 | 1 | 7 |
| What it comes to | 3 ranks | 3 | 9 |
| The absent | 3 temperaments | 1 | 3 |
| Death ended it | 3 temperaments × 3 ranks | 1 | about 40 |
| Hero overrides | per hero × 3 ranks | 1 | about 20 each |

About 300 lines in one data file, against 45 today. Written in `scripts/data/bond_talks.gd`
in the shape of `camp_moments.gd` and `personal_conversations.gd`: pure data and a pure
`compose(facts)` function, with no dependence on `GameState`, so it can be tested with a
dictionary of facts.

## Order of work

1. **Move the text out and choose it properly.** New `bond_talks.gd` with today's lines
   as a start; `bond_conversation()` gathers facts and calls `compose`. Both temperaments
   choose the exchange; the speaker is chosen by the facts; the voice line and the labelled
   vignettes go. `conversations` becomes a list of records, with migration from letters.
   Tests: a reread at rank C after reaching rank A is the same text; swapping the two
   captains' order gives the same talk; VS and SV give one exchange, VV and FF different
   ones; no passage contains "(Rank"; no sentence appears twice in one talk. Update the
   vignette test in `hero_companion_tests.gd` to assert the rank chip, not the prose.
2. **Record the facts.** Extend the bond record at `apply_result` with place, objective,
   site, enemy, and both captains' fate, kills, roll, needed and first-battle flag. Tests:
   each hook fires on a crafted result (close call, ford, siege, first blood, hardest
   fighting, chief killed, a gutted squad, a heavy day), the most particular one wins,
   and a battle that cost three men out of two hundred mentions no losses at all.
3. **The writing pass.** All 36 exchanges, openings, hooks, closings, swaps. Tests: every
   key present for every temperament pair and rank; no exchange text shared between keys;
   every line within the length limit; every name slot filled.
4. **The talk a death ended**, listed with the others and reachable from the memorial.
5. **Callbacks and the Bonds tab line.** The B and A talks name the earlier battle;
   each pair's row shows its last talk's hook.
6. **The player's reply**, if wanted.

Steps 1 and 2 are the engineering and change what the player reads only a little. Step 3
is where the game gets its talks. Steps 4 to 6 are each small once 1 to 3 are in.

## A worked example

`mockups/bond-talk-example.png` shows the rank C talk below on the phone screen, with
the steps from the battle to the words and which fact chose each part.

Brann of the Fens (Vardish, Steadfast, Brann's Shields, nine battles) and Tariq of Khalun
(Kharzani, Fragile, hired abroad, Tariq's Riders, three battles). Last battle: holding the
Raven ford near Ravensford against the Fenland cutthroats. Victory, four of the company
lost. Tariq went down and survived the death roll by four with Brann's squad in rescue
range. Brann cut down the most, seven. They have just reached rank C.

**Rank C**, as composed (opening: Vardish and Kharzani, one wounded; hook: close call with
the partner's squad in range; exchange: Steadfast and Fragile, Tariq first because the
hook is about him; closing: rank C):

> *Tariq sits with the bad leg out toward the fire. He has given up explaining the tea.
> Brann drinks it anyway.*
>
> *At the Raven ford, Tariq went down in the water with the cutthroats over him. Brann's
> Shields were close enough to drag him out. Another hand's width and the company would be
> keeping his cup.*
>
> **Tariq:** Your men pulled me out by the collar. I'd like it known I was still fighting.
> **Brann:** You were. Lying down, in a river. Very brave.
> **Tariq:** I don't know how to thank a man for that.
> **Brann:** Stand where I can reach you tomorrow. That's the whole of it.
> **Tariq:** That's a bad trade for you.
> **Brann:** I'm Fen-born. We don't leave things in rivers.
>
> *By morning neither of them will mention it again. But Brann knows where Tariq's riders
> will be, and Tariq knows who is on his left.*

**Rank B**, two battles later, after storming Highcliff, where Brann was wounded and Tariq
did the most killing. "Since the river" is the callback to the rank C record:

> *Brann's arm is strapped. Tariq has brought him the tea anyway, and is enjoying it.*
>
> *They went over the wall at Highcliff on the same ladder, Tariq's riders on foot for
> once. He cut down nine. Brann took a blade in the arm on the walk.*
>
> **Tariq:** Nine. You can say it.
> **Brann:** Nine. And the one that got my arm walked right past you.
> **Tariq:** I saw him. I decided you had it.
> **Brann:** You decided.
> **Tariq:** Since the river I've been trying to trust you with things. It's going badly.
> **Brann:** Keep at it. Drink your tea.
>
> *Today they moved before the other called for it, on the ladder and off it. The company
> has started to notice.*

**The same pair today**, rank C, with Brann first in the roster:

> *Brann and Tariq sit near the edge of the fire. They have fought close enough to rely on
> one another in 3 battles.*
> *Their last shared fight ended in victory, with 4 of the company lost. Neither needs to
> make the cost sound smaller.*
> *Brann checks Tariq's bandages without ceremony. "You heal. I will keep your place in the
> line."*
> *The bond between them is forged in iron (Rank C). Across the watchfire, a shared nod is
> all that is spoken — when shields lock tomorrow, each knows the other's flank is secure.*
> *Brann says, "Same distance tomorrow. Close enough to help, far enough to breathe." Tariq
> nods.*
>
> **Brann:** Same distance tomorrow?
> **Tariq:** Close enough to help, far enough to breathe.
> **Brann:** You've thought about this.
> **Tariq:** Since the second charge. Bread?

Nothing of the ford, the near-death or the two peoples reaches it, the "same distance"
line appears twice, and every Steadfast-first pair in the company reads this exact text.
