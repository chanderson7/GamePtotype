## The rise at the edge of camp where the company sets out its dead's stones, drawn in the
## game's pixel style like HallScene's halls, in the company's own way:
##
## - Vardish, the Cairn Field: cairns of grey stones with a pennant each, a tall standing
##   stone with names cut into it.
## - Kharzani, the Garden of Lamps: white headstones with a brass lamp each, a cypress, a
##   small domed tomb.
## - Ryumon, the Lantern Grove: a stone lantern and a wooden tablet each, under a maple.
##
## The camp's tents and fire are small and far off below; the company's banner hangs at
## half mast. Up to SHOWN_STONES stand large (newest nearest); older ones are a cluster of
## small stones further up the hill. The newest, if not yet mourned, is fresh earth with
## flowers and a stake. Drawn once into a small image and scaled up with hard pixel edges.
extends RefCounted

const W := 240
const H := 150
const SHOWN := 7

## Where each shown stone stands, newest first: [base (x, y), scale].
const SPOTS := [[Vector2(58, 140), 1.6], [Vector2(184, 136), 1.5], [Vector2(122, 126), 1.3], [Vector2(214, 119), 1.15],
	[Vector2(90, 112), 1.05], [Vector2(154, 107), 1.0], [Vector2(196, 99), 0.85]]
## The company's own stone (or tomb, or great lantern), and the banner pole beside it.
const MONUMENT := Vector2(146, 88)
const POLE := Vector2(166, 52)
## The camp, far off and below: its fire.
const CAMP_FIRE := Vector2(30, 104)

const PENNANTS := {"vardish": Color("4a74d1"), "kharzani": Color("d9962b"), "ryumon": Color("b8352a")}

static var _cache := {}


## Where stone `i` (0 the newest) stands and how large: {at, scale}.
static func spot(i: int) -> Dictionary:
	var s: Array = SPOTS[clampi(i, 0, SPOTS.size() - 1)]
	return {"at": s[0], "scale": float(s[1])}


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
	_sky(img, rng, night)
	_far(img, night)
	_hill(img, rng, culture, night)
	match culture:
		"kharzani":
			_tomb(img)
		"ryumon":
			_great_lantern(img)
		_:
			_standing_stone(img)
	_banner_pole(img, banner)
	if culture == "kharzani":
		_cypress(img, 210, 84)
	elif culture == "ryumon":
		_maple(img, 30, 92, rng)
	# The old stones, further up, small: everyone past the newest SHOWN.
	var old := maxi(0, stones.size() - SHOWN)
	for i in mini(old, 24):
		var x := 52 + (i * 37) % 80 + rng.randi_range(-3, 3)
		var y := 88 + (i * 7) % 8
		_stone(img, culture, Vector2(x, y), 0.5, _pennant(stones[SHOWN + i]))
	# The shown stones, back to front so the nearest is drawn over the rest.
	var shown := mini(stones.size(), SHOWN)
	for i in range(shown - 1, -1, -1):
		var s := spot(i)
		if i == 0 and fresh:
			_fresh_grave(img, s["at"], s["scale"], _pennant(stones[0]))
		else:
			_stone(img, culture, s["at"], s["scale"], _pennant(stones[i]))
	if not night:
		_blend(img, Color("3a1a08"), 0.12)
	return img


static func _pennant(s) -> Color:
	if s is Dictionary and bool(s.get("hero", false)):
		return Color("d9a944")
	var c := String(s.get("culture", "vardish")) if s is Dictionary else "vardish"
	return PENNANTS.get(c, PENNANTS["vardish"])


# ---------------------------------------------------------------- the land

static func _sky(img: Image, rng: RandomNumberGenerator, night: bool) -> void:
	var top := Color("0b1024") if night else Color("2a2448")
	var low := Color("1f2440") if night else Color("b8644a")
	for y in H:
		var t := float(y) / float(H * 0.7)
		var c := top.lerp(low, clampf(t, 0.0, 1.0))
		for x in W:
			img.set_pixel(x, y, c)
	for i in 70:
		_dot(img, rng.randi_range(0, W - 1), rng.randi_range(0, 60), Color(1, 1, 0.9).darkened(rng.randf_range(0.0, 0.6)))
	# The moon, a waning crescent.
	_disc(img, 200, 22, 8, Color("e8e2c8"))
	_disc(img, 203, 20, 7, top.lerp(low, 0.25))


static func _far(img: Image, night: bool) -> void:
	var far := Color("151a2e") if night else Color("4a3048")
	for x in W:
		var y := int(78 + sin(x * 0.05) * 6 + sin(x * 0.13) * 3)
		_rect(img, x, y, x, H - 1, far)
	# The camp, small and below, on the left: tents and a fire.
	var tent := Color("6a6250") if night else Color("8a7a5a")
	for t in [[14, 98], [26, 96], [42, 99]]:
		for r in 7:
			_rect(img, int(t[0]) - r, int(t[1]) + r, int(t[0]) + r, int(t[1]) + r, tent.darkened(0.2 if r % 2 else 0.0))
	_glow(img, int(CAMP_FIRE.x), int(CAMP_FIRE.y), 16, Color("ff9a40"), 0.45)
	_dot(img, int(CAMP_FIRE.x), int(CAMP_FIRE.y), Color("ffcf6a"))
	_dot(img, int(CAMP_FIRE.x) + 1, int(CAMP_FIRE.y), Color("ff9a3a"))


static func _hill(img: Image, rng: RandomNumberGenerator, culture: String, night: bool) -> void:
	var grass: Color = {"kharzani": Color("4a4a2a"), "ryumon": Color("2e3e2a")}.get(culture, Color("2b3a2a"))
	if not night:
		grass = grass.lightened(0.15)
	for x in W:
		var y := int(H * 0.6 - sin((x - 150) * 0.018) * 16)
		for yy in range(y, H):
			var shade: Color = grass.darkened(0.12 * float(yy - y) / float(H - y))
			img.set_pixel(x, yy, shade)
		if x % 5 == 0:
			_dot(img, x, y, grass.lightened(0.25))
	for i in 160:
		var x := rng.randi_range(0, W - 1)
		var y := rng.randi_range(int(H * 0.6), H - 1)
		_dot(img, x, y, grass.lightened(rng.randf_range(0.05, 0.2)))
	# A worn path up from the camp.
	for i in 30:
		var t := i / 30.0
		var x := int(lerpf(40, 140, t)) + int(sin(t * 6.0) * 3)
		var y := int(lerpf(H - 2, 92, t))
		_rect(img, x - 1, y, x + 1, y, grass.lightened(0.12))


# ---------------------------------------------------------------- the monuments

static func _standing_stone(img: Image) -> void:
	var x := int(MONUMENT.x)
	var y := int(MONUMENT.y)
	_rect(img, x - 7, y - 36, x + 7, y, Color("6a6a78"))
	_rect(img, x - 7, y - 36, x - 6, y, Color("8a8a96"))
	_rect(img, x - 6, y - 38, x + 6, y - 37, Color("6a6a78"))
	for r in 7:
		_rect(img, x - 3, y - 32 + r * 4, x + 4, y - 32 + r * 4, Color("3a3a48"))


static func _tomb(img: Image) -> void:
	var x := int(MONUMENT.x)
	var y := int(MONUMENT.y)
	_rect(img, x - 12, y - 18, x + 12, y, Color("e8e0cc"))
	_rect(img, x - 12, y - 18, x - 11, y, Color("c8bca4"))
	_half_disc(img, x, y - 18, 10, Color("e8e0cc"))
	_rect(img, x - 3, y - 10, x + 3, y, Color("3a2a2a"))
	_dot(img, x, y - 30, Color("d9a944"))


static func _great_lantern(img: Image) -> void:
	var x := int(MONUMENT.x)
	var y := int(MONUMENT.y)
	var stone := Color("7a7a84")
	_rect(img, x - 8, y - 4, x + 8, y, stone)
	_rect(img, x - 3, y - 18, x + 3, y - 4, stone)
	_rect(img, x - 7, y - 26, x + 7, y - 18, stone)
	_rect(img, x - 3, y - 24, x + 3, y - 20, Color("2a2018"))
	_rect(img, x - 10, y - 30, x + 10, y - 27, stone.darkened(0.15))
	_rect(img, x - 1, y - 33, x + 1, y - 31, stone)


static func _banner_pole(img: Image, banner: Array) -> void:
	var x := int(POLE.x)
	var y := int(POLE.y)
	_rect(img, x, y, x, int(MONUMENT.y), Color("8a6a3a"))
	_dot(img, x, y - 1, Color("cbb27a"))
	# At half mast.
	var cloth: Color = banner[0] if banner.size() > 0 else Color("4a74d1")
	var mark: Color = banner[1] if banner.size() > 1 else Color("e8ebf2")
	var top := y + 14
	_rect(img, x + 1, top, x + 12, top + 9, cloth)
	_rect(img, x + 1, top + 10, x + 12, top + 10, cloth.darkened(0.3))
	_rect(img, x + 5, top + 3, x + 8, top + 6, mark)


static func _cypress(img: Image, x: int, y: int) -> void:
	for r in 30:
		var w := int(sin(r / 30.0 * PI) * 5) + 1
		_rect(img, x - w, y - r, x + w, y - r, Color("1e3a2a").darkened(0.1 * (r % 2)))
	_rect(img, x, y, x, y + 4, Color("3a2a18"))


static func _maple(img: Image, x: int, y: int, rng: RandomNumberGenerator) -> void:
	_rect(img, x, y - 20, x + 2, y + 8, Color("3a2418"))
	_rect(img, x + 2, y - 14, x + 10, y - 13, Color("3a2418"))
	for i in 90:
		var a := rng.randf() * TAU
		var r := rng.randf() * 14.0
		_dot(img, x + 1 + int(cos(a) * r * 1.3), y - 24 + int(sin(a) * r * 0.8), [Color("a8261c"), Color("c8443c"), Color("d9622c")][i % 3])


# ---------------------------------------------------------------- the stones

## One of the company's stones, `s` large, its base centred on `at`, with its pennant.
static func _stone(img: Image, culture: String, at: Vector2, s: float, pennant: Color) -> void:
	var x := int(at.x)
	var y := int(at.y)
	match culture:
		"kharzani":
			var w := int(4 * s)
			var h := int(9 * s)
			_rect(img, x - w, y - h, x + w, y, Color("e8e0cc"))
			_rect(img, x - w, y - h, x - w, y, Color("c8bca4"))
			_half_disc(img, x, y - h, w, Color("e8e0cc"))
			_rect(img, x - w + 1, y - h + int(2 * s), x + w - 1, y - h + int(2 * s), pennant.darkened(0.2))
			# Its lamp, on the ground beside it.
			_rect(img, x + w + 2, y - int(2 * s), x + w + int(3 * s), y, Color("b08a3a"))
		"ryumon":
			var stone := Color("7a7a84")
			var h := int(12 * s)
			_rect(img, x - int(3 * s), y - int(2 * s), x + int(3 * s), y, stone)
			_rect(img, x - int(1 * s), y - h + int(4 * s), x + int(1 * s), y - int(2 * s), stone)
			_rect(img, x - int(3 * s), y - h + int(1 * s), x + int(3 * s), y - h + int(4 * s), stone)
			_rect(img, x - int(1 * s), y - h + int(2 * s), x + int(1 * s), y - h + int(3 * s), Color("2a2018"))
			_rect(img, x - int(4 * s), y - h, x + int(4 * s), y - h, stone.darkened(0.15))
			# The tablet beside it, its name in the company's colour.
			_rect(img, x + int(5 * s), y - int(11 * s), x + int(6 * s), y, Color("c8a878"))
			_rect(img, x + int(5 * s), y - int(9 * s), x + int(6 * s), y - int(8 * s), pennant)
		_:
			# A cairn: rows of stones narrowing up, light and dark.
			var rows := int(5 * s)
			for r in rows:
				var half := int((rows - r) * 1.2)
				var c := Color("8a8a96") if r % 2 == 0 else Color("6e6e7a")
				_rect(img, x - half, y - r * 2, x + half, y - r * 2 - 1, c)
			_rect(img, x, y - rows * 2 - int(10 * s), x, y - rows * 2, Color("6b4426"))
			_rect(img, x + 1, y - rows * 2 - int(10 * s), x + int(5 * s), y - rows * 2 - int(10 * s) + int(3 * s), pennant)


## The newest grave, not yet mourned: fresh earth, flowers, a stake with their pennant.
static func _fresh_grave(img: Image, at: Vector2, s: float, pennant: Color) -> void:
	var x := int(at.x)
	var y := int(at.y)
	var w := int(9 * s)
	_rect(img, x - w, y - int(2 * s), x + w, y, Color("4a3424"))
	_rect(img, x - w + 2, y - int(3 * s), x + w - 2, y - int(2 * s), Color("5a4030"))
	for i in 7:
		_dot(img, x - w + 2 + i * int(2.5 * s), y - int(3 * s) - 1, [Color("e88aa0"), Color("e8c547"), Color("ece5d3")][i % 3])
	_rect(img, x, y - int(14 * s), x, y - int(2 * s), Color("6b4426"))
	_rect(img, x + 1, y - int(14 * s), x + int(5 * s), y - int(11 * s), pennant)


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
