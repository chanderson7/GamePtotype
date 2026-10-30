extends SceneTree
const Cultures = preload("res://scripts/data/cultures.gd")
const State = preload("res://scripts/game_state.gd")
const Economy = preload("res://scripts/data/economy.gd")
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
	print("Battle controls failures: %d" % failures)
	quit(failures)
