## The feel-and-polish pass (docs/feel-polish-plan.md): the body typeface, the map camera
## (glides, flicks, soft edges, following the party, the road shown before you ride), the
## road autosave written off the frame, the shutter into battle, the battle's men drawn
## between sim steps, blows heard as they land, orders that sound and refusals that are
## felt, sound that follows the battle's time, warmed-up battle sounds, open-ground and
## night ambience, haptic weights, volume sliders, music that rests, and the developer's
## feel multipliers.
##     godot --headless --path . --script res://tests/feel_polish_tests.gd
extends SceneTree

const Style = preload("res://scripts/ui/style.gd")
const Sim = preload("res://scripts/battle/battle_sim.gd")
const Data = preload("res://scripts/world/world_data.gd")
const BattleScreen = preload("res://scripts/battle/battle_screen.gd")

var failures := 0
var gs
var sound
var scenes


func check(ok: bool, message: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + message)
	if not ok:
		failures += 1


func _frames(n := 4) -> void:
	for i in n:
		await process_frame


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _arrive(path: String) -> void:
	for i in 240:
		await process_frame
		if current_scene != null and current_scene.scene_file_path.ends_with(path) and current_scene.is_node_ready():
			break
	await _frames(6)


func _init() -> void:
	await process_frame
	gs = root.get_node("GameState")
	sound = root.get_node("Sound")
	scenes = root.get_node("Scenes")
	sound.settings_path = "user://feel-polish-test-%d.cfg" % OS.get_process_id()
	sound.reduced_motion = false
	sound.sounds_on = true
	sound.haptics_enabled = true
	gs.persist = false
	gs.new_campaign(preload("res://scripts/data/cultures.gd").VARDISH)
	_typeface()
	await _autosave()
	await _map_camera()
	await _into_battle()
	await _battle()
	_audio()
	await _settings()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(sound.settings_path))
	print("\nFeel polish tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)


# ---- the body typeface
func _typeface() -> void:
	var face: Font = Style.body_font()
	check(face != null and FileAccess.file_exists(Style.BODY_FONT), "the body face is in the game")
	check(Style.make_theme().default_font == face, "every themed screen sets it")
	check(ThemeDB.fallback_font == face and root.theme != null and root.theme.default_font == face,
		"and so do the window and the engine's fallback, for everything else")
	var ones: float = face.get_string_size("1111", HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	var eights: float = face.get_string_size("8888", HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	check(is_equal_approx(ones, eights), "its digits are tabular, so a count ticking up doesn't wobble")
	var three: Rect2 = Rect2(Vector2.ZERO, face.get_char_size(ord("3"), 26))
	check(three.size.y > 0.0, "its digits are drawn")


# ---- the road autosave, written on a worker
func _autosave() -> void:
	var path := "user://feel-polish-save-%d.json" % OS.get_process_id()
	var was_path: String = gs.save_path
	gs.save_path = path
	gs.persist = true
	check(gs.save_game_async(), "an autosave on the road starts")
	gs.finish_saving()
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(typeof(data) == TYPE_DICTIONARY and data.has("army") and data.has("world"), "and lands whole, written by the worker")
	check(not FileAccess.file_exists(path + ".async.tmp"), "with no temporary file left behind")
	check(float(gs.save_timing["snapshot_ms"]) >= 0.0 and float(gs.save_timing["write_ms"]) >= 0.0, "its cost is measured")
	# A save made while one is being written waits for it, so the newer one is what's kept.
	gs.silver = 4321
	gs.save_game_async()
	gs.silver = 1234
	gs.save_game()
	data = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(typeof(data) == TYPE_DICTIONARY and int(data.get("silver", 0)) == 1234, "a save made after an autosave is the one that stays")
	gs.persist = false
	gs.save_path = was_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	await _frames(1)


# ---- the map camera
func _map_camera() -> void:
	change_scene_to_file("res://scenes/world_map.tscn")
	await _arrive("world_map.tscn")
	var m = current_scene
	var w = gs.world
	var here := String(w.player().node)
	var there := ""
	for id in Data.SETTLEMENTS:
		if id != here:
			there = id
			break
	# A glide, not a cut.
	m._looked_away = true
	var target: Vector2 = Data.pos(there)
	m._glide_to(target)
	await _frames(2)
	check(m.cam_center.distance_to(m._clamped(target)) > 1.0, "Show on map glides rather than cuts")
	await _wait(0.5)
	check(m.cam_center.distance_to(m._clamped(target)) < 1.0, "and arrives where it was sent")
	# A flick carries on and slows.
	var start: Vector2 = m.cam_center
	m._fling = Vector2(400.0, 0.0)
	m._update_camera(0.1)
	check(m.cam_center.x > start.x, "a flick carries the view on after the finger lifts")
	for i in 60:
		m._update_camera(0.1)
	check(m._fling == Vector2.ZERO, "and comes to rest")
	# Past the edge, it springs back.
	m.cam_center = m._clamped(m.cam_center) + Vector2(-300.0, 0.0)
	for i in 40:
		m._update_camera(0.05)
	check(m.cam_center.distance_to(m._clamped(m.cam_center)) < 0.6, "dragged past the edge, the map springs back")
	# A drag's last moments become the flick.
	m._drag_trail.clear()
	var now := Time.get_ticks_msec()
	m._drag_trail.append([now - 60, Vector2(300, 600)])
	m._drag_trail.append([now - 5, Vector2(200, 600)])
	m._release_drag()
	check(m._fling.x > 0.0, "letting go of a drag to the left sends the view on to the right")
	m._fling = Vector2.ZERO
	# Riding: the view keeps the party in sight, until the player looks elsewhere.
	check(w.travel(there), "the party sets out")
	m._update_camera(0.016)
	m.cam_center = m._clamped(w.party_pos(w.player()) + Vector2(0.0, 600.0))
	m._looked_away = false
	for i in 120:
		m._update_camera(0.1)
	var box: Vector2 = m._view.size / m.cam_scale * 0.5
	var off: Vector2 = (w.party_pos(w.player()) - m.cam_center).abs()
	check(off.x <= box.x and off.y <= box.y, "while it rides, the view follows the party")
	m._looked_away = true
	var held: Vector2 = m.cam_center + Vector2(0.0, 300.0)
	m.cam_center = m._clamped(held)
	var before: Vector2 = m.cam_center
	m._update_camera(0.1)
	check(m.cam_center == before, "once the player has looked away, the view stays theirs")
	# The road shown before you ride.
	var other := ""
	for id in Data.SETTLEMENTS:
		if id != here and id != there:
			other = id
			break
	m._selected = other
	m._open_preview(other)
	check(m._ghost_for == other and not m._ghost_route.is_empty() and String(m._ghost_route.back()) == other,
		"a settlement's sheet shows the road there on the map")
	m._close_sheet()
	# Reduced motion: every move a cut.
	sound.reduced_motion = true
	m._glide_to(Data.pos(here))
	check(m.cam_center == m._clamped(Data.pos(here)), "under Reduced motion the view cuts")
	sound.reduced_motion = false
	# Back at the start, standing (the road out isn't what's under test).
	w.player().path = []
	w.player().next = ""
	w.player().along = 0.0
	await _frames(2)


# ---- the way into battle
func _into_battle() -> void:
	var w = gs.world
	w.encounter = w.bands()[0].id
	gs.start_encounter_battle()
	var n0: int = sound.haptic_count
	scenes.go_battle()
	await _wait(0.15)
	var top: ColorRect = scenes._shutters[0]
	check(top.visible and top.size.y > 0.0, "into battle, the shutter closes from top and bottom")
	check(sound.haptic_count > n0, "with a knock in the hand")
	await _arrive("battle.tscn")
	await _wait(0.7)
	check(current_scene.scene_file_path.ends_with("battle.tscn") and not top.visible and not scenes._busy,
		"and opens on the field")


# ---- the battle
func _battle() -> void:
	var sc = current_scene
	var sim = sc.sim
	sc._start_battle()
	sc._end_title()
	var mine = null
	var theirs = null
	for sq in sim.squads:
		if sq.team == Sim.PLAYER and mine == null:
			mine = sq
		if sq.team == Sim.ENEMY and theirs == null:
			theirs = sq
	sc.paused = true
	# Drawn between steps.
	sim.order_all(Sim.PLAYER, "advance")
	sc._remember_positions()
	var so = mine.soldiers[0]
	var was: Vector2 = so.pos
	for i in 3:
		sim.step()
	var now: Vector2 = so.pos
	sc._lerp_k = 0.0
	check(sc._drawn_pos(so) == was, "a man is drawn from where he stood before the step")
	sc._lerp_k = 1.0
	check(sc._drawn_pos(so) == now, "to where he stands after it")
	sc._lerp_k = 0.5
	check(sc._drawn_pos(so).distance_to(was.lerp(now, 0.5)) < 0.001 and so.pos == now, "and between them, without moving him")
	sc._prev_pos[so] = now + Vector2(200.0, 0.0)
	check(sc._drawn_pos(so) == now, "a jump (a squad placed, men arriving) is drawn where it lands")
	check(sc._drawn_avg(mine) is Vector2, "a squad's standard is drawn between steps too")
	# Blows heard as they land, in a melee only, and never a rattle.
	sound.placed = {}
	mine.engaged = false
	theirs.engaged = false
	var foe_so = theirs.soldiers[0]
	foe_so.flash = 1.0
	foe_so.target = so
	sc._hit_seen.erase(foe_so)
	sc._update_effects(0.5)
	var blows := 0
	for k in ["sword", "shield", "spear", "heavy"]:
		blows += int(sound.placed.get(k, 0))
	check(blows == 0, "a man hit outside a melee (an arrow) is heard as the volley, not as steel")
	theirs.engaged = true
	sound.placed = {}
	sc._blow_budget = 0.0
	var struck: Array = theirs.soldiers.filter(func(s): return s.alive).slice(0, 10)
	for s in struck:
		s.flash = 1.0
		s.target = so
		sc._hit_seen.erase(s)
	sc._update_effects(1.0)
	sound.end_battle_sounds()
	blows = 0
	for k in ["sword", "shield", "spear", "heavy"]:
		blows += int(sound.placed.get(k, 0))
	check(blows >= 1 and blows <= int(sc.BLOW_SOUND_BURST), "ten blows at once ring out, but no more than %d of them (%d)" % [int(sc.BLOW_SOUND_BURST), blows])
	for s in struck:
		s.flash = 0.0
	foe_so.flash = 0.0
	theirs.engaged = false
	# Orders sound; refusals are felt.
	sound._last.erase("order_select")
	sc._select(mine)
	check(sound._last.has("order_select"), "taking a squad in hand ticks")
	sound._last.erase("order_march")
	sc._order_move(mine, mine.average_pos() + Vector2(0.0, -30.0))
	check(sound._last.has("order_march") or sc._march_refusal(mine, mine.average_pos() + Vector2(0.0, -30.0)) != "", "a march order taps the drum")
	sound._last.erase("order_attack")
	sc._order_attack(mine, theirs)
	check(sound._last.has("order_attack"), "an attack order beats to arms")
	var n0: int = sound.haptic_count
	sound._last.erase("order_refuse")
	sc._refuse("Cannot march there: test.")
	check(sound._last.has("order_refuse") and sound.haptic_count == n0 + 1 and sound.last_pulse == "refuse",
		"a refused order knocks, and is felt firmer than an accepted one")
	# The battle's time, heard.
	sc.paused = true
	check(sc._felt_pace() == 0.0, "paused, the fight is heard as stopped")
	sc.paused = false
	sc._slow = 0.5
	check(is_equal_approx(sc._felt_pace(), sc.SLOW_PACE), "a captain's fall slows it")
	sc._slow = 0.0
	check(sc._felt_pace() == 1.0, "and then it runs on")
	sim.winner = Sim.PLAYER
	check(sc._felt_pace() == 1.0, "a decided battle is never heard slowed")
	sim.winner = -1
	# The developer's multipliers reach the field.
	sound.feel["hitstop"] = 2.0
	check(is_equal_approx(sc._hitstop_k(), 2.0), "the hit-stop multiplier reaches the battle")
	sound.feel["hitstop"] = 1.0
	sound.feel["shake"] = 0.0
	sc._shake = 0.0
	sc._kick(9.0)
	check(sc._shake == 0.0, "a shake multiplier of zero stills the field")
	sound.feel["shake"] = 1.0
	# Ground and hour.
	check(BattleScreen.battle_ambience("", "day") == "road_open", "open ground has the wind under it")
	check(BattleScreen.battle_ambience("woods", "day") == "birds", "a wood its birds")
	check(BattleScreen.battle_ambience("woods", "night") == "road_night", "after dark, the night's quiet")
	check(BattleScreen.battle_ambience("river", "night") == "water", "but a ford's river still runs")
	check(String(sound._loop_name) != "", "every battle has a ground under its music")
	sc.paused = true


# ---- sound and the hand
func _audio() -> void:
	# Slowed and stopped.
	sound.set_battle_time(0.0)
	sound._process(1.0)
	var field := AudioServer.get_bus_index("Field")
	var dull := AudioServer.get_bus_effect(field, 0) as AudioEffectLowPassFilter
	var music := AudioServer.get_bus_index("Music")
	check(is_equal_approx(sound.time_slowed(), 1.0) and dull.cutoff_hz <= sound.SLOW_CUTOFF + 1.0,
		"paused, the field is heard through a wall")
	check(AudioServer.get_bus_volume_db(music) <= sound.volume_db(sound.music_volume) + sound.SLOW_MUSIC_DB + 0.01,
		"and the music steps back")
	check(sound.time_pitch() < 1.0, "the men's sounds drop in pitch")
	sound.set_battle_time(1.0)
	for i in 10:
		sound._process(0.1)
	check(sound.time_slowed() == 0.0 and dull.cutoff_hz > 15000.0, "at full pace the field is clear again")
	sound.set_battle_time(0.25)
	sound._process(1.0)
	sound.end_battle_sounds()
	check(sound.time_slowed() == 0.0 and is_equal_approx(AudioServer.get_bus_volume_db(music), sound.volume_db(sound.music_volume)),
		"leaving the battle puts everything back")
	# Warmed up.
	check(sound.warm_battle("vardish") > 40, "the battle's sounds are read in before the fight")
	# Haptics by weight.
	var n0: int = sound.haptic_count
	sound.pulse("death")
	check(sound.haptic_count == n0 + 1 and sound.last_pulse == "death", "a captain's fall has its own, longest pulse")
	sound.haptic(true)
	check(sound.last_pulse == "heavy", "the old strong pulse is the heavy one")
	sound.haptic(false)
	check(sound.last_pulse == "tap", "and the light one a tap")
	sound.haptics_enabled = false
	sound.pulse("impact")
	check(sound.haptic_count == n0 + 3, "none when vibration is off")
	sound.haptics_enabled = true
	# Volumes.
	sound.set_music_volume(0.5)
	check(is_equal_approx(AudioServer.get_bus_volume_db(music), sound.volume_db(0.5)), "the music's level follows its slider")
	sound.set_sound_volume(0.25)
	check(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Sounds")), sound.volume_db(0.25)), "and the sounds' theirs")
	var cfg := ConfigFile.new()
	cfg.load(sound.settings_path)
	check(is_equal_approx(float(cfg.get_value("audio", "music_volume", -1.0)), 0.5) and is_equal_approx(float(cfg.get_value("audio", "sound_volume", -1.0)), 0.25),
		"both are kept on the device")
	check(sound.volume_db(0.5) < -5.0 and sound.volume_db(1.0) == 0.0, "half the slider is about half as loud, full is as mixed")
	sound.set_music_volume(1.0)
	sound.set_sound_volume(1.0)
	# The road themes rest between plays.
	sound.play_music("vardish")
	var p: AudioStreamPlayer = sound._music[sound._current]
	check(p.stream is AudioStreamOggVorbis and not (p.stream as AudioStreamOggVorbis).loop, "a road theme plays through rather than looping")
	sound._on_music_finished(p)
	check(sound.resting, "and when it ends, the road has the map to itself for a while")
	sound.play_music("title")
	check(not sound.resting and (sound._music[sound._current].stream as AudioStreamOggVorbis).loop, "other music loops as before")


# ---- the settings
func _settings() -> void:
	change_scene_to_file("res://scenes/settings.tscn")
	await _arrive("settings.tscn")
	var page = current_scene
	var slider := page.find_child("Slider_MusicVolume", true, false) as HSlider
	check(slider != null and slider.custom_minimum_size.y >= Style.TOUCH * 0.7, "Settings has a music volume slider, big enough for a thumb")
	slider.value = 0.3
	check(is_equal_approx(sound.music_volume, 0.3), "moving it sets the level at once")
	slider.drag_ended.emit(true)
	var cfg := ConfigFile.new()
	cfg.load(sound.settings_path)
	check(is_equal_approx(float(cfg.get_value("audio", "music_volume", -1.0)), 0.3), "letting go keeps it")
	check(page.find_child("Slider_SoundVolume", true, false) != null, "and a sound volume slider")
	check(page.find_child("Slider_Hit-stop", true, false) == null, "the feel multipliers stay out of the player's way")
	page._dev_open = true
	page._build()
	await _frames(2)
	var hitstop := page.find_child("Slider_Hit-stop", true, false) as HSlider
	check(hitstop != null and page.find_child("ResetFeel", true, false) != null, "under Developer, each feel multiplier has a slider and they reset together")
	if hitstop != null:
		hitstop.value = 1.5
		hitstop.drag_ended.emit(true)
		check(is_equal_approx(float(sound.feel["hitstop"]), 1.5), "a feel slider sets its multiplier")
	sound.reset_feel()
	check(sound.feel.values().all(func(v): return is_equal_approx(float(v), 1.0)), "Reset puts every multiplier back to 1")
	sound.set_music_volume(1.0)
