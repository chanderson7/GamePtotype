## The look of the Glass Sea, worked out once from the map data: a small picture of the
## land for the map's shaders (where the shore is, softened at three widths, and how high
## the ground lies), and where trees, mountains, dunes and fields stand. Only for looks:
## the world sim never reads it.
extends RefCounted

const Data = preload("res://scripts/world/world_data.gd")

## Texels across and down the land picture.
const TEX_SIZE := Vector2i(128, 200)
## Map units per pixel of a terrain sprite.
const DECOR_PIXEL := 2.0
## Woods and peaks keep this far from settlements and roads, in map units.
const CLEAR_OF_PLACES := 44.0
const CLEAR_OF_ROADS := 12.0
const CLEAR_OF_RIVERS := 7.0
## What stands on the high ground and in the woods of each realm.
const PEAK := {"vardmark": "mountain", "kharzan": "mesa", "ryumon": "mountain_snow"}
const FIELDS := {"vardmark": "fields", "kharzan": "fields_dry", "ryumon": "paddy"}
## Wood noise above which the forests of Vardmark and Ryumon grow.
const WOODS_VARDMARK := 0.32
const WOODS_RYUMON := 0.25

## R: land with a soft shore, G: land blurred over a few dozen map units, B: blurred
## wider still, A: how high the ground lies (0 at the shore, 1 on the peaks).
var image: Image
var texture: ImageTexture
## What stands on the land, back to front: [{name, pos, scale, flip}].
var decor: Array = []
var _height := FastNoiseLite.new()
var _woods := FastNoiseLite.new()

static var _shared = null


## The terrain, built the first time any map asks for it.
static func shared():
	if _shared == null:
		_shared = new()
		_shared.build()
	return _shared


func build() -> void:
	_height.seed = 4021
	_height.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_height.frequency = 1.0 / 190.0
	_height.fractal_octaves = 4
	_woods.seed = 77
	_woods.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_woods.frequency = 1.0 / 85.0
	_woods.fractal_octaves = 2
	_paint()
	_place_decor()


## How high the ground lies at map point `p`, from 0 to 1, ignoring the sea.
func height_at(p: Vector2) -> float:
	return clampf(_height.get_noise_2dv(p) * 0.5 + 0.5, 0.0, 1.0)


## How thick the woods run at map point `p`, from 0 to 1.
func woods_at(p: Vector2) -> float:
	return clampf(_woods.get_noise_2dv(p) * 0.5 + 0.5, 0.0, 1.0)


## Whether `p` lies in the woods the map draws: the thick of the wood noise in the realms
## that grow forests (Kharzan's high noise is dunes, not trees).
func wooded(p: Vector2) -> bool:
	match realm_at(p):
		"vardmark":
			return _woods.get_noise_2dv(p) > WOODS_VARDMARK
		"ryumon":
			return _woods.get_noise_2dv(p) > WOODS_RYUMON
	return false


## How far inland `p` lies, from 0 out at sea to 1 well inland.
func inland(p: Vector2) -> float:
	return _texel(p).g


## The realm whose land `p` is on, or "" at sea.
func realm_at(p: Vector2) -> String:
	var land := Data.land_at(p)
	if land == -1:
		return ""
	if land == 1:
		return "ryumon"
	if Geometry2D.is_point_in_polygon(p, Data.realm_shape("vardmark")):
		return "vardmark"
	return "kharzan"


func _texel(p: Vector2) -> Color:
	var x := clampi(int(p.x / Data.SIZE.x * TEX_SIZE.x), 0, TEX_SIZE.x - 1)
	var y := clampi(int(p.y / Data.SIZE.y * TEX_SIZE.y), 0, TEX_SIZE.y - 1)
	return image.get_pixel(x, y)


func _paint() -> void:
	var w := TEX_SIZE.x
	var h := TEX_SIZE.y
	var mask := Image.create_empty(w, h, false, Image.FORMAT_L8)
	for y in h:
		for x in w:
			var p := Vector2((x + 0.5) / w * Data.SIZE.x, (y + 0.5) / h * Data.SIZE.y)
			mask.set_pixel(x, y, Color.WHITE if Data.land_at(p) != -1 else Color.BLACK)
	var soft := _blurred(mask, 1)
	var mid := _blurred(mask, 2)
	var wide := _blurred(mask, 4)
	image = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var p := Vector2((x + 0.5) / w * Data.SIZE.x, (y + 0.5) / h * Data.SIZE.y)
			var m := mid.get_pixel(x, y).r
			image.set_pixel(x, y, Color(soft.get_pixel(x, y).r, m, wide.get_pixel(x, y).r, height_at(p) * m))
	texture = ImageTexture.create_from_image(image)


## The mask halved `times` times and stretched back: a cheap, smooth blur.
func _blurred(mask: Image, times: int) -> Image:
	var img := mask.duplicate() as Image
	for i in times:
		img.shrink_x2()
	img.resize(mask.get_width(), mask.get_height(), Image.INTERPOLATE_CUBIC)
	return img


func _place_decor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1166
	var flat := []
	# Farmland around every village: strips of crops, dry fields, or paddies.
	for id in Data.SETTLEMENTS:
		var s := Data.settlement(id)
		if s["type"] != Data.VILLAGE:
			continue
		for off in [Vector2(-34, 12), Vector2(32, 18)]:
			var p: Vector2 = Data.pos(id) + off
			if Data.land_at(p) != -1 and _road_distance(p) > 14.0:
				flat.append({"name": FIELDS[realm_at(p)], "pos": p, "scale": 1.0, "flip": 1.0})
	# Peaks where the land rises highest, spaced well apart.
	var peaks := []
	for gy in range(15, int(Data.SIZE.y), 30):
		for gx in range(15, int(Data.SIZE.x), 30):
			var p := Vector2(gx, gy) + Vector2(rng.randf_range(-9, 9), rng.randf_range(-9, 9))
			if not _clear(p, 16.0) or height_at(p) * inland(p) < 0.68 or rng.randf() > 0.6:
				continue
			peaks.append({"name": PEAK[realm_at(p)], "pos": p, "scale": rng.randf_range(0.85, 1.25),
				"flip": 1.0 if rng.randf() < 0.5 else -1.0})
	# Woods, dunes and the odd lone tree on a finer grid.
	var growth := []
	for gy in range(6, int(Data.SIZE.y), 12):
		for gx in range(6, int(Data.SIZE.x), 12):
			var p := Vector2(gx, gy) + Vector2(rng.randf_range(-4, 4), rng.randf_range(-4, 4))
			if not _clear(p, 0.0) or _near(peaks, p, 22.0):
				continue
			var name := _growth(realm_at(p), _woods.get_noise_2dv(p), height_at(p), rng)
			if name != "":
				growth.append({"name": name, "pos": p, "scale": rng.randf_range(0.85, 1.15),
					"flip": 1.0 if rng.randf() < 0.5 else -1.0})
	var standing := peaks + growth
	standing.sort_custom(func(a, b): return a["pos"].y < b["pos"].y)
	decor = flat + standing


## What grows at a spot: woods where the wood noise is high, a few lone trees elsewhere.
func _growth(realm: String, woods: float, height: float, rng: RandomNumberGenerator) -> String:
	match realm:
		"vardmark":
			if woods > WOODS_VARDMARK and rng.randf() < 0.75:
				return "pine" if height > 0.62 else "tree"
			return "tree" if rng.randf() < 0.02 else ""
		"kharzan":
			if woods > 0.4 and rng.randf() < 0.25:
				return "dune"
			return "palm" if rng.randf() < 0.008 else ""
		_:
			if woods > WOODS_RYUMON and rng.randf() < 0.7:
				return "blossom" if rng.randf() < 0.16 else "pine"
			return "pine" if rng.randf() < 0.03 else ""


## On land, off the beach, and clear of settlements, roads and rivers by `extra` more than
## usual.
func _clear(p: Vector2, extra: float) -> bool:
	if Data.land_at(p) == -1 or _texel(p).r < 0.9:
		return false
	for id in Data.SETTLEMENTS:
		if p.distance_to(Data.pos(id)) < CLEAR_OF_PLACES + extra:
			return false
	return _road_distance(p) > CLEAR_OF_ROADS + extra \
		and float(Data.nearest_river(p)["distance"]) > CLEAR_OF_RIVERS + extra


func _road_distance(p: Vector2) -> float:
	var best := INF
	for r in Data.ROADS:
		if r[2]:
			continue
		var a := Data.pos(r[0])
		var b := Data.pos(r[1])
		best = minf(best, Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p))
	return best


func _near(items: Array, p: Vector2, dist: float) -> bool:
	for d in items:
		if p.distance_to(d["pos"]) < dist:
			return true
	return false
