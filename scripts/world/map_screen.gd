## The world map: draws the Glass Sea and the parties on it, and turns taps into travel.
## All rules live in world_sim.gd; this screen never moves anyone itself.
##
## Tap a settlement to see it and ride there. Time passes while you ride or wait: one
## hour a second, or two at 2x. A bandit band on the road stops you; fight it or
## withdraw. Drag to look around, pinch or scroll to zoom, double-tap to find your party.
extends Node2D

const WorldSim = preload("res://scripts/world/world_sim.gd")
const Data = preload("res://scripts/world/world_data.gd")
const Cultures = preload("res://scripts/data/cultures.gd")
const Style = preload("res://scripts/ui/style.gd")
const Heraldry = preload("res://scripts/ui/heraldry.gd")

const TOP_BAR := 96.0
## Game hours that pass each real second at 1x.
const HOURS_PER_SECOND := 1.0
## How far you can zoom: map units across the screen, most and fewest.
const WIDEST_VIEW := 1050.0
const NARROWEST_VIEW := 260.0
## A tap this close (screen units) to a settlement or a party picks it.
const TAP_RADIUS := 46.0
## A press that moves less than this is a tap, not a drag.
const DRAG_SLOP := 14.0
const SEA := Color("1d3a48")
const SEA_LIGHT := Color("2a5062")
const LAND := {
	"vardmark": Color("5d7a43"),
	"kharzan": Color("b39a63"),
	"ryumon": Color("6b876e"),
}
const COAST := Color("1a2a22")
const ROAD := Color("e2cd98")
const SEA_LANE := Color("a8d2e6")
const BANDIT_CLOTH := Color("8a7f70")
const BANDIT_DARK := Color("4e463c")

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
var _decor: Array = []
var _save_clock := 0.0

var top_panel: PanelContainer
var clock_label: Label
var status_label: Label
var speed_button: Button
var warband_button: Button
var sheet_panel: PanelContainer
var sheet_title: Label
var sheet_body: Label
var sheet_row: HBoxContainer


func _ready() -> void:
	font = ThemeDB.fallback_font
	autoplay = OS.get_cmdline_user_args().has("--autoplay")
	world = GameState.world
	if world == null:
		get_tree().change_scene_to_file.call_deferred("res://scenes/title.tscn")
		return
	if autoplay:
		speed = 8.0
		if GameState.autoplay_battles >= 2:
			get_tree().quit.call_deferred()
			return
	_build_decor()
	_build_hud()
	get_viewport().size_changed.connect(_layout)
	_layout()
	cam_scale = _view.size.x / 640.0
	cam_center = world.party_pos(world.player())
	_clamp_camera()
	if world.encounter != -1:
		_open_encounter()
	elif GameState.map_notice != "":
		_open_notice(GameState.map_notice)
		GameState.map_notice = ""
	elif world.here() != "":
		_open_here()


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
	queue_redraw()


# ---------------------------------------------------------------- time

func _process(delta: float) -> void:
	# On the way out (no campaign, or the smoke test is done) the screen was never built.
	if world == null or top_panel == null:
		return
	if autoplay:
		_autoplay()
	# An encounter or a note about the last battle holds the clock until it's answered.
	if world.busy() and _sheet != "encounter" and _sheet != "notice":
		world.step(delta * speed * HOURS_PER_SECOND)
		_save_clock += delta
		if _save_clock > 5.0:
			_save_clock = 0.0
			GameState.save_game()
	for e in world.events:
		match e["type"]:
			"arrived", "waited":
				GameState.save_game()
				_open_here()
			"encounter":
				GameState.save_game()
				_open_encounter()
	world.events.clear()
	_refresh_hud()
	queue_redraw()


## The smoke test: ride at the nearest band, fight it, twice.
func _autoplay() -> void:
	if _sheet == "encounter":
		_on_fight()
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
	if _sheet == "encounter":
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
		if at.distance_to(_to_screen(world.party_pos(b)) + Vector2(10, -30)) < TAP_RADIUS:
			_open_band(b)
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
	hud.theme = Style.make_theme()
	layer.add_child(hud)

	top_panel = PanelContainer.new()
	top_panel.anchor_right = 1.0
	top_panel.offset_bottom = TOP_BAR
	hud.add_child(top_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	top_panel.add_child(row)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	row.add_child(col)
	clock_label = Style.label("", Style.BODY, Style.BRASS)
	col.add_child(clock_label)
	status_label = Style.label("", Style.SMALL, Style.MUTED)
	status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status_label.custom_minimum_size = Vector2(10, 0)
	col.add_child(status_label)
	speed_button = _button("1×", _on_speed)
	speed_button.custom_minimum_size = Vector2(Style.TOUCH, Style.TOUCH)
	row.add_child(speed_button)
	warband_button = _button("Warband", _on_warband)
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
	sheet_row = HBoxContainer.new()
	sheet_row.add_theme_constant_override("separation", 10)
	sv.add_child(sheet_row)


func _button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, Style.TOUCH)
	b.pressed.connect(callback)
	return b


func _show_sheet(kind: String, title: String, body: String, buttons: Array) -> void:
	_sheet = kind
	sheet_title.text = title
	sheet_body.text = body
	for c in sheet_row.get_children():
		c.queue_free()
	for spec in buttons:
		var b := _button(String(spec[0]), spec[1])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		if spec.size() > 2 and spec[2]:
			Style.make_primary(b)
		sheet_row.add_child(b)
	sheet_panel.visible = true


func _close_sheet() -> void:
	_sheet = ""
	sheet_panel.visible = false


func _describe_place(id: String) -> String:
	var s := Data.settlement(id)
	var faction: Dictionary = Data.FACTIONS[s["faction"]]
	var kind := String(s["type"]).capitalize()
	var line := "%s of the %s" % [kind, faction["name"]]
	if s["type"] == Data.TOWN and faction["capital"] == id:
		line = "Capital of the %s, seat of %s" % [faction["name"], faction["ruler"]]
	var people := String(Cultures.info(Data.culture_of(s["faction"]))["people"])
	return "%s · %s" % [line, people]


func _open_preview(id: String) -> void:
	var hours: float = world.hours_to(id)
	var sea := ""
	var route: Array = world.path(world.player().next if world.player().moving() else world.player().node, id)
	var a: String = world.player().node
	for b in route:
		if world.is_sea(a, b):
			sea = ", partly by sea"
		a = b
	var body := "%s\n%s away%s." % [_describe_place(id), _hours_text(hours), sea]
	_show_sheet("preview", String(Data.settlement(id)["name"]), body,
		[["Ride there", _on_travel.bind(id), true], ["Close", _close_sheet]])


func _open_here() -> void:
	var id: String = world.here()
	if id == "":
		_close_sheet()
		return
	_selected = id
	var buttons := [["Wait 8 hours", _on_wait]]
	if world.player_in_town() and GameState.is_wounded():
		buttons.append(["Rest and reinforce", _on_reinforce])
	buttons.append(["Warband", _on_warband])
	buttons.append(["Close", _close_sheet])
	var body := "%s\nYou are here." % _describe_place(id)
	if world.player_in_town() and not GameState.is_wounded():
		body += " Your warband is at full strength."
	_show_sheet("here", String(Data.settlement(id)["name"]), body, buttons)


func _open_band(b) -> void:
	var men := 0
	for sq in b.army:
		men += int(sq["men"])
	_show_sheet("band", b.name, "Bandits roaming the %s: %d squads, %d men. Ride into them to fight." % [
		Data.FACTIONS[b.faction]["name"], b.army.size(), men], [["Close", _close_sheet]])


func _open_encounter() -> void:
	var b = world.party(world.encounter)
	if b == null:
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
	_show_sheet("encounter", "%s block the road" % b.name,
		"%d squads, %d men: %s. Fight them, or withdraw to %s and lose the hours it takes." % [
			b.army.size(), men, ", ".join(parts), Data.settlement(world.player().node)["name"]],
		[["Fight", _on_fight, true], ["Withdraw", _on_withdraw]])


func _open_notice(text: String) -> void:
	if GameState.total_men() == 0:
		_show_sheet("notice", "Your warband is gone", text + " Raise a new one to ride again.",
			[["New campaign", _on_new_campaign, true]])
		return
	_show_sheet("notice", "After the battle", text, [["Carry on", _on_notice_done, true]])


func _on_notice_done() -> void:
	_close_sheet()
	if world.here() != "":
		_open_here()


func _hours_text(hours: float) -> String:
	var h := int(ceil(hours))
	if h >= 24:
		return "%d days %d hours" % [h / 24, h % 24] if h % 24 != 0 else "%d days" % (h / 24)
	return "%d hours" % h if h != 1 else "1 hour"


# ---------------------------------------------------------------- actions

func _on_travel(id: String) -> void:
	if world.travel(id):
		_close_sheet()
		GameState.save_game()


func _on_wait() -> void:
	if world.wait(8.0):
		_close_sheet()


func _on_reinforce() -> void:
	GameState.reinforce()
	_open_here()


func _on_warband() -> void:
	GameState.save_game()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _on_fight() -> void:
	GameState.start_encounter_battle()
	GameState.save_game()
	get_tree().change_scene_to_file("res://scenes/battle.tscn")


func _on_withdraw() -> void:
	world.withdraw()
	GameState.save_game()
	_close_sheet()
	_open_here()


func _on_speed() -> void:
	speed = 2.0 if speed < 1.5 else 1.0


func _on_new_campaign() -> void:
	get_tree().change_scene_to_file("res://scenes/new_campaign.tscn")


func _refresh_hud() -> void:
	var h := int(world.hour)
	clock_label.text = "Day %d · %02d:00" % [h / 24 + 1, h % 24]
	speed_button.text = "2×" if speed > 1.5 else "1×"
	var p = world.player()
	if world.encounter != -1:
		status_label.text = "Bandits block the road"
	elif p.moving():
		var to: String = world.destination()
		status_label.text = "Riding to %s · %s" % [Data.settlement(to)["name"], _hours_text(world.hours_to(to))]
	elif p.wait > 0.0:
		status_label.text = "Waiting at %s · %s" % [Data.settlement(p.node)["name"], _hours_text(p.wait)]
	else:
		status_label.text = "At %s" % Data.settlement(p.node)["name"]


# ---------------------------------------------------------------- drawing

## Trees in the north, dunes in the south, pines on the isles: scattered once, the same
## every time.
func _build_decor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1166
	for i in 900:
		var p := Vector2(rng.randf_range(0, Data.SIZE.x), rng.randf_range(0, Data.SIZE.y))
		var land := Data.land_at(p)
		if land == -1:
			continue
		var near_place := false
		for id in Data.SETTLEMENTS:
			if p.distance_to(Data.pos(id)) < 45.0:
				near_place = true
		if near_place:
			continue
		var realm := _realm_at(p, land)
		_decor.append({"pos": p, "realm": realm, "size": rng.randf_range(0.7, 1.3)})


func _realm_at(p: Vector2, land: int) -> String:
	if land == 1:
		return "ryumon"
	if Geometry2D.is_point_in_polygon(p, PackedVector2Array(Data.REALM_TINT["vardmark"])):
		return "vardmark"
	return "kharzan"


func _draw() -> void:
	if world == null:
		return
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), SEA)
	_draw_waves()
	_draw_land()
	_draw_decor()
	_draw_roads()
	_draw_route()
	for id in Data.SETTLEMENTS:
		_draw_settlement(id)
	for b in world.bands():
		_draw_party(world.party_pos(b), BANDIT_CLOTH, BANDIT_DARK, false, b.name)
	var culture_color := Cultures.color(world.culture)
	_draw_party(world.party_pos(world.player()), culture_color, culture_color.darkened(0.45), true, "")


func _draw_waves() -> void:
	var step := 70.0
	var y := fposmod(-cam_center.y * cam_scale, step)
	while y < get_viewport_rect().size.y:
		var x := fposmod(-cam_center.x * cam_scale * 0.5 + y * 0.37, step * 2.0) - step * 2.0
		while x < get_viewport_rect().size.x:
			draw_line(Vector2(x, y), Vector2(x + 14.0, y), Color(SEA_LIGHT, 0.6), 2.0)
			x += step * 2.0
		y += step


func _draw_land() -> void:
	var main := _screen_poly(Data.LAND[0])
	draw_colored_polygon(main, LAND["kharzan"])
	draw_colored_polygon(_screen_poly(Data.REALM_TINT["vardmark"]), LAND["vardmark"])
	var isle := _screen_poly(Data.LAND[1])
	draw_colored_polygon(isle, LAND["ryumon"])
	for poly in [main, isle]:
		var ring: PackedVector2Array = poly.duplicate()
		ring.append(poly[0])
		draw_polyline(ring, COAST, 4.0)
		draw_polyline(ring, Color(1, 1, 1, 0.12), 1.5)


func _screen_poly(points: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(_to_screen(p))
	return out


func _draw_decor() -> void:
	var k := clampf(cam_scale, 0.6, 1.6)
	for d in _decor:
		var p := _to_screen(d["pos"])
		if not _view.grow(20.0).has_point(p):
			continue
		var s: float = float(d["size"]) * 4.0 * k
		match String(d["realm"]):
			"vardmark":
				draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s * 1.6), p + Vector2(s, s * 0.6), p + Vector2(-s, s * 0.6)]), Color("3f5a2e"))
			"kharzan":
				draw_arc(p, s * 1.6, PI * 1.15, PI * 1.85, 8, Color("8f7a4a"), 2.0)
			"ryumon":
				draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s * 1.8), p + Vector2(s * 0.8, s * 0.5), p + Vector2(-s * 0.8, s * 0.5)]), Color("44624b"))


func _draw_roads() -> void:
	for r in Data.ROADS:
		var a := _to_screen(Data.pos(r[0]))
		var b := _to_screen(Data.pos(r[1]))
		if r[2]:
			draw_dashed_line(a, b, Color(SEA_LANE, 0.75), 2.0, 5.0)
		else:
			draw_line(a, b, Color(0, 0, 0, 0.25), 6.0)
			draw_dashed_line(a, b, ROAD, 3.0, 12.0)


## Where you're riding: a gold line through the settlements still ahead.
func _draw_route() -> void:
	var p = world.player()
	if not p.moving():
		return
	var pts := PackedVector2Array([_to_screen(world.party_pos(p)), _to_screen(Data.pos(p.next))])
	for id in p.path:
		pts.append(_to_screen(Data.pos(id)))
	for i in pts.size() - 1:
		draw_dashed_line(pts[i], pts[i + 1], Style.BRASS, 4.0, 10.0)
	draw_arc(pts[pts.size() - 1], 18.0, 0.0, TAU, 24, Style.BRASS, 3.0)


func _draw_settlement(id: String) -> void:
	var s := Data.settlement(id)
	var c := _to_screen(s["pos"])
	var color := Cultures.color(Data.culture_of(s["faction"]))
	var dark := color.darkened(0.5)
	if id == _selected:
		draw_circle(c, 30.0, Color(Style.BRASS, 0.18))
		draw_arc(c, 30.0, 0.0, TAU, 32, Style.BRASS, 3.0)
	match String(s["type"]):
		Data.TOWN:
			# A keep between two towers.
			draw_rect(Rect2(c + Vector2(-16, -12), Vector2(32, 22)), Color("d8d0bd"))
			draw_rect(Rect2(c + Vector2(-20, -20), Vector2(10, 30)), Color("c9c0aa"))
			draw_rect(Rect2(c + Vector2(10, -20), Vector2(10, 30)), Color("c9c0aa"))
			draw_rect(Rect2(c + Vector2(-20, -20), Vector2(40, 30)), COAST, false, 2.0)
			draw_rect(Rect2(c + Vector2(-4, -2), Vector2(8, 12)), Color("4a3a28"))
			Heraldry.flag(self, c + Vector2(-2, -38), Vector2(20, 14), color, dark, false)
			draw_line(c + Vector2(-2, -38), c + Vector2(-2, -20), COAST, 2.0)
		Data.CASTLE:
			draw_rect(Rect2(c + Vector2(-9, -18), Vector2(18, 28)), Color("c9c0aa"))
			draw_rect(Rect2(c + Vector2(-9, -18), Vector2(18, 28)), COAST, false, 2.0)
			for i in 3:
				draw_rect(Rect2(c + Vector2(-9 + i * 7, -23), Vector2(4, 5)), Color("c9c0aa"))
			Heraldry.flag(self, c + Vector2(0, -38), Vector2(18, 12), color, dark, false)
			draw_line(c + Vector2(0, -38), c + Vector2(0, -23), COAST, 2.0)
		_:
			draw_colored_polygon(PackedVector2Array([c + Vector2(-10, -2), c + Vector2(0, -12), c + Vector2(10, -2)]), Color("8a4b32"))
			draw_rect(Rect2(c + Vector2(-8, -2), Vector2(16, 11)), Color("d9c9a3"))
			draw_rect(Rect2(c + Vector2(-8, -2), Vector2(16, 11)), COAST, false, 1.5)
			draw_rect(Rect2(c + Vector2(-8, -16), Vector2(5, 4)), color)
	var label := String(s["name"])
	var size := Style.SMALL if s["type"] != Data.VILLAGE else 20
	var at := c + Vector2(-120, 34)
	draw_string_outline(font, at, label, HORIZONTAL_ALIGNMENT_CENTER, 240.0, size, 6, Color(0, 0, 0, 0.75))
	draw_string(font, at, label, HORIZONTAL_ALIGNMENT_CENTER, 240.0, size, Style.TEXT)


func _draw_party(at: Vector2, cloth: Color, dark: Color, mine: bool, label: String) -> void:
	var base := _to_screen(at)
	draw_set_transform(base + Vector2(2, 3), 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 9.0, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var top := base + Vector2(0, -40)
	draw_line(base, top, Color("6b4a2a"), 3.0)
	draw_circle(top, 4.0, Style.BRASS)
	Heraldry.flag(self, top + Vector2(0, 2), Vector2(30, 22), cloth, dark, mine, "", false, mine, 0.0,
		Style.BRASS if mine else Heraldry.EDGE)
	if label != "":
		var at_text := base + Vector2(-110, -48)
		draw_string_outline(font, at_text, label, HORIZONTAL_ALIGNMENT_CENTER, 220.0, 18, 5, Color(0, 0, 0, 0.8))
		draw_string(font, at_text, label, HORIZONTAL_ALIGNMENT_CENTER, 220.0, 18, Color("e8d9c0"))
