## The battle screen: draws the simulation, turns taps into placements and orders,
## and runs the HUD. All rules live in battle_sim.gd.
##
## Deployment: every squad in the warband is a card in the tray. Tap a card, then tap
## the blue zone to place it; tap a placed squad, then somewhere else to move it.
## Auto-place lines up whatever is left. Fight starts the battle once every squad is on
## the field.
##
## Battle: squads hold their ground until ordered. Advance and Hold command the whole
## army, or only the selected squad. Select a squad by tapping its card, its standard or
## its men; then tap an enemy squad to attack it, open ground to march there, or its
## ability button. The camera follows the fighting.
extends Node2D

const Sim = preload("res://scripts/battle/battle_sim.gd")
const Commander = preload("res://scripts/battle/commander_ai.gd")
const Troops = preload("res://scripts/data/troops.gd")
const Style = preload("res://scripts/ui/style.gd")
const Art = preload("res://scripts/art/unit_art.gd")
const Captains = preload("res://scripts/data/captains.gd")
const Cultures = preload("res://scripts/data/cultures.gd")
const Units = preload("res://scripts/data/units.gd")
const Heraldry = preload("res://scripts/ui/heraldry.gd")
const Economy = preload("res://scripts/data/economy.gd")
const MapArt = preload("res://scripts/art/map_art.gd")
const BattleSite = preload("res://scripts/battle/battle_site.gd")
const Terrain = preload("res://scripts/battle/terrain.gd")

const TOP_BAR := 96.0
const CHIP_H := 84.0
const CHIP_GAP := 8.0
const MAX_CHIPS_PER_ROW := 8
const ORDER_WORDS := {"hold": "holding", "advance": "advancing", "attack": "attacking", "move": "marching"}

## The camera frames every squad still fighting, with this much room around them, and
## zooms in up to MAX_ZOOM over the whole-field view.
const CAMERA_MARGIN := 110.0
const MAX_ZOOM := 1.8
const CAMERA_EASE := 1.6
## Standards: pole length, flag size, in screen units.
const POLE := 46.0
const FLAG := Vector2(34.0, 26.0)
## A tap this close (screen units) to a standard selects its squad.
const STANDARD_TAP := 30.0
## The death roll: the battle slows to ROLL_PACE while it plays out over ROLL_TIME seconds.
const ROLL_TIME := 4.2
const ROLL_PACE := 0.12
## When the tumbling die lands.
const ROLL_LANDS := 1.5
## A cavalry charge freezes the battle this long when it lands on or by your men.
const HITSTOP := 0.06
## A press on the field that moves this far (screen pixels) draws a line instead of tapping.
const DRAG_START := 24.0
## Seconds the line just ordered stays on the field.
const LINE_SHOWN := 1.4
## The sound of the ground the battle is fought on, under the music.
const AMBIENCE := {"river": "water", "woods": "birds"}
## Branches that shoot bolts rather than arrows.
const CROSSBOWS := ["vardish_crossbowmen"]
## The ring and blades over an enemy squad you've sent someone to attack.
const TARGET_RED := Color(0.93, 0.28, 0.22)

var sim: Sim
var field_origin := Vector2.ZERO
var field_scale := 1.0
## Deployment: the roster id of the squad the next tap on the field puts down, or -1.
var selected_id := -1
## Battle: the squad Advance, Hold and the ability button apply to. null means the
## whole army.
var selected_squad = null
var speed := 1.0
var paused := false
var autoplay := false
var font: Font

var floaters: Array = []
var ticker: Array = []
var _view := Rect2()
var _fit_scale := 1.0
var cam_zoom := 1.0
var cam_center := Sim.ARENA * 0.5
var _insets := {"top": 0.0, "bottom": 0.0}
var _clock := 0.0
var _hitstop := 0.0
var _shake := 0.0
var _shake_offset := Vector2.ZERO
## When each squad broke (for the toppling standard), last charged (to space out
## callouts) and was last ordered (for the standard's dip).
var _broke_at := {}
var _charged_at := {}
var _ordered_at := {}
var _std_x := {}
var _std_tops := {}
## The death roll on screen, and any waiting their turn.
var _roll := {}
var _roll_queue: Array = []

var _cards: Array = []
## What the enemy's troops are called: their culture's words.
var _enemy_culture := Cultures.VARDISH
## The land the battle is fought in, which sets the ground and what grows on it, and
## the rocks and bushes scattered over the field: [{name, pos, scale, flip}].
var _biome := Cultures.VARDISH
var _doodads: Array = []
## Broad patches of lighter and darker ground: [{pos, r, light}].
var _patches: Array = []
## The culture each squad was raised in, by "team/roster id", which dresses its men.
var _cultures := {}
## When the next clash of steel sounds, and how many arrows were in the air last frame.
var _clash_clock := 0.0
## The missiles in the air last frame, so each volley is heard once.
var _heard := {}
## A press on the field: where it went down (on screen and on the field), where it is
## now, and whether it has become a line.
var _camera_hold := false
var _camera_grace := 0.0
var camera_button: Button
var _pressing := false
var _drawing := false
var _press_at := Vector2.ZERO
var _press_field := Vector2.ZERO
var _drag_to := Vector2.ZERO
## The line just ordered, fading: {spots, face, at}.
var _line_shown := {}
## Whether the hint has shown how to command one squad yet this battle.
var _taught := false
var _accumulator := 0.0
var _result_shown := false
var _left_battle := false
var _pending_result := {}
var _retreat_armed := 0.0

var top_panel: PanelContainer
var bottom_panel: PanelContainer
var menu_button: Button
var title_label: Label
var status_label: Label
var power_bar: Control
var speed_button: Button
var tray: GridContainer
var chip_buttons: Array = []
var info_label: Label
var auto_button: Button
var fight_button: Button
var advance_button: Button
var hold_button: Button
var ability_button: Button
var hold_fire_button: Button
var hint_label: Label
var roll_layer: Control
var pause_panel: PanelContainer
var pause_note: Label
var retreat_button: Button
var result_panel: PanelContainer
var result_title: Label
var result_body: Label
var terrain_hint_panel: PanelContainer
var terrain_hint_title: Label
var terrain_hint_body: Label
var _height_tex: ImageTexture = null
var _trees: Array = []
## Woods on the battlefield: the shade of the forest floor, in rings, and how solid the
## treetops over the men are.
const WOODS_FLOOR := Color(0.10, 0.24, 0.10)
const WOODS_FLOOR_RINGS := 4
const TREETOP_ALPHA := 0.78
var _terrain_site_type := ""


func _ready() -> void:
	font = ThemeDB.fallback_font
	# Pixel art: hard edges, and the grass tile repeats.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	# `-- --autoplay` lets the computer fight both sides (used for headless smoke tests).
	autoplay = OS.get_cmdline_user_args().has("--autoplay")
	sim = Sim.new()
	# A fight the map set up (bandits on the road), or one made up on the spot.
	var pending: Dictionary = GameState.pending_battle
	var site = pending.get("site")
	if site == null:
		var pos: Vector2 = GameState.world.party_pos(GameState.world.player()) if GameState.world != null else Vector2.ZERO
		site = BattleSite.pick(GameState.world, pos)
	if pending.is_empty():
		sim.setup(GameState.army, GameState.enemy_army(), 0, site)
		sim.ai[Sim.ENEMY] = Commander.new(Sim.ENEMY)
	else:
		_enemy_culture = String(pending.get("culture", Cultures.VARDISH))
		var obj: String = String(pending.get("objective", Sim.OBJECTIVE_ROUT))
		sim.setup(GameState.army, pending["enemy"], 0, site, obj)
		if pending.has("chief_name") and pending["chief_name"] != "":
			sim.chief_name = String(pending["chief_name"])
		sim.ai[Sim.ENEMY] = Commander.new(Sim.ENEMY, String(pending.get("temperament", "")))
	# Bandits fight in their own realm; a battle off the map is fought in yours.
	_biome = _enemy_culture if not pending.is_empty() else GameState.culture
	_setup_terrain_visuals()
	_scatter_doodads()
	match sim.objective:
		Sim.OBJECTIVE_CHIEF:
			_tick("OBJECTIVE: Slay the Bandit Chief (%s)!" % (sim.chief_name if sim.chief_name != "" else "Bandit Chief"), Style.BRASS)
		Sim.OBJECTIVE_VILLAGE:
			_tick("OBJECTIVE: Hold the village square for 2 minutes!", Style.BRASS)
		Sim.OBJECTIVE_AMBUSH:
			_tick("AMBUSH: Protect your marching column!", Style.MORALE_LOW)
		_:
			_tick("OBJECTIVE: Rout the enemy host!", Style.TEXT)
	Sound.play_battle()
	# A river runs through a ford; birds sing in a wood.
	Sound.set_loop(AMBIENCE.get(_terrain_site_type, ""))
	# The enemy lines up first, so you can see what you're facing while you deploy.
	sim.ai[Sim.ENEMY].deploy(sim)
	if sim.caught_on_march(Sim.PLAYER):
		sim.auto_deploy(Sim.PLAYER)
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
		_maybe_show_terrain_hint()
	_refresh_hud()


func _exit_tree() -> void:
	Sound.set_loop("")
	if sim != null:
		sim.dispose()


func _notification(what: int) -> void:
	# A phone call or a swipe home pauses the battle.
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if sim != null and sim.phase == Sim.PHASE_BATTLE and sim.winner == -1 and not autoplay:
			_set_paused(true)


func _layout() -> void:
	var vs := get_viewport_rect().size
	_insets = Style.safe_insets(get_viewport())
	var top_h: float = TOP_BAR + _insets["top"]
	var bottom_h: float = _bottom_height() + _insets["bottom"]
	if top_panel != null:
		top_panel.add_theme_stylebox_override("panel", _bar_box(true))
		bottom_panel.add_theme_stylebox_override("panel", _bar_box(false))
		top_panel.offset_bottom = top_h
		bottom_panel.offset_top = -bottom_h
	_view = Rect2(Vector2(8.0, top_h + 8.0), Vector2(vs.x - 16.0, vs.y - top_h - bottom_h - 16.0))
	_fit_scale = maxf(0.1, minf(_view.size.x / Sim.ARENA.x, _view.size.y / Sim.ARENA.y))
	_apply_camera()
	queue_redraw()


func _bottom_height() -> float:
	var rows := _tray_rows()
	return 14.0 + rows * CHIP_H + (rows - 1) * CHIP_GAP + 10.0 + 34.0 + 10.0 + Style.TOUCH + 8.0 + 64.0 + 14.0 + Style.TOUCH + 10.0


func _tray_rows() -> int:
	return 1 if _cards.size() <= MAX_CHIPS_PER_ROW else 2


# ---------------------------------------------------------------- camera

func _apply_camera() -> void:
	field_scale = _fit_scale * cam_zoom
	var half := _view.size / field_scale * 0.5
	var c := cam_center
	c.x = clampf(c.x, half.x, Sim.ARENA.x - half.x) if half.x * 2.0 < Sim.ARENA.x else Sim.ARENA.x * 0.5
	c.y = clampf(c.y, half.y, Sim.ARENA.y - half.y) if half.y * 2.0 < Sim.ARENA.y else Sim.ARENA.y * 0.5
	cam_center = c
	field_origin = _view.get_center() - c * field_scale + _shake_offset


## The whole field while deploying; once the battle is on, every squad still fighting.
func _update_camera(delta: float) -> void:
	_camera_grace = maxf(0.0, _camera_grace - delta)
	if _pressing or _camera_hold or _camera_grace > 0.0:
		_shake = maxf(0.0, _shake - delta * 30.0)
		_shake_offset = Vector2.ZERO
		_apply_camera()
		return
	var want_zoom := 1.0
	var want_center := Sim.ARENA * 0.5
	if sim.phase == Sim.PHASE_BATTLE and sim.winner == -1:
		var box := Rect2()
		var first := true
		for sq in sim.squads:
			if not sq.is_active():
				continue
			var half: Vector2 = Vector2.ONE * (sq.extent + CAMERA_MARGIN)
			var r := Rect2(sq.avg - half, half * 2.0)
			box = r if first else box.merge(r)
			first = false
		if not first:
			want_center = box.get_center()
			want_zoom = clampf(minf(_view.size.x / (box.size.x * _fit_scale), _view.size.y / (box.size.y * _fit_scale)), 1.0, MAX_ZOOM)
	var k := 1.0 - exp(-delta * CAMERA_EASE)
	cam_zoom = lerpf(cam_zoom, want_zoom, k)
	cam_center = cam_center.lerp(want_center, k)
	_shake = maxf(0.0, _shake - delta * 30.0)
	_shake_offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake if _shake > 0.0 and not Style.motion_reduced() else Vector2.ZERO
	_apply_camera()


func _toggle_camera() -> void:
	_camera_hold = not _camera_hold
	camera_button.text = "View: held" if _camera_hold else "View: following"


func _recenter_camera() -> void:
	_camera_hold = false
	_camera_grace = 0.0
	camera_button.text = "View: following"
	_update_camera(1.0)


func _to_screen(p: Vector2) -> Vector2:
	return field_origin + p * field_scale


func _to_field(p: Vector2) -> Vector2:
	return (p - field_origin) / field_scale


# ---------------------------------------------------------------- frame

func _process(delta: float) -> void:
	_clock += delta
	if not _roll.is_empty():
		var before := float(_roll["t"])
		_roll["t"] = before + delta
		# The die rattles as it tumbles; a bell tolls if it lands on death.
		if before == 0.0:
			Sound.play("dice")
		if before < ROLL_LANDS and float(_roll["t"]) >= ROLL_LANDS and _roll["fate"] == "killed":
			Sound.play("bell")
		if float(_roll["t"]) >= ROLL_TIME:
			_next_roll()
	if sim.winner == -1 and sim.phase == Sim.PHASE_BATTLE and not paused:
		var pace := ROLL_PACE if not _roll.is_empty() else 1.0
		if _hitstop > 0.0:
			_hitstop -= delta
			pace = 0.0
		_accumulator += minf(delta, 0.1) * speed * pace
		var steps := 0
		while _accumulator >= Sim.STEP and steps < 16:
			sim.step()
			_accumulator -= Sim.STEP
			steps += 1
		_consume_events()
		_battle_sounds(delta)
		if selected_squad != null and not selected_squad.is_active():
			selected_squad = null
	elif sim.winner != -1 and not _result_shown and _roll.is_empty():
		_consume_events()
		if _roll.is_empty():
			_show_result()
	_update_camera(delta)
	for f in floaters:
		f["age"] += delta
	floaters = floaters.filter(func(f): return f["age"] < f["life"])
	for t in ticker:
		t["age"] += delta
	ticker = ticker.filter(func(t): return t["age"] < t["life"])
	_refresh_hud()
	queue_redraw()


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if not _roll.is_empty():
		get_viewport().set_input_as_handled()
		_next_roll()
		return
	if sim.winner != -1 or paused:
		return
	if not _view.has_point(mb.position):
		return
	get_viewport().set_input_as_handled()
	# A press on the field is a tap when it's let go, or a line if it's dragged.
	_pressing = true
	_drawing = false
	_press_at = mb.position
	_shake_offset = Vector2.ZERO
	_apply_camera()
	_press_field = _to_field(mb.position)
	_drag_to = mb.position


## Follows a press on the field until it's let go, wherever the finger goes.
func _input(event: InputEvent) -> void:
	if not _pressing:
		return
	var mm := event as InputEventMouseMotion
	if mm != null:
		_drag_to = mm.position
		if not _drawing and mm.position.distance_to(_press_at) >= DRAG_START:
			_drawing = true
		get_viewport().set_input_as_handled()
		return
	var mb := event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT or mb.pressed:
		return
	get_viewport().set_input_as_handled()
	_pressing = false
	_camera_grace = 0.85
	var drew := _drawing
	_drawing = false
	if sim.winner != -1 or paused:
		return
	if drew:
		_order_line(_press_field, _to_field(mb.position))
		return
	var tapped = _standard_at(_press_at)
	if sim.phase == Sim.PHASE_DEPLOY:
		_tap_deploy(_press_field, tapped)
	else:
		_tap_battle(_press_field, tapped)


## Form up along a line drawn from `a` to `b`: the selected squad alone, or the whole
## army (before the battle, the whole army always: it's placed there at once).
func _order_line(a: Vector2, b: Vector2) -> void:
	var only = selected_squad if sim.phase == Sim.PHASE_BATTLE else null
	var spots := sim.order_line(Sim.PLAYER, a, b, only)
	if spots.is_empty():
		_hint("Cannot form a line there. Choose clear ground in the deployment zone.")
		return
	for spot in spots:
		_ordered_at[spot["squad"]] = _clock
	_line_shown = {"spots": spots, "face": sim.line_face(Sim.PLAYER, a, b), "at": _clock}
	Sound.play("page", 0.0, 0.05)
	if sim.phase == Sim.PHASE_DEPLOY:
		selected_id = -1
		_hint("Your army stands on the line. Drag again to redraw it, tap a squad to move it, or press Fight.")
	elif only != null:
		_hint("%s form up along the line, %d men wide, and hold there." % [_company_or_type(only), int(spots[0]["files"])])
	else:
		_hint("The army forms up along the line, each squad to its own stretch of it, and holds there.")


## The squad whose standard is under a tap, or null.
func _standard_at(at: Vector2):
	var best = null
	var best_d := STANDARD_TAP
	for sq in _std_tops:
		var top: Vector2 = _std_tops[sq]
		var d := at.distance_to(top + FLAG * 0.5)
		if d < best_d:
			best_d = d
			best = sq
	return best


func _tap_deploy(p: Vector2, tapped) -> void:
	var mine = tapped if tapped != null and tapped.team == Sim.PLAYER else sim.squad_at(Sim.PLAYER, p)
	if mine != null:
		if mine.roster_id == selected_id:
			_select_next_card() # tapping the picked-up squad again leaves it where it is
		else:
			selected_id = mine.roster_id
			_hint("Tap where you want %s to stand." % _company_or_type(mine))
		return
	var foe = tapped if tapped != null and tapped.team == Sim.ENEMY else sim.squad_at(Sim.ENEMY, p, 52.0)
	if foe != null:
		_hint(_describe(foe))
		return
	if selected_id == -1:
		var thint := _terrain_hint(p)
		if thint != "":
			_hint(thint)
			return
		if sim.all_placed(Sim.PLAYER):
			_hint("Tap one of your squads to move it, or press Fight.")
		else:
			_hint("Tap a card first.")
		return
	if not sim.in_deploy_zone(Sim.PLAYER, p):
		_hint("Place your squads in the blue zone, your half of the field.")
		return
	if sim.caught_on_march(Sim.PLAYER):
		_hint("No time to form up: they're on you from both ends. Press Fight.")
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
			_hint("Tap the blue zone to place %s, %d %s, or drag a line to place everyone." % [
				_card_name(e), e["men"], _name(e["type"], Sim.PLAYER, e["roster_id"]).to_lower()])
			return
	if sim.caught_on_march(Sim.PLAYER):
		_hint("Ambushed on the march, strung out along the road! No time to form up. Press Fight.")
		return
	_hint("Your whole army is on the field. Tap a squad to move it, or drag a new line, then press Fight.")


func _tap_battle(p: Vector2, tapped) -> void:
	var mine = tapped if tapped != null and tapped.team == Sim.PLAYER else sim.squad_at(Sim.PLAYER, p)
	if mine != null and mine.is_active():
		_select(null if mine == selected_squad else mine)
		return
	var foe = tapped if tapped != null and tapped.team == Sim.ENEMY else sim.squad_at(Sim.ENEMY, p, 52.0)
	if selected_squad == null:
		if foe != null:
			_hint(_describe(foe))
		else:
			var thint := _terrain_hint(p)
			if thint != "":
				_hint(thint)
			else:
				_hint("Tap a squad to command it, or drag across the field to give the army a new line.")
		return
	if foe != null and foe.is_active():
		sim.order_attack(selected_squad, foe)
		_ordered_at[selected_squad] = _clock
		_ordered_at[foe] = _clock
		_float_text("TARGET", foe.average_pos() + Vector2(0, -60), Style.ENEMY_LIGHT)
		Sound.play("clash2", -6.0, 0.05)
		_hint("%s attack the enemy %s, and stay on them until they break." % [_company_or_type(selected_squad), _name(foe.type, Sim.ENEMY).to_lower()])
	else:
		if sim.terrain != null and not sim.terrain.passable(p):
			var thint := _terrain_hint(p)
			_hint("Cannot march there: %s" % thint)
			return
		if Sim.Pathing.find_path(sim.terrain, selected_squad.center, p, selected_squad.type == Troops.CAVALRY, false).is_empty():
			_hint("Cannot march there: no route to that ground.")
			return
		sim.order_move(selected_squad, p)
		_float_text("MOVE", p, Style.BRASS)
		_ordered_at[selected_squad] = _clock
		_hint("%s march there and hold." % _company_or_type(selected_squad))


func _select(sq) -> void:
	selected_squad = sq
	if sq == null:
		_hint("Orders go to the whole army.")
		return
	if not _taught:
		_taught = true
		_hint("%s: tap an enemy to attack it, open ground to march there, or drag a line to form them up along it." % _company_or_type(sq))
		return
	var ab := Troops.ability(sq.type)
	var who := _company_or_type(sq)
	if not sq.info.is_empty():
		who += ", led by %s (%s)" % [sq.info["first"], Captains.traits(sq.info)]
	_hint("%s. %s: %s" % [who, ab["name"], ab["blurb"]])


func _on_chip(index: int) -> void:
	if sim.winner != -1:
		return
	var e: Dictionary = _cards[index]
	if sim.phase == Sim.PHASE_BATTLE:
		var sq = sim.placed_squad(Sim.PLAYER, e["roster_id"])
		if sq == null or not sq.is_active():
			_hint("%s are out of the fight." % _card_name(e))
			return
		_select(null if sq == selected_squad else sq)
		return
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
	Sound.play("horn")
	selected_id = -1
	selected_squad = null
	_hint("Your squads hold, braced, until ordered. Tap a squad to command it, or drag across the field to give the army a new line.")


func _on_advance() -> void:
	if sim.phase != Sim.PHASE_BATTLE or sim.winner != -1:
		return
	if selected_squad != null:
		sim.order_advance(selected_squad)
		_ordered_at[selected_squad] = _clock
		_hint("%s advance on the enemy they fight best." % _company_or_type(selected_squad))
	else:
		sim.order_all(Sim.PLAYER, "advance")
		for sq in sim.squads:
			if sq.team == Sim.PLAYER:
				_ordered_at[sq] = _clock
		_hint("The whole army advances. Each squad goes for the enemy it fights best.")


func _on_hold() -> void:
	if sim.phase != Sim.PHASE_BATTLE or sim.winner != -1:
		return
	if selected_squad != null:
		sim.order_hold(selected_squad)
		_ordered_at[selected_squad] = _clock
		_hint("%s hold where they stand, and brace." % _company_or_type(selected_squad))
	else:
		sim.order_all(Sim.PLAYER, "hold")
		for sq in sim.squads:
			if sq.team == Sim.PLAYER:
				_ordered_at[sq] = _clock
		_hint("The whole army holds and braces. Squads fight anyone who comes close.")


func _on_ability() -> void:
	var sq = selected_squad
	if sq == null or sim.winner != -1:
		return
	var ab := Troops.ability(sq.type)
	if sim.use_ability(sq):
		_hint("%s: %s" % [ab["name"], ab["blurb"]])
	elif sq.ability_cd > 0.0:
		_hint("%s is ready again in %d seconds." % [ab["name"], ceili(sq.ability_cd)])
	elif sq.type == Troops.ARCHERS:
		_hint("No enemy in bow range." if sq.arrows > 0 else "Out of arrows.")


## Archers keep their arrows, or loose at will again.
func _on_hold_fire() -> void:
	var sq = selected_squad
	if sq == null or sim.winner != -1 or not sq.ranged:
		return
	sim.set_hold_fire(sq, not sq.hold_fire)
	_ordered_at[sq] = _clock
	if sq.hold_fire:
		_hint("%s hold their fire and keep their arrows. They draw blades if the enemy reaches them." % _company_or_type(sq))
	else:
		_hint("%s loose at will." % _company_or_type(sq))


func _on_menu() -> void:
	if sim.winner != -1:
		return
	_set_paused(not paused)


func _set_paused(on: bool) -> void:
	paused = on and sim.winner == -1
	pause_panel.visible = paused
	retreat_button.text = "Retreat"
	_retreat_armed = 0.0


func _on_speed() -> void:
	speed = 2.0 if speed < 1.5 else 1.0


func _on_retreat() -> void:
	if sim.winner != -1:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now < _retreat_armed:
		_set_paused(false)
		sim.concede(Sim.PLAYER)
		return
	_retreat_armed = now + 3.0
	retreat_button.text = "Tap again to retreat"


func _hint(text: String) -> void:
	if hint_label != null:
		hint_label.text = text


# ---------------------------------------------------------------- words

## What a troop type is called on one side: in the enemy's words, or for one of your
## squads in the words of the culture it was raised in (yours unless you hired it abroad).
func _name(type: String, team: int = Sim.PLAYER, roster_id: int = -1) -> String:
	if team != Sim.PLAYER:
		var foe = sim.placed_squad(Sim.ENEMY, roster_id) if roster_id != -1 else null
		return Units.troop_name({"unit": foe.unit if foe != null else "", "type": type}, _enemy_culture)
	var record := _squad_record(roster_id)
	if record.is_empty():
		record = {"type": type}
	return Units.troop_name(record, GameState.culture)


## "Brann's Shields, led by Brann of Ostmark (Vengeful, Lucky). Bonds: Mira (B)."
func _led_by(sq) -> String:
	if sq.info.is_empty():
		return "%s, without a captain." % _company_or_type(sq)
	var who := "%s, led by %s (%s)" % [_company(sq.roster_id), sq.info["name"], Captains.traits(sq.info)]
	if sq.captain == null:
		who = "%s. %s is down" % [_company(sq.roster_id), sq.info["name"]]
	return who + _bond_text(sq.info) + "."


func _card_story(e: Dictionary) -> String:
	var squad := _squad_record(e["roster_id"])
	var c = squad.get("captain")
	if c == null:
		return "%s have no captain." % squad.get("name", _name(e["type"], Sim.PLAYER, e["roster_id"]))
	if int(c.get("wounded", 0)) > 0:
		return "%s is wounded and sits this one out (%d more). %s fight without a captain." % [c["name"], c["wounded"], squad["name"]]
	return "%s, led by %s (%s)%s." % [squad["name"], c["name"], Captains.traits(c), _bond_text(c)]


func _card_name(e: Dictionary) -> String:
	var name := String(_squad_record(e["roster_id"]).get("name", ""))
	return name if name != "" else "your " + _name(e["type"], Sim.PLAYER, e["roster_id"]).to_lower()


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


func _company_or_type(sq) -> String:
	if sq.team == Sim.PLAYER:
		var name := _company(sq.roster_id)
		if name != "":
			return name
		return "Your " + _name(sq.type, Sim.PLAYER, sq.roster_id).to_lower()
	return "The enemy " + _name(sq.type, Sim.ENEMY).to_lower()


func _describe(sq) -> String:
	var text := "Enemy %s · %d men" % [_name(sq.type, Sim.ENEMY).to_lower(), sq.alive_count()]
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


func _scouting() -> String:
	var ai = sim.ai[Sim.ENEMY]
	return String(Commander.SCOUTING.get(ai.temperament, "")) if ai != null else ""


# ---------------------------------------------------------------- sound

## The din of the fight: steel ringing faster the more squads are locked in melee, a
## rush of air when a volley goes up, and the music swelling with the fighting.
func _battle_sounds(delta: float) -> void:
	var engaged := 0
	var active := 0
	for sq in sim.squads:
		if sq.is_active():
			active += 1
			if sq.engaged:
				engaged += 1
	Sound.set_battle_intensity(float(engaged) / maxf(1.0, active) * 1.6)
	if engaged > 0 and _roll.is_empty() and _hitstop <= 0.0:
		_clash_clock -= delta * speed * (0.5 + engaged * 0.35)
		if _clash_clock <= 0.0:
			_clash_clock = randf_range(0.18, 0.4)
			Sound.play("clash%d" % randi_range(1, 3), randf_range(-6.0, 0.0), 0.15)
	# Each kind of missile has its own sound, played when enough of them go up at once.
	var loosed := {}
	var seen := {}
	for p in sim.projectiles:
		seen[p] = true
		if not _heard.has(p):
			var kind := _missile_sound(p)
			loosed[kind] = int(loosed.get(kind, 0)) + 1
	_heard = seen
	for kind in loosed:
		if int(loosed[kind]) >= (6 if kind == "arrows" else 3):
			Sound.play(kind, 0.0, 0.08, 0.6)


## The sound a missile makes going up: a javelin, a crossbow bolt, a horse archer's
## arrow, or a plain arrow.
func _missile_sound(p) -> String:
	if p.kind == "javelin":
		return "javelin"
	if p.source != null and CROSSBOWS.has(p.source.unit):
		return "crossbow"
	if p.source != null and p.source.type == Troops.CAVALRY:
		return "horsebow"
	return "arrows"


# ---------------------------------------------------------------- events

func _consume_events() -> void:
	for e in sim.events:
		match e["type"]:
			"rout":
				var sq = e["squad"]
				_broke_at[sq] = _clock
				Sound.play("rout", 0.0, 0.1, 0.8)
				var mine: bool = sq.team == Sim.PLAYER
				_float_text("BROKEN", sq.average_pos() + Vector2(0, -50), Style.ENEMY_LIGHT if mine else Style.PLAYER_LIGHT, 1.6)
				if mine:
					_tick("%s broke and run for the edge." % _company_or_type(sq), Style.ENEMY_LIGHT)
				else:
					_tick("Their %s break and run." % _name(sq.type, Sim.ENEMY).to_lower(), Style.PLAYER_LIGHT)
			"charge":
				var sq = e["squad"]
				if _clock - float(_charged_at.get(sq, -9.0)) > 1.5:
					_charged_at[sq] = _clock
					_float_text("CHARGE!", e["pos"], Style.BRASS)
					Sound.play("charge", 0.0, 0.06, 0.6)
					if sq.team == Sim.PLAYER or e["victim"].team == Sim.PLAYER:
						_shake = maxf(_shake, 5.0)
						_hitstop = HITSTOP
						if e["victim"].team == Sim.PLAYER:
							Input.vibrate_handheld(30)
			"out_of_arrows":
				var sq = e["squad"]
				var mine: bool = sq.team == Sim.PLAYER
				_float_text("OUT OF ARROWS", sq.average_pos() + Vector2(0, -50), Style.PLAYER_LIGHT if mine else Style.ENEMY_LIGHT)
				if mine:
					_hint("Your archers are out of arrows and draw their blades. They are weak in a melee, so keep them out of one.")
			"captain_down":
				_captain_down(e)
			"grief":
				_grief(e)
			"ability":
				var sq = e["squad"]
				var mine: bool = sq.team == Sim.PLAYER
				if sq.type == Troops.ARCHERS:
					Sound.play("arrows", 2.0, 0.05, 0.3)
				_float_text(String(e["name"]).to_upper(), sq.average_pos() + Vector2(0, -50), Style.PLAYER_LIGHT if mine else Style.ENEMY_LIGHT)
				if not mine:
					_tick("Their %s: %s." % [_name(sq.type, Sim.ENEMY).to_lower(), String(e["name"]).to_lower()], Style.ENEMY_LIGHT)
			"braced":
				var sq = e["squad"]
				_float_text("BRACED", sq.average_pos() + Vector2(0, -50), Style.BRASS if sq.team == Sim.PLAYER else Style.ENEMY_LIGHT)
			"reinforcements":
				if int(e["team"]) == Sim.ENEMY:
					Sound.play("alarm", 0.0, 0.0, 2.0)
					_tick("More of them come on from the %s!" % String(e["edge"]), Style.ENEMY_LIGHT)
			"chief_broken":
				Sound.play("objective")
				_float_text("THE CHIEF FALLS BACK", e["squad"].average_pos() + Vector2(0, -60), Style.BRASS, 1.6)
				_tick("Their chief's guard is broken, and the whole band feels it.", Style.PLAYER_LIGHT)
			"chief_slain":
				Sound.play("objective")
				_tick("%s is cut down!" % String(e["chief_name"] if e["chief_name"] != "" else "Their chief"), Style.BRASS)
			"flanked":
				var sq = e["squad"]
				var where := "REAR!" if e["rear"] else "FLANK!"
				Sound.play("clash%d" % randi_range(1, 3), 3.0, 0.1, 0.3)
				_float_text(where, e["pos"], Style.ENEMY_LIGHT if sq.team == Sim.PLAYER else Style.BRASS)
				if sq.team == Sim.PLAYER and e["rear"]:
					_tick("%s are hit from behind!" % _company_or_type(sq), Style.ENEMY_LIGHT)
	sim.events.clear()


func _captain_down(e: Dictionary) -> void:
	var sq = e["squad"]
	var info: Dictionary = sq.info
	if sq.team != Sim.PLAYER:
		_float_text("%s CUT DOWN" % String(info.get("first", "Captain")).to_upper(), e["pos"], Style.PLAYER_LIGHT, 2.2)
		_tick("You cut down %s, captain of their %s. Their nerve wavers." % [info.get("name", ""), _name(sq.type, Sim.ENEMY).to_lower()], Style.PLAYER_LIGHT)
		return
	_shake = maxf(_shake, 9.0)
	Input.vibrate_handheld(120)
	var roll := {
		"t": 0.0, "name": String(info.get("name", "")), "company": _company(sq.roster_id),
		"roll": int(e["roll"]), "needed": int(e["needed"]), "fate": String(e["fate"]),
		"words": String(sq.last_words), "holding": bool(e.get("holding", false)),
		"friends": bool(e.get("friends", false)), "lucky": bool(e.get("lucky", false)),
	}
	if _roll.is_empty():
		_roll = roll
	else:
		_roll_queue.append(roll)


## The roll on screen is done (or skipped): its outcome goes to the hint line, and the
## next captain's roll, if any, takes its place.
func _next_roll() -> void:
	if not _roll.is_empty():
		if _roll["fate"] == "killed":
			_hint("\"%s\" %s is dead. Death roll %d; needed %d or more to live." % [_roll["words"], _roll["name"], _roll["roll"], _roll["needed"]])
		else:
			_hint("\"%s\" %s is down but alive. Death roll %d; needed %d or more. Out for %d battles." % [
				_roll["words"], _roll["name"], _roll["roll"], _roll["needed"], Captains.WOUND_BATTLES])
	_roll = {} if _roll_queue.is_empty() else _roll_queue.pop_front()


func _grief(e: Dictionary) -> void:
	var sq = e["squad"]
	if sq.team != Sim.PLAYER:
		return
	var who := String(sq.info.get("first", ""))
	var lost := String(e["for"].info.get("first", ""))
	match String(e["temperament"]):
		Captains.VENGEFUL:
			_float_text("FURY", sq.average_pos() + Vector2(0, -50), Style.ENEMY_LIGHT, 2.0)
			_tick("%s saw %s fall: fury, harder blows and no retreat for %d seconds." % [who, lost, int(Captains.FURY_SECONDS)], Style.BRASS)
		Captains.STEADFAST:
			_float_text("STEADY", sq.average_pos() + Vector2(0, -50), Style.BRASS, 2.0)
			_tick("%s saw %s fall, and steadies the line." % [who, lost], Style.BRASS)
		Captains.FRAGILE:
			_float_text("SHAKEN", sq.average_pos() + Vector2(0, -50), Style.MUTED, 2.0)
			_tick("%s saw %s fall and is shaken. Their squad's nerve is slipping." % [who, lost], Style.ENEMY_LIGHT)


## A callout over the field. Callouts that would land on one another stack upward.
func _float_text(text: String, at: Vector2, color: Color, life: float = 1.3) -> void:
	for f in floaters:
		if f["text"] == text and at.distance_to(f["pos"]) < 70.0 and f["age"] < 0.6:
			return
	var pos := at
	for i in 6:
		var clear := true
		for f in floaters:
			var fp: Vector2 = f["pos"]
			if f["age"] < 1.0 and absf(fp.x - pos.x) < 150.0 and absf(fp.y - pos.y) < 30.0:
				clear = false
				break
		if clear:
			break
		pos.y -= 32.0
	floaters.append({"text": text, "pos": pos, "color": color, "age": 0.0, "life": life})


## A line in the ticker along the top of the field, for what's happening in the story.
func _tick(text: String, color: Color) -> void:
	for t in ticker:
		if t["text"] == text:
			return
	ticker.append({"text": text, "color": color, "age": 0.0, "life": 4.5})
	if ticker.size() > 3:
		ticker.pop_front()


# ---------------------------------------------------------------- results

func _show_result() -> void:
	_result_shown = true
	paused = false
	pause_panel.visible = false
	selected_id = -1
	selected_squad = null
	_pending_result = _result()
	var won: bool = _pending_result["won"]
	var reasons := {
		"rout": ["Their army broke and fled.", "Your army broke and fled."],
		"time": ["Time ran out with more of your army still standing.", "Time ran out with more of theirs still standing."],
		"retreat": ["The enemy withdrew.", "You pulled your army off the field."],
		"village_held": ["You held the village square until the raiders gave up.", ""],
		"village_lost": ["", "The raiders held the village square when time ran out."],
		"village_burned": ["", "The raiders held the square long enough to fire the village."],
	}
	var why: String = reasons.get(_pending_result["reason"], ["", ""])[0 if won else 1]
	result_title.text = "Victory" if won else "Defeat"
	result_title.add_theme_color_override("font_color", Style.BRASS if won else Style.ENEMY_LIGHT)
	Sound.stinger("victory" if won else "defeat")
	var text := "%s\nYou lost %d men and cut down %d." % [why, _pending_result["lost"], _pending_result["killed"]]
	if won and GameState.has_campaign() and not GameState.pending_battle.is_empty():
		var got := Economy.spoils(int(_pending_result["killed"]))
		text += "\nSpoils: %d silver, %d rations, %d renown." % [got["silver"], got["food"], got["renown"]]
	var fates: Array = GameState.describe_result(_pending_result)
	if not fates.is_empty():
		text += "\n\n" + "\n".join(PackedStringArray(fates))
	result_body.text = text
	result_panel.visible = true
	Style.ease_in(result_panel, Vector2(0.5, 0.5))
	if autoplay:
		get_tree().create_timer(0.8).timeout.connect(_back_to_camp)


## Your side's result, plus what's left of the enemy, so a band that beats you stays
## weakened on the map.
func _result() -> Dictionary:
	var r := sim.result_for(Sim.PLAYER)
	r["enemy_squads"] = sim.result_for(Sim.ENEMY)["squads"]
	return r


func _back_to_camp() -> void:
	if _left_battle:
		return
	_left_battle = true
	if _pending_result.is_empty():
		_pending_result = _result()
	var campaign: bool = GameState.has_campaign() and not GameState.pending_battle.is_empty()
	GameState.apply_result(_pending_result)
	if autoplay:
		GameState.autoplay_battles += 1
	if campaign:
		GameState.save_game()
		Scenes.go("res://scenes/world_map.tscn")
	else:
		Scenes.go("res://scenes/main_menu.tscn")


# ---------------------------------------------------------------- HUD

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var hud := Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.theme = Style.make_theme()
	layer.add_child(hud)

	# Top bar: the menu, then deployment progress or the battle's balance of strength.
	top_panel = PanelContainer.new()
	top_panel.add_theme_stylebox_override("panel", _bar_box(true))
	top_panel.anchor_right = 1.0
	top_panel.offset_bottom = TOP_BAR
	hud.add_child(top_panel)
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 12)
	top_panel.add_child(top_row)
	menu_button = _button("II", Vector2(Style.TOUCH + 16.0, Style.TOUCH), _on_menu)
	menu_button.add_theme_font_size_override("font_size", Style.SMALL)
	top_row.add_child(menu_button)
	title_label = Style.label("Deploy", Style.LARGE, Style.BRASS)
	title_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_row.add_child(title_label)
	status_label = Style.label("", Style.BODY)
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top_row.add_child(status_label)
	power_bar = Control.new()
	power_bar.custom_minimum_size = Vector2(0, 44)
	power_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	power_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	power_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	power_bar.draw.connect(_draw_power)
	top_row.add_child(power_bar)
	speed_button = _button("1×", Vector2(Style.TOUCH, Style.TOUCH), _on_speed)
	top_row.add_child(speed_button)

	# Bottom panel: the squad tray, a line about the selection, the orders, and a hint.
	bottom_panel = PanelContainer.new()
	bottom_panel.add_theme_stylebox_override("panel", _bar_box(false))
	bottom_panel.anchor_top = 1.0
	bottom_panel.anchor_bottom = 1.0
	bottom_panel.anchor_right = 1.0
	bottom_panel.offset_top = -_bottom_height()
	bottom_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hud.add_child(bottom_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	bottom_panel.add_child(col)

	tray = GridContainer.new()
	tray.columns = mini(maxi(1, _cards.size()), MAX_CHIPS_PER_ROW) if _tray_rows() == 1 else ceili(_cards.size() / 2.0)
	tray.add_theme_constant_override("h_separation", int(CHIP_GAP))
	tray.add_theme_constant_override("v_separation", int(CHIP_GAP))
	col.add_child(tray)
	for i in _cards.size():
		var b := _button("", Vector2(0, CHIP_H), _on_chip.bind(i))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.draw.connect(_draw_chip.bind(i))
		tray.add_child(b)
		chip_buttons.append(b)

	info_label = Style.label("", Style.SMALL, Style.TEXT)
	info_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info_label.custom_minimum_size = Vector2(10, 34)
	col.add_child(info_label)

	var buttons_row := HBoxContainer.new()
	buttons_row.add_theme_constant_override("separation", 10)
	col.add_child(buttons_row)
	auto_button = _wide_button("Auto-place", _on_auto, buttons_row)
	fight_button = _wide_button("Fight", _on_fight, buttons_row)
	Style.make_primary(fight_button)
	advance_button = _wide_button("Advance all", _on_advance, buttons_row)
	Style.make_primary(advance_button)
	hold_button = _wide_button("Hold all", _on_hold, buttons_row)
	ability_button = _wide_button("", _on_ability, buttons_row)
	ability_button.draw.connect(_draw_ability_cooldown)
	hold_fire_button = _wide_button("Hold fire", _on_hold_fire, buttons_row)
	hold_fire_button.add_theme_font_size_override("font_size", Style.SMALL)

	hint_label = Style.label("", Style.SMALL, Style.MUTED)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.custom_minimum_size = Vector2(10, 64)
	hint_label.max_lines_visible = 2
	hint_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(hint_label)

	var view_row := HBoxContainer.new()
	view_row.add_theme_constant_override("separation", 10)
	col.add_child(view_row)
	camera_button = _wide_button("View: following", _toggle_camera, view_row)
	_wide_button("Re-center", _recenter_camera, view_row)
	_wide_button("Whole company", func(): _select(null), view_row)

	# The death roll plays over the field.
	roll_layer = Control.new()
	roll_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	roll_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	roll_layer.draw.connect(_draw_roll)
	hud.add_child(roll_layer)

	pause_panel = _centered_panel(hud)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 16)
	pause_panel.add_child(pv)
	var paused_title := Style.label("Paused", 48, Style.BRASS)
	paused_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pv.add_child(paused_title)
	pause_note = Style.label("", Style.SMALL, Style.MUTED)
	pause_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pause_note.custom_minimum_size = Vector2(480, 0)
	pause_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pv.add_child(pause_note)
	var resume := _button("Resume", Vector2(0, Style.TOUCH), _on_menu)
	Style.make_primary(resume)
	pv.add_child(resume)
	retreat_button = _button("Retreat", Vector2(0, Style.TOUCH), _on_retreat)
	pv.add_child(retreat_button)

	result_panel = _centered_panel(hud)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 18)
	result_panel.add_child(rv)
	result_title = Style.label("Victory", 64, Style.BRASS)
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rv.add_child(result_title)
	result_body = Style.label("", Style.BODY)
	result_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_body.custom_minimum_size = Vector2(540, 0)
	result_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rv.add_child(result_body)
	var back := _button("Back to the map" if not GameState.pending_battle.is_empty() else "Back to camp", Vector2(0, Style.TOUCH), _back_to_camp)
	Style.make_primary(back)
	rv.add_child(back)

	terrain_hint_panel = _centered_panel(hud)
	var thv := VBoxContainer.new()
	thv.add_theme_constant_override("separation", 16)
	terrain_hint_panel.add_child(thv)
	terrain_hint_title = Style.label("Battlefield Ground", 44, Style.BRASS)
	terrain_hint_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	thv.add_child(terrain_hint_title)
	terrain_hint_body = Style.label("", Style.BODY)
	terrain_hint_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	terrain_hint_body.custom_minimum_size = Vector2(500, 0)
	terrain_hint_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	thv.add_child(terrain_hint_body)
	var dismiss_btn := _button("Understood", Vector2(0, Style.TOUCH), func(): terrain_hint_panel.visible = false)
	Style.make_primary(dismiss_btn)
	thv.add_child(dismiss_btn)


func _bar_box(top: bool) -> StyleBoxFlat:
	var sb := Style.box(Style.NIGHT, Color(0, 0, 0, 0), 0, 0)
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 8.0 + (float(_insets["top"]) if top else 6.0)
	sb.content_margin_bottom = 8.0 if top else 8.0 + float(_insets["bottom"])
	return sb


func _centered_panel(parent: Control) -> PanelContainer:
	var p := PanelContainer.new()
	p.anchor_left = 0.5
	p.anchor_right = 0.5
	p.anchor_top = 0.5
	p.anchor_bottom = 0.5
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.visible = false
	parent.add_child(p)
	return p


func _button(text: String, min_size: Vector2, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(callback)
	return b


func _wide_button(text: String, callback: Callable, row: HBoxContainer) -> Button:
	var b := _button(text, Vector2(0, Style.TOUCH), callback)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", Style.BODY)
	b.clip_text = true
	row.add_child(b)
	return b


func _refresh_hud() -> void:
	var deploying := sim.phase == Sim.PHASE_DEPLOY
	title_label.visible = deploying
	status_label.visible = deploying
	power_bar.visible = not deploying
	speed_button.visible = not deploying
	auto_button.visible = deploying
	fight_button.visible = deploying
	advance_button.visible = not deploying
	hold_button.visible = not deploying
	menu_button.disabled = sim.winner != -1
	menu_button.text = "Menu" if deploying else "II"
	speed_button.text = "2×" if speed > 1.5 else "1×"
	pause_note.text = _scouting()
	if deploying:
		_refresh_deploy()
	else:
		_refresh_battle()
	for b in chip_buttons:
		b.queue_redraw()
	power_bar.queue_redraw()
	roll_layer.queue_redraw()


func _refresh_deploy() -> void:
	var left: int = sim.reserves[Sim.PLAYER].size()
	status_label.text = "%d of %d placed" % [_cards.size() - left, _cards.size()]
	auto_button.disabled = left == 0 or sim.winner != -1
	fight_button.disabled = left > 0 or sim.winner != -1
	ability_button.visible = false
	hold_fire_button.visible = false
	info_label.text = _scouting()
	info_label.add_theme_color_override("font_color", Style.BRASS)


func _refresh_battle() -> void:
	info_label.add_theme_color_override("font_color", Style.TEXT)
	var sq = selected_squad
	ability_button.visible = sq != null
	hold_fire_button.visible = sq != null and sq.ranged
	if sq != null:
		var title := _company(sq.roster_id)
		if title == "":
			title = _name(sq.type, Sim.PLAYER, sq.roster_id)
		var state: String = ORDER_WORDS.get(sq.order, sq.order)
		if sq.wheeling:
			state = "wheeling"
		elif sq.braced():
			state = "braced"
		elif sq.engaged:
			state = "fighting"
		if sq.hold_fire:
			state = "holding fire" if sq.order == "hold" else state + ", holding fire"
		var arrows := ""
		if sq.arrows > 0:
			arrows = " · %d arrows" % sq.arrows
		elif sq.arrows == 0:
			arrows = " · no arrows"
		var mood := " · fury" if sq.fury > 0.0 else ""
		info_label.text = "Selected: %s · %d men · %d%% morale%s%s · %s" % [
			title, sq.alive_count(), maxi(0, int(sq.morale)), mood, arrows, state]
		advance_button.text = "Advance"
		hold_button.text = "Hold"
		var ab := Troops.ability(sq.type)
		ability_button.text = String(ab["name"])
		ability_button.modulate = Color(1, 1, 1, 1.0 if sim.ability_ready(sq) else 0.55)
		ability_button.queue_redraw()
		hold_fire_button.text = "Fire at will" if sq.hold_fire else "Hold fire"
	else:
		info_label.text = "Whole army · " + _order_summary()
		advance_button.text = "Advance all"
		hold_button.text = "Hold all"
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


## The tug of war: how much of each army is still fighting. The clock only shows in
## the last minute.
func _draw_power() -> void:
	var w := power_bar.size.x
	var h := 26.0
	var y := (power_bar.size.y - h) * 0.5
	var mine := float(sim.men_on_field(Sim.PLAYER))
	var theirs := float(sim.men_on_field(Sim.ENEMY))
	var split := w * (mine / maxf(1.0, mine + theirs))
	power_bar.draw_rect(Rect2(0, y, w, h), Style.RULE)
	power_bar.draw_rect(Rect2(0, y, split, h), Style.PLAYER)
	power_bar.draw_rect(Rect2(split, y, w - split, h), Style.ENEMY)
	power_bar.draw_rect(Rect2(split - 2.0, y - 5.0, 4.0, h + 10.0), Style.TEXT)
	power_bar.draw_string(font, Vector2(8, y + h - 5.0), str(int(mine)), HORIZONTAL_ALIGNMENT_LEFT, -1, Style.SMALL, Style.TEXT)
	power_bar.draw_string(font, Vector2(w - 68.0, y + h - 5.0), str(int(theirs)), HORIZONTAL_ALIGNMENT_RIGHT, 60.0, Style.SMALL, Style.TEXT)
	var left := Sim.TIME_LIMIT - sim.time
	if left < 60.0 and sim.winner == -1:
		var clock := "%d:%02d" % [floori(left / 60.0), int(left) % 60]
		power_bar.draw_string_outline(font, Vector2(0, y + h - 5.0), clock, HORIZONTAL_ALIGNMENT_CENTER, w, Style.SMALL, 5, Style.NIGHT)
		power_bar.draw_string(font, Vector2(0, y + h - 5.0), clock, HORIZONTAL_ALIGNMENT_CENTER, w, Style.SMALL, Style.TEXT)


## A card in the tray: the squad's standard, its captain, its men, and in battle its
## morale and whether its ability is ready.
func _draw_chip(i: int) -> void:
	var b: Button = chip_buttons[i]
	var e: Dictionary = _cards[i]
	var sq = sim.placed_squad(Sim.PLAYER, e["roster_id"])
	var battle := sim.phase == Sim.PHASE_BATTLE
	var out: bool = battle and (sq == null or not sq.is_active())
	var picked: bool = (not battle and e["roster_id"] == selected_id) or (battle and sq != null and sq == selected_squad)
	var placed: bool = sq != null
	var size := b.size
	var bg := Style.RAISED
	if picked:
		bg = Style.RAISED.lightened(0.14)
	elif out or (not battle and placed):
		bg = Style.PANEL
	b.draw_rect(Rect2(Vector2.ZERO, size), bg)
	b.draw_rect(Rect2(Vector2.ZERO, size), Style.BRASS if picked else Style.RULE, false, 3.0 if picked else 2.0)
	var dim := 0.45 if out else 1.0
	_draw_flag(b, Vector2(8, 8), Vector2(28, 21), Sim.PLAYER, String(e["type"]), out, false, 0.0)
	var c = _squad_record(e["roster_id"]).get("captain")
	var who := _name(e["type"], Sim.PLAYER, e["roster_id"])
	if c != null:
		who = String(c["first"]) + ("*" if int(c.get("wounded", 0)) > 0 else "")
	var men: int = e["men"] if sq == null else sq.alive_count()
	b.draw_string(font, Vector2(size.x - 6.0 - 40.0, 27), str(men), HORIZONTAL_ALIGNMENT_RIGHT, 40.0, Style.SMALL, Color(Style.TEXT, dim))
	var fit := 21
	while fit > 16 and font.get_string_size(who, HORIZONTAL_ALIGNMENT_LEFT, -1, fit).x > size.x - 12.0:
		fit -= 1
	b.draw_string(font, Vector2(6, 58), who, HORIZONTAL_ALIGNMENT_LEFT, size.x - 12.0, fit, Color(Style.TEXT if not (placed and not battle and not picked) else Style.MUTED, dim))
	if battle and sq != null:
		if sq.is_active():
			var bar := Rect2(6, size.y - 14.0, size.x - 12.0, 7)
			var m := clampf(sq.morale / 100.0, 0.0, 1.0)
			b.draw_rect(bar, Style.NIGHT)
			b.draw_rect(Rect2(bar.position, Vector2(bar.size.x * m, bar.size.y)), Style.morale_color(sq.morale))
			if sim.ability_ready(sq):
				b.draw_circle(Vector2(size.x - 12.0, size.y - 26.0), 5.0, Style.BRASS)
		else:
			b.draw_string(font, Vector2(6, size.y - 6.0), "out", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Style.MUTED)
	elif int(e["level"]) > 1:
		for l in int(e["level"]) - 1:
			b.draw_circle(Vector2(10 + l * 12, size.y - 12.0), 4.0, Style.BRASS)


## A fill over the ability button that drains as its cooldown runs down.
func _draw_ability_cooldown() -> void:
	var sq = selected_squad
	if sq == null:
		return
	var total := float(Troops.ability(sq.type)["cooldown"])
	if sq.ability_left > 0.0:
		var run := float(Troops.ability(sq.type)["seconds"])
		var f: float = sq.ability_left / maxf(0.01, run)
		ability_button.draw_rect(Rect2(0, ability_button.size.y - 8.0, ability_button.size.x * f, 8.0), Style.BRASS)
	elif sq.ability_cd > 0.0:
		var f: float = sq.ability_cd / maxf(0.01, total)
		ability_button.draw_rect(Rect2(0, 0, ability_button.size.x * f, ability_button.size.y), Color(0, 0, 0, 0.35))


# ---------------------------------------------------------------- the death roll

func _draw_roll() -> void:
	if _roll.is_empty():
		return
	var ci := roll_layer
	var t: float = _roll["t"]
	var a := clampf(t / 0.25, 0.0, 1.0) * clampf((ROLL_TIME - t) / 0.35, 0.0, 1.0)
	ci.draw_rect(Rect2(_view.position, _view.size), Color(0, 0, 0, 0.5 * a))
	var w := minf(600.0, _view.size.x - 24.0)
	var box := Rect2(Vector2(_view.get_center().x - w * 0.5, _view.position.y + _view.size.y * 0.14), Vector2(w, 440))
	ci.draw_rect(box, Color(Style.PANEL, 0.97 * a))
	ci.draw_rect(box, Color(Style.BRASS, a), false, 3.0)
	var x := box.position.x
	var y := box.position.y
	ci.draw_string(font, Vector2(x, y + 44), "CAPTAIN DOWN", HORIZONTAL_ALIGNMENT_CENTER, w, Style.SMALL, Color(Style.MUTED, a))
	ci.draw_string(font, Vector2(x, y + 86), String(_roll["name"]), HORIZONTAL_ALIGNMENT_CENTER, w, 34, Color(Style.TEXT, a))
	ci.draw_string(font, Vector2(x, y + 118), String(_roll["company"]), HORIZONTAL_ALIGNMENT_CENTER, w, Style.SMALL, Color(Style.MUTED, a))

	# The die tumbles, slowing, then lands.
	var needed: int = _roll["needed"]
	var chance := needed - 1
	var landed := t >= ROLL_LANDS
	var shown: int = _roll["roll"]
	if not landed:
		var tick := int(pow(t * 6.0, 1.6))
		shown = 1 + int(posmod(tick * 7919 + 13, 100))
	var die := Rect2(Vector2(box.get_center().x - 64, y + 140), Vector2(128, 96))
	ci.draw_rect(die, Color(Style.RAISED, a))
	ci.draw_rect(die, Color(Style.TEXT if not landed else (Style.ENEMY_LIGHT if _roll["fate"] == "killed" else Style.BRASS), a), false, 3.0)
	ci.draw_string(font, Vector2(die.position.x, die.position.y + 72), str(shown), HORIZONTAL_ALIGNMENT_CENTER, die.size.x, 60, Color(Style.TEXT, a))

	# The odds: dies at or under the chance.
	var bar := Rect2(Vector2(x + 30, y + 258), Vector2(w - 60, 18))
	ci.draw_rect(bar, Color(Style.RAISED, a))
	ci.draw_rect(Rect2(bar.position, Vector2(bar.size.x * chance / 100.0, bar.size.y)), Color(Style.ENEMY, 0.85 * a))
	if landed:
		var mx: float = bar.position.x + bar.size.x * float(_roll["roll"]) / 100.0
		ci.draw_rect(Rect2(mx - 2.0, bar.position.y - 6.0, 4.0, bar.size.y + 12.0), Color(Style.TEXT, a))
	ci.draw_string(font, Vector2(x, y + 312), "Needs %d or more to live" % needed, HORIZONTAL_ALIGNMENT_CENTER, w, Style.SMALL, Color(Style.TEXT, a))
	var mods := PackedStringArray(["base %d%%" % Captains.DEATH_CHANCE])
	if _roll["holding"]:
		mods.append("squad holding -%d" % Captains.RESCUED_BY_SQUAD)
	if _roll["friends"]:
		mods.append("friends near -%d" % Captains.RESCUED_BY_FRIENDS)
	if _roll["lucky"]:
		mods.append("lucky -%d" % Captains.LUCK)
	ci.draw_string(font, Vector2(x, y + 342), " · ".join(mods), HORIZONTAL_ALIGNMENT_CENTER, w, 20, Color(Style.MUTED, a))

	if landed:
		var killed: bool = _roll["fate"] == "killed"
		var verdict := "FALLEN" if killed else "WOUNDED · OUT FOR %d BATTLES" % Captains.WOUND_BATTLES
		ci.draw_string(font, Vector2(x, y + 388), verdict, HORIZONTAL_ALIGNMENT_CENTER, w, Style.LARGE, Color(Style.ENEMY_LIGHT if killed else Style.BRASS, a))
		ci.draw_string(font, Vector2(x + 16, y + 424), "\"%s\"" % _roll["words"], HORIZONTAL_ALIGNMENT_CENTER, w - 32.0, Style.SMALL, Color(Style.TEXT, a))


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	if sim == null:
		return
	_draw_field()
	draw_set_transform(field_origin, 0.0, Vector2(field_scale, field_scale))
	_draw_scars()
	_draw_zones()
	_draw_objectives()
	for c in sim.corpses:
		var horse: bool = c.get("type", "") == Troops.CAVALRY
		var p: Vector2 = c["pos"]
		# A steady, random-looking angle per body, so the dead don't spin between frames.
		var angle := fposmod(p.x * 12.9898 + p.y * 78.233, TAU)
		_sprite("corpse_horse" if horse else "corpse", c["team"], 0, p, angle, Color(1, 1, 1, 0.8))
	draw_set_transform(field_origin, 0.0, Vector2(field_scale, field_scale))
	_draw_stuck_arrows()
	_draw_orders()
	_draw_targets()
	_draw_line_order()
	_draw_shadows()
	for sq in sim.squads:
		_draw_men(sq)
	draw_set_transform(field_origin, 0.0, Vector2(field_scale, field_scale))
	_draw_treetops()
	_draw_arrows()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_standards()
	draw_set_transform(field_origin, 0.0, Vector2(field_scale, field_scale))
	_draw_floaters()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_ticker()


## Pixel-art ground for the land the battle is in, and what grows on it.
func _draw_field() -> void:
	var px := Art.GRASS_PIXEL
	draw_set_transform(field_origin, 0.0, Vector2(field_scale * px, field_scale * px))
	draw_texture_rect(Art.ground(_biome), Rect2(Vector2.ZERO, Sim.ARENA / px), true)
	draw_set_transform(field_origin, 0.0, Vector2(field_scale, field_scale))

	# Elevation shading & contour lines
	if _height_tex != null:
		draw_texture_rect(_height_tex, Rect2(Vector2.ZERO, Sim.ARENA), false)

	# Rivers, fords, and rock outcrops
	_draw_terrain_features()

	var look: Dictionary = Art.GROUND.get(_biome, Art.GROUND["vardish"])
	for patch in _patches:
		draw_set_transform(field_origin + Vector2(patch["pos"]) * field_scale, 0.0, Vector2(field_scale, field_scale * 0.7))
		draw_circle(Vector2.ZERO, patch["r"], Color(look["light"] if patch["light"] else look["tuft"], 0.22))
	for d in _doodads:
		var s: float = field_scale * Art.FOOT_PIXEL * float(d["scale"])
		draw_set_transform(field_origin + Vector2(d["pos"]) * field_scale, 0.0, Vector2(s * float(d["flip"]), s))
		draw_texture(Art.frame(d["name"], 0, 0, _biome), -Art.pivot(d["name"], _biome))
	draw_set_transform(field_origin, 0.0, Vector2(field_scale, field_scale))
	draw_rect(Rect2(Vector2.ZERO, Sim.ARENA), Color(0, 0, 0, 0.4), false, 4.0)


func _draw_terrain_features() -> void:
	if sim == null or sim.terrain == null:
		return
	var t: Terrain = sim.terrain
	for feat in t.features:
		var ft: String = feat.get("type", "")
		if ft == "woods":
			# The forest floor: shade that deepens toward the middle of the stand.
			var c: Vector2 = feat["center"]
			var r: float = float(feat["radius"])
			for k in WOODS_FLOOR_RINGS:
				draw_circle(c, r * (1.0 - 0.18 * k), Color(WOODS_FLOOR, 0.16 + 0.04 * k))
			draw_arc(c, r, 0.0, TAU, 48, Color(WOODS_FLOOR.darkened(0.3), 0.55), 2.0)
		elif ft == "river":
			var half_w: float = float(feat.get("half_width", 38.0))
			var phase: float = float(feat.get("phase", 0.0))
			var bend: float = float(feat.get("bend", BattleSite.RIVER_BEND))
			var fords: Array = feat.get("fords", [])
			var ford_w: float = float(feat.get("ford_width", 90.0))

			var pts_top := PackedVector2Array()
			var pts_bot := PackedVector2Array()
			var x_step := 20.0
			var x := 0.0
			while x <= Sim.ARENA.x + x_step:
				var ry := 630.0 + sin(x * 0.007 + phase) * bend
				pts_top.append(Vector2(x, ry - half_w))
				pts_bot.append(Vector2(x, ry + half_w))
				x += x_step
			var poly := PackedVector2Array()
			poly.append_array(pts_top)
			pts_bot.reverse()
			poly.append_array(pts_bot)
			draw_colored_polygon(poly, Color(0.14, 0.30, 0.54, 0.88))

			for fx in fords:
				var fry := 630.0 + sin(fx * 0.007 + phase) * bend
				var ford_rect := Rect2(fx - ford_w * 0.5, fry - half_w - 4.0, ford_w, half_w * 2.0 + 8.0)
				draw_rect(ford_rect, Color(0.38, 0.68, 0.72, 0.80))
				draw_rect(ford_rect, Color(0.72, 0.64, 0.42, 0.85), false, 2.0)

		elif ft == "rock" or ft == "building":
			var rect: Rect2 = feat.get("rect", Rect2())
			if rect.size != Vector2.ZERO:
				draw_rect(rect, Color(0.24, 0.22, 0.20, 0.95))
				draw_rect(rect, Color(0.12, 0.10, 0.09, 0.95), false, 3.0)


## Draw treetops over troops, a little see-through so men in the woods still show.
func _draw_treetops() -> void:
	if _trees.is_empty():
		return
	for tree in _trees:
		var tex: Texture2D = MapArt.texture(tree["name"])
		if tex == null:
			continue
		var p: Vector2 = tree["pos"]
		var s: float = float(tree["scale"]) * 1.6
		var flip: float = float(tree["flip"])
		var sz := MapArt.size(tree["name"])
		var dest := Rect2(p.x - sz.x * s * 0.5 * flip, p.y - sz.y * s, sz.x * s * flip, sz.y * s)
		draw_texture_rect(tex, dest, false, Color(1, 1, 1, TREETOP_ALPHA))


func _setup_terrain_visuals() -> void:
	if sim == null or sim.terrain == null:
		return
	var t: Terrain = sim.terrain
	_trees.clear()
	_terrain_site_type = "open"

	# Build shaded height image
	var iw := 112
	var ih := 168
	var img := Image.create_empty(iw, ih, false, Image.FORMAT_RGBA8)
	var has_height := false
	for y in ih:
		for x in iw:
			var p := Vector2((x + 0.5) / float(iw) * Sim.ARENA.x, (y + 0.5) / float(ih) * Sim.ARENA.y)
			var h := t.height_at(p)
			if h > 0.04:
				has_height = true
				var alpha := clampf(h * 0.40, 0.0, 0.45)
				var mod_h := fmod(h, 0.20)
				if mod_h < 0.025 and h > 0.15:
					img.set_pixel(x, y, Color(1.0, 0.92, 0.65, 0.60))
				else:
					img.set_pixel(x, y, Color(1.0, 1.0, 0.85, alpha))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	if has_height:
		_height_tex = ImageTexture.create_from_image(img)
	else:
		_height_tex = null

	# Populate woods trees
	var tree_name := "tree"
	match _biome:
		Cultures.VARDISH:
			tree_name = "tree"
		Cultures.KHARZANI:
			tree_name = "palm"
		Cultures.RYUMON:
			tree_name = "blossom"
	var rng := RandomNumberGenerator.new()
	rng.seed = 999
	for cy in Terrain.ROWS:
		for cx in Terrain.COLS:
			var idx := cy * Terrain.COLS + cx
			if t.woods[idx] == Terrain.WOODS_TREES:
				_terrain_site_type = "woods"
				var cp := t.cell_pos(cx, cy)
				for k in 3:
					var p := cp + Vector2(rng.randf_range(-13.0, 13.0), rng.randf_range(-13.0, 13.0))
					var kind := tree_name
					if _biome == Cultures.VARDISH and t.height_at(p) > 0.4:
						kind = "pine"
					_trees.append({
						"pos": p,
						"name": kind,
						"scale": rng.randf_range(1.1, 1.4),
						"flip": 1.0 if rng.randf() < 0.5 else -1.0,
					})
	_trees.sort_custom(func(a, b): return a["pos"].y < b["pos"].y)

	for feat in t.features:
		var ft: String = feat.get("type", "")
		if ft == "river":
			_terrain_site_type = "river"
		elif ft == "hill" or ft == "ridge":
			if _terrain_site_type == "open":
				_terrain_site_type = "hills"
		elif ft == "rock":
			_terrain_site_type = "pass"
		elif ft == "building":
			_terrain_site_type = "village"


func _maybe_show_terrain_hint() -> void:
	var cfg := ConfigFile.new()
	cfg.load(Sound.SETTINGS_PATH)

	# 1. Objective hint cards
	var obj_key := sim.objective if sim != null else "rout"
	if obj_key != "rout" and not bool(cfg.get_value("objective_hints", obj_key, false)):
		var obj_texts := {
			"chief": ["Slay the Chief", "The enemy host is led by a named chieftain at the head of an elite bodyguard squad. Break or fell the bodyguard and the rest of the host suffers a catastrophic -35 morale shock. Slay the chief for double bounty and renown; do not let him flee the field!"],
			"ambush": ["Ambushed in the Woods!", "You have been caught marching down a road in dense woods. Your warband starts unbraced in a vulnerable narrow column, while enemy pincers strike simultaneously from both ends. You cannot withdraw; fight to the last man!"],
			"village": ["Village Defense", "Bandits are raiding the village! Hold the central village square for 2 minutes against arriving waves of reinforcements. Win by routing the attackers or holding the square when time expires."],
		}
		var o_card: Array = obj_texts.get(obj_key, [])
		if not o_card.is_empty():
			terrain_hint_title.text = o_card[0]
			terrain_hint_body.text = o_card[1]
			terrain_hint_panel.visible = true
			cfg.set_value("objective_hints", obj_key, true)
			cfg.save(Sound.SETTINGS_PATH)
			return

	# 2. Terrain hint cards
	if _terrain_site_type == "" or _terrain_site_type == "open":
		return
	if bool(cfg.get_value("terrain_hints", _terrain_site_type, false)):
		return
	var texts := {
		"hills": ["Hills & Ridges", "High ground grants archers up to +25% range and downhill fighters a 25% damage advantage. Charging uphill grants no charge shock or bonus."],
		"woods": ["Woods & Forests", "Dense stands slow foot troops by 25% and cavalry by 50%. Tree cover intercepts 50% of incoming arrows, cuts volley shock in half, and prevents cavalry charges."],
		"river": ["River Fords", "Deep river water is impassable; troops must cross at shallow fords. Soldiers fighting in shallow water take +25% damage and cannot brace."],
		"pass": ["Rocky Pass", "Impassable stone narrows the center of the field into a bottleneck. Arrows fly freely over the rocks."],
		"village": ["Village Streets", "Buildings and walls divide the combat zone into tight streets and chokepoints."],
	}
	var card_data: Array = texts.get(_terrain_site_type, [])
	if card_data.is_empty():
		return
	terrain_hint_title.text = card_data[0]
	terrain_hint_body.text = card_data[1]
	terrain_hint_panel.visible = true

	cfg.set_value("terrain_hints", _terrain_site_type, true)
	cfg.save(Sound.SETTINGS_PATH)


func _terrain_hint(p: Vector2) -> String:
	if sim == null or sim.terrain == null:
		return ""
	var t: Terrain = sim.terrain
	if t.rock_at(p) != Terrain.ROCK_NONE:
		return "Rock: impassable obstacle. Troops must go around; arrows fly over."
	if t.water_at(p) == Terrain.WATER_DEEP:
		return "Deep Water: impassable river. Troops must cross at shallow fords."
	if t.water_at(p) == Terrain.WATER_SHALLOW:
		return "Shallow Ford: 50% movement speed, +25% damage taken, no charges or bracing."
	if t.in_woods(p):
		return "Woods: slows horse by 50% (foot 25%), 50% arrow block, no charges."
	if t.height_at(p) > 0.35:
		var pct := int(t.height_at(p) * 100.0)
		return "High Ground (%d%% elevation): +25%% archer range, uphill melee damage advantage." % pct
	return ""


## A few rocks and bushes, more scrub and stone in the desert, more green on the isles,
## over broad patches of lighter and darker ground.
## Only for looks: men walk over them.
func _scatter_doodads() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var kinds: Array = {"kharzani": ["rock0", "rock1", "rock1", "bush", "bush"],
		"ryumon": ["bush", "bush", "bush", "rock0", "rock1"]}.get(_biome, ["bush", "bush", "rock0", "rock1"])
	for i in 18:
		var pos := Vector2(rng.randf_range(20.0, Sim.ARENA.x - 20.0), rng.randf_range(20.0, Sim.ARENA.y - 20.0))
		_doodads.append({"name": kinds[rng.randi_range(0, kinds.size() - 1)], "pos": pos,
			"scale": rng.randf_range(1.4, 2.2), "flip": 1.0 if rng.randf() < 0.5 else -1.0})
	for i in 12:
		_patches.append({"pos": Vector2(rng.randf_range(0.0, Sim.ARENA.x), rng.randf_range(0.0, Sim.ARENA.y)),
			"r": rng.randf_range(60.0, 150.0), "light": rng.randf() < 0.5})


## The culture a squad's men are dressed in: the enemy's, or for one of yours, the
## culture it was raised in.
func _culture_of(sq) -> String:
	var key := "%d/%d" % [sq.team, sq.roster_id]
	if not _cultures.has(key):
		var c := _enemy_culture
		if sq.team == Sim.PLAYER:
			c = String(_squad_record(sq.roster_id).get("culture", GameState.culture))
		_cultures[key] = c
	return _cultures[key]


## Trampled, bloodied ground where men fell, so the field remembers the fight.
func _draw_scars() -> void:
	for c in sim.corpses:
		var p: Vector2 = c["pos"]
		draw_circle(p + Vector2(2, 3), 11.0, Color(0.27, 0.19, 0.09, 0.16))
		draw_circle(p, 5.0, Color(0.36, 0.08, 0.06, 0.18))


func _draw_zones() -> void:
	if sim.phase != Sim.PHASE_DEPLOY or sim.winner != -1:
		return
	draw_dashed_line(Vector2(0.0, Sim.MID_Y), Vector2(Sim.ARENA.x, Sim.MID_Y), Color(1, 1, 1, 0.35), 3.0, 14.0)
	var zone := sim.deploy_zone(Sim.PLAYER)
	var picking := selected_id != -1
	draw_rect(zone, Color(Style.PLAYER, 0.22 if picking else 0.12))
	draw_rect(zone, Color(Style.PLAYER_LIGHT, 0.85 if picking else 0.4), false, 3.0)
	draw_rect(sim.deploy_zone(Sim.ENEMY), Color(Style.ENEMY, 0.08))


func _draw_objectives() -> void:
	if sim == null:
		return
	if sim.objective == Sim.OBJECTIVE_VILLAGE:
		var pulse := 0.5 + 0.5 * sin(_clock * 3.0)
		draw_circle(Sim.VILLAGE_ZONE_CENTER, Sim.VILLAGE_ZONE_RADIUS, Color(Style.PLAYER, 0.08 + pulse * 0.04))
		draw_arc(Sim.VILLAGE_ZONE_CENTER, Sim.VILLAGE_ZONE_RADIUS, 0.0, TAU, 48, Color(Style.PLAYER_LIGHT, 0.75), 3.0)
		if sim.phase == Sim.PHASE_BATTLE and sim.winner == -1:
			var remain := maxf(0.0, Sim.VILLAGE_DURATION - sim.time)
			var mins := int(remain) / 60
			var secs := int(remain) % 60
			var time_str := "%d:%02d" % [mins, secs]
			draw_string(font, Sim.VILLAGE_ZONE_CENTER + Vector2(-60.0, -170.0), "Defend: %s" % time_str, HORIZONTAL_ALIGNMENT_CENTER, 120.0, Style.BODY, Style.BRASS)
		# How near the raiders are to firing it: they get there by holding the square.
		if sim.village_burn > 0.0:
			var burnt := sim.village_burn / Sim.VILLAGE_BURN
			draw_arc(Sim.VILLAGE_ZONE_CENTER, Sim.VILLAGE_ZONE_RADIUS + 9.0, -PI * 0.5, -PI * 0.5 + TAU * burnt, 48,
				Color(1.0, 0.45, 0.12, 0.9), 7.0)
			var counts: Array = sim.men_in_village()
			if counts[Sim.ENEMY] > counts[Sim.PLAYER] * Sim.VILLAGE_TAKEN:
				draw_string(font, Sim.VILLAGE_ZONE_CENTER + Vector2(-90.0, Sim.VILLAGE_ZONE_RADIUS + 44.0), "They're firing the village!",
					HORIZONTAL_ALIGNMENT_CENTER, 180.0, Style.SMALL, Color(1.0, 0.55, 0.25))
	if sim.objective == Sim.OBJECTIVE_CHIEF:
		for sq in sim.squads:
			if (sq.is_bodyguard or sq.is_chief) and sq.is_active():
				var pulse := 0.5 + 0.5 * sin(_clock * 4.0)
				var r := minf(sq.extent, 65.0) + 14.0 + pulse * 4.0
				draw_arc(sq.average_pos(), r, 0.0, TAU, 36, Color(Style.BRASS, 0.7 + pulse * 0.3), 3.5)
	for r in sim.scheduled_reinforcements:
		if not r.get("spawned", false) and sim.time >= float(r.get("at_time", 0.0)) - 10.0:
			var edge: String = String(r.get("edge", "north"))
			var pt := Vector2(Sim.ARENA.x * 0.5, 40.0)
			var dir := Vector2.DOWN
			match edge:
				"north":
					pt = Vector2(Sim.ARENA.x * 0.5, 40.0)
					dir = Vector2.DOWN
				"south":
					pt = Vector2(Sim.ARENA.x * 0.5, Sim.ARENA.y - 40.0)
					dir = Vector2.UP
				"east":
					pt = Vector2(Sim.ARENA.x - 40.0, Sim.MID_Y)
					dir = Vector2.LEFT
				"west":
					pt = Vector2(40.0, Sim.MID_Y)
					dir = Vector2.RIGHT
			var right := Vector2(-dir.y, dir.x)
			var tip := pt + dir * 20.0
			draw_colored_polygon(PackedVector2Array([tip, pt + right * 14.0, pt - right * 14.0]), Color(Style.ENEMY_LIGHT, 0.85))


func _draw_stuck_arrows() -> void:
	for a in sim.stuck_arrows:
		var p: Vector2 = a["pos"]
		var d := Vector2.from_angle(float(a["angle"]))
		draw_line(p - d * 5.0, p + d * 1.5, Color(0.29, 0.2, 0.12, 0.85), 1.4)
		draw_circle(p - d * 5.0, 1.3, Color(0.93, 0.9, 0.84, 0.85))


## Draw sprite `name` with its pivot at arena point `at`, turned by `angle` (0 = facing
## up), dressed as `culture` dresses it.
func _sprite(name: String, team: int, index: int, at: Vector2, angle: float, tint: Color = Color.WHITE, grow: float = 1.0,
		culture: String = Cultures.VARDISH) -> void:
	var s := field_scale * Art.pixel_size(name) * grow
	draw_set_transform(field_origin + at * field_scale, angle, Vector2(s, s))
	draw_texture(Art.frame(name, team, index, culture), -Art.pivot(name, culture), tint)


func _draw_orders() -> void:
	var sel = selected_squad
	# While deploying, the picked squad's bow range.
	if sim.phase == Sim.PHASE_DEPLOY:
		var picked = sim.placed_squad(Sim.PLAYER, selected_id)
		if picked != null and picked.ranged:
			draw_arc(picked.center, picked.reach, 0.0, TAU, 64, Color(Style.PLAYER_LIGHT, 0.35), 2.0)
		return
	if sel == null or not sel.is_active():
		return
	var from: Vector2 = sel.average_pos()
	var ring: float = minf(sel.extent, 70.0) + 16.0
	draw_circle(from, ring, Color(Style.BRASS, 0.12))
	draw_arc(from, ring, 0.0, TAU, 48, Color(Style.BRASS, 0.9), 3.0)
	if sel.ranged:
		draw_arc(from, sel.reach, 0.0, TAU, 64, Color(Style.PLAYER_LIGHT, 0.3), 2.0)
	if sel.wheeling:
		draw_dashed_line(from, sel.wheel_point, Color(Style.BRASS, 0.7), 2.0, 10.0)
	elif sel.order == "move" or sel.order == "hold":
		var to: Vector2 = sel.order_point
		if from.distance_to(to) > 20.0:
			draw_dashed_line(from, to, Style.BRASS, 3.0, 12.0)
		draw_arc(to, 16.0, 0.0, TAU, 24, Style.BRASS, 3.0)
	elif sel.order == "attack" and sel.order_target != null and sel.order_target.is_active():
		draw_dashed_line(from, sel.order_target.average_pos(), Style.ENEMY_LIGHT, 3.0, 12.0)
	elif sel.order == "advance" and sel.focus != null and sel.focus.is_active():
		draw_dashed_line(from, sel.focus.average_pos(), Color(Style.ENEMY_LIGHT, 0.6), 2.0, 10.0)


## Soft shadows lift the men off the grass.
func _draw_shadows() -> void:
	for sq in sim.squads:
		var big: float = 5.0 if sq.type == Troops.CAVALRY else 1.5
		for so in sq.soldiers:
			if not so.alive:
				continue
			draw_set_transform(field_origin + (so.pos + Vector2(1.5, 3.0)) * field_scale, 0.0, Vector2(field_scale, field_scale * 0.62))
			draw_circle(Vector2.ZERO, so.radius + big, Color(0.05, 0.08, 0.02, 0.32))
	draw_set_transform(field_origin, 0.0, Vector2(field_scale, field_scale))


func _draw_men(sq) -> void:
	# A trained squad is drawn in its branch's own kit.
	var type: String = sq.unit if sq.unit != "" else sq.type
	var culture := _culture_of(sq)
	var tint := Color(0.72, 0.72, 0.72, 0.9) if sq.routing else Color.WHITE
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
		_sprite(type, sq.team, index, so.pos, angle, tint, grow, culture)
		if so.flash > 0.05:
			draw_texture(Art.flash(type, index, culture), -Art.pivot(type, culture), Color(1, 1, 1, so.flash * 0.8))


## Arrows rise and fall on their way, with a shadow on the ground beneath them.
func _draw_arrows() -> void:
	for p in sim.projectiles:
		var to: Vector2 = p.aim - p.pos
		if to.length() < 0.01:
			continue
		var done: float = p.origin.distance_to(p.pos)
		var total: float = done + to.length()
		var t: float = done / maxf(1.0, total)
		var rise := minf(70.0, total * 0.2)
		var height := 4.0 * rise * t * (1.0 - t)
		var dir := to.normalized()
		draw_set_transform(field_origin, 0.0, Vector2(field_scale, field_scale))
		draw_line(p.pos - dir * 4.0, p.pos + dir * 4.0, Color(0, 0, 0, 0.22), 1.5)
		var slope := 4.0 * rise * (1.0 - 2.0 * t) / maxf(1.0, total)
		var screen_dir := (dir - Vector2(0, slope)).normalized()
		_sprite("arrow", 0, 0, p.pos - Vector2(0, height), screen_dir.angle() + PI * 0.5)


## Every squad carries a standard over it: its type, a morale bar and a head count. A
## squad's standard topples when it breaks. Standards that would overlap fan out.
func _draw_standards() -> void:
	_std_tops.clear()
	var ref_type := ""
	if selected_squad != null:
		ref_type = selected_squad.type
	elif sim.phase == Sim.PHASE_DEPLOY and selected_id != -1:
		for e in _cards:
			if e["roster_id"] == selected_id:
				ref_type = e["type"]
	var shown: Array = []
	for sq in sim.squads:
		if sq.alive_n > 0:
			shown.append(sq)
	# Fan out: start from the squad's own spot, then push overlapping flags apart.
	var want := {}
	for sq in shown:
		want[sq] = _to_screen(sq.avg).x
	for pass_i in 6:
		for i in shown.size():
			for j in range(i + 1, shown.size()):
				var a = shown[i]
				var b = shown[j]
				var ya: float = _to_screen(a.avg).y
				var yb: float = _to_screen(b.avg).y
				if absf(ya - yb) > FLAG.y + 22.0:
					continue
				var gap: float = want[b] - want[a]
				var need := FLAG.x + 8.0
				if absf(gap) < need:
					var push := (need - absf(gap)) * 0.5 * (1.0 if gap >= 0.0 else -1.0)
					if absf(gap) < 0.01:
						push = need * 0.5
					want[a] -= push
					want[b] += push
	for sq in shown:
		var x: float = want[sq]
		_std_x[sq] = lerpf(float(_std_x.get(sq, x)), x, 0.25)
		_draw_standard(sq, float(_std_x[sq]), ref_type)
	for foe in _targeted():
		if _std_tops.has(foe):
			_draw_crossed_swords(_std_tops[foe] + Vector2(FLAG.x * 0.5, -40.0))


func _draw_standard(sq, flag_x: float, ref_type: String) -> void:
	var mine: bool = sq.team == Sim.PLAYER
	var base := _to_screen(sq.avg)
	var fall := 0.0
	if sq.routing:
		fall = clampf((_clock - float(_broke_at.get(sq, _clock - 1.0))) / 0.7, 0.0, 1.0)
		fall = 1.0 - pow(1.0 - fall, 3.0)
	# Dip forward for a moment when ordered.
	var dip := 0.0
	var since: float = _clock - float(_ordered_at.get(sq, -9.0))
	if since < 0.5:
		dip = sin(since / 0.5 * PI) * 0.35
	var lean := deg_to_rad(68.0) * fall * (1.0 if mine else -1.0) + dip * (1.0 if sq.facing.x >= 0.0 else -1.0)
	var top := Vector2(flag_x, base.y) + Vector2(sin(lean), -cos(lean)) * POLE
	var selected: bool = sq == selected_squad or (mine and sim.phase == Sim.PHASE_DEPLOY and sq.roster_id == selected_id)
	draw_line(base + Vector2(1, 1), top + Vector2(1, 1), Color(0, 0, 0, 0.5), 4.0)
	draw_line(base, top, Color("6b4a2a"), 3.0)
	var ready: bool = mine and sim.ability_ready(sq)
	draw_circle(top, 5.0 if ready else 3.5, Style.BRASS if ready or not sq.routing else Color(0.5, 0.5, 0.5))
	if not sq.routing:
		_std_tops[sq] = top
	var edge := Style.BRASS if selected or sq.braced() else Color(0.06, 0.05, 0.08)
	_draw_flag(self, top + Vector2(0, 2), FLAG, sq.team, sq.type, sq.routing, selected or sq.braced(), lean, edge)
	if sq.is_bodyguard or sq.is_chief:
		var crown_c := top + Vector2(FLAG.x * 0.5, -16.0)
		draw_colored_polygon(PackedVector2Array([
			crown_c + Vector2(-9, 5), crown_c + Vector2(-9, -4), crown_c + Vector2(-5, 0),
			crown_c + Vector2(0, -7), crown_c + Vector2(5, 0), crown_c + Vector2(9, -4),
			crown_c + Vector2(9, 5)
		]), Style.BRASS)
	if sq.routing or sim.phase != Sim.PHASE_BATTLE:
		if not mine and ref_type != "":
			_draw_counter_hint(top, sq.type, ref_type)
		return
	var bar := Rect2(top + Vector2(-2, FLAG.y + 9.0), Vector2(36, 6))
	var m := clampf(sq.morale / 100.0, 0.0, 1.0)
	draw_rect(bar.grow(1.5), Color(0.05, 0.05, 0.08, 0.85))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * m, bar.size.y)), Style.morale_color(sq.morale))
	var count := str(sq.alive_n)
	draw_string_outline(font, top + Vector2(38, FLAG.y + 17.0), count, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 4, Color(0, 0, 0, 0.9))
	draw_string(font, top + Vector2(38, FLAG.y + 17.0), count, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Style.TEXT)
	if sq.ability_left > 0.0 or sq.wheeling:
		draw_rect(Rect2(top + Vector2(-4, -2), FLAG + Vector2(8, 8)), Color(Style.BRASS, 0.8), false, 2.0)
	if not mine and ref_type != "":
		_draw_counter_hint(top, sq.type, ref_type)


## Enemy squads one of yours has been ordered to attack, still fighting.
func _targeted() -> Array:
	var out := []
	if sim.phase != Sim.PHASE_BATTLE:
		return out
	for sq in sim.squads:
		if sq.team == Sim.PLAYER and sq.is_active() and sq.order == "attack" and sq.order_target != null \
				and sq.order_target.is_active() and not out.has(sq.order_target):
			out.append(sq.order_target)
	return out


## A pulsing red ring around every enemy squad you've sent someone to attack.
func _draw_targets() -> void:
	var pulse := 0.5 + 0.5 * sin(_clock * 5.0)
	for foe in _targeted():
		var r: float = minf(foe.extent, 70.0) + 18.0 + pulse * 5.0
		draw_arc(foe.average_pos(), r, 0.0, TAU, 40, Color(0, 0, 0, 0.55), 8.0)
		draw_arc(foe.average_pos(), r, 0.0, TAU, 40, Color(TARGET_RED, 0.75 + 0.25 * pulse), 4.5)


## Two blades crossed over a standard: this squad is someone's target.
func _draw_crossed_swords(c: Vector2) -> void:
	for side in [-1.0, 1.0]:
		var tip := c + Vector2(-13.0 * side, -13.0)
		var hilt := c + Vector2(10.0 * side, 10.0)
		var guard := (hilt - tip).normalized().orthogonal() * 6.0
		for pass_i in 2:
			var w := 7.0 if pass_i == 0 else 3.5
			var col := Color(0.06, 0.05, 0.08, 0.95) if pass_i == 0 else TARGET_RED.lightened(0.25)
			draw_line(tip, hilt, col, w)
			draw_line(hilt - (hilt - tip).normalized() * 3.0 + guard, hilt - (hilt - tip).normalized() * 3.0 - guard, col, w)


## The line being drawn, with where each squad will stand on it and which way it will
## face; then, for a moment, the line just ordered.
func _draw_line_order() -> void:
	if _drawing:
		var b := _to_field(_drag_to)
		var only = selected_squad if sim.phase == Sim.PHASE_BATTLE else null
		var spots := sim.line_preview(Sim.PLAYER, _press_field, b, only)
		draw_line(_press_field, b, Color(0, 0, 0, 0.5), 7.0)
		draw_line(_press_field, b, Style.BRASS, 3.0)
		_draw_spots(spots, sim.line_face(Sim.PLAYER, _press_field, b), 1.0, true)
	elif not _line_shown.is_empty():
		var age: float = _clock - float(_line_shown["at"])
		if age > LINE_SHOWN:
			_line_shown = {}
			return
		_draw_spots(_line_shown["spots"], _line_shown["face"], 1.0 - age / LINE_SHOWN, false)


## Each squad's place on a line: the ground it will cover and an arrow the way it faces,
## and while drawing, a thread from where it stands now.
func _draw_spots(spots: Array, face: Vector2, alpha: float, live: bool) -> void:
	var right := Vector2(-face.y, face.x)
	for spot in spots:
		var at: Vector2 = spot["at"]
		var half: Vector2 = spot["half"]
		var sq = spot["squad"]
		if live and sq.alive_n > 0:
			draw_dashed_line(sq.average_pos(), at, Color(Style.BRASS, 0.45 * alpha), 2.0, 8.0)
		var box := PackedVector2Array([at - right * half.x - face * half.y, at + right * half.x - face * half.y,
			at + right * half.x + face * half.y, at - right * half.x + face * half.y])
		draw_colored_polygon(box, Color(Style.BRASS, 0.16 * alpha))
		box.append(box[0])
		draw_polyline(box, Color(Style.BRASS, 0.9 * alpha), 2.0)
		var tip := at + face * (half.y + 16.0)
		draw_colored_polygon(PackedVector2Array([tip, tip - face * 10.0 + right * 7.0, tip - face * 10.0 - right * 7.0]),
			Color(Style.BRASS, 0.9 * alpha))


## ▲ over an enemy your selected squad beats; ▼ over one that beats it.
func _draw_counter_hint(top: Vector2, type: String, ref_type: String) -> void:
	var c := top + Vector2(FLAG.x * 0.5, -12.0)
	if Troops.COUNTERED_BY[type] == ref_type:
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -9), c + Vector2(9, 6), c + Vector2(-9, 6)]), Style.MORALE_HIGH)
	elif Troops.COUNTERED_BY[ref_type] == type:
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, 7), c + Vector2(9, -8), c + Vector2(-9, -8)]), Style.MORALE_LOW)


## A team's flag on `ci`: a swallowtail for you, square for them, with a glyph for the
## troop type.
func _draw_flag(ci: CanvasItem, at: Vector2, size: Vector2, team: int, type: String, grey: bool, lit: bool, lean: float, edge: Color = Heraldry.EDGE) -> void:
	var mine := team == Sim.PLAYER
	Heraldry.flag(ci, at, size, Style.PLAYER if mine else Style.ENEMY, Style.PLAYER_DARK if mine else Style.ENEMY_DARK,
		mine, type, grey, lit, lean, edge)


func _draw_floaters() -> void:
	for f in floaters:
		var age: float = f["age"]
		var a := clampf(float(f["life"]) - age, 0.0, 1.0)
		var pos: Vector2 = f["pos"] + Vector2(-200.0, -minf(age, 1.3) * 34.0)
		var color: Color = f["color"]
		var size := int(28.0 / maxf(0.1, field_scale))
		draw_string_outline(font, pos, f["text"], HORIZONTAL_ALIGNMENT_CENTER, 400.0, size, 6, Color(0, 0, 0, a))
		draw_string(font, pos, f["text"], HORIZONTAL_ALIGNMENT_CENTER, 400.0, size, Color(color, a))


## The story so far, along the top of the field.
func _draw_ticker() -> void:
	var y := _view.position.y + 30.0
	for t in ticker:
		var age: float = t["age"]
		var a := clampf(float(t["life"]) - age, 0.0, 1.0) * clampf(age / 0.2, 0.0, 1.0)
		var color: Color = t["color"]
		draw_string_outline(font, Vector2(_view.position.x + 12.0, y), t["text"], HORIZONTAL_ALIGNMENT_CENTER, _view.size.x - 24.0, Style.SMALL, 6, Color(0, 0, 0, 0.85 * a))
		draw_string(font, Vector2(_view.position.x + 12.0, y), t["text"], HORIZONTAL_ALIGNMENT_CENTER, _view.size.x - 24.0, Style.SMALL, Color(color, a))
		y += 30.0
