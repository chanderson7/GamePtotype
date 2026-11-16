extends Control
## The memorial alive, drawn over MemorialScene's picture (240x150, shown "covered") in its
## own pixels: a candle burning on each stone where one is lit, mist drifting along the
## hill, the far camp fire flickering, stars twinkling, fireflies low over the grass, and
## maple leaves falling in the Lantern Grove. Under Reduced motion only the candles' steady
## glow. Add it over the TextureRect: MemorialLife.over(art, culture, lit) with `lit` the
## shown stones' indexes (0 the newest) that have a candle burning.

const Style = preload("res://scripts/ui/style.gd")
const MemorialScene = preload("res://scripts/ui/memorial_scene.gd")

const ART := Vector2(240, 150)

var culture := "vardish"
var lit: Array = []
var _t := 0.0
var _still := false
var _rng := RandomNumberGenerator.new()
var _leaves: Array = []
var _flies: Array = []


static func over(art: Control, culture_id: String, lit_stones: Array) -> Control:
	var life = load("res://scripts/ui/memorial_life.gd").new()
	life.name = "MemorialLife"
	life.culture = culture_id
	life.lit = lit_stones
	life.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	life.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.add_child(life)
	return life


func _ready() -> void:
	_rng.seed = 13
	_still = Style.motion_reduced()
	if culture == "ryumon":
		for i in 12:
			_leaves.append({"x": _rng.randf_range(0, 90), "age": _rng.randf(), "life": _rng.randf_range(6.0, 10.0), "ph": _rng.randf() * TAU})
	for i in 8:
		_flies.append({"at": Vector2(_rng.randf_range(20, 230), _rng.randf_range(100, 145)), "ph": _rng.randf() * TAU, "sp": _rng.randf_range(0.3, 0.6)})
	set_process(not _still)
	queue_redraw()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	for l in _leaves:
		l["age"] = float(l["age"]) + delta / float(l["life"])
		if float(l["age"]) >= 1.0:
			l["age"] = 0.0
			l["x"] = _rng.randf_range(0, 90)
	queue_redraw()


func _k() -> float:
	return maxf(size.x / ART.x, size.y / ART.y)


func _to(at: Vector2) -> Vector2:
	var k := _k()
	return (size - ART * k) * 0.5 + at * k


func _px(at: Vector2, c: Color, w: float = 1.0, h: float = 1.0) -> void:
	draw_rect(Rect2(_to(at.floor()), Vector2(w, h) * _k()), c)


## Where a lit stone's candle stands: a little left of its base.
static func candle_at(i: int) -> Vector2:
	var s := MemorialScene.spot(i)
	return (s["at"] as Vector2) + Vector2(-7.0 * float(s["scale"]), -1.0)


func _draw() -> void:
	var k := _k()
	# Candles on the stones where one is lit.
	for i in lit:
		var at := candle_at(int(i))
		var flick := 1.0 if _still else 0.8 + 0.2 * sin(_t * 9.0 + int(i) * 1.7) + 0.1 * sin(_t * 17.0 + int(i))
		draw_circle(_to(at + Vector2(0.5, -2.0)), 6.0 * k, Color(1.0, 0.7, 0.3, 0.16 * flick))
		draw_circle(_to(at + Vector2(0.5, -2.0)), 3.0 * k, Color(1.0, 0.8, 0.45, 0.2 * flick))
		_px(at, Color("ece5d3"), 1, 2)
		_px(at + Vector2(0, -1 - (0.0 if _still else floorf(sin(_t * 11.0 + i) + 0.5))), Color("ffcf6a"))
	if _still:
		return
	# The far camp fire.
	var f := MemorialScene.CAMP_FIRE
	draw_circle(_to(f), (4.0 + sin(_t * 7.0)) * k, Color(1.0, 0.6, 0.25, 0.12))
	# Mist drifting through the valley beyond the crest, and a thin fog low on the meadow.
	for m in 4:
		var y := 68.0 + m * 4.0
		var x := fmod(_t * (2.0 + m) + m * 60.0, ART.x + 80.0) - 80.0
		draw_rect(Rect2(_to(Vector2(x, y)), Vector2(90, 3) * k), Color(0.75, 0.8, 0.95, 0.06))
		draw_rect(Rect2(_to(Vector2(x - 160.0, y + 2.0)), Vector2(70, 2) * k), Color(0.75, 0.8, 0.95, 0.05))
	for m in 2:
		var x := fmod(_t * (1.5 + m) + m * 110.0, ART.x + 100.0) - 100.0
		draw_rect(Rect2(_to(Vector2(x, 138.0 + m * 5.0)), Vector2(100, 3) * k), Color(0.75, 0.8, 0.95, 0.035))
	# Stars twinkling.
	for i in 14:
		var tw := 0.5 + 0.5 * sin(_t * (1.0 + 0.3 * i) + i * 2.3)
		if tw > 0.75:
			_px(Vector2(fmod(i * 53.0, ART.x), fmod(i * 17.0, 56.0)), Color(1, 1, 0.9, (tw - 0.75) * 2.8))
	# Fireflies low over the grass.
	for fl in _flies:
		var p: Vector2 = fl["at"] + Vector2(sin(_t * float(fl["sp"]) + float(fl["ph"])) * 10.0, cos(_t * float(fl["sp"]) * 1.3 + float(fl["ph"])) * 4.0)
		var b := 0.5 + 0.5 * sin(_t * 2.1 + float(fl["ph"]))
		if b > 0.4:
			_px(p, Color(0.85, 1.0, 0.45, (b - 0.4) * 1.2))
	# Maple leaves falling in the grove.
	for l in _leaves:
		var a: float = l["age"]
		var at := Vector2(float(l["x"]) + a * 30.0 + sin(_t * 1.5 + float(l["ph"])) * 4.0, 50.0 + a * 100.0)
		_px(at, Color(0.78, 0.25, 0.15, 0.9 * minf(1.0, (1.0 - a) * 4.0)), 2, 1)
