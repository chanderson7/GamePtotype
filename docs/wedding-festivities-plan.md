# The wedding day: your hand in it, the "I do", and the feast

**Status: built.** Builds on the wedding in `docs/wedding-plan.md`, which is built. Nothing
before the day changes (the proposal, the place, the days of waiting, postponement, calling it
off). This plan is about the scene you open with *Begin the wedding*. Where the build differs
from the plan below:

- **The question doesn't clear the talk.** The rite's last line stays on screen above it, so
  it can be read; the hush is in the place (the dressing stills, the music drops).
- **Ryumon's rite has three plain steps** (the three cups), then the choice of how you sign;
  the Vardish and Kharzani rites have two, then their choice.
- **Round the tables** offers each guest as a reply with their face (so autoplay and the
  tests can tap them); the *Who came* card on arriving stays as it was.
- **The custom's choice needing your second** has its own version when no one stands with
  you (arm-wrestle the cook yourself; let her whisper you the line).
- **Tests and build checks** were written without a Godot binary in the session that built
  this: run `tests/wedding_tests.gd` before relying on it.

## What's wrong now

The day is read, not played. From *Begin* to *Back to the map* you make three choices: take
your place, pick a vow, pick a toast.

- **The rite is two lines of narration.** The cord, the bread and salt, the three cups all
  happen to you (`wedding.gd` `_rite`).
- **There is no moment you are married.** The status flips inside `_finish`, which runs
  after *your toast*. So the toasts come before the marriage, and "Married" arrives as a
  card in the log.
- **One captain toasts, and it could be anyone.** The longest-serving captain speaks one
  of six lines picked by `captain_id mod 6` (`Lines.captain_toast`). It says nothing about
  who they are. Everyone else is a count on the closing card ("Your 4 captains drank to
  you, loudly").
- **There is no feast.** The feast music plays from the first frame, but there is nothing
  to do at it. *Who came* is a row of faces you can't touch.
- **She barely reacts.** Her face is warm until the end and amused after; your vow doesn't
  change it.

## The idea

The day becomes three parts, and in each one your hands do the thing.

1. **The ceremony** (quiet music). You choose who stands with you, say your vow, perform
   her people's rite a step at a time, and answer the question: **"I do."** That is the
   moment you are married.
2. **The feast** (the feast music starts on the cheer). The night is yours: call on your
   captains for their toasts, dance the first dance, take part in her people's custom, go
   round the tables. Any order, as much or as little as you like.
3. **The night's end.** You slip away with her, she recalls something you did tonight, and
   the closing card says what the day made.

### Rules for every beat

- **Nothing can go wrong.** The scene already says "Your vow. No wrong answers." That
  holds for all of it: no timing to miss, no reply that costs trust.
- **A tap does something you can see.** No beat is only *Continue*: the cord winds, a cup
  empties, a captain stands, a lantern rises.
- **What you chose is kept.** Every choice goes into the wedding memory and comes back in
  *Relive*.
- **No new numbers.** Regard (+10 host, +5 lord guests), renown (+15) and the cost stay as
  they are, given once. The feast is for the story.
- **Every interaction is also a reply with an id**, so autoplay (first reply at each beat)
  and the tests (`choose(id)`) still walk the whole day. Reduced motion and "Text appears
  at once" get the same choices without the movement.

### How long it is

| Path | Taps |
|---|---|
| Today | 4 |
| New, straight through (ceremony, then slip away) | about 10 |
| New, everything at the feast | about 30 |

## Part 1: the ceremony

### 1. Arriving, and who stands with you

As now: the dressed place, *Who came*, her line, *Take your place* or *Not yet*. Music is
her culture's quiet theme (`camp_<culture>`), not the feast.

New, after *Take your place*: **"Who stands with you?"** One reply per captain offered
(at most four), each with their small face and a tag from their real record:

| Offered | Tag |
|---|---|
| Most battles | "longest with you · 14 battles" |
| A hero companion (Katherine, Tariq, Mori) | their byname |
| The captain in your closest bond pair | "bonded with Ilse" |
| The newest | "newest · hasn't slept" |
| "No one. Just the two of us." | quiet |

Your second:

- stands on the right of the stage (`set_face("right", …)`), in the pixel style;
- hands you what the rite needs;
- says one line under their breath before the question;
- gives the first toast at the feast.

With no living captain the question is skipped.

### 2. Vows

As now (her vow from a time you shared; three of your own). One change: her face answers
the vow you pick. *A promise* → warm, with the lean. *Honest* → neutral, a held beat, then
warm. *Make her laugh* → amused, with the bounce. All three wedding portraits exist.

### 3. The rite, by your hand

The rite is three steps. Each is one gold reply; tapping it plays the step on a small
prop drawn over the stage (`wedding_rite.gd`, pixel art in code like the dressing), then
the next step replaces it. The third step is a choice, and it is kept.

| Culture | Step 1 | Step 2 | Step 3 (a choice) |
|---|---|---|---|
| Vardish, the cord | "Hold out your wrist." The cord is passed over the hearth-fire. | "Wind it once." It goes round both wrists. | "Hold still while she ties it." / "Tie it together." |
| Kharzani, bread and salt | "Break the bread." | "Salt it, and give her the first piece." | The contract is read; one clause is yours to add (three to choose from, one about lentils). |
| Ryumon, three cups | "The first cup: for what was." | "The second: for what is." | "The third: for what will be." Then how you sign the register: "Plainly." / "With the company's name under it." / "Let her write it." |

Her existing lines stay as the answer to step 3 ("{name} ties the knot herself. Of course
she does. It holds.").

### 4. "I do"

The centre of the day. The log clears and the place goes quiet:

- **The stage hushes.** The bunting stills, the petals stop, the lanterns burn low
  (`Dressing.hush`); the music ducks (`Sound.duck`). The plate's chip reads "The question".
- **Who asks.** The host, face on the left; with no lord hosting, the old priest as
  narration. The question is in her people's words:
  - Vardish: "Will you have each other, hearth and road?"
  - Kharzani: "Before these witnesses, and by this contract: do you consent?" Farah is
    asked three times and answers on the third. ("The form matters.")
  - Ryumon: "Is it your will that these names stand together in the register?"
- **She answers first**, in her own voice. One line each:
  - Edda: "I do. Write it down before I think of conditions."
  - Farah: "I do. I'd have said so the first time."
  - Kaede: "I do. It's the first thing I've said in years that I didn't want to check."
- **Then you are asked.** Two replies:
  - **"I do."** Gold, and it is **held**: press, and a ring fills in about a second while
    the hall holds its breath; let go and it is said. A plain tap also says it, so nothing
    is missed (and Reduced motion skips the ring).
  - **"Take a breath."** Quiet, once. Nobody moves. Your second mutters ("Captain. The
    words. Any time."), she raises an eyebrow in her own way, and then only "I do." is
    left.
- **There is no "I don't."** The last way out is *Not yet* on arriving; calling the
  wedding off stays in the journal. Leaving her at the altar would need a story of its
  own, and this plan doesn't write one.

**On "I do":**

- the bell, the cheer (`cheer_1`), the shower of petals (`Dressing.burst`);
- her face turns to amused, with the bounce;
- **"Married"** lands across the stage in brass. It moves here from the closing card, so
  it is still said once, and at the right moment;
- one line of narration for the seal (the knot holds; the contract is signed; the names
  are dry);
- the feast music starts.

`GameState.finish_wedding` is called here: married, the pact, Regard, renown, the news, a
save. Whatever happens next, you are married.

## Part 2: the feast

The same place after dark, with more lanterns lit. The plate reads "{name} · The feast".
One line sets it, then the night's replies:

| Reply | Tag |
|---|---|
| "Call for the toasts." | "your captains have been rehearsing" |
| "Ask {name} to dance." | "the first dance" |
| The custom, by her culture | "the door toll" / "the couplet" / "lantern wishes" |
| "Go round the tables." | "6 guests · 2 gifts" |
| "Slip away with {name}." | quiet · "ends the night" |

- **Any order, each once.** A finished one stays in the list, ticked and locked.
- **The night moves on** with each one: the sky darkens, the lanterns brighten, and the
  line under the plate changes ("the second cask is open", "someone is asleep under the
  long table"). No game hours pass that don't pass today.
- **Slip away is always there.** Skipping the feast is allowed, and costs nothing.

### The captains' toasts

Your captains speak as themselves, and you run the table.

**Who can be called** (you pick; up to three speak):

| Speaker | When |
|---|---|
| Your second | You chose one. Speaks first. |
| The longest-serving | Always (if not the second). |
| A hero companion | In the company. An authored toast each for Katherine, Tariq and Mori. |
| A bonded pair | `GameState.bonds()` has one. They give the toast together, on the left and right of the stage, a line each in turn. |
| The newest | A captain with fewer than two battles. |
| A mourner | `remembered_bonds()` has one. They drink to the friend who fell, by name. |

**What a toast is made of.** Three parts, each from the captain's own record, so no two
companies hear the same speeches:

1. **How they start**, by temperament (Vengeful, Steadfast, Fragile).
2. **What they know**, by the first of these that applies: wounded tonight; their
   specialization (Scout, Quartermaster, Drillmaster, Champion); their quirk (Lucky,
   Mentor, Bold); how many battles they've stood in with you.
3. **How they raise it**, by the captain's own culture: a Kharzani captain at a Vardish
   wedding does it the way it's done at home.

Examples:

- Ilse (Steadfast, Quartermaster, 14 battles): "I'm not one for speeches, so I'll say
  what I know. I counted the barrels this morning. There are enough. I counted again in
  case. To Edda and the captain. Drink."
- Bren (Vengeful, wounded): "Anyone who wrongs these two answers to me. I mean that
  kindly. I've one good arm tonight and it's holding a cup, so nobody start anything. To
  Edda!"
- A pair at rank A: "We tossed a coin for who'd speak." / "I lost." / "So we're both
  doing it." / "To Edda, who gets the captain." / "And to the captain, who gets much the
  better of it."
- A mourner: "Rowan had a toast ready for tonight. Never told me what it was. So: to
  Rowan's toast, whatever it was. And to you both."

**Your part:**

- **Call on them.** "Who'll speak?" lists the captains above by face and tag. After the
  first, "That's enough speeches" is also offered.
- **Answer each toast.** "Drink to that." or "Heckle {first}." A heckle gets a comeback by
  their temperament and makes her laugh. After a mourner's toast the heckle is replaced by
  "Pour one for {fallen}."
- **The host's toast** follows the captains', by bearing, as now.
- **Raise your cup** closes the round, as now: to her, to the company, or to absent
  friends. It is now only a toast; it no longer marries you.

**Afterwards:**

- The memory keeps who spoke and what they said.
- The next camp has a moment for it (`camp_moments.gd`, a new kind `wedding`): "{first} is
  still telling the toast. It is longer every night."
- Your second's profile gains one line: "Stood with the captain at their wedding."

### The first dance

Her portrait sways as at a dance night (`sway`), in her wedding dress. Three steps, each a
pair of replies, each answered in her voice:

1. "Lead." / "Let her lead."
2. "Turn her under your arm." / "Keep it simple."
3. "Wave the company in." (her culture's round, with `Gatherings.DANCE_ROUND`) / "Keep this
   one for the two of you."

A stretch, not in the first build: tapping on the beat. A missed beat would be a trodden
foot and a line from her, never a failure.

### Her people's custom

One short game from her culture, with one choice that is kept:

- **Vardish, the door toll.** Her household bars the hall door with a bench and names a
  toll before you may pass. Pay it with a coin, with a song (badly), or by sending your
  second to arm-wrestle the cook.
- **Kharzani, the couplet.** Nobody serves the sweets until you cap an elder's verse.
  Choose the second line: a good one, a terrible one, or one your captain whispers.
- **Ryumon, lantern wishes.** Each of you writes a wish on a paper lantern. Choose yours
  (for her, for the company, for an end to the war) and let it go; it rises over the stage
  with hers. She won't say what hers was.

### Round the tables

*Who came* opens again, and now each face is a button.

- **A lord** says one line by bearing and by how well he thinks of you.
- **A captain** who didn't toast says one by temperament.
- **The gifts** are a row under the faces: the absent ruler's (as now), the host's, and the
  company's. The company's was bought by passing a helmet round; if you have a
  Quartermaster, they kept the receipt. Gifts are words only.
- **Who stayed away** keeps its line.

### Slipping away

- **The stage** becomes her room at night if you married at her seat, otherwise the same
  place with the lanterns low. The quiet theme returns.
- **She recalls one thing you did tonight**, the first that applies: the breath you took,
  a heckle, the dance, the custom, your vow.
- **One last pair of replies**, kept: "Stay up until the lanterns go out." / "Sleep. The
  war will keep."
- **The closing card**, as now without the "Married" title: where and when, the memory
  kept, the pact in three lines, the cost and renown. One new row shows the night in icons
  (rings, cup, dance, lantern) for what you did.

### Leaving in the middle

Married at "I do", so nothing is at risk. The wedding gets a state `feast` between "I do"
and the night's end:

- Closing the scene or the app keeps it. While you're still at the place and it is before
  dawn, the Court tab offers "The feast is still going · Rejoin", and the scene opens at
  the feast with what you've done ticked.
- Leaving the place, or dawn, ends it quietly: the state becomes `done` and the memory
  keeps what happened.

## Private vows

One small addition to the quiet path in her room: after the vows she asks, "Do you?" The
same held **"I do."** Her answer: one line each. No guests, no rite, no feast, as now.

## Relive

The memory tells the day again in order: who stood with you, both vows, the rite and your
choice in it, the question and both answers, the toasts as they were said, your toast, the
dance, the custom, her last words. A memory from before this plan replays as it does today.

## Data

**`wedding`** gains a state and fields:

```text
state: … | "ready" | "feast" | "done" | …
second: captain id or -1, second_name
rite_choice, breath: bool
feast: {done: ["toasts" | "dance" | "custom" | "tables"],
        toasts: [{id, name, text}], toast, dance: [step choices], custom, last}
```

**The `ceremony` memory** gains the same fields (`set_memory_words` already adds words to
it for private vows).

**Old saves:** a `done` wedding stays done. A `ready` one plays the new day.

## Code

| File | Change |
|---|---|
| `scripts/menu/wedding.gd` | The ceremony in beats: `_arrive`, `_second`, `_vows`, `_rite_step`, `_question`, `_married`. Hands over to the feast. `_tell_again` replays the new fields. |
| `scripts/menu/wedding_feast.gd` (new) | The feast: the hub, toasts, dance, custom, tables, slipping away, the closing card. Kept apart so `wedding.gd` (525 lines) doesn't double. |
| `scripts/data/wedding_lines.gd` | The questions, her answers, the breath, the rite steps, the seals. `CAPTAIN_TOASTS` goes. |
| `scripts/data/wedding_feast_lines.gd` (new) | Toast parts (temperament, what they know, culture), hero toasts, pair and mourner toasts, comebacks, the dance, the customs, guests' lines, gifts, her last words. |
| `scripts/ui/wedding_rite.gd` (new) | The rite's prop, drawn in code by culture and step: the cord, the bread and salt, the cups and register. |
| `scripts/ui/wedding_dressing.gd` | `hush` for the question, more lanterns as the night goes on, a lantern that rises. |
| `scripts/ui/talk_view.gd` | Two reply options: `hold` (press and hold, a ring fills; a tap or `choose()` also completes it) and `face` (a small face in a reply). |
| `scripts/world/social_sim.gd` | The `feast` state and new fields, save and load, the lapse at dawn or on leaving. |
| `scripts/game_state.gd` | `wedding_seconds()`, `wedding_toasters()`, `wedding_toast(captain)`, `wedding_feast_do()`, `end_wedding_feast()`. `finish_wedding` is called at "I do" and leaves the state at `feast`. |
| `scripts/data/camp_moments.gd` | The `wedding` moment. |
| `scripts/world/settlement_screen.gd` | "The feast is still going · Rejoin". |
| `scripts/menu/romance_talk.gd` | The private "I do". |
| `scripts/menu/captain_profile.gd` | The second's line. |

**Art:** none needed. The props are drawn in code; the captains' and lords' faces and her
three wedding portraits exist.

**Sound:** none needed. `bell`, `cheer_1`, `cheer_2`, `Sound.duck`, `camp_<culture>` and
`feast_<culture>` exist.

**Writing:** about 150 short lines.

| For | Lines |
|---|---|
| Questions, her answers, the breath, seals | 15 |
| Rite steps and choices | 20 |
| Toast parts, heroes, pairs, mourners, comebacks | 55 |
| The dance | 21 |
| The customs | 18 |
| Guests at the tables, gifts | 15 |
| Her last words | 20 |

## Tests

`tests/wedding_tests.gd` changes where it expects the old order (married after the toast)
and gains:

- **The second:** offered from the real company; none with no captains; stands on the
  stage; gives the first toast.
- **The rite:** three steps for each culture; the third's choice is kept.
- **"I do":** the status is Engaged until it is chosen and Married right after; Regard and
  renown are given once, there; "Take a breath" leaves only "I do"; no reply refuses.
- **The toasts:** a toast uses the captain's temperament and what they know; a hero's is
  their own; a pair needs a bond; a mourner needs a remembered bond and names the fallen;
  at most three speak; your toast no longer changes the status.
- **The feast:** each thing once, any order; slipping away first is allowed; the memory
  keeps only what was done.
- **Leaving:** close during the feast, rejoin with it ticked; ride away and it ends as
  `done`.
- **Relive:** replays the stored toasts and choices; an old memory still replays.
- **Autoplay:** the first reply at every beat reaches the closing card.
- **Private vows:** the "I do" is there; still no pact and −10 standing.

## Order of work

Each step ships on its own.

1. **The rite by hand and "I do".** The new order (married at the question, toasts after),
   the hush, "Married" on the stage, the hold reply, her reaction to your vow. The biggest
   change in how the day feels, and the least writing.
2. **Who stands with you, and the captains' toasts.** Toasts built from records, calling
   on them, heckles, the camp moment.
3. **The feast.** The hub, the first dance, the custom, slipping away, the closing card,
   leaving and rejoining.
4. **Round the tables, Relive, the private "I do".** Then screenshots, the README and the
   full suite.

## Choices made here

Each is a judgement; say so and it changes.

1. **Do everything, not pick three.** The feast lets you do all four things and end it
   when you like. You marry once in a campaign, so a limit would only take things away.
2. **Story only.** The feast gives no Regard, morale or bond points beyond what the
   wedding gives today. If a reward is wanted, the smallest honest one is bond points for
   a pair who toast together.
3. **No refusing at the altar.**
4. **"I do" is held.** If the hold reply costs more than it's worth in `talk_view.gd`, it
   becomes a plain gold reply and the hush carries the moment.
5. **The words are "I do" in all three cultures.** The question changes with her people;
   the answer doesn't.
