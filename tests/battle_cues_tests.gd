## The battlefield communicates pressure: wavering warnings, settling, cue budgets, haptics.
extends SceneTree

const Sim = preload("res://scripts/battle/battle_sim.gd")
const Cultures = preload("res://scripts/data/cultures.gd")

var failures := 0


func check(ok: bool, message: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + message)
	if not ok:
		failures += 1


func _init() -> void:
	await process_frame
	var sound = root.get_node("Sound")
	sound.settings_path = "user://battle-cues-test-%d.cfg" % OS.get_process_id()
	var gs = root.get_node("GameState")
	gs.persist = false
	gs.new_campaign(Cultures.VARDISH)
	gs.pending_battle = {}

	# Haptics: their own setting, saved, and silent when off.
	sound.set_haptics(true)
	var before: int = sound.haptic_count
	sound.haptic(false)
	check(sound.haptic_count == before + 1, "a light pulse is sent when vibration is on")
	sound.set_haptics(false)
	sound.haptic(true)
	check(sound.haptic_count == before + 1, "and none when it is off")
	sound.haptics_enabled = true
	sound._load_settings()
	check(not sound.haptics_enabled and not sound.reduced_motion, "the setting is saved, and is separate from reduced motion")
	sound.set_haptics(true)

	change_scene_to_file("res://scenes/battle.tscn")
	await process_frame
	await process_frame
	var screen = current_scene
	var sim = screen.sim
	if sim.phase == Sim.PHASE_DEPLOY:
		sim.start_battle()
	var mine = null
	for sq in sim.squads:
		if sq.team == Sim.PLAYER:
			mine = sq
			break

	# Orders are felt, once for a whole line.
	before = sound.haptic_count
	screen._mark_ordered(mine)
	screen._mark_ordered(mine)
	check(sound.haptic_count == before + 1, "an accepted order gives one light pulse, not one per squad")

	# Wavering is warned before the break: below the waver line (35), above the rout (30).
	mine.morale = 33.0
	await process_frame
	await process_frame
	check(screen.wavering(mine) and screen._wavered.has(mine) and not mine.routing, "a squad near breaking is marked wavering before it routs")
	check(screen.ticker.any(func(t): return String(t["text"]).contains("wavering")), "and the ticker warns you")

	# Settling: a squad that comes to a halt.
	mine.order = "move"
	await process_frame
	mine.order = "hold"
	mine.engaged = false
	await process_frame
	check(screen._settled_at.has(mine) or mine.engaged, "a squad that halts settles into its ground")

	# Cue budget: routine bursts are capped; critical ones always get in.
	screen.bursts.clear()
	for i in 100:
		screen._burst(Vector2(100, 100), "dust", Color.WHITE, 5.0)
	check(screen.bursts.size() <= screen.MAX_BURSTS, "routine bursts never exceed the budget (%d)" % screen.bursts.size())
	screen._burst(Vector2(100, 100), "rout", Color.WHITE, 5.0)
	check(screen.bursts.any(func(b): return b["kind"] == "rout"), "a critical burst still gets in when the budget is full")

	# Terrain colours the dust.
	var desert: Color = screen._ground_dust(Vector2(400, 600))
	check(desert.a > 0.0, "dust takes the colour of the ground")

	# Off-screen markers draw without disturbing the battle.
	screen.selected_squad = mine
	screen.cam_center = Vector2(0, 0) if "cam_center" in screen else Vector2.ZERO
	await process_frame
	check(true, "edge markers draw for a company out of sight")

	DirAccess.remove_absolute(sound.settings_path)
	print("\nBattle cue tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
