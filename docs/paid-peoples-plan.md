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
| **The look** | The people's court, captains and commanders drawn a tier above | Every talk, every card, every battle |
| **The war** | A different war at home, troops and roads only that company has | The whole campaign |

The first four are the supporting layer. After review (2026-11-11) they were judged too
small to carry a price on their own, and they are: none of them can be seen in a
screenshot. **The look** and **the war**, below the two peoples' sections, are the
headline of each pack.

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

## The look: a people drawn a tier above

Where the art stands today, from `captain_face.gd`, `lord_voice.gd`, `tools/unit_sprites.py`
and `battle_sim.gd`:

- every captain **and every lord and ruler** is the same generated 60×80 pixel bust; a lord
  differs by a circlet and his house's colours (`LordVoice.portrait_record`);
- only Edda, Farah and Kaede are painted, with five expressions each;
- in battle a captain is one of his men with a gold ring, and a lord is a flag on a squad
  (`is_lord`): the Sultan on the field looks like an Askari;
- **the player has no face and no name.** In a talk it is their portrait against your banner.

One rule for all of it, simple enough to put on the People sheet:

> **Owning a people changes how that people is drawn in every campaign you play.**

A Vardish campaign on a phone that owns the Kharzani meets painted emirs; without it, the
pixel busts of today. Nothing is missing for the player who has not paid, and the purchase
shows on every screen for the one who has. (This amends the paid plan's never list by one
line: the shared world's *content* is never locked, its *finer art* may be.)

### L1. A painted court

The ruler and the heads of the realm's six houses, painted as the romance cast is: a bust
at 384×512 in three expressions (level, pleased, angered), used wherever a lord's face is
shown: the road talk, the hall, People → Lords, the war council, the wedding's guests.

This needs the court to be **authored, not rolled**. Today `_spawn_lords` draws a first
name and a house at random each campaign, so a painting cannot belong to anyone. For a
people with a painted court, the ruler and four lords are fixed by name, house and bearing,
each with a named heir (the heir's painting waits for the death). The names and bearings
ship to everyone; the paintings to owners.

- Per people: 7 heads and 6 heirs, 13 faces, 39 images. Start with the ruler and the four
  riding lords (15 images) and add heirs after.
- The Sultan and the Shogun also get what Edda has and no lord has: a painted room of their
  own (the divan at Khalun, the audience hall at Kurogane) and lines written for them
  alone, not a bearing's shared lines.
- Art: the external illustration workflow the portraits used; briefs go in a
  `assets/court-art-manifest.md` beside the two that exist. Size: **large**, and it is not
  code.

### L2. Captains in full harness

The generated face stays, because it carries the captain's life (scars, grey, the bandage,
the role's token) and a painting cannot. For a paid people the generator draws **more of
the captain**: a half-figure at 96×128 for the profile, the death roll, the fire and the
memorial, with the 60×80 bust cut from it for cards.

- **Armour that is earned.** Three sets by training level and a fourth at twenty battles.
  Kharzani: quilted coat and turban; mail and a pointed helm with an aventail; gilded
  lamellar; a plume and a cloak of the Sultan's colour. Ryumon: a lacquered hat and a
  simple cuirass; full armour with shoulder guards; the great armour with a face guard; a
  horned crest and a surcoat.
- **The house's mark.** Each of the realm's six houses gets a device (a Ryumon crest, a
  Kharzani emblem) drawn by `heraldry.gd`: on its lord's banner, his men's back-flags and
  shields, his map party, behind his portrait. A company of that people **makes its own
  mark** from parts on the Warband, and its men carry it into battle.
- A weapon in hand by troop, and the temper in the stance.

All of it is drawn in code, so it can be built and reviewed here on mockup sheets, as the
current faces were. Size: **medium–large**.

### L3. Commanders on the field

A captain and a lord become figures you can find in a battle at a glance.

- **A captain's party** in every company of a paid people: the captain a head taller in
  his own armour set, a standard-bearer with the company's mark, and a musician (a
  kettledrummer, a conch-blower). When the captain goes down, the standard dips.
- **A lord's retinue.** An emir rides under a parasol with a kettledrum camel behind him. A
  daimyo sits on a stool behind a painted curtain with a war fan, his great standard beside
  him, and mounts only when his guard is committed. The Sultan and the Shogun each have a
  figure of their own. When a lord falls, the great standard falls, and that is the moment
  the callout stamps on.
- On the map, the same lord's party carries his house's mark and the parasol or the great
  standard, so the man you talked to is the man you see riding.

Presentation only: the same seeded battle ends the same (`tests/battle_feel_tests.gd`
already holds that line). Drawn in `tools/unit_sprites.py` and `tools/map_sprites.py`.
Size: **medium**.

### L4. You, drawn

The largest gap in the game's cast is the player. Give the company a **commander**: a name
and a face made at the start (the generator's parts, chosen or re-rolled), in the people's
dress, who stands opposite a lord in a talk where your banner stands alone today, is one of
the two at the wedding, sits at the fire with the captains, and wears the crown or the seal
when one is won.

This belongs to all three peoples (a Vardish commander in the free game, in today's bust),
and each paid people's commander is drawn in the full harness of L2. It is the one item
here that changes the free game most, so it is listed as a decision below. Size: **large**
(it touches every talk screen).

## The war: a different campaign, not a different start

### W1. A different war at home

Every campaign today opens on the same world: Vardmark and Kharzan at war, Ryumon watching
(`WorldData.WARS`). `WorldSim.setup` already takes the player's people; let it set the
stage.

- **Kharzani: the Two Heirs.** Sultan Rustam dies inside the first twenty days. His two
  heirs each hold part of the realm (Khalun and Qal'at Zeyra against Qasr Hamra and its
  villages), each with two emirs, and Vardmark's war goes on over both their heads. You
  serve one, play them against each other, or take the seal for yourself. The house of
  Darvani has lent to both, which is what *The Debt of Khalun* is then about.
- **Ryumon: the Empty Seat.** The Shogun sends the realm's host across the strait (the
  balance-of-power war, brought forward), and with the army away a great house rises at
  home. You carry the writ on the mainland while Kurogane is under threat behind you: go
  back, or finish the Shogun's war first.

Both need one new rule of the world, which `NEXT.md` already lists as owed: **a realm can
split** (a second faction of the same culture holding some of its seats, at war with the
first, rejoined when one side holds the capital and the other's ruler is taken). Built
once, it serves both packs, and later rebellions anywhere in the free game.

This is the feature a review would mention. Size: **large**.

### W2. Household troops

Each people's company can raise one kind of troop no one else can hire, at its capital,
once its story's second chapter is done. One company at a time.

- **Kharzani: the camel corps.** Slower than horse and no charge; enemy horse within reach
  lose their charge and their nerve. The answer to knights.
- **Ryumon: fire-lances.** A volley that shakes a whole company's nerve and punches
  through armour, then a long reload in which they are helpless. Useless in rain (W4).
- **Vardish, free: the banner guard.** Men-at-arms who cannot rout while the company's
  standard stands.

Sideways by the same gates as the troop trees: "neither branch of a role outclasses the
other" in `--balance` extends to these. This is a second amendment to the never list
(nothing existing is locked; these are new, and every people has one). Size: **medium**
each, with sprites.

### W3. Roads only that company can take

- **Ryumon: open water.** The company keeps ships. Not three lanes but the whole Glass Sea:
  sail from any Ryumon harbour and land on any shore beside a village, which makes every
  coastal village on the mainland reachable in a night. A band of Wako met at sea is fought
  on a deck: a narrow field with no flanks and no horse.
- **Kharzani: the desert tracks.** Caravan tracks across the Red Wastes that only a
  Kharzani company knows: direct ways between places the roads go round (Qal'at Zeyra to
  Qasr Hamra; Dar Nakhla to Nahrabad's far side), at a cost in water (double rations for
  the crossing).

The map graph (`WorldData.ROADS`) gains edges with a `people` tag; open water is the larger
piece (a sea-pathing layer and a deck field in `battle_site.gd`). Size: **medium**
(tracks), **large** (open water).

### W4. Their land's weather, their walls, their engines

- **Weather by land.** Sandstorm in Kharzan (bow range cut by a third, dust over the far
  half of the field), rain on the isles (mud slows horse, no fire-lances, arrows fall
  short), fog in Vardmark at dawn. Shared by every campaign and every people: it makes the
  two paid homelands feel like places, and it is free.
- **Sieges by people.** `NEXT.md` lists siege engines as owed. Give each people its own:
  Kharzani sappers (a mine under the wall: slow, then a breach where *you* choose),
  Ryumon fire arrows (the garrison's cover burns; the gate does not), Vardish trebuchets
  (free: the gate's bar drops before the assault). Walls drawn by who built them: Kharzani
  towers and a double gate, a Ryumon castle's two baileys to take one after the other.

Size: **medium** (weather), **large** (engines and walls).

### W5. Someone who rides with you

A painted character per people who carries its story and lives in your camp, with the
five expressions and the talk screen the romance cast has: the house of Darvani's factor,
who keeps your ledger and has her own view of what you borrow; the Shogun's inspector, sent
to watch the company that carries his writ. Each has a say at the fire after a battle, a
bond that is not a romance, and a part in how the story ends. Size: **medium**, plus one
painted cast member each.

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
◆ The Sultan's court, painted: every emir, in every campaign you play
◆ Captains in full harness, and emirs under their parasols on the field
◆ The Two Heirs: a succession war in your own homeland
◆ The camel corps, and the desert tracks no one else can ride
◆ A company on credit: the house of Darvani, its caravans, its factor
◆ Feigned flight, the swift raid, and the Sultan's seal at the end
```

```
WHAT YOU GET
◆ The Shogun's court, painted: every daimyo, in every campaign you play
◆ Captains in the great armour, under a mark you make yourself
◆ The Empty Seat: a rising at home while you carry the writ abroad
◆ Fire-lances, and ships that land on any shore
◆ Houses of retainers: when a captain falls, their heir rides in
◆ Vows, the challenge, and the mainland to govern at the end
```

The first two lines of each are what a screenshot shows; the middle two are what a review
describes; the last two are what the player is still doing in week three.

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

The look and the war, in the order I would build them:

8. **L3 commanders on the field and L2 captains in full harness.** Code-drawn, so they can
   start now and be judged on mockup sheets. The cheapest things here that a player sees
   in the first minute.
9. **The realm that splits, then W1 for each people.** The largest single piece, and the one
   that makes the campaign different, not only the company.
10. **L1 the painted court**, in step with 9, since the two heirs and the rising house are
    its first faces. Paced by the illustration workflow, not by code.
11. **W2 household troops and W3 the desert tracks.** Medium each.
12. **W5 the companion**, with the stories (5), since she or he speaks them.
13. **W4 weather**, free for everyone. Then engines and walls, then open water: the two
    largest, and the two a pack can ship without.
14. **L4 the commander**, if wanted: a base-game feature on its own schedule.

**What a pack is, at three sizes:**

| Size | Contains | Honest price |
| --- | --- | --- |
| **Small** | The rules, the order, a three-chapter story, the home | $2.99 |
| **Full** (recommended) | Small, plus L2, L3, W1, W2, the desert tracks or sea lanes at speed, the five-chapter story with its companion, and the ruler and four lords of L1 | $4.99 a people, $7.99 the pair |
| **Grand** | Full, plus the whole painted court with heirs, sieges by people, open water | $6.99 a people, or Full now and the rest as a free update to owners |

**What cannot be cut from any size:** the two rules and the order. Without those, it is
the coat again, however well painted.

**When to sell:** not before a people has its rules, its order, its look on the field (L2,
L3) and its story through to an ending. Selling on the opening alone and promising the rest
is how a pack earns one-star reviews.

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
| `tools/map_sprites.py` | The caravan; lords' parties with their mark, parasol or great standard. |
| `scripts/art/captain_face.gd` | The half-figure, armour sets by level, the weapon in hand (L2). |
| `scripts/ui/heraldry.gd` | House devices; the company's own mark and its maker (L2). |
| `tools/unit_sprites.py`, `scripts/art/unit_art.gd` | Captain's parties, lords' retinues, household troops (L3, W2). |
| `scripts/data/lords.gd`, `scripts/data/lord_voice.gd` | An authored court per painted people; painted portraits where owned (L1). |
| `scripts/world/world_data.gd`, `world_sim.gd` | A realm that splits; the opening war by people; roads tagged by people (W1, W3). |
| `scripts/battle/battle_site.gd`, `terrain_rules.gd` | Weather; the deck field; walls by builder (W3, W4). |
| `assets/court-art-manifest.md` | New. Briefs and records for the painted courts and companions. |
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
- **Price and size.** See the three sizes above. My recommendation is Full at $4.99 a
  people, with the Grand pieces following as free updates to owners.
- **Art by ownership.** Whether owning a people upgrades how it is drawn in every campaign
  (recommended: the purchase is seen everywhere and nothing playable is withheld), or the
  better art ships to everyone and only *beginning* as the people is sold.
- **An authored court.** L1 fixes the ruler's four lords by name and bearing in every
  campaign, where today they are rolled. Recommended for the two paid realms; Vardmark can
  follow.
- **Household troops** amend "no people-locked troops". Recommended, since every people
  gets one and nothing existing is locked; say no and W2 goes.
- **The commander (L4).** A face and a name for the player, in the free game too.
  Recommended, but as its own feature after the packs: it touches every talk screen.
