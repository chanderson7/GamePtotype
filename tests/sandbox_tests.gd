## The sandbox (scripts/menu/sandbox.gd): its setup as data, the tray, placing and taking
## away, the remembered setup, and the battle it starts.
##   godot --headless --path . --script res://tests/sandbox_tests.gd
extends SceneTree

var failures := 0
var gs
var scenes


func check(ok: bool, message: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + message)
	if not ok:
		failures += 1


func _arrive(file: String) -> void:
	for i in 400:
		await process_frame
		if current_scene != null and current_scene.scene_file_path.ends_with(file) and current_scene.is_node_ready() and not scenes._busy:
			break
	for i in 3:
		await process_frame


func _init() -> void:
	await process_frame
	gs = root.get_node("GameState")
	scenes = root.get_node("Scenes")
	gs.persist = false
	var SB = load("res://scripts/menu/sandbox.gd")
	var Units = load("res://scripts/data/units.gd")
	var Sim = load("res://scripts/battle/battle_sim.gd")
	if FileAccess.file_exists(SB.SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SB.SAVE))

	# Every troop in the game is in the tray, once.
	var seen := {}
	for land in ["vardish", "kharzani", "ryumon"]:
		var of_land: Array = SB.units_of(land)
		check(of_land.size() == 12, "%s has twelve troops in the tray (%d)" % [land, of_land.size()])
		for id in of_land:
			seen[id] = true
	check(seen.size() == Units.UNITS.size(), "the tray holds every troop in the game (%d of %d)" % [seen.size(), Units.UNITS.size()])

	# Home has the way in.
	change_scene_to_file("res://scenes/title.tscn")
	await _arrive("title.tscn")
	check(current_scene.find_child("Sandbox", true, false) is Button, "Home has a Sandbox button")

	SB.setup = SB.default_setup()
	change_scene_to_file("res://scenes/sandbox.tscn")
	await _arrive("sandbox.tscn")
	var sc = current_scene
	check(sc.step == 0 and sc.find_child("Site", true, false) != null and sc.find_child("Side", true, false) == null,
		"it opens on the fight's options; attack or defend is asked only at a wall")
	sc.setup["site"] = "castle"
	sc._build()
	await process_frame
	check(sc.find_child("Side", true, false) != null and sc.find_child("Attack", true, false) != null and sc.find_child("Defense", true, false) != null,
		"a siege asks your side of the wall and each side's engines")
	check(sc.find_child("Temper", true, false) != null and sc.find_child("Hour", true, false) != null and sc.find_child("Pace", true, false) != null,
		"and every fight asks the hour, the battle's speed and their commander")
	sc.setup["pace"] = 0.35

	# Step 1: the enemy.
	sc._go(1)
	await process_frame
	await process_frame
	var next := sc.find_child("Next", true, false) as Button
	check(sc.step == 1 and next.disabled, "then the enemy is placed; Confirm waits for at least one company")
	var zone: Rect2 = sc._zones[Sim.ENEMY]
	check(not sc.add_company("ryumon_infantry", Vector2(420, 1100)) and sc.setup["enemy"].is_empty(), "a company dropped outside their ground is not placed")
	check(sc.add_company("ryumon_infantry", zone.get_center()) and sc.setup["enemy"].size() == 1 and not next.disabled, "one dropped on it is, and Confirm wakes")
	for i in 9:
		sc.add_company("ryumon_archers", zone.get_center() + Vector2(i * 10.0, 0))
	check(sc.setup["enemy"].size() == SB.CAP, "a side holds %d companies and no more" % SB.CAP)
	# Picked up and let go off the field: gone.
	sc.carry = {"index": 0}
	var away := InputEventMouseButton.new()
	away.button_index = MOUSE_BUTTON_LEFT
	away.pressed = false
	away.position = sc.field.global_position + Vector2(-50, -50)
	sc._input(away)
	check(sc.setup["enemy"].size() == SB.CAP - 1, "a company dragged off the field is taken away")
	(sc.find_child("Reset", true, false) as Button).pressed.emit()
	check(sc.setup["enemy"].is_empty(), "Reset clears the side being placed")
	sc.add_company("ryumon_infantry", zone.get_center())
	sc.add_company("ryumon_yumi_samurai", zone.get_center() + Vector2(-200, 0))

	# Step 2: your own.
	sc._go(2)
	await process_frame
	await process_frame
	var mine_zone: Rect2 = sc._zones[Sim.PLAYER]
	sc.add_company("vardish_infantry", mine_zone.get_center())
	sc.add_company("vardish_longbowmen", mine_zone.get_center() + Vector2(0, 120))
	(sc.find_child("Reset", true, false) as Button).pressed.emit()
	check(sc.setup["mine"].is_empty() and sc.setup["enemy"].size() == 2, "Reset on your side leaves the enemy where they stand")
	sc.add_company("vardish_infantry", mine_zone.get_center())
	sc.add_company("vardish_longbowmen", mine_zone.get_center() + Vector2(0, 120))

	# The battle it describes.
	var p: Dictionary = SB.pending(sc.setup)
	check(p["sandbox"] and p["objective"] == Sim.OBJECTIVE_SIEGE and p["siege_kind"] == "castle" and not p["siege_defend"]
		and p["army"].size() == 2 and p["enemy"].size() == 2 and p["places"].size() == 4, "the setup becomes a battle: both hosts, where each stands, the wall and its engines")
	check(String(p["army"][1]["unit"]) == "vardish_longbowmen" and int(p["army"][1]["men"]) == Units.full_size("vardish_longbowmen"), "each company at full strength, as the troop it is")

	check(is_equal_approx(float(p["pace"]), 0.35), "the battle's speed goes with it")

	# Remembered.
	SB.save_setup(sc.setup)
	var back: Dictionary = SB.load_setup()
	check(is_equal_approx(float(back["pace"]), 0.35), "and so is the battle's speed")
	check(back["site"] == "castle" and back["enemy"].size() == 2 and back["mine"].size() == 2 and String(back["mine"][1]["unit"]) == "vardish_longbowmen",
		"the last setup is remembered")

	# Fought: both sides stand where they were dropped, it starts at once, and it ends in
	# the sandbox's own result, with no campaign touched.
	var had_campaign: bool = gs.has_campaign()
	(sc.find_child("Next", true, false) as Button).pressed.emit()
	await _arrive("battle.tscn")
	var screen = current_scene
	check(screen._sandbox and screen.sim.phase == Sim.PHASE_BATTLE, "Start battle begins the fight at once")
	check(is_equal_approx(screen._battle_pace, 0.35), "at the speed chosen (%.2f)" % screen._battle_pace)
	var foot = screen.sim.placed_squad(Sim.PLAYER, 9000)
	check(foot != null and foot.center.distance_to(mine_zone.get_center()) < 90.0, "your company stands where you dropped it")
	check(screen.sim.placed_squad(Sim.ENEMY, 9100) != null and screen.sim.placed_squad(Sim.ENEMY, 9101) != null, "and so do theirs")
	check(not screen._keeps_battle() and gs.battle_resume.is_empty(), "nothing is kept to come back to")
	screen.sim.winner = Sim.PLAYER
	screen._show_result()
	await process_frame
	check(screen.find_child("SandboxResult", true, false) != null and screen.find_child("FightAgain", true, false) != null
		and screen.find_child("EditSetup", true, false) != null and screen.find_child("SandboxHome", true, false) != null,
		"the result offers Fight again, Edit setup and Home")
	(screen.find_child("EditSetup", true, false) as Button).pressed.emit()
	await _arrive("sandbox.tscn")
	check(current_scene.step == 1 and current_scene.setup["enemy"].size() == 2 and gs.pending_battle.is_empty() and gs.has_campaign() == had_campaign,
		"Edit setup comes back to the enemy's step with everything in place, and no campaign was made or changed")

	# A field battle with you defending nothing: no wall questions asked of the sim.
	var open: Dictionary = SB.default_setup()
	open["site"] = "woods"
	open["enemy"] = [{"unit": "kharzani_horse_archers", "x": 420.0, "y": 200.0}]
	open["mine"] = [{"unit": "vardish_pikemen", "x": 420.0, "y": 1000.0}]
	var q: Dictionary = SB.pending(open)
	check(q["objective"] == Sim.OBJECTIVE_ROUT and not q.has("siege_kind") and String(q["site"]["type"]) == "woods", "a field is fought as a field, on the ground chosen")

	if FileAccess.file_exists(SB.SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SB.SAVE))
	print("Sandbox failures: %d" % failures)
	quit(1 if failures > 0 else 0)
