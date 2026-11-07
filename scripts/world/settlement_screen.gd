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
const SettlementScene = preload("res://scripts/ui/settlement_scene.gd")
const CaptainArt = preload("res://scripts/ui/captain_art.gd")
const TravelPresentation = preload("res://scripts/world/travel_presentation.gd")
const Jobs = preload("res://scripts/data/jobs.gd")
const Fiefs = preload("res://scripts/data/fiefs.gd")
const Widgets = preload("res://scripts/ui/widgets.gd")
const Lords = preload("res://scripts/data/lords.gd")
const LordTalk = preload("res://scripts/world/lord_talk.gd")
const LordVoice = preload("res://scripts/data/lord_voice.gd")
const LordConversation = preload("res://scripts/world/lord_conversation.gd")
const Gatherings = preload("res://scripts/data/gatherings.gd")
const CrownCourt = preload("res://scripts/world/crown_court.gd")
const KingdomScreen = preload("res://scripts/world/kingdom_screen.gd")
const StoryArtHall = preload("res://scripts/ui/story_art.gd")
const CourtUI = preload("res://scripts/ui/court_ui.gd")

## The food you can buy in one go, in days for the whole warband.
const FOOD_DAYS := [3, 7]

var place := ""
var autoplay := false
var _scroll: ScrollContainer
var _arrival_overlay: Control
var _arrival_dismissing := false
var _info_sheet: Control
## What the money and food tiles showed last, so a change can count up to the new value.
var _shown_silver := -1
var _shown_food := -1
## The open tab, remembered per place for the session, so a conversation or a purchase
## brings you back where you were.
var tab := ""
static var _tab_by_place := {}
## What the last thing you did at the feast came to, shown at the top of the Court tab.
var _court_note := ""
## A lord talk open over the screen.
var _talk: Control = null
## Your own gathering as you plan it: the kind and who beyond your sworn lords to ask.
var _host_kind := 0
## The captains you'd send to the lists (squad ids); filled with your best three at first.
var _lists_pick: Array = []
## Whether the lists' bout-by-bout account is unfolded.
var _bouts_open := false
var _host_ask := {"friends": true, "persuade": true, "lieges": false}
## The improvement just built at your fief, so the rebuilt page can mark it once.
var _just_built := ""


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
	# Any sheet or confirmation open goes with the page.
	_modal = null

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

	var vista := SettlementVista.make(place, GameState.world, 320.0)
	vista.name = "LocationIllustration"
	col.add_child(vista)
	if _just_built != "":
		# The new building flashes into the scene and its dust rises; a knock of timber.
		vista.call_deferred("show_built", _just_built)
		Sound.play("ladders", -6.0)
	_add_header(col, vista if vista.visible else null)
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
	_just_built = ""
	if _arrival_overlay != null and is_instance_valid(_arrival_overlay):
		move_child(_arrival_overlay, get_child_count() - 1)
	_restore_scroll(keep)


## The name, what the place is, and two coloured chips: how well it's held and how safe
## its roads are. Everything else waits behind the info button.
## The name and what the place is, set on the scene when there is one (or above the
## chips when illustrations are off), and two coloured chips: how well it's held and how
## safe its roads are. Everything else waits behind the info button.
func _add_header(col: VBoxContainer, vista: Control = null) -> void:
	var w = GameState.world
	var title := Style.label(String(WorldData.settlement(place)["name"]), 64, Style.BRASS)
	title.name = "SettlementName"
	var kind := Style.label(w.brief(place), Style.BODY, Style.TEXT if vista != null else Style.MUTED)
	kind.name = "SettlementKind"
	if vista != null:
		vista.fade = true
		var pad := MarginContainer.new()
		pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for side in ["left", "right"]:
			pad.add_theme_constant_override("margin_" + side, 24)
		pad.add_theme_constant_override("margin_bottom", 14)
		vista.add_child(pad)
		# The holder's banner beside the name.
		var line := HBoxContainer.new()
		line.alignment = BoxContainer.ALIGNMENT_BEGIN
		line.size_flags_vertical = Control.SIZE_SHRINK_END
		line.add_theme_constant_override("separation", 16)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pad.add_child(line)
		var flag := Widgets.banner(String(w.owner_of(place)), Vector2(46, 62))
		flag.name = "SettlementBanner"
		flag.size_flags_vertical = Control.SIZE_SHRINK_END
		line.add_child(flag)
		var stack := VBoxContainer.new()
		stack.alignment = BoxContainer.ALIGNMENT_END
		stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stack.add_theme_constant_override("separation", 0)
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(stack)
		for label in [title, kind]:
			label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
			label.add_theme_constant_override("shadow_offset_x", 0)
			label.add_theme_constant_override("shadow_offset_y", 3)
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			stack.add_child(label)
	else:
		var title_row := HFlowContainer.new()
		title_row.add_theme_constant_override("h_separation", 16)
		col.add_child(title_row)
		title_row.add_child(title)
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
	if String(WorldData.settlement(place)["type"]) == WorldData.VILLAGE:
		# A village has no walls to man, only its militia and whatever you've left there.
		if GameState.is_player_fief(place):
			var stationed: int = w.men_of(w.garrison_at(place))
			var militia: int = w.men_of(w.village_militia(place))
			chips.add_child(_chip("Garrison %d men · %d militia" % [stationed, militia] if stationed > 0 else "%d militia, no garrison" % militia,
				Style.MORALE_HIGH if stationed > 0 else Style.MORALE_MID))
	elif w.garrisons.has(place):
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
	if vista != null:
		# In the scene's top corner, out of the way of the title.
		info.add_theme_stylebox_override("normal", Style.box(Color(Style.NIGHT, 0.8), Style.RULE, 2, 40))
		info.anchor_left = 1.0
		info.anchor_right = 1.0
		info.offset_left = -82
		info.offset_right = -18
		info.offset_top = 18
		info.offset_bottom = 82
		vista.add_child(info)
	else:
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
	# A shape as well as a colour, so the good, middling and bad read without colour.
	var shape := "▲" if tone == Style.MORALE_HIGH else ("◆" if tone == Style.MORALE_MID else "▼")
	h.add_child(Style.label(shape, Style.SMALL, tone))
	h.add_child(Style.label(text, Style.SMALL, Style.TEXT))
	return chip


## Silver with what the company costs a day, and food in days, as two tiles.
func _add_wallet(col: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.name = "Wallet"
	row.add_theme_constant_override("separation", 14)
	col.add_child(row)
	var days := GameState.food_days()
	var silver_tile := Widgets.tile("silver", Widgets.thousands(GameState.silver), "−%d a day" % GameState.daily_wages())
	var food_tile := Widgets.tile("food", "1 day" if days == 1 else "%d days" % days, "of food",
		Style.ENEMY_LIGHT if days < 3 else Style.TEXT)
	row.add_child(silver_tile)
	row.add_child(food_tile)
	# After a purchase the numbers count to their new values, and flash.
	if _shown_silver >= 0 and _shown_silver != GameState.silver:
		Widgets.tick_to(silver_tile.find_child("Value", true, false), _shown_silver, GameState.silver, func(v): return Widgets.thousands(v))
	if _shown_food >= 0 and _shown_food != days:
		Widgets.tick_to(food_tile.find_child("Value", true, false), _shown_food, days, func(v): return "1 day" if v == 1 else "%d days" % v)
	_shown_silver = GameState.silver
	_shown_food = days


## One thing at a time: what's for sale, the company, paid work, the court, and your own
## fief when this is it. Only tabs with something in them are shown.
func _add_tabs(col: VBoxContainer, owner: String) -> void:
	var w = GameState.world
	var tabs: Array = []
	if GameState.is_player_fief(place):
		tabs.append({"id": "fief", "label": "Fief", "badge": 0})
	elif GameState.is_crowned() and GameState.crown_fiefs().has(place):
		tabs.append({"id": "crown", "label": "Crown", "badge": 0})
	var offers: int = 0 if GameState.army.size() >= GameState.squad_cap() else w.offers_at(place).size()
	tabs.append({"id": "buy", "label": "Buy", "badge": offers + GameState.available_heroes_at(place).size()})
	tabs.append({"id": "squads", "label": "Squads", "badge": 0})
	tabs.append({"id": "work", "label": "Work", "badge": GameState.active_jobs_completable_at(place).size()})
	if _has_court():
		tabs.append(_court_tab())
	var ids: Array = tabs.map(func(t): return t["id"])
	var current := String(_tab_by_place.get(place, ""))
	if not ids.has(current):
		current = "fief" if ids.has("fief") else ("crown" if ids.has("crown") else "buy")
	tab = current

	col.add_child(Widgets.tab_bar(tabs, tab, _on_tab, "SettlementTabs"))

	var body := VBoxContainer.new()
	body.name = "TabBody"
	body.add_theme_constant_override("separation", 16)
	col.add_child(body)
	match tab:
		"fief":
			if GameState.is_crowned() and GameState.host_places().has(place):
				_add_host_card(body)
			_add_fief_management(body)
		"crown":
			_add_host_card(body)
			_add_crown_holding(body)
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
	var g: Dictionary = GameState.world.gathering_at(place)
	if not g.is_empty():
		var feast := _note("%s is held behind the walls, but no enemy is seated at it. Make peace, or take the place, to sit at a feast here." % Gatherings.upper_first(GameState.gathering_title(g)), Style.MUTED)
		feast.name = "FeastBarred"
		card.add_child(feast)


func _add_contract(col: VBoxContainer, owner: String) -> void:
	var kind: String = WorldData.settlement(place)["type"]
	if not kind in [WorldData.CASTLE, WorldData.TOWN]:
		return

	var faction_name: String = WorldData.FACTIONS[owner]["name"]

	if GameState.has_fief():
		col.add_child(_section("Fealty & Lordship"))
		if GameState.fief_realm() == owner:
			col.add_child(_note("Sworn vassal of %s · Lord of %s" % [WorldData.the_realm(faction_name), WorldData.settlement(GameState.fief_id())["name"]], Style.BRASS))
		else:
			var other_name: String = WorldData.FACTIONS[GameState.fief_realm()]["name"]
			col.add_child(_note("Your company is already sworn in fealty to %s." % WorldData.the_realm(other_name), Style.MUTED))
		return

	if GameState.can_petition_fief(owner):
		col.add_child(_section("Fealty & Fiefdom"))
		col.add_child(_note("The crown recognizes your valor and standing (%d renown, %d relation). You may swear fealty as a vassal of %s and receive governance of a fief." % [
			GameState.renown, GameState.relation_with_realm(owner), WorldData.the_realm(faction_name)
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


## A castle or town of your crown that isn't your seat: who holds it for you, its
## garrison, and your squads standing with it.
func _add_crown_holding(col: VBoxContainer) -> void:
	var w = GameState.world
	var s_name := String(WorldData.settlement(place)["name"])
	col.add_child(_section("%s of %s" % [String(WorldData.settlement(place)["type"]).capitalize(), GameState.crown_title()]))
	var holder: Dictionary = GameState.holder_of(place)
	col.add_child(_note("Held for you by %s." % holder["name"] if not holder.is_empty() else "No lord holds it for you. Grant it to one of your sworn lords.", Style.TEXT))
	var income := int(Lords.INCOME.get(String(WorldData.settlement(place)["type"]), 0))
	col.add_child(_note("Pays %d silver a day: half to your purse, half to the crown treasury (%d), which raises its garrison." % [income, GameState.crown_treasury()]))
	# Grant it.
	var lords: Array = GameState.crown_lords().filter(func(l): return String(l.get("fief", "")) != place)
	if not lords.is_empty():
		col.add_child(_section("Grant %s" % s_name))
		for l in lords:
			var lid := int(l["id"])
			var holds := String(l.get("fief", ""))
			var b := _button("Grant to %s%s" % [l["name"], (" (holds %s)" % WorldData.settlement(holds)["name"]) if holds != "" else ""], func():
				if GameState.grant_fief(place, lid):
					Sound.play("horn")
					_build())
			b.name = "Grant_%d" % lid
			col.add_child(b)
	if not holder.is_empty():
		var hid := int(holder["id"])
		var r := _button("Take it back from %s (%d Regard)" % [holder["name"], GameState.REVOKE_REGARD], func():
			if GameState.revoke_fief(hid):
				_build())
		r.name = "Revoke"
		col.add_child(r)
	# Its garrison, and your squads in it.
	col.add_child(_section("Garrison"))
	col.add_child(_note("%d of %d men." % [w.men_of(w.garrison_at(place)), w.garrison_capacity(place)], Style.TEXT))
	for sq in GameState.stationed_at(place):
		var sid := int(sq["id"])
		var b := _button("Take back %s (%d men)" % [String(sq.get("name", "squad")), int(sq["men"])], func():
			if GameState.withdraw_from_holding(sid):
				_build())
		b.name = "Withdraw_%d" % sid
		col.add_child(b)
	if GameState.army.size() > 1:
		col.add_child(_note("Station a squad of yours with the garrison:"))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 8)
		flow.add_theme_constant_override("v_separation", 8)
		for sq in GameState.army:
			var sid := int(sq["id"])
			var b := Button.new()
			b.name = "Station_%d" % sid
			b.text = "Station %s" % String(sq.get("name", "squad"))
			b.pressed.connect(func():
				if GameState.station_in_holding(sid):
					Sound.play("click")
					_build())
			flow.add_child(b)
		col.add_child(flow)


## Your own fief: what it stores, the squads you've left there, and what you've built.
func _add_fief_management(col: VBoxContainer) -> void:
	var fief: Dictionary = GameState.player_fief
	var is_b: bool = GameState.world != null and GameState.world.is_burned(place)
	_add_estate_card(col, fief, is_b)
	_add_garrison_card(col, fief)
	_add_manor_card(col, fief, is_b)
	# A vassal can give up their fief; a ruler has no one to give it to.
	if not GameState.is_crowned():
		var ren := Button.new()
		ren.name = "RenounceFealty"
		ren.text = "Renounce fealty…"
		ren.flat = true
		ren.focus_mode = Control.FOCUS_ALL
		ren.custom_minimum_size = Vector2(0, Style.TOUCH)
		ren.add_theme_font_size_override("font_size", Style.text_size(Style.SMALL))
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			ren.add_theme_color_override(c, Style.MUTED)
		ren.pressed.connect(_confirm_renounce)
		col.add_child(ren)


func _fief_culture() -> String:
	return WorldData.culture_of(String(WorldData.settlement(place)["faction"]))


## The lord's title, how long they've held it, and the two stores the place fills each day.
func _add_estate_card(col: VBoxContainer, fief: Dictionary, is_b: bool) -> void:
	var title: String = Fiefs.title_for(_fief_culture())
	var s_name := String(WorldData.settlement(place)["name"])
	var held := ""
	if GameState.world != null:
		var days := int((float(GameState.world.hour) - float(fief.get("granted_at", 0.0))) / 24.0) + 1
		held = "day %d as its %s" % [days, title.to_lower()]
	var card := _card(col, "Your estate", held)
	card.get_parent().name = "EstateCard"
	var name_label := Style.label("%s of %s" % [title, s_name], Style.TITLE_SIZE, Style.BRASS)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(name_label)
	if GameState.is_crowned() and String(fief.get("realm", "")) == WorldData.CROWN:
		card.add_child(_note("Seat of your crown · ruler of %s" % GameState.crown_title(), Style.TEXT))
	else:
		var r_name := String(WorldData.FACTIONS.get(String(fief.get("realm", "")), {}).get("name", "Realm"))
		card.add_child(_note("Sworn vassal of %s · seat of your company" % WorldData.the_realm(r_name), Style.TEXT))
	if is_b:
		card.add_child(Widgets.chip_row([Widgets.chip("Raided · taxes and grain crippled until rebuilt", Style.MORALE_LOW)]))

	var silver: int = int(fief.get("silver", 0))
	var food: int = int(fief.get("food", 0))
	var tiles := HBoxContainer.new()
	tiles.add_theme_constant_override("separation", 12)
	card.add_child(tiles)
	tiles.add_child(_store_tile("TreasuryTile", silver, Fiefs.MAX_STORAGE_SILVER, "silver",
		"+%d a day in taxes" % Fiefs.daily_tax(fief, is_b), "Treasury full · taxes are being lost"))
	tiles.add_child(_store_tile("GranaryTile", food, Fiefs.max_food_capacity(fief), "rations",
		"+%d a day" % Fiefs.daily_food(fief, is_b), "Granary full · grain is going to waste"))

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	card.add_child(buttons)
	var collect := _button("Collect %s silver" % Widgets.thousands(silver) if silver > 0 else "Collect taxes", func():
		if GameState.collect_fief_taxes() > 0:
			Sound.play("coins")
			_build())
	collect.name = "CollectTaxes"
	collect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	collect.disabled = silver <= 0
	if silver > 0:
		Style.make_primary(collect)
	buttons.add_child(collect)
	var take := _button("Take %d rations" % food if food > 0 else "Take food", func():
		if GameState.collect_fief_food() > 0:
			Sound.play("coins")
			_build())
	take.name = "TakeFood"
	take.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	take.disabled = food <= 0
	buttons.add_child(take)


## A store: what's in it against what it holds, what it gains a day, and a meter that
## turns red when it's full, since the rules waste what won't fit.
func _store_tile(tile_name: String, have: int, cap: int, unit: String, gain: String, full_text: String) -> PanelContainer:
	var t := PanelContainer.new()
	t.name = tile_name
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := Style.box(Style.NIGHT, Style.RULE, 2, 14)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	t.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	t.add_child(v)
	var line := HFlowContainer.new()
	line.add_theme_constant_override("h_separation", 8)
	v.add_child(line)
	var big := Style.label(Widgets.thousands(have), Style.LARGE, Style.TEXT)
	big.name = "Value"
	line.add_child(big)
	var of := Style.label("of %s %s" % [Widgets.thousands(cap), unit], Style.SMALL, Style.MUTED)
	of.size_flags_vertical = Control.SIZE_SHRINK_END
	line.add_child(of)
	var full := have >= cap
	v.add_child(_note(full_text if full else gain, Style.ENEMY_LIGHT if full else Style.MUTED))
	v.add_child(Widgets.meter(float(have) / maxf(1.0, float(cap)), Style.MORALE_LOW if full else Style.BRASS, 12.0))
	return t


## The squads you've left here, how to leave another, and what the place holds out with.
func _add_garrison_card(col: VBoxContainer, fief: Dictionary) -> void:
	var w = GameState.world
	var garrison: Array = fief.get("garrison", [])
	var men := 0
	for sq in garrison:
		men += int(sq["men"])
	var aside := "" if garrison.is_empty() else "%d squad%s · %d men" % [garrison.size(), "" if garrison.size() == 1 else "s", men]
	var card := _card(col, "Garrison", aside)
	card.get_parent().name = "GarrisonCard"
	var village := String(WorldData.settlement(place)["type"]) == WorldData.VILLAGE
	var militia: int = w.men_of(w.village_militia(place)) if village and w != null else 0
	var full: bool = GameState.army.size() >= GameState.squad_cap()
	if garrison.is_empty():
		card.add_child(_note("No squads stationed. The village has only its %d militia." % militia if village else "No squads of yours are stationed here."))
	for i in garrison.size():
		var index := i
		var sq: Dictionary = garrison[i]
		var wounded := int(sq.get("wounded", 0))
		var take_back := func():
			if GameState.withdraw_squad_from_fief(index):
				Sound.play("click")
				_build()
		card.add_child(_squad_line(sq, "▼ %d wounded · one heals each day" % wounded if wounded > 0 else "",
			"Take back", not full, "Withdraw_%d" % int(sq["id"]), take_back))
	if full and not garrison.is_empty():
		card.add_child(_note("Your warband is full, %d of %d squads. Station one to make room." % [GameState.army.size(), GameState.squad_cap()]))
	if GameState.army.size() > 1:
		var open := _button("Station a squad here…", _show_station_sheet)
		open.name = "StationSquad"
		card.add_child(open)
	else:
		card.add_child(_note("Your only squad can't stay behind."))
	if village:
		var parts := PackedStringArray(["%d militia" % militia])
		if men > 0:
			parts.append("%d stationed men" % men)
		var forts := bool(fief.get("improvements", {}).get(Fiefs.IMPROVEMENT_FORTIFICATIONS, false))
		if forts:
			parts.append("the palisade's %d" % int(Fiefs.IMPROVEMENTS[Fiefs.IMPROVEMENT_FORTIFICATIONS]["militia_bonus"]))
		var joined := parts[0] if parts.size() == 1 else ", ".join(parts.slice(0, parts.size() - 1)) + " and " + parts[parts.size() - 1]
		card.add_child(_note("Holds against raiders with %s%s. Stationed men heal one wound a day." % [joined, ", a third stronger behind the stakes" if forts else ""]))
	else:
		card.add_child(_note("Stationed men hold the walls and heal one wound a day."))


## A squad as a row: the captain's face with the troop's badge, its name, who leads it and
## how many, a line about its wounds, and one button.
func _squad_line(sq: Dictionary, wounds: String, verb: String, can: bool, button_name: String, act: Callable, primary: bool = false) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(_squad_art(sq))
	var text := _text_column(row)
	var title := String(sq.get("name", ""))
	var name_label := Style.label(title if title != "" else Units.troop_name(sq, GameState.culture), Style.BODY)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.custom_minimum_size = Vector2(10, 0)
	text.add_child(name_label)
	var unit_id := String(sq.get("unit", ""))
	var full_size: int = Units.full_size(unit_id) if Units.has(unit_id) else Troops.full_size(String(sq["type"]))
	var c = sq.get("captain")
	var who := String(c.get("name", "")) if c is Dictionary else ""
	var bits := PackedStringArray()
	if who != "":
		bits.append(who)
	bits.append("%d of %d men" % [int(sq["men"]), full_size])
	bits.append(Units.troop_name(sq, GameState.culture))
	text.add_child(_small(" · ".join(bits), Style.TEXT))
	text.add_child(_small(wounds if wounds != "" else "Whole", Style.ENEMY_LIGHT if wounds != "" else Style.MUTED))
	var b := _button(verb, act)
	b.name = button_name
	b.custom_minimum_size = Vector2(150, Style.TOUCH)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.disabled = not can
	if primary and can:
		Style.make_primary(b)
	row.add_child(b)
	return row


## A squad's face: its captain's, with the troop's own icon at the corner, or the troop alone.
func _squad_art(s: Dictionary) -> Control:
	var type := String(s["type"])
	var unit_id := String(s.get("unit", ""))
	var art := Control.new()
	art.custom_minimum_size = Vector2(72, 84)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var face_tex: Texture2D = CaptainArt.texture(s["captain"]) if s.get("captain") != null else null
	if face_tex != null:
		var face := TextureRect.new()
		face.name = "SquadCaptain"
		face.texture = face_tex
		face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.add_child(face)
		var badge := _portrait(unit_id if unit_id != "" else type, String(s.get("culture", GameState.culture)))
		badge.custom_minimum_size = Vector2(34, 34)
		badge.size = Vector2(34, 34)
		badge.position = Vector2(44, 52)
		art.add_child(badge)
	else:
		var icon := _portrait(unit_id if unit_id != "" else type, String(s.get("culture", GameState.culture)))
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.add_child(icon)
	return art


## The warband, wounded first, to choose a squad to leave here. Slides up from the bottom
## like the place's info sheet, and leaves the page where it was.
func _show_station_sheet() -> void:
	if _modal != null and is_instance_valid(_modal):
		_modal.queue_free()
	var s_name := String(WorldData.settlement(place)["name"])
	var shade := ColorRect.new()
	shade.name = "StationSheet"
	shade.color = Color(0.012, 0.02, 0.04, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	_modal = shade
	var close := func():
		if is_instance_valid(shade):
			shade.queue_free()
		_modal = null
	shade.gui_input.connect(func(e):
		if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed:
			close.call())
	var panel := PanelContainer.new()
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
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var grip := Panel.new()
	grip.custom_minimum_size = Vector2(80, 8)
	grip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grip.add_theme_stylebox_override("panel", Style.box(Style.RULE, Color(0, 0, 0, 0), 0, 4))
	v.add_child(grip)
	v.add_child(Style.label("Station a squad", Style.TITLE_SIZE, Style.BRASS))
	v.add_child(_note("It stays at %s, heals a wound a day and holds the place. At least one squad must ride with you." % s_name))
	var squads: Array = GameState.army.duplicate()
	squads.sort_custom(func(a, b): return int(a.get("wounded", 0)) > int(b.get("wounded", 0)))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, minf(squads.size() * 100.0, get_viewport_rect().size.y * 0.55))
	v.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	for sq in squads:
		var sid := int(sq["id"])
		var wounded := int(sq.get("wounded", 0))
		var station := func():
			close.call()
			if GameState.station_squad_in_fief(sid):
				Sound.play("click")
				_build()
		var wounds := "▼ %d wounded · whole in %d day%s here" % [wounded, wounded, "" if wounded == 1 else "s"] if wounded > 0 else ""
		list.add_child(_squad_line(sq, wounds, "Station", GameState.army.size() > 1, "Station_%d" % sid, station, wounded > 0))
	var done := _button("Close", close)
	done.name = "CloseStationSheet"
	v.add_child(done)
	Style.ease_in(panel)


## What you've built and could build, each with its picture: the building as the scene at
## the top paints it, in colour once it's built and a grey ghost before.
func _add_manor_card(col: VBoxContainer, fief: Dictionary, is_b: bool) -> void:
	var imps: Dictionary = fief.get("improvements", {})
	var count := 0
	for k in Fiefs.IMPROVEMENT_ORDER:
		if bool(imps.get(k, false)):
			count += 1
	var card := _card(col, "Manor", "%d of %d built" % [count, Fiefs.IMPROVEMENT_ORDER.size()])
	card.get_parent().name = "ManorCard"
	if is_b:
		var rep_row := HBoxContainer.new()
		rep_row.add_theme_constant_override("separation", 12)
		card.add_child(rep_row)
		var rep_text := _note("Raiders burned it. Rebuild the cottages and the peasants' granaries.", Style.ENEMY_LIGHT)
		rep_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rep_row.add_child(rep_text)
		var rep_btn := _button("Rebuild · %d silver" % Fiefs.REPAIR_COST, func():
			if GameState.repair_fief().get("ok", false):
				Sound.play("coins")
				_build())
		rep_btn.name = "RebuildEstate"
		rep_btn.disabled = GameState.silver < Fiefs.REPAIR_COST
		if not rep_btn.disabled:
			Style.make_primary(rep_btn)
		rep_row.add_child(rep_btn)
	for k in Fiefs.IMPROVEMENT_ORDER:
		card.add_child(_improvement_row(String(k), bool(imps.get(k, false))))


func _improvement_row(key: String, built: bool) -> Control:
	var idef: Dictionary = Fiefs.IMPROVEMENTS[key]
	var panel := PanelContainer.new()
	panel.name = "Improvement_%s" % key
	var sb := Style.box(Color(Style.BRASS, 0.07) if built else Color(0, 0, 0, 0), Style.BRASS if built else Color(0, 0, 0, 0), 0, 8)
	if built:
		sb.border_width_left = 4
	sb.content_margin_left = 12
	sb.content_margin_right = 4
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)

	var frame := PanelContainer.new()
	var fb := Style.box(SettlementScene.PLATE_BG, Style.RULE, 2, 8)
	fb.set_content_margin_all(2)
	frame.add_theme_stylebox_override("panel", fb)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pic := TextureRect.new()
	pic.name = "Plate"
	pic.texture = ImageTexture.create_from_image(SettlementScene.plate(_fief_culture(), key, built))
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_SCALE
	pic.custom_minimum_size = Vector2(SettlementScene.PLATE_W * 3, SettlementScene.PLATE_H * 3)
	frame.add_child(pic)
	row.add_child(frame)
	if key == _just_built and not Style.motion_reduced():
		pic.modulate.a = 0.25
		pic.create_tween().tween_property(pic, "modulate:a", 1.0, 0.5)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 4)
	row.add_child(text)
	var head := HFlowContainer.new()
	head.add_theme_constant_override("h_separation", 10)
	text.add_child(head)
	head.add_child(Style.label(String(idef["name"]), Style.BODY, Style.TEXT))
	if built:
		var chip := Widgets.chip("Built", Style.BRASS, "★")
		chip.name = "BuiltChip"
		head.add_child(chip)
	for effect in idef.get("effects", []):
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		var mark := Style.label("▲", Style.SMALL, Style.MORALE_HIGH)
		mark.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		line.add_child(mark)
		var words := _note(String(effect), Style.TEXT if built else Style.MUTED)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(words)
		text.add_child(line)
	if key == Fiefs.IMPROVEMENT_FORTIFICATIONS and String(WorldData.settlement(place)["type"]) != WorldData.VILLAGE:
		text.add_child(_note("Raiders strike villages, not castles."))
	if built:
		return panel
	var cost := int(idef["cost"])
	if GameState.silver < cost:
		text.add_child(_note("Need %s more silver" % Widgets.thousands(cost - GameState.silver), Style.ENEMY_LIGHT))
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)
	stack.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(stack)
	var b := _button("Build", func():
		if GameState.build_fief_improvement(key).get("ok", false):
			Sound.play("coins")
			_just_built = key
			_build())
	b.name = "Build_%s" % key
	b.custom_minimum_size = Vector2(140, Style.TOUCH)
	b.disabled = GameState.silver < cost
	if not b.disabled:
		Style.make_primary(b)
	stack.add_child(b)
	var price := Style.label("%s silver" % Widgets.thousands(cost), Style.SMALL, Style.MUTED)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(price)
	return panel


## Giving up the fief is for good, so it asks first.
func _confirm_renounce() -> void:
	if _modal != null and is_instance_valid(_modal):
		_modal.queue_free()
	var s_name := String(WorldData.settlement(place)["name"])
	var r_name := String(WorldData.FACTIONS.get(GameState.fief_realm(), {}).get("name", "your liege"))
	var overlay := ColorRect.new()
	overlay.name = "RenounceConfirm"
	overlay.color = Color(0, 0, 0, 0.75)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	_modal = overlay
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(minf(560.0, get_viewport_rect().size.x - 64.0), 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	box.add_child(Style.label("Renounce fealty?", Style.LARGE, Style.TEXT))
	box.add_child(_note("You give %s back to the crown and lose 25 relation with %s. It can't be undone." % [s_name, WorldData.the_realm(r_name)], Style.TEXT))
	var yes := _button("Renounce %s" % s_name, func():
		overlay.queue_free()
		_modal = null
		GameState.renounce_fief()
		Sound.play("alarm")
		_build())
	yes.name = "ConfirmRenounce"
	yes.add_theme_stylebox_override("normal", Style.box(Style.ENEMY_DARK, Style.ENEMY, 2))
	yes.add_theme_stylebox_override("hover", Style.box(Style.ENEMY_DARK.lightened(0.08), Style.ENEMY_LIGHT, 2))
	box.add_child(yes)
	var no := _button("Keep it", func():
		overlay.queue_free()
		_modal = null)
	no.name = "KeepFief"
	box.add_child(no)
	Style.ease_in(panel, Vector2(0.5, 0.5))


## Whether the place has a hall worth a tab: every town and castle, and anywhere someone
## lives that you'd visit.
func _has_court() -> bool:
	var w = GameState.world
	if not WorldData.is_village(place):
		return true
	if w.social != null and not w.social.residents_at(place).is_empty():
		return true
	return GameState.wedding_can_begin() and String(GameState.wedding()["place"]) == place


## "Court · 3", or "Feast · 6" in brass while a gathering is on.
func _court_tab() -> Dictionary:
	var w = GameState.world
	var g: Dictionary = w.gathering_at(place)
	var count: int = w.lords_at(place).size() + (w.social.residents_at(place).size() if w.social != null else 0)
	var label := "Court"
	if w.gathering_on(g):
		label = {Gatherings.DANCE: "Dance", Gatherings.TOURNEY: "Tourney"}.get(String(g["kind"]), "Feast")
	return {"id": "court", "label": "%s · %d" % [label, count] if count > 0 else label, "badge": 0, "gold": w.gathering_on(g)}


## The hall: during a gathering the feast and what you can do there; then who's in the
## hall (lords stopped here, the household), who's away, and the next gathering.
func _add_court(col: VBoxContainer) -> void:
	var w = GameState.world
	if w == null:
		return
	var residents: Array = w.social.residents_at(place) if w.social != null else []
	var wedding_here: bool = GameState.wedding_can_begin() and String(GameState.wedding()["place"]) == place
	if wedding_here:
		var who := String(w.social.get_candidate_person(String(GameState.wedding()["candidate_id"])).get("name", ""))
		col.add_child(_note("%s · Wedding day · everything is ready" % who, Style.BRASS))
		var wb := _button("Begin your wedding", func():
			_remember_scroll()
			Scenes.wedding_replay = ""
			Scenes.wedding_return = "res://scenes/settlement.tscn"
			Scenes.go("res://scenes/wedding.tscn"))
		wb.name = "BeginWedding"
		col.add_child(wb)
	if not GameState.muster.is_empty() and String(GameState.muster["place"]) == place:
		_add_muster_card(col)
	var g: Dictionary = w.gathering_at(place)
	var on: bool = w.gathering_on(g)
	if not g.is_empty():
		_add_gathering_card(col, g)
	if _court_note != "":
		var n := _note(_court_note, Style.BRASS)
		n.name = "CourtNote"
		col.add_child(n)
	var here: Array = GameState.gathering_lords(g) if on else _hall_lords()
	var head := HBoxContainer.new()
	var t := _section("In the hall")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(_small(str(here.size() + residents.size())))
	col.add_child(head)
	var list := VBoxContainer.new()
	list.name = "Hall"
	list.add_theme_constant_override("separation", 10)
	col.add_child(list)
	for l in here:
		list.add_child(_lord_row(l, g if on else {}))
	for person in residents:
		list.add_child(_household_row(person))
	if here.is_empty() and residents.is_empty():
		list.add_child(_note("The hall is quiet. A steward keeps the fire; the lords are out on the roads."))
	# Who's away: the holder, out on their lands.
	var holder: Dictionary = w.holder_lord(place)
	if not holder.is_empty() and not here.has(holder):
		col.add_child(_section("Away"))
		col.add_child(_away_row(holder))
	# The next gathering, if it's somewhere else.
	if g.is_empty():
		var next := _next_gathering()
		if not next.is_empty():
			col.add_child(_note("The next gathering: %s at %s, %s." % [GameState.gathering_title(next),
				WorldData.settlement(String(next["place"]))["name"], GameState.gathering_when(next)]))


## The lords in the hall on an ordinary day, the holder first.
func _hall_lords() -> Array:
	var w = GameState.world
	var here: Array = w.lords_at(place)
	var holder: Dictionary = w.holder_lord(place)
	var hid := int(holder.get("id", -1))
	here.sort_custom(func(a, b): return int(int(a["id"]) == hid) > int(int(b["id"]) == hid))
	return here


## A gathering you're invited to or that's in this realm, elsewhere.
func _next_gathering() -> Dictionary:
	var w = GameState.world
	var owner: String = w.owner_of(place)
	for g in w.gatherings:
		if String(g["place"]) != place and (String(g["realm"]) == owner or bool(GameState.gathering_invite(g)["invited"])):
			return g
	return {}


## The feast: whose, which night, how many, whether you're invited, and what you can do.
func _add_gathering_card(col: VBoxContainer, g: Dictionary) -> void:
	var w = GameState.world
	var on: bool = w.gathering_on(g)
	var panel := PanelContainer.new()
	panel.name = "Gathering"
	var sb := Style.box(Color("33290f"), Style.BRASS, 2, 18)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 16
	sb.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", sb)
	col.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	var icon := Widgets.icon_rect("lantern", 34)
	icon.modulate = Style.BRASS
	top.add_child(icon)
	var title := Style.label(GameState.gathering_title(g), Style.BODY, Color("f3d891"))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	v.add_child(top)
	var inv: Dictionary = GameState.gathering_invite(g)
	var lords_n: int = GameState.gathering_lords(g).size() if on else w.gathering_guests(g).size()
	var line := "%s · %d lord%s %s · %s" % [Gatherings.upper_first(GameState.gathering_when(g)), lords_n, "" if lords_n == 1 else "s",
		"here" if on else "coming", ("you're invited: %s" % inv["why"]) if bool(inv["invited"]) else "you came uninvited"]
	var mine: bool = GameState.gathering_is_mine(g)
	if mine:
		top.add_child(CourtUI.round_button("?", func(): CourtUI.open_rules(self, Style.safe_insets(get_viewport())), "Rules"))
	if mine:
		var host_l: Dictionary = w.lord_by_id(int(g.get("host_lord", -1))) if int(g.get("host_lord", -1)) >= 0 else {}
		line = "%s · %d lord%s %s · your own%s" % [Gatherings.upper_first(GameState.gathering_when(g)), lords_n, "" if lords_n == 1 else "s", "here" if on else "coming",
			(", in %s's hall" % LordTalk.short_name(host_l)) if not host_l.is_empty() else ""]
	var sub := _note(line, Color("e8d9b0"))
	v.add_child(sub)
	if not on:
		v.add_child(_note("The hall is being made ready. Come back when it begins.", Style.MUTED))
		return
	if not mine:
		var said := Style.label(String(Gatherings.HALL.get(String(g.get("culture", "")), "")), Style.SMALL, Style.MUTED)
		said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(said)
	var acts := HBoxContainer.new()
	acts.name = "Actions"
	acts.add_theme_constant_override("separation", 8)
	v.add_child(acts)
	if mine:
		var sp: Dictionary = CrownCourt.speech_check(GameState)
		acts.add_child(_feast_action("Speech", "Speech", "renown %d" % Gatherings.SPEECH_RENOWN if bool(sp["ok"]) else String(sp["reason"]),
			bool(sp["ok"]), func():
				var r: Dictionary = CrownCourt.speech(GameState)
				if bool(r.get("ok", false)):
					Sound.play("horn")
					_court_note = String(r["text"])
				_build()))
		var gc: Dictionary = CrownCourt.gifts_check(GameState)
		acts.add_child(_feast_action("KingGifts", "Gifts", ("%d silver" % int(gc["cost"])) if bool(gc["ok"]) else String(gc["reason"]),
			bool(gc["ok"]), func():
				var r: Dictionary = CrownCourt.give_gifts(GameState)
				if bool(r.get("ok", false)):
					Sound.play("coins")
					_court_note = String(r["text"])
				_build()))
	else:
		var toast: Dictionary = GameState.toast_check(g)
		acts.add_child(_feast_action("Toast", "Raise a toast", "once · renown %d" % Gatherings.TOAST_RENOWN if bool(toast["ok"]) else String(toast["reason"]),
			bool(toast["ok"]), func():
				var r: Dictionary = GameState.raise_toast(g)
				if bool(r.get("ok", false)):
					Sound.play("horn")
					_court_note = "%s +%d Regard with %d lord%s." % [String(r["text"]), Gatherings.TOAST_REGARD, int(r["lords"]), "" if int(r["lords"]) == 1 else "s"]
				_build()))
	var gift: Dictionary = GameState.gift_check(g)
	var gift_sub := String(gift["reason"])
	if bool(gift["ok"]):
		gift_sub = "%d %s · host +%d" % [Gatherings.GIFT_SILVER if String(gift["what"]) == "silver" else Gatherings.GIFT_FOOD,
			"silver" if String(gift["what"]) == "silver" else "rations", Gatherings.GIFT_REGARD]
	if not mine:
		acts.add_child(_feast_action("Gift", "Bring a gift", gift_sub, bool(gift["ok"]), func():
			var r: Dictionary = GameState.bring_gift(g)
			if bool(r.get("ok", false)):
				Sound.play("coins")
				_court_note = "%s %s +%d Regard; %s +%d." % [String(r["text"]), GameState.gathering_host_name(g), Gatherings.GIFT_REGARD,
					GameState.realm_word(String(g["realm"])), Gatherings.GIFT_REALM]
			_build()))
	var gossip: Dictionary = GameState.gossip_check(g)
	acts.add_child(_feast_action("Gossip", "Gossip" if mine else "Hear the gossip", ("an hour" if mine else "an hour · once a night") if bool(gossip["ok"]) else String(gossip["reason"]),
		bool(gossip["ok"]), func():
			var r: Dictionary = GameState.hear_gossip(g)
			if bool(r.get("ok", false)):
				Sound.play("page")
				_court_note = "Gossip: %s" % String(r["text"])
			_build()))
	if mine and GameState.gathering_here() == g:
		_add_kings_table(v, g)
	var dance: Dictionary = GameState.dance_check(g)
	if bool(dance["ok"]):
		var db := _button("Ask someone to dance", func():
			_remember_scroll()
			Scenes.dance_return = "res://scenes/settlement.tscn"
			Scenes.go("res://scenes/dance.tscn"))
		db.name = "Dance"
		Style.make_primary(db)
		v.add_child(db)
	elif String(dance["reason"]) != "it hasn't begun":
		v.add_child(_note("Dancing: %s." % String(dance["reason"]), Style.MUTED))


## One of the feast's three things to do: a tall button with what it costs or why not.
func _feast_action(id: String, text: String, sub: String, ok: bool, act: Callable) -> Button:
	var b := Button.new()
	b.name = "Feast_" + id
	b.disabled = not ok
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 96)
	var box := Style.box(Color("2a2010") if ok else Color(Style.NIGHT, 0.5), Color("8a6a2a") if ok else Style.RULE, 2, 14)
	box.content_margin_left = 8
	box.content_margin_right = 8
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(state, box)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 2)
	var t := Style.label(text, Style.SMALL, Style.TEXT if ok else Style.MUTED)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(t)
	var st := Style.label(sub, Style.SMALL - 4, Color("cdbf9c") if ok else Style.MUTED)
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	st.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(st)
	b.add_child(v)
	b.pressed.connect(act)
	return b


## Your crown's own gathering here: a feast, a dance or a tourney, and who to ask. (The
## Crown screen's Court tab calls one anywhere.) What it's worth is on the rules sheet.
func _add_host_card(col: VBoxContainer) -> void:
	var w = GameState.world
	var mine: Dictionary = w.gathering_of_realm(WorldData.CROWN)
	var v := _card(col, "Hold a gathering here")
	v.get_parent().name = "HostCard"
	if not mine.is_empty():
		var n: int = w.gathering_guests(mine).size()
		v.add_child(_note("Your %s at %s · %s · %d coming" % [String(mine["name"]), WorldData.settlement(String(mine["place"]))["name"],
			GameState.gathering_when(mine), n], Style.BRASS))
		return
	var kinds := [Gatherings.FEAST, Gatherings.DANCE, Gatherings.TOURNEY]
	var kind: String = kinds[clampi(_host_kind, 0, 2)]
	var host: Dictionary = GameState.host_lord_at(place)
	v.add_child(Widgets.segmented(["Feast", "Dance", "Tourney"], _host_kind, func(i: int):
		_host_kind = i
		_build(), "HostKind"))
	v.add_child(CourtUI.rich("%s, three nights.%s" % [Gatherings.upper_first(GameState.gathering_when({"starts_hour": w.gathering_start_hour()})),
		(" %s hosts in your name (%s)." % [LordTalk.first_name(host), CourtUI.n(Gatherings.HOST_IN_NAME_REGARD)]) if not host.is_empty() else ""]))
	var who: Dictionary = GameState.host_invitees(place)
	var count := func(key: String) -> String:
		return str((who[key] as Array).size()) if not (who[key] as Array).is_empty() else "none near"
	v.add_child(_host_row("sworn", "Your sworn lords · %d" % (who["sworn"] as Array).size(), "", true, false))
	v.add_child(_host_row("friends", "Lords who like you · %s" % count.call("friends"), "", bool(_host_ask["friends"]), true))
	v.add_child(_host_row("persuade", "Lords to win over · %s" % count.call("persuade"), "", bool(_host_ask["persuade"]), true))
	if not (who["lieges"] as Array).is_empty():
		v.add_child(_host_row("lieges", "Their lieges · %d" % (who["lieges"] as Array).size(), "left out: %d" % Gatherings.SNUB_REGARD, bool(_host_ask["lieges"]), true))
	var cells := [[str(Gatherings.HOST_SILVER), "silver"], [str(Gatherings.HOST_FOOD), "rations"]]
	if kind == Gatherings.TOURNEY:
		cells.append([str(Gatherings.TOURNEY_PURSE), "purse"])
	cells.append(["3", "nights"])
	v.add_child(CourtUI.strip(cells))
	var check: Dictionary = GameState.host_check(place, kind)
	if not bool(check["ok"]):
		v.add_child(_note(String(check["reason"]), Style.ENEMY_LIGHT))
	var send := _button("Send the invitations", func():
		var r: Dictionary = GameState.host_gathering(kind, _host_ask, place)
		if bool(r.get("ok", false)):
			Sound.play("horn")
			_court_note = "Riders go out with your invitations. %d lord%s will come." % [int(r["guests"]), "" if int(r["guests"]) == 1 else "s"]
		_build())
	send.name = "SendInvitations"
	send.disabled = not bool(check["ok"])
	if bool(check["ok"]):
		Style.make_primary(send)
	v.add_child(send)
	if bool(check["ok"]) and _court_note != "":
		v.add_child(_note(_court_note, Style.BRASS))
	var how := _button("How the king's court works", func(): CourtUI.open_rules(self, Style.safe_insets(get_viewport())))
	how.name = "CourtRules"
	how.flat = true
	v.add_child(how)


## Your banners gathering here: who's in the hall, and the council once it can sit.
func _add_muster_card(col: VBoxContainer) -> void:
	var here: Array = CrownCourt.arrived(GameState)
	var all: Array = CrownCourt.muster_lords(GameState)
	var v := _card(col, "Your banners gather here")
	v.get_parent().name = "MusterCard"
	v.add_child(_note("%d of %d lords in the hall · the treasury feeds them, %d silver a day." % [here.size(), all.size(), CrownCourt.muster_upkeep(GameState)], Style.TEXT))
	var c: Dictionary = CrownCourt.council_check(GameState)
	var b := _button("Sit the war council", func(): _open_kingdom("council"))
	b.name = "OpenCouncil"
	b.disabled = not bool(c["ok"])
	if bool(c["ok"]):
		Style.make_primary(b)
	v.add_child(b)
	if not bool(c["ok"]):
		v.add_child(_note(String(c["reason"])))


## The Crown screen over the hall, on `start_tab`.
func _open_kingdom(start_tab: String) -> void:
	var k = KingdomScreen.open(self, GameState, start_tab)
	k.closed.connect(_build)
	k.wants_place.connect(func(_id: String): _build())


## At your own table, while it's on and you're in the hall: a seat of honour (tap a face),
## petitions (a castle granted before everyone among them), and the lists at a tourney.
## What each is worth is on the rules sheet behind "?".
func _add_kings_table(v: VBoxContainer, g: Dictionary) -> void:
	var w = GameState.world
	var lords: Array = GameState.gathering_lords(g)
	var box := VBoxContainer.new()
	box.name = "KingsTable"
	box.add_theme_constant_override("separation", 12)
	v.add_child(box)
	var honoured := int(GameState.hosted.get("honoured", -1))
	if honoured >= 0:
		var l: Dictionary = w.lord_by_id(honoured)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.add_child(CourtUI.face(l, 40))
		var t := _note("%s sits at your right hand." % LordTalk.short_name(l), Color("e8d9b0"))
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(t)
		box.add_child(row)
	elif not lords.is_empty():
		box.add_child(CourtUI.rich("SEAT OF HONOUR   %s" % CourtUI.n(Gatherings.HONOUR_REGARD)))
		var strip := HBoxContainer.new()
		strip.add_theme_constant_override("separation", 4)
		for l in lords.slice(0, 5):
			var lid := int(l["id"])
			strip.add_child(CourtUI.face_button(CaptainArt.texture(LordVoice.portrait_record(l)), LordTalk.first_name(l), "Honour_%d" % lid, func():
				var r: Dictionary = CrownCourt.honour(GameState, lid)
				if bool(r.get("ok", false)):
					_court_note = String(r["text"])
				_build(), true, 56.0))
		box.add_child(strip)
	var asks: Array = CrownCourt.petitions(GameState).filter(func(p): return lords.has(p["lord"]))
	if not asks.is_empty():
		box.add_child(_section("Petitions · %d" % asks.size()))
	for p in asks:
		var pl: Dictionary = p
		var row := HBoxContainer.new()
		row.name = "Petition_%d" % int(p["lord"]["id"])
		row.add_theme_constant_override("separation", 12)
		row.add_child(CourtUI.face(p["lord"], 48))
		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.add_theme_constant_override("separation", 6)
		words.add_child(_small(LordTalk.short_name(p["lord"]), Style.TEXT))
		words.add_child(_note(String(p.get("ask", p["text"])), Color("e8d9b0")))
		var f := HBoxContainer.new()
		f.add_theme_constant_override("separation", 8)
		var ok := _button("%s · +%d" % [String(p["settle"]), Gatherings.PUBLIC_GRANT_REGARD if String(p["kind"]) == "fief" else Gatherings.PETITION_TABLE], func():
			var r: Dictionary = CrownCourt.answer(GameState, pl, true)
			_court_note = String(r.get("text", r.get("reason", "")))
			_build())
		ok.name = "Hear_%d" % int(p["lord"]["id"])
		ok.autowrap_mode = TextServer.AUTOWRAP_OFF
		ok.custom_minimum_size = Vector2(0, 64)
		ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		Style.make_primary(ok)
		f.add_child(ok)
		if bool(p["refuse"]):
			var no := _button("Refuse %d" % Gatherings.PETITION_REFUSED, func():
				var r: Dictionary = CrownCourt.answer(GameState, pl, false)
				_court_note = String(r.get("text", ""))
				_build())
			no.name = "RefuseHere_%d" % int(p["lord"]["id"])
			no.autowrap_mode = TextServer.AUTOWRAP_OFF
			no.custom_minimum_size = Vector2(0, 64)
			f.add_child(no)
		words.add_child(f)
		row.add_child(words)
		box.add_child(row)
	if String(g.get("kind", "")) == Gatherings.TOURNEY:
		_add_lists(box, g)


## The tourney's lists: tap up to three of your captains' faces, then ride. After, who won,
## with every bout folded away under it.
func _add_lists(box: VBoxContainer, g: Dictionary) -> void:
	var done: Dictionary = GameState.hosted.get("tourney", {})
	box.add_child(_section("The lists · purse %d" % Gatherings.TOURNEY_PURSE))
	if not done.is_empty():
		var res := VBoxContainer.new()
		res.name = "ListsResult"
		res.add_theme_constant_override("separation", 8)
		var lines: Array = done.get("lines", [])
		if not lines.is_empty():
			var head := Style.label(String(lines[-1]), Style.BODY, Color("f3d891"))
			head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			res.add_child(head)
		if lines.size() > 1:
			var bouts := _button(("Hide the bouts" if _bouts_open else "Every bout (%d)" % (lines.size() - 1)), func():
				_bouts_open = not _bouts_open
				_build())
			bouts.name = "ListsBouts"
			res.add_child(bouts)
			if _bouts_open:
				for line in lines.slice(0, lines.size() - 1):
					res.add_child(_note(String(line), Color("e8d9b0")))
		box.add_child(res)
		return
	var check: Dictionary = CrownCourt.tourney_check(GameState)
	var caps: Array = CrownCourt.tourney_captains(GameState)
	if _lists_pick.is_empty():
		for e in caps.slice(0, Gatherings.TOURNEY_CAPTAINS):
			_lists_pick.append(int(e["squad"]))
	var strip := HBoxContainer.new()
	strip.name = "Riders"
	strip.add_theme_constant_override("separation", 4)
	for e in caps.slice(0, 5):
		var sid := int(e["squad"])
		var c: Dictionary = e["captain"]
		var name := String(c.get("first", String(c.get("name", "")).split(" ")[0]))
		strip.add_child(CourtUI.face_button(CaptainArt.texture(c), name, "Ride_%d" % sid, func():
			if _lists_pick.has(sid):
				_lists_pick.erase(sid)
			elif _lists_pick.size() < Gatherings.TOURNEY_CAPTAINS:
				_lists_pick.append(sid)
			_build(), _lists_pick.has(sid), 56.0))
	box.add_child(strip)
	box.add_child(_note("%d of %d ride · tap a face" % [_lists_pick.size(), Gatherings.TOURNEY_CAPTAINS]))
	var go := _button("Ride the lists", func():
		var r: Dictionary = CrownCourt.ride_tourney(GameState, _lists_pick)
		if bool(r.get("ok", false)):
			Sound.play("horn")
			_bouts_open = false
		_build())
	go.name = "RideLists"
	go.disabled = not bool(check["ok"]) or _lists_pick.is_empty()
	if not go.disabled:
		Style.make_primary(go)
	box.add_child(go)
	if not bool(check["ok"]):
		box.add_child(_note(String(check["reason"]), Style.MUTED))


func _host_row(key: String, text: String, sub: String, on: bool, can_change: bool) -> Control:
	var row := HBoxContainer.new()
	row.name = "Ask_" + key
	row.add_theme_constant_override("separation", 12)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_child(_small(text, Style.TEXT))
	if sub != "":
		words.add_child(_note(sub, Style.ENEMY_LIGHT))
	row.add_child(words)
	if can_change:
		row.add_child(Widgets.switch(on, func(state: bool): _host_ask[key] = state, "Switch_" + key, text))
	else:
		row.add_child(_small("Always", Style.BRASS))
	return row


## A row for someone in the hall: their face, name, what they're doing, a line in brass
## when there's something in it for you, and their Regard. Tapping opens the talk.
func _person_row(row_name: String, face: Texture2D, who: String, doing: String, tag: String, tag_tone: Color,
		chip_text: String, chip_tone: Color, act: Callable, faded: bool = false) -> Button:
	var b := Button.new()
	b.name = row_name
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 112)
	var lit := tag != "" and not faded
	var box := Style.box(Color(0, 0, 0, 0) if faded else Style.PANEL, Color("8a6a2a") if lit else Style.RULE, 0 if faded else 2, 16)
	for state in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(state, box)
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 14
	h.offset_right = -14
	h.add_theme_constant_override("separation", 14)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var pic := TextureRect.new()
	pic.texture = face
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(72, 96)
	pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if faded:
		pic.modulate = Color(1, 1, 1, 0.55)
	h.add_child(pic)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 2)
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(words)
	var n := _small(who, Style.MUTED if faded else Style.TEXT)
	n.add_theme_font_size_override("font_size", Style.text_size(Style.BODY))
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(n)
	if doing != "":
		var d := _small(doing)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		words.add_child(d)
	if tag != "":
		var tg := _small(tag, tag_tone)
		tg.name = "Tag"
		tg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		words.add_child(tg)
	if chip_text != "":
		var chip := PanelContainer.new()
		var cb := Style.box(Style.RAISED, chip_tone, 2, 20)
		cb.content_margin_left = 12
		cb.content_margin_right = 12
		cb.content_margin_top = 4
		cb.content_margin_bottom = 4
		chip.add_theme_stylebox_override("panel", cb)
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(Style.label(chip_text, Style.SMALL, chip_tone.lightened(0.2)))
		h.add_child(chip)
	b.pressed.connect(act)
	return b


func _lord_row(l: Dictionary, g: Dictionary) -> Button:
	var w = GameState.world
	var lid := int(l["id"])
	var regard := LordTalk.regard(GameState, l)
	var sworn := String(l.get("realm", "")) == WorldData.CROWN
	var tone := Style.MORALE_HIGH if regard >= 10 else (Style.MORALE_MID if regard >= -14 else Style.MORALE_LOW)
	var tag := ""
	var tag_tone := Style.BRASS
	if not g.is_empty():
		var bonus: int = GameState.first_word_bonus(l)
		tag = ("first word at the table · +%d" % bonus) if bonus > 0 else "spoke at the table"
		tag_tone = Style.BRASS if bonus > 0 else Style.MUTED
		var mark := String((GameState.gathering_record(g)["marks"] as Dictionary).get(str(lid), ""))
		if mark != "":
			tag += " · " + mark
	elif not sworn and String(LordTalk.trouble(GameState, l).get("kind", "")) == "bandits":
		tag = "would like a word · a trouble"
	var who := LordTalk.short_name(l)
	if not g.is_empty() and int(g.get("host_lord", -1)) == lid:
		who += " · host"
	return _person_row("Lord_%d" % lid, CaptainArt.texture(LordVoice.portrait_record(l)), who, _doing_here(l), tag, tag_tone,
		"Sworn" if sworn else "%s%d" % ["+" if regard > 0 else "", regard], Style.BRASS if sworn else tone, _open_lord_talk.bind(lid))


func _household_row(person: Dictionary) -> Button:
	var w = GameState.world
	var cid := String(person.get("content_id", ""))
	var rel: Dictionary = w.social.get_relationship(cid)
	var status := String(rel.get("status", Relationships.UNKNOWN))
	var fresh := false
	for v in w.social.available_personal_conversations(String(person.get("id", "")), GameState.personal_conversation_context()):
		fresh = fresh or (bool(v.get("ok", false)) and not bool(v.get("replay", false)))
	var letter := false
	for l in w.social.letters:
		letter = letter or (String(l.get("sender_id", "")) == String(person.get("id", "")) and not bool(l.get("read", false)))
	var tag := ""
	if fresh:
		tag = "would like a word · a visit is open"
	elif letter:
		tag = "would like a word · a letter unread"
	var tex := StoryArtHall.texture("res://assets/portraits/%s_neutral.png" % cid)
	var rose := Color("e58fa8")
	var b := _person_row("Person_%s" % cid, tex, String(person.get("name", "Noble")), String(person.get("role", "")), tag, Color("f6cdd9"),
		Relationships.status_label(status), rose, func():
			_remember_scroll()
			Scenes.active_candidate_id = cid
			Scenes.active_person_id = String(person.get("id", ""))
			Scenes.conversation_return = "res://scenes/settlement.tscn"
			Scenes.go("res://scenes/conversation.tscn"))
	var pic := b.get_child(0).get_child(0) as TextureRect
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	return b


func _away_row(l: Dictionary) -> Button:
	var w = GameState.world
	var where := _lord_whereabouts(l)
	var b := _person_row("Away_%d" % int(l["id"]), CaptainArt.texture(LordVoice.portrait_record(l)), LordTalk.short_name(l),
		"%s · %s" % ["Rules from here" if bool(l.get("ruler", false)) else "Holds %s" % WorldData.settlement(place)["name"], String(where["text"])],
		"", Style.MUTED, "Show on map" if String(where["place"]) != "" else "", Style.RULE, func():
			if String(where["place"]) != "":
				Scenes.map_focus = String(where["place"])
				_on_leave(), true)
	return b


## What a lord in the hall is doing here, in a few words.
func _doing_here(l: Dictionary) -> String:
	var w = GameState.world
	var s_name := String(WorldData.settlement(place)["name"])
	var holder: Dictionary = w.holder_lord(place)
	var p = w.party(int(l.get("party", -1)))
	var men_low: bool = p != null and w.men_of(p.army) < int(l.get("full", 0)) * Lords.REFILLED
	var holds := not holder.is_empty() and int(holder["id"]) == int(l["id"])
	match String(l.get("job", "")):
		"gather":
			var g: Dictionary = w.gathering_by_id(int(l.get("gather_id", 0)))
			if not g.is_empty():
				if int(g.get("host_lord", -1)) == int(l["id"]):
					return "Hosting %s" % w.gathering_name(g)
				return "A guest at %s" % w.gathering_name(g) if w.gathering_on(g) else "Here early for %s" % w.gathering_name(g)
			return "Resting at court a while"
		"guard":
			return "Holding %s for the crown" % s_name if String(l.get("realm", "")) == WorldData.CROWN else "Guarding %s" % s_name
		"escort":
			return "Riding with you"
		"army":
			return "With the marshal's army"
		"home":
			if holds:
				return "%s · raising men" % ("Rules from here" if bool(l.get("ruler", false)) else "Holds %s" % s_name) if men_low else "%s · at home" % ("Rules from here" if bool(l.get("ruler", false)) else "Holds %s" % s_name)
			return "Raising men"
	if holds:
		return "%s · at home" % ("Rules from here" if bool(l.get("ruler", false)) else "Holds %s" % s_name)
	return "Visiting · resting before the road"


## Where an absent lord is and what they're about: {text, place}.
func _lord_whereabouts(l: Dictionary) -> Dictionary:
	var w = GameState.world
	if String(l.get("state", "")) == "prisoner":
		return {"text": "a captive", "place": ""}
	if String(l.get("state", "")) == "regroup":
		return {"text": "gathering a new warband", "place": ""}
	var p = w.party(int(l.get("party", -1)))
	if p == null:
		return {"text": "away", "place": ""}
	var at: String = p.next if p.moving() else p.node
	var target := String(l.get("target", ""))
	var t_name := String(WorldData.settlement(target)["name"]) if WorldData.SETTLEMENTS.has(target) else ""
	var text := "away"
	match String(l.get("job", "")):
		"gather":
			var g: Dictionary = w.gathering_by_id(int(l.get("gather_id", 0)))
			text = ("at %s at %s" % [w.gathering_name(g), t_name]) if not g.is_empty() else "resting at %s" % t_name
		"raid":
			text = "raiding %s" % t_name
		"defend":
			text = "riding to defend %s" % t_name
		"hunt":
			text = "hunting bandits near %s" % t_name
		"army":
			text = "with the marshal's army"
		"guard":
			text = "guarding %s" % t_name
		"escort":
			text = "riding with you"
		"chase":
			text = "riding after your company"
		_:
			text = ("riding to %s" % t_name) if p.moving() and t_name != "" else "near %s" % WorldData.settlement(at)["name"]
	return {"text": text, "place": at}


## Talk to a lord in the hall: the lord talk, indoors.
func _open_lord_talk(lord_id: int) -> void:
	if _talk != null and is_instance_valid(_talk):
		return
	_remember_scroll()
	_talk = LordConversation.open(self, GameState, lord_id, "hall")
	_talk.closed.connect(func():
		_talk = null
		GameState.save_game()
		_build())


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
	# The captain's face, as in the Warband, with the troop's own icon at its corner.
	row.add_child(_squad_art(s))
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
