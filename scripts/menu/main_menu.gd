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
const CaptainArt = preload("res://scripts/ui/captain_art.gd")
const StoryArt = preload("res://scripts/ui/story_art.gd")
const Heraldry = preload("res://scripts/ui/heraldry.gd")
const Jobs = preload("res://scripts/data/jobs.gd")

var _scroll: ScrollContainer


func _ready() -> void:
	theme = Style.make_theme()
	Sound.set_loop("camp")
	_build()


func _exit_tree() -> void:
	Sound.set_loop("")


func _build() -> void:
	var keep := _scroll.scroll_vertical if _scroll != null else Scenes.warband_scroll
	for child in get_children():
		child.queue_free()

	var bg := ColorRect.new()
	bg.color = Style.NIGHT
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_scroll = ScrollContainer.new()
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_right", 36)
	var insets := Style.safe_insets(get_viewport())
	margin.add_theme_constant_override("margin_top", 64 + int(insets["top"]))
	margin.add_theme_constant_override("margin_bottom", 40 + int(insets["bottom"]))
	_scroll.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	margin.add_child(col)

	col.add_child(Style.label("Warband", 72, Style.BRASS))
	col.add_child(_camp_header())
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
	col.add_child(_upkeep_forecast())

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
	var wounded_total := GameState.total_wounded()
	var men_desc := "%d men" % GameState.total_men()
	if wounded_total > 0:
		men_desc += " (+%d wounded)" % wounded_total
	var note_text := "%s in %d squads, of the %d your renown lets you lead · wages %d silver a day · %s, %d won" % [
		men_desc, GameState.army.size(), GameState.squad_cap(), GameState.daily_wages(),
		"1 battle" if GameState.battles == 1 else "%d battles" % GameState.battles, GameState.wins]
	if GameState.has_contract():
		var emp_name: String = WorldData.FACTIONS[GameState.contract_realm()]["name"]
		note_text += "\nContract: %s · +%d silver/day (%d days left)" % [
			emp_name, GameState.contract_daily_pay(), int(GameState.contract.get("days_left", 0))
		]
	col.add_child(_note(note_text))
	col.add_child(_sort_control())
	var sorted := _sorted_roster(GameState.army)
	var active := sorted.filter(func(s): return s.get("captain") == null or int(s["captain"].get("wounded", 0)) <= 0)
	var wounded := sorted.filter(func(s): return s.get("captain") != null and int(s["captain"].get("wounded", 0)) > 0)
	var roster := VBoxContainer.new()
	roster.add_theme_constant_override("separation", 8)
	col.add_child(_section("Active companies"))
	col.add_child(roster)
	for s in active:
		roster.add_child(_squad_row(s))
	if not wounded.is_empty():
		col.add_child(_section("Wounded captains"))
		var wounded_roster := VBoxContainer.new()
		wounded_roster.add_theme_constant_override("separation", 8)
		col.add_child(wounded_roster)
		for s in wounded:
			wounded_roster.add_child(_squad_row(s))
	if GameState.army.is_empty():
		roster.add_child(Style.label("Your warband is gone. Raise a new one.", Style.BODY, Style.ENEMY_LIGHT))

	col.add_child(_section("Active contracts"))
	if GameState.active_jobs.is_empty():
		col.add_child(_note("No active contracts. Visit settlements to take on bounties, courier dispatches, or relief jobs."))
	else:
		for job in GameState.active_jobs:
			col.add_child(_active_job_row(job))

	col.add_child(_section("Bonds"))
	var bonds: Array = GameState.bonds()
	if bonds.is_empty():
		col.add_child(_note("None yet. Captains grow close by fighting side by side, and bonded pairs fight better near each other."))
	for b in bonds:
		col.add_child(_bond_row(b))

	var captives: Array = GameState.captive_lords()
	if not captives.is_empty():
		col.add_child(_section("Captive lords"))
		for cl in captives:
			col.add_child(_captive_lord_row(cl))

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
	_restore_scroll(keep)



func _camp_header() -> Control:
	var stage := Control.new()
	stage.name = "WarbandCampStage"
	stage.custom_minimum_size.y = 190
	stage.clip_contents = true
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var camp := StoryArt.location("company_camp", 0)
	camp.name = "WarbandCampIllustration"
	camp.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(camp)
	var banner := Control.new()
	banner.name = "CompanyBanner"
	banner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.visible = Style.illustrations_on()
	banner.draw.connect(func():
		var info: Dictionary = Cultures.info(GameState.culture)
		var color: Color = info["color"]
		var at := Vector2(maxf(22.0, banner.size.x - 145.0), 22.0)
		banner.draw_line(at + Vector2(0, -2), at + Vector2(0, 146), Color("6b4a2a"), 5.0)
		Heraldry.flag(banner, at + Vector2(4, 4), Vector2(108, 70), color, color.darkened(0.42), true, Troops.INFANTRY, false, true))
	stage.add_child(banner)
	return stage


func _upkeep_forecast() -> Label:
	var wages := GameState.daily_wages()
	var stipend := GameState.contract_daily_pay()
	var rations := GameState.total_men()
	var due := "each campaign day"
	if GameState.world != null:
		var next_day := (floori(GameState.world.hour / 24.0) + 1) * 24
		var hours := maxi(1, ceili(float(next_day) - GameState.world.hour))
		due = "in %d %s" % [hours, "hour" if hours == 1 else "hours"]
	var after_silver := GameState.silver - wages + stipend
	var after_food := GameState.food - rations
	var pay_text := "%d silver" % wages if stipend <= 0 else "%d silver (net %d with contract)" % [wages, wages - stipend]
	var text := "Next payment %s · %s + %d rations · afterward: %d silver, %d rations" % [
		due, pay_text, rations, maxi(0, after_silver), maxi(0, after_food)]
	if after_silver < 0 or after_food < 0:
		text += " · shortfall: men may leave"
	return _note(text, Style.ENEMY_LIGHT if after_silver < 0 or after_food < 0 else Style.MUTED)


func _sort_control() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := Style.label("Sort companies", Style.SMALL, Style.MUTED)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	var choice := OptionButton.new()
	choice.name = "WarbandSort"
	for text in ["Roster order", "Troop role", "Strength", "Experience", "Captain"]:
		choice.add_item(text)
	choice.selected = clampi(Scenes.warband_sort, 0, choice.item_count - 1)
	choice.custom_minimum_size = Vector2(245, Style.TOUCH)
	choice.item_selected.connect(_on_sort)
	row.add_child(choice)
	return row


func _on_sort(index: int) -> void:
	Scenes.warband_scroll = _scroll.scroll_vertical if _scroll != null else 0
	Scenes.warband_sort = index
	_build()


func _sorted_roster(source: Array) -> Array:
	var roster := source.duplicate()
	match Scenes.warband_sort:
		1:
			roster.sort_custom(func(a, b):
				var ar := Troops.ORDER.find(String(a.get("type", "")))
				var br := Troops.ORDER.find(String(b.get("type", "")))
				return ar < br if ar != br else int(a["id"]) < int(b["id"]))
		2:
			roster.sort_custom(func(a, b):
				var af := maxi(1, Units.full_size(String(a.get("unit", ""))) if Units.has(String(a.get("unit", ""))) else Troops.full_size(String(a["type"])))
				var bf := maxi(1, Units.full_size(String(b.get("unit", ""))) if Units.has(String(b.get("unit", ""))) else Troops.full_size(String(b["type"])))
				var av := float(a["men"]) / af
				var bv := float(b["men"]) / bf
				return av > bv if not is_equal_approx(av, bv) else int(a["id"]) < int(b["id"]))
		3:
			roster.sort_custom(func(a, b): return int(a.get("xp", 0)) > int(b.get("xp", 0)) if int(a.get("xp", 0)) != int(b.get("xp", 0)) else int(a["id"]) < int(b["id"]))
		4:
			roster.sort_custom(func(a, b):
				var an := String(a.get("captain", {}).get("name", "")) if typeof(a.get("captain")) == TYPE_DICTIONARY else ""
				var bn := String(b.get("captain", {}).get("name", "")) if typeof(b.get("captain")) == TYPE_DICTIONARY else ""
				return an.naturalnocasecmp_to(bn) < 0)
	return roster


func _restore_scroll(value: int) -> void:
	await get_tree().process_frame
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = value


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
	var c = s.get("captain")
	if c != null and int(c.get("wounded", 0)) > 0:
		panel.add_theme_stylebox_override("panel", Style.box(Style.PANEL, Style.ENEMY_LIGHT, 2, 14))
	row.add_child(_squad_art(c, s))
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 2)
	row.add_child(text)
	var title := String(s.get("name", ""))
	text.add_child(Style.label(title if title != "" else Units.troop_name(s, GameState.culture), Style.BODY))
	var who: Label
	if c == null:
		who = Style.label("No captain", Style.SMALL, Style.ENEMY_LIGHT)
	else:
		var hero_star := "★ " if bool(c.get("is_hero", false)) else ""
		var spec_tag := " · %s" % c["specialization"] if String(c.get("specialization", "")) != "" else ""
		if int(c.get("wounded", 0)) > 0:
			who = Style.label("%s%s · wounded, back in %d%s" % [hero_star, c["name"], c["wounded"], spec_tag], Style.SMALL, Style.ENEMY_LIGHT)
		else:
			who = Style.label("%s%s%s · %s" % [hero_star, c["name"], spec_tag, Captains.traits(c)], Style.SMALL, Style.MUTED)
	who.text = "%s · %s" % [Units.troop_name(s, GameState.culture), who.text]
	who.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	who.custom_minimum_size = Vector2(10, 0)
	text.add_child(who)
	var wounded: int = int(s.get("wounded", 0))
	var str_label := "Strength · %d/%d" % [men, full]
	if wounded > 0:
		str_label += " (+%d wounded)" % wounded
	text.add_child(_meter(str_label, men, full,
		Style.MORALE_HIGH if men >= full * 0.65 else (Style.MORALE_MID if men >= full * 0.35 else Style.MORALE_LOW)))
	var xp := int(s.get("xp", 0))
	var xp_target := maxi(Troops.XP_PER_LEVEL, level * Troops.XP_PER_LEVEL)
	var xp_text := "Experience · %d/%d" % [mini(xp, xp_target), xp_target]
	if GameState.can_train(s):
		xp_text += " · training ready"
	text.add_child(_meter(xp_text, mini(xp, xp_target), xp_target, Style.BRASS))
	if c != null:
		var bond := _best_bond(c)
		text.add_child(_meter(String(bond["label"]), float(bond["value"]), float(bond["target"]), Style.PLAYER_LIGHT))
	if GameState.can_train(s):
		row.add_child(Style.label("Lv%d+" % level, Style.SMALL, Style.BRASS))
	elif level > 1:
		row.add_child(Style.label("Lv%d" % level, Style.SMALL, Style.BRASS))
	var count_text := "%d/%d" % [men, full] if wounded == 0 else "%d(+%d)/%d" % [men, wounded, full]
	row.add_child(Style.label(count_text, Style.BODY, Style.TEXT if men >= full else Style.ENEMY_LIGHT))
	if c != null:
		_add_profile_tap(panel, int(c.get("id", -1)), String(c.get("name", "Captain")))
	return panel


func _meter(label_text: String, value: float, maximum: float, color: Color) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.add_child(Style.label(label_text, Style.SMALL, Style.MUTED))
	var bar := ProgressBar.new()
	bar.name = "WarbandMeter"
	bar.show_percentage = false
	bar.min_value = 0.0
	bar.max_value = maxf(1.0, maximum)
	bar.value = clampf(value, 0.0, bar.max_value)
	bar.custom_minimum_size.y = 12
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("fill", Style.box(color, Color(0, 0, 0, 0), 0, 5))
	box.add_child(bar)
	return box


func _best_bond(captain: Dictionary) -> Dictionary:
	var points := 0.0
	var other_name := "No bond yet"
	for other_id in captain.get("bonds", {}):
		var candidate := float(captain["bonds"][other_id])
		if candidate > points:
			points = candidate
			var other = GameState.captain_by_id(int(other_id))
			other_name = String(other["first"]) if other != null else "Bond"
	var rank_index := Captains.rank_for(points)
	var target: float = float(Captains.RANK_POINTS[rank_index + 1]) if rank_index + 1 < Captains.RANK_POINTS.size() else float(Captains.RANK_POINTS[-1])
	var next_rank: String = String(Captains.RANKS[rank_index + 1]) if rank_index + 1 < Captains.RANKS.size() else "A"
	var label := "Bond · %s · %.0f/%.0f to %s" % [other_name, points, target, next_rank]
	if rank_index == Captains.RANKS.size() - 1:
		label = "Bond · %s · rank A" % other_name
	return {"label": label, "value": points, "target": target}


func _note(text: String, color: Color = Style.MUTED) -> Label:
	var l := Style.label(text, Style.SMALL, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _active_job_row(job: Dictionary) -> Control:
	var panel := PanelContainer.new()
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	margin.add_child(v)

	var h := HBoxContainer.new()
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(h)

	var title_lbl := Style.label(String(job.get("title", "Contract")), Style.LARGE, Style.BRASS)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(title_lbl)

	var jid: String = String(job.get("id", ""))
	var abandon_btn := Button.new()
	abandon_btn.text = "Abandon"
	abandon_btn.custom_minimum_size = Vector2(100, 36)
	abandon_btn.add_theme_font_size_override("font_size", Style.text_size(Style.SMALL))
	abandon_btn.pressed.connect(func():
		GameState.abandon_job(jid)
		_build()
	)
	h.add_child(abandon_btn)

	var desc_lbl := Style.label(String(job.get("description", "")), Style.BODY, Style.TEXT)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(desc_lbl)

	var w = GameState.world
	var cur_hour: float = w.hour if w != null else 0.0
	var hrs_left: float = maxf(0.0, float(job.get("deadline", 0.0)) - cur_hour)
	var status_text := "Deadline: %.0fh remaining · Reward: %d silver, +%d renown, +%d standing" % [
		hrs_left,
		int(job.get("reward_silver", 0)),
		int(job.get("reward_renown", 0)),
		int(job.get("reward_relation", 0))
	]
	v.add_child(Style.label(status_text, Style.SMALL, Style.MUTED))
	return panel


func _bond_row(bond: Dictionary) -> Control:
	var panel := PanelContainer.new()
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	panel.add_child(stack)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	stack.add_child(row)
	var a: Dictionary = bond["a"]
	var b: Dictionary = bond["b"]
	var a_face := CaptainArt.portrait(a, Vector2(45, 60))
	var b_face := CaptainArt.portrait(b, Vector2(45, 60))
	row.add_child(a_face)
	row.add_child(b_face)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(words)
	words.add_child(Style.label("%s & %s" % [a["first"], b["first"]], Style.BODY, Style.TEXT))
	var record := GameState.bond_record(int(a["id"]), int(b["id"]))
	var shared := int(record.get("shared_battles", 0))
	var history_text: String = "%d shared %s" % [shared, "battle" if shared == 1 else "battles"] if shared > 0 else "earlier battle record unavailable"
	words.add_child(_note("Bond %s · %.0f shared points · %s" % [bond["rank"], float(bond["points"]), history_text], Style.BRASS))
	words.add_child(_note(GameState.bond_effect_text(float(bond["points"])), Style.TEXT))
	var rank_index := Captains.rank_for(float(bond["points"]))
	var target: float = float(Captains.RANK_POINTS[rank_index + 1]) if rank_index + 1 < Captains.RANK_POINTS.size() else float(Captains.RANK_POINTS[-1])
	var progress_text: String = "Highest rank reached" if rank_index + 1 >= Captains.RANKS.size() else "%.0f/%.0f points toward rank %s" % [float(bond["points"]), target, Captains.RANKS[rank_index + 1]]
	stack.add_child(_meter(progress_text, float(bond["points"]), target, Style.BRASS))
	var talk := Button.new()
	talk.name = "BondConversation_%d_%d" % [int(a["id"]), int(b["id"])]
	talk.text = "Spend time at camp" + (" · new" if GameState.bond_conversation_is_new(int(a["id"]), int(b["id"])) else "")
	talk.custom_minimum_size.y = Style.TOUCH
	talk.pressed.connect(_open_bond.bind(int(a["id"]), int(b["id"])))
	stack.add_child(talk)
	return panel


func _open_bond(a_id: int, b_id: int) -> void:
	Scenes.warband_scroll = _scroll.scroll_vertical if _scroll != null else 0
	Scenes.active_bond_a_id = a_id
	Scenes.active_bond_b_id = b_id
	Scenes.bond_conversation_return = "res://scenes/main_menu.tscn"
	Scenes.go("res://scenes/bond_conversation.tscn")


func _memorial_row(f: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Style.box(Style.NIGHT, Style.RULE, 2, 14))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	var portrait := _captain_or_unit(f, f)
	portrait.modulate = Color(0.55, 0.55, 0.6)
	row.add_child(portrait)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	text.add_child(Style.label(String(f.get("name", "")), Style.BODY))
	var deeds := "%s · fell in battle %d · fought %d, felled %d" % [f.get("company", ""), int(f.get("battle", 0)),
		int(f.get("battles", 0)), int(f.get("kills", 0))]
	if f.get("killed_by_lord_name", "") != "":
		deeds += " · slain by the men of %s" % f["killed_by_lord_name"]
	if bool(f.get("avenged", false)):
		deeds += " · [Avenged]"
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
	if String(f.get("avenged_words", "")) != "":
		var av := Style.label(f["avenged_words"], Style.SMALL, Style.PLAYER_LIGHT)
		av.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_child(av)
	if int(f.get("id", 0)) > 0:
		_add_profile_tap(panel, int(f["id"]), String(f.get("name", "Captain")))
	return panel


func _captive_lord_row(cl: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Style.box(Style.NIGHT, Style.RULE, 2, 14))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)

	var title_row := HBoxContainer.new()
	title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(title_row)

	var name_lbl := Style.label(String(cl.get("name", "Captive Lord")), Style.BODY, Style.BRASS)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(name_lbl)

	var realm_name: String = WorldData.FACTIONS.get(cl.get("realm", ""), {}).get("name", cl.get("realm", ""))
	var desc := "%s · Renown %d · Held in baggage" % [realm_name, int(cl.get("renown", 0))]
	col.add_child(Style.label(desc, Style.SMALL, Style.MUTED))

	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 8)
	col.add_child(btns)

	var lord_id := int(cl["id"])
	var ransom := int(cl.get("ransom_amount", 200))

	var ransom_btn := Button.new()
	ransom_btn.text = "Ransom · %d s" % ransom
	ransom_btn.pressed.connect(func():
		GameState.accept_lord_ransom(lord_id)
		Sound.play("coins")
		_build()
	)
	btns.add_child(ransom_btn)

	if GameState.has_contract() and GameState.world != null and GameState.world.at_war(GameState.contract_realm(), String(cl.get("realm", ""))):
		var bonus: int = int(GameState.contract.get("bonus_per_lord", 100))
		var deliver_btn := Button.new()
		deliver_btn.text = "Deliver · %d s" % bonus
		deliver_btn.pressed.connect(func():
			GameState.deliver_lord_to_employer(lord_id)
			Sound.play("coins")
			_build()
		)
		btns.add_child(deliver_btn)

	var honor_btn := Button.new()
	honor_btn.text = "Release for honor"
	honor_btn.pressed.connect(func():
		GameState.release_lord_for_honor(lord_id)
		Sound.play("page")
		_build()
	)
	btns.add_child(honor_btn)

	return panel


## The full roster card opens the person behind the company. The button is flat so the
## existing card remains visible and gains one large, accessible touch target.
func _add_profile_tap(panel: PanelContainer, captain_id: int, captain_name: String) -> void:
	var tap := Button.new()
	tap.name = "CaptainProfile_%d" % captain_id
	tap.flat = true
	tap.focus_mode = Control.FOCUS_ALL
	tap.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tap.tooltip_text = "View %s" % captain_name
	tap.accessibility_name = "View %s's profile" % captain_name
	tap.pressed.connect(func(): _open_captain(captain_id))
	panel.add_child(tap)


func _open_captain(captain_id: int) -> void:
	Scenes.warband_scroll = _scroll.scroll_vertical if _scroll != null else 0
	Scenes.active_captain_id = captain_id
	Scenes.captain_profile_return = "res://scenes/main_menu.tscn"
	Scenes.go("res://scenes/captain_profile.tscn")


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


func _captain_or_unit(captain, squad: Dictionary) -> TextureRect:
	if typeof(captain) == TYPE_DICTIONARY and CaptainArt.texture(captain) != null:
		return CaptainArt.portrait(captain, Vector2(60, 80))
	return _portrait(_kit(squad), String(squad.get("culture", GameState.culture)))


func _squad_art(captain, squad: Dictionary) -> Control:
	if typeof(captain) != TYPE_DICTIONARY or CaptainArt.texture(captain) == null:
		return _portrait(_kit(squad), String(squad.get("culture", GameState.culture)))
	var art := HBoxContainer.new()
	art.name = "CaptainAndTroopArt"
	art.add_theme_constant_override("separation", 4)
	art.add_child(CaptainArt.portrait(captain, Vector2(48, 64)))
	var unit := _portrait(_kit(squad), String(squad.get("culture", GameState.culture)))
	unit.custom_minimum_size = Vector2(38, 38)
	art.add_child(unit)
	return art


func _on_battle() -> void:
	if GameState.total_men() == 0:
		return
	Scenes.go("res://scenes/battle.tscn")


func _on_reinforce() -> void:
	GameState.reinforce()
	_build()
