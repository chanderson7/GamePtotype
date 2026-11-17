extends Control
## The notice board at the head of a place's Work tab: a roofed board on two posts with
## the contracts pinned to it, one sheet for each on offer or taken, their corners lifting
## in the wind, a wax seal on those you've signed. A lantern hangs from the post and is
## lit at night. Still under Reduced motion.
##
## NoticeBoard.make(offers, taken, night)

const Style = preload("res://scripts/ui/style.gd")

const WOOD := Color("6b4a2a")
const WOOD_DARK := Color("4a3220")
const WOOD_LIGHT := Color("8a6238")
const PAPER := Color("e9dcc0")
const INK := Color("5a4a3a")

var offers := 0
var taken := 0
var night := false
var _t := 0.0
var _since := 0.0


static func make(on_offer: int, signed: int, is_night: bool) -> Control:
	var b = load("res://scripts/ui/notice_board.gd").new()
	b.name = "NoticeBoardArt"
	b.offers = on_offer
	b.taken = signed
	b.night = is_night
	b.custom_minimum_size = Vector2(0, 132)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_contents = true
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.visible = Style.illustrations_on()
	return b


func _ready() -> void:
	set_process(not Style.motion_reduced())
	resized.connect(queue_redraw)


func _process(delta: float) -> void:
	_t += delta
	_since += delta
	if _since >= 0.1 and is_visible_in_tree():
		_since = 0.0
		queue_redraw()


## How many sheets are pinned up (at most what the board holds).
func sheets() -> int:
	return clampi(offers + taken, 0, 7)


func _draw() -> void:
	if size.x < 60.0:
		return
	var k := 4.0
	var tone := Color(0.5, 0.56, 0.82) if night else Color.WHITE
	var r := func(x: float, y: float, w: float, h: float, c: Color):
		draw_rect(Rect2(roundf(x / k) * k, roundf(y / k) * k, maxf(k, roundf(w / k) * k), maxf(k, roundf(h / k) * k)), Color(c.r * tone.r, c.g * tone.g, c.b * tone.b, c.a))
	var box := StyleBoxFlat.new()
	box.bg_color = Color("101830") if night else Color("22304a")
	box.set_corner_radius_all(10)
	draw_style_box(box, Rect2(Vector2.ZERO, size))
	var ground := size.y - 16.0
	draw_rect(Rect2(2, ground, size.x - 4, 14), Color("1c2a22") if night else Color("3a5236"))
	var w := minf(size.x - 120.0, 460.0)
	var x0 := (size.x - w) * 0.5
	# Posts, the board, its roof.
	r.call(x0, 28, 12, ground - 28, WOOD_DARK)
	r.call(x0 + w - 12, 28, 12, ground - 28, WOOD_DARK)
	r.call(x0 + 8, 30, w - 16, 76, WOOD)
	for i in 4:
		r.call(x0 + 8, 30 + i * 20, w - 16, 4, WOOD_DARK)
	r.call(x0 - 12, 16, w + 24, 12, WOOD_LIGHT)
	r.call(x0 - 12, 24, w + 24, 4, WOOD_DARK)
	r.call(x0 - 4, 8, w + 8, 8, WOOD)
	# The sheets: each its own size and lean, a corner lifting in the wind.
	var n := sheets()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in n:
		var pw := 44.0 + rng.randi_range(0, 2) * 8.0
		var ph := 44.0 + rng.randi_range(0, 2) * 8.0
		var px := x0 + 22.0 + (w - 44.0 - pw) * (float(i) / maxf(1.0, n - 1.0) if n > 1 else 0.5)
		var py := 36.0 + rng.randi_range(0, 2) * 4.0
		var lift := 0.0 if not is_processing() else maxf(0.0, sin(_t * (1.4 + 0.3 * (i % 3)) + i * 1.9)) * 8.0
		r.call(px + 4, py + 4, pw, ph, Color(0, 0, 0, 0.25))
		r.call(px, py, pw, ph - lift, PAPER)
		r.call(px, py, pw - lift, ph, PAPER)
		if lift >= 4.0:
			# The corner turned up shows its paler back.
			r.call(px + pw - lift, py + ph - lift, lift, lift, Color("fff6e0"))
		r.call(px + pw * 0.5 - 2, py - 2, 4, 4, Color("9aa0aa"))
		for line in 3:
			r.call(px + 8, py + 12 + line * 8, pw - 16 - (line % 2) * 8, 4, INK)
		if i < taken:
			r.call(px + pw - 20, py + ph - 24, 12, 12, Color("b8322a"))
			r.call(px + pw - 16, py + ph - 20, 4, 4, Color("e88a7a"))
	# The lantern on the left post, swinging a little; lit at night.
	var swing := 0.0 if not is_processing() else roundf(sin(_t * 1.3) * 1.0) * k
	draw_rect(Rect2(x0 - 16 + swing * 0.5, 32, 4, 12), Color("2a2430"))
	draw_rect(Rect2(x0 - 24 + swing, 44, 16, 20), Color("3a3f4a"))
	draw_rect(Rect2(x0 - 20 + swing, 48, 8, 12), Color("ffcf6a") if night else Color("8a8f9a"))
	if night:
		var flick := 0.16 + (0.04 * sin(_t * 9.0) if is_processing() else 0.0)
		draw_circle(Vector2(x0 - 16 + swing, 54), 46.0, Color(1.0, 0.7, 0.3, flick * 0.5))
		draw_circle(Vector2(x0 - 16 + swing, 54), 22.0, Color(1.0, 0.7, 0.3, flick))
