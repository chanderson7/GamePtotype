## Playable sieges: walls and a gate on the battlefield, and storming them on campaign.
extends SceneTree

const Sim = preload("res://scripts/battle/battle_sim.gd")
const Commander = preload("res://scripts/battle/commander_ai.gd")
const Troops = preload("res://scripts/data/troops.gd")
const Terrain = preload("res://scripts/battle/terrain.gd")
const Cultures = preload("res://scripts/data/cultures.gd")
const WorldData = preload("res://scripts/world/world_data.gd")
const MarshalArmies = preload("res://scripts/world/marshal_armies.gd")

var gs
var failures := 0


func check(ok: bool, message: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + message)
	if not ok:
		failures += 1


func _army(types: Array, base: int) -> Array:
	var out := []
	for i in types.size():
		out.append({"id": base + i, "type": types[i], "men": Troops.full_size(types[i])})
	return out


## Fight `seeds` AI-vs-AI assaults; [attacker wins, breaches].
func _assaults(att: Array, defn: Array, seeds: int) -> Array:
	var wins := 0
	var breaches := 0
	for s in range(1, seeds + 1):
		var sim := Sim.new()
		sim.setup(_army(att, 1), _army(defn, 100), s, null, Sim.OBJECTIVE_SIEGE)
		sim.ai = [Commander.new(Sim.PLAYER), Commander.new(Sim.ENEMY)]
		sim.start_battle()
		while sim.winner == -1 and sim.time < Sim.TIME_LIMIT + 5.0:
			sim.step()
		if sim.winner == Sim.PLAYER:
			wins += 1
		if sim.gate_hp <= 0.0:
			breaches += 1
		sim.dispose()
	return [wins, breaches]


func _check_battlefield() -> void:
	var sim := Sim.new()
	sim.setup(_army(["infantry", "archers"], 1), _army(["infantry", "spearmen", "archers"], 100), 1, null, Sim.OBJECTIVE_SIEGE)
	var wall_ok := true
	for cx in Terrain.COLS:
		var p := Vector2(cx * 30.0 + 15.0, Sim.WALL_Y)
		var blocked: bool = not sim.terrain.passable(p)
		wall_ok = wall_ok and (blocked != (Sim.GATE_COLS.has(cx) or Sim.LADDER_COLS.has(cx)))
	check(wall_ok, "a wall crosses the field, with the gate and two ladders the only ways over")
	sim.start_battle()
	var behind := true
	var garrison := 0
	for sq in sim.squads:
		if sq.team == Sim.ENEMY:
			garrison += 1
			behind = behind and sq.center.y < Sim.WALL_Y
	check(garrison == 3 and behind, "the whole garrison forms up behind its wall")
	check(not sim.gate_open() and sim.gate_hp == Sim.GATE_HP["castle"], "the gate starts shut at full strength")
	# Nobody walks through a shut gate.
	var so = sim.squads[0].soldiers[0]
	so.pos = Sim.GATE_CENTER + Vector2(0, 40)
	for i in 40:
		sim._walk(so, Sim.GATE_CENTER + Vector2(0, -120), 40.0, 0.1)
	check(so.pos.y > Sim.WALL_Y - 5.0, "no one walks through the shut gate")
	# Men sent to storm the walls by a ladder climb it while the gate holds; others don't.
	var climber = sim.squads[0].soldiers[1]
	var lp: Vector2 = sim.ladder_points()[0]
	climber.pos = lp + Vector2(0, 50)
	sim.squads[0].use_ladders = true
	for i in 120:
		sim._walk(climber, lp + Vector2(0, -120), 40.0, 0.1)
	check(climber.pos.y < Sim.WALL_Y - 15.0, "men sent up a ladder climb over the wall while the gate holds")
	sim.squads[0].use_ladders = false
	climber.pos = lp + Vector2(0, 50)
	for i in 120:
		sim._walk(climber, lp + Vector2(0, -120), 40.0, 0.1)
	check(climber.pos.y > Sim.WALL_Y, "and men not sent to the ladders make for the gate")
	# Horses can't climb: a horseman sent to a ladder stays outside, and no horse's route
	# goes over one.
	var hsim := Sim.new()
	hsim.setup(_army(["cavalry"], 1), _army(["infantry"], 100), 1, null, Sim.OBJECTIVE_SIEGE)
	hsim.start_battle()
	var rider = hsim.squads[0].soldiers[0]
	hsim.squads[0].use_ladders = true
	rider.pos = lp + Vector2(0, 50)
	for i in 200:
		hsim._walk(rider, lp + Vector2(0, -120), 60.0, 0.1)
	check(rider.pos.y > Sim.WALL_Y - 5.0, "a horseman can't climb a ladder")
	var route: Array = Sim.Pathing.find_path(hsim.terrain, lp + Vector2(0, 60), lp + Vector2(0, -90), true)
	var over_ladder := false
	var prev: Vector2 = lp + Vector2(0, 60)
	for wp in route:
		for k in 21:
			over_ladder = over_ladder or hsim.on_ladder(prev.lerp(wp, k / 20.0))
		prev = wp
	check(not over_ladder, "and a horseman's route over the wall never goes by a ladder")
	hsim.dispose()
	var bows_on_wall := true
	for sq in sim.squads:
		if sq.team == Sim.ENEMY and sq.type == Troops.ARCHERS:
			bows_on_wall = bows_on_wall and absf(sq.center.y - Sim.WALL_Y) < 60.0
	check(bows_on_wall, "the garrison's bows stand on the wall walk")
	# The storm plan: shields to a ladder or the ram, bows shoot; a changed plan is obeyed.
	var foot = sim.squads[0]
	var shooters = sim.squads[1]
	var plan := sim.storm_plan(Sim.PLAYER)
	check(plan.size() == 2 and ["ladder", "ram"].has(plan[foot.id]) and plan[shooters.id] == "bows",
		"the storm plan sends the shields to a ladder or the ram and leaves the bows shooting")
	check(sim.can_climb(foot) and not sim.can_climb(shooters), "only men on foot without shooters can be swapped onto a ladder")
	plan[foot.id] = "ladder"
	sim.order_storm(Sim.PLAYER, plan)
	check(foot.use_ladders and not shooters.use_ladders and foot.order == "advance", "storming by a changed plan sends those companies up the ladders")
	plan[foot.id] = "ram"
	sim.order_storm(Sim.PLAYER, plan)
	check(not foot.use_ladders, "and swapping a company back sends it to the ram")
	# The record of the siege: who climbed first, and how many went over.
	for s2 in foot.soldiers:
		s2.pos = Sim.GATE_CENTER + Vector2(0, 160)
	var up = foot.soldiers[2]
	up.pos = lp
	sim._batter_gate(0.001)
	check(sim.siege_role(foot) == "climb", "a company with a man on a ladder reads as climbing")
	up.pos = lp + Vector2(0, -40)
	sim._batter_gate(0.001)
	check(sim.climbed == 1 and sim.siege_log.any(func(e): return e["kind"] == "first_over" and e["squad"] == foot),
		"the first man over the wall is remembered, with his company")
	for s2 in foot.soldiers:
		s2.pos = Sim.GATE_CENTER + Vector2(0, 30)
	check(sim.siege_role(foot) == "ram", "a company at the gate reads as at the ram")
	check(sim.siege_role(shooters) == "bows", "and archers outside the walls as shooting")
	sim.gate_hp = 1.0
	for sq in sim.squads:
		if sq.team == Sim.PLAYER and sq.type == Troops.INFANTRY:
			for s in sq.soldiers:
				s.pos = Sim.GATE_CENTER + Vector2(0, 20)
	sim._batter_gate(1.0)
	check(sim.gate_open() and sim.events.any(func(e): return e["type"] == "gate_breached"), "men on foot at the gate break it")
	sim.dispose()

	# Walls are worth about half again their garrison: an assault that size breaks the gate
	# nearly always and wins more often than not, at a price; twice the garrison always wins.
	var stronger := _assaults(["infantry", "infantry", "spearmen", "archers", "archers", "infantry", "spearmen"],
		["infantry", "infantry", "spearmen", "archers", "archers"], 8)
	check(stronger[0] >= 4 and stronger[1] >= 7, "half again the garrison breaks the gate and usually takes the walls (%d/8 won, %d/8 breached)" % [stronger[0], stronger[1]])
	var twice := _assaults(["infantry", "infantry", "spearmen", "archers", "archers", "infantry", "infantry", "spearmen", "archers", "archers"],
		["infantry", "infantry", "spearmen", "archers", "archers"], 4)
	check(twice[0] == 4, "twice the garrison always takes the walls (%d/4)" % twice[0])
	var even := _assaults(["infantry", "infantry", "spearmen", "archers", "archers"],
		["infantry", "infantry", "spearmen", "archers", "archers"], 4)
	check(even[0] <= 1, "an even assault fails against the walls (%d/4 won)" % even[0])
	var bows := _assaults(["archers", "archers", "archers"], ["infantry", "archers"], 2)
	check(bows[1] == 0 and bows[0] == 0, "archers alone can't break a gate, and the walls hold")


## Holding the walls: the shut gate is a door, the garrison has posts and jobs on the wall
## (stones, ladder heads, the breach), and the storm uses the wall's weak points.
func _check_wall_defence() -> void:
	var five := ["infantry", "infantry", "spearmen", "archers", "archers"]
	var sim := Sim.new()
	sim.setup(_army(five, 1), _army(five, 100), 1, null, Sim.OBJECTIVE_SIEGE)
	sim.auto_deploy(Sim.PLAYER)
	sim.auto_deploy(Sim.ENEMY)
	# E: the garrison's posts.
	var tower = null
	var walk_bows := 0
	var crescent := 0
	for sq in sim.squads:
		if sq.team != Sim.ENEMY:
			continue
		if sq.type == Troops.ARCHERS and sim.on_walk(sq.center):
			walk_bows += 1
		elif sim.on_gate_tower(sq.center) and sq.type == Troops.INFANTRY:
			tower = sq
		elif sim.inside_walls(sq.center) and absf(sq.center.y - sim.wall_y) > 70.0 and sq.center.distance_to(sim.gate_center) < 200.0:
			crescent += 1
	check(walk_bows == 2 and tower != null and crescent == 2,
		"the garrison takes its posts: bows on the walk, swords on the gate tower, the rest behind the gate (%d bows, tower %s, %d at the breach)" % [walk_bows, tower != null, crescent])
	var head_clear := true
	for sq in sim.squads:
		if sq.team == Sim.ENEMY and sq.type == Troops.ARCHERS:
			for i in 2:
				head_clear = head_clear and sq.center.distance_to(sim.ladder_head_post(i)) > 60.0
	check(head_clear, "and the bows stand beside the ladders, leaving the heads for men with blades")
	sim.start_battle()
	# A: the shut gate is a door.
	var inside := Vector2(Sim.GATE_CENTER.x + 120.0, sim.wall_y - 20.0)
	var outside := Vector2(Sim.GATE_CENTER.x + 120.0, sim.wall_y + 20.0)
	var lp: Vector2 = sim.ladder_points()[0]
	check(sim.across_wall(inside, outside) and not sim.across_wall(inside, lp) and not sim.across_wall(lp, outside),
		"while the gate holds the wall stands between the sides, except across a ladder")
	var garrison_foot = null
	var stormer = null
	for sq in sim.squads:
		if sq.team == Sim.ENEMY and sq.type == Troops.SPEARMEN:
			garrison_foot = sq
		if sq.team == Sim.PLAYER and sq.type == Troops.INFANTRY:
			stormer = sq
	var d = garrison_foot.soldiers[0]
	var a = stormer.soldiers[0]
	var d_was: Vector2 = d.pos
	var a_was: Vector2 = a.pos
	d.pos = inside
	a.pos = outside
	sim._build_grid()
	garrison_foot.focus = stormer
	check(sim._pick_target(d, garrison_foot) == null, "a man on foot can't pick a fight through the shut gate")
	var hp: float = a.hp
	sim._strike(d, garrison_foot, a, 10.0)
	check(a.hp == hp, "nor strike one")
	a.pos = lp
	sim._build_grid()
	check(sim._pick_target(d, garrison_foot) == a, "but a man on a ladder can be fought from the walk")
	a.pos = lp + Vector2(0, 40.0)
	d.pos = inside
	for i in 30:
		sim._walk(d, Vector2(inside.x, sim.wall_y + 120.0), 40.0, 0.1)
	check(sim.inside_walls(d.pos), "and the garrison keeps to its own side of its shut gate")
	d.pos = d_was
	a.pos = a_was
	# B: the walk, stones, ladder heads.
	check(sim.on_walk(Vector2(400.0, sim.wall_y - 30.0)) and not sim.on_walk(Vector2(400.0, sim.wall_y - 90.0)),
		"the battlements cover the wall walk, not the courtyard behind it")
	var rammers := []
	for sq in sim.squads:
		if sq.team == Sim.PLAYER and not sq.ranged:
			for so in sq.soldiers:
				if rammers.size() < 15:
					so.pos = sim.gate_center + Vector2(randf_range(-20.0, 20.0), 22.0)
					rammers.append(so)
	var before := 0.0
	for so in rammers:
		before += so.hp
	for i in 10:
		sim._drop_stones(Sim.STONE_EVERY)
	var after := 0.0
	for so in rammers:
		after += so.hp if so.alive else 0.0
	check(sim.stones_dropped >= 100 and after < before,
		"men on the gate tower drop stones on the men at the ram (%d stones, %.0f hurt)" % [sim.stones_dropped, before - after])
	var dropped: int = sim.stones_dropped
	var tower_was: Vector2 = tower.center
	for so in tower.soldiers:
		so.pos += Vector2(0, -200.0)
	sim._drop_stones(Sim.STONE_EVERY)
	check(sim.stones_dropped == dropped, "and nobody drops stones from off the tower")
	for so in tower.soldiers:
		so.pos += Vector2(0, 200.0)
	var bow = null
	for sq in sim.squads:
		if sq.team == Sim.ENEMY and sq.type == Troops.ARCHERS:
			bow = sq
	for so in bow.soldiers:
		so.pos = Vector2(sim.gate_center.x + randf_range(-30.0, 30.0), sim.wall_y - 30.0)
	var stones_before: int = sim.stones_dropped
	for so in tower.soldiers:
		so.pos += Vector2(0, -200.0)
	sim._drop_stones(Sim.STONE_EVERY)
	check(sim.stones_dropped == stones_before, "bowmen on the tower drop no stones")
	var cell := int(lp.x / Terrain.CELL)
	var guard = garrison_foot.soldiers[1]
	guard.pos = sim.ladder_head_post(0)
	sim._hold_ladders()
	check(sim.ladder_held[0] and is_equal_approx(sim._foot[sim.wall_row * Terrain.COLS + cell], Sim.LADDER_HELD_PACE),
		"a garrison man at a ladder's head slows the climb")
	guard.pos = Vector2(400.0, 100.0)
	sim._hold_ladders()
	check(not sim.ladder_held[0] and is_equal_approx(sim._foot[sim.wall_row * Terrain.COLS + cell], Sim.LADDER_PACE), "and an unheld ladder is climbed as before")
	sim.dispose()

	# D: the storm spreads over the wall's weak points.
	var s2 := Sim.new()
	s2.setup(_army(five, 1), _army(five, 100), 1, null, Sim.OBJECTIVE_SIEGE)
	s2.auto_deploy(Sim.PLAYER)
	s2.auto_deploy(Sim.ENEMY)
	var plan: Dictionary = s2.storm_plan(Sim.PLAYER)
	var ladders := 0
	for id in plan:
		ladders += 1 if plan[id] == "ladder" else 0
	check(ladders == 2, "with three companies on foot, one goes up each ladder and one to the ram (%d to ladders)" % ladders)
	s2.ai = [Commander.new(Sim.PLAYER), Commander.new(Sim.ENEMY)]
	s2.start_battle()
	var far := 0.0
	var samples := 0
	var held_inside := true
	var guard_sent := false
	var breach_t := -1.0
	var garrison_lost_before := -1
	while s2.winner == -1 and s2.time < 200.0:
		s2.step()
		if s2.time < 40.0 and int(s2.time * 60.0) % 30 == 0:
			for sq in s2.squads:
				if sq.team == Sim.PLAYER and sq.type == Troops.ARCHERS and sq.is_active():
					far += absf(sq.center.y - s2.wall_y)
					samples += 1
		for i in 2:
			for sq in s2.squads:
				if sq.team == Sim.ENEMY and sq.is_active() and not sq.ranged and sq.center.distance_to(s2.ladder_head_post(i)) < 60.0:
					guard_sent = true
		if s2.gate_hp <= 0.0 and breach_t < 0.0:
			breach_t = s2.time
		if breach_t >= 0.0 and s2.time - breach_t < 20.0:
			for sq in s2.squads:
				# Until it sallies (once the fight has turned its way), nobody goes out.
				if sq.team == Sim.ENEMY and sq.is_active() and not sq.routing and sq.order != "advance" \
						and not s2.inside_walls(sq.center) and absf(sq.center.y - s2.wall_y) > 20.0:
					held_inside = false
	check(samples > 0 and far / samples >= 150.0, "storming bows stand off and shoot the walls (%.0f from the wall on average)" % (far / maxf(1.0, samples)))
	check(guard_sent, "the garrison sends men to hold a ladder's head when they come up it")
	check(breach_t < 0.0 or held_inside, "after the breach the garrison holds inside its walls until the fight turns its way")
	s2.dispose()

	# The player's own garrison: Man the walls and Hold the breach.
	var s3 := Sim.new()
	s3.siege_defender = Sim.PLAYER
	s3.setup(_army(five, 1), _army(five, 100), 1, null, Sim.OBJECTIVE_SIEGE)
	s3.auto_deploy(Sim.PLAYER)
	var posted := 0
	for sq in s3.squads:
		if sq.team == Sim.PLAYER and (s3.on_walk(sq.center) or s3.on_gate_tower(sq.center)):
			posted += 1
	check(posted == 3, "Auto-place puts your garrison at its posts too (%d on the wall)" % posted)
	s3.auto_deploy(Sim.ENEMY)
	s3.start_battle()
	for sq in s3.squads:
		if sq.team == Sim.PLAYER:
			s3.order_move(sq, sq.center + Vector2(0, 150.0))
	check(s3.man_the_walls(Sim.PLAYER) == 5, "Man the walls sends every company back to its post")
	s3.gate_hp = 0.0
	var sent: Array = s3.form_breach(Sim.PLAYER)
	check(sent.size() == 2 and sent.all(func(q): return q.order == "move"), "Hold the breach sends the foot off the tower to the crescent behind the gate")
	s3.dispose()


func _check_campaign() -> void:
	gs = root.get_node("GameState")
	gs.persist = false
	gs.new_campaign(Cultures.VARDISH)
	var w = gs.world
	# A hostile castle, at war with the realm we will serve.
	var target := ""
	var employer := ""
	for id in WorldData.SETTLEMENTS:
		if String(WorldData.settlement(id)["type"]) != WorldData.CASTLE:
			continue
		for realm in ["vardmark", "kharzan", "ryumon"]:
			if realm != w.owner_of(id) and w.at_war(realm, w.owner_of(id)):
				target = id
				employer = realm
				break
		if target != "":
			break
	check(target != "", "there is a castle held by a realm at war")
	if target == "":
		return
	check(not gs.siege_check(target)["ok"] and String(gs.siege_check(target)["reason"]).contains("free company"),
		"a free company can't storm walls")
	gs.contract = {"realm": employer, "daily_pay": 50, "days_left": 30, "bonus_per_lord": 100}
	check(String(gs.siege_check(target)["reason"]).contains("Ride"), "and must ride to them first")
	var p = w.player()
	p.node = target
	p.next = ""
	p.path = []
	check(gs.siege_check(target)["ok"], "under contract, at the walls of an enemy castle, the assault can begin")
	check(not gs.siege_check(w.capital_of(employer))["ok"], "but never on the employer's own walls")

	# A failed assault leaves the garrison weaker and the castle where it was.
	var owner: String = w.owner_of(target)
	var before: int = w.men_of(w.garrisons[target])
	gs.army = gs.army.slice(0, 1)
	gs.army[0]["men"] = 3
	var r: Dictionary = gs.auto_resolve_siege(target)
	check(not r.get("won", true) and w.owner_of(target) == owner and w.men_of(w.garrisons[target]) <= before,
		"a failed assault leaves the walls with their holder")

	# A strong company takes it for its employer.
	gs.new_campaign(Cultures.VARDISH)
	w = gs.world
	gs.contract = {"realm": employer, "daily_pay": 50, "days_left": 30, "bonus_per_lord": 100}
	p = w.player()
	p.node = target
	p.next = ""
	p.path = []
	w.garrisons[target] = w.garrisons[target].slice(0, 1)
	w.garrisons[target][0]["men"] = 4
	var renown_before: int = gs.renown
	r = gs.auto_resolve_siege(target)
	check(r.get("won", false) and w.owner_of(target) == employer, "a won assault hands the castle to the employer")
	check(gs.renown > renown_before and w.activity_log.any(func(e): return e.get("type", "") == "captured"),
		"and earns renown, and the chronicle records it")
	check(not gs.siege_check(target)["ok"], "and it can't be stormed again by the side that now holds it")

	# The battle screen sets up the walls for a led assault.
	gs.new_campaign(Cultures.VARDISH)
	w = gs.world
	gs.contract = {"realm": employer, "daily_pay": 50, "days_left": 30, "bonus_per_lord": 100}
	p = w.player()
	p.node = target
	p.next = ""
	p.path = []
	gs.start_siege_battle(target)
	check(gs.pending_battle.get("objective", "") == "siege" and gs.pending_battle.get("siege_target", "") == target,
		"leading the assault sets up a siege battle")
	change_scene_to_file("res://scenes/battle.tscn")
	await process_frame
	await process_frame
	var screen = current_scene
	check(screen.sim.objective == Sim.OBJECTIVE_SIEGE and screen.sim.gate_hp > 0.0 and not screen.sim.terrain.passable(Vector2(60, Sim.WALL_Y)),
		"the battle opens with the walls up and the gate shut")
	# Fight it out (the computer leading both sides) and bring the result home.
	var bsim = screen.sim
	bsim.ai[Sim.PLAYER] = Commander.new(Sim.PLAYER)
	if bsim.phase == Sim.PHASE_DEPLOY:
		bsim.start_battle()
	while bsim.winner == -1 and bsim.time < Sim.TIME_LIMIT + 5.0:
		bsim.step()
	var res: Dictionary = screen._result()
	var held: String = w.owner_of(target)
	gs.apply_result(res)
	var landed: bool = (w.owner_of(target) == employer) if res["won"] else (w.owner_of(target) == held)
	check(landed and gs.pending_battle.is_empty(), "a led assault's result comes home (%s, %s)" % ["won" if res["won"] else "lost", res["reason"]])


## Fight `seeds` assaults on walls the player holds; how many the player held.
func _defences(defn: Array, att: Array, seeds: int) -> int:
	var held := 0
	for s in range(1, seeds + 1):
		var sim := Sim.new()
		sim.siege_defender = Sim.PLAYER
		sim.setup(_army(defn, 1), _army(att, 100), s, null, Sim.OBJECTIVE_SIEGE)
		sim.ai = [Commander.new(Sim.PLAYER), Commander.new(Sim.ENEMY)]
		sim.start_battle()
		while sim.winner == -1 and sim.time < Sim.TIME_LIMIT + 5.0:
			sim.step()
		if sim.winner == Sim.PLAYER:
			held += 1
		sim.dispose()
	return held


func _check_defence_battlefield() -> void:
	var sim := Sim.new()
	sim.siege_defender = Sim.PLAYER
	sim.setup(_army(["infantry", "archers"], 1), _army(["infantry", "infantry"], 100), 1, null, Sim.OBJECTIVE_SIEGE)
	sim.start_battle()
	var inside := true
	for sq in sim.squads:
		if sq.team == Sim.PLAYER:
			inside = inside and sim.inside_walls(sq.center)
		else:
			inside = inside and not sim.inside_walls(sq.center)
	check(sim.wall_y > Sim.MID_Y and inside, "defending, your men stand behind a wall on your side of the field")
	sim.dispose()
	var five := ["infantry", "infantry", "spearmen", "archers", "archers"]
	check(_defences(five, five, 4) >= 3, "an even assault on walls you hold mostly fails")


## An army of `realm` with two of its lords, besieging `target`.
func _army_at(w, realm: String, target: String) -> Dictionary:
	var members: Array = []
	for l in w.lords:
		var lp = w.party(int(l["party"]))
		if l["realm"] == realm and lp != null and members.size() < 2:
			lp.node = target
			lp.next = ""
			lp.path = []
			members.append(lp.id)
	var army := {"id": 900, "realm": realm, "leader": members[0], "members": members, "state": "besieging",
		"muster": w.capital_of(realm), "target": target, "target_owner": w.owner_of(target), "destination": target,
		"deadline": w.hour, "expires": w.hour + 200.0, "reason": "", "siege_prep_until": w.hour, "siege_food_until": w.hour + 100.0}
	w.campaign_armies.append(army)
	return army


func _check_army_assaults() -> void:
	gs = root.get_node("GameState")
	gs.persist = false
	gs.new_campaign(Cultures.VARDISH)
	var w = gs.world
	# Find an enemy castle and a realm at war with its holder.
	var target := ""
	var realm := ""
	for id in WorldData.SETTLEMENTS:
		if String(WorldData.settlement(id)["type"]) != WorldData.CASTLE:
			continue
		for r in ["vardmark", "kharzan", "ryumon"]:
			if r != w.owner_of(id) and w.at_war(r, w.owner_of(id)):
				target = id
				realm = r
		if target != "":
			break
	var owner: String = w.owner_of(target)

	# Riding with an army: asked to lead its assault.
	var army := _army_at(w, realm, target)
	w.following_party = int(army["leader"])
	MarshalArmies.assault(w, army)
	check(w.pending_assault.get("role", "") == "lead" and not w.busy() and w.owner_of(target) == owner,
		"riding with an army, you're asked to lead its assault, and the clock waits")
	gs.answer_assault(true)
	var allies: Array = gs.pending_battle.get("allies", [])
	check(gs.pending_battle.get("objective", "") == "siege" and not allies.is_empty() and allies.all(func(e): return e["is_ally"])
		and not bool(gs.pending_battle.get("siege_defend", false)), "leading it, the lords' men fight beside you against the garrison")
	var won := {"won": true, "lost": 5, "killed": 40, "squads": {}, "enemy_squads": {}, "objective": "siege"}
	gs.apply_result(won)
	check(w.owner_of(target) == realm and w.pending_assault.is_empty(), "a won assault hands the castle to the army's realm")

	# Declining lets the army settle it as before.
	gs.new_campaign(Cultures.VARDISH)
	w = gs.world
	army = _army_at(w, realm, target)
	w.following_party = int(army["leader"])
	MarshalArmies.assault(w, army)
	gs.answer_assault(false)
	MarshalArmies.assault(w, army)
	check(w.pending_assault.is_empty() and w.activity_log.any(func(e): return e.get("type", "") in ["captured", "siege_repulsed"]),
		"letting them storm it settles the assault without you")

	# Your own fief, stormed while you're there.
	gs.new_campaign(Cultures.VARDISH)
	w = gs.world
	w.set_owner(target, owner)
	gs.player_fief = {"settlement_id": target, "realm": owner, "silver": 0, "food": 20, "improvements": {}, "garrison": [], "granted_at": 0.0, "lost": false}
	var p = w.player()
	p.node = target
	p.next = ""
	p.path = []
	army = _army_at(w, realm, target)
	MarshalArmies.assault(w, army)
	check(w.pending_assault.get("role", "") == "defend", "an army storming your fief while you're there calls you to its walls")
	gs.answer_assault(true)
	check(bool(gs.pending_battle.get("siege_defend", false)) and gs.pending_battle["allies"].all(func(e): return bool(e.get("garrison", false)))
		and not gs.pending_battle["enemy"].is_empty(), "holding them, the garrison fights beside you against the army")
	gs.apply_result(won)
	check(w.owner_of(target) == owner and String(army["state"]) in ["returning", "disbanded"] or not w.campaign_armies.has(army),
		"holding the walls keeps your fief and sends the army home")

	# The battle screen puts your men behind the wall.
	gs.new_campaign(Cultures.VARDISH)
	w = gs.world
	gs.player_fief = {"settlement_id": target, "realm": owner, "silver": 0, "food": 20, "improvements": {}, "garrison": [], "granted_at": 0.0, "lost": false}
	p = w.player()
	p.node = target
	p.next = ""
	p.path = []
	army = _army_at(w, realm, target)
	MarshalArmies.assault(w, army)
	gs.answer_assault(true)
	change_scene_to_file("res://scenes/battle.tscn")
	await process_frame
	await process_frame
	var screen = current_scene
	check(screen.sim.objective == Sim.OBJECTIVE_SIEGE and screen.sim.siege_defender == Sim.PLAYER and screen.sim.wall_y > Sim.MID_Y,
		"the defence opens with your side behind the wall")


func _init() -> void:
	await process_frame
	_check_battlefield()
	_check_defence_battlefield()
	_check_wall_defence()
	await _check_campaign()
	await _check_army_assaults()
	print("\nSiege tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
