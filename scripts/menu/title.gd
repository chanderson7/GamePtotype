## The title screen: carry on a campaign, or start a new one.
extends Control

const Style = preload("res://scripts/ui/style.gd")
const Cultures = preload("res://scripts/data/cultures.gd")
const WorldData = preload("res://scripts/world/world_data.gd")

var _restart_armed := 0.0
var _new_button: Button


func _ready() -> void:
	theme = Style.make_theme()
	# Headless smoke test: `-- --autoplay` starts a Vardish campaign and rides out.
	if OS.get_cmdline_user_args().has("--autoplay"):
		GameState.new_campaign(Cultures.VARDISH)
		get_tree().change_scene_to_file.call_deferred("res://scenes/world_map.tscn")
		return
	_build()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Style.NIGHT
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
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


func _button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 92)
	b.add_theme_font_size_override("font_size", Style.LARGE)
	b.pressed.connect(callback)
	return b


func _on_continue() -> void:
	get_tree().change_scene_to_file("res://scenes/world_map.tscn")


## Starting over throws away the campaign you have, so it takes a second tap.
func _on_new() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if GameState.has_campaign() and now >= _restart_armed:
		_restart_armed = now + 3.0
		_new_button.text = "Tap again: your campaign will be lost"
		return
	get_tree().change_scene_to_file("res://scenes/new_campaign.tscn")
