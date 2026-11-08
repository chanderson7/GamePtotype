## The look of the ground a battle is fought on. Where the old field drew its features as
## flat polygons every frame (a blue band for the river, grey boxes for rocks and houses, a
## pale wash for a hill), this bakes them once, when the battle starts, into a few textures
## the field then draws in one call each:
##   - a hillshade: slopes lit from the upper left, as the men are, dry grass on the brows
##     and thin contour lines, so high ground reads as ground that rises;
##   - a plate of features at two field units a pixel: the forest floor with its litter,
##     logs and tree shadows; the river with banks, reeds, a foam line and gravel fords;
##     rock outcrops as boulders with scree at their feet; a village's houses roofed the way
##     its people roof them, round a trodden square with a well.
## Only looks: nothing here changes where a man can stand or how fast he moves.
extends RefCounted

const Terrain = preload("res://scripts/battle/terrain.gd")
const Cultures = preload("res://scripts/data/cultures.gd")
const BattleSite = preload("res://scripts/battle/battle_site.gd")

## Field units per plate pixel: between the men (2.4) and the grass (3).
const PLATE_PX := 2.0
## Field units per hillshade pixel; its lines and slopes are soft, so it can be coarser.
const SHADE_PX := 4.0
## Where the light comes from, as on the sprites: the upper left.
const LIGHT := Vector2(-0.6, -0.8)
## How far scree and the river's banks reach past the ground that stops a man.
const SCREE := 12.0
const BANK := 10.0
const BANK_WOBBLE := 8.0
## Contour lines every this much height, and how wide they are in height.
const CONTOUR := 0.2
const CONTOUR_W := 0.035
## How far off true the hillshade samples the ground, in field units.
const WOBBLE := 14.0
## The middle of a village's square, as the site generator lays it out.
const VILLAGE_CENTER := Vector2(420.0, 840.0)

## Each land's stone, earth, water, timber and roofs.
const LOOKS := {
	"vardish": {
		"high": Color(0.80, 0.74, 0.46), "floor": Color(0.10, 0.24, 0.10), "litter": Color(0.36, 0.28, 0.14),
		"rock": Color(0.52, 0.52, 0.50), "rock_light": Color(0.70, 0.70, 0.66), "rock_dark": Color(0.33, 0.33, 0.33),
		"growth": Color(0.33, 0.50, 0.22), "water": Color(0.10, 0.27, 0.50), "shallow": Color(0.30, 0.54, 0.62),
		"ford": Color(0.46, 0.66, 0.68), "bank": Color(0.40, 0.31, 0.20), "wet": Color(0.56, 0.47, 0.30),
		"pebble": Color(0.74, 0.70, 0.58), "reed": Color(0.38, 0.54, 0.22), "dirt": Color(0.56, 0.47, 0.30),
		"roof": Color(0.74, 0.62, 0.34), "roof_light": Color(0.84, 0.74, 0.44), "roof_dark": Color(0.56, 0.45, 0.24),
		"ridge": Color(0.40, 0.30, 0.16), "wall": Color(0.45, 0.33, 0.20), "stone": Color(0.58, 0.58, 0.56), "dome": false,
		"top": Color(0.58, 0.60, 0.52), "top_alpha": 0.62,
	},
	"kharzani": {
		"high": Color(0.86, 0.78, 0.60), "floor": Color(0.34, 0.32, 0.17), "litter": Color(0.50, 0.42, 0.22),
		"rock": Color(0.66, 0.44, 0.30), "rock_light": Color(0.82, 0.60, 0.42), "rock_dark": Color(0.44, 0.28, 0.20),
		"growth": Color(0.56, 0.50, 0.28), "water": Color(0.12, 0.38, 0.50), "shallow": Color(0.30, 0.60, 0.64),
		"ford": Color(0.52, 0.74, 0.72), "bank": Color(0.80, 0.70, 0.47), "wet": Color(0.64, 0.54, 0.35),
		"pebble": Color(0.88, 0.82, 0.66), "reed": Color(0.62, 0.58, 0.32), "dirt": Color(0.72, 0.62, 0.42),
		"roof": Color(0.80, 0.68, 0.48), "roof_light": Color(0.90, 0.80, 0.60), "roof_dark": Color(0.62, 0.50, 0.32),
		"ridge": Color(0.52, 0.40, 0.26), "wall": Color(0.70, 0.58, 0.40), "stone": Color(0.76, 0.66, 0.50), "dome": true,
		"top": Color(0.86, 0.78, 0.60), "top_alpha": 0.34,
	},
	"ryumon": {
		"high": Color(0.56, 0.60, 0.46), "floor": Color(0.07, 0.20, 0.11), "litter": Color(0.30, 0.24, 0.14),
		"rock": Color(0.32, 0.32, 0.34), "rock_light": Color(0.50, 0.50, 0.50), "rock_dark": Color(0.18, 0.18, 0.20),
		"growth": Color(0.42, 0.60, 0.30), "water": Color(0.10, 0.30, 0.48), "shallow": Color(0.28, 0.50, 0.60),
		"ford": Color(0.44, 0.64, 0.68), "bank": Color(0.52, 0.52, 0.47), "wet": Color(0.40, 0.40, 0.36),
		"pebble": Color(0.72, 0.72, 0.68), "reed": Color(0.36, 0.56, 0.26), "dirt": Color(0.58, 0.54, 0.42),
		"roof": Color(0.22, 0.22, 0.28), "roof_light": Color(0.34, 0.34, 0.42), "roof_dark": Color(0.14, 0.14, 0.18),
		"ridge": Color(0.62, 0.62, 0.64), "wall": Color(0.50, 0.38, 0.24), "stone": Color(0.56, 0.56, 0.52), "dome": false,
		"top": Color(0.44, 0.46, 0.44), "top_alpha": 0.62,
	},
}


static func look(biome: String) -> Dictionary:
	return LOOKS.get(biome, LOOKS["vardish"])


# ---------------------------------------------------------------- hills

## Light and shade over the field's slopes, dry grass on the high ground, a contour line
## every CONTOUR of height. Null on level ground.
static func hillshade(t: Terrain, biome: String) -> ImageTexture:
	var img := hillshade_image(t, biome)
	return ImageTexture.create_from_image(img) if img != null else null


static func hillshade_image(t: Terrain, biome: String) -> Image:
	var w := int(Terrain.ARENA.x / SHADE_PX)
	var h := int(Terrain.ARENA.y / SHADE_PX)
	var heights := PackedFloat32Array()
	heights.resize(w * h)
	var any := false
	# The ground is sampled a little off true, by noise, so a ridge the site generator laid
	# down as a straight function of y comes out as a brow that wanders.
	var wob_x := _noise(31, 0.035, w, h)
	var wob_y := _noise(32, 0.035, w, h)
	for y in h:
		for x in w:
			var off := Vector2(wob_x.get_pixel(x, y).r - 0.5, wob_y.get_pixel(x, y).r - 0.5) * 2.0 * WOBBLE
			var v := t.height_at(Vector2((x + 0.5) * SHADE_PX, (y + 0.5) * SHADE_PX) + off)
			heights[y * w + x] = v
			if v > 0.04:
				any = true
	if not any:
		return null
	var lk := look(biome)
	var high: Color = lk["high"]
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var v := heights[y * w + x]
			if v <= 0.02:
				continue
			var x0 := maxi(x - 1, 0)
			var x1 := mini(x + 1, w - 1)
			var y0 := maxi(y - 1, 0)
			var y1 := mini(y + 1, h - 1)
			# Height change per field unit, and how squarely the slope faces the light.
			var gx := (heights[y * w + x1] - heights[y * w + x0]) / ((x1 - x0) * SHADE_PX)
			var gy := (heights[y1 * w + x] - heights[y0 * w + x]) / ((y1 - y0) * SHADE_PX)
			var s := -(gx * LIGHT.x + gy * LIGHT.y) * 90.0
			var c := Color(high, clampf((v - 0.1) * 0.5, 0.0, 0.36))
			if s > 0.0:
				c = c.blend(Color(1.0, 0.96, 0.80, minf(0.26, s * 0.8)))
			else:
				c = c.blend(Color(0.05, 0.08, 0.18, minf(0.30, -s * 0.8)))
			if v > 0.1 and fmod(v, CONTOUR) < CONTOUR_W:
				c = c.blend(Color(0.10, 0.08, 0.05, 0.20))
			img.set_pixel(x, y, c)
	return img


# ---------------------------------------------------------------- the plate

## Noise over the plate: soft blobs for edges, cells for boulders (their value, and how
## near a boulder's edge), and fine grain for litter, pebbles and reeds.
static func _noise(seed: int, freq: float, w: int, h: int, kind: String = "blob") -> Image:
	var n := FastNoiseLite.new()
	n.seed = seed
	n.frequency = freq
	match kind:
		"cells":
			n.noise_type = FastNoiseLite.TYPE_CELLULAR
			n.fractal_type = FastNoiseLite.FRACTAL_NONE
			n.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
		"edges":
			n.noise_type = FastNoiseLite.TYPE_CELLULAR
			n.fractal_type = FastNoiseLite.FRACTAL_NONE
			n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
		"grain":
			n.noise_type = FastNoiseLite.TYPE_VALUE
			n.fractal_type = FastNoiseLite.FRACTAL_NONE
		_:
			n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
			n.fractal_octaves = 3
	return n.get_image(w, h, false, false, true)


## Composite `c` over the plate's pixel.
static func _put(img: Image, x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	img.set_pixel(x, y, img.get_pixel(x, y).blend(c))


## Everything the ground shows that the sim knows about: woods, river, rocks and houses.
## `trees` are the field's tree sprites ({pos, ...}), so their shadows can fall on the
## forest floor. Null when the field is open.
static func plate(t: Terrain, biome: String, trees: Array, seed: int) -> ImageTexture:
	var img := plate_image(t, biome, trees, seed)
	return ImageTexture.create_from_image(img) if img != null else null


static func plate_image(t: Terrain, biome: String, trees: Array, seed: int) -> Image:
	if t == null or t.features.is_empty():
		return null
	var w := int(Terrain.ARENA.x / PLATE_PX)
	var h := int(Terrain.ARENA.y / PLATE_PX)
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var blob := _noise(seed, 0.05, w, h)
	var grain := _noise(seed + 1, 0.9, w, h, "grain")
	var lk := look(biome)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var drew := false
	var houses := []
	for feat in t.features:
		match String(feat.get("type", "")):
			"woods":
				_woods(img, feat, lk, blob, grain, rng)
				drew = true
			"river":
				_river(img, feat, lk, blob, grain)
				drew = true
			"rock":
				_rock(img, feat, lk, blob, grain, seed)
				drew = true
			"building":
				houses.append(feat["rect"])
	if not houses.is_empty():
		_village(img, houses, lk, grain, rng)
		drew = true
	if drew and not trees.is_empty():
		for tree in trees:
			_shadow(img, tree["pos"] + Vector2(5.0, 4.0), 7.0, 4.0, 0.28)
	return img if drew else null


## The slopes and the plate as one texture at the plate's size, so the field draws one
## see-through layer over the grass and not two (each covers the whole screen, every
## frame). The hillshade is doubled pixel for pixel, as it was drawn, and the plate laid
## over it the way the GPU would. Null when there is neither.
static func overlay(shade: Image, features: Image) -> ImageTexture:
	if shade == null and features == null:
		return null
	if features == null:
		return ImageTexture.create_from_image(shade)
	if shade == null:
		return ImageTexture.create_from_image(features)
	var out := shade.duplicate() as Image
	out.resize(features.get_width(), features.get_height(), Image.INTERPOLATE_NEAREST)
	out.blend_rect(features, Rect2i(Vector2i.ZERO, features.get_size()), Vector2i.ZERO)
	return ImageTexture.create_from_image(out)


static func _px(v: float) -> int:
	return int(floor(v / PLATE_PX))


## A soft dark ellipse on the ground, in field units.
static func _shadow(img: Image, at: Vector2, rx: float, ry: float, alpha: float) -> void:
	var c := Color(0.02, 0.05, 0.02, alpha)
	for py in range(_px(at.y - ry), _px(at.y + ry) + 1):
		for px in range(_px(at.x - rx), _px(at.x + rx) + 1):
			var p := Vector2((px + 0.5) * PLATE_PX, (py + 0.5) * PLATE_PX)
			var dx := (p.x - at.x) / rx
			var dy := (p.y - at.y) / ry
			if dx * dx + dy * dy <= 1.0:
				_put(img, px, py, c)


## The floor of a stand: shade deepening toward its middle with a ragged edge, leaf litter
## and sun through the leaves, a fallen log or two and a stump.
static func _woods(img: Image, feat: Dictionary, lk: Dictionary, blob: Image, grain: Image, rng: RandomNumberGenerator) -> void:
	var c: Vector2 = feat["center"]
	var r: float = float(feat["radius"])
	var floor_c: Color = lk["floor"]
	var litter: Color = lk["litter"]
	var reach := r + 14.0
	for py in range(_px(c.y - reach), _px(c.y + reach) + 1):
		for px in range(_px(c.x - reach), _px(c.x + reach) + 1):
			if px < 0 or py < 0 or px >= img.get_width() or py >= img.get_height():
				continue
			var p := Vector2((px + 0.5) * PLATE_PX, (py + 0.5) * PLATE_PX)
			var d := p.distance_to(c)
			var edge := r + (blob.get_pixel(px, py).r - 0.5) * 26.0
			if d > edge:
				continue
			var k := 1.0 - d / edge
			_put(img, px, py, Color(floor_c, 0.22 + 0.34 * minf(1.0, k * 2.2)))
			var g := grain.get_pixel(px, py).r
			if g > 0.80:
				_put(img, px, py, Color(litter, 0.55))
			elif g < 0.07 and k < 0.6:
				_put(img, px, py, Color(1.0, 0.96, 0.75, 0.22))
	# Deadfall.
	for i in 2:
		var at := c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, r * 0.6)
		var along := rng.randf() < 0.5
		var lw := 16.0 if along else 4.0
		var lh := 4.0 if along else 16.0
		var rect := Rect2(at - Vector2(lw, lh) * 0.5, Vector2(lw, lh))
		_fill(img, rect, Color(0.36, 0.25, 0.13))
		_fill(img, Rect2(rect.position, Vector2(rect.size.x if along else 2.0, 2.0 if along else rect.size.y)), Color(0.50, 0.36, 0.20))
		_fill(img, Rect2(rect.end - Vector2(2.0 if along else rect.size.x, rect.size.y if along else 2.0), Vector2(2.0 if along else rect.size.x, rect.size.y if along else 2.0)), Color(0.62, 0.50, 0.32))
	var stump := c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, r * 0.5)
	_disc(img, stump, 4.0, Color(0.30, 0.20, 0.10))
	_disc(img, stump, 2.2, Color(0.60, 0.46, 0.28))


static func _fill(img: Image, rect: Rect2, c: Color) -> void:
	for py in range(_px(rect.position.y), _px(rect.end.y)):
		for px in range(_px(rect.position.x), _px(rect.end.x)):
			_put(img, px, py, c)


static func _disc(img: Image, at: Vector2, r: float, c: Color) -> void:
	for py in range(_px(at.y - r), _px(at.y + r) + 1):
		for px in range(_px(at.x - r), _px(at.x + r) + 1):
			if Vector2((px + 0.5) * PLATE_PX, (py + 0.5) * PLATE_PX).distance_to(at) <= r:
				_put(img, px, py, c)


## The river: muddy banks with a wet line at the water, reeds along them, water that
## deepens toward the middle with a foam line at its edge, and gravel fords, their sides
## marked so the crossing is plain.
static func _river(img: Image, feat: Dictionary, lk: Dictionary, blob: Image, grain: Image) -> void:
	var half_w: float = float(feat.get("half_width", 38.0))
	var phase: float = float(feat.get("phase", 0.0))
	var bend: float = float(feat.get("bend", 0.0))
	var fords: Array = feat.get("fords", [])
	var ford_half: float = float(feat.get("ford_width", 90.0)) * 0.5
	var water: Color = lk["water"]
	var shallow: Color = lk["shallow"]
	var ford_c: Color = lk["ford"]
	var bank: Color = lk["bank"]
	var wet: Color = lk["wet"]
	var pebble: Color = lk["pebble"]
	var reed: Color = lk["reed"]
	var w := img.get_width()
	var reach := half_w + BANK + BANK_WOBBLE + 4.0
	for px in w:
		var x := (px + 0.5) * PLATE_PX
		var ry := 630.0 + sin(x * 0.007 + phase) * bend
		var in_ford := false
		var ford_edge := false
		for fx in fords:
			var dxf := absf(x - float(fx))
			if dxf <= ford_half:
				in_ford = true
				if dxf > ford_half - PLATE_PX:
					ford_edge = true
		for py in range(_px(ry - reach), _px(ry + reach) + 1):
			var y := (py + 0.5) * PLATE_PX
			var dy := absf(y - ry)
			var n := blob.get_pixel(px, clampi(py, 0, img.get_height() - 1)).r
			var g := grain.get_pixel(px, clampi(py, 0, img.get_height() - 1)).r
			var bank_w := BANK + (n - 0.5) * BANK_WOBBLE * 2.0
			# The waterline wanders a little too, so the river isn't a ruled band.
			var edge := half_w + (n - 0.5) * 7.0
			if dy <= edge:
				var depth := 1.0 - dy / edge
				var c: Color
				if in_ford:
					c = ford_c.lerp(wet, 0.30)
					if g > 0.74:
						c = pebble
					if ford_edge:
						c = Color(0.90, 0.92, 0.85)
				else:
					c = shallow.lerp(water, pow(depth, 0.7))
					c = c.lightened((n - 0.5) * 0.12)
					if dy > edge - 2.5:
						c = c.lerp(Color(0.88, 0.92, 0.92), 0.55)
				_put(img, px, py, Color(c, 0.94 if not in_ford else 0.80))
			elif dy <= edge + bank_w:
				var c := bank
				if dy < edge + 3.0:
					c = wet
				elif g > 0.82:
					c = pebble
				_put(img, px, py, Color(c, 0.92 - 0.3 * (dy - edge) / bank_w))
				if g > 0.93 and y < ry and not in_ford:
					# A reed, standing up from the bank.
					for k in 3:
						_put(img, px, py - k, Color(reed, 0.9))
					_put(img, px, py - 3, Color(0.52, 0.42, 0.20))


## How tall a cliff face is, in field units, how wide the lit rim along its brow, and how
## far in the higher step of a mass begins.
const FACE := 20.0
const RIM := 3.0
const STEP := 52.0

## A rock mass drawn as the ground rising, the way top-down games draw a cliff: the top is
## the same land, a shade drier and paler, with pebbles and a boulder here and there, and
## a second step rising from it further in. Round each step runs a cliff face, pale where
## it meets the light and dark where it turns from it, banded with strata and split by
## cracks, a bright rim along its brow, scree at its foot and, on its shaded side, a
## shadow thrown onto the floor. The mass is the site's (BattleSite.rock_reach); a feature
## without one is taken as its rect, from the nearer side of the field.
static func _rock(img: Image, feat: Dictionary, lk: Dictionary, blob: Image, grain: Image, seed: int) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var rect: Rect2 = feat.get("rect", Rect2())
	if not feat.has("reach"):
		feat = feat.duplicate()
		feat["side"] = -1.0 if rect.get_center().x < Terrain.ARENA.x * 0.5 else 1.0
		feat["reach"] = rect.size.x + 6.0
		feat["half_h"] = rect.size.y * 0.5 + 10.0
		feat["amp"] = 0.0
	var sd := float(feat["side"])
	var edge_x := 0.0 if sd < 0.0 else Terrain.ARENA.x
	var inward := -sd
	var half_h := float(feat["half_h"])
	var cells := _noise(seed + 7, 0.06, w, h, "cells")
	var cracks := _noise(seed + 9, 0.09, w, h, "edges")
	var rock: Color = lk["rock"]
	var light: Color = lk["rock_light"]
	var dark: Color = lk["rock_dark"]
	var growth: Color = lk["growth"]
	var pebble: Color = lk["pebble"]
	var top: Color = lk["top"]
	var top_a: float = float(lk["top_alpha"])
	var far := rect.size.x + SCREE + 20.0
	var x_lo := edge_x if inward > 0.0 else edge_x - far
	for py in range(_px(630.0 - half_h - 4.0), _px(630.0 + half_h + 4.0) + 1):
		if py < 0 or py >= h:
			continue
		var y := (py + 0.5) * PLATE_PX
		var r := BattleSite.rock_reach(feat, y)
		var slope := (BattleSite.rock_reach(feat, y + 3.0) - BattleSite.rock_reach(feat, y - 3.0)) / 6.0
		var ln := sqrt(1.0 + slope * slope)
		# The face's outward normal, and how squarely it meets the light (1 full on, -1
		# turned away).
		var nx := inward / ln
		var ny := -slope / ln
		var lit := nx * LIGHT.x + ny * LIGHT.y
		for px in range(_px(x_lo), _px(x_lo + far) + 1):
			if px < 0 or px >= w:
				continue
			var p := Vector2((px + 0.5) * PLATE_PX, y)
			var x_in := (p.x - edge_x) * inward
			var g := grain.get_pixel(px, py).r
			var d := (r - x_in) / ln
			# A face turned from the light shows more of itself than one that meets it.
			var face := FACE * (1.0 + 0.5 * maxf(0.0, -lit))
			# Which step of the mass this is: the second rises STEP in from the first.
			var step := 0
			if d >= STEP + face:
				d -= STEP
				step = 1
				lit = lit * 0.8 + 0.1
			if d >= face:
				var c := Color(top, top_a if step == 0 else top_a + 0.2)
				var v := cells.get_pixel(px, py).r
				if d < face + RIM:
					c = Color(light.lerp(Color.WHITE, 0.35), 0.9)
				elif v > 0.90 and step == 0:
					c = Color(rock.lerp(light, (v - 0.90) * 8.0) if cracks.get_pixel(px, py).r > 0.3 else dark, 1.0)
				elif g > 0.90:
					c = Color(pebble, 0.9)
				elif g < 0.04 and step == 0:
					c = Color(growth, 0.8)
				_put(img, px, py, c)
			elif d >= 0.0:
				var c := rock.lerp(light, lit * 0.6) if lit > 0.0 else rock.lerp(dark, 0.3 - lit * 0.7)
				# Strata along the face, streaks down it, cracks through it, dark at its foot.
				var band := int((d + g * 2.0) / 5.0)
				if band % 2 == 1:
					c = c.darkened(0.14)
				if cells.get_pixel(px, py).r > 0.6:
					c = c.lightened(0.07)
				if cracks.get_pixel(px, py).r < 0.08:
					c = dark.darkened(0.35)
				if d < 3.0:
					c = c.darkened(0.35)
				elif d > face - 2.0:
					c = c.lightened(0.12)
				_put(img, px, py, Color(c, 1.0))
			elif step == 0:
				var outside := -d
				if lit < -0.1 and outside < 26.0:
					var k := 1.0 - outside / 26.0
					_put(img, px, py, Color(0.02, 0.02, 0.05, 0.55 * -lit * k * k))
				if outside < SCREE and g > 0.6 + outside / SCREE * 0.38:
					_put(img, px, py, Color(pebble.lerp(rock, 0.45), 0.9))


## The village: a trodden square with a well in it, houses roofed the way the land roofs
## them (thatch, flat mud brick and a dome, dark tile), each with its shadow, and a fence
## or two.
static func _village(img: Image, houses: Array, lk: Dictionary, grain: Image, rng: RandomNumberGenerator) -> void:
	var dirt: Color = lk["dirt"]
	# The square: bare earth, darker where feet have worn it.
	var sq := VILLAGE_CENTER
	for py in range(_px(sq.y - 60.0), _px(sq.y + 60.0) + 1):
		for px in range(_px(sq.x - 80.0), _px(sq.x + 80.0) + 1):
			var p := Vector2((px + 0.5) * PLATE_PX, (py + 0.5) * PLATE_PX)
			var dx := (p.x - sq.x) / 80.0
			var dy := (p.y - sq.y) / 60.0
			var d := dx * dx + dy * dy
			if d <= 1.0:
				var g := grain.get_pixel(px, py).r
				var c := dirt.darkened(0.12) if g > 0.86 else dirt
				_put(img, px, py, Color(c, 0.85 * (1.0 - d * d)))
	# The well.
	_disc(img, sq + Vector2(5.0, 5.0), 11.0, Color(0.0, 0.0, 0.0, 0.3))
	_disc(img, sq, 10.0, lk["stone"])
	_disc(img, sq, 6.0, Color(0.08, 0.10, 0.14))
	_fill(img, Rect2(sq.x - 2.0, sq.y - 14.0, 4.0, 8.0), Color(0.40, 0.30, 0.16))
	_fill(img, Rect2(sq.x - 7.0, sq.y - 15.0, 14.0, 3.0), Color(0.40, 0.30, 0.16))
	for rect in houses:
		_house(img, rect, lk, rng)
	# A fence along one side of a couple of houses.
	for i in mini(2, houses.size()):
		var r: Rect2 = houses[i]
		var y := r.end.y + 8.0 if r.get_center().y < sq.y else r.position.y - 8.0
		var x := r.position.x - 6.0
		_fill(img, Rect2(x, y - 1.0, r.size.x + 12.0, 2.0), Color(0.46, 0.34, 0.18))
		while x <= r.end.x + 6.0:
			_fill(img, Rect2(x, y - 3.0, 2.0, 6.0), Color(0.34, 0.24, 0.12))
			x += 8.0


static func _house(img: Image, rect: Rect2, lk: Dictionary, rng: RandomNumberGenerator) -> void:
	var roof: Color = lk["roof"]
	var roof_light: Color = lk["roof_light"]
	var roof_dark: Color = lk["roof_dark"]
	var ridge: Color = lk["ridge"]
	var wall: Color = lk["wall"]
	# Its shadow, cast to the lower right; the walls' edge showing under the eaves.
	_fill(img, Rect2(rect.position + Vector2(6.0, 7.0), rect.size), Color(0.0, 0.0, 0.02, 0.35))
	_fill(img, rect.grow(1.0), wall)
	var eaves := rect.grow(-1.0)
	if bool(lk["dome"]):
		# A flat mud-brick roof with a parapet; the biggest house carries a dome.
		_fill(img, eaves, roof)
		_fill(img, Rect2(eaves.position, Vector2(eaves.size.x, 3.0)), roof_light)
		_fill(img, Rect2(eaves.position, Vector2(3.0, eaves.size.y)), roof_light)
		_fill(img, Rect2(Vector2(eaves.position.x, eaves.end.y - 3.0), Vector2(eaves.size.x, 3.0)), roof_dark)
		_fill(img, Rect2(Vector2(eaves.end.x - 3.0, eaves.position.y), Vector2(3.0, eaves.size.y)), roof_dark)
		if rect.size.x * rect.size.y > 1900.0:
			var c := rect.get_center()
			var r := minf(rect.size.x, rect.size.y) * 0.28
			_disc(img, c + Vector2(2.0, 2.0), r, roof_dark)
			_disc(img, c, r, Color(0.23, 0.54, 0.54))
			_disc(img, c - Vector2(r * 0.3, r * 0.3), r * 0.35, Color(0.45, 0.72, 0.70))
		else:
			_fill(img, Rect2(rect.get_center() + Vector2(4.0, -8.0), Vector2(6.0, 6.0)), roof_dark.darkened(0.4))
		return
	# A pitched roof: the ridge runs the long way; the slope toward the light is the
	# lighter one, and rows of thatch or tile run down each slope.
	var along_x := rect.size.x >= rect.size.y
	var c := rect.get_center()
	for py in range(_px(eaves.position.y), _px(eaves.end.y)):
		for px in range(_px(eaves.position.x), _px(eaves.end.x)):
			var p := Vector2((px + 0.5) * PLATE_PX, (py + 0.5) * PLATE_PX)
			var lit := (p.y < c.y) if along_x else (p.x < c.x)
			var col := roof_light if lit else roof
			var row := int(p.y / 3.0) if along_x else int(p.x / 3.0)
			if row % 2 == 0:
				col = col.darkened(0.10)
			_put(img, px, py, col)
	if along_x:
		_fill(img, Rect2(eaves.position.x, c.y - 1.5, eaves.size.x, 3.0), ridge)
	else:
		_fill(img, Rect2(c.x - 1.5, eaves.position.y, 3.0, eaves.size.y), ridge)
	# Thatch and tile both end in a darker eave.
	_fill(img, Rect2(Vector2(eaves.position.x, eaves.end.y - 2.0), Vector2(eaves.size.x, 2.0)), roof_dark)
	_fill(img, Rect2(Vector2(eaves.end.x - 2.0, eaves.position.y), Vector2(2.0, eaves.size.y)), roof_dark)
	if lk["ridge"] == LOOKS["vardish"]["ridge"]:
		# A chimney at one end of the ridge.
		var ch := Vector2(rect.end.x - 10.0, c.y - 3.0) if along_x else Vector2(c.x - 3.0, rect.end.y - 10.0)
		_fill(img, Rect2(ch, Vector2(6.0, 6.0)), lk["stone"])
		_fill(img, Rect2(ch + Vector2(2.0, 2.0), Vector2(2.0, 2.0)), Color(0.1, 0.1, 0.1))
	elif rng.randf() < 0.7:
		# Gable caps at both ends of the ridge, in the ridge's lighter tile.
		if along_x:
			_fill(img, Rect2(eaves.position.x, c.y - 3.0, 3.0, 6.0), ridge)
			_fill(img, Rect2(eaves.end.x - 3.0, c.y - 3.0, 3.0, 6.0), ridge)
		else:
			_fill(img, Rect2(c.x - 3.0, eaves.position.y, 6.0, 3.0), ridge)
			_fill(img, Rect2(c.x - 3.0, eaves.end.y - 3.0, 6.0, 3.0), ridge)


# ---------------------------------------------------------------- props and motion

## Things that stand on the ground as sprites, placed to suit the site: boulders on a
## crest, bushes at the edge of a wood and along a river's banks. Each is a doodad
## {name, pos, scale, flip} like the field's own.
static func props(t: Terrain, rng: RandomNumberGenerator) -> Array:
	var out := []
	if t == null:
		return out
	var tries := 0
	var crest := 0
	while crest < 7 and tries < 60 and not t.flat:
		tries += 1
		var p := Vector2(rng.randf_range(20.0, Terrain.ARENA.x - 20.0), rng.randf_range(20.0, Terrain.ARENA.y - 20.0))
		if t.height_at(p) > 0.70 and t.passable(p):
			out.append({"name": "rock0" if rng.randf() < 0.5 else "rock1", "pos": p,
				"scale": rng.randf_range(1.5, 2.3), "flip": 1.0 if rng.randf() < 0.5 else -1.0})
			crest += 1
	for feat in t.features:
		var ft := String(feat.get("type", ""))
		if ft == "woods":
			for i in 4:
				var a := rng.randf() * TAU
				var p: Vector2 = Vector2(feat["center"]) + Vector2.from_angle(a) * (float(feat["radius"]) + rng.randf_range(8.0, 26.0))
				if Rect2(Vector2.ZERO, Terrain.ARENA).grow(-12.0).has_point(p) and t.passable(p) and not t.in_woods(p):
					out.append({"name": "bush", "pos": p, "scale": rng.randf_range(1.4, 2.0), "flip": 1.0 if rng.randf() < 0.5 else -1.0})
		elif ft == "river":
			var half_w: float = float(feat.get("half_width", 38.0))
			var phase: float = float(feat.get("phase", 0.0))
			var bend: float = float(feat.get("bend", 0.0))
			for i in 5:
				var x := rng.randf_range(30.0, Terrain.ARENA.x - 30.0)
				var ry := 630.0 + sin(x * 0.007 + phase) * bend
				var side := -1.0 if rng.randf() < 0.5 else 1.0
				var p := Vector2(x, ry + side * (half_w + BANK + rng.randf_range(10.0, 24.0)))
				if t.passable(p) and t.water_at(p) == Terrain.WATER_NONE:
					out.append({"name": "bush", "pos": p, "scale": rng.randf_range(1.3, 1.8), "flip": 1.0 if rng.randf() < 0.5 else -1.0})
	return out


## The water moving: glints drifting along the river, and rings where it runs over a ford.
## Drawn every frame, in field units, over the plate.
static func draw_water(c: CanvasItem, t: Terrain, clock: float, alpha: float = 1.0) -> void:
	if t == null:
		return
	for feat in t.features:
		if String(feat.get("type", "")) != "river":
			continue
		var half_w: float = float(feat.get("half_width", 38.0))
		var phase: float = float(feat.get("phase", 0.0))
		var bend: float = float(feat.get("bend", 0.0))
		var fords: Array = feat.get("fords", [])
		var ford_half: float = float(feat.get("ford_width", 90.0)) * 0.5
		for i in 18:
			var x := fposmod(i * 61.7 + clock * 22.0 + sin(i * 1.7) * 30.0, Terrain.ARENA.x)
			var in_ford := false
			for fx in fords:
				if absf(x - float(fx)) <= ford_half:
					in_ford = true
			if in_ford:
				continue
			var ry := 630.0 + sin(x * 0.007 + phase) * bend
			var y := ry + sin(i * 2.3 + clock * 0.6) * half_w * 0.6
			var a := 0.18 + 0.17 * sin(clock * 2.0 + i)
			c.draw_line(Vector2(x, y), Vector2(x + 7.0, y - 0.6), Color(0.95, 0.98, 1.0, a * alpha), 1.6)
		for fx in fords:
			var fry := 630.0 + sin(float(fx) * 0.007 + phase) * bend
			for k in 3:
				var tt := fposmod(clock * 0.5 + k * 0.33, 1.0)
				var at := Vector2(float(fx) + (k - 1) * ford_half * 0.5, fry + sin(k * 2.0) * half_w * 0.3)
				c.draw_arc(at, 3.0 + tt * 9.0, 0.0, TAU, 16, Color(0.95, 0.98, 1.0, 0.30 * (1.0 - tt) * alpha), 1.2)
