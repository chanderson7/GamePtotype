## The warband: the squads, captains, bonds and the fallen that carry between battles.
## Opened from the map. Run on its own (no campaign yet), it can still start a battle.
extends Control

const Troops = preload("res://scripts/data/troops.gd")
const Style = preload("res://scripts/ui/style.gd")
const Art = preload("res://scripts/art/unit_art.gd")
const Captains = preload("res://scripts/data/captains.gd")
const Cultures = preload("res://scripts/data/cultures.gd")
const Units = preload("res://scripts/data/units.gd")
const WorldData = preload("res://scripts/world/world_data.gd")


func _ready() -> void:
	theme = Style.make_theme()
	_build()


func _build() -> void:
	for child in get_children():
		child.queue_free()

	var bg := ColorRect.new()
	bg.color = Style.NIGHT
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_right", 36)
	var insets := Style.safe_insets(get_viewport())
	margin.add_theme_constant_override("margin_top", 64 + int(insets["top"]))
	margin.add_theme_constant_override("margin_bottom", 40 + int(insets["bottom"]))
	scroll.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	margin.add_child(col)

	col.add_child(Style.label("Warband", 72, Style.BRASS))
	var people := String(Cultures.info(GameState.culture)["people"])
	var w = GameState.world
	if w != null:
		var where := String(WorldData.settlement(w.player().node)["name"])
		col.add_child(Style.label("%s · day %d · near %s" % [people, int(w.hour) / 24 + 1, where], Style.BODY, Style.MUTED))
	else:
		col.add_child(Style.label(people, Style.BODY, Style.MUTED))
	var days := GameState.food_days()
	var purse := Style.label("%d silver · food for %s · %d renown" % [GameState.silver,
		"1 day" if days == 1 else "%d days" % days, GameState.renown], Style.BODY, Style.TEXT)
	purse.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(purse)

	var last: Dictionary = GameState.last_result
	if not last.is_empty():
		var won: bool = last["won"]
		var line := "Last battle: %s. Lost %d men, cut down %d." % ["Victory" if won else "Defeat", last["lost"], last["killed"]]
		var last_label := Style.label(line, Style.BODY, Style.BRASS if won else Style.ENEMY_LIGHT)
		last_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(last_label)

	var back := Button.new()
	back.custom_minimum_size = Vector2(0, 92)
	back.add_theme_font_size_override("font_size", Style.LARGE)
	Style.make_primary(back)
	if w != null:
		back.text = "Back to the map"
		back.pressed.connect(func(): Scenes.go("res://scenes/world_map.tscn"))
	else:
		back.text = "To battle"
		back.disabled = GameState.total_men() == 0
		back.pressed.connect(_on_battle)
	col.add_child(back)


	col.add_child(_section("Your warband"))
	col.add_child(_note("%d men in %d squads, of the %d your renown lets you lead · wages %d silver a day · %s, %d won" % [
		GameState.total_men(), GameState.army.size(), GameState.squad_cap(), GameState.daily_wages(),
		"1 battle" if GameState.battles == 1 else "%d battles" % GameState.battles, GameState.wins]))
	var roster := VBoxContainer.new()
	roster.add_theme_constant_override("separation", 8)
	col.add_child(roster)
	for s in GameState.army:
		roster.add_child(_squad_row(s))
	if GameState.army.is_empty():
		roster.add_child(Style.label("Your warband is gone. Raise a new one.", Style.BODY, Style.ENEMY_LIGHT))

	col.add_child(_section("Bonds"))
	var bonds: Array = GameState.bonds()
	if bonds.is_empty():
		col.add_child(_note("None yet. Captains grow close by fighting side by side, and bonded pairs fight better near each other."))
	for b in bonds:
		col.add_child(_note("%s and %s · bond %s" % [b["a"]["name"], b["b"]["name"], b["rank"]], Style.TEXT))

	if not GameState.fallen.is_empty():
		col.add_child(_section("The fallen"))
		for i in range(GameState.fallen.size() - 1, -1, -1):
			col.add_child(_memorial_row(GameState.fallen[i]))


	# Fresh men are found in towns.
	if GameState.in_town():
		var total := 0
		var cheapest := 0
		for s in GameState.army:
			var cost := GameState.reinforce_cost(s)
			total += cost
			if cost > 0 and (cheapest == 0 or cost < cheapest):
				cheapest = cost
		var rest := Button.new()
		rest.text = "Reinforce all · %d silver" % total if total > 0 else "Every squad is at full strength"
		rest.custom_minimum_size = Vector2(0, Style.TOUCH)
		rest.disabled = total == 0 or cheapest > GameState.silver
		rest.pressed.connect(_on_reinforce)
		col.add_child(rest)
	else:
		col.add_child(_note("Ride to a town to reinforce and train."))



func _section(text: String) -> Label:
	var l := Style.label(text.to_upper(), Style.SMALL, Style.MUTED)
	l.add_theme_constant_override("line_spacing", 2)
	return l


func _squad_row(s: Dictionary) -> Control:
	var type: String = s["type"]
	var unit_id := String(s.get("unit", ""))
	var full := Units.full_size(unit_id) if Units.has(unit_id) else Troops.full_size(type)
	var men: int = s["men"]
	var level := int(s.get("level", 1))
	var panel := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	row.add_child(_portrait(_kit(s), String(s.get("culture", GameState.culture))))
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 2)
	row.add_child(text)
	var title := String(s.get("name", ""))
	text.add_child(Style.label(title if title != "" else Units.troop_name(s, GameState.culture), Style.BODY))
	var c = s.get("captain")
	var who: Label
	if c == null:
		who = Style.label("No captain", Style.SMALL, Style.ENEMY_LIGHT)
	elif int(c.get("wounded", 0)) > 0:
		who = Style.label("%s · wounded, back in %d" % [c["name"], c["wounded"]], Style.SMALL, Style.ENEMY_LIGHT)
	else:
		who = Style.label("%s · %s" % [c["name"], Captains.traits(c)], Style.SMALL, Style.MUTED)
	if Units.tier(String(s.get("unit", ""))) >= 2:
		who.text = "%s · %s" % [Units.troop_name(s, GameState.culture), who.text]
	who.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	who.custom_minimum_size = Vector2(10, 0)
	text.add_child(who)
	if GameState.can_train(s):
		row.add_child(Style.label("Lv%d+" % level, Style.SMALL, Style.BRASS))
	elif level > 1:
		row.add_child(Style.label("Lv%d" % level, Style.SMALL, Style.BRASS))
	row.add_child(Style.label("%d/%d" % [men, full], Style.BODY, Style.TEXT if men >= full else Style.ENEMY_LIGHT))
	return panel


func _note(text: String, color: Color = Style.MUTED) -> Label:
	var l := Style.label(text, Style.SMALL, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _memorial_row(f: Dictionary) -> Control:
	var panel := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	var portrait := _portrait(_kit(f), String(f.get("culture", GameState.culture)))
	portrait.modulate = Color(0.55, 0.55, 0.6)
	row.add_child(portrait)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	text.add_child(Style.label(String(f.get("name", "")), Style.BODY))
	var deeds := "%s · fell in battle %d · fought %d, felled %d" % [f.get("company", ""), int(f.get("battle", 0)),
		int(f.get("battles", 0)), int(f.get("kills", 0))]
	var bonds: Array = f.get("bonds", [])
	if not bonds.is_empty():
		deeds += " · mourned by " + ", ".join(PackedStringArray(bonds))
	var d := Style.label(deeds, Style.SMALL, Style.MUTED)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(d)
	if String(f.get("words", "")) != "":
		var w := Style.label("\"%s\"" % f["words"], Style.SMALL, Style.BRASS)
		w.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_child(w)
	return panel


## What a squad (or a fallen captain's) is drawn as: its trained branch, or its type.
func _kit(s: Dictionary) -> String:
	var unit := String(s.get("unit", ""))
	return unit if unit != "" else String(s.get("type", "infantry"))


## A unit portrait, scaled up with hard pixel edges, dressed as `culture` dresses it.
func _portrait(type: String, culture: String) -> TextureRect:
	var portrait := TextureRect.new()
	portrait.texture = Art.icon(type, 0, culture)
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2(64, 64)
	return portrait


func _on_battle() -> void:
	if GameState.total_men() == 0:
		return
	Scenes.go("res://scenes/battle.tscn")


func _on_reinforce() -> void:
	GameState.reinforce()
	_build()
