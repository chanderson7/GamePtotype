extends SceneTree
const Cultures = preload("res://scripts/data/cultures.gd")
const State = preload("res://scripts/game_state.gd")
const Economy = preload("res://scripts/data/economy.gd")
const WorldData = preload("res://scripts/world/world_data.gd")
const Sim = preload("res://scripts/battle/battle_sim.gd")
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
	check(screen.info_label.text.begins_with("Whole army") and screen.advance_button.text == "Advance all", "company orders clearly show their scope")
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
	screen._tap_battle(Vector2(60, 620), null)
	check(squad.order == previous and screen.hint_label.text.contains("no route"), "unreachable move is explained without replacing the current order")
	ground.reset()
	ground.bake()
	screen.sim.terrain = ground
	screen._tap_battle(Vector2(60, 620), null)
	check(squad.order == "move" and screen.floaters.any(func(f): return f["text"] == "MOVE"), "accepted move receives a destination marker")
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
	check(screen.result_content.get_child_count() >= 8 and screen.result_body.text.contains("broke"), "result screen builds a structured, scrollable account")
	await _check_siege_screen(gs)
	print("Battle controls failures: %d" % failures)
	quit(failures)



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
	check(not screen._banner.is_empty() and screen.ticker.any(func(t): return t.get("icon", "") == "breach"),
		"the breach gets its banner and a ticker line with an icon")
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
