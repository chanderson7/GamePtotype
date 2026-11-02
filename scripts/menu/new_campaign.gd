## Choose your people: one card per culture. Tapping one starts the campaign at that
## culture's capital.
extends Control

const Style = preload("res://scripts/ui/style.gd")
const Cultures = preload("res://scripts/data/cultures.gd")
const Troops = preload("res://scripts/data/troops.gd")
const WorldData = preload("res://scripts/world/world_data.gd")
const Heraldry = preload("res://scripts/ui/heraldry.gd")
const Widgets = preload("res://scripts/ui/widgets.gd")
const SettlementVista = preload("res://scripts/ui/settlement_vista.gd")


var _tutorial: Button
var _ironman: Button
var _casual := false
var _mode_holder: Control
var _mode_note: Label
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
	# The tutorial as a switch, the mode as a choice of two, side by side.
	var options := HBoxContainer.new()
	options.add_theme_constant_override("separation", 14)
	col.add_child(options)
	var tut_row := PanelContainer.new()
	tut_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tut_box := Style.box(Style.PANEL, Style.RULE, 2, 18)
	tut_box.content_margin_left = 18
	tut_box.content_margin_right = 10
	tut_row.add_theme_stylebox_override("panel", tut_box)
	var tut_line := HBoxContainer.new()
	tut_row.add_child(tut_line)
	var tut_label := Style.label("Tutorial", Style.SMALL, Style.TEXT)
	tut_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tut_line.add_child(tut_label)
	_tutorial = Widgets.switch(false, func(_on: bool): pass, "TutorialSwitch", "Tutorial")
	tut_line.add_child(_tutorial)
	options.add_child(tut_row)
	_mode_holder = MarginContainer.new()
	_mode_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mode_holder.size_flags_stretch_ratio = 1.4
	options.add_child(_mode_holder)
	_show_mode()
	# Ironman: one save, kept as you go, and no going back.
	var iron_row := PanelContainer.new()
	var iron_box := Style.box(Style.PANEL, Style.RULE, 2, 18)
	iron_box.content_margin_left = 18
	iron_box.content_margin_right = 10
	iron_box.content_margin_top = 10
	iron_box.content_margin_bottom = 10
	iron_row.add_theme_stylebox_override("panel", iron_box)
	var iron_line := HBoxContainer.new()
	iron_line.add_theme_constant_override("separation", 14)
	iron_row.add_child(iron_line)
	var iron_words := VBoxContainer.new()
	iron_words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	iron_words.add_theme_constant_override("separation", 0)
	iron_line.add_child(iron_words)
	iron_words.add_child(Style.label("Ironman", Style.SMALL, Style.TEXT))
	var iron_note := Style.label("One save, kept as you go. No saving your own, no going back.", 19, Style.MUTED)
	iron_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	iron_words.add_child(iron_note)
	_ironman = Widgets.switch(false, func(_on: bool): pass, "IronmanSwitch", "Ironman")
	iron_line.add_child(_ironman)
	col.add_child(iron_row)
	_mode_note = Style.label("", Style.SMALL, Style.MUTED)
	_mode_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_mode_note)
	_show_mode()
	# The people picked on Home comes first, lit.
	var pick := Scenes.new_campaign_pick
	Scenes.new_campaign_pick = ""
	var order: Array = Cultures.ORDER.duplicate()
	if order.has(pick):
		order.erase(pick)
		order.push_front(pick)
	for c in order:
		var card := _card(c)
		if c == pick:
			card.name = "PickedPeople"
			var sb := Style.box(Style.PANEL, Style.BRASS, 3, 20)
			sb.content_margin_left = 20
			sb.content_margin_right = 20
			sb.content_margin_top = 18
			sb.content_margin_bottom = 18
			card.add_theme_stylebox_override("panel", sb)
		col.add_child(card)
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(0, Style.TOUCH)
	back.pressed.connect(func(): Scenes.go("res://scenes/title.tscn"))
	col.add_child(back)


## Iron Company or Casual, the picked one lit, with what it means underneath.
func _show_mode() -> void:
	for c in _mode_holder.get_children():
		c.queue_free()
	_mode_holder.add_child(Widgets.segmented(["Iron Company", "Casual"], 1 if _casual else 0, func(i: int):
		_casual = i == 1
		_show_mode(), "ModeChoice"))
	if _mode_note != null:
		_mode_note.text = "Casual: captains survive what would kill them, with severe wounds." if _casual else "Iron Company: fallen captains can die for good."


func _card(culture: String) -> Control:
	var info := Cultures.info(culture)
	var panel := PanelContainer.new()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	# The card opens on the capital's gate, so the choice looks like a place.
	var capital_id := String(WorldData.capital_of_culture(culture))
	if Style.illustrations_on():
		var scene := SettlementVista.make(capital_id, null, 260.0)
		scene.name = "CapitalScene_%s" % culture
		v.add_child(scene)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	v.add_child(head)
	var flag := Control.new()
	flag.custom_minimum_size = Vector2(64, 84)
	flag.draw.connect(func(): Heraldry.realm_banner(flag, Heraldry.realm_of_culture(culture), Rect2(Vector2.ZERO, flag.size)))
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
	GameState.casual_mode = _casual
	GameState.ironman = _ironman.button_pressed
	GameState.save_game()
	if _tutorial.button_pressed:
		Scenes.tutorial_return = "res://scenes/world_map.tscn"
		Scenes.go("res://scenes/tutorial.tscn")
	else:
		Scenes.go("res://scenes/world_map.tscn")
