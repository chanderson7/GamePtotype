## PROTOTYPE. A captain's face drawn with more in it than captain_face.gd: a jaw and
## cheekbones under the skin tones, eyes with an iris and a lid, two-tone lips, hair with
## strands, clothes that meet the neck and carry the captain's rank, troops and veteran
## role, and an `expression` for the moment (the death roll, a friend fallen, a promotion).
## Same inputs as the original, same seeded identity, 60 x 80 at the same 3:4 as before,
## so every portrait on every screen takes it unchanged. Lit from the upper left.
extends RefCounted

const W := 60
const H := 80

const OUTLINE := Color("120d14")

const SKINS := [Color("f1d0b0"), Color("e3b38c"), Color("c98f63"), Color("a86f48"), Color("7f4f32"), Color("5c3725")]
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
const EYES := [Color("2b1d14"), Color("3d2a1c"), Color("2e3b4a"), Color("3c4a2e"), Color("5a4a2a")]
const EYE_WHITE := Color("efe6d8")

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
const MAIL_LIGHT := Color("b4b9c2")
const LEATHER := Color("6e4629")
const LEATHER_DARK := Color("47301d")
const LEATHER_LIGHT := Color("8a5c38")
const BRASS := Color("c9a243")
const BRASS_LIGHT := Color("f0d888")
const BRASS_DARK := Color("8a6a22")
const PALE := Color("eae3d4")
const RED := Color("a8322c")

## The moments a face can be drawn for. "" is the captain's resting face.
const EXPRESSIONS := ["", "grim", "pain", "grief", "proud", "fear", "warm"]

const SEASONED := 8
const VETERAN := 20

## Head geometry: the face is an oval centred here, narrowing to the chin.
const CX := 30.0
const CY := 36.0


## Everything about a captain's face that doesn't change: the same draws as the original
## generator, in the same order, so a captain keeps their identity across the two.
static func features(captain: Dictionary) -> Dictionary:
	var culture := String(captain.get("culture", "vardish"))
	var rng := RandomNumberGenerator.new()
	var who := String(captain.get("first", ""))
	if who == "":
		who = String(captain.get("name", ""))
	rng.seed = hash([int(captain.get("id", 0)), culture, who])
	var f := {
		"culture": culture,
		"skin": _weighted(rng, SKIN_WEIGHTS.get(culture, SKIN_WEIGHTS["vardish"])),
		"hair_color": _weighted(rng, HAIR_WEIGHTS.get(culture, HAIR_WEIGHTS["vardish"])),
		"head": rng.randi_range(0, 3),
		"eyes": rng.randi_range(0, 3),
		"brow": rng.randi_range(0, 2),
		"nose": rng.randi_range(0, 2),
		"mouth": rng.randi_range(0, 2),
		"cloth": rng.randi_range(0, 5),
		"soft": rng.randf() < 0.45,
		"age": rng.randi_range(0, 2),
	}
	match culture:
		"kharzani":
			f["hair"] = ["short", "curls", "long", "turban", "turban", "wrap"][rng.randi_range(0, 5)]
		"ryumon":
			f["hair"] = ["topknot", "topknot", "tied", "short", "long", "shaved"][rng.randi_range(0, 5)]
		_:
			f["hair"] = ["short", "side", "long", "braid", "crop", "receding"][rng.randi_range(0, 5)]
	var beard_chance := 0.12 if f["soft"] else (0.4 if culture == "ryumon" else 0.65)
	f["beard"] = "none"
	if rng.randf() < beard_chance:
		f["beard"] = ["stubble", "short", "full", "moustache", "goatee"][rng.randi_range(0, 4)]
	f["scar_seed"] = rng.randi()
	f["outfit"] = rng.randi_range(0, 3)
	# New draws come after the old ones, so nothing above changes.
	f["eye_set"] = rng.randi_range(0, 1)   # wide-set or close-set eyes
	f["lip"] = rng.randi_range(0, 1)       # full or thin lips
	f["freckles"] = rng.randf() < 0.18
	f["mole"] = rng.randf() < 0.15
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


static func rank(captain: Dictionary) -> int:
	if captain.has("level"):
		return int(captain["level"])
	var battles := int(captain.get("battles", 0))
	return 1 + (1 if battles >= SEASONED else 0) + (1 if battles >= VETERAN else 0)


static func texture(captain: Dictionary, backdrop: bool = true, expression: String = "") -> ImageTexture:
	return ImageTexture.create_from_image(image(captain, backdrop, expression))


## The face as it is now, wearing `expression` if one is given.
static func image(captain: Dictionary, backdrop: bool = false, expression: String = "") -> Image:
	var f := features(captain)
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var skin: Color = SKINS[int(f["skin"])]
	if expression == "fear":
		skin = skin.lerp(Color("e8e4e0"), 0.18)
	var tones := {
		"base": skin, "light": skin.lightened(0.09), "dark": skin.darkened(0.16),
		"deep": skin.darkened(0.3), "line": skin.darkened(0.42),
		"flush": skin.lerp(Color("c86a5a"), 0.3),
	}
	var battles := int(captain.get("battles", 0))
	var greying := int(f["age"]) >= 2 or battles >= 20
	var hair: Color = HAIRS[int(f["hair_color"])]
	if greying:
		hair = hair.lerp(GREY, 0.55 if int(f["age"]) >= 2 else 0.35)
	var hair_tones := {"base": hair, "dark": hair.darkened(0.35), "light": hair.lightened(0.14)}
	var cloth: Array = CLOTH.get(String(f["culture"]), CLOTH["vardish"])[int(f["cloth"])]
	var main: Color = cloth[0]
	var trim: Color = cloth[1]
	var accent: Color = cloth[2]
	var noble := String(captain.get("noble", ""))
	if noble != "":
		var house := Color(String(captain.get("house", main.to_html(false))))
		main = house.lerp(Color(house.get_luminance(), house.get_luminance(), house.get_luminance()), 0.3).darkened(0.18)
		accent = Color(String(captain.get("house_dark", accent.to_html(false))))
	var level := rank(captain)
	var spec := String(captain.get("specialization", ""))

	# Body first, so the head and hair sit over the collar.
	_outfit(img, f, main, trim, accent, "" if noble != "" else String(captain.get("type", "")), level, spec)
	if noble != "":
		_regalia_body(img, f, main)
	_neck(img, tones)
	_head(img, f, tones)
	_face(img, f, tones, hair_tones, String(captain.get("temperament", "")), String(captain.get("quirk", "")),
		expression, greying)
	_beard(img, f, hair_tones)
	_hair(img, f, hair_tones, main, trim, tones)
	if noble == "ruler":
		_circlet(img, f)
	_scars(img, f, captain, tones)
	if int(captain.get("wounded", 0)) > 0:
		_bandage(img, f)
	_outline(img)
	if not backdrop:
		return img
	var back := _backdrop(String(f["culture"]), String(captain.get("house", "")))
	back.blend_rect(img, Rect2i(0, 0, W, H), Vector2i.ZERO)
	return back


# ---------------------------------------------------------------- head and skin

## The oval of the face: four head shapes, narrowing to a chin, with a lit left side,
## a shadowed right, a cheekbone and the hollow under it.
static func _head(img: Image, f: Dictionary, t: Dictionary) -> void:
	var head := int(f["head"])
	var rx: float = [12.5, 13.0, 11.5, 12.5][head]
	var ry: float = [15.0, 14.5, 16.0, 15.0][head]
	var chin: float = [0.28, 0.14, 0.32, 0.2][head]   # how much the jaw narrows
	var flat: float = [0.0, 0.08, 0.0, 0.05][head]    # a squarer chin
	for y in H:
		for x in W:
			var dx := (float(x) + 0.5 - CX) / rx
			var dy := (float(y) + 0.5 - CY) / ry
			var width := 1.0
			if dy > 0.0:
				width = 1.0 - chin * pow(dy, 1.6)
			var r := pow(dx / width, 2.0) + dy * dy
			if dy > 1.0 - flat:
				r = 2.0
			if r > 1.0:
				continue
			var c: Color = t["base"]
			# Shadow down the right, deepening at the edge; light on the upper left.
			if dx > 0.55 or (dx > 0.3 and dy > 0.5):
				c = t["dark"]
			if dx > 0.86:
				c = t["deep"]
			if dx < -0.2 and dx > -0.75 and dy > -0.55 and dy < 0.05:
				c = t["light"]
			# The hollow under the right cheekbone, and the jaw's turn.
			if dx > 0.35 and dx < 0.8 and dy > 0.15 and dy < 0.45:
				c = t["deep"]
			if dy > 0.78 and absf(dx) < 0.5:
				c = t["dark"]
			_px(img, x, y, c)
	# Cheekbone catching light, left.
	_rect(img, 20, 38, 3, 1, t["light"])
	# Ears, with a fold.
	var ex_l := int(CX - rx) - 1
	var ex_r := int(CX + rx)
	_rect(img, ex_l - 1, 34, 2, 6, t["base"])
	_px(img, ex_l - 1, 36, t["dark"])
	_rect(img, ex_r, 34, 2, 6, t["dark"])
	_px(img, ex_r + 1, 36, t["deep"])
	if bool(f["freckles"]):
		for p in [Vector2i(22, 41), Vector2i(25, 42), Vector2i(23, 43), Vector2i(36, 41), Vector2i(38, 43)]:
			if img.get_pixel(p.x, p.y).a > 0.0:
				_px(img, p.x, p.y, img.get_pixel(p.x, p.y).darkened(0.12))
	if bool(f["mole"]):
		_px(img, 37, 46, t["line"])


## The neck under the chin, in shadow, with the throat catching a little light.
static func _neck(img: Image, t: Dictionary) -> void:
	_rect(img, 24, 48, 12, 11, t["dark"])
	_rect(img, 24, 48, 4, 11, t["base"])
	_rect(img, 24, 48, 12, 3, t["deep"])
	_rect(img, 33, 48, 3, 11, t["deep"])


## Eyes, brows, nose and mouth, set by the captain's temper and the moment.
static func _face(img: Image, f: Dictionary, t: Dictionary, ht: Dictionary, temperament: String, quirk: String,
		expression: String, greying: bool) -> void:
	var eye: Color = EYES[int(f["eyes"])]
	var ey := 36
	var gap := 1 if int(f["eye_set"]) == 1 else 2
	var lx := 22 - gap + 1   # left eye's first column
	var rx := 32 + gap - 1   # right eye's first column
	var look := 0
	match expression:
		"grief":
			look = 1
	var lids := _lids(temperament, expression)
	for ex: int in [lx, rx]:
		var shadow_side := ex > 30
		match lids:
			"shut":
				_rect(img, ex, ey + 1, 4, 1, t["line"])
				_px(img, ex, ey, t["dark"])
				_px(img, ex + 3, ey, t["dark"])
			"squeezed":
				_rect(img, ex, ey + 1, 4, 1, t["line"])
				_px(img, ex - 1, ey, t["line"])
				_px(img, ex + 4, ey, t["line"])
			"narrow":
				_rect(img, ex, ey, 4, 1, t["line"])
				_px(img, ex, ey + 1, EYE_WHITE.darkened(0.2 if shadow_side else 0.0))
				_px(img, ex + 1, ey + 1, eye)
				_px(img, ex + 2, ey + 1, eye)
				_px(img, ex + 3, ey + 1, EYE_WHITE.darkened(0.2 if shadow_side else 0.0))
			"smiling":
				_rect(img, ex, ey + 1, 4, 1, t["line"])
				_px(img, ex, ey, t["line"])
				_px(img, ex + 3, ey, t["line"])
				_px(img, ex + 1, ey, eye)
				_px(img, ex + 2, ey, eye)
			"wide":
				var white := EYE_WHITE.darkened(0.15 if shadow_side else 0.0)
				_rect(img, ex, ey - 1, 4, 3, white)
				_px(img, ex + 1, ey, eye)
				_px(img, ex + 2, ey, eye)
				_px(img, ex + 1, ey - 1, eye.lightened(0.25))
				_rect(img, ex, ey - 2, 4, 1, t["line"])
			_:
				var white := EYE_WHITE.darkened(0.15 if shadow_side else 0.0)
				_rect(img, ex, ey, 4, 2, white)
				_px(img, ex + 1, ey + look, eye)
				_px(img, ex + 2, ey + look, eye)
				_px(img, ex + 1, ey + 1 - look, eye.darkened(0.2) if look == 0 else white)
				_px(img, ex + 2, ey + 1, eye.darkened(0.2))
				_px(img, ex + 1, ey, eye.lightened(0.3) if look == 0 else eye)
				# The upper lid: a dark line with a crease above it.
				_rect(img, ex, ey - 1, 4, 1, t["line"])
				_rect(img, ex, ey - 2, 4, 1, t["dark"])
	# A tear, sweat, or a flush, by the moment.
	match expression:
		"grief":
			_px(img, lx + 3, ey + 3, Color("bcd4e8"))
			_px(img, lx + 3, ey + 4, Color("d8e8f4"))
		"pain", "fear":
			_px(img, 17, 30, Color("d8e8f4"))
			_px(img, 17, 31, Color("bcd4e8"))
			if expression == "pain":
				_rect(img, 21, 41, 3, 1, t["flush"])
				_rect(img, 36, 41, 3, 1, t["flush"])
		"warm":
			_rect(img, 20, 41, 3, 1, t["flush"])
			_rect(img, 37, 41, 3, 1, t["flush"])
	var brow_col: Color = ht["dark"] if String(f["hair"]) not in ["turban", "wrap", "shaved"] else Color("2a1c16")
	if greying:
		brow_col = brow_col.lerp(GREY, 0.4)
	_brows(img, f, temperament, expression, brow_col, t["deep"], lx, rx)
	_nose(img, f, t)
	_mouth(img, f, temperament, quirk, expression, t)
	if int(f["age"]) >= 1:
		# Lines from nose to mouth, and under the eyes with age.
		_px(img, 25, 44, t["dark"])
		_px(img, 24, 45, t["dark"])
		_px(img, 35, 44, t["deep"])
		_px(img, 36, 45, t["deep"])
	if int(f["age"]) >= 2:
		_rect(img, 20, 39, 2, 1, t["dark"])
		_rect(img, 38, 39, 2, 1, t["deep"])
		_rect(img, 26, 31, 8, 1, t["dark"])


## How the eyes sit for an expression, over the captain's resting look.
static func _lids(temperament: String, expression: String) -> String:
	match expression:
		"grim":
			return "narrow"
		"pain":
			return "squeezed"
		"fear":
			return "wide"
		"warm":
			return "smiling"
		"grief":
			return "open"
		"proud":
			return "open"
	return "narrow" if temperament == "Vengeful" else "open"


## The brows carry most of a face's feeling: knitted, level, lifted, or worried.
static func _brows(img: Image, f: Dictionary, temperament: String, expression: String, c: Color, crease: Color,
		lx: int, rx: int) -> void:
	var thick := int(f["brow"]) == 2
	var by := 33
	var shape := ""
	match expression:
		"grim":
			shape = "knit"
		"pain", "grief":
			shape = "worried"
		"fear":
			shape = "high"
		"proud":
			shape = "lifted"
		"warm":
			shape = "soft"
		_:
			match temperament:
				"Vengeful":
					shape = "knit"
				"Fragile":
					shape = "worried"
				"Steadfast":
					shape = "level"
				_:
					shape = ["level", "arched", "level"][int(f["brow"])]
	# Each brow is five pixels; the inner end is toward the nose.
	var rows := {
		"knit": [1, 1, 0, 0, -1],     # inner end down
		"worried": [-2, -1, 0, 0, 0], # inner end up
		"high": [-2, -2, -2, -2, -1],
		"lifted": [0, 0, -1, -1, -2],   # outer end up: assured
		"soft": [0, -1, -1, -1, 0],
		"level": [0, 0, 0, 0, 0],
		"arched": [1, 0, -1, 0, 1],
	}
	var off: Array = rows[shape]
	for i in 5:
		# Left brow: inner end at the right. Right brow: inner end at the left.
		var lxp := lx + 3 - i
		var rxp := rx + i
		var y: int = by + int(off[i])
		_px(img, lxp, y, c)
		_px(img, rxp, y, c)
		if thick:
			_px(img, lxp, y - 1, c)
			_px(img, rxp, y - 1, c)
	if shape == "knit":
		_px(img, 30, 33, crease)
		_px(img, 30, 34, crease)
	if shape == "worried" and expression == "pain":
		_px(img, 29, 32, crease)
		_px(img, 31, 32, crease)


static func _nose(img: Image, f: Dictionary, t: Dictionary) -> void:
	match int(f["nose"]):
		0:
			# Straight: a bridge line down the shadow side, a small tip.
			_rect(img, 31, 37, 1, 5, t["dark"])
			_rect(img, 29, 42, 3, 1, t["dark"])
			_px(img, 32, 42, t["deep"])
			_px(img, 30, 41, t["light"])
		1:
			# Broad: wider wings, a flatter tip.
			_rect(img, 31, 38, 1, 4, t["dark"])
			_rect(img, 28, 42, 5, 1, t["dark"])
			_px(img, 28, 43, t["deep"])
			_px(img, 32, 43, t["deep"])
			_px(img, 30, 41, t["light"])
		_:
			# Short, turned up: a dot of shadow and a lit tip.
			_rect(img, 31, 39, 1, 3, t["dark"])
			_px(img, 30, 42, t["deep"])
			_px(img, 29, 41, t["light"])


## Two-tone lips: an upper line and a lower that catches light, shaped by the moment.
static func _mouth(img: Image, f: Dictionary, temperament: String, quirk: String, expression: String, t: Dictionary) -> void:
	var lip: Color = t["base"].darkened(0.38).lerp(Color("8a3b36"), 0.3)
	var lip_light := lip.lightened(0.18)
	var full := int(f["lip"]) == 0
	var my := 45
	var shape := ""
	match expression:
		"grim":
			shape = "tight"
		"pain":
			shape = "grimace"
		"grief":
			shape = "down"
		"proud":
			shape = "sure"
		"fear":
			shape = "open"
		"warm":
			shape = "smile"
		_:
			if quirk == "Lucky" and temperament != "Vengeful":
				shape = "smile"
			elif quirk == "Bold" and temperament != "Fragile":
				shape = "half"
			else:
				match temperament:
					"Vengeful":
						shape = "down"
					"Steadfast":
						shape = "level"
					"Fragile":
						shape = "small"
					_:
						shape = ["level", "half", "down"][int(f["mouth"])]
	match shape:
		"level":
			_rect(img, 26, my, 8, 1, lip)
			if full:
				_rect(img, 27, my + 1, 6, 1, lip_light)
		"tight":
			_rect(img, 25, my, 10, 1, lip.darkened(0.2))
			_px(img, 25, my + 1, t["deep"])
			_px(img, 34, my + 1, t["deep"])
		"down":
			_rect(img, 26, my, 8, 1, lip)
			_px(img, 25, my + 1, lip)
			_px(img, 34, my + 1, lip)
			if full:
				_rect(img, 27, my + 1, 6, 1, lip_light)
		"small":
			_rect(img, 27, my, 5, 1, lip)
			_px(img, 26, my + 1, lip)
			if full:
				_rect(img, 28, my + 1, 3, 1, lip_light)
		"half":
			_rect(img, 26, my, 8, 1, lip)
			_px(img, 34, my - 1, lip)
			_px(img, 35, my - 1, t["deep"])
			if full:
				_rect(img, 27, my + 1, 6, 1, lip_light)
		"sure":
			# A wide, closed half-smile, the lit corner drawn up: a captain who knows.
			_rect(img, 26, my, 9, 1, lip)
			_px(img, 35, my - 1, lip)
			_px(img, 36, my - 2, t["deep"])
			_px(img, 25, my, lip.darkened(0.15))
			_rect(img, 27, my + 1, 7, 1, lip_light)
		"smile":
			_rect(img, 26, my, 8, 1, lip)
			_px(img, 25, my - 1, lip)
			_px(img, 34, my - 1, lip)
			_px(img, 24, my - 1, t["deep"])
			_px(img, 35, my - 1, t["deep"])
			_rect(img, 27, my + 1, 6, 1, lip_light)
			# Teeth showing in a broad smile.
			_rect(img, 27, my, 6, 1, PALE.darkened(0.08))
		"grimace":
			# Teeth clenched: a pale row with dark gaps, lips drawn back.
			_rect(img, 25, my - 1, 10, 1, lip.darkened(0.2))
			_rect(img, 25, my, 10, 1, PALE.darkened(0.1))
			for x in range(26, 35, 2):
				_px(img, x, my, PALE.darkened(0.35))
			_rect(img, 25, my + 1, 10, 1, lip)
			_px(img, 24, my, t["deep"])
			_px(img, 35, my, t["deep"])
		"open":
			_rect(img, 27, my - 1, 5, 1, lip)
			_rect(img, 27, my, 5, 2, Color("3a1c1c"))
			_rect(img, 28, my, 3, 1, PALE.darkened(0.2))
			_rect(img, 27, my + 2, 5, 1, lip_light)
	# The shadow under the lower lip, where the chin starts.
	if shape not in ["open", "grimace"]:
		_rect(img, 28, my + (2 if full else 1), 4, 1, t["dark"])


# ---------------------------------------------------------------- hair and beard

static func _beard(img: Image, f: Dictionary, ht: Dictionary) -> void:
	var hair: Color = ht["base"]
	var dark: Color = ht["dark"]
	match String(f["beard"]):
		"stubble":
			for y in range(42, 52):
				for x in range(19, 42):
					if (x + y) % 2 == 0 and img.get_pixel(x, y).a > 0.0 and not (y in [44, 45, 46] and x in range(25, 36)):
						_px(img, x, y, img.get_pixel(x, y).lerp(dark, 0.4))
		"short":
			_fill_face(img, 42, 52, 18, 42, ht, [44, 45, 46])
		"full":
			_fill_face(img, 40, 56, 17, 43, ht, [44, 45, 46])
			_rect(img, 24, 54, 12, 3, hair)
			_rect(img, 33, 54, 3, 3, dark)
			for x in range(25, 36, 3):
				_px(img, x, 56, dark)
		"moustache":
			_rect(img, 25, 43, 10, 1, hair)
			_rect(img, 24, 44, 2, 1, hair)
			_rect(img, 34, 44, 2, 1, dark)
			_px(img, 30, 43, ht["light"])
		"goatee":
			_rect(img, 25, 43, 10, 1, hair)
			_rect(img, 26, 47, 8, 5, hair)
			_rect(img, 32, 47, 2, 5, dark)
			_rect(img, 27, 51, 6, 2, dark)


## Beard over the lower face: every face pixel in the band but the mouth, with strands.
static func _fill_face(img: Image, y0: int, y1: int, x0: int, x1: int, ht: Dictionary, keep_rows: Array) -> void:
	for y in range(y0, y1):
		for x in range(x0, x1):
			if img.get_pixel(x, y).a <= 0.0 and y < 52:
				continue
			if keep_rows.has(y) and x in range(25, 36):
				continue
			var c: Color = ht["dark"] if x >= 34 else ht["base"]
			if (x * 3 + y) % 7 == 0:
				c = ht["light"] if x < 34 else ht["base"]
			_px(img, x, y, c)


## Hair or headwear, with a shadow where it meets the brow and strands catching light.
static func _hair(img: Image, f: Dictionary, ht: Dictionary, main: Color, trim: Color, t: Dictionary) -> void:
	var style := String(f["hair"])
	var hair: Color = ht["base"]
	var dark: Color = ht["dark"]
	var light: Color = ht["light"]
	var rx := 13.5
	var cap := func(top: int, low: int):
		for y in range(top, low):
			for x in range(int(CX - rx) - 1, int(CX + rx) + 2):
				var dx := (float(x) + 0.5 - CX) / (rx + 1.0)
				var dy := (float(y) + 0.5 - CY) / 16.0
				if dx * dx + dy * dy <= 1.0:
					var c := dark if dx > 0.4 else hair
					if (x + y * 2) % 9 == 0 and dx < 0.3 and y > top + 1:
						c = light
					_px(img, x, y, c)
		# The hairline's shadow on the brow.
		for x in range(int(CX - rx), int(CX + rx) + 1):
			if img.get_pixel(x, low).a > 0.0 and img.get_pixel(x, low) != hair and img.get_pixel(x, low) != dark:
				_px(img, x, low, img.get_pixel(x, low).darkened(0.1))
	match style:
		"short", "crop", "side", "curls":
			cap.call(19, 30 if style != "crop" else 27)
			if style == "side":
				_rect(img, 18, 26, 10, 4, hair)
				_rect(img, 26, 29, 3, 1, hair)
				_px(img, 28, 30, hair)
			if style == "curls":
				for x in range(17, 44, 3):
					_px(img, x, 19 + (x % 2), dark)
					_px(img, x + 1, 21, light)
					_px(img, x, 28 + (x % 2), hair)
			_rect(img, 17, 29, 2, 7, hair)
			_rect(img, 41, 29, 2, 7, dark)
		"receding":
			cap.call(21, 25)
			_rect(img, 17, 26, 3, 10, hair)
			_rect(img, 40, 26, 3, 10, dark)
			_px(img, 18, 25, light)
		"long", "braid":
			cap.call(19, 30)
			for y in range(27, 54):
				var wave := 1 if (y / 5) % 2 == 0 else 0
				_rect(img, 14 + wave, y, 5, 1, hair)
				_rect(img, 41 - wave, y, 5, 1, dark)
				if y % 6 == 2:
					_px(img, 15 + wave, y, light)
			if style == "braid":
				for y in range(50, 66, 2):
					_rect(img, 14, y, 4, 1, dark)
					_rect(img, 15, y + 1, 2, 1, hair)
				_rect(img, 14, 66, 4, 2, trim)
		"tied":
			cap.call(19, 29)
			_rect(img, 41, 32, 4, 14, dark)
			_rect(img, 42, 30, 3, 2, trim)
			_px(img, 41, 36, hair)
		"topknot":
			cap.call(21, 28)
			_rect(img, 26, 13, 8, 7, hair)
			_rect(img, 31, 13, 3, 7, dark)
			_rect(img, 27, 12, 6, 1, light)
			_rect(img, 27, 18, 6, 1, PALE)
			_px(img, 33, 18, PALE.darkened(0.25))
		"shaved":
			cap.call(21, 25)
			for y in range(21, 25):
				for x in range(16, 45):
					var c := img.get_pixel(x, y)
					if c.a > 0.0 and (x + y) % 2 == 0:
						_px(img, x, y, c.lightened(0.15))
		"turban", "wrap":
			var cloth := trim if style == "turban" else main.lightened(0.15)
			for y in range(13, 31):
				for x in range(int(CX - rx) - 3, int(CX + rx) + 4):
					var dx := (float(x) + 0.5 - CX) / (rx + 2.5)
					var dy := (float(y) + 0.5 - 29.0) / 16.0
					if dx * dx + dy * dy <= 1.0 and y <= 30:
						# Folds of the cloth wound round, each with its own light and shadow.
						var fold := (y - 13 + x / 9) % 5
						var c := cloth
						if fold == 0:
							c = cloth.darkened(0.22)
						elif fold == 1:
							c = cloth.lightened(0.08)
						if dx > 0.45:
							c = c.darkened(0.2)
						_px(img, x, y, c)
			if style == "wrap":
				_rect(img, 41, 30, 5, 18, main.lightened(0.15).darkened(0.25))
				_rect(img, 42, 30, 1, 18, main.lightened(0.15).darkened(0.1))
			else:
				_rect(img, 27, 17, 4, 4, BRASS)
				_px(img, 28, 18, BRASS_LIGHT)
				_px(img, 29, 19, Color("3a6ad8"))


# ---------------------------------------------------------------- clothes

## Inside the shoulders' outline: a neckline widening to the shoulders, then straight.
static func _body(x: int, y: int) -> bool:
	if y < 57 or y >= H or x < 0 or x >= W:
		return false
	var half := 15.0 + float(y - 57) * 1.8
	return absf(float(x) + 0.5 - CX) <= minf(half, 28.0)


static func _put(img: Image, x: int, y: int, c: Color) -> void:
	if _body(x, y):
		img.set_pixel(x, y, c)


static func _band(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			_put(img, xx, yy, c)


## The clothes: a garment by culture, lit from the upper left; a collar that meets the
## neck; the marks of the captain's troops, their rank, and their veteran role.
static func _outfit(img: Image, f: Dictionary, main: Color, trim: Color, accent: Color, type: String,
		level: int, spec: String) -> void:
	for y in range(57, H):
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
	# Light: the far shoulder in shadow, the near one lit, a fold under each arm and a
	# shadow under the chin on the chest.
	for y in range(57, H):
		for x in W:
			if not _body(x, y):
				continue
			var c := img.get_pixel(x, y)
			if x >= 39:
				c = c.darkened(0.22)
			elif x <= 18 and y <= 64:
				c = c.lightened(0.1)
			if (x == 17 or x == 43) and y >= 68:
				c = c.darkened(0.15)
			if y <= 59 and absf(float(x) + 0.5 - CX) < 9.0:
				c = c.darkened(0.2)
			img.set_pixel(x, y, c)
	_troop_mark(img, type, trim, main)
	_rank_marks(img, level, main, trim, accent)
	_role_token(img, spec)


static func _vardish(img: Image, garment: int, main: Color, trim: Color, accent: Color) -> void:
	match garment:
		0:
			# Quilted gambeson: diamond stitching, a standing collar, toggles down the front.
			for y in range(60, H):
				for x in W:
					if (x + y) % 6 == 0 or (x - y + 120) % 6 == 0:
						_put(img, x, y, main.darkened(0.14))
			_band(img, 21, 56, 18, 4, trim)
			_band(img, 22, 59, 16, 1, trim.darkened(0.25))
			_band(img, 29, 60, 2, 20, main.darkened(0.3))
			for y in [62, 67, 72, 77]:
				_band(img, 27, y, 6, 1, trim)
				_put(img, 27, y, trim.darkened(0.2))
		1:
			# Mail with a coif round the neck, under a tabard of the house colours.
			for y in range(57, H):
				for x in W:
					var ring := MAIL if (x + (y % 2)) % 2 == 0 else MAIL_DARK
					_put(img, x, y, ring)
			_band(img, 20, 55, 20, 5, MAIL)
			for x in range(20, 40, 2):
				_put(img, x, 57, MAIL_DARK)
				_put(img, x + 1, 59, MAIL_LIGHT)
			_band(img, 19, 62, 22, 18, main)
			_band(img, 19, 62, 1, 18, main.darkened(0.35))
			_band(img, 40, 62, 1, 18, main.darkened(0.35))
			_band(img, 27, 62, 6, 18, accent)
			_band(img, 21, 68, 18, 4, accent)
			_band(img, 19, 62, 22, 1, trim)
		2:
			# A wool cloak gathered in folds over the tunic, pinned with a round brooch.
			_band(img, 21, 57, 18, 23, accent.darkened(0.1))
			_band(img, 23, 56, 14, 2, trim)
			for y in range(57, H):
				for x in W:
					if absf(float(x) + 0.5 - CX) > 9.0:
						var fold := (x % 5 == 0)
						_put(img, x, y, main.darkened(0.25) if fold else (main.lightened(0.05) if x % 5 == 2 else main))
			_band(img, 11, 61, 5, 5, BRASS)
			_put(img, 12, 62, BRASS_LIGHT)
			_put(img, 14, 64, BRASS_DARK)
			_band(img, 16, 63, 6, 1, BRASS_DARK)
		_:
			# A leather jerkin over a coloured shirt: seams, a laced front, steel pauldrons.
			for y in range(57, H):
				for x in W:
					_put(img, x, y, LEATHER if (y % 7) != 0 else LEATHER_DARK)
			_band(img, 24, 57, 12, 23, main)
			_band(img, 24, 57, 1, 23, LEATHER_DARK)
			_band(img, 35, 57, 1, 23, LEATHER_DARK)
			for y in range(60, H, 4):
				_put(img, 26, y, trim)
				_put(img, 27, y + 1, trim)
				_put(img, 32, y + 1, trim)
				_put(img, 33, y, trim)
			for side in [0, 1]:
				var x0: int = 4 if side == 0 else 44
				for y in range(61, 70):
					for x in range(x0, x0 + 12):
						var dy := float(y - 61) / 9.0
						if float(x - x0) / 12.0 > 0.15 * (1.0 - dy) and _body(x, y):
							_put(img, x, y, MAIL_LIGHT if y < 64 else MAIL)
				_band(img, x0, 69, 12, 1, MAIL_DARK)
				_band(img, x0 + 2, 65, 8, 1, MAIL_DARK)


static func _kharzani(img: Image, garment: int, main: Color, trim: Color, accent: Color) -> void:
	match garment:
		0:
			# A robe crossing at the chest, its edges embroidered, a striped sash below.
			for i in 20:
				for side in [-1, 1]:
					var x: int = 30 + side * (i - 9)
					_put(img, x, 57 + i, trim)
					_put(img, x + side, 57 + i, BRASS if i % 2 == 0 else accent)
			_band(img, 4, 74, 52, 6, accent)
			_band(img, 4, 75, 52, 1, trim)
			_band(img, 4, 78, 52, 1, trim.darkened(0.2))
		1:
			# A vest of small brass-edged scales over the robe, laced at the sides.
			_band(img, 17, 58, 26, 22, LEATHER_DARK)
			for y in range(59, H, 2):
				for x in range(17, 43):
					var off := 1 if (y / 2) % 2 == 0 else 0
					if (x + off) % 2 == 0:
						_put(img, x, y, Color("b08a3a"))
					else:
						_put(img, x, y, Color("6e5426"))
			_band(img, 17, 58, 26, 1, trim)
			_band(img, 29, 58, 2, 22, trim)
		2:
			# A chequered scarf draped round the neck and over both shoulders.
			for y in range(56, 69):
				for x in W:
					var reach := 12 + (y - 56)
					if absf(float(x) + 0.5 - CX) <= float(reach) and y <= 67 - absi(x - 30) / 5:
						var check := ((x / 2) + (y / 2)) % 2 == 0
						if _body(x, y) or y < 60:
							img.set_pixel(x, y, trim if check else accent)
			for y in range(67, H):
				for x in [21, 22, 23, 36, 37, 38]:
					var check2: bool = ((x / 2) + (y / 2)) % 2 == 0
					_put(img, x, y, trim if check2 else accent)
		_:
			# An open kaftan with frogged fastenings over a long inner robe.
			_band(img, 24, 57, 12, 23, accent)
			for y in range(61, H, 4):
				_band(img, 20, y, 5, 1, trim)
				_band(img, 35, y, 5, 1, trim)
				_put(img, 25, y, BRASS)
				_put(img, 34, y, BRASS)
			_band(img, 23, 57, 1, 23, trim)
			_band(img, 36, 57, 1, 23, trim)


static func _ryumon(img: Image, garment: int, main: Color, trim: Color, accent: Color) -> void:
	match garment:
		0:
			# A kimono: lapels crossing left over right, pale under-collars, the crest.
			for i in 14:
				var lx := 22 + int(i * 0.6)
				var rx := 38 - int(i * 0.6)
				_put(img, rx, 57 + i, PALE.darkened(0.1))
				_put(img, rx - 1, 57 + i, accent)
				_put(img, lx, 57 + i, PALE)
				_put(img, lx + 1, 57 + i, accent)
			_band(img, 26, 57, 9, 2, PALE)
			_crest(img, 11, 65, trim if trim.get_luminance() > 0.3 else PALE)
		1:
			# Lacquered do armour: rows of plates laced with coloured cord, shoulder guards.
			_band(img, 17, 58, 26, 22, main.darkened(0.2))
			for y in range(60, H, 4):
				_band(img, 17, y, 26, 1, main.darkened(0.45))
				for x in range(18, 43, 3):
					_put(img, x, y + 1, accent)
			for y in range(61, H, 4):
				for x in range(2, 17):
					_put(img, x, y, trim)
				for x in range(43, 58):
					_put(img, x, y, trim)
				for x in range(3, 17, 3):
					_put(img, x, y + 1, accent)
				for x in range(44, 58, 3):
					_put(img, x, y + 1, accent)
			_band(img, 22, 55, 16, 5, trim)
			_band(img, 22, 59, 16, 1, trim.darkened(0.3))
		2:
			# A haori jacket over the kimono: crests on both breasts, a cord tied at the front.
			_band(img, 25, 57, 10, 23, accent)
			_band(img, 24, 57, 1, 23, trim)
			_band(img, 35, 57, 1, 23, trim)
			_crest(img, 13, 64, PALE)
			_crest(img, 41, 64, PALE)
			_band(img, 26, 68, 8, 1, PALE)
			_band(img, 27, 69, 1, 4, PALE)
			_band(img, 32, 69, 1, 4, PALE)
		_:
			# A footsoldier's plain cuirass with a big painted crest.
			_band(img, 16, 58, 28, 22, main.darkened(0.12))
			_band(img, 16, 58, 28, 1, trim)
			_band(img, 16, 65, 28, 1, main.darkened(0.35))
			_crest(img, 27, 69, PALE)
			_band(img, 22, 55, 16, 5, PALE)
			_band(img, 22, 59, 16, 1, PALE.darkened(0.3))


## A noble's mantle: a fur collar (stiff shoulder wings in the Ryumon lands) and a chain.
static func _regalia_body(img: Image, f: Dictionary, house: Color) -> void:
	var gold := Color("d8b048")
	if String(f["culture"]) == "ryumon":
		for y in range(57, 64):
			for x in W:
				var reach := 17 + (y - 57) * 2
				if absf(float(x) + 0.5 - CX) <= float(reach) and absf(float(x) + 0.5 - CX) > 7.0:
					_put(img, x, y, house.lightened(0.1) if y < 60 else house)
		_band(img, 2, 63, 56, 1, gold)
	else:
		var fur := Color("e6dccb") if String(f["culture"]) == "vardish" else Color("cfae74")
		for y in range(56, 64):
			for x in W:
				var reach := 16 + (y - 56) * 2
				if absf(float(x) + 0.5 - CX) <= float(reach) and (y < 61 or absf(float(x) + 0.5 - CX) > 10.0):
					var fleck := (x * 7 + y * 3) % 5 == 0
					var c := fur.darkened(0.25) if fleck else fur
					if _body(x, y) or y < 60:
						img.set_pixel(x, y, c)
	for x in range(16, 45):
		var sag := int(round(5.0 * (1.0 - pow((float(x) - CX) / 14.0, 2.0))))
		_put(img, x, 64 + sag, gold)
	_band(img, 27, 69, 6, 6, gold)
	_band(img, 28, 70, 4, 4, RED)
	_put(img, 28, 70, Color("d85a50"))


static func _circlet(img: Image, f: Dictionary) -> void:
	var gold := Color("e0b84a")
	var y := 22 if String(f["hair"]) in ["turban", "wrap"] else 25
	for x in range(16, 45):
		if img.get_pixel(x, y).a > 0.0 or img.get_pixel(x, y + 1).a > 0.0:
			_px(img, x, y, gold)
			_px(img, x, y + 1, gold.darkened(0.25))
	for x in [20, 30, 40]:
		_px(img, x, y - 1, gold)
		_px(img, x, y - 2, gold.lightened(0.2))
	_px(img, 30, y, Color("3a6ad8"))
	_px(img, 30, y + 1, Color("2a4aa0"))


## A round family crest, seven pixels across.
static func _crest(img: Image, x: int, y: int, c: Color) -> void:
	for p in [Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0), Vector2i(1, 1), Vector2i(5, 1), Vector2i(0, 2), Vector2i(6, 2),
			Vector2i(3, 2), Vector2i(0, 3), Vector2i(6, 3), Vector2i(2, 3), Vector2i(4, 3), Vector2i(0, 4), Vector2i(6, 4),
			Vector2i(3, 4), Vector2i(1, 5), Vector2i(5, 5), Vector2i(2, 6), Vector2i(3, 6), Vector2i(4, 6)]:
		_put(img, x + p.x, y + p.y, c)


## A sign of the captain's troops, worn over the clothes.
static func _troop_mark(img: Image, type: String, trim: Color, main: Color) -> void:
	match type:
		"archers":
			# A quiver strap from the near shoulder across the chest, with a buckle, and
			# fletched arrows showing over the far shoulder.
			for i in 23:
				_put(img, 11 + i, 57 + i, LEATHER)
				_put(img, 12 + i, 57 + i, LEATHER_DARK)
				_put(img, 10 + i, 57 + i, LEATHER_LIGHT)
			_band(img, 20, 65, 4, 4, BRASS)
			_put(img, 21, 66, BRASS_LIGHT)
			for i in 3:
				_band(img, 47 + i * 3, 55 - i, 2, 4, PALE)
				_band(img, 47 + i * 3, 54 - i, 2, 2, RED)
				_put(img, 47 + i * 3, 59 - i, LEATHER_DARK)
		"cavalry":
			# A riding cloak's clasp at the throat, and a horsehair tassel at the far shoulder.
			_band(img, 26, 61, 8, 5, BRASS.darkened(0.15))
			_band(img, 27, 62, 6, 3, BRASS_LIGHT)
			_band(img, 29, 62, 2, 3, BRASS_DARK)
			_band(img, 46, 57, 4, 2, BRASS)
			for y in range(59, 70):
				_put(img, 46 + (y % 2), y, PALE.darkened(0.15))
				_put(img, 48 - (y % 2), y, PALE.darkened(0.3))
		"spearmen":
			# A red tassel from the spear tied at the far shoulder.
			_band(img, 46, 57, 4, 3, LEATHER)
			_band(img, 46, 60, 4, 8, RED)
			_put(img, 47, 68, Color("7a221d"))
			_put(img, 48, 69, Color("7a221d"))
			_put(img, 47, 62, Color("d85a50"))
		_:
			# A round shield slung at the near shoulder: a rim, a boss, a strap.
			for y in range(60, 72):
				for x in range(4, 16):
					var dx := float(x) - 10.0
					var dy := float(y) - 66.0
					var d := dx * dx + dy * dy
					if d <= 30.0:
						_put(img, x, y, trim if d > 17.0 else (LEATHER_LIGHT if dx < 0.0 else LEATHER))
			_band(img, 9, 65, 3, 3, BRASS)
			_put(img, 9, 65, BRASS_LIGHT)
			_band(img, 15, 64, 8, 1, LEATHER_DARK)


## Rank on the clothes: brass at the collar for a seasoned captain, and a short cloak
## of the accent colour over the far shoulder, pinned with a brooch, for a veteran.
static func _rank_marks(img: Image, level: int, main: Color, trim: Color, accent: Color) -> void:
	if level >= 3:
		for y in range(57, H):
			for x in range(40, W):
				if _body(x, y) and x >= 40 + (y - 57) / 6:
					var fold := (x + y / 3) % 6 == 0
					_put(img, x, y, accent.darkened(0.3 if fold else 0.12))
		_band(img, 40, 57, 3, 23, accent.darkened(0.4))
		_band(img, 39, 60, 5, 4, BRASS)
		_put(img, 40, 61, BRASS_LIGHT)
		_put(img, 42, 62, BRASS_DARK)
	if level >= 2:
		for x in range(21, 40):
			if img.get_pixel(x, 57).a > 0.0:
				_px(img, x, 57, BRASS if x % 3 != 0 else BRASS_DARK)
		_band(img, 20, 58, 2, 2, BRASS)
		_band(img, 38, 58, 2, 2, BRASS)


## A small token of a veteran role, low on the lit side of the chest.
static func _role_token(img: Image, spec: String) -> void:
	match spec:
		"Scout":
			# A hawk's feather tucked at the breast.
			for i in 6:
				_put(img, 13 + i, 74 - i, Color("8a6a3a") if i % 2 == 0 else Color("5a4424"))
				_put(img, 14 + i, 74 - i, Color("c9b27a"))
			_put(img, 13, 75, PALE)
		"Quartermaster":
			# A ring of keys on a cord.
			_band(img, 15, 68, 1, 6, LEATHER_DARK)
			_band(img, 13, 73, 5, 1, BRASS)
			_band(img, 13, 74, 1, 3, BRASS)
			_band(img, 17, 74, 1, 3, BRASS)
			_put(img, 12, 76, BRASS_DARK)
			_put(img, 18, 76, BRASS_DARK)
			_put(img, 14, 73, BRASS_LIGHT)
		"Drillmaster":
			# A brass whistle on a red cord.
			for i in 5:
				_put(img, 14 + i, 66 + i, RED)
			_band(img, 18, 71, 2, 5, BRASS)
			_band(img, 17, 75, 4, 2, BRASS)
			_put(img, 18, 71, BRASS_LIGHT)
			_put(img, 20, 76, BRASS_DARK)
		"Champion":
			# A gold laurel pinned over the heart.
			for p in [Vector2i(0, 3), Vector2i(1, 2), Vector2i(1, 1), Vector2i(2, 0), Vector2i(2, 4), Vector2i(1, 4),
					Vector2i(6, 3), Vector2i(5, 2), Vector2i(5, 1), Vector2i(4, 0), Vector2i(4, 4), Vector2i(5, 4)]:
				_put(img, 13 + p.x, 68 + p.y, BRASS)
			_put(img, 16, 70, BRASS_LIGHT)
			_put(img, 16, 72, RED)


# ---------------------------------------------------------------- history

## Scars: one for each wound, up to three, in places worked out once: a pale line with
## a darker edge, so it reads as a healed cut and not a stray stroke.
static func _scars(img: Image, f: Dictionary, captain: Dictionary, t: Dictionary) -> void:
	var scars := mini(3, int(captain.get("history", {}).get("wounds", 0)))
	if scars == 0:
		return
	var srng := RandomNumberGenerator.new()
	srng.seed = int(f["scar_seed"])
	var pale: Color = t["base"].lerp(Color("e8b4a8"), 0.5)
	var edge: Color = t["deep"]
	var skin_set := [t["base"], t["light"], t["dark"], t["deep"], t["flush"]]
	for i in scars:
		var sx := srng.randi_range(20, 38)
		var sy := srng.randi_range(30, 46)
		var dirx := 1 if srng.randf() < 0.5 else -1
		for k in 6:
			var px := sx + k * dirx
			var py := sy + k
			if px < 0 or py < 0 or px >= W or py >= H:
				continue
			if img.get_pixel(px, py) in skin_set:
				_px(img, px, py, pale)
				if img.get_pixel(px + 1, py) in skin_set and k % 2 == 0:
					_px(img, px + 1, py, edge)


## Still recovering: a bandage round the brow, with a spot of blood come through.
static func _bandage(img: Image, f: Dictionary) -> void:
	var y0 := 28
	for x in range(16, 45):
		for y in range(y0, y0 + 3):
			if img.get_pixel(x, y).a > 0.0:
				var c := Color("e8e2d4") if y == y0 else (Color("cfc7b4") if x < 39 else Color("b7ae9a"))
				if y == y0 + 2:
					c = c.darkened(0.08)
				_px(img, x, y, c)
	_px(img, 37, y0 + 1, RED)
	_px(img, 38, y0 + 1, RED.darkened(0.2))
	_px(img, 37, y0 + 2, RED.darkened(0.3))


# ---------------------------------------------------------------- finishing

const BACKDROPS := {"vardish": Color("3d5c94"), "kharzani": Color("9c6a36"), "ryumon": Color("8e3238")}


static func _backdrop(culture: String, house: String = "") -> Image:
	var tint: Color = BACKDROPS.get(culture, BACKDROPS["vardish"])
	if house != "":
		tint = Color(house).darkened(0.15)
	var back := Image.create(W, H, false, Image.FORMAT_RGBA8)
	for y in H:
		for x in W:
			var dx := (float(x) + 0.5 - CX) / 30.0
			var dy := (float(y) + 0.5 - 38.0) / 38.0
			var d := sqrt(dx * dx + dy * dy)
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = floorf(a * 4.0) / 4.0
			back.set_pixel(x, y, Color(tint.r, tint.g, tint.b, minf(1.0, a * 1.3)))
	return back


static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < W and y < H:
		img.set_pixel(x, y, c)


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
