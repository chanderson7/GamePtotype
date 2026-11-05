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
	var bg := ColorRect.new()
	bg.color = Style.NIGHT
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var insets := Style.safe_insets(get_viewport())
	var frame := VBoxContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_constant_override("separation", 0)
	add_child(frame)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(_scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_top", 48 + int(insets["top"]))
	margin.add_theme_constant_override("margin_bottom", 28)
	_scroll.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 22)
	margin.add_child(col)

	var found := _find_captain(Scenes.active_captain_id)
	if found.is_empty():
		col.add_child(Page.note("Captain unavailable", 52, Style.BRASS))
		col.add_child(Page.note("This captain is no longer in the company record."))
		frame.add_child(_bar([_back_button()], insets))
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
	frame.add_child(_bar(buttons, insets))


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
	var pic := CaptainArt.portrait(captain, Vector2(150, 190))
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
	var unit := String(found.get("unit_name", "Captain"))
	if not fallen:
		var squad: Dictionary = found["squad"]
		unit += " · Level %d" % int(squad.get("level", Troops.level_for(int(squad.get("xp", 0)))))
	identity.add_child(Page.note(unit, Style.SMALL, Style.MUTED))

	var chips: Array = []
	var status: PanelContainer
	if fallen:
		status = Widgets.chip("Fallen · remembered", Style.MUTED, "◆")
	elif int(captain.get("wounded", 0)) > 0:
		status = Widgets.chip("Wounded · back in %d" % int(captain.get("wounded", 0)), Style.MORALE_LOW, "▼")
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
		var role := _gold_chip(spec, Widgets.icon(String(Captains.SPECIALIZATION_ICONS.get(spec, ""))))
		role.name = "SpecializationChip"
		chips.append(role)
	if promoting:
		var waiting := _gold_chip("★ Promotion ready")
		waiting.name = "PromotionReadyChip"
		chips.append(waiting)
	var row := Widgets.chip_row(chips)
	row.custom_minimum_size.y = 4
	identity.add_child(row)


## A brass chip, for the things worth noticing: a role, a promotion waiting.
func _gold_chip(text: String, icon: Texture2D = null) -> PanelContainer:
	var panel := PanelContainer.new()
	var sb := Style.box(Color("33290f"), Style.BRASS, 2, 40)
	sb.content_margin_left = 14
	sb.content_margin_right = 16
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	panel.add_child(h)
	if icon != null:
		var ic := TextureRect.new()
		ic.texture = icon
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.custom_minimum_size = Vector2(24, 24)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ic.modulate = Color("f3d891")
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(ic)
	h.add_child(Style.label(text, Style.SMALL, Color("f3d891")))
	return panel


# ---------------------------------------------------------------- promotion

func _add_promotion(col: VBoxContainer, captain: Dictionary) -> void:
	var v := Widgets.card(col, "Veteran promotion", "Permanent")
	var panel := v.get_parent() as PanelContainer
	panel.name = "PromotionCard"
	var sb := Style.box(Color("1c1c22"), Style.BRASS, 2, 20)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 18
	sb.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", sb)
	var title := v.get_child(0).get_child(0) as Label
	title.add_theme_color_override("font_color", Style.BRASS)
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
	# The tiles carry the numbers; a living captain's story only adds what they can't.
	var story := _record_story(captain, found, fallen) if fallen else _record_extra(captain)
	if story != "":
		v.add_child(Page.note(story, Style.SMALL if not fallen else Style.BODY, Style.MUTED if not fallen else Style.TEXT))


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


func _record_story(captain: Dictionary, found: Dictionary, fallen: bool) -> String:
	var battles := int(captain.get("battles", 0))
	var kills := int(captain.get("kills", 0))
	var story := "%s led %s through %d %s and was credited with %d %s." % [
		_first(captain), found.get("company", "the company"),
		battles, "battle" if battles == 1 else "battles", kills, "kill" if kills == 1 else "kills"]
	if fallen:
		story += " Their service ended in battle %d." % int(captain.get("battle", 0))
		if String(captain.get("killed_by_lord_name", "")) != "":
			story += " Slain by the host of %s." % captain["killed_by_lord_name"]
		if bool(captain.get("avenged", false)):
			story += " Avenged."
	elif int(captain.get("wounded", 0)) > 0:
		story += " They are recovering before returning to command."
	var wounds := int(captain.get("history", {}).get("wounds", 0))
	if wounds > 0:
		story += " They have survived %d serious %s." % [wounds, "wound" if wounds == 1 else "wounds"]
	return story


# ---------------------------------------------------------------- character

## The one place traits are explained: temperament, quirk and role, each with what it does.
func _add_character(col: VBoxContainer, captain: Dictionary, found: Dictionary, fallen: bool) -> void:
	var v := Widgets.card(col, "Character")
	v.get_parent().name = "CharacterCard"
	if fallen:
		v.add_child(Page.note(_fallen_story(found), Style.BODY, Style.TEXT))
		return
	var temperament := String(captain.get("temperament", ""))
	var quirk := String(captain.get("quirk", ""))
	if temperament != "":
		v.add_child(_detail(temperament, String(Captains.TRAIT_TEXT.get(temperament, "shapes how they lead under pressure"))))
	if quirk != "":
		v.add_child(_detail(quirk, String(Captains.TRAIT_TEXT.get(quirk, "marks their way of command"))))
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


func _detail(title: String, body: String) -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
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
	var into_level := clampi(xp - (level - 1) * Troops.XP_PER_LEVEL, 0, Troops.XP_PER_LEVEL)
	v.add_child(Widgets.meter(1.0 if at_cap else float(into_level) / Troops.XP_PER_LEVEL, Style.BRASS))
	var line := "Veteran company, fully trained." if at_cap else \
		"%d/%d experience toward training" % [xp, level * Troops.XP_PER_LEVEL]
	v.add_child(Page.note(line, Style.SMALL, Style.MUTED))
	if GameState.can_train(squad):
		var train := _gold_chip("★ Ready to train in town")
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
		var rank := Captains.rank_letter(points)
		if rank == "":
			continue
		var rank_index := Captains.rank_for(points)
		var next_text := "Highest rank"
		var frac := 1.0
		if rank_index + 1 < Captains.RANK_POINTS.size():
			var lo: float = Captains.RANK_POINTS[rank_index]
			var hi: float = Captains.RANK_POINTS[rank_index + 1]
			next_text = "%.0f/%.0f points to %s" % [points, hi, Captains.RANKS[rank_index + 1]]
			frac = clampf((points - lo) / maxf(0.01, hi - lo), 0.0, 1.0)
		var panel := PanelContainer.new()
		panel.name = "Bond_%d" % int(other_id)
		panel.add_theme_stylebox_override("panel", Style.box(Style.RAISED, Style.RULE, 2, 14))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(row)
		row.add_child(CaptainArt.portrait(other, Vector2(54, 72)))
		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.add_theme_constant_override("separation", 6)
		words.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(words)
		words.add_child(Page.note("%s · Bond %s" % [other["name"], rank], Style.BODY, Style.TEXT))
		words.add_child(Widgets.meter(frac, Style.PLAYER_LIGHT, 12.0))
		words.add_child(Page.note(next_text + " · " + GameState.bond_effect_text(points), Style.SMALL, Style.BRASS))
		# Tapping a bond opens that captain.
		var tap := Button.new()
		tap.name = "BondProfile_%d" % int(other_id)
		tap.flat = true
		tap.focus_mode = Control.FOCUS_ALL
		tap.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tap.accessibility_name = "View %s's profile" % other["name"]
		tap.pressed.connect(_open_captain.bind(int(other_id)))
		panel.add_child(tap)
		v.add_child(panel)
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
	v.add_child(Page.note(", ".join(PackedStringArray(bonds)), Style.BODY, Style.BRASS))


# ---------------------------------------------------------------- bottom bar

## Back, and Promote while a promotion waits, pinned in thumb reach.
func _bar(buttons: Array, insets: Dictionary) -> PanelContainer:
	var bar := PanelContainer.new()
	bar.name = "BottomBar"
	var box := Style.box(Style.NIGHT, Style.RULE, 0, 0)
	box.border_width_top = 2
	box.content_margin_left = 28
	box.content_margin_right = 28
	box.content_margin_top = 14
	box.content_margin_bottom = 14 + float(insets.get("bottom", 0))
	bar.add_theme_stylebox_override("panel", box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	bar.add_child(row)
	for i in buttons.size():
		var b: Button = buttons[i]
		b.custom_minimum_size.y = 92
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# The primary action, last, gets the wider share.
		b.size_flags_stretch_ratio = 1.6 if i > 0 else 1.0
		row.add_child(b)
	return bar


func _back_button() -> Button:
	var b := Page.button("Back", _back)
	b.name = "BackButton"
	b.autowrap_mode = TextServer.AUTOWRAP_OFF
	b.clip_text = true
	b.icon = Widgets.icon("back")
	for c in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "icon_focus_color"]:
		b.add_theme_color_override(c, Style.TEXT)
	b.accessibility_name = "Back to Warband"
	return b


func _back() -> void:
	Scenes.go(Scenes.captain_profile_return)
