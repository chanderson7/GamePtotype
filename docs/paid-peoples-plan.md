# Bannerfall: what the Kharzani and the Ryumon are worth paying for

- **Date:** 2026-11-11
- **Status:** proposed. Nothing here is built.
- **Reads with:** [`paid-features-plan.md`](paid-features-plan.md). That plan settles the
  model (Vardish free, two paid peoples, one-time purchases), the store, the gate and the
  screens, and none of that changes. This plan replaces its Packages C and D, which say what
  a paid people *contains*.
- **In one line:** a paid people has to be a different company to run, not a different
  coat. Each gets a rule its company lives by, an order only it can give in battle, a story
  with its own ending, and a home.

## The problem

What beginning as a people changes today, from `GameState.new_campaign`, `WorldSim.setup`
and the uses of `GameState.culture`:

- the capital you start at, and so which realm is friendly on day one;
- your first five captains' names, and the dress and words of your first five companies;
- the banner on your rider and standards, the camp tune on Home.

Everything else that makes the Kharzani and the Ryumon distinct is already open to a Vardish
company, on purpose: their troop trees (`units.gd`: horse archers, javelins, hatamoto,
naginata) are hired in their towns, Tariq and Mori sit in their taverns, Farah and Kaede can
be courted, the Sultan and the Shogun both hire. `cultures.gd` says it plainly: "only what
they're called and who leads them differs."

So a Kharzani campaign and a Vardish campaign are the same game after the first ride. The
earlier plan added an opening of three screens, two deeds, a reshuffled first roster and a
painted plate. That is an evening's difference. It would not survive the first review that
asks "what did I pay for?"

The fix is not to lock the shared world (the never list in the paid plan stands: no
people-locked troops, companions, romances or contracts). It is to add things that are true
only of **the company you are**, which the shared world never had.

## The bar

Two tests, to hold every feature below against:

1. **An hour in, the player is making a decision a Vardish player never faces.** Not a
   bigger number: a different choice.
2. **A Vardish player watching cannot call it stronger, only different.** Every rule is a
   trade, and the scripted campaigns in `tests/plans.gd` have to end in the same bands for
   all three peoples.

Each people gets four parts:

| Part | What it is | Where the player meets it |
| --- | --- | --- |
| **The rule** | Two standing rules for how the company is paid, moves or holds together | Every day on the map |
| **The order** | One order, once a battle, that no other people's company can give | Every battle |
| **The story** | Five chapters across the campaign, ending in an office no crown gives | Days 1 to about 90 |
| **The home** | The camp, the capital, the customs of the captains | Home, Warband, the memorial |

## Rules that keep it honest

- **Sideways, never up.** A rule that gives something takes something. Credit comes with
  favours owed; a vow's reward comes with a risk the player chose.
- **The company, not the troops.** Rules attach to `GameState.culture` (the people you began
  as), never to a squad's culture. A Vardish company's hired Faris get no Kharzani rule; a
  Kharzani company's hired Footmen do.
- **The free game gets the system too.** The battle order is a system all three peoples
  have; the Vardish get theirs in the free game (below). No screen in a Vardish campaign
  shows an empty slot where a paid thing would be.
- **Nothing softens the death roll.** No rule changes a captain's odds of dying, heals
  faster, or brings anyone back.
- **Saves still load without the purchase**, with every rule working. Only *Begin* is gated.

## The Kharzani: a company on horseback and on credit

The idea in a sentence: the Vardish are paid by lords; the Kharzani are financed by a
merchant house, and their war is fast, mounted, and has to pay.

### The rule, first half: the house's ledger

The house of Darvani (already the opening's creditor) becomes a standing presence: a
**Ledger** card on Khalun's sheet, and a row in the journal.

- **Credit.** Borrow up to `100 + 2 × renown` silver (at most 800) at any time you stand in
  Khalun. One part in ten is added every ten days. No other people can borrow: when a
  Vardish purse is empty, men desert.
- **Favours instead of threats.** A payment missed becomes a favour: an unpaid job from the
  existing templates (`jobs.gd`: a hunt, a dispatch, a relief) in the journal, with the
  house's name on it. Three favours left undone and the ledger closes for the campaign,
  with −10 standing in Kharzan. The house never takes men, captains or gear.
- **Caravan stakes.** At Khalun, buy a stake (100 to 300 silver, two at a time) in a
  caravan to a named town or castle. The caravan is a party on the map that walks the road
  in its own time. It pays a third to a half over the stake on arrival, more for distance.
  Bandits and enemy lords go for it as they go for a raider; if it is taken, the stake is
  gone. Ride with it and an attack on it is your battle, fought as a column defence (the
  ambush objective's deployment, with the wagons where the village square would be).
  Routes into a realm at war with Kharzan are closed, so **the Kharzani player wants
  peace on the roads** in a way no other company does.

The decision it creates: borrow to hire the sixth company now and owe the house a month of
favours, or stay small. Stake silver on the Qasr Hamra road and ride with it, or take the
Sultan's contract and leave the caravan to its luck.

Hooks: `GameState.ledger` (saved, additive); a `CARAVAN` party kind in `world_sim.gd`
beside lords and bands, with a sprite in `tools/map_sprites.py`; `commitments()` rows;
`settlement_screen.gd` card. Size: **large**, mostly the caravan as a party.

### The rule, second half: the razzia

- **Drive off the herds.** A Kharzani company with two or more companies of horse has a
  second way to raid (`raid_village`): two hours rather than six, 60 silver and 60 rations
  rather than 150 and 40, and **the village does not burn**: it still pays its realm,
  still offers recruits, the realm thinks −4 of you rather than −10, and Honorable lords
  under your crown don't mind. The fast, light raid that feeds a moving company, against
  the slow one that hurts a realm.
- **The first roster rides.** Foot, spears, bows, horse, horse (as the earlier plan). The
  existing pace rule (`WorldSim.pace`: horse raise it) already makes this company quicker
  on the road and dearer to pay; nothing new is needed for that.

Size: **small**.

### The order: feigned flight

Once a battle, for one company of horse or javelin foot: it turns and runs for your edge as
if broken, standard dipping. An enemy squad fighting it or within reach gives chase if its
commander is Reckless or Hammer (a Patient one holds, and the scouts' word on the commander
at deployment is how the player knows). A squad that chases loses its brace and its line.
After six seconds, or on a second tap, the company wheels, and its next charge lands as a
flank charge.

The price: while it runs, blows on it land as rear blows, and it cannot be recalled early
without losing the charge. Called against a Patient commander, it is six seconds wasted.

Hooks: a new order beside `order_hold` / `order_advance` in `battle_sim.gd`; a pursuit
state in `commander_ai.gd`; one button in the tray. Size: **medium**.

### The story: *The Debt of Khalun*

Five chapters, authored like the romance routes (`romance_stories.gd`, read in `TalkView`),
each opening on a day and a place, with a journal row between.

1. **The Debt.** Day 1, the caravanserai yard. Six hundred silver in sixty days, or the
   first favour. (The earlier plan's opening, kept.)
2. **The House's Road.** The house asks you to see its own caravan to Qasr Hamra. Teaches
   stakes and the column defence.
3. **Two Ledgers.** The house is also lending to an emir who speaks against the Sultan
   (picked at setup: the Kharzani lord who thinks least of his ruler, which the lords'
   News already tracks). Tell the Sultan (standing up, the credit limit halves), keep the
   house's secret (the limit doubles, and it is remembered), or tell the emir you know (his
   Regard, and a dangerous friend).
4. **The Reckoning.** What chapter 3 set in motion comes due on the road: a battle against
   the emir's host beside the Sultan's men, a duel with his champion, or his pardon bought.
   Uses the existing lord battles, duels and Regard as one scripted encounter; rebellion
   inside a realm as a rule of the world stays out of scope.
5. **The Seal.** The ending, one of two, by what you chose:
   - **Vizier of Kharzan.** Without a crown of your own, you hold the Sultan's seal: call
     the Sultan's banners and sit at the head of his war council (the crown's *Court* tab,
     for a realm you serve), speak for Kharzan in war and peace, and draw a daily stipend
     from its treasury. Lost if your standing falls below 20.
   - **Partner of the house.** Every caravan in Kharzan pays you a share; the ledger never
     closes; the Sultan's court keeps its distance.

Raising your own crown stays open, as for everyone.

Size: **large** (writing, and the office below).

### The home

- The camp at the fire as a caravanserai camp: horse lines, a striped awning, a brass
  coffee pot. Pixel art in code, the way `hall_scene.gd` draws the halls.
- The memorial in the Kharzani way: a cairn and a line of elegy spoken by the bonded
  friend, by temper.
- The painted Khalun plate (the earlier plan), when the illustration exists.
- **Name pools brought to the Vardish count.** `cultures.gd` gives the Vardish 39 first
  names and 14 origins, the Kharzani and Ryumon 19 and 8. A long paid campaign would start
  repeating names; this is a small, necessary fix.
- Deeds: *the Sand-Riders*, *the Sultan's Own* (earlier plan), and *the Ledger Closed*
  (repay the house and see five caravans home).

## The Ryumon: a company bound by its word, sent across the water

The idea in a sentence: the Vardish are a company of hired men; the Ryumon are houses of
retainers under a writ, and what they swear is what they are.

### The rule, first half: vows

While deploying, a Ryumon company may swear **one vow** for the battle. Optional, every
time.

| Vow | Kept when | Kept: | Broken: |
| --- | --- | --- | --- |
| **Not one step** | You win and no company of yours broke; Retreat is closed | +5 renown, half again the experience | Every company starts the next battle 10 morale down |
| **The captains before the men** | You win; captains stand in the front rank and go down more easily | +10 morale all battle, a bond point for every pair | The same shame |
| **Take him alive** (a chief or a lord) | He is taken, not slain | Capture is certain if his guard breaks to your men; Honorable lords +3 | He is slain or escapes: the shame |

And one for the road, sworn at Kurogane: **No fire, no flight** for twenty days (no raid,
no withdrawal from a fight you could have fought). Kept: Regard with every Honorable lord,
who hear of it the way they hear of a lord kept in chains today.

Rewards are renown, experience and Regard, never silver or strength. The Warband gains a
card, *The company's word*, counting vows kept and broken.

The decision it creates: before every fight, how sure are you? The scouts' report already
says Even, Hard or Deadly; the vow is the player betting on their own reading of it.

Hooks: `pending_battle["vow"]`; the facts it needs (who broke, whether Retreat was used,
the leader's fate) are already in the battle result; a row on the deployment screen in
`battle_screen.gd`. Size: **medium**.

### The rule, second half: houses of retainers

- **Every captain has a house, and one heir.** A Ryumon captain carries a family name and
  a named heir at home. When the captain dies (the death roll unchanged), the heir takes
  the company at your next stop in a Ryumon town or castle, where today a nameless veteran
  steps up. The heir keeps the house's name, a memory of each of the fallen's bonds (so a
  B or A bond begins again one rank lower, not from nothing, with its own talk at the
  fire), and a **blood debt** to whoever killed their kin: the memorial already records
  `killed_by_lord_id`, and the heir's company holds its nerve better against that lord
  until it is settled. One heir to a house: when the heir falls too, the house ends, the
  memorial says so, and a stranger leads the company.
- **Rice, not silver.** Retainers draw three quarters of the silver wage and half again
  the rations, tuned to the same daily cost at town prices. They stand unpaid for two days
  before any leave (`Economy.DESERTION` waits); hungry, they leave as anyone does. The
  Ryumon company watches its granary where the Kharzani watches its purse.

This is the feature closest to the game's centre (captains who die and are remembered), and
it deepens the loss; it does not undo it. The one tuning question is whether an inherited
bond softens a death too much; if playtests say so, the heir starts with the memory and the
talk but no rank.

Hooks: `house` and `heir` on a captain (`captains.gd`, additive to saves); the succession
where a veteran takes over today; `_record_bond_loss`. Size: **medium–large**.

### The order: the challenge

Once a battle, before the lines meet: one of your captains rides out and calls the enemy
commander to single combat. The odds are shown first, from the same sum a duel with a lord
uses (`LordTalk.duel_chance`). Whether he comes is his bearing: Daring and Honorable lords
and Reckless chiefs accept; Cautious and Patient ones refuse, and nothing happens.

- Win: his army starts 20 morale down, and a chief goes to his own death roll.
- Lose: your captain goes to the death roll with no one near to drag them clear, and your
  army starts 15 down.

It risks exactly the thing the game is about, on the player's own call. The plate, the die
and the stamp are the death roll's own.

Hooks: a beat before `Fight` resolves in `battle_screen.gd`; the result feeds the existing
morale and fate code. Size: **medium**.

### The story: *The Writ Across the Strait*

1. **The Writ.** Day 1, the crossing. The writ names a mainland lord to be watched; find
   him and carry word home. (The earlier plan's opening, kept.)
2. **The Lighter Scale.** The Shogun's standing order: serve whichever mainland realm
   holds fewer seats (`Politics.MAINLAND_SEATS`). Under such a contract the Shogunate adds
   a rice stipend to the pay.
3. **The Guest.** A captive lord of the stronger realm is wanted in Kurogane as a "guest".
   Send him (a new line among the captive's choices), ransom him, or release him for
   honour. Duty against the company's word, and the first time a vow and the writ can pull
   apart.
4. **The Landing.** When the Shogunate goes to war for the balance (the existing
   `_evaluate_balance_of_power`), you are asked to lead the landing: choose the lane, and
   storm the first mainland castle with a marshal's army beside you. Existing sieges and
   allied armies.
5. **The Deputy.** The ending, one of two:
   - **Kanrei of the mainland.** Every mainland seat the Shogunate takes is yours to govern
     in its name: the crown's *Holdings* and *Lords* tabs for those seats, a share of
     their dues, daimyo to grant them to. Lost if your standing falls below 20.
   - **The torn writ.** Keep the castle for yourself. The company is masterless: vows pay
     double renown, the rice stipend ends, and every Ryumon lord thinks −20 of you.

### The home

- **The company's ships.** A Ryumon company sails the three sea lanes at road speed
  (`SEA_SPEED` up to `LAND_SPEED` for the player's party only). Small, and it makes the
  strait a road for the one people whose story is crossing it.
- The camp behind a curtain painted with the company's mark, banners at the corners.
- The memorial in the Ryumon way: a stone lantern for each of the fallen, and a death poem
  of two lines by temper.
- The painted Kurogane plate; the name pools fix as above.
- Deeds: *the Strait-Crossers*, *the Unbroken Line* (earlier plan), and *the Kept Word*
  (keep ten vows).

## What the Vardish get, free

So the free game has every system and nobody plays the "lesser" people:

- **Their order: rally to the banner.** Once a battle, every company near your first
  company's standard regains 25 morale, and wavering ones steady. Plain, strong, and in
  keeping with a people of shield walls. Ships with the order system.
- **Their roster and their home** stay as they are; the name pools are already full.
- **No rule and no story.** The Vardish campaign is the baseline the other two are measured
  against, and the crown is its ending. This is the line between free and paid, and it
  is a clean one: *the free game is complete; a paid people is a second way to play it.*

## One piece of shared plumbing: the office

Both paid endings are "rule a realm without wearing its crown". Build it once:

- `GameState.office = {realm, kind}`, saved, set by a story's last chapter.
- `kingdom_screen.gd` and `crown_court.gd` already take the crown's realm; an office opens
  a named subset of their tabs for the realm you serve (Vizier: Court and Diplomacy; Kanrei:
  Holdings and Lords for mainland seats).
- The journal shows the office and what would lose it.

Size: **medium**, and the reason both stories can end in something the player *does*,
not a card that says "The End".

## What the People sheet can now say

```
WHAT YOU GET
◆ A company financed by the house of Darvani: credit, favours, caravans
◆ The swift raid: feed the company without burning a village
◆ Feigned flight, an order only your riders know
◆ The Debt of Khalun: five chapters, and the Sultan's seal at the end
◆ Your own camp, memorial and three deeds
```

```
WHAT YOU GET
◆ Vows: stake the company's word before a battle
◆ Houses of retainers: when a captain falls, their heir rides in
◆ The challenge: call their commander out before the lines meet
◆ The Writ Across the Strait: five chapters, and the mainland to govern
◆ Your own ships, camp, memorial and three deeds
```

Every line is something the player does, and none is a number.

## Order of work and sizes

1. **`scripts/data/peoples.gd` and the order system**, with all three orders and the
   Vardish rally. Medium. The culture balance gate runs with orders on and has to hold.
2. **Ryumon vows and houses.** Medium–large. Built first of the two rules because they
   touch only the battle result and the captains, which are well tested.
3. **Kharzani razzia, then the ledger and caravans.** Small, then large.
4. **The office.** Medium.
5. **The two stories.** Large each, mostly writing. Chapter 1 of each is the earlier
   plan's opening and can ship ahead of the rest.
6. **The homes**: camps, memorials, name pools, deeds. Small–medium, pixel art only.
7. The plates, when painted.

**What can be cut and still be worth the price:** the story from five chapters to three
(1, 3 and 5), and the caravans down to stakes that resolve unseen. **What cannot:** the two
rules and the order. Without those, it is the coat again.

**When to sell:** not before a people has its rules, its order, and its story through to
an ending. Selling on the opening alone and promising the rest is how a $3.99 pack earns
one-star reviews.

## Files

| File | Change |
| --- | --- |
| `scripts/data/peoples.gd` | New. Per people: roster, order, rules and their numbers. The one place to tune. |
| `scripts/data/people_stories.gd` | New. The two stories, in the romance routes' shape. |
| `scripts/data/cultures.gd` | Name pools to parity. |
| `scripts/data/captains.gd` | `house`, `heir`; death poems and elegies. |
| `scripts/data/achievements.gd` | `people` field; six deeds. |
| `scripts/game_state.gd` | `ledger`, `vows`, `office`; succession by heir; the swift raid; save additive. |
| `scripts/world/world_sim.gd` | Caravan parties; the player's sea pace. |
| `scripts/battle/battle_sim.gd`, `commander_ai.gd` | The three orders; pursuit of a feigned flight. |
| `scripts/battle/battle_screen.gd` | The order's button; the vow row; the challenge beat. |
| `scripts/world/kingdom_screen.gd`, `crown_court.gd` | Tabs opened by an office. |
| `scripts/world/settlement_screen.gd` | The Ledger card; the heir's arrival. |
| `scripts/menu/main_menu.gd` | The company's word; camp and memorial by people. |
| `tools/map_sprites.py` | The caravan. |
| `docs/paid-features-plan.md` | Packages C and D point here; the sheet's lines. |

## Tests

A `tests/peoples_tests.gd`, and the balance gates:

- each rule is live only in a campaign of its people, whatever the squads' cultures, and
  works in a loaded save with nothing owned;
- the ledger: the limit by renown, the tenth every ten days, a missed payment becomes a
  favour, three undone close it; silver is conserved (borrowed + earned = spent + held +
  repaid);
- a caravan pays on arrival, is lost when taken, never spawns on a closed route, and its
  party round-trips through a save;
- the swift raid leaves the village unburned, paying and recruiting;
- each vow is kept and broken by exactly the facts in the battle result; no vow changes a
  death roll;
- an heir takes the company once, with the house's name and the blood debt; a second
  death ends the house; captains with heirs round-trip, and an old save gains none;
- feigned flight draws a Reckless and a Hammer commander and not a Patient one; the
  challenge's odds are the duel's; both orders once a battle;
- an office opens its tabs and no others, and is lost at the standing it names;
- **`Plans.campaign` for each people** ends the thirty days within the existing bands, with
  debt counted against silver; **the culture balance gate** (`--balance`) holds with each
  people's order used by the tactician and unused by *Advance all*.

## Decisions for the user

- **Whether the Vardish get an office too** (Lord Marshal of Vardmark, by the vassal's
  road, with no story). My recommendation: not at launch. It blurs the clean line above,
  and it is cheap to add later if free players ask for it.
- **Inherited bonds for a Ryumon heir**: one rank lower (recommended) or none.
- **Caravans seen on the map** (recommended: they are the Kharzani's reason to care where
  the bandits are) or resolved unseen, which halves that package.
- **Price.** With this in each, $3.99 a people holds up, and the $5.99 pair is the easy
  choice. If only the cut-down version ships, $2.99 a people is the honest tier.
