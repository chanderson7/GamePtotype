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
const Terrain = preload("res://scripts/battle/terrain.gd")
const BattleSite = preload("res://scripts/battle/battle_site.gd")
const MapTerrain = preload("res://scripts/world/map_terrain.gd")
const Lords = preload("res://scripts/data/lords.gd")
const TerrainRules = preload("res://scripts/data/terrain_rules.gd")
const Units = preload("res://scripts/data/units.gd")
const UnitArt = preload("res://scripts/art/unit_art.gd")

const DUEL_SEEDS := 12
const BRANCH_SEEDS := 4
## Attacking into good ground: battles per commander on each kind of ground, how much
## stronger the attacker is, and how many points less often it should win there than on
## open ground. 24 battles a commander: with 8, chance alone moved the result about 7
## points either way, and one unlucky draw read 8 points where the ground is worth 21.
const TERRAIN_SEEDS := 24
const TERRAIN_ATTACKER := 1.15
const TERRAIN_POINTS := 15.0
## Objectives: battles per commander, and how many points more often playing to them
## should win than pressing Advance all.
const OBJECTIVE_SEEDS := 8
const OBJECTIVE_POINTS := 15.0
const BATTLE_SEEDS := 6
const BALANCE_SEEDS := 12
## Battles of the full sim that auto-resolve is checked against, and scripted campaigns.
const CALIBRATION_BATTLES := 16
const CAMPAIGN_SEEDS := 6
const CAMPAIGN_DAYS := 30

var failures := 0


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--world"):
		print("World:")
		_check_map()
		_check_travel()
		_check_encounters()
		_check_world_saves()
		_check_realms()
		_check_garrisons()
		_check_sieges()
		_check_lords()
		print("FAILURES: %d" % failures)
		quit(1 if failures > 0 else 0)
		return

	print("Deployment:")
	_check_deployment()

	print("Orders:")
	_check_orders()
	_check_arrows()
	_check_lines()
	_check_hold_fire()

	print("Tactics:")
	_check_flanks()
	_check_brace()
	_check_steering()

	print("Terrain:")
	_check_terrain()

	print("Abilities:")
	_check_shield_wall()
	_check_schiltron()
	_check_volley()
	_check_wheel()

	print("Commanders:")
	_check_commanders()

	print("Cultures:")
	_check_cultures()

	print("Units & Troop Trees:")
	_check_units()

	print("Objectives & Encounter Variety:")
	_check_objectives()

	print("World:")
	_check_map()
	_check_travel()
	_check_encounters()
	_check_world_saves()
	_check_realms()
	_check_garrisons()
	_check_sieges()
	_check_lords()
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
		_check_terrain_matters()
		_check_objective_plans()
		_check_branches()

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


func _check_lines() -> void:
	# Three squads standing left to right; a line drawn right to left, nearer the enemy.
	var sim := Sim.new()
	var army := [{"id": 1, "type": Troops.INFANTRY, "men": 20}, {"id": 2, "type": Troops.SPEARMEN, "men": 20},
		{"id": 3, "type": Troops.ARCHERS, "men": 20}]
	sim.setup(army, [{"id": 9, "type": Troops.INFANTRY, "men": 20}], 1)
	for i in 3:
		sim.place(Sim.PLAYER, i + 1, Vector2(150.0 + 270.0 * i, 1000.0))
	sim.place(Sim.ENEMY, 9, Vector2(420.0, 100.0))
	sim.start_battle()
	var a := Vector2(700, 880)
	var b := Vector2(140, 880)
	var spots := sim.order_line(Sim.PLAYER, a, b)
	var in_order := spots.size() == 3
	var apart := true
	for i in range(1, spots.size()):
		var prev: Dictionary = spots[i - 1]
		var cur: Dictionary = spots[i]
		# The first spot is at the line's start (the right), and each squad keeps its place.
		if prev["squad"].center.x < cur["squad"].center.x or Vector2(prev["at"]).x < Vector2(cur["at"]).x:
			in_order = false
		var need: float = Vector2(prev["half"]).x + Vector2(cur["half"]).x + Sim.LINE_GAP - 0.5
		if Vector2(prev["at"]).distance_to(cur["at"]) < need:
			apart = false
	var mid: Vector2 = (Vector2(spots[0]["at"]) + Vector2(spots[2]["at"])) * 0.5
	_expect(in_order and apart and mid.distance_to((a + b) * 0.5) < 30.0,
		"a line shares itself out in the order the squads stand, without overlaps, centered where it was drawn")
	for i in 30 * 25:
		sim.step()
	var formed := true
	for spot in spots:
		var sq = spot["squad"]
		if sq.center.distance_to(spot["at"]) > 8.0 or sq.order != "hold" or sq.facing.dot(Vector2.UP) < 0.97:
			formed = false
	_expect(formed, "the squads march to their places on it and hold there, facing the enemy across it")
	var inf = sim.placed_squad(Sim.PLAYER, 1)
	var spacing: float = inf.radius * 2.0 + 5.0
	var wide := sim.line_spots([inf], Vector2(100, 800), Vector2(280, 800))
	var deep := sim.line_spots([inf], Vector2(100, 800), Vector2(125, 800))
	var longest := sim.line_spots([inf], Vector2(0, 800), Vector2(800, 800))
	var usual := sim._files(20)
	_expect(int(wide[0]["files"]) > usual and absf(Vector2(wide[0]["half"]).x * 2.0 - 180.0) < spacing
			and int(deep[0]["files"]) < usual and int(deep[0]["files"]) >= 2 and int(longest[0]["files"]) == 10,
		"one squad alone fills the line: %d men wide for a long one, %d for a short one (usually %d), never under two ranks" % [
			int(wide[0]["files"]), int(deep[0]["files"]), usual])
	sim.order_line(Sim.PLAYER, Vector2(100, 800), Vector2(280, 800), inf)
	var spread := 0.0
	for so in inf.soldiers:
		if so.alive:
			spread = maxf(spread, absf(so.slot.x))
	_expect(inf.files == int(wide[0]["files"]) and spread * 2.0 > (usual - 1) * spacing + spacing * 0.5,
		"and its men re-form to that width")
	sim.dispose()

	# Before the battle, a line places the whole army at once, squads not yet placed too,
	# just where the preview drawn while dragging showed them.
	sim = Sim.new()
	sim.setup(army, [{"id": 9, "type": Troops.INFANTRY, "men": 20}], 2)
	sim.place(Sim.PLAYER, 2, Vector2(420.0, 1100.0))
	var shown := sim.line_preview(Sim.PLAYER, Vector2(150, 950), Vector2(690, 950))
	var still: bool = sim.placed_squad(Sim.PLAYER, 2).center == Vector2(420.0, 1100.0) and not sim.all_placed(Sim.PLAYER)
	spots = sim.order_line(Sim.PLAYER, Vector2(150, 950), Vector2(690, 950))
	var placed: bool = sim.all_placed(Sim.PLAYER) and spots.size() == 3 and shown.size() == 3 and still
	for i in spots.size():
		var spot: Dictionary = spots[i]
		if absf(spot["squad"].center.y - 950.0) > 1.0 or not sim.deploy_zone(Sim.PLAYER).has_point(spot["squad"].center):
			placed = false
		if Vector2(shown[i]["at"]).distance_to(spot["squad"].center) > 0.5:
			placed = false
	_expect(placed, "before the battle, a line places the whole army on it at once, where the preview showed")
	# A line drawn in the enemy's half is kept to your own.
	spots = sim.order_line(Sim.PLAYER, Vector2(150, 300), Vector2(690, 300))
	var kept := true
	for spot in spots:
		if not sim.deploy_zone(Sim.PLAYER).has_point(spot["squad"].center):
			kept = false
	_expect(kept, "and a line drawn in the enemy's half stays in yours")
	sim.dispose()


func _check_hold_fire() -> void:
	var sim := Sim.new()
	sim.setup([{"id": 1, "type": Troops.ARCHERS, "men": 20}], [{"id": 2, "type": Troops.INFANTRY, "men": 20}], 3)
	sim.place(Sim.PLAYER, 1, Vector2(420, 1000))
	sim.place(Sim.ENEMY, 2, Vector2(420, 520))
	sim.start_battle()
	var bows = sim.placed_squad(Sim.PLAYER, 1)
	var foot = sim.placed_squad(Sim.ENEMY, 2)
	var arrows: int = bows.arrows
	sim.set_hold_fire(bows, true)
	sim.order_advance(foot)
	var met := false
	for i in 30 * 30:
		sim.step()
		met = met or bows.engaged
		if sim.winner != -1:
			break
	var hurt := 0.0
	for so in foot.soldiers:
		hurt += so.max_hp - maxf(0.0, so.hp) if so.alive else so.max_hp
	_expect(bows.arrows == arrows and met and hurt > 0.0,
		"archers holding fire keep every arrow, and fight with blades when the enemy reaches them")
	sim.dispose()

	sim = Sim.new()
	sim.setup([{"id": 1, "type": Troops.ARCHERS, "men": 20}], [{"id": 2, "type": Troops.INFANTRY, "men": 20}], 4)
	sim.place(Sim.PLAYER, 1, Vector2(420, 1000))
	sim.place(Sim.ENEMY, 2, Vector2(420, 560))
	sim.start_battle()
	bows = sim.placed_squad(Sim.PLAYER, 1)
	sim.placed_squad(Sim.ENEMY, 2).center = Vector2(420, 800)
	sim._move_formation(sim.placed_squad(Sim.ENEMY, 2), Vector2(420, 800))
	sim.set_hold_fire(bows, true)
	for i in 30:
		sim.step()
	var kept: int = bows.arrows
	var loosed := sim.use_ability(bows)
	for i in 60:
		sim.step()
	_expect(kept == arrows and loosed and not bows.hold_fire and bows.arrows < kept,
		"a volley ends the hold: the bows loose at once")
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


# ---------------------------------------------------------------- terrain

func _check_terrain() -> void:
	# 1. Uphill attackers lose more
	var hill_t := Terrain.new()
	hill_t.reset()
	for cy in Terrain.ROWS:
		for cx in Terrain.COLS:
			var p := hill_t.cell_pos(cx, cy)
			var d := p.distance_to(Vector2(420.0, 780.0))
			if d < 280.0:
				var f := 1.0 - (d / 280.0)
				hill_t.height[cy * Terrain.COLS + cx] = 0.85 * (f * f * (3.0 - 2.0 * f))

	var downhill_defender_wins := 0
	for s in range(1, 13):
		var sim := Sim.new()
		sim.setup([{"id": 1, "type": Troops.INFANTRY, "men": 20}], [{"id": 2, "type": Troops.INFANTRY, "men": 20}], s, hill_t)
		sim.place(Sim.PLAYER, 1, Vector2(420.0, 780.0))
		sim.place(Sim.ENEMY, 2, Vector2(420.0, 480.0))
		sim.start_battle()
		sim.order_all(Sim.PLAYER, "hold")
		sim.order_all(Sim.ENEMY, "advance")
		while sim.winner == -1 and sim.time < Sim.TIME_LIMIT:
			sim.step()
		if sim.winner == Sim.PLAYER:
			downhill_defender_wins += 1
		sim.dispose()
	_expect(downhill_defender_wins >= 10, "downhill defenders beat uphill attackers (%d/12)" % downhill_defender_wins)

	# 2. Arrows into woods hit about half as often
	var woods_t := Terrain.new()
	woods_t.reset()
	for cy in range(20, Terrain.ROWS):
		for cx in Terrain.COLS:
			woods_t.woods[cy * Terrain.COLS + cx] = Terrain.WOODS_TREES

	var hits_open := 0
	var hits_woods := 0
	for in_woods in [false, true]:
		var sim := Sim.new()
		sim.setup([{"id": 1, "type": Troops.INFANTRY, "men": 20}], [{"id": 2, "type": Troops.ARCHERS, "men": 20}], 42, woods_t if in_woods else null)
		sim.place(Sim.PLAYER, 1, Vector2(420.0, 800.0))
		sim.place(Sim.ENEMY, 2, Vector2(420.0, 500.0))
		sim.start_battle()
		sim.order_all(Sim.PLAYER, "hold")
		sim.order_all(Sim.ENEMY, "hold")
		for step_i in 300:
			sim.step()
		var p_sq = sim.squads[0] if sim.squads[0].team == Sim.PLAYER else sim.squads[1]
		var total_hp_lost := 0.0
		for so in p_sq.soldiers:
			total_hp_lost += (so.max_hp - so.hp)
		if in_woods:
			hits_woods = int(total_hp_lost)
		else:
			hits_open = int(total_hp_lost)
		sim.dispose()
	_expect(hits_woods < hits_open * 0.70 and hits_woods > 0,
		"woods cover shelters from arrows (woods dmg %d vs open %d)" % [hits_woods, hits_open])

	# 3. Charges into woods do no charge damage
	var charge_woods_t := Terrain.new()
	charge_woods_t.reset()
	for cy in range(20, Terrain.ROWS):
		for cx in Terrain.COLS:
			charge_woods_t.woods[cy * Terrain.COLS + cx] = Terrain.WOODS_TREES
	var charge_sim := Sim.new()
	charge_sim.setup([{"id": 1, "type": Troops.INFANTRY, "men": 20}], [{"id": 2, "type": Troops.CAVALRY, "men": 20}], 42, charge_woods_t)
	charge_sim.place(Sim.PLAYER, 1, Vector2(420.0, 800.0))
	charge_sim.place(Sim.ENEMY, 2, Vector2(420.0, 480.0))
	charge_sim.start_battle()
	charge_sim.order_all(Sim.PLAYER, "hold")
	charge_sim.order_all(Sim.ENEMY, "advance")
	var had_charge := false
	while charge_sim.time < 15.0 and charge_sim.winner == -1:
		charge_sim.step()
		for ev in charge_sim.events:
			if ev.get("type") == "charge":
				had_charge = true
	_expect(not had_charge, "cavalry charge into woods triggers no charge shock")
	charge_sim.dispose()

	# 4. Fords slow troops
	var river_t := Terrain.new()
	river_t.reset()
	for cy in range(19, 23):
		for cx in Terrain.COLS:
			river_t.water[cy * Terrain.COLS + cx] = Terrain.WATER_SHALLOW
	var open_sim := Sim.new()
	open_sim.setup([{"id": 1, "type": Troops.INFANTRY, "men": 20}], [{"id": 2, "type": Troops.INFANTRY, "men": 20}], 1)
	open_sim.place(Sim.PLAYER, 1, Vector2(420.0, 800.0))
	open_sim.place(Sim.ENEMY, 2, Vector2(420.0, 460.0))
	open_sim.start_battle()
	open_sim.order_move(open_sim.squads[0], Vector2(420.0, 630.0))
	while open_sim.squads[0].center.y > 640.0 and open_sim.time < 30.0:
		open_sim.step()
	var time_open := open_sim.time
	open_sim.dispose()

	var ford_sim := Sim.new()
	ford_sim.setup([{"id": 1, "type": Troops.INFANTRY, "men": 20}], [{"id": 2, "type": Troops.INFANTRY, "men": 20}], 1, river_t)
	ford_sim.place(Sim.PLAYER, 1, Vector2(420.0, 800.0))
	ford_sim.place(Sim.ENEMY, 2, Vector2(420.0, 460.0))
	ford_sim.start_battle()
	ford_sim.order_move(ford_sim.squads[0], Vector2(420.0, 630.0))
	while ford_sim.squads[0].center.y > 640.0 and ford_sim.time < 30.0:
		ford_sim.step()
	var time_ford := ford_sim.time
	ford_sim.dispose()
	_expect(time_ford > time_open * 1.25, "fords slow crossing troops (%.1fs vs %.1fs)" % [time_ford, time_open])

	# 5. Men in fords take more damage: the same braced defence, on dry ground and with the
	# defenders standing in a ford.
	var ford_vuln_t := Terrain.new()
	ford_vuln_t.reset()
	for cy in range(22, 30):
		for cx in Terrain.COLS:
			ford_vuln_t.water[cy * Terrain.COLS + cx] = Terrain.WATER_SHALLOW
	var held := [0, 0]
	for wet in [0, 1]:
		for s in range(1, 13):
			var sim := Sim.new()
			sim.setup([{"id": 1, "type": Troops.INFANTRY, "men": 20}], [{"id": 2, "type": Troops.INFANTRY, "men": 20}], s,
				ford_vuln_t if wet == 1 else null)
			sim.place(Sim.PLAYER, 1, Vector2(420.0, 720.0))
			sim.place(Sim.ENEMY, 2, Vector2(420.0, 480.0))
			sim.start_battle()
			sim.order_all(Sim.ENEMY, "advance")
			while sim.winner == -1 and sim.time < Sim.TIME_LIMIT:
				sim.step()
			if sim.winner == Sim.PLAYER:
				held[wet] += 1
			sim.dispose()
	_expect(held[1] <= held[0] - 6, "men fighting in a ford take more damage (a braced line holds %d/12 on dry ground, %d/12 in the water)" % [held[0], held[1]])

	# 6. Pathing: A squad crosses a river only at a ford and arrives
	var river_path_t := Terrain.new()
	river_path_t.reset()
	# Single ford at center x in [375, 465], everywhere else in rows 19..22 is deep water
	for cy in range(19, 23):
		for cx in Terrain.COLS:
			var cp := river_path_t.cell_pos(cx, cy)
			if absf(cp.x - 420.0) <= 45.0:
				river_path_t.water[cy * Terrain.COLS + cx] = Terrain.WATER_SHALLOW
			else:
				river_path_t.water[cy * Terrain.COLS + cx] = Terrain.WATER_DEEP

	var path_sim := Sim.new()
	path_sim.setup([{"id": 1, "type": Troops.INFANTRY, "men": 20}], [{"id": 2, "type": Troops.INFANTRY, "men": 20}], 1, river_path_t)
	path_sim.place(Sim.PLAYER, 1, Vector2(180.0, 850.0))
	path_sim.place(Sim.ENEMY, 2, Vector2(180.0, 400.0))
	path_sim.start_battle()
	path_sim.order_move(path_sim.squads[0], Vector2(180.0, 400.0))
	path_sim.order_all(Sim.ENEMY, "hold")

	var stepped_in_deep_water := false
	while path_sim.time < 50.0 and path_sim.squads[0].center.y > 440.0:
		path_sim.step()
		for so in path_sim.squads[0].soldiers:
			if so.alive and river_path_t.water_at(so.pos) == Terrain.WATER_DEEP:
				stepped_in_deep_water = true

	var arrived: bool = path_sim.squads[0].center.y <= 440.0
	path_sim.dispose()
	_expect(arrived and not stepped_in_deep_water, "squad routes through the river ford to destination without entering deep water")

	# 7. Pathing: Nothing ever stands in deep water or rock across varied battles, and
	# routers still get off the field.
	var any_impassable_stand := false
	var fought := 0
	var fled := 0
	var field := Rect2(Vector2.ZERO, Sim.ARENA)
	for site_type in [BattleSite.TYPE_RIVER, BattleSite.TYPE_PASS, BattleSite.TYPE_VILLAGE]:
		for s in range(1, 4):
			var site_t := BattleSite.generate({"type": site_type, "seed": s, "fair": true})
			var test_sim := Sim.new()
			test_sim.setup(
				[{"id": 1, "type": Troops.INFANTRY, "men": 20}, {"id": 2, "type": Troops.CAVALRY, "men": 16}],
				[{"id": 3, "type": Troops.INFANTRY, "men": 20}, {"id": 4, "type": Troops.ARCHERS, "men": 20}],
				s,
				site_t
			)
			test_sim.auto_deploy(Sim.PLAYER)
			test_sim.auto_deploy(Sim.ENEMY)
			test_sim.start_battle()
			test_sim.order_all(Sim.PLAYER, "advance")
			test_sim.order_all(Sim.ENEMY, "advance")
			while test_sim.winner == -1 and test_sim.time < Sim.TIME_LIMIT:
				test_sim.step()
				for sq in test_sim.squads:
					for so in sq.soldiers:
						if so.alive and field.has_point(so.pos) and not site_t.passable(so.pos):
							any_impassable_stand = true
			for i in 300:
				test_sim.step()
			for sq in test_sim.squads:
				fought += sq.start_men
				fled += sq.escaped
			test_sim.dispose()
	_expect(fought > 0 and not any_impassable_stand, "no soldier stands on impassable rock or deep water (%d men fought)" % fought)
	_expect(fled > 0, "and men who rout still get off the field (%d fled)" % fled)

	# 8. Terrain matters: see _check_terrain_matters, with --balance.

	# 9. Performance: what a sim step costs per man on the field, in the first 30 seconds of
	# 6 battles on each kind of ground, against the same battles on open ground. Per man,
	# because armies that take longer to meet (round rocks, across a river) still have more
	# men alive at 30 seconds, and every man costs the same on any ground. The kinds take
	# turns battle by battle, so the machine speeding up or slowing down partway through
	# doesn't count against one of them, and each battle is timed twice and the faster run
	# counts, so a hiccup doesn't either.
	var grounds := ["", BattleSite.TYPE_HILLS, BattleSite.TYPE_WOODS, BattleSite.TYPE_RIVER, BattleSite.TYPE_PASS]
	var usec := {}
	var steps := {}
	for g in grounds:
		usec[g] = 0
		steps[g] = 0
	for s in range(1, 7):
		for g in grounds:
			var fastest := -1
			var ran := 0
			var men_steps := 0
			for attempt in 2:
				var sim := Sim.new()
				sim.setup(Plans.army(s), Plans.army(s + 1000), s, BattleSite.generate({"type": g, "seed": s, "fair": true}) if g != "" else null)
				sim.ai = [Commander.new(Sim.PLAYER), Commander.new(Sim.ENEMY)]
				sim.ai[Sim.PLAYER].deploy(sim)
				sim.ai[Sim.ENEMY].deploy(sim)
				sim.start_battle()
				ran = 0
				men_steps = 0
				var took := 0
				while sim.winner == -1 and sim.time < 30.0:
					var t0 := Time.get_ticks_usec()
					sim.step()
					took += Time.get_ticks_usec() - t0
					ran += 1
					for sq in sim.squads:
						men_steps += sq.alive_n
				fastest = took if fastest < 0 else mini(fastest, took)
				sim.dispose()
			usec[g] += fastest
			steps[g] += men_steps
	# Per man-step, and an average step on open ground for scale.
	var open_step := float(usec[""]) / maxi(1, steps[""])
	var worst := 0.0
	var each := PackedStringArray()
	for g in grounds:
		if g == "":
			continue
		var over := (float(usec[g]) / maxi(1, steps[g])) / open_step - 1.0
		worst = maxf(worst, over)
		each.append("%s %+.0f%%" % [g, over * 100.0])
	_expect(worst <= 0.25, "a sim step on rough ground costs at most 25%% more per man than on open ground (%.1f µs a man open; %s)" % [
		open_step, ", ".join(each)])


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


# ---------------------------------------------------------------- units & troop trees

func _check_units() -> void:
	# 0. Every trained branch wears its own kit, on the field and in its portrait.
	var dressed := true
	for id in Units.UNITS:
		if Units.tier(id) < 2:
			continue
		var recruit := String(Units.UNITS[id]["branch_of"])
		if UnitArt.sprite_name(id, "") != id or UnitArt.icon(id).get_image().get_data() == UnitArt.icon(recruit).get_image().get_data():
			dressed = false
	_expect(dressed, "every trained branch has its own sprite and portrait, unlike its recruit's")
	# 1. Matchup duels: each new unit wins the fight it was made for.
	var matchups := [
		["vardish_crossbowmen", "vardish_men_at_arms", false, "crossbowmen pierce armored men-at-arms"],
		["vardish_knights", "vardish_infantry", false, "knights charge crushes standard infantry"],
		["vardish_pikemen", "vardish_knights", true, "braced pikemen stop knights cold"],
		["kharzani_horse_archers", "vardish_infantry", false, "horse archers skirmish down footmen"],
		["kharzani_javelin_askari", "kharzani_spearmen", false, "javelin askari weaken and break spearmen"],
		["ryumon_hatamoto", "vardish_infantry", false, "elite hatamoto best standard footmen"],
		["ryumon_naginata", "vardish_cavalry", true, "naginata sweep and anti-cav bonus cuts horse down"],
	]
	for m in matchups:
		var wins := 0
		for s in range(1, DUEL_SEEDS + 1):
			if _unit_duel(m[0], m[1], s, m[2])["winner"] == Sim.PLAYER:
				wins += 1
		_expect(wins >= int(DUEL_SEEDS * 0.8), "%s (%d/%d)" % [m[3], wins, DUEL_SEEDS])

	# Halberdiers are still spearmen, and footmen still beat spearmen, but the sweep makes
	# them pay for it.
	var standing := [0, 0]
	for s in range(1, DUEL_SEEDS + 1):
		standing[0] += _unit_duel("vardish_spearmen", "vardish_infantry", s)["foe_left"]
		standing[1] += _unit_duel("vardish_halberdiers", "vardish_infantry", s)["foe_left"]
	_expect(standing[1] <= standing[0] * 0.7,
		"halberdiers' sweep cuts through footmen (%.1f footmen left standing, against %.1f facing plain spearmen)" % [
			float(standing[1]) / DUEL_SEEDS, float(standing[0]) / DUEL_SEEDS])

	# 2. Branch choices balance: see _check_branches, with --balance.

	# 3. Save migration (version 3 to 4)
	var gs := GameStateScript.new()
	gs.persist = false
	var old_save := {
		"version": 3, "culture": Cultures.VARDISH, "battles": 5, "silver": 600,
		"army": [
			{"id": 1, "type": Troops.INFANTRY, "men": 20, "xp": 0, "level": 1},
			{"id": 2, "type": Troops.CAVALRY, "men": 16, "xp": 45, "level": 2},
		]
	}
	gs.from_dict(old_save)
	_expect(gs.army[0]["unit"] == "vardish_infantry" and not gs.army[0].get("pending_branch", false),
		"migrated tier 1 squad assigned recruit unit without pending branch")
	_expect(gs.army[1]["unit"] == "vardish_cavalry" and gs.army[1].get("pending_branch", false),
		"migrated level 2 squad marked pending branch choice")
	gs.free()

	# 4. Training branches and costs
	var gs_train := GameStateScript.new()
	gs_train.persist = false
	gs_train.new_campaign(Cultures.VARDISH)
	var squad = gs_train.army[0] # Vardish infantry
	squad["xp"] = 30
	var branches: Array = Units.branches(squad["unit"])
	var choice_a: String = branches[0]
	var cost_a := Economy.train_cost(squad, choice_a)
	var silver_before := gs_train.silver
	var trained := gs_train.train_squad(int(squad["id"]), choice_a)
	_expect(trained and squad["unit"] == choice_a and squad["level"] == 2 and gs_train.silver == silver_before - cost_a,
		"training squad to branch %s upgrades unit and charges %d silver" % [Units.display_name(choice_a), cost_a])
	gs_train.free()


func _unit_duel(a: String, b: String, seed_value: int, a_holds: bool = false) -> Dictionary:
	var role_a: String = Units.role(a) if Units.has(a) else a
	var role_b: String = Units.role(b) if Units.has(b) else b
	var size_a: int = Units.full_size(a) if Units.has(a) else Troops.full_size(a)
	var size_b: int = Units.full_size(b) if Units.has(b) else Troops.full_size(b)
	var sim := Sim.new()
	sim.setup(
		[{"id": 1, "type": role_a, "unit": a, "men": size_a, "level": Units.tier(a)}],
		[{"id": 2, "type": role_b, "unit": b, "men": size_b, "level": Units.tier(b)}],
		seed_value
	)
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
	var foe_left := 0
	for sq in sim.squads:
		if sq.team == Sim.PLAYER:
			left = sq.alive_count()
		else:
			foe_left = sq.alive_count()
	var winner := sim.winner
	sim.dispose()
	return {"winner": winner, "left": left, "foe_left": foe_left}


## Each pair of tier-2 branches against every kind of recruit. A branch that wins far more
## of these fights than its twin would make the choice between them no choice at all.
func _check_branches() -> void:
	print("Troop tree branches against every kind of recruit (%d seeds each):" % BRANCH_SEEDS)
	for cult in Cultures.ORDER:
		for role in Troops.ORDER:
			var branches: Array = Units.branches(Units.recruit(cult, role))
			if branches.size() != 2:
				continue
			var won := [0, 0]
			for i in 2:
				for foe in Troops.ORDER:
					for s in range(1, BRANCH_SEEDS + 1):
						if _unit_duel(branches[i], Units.recruit(cult, foe), s)["winner"] == Sim.PLAYER:
							won[i] += 1
			var share := float(won[0]) / maxf(1.0, float(won[0] + won[1]))
			_expect(share >= 0.35 and share <= 0.65, "%s (%d of %d fights won) and %s (%d) are both real choices" % [
				Units.display_name(branches[0]), won[0], Troops.ORDER.size() * BRANCH_SEEDS,
				Units.display_name(branches[1]), won[1]])


# ---------------------------------------------------------------- world

## A world with no bandits in it, so travel checks aren't interrupted.
func _quiet_world(seed_value: int) -> WorldSim:
	var w := WorldSim.new()
	w.setup(seed_value, Cultures.VARDISH)
	# No bandits on the roads; the lords still ride.
	w.parties = w.parties.filter(func(p): return p.kind != WorldSim.BAND)
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
	var bound_ok := true
	var holds := {}
	for id in WorldData.SETTLEMENTS:
		var s: Dictionary = WorldData.SETTLEMENTS[id]
		if s["type"] == WorldData.VILLAGE:
			var lord := String(s.get("bound_to", ""))
			if not WorldData.SETTLEMENTS.has(lord) or WorldData.SETTLEMENTS[lord]["type"] == WorldData.VILLAGE \
					or WorldData.SETTLEMENTS[lord]["faction"] != s["faction"]:
				bound_ok = false
			holds[lord] = true
	for id in WorldData.SETTLEMENTS:
		if WorldData.SETTLEMENTS[id]["type"] != WorldData.VILLAGE and not holds.has(id):
			bound_ok = false
	_expect(bound_ok, "every village belongs to a castle or town of its realm, and every castle and town has a village")
	_check_rivers()


func _check_rivers() -> void:
	var courses_ok := true
	for r in WorldData.RIVERS:
		var pts: Array = r["points"]
		var at_sea := false
		for k in pts.size() - 1:
			for i in 11:
				var wet: bool = WorldData.land_at(pts[k].lerp(pts[k + 1], i / 10.0)) == -1
				if at_sea and not wet or k < pts.size() - 2 and wet:
					courses_ok = false
				at_sea = at_sea or wet
		courses_ok = courses_ok and at_sea
	_expect(courses_ok, "every river runs over land from its source to the sea")
	var forded := {}
	for f in WorldData.fords():
		forded[f["river"]] = true
	_expect(forded.size() == WorldData.RIVERS.size(), "a road crosses every river, at a ford (%d fords)" % WorldData.fords().size())
	var at_fords := true
	for f in WorldData.fords():
		for s in 6:
			var site := BattleSite.pick(null, f["pos"], "rout", s)
			if site["type"] != BattleSite.TYPE_RIVER or site.get("river", "") != f["river"]:
				at_fords = false
	var dry := true
	for id in WorldData.SETTLEMENTS:
		if WorldData.nearest_river(WorldData.pos(id))["distance"] < 80.0:
			continue
		for s in 6:
			if BattleSite.pick(null, WorldData.pos(id), "rout", s)["type"] == BattleSite.TYPE_RIVER:
				dry = false
	_expect(at_fords and dry, "a fight at a ford is fought across that river, and one far from water never is")
	var clear := true
	for d in MapTerrain.shared().decor:
		if not MapTerrain.FIELDS.values().has(d["name"]) and WorldData.nearest_river(d["pos"])["distance"] < MapTerrain.CLEAR_OF_RIVERS:
			clear = false
	_expect(clear, "no tree, peak or dune stands in a river")


func _check_travel() -> void:
	var w := _quiet_world(2)
	var hours := w.hours_to("khalun")
	var set_out := w.hour
	w.travel("khalun")
	w.step(hours)
	_expect(w.here() == "khalun" and absf(w.hour - set_out - hours) < 0.01,
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


## Who holds what, and who is at war, are the world's to change, and kept in its saves.
func _check_realms() -> void:
	var w := _quiet_world(3)
	var start_ok := true
	for id in WorldData.SETTLEMENTS:
		start_ok = start_ok and w.owner_of(id) == WorldData.SETTLEMENTS[id]["faction"]
	_expect(start_ok and w.at_war("vardmark", "kharzan") and not w.at_war("ryumon", "vardmark")
		and not w.at_war("kharzan", "ryumon") and w.at_war("ryumon", WorldData.BANDITS),
		"a campaign starts with the map's owners and wars: Vardmark and Kharzan at war, the isles at peace")

	w.set_owner("ravensford", "kharzan")
	var moved := w.owner_of("ravensford") == "kharzan" and w.owner_of("thornwall") == "kharzan" \
		and not w.villages_of("vardmark").has("thornwall") and w.villages_of("kharzan").has("thornwall") \
		and w.describe("ravensford").begins_with("Castle of the Sultanate of Kharzan · Vardish")
	_expect(moved, "a castle that changes hands takes its villages with it, and its people stay who they were")
	w.set_owner("highcliff", "kharzan")
	var seat := w.capital_of("vardmark")
	_expect(seat == "marchgate" and w.owner_of("ashby") == "kharzan" and w.home() == "marchgate",
		"a realm that loses its capital rules from what it has left, and your warband regroups there (%s)" % seat)
	for id in w.villages_of("vardmark"):
		w.set_owner(id, "kharzan")
	w.set_owner("marchgate", "kharzan")
	w._spawn_band("vardmark")
	_expect(w.bands().is_empty() and w.capital_of("vardmark") == "" and w.home() == "highcliff",
		"a realm with nothing left raises no bandits, and has no seat")

	w.make_peace("vardmark", "kharzan")
	w.declare_war("ryumon", "kharzan")
	var kinds := w.events.map(func(e): return e["type"])
	_expect(not w.at_war("kharzan", "vardmark") and w.at_war("kharzan", "ryumon") and kinds.has("captured")
		and kinds.has("peace") and kinds.has("war"), "realms make peace and go to war, and the world says so")

	var saved := JSON.stringify(w.to_dict())
	var copy := WorldSim.new()
	copy.from_dict(JSON.parse_string(saved))
	_expect(JSON.stringify(copy.to_dict()) == saved and copy.owner_of("highcliff") == "kharzan"
		and copy.at_war("ryumon", "kharzan") and copy.capital_of("vardmark") == "",
		"owners, wars and capitals are saved and load back")

	# A save from before places could change hands: version 4, made by the game as it was.
	var gs = GameStateScript.new()
	gs.persist = false
	var old = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/save_v4.json"))
	var loaded: bool = gs.from_dict(old)
	var as_map := true
	for id in WorldData.SETTLEMENTS:
		as_map = as_map and gs.world.owner_of(id) == WorldData.SETTLEMENTS[id]["faction"]
	var men: int = gs.total_men()
	gs.world.travel("nahrabad")
	gs.advance(30.0)
	_expect(int(old["version"]) == 4 and loaded and as_map and gs.world.at_war("kharzan", "vardmark")
		and gs.world.capital_of("kharzan") == "khalun" and men > 0 and gs.world.hour > float(old["world"]["hour"]),
		"a version-4 save loads into the map's first owners and wars, and plays on")
	gs.free()


## Standing guards grow once a day, paid by their owner, and survive saving and losses.
func _check_garrisons() -> void:
	var w := _quiet_world(43)
	var ids := {}
	var valid := w.garrisons.size() == 9
	for id in WorldData.SETTLEMENTS:
		if WorldData.is_village(id):
			valid = valid and w.garrison_at(id).is_empty() and w.garrison_capacity(id) == 0
			continue
		var army := w.garrison_at(id)
		valid = valid and w.men_of(army) == int(w.garrison_capacity(id) * Lords.GARRISON_START_SHARE)
		valid = valid and w.describe(id).contains("garrison %d/" % w.men_of(army))
		for sq in army:
			valid = valid and not ids.has(sq["id"]) and Units.has(String(sq["unit"])) \
				and sq["culture"] == WorldData.culture_of(WorldData.settlement(id)["faction"])
			ids[sq["id"]] = true
	var castle := w.garrison_at("ravensford")
	var town := w.garrison_at("highcliff")
	_expect(valid and w.men_of(town) > w.men_of(castle)
		and AutoResolve.strength(castle, []) / w.men_of(castle) > AutoResolve.strength(town, []) / w.men_of(town),
		"nine castles and towns have local guards with unique ids; towns hold more, castles have stronger men")

	# A quiet treasury makes the daily clock and exact recruit bill observable.
	w.lords = []
	w.parties = [w.player()]
	var start := w.men_of(castle)
	w.step(24.0)
	var idle := w.men_of(castle) == start
	w.wait(15.75)
	w.step(15.75)
	var before_midnight := w.men_of(castle) == start
	var before := w.garrisons.duplicate(true)
	var purse := int(w.realms["vardmark"]["treasury"])
	w.wait(0.25)
	w.step(0.25)
	var cost := 0
	var income := 0
	for id in w.holdings_of("vardmark"):
		income += int(Lords.INCOME[WorldData.settlement(id)["type"]])
		for i in w.garrison_at(id).size():
			var sq: Dictionary = w.garrison_at(id)[i]
			cost += Economy.recruit_cost(String(sq["unit"]), int(sq["men"]) - int(before[id][i]["men"]))
	_expect(idle and before_midnight and w.men_of(castle) == start + int(Lords.GARRISON_RECRUITS_PER_DAY["castle"])
		and int(w.realms["vardmark"]["treasury"]) == purse + income - cost,
		"garrisons grow at midnight only while time passes, charging their owner's treasury exactly")
	var once := JSON.stringify(w.garrisons)
	w._step_lords(0.0)
	_expect(JSON.stringify(w.garrisons) == once, "the same midnight never recruits twice")

	# Full garrisons stop spending; destroyed squads are raised again without duplicates.
	for realm in w.realms:
		w.realms[realm]["treasury"] = 100000
	for day in 40:
		w._garrisons_day()
	var capped := true
	for id in w.garrisons:
		capped = capped and w.men_of(w.garrison_at(id)) == w.garrison_capacity(id)
	var full_purses := JSON.stringify(w.realms)
	w._garrisons_day()
	_expect(capped and JSON.stringify(w.realms) == full_purses, "garrisons stop recruiting and spending at their caps")
	var lost_id := int(castle[0]["id"])
	castle.remove_at(0)
	castle[0]["men"] = 19
	var survivors := w.men_of(castle)
	w._garrisons_day()
	_expect(w.men_of(castle) == survivors + int(Lords.GARRISON_RECRUITS_PER_DAY["castle"])
		and int(castle[0]["men"]) == 20 and castle.any(func(sq): return int(sq["id"]) == lost_id),
		"daily guards refill surviving squads and rebuild destroyed squads with stable ids")

	# Only one affordable man: no whole-batch rejection, debt, or spending the reserve.
	var target: Dictionary = castle.back()
	var one := Economy.recruit_cost(String(target["unit"]), 1)
	w.realms["vardmark"]["treasury"] = Lords.TREASURY_RESERVE + one
	survivors = w.men_of(castle)
	w._garrisons_day()
	_expect(w.men_of(castle) == survivors + 1 and int(w.realms["vardmark"]["treasury"]) == Lords.TREASURY_RESERVE,
		"a treasury buys the men it can afford and keeps its reserve")
	for balance in [Lords.TREASURY_RESERVE, 0]:
		w.realms["vardmark"]["treasury"] = balance
		var held := JSON.stringify(castle)
		w._garrisons_day()
		_expect(JSON.stringify(castle) == held and int(w.realms["vardmark"]["treasury"]) == balance,
			"no free guards or debt when the recruitment budget is empty (%d silver)" % balance)

	w.set_owner("ravensford", "kharzan")
	var cleared := w.garrison_at("ravensford").is_empty()
	w.realms["kharzan"]["treasury"] = 100000
	var old_purse := int(w.realms["vardmark"]["treasury"])
	var new_purse := int(w.realms["kharzan"]["treasury"])
	w._garrisons_day()
	castle = w.garrison_at("ravensford")
	w.set_owner("ravensford", "kharzan")
	_expect(cleared and not castle.is_empty() and castle[0]["culture"] == Cultures.VARDISH
		and int(w.realms["vardmark"]["treasury"]) == old_purse
		and int(w.realms["kharzan"]["treasury"]) < new_purse and w.garrison_at("ravensford") == castle,
		"a capture clears old guards; the new owner pays for local recruits, and a repeated transfer preserves them")

	w.garrisons["highcliff"] = []
	var saved := JSON.stringify(w.to_dict())
	var copy := WorldSim.new()
	copy.from_dict(JSON.parse_string(saved))
	var loaded := JSON.stringify(copy.to_dict()) == saved and copy.garrison_at("highcliff").is_empty()
	for world in [w, copy]:
		world.wait(48.0)
		world.step(48.0)
	_expect(loaded and JSON.stringify(w.to_dict()) == JSON.stringify(copy.to_dict()),
		"empty and damaged garrisons save exactly and resume daily growth identically")
	var legacy: Dictionary = JSON.parse_string(saved)
	legacy.erase("garrisons")
	copy.from_dict(legacy)
	var purses_unchanged := true
	for realm in copy.realms:
		purses_unchanged = purses_unchanged and int(copy.realms[realm]["treasury"]) == int(legacy["realms"][realm]["treasury"])
	_expect(copy.garrisons.size() == 9 and str(copy.rng.state) == legacy["state"]
		and purses_unchanged
		and copy.owner_of("ravensford") == "kharzan" and not copy.garrison_at("highcliff").is_empty(),
		"pre-garrison saves receive starting guards without changing borders, treasuries or the random stream")
	var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/save_v4.json"))
	copy.from_dict(old["world"])
	_expect(copy.garrisons.size() == 9 and copy.lords.size() == 15,
		"the real version-4 fixture still loads with lords and starting garrisons")


## Wall multipliers, siege preparation, auto-resolved assaults, and settlement capture.
func _check_sieges() -> void:
	var w := _quiet_world(44)
	var castle := w.garrison_at("ravensford")
	var g_men := w.men_of(castle)
	var rng := RandomNumberGenerator.new()
	var twice_squads := [{"id": 1, "type": Troops.INFANTRY, "unit": "vard_foot", "culture": Cultures.VARDISH, "level": 1, "xp": 0, "men": int(g_men * 2.2), "captain": null}]
	var twice_wins := 0
	for i in 50:
		rng.seed = 20000 + i
		var r := AutoResolve.resolve_siege(twice_squads, castle, AutoResolve.WALLS["castle"], rng)
		if r["won"]: twice_wins += 1
	var twice_rate := float(twice_wins) / 50.0

	var weak_squads := [{"id": 1, "type": Troops.INFANTRY, "unit": "vard_foot", "culture": Cultures.VARDISH, "level": 1, "xp": 0, "men": int(g_men * 0.7), "captain": null}]
	var weak_wins := 0
	for i in 50:
		rng.seed = 30000 + i
		var r := AutoResolve.resolve_siege(weak_squads, castle, AutoResolve.WALLS["castle"], rng)
		if r["won"]: weak_wins += 1
	var weak_rate := float(weak_wins) / 50.0

	_expect(twice_rate >= 0.80 and weak_rate <= 0.20,
		"gate: twice garrison strength takes settlement >= 80%% (got %.1f%%), less than garrison strength succeeds <= 20%% (got %.1f%%)" % [twice_rate * 100.0, weak_rate * 100.0])

	# Expedition siege and capture
	w.step(0.0)
	WorldSim.MarshalArmies.create(w, "kharzan")
	var army_dict: Dictionary = w.campaign_armies.filter(func(a): return a["realm"] == "kharzan")[0]
	var target: String = army_dict["target"]
	army_dict["state"] = "marching"
	army_dict["destination"] = target
	var leader = WorldSim.MarshalArmies.leader(w, army_dict)
	leader.node = target
	leader.next = ""
	leader.path.clear()
	for m in WorldSim.MarshalArmies.members(w, army_dict):
		m.node = target
		m.next = ""
		m.path.clear()
	WorldSim.MarshalArmies.tick(w, 0.25)
	var besieging_ok: bool = army_dict["state"] == "besieging" and army_dict.has("siege_prep_until")
	w.hour = float(army_dict["siege_prep_until"]) + 0.1
	var atk_before := 0
	for m in WorldSim.MarshalArmies.members(w, army_dict): atk_before += w.men_of(m.army)
	WorldSim.MarshalArmies.tick(w, 0.25)
	var captured_ok: bool = w.owner_of(target) == "kharzan"
	var garrison_left := w.men_of(w.garrison_at(target))
	var atk_after := 0
	for m in WorldSim.MarshalArmies.members(w, army_dict): atk_after += w.men_of(m.army)
	var conserved_ok: bool = garrison_left > 0 and (atk_after + garrison_left <= atk_before)
	var bound_ok: bool = true
	for v in WorldData.SETTLEMENTS:
		if String(WorldData.SETTLEMENTS[v].get("bound_to", "")) == target:
			bound_ok = bound_ok and w.owner_of(v) == "kharzan"
	_expect(besieging_ok and captured_ok and conserved_ok and bound_ok,
		"an army reaching a hostile castle besieges, assaults, captures it, stations surviving attackers, and takes bound villages")

	# Village militia
	var mil: Array = w.village_militia("kettlebrook")
	_expect(mil.size() == 2 and w.men_of(mil) == 15,
		"villages keep a 15-man local defensive militia that resists raids")


## Lords ride the map with warbands of their own, choose what to do by their realm's needs
## and their bearing, fight each other and the bandits, and pay their way.
func _check_lords() -> void:
	var w := _quiet_world(4)
	var sized := w.lords.size() == 15
	for realm in w.realms:
		var mine := w.lords.filter(func(l): return l["realm"] == realm)
		var rulers := mine.filter(func(l): return l["ruler"])
		sized = sized and mine.size() == 5 and rulers.size() == 1 and w.party(int(rulers[0]["party"])).node == w.capital_of(realm)
		for c in w.holdings_of(realm, WorldData.CASTLE):
			sized = sized and mine.filter(func(l): return l["fief"] == c).size() == 1
	for l in w.lords:
		var lp := w.party(int(l["party"]))
		sized = sized and lp != null and lp.kind == WorldSim.LORD and lp.army.size() >= Lords.SQUADS_MIN \
			and lp.army.size() <= Lords.SQUADS_MAX and w.men_of(lp.army) == int(l["full"])
	_expect(sized, "each realm has a ruler at its capital and four lords, two holding its castles, all in the field")

	# What a lord chooses. Vardmark and Kharzan are at war.
	var v: Dictionary = w.lords.filter(func(l): return l["realm"] == "vardmark" and not l["ruler"])[0]
	var k: Dictionary = w.lords.filter(func(l): return l["realm"] == "kharzan" and not l["ruler"])[0]
	var vp := w.party(int(v["party"]))
	var kp := w.party(int(k["party"]))
	for sq in vp.army:
		sq["men"] = 2
	w._think_lord(v, vp)
	var home_ok: bool = v["job"] == "home" and v["target"] == w.seat_of(v)
	for sq in vp.army:
		sq["men"] = 20
	v["job"] = ""
	# A Kharzani lord burning Thornwall: the Vardish lord at Ravensford rides to save it.
	kp.node = "thornwall"
	kp.next = ""
	kp.path = []
	k["raiding"] = "thornwall"
	vp.node = "ravensford"
	vp.next = ""
	vp.path = []
	vp.wait = 0.0
	v["bearing"] = Lords.HONORABLE
	w._think_lord(v, vp)
	var defend_ok: bool = v["job"] == "defend" and v["target"] == "thornwall"
	k["raiding"] = ""
	# A cruel lord at full strength goes raiding over the border.
	kp.node = "zeyra"
	k["bearing"] = Lords.CRUEL
	k["job"] = ""
	w._think_lord(k, kp)
	var raid_ok: bool = k["job"] == "raid" and w.owner_of(String(k["target"])) == "vardmark"
	_expect(home_ok and defend_ok and raid_ok,
		"a spent lord goes home to refill, a lord rides to defend his realm's burning village, a cruel one raids the enemy")

	# Two lords at war who meet fight it out, settled as a fight sent in; the loser regroups.
	for lp in w.lord_parties():
		if lp != vp and lp != kp:
			lp.node = w.capital_of(lp.faction)
			lp.next = ""
			lp.path = []
	for lp in [vp, kp]:
		lp.node = "thornwall"
		lp.next = ""
		lp.path = []
	w._lord_fights()
	var beaten: Dictionary = v if int(v["party"]) == -1 else k
	var fought: bool = (int(v["party"]) == -1) != (int(k["party"]) == -1) and beaten["state"] == "regroup"
	w.hour = float(beaten["back_at"]) + 0.1
	w._step_lords(0.0)
	_expect(fought and beaten["state"] == "field" and w.party(int(beaten["party"])).node == w.seat_of(beaten),
		"lords at war who meet fight it out, and the loser regroups at his seat a day later")

	# A raid left alone burns the village: no dues, no recruits, until it's rebuilt.
	var raider: Dictionary = w.lords.filter(func(l): return l["realm"] == "kharzan" and l["state"] == "field")[0]
	var rp := w.party(int(raider["party"]))
	# This fixture tests an independent raid, so release any newly mustered membership.
	var expedition := WorldSim.MarshalArmies.for_party(w, rp.id)
	if not expedition.is_empty(): WorldSim.MarshalArmies.disband(w, expedition, "Independent raid fixture")
	rp.node = "kettlebrook"
	rp.next = ""
	rp.path = []
	raider["job"] = "raid"
	raider["target"] = "kettlebrook"
	w._lord_arrives(raider, rp)
	var started: bool = raider["raiding"] == "kettlebrook"
	rp.wait = 0.01
	w._step_lords(0.05)
	var burnt: bool = w.is_burned("kettlebrook") and w.offers_at("kettlebrook").is_empty() and w.describe("kettlebrook").contains("burned")
	w.hour += Lords.BURNED_DAYS * 24.0 + 1.0
	_expect(started and burnt and not w.is_burned("kettlebrook"),
		"a raid left alone burns the village: no dues and no recruits until it's rebuilt %d days later" % Lords.BURNED_DAYS)

	# A year of the world, nobody touching it.
	var year := WorldSim.new()
	year.setup(11, Cultures.RYUMON)
	var samples := 0
	var in_field := 0.0
	var worst_broke := 0
	var fights := 0
	var burned := 0
	var t0 := Time.get_ticks_usec()
	for day in 365:
		if year.encounter != -1:
			year.withdraw()
		year.wait(24.0)
		year.step(24.0)
		var field := 0
		for l in year.lords:
			if l["state"] == "field" and l["job"] != "home":
				field += 1
			worst_broke = maxi(worst_broke, int(l["broke_days"]))
		in_field += float(field) / year.lords.size()
		samples += 1
		for e in year.events:
			fights += 1 if e["type"] == "fight" else 0
			burned += 1 if e["type"] == "burned" else 0
		year.events.clear()
	var ms_per_hour := (Time.get_ticks_usec() - t0) / 1000.0 / (365.0 * 24.0)
	_expect(worst_broke <= 7 and in_field / samples >= 0.6 and fights > 0 and burned > 0,
		"a year on: lords are out in the field %.0f%% of the time, none broke over a week (worst %d days); %d fights, %d villages burned" % [
			in_field * 100.0 / samples, worst_broke, fights, burned])
	_expect(ms_per_hour <= 8.0, "a world hour with every lord riding and campaigns active costs at most 8 ms (%.2f ms)" % ms_per_hour)

	# Godot's JSON doesn't read every float back to the last bit, so a loaded world is the
	# saved one to 14 digits: it loads back exactly as saved, two loads carry on exactly
	# alike, and the original and a load still agree on where everyone is and what every
	# lord is doing two days on.
	var saved := JSON.stringify(year.to_dict())
	var copy := WorldSim.new()
	copy.from_dict(JSON.parse_string(saved))
	var again := WorldSim.new()
	again.from_dict(JSON.parse_string(saved))
	var loads_back := JSON.stringify(copy.to_dict()) == saved
	for world in [year, copy, again]:
		world.wait(48.0)
		world.step(48.0)
	var agree := true
	for i in year.lords.size():
		for key in ["state", "job", "target", "raiding", "party"]:
			agree = agree and year.lords[i][key] == copy.lords[i][key]
	for i in year.parties.size():
		agree = agree and year.parties[i].node == copy.parties[i].node and year.parties[i].next == copy.parties[i].next
	_expect(loads_back and JSON.stringify(copy.to_dict()) == JSON.stringify(again.to_dict()) and agree,
		"lords, their purses and what they're doing are saved, and the world carries on as it would have")


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
			seen[b.faction] = int(seen.get(b.faction, 0)) + 1
			if int(seen[b.faction]) > WorldData.BANDIT_BANDS[b.faction].size():
				per_realm_ok = false
	_expect(w.hour >= 60.0 * 24.0 and most <= 6 and per_realm_ok and outcome > 3,
		"sixty days of riding: never more than two bands per realm (%d encounters)" % outcome)


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
	var rng_probe := RandomNumberGenerator.new()
	rng_probe.seed = 318
	var rng_state := rng_probe.state
	var first_look := Captains.appearance_for(Cultures.VARDISH, 1)
	var second_look := Captains.appearance_for(Cultures.VARDISH, 2)
	_expect(rng_probe.state == rng_state and first_look != second_look,
		"captain appearances alternate without consuming campaign RNG")
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
	var state := GameStateScript.new()
	state.persist = false
	state.new_warband()
	var saved: Dictionary = JSON.parse_string(JSON.stringify(state.to_dict()))
	var expected := String(saved["army"][0]["captain"]["appearance_id"])
	for squad in saved["army"]:
		squad["captain"].erase("appearance_id")
	var restored := GameStateScript.new()
	restored.persist = false
	restored.from_dict(saved)
	_expect(String(restored.army[0]["captain"]["appearance_id"]) == expected,
		"old saves receive the same deterministic captain face")
	state.free()
	restored.free()


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
	_expect(gs.fallen.size() == 1 and gs.fallen[0]["name"] == c1["name"] and gs.fallen[0]["words"] == "Tell them I held."
		and gs.fallen[0]["appearance_id"] == c1["appearance_id"],
		"the dead go on the memorial with their last words and the same face")
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
	var branch: String = Units.branches(s["unit"])[0]
	var price := Economy.train_cost(s, branch)
	var silver: int = gs.silver
	_expect(gs.can_train(s) and gs.train_squad(int(s["id"]), branch) and int(s["level"]) == 2 and gs.silver == silver - price \
			and is_equal_approx(Economy.daily_wage(s), wage * (1.0 + Economy.WAGE_PER_LEVEL) * Units.wage_mult(branch)),
		"training to level 2 as %s costs %d silver, and half again in wages (times the branch's pay)" % [Units.display_name(branch), price])
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
## `trained`: squads past level 1 are one of the tier-2 branches of a random culture.
func _random_army(rng: RandomNumberGenerator, base_id: int, small: bool, trained: bool = false) -> Array:
	var out := []
	var n := rng.randi_range(3, 5) if small else rng.randi_range(2, 8)
	for i in n:
		var type: String = Troops.ORDER[rng.randi_range(0, 3)]
		var level: int = 1 if small else [1, 1, 1, 2, 2, 3][rng.randi_range(0, 5)]
		var unit_id := ""
		var full := Troops.full_size(type)
		if trained and level >= 2:
			var branches: Array = Units.branches(Units.recruit(Cultures.ORDER[rng.randi_range(0, 2)], type))
			unit_id = branches[rng.randi_range(0, branches.size() - 1)]
			full = Units.full_size(unit_id)
		var men := rng.randi_range(8, 14) if small else maxi(4, int(full * rng.randf_range(0.4, 1.0)))
		var squad := {"id": base_id + i, "type": type, "men": men, "xp": (level - 1) * Troops.XP_PER_LEVEL, "level": level,
			"captain": Captains.make(rng, base_id * 100 + i, type)}
		if unit_id != "":
			squad["unit"] = unit_id
		out.append(squad)
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

	# Trained armies of every culture on rough ground, half the hills and woods ground the
	# enemy chose and waits on, as bands do on the map.
	var terrain_agree := 0
	for i in CALIBRATION_BATTLES:
		var seed_value := 9200 + i
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value * 977
		var pa := _random_army(rng, 1, false, true)
		var ea := _random_army(rng, 500, false, true)
		var site_type: String = [BattleSite.TYPE_HILLS, BattleSite.TYPE_WOODS, BattleSite.TYPE_RIVER, BattleSite.TYPE_PASS][i % 4]
		var chosen: bool = (site_type == BattleSite.TYPE_HILLS or site_type == BattleSite.TYPE_WOODS) and i % 8 < 4
		var site_dict := {"type": site_type, "seed": seed_value, "fair": not chosen}
		var site_obj := BattleSite.generate(site_dict)
		var sim := Sim.new()
		sim.setup(pa, ea, seed_value, site_obj)
		sim.ai = [Commander.new(Sim.PLAYER), Commander.new(Sim.ENEMY, "Patient" if chosen else "Reckless")]
		sim.ai[Sim.ENEMY].deploy(sim)
		sim.ai[Sim.PLAYER].deploy(sim)
		sim.start_battle()
		while sim.winner == -1 and sim.time < Sim.TIME_LIMIT + 5.0:
			sim.step()
		var sim_won := sim.winner == Sim.PLAYER
		sim.dispose()
		if AutoResolve.odds(pa, ea, site_dict)["player_wins"] == sim_won:
			terrain_agree += 1
	_expect(terrain_agree >= int(ceil(n * 0.85)), "and with trained armies on rough ground, some of it chosen by the enemy (%d of %d)" % [terrain_agree, CALIBRATION_BATTLES])

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

	print("Terrain fairness (mirrored maps, AI vs AI, 24 seeds per type, each fought both ways round):")
	_check_terrain_fairness()
	_check_cultures_balance()


## Good ground is worth fighting for: a stronger army pressing Advance all wins most fights
## on open ground, and clearly fewer against the same enemy holding a ridge, standing
## behind a river, or waiting at the edge of a wood, against every kind of commander.
func _check_terrain_matters() -> void:
	print("Attacking into good ground (%d%% more men, %d seeds per commander):" % [int(round((TERRAIN_ATTACKER - 1.0) * 100.0)), TERRAIN_SEEDS])
	var grounds := [["open", true], [BattleSite.TYPE_HILLS, false], [BattleSite.TYPE_WOODS, false], [BattleSite.TYPE_RIVER, true]]
	var rate := {}
	var line := " "
	for g in grounds:
		var won := 0
		var n := 0
		for temp in Commander.TEMPERAMENTS:
			for s in range(1, TERRAIN_SEEDS + 1):
				var site = {"type": g[0], "seed": s, "fair": g[1]} if g[0] != "open" else null
				if Plans.attack(TERRAIN_ATTACKER, temp, s, site)["winner"] == Sim.PLAYER:
					won += 1
				n += 1
		rate[g[0]] = float(won) / n
		line += " %s %d/%d" % [g[0], won, n]
	print(line)
	var cost := 0.0
	for g in grounds.slice(1):
		cost += rate["open"] - rate[g[0]]
	cost = cost * 100.0 / (grounds.size() - 1)
	_expect(cost >= TERRAIN_POINTS, "attacking an enemy on a ridge, behind a river or at a wood's edge wins %.0f points less often than on open ground" % cost)


## Each objective asks for its own play, and rewards it: the tactician, who goes for the
## chief, strikes back at once when ambushed and holds the village square, wins most of
## each, and clearly more often than a player who presses Advance all and nothing else.
func _check_objective_plans() -> void:
	print("Objectives against each kind of commander (%d seeds each):" % OBJECTIVE_SEEDS)
	var gap := 0.0
	var objectives := [Sim.OBJECTIVE_CHIEF, Sim.OBJECTIVE_AMBUSH, Sim.OBJECTIVE_VILLAGE]
	for obj in objectives:
		var rate := {}
		for plan in ["tactician", "advance"]:
			var won := 0
			for temp in Commander.TEMPERAMENTS:
				for s in range(1, OBJECTIVE_SEEDS + 1):
					if Plans.battle(plan, temp, s, null, obj)["winner"] == Sim.PLAYER:
						won += 1
			rate[plan] = float(won) / (OBJECTIVE_SEEDS * Commander.TEMPERAMENTS.size())
		print("  %-8s tactician %3.0f%%  advance %3.0f%%" % [obj, rate["tactician"] * 100.0, rate["advance"] * 100.0])
		_expect(rate["tactician"] >= 0.6, "a player who plays the %s objective wins it at least 60%% of the time (%.0f%%)" % [obj, rate["tactician"] * 100.0])
		gap += rate["tactician"] - rate["advance"]
	gap = gap * 100.0 / objectives.size()
	_expect(gap >= OBJECTIVE_POINTS, "playing to the objective wins %.0f points more often than pressing Advance all" % gap)


## Each map is fought twice, with the armies swapped between the sides, so a stronger army
## drawn for one side doesn't pass for the ground favoring it. 48 battles leave about 7
## points of chance either way, so the window is two of those wide: a fair map seldom
## fails it, and one that tilts the fight (as rivers did, about 30%) still does.
func _check_terrain_fairness() -> void:
	for site_type in [BattleSite.TYPE_HILLS, BattleSite.TYPE_WOODS, BattleSite.TYPE_RIVER, BattleSite.TYPE_PASS]:
		var player_wins := 0
		for s in range(1, 25):
			var site_obj := BattleSite.generate({"type": site_type, "seed": s, "fair": true})
			for swap in [false, true]:
				var sim := Sim.new()
				var a := Plans.army(s)
				var b := Plans.army(s + 1000)
				sim.setup(b if swap else a, a if swap else b, s, site_obj)
				sim.ai = [Commander.new(Sim.PLAYER), Commander.new(Sim.ENEMY)]
				sim.ai[Sim.PLAYER].deploy(sim)
				sim.ai[Sim.ENEMY].deploy(sim)
				sim.start_battle()
				while sim.winner == -1 and sim.time < Sim.TIME_LIMIT + 5.0:
					sim.step()
				if sim.winner == Sim.PLAYER:
					player_wins += 1
				sim.dispose()
		var win_pct := float(player_wins) / 48.0
		_expect(win_pct >= 0.35 and win_pct <= 0.65,
			"mirrored %s map is fair (player win rate: %.0f%%)" % [site_type, win_pct * 100.0])


## Each culture's trained army against each other's, AI on both sides, each seed fought
## both ways round so neither the side nor the draw of the armies decides it.
func _check_cultures_balance() -> void:
	print("Culture vs Culture balance (trained armies, 24 seeds each, both ways round):")
	for pair in [[Cultures.VARDISH, Cultures.KHARZANI], [Cultures.KHARZANI, Cultures.RYUMON], [Cultures.RYUMON, Cultures.VARDISH]]:
		var cult_a: String = pair[0]
		var cult_b: String = pair[1]
		var wins_a := 0
		for s in range(1, 25):
			for a_first in [true, false]:
				var a := Plans.culture_army(cult_a, s)
				var b := Plans.culture_army(cult_b, s + 1000)
				var sim := Sim.new()
				sim.setup(a if a_first else b, b if a_first else a, s)
				sim.ai = [Commander.new(Sim.PLAYER), Commander.new(Sim.ENEMY)]
				sim.ai[Sim.PLAYER].deploy(sim)
				sim.ai[Sim.ENEMY].deploy(sim)
				sim.start_battle()
				while sim.winner == -1 and sim.time < Sim.TIME_LIMIT + 5.0:
					sim.step()
				if sim.winner == (Sim.PLAYER if a_first else Sim.ENEMY):
					wins_a += 1
				sim.dispose()
		var rate := float(wins_a) / 48.0
		_expect(rate >= 0.35 and rate <= 0.65,
			"%s army vs %s army is balanced (%.0f%% - %.0f%%)" % [
				Cultures.info(cult_a)["people"], Cultures.info(cult_b)["people"], rate * 100.0, (1.0 - rate) * 100.0])


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


func _check_objectives() -> void:
	# 1. Reinforcements pipeline
	var sim := Sim.new()
	var p_army := [{"id": 1, "type": Troops.INFANTRY, "men": 20}]
	var e_army := [{"id": 2, "type": Troops.INFANTRY, "men": 20}]
	sim.setup(p_army, e_army, 1, null, Sim.OBJECTIVE_ROUT)
	var wave := [{"id": 3, "type": Troops.ARCHERS, "men": 15}]
	sim.add_reinforcements(Sim.ENEMY, wave, 2.0, "north")
	sim.auto_deploy(Sim.PLAYER)
	sim.auto_deploy(Sim.ENEMY)
	sim.start_battle()
	_expect(sim.squads.size() == 2, "initial battle has 2 squads before reinforcement time")
	for i in 65:
		sim.step(Sim.STEP)
	_expect(sim.squads.size() == 3, "reinforcement squad arrived on time (3 squads total)")
	var arrived_sq = sim.squads[2]
	_expect(arrived_sq.team == Sim.ENEMY and arrived_sq.type == Troops.ARCHERS and arrived_sq.center.y <= 120.0,
		"reinforcements spawned from north edge facing into field")
	sim.dispose()

	# 2. Chief objective & morale shock
	var chief_sim := Sim.new()
	var p_army2 := [{"id": 1, "type": Troops.INFANTRY, "men": 20}, {"id": 2, "type": Troops.ARCHERS, "men": 20}]
	var e_army2 := [
		{"id": 10, "type": Troops.INFANTRY, "men": 16, "is_bodyguard": true, "is_chief": true, "chief_name": "Rask the Red"},
		{"id": 11, "type": Troops.INFANTRY, "men": 20},
		{"id": 12, "type": Troops.SPEARMEN, "men": 20}
	]
	chief_sim.setup(p_army2, e_army2, 1, null, Sim.OBJECTIVE_CHIEF)
	chief_sim.auto_deploy(Sim.PLAYER)
	chief_sim.auto_deploy(Sim.ENEMY)
	chief_sim.start_battle()
	var bg_sq = null
	for sq in chief_sim.squads:
		if sq.is_bodyguard:
			bg_sq = sq
			break
	_expect(bg_sq != null, "bodyguard squad designated in chief objective")
	var other_sq = chief_sim.squads[2]
	if other_sq == bg_sq:
		other_sq = chief_sim.squads[3]
	var morale_before: float = other_sq.morale
	bg_sq.drop_morale(80.0)
	chief_sim._update_squad(bg_sq, Sim.STEP)
	_expect(bg_sq.routing, "bodyguard squad broke")
	_expect(other_sq.morale <= morale_before - 35.0, "other squads lost 35 morale on chief shock")
	chief_sim.dispose()

	# A chief is cut down or gets away when you win, and keeps his band when you lose: one
	# fate, never both. Win, and he goes down in the rout of his guard, so the death roll
	# kills him some of the time.
	var fates_ok := true
	var fates := {"killed": 0, "escaped": 0, "kept": 0}
	for s in range(1, 17):
		var fate_sim := Sim.new()
		fate_sim.setup(Plans.army(s), Plans.foe_army(s, Sim.OBJECTIVE_CHIEF), s, null, Sim.OBJECTIVE_CHIEF)
		fate_sim.ai[Sim.ENEMY] = Commander.new(Sim.ENEMY)
		fate_sim.ai[Sim.ENEMY].deploy(fate_sim)
		fate_sim.auto_deploy(Sim.PLAYER)
		fate_sim.start_battle()
		fate_sim.order_all(Sim.PLAYER, "advance")
		while fate_sim.winner == -1 and fate_sim.time < Sim.TIME_LIMIT + 5.0:
			fate_sim.step()
		var r: Dictionary = fate_sim.result_for(Sim.PLAYER)
		if fate_sim.winner == Sim.PLAYER:
			fates_ok = fates_ok and r["chief_killed"] != r["chief_escaped"]
			fates["killed" if r["chief_killed"] else "escaped"] += 1
		else:
			fates_ok = fates_ok and not r["chief_killed"] and not r["chief_escaped"]
			fates["kept"] += 1
		fate_sim.dispose()
	_expect(fates_ok and fates["killed"] > 0, "a chief meets one fate: cut down %d, got away %d, kept his band %d" % [fates["killed"], fates["escaped"], fates["kept"]])

	# 3. Chief escape and grudge return
	var world := WorldSim.new()
	world.setup(42, Cultures.VARDISH)
	world.escaped_chiefs.append({"name": "Rask the Red", "culture": Cultures.VARDISH, "grudge": 0, "escaped_at": 10.0, "times_beaten": 1})
	world.hour = 10.0 + WorldSim.CHIEF_RETURN_HOURS
	# Clear the realm's band so a new one can rise there.
	world.parties = world.parties.filter(func(p): return not (p.kind == WorldSim.BAND and p.faction == "vardmark"))
	world._spawn_band("vardmark")
	var chief_band = null
	for b in world.bands():
		if b.is_chief_band and b.chief_name == "Rask the Red":
			chief_band = b
			break
	_expect(chief_band != null, "escaped chief returned with his own band after days passed")
	_expect(chief_band != null and chief_band.army[0].get("is_bodyguard", false), "chief leads bodyguard squad on return")

	# 4. Ambush deployment
	var ambush_sim := Sim.new()
	ambush_sim.setup(p_army2, e_army2, 1, null, Sim.OBJECTIVE_AMBUSH)
	ambush_sim.auto_deploy(Sim.PLAYER)
	ambush_sim.auto_deploy(Sim.ENEMY)
	var p_sq = ambush_sim.squads[0]
	var column_ok := true
	for sq in ambush_sim.squads:
		if sq.team != Sim.PLAYER:
			continue
		var per_rank := {}
		for so in sq.soldiers:
			var rank := snappedf(so.slot.y, 0.1)
			per_rank[rank] = int(per_rank.get(rank, 0)) + 1
		var half: Vector2 = ambush_sim._footprint(sq.type, sq.start_men, sq.files)
		column_ok = column_ok and sq.files == Sim.AMBUSH_FILES and per_rank.values().max() <= Sim.AMBUSH_FILES \
			and sq.still == 0.0 and not ambush_sim._overlaps(Sim.PLAYER, sq.center, half, sq)
	_expect(column_ok and p_sq.files == Sim.AMBUSH_FILES,
		"player caught on the march: squads %d abreast, strung out without overlapping, unbraced" % Sim.AMBUSH_FILES)
	var enemy_north := false
	var enemy_south := false
	for sq in ambush_sim.squads:
		if sq.team == Sim.ENEMY:
			if sq.center.y < 300.0:
				enemy_north = true
			elif sq.center.y > 900.0:
				enemy_south = true
	_expect(enemy_north and enemy_south, "ambushers deployed at both north and south ends")
	var before: Vector2 = p_sq.center
	var moved = ambush_sim.place(Sim.PLAYER, p_sq.roster_id, before + Vector2(200.0, 0.0))
	var redrawn := ambush_sim.order_line(Sim.PLAYER, Vector2(150.0, 900.0), Vector2(690.0, 900.0))
	_expect(moved == null and redrawn.is_empty() and p_sq.center == before, "and there's no time to form up: the column can't be moved or redrawn")
	ambush_sim.dispose()

	# 5. Village defense zone and countdown
	var village_sim := Sim.new()
	village_sim.setup(p_army2, e_army2, 1, null, Sim.OBJECTIVE_VILLAGE)
	village_sim.auto_deploy(Sim.PLAYER)
	village_sim.auto_deploy(Sim.ENEMY)
	village_sim.start_battle()
	_expect(village_sim.scheduled_reinforcements.size() == 2, "village defense scheduled 2 waves of reinforcements")
	village_sim.time = Sim.VILLAGE_DURATION + 0.1
	for sq in village_sim.squads:
		if sq.team == Sim.PLAYER:
			for so in sq.soldiers:
				so.pos = Sim.VILLAGE_ZONE_CENTER
		else:
			for so in sq.soldiers:
				so.pos = Vector2(50.0, 50.0)
	village_sim._check_end()
	_expect(village_sim.winner == Sim.PLAYER and village_sim.end_reason == "village_held",
		"village defense won by player controlling circle at 120s timer expiration")
	village_sim.dispose()

	# 6. Village loss condition
	var village_sim2 := Sim.new()
	village_sim2.setup(p_army2, e_army2, 1, null, Sim.OBJECTIVE_VILLAGE)
	village_sim2.auto_deploy(Sim.PLAYER)
	village_sim2.auto_deploy(Sim.ENEMY)
	village_sim2.start_battle()
	village_sim2.time = Sim.VILLAGE_DURATION + 0.1
	for sq in village_sim2.squads:
		if sq.team == Sim.PLAYER:
			for so in sq.soldiers:
				so.pos = Vector2(50.0, 50.0)
		else:
			for so in sq.soldiers:
				so.pos = Sim.VILLAGE_ZONE_CENTER
	village_sim2._check_end()
	_expect(village_sim2.winner == Sim.ENEMY and village_sim2.end_reason == "village_lost",
		"village defense lost when enemy holds circle at timer expiration")
	village_sim2.dispose()

	# Raiders who hold the square two to one fire the village before time runs out; a
	# defence that stands more than half their number holds off the torches.
	var burnt := {}
	for defended in [false, true]:
		var village_sim3 := Sim.new()
		village_sim3.setup(p_army2, e_army2, 1, null, Sim.OBJECTIVE_VILLAGE)
		village_sim3.auto_deploy(Sim.PLAYER)
		village_sim3.auto_deploy(Sim.ENEMY)
		village_sim3.start_battle()
		for sq in village_sim3.squads:
			for so in sq.soldiers:
				so.pos = Sim.VILLAGE_ZONE_CENTER if sq.team == Sim.ENEMY or defended else Vector2(50.0, 50.0)
		village_sim3._burn_village(Sim.VILLAGE_BURN + 0.1)
		burnt[defended] = village_sim3.end_reason == "village_burned" and village_sim3.winner == Sim.ENEMY
		village_sim3.dispose()
	_expect(burnt[false] and not burnt[true], "raiders holding the square two to one burn the village; enough defenders stop them")

	# 7. Auto-resolve objectives
	var rng := RandomNumberGenerator.new()
	rng.seed = 123
	var auto_ambush := AutoResolve.resolve(p_army2, e_army2, rng, true, null, "ambush")
	_expect(auto_ambush.has("won"), "auto-resolve settles ambush fights")
	var auto_chief := AutoResolve.resolve(p_army2, e_army2, rng, true, null, "chief")
	_expect(auto_chief.has("chief_killed") and auto_chief.has("chief_escaped"), "auto-resolve resolves chief fate")
