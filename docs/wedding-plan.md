# The wedding: plan

## What happens today

There is no wedding event. In chapter 5 of a romance:

- **"Marry me, before your house and everyone."**
  - 100 silver and 100 rations are taken at once.
  - The status becomes Engaged, and `schedule_ceremony` starts at her residence that same hour.
  - Six game hours later `SocialSim._conclude_ceremony` flips the status to Married, wherever you are: on the road, in a battle, or a captive.
  - It adds the memory "Wedded in solemn ceremony at …" and forms the marriage pact.
  - No notice, scene or guests. The Engaged greetings are almost never seen.
- **"Let's make our vows quietly, just us."** You are married at once, with one line in the talk.
- **The journal** lists "Wedding at …" with the hours left, and that is all.
- **The memory book row** for the ceremony only shows the place on the map.
- **Bug:** the marriage pact protects `[her residence, "thornwall"]`. Thornwall is hard-coded, whatever you actually hold.
- **Never built:** the old plan (romance-and-allies-plan.md §6 "Ceremony") promised a choice of court, costs that are set aside and refunded, and postponement on siege or capture.

## The idea

The wedding becomes a short event you ride to. You pick the place. You see who is coming. You arrive and stand beside her, say vows, hear the rite and the toasts, and keep the day in the memory book.

It reuses the romance talk view (`TalkView`), with the same faces, bubbles, replies and pixel style. The private path stays quick and happens right in her room.

## The screens

### 1. She says yes, then: where?

This is the romance talk, chapter 5.

Choosing the public wedding no longer starts a timer. Her answer is followed by a gold note, "Where will you marry?", and a muted line: "100 silver and 100 rations are set aside now, and returned if it's called off."

The replies:

| Reply | Tag | When |
|---|---|---|
| "Here in <her seat>, with your house." | Her house's seat · distance · ready tomorrow at dusk | Her seat is not hostile to you and not besieged |
| "At <your seat>, under my own banner." | Your seat · N days' ride · you host · your lords come | You hold a town or castle (your fief or crown seat) |
| "Somewhere else we both know." | Pick a friendly town on the map | Always. It opens the map in pick mode, and only friendly or neutral towns and castles you have visited can be chosen |
| "Let's decide later." | Stay engaged · no hurry | Always. The commitment stays as "Choose a place" |

### 2. The days before

The wedding is a commitment with a map pin:

- **Pin card:** "Your wedding at Ravensford". It shows when it is ready, the chips "100 silver · 100 rations set aside", "N guests coming" and the distance, and the buttons **Who's coming** and **Ride there**.
- **Marker:** a gold ring around the place, with a ribbon reading "Wedding · tomorrow at dusk" or "Wedding · ready".
- **Letter:** she writes once when the place is ready, using the existing letter banner and reader.
- **No deadline:** nothing expires, and being late costs nothing.

**Postponed:** if the place is besieged, burned, changes hands to a realm at war with you, or you are captive, the wedding is postponed. She writes: "Ravensford's under siege. The flowers will keep." The letter's replies are the place choices from screen 1, or "Wait".

**Call it off:** the pin card has a quiet button. It refunds the set-aside costs, sets the status back to Committed, and adds a short line from her. There is no trust loss, and the chapter 5 choice opens again.

### 3. Arriving: who came

Entering the place while the wedding is ready opens a sheet: "Your wedding is ready · Begin / Not yet". It is also on the Court tab as "Edda · Wedding day · Begin".

Begin opens the wedding scene:

- **Backdrop:** the place's painted art (Ravensford, Qasr Hamra, Kitayama), or its `SettlementVista` elsewhere. It is shown at the real hour, with dusk preferred.
- **Dressing:** drawn in code over the backdrop:
  - pixel bunting in both houses' colours;
  - the two banners planted left and right (theirs, and yours or your crown's);
  - lantern glows at dusk and night;
  - a few petals at the sides.
- **Face:** hers, in the warm expression.
- **Nameplate:** "EDDA · Wedding day · 6 guests".
- **Log:**
  - one arrival narration for the place type and hour;
  - a **Who came** card: a row of small faces with name and role, the host marked in brass, and Regard shown on lords;
  - a line naming who stayed away and why ("Torvald stayed away: your realms are at war.");
  - the liege's gift if they didn't come;
  - her line asking you to stand beside her.
- **Replies:** "Take your place beside Edda" (gold), and "Not yet" (quiet; it waits while you're in town).

### 4. Vows

The host reads the old words as narration. Then she says her vow:

- **Her vow** comes from your story. The game takes the most recent visit memory that has a vow line (one per visit scene, 18 in all). Without one it uses a chapter-3 variant line, then a per-candidate default.
- **Memory chip:** the bubble carries a chip such as "She remembers: the spare spoon · Day 3".
- **Your vow:** "Your vow. No wrong answers." Three plain replies per candidate, tagged "a promise", "honest" and "make her laugh". No numbers. The one you pick is kept.

### 5. The rite and the toasts

**The rite.** It follows her culture, as two or three narration lines:

| Culture | Rite |
|---|---|
| Vardish | The cord: a red cord wound once around both wrists over the hall's hearth-fire, carried outside |
| Kharzani | Salt and bread: shared before witnesses from both houses, and the marriage contract read aloud (Farah wrote it) |
| Ryumon | Three cups: three small cups, three sips each, and your names written into the archive's register (Kaede writes yours herself) |

**The toasts.** Each is a bubble with a small face beside the name:

- **Your longest-serving living captain** (most battles) gives a templated toast with their name, picked from six lines by captain id.
- **The host** gives a line by their bearing: Cautious, Daring, Honorable or Cruel, four lines each.

**Raise your cup** (gold note), then plain replies:

- "To <her>."
- "To the company, who got me here."
- "To absent friends: <names>." This appears only when captains have fallen in your service, and names up to two of them from the fallen-captain record.

### 6. Married

One closing card, shaped like the battle results:

- **Vignette:** dressed backdrop at night, her portrait, both banners.
- **Title:** "Married", with "<her> and you · <place> · day N" below.
- **Kept memory** (rose card): place, your vow, your toast. "Open it again from her page · Relive".
- **The marriage pact, in plain words:** who it binds, which places attacking breaks it (her residence and **your** seat or fief if you hold one, never a hard-coded village), the household grant (up to 150 silver every 14 days) and help refilling troops.
- **Who came:** host +10 Regard, other lord guests +5. Once per wedding, only for those present.
- **Totals:** −100 silver, −100 rations (already set aside), +15 renown.
- **A line on what's next:** "Edda keeps the household at Ravensford and writes when you're away. Visit any time."
- **Button:** Back to the map.

### 7. Private vows

This happens inline in the romance talk, right after the confirmation:

- **Backdrop:** her room at night. The stage switches to `TalkView.room(<her room>, "night")` and the place is captioned "<her>'s room at <seat> · night".
- **Lines:**
  - one narration: "No guests, no banners. A candle, the door shut."
  - her line about her house;
  - the same vow exchange as screen 4.
- **Ending:**
  - a keepsake;
  - a red note: "<House> wasn't asked: −10 standing · no marriage pact yet. Their good word can still be earned."
- **Not here:** no guests, no rite, no cost, no travel.

### 8. Afterwards

- **People profile:** the chip reads "Married · since day N".
- **Memory book:** the wedding is the first row, with a ring icon and **Relive**. Relive replays the scene read-only with your own vow and toast, as visit replays do now.
- **Pact:** it gets its own line ("House Fairholt · protects Ravensford and Highcliff · grant ready").
- **Map news:** a new activity, `wedding`: "Edda of Ravensford and the captain wed at Ravensford".
- **Unchanged:** married greetings and later talks stay as they are today.

## Rules

- **Places:**
  - Public weddings happen at a town or castle that is friendly or neutral to you, not besieged and not burned. Villages are allowed only for private vows.
  - Her seat and your seat come first; anything else is picked on the map.
- **Preparation:** ready at the first dusk at least 24 hours after the place is chosen.
- **Ready and waiting:** a ready wedding never completes by itself. It waits until you are at the place and choose Begin.
- **Costs:**
  - Taken when the place is chosen and stored as `reserved_silver` and `reserved_food`.
  - Refunded in full if it is called off.
  - Nothing more is taken at the wedding.
  - If you can't afford it, the public reply is locked with the reason, as today.
- **Guests:** worked out when the place is chosen and refreshed at Begin.
  - **Host:** her house head, unless their realm is at war with you.
  - **Lords:** up to 3 who have met you, have Regard ≥ 20, aren't at war with you or the host, and aren't captive.
  - **Crown lords:** if you are crowned, up to 3 sworn crown lords.
  - **Captains:** all living captains in your warband.
  - **The host realm's ruler:** comes if they are already a guest; otherwise they send a gift line if their Regard is ≥ 0.
  - **Who stayed away:** at most one hostile lord is named.
- **Regard:** +10 for the host and +5 for each other lord who came, once.
- **Renown:** +15 for a public wedding; nothing for private vows, as today.
- **No new battle or economy effects:** captains' cheers are narrative only.
- **Autoplay and tests:** autoplay chooses her seat, begins on arrival, and takes the first reply at every beat.

## Data

The single `scheduled_ceremony` becomes a `wedding` dictionary on `SocialSim`.

**`wedding`:**

```text
{state: "planning" | "preparing" | "ready" | "postponed" | "done" | "cancelled",
 candidate_id, person_id, place, chosen_hour, ready_hour,
 reserved_silver, reserved_food, guests: [{kind: "host" | "lord" | "crown_lord" | "captain", id}],
 absent: [{id, reason}], gift_from: lord id or -1, postponed_reason,
 vow, their_vow, toast, rite, day}
```

**Memory:** the finished wedding adds a memory of kind `ceremony` with `{place, vow, their_vow, toast, guests, scene_id: "wedding"}`, so Relive can replay it.

**Old saves:**

| Save state | Becomes |
|---|---|
| Active `scheduled_ceremony` | `wedding` with state `ready` at her residence |
| Completed ceremony | Stays as it is |
| Pact with `thornwall` that you don't hold | Rewritten to her residence plus your seat, if any |

## Code

| File | Change |
|---|---|
| `scripts/world/social_sim.gd` | Wedding states and functions: `plan_wedding`, `wedding_ready`, `begin_wedding`, `finish_wedding`, `postpone_wedding`, `cancel_wedding`. Remove the 6-hour auto-complete. Save/load and migration. Fix pact sites. |
| `scripts/game_state.gd` | Set aside and refund costs, `wedding_guests()`, Regard and renown on finish, commitment entry (Ride there / Who's coming / Call it off), news activity. |
| `scripts/data/wedding_lines.gd` (new) | Arrival narration (place type × hour), rites by culture, her vows (by visit scene, chapter-3 variant, default), your vows by candidate, captain toasts, host toasts by bearing, postponement letter. |
| `scripts/menu/wedding.gd` + `scenes/wedding.tscn` (new) | The wedding scene on `TalkView`: arrive, vows, rite and toasts, result card. Also replay mode for Relive. |
| `scripts/ui/wedding_dressing.gd` (new) | Draws pixel bunting, banners, lantern glows and petals over the stage; colours come from both banners. |
| `scripts/menu/romance_talk.gd` | Chapter 5 public: the place picker instead of a timer. Private: the inline vows beat. |
| `scripts/world/map_screen.gd` | Ring marker and ribbon, the "Your wedding is ready" sheet on arrival, pick-a-place mode. |
| `scripts/world/settlement_screen.gd` | Court row "Wedding day · Begin". |
| `scripts/menu/people.gd` | "Married · since day N", the ceremony memory row with Relive, the pact line. |
| `scripts/data/letters.gd` | Letters for "ready" and "postponed". |
| `assets/ui/o_rings.svg` (new) | Ring icon in the existing icon style. |

**Art:** no new art is required. The painted backdrops and portraits are reused and dressed in code. Three dedicated wedding paintings (Vardish hall, Kharzani courtyard, Ryumon terrace) can be added later through the art manifest pipeline.

**Sound:**
- the partner realm's campfire theme for the feast;
- a short bell stinger at the vows from `tools/music.py`.

## Tests

`tests/wedding_tests.gd`:

- **Choosing a place:**
  - Choosing a place sets the costs aside, and Engaged holds.
  - Time passing never completes it while you're away.
- **Ready:**
  - It is ready at the first dusk after 24 hours.
  - Arriving offers Begin.
- **The scene:**
  - Begin opens the scene.
  - Vows and toast are recorded.
  - The status becomes Married.
- **The pact:** it protects her seat and your seat, never an unheld Thornwall.
- **Guests:**
  - A lord at war with you is never a guest.
  - Regard is given once, only to guests.
  - "Absent friends" appears only with fallen captains.
- **Cancel:** refunds exactly. Committed status returns, and chapter 5 can be chosen again.
- **Postponement:** a siege at the place postpones it and sends a letter, and a new place resumes it.
- **Private vows:** married at once, −10 standing, no pact, a memory with the vow.
- **Saves:**
  - save/load in each state;
  - an old save with an active `scheduled_ceremony` loads as ready.
- **Relive:** replays the stored vow and toast.

Update `relationship_tests.gd` and `personal_conversation_tests.gd`, which expect the 6-hour timer.

## Order of work

1. Wedding state, migration, pact fix and tests (no UI).
2. The place picker in chapter 5; the commitment card, map marker and arrival sheet.
3. The wedding scene with dressing: arrival, vows, rite and toasts.
4. Result card, memory, Relive, profile and news.
5. Private vows inline.
6. Postponement and call-off letters.
7. Screenshots, README, full suite.
