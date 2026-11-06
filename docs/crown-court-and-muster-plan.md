# Ruling from anywhere: the king's court, gatherings with a purpose, and calling the banners

A plan, not yet built. Mockups drawn in the kingdom screen's own style:
`mockups/crown-court-tab.png` (a Court tab: hold a gathering), `mockups/crown-call-the-banners.png` (the muster card and petitions)
and `mockups/crown-war-council.png` (the war council at a muster).

## 1. What's there now

**Gatherings** (`gatherings-plan.md`, built): realms hold feasts and dances; you're invited
when you've earned it; at one you have a first word with each lord, a toast, a gift, the
gossip, and a dance. **With a crown you can host one**, but only:

- from the **Fief tab of your seat**, standing in it (`settlement_screen._add_host_card`);
- a **feast or a dance**, at the seat, once every 20 days, 300 silver and 200 rations;
- for your sworn lords plus lords who like you, lords you're winning over, and their
  lieges (`GameState.host_invitees`, `host_gathering`);
- with no enemy army within two days and no siege; you don't have to be at peace.

As host you do nothing a guest can't: the same first words, toast, gossip and dance. There
is no reason to hold one beyond +5 Regard a head and a persuasion bonus.

**War** (`kingdom-plan.md`, built): the Crown screen's Diplomacy tab has a **call to arms**:
if two sworn lords are "ready" (70% strength, not on the 3-day cooldown) they gather at
your capital and march on the enemy castle or town you name, led by one of them as marshal
(`MarshalArmies.create`); you can ride with the army from its sheet on the map. The Lords
tab lets you order one lord at a time to *ride with you*, *hold a place*, or go free.

What that leaves out, as a king:

1. You can't call anything from the road. Hosting needs you at the seat; war needs the
   Crown screen but gives you no say in who comes, where they meet, or when.
2. The call to arms is fire-and-forget: two lords, your capital, one siege target, a
   lord in command. There's no *muster* (everyone, to a place, by a day), no *council*
   (the aim decided with your lords in the room), no choice to lead it yourself except by
   ordering lords to follow you one by one.
3. Your lords never gather except to drink or to march. A king's court has no petitions,
   no seat of honour, no public grant, no speech.

## 2. The idea

Two things a crown should be able to do from anywhere, each ending in a hall full of your
lords:

- **Hold court**: call a feast, a dance or a tourney at any of your castles or towns, and
  use it: honour a lord, grant a fief before everyone, hear petitions, speak.
- **Call the banners**: summon every sworn lord to a muster at a place of yours by a
  day; when you arrive, a **war council** sits where the aim is set, the marshal named
  (you or a lord), and the host provisioned; then it marches.

Both live on a new **Court** tab of the Crown screen, reachable from the map menu wherever
you are. The seat's Fief tab keeps its host card as a shortcut to the same thing.

## 3. Holding court

### Calling a gathering (Court tab, "Hold a gathering")

- **Kind:** Feast, Dance (as now) or **Tourney** (new, below).
- **Where:** your seat, or any crown castle or town. A lord's seat means that lord hosts
  in your name: +5 Regard with him, and his hall's culture sets the room and the music.
- **When:** from the first dusk at least a day on, three nights, as now. You don't have
  to be there to call it. If you're not there on the first night, your lords drink
  without you: no first words, and −3 Regard with the lords you were winning over ("the
  king sent wine and no king").
- **Who:** the four groups as now (sworn, friends, persuade, lieges) with switches, and
  the reach stays two days' ride of the place.
- **Cost:** 300 silver, 200 rations; a tourney adds a 100-silver purse. Cooldown stays 20
  days, per crown.
- **Rules kept:** no enemy army within two days of the place, the place not besieged.

### The king's table (only at your own gathering)

Each is a card in the Court tab of the place while the gathering is on, beside the
existing first words, toast and gossip:

| Act | What it does | Limits |
|---|---|---|
| **Seat of honour** | Pick one lord to sit at your right: +8 Regard with him; lords of higher renown present lose 2 ("passed over") | Once per gathering |
| **Grant before everyone** | `grant_fief`, but public: +30 Regard with the lord (instead of +15), +3 with every other guest; the one who held it before loses 10 instead of 5 | Only a holding you have to give |
| **Hear petitions** | Each sworn lord with a trouble (the existing lord-trouble system) or a wish (a fief, a marriage of his daughter: wish list below) brings it. Settling it at table pays +5 Regard instead of +2 on the road; refusing publicly −5 | One each |
| **The king's speech** | Replaces the toast at your own table. Renown 120. +2 Regard with everyone there; if the crown is at war, +10 conviction toward the war with lords you're persuading, and sworn lords count as "ready" for the next muster regardless of strength | Once per gathering |
| **Gifts from the king** | 30 silver a head: +3 Regard with each guest | Once |

Wishes (new, small): a sworn lord without a fief wishes for one; a lord whose Regard is
under 0 wishes to be heard (a petition that just costs you an hour and gives +5); a lord
whose fief was raided wishes for a garrison (you station squads: +5). Three kinds, enough
to make a petition line real.

### The tourney (new kind)

A gathering's first day is the lists, then the feast as usual.

- **Who rides:** your captains (one from each company you choose, up to three) and one
  champion per lord present (generated from the lord's culture and renown, like a lord's
  warband captain).
- **How it's decided:** the existing duel rules, run as a bracket in auto-resolve with a
  short animated results strip (pixel faces, lances; no new battle mode). Each bout is a
  line: "Brann unhorses Lord Osric's champion at the second pass."
- **What it pays:** the winner's company +renown 10 for the company, +2 morale and a bond
  bump between that captain and his seconds; the winning lord's Regard +5; every lord who
  entered +2. The purse (100) goes to the winner's lord, or to your captain's pocket.
- **Risk:** a captain can be wounded (the duel's wound rules), never killed.
- **Crowd:** the town's prosperity +5 for a week (people came to watch).

## 4. Calling the banners

### The muster (Court tab, "Call the banners")

- **Where:** your seat or any crown castle or town. **When:** lords ride in within two
  days (reach as gatherings); the muster "stands" from then until you dismiss it or
  march.
- **Who answers:** every sworn lord who isn't a captive, besieged, or already under a
  *hold* order from you (those are named: "Bertram holds Thornwall by your order"). A
  bought lord with Regard below 0 may refuse (the existing unrest). A lord who could come
  and doesn't: −10 Regard, and his name on the list in red, which is your reason to take
  his fief back.
- **Cost:** the crown treasury feeds the muster: 1 ration per 10 men a day while it
  stands (the chip says "30 rations a day"). If the treasury runs dry, lords start going
  home after a day. No silver.
- **The map:** a red ring round the muster place (like the gatherings' lantern ring), lord
  plates say "riding to the muster", the journal has "Your banners gather at Highcliff ·
  3 of 5 there", and *Ride there*.
- **The old call to arms stays** as "send two lords on their own" at the foot of the card:
  the quick version when you don't mean to lead.

### The war council (when you arrive, or from the Court tab once two lords are there)

A full page in the kingdom screen (mockup 2):

- **Who's in the hall:** each lord with his men and one line in his voice from
  `LordVoice`, by temperament: a Cautious lord counsels patience, a Daring one the storm,
  a Greedy one the raid, an Honorable one objects to raiding. Lords still on the road are
  listed with their arrival.
- **The aim**, one of:
  - *Storm X*: an enemy castle or town (as the call to arms now), showing ride time and
    garrison;
  - *Relieve Y*: a crown holding under siege (disabled when none is);
  - *Hold the march*: the army patrols between two crown holdings for six days, meeting
    raiders and enemy lords that come near (new army state "patrol": the existing lord
    *guard* behaviour applied to an army, two anchors);
  - *Raid Z's villages*: the army raids the nearest two enemy villages (the AI already
    raids; this reuses it), Honorable lords −5 Regard and they say so first.
- **Who leads:** *You*, or the lord with the highest renown (a Daring lord offers). Led by
  you, the army is a marshal army whose leader is your party: it moves when you move,
  waits when you stop, and its lords join your battles and sieges exactly as *ride with
  me* lords do today (the follow order, applied to the whole army; `MarshalArmies.tick`
  skips its own marching for a player-led army). Led by a lord, it behaves as the call to
  arms does now and you may ride with it.
- **Provisions:** the treasury pays the expedition's rations up front (men × days ÷ 10);
  a paid army stays out for the full six days (`ARMY_EXPEDITION_HOURS`) instead of
  drifting home when its lords' purses run thin; an unpaid one marches anyway and comes
  home after three.
- **Regard:** +5 with each lord who rides, once per muster; the lords who spoke against
  the aim you chose −2 (they ride all the same unless Honorable and it's a raid).
- **Buttons:** *March!*, *Wait a day for X* (the council sits again tomorrow; the muster
  keeps eating), *Dismiss the banners* (lords go home; the 3-day army cooldown applies).

### While it's out

- The army's sheet on the map (existing) gains the aim, the days of provisions left, and
  for a player-led army a **Dismiss** button; for a lord-led one *Ride with them* as now.
- When the aim is met or the days run out, the army disbands with a map notice ("Your
  banners go home: Kurogane is yours" / "the march held; two raids turned back").
- A lord who leaves early (purse, unrest) is named.

## 5. Rules and numbers (one place)

`gatherings.gd`: `TOURNEY := "tourney"`, `TOURNEY_PURSE := 100`, `HONOUR_REGARD := 8`,
`PASSED_OVER := -2`, `PUBLIC_GRANT_REGARD := 30`, `PETITION_TABLE := 5`, `SPEECH_REGARD :=
2`, `SPEECH_CONVICTION := 10`, `KING_GIFT_SILVER := 30`, `KING_GIFT_REGARD := 3`,
`ABSENT_KING_REGARD := -3`.

`lords.gd`: `MUSTER_REACH_HOURS := 48.0`, `MUSTER_RATIONS_PER_10 := 1`, `MUSTER_REFUSED_REGARD
:= -10`, `MUSTER_RIDE_REGARD := 5`, `PATROL_HOURS := 144.0`, `UNPAID_HOURS := 72.0`.

Saves: `gs.muster = {place, called_hour, answering: [lord ids], refused: [ids], fed_until}`;
armies gain `aim` and `led_by_player`; a gathering gains `kind: "tourney"`, `host_lord`,
`honoured`, `speech_given`, `gifts_given`. All absent in old saves and read as none.

## 6. Tests

- Calling a gathering from the map at a lord's seat: it's called, he hosts, +5 Regard;
  missing the first night costs −3 with the persuade group and nothing with sworn lords.
- A tourney runs its bracket in auto-resolve, pays the winner, never kills a captain.
- Seat of honour, public grant, petitions, speech and gifts each pay what the table says,
  once.
- A muster: all free sworn lords ride to the place; a held lord stays; a captive is
  skipped; an absent lord loses 10; the treasury is debited daily and lords go home when
  it's empty.
- The council: each aim produces the right army state; led by you the army follows your
  party and its lords join your battle; led by a lord it marches as the call to arms does.
- Hold the march meets a raider between the anchors; a raid takes a village and costs
  Honorable lords' Regard.
- Old saves without `muster` or army `aim` load and behave as before.

## 7. Order of work

1. **The Court tab**, hosting from anywhere with a place picker, and the absent-king rule
   (small; reuses everything).
2. **The muster and war council** with *Storm* and *You lead* only; the quick call to arms
   kept. (The biggest new behaviour: a player-led marshal army.)
3. **Relieve, Hold the march, Raid**, provisions from the treasury.
4. **The king's table**: seat of honour, public grant, petitions and wishes, speech, gifts.
5. **The tourney.**

Each step: `kingdom_tests`, `crown_rule_tests`, `gathering_tests`, `lord_conversation_tests`
green, plus phone renders of the Court tab, the muster on the map and the council.
