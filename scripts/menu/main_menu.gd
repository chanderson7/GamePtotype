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
const Fiefs = preload("res://scripts/data/fiefs.gd")
const CampMoments = preload("res://scripts/data/camp_moments.gd")
const Achievements = preload("res://scripts/data/achievements.gd")
const Widgets = preload("res://scripts/ui/widgets.gd")
const SettlementVista = preload("res://scripts/ui/settlement_vista.gd")
const Page = preload("res://scripts/ui/menu_page.gd")
const BondRow = preload("res://scripts/ui/bond_row.gd")
const LordVoice = preload("res://scripts/data/lord_voice.gd")
const Motion = preload("res://scripts/ui/motion.gd")
const CampFx = preload("res://scripts/ui/camp_fx.gd")

var _scroll: ScrollContainer
## The open tab: camp, companies or deeds.
var _tab := "camp"
## Whether this visit's first build is done: things rise in only on arriving, and when a
## tab is turned to (_turning).
var _arrived := false
var _turning := false
## The camp picture, which drifts a little as the page scrolls.
var _camp_art: TextureRect
## The talks at the fire beyond the first few, once "All" is tapped.
var _all_talks := false
const TALKS_SHOWN := 3
## Companies whose men rose with the last Reinforce, by id, to flash once.
var _refilled := {}
## The company's name was just taken up: it rises in under the title.
var _title_new := false
## Scroll to the fallen once the page is built (after Remember).
var _to_fallen := false
var _fallen_section: Control
var _flicker: Tween
## The fallen card shows the five most recent until "All" is tapped.
var _all_fallen := false
const FALLEN_SHOWN := 5
## Icons for the sort segments, in the order of the sorts.
const SORT_ICONS := ["company", "shieldwall", "men", "level", "journal"]
const SORT_TIPS := ["Roster order", "By role", "By strength", "By experience", "By captain"]
## A contract's kind, as its icon.
const JOB_ICONS := {"hunt": "skull", "courier": "mail", "relief": "food"}


func _ready() -> void:
	theme = Style.make_theme()
	_tab = Scenes.warband_tab
	Sound.set_loop("camp")
	_build()


func _exit_tree() -> void:
	Sound.set_loop("")


func _build() -> void:
	var keep := _scroll.scroll_vertical if _scroll != null else Scenes.warband_scroll
	for child in get_children():
		child.queue_free()

	var insets := Style.safe_insets(get_viewport())
	var frame := VBoxContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_constant_override("separation", 0)
	add_child(frame)
	# The page shell fills the room above the bottom bar.
	var page := Control.new()
	page.name = "Page"
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(page)
	var col := Page.frame(page, 1.0)
	_scroll = col.get_parent().get_parent() as ScrollContainer
	_scroll.get_v_scroll_bar().value_changed.connect(_on_page_scroll)

	# Who you are, where, and what you have. The camp's banner says the people.
	col.add_child(Style.label("Warband", 64, Style.BRASS))
	var w = GameState.world
	var pay := _pay_forecast()
	if w != null:
		var pace: float = w.party_pace(w.player())
		var pace_tone := Style.MORALE_HIGH if pace >= 1.05 else (Style.MORALE_LOW if pace < 0.9 else Style.TEXT)
		var chips := [
			Widgets.stat("mappin", String(WorldData.settlement(w.player().node)["name"])),
			Widgets.stat("day", str(int(w.hour) / 24 + 1)),
			Widgets.stat("speed", str(roundi(w.player_speed())), pace_tone),
		]
		if not bool(pay["short"]):
			chips.append(_pay_chip(pay))
		var where_chips := Widgets.chip_row(chips)
		where_chips.name = "WhereChips"
		col.add_child(where_chips)
	if GameState.company_title != "" and Achievements.DEEDS.has(GameState.company_title):
		var known := Style.label("Known as %s" % Achievements.DEEDS[GameState.company_title]["title"], Style.BODY, Style.BRASS)
		known.name = "CompanyTitle"
		col.add_child(known)
		if _title_new:
			_title_new = false
			Motion.rise(known, 0.1)
			Widgets.flash(known)
	_tiles(col)
	# The pay card only when it says something the tiles don't: it can't be met, or
	# there's no map to put the chip on.
	if bool(pay["short"]) or w == null:
		_upkeep_forecast(col, pay)

	var tabs := [
		{"id": "camp", "label": "Camp", "icon": "fire", "badge": 1 if CampMoments.pick(GameState).size() > 0 else 0},
		{"id": "companies", "label": "Companies", "icon": "company", "badge": _promotions_ready()},
		{"id": "bonds", "label": "Bonds", "icon": "bond", "badge": GameState.new_bond_talks().size()},
		{"id": "deeds", "label": "Deeds", "icon": "book", "badge": GameState.active_jobs.size()},
	]
	var bar := Widgets.tab_bar(tabs, _tab, _on_tab, "WarbandTabs", true)
	col.add_child(bar)
	# The Camp tab's flame flickers while the camp is open.
	if _tab == "camp":
		Motion.flicker_icon(bar.find_child("Tab_camp", true, false) as Button, Style.TEXT, Color("f3d891"))

	# Every tab is built, and only the open one shown, so links into any of them work.
	var camp := VBoxContainer.new()
	camp.name = "CampTab"
	var companies := VBoxContainer.new()
	companies.name = "CompaniesTab"
	var deeds := VBoxContainer.new()
	deeds.name = "DeedsTab"
	var bonds_tab := VBoxContainer.new()
	bonds_tab.name = "BondsTab"
	for t in [camp, companies, bonds_tab, deeds]:
		t.add_theme_constant_override("separation", 16)
		col.add_child(t)
	camp.visible = _tab == "camp"
	companies.visible = _tab == "companies"
	bonds_tab.visible = _tab == "bonds"
	deeds.visible = _tab == "deeds"
	_build_bonds_tab(bonds_tab)

	# --- Camp: the fire, who's there, the last fight, bonds and the remembered.
	camp.add_child(_camp_header())
	camp.add_child(_camp_tableau())
	_camp_moment(camp)
	var last: Dictionary = GameState.last_result
	if not last.is_empty():
		var won: bool = last["won"]
		var lc := Widgets.card(camp, "Last battle", "Victory" if won else "Defeat", Style.BRASS if won else Style.ENEMY_LIGHT)
		lc.get_parent().name = "LastBattleCard"
		var lost := Widgets.effect("men", -int(last["lost"]))
		lost.tooltip_text = "Men lost"
		var cut := Widgets.stat("skull", str(int(last["killed"])))
		cut.tooltip_text = "Enemies cut down"
		lc.add_child(Widgets.chip_row([lost, cut]))
	# Bonds have their own tab, and its badge says when a talk is waiting at the fire.
	var captives: Array = GameState.captive_lords()
	if not captives.is_empty():
		var cc := Widgets.card(camp, "Captive lords", str(captives.size()))
		cc.get_parent().name = "CaptivesCard"
		for cl in captives:
			cc.add_child(_captive_lord_row(cl))
	if not GameState.fallen.is_empty():
		var fc := Widgets.card(camp, "The fallen", str(GameState.fallen.size()))
		_fallen_section = fc.get_parent()
		_fallen_section.name = "FallenCard"
		var shown := 0
		for i in range(GameState.fallen.size() - 1, -1, -1):
			if shown >= FALLEN_SHOWN and not _all_fallen:
				break
			fc.add_child(_memorial_row(GameState.fallen[i]))
			shown += 1
		if GameState.fallen.size() > FALLEN_SHOWN and not _all_fallen:
			var all := Button.new()
			all.name = "AllFallen"
			all.text = "All %d" % GameState.fallen.size()
			all.custom_minimum_size.y = Style.TOUCH
			all.pressed.connect(func():
				_all_fallen = true
				_build())
			fc.add_child(all)

	# --- Companies: the roster, and refilling it.
	companies.add_child(_company_summary())
	if GameState.has_contract():
		companies.add_child(_contract_strip())
	companies.add_child(_sort_control())
	var sorted := _sorted_roster(GameState.army)
	var active := sorted.filter(func(s): return s.get("captain") == null or int(s["captain"].get("wounded", 0)) <= 0)
	var wounded := sorted.filter(func(s): return s.get("captain") != null and int(s["captain"].get("wounded", 0)) > 0)
	var roster := Widgets.card(companies, "Active companies", str(active.size()))
	roster.get_parent().name = "ActiveCard"
	for s in active:
		roster.add_child(_squad_row(s))
	if GameState.army.is_empty():
		roster.add_child(Style.label("Your warband is gone. Raise a new one.", Style.BODY, Style.ENEMY_LIGHT))
	if GameState.in_town():
		var total := 0
		var cheapest := 0
		for s in GameState.army:
			var cost := GameState.reinforce_cost(s)
			total += cost
			if cost > 0 and (cheapest == 0 or cost < cheapest):
				cheapest = cost
		var rest := Button.new()
		rest.name = "ReinforceAll"
		rest.text = "Reinforce all"
		rest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rest.disabled = total == 0 or cheapest > GameState.silver
		if not rest.disabled:
			Style.make_primary(rest)
		rest.pressed.connect(_on_reinforce)
		var why := "Every company is at full strength" if total == 0 else ("Need %s more silver" % Widgets.thousands(cheapest - GameState.silver) if cheapest > GameState.silver else "")
		roster.add_child(Widgets.priced(rest, [["silver", Widgets.thousands(total)]] if total > 0 else [], why))
	else:
		roster.add_child(_note("Ride to a town to reinforce and train."))
	if not wounded.is_empty():
		var wounded_roster := Widgets.card(companies, "Wounded captains", str(wounded.size()), Style.ENEMY_LIGHT)
		wounded_roster.get_parent().name = "WoundedCard"
		for s in wounded:
			wounded_roster.add_child(_squad_row(s))

	# --- Deeds & work: contracts, your fief, and what the company is known for.
	var jc := Widgets.card(deeds, "Active contracts", "%d/%d" % [GameState.contract_count(), Jobs.MAX_ACTIVE_JOBS])
	if GameState.active_jobs.is_empty():
		jc.add_child(_note("None. Settlements' notice boards post bounties, dispatches and relief work."))
	else:
		for job in GameState.active_jobs:
			jc.add_child(_active_job_row(job))
	if GameState.has_fief():
		var fcard := Widgets.card(deeds, "Your fiefdom")
		fcard.add_child(_fief_overview_row())
	_add_crown_path(deeds)
	var earned := 0
	for id in Achievements.ORDER:
		if Achievements.done(GameState, id):
			earned += 1
	var dcard := Widgets.card(deeds, "Deeds", "%d/%d" % [earned, Achievements.ORDER.size()], Style.BRASS if earned > 0 else Style.MUTED)
	dcard.add_child(_deeds_panel())

	# Back to the map, always in reach.
	var back: Button
	if w != null:
		back = Widgets.back_button(func(): Scenes.go("res://scenes/world_map.tscn"), "Map", "BackButton")
		back.accessibility_name = "Back to the map"
	else:
		back = Button.new()
		back.name = "BackButton"
		Style.make_primary(back)
		back.text = "To battle"
		back.disabled = GameState.total_men() == 0
		back.pressed.connect(_on_battle)
	frame.add_child(Widgets.bottom_bar(back, insets, "BackBar"))
	_restore_scroll(keep)
	_show_changes(col, tabs, pay)
	var open_tab := {"camp": camp, "companies": companies, "bonds": bonds_tab, "deeds": deeds}[_tab] as Control
	if not _arrived or _turning:
		_arrive(col, open_tab)
	_arrived = true
	_turning = false
	if _to_fallen:
		_to_fallen = false
		_jump_to_fallen.call_deferred()


## Silver (and what a day costs), food (and the days it lasts), men (with the wounded)
## and renown, as tiles in one row; two rows when big text or big numbers won't fit one.
func _tiles(parent: Control) -> void:
	var days := GameState.food_days()
	var net := GameState.contract_daily_pay() - GameState.daily_outgoings()
	var wounded := GameState.total_wounded()
	var grid := Widgets.tile_grid([
		Widgets.compact_tile("silver", Widgets.thousands(GameState.silver), "%s%d a day" % ["+" if net > 0 else "−", absi(net)]),
		Widgets.compact_tile("food", Widgets.thousands(GameState.food), "%d day%s" % [days, "" if days == 1 else "s"], Style.ENEMY_LIGHT if days < 3 else Style.TEXT),
		Widgets.compact_tile("men", str(GameState.total_men()), str(wounded) if wounded > 0 else "all fit", Style.TEXT, "wounded" if wounded > 0 else ""),
		Widgets.compact_tile("renown", Widgets.thousands(GameState.renown), "renown"),
	], 4)
	grid.name = "WarbandTiles"
	# Measured in the tree, where the words have their font.
	parent.add_child(grid)
	if grid.get_combined_minimum_size().x > _room():
		grid.columns = 2


## What the Warband showed when last looked at, kept on Scenes for this world only.
func _seen() -> Dictionary:
	var world_id: int = GameState.world.get_instance_id() if GameState.world != null else 0
	if int(Scenes.warband_seen.get("world", -1)) != world_id:
		Scenes.warband_seen = {"world": world_id}
	return Scenes.warband_seen


## What changed since the Warband was last looked at, shown as it changes: the tiles count
## to their new numbers (the change rising off them), a pay that can no longer be met
## shakes in, and a tab whose count went up pops its badge. Then this is what was seen.
func _show_changes(col: Control, tabs: Array, pay: Dictionary) -> void:
	var seen := _seen()
	var now := {"silver": GameState.silver, "food": GameState.food, "men": GameState.total_men(), "renown": GameState.renown}
	var grid := col.find_child("WarbandTiles", false, false) as Control
	var n := 0
	for key in now:
		if seen.has(key) and int(seen[key]) != int(now[key]) and grid != null:
			var tile := grid.find_child("Tile_%s" % key, false, false) as Control
			if tile != null:
				Widgets.tick_to(tile.find_child("Value", true, false) as Label, int(seen[key]), int(now[key]), func(v): return Widgets.thousands(v), key)
				Widgets.flash(tile)
				n += 1
		seen[key] = now[key]
	var short := bool(pay["short"])
	if short and seen.has("short") and not bool(seen["short"]):
		Motion.shake(col.find_child("NextPayCard", true, false) as Control)
	seen["short"] = short
	var badges: Dictionary = seen.get("badges", {})
	for t in tabs:
		var id := String(t["id"])
		var count := int(t.get("badge", 0))
		if badges.has(id) and count > int(badges[id]):
			var tab := col.find_child("Tab_%s" % id, true, false)
			if tab != null:
				Motion.pop(tab.find_child("Badge", true, false) as Control, 1.5, 0.15)
		badges[id] = count
	seen["badges"] = badges
	# The pay's last hour: the clock ticks and the chip glows brass.
	var chip := col.find_child("NextPayChip", true, false) as PanelContainer
	if chip != null and float(pay.get("hours", 24.0)) <= 1.0:
		var sb := (chip.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
		sb.border_color = Style.BRASS
		chip.add_theme_stylebox_override("panel", sb)
		Motion.pulse(chip.find_child("Icon", true, false) as Control)


## Arriving on the page, or turning to a tab: its rows rise in one after another, its
## meters fill and its met steps draw their ticks.
func _arrive(col: Control, tab: Control) -> void:
	if not Motion.on():
		return
	if not _arrived:
		var tiles := col.find_child("WarbandTiles", false, false)
		if tiles != null:
			Motion.stagger(tiles.get_children(), 0.05)
	var rows: Array = []
	for pattern in ["CampCaptain_*", "Squad_*", "BondRow", "Deed_*"]:
		rows.append_array(tab.find_children(pattern, "Control", true, false))
	Motion.stagger(rows, 0.04, 0.08)
	for m in tab.find_children("*Meter", "Control", true, false):
		if (m as Control).has_meta("frac"):
			Motion.grow(m as Control, 0.0, 0.15)
	var met := tab.find_children("Met", "Control", true, false)
	for i in met.size():
		var mark := met[i] as Control
		mark.set_meta("tick", 0.0)
		var t := mark.create_tween()
		t.tween_interval(0.3 + 0.08 * i)
		t.tween_method(func(v: float):
			mark.set_meta("tick", v)
			mark.queue_redraw(), 0.0, 1.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## The node called `node_name` on the page as rebuilt, not the outgoing copy still
## waiting to be freed this frame.
func _live(node_name: String) -> Node:
	for n in find_children(node_name, "", true, false):
		if Widgets.live(n):
			return n
	return null


## The camp picture drifts a little slower than the page, so it has some depth.
func _on_page_scroll(value: float) -> void:
	if _camp_art == null or not is_instance_valid(_camp_art) or not Motion.on():
		return
	var p := clampf(value * 0.05, 0.0, 10.0)
	_camp_art.offset_top = -10.0 + p
	_camp_art.offset_bottom = 10.0 + p


func _on_tab(id: String) -> void:
	if id == _tab:
		return
	_tab = id
	_turning = true
	Scenes.warband_tab = id
	Sound.play("click", 0.0, 0.05)
	_scroll.scroll_vertical = 0
	_build()


func _camp_header() -> Control:
	var stage := Control.new()
	stage.name = "WarbandCampStage"
	stage.custom_minimum_size.y = 190
	stage.clip_contents = true
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var camp := StoryArt.location("company_camp", 0)
	camp.name = "WarbandCampIllustration"
	camp.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# A little taller than the stage, to drift in as the page scrolls.
	camp.offset_top = -10.0
	camp.offset_bottom = 10.0
	camp.modulate = _camp_light()
	stage.add_child(camp)
	_camp_art = camp
	# Firelight: a slow, slight flicker; still when motion is reduced.
	if not Style.motion_reduced():
		var base := camp.modulate
		_flicker = camp.create_tween().set_loops()
		_flicker.tween_property(camp, "modulate", base * Color(1.06, 1.0, 0.92), 1.7).set_trans(Tween.TRANS_SINE)
		_flicker.tween_property(camp, "modulate", base, 2.1).set_trans(Tween.TRANS_SINE)
	# The fire's life over the picture: glow, embers and smoke, stars, the weather.
	var fx := CampFx.new()
	fx.art = camp
	fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var w = GameState.world
	if w != null:
		fx.light = CampFx.light_for(w.hour)
		fx.weather = CampFx.weather_for(String(w.player().node), int(w.hour / 24.0))
	fx.visible = Style.illustrations_on()
	stage.add_child(fx)
	# The company's own banner, moving in the wind: its realm's, or its crown once raised.
	var realm := "crown" if GameState.is_crowned() else Heraldry.realm_of_culture(GameState.culture)
	var banner := CampFx.waving_banner(realm, Vector2(116, 140))
	banner.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	banner.offset_left = -136.0
	banner.offset_right = -20.0
	banner.offset_top = 8.0
	banner.offset_bottom = 148.0
	banner.visible = Style.illustrations_on()
	stage.add_child(banner)
	# Who's at the fire, as chips across the sky, clear of the fire and the banner, over a
	# shade that keeps them readable on a bright camp.
	var shade := Control.new()
	shade.name = "FireShade"
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.draw.connect(func():
		var low := shade.size.y * 0.6
		var clear := Color(Style.NIGHT, 0.0)
		var dark := Color(Style.NIGHT, 0.72)
		shade.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(shade.size.x, 0), Vector2(shade.size.x, low), Vector2(0, low)]),
			PackedColorArray([dark, dark, clear, clear])))
	stage.add_child(shade)
	var counts := _fire_counts()
	var chips := [Widgets.stat("fire", "%d ready" % int(counts["ready"]))]
	if int(counts["resting"]) > 0:
		chips.append(Widgets.stat("wounded", "%d resting" % int(counts["resting"])))
	if not GameState.fallen.is_empty():
		var remembered := Widgets.stat("lantern", "%d remembered" % GameState.fallen.size())
		remembered.name = "RememberedChip"
		remembered.tooltip_text = "The fallen"
		Widgets.on_tap(remembered, func(): _jump_to_fallen())
		chips.append(remembered)
	var fire := Widgets.chip_row(chips)
	fire.name = "FireChips"
	fire.set_anchors_preset(Control.PRESET_TOP_WIDE)
	fire.offset_left = 12.0
	fire.offset_right = -150.0
	fire.offset_top = 12.0
	fire.offset_bottom = 12.0
	stage.add_child(fire)
	return stage


## How many captains stand ready at the fire, and how many rest wounded.
func _fire_counts() -> Dictionary:
	var out := {"ready": 0, "resting": 0}
	for s in GameState.army:
		var c = s.get("captain")
		if c is Dictionary:
			out["resting" if int(c.get("wounded", 0)) > 0 else "ready"] += 1
	return out


## The camp's light by the hour on the map: night is dark and blue, dawn and dusk warm.
func _camp_light() -> Color:
	var w = GameState.world
	if w == null:
		return Color.WHITE
	var h := int(w.hour) % 24
	if h < 5 or h >= 21:
		return Color(0.55, 0.6, 0.85)
	if h < 8 or h >= 18:
		return Color(1.0, 0.85, 0.7)
	return Color.WHITE


## The captains around the fire, in an even grid, face over name: those fit for duty
## first, then the wounded, dimmed and marked as resting. Each opens the captain's
## profile. The counts are on the picture above; the fallen are remembered below.
func _camp_tableau() -> Control:
	var box := VBoxContainer.new()
	box.name = "CampTableau"
	var hurt_last := []
	for s in GameState.army:
		var c = s.get("captain")
		if c is Dictionary and int(c.get("wounded", 0)) <= 0:
			hurt_last.append(c)
	for s in GameState.army:
		var c = s.get("captain")
		if c is Dictionary and int(c.get("wounded", 0)) > 0:
			hurt_last.append(c)
	var grid := GridContainer.new()
	grid.name = "CampCaptains"
	# Four across; three when the text is set big.
	grid.columns = 4 if Style.text_size(Style.SMALL) <= roundi(Style.SMALL * 1.15) else 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for c in hurt_last:
		grid.add_child(_camp_token(c))
	box.add_child(grid)
	return box


## One captain at the fire: the face over the first name, the whole tile a button.
func _camp_token(c: Dictionary) -> Button:
	var hurt := int(c.get("wounded", 0)) > 0
	var first := String(c.get("first", c.get("name", "Captain")))
	var token := Button.new()
	token.name = "CampCaptain_%d" % int(c.get("id", 0))
	token.text = first
	token.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	token.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	token.clip_text = true
	token.add_theme_font_size_override("font_size", Style.text_size(Style.SMALL))
	token.custom_minimum_size = Vector2(0, Style.TOUCH)
	# The theme's button looks, with narrow sides so a name has the tile's width.
	var looks := {"normal": Style.box(Style.RAISED, Style.RULE, 2), "hover": Style.box(Style.RAISED.lightened(0.06), Style.MUTED, 2),
		"pressed": Style.box(Style.RAISED.darkened(0.16), Style.BRASS, 4), "hover_pressed": Style.box(Style.RAISED.darkened(0.16), Style.BRASS, 4)}
	for state in looks:
		var sb: StyleBoxFlat = looks[state]
		sb.content_margin_left = 4
		sb.content_margin_right = 4
		token.add_theme_stylebox_override(state, sb)
	if Style.illustrations_on():
		token.icon = CaptainArt.texture(c, _mood(c))
		token.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		token.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		token.add_theme_constant_override("icon_max_width", 55)
		token.add_theme_constant_override("h_separation", 2)
	token.tooltip_text = first
	if hurt:
		var back := int(c.get("wounded", 0))
		token.tooltip_text = "%s rests: back in %d battle%s" % [first, back, "" if back == 1 else "s"]
		token.accessibility_name = "%s, resting" % first
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			token.add_theme_color_override(k, Style.MUTED)
		for k in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "icon_focus_color"]:
			token.add_theme_color_override(k, Color(1, 1, 1, 0.62))
		var mark := PanelContainer.new()
		mark.name = "RestingMark"
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mb := Style.box(Style.NIGHT, Style.RULE, 2, 20)
		mb.set_content_margin_all(5)
		mark.add_theme_stylebox_override("panel", mb)
		mark.add_child(Widgets.icon_rect("wounded", 22.0))
		mark.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		mark.offset_left = -6.0
		mark.offset_right = -6.0
		mark.offset_top = 6.0
		mark.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		token.add_child(mark)
	token.pressed.connect(_open_captain.bind(int(c.get("id", 0))))
	# A press gives a little under the finger.
	token.button_down.connect(func():
		if Motion.on():
			token.pivot_offset = token.size * 0.5
			token.create_tween().tween_property(token, "scale", Vector2(0.94, 0.94), 0.08))
	token.button_up.connect(func():
		if Motion.on():
			token.create_tween().tween_property(token, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	return token


## The face a captain wears at the fire, from what is true of them now: in pain while
## wounded, grieving a friend just fallen, warm over a bond just grown, proud with a
## promotion waiting; otherwise their resting face.
func _mood(c: Dictionary) -> String:
	var id := int(c.get("id", 0))
	if int(c.get("wounded", 0)) > 0:
		return "pain"
	var m: Dictionary = CampMoments.pick(GameState)
	match String(m.get("kind", "")):
		"fallen":
			for f in GameState.fallen:
				if int(f.get("id", 0)) == int(m.get("captain_id", -1)):
					var who = CampMoments.mourner(GameState, f)
					if who is Dictionary and int(who.get("id", -1)) == id:
						return "grief"
		"bond":
			if id == int(m.get("a_id", -1)) or id == int(m.get("b_id", -1)):
				return "warm"
	if Captains.can_specialize(c):
		return "proud"
	return ""


## One optional moment from what happened to the company, on a gold card, or nothing on
## a quiet visit.
func _camp_moment(parent: Control) -> void:
	var m: Dictionary = CampMoments.pick(GameState)
	if m.is_empty():
		return
	var v := Widgets.card(parent, String(m["title"]), "", Style.MUTED, true)
	v.get_parent().name = "CampMoment"
	Motion.sheen(v.get_parent() as Control)
	var text := Style.label(String(m["text"]), Style.BODY, Style.TEXT)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(text)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var go_text: String = {"captain": "See captain", "bond": "Spend time together", "memorial": "Remember", "map": ""}.get(String(m.get("action", "")), "")
	if go_text != "":
		var go := Button.new()
		go.text = go_text
		go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		go.custom_minimum_size = Vector2(0, Style.TOUCH)
		go.pressed.connect(_on_moment.bind(m))
		row.add_child(go)
	var done := Button.new()
	done.text = "Let it be"
	done.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	done.custom_minimum_size = Vector2(0, Style.TOUCH)
	done.pressed.connect(func(): Motion.fold(v.get_parent() as Control, _on_moment_dismiss.bind(String(m["key"]))))
	row.add_child(done)


## The company's deeds: what it has done, how far along the rest are, and the names
## earned. A name is only a name: no bonuses come with it.
func _deeds_panel() -> Control:
	var box := VBoxContainer.new()
	box.name = "DeedsPanel"
	box.add_theme_constant_override("separation", 10)
	for id in Achievements.ORDER:
		var d: Dictionary = Achievements.DEEDS[id]
		var done := Achievements.done(GameState, id)
		var need := int(d["need"])
		var have := need if done else Achievements.progress(GameState, id)
		var row := PanelContainer.new()
		row.name = "Deed_%s" % id
		var sb := Style.box(Style.NIGHT, Style.BRASS.darkened(0.35) if done else Style.RULE, 2, 14)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 10
		sb.content_margin_bottom = 10
		row.add_theme_stylebox_override("panel", sb)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 14)
		row.add_child(line)
		# Its icon on a tile: brass and ticked once the deed is done.
		var tile := PanelContainer.new()
		tile.name = "DeedTile"
		tile.custom_minimum_size = Vector2(56, 56)
		tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tile.add_theme_stylebox_override("panel", Style.box(Style.BRASS if done else Style.RAISED, Color(0, 0, 0, 0), 0, 14))
		var ic := Widgets.icon_rect(String(DEED_ICONS.get(id, "renown")), 34.0)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if done:
			ic.modulate = Color("1a1420")
		tile.add_child(ic)
		line.add_child(tile)
		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.add_theme_constant_override("separation", 6)
		line.add_child(words)
		var text: Label
		if done:
			text = Style.label(String(d["title"]).capitalize(), Style.SMALL, Style.BRASS)
		else:
			text = Style.label(String(d["goal"]).trim_suffix("."), Style.SMALL, Style.TEXT)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		words.add_child(text)
		var progress := HBoxContainer.new()
		progress.add_theme_constant_override("separation", 10)
		if done:
			progress.add_child(Widgets.stat("day", str(int(GameState.deeds[id].get("day", 1)))))
		else:
			var dm := Widgets.meter(float(have) / maxf(1.0, float(need)), Style.PLAYER_LIGHT.darkened(0.25), 12.0)
			dm.name = "DeedMeter"
			progress.add_child(dm)
			progress.add_child(Style.label("%d/%d" % [have, need], Style.SMALL, Style.MUTED))
		words.add_child(progress)
		if done:
			var carried: bool = GameState.company_title == id
			# A toggle: lit brass while the company carries this name.
			var b := Button.new()
			b.name = "CarryTitle_%s" % id
			b.text = "Carried" if carried else "Carry"
			b.toggle_mode = true
			b.button_pressed = carried
			b.add_theme_font_size_override("font_size", Style.text_size(Style.SMALL))
			b.custom_minimum_size = Vector2(120, Style.TOUCH)
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			if carried:
				Style.make_primary(b)
			b.pressed.connect(func():
				GameState.set_company_title("" if carried else id)
				GameState.save_game()
				_title_new = not carried
				_build()
				if not carried and _scroll != null and Motion.on():
					_scroll.create_tween().tween_property(_scroll, "scroll_vertical", 0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT))
			line.add_child(b)
		box.add_child(row)
	box.add_child(_note("Yours to chase or ignore; the campaign never ends on one."))
	# A deed done since the tab was last open is stamped in brass, with a ring.
	if _tab == "deeds":
		var seen := _seen()
		var had: Array = seen.get("deeds", [])
		var done_now: Array = []
		for id in Achievements.ORDER:
			if Achievements.done(GameState, id):
				done_now.append(id)
				if seen.has("deeds") and not had.has(id):
					var deed_row := box.find_child("Deed_%s" % id, false, false)
					if deed_row != null:
						var ic := deed_row.find_child("DeedTile", true, false) as Control
						Motion.pop(ic, 1.4, 0.4)
						Motion.ring(ic, Style.BRASS, 0.4, false)
		seen["deeds"] = done_now
	return box


## The icon on each deed's tile.
const DEED_ICONS := {"contract": "company", "jobs": "book", "villages": "shieldwall", "chiefs": "skull", "lord": "lock",
	"walls": "walls", "veteran": "heart", "pact": "talk", "fief": "keep", "renown": "renown"}


func _on_moment(m: Dictionary) -> void:
	CampMoments.dismiss(GameState, String(m["key"]))
	GameState.save_game()
	match String(m.get("action", "")):
		"captain":
			_open_captain(int(m.get("captain_id", 0)))
		"bond":
			_open_bond(int(m.get("a_id", 0)), int(m.get("b_id", 0)))
		"memorial":
			_to_fallen = true
			_build()


func _jump_to_fallen() -> void:
	if _tab != "camp":
		_tab = "camp"
		Scenes.warband_tab = "camp"
		_build()
	await get_tree().process_frame
	await get_tree().process_frame
	if _fallen_section != null and is_instance_valid(_fallen_section) and _scroll != null:
		_scroll.scroll_vertical = int(_fallen_section.global_position.y - _scroll.global_position.y + _scroll.scroll_vertical)
		Widgets.flash(_fallen_section)


func _on_moment_dismiss(key: String) -> void:
	CampMoments.dismiss(GameState, key)
	GameState.save_game()
	_build()


## The width the page's column has: the screen's, up to a phone's, less the margins.
func _room() -> float:
	return minf(get_viewport_rect().size.x, Style.COLUMN_MAX) - 64.0


## What the next day costs: wages (less a contract's pay) and rations going out, when,
## what's left after, and whether that runs short.
func _pay_forecast() -> Dictionary:
	var wages := GameState.daily_outgoings()
	var stipend := GameState.contract_daily_pay()
	var rations := GameState.total_men()
	var due := "daily"
	var hours := 24.0
	if GameState.world != null:
		var next_day := (floori(GameState.world.hour / 24.0) + 1) * 24
		hours = float(next_day) - GameState.world.hour
		due = Style.time_short(maxf(1.0, hours))
	var after_silver := GameState.silver - wages + stipend
	var after_food := GameState.food - rations
	return {"silver_out": wages - stipend, "food_out": rations, "due": due, "hours": hours,
		"after_silver": after_silver, "after_food": after_food, "short": after_silver < 0 or after_food < 0}


## Pay that can be met, as a chip by the place and the day: only the time is news, since
## the tiles say what a day costs. Its tooltip has the sums.
func _pay_chip(pay: Dictionary) -> Control:
	var c := Widgets.stat("clock", "Pay in %s" % String(pay["due"]))
	c.name = "NextPayChip"
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	c.tooltip_text = "Wages %s → %s silver · rations −%s → %s" % [
		("−" if int(pay["silver_out"]) > 0 else "+") + Widgets.thousands(absi(int(pay["silver_out"]))),
		Widgets.thousands(int(pay["after_silver"])), Widgets.thousands(int(pay["food_out"])), Widgets.thousands(int(pay["after_food"]))]
	return c


## Pay as a card: wages and rations going out, and what's left after; red, with a
## warning, when it runs short.
func _upkeep_forecast(parent: Control, pay: Dictionary) -> void:
	var due := String(pay["due"])
	var after_silver := int(pay["after_silver"])
	var after_food := int(pay["after_food"])
	var short := bool(pay["short"])
	var v := Widgets.card(parent, "Next pay", due, Style.ENEMY_LIGHT if short else Style.MUTED)
	v.get_parent().name = "NextPayCard"
	var aside := v.find_child("CardAside", true, false) as Control
	if aside != null:
		var clock := Widgets.icon_rect("clock", 26.0)
		aside.get_parent().add_child(clock)
		aside.get_parent().move_child(clock, aside.get_index())
	if short:
		var panel := v.get_parent() as PanelContainer
		var sb := (panel.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
		sb.border_color = Style.MORALE_LOW
		panel.add_theme_stylebox_override("panel", sb)
	v.add_child(_pay_line("silver", int(pay["silver_out"]), maxi(0, after_silver), after_silver < 0))
	v.add_child(_pay_line("food", int(pay["food_out"]), maxi(0, after_food), after_food < 0))
	if short:
		var warn := Widgets.chip("Men may leave", Style.MORALE_LOW, "▼")
		warn.name = "Shortfall"
		warn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		v.add_child(warn)


## One line of the pay card: the icon, what goes out, and what's left.
func _pay_line(key: String, out: int, after: int, short: bool) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.name = "Pay_%s" % key
	h.add_theme_constant_override("separation", 12)
	h.add_child(Widgets.icon_rect(key, 30.0))
	var spent := Style.label("%s%s" % ["−" if out > 0 else "+", Widgets.thousands(absi(out))], Style.BODY, Style.ENEMY_LIGHT if out > 0 else Style.MORALE_HIGH)
	spent.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(spent)
	h.add_child(Style.label("→", Style.BODY, Style.MUTED))
	h.add_child(Style.label(Widgets.thousands(after), Style.BODY, Style.ENEMY_LIGHT if short else Style.TEXT))
	return h


## How many squads against the cap, and the battles fought, as tiles.
func _company_summary() -> Control:
	var grid := Widgets.tile_grid([
		Widgets.tile("company", "%d/%d" % [GameState.army.size(), GameState.squad_cap()], "companies"),
		Widgets.tile("battle", str(GameState.battles), "%d won" % GameState.wins),
	], 2)
	grid.name = "CompanySummary"
	return grid


## The contract you ride under: the employer's banner, the daily pay and the days left.
func _contract_strip() -> Control:
	var panel := PanelContainer.new()
	panel.name = "ContractStrip"
	panel.add_theme_stylebox_override("panel", Style.box(Style.PANEL, Style.RULE, 2, 14))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	panel.add_child(h)
	var realm := GameState.contract_realm()
	h.add_child(Widgets.banner(realm, Vector2(36, 50)))
	var name_l := Style.label(String(WorldData.FACTIONS[realm]["name"]), Style.BODY, Style.TEXT)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_l.custom_minimum_size.x = 10
	h.add_child(name_l)
	h.add_child(Widgets.effect("silver", GameState.contract_daily_pay(), "/day"))
	var days := int(GameState.contract.get("days_left", 0))
	h.add_child(Widgets.stat("clock", "%d day%s" % [days, "" if days == 1 else "s"]))
	return panel


## How to order the companies, as a row of choices; the picked one is lit.
func _sort_control() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.add_child(Widgets.section("Sort"))
	var seg := Widgets.segmented(["", "", "", "", ""], clampi(Scenes.warband_sort, 0, 4), _on_sort, "WarbandSort", SORT_ICONS)
	for i in SORT_TIPS.size():
		var tab := seg.find_child("Tab_%d" % i, true, false) as Button
		if tab != null:
			tab.tooltip_text = SORT_TIPS[i]
			tab.accessibility_name = SORT_TIPS[i]
	col.add_child(seg)
	return col


func _on_sort(index: int) -> void:
	Scenes.warband_scroll = _scroll.scroll_vertical if _scroll != null else 0
	Scenes.warband_sort = index
	_build()
	# The rows come back in their new order, one after another.
	var card := _live("ActiveCard")
	if card != null:
		Motion.stagger(card.find_children("Squad_*", "Control", true, false), 0.035)


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


## One company on the roster, in three lines: the face with the troop on its badge, the
## name with men and wounded; the captain with their temperament and quirk; the strength
## meter with level pips and Train when it's ready. The profile holds the rest.
func _squad_row(s: Dictionary) -> Control:
	var type: String = s["type"]
	var unit_id := String(s.get("unit", ""))
	var full := Units.full_size(unit_id) if Units.has(unit_id) else Troops.full_size(type)
	var men: int = s["men"]
	var level := int(s.get("level", 1))
	var wounded: int = int(s.get("wounded", 0))
	var panel := PanelContainer.new()
	panel.name = "Squad_%d" % int(s.get("id", 0))
	var c = s.get("captain")
	var hurt: bool = c != null and int(c.get("wounded", 0)) > 0
	var sb := Style.box(Style.RAISED, Style.ENEMY_LIGHT.darkened(0.3) if hurt else Style.RULE, 2, 14)
	sb.content_margin_left = 12
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	row.add_child(_squad_art(c, s))
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 6)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)

	# The company, with its men (and wounded) on the right.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(head)
	var title := String(s.get("name", ""))
	var name_l := Style.label(title if title != "" else Units.troop_name(s, GameState.culture), Style.BODY)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_l.custom_minimum_size.x = 10
	head.add_child(name_l)
	head.add_child(Widgets.icon_value("men", "%d/%d" % [men, full], Style.TEXT if men >= full else Style.ENEMY_LIGHT))
	if wounded > 0:
		head.add_child(Widgets.icon_value("wounded", str(wounded), Style.ENEMY_LIGHT))

	# The captain: their name, and their temperament and quirk as icons.
	var who := HFlowContainer.new()
	who.add_theme_constant_override("h_separation", 8)
	who.add_theme_constant_override("v_separation", 6)
	who.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(who)
	if c == null:
		who.add_child(Style.label("No captain", Style.SMALL, Style.ENEMY_LIGHT))
	else:
		var star := "★ " if bool(c.get("is_hero", false)) else ""
		var first := Style.label(star + String(c.get("first", c.get("name", "Captain"))), Style.SMALL, Style.ENEMY_LIGHT if hurt else Style.MUTED)
		first.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		who.add_child(first)
		var spec := String(c.get("specialization", ""))
		if spec != "":
			var role := Widgets.chip("", Color("f3d891"), "", String(Captains.SPECIALIZATION_ICONS.get(spec, "")), true)
			role.tooltip_text = spec
			who.add_child(role)
		for t in _trait_keys(c):
			var tc := Widgets.chip("", Style.TEXT, "", t)
			tc.name = "Trait_%s" % t
			tc.tooltip_text = t.capitalize()
			who.add_child(tc)
		if hurt:
			var back := Widgets.chip(str(int(c["wounded"])), Style.ENEMY_LIGHT, "", "battle")
			back.name = "BackIn"
			back.tooltip_text = "Back after %d battle%s" % [int(c["wounded"]), "" if int(c["wounded"]) == 1 else "s"]
			who.add_child(back)
		if Captains.can_specialize(c):
			var promo := Widgets.chip("Promotion", Style.BRASS, "★", "", true)
			promo.name = "PromotionReady_%d" % int(c.get("id", -1))
			who.add_child(promo)
			Motion.sheen(promo, 0.42 * (int(s.get("id", 0)) % 6), 3.8, 0.42)

	# Strength, then the level as pips and Train when it's ready.
	var strength := Widgets.meter(float(men) / maxf(1.0, float(full)),
		Style.MORALE_HIGH if men >= full * 0.65 else (Style.MORALE_MID if men >= full * 0.35 else Style.MORALE_LOW), 12.0)
	strength.name = "WarbandMeter"
	text.add_child(strength)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(foot)
	foot.add_child(_level_pips(level))
	if GameState.can_train(s):
		var train := Widgets.chip("Train", Style.BRASS, "▲", "", true)
		train.name = "TrainReady_%d" % int(s.get("id", 0))
		foot.add_child(train)
		Motion.pulse(train.find_child("Shape", true, false) as Control, 1.25, 1.3)
	if c != null:
		_add_profile_tap(panel, int(c.get("id", -1)), String(c.get("name", "Captain")))
	if _refilled.has(int(s.get("id", 0))):
		var order := int(_refilled[int(s.get("id", 0))])
		var t := panel.create_tween()
		t.tween_interval(0.11 * order)
		t.tween_callback(func(): Widgets.flash(panel))
		Motion.grow(strength, float(_refilled.get("from_%d" % int(s.get("id", 0)), 0.0)), 0.11 * order, 0.5)
	return panel


## The icons for a captain's temperament and quirk, lowercased to their icon keys.
func _trait_keys(c: Dictionary) -> Array:
	var out := []
	for k in [String(c.get("temperament", "")), String(c.get("quirk", ""))]:
		if k != "":
			out.append(k.to_lower())
	return out


## A company's level as three pips, filled to its level.
func _level_pips(level: int) -> Control:
	var pips := Control.new()
	pips.name = "LevelPips"
	pips.custom_minimum_size = Vector2(Troops.MAX_LEVEL * 26.0, 26.0)
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pips.tooltip_text = "Level %d of %d" % [level, Troops.MAX_LEVEL]
	pips.set_meta("level", level)
	pips.draw.connect(func():
		for i in Troops.MAX_LEVEL:
			var at := Vector2(11.0 + i * 26.0, pips.size.y / 2.0)
			if i < level:
				pips.draw_circle(at, 9.0, Style.BRASS)
			else:
				pips.draw_arc(at, 8.0, 0.0, TAU, 24, Style.RULE.lightened(0.2), 2.0, true))
	return pips


func _note(text: String, color: Color = Style.MUTED) -> Label:
	var l := Style.label(text, Style.SMALL, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## A contract you've taken: its kind as an icon, the title, the brief, then what's left
## of the time and what it pays as chips. Abandon asks first.
func _active_job_row(job: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.name = "Job_%s" % String(job.get("id", ""))
	var sb := Style.box(Style.RAISED, Style.RULE, 2, 14)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	v.add_child(h)
	h.add_child(Widgets.icon_rect(String(JOB_ICONS.get(String(job.get("type", "")), "book")), 36.0))
	var title_lbl := Style.label(String(job.get("title", "Contract")), Style.BODY, Style.BRASS)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.add_child(title_lbl)
	var jid: String = String(job.get("id", ""))
	var abandon_btn := Button.new()
	abandon_btn.name = "Abandon_%s" % jid
	abandon_btn.text = "Abandon"
	abandon_btn.custom_minimum_size = Vector2(130, Style.TOUCH)
	abandon_btn.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	abandon_btn.add_theme_font_size_override("font_size", Style.text_size(Style.SMALL))
	abandon_btn.pressed.connect(_confirm_abandon.bind(jid, String(job.get("title", "Contract"))))
	h.add_child(abandon_btn)

	var desc_lbl := Style.label(String(job.get("description", "")), Style.SMALL, Style.TEXT)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(desc_lbl)

	var w = GameState.world
	var cur_hour: float = w.hour if w != null else 0.0
	var hrs_left: float = maxf(0.0, float(job.get("deadline", 0.0)) - cur_hour)
	var due := Widgets.stat("clock", Style.time_short(hrs_left), Style.ENEMY_LIGHT if hrs_left < 24.0 else Style.TEXT)
	if hrs_left < 24.0:
		var ic := due.find_child("Icon", true, false) as Control
		if ic != null:
			ic.modulate = Style.ENEMY_LIGHT
			Motion.pulse(ic)
	var chips: Array = [due]
	for pair in [["silver", "reward_silver"], ["renown", "reward_renown"], ["bond", "reward_relation"]]:
		var n := int(job.get(pair[1], 0))
		if n != 0:
			chips.append(Widgets.effect(pair[0], n))
	var terms := Widgets.chip_row(chips)
	terms.name = "JobTerms"
	v.add_child(terms)
	return panel


## Abandoning a contract can't be undone, so it asks on a sheet.
func _confirm_abandon(jid: String, title: String) -> void:
	var story := false
	for j in GameState.active_jobs:
		if String(j.get("id", "")) == jid:
			story = String(j.get("story_candidate", "")) != ""
	var col := Widgets.sheet(self, "Set it down?" if story else "Abandon contract?", "AbandonSheet")
	var job_realm: String = ""
	for j in GameState.active_jobs:
		if String(j.get("id", "")) == jid:
			job_realm = GameState.job_realm(j)
	col.add_child(_note(("%s. You can take it up again when you next see her." if story else "%s. Nothing is paid, and the board may not post it again.") % title, Style.TEXT))
	if job_realm != "":
		col.add_child(Widgets.chip_row([Widgets.effect("bond", Jobs.ABANDON_RELATION, " with %s" % String(WorldData.FACTIONS[job_realm]["name"]))]))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	var keep := Button.new()
	keep.name = "KeepContract"
	keep.text = "Keep it"
	keep.custom_minimum_size.y = Style.TOUCH
	keep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	keep.pressed.connect(func(): Widgets.close_sheet(col))
	row.add_child(keep)
	var go := Button.new()
	go.name = "ConfirmAbandon"
	go.text = "Abandon" if job_realm == "" else "Abandon · −%d standing" % absi(Jobs.ABANDON_RELATION)
	go.custom_minimum_size.y = Style.TOUCH
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go.add_theme_color_override("font_color", Style.ENEMY_LIGHT)
	go.pressed.connect(func():
		Widgets.close_sheet(col)
		GameState.abandon_job(jid)
		_build())
	row.add_child(go)


## Your fief as it stands today, in its own picture, under its realm's banner, with what
## waits there for you as four tiles.
## The road to a crown of your own, every requirement ticked or open with what it needs.
## Gone once the crown is raised.
func _add_crown_path(parent: Control) -> void:
	var steps: Array = GameState.crown_path()
	if steps.is_empty():
		return
	var met := steps.filter(func(s): return bool(s["done"])).size()
	var ready: bool = met == steps.size()
	var card := Widgets.card(parent, "Toward a crown", "%d of %d" % [met, steps.size()], Style.BRASS if ready else Style.MUTED, ready)
	card.get_parent().name = "CrownPathCard"
	card.add_child(_note("Serve a realm, win a fief with walls and a name to match, then raise your own banner there. Your liege will call it war."))
	card.add_child(Widgets.checklist(steps, "CrownPath"))


func _fief_overview_row() -> Control:
	var v := VBoxContainer.new()
	v.name = "FiefOverview"
	v.add_theme_constant_override("separation", 10)
	var fid := GameState.fief_id()
	var vista := SettlementVista.make(fid, GameState.world, 120.0)
	vista.name = "FiefVista"
	v.add_child(vista)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	v.add_child(head)
	head.add_child(Widgets.banner(GameState.fief_realm(), Vector2(34, 48)))
	var title_lbl := Style.label(String(WorldData.settlement(fid)["name"]), Style.LARGE, Style.BRASS)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(title_lbl)

	var f := GameState.player_fief
	var is_b: bool = GameState.world != null and GameState.world.is_burned(fid)
	var garr: int = GameState.fief_garrison().filter(func(sq): return GameState.is_company_squad(sq)).size()
	var built := 0
	for k in Fiefs.IMPROVEMENT_ORDER:
		if bool(f.get("improvements", {}).get(k, false)):
			built += 1
	var grid := Widgets.tile_grid([
		Widgets.tile("company", str(garr), "stationed"),
		Widgets.tile("keep", "%d/%d" % [built, Fiefs.IMPROVEMENT_ORDER.size()], "built"),
		Widgets.tile("silver", Widgets.thousands(int(f.get("silver", 0))), "waiting"),
		Widgets.tile("food", Widgets.thousands(int(f.get("food", 0))), "waiting"),
	], 2)
	grid.name = "FiefTiles"
	v.add_child(grid)
	if is_b:
		var raid := Widgets.chip("Raided: needs rebuilding", Style.MORALE_LOW, "", "fire")
		raid.name = "FiefRaided"
		raid.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		v.add_child(raid)
	return v


## Every bond in the company: talks waiting at the fire first, then the bonds closest to
## their next rank, then those still growing toward rank C, and the remembered.
func _build_bonds_tab(tab: VBoxContainer) -> void:
	var ranked: Array = GameState.bonds()
	var waiting: Array = GameState.new_bond_talks()
	tab.add_child(_note("Captains who fight within reach of each other grow close. Each rank steadies them when near each other, and opens a talk at the fire."))
	if not waiting.is_empty():
		var wc := Widgets.card(tab, "Talks at the fire", str(waiting.size()), Style.BRASS, true)
		wc.get_parent().name = "TalksCard"
		for i in waiting.size():
			if i >= TALKS_SHOWN and not _all_talks:
				break
			wc.add_child(_bond_row(waiting[i]))
		if waiting.size() > TALKS_SHOWN and not _all_talks:
			var all := Button.new()
			all.name = "AllTalks"
			all.text = "All %d" % waiting.size()
			all.custom_minimum_size.y = Style.TOUCH
			all.pressed.connect(func():
				_all_talks = true
				_build()
				var card := _live("TalksCard")
				if card != null:
					var rows := card.find_children("BondRow", "Control", true, false)
					Motion.stagger(rows.slice(TALKS_SHOWN), 0.055))
			wc.add_child(all)
	var rest: Array = ranked.filter(func(b): return not waiting.has(b))
	rest.sort_custom(func(x, y): return _to_next_rank(float(x["points"])) < _to_next_rank(float(y["points"])))
	if not rest.is_empty():
		var rc := Widgets.card(tab, "Bonds", "closest to a rank first")
		rc.get_parent().name = "BondsListCard"
		for b in rest:
			rc.add_child(_bond_row(b))
	# Pairs that have fought together but haven't reached rank C.
	var growing := []
	for i in GameState.army.size():
		var a = GameState.army[i].get("captain")
		if a == null:
			continue
		for j in range(i + 1, GameState.army.size()):
			var b = GameState.army[j].get("captain")
			if b == null:
				continue
			var points := float(a.get("bonds", {}).get(str(b["id"]), 0.0))
			if points > 0.0 and Captains.rank_for(points) == 0:
				growing.append({"a": a, "b": b, "points": points})
	growing.sort_custom(func(x, y): return float(x["points"]) > float(y["points"]))
	if not growing.is_empty():
		var gc := Widgets.card(tab, "Growing", "toward rank C")
		gc.get_parent().name = "GrowingCard"
		for g in growing:
			gc.add_child(_growing_row(g))
	# Friends who have fallen: each opens the survivor's talk by the empty place.
	var memorials: Array = GameState.remembered_bonds()
	var remembered := []
	for sq in GameState.army:
		var c = sq.get("captain")
		if c == null:
			continue
		for name in c.get("history", {}).get("fallen_friends", []):
			if not memorials.any(func(rb): return rb["a"] == c and String(rb["b"].get("name", "")) == String(name)):
				remembered.append("%s remembers %s." % [c["first"], name])
	if not memorials.is_empty() or not remembered.is_empty():
		var mc := Widgets.card(tab, "Remembered")
		mc.get_parent().name = "RememberedCard"
		for rb in memorials:
			var survivor: Dictionary = rb["a"]
			var gone: Dictionary = rb["b"]
			var sid := int(survivor["id"])
			var gid := int(gone["id"])
			var title := String(survivor["first"]) + " remembers " + String(gone.get("first", gone.get("name", "")))
			mc.add_child(BondRow.make([survivor, gone], title, float(rb["points"]), 0, _open_bond.bind(sid, gid), false, Callable(),
				"BondMemory_%d_%d" % [sid, gid]))
		for line in remembered:
			mc.add_child(_note(line))
		# A candle for each friend remembered, before the talk button.
		for row in mc.find_children("BondRow", "PanelContainer", true, false):
			var line_box := (row as PanelContainer).get_child(0) as HBoxContainer
			if line_box != null:
				var flame := Motion.candle(52.0)
				line_box.add_child(flame)
				if line_box.get_child(line_box.get_child_count() - 2) is Button:
					line_box.move_child(flame, line_box.get_child_count() - 2)
	if ranked.is_empty() and growing.is_empty():
		tab.add_child(_note("None yet. Fight with captains side by side and they'll grow close."))
	_show_bond_changes(tab, ranked)


## On the Bonds tab: a talk waiting pings on its button, and a bond that has reached a new
## rank since the tab was last open pops its badge with a ring of brass and fills its bar
## from the start. The ranks are only taken as seen while the tab is open.
func _show_bond_changes(tab: Control, ranked: Array) -> void:
	var k := 0
	for dot in tab.find_children("NewDot", "Control", true, false):
		if (dot as Control).visible:
			Motion.ping(dot as Control, Style.BRASS, 0.3 * k)
			k += 1
	if _tab != "bonds":
		return
	var seen := _seen()
	var ranks: Dictionary = seen.get("ranks", {})
	for b in ranked:
		var a: Dictionary = b["a"]
		var c: Dictionary = b["b"]
		var key := "%d|%d" % [mini(int(a["id"]), int(c["id"])), maxi(int(a["id"]), int(c["id"]))]
		var rank := Captains.rank_for(float(b["points"]))
		if ranks.has(key) and rank > int(ranks[key]):
			for row in tab.find_children("BondRow", "Control", true, false):
				var t := row.find_child("BondTitle", true, false) as Label
				if t != null and t.text == "%s & %s" % [a["first"], c["first"]]:
					var badge := row.find_child("Rank_%s" % String(Captains.RANKS[rank]), true, false) as Control
					Motion.pop(badge, 1.5, 0.45)
					Motion.ring(badge, Style.BRASS, 0.45)
					Motion.grow(row.find_child("BondMeter", true, false) as Control, 0.0, 0.5)
		ranks[key] = rank
	seen["ranks"] = ranks


## Points still needed for the next rank (a big number at the top rank).
func _to_next_rank(points: float) -> float:
	var r := Captains.rank_for(points)
	return 999.0 if r + 1 >= Captains.RANK_POINTS.size() else float(Captains.RANK_POINTS[r + 1]) - points


func _growing_row(g: Dictionary) -> Control:
	return BondRow.make([g["a"], g["b"]], "%s & %s" % [g["a"]["first"], g["b"]["first"]], float(g["points"]))


## A bond on the shared row: both faces, the rank, what it does, the meter to the next
## rank, and the talk at the fire behind the talk button, dotted when there's a new one.
func _bond_row(bond: Dictionary) -> Control:
	var a: Dictionary = bond["a"]
	var b: Dictionary = bond["b"]
	var record := GameState.bond_record(int(a["id"]), int(b["id"]))
	var is_new := GameState.bond_conversation_is_new(int(a["id"]), int(b["id"]))
	return BondRow.make([a, b], "%s & %s" % [a["first"], b["first"]], float(bond["points"]),
		int(record.get("shared_battles", 0)), _open_bond.bind(int(a["id"]), int(b["id"])), is_new,
		Callable(), "BondConversation_%d_%d" % [int(a["id"]), int(b["id"])])


func _open_bond(a_id: int, b_id: int) -> void:
	Scenes.warband_scroll = _scroll.scroll_vertical if _scroll != null else 0
	Scenes.active_bond_a_id = a_id
	Scenes.active_bond_b_id = b_id
	Scenes.bond_conversation_return = "res://scenes/main_menu.tscn"
	Scenes.go("res://scenes/bond_conversation.tscn")


## A fallen captain: the dimmed face, their battles and kills as chips, Avenged, and the
## banner of the host that cut them down. Their last words stay as words.
func _memorial_row(f: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.name = "Memorial_%d" % int(f.get("id", 0))
	panel.add_theme_stylebox_override("panel", Style.box(Style.NIGHT, Style.RULE, 2, 14))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	var portrait := _captain_or_unit(f, f)
	portrait.modulate = Color(0.55, 0.55, 0.6)
	row.add_child(portrait)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 6)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	text.add_child(Style.name_label(String(f.get("name", "")), Style.BODY))
	if String(f.get("company", "")) != "":
		text.add_child(_note("Led %s · fell in battle %d" % [f["company"], int(f.get("battle", 0))]))
	var chips: Array = [Widgets.stat("battle", str(int(f.get("battles", 0)))), Widgets.stat("skull", str(int(f.get("kills", 0))))]
	if bool(f.get("avenged", false)):
		var av := Widgets.chip("Avenged", Style.BRASS, "★", "", true)
		av.name = "AvengedChip"
		chips.append(av)
	var marks := Widgets.chip_row(chips)
	text.add_child(marks)
	if String(f.get("killed_by_lord_name", "")) != "":
		var slayer := HBoxContainer.new()
		slayer.name = "Slayer"
		slayer.add_theme_constant_override("separation", 8)
		slayer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l: Dictionary = GameState.world.lord_by_id(int(f.get("killed_by_lord_id", -1))) if GameState.world != null else {}
		if not l.is_empty():
			slayer.add_child(Widgets.banner(String(l.get("realm", "")), Vector2(24, 34)))
		slayer.add_child(Widgets.icon_rect("skull", 22.0))
		var by := Style.label(String(f["killed_by_lord_name"]), Style.SMALL, Style.MUTED)
		by.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		by.custom_minimum_size.x = 10
		by.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slayer.add_child(by)
		text.add_child(slayer)
	var bonds: Array = f.get("bonds", [])
	if not bonds.is_empty():
		text.add_child(_note("Mourned by " + ", ".join(PackedStringArray(bonds))))
	if String(f.get("words", "")) != "":
		var w := Style.label("\"%s\"" % f["words"], Style.SMALL, Style.BRASS)
		w.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_child(w)
	if String(f.get("avenged_words", "")) != "":
		var av_words := Style.label(f["avenged_words"], Style.SMALL, Style.PLAYER_LIGHT)
		av_words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_child(av_words)
	row.add_child(Motion.candle(56.0))
	if int(f.get("id", 0)) > 0:
		_add_profile_tap(panel, int(f["id"]), String(f.get("name", "Captain")))
	return panel


## A captive lord: their face and banner, and what you can do with them as verbs, each
## with what it brings under it. A refusal says why on the screen.
func _captive_lord_row(cl: Dictionary) -> Control:
	var panel := PanelContainer.new()
	var lord_id := int(cl["id"])
	panel.name = "Captive_%d" % lord_id
	panel.add_theme_stylebox_override("panel", Style.box(Style.NIGHT, Style.RULE, 2, 14))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	col.add_child(head)
	var face := CaptainArt.portrait(LordVoice.portrait_record(cl), Vector2(56, 70))
	if face.texture != null:
		head.add_child(Widgets.framed(face, Vector2(56, 70)))
	var realm := String(cl.get("realm", ""))
	var who := VBoxContainer.new()
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.alignment = BoxContainer.ALIGNMENT_CENTER
	who.add_theme_constant_override("separation", 6)
	head.add_child(who)
	var name_lbl := Style.name_label(String(cl.get("name", "Captive Lord")), Style.BODY)
	name_lbl.add_theme_color_override("font_color", Style.BRASS)
	who.add_child(name_lbl)
	var marks := HBoxContainer.new()
	marks.add_theme_constant_override("separation", 8)
	who.add_child(marks)
	marks.add_child(Widgets.stat("renown", str(int(cl.get("renown", 0)))))
	head.add_child(Widgets.banner(realm, Vector2(40, 56)))

	# A flow, not a row: a crowned company has four or five choices for each captive,
	# more than fit across a phone, so they wrap onto a second line.
	var btns := HFlowContainer.new()
	btns.add_theme_constant_override("h_separation", 10)
	btns.add_theme_constant_override("v_separation", 10)
	col.add_child(btns)
	var ransom: int = GameState.ransom_offer(lord_id)

	var talk_btn := _captive_button("TalkToCaptive_%d" % lord_id, "Talk", func():
		var talk = load("res://scripts/world/lord_conversation.gd").open(self, GameState, lord_id, "captive")
		talk.closed.connect(_build))
	talk_btn.icon = Widgets.icon("talk")
	btns.add_child(Widgets.priced(talk_btn, []))

	var ransom_btn := _captive_button("Ransom_%d" % lord_id, "Ransom", func():
		GameState.accept_lord_ransom(lord_id)
		Sound.play("coins")
		_build())
	btns.add_child(Widgets.priced(ransom_btn, [["silver", "+" + Widgets.thousands(ransom)]]))

	if GameState.has_contract() and GameState.world != null and GameState.world.at_war(GameState.contract_realm(), realm):
		var bonus: int = int(GameState.contract.get("bonus_per_lord", 100))
		var deliver_btn := _captive_button("Deliver_%d" % lord_id, "Deliver", func():
			GameState.deliver_lord_to_employer(lord_id)
			Sound.play("coins")
			_build())
		btns.add_child(Widgets.priced(deliver_btn, [["silver", "+" + Widgets.thousands(bonus)]]))

	var honor_btn := _captive_button("Release_%d" % lord_id, "Release", func():
		GameState.release_lord_for_honor(lord_id)
		Sound.play("page")
		_build())
	var freed: Dictionary = GameState.release_reward(lord_id)
	btns.add_child(Widgets.priced(honor_btn, [["bond", "+%d" % int(freed["regard"])], ["renown", "+%d" % int(freed["renown"])]]))

	if GameState.is_crowned():
		var check: Dictionary = GameState.swear_check(lord_id)
		var swear := _captive_button("SwearToCrown_%d" % lord_id, "Swear", func():
			GameState.swear_lord_to_crown(lord_id)
			Sound.play("horn")
			_build())
		swear.icon = Widgets.icon("crown")
		swear.disabled = not check["ok"]
		var priced := Widgets.priced(swear, [], String(check["reason"]))
		btns.add_child(priced)
	return panel


func _captive_button(button_name: String, text: String, act: Callable) -> Button:
	var b := Button.new()
	b.name = button_name
	b.text = text
	b.custom_minimum_size = Vector2(150, Style.TOUCH)
	b.add_theme_constant_override("icon_max_width", 30)
	b.pressed.connect(act)
	return b


## Captains who have earned a veteran role and not yet chosen one.
func _promotions_ready() -> int:
	var n := 0
	for s in GameState.army:
		var c = s.get("captain")
		if typeof(c) == TYPE_DICTIONARY and Captains.can_specialize(c):
			n += 1
	return n


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


## The captain's face with their troop on a round badge at its foot; the troop alone when
## there's no face to draw.
func _squad_art(captain, squad: Dictionary) -> Control:
	if typeof(captain) != TYPE_DICTIONARY or CaptainArt.texture(captain) == null:
		return _portrait(_kit(squad), String(squad.get("culture", GameState.culture)))
	var art := Control.new()
	art.name = "CaptainAndTroopArt"
	art.custom_minimum_size = Vector2(66, 84)
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var face := CaptainArt.portrait(captain, Vector2(60, 80))
	face.position = Vector2.ZERO
	face.size = Vector2(60, 80)
	if int(captain.get("wounded", 0)) > 0:
		face.modulate = Color(0.75, 0.75, 0.82)
	art.add_child(face)
	var badge := Panel.new()
	badge.name = "TroopBadge"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_stylebox_override("panel", Style.box(Style.NIGHT, Style.BRASS.darkened(0.3), 2, 18))
	badge.position = Vector2(30, 48)
	badge.size = Vector2(36, 36)
	art.add_child(badge)
	var unit := _portrait(_kit(squad), String(squad.get("culture", GameState.culture)))
	unit.custom_minimum_size = Vector2(30, 30)
	unit.position = Vector2(3, 3)
	unit.size = Vector2(30, 30)
	badge.add_child(unit)
	return art


func _on_battle() -> void:
	if GameState.total_men() == 0:
		return
	Scenes.go("res://scenes/battle.tscn")


func _on_reinforce() -> void:
	var before := {}
	for s in GameState.army:
		before[int(s.get("id", 0))] = int(s["men"])
	GameState.reinforce()
	# The companies that took men, in roster order, flash one after another as they fill.
	_refilled.clear()
	var order := 0
	for s in GameState.army:
		var id := int(s.get("id", 0))
		if before.has(id) and int(s["men"]) > int(before[id]):
			var unit_id := String(s.get("unit", ""))
			var full := Units.full_size(unit_id) if Units.has(unit_id) else Troops.full_size(String(s["type"]))
			_refilled[id] = order
			_refilled["from_%d" % id] = float(before[id]) / maxf(1.0, float(full))
			order += 1
	_build()
	_refilled.clear()
