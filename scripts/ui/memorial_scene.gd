## The rise at the edge of camp where the company sets out its dead's stones, drawn in the
## game's pixel style like HallScene's halls, in the company's own way:
##
## - Vardish, the Cairn Field: mossy cairns with a pennant each, a tall standing stone on
##   its plinth with names cut into it, a dry-stone wall, an old oak, heather.
## - Kharzani, the Garden of Lamps: white headstones with a brass lamp each, a small domed
##   tomb on its steps, a whitewashed wall, cypresses and an olive tree, a paved walk.
## - Ryumon, the Lantern Grove: a stone lantern and a wooden tablet each, a great lantern
##   on its plinth, a bamboo fence, a maple with its leaves turning, stepping stones.
##
## Everything stands on the ground: the meadow slopes down toward you, lit by the moon
## from the right; each stone sits on its patch of earth with its shadow and the grass
## grown up round it, smaller the further up the slope it stands. Beyond the crest the
## mountains fade into the mist of the valley where the camp's tents glow round their
## fire. The company's banner hangs at half mast beside the monument. Up to SHOWN stones
## stand large (newest nearest); older ones stand in rows of small stones near the crest.
## The newest, if not yet mourned, is fresh earth with flowers and a stake. Drawn once into
## a small image and scaled up with hard pixel edges.
extends RefCounted

const W := 240
const H := 150
const SHOWN := 7

## Where each shown stone stands, newest first: its base on the meadow. Its size follows
## from how far up the slope it is (scale_at).
const SPOTS := [Vector2(54, 143), Vector2(188, 141), Vector2(120, 131), Vector2(214, 124),
	Vector2(84, 119), Vector2(160, 114), Vector2(198, 106)]
## The company's own stone (or tomb, or great lantern), and the banner pole beside it.
const MONUMENT := Vector2(144, 92)
const POLE := Vector2(166, 93)
## The camp, down in the valley beyond the crest: its fire.
const CAMP_FIRE := Vector2(30, 80)

const PENNANTS := {"vardish": Color("4a74d1"), "kharzani": Color("d9962b"), "ryumon": Color("b8352a")}

static var _cache := {}


## How large a thing stands at height `y` on the meadow: smaller up the slope.
static func scale_at(y: float) -> float:
	return clampf(0.7 + (y - 96.0) / 46.0 * 1.0, 0.55, 1.75)


## Where stone `i` (0 the newest) stands and how large: {at, scale}.
static func spot(i: int) -> Dictionary:
	var at: Vector2 = SPOTS[clampi(i, 0, SPOTS.size() - 1)]
	return {"at": at, "scale": scale_at(at.y)}


## The crest of the meadow at `x`: above it, the valley and the mountains.
static func crest(x: float) -> float:
	var y := 82.0 + sin(x * 0.021 + 0.6) * 5.0 + sin(x * 0.067) * 2.0
	# The meadow falls away on the left, where the camp lies below.
	if x < 70.0:
		y += (70.0 - x) * 0.16
	return y


## The rise for `culture` with `stones` (each {culture, hero}, newest first; only the first
## SHOWN are drawn large), the newest `fresh` (not yet mourned), at `when` ("dusk" or
## "night"), flying `banner` [cloth, mark] at half mast.
static func texture(culture: String, stones: Array, fresh: bool, when: String, banner: Array) -> Texture2D:
	var key := "%s|%s|%s|%s|%s" % [culture, JSON.stringify(stones), fresh, when, JSON.stringify(banner.map(func(c): return (c as Color).to_html()))]
	if _cache.has(key):
		return _cache[key]
	if _cache.size() > 24:
		_cache.clear()
	var tex := ImageTexture.create_from_image(image(culture, stones, fresh, when, banner))
	_cache[key] = tex
	return tex


static func image(culture: String, stones: Array, fresh: bool, when: String, banner: Array) -> Image:
	var img := Image.create(W, H, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(culture) + 7
	var night := when != "dusk"
	var L := _look(culture, night)
	_sky(img, rng, night)
	_mountains(img, night)
	_valley(img, rng, night)
	_meadow(img, rng, L)
	_path(img, rng, culture, L)
	# Behind the stones: the wall or fence along the crest, the trees, the monument.
	_boundary(img, rng, culture, L)
	_trees_back(img, rng, culture)
	match culture:
		"kharzani":
			_tomb(img, L)
		"ryumon":
			_great_lantern(img, L)
		_:
			_standing_stone(img, L)
	_banner_pole(img, banner)
	# The old stones, in rows near the crest, small: everyone past the newest SHOWN.
	var old := maxi(0, stones.size() - SHOWN)
	var old_spots := _old_spots(mini(old, 24))
	for i in old_spots.size():
		var at: Vector2 = old_spots[i]
		_stone(img, culture, at, scale_at(at.y) * 0.8, _pennant(stones[SHOWN + i]), L)
	# The shown stones, back to front so the nearer stand over the farther.
	var order := []
	for i in mini(stones.size(), SHOWN):
		order.append(i)
	order.sort_custom(func(a, b): return (SPOTS[a] as Vector2).y < (SPOTS[b] as Vector2).y)
	for i in order:
		var s := spot(i)
		if i == 0 and fresh:
			_fresh_grave(img, s["at"], s["scale"], _pennant(stones[0]), L)
		else:
			_stone(img, culture, s["at"], s["scale"], _pennant(stones[i]), L)
	_trees_front(img, rng, culture, L)
	_foreground(img, rng, culture, L)
	if not night:
		_blend(img, Color("3a1a08"), 0.12)
	return img


static func _pennant(s) -> Color:
	if s is Dictionary and bool(s.get("hero", false)):
		return Color("d9a944")
	var c := String(s.get("culture", "vardish")) if s is Dictionary else "vardish"
	return PENNANTS.get(c, PENNANTS["vardish"])


## Where the old stones stand: rows along the crest, clear of the monument and the path.
static func _old_spots(n: int) -> Array:
	var out := []
	var rows := [[96.0, [70, 86, 102, 182, 200, 216, 230]], [101.0, [62, 78, 94, 108, 176, 192, 208, 224]], [99.0, [118, 128, 186, 172]]]
	for r in rows:
		for x in r[1]:
			if out.size() >= n:
				return out
			out.append(Vector2(float(x), maxf(float(r[0]), crest(float(x)) + 8.0)))
	return out


## The palette of each place.
static func _look(culture: String, night: bool) -> Dictionary:
	var L: Dictionary = {
		"vardish": {"grass": Color("2f4630"), "grass_lit": Color("4a6a44"), "grass_dark": Color("1c2a1e"), "earth": Color("4a3424"),
			"path": Color("5a5448"), "stone": Color("8a8a96"), "stone_dark": Color("55556a"), "stone_lit": Color("b4b4c0"), "moss": Color("4a6a3a"),
			"flower": [Color("8a5a9a"), Color("b07ac8"), Color("e8c547")]},
		"kharzani": {"grass": Color("4a4a2e"), "grass_lit": Color("6a6a44"), "grass_dark": Color("2e2e1c"), "earth": Color("6a4a30"),
			"path": Color("a8987a"), "stone": Color("e2dac6"), "stone_dark": Color("a89c84"), "stone_lit": Color("f6f0e2"), "moss": Color("7a7a4a"),
			"flower": [Color("c8443c"), Color("e88aa0"), Color("e8c547")]},
		"ryumon": {"grass": Color("2c3e2c"), "grass_lit": Color("466446"), "grass_dark": Color("1a281c"), "earth": Color("4a3a2a"),
			"path": Color("6a6a70"), "stone": Color("82828c"), "stone_dark": Color("50505c"), "stone_lit": Color("aaaab4"), "moss": Color("3e6a3a"),
			"flower": [Color("e88aa0"), Color("f6cdd9"), Color("ece5d3")]},
	}.get(culture, {})
	if L.is_empty():
		L = _look("vardish", night)
	if not night:
		for k in ["grass", "grass_lit", "grass_dark"]:
			L[k] = (L[k] as Color).lightened(0.12)
	return L


# ---------------------------------------------------------------- sky, mountains, valley

static func _sky(img: Image, rng: RandomNumberGenerator, night: bool) -> void:
	var top := Color("0a0f22") if night else Color("2a2448")
	var low := Color("26304e") if night else Color("c0704e")
	for y in 90:
		var c := top.lerp(low, clampf(float(y) / 80.0, 0.0, 1.0))
		_rect(img, 0, y, W - 1, y, c)
	for i in 90:
		var x := rng.randi_range(0, W - 1)
		var y := rng.randi_range(0, 46)
		_dot(img, x, y, Color(1, 1, 0.92).darkened(rng.randf_range(0.0, 0.65)))
	# A few brighter stars with a cross of light.
	for s in [[38, 12], [92, 6], [128, 20]]:
		_dot(img, s[0], s[1], Color("fffbe8"))
		for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
			_dot(img, s[0] + d[0], s[1] + d[1], Color("7a86a8"))
	# The moon, a waning crescent with a halo.
	_glow(img, 202, 20, 22, Color("8a96c0"), 0.25)
	_disc(img, 202, 20, 8, Color("ece6cc"))
	_disc(img, 205, 18, 7, top.lerp(low, 0.24))


static func _mountains(img: Image, night: bool) -> void:
	var far := Color("26304a") if night else Color("6a5068")
	var far_lit := Color("323e5c") if night else Color("7a5e76")
	var mid := Color("1c2438") if night else Color("54405a")
	var snow := Color("9aa4c0") if night else Color("e0d0d0")
	# The far range: peaks, their moonlit faces on the right, snow on the highest.
	for x in W:
		var t := fmod(x / 34.0 + 0.35, 1.0)
		var tri := absf(t - 0.5) * 2.0
		var y1 := int(36.0 + tri * 20.0 + sin(x * 0.21) * 1.5 + (6.0 if int(x / 34.0) % 2 == 1 else 0.0))
		var lit_face := t > 0.5
		for y in range(y1, 90):
			img.set_pixel(x, y, far_lit if lit_face and y < y1 + 10 else far)
		if y1 < 44:
			for k in mini(3, 44 - y1):
				_dot(img, x, y1 + k, snow.darkened(0.15 * k) if lit_face else snow.darkened(0.35 + 0.1 * k))
	# The nearer hills, rounder and darker.
	for x in W:
		var y2 := int(62 + sin(x * 0.045 + 2.0) * 6 + sin(x * 0.11) * 3)
		_rect(img, x, y2, x, 89, mid)
	# Mist lying in the valley.
	for y in range(68, 84):
		var a := 0.22 * (1.0 - absf(y - 76.0) / 8.0)
		for x in W:
			img.set_pixel(x, y, img.get_pixel(x, y).lerp(Color("5a6688") if night else Color("c8a0a0"), a))


## The valley floor beyond the crest, and the camp on it: tents glowing, the fire, smoke.
static func _valley(img: Image, rng: RandomNumberGenerator, night: bool) -> void:
	var floor_c := Color("1e2a26") if night else Color("3e4a36")
	for x in W:
		_rect(img, x, 78, x, 89, floor_c.darkened(0.08 * float(x % 3 == 0)))
	# A dark line of trees along the valley.
	for x in range(80, W, 3):
		var h := 3 + int(absf(sin(x * 0.7)) * 4)
		_rect(img, x, 78 - h, x + 1, 78, Color("141c1a") if night else Color("2a3428"))
	# The camp: tents with their doorways lit, the fire between, a thread of smoke.
	var tent := Color("8a7a5a") if night else Color("a8946a")
	for t in [[12, 78], [24, 76], [44, 79], [52, 77]]:
		var tx: int = t[0]
		var ty: int = t[1]
		for r in 6:
			_rect(img, tx - r, ty - 6 + r, tx + r, ty - 6 + r, tent.darkened(0.25) if r % 2 else tent)
		_rect(img, tx - 1, ty - 2, tx, ty - 1, Color("ffb85a"))
	_glow(img, int(CAMP_FIRE.x), int(CAMP_FIRE.y), 18, Color("ff9a40"), 0.5)
	_dot(img, int(CAMP_FIRE.x), int(CAMP_FIRE.y), Color("ffe08a"))
	_dot(img, int(CAMP_FIRE.x) + 1, int(CAMP_FIRE.y), Color("ff9a3a"))
	_dot(img, int(CAMP_FIRE.x), int(CAMP_FIRE.y) - 1, Color("ffcf6a"))
	for i in 10:
		_dot(img, int(CAMP_FIRE.x) + int(sin(i * 0.9) * 2.0), int(CAMP_FIRE.y) - 3 - i * 2, Color(0.55, 0.58, 0.68).darkened(0.05 * i))
	# Figures by the fire.
	for f in [[26, 80], [35, 80]]:
		_rect(img, f[0], f[1] - 3, f[0], f[1], Color("2a2028"))


# ---------------------------------------------------------------- the meadow

static func _meadow(img: Image, rng: RandomNumberGenerator, L: Dictionary) -> void:
	var grass: Color = L["grass"]
	var lit: Color = L["grass_lit"]
	var dark: Color = L["grass_dark"]
	for x in W:
		var top := int(crest(x))
		for y in range(top, H):
			# Moonlit along the crest and on the right, darker as it comes toward you.
			var t := float(y - top) / float(maxi(1, H - top))
			var c := lit.lerp(grass, clampf(t * 2.2, 0.0, 1.0)).lerp(dark, clampf((t - 0.5) * 1.4, 0.0, 0.7))
			c = c.lerp(lit, 0.12 * float(x) / W)
			img.set_pixel(x, y, c)
		# The crest's edge catches the light.
		_dot(img, x, top, lit.lightened(0.15))
	# Texture: speckles, then tufts of grass growing taller toward you.
	for i in 420:
		var x := rng.randi_range(0, W - 1)
		var y := rng.randi_range(int(crest(x)) + 1, H - 1)
		_dot(img, x, y, (L["grass_lit"] as Color).lerp(L["grass_dark"], rng.randf()))
	for i in 140:
		var x := rng.randi_range(0, W - 1)
		var y := rng.randi_range(int(crest(x)) + 3, H - 1)
		var tall := 1 + int(scale_at(y) * 1.5)
		for k in tall:
			_dot(img, x + (k % 2), y - k, (L["grass_lit"] as Color).darkened(0.1 * k))
	# Small stones and wildflowers in the grass.
	for i in 26:
		var x := rng.randi_range(0, W - 1)
		var y := rng.randi_range(int(crest(x)) + 4, H - 2)
		_dot(img, x, y, L["stone_dark"])
		_dot(img, x + 1, y, L["stone"])
	for i in 40:
		var x := rng.randi_range(0, W - 1)
		var y := rng.randi_range(int(crest(x)) + 6, H - 1)
		var flowers: Array = L["flower"]
		_dot(img, x, y, flowers[i % flowers.size()])


## The path from the foot of the meadow up to the monument.
static func _path(img: Image, rng: RandomNumberGenerator, culture: String, L: Dictionary) -> void:
	var pc: Color = L["path"]
	for i in 60:
		var t := i / 60.0
		var x := lerpf(112.0, MONUMENT.x, t) + sin(t * 5.0) * 10.0 * (1.0 - t)
		var y := lerpf(float(H), MONUMENT.y + 3.0, t)
		var w := lerpf(7.0, 2.0, t)
		match culture:
			"ryumon":
				# Flat stepping stones, set apart.
				if i % 6 == 0:
					_ellipse(img, int(x - w), int(y - 1), int(x + w), int(y + 1), pc)
					_rect(img, int(x - w + 1), int(y - 1), int(x + w - 1), int(y - 1), (L["stone_lit"] as Color).darkened(0.2))
			"kharzani":
				# Paving, edged.
				_rect(img, int(x - w), int(y), int(x + w), int(y), pc if i % 3 else pc.darkened(0.15))
				_dot(img, int(x - w) - 1, int(y), pc.darkened(0.3))
				_dot(img, int(x + w) + 1, int(y), pc.darkened(0.3))
			_:
				# A trodden earth path with gravel.
				_rect(img, int(x - w), int(y), int(x + w), int(y), pc.lerp(L["earth"], 0.4))
				if rng.randf() < 0.5:
					_dot(img, int(x + rng.randf_range(-w, w)), int(y), pc.lightened(0.2))


# ---------------------------------------------------------------- what bounds it

## A boundary along the crest: a dry-stone wall, a whitewashed wall, a bamboo fence.
static func _boundary(img: Image, rng: RandomNumberGenerator, culture: String, L: Dictionary) -> void:
	for x in range(0, W):
		if x > 128 and x < 160:
			continue          # the monument stands in the gap
		var y := int(crest(x)) + 3
		match culture:
			"kharzani":
				_rect(img, x, y - 4, x, y, Color("cfc4a8"))
				_dot(img, x, y - 5, Color("efe6d0"))
				if x % 18 == 0:
					_rect(img, x, y - 6, x + 1, y, Color("e8dcc0"))
			"ryumon":
				if x % 3 == 0:
					_rect(img, x, y - 6, x, y, Color("8a9a4a"))
					_dot(img, x, y - 6, Color("a8b866"))
				if x % 12 == 0:
					_rect(img, x, y - 7, x, y, Color("5a4428"))
				_dot(img, x, y - 3, Color("5a4428"))
			_:
				var h := 3 + (1 if (x / 4) % 2 == 0 else 0)
				_rect(img, x, y - h, x, y, (L["stone"] as Color).darkened(0.25 + 0.15 * float((x + y) % 3 == 0)))
				_dot(img, x, y - h, (L["stone_lit"] as Color).darkened(0.1))
				if rng.randf() < 0.12:
					_dot(img, x, y - h + 1, L["moss"])


static func _trees_back(img: Image, rng: RandomNumberGenerator, culture: String) -> void:
	match culture:
		"kharzani":
			_cypress(img, 120, 88, 26)
			_cypress(img, 174, 88, 30)
			_cypress(img, 186, 90, 22)
		"ryumon":
			# Young maples along the fence.
			_round_tree(img, rng, 186, 86, 8, [Color("8a2a1c"), Color("b8402a"), Color("6a2418")])
		_:
			_round_tree(img, rng, 196, 86, 9, [Color("24361e"), Color("2e4426"), Color("1c2a18")])


## The trees in front: an old oak, an olive, a maple, standing on the meadow.
static func _trees_front(img: Image, rng: RandomNumberGenerator, culture: String, L: Dictionary) -> void:
	match culture:
		"kharzani":
			_olive(img, rng, 230, 120)
		"ryumon":
			_maple(img, rng, 20, 116)
		_:
			_oak(img, rng, 228, 112)


## Bushes and tall grass along the bottom edge, so the meadow runs on toward you.
static func _foreground(img: Image, rng: RandomNumberGenerator, culture: String, L: Dictionary) -> void:
	var dark: Color = (L["grass_dark"] as Color).darkened(0.25)
	for x in W:
		var h := 2 + int(absf(sin(x * 0.37)) * 3) + int(absf(sin(x * 0.11)) * 3)
		if x > 96 and x < 128:
			h = 1          # the path comes in here
		_rect(img, x, H - h, x, H - 1, dark)
	match culture:
		"vardish":
			# Heather by the wall.
			for i in 40:
				var x := rng.randi_range(0, W - 1)
				_dot(img, x, H - 1 - rng.randi_range(1, 4), Color("8a5a9a") if i % 2 else Color("6a3a7a"))
		"kharzani":
			# A rosebush at either side.
			for b in [[14, 146], [214, 147]]:
				_ellipse(img, b[0] - 7, b[1] - 6, b[0] + 7, b[1], Color("1e2e1a"))
				for i in 6:
					_dot(img, b[0] - 5 + i * 2, b[1] - 5 + (i % 2) * 2, Color("c8443c"))
		"ryumon":
			# Moss and fallen leaves.
			for i in 30:
				var x := rng.randi_range(0, W - 1)
				_dot(img, x, H - 1 - rng.randi_range(0, 3), Color("b8402a") if i % 3 else Color("d9622c"))


# ---------------------------------------------------------------- the monuments

## A shadow on the ground under something `w` wide at `at`, cast down-left by the moon.
static func _shadow(img: Image, at: Vector2, w: float, L: Dictionary) -> void:
	var c: Color = (L["grass_dark"] as Color).darkened(0.35)
	_ellipse(img, int(at.x - w * 0.9) - int(w * 0.35), int(at.y) - 1, int(at.x + w * 0.6) - int(w * 0.35), int(at.y) + maxi(1, int(w * 0.25)), c)


static func _plinth(img: Image, at: Vector2, w: int, L: Dictionary) -> void:
	var x := int(at.x)
	var y := int(at.y)
	_shadow(img, Vector2(x, y + 1), w + 2, L)
	_rect(img, x - w - 2, y - 2, x + w + 2, y + 1, (L["stone"] as Color).darkened(0.2))
	_rect(img, x - w - 2, y - 2, x + w + 2, y - 2, L["stone_lit"])
	_rect(img, x - w, y - 4, x + w, y - 3, (L["stone"] as Color).darkened(0.1))
	_rect(img, x - w, y - 4, x + w, y - 4, L["stone_lit"])


static func _standing_stone(img: Image, L: Dictionary) -> void:
	var x := int(MONUMENT.x)
	var y := int(MONUMENT.y)
	_plinth(img, MONUMENT, 9, L)
	var top := y - 40
	_rect(img, x - 6, top, x + 6, y - 5, L["stone"])
	_rect(img, x + 3, top, x + 6, y - 5, L["stone_lit"])
	_rect(img, x - 6, top, x - 5, y - 5, L["stone_dark"])
	_rect(img, x - 5, top - 2, x + 5, top - 1, L["stone"])
	_rect(img, x - 3, top - 3, x + 3, top - 3, L["stone"])
	# Names cut into it, line under line.
	for r in 8:
		_rect(img, x - 3, top + 5 + r * 4, x + 2 + (r % 3), top + 5 + r * 4, L["stone_dark"])
	for i in 8:
		_dot(img, x - 6 + (i * 5) % 12, y - 6 - (i * 7) % 30, L["moss"])


static func _tomb(img: Image, L: Dictionary) -> void:
	var x := int(MONUMENT.x)
	var y := int(MONUMENT.y)
	_plinth(img, MONUMENT, 14, L)
	# The walls, the dome, the doorway, the finial.
	_rect(img, x - 11, y - 20, x + 11, y - 5, L["stone"])
	_rect(img, x + 6, y - 20, x + 11, y - 5, L["stone_lit"])
	_rect(img, x - 11, y - 20, x - 10, y - 5, L["stone_dark"])
	_rect(img, x - 12, y - 21, x + 12, y - 20, L["stone_lit"])
	_half_disc(img, x, y - 21, 9, L["stone"])
	_half_disc(img, x + 3, y - 22, 5, L["stone_lit"])
	_rect(img, x - 3, y - 13, x + 3, y - 5, Color("2a1e1e"))
	_half_disc(img, x, y - 13, 3, Color("2a1e1e"))
	_rect(img, x, y - 34, x, y - 30, Color("b08a3a"))
	_dot(img, x, y - 35, Color("d9a944"))
	# A lamp in the doorway, and one at each corner.
	_dot(img, x, y - 8, Color("ffcf6a"))
	_glow(img, x, y - 8, 6, Color("ffb347"), 0.35)
	for cx in [x - 13, x + 13]:
		_rect(img, cx, y - 6, cx, y - 4, Color("b08a3a"))


static func _great_lantern(img: Image, L: Dictionary) -> void:
	var x := int(MONUMENT.x)
	var y := int(MONUMENT.y)
	_plinth(img, MONUMENT, 10, L)
	var s: Color = L["stone"]
	var lit: Color = L["stone_lit"]
	var dk: Color = L["stone_dark"]
	_rect(img, x - 7, y - 8, x + 7, y - 5, s)
	_rect(img, x - 3, y - 22, x + 3, y - 8, s)
	_rect(img, x + 1, y - 22, x + 3, y - 8, lit)
	_rect(img, x - 8, y - 25, x + 8, y - 22, s)
	_rect(img, x - 6, y - 33, x + 6, y - 25, s)
	_rect(img, x - 3, y - 31, x + 3, y - 27, Color("2a2018"))
	_dot(img, x, y - 29, Color("ffb85a"))
	_glow(img, x, y - 29, 7, Color("ffb347"), 0.35)
	_rect(img, x - 11, y - 37, x + 11, y - 34, dk)
	_rect(img, x - 11, y - 37, x + 11, y - 37, lit)
	_rect(img, x - 4, y - 40, x + 4, y - 38, s)
	_rect(img, x - 1, y - 43, x + 1, y - 41, s)


static func _banner_pole(img: Image, banner: Array) -> void:
	var x := int(POLE.x)
	var base := int(POLE.y)
	var top := base - 52
	# Its stone footing, the pole, the finial, the halyard.
	_rect(img, x - 2, base - 2, x + 2, base, Color("6a6a74"))
	_rect(img, x, top, x, base - 2, Color("8a6a3a"))
	_dot(img, x, top - 1, Color("cbb27a"))
	_rect(img, x - 1, top + 2, x - 1, base - 3, Color("5a4a3a"))
	# At half mast.
	var cloth: Color = banner[0] if banner.size() > 0 else Color("4a74d1")
	var mark: Color = banner[1] if banner.size() > 1 else Color("e8ebf2")
	var fy := top + 20
	for r in 11:
		var sag := int(sin(r * 0.5) * 1.0)
		_rect(img, x + 1, fy + r + sag, x + 13 - (r / 5), fy + r + sag, cloth if r < 10 else cloth.darkened(0.35))
	_rect(img, x + 5, fy + 3, x + 8, fy + 6, mark)


# ---------------------------------------------------------------- trees

static func _cypress(img: Image, x: int, base: int, tall: int) -> void:
	_rect(img, x, base - 2, x, base, Color("3a2a18"))
	for r in tall:
		var w := int(sin(float(r) / tall * PI) * 3.5) + 1
		_rect(img, x - w, base - 2 - r, x + w, base - 2 - r, Color("1e3a2a") if r % 3 else Color("2a4a34"))
		_dot(img, x + w, base - 2 - r, Color("3a5a40"))


static func _round_tree(img: Image, rng: RandomNumberGenerator, x: int, base: int, r: int, cols: Array) -> void:
	_rect(img, x, base - r, x + 1, base, Color("3a2a18"))
	for i in r * 14:
		var a := rng.randf() * TAU
		var d := rng.randf() * r
		_dot(img, x + int(cos(a) * d * 1.2), base - r - 2 + int(sin(a) * d * 0.8), cols[i % cols.size()])


## An old oak at the meadow's edge: a thick trunk with roots, a broad dark crown.
static func _oak(img: Image, rng: RandomNumberGenerator, x: int, base: int) -> void:
	var bark := Color("3a2a1c")
	_rect(img, x - 3, base - 26, x + 2, base, bark)
	_rect(img, x + 1, base - 26, x + 2, base, bark.lightened(0.15))
	_rect(img, x - 6, base - 1, x + 5, base, bark)
	_rect(img, x - 12, base - 30, x - 2, base - 28, bark)
	_rect(img, x + 2, base - 34, x + 10, base - 32, bark)
	for i in 520:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * 22.0
		var px := x + int(cos(a) * d * 1.3)
		var py := base - 44 + int(sin(a) * d * 0.75)
		var c := Color("1e2e1a") if rng.randf() < 0.5 else Color("28401f")
		if cos(a) > 0.3 and rng.randf() < 0.4:
			c = Color("3a5a2c")
		_dot(img, px, py, c)


static func _olive(img: Image, rng: RandomNumberGenerator, x: int, base: int) -> void:
	var bark := Color("5a4a3a")
	_rect(img, x - 2, base - 16, x + 1, base, bark)
	_rect(img, x - 6, base - 18, x - 2, base - 16, bark)
	_rect(img, x + 1, base - 22, x + 5, base - 20, bark)
	for i in 320:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * 15.0
		_dot(img, x + int(cos(a) * d * 1.3), base - 28 + int(sin(a) * d * 0.7), Color("5a6a4a") if rng.randf() < 0.5 else Color("7a8a62"))


static func _maple(img: Image, rng: RandomNumberGenerator, x: int, base: int) -> void:
	var bark := Color("3a2418")
	_rect(img, x - 2, base - 30, x + 1, base, bark)
	_rect(img, x - 5, base - 1, x + 4, base, bark)
	_rect(img, x + 1, base - 24, x + 12, base - 22, bark)
	_rect(img, x - 10, base - 28, x - 2, base - 26, bark)
	for i in 600:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * 22.0
		_dot(img, x + 2 + int(cos(a) * d * 1.3), base - 42 + int(sin(a) * d * 0.75),
			[Color("8a1c14"), Color("b8352a"), Color("d9622c"), Color("6a1810")][i % 4])
	# Leaves fallen round its foot.
	for i in 30:
		_dot(img, x + rng.randi_range(-14, 16), base + rng.randi_range(-1, 3), Color("b8352a") if i % 2 else Color("d9622c"))


# ---------------------------------------------------------------- the stones

## One of the company's stones, `s` large, its base on `at`, with its pennant: its patch of
## earth and its shadow first, then the stone, then grass grown up round its foot.
static func _stone(img: Image, culture: String, at: Vector2, s: float, pennant: Color, L: Dictionary) -> void:
	var x := int(at.x)
	var y := int(at.y)
	var st: Color = L["stone"]
	var lit: Color = L["stone_lit"]
	var dk: Color = L["stone_dark"]
	_shadow(img, at, 7.0 * s, L)
	_ellipse(img, x - int(5 * s), y - 1, x + int(5 * s), y + maxi(1, int(s)), L["earth"])
	match culture:
		"kharzani":
			var w := maxi(2, int(3.5 * s))
			var h := maxi(4, int(9 * s))
			_rect(img, x - w, y - h, x + w, y, st)
			_rect(img, x + int(w * 0.4), y - h, x + w, y, lit)
			_rect(img, x - w, y - h, x - w, y, dk)
			_half_disc(img, x, y - h, w, st)
			_dot(img, x + w - 1, y - h - w + 2, lit)
			# A carved band in their colour, and the lamp on the ground beside it.
			_rect(img, x - w + 1, y - h + maxi(1, int(2 * s)), x + w - 1, y - h + maxi(1, int(2 * s)), pennant.darkened(0.15))
			_rect(img, x + w + 2, y - maxi(2, int(2.5 * s)), x + w + maxi(3, int(3 * s)), y, Color("b08a3a"))
			_dot(img, x + w + 2, y - maxi(2, int(2.5 * s)) - 1, Color("d9a944"))
		"ryumon":
			var h := maxi(6, int(12 * s))
			var u := maxf(1.0, s)
			_rect(img, x - int(3 * u), y - int(2 * u), x + int(3 * u), y, st)
			_rect(img, x - int(1 * u), y - h + int(4 * u), x + int(1 * u), y - int(2 * u), st)
			_rect(img, x, y - h + int(4 * u), x + int(1 * u), y - int(2 * u), lit)
			_rect(img, x - int(3 * u), y - h + int(1 * u), x + int(3 * u), y - h + int(4 * u), st)
			_rect(img, x - int(1 * u), y - h + int(2 * u), x + int(1 * u), y - h + int(3 * u), Color("2a2018"))
			_rect(img, x - int(4 * u), y - h, x + int(4 * u), y - h, dk)
			_rect(img, x - int(4 * u) + 1, y - h - 1, x + int(4 * u) - 1, y - h - 1, lit)
			# The tablet beside it, its name in the company's colour.
			_rect(img, x + int(5 * u), y - int(11 * u), x + int(6 * u), y, Color("c8a878"))
			_dot(img, x + int(5 * u), y - int(11 * u) - 1, Color("c8a878"))
			_rect(img, x + int(5 * u), y - int(9 * u), x + int(6 * u), y - int(8 * u), pennant)
		_:
			# A cairn: rows of stones narrowing up, lit on the right, mossy, a pennant on top.
			var rows := maxi(3, int(4.5 * s))
			var top := y
			for r in rows:
				var half := maxi(1, int((rows - r) * 1.3 * maxf(0.8, s * 0.7)))
				var ry := y - r * 2
				_rect(img, x - half, ry - 1, x + half, ry, st if r % 2 == 0 else st.darkened(0.12))
				_rect(img, x + half - maxi(1, half / 2), ry - 1, x + half, ry - 1, lit)
				_dot(img, x - half, ry, dk)
				if r % 2 == 1:
					_dot(img, x - half + 1, ry - 1, L["moss"])
				top = ry - 1
			_rect(img, x, top - int(10 * s), x, top, Color("6b4426"))
			var pw := maxi(3, int(5 * s))
			var ph := maxi(2, int(3 * s))
			for r in ph:
				_rect(img, x + 1, top - int(10 * s) + r, x + pw - (r % 2), top - int(10 * s) + r, pennant if r < ph - 1 else pennant.darkened(0.3))
	# Grass grown up round its foot.
	for i in int(4 + 3 * s):
		var gx := x - int(5 * s) + (i * 3) % maxi(1, int(10 * s))
		_dot(img, gx, y, (L["grass_lit"] as Color).darkened(0.1))
		_dot(img, gx, y - 1, L["grass"])


## The newest grave, not yet mourned: a mound of fresh earth, flowers on it, a stake with
## their pennant, an unlit candle.
static func _fresh_grave(img: Image, at: Vector2, s: float, pennant: Color, L: Dictionary) -> void:
	var x := int(at.x)
	var y := int(at.y)
	var w := int(9 * s)
	_shadow(img, at, 9.0 * s, L)
	var earth: Color = L["earth"]
	_ellipse(img, x - w, y - int(3 * s), x + w, y + 1, earth)
	_ellipse(img, x - w + 2, y - int(3 * s), x + w - 2, y - int(1.5 * s), earth.lightened(0.15))
	for i in 9:
		_dot(img, x - w + 3 + (i * int(2.2 * s)) % (w * 2 - 4), y - int(2 * s) - (i % 2), (L["flower"] as Array)[i % 3])
	_rect(img, x, y - int(15 * s), x, y - int(2 * s), Color("6b4426"))
	_rect(img, x + 1, y - int(15 * s), x + int(5 * s), y - int(12 * s), pennant)
	_rect(img, x + w - 3, y - int(2 * s) - 2, x + w - 3, y - int(2 * s), Color("ece5d3"))


# ---------------------------------------------------------------- pixel primitives

static func _rect(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	var a := maxi(0, mini(x0, x1))
	var b := mini(W - 1, maxi(x0, x1))
	var top := maxi(0, mini(y0, y1))
	var bottom := mini(H - 1, maxi(y0, y1))
	if a > b or top > bottom:
		return
	img.fill_rect(Rect2i(a, top, b - a + 1, bottom - top + 1), c)


static func _dot(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and x < W and y >= 0 and y < H:
		img.set_pixel(x, y, c)


static func _disc(img: Image, cx: int, cy: int, r: int, c: Color) -> void:
	for y in range(cy - r, cy + r + 1):
		for x in range(cx - r, cx + r + 1):
			if Vector2(x - cx, y - cy).length() <= r:
				_dot(img, x, y, c)


static func _half_disc(img: Image, cx: int, base: int, r: int, c: Color) -> void:
	for y in range(base - r, base + 1):
		for x in range(cx - r, cx + r + 1):
			if Vector2(x - cx, y - base).length() <= r:
				_dot(img, x, y, c)


static func _ellipse(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	var cx := (float(x0) + float(x1) + 1.0) * 0.5
	var cy := (float(y0) + float(y1) + 1.0) * 0.5
	var rx := maxf(0.5, (float(x1) - float(x0) + 1.0) * 0.5)
	var ry := maxf(0.5, (float(y1) - float(y0) + 1.0) * 0.5)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var dx := (float(x) + 0.5 - cx) / rx
			var dy := (float(y) + 0.5 - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				_dot(img, x, y, c)


static func _glow(img: Image, cx: int, cy: int, r: int, c: Color, strength: float) -> void:
	for y in range(maxi(0, cy - r), mini(H, cy + r)):
		for x in range(maxi(0, cx - r), mini(W, cx + r)):
			var d := Vector2(x - cx, y - cy).length() / float(r)
			if d < 1.0:
				img.set_pixel(x, y, img.get_pixel(x, y).lerp(c, (1.0 - d) * (1.0 - d) * strength))


static func _blend(img: Image, c: Color, a: float) -> void:
	for y in H:
		for x in W:
			img.set_pixel(x, y, img.get_pixel(x, y).lerp(c, a))
