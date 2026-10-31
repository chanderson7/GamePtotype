## Choose your people: one card per culture. Tapping one starts the campaign at that
## culture's capital.
extends Control

const Style = preload("res://scripts/ui/style.gd")
const Cultures = preload("res://scripts/data/cultures.gd")
const Troops = preload("res://scripts/data/troops.gd")
const WorldData = preload("res://scripts/world/world_data.gd")
const Heraldry = preload("res://scripts/ui/heraldry.gd")


var _tutorial: Button
var _mode_button: Button
var _starting := false

func _ready() -> void:
	theme = Style.make_theme()
	var bg := ColorRect.new()
	bg.color = Style.NIGHT
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var insets := Style.safe_insets(get_viewport())
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 56 + int(insets["top"]))
	margin.add_theme_constant_override("margin_bottom", 40 + int(insets["bottom"]))
	scroll.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 20)
	margin.add_child(col)
	col.add_child(Style.label("Choose your people", 52, Style.BRASS))
	var intro := Style.label("Three realms share the shores of the Glass Sea. Your warband is of one of them, "
		+ "and starts at its capital. You can ride anywhere.", Style.SMALL, Style.MUTED)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(intro)
	_tutorial = Button.new()
	_tutorial.toggle_mode = true
	_tutorial.text = "Tutorial: off (optional)"
	_tutorial.toggled.connect(func(on: bool): _tutorial.text = "Tutorial: %s (optional)" % ("on" if on else "off"))
	_tutorial.custom_minimum_size.y = Style.TOUCH
	col.add_child(_tutorial)
	_mode_button = Button.new()
	_mode_button.toggle_mode = true
	_mode_button.text = "Mode: Iron Company (Default)"
	_mode_button.toggled.connect(func(on: bool): _mode_button.text = "Mode: Casual (Captains survive severe wounds)" if on else "Mode: Iron Company (Default)")
	_mode_button.custom_minimum_size.y = Style.TOUCH
	col.add_child(_mode_button)
	for c in Cultures.ORDER:
		col.add_child(_card(c))
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(0, Style.TOUCH)
	back.pressed.connect(func(): Scenes.go("res://scenes/title.tscn"))
	col.add_child(back)


func _card(culture: String) -> Control:
	var info := Cultures.info(culture)
	var panel := PanelContainer.new()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	v.add_child(head)
	var flag := Control.new()
	flag.custom_minimum_size = Vector2(52, 44)
	flag.draw.connect(func():
		var color: Color = info["color"]
		flag.draw_line(Vector2(4, 2), Vector2(4, 44), Color("6b4a2a"), 3.0)
		Heraldry.flag(flag, Vector2(5, 4), Vector2(44, 32), color, color.darkened(0.45), false))
	head.add_child(flag)
	var name := Style.label(String(info["realm"]), Style.LARGE, info["color"].lightened(0.25))
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(name)
	var blurb := Style.label(String(info["blurb"]), Style.SMALL, Style.TEXT)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(blurb)
	var troops := PackedStringArray()
	for type in Troops.ORDER:
		troops.append(Cultures.troop_name(culture, type))
	var capital := String(WorldData.settlement(WorldData.capital_of_culture(culture))["name"])
	var facts := Style.label("Starts in %s · %s" % [capital, ", ".join(troops)], Style.SMALL, Style.MUTED)
	facts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(facts)
	var go := Button.new()
	go.text = "Lead the %s" % info["people"]
	go.custom_minimum_size = Vector2(0, Style.TOUCH)
	Style.make_primary(go)
	go.pressed.connect(_on_pick.bind(culture))
	v.add_child(go)
	return panel


func _on_pick(culture: String) -> void:
	if _starting:
		return
	_starting = true
	GameState.new_campaign(culture)
	GameState.casual_mode = _mode_button.button_pressed
	GameState.save_game()
	if _tutorial.button_pressed:
		Scenes.tutorial_return = "res://scenes/world_map.tscn"
		Scenes.go("res://scenes/tutorial.tscn")
	else:
		Scenes.go("res://scenes/world_map.tscn")
