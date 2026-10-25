## Headless checks for the battle rules. Run from the project folder:
##   godot --headless --script res://tests/run_tests.gd
## Add `-- --balance` to also see how one-button plans fare against the computer
## (slower: it fights two dozen more battles). Exits with code 1 if any check fails.
extends SceneTree

const Sim = preload("res://scripts/battle/battle_sim.gd")
const Commander = preload("res://scripts/battle/commander_ai.gd")
const Troops = preload("res://scripts/data/troops.gd")

const DUEL_SEEDS := 12
const BATTLE_SEEDS := 6

var failures := 0


func _init() -> void:
	print("Deployment:")
	_check_deployment()

	print("Orders:")
	_check_orders()
	_check_arrows()

	print("Counter duels (one squad each, %d seeds):" % DUEL_SEEDS)
	_check_counter(Troops.SPEARMEN, Troops.CAVALRY)
	_check_counter(Troops.CAVALRY, Troops.ARCHERS)
	_check_counter(Troops.ARCHERS, Troops.INFANTRY)
	_check_counter(Troops.INFANTRY, Troops.SPEARMEN)
	_check_counter(Troops.SPEARMEN, Troops.CAVALRY, true)

	print("Mirror duels should be close to even:")
	for type in Troops.ORDER:
		var wins := 0
		for s in range(1, DUEL_SEEDS + 1):
			if _duel(type, type, s)["winner"] == Sim.PLAYER:
				wins += 1
		print("  %-9s vs itself  %2d/%d" % [type, wins, DUEL_SEEDS])

	print("Full battles, AI against AI (%d seeds):" % BATTLE_SEEDS)
	var tally := [0, 0]
	var timeouts := 0
	var total_time := 0.0
	for s in range(1, BATTLE_SEEDS + 1):
		var r := _full_battle(s)
		if r["winner"] == -1:
			failures += 1
			print("  seed %2d  FAIL: no winner after %.0fs" % [s, r["time"]])
			continue
		tally[r["winner"]] += 1
		total_time += r["time"]
		if r["reason"] == "time":
			timeouts += 1
		print("  seed %2d  %s won by %-6s in %5.1fs  (blue lost %d men, red lost %d)" % [
			s, "blue" if r["winner"] == Sim.PLAYER else "red ", r["reason"], r["time"], r["lost_blue"], r["lost_red"]])
	print("  blue %d, red %d" % [tally[0], tally[1]])
	_expect(timeouts <= BATTLE_SEEDS / 4, "battles end with an army breaking, not the clock (%d timed out)" % timeouts)
	var avg_time := total_time / BATTLE_SEEDS
	_expect(avg_time >= 40.0 and avg_time <= 150.0, "a battle lasts about a minute (%.0fs on average)" % avg_time)

	if OS.get_cmdline_user_args().has("--balance"):
		print("Plain orders against the computer (12 seeds):")
		for plan in ["advance", "hold"]:
			var wins := 0
			for s in range(1, 13):
				if _plain_battle(plan, s) == Sim.PLAYER:
					wins += 1
			print("  %-7s all battle long: won %2d/12" % [plan.capitalize(), wins])

	print("Campaign results add up:")
	_check_results()

	print("FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)


func _expect(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])


# ---------------------------------------------------------------- deployment

func _check_deployment() -> void:
	var sim := Sim.new()
	sim.setup(_army(5), _army(6), 5)
	for i in 30:
		sim.step()
	_expect(sim.time == 0.0, "time stands still while deploying")
	_expect(sim.place(Sim.PLAYER, 1, Vector2(360, 300)) == null, "can't place a squad in the enemy half")

	var first = sim.place(Sim.PLAYER, 1, Vector2(360, 800))
	var second = sim.place(Sim.PLAYER, 2, Vector2(360, 800))
	_expect(first != null and second != null, "two squads placed on the same spot both go down")
	_expect(first != null and second != null and not _touching(sim, first, second), "the second one is nudged clear of the first")

	sim.place(Sim.PLAYER, 1, Vector2(200, 950))
	_expect(first.center.distance_to(Vector2(200, 950)) < 1.0 and sim.reserves[Sim.PLAYER].size() == 5,
		"tapping a placed squad's id again moves it")

	sim.auto_deploy(Sim.PLAYER)
	sim.auto_deploy(Sim.ENEMY, 26.0)
	var ok_zone := true
	var ok_apart := true
	for a in sim.squads:
		if not sim.deploy_zone(a.team).grow(1.0).has_point(a.center):
			ok_zone = false
		for b in sim.squads:
			if a != b and a.team == b.team and _touching(sim, a, b):
				ok_apart = false
	_expect(sim.all_placed(Sim.PLAYER) and sim.all_placed(Sim.ENEMY) and sim.squads.size() == 14, "Auto-place puts every squad down")
	_expect(ok_zone, "every squad is inside its own deployment zone")
	_expect(ok_apart, "no two squads overlap")

	sim.start_battle()
	sim.step()
	_expect(sim.phase == Sim.PHASE_BATTLE and sim.time > 0.0, "the clock starts with the battle")
	_expect(sim.place(Sim.PLAYER, 1, Vector2(360, 800)) == null, "no placing once the battle is on")
	sim.dispose()


func _touching(sim, a, b) -> bool:
	var ha: Vector2 = sim._footprint(a.type, a.start_men)
	var hb: Vector2 = sim._footprint(b.type, b.start_men)
	return absf(a.center.x - b.center.x) < ha.x + hb.x and absf(a.center.y - b.center.y) < ha.y + hb.y


# ---------------------------------------------------------------- orders

func _check_orders() -> void:
	var sim := Sim.new()
	sim.setup([{"id": 1, "type": Troops.INFANTRY, "men": 10}], [{"id": 2, "type": Troops.INFANTRY, "men": 10}], 9)
	var mine = sim.place(Sim.PLAYER, 1, Vector2(360, 850))
	var theirs = sim.place(Sim.ENEMY, 2, Vector2(360, 250))
	sim.start_battle()
	var start: Vector2 = mine.center
	for i in 150:
		sim.step()
	_expect(mine.center.distance_to(start) < 3.0 and theirs.center.distance_to(Vector2(360, 250)) < 3.0,
		"squads hold where they were placed until ordered")

	sim.order_all(Sim.PLAYER, "advance")
	for i in 120:
		sim.step()
	_expect(mine.order == "advance" and start.y - mine.center.y > 100.0, "Advance sends a squad at the enemy")

	sim.order_all(Sim.PLAYER, "hold")
	var held: Vector2 = mine.center
	for i in 90:
		sim.step()
	_expect(mine.order == "hold" and mine.center.distance_to(held) < 3.0, "Hold stops it where it stands")

	sim.order_move(mine, Vector2(150, 700))
	for i in 240:
		sim.step()
	_expect(mine.order == "hold" and mine.center.distance_to(Vector2(150, 700)) < 8.0, "a march order ends holding the new ground")
	sim.dispose()


func _check_arrows() -> void:
	var sim := Sim.new()
	sim.setup([{"id": 1, "type": Troops.ARCHERS, "men": 20}], [{"id": 2, "type": Troops.INFANTRY, "men": 20}], 4)
	var bows = sim.place(Sim.PLAYER, 1, Vector2(Sim.ARENA.x * 0.5, Sim.MID_Y + 200.0))
	sim.place(Sim.ENEMY, 2, Vector2(Sim.ARENA.x * 0.5, Sim.MID_Y - 60.0))
	sim.start_battle()
	var full: int = bows.arrows
	bows.arrows = 5 # a short quiver, so the check doesn't wait on a whole barrage
	while sim.winner == -1 and sim.time < 30.0 and bows.arrows > 0:
		sim.step()
	_expect(full == 20 * int(Troops.stats(Troops.ARCHERS)["arrows"]) and bows.arrows == 0 and not bows.ranged,
		"archers run out of arrows (%d) and draw their blades" % full)
	sim.dispose()


# ---------------------------------------------------------------- duels

## `braced`: the stronger squad holds and lets the other come to it.
func _check_counter(strong: String, weak: String, braced: bool = false) -> void:
	var wins := 0
	var survivors := 0
	for s in range(1, DUEL_SEEDS + 1):
		var r := _duel(strong, weak, s, braced)
		if r["winner"] == Sim.PLAYER:
			wins += 1
			survivors += r["left"]
	var ok := wins >= int(DUEL_SEEDS * 0.8)
	if not ok:
		failures += 1
	print("  %-9s beat %-9s %2d/%d  avg survivors %.1f  %s%s" % [
		strong, weak, wins, DUEL_SEEDS, float(survivors) / maxi(1, wins), "ok" if ok else "FAIL",
		"  (holding)" if braced else ""])


func _duel(a: String, b: String, seed_value: int, a_holds: bool = false) -> Dictionary:
	var sim := Sim.new()
	sim.setup([{"id": 1, "type": a, "men": Troops.full_size(a)}], [{"id": 2, "type": b, "men": Troops.full_size(b)}], seed_value)
	var x := Sim.ARENA.x * 0.5 + sim.rng.randf_range(-40.0, 40.0)
	sim.place(Sim.PLAYER, 1, Vector2(x, Sim.MID_Y + 280.0))
	sim.place(Sim.ENEMY, 2, Vector2(Sim.ARENA.x - x, Sim.MID_Y - 280.0))
	sim.start_battle()
	if not a_holds:
		sim.order_all(Sim.PLAYER, "advance")
	sim.order_all(Sim.ENEMY, "advance")
	while sim.winner == -1 and sim.time < Sim.TIME_LIMIT:
		sim.step()
	var left := 0
	for sq in sim.squads:
		if sq.team == Sim.PLAYER:
			left = sq.alive_count()
	var winner := sim.winner
	sim.dispose()
	return {"winner": winner, "left": left}


# ---------------------------------------------------------------- full battles

func _army(seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919
	var out := []
	var id := 1
	for type in [Troops.INFANTRY, Troops.INFANTRY, Troops.SPEARMEN, Troops.SPEARMEN, Troops.ARCHERS, Troops.ARCHERS, Troops.CAVALRY]:
		out.append({"id": id, "type": type, "men": Troops.full_size(type), "xp": 0})
		id += 1
	# shuffle so roster order differs between seeds
	for i in range(out.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = out[i]
		out[i] = out[j]
		out[j] = tmp
	return out


func _ai_battle(player_army: Array, enemy_army: Array, seed_value: int) -> Sim:
	var sim := Sim.new()
	sim.setup(player_army, enemy_army, seed_value)
	sim.ai = [Commander.new(Sim.PLAYER), Commander.new(Sim.ENEMY)]
	sim.ai[Sim.PLAYER].deploy(sim)
	sim.ai[Sim.ENEMY].deploy(sim)
	sim.start_battle()
	while sim.winner == -1 and sim.time < Sim.TIME_LIMIT + 5.0:
		sim.step()
	return sim


## A player who lines up with Auto-place and gives one order for the whole battle,
## against the computer's commander. Returns the winner.
func _plain_battle(plan: String, seed_value: int) -> int:
	var sim := Sim.new()
	sim.setup(_army(seed_value), _army(seed_value + 1000), seed_value)
	sim.ai[Sim.ENEMY] = Commander.new(Sim.ENEMY)
	sim.ai[Sim.ENEMY].deploy(sim)
	sim.auto_deploy(Sim.PLAYER)
	sim.start_battle()
	sim.order_all(Sim.PLAYER, plan)
	while sim.winner == -1 and sim.time < Sim.TIME_LIMIT + 5.0:
		sim.step()
	var winner := sim.winner
	sim.dispose()
	return winner


func _full_battle(seed_value: int) -> Dictionary:
	var sim := _ai_battle(_army(seed_value), _army(seed_value + 1000), seed_value)
	var blue: Dictionary = sim.result_for(Sim.PLAYER)
	var red: Dictionary = sim.result_for(Sim.ENEMY)
	var out := {"winner": sim.winner, "reason": sim.end_reason, "time": sim.time, "lost_blue": blue["lost"], "lost_red": red["lost"]}
	sim.dispose()
	return out


func _check_results() -> void:
	var army := _army(3)
	var start_men := 0
	for e in army:
		start_men += int(e["men"])
	var sim := _ai_battle(army, _army(4), 3)
	var r: Dictionary = sim.result_for(Sim.PLAYER)
	sim.dispose()
	var survivors := 0
	for id in r["squads"]:
		survivors += int(r["squads"][id]["men"])
	_expect(survivors + int(r["lost"]) == start_men and r["squads"].size() == army.size(),
		"%d men went in, %d came back, %d lost" % [start_men, survivors, r["lost"]])
