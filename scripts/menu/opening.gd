## The opening: night on a ridge with the three realms' banners, dawn coming up behind
## them, then the night lifting off Home while the banners fly into the title's mark and
## the title rises into its place. Its first frame is the boot splash (assets/splash.png is
## a render of it, by tools/render_splash.gd), so the engine's still hands over without a
## jump. Plays once a launch, over Home: in full the first time (no campaign yet), short
## when a campaign is waiting, and as a still that fades when motion is reduced. A tap
## hurries it on.
extends Control

const Style = preload("res://scripts/ui/style.gd")
const Heraldry = preload("res://scripts/ui/heraldry.gd")
const Wordmark = preload("res://scripts/ui/wordmark.gd")

signal finished

## The frame the splash is drawn for (a 9:19.5 phone at the 720-wide canvas). It covers
## the screen, centred and cropped at the edges, the way the engine covers it with the
## splash image (stretch mode Cover, and aspect-fill on the iOS launch screen), so frame 0
## matches the splash on any shape of screen.
const BOX := Vector2(720.0, 1561.0)
## The ridge line, down the box.
const RIDGE_AT := 0.6
## The name (and tagline) on the splash: how wide, in the box, and how far below the ridge
## its middle sits.
const SPLASH_NAME := 560.0
const NAME_BELOW := 95.0
const NIGHT := Color("0e1322")
const RIDGE := Color("080b15")
const DAWN_LOW := Color("e9a04e")
const DAWN_MID := Color("8a4f5e")
## A banner before the dawn reaches it.
const UNLIT := Color(0.13, 0.15, 0.24)
## Dawn's bands, each this tall in the box; and the glow under the horizon (bands), which
## shows as the ridge goes and stays the night's lower edge as it lifts.
const BAND := 18.0
const EDGE_BANDS := 4
## How far Home's card and bottom row rise as they arrive, in screen pixels.
const ARRIVE_RISE := 24.0
## A tap finishes whatever is left in this many seconds.
const HURRY_SECONDS := 0.4

## The timelines, in seconds. Spans are (start, end). light: the first banner's lighting;
## light_step: each next one's delay (or `lead`: the one lit a beat ahead, the rest
## together). fly: the banners fly to their place in Home's mark (fly_step: each banner's
## delay, left to right), a little ahead of the title's rise, so they keep above the name.
## rise: the title rises into its place, where the painted banners take over. taps: from
## here taps reach Home.
## The first time anyone opens the game.
const FULL := {
	"hold": 0.25, "dawn": Vector2(0.25, 1.2), "light": Vector2(0.35, 0.85), "light_step": 0.22, "lead": "",
	"birds": 0.3, "glint": Vector2(1.0, 1.5), "ground": Vector2(1.35, 1.8), "lift": Vector2(1.45, 2.3),
	"fly": Vector2(1.4, 2.0), "fly_step": 0.04, "rise": Vector2(1.55, 2.2), "card": Vector2(2.1, 2.5), "row": Vector2(2.3, 2.7),
	"taps": 2.3, "music": 0.8, "length": 2.7,
}
## A campaign under way: the same picture, quickly. No glint, no birds; the camp's fire
## (Home's own ambience) comes up under the dawn.
const SHORT := {
	"hold": 0.15, "dawn": Vector2(0.15, 0.6), "light": Vector2(0.2, 0.55), "light_step": 0.0, "lead": "vardmark",
	"ground": Vector2(0.4, 0.75), "lift": Vector2(0.45, 1.2),
	"fly": Vector2(0.45, 0.95), "fly_step": 0.0, "rise": Vector2(0.55, 1.1), "card": Vector2(1.0, 1.3), "row": Vector2(1.15, 1.45),
	"taps": 1.2, "music": 0.0, "length": 1.5,
}
## Reduced motion: the first frame, still, fading off Home. Nothing moves.
const STILL := {"fade": Vector2(0.25, 0.5), "taps": 0.25, "music": 0.0, "length": 0.5}

## Whether the opening has played this launch.
static var played := false

var t := 0.0
var rate := 1.0
## "full", "short" or "still".
var kind := "full"
var timeline: Dictionary = FULL
var home_title: Label
## The opening's own title: a copy of Home's mark (or, with no mark, of its label).
var title: Control
var _mark: Control
var _home_mark: Control
var _name_local := Rect2()
var _stage: Control
var _sky: Control
var _ground: Control
var _banners: Array = []
var _stars: Array = []
var _card: Array = []
var _row: Array = []
var _fired := {}
var _done := false


class Banner extends Control:
	var realm := ""
	var sway := 0.0
	func _draw() -> void:
		# Swaying from the foot of the pole: the cloth leans, the ground stays put.
		var base := Transform2D(0.0, Vector2.ONE, sway, Vector2(-sway * size.y, 0.0))
		draw_set_transform_matrix(base)
		Heraldry.realm_banner(self, realm, Rect2(Vector2.ZERO, size), true, false, base)


## Whether Home should open with it: once a launch.
static func wanted() -> bool:
	return not played


## Which opening: still when motion is reduced, short with a campaign, else full.
static func kind_for(has_campaign: bool) -> String:
	if Style.motion_reduced():
		return "still"
	return "short" if has_campaign else "full"


static func timeline_for(which: String) -> Dictionary:
	match which:
		"short":
			return SHORT
		"still":
			return FULL.merged(STILL, true)
	return FULL


## How long Home's music waits, so that it has faded in as the title lands.
static func music_after(which: String) -> float:
	return float(timeline_for(which)["music"])


## Builds the opening over Home, whose title it hands over to at the end. `card` and `row`
## are the rest of Home, which arrive in turn as the night lifts.
func setup(home: Label, which: String = "full", card: Array = [], row: Array = []) -> void:
	home_title = home
	kind = which
	timeline = timeline_for(kind)
	_card = card
	_row = row
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
	_sky = Control.new()
	_sky.size = BOX
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sky.draw.connect(_draw_sky)
	_stage.add_child(_sky)
	_ground = Control.new()
	_ground.size = BOX
	_ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ground.draw.connect(_draw_ground)
	_stage.add_child(_ground)
	# The title, under the banners so they land on it. With a painted mark, just the mark,
	# in a box the size of Home's label: the label's own (clear) text has nothing to show,
	# and at the splash's size it would reach past the screen's edge.
	_home_mark = home.get_node_or_null("Wordmark") as Control
	if _home_mark != null:
		title = Control.new()
		title.name = "TitleCopy"
		title.add_child(_home_mark.duplicate())
	else:
		title = home.duplicate() as Label
	title.modulate.a = 1.0
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)
	title.size = home.get_combined_minimum_size()
	_mark = title.get_node_or_null("Wordmark") as Control
	if _mark != null:
		_mark.set("banners", 0.0)
		var n: Rect2 = _mark.call("name_rect")
		_name_local = Rect2(_mark.position + n.position, n.size)
	else:
		_name_local = Rect2(Vector2.ZERO, title.size)
	for spec in Wordmark.BANNERS:
		var b := Banner.new()
		b.realm = spec[0]
		b.size = (spec[1] as Rect2).size
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(b)
		_banners.append(b)
	home.modulate.a = 0.0
	apply()


func _process(delta: float) -> void:
	if _done:
		return
	var was := t
	t += minf(delta, 0.1) * rate
	_cues(was)
	apply()
	if t >= float(timeline["length"]):
		finish()


func _gui_input(event: InputEvent) -> void:
	var press: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if press:
		hurry()
		accept_event()


## A tap: whatever is left plays through quickly, from where it is. Nothing jumps.
func hurry() -> void:
	rate = maxf(rate, (float(timeline["length"]) - t) / HURRY_SECONDS)


## Done: Home shows whole, and the opening goes.
func finish() -> void:
	if _done:
		return
	_done = true
	if is_instance_valid(home_title):
		home_title.modulate.a = 1.0
	for c in _card + _row:
		_arrive(c, 1.0)
	finished.emit()
	var layer := get_parent()
	if layer is CanvasLayer:
		layer.queue_free()
	else:
		queue_free()


## The sounds and the touch, each once, as the opening passes its moment.
func _cues(was: float) -> void:
	if kind == "still":
		return
	var at := {"birds": timeline.get("birds", -1.0), "glint": (timeline["glint"] as Vector2).x if timeline.has("glint") else -1.0,
		"landed": (timeline["rise"] as Vector2).y}
	for key in at:
		var when: float = at[key]
		if when < 0.0 or _fired.has(key) or t < when or was > when:
			continue
		_fired[key] = true
		var sound := get_node_or_null("/root/Sound")
		if sound == null:
			continue
		match key:
			"birds": sound.play("birds")
			"glint": sound.play("glint")
			"landed": sound.haptic()


func _phase(span: Vector2) -> float:
	var x := clampf((_vt() - span.x) / maxf(0.001, span.y - span.x), 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


## The time the picture shows: the still opening keeps its first frame.
func _vt() -> float:
	return 0.0 if kind == "still" else t


func _span(key: String) -> Vector2:
	return timeline.get(key, Vector2(INF, INF))


## How big the box is drawn, and where, to cover the screen the way the splash does.
func _fit() -> Array:
	var sz := get_viewport_rect().size
	var k := maxf(sz.x / BOX.x, sz.y / BOX.y)
	return [k, (sz - BOX * k) * 0.5]


## When banner `i` lights, and when it flies.
func _light_start(i: int) -> float:
	var light := _span("light")
	var lead := String(timeline.get("lead", ""))
	if lead != "":
		return light.x + (0.0 if Wordmark.BANNERS[i][0] == lead else 0.08)
	return light.x + float(timeline.get("light_step", 0.0)) * i


func _fly_span(i: int) -> Vector2:
	var g := _span("fly")
	var step := float(timeline.get("fly_step", 0.0))
	var n := _banners.size()
	return Vector2(g.x + step * i, g.y - step * (n - 1 - i))


func apply() -> void:
	var fit := _fit()
	var k: float = fit[0]
	var origin: Vector2 = fit[1]
	var vt := _vt()
	var ridge_y := BOX.y * RIDGE_AT
	_stage.scale = Vector2(k, k)
	_stage.position = origin
	# The night lifts from the horizon: the sky, its stars and its dawn rise off the top of
	# the screen, the glow under the horizon last.
	var gone := -origin.y / k - float(EDGE_BANDS) * BAND - ridge_y
	_sky.position.y = _phase(_span("lift")) * gone
	_sky.queue_redraw()
	_ground.modulate.a = 1.0 - _phase(_span("ground"))
	_ground.queue_redraw()
	# The title: from its place on the splash (the name centred under the ridge) up to Home's
	# own, shrinking as it goes. Moved by the name's middle, so the name stays where the eye is.
	var c := _name_local.get_center()
	var s0 := SPLASH_NAME * k / maxf(1.0, _name_local.size.x)
	var start_mid := origin + Vector2(BOX.x * 0.5, ridge_y + NAME_BELOW) * k
	var home_ready := is_instance_valid(home_title) and home_title.size.x > 0.0
	var end_mid := home_title.global_position + c if home_ready else start_mid
	var rise := _phase(_span("rise"))
	var s := s0 * pow(1.0 / s0, rise)
	title.scale = Vector2(s, s)
	title.position = start_mid.lerp(end_mid, rise) - c * s
	# The painted banners take over from the flown ones once the title has come to rest.
	var g := _span("rise")
	var landing := _phase(Vector2(g.y - 0.02, g.y + 0.1))
	if _mark != null:
		_mark.set("banners", landing)
		var gl := _span("glint")
		_mark.set("glint", clampf((vt - gl.x) / (gl.y - gl.x), 0.0, 1.0) if vt >= gl.x and vt <= gl.y else -1.0)
		_mark.queue_redraw()
	# The banners: lit left to right by the dawn, swaying in the gust that follows it, then
	# still, and flown into the mark beside the name, where the painted ones take over.
	for i in _banners.size():
		var b: Banner = _banners[i]
		var box: Rect2 = Wordmark.BANNERS[i][1]
		var ls := _light_start(i)
		var light := _span("light")
		var lit := _phase(Vector2(ls, ls + light.y - light.x))
		var flash := sin(lit * PI) * 0.3
		var col := UNLIT.lerp(Color.WHITE, lit)
		b.modulate = Color(col.r * (1.0 + flash), col.g * (1.0 + flash * 0.9), col.b * (1.0 + flash * 0.6), 1.0)
		var gs := _fly_span(i)
		var gust := sin(PI * clampf((vt - ls) / 0.7, 0.0, 1.0)) * 0.6
		var still := _phase(Vector2(gs.x - 0.2, gs.x + 0.05))
		b.sway = (0.035 * sin(vt * 2.6 + float(i) * 1.7) + 0.02) * _phase(Vector2(ls, ls + 0.4)) * (1.0 + gust) * (1.0 - still)
		var from_pos := origin + (box.position + Vector2(0.0, ridge_y)) * k
		var to_pos := from_pos
		var to_scale := k
		# Straight to their place in Home's own mark (where the rising title will be), so they
		# keep above the name as it comes up, and land beside it.
		var flies := _mark != null and _home_mark != null and home_ready
		if flies:
			var r: Rect2 = _home_mark.call("from_image", Wordmark.box_in_image(box))
			var xf := _home_mark.get_global_transform()
			to_pos = xf * r.position
			to_scale = r.size.x / box.size.x * xf.get_scale().x
		var fly := _phase(gs) if flies else 0.0
		var sc := k * pow(to_scale / k, fly)
		var mid := (from_pos + box.size * 0.5 * k).lerp(to_pos + box.size * 0.5 * to_scale, fly)
		b.scale = Vector2(sc, sc)
		b.position = mid - box.size * 0.5 * sc
		b.modulate.a = 1.0 - landing if _mark != null else 1.0 - _phase(_span("lift"))
		b.queue_redraw()
	# The hand-over: once the night has gone from over Home's title, it is Home's own.
	var handed := vt >= _span("lift").y if kind != "still" else t >= float(timeline["hold"])
	title.visible = kind == "still" or not handed
	if is_instance_valid(home_title):
		home_title.modulate.a = 1.0 if handed else 0.0
	# The rest of Home arrives under the lifting night: the card, then the row along the bottom.
	if kind != "still":
		for part in _card:
			_arrive(part, _phase(_span("card")))
		for part in _row:
			_arrive(part, _phase(_span("row")))
	else:
		modulate.a = 1.0 - _phase_raw(_span("fade"))
	# Taps reach Home once its card is up.
	mouse_filter = Control.MOUSE_FILTER_IGNORE if t >= float(timeline["taps"]) else Control.MOUSE_FILTER_STOP


## A phase in real time, for the still opening's fade (whose picture keeps frame 0).
func _phase_raw(span: Vector2) -> float:
	var x := clampf((t - span.x) / maxf(0.001, span.y - span.x), 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


## One of Home's parts, `a` of the way in: fading up and rising into its place. Its
## container may lay it out again at any time, so its place is read back each time.
func _arrive(c: Control, a: float) -> void:
	if not is_instance_valid(c):
		return
	var base: Vector2 = c.position
	if c.has_meta("opening_set") and c.position == c.get_meta("opening_set"):
		base = c.get_meta("opening_base")
	c.set_meta("opening_base", base)
	c.modulate.a = a
	c.position = base + Vector2(0.0, (1.0 - a) * ARRIVE_RISE)
	c.set_meta("opening_set", c.position)
	if a >= 1.0:
		c.remove_meta("opening_set")
		c.remove_meta("opening_base")


## Where things are on the screen, in the box (the splash's frame): the name and each
## banner. tools/render_splash.gd records these for frame 0, and the tests compare.
func frame_rects() -> Dictionary:
	var fit := _fit()
	var k: float = fit[0]
	var origin: Vector2 = fit[1]
	var to_box := func(r: Rect2) -> Rect2: return Rect2((r.position - origin) / k, r.size / k)
	var out := {"name": to_box.call(name_rect())}
	for b in _banners:
		out[b.realm] = to_box.call(Rect2(b.position, b.size * b.scale.x))
	return out


## The name and tagline as shown now, on the screen.
func name_rect() -> Rect2:
	return Rect2(title.position + _name_local.position * title.scale.x, _name_local.size * title.scale.x)


## The name and tagline's ink as shown now, on the screen.
func name_ink() -> Rect2:
	if _mark == null:
		return name_rect()
	var r: Rect2 = _mark.call("name_ink")
	return Rect2(title.position + (_mark.position + r.position) * title.scale.x, r.size * title.scale.x)


## Where the dawn's bands end, on the screen: the ridge line, carried up with the sky.
func dawn_line() -> float:
	var fit := _fit()
	return float(fit[1].y) + (BOX.y * RIDGE_AT + _sky.position.y) * float(fit[0])


func _draw_sky() -> void:
	var vt := _vt()
	var dawn := _phase(_span("dawn"))
	var ridge_y := BOX.y * RIDGE_AT
	# A little past the box's sides, so a rounding at the screen's edge shows no seam.
	var fit := _fit()
	var spill: float = maxf(0.0, fit[1].x / maxf(0.01, float(fit[0]))) + 6.0
	var wide := Rect2(-spill, 0.0, BOX.x + spill * 2.0, 0.0)
	# The night ends at the horizon: under it is the ridge, and once that has gone, Home.
	_sky.draw_rect(Rect2(wide.position.x, -BOX.y, wide.size.x, BOX.y + ridge_y), NIGHT)
	for i in EDGE_BANDS:
		var f := float(i) / float(EDGE_BANDS)
		_sky.draw_rect(Rect2(wide.position.x, ridge_y + BAND * float(i), wide.size.x, BAND), Color(DAWN_LOW.lerp(DAWN_MID, f), dawn * 0.55 * (1.0 - f)))
	# Dawn behind the ridge, in stepped bands: pixel light, not a smooth gradient.
	for i in 10:
		var f := float(i) / 9.0
		var c := DAWN_LOW.lerp(DAWN_MID, f).lerp(NIGHT, f * f)
		_sky.draw_rect(Rect2(wide.position.x, ridge_y - BAND * float(i + 1), wide.size.x, BAND), Color(c, dawn * (1.0 - f * 0.85)))
	# The stars go out from the horizon upward as the dawn climbs.
	for st in _stars:
		var p: Vector2 = st[0]
		var height := clampf((ridge_y - p.y) / ridge_y, 0.0, 1.0)
		var out := clampf((dawn * 1.15 - height * 0.9) / 0.25, 0.0, 1.0)
		var a := (0.55 + 0.45 * sin(vt * 3.0 + float(st[1]))) * (1.0 - dawn * 0.85) * (1.0 - out * 0.9)
		_sky.draw_rect(Rect2(p, Vector2(6, 6) if st[2] else Vector2(3, 3)), Color(1, 0.95, 0.85, a * (0.9 if st[2] else 0.6)))


func _draw_ground() -> void:
	var dawn := _phase(_span("dawn"))
	var ridge_y := BOX.y * RIDGE_AT
	var fit := _fit()
	var spill: float = maxf(0.0, fit[1].x / maxf(0.01, float(fit[0]))) + 6.0
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
	_ground.draw_colored_polygon(pts, RIDGE)
	for j in range(0, top, 2):
		_ground.draw_line(pts[j], pts[j + 1], Color(DAWN_LOW, 0.55 * dawn), 3.0)
