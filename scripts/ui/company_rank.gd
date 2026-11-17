extends Control
## A company drawn up for you to look over: its soldiers as they stand on a battlefield,
## three times the size, in ranks on a strip of their own country's ground. Every man of
## the company is there when the strip is wide enough for them. They don't stand like
## statues: one shifts his weight, another settles his grip, a horse stamps. Still under
## Reduced motion.
##
## CompanyRank.make("cavalry", "vardish", 16)

const Art = preload("res://scripts/art/unit_art.gd")
const Style = preload("res://scripts/ui/style.gd")

const SCALE := 3.0
const RANKS := 2
const HEIGHT := 124.0

var type := ""
var culture := "vardish"
var men := 0

var _t := 0.0
var _since := 0.0
## Each man: {col, rank, phase, every (seconds between shifts)}.
var _stand: Array = []
var _laid_for := -1.0


static func make(troop: String, of_culture: String, count: int) -> Control:
	var rank = load("res://scripts/ui/company_rank.gd").new()
	rank.name = "CompanyRank"
	rank.type = troop
	rank.culture = of_culture
	rank.men = count
	rank.custom_minimum_size = Vector2(0, HEIGHT)
	rank.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rank.clip_contents = true
	rank.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rank.visible = Style.illustrations_on()
	return rank


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(not Style.motion_reduced())
	resized.connect(queue_redraw)


func _process(delta: float) -> void:
	_t += delta
	_since += delta
	if _since >= 0.1 and is_visible_in_tree():
		_since = 0.0
		queue_redraw()


## How many men are drawn: all of them, if two ranks of this width hold them.
func shown() -> int:
	_lay()
	return _stand.size()


func _spacing() -> float:
	var w := float(Art.frame(type, 0, 0, culture).get_width())
	return maxf(9.0, w * 0.98) * SCALE


func _lay() -> void:
	if is_equal_approx(_laid_for, size.x):
		return
	_laid_for = size.x
	_stand = []
	var gap := _spacing()
	var per := maxi(1, int(maxf(0.0, size.x - 28.0 - gap * 0.5) / gap))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(type + culture) + men
	var all := mini(men, per * RANKS)
	# One rank while it holds them; then two, the front never the shorter.
	var front := all if all <= per else int(ceil(all / 2.0))
	var rear := all - front
	for rank in [1, 0]:
		var n := rear if rank == 1 else front
		# Equal ranks stand staggered, so each man behind looks between two in front.
		var shift := 0.5 if rank == 1 and rear == front else 0.0
		for i in n:
			_stand.append({"col": i - (n - 1) * 0.5 + shift - (0.25 if rear == front else 0.0), "rank": rank,
				"phase": rng.randf_range(0.0, 40.0), "every": rng.randf_range(3.5, 8.0)})


func _draw() -> void:
	_lay()
	# Their ground: the country's own turf, darker towards the top like a field at a distance.
	var ground: Texture2D = Art.ground(culture)
	var strip := Rect2(0, 0, size.x, size.y)
	var box := StyleBoxFlat.new()
	box.bg_color = Style.NIGHT
	box.set_corner_radius_all(10)
	draw_style_box(box, strip)
	draw_texture_rect_region(ground, Rect2(2, 2, size.x - 4, size.y - 4), Rect2(0, 0, (size.x - 4) / 4.0, (size.y - 4) / 4.0), Color(0.72, 0.72, 0.78))
	draw_rect(Rect2(2, 2, size.x - 4, (size.y - 4) * 0.45), Color(Style.NIGHT, 0.35))
	var gap := _spacing()
	var pivot: Vector2 = Art.pivot(type, culture)
	for m in _stand:
		var rank: int = m["rank"]
		var since := fposmod(_t + float(m["phase"]), float(m["every"]))
		# A shift of weight: the passing step for a moment, then still again.
		var idx := 3 if since < 0.28 and is_processing() else 0
		var tex: Texture2D = Art.frame(type, 0, idx, culture)
		var sz := Vector2(tex.get_size()) * SCALE
		var breath := roundf(sin(_t * 1.6 + float(m["phase"])) * 0.5 + 0.5) if is_processing() else 0.0
		var foot := Vector2(size.x * 0.5 + float(m["col"]) * gap, size.y - 12.0 - rank * 40.0)
		var tone := Color(0.78, 0.78, 0.84) if rank == 1 else Color.WHITE
		draw_texture_rect(tex, Rect2(Vector2(roundf(foot.x - pivot.x * SCALE), roundf(foot.y - sz.y + breath)), sz), false, tone)
