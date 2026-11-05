## The opening: night on a ridge with the three realms' banners, dawn coming up behind
## them, and the title rising into its place on Home. Its first frame is the boot splash
## (assets/splash.png is a render of it), so the engine's still hands over without a jump.
## Plays once a launch, over Home; a tap hurries it on; off when motion is reduced.
extends Control

const Style = preload("res://scripts/ui/style.gd")
const Heraldry = preload("res://scripts/ui/heraldry.gd")

signal finished

## The frame the splash is drawn for (a 9:19.5 phone at the 720-wide canvas). It is fitted
## to the screen and centred the way the engine fits the splash image, so frame 0 matches
## it on any shape of screen.
const BOX := Vector2(720.0, 1561.0)
## Seconds: the land drops away, the title rises, the night lifts off Home.
const LAND_GOES := Vector2(1.35, 1.95)
const TITLE_RISES := Vector2(1.55, 2.25)
const NIGHT_LIFTS := Vector2(1.95, 2.75)
const LENGTH := 2.75
## The title on the splash, in the display face at this size.
const SPLASH_TITLE := 92
## A tap hurries the rest along at this pace.
const HURRY := 3.0
const NIGHT := Color("0e1322")
const RIDGE := Color("080b15")
const DAWN_LOW := Color("e9a04e")
const DAWN_MID := Color("8a4f5e")
## Kharzan, Vardmark and Ryumon on the ridge, in the box (the ridge is at RIDGE_AT).
const RIDGE_AT := 0.6
const BANNERS := [["kharzan", Rect2(170, -215, 125, 230)], ["vardmark", Rect2(302, -300, 116, 316)], ["ryumon", Rect2(436, -245, 100, 260)]]

## Whether the opening has played this launch.
static var played := false

var t := 0.0
var rate := 1.0
var home_title: Label
var title: Label
var _glint_clip: Control
var _glint: Label
var _stage: Control
var _land: Control
var _banners: Array = []
var _stars: Array = []
var _done := false


class Banner extends Control:
	var realm := ""
	var sway := 0.0
	func _draw() -> void:
		# Swaying from the foot of the pole: the cloth leans, the ground stays put.
		var base := Transform2D(0.0, Vector2.ONE, sway, Vector2(-sway * size.y, 0.0))
		draw_set_transform_matrix(base)
		Heraldry.realm_banner(self, realm, Rect2(Vector2.ZERO, size), true, false, base)


## Whether Home should open with it: once a launch, and never with reduced motion.
static func wanted() -> bool:
	return not played and not Style.motion_reduced()


## Builds the opening over Home, whose title it hands over to at the end.
func setup(home: Label) -> void:
	home_title = home
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 46:
		_stars.append([Vector2(floorf(rng.randf() * BOX.x / 3.0) * 3.0, floorf(rng.randf() * BOX.y * 0.55 / 3.0) * 3.0), rng.randf() * TAU, rng.randf() < 0.2])
	_stage = Control.new()
	_stage.size = BOX
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	_land = Control.new()
	_land.size = BOX
	_land.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_land.draw.connect(_draw_land)
	_stage.add_child(_land)
	var ridge_y := BOX.y * RIDGE_AT
	for spec in BANNERS:
		var b := Banner.new()
		b.realm = spec[0]
		var r: Rect2 = spec[1]
		b.position = Vector2(r.position.x, ridge_y + r.position.y)
		b.size = r.size
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_land.add_child(b)
		_banners.append(b)
	title = home.duplicate() as Label
	title.modulate.a = 1.0
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)
	# The glint: the same word in pale gold, seen only through a narrow moving slit.
	_glint_clip = Control.new()
	_glint_clip.clip_contents = true
	_glint_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_glint_clip)
	_glint = home.duplicate() as Label
	_glint.modulate.a = 1.0
	_glint.add_theme_color_override("font_color", Color("fff1c2"))
	_glint_clip.add_child(_glint)
	home.modulate.a = 0.0
	apply()


func _process(delta: float) -> void:
	if _done:
		return
	t += minf(delta, 0.1) * rate
	apply()
	if t >= LENGTH:
		finish()


func _gui_input(event: InputEvent) -> void:
	var press: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if press:
		hurry()
		accept_event()


## A tap: straight on to the title rising, and quickly.
func hurry() -> void:
	t = maxf(t, LAND_GOES.x)
	rate = HURRY


## Done: Home's own title shows, and the opening goes.
func finish() -> void:
	if _done:
		return
	_done = true
	if is_instance_valid(home_title):
		home_title.modulate.a = 1.0
	finished.emit()
	var layer := get_parent()
	if layer is CanvasLayer:
		layer.queue_free()
	else:
		queue_free()


func _phase(span: Vector2) -> float:
	var x := clampf((t - span.x) / (span.y - span.x), 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


## How big the box is drawn, and where, to fit the screen the way the splash is fitted.
func _fit() -> Array:
	var sz := get_viewport_rect().size
	var k := minf(sz.x / BOX.x, sz.y / BOX.y)
	return [k, (sz - BOX * k) * 0.5]


func apply() -> void:
	var fit := _fit()
	var k: float = fit[0]
	var origin: Vector2 = fit[1]
	_stage.scale = Vector2(k, k)
	_stage.position = origin
	var leave := _phase(LAND_GOES)
	for i in _banners.size():
		var b: Banner = _banners[i]
		var lit := _phase(Vector2(0.35, 1.05) + Vector2.ONE * 0.15 * float(i))
		b.modulate = Color(0.13, 0.15, 0.24).lerp(Color.WHITE, lit)
		b.sway = (0.035 * sin(t * 2.6 + float(i) * 1.7) + 0.02) * _phase(Vector2(0.3, 0.9))
		b.queue_redraw()
	_land.position.y = leave * BOX.y * 0.35
	_land.modulate.a = 1.0 - leave
	_land.queue_redraw()
	# The title: from its place on the splash (centred under the ridge, at the splash's
	# size) to Home's own title, where it is handed over.
	var home_size := float(home_title.get_theme_font_size("font_size"))
	var start_scale := k * float(Style.text_size(SPLASH_TITLE)) / maxf(1.0, home_size)
	var w := home_title.size.x if home_title.size.x > 0.0 else title.get_combined_minimum_size().x
	title.size = Vector2(w, home_title.size.y if home_title.size.y > 0.0 else title.get_combined_minimum_size().y)
	var start := origin + Vector2(BOX.x * 0.5, BOX.y * RIDGE_AT + 70.0) * k - Vector2(title.size.x * start_scale * 0.5, 0.0)
	var rise := _phase(TITLE_RISES)
	var s := lerpf(start_scale, 1.0, rise)
	title.scale = Vector2(s, s)
	title.position = start.lerp(home_title.global_position, rise)
	var handed := t >= TITLE_RISES.y
	title.visible = not handed
	home_title.modulate.a = 1.0 if handed else 0.0
	# The glint runs across the word once, before it rises.
	var glinting := t > 0.95 and t < 1.55
	_glint_clip.visible = glinting
	if glinting:
		var sz := get_viewport_rect().size
		var gx := lerpf(-60.0, sz.x + 60.0, _phase(Vector2(0.95, 1.55)))
		_glint_clip.position = Vector2(gx - 18.0, title.position.y)
		_glint_clip.size = Vector2(36.0, title.size.y * s)
		_glint.size = title.size
		_glint.scale = title.scale
		_glint.position = title.position - _glint_clip.position
	# Once Home shows through, taps go to it.
	mouse_filter = Control.MOUSE_FILTER_IGNORE if handed else Control.MOUSE_FILTER_STOP
	queue_redraw()


func _draw() -> void:
	# The night over Home: whole until the land has gone, then lifting.
	draw_rect(Rect2(Vector2.ZERO, size), Color(NIGHT, 1.0 - _phase(NIGHT_LIFTS)))


func _draw_land() -> void:
	var dawn := _phase(Vector2(0.25, 1.3))
	var ridge_y := BOX.y * RIDGE_AT
	# Past the box's sides on a wide screen, the sky and the ridge carry on.
	var fit := _fit()
	var spill: float = fit[1].x / maxf(0.01, float(fit[0])) + 6.0
	# Dawn behind the ridge, in stepped bands: pixel light, not a smooth gradient.
	for i in 10:
		var f := float(i) / 9.0
		var c := DAWN_LOW.lerp(DAWN_MID, f).lerp(NIGHT, f * f)
		_land.draw_rect(Rect2(-spill, ridge_y - 18.0 * float(i + 1), BOX.x + spill * 2.0, 18.0), Color(c, dawn * (1.0 - f * 0.85)))
	for st in _stars:
		var a := (0.55 + 0.45 * sin(t * 3.0 + float(st[1]))) * (1.0 - dawn * 0.85)
		_land.draw_rect(Rect2(st[0], Vector2(6, 6) if st[2] else Vector2(3, 3)), Color(1, 0.95, 0.85, a * (0.9 if st[2] else 0.6)))
	# The ridge, stepped in 6px blocks, with a rim of first light along it.
	var pts := PackedVector2Array()
	var x := -spill - fposmod(-spill, 6.0)
	while x <= BOX.x + spill:
		var h := floorf((10.0 * sin(x * 0.021) + 6.0 * sin(x * 0.067 + 1.0)) / 6.0) * 6.0
		pts.append(Vector2(x, ridge_y + h))
		pts.append(Vector2(x + 6.0, ridge_y + h))
		x += 6.0
	var top := pts.size()
	pts.append(Vector2(x, BOX.y * 2.0))
	pts.append(Vector2(-spill - 6.0, BOX.y * 2.0))
	_land.draw_colored_polygon(pts, RIDGE)
	for j in range(0, top, 2):
		_land.draw_line(pts[j], pts[j + 1], Color(DAWN_LOW, 0.55 * dawn), 3.0)
