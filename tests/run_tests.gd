## Headless checks for the battle rules. Run from the project folder:
##   godot --headless --script res://tests/run_tests.gd
## Add `-- --balance` to also see how one-button plans fare against the computer
## (slower: it fights two dozen more battles). Exits with code 1 if any check fails.
extends SceneTree

const Sim = preload("res://scripts/battle/battle_sim.gd")
const Commander = preload("res://scripts/battle/commander_ai.gd")
const Troops = preload("res://scripts/data/troops.gd")
const Captains = preload("res://scripts/data/captains.gd")
const GameStateScript = preload("res://scripts/game_state.gd")

const DUEL_SEEDS := 12
const BATTLE_SEEDS := 6

var failures := 0


func _init() -> void:
	print("Deployment:")
	_check_deployment()

	print("Orders:")
	_check_orders()
	_check_arrows()

	print("Captains:")
	_check_captains()
	_check_death_roll()
	_check_bonds_and_grief()
	_check_camp_memory()

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


# ---------------------------------------------------------------- captains

func _captained(type: String, id: int, extra: Dictionary = {}) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = id
	var c := Captains.make(rng, id, type)
	c["quirk"] = ""
	c.merge(extra, true)
	return {"id": id, "type": type, "men": 20, "captain": c}


func _check_captains() -> void:
	var sim := Sim.new()
	var wounded := _captained(Troops.INFANTRY, 2, {"wounded": 1})
	sim.setup([_captained(Troops.INFANTRY, 1), wounded], [{"id": 9, "type": Troops.INFANTRY, "men": 20}], 3)
	var sq = sim.place(Sim.PLAYER, 1, Vector2(300, 900))
	var hurt = sim.place(Sim.PLAYER, 2, Vector2(560, 900))
	var base := float(Troops.stats(Troops.INFANTRY)["hp"])
	var heart := true
	for so in sq.soldiers:
		if so.slot.length() < sq.captain.slot.length() - 0.1:
			heart = false
	_expect(sq.captain != null and sq.captain.captain and is_equal_approx(sq.captain.max_hp, base * Captains.HP_MULT) and heart,
		"each squad's captain is a hardier man at the heart of the squad")
	_expect(hurt.captain == null and hurt.info.is_empty(), "a wounded captain sits the battle out")
	sim.dispose()


## Knock a captain down and return the event. `friends` puts another squad beside him.
func _fell_captain(seed_value: int, lucky: bool, friends: bool) -> Dictionary:
	var sim := Sim.new()
	var army := [_captained(Troops.INFANTRY, 1, {"quirk": Captains.LUCKY if lucky else ""})]
	if friends:
		army.append({"id": 2, "type": Troops.INFANTRY, "men": 20})
	sim.setup(army, [{"id": 9, "type": Troops.INFANTRY, "men": 20}], seed_value)
	var sq = sim.place(Sim.PLAYER, 1, Vector2(300, 900))
	if friends:
		sim.place(Sim.PLAYER, 2, Vector2(450, 900))
	var foe = sim.place(Sim.ENEMY, 9, Vector2(300, 300))
	sim.start_battle()
	for s in sim.squads:
		s.refresh()
	var morale: float = sq.morale
	sim._damage(sq.captain, 99999.0, foe)
	var out := {}
	for e in sim.events:
		if e["type"] == "captain_down":
			out = e.duplicate()
	out["shock"] = morale - sq.morale
	out["leaderless"] = sq.captain == null and is_equal_approx(sq.led, Captains.LEADERLESS)
	sim.dispose()
	return out


func _check_death_roll() -> void:
	var trials := 300
	for setup in [[false, false], [true, true]]:
		var deaths := 0
		var ok_needed := true
		var first := {}
		for s in range(1, trials + 1):
			var e := _fell_captain(s, setup[0], setup[1])
			if first.is_empty():
				first = e
			if e.get("fate", "") == "killed":
				deaths += 1
				ok_needed = ok_needed and int(e["roll"]) < int(e["needed"])
			else:
				ok_needed = ok_needed and int(e["roll"]) >= int(e["needed"])
		var chance := Captains.death_chance({"quirk": Captains.LUCKY if setup[0] else ""}, true, setup[1])
		var rate := 100.0 * deaths / trials
		_expect(absf(rate - chance) < 7.0 and ok_needed,
			"a fallen captain dies on a d100 roll under %d: %.0f%% died over %d falls%s" % [
				chance + 1, rate, trials, " (lucky, friends nearby)" if setup[0] else ""])
		if not setup[0]:
			_expect(first.get("leaderless", false) and float(first.get("shock", 0.0)) >= Captains.FALL_SHOCK,
				"the squad reels and fights on leaderless")


func _check_bonds_and_grief() -> void:
	var sim := Sim.new()
	var a := _captained(Troops.INFANTRY, 1, {"temperament": Captains.STEADFAST})
	var b := _captained(Troops.SPEARMEN, 2, {"temperament": Captains.VENGEFUL})
	a["captain"]["bonds"] = {"2": Captains.RANK_POINTS[3]}
	b["captain"]["bonds"] = {"1": Captains.RANK_POINTS[3]}
	sim.setup([a, b], [{"id": 9, "type": Troops.INFANTRY, "men": 40}], 5)
	var sa = sim.place(Sim.PLAYER, 1, Vector2(330, 760))
	var sb = sim.place(Sim.PLAYER, 2, Vector2(510, 760))
	sim.place(Sim.ENEMY, 9, Vector2(420, 520))
	sim.start_battle()
	sim.order_all(Sim.PLAYER, "advance")
	sim.order_all(Sim.ENEMY, "advance")
	var power := 0.0
	for i in 600:
		sim.step()
		power = maxf(power, sb.bond_power)
	var key := "1|2"
	_expect(float(sim.bond_time.get(key, 0.0)) > 5.0 and sim.result_for(Sim.PLAYER)["bonds"].has(key),
		"captains fighting side by side build their bond (%.0fs together)" % float(sim.bond_time.get(key, 0.0)))
	_expect(is_equal_approx(power, Captains.RANK_POWER[3]), "an A-rank pair hits harder fighting near each other")
	if sa.captain != null and sb.captain != null:
		sim._damage(sa.captain, 99999.0, null)
		_expect(sb.fury > 0.0, "a Vengeful captain flies into a fury when a bonded friend falls")
	sim.dispose()


func _check_camp_memory() -> void:
	var gs = GameStateScript.new()
	gs.persist = false
	gs.new_warband()
	var s1: Dictionary = gs.army[0]
	var s2: Dictionary = gs.army[1]
	var c1: Dictionary = s1["captain"]
	var c2: Dictionary = s2["captain"]
	var key := "%d|%d" % [mini(c1["id"], c2["id"]), maxi(c1["id"], c2["id"])]
	var result := {"won": true, "lost": 5, "killed": 9, "reason": "rout", "bonds": {key: 120.0}, "squads": {
		int(s1["id"]): {"men": 12, "kills": 4, "captain": {"id": c1["id"], "fate": "killed", "roll": 12, "needed": 31, "kills": 2, "words": "Tell them I held."}},
		int(s2["id"]): {"men": 15, "kills": 3, "captain": {"id": c2["id"], "fate": "wounded", "roll": 77, "needed": 31, "kills": 1, "words": ""}},
	}}
	var lines: Array = gs.describe_result(result)
	gs.apply_result(result)
	var heir = gs.army[0]["captain"]
	_expect(gs.fallen.size() == 1 and gs.fallen[0]["name"] == c1["name"] and gs.fallen[0]["words"] == "Tell them I held.",
		"the dead go on the memorial with their last words")
	_expect(heir != null and int(heir["id"]) != int(c1["id"]) and gs.army[0]["name"] == s1["name"],
		"a veteran takes command and the company keeps its name")
	_expect(int(c2["wounded"]) == Captains.WOUND_BATTLES and not c2["bonds"].has(str(c1["id"])),
		"the wounded are marked to sit out, and bonds with the dead are closed")
	_expect(lines.size() >= 2 and String(lines[0]).contains("Rolled 12"), "the result screen tells each captain's fate")
	# Next battle: the wounded captain is absent and heals a battle's worth.
	gs.apply_result({"won": false, "squads": {int(s2["id"]): {"men": 15, "kills": 0}}})
	_expect(int(c2["wounded"]) == Captains.WOUND_BATTLES - 1, "a wounded captain heals as battles pass")
	var c3: Dictionary = gs.army[2]["captain"]
	var c4: Dictionary = gs.army[3]["captain"]
	var k2 := "%d|%d" % [mini(c3["id"], c4["id"]), maxi(c3["id"], c4["id"])]
	gs.apply_result({"won": true, "bonds": {k2: 60.0}, "squads": {}})
	_expect(is_equal_approx(float(c3["bonds"][str(c4["id"])]), float(c4["bonds"][str(c3["id"])])) and float(c3["bonds"][str(c4["id"])]) > 0.0,
		"bond points are shared by both captains")
	gs.free()


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
		out.append({"id": id, "type": type, "men": Troops.full_size(type), "xp": 0,
			"captain": Captains.make(rng, seed_value * 100 + id, type)})
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
