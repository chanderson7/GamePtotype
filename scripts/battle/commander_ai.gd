## Commands one side of a battle. Every commander lines up in a battle line and uses its
## squads' abilities; its temperament decides when it commits and what its horse does.
## Advancing squads pick their own targets in the sim, so the computer uses the same
## orders you do.
extends RefCounted

const Sim = preload("res://scripts/battle/battle_sim.gd")
const Troops = preload("res://scripts/data/troops.gd")

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


## Place the whole army in a battle line, a little differently each time.
func deploy(sim) -> void:
	if temperament == "":
		temperament = TEMPERAMENTS[sim.rng.randi_range(0, TEMPERAMENTS.size() - 1)]
	sim.auto_deploy(team, 26.0)
	match temperament:
		PATIENT:
			patience = PATIENT_WAIT
		HAMMER:
			patience = sim.rng.randf_range(2.0, 4.0)
		_:
			patience = sim.rng.randf_range(3.0, 8.0)


func update(sim, dt: float) -> void:
	patience -= dt
	_think -= dt
	if _think > 0.0:
		return
	_think = sim.rng.randf_range(0.3, 0.6)
	_use_abilities(sim)
	if contact_at < 0.0 and _in_contact(sim):
		contact_at = sim.time
	if not committed:
		if temperament == PATIENT:
			committed = patience <= 0.0 or _losing(sim) or (contact_at >= 0.0 and sim.time - contact_at > RECEIVE_SECONDS)
		else:
			committed = patience <= 0.0 or _enemy_close(sim)
		if not committed:
			return
	for sq in sim.squads:
		if sq.team != team or not sq.is_active() or sq.wheeling:
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
