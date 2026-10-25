## Flags and troop glyphs, drawn in code so the battle's standards, the squad cards and
## the map's party pennants all share one look. Call these from inside a CanvasItem's
## draw callback, passing that CanvasItem.
extends RefCounted

const Troops = preload("res://scripts/data/troops.gd")
const Style = preload("res://scripts/ui/style.gd")

const EDGE := Color(0.06, 0.05, 0.08)


## A flag on `ci` with its top-left at `at`, turned by `lean` about that corner. A
## swallowtail if `swallowtail`, square otherwise; `type` adds a troop glyph ("" for none);
## `grey` washes it out, for a squad that has broken.
static func flag(ci: CanvasItem, at: Vector2, size: Vector2, cloth: Color, dark: Color, swallowtail: bool,
		type: String = "", grey: bool = false, lit: bool = false, lean: float = 0.0, edge: Color = EDGE) -> void:
	if grey:
		cloth = cloth.lerp(Color(0.45, 0.45, 0.45), 0.6)
		dark = dark.lerp(Color(0.2, 0.2, 0.2), 0.6)
	ci.draw_set_transform(at, lean, Vector2.ONE)
	var w := size.x
	var h := size.y
	var pts: PackedVector2Array
	if swallowtail:
		pts = PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w - w * 0.26, h * 0.5), Vector2(w, h), Vector2(0, h)])
	else:
		pts = PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)])
	ci.draw_colored_polygon(pts, cloth)
	ci.draw_rect(Rect2(0, h - 5.0 * h / 26.0, w - (w * 0.26 if swallowtail else 0.0), 3.0 * h / 26.0), dark)
	var outline := pts.duplicate()
	outline.append(pts[0])
	ci.draw_polyline(outline, edge, 3.0 if lit else 2.0)
	if type != "":
		glyph(ci, type, Vector2(w * 0.42, h * 0.48), size.y / 26.0, Style.TEXT if not grey else Color(0.85, 0.85, 0.85))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


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
