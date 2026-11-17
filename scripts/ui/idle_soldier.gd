extends TextureRect
## A troop's portrait that doesn't stand like a statue: the icon from unit_art.gd, which
## every few seconds shifts its weight for a moment (the passing step of its walk), each
## portrait to its own time. Still under Reduced motion. A drop-in for the TextureRect
## the rosters used: IdleSoldier.make("cavalry", "vardish").

const Art = preload("res://scripts/art/unit_art.gd")
const Style = preload("res://scripts/ui/style.gd")

var type := ""
var culture := "vardish"
var team := 0
var _t := 0.0
var _every := 5.0
var _shifted := false


static func make(troop: String, of_culture: String, of_team: int = 0) -> TextureRect:
	var p = load("res://scripts/ui/idle_soldier.gd").new()
	p.type = troop
	p.culture = of_culture
	p.team = of_team
	p.texture = Art.icon(troop, of_team, of_culture)
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	p.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	p.custom_minimum_size = Vector2(64, 64)
	return p


func _ready() -> void:
	# Its own time, from where it sits in the tree, so a roster doesn't shift as one man.
	var seed_ := hash(String(get_path()))
	_every = 3.8 + (seed_ % 37) * 0.1
	_t = (seed_ % 23) * 0.2
	set_process(not Style.motion_reduced())


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	var shift := fposmod(_t, _every) < 0.32
	if shift != _shifted:
		_shifted = shift
		texture = Art.icon(type, team, culture, 3 if shift else 0)
