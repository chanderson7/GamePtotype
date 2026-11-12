## The music: every piece is there, the battle's layers are the same length so they stay
## in step, and the battle moves from deployment to the full music to the results.
extends SceneTree

const MUSIC := "res://assets/audio/music/%s.ogg"
const REALMS := ["vardish", "kharzani", "ryumon", "siege"]

var failures := 0


func check(ok: bool, message: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + message)
	if not ok:
		failures += 1


func _length(name: String) -> float:
	var s := AudioStreamOggVorbis.load_from_file(MUSIC % name)
	return s.get_length() if s != null else -1.0


func _wait(frames: int) -> void:
	for i in frames:
		await process_frame


func _init() -> void:
	await process_frame
	var gs = root.get_node("GameState")
	gs.persist = false
	var sound = root.get_node("Sound")

	# ---- the pieces
	var names := ["title", "victory", "defeat", "rest_victory", "rest_defeat", "turn_win", "turn_lose",
		"vardish", "kharzani", "ryumon", "camp_vardish", "camp_kharzani", "camp_ryumon",
		"feast_vardish", "feast_kharzani", "feast_ryumon"]
	for r in REALMS:
		names.append_array(["deploy_" + r, "base_" + r, "high_" + r])
	var missing := names.filter(func(n): return not FileAccess.file_exists(MUSIC % n))
	check(missing.is_empty(), "every piece of music is there" + ("" if missing.is_empty() else ": missing " + str(missing)))
	var battle_len := _length("base_vardish")
	var layers := ["turn_win", "turn_lose"]
	for r in REALMS:
		layers.append_array(["base_" + r, "high_" + r])
	var uneven := layers.filter(func(n): return absf(_length(n) - battle_len) > 0.02)
	check(battle_len > 60.0 and uneven.is_empty(), "the battle's layers all run %.1f s, so they stay in step" % battle_len)
	check(absf(fmod(battle_len, sound.BATTLE_BAR)) < 0.02 or absf(fmod(battle_len, sound.BATTLE_BAR) - sound.BATTLE_BAR) < 0.02,
		"and a whole number of bars")
	check(_length("deploy_siege") > 20.0 and _length("title") > 60.0, "deployment and Home pieces are full length")
	var short := ["vardish", "kharzani", "ryumon"].filter(func(n): return _length(n) < 120.0)
	check(short.is_empty(), "each land's theme runs over two minutes before it comes round again" + ("" if short.is_empty() else ": " + str(short)))
	check(["feast_vardish", "feast_kharzani", "feast_ryumon"].all(func(n): return _length(n) > 45.0), "and each land has its feast music")

	# ---- a battle, start to finish
	sound.play_battle("ryumon")
	check(sound._track == "deploy_ryumon", "deployment plays the enemy realm's drone")
	sound.play_battle("bandits")
	check(sound._track == "deploy_vardish", "an unknown people falls back to Vardmark's")
	sound.play_battle("siege")
	check(sound._track == "deploy_siege", "an assault on walls has its own")
	sound.battle_clash()
	await _wait(2)
	check(sound._track == "battle" and sound._layers["base"].playing and sound._layers["win"].playing,
		"Fight starts every layer together")
	sound.set_battle_balance(1.0)
	sound.set_battle_intensity(1.0)
	await create_timer(2.5).timeout
	check(sound._layers["win"].volume_db > sound._layers["lose"].volume_db + 10.0, "winning brings up the bright layer, not the dark one")
	check(sound._layers["high"].volume_db > -20.0, "and the tune swells with the fighting")
	sound.set_battle_balance(-1.0)
	await create_timer(2.5).timeout
	check(sound._layers["lose"].volume_db > sound._layers["win"].volume_db + 10.0, "breaking lines bring up the dark one")
	sound.stinger("victory")
	await create_timer(1.3).timeout
	check(sound._stinger.playing and String(sound._track) == "stinger:victory", "the stinger plays on the next half bar")
	sound._after_stinger()
	check(sound._track == "rest_victory", "then a quiet piece under the results")
	await create_timer(0.8).timeout
	check(not sound._layers["base"].playing, "and the battle layers have stopped")
	sound.play_music("vardish")
	sound._after_stinger()
	check(sound._track == "vardish", "leaving for the map first: the map's music stays")

	# ---- Home
	gs.world = null
	change_scene_to_file("res://scenes/title.tscn")
	await _wait(4)
	check(sound._track == "title", "a first visit to Home plays the Glass Sea")
	gs.new_campaign("kharzani")
	change_scene_to_file("res://scenes/title.tscn")
	await _wait(4)
	check(sound._track == "camp_kharzani" and sound._loop_name == "camp", "with a campaign: your realm's tune by the campfire")

	print("FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)
