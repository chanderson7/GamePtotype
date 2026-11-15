## Fewer frames while nothing happens: after a while without a touch, a screen that isn't
## moving by itself is drawn at 30 frames a second; a touch, or a screen that's moving (the
## battle fought, the map while time runs), keeps the full pace.
extends SceneTree

const Pacer = preload("res://scripts/ui/frame_pacer.gd")

var failures := 0


func check(ok: bool, message: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + message)
	if not ok:
		failures += 1


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var scenes = root.get_node("Scenes")
	check(scenes.pacer != null and not scenes.pacer._enabled and Engine.max_fps == 0,
		"with no screen (headless) the pacer leaves the frame rate alone")
	var gs = root.get_node("GameState")
	gs.persist = false
	gs.new_campaign("vardish")
	var pacer = Pacer.new()
	root.add_child(pacer)
	pacer._enabled = true
	change_scene_to_file("res://scenes/settings.tscn")
	for i in 4:
		await process_frame
	pacer._last_input_ms = Time.get_ticks_msec() - 3000
	pacer._process(0.0)
	check(pacer.idle and Engine.max_fps == Pacer.IDLE_FPS, "a page left alone is drawn at %d frames a second" % Pacer.IDLE_FPS)
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	pacer._input(touch)
	check(not pacer.idle and Engine.max_fps == 0, "a touch brings the full pace back at once")
	pacer._process(0.0)
	check(not pacer.idle, "and keeps it for a while after")
	# The map: full pace while time runs, fewer frames while it stands still.
	change_scene_to_file("res://scenes/world_map.tscn")
	for i in 8:
		await process_frame
	var map = current_scene
	map.set_process(false)
	pacer._last_input_ms = Time.get_ticks_msec() - 3000
	gs.world.wait(6.0)
	map.paused = false
	pacer._process(0.0)
	check(map.keeps_full_pace() and not pacer.idle, "the map keeps the full pace while time runs")
	gs.world.player().wait = 0.0
	map.paused = true
	pacer._process(0.0)
	check(not map.keeps_full_pace() and pacer.idle, "and spares frames while it stands still")
	# The battle: full pace while it's fought; paused, it may rest.
	var w = gs.world
	w.encounter = w.bands()[0].id
	gs.start_encounter_battle()
	change_scene_to_file("res://scenes/battle.tscn")
	for i in 4:
		await process_frame
	var battle = current_scene
	battle.set_process(false)
	battle._on_auto()
	battle._start_battle()
	battle._title = {}
	pacer._process(0.0)
	check(battle.keeps_full_pace() and not pacer.idle, "a battle being fought keeps the full pace")
	battle._set_paused(true)
	pacer._process(0.0)
	check(not battle.keeps_full_pace() and pacer.idle, "a paused battle may rest")
	pacer._set_idle(false)
	pacer.queue_free()
	gs.pending_battle = {}
	gs.battle_resume = {}
	print("Frame pacer failures: %d" % failures)
	quit(1 if failures > 0 else 0)
