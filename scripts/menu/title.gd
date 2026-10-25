## The title screen: carry on a campaign, or start a new one, over the Glass Sea at
## dawn, drifting slowly past.
extends Control

const Style = preload("res://scripts/ui/style.gd")
const Cultures = preload("res://scripts/data/cultures.gd")
const WorldData = preload("res://scripts/world/world_data.gd")
const SoundToggles = preload("res://scripts/ui/sound_toggles.gd")
const MapBackdrop = preload("res://scripts/world/map_backdrop.gd")
const SKY_SHADER = preload("res://shaders/map_sky.gdshader")
## The light over the title's map: early morning.
const DAWN := Color(1.0, 0.88, 0.76)

var _restart_armed := 0.0
var _new_button: Button
var _backdrop
var _sky: ColorRect
var _drift := 0.0


func _ready() -> void:
	theme = Style.make_theme()
	# Headless smoke test: `-- --autoplay` starts a Vardish campaign and rides out.
	if OS.get_cmdline_user_args().has("--autoplay"):
		GameState.new_campaign(Cultures.VARDISH)
		get_tree().change_scene_to_file.call_deferred("res://scenes/world_map.tscn")
		return
	Sound.play_music("title")
	_build()


func _build() -> void:
	# The sea fills the screen; the land sits on it (both drawn below this screen's own
	# controls).
	_backdrop = MapBackdrop.new()
	add_child(_backdrop)
	_sky = ColorRect.new()
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sky.material = _backdrop.shader_material(SKY_SHADER)
	(_sky.material as ShaderMaterial).set_shader_parameter("daylight", DAWN)
	add_child(_sky)
	# Darker toward the middle, where the words are.
	var veil := ColorRect.new()
	veil.color = Color(Style.NIGHT, 0.5)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)
	_point_backdrop()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var insets := Style.safe_insets(get_viewport())
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_top", 160 + int(insets["top"]))
	margin.add_theme_constant_override("margin_bottom", 80 + int(insets["bottom"]))
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 20)
	margin.add_child(col)
	var title := Style.label("Bannerfall", 96, Style.BRASS)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var sub := Style.label("The Glass Sea", Style.LARGE, Style.MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)
	if GameState.has_campaign():
		var w = GameState.world
		var go := _button("Continue", _on_continue)
		Style.make_primary(go)
		col.add_child(go)
		var where := String(WorldData.settlement(w.player().node)["name"])
		var note := Style.label("%s warband · day %d · near %s" % [
			Cultures.info(GameState.culture)["people"], int(w.hour) / 24 + 1, where], Style.SMALL, Style.MUTED)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(note)
	_new_button = _button("New campaign", _on_new)
	if not GameState.has_campaign():
		Style.make_primary(_new_button)
	col.add_child(_new_button)
	col.add_child(SoundToggles.make())


func _process(delta: float) -> void:
	if _backdrop != null:
		_drift += delta
		_point_backdrop()


## The camera drifts in a slow loop over the three realms.
func _point_backdrop() -> void:
	var vs := get_viewport_rect().size
	var center := Vector2(500.0 + cos(_drift * 0.035) * 250.0, 800.0 + sin(_drift * 0.024) * 480.0)
	_backdrop.point_camera(center, vs.x / 560.0, vs * 0.5, vs, [_sky])


func _button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 92)
	b.add_theme_font_size_override("font_size", Style.LARGE)
	b.pressed.connect(callback)
	return b


func _on_continue() -> void:
	Scenes.go("res://scenes/world_map.tscn")


## Starting over throws away the campaign you have, so it takes a second tap.
func _on_new() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if GameState.has_campaign() and now >= _restart_armed:
		_restart_armed = now + 3.0
		_new_button.text = "Tap again: your campaign will be lost"
		return
	Scenes.go("res://scenes/new_campaign.tscn")
