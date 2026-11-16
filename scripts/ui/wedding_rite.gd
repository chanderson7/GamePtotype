## The rite's prop at a wedding, drawn in pixels over the stage in front of the couple, a
## step at a time as you do it (`step` is how many of the rite's taps are done):
##   Vardish   the cord over the hearth-fire, laid across your wrist, wound round both, knotted;
##   Kharzani  the loaf, broken, salted with the first piece lifted, then the contract and its seal;
##   Ryumon    three cups on a tray, turned down one by one, then the register, then your names in it.
## Each step settles in over a moment (the cord winds, the loaf parts, a cup tips); at once
## under Reduced motion. Pure drawing; it takes no input.
extends Control

const Cultures = preload("res://scripts/data/cultures.gd")
const Style = preload("res://scripts/ui/style.gd")

var culture := Cultures.VARDISH
## Taps done: the rite's plain steps, then its choice.
var step := 0
## How the newest step has settled: 0 as it's done, 1 settled.
var _p := 1.0
var _clock := 0.0
## Her people's colour, on her sleeve (Vardish: her woad-blue gown) or the cloth's border
## (Kharzani). Yours is a soldier's leather.
const HERS := {Cultures.VARDISH: Color("2b4a9a"), Cultures.KHARZANI: Color("1f7a6e"), Cultures.RYUMON: Color("c8443c")}
const YOURS := Color("7a5a3a")
const SKIN := Color("e0b48c")
const SKIN_DARK := Color("b8875e")
const CORD := Color("b8352a")
const WOOD := Color("6b4a1e")
const WOOD_DARK := Color("3b2a1a")
const PAPER := Color("efe2c0")
const INK := Color("2b2f3a")


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)


## The next tap is done: show it, settling in.
func advance() -> void:
	set_step(step + 1)


func set_step(n: int) -> void:
	step = n
	_p = 1.0 if Style.motion_reduced() else 0.0
	queue_redraw()


func _process(delta: float) -> void:
	if Style.motion_reduced():
		return
	_clock += delta
	_p = minf(1.0, _p + delta / 0.6)
	queue_redraw()


func _draw() -> void:
	if size.x <= 0.0:
		return
	match culture:
		Cultures.KHARZANI:
			_bread_and_salt()
		Cultures.RYUMON:
			_three_cups()
		_:
			_the_cord()


## A pixel block in prop units: x, y from the prop's centre, low on the stage.
func _r(x: float, y: float, w: float, h: float, c: Color) -> void:
	var px := maxf(2.0, roundf(size.x / 240.0))
	var o := Vector2(size.x * 0.5, size.y * 0.72)
	draw_rect(Rect2(Vector2(roundf(o.x / px + x) * px, roundf(o.y / px + y) * px), Vector2(maxf(1.0, roundf(w)) * px, maxf(1.0, roundf(h)) * px)), c)


func _ease(t: float) -> float:
	return 1.0 - pow(1.0 - clampf(t, 0.0, 1.0), 3.0)


# ---------------------------------------------------------------- Vardish: the cord

func _the_cord() -> void:
	# The hearth-fire, carried out from the hall, at the foot.
	for i in 7:
		_r(-15 + i * 4.3, 10, 4, 3, Color("4a4f5c") if i % 2 == 0 else Color("5c6272"))
	_r(-10, 7, 20, 3, WOOD)
	_r(-8, 6, 16, 2, WOOD_DARK)
	for i in 5:
		var h := 5.0 + 2.5 * sin(_clock * 8.0 + i * 1.7) + (2.0 if i == 2 else 0.0)
		_r(-7 + i * 3.0, 6 - h, 3, h, [Color("ff8a3d"), Color("ffcf6a"), Color("ffe9a8"), Color("ffcf6a"), Color("ff8a3d")][i])
	if step == 0:
		# The cord, waiting: laid loose above the fire.
		for i in 17:
			_r(-16 + i * 2.0, -6 + sin(i * 0.7) * 1.5, 2, 1, CORD)
		return
	# Two forearms meeting over the fire: yours from the left in leather, hers from the
	# right in her gown's blue.
	_r(-32, -10, 10, 7, YOURS)
	_r(-22, -9, 20, 5, SKIN)
	_r(-22, -5, 20, 1, SKIN_DARK)
	_r(22, -10, 10, 7, HERS.get(culture, Color("2b4a9a")))
	_r(2, -9, 20, 5, SKIN)
	_r(2, -5, 20, 1, SKIN_DARK)
	if step == 1:
		# Through the smoke and across your wrist, trailing off.
		for i in 3:
			var rise := fmod(_clock * 6.0 + i * 4.0, 12.0)
			_r(-2 + i * 2 + sin(_clock + i) * 1.5, 2 - rise, 2, 2, Color(0.8, 0.8, 0.85, 0.35 * (1.0 - rise / 12.0)))
		var lay := _ease(_p)
		_r(-8, -10, 2, 7, CORD)
		for i in int(6 * lay):
			_r(-6 + i * 2.0, -3 + i * 0.6, 2, 1, CORD)
		return
	# Wound once around both wrists: bands over both, drawn on as it winds.
	var wind := _ease(_p) if step == 2 else 1.0
	var bands := [-9.0, -6.0, -3.0, 2.0, 5.0, 8.0]
	for i in int(ceilf(bands.size() * wind)):
		_r(float(bands[i]), -10, 2, 7, CORD)
	_r(-9, -4, 19 * wind, 1, CORD)
	if step >= 3:
		# The knot, and its ends hanging free.
		var k := _ease(_p)
		_r(-2, -13, 4, 4, CORD.darkened(0.15))
		_r(-1, -12, 2, 2, CORD.lightened(0.2))
		_r(-3, -9, 1, 3 + 3 * k, CORD)
		_r(2, -9, 1, 2 + 4 * k, CORD)


# ---------------------------------------------------------------- Kharzani: bread and salt

func _bread_and_salt() -> void:
	# The cloth, with her people's border.
	var cloth := HERS.get(culture, Color("1f7a6e")) as Color
	_r(-28, 4, 56, 7, Color("e9dcc0"))
	for i in 9:
		_r(-27 + i * 6.5, 5, 3, 1, cloth)
		_r(-27 + i * 6.5, 9, 3, 1, Color("c8443c"))
	var crust := Color("8a5a24")
	var loaf := Color("c98a3c")
	if step == 0:
		_r(-10, -4, 20, 8, loaf)
		_r(-8, -6, 16, 2, loaf.lightened(0.15))
		for i in 3:
			_r(-6 + i * 5, -5, 3, 1, crust)
		_r(-10, 3, 20, 1, crust)
	else:
		# Broken clean in two, the halves drawn apart.
		var apart := 5.0 * (_ease(_p) if step == 1 else 1.0)
		_r(-11 - apart, -4, 10, 8, loaf)
		_r(-9 - apart, -6, 7, 2, loaf.lightened(0.15))
		_r(-2 - apart, -3, 1, 6, Color("f2d9a6"))
		_r(1 + apart, -4, 10, 8, loaf)
		_r(2 + apart, -6, 7, 2, loaf.lightened(0.15))
		_r(1 + apart, -3, 1, 6, Color("f2d9a6"))
		for i in 4:
			_r(-3 + i * 2, 2, 1, 1, crust)
	if step >= 2:
		# The salt in its dish, and the first piece lifted, salted, for her.
		_r(14, 0, 10, 4, Color("5d6b8a"))
		_r(15, 3, 8, 1, Color("3b4560"))
		_r(16, -2, 6, 2, Color("f4f1ea"))
		var lift := 6.0 * (_ease(_p) if step == 2 else 1.0)
		_r(-3, -11 - lift, 6, 4, Color("f2d9a6"))
		_r(-2, -12 - lift, 1, 1, Color("ffffff"))
		_r(1, -11 - lift, 1, 1, Color("ffffff"))
	if step >= 3:
		# The contract, unrolled in front of it all, signed and sealed.
		var open := _ease(_p)
		var w := 44.0 * open
		_r(-w * 0.5, -22, w, 13, PAPER)
		_r(-w * 0.5 - 2, -23, 2, 15, WOOD)
		_r(w * 0.5, -23, 2, 15, WOOD)
		if open > 0.8:
			for i in 4:
				_r(-18, -20 + i * 2.5, 30 - (i % 2) * 8, 1, INK)
			_r(14, -15, 4, 4, Color("c8443c"))
			_r(15, -14, 2, 2, Color("e88a7a"))


# ---------------------------------------------------------------- Ryumon: three cups

func _three_cups() -> void:
	# The low tray.
	_r(-26, 4, 52, 3, Color("7a3348"))
	_r(-24, 7, 3, 3, Color("4a1f2c"))
	_r(21, 7, 3, 3, Color("4a1f2c"))
	var turned := mini(step, 3)
	for i in 3:
		var x := -15.0 + i * 13.0
		if i < turned:
			# Drunk, and turned down: the foot on top. The newest tips over as it settles.
			var tip := _ease(_p) if i == turned - 1 and step <= 3 else 1.0
			_r(x - 3, -1 - 3 * (1.0 - tip), 7, 5, Color("ece5d3"))
			_r(x - 1, -2 - 3 * (1.0 - tip), 3, 1, Color("b9b2a0"))
		else:
			_r(x - 3, -3, 7, 7, Color("ece5d3"))
			_r(x - 3, -3, 7, 1, Color("b9b2a0"))
			_r(x - 2, -2, 5, 1, Color("8a5a3a"))
	if step >= 3:
		# The register, opened to a clean page behind the cups.
		var open := _ease(_p) if step == 3 else 1.0
		_r(-20, -20, 40 * open, 12, PAPER)
		_r(-1, -20, 1, 12, Color("c9b98e"))
		_r(-22, -21, 2, 14, WOOD_DARK)
	if step >= 4:
		# Your names, written in: two columns of brush strokes.
		var ink := _ease(_p)
		for i in int(4 * ink):
			_r(-14, -18 + i * 2.5, 2, 2, INK)
			_r(6, -18 + i * 2.5, 2, 2, INK)
		_r(-12, -17, 1, 6 * ink, INK)
		_r(8, -17, 1, 6 * ink, INK)
