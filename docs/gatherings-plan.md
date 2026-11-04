# Lords gather: the hall, feasts and dances

## What happens today

- **Talking to a lord happens only on the map.** You tap their party while it's near you (map_screen `_open_lord` → Talk). It works even when the party is parked outside a castle.
- **The Court tab is narrow.** It appears only where Edda, Farah or Kaede live (`SocialSim.residents_at` keeps only romance candidates), and it lists only them. A lord sitting at Highcliff can't be found from inside Highcliff.
- **Lords rarely share a place.** Each one is at their seat refilling (`job "home"`), guarding, escorting, patrolling, hunting or raiding. Nothing brings several lords together except a marshal's army.

## The idea

1. **Every hall shows who's there.** The Court tab exists at every town and castle you can enter and lists the lords actually present, the household and your spouse. Each can be talked to indoors.
2. **Lords gather.** In peacetime a realm's ruler, or a rich lord, holds a feast or a dance at their seat for three nights. Lords ride in from across the realm. You're invited when you've earned it.
3. **Gatherings have things to do:**
   - a first word with each lord at the table (a little Regard);
   - a toast;
   - a gift for the host;
   - gossip that points at sour lords and troubles;
   - at a dance, a partner, which counts as time together if it's someone you court.
4. **You can host.** With a crown, your seat can hold its own gathering for your lords and the lords you want to win over.

## The screens (see the mockups)

### 1. An invitation (map)

- **Map marker:** a ring of lantern light around the host's seat, with a plate: "Feast · from tomorrow · 6 lords".
- **Lord plates:** lords heading there carry "riding to the feast" under their name plate, so you can also meet them on the road.
- **If you're invited:**
  - an invitation arrives like a letter, as a banner with a Read button;
  - a journal entry shows when it is, why you're invited, how many lords are coming and the ride time, with *Who's coming* and *Ride there*.
- **News:** the War & Politics feed gets "King Aldwin holds a feast at Highcliff".

### 2. The hall, any day (settlement → Court)

**Who's listed.** IN THE HALL lists everyone present:
- the holder, if their party is stopped there;
- visiting lords whose party is stopped there (a "home", "guard" or "gather" job, or waiting);
- the household (romance candidates living there);
- your spouse.

**Each row** shows:
- pixel face, name, and what they're doing ("Holds Ravensford · at home", "Visiting · resting before the ride to Marchgate");
- a Regard chip, or the courtship status for the household;
- a gold "would like a word" badge for a trouble, news or an open visit.

**AWAY** lists the holder (and the household when they've moved) with where they've gone, plus *Show on map*.

**The tab label** counts who's there ("Court · 3"). A note says when and where the next gathering is.

**Tapping a lord** opens the lord conversation (`LordConversation.open(..., "hall")`). Tapping a household member opens the romance talk, as now.

### 3. At the feast (settlement → Feast)

During a gathering the tab becomes *Feast · N* (or *Dance · N*, or the culture's name), in brass.

**The gathering card** shows the host, which night of three, the guest count and whether you're invited. It holds three actions:

| Action | Limit | Effect |
|---|---|---|
| Raise a toast | Once per gathering; needs renown 120 and an invitation | +2 Regard with every lord present; a Cruel host gives nothing |
| Bring a gift | Once per gathering; 50 silver or 50 rations | Host +5 Regard, realm relation +2 |
| Hear the gossip | Once per night; takes one hour | A note naming something true about a guest |

**What the gossip can name:**
- a lord who is sour with their ruler, for a reason the game tracks (a lost fief, Regard with their liege low, a fief given to a rival);
- a lord with a trouble;
- a war rumour from `news_since`.

**The guest list** has the same rows as the hall. Each lord's tag is "first word at the table · +2" (+1 if you're uninvited) until you've spoken with them this gathering, then "spoke at the table". A gossip-marked lord carries the hint ("sour with the king").

### 4. Talking in the hall

- **Same talk:** it's the lord conversation as now. Only the backdrop changes: the host culture's hall, drawn in code (screen 7).
- **Caption:** "In the hall at Highcliff · the feast · evening".
- **Everything else works:** news, stories, troubles, persuasion, fealty and crown orders.
- **Guest right:** "Draw your sword" (a battle) isn't offered indoors. In its place, "Meet me outside the walls at dawn" offers the existing duel. Its stakes are the same, and nothing else happens under the host's roof.
- **First-word bonus:** at a gathering, the first talk with each lord adds the bonus once ("first word at the table").

### 5. The dance

**Nights:** one of the three nights (or all three at a dance-kind gathering) is a dance.

**Partners.** One per night:

| Partner | Effect |
|---|---|
| Someone you court, if present | Time together: +1 trust within the existing personal-conversation cap, kept as a memory (kind "visit", scene "dance_<culture>") |
| A lord | +3 Regard; Daring lords +4 |
| Watch from the wall | The gossip, free this night |

**On screen:** it reuses `TalkView`, with the hall backdrop, the partner's portrait or pixel face, and one narration line and one line from the partner per culture.

### 6. Your own feast (crowned)

The seat's Crown tab gets *Hold a gathering*.

**Choices:**
- the kind: feast or dance;
- who to invite:
  - your sworn lords (always come);
  - lords who think well of you (Regard ≥ 20);
  - lords you want to win over (come unless Regard ≤ −30);
  - their liege (optional; leaving them out is a small snub, −3 Regard with that ruler).

**Cost and limits:**
- 300 silver and 200 rations;
- not at war with anyone within two days' ride of the seat, and no siege nearby;
- once every 20 days.

**Effects:**
- +5 Regard with each lord who comes, once;
- lords you're persuading start 10 points warmer (`LordTalk.conviction` bonus while the gathering lasts and for 3 days after);
- bought lords' unrest eases (`bought_lords_day` resets).

### 7. The halls

Each culture's hall is drawn in code (`scripts/ui/hall_scene.gd`), in the pixel style of `SettlementVista`. It's tinted for the hour, and the holder's banners hang on the walls.

| Culture | Hall | Gatherings |
|---|---|---|
| Vardish | Stone and timber, high seat on a dais, hearth, long table | Feast; midsummer dance |
| Kharzani | Courtyard arches onto a garden, carpets and cushions, lanterns | Banquet; lantern night |
| Ryumon | Paper screens, pillars, tatami, low tables, scroll alcove | Moon-viewing (verses); blossom festival (dances) |

The mockup halls were drawn with the same primitives the GDScript version will use (rectangles, pixel bands, glows), so they port directly.

## Rules

**When a gathering is held:**
- Once a day per realm, if the realm is at war with no one, holds no gathering, and its last one ended at least 10 days ago: a 12% chance, so one about every two weeks.
- Peace feast: signing a peace treaty schedules one at the ruler's capital within 2 days.
- Victory feast: taking a castle or town schedules one there when the war's sieges have ended (a realm still at war holds it only if no enemy army is within two days).

**Who hosts:**
- The ruler at the capital (60%), otherwise the richest lord with a town or castle seat.
- Kind: feast or dance, 50/50.
- The name comes from the culture table.

**How long:**
- Invitations go out at once.
- It starts at the next dusk at least 24 hours away and lasts 72 hours.

**Who comes:**
- Lords of the host's realm (and allied realms at 30%) within 48 hours' ride.
- Not when on campaign (a member of a campaign army), raiding, guarding by order, captive, or below 60% men (refilling).
- Up to 8, closest first.
- They take a new job, `gather` (target the host seat), like `home` but with a set end. When it ends they clear the job.

**Breaking up:**
- A war declared against the host realm, or a siege or enemy army within 24 hours' ride, ends the gathering at once.
- Lords leave, and the news says "The feast at Highcliff broke up: war with Kharzan".

**Your invitation:** you're invited if any of these hold:
- you have a contract with the realm;
- you hold a fief in it;
- you're its ruler (crowned host);
- the host's Regard is ≥ 10.

**Without an invitation:** you can still enter (not if hostile). The first word is +1 instead of +2, and there's no toast.

**Limits per gathering:** each lord's first-word bonus once; toast once; gift once; gossip once per night; dance once per night.

**Between gatherings:** lords whose job would be `patrol` in their own lands, and who are within 12 hours of their capital, sometimes (25%) rest there for 12 to 24 hours instead (`gather` with no host). Capitals are rarely empty.

**Romance:** candidates attend gatherings held at their residence, or by their house head's realm when it's within a day of their residence. They're listed as guests; a dance with them is the "time together" above.

## Data

`WorldSim.gatherings: Array` holds one entry per active or announced gathering:

```text
{id, realm, host_lord, place, kind ("feast" | "dance"), name, starts_hour, ends_hour,
 reason ("season" | "peace" | "victory" | "player"), guests: [lord ids], invited_player: bool,
 state ("announced" | "on" | "over" | "broken"), broken_reason}
```

`GameState.gathering_log: Dictionary` maps gathering id to `{spoke: [lord ids], toast, gift, gossip_nights: [n], danced_nights: [n]}`. It is cleared when the gathering ends.

- Gatherings are saved in the world save; old saves load with none.
- A lord's `job` can be `"gather"` and `target` the place.
- `_clean_lord` keeps both.

## Code

| File | Change |
|---|---|
| `scripts/world/world_sim.gd` | `gatherings`, `_step_gatherings` (daily roll, peace/victory triggers, start, end, break), guests' `gather` job in `_think_lord`/`_lord_arrives`, `lords_at(place)` (parties stopped there), activity lines, save/load. |
| `scripts/game_state.gd` | `gathering_at(place)`, `gathering_invited(g)`, `gathering_actions(g)`, `first_word(g, lord)`, `raise_toast`, `bring_gift`, `hear_gossip` (picks a true sour lord, trouble or rumour), `dance(partner)`, `host_gathering(kind, invite)` with cost and cooldown, the journal entry. |
| `scripts/data/gatherings.gd` (new) | Names by culture and kind, invitation and narration lines, toast and dance lines by culture, gossip templates. |
| `scripts/ui/hall_scene.gd` (new) | Draws the three halls (dusk, night, day tints) with the holder's banners. |
| `scripts/world/settlement_screen.gd` | The Court tab everywhere: hall list, away list, feast card and actions, host-a-gathering card on the Crown tab. |
| `scripts/world/lord_conversation.gd` | `"hall"` mode: hall backdrop and caption, the first-word bonus, duel instead of battle. |
| `scripts/menu/dance.gd` + scene (new) | The dance on `TalkView`. |
| `scripts/world/map_screen.gd` | Lantern ring and plate at a gathering; "riding to the feast" under guests; the invitation banner. |
| `scripts/world/social_sim.gd` | `residents_at` stays; the hall merges it with lords present. |

## Tests

`tests/gathering_tests.gd`:

- **When gatherings happen:**
  - none during war;
  - a peace treaty brings a peace feast at the capital;
  - in peace, roughly one per realm per two weeks over a long run.
- **Guests:**
  - they ride there with job `gather`;
  - none who are on campaign, captive or refilling;
  - at most 8.
- **The hall:** lists the holder, the guests and the household; the away list names the holder's job.
- **Invitation:**
  - with a contract, invited;
  - without one, the first word gives +1;
  - when hostile, you can't enter.
- **Actions:**
  - the first word with each lord counts once;
  - toast, gift and gossip limits;
  - the gossip only names something true.
- **Dance:**
  - with someone you court, +1 trust within the cap and a memory;
  - with a lord, Regard.
- **Hall talk:** no battle challenge indoors; the duel is offered.
- **Breaking up:** declaring war on the host realm breaks it up and the lords leave.
- **Your own feast:**
  - cost, cooldown, and who comes;
  - the persuasion bonus applies while it lasts.
- **Saves:** save/load mid-gathering; an old save has no gatherings.
- **Balance:** world-sim gates still hold in `run_tests` (peacetime patrols drop a little; war behaviour is unchanged because gatherings only happen in peace).

## Order of work

1. `lords_at`, the hall list and away list in the Court tab, and the hall mode of the lord talk with the drawn halls.
2. Gatherings in the world sim: triggers, guests' `gather` job, break-up, map marker, news, saves.
3. The feast tab with its actions, the invitation and journal, the first-word bonus and the gossip.
4. The dance.
5. Hosting your own as a crown.
6. Lords resting at their capital between gatherings.
7. Tests, screenshots, README.
