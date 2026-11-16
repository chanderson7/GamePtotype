## The rite's prop at a wedding, drawn in pixels on the stage in front of the couple, a
## step at a time as you do it (`step` is how many of the rite's taps are done):
##   Vardish   an iron brazier with the hearth-fire in it and the cord laid across; your arm
##             over the fire with the cord on your wrist; both your hands, the cord wound
##             round them; the knot.
##   Kharzani  a carved table with the loaf on its runner; the loaf broken; salted, the
##             first piece lifted for her; the contract unrolled behind, signed and sealed.
##   Ryumon    a black lacquer table with three cups, turned down one by one; the register
##             opened on the table; your names written in it.
## It stands on a soft pool of shadow so it reads apart from her gown. Each step settles in
## over a moment (the cord winds, the loaf parts, a cup tips); at once under Reduced
## motion. Pure drawing; it takes no input.
extends Control

const Cultures = preload("res://scripts/data/cultures.gd")
const Style = preload("res://scripts/ui/style.gd")

var culture := Cultures.VARDISH
## Taps done: the rite's plain steps, then its choice.
var step := 0
## How the newest step has settled: 0 as it's done, 1 settled.
var _p := 1.0
var _clock := 0.0
## Her people's colour: her sleeve (Vardish: her woad-blue gown) or the runner's border
## (Kharzani). Yours is a soldier's leather.
const HERS := {Cultures.VARDISH: Color("2b4a9a"), Cultures.KHARZANI: Color("1f7a6e"), Cultures.RYUMON: Color("c8443c")}
const YOURS := Color("7a5a3a")
const SKIN := Color("e0b48c")
const SKIN_DARK := Color("b8875e")
const HER_SKIN := Color("d9a47c")
const CORD := Color("c23a2e")
const WOOD := Color("8a5a2a")
const WOOD_DARK := Color("4e3216")
const IRON := Color("3a3f4a")
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
	_pool()
	match culture:
		Cultures.KHARZANI:
			_bread_and_salt()
		Cultures.RYUMON:
			_three_cups()
		_:
			_the_cord()


## One pixel of the prop, on screen.
func _px() -> float:
	return maxf(3.0, roundf(size.x / 150.0))


## Where the prop stands: low and centred, in front of the couple, clear of the nameplate.
func _origin() -> Vector2:
	return Vector2(size.x * 0.5, size.y * 0.74)


## A pixel block in prop units: x, y from the prop's centre.
func _r(x: float, y: float, w: float, h: float, c: Color) -> void:
	var px := _px()
	var o := _origin()
	draw_rect(Rect2(Vector2(roundf(o.x / px + x) * px, roundf(o.y / px + y) * px), Vector2(maxf(1.0, roundf(w)) * px, maxf(1.0, roundf(h)) * px)), c)


## A soft pool of shadow under the prop, darkest at its heart, so it stands apart from
## whatever is behind it.
func _pool() -> void:
	var px := _px()
	draw_set_transform(_origin() + Vector2(0.0, -4.0 * px), 0.0, Vector2(1.0, 0.62))
	for i in 5:
		draw_circle(Vector2.ZERO, 40.0 * px * (1.0 - 0.13 * i), Color(0.03, 0.03, 0.07, 0.16))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _ease(t: float) -> float:
	return 1.0 - pow(1.0 - clampf(t, 0.0, 1.0), 3.0)


## A hand seen from the side, `facing` 1 (pointing right) or -1, its knuckles shaded.
func _hand(x: float, y: float, facing: float, skin: Color) -> void:
	_r(x, y, 6, 7, skin)
	_r(x + (5.0 if facing > 0 else 0.0), y + 1, 1, 5, skin.darkened(0.12))
	_r(x + (1.0 if facing > 0 else 1.0), y + 6, 4, 1, skin.darkened(0.25))
	_r(x + (2.0 if facing > 0 else 2.0), y - 1, 3, 1, skin.lightened(0.1))


## A forearm from `x0` to `x1` with its sleeve at the outer end.
func _arm(x0: float, x1: float, y: float, skin: Color, sleeve: Color, sleeve_at_left: bool) -> void:
	_r(x0, y, x1 - x0, 5, skin)
	_r(x0, y + 4, x1 - x0, 1, skin.darkened(0.2))
	if sleeve_at_left:
		_r(x0 - 12, y - 2, 12, 9, sleeve)
		_r(x0 - 2, y - 2, 2, 9, sleeve.lightened(0.18))
	else:
		_r(x1, y - 2, 12, 9, sleeve)
		_r(x1, y - 2, 2, 9, sleeve.lightened(0.18))


# ---------------------------------------------------------------- Vardish: the cord

func _the_cord() -> void:
	# The iron brazier, the hearth-fire carried out from the hall burning in it.
	_r(-11, 13, 2, 5, IRON.darkened(0.3))
	_r(9, 13, 2, 5, IRON.darkened(0.3))
	_r(-14, 8, 28, 5, IRON)
	_r(-15, 7, 30, 2, IRON.lightened(0.25))
	_r(-12, 12, 24, 1, IRON.darkened(0.35))
	for i in 7:
		var h := 6.0 + 3.0 * sin(_clock * 8.0 + i * 1.7) + (3.0 if i == 3 else 0.0) - absf(i - 3.0)
		_r(-10 + i * 3.0, 7 - h, 3, h, [Color("ff7a2e"), Color("ffb04a"), Color("ffcf6a"), Color("fff0b8"), Color("ffcf6a"), Color("ffb04a"), Color("ff7a2e")][i])
	if step == 0:
		# The cord, waiting: laid along the brazier's rim, its ends hanging.
		_r(-13, 6, 26, 1, CORD)
		_r(-14, 6, 1, 4, CORD)
		_r(13, 6, 1, 3, CORD)
		return
	if step == 1:
		# Your arm over the fire, the cord passed through the smoke and laid on your wrist.
		_arm(-26, -6, -14, SKIN, YOURS, true)
		_hand(-6, -15, 1.0, SKIN)
		for i in 3:
			var rise := fmod(_clock * 7.0 + i * 5.0, 14.0)
			_r(-2 + i * 2 + sin(_clock + i) * 1.5, 2 - rise, 2, 2, Color(0.85, 0.85, 0.9, 0.35 * (1.0 - rise / 14.0)))
		var lay := _ease(_p)
		_r(-11, -15, 2, 7, CORD)
		for i in int(7 * lay):
			_r(-9 + i * 1.5, -9 + i * 1.6, 2, 1, CORD)
		return
	# Both your hands, joined over the fire: yours from the left, hers from the right.
	_arm(-26, -6, -14, SKIN, YOURS, true)
	_arm(6, 26, -14, HER_SKIN, HERS.get(culture, Color("2b4a9a")), false)
	_hand(-6, -15, 1.0, SKIN)
	_hand(0, -15, -1.0, HER_SKIN)
	# Wound once round both wrists, drawn on as it winds.
	var wind := _ease(_p) if step == 2 else 1.0
	var bands := [-9.0, -7.0, 6.0, 8.0]
	for i in int(ceilf(bands.size() * wind)):
		_r(float(bands[i]), -16, 1, 9, CORD)
	_r(-9, -16, 18 * wind, 1, CORD)
	_r(-9, -8, 18 * wind, 1, CORD.darkened(0.2))
	if step >= 3:
		# The knot on top, and its ends hanging free.
		var k := _ease(_p)
		_r(-2, -20, 4, 4, CORD.darkened(0.15))
		_r(-1, -19, 2, 2, CORD.lightened(0.25))
		_r(-3, -16, 1, 3 + 4 * k, CORD)
		_r(2, -16, 1, 2 + 5 * k, CORD)


# ---------------------------------------------------------------- Kharzani: bread and salt

## A low carved table, with her people's runner on it.
func _table_carved() -> void:
	_r(-26, 13, 3, 5, WOOD_DARK)
	_r(23, 13, 3, 5, WOOD_DARK)
	_r(-30, 7, 60, 6, WOOD_DARK)
	for i in 7:
		_r(-27 + i * 9, 9, 2, 2, Color("d9a944"))
	_r(-31, 5, 62, 2, WOOD)
	var border := HERS.get(culture, Color("1f7a6e")) as Color
	_r(-20, 4, 40, 2, Color("e9dcc0"))
	_r(-20, 4, 40, 1, border)
	_r(-20, 6, 40, 1, Color("c8443c"))


func _bread_and_salt() -> void:
	if step >= 3:
		# The contract, unrolled behind it all on its rods, signed and sealed.
		var open := _ease(_p)
		var w := 48.0 * open
		_r(-w * 0.5, -24, w, 15, PAPER)
		_r(-w * 0.5 - 2, -25, 2, 17, WOOD)
		_r(w * 0.5, -25, 2, 17, WOOD)
		if open > 0.8:
			for i in 4:
				_r(-19, -22 + i * 3.0, 30 - (i % 2) * 8, 1, INK)
			_r(14, -16, 5, 5, Color("c8443c"))
			_r(15, -15, 3, 3, Color("e88a7a"))
	_table_carved()
	var crust := Color("8a5a24")
	var loaf := Color("c98a3c")
	if step == 0:
		_r(-12, -5, 24, 9, loaf)
		_r(-10, -7, 20, 2, loaf.lightened(0.15))
		for i in 4:
			_r(-8 + i * 5, -6, 3, 1, crust)
		_r(-12, 3, 24, 1, crust)
	else:
		# Broken clean in two, the halves drawn apart.
		var apart := 5.0 * (_ease(_p) if step == 1 else 1.0)
		for side in [-1.0, 1.0]:
			var x := -13.0 - apart if side < 0 else 1.0 + apart
			_r(x, -5, 12, 9, loaf)
			_r(x + 2, -7, 8, 2, loaf.lightened(0.15))
			_r(x + (11.0 if side < 0 else 0.0), -4, 1, 7, Color("f2d9a6"))
		for i in 4:
			_r(-3 + i * 2, 3, 1, 1, crust)
	if step >= 2:
		# The salt in its dish, and the first piece lifted, salted, for her.
		_r(18, -1, 10, 5, Color("5d6b8a"))
		_r(19, 3, 8, 1, Color("3b4560"))
		_r(20, -3, 6, 2, Color("f4f1ea"))
		var lift := 7.0 * (_ease(_p) if step == 2 else 1.0)
		_r(-4, -13 - lift, 8, 5, Color("f2d9a6"))
		_r(-3, -14 - lift, 1, 1, Color("ffffff"))
		_r(1, -13 - lift, 1, 1, Color("ffffff"))
		_r(2, -14 - lift, 1, 1, Color("ffffff"))


# ---------------------------------------------------------------- Ryumon: three cups

## A low table of black lacquer with a red edge.
func _table_lacquer() -> void:
	_r(-26, 13, 3, 5, Color("15121a"))
	_r(23, 13, 3, 5, Color("15121a"))
	_r(-30, 7, 60, 6, Color("1e1a22"))
	_r(-30, 7, 60, 1, Color("8c2b2b"))
	_r(-31, 5, 62, 2, Color("2e2833"))


func _three_cups() -> void:
	_table_lacquer()
	if step >= 3:
		# The register, opened on its stand behind the cups.
		var open := _ease(_p) if step == 3 else 1.0
		_r(-22 * open, -16, 22 * open, 10, PAPER)
		_r(0, -16, 22 * open, 10, PAPER.darkened(0.05))
		_r(-1, -16, 2, 10, Color("c9b98e"))
		_r(-23 * open, -6, 46 * open, 1, Color("8a7a5a"))
		_r(-2, -5, 4, 5, Color("2e2833"))
		if step >= 4:
			# Your names, written in: a column of brush strokes on each page.
			var ink := _ease(_p)
			for i in int(4 * ink):
				_r(-14, -14 + i * 2.0, 3, 1, INK)
				_r(10, -14 + i * 2.0, 3, 1, INK)
	var turned := mini(step, 3)
	for i in 3:
		var x := -17.0 + i * 15.0
		var y := 0.0
		if i < turned:
			# Drunk, and turned down: the foot on top. The newest tips over as it settles.
			var tip := _ease(_p) if i == turned - 1 and step <= 3 else 1.0
			_r(x - 4, y - 2 - 3 * (1.0 - tip), 9, 6, Color("ece5d3"))
			_r(x - 4, y + 3 - 3 * (1.0 - tip), 9, 1, Color("b9b2a0"))
			_r(x - 1, y - 3 - 3 * (1.0 - tip), 3, 1, Color("b9b2a0"))
		else:
			_r(x - 4, y - 4, 9, 8, Color("ece5d3"))
			_r(x - 4, y - 4, 9, 1, Color("b9b2a0"))
			_r(x - 3, y - 3, 7, 1, Color("6a3a22"))
			_r(x - 4, y + 3, 9, 1, Color("b9b2a0"))
