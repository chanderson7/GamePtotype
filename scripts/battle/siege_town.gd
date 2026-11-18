## The place under siege, drawn in the field's own big pixels: a wall with a walk, merlons
## and a shaded face, towers and a gatehouse in the land's own build, the keep and houses
## under their roofs, a street from the gate to the keep and a square across it. The still
## part is painted once into a texture (bake); what the fight does to it (spent arrows,
## scorched ground, chipped battlements, roofs alight, smoke) is drawn over it each frame
## from how far the fight has gone (draw_wear, draw_fires).
##
## Only the buildings the sim already blocks stand on the field; houses beyond its edges
## are scenery, so nothing here changes where a man can walk.
extends RefCounted

const Terrain = preload("res://scripts/battle/terrain.gd")

## One painted pixel is this many field units, and the painting starts here.
const PX := 2.0
const ORIGIN := Vector2(-150.0, -60.0)
const WIDE := 570
const OUTLINE := Color("26221e")

## What each land builds its houses of: ground, street, two roofs [lit, shaded], whether
## roofs are flat, and the walls seen at a roof's foot.
const LOOKS := {
	"vardish": {"ground": Color("7d7355"), "street": Color("a09478"), "flat": false, "wall": Color("d8cdb0"),
		"roofs": [[Color("a2473a"), Color("7a3028")], [Color("b0603c"), Color("84422a")], [Color("9a7a44"), Color("72582e")]],
		"tower_roof": [Color("a2473a"), Color("7a3028")], "plot": Color("5d7a3c")},
	"kharzani": {"ground": Color("c2a06a"), "street": Color("d8bc8a"), "flat": true, "wall": Color("e8dcc4"),
		"roofs": [[Color("e8dcc4"), Color("c4b494")], [Color("dcc8a0"), Color("b8a078")], [Color("f0e6d0"), Color("ccbc9c")]],
		"tower_roof": [Color("3a8a8a"), Color("286464")], "plot": Color("7a8a44")},
	"ryumon": {"ground": Color("7c7a70"), "street": Color("a8a498"), "flat": false, "wall": Color("f0ece2"),
		"roofs": [[Color("3c3c4a"), Color("2a2a34")], [Color("4a4650"), Color("34303a")], [Color("44505a"), Color("2e3840")]],
		"tower_roof": [Color("3c3c4a"), Color("2a2a34")], "plot": Color("5a7a4a")},
}


static func _h(a: int, b: int) -> float:
	var n := (a * 374761393 + b * 668265263) & 0x7fffffff
	n = ((n ^ (n >> 13)) * 1274126177) & 0x7fffffff
	return float(n & 0xffff) / 65535.0


static func _f(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	img.fill_rect(Rect2i(x, y, w, h).intersection(Rect2i(0, 0, img.get_width(), img.get_height())), c)


## Darken what is already painted (a shadow lying on it).
static func _shade(img: Image, x: int, y: int, w: int, h: int, by: float) -> void:
	var r := Rect2i(x, y, w, h).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	for py in range(r.position.y, r.end.y):
		for px in range(r.position.x, r.end.x):
			var c := img.get_pixel(px, py)
			if c.a > 0.0:
				img.set_pixel(px, py, Color(c.darkened(by), c.a))
			else:
				img.set_pixel(px, py, Color(0, 0, 0, by * 0.9))


## Paint the place. `castle_style` is the screen's CASTLE_STYLES entry, `buildings` the
## sim's own (as laid out for a garrison at the top of the field), `flip` when the garrison
## holds the bottom instead. Returns the texture, where it goes, and what can burn or smoke.
static func bake(castle_style: Dictionary, culture: String, buildings: Array, wall_row: int, tower_cols: Array, gate_cols: Array, flip: bool) -> Dictionary:
	var lk: Dictionary = LOOKS.get(culture, LOOKS["vardish"])
	var st := castle_style
	var cell := int(Terrain.CELL / PX)
	var ox := int(-ORIGIN.x / PX)
	var oy := int(-ORIGIN.y / PX)
	var wall := oy + wall_row * cell
	var tall := wall + cell + 5
	var img := Image.create_empty(WIDE, tall, false, Image.FORMAT_RGBA8)
	var walk := 20
	# The ground inside: packed earth, flecked.
	var ground: Color = lk["ground"]
	_f(img, 0, 0, WIDE, wall - walk, ground)
	for y in range(0, wall - walk, 2):
		for x in range(0, WIDE, 2):
			var v := _h(x, y)
			if v < 0.1:
				_f(img, x, y, 2, 1, ground.darkened(0.08))
			elif v > 0.93:
				_f(img, x, y, 1, 1, ground.lightened(0.1))
	# The street from the gate to the keep, and the square across it.
	var street: Color = lk["street"]
	var gx0 := ox + int(gate_cols[0]) * cell
	var gw := gate_cols.size() * cell
	var lanes := [Rect2i(gx0 - 2, 0, gw + 4, wall - walk), Rect2i(ox + 4 * cell, oy + 7 * cell, 20 * cell, 3 * cell)]
	for lane in lanes:
		_f(img, lane.position.x, lane.position.y, lane.size.x, lane.size.y, street)
		for y in range(lane.position.y, lane.end.y, 3):
			for x in range(lane.position.x + ((y / 3) % 2) * 2, lane.end.x, 4):
				var v2 := _h(x * 3, y * 5)
				if v2 < 0.3:
					_f(img, x, y, 3, 2, street.darkened(0.07))
				elif v2 > 0.88:
					_f(img, x, y, 2, 1, street.lightened(0.09))
	# Kitchen plots in the open corners, rows of green.
	var plot: Color = lk["plot"]
	for p in [Rect2i(ox + 1 * cell, oy + 11 * cell, 4 * cell, 2 * cell), Rect2i(ox + 23 * cell, oy + 11 * cell, 4 * cell, 2 * cell),
			Rect2i(ox + 6 * cell, oy + 4 * cell + 6, 3 * cell, cell), Rect2i(ox + 19 * cell, oy + 4 * cell + 6, 3 * cell, cell)]:
		_f(img, p.position.x, p.position.y, p.size.x, p.size.y, ground.darkened(0.16))
		for y in range(p.position.y + 1, p.end.y - 1, 3):
			_f(img, p.position.x + 1, y, p.size.x - 2, 1, plot)
			for x in range(p.position.x + 1, p.end.x - 1, 3):
				if _h(x, y) > 0.5:
					_f(img, x, y, 1, 1, plot.lightened(0.2))
	# A well in the square.
	var wx := gx0 + gw / 2 - 3
	var wy := oy + 8 * cell + 4
	_f(img, wx - 1, wy - 1, 8, 8, OUTLINE)
	_f(img, wx, wy, 6, 6, st["light"])
	_f(img, wx + 1, wy + 1, 4, 4, Color("2f4a66"))
	_f(img, wx + 1, wy + 1, 2, 1, Color("5a7a9a"))
	# Buildings: the sim's own, then scenery beyond the field's edges.
	var burnable: Array = []
	var chimneys: Array = []
	var n := 0
	for b in buildings:
		var cr: Rect2i = b["cell"]
		var r := Rect2i(ox + cr.position.x * cell + 1, oy + cr.position.y * cell + 1, cr.size.x * cell - 2, cr.size.y * cell - 2)
		if String(b["kind"]) == "keep":
			_keep(img, r, st, lk)
		else:
			_house(img, r, lk, n, chimneys)
			burnable.append(r)
			n += 1
	var side := [Rect2i(6, 34, 34, 22), Rect2i(44, 30, 24, 30), Rect2i(8, 66, 26, 32), Rect2i(40, 70, 28, 22), Rect2i(6, 108, 36, 22),
		Rect2i(46, 104, 22, 30), Rect2i(10, 142, 28, 26), Rect2i(44, 146, 24, 20), Rect2i(6, 178, 30, 22), Rect2i(42, 176, 26, 28),
		Rect2i(8, 212, 34, 22), Rect2i(48, 214, 20, 20)]
	for r in side:
		_house(img, r, lk, n, chimneys)
		burnable.append(r)
		n += 1
		var m := Rect2i(WIDE - r.end.x, r.position.y + ((n * 5) % 7) - 3, r.size.x, r.size.y)
		_house(img, m, lk, n + 40, chimneys)
		burnable.append(m)
		n += 1
	for i in 9:
		var x := 6 + i * 64 + int(_h(i, 7) * 14.0)
		if absi(x + 20 - (gx0 + gw / 2)) < 70:
			continue
		_house(img, Rect2i(x, 2 + int(_h(i, 3) * 4.0), 30 + int(_h(i, 9) * 16.0), 20), lk, n + 80, chimneys)
		n += 1
	# The wall: its walk, then the parapet and the face men look at from the field.
	var stone: Color = st["stone"]
	var light: Color = st["light"]
	var dark: Color = st["dark"]
	var deep := dark.darkened(0.3)
	_shade(img, 0, wall - walk - 3, WIDE, 3, 0.25)
	_f(img, 0, wall - walk, WIDE, walk, st["walk"])
	_f(img, 0, wall - walk, WIDE, 2, light)
	_f(img, 0, wall - walk - 1, WIDE, 1, OUTLINE)
	for y in range(wall - walk + 2, wall, 4):
		_f(img, 0, y + 3, WIDE, 1, Color(st["walk"]).darkened(0.12))
		for x in range(((y / 4) % 2) * 4, WIDE, 8):
			_f(img, x, y, 1, 3, Color(st["walk"]).darkened(0.12))
	_f(img, 0, wall, WIDE, 6, stone)
	_f(img, 0, wall + 6, WIDE, cell - 6, dark)
	for i in range(0, cell - 6, 3):
		_f(img, 0, wall + 8 + i, WIDE, 1, deep)
		for x in range((i / 3 % 2) * 4, WIDE, 8):
			_f(img, x, wall + 6 + i, 1, 2, deep)
	for x in range(0, WIDE, 5):
		_f(img, x, wall, 3, 5, light)
		_f(img, x + 2, wall, 1, 5, stone.lightened(0.08))
		_f(img, x, wall + 5, 3, 1, stone.darkened(0.1))
	_f(img, 0, wall + cell, WIDE, 1, OUTLINE)
	_shade(img, 0, wall + cell + 1, WIDE, 3, 0.3)
	# The gate's passage, dark under its arch (the gate itself is drawn live).
	_f(img, gx0, wall, gw, cell, Color("1c1814"))
	# Towers along the wall (and one past each edge of the field), and the gatehouse.
	var cols := tower_cols.duplicate()
	cols.append_array([-4, 31])
	for tc in cols:
		_tower(img, ox + int(tc) * cell - 3, wall - 7, cell + 6, cell + 6, 9, st, lk)
	_tower(img, gx0 - 17, wall - 9, 15, cell + 8, 10, st, lk)
	_tower(img, gx0 + gw + 2, wall - 9, 15, cell + 8, 10, st, lk)
	_f(img, gx0 - 2, wall - 4, gw + 4, 4, OUTLINE)
	_f(img, gx0 - 2, wall - 3, gw + 4, 3, light)
	if flip:
		img.flip_y()
	var size := Vector2(WIDE, tall) * PX
	var at := ORIGIN if not flip else Vector2(ORIGIN.x, Terrain.ARENA.y - ORIGIN.y - size.y)
	var out_burn: Array = []
	for r in burnable:
		out_burn.append(_real(r, at, tall, flip))
	var out_smoke: Array = []
	for c in chimneys:
		var rr := _real(Rect2i(c, Vector2i(2, 2)), at, tall, flip)
		out_smoke.append(rr.get_center())
	return {"texture": ImageTexture.create_from_image(img), "rect": Rect2(at, size), "houses": out_burn, "chimneys": out_smoke}


static func _real(r: Rect2i, at: Vector2, tall: int, flip: bool) -> Rect2:
	var y := float(r.position.y) if not flip else float(tall - r.end.y)
	return Rect2(at + Vector2(r.position.x, y) * PX, Vector2(r.size) * PX)


static func _house(img: Image, r: Rect2i, lk: Dictionary, n: int, chimneys: Array) -> void:
	var pair: Array = lk["roofs"][n % 3]
	var a: Color = pair[0]
	var b: Color = pair[1]
	_shade(img, r.position.x + 2, r.end.y, r.size.x, 3, 0.3)
	_shade(img, r.end.x, r.position.y + 3, 2, r.size.y - 3, 0.3)
	_f(img, r.position.x - 1, r.position.y - 1, r.size.x + 2, r.size.y + 2, OUTLINE)
	if lk["flat"]:
		# A flat roof inside a low parapet, with a stair hatch; now and then a small dome.
		_f(img, r.position.x, r.position.y, r.size.x, r.size.y, a)
		_f(img, r.position.x + 2, r.position.y + 2, r.size.x - 4, r.size.y - 4, b)
		_f(img, r.position.x + 2, r.position.y + 2, r.size.x - 4, 1, b.darkened(0.15))
		_f(img, r.position.x + 2, r.position.y + 2, 1, r.size.y - 4, b.darkened(0.15))
		_f(img, r.end.x - 7, r.end.y - 7, 4, 4, Color("5a4630"))
		if n % 3 == 0 and r.size.x > 16 and r.size.y > 14:
			var c := r.position + Vector2i(7, r.size.y / 2)
			var tr: Array = lk["tower_roof"]
			for dy in range(-4, 5):
				var half := int(sqrt(16.0 - float(dy * dy)))
				_f(img, c.x - half, c.y + dy, half * 2 + 1, 1, tr[0] if dy < 1 else tr[1])
			_f(img, c.x - 2, c.y - 2, 2, 2, Color(tr[0]).lightened(0.3))
		return
	# A pitched roof, its ridge along the longer side: the near slope lit, the far in shade.
	var along := r.size.x >= r.size.y
	if along:
		var hy := r.size.y / 2
		_f(img, r.position.x, r.position.y, r.size.x, hy, a)
		_f(img, r.position.x, r.position.y + hy, r.size.x, r.size.y - hy, b)
		for x in range(r.position.x + 3, r.end.x, 4):
			_f(img, x, r.position.y, 1, hy, a.darkened(0.1))
			_f(img, x - 2, r.position.y + hy, 1, r.size.y - hy, b.darkened(0.14))
		_f(img, r.position.x, r.position.y + hy - 1, r.size.x, 1, a.lightened(0.25))
		_f(img, r.position.x, r.end.y - 1, r.size.x, 1, lk["wall"])
	else:
		var hx := r.size.x / 2
		_f(img, r.position.x, r.position.y, hx, r.size.y, a)
		_f(img, r.position.x + hx, r.position.y, r.size.x - hx, r.size.y, b)
		for y in range(r.position.y + 3, r.end.y, 4):
			_f(img, r.position.x, y, hx, 1, a.darkened(0.1))
			_f(img, r.position.x + hx, y - 2, r.size.x - hx, 1, b.darkened(0.14))
		_f(img, r.position.x + hx - 1, r.position.y, 1, r.size.y, a.lightened(0.25))
		_f(img, r.position.x, r.end.y - 1, r.size.x, 1, lk["wall"])
	var ch := Vector2i(r.end.x - 6, r.position.y + 2)
	_f(img, ch.x - 1, ch.y - 1, 4, 4, OUTLINE)
	_f(img, ch.x, ch.y, 2, 2, Color("6a5e52"))
	_f(img, ch.x, ch.y, 2, 1, Color("8a7e70"))
	chimneys.append(ch)


static func _keep(img: Image, r: Rect2i, st: Dictionary, lk: Dictionary) -> void:
	var stone: Color = st["stone"]
	var light: Color = st["light"]
	var dark: Color = st["dark"]
	_shade(img, r.position.x + 3, r.end.y, r.size.x, 4, 0.32)
	_shade(img, r.end.x, r.position.y + 4, 3, r.size.y - 4, 0.32)
	_f(img, r.position.x - 1, r.position.y - 1, r.size.x + 2, r.size.y + 2, OUTLINE)
	_f(img, r.position.x, r.position.y, r.size.x, r.size.y, stone)
	for x in range(r.position.x, r.end.x - 2, 5):
		_f(img, x, r.position.y, 3, 3, light)
		_f(img, x, r.end.y - 3, 3, 3, light)
	for y in range(r.position.y, r.end.y - 2, 5):
		_f(img, r.position.x, y, 3, 3, light)
		_f(img, r.end.x - 3, y, 3, 3, light)
	var inner := r.grow(-5)
	_f(img, inner.position.x - 1, inner.position.y - 1, inner.size.x + 2, inner.size.y + 2, dark)
	var tr: Array = lk["tower_roof"]
	if st["dome"]:
		_f(img, inner.position.x, inner.position.y, inner.size.x, inner.size.y, st["top"])
		var c := inner.get_center()
		var rad := mini(inner.size.x, inner.size.y) / 2 - 1
		for dy in range(-rad, rad + 1):
			var half := int(sqrt(float(rad * rad - dy * dy)))
			_f(img, c.x - half, c.y + dy, half * 2 + 1, 1, tr[0] if dy < rad / 3 else tr[1])
		_f(img, c.x - rad / 2, c.y - rad / 2, 3, 3, Color(tr[0]).lightened(0.35))
		_f(img, c.x, c.y, 1, 1, Color("e8d48a"))
	elif st["tiers"]:
		var t := inner
		for k in 3:
			_f(img, t.position.x, t.position.y, t.size.x, t.size.y, tr[1] if k % 2 == 0 else tr[0])
			_f(img, t.position.x, t.position.y, t.size.x, 1, Color(tr[0]).lightened(0.2))
			_f(img, t.position.x, t.end.y - 1, t.size.x, 1, st["light"])
			t = t.grow(-4)
	else:
		var hy := inner.size.y / 2
		_f(img, inner.position.x, inner.position.y, inner.size.x, hy, st["roof_light"])
		_f(img, inner.position.x, inner.position.y + hy, inner.size.x, inner.size.y - hy, st["roof"])
		for x in range(inner.position.x + 3, inner.end.x, 4):
			_f(img, x, inner.position.y, 1, inner.size.y, Color(st["roof"]).darkened(0.12))
		_f(img, inner.position.x, inner.position.y + hy - 1, inner.size.x, 1, Color(st["roof_light"]).lightened(0.25))
	# A turret on each corner.
	for corner in [r.position, Vector2i(r.end.x - 9, r.position.y), Vector2i(r.position.x, r.end.y - 9), r.end - Vector2i(9, 9)]:
		_f(img, corner.x - 1, corner.y - 1, 11, 11, OUTLINE)
		_f(img, corner.x, corner.y, 9, 9, light)
		_f(img, corner.x + 2, corner.y + 2, 5, 5, tr[0])
		_f(img, corner.x + 4, corner.y + 4, 3, 3, tr[1])
	# The door, facing the street.
	_f(img, r.get_center().x - 3, r.end.y - 5, 6, 5, OUTLINE)
	_f(img, r.get_center().x - 2, r.end.y - 4, 4, 4, Color("6a4a2c"))


## A tower: its top `w` by `top` with a ring of merlons, a face `face` deep below it with
## an arrow slit, and the land's own roof.
static func _tower(img: Image, x: int, y: int, w: int, top: int, face: int, st: Dictionary, lk: Dictionary) -> void:
	var stone: Color = st["stone"]
	var light: Color = st["light"]
	var dark: Color = st["dark"]
	var deep := dark.darkened(0.3)
	_shade(img, x + 2, y + top + face, w, 3, 0.3)
	_f(img, x - 1, y - 1, w + 2, top + face + 2, OUTLINE)
	_f(img, x, y, w, top, stone)
	_f(img, x, y + top, w, face, dark)
	for i in range(2, face, 3):
		_f(img, x, y + top + i, w, 1, deep)
	_f(img, x + w / 2 - 1, y + top + 2, 2, face - 4, OUTLINE)
	for mx in range(x, x + w - 1, 4):
		_f(img, mx, y, 3, 2, light)
		_f(img, mx, y + top - 3, 3, 3, light)
	for my in range(y + 3, y + top - 4, 4):
		_f(img, x, my, 2, 3, light)
		_f(img, x + w - 2, my, 2, 3, light)
	var tr: Array = lk["tower_roof"]
	var m := 4
	var rw := w - 2 * m
	var rh := top - 2 * m - 1
	if st["round"]:
		var c := Vector2i(x + w / 2, y + top / 2)
		var rad := mini(rw, rh) / 2
		for dy in range(-rad, rad + 1):
			var half := int(sqrt(float(rad * rad - dy * dy)))
			_f(img, c.x - half, c.y + dy, half * 2 + 1, 1, tr[0] if dy < 1 else tr[1])
		_f(img, c.x - rad / 2, c.y - rad / 2, 2, 2, Color(tr[0]).lightened(0.35))
	else:
		_f(img, x + m - 1, y + m - 1, rw + 2, rh + 2, OUTLINE)
		_f(img, x + m, y + m, rw, rh, tr[0])
		for i in mini(rw, rh) / 2:
			_f(img, x + m + rw - 1 - i, y + m + i, 1, rh - 2 * i, tr[1])
			_f(img, x + m + i, y + m + rh - 1 - i, rw - 2 * i, 1, tr[1])
			_f(img, x + m + i, y + m + i, rw - 2 * i, 1, Color(tr[0]).lightened(0.1))
		_f(img, x + w / 2 - 1, y + m + rh / 2 - 1, 2, 2, Color("e8d48a"))


# ---------------------------------------------------------------- what the fight does

static func _snap(v: Vector2) -> Vector2:
	return (v / PX).floor() * PX


## The ground before the wall as the fight goes on (`wear` 0..1): trampled dark, scorched in
## patches, stuck with spent arrows. `outward` is +1 when the field lies below the wall.
static func draw_wear(c: CanvasItem, wear: float, wall_edge: float, outward: float) -> void:
	if wear <= 0.02:
		return
	var w := Terrain.ARENA.x
	var deep := 150.0
	var band := Rect2(0.0, wall_edge if outward > 0.0 else wall_edge - deep, w, deep)
	for i in 12:
		var fade := 1.0 - float(i) / 12.0
		var y := band.position.y + (float(i) if outward > 0.0 else float(11 - i)) * deep / 12.0
		c.draw_rect(Rect2(0.0, y, w, deep / 12.0), Color(0.16, 0.12, 0.08, 0.2 * wear * fade))
	for i in int(wear * 9.0):
		var at := _snap(Vector2(20.0 + _h(i, 51) * (w - 60.0), band.position.y + 16.0 + _h(i, 52) * (deep - 40.0)))
		var sz := 14.0 + _h(i, 53) * 16.0
		c.draw_rect(Rect2(at, Vector2(sz, 8.0)), Color(0.1, 0.08, 0.07, 0.42))
		c.draw_rect(Rect2(at + Vector2(4.0, -4.0), Vector2(sz - 8.0, 16.0)), Color(0.1, 0.08, 0.07, 0.3))
	for i in int(wear * 90.0):
		var near := _h(i, 61)
		var at2 := _snap(Vector2(6.0 + _h(i, 62) * (w - 12.0), wall_edge + outward * (6.0 + near * near * (deep - 12.0))))
		c.draw_rect(Rect2(at2, Vector2(PX, PX * 3.0)), Color("d8d0b8"))
		c.draw_rect(Rect2(at2 + (Vector2.ZERO if outward > 0.0 else Vector2(0, PX * 2.0)), Vector2(PX, PX)), Color("8a3a30"))


## Merlons knocked off the parapet as the wall takes stones (`wear` 0..1). `parapet` is the
## parapet's top edge.
static func draw_chips(c: CanvasItem, wear: float, parapet: float, stone: Color, skip: Rect2) -> void:
	for i in int(wear * 22.0):
		var x := floorf(_h(i, 71) * (Terrain.ARENA.x - 12.0) / 10.0) * 10.0
		if x > skip.position.x - 40.0 and x < skip.end.x + 40.0:
			continue
		c.draw_rect(Rect2(x, parapet, 10.0 + floorf(_h(i, 72) * 2.0) * 10.0, 10.0), stone.darkened(0.12))
		c.draw_rect(Rect2(x + 2.0, parapet + 6.0, 4.0, 4.0), stone.darkened(0.4))


## Roofs alight, more of them as `heat` (0..1) climbs, each under its own smoke; and the
## thin smoke of cook fires until then. `still` holds the flames and smoke in place.
static func draw_fires(c: CanvasItem, town: Dictionary, heat: float, clock: float, still: bool) -> void:
	var houses: Array = town["houses"]
	var lit := {}
	if not houses.is_empty():
		for k in 6:
			if heat > 0.3 + float(k) * 0.11:
				lit[int(_h(k, 91) * 997.0) % houses.size()] = k
	for idx in lit:
		var r: Rect2 = houses[idx]
		var k: int = lit[idx]
		c.draw_rect(r.grow(-2.0), Color(0.08, 0.06, 0.05, 0.55))
		var frame := 0 if still else int(clock * 6.0 + float(k) * 1.7)
		for f in 7:
			var at := _snap(r.position + Vector2(_h(f + frame / 3, k * 7 + 1) * (r.size.x - 8.0), _h(f, k * 7 + 2) * (r.size.y - 10.0)))
			var tall := PX * (2.0 + float((f + frame) % 3))
			c.draw_rect(Rect2(at + Vector2(0, PX * 4.0 - tall), Vector2(PX * 3.0, tall)), Color("e8632a"))
			c.draw_rect(Rect2(at + Vector2(PX, PX * 5.0 - tall), Vector2(PX, tall - PX)), Color("f8d05a"))
		_plume(c, r.get_center() + Vector2(0, -r.size.y * 0.3), clock + float(k) * 0.37, still, 9, 130.0, Color(0.16, 0.14, 0.13), 0.6)
	var chimneys: Array = town["chimneys"]
	for i in chimneys.size():
		if i % 4 == 0 and heat < 0.6:
			_plume(c, chimneys[i], clock * 0.6 + float(i) * 0.21, still, 4, 44.0, Color(0.86, 0.86, 0.84), 0.5)


static func _plume(c: CanvasItem, from: Vector2, clock: float, still: bool, puffs: int, rise: float, tone: Color, alpha: float) -> void:
	for i in puffs:
		var t := fmod((0.0 if still else clock * 0.35) + float(i) / float(puffs), 1.0)
		var at := _snap(from + Vector2(t * rise * 0.45 + sin(t * 9.0 + float(i)) * 4.0, -t * rise))
		var sz := PX * (2.0 + floorf(t * 6.0))
		c.draw_rect(Rect2(at - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), Color(tone.lightened(t * 0.25), alpha * (1.0 - t)))


## The besiegers' camp in the margins beside their end of the field: tents and a fire.
static func draw_camp(c: CanvasItem, far_y: float, toward: float, clock: float, still: bool) -> void:
	for side in [-1.0, 1.0]:
		for i in 4:
			var x := (-34.0 - float(i % 2) * 46.0) if side < 0.0 else (Terrain.ARENA.x + 12.0 + float(i % 2) * 46.0)
			var at := _snap(Vector2(x - (22.0 if side < 0.0 else 0.0), far_y - toward * (90.0 + float(i) * 84.0 + _h(i, 33) * 20.0)))
			c.draw_rect(Rect2(at + Vector2(4, 6), Vector2(40, 32)), Color(0, 0, 0, 0.25))
			c.draw_rect(Rect2(at - Vector2(2, 2), Vector2(44, 36)), OUTLINE)
			c.draw_rect(Rect2(at, Vector2(20, 32)), Color("d8cdb0"))
			c.draw_rect(Rect2(at + Vector2(20, 0), Vector2(20, 32)), Color("a89c80"))
			c.draw_rect(Rect2(at + Vector2(18, 0), Vector2(4, 32)), Color("f0e8d0"))
			c.draw_rect(Rect2(at + Vector2(16, 22), Vector2(8, 10)), Color("3a2c20"))
		var fire := _snap(Vector2(-60.0 if side < 0.0 else Terrain.ARENA.x + 56.0, far_y - toward * 140.0))
		var flick := 0.0 if still else float(int(clock * 5.0) % 2) * PX
		c.draw_rect(Rect2(fire - Vector2(2, 0), Vector2(12, 4)), Color("3a2c20"))
		c.draw_rect(Rect2(fire + Vector2(0, -6.0 - flick), Vector2(8, 6.0 + flick)), Color("e8632a"))
		c.draw_rect(Rect2(fire + Vector2(2, -4.0 - flick), Vector2(4, 4.0 + flick)), Color("f8d05a"))
		_plume(c, fire + Vector2(4, -8), clock * 0.6 + side, still, 4, 50.0, Color(0.8, 0.8, 0.78), 0.45)
