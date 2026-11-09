## Flags and troop glyphs, drawn in code so the battle's standards, the squad cards and
## the map's party pennants all share one look. Call these from inside a CanvasItem's
## draw callback, passing that CanvasItem.
extends RefCounted

const Troops = preload("res://scripts/data/troops.gd")
const Style = preload("res://scripts/ui/style.gd")
const WorldData = preload("res://scripts/world/world_data.gd")

const EDGE := Color(0.06, 0.05, 0.08)


## A flag on `ci` with its top-left at `at`, turned by `lean` about that corner. A
## swallowtail if `swallowtail`, square otherwise; `type` adds a troop glyph ("" for none);
## `grey` washes it out, for a squad that has broken.
## `wave` (radians, or below zero for still cloth) ripples the cloth: the fly end moves
## more than the hoist, as a flag in the wind does.
static func flag(ci: CanvasItem, at: Vector2, size: Vector2, cloth: Color, dark: Color, swallowtail: bool,
		type: String = "", grey: bool = false, lit: bool = false, lean: float = 0.0, edge: Color = EDGE, wave: float = -1.0) -> void:
	if grey:
		cloth = cloth.lerp(Color(0.45, 0.45, 0.45), 0.6)
		dark = dark.lerp(Color(0.2, 0.2, 0.2), 0.6)
	ci.draw_set_transform(at, lean, Vector2.ONE)
	var w := size.x
	var h := size.y
	var still := wave < 0.0
	# The cloth's edges: the same ripple top and bottom at each step along the fly, worked
	# out once per step (battles draw two dozen of these every frame).
	var pts := PackedVector2Array()
	var steps := 1 if still else 6
	var drop := PackedFloat32Array()
	drop.resize(steps + 1)
	for i in steps + 1:
		drop[i] = 0.0 if still else _ripple(w * i / steps, w, h, wave)
	for i in steps + 1:
		pts.append(Vector2(w * i / steps, drop[i]))
	if swallowtail:
		var tx := w - w * 0.26
		pts.append(Vector2(tx, h * 0.5 + (0.0 if still else _ripple(tx, w, h, wave))))
	for i in range(steps, -1, -1):
		pts.append(Vector2(w * i / steps, h + drop[i]))
	ci.draw_colored_polygon(pts, cloth)
	var band_w := w - (w * 0.26 if swallowtail else 0.0)
	var y0 := h - 5.0 * h / 26.0
	var y1 := y0 + 3.0 * h / 26.0
	var b0 := 0.0 if still else _ripple(0.0, w, h, wave)
	var b1 := 0.0 if still else _ripple(band_w * 0.5, w, h, wave)
	var b2 := 0.0 if still else _ripple(band_w, w, h, wave)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(0, y0 + b0), Vector2(band_w * 0.5, y0 + b1), Vector2(band_w, y0 + b2),
		Vector2(band_w, y1 + b2), Vector2(band_w * 0.5, y1 + b1), Vector2(0, y1 + b0)]), dark)
	var outline := pts.duplicate()
	outline.append(pts[0])
	ci.draw_polyline(outline, edge, 3.0 if lit else 2.0)
	if type != "":
		var gx := w * 0.42
		glyph(ci, type, Vector2(gx, h * 0.48 + (0.0 if still else _ripple(gx, w, h, wave))), size.y / 26.0, Style.TEXT if not grey else Color(0.85, 0.85, 0.85))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A flag as one triangle list for a shader to wave (see the battle's FLAG_SHADER): the
## outline (a band `border` wide, centred on the cloth's edge as `flag` strokes it), the
## cloth, the band near its foot and the troop glyph, in the order `flag` paints them.
## UV.x is 2 plus how far along the fly a point is (0 at the hoist, 1 at the end), UV.y
## is `phase`, the flag's own offset in the wave. Every point of the glyph carries the UV
## of its centre, so it rides the cloth whole, as `flag` moves it.
## Returns {"points", "colors", "uvs", "indices"}, ready for canvas_item_add_triangle_array.
static func cloth_mesh(size: Vector2, swallowtail: bool, border: float, phase: float, cloth: Color, dark: Color,
		edge: Color, type: String, ink: Color) -> Dictionary:
	var w := size.x
	var h := size.y
	var path := PackedVector2Array()
	for i in 7:
		path.append(Vector2(w * i / 6, 0))
	if swallowtail:
		path.append(Vector2(w - w * 0.26, h * 0.5))
	for i in range(6, -1, -1):
		path.append(Vector2(w * i / 6, h))
	var e := border * 0.5
	var band_w := w - (w * 0.26 if swallowtail else 0.0)
	var y0 := h - 5.0 * h / 26.0
	var y1 := y0 + 3.0 * h / 26.0
	var x1 := band_w - (0.0 if swallowtail else e)
	# Plain arrays while building: they're shared when read from the dictionary, where
	# packed ones would be copied.
	var m := {"points": [], "colors": [], "uvs": [], "indices": [], "w": w, "phase": phase}
	_mesh_polygon(m, _offset(path, e), edge, -1.0)
	_mesh_polygon(m, _offset(path, -e), cloth, -1.0)
	_mesh_polygon(m, PackedVector2Array([Vector2(e, y0), Vector2((e + x1) * 0.5, y0), Vector2(x1, y0),
		Vector2(x1, y1), Vector2((e + x1) * 0.5, y1), Vector2(e, y1)]), dark, -1.0)
	if type != "":
		var c := Vector2(w * 0.42, h * 0.48)
		_mesh_glyph(m, type, c, h / 26.0, ink, c.x / w)
	return {"points": PackedVector2Array(m["points"]), "colors": PackedColorArray(m["colors"]),
		"uvs": PackedVector2Array(m["uvs"]), "indices": PackedInt32Array(m["indices"])}


## Adds a polygon (any simple outline) to the mesh `m`, its points taking the UV of
## where they lie along the fly, or all of `u_fixed` if that is 0 or more.
static func _mesh_polygon(m: Dictionary, pts: PackedVector2Array, col: Color, u_fixed: float) -> void:
	var tris := Geometry2D.triangulate_polygon(pts)
	var base: int = (m["points"] as Array).size()
	for p in pts:
		_mesh_point(m, p, col, u_fixed)
	for t in tris:
		(m["indices"] as Array).append(base + t)


static func _mesh_point(m: Dictionary, p: Vector2, col: Color, u_fixed: float) -> void:
	(m["points"] as Array).append(p)
	(m["colors"] as Array).append(col)
	var u: float = u_fixed if u_fixed >= 0.0 else p.x / float(m["w"])
	(m["uvs"] as Array).append(Vector2(2.0 + u, float(m["phase"])))


## A filled disc of radius `r` about `c`.
static func _mesh_disc(m: Dictionary, c: Vector2, r: float, col: Color, u: float) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		pts.append(c + Vector2.from_angle(TAU * i / 24.0) * r)
	_mesh_polygon(m, pts, col, u)


## A stroke `width` wide along `pts`, as draw_polyline lays it: a quad per segment.
static func _mesh_stroke(m: Dictionary, pts: PackedVector2Array, width: float, col: Color, u: float) -> void:
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var n := (b - a).normalized().orthogonal() * width * 0.5
		var base: int = (m["points"] as Array).size()
		for p in [a + n, b + n, b - n, a - n]:
			_mesh_point(m, p, col, u)
		(m["indices"] as Array).append_array([base, base + 1, base + 2, base, base + 2, base + 3])


## An arc as draw_arc lays it: `count` points from `from` to `to` radians.
static func _arc_points(c: Vector2, r: float, from: float, to: float, count: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in count:
		pts.append(c + Vector2.from_angle(from + (to - from) * i / float(count - 1)) * r)
	return pts


## The troop glyph `glyph` draws, as triangles in the mesh.
static func _mesh_glyph(m: Dictionary, type: String, c: Vector2, k: float, ink: Color, u: float) -> void:
	match type:
		Troops.INFANTRY:
			_mesh_disc(m, c, 8.0 * k, ink, u)
			_mesh_disc(m, c, 5.5 * k, Color(0.15, 0.15, 0.2), u)
			_mesh_disc(m, c, 2.5 * k, ink, u)
		Troops.SPEARMEN:
			_mesh_stroke(m, PackedVector2Array([c + Vector2(0, 10) * k, c + Vector2(0, -4) * k]), 2.5 * k, ink, u)
			_mesh_polygon(m, PackedVector2Array([c + Vector2(0, -11) * k, c + Vector2(4, -4) * k, c + Vector2(-4, -4) * k]), ink, u)
		Troops.ARCHERS:
			_mesh_stroke(m, _arc_points(c + Vector2(-5, 0) * k, 10.0 * k, -1.1, 1.1, 12), 2.5 * k, ink, u)
			_mesh_stroke(m, PackedVector2Array([c + Vector2(-1, -9) * k, c + Vector2(-1, 9) * k]), 1.0, ink, u)
			_mesh_stroke(m, PackedVector2Array([c + Vector2(-4, 0) * k, c + Vector2(9, 0) * k]), 2.0 * k, ink, u)
			_mesh_polygon(m, PackedVector2Array([c + Vector2(11, 0) * k, c + Vector2(6, -3) * k, c + Vector2(6, 3) * k]), ink, u)
		Troops.CAVALRY:
			_mesh_stroke(m, _arc_points(c + Vector2(0, 1) * k, 7.0 * k, PI * 0.72, PI * 2.28, 18), 3.5 * k, ink, u)


## `path` (a closed outline, clockwise on screen) moved out by `d` (in, if negative),
## corners mitred.
static func _offset(path: PackedVector2Array, d: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := path.size()
	for i in n:
		var a := path[(i - 1 + n) % n]
		var b := path[i]
		var c := path[(i + 1) % n]
		var n1 := (b - a).normalized().orthogonal()
		var n2 := (c - b).normalized().orthogonal()
		var m := (n1 + n2).normalized()
		out.append(b + m * d / maxf(0.25, m.dot(n1)))
	return out


## How far the cloth `x` along a flag `w` by `h` has dropped for a wave at `wave`: the
## fly end moves more than the hoist, as a flag in the wind does.
static func _ripple(x: float, w: float, h: float, wave: float) -> float:
	var u := x / w
	return sin(wave + u * 4.0) * h * 0.13 * u


## Shield, spear, bow or horseshoe, centred on `c`, scaled by `k`.
static func glyph(ci: CanvasItem, type: String, c: Vector2, k: float, ink: Color) -> void:
	match type:
		Troops.INFANTRY:
			ci.draw_circle(c, 8.0 * k, ink)
			ci.draw_circle(c, 5.5 * k, Color(0.15, 0.15, 0.2))
			ci.draw_circle(c, 2.5 * k, ink)
		Troops.SPEARMEN:
			ci.draw_line(c + Vector2(0, 10) * k, c + Vector2(0, -4) * k, ink, 2.5 * k)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -11) * k, c + Vector2(4, -4) * k, c + Vector2(-4, -4) * k]), ink)
		Troops.ARCHERS:
			ci.draw_arc(c + Vector2(-5, 0) * k, 10.0 * k, -1.1, 1.1, 12, ink, 2.5 * k)
			ci.draw_line(c + Vector2(-1, -9) * k, c + Vector2(-1, 9) * k, ink, 1.0)
			ci.draw_line(c + Vector2(-4, 0) * k, c + Vector2(9, 0) * k, ink, 2.0 * k)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(11, 0) * k, c + Vector2(6, -3) * k, c + Vector2(6, 3) * k]), ink)
		Troops.CAVALRY:
			ci.draw_arc(c + Vector2(0, 1) * k, 7.0 * k, PI * 0.72, PI * 2.28, 18, ink, 3.5 * k)


# ---------------------------------------------------------------- realm banners

## Each realm's banner: its shape, its size in design units (the cloth, without the
## pole), and how it's drawn. Vardmark hangs a pointed gonfalon from a crossbar with a
## silver keep on blue; Kharzan flies a swallowtail with a crimson sun over teal waters on
## saffron; Ryumon raises a tall nobori with three crossed arrows on red; the Free Crown
## a gold crown on night; bandits a torn rag with crossed knives.
const REALM_SIZES := {
	"vardmark": Vector2(84, 122), "kharzan": Vector2(104, 64), "ryumon": Vector2(66, 124),
	"crown": Vector2(90, 90), "bandits": Vector2(86, 104),
}
const SILVER := Color("e8ebf2")
const POLE := Color("8a6a3a")
const FINIAL := Color("cbb27a")


## The banner for a culture's realm.
static func realm_of_culture(culture: String) -> String:
	match culture:
		"kharzani": return "kharzan"
		"ryumon": return "ryumon"
	return "vardmark"


## The realm's banner on its pole, fitted into `box` on `ci` (call from a draw callback).
## `grey` washes it out (a realm that has fallen). `base` is the draw transform already in
## use (a zoomed battlefield), kept and restored. Returns where the pole's finial is.
static func realm_banner(ci: CanvasItem, realm: String, box: Rect2, pole: bool = true, grey: bool = false,
		base: Transform2D = Transform2D.IDENTITY) -> Vector2:
	if not REALM_SIZES.has(realm):
		realm = "bandits"
	var cloth: Vector2 = REALM_SIZES[realm]
	# Room for the pole: a crossbar above a gonfalon, a staff beside the rest.
	var lead := Vector2(0.0, 0.14) if realm == "vardmark" else Vector2(0.14, 0.06)
	if not pole:
		lead = Vector2.ZERO
	var avail := box.size / (Vector2.ONE + lead)
	var k := minf(avail.x / cloth.x, avail.y / cloth.y)
	var drawn := cloth * k
	var origin := box.position + Vector2(lead.x * drawn.x, lead.y * drawn.y)
	var finial := Vector2(origin.x + drawn.x * 0.5, box.position.y) if realm == "vardmark" else Vector2(origin.x - 2.0 * k, box.position.y)
	if pole:
		var w := maxf(1.5, 3.5 * k)
		if realm == "vardmark":
			var mid := origin.x + drawn.x * 0.5
			ci.draw_line(Vector2(mid, box.position.y), Vector2(mid, box.end.y), POLE, w)
			ci.draw_line(Vector2(origin.x - 4.0 * k, origin.y - 1.0 * k), Vector2(origin.x + drawn.x + 4.0 * k, origin.y - 1.0 * k), POLE, w)
			ci.draw_circle(Vector2(mid, box.position.y + w), w * 1.2, FINIAL)
		else:
			var x := origin.x - 2.0 * k
			ci.draw_line(Vector2(x, box.position.y), Vector2(x, box.end.y), POLE if realm != "ryumon" else Color("2a1d14"), w)
			ci.draw_circle(Vector2(x, box.position.y + w), w * 1.2, FINIAL)
	ci.draw_set_transform_matrix(base * Transform2D(0.0, Vector2(k, k), 0.0, origin))
	match realm:
		"vardmark": _vardmark(ci)
		"kharzan": _kharzan(ci)
		"ryumon": _ryumon(ci)
		"crown": _crown(ci)
		_: _bandits(ci)
	ci.draw_set_transform_matrix(base)
	if grey:
		ci.draw_rect(Rect2(origin, drawn), Color(0.2, 0.2, 0.22, 0.55))
	return finial


static func _poly(ci: CanvasItem, pts: Array, color: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array(pts), color)


static func _outline(ci: CanvasItem, pts: Array, color: Color, width: float) -> void:
	var line := PackedVector2Array(pts)
	line.append(pts[0])
	ci.draw_polyline(line, color, width)


static func _vardmark(ci: CanvasItem) -> void:
	var shape := [Vector2(0, 0), Vector2(84, 0), Vector2(84, 96), Vector2(42, 122), Vector2(0, 96)]
	_poly(ci, shape, Color("3459b8"))
	# The keep: a wall with two crenellated towers, a gate, and a tower roof with a pennant.
	_poly(ci, [Vector2(24, 84), Vector2(24, 48), Vector2(30, 48), Vector2(30, 40), Vector2(36, 40), Vector2(36, 48),
		Vector2(48, 48), Vector2(48, 40), Vector2(54, 40), Vector2(54, 48), Vector2(60, 48), Vector2(60, 84)], SILVER)
	var door := [Vector2(36, 84)]
	for i in 9:
		door.append(Vector2(42, 70) + Vector2.from_angle(PI + PI * i / 8.0) * 6.0)
	door.append(Vector2(48, 84))
	_poly(ci, door, Color("3459b8"))
	_poly(ci, [Vector2(33, 30), Vector2(51, 30), Vector2(42, 18)], SILVER)
	ci.draw_rect(Rect2(41, 9, 2, 10), SILVER)
	_poly(ci, [Vector2(43, 9), Vector2(52, 9), Vector2(49, 12), Vector2(52, 15), Vector2(43, 15)], Color("c9473d"))
	_outline(ci, shape, SILVER, 4.0)
	_outline(ci, shape, Color("10131e"), 1.5)


static func _kharzan(ci: CanvasItem) -> void:
	var shape := [Vector2(0, 0), Vector2(104, 0), Vector2(82, 32), Vector2(104, 64), Vector2(0, 64)]
	_poly(ci, shape, Color("d9962b"))
	var sun := Vector2(32, 28)
	ci.draw_circle(sun, 12.0, Color("a8261c"))
	for i in 8:
		var d := Vector2.from_angle(TAU * i / 8.0)
		ci.draw_line(sun + d * 17.0, sun + d * 22.0, Color("a8261c"), 3.2)
	# Two rows of waves, kept inside the swallowtail's notch.
	for y in [50.0, 58.0]:
		var pts := PackedVector2Array()
		var x := 0.0
		while x <= 88.0:
			pts.append(Vector2(x, y - sin(x / 20.0 * TAU) * 3.0))
			x += 2.0
		ci.draw_polyline(pts, Color("1f7a6e"), 4.0)
	_outline(ci, shape, Color("2a1708"), 2.0)


static func _ryumon(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(0, 0, 66, 124), Color("b8352a"))
	ci.draw_rect(Rect2(0, 0, 66, 16), Color("f1ece0"))
	var c := Vector2(33, 62)
	ci.draw_circle(c, 25.0, Color("14161f"))
	var ink := Color("f1ece0")
	for turn in [0.0, deg_to_rad(-38.0), deg_to_rad(38.0)]:
		var r := func(p: Vector2) -> Vector2: return c + p.rotated(turn)
		ci.draw_line(r.call(Vector2(0, 18)), r.call(Vector2(0, -14)), ink, 2.6)
		_poly(ci, [r.call(Vector2(0, -22)), r.call(Vector2(-5.5, -13)), r.call(Vector2(5.5, -13))], ink)
		for f in [12.0, 16.0]:
			ci.draw_line(r.call(Vector2(0, f)), r.call(Vector2(-5, f + 6.0)), ink, 2.0)
			ci.draw_line(r.call(Vector2(0, f)), r.call(Vector2(5, f + 6.0)), ink, 2.0)
	ci.draw_rect(Rect2(0, 0, 66, 124), Color("2a1d14"), false, 2.0)
	for y in [26.0, 58.0, 90.0]:
		ci.draw_rect(Rect2(-4, y, 6, 4), Color("2a1d14"))


static func _crown(ci: CanvasItem) -> void:
	var ink: Color = WorldData.crown_color
	ci.draw_rect(Rect2(0, 0, 90, 90), Color("1d1a2a"))
	ci.draw_rect(Rect2(4, 4, 82, 82), ink, false, 8.0)
	_poly(ci, [Vector2(24, 56), Vector2(20, 30), Vector2(33, 42), Vector2(45, 24), Vector2(57, 42), Vector2(70, 30), Vector2(66, 56)], ink)
	ci.draw_rect(Rect2(22, 58, 46, 7), ink)
	ci.draw_rect(Rect2(0, 0, 90, 90), Color("0a0a10"), false, 2.0)


static func _bandits(ci: CanvasItem) -> void:
	var rag := [Vector2(0, 0), Vector2(84, 0), Vector2(80, 18), Vector2(86, 32), Vector2(78, 44), Vector2(83, 60),
		Vector2(73, 70), Vector2(77, 84), Vector2(63, 78), Vector2(53, 90), Vector2(45, 80), Vector2(31, 88),
		Vector2(27, 76), Vector2(15, 80), Vector2(18, 64), Vector2(12, 54)]
	_poly(ci, rag, Color("2a2522"))
	ci.draw_line(Vector2(22, 32), Vector2(62, 72), Color("b8b0a4"), 5.0)
	ci.draw_line(Vector2(62, 32), Vector2(22, 72), Color("b8b0a4"), 5.0)
	ci.draw_line(Vector2(18, 28), Vector2(26, 36), Color("8a2a20"), 7.0)
	ci.draw_line(Vector2(66, 28), Vector2(58, 36), Color("8a2a20"), 7.0)
