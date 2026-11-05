## A settlement seen from the road to its gate, as pixel art on a 180 x 80 grid: the
## realm's sky and land, the castle, town or village in that realm's style, and what the
## place is going through (garrison, market, raids, repairs, a siege, night, who's there).
## `build` paints it once into images; settlement_vista.gd scales them up and animates
## the clouds, smoke, fires and lanterns on top.
extends RefCounted

const Data = preload("res://scripts/world/world_data.gd")
const SpriteData = preload("res://scripts/art/map_sprite_data.gd")
const TravelPresentation = preload("res://scripts/world/travel_presentation.gd")
const Politics = preload("res://scripts/data/politics.gd")

const W := 180
const H := 80
const HZ := 44
const BAYER := [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
const NIGHT_TINT := Color("4a5488")
const DARK := Color("2a2430")
const GOLD := Color("d9a944")

const LOOK := {
	"vardish": {"sky": ["6f86a8", "a9b8c8", "d3d9de"], "far": "7d92a3", "mid": "55785c", "grass": "6c9448", "grass2": "5c8540", "tuft": "4b7236",
		"road": "a08766", "road2": "8a7356", "stone": "c4bca9", "stoneS": "8e8576", "mortar": "aea591", "roof": "64708a", "roofS": "424a60",
		"tile": "b04c36", "tileS": "783026", "wood": "5a3e28", "plaster": "e6dcc2", "thatch": "c9a35a", "thatchS": "94723a"},
	"kharzani": {"sky": ["6aa2d0", "b4cfdc", "f2dcaa"], "far": "e8cd98", "mid": "d7ad66", "grass": "e0bf84", "grass2": "d3ad6c", "tuft": "c39a5a",
		"road": "c9a46a", "road2": "b08b52", "stone": "daba84", "stoneS": "aa8a5a", "mortar": "c8a670", "roof": "2f8a7a", "roofS": "1d5e54",
		"tile": "ece6d6", "tileS": "bdb5a2", "wood": "7a5232", "plaster": "ece6d6", "thatch": "c99a62", "thatchS": "9c7244"},
	"ryumon": {"sky": ["88a9c4", "c9cdd6", "f0d6cf"], "far": "8592a8", "mid": "4f6658", "grass": "7c9c54", "grass2": "6c8c48", "tuft": "587a3c",
		"road": "a99a7c", "road2": "8f8064", "stone": "a29f96", "stoneS": "77746c", "mortar": "8a877e", "roof": "3a3f4a", "roofS": "262a33",
		"tile": "3a3f4a", "tileS": "262a33", "wood": "4a362e", "plaster": "f1ece0", "thatch": "a8875a", "thatchS": "7a6040"},
}
const TEAM := {"vardmark": ["4a74d1", "284282", "a0befa"], "kharzan": ["d9962b", "8f5a14", "f4cf86"], "ryumon": ["b8352a", "6e1c16", "f08a7a"],
	"crown": ["5a4f86", "2a2440", "d9a944"], "bandits": ["4a4038", "2a2522", "8a7c6c"]}
const CULTURE_OF_REALM := {"vardmark": "vardish", "kharzan": "kharzani", "ryumon": "ryumon", "crown": "vardish", "bandits": "vardish"}

# Each realm's banner, one pixel a cell: big ones over gates and keeps, small ones on staffs.
const BANNER := {
	"vardmark": {"map": {"B": "3459b8", "W": "e6e8f0", "R": "c9473d"},
		"rows": ["BBBBBBB", "BBBRBBB", "BBWWWBB", "BWBWBWB", "BWWWWWB", "BWWBWWB", "BWWBWWB", "BBBBBBB", ".BBBBB.", "..BBB.."],
		"small": ["BBB", "BWB", "BWB", "BBB", ".B."]},
	"kharzan": {"map": {"O": "d9962b", "r": "a8261c", "g": "1f7a6e"},
		"rows": ["OOOOOOOOO", "OrrrOOOO.", "OrrrOOO..", "OOOOOOO..", "ggggggO..", "OOOOOOOO.", "gggggggOO"],
		"small": ["OOO", "OrO", "OOO", "ggO", "OO."]},
	"ryumon": {"map": {"w": "f1ece0", "R": "b8352a", "K": "14161f"},
		"rows": ["wwwww", "RRRRR", "RKKKR", "KKwKK", "KwwwK", "KKwKK", "RKKKR", "RRRRR", "RRRRR", "RRRRR"],
		"small": ["www", "RRR", "RKR", "RRR", "RRR", "RRR"]},
	"crown": {"map": {"D": "1d1a2a", "b": "d9a944"},
		"rows": ["DDDDDDD", "DbDbDbD", "DbbbbbD", "DbbbbbD", "DDDDDDD", "DDDDDDD", ".DDDDD."],
		"small": ["DDD", "DbD", "DDD", "DDD"]},
	"bandits": {"map": {"D": "2a2522", "b": "b8b0a4"},
		"rows": ["DDDDDDD", "DbDDDDD", "DDbDDDD", "DDDbDDD", "DDDDbD.", "DD.DDb.", "D..D.D."],
		"small": ["DDD", "DbD", "D.D"]},
}
const FIG := {
	"vardish": {"rows": [".hh.", ".ss.", "bbbb", "bsbb", ".bb.", ".ll.", ".l.l"], "map": {"h": "6a4a2c", "s": "e2b284", "b": "5c7a3a", "l": "3a2c22"}, "alt": {"b": "8a4a3a", "h": "c8a060"}},
	"kharzani": {"rows": [".hh.", ".ss.", "bbbb", "bsbb", "bbbb", "bbbb", ".l.l"], "map": {"h": "ece6d6", "s": "c99064", "b": "3c6a9a", "l": "5a4030"}, "alt": {"b": "b8823a", "h": "d9962b"}},
	"ryumon": {"rows": ["hhhh", ".ss.", "bbbb", "bsbb", ".bb.", ".ll.", ".l.l"], "map": {"h": "c9a868", "s": "e2b284", "b": "3a4a7a", "l": "2a2430"}, "alt": {"b": "6a5a4a", "h": "b8945a"}},
}


## Paints into one 180 x 80 image, blending, and notes what the vista animates.
class Painter:
	var img: Image
	var ga := 1.0
	var ox := 0
	var oy := 0
	var lights: Array = []
	var fires: Array = []
	var lanterns: Array = []
	var smokes: Array = []
	## Mill wheels the vista turns: [x, y, radius, spoke colour, turning].
	var wheels: Array = []
	## Where each improvement was painted, {key: [Rect2i]}, so the vista can mark a new one.
	var spots := {}
	## A still picture (a plate) paints its wheels' spokes instead of leaving them to turn.
	var still := false

	func _init() -> void:
		img = Image.create_empty(W, H, false, Image.FORMAT_RGBA8)

	func put(x: int, y: int, c: Color) -> void:
		x += ox
		y += oy
		if x < 0 or y < 0 or x >= W or y >= H:
			return
		var a := c.a * ga
		if a >= 0.999:
			img.set_pixel(x, y, Color(c.r, c.g, c.b, 1.0))
			return
		if a <= 0.0:
			return
		var d := img.get_pixel(x, y)
		var k := d.a * (1.0 - a)
		var oa := a + k
		img.set_pixel(x, y, Color((c.r * a + d.r * k) / oa, (c.g * a + d.g * k) / oa, (c.b * a + d.b * k) / oa, oa))

	func r(x: float, y: float, w: float, h: float, c: Color) -> void:
		var x0 := roundi(x)
		var y0 := roundi(y)
		var w0 := roundi(w)
		var h0 := roundi(h)
		if w0 <= 0 or h0 <= 0:
			return
		if ga >= 0.999 and c.a >= 0.999:
			var rect := Rect2i(x0 + ox, y0 + oy, w0, h0).intersection(Rect2i(0, 0, W, H))
			if rect.size.x > 0 and rect.size.y > 0:
				img.fill_rect(rect, Color(c.r, c.g, c.b, 1.0))
			return
		for yy in range(y0, y0 + h0):
			for xx in range(x0, x0 + w0):
				put(xx, yy, c)

	func p(x: float, y: float, c: Color) -> void:
		put(roundi(x), roundi(y), c)

	func faint(a: float, fn: Callable) -> void:
		var was := ga
		ga = a
		fn.call()
		ga = was

	func grid(rows: Array, x: float, y: float, map: Dictionary = {}, flip: bool = false) -> void:
		for j in rows.size():
			var row := String(rows[j])
			for i in row.length():
				var ch := row[i]
				if ch == ".":
					continue
				var col = map.get(ch, SpriteData.PALETTE.get(ch, Color.MAGENTA))
				if col is String:
					col = Color(col)
				p(x + (row.length() - 1 - i if flip else i), y + j, col)

	func ridge(f: Callable, c: Color, x0: int = 0, x1: int = W, bottom: int = H) -> void:
		for x in range(x0, x1):
			var y := roundi(float(f.call(x)))
			r(x, y, 1, bottom - y, c)

	func tri(x0: float, x1: float, top: int, base: int, c: Color, sh = null) -> void:
		var mid := (x0 + x1) / 2.0
		for y in range(top, base + 1):
			var t := float(y - top) / maxf(1.0, base - top)
			var half := (x1 - x0) / 2.0 * t
			for x in range(roundi(mid - half), roundi(mid + half) + 1):
				p(x, y, sh if sh != null and x > mid else c)

	func dome(cx: float, by: float, rad: int, c: Color, sh = null, hi = null) -> void:
		for y in range(-rad, 1):
			var w := roundi(sqrt(float(rad * rad - y * y)))
			for x in range(-w, w + 1):
				var col: Color = c
				if sh != null and x > w * 0.25:
					col = sh
				elif hi != null and x < -w * 0.4 and y < -rad * 0.3:
					col = hi
				p(cx + x, by + y, col)

	func win(x: float, y: float, w: float = 1, h: float = 2, c: Color = DARK) -> void:
		r(x, y, w, h, c)
		lights.append([x + ox, y + oy, w, h, c])

	func torch(x: float, y: float) -> void:
		r(x, y + 1, 1, 2, Color("4a3324"))
		fires.append(Vector2(x + ox, y + oy))

	func smoke(x: float, y: float, h: int, c: Color, a: float) -> void:
		smokes.append([x + ox, y + oy, h, c, a])

	func multiply(tint: Color) -> void:
		for y in H:
			for x in W:
				var d := img.get_pixel(x, y)
				if d.a > 0.0:
					img.set_pixel(x, y, Color(d.r * tint.r, d.g * tint.g, d.b * tint.b, d.a))

	func wash(c: Color, a: float) -> void:
		for y in H:
			for x in W:
				var d := img.get_pixel(x, y)
				if d.a > 0.0:
					img.set_pixel(x, y, Color(d.r + (c.r - d.r) * a, d.g + (c.g - d.g) * a, d.b + (c.b - d.b) * a, d.a))


static func col(key: String, L: Dictionary) -> Color:
	return Color(String(L[key]))


# ---------------------------------------------------------------- what to show

## The scene's settings for place `id`, read from the world without changing it.
static func params(world, id: String) -> Dictionary:
	var info: Dictionary = Data.settlement(id)
	var built_by := String(info["faction"])
	var owner: String = String(world.owner_of(id)) if world != null else built_by
	var o := {"id": id, "culture": Data.culture_of(built_by), "kind": String(info["type"]),
		"owner": owner if BANNER.has(owner) else "bandits", "garrison": "full", "prosperity": "normal",
		"condition": "healthy", "night": false, "visitors": [], "player": "", "besieger": "", "seed": absi(id.hash()),
		"improvements": []}
	if world == null:
		return o
	# What the company has built at its own fief stands there even while the fief is lost.
	var gs = world.get("game_state")
	if gs != null and gs.has_method("is_player_fief") and gs.is_player_fief(id):
		var imps: Dictionary = gs.player_fief.get("improvements", {})
		for k in IMP_KEYS:
			if bool(imps.get(k, false)):
				o["improvements"].append(k)
	var state: Dictionary = TravelPresentation.settlement_state(world, id)
	o["night"] = bool(state.get("night", false))
	if String(state.get("garrison", "none")) in ["thin", "none"] and o["kind"] != Data.VILLAGE:
		o["garrison"] = "thin"
	match String(state.get("condition", "healthy")):
		"besieged":
			o["condition"] = "besieged"
			var realm := String(world.siege_info(id).get("realm", "bandits"))
			o["besieger"] = realm if BANNER.has(realm) else "bandits"
		"damaged":
			o["condition"] = "raided" if o["kind"] == Data.VILLAGE else "healthy"
		"recovering":
			o["condition"] = "recovering" if o["kind"] == Data.VILLAGE else "healthy"
	# A market fills in a realm at peace with a strong guard, and empties when it's held
	# by strangers, thinly guarded or worn down by war.
	var weary := float(world.weariness_of(owner)) / Politics.WEARINESS_MAX if world.has_method("weariness_of") else 0.0
	var cond := String(state.get("condition", "healthy"))
	if cond in ["strained", "occupied", "damaged"] or weary >= 0.6:
		o["prosperity"] = "poor"
	elif cond == "healthy" and String(state.get("garrison", "")) == "strong" and weary < 0.25:
		o["prosperity"] = "rich"
	# Lords of other realms staying here hang their banners on the wall.
	var seen := {}
	for l in world.lords:
		var lp = world.party(int(l.get("party", -1)))
		var realm := String(l.get("realm", ""))
		if lp == null or lp.node != id or realm == owner or not BANNER.has(realm) or seen.has(realm):
			continue
		seen[realm] = true
		o["visitors"].append(realm)
	if o["condition"] != "besieged" and world.player() != null and world.player().node == id:
		var mine := String(Data.realm_of_culture(world.culture))
		o["player"] = mine if TEAM.has(mine) else "vardmark"
	return o


# ---------------------------------------------------------------- painting

## Paints the scene for `o` (see `params`). Returns the sky, the drifting clouds (or
## null), everything in front of the sky, and the things the vista animates.
static func build(o: Dictionary) -> Dictionary:
	var L: Dictionary = LOOK.get(String(o.get("culture", "vardish")), LOOK["vardish"])
	var sky := Painter.new()
	var front := Painter.new()
	var stars := []
	_sky(sky, o, L, stars)
	var clouds = _clouds(o) if not bool(o.get("night", false)) and o.get("culture") == "vardish" else null
	_land(front, o, L)
	_ground(front, o, L)
	var kind := String(o.get("kind"))
	if kind == Data.CASTLE:
		_road(front, L, 90, 56, 8)
	elif kind == Data.TOWN:
		_road(front, L, 90, 46, 3)
	else:
		_road(front, L, 90, 60, 4)
	match String(o.get("culture")):
		"kharzani":
			if kind == Data.CASTLE: _khar_castle(front, o, L)
			elif kind == Data.TOWN: _khar_town(front, o, L)
			else: _khar_village(front, o, L)
		"ryumon":
			if kind == Data.CASTLE: _ryu_castle(front, o, L)
			elif kind == Data.TOWN: _ryu_town(front, o, L)
			else: _ryu_village(front, o, L)
		_:
			if kind == Data.CASTLE: _vard_castle(front, o, L)
			elif kind == Data.TOWN: _vard_town(front, o, L)
			else: _vard_village(front, o, L)
	if kind == Data.CASTLE:
		_castle_improvements(front, o, L)
	_foreground(front, o, L)
	if o.get("condition") == "besieged":
		sky.wash(Color("6e3a2c"), 0.18)
		front.wash(Color("6e3a2c"), 0.18)
	if bool(o.get("night", false)):
		_night(sky, front, o)
	return {"sky": sky.img, "clouds": clouds.img if clouds != null else null, "front": front.img,
		"smokes": front.smokes, "fires": front.fires, "lanterns": front.lanterns, "stars": stars,
		"night": bool(o.get("night", false)), "wheels": front.wheels, "spots": front.spots}


static func _night(sky: Painter, front: Painter, o: Dictionary) -> void:
	# Light the windows nothing has covered, darken everything, then add the lit panes.
	var lit := []
	var i := 0
	for l in front.lights:
		i += 1
		if (i * 7) % 5 == 0:
			continue
		var x := roundi(float(l[0]))
		var y := roundi(float(l[1]))
		if x < 0 or y < 0 or x >= W or y >= H:
			continue
		if front.img.get_pixel(x, y).is_equal_approx(Color(l[4])):
			lit.append(l)
	sky.multiply(NIGHT_TINT)
	front.multiply(NIGHT_TINT)
	var mx := 34 if o.get("culture") == "kharzani" else 148
	for dy in range(-4, 5):
		for dx in range(-4, 5):
			if dx * dx + dy * dy <= 17:
				sky.p(mx + dx, 9 + dy, Color("b9c2d8") if (dx + 1) * (dx + 1) + (dy + 1) * (dy + 1) > 16 else Color("eef1f6"))
	for l in lit:
		front.r(l[0], l[1], l[2], l[3], Color("ffd678"))
		front.faint(0.25, func(): front.r(float(l[0]) - 1, float(l[1]) - 1, float(l[2]) + 2, float(l[3]) + 2, Color("ffb84a")))


static func _sky(P: Painter, o: Dictionary, L: Dictionary, stars: Array) -> void:
	var night := bool(o.get("night", false))
	var cols: Array = ["0d1430", "1b2650", "34406a"] if night else L["sky"]
	var n := cols.size() - 1
	for y in HZ + 6:
		var t := float(y) / float(HZ + 6) * n
		var i := mini(n - 1, int(t))
		var f := t - i
		var q := f * 4.0
		var qi := int(q)
		var qf := q - qi
		var a := Color(String(cols[i]))
		var b := Color(String(cols[i + 1]))
		for x in W:
			var k := float(qi + 1 if qf * 16.0 > BAYER[y % 4][x % 4] else qi) / 4.0
			P.img.set_pixel(x, y, a.lerp(b, k))
	P.r(0, HZ + 6, W, H - HZ - 6, Color(String(cols[n])))
	if night:
		var rng := RandomNumberGenerator.new()
		rng.seed = int(o.get("seed", 3))
		for i in 40:
			stars.append([rng.randi_range(0, W - 1), rng.randi_range(0, 25), rng.randf() > 0.8, rng.randf() * TAU])
		return
	match String(o.get("culture")):
		"kharzani":
			P.faint(0.35, func(): P.dome(34, 14, 9, Color("fff6d8")))
			P.dome(34, 14, 5, Color("fff8e4"))
			P.r(29, 14, 11, 1, Color("fff8e4"))
		"ryumon":
			P.faint(0.5, func(): P.dome(150, 15, 6, Color("fbe3c8")))
			P.dome(150, 15, 4, Color("fff0dc"))
			P.r(146, 15, 9, 1, Color("fff0dc"))
	if o.get("condition") == "besieged":
		P.faint(0.35, func(): P.r(0, 0, W, HZ, Color("5a4a48")))


## Vardmark's cloud bank, on its own layer so it can drift behind the towers.
static func _clouds(_o: Dictionary) -> Painter:
	var P := Painter.new()
	for c in [[20, 12, 9], [34, 10, 7], [46, 13, 6], [118, 9, 8], [132, 7, 10], [148, 10, 7], [160, 12, 5]]:
		P.dome(c[0], c[1] + 2, c[2], Color("e0e4e8"), Color("c3cbd5"), Color("f0f2f4"))
		P.r(c[0] - c[2], c[1] + 2, 2 * c[2], 1, Color("b4bfcc"))
	return P


static func _land(P: Painter, o: Dictionary, L: Dictionary) -> void:
	match String(o.get("culture")):
		"vardish":
			P.ridge(func(x): return 33 + sin(x / 23.0) * 3 + sin(x / 9.0 + 1) * 1.2, col("far", L), 0, W, HZ + 2)
			P.ridge(func(x): return 39 + sin(x / 17.0 + 2) * 2.2, col("mid", L), 0, W, HZ + 2)
			for x in range(2, W, 5):
				_pine(P, x + (x * 7 % 3), 43 + roundi(sin(x / 17.0 + 2) * 1.5), 5 + (x * 13 % 4), Color("3f6a4a"), Color("2f5a3e"))
		"kharzani":
			P.faint(0.5, func(): P.r(0, HZ - 6, W, 4, Color("f6e6c2")))
			P.ridge(func(x): return 35 + sin(x / 19.0) * 3 + sin(x / 7.0) * 0.8, col("far", L), 0, W, HZ + 2)
			P.ridge(func(x): return 37 - absf(sin(x / 28.0 + 0.6)) * 3 + 3, Color("eed9ac"), 0, W, 39)
			P.ridge(func(x): return 40 + sin(x / 13.0 + 1) * 2, col("mid", L), 0, W, HZ + 2)
			for x in range(140, 168):
				var y := 38 - (x - 140) * 2 if x < 144 else (30 + (x - 164) * 2 if x > 164 else 30)
				P.r(x, y, 1, 44 - y, Color("b88a5e") if x > 158 else Color("c99a6a"))
		_:
			for x in range(14, 120):
				var y := roundi(minf(absf(x - 58) * 0.75 + 7, absf(x - 84) * 0.55 + 13) + sin(x / 4.0) * 1.1 + (1 if x > 58 and x < 84 else 0))
				P.r(x, y, 1, HZ - y, Color("76839a") if x > 58 else col("far", L))
				if y < 15:
					P.r(x, y, 1, 15 - y + (2 if x % 3 == 0 else (1 if x % 4 == 1 else 0)), Color("d8dee8") if x > 58 else Color("f2f6fa"))
			P.faint(0.55, func():
				P.r(0, 26, W, 3, Color("eef0f4"))
				P.r(10, 30, 120, 2, Color("eef0f4")))
			P.ridge(func(x): return 36 + sin(x / 15.0 + 1) * 3, Color("6a7e7a"), 0, W, HZ + 2)
			P.ridge(func(x): return 40 + sin(x / 11.0 + 3) * 2, col("mid", L), 0, W, HZ + 2)
			for x in range(3, W, 6):
				_pine(P, x, 42 + roundi(sin(x / 11.0 + 3) * 1.5), 4 + (x * 7 % 4), Color("3e5a48"), Color("2c4436"))
			P.faint(0.4, func(): P.r(0, 40, W, 2, Color("eef0f4")))


static func _ground(P: Painter, o: Dictionary, L: Dictionary) -> void:
	var g1 := col("grass", L)
	var g2 := col("grass2", L)
	for y in range(HZ, H):
		var t := float(y - HZ) / float(H - HZ)
		for x in W:
			P.img.set_pixel(x, y, g2 if t * 16.0 > BAYER[y % 4][x % 4] + 4 else g1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	var tuft := col("tuft", L)
	for i in 60:
		var x := rng.randi_range(0, W - 1)
		var y := HZ + 2 + rng.randi_range(0, H - HZ - 3)
		P.p(x, y, tuft)
		if o.get("culture") != "kharzani":
			P.p(x + 1, y - 1, tuft)
	if o.get("culture") == "kharzani":
		for y in range(60, H, 5):
			for x in range((y * 3) % 7, W, 9):
				P.r(x, y, 4, 1, Color("cfa868"))


static func _road(P: Painter, L: Dictionary, gx: float, gy: int, w0: float) -> void:
	var road := col("road", L)
	var edge := col("road2", L)
	for y in range(gy, H):
		var t := float(y - gy) / float(H - gy)
		var half := w0 / 2.0 + t * 14.0
		P.r(gx - half, y, half * 2.0, 1, road)
		P.p(gx - half, y, edge)
		P.p(gx + half - 1, y, edge)
		if (y * 5) % 7 == 0:
			P.p(gx - 2 + (y % 5), y, edge)


static func _fields(P: Painter, x0: int, y0: int, w: int, h: int, cols: Array) -> void:
	for y in h:
		for x in w:
			P.p(x0 + x, y0 + y, Color(String(cols[int(floor((x + y * 0.5) / 2.0)) % cols.size()])))


# ---------------------------------------------------------------- pieces

static func _banner(P: Painter, realm: String, x: float, y: float, pole: int = 0) -> void:
	var b: Dictionary = BANNER.get(realm, BANNER["bandits"])
	if pole > 0:
		P.r(x - 1, y - 1, 1, pole + 1, Color("3a2a1c"))
		P.p(x - 1, y - 2, GOLD)
	P.grid(b["rows"], x, y, b["map"])


static func _small(P: Painter, realm: String, x: float, y: float, h: int = 10) -> void:
	var b: Dictionary = BANNER.get(realm, BANNER["bandits"])
	P.r(x, y, 1, h, Color("2e2218"))
	P.p(x, y - 1, GOLD)
	P.grid(b["small"], x + 1, y + 1, b["map"])


static func _person(P: Painter, culture: String, x: float, y: float, alt := false, flip := false, tool := "") -> void:
	var f: Dictionary = FIG.get(culture, FIG["vardish"])
	var map: Dictionary = f["map"].duplicate()
	if alt:
		map.merge(f["alt"], true)
	P.grid(f["rows"], x, y - 7, map, flip)
	if tool == "hoe":
		P.r(x + (-1 if flip else 4), y - 6, 1, 6, Color("7a5232"))
		P.p(x + (-2 if flip else 5), y - 1, Color("9c948a"))
	elif tool == "basket":
		P.r(x + (-1 if flip else 3), y - 4, 2, 2, Color("b8945a"))


static func _guard(P: Painter, x: float, y: float, c: Color) -> void:
	P.p(x + 1, y, Color("9aa0aa"))
	P.p(x + 1, y + 1, Color("e2b284"))
	P.r(x, y + 2, 3, 3, c)
	P.r(x + 3, y - 2, 1, 7, Color("5a4030"))
	P.p(x + 3, y - 3, Color("bbb5a4"))


static func _gate_guard(P: Painter, x: float, y: float, c: Color) -> void:
	P.grid([".m.", ".s.", "ccc", "ccc", "ccc", "l.l"], x, y - 6, {"m": "9aa0aa", "s": "e2b284", "c": c, "l": "2a2430"})
	P.r(x + 3, y - 9, 1, 9, Color("5a4030"))
	P.p(x + 3, y - 10, Color("cfc9ba"))


static func _beast(P: Painter, kind: String, x: float, y: float, flip := false) -> void:
	match kind:
		"sheep": P.grid([".www.", "wwwwk", "wwww.", ".k.k."], x, y - 4, {"w": "e8e2d2", "k": "3a3030"}, flip)
		"ox": P.grid(["......kk", "qqqqqqqk", "qqqqqqk.", "qqqqqq..", ".q.q.q.q", ".q.q.q.q"], x, y - 6, {"q": "6e4e38", "k": "3a2a20"}, flip)
		"camel": P.grid(["........yy", "..yy....y.", ".yyyy...y.", "yyyyyyyyy.", ".yyyyyyy..", ".y.y..y.y.", ".y.y..y.y.", ".y.y..y.y."], x, y - 8, {"y": "9a6e44"}, flip)
		"goat": P.grid(["....k", "ggggg", "gggg.", ".g.g."], x, y - 4, {"g": "8a6a4a", "k": "3a2a20"}, flip)
		"hen": P.grid([".r", "ww", "w."], x, y - 3, {"r": "c9473d", "w": "f0ead8"})


static func _pine(P: Painter, x: float, base: float, h: int, c := Color("2f5a3e"), s := Color("244834")) -> void:
	P.r(x, base - 2, 1, 2, Color("4a3324"))
	for i in h:
		var w := int(fmod(i * 0.6, 3.0)) + int(i / 3)
		for k in range(-w, w + 1):
			P.p(x + k, base - h - 1 + i, s if k > 0 else c)


static func _oak(P: Painter, x: float, base: float, rad: int) -> void:
	var c := Color("4f7a3e")
	var s := Color("3a5e2e")
	P.r(x, base - rad, 1, rad, Color("5a3e28"))
	P.dome(x, base - rad + 1, rad, c, s, c.lightened(0.15))
	P.r(x - rad + 1, base - rad + 1, 2 * rad - 1, 1, s)


static func _palm(P: Painter, x: float, base: float, h: int, lean: float = 1.0) -> void:
	for i in h:
		P.p(x + roundi(lean * i * i / (h * 3.0)), base - i, Color("8c5c32") if i % 2 else Color("6e4628"))
	var tx := x + roundi(lean * h / 3.0)
	var ty := base - h
	for d in [[-4, 2], [-3, 1], [-2, 0], [-1, 0], [1, 0], [2, 0], [3, 1], [4, 2], [-5, 3], [5, 3], [0, -1], [-1, -1], [1, -1]]:
		P.p(tx + d[0], ty + d[1], Color("345826") if d[1] > 1 else Color("548038"))
	P.p(tx - 2, ty + 1, Color("548038"))
	P.p(tx + 2, ty + 1, Color("548038"))
	P.p(tx, ty + 1, Color("8c5c32"))


static func _cherry(P: Painter, x: float, base: float, rad: int) -> void:
	P.r(x, base - rad, 1, rad, Color("4a3028"))
	P.dome(x, base - rad + 1, rad, Color("f0b2c6"), Color("d98aa6"), Color("f8d4e0"))


static func _embers(P: Painter, x: float, y: float, w: int) -> void:
	for i in w:
		if i % 2:
			P.p(x + i, y, Color("ff9a3a"))
		if i % 3 == 0:
			P.p(x + i, y - 1, Color("ffd678"))
	P.fires.append(Vector2(x + w / 2.0 + P.ox, y - 1 + P.oy))


static func _stone_wall(P: Painter, x: float, y: float, w: float, h: float, L: Dictionary, step: int = 6) -> void:
	P.r(x, y, w, h, col("stone", L))
	P.r(x, y + h - 1, w, 1, col("stoneS", L))
	var mortar := col("mortar", L)
	var yy := int(y) + 3
	while yy < y + h - 1:
		var xx := int(x) + (3 if yy % 8 == 0 else 0)
		while xx < x + w - 1:
			P.r(xx, yy, minf(4, x + w - xx), 1, mortar)
			xx += step
		yy += 4


static func _merlons(P: Painter, x0: int, x1: int, y: float, c: Color, gap := Vector2i(-1, -1)) -> void:
	for x in range(x0, x1, 3):
		if x >= gap.x and x < gap.y:
			continue
		P.r(x, y, 2, 2, c)


static func _arch(P: Painter, cx: float, base: float, w: float, h: int, c := DARK, pointed := false) -> void:
	for y in h:
		var half := w / 2.0
		var top := h - y
		if pointed and top > h - w / 2.0:
			half = maxf(0.0, w / 2.0 - (top - (h - w / 2.0)))
		elif not pointed and y < 2:
			half = w / 2.0 - (2 - y)
		P.r(cx - half, base - h + y, half * 2.0, 1, c)


static func _team(o: Dictionary) -> Color:
	return Color(String(TEAM.get(String(o.get("owner")), TEAM["vardmark"])[0]))


static func _guards_on(P: Painter, o: Dictionary, spots: Array, c: Color) -> void:
	var pick := spots
	if o.get("garrison") == "thin":
		pick = [spots[1], spots[spots.size() - 2]]
	for s in pick:
		_guard(P, s[0], s[1], c)


static func _visitors(P: Painter, o: Dictionary, spots: Array) -> void:
	var v: Array = o.get("visitors", [])
	for i in mini(v.size(), spots.size()):
		_banner(P, String(v[i]), spots[i][0], spots[i][1])


# ---------------------------------------------------------------- castles

static func _vard_castle(P: Painter, o: Dictionary, L: Dictionary) -> void:
	var T := _team(o)
	var stone := col("stone", L)
	var shade := col("stoneS", L)
	P.r(106, 18, 10, 20, shade)
	P.r(106, 18, 8, 20, stone)
	P.tri(103, 117, 6, 18, col("roof", L), col("roofS", L))
	P.win(109, 22)
	_stone_wall(P, 60, 12, 28, 26, L)
	P.r(84, 12, 4, 26, shade)
	_merlons(P, 60, 88, 10, stone)
	for w in [[66, 18], [73, 18], [80, 18], [70, 26], [77, 26]]:
		P.win(w[0], w[1])
	_banner(P, o["owner"], 75, 1, 9)
	_guards_on(P, o, [[36, 30], [48, 30], [60, 30], [107, 30], [119, 30], [131, 30], [140, 30]], T)
	_stone_wall(P, 30, 35, 120, 21, L)
	_merlons(P, 30, 150, 33, stone)
	for tx in [22, 146]:
		_stone_wall(P, tx, 26, 12, 30, L)
		P.r(tx + 9, 26, 3, 30, shade)
		_merlons(P, tx, tx + 12, 24, stone)
		P.r(tx + 5, 33, 1, 4, DARK)
		P.r(tx + 5, 44, 1, 4, DARK)
	_stone_wall(P, 77, 24, 26, 32, L)
	P.r(99, 24, 4, 32, shade)
	_merlons(P, 77, 103, 22, stone)
	_arch(P, 90, 56, 10, 14)
	var open: bool = o.get("condition") != "besieged" and o.get("player", "") != ""
	for x in range(86, 95, 2):
		P.r(x, 43, 1, 3 if open else 10, Color("5e5448"))
	if not open:
		for y in range(45, 54, 3):
			P.r(86, y, 9, 1, Color("5e5448"))
	_banner(P, o["owner"], 87, 28)
	P.torch(82, 44)
	P.torch(97, 44)
	_visitors(P, o, [[64, 39], [110, 39], [52, 39]])


static func _khar_castle(P: Painter, o: Dictionary, L: Dictionary) -> void:
	var T := _team(o)
	var stone := col("stone", L)
	var shade := col("stoneS", L)
	var roof := col("roof", L)
	P.r(54, 26, 26, 10, col("plaster", L))
	P.r(74, 26, 6, 10, col("tileS", L))
	for x in range(57, 76, 4):
		P.win(x, 29, 1, 3)
	P.dome(67, 26, 11, roof, col("roofS", L), roof.lightened(0.25))
	P.r(67, 12, 1, 3, GOLD)
	P.p(67, 11, GOLD)
	P.r(114, 6, 5, 30, col("plaster", L))
	P.r(117, 6, 2, 30, col("tileS", L))
	P.r(112, 13, 9, 2, shade)
	P.r(114, 20, 5, 1, roof)
	P.dome(116, 6, 3, roof, col("roofS", L))
	P.p(116, 2, GOLD)
	P.win(116, 16, 1, 2)
	P.win(116, 25, 1, 2)
	_guards_on(P, o, [[36, 30], [50, 30], [62, 30], [108, 30], [122, 30], [134, 30], [142, 30]], T)
	_stone_wall(P, 28, 35, 124, 21, L, 7)
	for x in range(28, 152, 4):
		P.r(x, 33, 3, 2, stone)
		P.p(x + 1, 32, stone)
	P.r(28, 40, 124, 1, roof)
	for tx in [20, 148]:
		for dx in 13:
			P.r(tx + dx, 27, 1, 29, stone.lightened(0.12) if dx < 3 else (shade if dx > 8 else stone))
		for x in range(tx, tx + 13, 4):
			P.r(x, 25, 3, 2, stone)
			P.p(x + 1, 24, stone)
		P.r(tx + 6, 33, 1, 4, DARK)
		P.r(tx, 31, 13, 1, roof)
	_stone_wall(P, 76, 22, 28, 34, L, 7)
	P.r(100, 22, 4, 34, shade)
	for x in range(76, 104, 4):
		P.r(x, 20, 3, 2, stone)
		P.p(x + 1, 19, stone)
	P.r(76, 27, 28, 2, roof)
	for x in range(77, 104, 3):
		P.p(x, 27, Color("f2e8c8"))
	_arch(P, 90, 56, 12, 20, Color("e8cfa0"), true)
	_arch(P, 90, 56, 10, 18, DARK, true)
	if o.get("player", "") == "" or o.get("condition") == "besieged":
		P.r(86, 44, 8, 12, Color("6a4428"))
		P.r(89, 44, 1, 12, Color("3a2414"))
		for y in range(46, 56, 3):
			P.p(87, y, Color("c9a046"))
			P.p(92, y, Color("c9a046"))
	_banner(P, o["owner"], 91, 9, 11)
	P.torch(80, 42)
	P.torch(99, 42)
	_palm(P, 12, 58, 16, 1)
	_palm(P, 168, 58, 14, -1)
	_palm(P, 160, 60, 11, 1)
	_visitors(P, o, [[62, 42], [108, 42], [46, 42]])


static func _ryu_roof(P: Painter, x0: float, x1: float, y: float, h: int, L: Dictionary) -> void:
	var c := col("roof", L)
	for i in h:
		var inset := h - 1 - i
		P.r(x0 + inset, y + i, x1 - x0 - inset * 2, 1, col("roofS", L) if i == h - 1 else c)
	P.p(x0 - 1, y + h - 2, c)
	P.p(x1, y + h - 2, c)


static func _ishigaki(P: Painter, x0: int, x1: int, y0: int, y1: int, L: Dictionary) -> void:
	for y in range(y0, y1):
		var inset := roundi((y1 - y) * 0.35)
		P.r(x0 + inset, y, x1 - x0 - inset * 2, 1, col("mortar", L) if y % 3 == 0 else col("stone", L))
		for x in range(x0 + inset + ((y >> 1) % 2) * 2, x1 - inset, 5):
			P.p(x, y, col("stoneS", L))


static func _ryu_castle(P: Painter, o: Dictionary, L: Dictionary) -> void:
	var T := _team(o)
	var plaster := col("plaster", L)
	var pshade := Color("cfc8b8")
	var pane := Color("22202a")
	P.oy = 3
	_ishigaki(P, 54, 88, 28, 38, L)
	P.r(58, 21, 26, 7, plaster)
	P.r(80, 21, 4, 7, pshade)
	for x in range(61, 80, 4):
		P.win(x, 23, 2, 2, pane)
	_ryu_roof(P, 53, 89, 17, 4, L)
	P.tri(66, 76, 13, 17, plaster, pshade)
	P.p(71, 13, col("roofS", L))
	P.r(62, 10, 18, 7, plaster)
	P.r(77, 10, 3, 7, pshade)
	for x in range(64, 77, 4):
		P.win(x, 12, 2, 2, pane)
	_ryu_roof(P, 58, 84, 7, 3, L)
	P.r(65, 3, 12, 4, plaster)
	P.win(68, 4, 2, 2, pane)
	P.win(72, 4, 2, 2, pane)
	_ryu_roof(P, 61, 81, 0, 3, L)
	P.p(61, 0, GOLD)
	P.p(80, 0, GOLD)
	P.oy = 0
	var flags := [[34, 22], [46, 22], [118, 22], [132, 22], [144, 24]]
	for i in (2 if o.get("garrison") == "thin" else 5):
		_small(P, o["owner"], flags[i][0], flags[i][1], 14)
	_guards_on(P, o, [[40, 31], [52, 31], [112, 31], [124, 31], [138, 31]], T)
	_ishigaki(P, 24, 156, 44, 57, L)
	P.r(28, 37, 124, 7, plaster)
	P.r(28, 43, 124, 1, pshade)
	for x in range(32, 150, 8):
		P.r(x, 39, 1, 2, pane)
	P.r(27, 35, 126, 2, col("roof", L))
	P.p(26, 36, col("roof", L))
	P.p(153, 36, col("roof", L))
	for tx in [22, 144]:
		P.r(tx, 28, 14, 9, plaster)
		P.r(tx + 11, 28, 3, 9, pshade)
		P.win(tx + 3, 31, 2, 2, pane)
		P.win(tx + 8, 31, 2, 2, pane)
		_ryu_roof(P, tx - 2, tx + 16, 24, 4, L)
	P.r(78, 28, 24, 9, plaster)
	P.r(98, 28, 4, 9, pshade)
	P.win(82, 31, 3, 2, pane)
	P.win(95, 31, 3, 2, pane)
	_ryu_roof(P, 75, 105, 23, 5, L)
	P.r(80, 37, 20, 20, col("wood", L))
	P.r(80, 37, 20, 2, Color("3a2a22"))
	if o.get("player", "") != "" and o.get("condition") != "besieged":
		P.r(84, 41, 12, 16, Color("1a1418"))
	else:
		P.r(89, 41, 1, 16, Color("2a1e18"))
		for y in range(43, 56, 4):
			for x in range(83, 98, 4):
				P.p(x, y, Color("9a9488"))
	_banner(P, o["owner"], 88, 29)
	P.lanterns.append(Vector2(79, 46))
	P.lanterns.append(Vector2(101, 46))
	_pine(P, 12, 60, 12)
	_pine(P, 168, 60, 10)
	_visitors(P, o, [[64, 45], [108, 45], [50, 45]])


# ---------------------------------------------------------------- towns

## A town's low wall, about a third of a castle's height, with two squat towers at the
## gate. Upper floors and roofs show over it; the street shows through the gate.
static func _town_wall(P: Painter, o: Dictionary, L: Dictionary) -> void:
	var c := String(o.get("culture"))
	var top := 54
	var base := 62
	var gx0 := 84
	var gx1 := 96
	var stone := col("stone", L)
	var span := func(x0: int, x1: int) -> void:
		if c == "ryumon":
			P.r(x0, top + 1, x1 - x0, base - top - 1, col("plaster", L))
			P.r(x0, base - 2, x1 - x0, 2, col("stoneS", L))
			P.r(x0, top - 1, x1 - x0, 2, col("roof", L))
			P.r(x0, top + 1, x1 - x0, 1, col("roofS", L))
			for x in range(x0 + 3, x1 - 1, 7):
				P.r(x, top + 3, 1, 2, Color("22202a"))
		else:
			_stone_wall(P, x0, top, x1 - x0, base - top, L, 7 if c == "kharzani" else 6)
			if c == "kharzani":
				for x in range(x0, x1, 4):
					P.r(x, top - 2, 3, 2, stone)
					P.p(x + 1, top - 3, stone)
			else:
				_merlons(P, x0, x1, top - 2, stone)
	_guards_on(P, o, [[20, top - 5], [52, top - 5], [124, top - 5], [158, top - 5]], _team(o))
	span.call(0, gx0 - 4)
	span.call(gx1 + 4, W)
	for tx in [gx0 - 6, gx1 - 1]:
		if c == "ryumon":
			P.r(tx, top - 3, 7, base - top + 3, col("wood", L))
			P.r(tx + 1, top - 2, 5, 4, col("plaster", L))
			P.r(tx - 1, top - 5, 9, 2, col("roof", L))
		else:
			_stone_wall(P, tx, top - 6, 7, base - top + 6, L)
			P.r(tx + 5, top - 6, 2, base - top + 6, col("stoneS", L))
			if c == "kharzani":
				for x in range(tx, tx + 7, 3):
					P.r(x, top - 8, 2, 2, stone)
					P.p(x, top - 9, stone)
				P.r(tx, top - 3, 7, 1, col("roof", L))
			else:
				_merlons(P, tx, tx + 7, top - 8, stone)
			P.r(tx + 3, top - 2, 1, 3, DARK)
	if c == "ryumon":
		P.r(gx0 - 2, top - 7, gx1 - gx0 + 4, 2, col("roof", L))
		P.r(gx0 - 1, top - 5, gx1 - gx0 + 2, 1, col("roofS", L))
		P.r(gx0, top - 4, gx1 - gx0, 1, col("wood", L))
	elif c == "kharzani":
		P.r(gx0, top - 5, gx1 - gx0, 4, stone)
		for y in 3:
			P.p(gx0 + y, top - 1 + y, stone)
			P.p(gx1 - 1 - y, top - 1 + y, stone)
		P.r(gx0, top - 4, gx1 - gx0, 1, col("roof", L))
	else:
		P.r(gx0, top - 5, gx1 - gx0, 4, stone)
		P.r(gx0, top - 1, 2, 1, stone)
		P.r(gx1 - 2, top - 1, 2, 1, stone)
		_merlons(P, gx0, gx1, top - 7, stone)
	_banner(P, o["owner"], 87, top - 16)
	P.torch(gx0 - 2, top + 2)
	P.torch(gx1 + 1, top + 2)
	if c == "ryumon":
		P.lanterns.append(Vector2(gx0 - 3, top + 1))
		P.lanterns.append(Vector2(gx1 + 2, top + 1))


static func _vard_town(P: Painter, o: Dictionary, L: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var walls := ["e6dcc2", "d9c08e", "e8c8b8", "cfd6c8", "d8b890", "e6dcc2"]
	var roofs := [[col("tile", L), col("tileS", L)], [col("roof", L), col("roofS", L)], [Color("9a5a3c"), Color("6a3a26")], [col("tile", L), col("tileS", L)]]
	var wood := col("wood", L)
	var house := func(x: float, base: float, w: int, h: int, i: int, door: bool, sign: bool) -> void:
		var wall := Color(String(walls[i % walls.size()]))
		var rf: Array = roofs[i % roofs.size()]
		P.r(x, base - h, w, h, wall)
		P.r(x + w - 2, base - h, 2, h, wall.darkened(0.12))
		P.r(x, base - h, 1, h, wood)
		P.r(x + w - 1, base - h, 1, h, wood)
		P.r(x, base - h, w, 1, wood)
		if h > 8:
			P.r(x, base - int(h / 2), w, 1, wood)
			for k in int(h / 2) - 1:
				P.p(x + 1 + k, base - h + 1 + k, wood)
		P.tri(x - 1, x + w, int(base - h - roundi(w * 0.62)), int(base - h), rf[0], rf[1])
		var fy := base - h + 2
		while fy < base - 4:
			for wx in range(int(x) + 2, int(x) + w - 2, 4):
				P.win(wx, fy, 2, 2)
			fy += 5
		if door:
			P.r(x + int(w / 2) - 1, base - 4, 3, 4, Color("4a3324"))
		if sign:
			P.r(x + w, base - 9, 3, 1, wood)
			P.r(x + w + 1, base - 8, 3, 3, GOLD)
	for i in 16:
		var x := 6 + i * 11 + rng.randi_range(0, 2)
		if x > 118 and x < 136:
			continue
		house.call(x, 37, 9, 5, i + 2, false, false)
	P.r(122, 8, 10, 38, col("stone", L))
	P.r(129, 8, 3, 38, col("stoneS", L))
	P.tri(120, 133, -7, 8, col("roof", L), col("roofS", L))
	P.win(125, 14, 2, 3)
	P.win(126, 24, 1, 2)
	P.win(126, 32, 1, 2)
	P.r(125, 4, 3, 3, GOLD)
	for i in 15:
		house.call(2 + i * 12 + rng.randi_range(0, 1), 48, 11, 7, i + 4, false, false)
	var left := [[0, 14], [15, 14], [30, 15], [46, 15], [62, 17]]
	for i in left.size():
		house.call(left[i][0], 59, left[i][1], 11 + (i % 2) * 2, i, true, i == 3)
	var right := [[99, 16], [116, 15], [132, 15], [148, 15], [164, 16]]
	for i in right.size():
		house.call(right[i][0], 59, right[i][1], 12 + ((i + 1) % 2) * 2, i + 3, true, i == 0)
	_town_wall(P, o, L)
	_visitors(P, o, [[46, 40], [136, 40], [16, 40]])


static func _khar_town(P: Painter, o: Dictionary, L: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var tones := [col("plaster", L), col("stone", L), Color("e6c896"), col("plaster", L), Color("d8b480")]
	var block := func(x: float, base: float, w: int, h: int, i: int, front: bool) -> void:
		var c: Color = tones[i % tones.size()]
		P.r(x, base - h, w, h, c)
		P.r(x + w - 2, base - h, 2, h, c.darkened(0.16))
		P.r(x - 1, base - h - 1, w + 2, 1, c.lightened(0.12))
		for xx in range(int(x), int(x) + w, 3):
			P.p(xx, base - h - 2, c)
		P.win(x + 2, base - h + 3, 1, 2)
		if w > 9:
			P.win(x + w - 4, base - h + 3, 1, 2)
		if front:
			_arch(P, x + int(w / 2), base, 4, 6, Color("5a3a24"), true)
			if i % 2 == 0:
				P.r(x + 1, base - 9, w - 2, 1, Color("1f7a6e"))
				for k in range(0, w - 2, 2):
					P.p(x + 1 + k, base - 8, Color("efe6d0"))
			else:
				P.r(x + 2, base - h + 2, 4, 4, Color("7a5232"))
				for k in range(0, 4, 2):
					P.r(x + 2 + k, base - h + 2, 1, 4, Color("5a3a24"))
	var roof := col("roof", L)
	P.r(130, 2, 5, 40, col("plaster", L))
	P.r(133, 2, 2, 40, col("tileS", L))
	P.r(128, 10, 9, 2, col("stoneS", L))
	P.r(128, 22, 9, 2, col("stoneS", L))
	P.dome(132, 2, 3, roof, col("roofS", L))
	P.win(132, 15, 1, 3)
	P.win(132, 28, 1, 3)
	for i in 14:
		var x := 8 + i * 12 + rng.randi_range(0, 2)
		var h := 6 + rng.randi_range(0, 3)
		if x > 124 and x < 138:
			continue
		block.call(x, 36, 10, h, i + 1, false)
	P.r(56, 28, 22, 8, col("plaster", L))
	P.dome(67, 28, 10, roof, col("roofS", L), roof.lightened(0.25))
	P.r(67, 15, 1, 3, GOLD)
	_palm(P, 30, 40, 11, -1)
	_palm(P, 150, 40, 12, 1)
	for i in 15:
		block.call(2 + i * 12 + rng.randi_range(0, 1), 48, 11, 8 + rng.randi_range(0, 2), i + 3, false)
	P.dome(104, 40, 5, col("plaster", L), col("tileS", L))
	P.r(99, 40, 11, 3, col("plaster", L))
	var left := [[0, 15], [16, 15], [32, 15], [48, 16], [65, 15]]
	for i in left.size():
		block.call(left[i][0], 59, left[i][1], 12 + (i % 2) * 2, i, true)
	var right := [[100, 15], [116, 16], [133, 15], [149, 15], [165, 15]]
	for i in right.size():
		block.call(right[i][0], 59, right[i][1], 12 + ((i + 1) % 2) * 2, i + 1, true)
	_banner(P, o["owner"], 136, 9)
	_town_wall(P, o, L)
	_visitors(P, o, [[46, 40], [136, 40], [16, 40]])


static func _ryu_town(P: Painter, o: Dictionary, L: Dictionary) -> void:
	var roof := col("roof", L)
	var roofS := col("roofS", L)
	var plaster := col("plaster", L)
	var wood := col("wood", L)
	var px := 142
	for i in 5:
		var y := 6 + i * 6
		var w := 8 + i * 2
		P.r(px - w / 2.0 + 1, y + 2, w - 2, 4, wood if i == 4 else Color("8a3428"))
		P.r(px - w / 2.0 - 2, y, w + 4, 2, roof)
		P.p(px - w / 2.0 - 3, y - 1, roof)
		P.p(px + w / 2.0 + 2, y - 1, roof)
	P.r(px, 0, 1, 6, GOLD)
	for y in range(1, 6, 2):
		P.r(px - 1, y, 3, 1, GOLD)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var hip := func(x: float, base: float, w: int, h: int, tone: Color) -> void:
		P.r(x, base - h, w, h, tone)
		P.r(x, base - 2, w, 2, wood)
		P.win(x + 2, base - h + 1, 2, 1, Color("22202a"))
		for k in 4:
			var inset := 3 - k
			P.r(x - 1 + inset, base - h - 4 + k, w + 2 - inset * 2, 1, roofS if k == 3 else roof)
		P.tri(x + w / 2.0 - 2, x + w / 2.0 + 2, int(base - h - 6), int(base - h - 3), Color("cfc8b8"))
		P.r(x + w / 2.0 - 3, base - h - 6, 7, 1, roof)
	var tones := [plaster, Color("e3d2a8"), plaster, Color("d8d0c0")]
	for i in 14:
		var x := i * 13 + rng.randi_range(0, 3)
		var w := 9 + rng.randi_range(0, 4)
		var b := 36 + rng.randi_range(0, 1)
		var h := 3 + rng.randi_range(0, 1)
		if x > 130 and x < 152:
			continue
		hip.call(x, b, w, h, tones[i % 4])
	for i in 13:
		var x := i * 14 + 4 + rng.randi_range(0, 3)
		hip.call(x, 44 + rng.randi_range(0, 1), 11 + rng.randi_range(0, 3), 4 + rng.randi_range(0, 1), tones[(i + 1) % 4])
	var machiya := func(x: float, base: float, w: int, h: int, i: int) -> void:
		var low := int(h / 2)
		P.r(x, base - h, w, h - low, plaster)
		P.r(x, base - low, w, low, wood)
		for xx in range(int(x) + 1, int(x) + w, 2):
			P.r(xx, base - low + 1, 1, low - 1, Color("6a4a34"))
		P.r(x - 1, base - low - 1, w + 2, 2, roof)
		P.r(x - 1, base - h - 2, w + 2, 2, roof)
		P.r(x - 1, base - h, w + 2, 1, roofS)
		P.r(x + 2, base - h - 3, w - 4, 1, roofS)
		for k in range(0, w - 4, 3):
			P.win(x + 2 + k, base - h + 2, 2, 1, Color("3a2a22"))
		var noren := [Color("2c3a6a"), Color("efe6d0")] if i % 2 else [Color("efe6d0"), Color("8a2a22")]
		var d := x + int(w / 2) - 3
		for k in 6:
			P.r(d + k, base - low + 1, 1, 3, noren[1 if k % 2 else 0])
		P.r(d, base - low + 4, 6, low - 4, Color("1a1418"))
		if i % 3 == 1:
			P.r(x + w - 3, base - h - 1, 2, 7, Color("6a4a34"))
			P.r(x + w - 3, base - h + 1, 2, 1, Color("efe6d0"))
			P.r(x + w - 3, base - h + 3, 2, 1, Color("efe6d0"))
	var kura := func(x: float, base: float, w: int, h: int) -> void:
		P.r(x, base - h, w, h, plaster)
		P.r(x + w - 2, base - h, 2, h, Color("cfc8b8"))
		P.r(x, base - 4, w, 4, roof)
		for k in range(0, w, 2):
			P.p(x + k, base - 3 + (1 if k % 4 else 0), Color("e8e2d2"))
		P.tri(x - 1, x + w, int(base - h - 5), int(base - h), roof, roofS)
		P.win(x + int(w / 2) - 1, base - h + 3, 2, 2, Color("22202a"))
	var left := [[0, 16, 14], [17, 16, 12], [34, 16, 0], [51, 14, 15], [66, 15, 13]]
	for i in left.size():
		if i == 2: kura.call(left[i][0] + 1, 60, left[i][1] - 2, 13)
		else: machiya.call(left[i][0], 60, left[i][1], left[i][2], i)
	var right := [[99, 15, 13], [115, 16, 15], [132, 16, 12], [149, 14, 0], [164, 16, 14]]
	for i in right.size():
		if i == 3: kura.call(right[i][0] + 1, 60, right[i][1] - 2, 13)
		else: machiya.call(right[i][0], 60, right[i][1], right[i][2], i + 1)
	for x in range(82, 99, 3):
		P.p(x, 44 + (1 if absi(x - 90) < 4 else 0), Color("3a2a22"))
	for x in range(83, 98, 4):
		P.lanterns.append(Vector2(x, 45 + (1 if absi(x - 90) < 4 else 0)))
	_cherry(P, 8, 64, 4)
	_cherry(P, 172, 64, 5)
	_town_wall(P, o, L)
	_visitors(P, o, [[46, 40], [136, 40], [16, 40]])


# ---------------------------------------------------------------- villages

static func _vard_village(P: Painter, o: Dictionary, L: Dictionary) -> void:
	var raided: bool = o.get("condition") == "raided"
	var rec: bool = o.get("condition") == "recovering"
	_fields(P, 0, 44, 70, 8, ["7a6448", "6a563c"] if raided else ["8aaa52", "7a9a46", "d0b662", "c4a858"])
	_fields(P, 112, 44, 68, 8, ["6a563c", "7a6448"] if raided else ["d0b662", "c4a858", "8aaa52", "7a9a46"])
	_oak(P, 24, 46, 5)
	_oak(P, 150, 46, 6)
	_oak(P, 166, 48, 4)
	if _built(o, "granary"):
		_granary(P, o, L)
	var wood := col("wood", L)
	var cottage := func(x: float, base: float, w: int, h: int, i: int) -> void:
		var burnt := raided and i % 2 == 0
		var fresh := rec and i % 2 == 0
		P.r(x, base - h, w, h, Color("6a6058") if burnt else col("plaster", L))
		for xx in range(int(x), int(x) + w, 4):
			P.r(xx, base - h, 1, h, wood)
		P.r(x, base - h, w, 1, wood)
		var rc := Color("2b2426") if burnt else (Color("e3c98a") if fresh else col("thatch", L))
		var rs := Color("1c1719") if burnt else (Color("c9ae6e") if fresh else col("thatchS", L))
		P.tri(x - 2, x + w + 1, int(base - h - 6), int(base - h), rc, rs)
		for yy in range(int(base - h - 4), int(base - h), 2):
			P.r(x, yy, w, 1, Color("3a3030") if burnt else rc.darkened(0.12))
		if burnt:
			for k in range(0, w, 3):
				P.p(x + k, base - h - 2, Color("5a2a1a"))
			P.r(x + 2, base - h - 6, 2, 3, Color("2b2426"))
			P.smoke(x + w / 2.0, base - h - 7, 26, Color("5a5250"), 0.75)
			_embers(P, x, base - h - 1, w)
		else:
			P.r(x + w - 3, base - h - 7, 2, 4, col("stoneS", L))
			if not rec or i % 2:
				P.smoke(x + w - 2, base - h - 8, 8, Color("d8d4d0"), 0.45)
		P.r(x + 2, base - 4, 2, 4, Color("4a3324"))
		P.win(x + w - 4, base - h + 2, 2, 2)
		if fresh:
			P.r(x - 2, base - h - 7, 1, h + 7, Color("a97846"))
			P.r(x + w + 1, base - h - 7, 1, h + 7, Color("a97846"))
			P.r(x - 3, base - h - 2, w + 5, 1, Color("c59555"))
			P.r(x - 3, base - 5, w + 5, 1, Color("c59555"))
	cottage.call(44, 56, 12, 7, 0)
	cottage.call(64, 52, 10, 6, 1)
	cottage.call(110, 53, 11, 6, 2)
	cottage.call(128, 58, 13, 8, 3)
	P.r(96, 58, 7, 4, col("stone", L))
	P.r(96, 58, 7, 1, col("stoneS", L))
	P.r(96, 52, 1, 6, wood)
	P.r(102, 52, 1, 6, wood)
	P.tri(95, 104, 49, 52, col("thatch", L), col("thatchS", L))
	var mill := _built(o, "mill")
	if mill:
		_brook(P)
	if _built(o, "fortifications"):
		_fortifications(P, o, L)
	else:
		for x in range(4, 40, 4):
			if not raided or x % 12:
				P.r(x, 62, 1, 4, wood)
		P.r(4, 63, 14 if raided else 36, 1, Color("8a6a44"))
		var fence_end := 154 if mill else 178
		for x in range(144, fence_end, 4):
			P.r(x, 64, 1, 4, wood)
		P.r(144, 65, fence_end - 144, 1, Color("8a6a44"))
	_banner(P, o["owner"], 30, 48, 10)
	if mill:
		_mill(P, o, L)
	if rec:
		P.r(150, 70, 14, 2, Color("a97846"))
		P.r(151, 68, 12, 2, Color("c59555"))


static func _khar_village(P: Painter, o: Dictionary, L: Dictionary) -> void:
	var raided: bool = o.get("condition") == "raided"
	var rec: bool = o.get("condition") == "recovering"
	_palm(P, 18, 46, 14, 1)
	_palm(P, 28, 45, 11, -1)
	_palm(P, 152, 46, 15, -1)
	_palm(P, 166, 47, 12, 1)
	_palm(P, 140, 45, 10, 1)
	var plot := ["9a7a4a", "8a6a40"] if raided else ["8aaa52", "7a9a46", "6c8c3c"]
	for f in [[2, 50], [22, 50], [2, 58], [22, 58], [142, 52], [160, 52], [142, 60], [160, 60]]:
		_fields(P, f[0], f[1], 17, 6, plot)
	var water := Color("8a7a5a") if raided else Color("70a4b0")
	P.r(0, 56, 42, 2, water)
	P.r(140, 58, 40, 2, water)
	P.r(39, 50, 2, 16, water)
	if _built(o, "granary"):
		_granary(P, o, L)
	var house := func(x: float, base: float, w: int, h: int, i: int) -> void:
		var burnt := raided and i % 2 == 0
		var fresh := rec and i % 2 == 0
		var c := Color("7a6050") if burnt else Color("c99a62")
		var s := Color("4a3a32") if burnt else Color("9c7244")
		P.r(x, base - h, w, h, c)
		P.r(x + w - 2, base - h, 2, h, s)
		P.r(x - 1, base - h - 1, w + 2, 1, c.lightened(0.1))
		for xx in range(int(x), int(x) + w, 3):
			P.p(xx, base - h - 2, c)
		P.r(x + 2, base - 4, 2, 4, Color("3a2a20"))
		P.win(x + w - 5, base - h + 2, 1, 2)
		if burnt:
			P.r(x + 1, base - h - 1, w - 3, 2, Color("2b2426"))
			P.smoke(x + w / 2.0, base - h - 2, 26, Color("5a5250"), 0.75)
			_embers(P, x + 1, base - h, w - 2)
		elif fresh:
			P.r(x - 1, base - h - 5, 1, h + 5, Color("a97846"))
			P.r(x + w, base - h - 5, 1, h + 5, Color("a97846"))
			P.r(x - 2, base - h - 3, w + 4, 1, Color("c59555"))
		else:
			P.r(x + 2, base - h - 3, 3, 2, Color("e8dcc0"))
	house.call(52, 54, 13, 8, 0)
	house.call(68, 51, 10, 7, 1)
	house.call(112, 52, 12, 8, 2)
	house.call(126, 57, 14, 9, 3)
	house.call(46, 60, 10, 6, 1)
	for y in range(60, 66):
		var w := 18 - absi(63 - y) * 3
		P.r(92 - w / 2.0, y, w, 1, water)
	var wood := col("wood", L)
	P.r(98, 52, 1, 9, wood)
	P.r(91, 50, 14, 1, wood)
	P.r(104, 50, 2, 3, Color("7a6a5a"))
	P.r(91, 51, 1, 7, Color("8a7a6a"))
	P.r(90, 58, 3, 2, Color("7a5232"))
	if _built(o, "fortifications"):
		_fortifications(P, o, L)
	_banner(P, o["owner"], 36, 46, 10)
	if _built(o, "mill"):
		_mill(P, o, L)
	if rec:
		P.r(150, 72, 12, 2, Color("c99a62"))
		P.r(151, 70, 10, 2, Color("9c7244"))


static func _ryu_village(P: Painter, o: Dictionary, L: Dictionary) -> void:
	var raided: bool = o.get("condition") == "raided"
	var rec: bool = o.get("condition") == "recovering"
	var paddy := func(x: int, y: int, w: int, h: int) -> void:
		P.r(x, y, w, h, Color("7a6a52") if raided else Color("a8ccd4"))
		P.r(x, y + h, w, 1, Color("6a5a3e"))
		if not raided:
			for yy in range(y, y + h, 2):
				for xx in range(x + 1, x + w, 3):
					P.p(xx, yy, Color("6c9a44"))
			P.r(x + 2, y, mini(6, w - 3), 1, Color("d8eaee"))
	for i in 4:
		paddy.call(0, 44 + i * 6, 44 - i * 4, 5)
		paddy.call(136 + i * 4, 44 + i * 6, 44 - i * 4, 5)
	_cherry(P, 52, 50, 5)
	_cherry(P, 128, 50, 4)
	if _built(o, "granary"):
		_granary(P, o, L)
	var wood := col("wood", L)
	var minka := func(x: float, base: float, w: int, h: int, i: int) -> void:
		var burnt := raided and i % 2 == 0
		var fresh := rec and i % 2 == 0
		P.r(x, base - h, w, h, Color("5a4a40") if burnt else wood)
		P.r(x + 2, base - h + 1, w - 4, h - 3, Color("4a3a30") if burnt else col("plaster", L))
		for xx in range(int(x) + 3, int(x) + w - 2, 3):
			P.r(xx, base - h + 1, 1, h - 3, wood)
		var rc := Color("2b2426") if burnt else (Color("d8be86") if fresh else col("thatch", L))
		var rs := Color("1c1719") if burnt else (Color("b89e66") if fresh else col("thatchS", L))
		for k in 8:
			var inset := maxi(0, 7 - k)
			P.r(x - 2 + inset, base - h - 8 + k, w + 4 - inset * 2, 1, rs if k > 5 else rc)
		P.r(x + 4, base - h - 9, w - 8, 2, Color("1c1719") if burnt else Color("3a3030"))
		if burnt:
			P.smoke(x + w / 2.0, base - h - 9, 26, Color("5a5250"), 0.75)
			_embers(P, x, base - h - 3, w)
		elif fresh:
			P.r(x - 3, base - h - 9, 1, h + 9, Color("a97846"))
			P.r(x + w + 2, base - h - 9, 1, h + 9, Color("a97846"))
			P.r(x - 4, base - h - 4, w + 8, 1, Color("c59555"))
		else:
			P.smoke(x + w / 2.0, base - h - 10, 7, Color("d8d4d0"), 0.4)
		P.r(x + int(w / 2) - 1, base - 4, 3, 4, Color("2a2024"))
	minka.call(60, 56, 16, 7, 0)
	minka.call(102, 54, 14, 7, 1)
	minka.call(80, 50, 12, 6, 2)
	var red := Color("b8352a")
	P.r(86, 60, 1, 8, red)
	P.r(95, 60, 1, 8, red)
	P.r(84, 59, 14, 1, red)
	P.r(83, 58, 16, 1, Color("22202a"))
	P.r(85, 61, 12, 1, red)
	if _built(o, "fortifications"):
		_fortifications(P, o, L)
	_small(P, o["owner"], 46, 52, 14)
	if _built(o, "mill"):
		_mill(P, o, L)
	if rec:
		P.r(146, 72, 12, 2, Color("a97846"))
		P.r(147, 70, 10, 2, Color("c59555"))


# ---------------------------------------------------------------- the lord's improvements

## What the player has built at their own fief, drawn where each kind of place has room
## for it: [x, base] for one building, [x0, x1, base] for a run of wall. The title sits on
## the bottom left of the picture, so nothing new goes there. Towns are never fiefs.
const IMP_AT := {
	"village": {
		"vardish": {"granary": [4, 54], "walls": [[2, 40, 58], [144, 178, 60]], "tower": [82, 64], "mill": [154, 72]},
		"kharzani": {"granary": [2, 53], "walls": [[0, 38, 68]], "tower": [78, 66], "mill": [148, 68]},
		"ryumon": {"granary": [4, 52], "walls": [[2, 26, 68], [136, 146, 70]], "tower": [35, 72], "mill": [148, 72]},
	},
	"castle": {
		"vardish": {"granary": [2, 64], "walls": [[30, 74, 66]], "tower": [40, 70], "mill": [154, 72]},
		"kharzani": {"granary": [2, 64], "walls": [[30, 74, 66]], "tower": [40, 70], "mill": [148, 72]},
		"ryumon": {"granary": [4, 64], "walls": [[30, 74, 66]], "tower": [40, 70], "mill": [148, 74]},
	},
}
const IMP_KEYS := ["granary", "fortifications", "mill"]
## A plate: one improvement alone on a strip of its culture's ground, for the Manor card.
const PLATE_W := 40
const PLATE_H := 30
const PLATE_BG := Color("1a2138")


static func _built(o: Dictionary, key: String) -> bool:
	var imps = o.get("improvements", [])
	return imps is Array and (imps as Array).has(key)


static func _imp_at(o: Dictionary) -> Dictionary:
	var by_kind: Dictionary = IMP_AT.get(String(o.get("kind", "")), {})
	return by_kind.get(String(o.get("culture", "vardish")), by_kind.get("vardish", {}))


## The mill's wheel stops while the place is raided or besieged.
static func _turning(o: Dictionary) -> bool:
	return not String(o.get("condition", "healthy")) in ["raided", "besieged"]


static func _granary(P: Painter, o: Dictionary, L: Dictionary) -> void:
	var at: Array = _imp_at(o).get("granary", [])
	if at.is_empty():
		return
	var x: int = at[0]
	var base: int = at[1]
	match String(o.get("culture")):
		"kharzani": _granary_khar(P, x, base)
		"ryumon": _granary_ryu(P, L, x, base)
		_: _granary_vard(P, L, x, base)
	P.spots["granary"] = [Rect2i(x - 2, base - 19, 23, 20)]


static func _fortifications(P: Painter, o: Dictionary, L: Dictionary) -> void:
	var at := _imp_at(o)
	if not at.has("tower"):
		return
	var culture := String(o.get("culture"))
	var rects: Array = []
	# A run of wall stops short of the mill's brook.
	var stop: int = 999
	if _built(o, "mill"):
		stop = int(at["mill"][0])
	for run in at["walls"]:
		var x0: int = run[0]
		var x1: int = mini(int(run[1]), stop)
		var base: int = run[2]
		match culture:
			"kharzani": _wall_khar(P, x0, x1, base)
			"ryumon": _stakes_ryu(P, x0, x1, base)
			_: _stakes_vard(P, L, x0, x1, base)
		rects.append(Rect2i(x0, base - 10, x1 - x0, 11))
	var tx: int = at["tower"][0]
	var tb: int = at["tower"][1]
	match culture:
		"kharzani": _tower_khar(P, tx, tb)
		"ryumon": _tower_ryu(P, L, tx, tb)
		_: _tower_vard(P, L, o, tx, tb)
	if culture == "vardish" and String(o.get("kind")) == Data.VILLAGE:
		# Two taller stakes either side of the road: the palisade's gate.
		for gx in [86, 94]:
			P.r(gx, tb - 10, 1, 10, col("wood", L))
			P.p(gx, tb - 10, Color("8a6a44"))
	rects.append(Rect2i(tx - 9, tb - 31, 19, 32))
	P.spots["fortifications"] = rects


static func _mill(P: Painter, o: Dictionary, L: Dictionary) -> void:
	var at: Array = _imp_at(o).get("mill", [])
	if at.is_empty():
		return
	var x: int = at[0]
	var base: int = at[1]
	var turning := _turning(o)
	match String(o.get("culture")):
		"kharzani": _mill_khar(P, x, base, turning)
		"ryumon": _mill_ryu(P, L, x, base, turning)
		_: _mill_vard(P, L, x, base, turning)
	P.spots["mill"] = [Rect2i(x - 2, base - 18, 28, 20)]


## A brook down the right edge, widening as it comes forward, for a Vardish mill.
static func _brook(P: Painter) -> void:
	for y in range(50, H):
		var t := (y - 50) / 30.0
		var cx := 177.0 - t * 8.0
		var w := 3.0 + t * 3.0
		P.r(cx - w / 2.0, y, w, 1, Color("6a9ab0"))
		P.p(cx - w / 2.0, y, Color("5a7a60"))
		if y % 3 == 0:
			P.p(cx + (y % 2), y, Color("a8ccd4"))


## A mill wheel's rim and hub. A still painter (a plate) paints the spokes too; the vista
## turns them itself, from `wheels`.
static func _wheel(P: Painter, cx: int, cy: int, rad: int, rim: Color, inner: Color, spoke: Color, turning: bool, step: int = 8) -> void:
	for a in range(0, 360, step):
		P.p(cx + roundi(cos(deg_to_rad(a)) * rad), cy + roundi(sin(deg_to_rad(a)) * rad), rim)
	for a in range(0, 360, 10):
		P.p(cx + roundi(cos(deg_to_rad(a)) * (rad - 1)), cy + roundi(sin(deg_to_rad(a)) * (rad - 1)), inner)
	for a in range(0, 360, 45):
		P.p(cx + roundi(cos(deg_to_rad(a)) * rad), cy + roundi(sin(deg_to_rad(a)) * rad), Color("8a6a44"))
	if P.still:
		for a in [0, 90]:
			for k in range(-rad + 1, rad):
				P.p(cx + roundi(cos(deg_to_rad(a)) * k), cy + roundi(sin(deg_to_rad(a)) * k), spoke)
	else:
		P.wheels.append([cx + P.ox, cy + P.oy, rad, spoke, turning])
	P.p(cx, cy, Color("8a6a44"))


static func _granary_vard(P: Painter, L: Dictionary, x: int, base: int) -> void:
	var stone := col("stone", L)
	var shade := col("stoneS", L)
	var wood := col("wood", L)
	# Staddle stones: a stalk and a wider cap, so rats can't climb in.
	for sx in [x + 1, x + 5, x + 9, x + 13]:
		P.r(sx + 1, base - 2, 1, 2, shade)
		P.r(sx, base - 3, 3, 1, stone)
	P.r(x - 1, base - 4, 18, 1, wood)
	P.r(x, base - 11, 16, 7, Color("7a5a3a"))
	for xx in range(x, x + 16, 3):
		P.r(xx, base - 11, 1, 7, wood)
	P.r(x, base - 11, 16, 1, wood)
	P.r(x + 6, base - 9, 3, 5, DARK)
	P.r(x + 6, base - 6, 3, 1, Color("3a3030"))
	var rc := col("thatch", L)
	P.tri(x - 2, x + 17, base - 17, base - 11, rc, col("thatchS", L))
	for yy in range(base - 15, base - 11, 2):
		P.r(x + 1, yy, 14, 1, rc.darkened(0.12))
	P.r(x + 9, base - 3, 5, 1, Color("8a6a44"))
	P.r(x + 14, base - 2, 2, 2, Color("d0b662"))
	P.p(x + 15, base - 3, Color("c4a858"))


## A domed mud-brick store with a ladder to the hatch at its crown, and sacks at its foot.
static func _granary_khar(P: Painter, x: int, base: int) -> void:
	var c := Color("b98250")
	var s := Color("8a6440")
	P.dome(x + 8, base - 2, 9, c, s, c.lightened(0.12))
	P.r(x - 1, base - 2, 18, 2, c)
	P.r(x + 14, base - 2, 3, 2, s)
	P.r(x + 7, base - 5, 3, 3, DARK)
	P.p(x + 8, base - 12, DARK)
	for yy in range(base - 11, base, 2):
		P.p(x + 13 - floori((base - yy) / 4.0), yy, Color("7a5232"))
	P.r(x + 18, base - 2, 2, 2, Color("d9962b"))
	P.p(x + 19, base - 3, Color("d0b662"))


## A raised kura: plaster walls on posts, a heavy tile roof, a shuttered window.
static func _granary_ryu(P: Painter, L: Dictionary, x: int, base: int) -> void:
	var wood := col("wood", L)
	for px in [x + 1, x + 6, x + 11]:
		P.r(px, base - 3, 1, 3, wood)
	P.r(x - 1, base - 4, 15, 1, wood)
	P.r(x, base - 11, 13, 7, col("plaster", L))
	P.r(x, base - 11, 13, 1, wood)
	P.r(x + 11, base - 11, 2, 7, Color("d8d2c4"))
	P.r(x + 2, base - 9, 3, 3, DARK)
	P.p(x + 3, base - 8, Color("8a8a86"))
	for k in 6:
		var inset := maxi(0, 5 - k)
		P.r(x - 2 + inset, base - 17 + k, 17 - inset * 2, 1, col("tileS", L) if k > 3 else col("tile", L))
	P.r(x + 3, base - 18, 7, 2, Color("262a33"))
	P.r(x + 14, base - 2, 2, 2, Color("b8945a"))


## Sharpened stakes two apart, with two rails.
static func _stakes_vard(P: Painter, L: Dictionary, x0: int, x1: int, base: int) -> void:
	var wood := col("wood", L)
	var i := 0
	for x in range(x0, x1, 2):
		var h := 9 if i % 3 != 0 else 8
		P.r(x, base - h, 1, h, wood)
		P.p(x, base - h, Color("8a6a44"))
		P.p(x, base - h + 1, Color("4a3222"))
		i += 1
	P.r(x0, base - 4, x1 - x0, 1, Color("8a6a44"))
	P.r(x0, base - 7, x1 - x0, 1, Color("6a4e30"))


## A mud-brick wall with a stepped parapet, redder than the sand so it reads.
static func _wall_khar(P: Painter, x0: int, x1: int, base: int) -> void:
	var c := Color("c08a56")
	var s := Color("8a6440")
	P.r(x0, base - 6, x1 - x0, 6, c)
	P.r(x0, base - 2, x1 - x0, 1, s)
	for x in range(x0, x1, 3):
		P.r(x, base - 8, 2, 2, c)
		P.p(x + 1, base - 7, s)
	P.r(x0, base - 6, x1 - x0, 1, Color("dcae78"))


## Bamboo stakes with a rope rail.
static func _stakes_ryu(P: Painter, x0: int, x1: int, base: int) -> void:
	var i := 0
	for x in range(x0, x1, 2):
		var h := 8 if i % 2 != 0 else 7
		P.r(x, base - h, 1, h, Color("a8a060"))
		P.p(x, base - h, Color("d8d2a0"))
		for yy in range(base - h + 2, base, 3):
			P.p(x, yy, Color("7a7440"))
		i += 1
	P.r(x0, base - 5, x1 - x0, 1, Color("6a5a3e"))


## A timber tower on four legs: a railed platform, a slate roof, the watch and a torch.
static func _tower_vard(P: Painter, L: Dictionary, o: Dictionary, x: int, base: int) -> void:
	var wood := col("wood", L)
	for lx in [x - 4, x + 4]:
		P.r(lx, base - 15, 1, 15, wood)
	for i in 12:
		P.p(x - 3 + floori(i * 7 / 11.0), base - 3 - i, Color("4a3222"))
		P.p(x + 3 - floori(i * 7 / 11.0), base - 3 - i, Color("4a3222"))
	P.r(x - 6, base - 16, 13, 1, Color("8a6a44"))
	P.r(x - 6, base - 17, 13, 1, Color("6a4e30"))
	for px in [x - 6, x + 6]:
		P.r(px, base - 21, 1, 4, wood)
	P.r(x - 6, base - 20, 13, 1, Color("8a6a44"))
	for yy in range(base - 15, base, 3):
		P.r(x + 5, yy, 2, 1, Color("a97846"))
	for px in [x - 5, x + 5]:
		P.r(px, base - 25, 1, 5, wood)
	P.tri(x - 8, x + 8, base - 29, base - 25, col("roof", L), col("roofS", L))
	P.p(x, base - 30, GOLD)
	_guard(P, x - 2, base - 24, _team(o) if not o.is_empty() else Color("4a74d1"))
	P.torch(x + 4, base - 24)


## A square brick burj with an arrow slit, its watch on top.
static func _tower_khar(P: Painter, x: int, base: int) -> void:
	var c := Color("c08a56")
	var s := Color("8a6440")
	P.r(x - 4, base - 20, 9, 20, c)
	P.r(x + 3, base - 20, 2, 20, s)
	for mx in range(x - 4, x + 5, 3):
		P.r(mx, base - 22, 2, 2, c)
	P.r(x - 1, base - 9, 3, 4, DARK)
	P.p(x, base - 10, DARK)
	_guard(P, x - 2, base - 27, Color("d9962b"))
	P.torch(x + 3, base - 27)


## A yagura: four posts, a deck with a red rail, a tile roof, a paper lantern.
static func _tower_ryu(P: Painter, L: Dictionary, x: int, base: int) -> void:
	var wood := col("wood", L)
	for lx in [x - 4, x + 4]:
		P.r(lx, base - 16, 1, 16, wood)
	for i in 10:
		P.p(x - 3 + floori(i * 7 / 9.0), base - 3 - i, Color("3a2a24"))
	P.r(x - 6, base - 17, 13, 1, Color("8a6a44"))
	P.r(x - 6, base - 20, 13, 1, Color("b8352a"))
	for px in [x - 6, x + 6]:
		P.r(px, base - 20, 1, 3, Color("b8352a"))
	for px in [x - 5, x + 5]:
		P.r(px, base - 25, 1, 5, wood)
	for k in 5:
		var inset := maxi(0, 4 - k)
		P.r(x - 9 + inset, base - 30 + k, 19 - inset * 2, 1, col("tileS", L) if k > 2 else col("tile", L))
	_guard(P, x - 2, base - 24, Color("b8352a"))
	P.r(x + 4, base - 24, 1, 3, Color("f1ece0"))
	P.p(x + 4, base - 23, Color("ffb84a"))
	P.lanterns.append(Vector2(x + 4 + P.ox, base - 23 + P.oy))


## A stone-footed mill with a slate roof and a lit window, its wheel on the brook.
static func _mill_vard(P: Painter, L: Dictionary, x: int, base: int, turning: bool) -> void:
	var wood := col("wood", L)
	var stone := col("stone", L)
	var shade := col("stoneS", L)
	P.r(x, base - 4, 12, 4, stone)
	P.r(x, base - 4, 12, 1, shade)
	P.r(x, base - 10, 12, 6, col("plaster", L))
	for xx in range(x, x + 12, 4):
		P.r(xx, base - 10, 1, 6, wood)
	P.r(x, base - 10, 12, 1, wood)
	P.tri(x - 2, x + 13, base - 15, base - 10, col("roof", L), col("roofS", L))
	P.r(x + 2, base - 3, 2, 3, Color("4a3324"))
	P.win(x + 8, base - 8, 2, 2)
	P.r(x + 9, base - 16, 2, 4, shade)
	if turning:
		P.smoke(x + 10, base - 17, 8, Color("d8d4d0"), 0.45)
	var cx := x + 16
	var cy := base - 4
	_wheel(P, cx, cy, 6, Color("4a3222"), Color("5a3e28"), Color("6a4e30"), turning)
	P.r(x + 12, cy, 4, 1, wood)
	P.r(x + 13, cy - 8, 8, 1, Color("8a6a44"))
	P.r(x + 20, cy - 9, 1, 2, Color("a8ccd4"))
	if turning:
		for k in range(-3, 4, 2):
			P.p(cx + k, cy + 2, Color("d8eaee"))


## A noria: a tall wheel lifting water from the channel into a raised trough.
static func _mill_khar(P: Painter, x: int, base: int, turning: bool) -> void:
	var c := Color("c99a62")
	var s := Color("9c7244")
	P.r(x, base - 8, 10, 8, c)
	P.r(x + 8, base - 8, 2, 8, s)
	P.r(x - 1, base - 9, 12, 1, c.lightened(0.1))
	P.r(x + 2, base - 3, 2, 3, Color("3a2a20"))
	P.win(x + 5, base - 6, 1, 2)
	P.r(x + 10, base - 6, 1, 6, Color("70a4b0"))
	var cx := x + 17
	var cy := base - 7
	P.r(cx - 9, base - 1, 18, 1, Color("70a4b0"))
	P.r(cx - 9, base - 2, 18, 1, Color("a8ccd4"))
	_wheel(P, cx, cy, 7, Color("7a5232"), Color("e8dcc0"), Color("9c7244"), turning, 6)
	P.r(x + 10, cy - 8, 9, 1, s)


## A small timber mill over the paddy channel, its wheel under the eaves.
static func _mill_ryu(P: Painter, L: Dictionary, x: int, base: int, turning: bool) -> void:
	var wood := col("wood", L)
	P.r(x, base - 9, 12, 9, wood)
	P.r(x + 2, base - 8, 8, 6, col("plaster", L))
	for xx in range(x + 3, x + 10, 3):
		P.r(xx, base - 8, 1, 6, wood)
	for k in 6:
		var inset := maxi(0, 5 - k)
		P.r(x - 2 + inset, base - 15 + k, 16 - inset * 2, 1, col("thatchS", L) if k > 3 else col("thatch", L))
	P.r(x + 5, base - 3, 3, 3, Color("2a2024"))
	P.win(x + 3, base - 6, 1, 2)
	var cx := x + 16
	var cy := base - 4
	P.r(cx - 7, base - 1, 14, 1, Color("a8ccd4"))
	_wheel(P, cx, cy, 5, Color("3a2a24"), Color("4a3a30"), Color("6a5a4a"), turning, 10)
	P.r(x + 12, cy, 4, 1, wood)
	P.r(x + 12, cy - 7, 9, 1, Color("6a5a4a"))


## Everything built at a castle fief, on the open ground either side of the approach.
static func _castle_improvements(P: Painter, o: Dictionary, L: Dictionary) -> void:
	if _built(o, "granary"):
		_granary(P, o, L)
	if _built(o, "mill"):
		if String(o.get("culture")) == "vardish":
			_brook(P)
		_mill(P, o, L)
	if _built(o, "fortifications"):
		_fortifications(P, o, L)


## One improvement alone on a 40 x 30 strip of its culture's ground: in colour when built,
## a grey ghost of itself when it could be.
static func plate(culture: String, key: String, built: bool = true) -> Image:
	var L: Dictionary = LOOK.get(culture, LOOK["vardish"])
	var o := {"culture": culture, "kind": "plate", "owner": Data.realm_of_culture(culture), "condition": "healthy"}
	var thing := Painter.new()
	thing.still = true
	match key:
		"granary":
			match culture:
				"kharzani": _granary_khar(thing, 8, 27)
				"ryumon": _granary_ryu(thing, L, 10, 26)
				_: _granary_vard(thing, L, 8, 26)
		"fortifications":
			match culture:
				"kharzani":
					_wall_khar(thing, 2, 38, 28)
					_tower_khar(thing, 19, 28)
				"ryumon":
					_stakes_ryu(thing, 2, 14, 28)
					_stakes_ryu(thing, 24, 38, 28)
					_tower_ryu(thing, L, 19, 30)
				_:
					_stakes_vard(thing, L, 2, 14, 28)
					_stakes_vard(thing, L, 24, 38, 28)
					_tower_vard(thing, L, o, 19, 30)
		"mill":
			match culture:
				"kharzani": _mill_khar(thing, 5, 27, true)
				"ryumon": _mill_ryu(thing, L, 6, 27, true)
				_: _mill_vard(thing, L, 6, 27, true)
	var img := Image.create_empty(PLATE_W, PLATE_H, false, Image.FORMAT_RGBA8)
	img.fill(PLATE_BG)
	var g1 := col("grass", L)
	var g2 := col("grass2", L)
	for y in range(24, PLATE_H):
		for x in PLATE_W:
			img.set_pixel(x, y, g2 if (x + y) % 3 == 0 else g1)
	var fig := thing.img.get_region(Rect2i(0, 0, PLATE_W, PLATE_H))
	if not built:
		for y in PLATE_H:
			for x in PLATE_W:
				var c := fig.get_pixel(x, y)
				if c.a > 0.0:
					var m := c.r * 0.3 + c.g * 0.59 + c.b * 0.11
					fig.set_pixel(x, y, Color(m * 0.45 + PLATE_BG.r * 0.55, m * 0.45 + PLATE_BG.g * 0.55, m * 0.5 + PLATE_BG.b * 0.5, c.a))
	img.blend_rect(fig, Rect2i(0, 0, PLATE_W, PLATE_H), Vector2i.ZERO)
	return img


# ---------------------------------------------------------------- the foreground

static func _market(P: Painter, o: Dictionary, spots: Array) -> void:
	var rich: bool = o.get("prosperity") == "rich"
	var poor: bool = o.get("prosperity") == "poor"
	var culture := String(o.get("culture"))
	var aw: Array = {"vardish": ["c9473d", "efe6d0"], "kharzani": ["1f7a6e", "efe6d0"], "ryumon": ["2c3a6a", "2c3a6a"]}[culture]
	var goods: Array = {"vardish": ["c9473d", "d0b662", "8aaa52", "e6dcc2"], "kharzani": ["d9962b", "a8261c", "1f7a6e", "ece6d6"], "ryumon": ["d9a944", "6c9a44", "e8e2d2", "b8352a"]}[culture]
	var wood := Color("6e4a2e")
	for i in spots.size():
		var x: int = spots[i][0]
		var y: int = spots[i][1]
		P.r(x, y - 7, 1, 7, wood)
		P.r(x + 13, y - 7, 1, 7, wood)
		for k in 15:
			if poor and k in [4, 5, 11]:
				continue
			P.r(x - 1 + k, y - 10, 1, 3, Color(String(aw[int(k / 2) % 2])))
		if culture == "ryumon":
			P.p(x + 3, y - 7, Color("efe6d0"))
			P.p(x + 10, y - 7, Color("efe6d0"))
		P.r(x, y - 3, 14, 3, wood)
		P.r(x, y - 3, 14, 1, Color("8a5c38"))
		if not poor:
			for k in (12 if rich else 6):
				P.p(x + 1 + k, y - 4 - (k % 2), Color(String(goods[(k + i) % goods.size()])))
		if rich and culture == "kharzani":
			P.r(x + 16, y - 9, 4, 8, Color("a8261c"))
			P.r(x + 17, y - 8, 2, 6, Color("d9962b"))
	if rich:
		var bunting := [Color("c9473d"), GOLD, Color("4a74d1")]
		for x in range(4, 176, 2):
			P.p(x, 58 + roundi(sin(x / 14.0) * 1.5), bunting[(x / 2) % 3])


static func _crowd(P: Painter, o: Dictionary, spots: Array) -> void:
	for s in spots:
		_person(P, String(o.get("culture")), s[0], s[1], s.size() > 2 and s[2], s.size() > 3 and s[3], s[4] if s.size() > 4 else "")


static func _team_map(realm: String) -> Dictionary:
	var t: Array = TEAM.get(realm, TEAM["bandits"])
	return {"T": t[0], "t": t[1], "L": t[2]}


static func _sprite(name: String) -> Array:
	return SpriteData.SPRITES[name]["frames"][0] if SpriteData.SPRITES.has(name) else []


static func _foreground(P: Painter, o: Dictionary, L: Dictionary) -> void:
	var c := String(o.get("culture"))
	var k := String(o.get("kind"))
	var cond := String(o.get("condition"))
	var T := _team(o)
	# The mill takes the right of the picture, so what grazes there moves left of the road.
	var mill := _built(o, "mill")
	if k != Data.VILLAGE:
		if cond != "besieged":
			var poor: bool = o.get("prosperity") == "poor"
			if k == Data.TOWN:
				_market(P, o, [[20, 76], [140, 76]] if poor else [[8, 76], [34, 70], [126, 70], [152, 76]])
				_crowd(P, o, [[58, 76], [120, 72, true, true]] if poor else [[28, 77], [56, 74, true, true], [70, 78, false, false, "basket"], [114, 76, true], [142, 79, false, true], [170, 77, true, true], [88, 66, true], [92, 71, false, true]])
				_gate_guard(P, 99, 67, T)
				if o.get("garrison") != "thin":
					_gate_guard(P, 78, 67, T)
			else:
				_crowd(P, o, [[60, 72, true]] if mill else [[60, 72, true], [128, 74, false, true, "basket"]])
				_gate_guard(P, 99, 62, T)
				if o.get("garrison") != "thin":
					_gate_guard(P, 78, 62, T)
				var bx := 20 if mill else 140
				match c:
					"vardish":
						_beast(P, "sheep", bx, 74 if mill else 70)
						_beast(P, "sheep", bx + 10, 77 if mill else 74, true)
					"kharzani": _beast(P, "camel", 14 if mill else 136, 78 if mill else 72)
					_: _beast(P, "ox", 14 if mill else 140, 78 if mill else 72)
		else:
			var b := String(o.get("besieger", "bandits"))
			var tc: Array = TEAM.get(b, TEAM["bandits"])
			for t in [[6, 76], [26, 70], [150, 74], [132, 68], [164, 66]]:
				P.tri(t[0], t[0] + 12, t[1] - 8, t[1], Color(String(tc[0])), Color(String(tc[1])))
				P.r(t[0] + 5, t[1] - 3, 3, 3, Color("1a1418"))
				P.r(t[0] + 6, t[1] - 11, 1, 3, Color("3a2a1c"))
			P.grid(SpriteData.SPRITES["campfire"]["frames"][0], 48, 70)
			P.fires.append(Vector2(52, 71))
			P.grid(SpriteData.SPRITES["campfire"]["frames"][1], 118, 74)
			P.fires.append(Vector2(122, 75))
			_banner(P, b, 56, 56, 12)
			_banner(P, b, 140, 52, 12)
			var foot := _sprite("follower/" + String(CULTURE_OF_REALM.get(b, "vardish")))
			for s in [[66, 72], [74, 76], [104, 74], [112, 78]]:
				P.grid(foot, s[0], s[1] - 11, _team_map(b))
			if k == Data.CASTLE:
				_ladder(P, 44, 33, 56)
				_ladder(P, 134, 33, 56)
				P.smoke(128, 32, 30, Color("4a4240"), 0.8)
				_embers(P, 124, 34, 6)
				P.r(84, 50, 13, 6, Color("6a4428"))
				P.tri(82, 99, 45, 50, Color("7a5232"), Color("5a3a20"))
				P.r(80, 53, 5, 2, Color("4a3a2a"))
			else:
				P.r(84, 56, 12, 6, Color("6a4428"))
				P.r(85, 54, 5, 2, Color("8a5c32"))
				P.r(91, 53, 4, 3, Color("7a5232"))
				P.p(85, 61, Color("2a2020"))
				P.p(94, 61, Color("2a2020"))
				_ladder(P, 40, 50, 62)
				_ladder(P, 140, 50, 62)
				P.smoke(40, 40, 30, Color("4a4240"), 0.8)
				_embers(P, 34, 44, 10)
	else:
		if cond != "raided":
			match c:
				"vardish":
					if mill:
						_beast(P, "sheep", 50, 72)
						_beast(P, "sheep", 60, 76, true)
						_beast(P, "sheep", 40, 70)
						_beast(P, "hen", 136, 72)
						_beast(P, "hen", 141, 74)
						_crowd(P, o, [[22, 74, false, false, "hoe"], [78, 70, true, true]])
					else:
						_beast(P, "sheep", 150, 74)
						_beast(P, "sheep", 160, 76, true)
						_beast(P, "sheep", 166, 72)
						_beast(P, "hen", 112, 70)
						_beast(P, "hen", 116, 72)
						_crowd(P, o, [[22, 74, false, false, "hoe"], [78, 70, true, true], [120, 76, false, false, "basket"]])
				"kharzani":
					_beast(P, "camel", 44 if mill else 148, 78 if mill else 76, true)
					_beast(P, "goat", 64, 72)
					_beast(P, "goat", 70, 74, true)
					_crowd(P, o, [[16, 76, false, false, "hoe"], [80, 77, true, true]] if mill else [[16, 74, false, false, "hoe"], [108, 74, true, true, "basket"], [124, 72]])
				_:
					_beast(P, "ox", 60 if mill else 150, 78, true)
					_crowd(P, o, [[18, 60, false, false, "hoe"], [64, 76, true]] if mill else [[18, 60, false, false, "hoe"], [150, 56, true, true, "basket"], [122, 74], [64, 76, true]])
		else:
			_crowd(P, o, [[40, 74, true], [130, 76, false, true]])
			P.r(60, 74, 10, 3, Color("4a3a2a"))
			P.p(58, 76, Color("2a2020"))
			P.p(71, 72, Color("2a2020"))
		if cond == "recovering":
			_crowd(P, o, [[56, 72, false, false, "hoe"], [66, 72, true, true]] if mill else [[148, 70, false, false, "hoe"], [162, 70, true, true]])
	# The mill's market stalls, by the road. They stand empty while the place suffers.
	if mill and cond != "besieged" and k != Data.TOWN:
		var stall := o.duplicate()
		stall["prosperity"] = "normal" if cond == "healthy" else "poor"
		_market(P, stall, [[98, 79], [114, 79]])
		if cond == "healthy":
			_crowd(P, o, [[108, 79, true, true]])
	var mine := String(o.get("player", ""))
	if mine != "":
		# Right of the road, clear of a title set on the bottom left.
		var x := 134
		var cul := String(CULTURE_OF_REALM.get(mine, "vardish"))
		var team := _team_map(mine)
		P.grid(_sprite("follower/" + cul), x - 18, 67, team)
		P.grid(_sprite("follower/" + cul), x - 10, 68, team)
		P.grid(_sprite("mounted/" + cul), x, 52, team)


static func _ladder(P: Painter, x: float, top: int, base: int) -> void:
	for y in range(top, base + 1):
		var k := roundi((y - top) * 0.25)
		P.p(x - k, y, Color("8a5c32"))
		P.p(x + 4 - k, y, Color("8a5c32"))
		if (y - top) % 3 == 0:
			P.r(x - k, y, 5, 1, Color("a97846"))
