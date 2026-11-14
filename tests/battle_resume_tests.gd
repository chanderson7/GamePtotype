## A battle survives the phone closing the game. The battle's orders are journaled as they
## are given (BattleSim.command); fought again from the same seed with them, the battle
## comes back exactly as it was (BattleSim.replay). The battle screen keeps the battle in
## the campaign save as it begins and whenever the game goes to the background; after a
## relaunch, Continue goes back to it, the battle is fought back to where it was, and it
## waits, paused. Once its result is in, nothing is kept.
extends SceneTree

const Sim = preload("res://scripts/battle/battle_sim.gd")
const Commander = preload("res://scripts/battle/commander_ai.gd")
const Troops = preload("res://scripts/data/troops.gd")
const Units = preload("res://scripts/data/units.gd")

var failures := 0


func check(ok: bool, message: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + message)
	if not ok:
		failures += 1


func _init() -> void:
	_run.call_deferred()


func _army(culture: String, n: int, base: int, shift: int) -> Array:
	var out := []
	for i in n:
		var t: String = Troops.ORDER[(i + shift) % 4]
		var u := Units.recruit(culture, t)
		out.append({"id": base + i, "type": t, "unit": u, "men": Units.full_size(u), "culture": culture, "xp": 0, "level": 1})
	return out


## The battle's state, exactly: every squad's men, morale and order, every man's place,
## health and life.
func _state(sim) -> String:
	var parts := PackedStringArray([str(sim.ticks), str(sim.winner)])
	for sq in sim.squads:
		parts.append("%d:%d:%s:%s:%s" % [sq.id, sq.alive_n, var_to_str(sq.morale), sq.order, var_to_str(sq.center)])
		for so in sq.soldiers:
			parts.append("%s,%s,%s" % [var_to_str(so.pos), var_to_str(so.hp), so.alive])
	return "|".join(parts)


func _fresh_sim():
	var sim = Sim.new()
	sim.setup(_army("vardish", 6, 100, 0), _army("kharzani", 6, 200, 1), 4242,
		{"type": "open", "seed": 4242, "biome": "kharzan", "fair": true}, "rout")
	sim.ai[Sim.ENEMY] = Commander.new(Sim.ENEMY)
	sim.ai[Sim.ENEMY].deploy(sim)
	return sim


func _run() -> void:
	# ---- 1. the journal: the same seed and the same orders give the same battle
	var sim = _fresh_sim()
	sim.command("auto_deploy", [Sim.PLAYER])
	sim.command("start_battle")
	var mine: Array = sim.squads.filter(func(s): return s.team == Sim.PLAYER)
	var bows: Array = mine.filter(func(s): return s.ranged)
	var at_400 := ""
	while sim.winner == -1 and sim.ticks < 3000:
		match sim.ticks:
			30:
				sim.command("order_all", [Sim.PLAYER, "advance"])
			120:
				sim.command("order_hold", [mine[0]])
			150:
				if not bows.is_empty():
					sim.command("set_hold_fire", [bows[0], true])
			200:
				sim.command("order_move", [mine[1], mine[1].center + Vector2(60, -40)])
			260:
				sim.command("order_line", [Sim.PLAYER, Vector2(200, 700), Vector2(640, 700), null])
			300:
				sim.command("order_all", [Sim.PLAYER, "advance"])
		if sim.ticks == 400:
			at_400 = _state(sim)
		sim.step()
	var end_state := _state(sim)
	check(sim.journal.size() >= 7 and int(sim.journal[0][0]) == 0 and String(sim.journal.back()[1]) == "order_all",
		"each order is written with the step it was given at (%d orders)" % sim.journal.size())
	var packed: String = State.pack(sim.journal)
	var journal = State.unpack(packed)
	check(typeof(journal) == TYPE_ARRAY and var_to_str(journal) == var_to_str(sim.journal),
		"the journal comes back from the save exactly (ints, points and squads by id)")
	var again = _fresh_sim()
	again.replay(journal, 400)
	check(again.ticks == 400 and _state(again) == at_400, "fought again from the journal, the battle at step 400 is the same, man for man")
	var chunks := 0
	while not again.replay(journal, 1 << 30, 50):
		chunks += 1
	check(_state(again) == end_state and again.winner == sim.winner and chunks > 5,
		"and fought on in pieces, it ends the same: the same winner, at the same step")
	check(var_to_str(again.journal) == var_to_str(sim.journal), "the orders go back into the new battle's own journal as they're given again")
	sim.dispose()
	again.dispose()

	# ---- 2. the battle screen keeps a campaign battle and finds it again after a relaunch
	var gs = root.get_node("GameState")
	gs.persist = true
	gs.save_path = "user://resume_campaign.json"
	gs.new_campaign("vardish")
	var w = gs.world
	w.encounter = w.bands()[0].id
	gs.start_encounter_battle()
	change_scene_to_file("res://scenes/battle.tscn")
	await process_frame
	await process_frame
	var screen = current_scene
	screen.set_process(false)
	check(not gs.battle_resume.is_empty() and screen.sim.ticks == 0, "a campaign battle is kept as it begins")
	screen._on_auto()
	screen._on_fight()
	screen._title = {}
	for i in 60:
		screen._process(0.1)
	screen._on_advance()
	for i in 40:
		screen._process(0.1)
	screen._select(screen.sim.squads.filter(func(s): return s.team == Sim.PLAYER)[0])
	screen._on_hold()
	for i in 30:
		screen._process(0.1)
	var ticks: int = screen.sim.ticks
	check(ticks > 300 and screen.sim.winner == -1 and screen.sim.journal.size() >= 4,
		"the battle is under way, with orders given (%d steps, %d orders)" % [ticks, screen.sim.journal.size()])
	screen._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	var when_closed := _state(screen.sim)
	check(screen.paused, "going to the background pauses the battle")
	var on_disk = JSON.parse_string(FileAccess.get_file_as_string(gs.save_path))
	check(typeof(on_disk) == TYPE_DICTIONARY and typeof(on_disk.get("battle_resume")) == TYPE_DICTIONARY
		and int(on_disk["battle_resume"].get("ticks", -1)) == ticks, "and writes the battle so far into the save")

	# The phone closes the game; it opens again.
	screen.set_process(false)
	change_scene_to_file("res://scenes/title.tscn")
	await process_frame
	await process_frame
	gs.pending_battle = {}
	gs.battle_resume = {}
	check(gs.load_game() and gs.battle_waiting(), "after a relaunch, the save says a battle is waiting")
	change_scene_to_file("res://scenes/title.tscn")
	await process_frame
	await process_frame
	var go := current_scene.find_child("ContinueButton", true, false) as Button
	check(go != null and go.text == "Back to the battle", "and Home's Continue says where it goes")
	go.pressed.emit()
	for i in 240:
		await process_frame
		if current_scene != null and current_scene.scene_file_path.ends_with("battle.tscn") and current_scene.get("_resume_to") == -1 \
				and current_scene.is_node_ready():
			break
	screen = current_scene
	var arrived: bool = screen != null and screen.scene_file_path.ends_with("battle.tscn")
	check(arrived, "Continue goes back to the battle")
	if arrived:
		check(screen.sim.ticks == ticks and _state(screen.sim) == when_closed,
			"which is fought back to exactly where it was (step %d of %d)" % [screen.sim.ticks, ticks])
		check(screen.paused and screen.get_node_or_null("ResumeLayer") == null, "and waits, paused, for you")
		screen.set_process(false)
		screen._set_paused(false)
		screen.sim.command("order_all", [Sim.PLAYER, "advance"])
		check(screen.sim.journal.size() > 4 and String(screen.sim.journal.back()[1]) == "order_all",
			"orders from here on join the same journal")
		screen.sim.command("concede", [Sim.PLAYER])
		for i in 3:
			screen.sim.step()
		screen._back_to_camp()
		check(gs.battle_resume.is_empty() and not gs.battle_waiting(), "once its result is in, the battle is no longer kept")
		on_disk = JSON.parse_string(FileAccess.get_file_as_string(gs.save_path))
		check(typeof(on_disk) == TYPE_DICTIONARY and (on_disk.get("battle_resume", {}) as Dictionary).is_empty(),
			"and the save says so")
		for i in 30:
			await process_frame

	# ---- 3. a battle the map sets up is never mistaken for one to come back to
	gs.battle_resume = {"setup": "stale", "journal": "", "ticks": 5}
	gs.pending_battle = {"enemy": []}
	check(not gs.battle_waiting(), "a battle set up since is the one fought, not a kept one")
	gs.pending_battle = {}
	check(gs.battle_waiting(), "a kept battle waits only when nothing has been set up since")
	gs.battle_resume = {}
	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.save_path))
	print("Battle resume failures: %d" % failures)
	quit(1 if failures > 0 else 0)


const State = preload("res://scripts/game_state.gd")
