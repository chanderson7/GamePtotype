## Scripted players for the balance check, each fighting the computer with the same army.
##   advance    presses Advance all and nothing else
##   hold       presses Hold all and nothing else
##   tactician  plays the way the game is meant to be played: takes the enemy's charge on
##              a braced line, then sends in everything else; lets the bows and volleys
##              work, and pushes the bows forward if the enemy won't come; raises shields
##              under fire; rings the spears when horse come near; and sends its own horse
##              into the flank of whatever is locked in a fight, wheeling away to charge again
extends RefCounted

const Sim = preload("res://scripts/battle/battle_sim.gd")
const Commander = preload("res://scripts/battle/commander_ai.gd")
const Troops = preload("res://scripts/data/troops.gd")
const Captains = preload("res://scripts/data/captains.gd")
const Cultures = preload("res://scripts/data/cultures.gd")
const WorldData = preload("res://scripts/world/world_data.gd")
const Economy = preload("res://scripts/data/economy.gd")
const Terrain = preload("res://scripts/battle/terrain.gd")
const Units = preload("res://scripts/data/units.gd")

const PLANS := ["advance", "hold", "tactician", "terrain"]
## The tactician's line fights braced this long after the first clash before the rest go
## in. It waits out a patient enemy, and only goes in first after RELEASE_AFTER. Its
## archers step back when enemy foot come within KITE_RANGE.
const RECEIVE_SECONDS := 3.0
const RELEASE_AFTER := 45.0
const KITE_RANGE := 120.0
const KITE_STEP := 110.0


## Seven squads with captains, the same mix the warband starts with, shuffled by seed.
static func army(seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919
	var out := []
	var id := 1
	for type in [Troops.INFANTRY, Troops.INFANTRY, Troops.SPEARMEN, Troops.SPEARMEN, Troops.ARCHERS, Troops.ARCHERS, Troops.CAVALRY]:
		out.append({"id": id, "type": type, "men": Troops.full_size(type), "xp": 0,
			"captain": Captains.make(rng, seed_value * 100 + id, type)})
		id += 1
	for i in range(out.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = out[i]
		out[i] = out[j]
		out[j] = tmp
	return out


## The army the enemy brings to an objective. A chief leads a bodyguard of trained men in
## place of one of his companies of foot, so the armies stay as strong as each other.
## Raiders far outnumber you, but come in waves: you can't beat them all, only hold the
## village until they give up.
static func foe_army(seed_value: int, objective: String = "rout") -> Array:
	var out := army(seed_value + 1000)
	if objective == "village":
		var more := [Troops.INFANTRY, Troops.SPEARMEN, Troops.ARCHERS, Troops.INFANTRY, Troops.SPEARMEN]
		for i in more.size():
			out.append({"id": 50 + i, "type": more[i], "men": Troops.full_size(more[i]), "xp": 0})
	if objective == "chief":
		for e in out:
			if e["type"] == Troops.INFANTRY:
				e["unit"] = Units.branches(Units.recruit(Cultures.VARDISH, Troops.INFANTRY))[0]
				e["men"] = 16
				e["level"] = 2
				e["xp"] = Troops.XP_PER_LEVEL
				e["is_bodyguard"] = true
				e["is_chief"] = true
				e["chief_name"] = "Rask the Red"
				break
	return out


## Seven trained squads of a culture, the warband's usual mix, each one of its tier-2
## branches: both branches of a role where it fields two squads, one picked by seed where
## it fields one.
static func culture_army(cult: String, seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919
	var out := []
	var id := 1
	var seen := {}
	for type in [Troops.INFANTRY, Troops.INFANTRY, Troops.SPEARMEN, Troops.SPEARMEN, Troops.ARCHERS, Troops.ARCHERS, Troops.CAVALRY]:
		var branches: Array = Units.branches(Units.recruit(cult, type))
		var nth: int = seen.get(type, seed_value)
		seen[type] = nth + 1
		var unit_id: String = branches[nth % branches.size()]
		out.append({
			"id": id, "type": type, "unit": unit_id, "culture": cult, "level": 2,
			"men": Units.full_size(unit_id), "xp": Troops.XP_PER_LEVEL,
			"captain": Captains.make(rng, seed_value * 100 + id, type, [], cult)
		})
		id += 1
	for i in range(out.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = out[i]
		out[i] = out[j]
		out[j] = tmp
	return out


## One battle of `plan` against a commander of `temperament`. Returns
## {winner, time, margin} where margin is your men still fighting less theirs.
static func battle(plan: String, temperament: String, seed_value: int, site = null, objective: String = "rout") -> Dictionary:
	var sim := Sim.new()
	sim.setup(army(seed_value), foe_army(seed_value, objective), seed_value, site, objective)
	sim.ai[Sim.ENEMY] = Commander.new(Sim.ENEMY, temperament)
	sim.ai[Sim.ENEMY].deploy(sim)
	if plan == "terrain" and sim.terrain != null and not sim.terrain.features.is_empty():
		_deploy_terrain_player(sim)
	else:
		sim.auto_deploy(Sim.PLAYER)
	sim.start_battle()
	if plan == "advance":
		sim.order_all(Sim.PLAYER, "advance")
	var state := {"released": false, "contact_at": -1.0}
	var think := 0.0
	while sim.winner == -1 and sim.time < Sim.TIME_LIMIT + 5.0:
		if plan == "tactician":
			think -= Sim.STEP
			if think <= 0.0:
				think = 0.5
				_tactician(sim, state)
		elif plan == "terrain":
			think -= Sim.STEP
			if think <= 0.0:
				think = 0.5
				_terrain_plan(sim, state)
		sim.step()
	var out := {"winner": sim.winner, "time": sim.time,
		"margin": sim.men_on_field(Sim.PLAYER) - sim.men_on_field(Sim.ENEMY)}
	sim.dispose()
	return out


## An army `more` times stronger than the enemy's (1.15: 15% more men in every squad)
## pressing Advance all against a commander of `temperament`, who lines up on whatever
## ground `site` gives him. Returns {winner, margin}.
static func attack(more: float, temperament: String, seed_value: int, site = null) -> Dictionary:
	var mine := army(seed_value)
	for e in mine:
		e["men"] = int(round(float(e["men"]) * more))
	var sim := Sim.new()
	sim.setup(mine, army(seed_value + 1000), seed_value, site)
	sim.ai[Sim.ENEMY] = Commander.new(Sim.ENEMY, temperament)
	sim.ai[Sim.ENEMY].deploy(sim)
	sim.auto_deploy(Sim.PLAYER)
	sim.start_battle()
	sim.order_all(Sim.PLAYER, "advance")
	while sim.winner == -1 and sim.time < Sim.TIME_LIMIT + 5.0:
		sim.step()
	var out := {"winner": sim.winner, "margin": sim.men_on_field(Sim.PLAYER) - sim.men_on_field(Sim.ENEMY)}
	sim.dispose()
	return out


static func _tactician(sim, state: Dictionary) -> void:
	var me := Sim.PLAYER
	if sim.objective == Sim.OBJECTIVE_AMBUSH and not state.has("faced"):
		# Ambushed: no line to receive them on, so go for them at once, before the trap
		# closes.
		state["faced"] = true
		state["released"] = true
		for sq in sim.squads:
			if sq.team == me and not sq.ranged:
				# Out of column: the squad spreads to its full width where it stands, then goes.
				var foe = sim.nearest_enemy_squad(me, sq.center, INF)
				var across: Vector2 = (foe.center - sq.center).normalized().orthogonal() if foe != null else Vector2.RIGHT
				sim.order_line(me, sq.center - across * 60.0, sq.center + across * 60.0, sq)
				sim.order_advance(sq)
	if sim.objective == Sim.OBJECTIVE_VILLAGE and not state.has("square"):
		# Defending a village: the line forms across the square and stays in it, and the
		# raiders have to come to it, wave by wave.
		state["square"] = true
		var c: Vector2 = Sim.VILLAGE_ZONE_CENTER
		sim.order_line(me, c + Vector2(-Sim.VILLAGE_ZONE_RADIUS, 30.0), c + Vector2(Sim.VILLAGE_ZONE_RADIUS, 30.0))
	var lines_met := false
	for sq in sim.squads:
		if sq.team == me and sq.is_active() and sq.engaged and not sq.ranged:
			lines_met = true
	if lines_met and state["contact_at"] < 0.0:
		state["contact_at"] = sim.time
	if not state["released"] and sim.objective != Sim.OBJECTIVE_VILLAGE:
		var met: float = state["contact_at"]
		state["released"] = (met >= 0.0 and sim.time - met > RECEIVE_SECONDS) or sim.time > RELEASE_AFTER
	for sq in sim.squads:
		if sq.team != me or not sq.is_active():
			continue
		match sq.type:
			Troops.ARCHERS:
				if sim.ability_ready(sq):
					sim.use_ability(sq)
				var threat = _foot_near(sim, sq, KITE_RANGE)
				if threat != null and threat.focus == sq and sq.ranged and sq.order != "move":
					var back: Vector2 = (sq.avg - threat.avg).normalized() * KITE_STEP
					sim.order_move(sq, sq.avg + back)
				elif state["released"] and sq.order == "hold":
					sim.order_advance(sq)
			Troops.INFANTRY:
				if sq.under_fire > 0.0 and not sq.engaged and sim.ability_ready(sq):
					sim.use_ability(sq)
				if state["released"] and sq.order == "hold":
					sim.order_advance(sq)
			Troops.SPEARMEN:
				if not sq.engaged and sim.ability_ready(sq) and _horse_near(sim, sq, 150.0):
					sim.use_ability(sq)
				elif state["released"] and sq.order == "hold" and not sq.schiltron():
					sim.order_advance(sq)
			Troops.CAVALRY:
				if sq.wheeling:
					continue
				if sq.engaged and sq.engaged_for > 2.0 and sim.ability_ready(sq) and sq.focus != null \
						and sq.focus.type != Troops.ARCHERS:
					sim.use_ability(sq)
					continue
				if not lines_met:
					continue
				if sq.order == "attack" and sq.order_target != null and sq.order_target.is_active():
					continue
				var prey = _chief(sim) if sim.objective == Sim.OBJECTIVE_CHIEF else null
				if prey == null:
					prey = _flank_target(sim, sq)
				if prey != null:
					sim.order_attack(sq, prey)
				elif sq.order == "hold":
					sim.order_advance(sq)


## The usual line, moved onto the best ground the field offers, the way the computer
## lines up.
static func _deploy_terrain_player(sim) -> void:
	sim.auto_deploy(Sim.PLAYER)
	Commander.fit_line_to_ground(sim, Sim.PLAYER)


## The tactician, using the ground: on a ridge its foot takes the crest first; nobody but
## the horse goes at an enemy across water or up a slope, so the enemy has to come to
## them; the horse doesn't ride into woods or water.
static func _terrain_plan(sim, state: Dictionary) -> void:
	_tactician(sim, state)
	var terrain = sim.terrain
	if terrain == null or terrain.features.is_empty():
		return
	if not state.has("crest"):
		state["crest"] = true
		for feat in terrain.features:
			if feat.get("type", "") == "ridge":
				for sq in sim.squads:
					if sq.team == Sim.PLAYER and (sq.type == Troops.INFANTRY or sq.type == Troops.SPEARMEN):
						sim.order_move(sq, Vector2(sq.center.x, float(feat["y"]) + 30.0))
	for sq in sim.squads:
		if sq.team != Sim.PLAYER or not sq.is_active() or sq.engaged:
			continue
		if sq.type == Troops.CAVALRY:
			if sq.order == "attack" and sq.order_target != null and _bad_ground_for_horse(terrain, sq.order_target.avg):
				var alt = _flank_target(sim, sq, true)
				if alt != null:
					sim.order_attack(sq, alt)
				else:
					sim.order_hold(sq)
			continue
		if sq.order != "advance":
			continue
		var foe = sq.focus if sq.focus != null else sim.nearest_enemy_squad(Sim.PLAYER, sq.avg, 2000.0)
		if foe == null:
			continue
		var uphill: float = terrain.height_at(foe.avg) - terrain.height_at(sq.avg)
		if uphill > 0.12 or Commander.wet_between(terrain, sq.avg, foe.avg):
			sim.order_hold(sq)


static func _bad_ground_for_horse(terrain, p: Vector2) -> bool:
	return terrain.in_woods(p) or terrain.water_at(p) != Terrain.WATER_NONE


## The enemy chief's bodyguard, while it's still in the fight.
static func _chief(sim):
	for foe in sim.squads:
		if foe.team != Sim.PLAYER and (foe.is_bodyguard or foe.is_chief) and foe.is_active():
			return foe
	return null


## The enemy squad the horse should hit: archers, or one already locked in a fight with
## ours (not spearmen), nearest first.
static func _flank_target(sim, sq, mind_ground: bool = false):
	var best = null
	var best_d := INF
	for foe in sim.squads:
		if foe.team == sq.team or not foe.is_active():
			continue
		if mind_ground and _bad_ground_for_horse(sim.terrain, foe.avg):
			continue
		if foe.type != Troops.ARCHERS and (not foe.engaged or foe.type == Troops.SPEARMEN):
			continue
		var d: float = sq.avg.distance_to(foe.avg) - (200.0 if foe.type == Troops.ARCHERS else 0.0)
		if d < best_d:
			best_d = d
			best = foe
	return best


## The nearest enemy squad of foot within `dist` of `sq`, or null. Horse are too fast
## to step away from.
static func _foot_near(sim, sq, dist: float):
	var best = null
	var best_d := dist
	for foe in sim.squads:
		if foe.team == sq.team or not foe.is_active() or foe.ranged or foe.type == Troops.CAVALRY:
			continue
		var d: float = foe.avg.distance_to(sq.avg) - foe.extent - sq.extent
		if d < best_d:
			best_d = d
			best = foe
	return best


static func _horse_near(sim, sq, dist: float) -> bool:
	for foe in sim.squads:
		if foe.team != sq.team and foe.is_active() and foe.type == Troops.CAVALRY and foe.avg.distance_to(sq.avg) < dist:
			return true
	return false


# ---------------------------------------------------------------- campaigns

## A scripted campaign of `days` days, settling every fight with auto-resolve: ride at
## the nearest bandit band; in towns, reinforce, train, and hire while under the squad
## cap with silver to spare; buy food anywhere when it runs low. Returns how it went:
## {silver, men, squads, renown, fights, won, desertion_days, broke_days}.
static func campaign(seed_value: int, days: int) -> Dictionary:
	const GameStateScript = preload("res://scripts/game_state.gd")
	var gs = GameStateScript.new()
	gs.persist = false
	gs.rng.seed = seed_value
	gs.new_campaign(Cultures.ORDER[seed_value % 3])
	var w = gs.world
	var fights := 0
	var won := 0
	var desertion_days := 0
	var broke_days := 0
	var lowest_men := gs.total_men()
	var guard := 0
	while w.hour < days * 24.0 and guard < 50000 and gs.total_men() > 0:
		guard += 1
		gs.map_notice = ""
		if w.encounter != -1:
			fights += 1
			if gs.auto_resolve_encounter().get("won", false):
				won += 1
		elif not w.busy():
			var here: String = w.here()
			if here != "":
				_shop(gs, here)
			var target := ""
			var best := INF
			for b in w.bands():
				var at: String = b.next if b.moving() else b.node
				var h: float = w.hours_to(at)
				if at != here and h < best:
					best = h
					target = at
			# Short of men or food: stop at the nearest town first.
			if gs.food_days() < 2 or (gs.is_wounded() and gs.silver > gs.daily_wages() * 2 + 100 and not w.player_in_town()):
				target = _nearest_town(w)
			if target == "" or target == here or not w.travel(target):
				w.wait(4.0)
		var day_before: int = int(w.hour / 24.0)
		gs.advance(1.0)
		if gs.map_notice.contains("left the warband"):
			desertion_days += 1
		if int(w.hour / 24.0) != day_before and gs.silver < 20:
			broke_days += 1
		lowest_men = mini(lowest_men, gs.total_men())
	var out := {"silver": gs.silver, "men": gs.total_men(), "squads": gs.army.size(), "renown": gs.renown,
		"fights": fights, "won": won, "desertion_days": desertion_days, "broke_days": broke_days,
		"lowest_men": lowest_men, "cap": gs.squad_cap()}
	gs.free()
	return out


static func _shop(gs, here: String) -> void:
	var w = gs.world
	# Keep two days' wages in hand; spend the rest.
	var reserve: int = gs.daily_wages() * 2
	if gs.food_days() < 4:
		var want: int = gs.total_men() * 5 - gs.food
		while want > 0 and not gs.buy_food(want):
			want /= 2
	# Fill the ranks first; then a new squad when renown allows one and there's silver to
	# keep it, and training with what's left.
	if w.player_in_town():
		gs.reinforce(maxi(0, gs.silver - reserve))
	var offers: Array = w.offers_at(here)
	if gs.army.size() < gs.squad_cap() and not offers.is_empty():
		var cost := Economy.recruit_cost(offers[0]["type"], Troops.full_size(offers[0]["type"]))
		if gs.silver - reserve - cost > 250:
			gs.hire(here, 0)
	if w.player_in_town():
		for s in gs.army.duplicate():
			if gs.can_train(s) and gs.silver - reserve > 300:
				gs.train_squad(int(s["id"]))


static func _nearest_town(w) -> String:
	var best := ""
	var best_h := INF
	for id in WorldData.SETTLEMENTS:
		if WorldData.SETTLEMENTS[id]["type"] == WorldData.TOWN:
			var h: float = 0.0 if id == w.here() else w.hours_to(id)
			if h < best_h:
				best_h = h
				best = id
	return best
