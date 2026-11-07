## The world map: draws the Glass Sea and the parties on it, and turns taps into travel.
## All rules live in world_sim.gd; this screen never moves anyone itself.
##
## Tap a settlement to see it and ride there. Time passes while you ride or wait: one
## hour a second, or two at 2x, and every day costs wages and food. A bandit band on the
## road stops you: lead the fight, send your men in without you, or withdraw. Drag to
## look around, pinch or scroll to zoom, double-tap to find your party.
extends Node2D

const WorldSim = preload("res://scripts/world/world_sim.gd")
const Data = preload("res://scripts/world/world_data.gd")
const Cultures = preload("res://scripts/data/cultures.gd")
const Style = preload("res://scripts/ui/style.gd")
const AutoResolve = preload("res://scripts/battle/auto_resolve.gd")
const MapArt = preload("res://scripts/art/map_art.gd")
const MapTerrain = preload("res://scripts/world/map_terrain.gd")
const MapBackdrop = preload("res://scripts/world/map_backdrop.gd")
const TravelPresentation = preload("res://scripts/world/travel_presentation.gd")
const Lords = preload("res://scripts/data/lords.gd")
const MarshalArmies = preload("res://scripts/world/marshal_armies.gd")
const LordVoice = preload("res://scripts/data/lord_voice.gd")
const CaptainArt = preload("res://scripts/ui/captain_art.gd")
const SettlementVista = preload("res://scripts/ui/settlement_vista.gd")
const Heraldry = preload("res://scripts/ui/heraldry.gd")
const Captains = preload("res://scripts/data/captains.gd")
const Troops = preload("res://scripts/data/troops.gd")
const Art = preload("res://scripts/art/unit_art.gd")
const Widgets = preload("res://scripts/ui/widgets.gd")
const SaveSlots = preload("res://scripts/save_slots.gd")
const LordConversation = preload("res://scripts/world/lord_conversation.gd")
const LordTalk = preload("res://scripts/world/lord_talk.gd")
const Gatherings = preload("res://scripts/data/gatherings.gd")
const KingdomScreen = preload("res://scripts/world/kingdom_screen.gd")
const SKY_SHADER = preload("res://shaders/map_sky.gdshader")

const TOP_BAR := 150.0
## The pills in the top bar, in order: the four numbers every choice on the map weighs.
const RESOURCE_KEYS := ["men", "silver", "food", "renown"]
## Game hours that pass each real second at 1x.
const HOURS_PER_SECOND := 1.0
## How far you can zoom: map units across the screen, most and fewest.
const WIDEST_VIEW := 1050.0
const NARROWEST_VIEW := 260.0
## A tap this close (screen units) to a settlement or a party picks it.
const TAP_RADIUS := 46.0
## A press that moves less than this is a tap, not a drag.
const DRAG_SLOP := 14.0
## Screen pixels per pixel of a settlement or party sprite, at the default zoom.
const SPRITE_PIXEL := 2.5
## The light over the map through the day.
const NIGHT_LIGHT := Color(0.46, 0.5, 0.78)
const DAWN_LIGHT := Color(1.0, 0.84, 0.72)
const DUSK_LIGHT := Color(1.0, 0.75, 0.58)
const LAMP := Color(1.0, 0.76, 0.42)
## A burned village, drawn charred; lords' names show from this sprite size up.
const BURNT := Color(0.42, 0.36, 0.32)
const LORD_NAMES_PX := 2.5

var world
var font: Font
var speed := 1.0
var autoplay := false
var cam_center := Vector2.ZERO
## Screen units per map unit.
var cam_scale := 1.0
var _view := Rect2()
var _selected := ""
var _sheet := ""
var _press_at := Vector2.ZERO
var _press_center := Vector2.ZERO
var _pressing := false
var _touches := {}
var _pinch_from := 0.0
var _pinch_scale := 1.0
var _pinching := false
var _save_clock := 0.0
## Seconds since the map opened, for anything that moves on its own.
var _clock := 0.0
## Presentation-only contact left by the moving warband: dust, footsteps or wake.
var _travel_marks: Array = []
var _contact_position := Vector2(INF, INF)
var _contact_distance := 0.0
var _contact_kind := "none"
var _travel_context := {}
var _music_clock := 0.0
var _siege_drum_clock := 0.0

var terrain
var backdrop
var sky: ColorRect
var labels: Node2D
var _plate: StyleBoxFlat

var top_panel: PanelContainer
var _toast_panel: PanelContainer
var _toast_label: Label
var _toast_tween: Tween
## The lord you're talking to, face to face (lord_conversation.gd), or null.
var _talk = null
## Your crown's screen while it's open, or null.
var _kingdom = null
## The Warband button, which counts the talks waiting at the fire.
var _warband_btn: Button
var _talks_waiting := -1
var _badge_hour := -1
## Why the last friendly lord stopped you ("first", "news", "army").
var _stop_reason := ""
## The free-floating HUD layer: the toast sits on it, outside any layout.
var _hud: Control
## How close a friendly lord must be, in encounter radii, for his sheet to offer Talk.
const TALK_REACH := 4.0
var clock_label: Label
var day_label: Label
var resource_buttons := {}
var status_label: Label
## What the company is doing, as an icon before the status line (ride, wait, home, fight).
var status_icon: TextureRect
## Chips after the status line: who chases you, what's running low, who's in chains.
var status_chips: HBoxContainer
var _status_sig := ""
## The pinned commitment, as a chip under the top bar: tap it to open the commitment.
var pinned_chip: Button
var _pinned_sig := ""
var _pinned_hour := -1
var _pinned_for := ""
var speed_button: Button
var warband_button: Button
var status_progress: ProgressBar
var day_icon: TextureRect
## Bottom of the screen, in thumb reach: the Warband, and pause / play / fast.
var bottom_bar: Control
var pause_button: Button
var play_button: Button
var fast_button: Button
var paused := false
var _trip_key := ""
var _trip_total := 0.0
var sheet_panel: PanelContainer
## A letter that has just come: a banner under the top bar for a few seconds. The clock
## keeps running.
var letter_banner: PanelContainer
var _banner_letter := ""
var _banner_left := 0.0
## The gathering the banner invites you to, or -1 when it brings a letter.
var _banner_invite := -1
var _banner_title: Label
var _banner_from: Label
var _banner_line: Label
var _banner_seal := Color("8e1f17")
var unread_badge: PanelContainer
const LETTER_BANNER_SECONDS := 9.0
var sheet_title: Label
## The sheet's header: a tile with the sheet's icon, the title and a line under it, and a
## close button. Sheets with a picture header (_sheet_header) hide it.
var sheet_head: HBoxContainer
var sheet_tile: PanelContainer
var sheet_tile_icon: TextureRect
var sheet_sub: Label
var sheet_close: Button
var _sheet_close_cb: Callable
var sheet_body: Label
## Pictures above a sheet's text: the odds of a fight, for one.
var sheet_extra: VBoxContainer
## A lord's face and house banner, above sheets about them.
var sheet_lord_row: HBoxContainer
var sheet_portrait: TextureRect
var sheet_banner: Control
var _banner_realm := ""
var sheet_row: GridContainer


func _ready() -> void:
	font = ThemeDB.fallback_font
	autoplay = OS.get_cmdline_user_args().has("--autoplay")
	world = GameState.world
	if world == null:
		get_tree().change_scene_to_file.call_deferred("res://scenes/title.tscn")
		return
	if GameState.bond_intro_pending() and GameState.desertion_warning == "" and not autoplay:
		get_tree().change_scene_to_file.call_deferred("res://scenes/bond_intro.tscn")
		return
	if autoplay:
		speed = 8.0
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_layers()
	_build_hud()
	_build_letter_banner()
	get_viewport().size_changed.connect(_layout)
	_layout()
	cam_scale = _view.size.x / 640.0
	cam_center = world.party_pos(world.player())
	_clamp_camera()
	_sync_layers()
	_refresh_hud()
	_update_music()
	_refresh_travel_presentation()
	if world.encounter != -1:
		_open_encounter()
	elif not world.pending_assault.is_empty():
		_open_assault_call()
	elif GameState.desertion_warning != "":
		_open_desertion_warning()
	elif Scenes.map_raid != "" and Scenes.map_raid == world.here():
		_open_raid(Scenes.map_raid)
	elif GameState.has_notice():
		var notice: Dictionary = GameState.take_map_notice()
		_open_notice(notice["text"], notice["title"], notice["items"])
	elif world.here() != "":
		_open_here()
	Scenes.map_raid = ""
	# Back from People & Letters with a place to look at (or ride to).
	if Scenes.map_focus != "":
		var focus := Scenes.map_focus
		Scenes.map_focus = ""
		if Data.SETTLEMENTS.has(focus):
			_selected = focus
			cam_center = Data.pos(focus)
			_clamp_camera()
			_sync_layers()


func _exit_tree() -> void:
	Sound.set_loop("")
	Sound.set_movement_loop("")


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if GameState.world != null:
			GameState.save_game()


func _layout() -> void:
	var vs := get_viewport_rect().size
	var insets := Style.safe_insets(get_viewport())
	if top_panel != null:
		top_panel.offset_bottom = TOP_BAR + float(insets["top"])
		var sb := Style.box(Style.NIGHT, Color(0, 0, 0, 0), 0, 0)
		sb.content_margin_top = 8.0 + float(insets["top"])
		top_panel.add_theme_stylebox_override("panel", sb)
		var bottom := Style.box(Style.PANEL, Style.RULE, 2, 14)
		bottom.content_margin_bottom = 16.0 + float(insets["bottom"])
		bottom.content_margin_left = 16.0
		bottom.content_margin_right = 16.0
		bottom.content_margin_top = 14.0
		sheet_panel.add_theme_stylebox_override("panel", bottom)
	var top: float = TOP_BAR + float(insets["top"])
	if pinned_chip != null:
		pinned_chip.offset_top = top + 10.0
		pinned_chip.offset_bottom = top + 10.0 + Style.TOUCH
	_view = Rect2(Vector2(0.0, top), Vector2(vs.x, vs.y - top))
	_clamp_camera()
	_sync_layers()
	queue_redraw()


# ---------------------------------------------------------------- time

func _process(delta: float) -> void:
	# On the way out (no campaign, or the smoke test is done) the screen was never built.
	if world == null or top_panel == null:
		return
	if GameState.desertion_warning != "" and _sheet not in ["encounter", "notice", "warning", "menu", "talk"]:
		_open_desertion_warning()
	if GameState.bond_intro_pending() and GameState.desertion_warning == "" and not autoplay and _sheet not in ["encounter", "notice", "warning", "talk"]:
		Scenes.go("res://scenes/bond_intro.tscn")
		return
	if autoplay:
		_autoplay()
	_watch_letters(delta)
	# An encounter or a note about the last battle holds the clock until it's answered.
	if world.busy() and not paused and _sheet not in ["encounter", "notice", "menu", "warning", "activity", "recommendation", "talk"]:
		GameState.advance(delta * speed * HOURS_PER_SECOND)
		_save_clock += delta
		if _save_clock > 5.0:
			_save_clock = 0.0
			GameState.save_game()
	for e in world.events:
		match e["type"]:
			"arrived", "waited":
				GameState.save_game()
				Sound.play("page", 0.0, 0.05)
				_open_here()
			"encounter", "friendly_encounter":
				GameState.save_game()
				_stop_reason = String(e.get("reason", ""))
				_open_encounter()
			"friendly_pass":
				var passer = world.party(int(e["party"]))
				if passer != null:
					_toast(_pass_line(passer))
			"ransom_offer":
				GameState.save_game()
				_open_ransom_sheet(int(e["lord_id"]))
			"assault_ready":
				GameState.save_game()
				_open_assault_call()
			"siege_loot":
				GameState.silver += int(e.get("silver", 0))
				GameState.renown += int(e.get("renown", 0))
				GameState.settle()
				Sound.play_place_fallen()
				_open_notice("Assault successful at %s! Claimed %d silver and %d renown." % [
					Data.settlement(String(e.get("target", "")))["name"],
					int(e.get("silver", 0)), int(e.get("renown", 0))
				], "Siege Victory")
			"chased":
				Sound.play("alarm", 0.0, 0.05)
			"war":
				Sound.play_war_horn()
			"captured":
				Sound.play_place_fallen()
	world.events.clear()
	if GameState.desertion_warning != "" and _sheet not in ["encounter", "notice", "warning", "menu", "talk"]:
		_open_desertion_warning()
	# Men deserting on the road: say so, and hold the clock while the player reads it.
	if GameState.has_notice() and _sheet not in ["encounter", "notice", "menu", "warning", "talk"]:
		var notice: Dictionary = GameState.take_map_notice()
		_open_notice(notice["text"], notice["title"] if notice["title"] != "" else "On the road", notice["items"])
		Sound.play("page")
	_clock += delta
	_music_clock -= delta
	if _music_clock <= 0.0:
		_music_clock = 0.5
		_update_music()
	_siege_drum_clock -= delta
	if _siege_drum_clock <= 0.0:
		_siege_drum_clock = 5.0
		_check_siege_proximity_sound()
	_refresh_travel_presentation()
	_update_travel_contact(delta)
	_refresh_hud()
	_sync_layers()
	queue_redraw()


## The smoke test: ride at the nearest band and fight it, send the men in against the
## next, then go into the next settlement you reach and spend there.
func _autoplay() -> void:
	if _sheet == "warning":
		_acknowledge_desertion()
	if _sheet == "talk" and _talk != null:
		# A lord stopping to talk is not a fight: part ways.
		_talk.choose("leave")
		return
	if _sheet == "encounter":
		var met = world.party(world.encounter) if world.encounter != -1 else null
		if met != null and met.kind == WorldSim.LORD and world.relation_to_player(met.faction) == "friendly":
			# A friendly lord stopping to greet you is not a fight: wave them on.
			_on_part_ways_friendly()
			return
		if GameState.autoplay_battles == 0:
			_on_fight()
		else:
			GameState.autoplay_battles += 1
			_on_send_in()
		return
	if _sheet == "here" and GameState.autoplay_battles >= 2:
		_on_enter()
		return
	if _sheet == "notice" or _sheet == "here":
		_close_sheet()
	if not world.busy() and world.encounter == -1:
		var best := ""
		var best_h := INF
		for b in world.bands():
			var at: String = b.next if b.moving() else b.node
			var h: float = world.hours_to(at)
			if at != world.here() and h < best_h:
				best_h = h
				best = at
		if best != "":
			world.travel(best)
		else:
			world.wait(2.0)


# ---------------------------------------------------------------- camera

func _clamp_camera() -> void:
	if _view.size.x <= 0.0:
		return
	cam_scale = clampf(cam_scale, _view.size.x / WIDEST_VIEW, _view.size.x / NARROWEST_VIEW)
	var half := _view.size / cam_scale * 0.5
	var margin := 80.0
	cam_center.x = clampf(cam_center.x, minf(half.x - margin, Data.SIZE.x * 0.5), maxf(Data.SIZE.x - half.x + margin, Data.SIZE.x * 0.5))
	cam_center.y = clampf(cam_center.y, minf(half.y - margin, Data.SIZE.y * 0.5), maxf(Data.SIZE.y - half.y + margin, Data.SIZE.y * 0.5))


func _to_screen(p: Vector2) -> Vector2:
	return _view.get_center() + (p - cam_center) * cam_scale


func _to_map(p: Vector2) -> Vector2:
	return cam_center + (p - _view.get_center()) / cam_scale


func _zoom_at(screen_point: Vector2, factor: float) -> void:
	var before := _to_map(screen_point)
	cam_scale *= factor
	_clamp_camera()
	cam_center += before - _to_map(screen_point)
	_clamp_camera()


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	# Two fingers pinch to zoom. Touches also arrive as an emulated mouse, which pans and
	# taps; while pinching, that's ignored.
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
		if _touches.size() == 2:
			_pinching = true
			var pts: Array = _touches.values()
			_pinch_from = maxf(1.0, (pts[0] as Vector2).distance_to(pts[1]))
			_pinch_scale = cam_scale
		elif _touches.is_empty():
			_pinching = false
		return
	if event is InputEventScreenDrag:
		_touches[event.index] = event.position
		if _touches.size() == 2:
			var pts: Array = _touches.values()
			var mid: Vector2 = ((pts[0] as Vector2) + (pts[1] as Vector2)) * 0.5
			var want := _pinch_scale * (pts[0] as Vector2).distance_to(pts[1]) / _pinch_from
			_zoom_at(mid, want / cam_scale)
		return
	var mb := event as InputEventMouseButton
	if mb != null:
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_at(mb.position, 1.15)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_at(mb.position, 1.0 / 1.15)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if mb.double_click:
					cam_center = world.party_pos(world.player())
					_clamp_camera()
					_pressing = false
					return
				_pressing = true
				_press_at = mb.position
				_press_center = cam_center
			elif _pressing:
				_pressing = false
				if not _pinching and mb.position.distance_to(_press_at) < DRAG_SLOP and _view.has_point(mb.position):
					_tap(mb.position)
		return
	var mm := event as InputEventMouseMotion
	if mm != null and _pressing and not _pinching and (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		if mm.position.distance_to(_press_at) >= DRAG_SLOP:
			cam_center = _press_center - (mm.position - _press_at) / cam_scale
			_clamp_camera()


func _tap(at: Vector2) -> void:
	if _sheet in ["encounter", "notice", "warning", "menu"]:
		return
	var best := ""
	var best_d := TAP_RADIUS
	for id in Data.SETTLEMENTS:
		var d := at.distance_to(_to_screen(Data.pos(id)))
		if d < best_d:
			best_d = d
			best = id
	if best != "":
		_selected = best
		if best == world.here():
			_open_here()
		else:
			_open_preview(best)
		return
	for b in world.bands():
		if at.distance_to(_to_screen(world.party_pos(b)) + Vector2(0, -14) * _sprite_px()) < TAP_RADIUS:
			_open_band(b)
			return
	for lp in world.visible_lord_parties():
		if at.distance_to(_to_screen(world.party_pos(lp)) + Vector2(0, -16) * _sprite_px()) < TAP_RADIUS:
			_open_lord(lp)
			return
	_selected = ""
	if _sheet != "notice":
		_close_sheet()


# ---------------------------------------------------------------- sheets

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var hud := Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud = hud
	hud.theme = Style.make_theme()
	layer.add_child(hud)

	top_panel = PanelContainer.new()
	top_panel.anchor_right = 1.0
	top_panel.offset_bottom = TOP_BAR
	hud.add_child(top_panel)
	var stack_top := VBoxContainer.new()
	stack_top.add_theme_constant_override("separation", 6)
	top_panel.add_child(stack_top)
	# Row one: the day and the hour, the men, purse, food and renown as pills, and the menu.
	var resource_row := HBoxContainer.new()
	resource_row.add_theme_constant_override("separation", 6)
	stack_top.add_child(resource_row)
	resource_row.add_child(Widgets.icon_rect("day", 28.0))
	day_label = Style.label("", Style.SMALL, Style.BRASS)
	day_label.name = "DayLabel"
	day_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	resource_row.add_child(day_label)
	day_icon = Widgets.icon_rect("sun", 28.0)
	day_icon.name = "HourIcon"
	resource_row.add_child(day_icon)
	clock_label = Style.label("", Style.SMALL, Style.MUTED)
	clock_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clock_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	clock_label.clip_text = true
	clock_label.custom_minimum_size = Vector2(10, 0)
	resource_row.add_child(clock_label)
	for key in RESOURCE_KEYS:
		var badge := _button("", _open_resource.bind(key))
		badge.name = "Pill_%s" % key
		badge.icon = Widgets.icon(key)
		badge.expand_icon = true
		badge.add_theme_constant_override("icon_max_width", 26)
		badge.add_theme_font_size_override("font_size", Style.text_size(Style.SMALL))
		badge.custom_minimum_size = Vector2(92, 64)
		badge.add_theme_stylebox_override("normal", _pill_box(Style.PANEL))
		badge.add_theme_stylebox_override("hover", _pill_box(Style.PANEL.lightened(0.08)))
		badge.add_theme_stylebox_override("pressed", _pill_box(Style.PANEL.darkened(0.1)))
		resource_buttons[key] = badge
		resource_row.add_child(badge)
	warband_button = _button("", _on_menu)
	warband_button.name = "MenuButton"
	warband_button.tooltip_text = "Menu"
	warband_button.icon = Widgets.icon("menu")
	warband_button.expand_icon = true
	warband_button.add_theme_constant_override("icon_max_width", 30)
	warband_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warband_button.custom_minimum_size = Vector2(64, 64)
	resource_row.add_child(warband_button)
	# Unread letters, counted on the menu button.
	unread_badge = Widgets.count_badge(0, "UnreadBadge")
	unread_badge.position = Vector2(34, -6)
	warband_button.add_child(unread_badge)
	# Row two: what the company is doing (with how far along), then chips for what's
	# pressing: a chaser, supplies running low, captives in your train.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	stack_top.add_child(row)
	status_icon = Widgets.icon_rect("ride", 30.0)
	status_icon.name = "StatusIcon"
	status_icon.modulate = Style.MUTED
	row.add_child(status_icon)
	var status_box := VBoxContainer.new()
	status_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_box.add_theme_constant_override("separation", 3)
	status_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(status_box)
	status_label = Style.label("", Style.SMALL, Style.TEXT)
	status_label.name = "StatusLine"
	status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status_label.custom_minimum_size = Vector2(10, 0)
	status_box.add_child(status_label)
	status_progress = ProgressBar.new()
	status_progress.show_percentage = false
	status_progress.custom_minimum_size = Vector2(10, 4)
	status_progress.max_value = 1.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.08)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Style.BRASS
	status_progress.add_theme_stylebox_override("background", bg)
	status_progress.add_theme_stylebox_override("fill", fill)
	status_box.add_child(status_progress)
	status_chips = HBoxContainer.new()
	status_chips.name = "StatusChips"
	status_chips.add_theme_constant_override("separation", 6)
	status_chips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(status_chips)

	# The pinned commitment, under the bar: the goal you chose to keep in sight.
	pinned_chip = _quiet_button("", _open_pinned)
	pinned_chip.name = "PinnedCommitment"
	pinned_chip.anchor_left = 0.5
	pinned_chip.anchor_right = 0.5
	pinned_chip.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pinned_chip.custom_minimum_size = Vector2(0, Style.TOUCH)
	var pb := Style.box(Color(Style.NIGHT, 0.92), Color("6d5222"), 2, 40)
	for state in ["normal", "hover", "pressed", "focus"]:
		pinned_chip.add_theme_stylebox_override(state, pb)
	pinned_chip.visible = false
	var pin_row := HBoxContainer.new()
	pin_row.name = "PinnedRow"
	pin_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pin_row.offset_left = 16
	pin_row.offset_right = -16
	pin_row.alignment = BoxContainer.ALIGNMENT_CENTER
	pin_row.add_theme_constant_override("separation", 10)
	pin_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pinned_chip.add_child(pin_row)
	hud.add_child(pinned_chip)

	# In thumb reach at the bottom: the Warband, and the clock's controls.
	bottom_bar = MarginContainer.new()
	bottom_bar.name = "TimeControls"
	bottom_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_bar.offset_top = -112.0
	bottom_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		bottom_bar.add_theme_constant_override("margin_" + side, 14)
	bottom_bar.add_theme_constant_override("margin_bottom", 18)
	hud.add_child(bottom_bar)
	var brow := HBoxContainer.new()
	brow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_bar.add_child(brow)
	var camp := _button("Warband", _on_warband)
	camp.name = "WarbandButton"
	_warband_btn = camp
	camp.icon = Widgets.icon("company")
	camp.expand_icon = true
	camp.add_theme_constant_override("icon_max_width", 30)
	camp.add_theme_constant_override("h_separation", 10)
	camp.custom_minimum_size = Vector2(170, Style.TOUCH)
	camp.add_theme_stylebox_override("normal", _pill_box(Color(Style.PANEL, 0.94)))
	brow.add_child(camp)
	# Talks waiting at the fire, counted on the button.
	var talks := Widgets.count_badge(0, "TalksBadge")
	talks.position = Vector2(146, -8)
	camp.add_child(talks)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brow.add_child(gap)
	var clock_row := HBoxContainer.new()
	clock_row.add_theme_constant_override("separation", 0)
	brow.add_child(clock_row)
	pause_button = _time_button("pause", _on_time.bind(0.0))
	play_button = _time_button("play", _on_time.bind(1.0))
	fast_button = _time_button("fast", _on_time.bind(2.0))
	for b in [pause_button, play_button, fast_button]:
		clock_row.add_child(b)
	speed_button = fast_button

	# The sheet sits at the bottom of a full-screen column, so it takes the screen's width
	# and grows upward to fit what it says.
	var frame := MarginContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "bottom"]:
		frame.add_theme_constant_override("margin_" + side, 8)
	hud.add_child(frame)
	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(stack)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(spacer)
	sheet_panel = PanelContainer.new()
	sheet_panel.visible = false
	stack.add_child(sheet_panel)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 12)
	sheet_panel.add_child(sv)
	sheet_lord_row = HBoxContainer.new()
	sheet_lord_row.name = "LordHeader"
	sheet_lord_row.add_theme_constant_override("separation", 12)
	sheet_lord_row.visible = false
	sv.add_child(sheet_lord_row)
	sheet_portrait = TextureRect.new()
	sheet_portrait.custom_minimum_size = Vector2(64, 84)
	sheet_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sheet_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sheet_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sheet_lord_row.add_child(sheet_portrait)
	sheet_banner = Control.new()
	sheet_banner.custom_minimum_size = Vector2(90, 84)
	sheet_banner.draw.connect(func():
		# The lord's realm banner, the same one their party flies on the map.
		if _banner_realm != "":
			Heraldry.realm_banner(sheet_banner, _banner_realm, Rect2(4, 2, 76, 80)))
	sheet_lord_row.add_child(sheet_banner)
	sheet_head = HBoxContainer.new()
	sheet_head.name = "SheetHead"
	sheet_head.add_theme_constant_override("separation", 16)
	sv.add_child(sheet_head)
	sheet_tile = PanelContainer.new()
	sheet_tile.name = "SheetTile"
	sheet_tile.custom_minimum_size = Vector2(84, 84)
	sheet_tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sheet_head.add_child(sheet_tile)
	sheet_tile_icon = TextureRect.new()
	sheet_tile_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sheet_tile_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sheet_tile_icon.custom_minimum_size = Vector2(46, 46)
	sheet_tile_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sheet_tile_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sheet_tile.add_child(sheet_tile_icon)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	words.add_theme_constant_override("separation", 2)
	sheet_head.add_child(words)
	sheet_title = Style.label("", Style.LARGE, Style.TEXT)
	sheet_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var face: Font = Style.display_font()
	if face != null:
		sheet_title.add_theme_font_override("font", face)
	words.add_child(sheet_title)
	sheet_sub = Style.label("", Style.SMALL, Style.MUTED)
	sheet_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(sheet_sub)
	sheet_close = _close_x()
	sheet_close.name = "SheetClose"
	sheet_head.add_child(sheet_close)
	sheet_extra = VBoxContainer.new()
	sheet_extra.name = "SheetExtra"
	sheet_extra.add_theme_constant_override("separation", 10)
	sheet_extra.visible = false
	sv.add_child(sheet_extra)
	sheet_body = Style.label("", Style.SMALL, Style.MUTED)
	sheet_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sheet_body.custom_minimum_size = Vector2(10, 0)
	sv.add_child(sheet_body)
	sheet_row = GridContainer.new()
	sheet_row.name = "SheetDock"
	sheet_row.columns = 2
	sheet_row.add_theme_constant_override("h_separation", 14)
	sheet_row.add_theme_constant_override("v_separation", 14)
	sv.add_child(sheet_row)


func _button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, Style.TOUCH)
	b.pressed.connect(callback)
	return b


## Labels that only put the sheet away. They become the ✕ in its corner instead of taking
## a tile in the dock; a real choice (Withdraw, Back to journal) stays a tile.
const SHEET_DISMISS := ["close", "leave", "part ways", "not yet"]
## The dock layout (mockup B): a header with an icon tile, the title, a line under it and a
## ✕; the text; then the actions side by side as big icon tiles in thumb reach. `sub` is the
## line under the title; `icon` overrides the tile's icon (otherwise chosen by `kind`).
## Each button is [verb, callback, primary?, icon key, costs]: the icon is named, never
## guessed from the words, and costs ([[key, text]] or [[key, text, tone]]) sit under it.
func _show_sheet(kind: String, title: String, body: String, buttons: Array, sub: String = "", icon: String = "") -> void:
	_sheet = kind
	# A sheet opened from a talk (the war news) shows over it; closing it goes back.
	if _talk != null and is_instance_valid(_talk):
		_talk.visible = false
	if bottom_bar != null:
		bottom_bar.visible = false
	sheet_lord_row.visible = false
	for c in sheet_extra.get_children():
		# Out now, so a sheet opened again this frame keeps its pieces' names.
		sheet_extra.remove_child(c)
		c.queue_free()
	sheet_extra.visible = false
	var danger := _sheet_is_danger(kind)
	sheet_head.visible = true
	sheet_title.text = title
	sheet_title.visible = true
	sheet_title.add_theme_color_override("font_color", Style.ENEMY_LIGHT if kind == "warning" else Style.TEXT)
	sheet_sub.text = sub
	sheet_sub.visible = sub != ""
	var tile_icon := icon if icon != "" else _sheet_icon(kind)
	sheet_tile_icon.texture = Widgets.icon(tile_icon) if tile_icon != "" else null
	sheet_tile.visible = sheet_tile_icon.texture != null
	sheet_tile.add_theme_stylebox_override("panel", Style.box(Color("3a1714") if danger else Color("2a2410"),
		Style.ENEMY if danger else Style.BRASS, 3, 18))
	sheet_body.text = body
	sheet_body.visible = body != ""
	# The ✕ takes over a button that only puts the sheet away.
	_sheet_close_cb = Callable()
	var actions := []
	for spec in buttons:
		if String(spec[0]).to_lower() in SHEET_DISMISS and not _sheet_close_cb.is_valid():
			_sheet_close_cb = spec[1]
		else:
			actions.append(spec)
	sheet_close.visible = _sheet_close_cb.is_valid()
	var n := actions.size()
	sheet_row.columns = maxi(1, 2 if n == 4 else mini(n, 3))
	sheet_row.visible = n > 0
	for c in sheet_row.get_children():
		# Out now, not at the end of the frame, so the new tiles keep their names.
		sheet_row.remove_child(c)
		c.queue_free()
	for spec in actions:
		sheet_row.add_child(_dock_button(String(spec[0]), spec[1], spec.size() > 2 and spec[2], danger, n,
			String(spec[3]) if spec.size() > 3 else "", spec[4] if spec.size() > 4 else []))
	if not sheet_panel.visible or Style.closing(sheet_panel):
		sheet_panel.visible = true
		Style.ease_in(sheet_panel)


## One action in the sheet's dock: its icon above its words, a big tile in thumb reach.
## The main one is brass, or red when it means a fight. What it costs or earns sits under
## the tile as icons and numbers, never in the words.
func _dock_button(text: String, callback: Callable, primary: bool, danger: bool, count: int, key: String = "", costs: Array = []) -> Control:
	var b := _button(text, callback)
	b.name = "Dock_" + text.validate_node_name().replace(" ", "")
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override("font_size", Style.text_size(Style.SMALL))
	if key != "":
		b.icon = Widgets.icon(key)
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", 46)
	b.add_theme_constant_override("h_separation", 6)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.custom_minimum_size = Vector2(0, 124 if count > 1 or key != "" else 96)
	if primary:
		if danger:
			b.add_theme_stylebox_override("normal", Style.box(Style.ENEMY, Color(0, 0, 0, 0), 0))
			b.add_theme_stylebox_override("hover", Style.box(Style.ENEMY.lightened(0.08), Color(0, 0, 0, 0), 0))
			b.add_theme_stylebox_override("pressed", Style.box(Style.ENEMY.darkened(0.24), Style.TEXT, 3))
			for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
				b.add_theme_color_override(c, Color("fff2ec"))
		else:
			Style.make_primary(b)
			for c in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
				b.add_theme_color_override(c, Style.BRASS_INK)
	if not costs.is_empty():
		return Widgets.priced(b, costs)
	return b


## A gain under a dock button: a green number with its icon.
func _gain(key: String, amount: int) -> Array:
	return [key, "+%s" % Widgets.thousands(amount), Style.MORALE_HIGH]


## A loss under a dock button: a red number with its icon.
func _loss(key: String, amount: int) -> Array:
	return [key, "−%s" % Widgets.thousands(amount), Style.ENEMY_LIGHT]


## A round ✕ for the corner of a sheet.
func _close_x() -> Button:
	var x := Button.new()
	x.icon = Widgets.icon("cancel")
	x.expand_icon = true
	x.add_theme_constant_override("icon_max_width", 26)
	x.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	x.custom_minimum_size = Vector2(Style.TOUCH, Style.TOUCH)
	x.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	x.tooltip_text = "Close"
	x.add_theme_stylebox_override("normal", Style.box(Style.RAISED, Style.RULE, 2, 40))
	x.add_theme_stylebox_override("hover", Style.box(Style.RAISED.lightened(0.06), Style.MUTED, 2, 40))
	x.add_theme_stylebox_override("pressed", Style.box(Style.RAISED.darkened(0.16), Style.BRASS, 3, 40))
	x.pressed.connect(func():
		if _sheet_close_cb.is_valid():
			_sheet_close_cb.call())
	return x


## The tile's icon for a kind of sheet.
func _sheet_icon(kind: String) -> String:
	match kind:
		"here", "preview":
			var id: String = _selected if _selected != "" else (world.here() if world != null else "")
			if id != "" and Data.SETTLEMENTS.has(id):
				match String(Data.settlement(id)["type"]):
					Data.CASTLE:
						return "walls"
					Data.TOWN:
						return "gate"
				return "home"
			return "mappin"
		"encounter":
			return "skull" if _sheet_is_danger(kind) else "talk"
		"band", "warning":
			return "skull"
		"siege":
			return "storm"
		"lord", "ransom", "crown":
			return "crown"
		"wars":
			return "battle"
		"journal":
			return "journal"
		"chronicle":
			return "book"
		"commitment", "recommendation":
			return "objective"
		"notice":
			return "resume"
	return ""


## Whether the sheet means a fight: bandits, a warning, or meeting someone hostile.
func _sheet_is_danger(kind: String) -> bool:
	if kind in ["band", "warning", "siege"]:
		return true
	if kind == "encounter" and world != null and world.encounter != -1:
		var p = world.party(world.encounter)
		return p != null and not (p.kind == WorldSim.LORD and world.relation_to_player(p.faction) == "friendly")
	return false


## Put a lord's face and banner above the sheet just shown.
func _show_lord_header(lord: Dictionary) -> void:
	if lord.is_empty():
		return
	sheet_portrait.texture = CaptainArt.texture(LordVoice.portrait_record(lord))
	sheet_portrait.visible = sheet_portrait.texture != null
	var realm := String(lord.get("realm", ""))
	_banner_realm = realm if Heraldry.REALM_SIZES.has(realm) else Heraldry.realm_of_culture(String(lord.get("culture", "")))
	sheet_banner.queue_redraw()
	sheet_lord_row.visible = true
	sheet_tile.visible = false


func _close_sheet() -> void:
	_sheet = ""
	if bottom_bar != null:
		bottom_bar.visible = true
	if sheet_panel.visible and not Style.closing(sheet_panel):
		Style.ease_out(sheet_panel, func(): sheet_panel.visible = false)


## Whether a sheet is up: shown and not on its way out.
func _sheet_open() -> bool:
	return sheet_panel != null and sheet_panel.visible and not Style.closing(sheet_panel)


## Closes a sheet opened from another (the war news, the chronicle). While an encounter
## is still waiting, as when a lord on the road told you of the war, it goes back to that
## encounter: closing it outright would leave the map paused with nothing to answer.
func _close_or_back() -> void:
	if _talk != null and is_instance_valid(_talk):
		_close_sheet()
		_sheet = "talk"
		bottom_bar.visible = false
		_talk.resume()
		return
	if world != null and world.encounter != -1 and world.party(world.encounter) != null:
		_open_encounter()
	else:
		_close_sheet()


func _open_preview(id: String) -> void:
	var hours: float = world.hours_to(id)
	var sea := false
	var route: Array = world.path(world.player().next if world.player().moving() else world.player().node, id)
	var a: String = world.player().node
	for b in route:
		if world.is_sea(a, b):
			sea = true
		a = b
	# Kept short on the map: what it is, how far, and only danger worth knowing. The full
	# picture is inside the settlement.
	var danger: String = world.settlement_danger(id)
	_show_sheet("preview", String(Data.settlement(id)["name"]), "",
		[["Ride there", _on_travel.bind(id), true, "ride"], ["Close", _close_sheet]])
	if Style.illustrations_on():
		var scene := SettlementVista.make(id, world, 200.0)
		scene.name = "PreviewScene"
		sheet_extra.add_child(scene)
	var owner := String(world.owner_of(id))
	var rel := String(world.relation_to_player(owner))
	var ride := Widgets.stat("clock", Style.time_short(hours))
	ride.name = "RideTime"
	var chips := [ride]
	if sea:
		var by_sea := Widgets.chip("", Style.TEXT, "", "sail")
		by_sea.name = "BySea"
		chips.append(by_sea)
	if rel == "hostile":
		chips.append(Widgets.chip("At war", Style.MORALE_LOW, "", "fight"))
	if danger != "":
		chips.append(_danger_chip(danger))
	else:
		chips.append(Widgets.chip("Quiet roads", Style.MORALE_HIGH))
	_sheet_header(null, owner, String(Data.settlement(id)["name"]), world.brief(id), chips)


## A settlement's danger ("under siege by …; …") as one chip: its icon and the first words.
func _danger_chip(danger: String) -> PanelContainer:
	var lower := danger.to_lower()
	var key := "fight"
	if lower.contains("siege") or lower.contains("besieg"):
		key = "storm"
	elif lower.contains("raid") or lower.contains("burn"):
		key = "fire"
	elif lower.contains("army") or lower.contains("marshal"):
		key = "advance"
	var c := Widgets.chip(danger.split(";")[0].split(":")[0].capitalize(), Style.MORALE_LOW, "", key)
	c.name = "DangerNote"
	return c


func _open_here() -> void:
	var id: String = world.here()
	if id == "":
		_close_sheet()
		return
	_selected = id
	var buttons := [["Enter", _on_enter, true, "inside"], ["Wait", _on_wait, false, "revert"], ["Warband", _on_warband, false, "company"], ["Close", _close_sheet]]
	var wedding_here := GameState.wedding_can_begin() and String(GameState.wedding()["place"]) == id
	if wedding_here:
		buttons[0][2] = false
		buttons.push_front(["Wedding", _on_begin_wedding, true, "rings"])
	if GameState.siege_check(id)["ok"]:
		buttons.push_front(["Storm", _open_siege.bind(id), true, "storm"])
		buttons[1][2] = false
	elif GameState.raid_check(id)["ok"]:
		buttons.push_front(["Raid the village", _open_raid.bind(id), true, "fire"])
		buttons[1][2] = false
	if GameState.crown_check()["ok"]:
		buttons.insert(buttons.size() - 1, ["Raise crown", _open_raise_crown, false, "crown"])
	# The title names the place and the bar says you're at it: the sheet says only what's
	# here, as chips.
	var body := ""
	if wedding_here:
		var who := String(world.social.get_candidate_person(String(GameState.wedding()["candidate_id"])).get("name", ""))
		body = "Your wedding is ready. %s is waiting for you; there's no hurry while you're in town." % who
	_show_sheet("here", String(Data.settlement(id)["name"]), body, buttons, world.brief(id))
	var chips := []
	var danger: String = world.settlement_danger(id)
	if danger != "":
		chips.append(_danger_chip(danger))
	var offers: Array = world.offers_at(id)
	var hire := Widgets.stat("men", "%d for hire" % offers.size() if not offers.is_empty() else "None for hire", Style.TEXT if not offers.is_empty() else Style.MUTED)
	hire.name = "ForHire"
	chips.append(hire)
	if world.player_in_town():
		chips.append(Widgets.chip("Reinforce and train", Style.MORALE_HIGH, "", "plus"))
	sheet_extra.add_child(Widgets.chip_row(chips))
	sheet_extra.visible = true


func _open_band(b) -> void:
	var men: int = world.men_of(b.army)
	var near := _near_place(world.party_pos(b))
	var what := "Raiding %s" % Data.settlement(b.raid_village)["name"] if b.raiding and Data.SETTLEMENTS.has(b.raid_village) else "Near %s" % near
	# The sub line says whose outlaws; the chips say how many and how quick.
	_show_sheet("band", b.name, "", [["Ride at them", _on_ride_at.bind(b), true, "fight"], ["Close", _close_sheet]])
	var kind := "wako" if String(b.name).contains("Wako") else Data.culture_of(b.faction)
	var pic := _sprite_picture("outlaws/" + kind if MapArt.has("outlaws/" + kind) else "bandits", Color("4a4038"), Data.culture_of(b.faction))
	_sheet_header(pic, "bandits", b.name, "Outlaws of %s" % _realm_short(b.faction),
		[_men_chip(men), _pace_chip(b), Widgets.chip(what, Style.MORALE_LOW, "", "fire") if b.raiding else Widgets.chip(what, Style.MORALE_MID, "", "mappin")])


## Ride for where a band is heading, to meet it on the road.
func _on_ride_at(b) -> void:
	var to: String = b.node
	if b.moving() and b.next != "" and b.along > world.road_length(b.node, b.next) * 0.5:
		to = b.next
	if world.travel(to) or world.here() == to:
		_close_sheet()


## The settlement nearest a point on the map, by name.
func _near_place(at: Vector2) -> String:
	var best := ""
	var dist := INF
	for id in Data.SETTLEMENTS:
		var d := at.distance_to(Data.pos(id))
		if d < dist:
			dist = d
			best = String(Data.settlement(id)["name"])
	return best


## How a party's men compare with yours, as a chip: their men by the men icon, with the
## kit's marks for what it means to you (▲ weaker than you, ◆ even, ▼ stronger). The same
## marks as the plates over parties on the map (`_odds_mark`).
func _men_chip(men: int, about: bool = false) -> PanelContainer:
	var mark := _odds_mark(men)
	var c := Widgets.chip(("~%d" % (int(round(men / 10.0)) * 10)) if about else str(men), mark[1], mark[0], "men")
	c.name = "MenChip"
	c.tooltip_text = String(mark[2])
	return c


## Who's quicker on the road, as a chip: the speed icon, theirs to yours, ▼ when they're
## faster (they can catch you), ▲ when you are.
func _pace_chip(p) -> PanelContainer:
	var theirs: float = world.party_speed(p)
	var mine: float = world.player_speed()
	var tone := Style.MORALE_MID
	var shape := "◆"
	if theirs > mine * 1.02:
		tone = Style.MORALE_LOW
		shape = "▼"
	elif theirs < mine * 0.98:
		tone = Style.MORALE_HIGH
		shape = "▲"
	var c := Widgets.chip("%d · you %d" % [roundi(theirs), roundi(mine)], tone, shape, "speed")
	c.name = "PaceChip"
	return c


## A map sprite on a patch of its own ground, scaled up crisp, for a sheet's picture.
func _sprite_picture(sprite: String, color: Color, culture: String) -> Control:
	var panel := PanelContainer.new()
	var ground := {"kharzani": Color("b89a62"), "ryumon": Color("5f8a62")}.get(culture, Color("5d7a40")) as Color
	panel.add_theme_stylebox_override("panel", Style.box(ground, Style.RULE, 2, 14))
	panel.custom_minimum_size = Vector2(150, 96)
	var pic := TextureRect.new()
	pic.texture = MapArt.texture(sprite, 0, color)
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(140, 88)
	panel.add_child(pic)
	return panel


## The top of a sheet: a picture, the realm's banner, the name and a line about it, then a
## row of chips. Replaces the plain title.
func _sheet_header(pic: Control, realm: String, title: String, sub: String, chips: Array) -> void:
	sheet_head.visible = false
	sheet_lord_row.visible = false
	sheet_extra.visible = true
	var row := HBoxContainer.new()
	row.name = "SheetHeader"
	row.add_theme_constant_override("separation", 14)
	if pic != null:
		pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(pic)
	if realm != "":
		var flag := Widgets.banner(realm, Vector2(44, 60))
		flag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(flag)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	words.add_theme_constant_override("separation", 2)
	var name_label := Style.label(title, Style.LARGE, Style.TEXT)
	name_label.name = "SheetName"
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(name_label)
	var sub_label := Style.label(sub, Style.SMALL, Style.MUTED)
	sub_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(sub_label)
	row.add_child(words)
	if _sheet_close_cb.is_valid():
		row.add_child(_close_x())
	sheet_extra.add_child(row)
	if not chips.is_empty():
		sheet_extra.add_child(Widgets.chip_row(chips))


## A lord on the road: who he is, how strong, and what he's about.
func _open_lord(lp) -> void:
	var army: Dictionary = world.MarshalArmies.for_party(world, lp.id)
	var rel: String = world.relation_to_player(lp.faction)
	var buttons := []
	if not army.is_empty():
		_open_marshal_army(lp, army, rel)
		return
	var l: Dictionary = world.lord_of(lp)
	var men := 0
	for sq in lp.army:
		men += int(sq["men"])
	var bearing := String(l.get("bearing", ""))
	if rel == "friendly" and GameState.has_contract() and GameState.contract_realm() == lp.faction:
		if world.following_party == lp.id:
			buttons.append(["Stop following", _on_stop_following, false, "back"])
		else:
			buttons.append(["Ride with us", _on_follow_lord.bind(lp.id), false, "ride"])
	elif rel == "neutral":
		buttons.append(["Attack", _on_attack_lord.bind(lp), true, "fight"])
	var near: bool = world.party_pos(lp).distance_to(world.party_pos(world.player())) <= WorldSim.ENCOUNTER_RADIUS * TALK_REACH
	if rel in ["friendly", "neutral"] and world.encounter == -1 and near:
		# A friendly lord rides past without stopping when there's nothing new; tap them
		# while they're near to talk anyway. So can you a lord of a realm at peace with you.
		buttons.push_front(["Talk", _on_talk_to_lord.bind(lp.id), true, "talk"])
	buttons.append(["Close", _close_sheet])
	# The banner says the realm and the sub line the rank: the body is only the bearing.
	var body := "%s: %s." % [bearing, Lords.BEARING_TEXT.get(bearing, "")] if bearing != "" else ""
	_show_sheet("lord", lp.name, body, buttons)
	var face := TextureRect.new()
	face.texture = CaptainArt.texture(LordVoice.portrait_record(l))
	face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.custom_minimum_size = Vector2(72, 92)
	var realm_id := String(l.get("realm", lp.faction))
	var rel_chip := Widgets.chip({"hostile": "At war", "friendly": "Friendly", "allied": "Your ally", "employer": "Your employer"}.get(rel, "Neutral"),
		Style.MORALE_LOW if rel == "hostile" else (Style.MORALE_HIGH if rel in ["friendly", "allied", "employer"] else Style.MORALE_MID))
	var rank := "Ruler" if l.get("ruler", false) else "Lord"
	var fief := String(l.get("fief", ""))
	if fief != "" and not l.get("ruler", false) and Data.SETTLEMENTS.has(fief):
		rank += " of %s" % Data.settlement(fief)["name"]
	_sheet_header(face, realm_id if Heraldry.REALM_SIZES.has(realm_id) else _party_realm(lp), lp.name, rank,
		[_men_chip(men, not GameState.has_specialization(Captains.SCOUT)), _pace_chip(lp), Widgets.chip(_lord_doing(l, lp), Style.MORALE_MID, "", "mappin"), rel_chip, _regard_chip(l)])


## A marshal's host: the realm's banner and what the army is doing, its strength, where it's
## bound and how quick, then the lords who ride in it, each with their face.
func _open_marshal_army(lp, army: Dictionary, rel: String) -> void:
	var buttons := []
	if rel == "friendly" and (army["realm"] == Data.CROWN or GameState.has_contract() and GameState.contract_realm() == army["realm"]):
		if world.following_party == lp.id or world.following_party == int(army["leader"]):
			buttons.append(["Stop following", _on_stop_following, false, "back"])
		else:
			buttons.append(["Ride with army", _on_follow_lord.bind(int(army["leader"])), false, "ride"])
	elif rel == "neutral":
		buttons.append(["Attack", _on_attack_lord.bind(lp), true, "fight"])
	buttons.append(["Close", _close_sheet])
	_show_sheet("lord", "Marshal's army", "", buttons)
	var members: Array = world.MarshalArmies.members(world, army)
	var total := 0
	for member in members:
		total += world.men_of(member.army)
	var state := String(army["state"])
	var badge := Control.new()
	badge.name = "ArmyState"
	badge.custom_minimum_size = Vector2(72, 72)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.draw.connect(func(): _paint_army_badge(badge, Vector2(36, 36), state, 4.6))
	var realm := String(army["realm"])
	var dest := String(army.get("destination", ""))
	var chips := [_men_chip(total), _pace_chip(lp)]
	if Data.SETTLEMENTS.has(dest):
		chips.append(Widgets.chip(String(Data.settlement(dest)["name"]), Style.TEXT, "", "mappin"))
	_sheet_header(badge, realm if Heraldry.REALM_SIZES.has(realm) else _party_realm(lp),
		"Marshal %s" % short_lord_name(lp.name), state.capitalize(), chips)
	var list := VBoxContainer.new()
	list.name = "ArmyMembers"
	list.add_theme_constant_override("separation", 8)
	sheet_extra.add_child(list)
	for member in members:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var face := TextureRect.new()
		face.texture = CaptainArt.texture(LordVoice.portrait_record(world.lord_of(member)))
		face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.custom_minimum_size = Vector2(44, 56)
		row.add_child(face)
		var who := Style.label(String(member.name), Style.SMALL, Style.TEXT)
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		who.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		who.custom_minimum_size = Vector2(10, 0)
		row.add_child(who)
		row.add_child(Widgets.icon_value("men", str(world.men_of(member.army))))
		list.add_child(row)


## What a lord thinks of you, as a chip: the bond icon and "+12".
func _regard_chip(l: Dictionary) -> PanelContainer:
	var v := LordTalk.regard(GameState, l)
	var tone := Style.MORALE_HIGH if v >= 10 else (Style.MORALE_MID if v >= -14 else Style.MORALE_LOW)
	var c := Widgets.chip("%s%d" % ["+" if v > 0 else ("−" if v < 0 else ""), absi(v)], tone,
		"▲" if tone == Style.MORALE_HIGH else ("◆" if tone == Style.MORALE_MID else "▼"), "bond")
	c.tooltip_text = "Regard"
	c.name = "RegardChip"
	return c


func _on_talk_to_lord(party_id: int) -> void:
	var p = world.party(party_id)
	if p == null:
		return
	world.encounter = party_id
	_open_talk(int(p.lord), "road")


## A friendly lord riding past without stopping, in a line for the top of the map.
func _pass_line(p) -> String:
	var lines := ["%s rides past and raises a hand.", "%s's company passes by with a nod.", "%s rides by; no news on the road."]
	return lines[absi(int(p.id)) % lines.size()] % p.name


## A short line under the top bar that fades on its own, for something worth seeing that
## doesn't need an answer.
func _toast(text: String) -> void:
	if _toast_panel == null:
		_toast_panel = PanelContainer.new()
		_toast_panel.name = "Toast"
		_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var box := Style.box(Color(Style.NIGHT, 0.92), Style.RULE, 2, 22)
		box.content_margin_left = 22
		box.content_margin_right = 22
		box.content_margin_top = 12
		box.content_margin_bottom = 12
		_toast_panel.add_theme_stylebox_override("panel", box)
		_toast_label = Style.label("", Style.SMALL, Style.TEXT)
		_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_toast_panel.add_child(_toast_label)
		_hud.add_child(_toast_panel)
	_toast_label.text = text
	var width: float = minf(get_viewport_rect().size.x - 48.0, 640.0)
	# The words get their width before the panel measures them, or they'd wrap after every
	# word and stand the panel up the whole screen.
	_toast_label.custom_minimum_size = Vector2(width - 44.0, 0)
	# A panel grows to fit but never shrinks on its own, and the wrapped words only know
	# their height a frame later: fit it now and again then.
	_toast_panel.reset_size()
	_toast_panel.reset_size.call_deferred()
	var under: float = pinned_chip.get_global_rect().end.y if pinned_chip != null and pinned_chip.visible else top_panel.get_global_rect().end.y
	_toast_panel.position = Vector2((get_viewport_rect().size.x - width) * 0.5, under + 14.0)
	_toast_panel.visible = true
	_toast_panel.modulate.a = 1.0
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(3.0)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 0.0, 0.6)
	_toast_tween.tween_callback(func(): _toast_panel.visible = false)


func _on_attack_lord(lp) -> void:
	_close_sheet()
	GameState.attack_neutral_lord(lp.lord, lp.id)
	_open_encounter()


func _on_follow_lord(party_id: int) -> void:
	world.following_party = party_id
	_close_sheet()
	var p = world.party(party_id)
	_open_notice("You are now riding with %s." % (p.name if p != null else "the army"), "Riding with an army")


func _on_stop_following() -> void:
	world.following_party = -1
	_close_sheet()


## The hostile lord riding after you, if any.
func _chaser():
	for l in world.lords:
		if String(l.get("job", "")) == "chase" and String(l.get("state", "")) == "field":
			var lp = world.party(int(l["party"]))
			if lp != null:
				return lp
	return null


func _lord_doing(l: Dictionary, lp) -> String:
	var target := String(l.get("target", ""))
	var place := String(Data.settlement(target)["name"]) if Data.SETTLEMENTS.has(target) else ""
	match String(l.get("job", "")):
		"chase":
			return "Riding after your company"
		"raid":
			return "Burning %s" % place if String(l.get("raiding", "")) != "" else "Riding to raid %s" % place
		"defend":
			return "Riding to defend %s" % place
		"hunt":
			return "Hunting bandits near %s" % place
		"home":
			return "Resting at %s, raising men" % place if not lp.moving() else "Riding home to %s" % place
		"muster":
			return "Waiting at the muster in %s" % place if not lp.moving() else "Riding to your muster at %s" % place
		"escort":
			return "Riding with you under your banners"
		"gather":
			var feast: Dictionary = world.gathering_by_id(int(l.get("gather_id", 0)))
			if feast.is_empty():
				return "Resting at court in %s" % place if not lp.moving() else "Riding to court at %s" % place
			return ("At %s at %s" if not lp.moving() else "Riding to %s at %s") % [world.gathering_name(feast), place]
		_:
			return "Riding to %s" % place if lp.moving() and place != "" else "Keeping watch over their lands"


## Talk to a lord face to face: on the road ("road"), when they've blocked yours
## ("hostile"), or at your camp as your captive ("captive"). The map holds still meanwhile.
func _open_talk(lord_id: int, how: String = "road", why: String = "") -> void:
	if world.lord_by_id(lord_id).is_empty():
		return
	if _talk != null and is_instance_valid(_talk):
		_talk.queue_free()
	_close_sheet()
	_sheet = "talk"
	bottom_bar.visible = false
	_talk = LordConversation.open(_hud, GameState, lord_id, how, why)
	_talk.closed.connect(_on_talk_closed)
	_talk.wants_news.connect(func():
		_talk.visible = false
		_open_wars())
	_talk.wants_fight.connect(func():
		_talk = null
		_sheet = ""
		_on_fight())
	_talk.wants_follow.connect(func(pid: int):
		world.following_party = pid)


func _on_talk_closed() -> void:
	_talk = null
	_sheet = ""
	bottom_bar.visible = true
	GameState.save_game()
	var b = world.party(world.encounter) if world.encounter != -1 else null
	# A lord who blocked your road is still there when you stop talking.
	if b != null and b.kind == WorldSim.LORD and world.relation_to_player(b.faction) != "friendly":
		_open_encounter()
		return
	world.encounter = -1
	_refresh_hud()


func _on_part_ways_friendly() -> void:
	world.encounter = -1
	_close_sheet()


func _open_ransom_sheet(lord_id: int) -> void:
	if world == null:
		return
	var l: Dictionary = world.lord_by_id(lord_id)
	if l.is_empty():
		return
	var realm_name: String = Data.FACTIONS.get(l.get("realm", ""), {}).get("name", l.get("realm", ""))
	var ransom: int = int(l.get("ransom_amount", 200))
	var title := "Ransom for %s" % l.get("name", "a captive lord")
	var text := "An envoy of %s rides under a banner of truce for %s's return." % [realm_name, l.get("name", "the lord")]
	var buttons := []
	buttons.append(["Ransom", _on_accept_ransom.bind(lord_id), true, "silver", [_gain("silver", ransom)]])
	if GameState.has_contract() and world.at_war(GameState.contract_realm(), String(l.get("realm", ""))):
		var bonus: int = int(GameState.contract.get("bonus_per_lord", 100))
		buttons.append(["To employer", _on_deliver_lord_to_employer.bind(lord_id), false, "crown", [_gain("silver", bonus), _gain("bond", 10)]])
	buttons.append(["Release", _on_release_lord_honor.bind(lord_id), false, "heart", [_gain("bond", 25), _gain("renown", 10)]])
	buttons.append(["Talk", _open_talk.bind(lord_id, "captive"), false, "talk"])
	buttons.append(["Keep in chains", _close_sheet, false, "lock"])
	_show_sheet("ransom", title, text, buttons)
	_show_lord_header(l)


func _on_accept_ransom(lord_id: int) -> void:
	GameState.accept_lord_ransom(lord_id)
	Sound.play("coins")
	_close_sheet()
	_refresh_hud()


func _on_deliver_lord_to_employer(lord_id: int) -> void:
	GameState.deliver_lord_to_employer(lord_id)
	Sound.play("coins")
	_close_sheet()
	_refresh_hud()


func _on_release_lord_honor(lord_id: int) -> void:
	GameState.release_lord_for_honor(lord_id)
	Sound.play("page")
	_close_sheet()
	_refresh_hud()


func _open_encounter() -> void:
	var b = world.party(world.encounter)
	if b == null:
		return
	if b.kind == WorldSim.LORD and world.relation_to_player(b.faction) == "friendly":
		_open_talk(int(b.lord), "road", _stop_reason)
		_stop_reason = ""
		return
	var men := 0
	for sq in b.army:
		men += int(sq["men"])
	var fighters := []
	for s in GameState.army:
		if int(s["men"]) > 0:
			fighters.append(s)
	var plan: Dictionary = GameState.encounter_plan(b)
	var objective: String = plan["objective"]
	var site: Dictionary = plan["site"]
	var is_ambush := objective == "ambush"
	var can_withdraw := bool(plan.get("can_withdraw", true))
	var has_grudge := bool(plan.get("has_grudge", false))
	var grudge_text := String(plan.get("grudge_text", ""))
	var title := "%s block the road" % b.name
	if b.kind == WorldSim.LORD:
		title = ("%s seeks vengeance!" % b.name) if has_grudge else ("%s blocks the road!" % b.name)
	else:
		match objective:
			"village":
				title = "%s are raiding %s!" % [b.name, Data.settlement(b.raid_village)["name"]]
			"chief":
				title = "%s confronts you" % b.name
			"ambush":
				title = "AMBUSH! %s attack from the woods" % b.name
	var odds: Dictionary = AutoResolve.odds(fighters, b.army, site, objective)
	var lost: int = odds["lost"]
	# Send in: the men you'd lose sit under the button, not in a sentence.
	var buttons := [["Fight", _on_fight, true, "fight"], ["Send in", _on_send_in, false, "advance", [_loss("skull", lost)]]]
	if b.kind == WorldSim.LORD and int(b.lord) >= 0:
		buttons.append(["Talk", _open_talk.bind(int(b.lord), "hostile"), false, "talk"])
	if not is_ambush and can_withdraw:
		buttons.append(["Withdraw", _on_withdraw, false, "retreat"])
	# The lord's own voice is the only prose; a grudge is part of what they say.
	var encounter_body := grudge_text
	var foe_lord: Dictionary = world.lord_of(b) if b.kind == WorldSim.LORD else {}
	if not foe_lord.is_empty():
		var met := int(foe_lord.get("met_player", 0))
		encounter_body = LordVoice.line("again" if met > 0 else "face", foe_lord) + ("\n\n" + grudge_text if grudge_text != "" else "")
	_show_sheet("encounter", title, encounter_body, buttons)
	_show_odds(b, fighters, odds, men, is_ambush or not can_withdraw)
	# The ground and the way out, as chips.
	var chips := []
	if site.get("river", "") != "":
		chips.append(Widgets.chip("Ford · %s" % site["river"], Style.MORALE_MID, "◆"))
	elif not bool(site.get("fair", true)):
		chips.append(Widgets.chip("Their ground: %s" % ("ridge" if site["type"] == "hills" else "wood's edge"), Style.MORALE_LOW, "▼"))
	if is_ambush:
		chips.append(Widgets.chip("Ambush · no way out", Style.MORALE_LOW, "", "retreat"))
	elif not can_withdraw:
		chips.append(Widgets.chip("Can't withdraw", Style.MORALE_LOW, "", "retreat"))
	elif world.party_speed(b) > world.player_speed():
		chips.append(Widgets.chip("Withdrawing may fail", Style.MORALE_MID, "", "retreat"))
	if not chips.is_empty():
		var row := Widgets.chip_row(chips)
		row.name = "EncounterChips"
		sheet_extra.add_child(row)
	_show_lord_header(foe_lord)
	Sound.play("alarm")


## The music of the realm you're riding through; at sea, whatever was playing.
func _update_music() -> void:
	var realm: String = terrain.realm_at(world.party_pos(world.player()))
	if realm != "":
		Sound.play_music(Data.culture_of(realm))


## Siege drums when the player or camera is near an active siege
func _check_siege_proximity_sound() -> void:
	if world == null:
		return
	var player_pos: Vector2 = world.party_pos(world.player())
	for id in Data.SETTLEMENTS:
		if world.is_sieged(id):
			var s_pos: Vector2 = Data.pos(id)
			if s_pos.distance_to(player_pos) < 180.0 or s_pos.distance_to(cam_center) < 180.0:
				Sound.play_siege_drums()
				break


## What your scouts make of a fight, from auto-resolve's reckoning.
## How a fight looks at a glance: how dangerous, both sides' strength as bars, what they
## bring, and who is quicker on the road.
func _show_odds(b, fighters: Array, odds: Dictionary, their_men: int, trapped: bool) -> void:
	var r: float = odds["ratio"]
	var danger := ["Easy", Style.MORALE_HIGH, "▲"]
	if odds["player_wins"]:
		if r >= 0.85:
			danger = ["Even", Style.MORALE_MID, "◆"]
		elif r >= 0.5:
			danger = ["Favourable", Style.MORALE_HIGH, "▲"]
	else:
		danger = ["Hard", Style.MORALE_LOW, "▼"] if r >= 0.5 else ["Deadly", Style.ENEMY, "✖"]
		if r >= 0.85:
			danger = ["Even", Style.MORALE_MID, "◆"]
	var head := HBoxContainer.new()
	head.name = "OddsHead"
	head.add_theme_constant_override("separation", 12)
	sheet_extra.add_child(head)
	var chip := PanelContainer.new()
	chip.name = "DangerChip"
	var sb := Style.box(Color(danger[1]).darkened(0.55), danger[1], 2, 30)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	chip.add_theme_stylebox_override("panel", sb)
	chip.add_child(Style.label("%s %s" % [danger[2], danger[0]], Style.BODY, Color(danger[1]).lightened(0.35)))
	head.add_child(chip)
	# Their troops wrap onto a second line rather than run off the sheet.
	var mix := HFlowContainer.new()
	mix.name = "EnemyMix"
	mix.add_theme_constant_override("h_separation", 6)
	mix.add_theme_constant_override("v_separation", 4)
	mix.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mix.alignment = FlowContainer.ALIGNMENT_END
	head.add_child(mix)
	var by_type := {}
	for sq in b.army:
		by_type[String(sq["type"])] = int(by_type.get(String(sq["type"]), 0)) + 1
	var cult := Data.culture_of(b.faction)
	for t in Troops.ORDER:
		if not by_type.has(t):
			continue
		var icon := TextureRect.new()
		icon.texture = Art.icon(t, 1, cult)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(40, 40)
		var pair := HBoxContainer.new()
		pair.add_theme_constant_override("separation", 4)
		pair.add_child(icon)
		pair.add_child(Style.label("×%d" % by_type[t], Style.SMALL, Style.TEXT))
		mix.add_child(pair)
	var mine := 0
	for s in fighters:
		mine += int(s.get("men", 0))
	var top: float = maxf(float(odds["player"]), float(odds["enemy"]))
	sheet_extra.add_child(_odds_bar(_party_realm(world.player()), mine, float(odds["player"]) / maxf(1.0, top), Style.PLAYER, "OddsYou"))
	sheet_extra.add_child(_odds_bar(_party_realm(b) if b.kind != WorldSim.BAND else "bandits", their_men, float(odds["enemy"]) / maxf(1.0, top), Style.ENEMY, "OddsThem"))
	var pace := Widgets.chip_row([_pace_chip(b)])
	pace.name = "OddsPace"
	sheet_extra.add_child(pace)
	sheet_extra.visible = true


## One side's strength: its banner, a bar against the stronger side, and its men.
func _odds_bar(realm: String, men: int, share: float, tone: Color, bar_name: String = "") -> Control:
	var row := HBoxContainer.new()
	if bar_name != "":
		row.name = bar_name
	row.add_theme_constant_override("separation", 10)
	var flag := Widgets.banner(realm, Vector2(34, 46))
	flag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(flag)
	var track := Panel.new()
	track.custom_minimum_size = Vector2(0, 22)
	track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	track.add_theme_stylebox_override("panel", Style.box(Style.NIGHT, Style.RULE, 1, 8))
	row.add_child(track)
	var fill := Panel.new()
	fill.add_theme_stylebox_override("panel", Style.box(tone, Color(0, 0, 0, 0), 0, 8))
	fill.anchor_bottom = 1.0
	fill.anchor_right = clampf(share, 0.04, 1.0)
	track.add_child(fill)
	if not Style.motion_reduced():
		fill.anchor_right = 0.04
		fill.create_tween().tween_property(fill, "anchor_right", clampf(share, 0.04, 1.0), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var count := Widgets.icon_value("men", str(men))
	count.custom_minimum_size = Vector2(100, 0)
	count.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(count)
	return row


func _open_desertion_warning() -> void:
	_show_sheet("warning", "Warning: men are leaving", GameState.desertion_warning +
		"\n\nTime is paused. Restore supplies and wages before another day passes.",
		[["Understood", _acknowledge_desertion, true, "resume"]])
	GameState.save_game()
	Sound.play("alarm")


func _acknowledge_desertion() -> void:
	# Remove only the warning's lines; preserve any unrelated battle or travel notice.
	for line in GameState.desertion_warning.split("\n"):
		GameState.map_notice = GameState.map_notice.replace(line, "")
	GameState.map_notice = GameState.map_notice.strip_edges()
	GameState.desertion_warning = ""
	GameState.save_game()
	_on_notice_done()


static func _short_amount(value: int) -> String:
	if value >= 1000000:
		return "%.1fm" % (value / 1000000.0)
	if value >= 10000:
		return "%.1fk" % (value / 1000.0)
	return str(value)


func _open_resource(key: String) -> void:
	if _sheet in ["encounter", "notice", "warning"]:
		return
	var tiles := []
	var tip := ""
	var short := false
	match key:
		"silver":
			var wages: int = GameState.daily_wages()
			short = GameState.silver < wages
			tiles = [Widgets.tile("silver", Widgets.thousands(GameState.silver), "in the purse", Style.ENEMY_LIGHT if short else Style.TEXT),
				Widgets.tile("men", "−%s" % Widgets.thousands(wages), "wages a day"),
				Widgets.tile("clock", str(GameState.silver / maxi(1, wages)), "days of wages")]
			tip = "Win battles for bounties and spoils." if not short else "You can't cover the next day's wages. Unpaid men may leave."
		"food":
			short = GameState.food < GameState.total_men()
			tiles = [Widgets.tile("food", Widgets.thousands(GameState.food), "rations", Style.ENEMY_LIGHT if short else Style.TEXT),
				Widgets.tile("men", "−%s" % Widgets.thousands(GameState.total_men()), "eaten a day"),
				Widgets.tile("clock", str(GameState.food_days()), "days of food")]
			tip = "Each man eats one ration a day. Villages sell rations cheapest." if not short else "Not enough rations for the next day. Hungry men may leave."
		"renown":
			tiles = [Widgets.tile("renown", Widgets.thousands(GameState.renown), "renown"),
				Widgets.tile("company", "%d / %d" % [GameState.army.size(), GameState.squad_cap()], "squads you can lead")]
			tip = "Winning battles builds your name, and a greater name leads more squads."
		"men":
			var wounded := 0
			for sq in GameState.army:
				wounded += int(sq.get("wounded", 0))
			tiles = [Widgets.tile("men", Widgets.thousands(GameState.total_men()), "fit to fight"),
				Widgets.tile("wounded", str(wounded), "wounded in the baggage", Style.ENEMY_LIGHT if wounded > 0 else Style.TEXT),
				Widgets.tile("company", "%d / %d" % [GameState.army.size(), GameState.squad_cap()], "squads"),
				Widgets.tile("speed", str(roundi(world.player_speed())), "pace on the road")]
			tip = "Every fight on the map weighs these men against theirs."
	_show_sheet("menu", key.capitalize(), tip, [["Close", _close_sheet]], "", key)
	var grid := Widgets.tile_grid(tiles, 2)
	grid.name = "ResourceTiles"
	sheet_extra.add_child(grid)
	sheet_extra.visible = true


## A message on a card. With no title, it's titled by where you are: a battle's own
## result says "After the battle" itself, so taxes collected at home never do. `items`
## are releases and oaths to show grouped (GameState.map_notice_items).
func _open_notice(text: String, title: String = "", items: Array = []) -> void:
	if title == "":
		title = _notice_place()
	if GameState.desertion_warning != "":
		for line in GameState.desertion_warning.split("\n"):
			text = text.replace(line, "")
		text = text.strip_edges()
		if text == "" and items.is_empty():
			_open_desertion_warning()
			return
	if GameState.total_men() == 0:
		_show_sheet("notice", "Your warband is gone", text + " Raise a new one to ride again.",
			[["New campaign", _on_new_campaign, true, "plus"]])
		return
	# Only releases and oaths to tell: name the sheet for them, not for a battle.
	if text == "" and not items.is_empty():
		title = "Your court" if items.any(func(i): return String(i.get("kind", "")) == "sworn") else "Your captives"
	_show_sheet("notice", title, text, [["Carry on", _on_notice_done, true, "resume"]])
	if not items.is_empty():
		sheet_extra.visible = true
		# The groups sit above any plain notes (the sheet's extra area comes before its body).
		for group in _notice_groups(items):
			sheet_extra.add_child(group)


## Releases and oaths, each kind as one block: a heading with its total, who, and what it
## earned, instead of a sentence per lord.
func _notice_groups(items: Array) -> Array:
	var blocks: Array = []
	var released := items.filter(func(i): return String(i.get("kind", "")) == "released")
	var sworn := items.filter(func(i): return String(i.get("kind", "")) == "sworn")
	if not released.is_empty():
		var v := _notice_block("NoticeReleased", "Released without ransom", "")
		(v.get_child(0) as HBoxContainer).add_child(Widgets.effect("renown", GameState.RELEASE_RENOWN * released.size()))
		# By realm: who went home to each, and how much that realm warmed to you.
		var realms: Array = []
		var by_realm := {}
		for i in released:
			var realm := String(i.get("realm", ""))
			if not by_realm.has(realm):
				by_realm[realm] = []
				realms.append(realm)
			by_realm[realm].append(String(i["name"]))
		for realm in realms:
			var names: Array = by_realm[realm]
			var realm_name := String(Data.FACTIONS.get(realm, {}).get("name", realm))
			var head := HBoxContainer.new()
			head.add_theme_constant_override("separation", 10)
			var rl := Style.label(realm_name, Style.SMALL, Style.MUTED)
			rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			rl.custom_minimum_size = Vector2(10, 0)
			head.add_child(rl)
			head.add_child(Widgets.effect("bond", GameState.RELEASE_REALM * names.size()))
			v.add_child(head)
			var who := Style.label(", ".join(PackedStringArray(names)), Style.SMALL, Style.TEXT)
			who.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			who.custom_minimum_size = Vector2(10, 0)
			v.add_child(who)
		var each := Widgets.chip_row([Widgets.effect("bond", GameState.RELEASE_REGARD, " each")])
		each.name = "RegardEach"
		v.add_child(each)
		blocks.append(v.get_parent())
	if not sworn.is_empty():
		var v := _notice_block("NoticeSworn", "Sworn to your crown", "")
		(v.get_child(0) as HBoxContainer).add_child(Widgets.icon_value("crown", str(sworn.size()), Style.BRASS))
		for i in sworn:
			var seat := String(i.get("seat", ""))
			var line := Style.label(String(i["name"]) + (" · holds %s" % seat if seat != "" else ""), Style.SMALL, Style.TEXT)
			line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			line.custom_minimum_size = Vector2(10, 0)
			v.add_child(line)
		blocks.append(v.get_parent())
	return blocks


## A small block in a notice: a brass heading with a note on the right; returns the column
## to fill (the block itself is its parent).
func _notice_block(block_name: String, heading: String, aside: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.name = block_name
	var sb := Style.box(Style.RAISED, Style.RULE, 2, 16)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 14
	sb.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	v.add_child(head)
	var h := Style.label(heading.to_upper(), Style.SMALL, Style.BRASS)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.custom_minimum_size = Vector2(10, 0)
	head.add_child(h)
	if aside != "":
		head.add_child(Style.label(aside, Style.SMALL, Style.BRASS))
	return v


func _notice_place() -> String:
	var here: String = world.here() if world != null else ""
	if here != "":
		return "At %s" % String(Data.settlement(here)["name"])
	return "On the road"


func _on_notice_done() -> void:
	_close_sheet()
	if world.here() != "":
		_open_here()


func _hours_text(hours: float) -> String:
	return Style.time_short(ceilf(hours))


# ---------------------------------------------------------------- actions

func _on_travel(id: String) -> void:
	if world.travel(id):
		_close_sheet()
		GameState.save_game()


func _on_wait() -> void:
	if world.wait(8.0):
		_close_sheet()


func _on_begin_wedding() -> void:
	GameState.save_game()
	Scenes.wedding_replay = ""
	Scenes.wedding_return = "res://scenes/world_map.tscn"
	Scenes.go("res://scenes/wedding.tscn")


func _on_enter() -> void:
	GameState.save_on_arrival(String(world.player().node))
	Scenes.settlement_arrival_pending = true
	Scenes.go("res://scenes/settlement.tscn")


func _on_menu() -> void:
	if _sheet in ["encounter", "notice", "warning"]:
		return
	_show_sheet("menu", "Campaign menu", "", [])
	sheet_head.visible = false
	sheet_extra.visible = true
	sheet_extra.add_child(_menu_header())
	sheet_extra.add_child(_last_save_card())
	sheet_extra.add_child(_menu_next_step())
	var grid := GridContainer.new()
	grid.name = "MenuCards"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	sheet_extra.add_child(grid)
	var men: int = GameState.total_men()
	var companies: int = GameState.army.size()
	grid.add_child(_menu_card("Warband", "company", "", _on_warband, 0, [["men", Widgets.thousands(men)], ["company", str(companies)]]))
	var open: int = GameState.commitments().size()
	grid.add_child(_menu_card("Journal", "journal", "" if open > 0 else "Nothing pending", _open_journal, 0, [["objective", str(open)]] if open > 0 else []))
	var unread: int = world.social.unread_letters_count() if world.social != null else 0
	grid.add_child(_menu_card(_people_label(), "mail", "New letters" if unread > 0 else "No new letters", _on_people, unread))
	grid.add_child(_menu_card("War & Politics", "battle", _war_status(), _open_wars))
	if GameState.is_crowned():
		grid.add_child(_menu_card("Your Crown", "crown", "", _open_crown, 0, [["keep", str(GameState.crown_holdings().size())]]))
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 14)
	sheet_extra.add_child(foot)
	for spec in [["Settings", "gear", _on_settings], ["Home", "home", _on_home]]:
		var f := _quiet_button(String(spec[0]), spec[2])
		f.add_theme_stylebox_override("normal", Style.box(Color(0, 0, 0, 0), Style.RULE, 2, 18))
		f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var inner := HBoxContainer.new()
		inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inner.alignment = BoxContainer.ALIGNMENT_CENTER
		inner.add_theme_constant_override("separation", 14)
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		f.add_child(inner)
		var pic := Widgets.icon_rect(String(spec[1]), 32.0)
		pic.modulate = Style.MUTED
		inner.add_child(pic)
		inner.add_child(Style.label(String(spec[0]), Style.BODY, Style.MUTED))
		f.custom_minimum_size.y = Style.TOUCH
		foot.add_child(f)


## "Campaign menu  Paused" with an ✕ to close.
func _menu_header() -> Control:
	var row := HBoxContainer.new()
	row.name = "MenuHeader"
	row.add_theme_constant_override("separation", 14)
	var t := Style.label("Campaign menu", 36, Style.TEXT)
	var face: Font = Style.display_font()
	if face != null:
		t.add_theme_font_override("font", face)
	row.add_child(t)
	var paused := Widgets.chip("Paused", Style.MUTED, "", "pause")
	paused.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(paused)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gap)
	var x := _icon_button("Close", "cancel", _close_sheet, Style.TOUCH)
	x.name = "CloseMenu"
	x.add_theme_stylebox_override("normal", Style.box(Style.RAISED, Style.RULE, 2, 36))
	row.add_child(x)
	return row


## A button whose words are kept (for tests and screen readers) but drawn by its children.
func _quiet_button(text: String, callback: Callable) -> Button:
	var b := _button(text, callback)
	b.clip_text = true
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color", "font_disabled_color"]:
		b.add_theme_color_override(c, Color(0, 0, 0, 0))
	return b


## A small square button: an icon over a word.
func _icon_button(text: String, icon: String, callback: Callable, side: float = 88.0, word: String = "") -> Button:
	var b := _quiet_button(text, callback)
	b.custom_minimum_size = Vector2(side, side)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var pic := Widgets.icon_rect(icon, 36.0 if word != "" else 30.0)
	pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(pic)
	if word != "":
		var l := Style.label(word, Style.SMALL, Style.MUTED)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(l)
	b.set_meta("art", v)
	return b


## When you last saved, with Save, Revert and All saves beside it; or what Ironman means.
func _last_save_card() -> Control:
	var card := PanelContainer.new()
	card.name = "LastSave"
	var sb := Style.box(Style.NIGHT, Style.RULE, 2, 22)
	sb.content_margin_left = 22
	sb.content_margin_right = 12
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 0)
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(words)
	if GameState.ironman:
		words.add_child(Style.label("Ironman", Style.BODY, Style.BRASS))
		var n := Style.label("The game saves as you go. There's no going back.", Style.SMALL, Style.MUTED)
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		words.add_child(n)
		return card
	var last := SaveSlots.latest()
	if last.is_empty():
		words.add_child(Style.label("No saves yet", Style.BODY, Style.TEXT))
		words.add_child(Style.label("Save a moment to come back to", Style.SMALL, Style.MUTED))
	else:
		var s: Dictionary = last["summary"]
		var when := HBoxContainer.new()
		when.name = "SavedWhen"
		when.add_theme_constant_override("separation", 12)
		when.add_child(Widgets.icon_value("day", str(int(s["day"])), Style.TEXT, Style.BODY))
		when.add_child(Widgets.icon_value("clock", "%02d:00" % (int(s["hour"]) % 24), Style.MUTED))
		words.add_child(when)
		var fought := GameState.battles - int(s["battles"])
		var since := "%d battle%s since" % [fought, "" if fought == 1 else "s"] if fought > 0 else SaveSlots.when(float(last["saved"]))
		words.add_child(Style.label("%s · %s" % [s["place_name"], since], Style.SMALL, Style.MORALE_MID if fought > 0 else Style.MUTED))
	for c in words.get_children():
		if c is Label:
			(c as Label).clip_text = true
			(c as Label).text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var save := _icon_button("Save game", "save", _on_save_game, 88.0, "Save")
	Style.make_primary(save)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		save.add_theme_color_override(c, Color(0, 0, 0, 0))
	var art: Control = save.get_meta("art")
	(art.get_child(0) as TextureRect).modulate = Style.BRASS_INK
	(art.get_child(1) as Label).add_theme_color_override("font_color", Style.BRASS_INK)
	row.add_child(save)
	var revert := _icon_button("Revert", "revert", _on_revert, 88.0, "Revert")
	revert.disabled = last.is_empty()
	revert.get_meta("art").get_child(0).modulate = Style.BRASS if not last.is_empty() else Color(Style.MUTED, 0.4)
	row.add_child(revert)
	var all := _icon_button("All saves", "saves", _on_saves, 88.0, "All")
	all.get_meta("art").get_child(0).modulate = Style.BRASS
	row.add_child(all)
	return card


## The next step as a gold card that names it.
func _menu_next_step() -> Control:
	var rec: Dictionary = GameState.recommendation()
	var b := _quiet_button("Next step", _open_recommendation)
	b.name = "MenuNextStep"
	b.custom_minimum_size = Vector2(0, 104)
	Style.make_primary(b)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, Color(0, 0, 0, 0))
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 22
	row.offset_right = -22
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var flag := Widgets.icon_rect("objective", 42.0)
	flag.modulate = Style.BRASS_INK
	row.add_child(flag)
	var words := VBoxContainer.new()
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", -2)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(words)
	words.add_child(Style.label("NEXT STEP", Style.SMALL, Color(Style.BRASS_INK, 0.7)))
	var what := Style.label(String(rec.get("title", "See what to do next")), Style.BODY, Style.BRASS_INK)
	what.clip_text = true
	what.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	words.add_child(what)
	var go := Widgets.icon_rect("advance", 36.0)
	go.modulate = Style.BRASS_INK
	row.add_child(go)
	return b


## A big card: an icon in a tile, the name, and what's there as icons and numbers (`stats`,
## [[key, text]]) or a short line; a red count when something waits unread.
func _menu_card(text: String, icon: String, status: String, callback: Callable, badge: int = 0, stats: Array = []) -> Control:
	var b := _quiet_button(text, callback)
	b.name = "Menu_" + text.split(" ")[0]
	b.custom_minimum_size = Vector2(0, 136)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 18
	row.offset_right = -10
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var tile := PanelContainer.new()
	tile.custom_minimum_size = Vector2(76, 76)
	tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_theme_stylebox_override("panel", Style.box(Color("141a2e"), Color(0, 0, 0, 0), 0, 18))
	row.add_child(tile)
	var pic := Widgets.icon_rect(icon, 44.0)
	pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if icon != "battle":
		pic.modulate = Style.BRASS
	tile.add_child(pic)
	var words := VBoxContainer.new()
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 2)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(words)
	var name := Style.label(text.split(" (")[0], Style.BODY, Style.TEXT)
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(name)
	if not stats.is_empty():
		var figures := HFlowContainer.new()
		figures.add_theme_constant_override("h_separation", 14)
		figures.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for st in stats:
			figures.add_child(Widgets.icon_value(String(st[0]), String(st[1]), Style.MUTED))
		words.add_child(figures)
	if status != "":
		var line := Style.label(status, Style.SMALL, Style.MUTED)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		words.add_child(line)
	if badge > 0:
		var dot := Widgets.count_badge(badge)
		dot.anchor_left = 1.0
		dot.anchor_right = 1.0
		dot.offset_left = -34
		dot.offset_top = -10
		b.add_child(dot)
	return b


## Your home realm's wars in a few words.
func _war_status() -> String:
	var mine := String(Data.realm_of_culture(GameState.culture))
	var foes: PackedStringArray = []
	for key in world.wars:
		var parts: PackedStringArray = String(key).split("|")
		if parts.has(mine):
			var other := parts[1] if parts[0] == mine else parts[0]
			foes.append(_realm_short(other))
	if not foes.is_empty():
		return "At war with " + " and ".join(foes)
	return "Wars elsewhere" if not world.wars.is_empty() else "Peace across the sea"


func _on_save_game() -> void:
	var e := SaveSlots.save_own(GameState)
	if e.is_empty():
		# All eight spaces are used: choose one to save over.
		_on_saves()
		return
	GameState.save_game()
	_on_menu()


## Go back to the newest save, after seeing what it undoes.
func _on_revert() -> void:
	var last := SaveSlots.latest()
	if last.is_empty():
		return
	Scenes.saves_confirm = String(last["id"])
	_on_saves()


func _on_saves() -> void:
	GameState.save_game()
	Scenes.saves_return = "res://scenes/world_map.tscn"
	Scenes.go("res://scenes/saves.tscn")


func _open_wars() -> void:
	_show_sheet("wars", "War & Politics", "", [["Chronicle", _open_chronicle.bind("war"), false, "book"], ["Close", _close_or_back, true]])
	sheet_extra.visible = true
	# The realms: each with its banner, its strength against the strongest, how weary of
	# war it is, and what it holds.
	sheet_extra.add_child(Widgets.section("Realms"))
	var realms: Array = ["vardmark", "kharzan", "ryumon"] + ([Data.CROWN] if GameState.is_crowned() else [])
	var strongest := 1
	for f in realms:
		strongest = maxi(strongest, int(world.realm_strength(f)))
	for f in realms:
		var row := HBoxContainer.new()
		row.name = "Realm_%s" % f
		row.add_theme_constant_override("separation", 16)
		row.add_child(Widgets.banner(f, Vector2(54, 72)))
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 4)
		row.add_child(col)
		var holdings: int = world.holdings_of(f).size()
		col.add_child(Style.label(String(Data.FACTIONS[f]["name"]), Style.BODY, Style.TEXT))
		var sub := HBoxContainer.new()
		sub.add_theme_constant_override("separation", 14)
		var ruler := Style.label(String(Data.FACTIONS[f].get("ruler", "")), Style.SMALL, Style.MUTED)
		ruler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ruler.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		ruler.custom_minimum_size = Vector2(10, 0)
		sub.add_child(ruler)
		sub.add_child(Widgets.icon_value("keep", str(holdings), Style.MUTED))
		col.add_child(sub)
		var men: int = world.realm_strength(f)
		var wear: float = world.weariness_of(f)
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 4)
		col.add_child(grid)
		grid.add_child(Widgets.icon_rect("men", 28.0))
		grid.add_child(Widgets.meter(float(men) / strongest, Color(String(REALM_INK.get(f, "a9c4ff")))))
		grid.add_child(Style.label(Widgets.thousands(men), Style.SMALL, Style.TEXT))
		grid.add_child(Style.label("Weary", Style.SMALL, Style.MUTED))
		grid.add_child(Widgets.meter(wear / 100.0, Style.MORALE_LOW))
		grid.add_child(Style.label("%d%%" % int(wear), Style.SMALL, Style.TEXT))
		sheet_extra.add_child(row)
	# Wars and truces, banner against banner.
	sheet_extra.add_child(Widgets.section("Wars & truces"))
	var pairs := 0
	for k in world.wars:
		var parts: PackedStringArray = k.split("|")
		var days := int((world.hour - float(world.wars[k].get("since", 0.0))) / 24.0)
		sheet_extra.add_child(_versus(parts[0], parts[1], "today" if days < 1 else "%d day%s" % [days, "" if days == 1 else "s"], Style.MORALE_LOW, "fight"))
		pairs += 1
	for k in world.truces:
		var parts: PackedStringArray = k.split("|")
		var left := int(ceil(maxf(0.0, float(world.truces[k].get("until", 0.0)) - world.hour) / 24.0))
		sheet_extra.add_child(_versus(parts[0], parts[1], "%d day%s left" % [left, "" if left == 1 else "s"], Style.MORALE_HIGH, "peace"))
		pairs += 1
	if pairs == 0:
		sheet_extra.add_child(Style.label("Every realm is at peace.", Style.SMALL, Style.MUTED))
	for t in world.tributes:
		# Tribute: who pays whom, then the silver a day and the days left as icons.
		var trow := HBoxContainer.new()
		trow.name = "Tribute"
		trow.add_theme_constant_override("separation", 10)
		trow.add_child(Widgets.banner(String(t["from"]), Vector2(26, 36)))
		trow.add_child(Widgets.icon_rect("advance", 24.0))
		trow.add_child(Widgets.banner(String(t["to"]), Vector2(26, 36)))
		var gap := Control.new()
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		trow.add_child(gap)
		trow.add_child(Widgets.icon_value("silver", "%d/day" % int(t["daily"])))
		trow.add_child(Widgets.icon_value("clock", "%d days" % int(t["days_left"]), Style.MUTED))
		sheet_extra.add_child(trow)
	# The latest news of war, with the day.
	sheet_extra.add_child(Widgets.section("Lately"))
	var shown := 0
	for entry in world.activity_log:
		if String(entry.get("type", "")) in ["war", "peace", "captured", "fight", "siege_assault"]:
			sheet_extra.add_child(_chronicle_row(int(float(entry.get("hour", 0.0))) / 24 + 1, _entry_icon(entry), String(entry.get("text", ""))))
			shown += 1
			if shown >= 3:
				break
	if shown == 0:
		var quiet := Style.label("No great battles or captures yet. When a castle falls or a truce is signed, it's told here.", Style.SMALL, Style.MUTED)
		quiet.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sheet_extra.add_child(quiet)


const REALM_INK := {"vardmark": "4a74d1", "kharzan": "d9962b", "ryumon": "c9473d", "crown": "8a7cc0"}
const REALM_SHORT := {"vardmark": "Vardmark", "kharzan": "Kharzan", "ryumon": "Ryumon", "crown": "the Crown"}


func _realm_short(f: String) -> String:
	return String(REALM_SHORT.get(f, Data.FACTIONS.get(f, {}).get("name", f)))


## One war or truce: both realms' banners, and between them its icon (crossed blades for
## war, the olive for a truce) and how long. The banners name the realms.
func _versus(a: String, b: String, text: String, tone: Color, key: String) -> Control:
	var row := HBoxContainer.new()
	row.name = "Versus"
	row.add_theme_constant_override("separation", 10)
	var left := Widgets.banner(a, Vector2(34, 46))
	left.tooltip_text = _realm_short(a)
	row.add_child(left)
	var mid := HBoxContainer.new()
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 10)
	var pic := Widgets.icon_rect(key, 30.0)
	pic.modulate = tone
	mid.add_child(pic)
	mid.add_child(Widgets.icon_value("clock", text, tone))
	row.add_child(mid)
	var right := Widgets.banner(b, Vector2(34, 46))
	right.tooltip_text = _realm_short(b)
	row.add_child(right)
	return row


# ---------------------------------------------------------------- journal

## "8 h" / "3 days", or "" when a commitment has no deadline.
func _commitment_time(c: Dictionary, prefix: String = "") -> String:
	var h := float(c.get("hours_left", -1.0))
	if h < 0.0:
		return ""
	return prefix + Style.time_short(ceilf(h))


## What the company has promised to do, one row each: the objective (or the pin, for the
## pinned one), the title, and a clock with the time left. Reading it takes no time.
func _open_journal() -> void:
	if _sheet in ["encounter", "notice", "warning"]:
		return
	var all: Array = GameState.commitments()
	var body := ""
	if all.is_empty():
		var rec: Dictionary = GameState.recommendation()
		body = "No promises bind the company yet. Settlements offer jobs, and realms at war hire sellswords."
		if String(rec.get("title", "")) != "":
			body += "\nNext step: %s" % rec.get("title", "")
	# The pinned entry leads the list.
	all.sort_custom(func(a, b): return a["id"] == GameState.pinned_commitment and b["id"] != GameState.pinned_commitment)
	var buttons := [["Chronicle", _open_chronicle.bind("all"), false, "book"], [_people_label(), _on_people, false, "mail"], ["Close", _close_sheet, true]]
	_show_sheet("journal", "Journal · %d active" % all.size(), body, buttons)
	if not all.is_empty():
		var rows := VBoxContainer.new()
		rows.name = "JournalRows"
		rows.add_theme_constant_override("separation", 8)
		for c in all:
			rows.add_child(_commitment_row(c))
		sheet_extra.add_child(rows)
	if not GameState.ended_commitments.is_empty():
		sheet_extra.add_child(Widgets.section("Recently ended"))
		for e in GameState.ended_commitments.slice(0, 3):
			sheet_extra.add_child(_chronicle_row(int(float(e.get("hour", 0.0))) / 24 + 1, "objective",
				"%s: %s" % [e.get("title", ""), e.get("outcome", "")]))
	sheet_extra.visible = sheet_extra.get_child_count() > 0


## A commitment as one row to tap: its icon, its title, what it waits on, its clock.
func _commitment_row(c: Dictionary) -> Button:
	var id := String(c["id"])
	var pinned := id == GameState.pinned_commitment
	var b := _quiet_button(String(c["title"]), _open_commitment.bind(id))
	b.name = "Commitment_" + id.validate_node_name()
	b.set_meta("pinned", pinned)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 88 if String(c["blocked"]) != "" else Style.TOUCH)
	if pinned:
		b.add_theme_stylebox_override("normal", Style.box(Color("221d10"), Style.BRASS, 2))
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 14
	row.offset_right = -12
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var pic := Widgets.icon_rect("pin" if pinned else "objective", 32.0)
	pic.modulate = Style.BRASS
	row.add_child(pic)
	var words := VBoxContainer.new()
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 0)
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(words)
	var t := Style.label(String(c["title"]), Style.SMALL, Style.TEXT)
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t.custom_minimum_size = Vector2(10, 0)
	words.add_child(t)
	if String(c["blocked"]) != "":
		var w := Style.label("Waiting: %s" % c["blocked"], Style.SMALL, Style.MORALE_MID)
		w.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		w.custom_minimum_size = Vector2(10, 0)
		words.add_child(w)
	var time := _commitment_time(c)
	if time != "":
		var clock := Widgets.icon_value("clock", time, Style.ENEMY_LIGHT if float(c.get("hours_left", 99.0)) < 12.0 else Style.MUTED)
		clock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(clock)
	return b


## One line of the chronicle: a day badge, the kind's icon and what happened.
func _chronicle_row(day: int, key: String, text: String) -> Control:
	var row := HBoxContainer.new()
	row.name = "Entry"
	row.add_theme_constant_override("separation", 10)
	var d := Widgets.stat("day", str(day))
	d.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(d)
	var pic := Widgets.icon_rect(key, 28.0)
	pic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	pic.modulate = Style.MUTED
	row.add_child(pic)
	var l := Style.label(text, Style.SMALL, Style.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(10, 0)
	row.add_child(l)
	return row


func _find_commitment(id: String) -> Dictionary:
	for c in GameState.commitments():
		if c["id"] == id:
			return c
	return {}


func _open_commitment(id: String) -> void:
	var c := _find_commitment(id)
	if c.is_empty():
		_open_journal()
		return
	var lines: PackedStringArray = [String(c["objective"])]
	if String(c["reward"]) != "":
		lines.append("Reward: %s" % c["reward"])
	if String(c["cost"]) != "":
		lines.append("Cost: %s" % c["cost"])
	if String(c["blocked"]) != "":
		lines.append("Waiting: %s" % c["blocked"])
	var buttons := []
	if String(c["place"]) != "" and Data.SETTLEMENTS.has(String(c["place"])):
		buttons.append(["Show on map", _focus_place.bind(String(c["place"])), true, "mappin"])
	if id.begins_with("captive_"):
		buttons.append(["Talk", _open_talk.bind(int(id.trim_prefix("captive_")), "captive"), true, "talk"])
	if id.begins_with("gathering_"):
		var gid := int(id.trim_prefix("gathering_"))
		if world.here() != String(c["place"]):
			buttons.append(["Ride there", _on_ride_to.bind(String(c["place"])), true, "ride"])
		buttons.append(["Who's coming", _open_guest_list.bind(gid), false, "company"])
	if id == "muster" or id == "banners":
		if id == "muster" and world.here() != String(c["place"]):
			buttons.append(["Ride there", _on_ride_to.bind(String(c["place"])), true, "ride"])
		buttons.append(["Your court", _open_court, id == "muster" and world.here() == String(c["place"]), "crown"])
	buttons.append(["Unpin" if GameState.pinned_commitment == id else "Pin to top", _on_pin.bind(id), false, "pin"])
	buttons.append(["Journal", _open_journal, false, "journal"])
	_show_sheet("commitment", String(c["title"]), "\n".join(lines), buttons)
	var t := _commitment_time(c)
	if t != "":
		var clock := Widgets.stat("clock", t, Style.ENEMY_LIGHT if float(c.get("hours_left", 99.0)) < 12.0 else Style.TEXT)
		clock.name = "TimeLeft"
		sheet_extra.add_child(Widgets.chip_row([clock]))
		sheet_extra.visible = true


func _on_pin(id: String) -> void:
	GameState.pin_commitment(id)
	_refresh_hud()
	_open_commitment(id)


## The chronicle's filters, their words and icons.
const CHRONICLE_FILTERS := [["all", "All", "book"], ["war", "Wars", "battle"], ["siege", "Sieges", "storm"], ["deed", "Deeds", "renown"]]


## The chronicle: the last 30 events (wars, peace, captures, sieges, company deeds), one
## row each with its day and the kind's icon, under All / Wars / Sieges / Deeds.
func _open_chronicle(filter: String = "all") -> void:
	var entries: Array = []
	for entry in world.activity_log:
		if filter == "all" or entry.get("category", "") == filter:
			entries.append(entry)
			if entries.size() >= 30:
				break
	_show_sheet("chronicle", "The Chronicle", "No chronicle events in this category yet." if entries.is_empty() else "",
		[["Close", _close_or_back]])
	var words: Array = []
	var icons: Array = []
	var current := 0
	for i in CHRONICLE_FILTERS.size():
		words.append(CHRONICLE_FILTERS[i][1])
		icons.append(CHRONICLE_FILTERS[i][2])
		if CHRONICLE_FILTERS[i][0] == filter:
			current = i
	sheet_extra.add_child(Widgets.segmented(words, current, func(i: int): _open_chronicle(String(CHRONICLE_FILTERS[i][0])), "ChronicleFilter", icons))
	var list := VBoxContainer.new()
	list.name = "ChronicleEntries"
	list.add_theme_constant_override("separation", 10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for entry in entries:
		list.add_child(_chronicle_row(int(float(entry.get("hour", 0.0))) / 24 + 1, _entry_icon(entry), String(entry.get("text", ""))))
	# Thirty entries would push the sheet off the top: they scroll in half the screen.
	var scroll := ScrollContainer.new()
	scroll.name = "ChronicleScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, minf(float(entries.size()) * 56.0, get_viewport_rect().size.y * 0.5))
	scroll.add_child(list)
	sheet_extra.add_child(scroll)
	sheet_extra.visible = true


## The icon for a chronicle entry, by its type and category.
func _entry_icon(entry: Dictionary) -> String:
	match String(entry.get("type", "")):
		"war":
			return "battle"
		"peace":
			return "peace"
		"captured":
			return "lock"
		"fight":
			return "fight"
		"siege_assault", "siege":
			return "storm"
		"raid", "burned":
			return "fire"
	match String(entry.get("category", "")):
		"siege":
			return "storm"
		"deed":
			return "renown"
		"war":
			return "battle"
	return "book"


func _open_activity() -> void:
	_open_chronicle("all")


func _open_recommendation() -> void:
	if _sheet in ["encounter", "notice", "warning"]:
		return
	var rec: Dictionary = GameState.recommendation()
	var buttons := []
	match String(rec.get("action", "")):
		"place":
			var place := String(rec.get("place", ""))
			if Data.SETTLEMENTS.has(place):
				buttons.append(["Show on map", _focus_place.bind(place), true, "mappin"])
		"warband":
			buttons.append(["Warband", _on_warband, true, "company"])
	buttons.append(["Close", _close_sheet])
	_show_sheet("recommendation", String(rec.get("title", "Next step")), String(rec.get("body", "")), buttons, "", "objective")


func _focus_place(id: String) -> void:
	_selected = id
	cam_center = Data.pos(id)
	_clamp_camera()
	_sync_layers()
	_open_preview(id)


## People & Letters, by name only: the unread count is the red badge on its card and on
## the menu button, not a number in the words.
func _people_label() -> String:
	return "People & Letters"


## The banner a newly arrived letter shows under the top bar.
func _build_letter_banner() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	letter_banner = PanelContainer.new()
	letter_banner.name = "LetterBanner"
	letter_banner.theme = Style.make_theme()
	letter_banner.anchor_right = 1.0
	letter_banner.offset_left = 16.0
	letter_banner.offset_right = -16.0
	var sb := Style.box(Color(Style.NIGHT, 0.96), Color("6a5226"), 2, 20)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 14
	letter_banner.add_theme_stylebox_override("panel", sb)
	letter_banner.visible = false
	layer.add_child(letter_banner)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	letter_banner.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 18)
	v.add_child(top)
	var env := Control.new()
	env.custom_minimum_size = Vector2(110, 80)
	env.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	env.mouse_filter = Control.MOUSE_FILTER_IGNORE
	env.draw.connect(func():
		var r := Rect2(Vector2(4, 6), Vector2(102, 70))
		env.draw_rect(Rect2(r.position + Vector2(2, 4), r.size), Color(0, 0, 0, 0.45))
		env.draw_rect(r, Color("e6d3a5"))
		env.draw_colored_polygon(PackedVector2Array([r.position, r.position + Vector2(r.size.x, 0), r.position + Vector2(r.size.x * 0.5, r.size.y * 0.55)]), Color("cdb47c"))
		var c := r.position + Vector2(r.size.x * 0.5, r.size.y * 0.52)
		env.draw_circle(c, 15, _banner_seal.darkened(0.2))
		env.draw_circle(c - Vector2(2, 2), 12, _banner_seal))
	top.add_child(env)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 2)
	top.add_child(words)
	_banner_title = Style.label("A rider brings a letter", 30, Style.BRASS)
	_banner_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var big: Font = Style.display_font()
	if big != null:
		_banner_title.add_theme_font_override("font", big)
	words.add_child(_banner_title)
	_banner_from = Style.label("", Style.SMALL, Style.TEXT)
	_banner_from.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(_banner_from)
	_banner_line = Style.label("", 22, Color("cdbf9c"))
	var italic: Font = Style.letter_font(true)
	if italic != null:
		_banner_line.add_theme_font_override("font", italic)
	_banner_line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_banner_line.custom_minimum_size.x = 10
	words.add_child(_banner_line)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var read := _button("Read it", _read_banner_letter)
	read.name = "ReadLetter"
	Style.make_primary(read)
	read.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	read.size_flags_stretch_ratio = 1.6
	row.add_child(read)
	var later := _button("Later", func(): letter_banner.visible = false)
	later.name = "LaterLetter"
	later.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(later)


## New letters show as a banner for a few seconds; the clock never stops for them.
func _watch_letters(delta: float) -> void:
	if world.social == null or letter_banner == null:
		return
	# A letter waits while you talk to a lord or rule your crown.
	if _sheet == "talk":
		letter_banner.visible = false
		return
	var fresh: Array = world.social.take_unannounced()
	if not fresh.is_empty() and not autoplay:
		_show_letter_banner(fresh[fresh.size() - 1])
	var invites: Array = GameState.take_new_invitations()
	if not invites.is_empty() and not autoplay and not letter_banner.visible:
		_show_invite_banner(invites[invites.size() - 1])
	if letter_banner.visible:
		_banner_left -= delta
		if _banner_left <= 0.0:
			letter_banner.visible = false


func _show_letter_banner(l: Dictionary) -> void:
	_banner_invite = -1
	_banner_title.text = "A rider brings a letter"
	var view: Dictionary = world.social.letter_view(l)
	var sender: Dictionary = world.social.get_person(String(l.get("sender_id", "")))
	var place := String(l.get("destination", ""))
	_banner_letter = String(l["id"])
	_banner_seal = Color(String(view.get("seal_color", "8e1f17")))
	_banner_from.text = "From %s%s" % [sender.get("name", "a friend"), (", at %s" % Data.settlement(place)["name"]) if Data.SETTLEMENTS.has(place) else ""]
	var body: Array = view.get("body", [])
	_banner_line.text = "“%s…”" % String(body[0]).left(60).strip_edges() if not body.is_empty() else ""
	var insets := Style.safe_insets(get_viewport())
	letter_banner.offset_top = TOP_BAR + float(insets["top"]) + 12.0
	letter_banner.visible = true
	_banner_left = LETTER_BANNER_SECONDS
	Sound.play("page", 0.0, 0.05)
	if not Style.motion_reduced():
		letter_banner.modulate.a = 0.0
		letter_banner.create_tween().tween_property(letter_banner, "modulate:a", 1.0, 0.25)


## An invitation to a gathering, brought like a letter, sealed in brass.
func _show_invite_banner(g: Dictionary) -> void:
	_banner_invite = int(g["id"])
	_banner_title.text = "An invitation"
	_banner_seal = Color("b8862b")
	_banner_from.text = "From %s, at %s" % [GameState.gathering_host_name(g), Data.settlement(String(g["place"]))["name"]]
	_banner_line.text = "“The %s, %s…”" % [String(g["name"]), GameState.gathering_when(g)]
	var insets := Style.safe_insets(get_viewport())
	letter_banner.offset_top = TOP_BAR + float(insets["top"]) + 12.0
	letter_banner.visible = true
	_banner_left = LETTER_BANNER_SECONDS
	Sound.play("page", 0.0, 0.05)


func _read_banner_letter() -> void:
	letter_banner.visible = false
	if _banner_invite >= 0:
		_open_invitation(_banner_invite)
		return
	GameState.save_game()
	Scenes.people_return = "res://scenes/world_map.tscn"
	Scenes.people_letter = _banner_letter
	Scenes.go("res://scenes/people.tscn")


## An invitation: when, why you're asked, who's coming, how far.
func _open_invitation(gid: int) -> void:
	var g: Dictionary = world.gathering_by_id(gid)
	if g.is_empty():
		_close_sheet()
		return
	var place := String(g["place"])
	var inv: Dictionary = GameState.gathering_invite(g)
	var ctx := {"host": GameState.gathering_host_name(g), "name": String(g["name"]), "place": Data.settlement(place)["name"],
		"when": GameState.gathering_when(g).trim_prefix("from "), "why": String(inv["why"])}
	var body := Gatherings.fill(Gatherings.INVITE if bool(inv["invited"]) else Gatherings.NOT_INVITED, ctx)
	var coming: int = world.gathering_guests(g).size()
	var buttons := []
	if world.here() != place:
		buttons.append(["Ride there", _on_ride_to.bind(place), true, "ride"])
	buttons.append(["Who's coming", _open_guest_list.bind(gid), false, "company"])
	buttons.append(["Close", _close_sheet])
	_show_sheet("invitation", "The %s at %s" % [String(g["name"]), Data.settlement(place)["name"]], body, buttons, "", _gathering_icon(g))
	var chips := [Widgets.stat("men", "%d coming" % coming)]
	chips.append(Widgets.stat("clock", Style.time_short(world.hours_to(place))) if world.here() != place else Widgets.chip("You're there", Style.MORALE_HIGH, "", "mappin"))
	sheet_extra.add_child(Widgets.chip_row(chips))
	sheet_extra.visible = true


func _open_guest_list(gid: int) -> void:
	var g: Dictionary = world.gathering_by_id(gid)
	if g.is_empty():
		_close_sheet()
		return
	var host: Dictionary = world.lord_by_id(int(g["host_lord"])) if int(g["host_lord"]) >= 0 else {}
	var guests: Array = []
	if not host.is_empty():
		guests.append(host)
	for l in world.gathering_guests(g):
		if l != host:
			guests.append(l)
	_show_sheet("invitation", "Who's coming", "No one has answered yet." if guests.is_empty() else "",
		[["Back", _open_invitation.bind(gid), true, "back"], ["Close", _close_sheet]])
	# Each guest as a face, a name and what they think of you; the host wears the keep.
	var list := VBoxContainer.new()
	list.name = "GuestList"
	list.add_theme_constant_override("separation", 8)
	for l in guests:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var face := TextureRect.new()
		face.texture = CaptainArt.texture(LordVoice.portrait_record(l))
		face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.custom_minimum_size = Vector2(44, 56)
		row.add_child(face)
		var who := Style.label(LordTalk.short_name(l), Style.SMALL, Style.TEXT)
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		who.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		who.custom_minimum_size = Vector2(10, 0)
		row.add_child(who)
		if l == host:
			row.add_child(Widgets.chip("Host", Style.BRASS, "", "keep", true))
		row.add_child(_regard_chip(l))
		list.add_child(row)
	sheet_extra.add_child(list)
	sheet_extra.visible = true


func _on_ride_to(place: String) -> void:
	if world.travel(place) or world.here() == place:
		_close_sheet()
		_refresh_hud()


func _on_people() -> void:
	GameState.save_game()
	Scenes.people_return = "res://scenes/world_map.tscn"
	Scenes.go("res://scenes/people.tscn")


func _on_settings() -> void:
	GameState.save_game()
	Scenes.settings_return = "res://scenes/world_map.tscn"
	Scenes.go("res://scenes/settings.tscn")


func _on_home() -> void:
	GameState.save_game()
	Scenes.go("res://scenes/title.tscn")


func _on_warband() -> void:
	GameState.save_game()
	Scenes.go("res://scenes/main_menu.tscn")


## An army is about to storm walls you have a stake in: beside it, or against your fief.
func _open_assault_call() -> void:
	var call: Dictionary = world.pending_assault
	if call.is_empty():
		return
	var target := String(call["target"])
	var place: String = Data.settlement(target)["name"]
	var army: Dictionary = {}
	for a in world.campaign_armies:
		if int(a["id"]) == int(call["army"]):
			army = a
	if army.is_empty():
		GameState.answer_assault(false)
		return
	var realm: String = Data.FACTIONS[army["realm"]]["name"]
	var their_men := 0
	for m in MarshalArmies.members(world, army):
		their_men += world.men_of(m.army)
	var garrison_men: int = world.men_of(world.garrisons.get(target, []))
	if String(call["role"]) == "lead":
		_show_sheet("encounter", "The assault on %s" % place,
			"The marshal of %s offers you the van." % realm,
			[["Lead", _on_assault_answer.bind(true), true, "storm"], ["Stand aside", _on_assault_answer.bind(false), false, "retreat"]])
	else:
		_show_sheet("encounter", "%s is stormed!" % place,
			"The army of %s storms the walls of your fief." % realm,
			[["Defend", _on_assault_answer.bind(true), true, "walls"], ["Stand aside", _on_assault_answer.bind(false), false, "retreat"]])
	var share: float = maxf(1.0, maxf(float(their_men), float(garrison_men)))
	var stormers := String(army["realm"])
	var holder: String = world.owner_of(target)
	sheet_extra.add_child(_odds_bar(stormers, their_men, float(their_men) / share, Style.ENEMY if String(call["role"]) != "lead" else Style.PLAYER, "OddsStormers"))
	sheet_extra.add_child(_odds_bar(holder, garrison_men, float(garrison_men) / share, Style.PLAYER if String(call["role"]) != "lead" else Style.ENEMY, "OddsWalls"))
	sheet_extra.visible = true


func _on_assault_answer(fight: bool) -> void:
	GameState.answer_assault(fight)
	_close_sheet()
	if fight and not GameState.pending_battle.is_empty():
		GameState.save_before_battle()
		Scenes.go("res://scenes/battle.tscn")
	_refresh_hud()


## Cast off your liege: what it means, before it's done.
func _open_raise_crown() -> void:
	var liege: String = Data.FACTIONS[GameState.fief_realm()]["name"]
	_show_sheet("crown", "Raise your banner",
		"Declare %s the seat of your own crown. %s will go to war with you at once and send its armies for your walls. Every castle or town you storm after this is yours, and its dues fill your purse and your garrisons. There is no going back." % [
			Data.settlement(GameState.fief_id())["name"], liege],
		[["Raise crown", _on_raise_crown, true, "crown"], ["Not yet", _open_here]])


func _on_raise_crown() -> void:
	if GameState.declare_crown():
		Sound.play("horn")
	_close_sheet()
	_refresh_hud()
	_sync_layers()


## The crown: what it holds, who it fights, who stands with it.
## Your crown's Court tab: gatherings, the banners, petitions.
func _open_court() -> void:
	_open_crown("court")


## Your crown's own screen (kingdom_screen.gd), over the map; the map holds still.
func _open_crown(start_tab: String = "realm") -> void:
	_close_sheet()
	if _kingdom != null and is_instance_valid(_kingdom):
		_kingdom.queue_free()
	_sheet = "talk"
	bottom_bar.visible = false
	_kingdom = KingdomScreen.open(_hud, GameState, start_tab)
	_kingdom.closed.connect(func():
		_kingdom = null
		_sheet = ""
		bottom_bar.visible = true
		_refresh_hud())
	_kingdom.wants_place.connect(func(id: String):
		_kingdom = null
		_sheet = ""
		bottom_bar.visible = true
		_focus_place(id))


## Before an assault: the garrison, the walls, and the odds.
func _open_siege(id: String) -> void:
	var check: Dictionary = GameState.siege_check(id)
	if not check["ok"]:
		_open_notice(String(check["reason"]), "The walls")
		return
	var place: String = Data.settlement(id)["name"]
	var walls: float = float(Lords.WALLS[check["kind"]])
	var fighters: Array = GameState.army.filter(func(s): return int(s["men"]) > 0)
	var garrison: Array = world.garrisons.get(id, [])
	var allies: Array = GameState.siege_allies(id)
	var ally_men := 0
	for a in allies:
		ally_men += int(a["men"])
	fighters = fighters + allies
	var body := "Batter down the gate under their archers, then rout the garrison. A gate still standing when time runs out means the walls held."
	if garrison.is_empty():
		body = "The walls stand empty. It is yours for the taking."
	_show_sheet("siege", "Storm %s" % place, body, [["Lead", _on_storm.bind(id), true, "storm"],
		["Send in", _on_storm_send.bind(id), false, "advance"], ["Back", _open_here, false, "back"]])
	var mine := GameState.total_men() + ally_men
	var theirs := int(check["men"])
	var top := float(maxi(1, maxi(mine, theirs)))
	sheet_extra.add_child(_odds_bar(_party_realm(world.player()), mine, float(mine) / top, Style.PLAYER, "OddsYou"))
	sheet_extra.add_child(_odds_bar(String(check["realm"]), theirs, float(theirs) / top, Style.ENEMY, "OddsWalls"))
	var chips := [Widgets.chip("Walls ×%s" % String.num(walls, 1), Style.MORALE_MID, "", "walls")]
	if ally_men > 0:
		chips.append(Widgets.chip("+%d beside you" % ally_men, Style.MORALE_HIGH, "", "company"))
	if not garrison.is_empty():
		var odds: Dictionary = AutoResolve.odds(fighters, garrison, null, "rout", walls)
		chips.append(Widgets.chip("Can succeed" if odds["player_wins"] else "Would fail", Style.MORALE_HIGH if odds["player_wins"] else Style.MORALE_LOW))
	var row := Widgets.chip_row(chips)
	row.name = "SiegeChips"
	sheet_extra.add_child(row)
	sheet_extra.visible = true


## Before a raid: what the village holds, what burning it costs, and whether its militia
## will fight for it.
func _open_raid(id: String) -> void:
	var check: Dictionary = GameState.raid_check(id)
	if not check["ok"]:
		_open_notice(String(check["reason"]), "The village")
		return
	var place: String = Data.settlement(id)["name"]
	var owner: String = world.owner_of(id)
	var realm: String = GameState.realm_word(owner)
	var body := "%s's lords nearby will ride at you while the carts are loaded." % realm
	var buttons := []
	var odds := {}
	if bool(check["stand"]):
		var fighters: Array = GameState.army.filter(func(s): return int(s["men"]) > 0)
		odds = AutoResolve.odds(fighters, GameState.raid_defenders(id), null, "rout")
		buttons = [["Lead", _on_raid_fight.bind(id), true, "fight"], ["Send in", _on_raid_send.bind(id), false, "advance"], ["Back", _open_here, false, "back"]]
	else:
		buttons = [["Burn it", _on_raid_burn.bind(id), true, "fire"], ["Back", _open_here, false, "back"]]
	_show_sheet("raid", "Raid %s" % place, body, buttons)
	var tiles := Widgets.tile_grid([
		Widgets.tile("silver", "+%d" % Lords.RAID_LOOT, "loot"),
		Widgets.tile("food", "+%d" % Lords.PLAYER_RAID_FOOD, "rations"),
		Widgets.tile("clock", Style.time_short(Lords.RAID_HOURS), "to load"),
		Widgets.tile("fire", "%d days" % Lords.BURNED_DAYS, "pays %s nothing" % realm)], 2)
	tiles.name = "RaidTiles"
	sheet_extra.add_child(tiles)
	var chips := []
	if bool(check["stand"]):
		chips.append(Widgets.chip("%d stand" % int(check["men"]), Style.MORALE_LOW, "", "militia"))
		chips.append(Widgets.chip("You'd drive them off" if odds["player_wins"] else "You'd be beaten", Style.MORALE_HIGH if odds["player_wins"] else Style.MORALE_LOW))
	else:
		chips.append(Widgets.chip("%d won't stand" % int(check["men"]), Style.MORALE_HIGH, "", "militia"))
	if GameState.is_crowned():
		chips.append(Widgets.chip("Honorable %d" % Lords.RAID_HONORABLE_REGARD, Style.MORALE_LOW, "", "bond"))
		chips.append(Widgets.chip("Cruel +%d" % Lords.RAID_CRUEL_REGARD, Style.MORALE_HIGH, "", "bond"))
	var row := Widgets.chip_row(chips)
	row.name = "RaidChips"
	sheet_extra.add_child(row)
	sheet_extra.visible = true


func _on_raid_fight(id: String) -> void:
	GameState.start_raid_battle(id)
	GameState.save_before_battle()
	Scenes.go("res://scenes/battle.tscn")


func _on_raid_send(id: String) -> void:
	GameState.auto_resolve_raid(id)
	_after_raid(id)


func _on_raid_burn(id: String) -> void:
	GameState.raid_village(id)
	_after_raid(id)


func _after_raid(id: String) -> void:
	Sound.play("coins" if world.is_burned(id) else "bell")
	_close_sheet()
	_refresh_hud()
	_sync_layers()
	if GameState.has_notice():
		var notice: Dictionary = GameState.take_map_notice()
		_open_notice(notice["text"], "The raid", notice["items"])


func _on_storm(id: String) -> void:
	if world.garrisons.get(id, []).is_empty():
		_on_storm_send(id)
		return
	GameState.start_siege_battle(id)
	GameState.save_before_battle()
	Scenes.go("res://scenes/battle.tscn")


func _on_storm_send(id: String) -> void:
	GameState.auto_resolve_siege(id)
	_close_sheet()
	_refresh_hud()
	_sync_layers()
	if GameState.has_notice():
		var notice: Dictionary = GameState.take_map_notice()
		_open_notice(notice["text"], "The assault", notice["items"])


func _on_fight() -> void:
	GameState.start_encounter_battle()
	GameState.save_before_battle()
	Scenes.go("res://scenes/battle.tscn")


## Settle the fight at once, without the battle screen.
func _on_send_in() -> void:
	var won: bool = GameState.auto_resolve_encounter().get("won", false)
	Sound.play("charge")
	get_tree().create_timer(1.1).timeout.connect(Sound.play.bind("coins" if won else "bell"))
	_close_sheet()
	var notice: Dictionary = GameState.take_map_notice()
	_open_notice(notice["text"], notice["title"], notice["items"])


func _on_withdraw() -> void:
	if not world.can_withdraw():
		var b = world.party(world.encounter)
		var l_name: String = b.name if b != null else "The enemy"
		_show_sheet("encounter", "Ridden down!", "%s's riders cut off your retreat. You have to fight." % l_name,
			[["Fight", _on_fight, true, "fight"], ["Send in", _on_send_in, false, "advance"]])
		return
	world.withdraw()
	# Riding back takes hours: pay for any day that ended on the way.
	GameState.settle()
	GameState.save_game()
	_close_sheet()
	_open_here()


func _on_speed() -> void:
	speed = 2.0 if speed < 1.5 else 1.0
	paused = false


## Pause, play at an hour a second, or fast at two.
func _on_time(rate: float) -> void:
	paused = rate <= 0.0
	if rate > 0.0:
		speed = rate
	Sound.play("click", -4.0)
	_refresh_hud()


func _pill_box(color: Color, border: Color = Color(1, 1, 1, 0.12)) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = color
	b.border_color = border
	b.set_border_width_all(1)
	b.set_corner_radius_all(16)
	b.content_margin_left = 10.0
	b.content_margin_right = 12.0
	b.content_margin_top = 4.0
	b.content_margin_bottom = 4.0
	return b


func _time_button(kind: String, callback: Callable) -> Button:
	var b := _button("", callback)
	b.name = "Time_" + kind
	b.tooltip_text = {"pause": "Pause", "play": "Play", "fast": "Fast"}[kind]
	b.icon = Widgets.icon(kind)
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", 32)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size = Vector2(Style.TOUCH, Style.TOUCH)
	return b


## How far along the current ride or wait is, for the thin bar under the status line.
func _update_progress(p) -> void:
	var key := ""
	var left := 0.0
	if world.encounter == -1 and p.moving():
		key = "ride:" + String(world.destination())
		left = float(world.hours_to(world.destination()))
	elif world.encounter == -1 and p.wait > 0.0:
		key = "wait:%d" % int(p.node.hash())
		left = float(p.wait)
	if key == "":
		_trip_key = ""
		status_progress.visible = false
		return
	if key != _trip_key or left > _trip_total:
		_trip_key = key
		_trip_total = maxf(left, 0.01)
	status_progress.visible = true
	status_progress.value = clampf(1.0 - left / _trip_total, 0.0, 1.0)


func _on_new_campaign() -> void:
	Scenes.go("res://scenes/new_campaign.tscn")


## A red count on the Warband button while talks wait at the fire.
func _refresh_talks_badge() -> void:
	if _warband_btn == null:
		return
	var n: int = GameState.new_bond_talks().size()
	if n != _talks_waiting:
		_talks_waiting = n
		var badge := _warband_btn.get_node_or_null("TalksBadge") as PanelContainer
		if badge != null:
			(badge.get_node("Count") as Label).text = str(n)
			badge.visible = n > 0


func _refresh_hud() -> void:
	var h := int(world.hour)
	if h != _badge_hour:
		_badge_hour = h
		_refresh_talks_badge()
	if unread_badge != null and world.social != null:
		var unread: int = world.social.unread_letters_count()
		unread_badge.visible = unread > 0
		(unread_badge.get_node("Count") as Label).text = str(unread)
	day_label.text = str(h / 24 + 1)
	clock_label.text = "%02d:00" % (h % 24)
	var night_now := h % 24 < 6 or h % 24 >= 20
	day_icon.texture = Widgets.icon("moon" if night_now else "sun")
	day_icon.modulate = Color(0.78, 0.82, 0.95) if night_now else Style.BRASS
	var current := pause_button if paused else (fast_button if speed > 1.5 else play_button)
	for b in [pause_button, play_button, fast_button]:
		var on: bool = b == current
		b.add_theme_stylebox_override("normal", _pill_box(Style.BRASS if on else Color(Style.PANEL, 0.94)))
		b.add_theme_stylebox_override("hover", _pill_box(Style.BRASS.lightened(0.1) if on else Color(Style.PANEL, 0.94).lightened(0.08)))
		var ink := Color(0.1, 0.08, 0.12) if on else Color(0.93, 0.89, 0.8)
		for state in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
			b.add_theme_color_override(state, ink)
	bottom_bar.visible = not _sheet_open()
	var modal := _sheet in ["encounter", "notice", "warning"]
	warband_button.disabled = modal
	for b in [pause_button, play_button, fast_button]:
		b.disabled = modal or _sheet == "menu"
	for badge in resource_buttons.values():
		badge.disabled = modal
	var days: int = GameState.food_days()
	resource_buttons["men"].text = _short_amount(GameState.total_men())
	resource_buttons["silver"].text = _short_amount(GameState.silver)
	resource_buttons["food"].text = _short_amount(days)
	resource_buttons["renown"].text = _short_amount(GameState.renown)
	resource_buttons["men"].tooltip_text = "%d men in %d squads" % [GameState.total_men(), GameState.army.size()]
	resource_buttons["silver"].tooltip_text = "%d silver · wages %d per day" % [GameState.silver, GameState.daily_wages()]
	resource_buttons["food"].tooltip_text = "%d rations · %d days of food" % [GameState.food, days]
	resource_buttons["renown"].tooltip_text = "%d renown · capacity %d squads" % [GameState.renown, GameState.squad_cap()]
	resource_buttons["silver"].add_theme_color_override("font_color", Style.ENEMY_LIGHT if GameState.silver < GameState.daily_wages() else Style.TEXT)
	resource_buttons["food"].add_theme_color_override("font_color", Style.ENEMY_LIGHT if days < 2 else Style.TEXT)
	var p = world.player()
	var activity := "home"
	if world.encounter != -1:
		var enc_p = world.party(world.encounter)
		activity = "fight"
		if enc_p != null and enc_p.kind == WorldSim.LORD:
			var stops: bool = _sheet_is_danger("encounter") == false
			activity = "talk" if stops else "fight"
			status_label.text = ("%s stops to talk" if stops else "%s blocks your road") % enc_p.name
		else:
			status_label.text = "Bandits block the road"
	elif world.following_party != -1:
		var fp = world.party(world.following_party)
		activity = "ride"
		status_label.text = "With %s" % (fp.name if fp != null else "allies")
	elif p.moving():
		var to: String = world.destination()
		activity = "ride"
		status_label.text = "%s · %s" % [Data.settlement(to)["name"], _hours_text(world.hours_to(to))]
	elif p.wait > 0.0:
		activity = "revert"
		status_label.text = "%s · %s" % [Data.settlement(p.node)["name"], _hours_text(p.wait)]
	else:
		status_label.text = String(Data.settlement(p.node)["name"])
	status_icon.texture = Widgets.icon(activity)
	var low_food: bool = GameState.food < GameState.total_men()
	var low_silver: bool = GameState.silver < GameState.daily_wages()
	var chaser = _chaser()
	var captives: int = GameState.captive_lords().size()
	status_label.add_theme_color_override("font_color", Style.ENEMY_LIGHT if low_food or low_silver or chaser != null else Style.TEXT)
	_refresh_status_chips(chaser, low_food, low_silver, captives)
	_refresh_pinned(h)
	_update_progress(p)


## The chips after the status line, rebuilt only when what they say changes: the lord
## riding after you (▼ when he can catch you, ▲ when you're quicker), red food and silver
## when they won't last the day, and the lock with your captives.
func _refresh_status_chips(chaser, low_food: bool, low_silver: bool, captives: int) -> void:
	var catches: bool = chaser != null and world.can_catch_player(chaser)
	var sig := "%s|%s|%s|%s|%d" % [short_lord_name(chaser.name) if chaser != null else "", catches, low_food, low_silver, captives]
	if sig == _status_sig:
		return
	_status_sig = sig
	for c in status_chips.get_children():
		status_chips.remove_child(c)
		c.queue_free()
	if chaser != null:
		var hunt := Widgets.chip(short_lord_name(chaser.name), Style.MORALE_LOW if catches else Style.MORALE_MID, "▼" if catches else "▲", "skull")
		hunt.name = "ChaserChip"
		hunt.tooltip_text = "%s is riding after you%s" % [chaser.name, " and is faster" if catches else ", but you're quicker"]
		status_chips.add_child(hunt)
	if low_food:
		var f := Widgets.chip("", Style.ENEMY_LIGHT, "▼", "food")
		f.name = "LowFood"
		f.tooltip_text = "Not enough food for the next day: men may leave."
		status_chips.add_child(f)
	if low_silver:
		var m := Widgets.chip("", Style.ENEMY_LIGHT, "▼", "silver")
		m.name = "LowSilver"
		m.tooltip_text = "Not enough silver for the next day's wages: men may leave."
		status_chips.add_child(m)
	if captives > 0:
		var lock := Widgets.stat("lock", str(captives))
		lock.name = "Captives"
		status_chips.add_child(lock)


## The pinned commitment's chip under the bar: the objective, its title and its clock.
## Checked once an hour of game time (or when the pin changes), not every frame.
func _refresh_pinned(h: int) -> void:
	if pinned_chip == null:
		return
	var id: String = GameState.pinned_commitment
	if h != _pinned_hour or id != _pinned_for:
		_pinned_hour = h
		_pinned_for = id
		var c: Dictionary = _find_commitment(id) if id != "" else {}
		pinned_chip.set_meta("id", id if not c.is_empty() else "")
		var sig := "" if c.is_empty() else "%s|%s|%s" % [id, c["title"], _commitment_time(c)]
		if sig != _pinned_sig:
			_pinned_sig = sig
			var row := pinned_chip.get_node("PinnedRow") as HBoxContainer
			for k in row.get_children():
				row.remove_child(k)
				k.queue_free()
			if not c.is_empty():
				var pic := Widgets.icon_rect("objective", 30.0)
				pic.modulate = Color("f3cf7a")
				row.add_child(pic)
				var t := Style.label(String(c["title"]), Style.SMALL, Color("f3cf7a"))
				t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
				t.custom_minimum_size = Vector2(minf(360.0, get_viewport_rect().size.x - 260.0), 0)
				row.add_child(t)
				var time := _commitment_time(c)
				if time != "":
					row.add_child(Widgets.icon_value("clock", time, Style.MUTED))
				pinned_chip.text = String(c["title"])
				# The words are drawn by the row, so the chip takes the row's width.
				pinned_chip.custom_minimum_size.x = row.get_combined_minimum_size().x + 32.0
				pinned_chip.reset_size()
	var show := String(pinned_chip.get_meta("id", "")) != "" and not _sheet_open() and _sheet == ""
	pinned_chip.visible = show


func _open_pinned() -> void:
	var id := String(pinned_chip.get_meta("id", ""))
	if id != "" and _sheet == "":
		_open_commitment(id)



# ---------------------------------------------------------------- layers

## The map is drawn in layers, back to front: the sea and the land (the backdrop),
## settlements and parties (this node), the light of the hour, then the names.
func _build_layers() -> void:
	terrain = MapTerrain.shared()
	backdrop = MapBackdrop.new()
	add_child(backdrop)
	sky = ColorRect.new()
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky.z_index = 1
	sky.material = backdrop.shader_material(SKY_SHADER)
	add_child(sky)
	labels = Node2D.new()
	labels.z_index = 2
	labels.draw.connect(_draw_labels)
	add_child(labels)


## Point the layers at what the camera sees, in the hour's light.
func _sync_layers() -> void:
	if backdrop == null or backdrop.land_layer == null:
		return
	backdrop.point_camera(cam_center, cam_scale, _view.get_center(), get_viewport_rect().size, [sky])
	(sky.material as ShaderMaterial).set_shader_parameter("daylight", _daylight())
	labels.queue_redraw()


## The light over the map at this hour: white by day, gold at dawn and dusk, blue at night.
func _daylight() -> Color:
	var h := fposmod(world.hour, 24.0)
	var keys := [[0.0, NIGHT_LIGHT], [5.0, NIGHT_LIGHT], [6.5, DAWN_LIGHT], [8.5, Color.WHITE],
		[17.0, Color.WHITE], [19.0, DUSK_LIGHT], [20.5, NIGHT_LIGHT], [24.0, NIGHT_LIGHT]]
	for i in keys.size() - 1:
		if h <= keys[i + 1][0]:
			var t: float = (h - keys[i][0]) / (keys[i + 1][0] - keys[i][0])
			return (keys[i][1] as Color).lerp(keys[i + 1][1], t)
	return NIGHT_LIGHT


## How dark it is, from 0 by day to 1 at night: when the lamps are lit.
func _night() -> float:
	return clampf((1.0 - _daylight().b * 0.5 - _daylight().g * 0.5) / (1.0 - (NIGHT_LIGHT.b + NIGHT_LIGHT.g) * 0.5), 0.0, 1.0)


## Screen pixels per sprite pixel: a little bigger as you zoom in, in half steps so the
## pixel art stays even.
func _sprite_px() -> float:
	return clampf(round(cam_scale * SPRITE_PIXEL / 1.125 * 2.0) / 2.0, 1.5, 3.5)


## Select map ambience and the company's movement loop from read-only campaign facts.
func _refresh_travel_presentation() -> void:
	_travel_context = TravelPresentation.context(world, GameState.army)
	if _travel_context.is_empty():
		Sound.set_loop("")
		Sound.set_movement_loop("")
		return
	Sound.set_loop(String(_travel_context["ambience"]))
	var contact := String(_travel_context["movement_contact"])
	Sound.set_movement_loop("hooves" if contact == "cavalry" else ("footsteps" if contact == "foot" else ""))


## Leave evenly spaced contact behind actual movement. This reads the party position after
## the world advances; it cannot change travel speed, pathing or campaign time.
func _update_travel_contact(delta: float) -> void:
	for mark in _travel_marks:
		mark["age"] = float(mark["age"]) + delta
	_travel_marks = _travel_marks.filter(func(mark):
		return float(mark["age"]) < (1.05 if String(mark["kind"]) == "wake" else 1.2))
	if Sound.reduced_motion or not Sound.illustrations_enabled or _travel_context.is_empty():
		_travel_marks.clear()
		_contact_position = Vector2(INF, INF)
		_contact_distance = 0.0
		return
	var kind := String(_travel_context["movement_contact"])
	var pos: Vector2 = _travel_context["position"]
	if kind == "none":
		_contact_position = pos
		_contact_distance = 0.0
		_contact_kind = kind
		return
	if not _contact_position.is_finite() or _contact_kind != kind:
		_contact_position = pos
		_contact_distance = 0.0
		_contact_kind = kind
		return
	var moved := _contact_position.distance_to(pos)
	if moved <= 0.001 or moved > 90.0:
		_contact_position = pos
		return
	var direction := (_contact_position - pos).normalized()
	var spacing := 5.0 if kind == "wake" else (7.0 if kind == "cavalry" else 9.0)
	_contact_distance += moved
	var count := mini(6, int(_contact_distance / spacing))
	for k in count:
		_travel_marks.append({"pos": pos + direction * (float(k) * spacing + 2.0), "age": 0.0,
			"kind": kind, "direction": direction, "surface": String(_travel_context["surface"]),
			"realm": String(_travel_context["realm"])})
	if count > 0:
		_contact_distance = fmod(_contact_distance, spacing)
	if _travel_marks.size() > 72:
		_travel_marks = _travel_marks.slice(_travel_marks.size() - 72)
	_contact_position = pos


func _contact_color(mark: Dictionary) -> Color:
	if String(mark.get("kind", "")) == "wake":
		return Color(0.72, 0.9, 0.96, 0.52)
	if String(mark.get("surface", "")) == "woods":
		return Color(0.63, 0.68, 0.49, 0.38)
	if String(mark.get("realm", "")) == "kharzan":
		return Color(0.88, 0.75, 0.5, 0.45)
	return Color(0.78, 0.7, 0.54, 0.38)


# ---------------------------------------------------------------- drawing

## Settlements and parties, front to back by how far down the map they stand.
func _draw() -> void:
	if world == null:
		return
	var px := _sprite_px()
	for mark in _travel_marks:
		var age: float = mark["age"]
		var kind := String(mark["kind"])
		var fade := 1.0 - age / (1.05 if kind == "wake" else 1.2)
		var color := _contact_color(mark)
		color.a *= fade
		var at := _to_screen(mark["pos"])
		var direction: Vector2 = mark["direction"]
		if kind == "wake":
			var side := Vector2(-direction.y, direction.x) * (3.0 + age * 2.0) * px
			var tail := direction * (9.0 + age * 8.0) * px
			draw_line(at + side, at + tail + side * 1.5, color, 2.0)
			draw_line(at - side, at + tail - side * 1.5, color, 2.0)
		elif kind == "foot":
			var side := Vector2(-direction.y, direction.x) * 2.2 * px
			draw_circle(at + side, (1.2 + age * 1.6) * px, color)
			draw_circle(at - side + direction * 2.0 * px, (1.0 + age * 1.4) * px, color)
		else:
			draw_circle(at + Vector2(0, -2), (2.0 + age * 5.0) * px * 0.5, color)
	var things := []
	for id in Data.SETTLEMENTS:
		things.append({"y": Data.pos(id).y, "settlement": id})
	# A party at a settlement stands in front of it, not behind its walls.
	for b in world.bands():
		things.append({"y": world.party_pos(b).y + 0.25, "band": b})
	for lp in world.visible_lord_parties():
		things.append({"y": world.party_pos(lp).y + 0.25, "lord": lp})
	things.append({"y": world.party_pos(world.player()).y + 0.5, "player": true})
	things.sort_custom(func(a, b): return a["y"] < b["y"])
	for t in things:
		if t.has("settlement"):
			_draw_settlement(t["settlement"], px)
		elif t.has("band"):
			_draw_party(t["band"], "bandits", Color.WHITE, px)
		elif t.has("lord"):
			_draw_party(t["lord"], "lord", Cultures.color(Data.culture_of(t["lord"].faction)), px)
		else:
			_draw_party(world.player(), "rider", Cultures.color(world.culture), px)
	_draw_sieges(px)
	_draw_aftermath(px)
	_draw_wedding(px)
	_draw_gatherings(px)
	_draw_muster(px)


## Your banners gathering: a red ring of spears around the muster.
func _draw_muster(px: float) -> void:
	if GameState.muster.is_empty():
		return
	var place := String(GameState.muster.get("place", ""))
	if not Data.SETTLEMENTS.has(place):
		return
	var c := _to_screen(Data.pos(place))
	var pulse := 0.0 if Style.motion_reduced() else 0.5 + 0.5 * sin(_clock * 2.0)
	draw_circle(c, 38.0 * px, Color(Style.ENEMY, 0.08))
	draw_arc(c, 34.0 * px, 0.0, TAU, 48, Color(0, 0, 0, 0.5), 5.0 * px)
	draw_arc(c, 34.0 * px, 0.0, TAU, 48, Style.ENEMY_LIGHT, 2.5 * px)
	for i in 10:
		var a := TAU * float(i) / 10.0
		var at := c + Vector2.from_angle(a) * 34.0 * px
		draw_line(at, at + Vector2.from_angle(a) * (6.0 + pulse * 2.0) * px, Style.ENEMY_LIGHT, 2.0 * px)


## A gold ring around the place your wedding will be held, while it's planned there.
func _draw_wedding(px: float) -> void:
	var place := _wedding_place()
	if place == "":
		return
	var c := _to_screen(Data.pos(place))
	var ready := String(GameState.wedding().get("state", "")) == "ready"
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 400.0) if ready and not Style.motion_reduced() else 0.0
	draw_arc(c, 30.0 * px, 0.0, TAU, 48, Color(0, 0, 0, 0.5), 5.0 * px)
	draw_arc(c, 30.0 * px, 0.0, TAU, 48, Color("f3d27a"), 2.5 * px)
	if ready:
		draw_arc(c, (34.0 + pulse * 4.0) * px, 0.0, TAU, 48, Color(Style.BRASS, 0.6 - pulse * 0.4), 2.0 * px)


## Lantern light around a hall where lords gather: a warm pool and a ring of lanterns,
## swaying while the gathering is on.
func _draw_gatherings(px: float) -> void:
	for g in world.gatherings:
		var c := _to_screen(Data.pos(String(g["place"])))
		var on: bool = world.gathering_on(g)
		var sway := 0.0 if Style.motion_reduced() else _clock * 1.4
		draw_circle(c, 40.0 * px, Color(1.0, 0.7, 0.28, 0.10 if on else 0.06))
		draw_circle(c, 26.0 * px, Color(1.0, 0.75, 0.3, 0.10 if on else 0.05))
		for i in 8:
			var a := TAU * float(i) / 8.0 + sway * 0.15
			var at := c + Vector2.from_angle(a) * 30.0 * px
			var flicker := 0.75 + 0.25 * sin(sway * 3.0 + float(i) * 1.7) if on else 0.7
			draw_circle(at, 4.2 * px, Color(0, 0, 0, 0.45))
			draw_circle(at, 3.0 * px, Color(1.0, 0.8, 0.42, flicker))
			draw_circle(at, 1.4 * px, Color(1.0, 0.95, 0.75, flicker))


## "Feast · from tomorrow · 6 lords" for the plate over a gathering.
func _gathering_plate(g: Dictionary) -> String:
	var night: int = world.gathering_night(g)
	var when := ""
	if night > 0:
		when = "night %d of 3" % night
	else:
		var day := int(float(g["starts_hour"]) / 24.0)
		var today := int(world.hour / 24.0)
		when = "from dusk" if day == today else ("from tomorrow" if day == today + 1 else "from day %d" % (day + 1))
	var title := Gatherings.upper_first(String(g["name"]))
	if GameState.gathering_barred(g):
		return "%s · closed to you" % title
	var n: int = GameState.gathering_lords(g).size() if world.gathering_on(g) else world.gathering_guests(g).size()
	if n == 0:
		return "%s · %s" % [title, when]
	return "%s · %s · %d lord%s" % [title, when, n, "" if n == 1 else "s"]


## Where the planned wedding is (while it's being made ready or is ready), or "".
func _wedding_place() -> String:
	if not GameState.wedding_active():
		return ""
	var w: Dictionary = GameState.wedding()
	if not (String(w["state"]) in ["preparing", "ready"]):
		return ""
	var place := String(w.get("place", ""))
	return place if Data.SETTLEMENTS.has(place) else ""


## A siege ring and the besiegers' tents around every settlement under siege, in the
## besieging realm's colors, with a storm badge. The one siege mark on the map.
func _draw_sieges(px: float) -> void:
	for army in world.campaign_armies:
		if String(army.get("state", "")) != "besieging":
			continue
		var id := String(army["target"])
		if not Data.SETTLEMENTS.has(id):
			continue
		var c := _to_screen(Data.pos(id))
		var color: Color = Data.crown_color if String(army["realm"]) == Data.CROWN else Cultures.color(Data.culture_of(String(army["realm"])))
		var r := 34.0 * px
		# a broken ring: the lines drawn around the walls
		for i in 12:
			var a0 := float(i) / 12.0 * TAU
			draw_arc(c, r, a0, a0 + TAU / 24.0, 6, Color(0, 0, 0, 0.55), 5.0 * px)
			draw_arc(c, r, a0, a0 + TAU / 24.0, 6, color, 2.5 * px)
		# the besiegers' camp: a few tents outside the ring
		for i in 4:
			var t := c + Vector2.from_angle(PI * 0.15 + float(i) * TAU / 4.0) * (r + 9.0 * px)
			draw_colored_polygon(PackedVector2Array([t + Vector2(-5, 3) * px, t + Vector2(0, -5) * px, t + Vector2(5, 3) * px]), color.lightened(0.25))
			draw_line(t + Vector2(-5, 3) * px, t + Vector2(5, 3) * px, Color(0, 0, 0, 0.6), 1.5 * px)
		# The storm badge: this place is under siege, readable at any zoom.
		var at := c + Vector2(-r * 0.8, -r * 0.95)
		var br := maxf(11.0, 7.0 * px)
		draw_circle(at, br + 2.0, Color(0, 0, 0, 0.6))
		draw_circle(at, br, Style.ENEMY_DARK)
		draw_arc(at, br, 0.0, TAU, 24, color.lightened(0.3), 2.0)
		var storm := Widgets.icon("storm")
		if storm != null:
			draw_texture_rect(storm, Rect2(at - Vector2(br, br) * 0.7, Vector2(br, br) * 1.4), false, Color.WHITE)


## A few days' aftermath beside the places it touched: crossed blades where a battle was
## fought, a fresh banner where a place changed hands. They fade, then vanish.
func _draw_aftermath(px: float) -> void:
	for a in world.aftermath():
		var at := _to_screen(Data.pos(String(a["place"]))) + Vector2(22.0, -26.0) * px
		var alpha: float = 0.35 + 0.65 * float(a["fade"])
		if String(a["kind"]) == "battle":
			for side in [-1.0, 1.0]:
				var tip := at + Vector2(-7.0 * side, -7.0) * px
				var hilt := at + Vector2(6.0 * side, 6.0) * px
				draw_line(tip, hilt, Color(0, 0, 0, 0.6 * alpha), 4.0 * px)
				draw_line(tip, hilt, Color(Style.ENEMY_LIGHT, alpha), 2.0 * px)
		else:
			at += Vector2(10.0, 0) * px
			draw_line(at + Vector2(0, 8) * px, at + Vector2(0, -10) * px, Color(0.25, 0.18, 0.1, alpha), 2.0 * px)
			draw_colored_polygon(PackedVector2Array([at + Vector2(0, -10) * px, at + Vector2(11, -6) * px, at + Vector2(0, -2) * px]),
				Color(Style.BRASS, alpha))


func _draw_settlement(id: String, px: float) -> void:
	var s := Data.settlement(id)
	var c := _to_screen(s["pos"])
	# Built by its own people, flying its holder's colors.
	var culture := Data.culture_of(s["faction"])
	var colors := Data.crown_color if world.owner_of(id) == Data.CROWN else Cultures.color(Data.culture_of(world.owner_of(id)))
	var sprite := "%s/%s" % [culture, s["type"]]
	var w: float = MapArt.size(sprite).x * px
	draw_set_transform(c + Vector2(0, 2), 0.0, Vector2(1.0, 0.32))
	draw_circle(Vector2.ZERO, w * 0.5, Color(0, 0, 0, 0.22))
	if id == _selected:
		draw_arc(Vector2.ZERO, w * 0.6, 0.0, TAU, 40, Style.BRASS, 3.0 / 0.32)
	draw_set_transform(c, 0.0, Vector2(px, px))
	var presentation := TravelPresentation.settlement_state(world, id)
	var condition := String(presentation.get("condition", "healthy"))
	var tint := BURNT if condition == "damaged" else (Color("c8b58f") if condition == "recovering" else Color.WHITE)
	draw_texture(MapArt.texture(sprite, 0, colors), -MapArt.pivot(sprite), tint)
	if condition == "damaged":
		# Charred ruins: smoke plumes and glowing embers rising
		for k in 3:
			var rise := fmod(_clock * 0.6 + k * 0.33, 1.0)
			draw_circle(Vector2(-3.0 + k * 3.0, -10.0 - rise * 14.0), 2.0 + rise * 3.0, Color(0.25, 0.23, 0.22, 0.45 * (1.0 - rise)))
			var ember_rise := fmod(_clock * 1.3 + k * 0.37, 1.0)
			draw_circle(Vector2(-4.0 + k * 4.0 + sin(_clock * 4.0 + k) * 2.0, -8.0 - ember_rise * 16.0), 1.2, Color(1.0, 0.45, 0.1, 0.75 * (1.0 - ember_rise)))
	elif condition == "recovering":
		# Pale new timbers distinguish rebuilding from an actively ruined village.
		draw_line(Vector2(-9, -12), Vector2(-9, 2), Color("c59555"), 2.0)
		draw_line(Vector2(9, -12), Vector2(9, 2), Color("c59555"), 2.0)
		draw_line(Vector2(-11, -7), Vector2(11, -7), Color("d5ae6c"), 2.0)
	if String(presentation.get("garrison", "none")) == "thin" and String(s["type"]) != Data.VILLAGE:
		draw_arc(Vector2.ZERO, MapArt.size(sprite).x * 0.58, 0.18, PI - 0.18, 14, Style.ENEMY_LIGHT, 1.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Castles and towns fly their holder's banner.
	if String(s["type"]) != Data.VILLAGE and condition != "damaged":
		var tall: float = MapArt.size(sprite).y * px
		var holder := String(world.owner_of(id))
		Heraldry.realm_banner(self, holder if Heraldry.REALM_SIZES.has(holder) else "bandits",
			Rect2(c + Vector2(w * 0.22, -tall - 10.0 * px), Vector2(9.0, 13.0) * px))


## A party on the road: your rider under your banner, or a bandit band. Walks while it
## moves, facing the way it's going.
func _draw_party(p, sprite: String, color: Color, px: float) -> void:
	var at: Vector2 = world.party_pos(p)
	var base := _to_screen(at)
	var army: Dictionary = world.MarshalArmies.for_party(world, p.id)

	# Calculate troop strength for scaling party presence
	var men := 0
	if p == world.player():
		men = GameState.total_men()
	else:
		for sq in p.army:
			men += int(sq.get("men", 0))
	var strength_scale := 1.0
	if men < 20:
		strength_scale = 0.85
	elif men < 50:
		strength_scale = 1.0
	elif men < 90:
		strength_scale = 1.18
	elif men < 140:
		strength_scale = 1.32
	else:
		strength_scale = 1.45
	# Lords ride their realm's horse with their men marching behind (one per 45 men, up to
	# two), so size is counted rather than scaled; bandits look like their region's outlaws.
	var rides := ""
	if sprite == "lord" or sprite == "rider":
		var culture := String(world.culture) if sprite == "rider" else Data.culture_of(p.faction)
		if MapArt.has("mounted/" + culture):
			rides = culture
			sprite = "mounted/" + culture
			strength_scale = 1.0
	elif sprite == "bandits":
		var kind := "wako" if String(p.name).contains("Wako") else Data.culture_of(p.faction)
		if MapArt.has("outlaws/" + kind):
			sprite = "outlaws/" + kind
			strength_scale = 1.0

	# Fading bandits at wide zoom
	var party_alpha := 1.0
	if sprite == "bandits":
		party_alpha = clampf((px - 1.4) / (2.2 - 1.4), 0.25, 1.0)

	var moving: bool = p.moving() and (world.busy() or p != world.player())
	var facing := 1.0
	if p.moving() and Data.pos(p.next).x < at.x:
		facing = -1.0
	var frame := int(_clock * 6.0) % 2 if moving else 0
	var mine := sprite == "rider"
	# A marshal's host is drawn as one: the marshal under the realm's great standard, with
	# the column behind, and a badge for what the army is doing.
	var host: bool = not army.is_empty() and army["state"] != "gathering" and p.id == int(army["leader"])
	if host:
		var host_sprite := "marshal/" + Data.culture_of(p.faction)
		if MapArt.has(host_sprite):
			sprite = host_sprite
			rides = ""

	# Shadow on ground
	draw_set_transform(base + Vector2(0, 2), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 8.0 * px * strength_scale, Color(0, 0, 0, 0.28 * party_alpha))
	if mine:
		draw_arc(Vector2.ZERO, 9.5 * px * strength_scale, 0.0, TAU, 32, Style.BRASS, 2.5 / 0.35)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Marshal army rings or bandit diamond
	if not army.is_empty() and army["state"] != "gathering":
		if p.id == int(army["leader"]):
			draw_arc(base, 20 * px * strength_scale, 0, TAU, 32, Style.BRASS, 3.0)
			draw_arc(base, 25 * px * strength_scale, 0, TAU, 32, Color(Style.BRASS, 0.55), 2.0)
		else:
			# Attached army cohort member: grouped cohort ring
			draw_arc(base, 14 * px * strength_scale, 0, TAU, 24, Color(Style.BRASS, 0.4), 1.5)
	elif sprite == "bandits" or sprite.begins_with("outlaws/"):
		var r := 15.0 * px * strength_scale
		var b_col := Style.ENEMY_LIGHT
		b_col.a *= party_alpha
		draw_polyline(PackedVector2Array([base + Vector2(0, -r), base + Vector2(r, 0), base + Vector2(0, r),
			base + Vector2(-r, 0), base + Vector2(0, -r)]), b_col, 2.0)

	# A hostile lord near you: how far he sees, and if he's after you, the line of the chase.
	var chasing := false
	if p.kind == WorldSim.LORD and army.is_empty() and world.relation_to_player(p.faction) == "hostile":
		var me: Vector2 = world.party_pos(world.player())
		var d: float = at.distance_to(me)
		chasing = String(world.lord_of(p).get("job", "")) == "chase"
		if d < WorldSim.SIGHT * 2.0 or chasing:
			var r: float = _to_screen(at + Vector2(WorldSim.SIGHT, 0)).x - base.x
			var fade := clampf(1.0 - (d - WorldSim.SIGHT) / WorldSim.SIGHT, 0.15, 1.0)
			draw_arc(base, r, 0.0, TAU, 64, Color(Style.ENEMY, 0.22 * fade), 2.0)
		if chasing:
			var to := _to_screen(me)
			var dir := (to - base)
			var length := dir.length()
			if length > 1.0:
				dir /= length
				var step := 12.0 * px
				var t := fmod(_clock * 30.0, step * 2.0)
				while t < length - 10.0 * px:
					draw_line(base + dir * t, base + dir * minf(t + step, length - 10.0 * px), Color(Style.ENEMY_LIGHT, 0.85), 2.5)
					t += step * 2.0
	if host:
		_draw_army_badge(base + Vector2(0, -34.0) * px * strength_scale, String(army["state"]), px)
	if rides != "":
		# His men behind him, then the lord, then the realm's banner by his lance (a
		# Ryumon lord's is the flag on his back).
		var followers := mini(2, men / 45)
		for i in range(followers, 0, -1):
			_draw_party_sprite(base + Vector2(-facing * (10.0 + 9.0 * (i - 1)) * px, 0.0), "follower/" + rides, frame, color, px, facing, 1.0, party_alpha)
		_draw_party_sprite(base, sprite, frame, color, px, facing, 1.0, party_alpha)
		var realm := _party_realm(p)
		if rides != "ryumon" or realm == Data.CROWN:
			var bx := 5.0 if facing > 0.0 else -13.0
			Heraldry.realm_banner(self, realm, Rect2(base + Vector2(bx, -28.0) * px, Vector2(8.0, 13.0) * px))
	elif sprite.begins_with("outlaws/"):
		_draw_party_sprite(base, sprite, frame, color, px, facing, 1.0, party_alpha)
		if p.raiding:
			# Torches and smoke over a raid.
			for k in 3:
				var rise := fmod(_clock * 0.5 + k * 0.33, 1.0)
				draw_circle(base + Vector2(-4.0 + k * 4.0, -18.0 - rise * 14.0) * px, (2.0 + rise * 3.0) * px, Color(0.3, 0.28, 0.27, 0.5 * (1.0 - rise) * party_alpha))
			for tx in [-7.0, 6.0]:
				var flick := 0.6 + 0.4 * sin(_clock * 13.0 + tx)
				draw_line(base + Vector2(tx, -6.0) * px, base + Vector2(tx, -12.0) * px, Color(0.38, 0.24, 0.12, party_alpha), 1.2 * px)
				draw_circle(base + Vector2(tx, -13.0) * px, 1.8 * px * flick, Color(1.0, 0.55, 0.15, party_alpha))
		elif not moving:
			# Lying in wait round a fire.
			_draw_party_sprite(base + Vector2(0, 2.0) * px, "campfire", int(_clock * 5.0) % 2, color, px, 1.0, 1.0, party_alpha)
	else:
		# Heraldic banner / pennant by owner (a host carries its own great standard)
		if not (host and sprite.begins_with("marshal/")):
			_draw_pennant(base, 7.0 * px * facing, px, strength_scale, color, party_alpha, facing, p)
		_draw_party_sprite(base, sprite, frame, color, px, facing, strength_scale, party_alpha)
	if chasing:
		# A red "!" over the hunter, bobbing.
		var mark := base + Vector2(0, (-30.0 - 3.0 * sin(_clock * 6.0)) * px * strength_scale)
		draw_circle(mark, 8.0 * px, Style.ENEMY_DARK)
		draw_arc(mark, 8.0 * px, 0.0, TAU, 20, Style.ENEMY_LIGHT, 2.0)
		draw_line(mark + Vector2(0, -4.5) * px, mark + Vector2(0, 1.5) * px, Color.WHITE, 2.4 * px)
		draw_circle(mark + Vector2(0, 4.2) * px, 1.3 * px, Color.WHITE)


## What a marshal's army is about, in a small badge: marching on, besieging, or going home.
## The banner a party flies: its realm's, or for you, your crown or your people's realm.
func _party_realm(p) -> String:
	if p == world.player():
		return Data.CROWN if GameState.is_crowned() else Heraldry.realm_of_culture(String(world.culture))
	var realm := String(p.faction)
	return realm if Heraldry.REALM_SIZES.has(realm) else Heraldry.realm_of_culture(Data.culture_of(realm))


## How a party's men compare with yours, in the kit's marks: [shape, colour, word]. ▲ they
## are weaker (good for you), ◆ about even, ▼ stronger. The plates over parties and the
## men chips on sheets share it, so the marks mean one thing everywhere.
func _odds_mark(men: int) -> Array:
	var mine := maxf(1.0, float(GameState.total_men()))
	var ratio := float(men) / mine
	if ratio > 1.25:
		return ["▼", Style.MORALE_LOW, "Stronger than you"]
	if ratio < 0.8:
		return ["▲", Style.MORALE_HIGH, "Weaker than you"]
	return ["◆", Style.MORALE_MID, "Evenly matched"]


## The plate chip's fill for a mark: a lighter tint of its colour, under dark ink.
func _strength_mark(men: int) -> Array:
	var mark := _odds_mark(men)
	return [mark[0], Color(mark[1]).lightened(0.45)]


func _draw_army_badge(at: Vector2, state: String, px: float) -> void:
	_paint_army_badge(self, at, state, px)


## What a marshal's army is about, as a pictogram: marching on, going home, sitting before
## walls, or gathering. Drawn on the map over the marshal, and on the army's sheet.
func _paint_army_badge(ci: CanvasItem, at: Vector2, state: String, px: float) -> void:
	var r := 7.0 * px
	ci.draw_circle(at, r + 1.5 * px, Color(0, 0, 0, 0.6))
	ci.draw_circle(at, r, Style.NIGHT)
	ci.draw_arc(at, r, 0.0, TAU, 20, Style.BRASS, 1.5 * px)
	var c := Style.BRASS
	match state:
		"marching":
			ci.draw_polyline(PackedVector2Array([at + Vector2(-3, -4) * px, at + Vector2(2, 0) * px, at + Vector2(-3, 4) * px]), c, 1.8 * px)
		"returning":
			ci.draw_polyline(PackedVector2Array([at + Vector2(3, -4) * px, at + Vector2(-2, 0) * px, at + Vector2(3, 4) * px]), c, 1.8 * px)
		"besieging":
			# a little tower: the walls they sit before
			ci.draw_rect(Rect2(at + Vector2(-3.5, -1.5) * px, Vector2(7, 5) * px), c)
			for x in [-3.5, -0.5, 2.5]:
				ci.draw_rect(Rect2(at + Vector2(x, -4) * px, Vector2(1.5, 2) * px), c)
		_:
			ci.draw_circle(at, 2.0 * px, c)


func _draw_pennant(base: Vector2, pole_x: float, px: float, strength_scale: float, color: Color, party_alpha: float, facing: float, p) -> void:
	var pole_top := base + Vector2(pole_x, -14.0 * px * strength_scale)
	var pole_bot := base + Vector2(pole_x, 1.0 * px)
	var pole_col := Color(0.25, 0.22, 0.18, party_alpha)
	draw_line(pole_bot, pole_top, pole_col, 1.5)
	# Close enough to see, a party carries its realm's own banner; far off, a pennant.
	var realm := "bandits" if p.kind == WorldSim.BAND else String(p.faction)
	if px >= 1.6 and party_alpha >= 0.99 and Heraldry.REALM_SIZES.has(realm):
		var h := 15.0 * px * strength_scale
		Heraldry.realm_banner(self, realm, Rect2(base + Vector2(pole_x - 1.5 * px, -h), Vector2(h * 0.72, h)))
		return
	var flutter := sin(_clock * 7.0 + float(p.id)) * 2.0 * px
	var flag_pts := PackedVector2Array([
		pole_top,
		pole_top + Vector2(9.0 * px * facing + flutter * facing, 3.0 * px),
		pole_top + Vector2(0, 6.5 * px)
	])
	var flag_col := color
	flag_col.a *= party_alpha
	draw_colored_polygon(flag_pts, flag_col)
	draw_polyline(flag_pts, Color(0.12, 0.1, 0.08, 0.8 * party_alpha), 1.0)


func _draw_party_sprite(base: Vector2, sprite: String, frame: int, color: Color, px: float, facing: float, strength_scale: float, party_alpha: float) -> void:
	draw_set_transform(base, 0.0, Vector2(px * facing * strength_scale, px * strength_scale))
	var tex_col := Color(1, 1, 1, party_alpha)
	draw_texture(MapArt.texture(sprite, frame, color), -MapArt.pivot(sprite), tex_col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Above the light of the hour: lamps lit at night, your route, and every name.
func _draw_labels() -> void:
	var px := _sprite_px()
	var night := _night()
	if night > 0.02:
		for id in Data.SETTLEMENTS:
			var c := _to_screen(Data.pos(id)) + Vector2(0, -8) * px
			labels.draw_circle(c, 26.0 * px * 0.5, Color(LAMP, 0.10 * night))
			labels.draw_circle(c, 14.0 * px * 0.5, Color(LAMP, 0.14 * night))
	_draw_route()
	_taken.clear()
	for id in Data.SETTLEMENTS:
		var s := Data.settlement(id)
		var size := Style.SMALL + 2 if s["type"] != Data.VILLAGE else Style.SMALL
		_name_plate(_to_screen(s["pos"]) + Vector2(0, 8.0 + px * 2.0), String(s["name"]), size,
			Style.BRASS if s["type"] == Data.TOWN else Style.TEXT)
	var wp := _wedding_place()
	if wp != "":
		var ready := String(GameState.wedding()["state"]) == "ready"
		var over := _to_screen(Data.pos(wp)) + Vector2(0, -34.0 * px - 18.0)
		if ready:
			# Ready: a pulsing badge with the rings, nothing to read.
			_rings_badge(over + Vector2(0, 14.0))
		else:
			_icon_plate(over, [{"icon": "rings"}, {"icon": "clock"}, {"text": GameState._when_text(float(GameState.wedding()["ready_hour"]))}],
				Color("f3d27a"), Color("8a6a2a"))
	for g in world.gatherings:
		var lift := 34.0 * px + 18.0 + (40.0 if String(g["place"]) == wp else 0.0)
		var at := _to_screen(Data.pos(String(g["place"]))) + Vector2(0, -lift)
		if GameState.gathering_barred(g):
			_icon_plate(at, [{"icon": "lock"}, {"text": _gathering_plate(g)}], Style.ENEMY_LIGHT, Style.ENEMY_LIGHT)
		else:
			_icon_plate(at, _gathering_parts(g), Color("f3d891"), Style.BRASS)
	# Parties' plates step up out of the way of any name already placed.
	for b in world.bands():
		if px >= 2.0:
			var b_col := Color("e8d9c0")
			if px < 2.5:
				b_col.a = clampf((px - 2.0) / 0.5, 0.3, 1.0)
			_name_plate(_to_screen(world.party_pos(b)) + Vector2(0, -21.0 * px - 6.0), b.name, PARTY_PLATE, b_col,
				Color(Style.ENEMY_LIGHT, b_col.a * 0.8), world.men_of(b.army), true)
	# Lords' names only once you're looking closely, or the map drowns in them. The plate
	# shows the name they go by; the full title is on their sheet.
	if px >= LORD_NAMES_PX:
		for lp in world.visible_lord_parties():
			var army: Dictionary = world.MarshalArmies.for_party(world, lp.id)
			var ink := Cultures.color(Data.culture_of(lp.faction)).lightened(0.6)
			if not army.is_empty() and army["state"] != "gathering":
				if lp.id != int(army["leader"]):
					# The brass ring groups a host's lords; only the marshal carries a plate.
					continue
				var total_men := 0
				for m in world.MarshalArmies.members(world, army):
					total_men += world.men_of(m.army)
				_name_plate(_to_screen(world.party_pos(lp)) + Vector2(0, -25.0 * px - 6.0), "Marshal %s" % short_lord_name(lp.name), PARTY_PLATE,
					ink, Style.BRASS, total_men, true)
			else:
				var rel := String(world.relation_to_player(lp.faction))
				var edge := Style.ENEMY_LIGHT if rel == "hostile" else (Style.BRASS if rel in ["friendly", "allied", "employer"] else Color("6d7699"))
				_name_plate(_to_screen(world.party_pos(lp)) + Vector2(0, -32.0 * px - 6.0), short_lord_name(lp.name), PARTY_PLATE,
					ink, edge, world.men_of(lp.army), true)
				# Bound for a gathering or your muster: say so under the name.
				var l: Dictionary = world.lord_of(lp)
				if lp.moving() and String(l.get("job", "")) == "gather" and int(l.get("gather_id", 0)) > 0 and not _taken.is_empty():
					var placed: Rect2 = _taken[_taken.size() - 1]
					var feast: Dictionary = world.gathering_by_id(int(l["gather_id"]))
					_icon_plate(Vector2(placed.get_center().x, placed.end.y + 2.0), [{"icon": "ride"}, {"icon": _gathering_icon(feast)}],
						Color("f3d891"), Color("8a6a2a"), false)
				elif lp.moving() and String(l.get("job", "")) == "muster" and not _taken.is_empty():
					var placed: Rect2 = _taken[_taken.size() - 1]
					_icon_plate(Vector2(placed.get_center().x, placed.end.y + 2.0), [{"icon": "ride"}, {"icon": "crown"}],
						Color("f3b0a0"), Style.ENEMY, false)


## Text size of a party's name plate: the same as a village's name.
const PARTY_PLATE := Style.SMALL
## Words that come before a lord's own name, dropped on the map's plates.
const LORD_TITLES := ["Lord", "Lady", "Ser", "Sir", "Dame", "Emir", "Emira", "Bey", "Amir", "Sheikh", "Daimyo", "Lady-Daimyo", "Tono", "Hime"]
## Plates already placed this frame, so later ones can step out of their way.
var _taken: Array[Rect2] = []


## The name a lord goes by on the map: "Lord Ansel Brightwater" is "Ansel". Rulers keep
## their title ("King Aldwin"), which is short already.
static func short_lord_name(full: String) -> String:
	var words := full.split(" ", false)
	if words.size() >= 2 and LORD_TITLES.has(words[0]):
		return words[1]
	if words.size() >= 3:
		return "%s %s" % [words[0], words[1]]
	return full


## A name on a dark plate, centered on `at` (the plate's top edge).
## `edge` rings the plate (red for enemies, brass for friends); `men` >= 0 adds a chip
## with how they compare with you.
func _name_plate(at: Vector2, text: String, base_size: int, color: Color, edge: Color = Color(0, 0, 0, 0), men: int = -1, dodge: bool = false) -> void:
	var size := Style.text_size(maxi(base_size, Style.SMALL))
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var chip_text := ""
	var chip_w := 0.0
	var mark: Array = []
	var chip_size := Style.text_size(Style.SMALL)
	if men >= 0:
		mark = _strength_mark(men)
		chip_text = "%s %d" % [mark[0], men]
		chip_w = font.get_string_size(chip_text, HORIZONTAL_ALIGNMENT_LEFT, -1, chip_size).x + 14.0
	var rect := Rect2(at + Vector2(-(w + chip_w) * 0.5 - 8.0, 0.0), Vector2(w + chip_w + 16.0 + (6.0 if chip_w > 0.0 else 0.0), size + 8.0))
	if dodge:
		for attempt in 4:
			var hit := false
			for other in _taken:
				if other.grow(2.0).intersects(rect):
					hit = true
					break
			if not hit:
				break
			rect.position.y -= rect.size.y + 4.0
	_taken.append(rect)
	if _plate == null:
		_plate = Style.box(Color(0.06, 0.07, 0.1, 0.62), Color(0, 0, 0, 0), 0, 8)
	if edge.a > 0.0:
		var sb := Style.box(Color(0.06, 0.07, 0.1, 0.78), edge, 2, 8)
		sb.draw(labels.get_canvas_item(), rect)
	else:
		_plate.draw(labels.get_canvas_item(), rect)
	labels.draw_string(font, rect.position + Vector2(8.0, size * 0.92 + 3.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
	if chip_w > 0.0:
		var chip := Rect2(Vector2(rect.end.x - chip_w - 4.0, rect.position.y + 3.0), Vector2(chip_w, rect.size.y - 6.0))
		labels.draw_style_box(Style.box(mark[1], Color(0, 0, 0, 0), 0, int(chip.size.y * 0.5)), chip)
		labels.draw_string(font, chip.position + Vector2(7.0, chip.size.y * 0.5 + chip_size * 0.36), chip_text, HORIZONTAL_ALIGNMENT_LEFT, -1, chip_size, Color("14161f"))


## A plate of icons and words, centred on `at` (its top edge): `parts` are {"icon": key},
## {"text": words} or {"pips": [lit, of]}. Steps out of the way of plates already placed.
func _icon_plate(at: Vector2, parts: Array, color: Color, edge: Color, dodge: bool = true) -> void:
	var size := Style.text_size(Style.SMALL)
	var icon_w := float(size) + 2.0
	var gap := 6.0
	var w := 0.0
	for part in parts:
		if part.has("icon"):
			w += icon_w
		elif part.has("text"):
			w += font.get_string_size(String(part["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		elif part.has("pips"):
			w += float(int(part["pips"][1])) * 12.0
		w += gap
	w -= gap
	var rect := Rect2(at + Vector2(-w * 0.5 - 8.0, 0.0), Vector2(w + 16.0, size + 8.0))
	for attempt in (4 if dodge else 0):
		var hit := false
		for other in _taken:
			if other.grow(2.0).intersects(rect):
				hit = true
				break
		if not hit:
			break
		rect.position.y -= rect.size.y + 4.0
	_taken.append(rect)
	Style.box(Color(0.06, 0.07, 0.1, 0.8), edge, 2, 8).draw(labels.get_canvas_item(), rect)
	var x := rect.position.x + 8.0
	var mid := rect.position.y + rect.size.y * 0.5
	for part in parts:
		if part.has("icon"):
			var tex := Widgets.icon(String(part["icon"]))
			if tex != null:
				labels.draw_texture_rect(tex, Rect2(Vector2(x, mid - icon_w * 0.5), Vector2(icon_w, icon_w)), false, color)
			x += icon_w
		elif part.has("text"):
			var t := String(part["text"])
			labels.draw_string(font, Vector2(x, mid + size * 0.36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
			x += font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		elif part.has("pips"):
			for i in int(part["pips"][1]):
				var lit: bool = i < int(part["pips"][0])
				var pc := Vector2(x + 6.0 + i * 12.0, mid)
				if lit:
					labels.draw_circle(pc, 4.5, color)
				else:
					labels.draw_arc(pc, 4.0, 0.0, TAU, 12, Color(color, 0.6), 1.5)
			x += float(int(part["pips"][1])) * 12.0
		x += gap


## A gathering over its hall, as marks: its kind, then the nights as pips while it's on
## (or a clock and when it starts), then the lords there.
func _gathering_parts(g: Dictionary) -> Array:
	var parts: Array = [{"icon": _gathering_icon(g)}]
	var night: int = world.gathering_night(g)
	if night > 0:
		parts.append({"pips": [night, 3]})
	else:
		var day := int(float(g["starts_hour"]) / 24.0)
		var today := int(world.hour / 24.0)
		parts.append({"icon": "clock"})
		parts.append({"text": "dusk" if day == today else ("tomorrow" if day == today + 1 else "day %d" % (day + 1))})
	var n: int = GameState.gathering_lords(g).size() if world.gathering_on(g) else world.gathering_guests(g).size()
	if n > 0:
		parts.append({"icon": "men"})
		parts.append({"text": str(n)})
	return parts


## The icon for a kind of gathering: a cup for a feast, the dance, crossed blades for the
## lists.
func _gathering_icon(g: Dictionary) -> String:
	match String(g.get("kind", "")):
		Gatherings.DANCE:
			return "dance"
		Gatherings.TOURNEY:
			return "fight"
	return "cup"


## A wedding ready to begin: the rings in a gold badge that pulses.
func _rings_badge(c: Vector2) -> void:
	var pulse := 0.0 if Style.motion_reduced() else 0.5 + 0.5 * sin(Time.get_ticks_msec() / 400.0)
	var r := 18.0 + pulse * 2.0
	labels.draw_circle(c, r + 3.0, Color(0, 0, 0, 0.55))
	labels.draw_circle(c, r, Color("33290f"))
	labels.draw_arc(c, r, 0.0, TAU, 32, Color("f3d27a"), 2.5)
	labels.draw_arc(c, r + 4.0 + pulse * 4.0, 0.0, TAU, 32, Color(Style.BRASS, 0.6 - pulse * 0.4), 2.0)
	var tex := Widgets.icon("rings")
	if tex != null:
		labels.draw_texture_rect(tex, Rect2(c - Vector2(r, r) * 0.68, Vector2(r, r) * 1.36), false, Color("f3d27a"))


## Where you're riding: a gold line through the settlements still ahead.
func _draw_route() -> void:
	var p = world.player()
	if not p.moving():
		return
	var pts := PackedVector2Array([_to_screen(world.party_pos(p)), _to_screen(Data.pos(p.next))])
	for id in p.path:
		pts.append(_to_screen(Data.pos(id)))
	for i in pts.size() - 1:
		labels.draw_dashed_line(pts[i], pts[i + 1], Color(Style.BRASS, 0.85), 4.0, 10.0)
	var end := pts[pts.size() - 1]
	var pulse := 0.5 + 0.5 * sin(_clock * 4.0)
	labels.draw_arc(end, 16.0 + pulse * 6.0, 0.0, TAU, 28, Color(Style.BRASS, 0.9 - pulse * 0.5), 3.0)
