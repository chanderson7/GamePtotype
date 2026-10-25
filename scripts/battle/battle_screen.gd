## The battle screen: draws the simulation, turns taps into deployments and orders,
## and runs the HUD. All rules live in battle_sim.gd.
##
## Controls: tap a card, then tap your half of the field to deploy that squad.
## Tap one of your squads to select it, then tap an enemy squad to attack it or
## open ground to march there and hold. "Advance" sends it back on the offensive.
extends Node2D

const Sim = preload("res://scripts/battle/battle_sim.gd")
const Commander = preload("res://scripts/battle/commander_ai.gd")
const Troops = preload("res://scripts/data/troops.gd")
const Style = preload("res://scripts/ui/style.gd")

const TOP_BAR := 72.0
const BOTTOM_PANEL := 244.0
const ARROW_COLOR := Color("f4efe1")
## Men are drawn bigger than their collision size so they read on a phone screen.
const BODY_SCALE := 1.35

var sim: Sim
var field_origin := Vector2.ZERO
var field_scale := 1.0
var selected_card := -1
var selected_squad = null
var speed := 1.0
var autoplay := false
var floaters: Array = []
var font: Font

var _accumulator := 0.0
var _result_shown := false
var _left_battle := false
var _pending_result := {}
var _retreat_armed := 0.0
var _card_selected_box: StyleBoxFlat

var timer_label: Label
var meter_bar: ProgressBar
var meter_label: Label
var card_buttons: Array = []
var reserve_label: Label
var hint_label: Label
var advance_button: Button
var retreat_button: Button
var result_panel: PanelContainer
var result_title: Label
var result_body: Label


func _ready() -> void:
	font = ThemeDB.fallback_font
	# `-- --autoplay` lets the computer fight both sides (used for headless smoke tests).
	autoplay = OS.get_cmdline_user_args().has("--autoplay")
	sim = Sim.new()
	sim.setup(GameState.army, GameState.enemy_army())
	sim.ai[Sim.ENEMY] = Commander.new(Sim.ENEMY)
	if autoplay:
		sim.ai[Sim.PLAYER] = Commander.new(Sim.PLAYER)
		speed = 4.0
	_build_hud()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_refresh_hud()


func _exit_tree() -> void:
	if sim != null:
		sim.dispose()


func _layout() -> void:
	var vs := get_viewport_rect().size
	var avail := Vector2(vs.x - 16.0, vs.y - TOP_BAR - BOTTOM_PANEL - 16.0)
	field_scale = maxf(0.1, minf(avail.x / Sim.ARENA.x, avail.y / Sim.ARENA.y))
	var drawn := Sim.ARENA * field_scale
	field_origin = Vector2((vs.x - drawn.x) * 0.5, TOP_BAR + 8.0 + (avail.y - drawn.y) * 0.5)
	queue_redraw()


func _process(delta: float) -> void:
	if sim.winner == -1:
		_accumulator += minf(delta, 0.1) * speed
		var steps := 0
		while _accumulator >= Sim.STEP and steps < 16:
			sim.step()
			_accumulator -= Sim.STEP
			steps += 1
		_consume_events()
		if selected_squad != null and not selected_squad.is_active():
			selected_squad = null
	elif not _result_shown:
		_consume_events()
		_show_result()
	for f in floaters:
		f["age"] += delta
	floaters = floaters.filter(func(f): return f["age"] < 1.3)
	_refresh_hud()
	queue_redraw()


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if sim.winner != -1:
		return
	var p := (mb.position - field_origin) / field_scale
	if p.x < 0.0 or p.y < 0.0 or p.x > Sim.ARENA.x or p.y > Sim.ARENA.y:
		return
	get_viewport().set_input_as_handled()
	_tap_field(p)


func _tap_field(p: Vector2) -> void:
	# A card is selected: deploy it here.
	if selected_card != -1:
		if not sim.in_deploy_zone(Sim.PLAYER, p):
			_hint("Deploy in your half of the field, below the line.")
		elif not sim.can_afford(Sim.PLAYER, selected_card):
			_hint("Not enough command yet. The meter refills over time.")
		elif sim.deploy(Sim.PLAYER, selected_card, p) != null:
			selected_card = -1
			_hint("Deployed. It will advance on its own; tap it to give orders.")
		return

	# Tapped one of your squads: select it, or deselect it.
	var mine = sim.squad_at(Sim.PLAYER, p)
	if mine != null and mine.is_active():
		selected_squad = null if mine == selected_squad else mine
		if selected_squad != null:
			_hint("%s selected. Tap an enemy squad to attack, or open ground to march and hold." % Troops.display_name(mine.type))
		return
	if selected_squad == null:
		return

	# A squad is selected: an enemy squad means attack, anything else means march there.
	var foe = sim.squad_at(Sim.ENEMY, p, 52.0)
	if foe != null and foe.is_active():
		sim.order_attack(selected_squad, foe)
		_hint("Attacking the enemy %s." % Troops.display_name(foe.type).to_lower())
	else:
		sim.order_move(selected_squad, p)
		_hint("Marching. They will hold that ground and fight anyone who comes close.")
	selected_squad = null


func _on_card(index: int) -> void:
	if sim.winner != -1:
		return
	selected_squad = null
	selected_card = -1 if selected_card == index else index
	if selected_card != -1:
		var entry: Dictionary = sim.hand(Sim.PLAYER)[index]
		var type: String = entry["type"]
		_hint("%s: %s" % [Troops.display_name(type), Troops.stats(type)["blurb"]])
	queue_redraw()


func _on_advance() -> void:
	if selected_squad != null:
		sim.order_advance(selected_squad)
		_hint("Advancing on the nearest enemy.")
		selected_squad = null


func _on_retreat() -> void:
	if sim.winner != -1:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now < _retreat_armed:
		sim.concede(Sim.PLAYER)
		return
	_retreat_armed = now + 3.0
	retreat_button.text = "Sure?"
	get_tree().create_timer(3.0).timeout.connect(_reset_retreat_label)


func _reset_retreat_label() -> void:
	if is_instance_valid(retreat_button):
		retreat_button.text = "Retreat"


func _hint(text: String) -> void:
	if hint_label != null:
		hint_label.text = text


# ---------------------------------------------------------------- results

func _consume_events() -> void:
	for e in sim.events:
		match e["type"]:
			"rout":
				var sq = e["squad"]
				var mine: bool = sq.team == Sim.PLAYER
				_float_text("ROUTED", sq.average_pos() + Vector2(0, -56), Style.ENEMY_LIGHT if mine else Style.PLAYER_LIGHT)
				if mine:
					_hint("One of your squads broke and is running for the edge. Men who escape live to fight again.")
			"charge":
				_float_text("CHARGE", e["pos"], Style.BRASS)
	sim.events.clear()


func _float_text(text: String, at: Vector2, color: Color) -> void:
	for f in floaters:
		if f["text"] == text and at.distance_to(f["pos"]) < 70.0 and f["age"] < 0.6:
			return
	floaters.append({"text": text, "pos": at, "color": color, "age": 0.0})


func _show_result() -> void:
	_result_shown = true
	selected_card = -1
	selected_squad = null
	_pending_result = sim.result_for(Sim.PLAYER)
	var won: bool = _pending_result["won"]
	var reasons := {
		"banner": ["The enemy banner has fallen.", "Your banner has fallen."],
		"rout": ["Their army broke and fled.", "Your army broke and fled."],
		"time": ["Time ran out with you holding more of the field.", "Time ran out with them holding more of the field."],
		"retreat": ["The enemy withdrew.", "You pulled your army off the field."],
	}
	var why: String = reasons.get(_pending_result["reason"], ["", ""])[0 if won else 1]
	result_title.text = "Victory" if won else "Defeat"
	result_title.add_theme_color_override("font_color", Style.BRASS if won else Style.ENEMY_LIGHT)
	result_body.text = "%s\nYou lost %d men and cut down %d.\nSurvivors return to camp; losses carry over." % [
		why, _pending_result["lost"], _pending_result["killed"]]
	result_panel.visible = true
	if autoplay:
		get_tree().create_timer(0.8).timeout.connect(_back_to_camp)


func _back_to_camp() -> void:
	if _left_battle:
		return
	_left_battle = true
	if _pending_result.is_empty():
		_pending_result = sim.result_for(Sim.PLAYER)
	GameState.apply_result(_pending_result)
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


# ---------------------------------------------------------------- HUD

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var hud := Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.theme = Style.make_theme()
	layer.add_child(hud)
	_card_selected_box = Style.box(Style.RAISED.lightened(0.12), Style.BRASS, 3)

	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", Style.box(Style.NIGHT, Color(0, 0, 0, 0), 0, 0))
	top.anchor_right = 1.0
	top.offset_bottom = TOP_BAR
	hud.add_child(top)
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	top.add_child(top_row)
	top_row.add_child(Style.label("Field battle", 24, Style.BRASS))
	timer_label = Style.label("3:00", 28)
	timer_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_row.add_child(timer_label)
	advance_button = Button.new()
	advance_button.text = "Advance"
	advance_button.custom_minimum_size = Vector2(130, 52)
	advance_button.pressed.connect(_on_advance)
	top_row.add_child(advance_button)
	retreat_button = Button.new()
	retreat_button.text = "Retreat"
	retreat_button.custom_minimum_size = Vector2(120, 52)
	retreat_button.pressed.connect(_on_retreat)
	top_row.add_child(retreat_button)

	var bottom := PanelContainer.new()
	bottom.add_theme_stylebox_override("panel", Style.box(Style.NIGHT, Color(0, 0, 0, 0), 0, 0))
	bottom.anchor_top = 1.0
	bottom.anchor_bottom = 1.0
	bottom.anchor_right = 1.0
	bottom.offset_top = -BOTTOM_PANEL
	hud.add_child(bottom)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	bottom.add_child(col)

	var meter_row := HBoxContainer.new()
	meter_row.add_theme_constant_override("separation", 12)
	col.add_child(meter_row)
	meter_row.add_child(Style.label("Command", 20, Style.MUTED))
	meter_bar = ProgressBar.new()
	meter_bar.max_value = Sim.MAX_POINTS
	meter_bar.show_percentage = false
	meter_bar.custom_minimum_size = Vector2(0, 24)
	meter_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meter_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	meter_row.add_child(meter_bar)
	meter_label = Style.label("5 / 10", 20)
	meter_label.custom_minimum_size = Vector2(72, 0)
	meter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	meter_row.add_child(meter_label)

	var cards_row := HBoxContainer.new()
	cards_row.add_theme_constant_override("separation", 8)
	col.add_child(cards_row)
	for i in Sim.HAND_SIZE:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 116)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 19)
		b.clip_text = true
		b.pressed.connect(_on_card.bind(i))
		cards_row.add_child(b)
		card_buttons.append(b)

	var info_row := HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 12)
	col.add_child(info_row)
	hint_label = Style.label("Tap a card, then tap your half of the field to deploy it.", 18, Style.MUTED)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_row.add_child(hint_label)
	reserve_label = Style.label("", 18, Style.MUTED)
	info_row.add_child(reserve_label)

	result_panel = PanelContainer.new()
	result_panel.anchor_left = 0.5
	result_panel.anchor_right = 0.5
	result_panel.anchor_top = 0.5
	result_panel.anchor_bottom = 0.5
	result_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	result_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	result_panel.visible = false
	hud.add_child(result_panel)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 18)
	result_panel.add_child(rv)
	result_title = Style.label("Victory", 64, Style.BRASS)
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rv.add_child(result_title)
	result_body = Style.label("", 22)
	result_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_body.custom_minimum_size = Vector2(520, 0)
	result_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rv.add_child(result_body)
	var back := Button.new()
	back.text = "Back to camp"
	back.custom_minimum_size = Vector2(0, 72)
	Style.make_primary(back)
	back.pressed.connect(_back_to_camp)
	rv.add_child(back)


func _refresh_hud() -> void:
	var left := maxf(0.0, Sim.TIME_LIMIT - sim.time)
	timer_label.text = "%d:%02d" % [floori(left / 60.0), int(left) % 60]
	var pts: float = sim.points[Sim.PLAYER]
	meter_bar.value = pts
	meter_label.text = "%d / %d" % [floori(pts), int(Sim.MAX_POINTS)]

	var cards: Array = sim.hand(Sim.PLAYER)
	if selected_card >= cards.size():
		selected_card = -1
	for i in card_buttons.size():
		var b: Button = card_buttons[i]
		if i >= cards.size():
			b.visible = false
			continue
		var e: Dictionary = cards[i]
		var type: String = e["type"]
		var level: int = e["level"]
		b.visible = true
		b.text = "%s\n%d men%s\nCost %d" % [Troops.display_name(type), e["men"], "" if level <= 1 else " · Lv%d" % level, Troops.cost(type)]
		b.modulate = Color(1, 1, 1, 1) if sim.can_afford(Sim.PLAYER, i) else Color(1, 1, 1, 0.5)
		if i == selected_card:
			b.add_theme_stylebox_override("normal", _card_selected_box)
			b.add_theme_stylebox_override("hover", _card_selected_box)
		else:
			b.remove_theme_stylebox_override("normal")
			b.remove_theme_stylebox_override("hover")

	var extra: int = sim.reserves[Sim.PLAYER].size() - cards.size()
	if extra > 0:
		reserve_label.text = "+%d in reserve" % extra
	elif cards.size() > 0:
		reserve_label.text = "Last squads"
	else:
		reserve_label.text = "All deployed"
	advance_button.visible = selected_squad != null
	retreat_button.disabled = sim.winner != -1


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	if sim == null:
		return
	draw_set_transform(field_origin, 0.0, Vector2(field_scale, field_scale))
	_draw_field()
	for c in sim.corpses:
		var dark := Style.PLAYER_DARK if c["team"] == Sim.PLAYER else Style.ENEMY_DARK
		draw_circle(c["pos"], 5.0, Color(dark, 0.5))
	_draw_banner(sim.banners[Sim.PLAYER])
	_draw_banner(sim.banners[Sim.ENEMY])
	_draw_orders()
	for sq in sim.squads:
		_draw_men(sq)
	for p in sim.projectiles:
		var to: Vector2 = p.aim - p.pos
		if to.length() > 0.01:
			draw_line(p.pos, p.pos - to.normalized() * 11.0, ARROW_COLOR, 2.0)
	var placed: Array = []
	for sq in sim.squads:
		_draw_flag(sq, placed)
	_draw_floaters()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_field() -> void:
	var w := Sim.ARENA.x
	var h := Sim.ARENA.y
	var band := 110.0
	var y := 0.0
	var i := 0
	while y < h:
		draw_rect(Rect2(0.0, y, w, minf(band, h - y)), Style.FIELD_A if i % 2 == 0 else Style.FIELD_B)
		y += band
		i += 1
	draw_dashed_line(Vector2(0.0, Sim.MID_Y), Vector2(w, Sim.MID_Y), Color(1, 1, 1, 0.35), 3.0, 14.0)
	if selected_card != -1:
		var zone := Rect2(30.0, Sim.MID_Y + 50.0, w - 60.0, Sim.ARENA.y - 100.0 - (Sim.MID_Y + 50.0))
		draw_rect(zone, Color(Style.PLAYER, 0.2))
		draw_rect(zone, Color(Style.PLAYER_LIGHT, 0.8), false, 3.0)
	draw_rect(Rect2(Vector2.ZERO, Sim.ARENA), Color(0, 0, 0, 0.4), false, 4.0)


func _draw_banner(b) -> void:
	var base: Vector2 = b.pos
	var mine: bool = b.team == Sim.PLAYER
	var col := Style.PLAYER if mine else Style.ENEMY
	var light := Style.PLAYER_LIGHT if mine else Style.ENEMY_LIGHT
	draw_circle(base + Vector2(0, 8), 34.0, Color(0, 0, 0, 0.2))
	if b.alive:
		draw_line(base + Vector2(0, 16), base + Vector2(0, -50), Style.BRASS, 4.0)
		var flag := PackedVector2Array([
			base + Vector2(2, -50), base + Vector2(46, -44), base + Vector2(32, -32),
			base + Vector2(46, -20), base + Vector2(2, -24)])
		draw_colored_polygon(flag, col.lerp(Color.WHITE, b.flash * 0.6))
		flag.append(flag[0])
		draw_polyline(flag, light, 2.0)
	else:
		draw_line(base + Vector2(-30, 12), base + Vector2(30, 2), Style.BRASS.darkened(0.4), 4.0)
	var bw := 120.0
	var bar := Rect2(base.x - bw * 0.5, base.y + 22.0, bw, 8.0)
	draw_rect(bar, Color(0, 0, 0, 0.6))
	draw_rect(Rect2(bar.position, Vector2(bw * b.hp / b.max_hp, 8.0)), light)


func _draw_orders() -> void:
	var sq = selected_squad
	if sq == null or not sq.is_active():
		return
	var from: Vector2 = sq.average_pos()
	if sq.order == "move" or sq.order == "hold":
		var to: Vector2 = sq.order_point
		draw_dashed_line(from, to, Style.BRASS, 3.0, 12.0)
		draw_arc(to, 16.0, 0.0, TAU, 24, Style.BRASS, 3.0)
	elif sq.order == "attack" and sq.order_target != null and sq.order_target.is_active():
		draw_dashed_line(from, sq.order_target.average_pos(), Style.ENEMY_LIGHT, 3.0, 12.0)


func _draw_men(sq) -> void:
	var mine: bool = sq.team == Sim.PLAYER
	var col := Style.PLAYER if mine else Style.ENEMY
	var dark := Style.PLAYER_DARK if mine else Style.ENEMY_DARK
	var light := Style.PLAYER_LIGHT if mine else Style.ENEMY_LIGHT
	if sq.routing:
		col = col.lerp(Color(0.8, 0.8, 0.8), 0.55)
	var r: float = float(sq.stats["radius"]) * BODY_SCALE
	var selected: bool = sq == selected_squad
	for so in sq.soldiers:
		if not so.alive:
			continue
		var p: Vector2 = so.pos
		var f: Vector2 = so.facing
		var side := Vector2(-f.y, f.x)
		var c := col.lerp(Color.WHITE, float(so.flash) * 0.7)
		if sq.type == Troops.CAVALRY:
			var body := PackedVector2Array([p + f * (r + 5.0), p + side * (r * 0.75), p - f * (r + 3.0), p - side * (r * 0.75)])
			draw_colored_polygon(body, dark)
			draw_circle(p, r * 0.62, c)
		else:
			draw_circle(p, r, dark)
			draw_circle(p, r - 1.6, c)
		if sq.type == Troops.SPEARMEN:
			draw_line(p + f * 2.0, p + f * (r + 13.0), Style.TEXT, 2.0)
		elif sq.type == Troops.INFANTRY:
			draw_line(p + f * (r - 1.0) + side * 4.5, p + f * (r - 1.0) - side * 4.5, light, 3.0)
		elif sq.type == Troops.ARCHERS:
			draw_arc(p, r + 1.5, f.angle() - 0.9, f.angle() + 0.9, 8, light, 2.0)
		if selected:
			draw_arc(p, r + 3.5, 0.0, TAU, 16, Style.BRASS, 2.0)


## Flags stack upward instead of covering each other when squads crowd together.
func _draw_flag(sq, placed: Array) -> void:
	if sq.alive_count() == 0:
		return
	var mine: bool = sq.team == Sim.PLAYER
	var p: Vector2 = sq.average_pos() + Vector2(0, -46)
	var w := 78.0
	var h := 28.0
	var rect := Rect2(p.x - w * 0.5, p.y - h * 0.5, w, h)
	for attempt in 6:
		var clear := true
		for other in placed:
			if other.intersects(rect.grow(3.0)):
				clear = false
				break
		if clear:
			break
		rect.position.y -= h + 8.0
	placed.append(rect)
	draw_rect(rect, Color(Style.NIGHT, 0.85))
	draw_rect(Rect2(rect.position, Vector2(6, h)), Style.PLAYER if mine else Style.ENEMY)
	if sq == selected_squad:
		draw_rect(rect, Style.BRASS, false, 2.0)
	var label := "%s %d" % [String(sq.stats["short"]), sq.alive_count()]
	draw_string(font, Vector2(rect.position.x + 11.0, rect.position.y + 21.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Style.TEXT)
	var m := clampf(float(sq.morale) / 100.0, 0.0, 1.0)
	draw_rect(Rect2(rect.position.x, rect.end.y + 2.0, w, 4.0), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(rect.position.x, rect.end.y + 2.0, w * m, 4.0), Style.ENEMY_LIGHT if sq.routing else Style.BRASS)


func _draw_floaters() -> void:
	for f in floaters:
		var age: float = f["age"]
		var a := clampf(1.3 - age, 0.0, 1.0)
		var pos: Vector2 = f["pos"] + Vector2(-110.0, -age * 40.0)
		var color: Color = f["color"]
		draw_string_outline(font, pos, f["text"], HORIZONTAL_ALIGNMENT_CENTER, 220.0, 26, 6, Color(0, 0, 0, a))
		draw_string(font, pos, f["text"], HORIZONTAL_ALIGNMENT_CENTER, 220.0, 26, Color(color, a))
