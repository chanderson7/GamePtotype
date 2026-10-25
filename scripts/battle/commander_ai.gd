## Commands one side of a battle. Lines the army up during deployment, holds the line
## for a few seconds, then advances with everything at once. It goes early if the enemy
## comes close first. Advancing squads pick their own targets in the sim (each goes for
## the enemy it fights best), so the computer uses the same orders you do.
extends RefCounted

const Sim = preload("res://scripts/battle/battle_sim.gd")

## While holding before the advance, the whole army goes in if an enemy gets this close.
const REACT_RANGE := 260.0

var team := Sim.ENEMY
## Seconds left to hold the line before advancing. INF means hold until the enemy comes.
var patience := 0.0
var _think := 0.0


func _init(side: int = Sim.ENEMY) -> void:
	team = side


## Place the whole army in a battle line, a little differently each time.
func deploy(sim) -> void:
	sim.auto_deploy(team, 26.0)
	patience = sim.rng.randf_range(3.0, 8.0)


func update(sim, dt: float) -> void:
	patience -= dt
	_think -= dt
	if _think > 0.0:
		return
	_think = sim.rng.randf_range(0.3, 0.6)
	if patience > 0.0 and not _enemy_close(sim):
		return
	patience = 0.0
	for sq in sim.squads:
		if sq.team == team and sq.is_active() and sq.order == "hold":
			sim.order_advance(sq)


func _enemy_close(sim) -> bool:
	for sq in sim.squads:
		if sq.team == team and sq.is_active() and sim.nearest_enemy_squad(team, sq.average_pos(), REACT_RANGE) != null:
			return true
	return false
