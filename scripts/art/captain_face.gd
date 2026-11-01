## A captain's face, drawn from parts: the same captain always gets the same face, made
## from their id and culture, and it changes with what happens to them (scars for wounds,
## grey as the years and battles pile up, a brass pin for rank). Pixel art, 48 x 64, lit
## from the upper left, on a transparent background.
extends RefCounted

const W := 48
const H := 64

const OUTLINE := Color("120d14")

## Skin tones, light to dark, each with its shadow and highlight worked out below.
const SKINS := [Color("f1d0b0"), Color("e3b38c"), Color("c98f63"), Color("a86f48"), Color("7f4f32"), Color("5c3725")]
## How likely each skin tone is in each culture's lands (people travel; nobody is barred).
const SKIN_WEIGHTS := {
	"vardish": [3, 4, 2, 1, 1, 1],
	"kharzani": [0, 1, 3, 4, 3, 2],
	"ryumon": [2, 4, 3, 1, 0, 0],
}
const HAIRS := [Color("1b1414"), Color("3a2418"), Color("5d3a22"), Color("8a4b2a"), Color("b07a3a"), Color("d6b46a")]
const HAIR_WEIGHTS := {
	"vardish": [2, 3, 3, 2, 2, 2],
	"kharzani": [5, 4, 2, 0, 0, 0],
	"ryumon": [6, 3, 1, 0, 0, 0],
}
const GREY := Color("a9a6a2")
const EYES := [Color("2b1d14"), Color("3d2a1c"), Color("2e3b4a"), Color("3c4a2e")]

## Clothing by culture: [main, trim, shadow].
const CLOTH := {
	"vardish": [[Color("2c3e66"), Color("d9c9a3")], [Color("3a4a5c"), Color("b9a37a")], [Color("4a3a2e"), Color("d9c9a3")], [Color("2e4a48"), Color("c7b48a")]],
	"kharzani": [[Color("b0703a"), Color("e8d8b0")], [Color("8c2f2a"), Color("e0c28a")], [Color("d8c49a"), Color("7a3a28")], [Color("2f5a5a"), Color("e0c28a")]],
	"ryumon": [[Color("7a1e1e"), Color("1a1418")], [Color("1e2430"), Color("b8952f")], [Color("3b2a3e"), Color("c9b48a")], [Color("4a5a3a"), Color("1a1418")]],
}
const BRASS := Color("c9a243")


## Everything about a captain's face that doesn't change: worked out from id and culture.
static func features(captain: Dictionary) -> Dictionary:
	var culture := String(captain.get("culture", "vardish"))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(captain.get("id", 0)), culture, String(captain.get("first", ""))])
	var f := {
		"culture": culture,
		"skin": _weighted(rng, SKIN_WEIGHTS.get(culture, SKIN_WEIGHTS["vardish"])),
		"hair_color": _weighted(rng, HAIR_WEIGHTS.get(culture, HAIR_WEIGHTS["vardish"])),
		"head": rng.randi_range(0, 3),
		"eyes": rng.randi_range(0, EYES.size() - 1),
		"brow": rng.randi_range(0, 2),
		"nose": rng.randi_range(0, 2),
		"mouth": rng.randi_range(0, 2),
		"cloth": rng.randi_range(0, 3),
		"soft": rng.randf() < 0.45,
		"age": rng.randi_range(0, 2),
	}
	# Hair styles by culture; some cover the head with a turban or a helmet-cap instead.
	match culture:
		"kharzani":
			f["hair"] = ["short", "curls", "long", "turban", "turban", "wrap"][rng.randi_range(0, 5)]
		"ryumon":
			f["hair"] = ["topknot", "topknot", "tied", "short", "long", "shaved"][rng.randi_range(0, 5)]
		_:
			f["hair"] = ["short", "side", "long", "braid", "crop", "receding"][rng.randi_range(0, 5)]
	# Beards are less common on the soft-featured, and the Ryumon go clean-shaven more.
	var beard_chance := 0.12 if f["soft"] else (0.4 if culture == "ryumon" else 0.65)
	f["beard"] = "none"
	if rng.randf() < beard_chance:
		f["beard"] = ["stubble", "short", "full", "moustache", "goatee"][rng.randi_range(0, 4)]
	f["scar_seed"] = rng.randi()
	return f


static func _weighted(rng: RandomNumberGenerator, weights: Array) -> int:
	var total := 0
	for w in weights:
		total += int(w)
	var roll := rng.randi_range(1, maxi(1, total))
	for i in weights.size():
		roll -= int(weights[i])
		if roll <= 0:
			return i
	return 0


## The face as it is now. `captain` may carry history.wounds (scars), battles and level
## (grey hair, rank pin).
static func image(captain: Dictionary) -> Image:
	var f := features(captain)
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var skin: Color = SKINS[int(f["skin"])]
	var skin_dark := skin.darkened(0.22)
	var skin_light := skin.lightened(0.06)
	var battles := int(captain.get("battles", 0))
	var greying := int(f["age"]) >= 2 or battles >= 20
	var hair: Color = HAIRS[int(f["hair_color"])]
	if greying:
		hair = hair.lerp(GREY, 0.55 if int(f["age"]) >= 2 else 0.35)
	var hair_dark := hair.darkened(0.35)
	var cloth: Array = CLOTH.get(String(f["culture"]), CLOTH["vardish"])[int(f["cloth"])]
	var main: Color = cloth[0]
	var trim: Color = cloth[1]

	# Shoulders and clothes.
	_shoulders(img, f, main, trim, String(captain.get("type", "")))
	# Neck.
	_rect(img, 20, 44, 8, 6, skin_dark)
	_rect(img, 20, 44, 3, 6, skin)

	# Head: four shapes, all about 20 wide and 24 tall, centred at x 24.
	var cx := 24.0
	var cy := 30.0
	var rx: float = [10.0, 10.5, 9.5, 10.0][int(f["head"])]
	var ry: float = [12.0, 11.5, 13.0, 12.0][int(f["head"])]
	var jaw: float = [0.0, 1.5, 0.0, 0.8][int(f["head"])]
	for y in H:
		for x in W:
			var dx := (float(x) + 0.5 - cx) / rx
			var dy := (float(y) + 0.5 - cy) / ry
			var r := dx * dx + dy * dy
			# A squarer jaw: widen the lower half.
			if dy > 0.2 and jaw > 0.0:
				r = pow(absf(dx) * (1.0 - 0.06 * jaw), 2.0) + dy * dy
			if r <= 1.0:
				var c := skin
				if dx > 0.45:
					c = skin_dark
				elif dx < -0.5 and dx > -0.8 and dy > -0.35 and dy < 0.15:
					c = skin_light
				img.set_pixel(x, y, c)
	# Ears.
	for side in [-1, 1]:
		var ex := int(cx + side * (rx + 0.5)) - (1 if side < 0 else 0)
		_rect(img, ex, 28, 1, 4, skin_dark if side > 0 else skin)

	# Eyes, brows, nose and mouth.
	var eye: Color = EYES[int(f["eyes"])]
	var ey := 29
	for ex in [19, 27]:
		img.set_pixel(ex, ey, Color("efe6d8"))
		img.set_pixel(ex + 1, ey, eye)
		img.set_pixel(ex + 1, ey - 1, skin_dark)
		img.set_pixel(ex, ey - 1, skin_dark)
	var brow_col := hair_dark if String(f["hair"]) not in ["turban", "wrap", "shaved"] else Color("2a1c16")
	if greying:
		brow_col = brow_col.lerp(GREY, 0.4)
	match int(f["brow"]):
		0:
			_rect(img, 18, 26, 4, 1, brow_col)
			_rect(img, 26, 26, 4, 1, brow_col)
		1:
			_rect(img, 18, 27, 2, 1, brow_col)
			_rect(img, 20, 26, 2, 1, brow_col)
			_rect(img, 26, 26, 2, 1, brow_col)
			_rect(img, 28, 27, 2, 1, brow_col)
		_:
			_rect(img, 18, 26, 4, 2, brow_col)
			_rect(img, 26, 26, 4, 2, brow_col)
	match int(f["nose"]):
		0:
			_rect(img, 24, 30, 1, 3, skin_dark)
			img.set_pixel(23, 33, skin_dark)
		1:
			_rect(img, 24, 29, 1, 4, skin_dark)
			_rect(img, 23, 33, 3, 1, skin_dark)
		_:
			_rect(img, 25, 31, 1, 2, skin_dark)
	var lip := skin.darkened(0.38).lerp(Color("8a3b36"), 0.25)
	match int(f["mouth"]):
		0:
			_rect(img, 22, 36, 5, 1, lip)
		1:
			_rect(img, 22, 36, 4, 1, lip)
			img.set_pixel(26, 35, lip)
		_:
			_rect(img, 22, 36, 5, 1, lip)
			img.set_pixel(21, 37, lip)
	if int(f["age"]) >= 1:
		# Lines from nose to mouth.
		img.set_pixel(20, 34, skin_dark)
		img.set_pixel(28, 34, skin_dark)
	if int(f["age"]) >= 2:
		_rect(img, 17, 31, 2, 1, skin_dark)
		_rect(img, 30, 31, 2, 1, skin_dark)

	# Beard.
	_beard(img, f, hair, hair_dark, skin)
	# Hair or headwear on top.
	_hair(img, f, hair, hair_dark, main, trim, cx, rx)

	# Scars: one for each time wounded, up to three, in places worked out once.
	var scars := mini(3, int(captain.get("history", {}).get("wounds", 0)))
	var srng := RandomNumberGenerator.new()
	srng.seed = int(f["scar_seed"])
	var scar_col := skin.lerp(Color("d8a39a"), 0.55)
	for i in scars:
		var sx := srng.randi_range(17, 29)
		var sy := srng.randi_range(25, 36)
		var dirx := 1 if srng.randf() < 0.5 else -1
		for k in 4:
			var px := sx + k * dirx
			var py := sy + k
			if img.get_pixel(px, py) in [skin, skin_dark, skin_light]:
				img.set_pixel(px, py, scar_col)

	# Rank: a brass pin on the collar from level 2, and a second at level 3.
	var level := int(captain.get("level", 1))
	if level >= 2:
		_rect(img, 14, 52, 2, 2, BRASS)
	if level >= 3:
		_rect(img, 32, 52, 2, 2, BRASS)

	_outline(img)
	return img


static func texture(captain: Dictionary) -> ImageTexture:
	return ImageTexture.create_from_image(image(captain))


# ---------------------------------------------------------------- parts

static func _shoulders(img: Image, f: Dictionary, main: Color, trim: Color, type: String) -> void:
	var shade := main.darkened(0.3)
	for y in range(46, H):
		var half := 12 + (y - 46)
		half = mini(half, 22)
		for x in range(24 - half, 24 + half):
			if x < 0 or x >= W:
				continue
			img.set_pixel(x, y, shade if x >= 30 else main)
	match String(f["culture"]):
		"vardish":
			# A quilted gambeson: stitched lines, and a cream collar.
			for y in range(50, H, 4):
				for x in range(6, 42):
					if img.get_pixel(x, y).a > 0.0:
						img.set_pixel(x, y, main.darkened(0.15))
			_rect(img, 17, 45, 14, 3, trim)
			_rect(img, 18, 48, 12, 1, trim.darkened(0.2))
		"kharzani":
			# Robes crossing at the chest, and a sash.
			for i in 14:
				if 24 - i >= 0:
					img.set_pixel(24 - i + 7, 46 + i, trim)
					img.set_pixel(24 + i - 7, 46 + i, trim)
			_rect(img, 4, 60, 40, 3, trim.darkened(0.1))
		"ryumon":
			# Lacquered shoulder plates in laced rows, and a dark high collar.
			for y in range(50, H, 3):
				for x in range(2, 15):
					if img.get_pixel(x, y).a > 0.0:
						img.set_pixel(x, y, trim)
				for x in range(33, 46):
					if img.get_pixel(x, y).a > 0.0:
						img.set_pixel(x, y, trim)
			_rect(img, 18, 44, 12, 4, trim.lightened(0.05))
	# A sign of the captain's troops.
	match type:
		"archers":
			for i in 18:
				var x := 10 + i
				var y := 46 + i
				if y < H:
					img.set_pixel(x, y, Color("5a3a22"))
					img.set_pixel(x + 1, y, Color("5a3a22"))
		"cavalry":
			_rect(img, 22, 50, 4, 3, BRASS.darkened(0.15))
			img.set_pixel(23, 51, BRASS.lightened(0.3))
		"spearmen":
			_rect(img, 36, 47, 3, 6, Color("a8322c"))
		_:
			_rect(img, 9, 50, 5, 6, trim)
			_rect(img, 10, 51, 3, 4, main.darkened(0.2))


static func _beard(img: Image, f: Dictionary, hair: Color, hair_dark: Color, skin: Color) -> void:
	match String(f["beard"]):
		"stubble":
			for y in range(33, 41):
				for x in range(16, 33):
					if (x + y) % 2 == 0 and img.get_pixel(x, y).a > 0.0 and y >= 34 and not (y == 36 and x in range(22, 27)):
						img.set_pixel(x, y, img.get_pixel(x, y).lerp(hair_dark, 0.45))
		"short":
			_fill_face(img, 34, 41, 15, 33, hair, hair_dark, [36])
		"full":
			_fill_face(img, 32, 44, 14, 34, hair, hair_dark, [36])
			_rect(img, 20, 42, 9, 2, hair)
		"moustache":
			_rect(img, 21, 35, 7, 1, hair)
			img.set_pixel(20, 36, hair)
			img.set_pixel(28, 36, hair_dark)
		"goatee":
			_rect(img, 21, 35, 7, 1, hair)
			_rect(img, 22, 37, 5, 4, hair)
			_rect(img, 26, 37, 1, 4, hair_dark)


## Beard over the lower face: every face pixel in the band, except the mouth line.
static func _fill_face(img: Image, y0: int, y1: int, x0: int, x1: int, hair: Color, hair_dark: Color, keep_rows: Array) -> void:
	for y in range(y0, y1):
		for x in range(x0, x1):
			if img.get_pixel(x, y).a <= 0.0 and y < 42:
				continue
			if keep_rows.has(y) and x in range(22, 27):
				continue
			img.set_pixel(x, y, hair_dark if x >= 28 else hair)


static func _hair(img: Image, f: Dictionary, hair: Color, hair_dark: Color, main: Color, trim: Color, cx: float, rx: float) -> void:
	var style := String(f["hair"])
	# The cap of hair over the crown, shared by most styles.
	var cap := func(top: int, low: int):
		for y in range(top, low):
			for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
				var dx := (float(x) + 0.5 - cx) / (rx + 1.0)
				var dy := (float(y) + 0.5 - 30.0) / 13.0
				if dx * dx + dy * dy <= 1.0:
					img.set_pixel(x, y, hair_dark if dx > 0.4 else hair)
	match style:
		"short", "crop", "side", "curls":
			cap.call(16, 25 if style != "crop" else 23)
			if style == "side":
				_rect(img, 15, 22, 7, 3, hair)
				img.set_pixel(22, 24, hair)
			if style == "curls":
				for x in range(14, 35, 3):
					img.set_pixel(x, 16 + (x % 2), hair_dark)
					img.set_pixel(x + 1, 18, hair.lightened(0.1))
			# Sideburns.
			_rect(img, 14, 24, 2, 5, hair)
			_rect(img, 33, 24, 2, 5, hair_dark)
		"receding":
			cap.call(16, 21)
			_rect(img, 14, 21, 2, 8, hair)
			_rect(img, 33, 21, 2, 8, hair_dark)
		"long", "braid":
			cap.call(16, 25)
			_rect(img, 12, 22, 4, 20, hair)
			_rect(img, 33, 22, 4, 20, hair_dark)
			if style == "braid":
				for y in range(40, 52, 2):
					_rect(img, 12, y, 3, 1, hair_dark)
		"tied":
			cap.call(16, 24)
			_rect(img, 33, 26, 3, 10, hair_dark)
			_rect(img, 34, 24, 2, 2, trim)
		"topknot":
			cap.call(17, 23)
			_rect(img, 21, 12, 6, 5, hair)
			_rect(img, 25, 12, 2, 5, hair_dark)
			_rect(img, 22, 16, 4, 1, Color("efe6d8"))
		"shaved":
			cap.call(17, 21)
			for y in range(17, 21):
				for x in range(13, 36):
					var c := img.get_pixel(x, y)
					if c.a > 0.0 and (x + y) % 2 == 0:
						img.set_pixel(x, y, c.lightened(0.15))
		"turban", "wrap":
			var cloth := trim if style == "turban" else main.lightened(0.15)
			for y in range(11, 25):
				for x in range(int(cx - rx) - 2, int(cx + rx) + 3):
					var dx := (float(x) + 0.5 - cx) / (rx + 2.0)
					var dy := (float(y) + 0.5 - 24.0) / 12.5
					if dx * dx + dy * dy <= 1.0 and y <= 24:
						var band := (y - 11) % 4 == 0
						img.set_pixel(x, y, cloth.darkened(0.25 if dx > 0.4 else (0.12 if band else 0.0)))
			if style == "wrap":
				# The tail of the wrap falls by the cheek.
				_rect(img, 33, 24, 4, 14, main.lightened(0.15).darkened(0.25))
			else:
				_rect(img, 22, 14, 3, 3, BRASS)


static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(maxi(0, y), mini(H, y + h)):
		for xx in range(maxi(0, x), mini(W, x + w)):
			img.set_pixel(xx, yy, c)


## A dark line round the figure, so it reads on any background.
static func _outline(img: Image) -> void:
	var edge: Array = []
	for y in H:
		for x in W:
			if img.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = Vector2i(x, y) + d
				if n.x >= 0 and n.y >= 0 and n.x < W and n.y < H and img.get_pixel(n.x, n.y).a > 0.0:
					edge.append(Vector2i(x, y))
					break
	for p in edge:
		img.set_pixel(p.x, p.y, OUTLINE)
