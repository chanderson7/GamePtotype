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
const Cultures = preload("res://scripts/data/cultures.gd")
const WorldSim = preload("res://scripts/world/world_sim.gd")
const WorldData = preload("res://scripts/world/world_data.gd")
const Economy = preload("res://scripts/data/economy.gd")
const AutoResolve = preload("res://scripts/battle/auto_resolve.gd")

const DUEL_SEEDS := 12
const BATTLE_SEEDS := 6
const BALANCE_SEEDS := 12
## Battles of the full sim that auto-resolve is checked against, and scripted campaigns.
const CALIBRATION_BATTLES := 16
const CAMPAIGN_SEEDS := 6
const CAMPAIGN_DAYS := 30

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

	print("Cultures:")
	_check_cultures()

	print("World:")
	_check_map()
	_check_travel()
	_check_encounters()
	_check_world_saves()
	_check_long_run()
	_check_campaign_battles()

	print("Captains:")
	_check_captains()
	_check_death_roll()
	_check_bonds_and_grief()
	_check_camp_memory()

	print("Economy:")
	_check_upkeep()
	_check_hiring()
	_check_drill()
	_check_spoils()

	print("Auto-resolve:")
	_check_auto_resolve()
	_check_auto_encounter()

	print("Scripted campaigns, settling every fight unled (%d days, %d seeds):" % [CAMPAIGN_DAYS, CAMPAIGN_SEEDS])
	_check_campaigns()

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


# ---------------------------------------------------------------- cultures

func _check_cultures() -> void:
	for c in Cultures.ORDER:
		var gs = GameStateScript.new()
		gs.persist = false
		gs.new_campaign(c)
		var names: Array = Cultures.info(c)["first"]
		var origins: Array = Cultures.info(c)["origins"]
		var own := true
		for sq in gs.army:
			var cap: Dictionary = sq["captain"]
			var origin := String(cap["name"]).split(" of ", true, 1)[1]
			if not names.has(cap["first"]) or not origins.has(origin) or cap["culture"] != c:
				own = false
			if String(sq["name"]) != "%s's %s" % [cap["first"], Cultures.company_noun(c, sq["type"])]:
				own = false
		var home: String = gs.world.player().node
		_expect(own and home == WorldData.capital_of_culture(c),
			"a %s warband has %s captains and companies, and starts at %s" % [
				Cultures.info(c)["people"], Cultures.info(c)["people"], WorldData.settlement(home)["name"]])
		gs.free()


# ---------------------------------------------------------------- world

## A world with no bandits in it, so travel checks aren't interrupted.
func _quiet_world(seed_value: int) -> WorldSim:
	var w := WorldSim.new()
	w.setup(seed_value, Cultures.VARDISH)
	w.parties = [w.player()]
	return w


func _check_map() -> void:
	var w := _quiet_world(1)
	var connected := true
	for a in WorldData.SETTLEMENTS:
		for b in WorldData.SETTLEMENTS:
			if a != b and w.path(a, b).is_empty():
				connected = false
	_expect(connected, "every settlement can reach every other by road")
	var on_land := true
	for id in WorldData.SETTLEMENTS:
		if WorldData.land_at(WorldData.pos(id)) == -1:
			on_land = false
	var roads_ok := true
	for r in WorldData.ROADS:
		var a := WorldData.pos(r[0])
		var b := WorldData.pos(r[1])
		if r[2]:
			if WorldData.land_at(a) == WorldData.land_at(b):
				roads_ok = false
		else:
			for i in 21:
				if WorldData.land_at(a.lerp(b, i / 20.0)) == -1:
					roads_ok = false
	_expect(on_land and roads_ok, "every settlement and land road is on land, and every sea lane crosses water")
	var realms_ok := true
	for f in WorldData.FACTIONS:
		if f == WorldData.BANDITS:
			continue
		var capital: String = WorldData.FACTIONS[f]["capital"]
		if WorldData.settlement(capital)["faction"] != f or not Cultures.has(WorldData.culture_of(f)):
			realms_ok = false
	for id in WorldData.SETTLEMENTS:
		if not WorldData.FACTIONS.has(WorldData.settlement(id)["faction"]):
			realms_ok = false
	_expect(realms_ok, "every settlement belongs to a realm of a known culture, and each realm holds its capital")


func _check_travel() -> void:
	var w := _quiet_world(2)
	var hours := w.hours_to("khalun")
	w.travel("khalun")
	w.step(hours)
	_expect(w.here() == "khalun" and absf(w.hour - hours) < 0.01,
		"a ride from Highcliff to Khalun takes the time the map says (%.1f hours)" % hours)

	w = _quiet_world(3)
	var by_hand := WorldData.pos("highcliff").distance_to(WorldData.pos("kettlebrook")) / WorldSim.LAND_SPEED \
		+ WorldData.pos("kettlebrook").distance_to(WorldData.pos("hamazaki")) / WorldSim.SEA_SPEED
	hours = w.hours_to("hamazaki")
	w.travel("hamazaki")
	w.step(hours + 0.01)
	_expect(absf(hours - by_hand) < 0.01 and w.here() == "hamazaki", "sea lanes are slower than roads (%.1f hours to Hamazaki)" % hours)

	var before := w.hour
	w.step(5.0)
	_expect(w.hour == before, "the clock stands still while the warband does")
	w.wait(8.0)
	w.step(20.0)
	_expect(absf(w.hour - before - 8.0) < 0.001, "waiting eight hours takes eight hours")


func _check_encounters() -> void:
	var w := WorldSim.new()
	w.setup(4, Cultures.VARDISH)
	var band = null
	for b in w.bands():
		if b.faction == "vardmark":
			band = b
	w.parties = [w.player(), band]
	band.node = "thornwall"
	band.next = ""
	band.wait = 999.0
	band.grace_until = -1.0
	w.events.clear()
	w.travel("thornwall")
	w.step(30.0)
	var found := w.events.filter(func(e): return e["type"] == "encounter")
	var stopped := w.hour
	w.step(5.0)
	_expect(found.size() == 1 and w.encounter == band.id and w.hour == stopped,
		"a band on the road stops the warband and the clock")
	w.win_encounter()
	_expect(w.bands().is_empty() and w.busy(), "a beaten band is gone and the warband rides on")
	w.step(10.0)
	w.wait(30.0)
	w.step(40.0)
	var back := w.bands()
	_expect(back.size() == 1 and back[0].faction == "vardmark" and WorldData.settlement(back[0].node)["faction"] == "vardmark",
		"a day later another band rises in the same realm")


func _check_world_saves() -> void:
	var w := WorldSim.new()
	w.setup(5, Cultures.RYUMON)
	w.travel("takamine")
	w.step(3.3)
	var saved := JSON.stringify(w.to_dict())
	var copy := WorldSim.new()
	copy.from_dict(JSON.parse_string(saved))
	var same := JSON.stringify(copy.to_dict()) == saved
	for world in [w, copy]:
		world.step(40.0)
		if world.encounter != -1:
			world.withdraw()
		world.travel("hamazaki")
		world.step(40.0)
	_expect(same and JSON.stringify(copy.to_dict()) == JSON.stringify(w.to_dict()),
		"a saved world loads back exactly, and carries on exactly as the original")

	var gs = GameStateScript.new()
	gs.persist = false
	gs.new_campaign(Cultures.KHARZANI)
	gs.world.travel("nahrabad")
	gs.world.step(2.0)
	var data := JSON.stringify(gs.to_dict())
	var gs2 = GameStateScript.new()
	gs2.persist = false
	gs2.from_dict(JSON.parse_string(data))
	_expect(JSON.stringify(gs2.to_dict()) == data, "a saved campaign loads back with its warband, place and hour")
	gs.free()
	gs2.free()


func _check_long_run() -> void:
	var w := WorldSim.new()
	w.setup(6, Cultures.VARDISH)
	var ids: Array = WorldData.SETTLEMENTS.keys()
	var rng := RandomNumberGenerator.new()
	rng.seed = 6
	var most := 0
	var per_realm_ok := true
	var outcome := 0
	var guard := 0
	while w.hour < 60.0 * 24.0 and guard < 20000:
		guard += 1
		if w.encounter != -1:
			match outcome % 3:
				0:
					w.win_encounter()
				1:
					w.withdraw()
				_:
					w.lose_encounter()
			outcome += 1
		elif not w.busy():
			if not w.travel(ids[rng.randi_range(0, ids.size() - 1)]):
				w.wait(6.0)
		w.step(1.0)
		most = maxi(most, w.bands().size())
		var seen := {}
		for b in w.bands():
			if seen.has(b.faction):
				per_realm_ok = false
			seen[b.faction] = true
	_expect(w.hour >= 60.0 * 24.0 and most <= 3 and per_realm_ok and outcome > 3,
		"sixty days of riding: never more than one band per realm (%d encounters)" % outcome)


func _check_campaign_battles() -> void:
	var gs = GameStateScript.new()
	gs.persist = false
	gs.new_campaign(Cultures.VARDISH)
	var band = gs.world.bands()[0]
	gs.world.encounter = band.id
	gs.start_encounter_battle()
	var set_up: bool = gs.pending_battle.get("enemy", []).size() == band.army.size() and gs.pending_battle["name"] == band.name
	gs.apply_result({"won": true, "squads": {}})
	_expect(set_up and gs.world.party(band.id) == null and gs.pending_battle.is_empty(),
		"bandits beaten in battle are gone from the map")

	band = gs.world.bands()[0]
	gs.world.travel("ravensford")
	gs.world.step(1.0)
	gs.world.encounter = band.id
	var hour: float = gs.world.hour
	gs.start_encounter_battle()
	gs.apply_result({"won": false, "squads": {}})
	_expect(gs.world.here() == "highcliff" and gs.world.hour >= hour + WorldSim.REGROUP_HOURS and gs.world.party(band.id) != null,
		"a beaten warband regroups at its capital half a day later, and the bandits stay")
	gs.free()


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


# ---------------------------------------------------------------- economy

## A new campaign at the capital, with the bandits cleared off the roads.
func _economy_campaign(seed_value: int):
	var gs = GameStateScript.new()
	gs.persist = false
	gs.rng.seed = seed_value
	gs.new_campaign(Cultures.VARDISH)
	gs.world.parties = [gs.world.player()]
	return gs


## A day standing still.
func _pass_day(gs) -> void:
	gs.map_notice = ""
	gs.world.wait(24.0)
	gs.advance(24.0)


func _check_upkeep() -> void:
	var gs = _economy_campaign(21)
	var men: int = gs.total_men()
	_expect(gs.silver == Economy.START_SILVER and gs.food_days() == Economy.START_FOOD_DAYS and gs.army.size() == 5 \
			and gs.squad_cap() == Economy.SQUADS_BASE,
		"a new warband has %d silver, %d days of food and five squads, and may lead %d" % [gs.silver, gs.food_days(), gs.squad_cap()])
	var wages: int = gs.daily_wages()
	var silver: int = gs.silver
	var food: int = gs.food
	_pass_day(gs)
	_expect(gs.silver == silver - wages and gs.food == food - men and gs.total_men() == men and gs.map_notice == "",
		"a day costs a day's wages (%d silver) and a ration a man, and nobody leaves" % wages)
	gs.food = 0
	_pass_day(gs)
	var left: int = men - gs.total_men()
	_expect(left >= int(men * Economy.DESERTION * 0.5) and left <= int(ceil(men * Economy.DESERTION * 1.5)) \
			and gs.map_notice.contains("hungry"),
		"with nothing to eat about one man in ten deserts a day (%d of %d), and the map says so" % [left, men])
	men = gs.total_men()
	gs.food = men * 10
	gs.silver = gs.daily_wages() / 2
	_pass_day(gs)
	var short: int = men - gs.total_men()
	_expect(short > 0 and short < left and gs.silver == 0 and gs.map_notice.contains("unpaid"),
		"half a day's wages loses fewer men (%d)" % short)
	gs.free()


func _check_hiring() -> void:
	var gs = _economy_campaign(22)
	gs.silver = 5000
	var here: String = gs.world.here()
	gs.world.offers[here] = [{"type": Troops.CAVALRY, "culture": Cultures.RYUMON}, {"type": Troops.ARCHERS, "culture": Cultures.VARDISH}]
	var price := Economy.recruit_cost(Troops.CAVALRY, Troops.full_size(Troops.CAVALRY))
	var hired: bool = gs.hire(here, 0)
	var s: Dictionary = gs.army.back()
	_expect(hired and gs.army.size() == 6 and s["type"] == Troops.CAVALRY and s["culture"] == Cultures.RYUMON \
			and s["captain"]["culture"] == Cultures.RYUMON and int(s["men"]) == Troops.full_size(Troops.CAVALRY) and gs.silver == 5000 - price,
		"hiring abroad brings a full squad of that land's men under a captain of their own, for %d silver" % price)
	_expect(gs.world.offers_at(here).size() == 1 and not gs.hire(here, 0) and gs.army.size() == Economy.SQUADS_BASE,
		"with no renown you lead %d squads and no more" % Economy.SQUADS_BASE)
	gs.renown = Economy.RENOWN_PER_SQUAD
	_expect(gs.squad_cap() == Economy.SQUADS_BASE + 1 and gs.hire(here, 0) and Economy.squad_cap(100000) == Economy.MAX_SQUADS,
		"renown raises the cap, a squad for every %d, up to %d" % [Economy.RENOWN_PER_SQUAD, Economy.MAX_SQUADS])
	gs.renown = 100000
	gs.world.offers["khalun"] = [{"type": Troops.ARCHERS, "culture": Cultures.KHARZANI}]
	_expect(gs.world.offers_at(here).is_empty() and not gs.hire(here, 0) and not gs.hire("khalun", 0),
		"an offer taken is gone, and you hire only where you stand")
	gs.world.wait(Economy.OFFER_REFRESH_HOURS + 1.0)
	gs.advance(Economy.OFFER_REFRESH_HOURS + 1.0)
	_expect(not gs.world.offers_at(here).is_empty(), "new recruits turn up %d hours later" % int(Economy.OFFER_REFRESH_HOURS))
	gs.free()


func _check_drill() -> void:
	var gs = _economy_campaign(23)
	gs.silver = 5000
	var s: Dictionary = gs.army[0]
	var full := Troops.full_size(s["type"])
	s["men"] = full / 2
	s["xp"] = Troops.XP_PER_LEVEL
	var cost: int = gs.reinforce_cost(s)
	_expect(cost == Economy.recruit_cost(s["type"], full - full / 2) and gs.reinforce() == cost and gs.silver == 5000 - cost \
			and int(s["men"]) == full and int(s["xp"]) == Troops.XP_PER_LEVEL / 2,
		"reinforcing pays %d silver for %d fresh men, who water down the squad's experience" % [cost, full - full / 2])
	s["xp"] = Troops.XP_PER_LEVEL
	var wage := Economy.daily_wage(s)
	var price := Economy.train_cost(s)
	var silver: int = gs.silver
	_expect(gs.can_train(s) and gs.train_squad(int(s["id"])) and int(s["level"]) == 2 and gs.silver == silver - price \
			and is_equal_approx(Economy.daily_wage(s), wage * (1.0 + Economy.WAGE_PER_LEVEL)),
		"training to level 2 costs %d silver, and half again in wages" % price)
	s["xp"] = Troops.XP_PER_LEVEL * 2
	_expect(gs.can_train(s) and absi(Economy.train_cost(s) - price * 2) <= 1 and not gs.can_train(gs.army[1]),
		"the next level costs twice as much, and needs the experience")
	var hours: float = gs.world.hours_to("kettlebrook")
	gs.world.travel("kettlebrook")
	gs.advance(hours + 0.01)
	s["men"] = full - 2
	_expect(gs.world.here() == "kettlebrook" and not gs.reinforce_squad(int(s["id"])) and not gs.train_squad(int(s["id"])),
		"in a village there's nobody to reinforce or drill you")
	gs.free()


func _check_spoils() -> void:
	var gs = GameStateScript.new()
	gs.persist = false
	gs.rng.seed = 24
	gs.new_campaign(Cultures.VARDISH)
	var band = gs.world.bands()[0]
	gs.world.encounter = band.id
	gs.start_encounter_battle()
	var silver: int = gs.silver
	var food: int = gs.food
	var got := Economy.spoils(30)
	gs.apply_result({"won": true, "killed": 30, "squads": {}})
	_expect(gs.silver == silver + got["silver"] and gs.food == food + got["food"] and gs.renown == got["renown"] \
			and gs.map_notice.contains("Spoils"),
		"beating a band of 30 pays %d silver, %d rations and %d renown" % [got["silver"], got["food"], got["renown"]])

	band = gs.world.bands()[0]
	gs.world.encounter = band.id
	gs.start_encounter_battle()
	var survivors := {}
	for sq in band.army:
		survivors[int(sq["id"])] = {"men": 0}
	survivors[int(band.army[0]["id"])] = {"men": 3}
	gs.apply_result({"won": false, "squads": {}, "enemy_squads": survivors})
	_expect(gs.world.party(band.id) != null and band.army.size() == 1 and int(band.army[0]["men"]) == 3,
		"a band that beats you keeps only the men it had left")
	gs.free()


# ---------------------------------------------------------------- auto-resolve

## A random army for checking auto-resolve against the full sim: up to eight squads,
## some worn down, some veteran. Small ones are bandit-sized.
func _random_army(rng: RandomNumberGenerator, base_id: int, small: bool) -> Array:
	var out := []
	var n := rng.randi_range(3, 5) if small else rng.randi_range(2, 8)
	for i in n:
		var type: String = Troops.ORDER[rng.randi_range(0, 3)]
		var men := rng.randi_range(8, 14) if small else maxi(4, int(Troops.full_size(type) * rng.randf_range(0.4, 1.0)))
		var level: int = 1 if small else [1, 1, 1, 2, 2, 3][rng.randi_range(0, 5)]
		out.append({"id": base_id + i, "type": type, "men": men, "xp": (level - 1) * Troops.XP_PER_LEVEL, "level": level,
			"captain": Captains.make(rng, base_id * 100 + i, type)})
	return out


func _men(army: Array) -> int:
	var n := 0
	for s in army:
		n += int(s["men"])
	return n


func _check_auto_resolve() -> void:
	var agree := 0
	# The share of its men the winner and the loser lost, summed: the full sim, auto-resolve.
	var winner_lost := [0.0, 0.0]
	var loser_lost := [0.0, 0.0]
	var shape_ok := true
	for i in CALIBRATION_BATTLES:
		var seed_value := 9000 + i
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value * 977
		var pa := _random_army(rng, 1, false)
		var ea := _random_army(rng, 500, rng.randf() < 0.5)
		var sim := Sim.new()
		sim.setup(pa, ea, seed_value)
		sim.ai = [Commander.new(Sim.PLAYER), Commander.new(Sim.ENEMY, "Reckless")]
		sim.ai[Sim.PLAYER].deploy(sim)
		sim.ai[Sim.ENEMY].deploy(sim)
		sim.start_battle()
		while sim.winner == -1 and sim.time < Sim.TIME_LIMIT + 5.0:
			sim.step()
		var sim_won := sim.winner == Sim.PLAYER
		var mine := float(sim.result_for(Sim.PLAYER)["lost"]) / _men(pa)
		var theirs := float(sim.result_for(Sim.ENEMY)["lost"]) / _men(ea)
		sim.dispose()
		winner_lost[0] += mine if sim_won else theirs
		loser_lost[0] += theirs if sim_won else mine
		var r := AutoResolve.resolve(pa, ea, rng, true)
		var auto_mine := float(r["lost"]) / _men(pa)
		var auto_theirs := float(r["killed"]) / _men(ea)
		winner_lost[1] += auto_mine if r["won"] else auto_theirs
		loser_lost[1] += auto_theirs if r["won"] else auto_mine
		if AutoResolve.odds(pa, ea)["player_wins"] == sim_won:
			agree += 1
		var back := 0
		for id in r["squads"]:
			back += int(r["squads"][id]["men"])
		if back + int(r["lost"]) != _men(pa) or r["squads"].size() != pa.size() or r["enemy_squads"].size() != ea.size():
			shape_ok = false
	var n := float(CALIBRATION_BATTLES)
	_expect(agree >= int(ceil(n * 0.85)), "the stronger side by auto-resolve's reckoning wins the full battle (%d of %d)" % [agree, CALIBRATION_BATTLES])
	_expect(absf(winner_lost[0] - winner_lost[1]) / n < 0.06 and absf(loser_lost[0] - loser_lost[1]) / n < 0.1,
		"and the losses come out about the same: winners lose %.0f%% in battle, %.0f%% settled; losers %.0f%% and %.0f%%" % [
			winner_lost[0] / n * 100.0, winner_lost[1] / n * 100.0, loser_lost[0] / n * 100.0, loser_lost[1] / n * 100.0])
	_expect(shape_ok, "a settled fight accounts for every man, and every squad on both sides")

	var mine_army := Plans.army(5)
	var foes := Plans.army(6)
	var led := 0
	var unled := 0
	var fell := 0
	for k in 40:
		var rng := RandomNumberGenerator.new()
		rng.seed = k
		led += int(AutoResolve.resolve(mine_army, foes, rng, true)["lost"])
		rng.seed = k
		var r := AutoResolve.resolve(mine_army, foes, rng, false)
		unled += int(r["lost"])
		for id in r["squads"]:
			if String(r["squads"][id].get("captain", {}).get("fate", "fine")) != "fine":
				fell += 1
	_expect(unled > led, "men sent in without you lose more (%d against %d over 40 even fights)" % [unled, led])
	_expect(fell > 0, "captains can fall in a settled fight too (%d times in 40)" % fell)


func _check_auto_encounter() -> void:
	var gs = GameStateScript.new()
	gs.persist = false
	gs.rng.seed = 25
	gs.new_campaign(Cultures.KHARZANI)
	var band = gs.world.bands()[0]
	for sq in band.army:
		sq["men"] = 2
	gs.world.encounter = band.id
	var silver: int = gs.silver
	var r: Dictionary = gs.auto_resolve_encounter()
	_expect(r.get("won", false) and gs.world.party(band.id) == null and gs.world.encounter == -1 and gs.silver > silver \
			and gs.renown > 0 and gs.battles == 1,
		"sending the men in against a broken band scatters it and pays the spoils")
	gs.free()


func _check_campaigns() -> void:
	var all_ok := true
	var grew := 0
	for s in range(1, CAMPAIGN_SEEDS + 1):
		var r := Plans.campaign(s, CAMPAIGN_DAYS)
		print("  seed %d  %3d men in %d squads (cap %d), %3d silver, %3d renown; won %d of %d; deserters on %d days, broke on %d" % [
			s, r["men"], r["squads"], r["cap"], r["silver"], r["renown"], r["won"], r["fights"], r["desertion_days"], r["broke_days"]])
		if r["men"] == 0 or r["lowest_men"] < 50 or r["desertion_days"] > 4 or r["broke_days"] > 5 or r["renown"] < 200:
			all_ok = false
		if r["squads"] > 5:
			grew += 1
	_expect(all_ok, "every warband lasts the month, never below 50 men, rarely short of pay or food, and makes a name")
	_expect(grew >= CAMPAIGN_SEEDS - 1, "and most grow (%d of %d lead more squads than they started with)" % [grew, CAMPAIGN_SEEDS])


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
