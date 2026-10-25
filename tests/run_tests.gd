## Headless checks for the battle rules. Run from the project folder:
##   godot --headless --script res://tests/run_tests.gd
## Add `-- --balance` to also fight scripted plans against every kind of computer
## commander and check that skill pays: pressing Advance all and nothing else should win
## about half the time, a player who uses the tools far more often (slower: a hundred
## more battles). Exits with code 1 if any check fails.
extends SceneTree

const Sim = preload("res://scripts/battle/battle_sim.gd")
const Commander = preload("res://scripts/battle/commander_ai.gd")
const Troops = preload("res://scripts/data/troops.gd")
const Captains = preload("res://scripts/data/captains.gd")
const GameStateScript = preload("res://scripts/game_state.gd")
const Plans = preload("res://tests/plans.gd")

const DUEL_SEEDS := 12
const BATTLE_SEEDS := 6
const BALANCE_SEEDS := 12

var failures := 0


func _init() -> void:
	print("Deployment:")
	_check_deployment()

	print("Orders:")
	_check_orders()
	_check_arrows()

	print("Tactics:")
	_check_flanks()
	_check_brace()
	_check_steering()

	print("Abilities:")
	_check_shield_wall()
	_check_schiltron()
	_check_volley()
	_check_wheel()

	print("Commanders:")
	_check_commanders()

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
		_check_balance()

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


# ---------------------------------------------------------------- tactics

func _check_flanks() -> void:
	var sim := Sim.new()
	sim.setup([{"id": 1, "type": Troops.INFANTRY, "men": 20}],
		[{"id": 2, "type": Troops.INFANTRY, "men": 20}, {"id": 3, "type": Troops.INFANTRY, "men": 20}], 7)
	var mine = sim.place(Sim.PLAYER, 1, Vector2(420, 760))
	var front = sim.place(Sim.ENEMY, 2, Vector2(420, 520))
	var other = sim.place(Sim.ENEMY, 3, Vector2(200, 300))
	sim.start_battle()
	var man = mine.soldiers[0]
	var behind: Vector2 = man.pos + Vector2(0, 60)
	var free: int = sim._side_of(man, behind, other)
	mine.engaged = true
	mine.focus = front
	var rear: int = sim._side_of(man, behind, other)
	var side: int = sim._side_of(man, man.pos + Vector2(60, 0), other)
	var own_fight: int = sim._side_of(man, behind, front)
	_expect(free == Sim.FRONT and rear == Sim.REAR and side == Sim.FLANK and own_fight == Sim.FRONT,
		"only a squad pinned in a fight can be caught in the flank or rear, and only by someone else")
	sim.dispose()

	# Hammer and anvil: the same horse, sent into the back of a squad already pinned by
	# foot, breaks it sooner after it strikes and loses fewer riders than when it rides
	# in from the front alongside the foot.
	var head_on := [0.0, 0]
	var in_rear := [0.0, 0]
	for s in range(1, 7):
		var a := _hammer(s, false)
		var b := _hammer(s, true)
		head_on[0] += a[0]
		head_on[1] += a[1]
		in_rear[0] += b[0]
		in_rear[1] += b[1]
	_expect(in_rear[0] < head_on[0] * 0.9 and in_rear[1] < head_on[1],
		"horse in the rear of a pinned squad breaks it sooner (%.0fs after striking, against %.0fs head-on) and loses fewer riders (%d against %d)" % [
			in_rear[0] / 6.0, head_on[0] / 6.0, in_rear[1], head_on[1]])


## Our infantry, pinned by enemy infantry, charged by enemy horse from behind (or from
## the front, alongside the foot). Returns [seconds from the horse's first blow until our
## squad breaks, riders lost].
func _hammer(seed_value: int, from_behind: bool) -> Array:
	var sim := Sim.new()
	sim.setup([{"id": 1, "type": Troops.INFANTRY, "men": 20}],
		[{"id": 2, "type": Troops.INFANTRY, "men": 20}, {"id": 3, "type": Troops.CAVALRY, "men": 16}], seed_value)
	var mine = sim.place(Sim.PLAYER, 1, Vector2(420, 760))
	var anvil = sim.place(Sim.ENEMY, 2, Vector2(420, 480))
	var hammer = sim.place(Sim.ENEMY, 3, Vector2(600, 480))
	sim.start_battle()
	if from_behind:
		sim._move_formation(hammer, Vector2(420, 1080))
	sim.order_attack(anvil, mine)
	var sent := false
	var struck := -1.0
	while sim.winner == -1 and sim.time < 150.0:
		if not sent and (mine.engaged or not from_behind):
			sent = true
			sim.order_attack(hammer, mine)
		sim.step()
		if struck < 0.0 and hammer.engaged:
			struck = sim.time
	var out := [sim.time - maxf(struck, 0.0), 16 - hammer.alive_count()]
	sim.dispose()
	return out


func _check_brace() -> void:
	var sim := Sim.new()
	sim.setup([{"id": 1, "type": Troops.INFANTRY, "men": 20}], [{"id": 2, "type": Troops.INFANTRY, "men": 20}], 3)
	var mine = sim.place(Sim.PLAYER, 1, Vector2(420, 800))
	sim.place(Sim.ENEMY, 2, Vector2(420, 300))
	sim.start_battle()
	for i in 90:
		sim.step()
	var braced: bool = mine.braced()
	sim.order_advance(mine)
	sim.step()
	_expect(braced and not mine.braced(), "a squad that holds its ground is braced; one on the move isn't")
	sim.dispose()

	var wins := 0
	for s in range(1, DUEL_SEEDS + 1):
		if _duel(Troops.INFANTRY, Troops.INFANTRY, s, true)["winner"] == Sim.PLAYER:
			wins += 1
	_expect(wins >= int(DUEL_SEEDS * 0.7), "a braced line wins the even fight it receives (%d/%d)" % [wins, DUEL_SEEDS])


func _check_steering() -> void:
	var lost := 0
	var reached := 0
	for s in range(1, 5):
		var sim := Sim.new()
		sim.setup([{"id": 1, "type": Troops.CAVALRY, "men": 16}],
			[{"id": 2, "type": Troops.SPEARMEN, "men": 20}, {"id": 3, "type": Troops.ARCHERS, "men": 20}], s)
		var horse = sim.place(Sim.PLAYER, 1, Vector2(420, 1000))
		sim.place(Sim.ENEMY, 2, Vector2(420, 470))
		var bows = sim.place(Sim.ENEMY, 3, Vector2(420, 330))
		sim.start_battle()
		sim.order_attack(horse, bows)
		while sim.time < 30.0 and not horse.engaged and horse.is_active():
			sim.step()
		if horse.engaged and horse.focus == bows:
			reached += 1
		lost += 16 - horse.alive_count()
		sim.dispose()
	_expect(reached == 4 and lost <= 8, "horse sent at archers behind a spear line ride around it (%d/4 got there, %d men lost)" % [reached, lost])


# ---------------------------------------------------------------- abilities

func _check_shield_wall() -> void:
	var hurt := [0.0, 0.0]
	var pace := [0.0, 0.0]
	for walled in [0, 1]:
		var sim := Sim.new()
		sim.setup([{"id": 1, "type": Troops.INFANTRY, "men": 20}], [{"id": 2, "type": Troops.ARCHERS, "men": 20}], 5)
		var wall = sim.place(Sim.PLAYER, 1, Vector2(420, 760))
		sim.place(Sim.ENEMY, 2, Vector2(420, 545))
		sim.start_battle()
		if walled == 1:
			sim.use_ability(wall)
		for i in 240:
			sim.step()
		for so in wall.soldiers:
			hurt[walled] += so.max_hp - (so.hp if so.alive else 0.0)
		var from: Vector2 = wall.center
		sim.order_move(wall, from + Vector2(0, 200))
		for i in 30:
			sim.step()
		pace[walled] = wall.center.distance_to(from)
		sim.dispose()
	_expect(hurt[1] < hurt[0] * 0.5, "a shield wall takes the sting out of arrows from the front (%.0f damage against %.0f)" % [hurt[1], hurt[0]])
	_expect(pace[1] < pace[0] * 0.65, "and moves at half pace")


func _check_schiltron() -> void:
	var landed := [false, false]
	var side := [-1, -1]
	for ring in [0, 1]:
		var sim := Sim.new()
		sim.setup([{"id": 1, "type": Troops.SPEARMEN, "men": 20}],
			[{"id": 2, "type": Troops.INFANTRY, "men": 20}, {"id": 3, "type": Troops.CAVALRY, "men": 16}], 6)
		var spears = sim.place(Sim.PLAYER, 1, Vector2(420, 760))
		var foot = sim.place(Sim.ENEMY, 2, Vector2(420, 520))
		var horse = sim.place(Sim.ENEMY, 3, Vector2(620, 300))
		sim.start_battle()
		for s in sim.squads:
			s.refresh()
		if ring == 1:
			sim.use_ability(spears)
		spears.engaged = true
		spears.focus = foot
		var rider = horse.soldiers[0]
		var victim = spears.soldiers[0]
		rider.pos = victim.pos + Vector2(0, 30)
		rider.runup = 200.0
		side[ring] = sim._side_of(victim, rider.pos, horse)
		sim._strike(rider, horse, victim, 10.0)
		for e in sim.events:
			if e["type"] == "charge":
				landed[ring] = true
		sim.dispose()
	_expect(landed[0] and side[0] == Sim.REAR, "horse charging pinned spearmen from behind lands the charge")
	_expect(not landed[1] and side[1] == Sim.FRONT, "a schiltron has no rear, and the charge breaks on it")


func _check_volley() -> void:
	var shock := [0.0, 0.0]
	var quick := 0
	for v in [0, 1]:
		var sim := Sim.new()
		sim.setup([{"id": 1, "type": Troops.ARCHERS, "men": 20}], [{"id": 2, "type": Troops.INFANTRY, "men": 20}], 8)
		var bows = sim.place(Sim.PLAYER, 1, Vector2(420, 760))
		var foot = sim.place(Sim.ENEMY, 2, Vector2(420, 545))
		sim.start_battle()
		for i in 45:
			sim.step()
		var arrows: int = bows.arrows
		var morale: float = foot.morale
		var men: int = foot.alive_count()
		if v == 1:
			_expect(sim.use_ability(bows) and not sim.ability_ready(bows), "a volley goes off, then has to wait for its cooldown")
		for i in 15:
			sim.step()
		if v == 1:
			quick = arrows - bows.arrows
		for i in 45:
			sim.step()
		# Morale lost beyond what the dead alone cost.
		shock[v] = morale - foot.morale - (men - foot.alive_count()) * (100.0 / 20.0 * 0.8 + 2.0)
		sim.dispose()
	_expect(quick >= 18, "every bow looses within half a second (%d arrows)" % quick)
	_expect(shock[1] > shock[0] + 3.0, "and the volley shakes the target's nerve")


func _check_wheel() -> void:
	var sim := Sim.new()
	sim.setup([{"id": 1, "type": Troops.CAVALRY, "men": 16}], [{"id": 2, "type": Troops.INFANTRY, "men": 20}], 9)
	var horse = sim.place(Sim.PLAYER, 1, Vector2(420, 760))
	var foot = sim.place(Sim.ENEMY, 2, Vector2(420, 520))
	sim.start_battle()
	sim.order_attack(horse, foot)
	while sim.time < 30.0 and horse.engaged_for < 3.0:
		sim.step()
	sim.events.clear()
	var stuck: Vector2 = horse.avg
	_expect(sim.use_ability(horse) and horse.wheeling, "horse stuck in a melee can wheel away")
	var far := 0.0
	var charged := false
	while sim.time < 60.0 and not charged and horse.is_active():
		sim.step()
		far = maxf(far, horse.avg.distance_to(stuck))
		for e in sim.events:
			if e["type"] == "charge" and e["squad"] == horse:
				charged = true
		sim.events.clear()
	_expect(far > 90.0 and charged, "they ride clear (%.0f units) and charge the same enemy again" % far)
	sim.dispose()


# ---------------------------------------------------------------- commanders

func _check_commanders() -> void:
	var moved := {}
	var horse_early := {}
	for temp in Commander.TEMPERAMENTS:
		var sim := Sim.new()
		sim.setup(_army(4), _army(5), 4)
		sim.ai[Sim.ENEMY] = Commander.new(Sim.ENEMY, temp)
		sim.ai[Sim.ENEMY].deploy(sim)
		sim.auto_deploy(Sim.PLAYER)
		sim.start_battle()
		moved[temp] = -1.0
		horse_early[temp] = false
		var ai = sim.ai[Sim.ENEMY]
		while sim.time < 25.0:
			sim.step()
			for sq in sim.squads:
				if sq.team != Sim.ENEMY:
					continue
				if moved[temp] < 0.0 and sq.type != Troops.CAVALRY and sq.order == "advance":
					moved[temp] = sim.time
				if sq.type == Troops.CAVALRY and sq.order != "hold" and ai.contact_at < 0.0:
					horse_early[temp] = true
		sim.dispose()
	_expect(moved[Commander.RECKLESS] > 0.0 and moved[Commander.RECKLESS] < 9.0,
		"a reckless commander comes straight at you (moved at %.0fs)" % moved[Commander.RECKLESS])
	_expect(moved[Commander.PATIENT] < 0.0, "a patient one waits for you to come")
	_expect(moved[Commander.HAMMER] > 0.0 and not horse_early[Commander.HAMMER],
		"a hammer-and-anvil commander sends its foot first and holds its horse until the lines meet")


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
	sim.place(Sim.ENEMY, 2, Vector2(x, Sim.MID_Y - 280.0))
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
	return Plans.army(seed_value)


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


## Every scripted plan against every kind of commander, and the targets that say skill
## pays off: a player who only ever presses Advance all should win about half the time,
## one who uses the tools far more often.
func _check_balance() -> void:
	print("Plans against each kind of commander (%d seeds each):" % BALANCE_SEEDS)
	var rates := {}
	for plan in Plans.PLANS:
		var line := "  %-9s" % plan
		var won := 0
		for temp in Commander.TEMPERAMENTS:
			var w := 0
			for s in range(1, BALANCE_SEEDS + 1):
				if Plans.battle(plan, temp, s)["winner"] == Sim.PLAYER:
					w += 1
			won += w
			line += "  %s %2d/%d" % [temp, w, BALANCE_SEEDS]
		rates[plan] = float(won) / (BALANCE_SEEDS * Commander.TEMPERAMENTS.size())
		print("%s   %3.0f%%" % [line, rates[plan] * 100.0])
	_expect(rates["advance"] <= 0.55, "pressing Advance all and nothing else wins about half the time at most (%.0f%%)" % (rates["advance"] * 100.0))
	_expect(rates["tactician"] >= 0.7, "a player who uses the tools wins at least 70%% of the time (%.0f%%)" % (rates["tactician"] * 100.0))


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
