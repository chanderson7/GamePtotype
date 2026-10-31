# Where to pick up

For a fresh session: read this, then `docs/phase-4-plan.md`. Don't re-read the whole
codebase; the plan names the files each step touches.

For the broader feature priorities and delivery packages, see
[`next-features-roadmap.md`](next-features-roadmap.md). The immediate gameplay task remains
Phase 4.3 siege resolution.

For art, battle feedback, dialogue staging and usability work, see
[`game-feel-and-presentation-plan.md`](game-feel-and-presentation-plan.md). It proposes
small polish slices that can accompany the gameplay roadmap.

For the next focused pass on travel atmosphere, lived-in settlements, a reactive company camp,
battlefield feel and consequence continuity, see
[`game-feel-and-immersion-roadmap.md`](game-feel-and-immersion-roadmap.md). Packages A and B—
The road feels alive and Places carry their condition—are implemented. Package C, Camp feels
like home, is the next immersion slice.

For a prioritized asset backlog, production briefs and artwork delivery packages, see
[`artwork-roadmap.md`](artwork-roadmap.md). Its first package—captain portrait continuity
and a reusable company camp—is implemented; siege resolution remains the next gameplay feature.

## State (on `main`)

- Phase 3 is done; every gate passes.
- Phase 4.1 (owners, wars, 21 settlements, save v5) and 4.2 (lords on the map) are done:
  see their "As built" notes in `docs/phase-4-plan.md`.
- Phase 4.3 is done:
  - Garrisons grow daily from treasuries, save accurately, and show in descriptions.
  - Marshal expeditions: saved membership, timed gathering, joint travel, and aggregate battles.
  - Sieges with walls (castle ×1.6, town ×1.4), ladder/ram prep, defender food starvation,
    relief battles, auto-resolved assaults, and settlement ownership transfer.
  - Attacking survivors stationed into garrison 1:1 (soldier conservation), bound villages follow,
    fief-holders become landless upon seat loss, capital relocates, and 15-man village militia resists raids.
- Phase 4.4 is done:
  - War weariness tracks losses, burnings, captures, and casualties; decays during peace.
  - Peace treaties, 30-day truce enforcement, and daily tribute transfers (20 days).
  - Autonomous war declarations for rested rivals; Ryumon Shogunate balance-of-power intervention when a mainland realm holds >= 4 of 6 mainland seats.
  - War Sheet on the map screen showing active wars, truces, tributes, realm strength/weariness, and recent chronicle events.
  - Fully deterministic save/load persistence. Verified with `tests/politics_tests.gd` (31 tests pass).
- Phase 4.5 in progress:
  - **Slice 4.5.1 done:** Realm & lord relations (-100 to 100), 30-day mercenary contracts ("Offer your sword"), scaled daily stipend, employer war alignment, hostile settlement market bar, warband financial forecast integration, and save/load roundtrip. Verified with `tests/mercenary_tests.gd` (37 tests pass).
  - **Next: Slice 4.5.2:** Meeting lords on the road (hostile lord road interception, friendly lord dialogues, following armies) and combined allied battles.
- Then 4.6, 4.7.

## Menu and onboarding update

Home now has a campaign summary, explicit replacement confirmation, Learn to play, and
Settings. The optional six-step tutorial can be selected at campaign creation or replayed
from Home/Settings. Map Menu opens Warband, Settings or Home. Audio settings are no longer
in Warband. Bonds introduce rank C, B and A milestones with saved pending and acknowledgment
state, and bonded deaths create a remembrance. The map's top-right resource icons are labeled and tappable;
low supplies warn early, and actual desertion pauses play with a saved, actionable warning.

`tests/menu_tests.gd` covers navigation, opt-in/replay, preferences, bond persistence,
resource controls and desertion warnings. Menu tests, relevant save/upkeep/captain checks,
and autoplay pass on Godot 4.7.2; phone-sized menus were rendered and inspected. Phase 4's
next gameplay piece is sieges.

## Experience Package A — The road feels alive

Travel now derives a presentation-only context from the party's actual position, route,
terrain, culture and time. Open road, woods, water, settlement-edge and night ambience crossfade
without affecting simulation RNG. Foot-heavy companies march, mounted companies use hoofbeats,
and map movement leaves restrained foot, dust or wake contact based on the actual route.

Entering from the map stages a factual, dismissible settlement arrival card using the existing
vista, owner and current condition. It clears in under a second, does not replay when returning
from a conversation, and has reduced-motion and text-only behavior. Presentation checks cover
context purity, stable cosmetic selection, sound assets and crossfades, movement types, a single
arrival overlay, accessibility variants and zero campaign-state mutation.

## Experience Package B — Places carry their condition

All 21 settlements now derive one presentation state from saved campaign facts: healthy,
strained, occupied, damaged or recovering. The procedural vista combines the place's original
architecture with its current owner's culture-specific banner, relation treatment, town/castle/
village activity, available-service props, garrison pressure, raid damage, rebuilding timber and
night lamps. The map uses the same damage, recovery and low-garrison facts.

Settlement sheets and arrival cards lead with the same compact condition sentence. Recent
capture or raid wording comes from the saved activity feed. Vardish, Kharzani and Ryumon places
have separate synthesized ambience loops. No presentation state is added to saves: reloads
reconstruct the same result without consuming campaign RNG. Text-only mode retains all condition,
owner, danger, service and garrison information. `tests/presentation_tests.gd` covers all 21
compositions, state transitions, save/reload, audio, missing-art behavior and 150% layout.

## Artwork Package A

Six captain portraits, one fallback and the company camp are integrated across Home, Warband,
battle cards, the first rank-C bond introduction and the memorial. Captain appearance IDs are
deterministic and additive to version 6 saves, do not consume campaign RNG, and survive death in
memorial records. Older campaigns acquire a stable ID when loaded. The illustrations preference
keeps the complete text, controls and tactical standards while hiding decorative art.

Source prompts and asset details are in [`../assets/captain-art-manifest.md`](../assets/captain-art-manifest.md);
the delivery record and next art packages are in [`artwork-roadmap.md`](artwork-roadmap.md).

## Experience improvements 1–3

The first three game-feel priorities are implemented as one connected battle-to-camp flow:

- Battle units have a narrower painted footprint, stronger hit sparks, charge/fall/rout
  bursts, persistent company destination marks, selected-order lines and visible links when
  established bonds are actively supporting nearby captains. These are presentation-only;
  collision, damage, morale and battle RNG are unchanged.
- Every living captain and modern memorial entry opens a full profile from its Warband card.
  The profile carries the stable portrait, status, company, troop role, trait explanations,
  battles, kills, squad progression and bond progress. Fallen profiles retain final words,
  campaign record and mourners.
- The battle result is a scrollable report with an outcome sentence, casualty tally, exact
  campaign rewards including chief/village bonuses, captain fate rolls, bond points/rank-ups,
  and per-company survivor, kill, XP and training information. The same report is saved as
  the last-battle record, using only additive version-6 data.

Focused battle-control and menu checks cover report reconciliation, training/bond/fate
details and profile navigation. The presentation regression remains green. Physical-phone
effect performance and haptics still need device review.

## Experience improvements 4–5

Warband now reads as a company overview. Its camp header carries a culture-colored company
banner, the next daily wage and ration payment is forecast with the remaining supplies, and
the roster can be sorted by role, strength, experience or captain. Active and wounded captains
have separate sections. Each company card shows troop strength, experience and strongest-bond
progress, opens the captain profile from the whole card, and restores the previous scroll
position on return.

Bond progression is visible beyond its combat bonus. Rank C, B and A each receive a paired
portrait milestone with the exact nearby morale and damage effects. Warband bond cards show
shared battles, rank progress and an optional camp conversation. These exchanges use saved
facts such as the last outcome, losses, current wounds and fallen friends, while changing no
resources, combat values or bond points. A bonded death is recorded in the survivor's history
and queues a saved memorial reaction. Old version-6 campaigns load with empty history records.

The focused menu suite and 78 presentation checks pass. Warband, rank-B and bond-conversation
screens were rendered and inspected at 720×1280; the roster and bond cards remain scrollable
and all controls fit at 150% text.

## Experience improvements 6–9

World readability, campaign guidance, sound variety and mobile comfort are implemented as
one campaign-navigation pass:

- Settlement previews and arrival pages now keep ownership, garrison strength, danger,
  available services/recruits and strategic value in readable text. Every settlement has a
  culture- and type-specific procedural arrival vista; current capitals carry a second banner
  and crown, while essential facts remain outside the art and survive text-only mode.
- Lone lords, bandits and active marshal armies have different map silhouettes. Marshal armies
  use a double brass ring and an explicit label. The saved activity feed retains the latest 24
  significant wars, captures, raids, battles and marshal movements after the transient event
  queue is consumed.
- Home and the map expose one factual recommendation based on food, earned training, a nearby
  bond rank, open company capacity, wounded ranks or recent world news. “Show” focuses a real
  place without beginning travel. Vulnerable-garrison recommendations wait for playable siege
  decisions, so the UI does not advertise an action that does not exist yet.
- New synthesized cues distinguish foot and cavalry movement, low morale, promotion and bond
  rank. Camp screens use a quiet fire/wind loop, settlement arrivals use subtle cultural UI
  pitches, and the existing synchronized battle layers still follow battle intensity.
- Map sheets use a two-column touch grid, settlement controls accept keyboard focus, pressed
  and disabled states are clearer, and settlement scroll position survives an audience subpage.
  Focused presentation coverage exercises settlement and map screens at 150% text.

The activity feed is the first Chronicle slice, not the full planned Journal: commitments,
deadlines and contracts remain dependent on their gameplay systems. Siege forces are currently
identified as marshal armies until siege state is implemented.

## Romance and allies feature (R0–R3 and three-candidate cast implemented)

The core Romance & Allies system is implemented per [`romance-and-allies-plan.md`](romance-and-allies-plan.md):
- Stable person & house IDs in `SocialSim`, with three persistent women: Edda at Ravensford, Farah at Qasr Hamra, and Kaede at Kitayama. Farah retains the legacy save key `farid` so existing campaigns remain compatible.
- Complete 5-chapter stories for Edda ("A Place Beneath the Banner"), Farah ("Words With Their Own Weight"), and Kaede ("The Account We Choose"), each with character-specific personal/shared scenes, honest vs. breach outcomes, repair restitution, public marriage, private vows, and sworn friendship pact.
- Support projects with strict escrow accounting (`total == remaining + spent + refunded`), daily recruit funding before realm treasury, capture-triggered refund, and emergency household grants respecting 300-silver lord reserve and 14-day global cooldown.
- UI: Settlement Court audience entry, People & Letters screen (`scenes/people.tscn`), interactive dialogue conversation (`scenes/conversation.tscn`), and "Romance invitations" toggle in Settings.
- Persistence & migration: Version 6 saves with deterministic v4/v5 migration.
- Tested: `tests/relationship_tests.gd` verifies all three complete routes and `tests/menu_tests.gd` covers their shared navigation and campaign HCI.

### Personal conversations (all three implemented)

Edda, Farah, and Kaede each have six optional backstory scenes, accessible through
**Spend time / memories** in People and their audiences. First visits require an introduction
and being at the candidate's current residence; strained relationships pause new visits.
Completed memories replay anywhere.
All responses and summaries receive equal treatment: +1 trust for the first three unique
completions, at most +3 per persistent person per campaign. Nothing else advances or costs
resources. Each unfinished visit can be resumed independently; replays preserve original
choices and relationship context. The final scene requires commitment or friendship.

Records are additive to version 6 saves, with empty defaults for existing campaigns.
Conversation writes use atomic save replacement and roll back on failure. See
[`romance-personal-conversations-plan.md`](romance-personal-conversations-plan.md) for the
content design, research, and implementation record.

Validation: 118 personal-conversation checks, 83 relationship-route checks, 120 presentation
checks, the menu suite, isolated disk-save/failure checks, and phone-sized library/reader views.

## Latest validation

Follow-up delivery (2026-10-29): collision correction is capped at **two** passes; shallow
contacts receive correction but do not trigger a second global pass. The eight collision
checks still pass. `tests/collision_profile.gd` alternates baseline/current order across
three seeds at 272 and 544 soldiers; see the presentation plan for measured results.
Battle controls add a persistent Selected/Whole army scope, Whole company selection,
Hold view/Re-center, frozen framing during gestures and a 0.85-second release grace period.
Unreachable single-squad moves are rejected before changing orders; accepted moves show a marker.
Eight battle-control checks pass and both battle controls and the army sheet were rendered at
405×720. No physical phone was available.

Marshal army checks cover conservation, deterministic muster/march reloads, unique membership,
peace/capture/marshal-loss interruption, muster timeout, group combat and old saves. The bounded
world/battle regression passes, including a simulated year with 73% of lords in the field,
no broke days, and a 1.84 ms world-hour average (2 ms gate). Loading social identity/progression
numbers now restores integer types, preserving exact world-save round trips. Siege captures,
siege food and player contracts remain future work.

Combat collision follow-up: approaching fighters stop just inside weapon reach instead of
stepping toward the target's center. Crowd separation uses full body radii and up to two
terrain-aware correction passes, rebuilding the spatial grid between passes and stopping
early when clear. This reduces persistent overlap without treating corpses as obstacles.
`tests/collision_tests.gd` covers cell boundaries, coincident positions, symmetric correction,
dead units, attack-distance rounding, dense crowds and water edges. Battle outcomes can change
because spacing affects contact; physical-phone performance and broad balance remain follow-ups.
Eight focused checks pass. Deployment/orders, bracing, steering and functional terrain checks
pass, including 684 soldiers remaining off impassable ground and 111 routing escapes.
Combat regressions also pass: shield walls, schiltron, volleys, cavalry disengagement and
repeat charges; braced spearmen beat cavalry and cavalry beat archers in all 12 test seeds each.
The broader terrain timing sweep exceeded its 240-second timeout after functional checks;
no new terrain-overhead gate result is claimed. The small three-battle comparison measured
about 1.08 ms/tick before and 2.12 ms/tick after, excluding rendering.

Presentation first slice: five-expression portrait sets for Edda, Farah, and Kaede;
Ravensford, Qasr Hamra, and Kitayama exteriors; three character-specific interiors;
paragraph reader with saved position/history/summary, and text-size/reduced-motion/art
preferences are implemented. See the implementation record in
[`game-feel-and-presentation-plan.md`](game-feel-and-presentation-plan.md) and
[`../assets/story-art-manifest.md`](../assets/story-art-manifest.md).
120 presentation checks and 118 personal-conversation checks pass, along with relationship
and menu regressions. Rendered 405×720 layouts were reviewed; physical-phone performance
remains untested. This does not complete the wider presentation roadmap or change the
living-world feature order.

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
