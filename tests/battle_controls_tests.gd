extends SceneTree
const Cultures = preload("res://scripts/data/cultures.gd")
const State = preload("res://scripts/game_state.gd")
const Economy = preload("res://scripts/data/economy.gd")
const WorldData = preload("res://scripts/world/world_data.gd")
const Sim = preload("res://scripts/battle/battle_sim.gd")
const Troops = preload("res://scripts/data/troops.gd")
var failures := 0
func check(ok: bool, text: String) -> void:
	print(("ok " if ok else "FAIL ") + text)
	if not ok: failures += 1
func _init() -> void:
	_run.call_deferred()
func _run() -> void:
	var gs = root.get_node("GameState")
	gs.persist = false
	gs.new_campaign(Cultures.VARDISH)
	change_scene_to_file("res://scenes/battle.tscn")
	await process_frame
	await process_frame
	var screen = current_scene
	screen.set_process(false)
	screen._on_auto()
	screen._start_battle()
	screen._select(screen.sim.squads[0])
	screen._refresh_hud()
	check(screen.info_label.text.begins_with("Selected:"), "selected squad scope is explicit")
	screen._select(null)
	screen._refresh_hud()
	check(screen.info_label.text.begins_with("Whole army") and screen.advance_button.tooltip_text == "Advance all", "company orders clearly show their scope")
	check(screen.info_strip.tooltip_text == screen.info_label.text and not screen._strip_items.is_empty(),
		"the selection reads as icons, the sentence kept as the strip's tooltip")
	# The order bar has its words in a campaign's first battles, then the icons alone.
	check(gs.battles < screen.ORDER_WORD_BATTLES and screen.advance_button.text == "Advance all", "a new campaign's order bar has words")
	screen._hint("", "")
	screen._hinted.clear()
	screen._hint("The whole army holds.", "hold_probe")
	check(screen.hint_label.text == "The whole army holds." and screen.hint_toast.visible, "and its orders are narrated while they're new")
	screen._order_words = false
	screen._refresh_hud()
	check(screen.advance_button.text == "Advance all" and screen.advance_button.tooltip_text == "Advance all" and screen.advance_button.icon != null,
		"after the first battles the order bar keeps its words under the icons (touch has no tooltips)")
	screen._hint("Out of arrows.")
	screen._hint("The whole army advances.", "advance_probe")
	check(screen.hint_label.text == "Out of arrows.", "and only refusals and first sights reach the hint")
	screen._hint("Your archers are out of arrows.", "state_probe", false)
	check(screen.hint_label.text == "Your archers are out of arrows.", "but a state the field just changed is still said, in any battle")
	screen._order_words = true
	screen._refresh_hud()
	# With no squad selected, the bows' orders go to every company of them.
	var bows: Array = screen._player_bows()
	if not bows.is_empty():
		check(screen.hold_fire_button.visible and screen.hold_fire_button.text == "Hold fire (all bows)"
			and screen.ability_button.visible and screen.ability_button.text == "Volley (all)",
			"with nothing selected the bar offers Hold fire and Volley for all bows")
		screen._on_hold_fire()
		check(bows.all(func(bw): return bw.hold_fire), "and Hold fire (all bows) holds every company's arrows")
		screen._refresh_hud()
		check(screen.hold_fire_button.text == "Fire at will (all bows)", "then offers Fire at will for them all")
		screen._on_hold_fire()
		check(bows.all(func(bw): return not bw.hold_fire), "which looses them all again")
	# The pause card prints what a retreat costs.
	screen._set_paused(true)
	var cost: int = screen.sim.withdraw_cost(Sim.PLAYER)
	check(screen.retreat_button.text == ("Retreat: lose %d men" % cost if cost > 0 else "Retreat") and screen.retreat_button.visible,
		"the Retreat button says what pulling out costs (%s)" % screen.retreat_button.text)
	screen._on_retreat()
	check(screen.retreat_button.text.begins_with("Tap again") and screen.sim.winner == -1, "the first tap only arms it")
	screen._set_paused(false)
	# Escape (and the phone's back button) pause and resume.
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	screen._unhandled_input(esc)
	check(screen.paused and screen.pause_panel.visible, "Escape pauses the battle")
	screen._unhandled_input(esc)
	check(not screen.paused and not screen.pause_panel.visible, "and again closes the pause card")
	var before: float = screen.sim.time
	screen.cam_center = Vector2(400, 650)
	screen.cam_zoom = 1.25
	screen._apply_camera()
	var center: Vector2 = screen.cam_center
	var zoom: float = screen.cam_zoom
	screen._pressing = true
	screen._update_camera(0.1)
	check(screen.cam_center == center and screen.cam_zoom == zoom, "camera remains fixed during formation gesture")
	screen._pressing = false
	screen._toggle_camera()
	screen._update_camera(0.1)
	check(screen.cam_center == center and screen.cam_zoom == zoom, "Hold view prevents automatic reframing")
	screen._recenter_camera()
	check(not screen._camera_hold and screen.sim.time == before, "re-center changes view without advancing simulation")
	screen._camera_grace = 0.85
	center = screen.cam_center
	zoom = screen.cam_zoom
	screen._update_camera(0.1)
	check(screen.cam_center == center and screen.cam_zoom == zoom, "gesture release gets a camera grace period")
	var ground = load("res://scripts/battle/terrain.gd").new()
	ground.reset()
	for row in ground.ROWS: ground.water[row * ground.COLS + 10] = ground.WATER_DEEP
	ground.bake()
	screen.sim.terrain = ground
	var squad = screen.sim.squads[0]
	squad.center = Vector2(600, 900)
	screen._select(squad)
	var previous: String = squad.order
	screen._press_at = screen._to_screen(Vector2(60, 620))
	screen._tap_battle(Vector2(60, 620), null)
	check(squad.order == previous and screen.hint_label.text.contains("no route"), "unreachable move is explained without replacing the current order")
	ground.reset()
	ground.bake()
	screen.sim.terrain = ground
	screen._tap_battle(Vector2(60, 620), null)
	check(squad.order == previous and not screen._pending_march.is_empty(), "a tap on open ground puts down a march ring and waits for a second")
	screen._press_at = screen._to_screen(Vector2(780, 640))
	screen._tap_battle(Vector2(780, 640), null)
	check(squad.order == previous and screen._pending_march["at"] == Vector2(780, 640), "a tap somewhere else only moves the ring")
	screen._tap_battle(Vector2(780, 640), null)
	check(squad.order == "move" and screen._pending_march.is_empty() and screen._ordered_at.has(squad) and not screen.floaters.any(func(f): return f["text"] == "MOVE"),
		"the second tap on the ring marches them, with a destination ring and no floating word")
	_check_carry_and_slow(screen)
	var first: Dictionary = gs.army[0]
	var second: Dictionary = gs.army[1]
	var a: Dictionary = first["captain"]
	var b: Dictionary = second["captain"]
	var key := "%d|%d" % [mini(int(a["id"]), int(b["id"])), maxi(int(a["id"]), int(b["id"]))]
	var battle_result := {"won": true, "reason": "rout", "lost": 3, "killed": 24,
		"bonds": {key: 55.0}, "squads": {
			int(first["id"]): {"men": int(first["men"]) - 2, "kills": 20,
				"captain": {"fate": "wounded", "kills": 4, "roll": 52, "needed": 45, "words": "Hold."}},
			int(second["id"]): {"men": int(second["men"]) - 1, "kills": 4,
				"captain": {"fate": "standing", "kills": 1, "roll": 0, "needed": 0}},
		}}
	var report: Dictionary = gs.battle_report(battle_result)
	check(report["story"].contains(first["name"]) and report["squads"][0]["training_ready"], "battle report names the leading company and exposes earned training")
	check(report["captains"][0]["fate"] == "wounded" and report["bonds"][0]["rank_up"], "battle report preserves captain fate and new bond rank")
	gs.pending_battle = {"objective": "chief", "chief_name": "Test Chief", "name": "Test band"}
	var chief_result: Dictionary = battle_result.duplicate(true)
	chief_result["chief_killed"] = true
	var chief_report: Dictionary = gs.battle_report(chief_result)
	var ordinary: Dictionary = Economy.spoils(int(battle_result["killed"]))
	check(chief_report["rewards"]["silver"] == int(ordinary["silver"]) * 2 and chief_report["rewards"]["renown"] == int(ordinary["renown"]) + 10,
		"battle report uses the same special-objective rewards as campaign settlement")
	gs.pending_battle = {}
	gs.last_result = report
	var restored := State.new()
	restored.persist = false
	restored.from_dict(JSON.parse_string(JSON.stringify(gs.to_dict())))
	check(restored.last_result["story"] == report["story"] and restored.last_result["squads"].size() == report["squads"].size(),
		"structured last-battle account survives a save round trip")
	restored.free()
	screen._rebuild_result(report, "Their army broke and fled.")
	check(screen.result_content.get_child_count() >= 6 and screen.result_body.text.contains("broke"), "result screen builds a structured, scrollable account")
	var first_row = screen.result_content.find_child("Company_%d" % int(first["id"]), true, false)
	check(first_row != null and first_row.get_index() < screen.result_content.find_child("Company_%d" % int(second["id"]), true, false).get_index(),
		"companies that fought are listed, a wounded captain's first")
	var quiet_ids: Array = gs.army.filter(func(sq): return not battle_result["squads"].has(int(sq["id"]))).map(func(sq): return int(sq["id"]))
	check(quiet_ids.all(func(id): return screen.result_content.find_child("Company_%d" % id, true, false) == null),
		"companies with nothing to report aren't listed")
	check(screen.result_content.find_child("OtherBondsToggle", true, false) == null and screen.result_content.find_child("RankUp_*", true, false) != null,
		"bonds show only the rank reached, not every pair that grew closer")
	check(not String(report["story"]).contains("held the field"), "the story doesn't repeat what the title says")
	await _check_siege_screen(gs)
	print("Battle controls failures: %d" % failures)
	quit(failures)



func _press(screen, kind: String, at: Vector2) -> void:
	if kind == "down":
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = true
		e.position = at
		screen._input(e)
		if not screen.slow_held() or not screen._slow_handle().has_point(at):
			screen._unhandled_input(e)
	elif kind == "move":
		var m := InputEventMouseMotion.new()
		m.position = at
		screen._input(m)
	else:
		var u := InputEventMouseButton.new()
		u.button_index = MOUSE_BUTTON_LEFT
		u.pressed = false
		u.position = at
		screen._input(u)


func _touch(screen, index: int, pressed: bool, at: Vector2) -> void:
	var t := InputEventScreenTouch.new()
	t.index = index
	t.pressed = pressed
	t.position = at
	screen._input(t)


## Carrying a squad by its flag onto an enemy or ground, and a thumb holding time back.
func _check_carry_and_slow(screen) -> void:
	var sim = screen.sim
	screen.paused = false
	screen._title = {}
	screen._storm_plan = {}
	var mine = null
	var foe = null
	for sq in sim.squads:
		if sq.team == Sim.PLAYER and sq.is_active() and not sq.is_ally and mine == null:
			mine = sq
		if sq.team == Sim.ENEMY and sq.is_active() and foe == null:
			foe = sq
	screen.cam_center = Vector2(420, 630)
	screen.cam_zoom = 1.0
	screen._camera_hold = true
	screen._apply_camera()
	mine.center = Vector2(420, 760)
	foe.center = Vector2(420, 520)
	for i in mine.soldiers.size():
		mine.soldiers[i].pos = mine.center + Vector2(float(i % 5) * 8.0, float(i / 5) * 8.0)
	for i in foe.soldiers.size():
		foe.soldiers[i].pos = foe.center + Vector2(float(i % 5) * 8.0, float(i / 5) * 8.0)
	mine.avg = mine.center
	foe.avg = foe.center
	var flag: Vector2 = screen._to_screen(mine.center) + Vector2(0, -60)
	var foe_flag: Vector2 = screen._to_screen(foe.center) + Vector2(0, -60)
	screen._std_tops = {mine: flag - screen.FLAG * 0.5, foe: foe_flag - screen.FLAG * 0.5}
	screen._select(null)
	_press(screen, "down", flag)
	check(screen._press_squad == mine, "a press on your own standard picks that squad up")
	_press(screen, "move", foe_flag + Vector2(4, 4))
	check(screen._drawing and screen._drop_target(mine, foe_flag)["foe"] == foe, "carried over an enemy standard, the squad would go for it")
	_press(screen, "up", foe_flag + Vector2(4, 4))
	check(mine.order == "attack" and mine.order_target == foe and screen.selected_squad == mine, "letting go over an enemy orders the attack and selects the squad")
	var m: Array = screen._matchup(Troops.SPEARMEN, Troops.CAVALRY)
	var bad: Array = screen._matchup(Troops.CAVALRY, Troops.SPEARMEN)
	check(m[0] == "▲" and bad[0] == "▼" and screen._matchup(Troops.INFANTRY, Troops.INFANTRY)[0] == "·", "the matchup reads which side has the edge")
	screen._std_tops = {mine: flag - screen.FLAG * 0.5, foe: foe_flag - screen.FLAG * 0.5}
	var ground: Vector2 = screen._to_screen(Vector2(250, 700))
	_press(screen, "down", flag)
	_press(screen, "move", ground)
	_press(screen, "up", ground)
	check(mine.order == "move" and mine.order_point.distance_to(Vector2(250, 700)) < 40.0, "letting go over open ground marches the squad there")
	screen._std_tops = {mine: flag - screen.FLAG * 0.5, foe: foe_flag - screen.FLAG * 0.5}
	screen._select(null)
	var open_a: Vector2 = screen._to_screen(Vector2(200, 900))
	var open_b: Vector2 = screen._to_screen(Vector2(600, 900))
	screen._line_shown = {}
	_press(screen, "down", open_a)
	check(screen._press_squad == null, "a press on open ground does not pick a squad up")
	_press(screen, "move", open_b)
	_press(screen, "up", open_b)
	check(screen._line_shown.is_empty() and not screen._pending_line.is_empty(),
		"a line drawn with nothing selected waits on the field for a tap, so a stray swipe moves no one")
	var on_line: Vector2 = (open_a + open_b) * 0.5
	_press(screen, "down", on_line)
	_press(screen, "up", on_line)
	check(not screen._line_shown.is_empty() and screen._pending_line.is_empty(), "a tap on it forms the whole army there")
	_press(screen, "down", open_a)
	_press(screen, "move", open_b)
	_press(screen, "up", open_b)
	_press(screen, "down", screen._to_screen(Vector2(420, 640)))
	_press(screen, "up", screen._to_screen(Vector2(420, 640)))
	check(screen._pending_line.is_empty() and screen.hint_label.text.begins_with("Line dropped"), "a tap anywhere else drops it")
	# Slow time: the handle on the field's edge.
	var handle: Rect2 = screen._slow_handle()
	check(handle.size.x > 40.0 and screen._view.encloses(handle), "the slow handle sits on the field's edge in battle")
	var t0: float = sim.time
	screen.speed = 1.0
	for i in 10: screen._process(0.05)
	var normal: float = sim.time - t0
	_press(screen, "down", handle.get_center())
	check(screen.slow_held() and not screen._pressing, "holding the handle slows time without pressing the field")
	screen._refresh_hud()
	check(screen.speed_button.text == "¼×", "the speed button reads a quarter while held")
	screen.speed = 2.0
	t0 = sim.time
	for i in 10: screen._process(0.05)
	var slowed: float = sim.time - t0
	check(slowed > normal * 0.1 and slowed < normal * 0.4, "held, the fight runs at a quarter pace even at 2× (%.2f vs %.2f)" % [slowed, normal])
	screen._std_tops = {mine: flag - screen.FLAG * 0.5, foe: foe_flag - screen.FLAG * 0.5}
	screen._select(mine)
	sim.order_hold(mine)
	_touch(screen, 1, true, foe_flag)
	_touch(screen, 1, false, foe_flag)
	check(mine.order == "attack" and mine.order_target == foe, "a second finger's tap gives orders while the thumb holds")
	_press(screen, "up", handle.get_center())
	check(not screen.slow_held(), "letting go of the handle runs time on")
	_touch(screen, 0, true, handle.get_center())
	check(screen.slow_held(), "a touch on the handle holds time too")
	screen._set_paused(true)
	screen._set_paused(false)
	check(not screen.slow_held(), "pausing lets go of the handle")
	# Paused, the field still takes orders.
	screen._std_tops = {mine: flag - screen.FLAG * 0.5, foe: foe_flag - screen.FLAG * 0.5}
	sim.order_hold(mine)
	screen._set_paused(true)
	screen._select(mine)
	_press(screen, "down", foe_flag)
	_press(screen, "up", foe_flag)
	check(screen.paused and mine.order == "attack" and mine.order_target == foe, "paused, a tap on an enemy still orders the attack")
	screen._set_paused(false)
	# Two fingers pinch the view; the wheel zooms it; either holds the camera until Re-center.
	screen._select(null)
	screen._recenter_camera()
	var z0: float = screen.cam_zoom
	var mid: Vector2 = screen._view.get_center()
	_touch(screen, 0, true, mid - Vector2(60, 0))
	_touch(screen, 1, true, mid + Vector2(60, 0))
	check(not screen._pinch.is_empty() and not screen._pressing, "a second finger on the field starts a pinch, not an order")
	var spread := InputEventScreenDrag.new()
	spread.index = 1
	spread.position = mid + Vector2(180, 0)
	screen._input(spread)
	check(screen.cam_zoom > z0 and screen._camera_hold and screen.camera_button.text == "Held", "spreading the fingers zooms in and holds the camera")
	_touch(screen, 1, false, mid + Vector2(180, 0))
	_touch(screen, 0, false, mid - Vector2(60, 0))
	check(screen._touches.is_empty() and screen._pinch.is_empty() and not screen._pinch_lock, "lifting both fingers ends the pinch")
	screen._recenter_camera()
	check(not screen._camera_hold and screen.camera_button.text == "Following", "Re-center hands the camera back to the fight")
	var z1: float = screen.cam_zoom
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.factor = 1.0
	wheel.position = mid
	screen._unhandled_input(wheel)
	check(screen.cam_zoom > z1 and screen._camera_hold, "the mouse wheel zooms the field too")
	screen._recenter_camera()
	screen.speed = 1.0
	screen._camera_hold = false


## Storming a castle: the objective line, the two-tap storm plan, the breach and the
## siege's own result.
func _check_siege_screen(gs) -> void:
	gs.new_campaign(Cultures.VARDISH)
	var w = gs.world
	var target := ""
	var employer := ""
	for id in WorldData.SETTLEMENTS:
		if String(WorldData.settlement(id)["type"]) != WorldData.CASTLE:
			continue
		for r in ["vardmark", "kharzan", "ryumon"]:
			if r != w.owner_of(id) and w.at_war(r, w.owner_of(id)):
				target = id
				employer = r
		if target != "":
			break
	if target == "":
		for id in WorldData.SETTLEMENTS:
			if String(WorldData.settlement(id)["type"]) == WorldData.CASTLE and w.owner_of(id) != "vardmark":
				target = id
				employer = "vardmark"
				w.declare_war(employer, w.owner_of(id), true)
				break
	gs.contract = {"realm": employer, "daily_pay": 50, "days_left": 30, "bonus_per_lord": 100}
	var p = w.player()
	p.node = target
	p.next = ""
	p.path = []
	gs.start_siege_battle(target)
	change_scene_to_file("res://scenes/battle.tscn")
	await process_frame
	await process_frame
	var screen = current_scene
	screen.set_process(false)
	var sim = screen.sim
	check(sim.objective == Sim.OBJECTIVE_SIEGE, "a castle assault opens as a siege")
	screen._refresh_hud()
	check(screen.objective_chip.visible and screen.objective_label.text.begins_with("Take the walls"), "the objective line says to take the walls")
	check(screen.fight_button.icon != null and screen.auto_button.icon != null, "deploy buttons carry icons")
	screen._on_auto()
	screen._start_battle()
	screen._refresh_hud()
	check(screen.advance_button.icon != null and screen.hold_button.icon != null and screen.storm_button.visible, "the assault's order bar has icons and Storm")
	screen._on_storm()
	screen._refresh_hud()
	check(not screen._storm_plan.is_empty() and screen.storm_go_button.visible and not screen.advance_button.visible,
		"the first tap on Storm shows the plan and asks for a second")
	var t0: float = sim.time
	screen._process(0.5)
	check(sim.time == t0, "the battle waits while the storm plan is up")
	var foot = null
	var index := -1
	for i in screen._cards.size():
		var sq = sim.placed_squad(Sim.PLAYER, screen._cards[i]["roster_id"])
		if sq != null and sim.can_climb(sq):
			foot = sq
			index = i
			break
	var was: String = screen._storm_plan[foot.id]
	screen._on_chip(index)
	check(screen._storm_plan[foot.id] != was and ["ladder", "ram"].has(screen._storm_plan[foot.id]), "tapping a card on the plan swaps ladder and ram")
	var ladder: bool = screen._storm_plan[foot.id] == "ladder"
	screen._on_storm_go()
	check(screen._storm_plan.is_empty() and foot.use_ladders == ladder and foot.order == "advance", "Storm! gives the order as planned")
	sim.events.append({"type": "gate_breached"})
	screen._consume_events()
	check(not screen._banner.is_empty() and not screen.ticker.any(func(t): return t.get("icon", "") == "breach"),
		"the breach gets its banner, and no ticker line saying it again")
	sim.gate_hp = 0.0
	screen._refresh_hud()
	check(screen.storm_button.disabled and screen.objective_label.text == "Rout the garrison", "after the breach Storm greys out and the objective moves on")
	sim.winner = Sim.PLAYER
	var report: Dictionary = gs.battle_report(screen._result())
	screen._rebuild_result(report, "The garrison broke.")
	var vignette = screen.result_content.find_child("SiegeVignette", true, false)
	check(vignette != null, "a siege result shows the castle with its fate")
	var names := []
	for c in screen.result_content.get_children():
		if c is Label:
			names.append(c.text)
	check(names.has("HOW IT WENT"), "and how the siege went, moment by moment")
