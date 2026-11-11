## The combat feel pass (docs/combat-feel-plan.md): men who act, impact, callout tiers, the
## hour of the fight, the start and the end, a HUD that feels it, the death roll. All of it
## is drawn only: the first check runs one seeded battle with the screen drawing it and one
## without, and they must end the same.
extends SceneTree

const Sim = preload("res://scripts/battle/battle_sim.gd")
const Commander = preload("res://scripts/battle/commander_ai.gd")
const Troops = preload("res://scripts/data/troops.gd")
const Style = preload("res://scripts/ui/style.gd")
const FieldArt = preload("res://scripts/battle/field_art.gd")
const UnitArt = preload("res://scripts/art/unit_art.gd")
const SpriteData = preload("res://scripts/art/sprite_data.gd")


## A field that is a ford wherever you stand, for the rings men leave on water.
class Ford extends "res://scripts/battle/terrain.gd":
	func water_at(_p: Vector2) -> int:
		return WATER_SHALLOW

var failures := 0


func check(ok: bool, message: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + message)
	if not ok:
		failures += 1


func _battle_scene():
	var gs = root.get_node("GameState")
	gs.new_campaign("vardish")
	var w = gs.world
	w.encounter = w.bands()[0].id
	gs.start_encounter_battle()
	change_scene_to_file("res://scenes/battle.tscn")
	await process_frame
	await process_frame
	return current_scene


func _seeded_sim(gs, enemy: Array) -> Sim:
	var s := Sim.new()
	s.setup(gs.army.duplicate(true), enemy.duplicate(true), 11)
	s.ai[Sim.ENEMY] = Commander.new(Sim.ENEMY)
	s.ai[Sim.PLAYER] = Commander.new(Sim.PLAYER)
	s.ai[Sim.ENEMY].deploy(s)
	s.ai[Sim.PLAYER].deploy(s)
	s.start_battle()
	s.order_all(Sim.PLAYER, "advance")
	return s


func _fingerprint(s: Sim) -> String:
	var parts := PackedStringArray([str(s.winner), str(snapped(s.time, 0.001)), str(s.corpses.size())])
	for sq in s.squads:
		parts.append("%d:%d:%.3f:%s" % [sq.team, sq.alive_n, sq.morale, str(sq.routing)])
		for so in sq.soldiers:
			if so.alive:
				parts.append("%.3f,%.3f" % [so.pos.x, so.pos.y])
	return "|".join(parts)


func _init() -> void:
	await process_frame
	var sound = root.get_node("Sound")
	sound.settings_path = "user://battle-feel-test-%d.cfg" % OS.get_process_id()
	sound.reduced_motion = false
	sound.shake = 1.0
	var gs = root.get_node("GameState")
	gs.persist = false
	var sc = await _battle_scene()

	# ---- 1. the boundary: the screen draws, the sim doesn't notice
	# One enemy for both (each call to enemy_army raises a fresh one).
	var enemy: Array = gs.enemy_army()
	var a := _seeded_sim(gs, enemy)
	var b := _seeded_sim(gs, enemy)
	sc.sim = a
	sc.paused = true
	sc._layout()
	for i in 900:
		if a.winner != -1:
			break
		a.step()
		sc._consume_events()
		sc._update_effects(Sim.STEP)
		if i % 6 == 0:
			sc.queue_redraw()
			await process_frame
	while b.time < a.time - 0.0001:
		b.step()
	check(_fingerprint(a) == _fingerprint(b), "the same seeded battle ends the same with the screen drawing it (t=%.1f)" % a.time)
	a.dispose()
	b.dispose()

	sc = await _battle_scene()
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

	# ---- the batch: every living man is in the one draw, with his shadow
	sc._redraw()
	await process_frame
	await process_frame
	var living := 0
	for sq in sim.squads:
		living += sq.alive_n
	check(sc._men_n == living and sc._shadow_n == living, "every living man is drawn once in the batch, with his shadow (%d of %d)" % [sc._men_n, living])
	var troop_layer = sc.find_child("TroopLayer", false, false)
	var top_layer = sc.find_child("TopLayer", false, false)
	var field_first := true
	for i in sc._field_layers.size():
		field_first = field_first and sc.get_child(i) == sc._field_layers[i] and sc._field_layers[i].show_behind_parent
	check(troop_layer != null and top_layer != null and troop_layer.get_index() == sc._field_layers.size() and top_layer.get_index() == troop_layer.get_index() + 1,
		"the men are drawn on their own layer, under the top layer and the HUD")
	check(sc._field_layers.size() == 4 and field_first,
		"the field's ground, water, props and litter are layers drawn behind the battle, under the men")
	check(int(sc.perf["frames"]) >= 0 and sc.perf.has("draw") and sc.perf.has("sim"), "the performance readout keeps its numbers")

	# ---- 2. men who act: poses are drawn, never stored
	var so = mine.soldiers[0]
	var look: Dictionary = sc._squad_look(mine)
	var at: Vector2 = so.pos
	so.swing = sc.SWING - 0.02
	var pose: Dictionary = sc._pose(so, mine, 0, look)
	check(Vector2(pose["off"]).dot(so.facing) > 0.0 and int(pose["index"]) == 2, "a man who has just struck lunges at his target on the strike frame")
	so.swing = 0.0
	so.target = theirs.soldiers[0]
	so.cooldown = sc.WINDUP * 0.5
	mine.engaged = true
	pose = sc._pose(so, mine, 0, sc._squad_look(mine))
	check(Vector2(pose["off"]).dot(so.facing) < 0.0, "and draws back before the next blow")
	mine.engaged = false
	so.cooldown = 1.0
	so.target = null
	so.flash = 1.0
	pose = sc._pose(so, mine, 0, look)
	check(Vector2(pose["off"]).dot(so.facing) < 0.0 and absf(float(pose["tilt"])) > 0.0, "a man who is hit is knocked back and turned")
	so.flash = 0.0
	sc._shove(mine, mine.avg, theirs)
	check(sc._shoved.size() > 0 and so.pos == at, "a charge shoves the men it hits, on screen only")
	sc._update_effects(sc.SHOVE_TIME + 0.05)
	check(sc._shoved.is_empty() and so.pos == at, "and they are back in their places when it's over")
	mine.routing = true
	pose = sc._pose(so, mine, 0, sc._squad_look(mine))
	check(Vector2(pose["face"]) == Vector2.DOWN, "a routing man faces the edge he runs for")
	mine.routing = false
	mine.order = "hold"
	mine.still = 99.0
	for i in 12:
		sc._update_effects(0.05)
	check(float(sc._set_k[mine]) > 0.9, "a braced squad is drawn set for the blow")

	# ---- 3. impact
	sc._stop_at = -9.0
	sc._shake = 0.0
	sc._impact(1, mine.avg, Vector2.RIGHT)
	var small: float = sc._hitstop
	sc._stop_at = -9.0
	sc._shake = 0.0
	sc._impact(14, mine.avg, Vector2.RIGHT)
	check(sc._hitstop > small and sc._hitstop <= sc.HITSTOP_MAX, "a charge that strikes more men stops the battle longer (%.2f > %.2f)" % [sc._hitstop, small])
	check(sc._shake_dir == Vector2.RIGHT and sc._punch > 0.0, "and knocks the view the way it went, punching in")
	var stop_before: float = sc._hitstop
	sc._hitstop = 0.0
	sc._impact(14, mine.avg, Vector2.RIGHT)
	check(sc._hitstop == 0.0, "charges landing together share one stop")
	sc._hitstop = 0.0
	sc._punch = 0.0
	sound.set_shake(0.0)
	sc._shake = 0.0
	sc._kick(12.0)
	check(sc._shake == 0.0, "screen shake off: a gate breaking doesn't shake")
	sound.set_shake(0.5)
	sc._kick(12.0)
	check(is_equal_approx(sc._shake, 6.0), "light: half as hard")
	sound.shake = 1.0
	sound._load_settings()
	check(is_equal_approx(sound.shake, 0.5), "the shake setting is saved")
	sound.set_shake(1.0)
	sc._shake = 0.0

	# ---- 4. callout tiers
	sc.floaters.clear()
	sc._said.clear()
	sc._hush_until = -9.0
	for i in 3:
		sc._callout(mine, "CHARGE", Style.BRASS)
	check(sc.floaters.filter(func(f): return f["sq"] == mine).size() == 1, "the same word on the same squad shows once")
	sc._callout(mine, "BRACED", Style.BRASS)
	check(sc.floaters.filter(func(f): return f["sq"] == mine).size() == 1 and sc.floaters.any(func(f): return f["text"] == "BRACED"),
		"one word per squad: a new one replaces the last")
	sc._banner = {}
	sc._moments.clear()
	sc._moment("First", "", Style.BRASS)
	sc._moment("Second", "", Style.BRASS)
	check(String(sc._banner["title"]) == "First" and sc._moments.size() == 1, "two moments queue rather than overlap")
	sc._callout(theirs, "FLANK", Style.BRASS)
	check(not sc.floaters.any(func(f): return f["sq"] == theirs), "while a moment holds the field the squads' words wait")
	sc._callout(theirs, "TARGET", Style.ENEMY_LIGHT, true)
	check(sc.floaters.any(func(f): return f["sq"] == theirs), "but the answer to your own order still shows")
	sc._process(sc.MOMENT_LIFE + 0.05)
	check(String(sc._banner.get("title", "")) == "Second", "and the next moment follows")
	sc._banner = {}
	sc._moments.clear()
	sim.events.append({"type": "rout", "squad": mine})
	sc._consume_events()
	check(String(sc._banner.get("title", "")).ends_with("break"), "your squad breaking is a moment")
	mine.routing = false
	sc._banner = {}
	sc._hush_until = -9.0
	sim.events.append({"type": "rout", "squad": theirs})
	sc._consume_events()
	check(sc._banner.is_empty() and sc.floaters.any(func(f): return f["sq"] == theirs and f["text"] == "BROKEN"), "theirs is a word over the squad")
	theirs.routing = false

	# ---- 5. the hour
	sc._set_hour(22.0)
	check(sc._band == "night" and sc._ground_tint.a > 0.3 and sc._shadow_a < 0.2 and sc._vignette > 0.5, "a battle at 22:00 is fought at night")
	var night_contrast := _contrast(sc)
	sc._set_hour(12.0)
	check(sc._band == "day" and sc._ground_tint.a == 0.0, "at noon the field is as it was")
	var day_contrast := _contrast(sc)
	check(night_contrast >= day_contrast * 0.66, "both sides' colours still stand out from the ground at night (%.2f vs %.2f by day)" % [night_contrast, day_contrast])
	sc._set_hour(18.5)
	check(sc._band == "dusk" and sc._shadow_off.x < 0.0, "at dusk the shadows fall west")
	sc._set_hour(6.0)
	check(sc._band == "dawn" and sc._shadow_off.x > 0.0, "at dawn they fall east")
	check(sc.hour_band(gs.world.hour + 24.0) == sc.hour_band(gs.world.hour), "the hour of day comes from the world clock, whatever the day")

	# ---- 6. reduced motion: no offsets, the same words
	sound.reduced_motion = true
	so.swing = sc.SWING - 0.02
	so.flash = 1.0
	pose = sc._pose(so, mine, 0, sc._squad_look(mine))
	check(Vector2(pose["off"]) == Vector2.ZERO and float(pose["tilt"]) == 0.0, "reduced motion: every man drawn where he stands")
	sc._punch = 0.0
	sc._stop_at = -9.0
	sc._impact(10, mine.avg, Vector2.UP)
	check(sc._punch == 0.0, "no punch zoom")
	sc.floaters.clear()
	sc._said.clear()
	sc._hush_until = -9.0
	sc._callout(mine, "VOLLEY", Style.BRASS)
	check(sc.floaters.size() == 1, "and every word still shows")
	sound.reduced_motion = false
	so.swing = 0.0
	so.flash = 0.0

	# ---- 6b. a stride in four, a halt that settles, rings at a ford, a warning at the edge
	var frames_ok := true
	for sprite in SpriteData.SPRITES:
		var n: int = (SpriteData.SPRITES[sprite]["frames"] as Array).size()
		if n != 1 and n != 4:
			frames_ok = false
	check(frames_ok, "every soldier's sprite has four frames: two steps, the strike, and the passing step between")
	var all_differ := true
	for troop in [Troops.INFANTRY, Troops.SPEARMEN, Troops.ARCHERS, Troops.CAVALRY]:
		var pass_img: Image = UnitArt.frame(troop, Sim.PLAYER, 3, "vardish").get_image()
		for other in 3:
			if pass_img.get_data() == UnitArt.frame(troop, Sim.PLAYER, other, "vardish").get_image().get_data():
				all_differ = false
	check(all_differ, "the passing step is its own picture for foot, spear, bow and horse")
	var was_stride: float = so.stride
	var seen := []
	mine.routing = true
	for k in 4:
		so.stride = sc.STRIDE * 0.125 * (k + 0.5)
		seen.append(int(sc._pose(so, mine, 0, sc._squad_look(mine))["index"]))
	mine.routing = false
	so.stride = was_stride
	check(seen == [0, 3, 1, 3] and sc.WALK == [0, 3, 1, 3], "a running man's stride goes step, passing, step, passing (%s)" % str(seen))
	so.target = null
	so.cooldown = 0.0
	sc._settled_at[mine] = sc._clock - sc.SETTLE_TIME * 0.5
	var settling: Dictionary = sc._squad_look(mine)
	settling["set"] = 0.0
	check(float(settling["settle"]) > 0.9, "a company that has just halted is settling onto its ground")
	check(float(sc._pose(so, mine, 0, settling)["squash"]) < 0.95, "its men dip into their stance")
	sound.reduced_motion = true
	var held: Dictionary = sc._squad_look(mine)
	held["set"] = 0.0
	check(is_equal_approx(float(sc._pose(so, mine, 0, held)["squash"]), 1.0), "but stand as they are under Reduced motion")
	sound.reduced_motion = false
	sc._settled_at[mine] = sc._clock - 2.0
	check(float(sc._squad_look(mine)["settle"]) == 0.0, "and are done with it a moment later")
	sc._settled_at.erase(mine)
	var dry = sim.terrain
	sc._wades.clear()
	for k in 40:
		sc._ripple_under(mine)
	check(sc._wades.is_empty(), "men on dry ground leave no rings")
	sim.terrain = Ford.new()
	for k in 40:
		sc._ripple_under(mine)
	check(sc._wades.size() > 5 and sc._wades.size() <= sc.MAX_RIPPLES, "men wading a ford leave rings on the water (%d)" % sc._wades.size())
	sound.reduced_motion = true
	sc._wades.clear()
	for k in 40:
		sc._ripple_under(mine)
	check(sc._wades.is_empty(), "none under Reduced motion")
	sound.reduced_motion = false
	sim.terrain = dry
	sc._wades.clear()
	var was_type: String = theirs.type
	var was_avg: Vector2 = theirs.avg
	var was_engaged: bool = theirs.engaged
	theirs.type = Troops.CAVALRY
	theirs.engaged = false
	theirs.avg = mine.avg + Vector2(120, 0)
	sc._sq_speed[theirs] = 45.0
	check(theirs.is_active() and sc._threats().has(theirs), "enemy horse at the charge near one of yours is a threat worth a warning at the edge")
	sc._sq_speed[theirs] = 5.0
	check(not sc._threats().has(theirs), "horse standing off is not")
	sc._sq_speed[theirs] = 45.0
	theirs.avg = Vector2(-9000.0, -9000.0)
	check(not sc._threats().has(theirs), "nor horse far from all of yours")
	theirs.type = was_type
	theirs.avg = was_avg
	theirs.engaged = was_engaged

	# ---- 7. the HUD feels it
	sc.paused = false
	sc._shown_men = [-1.0, -1.0]
	sc._ease_hud(0.016)
	var before_men: float = sc._shown_men[Sim.ENEMY]
	theirs.soldiers[0].alive = false
	theirs.alive_n -= 1
	sc._ease_hud(0.016)
	check(sc._shown_men[Sim.ENEMY] > float(sim.men_on_field(Sim.ENEMY)) and sc._shown_men[Sim.ENEMY] <= before_men, "men just lost linger on the strength bar as a bite")
	for i in 60:
		sc._ease_hud(0.05)
	check(is_equal_approx(sc._shown_men[Sim.ENEMY], float(sim.men_on_field(Sim.ENEMY))), "and drain away")
	sc._card_morale[mine] = 90.0
	mine.morale = 50.0
	sc._ease_hud(0.1)
	check(float(sc._card_morale[mine]) < 90.0 and float(sc._card_morale[mine]) > 50.0, "a card's morale eases down rather than jumping")
	mine.morale = 100.0
	sc._ready_was[mine] = false
	mine.ability_cd = 0.0
	sc._ease_hud(0.016)
	check(sc._ready_at.has(mine) == sim.ability_ready(mine), "an ability coming ready pulses once on its card")
	sc.paused = true
	sc._update_grade(0.5)
	check(sc._grey > 0.3 and sc._grade.visible, "pausing greys the field")
	sc.paused = false
	sc._update_grade(1.0)
	check(sc._grey == 0.0 and not sc._grade.visible, "resuming brings the colour back")

	# ---- 8. the start: a title card the battle waits for
	sc = await _battle_scene()
	sim = sc.sim
	sc._on_auto()
	sc._on_fight()
	check(sim.phase == Sim.PHASE_BATTLE and not sc._title.is_empty(), "Fight puts up the title card")
	check(String(sc._title["place"]).begins_with("Near ") and String(sc._title["odds"]).contains(" against "), "naming the place and the odds: %s · %s" % [sc._title["place"], sc._title["odds"]])
	var t0: float = sim.time
	for i in 6:
		await process_frame
	check(sim.time == t0, "the battle waits while it's up")
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	tap.position = sc._view.get_center()
	sc._unhandled_input(tap)
	check(sc._title.is_empty(), "a tap clears it")
	await create_timer(0.2).timeout
	check(sim.time > t0, "and the battle begins")
	sc._begin_title()
	await create_timer(sc.TITLE_TIME + 0.25).timeout
	check(sc._title.is_empty(), "left alone it clears in under a second")

	# ---- 9. the end: the word, then the result
	sim.winner = Sim.PLAYER
	await process_frame
	await process_frame
	check(not sc._beat.is_empty() and bool(sc._beat["won"]) and not sc._result_shown, "a win: VICTORY stamps on the field before the result")
	await create_timer(sc.CHEER_TIME + 0.4).timeout
	check(sc._result_shown and sc._beat.is_empty() == false, "then the result comes up")
	check(sc.result_content.get_node_or_null("FieldVignette") != null, "with a picture of the field")
	sc = await _battle_scene()
	sim = sc.sim
	sc._start_battle()
	sim.winner = Sim.ENEMY
	await create_timer(0.6).timeout
	check(not sc._beat.is_empty() and not bool(sc._beat["won"]) and sc._grey > 0.3 and not sc._result_shown, "a loss: DEFEAT, and the colour drains from the field")
	await create_timer(sc.DEFEAT_PAUSE).timeout
	check(sc._result_shown and not sc._grade.visible, "then the result, in colour again")

	# ---- 10. the death roll keeps its timing
	sc = await _battle_scene()
	sim = sc.sim
	sc._start_battle()
	mine = null
	for sq in sim.squads:
		if sq.team == Sim.PLAYER:
			mine = sq
			break
	sim.events.append({"type": "captain_down", "squad": mine, "pos": mine.avg, "fate": "killed", "roll": 12, "needed": 31})
	sc._consume_events()
	check(not sc._roll.is_empty() and sc._clock < sc._hush_until, "a captain down is the moment: the squads' words wait")
	for i in 4:
		await process_frame
	check(not sc._roll.is_empty(), "the death roll plays")

	# ---- 11. the cost of a frame's poses
	sc = await _battle_scene()
	sim = sc.sim
	sc._start_battle()
	var men := 0
	var t := Time.get_ticks_usec()
	for k in 20:
		for sq in sim.squads:
			var lk: Dictionary = sc._squad_look(sq)
			var i := 0
			for s2 in sq.soldiers:
				sc._pose(s2, sq, i, lk)
				i += 1
				men += 1
	var per_frame_ms := float(Time.get_ticks_usec() - t) / 1000.0 / 20.0
	check(per_frame_ms < 4.0, "posing every man on the field costs %.2f ms a frame (%d men)" % [per_frame_ms, men / 20])

	# ---- 12. a field full of the fallen still draws, in batches
	for i in Sim.MAX_CORPSES:
		var body_at := Vector2(40.0 + (i % 25) * 30.0, 300.0 + floorf(i / 25.0) * 30.0)
		sim.corpses.append({"pos": body_at, "team": i % 2, "type": Troops.CAVALRY if i % 7 == 0 else Troops.INFANTRY})
	for i in Sim.MAX_STUCK_ARROWS:
		sim.stuck_arrows.append({"pos": Vector2(60.0 + (i % 20) * 35.0, 200.0 + floorf(i / 20.0) * 20.0), "angle": i * 0.3})
	for i in sc.MAX_LITTER:
		sc._litter.append({"p": Vector2(50.0 + (i % 16) * 45.0, 900.0 + floorf(i / 16.0) * 25.0), "a": i * 0.5, "shield": i % 2 == 0, "team": i % 2})
	sc._redraw()
	await process_frame
	await process_frame
	check(sc._disc_tex != null and sc._disc_tex.get_width() == 64, "the field's discs are one texture, drawn as rects")
	var grown := true
	for g in [0, 1, 2, 3]:
		grown = grown and sc._corpse_mm.has(g) and (sc._corpse_mm[g] as MultiMesh).instance_count % sc.CORPSE_STEP == 0
	check(grown, "five hundred dead go in four batches, each with room to grow")

	# ---- 13. the slopes and the feature plate are one layer, laid as the GPU laid them
	var shade_img := Image.create_empty(2, 2, false, Image.FORMAT_RGBA8)
	shade_img.fill(Color(0.0, 0.0, 1.0, 0.5))
	var plate_img := Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)
	plate_img.set_pixel(1, 1, Color(1.0, 0.0, 0.0, 1.0))
	plate_img.set_pixel(2, 2, Color(1.0, 0.0, 0.0, 0.5))
	var ov := FieldArt.overlay_image(shade_img, plate_img)
	var bare := ov.get_pixel(0, 0)
	var half := ov.get_pixel(2, 2)
	check(ov.get_size() == Vector2i(4, 4) and absf(bare.a - 0.5) < 0.01 and bare.b > 0.99 and ov.get_pixel(1, 1).is_equal_approx(Color(1, 0, 0, 1))
		and absf(half.a - 0.75) < 0.01 and absf(half.r - 2.0 / 3.0) < 0.01,
		"the merged ground layer is the slopes doubled with the features over them")
	check(FieldArt.overlay_image(null, plate_img) == plate_img and FieldArt.overlay_image(shade_img, null) == shade_img
		and FieldArt.overlay_image(null, null) == null, "with only one of the two, the layer is that one")

	# ---- the test battle from Settings: a big fight that leaves the campaign alone
	gs.pending_battle = {}
	var army_before := JSON.stringify(gs.army)
	var next_before: int = gs._next_id
	var renown_before: int = gs.renown
	sound.show_performance = true
	change_scene_to_file("res://scenes/settings.tscn")
	await process_frame
	await process_frame
	var tb := current_scene.find_child("TestBattle", true, false) as Button
	check(tb != null, "with the readout on, Settings offers a test battle")
	tb.pressed.emit()
	for i in 600:
		await process_frame
		if current_scene != null and current_scene.get("_test") != null and current_scene.sim != null and current_scene.sim.phase == Sim.PHASE_BATTLE:
			break
	var ts = current_scene
	var mine_n := 0
	var theirs_n := 0
	if ts != null and ts.get("sim") != null:
		for sq in ts.sim.squads:
			if sq.team == Sim.PLAYER:
				mine_n += 1
			else:
				theirs_n += 1
	check(ts != null and ts.get("_test") == true and mine_n == 12 and theirs_n == 12 and ts.sim.phase == Sim.PHASE_BATTLE and ts.sim.ai[Sim.PLAYER] != null,
		"the test battle is 12 against 12, under way, the computer commanding both (%d v %d)" % [mine_n, theirs_n])
	if ts != null and ts.has_method("_back_to_camp"):
		ts.sim.winner = Sim.PLAYER
		ts._back_to_camp()
		for i in 120:
			await process_frame
	check(gs.pending_battle.is_empty() and JSON.stringify(gs.army) == army_before and gs._next_id == next_before and gs.renown == renown_before,
		"and leaving it changes nothing in the campaign")
	sound.show_performance = false

	DirAccess.remove_absolute(sound.settings_path)
	print("FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)


## How far both sides' colours stand from the ground under the screen's hour (the smaller).
func _contrast(sc) -> float:
	var ground: Color = Style.FIELD_A.blend(sc._ground_tint)
	var lum := func(c: Color) -> float: return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
	var out := 1.0
	for team_col in [Style.PLAYER, Style.ENEMY, Style.PLAYER_LIGHT, Style.ENEMY_LIGHT]:
		var c: Color = Color(team_col).blend(sc._air_tint)
		var g: Color = ground.blend(sc._air_tint)
		out = minf(out, absf(lum.call(c) - lum.call(g)) + 0.5 * Vector3(c.r - g.r, c.g - g.g, c.b - g.b).length())
	return out
