## A reusable arrival illustration made from the map's established pixel art. Every
## culture and settlement type has a distinct skyline; capitals carry a second banner.
extends Control

const Data = preload("res://scripts/world/world_data.gd")
const Cultures = preload("res://scripts/data/cultures.gd")
const MapArt = preload("res://scripts/art/map_art.gd")
const Style = preload("res://scripts/ui/style.gd")

var place := ""
var world = null


static func make(id: String, world_ref, height: float = 220.0) -> Control:
	var vista := new()
	vista.place = id
	vista.world = world_ref
	vista.name = "SettlementVista"
	vista.custom_minimum_size = Vector2(0, height)
	vista.clip_contents = true
	vista.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vista.visible = Style.illustrations_on()
	return vista


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()


func _draw() -> void:
	if place == "" or not Data.SETTLEMENTS.has(place):
		return
	var info: Dictionary = Data.settlement(place)
	var built_by := String(info["faction"])
	var owner: String = String(world.owner_of(place)) if world != null else built_by
	var culture := Data.culture_of(built_by)
	var owner_color := Cultures.color(Data.culture_of(owner))
	var culture_color := Cultures.color(culture)
	var capital: bool = bool(world.capital_of(owner) == place) if world != null else String(Data.FACTIONS[built_by]["capital"]) == place
	var kind := String(info["type"])

	# Painted sky, distant land and a foreground road. These broad shapes keep the tiny
	# pixel settlement legible without pretending to contain gameplay information.
	draw_rect(Rect2(Vector2.ZERO, size), Style.NIGHT)
	var sky := Rect2(Vector2.ZERO, Vector2(size.x, size.y * 0.66))
	draw_rect(sky, culture_color.darkened(0.62))
	draw_circle(Vector2(size.x * (0.78 if culture != Cultures.KHARZANI else 0.22), size.y * 0.24), 30.0,
		Color(Style.BRASS, 0.7))
	var horizon := PackedVector2Array([
		Vector2(0, size.y * 0.58), Vector2(size.x * 0.16, size.y * 0.43),
		Vector2(size.x * 0.34, size.y * 0.55), Vector2(size.x * 0.53, size.y * 0.38),
		Vector2(size.x * 0.73, size.y * 0.54), Vector2(size.x, size.y * 0.42),
		Vector2(size.x, size.y), Vector2(0, size.y)])
	draw_colored_polygon(horizon, culture_color.darkened(0.72))
	draw_rect(Rect2(0, size.y * 0.70, size.x, size.y * 0.30), culture_color.darkened(0.78))
	draw_colored_polygon(PackedVector2Array([
		Vector2(size.x * 0.40, size.y), Vector2(size.x * 0.47, size.y * 0.70),
		Vector2(size.x * 0.55, size.y * 0.70), Vector2(size.x * 0.68, size.y)]), Color("74634f"))

	var sprite := "%s/%s" % [culture, kind]
	if MapArt.has(sprite):
		var tex := MapArt.texture(sprite, 0, owner_color)
		var source := MapArt.size(sprite)
		var scale := minf(7.0 if kind == Data.TOWN else 6.0, minf(size.x * 0.62 / source.x, size.y * 0.64 / source.y))
		var draw_size := source * scale
		var rect := Rect2(Vector2((size.x - draw_size.x) * 0.5, size.y * 0.72 - draw_size.y), draw_size)
		draw_texture_rect(tex, rect, false, Color(0.48, 0.42, 0.38) if world != null and world.is_burned(place) else Color.WHITE)

	_draw_banner(Vector2(size.x * 0.19, size.y * 0.34), owner_color, 1.0)
	if capital:
		_draw_banner(Vector2(size.x * 0.77, size.y * 0.29), owner_color, 1.15)
		# A small brass crown makes a capital readable even in grayscale.
		var crown := PackedVector2Array([
			Vector2(size.x * 0.46, 24), Vector2(size.x * 0.49, 10), Vector2(size.x * 0.52, 24),
			Vector2(size.x * 0.55, 10), Vector2(size.x * 0.58, 24)])
		draw_polyline(crown, Style.BRASS, 5.0)


func _draw_banner(at: Vector2, color: Color, scale: float) -> void:
	draw_line(at, at + Vector2(0, 88) * scale, Color("6b4a2a"), 5.0 * scale)
	var flag := Rect2(at + Vector2(4, 5) * scale, Vector2(58, 36) * scale)
	draw_rect(flag, color)
	draw_colored_polygon(PackedVector2Array([
		flag.position + Vector2(flag.size.x, 0), flag.position + flag.size,
		flag.position + Vector2(flag.size.x * 0.72, flag.size.y * 0.5)]), color.darkened(0.32))
	draw_circle(flag.position + flag.size * Vector2(0.42, 0.5), 6.0 * scale, Style.TEXT)
