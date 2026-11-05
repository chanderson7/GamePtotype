# Captain profile: UI plan

A plan, not yet built. The captain profile (`scripts/menu/captain_profile.gd`) is a
record page that sometimes carries a permanent decision, the veteran promotion. Right now
the promotion is easy to miss, easy to pick by accident, and hard to compare, and the
rest of the page says some things twice. This plan puts the decision first when there is
one, makes it a pick-then-confirm, and turns the rest into the same cards, tiles and
meters the Warband already uses.

Mockups: `mockups/captain-profile-promotion.png` (what you see when the screen opens) and
`mockups/captain-profile-full.png` (the whole page).

## What's there now

From a screenshot of Briony's Lances (34 battles, 18 kills, promotion ready):

1. **The one decision is halfway down.** The promotion comes after the hero, Character
   and Campaign record, below the first screen. Nothing at the top says it is waiting, and
   the Warband roster card doesn't either. `main_menu.gd` shows a specialization only
   after one is chosen and never checks `can_specialize`.
2. **One tap makes a permanent choice.** Each option is a plain `Page.button` that calls
   `GameState.specialize_captain` straight away. The four buttons fill most of the
   screen, so a scroll that starts on one can pick it. There's no confirmation, only a
   sound and a rebuilt page.
3. **The options are hard to compare.** Role, title and effects are one centered run of
   text, all the same size and color: "Scout: Eye of the Host\nExtends scouting sight…".
4. **The text gets the scope wrong.** It says "Choose a specialization for the company",
   but Scout, Quartermaster and Drillmaster are checked with
   `GameState.has_specialization`, which asks whether *any* captain holds the role. They
   apply to the whole host and don't stack, so a second Scout adds nothing. Only Champion
   applies to this company (`battle_sim.gd:1585`, `auto_resolve.gd:96`). The screen
   doesn't say who already holds each role.
5. **Things are said twice.** "Steadfast" appears three times: the hero line, the
   Character card title and that card's text. The record sentence ("led … through 34
   battles and was credited with 18 kills") repeats the tiles under it.
6. **Headings float.** Everything in the column is 20 apart, so a small grey heading
   sits as close to the section above it as to its own.
7. **The tiles are thin.** They have no icons, and "11 SQUAD" doesn't say 11 out of how
   many. The Warband shows the same company as "11/12".
8. **Company progress is a sentence** ("Level 3 · veteran company"). The Warband shows
   the same number as a meter.
9. **The only way out is at the end** of a page that grows with every bond and scar.

## The plan

### 1. Hero: who this is, at a glance

- Draw the portrait in the arched brass frame from `people.gd` (`_framed`). Move the
  frame into `Widgets` as `framed(art: Control, size, dim)` so both screens share it, and
  keep nearest filtering for the pixel captains.
- Show the captain's name in the display face, then "Captain of Briony's Lances", then
  "Knights · Level 3 veteran company" (SMALL, MUTED).
- Add a chip row with `Widgets.chip_row`:
  - Status: `▲ Active`, `▼ Wounded · back in 2` or `Fallen · Remembered`. The shapes
    let it read without color.
  - `★ Unique Companion` for heroes.
  - The role (`Champion`) once one is chosen.
  - A gold `★ Promotion ready` while `can_specialize` is true.
- Traits leave the hero. They're explained once, in Character.
- The hero replaces the big title and status line from `Page.column`. Give
  `Page.column` a way to skip an empty heading and subtitle rather than adding blank
  labels.

### 2. The promotion card, first when it's there

When `Captains.can_specialize(captain)` is true, a brass-bordered card sits right under
the hero, so it's on the first screen (see the mockup).

- **Header:** "VETERAN PROMOTION", with "Permanent" on the right.
- **One line of copy:** "Briony has earned a veteran role. Choose one; it can't be
  changed later." This replaces the "crucible of battle" paragraph.
- **Option rows**, one per role, in a fixed order. Each row shows:
  - The role's icon in a small dark tile: `o_eye` for Scout, `food` for
    Quartermaster, `o_book` or `o_shieldwall` for Drillmaster, `o_fight` for Champion.
  - The role name (BODY, TEXT), then the title in brass, then the scope in muted text:
    "Eye of the Host · Whole host" or "Hero of the Vanguard · This company".
  - The effects, one short line each with a ▲: "+30% scouting sight on the road",
    "Exact enemy numbers", "Half the ambush risk".
  - A radio circle on the right.
- **If another captain already holds a host-wide role,** that row says so with a ◆ in
  the middle tone: "Aldric already holds this. A second adds nothing." The row is muted,
  but you can still pick it, for example as a reserve if Aldric falls. The text stays
  above contrast; don't just fade it.
- **Picking selects, it doesn't commit.** The rows are toggle buttons in one
  `ButtonGroup`. The selected row gets a 4px brass border and a ✓ in the circle, a shape
  as well as a color. Each row gets an `accessibility_name` such as "Champion, Hero of
  the Vanguard, this company: +15% melee damage…".
- **Commit from the bottom bar.** While the card is shown, the bar holds Back and a
  primary button. The button is disabled and reads "Choose a role" until a row is
  selected, then reads "Promote to Champion". Pressing it calls
  `GameState.specialize_captain` and plays "charge", then rebuilds the page. The new role
  chip eases in with `Style.ease_in`, and a line under the hero reads "Briony is now the
  host's Champion." The promotion card is gone, and the role shows in Character.

New data in `captains.gd`, keeping `SPECIALIZATION_DESCRIPTIONS` for the journal note
and the existing tests:

```gdscript
const SPECIALIZATION_EFFECTS := {
	SCOUT: ["+30% scouting sight on the road", "Exact enemy numbers", "Half the ambush risk"],
	QUARTERMASTER: ["20% less food eaten", "+15% battlefield spoils", "Half the desertion risk"],
	DRILLMASTER: ["+25% combat experience", "Recruits dilute experience half as much"],
	CHAMPION: ["+15% melee damage and charge impact", "%s gains +25% vitality"],  # captain's first name
}
const SPECIALIZATION_SCOPE := {SCOUT: "host", QUARTERMASTER: "host", DRILLMASTER: "host", CHAMPION: "company"}
const SPECIALIZATION_ICONS := {SCOUT: "o_eye", QUARTERMASTER: "food", DRILLMASTER: "o_book", CHAMPION: "o_fight"}
```

Add `GameState.specialization_holder(spec) -> Dictionary`, which returns the captain
holding a role or `{}`. `has_specialization` can call it.

### 3. Campaign record: tiles, not a sentence

- Use `Widgets.tile_grid` with three tiles: `battle` 34 Battles, `o_skull` 18 Kills, and
  `men` 11/12 Men, with the full size from `Units.full_size` the same way the Warband
  gets it.
- For a living captain, drop the sentence. Keep only what the tiles can't show, as one
  muted line: "Recovering, back in 2" or "Survived 2 serious wounds."
- A fallen captain keeps the story (where they fell, who killed them, avenged), since it
  says something new.
- Check at 150% text. If three tiles don't fit across, fall back to two per row rather
  than shrinking the numbers.

### 4. Every section in a card

Wrap each section in `Widgets.card(title, aside)`, so its heading sits inside its own
content and sections are clearly apart. This fixes the floating headings without
touching the spacing.

- **Character:** temperament, then quirk, then role once chosen. Each has its name in
  brass and one line of what it does. This is the only place traits are explained.
- **Company:** "Level 3 of 3" as the aside, then a meter in level pips or
  `Widgets.meter` in brass. Under it, "1,240/1,500 experience toward training" or
  "Veteran company, fully trained". When `GameState.can_train` is true, add a gold
  "Ready to train in town" chip.
- **Bonds:** keep the portrait rows. Add a `Widgets.meter` in PLAYER_LIGHT toward the
  next rank, as the Warband's `_best_bond` does, and keep the effect line under it.
  Tapping a bond opens that captain's profile: set `active_captain_id` and rebuild.
- **History:** fallen friends and battle scars move into one card instead of two
  headings.

### 5. A pinned bottom bar

Move Back into a bar pinned to the bottom, using the `_bar` pattern from `people.gd`
(Back plus an optional primary button), so the exit is always in thumb reach. The scroll
gets bottom padding for it. The button reads "Back" with `o_back`, since it shares the
bar with "Promote to …".

### 6. Flag it in the Warband

On the roster card, when `can_specialize` is true, add a gold "★ Promotion ready" to the
captain line, where the role shows today. If the Warband tab badge can carry a count, it
counts captains ready for promotion.

### The fallen

A fallen captain's profile uses the same hero with a dimmed portrait and the "Fallen ·
Remembered" chip. Their words go in a quote card, followed by the record tiles (battles
and kills) and "Remembered by". There is no promotion card and no primary button.

## Tests

- `presentation_tests.gd`:
  - Open the profile of a captain who qualifies, at 150% text. The promotion card and
    Back are on screen, and `_check_widths` passes.
  - Change `button("Back to Warband")` to the new Back.
- `menu_tests.gd`:
  - Tapping a role doesn't set `specialization`, and "Promote to …" does.
  - A role held by another captain shows the warning.
  - After promotion, the card is gone and the role chip shows.
  - The roster card shows "Promotion ready" for a captain who qualifies.
- `captain_development_tests.gd`:
  - Every role has effects, a scope and an icon.
  - Champion's scope is "company" and the others' is "host".
  - `specialization_holder` finds the holder.

## Order of work

1. **The promotion:** the card, pick-then-confirm, the bottom bar, the scope and holder
   lines, and the Warband flag. This fixes the real problems: the promotion is missed,
   picked by accident, or picked when it adds nothing.
2. **The layout:** the hero, cards, record tiles, and taking out the repeats.
3. **Progress:** meters for the company and bonds, and tapping a bond to open that
   captain.

## To decide

- Should a role held by another captain be selectable at all, or only when it would
  matter (the holder is wounded or falls)? This plan keeps it selectable, with the
  warning.
- Should host-wide roles stack, or should a second holder stand in as a reserve? Today a
  second holder does nothing.
