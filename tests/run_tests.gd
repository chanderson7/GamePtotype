## Headless checks for the battle rules. Run from the project folder:
##   godot --headless --script res://tests/run_tests.gd
## Exits with code 1 if any check fails.
extends SceneTree

const Sim = preload("res://scripts/battle/battle_sim.gd")
const Commander = preload("res://scripts/battle/commander_ai.gd")
const Troops = preload("res://scripts/data/troops.gd")

const DUEL_SEEDS := 20
const BATTLE_SEEDS := 12

var failures := 0


func _init() -> void:
	print("Counter duels (one squad each, %d seeds):" % DUEL_SEEDS)
	_check_counter(Troops.SPEARMEN, Troops.CAVALRY)
	_check_counter(Troops.CAVALRY, Troops.ARCHERS)
	_check_counter(Troops.ARCHERS, Troops.INFANTRY)
	_check_counter(Troops.INFANTRY, Troops.SPEARMEN)

	print("Mirror duels should be close to even:")
	for type in Troops.ORDER:
		var wins := 0
		for s in range(1, DUEL_SEEDS + 1):
			if _duel(type, type, s)["winner"] == Sim.PLAYER:
				wins += 1
		print("  %-9s vs itself  %2d/%d" % [type, wins, DUEL_SEEDS])

	print("Full battles, AI against AI (%d seeds):" % BATTLE_SEEDS)
	var tally := [0, 0]
	for s in range(1, BATTLE_SEEDS + 1):
		var r := _full_battle(s)
		if r["winner"] == -1:
			failures += 1
			print("  seed %2d  FAIL: no winner after %.0fs" % [s, r["time"]])
			continue
		tally[r["winner"]] += 1
		print("  seed %2d  %s won by %-6s in %5.1fs  (blue lost %d men, red lost %d)" % [
			s, "blue" if r["winner"] == Sim.PLAYER else "red ", r["reason"], r["time"], r["lost_blue"], r["lost_red"]])
	print("  blue %d, red %d" % [tally[0], tally[1]])

	print("Campaign results add up:")
	_check_results()

	print("FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)


func _check_counter(strong: String, weak: String) -> void:
	var wins := 0
	var survivors := 0
	for s in range(1, DUEL_SEEDS + 1):
		var r := _duel(strong, weak, s)
		if r["winner"] == Sim.PLAYER:
			wins += 1
			survivors += r["left"]
	var ok := wins >= int(DUEL_SEEDS * 0.8)
	if not ok:
		failures += 1
	print("  %-9s beat %-9s %2d/%d  avg survivors %.1f  %s" % [
		strong, weak, wins, DUEL_SEEDS, float(survivors) / maxi(1, wins), "ok" if ok else "FAIL"])


func _duel(a: String, b: String, seed_value: int) -> Dictionary:
	var sim := Sim.new()
	sim.setup([{"id": 1, "type": a, "men": Troops.full_size(a)}], [{"id": 2, "type": b, "men": Troops.full_size(b)}], seed_value)
	sim.points = [Sim.MAX_POINTS, Sim.MAX_POINTS]
	var x := 360.0 + sim.rng.randf_range(-40.0, 40.0)
	sim.deploy(Sim.PLAYER, 0, Vector2(x, 830.0))
	sim.deploy(Sim.ENEMY, 0, Vector2(720.0 - x, 270.0))
	while sim.winner == -1 and sim.time < 120.0:
		sim.step()
	var left := 0
	for sq in sim.squads:
		if sq.team == Sim.PLAYER:
			left = sq.alive_count()
	var winner := sim.winner
	sim.dispose()
	return {"winner": winner, "left": left}


func _army(seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919
	var out := []
	var id := 1
	for type in [Troops.INFANTRY, Troops.INFANTRY, Troops.SPEARMEN, Troops.SPEARMEN, Troops.ARCHERS, Troops.ARCHERS, Troops.CAVALRY]:
		out.append({"id": id, "type": type, "men": Troops.full_size(type), "xp": 0})
		id += 1
	# shuffle so hands differ between seeds
	for i in range(out.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = out[i]
		out[i] = out[j]
		out[j] = tmp
	return out


func _full_battle(seed_value: int) -> Dictionary:
	var sim := Sim.new()
	sim.setup(_army(seed_value), _army(seed_value + 1000), seed_value)
	sim.ai = [Commander.new(Sim.PLAYER), Commander.new(Sim.ENEMY)]
	while sim.winner == -1 and sim.time < Sim.TIME_LIMIT + 5.0:
		sim.step()
	var blue: Dictionary = sim.result_for(Sim.PLAYER)
	var red: Dictionary = sim.result_for(Sim.ENEMY)
	sim.dispose()
	return {"winner": sim.winner, "reason": sim.end_reason, "time": sim.time, "lost_blue": blue["lost"], "lost_red": red["lost"]}


func _check_results() -> void:
	var sim := Sim.new()
	var army := _army(3)
	var start_men := 0
	for e in army:
		start_men += int(e["men"])
	sim.setup(army, _army(4), 3)
	sim.ai = [Commander.new(Sim.PLAYER), Commander.new(Sim.ENEMY)]
	while sim.winner == -1 and sim.time < Sim.TIME_LIMIT + 5.0:
		sim.step()
	var r: Dictionary = sim.result_for(Sim.PLAYER)
	sim.dispose()
	var survivors := 0
	for id in r["squads"]:
		survivors += int(r["squads"][id]["men"])
	var ok: bool = survivors + int(r["lost"]) == start_men and r["squads"].size() == army.size()
	if not ok:
		failures += 1
	print("  %d men went in, %d came back, %d lost  %s" % [start_men, survivors, r["lost"], "ok" if ok else "FAIL"])
