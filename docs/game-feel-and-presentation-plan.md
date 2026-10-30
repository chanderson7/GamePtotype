# Bannerfall: game feel, art and player experience

**Date:** 2026-10-28

**Status:** the first presentation slice, captain continuity, tactical feedback, captain
profiles, the structured battle aftermath, the Warband overview and visible bond progression
are implemented locally through 2026-10-29;
remaining items are future proposals, with experience priorities 1–9 implemented through
2026-10-29.
The recommendations come from source inspection and the references below; they are not
claims from a new player study or a completed art pass. Timing values and asset budgets
are starting targets to validate in playtests.

This complements [the feature roadmap](next-features-roadmap.md). That roadmap expands
what the player can do; this plan improves how existing actions look, sound, read and feel.
The living-world implementation order in [NEXT.md](NEXT.md) remains unchanged.

For the post-priorities-1–9 implementation order, acceptance checks and current recommended
slice, see the [game feel and immersion roadmap](game-feel-and-immersion-roadmap.md).

The [artwork roadmap](artwork-roadmap.md) expands the remaining art work into asset briefs,
quantities, screen placements, production constraints and a proposed delivery order.

### First slice implementation record

- Edda, Farah, and Kaede each have five original portraits: neutral, amused, thoughtful,
  concerned and warm. Their faces are reused in People, audiences, and the conversation reader.
- Ravensford, Qasr Hamra, and Kitayama have illustrated exteriors, while each candidate has
  a distinct interior conversation backdrop. These static illustrations do not change simulation.
- All 18 personal scenes use speaker-labelled paragraphs, Previous/Continue controls,
  history, summaries and an always-available Leave action. Each reading position persists;
  archived playback stays local and does not change rewards or campaign records.
- Reader version 1 is separate from authored content version 1. Old interrupted visits start
  at the first paragraph of their existing passage, preserving choices and completion state.
- Settings persist 100/125/150% text, reduced motion and illustrations on/off. Reduced motion
  removes shared panel/button animation, title drift and battle camera shake. Large display
  headings grow less than body text. This is not a complete accessibility audit of all screens.
- Twenty-one PNG assets total roughly 7.7 MB on disk: fifteen 384×512 transparent portraits
  and six 768×512 locations. [Asset provenance and exact prompts](../assets/story-art-manifest.md)
  document built-in image generation and exports. Missing art leaves text/navigation usable.
- Validation: 120 presentation checks, 118 personal-conversation checks, relationship and menu
  regression suites; rendered 405×720 reader, large text, text-only, People and settlement
  screens. Settlement court buttons now wrap instead of widening the page. No physical-phone
  performance test was performed. Headless teardown reports resource-leak warnings separately
  from the passing assertions.

Every settlement now has a culture/type arrival vista plus factual ownership, garrison, danger,
services and strategic-value text. The map has distinct force markers, a saved 24-entry activity
feed and factual Home/map recommendations. Foot/cavalry movement, low morale, camp, promotion
and bond-rank cues extend the procedural audio library. Map sheets use a two-column touch layout,
settlement subpages preserve their scroll position, and focused 150% text checks cover the new
campaign surfaces. The sections below retain the remaining wider implementation plan.

## 1. Recommended direction

Make Bannerfall feel like **leading a recognizable company through a lived-in world**.
The highest-value improvements are faces, places, clear orders and memorable aftermaths.

Start with four connected upgrades:

1. Give Edda and the captains recognizable portraits that follow them across screens.
2. Give settlements and conversations illustrated settings with restrained ambient motion.
3. Make every tactical order immediately clear: who received it, what they will do, and
   why an order was rejected or interrupted.
4. Turn battle results into a short account of the company's experience, with an immediate
   exit available for players who want to keep moving.

These improvements can make the existing campaign feel substantially richer before another
large system is added. Keep routine travel, shopping and repeated battles quick. Reserve
stronger staging for a first meeting, an important promotion, a narrow victory or a death.

### Experience principles

- **Recognizable people:** a name, face, voice and history belong to the same person.
- **Readable command:** visual polish helps the player understand the battle.
- **A rhythm of pressure and rest:** a dangerous road, a decisive fight, then a quieter
  settlement or conversation.
- **Consequences with context:** show what happened and what the player can do next.
- **Optional intimacy:** conversations deepen attachment without becoming daily chores.
- **Consistent identity:** portraits, sprites, banners, icons, music and prose belong to
  the same setting.

## 2. Current foundation and the opportunity

| Already in the game | Improvement to pursue |
| --- | --- |
| Culture-specific soldiers, troop portraits, settlements and a detailed animated map | Distinct person portraits and illustrated interiors, with a shared art guide |
| Dawn map backdrop on Home | A more personal Continue card tied to the current company |
| Charge hit-stop, shake and handheld vibration | Better intensity limits, user controls and event priorities |
| Animated standards, rout/flank callouts, target markers and order feedback | Clearer command scope, movement feedback and fewer competing notifications |
| Automatic battle camera and pause-with-orders | Stable camera behavior while issuing orders; optional camera control modes |
| Two-layer battle music, cultural tracks, ambience and victory/defeat stingers | Better contextual mixing, ambient variety and quieter emotional scenes |
| Persistent captains, death rolls, bonds and a memorial | Faces, restrained character reactions and stronger battle aftermaths |
| Edda's main and optional conversations, summaries, resume and archive | A staged dialogue reader with expressions and scene-specific props |
| Resource icons, low-supply warnings and desertion messages | More understandable financial choices and recovery guidance |
| Scrollable menus, safe areas, large touch targets and keyboard focus | More consistent hierarchy, text sizing and reduced-motion controls |

The existing effects should be audited before adding new ones. For example, a charge already
has a 0.06-second hit-stop and a captain's death roll already occupies a 4.2-second dramatic
presentation. More pauses and shake would not automatically improve either moment.

## 3. Reference lessons worth adapting

The following are observations from the named games. The proposed Bannerfall treatments
are design recommendations, not claims that those games implement the same treatment.

| Reference observation | Lesson for Bannerfall |
| --- | --- |
| TaleWorlds' audio director describes sound as a way to convey physical action and discusses the cost of many individual sounds. [Bannerlord audio development blog](https://www.taleworlds.com/en/Games/Bannerlord/Blog/95) | Prioritize audible meaning and use bounded sound groups for a busy battle. |
| Bannerlord's soundtrack distinguishes campaign/combat music and culture-related tavern material. [Official soundtrack release](https://www.taleworlds.com/en/News/538) | Let a place sound different from the road and the battle; build on the cultural tracks already present. |
| Three Houses combines social exploration and support scenes with battlefield preparation, threat information and predictions. [Nintendo's Three Houses guide](https://www.nintendo.com/au/news-and-articles/fire-emblem-three-houses-101/) | Pair attachment to characters with clear tactical information and a quiet place to see them between fights. |
| Engage's developers discuss distinctive character colors, expressions and movement, including the appeal of earlier pixel-art battle animation. [Nintendo developer interview](https://www.nintendo.com/us/whatsnew/ask-the-developer-vol-8-fire-emblem-engage-part-2/) | Give characters readable silhouettes and expressions; use a few strong animation poses instead of adding indiscriminate motion. |

For Bannerfall's real-time squad scale, adapt these principles to compact portraits,
short expressive moments and tactical overlays. A large walkable monastery, a fully voiced
cast or frequent individual combat cutaways would carry a much larger cost. Use original
characters, art, dialogue and music throughout.

## 4. Priority map

**P1:** first polish release. **P2:** expand after the first coherent presentation pass.
**P3:** optional later investment. Size includes integration: S is a small adjustment,
M spans several screens/assets, and L needs separate implementation slices.

| ID | Improvement | Priority | Size | First useful deliverable |
| --- | --- | --- | --- | --- |
| F01 | Character portraits and identity | P1 | M | Edda in People, dialogue and memories; one captain prototype |
| F02 | Settlement and conversation art | P1 | M | Ravensford exterior, common room and camp backdrop |
| F03 | Expressive dialogue presentation | P1 | M | Edda's Spare Spoon scene with expressions, history and summary |
| F04 | Command and camera clarity | P1 | M | Clear order scope and stable touch targeting |
| F05 | Impact feedback and accessibility controls | P1 | S–M | Tune existing effects; add shake/haptic/reduced-motion settings |
| F06 | Battle aftermath and memorial presentation | P1 | M | Accurate result cards and a captain remembrance panel |
| F07 | Contextual audio and ambience | P2 | M | Settlement, camp and dialogue mixes using existing music |
| F08 | Company identity and visible growth | P2 | M | Persistent company name, crest and veteran presentation |
| F09 | Travel, shopping and journal usability | P1/P2 | M | Clear costs, destination links and contextual return actions |
| F10 | Optional camp moments and world reactions | P2 | M | One state-aware quiet hub and a few event-based conversations |
| F11 | Menu, accessibility and session continuity | P1, ongoing | M | Larger text, readable states and graceful return after interruption |
| F12 | Practice encounters and presentation replay | P3 | M | One optional short tactics exercise, separate from the campaign |

Start F01–F03 as one small art-and-dialogue slice. F04–F05 can improve battles without
waiting for the full art library. F06 makes those battles matter afterward.

## 5. F01 — Give people faces that persist

### Named characters

Create a portrait sheet for Edda first: **neutral, amused, thoughtful, concerned and warm**.
Use posture, eyebrows and eye direction; avoid making every emotional change a large pose.
Her practical clothes, restrained expression and a small work-related detail should fit
her established voice. Expressions describe the line being spoken, not a score for whether
the player picked the right answer.

Equivalent five-expression sheets for Farah and Kaede are implemented with their full routes.
Each preserves a distinct silhouette, wardrobe, and emotional register in the shared reader.

### Captains

The current unit icons communicate equipment. Add a separate personal face for each captain
so two captains of the same troop type do not become visually interchangeable.

- Prototype a small compatible set of heads, hair, facial hair, age details and accessories.
- Select appearance once and save an appearance ID/recipe on the captain. Loading a game,
  changing unit branch or replacing a portrait asset must not reroll their face.
- Keep the portrait on the roster, battle selection card, death-roll panel and memorial.
- Give a replacement captain a new identity while preserving the predecessor's memorial.
- Express wounds with a modest bandage or tired pose, without obscuring identification.
- Keep named-cast portrait art and generated-captain art under the same palette and lighting
  rules. Broadly support different ages, builds and appearances within each culture.

**Acceptance:** players can match a captain between battle and roster without reading the
name; portraits remain stable after save/load and promotion; absent assets have a dignified
fallback; names and status are always readable without interpreting an expression.

## 6. F02 — Make destinations feel like places

### Settlement arrival panels

Replace the visually uniform top of the settlement list with a compact illustrated header.
Keep buying food and returning to the map easy to reach; the illustration is not a loading
screen the player must wait through.

The header should combine:

- A distinct architectural silhouette and one recognizable landmark.
- Settlement name, local culture and current holder's banner as separate information.
- Small ambience: chimney smoke, a hanging cloth, lamplight or water.
- Context already represented in the world: day/night, a burned village or changed owner.
- A short, state-accurate arrival line. Avoid claiming prosperity, poverty or peace unless
  the game actually tracks enough information to justify it.

A captured Kharzani settlement should retain its Kharzani buildings while its owner's banner
changes. Cosmetic rain or seasonal art should not imply a combat modifier that does not exist.

### Art expansion order

1. Ravensford exterior, a flexible common room and a company camp.
2. One Kharzani and one Ryumon settlement exterior, with matching prop treatments.
3. Village and castle variations for all three cultures, then a few named landmarks.
4. Occasional major-event illustrations only after frequently visited screens are covered.

Use reusable foreground props and light overlays instead of separate full paintings for
every possible state. Prioritize assets that appear in several real flows.

**Acceptance:** the player can identify the location type and culture quickly; captures
change the right banner; art never hides controls; reduced motion produces a stable scene;
new images load without a visible stall on the target phone.

## 7. F03 — Stage conversations without slowing them down

The existing reader already handles branching replies, summaries, resume and replay. Keep
those contracts while adding speaker presence.

### Layout

- A compact character portrait beside a clearly labeled speaker, above readable dialogue.
- An illustrated setting that changes by scene, with a darkened text surface for contrast.
- Short dialogue beats rather than one large undifferentiated passage. Keep a conversation
  history available so the player can reread earlier lines.
- Responses as full-width buttons, with no hover-only clues or hidden good-answer styling.
- Summary, exit and history controls reachable without scrolling through the whole passage.
- Default text appears immediately. Optional typewriter text supports tap-to-reveal; that
  first tap must not also choose a reply or skip the next beat.
- Saving/resuming retains the line/beat and response, not just the general scene.

### Pilot: The Spare Spoon

Use a warm table corner, two visible places, a sticking drawer and Edda's portrait.
Start with her thoughtful expression as she counts. Switch to amused after the player
notices the missing place; finish with a warmer, settled pose. A quiet utensil sound can
punctuate the correction. The prop is decorative: no item or food transaction occurs.

Different replies can receive different expressions while keeping the current equal reward.
The summary path and replay keep their existing behavior, including the +3 campaign cap.
Use a visible memory treatment when recalling an earlier romantic context after separation.

**Acceptance:** every current scene is readable with art disabled; summary/replay rewards
are unchanged; text enlargement reflows; a save at every beat resumes correctly; missing
portrait/setting data never prevents completion.

## 8. F04 — Make issuing orders feel precise

### Selection and command scope

- Keep the selected captain's name, squad type and current order in a consistent location.
- Make **selected squad** versus **whole company** explicit beside order buttons. Switching
  scope should be visible before the player commits a command.
- Give an accepted command a quick marker and an order label. Update it only after the
  command is valid; use a reason such as “No route to that ground” for a rejected move.
- Show a lightweight path/formation preview while positioning, using actual path data where
  available. Use an approximate destination marker if no reliable preview can be supplied.
- When an attack target routs or a squad abandons its order, explain the resulting state.
- Permit repositioning freely during deployment; show exactly what Advance gives up when a
  squad is braced. Reuse existing terrain hints and counter indicators.

**Starting response target:** acknowledgement within 100 ms of an accepted tap on the
baseline device. This measures UI feedback, not how quickly soldiers physically turn.

### Camera

- Stop automatic zoom/reframing while a touch gesture is selecting or drawing a formation.
- Resume following smoothly after a short grace period, initially 0.75–1 second.
- Offer Follow battle and Hold view modes, with a visible re-center control.
- Keep selected squads and major threats readable without snapping across the map whenever
  a unit routs. Offscreen alerts can point to an event without moving the camera.
- Keep cinematic shake separate from world hit-testing, so a vibrating image cannot shift
  the ground location that receives an order.

### Tactical inspection

While paused, show selected ranged reach, meaningful terrain effects and current morale
state. Treat encounter losses as estimates with reasons. Do not promise exact damage or
future enemy positions in a real-time fight.

**Acceptance:** repeated taps do not duplicate orders; dragging is stable during charge
feedback; pause accepts deliberate commands; changing view mode never changes simulation
state; a new player can explain which soldiers will act before pressing Advance.

## 9. F05 — Refine impact, animation and effect priority

**Collision follow-up implemented locally (2026-10-28):** fighters approach to weapon
reach rather than the target's center, with a small rounding allowance to avoid stalled
attacks. Body separation now respects full radii and runs up to two bounded passes,
rebuilding contact cells between passes. Existing terrain sliding and routing exits remain.
This reduces crowd interpenetration; it is not rigid-body physics or a guarantee that
sprites never visually overlap. Corpses do not block movement.

Eight focused checks cover dense crowds, opposing contact, grid boundaries, coincident
positions, dead units, approach distance, attack rounding and water boundaries. In three
seeded 84-soldier mixed-unit battles, summed sampled penetration fell from 14,106 to 2,514
world units; the runs lasted 2,320 versus 1,966 ticks, so this is an exploratory comparison,
not a controlled balance result. Average simulation cost increased from about 1.08 to
2.12 ms/tick on this Mac, excluding rendering. Target-phone performance and wider balance
still need validation before calling this polish complete.
Functional terrain checks pass; the broader terrain timing sweep exceeded a 240-second
timeout, so its overhead gate remains unverified for this change.

Build on the current charge freeze, shake, vibration, standards and callouts. Do not layer
a second independent effect system over them.

| Event | Recommended emphasis | Limit |
| --- | --- | --- |
| Order accepted | Banner response, destination mark, restrained confirmation sound | No camera shake |
| Formation braces | Clear silhouette/stance and brief status indicator | Once on entering the state |
| Cavalry connects | Dust, directional impact, stronger sound, optional brief existing hit-stop | Coalesce simultaneous charges; avoid repeated global freezes |
| Volley released | Synchronized release pose and distinct bow/crossbow sound | Emphasize the squad action rather than every arrow |
| Enemy routs | Falling standard and short directional cue | Aggregate simultaneous rout notices |
| Friendly flank or rear hit | Directional marker and specific warning | Suppress repeated warnings for the same continuing situation |
| Captain falls | Portrait, resolved fate and optional dramatic presentation | One foreground presentation; queue/coalesce safely |
| Objective resolved | One clear completion/failure message | Never repeat after reload or results refresh |

### Animation work

Add or refine a few useful states: anticipation, attack contact, recovery, braced stance,
routing and rallying. Favor readable silhouettes at the real phone zoom. Dust should match
the surface; wood/metal impacts should match the action. Persistent corpses or debris need
caps and fading so the battlefield stays readable.

Keep visual anticipation aligned with simulation contact. Do not move the damage moment
just to fit a longer animation without treating that as a separate balance change.

### User controls

Add shake intensity, haptics on/off, reduced motion, and full/compact dramatic moments.
Compact death-roll presentation still shows the already-resolved odds and outcome and
preserves acknowledgement. Skipping animation never rerolls a fate or changes a reward.
Keep pause controls responsive while presentation events are queued.

**Acceptance:** a busy multi-squad fight remains readable; reduced motion removes shake and
large zoom/scale transitions; haptics can be fully disabled; repeated presentation events
do not multiply effects; presentation RNG never consumes battle or world RNG.

## 10. F06 — Give victories, losses and promotions room to land

### Battle report

Keep a short summary first, with details available immediately:

1. Outcome and the actual reason: held the village, routed the enemy, withdrew, or lost.
2. Company casualties, captain fates and survivors.
3. Actual resolved silver, food and renown, including special objective rewards.
4. One or two notable contributions backed by tracked events.
5. A sensible next action: return to the map, review the warband, or inspect a fallen captain.

Present all numbers as the authoritative result/transaction, not a second UI calculation.
Animating a reward counter must not apply it again. Until troop wounds exist, keep the
existing casualty categories; do not display a fictional wounded-soldier count.

A costly victory should feel different from an easy one. Let the title remain Victory,
but soften the music and show the lost captain rather than covering the screen in rewards.
A defeat report should explain remaining men, location and recovery options without shaming
the player or promising they can immediately afford replacement troops.

### Captain remembrance and growth

- Give the memorial a saved portrait, company name, last words and verified service history.
- Offer an optional short remembrance if a surviving bonded captain exists. Do not invent a
  witness or a shared battle that did not occur.
- Mark promotions with a brief before/after silhouette or equipment change, including new
  wages and abilities. The player can skip the presentation and inspect the change later.
- Award a narrative battle distinction only from sufficient event data. Avoid claiming
  “saved everyone” from a simple kill-count maximum.

**Acceptance:** the report exactly matches the resulting campaign state; Send in and played
battles use consistent categories; returning twice cannot pay twice; animation can be
skipped; history still makes sense after a captain dies or a squad changes branch.

## 11. F07 — Let sound explain the place and the moment

The current crossfades and two-layer battle music provide a useful foundation. Evaluate the
actual recordings and phone mix before commissioning a replacement soundtrack.

### First audio pass

- Mix priorities: essential warning, selected command, nearby combat, general crowd, ambience.
- Add quieter ambience to settlement, camp and conversation contexts. Use short randomized
  variations and cooldowns to avoid a conspicuous identical loop.
- Extend the current cultural themes with a restrained settlement/camp arrangement before
  writing a separate track for every screen.
- Duck nonessential ambience briefly under critical cues. Avoid stacking several horns and
  celebratory stingers when related events happen together.
- Give purchases, recruitment, training and relationship memories distinct but subtle cues.
- Stop or crossfade ambience on scene exit; prevent several loops playing after navigation.
- Add separate volume controls for music and effects; consider ambience separately once its
  layer exists. Keep the present simple mute controls usable.

Optional later work: short nonverbal acknowledgements or a small original voice-bark set.
Full dialogue voice acting should wait for stable writing and localization scope.

**Acceptance:** warnings are understandable through phone speakers at moderate volume;
headphone stereo placement has a usable mono fallback; sound-off play still communicates
all important information; quiet scenes do not inherit battle intensity; audio voices and
memory use stay within measured limits.

## 12. F08 — Make the company visibly belong to the player

Add a company name and a small banner editor using the existing heraldry system: a limited
palette, a few original charges and contrasting fields. Persist the design and reuse it on
Home, the map, roster, battle standards and campaign records.

Keep faction ownership, player/allied/enemy status and troop type readable independently.
A chosen red crest must not make friendly soldiers indistinguishable from enemies.

Show growth through veteran ribbons, cleaner equipment silhouettes, a captain's service
record and a more established camp detail. Tie these to real milestones. A battered banner
may represent a recorded battle; it should not imply an invented mechanical penalty.

**Acceptance:** a fresh and established company look distinct; renaming does not break IDs;
heraldry works in grayscale and beside faction banners; old saves receive a stable default;
customization never delays Continue or interrupts routine travel.

## 13. F09 — Make routine campaign decisions easier

### Travel

- Preview destination, approximate arrival time and current supplies in the same card.
- Mark estimates clearly: interception and changing conditions can alter the journey.
- Explain why travel is blocked and keep a route highlight visible after confirmation.
- Let Show on map focus a destination without silently starting travel. Link to the same
  navigation work specified in the [feature roadmap](next-features-roadmap.md).
- Make near-term threats visible at the zoom where they matter; prevent labels and decorative
  movement from obscuring the selected route.

### Recruiting, food and training

- Preview cost and resulting stock/strength before purchase, plus recurring wages where
  relevant. Show the reason a button is unavailable next to it.
- Compare training branches with a shared structure: role, main strength, tradeoff, cost
  and wage change. Keep an expandable detailed stat comparison.
- Preserve scroll position and focus after a successful purchase; update the affected card
  and purse rather than jumping the player to the top.
- A small confirmation pulse and concise receipt should be enough for a routine purchase.
  Reserve confirmation dialogs for meaningful irreversible commitments.

### Returning to the game

Continue should show the current company crest, location, supplies and the last significant
unresolved situation. Add a short “since your last visit” card from saved records when
needed. The world currently advances through player travel/wait; do not fabricate offline
progress or imply the company deteriorated while the application was closed.

**Acceptance:** common tasks take no more taps than now; previews match committed costs;
return navigation preserves useful context; receipts cannot duplicate transactions;
reopening the app gives an understandable next step.

## 14. F10 — A small quiet hub and responsive characters

Give Warband an optional camp presentation: a static or lightly animated scene with clear
Roster, Bonds, People and Memorial entry points. Keep the efficient list view available.
The first version is a presentation layer over existing data, not a new world simulation.

Offer occasional short reactions after real events: a costly battle, a promotion, a saved
village or a return to someone's home. Use eligible living characters, current relationship
state and recorded event IDs. Remember which reactions were seen and suppress repeats.

Examples of original directions:

- A cautious captain checks straps after a narrow escape, without requesting a new item.
- Two bonded captains disagree gently about who broke formation first, only if the relevant
  incident was recorded; otherwise use a more general scene.
- Edda greets a returning company differently after a documented loss, then offers the
  usual conversation choices without pressuring the player into an emotional response.

No new maintenance meter, daily gift loop or penalty for leaving camp quickly. Existing
personal-conversation reward rules remain intact; incidental banter grants no extra trust.
Actual Rest remains an explicit timed action with upkeep, distinct from opening the screen.

**Acceptance:** absent/dead characters never appear as present; reactions respect friendship
and romance settings; skipping affects no progression; camp reading advances no time;
replay is clearly a memory rather than a new event.

## 15. F11 — Accessibility and interface consistency

Build these into the first polish release instead of scheduling a separate final cleanup.

| Area | Proposed behavior |
| --- | --- |
| Text | Default, 125% and 150% settings; wrap labels and buttons; never truncate a consequence |
| Motion | Reduced motion disables shake, backdrop drift and spring-like scaling; retain simple fades |
| Haptics | Independent toggle; no essential information conveyed only by vibration |
| Colors | Friendly/enemy shapes and labels alongside colors; do not recolor solely by preference |
| Dialogue | Instant text default, readable history, clear speaker, summary and replay |
| Inputs | Equivalent touch, mouse and keyboard actions; visible focus; no hover-only instructions |
| Camera | Hold-view mode and deliberate re-center; no forced framing while gesturing |
| Interruptions | Pause on app backgrounding; save visible state where supported; return safely |
| Status | Disabled controls explain why; warnings have an actionable destination |
| Audio | Readable alternatives for critical sound cues and independently adjustable mix |

Retain `Style.TOUCH` as the minimum hit area for normal buttons, including new art-heavy
cards. Check dynamic text at narrow phone widths. Avoid textures behind paragraphs and
ornamental fonts for numerical or tactical information.

**Acceptance:** all essential flows work at 150% text and with sound/haptics disabled;
reduced motion is complete across screens; pop-ups do not steal a tap intended for the
battlefield; there is always a visible route back.

## 16. F12 — Optional practice and replay

Add one brief tactics exercise after the existing optional tutorial: select a squad, hold
a spear line, then move cavalry around it. Use explicit feedback and a retry button in a
disposable scenario that never changes the campaign.

Later add a gallery for viewed scenes, promotions and memorials using the existing archive
patterns. Presentation replay is substantially cheaper than a deterministic full battle
replay. Defer the latter until battle input recording and replay integrity have a separate
technical plan.

Do not add real-time battle rewind as a small polish task. It would need a full design for
simulation state, random outcomes, inputs, saves and captain fate; pause and clear tactical
inspection are the nearer improvements.

## 17. Art direction and first asset list

### Shared visual rules

Use the current night-blue/brass interface and culture silhouettes as anchors. Start with
limited-palette pixel portraits and illustrated pixel environments that match the existing
battle/map art. Establish one approved portrait and one environment before producing a cast.

Specify lighting direction, outline weight, shadow colors, texture density and export scale.
Test portraits at actual displayed size; finer facial detail is wasted if it disappears on
a phone. Keep text and scalable interface symbols separate from raster illustrations.

### Proposed pilot assets

| Asset | Initial quantity | Suggested source/export | Reuse |
| --- | --- | --- | --- |
| Edda portrait | 1 base, 5 expression states | Transparent 192×256 PNGs; shared registration | People, main dialogue, personal scenes, memory |
| Captain appearance prototype | 1 small compatible part kit | Registered transparent layers; save a recipe ID | Roster, selection, injury and memorial |
| Location illustrations | 3 initially | 720×480 backgrounds with optional foreground layers | Ravensford, common room, camp |
| Other-culture exteriors | 2 after the pilot | Same framing and layer conventions | First Kharzani and Ryumon arrival panels |
| Personal-story props | 3–5 reusable items | Small transparent sprites | Spoon/table, ledger, doorway, cloth |
| UI symbols and heraldry | Extend existing set | SVG or existing drawing code | Buttons, receipts, faction/company identity |
| Combat effect refinements | 3 focused families | Small sprite atlases | Dust/contact, volley, rally/rout |
| Ambient audio | 3 short sets | Seamless loops plus sparse variations | Settlement, common room, camp |

These are production starting points, not a demand to load every asset at once. Keep each
portrait's eyes, shoulders and crop aligned so expression changes do not jump.

Proposed new folders: `assets/portraits/`, `assets/locations/`, `assets/vfx/`. Existing icons
and heraldry should be extended in their current vector/code systems. Keep source art,
export settings, licensing/provenance and an asset manifest together. Do not put important
words, resource numbers or buttons into an image.

**Initial performance target:** keep the pilot's additional resident UI textures below
32 MiB decoded on the target device; load the current scene's needs and release unused
sets. Measure the actual imported/compressed textures. For active battle effects, start
with a shared particle budget and require no material regression against a measured
baseline; tighten exact limits after profiling on a named device.

## 18. Implementation map

All paths below are existing unless explicitly marked proposed.

| Work | Main integration points |
| --- | --- |
| Portrait data and persistent appearance | `scripts/data/captains.gd`, `scripts/world/social_sim.gd`, `scripts/game_state.gd`; proposed portrait catalog/renderer |
| Settlement/camp illustrations | `scripts/world/settlement_screen.gd`, `scripts/menu/main_menu.gd`, shared menu layout |
| Staged dialogue | `scripts/menu/conversation.gd`, `scripts/menu/personal_conversation.gd`, `scripts/data/personal_conversations.gd` |
| Command, camera and effects | `scripts/battle/battle_screen.gd`, `scripts/art/unit_art.gd`, existing event producers in `battle_sim.gd` |
| Results and memorial | `battle_screen.gd`, `scripts/game_state.gd`, `scripts/menu/main_menu.gd` |
| Sound and preferences | `scripts/audio/sound.gd`, `scripts/menu/settings.gd`, `scripts/ui/sound_toggles.gd` |
| Company identity | `scripts/ui/heraldry.gd`, Home/map/roster, campaign serialization |
| Reusable UI/accessibility | `scripts/ui/style.gd`, `scripts/ui/menu_page.gd`, `scripts/ui/scenes.gd` |

Introduce a small presentation-event adapter if needed to prioritize and coalesce effects.
Keep authoritative battle/campaign events separate from visual replay. Art, audio and
cosmetic randomization must not mutate simulation state or consume simulation RNG.
When changing dialogue into beats, version its progress format and migrate existing
unfinished conversations rather than discarding saved choices.

## 19. Delivery order and quality gates

### A — One convincing character visit

Deliver Edda's portrait, Ravensford/common-room art, a staged Spare Spoon conversation,
summary/history, reduced motion and larger text in that flow. Reuse the portrait in People.

**Gate:** every original conversation state/reward test still passes; new beat-resume checks
pass; the visit works at narrow phone width, 150% text and without art/audio.

### B — One convincing battle

**Partial delivery, updated 2026-10-29:** scope is shown explicitly; Whole company clears squad
selection; Hold view/Re-center control automatic framing. Gestures freeze the camera and
receive a 0.85-second grace period afterward. Single-squad moves validate terrain routes
before acceptance and show a MOVE marker. Eight UI checks and a 405×720 rendered review pass.
Collision correction now uses at most two passes, repeating only for contacts deeper than
one world unit. Units now render narrower over the same collision bodies; all company move
destinations remain visible, nearby active bonds link their captains, and hits, charges,
captain falls and routs receive short field marks. Eight crowd/attack checks and combat
regressions pass. Haptics, tactile device review and broader effect-priority work remain.

An isolated interleaved desktop profile (`tests/collision_profile.gd`, three seeds, 600 ticks
each) compares the first three-pass collision fix with this two-pass revision:

| Soldiers at peak | Three-pass ms/tick | Two-pass ms/tick | Overlap/sample, three → two passes |
|---|---:|---:|---:|
| 272 | 7.422 | 5.823 | 147.37 → 225.62 |
| 544 | 17.856 | 13.982 | 560.30 → 726.51 |

This saves about 22% of simulation time in these cases at the cost of more residual contact
penetration. The dense stationary-crowd check still reduces total penetration from 551.1 to
4.9 within 15 ticks. These timings exclude drawing; they are not phone frame-rate claims.


Deliver command scope, stable camera gestures, tuned charge feedback, effect priorities and
haptic controls. Use the same representative encounter before and after the change.

**Gate:** players can issue accurate orders during the busiest moment; reduced motion and
compact presentation preserve battle logic for the same recorded commands at simulation
times; input response and frame time are measured on the target phone.

### C — One convincing return to camp

**Partial delivery, 2026-10-29:** the battle aftermath now reconciles casualty totals,
campaign rewards, captain fate rolls, earned bonds, XP and training readiness in a scrollable
report. The report is saved as the last battle. Warband captain cards open persistent profiles
for living and fallen captains, combining portrait, status, traits, company record, progression
and relationships. The screen now adds a company banner, payment forecast, sorting, separate
active/wounded sections and strength, experience and bond meters while preserving its scroll
position through profile visits. Rank C/B/A bond milestones show paired portraits and exact
effects; optional camp dialogue refers only to recorded battles, outcomes, wounds and losses.
Bonded deaths create saved memorial reactions and survivor history without adding a new reward
or penalty. A quieter camp mix and explicit recovery actions remain future work.

Deliver captain portrait continuity, the revised battle report, a remembrance view and a
quiet camp mix. Use a victory, a costly victory and a defeat as separate review cases.

**Gate:** every displayed reward and loss reconciles to saved state; the report is skippable;
there is a clear recovery action; memories remain consistent after reload.

### D — Expand the established language

Extend to the other cultures, more captain appearances, company heraldry, state-aware
banter and remaining menus. Expand the practice scenario only after the core controls are
clear. Reuse the roadmap's journal and contact work rather than building a competing system.

### Practical review checklist

- Capture Home, settlement, roster, dialogue, deployment, busy battle, results and memorial
  at the real phone size, including large text and reduced motion.
- Record a short before/after session with the same scenario and compare input errors,
  attention shifts, repeated clicks and time to complete common tasks.
- Ask a few fresh players to identify their captain, issue a specific order, explain a
  loss, buy enough food and resume an interrupted conversation without coaching.
- Evaluate atmosphere separately: which person/place do they remember, and what moment
  felt important? Treat a small playtest as directional evidence, not a statistical claim.
- Profile loading, frame times, audio voices and memory on a named physical phone. Desktop
  previews do not establish mobile performance or haptic quality.
- Keep existing functional suites; add targeted tests for saved appearance, presentation
  deduplication, result consistency, preference persistence and dialogue migration.

## 20. Recommended first implementation request

> Implement the Edda/Ravensford presentation slice: one consistent portrait with five
> expressions, exterior/common-room art, a staged Spare Spoon reader with history and
> summary, portrait reuse in People, and text/motion preferences. Preserve the current
> personal-conversation rewards, archive and resume behavior. Verify on phone-sized layouts.

If art production is not available yet, start with **command scope, camera stability,
reduced motion and truthful result cards**. Those improve the current experience without
waiting for a larger asset library.
