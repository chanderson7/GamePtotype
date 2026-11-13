## Siege engines' pixel art (siege_sprite_data.gd, made by tools/siege_sprites.py) as
## textures: built once from the palette grids, as the men are (unit_art.gd), so it works
## in headless tests and an export alike; with a charred twin of each for what has burned
## and a silhouette for its shadow.
extends RefCounted

const Data = preload("res://scripts/art/siege_sprite_data.gd")

## Arena units per sprite pixel: the men's (UnitArt.FOOT_PIXEL), so an engine and its
## crew are one picture.
const PIXEL := 2.4
## How high each engine stands, in arena units: how far its shadow falls from it.
const HEIGHT := {"thrower": 12.0, "tower": 30.0, "ram": 7.0, "mantlet": 3.0, "bolt": 5.0, "platform": 3.0}
## Burnt wood: the dark it chars to, and the ember-brown its lights keep.
const CHAR_DARK := Color(0.10, 0.08, 0.07)
const CHAR_LIGHT := Color(0.32, 0.22, 0.16)

static var _cache := {}


static func has(name: String) -> bool:
	return Data.SPRITES.has(name)


static func frames(name: String) -> int:
	return (Data.SPRITES[name]["frames"] as Array).size() if has(name) else 0


## The pixel `name` stands on (its centre, or its axle, or its body's).
static func pivot(name: String) -> Vector2:
	return Data.SPRITES[name]["pivot"] if has(name) else Vector2.ZERO


## Frame `index` of `name`: as built, `burnt` (charred), or `shadow` (a black silhouette).
static func texture(name: String, index: int = 0, burnt: bool = false, shadow: bool = false) -> Texture2D:
	if not has(name):
		return null
	var key := "%s|%d|%s|%s" % [name, index, burnt, shadow]
	if _cache.has(key):
		return _cache[key]
	var all: Array = Data.SPRITES[name]["frames"]
	var rows: Array = all[clampi(index, 0, all.size() - 1)]
	var h := rows.size()
	var w := String(rows[0]).length()
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var row := String(rows[y])
		for x in w:
			var ch := row[x]
			if ch == ".":
				continue
			var c: Color = Data.PALETTE[ch]
			if shadow:
				c = Color(0, 0, 0, 1)
			elif burnt:
				c = CHAR_DARK.lerp(CHAR_LIGHT, clampf(c.get_luminance() * 1.4, 0.0, 1.0))
				# A few embers glow in the char.
				if ch in ["o", "a", "c", "h"] and (x * 7 + y * 13) % 11 == 0:
					c = Color(0.85, 0.32, 0.10)
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex
