## A captain's lasting identity: portrait, record, traits, company and relationships.
## Opened by tapping any living or memorial captain in the Warband page.
extends Control

const Page = preload("res://scripts/ui/menu_page.gd")
const Style = preload("res://scripts/ui/style.gd")
const Captains = preload("res://scripts/data/captains.gd")
const Troops = preload("res://scripts/data/troops.gd")
const Units = preload("res://scripts/data/units.gd")
const CaptainArt = preload("res://scripts/ui/captain_art.gd")


func _ready() -> void:
	_build()


func _build() -> void:
	var found := _find_captain(Scenes.active_captain_id)
	if found.is_empty():
		var missing := Page.column(self, "Captain unavailable", "This captain is no longer in the company record.")
		missing.add_child(Page.button("Back to Warband", _back, true))
		return
	var captain: Dictionary = found["captain"]
	var fallen := bool(found.get("fallen", false))
	var status := "FALLEN · REMEMBERED" if fallen else ("WOUNDED · BACK IN %d" % int(captain.get("wounded", 0)) if int(captain.get("wounded", 0)) > 0 else "ACTIVE CAPTAIN")
	var col := Page.column(self, String(captain.get("name", "Captain")), status)

	var hero := HBoxContainer.new()
	hero.add_theme_constant_override("separation", 18)
	col.add_child(hero)
	var portrait := CaptainArt.portrait(captain, Vector2(150, 200))
	if fallen:
		portrait.modulate = Color(0.62, 0.62, 0.68)
	hero.add_child(portrait)
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.alignment = BoxContainer.ALIGNMENT_CENTER
	identity.add_theme_constant_override("separation", 8)
	hero.add_child(identity)
	identity.add_child(Page.note(String(found.get("company", "The company")), Style.LARGE, Style.TEXT))
	identity.add_child(Page.note(String(found.get("unit_name", "Captain")), Style.BODY, Style.MUTED))
	if not fallen:
		identity.add_child(Page.note(Captains.traits(captain), Style.BODY, Style.BRASS))

	col.add_child(_heading("Character"))
	if fallen:
		col.add_child(Page.note(_fallen_story(found), Style.BODY, Style.TEXT))
	else:
		var temperament := String(captain.get("temperament", ""))
		var quirk := String(captain.get("quirk", ""))
		col.add_child(_detail(temperament, String(Captains.TRAIT_TEXT.get(temperament, "shapes how they lead under pressure"))))
		if quirk != "":
			col.add_child(_detail(quirk, String(Captains.TRAIT_TEXT.get(quirk, "marks their way of command"))))

	col.add_child(_heading("Campaign record"))
	col.add_child(Page.note(_record_story(captain, found, fallen), Style.BODY, Style.TEXT))
	var record := HBoxContainer.new()
	record.add_theme_constant_override("separation", 10)
	record.add_child(_stat("BATTLES", int(captain.get("battles", 0))))
	record.add_child(_stat("KILLS", int(captain.get("kills", 0))))
	if not fallen:
		var squad: Dictionary = found["squad"]
		record.add_child(_stat("SQUAD", int(squad.get("men", 0))))
	col.add_child(record)

	if not fallen:
		_add_progress(col, found["squad"])
		_add_bonds(col, captain)
		_add_living_history(col, captain)
	else:
		_add_memorial_bonds(col, captain)

	col.add_child(Page.button("Back to Warband", _back, true))


func _find_captain(id: int) -> Dictionary:
	for squad in GameState.army:
		var captain = squad.get("captain")
		if typeof(captain) == TYPE_DICTIONARY and int(captain.get("id", -1)) == id:
			return {"captain": captain, "squad": squad, "company": squad.get("name", ""),
				"unit_name": Units.troop_name(squad, GameState.culture), "fallen": false}
	for memorial in GameState.fallen:
		if typeof(memorial) == TYPE_DICTIONARY and int(memorial.get("id", 0)) == id:
			var type := String(memorial.get("type", Troops.INFANTRY))
			return {"captain": memorial, "company": memorial.get("company", ""),
				"unit_name": String(Troops.TYPES.get(type, Troops.TYPES[Troops.INFANTRY])["name"]), "fallen": true}
	return {}


func _heading(text: String) -> Label:
	return Page.note(text.to_upper(), Style.SMALL, Style.MUTED)


func _detail(title: String, body: String) -> Control:
	var panel := PanelContainer.new()
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	panel.add_child(row)
	row.add_child(Page.note(title, Style.BODY, Style.BRASS))
	var sentence := body.left(1).to_upper() + body.substr(1)
	row.add_child(Page.note(sentence + ".", Style.SMALL, Style.TEXT))
	return panel


func _stat(label_text: String, value: int) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(col)
	var value_label := Page.note(str(value), Style.LARGE, Style.BRASS)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(value_label)
	var caption := Page.note(label_text, Style.SMALL, Style.MUTED)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(caption)
	return panel


func _add_progress(col: VBoxContainer, squad: Dictionary) -> void:
	col.add_child(_heading("Company progress"))
	var xp := int(squad.get("xp", 0))
	var level := int(squad.get("level", Troops.level_for(xp)))
	var at_cap := level >= Troops.MAX_LEVEL
	var next_xp := level * Troops.XP_PER_LEVEL
	var line := "Level %d · veteran company" % level if at_cap else "Level %d · %d/%d experience toward training" % [level, xp, next_xp]
	if GameState.can_train(squad):
		line += " · ready to train in town"
	col.add_child(Page.note(line, Style.BODY, Style.BRASS if GameState.can_train(squad) else Style.TEXT))


func _add_bonds(col: VBoxContainer, captain: Dictionary) -> void:
	col.add_child(_heading("Bonds"))
	var shown := 0
	for other_id in captain.get("bonds", {}):
		var other = GameState.captain_by_id(int(other_id))
		if other == null:
			continue
		var points := float(captain["bonds"][other_id])
		var rank := Captains.rank_letter(points)
		if rank == "":
			continue
		var next_text := "highest rank"
		var rank_index := Captains.rank_for(points)
		if rank_index + 1 < Captains.RANK_POINTS.size():
			next_text = "%.0f/%.0f points to %s" % [points, Captains.RANK_POINTS[rank_index + 1], Captains.RANKS[rank_index + 1]]
		var panel := PanelContainer.new()
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		panel.add_child(row)
		row.add_child(CaptainArt.portrait(other, Vector2(54, 72)))
		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(words)
		words.add_child(Page.note("%s · Bond %s" % [other["name"], rank], Style.BODY, Style.TEXT))
		words.add_child(Page.note(next_text + " · " + GameState.bond_effect_text(points), Style.SMALL, Style.BRASS))
		col.add_child(panel)
		shown += 1
	if shown == 0:
		col.add_child(Page.note("No lasting bond yet. Captains grow close by fighting near one another.", Style.BODY, Style.MUTED))


func _add_living_history(col: VBoxContainer, captain: Dictionary) -> void:
	var history: Dictionary = captain.get("history", {})
	var friends: Array = history.get("fallen_friends", [])
	if friends.is_empty():
		return
	col.add_child(_heading("Fallen friends"))
	col.add_child(Page.note("Carries the memory of %s." % ", ".join(PackedStringArray(friends)), Style.BODY, Style.TEXT))


func _add_memorial_bonds(col: VBoxContainer, captain: Dictionary) -> void:
	var bonds: Array = captain.get("bonds", [])
	if bonds.is_empty():
		return
	col.add_child(_heading("Remembered by"))
	col.add_child(Page.note(", ".join(PackedStringArray(bonds)), Style.BODY, Style.BRASS))


func _record_story(captain: Dictionary, found: Dictionary, fallen: bool) -> String:
	var battles := int(captain.get("battles", 0))
	var kills := int(captain.get("kills", 0))
	var story := "%s led %s through %d %s and was credited with %d %s." % [
		String(captain.get("first", captain.get("name", "This captain"))), found.get("company", "the company"),
		battles, "battle" if battles == 1 else "battles", kills, "kill" if kills == 1 else "kills"]
	if fallen:
		story += " Their service ended in battle %d." % int(captain.get("battle", 0))
	elif int(captain.get("wounded", 0)) > 0:
		story += " They are recovering before returning to command."
	var wounds := int(captain.get("history", {}).get("wounds", 0))
	if wounds > 0:
		story += " They have survived %d serious %s." % [wounds, "wound" if wounds == 1 else "wounds"]
	return story


func _fallen_story(found: Dictionary) -> String:
	var captain: Dictionary = found["captain"]
	var words := String(captain.get("words", ""))
	return "\"%s\"" % words if words != "" else "Their name remains on the company roll."


func _back() -> void:
	Scenes.go(Scenes.captain_profile_return)
