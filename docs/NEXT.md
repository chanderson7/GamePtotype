# Where to pick up

For a fresh session: read this, then `docs/phase-4-plan.md`. Don't re-read the whole
codebase; the plan names the files each step touches.

## State (on `main`)

- Phase 3 is done; every gate passes.
- Phase 4.1 (owners, wars, 21 settlements, save v5) and 4.2 (lords on the map) are done:
  see their "As built" notes in `docs/phase-4-plan.md`.
- Phase 4.3's garrisons are done: towns and castles recruit daily from their owner's
  treasury, keep their guards in saves, and show their strength in settlement descriptions.
- **Next: 4.3**, one piece per session, committing and pushing after each:
  1. Armies: a realm at war has its marshal (highest-renown lord) gather 2–3 lords and
     ride at an enemy castle or town.
  2. Sieges by auto-resolve with walls (castle ×1.6, town ×1.4), then
     `world.set_owner(id, realm)`. Gate: twice the garrison's strength takes it ≥ 80%.
     `set_owner` clears the old defenders; leave attacking survivors in `world.garrisons[id]`
     after transferring ownership. Village militia and siege food belong to this piece.
- Then 4.4 (war and peace), 4.5 (contracts and lord encounters), 4.6, 4.7.

## Menu and onboarding update

Home now has a campaign summary, explicit replacement confirmation, Learn to play, and
Settings. The optional six-step tutorial can be selected at campaign creation or replayed
from Home/Settings. Map Menu opens Warband, Settings or Home. Audio settings are no longer
in Warband. First rank-C bonds introduce themselves once per campaign, with saved pending
and acknowledgment state. The map's top-right resource icons are labeled and tappable;
low supplies warn early, and actual desertion pauses play with a saved, actionable warning.

`tests/menu_tests.gd` covers navigation, opt-in/replay, preferences, bond persistence,
resource controls and desertion warnings. Menu tests, relevant save/upkeep/captain checks,
and autoplay pass on Godot 4.7.2; phone-sized menus were rendered and inspected. Phase 4's
next gameplay piece remains armies.

## Romance and allies feature (R0–R3 implemented)

The core Romance & Allies system is implemented per [`romance-and-allies-plan.md`](romance-and-allies-plan.md):
- Stable person & house IDs in `SocialSim`, persistent candidate Edda anchored to Ravensford's household, and candidate stubs for Farid & Kaede.
- Complete 5-chapter story for Edda ("A Place Beneath the Banner") with personal/shared choices, honest vs. breach outcomes, repair restitution branch, public marriage, private vows, and sworn friendship pact.
- Support projects with strict escrow accounting (`total == remaining + spent + refunded`), daily recruit funding before realm treasury, capture-triggered refund, and emergency household grants respecting 300-silver lord reserve and 14-day global cooldown.
- UI: Settlement Court audience entry, People & Letters screen (`scenes/people.tscn`), interactive dialogue conversation (`scenes/conversation.tscn`), and "Romance invitations" toggle in Settings.
- Persistence & migration: Version 6 saves with deterministic v4/v5 migration.
- Tested: `tests/relationship_tests.gd` (48 automated checks, 0 failures) and `tests/menu_tests.gd` (all checks pass).

## Latest validation

Garrisons: focused checks and autoplay pass on macOS with Godot 4.7.2. The full regular
suite passes its functional checks, but hits two timing gates on this Intel Mac: terrain
overhead (hills +28%, woods +50%, pass +27%; limit +25%) and world hours (2.16 ms; limit
2 ms). An isolated rerun of the lord/year checks passes at 1.12 ms per hour, compared with
1.14 ms on the unchanged checkout. Battle code was not changed. The terrain timing failure
remains to be rechecked; the slow phase-end balance suite was not run for this piece.

## How to work here

- Godot 4.7 headless. If it isn't installed, download the standard Linux build into the
  scratchpad. Always run with `timeout`: a script that fails to parse leaves Godot idle
  forever.
- Tests: `godot --headless --path . --script res://tests/run_tests.gd` (about 10 minutes).
  `-- --balance` adds the slow gates (about an hour); run it only at the end of a phase.
- To run a few checks, copy `run_tests.gd` with an `_init()` that calls only those
  `_check_*` functions into `tests/_partial_*.gd` (ignored locally), and delete it after.
- `--check-only` can't see autoloads (`GameState`, `Sound`): "Identifier not found:
  GameState" is expected.
- Godot's JSON doesn't read every float back to the last bit; compare saved worlds as
  the lord save test does, not bit for bit.
- Battle gates are noisy: 48 battles move about ±10 points by chance. Check a surprising
  result on a second batch of seeds before tuning anything.
- The container can restart and kill background runs; re-run them.
- Don't commit `.uid` or `.import` files.
