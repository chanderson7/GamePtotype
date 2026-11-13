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
## A chief flees when his bodyguard is down to this share of its men; he keeps it out of
## the fight unless an enemy squad comes this close.
const CHIEF_FLEES_AT := 0.45
const CHIEF_GUARD_RANGE := 160.0
const CHIEF_BEHIND := 70.0
## Lining up on rough ground: the least rise, summed over the foot squads, worth moving the
## line for; what each unit of the move costs against that; and what cover is worth to
## archers in height.
const LINE_GAIN_MIN := 0.05
const LINE_SHIFT_COST := 0.0005
const WOODS_VANTAGE := 0.0
const WOODS_FOOTING := 0.3
## How far in front of a man in a wood the open ground must start for him to be at its edge.
const WOODS_EDGE := 45.0
const BROW_LOOK := 90.0
## A drop in the ground ahead this big makes a brow worth holding; and how long into the
## battle a commander waits on good ground before going in anyway.
const BROW_DROP := 0.1
const KEEP_GROUND_TIME := 90.0
const BROW_WEIGHT := 2.0
## A Patient commander goes in once its share of the army still fighting falls this far
## behind yours.
const PATIENT_LOSING := 0.08
## Seconds a Patient line fights braced after the first clash before the rest go in.
const RECEIVE_SECONDS := 4.0
## Cavalry that have been stuck in a melee this long wheel away to charge again.
const WHEEL_AFTER := 2.5

var team := Sim.ENEMY
var temperament := ""
var allies_only := false
## How sharp the commander is, from 0 to 1: the chance each look at a squad leads to
## using its ability when it should.
var skill := 0.6
## Seconds left to hold the line before committing.
var patience := 0.0
var committed := false
## When its foot first met yours, or -1.
var contact_at := -1.0
## How long after the gate breaks a garrison holds the breach before it sallies anyway.
const BREACH_HOLD := 45.0
## Whether this commander has sent its men to storm the walls yet.
var stormed := false
## Which company holds each ladder's head ({ladder index: squad}).
var ladder_guard := {}
## Companies this commander has sent to a post (a ladder head or the breach) and lets
## march there; and whether it has formed up to meet the breach yet.
var _posted := []
var _breach_formed := false
## Breaches in the wall this garrison has formed up to meet (by section index).
var _breaches_met := {}
## When this commander last thought about sallying, burning or bombarding.
var _engine_think := 0.0
## How long a storming commander with stone throwers at work waits for a breach before it
## goes anyway.
const BOMBARD_WAIT := 100.0
## The share of its men a storming commander keeps while it waits on its throwers.
const BOMBARD_COST := 0.9
## A garrison sallies by the postern at a stormers' engine with at most this many of them
## within SALLY_GUARD of it, and no further than SALLY_REACH from the postern.
const SALLY_GUARD := 10
const SALLY_GUARD_RANGE := 110.0
const SALLY_REACH := 420.0
var _think := 0.0


func _init(side: int = Sim.ENEMY, kind: String = "", p_allies_only: bool = false) -> void:
	team = side
	temperament = kind
	allies_only = p_allies_only


## Line up: the usual battle line, moved onto the best ground the field offers.
func deploy(sim) -> void:
	if temperament == "":
		temperament = TEMPERAMENTS[sim.rng.randi_range(0, TEMPERAMENTS.size() - 1)]
	if allies_only:
		var ally_entries: Array = sim.reserves[team].filter(func(e): return bool(e.get("is_ally", false)))
		var n: int = ally_entries.size()
		for i in n:
			var entry: Dictionary = ally_entries[i]
			var offset: float = (float(i) - float(n - 1) * 0.5) * 80.0
			var spot := Vector2(clampf(Sim.ARENA.x * 0.5 + offset, 80.0, Sim.ARENA.x - 80.0), Sim.MID_Y + 140.0)
			sim.place(team, entry["roster_id"], spot)
		return
	if sim.objective == Sim.OBJECTIVE_AMBUSH:
		committed = true
		patience = 0.0
	sim.auto_deploy(team, 26.0)
	if sim.objective != Sim.OBJECTIVE_AMBUSH:
		fit_line_to_ground(sim, team)
	_guard_the_chief(sim)

	match temperament:
		PATIENT:
			patience = PATIENT_WAIT
		HAMMER:
			patience = sim.rng.randf_range(2.0, 4.0)
		_:
			patience = sim.rng.randf_range(3.0, 8.0)


## A chief stands behind his line with his bodyguard, in the middle.
func _guard_the_chief(sim) -> void:
	var back := -1.0 if team == Sim.ENEMY else 1.0
	for sq in sim.squads:
		if sq.team == team and (sq.is_bodyguard or sq.is_chief):
			var rear := 0.0
			for other in sim.squads:
				if other.team == team and other != sq:
					rear = maxf(rear, (other.center.y - Sim.MID_Y) * back)
			sim.place(team, sq.roster_id, Vector2(Sim.ARENA.x * 0.5, Sim.MID_Y + back * (rear + CHIEF_BEHIND)))


## Move a side's whole battle line, together so it keeps its shape, to where its foot
## stand highest, or under trees, without leaving the deployment zone; then each company of archers climbs
## the highest ground near its place, or takes to a wood. Shifts forward and back are
## counted from the side's own front, left and right as the field lies (both sides line up
## from the same end), so on a field mirrored across its middle both make the same choice.
static func fit_line_to_ground(sim, team: int) -> void:
	var terrain = sim.terrain
	if terrain == null or terrain.features.is_empty():
		return
	var zone: Rect2 = sim.deploy_zone(team)
	var side := 1.0 if team == Sim.PLAYER else -1.0
	var line: Array = sim.squads.filter(func(sq): return sq.team == team)
	var best_off := Vector2.ZERO
	var best_gain := LINE_GAIN_MIN
	for dy in [-80.0, -40.0, 0.0, 40.0, 80.0, 120.0, 160.0]:
		for dx in [0.0, -40.0, 40.0, -80.0, 80.0, -120.0, 120.0, -160.0, 160.0, -200.0, 200.0, -240.0, 240.0]:
			var off := Vector2(dx, dy * side)
			var gain := 0.0
			var fits := true
			for sq in line:
				var to: Vector2 = sq.center + off
				if not zone.has_point(to) or not terrain.passable(to):
					fits = false
					break
				if sq.type == Troops.INFANTRY or sq.type == Troops.SPEARMEN:
					gain += _footing(terrain, to, side) - _footing(terrain, sq.center, side)
				elif sq.type == Troops.CAVALRY and (terrain.in_woods(_own(to, side)) or terrain.water_at(_own(to, side)) != Terrain.WATER_NONE):
					fits = false
					break
			gain -= off.length() * LINE_SHIFT_COST
			if fits and gain > best_gain:
				best_gain = gain
				best_off = off
	if best_off != Vector2.ZERO:
		for sq in line:
			sim._move_formation(sq, sq.center + best_off)
	for sq in line:
		if sq.type != Troops.ARCHERS:
			continue
		var half: Vector2 = sim._footprint(sq.type, sq.alive_count())
		var best: Vector2 = sq.center
		var best_score: float = _vantage(terrain, best) + 0.05
		for dy in [0.0, -40.0, 40.0, -80.0, 80.0, 120.0]:
			for dx in [0.0, -40.0, 40.0, -80.0, 80.0, -120.0, 120.0, -160.0, 160.0]:
				var pt: Vector2 = sq.center + Vector2(dx, dy * side)
				var score := _vantage(terrain, pt)
				if score > best_score and zone.has_point(pt) and terrain.passable(pt) and not sim._overlaps(team, pt, half, sq):
					best = pt
					best_score = score
		if best != sq.center:
			sim.place(team, sq.roster_id, best)


## How good a spot is for a line of foot to receive an attack: high, with the ground
## falling away in front of it so the enemy has to come up a slope (the brow of a hill, not
## its flat top), or just inside the edge of a wood, so the enemy attacks into the trees
## from open ground and the trees stop arrows and charges. `side` is 1 for the player,
## whose enemy comes from -y.
static func _footing(terrain, p: Vector2, side: float) -> float:
	p = _own(p, side)
	var ahead := p + Vector2(0.0, -BROW_LOOK * side)
	var drop: float = terrain.height_at(p) - terrain.height_at(ahead)
	var cover := 0.0
	if terrain.in_woods(p):
		cover = WOODS_FOOTING if not terrain.in_woods(p + Vector2(0.0, -WOODS_EDGE * side)) else WOODS_FOOTING * 0.3
	return terrain.height_at(p) + maxf(0.0, drop) * BROW_WEIGHT + cover


## A point moved a hair toward the side's own rear, so one that falls exactly on the line
## between two cells of ground counts as the cell behind it for either side, as it does
## for its mirror image.
static func _own(p: Vector2, side: float) -> Vector2:
	return p + Vector2(0.0, 0.5 * side)


## How good a spot is for bows: high, and better still under trees.
static func _vantage(terrain, p: Vector2) -> float:
	return terrain.height_at(p) + (WOODS_VANTAGE if terrain.in_woods(p) else 0.0)

func update(sim, dt: float) -> void:
	patience -= dt
	_think -= dt
	if _think > 0.0:
		return
	_think = sim.rng.randf_range(0.3, 0.6)

	# A chief runs for it once his bodyguard has been cut to pieces.
	for sq in sim.squads:
		if sq.team == team and (sq.is_bodyguard or sq.is_chief) and sq.is_active():
			if sq.alive_n < sq.start_men * CHIEF_FLEES_AT and not sq.routing:
				sim.rout(sq)

	_use_abilities(sim)
	# A garrison keeps to its walls until the gate gives, then holds the breach: it stays at
	# its posts and lets the enemy come through the gate to it, and sallies only once the
	# fight has turned its way (or nobody has come for it in a while).
	if sim.objective == Sim.OBJECTIVE_SIEGE and team == sim.siege_defender \
			and (not sim.gate_open() or (not _winning(sim) and sim.time - sim.breached_at < BREACH_HOLD)):
		if not sim.gate_open():
			_guard_ladders(sim)
			_meet_breaches(sim)
			_work_the_walls(sim)
		elif not _breach_formed:
			_breach_formed = true
			_form_breach(sim)
		for sq in sim.squads:
			if allies_only and not sq.is_ally:
				continue
			if sq.order == "move" and _posted.has(sq):
				continue
			if sq.sally_phase != "" or (sq.crew_of != null and sq.order == "move"):
				continue
			if sq.team == team and sq.is_active() and not sq.routing and sq.order != "hold" and not sq.engaged:
				sim.order_hold(sq)
		return
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

	# Storming the walls: once committed, the whole force goes at once by the storm plan,
	# ladders and ram, with the bows standing off to shoot the wall walk.
	if sim.objective == Sim.OBJECTIVE_SIEGE and team != sim.siege_defender and not allies_only \
			and not stormed and not sim.gate_open():
		# With stone throwers at work, let them bring a section down first (a while).
		if _bombarding(sim) and not _losing(sim):
			return
		stormed = true
		sim.order_storm(team)

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
		if allies_only and not sq.is_ally:
			continue
		if not allies_only and team == Sim.PLAYER and sq.is_ally:
			continue
		# The chief keeps his bodyguard back, and comes on only once the fight is going his
		# way or someone comes for him.
		if (sq.is_bodyguard or sq.is_chief) and not sq.engaged \
				and (not committed or (not _winning(sim) and sim.nearest_enemy_squad(team, sq.avg, CHIEF_GUARD_RANGE) == null)):
			continue
		# Engine crews stay at their engines.
		if sq.crew_of != null and sq.crew_of.working() and not sq.use_tower:
			continue
		if sq.type == Troops.CAVALRY and temperament != RECKLESS:
			_ride(sim, sq)
		elif sq.order == "hold" and not sq.schiltron() and not _keeps_ground(sim, sq):
			sim.order_advance(sq)


## Men on a ladder, or gathering at its foot: the nearest company on foot that isn't on the
## gate tower goes up to hold its head, and stays there.
func _guard_ladders(sim) -> void:
	for i in sim.ladder_points().size():
		var g = ladder_guard.get(i)
		if g != null and g.is_active() and not g.routing:
			continue
		ladder_guard.erase(i)
		if sim.ladder_threat(i) == 0:
			continue
		var post: Vector2 = sim.ladder_head_post(i)
		var best = null
		var best_d := INF
		for sq in sim.squads:
			if sq.team != team or not sq.is_active() or sq.routing or sq.engaged or bool(sq.stats["ranged"]) \
					or sq.type == Troops.CAVALRY or (allies_only and not sq.is_ally) or ladder_guard.values().has(sq) \
					or sim.on_gate_tower(sq.avg):
				continue
			var d: float = sq.avg.distance_to(post)
			if d < best_d:
				best_d = d
				best = sq
		if best != null:
			ladder_guard[i] = best
			_posted.append(best)
			sim.order_move(best, post)


## Whether this storming commander is waiting on its stone throwers: they're working, no
## section has come down yet, and it hasn't waited BOMBARD_WAIT.
func _bombarding(sim) -> bool:
	if sim.works == null or sim.time > BOMBARD_WAIT or sim.works.any_breach():
		return false
	# Under the walls' bolts, waiting costs men: once a tenth of them are down, go.
	if sim.men_on_field(team) + sim.reserve_men(team) < int(float(sim.start_men(team)) * BOMBARD_COST):
		return false
	for e in sim.works.engines:
		if e.team == team and e.kind == sim.works.THROWER and e.working() and sim.works.manned(e):
			return true
	return false


## A section of the wall has come down: free foot form a crescent behind it, as at the gate.
func _meet_breaches(sim) -> void:
	if sim.works == null:
		return
	for i in sim.works.sections.size():
		if not sim.works.sections[i]["broken"] or _breaches_met.has(i):
			continue
		_breaches_met[i] = true
		_posted.append_array(sim.form_breach(team, allies_only, sim.works.section_center(i)))


## The walls' engines, every few seconds: bows on the walk set the moving tower alight,
## and a company of foot slips out by the postern at a stone thrower the stormers have left
## unguarded.
func _work_the_walls(sim) -> void:
	if sim.works == null or allies_only:
		return
	_engine_think -= 0.5
	if _engine_think > 0.0:
		return
	_engine_think = 3.0
	var works = sim.works
	# Fire.
	# (The ram is left to the oil and stones: bows shooting fire at it aren't shooting
	# the men under it.)
	var mark = works.tower_of(1 - team)
	if mark != null and mark.docked:
		mark = null
	var burning_already := false
	for sq in sim.squads:
		if sq.team == team and sq.burn_target != null and sq.is_active():
			burning_already = true
			if mark == null or sq.burn_target != mark:
				sim.order_burn(sq, null)
	if mark != null and not burning_already:
		var best = null
		var best_d: float = works.FIRE_RANGE
		for sq in sim.squads:
			if sq.team != team or not sq.is_active() or not sq.ranged or sq.arrows == 0:
				continue
			var d: float = sq.avg.distance_to(mark.pos)
			if d < best_d:
				best_d = d
				best = sq
		if best != null:
			sim.order_burn(best, mark)
	# A sally.
	if not works.has_postern():
		return
	for sq in sim.squads:
		if sq.team == team and sq.sally_phase != "":
			return
	var door: Vector2 = works.postern_points()[1]
	var target = null
	for e in works.engines:
		if e.team == team or not e.working() or not (e.kind in [works.THROWER, works.TOWER]) or e.pos.distance_to(door) > SALLY_REACH:
			continue
		var guards := 0
		for o in sim.squads:
			if o.team != team and o.is_active():
				for so in o.soldiers:
					if so.alive and so.pos.distance_to(e.pos) < SALLY_GUARD_RANGE:
						guards += 1
		if guards <= SALLY_GUARD:
			target = e
			break
	if target == null:
		return
	var best_sq = null
	for sq in sim.squads:
		if sq.team != team or not sq.is_active() or sq.engaged or sq.ranged or sq.type == Troops.CAVALRY \
				or sim.on_gate_tower(sq.avg) or ladder_guard.values().has(sq) or sq.crew_of != null:
			continue
		if best_sq == null or sq.alive_n > best_sq.alive_n:
			best_sq = sq
	if best_sq != null:
		sim.order_sally(best_sq, target)


## The gate has given: the companies on foot not already fighting fall back to the
## crescent behind it (see BattleSim.form_breach).
func _form_breach(sim) -> void:
	_posted.append_array(sim.form_breach(team, allies_only))


## A commander who isn't reckless makes the enemy come to him, for the first part of the
## battle: his foot stays on good ground (in a wood, or on a brow with the ground falling
## away in front), and nobody but the horse wades a river to get at the enemy.
func _keeps_ground(sim, sq) -> bool:
	if temperament == RECKLESS or sq.type == Troops.CAVALRY or sim.terrain == null or sim.time > KEEP_GROUND_TIME:
		return false
	var p: Vector2 = sq.avg
	var foe = sim.nearest_enemy_squad(team, p, INF)
	if foe == null:
		return false
	if wet_between(sim.terrain, p, foe.avg):
		return true
	if sq.ranged:
		return false
	var side := 1.0 if team == Sim.PLAYER else -1.0
	return sim.terrain.in_woods(p) \
			or sim.terrain.height_at(p) - sim.terrain.height_at(p + Vector2(0.0, -BROW_LOOK * side)) > BROW_DROP


## Whether there's a ford or deep water anywhere on the straight way from `a` to `b`.
static func wet_between(terrain, a: Vector2, b: Vector2) -> bool:
	var steps := maxi(1, int(a.distance_to(b) / 15.0))
	for i in steps + 1:
		if terrain.water_at(a.lerp(b, float(i) / steps)) != Terrain.WATER_NONE:
			return true
	return false


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
		if allies_only and not sq.is_ally:
			continue
		if not allies_only and team == Sim.PLAYER and sq.is_ally:
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


func _winning(sim) -> bool:
	return sim.strength(team) > sim.strength(1 - team) + PATIENT_LOSING
