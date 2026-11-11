# Bannerfall: the paid features plan

- **Date:** 2026-11-04
- **Status:** proposed. Nothing here is built.
- **Model in one line:** the game is free to download and whole as the Vardish. The Kharzani
  and the Ryumon are paid peoples, each a different home, cast, army and opening on the same
  Glass Sea. Everything sold is a one-time purchase that restores on a new phone. Nothing sold
  makes a battle easier, saves a captain, or buys silver.

## Why this model fits this game

Bannerfall's identity is consequence: captains who can die, men who desert when unpaid, a
company that carries its losses. Any purchase that softens that (a revive, a purse of silver,
a stronger squad) sells the thing the game is about. So the only honest things to sell are
**more of the game** (another people to begin as, with its own opening and cast) and
**ways to make it yours** (heraldry and regalia). Both are what premium strategy games on
phones already sell well, and neither gives a reviewer a "pay to win" line.

The user's proposal, one people free and two paid, is the right shape. The free people
has to be a full game, not a demo, or the reviews are the demo's. The Vardish campaign stays
complete: the whole map, every lord, contracts, fiefs, the crown and its ending.

### What the starting people actually controls

Reading `game_state.new_campaign` and the uses of `GameState.culture`, the people you begin
as decides:

- where you start (`capital_of_culture`: Highcliff, Khalun or Kurogane);
- your first five squads and their captains (names, troop kits, portraits, sprites);
- which realm's lords are your kin: the realm at peace with you, the realm you may swear to
  without proving yourself, the banner on your rider and battle standards;
- the camp music on Home (`camp_<people>`), and the battlefield ground when no enemy sets it;
- which companion sits in your home tavern on day one, and which romance candidate is
  closest to your road.

It does **not** lock the rest of the world. A Vardish company can ride to Khalun, hire
Askari and Faris, court Farah, serve the Sultan, and take Kurogane for a crown. This is good
for the model in two ways: the free game is really whole, and the paid peoples are on show
inside it. Every Vardish player meets the Kharzani and the Ryumon as neighbours before being
asked to pay to *be* them.

## What is for sale

| Product | Id (suffix of `com.anderson-sites.bannerfall`) | Price (US tier) | What it is |
| --- | --- | --- | --- |
| **The Kharzani** | `.people.kharzan` | $3.99 | Begin as the Kharzani: Khalun, a Kharzani company, the Sultan's lords as kin, the *Debt of Khalun* opening, two people's deeds, the painted Khalun plate. |
| **The Ryumon** | `.people.ryumon` | $3.99 | Begin as the Ryumon: Kurogane, a Ryumon company, the Shogun's lords as kin, the *Writ Across the Strait* opening, two people's deeds, the painted Kurogane plate. |
| **Peoples of the Glass Sea** | `.people.all` | $5.99 | Both peoples. The bundle is the product most people should buy; the singles exist so no one has to buy a people they do not want. |
| **Heraldry & Regalia** | `.regalia` | $1.99 | Six more crown colours, eight banner devices for the company and the crown, captain portrait frames by rank, and a different Home title theme for a crowned company. Cosmetic only. |
| **Chronicler's Edition** | `.chronicler` | $7.99 | Everything above, plus the Chronicle export (the campaign's chronicle as a shareable image) and a line in the credits roll. For the player who wants to pay once. |

Decisions for the user, with my recommendation:

- **Prices.** $3.99 / $5.99 / $1.99 / $7.99 are the recommendation. The bundle should cost
  less than two singles so the choice is easy; the Chronicler's Edition should be under $10
  so it reads as "the full game" rather than "the whale pack".
- **Steam.** Sell the whole game as one paid app ($12.99–14.99) with everything in it; no
  people packs there. Steam players expect a complete game and DLC fragmentation for a
  three-people game would look mean. Android mirrors iOS.
- **Which people is free.** Vardmark. It is the default everywhere already (`Cultures.info`
  falls back to it, Home picks it first), it is the most legible start for a new player
  (knights, keeps, a king), and the tutorial and the Highcliff capital plate were made around
  it. The other two are the more distinctive peoples, which is what makes them worth paying
  for.

### What is never for sale

Written down so it survives a later "quick win" conversation:

- No silver, food, men, renown or relation for money. No way to reinforce, heal or revive.
- No consumables, no energy, no timers, no "speed up".
- No advertisements, no rewarded video, no cross-promotion.
- No locked save slots, no locked settings or accessibility, no locked tutorial.
- No lock on a save. A campaign begun as the Kharzani loads and plays on a phone that has
  not restored the purchase. Only *beginning* a new campaign as a paid people is gated.
- No people-locked content inside the shared world: Farah, Tariq Windrunner, the Sultan's
  contracts and Kharzani recruits stay open to a Vardish company.
- At most one in-game nudge per campaign, and never in a battle or a story scene.

## Package A: the Store and the gate

The plumbing, built first so everything else sits on it and can be tested without a phone.

### `scripts/store/store.gd`, autoload `Store`

```
signal changed                       # owned set changed (purchase, restore, dev file)
func owned(product: String) -> bool
func owned_people(culture: String) -> bool     # Vardish: always true
func can_begin_as(culture: String) -> Dictionary  # {ok, reason, product}
func price(product: String) -> String          # "$3.99", or "" until the store answers
func buy(product: String) -> void              # async; `changed` fires on success
func restore() -> void
func products() -> Array                       # from scripts/data/products.gd
```

`Store` keeps the owned set in `user://entitlements.json` so the game knows what it owns
before the store answers (phones open the game offline). On launch it asks the backend to
refresh; a product that the backend says is not owned is **not** removed from the local set
until a `restore()` the player asked for confirms it, so a flaky network never locks a
people the player paid for.

Backends, one chosen at launch:

- `store_dev.gd`: the editor, tests and headless runs. Owns whatever
  `user://entitlements.json` lists; `buy()` succeeds at once; `price()` returns the tier
  text from `products.gd`. A `--own=all` or `--own=none` command line switch for screenshots.
- `store_ios.gd`: StoreKit 2 through a Swift plugin. `buy`, `restore`, product prices
  localized by the store, transaction listener for purchases finished outside the app.
- `store_android.gd` later: Godot's own `GodotGooglePlayBilling` plugin.
- `store_steam.gd` later: `owned()` is always true.

The iOS plugin choice needs a Mac to settle, so it is the last step, not the first. The
candidates as of this writing: the StoreKit 2 Swift plugins on the asset library built for
Godot 4.6 and 4.7 (hrk4649's at 0.4.0 for 4.7; atlasapplications' Godot StoreKit at 1.5),
and OpenIAP's cross-platform `godot-iap`, which also covers Play Billing. The old
`godot-ios-plugins` `inappstore` plugin is StoreKit 1 and reported inconsistent restore
validation; avoid it. Whichever is chosen, `store_ios.gd` is the only file that knows it.

### `scripts/data/products.gd`

Pure data, like `cultures.gd`: id, name, tier price text for the dev backend, one-line
pitch, the list of what it unlocks (`peoples`, `regalia`, `chronicle_export`), and for a
people the "what you get" lines shown on its sheet. The bundle and the Chronicler's Edition
list the products they contain, so `owned("people.kharzan")` is true when the bundle is
owned.

### The gate, in one place

`Store.can_begin_as(culture)` is the only gate. `title.gd`'s Begin button and
`new_campaign.gd`'s people cards both ask it; `GameState.new_campaign` does not (the UI is
the gate, so tests and saves are never blocked by the store). A locked people never
disappears and is never greyed: its card is drawn in full colour with a brass lock chip and
the price, and tapping it opens the People sheet rather than beginning.

### Saves

`SaveSlots` already records `culture` in the index. A save of a paid people loads without
the purchase (see the never list). Home's campaign card for such a save shows no lock. The
only effect of a missing entitlement is on **Begin**.

## Package B: the screens

### Home: the people picker

Today each people is a card with its banner, name, realm, blurb and three strength chips,
and the big button reads "Begin as the Vardish". The locked cards gain a chip in the top
right and the button changes meaning when a locked people is lit.

```
┌─────────────────────────────────────────┐
│  BEGIN YOUR COMPANY                     │
│ ┌─────────────────────────────────────┐ │
│ │ ▐▌  Vardish                         │ │
│ │ ▐▌  Kingdom of Vardmark             │ │
│ │ ▐▌  A feudal kingdom of stone keeps │ │
│ │     and armored knights...          │ │
│ │     [Shield walls][Crossbows][Knights]│
│ └─────────────────────────────────────┘ │
│ ┌─────────────────────────────────────┐ │
│ │ ▐▌  Kharzani            ⚿ $3.99    │ │
│ │ ▐▌  Sultanate of Kharzan            │ │
│ │ ▐▌  A sultanate of walled cities    │ │
│ │     and swift riders...             │ │
│ │     [Horse archers][Javelins][Fast] │ │
│ └─────────────────────────────────────┘ │
│ ┌─────────────────────────────────────┐ │
│ │ ▐▌  Ryumon              ⚿ $3.99    │ │
│ │ ...                                 │ │
│ └─────────────────────────────────────┘ │
│                                         │
│ ┃      Begin as the Vardish          ┃ │   ← Vardish lit
│                                         │
│ ┃   Ride as the Kharzani · $3.99     ┃ │   ← Kharzani lit: opens the sheet
│   Both peoples $5.99 · Restore purchases│
└─────────────────────────────────────────┘
```

The lock chip is the same shape-coded chip the game uses elsewhere (a brass outline, the
`o_lock` icon to add to `assets/ui`), so it reads as part of the game, not a storefront. When
a people is owned the chip is gone and the card is as it is today. Under the big button a
small muted line offers the bundle and Restore, in the same `_minor` style as "Learn to play".

### The People sheet

Opened by tapping a locked card's button, or "Learn more" on a locked card in New campaign.
A `Page.column` like the tutorial, scrolling, with the people's banner, their capital's plate
where one exists, and what the purchase is in plain words.

```
┌─────────────────────────────────────────┐
│ ‹ Back                                  │
│                                         │
│        ▐▌▐▌  THE KHARZANI               │
│         Sultanate of Kharzan            │
│                                         │
│ ┌─────────────────────────────────────┐ │
│ │   [painted Khalun plate, 405×220]   │ │
│ └─────────────────────────────────────┘ │
│                                         │
│ Begin at Khalun, the Sultan's city on   │
│ the southern shore. Your company is     │
│ Kharzani: Askari blades, Faris riders   │
│ and horse archers, led by captains of   │
│ the desert towns. The Sultan's emirs    │
│ are your kin, and Vardmark's knights    │
│ are the foreigners.                     │
│                                         │
│ WHAT YOU GET                            │
│ ◆ A Kharzani company from day one       │
│ ◆ The Debt of Khalun: your own opening  │
│ ◆ Two deeds only a Kharzani can earn    │
│ ◆ Khalun, painted                       │
│ ◆ Your own camp fire and battle music   │
│                                         │
│ Everything else is already yours: the   │
│ map, the lords, the crown.              │
│                                         │
│ ┃        Buy · $3.99                 ┃ │
│ ┃  Both peoples · $5.99              ┃ │
│   Restore purchases                     │
└─────────────────────────────────────────┘
```

While the store is answering, the Buy button shows "…" and is disabled; on success the sheet
closes to Home with the people lit and the button now reading "Begin as the Kharzani", and a
short brass line "The Kharzani ride with you." On a failure or a cancel the sheet stays, and
the error is one muted line under the button, never a modal.

### New campaign

The cards keep their layout. A locked card's Go button becomes "Learn more" and opens the
People sheet; the lock chip sits beside the capital line. If the player arrives with a
locked people picked on Home (`Scenes.new_campaign_pick`), the card is lit as today, and
Learn more is the only action on it. Tutorial, Casual and Ironman stay as they are.

### Settings

One row, under Sound, in the existing switch-row style with no switch:

```
│ Purchases                               │
│ Your peoples: Vardish · Kharzani        │
│ Heraldry & Regalia: not owned           │
│                [Restore purchases]      │
```

### The one nudge

When a Vardish company first enters Khalun or Kurogane, the settlement sheet's description
gets one extra muted line at the bottom: *"The Kharzani can be a people to begin as, from
the Home screen."* It shows once per campaign (`GameState.nudged`, saved), never while a
battle or a story scene is up, and never at all once the people is owned. No other nudge.
The reasoning: the player has just seen the city and the people's troops for hire; this is
the moment the pitch is honest, and once is enough.

## Package C: the Kharzani

> **Superseded (2026-11-11):** what each paid people contains is now
> [`paid-peoples-plan.md`](paid-peoples-plan.md): a rule, an order, a five-chapter story and a
> home for each. The opening, deeds, roster and plate below are kept there as parts of it.

What the purchase has to contain so that it is a different game to begin, not a flag.
Most of it already exists (the capital, the kit, the captains, the music); the new work is
the opening, the deeds, the roster, the plate.

### The opening: *The Debt of Khalun*

Three authored screens in the tutorial-picture style (`TutorialArt`) on the first launch of a
Kharzani campaign, then a letter in the inbox and a commitment in the journal.

```
┌─────────────────────────────────────────┐
│ [picture: a caravanserai yard at dawn,  │
│  horses, a scribe with a ledger]        │
│                                         │
│ Khalun, the first day of the season     │
│                                         │
│ The house of Darvani lent your father   │
│ the silver that raised this company,    │
│ and your father is dead. The scribe is  │
│ polite about it. The sum is six hundred │
│ silver, due by the end of the season,   │
│ and the house would prefer a friend to  │
│ a debtor.                               │
│                                         │
│                 Next ›                  │
└─────────────────────────────────────────┘
```

Mechanically: a journal commitment *Repay the house of Darvani* (600 silver, 60 days,
pay at Khalun) using the existing `commitments()` shape. Paying it on time earns +15
standing with Kharzan and a letter of thanks; missing it costs −10 and a cool reply, nothing
more. It is a reason to take the first contracts, not a punishment. Six hundred silver in
sixty days is reachable by the balance campaigns' earnings (`Plans.campaign`), to be checked
by a seeded run in the tests.

### The deeds

Added to `achievements.gd` with a `people` field, so they show only in a campaign of that
people and the ten existing deeds stay as they are:

- **the Sand-Riders**: win a battle with three companies of horse in the field.
- **the Sultan's Own**: be granted a fief by the Sultanate of Kharzan.

### The roster

The starting five are the same for every people today (two foot, spears, bows, horse). A
people's first company should look like its people:

- Vardish: foot, foot, spears, bows, horse (as now).
- Kharzani: foot, spears, bows, horse, horse (two Faris companies, one fewer foot).
- Ryumon: foot, spears, spears, bows, horse (two Ashigaru, a Yumi company).

Sideways, not upwards: the same number of men, wages that differ by a day's silver or so
(horse cost more; the Kharzani start a little poorer per day, the Ryumon a little richer).
The culture balance gate (`tests/_partial_cultbal` family and the campaign plans) runs with
the new rosters and has to stay within its bands.

### The plate

The painted Khalun capital plate from `artwork-roadmap.md` Package B ships with the people.
It uses the external illustration workflow the portraits used, so it is the one piece of
this package that is not code; until it exists the sheet shows the pixel vista
(`SettlementVista`) the New campaign cards use.

## Package D: the Ryumon

Same shape as C, with:

- **The opening: *The Writ Across the Strait*.** The Shogun's court has sent your company to
  the mainland with a writ and a purpose it does not explain. Three screens: the crossing,
  the writ unsealed at Kurogane's gate (it names a mainland lord to be watched), and the
  captains asking what it means. Journal: *Carry word of lord X to Kurogane* within 45 days,
  where X is a Vardish or Kharzani lord picked at setup; it completes by meeting them on the
  road or in a hall (the existing lord conversations), and rewards +15 Ryumon standing and a
  Ryumon lord's regard. The company's first forty days have a reason to cross the sea, which
  is the Ryumon's whole situation in the game (the balance-of-power realm that watches the
  mainland).
- **Deeds:** *the Strait-Crossers* (hold a mainland castle or town as the Ryumon) and
  *the Unbroken Line* (win a battle without a squad breaking, with two or more spear
  companies).
- **Roster** as above; **plate**: Kurogane.

## Package E: Heraldry & Regalia

Cosmetic, and the smallest package. All drawn in pixel art by the existing `Heraldry`
routines, so no external art.

- Six more crown colours in `WorldData.CROWN_COLORS` behind the entitlement: the Realm sheet's
  colour picker shows all twelve, the locked six with the lock chip, and tapping one opens
  the regalia sheet.
- Eight banner devices (a hawk, a sun, a wave, a tower, a stag, a crescent, a cloud, a
  crossed-lance) for the company's standard in battle and the crown's banner on the map.
  Today a company flies its realm's banner; the device would sit on it in the crown colour.
- Captain portrait frames by rank: plain, brass at five battles, laurel at ten (the Old
  Guard). Drawn as a frame around the existing portraits.
- An alternate title theme for a crowned company (a variation of the Glass Sea theme with
  the people's instrument forward; `tools/music.py` renders it).

## Package F: the Chronicler's Edition

The bundle of everything plus:

- **Chronicle export**: the Chronicle (last 30 events) and the company's deeds rendered
  to one tall image in the game's style, saved to Photos (the iOS share sheet via
  `OS.shell_open` on the written file, or the plugin's share call). People share these.
- A line in the credits roll: the owner's company name as of the purchase, read from the
  current campaign ("Brann's Company, the Chiefbreakers"), kept in `user://`.

## Where the free game shows the paid game (and where it does not)

- Home: lock chips on the two cards, the minor line under Begin. Once owned, gone.
- New campaign: Learn more on the locked cards.
- Settings: the Purchases row.
- The one nudge in Khalun and Kurogane.
- Nowhere else: not in battle, results, camp, the journal, letters, lords' lines, the
  wedding, the hall, or the ending.

## Files

| File | Change |
| --- | --- |
| `scripts/store/store.gd` | New autoload: owned set, gate, buy/restore, backend choice. |
| `scripts/store/store_dev.gd`, `store_ios.gd` | Backends. Android and Steam later. |
| `scripts/data/products.gd` | Product data and what each unlocks. |
| `scripts/data/openings.gd` | The two openings: screens, letter, commitment. |
| `scripts/data/achievements.gd` | `people` field; four new deeds. |
| `scripts/menu/people_sheet.gd`, `scenes/people_sheet.tscn` | The preview and buy sheet. |
| `scripts/menu/opening.gd`, `scenes/opening.tscn` | The three-screen opening, tutorial style. |
| `scripts/menu/title.gd` | Lock chips, Begin/Ride button, the minor line. |
| `scripts/menu/new_campaign.gd` | Learn more on locked cards. |
| `scripts/menu/settings.gd` | Purchases row. |
| `scripts/game_state.gd` | Roster by people; `nudged`; the opening's commitment; save v7 (additive). |
| `scripts/world/settlement_screen.gd` | The one nudge line. |
| `scripts/world/world_data.gd`, `scripts/ui/heraldry.gd` | Twelve crown colours, devices, frames (E). |
| `project.godot` | `Store` autoload; the iOS plugin entry. |
| `export_presets.cfg` | The plugin, StoreKit capability. |
| `assets/ui/o_lock.svg` | The lock icon. |
| `README.md` | A "What's free and what's paid" section; the never list. |

## Tests

`tests/store_tests.gd`, with the dev backend:

- the Vardish are always open; `can_begin_as` for the others is closed with a product and
  a reason until owned;
- the bundle and the Chronicler's Edition own their contents; owning a single does not own
  the bundle;
- the owned set survives a restart (`user://entitlements.json`), and a backend that answers
  "not owned" does not remove a locally owned product without a player-asked restore;
- a Kharzani save loads with nothing owned, and Home shows no lock on it;
- the Home cards: locked chips and prices on the two, none on the Vardish, none on an owned
  people; the button text for each lit people;
- New campaign: Learn more on locked cards, Begin on open ones;
- the nudge shows once in Khalun, never in Highcliff, never once owned, and round-trips
  through a save;
- each people's roster: five squads, the expected types, the same men, wages within a
  day's silver of each other; the culture balance gate still passes;
- each opening: its commitment appears in `commitments()`, completes and expires as written,
  and never consumes RNG the world uses (the same seed with and without the opening gives the
  same world after sixty days);
- the people's deeds show only for that people and award once.

Plus the existing suites, run in full, since the roster change touches the balance
campaigns.

## Order of work and sizes

1. **A, the store and gate with the dev backend, and its tests.** Small. Everything else
   can be built and screenshot against it.
2. **B, the screens.** Medium. Lock chips, the People sheet, Settings, the nudge.
3. **C, the Kharzani.** Medium–large: the opening, the deeds, the roster and the balance run.
4. **D, the Ryumon.** Medium, the same again.
5. **E, Heraldry & Regalia.** Small–medium, pixel art only.
6. **F, the Chronicler's Edition.** Small once E exists; the export is the only new piece.
7. **The iOS backend.** Needs a Mac, an App Store Connect record for each product, the
   sandbox tester account, and a run on a real phone: buy, cancel, restore, airplane mode,
   a purchase interrupted by a call. This is the step that cannot be done from this session.
8. **Store listing.** The "In-App Purchases" label is automatic; the description should say
   what the free game is in one sentence so the first review is not "free to try". The
   privacy label stays "data not collected": the store owns the receipts, the game keeps
   nothing but the owned set.

Steps 1–6 are a normal feature series here, with mockups shown before each screen is built
as usual. Step 7 is the user's, with the code ready for it.

## Open questions for the user

- The prices and whether the Chronicler's Edition exists at all (it could wait for a
  second release).
- Whether a ten-day **trial** of a paid people is wanted: begin as the Kharzani, ride ten
  campaign days, then the campaign waits for the purchase and resumes exactly where it was.
  It is the strongest conversion lever, because the player has captains by then, and that
  is also why it can feel like a hostage. My recommendation: ship without it and add it only
  if the sheet alone does not convert, and if added, say "ten days" on the card before the
  player begins.
- Whether Vardish players should be able to buy a single **opening** without the people
  (no: the openings are the people's).
