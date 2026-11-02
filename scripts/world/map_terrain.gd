## The look of the Glass Sea, worked out once from the map data: a small picture of the
## land for the map's shaders (where the shore is, softened at three widths, and how high
## the ground lies), and where trees, mountains, dunes and fields stand. Only for looks:
## the world sim never reads it.
extends RefCounted

const Data = preload("res://scripts/world/world_data.gd")

## How far past the map's edge the land picture and the decor reach, in map units: as far
## as the camera can see at its widest.
const BEYOND := 320.0
## Where the land picture starts and how much of the world it covers, in map units.
const ORIGIN := Vector2(-BEYOND, -BEYOND)
const EXTENT := Data.SIZE + Vector2(BEYOND, BEYOND) * 2.0
## Texels across and down the land picture (about 8 map units each).
const TEX_SIZE := Vector2i(210, 280)
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


## The realm whose land `p` is on, or "" at sea. Past the map's edge this follows the
## land as it's drawn there (the isles off the east look like Ryumon's).
func realm_at(p: Vector2) -> String:
	var land := looks_land(p)
	if land == -1:
		return ""
	if land >= 1:
		return "ryumon"
	if Geometry2D.is_point_in_polygon(p, Data.vardmark_beyond()):
		return "vardmark"
	return "kharzan"


## Which land the map draws at `p`, inside the map or past its edge: 0 the mainland, 1
## Ryumon, 2 an isle beyond the edge, -1 sea. Inside the map it matches Data.land_at.
static func looks_land(p: Vector2) -> int:
	if _boxes.is_empty():
		_boxes = [_box(Data.coast(1))] + Data.isles_beyond().map(func(isle): return _box(isle))
	if _boxes[0].has_point(p) and Geometry2D.is_point_in_polygon(p, Data.coast(1)):
		return 1
	var isles: Array = Data.isles_beyond()
	for i in isles.size():
		if _boxes[i + 1].has_point(p) and Geometry2D.is_point_in_polygon(p, isles[i]):
			return 2
	if Geometry2D.is_point_in_polygon(p, Data.land_beyond()):
		return 0
	return -1


static var _boxes: Array = []


static func _box(points: PackedVector2Array) -> Rect2:
	var r := Rect2(points[0], Vector2.ZERO)
	for q in points:
		r = r.expand(q)
	return r.grow(1.0)


func _texel(p: Vector2) -> Color:
	var x := clampi(int((p.x - ORIGIN.x) / EXTENT.x * TEX_SIZE.x), 0, TEX_SIZE.x - 1)
	var y := clampi(int((p.y - ORIGIN.y) / EXTENT.y * TEX_SIZE.y), 0, TEX_SIZE.y - 1)
	return image.get_pixel(x, y)


func _paint() -> void:
	var w := TEX_SIZE.x
	var h := TEX_SIZE.y
	var mask := Image.create_empty(w, h, false, Image.FORMAT_L8)
	for poly in [Data.land_beyond(), Data.coast(1)] + Data.isles_beyond():
		_fill(mask, poly)
	var soft := _blurred(mask, 1)
	var mid := _blurred(mask, 2)
	var wide := _blurred(mask, 4)
	image = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var p := _texel_pos(x, y)
			var m := mid.get_pixel(x, y).r
			image.set_pixel(x, y, Color(soft.get_pixel(x, y).r, m, wide.get_pixel(x, y).r, height_at(p) * m))
	texture = ImageTexture.create_from_image(image)


## Fills the texels whose centres lie inside `poly`, a row at a time: where the row
## crosses the outline, sorted, gives the runs of land.
func _fill(mask: Image, poly: PackedVector2Array) -> void:
	for y in TEX_SIZE.y:
		var py := _texel_pos(0, y).y
		var xs: Array[float] = []
		for k in poly.size():
			var a := poly[k]
			var b := poly[(k + 1) % poly.size()]
			if (a.y <= py) != (b.y <= py):
				xs.append(a.x + (py - a.y) / (b.y - a.y) * (b.x - a.x))
		xs.sort()
		for i in range(0, xs.size() - 1, 2):
			var x0 := maxi(0, ceili((xs[i] - ORIGIN.x) / EXTENT.x * TEX_SIZE.x - 0.5))
			var x1 := mini(TEX_SIZE.x - 1, floori((xs[i + 1] - ORIGIN.x) / EXTENT.x * TEX_SIZE.x - 0.5))
			for x in range(x0, x1 + 1):
				mask.set_pixel(x, y, Color.WHITE)


func _texel_pos(x: int, y: int) -> Vector2:
	return ORIGIN + Vector2((x + 0.5) / TEX_SIZE.x * EXTENT.x, (y + 0.5) / TEX_SIZE.y * EXTENT.y)


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
	for gy in range(int(ORIGIN.y) + 15, int(ORIGIN.y + EXTENT.y), 30):
		for gx in range(int(ORIGIN.x) + 15, int(ORIGIN.x + EXTENT.x), 30):
			var p := Vector2(gx, gy) + Vector2(rng.randf_range(-9, 9), rng.randf_range(-9, 9))
			if not _clear(p, 16.0) or height_at(p) * inland(p) < 0.68 or rng.randf() > 0.6:
				continue
			peaks.append({"name": PEAK[realm_at(p)], "pos": p, "scale": rng.randf_range(0.85, 1.25),
				"flip": 1.0 if rng.randf() < 0.5 else -1.0})
	# Woods, dunes and the odd lone tree on a finer grid.
	var growth := []
	for gy in range(int(ORIGIN.y) + 6, int(ORIGIN.y + EXTENT.y), 12):
		for gx in range(int(ORIGIN.x) + 6, int(ORIGIN.x + EXTENT.x), 12):
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
	# The land picture already knows the shore; past the map's edge nothing else stands.
	if _texel(p).r < 0.9:
		return false
	if p.x < -40.0 or p.y < -40.0 or p.x > Data.SIZE.x + 40.0 or p.y > Data.SIZE.y + 40.0:
		return true
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
