## The warband: the squads, captains, bonds and the fallen that carry between battles.
## Opened from the map. Run on its own (no campaign yet), it can still start a battle.
extends Control

const Troops = preload("res://scripts/data/troops.gd")
const Style = preload("res://scripts/ui/style.gd")
const Art = preload("res://scripts/art/unit_art.gd")
const Captains = preload("res://scripts/data/captains.gd")
const Cultures = preload("res://scripts/data/cultures.gd")
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

	var last: Dictionary = GameState.last_result
	if not last.is_empty():
		var won: bool = last["won"]
		var line := "Last battle: %s. Lost %d men, cut down %d." % ["Victory" if won else "Defeat", last["lost"], last["killed"]]
		var last_label := Style.label(line, Style.BODY, Style.BRASS if won else Style.ENEMY_LIGHT)
		last_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(last_label)

	col.add_child(_section("Your warband"))
	col.add_child(Style.label("%d men in %d squads · %d battles, %d won" % [
		GameState.total_men(), GameState.army.size(), GameState.battles, GameState.wins], Style.SMALL, Style.MUTED))
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

	var back := Button.new()
	back.custom_minimum_size = Vector2(0, 92)
	back.add_theme_font_size_override("font_size", Style.LARGE)
	Style.make_primary(back)
	if w != null:
		back.text = "Back to the map"
		back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/world_map.tscn"))
	else:
		back.text = "To battle"
		back.disabled = GameState.total_men() == 0
		back.pressed.connect(_on_battle)
	col.add_child(back)

	# Fresh men are found in towns.
	if w == null or w.player_in_town():
		var rest := Button.new()
		rest.text = "Rest and reinforce"
		rest.custom_minimum_size = Vector2(0, Style.TOUCH)
		rest.disabled = not GameState.is_wounded()
		rest.pressed.connect(_on_reinforce)
		col.add_child(rest)
	else:
		col.add_child(_note("Ride to a town to rest and reinforce."))

	col.add_child(_section("How to play"))
	var how := Style.label(
		"On the map, tap a settlement to ride there. Time passes only while you ride or wait. " +
		"Bandits roam each realm: when they block the road, fight them or withdraw.\n\n" +
		"Before the fight, place your whole army in the blue zone: tap a card, then the field, " +
		"or tap Auto-place. Your scouts tell you what kind of commander you face. Press Fight when you're ready.\n\n" +
		"Your squads hold, braced, until ordered, and a braced line wins the first clash: often the " +
		"best move is to let them come. Advance sends each squad at the enemy it fights best; Hold " +
		"stops them and braces them again. Tap a card or a standard to command one squad, then tap " +
		"an enemy to attack it, open ground to march there, or its ability button.\n\n" +
		"Spearmen stop cavalry. Cavalry ride down archers. Archers shred infantry, until their " +
		"arrows run out. Infantry cut through spear lines. A squad locked in one fight can be hit " +
		"in the flank or rear by another, which hurts and shakes it: pin them with foot, then send in the horse.\n\n" +
		"Infantry raise a Shield wall against arrows. Spearmen form a Schiltron no charge can break. " +
		"Archers loose a Volley that shakes a squad's nerve. Cavalry Wheel away to charge again.\n\n" +
		"Every squad has a captain, marked by a gold ring. If a captain falls, a d100 decides: " +
		"roll over the death chance and they're wounded and sit out two battles; at or under it, " +
		"they're gone. Their own squad, a friendly squad nearby or plain luck improves the odds.", Style.SMALL, Style.MUTED)
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(how)


func _section(text: String) -> Label:
	var l := Style.label(text.to_upper(), Style.SMALL, Style.MUTED)
	l.add_theme_constant_override("line_spacing", 2)
	return l


func _squad_row(s: Dictionary) -> Control:
	var type: String = s["type"]
	var full := Troops.full_size(type)
	var men: int = s["men"]
	var level := Troops.level_for(int(s["xp"]))
	var panel := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	row.add_child(_portrait(type))
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 2)
	row.add_child(text)
	var title := String(s.get("name", ""))
	text.add_child(Style.label(title if title != "" else Cultures.troop_name(GameState.culture, type), Style.BODY))
	var c = s.get("captain")
	var who: Label
	if c == null:
		who = Style.label("No captain", Style.SMALL, Style.ENEMY_LIGHT)
	elif int(c.get("wounded", 0)) > 0:
		who = Style.label("%s · wounded, back in %d" % [c["name"], c["wounded"]], Style.SMALL, Style.ENEMY_LIGHT)
	else:
		who = Style.label("%s · %s" % [c["name"], Captains.traits(c)], Style.SMALL, Style.MUTED)
	who.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	who.custom_minimum_size = Vector2(10, 0)
	text.add_child(who)
	if level > 1:
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
	var portrait := _portrait(String(f.get("type", "infantry")))
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


## A unit portrait, scaled up with hard pixel edges.
func _portrait(type: String) -> TextureRect:
	var portrait := TextureRect.new()
	portrait.texture = Art.icon(type)
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2(64, 64)
	return portrait


func _on_battle() -> void:
	if GameState.total_men() == 0:
		return
	get_tree().change_scene_to_file("res://scenes/battle.tscn")


func _on_reinforce() -> void:
	GameState.reinforce()
	_build()
