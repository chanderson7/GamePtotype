# UI simplification plan: less text, more marks

**Status:** built, not yet run in Godot. Nothing here changes a rule of the game.

The kit, every screen section and the order-bar recommendation are in. The container that
built it had no Godot binary, so the checks were `gdparse`, `tools/check_calls.py` (calls into
other scripts and the autoloads name real functions with valid argument counts; private
helpers exist; local argument counts) and `tools/check_infer.py` (no `:=` on a call without a
return type). Run the suites before trusting it:

    godot --headless --path . -s tests/widgets_tests.gd
    godot --headless --path . -s tests/menu_tests.gd   (and the rest of tests/*_tests.gd)
    xvfb-run -a godot --path . --resolution 405x878 -s tests/screen_width_tests.gd

What was left, and why:
- **Order bar:** words for the first three battles (`GameState.battles` below 3), icons after,
  with the word as a tooltip. Fight, Storm!, Auto-place and Cancel keep words.
- **Brand:** only the wordmark came over from `app-logo` and sits on Home over the title
  label, with the Cinzel text as a fallback. The app icon still waits on a choice.
- **Iron Company** is renamed **Mortal** in New campaign and Settings; change it freely.
- **Not done:** tab icons on the settlement tab bar (five tabs with icon and word overflow a
  phone). The Warband's four tabs have them, the icon over the word and the count on a brass
  pill (`Widgets.tab_bar(..., stacked = true)`); the settlement keeps its own shell rather than `Page.frame`; the marshal
  army's "Expedition timed out" outcome type (it lives in `marshal_armies.gd`); the arrival
  subtitle's realm (in `travel_presentation.gd`); the map's top-bar pills stay 64 tall; men and
  morale are not in the battle info strip (the card and standard say them); grief and wavering
  ticker lines stay, having no other channel.
- **Found on the way, since fixed:** `world_sim.is_sieged()` and `sieging_army()` looked for
  the state "sieging" while marshal armies use "besieging", so no place ever read as besieged:
  siege drums never played, and feasts, summons and hosting went ahead under a siege. They now
  read "besieging", like `siege_info`. `tests/combined_battle_tests.gd` called the removed
  `w._spawn_lord_party()`; it now calls `_lord_takes_field()`.
**Mockups:** `mockups/ui-patterns-before-after.png` (four recurring patterns as they are and as
proposed) and `mockups/ui-new-icons.png` (the 25 new icons the plan needs, drawn and checked
at size). The icons themselves are in `assets/ui/o_*.svg`, unused until a screen takes them.

This plan comes from reading every screen script against the shared kit (`scripts/ui/widgets.gd`,
`scripts/ui/style.gd`, `assets/ui`), with the recent screens (captain profile, crown court,
Fief tab, siege deployment, romance talks) as the house style the rest should match. Line
numbers below refer to the files at commit `2c2ef8a`.

## What the survey found

The game has a good kit and an uneven use of it. Four recent screens use tiles, chips, faces,
meters and cards; the older and larger ones (the map, the Warband roster, the Work and Crown
tabs, the battle result, Home, Saves, People) say the same things in sentences. Across the
whole game the same five problems repeat:

1. **Numbers live in sentences.** "Deadline: 48h · Reward: 150 silver, +5 renown, +10 standing",
   "Next payment in 5 hours · 180 silver + 24 rations · afterward: 1,020 silver, 96 rations",
   "In service to Vardmark · 40 silver daily (12 days remaining) · 100 silver bonus per captured
   lord", "9 casualties (4 slain, 5 wounded in baggage)". About forty of these. Every one of them
   has an icon already in `assets/ui` for each number.
2. **Costs and effects sit inside button labels.** "Construct (300 silver)" is gone from the Fief
   tab, but "Accept Ransom (+200 s)", "Deliver to Employer (+100 s, +10 rel)", "Release for Honor
   (+25 Regard, +10 renown)", "Swear Fealty and Claim Ashford (Village)", "Recruit Osric (420
   silver)", "Refill · 60", "Train · from 120", "Sue for peace (you pay 40 a day)", "Refuse −5",
   "Reinforce all · 240 silver" are still there. A label should be the verb; the price goes
   under it.
3. **The same fact is on screen twice or three times.** Men and morale show on the battle card,
   the standard and the info line at once. Wounded men show in the Warband header tile, the
   Companies summary and twice in every row. Every battle "moment" also fires as a ticker line.
   The romance talk states a choice's effect in the tag, again on confirm, and again as a
   reaction chip. The Saves screen says how many free slots there are in two places. The full
   list is at the end of each section.
4. **Six versions of the same widget.** Three chip builders (`Widgets.chip`, the profile's
   `_gold_chip`, People's `_chip`, the talk view's `plate_chip`, Saves' `_stat`), six chip shapes in
   the battle screen alone (radii 12 to 40), four bottom sheets, three bottom bars, four Back
   button styles, three section headings, two tile builders and three meters. `settlement_screen`
   carries line-for-line copies of `Widgets.card`, `chip` and `section`; `map_screen` carries a
   copy of `Widgets.icon`.
5. **Text below the floor.** `style.gd` says nothing a player reads goes under SMALL (22). People,
   Home, Saves, the talks, the kingdom screen and the battle field use 15 to 21 in about sixty
   places, and most field text in battle skips `Style.text_size`, so the Text size setting does
   nothing to it.

The fix is the same everywhere, and the mockup shows it on four screens: a recurring quantity
gets its icon, a status gets a chip with a shape, a person gets a face, a realm gets its banner,
a sentence of numbers becomes a row of tiles, and a verb is a verb.

## The rules

These go at the top of `widgets.gd` so new screens follow them without a review:

- **A number that recurs has an icon, and the icon replaces its word.** Silver, rations, men,
  wounded, renown, morale, speed, Regard, days, hours. "150 silver" is the silver icon and
  "150". "Day 12" is the calendar icon and "12". No "s" for silver, no "d" for days, no "h".
- **A status is a chip with a shape.** ▲ good, ◆ middling, ▼ bad, so it reads without colour;
  an icon where one exists (wounded, lock, rings, fight). Never a coloured word alone.
- **A person is a face; a realm is a banner.** Lords, captains, candidates and guests are
  drawn with `CaptainArt` or `Widgets.framed`; realms with `Widgets.banner`. A name or realm in
  text beside its picture is a duplicate.
- **A sentence with two or more numbers is tiles.** `Widgets.tile_grid` or a chip row. The
  sentence survives only as a tooltip or a sheet.
- **A button is a verb.** The cost sits under it or beside it as an icon and a number; the
  reason it is greyed sits in a muted line under the row, never in a tooltip. Labels are at
  most three words.
- **Say it once.** If a fact is on the picture (a face badge, a meter, a field mark), it is not
  also in a line of text. A moment on the field replaces the ticker line for the same event.
- **Nothing a player reads is under SMALL**, and every size goes through `Style.text_size`,
  including `draw_string` on the battle field.

## 1. The kit: one of each

Do this first; every screen change below leans on it.

| Add or change | Replaces |
|---|---|
| `Widgets.chip(text, tone, shape := "", icon := "", gold := false)` | profile `_gold_chip`, People `_chip`, talk view `plate_chip`, Saves `_stat`, Home strength chips, map `DangerChip`, battle `scout_chip`, `objective_chip`, `_pill_box`, `_ticker_box`, role badge, rank chip |
| `Widgets.sheet(title) -> column` (shade, grip, slide, tap-outside closes, one ✕) | settlement info sheet, station sheet, `CourtUI.sheet`, map `_show_sheet`, the renounce and branch modals, Home's stock `ConfirmationDialog` |
| `Widgets.bottom_bar(buttons: Array, insets)` with one rule: Back left, primary right and wider | profile `_bar`, People `_bar`, kingdom council footer, settlement LeaveBar |
| `Widgets.back_button(label := "Back")` with the `back` icon, never brass | four Back styles |
| `Widgets.meter(frac, color, height, marks := [])` | `main_menu._meter`, People `_trust_meter`, romance `_trust_bar`, map `_odds_bar`, battle roll bar |
| `Widgets.store_tile` (the Fief tab's number-over-cap tile with a meter) | the Fief tab's local copy, Crown garrison, muster and host strips |
| `Widgets.icon_tile(key, lit)` | deed tiles, role option tiles, letter kinds, job kinds |
| `Widgets.count_badge(n)` | map unread pill, menu card red badge, tab-label counts like "Court · 3" |
| `Widgets.card(..., gold := false)` | the gathering card, camp moment card, promotion card borders |
| `Widgets.segmented(options, current, on_pick, icons := [])` | map time controls, Lords filters, lord order buttons, chronicle filters, gathering kind |
| `Widgets.rank_badge(letter)` | "Rank C" text in bond rows, bond talk chips, battle rank-up chip |
| `Page.frame(root)` one shell: background, scroll, margins 32/48, column separation 18 | the hand-built shells in Warband, profile, People, settlement, new campaign |
| `Style.time_short(hours)` one formatter ("8 h", "2 days") | four wordings of ride time across map, crown court and People |

Delete after the moves: `settlement_screen._card/_chip/_section`, `map_screen._resource_icon`
and `RESOURCE_ICON_PATHS`, `title._tile/_button`, `sound_toggles.gd`, `people._memory_row`,
`wedding._card`, the second `_keepsake`, `_result_heading`/`_result_stat` in battle.

## 2. Icons

### Already there, not yet used where they fit

`wounded` (Home uses `plus` for wounded captains; the deploy card uses "*"), `saves` (Home's
"Load a save" has no icon), `rings` (weddings on the map use a word), `mail` (letter replies say
"read and answer it"), `eye`/`book` for the "i" info button, `ladder`/`ram`/`walls`/`storm` for
the siege field labels, every `o_*` order icon for the callouts over squads (CHARGE, BRACED,
BROKEN, SHIELD WALL), `o_back` for the text "‹" and "›" chevrons in the kingdom screen,
`o_cup`/`o_dance` for gathering kinds that use `lantern` or `food`.

### New, drawn in `assets/ui` on this branch

| Icon | For |
|---|---|
| `clock` | deadlines, "days left", ride times, "back in N", cooldowns |
| `day` | "Day 12" on the map bar, Home, Saves, the chronicle |
| `sun`, `moon` | time of day on the map bar, talk captions, battle title card |
| `fire` | raids, burned villages, "Burn it" |
| `bond` | Regard and standing with a number, replacing "relation", "standing", "+12 Regard" and the bare "+12" |
| `level` | squad level, where words say "Lv3" |
| `vengeful`, `steadfast`, `fragile` | temperaments on roster rows and profile |
| `lucky`, `mentor`, `bold` | quirks |
| `flank`, `rear` | battle callouts and ticker |
| `pause`, `play`, `fast`, `menu` | the map's procedural glyphs and the battle's hand-drawn pause |
| `peace` | truces and "Sue for peace" |
| `sail` | "partly by sea" on map previews |
| `militia` | village militia in garrison chips |
| `armor`, `damage` | the branch choice's stat lines |
| `chest` | the crown treasury |

Not drawn, and recommended against: icons for lord bearings (Daring, Cautious, Cruel,
Honorable) and for fury/steady/shaken. Four abstract temperaments as glyphs would need a
legend; a chip with the word and a shape is clearer.

## 3. Screen by screen

Each list is in order of value. "Twice" items are facts shown more than once on one screen.

### Map (`world/map_screen.gd`)

1. **Status line to chips.** The one ellipsised line that packs activity, chaser, low supplies
   and captives (2879–2906) becomes an activity row (ride/wait/home icon, place, the progress
   bar) and a chip row: `skull` with the chaser and ▲/▼ pace, red `food`/`silver` for low
   supplies, `lock` with the captive count. Its second line is clipped today.
2. **A pinned-commitment chip under the bar.** The comment at 562 promises a goal chip that was
   never built. `objective` icon, title, a `clock` chip from `_commitment_time`.
3. **Dock icons by key, not by word.** `ACTION_ICONS` (721–730) matches words in labels, so "Let
   them storm it" gets the storm icon and "Begin your wedding" gets none. Pass the icon in the
   button spec and shorten the labels: "Ransom", "To employer", "Release", "Storm", "Wedding",
   "Raise crown", "Lead", "Stand aside", "Defend". Costs become a sub line on the tile.
4. **Encounter, siege and raid sheets as odds plus chips** (mockup 4). Banners on the odds bars,
   `men` numbers, chips for ground, expected losses and withdraw; the lord's voice line as the
   only prose. Pace is said twice today (1421–1426 and 1524–1532). The raid sheet's five
   sentences become `silver`, `food`, `clock`, `militia` tiles and a `bond` chip per bearing.
5. **Journal and chronicle as rows.** Commitments are a bullet list plus a dock tile each, so
   five commitments make eight big tiles repeating the list. One row each: `objective` or `pin`
   icon, title, `clock` chip. Chronicle filters become `Widgets.segmented`; entries get a `day`
   badge and a type icon.
6. **Resource sheets as tile grids.** "1,204 silver. Your men need 62 silver in wages each day…"
   (1600–1615) becomes three tiles and one tip line.
7. **Lord sheets.** The marshal's army branch (1103–1121) is a text dump with no header, banner
   or faces; rebuild it with the realm banner, the army-state pictogram from `_draw_army_badge`,
   `men`, `mappin`, `speed`, and member rows. The single-lord sheet says realm and rank in the
   body, the sub line and the banner.
8. **One siege ring.** `_draw_sieges` and `_draw_settlement` both draw rings and tents around a
   besieged place (3162–3181, 3243–3261). Keep the realm-coloured one and add a `storm` badge.
9. **Plates.** Gathering plates ("Feast · night 2 of 3 · 6 lords") become a kind icon, a 2/3 pip
   row and `men` 6. "Wedding · ready" becomes a pulsing `rings` badge. Cohort member plates can go;
   the brass ring already groups them. The ▲/▼ on strength marks means the opposite of the kit's
   ▲ good / ▼ bad; pick one and share the helper with the sheet chips.
10. **Fourth resource pill: men.** The bar shows silver, food and renown; men is the number
    every fight compares. Food's "3d" becomes the icon and "3".

Twice: "You are here" body, title and bar (975, 988, 2894); squads and realm in the band sheet
body and sub (995, 999); unread count in the menu card text and its badge (1793); the hall count
in the council head and the face row.

### Settlement (`world/settlement_screen.gd`)

1. **Work tab as cards with term chips** (mockup 2). Job terms, the commission ("In service to
   … · 40 silver daily (12 days remaining) · 100 silver bonus per captured enemy lord") and the
   fealty petition become `silver`/`renown`/`bond`/`clock`/`food` chips with a job-kind icon
   (`skull` hunt, `mail` courier, `food` relief). Buttons: "Accept", "Claim", "Offer your sword",
   "Resign", "Swear fealty…" (a picker sheet of fiefs with their vista plates, instead of one
   primary button per candidate).
2. **Crown tab like the Fief tab.** Today it is sections, notes and full-width buttons: "Grant to
   Ysolde (holds Marchgate)" per lord, "Station Osric's Shields" per squad, "Take back Varo's
   Bows (18 men)". Use `store_tile` for the garrison, a face picker sheet for granting, the
   station sheet for stationing, `_squad_line` rows for withdrawing.
3. **Squads tab rows on `_squad_line`.** "Shields · 11/12 men · level 3 · 180/180 xp" becomes a
   men meter, level pips and an xp meter; "Refill · 60" and "Train · from 120" become verbs
   with a `silver` number under them; "Reinforce all · 240 silver" becomes the card's primary
   button with the cost as an aside. The branch choice becomes a sheet with stat chips (`armor`,
   `damage`, `speed`, `men`, `morale`) instead of bullet sentences.
4. **Buy tab.** Recruit rows "12 Vardish · 3 a day" become `men` 12 and `silver` −3/day; "Hire
   180" becomes "Hire" over `silver` 180; provisions buttons "+3 days\n45 silver" become a
   `food` tile-button with a `silver` aside. Tavern heroes get faces and one card, with the bio
   and quote behind a tap.
5. **Header.** "Town · Vardmark" repeats the banner beside it; keep the type. The danger chip
   gets icons (`walls`/`ram` siege, `fire` raid, `advance` marshal army, `fight` hostile) and a
   banner in place of the realm word. The "i" glyph becomes an icon button.
6. **Info sheet.** Owner as a banner, garrison as `men` with a meter, services as an icon row,
   the siege sentence ("under siege by X: 120 men against 40 behind walls (×1.4); food for 6
   days; assault in 18 hrs") as a tile grid.
7. **Court tab.** Feast actions get icons (`cup` toast, `silver`/`food` gift, `talk` gossip,
   `crown` speech) and icon-number sub lines at 22; the host strip uses `tile_grid` with icons;
   "In the hall" becomes a card head; the duplicate rules entry goes; petition buttons rise to
   80 px with `bond` ±N marks. Hall rows use the same `bond` chip the talk view uses.
8. **One sheet, one modal pattern.** Replace the info sheet, station sheet, renounce modal and
   branch modal with `Widgets.sheet`. Delete the local `_card`, `_chip`, `_section` and LeaveBar.
9. **Fief tab leftovers.** Store tiles take the `silver` and `food` icons; "Collect 320 silver"
   becomes "Collect" since the tile above says the number; the wound rule is stated three times
   between the card and the sheet, keep one; "Need 130 more silver" and the price under the
   button say the cost twice.

Twice: the condition sentence in the info sheet and the arrival card; the realm in the kind
line, the arrival subtitle, the Owner line and the banner; "Court · 3" in the tab and "In the
hall · 3".

### Lord talk (`world/lord_conversation.gd`, `lord_talk.gd`)

1. **Reply tags as marks.** Every tag ("new job · +10 Regard when done · counts toward
   crowns", "they'd add 40 silver · −3 Regard, Cautious dislikes haggling", "release for honor ·
   +25 Regard · Vardmark +10") becomes a category icon and effect chips: `bond` ±N, `silver` ±N,
   `renown` +N, a small banner ±N.
2. **Shorter reply lists.** The root list reaches ten full-width buttons. Collapse the two locked
   crown lines into one; make the three orders a Follow / Hold / Free segmented row; move
   "Something else" and "leave" to a two-icon footer (the stage ✕ already leaves).
3. **Caption and plate.** "In the hall at Highcliff · feast · dusk" becomes `mappin`, `cup` and
   `sun`/`moon` marks. Drop the uppercase speaker name above every line; the plate has it.
4. **Notes as chip rows.** "−40 silver, +3 Regard. They let you pass." and the rest of `_note`
   become effect chips with coloured numbers.
5. **Stakes as a Win / Lose grid** for challenges and duels (`men` v `men`, `renown`, `silver`,
   `wounded` ×2, a red banner for war).
6. Raise all talk text to 22 and the small buttons (Draw swords 60, silver offers 56, close 64)
   to 80.

### Warband (`menu/main_menu.gd`)

**Compact header, as built** (mockup `mockups/warband-compact-before-after.png`): the four
tiles share one row (`Widgets.compact_tile`; two rows when big text or big numbers won't fit),
food shows the stock with its days under it; pay that can be met is a `clock` chip with the
place, day and speed, and the Next pay card shows only when pay runs short (red edge, "Men may
leave") or there's no map; the tabs stack icon over word with the count on a pill; the
captains stand in a grid four across (three at big text), the resting last, dimmed, with a
`wounded` mark; "7 ready · 1 resting · 1 remembered" are chips on the camp picture, the last
one jumping to The fallen. Not yet run in Godot.

**Motion, as built** (prototyped as a live page first): the camp flies the company's own
realm banner (`Heraldry.realm_pole` and `realm_cloth`, the crown once raised) in place of the
old culture-coloured flag, its cloth drawn once into a viewport and rippled by
`shaders/banner_wave.gdshader`. `scripts/ui/camp_fx.gd` lays the fire's life over the camp
picture: lantern and cook-fire glow, embers, smoke, stars at night, and rain (snow in
Ryumon) on about one day in six, from a stable hash of the place and the day, never the
campaign's dice. The picture drifts a little as the page scrolls. Captains wear the face
that's true of them (pain, grief, warm, proud). `Scenes.warband_seen` remembers what the
screen last showed, so on a return the tiles count to their new numbers with the change
rising off them, badges that went up pop, a pay that can no longer be met shakes in, a bond
that reached a rank pops its badge, and a deed just done is stamped. Rows rise in and meters
fill on arriving or turning to a tab; met crown steps draw their ticks; the moment card
catches the light and folds away; Remember lands on The fallen; memorials and remembered
bonds keep a candle; Promotion catches the light, Train beckons, a contract with under a day
left ticks. Talks at the fire show three, then "All N". The helpers are
`scripts/ui/motion.gd`; every one is a no-op under Reduced motion. Not yet run in Godot.

1. **The roster row** (mockup 1): face with the troop badge, name with `men` 11/12 and
   `wounded` 1 on the right, captain with temperament and quirk icons and a gold Promotion chip,
   one strength meter, level pips, a ▲ Train chip. Drop the xp and bond meters (the profile and
   Bonds tab have them) and the trait words. Seven lines become three, across twelve squads.
2. **Upkeep forecast as a "Next pay" card**: `clock` aside, two rows (`silver` −wages → after,
   `food` −rations → after), a red chip for the shortfall.
3. **Companies summary and contract as tiles**: `company` 9/12, `battle` 14 (9 won), `wounded`
   3; the contract as a banner, `silver` +20/day and a `clock` chip. Wounded appears in the
   header tile, this summary and twice per row today; contract pay appears three times.
4. **Bond rows shared with the profile**: framed faces with a `rank_badge`, effect as `morale`
   +1.5/s and `fight` +5% chips, a meter with "9/12 → B" as aside, a `talk` icon button with a
   new dot. Drop "earlier battle record unavailable" and the repeated points.
5. **Captive lords as faces and banners** with "Ransom", "Deliver", "Release", "Swear" over
   `silver`/`crown`/`bond` numbers (today "Ransom · 200 s"); the refusal reason on screen, not in
   a tooltip.
6. **Memorials** as a face, a `battle`/`skull` tile pair, an Avenged chip and the slayer's banner,
   instead of a six-clause sentence; show five and "All N".
7. **Deeds**: job-kind icons, an 80 px cancel with confirm (Abandon is 100×36), status chips
   (`clock`, `silver`, `renown`, `bond`), the fief card as a four-tile grid with the realm banner,
   "Carried" as a toggle, the footer count as the card aside.
8. **Header**: the culture word becomes the banner, "near Holt" a `mappin` chip, "day 3" a
   `day` chip; the men tile shows a number, not "11 men"; pace moves to a `speed` tile.
9. Sort control as icon segments; floating section headings into cards; the "N talks at the fire"
   button goes (the Bonds badge says it).

### Captain profile (`menu/captain_profile.gd`)

Already the reference. Remaining: level shown in the hero and the Progress aside; the fallen
story repeats the record tiles (402–404); the xp meter fills differently here (within level) and
on the Warband (total); "back in N" has no unit; the Bonds card should use the shared bond row;
temperament and quirk get their icons beside the names.

### People (`menu/people.gd`)

1. **Say the place once on a person card.** It appears in the role line, the next-step box,
   the Ride button and the pin. Keep one `mappin` chip with the ride time; the main button is
   "Ride" or "Speak" with its icon. The stranger row's `mappin` button starts travel; use `ride`.
2. **Status chips with shapes and icons**: `heart` courting, `rings` engaged or married, `talk`
   acquainted; standing Allied to Hostile as ▲◆▼.
3. **Lords tab**: drop the realm text beside the banner; "at war" a red `fight` chip, "captive"
   `lock`, "holds X" `keep`, "ransom 300" `silver`; Regard as the meter's aside; filters as
   `segmented` at 80 px; rulers get a muted border, not 0.72 alpha text.
4. **Pacts**: "Request grant · 150" and "Sponsor muster · 150" look identical but money moves
   opposite ways, and the grant's 150 is hard-coded while the real amount is `res.amount`.
   "Grant" over `silver` +150, "Muster" over `men` with `silver` −150, disabled with a reason on
   cooldown. Replace the always-"Active" aside with the house banner and standing.
5. **Letters**: a kind icon per row (`mail`, `rings`, `mappin`, `cup`), `reply` instead of
   "· answered", read letters collapsed to one line, grouped by sender face.
6. **Person page**: `Widgets.tile` with `bond` trust, `keep` house, `journal` memories (the
   captions are size 17 today); a Back in the bottom bar.
7. All sizes 17–21 to 22; names through one `Style.name_label`.

### Battle (`battle/battle_screen.gd`)

1. **Result screen as tiles and faces** (mockup 3). `skull`/`wounded`/`fight` tiles for the
   tally, `silver`/`food`/`renown` tiles with `tick_to` for rewards, the story paragraph replaced
   by a "hardest fighting" star on that captain's face, fate as a badge on the portrait, the
   death roll as "37 / 41" with a die mark, out-for-N as pips, company rows with a troop sprite
   and a before → after men meter. Drop "Fought near X." under the vignette that says "Near X".
2. **Info line as an icon strip.** "Selected: Brann's Shields · 18 men · 64% morale · fury ·
   12 arrows · attacking, holding fire" becomes `men` 18, a morale meter, `bow` 12, an
   order-state icon. Whole-army and storm-plan lines become icon counts. Then men and morale
   are on the card and the standard only.
3. **Hint line to a toast.** The two reserved lines narrate every order in a sentence (twenty
   strings, 1472–1838) although the field already confirms each with a mark. Keep first-time
   teaching and refusals; reclaim 64 px of field.
4. **One message per event.** Every moment also fires a ticker line (breach, rout, captain cut
   down, chief and lord lines). The death roll plate is echoed in the hint line. The scouting
   sentence shows on the title card, the scout chip and the pause note.
5. **One objective chip for every battle.** Field battles put the objective in a 4.5 s ticker
   line; sieges have a chip. Use the chip everywhere, with "Defend 1:23" inside it, and trim the
   siege tails to the short phrase or an icon.
6. **Callouts to icons**: CHARGE `wheel`, BRACED `shieldwall`, BROKEN `retreat`, abilities their
   icons, FLANK/REAR the new arrows; the pill's leading dot becomes the icon so the word can go
   at low zoom. Drop the floating "MOVE".
7. **Deploy**: troop sprite via `Art.icon` on the card, `wounded` badge instead of "*", a `men`
   glyph on the count, "3/5" pips instead of "Deploy · 3 of 5 placed" (the cards' ticks say it);
   the enemy tap readout as an inspect pill (sprite, `men`, morale meter, level pips, skull);
   terrain modals as icon-and-modifier rows.
8. **One chip shape** for the six in this file; `Widgets.section` for `_result_heading`; field
   text on the 22/26/30 scale through `Style.text_size`; the 44 px terrain title to 48 so it
   takes the display face like "Paused".

### Home, Saves, Settings, New campaign, Tutorial (`menu/title.gd`, `saves.gd`, `settings.gd`, `new_campaign.gd`, `tutorial.gd`)

1. **Brand.** Home draws "Bannerfall" as Cinzel text and the export icon slots are empty. The
   `app-logo` branch has the icon and wordmark; adopt one and use the wordmark here, with the
   opening animation lifting into it.
2. **The campaign card shows the real place.** Home paints the generic camp; Saves already
   paints the saved settlement vista. Use it on Home too. Swap `plus` for `wounded` on the
   wounded row, give "Next step" an `objective` icon and drop the row (Continue does the same).
3. **One culture picker.** Home's first-time cards and New campaign ask the same question in
   two designs. One card: vista, banner, people name in Cinzel, strengths as icons
   (`shieldwall`, `bow`, `ride`, `speed`, `schiltron`, `volley`) instead of "Starts in X · troop,
   troop…", with Tutorial, Iron Company and Ironman on the same screen. Rename one of Iron
   Company / Ironman.
4. **The four numbers one way.** Home tiles, the Right-now icon chips and the save rows' bare
   icons show men, silver, food, renown three ways. Use `Widgets.tile`; add food to the rows,
   show the day when illustrations are off, use icons for the Go-back compare grid, fix the
   `"o_back"` fallback at `saves.gd:317` (it looks for `o_o_back.svg`).
5. **Settings**: `Widgets.section` headings, label-left control-right for Text size and Screen
   shake, Text size as three "A" glyphs, developer options out of the player list, a shared
   bottom-bar Back here and on Saves, New campaign and Tutorial.
6. **Tutorial**: one icon row (`back`, `advance`, skip link) instead of three stacked buttons;
   drop the duplicate counter or caption.

### Talks (`ui/talk_view.gd`, `menu/romance_talk.gd`, `wedding.gd`, `dance.gd`, `bond_conversation.gd`, `bond_intro.gd`)

1. **Effects once, as marks.** Romance states a choice's cost in the tag, again on confirm and
   again as reaction chips; dance repeats the tag in the result. Show `silver`/`food`/`bond`
   chips on the button and one animated result.
2. **Plate badges.** Bond rank as a `rank_badge` with `morale`/`fight` chips, not a sentence
   chip; relationship status as a heart-stage badge; trust as `Widgets.meter` with marks.
3. Drop the repeated speaker name in one-on-one bubbles; give the second captain in a bond
   talk a neutral right bubble instead of the player's blue.
4. **Wedding finish**: "Married" is a chip, a title and a sub line; the keepsake re-quotes the
   vow and toast; "Who came" restates Regard. One closing card, guest roles as icon badges
   (`keep` host, `crown` your lord, `company` captain), the pact as three icon lines, the
   player's banner instead of the company icon.
5. The pink colours (`e88aa0`, `e58fa8`, `f6cdd9`) become `Style.ROMANCE`.

### Kingdom (`world/kingdom_screen.gd`, strings in `crown_court.gd`)

1. **Diplomacy rows as tiles**: "Vardmark · war-weariness 40 · 5 places · opinion of you −12 ·
   at war with you for 6 days" becomes a status chip, a weariness meter, `keep` 5, `bond` −12,
   `clock` 6. The map's War & Politics sheet shows the same realms another way; share the row.
2. **Holdings**: type icon with the name, a chip row for holder (face), garrison (`men` +
   meter), stationed (`company`), burned (`fire`), besieged (`storm`); one "Grant…" picker
   instead of one button per lord per fief.
3. **Lords**: order as a Follow / Hold / Free segmented row with "Take back" quiet and apart;
   status as `keep`/`ride`/`hold`/`lock`/`silver` chips; the same `bond` chip as everywhere.
4. **Court strips** (`CourtUI.strip`) become `tile_grid` with icons; the council footer becomes
   `bottom_bar` with a leading info column; place pickers become sheets; "‹" and "›" become
   `back` icons; buttons rise from 60–64 to 80.
5. **Strings at the source**: `host_status` and `commitments()` return fields, not sentences;
   one ride-time formatter; marshal army reasons get an outcome type so the UI can show an
   icon instead of "Expedition timed out".
6. Realm tile for "places" uses `battle`; use `keep`. Two tiles share `silver`; the treasury
   takes `chest`.

## 4. Order of work

1. **Kit** (section 1) and the new icons wired into `Widgets.ICONS`. Tests: `tests/screen_width_tests.gd`
   unchanged; a new `tests/widgets_tests.gd` builds each widget and checks names, sizes and
   that no label under 22 is created by the kit.
2. **The four mockup patterns**: Warband roster row, Work tab, battle result, map encounter.
   They are the four most-seen text-heavy pieces and prove the rules.
3. **Costs out of labels, everywhere.** A grep for `%d s)`, `silver)`, `(%d`, `· %d silver`,
   `Regard)` in button text drives the list; each becomes a verb with a sub line. One commit per
   screen.
4. **Say it once.** The "twice" lists above, one screen at a time, with the battle ticker and
   hint line first.
5. **Faces and banners** on captive lords, the Lords tab, memorials, the marshal sheet, guests.
6. **Sizes**: every raw 15–21 to 22, every `draw_string` through `Style.text_size`, every
   touch target to 80.
7. **Home and the brand**, the single culture picker, Saves and Settings.
8. **Kingdom and talks**, which are large but seen less.

Each step renders its screens under `xvfb-run` and the pictures go in `docs/mockups`, as the
earlier plans did, so the before and after are both on record.

## Open questions

- **How far to go with icon-only buttons in battle.** The order bar has an icon over every
  word already. Dropping the words gains 20 px and loses first-time clarity. Recommendation:
  keep the words for the first three battles of a campaign (`_taught` already tracks teaching),
  then icon-only.
- **Bearings and moods as icons.** Daring/Cautious/Cruel/Honorable and fury/steady/shaken recur,
  but abstract glyphs need a legend. Recommendation: chips with the word and a shape, no icon.
- **Rank badges versus letters.** C/B/A in a brass circle reads as a grade; the game calls it a
  rank. Recommendation: the badge, since the letter is already the whole label.
- **The brand.** Three icon concepts and a wordmark wait on `app-logo`. This plan assumes one is
  chosen; Home cannot drop the text title until then.
