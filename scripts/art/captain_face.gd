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

## Clothing by culture: [main, trim, accent].
const CLOTH := {
	"vardish": [
		[Color("2c3e66"), Color("d9c9a3"), Color("8c2f2a")], [Color("3a4a5c"), Color("b9a37a"), Color("2e5a3a")],
		[Color("5a3a2a"), Color("d9c9a3"), Color("2c3e66")], [Color("2e4a48"), Color("c7b48a"), Color("7a2a2a")],
		[Color("6a2a2a"), Color("e0d0a8"), Color("2a3a5a")], [Color("4a5a3a"), Color("d0bf94"), Color("5a3a6a")],
	],
	"kharzani": [
		[Color("b0703a"), Color("e8d8b0"), Color("2f5a5a")], [Color("8c2f2a"), Color("e0c28a"), Color("1e3a5a")],
		[Color("d8c49a"), Color("7a3a28"), Color("3a6a5a")], [Color("2f5a5a"), Color("e0c28a"), Color("9a3a2a")],
		[Color("5a3a6a"), Color("e8d0a0"), Color("b0703a")], [Color("e8e0cc"), Color("3a5a8a"), Color("a8322c")],
	],
	"ryumon": [
		[Color("7a1e1e"), Color("1a1418"), Color("d8c8a0")], [Color("1e2430"), Color("b8952f"), Color("8a2a2a")],
		[Color("3b2a3e"), Color("c9b48a"), Color("2a4a6a")], [Color("4a5a3a"), Color("1a1418"), Color("c9b48a")],
		[Color("2a3a5a"), Color("e8e0d0"), Color("8a2a2a")], [Color("5a2a2a"), Color("d8b060"), Color("1a1418")],
	],
}
const MAIL := Color("8a9099")
const MAIL_DARK := Color("565c66")
const LEATHER := Color("6e4629")
const LEATHER_DARK := Color("47301d")
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
		"cloth": rng.randi_range(0, 5),
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
	f["outfit"] = rng.randi_range(0, 3)
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
	var accent: Color = cloth[2]

	# Shoulders and clothes.
	_outfit(img, f, main, trim, accent, String(captain.get("type", "")))
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

## Inside the shoulders' outline (a widening trapezoid below the neck).
static func _body(x: int, y: int) -> bool:
	if y < 46 or y >= H or x < 0 or x >= W:
		return false
	return absf(float(x) + 0.5 - 24.0) <= float(mini(12 + (y - 46), 22))


## Paint a pixel, but only on the clothes.
static func _put(img: Image, x: int, y: int, c: Color) -> void:
	if _body(x, y):
		img.set_pixel(x, y, c)


static func _band(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			_put(img, xx, yy, c)


## The clothes: four garments for each culture, in the captain's colours, then light
## from the upper left and a sign of the troops they lead.
static func _outfit(img: Image, f: Dictionary, main: Color, trim: Color, accent: Color, type: String) -> void:
	for y in range(46, H):
		for x in W:
			_put(img, x, y, main)
	var garment := int(f.get("outfit", 0))
	match String(f["culture"]):
		"kharzani":
			_kharzani(img, garment, main, trim, accent)
		"ryumon":
			_ryumon(img, garment, main, trim, accent)
		_:
			_vardish(img, garment, main, trim, accent)
	# Light from the upper left: the far shoulder in shadow, the near one catching light,
	# and a fold where the arm meets the chest.
	for y in range(46, H):
		for x in W:
			if not _body(x, y):
				continue
			var c := img.get_pixel(x, y)
			if x >= 31:
				c = c.darkened(0.22)
			elif x <= 14 and y <= 50:
				c = c.lightened(0.1)
			if x in [13, 35] and y >= 54:
				c = c.darkened(0.15)
			img.set_pixel(x, y, c)
	_troop_mark(img, type, trim, main)


static func _vardish(img: Image, garment: int, main: Color, trim: Color, accent: Color) -> void:
	match garment:
		0:
			# Quilted gambeson: diamond stitching, a standing collar, toggles down the front.
			for y in range(48, H):
				for x in W:
					if (x + y) % 5 == 0 or (x - y + 100) % 5 == 0:
						_put(img, x, y, main.darkened(0.14))
			_band(img, 17, 45, 14, 3, trim)
			_band(img, 18, 47, 12, 1, trim.darkened(0.25))
			_band(img, 23, 48, 2, 16, main.darkened(0.3))
			for y in [50, 54, 58, 62]:
				_band(img, 22, y, 4, 1, trim)
		1:
			# Mail on the shoulders, a coif round the neck, a tabard of the house colours.
			for y in range(46, H):
				for x in W:
					var ring := MAIL if (x + (y % 2)) % 2 == 0 else MAIL_DARK
					_put(img, x, y, ring)
			_band(img, 16, 44, 16, 4, MAIL)
			for x in range(16, 32, 2):
				_put(img, x, 46, MAIL_DARK)
			_band(img, 15, 50, 18, 14, main)
			_band(img, 15, 50, 1, 14, main.darkened(0.35))
			_band(img, 32, 50, 1, 14, main.darkened(0.35))
			# A charge on the tabard: a pale or a cross, in the accent colour.
			_band(img, 22, 50, 4, 14, accent)
			_band(img, 17, 55, 14, 3, accent)
			_band(img, 15, 50, 18, 1, trim)
		2:
			# A wool cloak over the tunic, gathered in folds, pinned with a round brooch.
			_band(img, 17, 46, 14, 18, accent.darkened(0.1))
			_band(img, 19, 45, 10, 2, trim)
			for y in range(46, H):
				for x in W:
					if absf(float(x) + 0.5 - 24.0) > 7.0:
						var fold := (x % 4 == 0)
						_put(img, x, y, main.darkened(0.25) if fold else main)
			_band(img, 9, 49, 4, 4, Color("c9a243"))
			_put(img, 10, 50, Color("f0d888"))
			_put(img, 11, 51, Color("8a6a22"))
			_band(img, 13, 51, 5, 1, Color("c9a243").darkened(0.2))
		_:
			# A leather jerkin over a coloured shirt: stitched seams, laced front, and
			# a rounded steel plate on each shoulder.
			for y in range(46, H):
				for x in W:
					_put(img, x, y, LEATHER if (y % 6) != 0 else LEATHER_DARK)
			_band(img, 19, 46, 10, 18, main)
			_band(img, 19, 46, 1, 18, LEATHER_DARK)
			_band(img, 28, 46, 1, 18, LEATHER_DARK)
			for y in range(48, H, 3):
				_put(img, 21, y, trim)
				_put(img, 22, y + 1, trim)
				_put(img, 26, y + 1, trim)
				_put(img, 27, y, trim)
			for side in [0, 1]:
				var x0: int = 3 if side == 0 else 35
				for y in range(49, 56):
					for x in range(x0, x0 + 10):
						var dy := float(y - 49) / 7.0
						if float(x - x0) / 10.0 > 0.15 * (1.0 - dy) and _body(x, y):
							_put(img, x, y, MAIL.lightened(0.15) if y < 51 else MAIL)
				_band(img, x0, 55, 10, 1, MAIL_DARK)


static func _kharzani(img: Image, garment: int, main: Color, trim: Color, accent: Color) -> void:
	match garment:
		0:
			# A robe crossing at the chest, its edges embroidered, a striped sash below.
			for i in 16:
				for side in [-1, 1]:
					var x: int = 24 + side * (i - 7)
					_put(img, x, 46 + i, trim)
					_put(img, x + side, 46 + i, Color("c9a243") if i % 2 == 0 else accent)
			_band(img, 4, 59, 40, 4, accent)
			_band(img, 4, 60, 40, 1, trim)
			_band(img, 4, 62, 40, 1, trim.darkened(0.2))
		1:
			# A vest of small brass-edged scales over the robe.
			_band(img, 14, 47, 20, 17, LEATHER_DARK)
			for y in range(48, H, 2):
				for x in range(14, 34):
					var off := 1 if (y / 2) % 2 == 0 else 0
					if (x + off) % 2 == 0:
						_put(img, x, y, Color("b08a3a"))
					else:
						_put(img, x, y, Color("6e5426"))
			_band(img, 14, 47, 20, 1, trim)
			_band(img, 23, 47, 2, 17, trim)
		2:
			# A chequered scarf draped round the neck and over both shoulders.
			for y in range(45, 56):
				for x in W:
					var reach := 10 + (y - 45)
					if absf(float(x) + 0.5 - 24.0) <= float(reach) and y <= 54 - absi(x - 24) / 4:
						var check := ((x / 2) + (y / 2)) % 2 == 0
						if _body(x, y) or y < 48:
							img.set_pixel(x, y, trim if check else accent)
			# The ends hang down the front.
			for y in range(54, H):
				for x in [17, 18, 19, 29, 30, 31]:
					var check2: bool = ((x / 2) + (y / 2)) % 2 == 0
					_put(img, x, y, trim if check2 else accent)
		_:
			# An open kaftan with frogged fastenings over a long inner robe.
			_band(img, 19, 46, 10, 18, accent)
			for y in range(49, H, 3):
				_band(img, 16, y, 4, 1, trim)
				_band(img, 28, y, 4, 1, trim)
				_put(img, 20, y, Color("c9a243"))
				_put(img, 27, y, Color("c9a243"))
			_band(img, 18, 46, 1, 18, trim)
			_band(img, 29, 46, 1, 18, trim)


static func _ryumon(img: Image, garment: int, main: Color, trim: Color, accent: Color) -> void:
	match garment:
		0:
			# A kimono: a pale under-collar crossing left over right, and the house crest.
			# Lapels from each side of the neck to a V at the breastbone, the left over
			# the right, each with its pale under-collar showing.
			for i in 11:
				var lx := 18 + int(i * 0.6)
				var rx := 30 - int(i * 0.6)
				_put(img, rx, 46 + i, Color("eae3d4").darkened(0.1))
				_put(img, rx - 1, 46 + i, accent)
				_put(img, lx, 46 + i, Color("eae3d4"))
				_put(img, lx + 1, 46 + i, accent)
			_band(img, 21, 46, 7, 2, Color("eae3d4"))
			_crest(img, 9, 52, trim if trim.get_luminance() > 0.3 else Color("eae3d4"))
		1:
			# Lacquered do armour: rows of plates laced with coloured cord, shoulder guards.
			_band(img, 14, 47, 20, 17, main.darkened(0.2))
			for y in range(48, H, 3):
				_band(img, 14, y, 20, 1, main.darkened(0.45))
				for x in range(15, 34, 3):
					_put(img, x, y + 1, accent)
			for y in range(49, H, 3):
				for x in range(2, 14):
					_put(img, x, y, trim)
				for x in range(34, 46):
					_put(img, x, y, trim)
				for x in range(3, 14, 3):
					_put(img, x, y + 1, accent)
				for x in range(35, 46, 3):
					_put(img, x, y + 1, accent)
			_band(img, 18, 44, 12, 4, trim)
		2:
			# A haori jacket over the kimono: crests on both breasts, a cord tied at the front.
			_band(img, 20, 46, 8, 18, accent)
			_band(img, 19, 46, 1, 18, trim)
			_band(img, 28, 46, 1, 18, trim)
			_crest(img, 11, 51, Color("eae3d4"))
			_crest(img, 32, 51, Color("eae3d4"))
			_band(img, 21, 54, 6, 1, Color("eae3d4"))
			_band(img, 22, 55, 1, 3, Color("eae3d4"))
			_band(img, 25, 55, 1, 3, Color("eae3d4"))
		_:
			# A footsoldier's plain cuirass with a big painted crest.
			_band(img, 13, 47, 22, 17, main.darkened(0.12))
			_band(img, 13, 47, 22, 1, trim)
			_band(img, 13, 52, 22, 1, main.darkened(0.35))
			_crest(img, 21, 55, Color("eae3d4"))
			_band(img, 18, 44, 12, 4, Color("eae3d4"))


## A round family crest, five pixels across.
static func _crest(img: Image, x: int, y: int, c: Color) -> void:
	for p in [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(0, 1), Vector2i(4, 1), Vector2i(0, 2),
			Vector2i(2, 2), Vector2i(4, 2), Vector2i(0, 3), Vector2i(4, 3), Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4)]:
		_put(img, x + p.x, y + p.y, c)


## A sign of the captain's troops, worn over the clothes.
static func _troop_mark(img: Image, type: String, trim: Color, main: Color) -> void:
	match type:
		"archers":
			# A quiver strap from the near shoulder across the chest, with a buckle.
			for i in 18:
				_put(img, 9 + i, 46 + i, LEATHER)
				_put(img, 10 + i, 46 + i, LEATHER_DARK)
			_band(img, 16, 52, 3, 3, Color("c9a243"))
			# Fletching showing over the far shoulder.
			_band(img, 38, 46, 2, 3, Color("eae3d4"))
			_band(img, 40, 45, 2, 3, Color("a8322c"))
		"cavalry":
			# A riding cloak's clasp and a strap of spurs' leather over the shoulder.
			_band(img, 21, 49, 6, 4, Color("c9a243").darkened(0.15))
			_band(img, 22, 50, 4, 2, Color("f0d888"))
			_put(img, 23, 50, Color("8a6a22"))
		"spearmen":
			# A red tassel from the spear tied at the far shoulder.
			_band(img, 37, 46, 3, 2, Color("6e4629"))
			_band(img, 37, 48, 3, 6, Color("a8322c"))
			_put(img, 38, 54, Color("7a221d"))
		_:
			# A small round shield slung at the near shoulder.
			for y in range(48, 57):
				for x in range(4, 13):
					var dx := float(x) - 8.0
					var dy := float(y) - 52.0
					if dx * dx + dy * dy <= 16.0:
						_put(img, x, y, trim if dx * dx + dy * dy > 9.0 else main.lightened(0.15))
			_put(img, 8, 52, Color("c9a243"))


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
