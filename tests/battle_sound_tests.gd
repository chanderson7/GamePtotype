## Battle sounds: every take is there, takes never repeat back to back, sounds play where
## they happen, in their groups, never too many at once, and every moment of a battle is
## heard.
extends SceneTree

const Sim = preload("res://scripts/battle/battle_sim.gd")
const Troops = preload("res://scripts/data/troops.gd")
const SFX := "res://assets/audio/sfx/%s.ogg"

var failures := 0


func check(ok: bool, message: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + message)
	if not ok:
		failures += 1


func _init() -> void:
	await process_frame
	var sound = root.get_node("Sound")
	sound.settings_path = "user://battle-sound-test-%d.cfg" % OS.get_process_id()
	sound.sounds_on = true
	var gs = root.get_node("GameState")
	gs.persist = false
	gs.new_campaign("kharzani")
	gs.pending_battle = {}

	# ---- the files
	var missing := []
	for bank in sound.BANKS:
		for i in range(1, int(sound.BANKS[bank]) + 1):
			if not FileAccess.file_exists(SFX % ("%s_%d" % [bank, i])):
				missing.append("%s_%d" % [bank, i])
	for name in ["melee_bed", "gasp", "cav_impact", "brace", "captain_down", "quiver_empty", "gate_break", "ladders",
			"footsteps", "hooves", "crossbow", "morale_low"]:
		if not FileAccess.file_exists(SFX % name):
			missing.append(name)
	for realm in ["vardish", "kharzani", "ryumon"]:
		for which in ["start", "charge", "retreat"]:
			if not FileAccess.file_exists(SFX % ("call_%s_%s" % [which, realm])):
				missing.append("call_%s_%s" % [which, realm])
		if not FileAccess.file_exists(SFX % ("reinforce_" + realm)):
			missing.append("reinforce_" + realm)
	check(missing.is_empty(), "every battle sound and every take is there" + ("" if missing.is_empty() else ": missing " + str(missing)))

	# ---- takes
	var last := ""
	var repeats := 0
	var used := {}
	for i in 300:
		var t: String = sound.take("sword")
		if t == last:
			repeats += 1
		last = t
		used[t] = true
	check(repeats == 0 and used.size() == 12, "a clash never repeats the take just heard, and all twelve come round")
	check(sound.take("gasp") == "gasp" and sound.take("ram").begins_with("ram_"), "single sounds play as they are")

	# ---- groups, buses, limiter, distance
	check(sound.group_of("sword") == "Melee" and sound.group_of("arrows_land") == "Missiles"
		and sound.group_of("warcry") == "Voices" and sound.group_of("call_start_vardish") == "Cues",
		"each sound plays in its group")
	var sounds_bus := AudioServer.get_bus_index("Sounds")
	var has_limiter := false
	for i in AudioServer.get_bus_effect_count(sounds_bus):
		if AudioServer.get_bus_effect(sounds_bus, i) is AudioEffectHardLimiter:
			has_limiter = true
	check(has_limiter, "a limiter keeps a big moment from distorting")
	check(AudioServer.get_bus_send(AudioServer.get_bus_index("Melee")) == "Field", "melee passes through the field")
	sound.set_field_distance(1.0)
	var dull: AudioEffectLowPassFilter = AudioServer.get_bus_effect(AudioServer.get_bus_index("Field"), 0)
	check(dull.cutoff_hz < 5000.0, "seen from far off, the fighting is duller")
	sound.set_field_distance(0.0)
	check(dull.cutoff_hz > 15000.0, "and clear close in")

	# ---- placed where it happens, and capped
	sound.end_battle_sounds()
	sound.play_at("heavy", Vector2(40, 600))
	var player = null
	for q in sound._pool_2d:
		if q.playing and String(q.get_meta("family", "")) == "heavy":
			player = q
	check(player != null and player.global_position.x == 40.0, "a sound plays from where it happens on screen")
	sound.end_battle_sounds()
	for i in 8:
		sound.play_at("sword", Vector2(300 + i, 600))
	var swords: int = sound._pool_2d.filter(func(q): return q.playing and String(q.get_meta("family", "")) == "sword").size()
	check(swords == int(sound.CAPS["sword"]), "never more than %d sword clashes at once" % int(sound.CAPS["sword"]))
	sound.end_battle_sounds()

	# ---- the din of the melee
	sound.set_melee(1.0)
	await process_frame
	await process_frame
	check(sound._melee_bed.playing, "fighting brings up the din of the melee")
	sound.end_battle_sounds()
	check(not sound._melee_bed.playing, "and it stops with the battle")

	# ---- a battle: every moment heard
	change_scene_to_file("res://scenes/battle.tscn")
	await process_frame
	await process_frame
	var screen = current_scene
	var sim = screen.sim
	screen._start_battle()
	check(String(sound._last.keys().filter(func(k): return String(k).begins_with("call_start_")).front() if sound._last.keys().any(func(k): return String(k).begins_with("call_start_")) else "") == "call_start_kharzani",
		"the battle opens with your own realm's call")
	var mine = null
	var theirs = null
	for sq in sim.squads:
		if sq.team == Sim.PLAYER and mine == null:
			mine = sq
		if sq.team == Sim.ENEMY and theirs == null:
			theirs = sq
	sound.placed = {}
	mine.engaged = true
	theirs.engaged = true
	for i in 20:
		screen._clash_clock = 0.0
		screen._battle_sounds(0.1)
		sound.end_battle_sounds()
	var blows := 0
	for k in ["sword", "shield", "spear", "heavy"]:
		blows += int(sound.placed.get(k, 0))
	check(blows >= 15, "blows ring out where the lines meet (%d)" % blows)
	# A volley comes down: arrows that were in the air last frame and are gone now.
	sim.projectiles.clear()
	screen._heard = {}
	for i in 6:
		screen._heard[RefCounted.new()] = ["arrows", Vector2(200 + i, 300)]
	screen._battle_sounds(0.1)
	check(int(sound.placed.get("arrows_land", 0)) > 0, "a volley is heard landing where it falls")
	var pos: Vector2 = mine.average_pos()
	sim.events.append({"type": "braced", "squad": mine})
	sim.events.append({"type": "out_of_arrows", "squad": mine})
	sim.events.append({"type": "flanked", "squad": mine, "rear": true, "pos": pos})
	sim.events.append({"type": "captain_down", "squad": theirs, "pos": theirs.average_pos()})
	sim.events.append({"type": "rout", "squad": theirs})
	sim.events.append({"type": "charge", "squad": mine, "pos": pos, "victim": theirs})
	sim.events.append({"type": "ladders_up"})
	sim.events.append({"type": "gate_breached"})
	sim.events.append({"type": "reinforcements", "team": Sim.ENEMY, "edge": "north"})
	screen._consume_events()
	for name in ["brace", "quiver_empty", "heavy", "captain_down", "panic", "ladders", "gate_break"]:
		check(int(sound.placed.get(name, 0)) > 0, "heard: " + name)
	check(int(sound.placed.get("cav_impact", 0)) + int(sound.placed.get("warcry", 0)) > 0, "heard: the charge")
	check(sound._last.has("cheer"), "your men cheer when theirs run")
	check(sound._last.has("reinforce_vardish") or sound._last.has("reinforce_kharzani") or sound._last.has("reinforce_ryumon"),
		"their horn sounds as more of them come")
	screen.queue_free()
	await process_frame
	check(not sound._melee_bed.playing, "leaving the battle silences it")

	print("FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)
