# Bannerfall: game feel and immersion roadmap

- **Date:** 2026-10-30
- **Status:** Packages A and B implemented locally; Package C is the next immersion slice
- **Goal:** make every part of the campaign feel responsive, grounded and connected while
  preserving the current simulation rules.

This roadmap starts from the game as it exists now. Captain portraits, the company camp,
structured battle reports, resource warnings, settlement vistas, the map activity feed,
day/night lighting, battle particles, destination markers, bond presentation, contextual
sound and accessibility settings are already in place. The work below should deepen those
systems rather than replace them.

The intended experience is simple: the player should feel that they are leading one
recognizable company through places that remember what happened there. Orders should answer
immediately, battles should communicate danger before failure, and the aftermath should
follow the company back onto the campaign map and into camp.

## 1. Experience target

| Campaign moment | Desired feeling | Current foundation | Next improvement |
| --- | --- | --- | --- |
| Home | Orientation and anticipation | Campaign summary, recommendation and camp art | Let the camp reflect location, time, recent losses and current company state |
| Travel | Distance, risk and momentum | Moving parties, terrain map, day/night lighting and activity feed | Terrain ambience, restrained movement effects and brief arrival transitions |
| Settlement | Relief, identity and local tension | Condition-aware culture/type vista, ambient life, local sound, services, owner, danger and garrison facts | Carry recent settlement events into optional company reactions |
| Encounter | A readable decision under pressure | Factual sheets and force information | Stronger staging, commander identity and clearer consequences before committing |
| Battle | Command, impact and mounting pressure | Order feedback, collision, particles, camera response and layered battle sound | A cue director, formation-state animation, morale telegraphs and terrain contact |
| Results | Consequence and reflection | Detailed battle report and saved last-battle record | A short visual aftermath and direct continuity into the map and camp |
| Camp | Attachment, recovery and preparation | Captain profiles, portraits, bonds and memorial | A living company tableau with one optional, fact-based moment at a time |

## 2. Design rules

1. **Every effect must explain something.** Motion, sound and color should tell the player
   that an order was accepted, danger is rising, a formation changed state, or the world
   changed. Decorative effects stay quiet enough to preserve those signals.
2. **Use one dominant cue at a time.** A captain injury, morale break or victory may take
   priority over routine hits, movement sounds and ambient barks. Important feedback should
   never have to compete for attention.
3. **Carry events across screens.** A village raid should appear on the map, affect its
   arrival view, enter the chronicle and be available for one grounded camp reaction. This
   continuity creates more immersion than adding unrelated animations to each screen.
4. **Keep optional character material optional.** Camp remarks, personal conversations and
   quiet reactions should be available without becoming daily chores or modal interruptions.
5. **Derive prose from game facts.** Names, locations, owners, losses, shortages and recent
   events must come from saved state. Reusable writing can supply tone, but it cannot invent
   campaign history.
6. **Protect the simulation boundary.** Presentation code reads battle and world state. It
   does not consume campaign RNG, advance time, change damage, alter collision, spend
   resources or award relationship points.
7. **Design for the phone first.** Touch targets, large text, reduced motion, text-only mode
   and low visual density remain part of the primary design.

## 3. Priority roadmap

| Order | Package | Player value | Size | Dependency |
| --- | --- | --- | --- | --- |
| 1 | A. The road feels alive | Makes ordinary travel feel like part of the adventure | M | Current map and Sound systems |
| 2 | B. Places carry their condition | Gives settlements identity and visible history | M | Package A presentation context |
| 3 | C. Camp feels like home | Strengthens attachment to the company between battles | M | Existing portraits, profiles and activity feed |
| 4 | D. The battlefield communicates pressure | Improves responsiveness, clarity and impact | L | Current battle controls and collision work |
| 5 | E. Consequences follow the company | Connects results, map state and character reactions | M | Packages B and C |
| 6 | F. Sieges have campaign-scale presence | Makes settlement capture feel important | M | Core Phase 4.3 siege resolution |
| 7 | G. The broader cast becomes recognizable | Extends identity to lords and future routes | L | Stable lord encounters and authored character content |

Packages A through C should come before another broad art expansion. They reuse current art,
sound and data while improving the part of the game the player sees most often. Package D is
the next large feel pass. Package F should ship with or immediately after the core siege rules,
so presentation never blocks siege simulation work.

## 4. Package A — The road feels alive

**Implementation status:** complete on 2026-10-30. The delivered slice includes a read-only
travel context, crossfading terrain/time ambience, foot/cavalry/wake contact, a factual arrival
card and accessibility fallbacks. The sections below remain the acceptance record.

### Player outcome

Moving across the map should sound and feel different from standing still. Reaching a town,
castle or village should have a short sense of arrival without slowing repeated visits.

### First playable slice

- Build a read-only presentation context from current terrain, culture, time band, movement
  state, party type and nearest settlement.
- Crossfade among a small set of terrain ambience beds: open land, forest, coast/water,
  settlement edge and night. Silence remains an intentional part of the mix.
- Add subtle movement contact: foot dust, cavalry dust and water wake. Density follows actual
  party speed and stops immediately when the party stops.
- Present a brief arrival card when entering a settlement. It uses the existing vista and
  shows settlement name, type, realm and one current condition. The normal settlement screen
  remains interactive as soon as the card clears.
- Let a tap dismiss the card. Reduced motion changes it to an immediate static title; turning
  illustrations off uses a text-only version.

### Technical direction

- Keep context selection in `scripts/world/map_screen.gd` or a small presentation helper.
- Reuse `scripts/world/map_terrain.gd` and `scripts/data/cultures.gd` as read-only sources.
- Route ambience and crossfades through `scripts/audio/sound.gd`.
- Use stable hashes of location and day for cosmetic variation. Do not use campaign or battle
  RNG.
- Keep movement particles in the map renderer. They must never influence map pathing or world
  updates.

### Acceptance checks

- Moving, stopping, changing terrain and crossing into night update the ambience correctly.
- An arrival presentation clears within 0.9 seconds, can be dismissed immediately and never
  advances campaign time.
- Re-entering the same place does not stack cards or restart multiple ambience loops.
- Text-only, reduced-motion and 150% text modes remain usable at 405×720.
- Cosmetic effects produce no save differences and no change to movement or encounter timing.

### Likely files

- `scripts/world/map_screen.gd`
- `scripts/world/map_backdrop.gd`
- `scripts/world/map_terrain.gd`
- `scripts/world/settlement_screen.gd`
- `scripts/audio/sound.gd`
- `scripts/ui/style.gd`
- `tests/presentation_tests.gd`

## 5. Package B — Places carry their condition

**Implementation status:** complete on 2026-10-30. Five derived states—healthy, strained,
occupied, damaged and recovering—drive reusable procedural layers in the settlement vista and
map. Three culture-specific ambience loops, compact factual copy, saved activity-feed callbacks,
text-only fallback and all-21-settlement coverage are included. No new save field or simulation
rule was added. The sections below remain the acceptance record.

### Player outcome

A settlement should look owned, occupied, prosperous, strained, raided or recovering before
the player reads its statistics. The visual state must agree with the underlying world state.

### First playable slice

- Extend the procedural arrival vista with reusable layers for realm banners, local activity,
  damage/recovery, night lighting and garrison pressure.
- Give towns, castles and villages different ambient staging. Towns emphasize trade and
  crowds, castles emphasize guards and defenses, and villages emphasize work and fields.
- Reflect available services with props and people only when those services exist.
- Add one compact condition sentence ahead of the existing factual details. Examples include
  a recently raided village, a thinly held castle and a busy allied town.
- Give each culture a restrained palette accent and ambient sound family while retaining the
  shared interface and legibility.

### Art approach

Use layered assets instead of a bespoke painting for every settlement state. A practical
first set is:

- three culture banner families with friendly, neutral and hostile treatment;
- six transparent life props, such as market activity, smith smoke, guards, livestock,
  field workers and carts;
- three condition overlays: healthy, damaged and recovering;
- one night-light layer and one low-garrison treatment per settlement type.

The current vista remains the base composition. Every decorative layer needs a clean fallback
when illustrations are disabled or an asset is missing.

### Technical direction

- Compose the state in `scripts/ui/settlement_vista.gd` from `world_sim` facts already shown
  in text.
- Prefer existing raid, owner, service and garrison data. Add saved presentation state only
  when an important condition cannot be reconstructed after loading.
- Use the activity feed as the source for recent-event language instead of creating a second
  history log.

### Acceptance checks

- All 21 settlements produce a coherent culture/type composition without unique per-location
  code.
- Ownership, raid state, garrison pressure and services always agree with the settlement sheet.
- A missing layer leaves a complete, readable screen.
- A settlement state remains stable across save and reload.
- The composition works at 100% and 150% text without covering primary controls.

### Likely files

- `scripts/ui/settlement_vista.gd`
- `scripts/world/settlement_screen.gd`
- `scripts/world/world_sim.gd`
- `scripts/world/world_data.gd`
- `scripts/audio/sound.gd`
- `assets/` and an accompanying asset manifest

## 6. Package C — Camp feels like home

### Player outcome

Home should show the company as a group of people recovering, training and preparing in the
current world, rather than as a fixed background behind menu choices.

### First playable slice

- Build the camp tableau from current captains. Active captains stand near their formations,
  wounded captains rest, and fallen captains remain represented only through the memorial.
- Tint or layer the camp for broad time and terrain context from the company’s current map
  position.
- Surface one optional company moment at a time. Good candidates are a promotion, new bond
  rank, recovery, serious shortage, recent victory, defeat or death.
- Make each visible captain or event token open the relevant profile, bond scene, report or
  memorial entry.
- Add restrained idle motion and camp ambience. Reduced motion uses a static tableau.
- Remember dismissed moments so returning to Home does not repeat the same prompt.

### Content rules

- A moment may react to an event but has no hidden gameplay reward.
- A visit never forces the player through dialogue before using Home actions.
- One authored line can have temperament variants, but every factual noun and outcome comes
  from campaign state.
- Quiet visits are valid. The system should not invent drama when there is no meaningful event.

### Technical direction

- Extend `scripts/menu/main_menu.gd` and the current camp composition before creating another
  navigation destination.
- Reuse captain appearance IDs, profiles, bond milestone state, memorial data and the saved
  last-battle report.
- Store only acknowledgment keys for moments that should not repeat. Avoid a parallel quest or
  conversation-state system.

### Acceptance checks

- Active, wounded and fallen captain presentation matches the roster after load.
- A recent event produces at most one camp moment and can be dismissed without side effects.
- Every camp shortcut opens the correct existing record and returns to the same Home state.
- There is no mandatory daily interaction and no new resource, bond or relationship change.
- The camp remains useful and readable with illustrations off.

### Likely files

- `scripts/menu/main_menu.gd`
- `scripts/ui/captain_art.gd`
- `scripts/menu/captain_profile.gd`
- `scripts/menu/bond_conversation.gd`
- `scripts/game_state.gd`
- `scripts/audio/sound.gd`
- `tests/menu_tests.gd`

## 7. Package D — The battlefield communicates pressure

### Player outcome

The player should understand whether troops are marching, braced, engaged, wavering or
routing at a glance. Orders should feel immediate, while major events remain more forceful
than routine contact.

### First playable slice

#### Cue hierarchy

Add a presentation-only cue director with four levels:

1. **Critical:** captain wounded, formation breaks, defeat and victory.
2. **Command:** selection, destination set, charge, hold and formation response.
3. **Contact:** first clash, blocked strike, heavy hit, fall and ranged impact.
4. **Ambient:** footsteps, distant combat, minor particles and repeated weapon contact.

The director caps repeated contact sounds and particles, temporarily ducks lower levels for a
critical cue, and prevents screen shake from accumulating across many simultaneous hits.

#### Formation state

- Add readable movement cycles for foot and cavalry using current procedural unit art.
- Show a brief settle/brace response when a formation reaches a hold destination.
- Give wavering formations an early visual and audio warning before they rout.
- Keep routing units distinct from merely repositioning units.
- Add off-screen edge indicators for selected companies and immediate high-risk threats.

#### Terrain contact

- Use small dust, grass, mud or water contact effects selected by the actual battle terrain.
- Give arrows and charges distinct arrival sounds and particles.
- Keep all contact effects within a strict density budget so dense fights remain readable.

#### Optional haptics

- Provide light response for accepted orders and a stronger, short response for a decisive
  event on supported devices.
- Add a separate haptics setting. Reduced motion does not implicitly enable or disable it.

### Technical direction

- Keep combat outcomes in `scripts/battle/battle_sim.gd` authoritative.
- Let `scripts/battle/battle_screen.gd` translate simulation events into presentation cues.
- Introduce a small `BattleCueDirector` only if the event priority and cooldown rules become
  difficult to keep local to the screen.
- Extend `scripts/audio/sound.gd` with mix groups and priority-aware playback rather than
  independent calls that can overlap without limits.

### Acceptance checks

- Selection and order acknowledgment begin within 100 ms of the touch or click.
- A morale break is recognizable before routing movement begins.
- Critical cues remain clear during a dense multi-company clash.
- Reduced motion removes shake and large motion without removing state information.
- Presentation does not change damage, morale, collision, pathing, battle RNG or results.
- The reference phone targets 60 FPS and must remain playable above 30 FPS in the densest
  supported battle. Measure against the same saved battle before and after the pass.

### Likely files

- `scripts/battle/battle_screen.gd`
- `scripts/art/unit_art.gd`
- `scripts/art/sprite_data.gd`
- `scripts/audio/sound.gd`
- `scripts/menu/settings.gd`
- `scripts/game_state.gd`
- `tests/battle_controls_tests.gd`
- `tests/collision_tests.gd`

## 8. Package E — Consequences follow the company

### Player outcome

The player should see a major battle, raid, capture or loss echo through the next few screens.
This makes the campaign feel persistent without requiring a large new narrative simulation.

### First playable slice

- Preserve a compact recent-event reference for battles, raids, captures, deaths and major
  promotions. Reuse the saved activity feed where it already contains the needed facts.
- Show short-lived map aftermath: smoke near a raid, a recent-battle marker, a changed banner
  after capture and a recovery treatment after damage.
- Let the result screen name the affected place and provide a direct return path to its map or
  settlement context when appropriate.
- Allow one captain camp reaction chosen from the actual participants, survivors, bond partners
  or mourners. The reaction is optional and acknowledged once.
- Expire purely visual aftermath after a clear number of campaign days while retaining the
  permanent chronicle entry.

### Suggested recent-event record

Only add fields that cannot be recovered from the activity feed:

```text
event_id
event_type
day
location_id
actor_ids
subject_ids
outcome_key
acknowledgment_keys
visual_expiry_day
```

Use stable IDs and templates. Do not save rendered prose, screen positions or particle state.

### Acceptance checks

- A qualifying event can be traced from results to map and camp without contradictory details.
- Save/reload preserves the current aftermath and its acknowledgment state.
- Expired decoration disappears while the activity record remains.
- Repeated visits do not replay the same reaction.
- Small routine encounters do not fill the map or camp with high-priority cues.

### Likely files

- `scripts/world/world_sim.gd`
- `scripts/world/map_screen.gd`
- `scripts/menu/main_menu.gd`
- `scripts/game_state.gd`
- `scripts/data/event_reactions.gd` (new)
- `tests/presentation_tests.gd`
- `tests/menu_tests.gd`

## 9. Package F — Sieges have campaign-scale presence

This package depends on the core Phase 4.3 siege resolution described in `NEXT.md`. Build the
rules and save behavior first, then present those facts consistently.

### Presentation scope

- Show a siege ring, attacker camp and blocked settlement marker on the map.
- Stage the siege sheet around attacker strength, defender strength, walls, supplies and likely
  outside relief.
- Reflect wall condition and blockade pressure in the settlement vista.
- Give assault, relief, withdrawal and capture distinct result treatments.
- Carry ownership change into banners, ambience, recent-event presentation and the camp.
- Show surviving attackers taking the garrison role after capture, matching the core rule.

### Acceptance checks

- Every displayed value comes from the same state used by auto-resolve.
- Leaving and reopening a siege shows the same participants and wall state.
- Capture presentation occurs only after ownership and garrison transfer succeed.
- A text-only siege screen exposes all decision-relevant information.
- Siege art remains additive; it cannot delay or alter resolution.

## 10. Package G — The broader cast becomes recognizable

This is a later content package, best started once lord encounters and future relationship
routes are stable.

- Give recurring lords portrait archetypes, heraldry and one readable temperament cue.
- Add expression variants for characters only when they have enough authored scenes to reuse
  them.
- Write short pre-battle, post-battle and camp reactions tied to real events and established
  temperament.
- Use recurring visual motifs for realm, family and personal history.
- Expand optional personal conversations in small authored sets with clear replay behavior.
- Keep social rewards explicit. Pure backstory scenes remain safe to read without optimizing
  for relationship points.

The current captain art and conversation reader define the technical pattern. The
[`artwork-roadmap.md`](artwork-roadmap.md) remains the source for asset briefs and production
tracking.

## 11. Cross-cutting sound plan

Sound should support every package rather than arrive as a separate late pass.

### Mix groups

- Music
- World ambience
- Movement
- Battle contact
- Commands and voices
- Interface
- Critical stingers

Each group needs its own concurrency and volume rules inside `Sound`. Critical stingers may
briefly lower battle contact and ambience. Interface feedback stays audible without becoming
louder than battle events.

### Content priorities

1. Terrain and time ambience for travel.
2. Settlement culture and condition layers.
3. Camp idle and recovery layers.
4. Formation movement, morale warning and ranged/charge distinction.
5. Siege blockade, assault and capture cues.

Use short families with small pitch/timing variation and meaningful silence. Production audio
should use compressed imports where practical; raw generated sources can remain in the source
manifest outside the shipped build.

Audio-only information needs a visible equivalent. A morale warning, arrival, captain injury
or siege update must still be clear with sound disabled.

## 12. Cross-cutting comfort and accessibility plan

- Add screen-shake intensity or an explicit off setting in addition to reduced motion.
- Add haptics on/off when haptics are introduced.
- Keep color-independent icons and motion/state changes for friendly, hostile, wounded,
  wavering and routing states.
- Preserve complete text when illustrations are off.
- Restore scroll and focus position after opening profiles, reports and conversations.
- Keep primary touch targets at least 44 logical pixels in both dimensions.
- Avoid time-sensitive reading outside battle. Battle alerts persist long enough to recognize
  their associated state.
- Maintain 100%, 125% and 150% text checks for every new screen and overlay.

## 13. Presentation budgets

These are starting constraints to validate on the reference phone:

| Area | Starting budget |
| --- | --- |
| Blocking transition | 0.9 seconds maximum; always dismissible |
| High-priority overlays | One at a time |
| Map ambience | Up to two continuous layers plus one occasional accent |
| Battle critical cue | One dominant stinger/shake event at a time |
| Repeated contact cue | Per-kind cooldown and global concurrency cap |
| Camp moments | One surfaced per Home visit; each event acknowledged once |
| Cosmetic variation | Stable hash only; no campaign or battle RNG |
| Dense battle performance | 60 FPS target, 30 FPS minimum on the reference phone |

If an effect exceeds a budget, simplify the effect before reducing tactical information.

## 14. Validation plan

### Automated checks

- Presentation actions do not advance time or change resources.
- Cosmetic selection does not consume campaign or battle RNG.
- Arrival and camp acknowledgments survive save/reload.
- Recent-event expiry is deterministic.
- Cue priorities and cooldowns cap duplicates.
- Reduced-motion, illustrations-off, sound-off and 150% text paths remain complete.
- Existing collision, battle controls, relationships, menu and autoplay suites stay green.

### Visual capture matrix

Capture the affected screen at 405×720 for:

- 100% and 150% text;
- reduced motion on and off;
- illustrations on and off;
- day and night;
- each culture;
- friendly and hostile ownership;
- healthy, damaged and recovering settlement conditions;
- quiet and dense battle states.

Favor structural assertions and reviewed captures over brittle full-pixel golden tests.

### Fifteen-minute playtest route

1. Open Home and identify the next useful action within three seconds.
2. Travel across at least two terrain types and arrive at a settlement.
3. Inspect the settlement condition, services and local danger.
4. Enter one battle, issue move/hold/charge orders and observe one morale break.
5. Read the result, return to the map and visit Home.
6. Confirm that the same event appears consistently in aftermath, chronicle and camp.

Record where the player hesitates, which sound or visual cues overlap, whether any transition
feels repetitive, and whether they can explain why the last battle mattered.

### Physical-device review

- Measure frame pacing in the densest supported battle before and after Package D.
- Check touch latency, accidental taps and edge indicators while panning.
- Listen through phone speakers and headphones at low volume.
- Check thermal behavior during 20 minutes of map travel and repeated battles.
- Verify haptics on a supported device and confirm the toggle applies immediately.

## 15. Risks and controls

| Risk | Control |
| --- | --- |
| Repetition makes ambience irritating | Use cooldowns, variation and intentional silence |
| Decorative layers hide actionable information | Apply the cue hierarchy and density budgets |
| Bespoke art grows faster than the game | Build culture/type/state layers that combine across locations |
| Flavor text contradicts the simulation | Generate facts first, then apply authored tone templates |
| Save data grows into a second history system | Reuse the 24-entry activity feed and save only missing acknowledgment/state keys |
| Presentation changes combat outcomes | Keep event translation read-only and compare identical saved battles |
| Mobile performance falls during dense fights | Pool effects, cap concurrency and test on the reference phone each slice |
| Optional character content feels mandatory | Avoid hidden rewards and surface no more than one moment per visit |

## 16. Deferred scope

The following ideas should wait until the packages above prove their value:

- full voice acting;
- bespoke interior scenes for every service;
- dynamic weather that changes combat rules;
- seasons and a calendar simulation;
- cinematics longer than the dismissible arrival/result beats;
- unique art for all 21 settlements;
- a second relationship currency or hidden social bonuses;
- large procedural dialogue systems;
- broad lord portrait production before lord encounters are stable.

## 17. Package A implementation record and next request

Package A delivered:

1. Added a read-only travel presentation context.
2. Added terrain/time ambience crossfades with concurrency guards.
3. Added speed-driven foot, cavalry and water movement contact.
4. Added the dismissible settlement arrival card using current vista art.
5. Wired reduced motion, illustrations-off and sound-off behavior.
6. Added focused presentation tests for phone-sized and 150% text layouts.

The slice is complete when a route across two terrain types into a settlement feels continuous,
all accessibility variants remain usable, save data is unchanged, and an identical campaign
replay reaches the same world state with presentation enabled or disabled.

Package B now supplies the reusable owner, activity, damage/recovery, night and garrison layers
described above. The next immersion request is **Package C: Camp feels like home**: derive a
company tableau from current captains, wounds, losses, terrain, time and one optional recent
moment while preserving the same presentation-only boundary.
