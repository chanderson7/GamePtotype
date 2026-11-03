## Attack positions: squads going for an enemy take a free side of it instead of piling on.
## Two foot squads to an enemy (front first, then a flank), horse on top of that on a flank
## or the rear; a third foot squad looks for another enemy or waits behind the fight as a
## reserve. A squad joins the fight once it reaches its side, the side stays fixed on the
## ground, and orders, archers, sieges and the switch keep the old ways.
extends SceneTree

const Sim = preload("res://scripts/battle/battle_sim.gd")
const Troops = preload("res://scripts/data/troops.gd")

var failures := 0


func check(ok: bool, message: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + message)
	if not ok:
		failures += 1


## Player squads (types) below the middle, side by side; enemy squads (types, x offsets)
## above it, holding. Everyone placed, the battle started, the player's squads advancing.
func _battle(mine: Array, theirs: Array, their_x: Array = [0.0], on: bool = true) -> Sim:
	var sim := Sim.new()
	sim.attack_positions = on
	var p := []
	for i in mine.size():
		p.append({"id": 10 + i, "type": mine[i], "men": 20})
	var e := []
	for i in theirs.size():
		e.append({"id": 20 + i, "type": theirs[i], "men": 20})
	sim.setup(p, e, 3)
	var mid := Sim.ARENA.x * 0.5
	for i in mine.size():
		sim.place(Sim.PLAYER, 10 + i, Vector2(mid + (i - (mine.size() - 1) * 0.5) * 110.0, Sim.MID_Y + 220.0))
	for i in theirs.size():
		sim.place(Sim.ENEMY, 20 + i, Vector2(mid + float(their_x[i]), Sim.MID_Y - 80.0))
	sim.start_battle()
	sim.order_all(Sim.ENEMY, "hold")
	sim.order_all(Sim.PLAYER, "advance")
	return sim


func _run(sim: Sim, seconds: float) -> void:
	var until: float = sim.time + seconds
	while sim.time < until and sim.winner == -1:
		sim.step()


func _mine(sim: Sim) -> Array:
	return sim.squads.filter(func(s): return s.team == Sim.PLAYER)


func _init() -> void:
	await process_frame

	# ---- two to an enemy: the front, then a flank
	var sim := _battle([Troops.INFANTRY, Troops.INFANTRY], [Troops.INFANTRY])
	var foe = sim.squads.filter(func(s): return s.team == Sim.ENEMY)[0]
	_run(sim, 1.0)
	var a = _mine(sim)[0]
	var b = _mine(sim)[1]
	var front: Vector2 = foe.facing
	check(a.attack_foe == foe and b.attack_foe == foe and a.attack_dir != Vector2.ZERO and b.attack_dir != Vector2.ZERO,
		"two squads going for one enemy each take a side of it")
	check(a.attack_dir.dot(b.attack_dir) < 0.5, "different sides, not the same one")
	check(maxf(a.attack_dir.dot(front), b.attack_dir.dot(front)) > 0.7, "one of them takes its front")
	# ---- the side stays put on the ground: an enemy that turns doesn't lead it round
	var held: Vector2 = b.attack_dir
	foe.facing = foe.facing.orthogonal()
	sim.step()
	check(b.attack_dir.is_equal_approx(held), "an enemy turning doesn't move the side a squad is making for")
	sim.dispose()

	# ---- a third foot squad looks for another enemy
	sim = _battle([Troops.INFANTRY, Troops.INFANTRY, Troops.INFANTRY], [Troops.INFANTRY, Troops.INFANTRY], [-60.0, 330.0])
	var near = sim.squads.filter(func(s): return s.team == Sim.ENEMY)[0]
	var far = sim.squads.filter(func(s): return s.team == Sim.ENEMY)[1]
	_run(sim, 1.0)
	var on_near := _mine(sim).filter(func(s): return s.attack_foe == near and s.attack_dir != Vector2.ZERO).size()
	var on_far := _mine(sim).filter(func(s): return s.focus == far).size()
	check(on_near == 2 and on_far == 1, "with two on one enemy, the third goes for another (%d and %d)" % [on_near, on_far])
	sim.dispose()

	# ---- with no other enemy, the third waits as a reserve until the enemy reaches it
	sim = _battle([Troops.INFANTRY, Troops.INFANTRY, Troops.INFANTRY], [Troops.INFANTRY])
	_run(sim, 1.0)
	var reserves := _mine(sim).filter(func(s): return s.attack_dir == Vector2.ZERO)
	check(reserves.size() == 1, "with one enemy, the third foot squad waits as a reserve")
	var reserve = reserves[0] if reserves.size() == 1 else _mine(sim)[2]
	var fought := 0.0
	var reserve_joined := false
	while sim.time < 40.0 and sim.winner == -1 and fought < 4.0:
		sim.step()
		if _mine(sim).filter(func(s): return s != reserve and s.engaged).size() == 2:
			fought += Sim.STEP
			reserve_joined = reserve_joined or reserve.engaged
	check(fought >= 4.0 and not reserve_joined, "and stays out while the other two fight it")
	sim.dispose()

	# ---- horse may still ride round to the rear
	sim = _battle([Troops.INFANTRY, Troops.INFANTRY, Troops.CAVALRY], [Troops.INFANTRY])
	foe = sim.squads.filter(func(s): return s.team == Sim.ENEMY)[0]
	_run(sim, 1.0)
	var horse = _mine(sim)[2]
	var foot_placed := _mine(sim).filter(func(s): return s.type == Troops.INFANTRY and s.attack_dir != Vector2.ZERO).size()
	check(horse.attack_dir != Vector2.ZERO and horse.attack_dir.dot(foe.facing) < 0.7 and foot_placed == 2,
		"horse ride in on a flank or the rear, without taking a foot squad's place")
	sim.dispose()

	# ---- a squad making for a flank doesn't join the fight on its way past the front
	sim = _battle([Troops.INFANTRY, Troops.INFANTRY], [Troops.INFANTRY])
	foe = sim.squads.filter(func(s): return s.team == Sim.ENEMY)[0]
	var early := false
	var arrived := false
	while sim.time < 40.0 and sim.winner == -1:
		sim.step()
		for s in _mine(sim):
			if s.attack_dir.dot(foe.facing) < 0.7 and s.attack_dir != Vector2.ZERO:
				if s.engaged and not sim._on_its_side(s, foe) and s.engaged_for < Sim.STEP * 1.5 \
						and not sim._in_range(s, foe, s.reach + 8.0):
					early = true
				arrived = arrived or (s.engaged and sim._on_its_side(s, foe))
	check(arrived and not early, "a flanker joins the fight on the flank, not on its way past the front")
	sim.dispose()

	# ---- told to attack, it goes in even with every place taken
	sim = _battle([Troops.INFANTRY, Troops.INFANTRY, Troops.INFANTRY], [Troops.INFANTRY])
	foe = sim.squads.filter(func(s): return s.team == Sim.ENEMY)[0]
	sim.order_attack(_mine(sim)[2], foe)
	_run(sim, 1.0)
	check(_mine(sim)[2].attack_dir != Vector2.ZERO, "an order to attack an enemy goes in even when its sides are taken")
	sim.dispose()

	# ---- archers shooting, sieges and the switch keep the old ways
	sim = _battle([Troops.ARCHERS], [Troops.INFANTRY])
	check(not sim._uses_sides(_mine(sim)[0]), "archers with arrows to loose shoot from where they are")
	sim.dispose()
	sim = _battle([Troops.INFANTRY], [Troops.INFANTRY])
	sim.objective = Sim.OBJECTIVE_SIEGE
	check(not sim._uses_sides(_mine(sim)[0]), "a siege keeps the old rules")
	sim.dispose()
	sim = _battle([Troops.INFANTRY, Troops.INFANTRY], [Troops.INFANTRY], [0.0], false)
	foe = sim.squads.filter(func(s): return s.team == Sim.ENEMY)[0]
	_run(sim, 1.0)
	check(_mine(sim).all(func(s): return s.goal.distance_to(foe.avg) < 4.0), "switched off, squads head straight for their foe as before")
	sim.dispose()

	print("FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)
