## A small picture for each step of the tutorial, drawn from the game's own art: the map's
## settlements and riders, the battle's squads, the order icons. What to tap is ringed in
## brass. Only for looks; nothing here touches the campaign.
extends Control

const MapArt = preload("res://scripts/art/map_art.gd")
const Art = preload("res://scripts/art/unit_art.gd")
const Troops = preload("res://scripts/data/troops.gd")
const Style = preload("res://scripts/ui/style.gd")
const Widgets = preload("res://scripts/ui/widgets.gd")
const Heraldry = preload("res://scripts/ui/heraldry.gd")

const BLUE := Color(0.29, 0.45, 0.82)
const RED := Color(0.78, 0.25, 0.22)
const GRASS := Color("5d7a40")
const GRASS_DARK := Color("4f6c36")

var step := 0
var _t := 0.0


static func make(lesson: int) -> Control:
	var art := new()
	art.step = lesson
	art.name = "TutorialPicture"
	art.custom_minimum_size = Vector2(0, 300)
	art.clip_contents = true
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return art


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _ready() -> void:
	set_process(not Style.motion_reduced())


func _draw() -> void:
	draw_style_box(Style.box(GRASS, Style.RULE, 2, 18), Rect2(Vector2.ZERO, size))
	match step:
		0: _ride()
		1: _supplies()
		2: _fight()
		3: _command()
		4: _ground()
		_: _captains()


func _sprite(name: String, at: Vector2, scale: float, color: Color = BLUE, frame: int = 0, flip: bool = false) -> void:
	if not MapArt.has(name):
		return
	var tex := MapArt.texture(name, frame, color)
	var pivot := MapArt.pivot(name)
	draw_set_transform(at, 0.0, Vector2(scale * (-1.0 if flip else 1.0), scale))
	draw_texture(tex, -pivot)
	draw_set_transform(Vector2.ZERO)


func _unit(type: String, team: int, at: Vector2, scale: float) -> void:
	var tex := Art.frame(type, team, 0, "vardish")
	if tex == null:
		return
	draw_set_transform(at, 0.0, Vector2(scale, scale))
	draw_texture(tex, -Art.pivot(type, "vardish"))
	draw_set_transform(Vector2.ZERO)


## The brass ring round what to tap, breathing gently.
func _ring(at: Vector2, r: float) -> void:
	var pulse := 0.5 + 0.5 * sin(_t * 3.0)
	draw_arc(at, r + pulse * 6.0, 0.0, TAU, 40, Color(Style.BRASS, 0.95 - pulse * 0.4), 5.0)


func _plate(at: Vector2, text: String, color: Color = Style.TEXT) -> void:
	var font := get_theme_default_font()
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	var rect := Rect2(at - Vector2(w * 0.5 + 10.0, 0), Vector2(w + 20.0, 30))
	draw_style_box(Style.box(Color(0.06, 0.07, 0.1, 0.8), Color(0, 0, 0, 0), 0, 8), rect)
	draw_string(font, rect.position + Vector2(10, 22), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, color)


func _caption(text: String) -> void:
	var font := get_theme_default_font()
	var rect := Rect2(Vector2(16, size.y - 54), Vector2(size.x - 32, 40))
	draw_style_box(Style.box(Color(Style.NIGHT, 0.92), Style.BRASS, 2, 12), rect)
	draw_string(font, rect.position + Vector2(14, 28), text, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 28, 21, Style.TEXT)


func _trees(points: Array) -> void:
	for p in points:
		_sprite("tree", p, 3.0, BLUE)


# ---------------------------------------------------------------- the six pictures

func _ride() -> void:
	var a := Vector2(size.x * 0.22, 190)
	var b := Vector2(size.x * 0.7, 120)
	draw_line(a, b, Color("6b4a2a"), 10.0)
	draw_line(a, b, Color("d8c08a"), 6.0)
	_trees([Vector2(60, 90), Vector2(110, 70), Vector2(size.x - 60, 220), Vector2(size.x * 0.45, 230)])
	_sprite("vardish/village", a, 3.0)
	_sprite("vardish/town", b, 3.0)
	_plate(b + Vector2(0, 12), "Highcliff", Style.BRASS)
	var along := fposmod(_t * 0.12, 1.0)
	_sprite("mounted/vardish", a.lerp(b, 0.15 + along * 0.6) + Vector2(0, 8), 2.6, BLUE, int(_t * 4.0) % 2)
	_ring(b + Vector2(0, -20), 52.0)
	_caption("Tap Highcliff, then Ride there")


func _supplies() -> void:
	draw_rect(Rect2(0, 0, size.x, 70), Color(Style.NIGHT, 0.95))
	var tiles := [["silver", "400"], ["food", "5d"], ["renown", "0"]]
	for i in tiles.size():
		var r := Rect2(Vector2(size.x - 420 + i * 136, 12), Vector2(124, 46))
		draw_style_box(Style.box(Style.RAISED, Style.RULE, 2, 12), r)
		var tex := Widgets.icon(String(tiles[i][0]))
		if tex != null:
			draw_texture_rect(tex, Rect2(r.position + Vector2(10, 9), Vector2(28, 28)), false)
		draw_string(get_theme_default_font(), r.position + Vector2(48, 32), String(tiles[i][1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Style.TEXT)
	_ring(Vector2(size.x - 420 + 136 + 62, 35), 44.0)
	_sprite("vardish/village", Vector2(size.x * 0.32, 200), 3.2)
	_plate(Vector2(size.x * 0.32, 212), "Ashby · food is cheap")
	_caption("Watch silver and food; buy rations in villages")


func _fight() -> void:
	_trees([Vector2(70, 120), Vector2(size.x - 80, 110)])
	_sprite("mounted/vardish", Vector2(size.x * 0.3, 190), 3.0, BLUE, 0)
	_sprite("outlaws/vardish", Vector2(size.x * 0.66, 180), 3.0, Color("4a4038"), 0, true)
	_ring(Vector2(size.x * 0.66, 150), 56.0)
	# The odds, as the encounter sheet shows them.
	var bar := Rect2(Vector2(size.x * 0.18, 40), Vector2(size.x * 0.64, 18))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * 0.62, bar.size.y)), BLUE)
	draw_rect(Rect2(bar.position + Vector2(bar.size.x * 0.62, 0), Vector2(bar.size.x * 0.38, bar.size.y)), RED)
	_caption("Lead the fight, send your men in, or ride away")


func _command() -> void:
	for y in range(0, int(size.y), 18):
		draw_rect(Rect2(0, y, size.x, 9), GRASS_DARK if (y / 18) % 2 == 0 else GRASS)
	for i in 3:
		_unit(String(Troops.ORDER[i % Troops.ORDER.size()]), 1, Vector2(size.x * (0.3 + i * 0.2), 80), 2.2)
	for i in 3:
		_unit(String(Troops.ORDER[(i + 1) % Troops.ORDER.size()]), 0, Vector2(size.x * (0.3 + i * 0.2), 200), 2.2)
	# Drag a line to form your squads along it.
	var from := Vector2(size.x * 0.24, 150)
	var to := Vector2(size.x * 0.76, 150)
	draw_dashed_line(from, from.lerp(to, fposmod(_t * 0.4, 1.0)), Style.BRASS, 4.0, 10.0)
	var fight := Rect2(Vector2(size.x - 170, 14), Vector2(150, 50))
	draw_style_box(Style.box(Style.BRASS, Color(0, 0, 0, 0), 0, 12), fight)
	draw_string(get_theme_default_font(), fight.position + Vector2(44, 34), "Fight", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("1a1420"))
	_ring(fight.get_center(), 62.0)
	_caption("Place squads or drag a line, then press Fight")


func _ground() -> void:
	# A hill, lit from the upper left, and a wood.
	draw_circle(Vector2(size.x * 0.3, 150), 110.0, Color("6c8a48"))
	draw_circle(Vector2(size.x * 0.28, 140), 70.0, Color("7a9a52"))
	_trees([Vector2(size.x * 0.68, 110), Vector2(size.x * 0.76, 130), Vector2(size.x * 0.72, 160), Vector2(size.x * 0.82, 100)])
	_unit(String(Troops.ARCHERS), 0, Vector2(size.x * 0.3, 140), 2.2)
	var icons := ["shieldwall", "schiltron", "volley", "wheel"]
	for i in icons.size():
		var r := Rect2(Vector2(20 + i * 74, 16), Vector2(62, 62))
		draw_style_box(Style.box(Style.RAISED, Style.RULE, 2, 12), r)
		var tex := Widgets.icon(icons[i])
		if tex != null:
			draw_texture_rect(tex, r.grow(-12), false)
	_ring(Vector2(20 + 2 * 74 + 31, 47), 44.0)
	_caption("High ground helps bows; woods shelter from arrows")


func _captains() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(Style.NIGHT, 0.55))
	# Two companies side by side, and the bond growing between them.
	for i in 2:
		var at := Vector2(size.x * (0.3 + i * 0.4), 150)
		_unit(String(Troops.ORDER[i]), 0, at, 2.6)
		Heraldry.realm_banner(self, "vardmark", Rect2(at + Vector2(-60, -120), Vector2(36, 50)))
	var mid := Vector2(size.x * 0.5, 120)
	var tex := Widgets.icon("heart")
	if tex != null:
		draw_texture_rect(tex, Rect2(mid - Vector2(26, 26), Vector2(52, 52)), false, Style.BRASS)
	_ring(mid, 42.0)
	_caption("Captains who fight side by side grow bonds")
