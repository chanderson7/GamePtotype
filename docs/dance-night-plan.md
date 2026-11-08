# Dance night: who is on the floor

## What's wrong now

`GameState.dance_partners()` offers three kinds of partner:

- **Romance.** Someone you court (courting, committed, engaged or married), but only if
  she *lives* at the host's seat (`social.residents_at(place)`). Edda, Farah and Kaede each
  live at one seat, so at almost every gathering this list is empty.
- **Lord.** Every lord at the gathering (`gathering_lords(g)`), up to eight, each for
  +3 Regard (+4 if Daring). Every lord is a warlord and head of a household (`he/him` in the
  social sim). So the menu is mostly "Dance with Lord X" eight times over.
- **Wall.** Watch, and hear the gossip.

So the dance is usually a list of warlords to dance with, and the one person you would want
to dance with is missing unless the gathering happens to be in her own town. The Regard
reward for lords is a reasonable mechanic, but it's on the wrong action.

## What the floor should hold

Each option below is a partner who would really be there, and keeps a reason to pick it.

### 1. Someone you court, wherever she attends (romance stays, and gets easier to reach)

She is on the floor if she is **at the gathering**, not only if she lives at the host's seat:

- she lives at the host's seat (today's rule), **or**
- her house's head lord is the host or a guest (`houses[house_id].head_person_id` →
  `lord_id`, checked against `gathering_lords(g)`). She comes with her household.
- Farah only: she is an envoy, so she also attends any gathering of her realm (or of a realm
  at peace with it, if that reads better).
- She isn't there if her status is `displaced` or she's away on her own errand.

Statuses offered: courting, committed, engaged or married (as now), plus **acquainted**.
An acquainted dance gives the memory, and +1 trust within the same `DANCE_TRUST_CAP`, so a
dance can be how a courtship warms up. It does not change her status: the authored chapter
choices still do that.

A woman you've never met is not on your list. Instead the narration names her
("Across the hall, a woman in Ravensford grey is laughing at something the steward said")
and the journal gets a line saying where to find her. A dance never skips her authored
first meeting.

When someone you court isn't there, say so in one muted line under the choices:
"Edda isn't here: she comes when Ravensford's household does." That turns the dance into a
pointer for the romance, not a dead end.

### 2. A lord's kinswoman, for the lord's Regard (replaces "dance with Lord X")

The lords stay at the table: toast, gift and first word already cover them. The political
dance becomes the courtly one: **you ask the host's wife, sister or daughter, and the lord
notices.**

- Offer at most **the host and two guests** (the two whose Regard is closest to a
  threshold that matters: an invitation, a sworn lord's loyalty, a lord you're persuading),
  not all eight.
- Each kinswoman is **generated, named and kept**. She is made the first time her lord's
  household is needed, from the culture's name list. She is stored on the house as
  `kin: {name, relation}`, so "Lady Maren, Lord Caldmoor's sister" is the same woman at the
  next gathering.
- She is **not romanceable.** She has no story, letters or memory book. Her line can show a
  little of her lord's bearing.
- Effect: the same Regard as today (+3, +4 with a Daring lord's kin), credited to her lord.
  The button reads "Dance with Maren, Lord Caldmoor's sister", with a Regard chip naming
  Caldmoor.
- A lord who is a **widower or has no kin left** (a heir who has just succeeded) has no one
  to offer. Leave that to chance at generation, about 1 in 6, so the list varies.
- Lines are written by the kinswoman's relation to her lord and by his bearing, replacing
  `DANCE_LORD_LINES`: a wary Cautious sister, a delighted Daring daughter, a correct
  Honorable wife, a Cruel lord's kin who knows everyone is watching her.

### 3. The round dance, for everyone in the hall (new, small)

Each culture has a group dance: the Vardish reel, the Kharzani lantern circle, the Ryumon
two lines. "Join the round" gives **+1 Regard with every lord present**. It's a sociable
choice for a player who isn't courting and doesn't want to favour one house. If any of
your captains are married or bonded, it can also give one captain line ("Your captains
make fools of themselves and are cheered for it").

### 4. The wall (unchanged)

Keep to the wall with a cup: the gossip, if there's any to hear.

## The menu, in order

1. Each person you court who is here, gold, with a heart icon.
2. The host's kinswoman, then up to two guests' kinswomen, each with a Regard chip.
3. Join the round, with a "+1 Regard with all N lords" chip.
4. Watch from the wall.
5. A muted line for anyone you court who isn't here, and where she'll be.

That is at most about six options, and none of them asks a warlord to dance.

## Where the code changes

- `scripts/data/gatherings.gd`: `KIN_RELATIONS`, `KIN_NONE_CHANCE`, `DANCE_KIN_LINES`
  (by relation × bearing), `DANCE_ROUND` (by culture), `DANCE_ROUND_REGARD := 1`,
  `KIN_OFFERED := 3`. `DANCE_LORD_LINES` goes.
- `scripts/world/social_sim.gd`:
  - `attending(g, lords_here) -> Array` gives the candidates at a gathering, by the rules above.
  - `house_kin(lord_id) -> Dictionary` makes the kinswoman lazily and stores her on the house.
    A save migration adds `kin` to old houses as they're needed.
  - `on_lord_succeeded` clears or moves the kin (the old lord's daughter becomes the new
    lord's sister).
  - `dance_with` accepts acquainted.
- `scripts/game_state.gd`: `dance_partners()` builds the list above (kinds `romance`,
  `kin`, `round`, `wall`, plus `absent` notes). `dance()` handles `kin` (Regard to her lord)
  and `round` (Regard to all). The `lord` kind is removed.
- `scripts/menu/dance.gd`:
  - `kin` replies show her portrait, from the captain-face generator in the kin's culture.
  - `round` replies show the hall line art.
  - The absent notes go under the replies.
- `tests/`:
  - partners never include a lord himself;
  - Edda is offered when Ravensford's lord is a guest elsewhere;
  - an unmet candidate is never offered;
  - the same kinswoman returns at the next gathering;
  - kin Regard goes to the right lord;
  - the round touches every lord once;
  - Regard totals stay where they were for a player who used to dance with one lord a night.

## Open questions

1. **Generated kinswomen.** Is a named, non-romanceable "Lord X's sister" the right
   stand-in, or should the political dance go entirely (lords handled only at the table)
   and the dance be romance + round + wall?
2. **Meeting at a dance.** Should a gathering be able to start a first meeting with an
   unmet candidate (an authored "first meeting at a dance" variant for each of the three),
   or only point you to her?
3. **Who you ask.** The romance candidates are all she/her and the lords he/him, so this
   assumes the player courts women and dances with lords' kinswomen. If a player
   character or preference setting is planned, the kin generator and partner lists should
   follow it from the start rather than be retrofitted.
