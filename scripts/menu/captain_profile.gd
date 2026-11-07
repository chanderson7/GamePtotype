## A captain's lasting identity: portrait, record, traits, company and relationships.
## Opened by tapping any living or memorial captain in the Warband page.
##
## When a captain has earned a veteran role, the choice comes first, under the portrait.
## Tapping a role only selects it; Promote in the bar along the bottom makes it, since the
## choice is permanent.
extends Control

const Page = preload("res://scripts/ui/menu_page.gd")
const Style = preload("res://scripts/ui/style.gd")
const Widgets = preload("res://scripts/ui/widgets.gd")
const Captains = preload("res://scripts/data/captains.gd")
const Troops = preload("res://scripts/data/troops.gd")
const Units = preload("res://scripts/data/units.gd")
const CaptainArt = preload("res://scripts/ui/captain_art.gd")
const BondRow = preload("res://scripts/ui/bond_row.gd")
const Heroes = preload("res://scripts/data/heroes.gd")

## The role selected in the promotion card, waiting for Promote ("" for none).
var _picked := ""
## Said once under the portrait after a promotion.
var _flash := ""
var _scroll: ScrollContainer
var _promote: Button
## spec -> its option panel, so a pick restyles the rows in place.
var _options := {}


func _ready() -> void:
	_build()


func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_options.clear()
	_promote = null
	theme = Style.make_theme()
	var insets := Style.safe_insets(get_viewport())
	var frame := VBoxContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_constant_override("separation", 0)
	add_child(frame)
	var page := Control.new()
	page.name = "Page"
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(page)
	var col := Page.frame(page, 1.0)
	_scroll = col.get_parent().get_parent() as ScrollContainer

	var found := _find_captain(Scenes.active_captain_id)
	if found.is_empty():
		col.add_child(Page.note("Captain unavailable", 52, Style.BRASS))
		col.add_child(Page.note("This captain is no longer in the company record."))
		frame.add_child(Widgets.bottom_bar([_back_button()], insets))
		return
	var captain: Dictionary = found["captain"]
	var fallen := bool(found.get("fallen", false))
	var promoting := not fallen and Captains.can_specialize(captain)

	_add_hero(col, captain, found, fallen, promoting)
	if _flash != "":
		var said := Page.note(_flash, Style.BODY, Style.BRASS)
		said.name = "PromotionNote"
		col.add_child(said)
		_flash = ""
	if promoting:
		_add_promotion(col, captain)
	_add_record(col, captain, found, fallen)
	_add_character(col, captain, found, fallen)
	if fallen:
		_add_memorial_bonds(col, captain)
	else:
		_add_progress(col, found["squad"])
		_add_bonds(col, captain)
		_add_living_history(col, captain)

	var buttons: Array = [_back_button()]
	if promoting:
		_promote = Page.button("Choose a role", _confirm_promotion, true)
		_promote.name = "PromoteButton"
		buttons.append(_promote)
		_refresh_options()
	frame.add_child(Widgets.bottom_bar(buttons, insets))


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


func _first(captain: Dictionary) -> String:
	return String(captain.get("first", captain.get("name", "This captain")))


# ---------------------------------------------------------------- hero

## Who this is at a glance: the portrait in its arch, the name, the company, and chips
## for status, a hero, the role, and a promotion waiting.
func _add_hero(col: VBoxContainer, captain: Dictionary, found: Dictionary, fallen: bool, promoting: bool) -> void:
	var hero := HBoxContainer.new()
	hero.name = "CaptainHero"
	hero.add_theme_constant_override("separation", 22)
	col.add_child(hero)
	# Just promoted: proud. Otherwise their resting face.
	var pic := CaptainArt.portrait(captain, Vector2(150, 190), "proud" if _flash != "" else "")
	if pic.texture != null:
		hero.add_child(Widgets.framed(pic, Vector2(150, 190), fallen, 0.0))
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.alignment = BoxContainer.ALIGNMENT_CENTER
	identity.add_theme_constant_override("separation", 4)
	hero.add_child(identity)
	identity.add_child(Page.note(String(captain.get("name", "Captain")), 48, Style.BRASS))
	var company := String(found.get("company", ""))
	if company != "":
		identity.add_child(Page.note(("Led %s" if fallen else "Captain of %s") % company, Style.BODY, Style.TEXT))
	identity.add_child(Page.note(String(found.get("unit_name", "Captain")), Style.SMALL, Style.MUTED))

	var chips: Array = []
	var status: PanelContainer
	if fallen:
		status = Widgets.chip("Fallen · remembered", Style.MUTED, "◆")
	elif int(captain.get("wounded", 0)) > 0:
		var out := int(captain.get("wounded", 0))
		status = Widgets.chip("Back in %d battle%s" % [out, "" if out == 1 else "s"], Style.MORALE_LOW, "", "wounded")
	else:
		status = Widgets.chip("Active", Style.MORALE_HIGH, "▲")
	status.name = "StatusChip"
	chips.append(status)
	if bool(captain.get("is_hero", false)):
		var star := Widgets.chip("Unique Companion", Style.BRASS, "★")
		star.name = "HeroChip"
		chips.append(star)
	var spec := String(captain.get("specialization", ""))
	if spec != "":
		var role := Widgets.chip(spec, Color("f3d891"), "", String(Captains.SPECIALIZATION_ICONS.get(spec, "")), true)
		role.name = "SpecializationChip"
		chips.append(role)
	if promoting:
		var waiting := Widgets.chip("Promotion ready", Style.BRASS, "★", "", true)
		waiting.name = "PromotionReadyChip"
		chips.append(waiting)
	var row := Widgets.chip_row(chips)
	row.custom_minimum_size.y = 4
	identity.add_child(row)


# ---------------------------------------------------------------- promotion

func _add_promotion(col: VBoxContainer, captain: Dictionary) -> void:
	var v := Widgets.card(col, "Veteran promotion", "Permanent", Style.MUTED, true)
	v.get_parent().name = "PromotionCard"
	v.add_child(Page.note("%s has earned a veteran role. Choose one; it can't be changed later." % _first(captain),
		Style.SMALL, Style.TEXT))
	for spec in Captains.SPECIALIZATIONS:
		v.add_child(_spec_option(String(spec), captain))


## One role: its icon, name, title and reach, what it does, and whether someone else
## already holds it. The whole row is one touch target that selects it.
func _spec_option(spec: String, captain: Dictionary) -> PanelContainer:
	var host_wide: bool = Captains.SPECIALIZATION_SCOPE.get(spec, Captains.HOST) == Captains.HOST
	var holder: Dictionary = GameState.specialization_holder(spec, int(captain.get("id", -1))) if host_wide else {}
	var panel := PanelContainer.new()
	panel.name = "Option_%s" % spec
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)

	var tile := PanelContainer.new()
	tile.name = "Icon"
	tile.custom_minimum_size = Vector2(60, 60)
	tile.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(Widgets.icon_rect(String(Captains.SPECIALIZATION_ICONS.get(spec, "")), 34.0))
	row.add_child(tile)

	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 2)
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(words)
	words.add_child(Page.note(spec, Style.BODY, Style.MUTED if not holder.is_empty() else Style.TEXT))
	var sub := HFlowContainer.new()
	sub.add_theme_constant_override("h_separation", 0)
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub.add_child(Style.label(String(Captains.SPECIALIZATION_TITLES.get(spec, "")), Style.SMALL, Style.BRASS))
	sub.add_child(Style.label(" · Whole host" if host_wide else " · This company", Style.SMALL, Style.MUTED))
	words.add_child(sub)
	var effects := Captains.specialization_effects(spec, _first(captain))
	for line in effects:
		words.add_child(_marked_line("▲", Style.MORALE_HIGH, String(line), Style.TEXT))
	if not holder.is_empty():
		var warn := _marked_line("◆", Style.MORALE_MID,
			"%s already holds this. A second adds nothing." % _first(holder), Style.MORALE_MID)
		warn.name = "HeldWarning"
		words.add_child(warn)

	var radio := Control.new()
	radio.name = "Radio"
	radio.custom_minimum_size = Vector2(36, 36)
	radio.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	radio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# An empty ring, or a ring with a brass dot when picked: a shape, not only a color.
	radio.draw.connect(func():
		var on := _picked == spec
		var c := radio.size / 2.0
		radio.draw_arc(c, 15.0, 0.0, TAU, 40, Style.BRASS if on else Style.RULE, 3.0, true)
		if on:
			radio.draw_circle(c, 8.0, Style.BRASS))
	row.add_child(radio)

	var tap := Button.new()
	tap.name = "Specialization_%s" % spec
	tap.flat = true
	tap.focus_mode = Control.FOCUS_ALL
	tap.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tap.accessibility_name = "%s, %s, %s: %s" % [spec, Captains.SPECIALIZATION_TITLES.get(spec, ""),
		"whole host" if host_wide else "this company", ". ".join(PackedStringArray(effects))]
	tap.pressed.connect(_pick.bind(spec))
	panel.add_child(tap)
	_options[spec] = panel
	return panel


## A short line with a shape in front: ▲ for an effect, ◆ for a caution.
func _marked_line(mark: String, mark_color: Color, text: String, color: Color) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := Style.label(mark, Style.SMALL, mark_color)
	m.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(m)
	var l := Page.note(text, Style.SMALL, color)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	return h


func _pick(spec: String) -> void:
	_picked = "" if _picked == spec else spec
	Sound.play("click")
	_refresh_options()


## Restyle the role rows and the Promote button for the current pick.
func _refresh_options() -> void:
	for spec in _options:
		var panel: PanelContainer = _options[spec]
		var on: bool = _picked == spec
		# The picked row's thicker border eats into its padding, so the row doesn't move.
		var sb := Style.box(Color("262c45") if on else Style.RAISED, Style.BRASS if on else Style.RULE, 4 if on else 2, 14)
		sb.content_margin_left = 16 if on else 18
		sb.content_margin_right = 14 if on else 16
		sb.content_margin_top = 14 if on else 16
		sb.content_margin_bottom = 14 if on else 16
		panel.add_theme_stylebox_override("panel", sb)
		var tile := panel.find_child("Icon", true, false) as PanelContainer
		if tile != null:
			var tb := Style.box(Style.NIGHT, Style.BRASS if on else Style.RULE, 2, 14)
			tb.content_margin_left = 12
			tb.content_margin_right = 12
			tb.content_margin_top = 12
			tb.content_margin_bottom = 12
			tile.add_theme_stylebox_override("panel", tb)
		var radio := panel.find_child("Radio", true, false) as Control
		if radio != null:
			radio.queue_redraw()
	if _promote != null:
		_promote.disabled = _picked == ""
		_promote.text = "Choose a role" if _picked == "" else "Promote to %s" % _picked


func _confirm_promotion() -> void:
	if _picked == "":
		return
	var spec := _picked
	if not GameState.specialize_captain(Scenes.active_captain_id, spec):
		return
	Sound.play("charge")
	var captain = GameState.captain_by_id(Scenes.active_captain_id)
	var first := _first(captain) if typeof(captain) == TYPE_DICTIONARY else "The captain"
	_flash = "%s is now %s: %s." % [first, spec, Captains.SPECIALIZATION_TITLES.get(spec, "")]
	_picked = ""
	_build()
	_settle_new_role()


## The new role's chip eases in once the page has laid out.
func _settle_new_role() -> void:
	await get_tree().process_frame
	var chip := find_child("SpecializationChip", true, false) as Control
	if chip != null:
		Style.ease_in(chip, Vector2(0.5, 0.5))


# ---------------------------------------------------------------- record

func _add_record(col: VBoxContainer, captain: Dictionary, found: Dictionary, fallen: bool) -> void:
	var v := Widgets.card(col, "Campaign record")
	v.get_parent().name = "RecordCard"
	var tiles: Array = [
		_tile("battle", str(int(captain.get("battles", 0))), "Battles"),
		_tile("skull", str(int(captain.get("kills", 0))), "Kills"),
	]
	if not fallen:
		var squad: Dictionary = found["squad"]
		var unit_id := String(squad.get("unit", ""))
		var full := Units.full_size(unit_id) if Units.has(unit_id) else Troops.full_size(String(squad.get("type", Troops.INFANTRY)))
		tiles.append(_tile("men", "%d/%d" % [int(squad.get("men", 0)), full], "Men"))
	v.add_child(Widgets.tile_grid(tiles, tiles.size()))
	# The tiles carry the numbers; the story only adds what they can't.
	var story := _record_story(captain, found, fallen) if fallen else _record_extra(captain)
	if story != "":
		v.add_child(Page.note(story, Style.SMALL, Style.MUTED))
	if fallen and bool(captain.get("avenged", false)):
		var av := Widgets.chip("Avenged", Style.BRASS, "★", "", true)
		av.name = "AvengedChip"
		av.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		v.add_child(av)


func _tile(icon: String, value: String, sub: String) -> PanelContainer:
	var t := Widgets.tile(icon, value, sub, Style.BRASS)
	t.add_theme_stylebox_override("panel", Style.box(Style.RAISED, Style.RULE, 2, 14))
	# At large text sizes three tiles across have no room for icons; the words stay.
	if Style.text_size(Style.LARGE) > 36:
		var row := t.get_child(0)
		var icon_node: CanvasItem = row.get_child(0) as CanvasItem if row.get_child_count() > 0 else null
		if icon_node != null:
			icon_node.visible = false
	return t


func _record_extra(captain: Dictionary) -> String:
	var wounds := int(captain.get("history", {}).get("wounds", 0))
	if wounds > 0:
		return "Survived %d serious %s." % [wounds, "wound" if wounds == 1 else "wounds"]
	return ""


## What the tiles can't say about a fallen captain: when they fell, and by whose host.
func _record_story(captain: Dictionary, _found: Dictionary, fallen: bool) -> String:
	var story := ""
	if fallen:
		story = "Fell in battle %d." % int(captain.get("battle", 0))
		if String(captain.get("killed_by_lord_name", "")) != "":
			story += " Slain by the host of %s." % captain["killed_by_lord_name"]
	var wounds := int(captain.get("history", {}).get("wounds", 0))
	if wounds > 0:
		story += (" " if story != "" else "") + "Survived %d serious %s." % [wounds, "wound" if wounds == 1 else "wounds"]
	return story


# ---------------------------------------------------------------- character

## The one place traits are explained: temperament, quirk and role, each with what it does.
func _add_character(col: VBoxContainer, captain: Dictionary, found: Dictionary, fallen: bool) -> void:
	var v := Widgets.card(col, "Character")
	v.get_parent().name = "CharacterCard"
	# A hero keeps the story they came with.
	var hero: Dictionary = Heroes.HEROES.get(String(captain.get("hero_id", "")), {}) if bool(captain.get("is_hero", false)) else {}
	if not hero.is_empty():
		var bio := _detail("Before the company", String(hero.get("bio", "")), "")
		bio.name = "HeroBio"
		v.add_child(bio)
		var said := Page.note("\"%s\"" % String(hero.get("dialogue", "")), Style.SMALL, Style.MUTED)
		said.name = "HeroWords"
		v.add_child(said)
	if fallen:
		v.add_child(Page.note(_fallen_story(found), Style.BODY, Style.TEXT))
		return
	var temperament := String(captain.get("temperament", ""))
	var quirk := String(captain.get("quirk", ""))
	if temperament != "":
		v.add_child(_detail(temperament, String(Captains.TRAIT_TEXT.get(temperament, "shapes how they lead under pressure")), temperament.to_lower()))
	if quirk != "":
		v.add_child(_detail(quirk, String(Captains.TRAIT_TEXT.get(quirk, "marks their way of command")), quirk.to_lower()))
	var spec := String(captain.get("specialization", ""))
	if spec != "":
		var role := VBoxContainer.new()
		role.name = "RoleDetail"
		role.add_theme_constant_override("separation", 2)
		role.add_child(Page.note("%s · %s" % [spec, Captains.SPECIALIZATION_TITLES.get(spec, "")], Style.BODY, Style.BRASS))
		var host_wide: bool = Captains.SPECIALIZATION_SCOPE.get(spec, Captains.HOST) == Captains.HOST
		role.add_child(Page.note("For the whole host" if host_wide else "For this company", Style.SMALL, Style.MUTED))
		for line in Captains.specialization_effects(spec, _first(captain)):
			role.add_child(_marked_line("▲", Style.MORALE_HIGH, String(line), Style.TEXT))
		v.add_child(role)


func _detail(title: String, body: String, icon_key: String = "") -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	if icon_key != "":
		var head := HBoxContainer.new()
		head.name = "Trait_%s" % icon_key
		head.add_theme_constant_override("separation", 10)
		var ic := Widgets.icon_rect(icon_key, 30.0)
		ic.modulate = Style.BRASS
		head.add_child(ic)
		head.add_child(Page.note(title, Style.BODY, Style.BRASS))
		row.add_child(head)
	else:
		row.add_child(Page.note(title, Style.BODY, Style.BRASS))
	var sentence := body.left(1).to_upper() + body.substr(1)
	if not sentence.ends_with("."):
		sentence += "."
	row.add_child(Page.note(sentence, Style.SMALL, Style.TEXT))
	return row


func _fallen_story(found: Dictionary) -> String:
	var captain: Dictionary = found["captain"]
	var words := String(captain.get("words", ""))
	return "\"%s\"" % words if words != "" else "Their name remains on the company roll."


# ---------------------------------------------------------------- company and bonds

func _add_progress(col: VBoxContainer, squad: Dictionary) -> void:
	var xp := int(squad.get("xp", 0))
	var level := int(squad.get("level", Troops.level_for(xp)))
	var at_cap := level >= Troops.MAX_LEVEL
	var v := Widgets.card(col, "Company progress", "Level %d of %d" % [level, Troops.MAX_LEVEL], Style.BRASS)
	v.get_parent().name = "ProgressCard"
	# Experience within this level, toward the next: the meter and the number agree.
	var into_level := clampi(xp - (level - 1) * Troops.XP_PER_LEVEL, 0, Troops.XP_PER_LEVEL)
	var meter_row := HBoxContainer.new()
	meter_row.add_theme_constant_override("separation", 10)
	v.add_child(meter_row)
	meter_row.add_child(Widgets.icon_rect("level", 28.0))
	meter_row.add_child(Widgets.meter(1.0 if at_cap else float(into_level) / Troops.XP_PER_LEVEL, Style.BRASS))
	meter_row.add_child(Style.label("Fully trained" if at_cap else "%d/%d" % [into_level, Troops.XP_PER_LEVEL], Style.SMALL, Style.MUTED))
	if GameState.can_train(squad):
		var train := Widgets.chip("Ready to train in town", Style.BRASS, "▲", "", true)
		train.name = "TrainReadyChip"
		train.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		v.add_child(train)


func _add_bonds(col: VBoxContainer, captain: Dictionary) -> void:
	var v := Widgets.card(col, "Bonds")
	v.get_parent().name = "BondsCard"
	var shown := 0
	for other_id in captain.get("bonds", {}):
		var other = GameState.captain_by_id(int(other_id))
		if other == null:
			continue
		var points := float(captain["bonds"][other_id])
		if Captains.rank_letter(points) == "":
			continue
		var record := GameState.bond_record(int(captain.get("id", -1)), int(other_id))
		# Tapping a bond opens that captain.
		var row := BondRow.make([other], String(other["name"]), points, int(record.get("shared_battles", 0)),
			Callable(), false, _open_captain.bind(int(other_id)), "BondProfile_%d" % int(other_id))
		row.name = "Bond_%d" % int(other_id)
		v.add_child(row)
		shown += 1
	if shown == 0:
		v.add_child(Page.note("No lasting bond yet. Captains grow close by fighting near one another.", Style.SMALL, Style.MUTED))


func _open_captain(captain_id: int) -> void:
	Scenes.active_captain_id = captain_id
	_picked = ""
	_build()


func _add_living_history(col: VBoxContainer, captain: Dictionary) -> void:
	var history: Dictionary = captain.get("history", {})
	var friends: Array = history.get("fallen_friends", [])
	var scars: Array = history.get("scars", [])
	if friends.is_empty() and scars.is_empty():
		return
	var v := Widgets.card(col, "History")
	v.get_parent().name = "HistoryCard"
	if not friends.is_empty():
		v.add_child(_detail("Fallen friends", "Carries the memory of %s" % ", ".join(PackedStringArray(friends))))
	if not scars.is_empty():
		v.add_child(_detail("Battle scars", "Bears lasting scars: %s" % ", ".join(PackedStringArray(scars))))


func _add_memorial_bonds(col: VBoxContainer, captain: Dictionary) -> void:
	var bonds: Array = captain.get("bonds", [])
	if bonds.is_empty():
		return
	var v := Widgets.card(col, "Remembered by")
	v.get_parent().name = "RememberedByCard"
	# Those still with the company: their talk by the empty place, told again.
	var shown := 0
	for rb in GameState.remembered_bonds():
		var gone: Dictionary = rb["b"]
		if int(gone.get("id", -2)) != int(captain.get("id", -1)):
			continue
		var survivor: Dictionary = rb["a"]
		v.add_child(BondRow.make([survivor, gone], "%s remembers %s" % [String(survivor.get("first", "")), _first(captain)], float(rb["points"]),
			0, _open_memorial.bind(int(survivor["id"]), int(captain["id"])), false, Callable(), "Remembered_%d" % int(survivor["id"])))
		shown += 1
	if shown == 0:
		v.add_child(Page.note(", ".join(PackedStringArray(bonds)), Style.BODY, Style.BRASS))


## The survivor's talk by the fallen captain's empty place.
func _open_memorial(survivor_id: int, fallen_id: int) -> void:
	Scenes.active_bond_a_id = survivor_id
	Scenes.active_bond_b_id = fallen_id
	Scenes.bond_conversation_return = "res://scenes/captain_profile.tscn"
	Scenes.go("res://scenes/bond_conversation.tscn")


# ---------------------------------------------------------------- bottom bar

func _back_button() -> Button:
	var b := Widgets.back_button(_back, "Back", "BackButton")
	b.accessibility_name = "Back to Warband"
	return b


func _back() -> void:
	Scenes.go(Scenes.captain_profile_return)
