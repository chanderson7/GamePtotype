# Playtest audit: six players, one build

**Status: findings, not fixes.** Six passes over the game as built at `044a9fa`, each from a
different player's seat: a first-time player, a tactician in battle, a long-game strategist,
a story-and-character player, an accessibility and desktop player, and a QA engineer looking
for what breaks. Each pass walked the screens and rules the way that player would meet them
and wrote down where the game got in the way, with the file and line that does it.

**How it was played.** The environment this audit ran in had no Godot binary and could not
download one, so every session was traced through the code rather than on a device: the
numbers are the game's own constants, the flows are the functions a tap calls, and every
claim quotes the line that makes it true. Nothing here is a guess about feel; where a pass
could not close a claim it is marked *unverified*. The first thing to do with this document
is to confirm the blockers on a phone (section 1), then run `-- --autoplay` and the suites in
`tests/` after each fix.

Severity: **blocker** (loses the player's progress or makes a path unwinnable), **major**
(a player will hit it and it will cost them a session's goodwill), **minor** (friction),
**polish**. Items already on `docs/game-feel-audit.md`, `docs/ui-simplification-plan.md` or
the roadmaps are not repeated.

## 1. Fix first

Ranked across all six players by how many of them hit it, times how much it costs.

| # | What | Who hits it | Where |
|---|---|---|---|
| 1 | Squads you station in a crown holding are lost from your control on the next load: the loader drops the `stationed_by_company` flag (and squad `wounded`). | Crowned players, every restart | `world_sim.gd:3478-3515` `clean_army`, `game_state.gd:1649-1658` |
| 2 | Swearing fealty empties your new castle's garrison, and declaring the crown empties the seat's; marshal armies target the emptiest walls and take a settlement with no men in it without a fight. | Every new vassal and every new crown | `game_state.gd:2341`, `:1344-1358`, `world_sim.gd:593-607`, `marshal_armies.gd` assault |
| 3 | A lord you beat in the field is back at full strength 24 hours later: casualties are only written back when you lose. Four wins buy the 200 renown the crown needs. | Anyone at war, from the first lord victory | `game_state.gd:3430-3431`, `:3903`, `world_sim.gd:2984-2990`, `:2840-2850`, `lords.gd:85` |
| 4 | Retreat from the pause menu is a free, guaranteed escape with no men lost, even when the map said you could not withdraw. Quitting is strictly better than routing. | Any losing player | `battle_screen.gd:1894-1903`, `battle_sim.gd:3693`, `:3740`, `world_sim.gd:3136-3143` |
| 5 | A squad on a march order never fights back; a drawn line in battle puts the whole army on march orders. | Anyone who swipes or taps ground mid-melee | `battle_sim.gd:2209`, `:2221-2224`, `:2857-2858`, `:1855` |
| 6 | A corrupt or unreadable autosave shows the first-time screen with no "Load a save"; the next tap starts a new campaign and deletes every slot save. | Returning players after a bad write | `game_state.gd:155-157`, `title.gd:108-110`, `:574-577`, `save_slots.gd:119-123` |
| 7 | The tutorial is off by default and nothing on the first-time Home says it exists; the first "Next step" tells a new player to spend 45% of their silver on a sixth squad. | Every new player | `new_campaign.gd:103`, `title.gd:128`, `game_state.gd:2554-2612` |
| 8 | Order buttons lose their words after three battles and keep only tooltips, which do not exist on touch; siege orders are glyphs the player saw labelled at most three times. | Everyone from battle four on | `battle_screen.gd:62`, `:544`, `:3983-3990`, `:1910-1917` |
| 9 | Only an iOS export preset exists, with a placeholder team id, empty versions and empty icons. No Android or desktop preset. | A store build | `export_presets.cfg:1-8`, `:33`, `:42-43`, `:213`, `:261` |
| 10 | Picking "We'll speak another time" at the first audience silently closes romance and friendship for that person for the whole campaign. | Story players, first audience | `romance_stories.gd:96`, `social_sim.gd:812-825`, `:647-654` |

## 2. The first-time player

What they inherit: 96 men, 400 silver and 480 rations. Wages come to 71 silver a day
(`economy.gd:21-26`, summed `game_state.gd:2532-2537`) and food about 19, so the purse is
five days deep and so is the larder. A bandit win pays about 470 silver, 88 rations and 21
renown (`economy.gd:38-42`; bands of 24 to 70 men, `world_sim.gd:1427,1457`). One win every
five days keeps the purse level; the food from a win never covers the men. Desertion is a
tenth of each squad a day when unpaid or hungry (`game_state.gd:2978-2987`). No hard
soft-lock was found, but the advice a broke player gets points the wrong way.

1. **Tutorial off by default.** `new_campaign.gd:103` passes `false` for the switch; first-time
   Home (`title.gd:505-537`) never mentions it and *Learn to play* is a small bottom-row
   button (`:128`). **Major.** Default it on when no campaign has ever been started, or ask
   after the people pick.
2. **The first "Next step" is "Room for another company."** With food at five days, nothing
   to train and no jobs, `recommendation()` falls through to the squad-cap branch
   (`game_state.gd:2605`). The cheapest hire is 180 silver (`economy.gd:14`) and lifts wages
   to 83 a day, leaving 2.6 days of pay. **Major.** When `battles == 0` recommend the nearest
   band; gate the hire line on three days of wages remaining after the cost.
3. **A broke player is told to buy food.** `game_state.gd:2558-2559` recommends provisions
   with no silver check; the desertion text (`:2998`) says to earn silver from bounties.
   The only income that needs no victory, the 110-silver courier job (`jobs.gd:46-49`,
   `:131-143`), sits behind the settlement's *Work* tab (`settlement_screen.gd:336`) and is
   never pointed to. **Major.** If silver is below a day of food, recommend a contract at the
   nearest town, and name contracts in the desertion warning.
4. **HUD resources are bare numbers.** Food shows `5` (`map_screen.gd:3176`); the tutorial
   art promises `5d` (`tutorial_art.gd:117`). The low-supply chips are a wordless ▼ with the
   meaning in a tooltip (`:3237-3239`). **Minor.** Render the unit; give the chips two words.
5. **"Braced" is used from the first battle and never defined** (`tutorial.gd:13`,
   `battle_screen.gd:1722`, `:1847`); the rule lives only in the README. **Minor.** Say it
   once in the first Hold hint.
6. **"Withdrawing may fail" shows for bandits**, but `can_withdraw()` returns true for any
   party that is not a lord (`map_screen.gd:1524-1525` vs `world_sim.gd:2933-2938`).
   **Minor.** Emit the chip only for lords.
7. **Hire and Send in are one tap, unconfirmed, with no "pay left after".** `_on_hire`
   calls `GameState.hire` directly (`settlement_screen.gd:2367-2369`); the only forecast is
   on the Warband screen two taps away (`main_menu.gd:486-511`). **Minor.** Show days of pay
   left under the price; confirm Send in when the odds chip reads Hard or Deadly.
8. **"Company" means a squad and the whole warband.** Squad: `battle_screen.gd:2919`,
   `main_menu.gd:92`. Warband: `settlement_screen.gd:1945` ("Your company is full. Win
   renown to lead more squads."), `title.gd:1`. The settlement tab says *Squads* (`:335`).
   **Minor.** Company for a squad, warband for the whole.
9. **Wounded are never explained.** Half of every loss comes back (`game_state.gd:3830-3831`)
   but still eats and draws pay (`economy.gd:66`); the result card is three bare tiles
   (`battle_screen.gd:2855-2859`). **Minor.** One line on the card.
10. **Play and 2× do nothing while standing still** (`map_screen.gd:280`) and nothing says
    so; the idle status line is just the town name (`:3213`). **Minor.** Toast the reason.
11. **Wait hides that it costs 8 hours** (`map_screen.gd:1015`, `:1886-1888`). **Polish.**
12. **Mortal/Casual and Ironman are decided before the player knows what a captain is**
    (`new_campaign.gd:101-113`); Ironman cannot be changed later. **Polish.** Fold them under
    "More options".
13. **The tutorial skips what the first hour needs**: contracts, wounded, what defeat does
    (12 hours lost and a ride home, `world_sim.gd:3131-3141`), what Withdraw does
    (`:3097-3110`); and it says "squad cap" where the HUD says "squads you can lead".
    **Minor.**
14. **The one-shot ground card can land on top of the deploy hint** (`battle_screen.gd:4813-4864`
    over `:1566-1621`). **Polish.** Show it after Fight.

What works: the encounter sheet (odds chip, troop mix, two bars, expected losses, time
stopped), deployment that is hard to get wrong (auto-select of the next card, a disabled
Fight with a plain refusal), and money that is honest at the point of sale with a desertion
sheet that pauses, names the cause and the fix.

## 3. The tactician

1. **A marching squad never fights back.** With order `move`, `foe` is null
   (`battle_sim.gd:2209`), so the squad is never `engaged` and its men drop their targets
   (`:2857-2858`) while enemy soldiers keep striking them, until the centre is within six
   units of the goal (`:2221-2224`). `order_line` in battle issues `move` to every active
   squad (`:1855`), the AI's raiders march under it (`commander_ai.gd:266`) and village
   reinforcements spawn on it (`battle_sim.gd:1043`). **Major.** Compute `engaged` on move
   too, and flip to hold when struck.
2. **Orders fire on a 24 px drag or a stray ground tap, with no confirm and no undo.**
   `DRAG_START := 24.0` (`battle_screen.gd:99`); with nothing selected a swipe re-forms the
   whole army (`:1353`, `:1535`); a ground tap with a squad selected marches it (`:1650`).
   In deployment the same swipe re-places a hand-placed army (`battle_sim.gd:1840-1846`).
   **Major.** Require a selection for a line in battle, or preview and confirm on a second tap.
3. **Retreat is a free escape.** Two taps on the pause card concede (`:1900`); `_finish`
   counts every standing man as a survivor (`battle_sim.gd:3740`); the map then sends you
   home with a grace period (`world_sim.gd:3136-3143`). The map refuses the same thing
   ("Ridden down!", `map_screen.gd:3060`). **Major.** Make it a fighting withdrawal or charge
   a share of men; at least print the cost on the button.
4. **The strength bar and the five-minute verdict disagree.** The bar is absolute men on the
   field (`battle_screen.gd:4056`); the verdict is share of start (`battle_sim.gd:3620-3624`,
   `:3669`), and start includes the reserve queue while the bar does not, so a lord with more
   than 12 squads is scored as weaker and his queued squads are drawn nowhere. **Major.**
   Draw the bar as share of start and mark "+N in reserve".
5. **Icon-only orders after three battles** (see Fix first, 8). Sally, Man the walls, Hold
   breach, Fire at will and Schiltron become glyphs; the same flag silences the out-of-arrows
   narration (`battle_screen.gd:1914`). **Major.**
6. **"Orders still work while paused" is half true.** Buttons work, the field does not:
   `_unhandled_input` and `_end_press` return when paused (`:1308`, `:1347`), so you cannot
   select, target or draw a line. **Minor.**
7. **Cavalry ride 2.6× faster under tap-to-attack than under Advance.** The march cap applies
   only to `advance` (`battle_sim.gd:2325`); the AI always uses attack for horse
   (`commander_ai.gd:355-375`). **Minor.**
8. **Empty archers walk into the melee with knives.** `_draw_blades` clears `ranged`
   (`battle_sim.gd:3143`), the bow-range halt no longer applies (`:2309`), and the AI
   re-issues Advance (`commander_ai.gd:283`). Hold fire plus Advance does the same to yours.
   **Minor.** Park them behind the nearest friendly foot.
9. **Ability cooldown fill uses the base cooldown** (`battle_screen.gd:4227`) while the sim
   scales it per branch (`battle_sim.gd:1999-2001`). **Minor.**
10. **Hold fire and Volley are per squad only** (`battle_screen.gd:1864-1875`, `:3833`):
    three archer squads are three select-and-toggle cycles. **Minor.** Offer "all bows" when
    nothing is selected.
11. **No pinch zoom or pan**; the camera only fits the bounding box (`battle_screen.gd:705`,
    `:913`), so a spread fight is 8 px men. **Minor.**
12. **An enemy lord's fall uses two thresholds** (`battle_sim.gd:3293` vs `:3304`), so the
    screen can say "cut down" then "taken". **Polish.**
13. **Horse-archer kiting is automatic** (`battle_sim.gd:2243-2248`) and bounded only by the
    quiver; against foot-only bands it is risk-free. **Minor, partly unverified.**

What works: the flag-drag matchup card, the targeting rings and destination rings, the
hourglass quarter-time with a second finger, and enemy morale on every standard.

## 4. The long-game strategist

Baseline: a lord's host (100 to 180 men) pays about 1,000 silver and 50 renown per win
(`game_state.gd:3909-3913`); a village fief 50 silver and 12 food a day, a castle 90 and 6
(`fiefs.gd:10-20`); a contract 25 + renown/5 + men/2 a day (`game_state.gd:3089-3091`). Only
two bandit bands exist per realm (`world_data.gd:156-160`), so lords are the late income.

1. **Stationed squads lost on load** (Fix first, 1). `stationed_at()` filters on a key
   `clean_army` never copies, so the Take back rows (`settlement_screen.gd:775-783`) vanish
   after a restart and the veterans are the crown's for good. **Blocker.** Carry the flag
   and squad `wounded` through `clean_army`, or keep company-stationed squads in GameState.
2. **Fealty and the crown empty the seat's garrison** (Fix first, 2). `answer_assault` also
   builds your defenders from `world.garrisons` (`game_state.gd:1904`) and your own
   conquests start empty (`:1991`). **Blocker.** Keep the liege's guards on grant; re-point
   the seat's garrison to `player_fief["garrison"]` right after `set_owner`.
3. **Infinite lord farm** (Fix first, 3). **Major.** Write `result["enemy_squads"]` back
   into the lord's party on a win as `hurt_band` does on a loss (`world_sim.gd:3113-3127`).
4. **Ransom is minted and release is a free renown pump.** Treasury is clamped at zero but
   the silver is paid in full (`game_state.gd:4087-4089`); release gives +10 renown, +25
   regard, +10 relation with no cooldown (`:4121-4136`); a captured lord's host is not
   reduced (`world_sim.gd:3007-3023`). **Major.**
5. **"Take back" hands you the liege's guard squads.** Stationing aliases the two arrays
   (`game_state.gd:2434`); `_garrisons_day` appends captain-less template squads to it
   (`world_sim.gd:1530-1570`, `:1492-1509`); the Fief card offers every entry
   (`settlement_screen.gd:912-924`). **Major.** Filter to squads the company stationed.
6. **Balance of power makes a daily war, peace, tribute loop.** Forced declarations skip the
   truce (`world_sim.gd:554-563`, `:2580-2586`), peace and balance run the same day
   (`:2482-2521`), each peace appends a tribute (`:565-591`), and the comparison counts
   Ryumon's villages against the other side's seats (`:2549-2551`). **Major.**
7. **Relation at or below −20 is a one-way door for a free company.** It counts as war
   (`game_state.gd:3075-3087`); the settlement then bars the tabs that hold contracts and
   jobs (`settlement_screen.gd:136-140`, `:574-578`); positive sources are a released lord
   (+10) and a gathering gift (+2). The card never says how to mend it. **Major.** Add an
   envoy or reparations action and print the number and threshold.
8. **The crown is gated by a fief shuffle nobody explains.** Castles start lord-held
   (`world_sim.gd:1572-1587`), only lord-less non-towns are grantable
   (`game_state.gd:2296-2312`), a vassal cannot petition again while holding a fief
   (`:2286-2289`), and the crown needs a castle or town (`:1333-1334`); `recommendation()`
   never mentions any of it. **Major.** Let a vassal exchange their fief for a freed castle.
9. **Garrisoned squads pay no wages and eat nothing** (`game_state.gd:2532-2537`,
   `:254-269`), and contract pay is fixed at signing from `total_men()` (`:3089-3091`).
   **Minor.** Half wages from fief silver; recompute pay daily.
10. **Relief jobs give +10 realm relation for 15 rations** (`jobs.gd:146-162`) and abandon
    is free (`game_state.gd:389-397`, `:480-490`). **Minor.**
11. **Declare, farm, sue always yields tribute to the crown.** Your own field losses never
    raise crown weariness, so `peace_terms` (`world_sim.gd:2632-2645`) favours you. **Minor.**
12. **The AI signs peace on the crown's behalf** with no prompt (`world_sim.gd:2524-2563`).
    **Minor.**
13. **Nothing after the crown.** `_crown_fate()` (`game_state.gd:1524-1531`) says the campaign
    carries on; `recommendation()` falls to "Build your name" (`:2616-2617`) and the last
    deed is 300 renown (`achievements.gd:18`). **Minor.**
14. **The War Sheet shows no relations and no peace thresholds** (`map_screen.gd:2197-2290`,
    `politics.gd:26-29`). **Polish.**

What works: the Diplomacy tab prints terms on the button and the exact blocker under
disabled actions; the realm economy is honest (treasuries, reserves, lords who desert when
unpaid); the Journal states objective, reward, cost, time left and the concrete blocker.

## 5. The story-and-character player

1. **"We'll speak another time" is final** (Fix first, 10). Status stays `unknown`, People
   says "Not yet met" (`people.gd:444-445`), every visit opens with the introduction line
   (`romance_talk_lines.gd:8`), and the marriage options are hidden in chapter 5
   (`romance_talk.gd:308-311`). **Major.** Keep offering the intent while none is chosen.
2. **Standing by her in council locks the public wedding and the pact.** `support_edda` is
   −10 standing (`romance_stories.gd:151-152`); both thresholds are 25
   (`relationships.gd:41-42`); the only standing sources are chapter rewards
   (`social_sim.gd:692-709`), so the support route tops out at 5 and the talk prints
   "Requires at least 25 house standing (currently 5)" with nothing left to raise it.
   **Major.** Lower the threshold or add a repeatable source.
3. **Married life is empty.** Seven letter kinds, none after the wedding
   (`letters.gd`; `add_letter` at `social_sim.gd:342,504,949,956`), though the closing
   narration promises letters (`wedding_lines.gd:133-134`); the authored post-wedding
   project `empty_chairs` is dead data (`romance_stories.gd:189-203`). **Major.**
4. **Lords never notice you married into their house.** The greeting is one line per
   bearing (`lord_voice.gd:14-19`; 20 lord lines in all, `:13-45`) with no check of pacts
   or marriage (`lord_conversation.gd:559-577`); People shows no kin chip
   (`people.gd:150-226`). **Major.**
5. **Letters from strangers, and from the woman whose castle you just took, consoling you.**
   `on_settlement_captured` relocates every resident including lord persons
   (`social_sim.gd:296-345`) and always writes; lords get the fallback letter
   (`letters.gd:572-575`); nothing checks `new_owner == CROWN` (`world_sim.gd:626`).
   **Major.** Letter only met persons; a different letter when you were the captor.
6. **House identity drifts and a dead lord keeps hosting.** Edda signs "of House Caldmoor"
   (`letters.gd:27`) but her house is whoever holds Ravensford, drawn at random
   (`world_sim.gd:1577-1586`); `kill_lord` (`:3038-3074`) renames the lord but not the
   person or the house, so the private-vows line names the dead man (`wedding_lines.gd:126`).
   **Major.**
7. **Camp moments: 20 lines, the same one after every battle, and the mourning moment can be
   missed forever.** One line per kind and temper (`camp_moments.gd:12-44`); mourning only
   until the next battle (`:93`); ten last words and five wounded lines for three cultures
   (`captains.gd:118-126`). **Major.**
8. **Bond talks: nine exchanges, keyed by the first captain's temper only**
   (`game_state.gd:3302-3330`); no memorial talk, the scene says the fire has gone quiet
   (`bond_conversation.gd:20-22`), though the plan asked for one
   (`talk-memories-and-bonds-plan.md:120-121`). **Major.**
9. **Visit openers repeat.** One line per status and per fact (`romance_talk_lines.gd:6-37`,
   `:113-147`); war, siege, wounded and company-hurt facts are current-state booleans not
   gated on the last visit (`romance_talk.gd:41-53`), so a war opens every visit the same way.
   **Major.**
10. **Every chapter letter gets Edda's chapter-2 reply** ("Keep the chair",
    `letters.gd:596-598`, `:541-543`). **Minor.**
11. **"Remember when" answers are generic or wrong** (private vows get the ceremony's "music
    too loud" line, `romance_talk_lines.gd:62-76`; dances have no entry) and only the newest
    six memories can be raised (`romance_talk.gd:702`). **Minor.**
12. **Heroes are generic captains the moment they are hired.** Their only words are in the
    tavern (`heroes.gd:27,43,59`); `is_hero` buys a star, a chip, a duel bonus and a court
    score; the memorial drops it (`game_state.gd:4046-4065`). **Major.**
13. **Name collisions**: Edda, Kaede and Tariq are in the captain pools (`cultures.gd:19,36,52`)
    that lords and heirs also draw from; `recruit_hero` ignores `taken`
    (`game_state.gd:321-333`). **Minor.**
14. **Chapter 3's obligations resolve in one tap** with no job or ride created
    (`social_sim.gd:685-697`; the plan asked for one, `romance-and-allies-plan.md:214-236`).
    **Minor.**
15. **Someone you parted from still receives visits** (`social_sim.gd:1046-1052` never checks
    `ENDED`; dances do, `game_state.gd:1016`). **Minor.**

What works: event-aware openers in each woman's voice; a wedding built from your own history
(her vow from your last visit, the toast naming your last two fallen); letters that are
letters, with a reply you read before it goes and a repair path for a broken word.

## 6. The accessibility, desktop and returning player

1. **Only an iOS preset, and a placeholder one** (Fix first, 9). `icon.svg` is a rounded rect
   on a transparent canvas, which the 1024 App Store slot may reject (*unverified*).
   **Blocker for a build.**
2. **A corrupt autosave hides every slot save and the next tap deletes them** (Fix first, 6).
   **Major.** If `load_game()` fails but `SaveSlots.list()` is non-empty, open the saves
   screen; never `clear()` without the confirmation sheet.
3. **No save-version check.** `SAVE_VERSION := 6` is written (`game_state.gd:34`, `:4172`)
   and never read; a save from a newer build is loaded lossy and re-saved at once
   (`save_slots.gd:136-137`). **Major.** Refuse newer versions and leave the file alone.
4. **The save index is written non-atomically and never rebuilt from the files**
   (`save_slots.gd:166-173` vs the tmp-and-rename slot writes at `:146-156`); a truncated
   index reads as no saves (`:37-39`). Settings go the same way (`sound.gd:543-557`).
   **Major.** Tmp-and-rename the index; rebuild it by scanning the directory when invalid.
5. **Portrait layout stretches to a landscape window.** `stretch/aspect="expand"`
   (`project.godot:31-37`) with full-rect pages (`menu_page.gd:16,21,30`) and no column cap
   except the ribbon (`scenes.gd:234`); no fullscreen toggle anywhere. **Major for Steam.**
6. **Escape and system back do nothing on the map or in battle.** Settings and Saves handle
   `ui_cancel` (`settings.gd:151-154`, `saves.gd:416-422`); the two main screens have no key
   handling; sheets close only from the shade (`widgets.gd:755-757`); `quit_on_go_back` is
   unset so Android back quits. **Major.**
7. **Targets under 44 pt.** The settings switch is 96×52 units and the row's words do not
   toggle it (`widgets.gd:877`, `settings.gd:113-128`); the map's Warband button is 64
   (`map_screen.gd:549`); the battle scout chip 52 (`battle_screen.gd:3466`); the slow handle
   54 wide (`:180`); tab bars 72 (`widgets.gd:135`). **Major.** Raise them to `Style.TOUCH`.
8. **Tabs and segmented controls ignore text size above 1.15× and ellipsize**
   (`widgets.gd:138-140`, `:909`), including Mortal/Casual and the Settings page's own
   controls. **Major.** Wrap to two lines or go icon-only above 1.25×.
9. **Colour is the only cue in the go-back grid** (`saves.gd:335-337`) **and the morale
   meters** (`battle_screen.gd:2049`, `:4148`, `:5656`). **Minor.** Add ▲▼ or a number.
10. **The chase alarm and the war horn are sound only** (`map_screen.gd:307-310`), unlike
    desertion and encounters which open a sheet. **Minor.** Ribbon them.
11. **"Save over it" is one tap, Delete is two** (`saves.gd:378-380` vs `:389-395`). **Minor.**
12. **No way to move a campaign between devices**: `user://` only, iOS file sharing off
    (`export_presets.cfg:58-59`). **Major for a returning player.** Enable Files-app access;
    later iCloud and Steam Cloud on the directory.
13. **Desktop gaps**: no hover on unlit tabs (`widgets.gd:148-149`), `on_tap` cards are
    mouse-only and unfocusable (`:497-507`), settlements hit-test only on release
    (`map_screen.gd:452-453`), no battle zoom. **Minor.**
14. **Reduced motion leaves the hit flash** (`battle_screen.gd:294`, `:5474`), **the gate
    flash** (`:6148-6149`), hitstop (`:2530`) and the scene fade; ribbons hold 2.2 s and
    cannot be dismissed (`scenes.gd:171`, `:201`), the same at 150% text. **Polish.**
15. **Settings row titles cannot wrap** (`settings.gd:122`). **Polish.**

What works: save safety around the battle (a checkpoint before the fight, `pending_battle`
not serialised, atomic autosave, a save on pause, a pause on focus loss); the accessibility
settings are real and respected across the kit; chips never rely on colour alone; switches
carry screen-reader text; destructive sheets grab focus on the safe button.

## 7. The QA engineer

*(pending: static pass over preload paths, scene references, autoload calls, save keys and
assets)*

## 8. Method, and what to do next

- Each pass read the player's screens in the order they would meet them and the rules
  behind each tap, with `README.md`, `docs/NEXT.md` and the plans as the statement of
  intent. Items the plans already list were left out.
- The blockers in section 1 should be confirmed on a device before anything else: station a
  squad in a crown holding, restart, open the Fief tab (1); swear fealty and look at the
  castle's garrison (2); beat a lord, wait a day, meet him again (3); retreat from the pause
  card when the map said you could not withdraw (4).
- After each fix: `godot --headless --script res://tests/run_tests.gd`, the focused suite
  the fix touches, and the game with `-- --autoplay`.
