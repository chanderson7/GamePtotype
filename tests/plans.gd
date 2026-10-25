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

const PLANS := ["advance", "hold", "tactician"]
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


## One battle of `plan` against a commander of `temperament`. Returns
## {winner, time, margin} where margin is your men still fighting less theirs.
static func battle(plan: String, temperament: String, seed_value: int) -> Dictionary:
	var sim := Sim.new()
	sim.setup(army(seed_value), army(seed_value + 1000), seed_value)
	sim.ai[Sim.ENEMY] = Commander.new(Sim.ENEMY, temperament)
	sim.ai[Sim.ENEMY].deploy(sim)
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
		sim.step()
	var out := {"winner": sim.winner, "time": sim.time,
		"margin": sim.men_on_field(Sim.PLAYER) - sim.men_on_field(Sim.ENEMY)}
	sim.dispose()
	return out


static func _tactician(sim, state: Dictionary) -> void:
	var me := Sim.PLAYER
	var lines_met := false
	for sq in sim.squads:
		if sq.team == me and sq.is_active() and sq.engaged and not sq.ranged:
			lines_met = true
	if lines_met and state["contact_at"] < 0.0:
		state["contact_at"] = sim.time
	if not state["released"]:
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
				var prey = _flank_target(sim, sq)
				if prey != null:
					sim.order_attack(sq, prey)
				elif sq.order == "hold":
					sim.order_advance(sq)


## The enemy squad the horse should hit: archers, or one already locked in a fight with
## ours (not spearmen), nearest first.
static func _flank_target(sim, sq):
	var best = null
	var best_d := INF
	for foe in sim.squads:
		if foe.team == sq.team or not foe.is_active():
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
