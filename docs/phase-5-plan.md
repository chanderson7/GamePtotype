# Phase 5: Captains & Men

The warband becomes a company of living people rather than disposable numbers.
Troops cut down in battle aren't all buried where they fell: wounded soldiers travel
in the baggage train and mend over days on the road or in camp, saving silver and
protecting veteran experience. Captains who survive the crucible of battle earn
reputation and choose a company specialization—Scout, Quartermaster, Drillmaster,
or Champion. Unique wandering heroes can be found and recruited in taverns across the
Glass Sea. A dedicated Casual Mode offers an accessible journey where captains are
severely wounded rather than permanently slain.

---

## Workstreams

| | Workstream | Scope | Focus |
|---|---|---|---|
| **5.1** | **Recoverable Troop Casualties & Healing** | ~1 week | Split casualties into killed vs wounded, squad `wounded` tracking, natural daily healing, camp rest healing boost, and preserving troop XP. |
| **5.2** | **Casual Mode Campaign Option** | ~3 days | Toggle in Settings and campaign creation. Failed death rolls severely wound captains (scarred injury, sit out 3 battles) instead of permanent mortality. |
| **5.3** | **Captain Specializations & Promotions** | ~1 week | Veteran milestones (battles/kills) unlock earned specialization tracks: Scout, Quartermaster, Drillmaster, Champion. Profile display & campaign effects. |
| **5.4** | **Unique Named Heroes (Companions)** | ~1 week | Three authored wanderers (Katherine of the Pale, Tariq Windrunner, Mori the Unbroken) with distinct portraits, backstories, and unique traits in taverns. |
| **5.5** | **Bond Vignettes & Integration Polish** | ~1 week | Interactive camp bond reflections for C, B, A pairs, Warband UI integration, phone layout polish, and full test suite verification. |

---

## 5.1 Recoverable Troop Casualties & Healing

### Design
- In tactical battles and auto-resolve, troop losses are divided into **Killed** (50%) and **Wounded** (50%).
- Wounded soldiers are recorded on each squad as `squad["wounded"]`.
- Wounded soldiers consume rations (they must be fed) and earn wages, but cannot fight until recovered.
- On the road, wounded men recover naturally at a rate of 1 man per squad every 12 hours.
- While resting (waiting in a settlement or company camp), recovery speed doubles (1 man per squad every 6 hours).
- Recovered troops return directly to `squad["men"]` with their earned veterancy level and experience intact, avoiding the dilution penalty of hiring raw recruits in town.

### Verification
- Tested in `tests/casualty_and_healing_tests.gd`: battle splits, natural healing ticks, camp acceleration, and save/load persistence.

---

## 5.2 Casual Mode Campaign Setting

### Design
- An explicit setting toggle in Settings and New Campaign: **Mode: Iron Company (Default)** vs **Mode: Casual**.
- In **Iron Company**: Captains who roll at or below the death roll die permanently, their memory etched into the Memorial.
- In **Casual Mode**: Captains who fail the death roll are severely injured rather than killed. They sit out 3 battles (`wounded = 3`) and gain a lasting injury scar in their history.
- Regular squad soldiers still suffer casualties and recover under normal rules in both modes.

### Verification
- Tested in `tests/casual_mode_tests.gd`: death roll interception, wound duration, history logging, and setting persistence across save/load.

---

## 5.3 Captain Specializations & Promotions

### Design
- Captains who lead their company through 5 battles or achieve 15 kills earn **Veteran Promotion**.
- The player selects one specialization on the Captain Profile:
  1. **Scout**: +25% map sighting distance, reveals exact enemy strength before road intercept, reduces ambush chance by 50%.
  2. **Quartermaster**: -20% daily food consumption, +15% silver and food spoils from battle, halves desertion risk when supplies run low.
  3. **Drillmaster**: +25% squad combat experience gain, reduces XP dilution from fresh recruits in town by 50%.
  4. **Champion**: +15% squad melee damage and charge impact, captain gains +25% max HP and +10 base morale shock resistance.
- Active specialization is badged on the Warband card and Captain Profile.

### Verification
- Tested in `tests/captain_development_tests.gd`: promotion qualification, selection, campaign bonuses, and save/load persistence.

---

## 5.4 Unique Named Heroes (Companions)

### Design
- Three unique legendary wanderers appear in town taverns across the Glass Sea:
  1. **Sir Katherine of the Pale** (Vardish Knight, Highcliff): Exiled knight of House Dunmere; *Steadfast*, *Drillmaster*, unique plate armor portrait.
  2. **Tariq Windrunner** (Kharzani Faris, Khalun): Desert scout and outcast; *Lucky*, *Scout*, unique turban and faris mail portrait.
  3. **Mori the Unbroken** (Ryumon Ronin, Kurogane): Masterless swordsman; *Vengeful*, *Champion*, unique scarred hatamoto portrait.
- Unique dialogue on meeting, bespoke hire cost, and permanent presence in company history.

### Verification
- Tested in `tests/hero_companion_tests.gd`: tavern spawning, recruitment, uniqueness enforcement, and save/load persistence.

---

## 5.5 Bond Vignettes & Polish

### Design
- When captain pairs achieve rank C, B, or A bonds, a short thematic reflection vignette unlocks on the Warband / Profile screen.
- Camp reflects wounded captains resting in tents, active captains training, and bond partners conversing.
- Phone UI polish across all screen sizes with text-scaling and accessibility support.
