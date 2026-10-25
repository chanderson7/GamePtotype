## The battle screen: draws the simulation, turns taps into placements and orders,
## and runs the HUD. All rules live in battle_sim.gd.
##
## Deployment: every squad in the warband is a card. Tap a card, then tap the blue zone
## to place it; tap a placed squad, then somewhere else to move it. Auto-place lines up
## whatever is left. Fight starts the battle once every squad is on the field.
##
## Battle: squads hold their ground until ordered. Advance and Hold command the whole
## army, or only the selected squad. With a squad selected, tap an enemy squad to attack
## it, or open ground to march there and hold.
extends Node2D

const Sim = preload("res://scripts/battle/battle_sim.gd")
const Commander = preload("res://scripts/battle/commander_ai.gd")
const Troops = preload("res://scripts/data/troops.gd")
const Style = preload("res://scripts/ui/style.gd")
const Art = preload("res://scripts/art/unit_art.gd")
const Captains = preload("res://scripts/data/captains.gd")
## When one of your captains goes down the battle slows to this pace for a moment.
const SLOWMO_PACE := 0.25
const SLOWMO_SECONDS := 1.4

const TOP_BAR := 76.0
const BOTTOM_PANEL := 256.0
const CARD_COLUMNS := 5
const ORDER_WORDS := {"hold": "holding", "advance": "advancing", "attack": "attacking", "move": "marching"}

var sim: Sim
var field_origin := Vector2.ZERO
var field_scale := 1.0
## Deployment: the roster id of the squad the next tap on the field puts down, or -1.
var selected_id := -1
## Battle: the squad Advance and Hold apply to. null means the whole army.
var selected_squad = null
var speed := 1.0
var autoplay := false
var floaters: Array = []
var _slowmo := 0.0
var font: Font

var _cards: Array = []
var _card_styles := {}
var _accumulator := 0.0
var _result_shown := false
var _left_battle := false
var _pending_result := {}
var _retreat_armed := 0.0

var title_label: Label
var status_label: Label
var auto_button: Button
var fight_button: Button
var retreat_button: Button
var deploy_box: GridContainer
var card_buttons: Array = []
var battle_box: VBoxContainer
var orders_label: Label
var strength_label: Label
var advance_button: Button
var hold_button: Button
var army_button: Button
var hint_label: Label
var result_panel: PanelContainer
var result_title: Label
var result_body: Label


func _ready() -> void:
	font = ThemeDB.fallback_font
	# Pixel art: hard edges, and the grass tile repeats.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	# `-- --autoplay` lets the computer fight both sides (used for headless smoke tests).
	autoplay = OS.get_cmdline_user_args().has("--autoplay")
	sim = Sim.new()
	sim.setup(GameState.army, GameState.enemy_army())
	# The enemy lines up first, so you can see what you're facing while you deploy.
	sim.ai[Sim.ENEMY] = Commander.new(Sim.ENEMY)
	sim.ai[Sim.ENEMY].deploy(sim)
	_cards = sim.roster(Sim.PLAYER)
	_build_hud()
	get_viewport().size_changed.connect(_layout)
	_layout()
	if autoplay:
		sim.ai[Sim.PLAYER] = Commander.new(Sim.PLAYER)
		sim.ai[Sim.PLAYER].deploy(sim)
		speed = 4.0
		_start_battle()
	else:
		_select_next_card()
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
	if sim.winner == -1 and sim.phase == Sim.PHASE_BATTLE:
		var pace := SLOWMO_PACE if _slowmo > 0.0 else 1.0
		_slowmo = maxf(0.0, _slowmo - delta)
		_accumulator += minf(delta, 0.1) * speed * pace
		var steps := 0
		while _accumulator >= Sim.STEP and steps < 16:
			sim.step()
			_accumulator -= Sim.STEP
			steps += 1
		_consume_events()
		if selected_squad != null and not selected_squad.is_active():
			selected_squad = null
	elif sim.winner != -1 and not _result_shown:
		_consume_events()
		_show_result()
	for f in floaters:
		f["age"] += delta
	floaters = floaters.filter(func(f): return f["age"] < f["life"])
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
	if sim.phase == Sim.PHASE_DEPLOY:
		_tap_deploy(p)
	else:
		_tap_battle(p)


func _tap_deploy(p: Vector2) -> void:
	var mine = sim.squad_at(Sim.PLAYER, p)
	if mine != null:
		if mine.roster_id == selected_id:
			_select_next_card() # tapping the picked-up squad again leaves it where it is
		else:
			selected_id = mine.roster_id
			_hint("Tap where you want your %s to stand." % _name(mine.type).to_lower())
		return
	var foe = sim.squad_at(Sim.ENEMY, p, 52.0)
	if foe != null:
		_hint(_describe(foe))
		return
	if selected_id == -1:
		if sim.all_placed(Sim.PLAYER):
			_hint("Tap one of your squads to move it, or press Fight.")
		else:
			_hint("Tap a card first.")
		return
	if not sim.in_deploy_zone(Sim.PLAYER, p):
		_hint("Place your squads in the blue zone, your half of the field.")
		return
	if sim.place(Sim.PLAYER, selected_id, p) == null:
		_hint("No room there. Try a more open spot.")
		return
	_select_next_card()


## Pick the first card not yet on the field, so placing a whole army is one tap per squad.
func _select_next_card() -> void:
	selected_id = -1
	for e in _cards:
		if sim.placed_squad(Sim.PLAYER, e["roster_id"]) == null:
			selected_id = e["roster_id"]
			_hint("Tap the blue zone to place your %s (%d men)." % [_name(e["type"]).to_lower(), e["men"]])
			return
	_hint("Your whole army is on the field. Tap a squad to move it, then press Fight.")


func _tap_battle(p: Vector2) -> void:
	var mine = sim.squad_at(Sim.PLAYER, p)
	if mine != null and mine.is_active():
		selected_squad = null if mine == selected_squad else mine
		if selected_squad != null:
			_hint("%s Orders now go to this squad only: tap an enemy squad to attack it, or open ground to march there." % _led_by(mine))
		else:
			_hint("Orders go to the whole army.")
		return
	var foe = sim.squad_at(Sim.ENEMY, p, 52.0)
	if selected_squad == null:
		if foe != null:
			_hint(_describe(foe))
		return
	if foe != null and foe.is_active():
		sim.order_attack(selected_squad, foe)
		_hint("Your %s attack the enemy %s." % [_name(selected_squad.type).to_lower(), _name(foe.type).to_lower()])
	else:
		sim.order_move(selected_squad, p)
		_hint("Your %s march there and hold." % _name(selected_squad.type).to_lower())


func _on_card(index: int) -> void:
	if sim.winner != -1 or sim.phase != Sim.PHASE_DEPLOY:
		return
	var e: Dictionary = _cards[index]
	if selected_id == e["roster_id"]:
		selected_id = -1
		_hint("Tap a card to place or move that squad.")
		return
	selected_id = e["roster_id"]
	var placed: bool = sim.placed_squad(Sim.PLAYER, selected_id) != null
	var level: int = e["level"]
	var veteran := " Level %d veterans." % level if level > 1 else ""
	_hint("%s%s %s" % [_card_story(e), veteran,
		"Tap the field to move them." if placed else "Tap the blue zone to place them."])


func _on_auto() -> void:
	sim.auto_deploy(Sim.PLAYER)
	_select_next_card()
	if sim.all_placed(Sim.PLAYER):
		_hint("Your army is in a battle line. Tap any squad to move it, then press Fight.")


func _on_fight() -> void:
	if sim.phase != Sim.PHASE_DEPLOY or sim.winner != -1:
		return
	if not sim.all_placed(Sim.PLAYER):
		_hint("Place every squad first, or tap Auto-place.")
		return
	_start_battle()


func _start_battle() -> void:
	sim.start_battle()
	selected_id = -1
	selected_squad = null
	_hint("Your squads hold their ground until ordered. Advance to attack, or Hold and let them come to you.")


func _on_advance() -> void:
	if sim.phase != Sim.PHASE_BATTLE or sim.winner != -1:
		return
	if selected_squad != null:
		sim.order_advance(selected_squad)
		_hint("Your %s advance on the enemy they fight best." % _name(selected_squad.type).to_lower())
	else:
		sim.order_all(Sim.PLAYER, "advance")
		_hint("The whole army advances. Each squad goes for the enemy it fights best.")


func _on_hold() -> void:
	if sim.phase != Sim.PHASE_BATTLE or sim.winner != -1:
		return
	if selected_squad != null:
		sim.order_hold(selected_squad)
		_hint("Your %s hold where they stand." % _name(selected_squad.type).to_lower())
	else:
		sim.order_all(Sim.PLAYER, "hold")
		_hint("The whole army holds. Squads fight anyone who comes close.")


func _on_army() -> void:
	selected_squad = null
	_hint("Orders go to the whole army.")


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


func _name(type: String) -> String:
	return Troops.display_name(type)


## "Brann's Shields, led by Brann of Ostmark (Vengeful, Lucky). Bonds: Mira (B)."
func _led_by(sq) -> String:
	if sq.info.is_empty():
		return "%s, without a captain." % (_company(sq.roster_id) if sq.team == Sim.PLAYER else _name(sq.type))
	var who := "%s, led by %s (%s)" % [_company(sq.roster_id), sq.info["name"], Captains.traits(sq.info)]
	if sq.captain == null:
		who = "%s. %s is down" % [_company(sq.roster_id), sq.info["name"]]
	return who + _bond_text(sq.info) + "."


func _card_story(e: Dictionary) -> String:
	var squad := _squad_record(e["roster_id"])
	var c = squad.get("captain")
	if c == null:
		return "%s have no captain." % squad.get("name", _name(e["type"]))
	if int(c.get("wounded", 0)) > 0:
		return "%s is wounded and sits this one out (%d more). %s fight without a captain." % [c["name"], c["wounded"], squad["name"]]
	return "%s, led by %s (%s)%s." % [squad["name"], c["name"], Captains.traits(c), _bond_text(c)]


func _bond_text(c: Dictionary) -> String:
	var parts := PackedStringArray()
	for other_id in c.get("bonds", {}):
		var rank := Captains.rank_letter(float(c["bonds"][other_id]))
		var other = GameState.captain_by_id(int(other_id))
		if rank != "" and other != null:
			parts.append("%s (%s)" % [other["first"], rank])
	return "" if parts.is_empty() else ". Bonds: " + ", ".join(parts)


func _squad_record(roster_id: int) -> Dictionary:
	for s in GameState.army:
		if int(s["id"]) == roster_id:
			return s
	return {}


func _company(roster_id: int) -> String:
	return String(_squad_record(roster_id).get("name", ""))


func _describe(sq) -> String:
	var text := "Enemy %s · %d men" % [_name(sq.type).to_lower(), sq.alive_count()]
	if not sq.info.is_empty():
		text += " · Captain %s%s" % [sq.info["name"], "" if sq.captain != null else " (down)"]
	if sq.level > 1:
		text += " · Lv%d" % sq.level
	if sq.arrows == 0:
		text += " · out of arrows"
	if sq.routing:
		text += " · running"
	elif sim.phase == Sim.PHASE_BATTLE:
		text += " · %d%% morale" % maxi(0, int(sq.morale))
	return "%s. %s" % [text, Troops.stats(sq.type)["blurb"]]


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
			"out_of_arrows":
				var sq = e["squad"]
				var mine: bool = sq.team == Sim.PLAYER
				_float_text("OUT OF ARROWS", sq.average_pos() + Vector2(0, -56), Style.PLAYER_LIGHT if mine else Style.ENEMY_LIGHT)
				if mine:
					_hint("Your archers are out of arrows and draw their blades. They are weak in a melee, so keep them out of one.")
			"captain_down":
				_captain_down(e)
			"grief":
				_grief(e)
	sim.events.clear()


func _captain_down(e: Dictionary) -> void:
	var sq = e["squad"]
	var info: Dictionary = sq.info
	var first := String(info.get("first", "Captain")).to_upper()
	if sq.team != Sim.PLAYER:
		_float_text("%s CUT DOWN" % first, e["pos"], Style.PLAYER_LIGHT, 2.2)
		_hint("You cut down %s, captain of the enemy %s. Their nerve wavers." % [info.get("name", ""), _name(sq.type).to_lower()])
		return
	_slowmo = SLOWMO_SECONDS
	var killed: bool = e["fate"] == "killed"
	_float_text("%s FALLS" % first if killed else "%s WOUNDED" % first, e["pos"], Style.ENEMY_LIGHT if killed else Style.BRASS, 3.0)
	if killed:
		_hint("\"%s\" %s is dead. Death roll %d; needed %d or more to live." % [sq.last_words, info["name"], e["roll"], e["needed"]])
	else:
		_hint("\"%s\" %s is down but alive. Death roll %d; needed %d or more. Out for %d battles." % [
			sq.last_words, info["name"], e["roll"], e["needed"], Captains.WOUND_BATTLES])


func _grief(e: Dictionary) -> void:
	var sq = e["squad"]
	if sq.team != Sim.PLAYER:
		return
	var who := String(sq.info.get("first", ""))
	var lost := String(e["for"].info.get("first", ""))
	match String(e["temperament"]):
		Captains.VENGEFUL:
			_float_text("FURY", sq.average_pos() + Vector2(0, -56), Style.ENEMY_LIGHT, 2.0)
			_hint("%s saw %s fall and is consumed by fury: harder blows, and no retreat for %d seconds." % [who, lost, int(Captains.FURY_SECONDS)])
		Captains.STEADFAST:
			_float_text("STEADY", sq.average_pos() + Vector2(0, -56), Style.BRASS, 2.0)
			_hint("%s saw %s fall, and steadies the line." % [who, lost])
		Captains.FRAGILE:
			_float_text("SHAKEN", sq.average_pos() + Vector2(0, -56), Style.MUTED, 2.0)
			_hint("%s saw %s fall and is shaken. Their squad's nerve is slipping." % [who, lost])


func _float_text(text: String, at: Vector2, color: Color, life: float = 1.3) -> void:
	for f in floaters:
		if f["text"] == text and at.distance_to(f["pos"]) < 70.0 and f["age"] < 0.6:
			return
	floaters.append({"text": text, "pos": at, "color": color, "age": 0.0, "life": life})


func _show_result() -> void:
	_result_shown = true
	selected_id = -1
	selected_squad = null
	_pending_result = sim.result_for(Sim.PLAYER)
	var won: bool = _pending_result["won"]
	var reasons := {
		"rout": ["Their army broke and fled.", "Your army broke and fled."],
		"time": ["Time ran out with more of your army still standing.", "Time ran out with more of theirs still standing."],
		"retreat": ["The enemy withdrew.", "You pulled your army off the field."],
	}
	var why: String = reasons.get(_pending_result["reason"], ["", ""])[0 if won else 1]
	result_title.text = "Victory" if won else "Defeat"
	result_title.add_theme_color_override("font_color", Style.BRASS if won else Style.ENEMY_LIGHT)
	var text := "%s\nYou lost %d men and cut down %d." % [why, _pending_result["lost"], _pending_result["killed"]]
	var fates: Array = GameState.describe_result(_pending_result)
	if not fates.is_empty():
		text += "\n\n" + "\n".join(PackedStringArray(fates))
	result_body.text = text
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
	_card_styles = {
		"normal": _card_box(Style.RAISED, Style.RULE, 2),
		"hover": _card_box(Style.RAISED.lightened(0.06), Style.MUTED, 2),
		"selected": _card_box(Style.RAISED.lightened(0.12), Style.BRASS, 3),
		"placed": _card_box(Style.PANEL, Style.PLAYER_DARK, 2),
	}

	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", Style.box(Style.NIGHT, Color(0, 0, 0, 0), 0, 0))
	top.anchor_right = 1.0
	top.offset_bottom = TOP_BAR
	hud.add_child(top)
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	top.add_child(top_row)
	title_label = Style.label("Deploy", 24, Style.BRASS)
	top_row.add_child(title_label)
	status_label = Style.label("", 22)
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top_row.add_child(status_label)
	strength_label = Style.label("", 20, Style.MUTED)
	top_row.add_child(strength_label)
	auto_button = _button("Auto-place", Vector2(140, 56), _on_auto)
	top_row.add_child(auto_button)
	fight_button = _button("Fight", Vector2(120, 56), _on_fight)
	Style.make_primary(fight_button)
	top_row.add_child(fight_button)
	retreat_button = _button("Retreat", Vector2(110, 56), _on_retreat)
	top_row.add_child(retreat_button)

	var bottom := PanelContainer.new()
	bottom.add_theme_stylebox_override("panel", Style.box(Style.NIGHT, Color(0, 0, 0, 0), 0, 0))
	bottom.anchor_top = 1.0
	bottom.anchor_bottom = 1.0
	bottom.anchor_right = 1.0
	bottom.offset_top = -BOTTOM_PANEL
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hud.add_child(bottom)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	bottom.add_child(col)

	# Deployment: one card per squad in the warband.
	deploy_box = GridContainer.new()
	deploy_box.columns = CARD_COLUMNS
	deploy_box.add_theme_constant_override("h_separation", 8)
	deploy_box.add_theme_constant_override("v_separation", 8)
	col.add_child(deploy_box)
	var roomy := _cards.size() <= CARD_COLUMNS * 2
	for i in _cards.size():
		var b := _button("", Vector2(0, 84.0 if roomy else 52.0), _on_card.bind(i))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 16)
		b.clip_text = true
		if roomy:
			b.icon = Art.icon(_cards[i]["type"], Sim.PLAYER)
			b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		deploy_box.add_child(b)
		card_buttons.append(b)

	# Battle: who the orders go to, and the two orders.
	battle_box = VBoxContainer.new()
	battle_box.add_theme_constant_override("separation", 10)
	col.add_child(battle_box)
	orders_label = Style.label("", 20)
	orders_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	battle_box.add_child(orders_label)
	var buttons_row := HBoxContainer.new()
	buttons_row.add_theme_constant_override("separation", 10)
	battle_box.add_child(buttons_row)
	advance_button = _button("Advance all", Vector2(0, 84), _on_advance)
	advance_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	advance_button.add_theme_font_size_override("font_size", 26)
	Style.make_primary(advance_button)
	buttons_row.add_child(advance_button)
	hold_button = _button("Hold all", Vector2(0, 84), _on_hold)
	hold_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hold_button.add_theme_font_size_override("font_size", 26)
	buttons_row.add_child(hold_button)
	army_button = _button("Whole army", Vector2(150, 84), _on_army)
	army_button.add_theme_font_size_override("font_size", 20)
	buttons_row.add_child(army_button)

	hint_label = Style.label("", 18, Style.MUTED)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(hint_label)

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
	result_body = Style.label("", 20)
	result_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_body.custom_minimum_size = Vector2(520, 0)
	result_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rv.add_child(result_body)
	var back := _button("Back to camp", Vector2(0, 72), _back_to_camp)
	Style.make_primary(back)
	rv.add_child(back)


func _button(text: String, min_size: Vector2, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(callback)
	return b


func _card_box(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var sb := Style.box(bg, border, width)
	sb.content_margin_left = 6.0
	sb.content_margin_right = 6.0
	return sb


func _refresh_hud() -> void:
	var deploying := sim.phase == Sim.PHASE_DEPLOY
	deploy_box.visible = deploying
	auto_button.visible = deploying
	fight_button.visible = deploying
	battle_box.visible = not deploying
	strength_label.visible = not deploying
	retreat_button.disabled = sim.winner != -1
	if deploying:
		_refresh_deploy()
	else:
		_refresh_battle()


func _refresh_deploy() -> void:
	var left: int = sim.reserves[Sim.PLAYER].size()
	title_label.text = "Deploy"
	status_label.text = "%d of %d placed" % [_cards.size() - left, _cards.size()]
	auto_button.disabled = left == 0 or sim.winner != -1
	fight_button.disabled = left > 0 or sim.winner != -1
	for i in card_buttons.size():
		var b: Button = card_buttons[i]
		var e: Dictionary = _cards[i]
		var level: int = e["level"]
		var c = _squad_record(e["roster_id"]).get("captain")
		var who := _name(e["type"])
		if c != null:
			who = String(c["first"]) + ("*" if int(c.get("wounded", 0)) > 0 else "")
		b.text = "%s %d%s" % [who, e["men"], "" if level <= 1 else " L%d" % level]
		var picked: bool = e["roster_id"] == selected_id
		var placed: bool = sim.placed_squad(Sim.PLAYER, e["roster_id"]) != null
		var style: StyleBox = _card_styles["normal"]
		if picked:
			style = _card_styles["selected"]
		elif placed:
			style = _card_styles["placed"]
		b.add_theme_stylebox_override("normal", style)
		b.add_theme_stylebox_override("hover", style if picked else _card_styles["hover"])
		var ink := Style.MUTED if placed and not picked else Style.TEXT
		b.add_theme_color_override("font_color", ink)
		b.add_theme_color_override("font_hover_color", ink)
		var faded := Color(1, 1, 1, 0.45) if placed and not picked else Color.WHITE
		b.add_theme_color_override("icon_normal_color", faded)
		b.add_theme_color_override("icon_hover_color", faded)


func _refresh_battle() -> void:
	title_label.text = "Battle"
	var left := maxf(0.0, Sim.TIME_LIMIT - sim.time)
	status_label.text = "%d:%02d" % [floori(left / 60.0), int(left) % 60]
	strength_label.text = "You %d · Them %d" % [sim.men_on_field(Sim.PLAYER), sim.men_on_field(Sim.ENEMY)]
	var sq = selected_squad
	if sq != null:
		var arrows := ""
		if sq.arrows > 0:
			arrows = " · %d arrows" % sq.arrows
		elif sq.arrows == 0:
			arrows = " · no arrows"
		var title := _company(sq.roster_id)
		if title == "":
			title = _name(sq.type)
		var mood := " · fury" if sq.fury > 0.0 else ""
		orders_label.text = "%s · %d men · %d%% morale%s%s · %s" % [
			title, sq.alive_count(), maxi(0, int(sq.morale)), mood, arrows, ORDER_WORDS.get(sq.order, sq.order)]
		advance_button.text = "Advance"
		hold_button.text = "Hold"
	else:
		orders_label.text = "Whole army · " + _order_summary()
		advance_button.text = "Advance all"
		hold_button.text = "Hold all"
	army_button.visible = sq != null
	advance_button.disabled = sim.winner != -1
	hold_button.disabled = sim.winner != -1


## "5 holding · 2 advancing" for the squads you still have fighting.
func _order_summary() -> String:
	var counts := {}
	for sq in sim.squads:
		if sq.team == Sim.PLAYER and sq.is_active():
			var word: String = ORDER_WORDS.get(sq.order, sq.order)
			counts[word] = int(counts.get(word, 0)) + 1
	var parts := PackedStringArray()
	for word in ORDER_WORDS.values():
		if counts.has(word):
			parts.append("%d %s" % [counts[word], word])
	return "none left" if parts.is_empty() else " · ".join(parts)


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	if sim == null:
		return
	_draw_field()
	draw_set_transform(field_origin, 0.0, Vector2(field_scale, field_scale))
	_draw_zones()
	for c in sim.corpses:
		var horse: bool = c.get("type", "") == Troops.CAVALRY
		var p: Vector2 = c["pos"]
		# A steady, random-looking angle per body, so the dead don't spin between frames.
		var angle := fposmod(p.x * 12.9898 + p.y * 78.233, TAU)
		_sprite("corpse_horse" if horse else "corpse", c["team"], 0, p, angle, Color(1, 1, 1, 0.8))
	draw_set_transform(field_origin, 0.0, Vector2(field_scale, field_scale))
	_draw_orders()
	for sq in sim.squads:
		_draw_men(sq)
	for p in sim.projectiles:
		var to: Vector2 = p.aim - p.pos
		if to.length() > 0.01:
			_sprite("arrow", 0, 0, p.pos, to.angle() + PI * 0.5)
	draw_set_transform(field_origin, 0.0, Vector2(field_scale, field_scale))
	_draw_floaters()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Pixel-art grass, with faint mown bands so distances still read at a glance.
func _draw_field() -> void:
	var px := Art.GRASS_PIXEL
	draw_set_transform(field_origin, 0.0, Vector2(field_scale * px, field_scale * px))
	draw_texture_rect(Art.grass(), Rect2(Vector2.ZERO, Sim.ARENA / px), true)
	draw_set_transform(field_origin, 0.0, Vector2(field_scale, field_scale))
	var band := 126.0
	var y := 0.0
	var i := 0
	while y < Sim.ARENA.y:
		if i % 2 == 1:
			draw_rect(Rect2(0.0, y, Sim.ARENA.x, minf(band, Sim.ARENA.y - y)), Color(0, 0, 0, 0.06))
		y += band
		i += 1


func _draw_zones() -> void:
	draw_dashed_line(Vector2(0.0, Sim.MID_Y), Vector2(Sim.ARENA.x, Sim.MID_Y), Color(1, 1, 1, 0.35), 3.0, 14.0)
	if sim.phase == Sim.PHASE_DEPLOY and sim.winner == -1:
		var zone := sim.deploy_zone(Sim.PLAYER)
		var picking := selected_id != -1
		draw_rect(zone, Color(Style.PLAYER, 0.22 if picking else 0.12))
		draw_rect(zone, Color(Style.PLAYER_LIGHT, 0.85 if picking else 0.4), false, 3.0)
		draw_rect(sim.deploy_zone(Sim.ENEMY), Color(Style.ENEMY, 0.08))
	draw_rect(Rect2(Vector2.ZERO, Sim.ARENA), Color(0, 0, 0, 0.4), false, 4.0)


## Draw sprite `name` with its pivot at arena point `at`, turned by `angle` (0 = facing up).
func _sprite(name: String, team: int, index: int, at: Vector2, angle: float, tint: Color = Color.WHITE, grow: float = 1.0) -> void:
	var s := field_scale * Art.pixel_size(name) * grow
	draw_set_transform(field_origin + at * field_scale, angle, Vector2(s, s))
	draw_texture(Art.frame(name, team, index), -Art.pivot(name), tint)


func _draw_orders() -> void:
	if sim.phase != Sim.PHASE_BATTLE:
		return
	# A faint ring marks the ground each of your holding squads is keeping.
	for sq in sim.squads:
		if sq.team == Sim.PLAYER and sq.is_active() and sq.order == "hold" and sq != selected_squad:
			draw_arc(sq.order_point, 12.0, 0.0, TAU, 20, Color(Style.BRASS, 0.45), 2.0)
	var sel = selected_squad
	if sel == null or not sel.is_active():
		return
	var from: Vector2 = sel.average_pos()
	if sel.order == "move" or sel.order == "hold":
		var to: Vector2 = sel.order_point
		if from.distance_to(to) > 20.0:
			draw_dashed_line(from, to, Style.BRASS, 3.0, 12.0)
		draw_arc(to, 16.0, 0.0, TAU, 24, Style.BRASS, 3.0)
	elif sel.order == "attack" and sel.order_target != null and sel.order_target.is_active():
		draw_dashed_line(from, sel.order_target.average_pos(), Style.ENEMY_LIGHT, 3.0, 12.0)
	elif sel.order == "advance" and sel.focus != null and sel.focus.is_active():
		draw_dashed_line(from, sel.focus.average_pos(), Color(Style.ENEMY_LIGHT, 0.6), 2.0, 10.0)


func _draw_men(sq) -> void:
	var mine: bool = sq.team == Sim.PLAYER
	var type: String = sq.type
	var tint := Color(0.72, 0.72, 0.72, 0.9) if sq.routing else Color.WHITE
	var selected: bool = sq == selected_squad or (mine and sim.phase == Sim.PHASE_DEPLOY and sq.roster_id == selected_id)
	if selected:
		draw_set_transform(field_origin, 0.0, Vector2(field_scale, field_scale))
		var r: float = float(sq.stats["radius"]) + 4.0
		for so in sq.soldiers:
			if so.alive:
				draw_arc(so.pos, r, 0.0, TAU, 14, Style.BRASS, 2.5)
	for so in sq.soldiers:
		if not so.alive:
			continue
		var index := 2 if so.swing > 0.0 else int(so.stride / 7.0) % 2
		var angle: float = so.facing.angle() + PI * 0.5
		var grow := 1.0
		if so.captain:
			# Captains stand a head taller, on a gold ring.
			grow = 1.2
			var px := field_scale * Art.pixel_size(type)
			draw_set_transform(field_origin + so.pos * field_scale, 0.0, Vector2(px, px))
			draw_arc(Vector2.ZERO, 7.5, 0.0, TAU, 20, Color(0, 0, 0, 0.6), 2.6)
			draw_arc(Vector2.ZERO, 7.5, 0.0, TAU, 20, Style.BRASS if sq.team == Sim.PLAYER else Style.ENEMY_LIGHT, 1.4)
		_sprite(type, sq.team, index, so.pos, angle, tint, grow)
		if so.flash > 0.05:
			draw_texture(Art.flash(type, index), -Art.pivot(type), Color(1, 1, 1, so.flash * 0.8))


func _draw_floaters() -> void:
	for f in floaters:
		var age: float = f["age"]
		var a := clampf(float(f["life"]) - age, 0.0, 1.0)
		var pos: Vector2 = f["pos"] + Vector2(-200.0, -minf(age, 1.3) * 40.0)
		var color: Color = f["color"]
		draw_string_outline(font, pos, f["text"], HORIZONTAL_ALIGNMENT_CENTER, 400.0, 26, 6, Color(0, 0, 0, a))
		draw_string(font, pos, f["text"], HORIZONTAL_ALIGNMENT_CENTER, 400.0, 26, Color(color, a))
