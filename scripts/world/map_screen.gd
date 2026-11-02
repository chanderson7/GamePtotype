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
const Heraldry = preload("res://scripts/ui/heraldry.gd")
const Captains = preload("res://scripts/data/captains.gd")
const Troops = preload("res://scripts/data/troops.gd")
const Art = preload("res://scripts/art/unit_art.gd")
const Widgets = preload("res://scripts/ui/widgets.gd")
const SKY_SHADER = preload("res://shaders/map_sky.gdshader")

const TOP_BAR := 132.0
const RESOURCE_ICON_PATHS := {
	"silver": "res://assets/ui/silver.svg",
	"food": "res://assets/ui/food.svg",
	"renown": "res://assets/ui/renown.svg",
}
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
var clock_label: Label
var resource_buttons := {}
var _resource_icons := {}
var status_label: Label
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
var _banner_title: Label
var _banner_from: Label
var _banner_line: Label
var _banner_seal := Color("8e1f17")
var unread_badge: Label
const LETTER_BANNER_SECONDS := 9.0
var sheet_title: Label
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
	elif GameState.map_notice != "":
		_open_notice(GameState.map_notice)
		GameState.map_notice = ""
	elif world.here() != "":
		_open_here()
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
	_view = Rect2(Vector2(0.0, top), Vector2(vs.x, vs.y - top))
	_clamp_camera()
	_sync_layers()
	queue_redraw()


# ---------------------------------------------------------------- time

func _process(delta: float) -> void:
	# On the way out (no campaign, or the smoke test is done) the screen was never built.
	if world == null or top_panel == null:
		return
	if GameState.desertion_warning != "" and _sheet not in ["encounter", "notice", "warning", "menu"]:
		_open_desertion_warning()
	if GameState.bond_intro_pending() and GameState.desertion_warning == "" and not autoplay and _sheet not in ["encounter", "notice", "warning"]:
		Scenes.go("res://scenes/bond_intro.tscn")
		return
	if autoplay:
		_autoplay()
	_watch_letters(delta)
	# An encounter or a note about the last battle holds the clock until it's answered.
	if world.busy() and not paused and _sheet not in ["encounter", "notice", "menu", "warning", "activity", "recommendation"]:
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
				_open_encounter()
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
	if GameState.desertion_warning != "" and _sheet not in ["encounter", "notice", "warning", "menu"]:
		_open_desertion_warning()
	# Men deserting on the road: say so, and hold the clock while the player reads it.
	if GameState.map_notice != "" and _sheet != "encounter" and _sheet != "notice" and _sheet != "menu" and _sheet != "warning":
		_open_notice(GameState.map_notice, "On the road")
		Sound.play("page")
		GameState.map_notice = ""
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

## Load source SVGs directly when a fresh headless checkout has no editor import cache.
## The packaged game still uses the same files through Godot's normal resource pipeline.
func _resource_icon(key: String) -> Texture2D:
	if _resource_icons.has(key):
		return _resource_icons[key]
	var image := Image.load_from_file(String(RESOURCE_ICON_PATHS.get(key, "")))
	var texture: Texture2D = ImageTexture.create_from_image(image) if image != null and not image.is_empty() else null
	_resource_icons[key] = texture
	return texture


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var hud := Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.theme = Style.make_theme()
	layer.add_child(hud)

	top_panel = PanelContainer.new()
	top_panel.anchor_right = 1.0
	top_panel.offset_bottom = TOP_BAR
	hud.add_child(top_panel)
	var stack_top := VBoxContainer.new()
	stack_top.add_theme_constant_override("separation", 6)
	top_panel.add_child(stack_top)
	# Row one: the day, the purse, food and renown as small pills, and the menu.
	var resource_row := HBoxContainer.new()
	resource_row.add_theme_constant_override("separation", 6)
	stack_top.add_child(resource_row)
	day_icon = TextureRect.new()
	day_icon.custom_minimum_size = Vector2(26, 26)
	day_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	day_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	resource_row.add_child(day_icon)
	clock_label = Style.label("", Style.SMALL, Style.BRASS)
	clock_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clock_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	clock_label.clip_text = true
	clock_label.custom_minimum_size = Vector2(10, 0)
	resource_row.add_child(clock_label)
	for key in ["silver", "food", "renown"]:
		var badge := _button("", _open_resource.bind(key))
		badge.icon = _resource_icon(key)
		badge.expand_icon = true
		badge.add_theme_constant_override("icon_max_width", 24)
		badge.add_theme_font_size_override("font_size", Style.SMALL)
		badge.custom_minimum_size = Vector2(104, 52)
		badge.add_theme_stylebox_override("normal", _pill_box(Style.PANEL))
		badge.add_theme_stylebox_override("hover", _pill_box(Style.PANEL.lightened(0.08)))
		badge.add_theme_stylebox_override("pressed", _pill_box(Style.PANEL.darkened(0.1)))
		resource_buttons[key] = badge
		resource_row.add_child(badge)
	warband_button = _button("", _on_menu)
	warband_button.name = "MenuButton"
	warband_button.tooltip_text = "Menu"
	warband_button.icon = _glyph("menu")
	warband_button.custom_minimum_size = Vector2(56, 52)
	resource_row.add_child(warband_button)
	# Unread letters, counted on the menu button.
	unread_badge = Style.label("", 18, Style.BRASS_INK)
	unread_badge.name = "UnreadBadge"
	unread_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	unread_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var ub := Style.box(Style.BRASS, Color(0, 0, 0, 0), 0, 12)
	unread_badge.add_theme_stylebox_override("normal", ub)
	unread_badge.custom_minimum_size = Vector2(26, 24)
	unread_badge.position = Vector2(30, 0)
	unread_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	unread_badge.visible = false
	warband_button.add_child(unread_badge)
	# Row two: what the company is doing (with how far along), and the goal chip.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	stack_top.add_child(row)
	var status_box := VBoxContainer.new()
	status_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_box.add_theme_constant_override("separation", 3)
	status_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(status_box)
	status_label = Style.label("", Style.SMALL, Style.MUTED)
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

	# In thumb reach at the bottom: the Warband, and the clock's controls.
	bottom_bar = MarginContainer.new()
	bottom_bar.name = "TimeControls"
	bottom_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_bar.offset_top = -96.0
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
	camp.custom_minimum_size = Vector2(150, 64)
	camp.add_theme_stylebox_override("normal", _pill_box(Color(Style.PANEL, 0.94)))
	brow.add_child(camp)
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
	sheet_title = Style.label("", Style.LARGE, Style.TEXT)
	sv.add_child(sheet_title)
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
	sheet_row.columns = 2
	sheet_row.add_theme_constant_override("separation", 10)
	sheet_row.add_theme_constant_override("h_separation", 10)
	sheet_row.add_theme_constant_override("v_separation", 10)
	sv.add_child(sheet_row)


func _button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, Style.TOUCH)
	b.pressed.connect(callback)
	return b


func _show_sheet(kind: String, title: String, body: String, buttons: Array) -> void:
	_sheet = kind
	if bottom_bar != null:
		bottom_bar.visible = false
	sheet_lord_row.visible = false
	for c in sheet_extra.get_children():
		c.queue_free()
	sheet_extra.visible = false
	sheet_title.text = title
	sheet_title.add_theme_color_override("font_color", Style.ENEMY_LIGHT if kind == "warning" else Style.TEXT)
	sheet_body.text = body
	sheet_row.columns = 1 if buttons.size() <= 1 else 2
	for c in sheet_row.get_children():
		c.queue_free()
	for spec in buttons:
		var b := _button(String(spec[0]), spec[1])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		if spec.size() > 2 and spec[2]:
			Style.make_primary(b)
		sheet_row.add_child(b)
	if not sheet_panel.visible:
		sheet_panel.visible = true
		Style.ease_in(sheet_panel)


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


func _close_sheet() -> void:
	_sheet = ""
	if bottom_bar != null:
		bottom_bar.visible = true
	sheet_panel.visible = false


func _open_preview(id: String) -> void:
	var hours: float = world.hours_to(id)
	var sea := ""
	var route: Array = world.path(world.player().next if world.player().moving() else world.player().node, id)
	var a: String = world.player().node
	for b in route:
		if world.is_sea(a, b):
			sea = ", partly by sea"
		a = b
	# Kept short on the map: what it is, how far, and only danger worth knowing. The full
	# picture is inside the settlement.
	var body := "%s\n%s away%s." % [world.brief(id), _hours_text(hours), sea]
	var danger: String = world.settlement_danger(id)
	if danger != "":
		body += "\n" + danger.substr(0, 1).to_upper() + danger.substr(1) + "."
	_show_sheet("preview", String(Data.settlement(id)["name"]), body,
		[["Ride there", _on_travel.bind(id), true], ["Close", _close_sheet]])


func _open_here() -> void:
	var id: String = world.here()
	if id == "":
		_close_sheet()
		return
	_selected = id
	var buttons := [["Enter", _on_enter, true], ["Wait", _on_wait], ["Warband", _on_warband], ["Close", _close_sheet]]
	if GameState.siege_check(id)["ok"]:
		buttons.push_front(["Storm the walls", _open_siege.bind(id), true])
		buttons[1][2] = false
	if GameState.crown_check()["ok"]:
		buttons.insert(buttons.size() - 1, ["Raise your banner", _open_raise_crown])
	var offers: Array = world.offers_at(id)
	var body := "%s\nYou are here. " % world.brief(id)
	var danger: String = world.settlement_danger(id)
	if danger != "":
		body = "%s\n%s.\nYou are here. " % [world.brief(id), danger.substr(0, 1).to_upper() + danger.substr(1)]
	if offers.is_empty():
		body += "Nobody here is looking for work."
	else:
		body += "%d %s looking for work." % [offers.size(), "squad is" if offers.size() == 1 else "squads are"]
	if world.player_in_town():
		body += " Reinforce and train in town."
	_show_sheet("here", String(Data.settlement(id)["name"]), body, buttons)


func _open_band(b) -> void:
	var men := 0
	for sq in b.army:
		men += int(sq["men"])
	_show_sheet("band", b.name, "Bandits roaming the %s: %d squads, %d men. Ride into them to fight.\n%s." % [
		Data.FACTIONS[b.faction]["name"], b.army.size(), men, _pace_text(b)], [["Close", _close_sheet]])


## A lord on the road: who he is, how strong, and what he's about.
func _open_lord(lp) -> void:
	var army: Dictionary = world.MarshalArmies.for_party(world, lp.id)
	var rel: String = world.relation_to_player(lp.faction)
	var buttons := []
	if not army.is_empty():
		var names: Array = []
		var total := 0
		for member in world.MarshalArmies.members(world, army):
			var men: int = world.men_of(member.army)
			total += men
			names.append("%s — %d men" % [member.name, men])
		var body := "%s · %d men\nDestination: %s\n%s.\n\n%s" % [String(army["state"]).capitalize(), total,
			Data.settlement(army["destination"])["name"], _pace_text(lp), "\n".join(names)]
		if rel == "friendly" and GameState.has_contract() and GameState.contract_realm() == army["realm"]:
			if world.following_party == lp.id or world.following_party == int(army["leader"]):
				buttons.append(["Stop following", _on_stop_following])
			else:
				buttons.append(["Ride with army", _on_follow_lord.bind(int(army["leader"]))])
		elif rel == "neutral":
			buttons.append(["Attack", _on_attack_lord.bind(lp), true])
		buttons.append(["Close", _close_sheet])
		_show_sheet("lord", "Marshal's army", body, buttons)
		return
	var l: Dictionary = world.lord_of(lp)
	var men := 0
	for sq in lp.army:
		men += int(sq["men"])
	var realm: String = Data.FACTIONS[lp.faction]["name"]
	var who := "Ruler of the %s" % realm if l.get("ruler", false) else "A lord of the %s" % realm
	var fief := String(l.get("fief", ""))
	if fief != "" and not l.get("ruler", false):
		who += ", holding %s" % Data.settlement(fief)["name"]
	var bearing := String(l.get("bearing", ""))
	var strength_text := "%d men" % men if GameState.has_specialization(Captains.SCOUT) else "About %d men" % (int(round(men / 10.0)) * 10)
	var body := "%s. %s: %s.\n%s in %d squads. %s.\n%s." % [who, bearing, Lords.BEARING_TEXT.get(bearing, ""),
		strength_text, lp.army.size(), _lord_doing(l, lp), _pace_text(lp)]
	if rel == "friendly" and GameState.has_contract() and GameState.contract_realm() == lp.faction:
		if world.following_party == lp.id:
			buttons.append(["Stop following", _on_stop_following])
		else:
			buttons.append(["Ride with us", _on_follow_lord.bind(lp.id)])
	elif rel == "neutral":
		buttons.append(["Attack", _on_attack_lord.bind(lp), true])
	buttons.append(["Close", _close_sheet])
	_show_sheet("lord", lp.name, body, buttons)
	_show_lord_header(l)


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


## Who's quicker on the road, you or them, in words.
func _pace_text(p) -> String:
	var theirs: float = world.party_speed(p)
	var mine: float = world.player_speed()
	if theirs > mine * 1.02:
		return "Faster than you (%d to your %d): they can catch you" % [roundi(theirs), roundi(mine)]
	if theirs < mine * 0.98:
		return "Slower than you (%d to your %d): you can outrun them" % [roundi(theirs), roundi(mine)]
	return "As quick as you (%d)" % roundi(mine)


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
		_:
			return "Riding to %s" % place if lp.moving() and place != "" else "Keeping watch over their lands"


func _open_friendly_lord_encounter(b) -> void:
	var realm: String = Data.FACTIONS[b.faction]["name"]
	var title := "%s of the %s" % [b.name, realm]
	var greeter: Dictionary = world.lord_of(b)
	var text := LordVoice.line("greet", greeter) if not greeter.is_empty() else "%s halts on the road to greet you." % b.name
	var buttons := []
	buttons.append(["News of the war", _open_wars, true])
	if GameState.has_contract() and GameState.contract_realm() == b.faction:
		if world.following_party == b.id:
			buttons.append(["Part ways", _on_part_ways_friendly])
		else:
			buttons.append(["Ride with us", _on_follow_lord.bind(b.id)])
	buttons.append(["Leave", _on_part_ways_friendly])
	_show_sheet("encounter", title, text, buttons)
	_show_lord_header(world.lord_of(b))


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
	var title := "Ransom Envoy: %s" % l.get("name", "Captive Lord")
	var text := "An envoy rides under a banner of truce bearing an offer from %s.\n\n\"We offer %d silver for the honorable return of %s to their hall.\"" % [
		realm_name, ransom, l.get("name", "the lord")
	]
	var buttons := []
	buttons.append(["Accept Ransom (+%d s)" % ransom, _on_accept_ransom.bind(lord_id), true])
	if GameState.has_contract() and world.at_war(GameState.contract_realm(), String(l.get("realm", ""))):
		var bonus: int = int(GameState.contract.get("bonus_per_lord", 100))
		buttons.append(["Deliver to Employer (+%d s, +10 rel)" % bonus, _on_deliver_lord_to_employer.bind(lord_id)])
	buttons.append(["Release for Honor (+20 rel, +10 ren)", _on_release_lord_honor.bind(lord_id)])
	buttons.append(["Keep in Chains", _close_sheet])
	_show_sheet("ransom", title, text, buttons)


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
		_open_friendly_lord_encounter(b)
		return
	var men := 0
	var kinds := {}
	var band_culture := Data.culture_of(b.faction)
	for sq in b.army:
		men += int(sq["men"])
		var word := Cultures.troop_name(band_culture, sq["type"]).to_lower()
		kinds[word] = int(kinds.get(word, 0)) + 1
	var parts := PackedStringArray()
	for k in kinds:
		parts.append("%s (%d %s)" % [k, kinds[k], "squad" if kinds[k] == 1 else "squads"])
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

	var buttons := [["Fight", _on_fight, true], ["Send in", _on_send_in]]
	var withdraw_text := ""
	if is_ambush:
		withdraw_text = "\nYou cannot withdraw from an ambush!"
	elif not can_withdraw:
		withdraw_text = "\nThey are faster and stronger: you cannot withdraw!"
	else:
		buttons.append(["Withdraw", _on_withdraw])
		withdraw_text = "\nOr withdraw to %s, losing the hours it takes." % Data.settlement(world.player().node)["name"]

	var ground := ""
	if site.get("river", "") != "":
		ground = "\nYou meet them at a ford over %s." % site["river"]
	elif not bool(site.get("fair", true)):
		ground = "\nThey chose their ground: %s, and they'll wait for you on it." % (
			"the brow of a ridge" if site["type"] == "hills" else "the edge of a wood")
	var odds: Dictionary = AutoResolve.odds(fighters, b.army, site, objective)
	var lost: int = odds["lost"]
	var encounter_body := "%sSent in without you, you'd lose about %d %s.%s" % [
		ground.strip_edges() + "\n" if ground != "" else "", lost, "man" if lost == 1 else "men", withdraw_text]
	if grudge_text != "":
		encounter_body = grudge_text + "\n\n" + encounter_body
	var foe_lord: Dictionary = world.lord_of(b) if b.kind == WorldSim.LORD else {}
	if not foe_lord.is_empty():
		var met := int(foe_lord.get("met_player", 0))
		encounter_body = LordVoice.line("again" if met > 0 else "face", foe_lord) + "\n\n" + encounter_body
	_show_sheet("encounter", title, encounter_body, buttons)
	_show_odds(b, fighters, odds, men, is_ambush or not can_withdraw)
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
	var mix := HBoxContainer.new()
	mix.name = "EnemyMix"
	mix.add_theme_constant_override("separation", 6)
	mix.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mix.alignment = BoxContainer.ALIGNMENT_END
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
		mix.add_child(icon)
		mix.add_child(Style.label("×%d" % by_type[t], Style.SMALL, Style.TEXT))
	var mine := 0
	for s in fighters:
		mine += int(s.get("men", 0))
	var top: float = maxf(float(odds["player"]), float(odds["enemy"]))
	sheet_extra.add_child(_odds_bar("You", mine, float(odds["player"]) / maxf(1.0, top), Style.PLAYER))
	sheet_extra.add_child(_odds_bar("Them", their_men, float(odds["enemy"]) / maxf(1.0, top), Style.ENEMY))
	var pace := HBoxContainer.new()
	pace.add_theme_constant_override("separation", 10)
	pace.add_child(Widgets.icon_rect("speed", 32.0))
	var quick: bool = world.party_speed(b) > world.player_speed()
	var pace_text := _pace_text(b)
	if quick and not trapped:
		pace_text += " · withdrawing may fail"
	pace.add_child(Style.label(pace_text, Style.SMALL, Style.ENEMY_LIGHT if quick else Style.MUTED))
	sheet_extra.add_child(pace)
	sheet_extra.visible = true


func _odds_bar(who: String, men: int, share: float, tone: Color) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var name_label := Style.label(who, Style.SMALL, Style.MUTED)
	name_label.custom_minimum_size = Vector2(70, 0)
	row.add_child(name_label)
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
	var count := Style.label("%d men" % men, Style.SMALL, Style.TEXT)
	count.custom_minimum_size = Vector2(110, 0)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(count)
	return row


func _odds_text(odds: Dictionary) -> String:
	var r: float = odds["ratio"]
	var call: String
	if odds["player_wins"]:
		call = "they're no match for you" if r < 0.5 else ("you have the stronger force" if r < 0.85 else "it's close, with the edge to you")
	else:
		call = "you're badly outmatched" if r < 0.5 else ("they have the stronger force" if r < 0.85 else "it's close, with the edge to them")
	var lost: int = odds["lost"]
	return "Your scouts say %s. Sent in without you, you'd lose about %d %s." % [call, lost, "man" if lost == 1 else "men"]


func _open_desertion_warning() -> void:
	_show_sheet("warning", "Warning: men are leaving", GameState.desertion_warning +
		"\n\nTime is paused. Restore supplies and wages before another day passes.",
		[["Understood", _acknowledge_desertion, true]])
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
	var text := ""
	match key:
		"silver":
			text = "%d silver. Your men need %d silver in wages each day. Win battles for bounties and spoils." % [GameState.silver, GameState.daily_wages()]
			if GameState.silver < GameState.daily_wages():
				text += "\nWarning: you cannot cover the next day's wages. Unpaid men may leave."
		"food":
			text = "%d rations, enough for %d days. Every man eats one ration a day. Buy food in any settlement; villages are cheapest." % [GameState.food, GameState.food_days()]
			if GameState.food < GameState.total_men():
				text += "\nWarning: there is not enough food for the next day. Hungry men may leave."
		"renown":
			text = "%d renown. You can lead up to %d squads. Winning battles builds your reputation and increases your squad limit." % [GameState.renown, GameState.squad_cap()]
	_show_sheet("menu", key.capitalize(), text, [["Close", _close_sheet]])


func _open_notice(text: String, title: String = "After the battle") -> void:
	if GameState.desertion_warning != "":
		for line in GameState.desertion_warning.split("\n"):
			text = text.replace(line, "")
		text = text.strip_edges()
		if text == "":
			_open_desertion_warning()
			return
	if GameState.total_men() == 0:
		_show_sheet("notice", "Your warband is gone", text + " Raise a new one to ride again.",
			[["New campaign", _on_new_campaign, true]])
		return
	_show_sheet("notice", title, text, [["Carry on", _on_notice_done, true]])


func _on_notice_done() -> void:
	_close_sheet()
	if world.here() != "":
		_open_here()


func _hours_text(hours: float) -> String:
	var h := int(ceil(hours))
	if h >= 24:
		var days := "1 day" if h / 24 == 1 else "%d days" % (h / 24)
		return days if h % 24 == 0 else "%s %s" % [days, _hours_text(h % 24)]
	return "%d hours" % h if h != 1 else "1 hour"


# ---------------------------------------------------------------- actions

func _on_travel(id: String) -> void:
	if world.travel(id):
		_close_sheet()
		GameState.save_game()


func _on_wait() -> void:
	if world.wait(8.0):
		_close_sheet()


func _on_enter() -> void:
	GameState.save_game()
	Scenes.settlement_arrival_pending = true
	Scenes.go("res://scenes/settlement.tscn")


func _on_menu() -> void:
	if _sheet in ["encounter", "notice", "warning"]:
		return
	_show_sheet("menu", "Campaign menu", "Time is paused. Your progress saves automatically.",
		([["Next step", _open_recommendation, true], ["Journal", _open_journal], ["Warband", _on_warband], [_people_label(), _on_people], ["War & Politics", _open_wars]]
		+ ([["Your Crown", _open_crown]] if GameState.is_crowned() else [])
		+ [["Settings", _on_settings], ["Home", _on_home], ["Close", _close_sheet]]))


func _open_wars() -> void:
	var lines: Array[String] = []
	lines.append("=== WARS & TRUCES ===")
	if world.wars.is_empty():
		lines.append("All realms are currently at peace.")
	else:
		for k in world.wars:
			var parts: PackedStringArray = k.split("|")
			var r0: String = Data.FACTIONS[parts[0]]["name"]
			var r1: String = Data.FACTIONS[parts[1]]["name"]
			var days_war: int = int((world.hour - float(world.wars[k].get("since", 0.0))) / 24.0)
			lines.append("• %s vs %s · %d days at war" % [r0, r1, days_war])

	if not world.truces.is_empty():
		for k in world.truces:
			var parts: PackedStringArray = k.split("|")
			var r0: String = Data.FACTIONS[parts[0]]["name"]
			var r1: String = Data.FACTIONS[parts[1]]["name"]
			var days_left: int = int(ceil(maxf(0.0, float(world.truces[k].get("until", 0.0)) - world.hour) / 24.0))
			lines.append("• Truce: %s and %s · %d days remaining" % [r0, r1, days_left])

	if not world.tributes.is_empty():
		for t in world.tributes:
			var f_name: String = Data.FACTIONS[t["from"]]["name"]
			var to_name: String = Data.FACTIONS[t["to"]]["name"]
			lines.append("• Tribute: %s pays %d silver/day to %s (%d days left)" % [f_name, t["daily"], to_name, t["days_left"]])

	lines.append("\n=== REALMS ===")
	for f in ["vardmark", "kharzan", "ryumon"] + ([Data.CROWN] if GameState.is_crowned() else []):
		var fn: String = Data.FACTIONS[f]["name"]
		var str_val: int = world.realm_strength(f)
		var wear: float = world.weariness_of(f)
		var holdings_count: int = world.holdings_of(f).size()
		lines.append("• %s: %d men · Weariness %d%% · %d holdings" % [fn, str_val, int(wear), holdings_count])

	lines.append("\n=== RECENT WAR EVENTS ===")
	var event_count := 0
	for entry in world.activity_log:
		var kind: String = entry.get("type", "")
		if kind in ["war", "peace", "captured", "fight", "siege_assault"]:
			var h := int(float(entry.get("hour", 0.0)))
			lines.append("Day %d · %s" % [h / 24 + 1, entry.get("text", "")])
			event_count += 1
			if event_count >= 5:
				break
	if event_count == 0:
		lines.append("No recent major battles or captures.")

	_show_sheet("wars", "War & Politics", "\n".join(lines), [["The Chronicle", _open_chronicle.bind("war")], ["Close", _close_sheet, true]])


# ---------------------------------------------------------------- journal

## "12h left" / "3 days left", or "" when a commitment has no deadline.
func _commitment_time(c: Dictionary, prefix: String = "") -> String:
	var h := float(c.get("hours_left", -1.0))
	if h < 0.0:
		return ""
	return prefix + ("%d days left" % int(ceil(h / 24.0)) if h >= 48.0 else "%dh left" % int(ceil(h)))


## What the company has promised to do. Reading it takes no time.
func _open_journal() -> void:
	if _sheet in ["encounter", "notice", "warning"]:
		return
	var all: Array = GameState.commitments()
	var lines: PackedStringArray = []
	var buttons := []
	if all.is_empty():
		var rec: Dictionary = GameState.recommendation()
		lines.append("No promises bind the company yet.")
		lines.append("Settlements offer jobs, and realms at war hire sellswords. %s: %s" % [rec.get("title", "Next step"), rec.get("body", "")])
	# The pinned entry leads the list.
	all.sort_custom(func(a, b): return a["id"] == GameState.pinned_commitment and b["id"] != GameState.pinned_commitment)
	for c in all:
		var line := "• %s%s" % [c["title"], _commitment_time(c, " · ")]
		if c["id"] == GameState.pinned_commitment:
			line += " · pinned"
		if String(c["blocked"]) != "":
			line += "\n   Waiting: %s" % c["blocked"]
		lines.append(line)
		buttons.append([String(c["title"]), _open_commitment.bind(String(c["id"]))])
	if not GameState.ended_commitments.is_empty():
		lines.append("\nRecently ended:")
		for e in GameState.ended_commitments.slice(0, 3):
			lines.append("• Day %d · %s: %s" % [int(float(e.get("hour", 0.0))) / 24 + 1, e.get("title", ""), e.get("outcome", "")])
	buttons.append(["Chronicle", _open_chronicle.bind("all")])
	buttons.append([_people_label(), _on_people])
	buttons.append(["Close", _close_sheet, true])
	_show_sheet("journal", "Journal · %d active" % all.size(), "\n".join(lines), buttons)


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
	var t := _commitment_time(c)
	if t != "":
		lines.append("Time: %s" % t)
	if String(c["blocked"]) != "":
		lines.append("Waiting: %s" % c["blocked"])
	var buttons := []
	if String(c["place"]) != "" and Data.SETTLEMENTS.has(String(c["place"])):
		buttons.append(["Show on map", _focus_place.bind(String(c["place"])), true])
	buttons.append(["Unpin" if GameState.pinned_commitment == id else "Pin to top", _on_pin.bind(id)])
	buttons.append(["Back to journal", _open_journal])
	_show_sheet("commitment", String(c["title"]), "\n".join(lines), buttons)


func _on_pin(id: String) -> void:
	GameState.pin_commitment(id)
	_refresh_hud()
	_open_commitment(id)


## The chronicle: the last 30 events (wars, peace, captures, sieges, company deeds)
func _open_chronicle(filter: String = "all") -> void:
	var lines: Array[String] = []
	var entries: Array = []
	for entry in world.activity_log:
		if filter == "all" or entry.get("category", "") == filter:
			entries.append(entry)
			if entries.size() >= 30:
				break
	for entry in entries:
		var h := int(float(entry.get("hour", 0.0)))
		lines.append("Day %d · %s" % [h / 24 + 1, entry.get("text", "")])
	if lines.is_empty():
		lines.append("No chronicle events in this category yet.")
	var buttons := [
		["All", _open_chronicle.bind("all"), filter == "all"],
		["Wars", _open_chronicle.bind("war"), filter == "war"],
		["Sieges", _open_chronicle.bind("siege"), filter == "siege"],
		["Deeds", _open_chronicle.bind("deed"), filter == "deed"],
		["Close", _close_sheet]
	]
	var cat_label := "" if filter == "all" else (" · " + filter.capitalize())
	_show_sheet("chronicle", "The Chronicle%s" % cat_label, "\n".join(lines), buttons)


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
				buttons.append(["Show %s" % Data.settlement(place)["name"], _focus_place.bind(place), true])
		"warband":
			buttons.append(["View warband", _on_warband, true])
	buttons.append(["Close", _close_sheet])
	_show_sheet("recommendation", String(rec.get("title", "Next step")), String(rec.get("body", "")), buttons)


func _focus_place(id: String) -> void:
	_selected = id
	cam_center = Data.pos(id)
	_clamp_camera()
	_sync_layers()
	_open_preview(id)


func _people_label() -> String:
	var n: int = world.social.unread_letters_count() if world.social != null else 0
	return "People & Letters (%d)" % n if n > 0 else "People & Letters"


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
	var big: Font = Style.display_font()
	if big != null:
		_banner_title.add_theme_font_override("font", big)
	words.add_child(_banner_title)
	_banner_from = Style.label("", Style.SMALL, Style.TEXT)
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
	var fresh: Array = world.social.take_unannounced()
	if not fresh.is_empty() and not autoplay:
		_show_letter_banner(fresh[fresh.size() - 1])
	if letter_banner.visible:
		_banner_left -= delta
		if _banner_left <= 0.0:
			letter_banner.visible = false


func _show_letter_banner(l: Dictionary) -> void:
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


func _read_banner_letter() -> void:
	letter_banner.visible = false
	GameState.save_game()
	Scenes.people_return = "res://scenes/world_map.tscn"
	Scenes.people_letter = _banner_letter
	Scenes.go("res://scenes/people.tscn")


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
			"The army of %s is ready to storm %s: %d men against %d on the walls. The marshal offers you the van. Lead the assault, with the lords' men fighting beside you?" % [
				realm, place, their_men, garrison_men],
			[["Lead the assault", _on_assault_answer.bind(true), true], ["Let them storm it", _on_assault_answer.bind(false)]])
	else:
		_show_sheet("encounter", "%s is stormed!" % place,
			"The army of %s storms the walls of your fief: %d men against its %d. Will you hold the walls yourself, with the garrison beside you?" % [
				realm, their_men, garrison_men],
			[["Hold the walls", _on_assault_answer.bind(true), true], ["Leave it to the garrison", _on_assault_answer.bind(false)]])


func _on_assault_answer(fight: bool) -> void:
	GameState.answer_assault(fight)
	_close_sheet()
	if fight and not GameState.pending_battle.is_empty():
		GameState.save_game()
		Scenes.go("res://scenes/battle.tscn")
	_refresh_hud()


## Cast off your liege: what it means, before it's done.
func _open_raise_crown() -> void:
	var liege: String = Data.FACTIONS[GameState.fief_realm()]["name"]
	_show_sheet("crown", "Raise your banner",
		"Declare %s the seat of your own crown. %s will go to war with you at once and send its armies for your walls. Every castle or town you storm after this is yours, and its dues fill your purse and your garrisons. There is no going back." % [
			Data.settlement(GameState.fief_id())["name"], liege],
		[["Raise the crown", _on_raise_crown, true], ["Not yet", _open_here]])


func _on_raise_crown() -> void:
	if GameState.declare_crown():
		Sound.play("horn")
	_close_sheet()
	_refresh_hud()
	_sync_layers()


## The crown: what it holds, who it fights, who stands with it.
func _open_crown() -> void:
	var lines: PackedStringArray = []
	var held: Array = GameState.crown_holdings()
	var names: PackedStringArray = []
	for id in held:
		names.append(String(Data.settlement(id)["name"]))
	lines.append("Holds: %s." % ", ".join(names) if not names.is_empty() else "Holds nothing. Without a seat the crown is only a name.")
	lines.append("Crown treasury: %d silver (raises garrisons)." % int(world.realms[Data.CROWN].get("treasury", 0)))
	var buttons := []
	var enemies: Array = world.crown_enemies()
	if enemies.is_empty():
		lines.append("At war with no one.")
	for r in enemies:
		var check: Dictionary = GameState.crown_peace_check(r)
		lines.append("At war with %s.%s" % [Data.FACTIONS[r]["name"], "" if check["ok"] else " " + String(check["reason"])])
		if check["ok"]:
			buttons.append(["Sue %s for peace" % Data.FACTIONS[r]["name"], _on_crown_peace.bind(r)])
	for r in world.alliances:
		lines.append("Allied with %s." % Data.FACTIONS[r]["name"])
	for r in GameState.crown_allies_possible():
		buttons.append(["Ally with %s" % Data.FACTIONS[r]["name"], _on_crown_ally.bind(r)])
	buttons.append(["Close", _close_sheet, true])
	_show_sheet("crown", "Your Crown", "\n".join(lines), buttons)


func _on_crown_ally(realm: String) -> void:
	GameState.propose_alliance(realm)
	_open_crown()


func _on_crown_peace(realm: String) -> void:
	GameState.sue_for_peace(realm)
	_open_crown()


## Before an assault: the garrison, the walls, and the odds.
func _open_siege(id: String) -> void:
	var check: Dictionary = GameState.siege_check(id)
	if not check["ok"]:
		_open_notice(String(check["reason"]), "The walls")
		return
	var place: String = Data.settlement(id)["name"]
	var realm: String = Data.FACTIONS[check["realm"]]["name"]
	var walls: float = float(Lords.WALLS[check["kind"]])
	var fighters: Array = GameState.army.filter(func(s): return int(s["men"]) > 0)
	var garrison: Array = world.garrisons.get(id, [])
	var body := "Storm %s for %s. %d men hold its walls against your %d.\n" % [place, realm, check["men"], GameState.total_men()]
	body += "Men on foot must batter down the gate while the walls shelter the defenders' archers; then rout the garrison. A gate still standing when time runs out means the walls held."
	var allies: Array = GameState.siege_allies(id)
	if not allies.is_empty():
		var ally_men := 0
		for a in allies:
			ally_men += int(a["men"])
		body += "\n%d men of the lords camped here will storm the walls beside you." % ally_men
		fighters = fighters + allies
	if not garrison.is_empty():
		var odds: Dictionary = AutoResolve.odds(fighters, garrison, null, "rout", walls)
		body += "\nYour captains think the assault %s." % ("can succeed" if odds["player_wins"] else "would fail")
	else:
		body += "\nThe walls stand empty. It is yours for the taking."
	_show_sheet("siege", "Storm %s" % place, body, [["Lead the assault", _on_storm.bind(id), true],
		["Send them in", _on_storm_send.bind(id)], ["Back", _open_here]])


func _on_storm(id: String) -> void:
	if world.garrisons.get(id, []).is_empty():
		_on_storm_send(id)
		return
	GameState.start_siege_battle(id)
	GameState.save_game()
	Scenes.go("res://scenes/battle.tscn")


func _on_storm_send(id: String) -> void:
	GameState.auto_resolve_siege(id)
	_close_sheet()
	_refresh_hud()
	_sync_layers()
	if GameState.map_notice != "":
		_open_notice(GameState.map_notice, "The assault")
		GameState.map_notice = ""


func _on_fight() -> void:
	GameState.start_encounter_battle()
	GameState.save_game()
	Scenes.go("res://scenes/battle.tscn")


## Settle the fight at once, without the battle screen.
func _on_send_in() -> void:
	var won: bool = GameState.auto_resolve_encounter().get("won", false)
	Sound.play("charge")
	get_tree().create_timer(1.1).timeout.connect(Sound.play.bind("coins" if won else "bell"))
	_close_sheet()
	_open_notice(GameState.map_notice)
	GameState.map_notice = ""


func _on_withdraw() -> void:
	if not world.can_withdraw():
		var b = world.party(world.encounter)
		var l_name: String = b.name if b != null else "The enemy"
		_show_sheet("encounter", "Ridden Down!", "%s's cavalry ride you down as you attempt to withdraw! You have no choice but to fight." % l_name,
			[["Fight", _on_fight, true], ["Send in", _on_send_in]])
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
	b.icon = _glyph(kind)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size = Vector2(72, 64)
	return b


## Small icons drawn here rather than taken from the font, which may not carry them.
var _glyphs := {}

func _glyph(kind: String) -> Texture2D:
	if _glyphs.has(kind):
		return _glyphs[kind]
	var n := 32
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Color(0.93, 0.89, 0.8)
	match kind:
		"menu":
			for y in [8, 15, 22]:
				img.fill_rect(Rect2i(6, y, 20, 3), c)
		"pause":
			img.fill_rect(Rect2i(9, 7, 5, 18), c)
			img.fill_rect(Rect2i(18, 7, 5, 18), c)
		"play", "fast":
			var tris := [[9, 23]] if kind == "play" else [[4, 15], [15, 26]]
			for t in tris:
				for x in range(t[0], t[1]):
					var h := int((float(t[1] - x) / float(t[1] - t[0])) * 9.0)
					img.fill_rect(Rect2i(x, 16 - h, 1, h * 2 + 1), c)
		"sun":
			var sc := Style.BRASS
			for y in n:
				for x in n:
					var d := Vector2(x - 15.5, y - 15.5).length()
					if d < 6.0:
						img.set_pixel(x, y, sc)
			for i in 8:
				var a := TAU * i / 8.0
				for r in range(9, 13):
					img.set_pixel(int(15.5 + cos(a) * r), int(15.5 + sin(a) * r), sc)
		"moon":
			var mc := Color(0.78, 0.82, 0.95)
			for y in n:
				for x in n:
					if Vector2(x - 15.5, y - 15.5).length() < 10.0 and Vector2(x - 20.5, y - 12.5).length() > 8.0:
						img.set_pixel(x, y, mc)
	var tex := ImageTexture.create_from_image(img)
	_glyphs[kind] = tex
	return tex


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


func _refresh_hud() -> void:
	var h := int(world.hour)
	if unread_badge != null and world.social != null:
		var unread: int = world.social.unread_letters_count()
		unread_badge.visible = unread > 0
		unread_badge.text = str(unread)
	clock_label.text = "Day %d · %02d:00" % [h / 24 + 1, h % 24]
	day_icon.texture = _glyph("moon" if h % 24 < 6 or h % 24 >= 20 else "sun")
	var current := pause_button if paused else (fast_button if speed > 1.5 else play_button)
	for b in [pause_button, play_button, fast_button]:
		var on: bool = b == current
		b.add_theme_stylebox_override("normal", _pill_box(Style.BRASS if on else Color(Style.PANEL, 0.94)))
		b.add_theme_stylebox_override("hover", _pill_box(Style.BRASS.lightened(0.1) if on else Color(Style.PANEL, 0.94).lightened(0.08)))
		var ink := Color(0.1, 0.08, 0.12) if on else Color(0.93, 0.89, 0.8)
		for state in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
			b.add_theme_color_override(state, ink)
	bottom_bar.visible = not sheet_panel.visible
	var modal := _sheet in ["encounter", "notice", "warning"]
	warband_button.disabled = modal
	for b in [pause_button, play_button, fast_button]:
		b.disabled = modal or _sheet == "menu"
	for badge in resource_buttons.values():
		badge.disabled = modal
	var days: int = GameState.food_days()
	resource_buttons["silver"].text = _short_amount(GameState.silver)
	resource_buttons["food"].text = "%sd" % _short_amount(days)
	resource_buttons["renown"].text = _short_amount(GameState.renown)
	resource_buttons["silver"].tooltip_text = "%d silver · wages %d per day" % [GameState.silver, GameState.daily_wages()]
	resource_buttons["food"].tooltip_text = "%d rations · %d days of food" % [GameState.food, days]
	resource_buttons["renown"].tooltip_text = "%d renown · capacity %d squads" % [GameState.renown, GameState.squad_cap()]
	resource_buttons["silver"].add_theme_color_override("font_color", Style.ENEMY_LIGHT if GameState.silver < GameState.daily_wages() else Style.TEXT)
	resource_buttons["food"].add_theme_color_override("font_color", Style.ENEMY_LIGHT if days < 2 else Style.TEXT)
	var p = world.player()
	if world.encounter != -1:
		var enc_p = world.party(world.encounter)
		if enc_p != null and enc_p.kind == WorldSim.LORD:
			status_label.text = "%s blocks your road" % enc_p.name
		else:
			status_label.text = "Bandits block the road"
	elif world.following_party != -1:
		var fp = world.party(world.following_party)
		status_label.text = "Riding with %s" % (fp.name if fp != null else "allies")
	elif p.moving():
		var to: String = world.destination()
		status_label.text = "Riding to %s · %s" % [Data.settlement(to)["name"], _hours_text(world.hours_to(to))]
	elif p.wait > 0.0:
		status_label.text = "Waiting at %s · %s" % [Data.settlement(p.node)["name"], _hours_text(p.wait)]
	else:
		status_label.text = "At %s" % Data.settlement(p.node)["name"]
	var at_risk: bool = GameState.food < GameState.total_men() or GameState.silver < GameState.daily_wages()
	var chaser = _chaser()
	if chaser != null:
		status_label.text += "\n%s is riding after you%s" % [chaser.name,
			" and is faster" if world.can_catch_player(chaser) else ", but you're quicker"]
		at_risk = true
	elif at_risk:
		status_label.text += "\nLow supplies: men may leave."
	if not GameState.captive_lords().is_empty():
		var n_captives: int = GameState.captive_lords().size()
		status_label.text += " · %d captive%s" % [n_captives, "" if n_captives == 1 else "s"]
	status_label.add_theme_color_override("font_color", Style.ENEMY_LIGHT if at_risk else Style.MUTED)
	_update_progress(p)




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


## A siege ring and the besiegers' tents around every settlement under siege, in the
## besieging realm's colors.
func _draw_sieges(px: float) -> void:
	for army in world.campaign_armies:
		if String(army.get("state", "")) != "besieging":
			continue
		var id := String(army["target"])
		if not Data.SETTLEMENTS.has(id):
			continue
		var c := _to_screen(Data.pos(id))
		var color: Color = Style.BRASS if String(army["realm"]) == Data.CROWN else Cultures.color(Data.culture_of(String(army["realm"])))
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
	var colors := Style.BRASS if world.owner_of(id) == Data.CROWN else Cultures.color(Data.culture_of(world.owner_of(id)))
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

	# Siege camps drawn around besieged settlements
	if world.is_sieged(id):
		var siege_r: float = w * 0.72
		draw_arc(c, siege_r, 0.1, TAU - 0.1, 32, Color("7a5c3b"), 2.0)
		for t_i in 4:
			var ang := 0.45 + t_i * 1.57
			var t_pos := c + Vector2(cos(ang), sin(ang)) * siege_r
			var pts := PackedVector2Array([
				t_pos + Vector2(0, -6.0 * px),
				t_pos + Vector2(4.5 * px, 4.0 * px),
				t_pos + Vector2(-4.5 * px, 4.0 * px)
			])
			draw_colored_polygon(pts, Color("8a7356"))
			draw_polyline(pts, Color("483928"), 1.2)
		for f_i in 2:
			var f_ang := 1.25 + f_i * 3.1
			var f_pos := c + Vector2(cos(f_ang), sin(f_ang)) * (siege_r + 5.0 * px)
			var f_pulse := 0.7 + 0.3 * sin(_clock * 8.0 + f_i * 3.0)
			draw_circle(f_pos, 2.5 * px * f_pulse, Color(0.95, 0.45, 0.1, 0.85))
			draw_circle(f_pos, 1.2 * px * f_pulse, Color(1.0, 0.85, 0.3, 0.95))


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


## How a party's men compare with yours, as the chip under its name: ▲ stronger,
## ◆ about even, ▼ weaker.
func _strength_mark(men: int) -> Array:
	var mine := maxf(1.0, float(GameState.total_men()))
	var ratio := float(men) / mine
	if ratio > 1.25:
		return ["▲", Color("ffb3a0")]
	if ratio < 0.8:
		return ["▼", Color("b8f5b0")]
	return ["◆", Color("ffd27a")]


func _draw_army_badge(at: Vector2, state: String, px: float) -> void:
	var r := 7.0 * px
	draw_circle(at, r + 1.5 * px, Color(0, 0, 0, 0.6))
	draw_circle(at, r, Style.NIGHT)
	draw_arc(at, r, 0.0, TAU, 20, Style.BRASS, 1.5 * px)
	var c := Style.BRASS
	match state:
		"marching":
			draw_polyline(PackedVector2Array([at + Vector2(-3, -4) * px, at + Vector2(2, 0) * px, at + Vector2(-3, 4) * px]), c, 1.8 * px)
		"returning":
			draw_polyline(PackedVector2Array([at + Vector2(3, -4) * px, at + Vector2(-2, 0) * px, at + Vector2(3, 4) * px]), c, 1.8 * px)
		"besieging":
			# a little tower: the walls they sit before
			draw_rect(Rect2(at + Vector2(-3.5, -1.5) * px, Vector2(7, 5) * px), c)
			for x in [-3.5, -0.5, 2.5]:
				draw_rect(Rect2(at + Vector2(x, -4) * px, Vector2(1.5, 2) * px), c)
		_:
			draw_circle(at, 2.0 * px, c)


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
	for id in Data.SETTLEMENTS:
		var s := Data.settlement(id)
		var size := Style.SMALL if s["type"] != Data.VILLAGE else 19
		_name_plate(_to_screen(s["pos"]) + Vector2(0, 8.0 + px * 2.0), String(s["name"]), size,
			Style.BRASS if s["type"] == Data.TOWN else Style.TEXT)
	for b in world.bands():
		if px >= 2.0:
			var b_col := Color("e8d9c0")
			if px < 2.5:
				b_col.a = clampf((px - 2.0) / 0.5, 0.3, 1.0)
			_name_plate(_to_screen(world.party_pos(b)) + Vector2(0, -21.0 * px - 6.0), b.name, 17, b_col,
				Color(Style.ENEMY_LIGHT, b_col.a * 0.8), world.men_of(b.army))
	# Lords' names only once you're looking closely, or the map drowns in them.
	if px >= LORD_NAMES_PX:
		for lp in world.visible_lord_parties():
			var army: Dictionary = world.MarshalArmies.for_party(world, lp.id)
			if not army.is_empty() and army["state"] != "gathering":
				if lp.id != int(army["leader"]):
					if px < 2.8:
						continue
					_name_plate(_to_screen(world.party_pos(lp)) + Vector2(0, -21.0 * px - 6.0), "%s (Cohort)" % lp.name, 14,
						Cultures.color(Data.culture_of(lp.faction)).lightened(0.35))
					continue
				var total_men := 0
				for m in world.MarshalArmies.members(world, army):
					total_men += world.men_of(m.army)
				var title := "MARSHAL ARMY · %s (%d men)" % [lp.name, total_men]
				_name_plate(_to_screen(world.party_pos(lp)) + Vector2(0, -25.0 * px - 6.0), title, 16,
					Cultures.color(Data.culture_of(lp.faction)).lightened(0.55))
			else:
				var rel := String(world.relation_to_player(lp.faction))
				var edge := Style.ENEMY_LIGHT if rel == "hostile" else (Style.BRASS if rel in ["friendly", "allied", "employer"] else Color("6d7699"))
				_name_plate(_to_screen(world.party_pos(lp)) + Vector2(0, -32.0 * px - 6.0), String(lp.name), 15,
					Cultures.color(Data.culture_of(lp.faction)).lightened(0.45), edge, world.men_of(lp.army))


## A name on a dark plate, centered on `at` (the plate's top edge).
## `edge` rings the plate (red for enemies, brass for friends); `men` >= 0 adds a chip
## with how they compare with you.
func _name_plate(at: Vector2, text: String, size: int, color: Color, edge: Color = Color(0, 0, 0, 0), men: int = -1) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var chip_text := ""
	var chip_w := 0.0
	var mark: Array = []
	if men >= 0:
		mark = _strength_mark(men)
		chip_text = "%s %d" % [mark[0], men]
		chip_w = font.get_string_size(chip_text, HORIZONTAL_ALIGNMENT_LEFT, -1, size - 3).x + 14.0
	var rect := Rect2(at + Vector2(-(w + chip_w) * 0.5 - 8.0, 0.0), Vector2(w + chip_w + 16.0 + (6.0 if chip_w > 0.0 else 0.0), size + 8.0))
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
		labels.draw_string(font, chip.position + Vector2(7.0, chip.size.y * 0.5 + (size - 3) * 0.36), chip_text, HORIZONTAL_ALIGNMENT_LEFT, -1, size - 3, Color("14161f"))


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
