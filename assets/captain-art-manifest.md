# Captain artwork manifest

Generated with the built-in `image_gen` tool on 2026-10-29, then copied into the project and resized with nearest-neighbor sampling. Portraits are 384 × 512 PNGs with alpha. The camp is a 768 × 512 PNG.

## Shared portrait prompt

The following exact block preceded each of the six character-specific blocks below:

```text
Use case: stylized-concept
Asset type: reusable captain dialogue portrait for the Bannerfall mobile strategy game
Scene/backdrop: genuinely transparent background, with no scenery, no frame, and no shadow rectangle
Style/medium: original chunky pixel-painted game illustration; deliberate large pixel clusters, crisp hard edges, restrained detail, readable at 48 pixels tall; grounded low-fantasy clothing
Composition/framing: exactly one adult, waist-up bust, centered, facing slightly toward the viewer, head and both shoulders fully inside frame, hands and weapons out of frame, straight lower bust crop, portrait 3:4
Lighting/mood: warm upper-left lantern light, calm and battle-worn
Color palette: deep night blue, muted teal, warm cream, aged brass, plus the character-specific accents
Constraints: true alpha transparency across the entire background; exactly one person; original fictional character; no text, logo, watermark, border, banner, weapon, helmet, extra person, scenery, glow, or photorealism
```

The character-specific block was appended directly after the shared block.

### `captain_vardish_01.png`

```text
Primary request: Vardish captain portrait 01
Subject: a woman in her mid-thirties with brown skin, tightly coiled black hair gathered back, steady dark eyes, a practical navy wool gambeson, and a small aged-brass ring brooch; composed and dependable expression
Character accents: slate blue and muted teal
```

### `captain_vardish_02.png`

```text
Primary request: Vardish captain portrait 02
Subject: a weathered fair-skinned man in his late forties, short auburn hair going grey, close beard, faint old cheek scar, navy padded collar, and plain cream undershirt; patient guarded expression
Character accents: navy, faded blue-grey, cream
```

### `captain_kharzani_01.png`

```text
Primary request: Kharzani captain portrait 01
Subject: an olive-skinned man in his early thirties with dark wavy hair, a neat short beard, an ochre quilted coat, indigo scarf, and small brass fastener; alert, wry expression
Character accents: ochre, indigo, tarnished brass
```

### `captain_kharzani_02.png`

```text
Primary request: Kharzani captain portrait 02
Subject: a dark-skinned woman in her early forties with braids gathered beneath a practical wrapped headcloth, rust-red quilted coat over a cream collar, and restrained brass trim; resolute, thoughtful expression
Character accents: rust, cream, muted plum
```

### `captain_ryumon_01.png`

```text
Primary request: Ryumon captain portrait 01
Subject: a light-medium-skinned woman in her early thirties with short black hair tied into a practical low knot, dark red lamellar vest over an indigo undercoat, plain cream collar, and one aged-brass clasp; stern but humane expression
Character accents: dark red, indigo, charcoal
```

### `captain_ryumon_02.png`

```text
Primary request: Ryumon captain portrait 02
Subject: a tan-skinned man in his early fifties with greying black hair gathered in a short practical topknot, neat moustache and chin stubble, moss-green and charcoal campaign coat, plain cream collar; thoughtful, tired expression
Character accents: moss green, charcoal, muted burgundy
```

## `captain_fallback.png`

```text
Use case: stylized-concept
Asset type: fallback captain portrait for the Bannerfall mobile strategy game
Primary request: a simple anonymous captain bust silhouette that can represent any culture or gender
Scene/backdrop: genuinely transparent background
Subject: one faceless head-and-shoulders silhouette in deep navy, with a restrained warm-brass rim light and a simple travel cloak; no visible facial traits
Style/medium: chunky pixel-painted game icon with deliberate large pixel clusters and crisp hard edges, matching a grounded low-fantasy strategy game
Composition/framing: centered bust, head and both shoulders fully inside a 3:4 portrait frame, straight lower crop
Constraints: true alpha transparency; exactly one silhouette; no text, logo, watermark, border, scenery, weapon, helmet, recognizable face, glow field, or extra object
```

## `company_camp.png`

```text
Use case: stylized-concept
Asset type: reusable header and home-card environment illustration for the Bannerfall mobile strategy game
Primary request: a quiet mercenary company camp at blue hour, between marches
Scene/backdrop: a small low-fantasy roadside camp with three modest canvas tents, a low ember fire, cooking pot, supply chest, folded blankets, hitching rail, and distant dark hills; no people
Style/medium: original chunky pixel-painted game illustration; deliberate large pixel clusters, crisp hard edges, restrained detail, grounded historical-fantasy materials
Composition/framing: landscape 3:2; broad calm camp silhouette; keep the central and upper-left areas visually quiet enough for UI copy; preserve meaningful detail in a shallow center crop and a wide header crop
Lighting/mood: cool blue-hour sky with one warm pool of ember and lantern light; restful, weathered, safe for the night
Color palette: deep night blue, muted teal, warm cream canvas, aged brass, ember orange
Constraints: no people, faces, soldiers, battle, corpses, fortress, city, text, logo, watermark, border, modern items, bright magic, or photorealism
```
