# Bannerfall artwork roadmap

**Date:** 2026-10-29

**Status:** Package A implemented; Packages B–C remain planned.
**Baseline:** `04aee31`, including Edda's illustrations, battle controls and marshal armies.

This expands the [presentation plan](game-feel-and-presentation-plan.md) into an asset
backlog. The next gameplay feature remains siege resolution in [NEXT.md](NEXT.md).
Asset counts and budgets below are starting scopes to validate, not measured production estimates.

## 1. What to make next

Prioritize **recognizable captains, a company camp, distinct destinations and readable battles**.
These recur throughout a campaign and give existing decisions more visual context.

| Order | Artwork package | First useful scope | Where the player sees it | Dependency |
|---|---|---|---|---|
| 1 | Captain portraits | 6 portrait prototypes, 2 per culture, plus one fallback | Warband, battle cards, bonds, fallen captains | Stable appearance IDs and crop rules |
| 2 | Company camp | 1 reusable dusk scene and separate banner area | Warband header; cropped Home campaign card | Existing screens; no new camp mechanic |
| 3 | Battle silhouette pass | Infantry and cavalry pilot with ground shadows | Every battle | Actual sprite/footprint comparison |
| 4 | Cultural destinations | Highcliff, Khalun and Kurogane exteriors | Settlement arrivals | Shared location catalog |
| 5 | Marshal identity | 3 culture-specific army silhouettes and 3 state badges | Map markers and army sheet | Existing expedition state |
| 6 | Battle aftermath | 3 restrained illustrations: victory, withdrawal, remembrance | Results and memorial | Accurate result/state selection |
| 7 | Villages and forts | 3 village plates, 2 additional castle plates | Remaining settlement headers | Reusable culture/type fallback |
| 8 | Personal story objects | 4 small Edda props; later Farah/Kaede portraits | Memories and dialogue | Authored scene context; complete routes for later portraits |
| 9 | Siege artwork | 1 camp, 3 wall styles, 4 state symbols | Siege sheet and strategic map | Actual siege states, still unimplemented |
| 10 | Company identity and world detail | 6 heraldic charges; a small landmark/prop set | Banners, Home, map, recruitment | Existing heraldry and truthful world state |

Orders 1–5 are the strongest near-term investment. Siege concept art can be prepared while
the system is built; its state-specific UI should ship with the system that drives it.

## 2. Existing art to keep and extend

- Five Edda expressions already exist at **384×512**, with transparent backgrounds.
- Ravensford and the common room already exist at **768×512**. Use their lighting,
  palette and framing as references. Do not commission replacements as part of this pass.
- Battle units, map figures and scenery already use code-generated pixel textures in
  `scripts/art/`. Preserve that pipeline for small sprites unless a measured need justifies migration.
- Silver, food and renown already have SVG icons. Heraldry is drawn in code. Extend these
  scalable systems for symbols rather than generating raster pictures of interface controls.
- Home already has a map backdrop. A camp crop should enrich the saved-campaign card,
  preserving its useful campaign information and Continue button.
- Portraits, locations and an illustrations toggle currently flow through `story_art.gd`.
  Its portrait/identity helpers are Edda-specific; generalize them before introducing another cast.

The earlier presentation plan's 192×256 portrait and 720×480 environment suggestions were
proposals. Use the shipped dimensions above as the starting export convention for new story art.

## 3. Captain faces that survive a whole campaign

### Art brief

Paint adult, practical military leaders with distinct face shapes, hair, age details and
silhouettes. Use modest equipment and weathering, with readable expressions at small size.
Include varied skin tones and gender presentations across the whole set; culture should
primarily read through clothing, materials and equipment, not a single face template.

The pilot is **six finished neutral busts**, two per culture. It tests framing and reuse;
it is not enough variety for the entire procedural cast. Once validated, expand toward
18 neutral portraits, six per culture. Start with complete portraits rather than a large
layer kit: separate generated hair/face/clothing layers create alignment and lighting work.
Build modular parts later only if the small pool proves too repetitive.

Give every portrait:

- A 384×512 transparent master export matching Edda's upper-left lighting.
- An authored head-crop rectangle for small cards; derive thumbnail exports from that crop.
- Clear eye and shoulder registration, stable across any later expressions.
- Metadata for culture styling and visual variants, without inferring identity from a name.

### Integration and persistence

Assign an `appearance_id` once when a captain is created. Prefer unused compatible faces
within the active company while available; allow documented reuse when the pool is exhausted.
Use a separate deterministic appearance selector, never the battle/world random stream.
Old saves receive a stable choice based on campaign identity and captain ID, then persist it.

Promotion, troop-branch changes and equipment upgrades retain the face. Wounds use a small
status badge or frame first, not a new painting for every injury. A successor gets a new
identity; the fallen captain's appearance ID is copied into the memorial record before replacement.

Reuse the same face in Warband, the battle selection card, bond introductions and the fallen
list. Keep the troop-role icon beside it so a face does not replace tactical information.
Do not attach these generic portraits to Edda, Farah or Kaede.

**Done when:** a captain can be recognized between screens; reload and promotion preserve
the face; the memorial keeps the deceased's portrait; missing assets fall back cleanly.

## 4. A company camp that makes the warband feel like home

**First scene:** a low fire, a travel chest, folded blankets, a cooking pot, a few tents and
an empty space for the company's banner. Use a quiet dusk palette with a brighter fire focal
point. Keep specific faces out of the background so it never depicts a dead or absent captain.

Use one 768×512 scene in the Warband header and a shallow crop on Home's campaign summary.
Keep controls outside the illustration. The first version is static; add a subtle fire loop
only after checking reduced motion and device cost.

The banner should be a separate overlay drawn from heraldry. A later daylight variant can
be another export or a controlled lighting layer. Do not imply a real camp location, upgrades,
food supply or time of day unless the scene is connected to those saved facts. A decorative
dusk scene can remain a consistent menu setting instead.

**Done when:** the scene works as both a full header and a narrow crop, does not delay access
to squads, and remains readable with illustrations disabled and text at 150%.

## 5. Make the three cultures and their settlements distinct

Create **three capital plates** first, completing the currently underrepresented town tier:

| Destination | Proposed composition | Recognizable detail |
|---|---|---|
| Highcliff | A stone town rising toward a keep above a steep approach | Terraced walls and a cliff silhouette |
| Khalun | A sunlit walled city seen through a shaded approach | Pale masonry, layered roofs, cloth shade and warm stone |
| Kurogane | An island town rising toward a timber stronghold | Layered rooflines, stone foundations and a coastal ridge |

These are art directions, not new geographic facts. Check each composition against the map
before establishing a harbor, river, mountain or other permanent landmark as canon.

Then make **one village plate per culture** and **two castle plates** for Kharzani and Ryumon
locations. Ravensford supplies the initial Vardish castle reference. Use the generic plates
as explicitly shared visual treatments; avoid placing a unique named landmark in every village.
Later give Qasr Hamra, Kitayama and Marchgate distinct landmarks when their visits justify it.

Keep architecture tied to the settlement's local culture. Draw the current owner's banner
separately. Capturing a place must not replace its buildings with those of the conqueror.

Start with two reusable state treatments: a gentle night lighting layer and a restrained
burned-village treatment. Burn damage is driven only by the existing burned state. Night art
must use the campaign clock if it is presented as current time. Seasonal weather is deferred.

**Done when:** culture and settlement type read at a glance; ownership changes only the correct
overlay; the arrival header leaves shopping and departure controls easy to reach.

## 6. Improve battle artwork where it affects readability

`unit_art.gd` explicitly draws foot soldiers wider than their simulation footprint. This is
part of why bodies may look intermingled even when their centers separate correctly.
Treat this as an art/readability task alongside the collision work.

### First comparison

Capture the same dense infantry melee and cavalry charge with debug circles at each soldier's
ground contact point. Compare idle, walk and strike frames at the game's actual zoom levels.

- Keep feet/hooves and torso width legible; long weapons may extend past the contact footprint.
- Try a narrower body silhouette or adjusted sprite scale before widening simulation radii again.
- Keep every frame's ground pivot fixed so animation does not look like collision jitter.
- Give horses and infantry distinct, quiet oval contact shadows. Avoid opaque circles that merge.
- Separate front/back rows through outline contrast and shadow, without relying on faction color alone.

Do not promise zero visual overlap: overhead weapons and tall bodies naturally overlap in this
view. Success is being able to identify soldiers and read the front line during contact.

### Small effect set after the silhouette pass

Create four families: foot dust, cavalry dust, a brief contact spark and a rally/rout cue.
Prototype 4-frame strips, with a shared event rate cap. Prefer one squad-level burst to an
effect on every soldier. Keep target markers, banners and command previews above decorative
effects. A visual flash must not imply an extra hit or change battle timing.

**Done when:** busy battles are easier to read at phone width; sprite motion does not change
orders or collisions; reduced-motion/static alternatives work; frame cost is measured separately
from the simulation-only collision profile.

## 7. Make marshal armies recognizable on the map

The current joined army uses the lord marker with a gold ring. Add a compact silhouette of
several riders or standards with **three cultural variants**. Reuse faction banner colors;
do not draw every individual member on the strategic map.

Add **gathering, marching and returning** badges as SVG or code-drawn symbols with text labels
in the army sheet. These states already exist. Keep the current hit area generous and make the
army distinct from a lone lord even in grayscale and at wide zoom.

The army sheet can reuse the camp image with its actual marshal's banner and member portraits
once a suitable lord portrait system exists. Do not reuse an unrelated named character's face.
Lord portrait assignment is a later extension of stable person IDs, not part of the first captain pilot.

**Done when:** players can spot an army without opening the sheet, and its art reflects the
saved expedition state after reload, interruption and disbanding.

## 8. Let results and personal moments have a visual memory

### Results and remembrance

Make three compact 768×512 vignettes with useful header crops:

1. **Victory:** a standard being raised beside resting equipment; use a restrained composition
   that remains appropriate after heavy losses.
2. **Withdrawal/defeat:** packed equipment on a retreating road, with no identifiable dead captain.
3. **Remembrance:** an empty place by the fire or a cloak beside an unoccupied stool.

Overlay the actual captain portrait, name and outcome rather than painting those into a generic
scene. Keep casualties, rewards and the exit button visible. An injury must not show a grave;
a defeat must not imply every member died. Avoid a separate illustration for every numerical result.

### Story props and later cast

Start with four small Edda items: the spare spoon, a marked ledger page, worn boots and a folded
piece of cloth. Use them as memory thumbnails or occasional scene details where the writing
actually mentions them. Keep letters and legible prose in UI text, not in painted pixels.

Farah and Kaede now have five registered expressions each:
neutral, amused, thoughtful, concerned and warm. Farah's brief should reflect an accomplished
envoy whose formality softens in private; Kaede's should follow her existing character plan.
Match Edda's visual system while giving each a distinct silhouette and clothing. Design original
faces and costumes rather than adapting recognizable Fire Emblem character designs. Their
Qasr Hamra/envoy-room and Kitayama/archive-room settings are also implemented.

Use bond introductions and milestone scenes to show paired portraits first. Reserve bespoke
event paintings for a small number of authored moments after the everyday screens are covered.

## 9. Prepare siege artwork for the next gameplay feature

Build a small reusable set instead of full siege battle maps:

- One army camp plate with separate tents, supply crates, ladders and banner slots.
- Three wall/gate silhouettes matching the local cultures.
- Four scalable status symbols for preparation, assault, shortage and relief.
- One modest smoke/damage overlay that preserves the original architecture.

Use these for the future siege sheet and a strategic-map camp marker. Connect each state to
the implemented rules before exposing it: a ladder should not advertise a playable wall-climbing
mode, and a relief badge should not appear before relief forces are supported. Food status must
come from actual siege supply data, not an artist-authored scene variation.

Defer large wall-animation sets, breach choreography and siege-engine units until those systems
are planned. Current expeditions return from their destination; siege artwork must not imply otherwise.

## 10. Small artwork with wide reuse

- **Heraldry:** six original readable charges, a few field divisions and cloth-edge variants,
  built in the existing renderer. Reuse them on camp banners, map parties and company summaries.
- **Recruitment:** equipment bundles for infantry, spears, bows and horse, using existing troop
  palettes. Keep culture and upgrade differences apparent; preserve the readable troop icon.
- **Map landmarks:** a compact set of bridge, watchtower, harbor and roadside-shrine silhouettes,
  placed only where geography supports them. Decorative detail must not look like a tappable settlement.
- **Tutorial diagrams:** small code-drawn examples of selection, formation lines and supply warnings.
  Show actual game symbols and label them; do not replace instructions with unexplained pictures.
- **Paper and seals:** restrained dividers, wax seals and letter thumbnails. Use them around the
  existing text rather than putting parchment texture behind every paragraph.

## 11. Production rules and budgets

| Asset type | Starting delivery format | Notes |
|---|---|---|
| Story/captain bust | 384×512 PNG, true alpha | Shared registration; nearest filtering; authored head crop |
| Environment/event plate | 768×512 PNG | Compose for both 3:2 and a shallow phone header crop |
| Story prop | Up to 128×128 transparent PNG | Readable at small size; no critical embedded text |
| Unit/map pixel art | Existing sprite-data/code pipeline | Fixed ground pivots and established pixel scale |
| UI/state/heraldic symbol | SVG or existing drawing code | Labels, contrast and shape carry meaning |

Use the current night-blue/brass UI and subdued terrain colors. Concentrate contrast on faces,
interactable elements and tactical information. Keep raster artwork free of buttons, resource
numbers, player names and faction labels that can change.

Record asset ID, purpose, dimensions, crop, pivot, variants, source/provenance, generation prompt
or artist credit, revision and fallback in an art manifest. Keep editable originals separate
from runtime exports. Suggested folders are `assets/portraits/captains/`, `assets/locations/`,
`assets/events/` and `assets/props/`; use `assets/vfx/` only when an atlas is actually needed.

Generalize `story_art.gd` to a catalog with person/location IDs, then add cache eviction or
scene-scoped loading. Its current static cache retains loaded textures; simply adding all
portrait/location variants would make memory accumulate across visits.

For scale, one uncompressed RGBA8 portrait is about **0.75 MiB**, and one 768×512 plate is
about **1.5 MiB**, before mipmaps/driver overhead. PNG file size is not GPU memory usage.
Retain the presentation plan's provisional **32 MiB additional story-art texture budget**,
verify imported memory on the target device, and load only the current scene's needs.

The illustrations toggle should hide decorative portraits and headers. Functional map symbols,
troop roles and command markers stay available. Reduced motion uses static frames. Every new
asset set needs a readable missing-art fallback and a 150% text check on the surrounding UI.

## 12. Implementation packages and acceptance

### Package A: faces and a place to return to

Produce six captain busts, one fallback and one camp illustration. Implement stable appearance
IDs, crop handling and portrait reuse in Warband/battle/bonds/memorial. Add the camp header.
Treat this as the recommended first artwork implementation request.

Validate promotion, wounds, death/succession, old saves and reloads without changes to campaign
RNG or stats. Review face crops at 405×720 and 360×640. Expand the portrait pool only after this works.

#### As built — 2026-10-29

- Six culture-specific captain portraits, a transparent fallback and one reusable company-camp
  plate are shipped at the target runtime dimensions. Prompts and provenance are recorded in
  [`assets/captain-art-manifest.md`](../assets/captain-art-manifest.md).
- Every captain now receives a deterministic `appearance_id` from captain ID and culture without
  consuming RNG. Old saves receive the same stable assignment on load; new memorial records retain
  the deceased captain ID and portrait.
- Warband squad cards, bond rows, the rank-C introduction, battle cards and memorial entries reuse
  the same face. Home and Warband reuse the company camp. Troop names and battle standards remain
  present for tactical identity.
- The illustrations preference hides these decorative images and keeps functional text, controls,
  standards and unit-icon fallbacks.
- The seven portraits plus camp occupy about 6.75 MiB as uncompressed RGBA/RGB textures, below the
  provisional 32 MiB additional story-art budget; target-device imported memory is still unmeasured.
- Focused acceptance checks cover dimensions and alpha, old-save assignment, RNG isolation,
  memorial continuity, bond portrait identity and menu presence. Home, Warband, bonds and battle
  cards were rendered and inspected at 405×720 and 360×640 equivalents.

### Package B: readable forces and destinations

Run the infantry/cavalry silhouette comparison, then make the three capital plates and three
marshal markers. Add state badges, culture/type fallbacks and asset-lifetime management.
Validate capture banners, army transitions, narrow screens and dense battle visibility.

### Package C: consequences and the wider world

Add the result/remembrance vignettes, village/castle plates and Edda props. Introduce later
romance portraits with their routes, and siege art with siege rules. Add ambient animation
only after static artwork, reduced motion and actual-device performance have been reviewed.

### Integration points

| Work | Existing files to extend |
|---|---|
| Catalog, loading and static fallbacks | `scripts/ui/story_art.gd`, `scripts/ui/style.gd` |
| Captain appearance and memorial identity | `scripts/data/captains.gd`, `scripts/game_state.gd` |
| Portrait reuse and camp/Home | `scripts/menu/main_menu.gd`, `scripts/menu/title.gd`, `scripts/menu/bond_intro.gd` |
| Captain battle cards and aftermath | `scripts/battle/battle_screen.gd` |
| Unit silhouette and ground pivots | `scripts/art/unit_art.gd`, `scripts/art/sprite_data.gd` |
| Settlements and marshal map markers | `scripts/world/settlement_screen.gd`, `scripts/world/map_screen.gd`, `scripts/art/map_art.gd`, `scripts/art/map_sprite_data.gd` |
| Cast and personal scenes | `scripts/menu/people.gd`, `scripts/menu/conversation.gd`, `scripts/menu/personal_conversation.gd` |
| Heraldry and illustration preference | `scripts/ui/heraldry.gd`, `scripts/audio/sound.gd`, `scripts/menu/settings.gd` |

Implementation should include in-game captures of each asset at its actual display size,
an updated manifest, focused identity/state tests where applicable, and device measurements
before claiming mobile performance. No new artwork needs to change battle balance or relationship rewards.
