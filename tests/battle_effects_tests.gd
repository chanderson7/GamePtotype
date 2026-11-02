## Battle effects: sparks where blows land, men falling, dust behind squads on the move,
## gear and standards left where a squad breaks, a spotlight and slowed time when their
## captain falls, and the winners cheering before the result.
extends SceneTree

const Sim = preload("res://scripts/battle/battle_sim.gd")
const Troops = preload("res://scripts/data/troops.gd")
const Heraldry = preload("res://scripts/ui/heraldry.gd")

var failures := 0


func check(ok: bool, message: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + message)
	if not ok:
		failures += 1


func _init() -> void:
	await process_frame
	var gs = root.get_node("GameState")
	gs.persist = false
	gs.new_campaign("vardish")
	var w = gs.world
	w.encounter = w.bands()[0].id
	gs.start_encounter_battle()
	change_scene_to_file("res://scenes/battle.tscn")
	await process_frame
	await process_frame
	var sc = current_scene
	var sim = sc.sim
	sc._start_battle()
	sc.paused = true
	var mine = null
	var theirs = null
	for sq in sim.squads:
		if sq.team == Sim.PLAYER and mine == null:
			mine = sq
		if sq.team == Sim.ENEMY and theirs == null:
			theirs = sq

	# ---- a blow lands
	var victim = theirs.soldiers[0]
	victim.target = mine.soldiers[0]
	victim.flash = 1.0
	sc._update_effects(0.016)
	check(sc._sparks.size() >= 6, "a blow throws sparks (%d)" % sc._sparks.size())
	var before: int = sc._sparks.size()
	sc._update_effects(0.016)
	check(sc._sparks.size() <= before, "once per blow, not every frame")
	for i in 5:
		sc._update_effects(0.1)
	check(sc._sparks.is_empty(), "and they die away")
	for i in 400:
		victim.flash = 1.0
		sc._hit_seen.clear()
		sc._update_effects(0.001)
	check(sc._sparks.size() <= sc.MAX_SPARKS, "never more than %d sparks" % sc.MAX_SPARKS)
	sc._sparks.clear()

	# ---- a man falls
	sim.corpses.append({"pos": victim.pos, "team": Sim.ENEMY, "type": Troops.INFANTRY})
	sc._update_effects(0.016)
	check(sc._falling.size() == 1, "a man who's cut down takes a moment to fall")
	sc._update_effects(sc.FALL_TIME)
	check(sc._falling.is_empty(), "then lies as a body")

	# ---- dust behind a squad on the move
	sc._sq_last_avg[mine] = mine.avg - Vector2(6, 0)
	sc._sq_speed[mine] = 60.0
	sc._puff_clock = 0.0
	sc._update_effects(0.1)
	check(sc._puffs.size() > 0, "a squad on the move kicks up dust")
	for i in 600:
		sc._puff(Vector2.ZERO, Vector2.ZERO, 1.0, 2.0, 5.0, Color.WHITE, 0.2)
	check(sc._puffs.size() <= sc.MAX_PUFFS, "and dust is capped")

	# ---- a squad breaks
	sim.events.append({"type": "rout", "squad": theirs})
	sc._consume_events()
	check(sc._fallen_flags.size() == 1, "a broken squad's standard is left lying where it fell")
	check(sc._litter.size() > 0, "with shields and spears dropped behind it")

	# ---- their captain falls
	sim.events.append({"type": "captain_down", "squad": theirs, "pos": theirs.average_pos()})
	sc._consume_events()
	check(not sc._spot.is_empty() and sc._slow > 0.0, "their captain falls: the field darkens and time slows")
	sc._update_effects(sc.SLOW_TIME + 0.5)
	check(sc._spot.is_empty() and sc._slow == 0.0, "and the moment passes")

	# ---- standards ripple (and still draw with reduced motion)
	var probe := Control.new()
	var drew := [false]
	probe.draw.connect(func():
		Heraldry.flag(probe, Vector2(10, 10), Vector2(34, 26), Color.BLUE, Color.NAVY_BLUE, true, Troops.INFANTRY, false, false, 0.0, Heraldry.EDGE, 1.2)
		Heraldry.flag(probe, Vector2(60, 10), Vector2(34, 26), Color.RED, Color.DARK_RED, false, "", false, false, 0.3)
		drew[0] = true)
	root.add_child(probe)
	await process_frame
	await process_frame
	check(drew[0], "a standard draws rippling or still")

	# ---- victory: the winners cheer before the result
	sc.paused = false
	sim.winner = Sim.PLAYER
	await process_frame
	await process_frame
	check(not sc._result_shown and sc._decided_at >= 0.0, "the battle won, the winners cheer first")
	await create_timer(sc.CHEER_TIME + 0.4).timeout
	check(sc._result_shown, "then the result comes up")

	print("FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)
