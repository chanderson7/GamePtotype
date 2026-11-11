## A place dressed for a wedding, drawn over its picture: two strings of pixel bunting in
## the house's colours, lantern glows at dusk and night, and a few petals at the sides.
## Pure drawing; it fills the stage and takes no input.
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
const BURST_TIME := 2.6
var _burst := 0.0


## Throw the petals. Nothing under Reduced motion.
func burst() -> void:
	if not Style.motion_reduced():
		_burst = 1.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)


func _process(delta: float) -> void:
	if Style.motion_reduced():
		return
	_clock += delta
	_burst = maxf(0.0, _burst - delta / BURST_TIME)
	queue_redraw()


func _draw() -> void:
	var s := size
	if s.x <= 0.0:
		return
	var px := maxf(2.0, roundf(s.x / 240.0))
	var colors: Array = COLORS.get(culture, COLORS[Cultures.VARDISH])
	var lit := when in ["dusk", "night"]
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
		for t: float in [0.12, 0.3, 0.7, 0.88]:
			var y := s.y * 0.12 + s.y * 0.07 * 4.0 * t * (1.0 - t) + px * 9.0
			var c := Vector2(s.x * t, y)
			var glow := 0.85 + 0.15 * sin(_clock * 5.3 + t * 11.0) * sin(_clock * 3.1 + t * 7.0)
			for k in 4:
				var r := px * (10.0 - k * 2.0)
				draw_circle(c, r, Color(1.0, 0.72, 0.3, (0.06 + 0.05 * k) * glow))
			draw_rect(Rect2(c - Vector2(px * 2.0, px * 3.0), Vector2(px * 4.0, px * 6.0)), Color("ffcf6a"))
			draw_rect(Rect2(c - Vector2(px * 2.0, px * 3.0), Vector2(px * 4.0, px)), Color("6b4a1e"))
	# A few petals drifting at the sides, clear of faces.
	if petals:
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
	# The shower: thrown from above, across the whole width, thinning as it falls.
	if _burst > 0.0:
		var rng := RandomNumberGenerator.new()
		rng.seed = 23
		var gone := 1.0 - _burst
		for i in 70:
			var x := rng.randf() * s.x + sin(gone * 6.0 + i) * px * 5.0
			var y := (rng.randf_range(-0.35, 0.25) + gone * rng.randf_range(0.7, 1.3)) * s.y
			var c := Color("f4b6c8") if rng.randf() < 0.6 else Color("fff3e6")
			c.a = minf(1.0, _burst * 2.5)
			if y > 0.0 and y < s.y:
				draw_rect(Rect2(Vector2(roundf(x / px) * px, roundf(y / px) * px), Vector2(px, px)), c)


func _pennant(top: Vector2, half: float, depth: float, c: Color, px: float) -> void:
	# A stepped triangle, a pixel row at a time, so it reads as pixel art.
	var rows := int(maxf(2.0, depth / px))
	for r in rows:
		var w := half * (1.0 - float(r) / float(rows))
		draw_rect(Rect2(Vector2(roundf((top.x - w) / px) * px, top.y + r * px), Vector2(maxf(px, roundf(w * 2.0 / px) * px), px)), c)
