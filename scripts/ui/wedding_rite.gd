## The rite's prop at a wedding, drawn in pixels on the stage in front of the couple, a
## step at a time as you do it (`step` is how many of the rite's taps are done):
##   Vardish   the hearth-fire in an iron basket, the cord coiled on a stool beside it;
##             your arm over the fire with the cord laid across your wrist; her wrist
##             against yours, each hand on the other's arm, the cord wound round both; the
##             knot (hers small and tight, or lopsided if you tied it together).
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
## (Kharzani).
const HERS := {Cultures.VARDISH: Color("2b4a9a"), Cultures.KHARZANI: Color("1f7a6e"), Cultures.RYUMON: Color("c8443c")}
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


# ---------------------------------------------------------------- Vardish: the cord

## The cord rite is drawn on a finer grid than the other two (FINE units across the
## stage), near the grain of her portrait, so that hands, a cuff and a twisted cord can be
## told apart. Positions below are in those units, from the prop's centre.
const FINE := 265.0
const IRON_LIGHT := Color("5d6676")
const IRON_DARK := Color("22252d")
const CORD_LIGHT := Color("e8674f")
const CORD_DARK := Color("86201a")
const GOLD := Color("d9a944")
const GOLD_LIGHT := Color("f0d27a")
const FLAMES := [Color("d8401c"), Color("ff7a2e"), Color("ffab40"), Color("ffd76a"), Color("fff3c4")]
const FIRELIGHT := Color(1.0, 0.62, 0.25)
## Skin as base, light, shade and line: yours, a soldier's; hers, as she is painted.
const YOU := {"base": Color("d9a57a"), "light": Color("ecc198"), "shade": Color("b07c56"), "line": Color("8a5c3c")}
const HER := {"base": Color("f0c8a8"), "light": Color("fadfc6"), "shade": Color("cf9c7a"), "line": Color("a8745a")}
const LEATHER := Color("7a5a3a")
const WOOL := Color("463c36")
## The top of your forearm and how thick it is; hers lies behind it, a little higher.
const ARM_Y := -32.0
const ARM_TH := 13.0

## Which knot was tied (the rite's choice): "together" comes out lopsided; any other is
## hers, small and tight.
var choice := ""


## A block in fine units, snapped to whole screen pixels so neighbours meet without gaps.
func _f(x: float, y: float, w: float, h: float, c: Color) -> void:
	if w <= 0.0 or h <= 0.0:
		return
	var u := size.x / FINE
	var o := _origin()
	var x0 := roundf(o.x + x * u)
	var y0 := roundf(o.y + y * u)
	var x1 := maxf(x0 + 1.0, roundf(o.x + (x + w) * u))
	var y1 := maxf(y0 + 1.0, roundf(o.y + (y + h) * u))
	draw_rect(Rect2(x0, y0, x1 - x0, y1 - y0), c)


## The rite as it stands: the hearth-fire in its iron basket and the cord coiled on a
## stool beside it; your wrist over the fire with the cord laid across; her wrist against
## yours, each hand on the other's arm, the cord wound round both; the knot.
func _the_cord() -> void:
	_glow()
	_stool()
	if step == 0:
		_coil()
	_brazier()
	_fire()
	_smoke(1.0 if step == 1 else 0.45)
	var p := _ease(_p)
	if step == 1:
		_your_arm(true)
		_draped(p)
	elif step >= 2:
		# Her arm comes in from the right as you wind.
		var dx := (1.0 - p) * 22.0 if step == 2 else 0.0
		_her_arm(dx)
		_your_arm(false)
		_her_fingers(dx)
		_wound(p if step == 2 else 1.0, step >= 3)
		if step >= 3:
			_knot(p)
	_sparks()


## The fire's light on everything near it: many faint rings, so it has no edge.
func _glow() -> void:
	var u := size.x / FINE
	var c := _origin() + Vector2(0.0, 6.0 * u)
	var flick := 0.5 + 0.5 * sin(_clock * 7.0)
	for i in 10:
		draw_circle(c, (58.0 - i * 5.0) * u, Color(1.0, 0.55 + 0.02 * i, 0.2, 0.014 + 0.004 * flick))


## An iron fire-basket on three legs: a rim with rivets and a carrying ring at each side,
## upright bars with the coals glowing between them, a band at the foot.
func _brazier() -> void:
	# The back leg, then the two that splay toward you.
	_f(-2, 31, 4, 10, IRON_DARK.darkened(0.25))
	for i in 6:
		_f(-23.0 - i, 31.0 + i * 2.0, 3, 2, IRON_DARK)
		_f(20.0 + i, 31.0 + i * 2.0, 3, 2, IRON_DARK)
		_f(-23.0 - i, 31.0 + i * 2.0, 1, 2, IRON)
	_f(-30, 42, 6, 1, IRON_DARK)
	_f(24, 42, 6, 1, IRON_DARK)
	# The coals, banked in the basket: each glows and dims in its own time.
	for row in 7:
		var half := 27.0 - row * 0.8
		var y := 17.0 + row * 2.0
		var cells := int(half)
		for i in cells:
			var heat := 0.5 + 0.5 * sin(_clock * 2.6 + i * 2.3 + row * 1.7)
			var ember := Color("5a1c0e").lerp(Color("ff8a30"), heat * (1.0 - row * 0.09))
			_f(-half + i * 2.0, y, 2, 2, ember)
	# The bars, drawing in toward the foot.
	for i in 9:
		var bx := -26.0 + i * 6.5
		for row in 7:
			var k := 1.0 - row * 0.028
			_f(bx * k - 1.0, 17.0 + row * 2.0, 2, 2, IRON if row < 4 else IRON_DARK)
			if row < 4:
				_f(bx * k - 1.0, 17.0 + row * 2.0, 1, 2, IRON_LIGHT.lerp(IRON, 0.5))
	# The rim, lit along its top by the fire, with its rivets and rings.
	_f(-30, 13, 60, 1, IRON_LIGHT.lerp(FIRELIGHT, 0.45))
	_f(-30, 14, 60, 3, IRON)
	_f(-30, 16, 60, 1, IRON_DARK)
	for i in 7:
		_f(-27.0 + i * 9.0, 14, 1, 1, IRON_LIGHT)
	for side in [-1.0, 1.0]:
		var rx: float = -34.0 if side < 0.0 else 31.0
		_f(rx, 15, 3, 1, IRON_LIGHT)
		_f(rx if side < 0.0 else rx + 2.0, 16, 1, 4, IRON)
		_f(rx, 20, 3, 1, IRON_DARK)
	_f(-24, 24, 48, 1, IRON_DARK)
	_f(-23, 30, 46, 2, IRON)
	_f(-23, 30, 46, 1, IRON_LIGHT.lerp(IRON, 0.4))
	_f(-22, 32, 44, 1, IRON_DARK)


## The hearth-fire: flames in five colours, deepest at the edge and palest at the heart,
## their tongues leaning and licking in turn.
func _fire() -> void:
	var t := _clock
	for i in 22:
		var x := -22.0 + i * 2.0
		var c := (x + 1.0) / 22.0
		var dome := maxf(0.0, 1.0 - c * c)
		var flick := 0.5 + 0.3 * sin(t * 9.0 + i * 1.9) + 0.2 * sin(t * 13.0 - i * 0.7)
		var tongue := pow(maxf(0.0, sin(i * 0.9 + t * 2.2)), 3.0) * 7.0
		var h := (5.0 + 17.0 * dome) * (0.7 + 0.3 * flick) + tongue * dome
		for k in FLAMES.size():
			var hh := roundf(h * (1.0 - 0.19 * k) - k * 1.5)
			if hh > 0.0:
				var flame: Color = FLAMES[k]
				_f(x, 14.0 - hh, 2, hh, flame)
		# The tip of each tongue thins out.
		_f(x, 14.0 - roundf(h) - 1.0, 2, 1, Color(FLAMES[0], 0.45))


## Sparks, going up.
func _sparks() -> void:
	for i in 7:
		var life := fmod(_clock * (0.33 + 0.06 * i) + i * 0.37, 1.0)
		var x := -14.0 + fmod(i * 7.3, 28.0) + sin(_clock * 2.0 + i) * 4.0 * life
		_f(x, 4.0 - life * 46.0, 1, 1, Color(1.0, 0.8 - 0.35 * life, 0.3, 1.0 - life))


## Smoke, thin over the fire; thicker (`strength`) when the cord is passed through it.
func _smoke(strength: float) -> void:
	for i in 5:
		var life := fmod(_clock * 0.22 + i * 0.2, 1.0)
		var x := -8.0 + i * 4.0 + sin(_clock * 0.9 + i * 2.1) * (3.0 + 6.0 * life)
		var s := 2.0 + 3.0 * life
		_f(x, -6.0 - life * 58.0, s, s, Color(0.86, 0.86, 0.9, 0.22 * strength * (1.0 - life)))


## A three-legged stool beside the fire, where the cord waits.
func _stool() -> void:
	_f(43, 31, 2, 11, WOOD_DARK)
	_f(57, 31, 2, 11, WOOD_DARK)
	_f(50, 31, 2, 9, WOOD_DARK.darkened(0.25))
	_f(44, 37, 14, 1, WOOD_DARK)
	_f(40, 27, 22, 4, WOOD)
	_f(40, 27, 22, 1, WOOD.lightened(0.3))
	_f(40, 30, 22, 1, WOOD_DARK)


## A turn of the cord lying flat, from `x0` to `x1`: lit above, dark beneath, its twist
## showing along it.
func _turn(x0: float, x1: float, y: float) -> void:
	_f(x0 + 1.0, y, x1 - x0 - 2.0, 1, CORD_LIGHT)
	_f(x0, y + 1.0, x1 - x0, 2, CORD)
	_f(x0 + 1.0, y + 3.0, x1 - x0 - 2.0, 1, CORD_DARK)
	var x := x0 + 2.0
	while x < x1 - 2.0:
		_f(x, y + 1.0, 1, 1, CORD_DARK)
		_f(x + 1.0, y + 2.0, 1, 1, CORD_DARK)
		x += 4.0


## The cord, waiting: three turns coiled on the stool, one tasselled end over its edge.
func _coil() -> void:
	_turn(41, 61, 23)
	_turn(42, 60, 19)
	_turn(45, 57, 15)
	_f(49, 16, 4, 1, CORD_DARK.darkened(0.4))
	_hang(59, 25, 7, 0.6)


## One row of the cord seen along its length, three wide: lit on the left, dark on the
## right, the twist stepping across it as the rows go down.
func _cord_row(x: float, y: float, r: int, dim: float = 0.0) -> void:
	var twist := r % 4
	_f(x, y, 1, 1, (CORD_DARK if twist == 0 else CORD_LIGHT).darkened(dim))
	_f(x + 1.0, y, 1, 1, (CORD_DARK if twist == 1 else CORD).darkened(dim))
	_f(x + 2.0, y, 1, 1, CORD_DARK.darkened(dim + (0.25 if twist == 2 else 0.0)))


## A length of the cord hanging from (`x`, `y`), swaying, a gold-bound tassel at its end.
## `far` is a length seen behind something: darker.
func _hang(x: float, y: float, length: float, phase: float, far: bool = false) -> void:
	var n := int(length)
	if n < 1:
		return
	var dim := 0.3 if far else 0.0
	var sway := sin(_clock * 1.7 + phase) * 2.0
	var bx := x
	for r in n:
		var k := float(r) / maxf(1.0, length)
		bx = x + roundf(sway * k * k)
		_cord_row(bx, y + r, r, dim)
	if n < 4:
		return
	var ty := y + n
	_f(bx - 1.0, ty, 5, 2, GOLD.darkened(dim))
	_f(bx - 1.0, ty, 3, 1, GOLD_LIGHT.darkened(dim))
	_f(bx - 1.0, ty + 2.0, 1, 5, CORD.darkened(dim))
	_f(bx, ty + 2.0, 1, 6, CORD_LIGHT.darkened(dim))
	_f(bx + 1.0, ty + 2.0, 1, 5, CORD.darkened(dim))
	_f(bx + 2.0, ty + 2.0, 1, 6, CORD_DARK.darkened(dim))
	_f(bx + 3.0, ty + 2.0, 1, 4, CORD.darkened(dim))


## A bare forearm from `x0` to `x1`: lit along the top, shaded beneath, and warmed along
## its underside by the fire.
func _skin(x0: float, x1: float, y: float, th: float, tone: Dictionary) -> void:
	var warm := 0.4 + 0.12 * sin(_clock * 7.0)
	_f(x0, y, x1 - x0, th, tone["base"])
	_f(x0, y, x1 - x0, 2, tone["light"])
	_f(x0, y + th - 4.0, x1 - x0, 3, tone["shade"])
	_f(x0, y + th - 1.0, x1 - x0, 1, (tone["shade"] as Color).lerp(FIRELIGHT, warm))


## Your arm, from the left: a wool sleeve, a soldier's leather cuff with its three straps
## and buckles, the forearm, and the hand: held flat over the fire (`open_hand`), or
## closed round her wrist.
func _your_arm(open_hand: bool) -> void:
	var y := ARM_Y
	var th := ARM_TH
	_f(-64, y - 2.0, 14, th + 4.0, WOOL)
	_f(-64, y - 2.0, 14, 2, WOOL.lightened(0.2))
	_f(-64, y + th, 14, 2, WOOL.darkened(0.35))
	for i in 3:
		_f(-61.0 + i * 4.0, y, 1, th, WOOL.darkened(0.25))
	_f(-50, y - 1.0, 20, th + 2.0, LEATHER)
	_f(-50, y - 1.0, 20, 2, LEATHER.lightened(0.24))
	_f(-50, y + th - 2.0, 20, 3, LEATHER.darkened(0.32))
	for i in 3:
		var sx := -48.0 + i * 7.0
		_f(sx, y - 1.0, 2, th + 2.0, LEATHER.darkened(0.42))
		_f(sx - 1.0, y + 3.0, 4, 3, GOLD)
		_f(sx - 1.0, y + 3.0, 2, 1, GOLD_LIGHT)
		_f(sx, y + 4.0, 2, 1, LEATHER.darkened(0.42))
	_f(-31, y - 1.0, 1, th + 2.0, LEATHER.lightened(0.34))
	_skin(-30, 3, y, th, YOU)
	var base: Color = YOU["base"]
	var light: Color = YOU["light"]
	var shade: Color = YOU["shade"]
	var line: Color = YOU["line"]
	if open_hand:
		# The back of the hand, the fingers together and tapering, the thumb beneath.
		_f(3, y, 12, th - 1.0, base)
		_f(3, y, 12, 2, light)
		_f(3, y + th - 4.0, 12, 3, shade)
		_f(13, y, 1, 2, shade)
		_f(15, y + 1.0, 8, th - 5.0, base)
		_f(15, y + 1.0, 8, 2, light)
		_f(23, y + 2.0, 4, th - 8.0, base)
		_f(23, y + 2.0, 4, 1, light)
		_f(26, y + 3.0, 1, 3, light.lightened(0.3))
		_f(15, y + th - 5.0, 10, 1, line)
		_f(19, y + 3.0, 1, 4, shade)
		_f(15, y + th - 4.0, 8, 1, shade)
		_f(6, y + th - 3.0, 11, 4, base)
		_f(6, y + th - 3.0, 11, 1, line)
		_f(6, y + th, 11, 1, shade.lerp(FIRELIGHT, 0.4))
		_f(16, y + th - 2.0, 1, 2, light.lightened(0.3))
		return
	# Closed round her wrist: the back of your hand, knuckles along the top where the
	# fingers go over, the thumb along the underside.
	_f(3, y - 1.0, 17, th + 2.0, base)
	_f(3, y - 1.0, 17, 2, light)
	_f(3, y + th - 3.0, 17, 3, shade)
	for i in 4:
		_f(5.0 + i * 4.0, y - 2.0, 3, 1, light)
		_f(8.0 + i * 4.0, y - 1.0, 1, 4, line)
	_f(6, y + th - 1.0, 12, 3, base)
	_f(6, y + th - 1.0, 12, 1, line)
	_f(6, y + th + 2.0, 12, 1, shade.lerp(FIRELIGHT, 0.4))
	_f(17, y + th, 1, 2, light.lightened(0.3))


## Her arm, from the right and behind yours: the forearm, and the sleeve of her gown,
## woad blue and widening as it hangs, gold at the cuff. `dx` is how far it has yet to come.
func _her_arm(dx: float) -> void:
	var y := ARM_Y - 4.0
	var th := ARM_TH - 1.0
	_skin(-5.0 + dx, 30.0 + dx, y, th, HER)
	var blue: Color = HERS[Cultures.VARDISH]
	for i in 5:
		var sx := 34.0 + i * 5.0 + dx
		var drop := [1.0, 2.0, 4.0, 7.0, 10.0][i] as float
		_f(sx, y - 2.0, 5, th + 4.0 + drop, blue)
		_f(sx, y - 2.0, 5, 2, blue.lightened(0.24))
		_f(sx, y + th + drop, 5, 2, blue.darkened(0.38))
		if i % 2 == 1:
			_f(sx, y + 1.0, 1, th + drop, blue.darkened(0.22))
	_f(30.0 + dx, y - 2.0, 5, th + 4.0, GOLD)
	_f(30.0 + dx, y - 2.0, 5, 1, GOLD_LIGHT)
	_f(34.0 + dx, y - 2.0, 1, th + 4.0, GOLD.darkened(0.3))
	for i in 4:
		_f(32.0 + dx, y + 1.0 + i * 3.0, 1, 1, blue)


## Her hand on your arm: the back of it showing above, four fingers come over the top.
func _her_fingers(dx: float) -> void:
	var y := ARM_Y - 4.0
	var base: Color = HER["base"]
	var light: Color = HER["light"]
	var line: Color = HER["line"]
	_f(-22.0 + dx, y - 1.0, 17, 4, base)
	_f(-22.0 + dx, y - 1.0, 17, 1, light)
	for i in 4:
		var fx := -21.0 + i * 4.0 + dx
		var fl := 11.0 + ([0.0, 1.0, 1.0, -1.0][i] as float)
		_f(fx, y + 2.0, 3, fl, base)
		_f(fx, y + 2.0, 1, fl, light)
		_f(fx, y + 1.0 + fl, 3, 1, light.lightened(0.35))
		_f(fx + 3.0, y + 3.0, 1, fl - 2.0, line)


## One pass of the cord round both wrists, from `y0` down to `y1`, leaning a little;
## `shown` (0 to 1) is how much of it has been wound.
func _band(x: float, y0: float, y1: float, shown: float) -> void:
	var n := int((y1 - y0) * clampf(shown, 0.0, 1.0))
	for r in n:
		var bx := x + floorf(float(r) / 7.0)
		_cord_row(bx, y0 + r, r)
		_f(bx + 3.0, y0 + r, 1, 1, CORD_DARK.darkened(0.3))


## The cord laid across your wrist: over the top, the near end down the front of the arm
## and off it, the far end showing below.
func _draped(p: float) -> void:
	var y := ARM_Y
	_hang(-1, y + ARM_TH, 10.0 * p, 2.0, true)
	_f(-7, y - 2.0, 6, 2, CORD)
	_f(-7, y - 2.0, 6, 1, CORD_LIGHT)
	_hang(-7, y - 1.0, (ARM_TH + 14.0) * p, 0.0)


## Wound once round both wrists: two passes, between her fingers and your hand. Until it
## is `tied` its ends hang beneath.
func _wound(wind: float, tied: bool) -> void:
	var top := ARM_Y - 6.0
	var bottom := ARM_Y + ARM_TH + 2.0
	_band(-4, top, bottom, wind * 2.0)
	_band(4, top, bottom, wind * 2.0 - 1.0)
	if tied or wind < 0.85:
		return
	var out := (wind - 0.85) / 0.15
	_hang(-2, bottom, 13.0 * out, 0.0)
	_hang(6, bottom, 9.0 * out, 1.3)


## A loop of the cord, standing: lit along its top, dark along its foot, open in the middle.
func _loop(x: float, y: float, w: float, h: float) -> void:
	_f(x + 2.0, y, w - 4.0, 2, CORD_LIGHT)
	_f(x, y + 2.0, 2, h - 4.0, CORD)
	_f(x + w - 2.0, y + 2.0, 2, h - 4.0, CORD_DARK)
	_f(x + 2.0, y + h - 2.0, w - 4.0, 2, CORD_DARK)
	_f(x + 1.0, y + 1.0, 1, 1, CORD)
	_f(x + w - 2.0, y + 1.0, 1, 1, CORD)
	_f(x + 1.0, y + h - 2.0, 1, 1, CORD_DARK)
	_f(x + w - 2.0, y + h - 2.0, 1, 1, CORD_DARK)


## The knot, on top between the two passes, its ends down the front. Hers is small and
## tight; tied together it has a bow's loops, one bigger than the other, and uneven ends.
func _knot(p: float) -> void:
	var kx := -3.0
	var ky := ARM_Y - 13.0
	var lopsided := choice == "together"
	if lopsided:
		_loop(kx - 11.0, ky - 3.0, 13, 10)
		_loop(kx + 10.0, ky + 2.0, 7, 6)
		kx += 1.0
		ky += 1.0
	_f(kx + 1.0, ky, 9, 1, CORD_LIGHT)
	_f(kx, ky + 1.0, 11, 6, CORD)
	_f(kx, ky + 1.0, 11, 1, CORD_LIGHT)
	_f(kx + 1.0, ky + 7.0, 9, 1, CORD_DARK)
	_f(kx, ky + 5.0, 11, 2, CORD_DARK.lerp(CORD, 0.5))
	_f(kx + 3.0, ky + 2.0, 1, 5, CORD_DARK)
	_f(kx + 7.0, ky + 2.0, 1, 5, CORD_DARK)
	_f(kx + 4.0, ky + 2.0, 3, 1, CORD_LIGHT)
	var long := ARM_TH + 20.0
	_hang(kx - 3.0, ky + 5.0, (long - (10.0 if lopsided else 0.0)) * p, 0.0)
	_hang(kx + 11.0, ky + 5.0, (long - (0.0 if lopsided else 5.0)) * p, 1.3)


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
