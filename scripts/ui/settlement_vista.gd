## The settlement seen from its gate (settlement_scene.gd paints it), scaled up with crisp
## pixels and kept a little alive: Vardmark's clouds drift, smoke rises and leans,
## torches and lanterns flicker, stars twinkle. With reduced motion it holds still.
extends Control

const SettlementScene = preload("res://scripts/ui/settlement_scene.gd")
const Data = preload("res://scripts/world/world_data.gd")
const Style = preload("res://scripts/ui/style.gd")

const FRAME := 1.0 / 8.0

var place := ""
var world = null
## Darken the bottom of the picture so a title set on it reads.
var fade := false

var _scene := {}
var _sky: Texture2D
var _clouds: Texture2D
var _front: Texture2D
var _t := 0.0
var _since := 0.0


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
	refresh()
	set_process(not Style.motion_reduced())
	resized.connect(_fit)


## Paints the scene again from the world as it is now.
func refresh() -> void:
	if place == "" or not Data.SETTLEMENTS.has(place):
		return
	_scene = SettlementScene.build(SettlementScene.params(world, place))
	_sky = ImageTexture.create_from_image(_scene["sky"])
	_front = ImageTexture.create_from_image(_scene["front"])
	_clouds = ImageTexture.create_from_image(_scene["clouds"]) if _scene["clouds"] != null else null
	queue_redraw()


## Keep the picture's shape: as tall as its width allows.
func _fit() -> void:
	var want := roundf(size.x * SettlementScene.H / SettlementScene.W)
	if size.x > 0.0 and absf(custom_minimum_size.y - want) > 1.0:
		custom_minimum_size.y = want


func _process(delta: float) -> void:
	_t += delta
	_since += delta
	if _since >= FRAME and is_visible_in_tree():
		_since = 0.0
		queue_redraw()


func _draw() -> void:
	if _scene.is_empty():
		return
	var s := size.x / SettlementScene.W
	var top := size.y - SettlementScene.H * s
	var full := Rect2(0, 0, SettlementScene.W, SettlementScene.H)
	draw_set_transform(Vector2(0, top), 0.0, Vector2(s, s))
	draw_texture_rect(_sky, full, false)
	var night: bool = _scene["night"]
	for star in _scene["stars"]:
		var a := 0.55 + 0.45 * sin(_t * 2.0 + float(star[3]))
		draw_rect(Rect2(star[0], star[1], 1, 1), Color(1, 1, 1, a) if star[2] else Color(0.66, 0.71, 0.85, a))
	if _clouds != null:
		var off := fmod(_t * 1.2, float(SettlementScene.W))
		draw_texture_rect(_clouds, Rect2(off, 0, SettlementScene.W, SettlementScene.H), false)
		draw_texture_rect(_clouds, Rect2(off - SettlementScene.W, 0, SettlementScene.W, SettlementScene.H), false)
	draw_texture_rect(_front, full, false)
	for plume in _scene["smokes"]:
		_draw_smoke(plume, night)
	for f in _scene["fires"]:
		var hot := sin(_t * 14.0 + f.x * 1.7) > -0.2
		if night:
			draw_rect(Rect2(f.x - 3, f.y - 3, 7, 7), Color(1.0, 0.6, 0.23, 0.18 + (0.08 if hot else 0.0)))
		draw_rect(Rect2(f.x, f.y, 1, 1), Color("ffd678") if hot else Color("ffb84a"))
		if hot:
			draw_rect(Rect2(f.x, f.y - 1, 1, 1), Color("ff7a3a"))
	for l in _scene["lanterns"]:
		if night:
			draw_rect(Rect2(l.x - 2, l.y - 2, 5, 6), Color(1.0, 0.48, 0.29, 0.2 + 0.06 * sin(_t * 5.0 + l.x)))
			draw_rect(Rect2(l.x, l.y, 1, 2), Color("ff6a3a"))
		else:
			draw_rect(Rect2(l.x, l.y, 1, 2), Color("c9473d"))
	draw_set_transform(Vector2.ZERO)
	if fade:
		# Darkest under the title, easing out two thirds of the way up.
		var top_y := size.y * 0.34
		var mid_y := size.y * 0.62
		var clear := Color(Style.NIGHT, 0.0)
		var half := Color(Style.NIGHT, 0.6)
		var dark := Color(Style.NIGHT, 0.94)
		draw_polygon(PackedVector2Array([Vector2(0, top_y), Vector2(size.x, top_y), Vector2(size.x, mid_y), Vector2(0, mid_y)]),
			PackedColorArray([clear, clear, half, half]))
		draw_polygon(PackedVector2Array([Vector2(0, mid_y), Vector2(size.x, mid_y), Vector2(size.x, size.y), Vector2(0, size.y)]),
			PackedColorArray([half, half, dark, dark]))


## A plume that widens and leans downwind as it rises, thinning out, its puffs moving up.
func _draw_smoke(plume: Array, night: bool) -> void:
	var x: float = plume[0]
	var y: float = plume[1]
	var h: int = plume[2]
	var c: Color = plume[3]
	if night:
		c = Color(c.r * SettlementScene.NIGHT_TINT.r, c.g * SettlementScene.NIGHT_TINT.g, c.b * SettlementScene.NIGHT_TINT.b)
	var a: float = plume[4]
	var phase := int(_t * 5.0)
	var light := c.lightened(0.18)
	for i in h:
		var t := float(i) / h
		var r := 1.0 + t * 5.0
		var cx := x + t * t * 14.0 + sin(i * 0.5 - _t * 2.2) * 0.8
		var reach := ceili(r)
		for dx in range(-reach, reach + 1):
			if absf(dx) > r:
				continue
			if absf(dx) > r - 1.2 and (dx + i + phase) % 2:
				continue
			if t > 0.6 and SettlementScene.BAYER[(i + phase) % 4][(dx + 8) % 4] < t * 12.0 - 6.0:
				continue
			var shade := light if (int((i + phase) / 3) + dx) % 4 == 0 else c
			draw_rect(Rect2(roundf(cx + dx), y - i, 1, 1), Color(shade, a * (1.0 - t * 0.55)))
