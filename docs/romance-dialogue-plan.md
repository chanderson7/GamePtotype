# Romance dialogue: what's there, what other games do, and a plan

**Status:** Phases 1 (the talk itself) and 2 (pacing) are built; Phase 3 is not. Phase 2
as built: a chapter opens `CHAPTER_GAP_HOURS` (24) after the last decision, when her
letter for it arrives (letters are written at the decision and held in `pending_letters`
until their hour); there is no separate "you've left" condition, since the letter is the
pacing. One new visit a day per person (`last_visit_day` on the record; resumes are free).
Chapter 5 opens at trust 50 (`TRUST_CH5_OPEN`). Old saves have neither field and are open. Where the build
differs from Phase 1 below: the hub keeps up to two time-together lines (one when a letter
waits) and *Remember when…*, so it can reach five lines plus the exit; *Short version* and
*Another time* sit side by side under *Go on* rather than in the caption, and *Another
time* stays available after the visit's choice too; the stage lowers to 38% only while
reading a visit; reaction chips name "Edda's house" rather than the long household name.
Phase 1 renders: `mockups/romance-talk-built-1.png` to `-4.png`; Phase 2: `-5.png` (the hub after a decision, her letter the next day, the hub then).

It covers the talk with Edda, Farah or Kaede (`romance_talk.gd` on
`talk_view.gd`, content in `romance_stories.gd`, `personal_conversations.gd`,
`romance_talk_lines.gd`). The rules in `romance-personal-conversations-plan.md` still
hold: visits never score answers, and pay at most +1 trust for the first three.

Renders of every state as it is today: `mockups/romance-talk-now-1.png` to `-3.png`.
Mockups of the plan, drawn with the real talk view: `mockups/romance-talk-plan.png`.

## 1. What's there now

Played through on a phone-sized render, meeting Edda to a proposal:

1. **The hub is a menu.** Edda says one line, then you get up to six buttons in three
   grammars: a title (*Our story · Chapter 2: Something of Your Own*), a label (*Spend
   time: The Spare Spoon*), and quoted lines (*"About your letter…"*, *"Another time."*).
   She speaks once and you pick from a job board.
2. **The player has two voices.** In visits you say things a person says (*"You missed
   your own place."*). In the chapters you say task descriptions in quotation marks:
   *"Travel to nearby Thornwall to recover an old elder's written account."*, *"Sponsor
   Replacements: Sponsor up to 300 silver into an escrow fund to raise replacements for
   the district."* The player never sounds like someone in the story.
3. **Her answers carry narration inside her bubble**, with nested quotes: under the EDDA
   label, *Edda's eyes sharpen with interest. 'Few commanders look past the vanguard…'*
   The visits already use a clean `Edda:` / `You:` / narration format; the chapters don't.
4. **Numbers on everything, even where they mean nothing.** Chapter 2's three options all
   pay +15 trust and all show *Decision · +15 trust*; chapter 3's all show *+15 trust ·
   +15 house standing*. That makes a flavour choice look like a sum, and buries the one
   chapter (4) where the options really differ. (The earlier plan was right to mark
   costs and status changes; it was wrong to print identical rewards.)
5. **The whole courtship fits in one morning.** Meet, agree to court, chapter 2, a visit,
   chapter 3: trust 0 → 26 before midday, on day 1. Nothing separates chapters by time,
   by leaving, or by anything happening in the world. Every game below paces this.
6. **The face barely moves.** Five painted expressions exist; visits use two or three per
   scene, chapters use none (the face changes only with status). Across eighteen renders
   it is the same warm face sixteen times.
7. **She knows nothing about your life.** Greetings vary by status only. She never
   mentions the battle you came from, the captain you buried, your wound, the siege of
   her own town, the war between your realm and hers, the season, or how long you've
   been away, all of which the game tracks.
8. **Memories read like a log.** *Shared personal stories with Edda.*, *Agreed to court
   Edda.* appear as buttons you "say". The callback lines she answers with are good; the
   entries aren't.
9. **Reading is heavy-handed.** Three buttons after every beat (*Continue · Short version
   · Another time*), the same three each time.
10. Small things: a heart chip reading *Unknown* and a *Trust 0* bar before you've met;
    *Not now.* / *Something else.* / *Another time.* as three different exits; *+10
    Trust.* as a green ledger line after every decision.

## 2. How other games do it, and what to take

| Game | What it does | Take | Leave |
|---|---|---|---|
| **Fire Emblem (Three Houses)** supports and tea | Ranked talks earned by time spent together in the campaign; each a short self-contained scene; tea time matches topics to likes and is graded | Scenes are *earned* by what happens in the game, not bought from a menu; the reaction is the reward | The quiz: right/wrong topics with points shown |
| **Stardew Valley** | A fresh line each day, by season, weather and events; heart events at thresholds; hearts visible, per-line gains hidden | Ambient variety; time gating across seasons; keep the bar, hide the arithmetic | Gift grinding |
| **Hades** | Each character comments on your last run and what happened in it; one gift per visit; a keepsake is a physical token; the affinity heart says what unlocks next | Reactive opening lines; one meaningful thing per visit; keepsakes as objects | Nectar as a currency to spend |
| **Baldur's Gate 3 / Dragon Age** | Approval shown as a nudge *after* the fact (*Edda approves*); camp conversations unlock with story progress; companions react to world choices | Consequences told after the choice, in a word, and only when options differ | Approval farming |
| **Bannerlord** (the direct peer) | Courtship is a Charm check with trait-matching answers, then a barter with the family; widely felt as thin | The family dimension (we already have house standing and pacts) | The trait quiz |
| **Pentiment / Disco Elysium** | Choices are phrased as what you'd actually say; the game remembers and throws it back later | The player's voice; callbacks (we've started) | Length |
| **Visual novels** (mobile) | Tap to advance, auto, backlog, skip-read, one control | One quiet way to read, the rest hidden | Full-screen text boxes |

The common thread: **the character reacts to you and to time, and the game doesn't
show its working.** Our talk shows all its working and reacts to nothing.

## 3. The plan

### Phase 1: the talk itself (presentation; no rule changes; no save changes)

1. **The hub is a conversation.** Her first line is chosen from what has happened
   (see Phase 3 for the lines; until those exist, the status greeting), then at most
   three replies in the player's voice and one quiet exit:
   - *"I came about Thornwall."* · tag: *Chapter 3 · An Obligation Shared* (gold)
   - *"Nothing that needs doing today. I just came."* · tag: *time together · The Wrong
     Last Verse* (opens the next open visit; two open visits give two lines)
   - *"Your letter found me at Marchgate."* · tag: *answer it*
   - *"Remember when…"* only once there are memories
   - *"I can't stay. I wanted to see you."* (quiet)
   Locked visits don't get buttons; a line under the time-together reply says why not
   (*after your first audience*, *she's busy until the promise is mended*).
2. **Player lines, not task descriptions.** Rewrite the `text` of every chapter 2–4
   choice and chapter 3 variant as something said, with the task in the tag
   (*"Then I'll pay for the muster."* · *up to 300 silver into the district's fund*).
   Ids and effects unchanged. All three candidates.
3. **One authoring format.** Chapter texts and responses move to the visits' format
   (`Narration\n\nEdda: line`), rendered by the same beat parser, so narration sits
   centred and her words sit in her bubble, with no nested quotes.
4. **Show costs, not scores.** Before a choice: silver, rations, a status change
   (*now courting*), a promise broken (red). Never a trust number when every option
   pays the same. Where options differ (chapter 4), say it in words: *Edda's trust · the
   elders' displeasure*. After a choice: two chips in the log, *Edda trusts you more* /
   *House Caldmoor takes note*, and the trust bar grows. Exact numbers stay on the
   confirmation step for things that cost or can't be undone (wedding, private vows,
   parting, breaking word).
5. **A face for every line.** Each chapter response gets an expression in data
   (`"face": "warm"`); the big portrait changes with the line (crossfade; none with
   reduced motion). Visits keep their per-scene faces.
6. **Reading.** Tap anywhere continues (already). One small chevron reply, *Go on*,
   instead of three buttons; *Short version* moves to the caption as a small text link;
   *Another time* appears only before the choice and after the end.
7. **Memory entries become sentences.** *The spare spoon.* / *The day I asked to know
   her better.* / *The council, and what I said.* New text in `add_memory` calls; old
   entries keep their text.
8. **Small fixes.** No heart chip or trust bar before you've met (*Not yet met* in the
   caption instead); one exit wording (*Another time.*) everywhere; the stage shrinks
   from 46% to 38% of the screen while reading a visit.

Tests: `talk_and_memories_tests` updated for the new reply ids; a new check that no
reply tag contains *trust* in chapters 2 and 3; every chapter response has a face; the
hub never shows more than five replies.

### Phase 2: pacing (small rule changes in `social_sim.gd`)

1. **A chapter a visit, a day between.** After a chapter decision, the next chapter
   opens when at least `CHAPTER_GAP_HOURS` (24) have passed *and* you've left the
   settlement, or when her letter arrives. Every chapter opening sends a short letter
   (chapter 2 already does; add 3, 4 and 5 for each candidate), so the invitation back
   is the pacing. The preview reason reads *Not yet; she'll write.*
2. **One visit a day.** After a visit the hub says *It's late. Another day.* and the
   time-together line is gone until the next morning. Dances already have their own
   cap and aren't affected.
3. **Chapter 5 waits** until trust can actually carry a yes: it opens at the first
   visit after chapter 4 where trust ≥ 50, so the proposal scene never appears as a
   list of locked options.

Saves: two new fields on the quest (`chapter_opened_hour`, `last_visit_day`), absent in
old saves and treated as "open now". Tests: the gap is enforced; the letter arrives; an
old save continues.

### Phase 3: she knows what happened (content)

Opening lines per candidate, picked by priority from the world, one per visit:

| When | Edda, for example |
|---|---|
| A captain of yours died since you last came | *You came back with fewer than you left with. Word of the ford reached us before you did.* |
| You're wounded | *Sit before you fall over. No, the chair. I'll move the ledgers.* |
| Her town was besieged or changed hands | *You'll have seen the walls. We're fine. I'm saying that so it becomes true.* |
| Your realm is at war with hers | *My cousin asked which side you're on today. I told him mine.* |
| You won a battle within two days' ride | *The whole hall is telling your battle. They've given you a horse you don't own.* |
| Away more than twenty days | *Twenty-three days. I didn't count. The ledger did.* |
| Winter / rain outside | a line for each |
| Nothing in particular | the status greetings that exist now |

Eight to ten per candidate, in their voice (Farah elaborate then plain, Kaede precise
and playful). Facts come from what already exists: captain history, `wounded`, map
notices, realm relations, the day count since the last visit, the weather.

Later, if wanted: a visit unlocked by the world rather than by order (one that opens
only after you've lost a battle; one only in winter), and after a broken promise, the
greetings carry it for a while even once it's mended.

## 4. Order of work

1. Phase 1 items 1–4 (hub, player lines, one format, costs not scores): the biggest
   felt change, no save impact. About a day with the three candidates' rewrites.
2. Phase 2 (pacing) with its letters.
3. Phase 1 items 5–8, then Phase 3's lines.

Each step runs `talk_and_memories_tests`, `personal_conversation_tests`,
`relationship_tests`, `letters_tests`, `scroll_touch_tests` and `menu_tests`, and a
phone render of the hub, a chapter, an after-choice screen and a visit.

## Sources read for section 2

- Bannerlord courtship: [Gamer Guides](https://www.gamerguides.com/mount-and-blade-ii-bannerlord/guide/character-creation/character-development/marriage), [PC Gamer](https://www.pcgamer.com/mount-and-blade-2-bannerlord-marraige-children), [GameWatcher](https://www.gamewatcher.com/mount-and-blade-2-bannerlord-marriage)
- Baldur's Gate 3 approval: [bg3.wiki](https://bg3.wiki/wiki/Approval), [a write-up of the companion design interview](https://gamegeeker.com/de/news/baldurs-gate-3-companion-affinity-system-interview?market=DE)
- Hades gifts and keepsakes: [Critical Play: Hades](https://mechanicsofmagic.com/2026/05/11/critical-play-hades-2/), [Destructoid on Hades II relationships](https://destructoid.com/?p=518452)
- Stardew Valley pacing: [slow reveal of characters over years](https://alamrafiul.com/blogs/slow-reveal-characters-over-years/), [Stardew modding wiki: writing heart events](https://stardewmodding.wiki.gg/wiki/Tips_for_Heart_Events_-_Writing_and_Narrative_Design)
- Fire Emblem tea time: [GamesRadar](https://gamesradar.com/fire-emblem-three-houses-tea-guide), [Tom's Guide on the illusion of choice](https://www.tomsguide.com/opinion/fire-emblem-three-houses-dialogue-choices)
