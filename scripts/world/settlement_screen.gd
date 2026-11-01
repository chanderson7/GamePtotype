## A settlement you've stopped at: buy food, hire the recruits looking for work, and in a
## town reinforce and train your squads. The clock stands still while you're here. All
## rules live in game_state.gd; this screen shows them and passes the taps on.
extends Control

const StoryArt = preload("res://scripts/ui/story_art.gd")
const Troops = preload("res://scripts/data/troops.gd")
const Style = preload("res://scripts/ui/style.gd")
const Art = preload("res://scripts/art/unit_art.gd")
const Cultures = preload("res://scripts/data/cultures.gd")
const WorldData = preload("res://scripts/world/world_data.gd")
const Economy = preload("res://scripts/data/economy.gd")
const Units = preload("res://scripts/data/units.gd")
const Relationships = preload("res://scripts/data/relationships.gd")
const SettlementVista = preload("res://scripts/ui/settlement_vista.gd")
const TravelPresentation = preload("res://scripts/world/travel_presentation.gd")
const Jobs = preload("res://scripts/data/jobs.gd")
const Fiefs = preload("res://scripts/data/fiefs.gd")

## The food you can buy in one go, in days for the whole warband.
const FOOD_DAYS := [3, 7]

var place := ""
var autoplay := false
var _scroll: ScrollContainer
var _arrival_overlay: Control
var _arrival_dismissing := false
var _info_sheet: Control
## The open tab, remembered per place for the session, so a conversation or a purchase
## brings you back where you were.
var tab := ""
static var _tab_by_place := {}


func _ready() -> void:
	theme = Style.make_theme()
	autoplay = OS.get_cmdline_user_args().has("--autoplay")
	var w = GameState.world
	if w == null or w.here() == "":
		get_tree().change_scene_to_file.call_deferred("res://scenes/world_map.tscn" if w != null else "res://scenes/title.tscn")
		return
	place = w.here()
	Sound.play_music(WorldData.culture_of(WorldData.settlement(place)["faction"]))
	Sound.play_culture_accent(WorldData.culture_of(WorldData.settlement(place)["faction"]))
	var travel := TravelPresentation.context(w, GameState.army)
	Sound.set_loop(String(travel.get("ambience", "settlement_edge")))
	_build()
	var show_arrival: bool = Scenes.settlement_arrival_pending and not autoplay
	Scenes.settlement_arrival_pending = false
	if show_arrival:
		_show_arrival_card()
	if autoplay:
		_autoplay.call_deferred()


func _exit_tree() -> void:
	Sound.set_loop("")


func _build() -> void:
	var keep := _scroll.scroll_vertical if _scroll != null else (Scenes.settlement_scroll if Scenes.settlement_place == place else 0)
	for child in get_children():
		if child != _arrival_overlay:
			child.queue_free()

	var bg := ColorRect.new()
	bg.color = Style.NIGHT
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	move_child(bg, 0)

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
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 40 + int(insets["top"]))
	margin.add_theme_constant_override("margin_bottom", 24)
	_scroll.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	margin.add_child(col)

	var vista := SettlementVista.make(place, GameState.world, 240.0)
	vista.name = "LocationIllustration"
	col.add_child(vista)
	_add_header(col)
	_add_wallet(col)

	var owner := String(GameState.world.owner_of(place))
	if GameState.is_at_war_with(owner):
		_add_hostile_notice(col, owner)
	else:
		_add_tabs(col, owner)

	# Leaving stays in thumb reach, whatever the page scrolls to.
	var bar := PanelContainer.new()
	bar.name = "LeaveBar"
	var bar_box := Style.box(Style.NIGHT, Style.RULE, 0, 0)
	bar_box.border_width_top = 2
	bar_box.content_margin_left = 32
	bar_box.content_margin_right = 32
	bar_box.content_margin_top = 14
	bar_box.content_margin_bottom = 14 + insets["bottom"]
	bar.add_theme_stylebox_override("panel", bar_box)
	frame.add_child(bar)
	var back := Button.new()
	back.name = "LeaveButton"
	back.text = "Leave %s" % String(WorldData.settlement(place)["name"])
	back.custom_minimum_size = Vector2(0, 92)
	back.add_theme_font_size_override("font_size", Style.text_size(Style.LARGE))
	Style.make_primary(back)
	back.pressed.connect(_on_leave)
	bar.add_child(back)

	_build_info_sheet()
	if _arrival_overlay != null and is_instance_valid(_arrival_overlay):
		move_child(_arrival_overlay, get_child_count() - 1)
	_restore_scroll(keep)


## The name, what the place is, and two coloured chips: how well it's held and how safe
## its roads are. Everything else waits behind the info button.
func _add_header(col: VBoxContainer) -> void:
	var w = GameState.world
	var title_row := HFlowContainer.new()
	title_row.add_theme_constant_override("h_separation", 16)
	col.add_child(title_row)
	var title := Style.label(String(WorldData.settlement(place)["name"]), 64, Style.BRASS)
	title.name = "SettlementName"
	title_row.add_child(title)
	var kind := Style.label(w.brief(place), Style.BODY, Style.MUTED)
	kind.name = "SettlementKind"
	kind.size_flags_vertical = Control.SIZE_SHRINK_END
	title_row.add_child(kind)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	var chips := HFlowContainer.new()
	chips.name = "SettlementChips"
	chips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chips.add_theme_constant_override("h_separation", 10)
	chips.add_theme_constant_override("v_separation", 10)
	row.add_child(chips)
	if w.garrisons.has(place):
		var men: int = w.men_of(w.garrison_at(place))
		var cap: int = w.garrison_capacity(place)
		var tone := Style.MORALE_LOW if men < cap * 0.4 else (Style.MORALE_HIGH if men >= cap * 0.8 else Style.MORALE_MID)
		chips.add_child(_chip("Garrison %d/%d" % [men, cap], tone))
	var danger := String(w.settlement_danger(place))
	if danger == "":
		chips.add_child(_chip("Quiet roads", Style.MORALE_HIGH))
	else:
		var short := danger.split(";")[0].split(":")[0]
		chips.add_child(_chip(short.substr(0, 1).to_upper() + short.substr(1), Style.MORALE_LOW))
	var info := Button.new()
	info.name = "InfoButton"
	info.text = "i"
	info.tooltip_text = "About %s" % String(WorldData.settlement(place)["name"])
	info.custom_minimum_size = Vector2(64, 64)
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_font_size_override("font_size", Style.text_size(Style.BODY))
	info.add_theme_stylebox_override("normal", Style.box(Style.NIGHT, Style.RULE, 2, 40))
	info.add_theme_stylebox_override("hover", Style.box(Style.PANEL, Style.MUTED, 2, 40))
	info.add_theme_stylebox_override("pressed", Style.box(Style.PANEL, Style.BRASS, 2, 40))
	info.pressed.connect(_show_info)
	row.add_child(info)

	var recent := String(TravelPresentation.settlement_state(w, place).get("recent_event", ""))
	if recent != "":
		var recent_note := _note("Recent: %s" % recent, Style.MUTED)
		recent_note.name = "SettlementRecentEvent"
		col.add_child(recent_note)


func _chip(text: String, tone: Color) -> PanelContainer:
	var chip := PanelContainer.new()
	var sb := Style.box(Style.RAISED, Style.RULE, 2, 40)
	sb.content_margin_left = 16
	sb.content_margin_right = 18
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	chip.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	chip.add_child(h)
	var dot := Panel.new()
	dot.custom_minimum_size = Vector2(14, 14)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.add_theme_stylebox_override("panel", Style.box(tone, Color(0, 0, 0, 0), 0, 7))
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(dot)
	h.add_child(Style.label(text, Style.SMALL, Style.TEXT))
	return chip


## Silver with what the company costs a day, and food in days, as two tiles.
func _add_wallet(col: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.name = "Wallet"
	row.add_theme_constant_override("separation", 14)
	col.add_child(row)
	var days := GameState.food_days()
	row.add_child(_tile("silver", _thousands(GameState.silver), "−%d a day" % GameState.daily_wages(), Style.TEXT))
	row.add_child(_tile("food", "1 day" if days == 1 else "%d days" % days, "of food",
		Style.ENEMY_LIGHT if days < 3 else Style.TEXT))


func _tile(icon: String, value: String, sub: String, tone: Color) -> PanelContainer:
	var tile := PanelContainer.new()
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	tile.add_child(h)
	var tex := TextureRect.new()
	tex.texture = load("res://assets/ui/%s.svg" % icon)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.custom_minimum_size = Vector2(44, 44)
	tex.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(tex)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	h.add_child(v)
	v.add_child(Style.label(value, Style.LARGE, tone))
	v.add_child(Style.label(sub, Style.SMALL, Style.MUTED))
	return tile


static func _thousands(n: int) -> String:
	var digits := str(absi(n))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if n < 0 else "") + digits + out


## One thing at a time: what's for sale, the company, paid work, the court, and your own
## fief when this is it. Only tabs with something in them are shown.
func _add_tabs(col: VBoxContainer, owner: String) -> void:
	var w = GameState.world
	var tabs: Array = []
	if GameState.is_player_fief(place):
		tabs.append({"id": "fief", "label": "Fief", "badge": 0})
	var offers: int = 0 if GameState.army.size() >= GameState.squad_cap() else w.offers_at(place).size()
	tabs.append({"id": "buy", "label": "Buy", "badge": offers + GameState.available_heroes_at(place).size()})
	tabs.append({"id": "squads", "label": "Squads", "badge": 0})
	tabs.append({"id": "work", "label": "Work", "badge": GameState.active_jobs_completable_at(place).size()})
	if w.social != null and not w.social.residents_at(place).is_empty():
		tabs.append({"id": "court", "label": "Court", "badge": 0})
	var ids: Array = tabs.map(func(t): return t["id"])
	var current := String(_tab_by_place.get(place, ""))
	if not ids.has(current):
		current = "fief" if ids.has("fief") else "buy"
	tab = current

	var bar := PanelContainer.new()
	bar.name = "SettlementTabs"
	var bar_box := Style.box(Style.PANEL, Style.RULE, 2, 18)
	bar_box.content_margin_left = 6
	bar_box.content_margin_right = 6
	bar_box.content_margin_top = 6
	bar_box.content_margin_bottom = 6
	bar.add_theme_stylebox_override("panel", bar_box)
	col.add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	bar.add_child(row)
	for t in tabs:
		var b := Button.new()
		b.name = "Tab_%s" % t["id"]
		b.text = String(t["label"]) + ("  %d" % t["badge"] if int(t["badge"]) > 0 else "")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 72)
		b.add_theme_font_size_override("font_size", Style.text_size(Style.SMALL))
		var on: bool = t["id"] == tab
		var flat := Style.box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 14)
		var lit := Style.box(Style.RAISED, Style.PLAYER_LIGHT.darkened(0.5), 2, 14)
		for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			b.add_theme_stylebox_override(state, lit if on else flat)
		var ink := Style.TEXT if on else Style.MUTED
		if int(t["badge"]) > 0 and not on:
			ink = Style.BRASS
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(c, ink)
		b.pressed.connect(_on_tab.bind(String(t["id"])))
		row.add_child(b)

	var body := VBoxContainer.new()
	body.name = "TabBody"
	body.add_theme_constant_override("separation", 16)
	col.add_child(body)
	match tab:
		"fief":
			_add_fief_management(body)
		"buy":
			_add_provisions(body)
			_add_recruits(body)
			_add_tavern_heroes(body)
		"squads":
			_add_squads(body)
		"work":
			_add_local_jobs(body)
			_add_contract(body, owner)
		"court":
			_add_court(body)


func _on_tab(id: String) -> void:
	if id == tab:
		return
	_tab_by_place[place] = id
	Sound.play("click", 0.0, 0.05)
	_build()


## A card: a titled panel with an optional note on the right of its title.
func _card(parent: Control, title: String, aside: String = "", aside_color: Color = Style.MUTED) -> VBoxContainer:
	var panel := PanelContainer.new()
	var sb := Style.box(Style.PANEL, Style.RULE, 2, 20)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 18
	sb.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", sb)
	parent.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var t := _section(title)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	if aside != "":
		head.add_child(Style.label(aside, Style.SMALL, aside_color))
	return v


## Everything about the place that isn't needed to act on it: its look, owner, garrison,
## danger, services and why it matters, in a sheet that slides up from the bottom.
func _build_info_sheet() -> void:
	var w = GameState.world
	var shade := ColorRect.new()
	shade.name = "InfoSheet"
	shade.color = Color(0.012, 0.02, 0.04, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.visible = false
	shade.gui_input.connect(func(e):
		if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed:
			_hide_info())
	add_child(shade)
	_info_sheet = shade

	var panel := PanelContainer.new()
	panel.name = "InfoPanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var sb := Style.box(Style.PANEL.lightened(0.02), Style.RULE, 2, 28)
	sb.corner_radius_bottom_left = 0
	sb.corner_radius_bottom_right = 0
	sb.content_margin_left = 32
	sb.content_margin_right = 32
	sb.content_margin_top = 18
	sb.content_margin_bottom = 36 + Style.safe_insets(get_viewport())["bottom"]
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	var grip := Panel.new()
	grip.custom_minimum_size = Vector2(80, 8)
	grip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grip.add_theme_stylebox_override("panel", Style.box(Style.RULE, Color(0, 0, 0, 0), 0, 4))
	v.add_child(grip)
	v.add_child(Style.label("About %s" % String(WorldData.settlement(place)["name"]), Style.LARGE, Style.TEXT))
	var condition := _note(String(TravelPresentation.settlement_state(w, place).get("sentence", "")), Style.MUTED)
	condition.name = "SettlementCondition"
	v.add_child(condition)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	for line in String(w.settlement_intelligence(place)).split("\n"):
		var parts := String(line).split(": ", true, 1)
		if parts.size() < 2:
			continue
		var key := Style.label(parts[0], Style.SMALL, Style.MUTED)
		key.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		grid.add_child(key)
		var value := _note(parts[1].substr(0, 1).to_upper() + parts[1].substr(1), Style.TEXT)
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(value)
	var close := _button("Close", _hide_info)
	v.add_child(close)


func _show_info() -> void:
	if _info_sheet == null:
		return
	_info_sheet.visible = true
	Style.ease_in(_info_sheet.get_child(0))


func _hide_info() -> void:
	if _info_sheet != null:
		_info_sheet.visible = false


## Rebuilding after a tap shouldn't throw the player back to the top.
func _restore_scroll(value: int) -> void:
	if value <= 0:
		return
	await get_tree().process_frame
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = value


## A short, dismissible bridge from the road into the settlement. It is deliberately
## local UI state: showing or dismissing it cannot touch campaign time or save data.
func _show_arrival_card() -> void:
	if _arrival_overlay != null or place == "":
		return
	var arrival := TravelPresentation.arrival(GameState.world, place)
	if arrival.is_empty():
		return
	_arrival_dismissing = false
	var shade := ColorRect.new()
	shade.name = "ArrivalOverlay"
	shade.color = Color(0.025, 0.035, 0.065, 0.92)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.z_index = 50
	shade.gui_input.connect(_on_arrival_input)
	add_child(shade)
	_arrival_overlay = shade

	var safe := MarginContainer.new()
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var insets := Style.safe_insets(get_viewport())
	safe.add_theme_constant_override("margin_left", 42)
	safe.add_theme_constant_override("margin_right", 42)
	safe.add_theme_constant_override("margin_top", 42 + int(insets["top"]))
	safe.add_theme_constant_override("margin_bottom", 42 + int(insets["bottom"]))
	shade.add_child(safe)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	safe.add_child(center)
	var card := PanelContainer.new()
	card.name = "ArrivalCard"
	card.custom_minimum_size = Vector2(600, 0)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(col)
	if Sound.illustrations_enabled:
		var vista := SettlementVista.make(place, GameState.world, 280.0)
		vista.name = "ArrivalVista"
		col.add_child(vista)
	var arrived := Style.label("ARRIVED", Style.SMALL, Style.MUTED)
	arrived.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(arrived)
	var title := Style.label(String(arrival["name"]), 64, Style.BRASS)
	title.name = "ArrivalTitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(title)
	var subtitle := Style.label(String(arrival["subtitle"]), Style.BODY, Style.TEXT)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(subtitle)
	var condition := Style.label(String(arrival["condition"]), Style.BODY, Style.MUTED)
	condition.name = "ArrivalCondition"
	condition.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	condition.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(condition)
	var hint := Style.label("Tap to continue", Style.SMALL, Style.MUTED.darkened(0.1))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint)
	Style.ease_in(card, Vector2(0.5, 0.5))
	get_tree().create_timer(0.72).timeout.connect(_dismiss_arrival)


func _on_arrival_input(event: InputEvent) -> void:
	if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed):
		_dismiss_arrival()
		get_viewport().set_input_as_handled()


func _dismiss_arrival() -> void:
	if _arrival_overlay == null or not is_instance_valid(_arrival_overlay) or _arrival_dismissing:
		return
	_arrival_dismissing = true
	var overlay := _arrival_overlay
	if Sound.reduced_motion:
		overlay.queue_free()
		_arrival_overlay = null
		return
	var fade := overlay.create_tween()
	fade.tween_property(overlay, "modulate:a", 0.0, 0.14)
	fade.tween_callback(_finish_arrival.bind(overlay))


func _finish_arrival(overlay: Control) -> void:
	if is_instance_valid(overlay):
		overlay.queue_free()
	if _arrival_overlay == overlay:
		_arrival_overlay = null


func _unhandled_key_input(event: InputEvent) -> void:
	if _arrival_overlay != null and (event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel")):
		_dismiss_arrival()
		get_viewport().set_input_as_handled()


func _add_hostile_notice(col: VBoxContainer, owner: String) -> void:
	var card := _card(col, "Gates barred", "at war", Style.ENEMY_LIGHT)
	var faction_name: String = WorldData.FACTIONS[owner]["name"]
	card.add_child(_note("The %s is at war with you. Markets, barracks and halls are closed." % faction_name, Style.ENEMY_LIGHT))


func _add_contract(col: VBoxContainer, owner: String) -> void:
	var kind: String = WorldData.settlement(place)["type"]
	if not kind in [WorldData.CASTLE, WorldData.TOWN]:
		return

	var faction_name: String = WorldData.FACTIONS[owner]["name"]

	if GameState.has_fief():
		col.add_child(_section("Fealty & Lordship"))
		if GameState.fief_realm() == owner:
			col.add_child(_note("Sworn vassal of the %s · Lord of %s" % [faction_name, WorldData.settlement(GameState.fief_id())["name"]], Style.BRASS))
		else:
			var other_name: String = WorldData.FACTIONS[GameState.fief_realm()]["name"]
			col.add_child(_note("Your company is already sworn in fealty to the %s." % other_name, Style.MUTED))
		return

	if GameState.can_petition_fief(owner):
		col.add_child(_section("Fealty & Fiefdom"))
		col.add_child(_note("The crown recognizes your valor and standing (%d renown, %d relation). You may swear fealty as a vassal of the %s and receive governance of a fief." % [
			GameState.renown, GameState.relation_with_realm(owner), faction_name
		], Style.BRASS))
		var fief_candidates: Array = GameState.available_fiefs_for_grant(owner)
		for fid in fief_candidates:
			var fname := String(WorldData.settlement(fid)["name"])
			var ftype := String(WorldData.settlement(fid)["type"]).capitalize()
			var btn := _button("Swear Fealty and Claim %s (%s)" % [fname, ftype], func():
				if GameState.accept_fealty_and_fief(fid, owner):
					Sound.play("charge")
					_build()
			)
			Style.make_primary(btn)
			col.add_child(btn)

	col.add_child(_section("Mercenary commission"))

	if GameState.has_contract():
		if GameState.contract_realm() == owner:
			var daily: int = GameState.contract_daily_pay()
			var left: int = int(GameState.contract.get("days_left", 0))
			var bonus: int = int(GameState.contract.get("bonus_per_lord", 100))
			col.add_child(_note("In service to %s · %d silver daily (%d days remaining) · %d silver bonus per captured enemy lord." % [
				faction_name, daily, left, bonus
			], Style.BRASS))
			var cancel_btn := _button("Resign commission (costs 25 relation)", _on_cancel_contract)
			col.add_child(cancel_btn)
		else:
			var other_name: String = WorldData.FACTIONS[GameState.contract_realm()]["name"]
			col.add_child(_note("Your company is already pledged to %s." % other_name, Style.MUTED))
		return

	if not GameState.world.is_at_war(owner):
		col.add_child(_note("%s is currently at peace and requires no mercenary companies." % faction_name, Style.MUTED))
		return

	var pay := GameState.calculate_contract_pay(owner)
	if GameState.renown < GameState.CONTRACT_MIN_RENOWN:
		col.add_child(_note("The realm is at war and seeks sellswords, but marshals only hire captains of renown (%d renown needed)." % GameState.CONTRACT_MIN_RENOWN, Style.MUTED))
		return

	col.add_child(_note("The %s is at war and seeks sellswords to take the field. A 30-day commission offers %d silver each day." % [
		faction_name, pay
	], Style.TEXT))
	var sign_btn := _button("Offer your sword (%d silver/day)" % pay, _on_sign_contract.bind(owner))
	Style.make_primary(sign_btn)
	col.add_child(sign_btn)


func _on_sign_contract(owner: String) -> void:
	GameState.sign_contract(owner)
	Sound.play("charge")
	_build()


func _on_cancel_contract() -> void:
	GameState.break_contract()
	Sound.play("alarm")
	_build()


func _add_fief_management(col: VBoxContainer) -> void:
	col.add_child(_section("Your Fief & Manor"))

	var fief: Dictionary = GameState.player_fief
	var cult: String = String(WorldData.settlement(place)["faction"])
	var title: String = Fiefs.title_for(cult)
	var s_name: String = String(WorldData.settlement(place)["name"])
	var r_name: String = String(WorldData.FACTIONS.get(String(fief.get("realm", "")), {}).get("name", "Realm"))

	# Header card
	var header_panel := PanelContainer.new()
	var h_margin := MarginContainer.new()
	h_margin.add_theme_constant_override("margin_left", 14)
	h_margin.add_theme_constant_override("margin_right", 14)
	h_margin.add_theme_constant_override("margin_top", 12)
	h_margin.add_theme_constant_override("margin_bottom", 12)
	header_panel.add_child(h_margin)
	var h_v := VBoxContainer.new()
	h_v.add_theme_constant_override("separation", 6)
	h_margin.add_child(h_v)

	var title_lbl := Style.label("%s of %s" % [title, s_name], Style.LARGE, Style.BRASS)
	h_v.add_child(title_lbl)
	h_v.add_child(Style.label("Sworn vassal of the %s · Seat of your company" % r_name, Style.SMALL, Style.TEXT))

	var is_b: bool = GameState.world != null and GameState.world.is_burned(place)
	var daily_t: int = Fiefs.daily_tax(fief, is_b)
	var daily_f: int = Fiefs.daily_food(fief, is_b)
	var cur_silver: int = int(fief.get("silver", 0))
	var cur_food: int = int(fief.get("food", 0))
	var max_f: int = Fiefs.max_food_capacity(fief)

	var stats_text := "Estate Treasury: %d / %d silver (+%d/day) · Granary: %d / %d rations (+%d/day)" % [
		cur_silver, Fiefs.MAX_STORAGE_SILVER, daily_t, cur_food, max_f, daily_f
	]
	if is_b:
		stats_text += "\n[Raided and Damaged: Tax and grain yields crippled]"
	var stats_lbl := Style.label(stats_text, Style.BODY, Style.MUTED if not is_b else Style.ENEMY_LIGHT)
	stats_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h_v.add_child(stats_lbl)

	# Buttons to collect taxes and food
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	h_v.add_child(btn_row)

	var collect_tax_btn := _button("Collect Taxes (%d silver)" % cur_silver, func():
		var got: int = GameState.collect_fief_taxes()
		if got > 0:
			Sound.play("coins")
			_build()
	)
	collect_tax_btn.disabled = cur_silver <= 0
	if cur_silver > 0:
		Style.make_primary(collect_tax_btn)
	btn_row.add_child(collect_tax_btn)

	var collect_food_btn := _button("Take Food (%d rations)" % cur_food, func():
		var got: int = GameState.collect_fief_food()
		if got > 0:
			Sound.play("coins")
			_build()
	)
	collect_food_btn.disabled = cur_food <= 0
	btn_row.add_child(collect_food_btn)
	col.add_child(header_panel)

	# Garrison Management Card
	col.add_child(_section("Fief Garrison"))
	var g_panel := PanelContainer.new()
	var g_margin := MarginContainer.new()
	g_margin.add_theme_constant_override("margin_left", 14)
	g_margin.add_theme_constant_override("margin_right", 14)
	g_margin.add_theme_constant_override("margin_top", 12)
	g_margin.add_theme_constant_override("margin_bottom", 12)
	g_panel.add_child(g_margin)
	var g_v := VBoxContainer.new()
	g_v.add_theme_constant_override("separation", 8)
	g_margin.add_child(g_v)

	var garrison: Array = fief.get("garrison", [])
	if garrison.is_empty():
		g_v.add_child(_note("No squads are currently stationed in the garrison. Troops in garrison heal wounds and protect your estate from raiders."))
	else:
		for i in garrison.size():
			var sq: Dictionary = garrison[i]
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			g_v.add_child(row)

			var c = sq.get("captain")
			var c_str := String(c.get("name", "Captain")) if c != null else "Company"
			var w_cnt := int(sq.get("wounded", 0))
			var men_str := "%d men" % int(sq["men"])
			if w_cnt > 0:
				men_str += " (+%d wounded)" % w_cnt
			var sq_lbl := Style.label("%s (%s · %s)" % [String(sq.get("name", "Squad")), c_str, men_str], Style.BODY, Style.TEXT)
			sq_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(sq_lbl)

			var withdraw_btn := _button("Take into Warband", func():
				if GameState.withdraw_squad_from_fief(i):
					_build()
			)
			withdraw_btn.disabled = GameState.army.size() >= GameState.squad_cap()
			row.add_child(withdraw_btn)

	# Station active squad into garrison
	if GameState.army.size() > 1:
		var st_lbl := Style.label("Station squad from warband into garrison:", Style.SMALL, Style.MUTED)
		g_v.add_child(st_lbl)
		var st_flow := HBoxContainer.new()
		st_flow.add_theme_constant_override("separation", 8)
		g_v.add_child(st_flow)
		for sq in GameState.army:
			var sid: int = int(sq["id"])
			var btn := _button("Station %s" % String(sq.get("name", "Squad")), func():
				if GameState.station_squad_in_fief(sid):
					_build()
			)
			st_flow.add_child(btn)
	col.add_child(g_panel)

	# Manor Improvements Card
	col.add_child(_section("Manor Improvements & Reconstruction"))
	var imp_panel := PanelContainer.new()
	var imp_margin := MarginContainer.new()
	imp_margin.add_theme_constant_override("margin_left", 14)
	imp_margin.add_theme_constant_override("margin_right", 14)
	imp_margin.add_theme_constant_override("margin_top", 12)
	imp_margin.add_theme_constant_override("margin_bottom", 12)
	imp_panel.add_child(imp_margin)
	var imp_v := VBoxContainer.new()
	imp_v.add_theme_constant_override("separation", 8)
	imp_margin.add_child(imp_v)

	if is_b:
		var rep_row := HBoxContainer.new()
		rep_row.add_theme_constant_override("separation", 10)
		imp_v.add_child(rep_row)
		var rep_desc := Style.label("Rebuild the burned village and restore peasant granaries.", Style.BODY, Style.ENEMY_LIGHT)
		rep_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rep_row.add_child(rep_desc)
		var rep_btn := _button("Rebuild Estate (%d silver)" % Fiefs.REPAIR_COST, func():
			var r: Dictionary = GameState.repair_fief()
			if r.get("ok", false):
				Sound.play("coins")
				_build()
		)
		rep_btn.disabled = GameState.silver < Fiefs.REPAIR_COST
		if GameState.silver >= Fiefs.REPAIR_COST:
			Style.make_primary(rep_btn)
		rep_row.add_child(rep_btn)

	var imps: Dictionary = fief.get("improvements", {})
	for ikey in [Fiefs.IMPROVEMENT_GRANARY, Fiefs.IMPROVEMENT_FORTIFICATIONS, Fiefs.IMPROVEMENT_MILL]:
		var idef: Dictionary = Fiefs.IMPROVEMENTS[ikey]
		var built: bool = bool(imps.get(ikey, false))
		var i_row := HBoxContainer.new()
		i_row.add_theme_constant_override("separation", 10)
		imp_v.add_child(i_row)

		var i_text := VBoxContainer.new()
		i_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		i_row.add_child(i_text)

		var iname := String(idef["name"]) + (" [Built]" if built else "")
		i_text.add_child(Style.label(iname, Style.BODY, Style.BRASS if built else Style.TEXT))
		var idesc := Style.label(String(idef["description"]), Style.SMALL, Style.MUTED)
		idesc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		i_text.add_child(idesc)

		if not built:
			var cost: int = int(idef["cost"])
			var b_btn := _button("Construct (%d silver)" % cost, func():
				var r: Dictionary = GameState.build_fief_improvement(ikey)
				if r.get("ok", false):
					Sound.play("coins")
					_build()
			)
			b_btn.disabled = GameState.silver < cost
			i_row.add_child(b_btn)
	col.add_child(imp_panel)

	# Renounce option
	var ren_btn := _button("Renounce Fealty (Forfeit fief to crown, -25 relation)", func():
		GameState.renounce_fief()
		Sound.play("alarm")
		_build()
	)
	col.add_child(ren_btn)


func _add_court(col: VBoxContainer) -> void:
	var w = GameState.world
	if w == null or w.social == null:
		return
	var residents: Array = w.social.residents_at(place)
	if residents.is_empty():
		return
	col.add_child(_section("Court & Nobles"))
	for person in residents:
		var name_str := String(person.get("name", "Noble"))
		var role_str := String(person.get("role", "Resident"))
		var cid := String(person.get("content_id", ""))
		var rel: Dictionary = w.social.get_relationship(cid)
		var status_str := Relationships.status_label(String(rel.get("status", Relationships.UNKNOWN)))
		var btn := _button("Speak with %s (%s · %s)" % [name_str, role_str, status_str], func():
			_remember_scroll()
			Scenes.active_candidate_id = cid
			Scenes.active_person_id = String(person.get("id", ""))
			Scenes.conversation_return = "res://scenes/settlement.tscn"
			Scenes.go("res://scenes/conversation.tscn"))
		col.add_child(btn)


func _add_provisions(col: VBoxContainer) -> void:
	var men := GameState.total_men()
	var kind := String(WorldData.settlement(place)["type"])
	var price := float(Economy.FOOD_PRICE.get(kind, 0.3))
	var card := _card(col, "Provisions", "%.1f a ration" % price)
	card.name = "ProvisionsCard"
	var hint := "A ration per man a day" + (" · villages sell cheaper" if kind != WorldData.VILLAGE else " · cheapest here")
	card.add_child(_note(hint))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	for d in FOOD_DAYS:
		var rations: int = d * men
		var cost := GameState.food_cost(rations)
		var b := _button("+%d days\n%d silver" % [d, cost], _on_buy_food.bind(rations))
		b.name = "Food%d" % d
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 96)
		b.add_theme_font_size_override("font_size", Style.text_size(Style.BODY))
		b.disabled = men == 0 or cost > GameState.silver
		row.add_child(b)


func _add_recruits(col: VBoxContainer) -> void:
	var cap := GameState.squad_cap()
	var full := GameState.army.size() >= cap
	var card := _card(col, "Recruits here", "%d/%d squads" % [GameState.army.size(), cap],
		Style.ENEMY_LIGHT if full else Style.MUTED)
	card.name = "RecruitsCard"
	var offers: Array = GameState.world.offers_at(place)
	for i in offers.size():
		card.add_child(_offer_row(offers[i], i, full))
	if offers.is_empty():
		var back: float = float(GameState.world.offers_back.get(place, GameState.world.hour)) - GameState.world.hour
		card.add_child(_note("Nobody's looking for work · more in about %d hours" % maxi(1, int(ceil(back)))))
	elif full:
		card.add_child(_note("Company full — win renown to lead more", Style.ENEMY_LIGHT))


func _add_tavern_heroes(col: VBoxContainer) -> void:
	var heroes: Array = GameState.available_heroes_at(place)
	if heroes.is_empty():
		return
	col.add_child(_section("Tavern & Wanderers"))
	for hero in heroes:
		col.add_child(_hero_row(hero))


func _hero_row(hero: Dictionary) -> Control:
	var hid := String(hero.get("id", ""))
	var name_str := String(hero.get("name", "Hero"))
	var cost := int(hero.get("cost", 250))
	var type := String(hero.get("type", Troops.INFANTRY))
	var cult := String(hero.get("culture", Cultures.VARDISH))
	var spec := String(hero.get("specialization", ""))
	var panel := PanelContainer.new()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	v.add_child(head)
	head.add_child(_portrait(type, cult))

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 2)
	head.add_child(text)
	text.add_child(Style.label(name_str + " ★", Style.BODY, Style.BRASS))
	var role_line := "%s · %s" % [Units.troop_name({"unit": hero.get("unit", "")}, cult), spec]
	text.add_child(Style.label(role_line, Style.SMALL, Style.TEXT))
	var bio := Style.label(String(hero.get("bio", "")), Style.SMALL, Style.MUTED)
	bio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(bio)

	var quote := Style.label("\"%s\"" % String(hero.get("dialogue", "")), Style.SMALL, Style.TEXT)
	quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(quote)

	var can_hire: bool = GameState.silver >= cost and GameState.army.size() < GameState.squad_cap()
	var hire_btn := _button("Recruit %s (%d silver)" % [String(hero.get("first", name_str)), cost], func():
		if GameState.recruit_hero(hid):
			Sound.play("charge")
			_build()
	)
	hire_btn.disabled = not can_hire
	if can_hire:
		Style.make_primary(hire_btn)
	v.add_child(hire_btn)
	return panel


func _add_local_jobs(col: VBoxContainer) -> void:
	var w = GameState.world
	if w == null:
		return

	# Deliveries ready for turn-in
	var deliverable: Array = GameState.active_jobs_completable_at(place)
	if not deliverable.is_empty():
		col.add_child(_section("Contract Deliveries"))
		for job in deliverable:
			col.add_child(_deliverable_job_card(job))

	# Notice board offers
	col.add_child(_section("Notice Board & Local Work"))
	var active_count: int = GameState.active_jobs.size()
	var cap_note := Style.label("Active contracts: %d / %d" % [active_count, Jobs.MAX_ACTIVE_JOBS], Style.SMALL, Style.MUTED)
	col.add_child(cap_note)

	var offers: Array = GameState.jobs_at(place)
	if offers.is_empty():
		col.add_child(_note("No local contracts are currently posted. Notices refresh every few days."))
	else:
		for i in offers.size():
			col.add_child(_job_offer_card(offers[i], i, active_count >= Jobs.MAX_ACTIVE_JOBS))


func _deliverable_job_card(job: Dictionary) -> Control:
	var panel := PanelContainer.new()
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	margin.add_child(v)

	var title_lbl := Style.label(String(job.get("title", "Contract")), Style.LARGE, Style.BRASS)
	v.add_child(title_lbl)

	var desc_lbl := Style.label(String(job.get("description", "")), Style.BODY, Style.TEXT)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(desc_lbl)

	var rew_text := "Reward: %d silver · +%d renown · +%d standing" % [
		int(job.get("reward_silver", 0)),
		int(job.get("reward_renown", 0)),
		int(job.get("reward_relation", 0))
	]
	if String(job.get("type", "")) == Jobs.TYPE_RELIEF:
		rew_text += " (Requires %d rations)" % int(job.get("food_needed", 0))
	v.add_child(Style.label(rew_text, Style.SMALL, Style.MUTED))

	var jid: String = String(job.get("id", ""))
	var claim_btn := _button("Complete Contract & Claim Reward", func():
		var res: Dictionary = GameState.complete_job(jid)
		if res.get("ok", false):
			_paid(true)
	)
	Style.make_primary(claim_btn)
	v.add_child(claim_btn)
	return panel


func _job_offer_card(job: Dictionary, index: int, is_capped: bool) -> Control:
	var panel := PanelContainer.new()
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	margin.add_child(v)

	var title_lbl := Style.label(String(job.get("title", "Contract")), Style.LARGE, Style.TEXT)
	v.add_child(title_lbl)

	var desc_lbl := Style.label(String(job.get("description", "")), Style.BODY, Style.MUTED)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(desc_lbl)

	var hrs_left: float = maxf(0.0, float(job.get("deadline", 0.0)) - (GameState.world.hour if GameState.world != null else 0.0))
	var terms := "Deadline: %.0fh · Reward: %d silver, +%d renown, +%d standing" % [
		hrs_left,
		int(job.get("reward_silver", 0)),
		int(job.get("reward_renown", 0)),
		int(job.get("reward_relation", 0))
	]
	v.add_child(Style.label(terms, Style.SMALL, Style.MUTED))

	var accept_btn := _button("Accept Contract" if not is_capped else "Contract Limit Reached (%d/%d)" % [Jobs.MAX_ACTIVE_JOBS, Jobs.MAX_ACTIVE_JOBS], func():
		if GameState.accept_job(place, index):
			Sound.play("coins")
			_build()
	)
	accept_btn.disabled = is_capped
	if not is_capped:
		Style.make_primary(accept_btn)
	v.add_child(accept_btn)
	return panel


func _offer_row(offer: Dictionary, index: int, full: bool) -> Control:
	var type := String(offer["type"])
	var culture := String(offer["culture"])
	var men := Troops.full_size(type)
	var cost := Economy.recruit_cost(type, men)
	var wage := Economy.daily_wage({"type": type, "men": men, "level": 1})
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.add_child(_portrait(type, culture))
	var text := _text_column(row)
	text.add_child(Style.label(Cultures.troop_name(culture, type), Style.BODY))
	var people := String(Cultures.info(culture)["people"])
	text.add_child(_small("%d %s · %d a day" % [men, people, int(ceil(wage))]))
	var b := _button("Hire %d" % cost, _on_hire.bind(index))
	b.custom_minimum_size = Vector2(150, Style.TOUCH)
	b.disabled = full or cost > GameState.silver
	if not b.disabled:
		Style.make_primary(b)
	row.add_child(b)
	return row


func _add_squads(col: VBoxContainer) -> void:
	var card := _card(col, "Your squads", "%d men" % GameState.total_men())
	if not GameState.in_town():
		card.add_child(_note("Ride to a town to refill and train your squads."))
		return
	card.add_child(_note("Fresh men water down experience · training raises wages"))
	col = card
	var total := 0
	var cheapest := 0
	for s in GameState.army:
		var cost := GameState.reinforce_cost(s)
		total += cost
		if cost > 0 and (cheapest == 0 or cost < cheapest):
			cheapest = cost
		col.add_child(_squad_row(s))
	if total > 0:
		var all := _button("Reinforce all · %d silver" % total, _on_reinforce_all)
		all.disabled = cheapest > GameState.silver
		col.add_child(all)


func _squad_row(s: Dictionary) -> Control:
	var type := String(s["type"])
	var unit_id := String(s.get("unit", ""))
	var full := Units.full_size(unit_id) if Units.has(unit_id) else Troops.full_size(type)
	var men := int(s["men"])
	var level := int(s.get("level", 1))
	var xp := int(s["xp"])
	var panel := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	row.add_child(_portrait(unit_id if unit_id != "" else type, String(s.get("culture", GameState.culture))))
	var text := _text_column(row)
	var title := String(s.get("name", ""))
	var name_label := Style.label(title if title != "" else Units.troop_name(s, GameState.culture), Style.BODY)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.custom_minimum_size = Vector2(10, 0)
	text.add_child(name_label)
	var drill := "fully trained"
	if GameState.can_train(s):
		drill = "ready to train"
	elif level < Troops.MAX_LEVEL:
		drill = "%d/%d xp" % [xp, level * Troops.XP_PER_LEVEL]
	text.add_child(_small("%s · %d/%d men · level %d · %s" % [Units.troop_name(s, GameState.culture), men, full, level, drill],
		Style.TEXT if men >= full else Style.ENEMY_LIGHT))
	var refill := GameState.reinforce_cost(s)
	if refill > 0:
		var b := _button("Refill · %d" % refill, _on_reinforce.bind(int(s["id"])))
		b.disabled = refill > GameState.silver
		row.add_child(b)
	if GameState.can_train(s):
		# Training a recruit squad makes it one of two branches, each with its own price.
		var branches := Units.branches(unit_id)
		var choosing: bool = (level == 1 or bool(s.get("pending_branch", false))) and not branches.is_empty()
		var price: int = 0 if bool(s.get("pending_branch", false)) else Economy.train_cost(s)
		if choosing and not s.get("pending_branch", false):
			price = Economy.train_cost(s, branches[0])
			for b in branches:
				price = mini(price, Economy.train_cost(s, b))
		var label: String = "Train · free" if price == 0 else ("Train · from %d" if choosing else "Train · %d") % price
		var t := _button(label, _on_train.bind(int(s["id"])))
		t.disabled = price > GameState.silver
		row.add_child(t)
	return panel


# ---------------------------------------------------------------- pieces

func _section(text: String) -> Label:
	return Style.label(text.to_upper(), Style.SMALL, Style.MUTED)


func _note(text: String, color: Color = Style.MUTED) -> Label:
	var l := Style.label(text, Style.SMALL, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _small(text: String, color: Color = Style.MUTED) -> Label:
	var l := Style.label(text, Style.SMALL, color)
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.custom_minimum_size = Vector2(10, 0)
	return l


func _text_column(row: HBoxContainer) -> VBoxContainer:
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 2)
	row.add_child(text)
	return text


func _button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(160, Style.TOUCH)
	b.add_theme_font_size_override("font_size", Style.text_size(Style.SMALL))
	b.pressed.connect(callback)
	return b


## A unit portrait, scaled up with hard pixel edges, dressed as `culture` dresses it.
func _portrait(type: String, culture: String) -> TextureRect:
	var portrait := TextureRect.new()
	portrait.texture = Art.icon(type, 0, culture)
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2(64, 64)
	return portrait


# ---------------------------------------------------------------- actions

func _on_buy_food(rations: int) -> void:
	_paid(GameState.buy_food(rations))


func _on_hire(index: int) -> void:
	_paid(GameState.hire(place, index))


func _on_reinforce(id: int) -> void:
	_paid(GameState.reinforce_squad(id))


func _on_reinforce_all() -> void:
	_paid(GameState.reinforce() > 0)


var _modal: Control = null


func _on_train(id: int) -> void:
	var s := GameState.squad_by_id(id)
	if s.is_empty():
		return
	var branches := Units.branches(s.get("unit", ""))
	if (int(s.get("level", 1)) == 1 or s.get("pending_branch", false)) and not branches.is_empty():
		_show_branch_choice(id, branches)
	else:
		_paid(GameState.train_squad(id), "promotion")


func _show_branch_choice(id: int, branches: Array) -> void:
	if _modal != null:
		_modal.queue_free()
		_modal = null

	var squad := GameState.squad_by_id(id)
	if squad.is_empty():
		return

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.75)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	_modal = overlay

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 0)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	var heading := Style.label("Choose Upgrade Path", Style.LARGE)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(heading)

	var sub := Style.label("Select a veteran specialization for this squad:", Style.BODY, Style.MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	var cards_row := HBoxContainer.new()
	cards_row.add_theme_constant_override("separation", 12)
	box.add_child(cards_row)

	for b_id in branches:
		var u_info := Units.get_unit(b_id)
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var c_box := VBoxContainer.new()
		c_box.add_theme_constant_override("separation", 8)
		card.add_child(c_box)

		var b_portrait := _portrait(b_id, Units.culture(b_id))
		b_portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		c_box.add_child(b_portrait)

		var b_title := Style.label(Units.display_name(b_id), Style.BODY)
		b_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c_box.add_child(b_title)

		var b_blurb := Style.label(String(u_info.get("blurb", "")), Style.SMALL)
		b_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		c_box.add_child(b_blurb)

		var stats_desc := _format_unit_diff(b_id)
		if stats_desc != "":
			var diff_label := Style.label(stats_desc, Style.SMALL, Style.TEXT)
			diff_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			c_box.add_child(diff_label)

		var is_free: bool = squad.get("pending_branch", false)
		var price := 0 if is_free else Economy.train_cost(squad, b_id)
		var btn_text := "Select (Free)" if is_free else "Select · %d silver" % price
		var btn := _button(btn_text, func():
			overlay.queue_free()
			_modal = null
			_paid(GameState.train_squad(id, b_id), "promotion")
		)
		btn.disabled = price > GameState.silver
		c_box.add_child(btn)

		cards_row.add_child(card)

	var cancel_btn := _button("Cancel", func():
		overlay.queue_free()
		_modal = null
	)
	box.add_child(cancel_btn)


func _format_unit_diff(unit_id: String) -> String:
	var u := Units.get_unit(unit_id)
	var lines := []
	var mech: Dictionary = u.get("mechanics", {})
	if mech.has("armor"):
		lines.append("• Armor: %.0f%%" % [float(mech["armor"]) * 100.0])
	if mech.has("piercing"):
		lines.append("• Piercing: %.0f%%" % [float(mech["piercing"]) * 100.0])
	if mech.has("javelins"):
		lines.append("• Javelins: %d per man" % int(mech["javelins"]))
	if mech.get("sweep", false):
		lines.append("• Sweep: hits 2nd foe for 50%")
	if mech.get("steady", false):
		lines.append("• Steady: -20% morale loss")
	if mech.get("horse_archer", false):
		lines.append("• Horse Archer: shoots from saddle & kites")
	if mech.get("ronin", false):
		lines.append("• Ronin: enters fury if captain falls")
	var st: Dictionary = u.get("stats", {})
	if st.has("damage"):
		lines.append("• Damage: %.0f" % float(st["damage"]))
	if st.has("range"):
		lines.append("• Range: %.0f" % float(st["range"]))
	if st.has("speed"):
		lines.append("• Speed: %.0f" % float(st["speed"]))
	if st.has("size"):
		lines.append("• Squad size: %d men" % int(st["size"]))
	return "\n".join(lines)


## Silver changed hands, or didn't: the coins chink, and the screen shows the new state.
func _paid(done: bool, effect: String = "coins") -> void:
	if done:
		Sound.play(effect, 0.0, 0.08)
	_build()


func _remember_scroll() -> void:
	Scenes.settlement_place = place
	Scenes.settlement_scroll = _scroll.scroll_vertical if _scroll != null else 0


func _on_leave() -> void:
	GameState.save_game()
	Scenes.settlement_place = ""
	Scenes.settlement_scroll = 0
	Scenes.go("res://scenes/world_map.tscn")


## The smoke test: buy food, hire whoever's here, fill the ranks, then stop.
func _autoplay() -> void:
	var before := GameState.silver
	_on_buy_food(GameState.total_men() * FOOD_DAYS[0])
	if not GameState.world.offers_at(place).is_empty():
		_on_hire(0)
	_on_reinforce_all()
	print("autoplay: at %s spent %d silver; %d men in %d squads, food for %d days" % [
		place, before - GameState.silver, GameState.total_men(), GameState.army.size(), GameState.food_days()])
	get_tree().quit()
