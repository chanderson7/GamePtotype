# Married life: her hand in your affairs

**Status: built.** Builds on the wedding (`docs/wedding-plan.md`, `docs/wedding-festivities-plan.md`)
and the house pacts of `docs/romance-and-allies-plan.md`. Rules in `scripts/world/married_life.gd`,
words in `scripts/data/married_lines.gd` and `letters.gd` (`MARRIED_LETTERS`), tests in
`tests/married_life_tests.gd`. Where the build differs from the plan below:

- **A truce is refused only for the ruler's Regard.** The "fought them in the last 3 days" rule
  needs a record the game doesn't keep.
- **Good words** are offered to the four lords you've met who think least of you.
- **With her in the company, Kaede answers a lookup at once**, not twelve hours later.
- **When her seat falls she comes to your fief** whenever it isn't under siege. Excluding a fief
  held by a realm at war with her captor would almost always exclude it, since the captor is at
  war with her own realm.
- **A house's lord holding a place** stops when his time is up or if he's taken, checked every
  step rather than only when he next thinks.
- **Letters fill any placeholder they carry** (`Letters._fill`), so a married letter can say
  `{outcome}`, `{facts}`, `{near}`.

## What marriage gives today

- **Her house's purse:** up to 150 silver every 14 days, from the *Grant* button on her People page.
- **A pact:** attacking her seat or yours breaks it. Her house's head greets you as kin
  (`lord_conversation.greeting_kind`, "kin" lines in `lord_lines.gd`).
- **One sixth-chapter matter** each, answered once.
- **Evenings together** ("Sit with me a while"): words only.
- **Letters** after a battle, a fallen captain, or a long time away (`married_life_check`).

Two things are promised and not done:

- **"Help refilling troops."** The closing card says it; nothing does it (only empty
  `limits` fields exist).
- **Help that fits who she is.** Edda keeps a household's accounts, Farah is an envoy, Kaede
  keeps an archive of maps and records. None of it reaches your campaign.

## The idea

The one you marry changes how you play. Each partner answers one of the campaign's
pressures:

| | Pressure |
|---|---|
| **Edda** | Money and food |
| **Farah** | Enemies and politics |
| **Kaede** | Not knowing what's out there |

Each has:

- **A standing benefit**, small, always on, and never the same lever as a captain's role
  (the Quartermaster saves food, the Scout shows exact numbers).
- **One ask**, from her talk, on a cooldown, with a visible cost and an honest reason when
  she can't.
- **Letters that come when they're needed**, about your real situation.

Shared by all three:

- **Her house's help** (men for your squads; her house's lord holding a place for you), on
  the pact card's footing.
- **Her seat as your home.**
- **Her seat in danger**, and you riding to it.
- **Travelling together for a season.** She can be taken if you lose, and you can bring her
  home.

### Rules for all of it

- **Honest.** Nothing is created from nowhere: silver and food come out of her house
  lord's purse, men out of her seat's garrison. Nothing teleports: a cart or an envoy rides
  the roads and takes the time the road takes.
- **No chores.** No affection meter that decays. Time together only adds.
- **Public vs private vows.**
  - Her own help (her standing benefit, her ask, her letters) comes with either.
  - Her house's help (grant, men, holding a place, Edda's supply train, which the
    household pays for) needs the pact, which only a public wedding or a sworn friendship
    makes.
- **Friendship** (a sworn pact without marriage) gets the house's help and her letters,
  not her standing benefit, her ask, or travelling together.

## 1. Promises kept

### Men from her house

- **Where:** in her talk at her seat: *Ask your house for men*.
- **What:** her house's lord sends up to **24 men** from her seat's garrison to fill your
  understrength squads, smallest squads first. They come as raw recruits, diluting
  experience as hiring does. The garrison never drops below **40 men**.
- **Cost:** you pay their wages from then on.
- **Cooldown:** the house's military help, **14 days**, shared with *holding a place*.
- **Refused when:** the seat isn't held by her house's realm, that realm is hostile to
  you, the garrison can't spare men, your squads are full, or it's too soon.

### Kin greetings

Already done; no change.

## 2. Each partner's part

### Edda: the household

- **Standing benefit:** she keeps your fief's accounts by letter, so its daily tax is
  **+20%**.
- **Her ask: send a supply train.**
  - **Load:** **120 rations** (her house pays **1 silver each**) and the household grant's
    silver (up to 150, while her lord's purse keeps 300).
  - **Route:** she chooses where with you: where you are, if it's a town or castle, or one
    of the four friendly towns or castles nearest you.
  - **The journey:** a cart leaves her seat and rides the roads. It's drawn on the map, and
    the Journal follows it.
  - **Arrival:** it waits at the place until you're there, then the food and silver are
    yours.
  - **Danger:** a bandit band that comes within **30** of it takes it. She writes that it
    was lost; nothing is refunded.
  - **Cooldown:** shared with the household grant (**14 days**). Needs the pact.
- **Her letter when you need it:** on a day you can't cover two more days of wages, if the
  train could be sent, she writes ("The tallies say you're short"). One reply, *Send the
  train*, sends it to the place nearest you. At most once a week.

### Farah: the envoy

- **Standing benefit:**
  - A captive lord's house pays **25% more** ransom, up to what it holds.
  - Reparations to a realm cost **half**.
- **Her ask: carry a letter.** She rides as an envoy, drawn on the map and followed in the
  Journal. Envoys are let pass. On arrival she writes what came of it:
  - **Seek a truce with a realm hostile to you.** Offered only when the hostility is your
    own standing (not your employer's or your crown's war).
    - **Rides to:** the realm's capital.
    - **Granted:** your standing rises to **−10** (no longer hostile).
    - **Refused:** if its ruler's Regard for you is below **−40**, or you've fought them in
      the last **3 days**.
  - **Speak well of you to a lord** you've met, whose Regard is under 40 and who isn't
    hostile.
    - **Rides to:** his seat.
    - **Result:** **+10 Regard**, once per lord.
  - **Cooldown:** **10 days** from when she sets out.
- **Her letter when you need it:** when a marshal army starts mustering against your fief,
  her seat, or a holding of the realm you're contracted to, she writes once per army: who,
  where, and against what.

### Kaede: the archive

- **Standing benefit:** the map's sheet for any castle, town or village shows her records:
  garrison strength, danger, services and why the place matters
  (`WorldSim.settlement_intelligence`, until now unused). With no fog of war, this is the
  knowledge sight doesn't give.
- **Her ask: look something up.** An answer comes by letter **12 hours** later.
  - **A castle or town** (the six nearest you): its walls, garrison, owner and lord, and
    what a siege would face.
  - **A lord you've met:** where he is now, his realm, his bearing, his Regard for you, and
    what he resents (a lost or burned castle, a burned village, a war-weary realm).
  - **Cooldown:** **2 days**.
- **Her letter when you need it:** every week, if a bandit band is within **260** of you,
  she sends a map with it marked ("the useless map has a use"). The Journal follows the
  band until it's gone.

## 3. Shared

### Home

- **Resting at her seat** heals the wounded **twice as fast** again, on top of resting.

### Her seat in danger

- **The siege begins:** when a marshal army besieges her seat, she writes ("{place} is
  under siege"), and the Journal shows *Her seat is under siege* with *Show on map*.
- **The call to the walls:** at her seat during the siege, it now comes for you too (it
  used to come only at your own fief), as long as its owner isn't hostile to you. Win and
  the besiegers fall back.
- **Held:** if the siege fails while you held the walls, she writes her thanks and her
  house's standing rises **+5**.
- **Fallen:** if it falls, she moves to your fief if you hold one and its realm isn't at war
  with the captor. Otherwise she goes where she would today. Her letter about it is the
  existing one.

### Her house holds a place

- **Where:** in her talk: *Ask your house to hold a place*.
- **The places:** your fief, your current town or castle, or the four friendly places
  nearest you, none hostile to his realm.
- **What happens:** her house's lord rides there with his own army and holds it for **48
  hours**, using the crown lords' timed guard order (`order` with `until`, not limited to
  the crown when it carries `house`).
- **On the map:** he shows "Holding {place} for the captain". The Journal counts down.
- **Cooldown:** shares the house's **14-day** military help. Needs the pact.
- **Refused when:** he's a captive, already riding with a marshal, spent (below his refill
  line), or his realm is hostile to you.

## 4. Travelling together

- **Joining:** at her seat, married: *Come with me for a while.* She rides with the
  company until you send her home (*Ride home; I'll see you there*: she's back at her seat
  when the road allows).
- **While she's with you:**
  - She's in **Around the fire** in her travel clothes. Tapping her opens her talk, by the
    company's fire.
  - Her ask is ready **twice as often**. Envoys and lookups set out from where you are.
  - **The camp** sometimes has a moment with her (three each).
  - **Her seat** shows her away. The Court tab doesn't list her.
- **Captured:** if the company loses a battle while she's with it, she's taken by whoever
  beat you: a lord (held at his seat) or a band (held by it).
- **A Road Home:** a Journal entry with the captor and where they are. She comes home when:
  - **You ransom her:** **250 silver**, from her People page. Her captor's house takes it.
  - **You beat her captor** in battle.
  - **Her captor is taken or killed** by anyone, or a band holding her is destroyed: she
    walks free in the confusion.
  - **After 10 days** her house pays for her. She's home, and her house's standing falls
    **−5**, because you didn't come.
- **Back home:** she writes, and the memory is kept (*The road home*).

## Data

**`SocialSim.household`** (saved with the social sim):

```text
{ convoys: [{id, kind ("supply" | "envoy"), cand, from, to, path, depart, arrive,
             food, silver, purpose: {kind ("truce" | "word"), realm, lord_id}, state}],
  ask_hour: {cand: hour the ask is ready again},
  with_company: cand or "", joined_hour,
  captive: {cand, kind ("lord" | "band"), lord_id, party_id, since, captor},
  sent: {letter key: hour},
  warned_armies: [army ids], besieged: {army_id, place, defended},
  marked_band: {party_id, until}, spoken_well: [lord ids] }
```

Lord order: `{"kind": "guard", "target": id, "until": hour, "house": house_id}`.

## Code

| File | Change |
|---|---|
| `scripts/world/married_life.gd` (new) | The rules: asks, convoys (positions, ambush, arrival), house help, letters when needed, seat in danger, travelling and capture, rescue. Static functions on GameState, like `LordTalk`. |
| `scripts/data/married_lines.gd` (new) | Her words in the talk: asks, refusals, travelling, the fire, home again. |
| `scripts/data/letters.gd` | New letters and replies. A letter may carry only a married version. |
| `scripts/world/social_sim.gd` | `household`: save, load, `residents_at` (not while she's away or taken). Relocation to your fief. Reply actions. |
| `scripts/world/world_sim.gd` | The timed house guard order. Ransom and reparation hooks stay in GameState. |
| `scripts/world/marshal_armies.gd` | The call to defend her seat. |
| `scripts/game_state.gd` | Hooks: fief tax, healing, ransom, reparations, the daily and per-step married-life steps, battle won and lost, commitments. |
| `scripts/menu/romance_talk.gd` | *I need your help…* (her ask, her house's help), come with me / ride home, talk by the company's fire. |
| `scripts/menu/people.gd` | *Speak* while she's with you, *Ransom* while she's held, replies that act. |
| `scripts/world/map_screen.gd` | Convoys on the map, "Holding X for the captain", Kaede's records on the place sheet. |
| `scripts/menu/main_menu.gd` | Her token around the fire. |
| `scripts/data/camp_moments.gd` | Moments with her on the road. |
| `scripts/menu/wedding_feast.gd` | The closing card says what the house can do, truthfully. |

## Tests

`tests/married_life_tests.gd`:

- **House help:** men from the garrison (never below 40, wages yours, the shared cooldown);
  holding a place (the order, expiry, refusals).
- **Edda:** fief tax +20%; the train: cost from the purse, the ride, arrival, collecting,
  ambush; the short-of-wages letter and its reply.
- **Farah:**
  - Ransom +25% and half-price reparations.
  - A truce granted and refused; a good word given once.
  - The army warning, once per army.
- **Kaede:** the records on the sheet; a lookup letter for a place and a lord; the band map
  and its Journal entry.
- **Private vows:** her ask works; house help is refused.
- **Her seat:**
  - Healing at home.
  - The siege letter and Journal entry; the call to the walls at her seat.
  - Thanks after holding it; moving to your fief when it falls.
- **Travelling:**
  - Joining and coming home; her token at the fire; her ask twice as often.
  - Taken on a loss.
  - Freed by ransom, by battle, by her captor's fall, and by her house after ten days.
- **Saves:** every state round-trips.

## Order of work

1. Data, saves, men from her house, the honest closing card.
2. Edda, Farah, Kaede: benefits, asks, convoys, letters.
3. Holding a place; her seat in danger; home.
4. Travelling together, capture, A Road Home.
5. The talk, People, map and camp screens; tests; renders; README.
