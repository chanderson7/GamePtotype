## Formation melee: squads keep their lines when they fight. A line stays wider than it is
## deep, doesn't turn round its foe once the lines meet, a holding squad stands its ground,
## the man behind steps into a fallen man's place, lines form only where two lines meet, and
## the switch puts the old free-for-all back.
extends SceneTree

const Sim = preload("res://scripts/battle/battle_sim.gd")
const Troops = preload("res://scripts/data/troops.gd")

var failures := 0


func check(ok: bool, message: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + message)
	if not ok:
		failures += 1


func _fight(seed_value: int, holds: bool, formation: bool) -> Sim:
	var sim := Sim.new()
	sim.formation_melee = formation
	sim.setup([{"id": 1, "type": Troops.INFANTRY, "men": 20}], [{"id": 2, "type": Troops.INFANTRY, "men": 20}], seed_value)
	sim.place(Sim.PLAYER, 1, Vector2(Sim.ARENA.x * 0.5, Sim.MID_Y + 280.0))
	sim.place(Sim.ENEMY, 2, Vector2(Sim.ARENA.x * 0.5, Sim.MID_Y - 280.0))
	sim.start_battle()
	if not holds:
		sim.order_all(Sim.PLAYER, "advance")
	sim.order_all(Sim.ENEMY, "advance")
	return sim


## Width of a squad across its own front over its depth.
func _shape(sq) -> float:
	var side: Vector2 = sq.facing.orthogonal()
	var w0 := INF
	var w1 := -INF
	var d0 := INF
	var d1 := -INF
	for so in sq.soldiers:
		if so.alive:
			var r: Vector2 = so.pos - sq.avg
			w0 = minf(w0, r.dot(side))
			w1 = maxf(w1, r.dot(side))
			d0 = minf(d0, r.dot(sq.facing))
			d1 = maxf(d1, r.dot(sq.facing))
	return (w1 - w0) / maxf(1.0, d1 - d0)


func _init() -> void:
	await process_frame

	# ---- lines stay lines, and don't turn round each other
	var shapes := []
	var turns := []
	for s in range(1, 5):
		var sim := _fight(s, false, true)
		var a = sim.squads[0]
		var axis := Vector2.ZERO
		var fought := 0.0
		while sim.winner == -1 and sim.time < 60.0:
			sim.step()
			if a.engaged and a.in_contact:
				fought += Sim.STEP
				if fought > 1.0 and int(fought / Sim.STEP) % 30 == 0:
					shapes.append(_shape(a))
					var now: Vector2 = (sim.squads[1].avg - a.avg).normalized()
					if axis != Vector2.ZERO:
						turns.append(rad_to_deg(absf(axis.angle_to(now))))
					axis = now
		sim.dispose()
	var mean_shape := 0.0
	for x in shapes:
		mean_shape += x
	mean_shape /= maxf(1.0, shapes.size())
	var mean_turn := 0.0
	for x in turns:
		mean_turn += x
	mean_turn /= maxf(1.0, turns.size())
	check(shapes.size() > 10 and mean_shape >= 2.0, "in a fight, a squad stays a line, wider than deep (%.1f : 1)" % mean_shape)
	check(mean_turn < 3.0, "two lines in contact don't turn round each other (%.1f° a second)" % mean_turn)

	# ---- a holding squad stands its ground
	var sim := _fight(3, true, true)
	var holder = sim.squads[0]
	var post: Vector2 = holder.center
	var met := false
	while sim.winner == -1 and sim.time < 40.0:
		sim.step()
		met = met or holder.engaged
	check(met and holder.center.distance_to(post) < 12.0, "a squad on Hold meets the enemy where it stands (moved %.0f)" % holder.center.distance_to(post))
	check(holder.facing.dot(Vector2.UP) > 0.9, "and keeps facing them")
	sim.dispose()

	# ---- the man behind steps up
	sim = _fight(4, false, true)
	var a = sim.squads[0]
	while not (a.engaged and a.in_contact) and sim.time < 30.0:
		sim.step()
	sim.step()
	var front = null
	for so in a.soldiers:
		if so.alive and (front == null or so.line_slot.y < front.line_slot.y):
			front = so
	var file_x: float = front.slot.x
	var behind = null
	for so in a.soldiers:
		if so.alive and so != front and absf(so.slot.x - file_x) < 0.5 and (behind == null or so.slot.y < behind.slot.y):
			behind = so
	var before: float = behind.line_slot.y
	front.alive = false
	a.alive_n -= 1
	sim.step()
	check(behind.line_slot.y < before - 1.0, "when a front-rank man falls, the man behind steps into his place")
	sim.dispose()

	# ---- off, it's the old free-for-all; in a siege, the old rules too
	sim = _fight(5, false, false)
	while not sim.squads[0].engaged and sim.time < 30.0:
		sim.step()
	check(not sim.in_line(sim.squads[0]), "with formation melee off, men fight as before")
	sim.dispose()
	sim = _fight(5, false, true)
	sim.objective = Sim.OBJECTIVE_SIEGE
	sim.squads[0].engaged = true
	check(not sim.in_line(sim.squads[0]), "and in a siege, where walls take men one at a time")
	sim.dispose()
	sim = _fight(5, false, true)
	var foot = sim.squads[0]
	foot.engaged = true
	foot.focus = sim.squads[1]
	check(sim.in_line(foot), "two lines of foot that meet fight in line")
	foot.focus.type = Troops.CAVALRY
	check(not sim.in_line(foot), "but against horsemen, who fight loose, it's a melee")
	sim.dispose()

	print("FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)
