extends Control
## A hall at a gathering, alive: drawn over the hall HallScene paints (240x150, shown
## "covered"), in the art's own pixels so it reads as part of the picture.
##
## - Vardish great hall: the hearth burns, embers lift in its mouth, the wall torches
##   flicker, and stars wink in the tall windows.
## - Kharzani courtyard: the lanterns breathe on their chains, a brazier burns with a curl
##   of incense smoke, fireflies drift in the garden and stars show over the arches.
## - Ryumon audience hall: the paper lanterns glow, a candle burns on each low table,
##   petals drift down, and the moon is a pale disc behind the screens.
##
## Every hall gets a slow warm breath of light. Under Reduced motion only the steady glow
## is drawn. Add it as a child of the TextureRect that shows the hall: HallLife.over(art, culture).

const Style = preload("res://scripts/ui/style.gd")

const ART := Vector2(240, 150)
const FLAME := [Color("fff1a8"), Color("ffcf6a"), Color("ff9a3a"), Color("e2553f")]

## Where things stand in each painting, in its pixels (see hall_scene.gd).
const VARDISH := {
	"fires": [{"at": Vector2(214.0, 99.0), "half": 10.0, "tall": 13.0, "embers": 12, "rise": 20.0, "smoke": false}],
	"torches": [Vector2(22, 60), Vector2(218, 60), Vector2(98, 64), Vector2(142, 64)],
	"glows": [[Vector2(214, 90), 40.0, 0.07]],
	"stars": [Vector2(40, 20), Vector2(44, 30), Vector2(50, 45), Vector2(41, 52), Vector2(52, 24),
		Vector2(188, 22), Vector2(196, 40), Vector2(199, 28), Vector2(190, 50), Vector2(194, 16)],
}
const KHARZANI := {
	"fires": [{"at": Vector2(120.0, 92.0), "half": 4.0, "tall": 8.0, "embers": 8, "rise": 26.0, "smoke": true}],
	"lanterns": [Vector2(30, 28), Vector2(90, 28), Vector2(150, 28), Vector2(210, 28)],
	"glows": [[Vector2(120, 88), 26.0, 0.08]],
	"stars": [Vector2(22, 30), Vector2(36, 26), Vector2(29, 40), Vector2(84, 28), Vector2(98, 36), Vector2(90, 48),
		Vector2(142, 27), Vector2(158, 34), Vector2(150, 44), Vector2(204, 30), Vector2(218, 38), Vector2(210, 52)],
	"fireflies": [Rect2(16, 72, 28, 26), Rect2(76, 72, 28, 26), Rect2(136, 72, 28, 26), Rect2(196, 72, 28, 26)],
}
const RYUMON := {
	"paper": [Vector2(40, 29), Vector2(200, 29)],
	"candles": [Vector2(42, 113), Vector2(102, 113), Vector2(162, 113), Vector2(212, 113)],
	"moon": [Vector2(180, 40), 12.0],
	"glows": [],
	"petals": 14,
}

var culture := "vardish"
var _t := 0.0
var _rng := RandomNumberGenerator.new()
var _still := false
var _sparks: Array = []      # [fire index, spark]
var _smoke: Array = []
var _petals: Array = []
var _flies: Array = []


## The hall's life over `art` (a TextureRect showing HallScene's hall), filling it.
static func over(art: Control, culture_id: String) -> Control:
	var life = load("res://scripts/ui/hall_life.gd").new()
	life.name = "HallLife"
	life.culture = culture_id
	life.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	life.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.add_child(life)
	return life


func _spots() -> Dictionary:
	match culture:
		"kharzani":
			return KHARZANI
		"ryumon":
			return RYUMON
	return VARDISH


func _ready() -> void:
	_rng.seed = hash(culture)
	_still = Style.motion_reduced()
	var spots := _spots()
	var fires: Array = spots.get("fires", [])
	for fi in fires.size():
		for i in int(fires[fi]["embers"]):
			_sparks.append([fi, _new_spark(fires[fi], _rng.randf())])
		if bool(fires[fi]["smoke"]):
			for i in 6:
				_smoke.append(_new_puff(fires[fi], _rng.randf()))
	for i in int(spots.get("petals", 0)):
		_petals.append(_new_petal(_rng.randf()))
	for r in spots.get("fireflies", []):
		for i in 2:
			_flies.append({"box": r, "phase": _rng.randf_range(0.0, TAU), "speed": _rng.randf_range(0.3, 0.7), "blink": _rng.randf_range(0.0, TAU)})
	set_process(not _still)
	queue_redraw()


func _new_spark(fire: Dictionary, age: float = 0.0) -> Dictionary:
	var half: float = fire["half"]
	return {"x": float(fire["at"].x) + _rng.randf_range(-half * 0.7, half * 0.7), "age": age,
		"life": _rng.randf_range(1.2, 2.6), "rise": float(fire["rise"]) * _rng.randf_range(0.6, 1.0),
		"sway": _rng.randf_range(1.5, 4.0), "phase": _rng.randf_range(0.0, TAU)}


func _new_puff(fire: Dictionary, age: float = 0.0) -> Dictionary:
	return {"x": float(fire["at"].x) + _rng.randf_range(-1.0, 1.0), "base": float(fire["at"].y), "age": age,
		"life": _rng.randf_range(4.0, 6.0), "phase": _rng.randf_range(0.0, TAU)}


func _new_petal(age: float = 0.0) -> Dictionary:
	return {"x": _rng.randf_range(-20.0, ART.x), "age": age, "life": _rng.randf_range(7.0, 11.0),
		"drift": _rng.randf_range(18.0, 34.0), "phase": _rng.randf_range(0.0, TAU),
		"tone": Color("f6cdd9") if _rng.randf() < 0.6 else Color("e88aa0")}


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	var fires: Array = _spots().get("fires", [])
	for s in _sparks:
		var spark: Dictionary = s[1]
		spark["age"] = float(spark["age"]) + delta / float(spark["life"])
		if float(spark["age"]) >= 1.0:
			s[1] = _new_spark(fires[int(s[0])])
	for i in _smoke.size():
		var p: Dictionary = _smoke[i]
		p["age"] = float(p["age"]) + delta / float(p["life"])
		if float(p["age"]) >= 1.0:
			_smoke[i] = _new_puff(fires[0])
	for i in _petals.size():
		var p: Dictionary = _petals[i]
		p["age"] = float(p["age"]) + delta / float(p["life"])
		if float(p["age"]) >= 1.0:
			_petals[i] = _new_petal()
	queue_redraw()


## The painting's pixel `at` on this control: the art covers the control, centred, as the
## TextureRect under it shows it.
func _k() -> float:
	return maxf(size.x / ART.x, size.y / ART.y)


func _to(at: Vector2) -> Vector2:
	var k := _k()
	return (size - ART * k) * 0.5 + at * k


func _px(at: Vector2, colour: Color, w: float = 1.0, h: float = 1.0) -> void:
	draw_rect(Rect2(_to(at.floor()), Vector2(w, h) * _k()), colour)


func _draw() -> void:
	var k := _k()
	var spots := _spots()
	# The hall's warm breath: every source of light glows a little brighter, then less.
	var breath := 1.0 if _still else 0.85 + 0.1 * sin(_t * 2.1) + 0.05 * sin(_t * 5.3 + 0.7)
	for g in spots.get("glows", []):
		var centre := _to(g[0])
		for ring in [[1.0, 0.5], [0.7, 0.75], [0.45, 1.0]]:
			draw_circle(centre, float(g[1]) * float(ring[0]) * k, Color(1.0, 0.62, 0.28, float(g[2]) * float(ring[1]) * breath))
	for l in spots.get("lanterns", []):
		var on := 1.0 if _still else 0.75 + 0.15 * sin(_t * 3.1 + l.x * 0.07) + 0.1 * sin(_t * 7.7 + l.x)
		draw_circle(_to(l), 14.0 * k, Color(1.0, 0.72, 0.32, 0.07 * on))
		draw_circle(_to(l), 7.0 * k, Color(1.0, 0.8, 0.4, 0.1 * on))
	for l in spots.get("paper", []):
		var on := 1.0 if _still else 0.8 + 0.12 * sin(_t * 1.7 + l.x * 0.05) + 0.08 * sin(_t * 4.3 + l.x)
		draw_circle(_to(l), 16.0 * k, Color(1.0, 0.85, 0.5, 0.07 * on))
		draw_circle(_to(l), 8.0 * k, Color(1.0, 0.92, 0.65, 0.1 * on))
	if spots.has("moon"):
		var m: Array = spots["moon"]
		draw_circle(_to(m[0]), float(m[1]) * 1.8 * k, Color(1.0, 0.98, 0.88, 0.05))
		draw_circle(_to(m[0]), float(m[1]) * k, Color(1.0, 0.98, 0.9, 0.12))
	for c in spots.get("candles", []):
		_px(c + Vector2(0, -1), Color("ece5d3"), 1.0, 2.0)
		draw_circle(_to(c + Vector2(0.5, -3.0)), 5.0 * k, Color(1.0, 0.75, 0.35, 0.10 * breath))
	if _still:
		return
	var beat := int(_t * 10.0)
	var lick := RandomNumberGenerator.new()
	# Fires: tongues that leap and fall, a new shape every tenth of a second.
	var fires: Array = spots.get("fires", [])
	for fi in fires.size():
		var f: Dictionary = fires[fi]
		var base: Vector2 = f["at"]
		var half: float = f["half"]
		var cols := int(half * 2.0) - 1
		for i in cols:
			lick.seed = beat * 31 + i * 7 + fi * 101
			var x := base.x - half + 1.0 + i
			var centred := 1.0 - absf(x - base.x) / half
			var tall := roundf((2.0 + centred * float(f["tall"])) * lick.randf_range(0.55, 1.15))
			for j in int(tall):
				var fr := float(j) / maxf(1.0, tall)
				var c: Color = FLAME[mini(3, int((1.0 - fr) * 2.2 + lick.randf_range(0.0, 1.2)))]
				c.a = 0.95 - fr * 0.45
				_px(Vector2(x, base.y - 2.0 - j), c)
			if lick.randf() < 0.25:
				_px(Vector2(x, base.y - 4.0 - tall - lick.randf_range(1.0, 3.0)), Color(FLAME[1], 0.8))
	# Embers: rising, drifting, going out.
	for s in _sparks:
		var spark: Dictionary = s[1]
		var f: Dictionary = fires[int(s[0])]
		var a: float = spark["age"]
		var at := Vector2(float(spark["x"]) + sin(_t * 2.0 + float(spark["phase"])) * float(spark["sway"]) * a,
			float(f["at"].y) - 6.0 - a * float(spark["rise"]))
		var glow := (1.0 - a) * (0.6 + 0.4 * sin(_t * 17.0 + float(spark["phase"])))
		_px(at, Color(1.0, lerpf(0.85, 0.45, a), lerpf(0.4, 0.15, a), glow))
	# Incense: a thin grey curl.
	for p in _smoke:
		var a: float = p["age"]
		var at := Vector2(float(p["x"]) + sin(_t * 0.9 + float(p["phase"]) + a * 4.0) * 2.5 * a, float(p["base"]) - 10.0 - a * 44.0)
		var shade := Color(0.85, 0.82, 0.88, 0.16 * sin(a * PI))
		_px(at, shade, 1.0 + floorf(a * 2.0), 1.0)
		_px(at + Vector2(0, 1), Color(shade, shade.a * 0.6), 1.0, 1.0)
	# Torches flicker: a short flame on each and a breathing pool of light.
	for i in spots.get("torches", []).size():
		var tch: Vector2 = spots["torches"][i]
		lick.seed = beat * 13 + i * 5
		var on := 0.75 + 0.25 * sin(_t * (6.0 + i) + i * 1.7)
		draw_circle(_to(tch + Vector2(0.5, -3.0)), 12.0 * k, Color(1.0, 0.7, 0.3, 0.07 * on))
		for dx in [-1, 0, 1, 2]:
			var tall := lick.randi_range(1, 4) - absi(dx - 0) / 2
			for j in tall:
				_px(Vector2(tch.x + dx, tch.y - 2.0 - j), Color(FLAME[mini(3, j)], 0.9 - j * 0.15))
	# Stars twinkle.
	var stars: Array = spots.get("stars", [])
	for i in stars.size():
		var tw := 0.5 + 0.5 * sin(_t * (1.1 + 0.37 * i) + i * 2.1)
		if tw > 0.7:
			_px(stars[i], Color(1.0, 1.0, 0.92, (tw - 0.7) * 2.6))
	# Fireflies wander the garden, glowing on and off.
	for fl in _flies:
		var box: Rect2 = fl["box"]
		var ph: float = fl["phase"]
		var sp: float = fl["speed"]
		var at := box.position + Vector2((0.5 + 0.45 * sin(_t * sp + ph)) * box.size.x, (0.5 + 0.45 * sin(_t * sp * 1.3 + ph * 2.0)) * box.size.y)
		var b := 0.5 + 0.5 * sin(_t * 2.3 + float(fl["blink"]))
		if b > 0.35:
			_px(at, Color(0.85, 1.0, 0.45, (b - 0.35) * 1.3))
	# Petals drift down and across.
	for p in _petals:
		var a: float = p["age"]
		var at := Vector2(float(p["x"]) + a * float(p["drift"]) + sin(_t * 1.3 + float(p["phase"])) * 3.0, -4.0 + a * (ART.y + 8.0))
		var col: Color = p["tone"]
		col.a = 0.85 * minf(1.0, (1.0 - a) * 4.0)
		_px(at, col, 2.0 if sin(_t * 3.0 + float(p["phase"])) > 0.0 else 1.0, 1.0)
