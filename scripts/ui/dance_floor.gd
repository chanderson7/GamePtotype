extends Control
## The dancers on a hall's floor at a dance: couples turning about each other as they go
## round the room, drawn in the hall painting's own pixels (hall_scene.gd, 240 x 150,
## shown "covered"), dressed as their people dress. When you take the floor yourself, a
## couple in brass trim joins at the front: you and your partner. Still under Reduced
## motion.
##
## Add it as a child of the TextureRect that shows the hall: DanceFloor.over(hall, culture).

const Style = preload("res://scripts/ui/style.gd")

const ART := Vector2(240, 150)
## The floor the dance goes round: its middle and how far the round reaches, in the painting.
const FLOOR := Vector2(120.0, 107.0)
const REACH := Vector2(66.0, 4.0)
const COUPLES := 6
const SKIN := [Color("e2b284"), Color("c99064"), Color("f0c8a0"), Color("b07a52")]
const HAIR := [Color("3a2a1c"), Color("6a4a2c"), Color("1c1a22"), Color("a8763a"), Color("8a8a90")]
## What each people wears to a dance: gowns and robes for one of a couple, tunics and
## coats for the other, and how quick the measure is.
const DRESS := {
	"vardish": {"gown": ["8a2f3a", "2f5a8a", "3f7a52", "b8893a", "6a3f7a"], "coat": ["3a4a6a", "5a3a2a", "2f4a3a", "4a4a52"], "trim": "d8d2c0", "pace": 1.0},
	"kharzani": {"gown": ["c9662b", "1f7a6e", "a8261c", "d9a944", "5a3f8a"], "coat": ["ece6d6", "2f6a8a", "8a5a2a", "3a3a4a"], "trim": "f4cf86", "pace": 1.15},
	"ryumon": {"gown": ["b8352a", "e8c8d0", "3a4a7a", "d8d2c0", "5a7a5a"], "coat": ["2a2e3a", "4a3a3a", "3a4a5a", "5a5248"], "trim": "f1ece0", "pace": 0.75},
}

var culture := "vardish"
## The night's light on the dancers (the hall is painted for dusk or night).
var tone := Color(0.96, 0.9, 0.86)

var _t := 0.0
var _since := 0.0
var _couples: Array = []
## 0 while you watch, rising to 1 once you've taken the floor.
var _lead := 0.0
var _leading := false
var _still := false


static func over(art: Control, culture_id: String) -> Control:
	var floor_ = load("res://scripts/ui/dance_floor.gd").new()
	floor_.name = "DanceFloor"
	floor_.culture = culture_id if DRESS.has(culture_id) else "vardish"
	floor_.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	floor_.mouse_filter = Control.MOUSE_FILTER_IGNORE
	floor_.visible = Style.illustrations_on()
	art.add_child(floor_)
	return floor_


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_still = Style.motion_reduced()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(culture) + 5
	var dress: Dictionary = DRESS[culture]
	for i in COUPLES:
		_couples.append(_couple(rng, dress, false))
	set_process(not _still)


func _couple(rng: RandomNumberGenerator, dress: Dictionary, lead: bool) -> Dictionary:
	var gowns: Array = dress["gown"]
	var coats: Array = dress["coat"]
	return {"turn": rng.randf_range(0.0, TAU), "lead": lead,
		"a": {"gown": true, "cloth": Color(String(gowns[rng.randi() % gowns.size()])), "skin": SKIN[rng.randi() % SKIN.size()], "hair": HAIR[rng.randi() % HAIR.size()]},
		"b": {"gown": false, "cloth": Color(String(coats[rng.randi() % coats.size()])), "skin": SKIN[rng.randi() % SKIN.size()], "hair": HAIR[rng.randi() % HAIR.size()]}}


## You take the floor: a couple in brass trim comes to the front of the dance.
func take_floor() -> void:
	if _leading:
		return
	_leading = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var pair := _couple(rng, DRESS[culture], true)
	pair["b"]["cloth"] = Style.PLAYER_DARK
	_couples.append(pair)
	if _still:
		_lead = 1.0
	queue_redraw()


## How many couples are on the floor.
func couples() -> int:
	return _couples.size()


func _process(delta: float) -> void:
	_t += delta
	_since += delta
	if _leading:
		_lead = minf(1.0, _lead + delta / 1.2)
	if _since >= 1.0 / 12.0 and is_visible_in_tree():
		_since = 0.0
		queue_redraw()


func _k() -> float:
	return maxf(size.x / ART.x, size.y / ART.y)


func _to(at: Vector2) -> Vector2:
	var k := _k()
	return (size - ART * k) * 0.5 + at * k


func _px(x: float, y: float, w: float, h: float, c: Color) -> void:
	draw_rect(Rect2(_to(Vector2(roundf(x), roundf(y))), Vector2(w, h) * _k()), c)


func _lit(c: Color, a: float = 1.0) -> Color:
	return Color(c.r * tone.r, c.g * tone.g, c.b * tone.b, a)


func _draw() -> void:
	var pace: float = DRESS[culture]["pace"]
	var trim := Color(String(DRESS[culture]["trim"]))
	var figures: Array = []
	var n := COUPLES
	for i in _couples.size():
		var pair: Dictionary = _couples[i]
		var mid: Vector2
		var alpha := 1.0
		if bool(pair["lead"]):
			# Yours: at the front, in the middle, a little apart from the round.
			mid = FLOOR + Vector2(sin(_t * 0.5 * pace) * 10.0, REACH.y + 2.0)
			alpha = _lead
		else:
			var round_at := TAU * i / n + _t * 0.16 * pace
			mid = FLOOR + Vector2(cos(round_at) * REACH.x, sin(round_at) * REACH.y)
		var turn := float(pair["turn"]) + _t * 1.5 * pace
		var off := Vector2(cos(turn) * 6.0, sin(turn) * 1.2)
		# A step to the measure: up on the beat, down between.
		var lift := 1.0 if sin(_t * 5.0 * pace + i) > 0.3 and not _still else 0.0
		figures.append([mid + off, pair["a"], -signf(off.x), lift, alpha, bool(pair["lead"])])
		figures.append([mid - off, pair["b"], signf(off.x), 1.0 - lift if not _still else 0.0, alpha, bool(pair["lead"])])
	figures.sort_custom(func(p, q): return float(p[0].y) < float(q[0].y))
	for f in figures:
		_figure(f[0], f[1], float(f[2]), float(f[3]), float(f[4]), trim, bool(f[5]))


## One dancer, feet at `at`: 23 pixels tall, a gown that sways or a coat over two legs,
## an arm out to the partner on the side `toward` (-1 left, 1 right).
func _figure(at: Vector2, who: Dictionary, toward: float, lift: float, alpha: float, trim: Color, lead: bool) -> void:
	if alpha <= 0.01:
		return
	var x := roundf(at.x)
	var y := roundf(at.y - lift)
	var cloth := _lit(who["cloth"], alpha)
	var dark := _lit(Color(who["cloth"]).darkened(0.35), alpha)
	var skin := _lit(who["skin"], alpha)
	var edge := _lit(Style.BRASS if lead else trim, alpha)
	_px(x - 4, at.y, 9, 1, Color(0, 0, 0, 0.3 * alpha))
	var hair := _lit(who["hair"], alpha)
	if bool(who["gown"]):
		var sway := roundf(sin(_t * 3.0 + at.x * 0.3) * 1.0) if not _still else 0.0
		for r in 12:
			var half := 2.0 + floorf(r * 0.34)
			var lean := roundf(sway * r / 11.0)
			_px(x - half + lean, y - 12 + r, half * 2.0 + 1.0, 1, dark if int(r + x) % 4 == 3 else cloth)
		_px(x - 5 + sway, y - 1, 11, 1, edge)
		_px(x - 2, y - 18, 5, 6, cloth)
		_px(x - 2, y - 13, 5, 1, edge)
		# Long hair down the back, away from the partner.
		_px(x + (-3.0 if toward >= 0.0 else 2.0), y - 21, 2, 6, hair)
	else:
		var stride := 1.0 if lift > 0.5 else 0.0
		_px(x - 3, y - 9, 3, 9 - stride, dark)
		_px(x + 1, y - 9, 3, 8 + stride, dark)
		_px(x - 3, y - 18, 7, 10, cloth)
		_px(x - 3, y - 10, 7, 1, edge)
		_px(x - 3, y - 18, 7, 1, edge)
	# Head and hair, and the arm held out to the partner.
	_px(x - 2, y - 22, 4, 4, skin)
	_px(x - 2, y - 23, 4, 2, hair)
	if toward != 0.0:
		_px(x + (3.0 if toward > 0.0 else -5.0), y - 16, 3, 2, cloth)
		_px(x + (6.0 if toward > 0.0 else -6.0), y - 16, 1, 2, skin)
