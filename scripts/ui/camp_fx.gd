## The life laid over the camp picture: the lanterns and the cook fire glowing, embers and
## smoke rising from the pot, stars at night, and rain or snow. It follows the picture it
## lies on (`art`, a TextureRect drawn covering its box), so a picture that drifts as the
## page scrolls takes its fire with it. Everything here is cosmetic: the weather comes from
## a stable hash of the place and the day, never the campaign's dice. Under Reduced motion
## it is drawn once and holds still.
extends Control

const Style = preload("res://scripts/ui/style.gd")
const Heraldry = preload("res://scripts/ui/heraldry.gd")
const WorldData = preload("res://scripts/world/world_data.gd")
const WAVE_SHADER := "res://shaders/banner_wave.gdshader"

## Where the fire is in the picture (assets/locations/company_camp.png, 768 by 512): the
## cook pot, and each lantern with the reach of its glow.
const ART_SIZE := Vector2(768, 512)
const POT := Vector2(413, 350)
const LANTERNS := [[Vector2(297, 292), 30.0], [Vector2(461, 275), 24.0], [Vector2(640, 238), 40.0]]
## The open sky, where the stars come out.
const SKY := Rect2(10, 150, 510, 28)
## One day in this many is wet.
const WET_IN := 100
const WET_BELOW := 18

## "night", "dusk" or "day".
var light := "night"
## "clear", "rain" or "snow".
var weather := "clear"
var art: TextureRect

var _t := 0.0
var _embers: Array = []
var _smoke: Array = []
var _drops: Array = []
var _stars: Array = []
var _ember_wait := 0.0
var _smoke_wait := 0.0
var _rng := RandomNumberGenerator.new()


## The light at an hour of the map: night and blue, dusk and dawn warm, or day.
static func light_for(hour: float) -> String:
	var h := int(hour) % 24
	if h < 5 or h >= 21:
		return "night"
	if h < 8 or h >= 18:
		return "dusk"
	return "day"


## The weather at `place` on `day`: a stable hash, so it is the same every time you look
## and costs the campaign nothing. Wet days in Ryumon's mountains bring snow.
static func weather_for(place: String, day: int) -> String:
	if place == "":
		return "clear"
	if absi(hash("%s|%d" % [place, day])) % WET_IN >= WET_BELOW:
		return "clear"
	var home := String(WorldData.settlement(place).get("faction", "")) if WorldData.SETTLEMENTS.has(place) else ""
	return "snow" if home == "ryumon" else "rain"


func _ready() -> void:
	name = "CampFx"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = add
	_rng.seed = 7
	for i in 26:
		_stars.append({"at": Vector2(SKY.position.x + _rng.randf() * SKY.size.x, SKY.position.y + _rng.randf() * SKY.size.y),
			"phase": _rng.randf() * TAU, "speed": 0.6 + _rng.randf() * 1.6, "big": _rng.randf() < 0.25})
	_rng.randomize()
	for i in 70:
		_drops.append({"x": _rng.randf(), "y": _rng.randf(), "v": 0.7 + _rng.randf() * 0.6, "phase": _rng.randf() * TAU})
	set_process(not Style.motion_reduced())
	resized.connect(queue_redraw)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	delta = minf(delta, 0.05)
	_t += delta
	var k := _scale()
	var pot := _at(POT)
	_ember_wait += delta
	while _ember_wait > 0.07:
		_ember_wait -= 0.07
		_embers.append({"p": pot + Vector2(_rng.randf_range(-8.0, 8.0), 6.0) * k, "vy": -_rng.randf_range(20.0, 46.0) * k,
			"phase": _rng.randf() * TAU, "life": 0.0, "max": _rng.randf_range(2.2, 3.8)})
	for i in range(_embers.size() - 1, -1, -1):
		var e: Dictionary = _embers[i]
		e["life"] = float(e["life"]) + delta
		if float(e["life"]) > float(e["max"]):
			_embers.remove_at(i)
			continue
		var p: Vector2 = e["p"]
		e["p"] = p + Vector2(sin(float(e["phase"]) + float(e["life"]) * 3.0) * 10.0 + 4.0, float(e["vy"])) * delta
	_smoke_wait += delta
	if _smoke_wait > 0.55:
		_smoke_wait = 0.0
		_smoke.append({"p": pot + Vector2(2.0, -10.0) * k, "life": 0.0, "max": 6.5, "phase": _rng.randf() * TAU})
	for i in range(_smoke.size() - 1, -1, -1):
		var m: Dictionary = _smoke[i]
		m["life"] = float(m["life"]) + delta
		if float(m["life"]) > float(m["max"]):
			_smoke.remove_at(i)
			continue
		var p: Vector2 = m["p"]
		m["p"] = p + Vector2(5.0 + sin(float(m["phase"]) + float(m["life"])) * 4.0, -9.0) * k * delta
	for d in _drops:
		if weather == "rain":
			d["y"] = float(d["y"]) + 2.2 * float(d["v"]) * delta
			d["x"] = float(d["x"]) - 0.2 * float(d["v"]) * delta
		elif weather == "snow":
			d["y"] = float(d["y"]) + 0.14 * float(d["v"]) * delta
			d["x"] = float(d["x"]) + sin(float(d["phase"]) + _t * 1.3) * 0.018 * delta
		if float(d["y"]) > 1.05:
			d["y"] = -0.05
			d["x"] = _rng.randf() * 1.1
	queue_redraw()


## How big one picture pixel is here, and where a picture pixel lands.
func _scale() -> float:
	var r := _art_rect()
	return maxf(r.size.x / ART_SIZE.x, r.size.y / ART_SIZE.y)


func _at(px: Vector2) -> Vector2:
	var r := _art_rect()
	var s := _scale()
	return r.position + (r.size - ART_SIZE * s) * 0.5 + px * s


func _art_rect() -> Rect2:
	if art != null and is_instance_valid(art):
		return Rect2(art.position - position, art.size)
	return Rect2(Vector2.ZERO, size)


func _draw() -> void:
	var live := not Style.motion_reduced()
	var k := _scale()
	if light == "night" and weather == "clear":
		for s in _stars:
			var a := 0.45 + 0.4 * sin(_t * float(s["speed"]) + float(s["phase"])) if live else 0.6
			var side := 2.0 if bool(s["big"]) else 1.4
			draw_rect(Rect2(_at(s["at"]), Vector2(side, side)), Color(0.91, 0.93, 1.0, maxf(0.08, a)))
	var dim := 0.45 if light == "day" else 1.0
	# Glows: rings of low light, brightest at the middle where they overlap.
	for i in LANTERNS.size():
		var l: Array = LANTERNS[i]
		var breath := (sin(_t * 6.1 + i * 2.0) + sin(_t * 13.7 + i)) * 0.5 if live else 0.0
		_glow(_at(l[0]), float(l[1]) * k / 0.854 * (1.0 + 0.1 * breath), Color(1.0, 0.75, 0.35), 0.42 * dim)
	_glow(_at(POT) + Vector2(0, 8) * k, (34.0 + (4.0 * sin(_t * 9.0) if live else 0.0)) * k / 0.854, Color(1.0, 0.63, 0.24), 0.5 * dim)
	for e in _embers:
		var f := 1.0 - float(e["life"]) / float(e["max"])
		draw_rect(Rect2(e["p"], Vector2(2.5, 2.5)), Color(1.0, (120.0 + 90.0 * f) / 255.0, 0.24, f * 0.95))
	for m in _smoke:
		var q := float(m["life"]) / float(m["max"])
		draw_circle(m["p"], (4.0 + q * 13.0) * k / 0.854, Color(0.77, 0.8, 0.9, 0.06 * sin(q * PI)))
	if weather == "rain":
		for d in _drops:
			var p := Vector2(float(d["x"]) * size.x, float(d["y"]) * size.y)
			draw_line(p, p + Vector2(-3.4, 11.0), Color(0.69, 0.77, 1.0, 0.32), 1.2)
	elif weather == "snow":
		for d in _drops:
			var side := 2.4 if float(d["v"]) > 1.0 else 1.6
			draw_rect(Rect2(Vector2(float(d["x"]) * size.x, float(d["y"]) * size.y), Vector2(side, side)), Color(1, 1, 1, 0.75))


func _glow(at: Vector2, r: float, color: Color, strength: float) -> void:
	var rings := 6
	for i in rings:
		draw_circle(at, r * (1.0 - float(i) / rings), Color(color, strength / rings * 0.9))


## A realm's banner on its pole, `size` big, its cloth moving in the wind: drawn once into a
## texture that a wave shader ripples. Under Reduced motion the cloth is drawn flat.
static func waving_banner(realm: String, size: Vector2) -> Control:
	if not Heraldry.REALM_SIZES.has(realm):
		realm = "bandits"
	var root := Control.new()
	root.name = "CompanyBanner"
	root.custom_minimum_size = size
	root.size = size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_meta("realm", realm)
	var box := Rect2(Vector2.ZERO, size)
	var cloth := Heraldry.cloth_rect(realm, box, true)
	var pole := Control.new()
	pole.name = "Pole"
	pole.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pole.size = size
	pole.draw.connect(func(): Heraldry.realm_pole(pole, realm, box))
	root.add_child(pole)
	if Style.motion_reduced():
		var flat := Control.new()
		flat.name = "BannerCloth"
		flat.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flat.size = size
		flat.draw.connect(func(): Heraldry.realm_cloth(flat, realm, cloth))
		root.add_child(flat)
		return root
	# The cloth at twice its size, with room around it to swing into.
	var pad := cloth.size * 0.14
	var whole := cloth.size + pad * 2.0
	var vp := SubViewport.new()
	vp.name = "ClothViewport"
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.size = Vector2i(ceili(whole.x * 2.0), ceili(whole.y * 2.0))
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var painter := Control.new()
	painter.size = Vector2(vp.size)
	painter.draw.connect(func():
		Heraldry.realm_cloth(painter, realm, Rect2(pad, cloth.size), Transform2D(0.0, Vector2(2.0, 2.0), 0.0, Vector2.ZERO)))
	vp.add_child(painter)
	root.add_child(vp)
	var tex := TextureRect.new()
	tex.name = "BannerCloth"
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex.texture = vp.get_texture()
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_SCALE
	tex.position = cloth.position - pad
	tex.size = whole
	var mat := ShaderMaterial.new()
	mat.shader = load(WAVE_SHADER)
	# A gonfalon hangs from its crossbar and swings sideways; a nobori, held top and side,
	# barely stirs; the rest stream from their staff.
	var hung := realm == "vardmark"
	mat.set_shader_parameter("held", 1 if hung else 0)
	mat.set_shader_parameter("margin", (pad.y / whole.y) if hung else (pad.x / whole.x))
	var swing := 0.05 if realm == "ryumon" else (0.07 if hung else 0.11)
	mat.set_shader_parameter("amp", swing * (cloth.size.x / whole.x if hung else cloth.size.y / whole.y))
	mat.set_shader_parameter("folds", 5.0 if hung else 7.0)
	tex.material = mat
	root.add_child(tex)
	return root
