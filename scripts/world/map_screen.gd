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
const SKY_SHADER = preload("res://shaders/map_sky.gdshader")

const TOP_BAR := 184.0
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
var next_button: Button
var sheet_panel: PanelContainer
var sheet_title: Label
var sheet_body: Label
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
	elif GameState.desertion_warning != "":
		_open_desertion_warning()
	elif GameState.map_notice != "":
		_open_notice(GameState.map_notice)
		GameState.map_notice = ""
	elif world.here() != "":
		_open_here()


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
	# An encounter or a note about the last battle holds the clock until it's answered.
	if world.busy() and _sheet not in ["encounter", "notice", "menu", "warning", "activity", "recommendation"]:
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
			"siege_loot":
				GameState.silver += int(e.get("silver", 0))
				GameState.renown += int(e.get("renown", 0))
				GameState.settle()
				_open_notice("Assault successful at %s! Claimed %d silver and %d renown." % [
					Data.settlement(String(e.get("target", "")))["name"],
					int(e.get("silver", 0)), int(e.get("renown", 0))
				], "Siege Victory")
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
	stack_top.add_theme_constant_override("separation", 4)
	top_panel.add_child(stack_top)
	var resource_row := HBoxContainer.new()
	resource_row.add_theme_constant_override("separation", 8)
	stack_top.add_child(resource_row)
	clock_label = Style.label("", Style.BODY, Style.BRASS)
	clock_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clock_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	resource_row.add_child(clock_label)
	for key in ["silver", "food", "renown"]:
		var badge := _button("", _open_resource.bind(key))
		badge.icon = _resource_icon(key)
		badge.expand_icon = true
		badge.add_theme_constant_override("icon_max_width", 30)
		badge.add_theme_font_size_override("font_size", Style.SMALL)
		badge.custom_minimum_size = Vector2(138, Style.TOUCH)
		resource_buttons[key] = badge
		resource_row.add_child(badge)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	stack_top.add_child(row)
	status_label = Style.label("", Style.SMALL, Style.MUTED)
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status_label.custom_minimum_size = Vector2(10, 0)
	row.add_child(status_label)
	next_button = _button("Next", _open_recommendation)
	next_button.name = "NextStepButton"
	next_button.custom_minimum_size = Vector2(118, Style.TOUCH)
	row.add_child(next_button)
	speed_button = _button("1×", _on_speed)
	speed_button.custom_minimum_size = Vector2(Style.TOUCH, Style.TOUCH)
	row.add_child(speed_button)
	warband_button = _button("Menu", _on_menu)
	warband_button.custom_minimum_size = Vector2(150, Style.TOUCH)
	row.add_child(warband_button)

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
	sheet_title = Style.label("", Style.LARGE, Style.TEXT)
	sv.add_child(sheet_title)
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


func _close_sheet() -> void:
	_sheet = ""
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
	var body := "%s\n%s\n%s away%s." % [world.describe(id), world.settlement_intelligence(id), _hours_text(hours), sea]
	_show_sheet("preview", String(Data.settlement(id)["name"]), body,
		[["Ride there", _on_travel.bind(id), true], ["Close", _close_sheet]])


func _open_here() -> void:
	var id: String = world.here()
	if id == "":
		_close_sheet()
		return
	_selected = id
	var buttons := [["Enter", _on_enter, true], ["Wait", _on_wait], ["Warband", _on_warband], ["Close", _close_sheet]]
	var offers: Array = world.offers_at(id)
	var body := "%s\n%s\nYou are here. " % [world.describe(id), world.settlement_intelligence(id)]
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
	_show_sheet("band", b.name, "Bandits roaming the %s: %d squads, %d men. Ride into them to fight." % [
		Data.FACTIONS[b.faction]["name"], b.army.size(), men], [["Close", _close_sheet]])


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
		var body := "%s · %d men\nDestination: %s\n\n%s" % [String(army["state"]).capitalize(), total,
			Data.settlement(army["destination"])["name"], "\n".join(names)]
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
	var body := "%s. %s: %s.\nAbout %d men in %d squads. %s." % [who, bearing, Lords.BEARING_TEXT.get(bearing, ""),
		int(round(men / 10.0)) * 10, lp.army.size(), _lord_doing(l, lp)]
	if rel == "friendly" and GameState.has_contract() and GameState.contract_realm() == lp.faction:
		if world.following_party == lp.id:
			buttons.append(["Stop following", _on_stop_following])
		else:
			buttons.append(["Ride with us", _on_follow_lord.bind(lp.id)])
	elif rel == "neutral":
		buttons.append(["Attack", _on_attack_lord.bind(lp), true])
	buttons.append(["Close", _close_sheet])
	_show_sheet("lord", lp.name, body, buttons)


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


func _lord_doing(l: Dictionary, lp) -> String:
	var target := String(l.get("target", ""))
	var place := String(Data.settlement(target)["name"]) if Data.SETTLEMENTS.has(target) else ""
	match String(l.get("job", "")):
		"raid":
			return "Burning %s" % place if String(l.get("raiding", "")) != "" else "Riding to raid %s" % place
		"defend":
			return "Riding to defend %s" % place
		"hunt":
			return "Hunting bandits near %s" % place
		"home":
			return "Resting at %s, raising men" % place if not lp.moving() else "Riding home to %s" % place
		_:
			return "Riding to %s" % place if lp.moving() and place != "" else "Keeping watch on his lands"


func _open_friendly_lord_encounter(b) -> void:
	var realm: String = Data.FACTIONS[b.faction]["name"]
	var title := "%s of the %s" % [b.name, realm]
	var text := "Lord %s halts his party and greets you warmly upon the road.\n\"Greetings, sellsword. What news do you bring?\"" % b.name
	var buttons := []
	buttons.append(["News of the war", _open_wars, true])
	if GameState.has_contract() and GameState.contract_realm() == b.faction:
		if world.following_party == b.id:
			buttons.append(["Part ways", _on_part_ways_friendly])
		else:
			buttons.append(["Ride with us", _on_follow_lord.bind(b.id)])
	buttons.append(["Leave", _on_part_ways_friendly])
	_show_sheet("encounter", title, text, buttons)


func _on_part_ways_friendly() -> void:
	world.encounter = -1
	_close_sheet()


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
	var title := "%s block the road" % b.name
	if b.kind == WorldSim.LORD:
		title = "%s blocks the road!" % b.name
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
		withdraw_text = "\nLead the fight, send your men in without you, or withdraw to %s and lose the hours it takes." % Data.settlement(world.player().node)["name"]

	var ground := ""
	if site.get("river", "") != "":
		ground = "\nYou meet them at a ford over %s." % site["river"]
	elif not bool(site.get("fair", true)):
		ground = "\nThey chose their ground: %s, and they'll wait for you on it." % (
			"the brow of a ridge" if site["type"] == "hills" else "the edge of a wood")
	_show_sheet("encounter", title,
		"%d squads, %d men: %s.%s\n%s%s" % [
			b.army.size(), men, ", ".join(parts), ground, _odds_text(AutoResolve.odds(fighters, b.army, site, objective)),
			withdraw_text],
		buttons)
	Sound.play("alarm")


## The music of the realm you're riding through; at sea, whatever was playing.
func _update_music() -> void:
	var realm: String = terrain.realm_at(world.party_pos(world.player()))
	if realm != "":
		Sound.play_music(Data.culture_of(realm))


## What your scouts make of a fight, from auto-resolve's reckoning.
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
		[["Warband", _on_warband], ["People & Letters", _on_people], ["War & Politics", _open_wars], ["Activity", _open_activity],
		["Settings", _on_settings], ["Home", _on_home], ["Close", _close_sheet]])


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
	for f in ["vardmark", "kharzan", "ryumon"]:
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

	_show_sheet("wars", "War & Politics", "\n".join(lines), [["Close", _close_sheet, true]])


func _open_activity() -> void:
	var lines: Array[String] = []
	for entry in world.activity_log.slice(0, 8):
		var h := int(float(entry.get("hour", 0.0)))
		lines.append("Day %d · %s" % [h / 24 + 1, entry.get("text", "")])
	if lines.is_empty():
		lines.append("The roads are quiet. News of raids, battles and marshal armies will appear here.")
	_show_sheet("activity", "Recent activity", "\n".join(lines), [["Close", _close_sheet, true]])


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


func _on_new_campaign() -> void:
	Scenes.go("res://scenes/new_campaign.tscn")


func _refresh_hud() -> void:
	var h := int(world.hour)
	clock_label.text = "Day %d · %02d:00" % [h / 24 + 1, h % 24]
	speed_button.text = "2×" if speed > 1.5 else "1×"
	var modal := _sheet in ["encounter", "notice", "warning"]
	warband_button.disabled = modal
	next_button.disabled = modal
	speed_button.disabled = modal or _sheet == "menu"
	for badge in resource_buttons.values():
		badge.disabled = modal
	var days: int = GameState.food_days()
	resource_buttons["silver"].text = "%s\nSilver" % _short_amount(GameState.silver)
	resource_buttons["food"].text = "%sd\nFood" % _short_amount(days)
	resource_buttons["renown"].text = "%s\nRenown" % _short_amount(GameState.renown)
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
	if at_risk:
		status_label.text += "\nLow supplies: men may leave."
	status_label.add_theme_color_override("font_color", Style.ENEMY_LIGHT if at_risk else Style.MUTED)




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
	for b in world.bands():
		things.append({"y": world.party_pos(b).y, "band": b})
	for lp in world.visible_lord_parties():
		things.append({"y": world.party_pos(lp).y, "lord": lp})
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


func _draw_settlement(id: String, px: float) -> void:
	var s := Data.settlement(id)
	var c := _to_screen(s["pos"])
	# Built by its own people, flying its holder's colors.
	var culture := Data.culture_of(s["faction"])
	var colors := Cultures.color(Data.culture_of(world.owner_of(id)))
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
		# Smoke still rising from the ruins.
		for k in 3:
			var rise := fmod(_clock * 0.6 + k * 0.33, 1.0)
			draw_circle(Vector2(-3.0 + k * 3.0, -10.0 - rise * 14.0), 2.0 + rise * 3.0, Color(0.25, 0.23, 0.22, 0.45 * (1.0 - rise)))
	elif condition == "recovering":
		# Pale new timbers distinguish rebuilding from an actively ruined village.
		draw_line(Vector2(-9, -12), Vector2(-9, 2), Color("c59555"), 2.0)
		draw_line(Vector2(9, -12), Vector2(9, 2), Color("c59555"), 2.0)
		draw_line(Vector2(-11, -7), Vector2(11, -7), Color("d5ae6c"), 2.0)
	if String(presentation.get("garrison", "none")) == "thin" and String(s["type"]) != Data.VILLAGE:
		draw_arc(Vector2.ZERO, MapArt.size(sprite).x * 0.58, 0.18, PI - 0.18, 14, Style.ENEMY_LIGHT, 1.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A party on the road: your rider under your banner, or a bandit band. Walks while it
## moves, facing the way it's going.
func _draw_party(p, sprite: String, color: Color, px: float) -> void:
	var at: Vector2 = world.party_pos(p)
	var base := _to_screen(at)
	var army: Dictionary = world.MarshalArmies.for_party(world, p.id)
	if not army.is_empty() and army["state"] != "gathering":
		draw_arc(base, 18 * px, 0, TAU, 28, Style.BRASS, 3.0)
		draw_arc(base, 22 * px, 0, TAU, 28, Color(Style.BRASS, 0.55), 2.0)
	elif sprite == "bandits":
		var r := 15.0 * px
		draw_polyline(PackedVector2Array([base + Vector2(0, -r), base + Vector2(r, 0), base + Vector2(0, r),
			base + Vector2(-r, 0), base + Vector2(0, -r)]), Style.ENEMY_LIGHT, 2.0)
	var moving: bool = p.moving() and (world.busy() or p != world.player())
	var facing := 1.0
	if p.moving() and Data.pos(p.next).x < at.x:
		facing = -1.0
	var frame := int(_clock * 6.0) % 2 if moving else 0
	var mine := sprite == "rider"
	draw_set_transform(base + Vector2(0, 2), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 8.0 * px, Color(0, 0, 0, 0.28))
	if mine:
		draw_arc(Vector2.ZERO, 9.5 * px, 0.0, TAU, 32, Style.BRASS, 2.5 / 0.35)
	draw_set_transform(base, 0.0, Vector2(px * facing, px))
	draw_texture(MapArt.texture(sprite, frame, color), -MapArt.pivot(sprite))
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
		_name_plate(_to_screen(world.party_pos(b)) + Vector2(0, -17.0 * px - 6.0), b.name, 17, Color("e8d9c0"))
	# Lords' names only once you're looking closely, or the map drowns in them.
	if px >= LORD_NAMES_PX:
		for lp in world.visible_lord_parties():
			var army: Dictionary = world.MarshalArmies.for_party(world, lp.id)
			var title: String = "MARSHAL ARMY · %s" % lp.name if not army.is_empty() and army["state"] != "gathering" else String(lp.name)
			_name_plate(_to_screen(world.party_pos(lp)) + Vector2(0, -23.0 * px - 6.0), title, 15,
				Cultures.color(Data.culture_of(lp.faction)).lightened(0.45))


## A name on a dark plate, centered on `at` (the plate's top edge).
func _name_plate(at: Vector2, text: String, size: int, color: Color) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var rect := Rect2(at + Vector2(-w * 0.5 - 8.0, 0.0), Vector2(w + 16.0, size + 8.0))
	if _plate == null:
		_plate = Style.box(Color(0.06, 0.07, 0.1, 0.62), Color(0, 0, 0, 0), 0, 8)
	_plate.draw(labels.get_canvas_item(), rect)
	labels.draw_string(font, rect.position + Vector2(8.0, size * 0.92 + 3.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


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
