## The Glass Sea itself, for any screen that shows it: the sea (a shader on a
## screen-filling rect), and the land with its shore, fields, roads and terrain (drawn
## once, in map units, and moved with the camera). Point it with point_camera().
extends Node2D

const Data = preload("res://scripts/world/world_data.gd")
const MapArt = preload("res://scripts/art/map_art.gd")
const MapTerrain = preload("res://scripts/world/map_terrain.gd")
const WATER_SHADER = preload("res://shaders/map_water.gdshader")
const LAND_SHADER = preload("res://shaders/map_land.gdshader")

const LAND := {
	"vardmark": Color("6c8f4a"),
	"kharzan": Color("c9ac72"),
	"ryumon": Color("5f8a62"),
}
const COAST := Color("23302a")
const ROAD := Color("d8c08a")
const ROAD_EDGE := Color(0.27, 0.2, 0.12, 0.55)
const SEA_LANE := Color("cfe8f2")
const RIVER := Color(0.2, 0.48, 0.55)
const RIVER_BANK := Color(0.16, 0.26, 0.22)
const RIVER_SHINE := Color(0.5, 0.72, 0.74, 0.55)
const FORD := Color(0.58, 0.8, 0.8)
## A river's width in map units at its source and at its mouth.
const RIVER_WIDTH := Vector2(2.2, 5.6)

var terrain
var water: ColorRect
var land_layer: Node2D
var detail_layer: Node2D


func _ready() -> void:
	terrain = MapTerrain.shared()
	water = ColorRect.new()
	water.mouse_filter = Control.MOUSE_FILTER_IGNORE
	water.z_index = -4
	water.material = shader_material(WATER_SHADER)
	add_child(water)
	land_layer = Node2D.new()
	land_layer.z_index = -3
	land_layer.material = shader_material(LAND_SHADER)
	land_layer.draw.connect(_draw_land)
	add_child(land_layer)
	detail_layer = Node2D.new()
	detail_layer.z_index = -2
	detail_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	detail_layer.draw.connect(_draw_detail)
	add_child(detail_layer)


## A material for one of the map's shaders, with the terrain it reads.
func shader_material(shader: Shader) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("terrain", MapTerrain.shared().texture)
	m.set_shader_parameter("map_size", Data.SIZE)
	return m


## Show map point `center` at screen point `view_center`, `zoom` screen pixels to the
## map unit, on a screen of `screen` size. Also points any screen-filling `rects` that
## run map shaders (the sky over the map).
func point_camera(center: Vector2, zoom: float, view_center: Vector2, screen: Vector2, rects: Array = []) -> void:
	var origin := view_center - center * zoom
	for layer in [land_layer, detail_layer]:
		layer.position = origin
		layer.scale = Vector2(zoom, zoom)
	for rect in [water] + rects:
		rect.position = Vector2.ZERO
		rect.size = screen
		var m := rect.material as ShaderMaterial
		m.set_shader_parameter("cam_center", center)
		m.set_shader_parameter("cam_scale", zoom)
		m.set_shader_parameter("view_center", view_center)
		m.set_shader_parameter("rect_size", screen)


## The land, in map units: each realm in its own color, run off past the map's edge.
func _draw_land() -> void:
	land_layer.draw_colored_polygon(_past_border(Data.coast(0)), LAND["kharzan"])
	land_layer.draw_colored_polygon(_past_border(Data.realm_shape("vardmark")), LAND["vardmark"])
	land_layer.draw_colored_polygon(Data.coast(1), LAND["ryumon"])


## The shore, the border, fields, roads, and everything standing on the land, in map
## units. Drawn once; the camera only moves the layer.
func _draw_detail() -> void:
	for i in Data.LAND.size():
		var ring := Data.coast(i)
		for k in ring.size():
			var a := ring[k]
			var b := ring[(k + 1) % ring.size()]
			if not Data.on_border(a, b):
				detail_layer.draw_line(a, b, COAST, 2.2)
	_draw_border()
	_draw_rivers()
	var standing := false
	for d in terrain.decor:
		# Fields lie flat under the roads; everything else stands on top of them.
		if not standing and not MapTerrain.FIELDS.values().has(d["name"]):
			standing = true
			_draw_roads()
		_draw_decor(d)
	if not standing:
		_draw_roads()


func _draw_decor(d: Dictionary) -> void:
	var name := String(d["name"])
	var s: float = MapTerrain.DECOR_PIXEL * float(d["scale"])
	detail_layer.draw_set_transform(d["pos"], 0.0, Vector2(s * float(d["flip"]), s))
	detail_layer.draw_texture(MapArt.texture(name), -MapArt.pivot(name))
	detail_layer.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The inland edge of Vardmark, where the kingdom meets the sultanate.
func _draw_border() -> void:
	var shape := Data.realm_shape("vardmark")
	var from := -1
	for k in shape.size():
		if shape[k] == Vector2(300, 820):
			from = k
	if from == -1:
		return
	var k := from
	while k < shape.size() - 1 and shape[k].x > 0.0:
		detail_layer.draw_dashed_line(shape[k], shape[k + 1], Color(0.2, 0.12, 0.08, 0.5), 2.0, 6.0)
		k += 1


## Each river as a smooth line widening toward the sea: a dark bank, the water, and a
## glint down its middle. Where a road crosses, pale shallows show the ford under the road.
func _draw_rivers() -> void:
	for r in Data.RIVERS:
		var line := river_line(r["points"])
		_draw_river_pass(line, RIVER_BANK, 1.0, 1.6)
		_draw_river_pass(line, RIVER, 1.0, 0.0)
		_draw_river_pass(line, RIVER_SHINE, 0.3, 0.0)
	for f in Data.fords():
		detail_layer.draw_circle(f["pos"], 5.0, RIVER_BANK)
		detail_layer.draw_circle(f["pos"], 4.2, FORD)


## One stroke along a river, `scale` of its width plus `extra`, with round joins so the
## widening line shows no seams.
func _draw_river_pass(line: PackedVector2Array, color: Color, scale: float, extra: float) -> void:
	for k in line.size() - 1:
		var w := lerpf(RIVER_WIDTH.x, RIVER_WIDTH.y, float(k) / float(line.size() - 1)) * scale + extra
		detail_layer.draw_line(line[k], line[k + 1], color, w)
		if k > 0 and color.a >= 1.0:
			detail_layer.draw_circle(line[k], w * 0.5, color)


## A river's course smoothed through its points, for drawing.
static func river_line(points: Array) -> PackedVector2Array:
	var curve := Curve2D.new()
	for k in points.size():
		var p: Vector2 = points[k]
		var prev: Vector2 = points[maxi(0, k - 1)]
		var next: Vector2 = points[mini(points.size() - 1, k + 1)]
		var tangent := (next - prev) * 0.25
		curve.add_point(p, -tangent, tangent)
	return curve.tessellate(5, 3.0)


func _draw_roads() -> void:
	for r in Data.ROADS:
		var a := Data.pos(r[0])
		var b := Data.pos(r[1])
		if r[2]:
			detail_layer.draw_dashed_line(a, b, Color(SEA_LANE, 0.55), 1.6, 5.0)
		else:
			detail_layer.draw_line(a, b, ROAD_EDGE, 5.5)
			detail_layer.draw_line(a, b, ROAD, 3.0)


## A land outline with the corners on the map's edge pushed far out, so the land runs
## on past the edge of the map instead of stopping at it.
func _past_border(points: PackedVector2Array) -> PackedVector2Array:
	var out := points.duplicate()
	for i in out.size():
		var p := out[i]
		if p.x <= 0.0:
			p.x = -900.0
		elif p.x >= Data.SIZE.x:
			p.x = Data.SIZE.x + 900.0
		if p.y <= 0.0:
			p.y = -900.0
		elif p.y >= Data.SIZE.y:
			p.y = Data.SIZE.y + 900.0
		out[i] = p
	return out
