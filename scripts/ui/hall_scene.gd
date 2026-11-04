## The inside of a hall, drawn in the game's pixel style: a Vardish great hall (stone and
## timber, the high seat on its dais, a hearth, the long table), a Kharzani courtyard
## (arches onto a garden, carpets, cushions and lanterns) or a Ryumon audience hall (paper
## screens, tatami, low tables, a scroll in the alcove). The holder's banners hang on the
## walls, and the hour tints it. Drawn once into a small image and scaled up with hard
## pixel edges, like the settlement vistas.
extends RefCounted

const Data = preload("res://scripts/world/world_data.gd")

const W := 240
const H := 150

## Pixel banners by realm: [cloth, mark].
const BANNERS := {
	"vardmark": [Color("3459b8"), Color("e8ebf2")],
	"kharzan": [Color("d9962b"), Color("a8261c")],
	"ryumon": [Color("b8352a"), Color("f1ece0")],
	"crown": [Color("1d1a2a"), Color("d9a944")],
}

static var _cache := {}


## The hall for `culture` hung with `realm`'s banners at `when` ("morning", "midday",
## "afternoon", "dusk", "night"). `seed` keeps one place's hall the same every visit.
static func texture(culture: String, realm: String, when: String, seed: int = 3) -> Texture2D:
	var key := "%s|%s|%s|%d" % [culture, realm, when, seed]
	if _cache.has(key):
		return _cache[key]
	var img := image(culture, realm, when, seed)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## A TextureRect showing the hall, covering whatever it's given.
static func rect(culture: String, realm: String, when: String, seed: int = 3) -> TextureRect:
	var art := TextureRect.new()
	art.name = "Hall"
	art.texture = texture(culture, realm, when, seed)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return art


static func image(culture: String, realm: String, when: String, seed: int = 3) -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var night := when == "night"
	var colors: Array = BANNERS.get(realm, BANNERS["vardmark"])
	if realm == "crown":
		colors = [Color("1d1a2a"), _crown_ink()]
	var img: Image
	match culture:
		"kharzani":
			img = _kharzani(rng, night, colors)
		"ryumon":
			img = _ryumon(rng, night, colors)
		_:
			img = _vardish(rng, night, colors)
	# The hour: evening warms it, night cools and darkens it, morning is pale.
	match when:
		"dusk":
			_blend(img, Color("3a1a08"), 0.14)
		"night":
			_blend(img, Color("101830"), 0.28)
		"morning":
			_blend(img, Color("f4ead8"), 0.06)
		_:
			_blend(img, Color("3a1a08"), 0.06)
	return img


static func _crown_ink() -> Color:
	return Data.crown_color


# ---------------------------------------------------------------- the three halls

static func _vardish(rng: RandomNumberGenerator, night: bool, banner: Array) -> Image:
	var img := Image.create(W, H, false, Image.FORMAT_RGB8)
	img.fill(Color("3b3a44"))
	# Stone, course by course.
	var stone := Color("5d5c68")
	for row in range(0, 100, 7):
		var off := (row / 7) % 2 * 9
		for x in range(-9, W, 18):
			_rect(img, x + off, row, x + off + 16, row + 5, _shade(stone, 0.88 + rng.randf() * 0.2))
	# Tall windows, starlit at night.
	var glass := Color("0d1430") if night else Color("1d2a4e")
	for wx in [38, 186]:
		_rect(img, wx, 18, wx + 15, 58, glass)
		_half_disc(img, wx + 7.5, 18.0, 7.5, glass)
		_rect(img, wx + 7, 12, wx + 7, 58, Color("2a2a33"))
		_rect(img, wx, 36, wx + 15, 36, Color("2a2a33"))
		if not night:
			for i in 6:
				_dot(img, wx + 2 + rng.randi_range(0, 11), 16 + rng.randi_range(0, 38), Color("e6c37a"))
		else:
			for i in 3:
				_dot(img, wx + 2 + rng.randi_range(0, 11), 16 + rng.randi_range(0, 38), Color("c8d0f0"))
	# Roof beams and posts.
	_rect(img, 0, 0, W, 6, Color("3a2414"))
	_rect(img, 0, 6, W, 7, Color("241608"))
	for px in [20, W - 24]:
		_rect(img, px, 0, px + 5, 104, Color("4a2e18"))
		_rect(img, px, 0, px, 104, Color("6b4426"))
	_banner(img, 70, 10, 16, 38, banner[0], banner[1])
	_banner(img, 154, 10, 16, 38, banner[0], banner[1])
	# The dais and the high seat.
	_rect(img, 92, 78, 148, 92, Color("5a3a22"))
	_rect(img, 92, 78, 148, 79, Color("7a5232"))
	_rect(img, 110, 40, 130, 80, Color("4a2c16"))
	_rect(img, 112, 42, 128, 64, Color("8e1f17"))
	_rect(img, 108, 36, 132, 41, Color("6b4426"))
	_dot(img, 120, 35, Color("d9a944"))
	# The hearth.
	_rect(img, 196, 64, 232, 100, Color("4b4a55"))
	_rect(img, 202, 74, 226, 100, Color("140c08"))
	var flames := [Color("ffcf6a"), Color("ff8a3a"), Color("e2553f")]
	for i in 14:
		_dot(img, 204 + rng.randi_range(0, 20), 88 + rng.randi_range(0, 10), flames[rng.randi_range(0, 2)])
	_glow(img, 214, 92, 40, Color("ff9a40"), 0.5)
	# Flagstones, strewn with rushes.
	for y in range(100, H):
		for x in W:
			img.set_pixel(x, y, _shade(Color("4a3f38"), 0.9 + 0.1 * float((x / 12 + y / 6) % 2)))
	for i in 120:
		_dot(img, rng.randi_range(0, W - 1), rng.randi_range(102, H - 1), Color("8a7a4a"))
	# The long table, set.
	_rect(img, 14, 116, 226, 124, Color("6b4426"))
	_rect(img, 14, 116, 226, 117, Color("8a5c34"))
	_rect(img, 20, 124, 24, 140, Color("4a2e18"))
	_rect(img, 216, 124, 220, 140, Color("4a2e18"))
	for x in range(26, 214, 14):
		_rect(img, x, 112, x + 3, 116, Color("c8b080"))
		_dot(img, x + 1, 111, Color("e8dcb8"))
		_rect(img, x + 6, 114, x + 10, 116, Color("b07a3a"))
	_rect(img, 10, 132, 230, 135, Color("4a2e18"))
	for t in [[22, 60], [W - 22, 60], [98, 64], [142, 64]]:
		_torch(img, int(t[0]), int(t[1]))
	return img


static func _kharzani(rng: RandomNumberGenerator, night: bool, banner: Array) -> Image:
	var img := Image.create(W, H, false, Image.FORMAT_RGB8)
	var wall := Color("c9a77a")
	img.fill(wall)
	for i in 400:
		_dot(img, rng.randi_range(0, W - 1), rng.randi_range(0, 99), _shade(wall, 0.9 + rng.randf() * 0.15))
	# Arches onto the garden.
	var shadow := Color("3a2a2e") if night else Color("5a3a32")
	for ax in [12, 72, 132, 192]:
		_rect(img, ax, 40, ax + 36, 100, shadow)
		_half_disc(img, ax + 18.0, 40.0, 18.0, shadow)
		_arc(img, ax + 18.0, 40.0, 20.0, Color("8a6a4a"))
		_rect(img, ax - 3, 40, ax - 1, 100, Color("e0c69a"))
		_rect(img, ax + 37, 40, ax + 39, 100, Color("e0c69a"))
		_rect(img, ax + 4, 70, ax + 32, 100, Color("2c4a3a") if night else Color("3e6a48"))
	# A band of tiles, then carpets.
	for x in range(0, W, 6):
		_rect(img, x, 100, x + 5, 104, Color("1f7a6e") if (x / 6) % 2 == 1 else Color("d9a944"))
	_rect(img, 0, 104, W, H, Color("7a2a24"))
	for y in range(108, H, 8):
		for x in range(0, W, 8):
			_dot(img, x + 3, y + 3, Color("d9a944"))
			_dot(img, x + 4, y + 3, Color("1f7a6e"))
	_outline(img, 30, 112, 210, 140, Color("d9a944"))
	# Cushions and brass trays.
	for x in range(34, 206, 24):
		_ellipse(img, x, 124, x + 12, 132, Color("1f7a6e"))
		_rect(img, x + 14, 126, x + 20, 128, Color("d9a944"))
	# Lanterns on chains.
	for lx in [30, 90, 150, 210]:
		_rect(img, lx, 0, lx, 24, Color("4a3018"))
		_rect(img, lx - 3, 24, lx + 3, 32, Color("ffcf6a"))
		_rect(img, lx - 3, 24, lx + 3, 25, Color("8a5a2a"))
		_glow(img, lx, 28, 30, Color("ffb347"), 0.5)
	_banner(img, 52, 6, 14, 30, banner[0], banner[1])
	_banner(img, 174, 6, 14, 30, banner[0], banner[1])
	# A brazier in the middle of the court.
	_rect(img, 116, 92, 124, 100, Color("6b4a2a"))
	_glow(img, 120, 90, 24, Color("ff9a40"), 0.4)
	return img


static func _ryumon(rng: RandomNumberGenerator, night: bool, banner: Array) -> Image:
	var img := Image.create(W, H, false, Image.FORMAT_RGB8)
	img.fill(Color("e8dcc0"))
	# Paper screens.
	for sx in range(0, W, 40):
		_rect(img, sx, 8, sx + 39, 98, Color("efe4c8"))
		for gx in range(sx, sx + 40, 10):
			_rect(img, gx, 8, gx, 98, Color("7a5a3a"))
		for gy in range(8, 98, 12):
			_rect(img, sx, gy, sx + 39, gy, Color("7a5a3a"))
	# Beam and pillars.
	_rect(img, 0, 0, W, 8, Color("3a2414"))
	for px in [0, 78, 158, W - 6]:
		_rect(img, px, 0, px + 5, 104, Color("4a2c18"))
	# The alcove with its hanging scroll, and the lord's seal beneath.
	_rect(img, 100, 14, 140, 98, Color("2a2018"))
	_rect(img, 112, 20, 128, 64, Color("e8dcb8"))
	_rect(img, 112, 20, 128, 21, Color("6b4426"))
	for y in range(26, 60, 5):
		_rect(img, 118, y, 121, y + 2, Color("2b2f3a"))
	_ellipse(img, 114, 70, 126, 78, Color("c8443c"))
	_banner(img, 52, 10, 14, 34, banner[0], banner[1])
	_banner(img, 174, 10, 14, 34, banner[0], banner[1])
	# Tatami.
	_rect(img, 0, 100, W, H, Color("b8a86a"))
	for x in range(0, W, 40):
		_rect(img, x, 100, x, H, Color("3a3a2a"))
	_rect(img, 0, 124, W, 124, Color("3a3a2a"))
	for i in 300:
		_dot(img, rng.randi_range(0, W - 1), rng.randi_range(101, H - 1), Color("a89858"))
	# Low lacquer tables with cups.
	for x in [30, 90, 150, 200]:
		_rect(img, x, 116, x + 24, 120, Color("5a1a14"))
		_rect(img, x + 2, 120, x + 4, 126, Color("3a1008"))
		_rect(img, x + 20, 120, x + 22, 126, Color("3a1008"))
		_rect(img, x + 6, 113, x + 9, 116, Color("ece5d3"))
		_rect(img, x + 14, 113, x + 17, 116, Color("ece5d3"))
	# Paper lanterns.
	for lx in [40, 200]:
		_rect(img, lx, 8, lx, 22, Color("2a2018"))
		_ellipse(img, lx - 5, 22, lx + 5, 36, Color("fff0c8"))
		_rect(img, lx - 5, 29, lx + 5, 29, Color("c8443c"))
		_glow(img, lx, 29, 28, Color("ffd27a"), 0.45)
	return img


# ---------------------------------------------------------------- pixel primitives

## A filled rectangle, both corners inclusive, clipped to the image.
static func _rect(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	var a := maxi(0, mini(x0, x1))
	var b := mini(W - 1, maxi(x0, x1))
	var top := maxi(0, mini(y0, y1))
	var bottom := mini(H - 1, maxi(y0, y1))
	if a > b or top > bottom:
		return
	img.fill_rect(Rect2i(a, top, b - a + 1, bottom - top + 1), c)


static func _outline(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	_rect(img, x0, y0, x1, y0, c)
	_rect(img, x0, y1, x1, y1, c)
	_rect(img, x0, y0, x0, y1, c)
	_rect(img, x1, y0, x1, y1, c)


static func _dot(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and x < W and y >= 0 and y < H:
		img.set_pixel(x, y, c)


## The top half of a disc centred on (cx, base), for arch heads.
static func _half_disc(img: Image, cx: float, base: float, r: float, c: Color) -> void:
	for y in range(int(base - r), int(base) + 1):
		for x in range(int(cx - r), int(cx + r) + 1):
			if Vector2(float(x) + 0.5 - cx, float(y) + 0.5 - base).length() <= r:
				_dot(img, x, y, c)


## The upper arc of a circle, one pixel thick.
static func _arc(img: Image, cx: float, base: float, r: float, c: Color) -> void:
	for y in range(int(base - r) - 1, int(base) + 1):
		for x in range(int(cx - r) - 1, int(cx + r) + 2):
			var d := Vector2(float(x) + 0.5 - cx, float(y) + 0.5 - base).length()
			if absf(d - r) <= 0.6:
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


## A soft pool of light around (cx, cy).
static func _glow(img: Image, cx: int, cy: int, r: int, c: Color, strength: float) -> void:
	for y in range(maxi(0, cy - r), mini(H, cy + r)):
		for x in range(maxi(0, cx - r), mini(W, cx + r)):
			var d := Vector2(x - cx, y - cy).length() / float(r)
			if d < 1.0:
				var a := (1.0 - d) * (1.0 - d) * strength
				img.set_pixel(x, y, img.get_pixel(x, y).lerp(c, a))


## A hanging pixel banner: a rod, the cloth with a notched foot, a mark on it.
static func _banner(img: Image, x: int, y: int, w: int, h: int, cloth: Color, mark: Color) -> void:
	_rect(img, x - 2, y - 2, x + w + 1, y - 1, Color("5a3a1e"))
	for row in range(y, y + h + 1):
		var depth := row - (y + h - 6)
		for col in range(x, x + w):
			if depth > 0:
				# The notched foot: cut in from the middle.
				var from_mid := absi(col - (x + w / 2))
				if from_mid < depth * w / 12:
					continue
			_dot(img, col, row, cloth)
	_rect(img, x, y, x, y + h, _shade(cloth, 0.75))
	var cx := x + w / 2
	var cy := y + h / 3
	_rect(img, cx - 3, cy - 3, cx + 2, cy + 2, mark)
	_rect(img, cx - 1, cy + 3, cx, cy + 8, mark)


static func _torch(img: Image, x: int, y: int) -> void:
	_rect(img, x, y, x + 1, y + 6, Color("4a3018"))
	_rect(img, x - 1, y - 3, x + 2, y - 1, Color("ffcf6a"))
	_dot(img, x, y - 4, Color("fff3c0"))
	_glow(img, x, y - 2, 26, Color("ffb347"), 0.45)


static func _shade(c: Color, f: float) -> Color:
	return Color(clampf(c.r * f, 0.0, 1.0), clampf(c.g * f, 0.0, 1.0), clampf(c.b * f, 0.0, 1.0))


static func _blend(img: Image, c: Color, a: float) -> void:
	for y in H:
		for x in W:
			img.set_pixel(x, y, img.get_pixel(x, y).lerp(c, a))
