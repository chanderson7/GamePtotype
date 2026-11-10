# Romance dialogue: choices you make, and memories with more in them

A plan, written after fixing the bug where a romance memory put all its dialogue on screen
at once. The fix is in; the rest is planned here. It builds on
`romance-personal-conversations-plan.md` (the 18 visits as built, and their writing rules)
and `romance-dialogue-plan.md` (the talk screen).

## The bug, and what was done about it

Two causes, both in how the talk put lines on screen:

1. **Visits and memories retyped every line.** Each "Go on" cleared the log and said every
   line so far again, and each of her lines writes itself out. So every step restarted
   the whole conversation typing at once. Reopening a memory ("Tell it again") made it
   obvious. Now the lines already heard are shown whole and only the new one is written
   out (`romance_talk.gd`, `_render_visit`; `say(..., instant)` in `talk_view.gd`).
2. **Story chapters were dumped whole.** A chapter's text, her answer to a decision, the
   untold account of chapter 3's deed, the sixth chapter and the private vows were each
   said in one go, every line typing together, with the choices already showing under
   them. Now they are told a line at a time: Go on (or a tap) for the next, "All of it"
   for the rest at once, and only then the choices (`TalkView.tell_lines`, used by
   `romance_talk.gd`'s `_tell`).

Found on the way: the small line under each answer (what it is: "ask about her work",
"offer help") was squeezed to one letter per line, a wrapping label given no width in its
row. It now takes the rest of the row (`TalkView.marks`, and the same in `fx_note`).

What a decision changes is applied before its answer is told, so leaving part way loses
nothing: the promise or the wedding still stands and the hub picks it up.

## What's there now

- **18 visits**, six each for Edda, Farah and Kaede (`personal_conversations.gd`). Each is
  one passage (8 to 12 lines), then **one choice of three**, her answer (1 to 3 lines) and
  a closing. The three options are nearly always the same shape: ask about it, say
  something kind, or share something of yours.
- **The choice comes late.** You read ten lines before you say anything. For most of a
  visit you are an audience, not a participant.
- **She doesn't remember what you said.** A visit's choice is saved, but only three
  lines anywhere in the game look at it, all in the last visit (the "coda").
- **Your voice is the same in friendship and romance.** Rule 8 of the old plan kept
  flirting for an established romance, and then no option ever used it.
- **The memory book** lists one-line summaries. A visit can be told again; a chapter
  decision shows "You said … " and her whole answer squeezed into one grey line under
  the button.

The writing itself is good: specific, funny, unhurried. This plan keeps that and gives it
more room, more of the player, and more continuity.

## What to take from Fire Emblem

Fire Emblem's support conversations are the model the old plan studied. Three more things
are worth taking:

- **Ranks (C, B, A, S).** Each support is short and changes one thing; the four together
  make an arc. Our six visits already unlock in order; naming them as ranks, and giving
  each rank a job (C: the habit, B: the reason for it, A: the cost of it, S: what changes),
  gives the writer a shape and the player a sense of progress.
- **A running gag and a hidden depth.** Frederick clears pebbles from the road; that's
  funny, and later it's love. The best supports repeat a small, visible habit until it
  means something. Each of ours gets one.
- **Tea Time's reactions (Three Houses).** Between topics you react to what they say:
  agree, laugh, scold, stay quiet, and they answer the reaction. This is the "couple of
  options" the visits need: small, quick, in the middle of the talk, changing her next
  line or two rather than the story.

Personalities below are references for how a trait can play out across an arc, not
characters to copy. No names, plots, lines or looks come over; Edda, Farah and Kaede keep
their own lives, families and places.

## Part 1: dialogue with choices in it

### Two or three choice points a visit

Each visit is rebuilt as two or three short movements with a choice between each:

| Where | How many options | What it does |
|---|---|---|
| **Coming in** (after 2 to 4 lines) | 2 | How you join in: help her, tease her, ask, or wait. Sets the tone she answers in for the next movement. |
| **A reaction** (middle) | 2 or 3 | Tea Time style: to something she has just said. Ask more, laugh, share, or stay quiet. Changes her next 1 to 3 lines; sometimes adds a fact. |
| **The answer** (end, as now) | 3 | What you say that matters most here. Her answer, then the closing. |

- **No more than six lines between choices**, so the player is in it from the start.
- **Still no wrong answers.** Nothing is scored and trust is unchanged (the existing rule:
  the first completion of a visit gives its one point). What changes is what she says,
  and what she remembers.
- **Each option shows what kind of thing it is** with a small icon, as the hub's replies
  do: *ask*, *tease*, *share*, *comfort*, *quiet*, and in a romance, *heart*.
- **Your own words.** Options are things you say, in the second person's voice, not
  descriptions ("You know she's teasing you" is never an option).

### She remembers

- **Every choice can leave a mark** (`"sets": "edda.helped_count"`). Marks are worked out
  from the saved choices, never stored separately, so they always agree with the record.
- **Every visit after the first reads at least one mark** from an earlier visit: a line
  added, a line changed, or a different first line. Greetings (`romance_talk_lines.gd`),
  letters and the codas read them too.
- **The memory book says what you did**, not only what happened: "Counted spoons with
  Edda, and laid one at her place" or "…and teased her about the drawer."

### Friendship and romance

- On a romantic route, the closing answer of each B, A and S visit offers one *heart*
  option: a compliment, a hand, an admission. On a friendship route the same slot is a
  warm, friendly one. Neither is better; she answers each in kind.
- C visits stay the same on both routes: you are still getting to know each other.

### On the screen

- Lines come one at a time (done), with "All of it" to skip ahead and "Short version"
  for a first reading, as now.
- **Replays keep your path**: "Tell it again" plays the visit with the answers you gave.
  Once it ends, **"What if I'd said…"** lets you try the other options. It changes
  nothing and says so, as the replay already does.
- **Decisions in the memory book open as a moment**, not a grey line: the talk opens on
  what you said and her answer, told a line at a time, then closes. (Same screen as a
  replayed visit.)

### Data and saves

- **Scene format version 2**, alongside version 1 so characters can move over one at a
  time. Still plain text, a paragraph a line, "Edda:" for speakers. A scene becomes a list
  of movements; a movement ends at a choice point:

  ```gdscript
  "edda_spare_spoon": {"version": 2, "rank": "C", "title": "The Spare Spoon",
      "movements": [
          {"text": "Edda stands beside…\n\nEdda: Seven spoons…", "point": "in"},
          {"text": "…", "point": "react"},
          {"text": "…", "point": "answer"},
      ],
      "points": {
          "in": [{"text": "I'll count. You sit.", "tone": "share", "lines": "Edda: …", "sets": "edda.helped_count"},
                 {"text": "Is this an inspection?", "tone": "tease", "lines": "Edda: …"}],
          ...},
      "closing": "…", "summary": "…", "memory": "Counted spoons with Edda{edda.helped_count: , and laid one at her place}."}
  ```
- **Saves**: a completed visit keeps `choices: {point: option}`. The old single `choice`
  becomes the `answer` point, so every finished visit in every old save still reads
  right; marks from points it never had are simply absent.
- **Reading position**: `node` becomes the movement index, `choice` the point's option;
  `normalize_reader` carries old cursors over, as it did for version 1.
- **Tests**: every scene's points have 2 or 3 options; no movement has more than six lines
  before its point; every mark set somewhere is read somewhere; every visit after the
  first reads one; an old save's finished visits replay; a replay changes nothing.

## Part 2: the memories, rewritten

### Rules for all three

The old plan's eight rules stand. Added:

1. **Ranks.** C (visits 1 and 2): the habit, light. B (3 and 4): the reason under it. A
   (5 and 6): what it costs her, and you there for it. S (7 and 8, new): what has changed,
   on a romantic route or between sworn friends (status committed, married or the
   friendship route's end).
2. **One running gag each,** seen in most visits, paid off in the S visits.
3. **One thread each,** a person or a thing from her past that comes back across the
   visits and is settled (not solved) by the end.
4. **She asks you something** at least twice across the eight. The player has a past too;
   what you say about it is remembered (a mark), and she refers to it later.
5. **Longer, in movements:** 14 to 22 lines a visit, in two or three movements, against
   8 to 12 now.

### Edda: the steward who sets a place for everyone but herself

**References.** Frederick (*Awakening*): readiness taken to comic lengths, duty first,
and the soft man under it who can't sit still while others are tired. Mercedes (*Three
Houses*): warmth that shows itself as hospitality, a quiet sadness carried kindly. Ingrid
(*Three Houses*): what she owes her family against what she wants. Not taken: knights,
nobility, a prince to serve, a lost fiancé, a hidden brother.

**Running gag:** counting. Spoons, chairs, sacks, people at a table, always one short,
because she never counts herself.
**Thread:** her aunt, who visited the outlying houses and missed Edda's celebration
(visit 3). Edda has become her aunt; the arc ends with her choosing to be the one who
comes home on time.
**She asks you:** visit 4 (what you'd do with a free morning) and visit 7 (who set a place
for you, growing up).

| Rank | Visit | What happens, and the choices |
|---|---|---|
| C | **The Spare Spoon** (rewritten) | Counting places for a supper. *In:* help her count, or ask if this is an inspection (she hands you the spoons either way, differently). *React* to the uncle who set an extra bowl without a word: laugh, or ask who the place was for. *Answer* as now. **Mark:** you counted with her. |
| C | **The Wrong Last Verse** (rewritten) | Two endings to a song. *In:* hum the tune wrong on purpose, or ask what it is. *React* to the cousin's version: demand it, or defend the respectable one (she's delighted to be argued with). *Answer* as now. **Reads:** if you counted with her, she counts the verses. |
| B | **Boots by the Door** (deepened) | The aunt and the missed celebration. *In:* stand with her in the doorway, or bring the boots in out of the wet. *React* to "I was still furious": was she right to be, or did her aunt know. *Answer* as now. Adds: she has missed a celebration herself this year, for a village roof. **Mark:** what you said about the aunt. |
| B | **A Morning Unclaimed** (deepened) | A free morning. *In:* insist on nothing to do, or bargain her down to one errand. *React* to the stone-skipping cousin. *She asks you* the same question; you answer (the river, a long sleep, a market, a walk). **Mark:** your morning, for visit 7 and her letters. |
| A | **The Blot in the Ledger** (deepened) | The corrected page. *In:* ask to see it, or wait to be shown. *React* at the family's kitchen table: tell her you'd have been as frightened, or ask what she wishes she'd said. *Answer* as now. Adds: she has hidden a mistake this year and you are the first she tells; she asks you to read the corrected entry with her before it goes out. |
| A | **A Place With No Task** (deepened) | Two chairs, no errand. *In:* sit first, or wait for her to. *React* to the crooked cloth. *Answer* as now. Callbacks: the drawer, the verse, your morning, the aunt. |
| S | **Who Set Your Place** (new) | She asks you who set a place for you, growing up. Three answers (a parent, a stranger, no one), each remembered. Then she lays a place for you at her own table in her own hand, and counts it out loud: "Two." The counting gag ends. |
| S | **Home on Time** (new) | A village feast she's arranged, and a roof she could go and see to instead. *In:* remind her of her aunt, or say nothing and let her choose. She stays. Romance: she asks you to stay too. Friendship: she asks you to carry the bread. |

### Farah: the envoy who can answer for everyone except herself

**References.** Claude (*Three Houses*): charm and jokes worn as armour, a dream of open
borders, and how slowly someone like that lets you see the plan. Dorothea (*Three
Houses*): the public self everyone admires, and the wish to be wanted for the other one.
Not taken: a secret royal line, schemes against allies, a stage career, an orphan's past.

**Running gag:** sentences that take the scenic route. Her drafts, her toasts, her
apologies; and once in a while five plain words that land like a door shut.
**Thread:** her cousin's question, "Are you happy?" (visit 3), answered at last in visit 8.
**She asks you:** visit 2 (a place you know by a name no map uses) and visit 7 (when you
last said exactly what you meant).

| Rank | Visit | What happens, and the choices |
|---|---|---|
| C | **Three Ways to Ask for Supper** (rewritten) | The over-drafted note. *In:* read the grandest draft aloud, or draft one even grander. *React* to the cook's year of lessons: laugh, or ask if she minded. *Answer* as now. **Mark:** you out-drafted her. |
| C | **The Street With Two Names** (rewritten) | Crooked Lantern. *In:* guess why it's crooked, or ask which name she uses. *She asks you* for a private place-name; you give one (it is remembered, and she uses it later). *Answer* as now. |
| B | **The Letter Without a Seal** (deepened) | Her cousin's question. *In:* sit where you can't read it, or ask what it says. *React* to "I do. Mostly.": ask about the part she didn't choose, or let "mostly" be enough. *Answer* as now. **Mark:** how you met the question. |
| B | **The Wrong Courtesy** (deepened) | The enormous gift at an informal supper. *In:* ask what the gift was, or guess (badly, on purpose). *React* to the host handing her a dish towel: say that's the best kind of welcome, or that ceremony has its place. She agrees with both, differently. |
| A | **My Own Answer** (deepened) | The bookbinding she wanted to learn. *In:* hold the pages, or ask to try. *React*: is it a regret, or a thing she can still do. *Answer* as now. Adds: an envoy's post she was offered and turned down, and why she isn't sure she was right. |
| A | **No Reply Required** (deepened) | The dog and the long loaf. *In:* demand the full story, or the five-word version. *Answer* as now. Callbacks: the soup, your place-name, the letter. |
| S | **When You Last Said It Plainly** (new) | She asks you when you last said exactly what you meant. Three answers, remembered. Then she tries it herself, in five words, about you. Romance: what she feels. Friendship: that she trusts you. The scenic-route gag ends with a short sentence. |
| S | **The Short Answer** (new) | Her cousin writes again. This time she reads you her reply, which is short, and asks whether it sounds like her. *Answer:* yes; or yes, and add one line (you choose it). The thread closes. |

### Kaede: the archivist who records everything except her own preferences

**References.** Miriel (*Awakening*): a scientist's method turned on feelings, with deadpan
results. Linhardt (*Three Houses*): bored by what bores him and suddenly fierce about what
interests him. Lysithea (*Three Houses*): precise, quick to correct, and secretly fond of
something she thinks undignified. Not taken: magic or research into crests, a shortened
life, noble houses, a fondness for sweets.

**Running gag:** the cat on her private map, whose attendance is never guaranteed, and her
deliberately terrible mystery theories.
**Thread:** the childhood nickname she rejected (visit 3), and the aunt who gave it.
**She asks you:** visit 4 (a place that changes each time you go there) and visit 7 (a
preference you've never said aloud).

| Rank | Visit | What happens, and the choices |
|---|---|---|
| C | **A Map of Useless Places** (rewritten) | Her private map. *In:* ask about the cat, or point out a mistake (she is thrilled: a correction). *React* to "it offers no strategic value": agree that's the point, or suggest one useless place of your own. **Mark:** the place you named. |
| C | **A Very Bad Mystery** (rewritten) | The forged letter. *In:* accuse the least likely suspect, or the cat. *React* to her reasons for rereading it: tease her, or confess a bad book of your own. *Answer* as now. |
| B | **A Name in the Margin** (deepened) | The rejected nickname. *In:* ask what it was, or don't. If you don't, she tells you in visit 8. *React* to the aunt: ask about her, or share a name you were called. **Mark:** whether you asked. |
| B | **The Missing Street** (deepened) | A map that won't hold still. *In:* help her measure, or tell her to draw the afternoon instead. *She asks you* for a place that changes each time you go there. **Mark:** your place. |
| A | **The Page She Kept** (deepened) | The private page in a reconciliation record. *In:* ask whether you may read it, or say you won't. *React* to her teacher's lesson: records have readers. Adds: a record she is keeping now in which she wrote your name, and isn't sure in which kind of page. |
| A | **Room on the Map** (deepened) | Your place beside hers on a new map. Callbacks: your useless place, your changing place, the cat, the mystery. |
| S | **A Preference, Stated** (new) | She asks you for a preference you've never said aloud. You give one; then she states hers, without hedging, for the first time. Romance: you. Friendship: that she'd like to keep these afternoons. |
| S | **The Name, Used** (new) | She lets you use the nickname, once, if you asked about it in visit 3; or tells it to you now if you didn't. The cat attends. |

## Order of work

1. **Format and saves** (version 2 scenes beside version 1, marks, the reader, old saves
   read right) with one rewritten visit as the test case: Edda's *Spare Spoon*.
2. **The screen**: tone icons on options, replays keeping your path, "What if I'd said…",
   decisions opening as a moment in the memory book.
3. **Edda's eight**, written and checked against the rules; then **Farah's**, then
   **Kaede's**. Each character is a self-contained step: the others stay on version 1
   until their turn.
4. **Greetings and letters** that read the marks, after each character's visits.
5. **Editorial pass**: read each character's eight in order, aloud; check no visit runs
   more than six lines before the player speaks, that the gag and the thread land, and
   that both routes read well.

## Questions to settle before writing

1. **Eight visits or six?** The S visits are new content (six more scenes). Without them,
   the six are deepened in place and the gags pay off in visit 6.
2. **How far should the player's *heart* options go?** The plan keeps them to a
   compliment, a hand, an admission: affectionate, not explicit.
3. **"What if I'd said…"**: some players like seeing the paths not taken; others feel it
   spoils a choice. It could be offered only after a visit has been finished once (as
   planned) or not at all.
