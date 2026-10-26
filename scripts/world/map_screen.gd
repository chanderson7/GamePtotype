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
const SKY_SHADER = preload("res://shaders/map_sky.gdshader")

const TOP_BAR := 122.0
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
## Dust kicked up behind the warband on the road: [{pos, age}] in map units.
var _dust: Array = []
var _dust_clock := 0.0
var _music_clock := 0.0

var terrain
var backdrop
var sky: ColorRect
var labels: Node2D
var _plate: StyleBoxFlat

var top_panel: PanelContainer
var clock_label: Label
var purse_label: Label
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
	if world.encounter != -1:
		_open_encounter()
	elif GameState.map_notice != "":
		_open_notice(GameState.map_notice)
		GameState.map_notice = ""
	elif world.here() != "":
		_open_here()


func _exit_tree() -> void:
	Sound.set_loop("")


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
	if autoplay:
		_autoplay()
	# An encounter or a note about the last battle holds the clock until it's answered.
	if world.busy() and _sheet != "encounter" and _sheet != "notice":
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
			"encounter":
				GameState.save_game()
				_open_encounter()
	world.events.clear()
	# Men deserting on the road: say so, and hold the clock while the player reads it.
	if GameState.map_notice != "" and _sheet != "encounter" and _sheet != "notice":
		_open_notice(GameState.map_notice, "On the road")
		Sound.play("page")
		GameState.map_notice = ""
	_clock += delta
	_music_clock -= delta
	if _music_clock <= 0.0:
		_music_clock = 0.5
		_update_music()
	var riding: bool = world.player().moving() and world.busy() and _sheet != "encounter" and _sheet != "notice"
	Sound.set_loop("hooves" if riding else "")
	_kick_dust(delta)
	_refresh_hud()
	_sync_layers()
	queue_redraw()


## The smoke test: ride at the nearest band and fight it, send the men in against the
## next, then go into the next settlement you reach and spend there.
func _autoplay() -> void:
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
		if at.distance_to(_to_screen(world.party_pos(b)) + Vector2(0, -14) * _sprite_px()) < TAP_RADIUS:
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
	purse_label = Style.label("", Style.SMALL, Style.TEXT)
	purse_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	purse_label.custom_minimum_size = Vector2(10, 0)
	col.add_child(purse_label)
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
	var body := "%s\n%s away%s." % [world.describe(id), _hours_text(hours), sea]
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
	var body := "%s\nYou are here. " % world.describe(id)
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
	var fighters := []
	for s in GameState.army:
		if int(s["men"]) > 0:
			fighters.append(s)
	var plan: Dictionary = GameState.encounter_plan(b)
	var objective: String = plan["objective"]
	var site: Dictionary = plan["site"]
	var is_ambush := objective == "ambush"
	var title := "%s block the road" % b.name
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


func _open_notice(text: String, title: String = "After the battle") -> void:
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
	Scenes.go("res://scenes/settlement.tscn")


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
	var days: int = GameState.food_days()
	purse_label.text = "%d silver · food for %s · %d renown" % [GameState.silver,
		"1 day" if days == 1 else "%d days" % days, GameState.renown]
	var short: bool = days < 2 or GameState.silver < GameState.daily_wages()
	purse_label.add_theme_color_override("font_color", Style.ENEMY_LIGHT if short else Style.TEXT)
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


func _kick_dust(delta: float) -> void:
	for d in _dust:
		d["age"] = float(d["age"]) + delta
	_dust = _dust.filter(func(d): return float(d["age"]) < 1.2)
	var p = world.player()
	if not p.moving() or not world.busy():
		return
	_dust_clock -= delta * speed
	if _dust_clock <= 0.0:
		_dust_clock = 0.22
		_dust.append({"pos": world.party_pos(p), "age": 0.0})


# ---------------------------------------------------------------- drawing

## Settlements and parties, front to back by how far down the map they stand.
func _draw() -> void:
	if world == null:
		return
	var px := _sprite_px()
	for d in _dust:
		var age: float = d["age"]
		draw_circle(_to_screen(d["pos"]) + Vector2(0, -2), (2.0 + age * 5.0) * px * 0.5, Color(0.85, 0.78, 0.6, 0.35 * (1.0 - age / 1.2)))
	var things := []
	for id in Data.SETTLEMENTS:
		things.append({"y": Data.pos(id).y, "settlement": id})
	for b in world.bands():
		things.append({"y": world.party_pos(b).y, "band": b})
	things.append({"y": world.party_pos(world.player()).y + 0.5, "player": true})
	things.sort_custom(func(a, b): return a["y"] < b["y"])
	for t in things:
		if t.has("settlement"):
			_draw_settlement(t["settlement"], px)
		elif t.has("band"):
			_draw_party(t["band"], "bandits", Color.WHITE, px)
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
	draw_texture(MapArt.texture(sprite, 0, colors), -MapArt.pivot(sprite))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A party on the road: your rider under your banner, or a bandit band. Walks while it
## moves, facing the way it's going.
func _draw_party(p, sprite: String, color: Color, px: float) -> void:
	var at: Vector2 = world.party_pos(p)
	var base := _to_screen(at)
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
