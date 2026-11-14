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
const SiegeCamp = preload("res://scripts/world/siege_camp.gd")
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
## The court note the page last showed (a new one glows), and whether the tourney's bouts
## were opened by the last tap (they're read out in turn).
var _court_note_shown := ""
var _bouts_fresh := false
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
	autoplay = Scenes.autoplay()
	var w = GameState.world
	if w == null or w.here() == "":
		get_tree().change_scene_to_file.call_deferred("res://scenes/world_map.tscn" if w != null else "res://scenes/title.tscn")
		return
	place = w.here()
	# A town keeps its land's theme; while a feast is on there, the feast's music.
	var land := String(WorldData.culture_of(WorldData.settlement(place)["faction"]))
	Sound.play_music(("feast_" if w.gathering_on(w.gathering_at(place)) else "") + land)
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
	# Regard a tap just changed rises by the lord's face once the page is back.
	Widgets.show_regard.call_deferred(self)
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
	var back := Button.new()
	back.name = "LeaveButton"
	back.set_meta("back", true)
	back.text = "Leave %s" % String(WorldData.settlement(place)["name"])
	Style.make_primary(back)
	back.pressed.connect(_on_leave)
	frame.add_child(Widgets.bottom_bar(back, insets, "LeaveBar"))

	_build_info_sheet()
	_just_built = ""
	if _arrival_overlay != null and is_instance_valid(_arrival_overlay):
		move_child(_arrival_overlay, get_child_count() - 1)
	_restore_scroll(keep)


## The name and what kind of place it is, set on the scene beside the holder's banner (or
## above the chips when illustrations are off), and chips for how well it's held and how
## safe its roads are. Everything else waits behind the info button.
func _add_header(col: VBoxContainer, vista: Control = null) -> void:
	var w = GameState.world
	var title := Style.label(String(WorldData.settlement(place)["name"]), 64, Style.BRASS)
	title.name = "SettlementName"
	# The banner says whose it is, so the line under the name says only what it is.
	var kind := Style.label(String(w.brief(place)).split(" · ")[0], Style.BODY, Style.TEXT if vista != null else Style.MUTED)
	kind.name = "SettlementKind"
	var flag := Widgets.banner(String(w.owner_of(place)), Vector2(46, 62))
	flag.name = "SettlementBanner"
	flag.size_flags_vertical = Control.SIZE_SHRINK_END
	if vista != null:
		vista.fade = true
		var pad := MarginContainer.new()
		pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for side in ["left", "right"]:
			pad.add_theme_constant_override("margin_" + side, 24)
		pad.add_theme_constant_override("margin_bottom", 14)
		vista.add_child(pad)
		var line := HBoxContainer.new()
		line.alignment = BoxContainer.ALIGNMENT_BEGIN
		line.size_flags_vertical = Control.SIZE_SHRINK_END
		line.add_theme_constant_override("separation", 16)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pad.add_child(line)
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
		var title_row := HBoxContainer.new()
		title_row.add_theme_constant_override("separation", 16)
		col.add_child(title_row)
		title_row.add_child(flag)
		var stack := VBoxContainer.new()
		stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stack.add_theme_constant_override("separation", 0)
		title_row.add_child(stack)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stack.add_child(title)
		stack.add_child(kind)

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
			if stationed > 0:
				chips.add_child(_status_chip(str(stationed), Style.MORALE_HIGH, "men"))
			chips.add_child(_status_chip(str(militia), Style.MORALE_HIGH if stationed > 0 else Style.MORALE_MID, "militia"))
	elif w.garrisons.has(place):
		var men: int = w.men_of(w.garrison_at(place))
		var cap: int = w.garrison_capacity(place)
		var tone := Style.MORALE_LOW if men < cap * 0.4 else (Style.MORALE_HIGH if men >= cap * 0.8 else Style.MORALE_MID)
		chips.add_child(_status_chip("%d/%d" % [men, cap], tone, "men"))
	chips.add_child(_danger_chip())
	var info := Widgets.icon_button("book", _show_info, "About %s" % String(WorldData.settlement(place)["name"]), "InfoButton")
	info.add_theme_stylebox_override("normal", Style.box(Style.NIGHT, Style.RULE, 2, 40))
	info.add_theme_stylebox_override("hover", Style.box(Style.PANEL, Style.MUTED, 2, 40))
	info.add_theme_stylebox_override("pressed", Style.box(Style.PANEL, Style.BRASS, 2, 40))
	if vista != null:
		# In the scene's top corner, out of the way of the title.
		info.add_theme_stylebox_override("normal", Style.box(Color(Style.NIGHT, 0.8), Style.RULE, 2, 40))
		info.anchor_left = 1.0
		info.anchor_right = 1.0
		info.offset_left = -18 - Style.TOUCH
		info.offset_right = -18
		info.offset_top = 18
		info.offset_bottom = 18 + Style.TOUCH
		vista.add_child(info)
	else:
		row.add_child(info)

	var recent := String(TravelPresentation.settlement_state(w, place).get("recent_event", ""))
	if recent != "":
		var recent_note := _note("Recent: %s" % recent, Style.MUTED)
		recent_note.name = "SettlementRecentEvent"
		col.add_child(recent_note)


## A status as a chip: its shape for good, middling or bad, and the icon of what it counts.
func _status_chip(text: String, tone: Color, key: String) -> PanelContainer:
	var c := Widgets.chip(text, tone, "▲" if tone == Style.MORALE_HIGH else ("◆" if tone == Style.MORALE_MID else "▼"), key)
	var ic := c.find_child("Icon", true, false) as Control
	if ic != null:
		ic.modulate = Color.WHITE
	return c


## How safe the place is, as one chip: what threatens it, by its icon, and whose banner.
func _danger_chip() -> PanelContainer:
	var w = GameState.world
	var danger := String(w.settlement_danger(place))
	if danger == "":
		var quiet := Widgets.chip("Quiet roads", Style.MORALE_HIGH)
		quiet.name = "DangerChip"
		return quiet
	var key := "fight"
	var word := "Hostile"
	var realm := ""
	if danger.begins_with("under siege"):
		key = "walls"
		word = "Besieged"
		realm = String(w.siege_info(place).get("realm", ""))
	elif danger.begins_with("raid"):
		key = "fire"
		word = "Raiders here"
	elif danger.begins_with("burned"):
		key = "fire"
		word = "Burned"
	elif danger.begins_with("marshal"):
		key = "advance"
		word = "Army coming"
		for army in w.campaign_armies:
			if String(army.get("target", "")) == place:
				realm = String(army.get("realm", ""))
	var c := Widgets.chip(word, Style.MORALE_LOW, "", key)
	c.name = "DangerChip"
	c.tooltip_text = danger
	if realm != "":
		var flag := Widgets.banner(realm, Vector2(20, 28))
		(c.get_child(0) as HBoxContainer).add_child(flag)
	return c


## Silver with what the company costs a day, and food in days, as two tiles.
func _add_wallet(col: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.name = "Wallet"
	row.add_theme_constant_override("separation", 14)
	col.add_child(row)
	var days := GameState.food_days()
	var silver_tile := Widgets.tile("silver", Widgets.thousands(GameState.silver), "−%d a day" % GameState.daily_outgoings())
	var food_tile := Widgets.tile("food", str(days), "day of food" if days == 1 else "days of food",
		Style.ENEMY_LIGHT if days < 3 else Style.TEXT)
	row.add_child(silver_tile)
	row.add_child(food_tile)
	# After a purchase the numbers count to their new values, and flash.
	if _shown_silver >= 0 and _shown_silver != GameState.silver:
		Widgets.tick_to(silver_tile.find_child("Value", true, false), _shown_silver, GameState.silver, func(v): return Widgets.thousands(v), "silver")
	if _shown_food >= 0 and _shown_food != days:
		Widgets.tick_to(food_tile.find_child("Value", true, false), _shown_food, days, func(v): return str(v), "food")
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
	tabs.append({"id": "squads", "label": "Companies", "badge": 0})
	# Work counts what's ready to claim; with the purse too thin for tomorrow, the new
	# notices too, since paid work is what the company needs.
	var work_badge: int = GameState.active_jobs_completable_at(place).size()
	if GameState.short_of_silver() and GameState.contract_count() < Jobs.MAX_ACTIVE_JOBS:
		work_badge += GameState.jobs_at(place).size()
	tabs.append({"id": "work", "label": "Work", "badge": work_badge})
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


## Everything about the place that isn't needed to act on it: whose it is, its garrison,
## what threatens it, what it offers and why it matters, in a sheet that slides up from
## the bottom. It's built with the page and kept hidden, so its words are always there.
func _build_info_sheet() -> void:
	var w = GameState.world
	var col := Widgets.sheet(self, "About %s" % String(WorldData.settlement(place)["name"]), "InfoSheet", func(): _info_sheet = null)
	_info_sheet = col.get_parent().get_parent().get_parent().get_parent() as Control
	_info_sheet.visible = false
	var condition := _note(String(TravelPresentation.settlement_state(w, place).get("sentence", "")), Style.TEXT)
	condition.name = "SettlementCondition"
	col.add_child(condition)
	# Whose it is: their banner and name.
	var owner := String(w.owner_of(place))
	var own := HBoxContainer.new()
	own.name = "InfoOwner"
	own.add_theme_constant_override("separation", 14)
	own.add_child(Widgets.banner(owner, Vector2(40, 54)))
	var own_words := VBoxContainer.new()
	own_words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	own_words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	own_words.add_child(Style.label("Owner", Style.SMALL, Style.MUTED))
	own_words.add_child(Style.label(String(WorldData.FACTIONS[owner]["name"]), Style.BODY, Style.TEXT))
	own.add_child(own_words)
	col.add_child(own)
	# The garrison, as men against what the walls hold.
	if w.garrisons.has(place):
		var men: int = w.men_of(w.garrison_at(place))
		var cap: int = w.garrison_capacity(place)
		col.add_child(Widgets.store_tile("InfoGarrison", "men", men, cap, "Garrison"))
	# A siege in numbers.
	var siege: Dictionary = w.siege_info(place)
	if not siege.is_empty():
		col.add_child(Style.label("Under siege", Style.SMALL, Style.ENEMY_LIGHT))
		var tiles := Widgets.tile_grid([
			Widgets.tile("men", Widgets.thousands(int(siege["attackers"])), "besiegers", Style.ENEMY_LIGHT),
			Widgets.tile("walls", Widgets.thousands(int(siege["defenders"])), "behind walls ×%.1f" % float(siege["walls"])),
			Widgets.tile("food", str(int(ceil(float(siege["food_hours"]) / 24.0))), "days of food"),
			Widgets.tile("clock", Style.time_short(float(siege["assault_hours"])), "to the assault"),
		], 2)
		tiles.name = "SiegeTiles"
		col.add_child(tiles)
		col.add_child(Widgets.chip_row([Widgets.chip("Relief may come" if int(siege["relief"]) > 0 else "No relief in sight",
			Style.MORALE_MID if int(siege["relief"]) > 0 else Style.MORALE_LOW)]))
	else:
		col.add_child(Widgets.chip_row([_danger_chip()]))
	# What it offers, as icons.
	col.add_child(Style.label("Services", Style.SMALL, Style.MUTED))
	var services := HFlowContainer.new()
	services.name = "InfoServices"
	services.add_theme_constant_override("h_separation", 8)
	services.add_theme_constant_override("v_separation", 8)
	for svc in WorldData.services(place):
		services.add_child(Widgets.chip(String(svc).capitalize(), Style.TEXT, "", String(SERVICE_ICONS.get(String(svc), "plus"))))
	var recruits: int = w.offers_at(place).size()
	services.add_child(Widgets.stat("men", "%d to hire" % recruits))
	col.add_child(services)
	col.add_child(Style.label("Why it matters", Style.SMALL, Style.MUTED))
	col.add_child(_note(WorldData.importance(place), Style.TEXT))


## Each service's icon in the info sheet.
const SERVICE_ICONS := {"provisions": "food", "cheap provisions": "food", "recruits": "men", "reinforcement": "plus",
	"training": "level", "court": "crown"}


func _show_info() -> void:
	if _info_sheet == null or not is_instance_valid(_info_sheet) or _info_sheet.is_queued_for_deletion():
		_build_info_sheet()
	Style.stop_easing(_info_sheet)
	_info_sheet.visible = true
	_info_sheet.move_to_front()
	var panel := _info_sheet.get_node_or_null("SheetPanel") as Control
	if panel != null:
		Style.ease_in(panel)


func _hide_info() -> void:
	if _info_sheet != null and is_instance_valid(_info_sheet) and _info_sheet.visible:
		var sheet := _info_sheet
		Style.ease_out(sheet, func(): sheet.visible = false)


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
	var why: String = GameState.barred_by(owner)
	var card := Widgets.card(col, "Gates barred", "your standing" if why == "standing" else "at war", Style.ENEMY_LIGHT)
	card.get_parent().name = "HostileCard"
	card.add_child(_realm_line(owner, String(WorldData.FACTIONS[owner]["name"]), "Markets, barracks and halls are closed to you.", Style.ENEMY_LIGHT))
	_add_reparations(card, owner, why)
	var raid: Dictionary = GameState.raid_check(place)
	if bool(raid["ok"]):
		card.add_child(_note("Its people won't trade with you, but their barns are full.", Style.MUTED))
		var b := _button("Raid %s" % WorldData.settlement(place)["name"], func():
			GameState.save_game()
			Scenes.settlement_place = ""
			Scenes.settlement_scroll = 0
			Scenes.map_raid = place
			Scenes.go("res://scenes/world_map.tscn"))
		b.name = "Raid"
		_with_icon(b, "fire")
		card.add_child(b)
	var g: Dictionary = GameState.world.gathering_at(place)
	if not g.is_empty():
		var feast := _note("%s is held behind the walls, but no enemy is seated at it. Make peace, or take the place, to sit at a feast here." % Gatherings.upper_first(GameState.gathering_title(g)), Style.MUTED)
		feast.name = "FeastBarred"
		card.add_child(feast)


## Why the gates are barred, in numbers: your standing against the line they bar you at,
## and, when your standing alone shuts them, an envoy with reparations.
func _add_reparations(card: VBoxContainer, owner: String, why: String) -> void:
	var rel: int = GameState.relation_with_realm(owner)
	var standing := Widgets.chip_row([Widgets.stat("bond", _signed(rel), Style.ENEMY_LIGHT if rel <= GameState.HOSTILE_RELATION else Style.TEXT),
		Widgets.stat("lock", "barred at %s or below" % _signed(GameState.HOSTILE_RELATION), Style.MUTED)])
	standing.name = "Standing"
	card.add_child(standing)
	if why == "crown":
		card.add_child(_note("Your crown is at war with them. Make peace from your court to open these gates."))
		return
	if why == "employer":
		card.add_child(_note("Your employer is at war with them. These gates open when your contract ends."))
		return
	if why != "standing":
		return
	var check: Dictionary = GameState.reparations_check(owner)
	var envoy := _button("Send an envoy", func():
		if GameState.pay_reparations(owner):
			Sound.play("coins")
			_build())
	envoy.name = "SendEnvoy"
	_with_icon(envoy, "silver")
	envoy.disabled = not bool(check["ok"])
	if bool(check["ok"]):
		Style.make_primary(envoy)
	card.add_child(Widgets.priced(envoy, [["silver", "−%s" % Widgets.thousands(int(check["cost"])), Style.ENEMY_LIGHT],
		["bond", "to %s" % _signed(GameState.REPARATIONS_RELATION), Style.MORALE_HIGH]], String(check["reason"])))
	card.add_child(_note("Reparations buy your standing back to just above the line. One envoy a week."))


## A realm's banner beside two lines: what it is to you, and a word more.
func _realm_line(realm: String, top: String, bottom: String, tone: Color = Style.MUTED) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var flag := Widgets.banner(realm, Vector2(36, 48))
	flag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(flag)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	words.add_theme_constant_override("separation", 0)
	row.add_child(words)
	var t := Style.label(top, Style.BODY, Style.TEXT)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(t)
	if bottom != "":
		words.add_child(_note(bottom, tone))
	return row


## A signed number with a real minus: "+5", "−25".
func _signed(n: int) -> String:
	return ("+%d" % n) if n > 0 else (("−%d" % -n) if n < 0 else "0")


## Fealty and a mercenary commission, in a town or castle: who you serve and on what
## terms, as chips, with one verb each.
func _add_contract(col: VBoxContainer, owner: String) -> void:
	var kind: String = WorldData.settlement(place)["type"]
	if not kind in [WorldData.CASTLE, WorldData.TOWN]:
		return

	var faction_name: String = WorldData.FACTIONS[owner]["name"]

	if GameState.has_fief():
		var fv := Widgets.card(col, "Fealty")
		fv.get_parent().name = "FealtyCard"
		if GameState.fief_realm() == owner:
			fv.add_child(_realm_line(owner, "Sworn vassal", "Lord of %s" % WorldData.settlement(GameState.fief_id())["name"], Style.BRASS))
		else:
			var other_realm := GameState.fief_realm()
			fv.add_child(_realm_line(other_realm, "Sworn elsewhere", "Your company holds its fief from %s." % WorldData.the_realm(String(WorldData.FACTIONS[other_realm]["name"]))))
		return

	if GameState.can_petition_fief(owner):
		var pv := Widgets.card(col, "Fealty", "", Style.MUTED, true)
		pv.get_parent().name = "FealtyCard"
		pv.add_child(_realm_line(owner, faction_name, "Will take you as a vassal and grant you a fief.", Style.TEXT))
		pv.add_child(Widgets.chip_row([Widgets.stat("renown", Widgets.thousands(GameState.renown)),
			Widgets.stat("bond", _signed(GameState.relation_with_realm(owner)))]))
		var swear := _button("Swear fealty…", _show_fealty_sheet.bind(owner))
		swear.name = "SwearFealty"
		Style.make_primary(swear)
		pv.add_child(swear)

	var v := Widgets.card(col, "Mercenary commission")
	v.get_parent().name = "CommissionCard"
	if GameState.has_contract():
		if GameState.contract_realm() == owner:
			var daily: int = GameState.contract_daily_pay()
			var left: int = int(GameState.contract.get("days_left", 0))
			var bonus: int = int(GameState.contract.get("bonus_per_lord", 100))
			v.add_child(_realm_line(owner, "In service", faction_name, Style.BRASS))
			v.add_child(Widgets.chip_row([Widgets.effect("silver", daily, "/day"),
				Widgets.stat("clock", "%d day%s left" % [left, "" if left == 1 else "s"]),
				Widgets.effect("silver", bonus, " a captive lord")]))
			var cancel_btn := _button("Resign", _on_cancel_contract)
			cancel_btn.name = "ResignCommission"
			v.add_child(Widgets.priced(cancel_btn, [["bond", "−25", Style.ENEMY_LIGHT]]))
		else:
			var other: String = GameState.contract_realm()
			v.add_child(_realm_line(other, "Pledged elsewhere", "Your company already serves %s." % String(WorldData.FACTIONS[other]["name"])))
		return

	if not GameState.world.is_at_war(owner):
		v.add_child(_realm_line(owner, "At peace", "No sellswords wanted."))
		return

	var pay := GameState.calculate_contract_pay(owner)
	if GameState.renown < GameState.CONTRACT_MIN_RENOWN:
		v.add_child(_realm_line(owner, "At war · hiring", "Its marshals hire only captains of renown."))
		v.add_child(Widgets.chip_row([Widgets.stat("renown", "%d of %d" % [GameState.renown, GameState.CONTRACT_MIN_RENOWN], Style.ENEMY_LIGHT)]))
		return

	v.add_child(_realm_line(owner, "At war · hiring", faction_name, Style.TEXT))
	v.add_child(Widgets.chip_row([Widgets.effect("silver", pay, "/day"), Widgets.stat("clock", "%d days" % GameState.CONTRACT_DAYS)]))
	var sign_btn := _button("Offer your sword", _on_sign_contract.bind(owner))
	sign_btn.name = "OfferSword"
	Style.make_primary(sign_btn)
	v.add_child(sign_btn)


## The fiefs the realm would grant you, each with its scene, to choose one and swear.
func _show_fealty_sheet(owner: String) -> void:
	var col := Widgets.sheet(self, "Swear fealty", "FealtySheet")
	col.add_child(_realm_line(owner, String(WorldData.FACTIONS[owner]["name"]), "Choose the fief you'll hold as its vassal.", Style.TEXT))
	for fid in GameState.available_fiefs_for_grant(owner):
		var f := String(fid)
		var row := HBoxContainer.new()
		row.name = "Fief_%s" % f
		row.add_theme_constant_override("separation", 14)
		var thumb := SettlementVista.make(f, GameState.world, 96.0)
		thumb.custom_minimum_size.x = 150
		row.add_child(thumb)
		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(words)
		words.add_child(Style.label(String(WorldData.settlement(f)["name"]), Style.BODY, Style.TEXT))
		words.add_child(_note(String(WorldData.settlement(f)["type"]).capitalize()))
		var claim := _button("Claim", func():
			Widgets.close_sheet(col)
			if GameState.accept_fealty_and_fief(f, owner):
				Sound.play("charge")
				_build())
		claim.name = "Claim_%s" % f
		claim.custom_minimum_size = Vector2(140, Style.TOUCH)
		claim.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		Style.make_primary(claim)
		row.add_child(claim)
		col.add_child(row)


func _on_sign_contract(owner: String) -> void:
	GameState.sign_contract(owner)
	Sound.play("charge")
	_build()


func _on_cancel_contract() -> void:
	GameState.break_contract()
	Sound.play("alarm")
	_build()


## A castle or town of your crown that isn't your seat, laid out like your own fief: who
## holds it for you and what it pays, then its garrison and your squads standing with it.
func _add_crown_holding(col: VBoxContainer) -> void:
	var w = GameState.world
	var v := Widgets.card(col, "%s of %s" % [String(WorldData.settlement(place)["type"]).capitalize(), GameState.crown_title()])
	v.get_parent().name = "HoldingCard"
	var holder: Dictionary = GameState.holder_of(place)
	var lords: Array = GameState.crown_lords().filter(func(l): return String(l.get("fief", "")) != place)
	var who := HBoxContainer.new()
	who.name = "Holder"
	who.add_theme_constant_override("separation", 14)
	v.add_child(who)
	if not holder.is_empty():
		who.add_child(CourtUI.face(holder, 56))
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	who.add_child(words)
	if holder.is_empty():
		words.add_child(Style.label("No one holds it", Style.BODY, Style.MUTED))
		words.add_child(_note("Grant it to a sworn lord."))
	else:
		words.add_child(Style.label(LordTalk.short_name(holder), Style.BODY, Style.TEXT))
		words.add_child(_note("Holds it for you"))
	if not lords.is_empty():
		var grant := _button("Grant…", _show_grant_sheet)
		grant.name = "GrantHolding"
		grant.custom_minimum_size = Vector2(140, Style.TOUCH)
		grant.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if holder.is_empty():
			Style.make_primary(grant)
		who.add_child(grant)
	if not holder.is_empty():
		var hid := int(holder["id"])
		var r := _button("Take it back", func():
			if GameState.revoke_fief(hid):
				_build())
		r.name = "Revoke"
		v.add_child(Widgets.priced(r, [["bond", _signed(GameState.REVOKE_REGARD), Style.ENEMY_LIGHT]]))
	var income := int(Lords.INCOME.get(String(WorldData.settlement(place)["type"]), 0))
	v.add_child(Widgets.tile_grid([Widgets.tile("silver", "+%d" % int(income / 2.0), "a day to you"),
		Widgets.tile("chest", Widgets.thousands(GameState.crown_treasury()), "crown treasury")], 2))
	v.add_child(_note("The treasury's half raises the garrison."))

	var stationed: Array = GameState.stationed_at(place)
	var g := Widgets.card(col, "Garrison", "" if stationed.is_empty() else "%d compan%s yours" % [stationed.size(), "y" if stationed.size() == 1 else "ies"])
	g.get_parent().name = "CrownGarrisonCard"
	g.add_child(Widgets.store_tile("CrownGarrisonTile", "men", w.men_of(w.garrison_at(place)), w.garrison_capacity(place), ""))
	for sq in stationed:
		var sid := int(sq["id"])
		var take_back := func():
			if GameState.withdraw_from_holding(sid):
				_build()
		g.add_child(_squad_line(sq, "Take back", true, "Withdraw_%d" % sid, take_back))
	if not stationed.is_empty():
		g.add_child(_note("Companies you leave in a garrison draw half wages, from your seat's silver before your purse."))
	if GameState.army.size() > 1:
		var open := _button("Station a company here…", _show_station_sheet.bind(true))
		open.name = "StationSquad"
		g.add_child(open)


## Your sworn lords, by face, to hand this place to.
func _show_grant_sheet() -> void:
	var col := Widgets.sheet(self, "Grant %s" % String(WorldData.settlement(place)["name"]), "GrantSheet")
	for l in GameState.crown_lords().filter(func(x): return String(x.get("fief", "")) != place):
		var lid := int(l["id"])
		var holds := String(l.get("fief", ""))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		row.add_child(CourtUI.face(l, 48))
		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(words)
		words.add_child(Style.label(LordTalk.short_name(l), Style.BODY, Style.TEXT))
		if holds != "":
			words.add_child(Widgets.chip_row([Widgets.chip(String(WorldData.settlement(holds)["name"]), Style.TEXT, "", "keep")]))
		var b := _button("Grant", func():
			Widgets.close_sheet(col)
			if GameState.grant_fief(place, lid):
				Sound.play("horn")
				_build())
		b.name = "Grant_%d" % lid
		b.custom_minimum_size = Vector2(140, Style.TOUCH)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(b)
		col.add_child(row)


## Your own fief: what it stores, the squads you've left there, and what you've built.
func _add_fief_management(col: VBoxContainer) -> void:
	var fief: Dictionary = GameState.player_fief
	var is_b: bool = GameState.world != null and GameState.world.is_burned(place)
	_add_estate_card(col, fief, is_b)
	_add_garrison_card(col, fief)
	_add_manor_card(col, fief, is_b)
	_add_exchange_card(col)
	_add_crown_card(col)
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


## At your own seat: what a crown of your own still needs, and the way to raise it once
## nothing does.
func _add_crown_card(col: VBoxContainer) -> void:
	var steps: Array = GameState.crown_path()
	if steps.is_empty():
		return
	var met := steps.filter(func(s): return bool(s["done"])).size()
	var ready: bool = bool(GameState.crown_check()["ok"])
	var card := Widgets.card(col, "Toward a crown", "%d of %d" % [met, steps.size()], Style.BRASS if ready else Style.MUTED, ready)
	card.get_parent().name = "CrownPathCard"
	card.add_child(Widgets.checklist(steps, "CrownPath"))
	if ready:
		var raise := _button("Raise your crown…", _confirm_crown)
		raise.name = "RaiseCrown"
		Style.make_primary(raise)
		card.add_child(raise)


func _confirm_crown() -> void:
	if _modal != null and is_instance_valid(_modal):
		_modal.queue_free()
	var liege := GameState.fief_realm()
	var s_name := String(WorldData.settlement(place)["name"])
	var col := Widgets.sheet(self, "Raise your banner?", "CrownConfirm", func(): _modal = null)
	_modal = col.get_parent().get_parent().get_parent().get_parent() as Control
	col.add_child(_realm_line(liege, "%s goes to war with you" % WorldData.the_realm(String(WorldData.FACTIONS[liege]["name"])),
		"%s becomes the seat of your own crown. Every castle or town you storm after this is yours. There is no going back." % s_name, Style.TEXT))
	var yes := _button("Raise crown", func():
		Widgets.close_sheet(col)
		if GameState.declare_crown():
			Sound.play("horn")
		_build())
	yes.name = "ConfirmCrown"
	Style.make_primary(yes)
	var no := _button("Not yet", func(): Widgets.close_sheet(col))
	no.name = "NotYetCrown"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(no)
	row.add_child(yes)
	col.add_child(row)


func _fief_culture() -> String:
	return WorldData.culture_of(String(WorldData.settlement(place)["faction"]))


## A vassal holding a village can ask their liege for a castle that has lost its lord: the
## village goes back, the castle is theirs. Standing is kept; the asking needs as much as
## fealty did.
func _add_exchange_card(col: VBoxContainer) -> void:
	if GameState.is_crowned() or String(WorldData.settlement(place)["type"]) != WorldData.VILLAGE:
		return
	var realm := GameState.fief_realm()
	var castles: Array = GameState.exchange_castles()
	var card := Widgets.card(col, "Walls of your own", "%d free" % castles.size() if not castles.is_empty() else "")
	card.get_parent().name = "ExchangeCard"
	if castles.is_empty():
		card.add_child(_note("No castle of %s is free to grant. When one loses its lord, ask for it here: a crown needs walls." % WorldData.the_realm(String(WorldData.FACTIONS[realm]["name"]))))
		return
	card.add_child(_note("Your liege will take this village back and grant you a castle. Your companies here move with you; the village's buildings stay."))
	for cid in castles:
		var c := String(cid)
		var check: Dictionary = GameState.exchange_check(c)
		var row := HBoxContainer.new()
		row.name = "Exchange_%s" % c
		row.add_theme_constant_override("separation", 14)
		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(words)
		var nm := Style.label(String(WorldData.settlement(c)["name"]), Style.BODY, Style.TEXT)
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nm.custom_minimum_size = Vector2(10, 0)
		words.add_child(nm)
		words.add_child(_note("Castle · %d silver a day in taxes" % int(Fiefs.BASE_TAX[WorldData.CASTLE])))
		var ask := _button("Ask for it", func():
			if GameState.exchange_fief(c):
				Sound.play("horn")
				_build())
		ask.name = "AskExchange_%s" % c
		ask.custom_minimum_size = Vector2(150, Style.TOUCH)
		ask.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ask.disabled = not bool(check["ok"])
		if bool(check["ok"]):
			Style.make_primary(ask)
		row.add_child(ask)
		card.add_child(row)
		if not bool(check["ok"]):
			card.add_child(_note(String(check["reason"])))


## The lord's title, how long they've held it, and the two stores the place fills each day.
func _add_estate_card(col: VBoxContainer, fief: Dictionary, is_b: bool) -> void:
	var title: String = Fiefs.title_for(_fief_culture())
	var s_name := String(WorldData.settlement(place)["name"])
	var held := ""
	if GameState.world != null:
		var days := int((float(GameState.world.hour) - float(fief.get("granted_at", 0.0))) / 24.0) + 1
		held = "day %d as its %s" % [days, title.to_lower()]
	var card := Widgets.card(col, "Your estate", held)
	card.get_parent().name = "EstateCard"
	var name_label := Style.label("%s of %s" % [title, s_name], Style.TITLE_SIZE, Style.BRASS)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(name_label)
	if GameState.is_crowned() and String(fief.get("realm", "")) == WorldData.CROWN:
		card.add_child(_note("Seat of your crown · ruler of %s" % GameState.crown_title(), Style.TEXT))
	else:
		var realm := String(fief.get("realm", ""))
		var r_name := String(WorldData.FACTIONS.get(realm, {}).get("name", "Realm"))
		card.add_child(_realm_line(realm, r_name, "Your liege · the seat of your company"))
	if is_b:
		card.add_child(Widgets.chip_row([Widgets.chip("Raided · until rebuilt", Style.MORALE_LOW, "", "fire")]))

	var silver: int = int(fief.get("silver", 0))
	var food: int = int(fief.get("food", 0))
	var tiles := HBoxContainer.new()
	tiles.add_theme_constant_override("separation", 12)
	card.add_child(tiles)
	tiles.add_child(Widgets.store_tile("TreasuryTile", "silver", silver, Fiefs.MAX_STORAGE_SILVER,
		"+%d a day in taxes" % Fiefs.daily_tax(fief, is_b), "Full · taxes are being lost"))
	tiles.add_child(Widgets.store_tile("GranaryTile", "food", food, Fiefs.max_food_capacity(fief),
		"+%d a day" % Fiefs.daily_food(fief, is_b), "Full · grain is going to waste"))

	# The tiles above say how much; the buttons only say what to do.
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	card.add_child(buttons)
	var collect := _button("Collect", func():
		if GameState.collect_fief_taxes() > 0:
			Sound.play("coins")
			_build())
	collect.name = "CollectTaxes"
	_with_icon(collect, "silver")
	collect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	collect.disabled = silver <= 0
	if silver > 0:
		Style.make_primary(collect)
	buttons.add_child(collect)
	var take := _button("Take food", func():
		if GameState.collect_fief_food() > 0:
			Sound.play("coins")
			_build())
	take.name = "TakeFood"
	_with_icon(take, "food")
	take.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	take.disabled = food <= 0
	buttons.add_child(take)


## The squads you've left here, how to leave another, and what the place holds out with.
## Only your own squads can be taken back; the liege's guards are counted, not listed.
## The wound rule is said once, at the bottom.
func _add_garrison_card(col: VBoxContainer, fief: Dictionary) -> void:
	var w = GameState.world
	var garrison: Array = GameState.fief_garrison()
	var men := 0
	var yours := 0
	for sq in garrison:
		men += int(sq["men"])
		if GameState.is_company_squad(sq):
			yours += 1
	var aside := "" if garrison.is_empty() else "%d compan%s · %d men" % [garrison.size(), "y" if garrison.size() == 1 else "ies", men]
	var card := Widgets.card(col, "Garrison", aside)
	card.get_parent().name = "GarrisonCard"
	var village := String(WorldData.settlement(place)["type"]) == WorldData.VILLAGE
	var militia: int = w.men_of(w.village_militia(place)) if village and w != null else 0
	var full: bool = GameState.army.size() >= GameState.squad_cap()
	if yours == 0:
		card.add_child(_note("No companies of yours are stationed here."))
	var guards := 0
	for i in garrison.size():
		var index := i
		var sq: Dictionary = garrison[i]
		if not GameState.is_company_squad(sq):
			guards += int(sq["men"])
			continue
		var take_back := func():
			if GameState.withdraw_squad_from_fief(index):
				Sound.play("click")
				_build()
		card.add_child(_squad_line(sq, "Take back", not full, "Withdraw_%d" % int(sq["id"]), take_back))
	if guards > 0:
		var keep := _note("%d guards of the realm hold the walls with your companies. They stay when you ride out." % guards)
		keep.name = "RealmGuards"
		card.add_child(keep)
	if full and yours > 0:
		card.add_child(_note("Your warband is full, %d of %d squads. Station one to make room." % [GameState.army.size(), GameState.squad_cap()]))
	if yours > 0:
		var pay := _note("Your companies here draw half wages: %d silver a day, from the estate's silver before your purse." % GameState.stationed_wages())
		pay.name = "StationedWages"
		card.add_child(pay)
	if GameState.army.size() > 1:
		var open := _button("Station a company here…", _show_station_sheet)
		open.name = "StationSquad"
		card.add_child(open)
	else:
		card.add_child(_note("Your only company can't stay behind."))
	if village:
		# What holds it against raiders, as chips.
		card.add_child(Style.label("Against raiders", Style.SMALL, Style.MUTED))
		var holds: Array = [Widgets.stat("militia", str(militia))]
		if men > 0:
			holds.append(Widgets.stat("men", str(men)))
		if bool(fief.get("improvements", {}).get(Fiefs.IMPROVEMENT_FORTIFICATIONS, false)):
			holds.append(Widgets.stat("walls", "+%d · a third stronger" % int(Fiefs.IMPROVEMENTS[Fiefs.IMPROVEMENT_FORTIFICATIONS]["militia_bonus"]), Style.MORALE_HIGH))
		var chips := Widgets.chip_row(holds)
		chips.name = "Defenders"
		card.add_child(chips)
	card.add_child(_note("Stationed men %sheal one wound a day." % ("" if village else "hold the walls and ")))


## A squad as a row: the captain's face with the troop's badge, its name, its men and
## wounds as chips, and one button.
func _squad_line(sq: Dictionary, verb: String, can: bool, button_name: String, act: Callable, primary: bool = false, heal_time: bool = false) -> Control:
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
	var men := int(sq["men"])
	var wounded := int(sq.get("wounded", 0))
	var chips: Array = [Widgets.stat("men", "%d/%d" % [men, full_size], Style.TEXT if men >= full_size else Style.ENEMY_LIGHT)]
	if wounded > 0:
		chips.append(Widgets.stat("wounded", str(wounded), Style.ENEMY_LIGHT))
		if heal_time:
			chips.append(Widgets.stat("clock", Style.time_short(wounded * 24.0)))
	text.add_child(Widgets.chip_row(chips))
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
	var face_tex: Texture2D = CaptainArt.texture(s["captain"], "", true) if s.get("captain") != null else null
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


## The warband, wounded first, to choose a squad to leave here: in your fief, or with the
## garrison of a crown holding (`holding`). Leaves the page where it was.
func _show_station_sheet(holding: bool = false) -> void:
	if _modal != null and is_instance_valid(_modal):
		_modal.queue_free()
	var col := Widgets.sheet(self, "Station a company", "StationSheet", func(): _modal = null)
	_modal = col.get_parent().get_parent().get_parent().get_parent() as Control
	col.add_child(_note("It holds %s with the garrison. One squad must ride with you." % String(WorldData.settlement(place)["name"])))
	var squads: Array = GameState.army.duplicate()
	squads.sort_custom(func(a, b): return int(a.get("wounded", 0)) > int(b.get("wounded", 0)))
	for sq in squads:
		var sid := int(sq["id"])
		var wounded := int(sq.get("wounded", 0))
		var station := func():
			Widgets.close_sheet(col)
			var ok: bool = GameState.station_in_holding(sid) if holding else GameState.station_squad_in_fief(sid)
			if ok:
				Sound.play("click")
				_build()
		col.add_child(_squad_line(sq, "Station", GameState.army.size() > 1, "Station_%d" % sid, station, wounded > 0, not holding))


## What you've built and could build, each with its picture: the building as the scene at
## the top paints it, in colour once it's built and a grey ghost before.
func _add_manor_card(col: VBoxContainer, fief: Dictionary, is_b: bool) -> void:
	var imps: Dictionary = fief.get("improvements", {})
	var offered: Array = Fiefs.improvements_for(String(WorldData.settlement(String(fief.get("settlement_id", ""))).get("type", WorldData.VILLAGE)))
	var count := 0
	for k in offered:
		if bool(imps.get(k, false)):
			count += 1
	var card := Widgets.card(col, "Manor", "%d of %d built" % [count, offered.size()])
	card.get_parent().name = "ManorCard"
	if is_b:
		var rep_row := HBoxContainer.new()
		rep_row.add_theme_constant_override("separation", 12)
		card.add_child(rep_row)
		var rep_text := _note("Raiders burned it. Rebuild the cottages and the peasants' granaries.", Style.ENEMY_LIGHT)
		rep_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rep_row.add_child(rep_text)
		var rep_btn := _button("Rebuild", func():
			if GameState.repair_fief().get("ok", false):
				Sound.play("coins")
				_build())
		rep_btn.name = "RebuildEstate"
		rep_btn.custom_minimum_size = Vector2(140, Style.TOUCH)
		rep_btn.disabled = GameState.silver < Fiefs.REPAIR_COST
		if not rep_btn.disabled:
			Style.make_primary(rep_btn)
		var rep := Widgets.priced(rep_btn, [["silver", Widgets.thousands(Fiefs.REPAIR_COST), Style.ENEMY_LIGHT if rep_btn.disabled else Style.TEXT]])
		rep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rep_row.add_child(rep)
	# Walls an assault broke mend on their own over a few days; paying mends them now.
	var fid := String(fief.get("settlement_id", ""))
	if GameState.world != null and not SiegeCamp.damage(GameState.world, fid).is_empty():
		var wall_row := HBoxContainer.new()
		wall_row.add_theme_constant_override("separation", 12)
		card.add_child(wall_row)
		var wall_text := _note("Your walls carry the marks of an assault. They mend over a few days, or now for silver.", Style.ENEMY_LIGHT)
		wall_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		wall_row.add_child(wall_text)
		var mend_btn := _button("Mend", func():
			if GameState.repair_fief_walls().get("ok", false):
				Sound.play("coins")
				_build())
		mend_btn.name = "MendWalls"
		mend_btn.custom_minimum_size = Vector2(140, Style.TOUCH)
		mend_btn.disabled = GameState.silver < SiegeCamp.REPAIR_COST
		var priced := Widgets.priced(mend_btn, [["silver", str(SiegeCamp.REPAIR_COST), Style.ENEMY_LIGHT if mend_btn.disabled else Style.TEXT]])
		priced.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		wall_row.add_child(priced)
	for k in offered:
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
		var chip := Widgets.chip("Built", Style.BRASS, "★", "", true)
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
	# The price under the button, red when you're short: it says the cost once.
	var cost := int(idef["cost"])
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
	var stack := Widgets.priced(b, [["silver", Widgets.thousands(cost), Style.ENEMY_LIGHT if b.disabled else Style.TEXT]])
	stack.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(stack)
	return panel


## Giving up the fief is for good, so it asks first.
func _confirm_renounce() -> void:
	if _modal != null and is_instance_valid(_modal):
		_modal.queue_free()
	var s_name := String(WorldData.settlement(place)["name"])
	var realm := GameState.fief_realm()
	var col := Widgets.sheet(self, "Renounce fealty?", "RenounceConfirm", func(): _modal = null)
	_modal = col.get_parent().get_parent().get_parent().get_parent() as Control
	col.add_child(_realm_line(realm, "%s goes back to the crown" % s_name, "It can't be undone.", Style.TEXT))
	var yes := _button("Renounce", func():
		Widgets.close_sheet(col)
		GameState.renounce_fief()
		Sound.play("alarm")
		_build())
	yes.name = "ConfirmRenounce"
	yes.add_theme_stylebox_override("normal", Style.box(Style.ENEMY_DARK, Style.ENEMY, 2))
	yes.add_theme_stylebox_override("hover", Style.box(Style.ENEMY_DARK.lightened(0.08), Style.ENEMY_LIGHT, 2))
	var no := _button("Keep it", func(): Widgets.close_sheet(col))
	no.name = "KeepFief"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(no)
	row.add_child(Widgets.priced(yes, [["bond", "−25", Style.ENEMY_LIGHT]]))
	col.add_child(row)


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
	# Held together (no-break spaces): at big text the count never wraps onto a line alone.
	return {"id": "court", "label": "%s\u00a0·\u00a0%d" % [label, count] if count > 0 else label, "badge": 0, "gold": w.gathering_on(g)}


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
		var wv := Widgets.card(col, "Wedding day", "everything is ready", Style.BRASS, true)
		wv.get_parent().name = "WeddingCard"
		var wl := HBoxContainer.new()
		wl.add_theme_constant_override("separation", 12)
		var rings := Widgets.icon_rect("rings", 40)
		rings.modulate = Style.ROMANCE
		wl.add_child(rings)
		var wn := Style.label(who, Style.BODY, Style.ROMANCE_LIGHT)
		wn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		wn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		wl.add_child(wn)
		wv.add_child(wl)
		var wb := _button("Begin the wedding", func():
			_remember_scroll()
			Scenes.wedding_replay = ""
			Scenes.wedding_return = "res://scenes/settlement.tscn"
			Scenes.go("res://scenes/wedding.tscn"))
		wb.name = "BeginWedding"
		Style.make_primary(wb)
		wv.add_child(wb)
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
		# What a toast, a gift or a speech just did shows itself once.
		if _court_note != _court_note_shown:
			Widgets.flash_soon(n)
	_court_note_shown = _court_note
	var here: Array = GameState.gathering_lords(g) if on else _hall_lords()
	# The tab already counts who's here.
	var hall := Widgets.card(col, "In the hall")
	hall.get_parent().name = "HallCard"
	var list := VBoxContainer.new()
	list.name = "Hall"
	list.add_theme_constant_override("separation", 10)
	hall.add_child(list)
	for l in here:
		list.add_child(_lord_row(l, g if on else {}))
	for person in residents:
		list.add_child(_household_row(person))
	if here.is_empty() and residents.is_empty():
		list.add_child(_note("The hall is quiet. A steward keeps the fire; the lords are out on the roads."))
	# Who's away: the holder, out on their lands.
	var holder: Dictionary = w.holder_lord(place)
	if not holder.is_empty() and not here.has(holder):
		hall.add_child(Widgets.section("Away"))
		hall.add_child(_away_row(holder))
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
	var v := Widgets.card(col, "", "", Style.MUTED, true)
	v.get_parent().name = "Gathering"
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	var kind_icon := Widgets.icon_rect(GATHERING_ICONS.get(String(g.get("kind", "")), "lantern"), 34)
	kind_icon.modulate = Style.BRASS
	top.add_child(kind_icon)
	var title := Style.label(GameState.gathering_title(g), Style.BODY, Color("f3d891"))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	v.add_child(top)
	var inv: Dictionary = GameState.gathering_invite(g)
	var lords_n: int = GameState.gathering_lords(g).size() if on else w.gathering_guests(g).size()
	var mine: bool = GameState.gathering_is_mine(g)
	if mine:
		top.add_child(CourtUI.round_button("?", func(): CourtUI.open_rules(self, Style.safe_insets(get_viewport())), "Rules"))
	# When, how many, and on what footing you're here, as chips.
	var chips: Array = [Widgets.chip(Gatherings.upper_first(GameState.gathering_when(g)), Style.TEXT, "", "moon"),
		Widgets.stat("men", "%d %s" % [lords_n, "here" if on else "coming"])]
	if mine:
		chips.append(Widgets.chip("Your own", Style.BRASS, "", "crown", true))
		var host_l: Dictionary = w.lord_by_id(int(g.get("host_lord", -1))) if int(g.get("host_lord", -1)) >= 0 else {}
		if not host_l.is_empty():
			chips.append(Widgets.chip("%s's hall" % LordTalk.short_name(host_l), Style.TEXT, "", "keep"))
	elif bool(inv["invited"]):
		chips.append(Widgets.chip("Invited", Style.MORALE_HIGH))
	else:
		chips.append(Widgets.chip("Uninvited", Style.MORALE_MID))
	var chip_row := Widgets.chip_row(chips)
	chip_row.name = "GatheringChips"
	v.add_child(chip_row)
	if not mine and bool(inv["invited"]) and String(inv.get("why", "")) != "":
		v.add_child(_note(Gatherings.upper_first(String(inv["why"])), Color("e8d9b0")))
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
		acts.add_child(_feast_action("Speech", "Speech", "crown", [["renown", "+%d" % Gatherings.SPEECH_RENOWN]], String(sp["reason"]),
			bool(sp["ok"]), func():
				var r: Dictionary = CrownCourt.speech(GameState)
				if bool(r.get("ok", false)):
					Sound.play("horn")
					_court_note = String(r["text"])
				_build()))
		var gc: Dictionary = CrownCourt.gifts_check(GameState)
		acts.add_child(_feast_action("KingGifts", "Gifts", "chest", [["silver", "−%d" % int(gc.get("cost", 0))]], String(gc["reason"]),
			bool(gc["ok"]), func():
				var r: Dictionary = CrownCourt.give_gifts(GameState)
				if bool(r.get("ok", false)):
					Sound.play("coins")
					_court_note = String(r["text"])
				_build()))
	else:
		var toast: Dictionary = GameState.toast_check(g)
		acts.add_child(_feast_action("Toast", "Toast", "cup", [["renown", "+%d" % Gatherings.TOAST_RENOWN]], String(toast["reason"]),
			bool(toast["ok"]), func():
				var r: Dictionary = GameState.raise_toast(g)
				if bool(r.get("ok", false)):
					Sound.play("horn")
					_court_note = "%s +%d Regard with %d lord%s." % [String(r["text"]), Gatherings.TOAST_REGARD, int(r["lords"]), "" if int(r["lords"]) == 1 else "s"]
				_build()))
	var gift: Dictionary = GameState.gift_check(g)
	if not mine:
		var in_silver := String(gift.get("what", "silver")) == "silver"
		var gift_cost: Array = [["silver" if in_silver else "food", "−%d" % (Gatherings.GIFT_SILVER if in_silver else Gatherings.GIFT_FOOD)],
			["bond", "+%d" % Gatherings.GIFT_REGARD]]
		acts.add_child(_feast_action("Gift", "Gift", "silver" if in_silver else "food", gift_cost, String(gift["reason"]), bool(gift["ok"]), func():
			var r: Dictionary = GameState.bring_gift(g)
			if bool(r.get("ok", false)):
				Sound.play("coins")
				_court_note = "%s %s +%d Regard; %s +%d." % [String(r["text"]), GameState.gathering_host_name(g), Gatherings.GIFT_REGARD,
					GameState.realm_word(String(g["realm"])), Gatherings.GIFT_REALM]
			_build()))
	var gossip: Dictionary = GameState.gossip_check(g)
	acts.add_child(_feast_action("Gossip", "Gossip", "talk", [["clock", "1 h"]], String(gossip["reason"]),
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
		var db := _button("Dance", func():
			_remember_scroll()
			Scenes.dance_return = "res://scenes/settlement.tscn"
			Scenes.go("res://scenes/dance.tscn"))
		db.name = "Dance"
		_with_icon(db, "dance")
		Style.make_primary(db)
		v.add_child(db)
	elif String(dance["reason"]) != "it hasn't begun":
		v.add_child(_note("Dancing: %s." % String(dance["reason"]), Style.MUTED))


## Each kind of gathering's icon.
const GATHERING_ICONS := {"feast": "cup", "dance": "dance", "tourney": "fight"}


## One of the feast's things to do: a tall button with its icon and word, and under them
## what it costs or brings as icons and numbers, or why not.
func _feast_action(id: String, text: String, icon_key: String, marks: Array, why_not: String, ok: bool, act: Callable) -> Button:
	var b := Button.new()
	b.name = "Feast_" + id
	b.disabled = not ok
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 132)
	var box := Style.box(Color("2a2010") if ok else Color(Style.NIGHT, 0.5), Color("8a6a2a") if ok else Style.RULE, 2, 14)
	box.content_margin_left = 8
	box.content_margin_right = 8
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(state, box)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 6
	v.offset_right = -6
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 4)
	var ic := Widgets.icon_rect(icon_key, 32)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if not ok:
		ic.modulate = Color(1, 1, 1, 0.4)
	v.add_child(ic)
	var t := Style.label(text, Style.SMALL, Style.TEXT if ok else Style.MUTED)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(t)
	if ok:
		var row := HFlowContainer.new()
		row.name = "Marks"
		row.alignment = FlowContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("h_separation", 10)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for m in marks:
			row.add_child(Widgets.icon_value(String(m[0]), String(m[1]), Color("cdbf9c")))
		v.add_child(row)
	else:
		var st := Style.label(why_not, Style.SMALL, Style.MUTED)
		st.name = "WhyNot"
		st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		st.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(st)
	b.add_child(v)
	b.pressed.connect(act)
	# The thing just done glows on the page that comes back.
	var tile_name := String(b.name)
	b.pressed.connect(func(): _flash_named.call_deferred(tile_name))
	return b


## Your crown's own gathering here: a feast, a dance or a tourney, and who to ask. (The
## Crown screen's Court tab calls one anywhere.) What it's worth is on the rules sheet.
func _add_host_card(col: VBoxContainer) -> void:
	var w = GameState.world
	var mine: Dictionary = w.gathering_of_realm(WorldData.CROWN)
	var v := Widgets.card(col, "Hold a gathering here")
	v.get_parent().name = "HostCard"
	if not mine.is_empty():
		var n: int = w.gathering_guests(mine).size()
		v.add_child(_note("Your %s at %s · %s · %d coming" % [String(mine["name"]), WorldData.settlement(String(mine["place"]))["name"],
			GameState.gathering_when(mine), n], Style.BRASS))
		return
	var kinds := [Gatherings.FEAST, Gatherings.DANCE, Gatherings.TOURNEY]
	var kind: String = kinds[clampi(_host_kind, 0, 2)]
	var host: Dictionary = GameState.host_lord_at(place)
	var kind_row := HBoxContainer.new()
	kind_row.add_theme_constant_override("separation", 10)
	v.add_child(kind_row)
	var kinds_bar := Widgets.segmented(["Feast", "Dance", "Tourney"], _host_kind, func(i: int):
		_host_kind = i
		_build(), "HostKind", ["cup", "dance", "fight"])
	kinds_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kind_row.add_child(kinds_bar)
	# What a gathering's worth, behind one icon.
	var how := Widgets.icon_button("book", func(): CourtUI.open_rules(self, Style.safe_insets(get_viewport())), "How the king's court works", "CourtRules")
	kind_row.add_child(how)
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
	var tiles: Array = [Widgets.tile("silver", "−%s" % Widgets.thousands(Gatherings.HOST_SILVER), "the hall"),
		Widgets.tile("food", "−%s" % Widgets.thousands(Gatherings.HOST_FOOD), "rations")]
	if kind == Gatherings.TOURNEY:
		tiles.append(Widgets.tile("silver", Widgets.thousands(Gatherings.TOURNEY_PURSE), "the purse"))
	tiles.append(Widgets.tile("moon", "3", "nights"))
	var cost_grid := Widgets.tile_grid(tiles, 2)
	cost_grid.name = "HostCosts"
	v.add_child(cost_grid)
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


## Your banners gathering here: who's in the hall, and the council once it can sit.
func _add_muster_card(col: VBoxContainer) -> void:
	var here: Array = CrownCourt.arrived(GameState)
	var all: Array = CrownCourt.muster_lords(GameState)
	var v := Widgets.card(col, "Your banners gather here")
	v.get_parent().name = "MusterCard"
	v.add_child(Widgets.chip_row([Widgets.stat("crown", "%d of %d lords here" % [here.size(), all.size()]),
		Widgets.chip("−%d/day from the treasury" % CrownCourt.muster_upkeep(GameState), Style.TEXT, "", "chest")]))
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
		var honour_head := HBoxContainer.new()
		honour_head.add_theme_constant_override("separation", 10)
		var hl := Widgets.section("Seat of honour")
		hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		honour_head.add_child(hl)
		honour_head.add_child(Widgets.effect("bond", Gatherings.HONOUR_REGARD))
		box.add_child(honour_head)
		var strip := HBoxContainer.new()
		strip.add_theme_constant_override("separation", 4)
		for l in lords.slice(0, 5):
			var lid := int(l["id"])
			strip.add_child(CourtUI.face_button(CaptainArt.texture(LordVoice.portrait_record(l)), LordTalk.first_name(l), "Honour_%d" % lid, func():
				var r: Dictionary = CrownCourt.honour(GameState, lid)
				if bool(r.get("ok", false)):
					_court_note = String(r["text"])
				_build(), true, 56.0, lid))
		box.add_child(strip)
	var asks: Array = CrownCourt.petitions(GameState).filter(func(p): return lords.has(p["lord"]))
	if not asks.is_empty():
		box.add_child(Widgets.section("Petitions"))
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
		var ok := _button(String(p["settle"]), func():
			var r: Dictionary = CrownCourt.answer(GameState, pl, true)
			_court_note = String(r.get("text", r.get("reason", "")))
			_build())
		ok.name = "Hear_%d" % int(p["lord"]["id"])
		ok.autowrap_mode = TextServer.AUTOWRAP_OFF
		ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ok.size_flags_stretch_ratio = 2.0
		Style.make_primary(ok)
		f.add_child(Widgets.priced(ok, [["bond", "+%d" % (Gatherings.PUBLIC_GRANT_REGARD if String(p["kind"]) == "fief" else Gatherings.PETITION_TABLE), Style.MORALE_HIGH]]))
		if bool(p["refuse"]):
			var no := _button("Refuse", func():
				var r: Dictionary = CrownCourt.answer(GameState, pl, false)
				_court_note = String(r.get("text", ""))
				_build())
			no.name = "RefuseHere_%d" % int(p["lord"]["id"])
			no.autowrap_mode = TextServer.AUTOWRAP_OFF
			no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			f.add_child(Widgets.priced(no, [["bond", _signed(Gatherings.PETITION_REFUSED), Style.ENEMY_LIGHT]]))
		words.add_child(f)
		row.add_child(words)
		box.add_child(row)
	if String(g.get("kind", "")) == Gatherings.TOURNEY:
		_add_lists(box, g)


## The tourney's lists: tap up to three of your captains' faces, then ride. After, who won,
## with every bout folded away under it.
func _add_lists(box: VBoxContainer, g: Dictionary) -> void:
	var done: Dictionary = GameState.hosted.get("tourney", {})
	var lists_head := HBoxContainer.new()
	lists_head.add_theme_constant_override("separation", 10)
	var lh := Widgets.section("The lists")
	lh.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lists_head.add_child(lh)
	lists_head.add_child(Widgets.stat("silver", "purse %s" % Widgets.thousands(Gatherings.TOURNEY_PURSE)))
	box.add_child(lists_head)
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
				_bouts_fresh = _bouts_open
				_build())
			bouts.name = "ListsBouts"
			res.add_child(bouts)
			if _bouts_open:
				# Opened just now, the bouts are read out one after another.
				var k := 0
				for line in lines.slice(0, lines.size() - 1):
					var bout := _note(String(line), Color("e8d9b0"))
					bout.name = "Bout_%d" % k
					res.add_child(bout)
					if _bouts_fresh and not Style.motion_reduced():
						bout.modulate.a = 0.0
						bout.create_tween().tween_property(bout, "modulate:a", 1.0, 0.2).set_delay(minf(0.07 * k, 1.2))
					k += 1
				_bouts_fresh = false
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
		strip.add_child(CourtUI.face_button(CaptainArt.texture(c, "", true), name, "Ride_%d" % sid, func():
			if _lists_pick.has(sid):
				_lists_pick.erase(sid)
			elif _lists_pick.size() < Gatherings.TOURNEY_CAPTAINS:
				_lists_pick.append(sid)
			_build(), _lists_pick.has(sid), 56.0))
	box.add_child(strip)
	box.add_child(_note("%d of %d ride · tap a face" % [_lists_pick.size(), Gatherings.TOURNEY_CAPTAINS]))
	var go := _button("Ride the lists", func():
		var r: Dictionary = CrownCourt.ride_tourney(GameState, _lists_pick)
		var rode := bool(r.get("ok", false))
		if rode:
			Sound.play("horn")
			_bouts_open = false
			# How it ended drops in as a ribbon, and the result shows itself on the page.
			var told: Array = (GameState.hosted.get("tourney", {}) as Dictionary).get("lines", [])
			if not told.is_empty():
				Scenes.ribbon("The lists are run", String(told[-1]), "fight", "")
		_lists_ridden(rode))
	go.name = "RideLists"
	go.disabled = not bool(check["ok"]) or _lists_pick.is_empty()
	if not go.disabled:
		Style.make_primary(go)
	box.add_child(go)
	if not bool(check["ok"]):
		box.add_child(_note(String(check["reason"]), Style.MUTED))


## The page after the lists: rebuilt, with their result showing itself if they were ridden.
func _lists_ridden(rode: bool) -> void:
	_build()
	if rode:
		_flash_named.call_deferred("ListsResult")


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
## when there's something in it for you, and a chip (their Regard, Sworn, a heart).
## Tapping opens the talk.
func _person_row(row_name: String, face: Texture2D, who: String, doing: String, tag: String, tag_tone: Color,
		chip: Control, act: Callable, faded: bool = false) -> Button:
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
	if chip != null:
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(chip)
	b.pressed.connect(act)
	return b


func _lord_row(l: Dictionary, g: Dictionary) -> Button:
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
	# The same Regard chip as the talk: the bond mark and a signed number.
	var chip: Control = Widgets.chip("Sworn", Style.BRASS, "", "crown", true) if sworn else Widgets.stat("bond", _signed(regard), tone)
	chip.name = "RegardChip"
	return _person_row("Lord_%d" % lid, CaptainArt.texture(LordVoice.portrait_record(l)), who, _doing_here(l), tag, tag_tone,
		chip, _open_lord_talk.bind(lid))


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
	var heart := Widgets.chip(Relationships.status_label(status), Style.ROMANCE, "", "rings" if status in ["engaged", "married"] else "heart")
	var b := _person_row("Person_%s" % cid, tex, String(person.get("name", "Noble")), String(person.get("role", "")), tag, Style.ROMANCE_LIGHT,
		heart, func():
			_remember_scroll()
			Scenes.active_candidate_id = cid
			Scenes.active_person_id = String(person.get("id", ""))
			Scenes.conversation_return = "res://scenes/settlement.tscn"
			Scenes.go("res://scenes/conversation.tscn"))
	var pic := b.get_child(0).get_child(0) as TextureRect
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	return b


func _away_row(l: Dictionary) -> Button:
	var where := _lord_whereabouts(l)
	var on_map := String(where["place"]) != ""
	var map_chip: Control = null
	if on_map:
		map_chip = Widgets.chip("On the map", Style.TEXT, "", "mappin")
	var b := _person_row("Away_%d" % int(l["id"]), CaptainArt.texture(LordVoice.portrait_record(l)), LordTalk.short_name(l),
		"%s · %s" % ["Rules from here" if bool(l.get("ruler", false)) else "Holds %s" % WorldData.settlement(place)["name"], String(where["text"])],
		"", Style.MUTED, map_chip, func():
			if on_map:
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
	var card := Widgets.card(col, "Provisions", "%.1f a ration" % price)
	card.get_parent().name = "ProvisionsCard"
	var hint := "A ration per man a day" + (" · villages sell cheaper" if kind != WorldData.VILLAGE else " · cheapest here")
	card.add_child(_note(hint))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	for d in FOOD_DAYS:
		var rations: int = d * men
		var cost := GameState.food_cost(rations)
		var b := _button("+%d days" % d, _on_buy_food.bind(rations))
		b.name = "Food%d" % d
		_with_icon(b, "food")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", Style.text_size(Style.BODY))
		b.disabled = men == 0 or cost > GameState.silver
		row.add_child(Widgets.priced(b, [["silver", Widgets.thousands(cost), Style.ENEMY_LIGHT if cost > GameState.silver else Style.TEXT]]))


func _add_recruits(col: VBoxContainer) -> void:
	var cap := GameState.squad_cap()
	var full := GameState.army.size() >= cap
	var card := Widgets.card(col, "Recruits here", "%d/%d companies" % [GameState.army.size(), cap],
		Style.ENEMY_LIGHT if full else Style.MUTED)
	card.get_parent().name = "RecruitsCard"
	var offers: Array = GameState.world.offers_at(place)
	for i in offers.size():
		card.add_child(_offer_row(offers[i], i, full))
	if offers.is_empty():
		var back: float = float(GameState.world.offers_back.get(place, GameState.world.hour)) - GameState.world.hour
		card.add_child(Widgets.chip_row([Widgets.chip("No one looking for work · more in %s" % Style.time_short(maxf(1.0, ceil(back))), Style.TEXT, "", "clock")]))
	elif full:
		card.add_child(_note("Your warband is full. Win renown to lead more companies.", Style.ENEMY_LIGHT))


func _add_tavern_heroes(col: VBoxContainer) -> void:
	var heroes: Array = GameState.available_heroes_at(place)
	if heroes.is_empty():
		return
	var card := Widgets.card(col, "In the tavern", "", Style.MUTED, true)
	card.get_parent().name = "TavernCard"
	for hero in heroes:
		card.add_child(_hero_row(hero))


## A wanderer you could take on: their face, name and what they lead, the price under the
## verb, and their story behind a tap.
func _hero_row(hero: Dictionary) -> Control:
	var hid := String(hero.get("id", ""))
	var name_str := String(hero.get("name", "Hero"))
	var cost := int(hero.get("cost", 250))
	var type := String(hero.get("type", Troops.INFANTRY))
	var cult := String(hero.get("culture", Cultures.VARDISH))
	var spec := String(hero.get("specialization", ""))
	var v := VBoxContainer.new()
	v.name = "Hero_%s" % hid
	v.add_theme_constant_override("separation", 8)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	v.add_child(head)
	var face_tex: Texture2D = CaptainArt.texture(hero, "", true)
	if face_tex != null:
		var pic := TextureRect.new()
		pic.texture = face_tex
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		head.add_child(Widgets.framed(pic, Vector2(72, 90)))
	else:
		head.add_child(_portrait(type, cult))

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.add_theme_constant_override("separation", 4)
	head.add_child(text)
	text.add_child(Style.label(name_str, Style.BODY, Style.BRASS))
	var unit_badge := _portrait(String(hero.get("unit", type)) if String(hero.get("unit", "")) != "" else type, cult)
	unit_badge.custom_minimum_size = Vector2(30, 30)
	var role := HBoxContainer.new()
	role.add_theme_constant_override("separation", 8)
	role.add_child(unit_badge)
	var role_words := _small("%s · %s" % [Units.troop_name({"unit": hero.get("unit", "")}, cult), spec.capitalize()], Style.TEXT)
	role_words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	role.add_child(role_words)
	text.add_child(role)

	var can_hire: bool = GameState.silver >= cost and GameState.army.size() < GameState.squad_cap()
	var hire_btn := _button("Recruit", func():
		if GameState.recruit_hero(hid):
			Sound.play("charge")
			# They're seen to join: their face on a ribbon, and the Squads tab they went to glows.
			Scenes.ribbon_face("%s joins the company" % name_str, "%s · %s" % [Units.troop_name({"unit": hero.get("unit", "")}, cult), spec.capitalize()], face_tex, "")
			_build()
			_flash_named.call_deferred("Tab_squads")
	)
	hire_btn.name = "Recruit_%s" % hid
	hire_btn.custom_minimum_size = Vector2(150, Style.TOUCH)
	hire_btn.disabled = not can_hire
	if can_hire:
		Style.make_primary(hire_btn)
	var priced := Widgets.priced(hire_btn, [["silver", Widgets.thousands(cost), Style.ENEMY_LIGHT if GameState.silver < cost else Style.TEXT]])
	priced.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(priced)

	# Who they are and what they say, folded away until asked for.
	var story := VBoxContainer.new()
	story.name = "Story"
	story.add_theme_constant_override("separation", 6)
	story.visible = false
	var bio := _note(String(hero.get("bio", "")), Style.MUTED)
	story.add_child(bio)
	var quote := _note("\"%s\"" % String(hero.get("dialogue", "")), Style.TEXT)
	story.add_child(quote)
	var more := Button.new()
	more.name = "HeroStory"
	more.text = "Their story"
	more.flat = true
	_with_icon(more, "book")
	more.custom_minimum_size = Vector2(0, Style.TOUCH)
	more.alignment = HORIZONTAL_ALIGNMENT_LEFT
	more.add_theme_font_size_override("font_size", Style.text_size(Style.SMALL))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		more.add_theme_color_override(c, Style.MUTED)
	more.pressed.connect(func():
		story.visible = not story.visible
		more.text = "Hide their story" if story.visible else "Their story")
	v.add_child(more)
	v.add_child(story)
	return v


## What each kind of job is, as an icon.
const JOB_ICONS := {Jobs.TYPE_HUNT: "skull", Jobs.TYPE_COURIER: "mail", Jobs.TYPE_RELIEF: "food"}


func _add_local_jobs(col: VBoxContainer) -> void:
	var w = GameState.world
	if w == null:
		return

	# Deliveries ready for turn-in
	var deliverable: Array = GameState.active_jobs_completable_at(place)
	if not deliverable.is_empty():
		var ready := Widgets.card(col, "Ready to claim", "", Style.MUTED, true)
		ready.get_parent().name = "DeliveriesCard"
		for job in deliverable:
			ready.add_child(_deliverable_job_card(job))

	# Notice board offers
	var active_count: int = GameState.contract_count()
	var capped := active_count >= Jobs.MAX_ACTIVE_JOBS
	var board := Widgets.card(col, "Notice board", "%d of %d taken" % [active_count, Jobs.MAX_ACTIVE_JOBS],
		Style.ENEMY_LIGHT if capped else Style.MUTED)
	board.get_parent().name = "NoticeBoard"
	var offers: Array = GameState.jobs_at(place)
	if offers.is_empty():
		board.add_child(_note("Nothing posted. Notices go up every few days."))
	else:
		for i in offers.size():
			board.add_child(_job_offer_card(offers[i], i, capped))
		if capped:
			board.add_child(_note("Your journal is full. Finish a contract to take another."))


## The rewards a job pays, as chips: silver, renown and standing, and the rations a
## relief job takes from you.
func _job_chips(job: Dictionary) -> Array:
	var chips: Array = []
	if int(job.get("reward_silver", 0)) != 0:
		chips.append(Widgets.effect("silver", int(job.get("reward_silver", 0))))
	if int(job.get("reward_renown", 0)) != 0:
		chips.append(Widgets.effect("renown", int(job.get("reward_renown", 0))))
	if int(job.get("reward_relation", 0)) != 0:
		chips.append(Widgets.effect("bond", int(job.get("reward_relation", 0))))
	if String(job.get("type", "")) == Jobs.TYPE_RELIEF and int(job.get("food_needed", 0)) > 0:
		chips.append(Widgets.effect("food", -int(job.get("food_needed", 0))))
	return chips


## A job as a row: its kind as an icon, its title and first line, its terms as chips,
## and one verb.
func _job_row(job: Dictionary, chips: Array, button: Button) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var badge := PanelContainer.new()
	var bb := Style.box(Color("1a2138"), Style.RULE, 2, 14)
	bb.set_content_margin_all(10)
	badge.add_theme_stylebox_override("panel", bb)
	badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	badge.add_child(Widgets.icon_rect(String(JOB_ICONS.get(String(job.get("type", "")), "journal")), 40))
	row.add_child(badge)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 4)
	row.add_child(text)
	var title := Style.label(String(job.get("title", "Contract")), Style.BODY, Style.TEXT)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(title)
	var desc := String(job.get("description", ""))
	var first := desc.split(". ")[0]
	if first.length() < desc.length() and not first.ends_with("."):
		first += "."
	if first != "":
		text.add_child(_note(first))
	text.add_child(Widgets.chip_row(chips))
	button.custom_minimum_size = Vector2(150, Style.TOUCH)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(button)
	return row


func _deliverable_job_card(job: Dictionary) -> Control:
	var jid: String = String(job.get("id", ""))
	var claim_btn := _button("Claim", func():
		var res: Dictionary = GameState.complete_job(jid)
		if res.get("ok", false):
			_paid(true)
	)
	claim_btn.name = "ClaimJob_%s" % jid
	Style.make_primary(claim_btn)
	return _job_row(job, _job_chips(job), claim_btn)


func _job_offer_card(job: Dictionary, index: int, is_capped: bool) -> Control:
	var hrs_left: float = maxf(0.0, float(job.get("deadline", 0.0)) - (GameState.world.hour if GameState.world != null else 0.0))
	var chips: Array = [Widgets.stat("clock", Style.time_short(hrs_left))]
	chips.append_array(_job_chips(job))
	var accept_btn := _button("Accept", func():
		if GameState.accept_job(place, index):
			Sound.play("coins")
			_build()
	)
	accept_btn.name = "AcceptJob_%d" % index
	accept_btn.disabled = is_capped
	if not is_capped:
		Style.make_primary(accept_btn)
	return _job_row(job, chips, accept_btn)


func _offer_row(offer: Dictionary, index: int, full: bool) -> Control:
	var type := String(offer["type"])
	var culture := String(offer["culture"])
	var men := Troops.full_size(type)
	var cost := Economy.recruit_cost(type, men)
	var wage := Economy.daily_wage({"type": type, "men": men, "level": 1})
	var row := HBoxContainer.new()
	row.name = "Offer_%d" % index
	row.add_theme_constant_override("separation", 14)
	row.add_child(_portrait(type, culture))
	var text := _text_column(row)
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.add_child(Style.label(Cultures.troop_name(culture, type), Style.BODY))
	# What it adds to the wages, and how many days of pay the purse holds after the hire.
	var offer_chips: Array = [Widgets.stat("men", str(men)), Widgets.effect("silver", -int(ceil(wage)), "/day")]
	var tight := _hire_is_tight(cost)
	if cost <= GameState.silver:
		var days_after := _pay_days_after_hire(cost, wage)
		# Short enough for the row's narrow column at the largest text.
		var pay_left := Widgets.stat("clock", "%d %s pay after" % [days_after, "day's" if days_after == 1 else "days'"],
			Style.ENEMY_LIGHT if tight else Style.TEXT)
		pay_left.name = "PayLeft"
		offer_chips.append(pay_left)
	text.add_child(Widgets.chip_row(offer_chips))
	var b := _button("Hire", _on_hire.bind(index))
	b.name = "Hire_%d" % index
	b.custom_minimum_size = Vector2(150, Style.TOUCH)
	b.disabled = full or cost > GameState.silver
	# A hire that leaves under two days of wages still works, but asks first and isn't lit.
	if not b.disabled and not tight:
		Style.make_primary(b)
	var priced := Widgets.priced(b, [["silver", Widgets.thousands(cost), Style.ENEMY_LIGHT if cost > GameState.silver else Style.TEXT]])
	priced.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(priced)
	return row


func _add_squads(col: VBoxContainer) -> void:
	var card := Widgets.card(col, "Your companies", "%d men" % GameState.total_men())
	card.get_parent().name = "SquadsCard"
	if not GameState.in_town():
		card.add_child(_note("Ride to a town to refill and train your companies."))
		for s in GameState.army:
			card.add_child(_squad_row(s, false))
		return
	card.add_child(_note("Fresh men water down experience, never a level earned · training raises wages"))
	var total := 0
	var cheapest := 0
	for s in GameState.army:
		var cost := GameState.reinforce_cost(s)
		total += cost
		if cost > 0 and (cheapest == 0 or cost < cheapest):
			cheapest = cost
		card.add_child(_squad_row(s, true))
	if total > 0:
		var all := _button("Reinforce all", _on_reinforce_all)
		all.name = "ReinforceAll"
		all.disabled = cheapest > GameState.silver
		if not all.disabled:
			Style.make_primary(all)
		all.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_child(Widgets.priced(all, [["silver", Widgets.thousands(total), Style.ENEMY_LIGHT if total > GameState.silver else Style.TEXT]]))


## A squad in town: its face, name, men as a meter, level as pips and drill as a meter,
## then Refill and Train with their prices under them.
func _squad_row(s: Dictionary, in_town: bool = true) -> Control:
	var type := String(s["type"])
	var unit_id := String(s.get("unit", ""))
	var full := Units.full_size(unit_id) if Units.has(unit_id) else Troops.full_size(type)
	var men := int(s["men"])
	var level := int(s.get("level", 1))
	var xp := int(s["xp"])
	var panel := PanelContainer.new()
	panel.name = "Squad_%d" % int(s["id"])
	var pb := Style.box(Style.NIGHT, Style.RULE, 2, 14)
	pb.content_margin_left = 12
	pb.content_margin_right = 12
	pb.content_margin_top = 10
	pb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", pb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	# The captain's face, as in the Warband, with the troop's own icon at its corner.
	row.add_child(_squad_art(s))
	var text := _text_column(row)
	text.add_theme_constant_override("separation", 6)
	var title := String(s.get("name", ""))
	var name_label := Style.label(title if title != "" else Units.troop_name(s, GameState.culture), Style.BODY)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.custom_minimum_size = Vector2(10, 0)
	text.add_child(name_label)
	# Men: the number and a meter, red when short.
	var men_line := HBoxContainer.new()
	men_line.add_theme_constant_override("separation", 10)
	men_line.add_child(Widgets.icon_value("men", "%d/%d" % [men, full], Style.TEXT if men >= full else Style.ENEMY_LIGHT))
	var men_bar := Widgets.meter(float(men) / maxf(1.0, float(full)), Style.MORALE_HIGH if men >= full else Style.MORALE_LOW, 12.0)
	men_bar.name = "MenMeter"
	men_line.add_child(men_bar)
	text.add_child(men_line)
	# Level as pips, and drill toward the next as a meter (or a chip when it's done).
	var lvl_line := HBoxContainer.new()
	lvl_line.add_theme_constant_override("separation", 10)
	lvl_line.add_child(Widgets.icon_rect("level", 26))
	lvl_line.add_child(_pips(level, Troops.MAX_LEVEL))
	if level >= Troops.MAX_LEVEL:
		lvl_line.add_child(_small("Fully trained"))
	elif GameState.can_train(s):
		lvl_line.add_child(Widgets.chip("Ready to train", Style.MORALE_HIGH))
	else:
		var need := level * Troops.XP_PER_LEVEL
		var xp_bar := Widgets.meter(float(xp) / maxf(1.0, float(need)), Style.BRASS, 12.0)
		xp_bar.name = "XpMeter"
		xp_bar.tooltip_text = "%d/%d xp" % [xp, need]
		lvl_line.add_child(xp_bar)
	text.add_child(lvl_line)
	if not in_town:
		return panel
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	var refill := GameState.reinforce_cost(s)
	if refill > 0:
		var b := _button("Refill", _on_reinforce.bind(int(s["id"])))
		b.name = "Refill_%d" % int(s["id"])
		_with_icon(b, "men")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = refill > GameState.silver
		buttons.add_child(Widgets.priced(b, [["silver", Widgets.thousands(refill), Style.ENEMY_LIGHT if b.disabled else Style.TEXT]]))
	if GameState.can_train(s):
		# Training a recruit squad makes it one of two branches, each with its own price.
		var branches := Units.branches(unit_id)
		var choosing: bool = (level == 1 or bool(s.get("pending_branch", false))) and not branches.is_empty()
		var price: int = 0 if bool(s.get("pending_branch", false)) else Economy.train_cost(s)
		if choosing and not s.get("pending_branch", false):
			price = Economy.train_cost(s, branches[0])
			for br in branches:
				price = mini(price, Economy.train_cost(s, br))
		var t := _button("Choose a path…" if choosing else "Train", _on_train.bind(int(s["id"])))
		t.name = "Train_%d" % int(s["id"])
		_with_icon(t, "level")
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.disabled = price > GameState.silver
		var price_text := "free" if price == 0 else ("from %s" % Widgets.thousands(price) if choosing else Widgets.thousands(price))
		buttons.add_child(Widgets.priced(t, [["silver", price_text, Style.ENEMY_LIGHT if t.disabled else Style.TEXT]]))
	if buttons.get_child_count() > 0:
		v.add_child(buttons)
	return panel


## `n` of `of` pips, lit in brass: a squad's level.
func _pips(n: int, of: int) -> Control:
	var c := Control.new()
	c.name = "LevelPips"
	c.custom_minimum_size = Vector2(of * 22, 22)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.tooltip_text = "Level %d of %d" % [n, of]
	c.draw.connect(func():
		for i in of:
			var at := Vector2(11 + i * 22, c.size.y / 2.0)
			if i < n:
				c.draw_circle(at, 8.0, Style.BRASS)
			else:
				c.draw_arc(at, 7.0, 0.0, TAU, 20, Style.RULE, 2.0, true))
	return c


# ---------------------------------------------------------------- pieces

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


## Puts an icon beside a button's word, kept to the size of the text.
func _with_icon(b: Button, key: String) -> void:
	b.icon = Widgets.icon(key)
	b.add_theme_constant_override("icon_max_width", 30)
	b.add_theme_constant_override("h_separation", 10)


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


## Whether paying `cost` leaves less than two days of the warband's wages in the purse.
func _hire_is_tight(cost: int) -> bool:
	return GameState.silver - cost < 2 * GameState.daily_outgoings()


## Whole days of wages the purse holds after a hire, counting the new company's pay.
func _pay_days_after_hire(cost: int, wage: float) -> int:
	var wages_after: int = GameState.daily_outgoings() + int(ceil(wage))
	return maxi(0, GameState.silver - cost) / maxi(1, wages_after)


func _on_hire(index: int) -> void:
	var offers: Array = GameState.world.offers_at(place)
	if index >= 0 and index < offers.size():
		var offer: Dictionary = offers[index]
		var type := String(offer["type"])
		var cost := Economy.recruit_cost(type, Troops.full_size(type))
		if cost <= GameState.silver and _hire_is_tight(cost):
			_confirm_hire(index, cost, _pay_days_after_hire(cost, Economy.daily_wage({"type": type, "men": Troops.full_size(type), "level": 1})))
			return
	_hire_now(index)


func _hire_now(index: int) -> void:
	# The new company joins the Companies tab, so that's what glows: where it went.
	_paid(GameState.hire(place, index), "coins", "Tab_squads")


## A hire that would leave under two days of wages: say so, and let the player choose.
func _confirm_hire(index: int, cost: int, days_after: int) -> void:
	if _modal != null and is_instance_valid(_modal):
		_modal.queue_free()
	var col := Widgets.sheet(self, "Hire with a thin purse?", "HireConfirm", func(): _modal = null)
	_modal = col.get_parent().get_parent().get_parent().get_parent() as Control
	col.add_child(_note("After paying %s silver, the purse holds %d %s of wages. Unpaid men leave the warband." % [
		Widgets.thousands(cost), days_after, "day" if days_after == 1 else "days"], Style.TEXT))
	var yes := _button("Hire anyway", func():
		Widgets.close_sheet(col)
		_hire_now(index))
	yes.name = "ConfirmHire"
	var no := _button("Keep the silver", func(): Widgets.close_sheet(col))
	no.name = "KeepSilver"
	Style.make_primary(no)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(no)
	row.add_child(Widgets.priced(yes, [["silver", Widgets.thousands(cost), Style.ENEMY_LIGHT]]))
	col.add_child(row)


func _on_reinforce(id: int) -> void:
	_paid(GameState.reinforce_squad(id), "coins", "Squad_%d" % id)


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
		_paid(GameState.train_squad(id), "promotion", "Squad_%d" % id)


func _show_branch_choice(id: int, branches: Array) -> void:
	if _modal != null and is_instance_valid(_modal):
		_modal.queue_free()
	_modal = null
	var squad := GameState.squad_by_id(id)
	if squad.is_empty():
		return
	var col := Widgets.sheet(self, "Choose a path", "BranchSheet", func(): _modal = null)
	_modal = col.get_parent().get_parent().get_parent().get_parent() as Control
	col.add_child(_note("Your veterans take one of two trades for good."))
	var is_free: bool = squad.get("pending_branch", false)
	for b_id in branches:
		var u_info := Units.get_unit(b_id)
		var card := Widgets.card(col, "")
		card.get_parent().name = "Branch_%s" % b_id
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 14)
		card.add_child(head)
		head.add_child(_portrait(b_id, Units.culture(b_id)))
		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(words)
		words.add_child(Style.label(Units.display_name(b_id), Style.BODY, Style.TEXT))
		if String(u_info.get("blurb", "")) != "":
			words.add_child(_note(String(u_info.get("blurb", ""))))
		var stats := Widgets.chip_row(_unit_chips(b_id))
		stats.name = "Stats"
		card.add_child(stats)
		var price := 0 if is_free else Economy.train_cost(squad, b_id)
		var bid := String(b_id)
		var btn := _button("Choose", func():
			Widgets.close_sheet(col)
			_paid(GameState.train_squad(id, bid), "promotion")
		)
		btn.name = "Choose_%s" % bid
		btn.disabled = price > GameState.silver
		if not btn.disabled:
			Style.make_primary(btn)
		card.add_child(Widgets.priced(btn, [["silver", "free" if price == 0 else Widgets.thousands(price), Style.ENEMY_LIGHT if btn.disabled else Style.TEXT]]))


## A unit's strengths as chips: each number by its icon, each trait as a word with ▲.
func _unit_chips(unit_id: String) -> Array:
	var u := Units.get_unit(unit_id)
	var chips: Array = []
	var st: Dictionary = u.get("stats", {})
	var mech: Dictionary = u.get("mechanics", {})
	if mech.has("armor"):
		chips.append(Widgets.stat("armor", "%.0f%%" % (float(mech["armor"]) * 100.0)))
	if st.has("damage"):
		chips.append(Widgets.stat("damage", "%.0f" % float(st["damage"])))
	if mech.has("piercing"):
		chips.append(Widgets.chip("Pierces %.0f%%" % (float(mech["piercing"]) * 100.0), Style.TEXT, "", "damage"))
	if st.has("range"):
		chips.append(Widgets.stat("bow", "%.0f" % float(st["range"])))
	if st.has("speed"):
		chips.append(Widgets.stat("speed", "%.0f" % float(st["speed"])))
	if st.has("size"):
		chips.append(Widgets.stat("men", str(int(st["size"]))))
	if mech.has("javelins"):
		chips.append(Widgets.chip("%d javelins a man" % int(mech["javelins"]), Style.MORALE_HIGH))
	if mech.get("sweep", false):
		chips.append(Widgets.chip("Sweep: a second foe for half", Style.MORALE_HIGH))
	if mech.get("steady", false):
		chips.append(Widgets.chip("Steady · −20% morale loss", Style.MORALE_HIGH, "", "morale"))
	if mech.get("horse_archer", false):
		chips.append(Widgets.chip("Shoots from the saddle", Style.MORALE_HIGH, "", "ride"))
	if mech.get("ronin", false):
		chips.append(Widgets.chip("Fury if the captain falls", Style.MORALE_HIGH, "", "fight"))
	return chips


## Silver changed hands, or didn't: the coins chink, and the screen shows the new state.
func _paid(done: bool, effect: String = "coins", changed: String = "") -> void:
	if done:
		Sound.play(effect, 0.0, 0.08)
	_build()
	# The company the tap made or changed glows as the page comes back.
	if done and changed != "":
		_flash_named.call_deferred(changed)


func _flash_named(node_name: String) -> void:
	# The old page is freed at the end of the frame, so its copy may still be found first.
	for n in find_children(node_name, "Control", true, false):
		if Widgets.live(n):
			Widgets.flash(n as Control)
			return


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
