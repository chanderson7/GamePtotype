## Deploys squads for one side of a battle. Reads the field, answers the most
## dangerous enemy squad with its counter, and spends its meter before it overflows.
extends RefCounted

const Sim = preload("res://scripts/battle/battle_sim.gd")
const Troops = preload("res://scripts/data/troops.gd")

var team := Sim.ENEMY
var _think := 1.5


func _init(side: int = Sim.ENEMY) -> void:
	team = side


func update(sim, dt: float) -> void:
	_think -= dt
	if _think > 0.0:
		return
	_think = sim.rng.randf_range(0.6, 1.2)
	var cards: Array = sim.hand(team)
	if cards.is_empty():
		return

	var threat = sim.biggest_threat(team)
	var pick := -1
	if threat != null:
		var answer: String = Troops.COUNTERED_BY[threat.type]
		for i in cards.size():
			if cards[i]["type"] == answer:
				pick = i
				break
	# Nothing that counters it, or nothing to counter: don't let the meter overflow.
	if pick == -1 and float(sim.points[team]) >= Sim.MAX_POINTS - 0.5:
		pick = sim.rng.randi_range(0, cards.size() - 1)
	if pick == -1 or not sim.can_afford(team, pick):
		return

	var x := Sim.ARENA.x * 0.5
	if threat != null:
		var tp: Vector2 = threat.average_pos()
		x = tp.x
	x = clampf(x + sim.rng.randf_range(-50.0, 50.0), 70.0, Sim.ARENA.x - 70.0)
	var depth := 130.0
	if cards[pick]["type"] == Troops.ARCHERS:
		depth = 330.0 # keep bows behind the line
	var y := Sim.MID_Y - depth if team == Sim.ENEMY else Sim.MID_Y + depth
	sim.deploy(team, pick, Vector2(x, y))
