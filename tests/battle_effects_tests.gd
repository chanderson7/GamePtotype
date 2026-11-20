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
	victim.blows += 1
	victim.blow_tier = 1
	sc._update_effects(0.016)
	check(sc._marks.size() == 1 and int(sc._marks[0]["tier"]) == 1, "a blow leaves one mark where it lands, of its kind")
	check(sc._sparks.size() >= 3, "and throws sparks (%d)" % sc._sparks.size())
	var before: int = sc._sparks.size()
	sc._update_effects(0.016)
	check(sc._sparks.size() <= before and sc._marks.size() == 1, "once per blow, not every frame")
	for i in 5:
		sc._update_effects(0.1)
	check(sc._sparks.is_empty() and sc._marks.is_empty(), "and they die away")
	# A hard blow's mark outlasts an ordinary one's, and a turned blow's is the shortest.
	check(float(sc.MARK_LIFE[2]) > float(sc.MARK_LIFE[1]) and float(sc.MARK_LIFE[1]) > float(sc.MARK_LIFE[0]),
		"a hard blow's mark stays longest, a turned one's least")
	var sound_node = root.get_node("Sound")
	var sound_was: bool = sound_node.reduced_motion
	sound_node.reduced_motion = true
	victim.blows += 1
	victim.blow_tier = 2
	sc._update_effects(0.016)
	check(sc._marks.size() == 1 and sc._sparks.is_empty(), "under Reduced motion a blow leaves its still mark and throws nothing")
	sound_node.reduced_motion = sound_was
	sc._marks.clear()
	for i in 400:
		victim.flash = 1.0
		sc._hit_seen.clear()
		sc._update_effects(0.001)
	check(sc._sparks.size() <= sc.MAX_SPARKS, "never more than %d sparks" % sc.MAX_SPARKS)
	check(sc._marks.size() <= sc.MAX_MARKS, "never more than %d marks" % sc.MAX_MARKS)
	sc._sparks.clear()
	sc._marks.clear()

	# ---- an arrow strikes: its shaft stands in him for a moment, not a blow's mark
	var shot = theirs.soldiers[1]
	shot.shot_from = shot.pos + Vector2(0, 200)
	shot.arrows_in += 1
	shot.blows += 1
	shot.blow_tier = 1
	sc._update_effects(0.016)
	check(sc._shafts.size() == 1 and sc._marks.is_empty(), "an arrow that strikes stands in the man, with no blow mark")
	var tail_back: Vector2 = Vector2(sc._shafts[0]["dir"]).rotated(shot.facing.angle() + PI * 0.5)
	check(tail_back.dot(Vector2(0, 1)) > 0.9, "its shaft points back the way it came")
	shot.arrows_in += 1
	shot.blows += 1
	shot.blow_tier = 0
	sc._update_effects(0.016)
	check(sc._shafts.size() == 2 and Vector2(sc._shafts[1]["off"]).x < -3.0, "one turned is in his shield, on his left")
	for i in 6:
		shot.arrows_in += 1
		shot.blows += 1
		sc._update_effects(0.016)
	check(sc._shafts.size() == sc.SHAFTS_PER_MAN, "no more than %d in one man" % sc.SHAFTS_PER_MAN)
	sc._update_effects(sc.SHAFT_LIFE)
	check(sc._shafts.is_empty() and sc._shaft_count.is_empty() and sc._shaft_men.is_empty(), "and they go after a moment")
	# An arrow that kills leaves its mark where it struck (there is no man to stand in).
	var killed = theirs.soldiers[3]
	killed.shot_from = killed.pos + Vector2(0, 200)
	killed.arrows_in += 1
	killed.blows += 1
	killed.alive = false
	sc._update_effects(0.016)
	check(sc._shafts.is_empty() and sc._marks.size() == 1, "an arrow that kills leaves a blow's mark instead")
	killed.alive = true
	sc._marks.clear()
	sc._sparks.clear()
	# A routed man is drawn turned to run: his shaft still points back at the bows.
	theirs.routing = true
	var runner = theirs.soldiers[4]
	runner.shot_from = runner.pos + Vector2(0, 200)
	runner.arrows_in += 1
	runner.blows += 1
	sc._update_effects(0.016)
	var run_angle: float = Vector2.UP.angle() + PI * 0.5
	check(sc._shafts.size() == 1 and Vector2(sc._shafts[0]["dir"]).rotated(run_angle).dot(Vector2(0, 1)) > 0.9,
		"a routed man's shaft points back at the bows too")
	theirs.routing = false
	sc._update_effects(sc.SHAFT_LIFE)
	victim.blows += 1
	victim.blow_tier = 1
	sc._update_effects(0.016)
	check(sc._marks.size() == 1, "a blow by hand still leaves its mark")
	sc._marks.clear()
	sc._sparks.clear()
	check(not sc.has_method("_draw_volley_shadows"), "no ovals are drawn on the ground where a volley will land")
	check(sc.STUCK_GONE > sc.STUCK_FADE and sc.STUCK_PER_PATCH >= 1, "arrows in the ground fade and go, and a patch of ground keeps only its newest")

	# ---- a bowman draws, then the string snaps straight on the loose
	var bows = null
	for sq in sim.squads:
		if sq.ranged and sq.team == Sim.PLAYER and bows == null:
			bows = sq
	if bows != null:
		var bm = bows.soldiers[0]
		var bow_look: Dictionary = sc._squad_look(bows)
		bow_look["ranged"] = true
		bm.target = theirs.soldiers[2]
		bm.pos = bm.target.pos + Vector2(0, 200)
		bm.swing = 0.0
		bm.cooldown = sc.DRAW_TIME * 0.2
		check(int(sc._pose(bm, bows, 0, bow_look)["index"]) == 2, "a bowman about to loose has the string drawn back")
		bm.cooldown = 2.0
		bm.swing = sc.SWING - 0.01
		var loose: Dictionary = sc._pose(bm, bows, 0, bow_look)
		check(int(loose["index"]) == 0 and Vector2(loose["off"]).dot(bm.facing) < -1.5, "on the loose the string snaps straight and he rocks back")
		bm.swing = 0.0
		bm.target = null
		# A volley's bows go up in a ripple along the line, left to right.
		if sim.use_ability(bows):
			var left_cd := 0.0
			var right_cd := 0.0
			var lo := INF
			var hi := -INF
			for m in bows.soldiers:
				if m.alive and m.slot.x < lo:
					lo = m.slot.x
					left_cd = m.cooldown
				if m.alive and m.slot.x > hi:
					hi = m.slot.x
					right_cd = m.cooldown
			check(right_cd - left_cd > sim.VOLLEY_RIPPLE * 0.5 and right_cd <= 0.3, "a volley ripples along the line, left to right, within a third of a second")
		else:
			check(false, "the test battle's bows can loose a volley")
	else:
		check(false, "the test battle has bows of ours")

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
	var clumps: PackedVector3Array = sc._puffs.back()["k"]
	check(clumps.size() >= 3 and clumps.size() <= 4, "a puff of dust is a few square clumps, not a soft disc")

	# ---- a squad breaks (what its men drop is a roll each: seeded, so the check is the
	# same every run)
	seed(11)
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
