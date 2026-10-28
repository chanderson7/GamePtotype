## The title screen: carry on a campaign, or start a new one, over the Glass Sea at
## dawn, drifting slowly past.
extends Control

const Style = preload("res://scripts/ui/style.gd")
const Cultures = preload("res://scripts/data/cultures.gd")
const WorldData = preload("res://scripts/world/world_data.gd")
const Page = preload("res://scripts/ui/menu_page.gd")
const MapBackdrop = preload("res://scripts/world/map_backdrop.gd")
const SKY_SHADER = preload("res://shaders/map_sky.gdshader")
## The light over the title's map: early morning.
const DAWN := Color(1.0, 0.88, 0.76)

var _confirmation: ConfirmationDialog
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
	veil.color = Color(Style.NIGHT, 0.78)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)
	_point_backdrop()
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var insets := Style.safe_insets(get_viewport())
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_top", 80 + int(insets["top"]))
	margin.add_theme_constant_override("margin_bottom", 80 + int(insets["bottom"]))
	scroll.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 20)
	margin.add_child(col)
	var title := Style.label("Bannerfall", 80, Style.BRASS)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var sub := Style.label("The Glass Sea", Style.LARGE, Style.MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	col.add_child(Page.note("Build a company. Lead the battle. Make your name.", Style.BODY, Style.TEXT))
	col.add_child(Page.note("YOUR CAMPAIGN", Style.SMALL))
	if GameState.has_campaign():
		var w = GameState.world
		var go := _button("Continue campaign", _on_continue)
		Style.make_primary(go)
		col.add_child(go)
		go.grab_focus()
		var where := String(WorldData.settlement(w.player().node)["name"])
		var note := Style.label("%s warband · day %d · near %s" % [
			Cultures.info(GameState.culture)["people"], int(w.hour) / 24 + 1, where], Style.SMALL, Style.MUTED)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(note)
		col.add_child(Page.note("%d men · %d silver · %d days of food" % [GameState.total_men(), GameState.silver, GameState.food_days()]))
	_new_button = _button("New campaign", _on_new)
	if not GameState.has_campaign():
		Style.make_primary(_new_button)
	col.add_child(_new_button)
	if not GameState.has_campaign():
		_new_button.grab_focus()
	col.add_child(Page.note("NEW TO THE GLASS SEA?", Style.SMALL))
	col.add_child(_button("Learn to play", func():
		Scenes.tutorial_return = "res://scenes/title.tscn"
		Scenes.go("res://scenes/tutorial.tscn")))
	col.add_child(_button("Settings", func():
		Scenes.settings_return = "res://scenes/title.tscn"
		Scenes.go("res://scenes/settings.tscn")))
	col.add_child(Page.note("Your campaign saves automatically. The tutorial is optional.", Style.SMALL))


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
	b.custom_minimum_size = Vector2(0, 92)
	b.add_theme_font_size_override("font_size", Style.LARGE)
	b.pressed.connect(callback)
	return b


func _on_continue() -> void:
	Scenes.go("res://scenes/world_map.tscn")


## A deliberate confirmation replaces the timed second tap.
func _on_new() -> void:
	if not GameState.has_campaign():
		Scenes.go("res://scenes/new_campaign.tscn")
		return
	if _confirmation == null:
		_confirmation = ConfirmationDialog.new()
		_confirmation.title = "Start a new campaign?"
		_confirmation.dialog_text = "Choosing a people will replace your saved campaign.\nYour current progress will be lost."
		_confirmation.ok_button_text = "Choose a new people"
		_confirmation.cancel_button_text = "Keep my campaign"
		_confirmation.confirmed.connect(func(): Scenes.go("res://scenes/new_campaign.tscn"))
		add_child(_confirmation)
	_confirmation.popup_centered(Vector2i(620, 260))
	_confirmation.get_cancel_button().grab_focus()
