## A reusable arrival illustration made from the map's established pixel art. Every
## culture and settlement type has a distinct skyline; capitals carry a second banner.
extends Control

const Data = preload("res://scripts/world/world_data.gd")
const Cultures = preload("res://scripts/data/cultures.gd")
const MapArt = preload("res://scripts/art/map_art.gd")
const Style = preload("res://scripts/ui/style.gd")
const TravelPresentation = preload("res://scripts/world/travel_presentation.gd")

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
	var state: Dictionary = TravelPresentation.settlement_state(world, place) if world != null else {}
	var built_by := String(info["faction"])
	var owner: String = String(world.owner_of(place)) if world != null else built_by
	var culture := Data.culture_of(built_by)
	var owner_culture := Data.culture_of(owner)
	var owner_color := Cultures.color(Data.culture_of(owner))
	var culture_color := Cultures.color(culture)
	var capital: bool = bool(world.capital_of(owner) == place) if world != null else String(Data.FACTIONS[built_by]["capital"]) == place
	var kind := String(info["type"])
	var condition := String(state.get("condition", "healthy"))
	var night := bool(state.get("night", false))

	# Painted sky, distant land and a foreground road. These broad shapes keep the tiny
	# pixel settlement legible without pretending to contain gameplay information.
	draw_rect(Rect2(Vector2.ZERO, size), Style.NIGHT)
	var sky := Rect2(Vector2.ZERO, Vector2(size.x, size.y * 0.66))
	var sky_color := culture_color.darkened(0.77 if night else 0.62)
	if condition == "damaged": sky_color = sky_color.lerp(Color("57494a"), 0.42)
	elif condition == "recovering": sky_color = sky_color.lerp(Color("8c7451"), 0.18)
	draw_rect(sky, sky_color)
	draw_circle(Vector2(size.x * (0.78 if culture != Cultures.KHARZANI else 0.22), size.y * 0.24), 30.0,
		Color("d7d9da") if night else Color(Style.BRASS, 0.7))
	var horizon := PackedVector2Array([
		Vector2(0, size.y * 0.58), Vector2(size.x * 0.16, size.y * 0.43),
		Vector2(size.x * 0.34, size.y * 0.55), Vector2(size.x * 0.53, size.y * 0.38),
		Vector2(size.x * 0.73, size.y * 0.54), Vector2(size.x, size.y * 0.42),
		Vector2(size.x, size.y), Vector2(0, size.y)])
	draw_colored_polygon(horizon, culture_color.darkened(0.72))
	draw_rect(Rect2(0, size.y * 0.70, size.x, size.y * 0.30), culture_color.darkened(0.86 if night else 0.78))
	draw_colored_polygon(PackedVector2Array([
		Vector2(size.x * 0.40, size.y), Vector2(size.x * 0.47, size.y * 0.70),
		Vector2(size.x * 0.55, size.y * 0.70), Vector2(size.x * 0.68, size.y)]), Color("4b4550") if night else Color("74634f"))
	_draw_fields(kind, condition, culture_color)

	var sprite := "%s/%s" % [culture, kind]
	if MapArt.has(sprite):
		var tex := MapArt.texture(sprite, 0, owner_color)
		var source := MapArt.size(sprite)
		var scale := minf(7.0 if kind == Data.TOWN else 6.0, minf(size.x * 0.62 / source.x, size.y * 0.64 / source.y))
		var draw_size := source * scale
		var rect := Rect2(Vector2((size.x - draw_size.x) * 0.5, size.y * 0.72 - draw_size.y), draw_size)
		var tint := Color.WHITE
		if condition == "damaged": tint = Color(0.48, 0.42, 0.38)
		elif condition == "recovering": tint = Color(0.82, 0.75, 0.62)
		elif night: tint = Color(0.58, 0.64, 0.82)
		draw_texture_rect(tex, rect, false, tint)

	var relation := String(state.get("relation", "neutral"))
	_draw_banner(Vector2(size.x * 0.19, size.y * 0.34), owner_color, 1.0, owner_culture, relation)
	if capital:
		_draw_banner(Vector2(size.x * 0.77, size.y * 0.29), owner_color, 1.15, owner_culture, relation)
		# A small brass crown makes a capital readable even in grayscale.
		var crown := PackedVector2Array([
			Vector2(size.x * 0.46, 24), Vector2(size.x * 0.49, 10), Vector2(size.x * 0.52, 24),
			Vector2(size.x * 0.55, 10), Vector2(size.x * 0.58, 24)])
		draw_polyline(crown, Style.BRASS, 5.0)
	_draw_activity(state, culture_color)
	_draw_condition(state)
	if String(state.get("garrison", "none")) == "thin":
		_draw_low_garrison(kind)
	if night:
		_draw_night_lights(kind, condition)


func _draw_banner(at: Vector2, color: Color, scale: float, culture: String, relation: String) -> void:
	draw_line(at, at + Vector2(0, 88) * scale, Color("6b4a2a"), 5.0 * scale)
	var mark := Style.BRASS if relation == "friendly" else (Style.ENEMY_LIGHT if relation == "hostile" else Style.TEXT)
	var flag := Rect2(at + Vector2(4, 5) * scale, Vector2(58, 36) * scale)
	match culture:
		Cultures.KHARZANI:
			draw_colored_polygon(PackedVector2Array([flag.position, flag.position + Vector2(flag.size.x, flag.size.y * 0.5), flag.position + Vector2(0, flag.size.y)]), color)
			draw_polyline(PackedVector2Array([flag.position, flag.position + Vector2(flag.size.x, flag.size.y * 0.5), flag.position + Vector2(0, flag.size.y)]), mark, 2.0 * scale)
		Cultures.RYUMON:
			flag.size = Vector2(34, 58) * scale
			draw_rect(flag, color)
			draw_line(flag.position + Vector2(flag.size.x * 0.18, 0), flag.position + Vector2(flag.size.x * 0.18, flag.size.y), mark, 2.0 * scale)
		_:
			draw_rect(flag, color)
			draw_colored_polygon(PackedVector2Array([flag.position + Vector2(flag.size.x, 0), flag.position + flag.size, flag.position + Vector2(flag.size.x * 0.72, flag.size.y * 0.5)]), color.darkened(0.32))
			draw_line(flag.position, flag.position + Vector2(flag.size.x * 0.72, flag.size.y), mark, 2.0 * scale)
	draw_circle(flag.position + flag.size * Vector2(0.42, 0.5), 5.0 * scale, mark)


func _draw_fields(kind: String, condition: String, color: Color) -> void:
	if kind != Data.VILLAGE:
		return
	var field_color := Color("6b593a") if condition == "damaged" else color.lightened(0.08).darkened(0.45)
	for row in 3:
		var y := size.y * (0.73 + row * 0.065)
		for col in 7:
			var x := size.x * (0.05 + col * 0.065)
			draw_line(Vector2(x, y), Vector2(x + 22, y + 9), field_color, 3.0)


func _draw_activity(state: Dictionary, color: Color) -> void:
	var props: Array = state.get("props", [])
	var ground := size.y * 0.82
	if props.has("market"):
		for i in 2:
			var x := size.x * (0.16 + i * 0.64)
			draw_rect(Rect2(x - 28, ground - 36, 56, 22), color.lightened(0.18))
			draw_colored_polygon(PackedVector2Array([Vector2(x - 34, ground - 36), Vector2(x, ground - 55), Vector2(x + 34, ground - 36)]), Style.BRASS.darkened(0.2))
	if props.has("cart"):
		var cart := Vector2(size.x * 0.29, ground + 2)
		draw_rect(Rect2(cart + Vector2(-28, -18), Vector2(56, 22)), Color("77533a"))
		draw_circle(cart + Vector2(-19, 8), 9, Color("2f2930"))
		draw_circle(cart + Vector2(19, 8), 9, Color("2f2930"))
	if props.has("guards"):
		_draw_person(Vector2(size.x * 0.38, ground), color.lightened(0.25), true)
		if String(state.get("garrison", "")) != "thin":
			_draw_person(Vector2(size.x * 0.62, ground), color.lightened(0.25), true)
	if props.has("workers"):
		_draw_person(Vector2(size.x * 0.24, ground), Color("c5aa78"), false)
		_draw_person(Vector2(size.x * 0.76, ground), Color("b88458"), false)
	if props.has("livestock"):
		var animal := Vector2(size.x * 0.71, ground + 6)
		draw_circle(animal, 11, Color("d1c2a2"))
		draw_circle(animal + Vector2(12, -5), 7, Color("d1c2a2"))
		draw_line(animal + Vector2(-6, 8), animal + Vector2(-6, 20), Color("6f604e"), 3)
		draw_line(animal + Vector2(5, 8), animal + Vector2(5, 20), Color("6f604e"), 3)
	if props.has("smith"):
		var chimney := Vector2(size.x * 0.83, ground - 48)
		for i in 3:
			draw_circle(chimney + Vector2(i * 4, -i * 13), 7 + i * 2, Color(0.35, 0.32, 0.30, 0.28))
	if props.has("timber"):
		for i in 3:
			draw_line(Vector2(size.x * 0.62, ground + i * 7), Vector2(size.x * 0.77, ground + i * 7), Color("a97846"), 6)


func _draw_person(at: Vector2, color: Color, armed: bool) -> void:
	draw_circle(at + Vector2(0, -23), 6, Color("d2ae82"))
	draw_rect(Rect2(at + Vector2(-6, -17), Vector2(12, 22)), color)
	draw_line(at + Vector2(-3, 4), at + Vector2(-7, 18), Color("382f35"), 3)
	draw_line(at + Vector2(3, 4), at + Vector2(7, 18), Color("382f35"), 3)
	if armed:
		draw_line(at + Vector2(8, -16), at + Vector2(8, 17), Color("bbb5a4"), 3)


func _draw_condition(state: Dictionary) -> void:
	var condition := String(state.get("condition", "healthy"))
	if condition == "damaged":
		var smoke_offset := float(absi(place.hash()) % 100) / 100.0
		for i in 4:
			var x := size.x * (0.12 + i * 0.24)
			draw_line(Vector2(x, size.y * 0.77), Vector2(x + 18, size.y * 0.9), Color("392f2d"), 7)
			var rise := fmod(smoke_offset + i * 0.27, 1.0)
			draw_circle(Vector2(x + 7, size.y * (0.68 - rise * 0.17)), 10 + rise * 12, Color(0.22, 0.20, 0.21, 0.32 * (1.0 - rise)))
	elif condition == "recovering":
		var left := size.x * 0.36
		var right := size.x * 0.64
		for x in [left, right]:
			draw_line(Vector2(x, size.y * 0.43), Vector2(x, size.y * 0.76), Color("a97846"), 6)
		for y in [0.49, 0.61, 0.73]:
			draw_line(Vector2(left, size.y * y), Vector2(right, size.y * y), Color("c59555"), 5)


func _draw_low_garrison(kind: String) -> void:
	if kind == Data.VILLAGE:
		return
	var y := size.y * 0.76
	for x in [size.x * 0.08, size.x * 0.92]:
		draw_rect(Rect2(Vector2(x - 13, y - 34), Vector2(26, 34)), Color(0.09, 0.10, 0.14, 0.72), false, 4)
		draw_line(Vector2(x - 10, y + 8), Vector2(x + 10, y + 8), Style.ENEMY_LIGHT.darkened(0.2), 3)


func _draw_night_lights(kind: String, condition: String) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.05, 0.13, 0.28))
	var count := 2 if condition == "damaged" else (7 if kind == Data.TOWN else 4)
	for i in count:
		var x := size.x * (0.34 + 0.32 * float(i % 4) / 3.0)
		var y := size.y * (0.48 + 0.16 * float(i / 4))
		draw_rect(Rect2(Vector2(x - 4, y - 3), Vector2(8, 7)), Color(1.0, 0.72, 0.32, 0.84))
