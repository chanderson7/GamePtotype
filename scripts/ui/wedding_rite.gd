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
			_grid = TABLE_GRID
			_bread_and_salt()
		Cultures.RYUMON:
			_grid = TABLE_GRID
			_three_cups()
		_:
			_grid = FINE
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
## The two table rites are smaller things than two arms and a brazier, so are drawn a
## little larger: this many units across the stage.
const TABLE_GRID := 200.0
var _grid := FINE
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
	var u := size.x / _grid
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
	var u := size.x / _grid
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
## The Kharzani and Ryumon rites are drawn on the same fine grid as the cord (FINE units
## across the stage, from the prop's centre), so a loaf has a crust and a cup a rim.

## A filled oval in fine units, a row at a time: `top` and `bottom` cut it (0 to 1 down
## its height), so a dome, a bowl or a whole loaf come from the one shape.
func _oval(cx: float, cy: float, rx: float, ry: float, c: Color, top: float = 0.0, bottom: float = 1.0) -> void:
	var y0 := int(round(-ry + 2.0 * ry * top))
	var y1 := int(round(-ry + 2.0 * ry * bottom))
	for y in range(y0, y1):
		var half := rx * sqrt(maxf(0.0, 1.0 - pow((y + 0.5) / ry, 2.0)))
		_f(cx - half, cy + y, half * 2.0, 1.0, c)


## A small flame, flickering.
func _flame(x: float, y: float) -> void:
	var lick := sin(_clock * 9.0 + x) * 0.6
	_f(x - 1.5, y - 4.0, 3.0, 4.0, FLAMES[1])
	_f(x - 1.0 + lick * 0.5, y - 6.5, 2.0, 3.0, FLAMES[3])
	_f(x - 0.5 + lick, y - 8.0, 1.0, 2.0, FLAMES[4])
	var u := size.x / _grid
	draw_circle(_origin() + Vector2(x, y - 5.0) * u, 16.0 * u, Color(1.0, 0.62, 0.25, 0.07 + 0.015 * sin(_clock * 7.0)))


## A low carved table under an embroidered runner: a thick top with a lit edge, an apron
## inlaid with brass, turned legs, the cloth's border in her house's colour and its fringe.
func _table_carved() -> void:
	for side in [-1.0, 1.0]:
		var lx := -50.0 if side < 0.0 else 44.0
		_f(lx, 22, 6, 9, WOOD_DARK)
		_f(lx - 1, 25, 8, 2, WOOD)
		_f(lx + 1, 31, 4, 2, WOOD_DARK.darkened(0.3))
	_f(-55, 12, 110, 10, WOOD_DARK)
	_f(-55, 12, 110, 1, WOOD_DARK.darkened(0.35))
	for i in 9:
		var x := -48.0 + i * 12.0
		_f(x, 16, 2, 2, GOLD)
		_f(x - 1, 17, 1, 1, GOLD.darkened(0.3))
		_f(x + 2, 17, 1, 1, GOLD.darkened(0.3))
		_f(x, 15, 1, 1, GOLD_LIGHT)
	_f(-57, 8, 114, 4, WOOD)
	_f(-57, 8, 114, 1, WOOD.lightened(0.25))
	_f(-57, 11, 114, 1, WOOD_DARK)
	# The runner: linen, a border, a thin red line, and a fringe over the table's edge.
	var border := HERS.get(culture, Color("1f7a6e")) as Color
	_f(-38, 6, 76, 3, Color("e9dcc0"))
	_f(-38, 6, 76, 1, Color("f6ecd6"))
	_f(-38, 9, 76, 4, Color("e9dcc0"))
	_f(-38, 10, 76, 1, border)
	_f(-38, 12, 76, 1, Color("c8443c"))
	for i in 26:
		_f(-37.5 + i * 3.0, 13, 1, 2 + (i % 2), Color("d8c8a4"))
	for i in 12:
		_f(-34 + i * 6.0, 7, 2, 1, border.lightened(0.25))


## A brass lamp with its flame, at the table's end.
func _lamp(x: float) -> void:
	_f(x - 3, 3, 6, 2, GOLD.darkened(0.25))
	_f(x - 5, -1, 10, 4, GOLD)
	_f(x - 5, -1, 10, 1, GOLD_LIGHT)
	_f(x - 1, -3, 2, 2, GOLD)
	_f(x + 5, 0, 3, 1, GOLD)
	_flame(x, -3.0)


## The loaf, or the part of it on one side of a tear: a domed flatbread centred on `cx`,
## golden on top, darker under, scored and seeded. `keep` is which side of `tear` is
## drawn (-1 left of it, 1 right, 0 the whole loaf). The torn face follows the dome, pale
## crumb with a ragged edge, so a half looks pulled apart, not sawn.
const RAGGED := [0.0, 1.0, 0.0, -1.0, -1.0, 0.0, 1.0, 1.0, 0.0, -1.0, 0.0, 1.0]

func _loaf(cx: float, rx: float, keep: float = 0.0, tear: float = 0.0) -> void:
	var crust := Color("8a5a24")
	var loaf := Color("c98a3c")
	var crumb := Color("f2d9a6")
	for r in 12:
		var y := -7.0 + r
		var half := rx * sqrt(maxf(0.0, 1.0 - pow((11.5 - r) / 12.0, 2.0)))
		var x0 := cx - half
		var x1 := cx + half
		var edge: float = tear + float(RAGGED[r])
		if keep < 0.0:
			x1 = minf(x1, edge)
		elif keep > 0.0:
			x0 = maxf(x0, edge)
		if x1 - x0 < 1.0:
			continue
		_f(x0, y, x1 - x0, 1, crust)
		var in0 := maxf(x0, cx - half + 1.0)
		var in1 := minf(x1, cx + half - 1.0)
		if r >= 1 and r <= 10 and in1 > in0:
			_f(in0, y, in1 - in0, 1, loaf if r > 6 else loaf.lightened(0.14))
		var top0 := maxf(x0, cx - half * 0.55)
		var top1 := minf(x1, cx + half * 0.2)
		if r >= 1 and r <= 3 and top1 > top0:
			_f(top0, y, top1 - top0, 1, loaf.lightened(0.3))
		# The torn face: crumb three deep along the tear, under a line of crust.
		if keep != 0.0 and r >= 1:
			var f0 := x1 - 3.0 if keep < 0.0 else x0
			var fw := minf(3.0, x1 - x0)
			_f(f0 if keep > 0.0 else x1 - fw, y, fw, 1, crumb if r > 1 else loaf)
			if r % 3 == 2:
				_f((x0 + 1.0) if keep > 0.0 else (x1 - 2.0), y, 1, 1, Color("d9bd84"))
	# Scoring and seeds, where there is loaf to carry them.
	for i in int(rx / 4.0):
		var sx := cx - rx + 6.0 + i * 8.0
		var inside := sx < cx + rx - 6.0 and (keep == 0.0 or (keep < 0.0 and sx + 4.0 < tear - 4.0) or (keep > 0.0 and sx > tear + 4.0))
		if inside:
			_f(sx, -3 + (i % 2), 4, 1, crust)
			_f(sx + 1, -4 + (i % 2), 3, 1, crust.lightened(0.1))
	for i in int(rx / 3.0):
		var px := cx - rx + 5.0 + i * 5.3
		if px < cx + rx - 4.0 and (keep == 0.0 or (keep < 0.0 and px < tear - 4.0) or (keep > 0.0 and px > tear + 4.0)):
			_f(px, 0 + (i * 7) % 4, 1, 1, Color("f4e6b8"))


func _bread_and_salt() -> void:
	_glow()
	if step >= 3:
		# The contract, unrolled behind it all on its rods, signed and sealed.
		var open := _ease(_p) if step == 3 else 1.0
		var w := 86.0 * open
		_f(-w * 0.5, -44, w, 30, PAPER)
		_f(-w * 0.5, -44, w, 1, PAPER.lightened(0.2))
		_f(-w * 0.5, -15, w, 1, PAPER.darkened(0.2))
		for side in [-1.0, 1.0]:
			var rx := -w * 0.5 - 3.0 if side < 0.0 else w * 0.5
			_f(rx, -47, 3, 36, WOOD)
			_f(rx, -47, 1, 36, WOOD.lightened(0.25))
			_f(rx - 1, -49, 5, 2, GOLD)
			_f(rx - 1, -11, 5, 2, GOLD)
		if open > 0.8:
			# The clauses, in a small hand; then the last, short, the one she showed nobody.
			var lines := [58.0, 50.0, 62.0, 44.0, 56.0, 38.0]
			for i in lines.size():
				var lw: float = lines[i]
				var x := -36.0
				var k := 0
				while x < -36.0 + lw:
					var word := 3.0 + ((i * 5 + k * 3) % 5)
					_f(x, -41 + i * 3.6, minf(word, -36.0 + lw - x), 1, INK)
					x += word + 2.0
					k += 1
			_f(-36, -19, 9, 1.5, Color("8c2b2b"))
			# Ribbon and seal.
			_f(26, -24, 3, 12, Color("c8443c").darkened(0.2))
			_f(30, -23, 2, 9, Color("c8443c").darkened(0.3))
			_oval(29.0, -24.0, 6.0, 5.0, Color("b8322a"))
			_oval(28.5, -24.5, 4.0, 3.0, Color("d9584a"))
			_f(26.5, -26.5, 2, 1, Color("f0a090"))
	_table_carved()
	_lamp(-47.0)
	if step == 0:
		_loaf(0.0, 24.0)
	else:
		# Torn in two, the halves drawn apart, crumbs between. Once you've salted a piece
		# for her, it has come off the right half's torn side.
		var apart := 8.0 * (_ease(_p) if step == 1 else 1.0)
		var taken := 0.0 if step < 2 else 7.0 * (_ease(_p) if step == 2 else 1.0)
		_loaf(-apart, 24.0, -1.0, -apart)
		_loaf(apart, 24.0, 1.0, apart + taken)
		for i in 7:
			_f(-5.0 + i * 1.8 + (i % 2), 4 + (i % 3) * 0.5, 1, 1, Color("f2d9a6") if i % 2 == 0 else Color("c98a3c"))
		if step == 2:
			_piece(apart)
	if step >= 2:
		# The salt in its glazed dish.
		_oval(45.0, 0.0, 8.0, 7.0, Color("3b4560"), 0.5, 1.0)
		_oval(45.0, -1.0, 8.0, 7.0, Color("5d6b8a"), 0.5, 0.95)
		_f(37, -1, 16, 1, Color("8fa0c4"))
		_f(40, 2, 4, 1, Color("8fa0c4"))
		_oval(45.0, -1.0, 5.5, 4.0, Color("f4f1ea"), 0.0, 0.5)
		_f(43, -5, 1, 1, Color.WHITE)
		_f(47, -4, 1, 1, Color.WHITE)


## The piece you tear off for her, in your fingers: it leaves the right half's torn side,
## passes under your other hand's pinch of salt, and is held out over the table. It is a
## wedge of that loaf: the crust's curve on top, crumb below, ragged where it was pulled.
func _piece(apart: float) -> void:
	var go := _ease(_p)
	var at := Vector2(apart + 3.0, -1.0).lerp(Vector2(4.0, -24.0), go)
	var x := at.x
	var y := at.y
	# Your arm reaching in from the left: a wool sleeve and its leather cuff, the forearm,
	# the palm under the piece and the thumb over its near corner.
	_f(x - 70, y + 3, 26, 9, WOOL)
	_f(x - 70, y + 3, 26, 1, WOOL.lightened(0.2))
	_f(x - 46, y + 2, 6, 11, LEATHER)
	_f(x - 46, y + 2, 6, 1, LEATHER.lightened(0.25))
	_f(x - 40, y + 4, 34, 7, YOU["base"])
	_f(x - 40, y + 4, 34, 1, YOU["light"])
	_f(x - 40, y + 10, 34, 1, YOU["shade"])
	_f(x - 8, y + 5, 16, 5, YOU["base"])
	_f(x - 8, y + 9, 16, 1, YOU["shade"])
	_f(x + 7, y + 6, 2, 3, YOU["base"])
	for k in 3:
		_f(x - 3 + k * 4.0, y + 7, 1, 3, YOU["line"])
	# The wedge.
	var crust := Color("8a5a24")
	var loaf := Color("c98a3c")
	var crumb := Color("f2d9a6")
	var rows := [[-3.0, 6.0], [-5.0, 9.0], [-6.0, 11.0], [-6.0, 11.0], [-5.0, 10.0], [-5.0, 9.0], [-4.0, 8.0], [-4.0, 7.0]]
	for r in rows.size():
		var x0: float = rows[r][0]
		var w: float = rows[r][1]
		_f(x + x0, y - 3 + r, w, 1, crust if r == 0 else (loaf.lightened(0.14) if r == 1 else crumb))
		if r >= 2:
			_f(x + x0 + w - 1.0, y - 3 + r, 1, 1, loaf)
	_f(x - 2, y + 1, 1, 1, Color("d9bd84"))
	_f(x + 1, y + 3, 1, 1, Color("d9bd84"))
	_f(x - 8, y + 1, 5, 4, YOU["light"])
	_f(x - 8, y + 1, 5, 1, YOU["base"])
	_f(x - 4, y + 2, 1, 2, YOU["line"])
	# The salt: falling while it's lifted, lying on it after.
	if go > 0.25:
		for g in [[-3.0, -1.0], [0.0, 0.0], [2.0, -1.0], [-1.0, 1.0]]:
			_f(x + float(g[0]), y + float(g[1]), 1, 1, Color.WHITE)
	if _p < 1.0:
		for i in 4:
			_f(x - 3.0 + i * 2.0, y - 10.0 + fposmod(_clock * 22.0 + i * 3.0, 7.0), 1, 1, Color(1, 1, 1, 0.8))


# ---------------------------------------------------------------- Ryumon: three cups

## A low table of black lacquer: a red edge, a sheen along the top, gold sprinkled in the
## lacquer, legs that curve in.
func _table_lacquer() -> void:
	var black := Color("1e1a22")
	for side in [-1.0, 1.0]:
		var lx := -50.0 if side < 0.0 else 45.0
		_f(lx, 20, 5, 8, Color("15121a"))
		_f(lx + side * -1.0, 28, 5, 3, Color("15121a"))
		_f(lx, 20, 1, 8, Color("2e2833"))
	_f(-55, 11, 110, 9, black)
	_f(-55, 19, 110, 1, Color("0f0d12"))
	_f(-55, 11, 110, 1, Color("8c2b2b"))
	_f(-57, 7, 114, 4, Color("2e2833"))
	_f(-57, 7, 114, 1, Color("4a4352"))
	_f(-30, 8, 34, 1, Color("5c5466"))
	for i in 14:
		_f(-50.0 + i * 7.5 + (i % 3), 13 + (i * 5) % 5, 1, 1, GOLD if i % 2 == 0 else GOLD.darkened(0.3))
	# A plum branch in gold along the apron.
	for i in 6:
		_f(18.0 + i * 4.0, 16 - (i % 2), 4, 1, GOLD.darkened(0.2))
	for b in [[22.0, 13.0], [30.0, 14.0], [37.0, 13.0]]:
		_f(float(b[0]), float(b[1]), 2, 2, Color("e8a0a8"))


## One of the three cups, a shallow red-lacquer saucer on a small foot, `rx` wide: full,
## or drunk and turned down with its foot on top (`tip` 0 to 1 as it settles).
func _cup(cx: float, rx: float, down: bool, tip: float) -> void:
	var red := Color("a8261c")
	var deep := Color("6e1c16")
	if down:
		var y := 7.0 - 5.0 * (1.0 - tip)
		_oval(cx, y, rx, 5.0, deep, 0.0, 0.5)
		_oval(cx, y, rx - 1.0, 4.0, red, 0.0, 0.5)
		_f(cx - rx * 0.5, y - 3.5, rx * 0.5, 1, Color("d9584a"))
		_f(cx - 2.5, y - 7, 5, 2, deep)
		_f(cx - 2.5, y - 7, 5, 1, GOLD)
		_f(cx - rx, y - 1, rx * 2.0, 1, GOLD.darkened(0.2))
	else:
		_f(cx - 2.5, 5, 5, 2, deep)
		_oval(cx, 0.0, rx, 5.0, deep, 0.5, 1.0)
		_oval(cx, -0.5, rx - 1.0, 4.5, red, 0.5, 1.0)
		# The rim, the sake in it, and a glint.
		_f(cx - rx, -1, rx * 2.0, 1, GOLD)
		_f(cx - rx + 2.0, 0, rx * 2.0 - 4.0, 1, Color("efe9d8"))
		_f(cx - rx + 3.0, 0, 3, 1, Color.WHITE)
		_f(cx + rx * 0.3, 2.5, rx * 0.4, 1, Color("d9584a"))


func _three_cups() -> void:
	_glow()
	if step >= 3:
		# The register, opened on its stand behind the cups: ruled columns, a red seal.
		var open := _ease(_p) if step == 3 else 1.0
		var w := 40.0 * open
		_f(-3, -12, 6, 20, Color("2e2833"))
		_f(-w - 2.0, -15, w * 2.0 + 4.0, 2, Color("8a7a5a"))
		_f(-w, -40, w, 26, PAPER)
		_f(0, -40, w, 26, PAPER.darkened(0.06))
		_f(-w, -40, w * 2.0, 1, PAPER.lightened(0.2))
		_f(-1, -40, 2, 26, Color("c9b98e"))
		if open > 0.8:
			for i in 4:
				_f(-34.0 + i * 8.0, -38, 0.6, 22, Color("d9cba0"))
				_f(8.0 + i * 8.0, -38, 0.6, 22, Color("cfc198"))
			# Names written before yours, faint, at the pages' outer edges.
			for i in 6:
				_f(-33, -37 + i * 3.4, 2 + (i % 2), 2, Color(INK, 0.45))
				_f(33 - (i % 2), -37 + i * 3.4, 2 + (i % 2), 2, Color(INK, 0.45))
		if step >= 4:
			# Your names, written in: a column of brush strokes on each page, and the seal.
			var ink := _ease(_p)
			for i in int(6 * ink):
				var wide := 3.0 + ((i * 3) % 3)
				_f(-16 - wide * 0.5, -37 + i * 3.4, wide, 2, INK)
				_f(-16 + ((i % 2) * 2.0 - 1.0), -36 + i * 3.4, 1, 2, INK)
				_f(16 - wide * 0.5, -37 + i * 3.4, wide, 2, INK)
				_f(16 - ((i % 2) * 2.0 - 1.0), -36 + i * 3.4, 1, 2, INK)
			if ink > 0.9:
				_f(13, -17, 6, 2, Color("b8322a"))
				_f(-19, -17, 6, 2, Color("b8322a"))
	_table_lacquer()
	# The ewer the sake is poured from: gold, long-handled, at the table's end.
	_oval(-44.0, 2.0, 7.0, 6.0, GOLD.darkened(0.25))
	_oval(-44.5, 1.5, 6.0, 5.0, GOLD)
	_f(-47, -2, 3, 2, GOLD_LIGHT)
	_f(-38, -1, 6, 1, GOLD)
	_f(-33, -2, 2, 1, GOLD)
	_f(-46, -9, 1, 6, GOLD.darkened(0.2))
	_f(-46, -10, 6, 1, GOLD.darkened(0.2))
	_f(-41, -9, 1, 4, GOLD.darkened(0.2))
	# The brush on its rest and the inkstone, at the other end.
	_f(40, 3, 12, 4, Color("2a2e3a"))
	_f(41, 4, 7, 2, Color("0f1016"))
	_f(40, 3, 12, 1, Color("4a5060"))
	_f(34, -2, 16, 1, Color("c8a878"))
	_f(31, -2, 3, 1, INK)
	_f(30, -1, 2, 1, INK)
	var turned := mini(step, 3)
	for i in 3:
		# Small, middle, great: each cup wider than the last.
		var rx := 7.0 + i * 2.0
		var x := -20.0 + i * 19.0
		if i < turned:
			_cup(x, rx, true, _ease(_p) if i == turned - 1 and step <= 3 else 1.0)
		else:
			_cup(x, rx, false, 1.0)
	# A petal or two come in from the garden and settle on the lacquer.
	for i in 3:
		var fall := fposmod(_clock * 0.12 + i * 0.37, 1.0)
		_f(-30.0 + i * 31.0 + sin(_clock * 0.9 + i) * 4.0, -46.0 + fall * 52.0, 2, 1, Color(0.95, 0.72, 0.78, 0.8 * sin(fall * PI)))
