extends Control
## The company's camp, alive: drawn over the painted camp (assets/locations/company_camp.png,
## 240x160, shown "covered"), it makes the fire burn. Flames lick up from the painted ones,
## a warm light breathes around it, embers rise and drift and go out, smoke curls away, the
## tent lanterns flicker and a few stars twinkle. All in the art's own pixels, so it reads
## as part of the picture. Still under Reduced motion (only the steady glow).
##
## Add it as a child of the TextureRect that shows the camp: CampLife.over(art).

const Style = preload("res://scripts/ui/style.gd")

## Where things stand in the painting, in its pixels.
const ART := Vector2(240, 160)
const FIRE := Vector2(120.5, 87.0)      # the middle of the fire's base
const FIRE_HALF := 8.0                  # half its width
const LANTERNS := [Vector2(57, 88), Vector2(187, 89), Vector2(110, 66), Vector2(207, 62)]
const STARS := [Vector2(47, 1), Vector2(84, 0), Vector2(172, 1), Vector2(103, 2), Vector2(78, 5), Vector2(69, 6),
	Vector2(206, 8), Vector2(72, 9), Vector2(76, 13), Vector2(220, 15), Vector2(2, 16)]

const FLAME := [Color("fff1a8"), Color("ffcf6a"), Color("ff9a3a"), Color("e2553f")]

var _t := 0.0
var _sparks: Array = []
var _smoke: Array = []
var _rng := RandomNumberGenerator.new()
var _still := false


## The camp's life over `art` (a TextureRect showing the camp), filling it.
static func over(art: Control) -> Control:
	var life = load("res://scripts/ui/camp_life.gd").new()
	life.name = "CampLife"
	life.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	life.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.add_child(life)
	return life


func _ready() -> void:
	_rng.seed = 7
	_still = Style.motion_reduced()
	for i in 16:
		_sparks.append(_new_spark(_rng.randf()))
	for i in 7:
		_smoke.append(_new_puff(_rng.randf()))
	set_process(not _still)
	queue_redraw()


func _new_spark(age: float = 0.0) -> Dictionary:
	return {"x": FIRE.x + _rng.randf_range(-FIRE_HALF * 0.7, FIRE_HALF * 0.7), "age": age,
		"life": _rng.randf_range(1.4, 3.2), "rise": _rng.randf_range(10.0, 22.0), "sway": _rng.randf_range(2.0, 6.0),
		"phase": _rng.randf_range(0.0, TAU), "size": 1.0 if _rng.randf() < 0.75 else 2.0}


func _new_puff(age: float = 0.0) -> Dictionary:
	return {"x": FIRE.x + _rng.randf_range(-2.0, 2.0), "age": age, "life": _rng.randf_range(4.0, 6.5),
		"phase": _rng.randf_range(0.0, TAU)}


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	for i in _sparks.size():
		var s: Dictionary = _sparks[i]
		s["age"] = float(s["age"]) + delta / float(s["life"])
		if float(s["age"]) >= 1.0:
			_sparks[i] = _new_spark()
	for i in _smoke.size():
		var p: Dictionary = _smoke[i]
		p["age"] = float(p["age"]) + delta / float(p["life"])
		if float(p["age"]) >= 1.0:
			_smoke[i] = _new_puff()
	queue_redraw()


## The painting's pixel `at` on this control, and one pixel's size: the art covers the
## control, centred, as the TextureRect under it shows it.
func _k() -> float:
	return maxf(size.x / ART.x, size.y / ART.y)


func _to(at: Vector2) -> Vector2:
	var k := _k()
	return (size - ART * k) * 0.5 + at * k


func _px(at: Vector2, colour: Color, w: float = 1.0, h: float = 1.0) -> void:
	var k := _k()
	draw_rect(Rect2(_to(at.floor()), Vector2(w, h) * k), colour)


func _draw() -> void:
	var k := _k()
	# The firelight: warm rings around the fire, breathing as a fire does.
	var breath := 1.0 if _still else 0.82 + 0.12 * sin(_t * 7.3) + 0.06 * sin(_t * 13.1 + 1.3)
	var centre := _to(FIRE + Vector2(0, -4))
	for ring in [[70.0, 0.035], [48.0, 0.05], [30.0, 0.07], [16.0, 0.09]]:
		draw_circle(centre, float(ring[0]) * k * (0.96 + 0.04 * breath), Color(1.0, 0.6, 0.25, float(ring[1]) * breath))
	if _still:
		return
	# Smoke: soft grey puffs that rise, lean with the wind and widen as they thin.
	for p in _smoke:
		var a: float = p["age"]
		var at := Vector2(float(p["x"]) + a * 12.0 + sin(_t * 0.8 + float(p["phase"])) * 1.5, FIRE.y - 14.0 - a * 58.0)
		# A small cluster of grey pixels, a little wider as it rises and fades.
		var shade := Color(0.6, 0.58, 0.66, 0.11 * sin(a * PI))
		var wide := 1.0 + floorf(a * 3.0)
		_px(at, shade, wide, 1.0)
		_px(at + Vector2(-1.0, 1.0), shade, wide + 1.0, 1.0)
		_px(at + Vector2(0.0, 2.0), Color(shade, shade.a * 0.6), wide, 1.0)
	# Flames: tongues that leap and fall over the painted fire, a new shape every tenth of a second.
	var beat := int(_t * 10.0)
	var lick := RandomNumberGenerator.new()
	for i in 9:
		lick.seed = beat * 31 + i * 7
		var x := FIRE.x - FIRE_HALF + 1.0 + i * (FIRE_HALF * 2.0 - 2.0) / 8.0
		var centred := 1.0 - absf(x - FIRE.x) / FIRE_HALF
		var tall := roundf((3.0 + centred * 9.0) * lick.randf_range(0.55, 1.15))
		for j in int(tall):
			var f := float(j) / maxf(1.0, tall)
			var c: Color = FLAME[mini(3, int((1.0 - f) * 2.2 + lick.randf_range(0.0, 1.2)))]
			c.a = 0.95 - f * 0.45
			_px(Vector2(x, FIRE.y - 3.0 - j), c)
		# A lick that breaks off the top now and then.
		if lick.randf() < 0.3:
			_px(Vector2(x + lick.randf_range(-1.0, 1.0), FIRE.y - 5.0 - tall - lick.randf_range(1.0, 3.0)), Color(FLAME[1], 0.8))
	# Embers: sparks rising and drifting, bright, then going out.
	for s in _sparks:
		var a: float = s["age"]
		var at := Vector2(float(s["x"]) + sin(_t * 2.0 + float(s["phase"])) * float(s["sway"]) * a,
			FIRE.y - 8.0 - a * float(s["rise"]) * float(s["life"]))
		var glow := (1.0 - a) * (0.6 + 0.4 * sin(_t * 17.0 + float(s["phase"])))
		_px(at, Color(1.0, lerpf(0.85, 0.45, a), lerpf(0.4, 0.15, a), glow), float(s["size"]), float(s["size"]))
	# The tents' lanterns flicker.
	for i in LANTERNS.size():
		var l: Vector2 = LANTERNS[i]
		var on := 0.10 + 0.07 * sin(_t * (5.0 + i) + i * 1.7) + 0.04 * sin(_t * 11.0 + i)
		draw_circle(_to(l), 4.5 * k, Color(1.0, 0.72, 0.35, on))
	# A few stars twinkle.
	for i in STARS.size():
		var tw := 0.5 + 0.5 * sin(_t * (1.1 + 0.37 * i) + i * 2.1)
		if tw > 0.75:
			_px(STARS[i], Color(1.0, 1.0, 0.92, (tw - 0.75) * 2.4))
