# Romance talks, memories and captain bonds: UI plan

A plan, not yet built. Part 1 brings the romance screens up to the lord conversation
(face to face, one exchange at a time) and makes memories something you can open. Part 2
stops captain bonds ("supports") from interrupting the map once per bond after a battle.
The rules in `romance-personal-conversations-plan.md` still hold: visits never score
answers, never start on their own, and pay at most +1 trust for the first three.

## What's there now

Romance (screenshots of each were taken for this plan):

1. **Audience** (`conversation.gd`) is a text page: a three-line title, trust and standing
   as a sentence, a small portrait, the chapter text, and choices as plain buttons. Your
   answer replaces the chapter text, so you lose what was said. "Spend time / memories"
   leaves for a second screen.
2. **Visits list** (`personal_conversation.gd`): every locked visit repeats "Introduce
   yourself in an audience first." under it, six times for Edda alone.
3. **Visit reader**: paragraphs paged with Previous / Continue under a strip of the room,
   with the portrait small at one side. "Edda:" and "You:" are text prefixes, not speakers.
4. **Profile** (`people.gd`): a strong portrait and chapter steps, but memories are the
   last eight plain lines ("Day 3 · Shared personal stories with Edda."), with no link to
   the visit, the letter, the decision or the place. Memories are kept three times over
   (`memories`, `memory_log`, the relationship's `memories`).
5. Chapter decisions with real costs (trust, house standing, 100 silver and 100 rations,
   private vows) look exactly like chat.

Bonds:

1. Each rank-up and each memorial is queued in `bond_events`, and the map jumps to the
   full-screen `bond_intro` for each, one after another: three bonds after a battle are
   three interruptions, each with three buttons.
2. The battle results list every pair that earned any points ("+0.4 bond points"), up to
   fifteen rows with six captains, so the rank-ups that matter are hard to find.
3. A camp conversation is a page of template passages, the same shape for every pair, and
   an earlier rank's talk can't be read again once the bond has moved on.

## Part 1: Romance talks

### One screen, face to face

Reuse the shell built for lords (`lord_conversation.gd`): pull the stage, reply bubbles,
notes and "you said" line into a shared `talk_view.gd`, and drive it with romance content.

- **Stage**: their room (`common_room`, `envoy_room`, `archive_room`) or the place they
  live (Ravensford, Qasr Hamra, Kitayama) at the hour it is; the painted portrait large,
  with its five expressions changing per line (a short crossfade, none with reduced
  motion); a nameplate with their status (Acquainted, Courting…) and a trust bar marked at
  60, where vows and a wedding open, plus house standing as a small chip.
- **One hub** replaces the Audience page and the Visits list:
  - *Our story: Chapter 2, Something of Your Own* (gold; the decisions live here).
  - *Spend time*: the visits open now, each with New and "about 2 minutes"; the locked
    ones collapse into one line ("3 more after your first audience").
  - *About your letter…* when a letter from them waits for an answer, answered here.
  - *Remember when…* (see memories).
  - *Another time* (leave).
- **Reading**: their lines on the left under their name, yours on the right, narration
  centred in italics without a bubble. Tap anywhere to go on (a Continue button too, for
  keyboards). What's been said stays on screen above, which replaces Previous and History.
  *Short version* stays as a small link.
- **Two kinds of reply, kept apart**:
  - *Chat* (visits): no tags or numbers. One line at the top: "No wrong answers."
  - *Decisions* (chapters): a Decision marker and gold edge, with what it does listed
    plainly (+15 trust; −10 house standing; 100 silver, 100 rations). Marriage, private
    vows and parting ask once more before they're final.
- **After a visit**: a keepsake card slides in ("A memory kept: …"), with "+1 trust (2 of
  3)" only when trust actually changed.
- **Strained**: the portrait turns concerned, a red chip says why ("a broken promise"),
  and the repair line is offered first, in gold.
- **After the story**: married, sworn friends or parted, the hub stays: spend time,
  remember, and a greeting chosen from the visits you've shared.

### Memories you can open

Data: one list per person, each memory `{id, day, kind, text, place, chapter, scene_id,
letter_id, said, answer}`, where `kind` is visit, decision, letter, ceremony or move.
Old string memories become `kind: "note"` with their day. Keep writing the old fields for
one save version, then read only the new list.

- **Memory book** on the profile, replacing the last-eight list: a timeline grouped by
  chapter, each memory a keepsake row with an icon (cup for a visit, seal for a letter,
  ring for vows, scroll for a decision, pin for a move), the day and place, and its line.
  - A visit opens its replay (the existing replay mode, marked "Memory · no rewards").
  - A letter opens the letter.
  - A decision shows what you said and how they answered.
  - A move shows the place on the map.
- **Remember when…** in the talk: pick a memory, and they answer with a callback line.
  That's one authored line per visit (18) and per chapter decision; it never pays trust.
- The profile's "memories" tile opens the book.
- Later, if wanted: a Keepsakes tab in People with every memory, filtered by person.

### Smaller things

- A settlement's Court tab says "Edda would like a word · new" when there's something
  new; nothing starts on arrival.
- Expressions per line move from code (`personal_conversations.gd` matches scene ids
  today) into each scene's data.
- Pronouns come from the person's data; the audience page writes "her" directly today.
- With illustrations off, the talk falls back to text with the same bubbles; text size
  settings apply to every line.

## Part 2: Captain bonds ("supports")

"Supports between lords" is read here as the bonds between your captains (ranks C, B and
A), whose screens queue up after a battle.

Rule: **a battle interrupts you at most once for bonds, and only the first time.**

1. **One summary, on the results screen.** Its bonds section shows:
   - rank-ups first, each a pair of faces with the new rank and what it does ("Rank B ·
     +1.5 morale a second nearby, +10% damage");
   - memorials in their own darker block ("Fenwick remembers Brann · 6 battles together");
   - then a single line, "7 other pairs grew closer", which opens the full list.
2. **No more interstitials.** `bond_intro` is kept only for the very first rank C, where it
   explains what bonds do, once. Every later rank-up and memorial is told in the results
   summary.
3. **Talks wait at the fire.** Each new rank opens a camp talk, marked New. The Warband
   button on the map and Home's camp card carry a badge ("3 talks at the fire"), and
   nothing opens until you choose it.
4. **A support talk scene**: the camp painted at night, the two captains' portraits facing
   each other, lines as alternating bubbles in the shared talk view. Tabs for C, B and A
   reread each rank's talk, and the effect sits in a chip. Memorial talks keep the empty
   place: the fallen captain's portrait greyed.
5. **A Bonds tab in the Warband**: each captain with their partners, rank badges and a bar
   to the next rank; sort by "closest to a rank"; a hint on how bonds grow (fighting within
   reach of each other); fallen partners greyed.
6. **Saves**: queued `bond_events` from older campaigns become New talks at the fire, not
   interstitials.

## Order of work

1. **Bond batching** (smallest change, biggest annoyance): the results summary, stopping
   the interstitials, the fire badge. Tests: several rank-ups after one battle make no
   map interruption, and appear once in the results and as New talks.
2. **Shared talk view**: extract from the lord conversation; lords keep working
   (`lord_conversation_tests` stay green).
3. **Romance hub and reader** on the talk view, with decisions shown apart from chat.
   Tests: every chapter decision is reachable and still applies the same effects;
   the visit trust cap is unchanged; replays pay nothing.
4. **Memory data and book**, with save migration and tests for old saves.
5. **Support talk scene and the Bonds tab.**
6. **Content**: callback lines, greetings from shared visits, per-line expressions.

Mockups of the romance hub, a visit mid-read, the memory book, the bonds summary and the
support talk come before building, in the game's pixel-art style.
