## Commands one side of a battle. Every commander lines up in a battle line and uses its
## squads' abilities; its temperament decides when it commits and what its horse does.
## Advancing squads pick their own targets in the sim, so the computer uses the same
## orders you do.
extends RefCounted

const Sim = preload("res://scripts/battle/battle_sim.gd")
const Troops = preload("res://scripts/data/troops.gd")
const Terrain = preload("res://scripts/battle/terrain.gd")

## Waits a few seconds, then everything goes straight in.
const RECKLESS := "Reckless"
## Holds a braced line under its archers and makes you come. Takes your charge on its
## braced line, then sends in everything else; goes in first only when the archery turns
## against it or it runs out of patience.
const PATIENT := "Patient"
## Foot goes in to pin your line while the horse swings wide for your archers and flanks.
const HAMMER := "Hammer"
const TEMPERAMENTS := [RECKLESS, PATIENT, HAMMER]
## What your scouts say about each, on the deployment screen.
const SCOUTING := {
	RECKLESS: "Their commander is reckless: expect a headlong attack.",
	PATIENT: "Their commander is patient: they'll hold and make you come.",
	HAMMER: "Their commander fights hammer and anvil: watch your flanks.",
}

## While holding before the advance, the whole army goes in if an enemy gets this close.
const REACT_RANGE := 260.0
## Seconds a Patient commander will wait for you.
const PATIENT_WAIT := 30.0
## A Patient commander goes in once its share of the army still fighting falls this far
## behind yours.
const PATIENT_LOSING := 0.08
## Seconds a Patient line fights braced after the first clash before the rest go in.
const RECEIVE_SECONDS := 4.0
## Cavalry that have been stuck in a melee this long wheel away to charge again.
const WHEEL_AFTER := 2.5

var team := Sim.ENEMY
var temperament := ""
## How sharp the commander is, from 0 to 1: the chance each look at a squad leads to
## using its ability when it should.
var skill := 0.6
## Seconds left to hold the line before committing.
var patience := 0.0
var committed := false
## When its foot first met yours, or -1.
var contact_at := -1.0
var _think := 0.0


func _init(side: int = Sim.ENEMY, kind: String = "") -> void:
	team = side
	temperament = kind


## Place the whole army using terrain scoring (high ground and woods for archers,
## hills/edges for foot, keeping horse clear of woods), falling back to auto_deploy.
func deploy(sim) -> void:
	if temperament == "":
		temperament = TEMPERAMENTS[sim.rng.randi_range(0, TEMPERAMENTS.size() - 1)]
	if sim.objective == Sim.OBJECTIVE_AMBUSH:
		committed = true
		patience = 0.0
	if sim.terrain != null and not sim.terrain.features.is_empty():
		_deploy_terrain(sim)
	if not sim.all_placed(team):
		sim.auto_deploy(team, 26.0)

	match temperament:
		PATIENT:
			patience = PATIENT_WAIT
		HAMMER:
			patience = sim.rng.randf_range(2.0, 4.0)
		_:
			patience = sim.rng.randf_range(3.0, 8.0)


func _deploy_terrain(sim) -> void:
	var zone: Rect2 = sim.deploy_zone(team)
	var terrain = sim.terrain
	var reserves_copy := sim.reserves[team].duplicate()

	# Archers first for best vantage, foot next, cavalry on open flanks
	reserves_copy.sort_custom(func(a, b):
		var priority := {Troops.ARCHERS: 0, Troops.SPEARMEN: 1, Troops.INFANTRY: 2, Troops.CAVALRY: 3}
		return priority.get(a["type"], 4) < priority.get(b["type"], 4)
	)

	var step := 50.0
	var candidates: Array = []
	var y := zone.position.y + 20.0
	while y < zone.position.y + zone.size.y - 20.0:
		var x := zone.position.x + 30.0
		while x < zone.position.x + zone.size.x - 30.0:
			var pt := Vector2(x, y)
			if terrain.passable(pt):
				candidates.append(pt)
			x += step
		y += step

	for entry in reserves_copy:
		var type: String = entry["type"]
		var best_spot = null
		var best_score := -INF
		var half := sim._footprint(type, entry["men"])

		for pt in candidates:
			var score := _score_spot(sim, terrain, pt, type)
			if score > best_score:
				if not sim._overlaps(team, pt, half, null) and terrain.passable(pt):
					best_score = score
					best_spot = pt

		if best_spot != null:
			sim.place(team, entry["roster_id"], best_spot)


func _score_spot(sim, terrain, pt: Vector2, type: String) -> float:
	var h: float = terrain.height_at(pt)
	var in_w: bool = terrain.in_woods(pt)
	var score := 0.0

	var front_y := sim.MID_Y - sim.DEPLOY_GAP if team == Sim.ENEMY else sim.MID_Y + sim.DEPLOY_GAP
	var dist_to_front := absf(pt.y - front_y)

	match type:
		Troops.ARCHERS:
			score += h * 300.0
			score += dist_to_front * 0.4
			if in_w:
				score += 60.0

		Troops.INFANTRY, Troops.SPEARMEN:
			score += h * 200.0
			score -= dist_to_front * 0.8
			if in_w:
				score += 20.0

		Troops.CAVALRY:
			if in_w:
				score -= 600.0
			if terrain.water_at(pt) != Terrain.WATER_NONE:
				score -= 600.0
			var flank_dist := minf(pt.x, sim.ARENA.x - pt.x)
			if flank_dist < 220.0:
				score += 100.0

	if temperament == PATIENT:
		for feat in terrain.features:
			if feat.get("type") == "river":
				for fx in feat.get("fords", []):
					if absf(pt.x - fx) < 90.0 and dist_to_front < 120.0:
						score += 160.0
			elif feat.get("type") == "hill":
				var c: Vector2 = feat.get("center", Vector2.ZERO)
				if pt.distance_to(c) < feat.get("radius", 100.0) * 0.5:
					score += 150.0

	return score


func update(sim, dt: float) -> void:
	patience -= dt
	_think -= dt
	if _think > 0.0:
		return
	_think = sim.rng.randf_range(0.3, 0.6)

	# In chief objective, chief flees early when hurt
	for sq in sim.squads:
		if sq.team == team and (sq.is_bodyguard or sq.is_chief) and sq.is_active():
			if sq.alive_n < sq.start_men * 0.45 or sq.morale < 45.0:
				if not sq.routing:
					sq.routing = true
					sq.focus = null
					sq.wheeling = false
					sq.ability_left = 0.0
					sim.events.append({"type": "rout", "squad": sq})
					sim._trigger_chief_shock(sq)

	_use_abilities(sim)
	if contact_at < 0.0 and _in_contact(sim):
		contact_at = sim.time
	if not committed:
		if sim.objective == Sim.OBJECTIVE_AMBUSH:
			committed = true
		elif temperament == PATIENT:
			committed = patience <= 0.0 or _losing(sim) or (contact_at >= 0.0 and sim.time - contact_at > RECEIVE_SECONDS)
		else:
			committed = patience <= 0.0 or _enemy_close(sim)
		if not committed:
			return

	# In village objective, attackers advance toward the village circle
	if sim.objective == Sim.OBJECTIVE_VILLAGE and team == Sim.ENEMY:
		for sq in sim.squads:
			if sq.team == team and sq.is_active() and not sq.routing and not sq.engaged:
				if sq.order != "attack" and sq.center.distance_to(Sim.VILLAGE_ZONE_CENTER) > 50.0:
					sq.order = "move"
					sq.order_point = Sim.VILLAGE_ZONE_CENTER

	for sq in sim.squads:
		if sq.team != team or not sq.is_active() or sq.wheeling:
			continue
		if (sq.is_bodyguard or sq.is_chief) and not committed and not sq.engaged:
			continue
		if sq.type == Troops.CAVALRY and temperament != RECKLESS:
			_ride(sim, sq)
		elif sq.order == "hold" and not sq.schiltron():
			sim.order_advance(sq)


## Once the lines have met, horse goes for archers first, then for an enemy squad already
## locked in a fight with one of ours, so the charge lands in its flank or rear.
func _ride(sim, sq) -> void:
	if contact_at < 0.0:
		return
	if sq.order == "attack" and sq.order_target != null and sq.order_target.is_active():
		return
	var prey = null
	var best := INF
	for foe in sim.squads:
		if foe.team == team or not foe.is_active():
			continue
		var score: float = sq.avg.distance_to(foe.avg)
		if foe.type == Troops.ARCHERS:
			score -= 250.0
		elif not foe.engaged or foe.type == Troops.SPEARMEN:
			continue
		if sim.terrain != null:
			if sim.terrain.in_woods(foe.avg):
				score += 300.0
			if sim.terrain.water_at(foe.avg) != Terrain.WATER_NONE:
				score += 400.0
		if score < best:
			best = score
			prey = foe
	if prey != null:
		sim.order_attack(sq, prey)
	elif sq.order == "hold":
		sim.order_advance(sq)


func _use_abilities(sim) -> void:
	for sq in sim.squads:
		if sq.team != team or not sim.ability_ready(sq) or sim.rng.randf() > skill:
			continue
		match sq.type:
			Troops.INFANTRY:
				if sq.under_fire > 0.0 and not sq.engaged:
					sim.use_ability(sq)
			Troops.SPEARMEN:
				if _horse_near(sim, sq, 150.0) and not sq.engaged:
					sim.use_ability(sq)
			Troops.ARCHERS:
				sim.use_ability(sq)
			Troops.CAVALRY:
				if sq.engaged and sq.engaged_for > WHEEL_AFTER and sq.focus != null and sq.focus.type != Troops.ARCHERS:
					sim.use_ability(sq)


func _horse_near(sim, sq, dist: float) -> bool:
	for foe in sim.squads:
		if foe.team != team and foe.is_active() and foe.type == Troops.CAVALRY and foe.avg.distance_to(sq.avg) < dist:
			return true
	return false


func _enemy_close(sim) -> bool:
	for sq in sim.squads:
		if sq.team == team and sq.is_active() and sim.nearest_enemy_squad(team, sq.average_pos(), REACT_RANGE) != null:
			return true
	return false


func _in_contact(sim) -> bool:
	for sq in sim.squads:
		if sq.team == team and sq.is_active() and sq.engaged and not sq.ranged:
			return true
	return false


func _losing(sim) -> bool:
	return sim.strength(team) < sim.strength(1 - team) - PATIENT_LOSING
