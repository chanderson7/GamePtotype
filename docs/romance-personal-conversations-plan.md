# Personal conversations for romances

**Status:** Edda implementation complete, 2026-10-28. Builds on `main` at `2b93920`.
Farid and Kaede remain future content until their main routes exist. This document retains
the design and research for all three candidates; the implementation record below identifies
what shipped locally.

### Implementation record

- `scripts/data/personal_conversations.gd`: six original Edda scenes, three equally rewarded
  replies each, short summaries, neutral/romantic coda, conditional remembered callbacks.
- `scripts/world/social_sim.gd`: persistent person records, introduction/location/strain/
  prerequisite checks, per-scene resumable progress, completion validation, first-three
  bonus claims including zero-delta claims at 100 trust. New campaigns reset the records.
- `scripts/game_state.gd`: world-derived location/setting context and separate personal
  action wrapper. Atomic save replacement preserves the previous file on write failure;
  the wrapper also restores social state and reports a retryable error.
- `scripts/menu/personal_conversation.gd` and `scenes/personal_conversation.tscn`: scrollable
  library, locked-topic explanations, reader, summary, archive, and keyboard/back navigation.
  People and the audience page provide entry points. Replays use local reader state and
  remembered relationship/callback context; they cannot rewrite campaign choices.
- Save version remains **6**: this is an additive optional social field, defaulting to empty
  in existing saves. No main chapter is retrospectively counted as a personal conversation.
- Validation: `tests/personal_conversation_tests.gd` passes 79 checks, including real UI
  interactions, JSON resume, alternative replies, side-effect isolation, limits, prerequisite
  gates, relocation, separation, and disabled-invitation behavior. Existing relationship and
  menu tests pass. Ten isolated disk checks cover atomic replacement, reload, failed-write
  rollback, and successful retry. Phone-sized library, opening and summary renders reviewed.
- Deliberate implementation detail: unfinished progress is keyed by scene, so beginning a
  different topic does not discard an interrupted visit. A resumed unfinished scene uses
  the current relationship/setting; completed archive context remains historical.


## 1. Recommendation: mostly story, with a small relationship effect

Give these conversations a **small, capped trust benefit**. The original request was for
backstory with no gameplay effect; the follow-up asks whether a slight relationship effect
would help. The proposed compromise is:

- **+1 trust for each of the first three different personal conversations completed with
  a character, for a maximum of +3 per character per campaign.**
- Every response receives the same completion benefit. Curiosity, humor, disagreement,
  and comfortable silence are ways to express the player character, not scored answers.
- Remaining scenes and all replays give no additional trust. Their reward is the scene.
- No change to house standing, money, food, renown, troop statistics, captain bonds, pact
  terms, cooldowns, or campaign time. No new quests or obligations are accepted here.
- Skipping the entire feature has no penalty. Required romance chapters, mutual romantic
  intent, and repairing a broken promise remain necessary regardless of optional trust.

This makes taking an interest feel acknowledged without making personal conversations a
major progression route. It also avoids implying that the only valuable response to a
character's childhood story is the one that produces a larger number.

| Model | Advantage | Cost | Decision |
|---|---|---|---|
| No trust change; cosmetic memories only | Fully satisfies a story-only role; no incentive to optimize dialogue | Time together is acknowledged only through writing | Keep as the fallback if playtests turn the scenes into a checklist |
| +1 on the first three unique completions | A small acknowledgment; fixed maximum; all responses equally valid | Can slightly affect a numerical trust threshold | **Recommended starting design** |
| Different points for preferred answers, or repeatable gains | More immediate numerical feedback | Encourages answer guides, repetition, and treating backstory as a quiz | Exclude |

### Numerical effect and boundaries

The current uncomplicated Edda route grants 65 trust and marriage requires 60. Reading
none of these scenes preserves that route; reading three makes its total 68. The extra
three points are smaller than any main chapter's 10–15-point positive reward.

They can move someone from 57 to 60 if all other commitment conditions have already been
met. That is an intentional slight effect, not a claim that these scenes are mechanically
inert. They cannot set romantic intent, advance a main chapter, clear `strained`, award
family approval, or substitute for a required milestone. Verify those requirements at the
commitment action even when the numerical trust threshold is satisfied.

Use one campaign-wide cap per persistent person, shared across friendship, courtship,
marriage, separation, and reconciliation. Every character gets the same rules. No separate
intimacy currency, romance skill, or repeatable conversation grind is needed.

## 2. Fire Emblem: Three Houses research and writing lessons

Use the game's English support dialogue as a writing reference. The links below are
transcripts served from game data by the independent FE Datamine archive. The “lesson”
column is our interpretation; the proposed Bannerfall scenes are original writing.

| Conversation studied | What the scene does | Writing lesson for Bannerfall |
|---|---|---|
| [Ferdinand / Dorothea, A](https://houses.fedatamine.com/en-us/supports/Ferdinand/Dorothea/A) | A remembered childhood encounter explains an existing mistrust, then gains another perspective | Let a later detail change how the player understands an earlier habit; useful for Edda's concern with recognition |
| [Sylvain / Mercedes, A](https://houses.fedatamine.com/en-us/supports/Sylvain/Mercedes/A) | Flirtation gives way to a conversation about family expectations and being understood | Farid can use social fluency to avoid speaking personally; another person can notice without interrogating him |
| [Raphael / Ignatz, A](https://houses.fedatamine.com/en-us/supports/Raphael/Ignatz/A) | A childhood drawing and a family letter lead to encouragement about an artistic ambition, with humor retained | Use small objects and ordinary pleasures to reveal an interior life; useful for Kaede's private maps |
| [Hilda / Seteth, B](https://houses.fedatamine.com/en-us/supports/Hilda/Seteth/B) | Sharing an authored story exposes a tender side beneath a stern public manner, provoking gentle teasing | A serious character can be funny and affectionate without losing their competence |

Apply these techniques across the cast. Edda is not a renamed Dorothea, Farid is not
Sylvain with a different title, and Kaede does not inherit Ignatz's family or ambitions.
Their lives must fit Bannerfall's villages, courts, correspondence, and archives. None
of the sample dialogue below is quoted from Fire Emblem.

### Shared writing rules

1. Start with something happening: a mislaid spoon, an over-edited letter, a ridiculous
   passage in a book. Let personal information enter through that activity.
2. Each scene adds one specific fact, one reaction, and one small change in how the two
   people speak to each other. Avoid delivering an entire biography in one speech.
3. At least half the scenes are light, affectionate, or curious. Every character needs
   pleasures and habits as well as regrets.
4. The player is a participant. Offer an observation, a question, or a little self-disclosure;
   do not make every response a diagnosis or a promise to fix the character's life.
5. Characters can disagree, decline a question, and retain an awkward habit. A successful
   romance does not remove every insecurity or resolve every family conflict.
6. Vary the rhythm. Edda is concrete and dry, Farid elaborates then occasionally speaks
   very plainly, and Kaede is precise with an unexpectedly playful interest.
7. Keep all political facts needed for main quests in those quests. A private story must
   not reveal a hidden “correct answer” required to negotiate a better pact later.
8. Express affection through remembered details and ease of company. Reserve explicit
   flirting for an established mutual romantic route.

## 3. Structure, availability, and pacing

Plan **six scenes for each of the three candidates: 18 scenes total**. First release all
six for Edda. Farid and Kaede remain authored plans until their introduction and core
relationship routes are ready; do not present their unfinished routes as playable romances.

Each scene targets 250–400 words on the selected path, about 2–3 minutes at an unhurried
pace. Each has one or two response points with two or three options, which rejoin after
a short reply. Full authored word counts can be higher because of variants. Never require
reading speed checks, a real-time delay, or selecting every answer to complete a scene.

Use scene titles rather than C/B/A or support ranks. Those labels already mean battlefield
bonds in Bannerfall.

| Slot | Availability | Purpose |
|---|---|---|
| 01 | Introduction completed | A small habit and an easy first conversation |
| 02 | Introduction completed | A pleasure, hobby, or family custom |
| 03 | Either 01 or 02 completed | A first personal disclosure |
| 04 | 03 completed | A different side of the same person, often lighter |
| 05 | 04 completed | Reconsider an earlier habit using a specific past event |
| 06 | 05 completed and core route reaches commitment/marriage or its friendship ending | An intimate or companionable coda that recalls an earlier detail |

These dependencies only order optional scenes. No main quest may depend on a personal
scene being read. Unlocks use introductions, prior scene completion, and relationship
status, not a new trust threshold that requires farming the feature itself.

There are no expiring invitations or required daily visits. Show one suggested new topic
at a time, with a list of other available topics. Players may read several in one visit
if they want. The game clock stays paused, and there is no activity-point cost.

**Choices in all 18 scenes follow the same trust rule.** The sample choices below change
the immediate reply and occasional cosmetic callbacks; none is the high-score answer.
Every scene also provides “Another time,” which closes without completing or penalizing it.

## 4. Edda: a person who always finds a job to do

### Voice and backstory direction

Edda, 28, is the Vardish steward already associated with the Ravensford household. Her
public concern for villagers remains. Add an untidy private life underneath her capable
public manner: she remembers kitchen arguments, keeps poor attempts at songs, and finds
it easier to offer hospitality than to accept it.

Her humor is practical and lightly exasperated. She notices a leaking jug before the
embroidery on a guest's coat. She occasionally organizes things nobody asked her to
organize, then becomes embarrassed when she is caught. Her worry is that if she is not
useful she will be an inconvenience. Her counterweight is pleasure in noisy, ordinary
company. Childhood relatives in these scenes can still be alive; loss is not required
to make the memories matter.

New facts below are proposed additions to her backstory. Resolve references to the
current household from saved data; do not hardcode a surname or assume Ravensford is
still her residence.

### E01 — The Spare Spoon

**ID:** `edda_spare_spoon`. **Mood:** light. **Place:** a kitchen or shared sitting room.

**Beats:** Edda is looking for a spoon while counting everyone else's places. As a child,
she set an extra place at crowded household meals because a neighbor almost always arrived
late. She still does it, even when she insists the guest list is final. Let the player notice
that she has not yet set a place for herself.

**Responses:** “Who usually arrived late?” invites a comic family memory; “You missed your
own place” brings a sheepish correction; “I can sit wherever is free” prompts practical
hospitality. Each receives the same completion treatment.

**Sample exchange:**

> **Edda:** Seven spoons. Six guests. That ought to be enough.
>
> **Player:** Have you counted yourself?
>
> **Edda:** ...It is too early in the evening for you to be this observant.
>
> **Player:** I'll put another one out.
>
> **Edda:** Thank you. The drawer sticks; lift it a little.

**Callback:** a later greeting can mention that the player knows which drawer sticks.
No item is granted, food consumed, or household capacity changed.

### E02 — The Wrong Last Verse

**ID:** `edda_wrong_verse`. **Mood:** playful. **Place:** a window seat or courtyard.

**Beats:** Edda remembers two incompatible endings to a childhood song. Her aunt insisted
on one; her cousin loudly preferred another. Edda had spent years writing down whichever
version sounded most respectable and now admits the rude version was funnier. The story
reveals affection for her family without making every relative a political obstacle.

**Responses:** ask for the ridiculous ending, ask who invented it, or admit to forgetting
lyrics too. There is no lyric-matching test. This is separate from the existing main-quest
verse choice and does not complete that chapter.

**Sample exchange:**

> **Edda:** In my aunt's version, the miller learns patience.
>
> **Player:** And in your cousin's?
>
> **Edda:** He falls into his own flour bin. I preferred that one.
>
> **Player:** Did you tell your aunt?
>
> **Edda:** I was a sensible child. I sang it outside.

**Callback:** future dialogue can refer to the miller without playing or copying a real
song. Edda does not become a trained singer as a result of the scene.

### E03 — Boots by the Door

**ID:** `edda_boots_by_door`. **Mood:** reflective. **Place:** a sheltered doorway.

**Beats:** Rain reminds Edda of waiting for an older relative to return from village visits.
She once thought the visits were grand household business. Later she discovered that much
of the work was listening to small problems and remembering whose roof still leaked.
She keeps the habit, but remembers being disappointed when the visits made that relative
late for her own childhood celebrations. Both memories are allowed to be true.

**Responses:** ask what she remembers of those evenings, say that waiting sounds lonely,
or ask whether they eventually talked about it. Edda can say that some conversations were
awkward and unfinished; the player does not assign a verdict to her family.

**Sample exchange:**

> **Edda:** I used to line up the muddy boots by size. It made the waiting less dull.
>
> **Player:** Did they know you were waiting?
>
> **Edda:** Yes. I think knowing was the difficult part.
>
> **Player:** For both of you?
>
> **Edda:** For both of us.

**Callback:** she may later acknowledge that she has kept the player waiting, without
starting a deadline, apology quest, or relationship penalty.

### E04 — A Morning Unclaimed

**ID:** `edda_morning_unclaimed`. **Mood:** warm, gently comic. **Place:** a quiet bench.

**Beats:** Asked what she would do with a free morning, Edda first lists useful errands.
Given time, she remembers liking a local game of skipping flat stones and being fiercely
competitive with a younger cousin. She describes an embarrassingly elaborate method for
choosing stones. This makes room for an ambition small enough to be enjoyed today.

**Responses:** ask about her technique, name an ordinary pleasure for the player, or tease
her about turning leisure into a competition. Keep the game imaginary or within the scene;
do not add a minigame, movement order, appointment, or ability reward.

**Sample exchange:**

> **Player:** A morning with nothing that needs doing. What would you choose?
>
> **Edda:** I would mend—oh. You mean it.
>
> **Player:** I do.
>
> **Edda:** The river, perhaps. There is a trick to finding a good stone.
>
> **Player:** I suspect I'm about to hear it.

**Callback:** a selected player pastime may appear in one later line. Store only this
cosmetic preference, not a new character stat or scheduled activity.

### E05 — The Blot in the Ledger

**ID:** `edda_ledger_blot`. **Mood:** candid. **Place:** a desk after work.

**Beats:** Edda kept a page from her first year as a clerk. It contains an error that caused
a family to be asked for the same levy twice. The mistake was corrected, and nobody died;
she remembers having to explain herself at their kitchen table. Her supervisor kept the
correction visible instead of replacing the page. She still struggles to distinguish
carefulness from pretending she can prevent every mistake.

**Responses:** ask what the family said, ask why she kept the page, or offer a brief example
of owning an ordinary mistake. Avoid absolving her with “You did nothing wrong,” or turning
the player into the person who finally teaches her all self-worth.

**Sample exchange:**

> **Edda:** I wanted to copy the whole page out again.
>
> **Player:** So nobody would see it?
>
> **Edda:** So I wouldn't have to. The family had already forgiven me.
>
> **Player:** You kept the page anyway.
>
> **Edda:** Eventually I found a different reason to keep it.

**Callback:** she lets a small harmless imperfection stand in a later personal scene.
The historical levy is not a new world debt, refund, or current political clue.

### E06 — A Place With No Task

**ID:** `edda_place_no_task`. **Mood:** affectionate coda. **Place:** any safe shared room.

**Beats:** Edda has set out two places and, this time, included herself. She initially
asks whether the player needs anything, then catches herself and sits down. Recall one
earlier detail only if its scene was seen. She has begun to enjoy someone's presence
without needing to organize it into a service.

**Responses:** mention a small detail from the visit, ask about her day, or sit comfortably
without a question. In the romantic version the player can offer a hand; in the friendship
version they settle into a familiar shared routine. Neither initiates a new relationship.

**Sample exchange, romantic variant:**

> **Edda:** I have no letters for you. No requests, either.
>
> **Player:** Then I picked a good evening.
>
> **Edda:** I was hoping you might think so.
>
> **Player:** Will you sit with me?
>
> **Edda:** Yes. I already put my spoon out.

**End state:** a personal recollection and optional greeting variation. No permanent morale
buff, promise flag, household project, or automatic proposal.

## 5. Farid: someone who can answer for everyone except himself

### Voice and backstory direction

Farid, 31, is the Kharzani envoy of Qasr Hamra. Keep his diplomatic competence and concern
for contact across borders. His private difficulty is speaking without first anticipating
how everyone will hear him. He enjoys conversation, notices absurd social rituals, and
sometimes uses a polished anecdote to avoid a personal question.

His vulnerability need not be secret cruelty, serial infidelity, or a catastrophic family
revelation. He grew up rewarded for saying the useful thing and finds honest preferences
surprisingly exposing. He cares about living relatives who ask ordinary questions. Give
him moments where his own joke fails and he can laugh about it.

### F01 — Three Ways to Ask for Supper

**ID:** `farid_supper_request`. **Mood:** comic. **Place:** a guest room or dining alcove.

**Beats:** Farid has written a simple request to the kitchens in language fit for a treaty.
He knows it is ridiculous. As a young page he once delivered an overly blunt message and
was coached so thoroughly that he still edits even harmless notes. The player helps him
choose a plain sentence; the note is a prop, not a food purchase.

**Responses:** ask him to read the grandest draft, suggest a very short request, or confess
to overthinking a small task. All lead to a shared laugh rather than a persuasion check.

**Sample exchange:**

> **Farid:** “If the household's present circumstances permit—”
>
> **Player:** You're asking for soup.
>
> **Farid:** Yes. I had hoped not to sound demanding.
>
> **Player:** “Is there any soup?”
>
> **Farid:** Distressingly effective.

**Callback:** one greeting can use a deliberately short sentence when Farid is at ease.

### F02 — The Street With Two Names

**ID:** `farid_two_street_names`. **Mood:** curious and fond. **Place:** near a window.

**Beats:** Farid describes a childhood street known by one name in official letters and
another by everyone who lived there. The informal name came from a stubborn shop sign,
not a major historical event. He remembers family arguments about which name a visitor
should use. His love of correspondence began with wanting distant people to find each
other, rather than with an abstract love of treaties.

**Responses:** ask about the shopkeeper, mention a nickname for a place the player knows,
or ask which name Farid uses at home. He has no universal rule to teach the player.

**Sample exchange:**

> **Farid:** The address said South Market Street. My mother called it Crooked Lantern.
>
> **Player:** Was the lantern crooked?
>
> **Farid:** The shopkeeper said the entire street was leaning.
>
> **Player:** Did anyone agree?
>
> **Farid:** Only his customers. He was generous with them.

**Callback:** the street remains a remembered childhood location. It is not a new map node,
trade route, secret passage, or travel discount.

### F03 — The Letter Without a Seal

**ID:** `farid_unsealed_letter`. **Mood:** personal. **Place:** a writing table.

**Beats:** A relative has asked whether Farid is happy. He has drafted an answer about
work, the weather, and safe roads. He admits that answering the actual question would
mean choosing words he cannot retract as a diplomatic misunderstanding. The player can
listen, share a limited personal answer, or leave the letter private. Farid writes the
first honest sentence himself; the player does not dictate the letter.

**Responses:** “What did you want to say first?”, “You don't have to read it to me,” or
“I find that question difficult too.” Respecting privacy still completes the scene.

**Sample exchange:**

> **Farid:** She asked one question. I've written two pages around it.
>
> **Player:** Would you like me to leave you to it?
>
> **Farid:** No. Though I may stop trying to make this sound impressive.
>
> **Player:** That's all right.
>
> **Farid:** Good. The first sentence is rather small.

**Callback:** later he mentions having sent the letter. No player mail quest or family
standing change is created, and the private contents are not added to a public log.

### F04 — The Wrong Courtesy

**ID:** `farid_wrong_courtesy`. **Mood:** embarrassment turning to humor. **Place:** a terrace.

**Beats:** Farid recounts an early visit when he arrived with an elaborate ceremonial gift
for a host who had asked for an informal meal. He spent the evening explaining himself
instead of speaking to anyone. The host eventually asked him to help wash dishes, which
was the first relaxed conversation they had. He still enjoys ceremony; he is learning
when other people do not need it.

**Responses:** ask about the impractical gift, ask what they talked about afterward, or
say that the host found a kind way through the awkwardness. Let Farid laugh at himself
without depicting his culture or its etiquette as inherently ridiculous.

**Sample exchange:**

> **Farid:** It took two servants to bring the box inside.
>
> **Player:** What was in it?
>
> **Farid:** An ornamental bowl. They already owned several useful ones.
>
> **Player:** Did you eventually find something to say?
>
> **Farid:** While drying the plates. Neither of us had to admire anything.

**Callback:** a later simple shared task has an easier rhythm. The past gift does not
appear in inventory or grant a gift preference bonus.

### F05 — My Own Answer

**ID:** `farid_own_answer`. **Mood:** quietly candid. **Place:** a bookbinder's bench or room.

**Beats:** Farid knows how to repair the loose binding on a notebook. It was a trade he
briefly wanted to learn, although he also genuinely likes his present work. He has usually
framed every preference as a service to the family and feels awkward admitting that he
likes making something small with his hands. He does not need to quit diplomacy to retain
that part of himself.

**Responses:** ask who taught him, ask what he enjoys about the work, or mention that two
interests can coexist. If the player offers to help, the immediate reply covers holding
the paper steady; there is no crafting action or unlock.

**Sample exchange:**

> **Farid:** The thread needs to be firm. If I pull it much tighter, the paper will tear.
>
> **Player:** You sound certain of that.
>
> **Farid:** I've torn enough paper to be certain.
>
> **Player:** Is that why you like it?
>
> **Farid:** Partly. Mostly I like having a notebook that opens properly.

**Callback:** he later uses the repaired notebook. It remains a story prop with no market
value, trade skill, or inventory effect.

### F06 — No Reply Required

**ID:** `farid_no_reply_required`. **Mood:** relaxed affection. **Place:** a safe sitting room.

**Beats:** Farid has some unimportant news he wants to tell the player. He makes no opening
speech and does not turn the conversation into a request. Recall the letter, soup, or
notebook only if that topic was seen. The change is comfort in being ordinary with someone.

**Responses:** invite the story, share a harmless observation, or suggest sitting together
for a while. Romantic wording can acknowledge that he missed the player; friendship
wording expresses pleasure in familiar company without implying a hidden romance.

**Sample exchange, romantic variant:**

> **Farid:** I saw something today that I wanted to tell you about.
>
> **Player:** What was it?
>
> **Farid:** A dog carrying a very long loaf. I am fairly sure the baker was losing.
>
> **Player:** That's your important news?
>
> **Farid:** Yes. I found myself wishing you were there.

**End state:** a cosmetic memory about being included in his ordinary day. No diplomatic
favor, promise to visit, or extra alliance action.

## 6. Kaede: someone who records everything except her own preferences

### Voice and backstory direction

Kaede, 27, is the Ryumon archivist of Kitayama. Preserve her precision and commitment to
agreements. Privately she draws small, unofficial maps of places she likes and reads
unlikely mystery tales. She is less withdrawn than people assume: given an interesting
subject, she can be animated and unexpectedly opinionated.

Her concern is that expressing a preference will make her less reliable as an observer.
She sometimes corrects a small detail before acknowledging another person's feeling.
Her growth is the ability to state a preference and accept an unfinished personal account,
while continuing to take professional accuracy seriously.

### K01 — A Map of Useless Places

**ID:** `kaede_useless_map`. **Mood:** light curiosity. **Place:** a desk or covered walkway.

**Beats:** The player sees a map without borders, troop routes, or distances. Kaede has
marked the place where afternoon light reaches a wall and a step that stays dry in rain.
As a child she made little plans of places where she could read undisturbed. She still
does it and is mildly embarrassed by how much explanation she thinks it requires.

**Responses:** ask about a tiny symbol, name a pleasant place, or ask whether she draws
these for herself. The player does not obtain usable campaign intelligence.

**Sample exchange:**

> **Player:** What's this mark beside the stairs?
>
> **Kaede:** A cat. Usually.
>
> **Player:** Usually?
>
> **Kaede:** I cannot guarantee the cat's attendance.
>
> **Player:** An admirably cautious map.

**Callback:** the cat can be mentioned later without creating a pet, map marker, scout
bonus, or collectible.

### K02 — A Very Bad Mystery

**ID:** `kaede_bad_mystery`. **Mood:** playful. **Place:** a reading corner.

**Beats:** Kaede complains that a mystery's forged letter is obviously impossible, then
admits she has read the story several times. A favorite childhood reader made every
suspect sound guilty. Kaede enjoys guessing badly aloud even though she is meticulous
about real evidence. Her amusement should be visible in the performance directions.

**Responses:** accuse the least plausible fictional suspect, ask why she keeps reading,
or offer to hear the next page. There is no right-answer reward and no real quest clue.

**Sample exchange:**

> **Kaede:** The seal is on the wrong side of the fold. The entire accusation collapses.
>
> **Player:** Shall we stop reading?
>
> **Kaede:** Certainly not. The gardener has just acquired a second disguise.
>
> **Player:** Is he the culprit?
>
> **Kaede:** I hope so. He has put in the most effort.

**Callback:** she may ask for another deliberately absurd theory during a later greeting.
Do not copy a Fire Emblem fable, plot, or catchphrase.

### K03 — A Name in the Margin

**ID:** `kaede_margin_name`. **Mood:** fond, slightly awkward. **Place:** a desk with keepsakes.

**Beats:** Kaede finds an old label bearing a family nickname she once insisted was too
childish. She had just begun formal training and wanted to sound like the adult scholars.
She remembers correcting the relative who used it and now realizes the nickname had
been affectionate. The relative remains a person with a sense of humor, not simply a
source of regret. Kaede decides whether to explain the nickname's origin.

**Responses:** ask about the relative, say she can keep the nickname private, or share a
brief player anecdote. The player does not earn the right to use a name she has declined
to share. A respectful boundary is a complete, equally rewarding conversation.

**Sample exchange:**

> **Kaede:** I demanded that everyone use my proper name. I was twelve.
>
> **Player:** Did they agree?
>
> **Kaede:** For nearly an hour.
>
> **Player:** May I ask what they called you?
>
> **Kaede:** Another day, perhaps. I am still deciding whether to trust your restraint.

**Callback:** a future line can acknowledge that the player did not press. No hidden
nickname password or permanent relationship advantage is attached.

### K04 — The Missing Street

**ID:** `kaede_missing_street`. **Mood:** amused frustration. **Place:** a table with her map.

**Beats:** Kaede has tried to finish a private map, but every visit changes some small
feature. A bench moves, a stall closes, the cat chooses a different step. She remembers
her first map of home, which included a shortcut that existed only when a neighbor left
a gate open. She can enjoy the map as a record of one afternoon without making it final.

**Responses:** ask about the old shortcut, suggest dating the sketch, or say that the
changed place might deserve another drawing. Each is a legitimate perspective.

**Sample exchange:**

> **Kaede:** The bench has moved again.
>
> **Player:** Perhaps it prefers the shade.
>
> **Kaede:** So do I. That is the troublesome part; I approve of the change.
>
> **Player:** Will you redraw it?
>
> **Kaede:** Perhaps tomorrow. This is where it stood today.

**Callback:** a dated unfinished sketch can remain on her desk. No settlement geometry,
travel calculation, or calendar value changes.

### K05 — The Page She Kept

**ID:** `kaede_kept_page`. **Mood:** thoughtful. **Place:** a quiet archive corner.

**Beats:** During an early apprenticeship, Kaede summarized a family gathering so formally
that she omitted the apology everyone had come to hear. Her teacher asked who the account
was for. Kaede has kept both versions: the official summary and the personal note that
includes what she felt. She still believes evidence matters; she is learning when her
own experience belongs in a different kind of record.

**Responses:** ask about the teacher, ask what she wrote in the second version, or observe
that an account can have a purpose without containing everything. She may keep some lines
private; no response grants access to confidential political records.

**Sample exchange:**

> **Kaede:** The first account said they met, ate, and departed.
>
> **Player:** And the second?
>
> **Kaede:** That I was glad they stayed until evening.
>
> **Player:** That sounds worth keeping.
>
> **Kaede:** It took me a while to put my name beneath it.

**Callback:** she later states an opinion in the first person. This page does not settle
the feud or document dispute in her main political story.

### K06 — Room on the Map

**ID:** `kaede_room_on_map`. **Mood:** gentle affection. **Place:** a safe shared room.

**Beats:** Kaede invites the player to add one ordinary place to a new personal map. The
map represents things they notice, not territory they own. In a romantic relationship
she admits she likes knowing where the player would choose to sit. In friendship she
is curious how someone else sees the same place. She leaves room for future changes.

**Responses:** choose a sunny spot, a quiet corner, or a place to watch people go by. These
are cosmetic preferences only. Include a line for anyone who prefers not to choose yet.

**Sample exchange, romantic variant:**

> **Kaede:** Where would you put your chair?
>
> **Player:** Beside yours, if it won't spoil the drawing.
>
> **Kaede:** It will require a very small revision.
>
> **Player:** Can you tolerate that?
>
> **Kaede:** I think I should like it.

**End state:** a shared personal image and a greeting variant. No home assignment, property
claim, travel destination, engagement, or gameplay map update.

## 7. Responses, romantic variants, and memories

### Give choices an expressive purpose

The normal choice set is a question, an observation, and a restrained response such as
letting a subject rest. Write a distinct reply to each. A character may prefer one topic
in the moment without the game assigning a superior numerical outcome.

Do not offer insults or dramatic betrayals as harmless flavor options. If the player
wants to end the relationship or make a binding promise, return to the existing main
relationship actions with their explicit consequences. Gentle disagreement within a
personal conversation is safe; a major political decision belongs in the main quest.

A choice can set a cosmetic callback, such as the player preferring a quiet corner. These
callbacks may select a later line or greeting. They must never alter an AI decision,
unlock a pact, add a cost, or supply a hidden requirement for romance progression.

### Variants and continuity

- Scenes 01–05 use neutral friendship wording by default. Add a few optional affectionate
  lines only when mutual romantic intent already exists and the relationship permits them.
- Scene 06 has a full romantic coda and an equally complete friendship version. Reading
  either never changes the relationship's status. A friendship ending is not presented as
  a failed romantic ending.
- A callback checks whether its source scene was completed. If E01 was skipped, E06
  introduces the shared table naturally instead of assuming the player remembers a spoon.
  Apply the same rule to Farid's letter and Kaede's map.
- Use the character's current safe residence for the staging. A displaced Edda can remember
  her old kitchen without claiming the current room is at Ravensford.
- During an unresolved main-story breach, pause new intimate scenes with a clear reason.
  Previously completed scenes remain replayable. Optional conversation cannot repair the
  breach or behave as if it never happened.
- After separation, preserve memories. New neutral scenes follow ordinary contact access;
  romantic variants remain unavailable. A later reconciliation does not replenish rewards.
- When Romance invitations is off, do not suggest flirtation. Neutral personal topics
  remain available; turning the setting off does not erase an existing spouse or history.

### Cosmetic memories

Write one plain recollection for each completed scene, for example:

- “Edda told you why she sets an extra place at the table.”
- “Farid shared a letter he found difficult to begin.”
- “Kaede showed you a map of places she likes.”

Keep sensitive details in the private scene transcript rather than repeating them in a
public-sounding contact summary. A refusal to share a detail can still produce an accurate
memory: “You spent a quiet evening with Kaede.” Do not claim a secret was disclosed if
the chosen branch respected its privacy.

After the core scenes work, add three short greeting variants per character, derived from
completed scenes. They are incidental lines, never another set of trust rewards.

## 8. Trust rule: exact behavior

| Action/context | Trust result | Other result |
|---|---|---|
| Complete a new eligible scene with fewer than three bonus claims | +1, clamped at 100 | Save completion, cosmetic choices, and one claimed bonus slot |
| Complete a fourth or later unique scene | 0 | Save the new memory and cosmetic choices |
| Replay a scene or select an alternative response in replay | 0 | View another line; do not rewrite the campaign's remembered choice |
| Close midway or choose “Another time” | 0 | Preserve an optional resume position; no penalty |
| Use an authored “Read summary” completion | Same as normal completion | Record the neutral response path; no reading-speed or comprehension test |
| Complete while already at 100 trust | 0 actual increase | Consume the eligible bonus slot so points cannot be banked for a later breach |
| Read previously completed scenes during a strained relationship | 0 | Archive access only; no repair or new completion reward |
| Skip every optional scene | 0 | Main romance remains fully completable on its existing ordinary route |

The first three **unique** completions claim the three slots, regardless of scene choice.
No scene has a special +2 reward for vulnerability or flirtation. Closing an incomplete
scene is not a completion, and a double click on its ending is not a second completion.

Store this policy as tunables in `scripts/data/relationships.gd`, initially
`PERSONAL_CONVERSATION_TRUST = 1` and `PERSONAL_CONVERSATION_CAP = 3`. These are proposed
constants, not values already in the game. If playtesting favors pure backstory, set the
reward to zero before release without rewriting dialogue or adding a player-facing
scoring-mode switch. Changing the number in a later patch must not retroactively regrant
or subtract previously earned trust.

Show one brief completion note when points actually change: “Time together: +1 trust.”
Explain the cap in contact Details. Do not display point previews on individual answers
or turn every new scene into a reward notification. Main quest rewards keep their existing
separate descriptions and amounts.

## 9. Menus and interaction flow

Add **“Spend time together”** beside the current main-story audience action. Its topic
list shows available titles, a short topic description, approximate reading length, and
an optional New marker. Reading is voluntary and never starts automatically on arrival.

```text
Edda

[Continue your shared story]
[Spend time together]

Personal conversations
  The Spare Spoon          New · about 2 minutes
  The Wrong Last Verse     New · about 2 minutes
  Remembered conversations

[Back]
```

Use a dedicated personal-conversation mode or scene, with an explicit exit back to the
same contact/topic list. Never route a personal response through a main chapter's choice
ID. The player should always know whether they are making a quest decision or chatting.

New conversations require the actual contact to be available at the same accessible
settlement. Revalidate this in state logic, not just by disabling a button. Replays are
available anywhere as memories, clearly marked as such. The existing People screen has
an audience action even away from a resident; do not inherit that as permission for a
new in-person scene or use a remote replay to claim trust.

Keep the map paused, hide the main quest choices while chatting, and restore the correct
return route on Back/Escape. Reuse `MenuPage` and `Style.TOUCH`; wrap long text, keep
choices reachable by keyboard, and check phone-sized layouts. The default focused action
should not accidentally confirm a reply or a completion.

Each scene needs an authored 40–60-word summary. Offer “Read summary” and “Another time”
without moralizing about skipping dialogue. Archive replays use the first-play relationship
context, so an old romantic conversation is identified as a memory after a separation.

## 10. Implementation plan against the current code

The existing system already supplies candidates, relationship trust, `SocialSim` persistence,
`GameState.apply_social_choice()`, People & Letters, and a main-story conversation screen.
These optional scenes need a separate set of content and completion IDs so they cannot
accidentally consume the main quest's rewards or advance its chapter.

### Proposed content data

Add `scripts/data/personal_conversations.gd` with records containing:

```text
scene_id, candidate_id, content_version, title, short_description
prerequisites: introduction, optional_scene_ids, permitted_relationship_statuses
nodes: speaker, text_key, expression, choices, next_node
variants: friendship, romantic, relocated, missing_callback
cosmetic_choice_keys, summary_text, completion_memory_variants
```

Use existing candidate/person IDs. Author text as original keyed strings, without a
runtime generative-dialogue dependency. Response nodes may select text, move to another
personal node, and record a cosmetic choice. They cannot specify arbitrary silver,
standing, status, or quest effects. The shared completion rule is the only trust entry point.

### Saved state

Add an optional `personal_conversations` object to `SocialSim`, keyed by persistent person ID:

```text
schema_version
completed: scene_id -> content_version and remembered relationship context
cosmetic_choices: scene_id -> selected expressive choices
bonus_claims: scene_id -> actual trust delta granted, including zero at the trust cap
in_progress: scene_id -> current node, selected choice, content_version, relationship/callback context
```

Derive used slots from the unique `bonus_claims` keys; do not maintain a second independent
counter. Keep these claims even if a scene is rewritten, removed, or archived. Completed
scenes without a bonus claim after the cap are still permanently ineligible on replay.

Current saves are version 6. Default missing personal state to empty without treating main
chapter 2 as a completed optional scene or granting retrospective trust. Use the project's
normal save-version policy when this ships; do not assume version 7 remains available.
New campaigns reset the records. Marriage, relocation, separation, and save migration do not.

### Proposed command flow

1. `SocialSim.available_personal_conversations(person_id, context)` lists eligible topics
   from actual introduction, location, availability, and seen-scene state.
2. `GameState.personal_conversation_action(person_id, scene_id, "begin")` validates a first
   play; archive replay stays in the reader. Neither advances world time.
3. A personal reader validates choices against the current scene/node and records only
   cosmetic progress. Do not call `apply_social_choice()` for these responses.
4. `GameState.complete_personal_conversation(...)` revalidates eligibility and first-play
   status, applies at most one capped trust point, and stores completion/claim/memory together.
5. Save once for that completion. Reopening the reader, duplicate input, or a loaded ending
   cannot apply it again. Save failures remain visible and do not allow a second reward.

Use deterministic text/choice rules and no draws from the world RNG. If a content update
makes a saved in-progress node unavailable, restart the unread scene safely; preserve all
completion and bonus ledgers. Scene IDs remain stable across editorial changes.

### Files and milestones

| Step | Work | Completion evidence |
|---|---|---|
| P1: reader and scoring policy | New personal data file; `SocialSim` records; completion command in `game_state.gd`; tunables in `relationships.gd`; one Edda scene | A first read gives at most +1; replay, remote access, and duplicate submission cannot award it |
| P2: Edda's six scenes | Dedicated `scripts/menu/personal_conversation.gd` and thin scene wrapper; entry from `people.gd`/`conversation.gd`; return context in `scenes.gd`; summaries and variants | Reading/skipping never advances or blocks a main chapter; the coda respects its existing-commitment gate; total additional trust is at most +3 |
| P3: content and campaign QA | `tests/personal_conversation_tests.gd` plus relevant menu/save checks; editorial review of all branches | No world/economy mutation; baseline romance still completes with zero scenes; phone layouts and save/resume pass |
| P4: Farid and Kaede | Implement their planned scenes after each has a valid introduction/core route; add neutral and romantic codas | Both have distinct voices and complete context checks; neither relies on Edda's chapter IDs |

The first testable slice is E01 plus a replay and the capped-completion path. The first
content-complete release is Edda's six scenes. Keep unpublished Farid/Kaede content hidden
until their surrounding relationships can support it.

## 11. Acceptance tests and editorial review

### Mechanical checks

- Three distinct first completions add exactly three trust when below the cap. All remaining
  scenes, summaries of completed scenes, and replays add zero. Response choice never changes
  the award. At 100 trust, the claim is consumed without raising trust above 100.
- Save/reload at a choice, summary, final line, and completed screen. Two completion requests
  with the same scene ID have one effect. Editing a text version cannot reset its entitlement.
- Before/after campaign snapshots differ only in allowed personal records, cosmetic memories,
  and the bounded trust change. Silver, food, renown, time, RNG, armies, bonds, house standing,
  pacts, grant cooldowns, main chapter, and main reward keys remain unchanged.
- The current ordinary Edda route reaches 65 trust with no optional scenes and at most 68
  with them. Marriage still checks the main route, intent, standing, and unresolved breach.
- Use a low-trust and a strained fixture to prove chat cannot skip a main chapter or clear
  a breach. A numerical threshold reached through +3 is insufficient without other gates.
- Friendship earns the same optional trust as romance. Another active romance never makes
  a friendly scene silently flirt or set intent. Separation never resets the cap.
- Migration from version 6 preserves existing romance records and starts with no completed
  optional scenes. Missing content/node recovery cannot grant retrospective rewards.
- Validate same-location/availability on first play. Relocation changes staging; archived
  remote playback cannot become a first-play completion or claim a reward.
- Every route can close and resume. A declined private detail is a valid completion and
  produces an accurate memory. Back/Cancel midway creates no reward or negative effect.

### Content and HCI checks

- Read sample lines without speaker names: the three characters should sound distinguishable.
  Check that Edda does more than administer, Farid does more than charm, and Kaede does more
  than correct facts.
- Every scene reveals a specific memory, preference, or habit. At least three of each
  character's six scenes should contain ordinary pleasure or humor, rather than a confession.
- Verify every choice has an authored response; no option is marked correct or silently
  changes political rewards. Respectful curiosity and respectful restraint both work.
- Inspect romantic, friendship, relocated, missing-callback, strained, and archive contexts.
  Never assume a scene was read just because it was available.
- Render the longest text/choice combinations at 405×720 and 360×640, with safe areas and
  keyboard navigation. Ensure the personal reader cannot expose an active main-quest button.
- Have playtesters try one run with zero scenes and one with all six. Ask what they remember
  about the character before asking about the trust number. If players mainly remember which
  scenes grant points, test the zero-bonus fallback while keeping the writing intact.

Success means the player can describe a partner's ordinary life and recognize their voice.
The proposed +3 is a small acknowledgment of attention; the conversations must remain worth
reading after that cap has been reached.
