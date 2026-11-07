## Choose your people: one card per culture. Tapping one starts the campaign at that
## culture's capital. The card is the same one Home shows the first time (people_card).
extends Control

const Style = preload("res://scripts/ui/style.gd")
const Cultures = preload("res://scripts/data/cultures.gd")
const WorldData = preload("res://scripts/world/world_data.gd")
const Heraldry = preload("res://scripts/ui/heraldry.gd")
const Widgets = preload("res://scripts/ui/widgets.gd")
const Page = preload("res://scripts/ui/menu_page.gd")
const SettlementVista = preload("res://scripts/ui/settlement_vista.gd")

## What each people does best, as icons with a word: the shape of their army.
const STRENGTHS := {
	"vardish": [["shieldwall", "Shield walls"], ["bow", "Crossbows"], ["ride", "Knights"]],
	"kharzani": [["ride", "Horse archers"], ["volley", "Javelins"], ["speed", "Fast"]],
	"ryumon": [["bow", "Longbows"], ["schiltron", "Spear blocks"], ["fight", "Samurai"]],
}
## Room for the bottom bar under the page, above the safe area.
const BAR_ROOM := 124.0

var _tutorial: Button
var _ironman: Button
var _casual := false
var _mode_holder: Control
var _mode_note: Label
var _starting := false


## A people as a card: their capital's gate, their banner and name, a line about them and
## what their army is good at. Home and this screen both use it. The column inside is
## the card's child named "Body", for a caller's own button.
static func people_card(culture: String, vista_height: float = 220.0) -> PanelContainer:
	var info := Cultures.info(culture)
	var panel := PanelContainer.new()
	panel.name = "PeopleCard_%s" % culture
	var sb := Style.box(Style.PANEL, Style.RULE, 2, 20)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 16
	sb.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.name = "Body"
	v.add_theme_constant_override("separation", 10)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(v)
	# The card opens on the capital's gate, so the choice looks like a place.
	var capital_id := String(WorldData.capital_of_culture(culture))
	if Style.illustrations_on():
		var scene := SettlementVista.make(capital_id, null, vista_height)
		scene.name = "CapitalScene_%s" % culture
		v.add_child(scene)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(head)
	var flag := Widgets.banner(Heraldry.realm_of_culture(culture), Vector2(54, 74))
	flag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(flag)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	names.add_theme_constant_override("separation", 0)
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(names)
	names.add_child(Style.name_label(String(info["people"]), Style.TITLE_SIZE))
	var realm := Style.label(String(info["realm"]), Style.SMALL, Style.BRASS)
	realm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	names.add_child(realm)
	var blurb := Style.label(String(info["blurb"]), Style.SMALL, Color("c9cfdf"))
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(blurb)
	var chips: Array = []
	for s in STRENGTHS.get(culture, []):
		chips.append(Widgets.chip(String(s[1]), Style.TEXT, "", String(s[0])))
	var strengths := Widgets.chip_row(chips)
	strengths.name = "Strengths"
	strengths.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(strengths)
	return panel


## Light a people card (brass edge) or not.
static func light_card(panel: PanelContainer, on: bool) -> void:
	var sb := (panel.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
	sb.border_color = Style.BRASS if on else Style.RULE
	sb.set_border_width_all(3 if on else 2)
	panel.add_theme_stylebox_override("panel", sb)


func _ready() -> void:
	var insets := Style.safe_insets(get_viewport())
	var col := Page.frame(self, BAR_ROOM + float(insets["bottom"]))
	col.add_child(Style.label("Choose your people", 52, Style.BRASS))
	var intro := Style.label("Three realms share the shores of the Glass Sea. You start at your people's capital and can ride anywhere.", Style.SMALL, Style.MUTED)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(intro)
	# How the campaign runs: the tutorial, whether captains can die, and Ironman, together.
	var how := Widgets.card(col, "How you'll play")
	how.add_child(_option_row("Tutorial", "Six short lessons before you ride out.", false, "TutorialSwitch"))
	_tutorial = how.find_child("TutorialSwitch", true, false) as Button
	_mode_holder = MarginContainer.new()
	how.add_child(_mode_holder)
	_mode_note = Style.label("", Style.SMALL, Style.MUTED)
	_mode_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	how.add_child(_mode_note)
	_show_mode()
	# Ironman: one save, kept as you go, and no going back.
	how.add_child(_option_row("Ironman", "One save, kept as you go. No saves of your own, no going back.", false, "IronmanSwitch"))
	_ironman = how.find_child("IronmanSwitch", true, false) as Button
	# The people picked on Home comes first, lit.
	var pick := Scenes.new_campaign_pick
	Scenes.new_campaign_pick = ""
	var order: Array = Cultures.ORDER.duplicate()
	if order.has(pick):
		order.erase(pick)
		order.push_front(pick)
	for c in order:
		var card := people_card(c)
		var go := Button.new()
		go.name = "Lead_%s" % c
		go.text = "Lead the %s" % Cultures.info(c)["people"]
		go.icon = Widgets.icon("advance")
		go.custom_minimum_size = Vector2(0, Style.TOUCH)
		Style.make_primary(go)
		for k in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
			go.add_theme_color_override(k, Style.BRASS_INK)
		go.pressed.connect(_on_pick.bind(c))
		card.get_node("Body").add_child(go)
		if c == pick:
			card.name = "PickedPeople"
			light_card(card, true)
		col.add_child(card)
	var bar := Widgets.bottom_bar(Widgets.back_button(func(): Scenes.go("res://scenes/title.tscn")), insets)
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(bar)


## A setting with its name and a note on the left, its switch on the right.
func _option_row(title: String, note: String, on: bool, switch_name: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 0)
	row.add_child(words)
	words.add_child(Style.label(title, Style.BODY, Style.TEXT))
	var n := Style.label(note, Style.SMALL, Style.MUTED)
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(n)
	row.add_child(Widgets.switch(on, func(_on: bool): pass, switch_name, title))
	return row


## Mortal or Casual, the picked one lit, with what it means underneath.
func _show_mode() -> void:
	for c in _mode_holder.get_children():
		c.queue_free()
	_mode_holder.add_child(Widgets.segmented(["Mortal", "Casual"], 1 if _casual else 0, func(i: int):
		_casual = i == 1
		_show_mode(), "ModeChoice", ["skull", "wounded"]))
	if _mode_note != null:
		_mode_note.text = "Casual: captains survive what would kill them, with severe wounds." if _casual else "Mortal: fallen captains can die for good."


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


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Scenes.go("res://scenes/title.tscn")
		get_viewport().set_input_as_handled()
