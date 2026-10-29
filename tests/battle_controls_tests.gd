extends SceneTree
const Cultures = preload("res://scripts/data/cultures.gd")
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
	print("Battle controls failures: %d" % failures)
	quit(failures)
