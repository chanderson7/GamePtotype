## A place dressed for a wedding, drawn over its picture: two strings of pixel bunting in
## the house's colours, lantern glows at dusk and night, and a few petals at the sides.
## For the question it hushes (hush: the bunting stills, the petals stop, the lanterns
## burn low); at the feast more lanterns are lit as the night goes on (set_late), and a
## wish lantern can be let go to rise over everything (release_lantern). Pure drawing; it
## fills the stage and takes no input.
extends Control

const Cultures = preload("res://scripts/data/cultures.gd")
const Style = preload("res://scripts/ui/style.gd")

## Pennant colours by culture.
const COLORS := {
	Cultures.VARDISH: ["3f6fd8", "d9a944", "ece5d3", "b8352a"],
	Cultures.KHARZANI: ["1f7a6e", "d9a944", "c8443c", "ece5d3"],
	Cultures.RYUMON: ["c8443c", "ece5d3", "2b2f3a", "d9a944"],
}

var culture := Cultures.VARDISH
## "morning", "midday", "afternoon", "dusk" or "night": lanterns glow at dusk and night.
var when := "dusk"
var petals := true
## Time for the breeze: the bunting sways, the lanterns flicker and the petals drift.
var _clock := 0.0
## A shower of petals over the whole place, for the moment you're wed: 1 as it's thrown,
## falling to 0 as the last of it lands.
const BURST_TIME := 3.0
var _burst := 0.0
## 0 as the place is, 1 hushed for the question: eased between, so it settles.
var _hush := 0.0
var _hushed := false
## How far into the night the feast is (0 to 4): one more lantern lit at each step, and a
## little more dark.
var late := 0
## Wish lanterns let go (release_lantern): [{x, t (seconds since let go), wob}].
var _risers: Array = []
## How long a wish lantern takes to rise out of sight.
const RISE_TIME := 7.0


## Throw the petals. Nothing under Reduced motion.
func burst() -> void:
	if not Style.motion_reduced():
		_burst = 1.0


## Hush the place for the question, or let it go again.
func hush(on: bool) -> void:
	_hushed = on
	if Style.motion_reduced():
		_hush = 1.0 if on else 0.0
	queue_redraw()


## The night moves on: `step` lanterns more (up to 4), and a little darker.
func set_late(step: int) -> void:
	late = clampi(step, 0, 4)
	queue_redraw()


## Let a wish lantern go: it rises from `x` (a share of the width) over the whole place,
## swaying, until it's a speck. Nothing under Reduced motion.
func release_lantern(x: float = 0.5) -> void:
	if not Style.motion_reduced():
		_risers.append({"x": x, "t": 0.0, "wob": float(_risers.size()) * 1.7})


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)


func _process(delta: float) -> void:
	if Style.motion_reduced():
		return
	_hush = move_toward(_hush, 1.0 if _hushed else 0.0, delta / 0.8)
	# Hushed, the breeze drops: everything slows almost to a stop.
	_clock += delta * (1.0 - 0.9 * _hush)
	_burst = maxf(0.0, _burst - delta / BURST_TIME)
	for r in _risers:
		r["t"] = float(r["t"]) + delta
	_risers = _risers.filter(func(r): return float(r["t"]) < RISE_TIME)
	queue_redraw()


func _draw() -> void:
	var s := size
	if s.x <= 0.0:
		return
	var px := maxf(2.0, roundf(s.x / 240.0))
	var colors: Array = COLORS.get(culture, COLORS[Cultures.VARDISH])
	var lit := when in ["dusk", "night"] or late > 0
	# Later in the night, darker: a wash over the place, under the lanterns.
	if late > 0:
		draw_rect(Rect2(Vector2.ZERO, s), Color(0.04, 0.05, 0.12, 0.09 * float(late)))
	# Two strings of bunting sagging across the top.
	for row in 2:
		var y0 := s.y * (0.05 + 0.07 * row)
		var sag := s.y * 0.07 * (1.0 + 0.1 * sin(_clock * 0.9 + row * 1.7))
		var n := 14
		var prev := Vector2.ZERO
		for i in 41:
			var t := float(i) / 40.0
			var p := Vector2(s.x * t, y0 + sag * 4.0 * t * (1.0 - t))
			if i > 0:
				draw_line(prev, p, Color("3b2a1a"), maxf(1.0, px * 0.6))
			prev = p
		for i in n:
			var t := (float(i) + 0.5) / float(n)
			var x := s.x * t
			var y := y0 + sag * 4.0 * t * (1.0 - t)
			var c := Color(String(colors[(i + row) % colors.size()]))
			if when == "night":
				c = c.darkened(0.35)
			_pennant(Vector2(x + sin(_clock * 1.6 + i * 0.8 + row) * px * 0.8, y), px * 3.0, px * 6.0, c, px)
	# Lanterns hung along the lower string, glowing after dusk.
	if lit:
		# More are lit as the feast goes on, filling the gaps along the string.
		var spots: Array = [0.12, 0.3, 0.7, 0.88]
		spots.append_array(([0.5, 0.21, 0.79, 0.04] as Array).slice(0, late))
		for t: float in spots:
			var y := s.y * 0.12 + s.y * 0.07 * 4.0 * t * (1.0 - t) + px * 9.0
			var c := Vector2(s.x * t, y)
			# Hushed, they burn low.
			var glow := (0.85 + 0.15 * sin(_clock * 5.3 + t * 11.0) * sin(_clock * 3.1 + t * 7.0)) * (1.0 - 0.55 * _hush)
			for k in 4:
				var r := px * (10.0 - k * 2.0)
				draw_circle(c, r, Color(1.0, 0.72, 0.3, (0.06 + 0.05 * k) * glow))
			draw_rect(Rect2(c - Vector2(px * 2.0, px * 3.0), Vector2(px * 4.0, px * 6.0)), Color("ffcf6a"))
			draw_rect(Rect2(c - Vector2(px * 2.0, px * 3.0), Vector2(px * 4.0, px)), Color("6b4a1e"))
	# A few petals drifting at the sides, clear of faces (none while hushed).
	if petals and _hush < 0.5:
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in 22:
			var left := i % 2 == 0
			var x := rng.randf_range(0.02, 0.22) * s.x if left else rng.randf_range(0.78, 0.98) * s.x
			var fall := rng.randf_range(0.015, 0.04)
			var y := (0.12 + fposmod(rng.randf_range(0.0, 0.73) + _clock * fall, 0.73)) * s.y
			x += sin(_clock * 1.2 + i) * px * 2.0
			var c := Color("f4b6c8") if rng.randf() < 0.6 else Color("fff3e6")
			draw_rect(Rect2(Vector2(roundf(x / px) * px, roundf(y / px) * px), Vector2(px, px)), c)
	# The shower: thrown from above across the whole width, a couple of hundred petals
	# tumbling down past everyone and thinning as the last of it lands.
	if _burst > 0.0:
		var rng := RandomNumberGenerator.new()
		rng.seed = 23
		var gone := 1.0 - _burst
		for i in 180:
			var x0 := rng.randf() * s.x
			var y0 := rng.randf_range(-0.7, 0.05)
			var fall := rng.randf_range(1.0, 1.9)
			var big := rng.randf() < 0.55
			var tint := rng.randf()
			var x := x0 + sin(gone * 7.0 + i * 1.3) * px * 7.0
			var y := (y0 + gone * fall) * s.y
			if y < 0.0 or y > s.y:
				continue
			var c := Color("f4b6c8") if tint < 0.5 else (Color("fff3e6") if tint < 0.8 else Color("e58aa8"))
			c.a = minf(1.0, _burst * 3.0)
			# A petal turns as it falls: wide, then edge on.
			var wide := px * (2.0 if big else 1.0) * (1.0 if sin(gone * 9.0 + i) > -0.3 else 0.5)
			draw_rect(Rect2(Vector2(roundf(x / px) * px, roundf(y / px) * px), Vector2(maxf(px, wide), px * (2.0 if big else 1.0))), c)
	# Wish lanterns rising: a paper box with a flame in it, a glow around, swaying as it
	# climbs, smaller as it goes, until it's a speck among the stars.
	for r in _risers:
		var k := float(r["t"]) / RISE_TIME
		var grow := 1.0 - 0.7 * k
		var x := s.x * float(r["x"]) + sin(float(r["t"]) * 1.3 + float(r["wob"])) * px * 6.0
		var y := lerpf(s.y * 0.82, -s.y * 0.1, k)
		var w := px * 5.0 * grow
		var h := px * 6.0 * grow
		var fade := 1.0 if k < 0.8 else (1.0 - k) / 0.2
		for g in 3:
			draw_circle(Vector2(x, y), w * (1.6 + g * 0.6), Color(1.0, 0.7, 0.3, 0.07 * fade))
		draw_rect(Rect2(Vector2(x - w * 0.5, y - h * 0.5), Vector2(w, h)), Color(1.0, 0.86, 0.6, 0.95 * fade))
		draw_rect(Rect2(Vector2(x - w * 0.2, y), Vector2(w * 0.4, h * 0.3)), Color(1.0, 0.55, 0.2, fade))


func _pennant(top: Vector2, half: float, depth: float, c: Color, px: float) -> void:
	# A stepped triangle, a pixel row at a time, so it reads as pixel art.
	var rows := int(maxf(2.0, depth / px))
	for r in rows:
		var w := half * (1.0 - float(r) / float(rows))
		draw_rect(Rect2(Vector2(roundf((top.x - w) / px) * px, top.y + r * px), Vector2(maxf(px, roundf(w * 2.0 / px) * px), px)), c)
