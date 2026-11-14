## Fighting in ranks: every company in a fight keeps its ranks, foot, horse and bows alike.
## A line stays wider than it is deep and doesn't turn round its foe once the lines meet; a
## holding company stands its ground; the man behind steps into a fallen man's place; each
## man steps out of his place only as far as his company's tether to strike; no more than
## two men set on one enemy; bows shoot from their ranks; riding down men running for it,
## or fighting at a siege's walls, is still a scramble; and in a whole battle nobody flicks
## left and right (a man turning more than 60 degrees and back within 0.2 s).
extends SceneTree

const Sim = preload("res://scripts/battle/battle_sim.gd")
const Troops = preload("res://scripts/data/troops.gd")
const Units = preload("res://scripts/data/units.gd")
const Commander = preload("res://scripts/battle/commander_ai.gd")

var failures := 0


func check(ok: bool, message: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + message)
	if not ok:
		failures += 1


func _fight(seed_value: int, holds: bool, mine: String = Troops.INFANTRY, theirs: String = Troops.INFANTRY) -> Sim:
	var sim := Sim.new()
	sim.setup([{"id": 1, "type": mine, "men": 20}], [{"id": 2, "type": theirs, "men": 20}], seed_value)
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


## Of the men of companies fighting in ranks, the share standing further from their place
## than their tether and two bodies (men folding in on a flank may go WING_LEASH).
func _strayed(sim) -> Array:
	var men := 0
	var out := 0
	for sq in sim.squads:
		if not sim.in_line(sq):
			continue
		for so in sq.soldiers:
			if not so.alive:
				continue
			men += 1
			var home: Vector2 = sq.center + sim._slot_world(so.line_slot, sq.facing, sq.team)
			var tether: float = (Sim.WING_LEASH if so.wing else sim._leash(sq)) + so.radius * 4.0
			if so.pos.distance_to(home) > tether:
				out += 1
	return [men, out]


func _init() -> void:
	await process_frame

	# ---- lines stay lines, and don't turn round each other
	var shapes := []
	var turns := []
	for s in range(1, 5):
		var sim := _fight(s, false)
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
	var sim := _fight(3, true)
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
	sim = _fight(4, false)
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

	# ---- foot, horse and bows all fight in their ranks; each man on his tether; two to a man
	for pair in [[Troops.INFANTRY, Troops.INFANTRY], [Troops.CAVALRY, Troops.INFANTRY], [Troops.SPEARMEN, Troops.CAVALRY]]:
		sim = _fight(6, false, pair[0], pair[1])
		var both_in_line := false
		var men := 0
		var strayed := 0
		var crowded := 0
		var pairs := 0
		while sim.winner == -1 and sim.time < 90.0:
			sim.step()
			if sim.squads[0].engaged and sim.squads[1].engaged:
				both_in_line = both_in_line or (sim.in_line(sim.squads[0]) and sim.in_line(sim.squads[1]))
				var st := _strayed(sim)
				men += st[0]
				strayed += st[1]
				for sq in sim.squads:
					for so in sq.soldiers:
						if so.alive:
							pairs += 1
							if so.attackers > Sim.MAX_ATTACKERS:
								crowded += 1
		var share := float(strayed) / maxf(1.0, men)
		check(both_in_line, "%s against %s: both fight in their ranks" % [pair[0], pair[1]])
		check(men > 0 and share < 0.1, "  and men keep to their tether (%.1f%% strayed)" % (100.0 * share))
		check(pairs > 0 and float(crowded) / pairs < 0.02, "  and no more than two set on one man (%.1f%% had more)" % (100.0 * crowded / maxf(1.0, pairs)))
		sim.dispose()

	# ---- bows shoot from their ranks
	sim = _fight(7, true, Troops.ARCHERS, Troops.INFANTRY)
	var shot := false
	while sim.winner == -1 and sim.time < 30.0 and not shot:
		sim.step()
		shot = sim.squads[0].arrows < int(Troops.stats(Troops.ARCHERS)["arrows"]) * 20
	check(shot and sim.in_line(sim.squads[0]), "bows on Hold shoot from their ranks")
	sim.dispose()

	# ---- riding down runners, and the walls of a siege, are still a scramble
	sim = _fight(5, false)
	sim.squads[0].engaged = true
	sim.squads[0].pursuing = true
	check(not sim.in_line(sim.squads[0]), "riding down men running for it is a chase, not a line")
	sim.dispose()
	sim = _fight(5, false)
	sim.objective = Sim.OBJECTIVE_SIEGE
	sim.squads[0].engaged = true
	check(not sim.in_line(sim.squads[0]), "and in a siege, where walls take men one at a time")
	sim.dispose()

	# ---- a whole battle, the computer on both sides: nobody flicks left and right
	var army := func(culture: String, base: int, shift: int) -> Array:
		var out := []
		for i in 10:
			var t: String = Troops.ORDER[(i + shift) % 4]
			var u := Units.recruit(culture, t)
			out.append({"id": base + i, "type": t, "unit": u, "men": Units.full_size(u), "culture": culture, "xp": 0, "level": 1})
		return out
	seed(8)
	sim = Sim.new()
	sim.setup(army.call("vardish", 9000, 0), army.call("kharzani", 9100, 1), 8, {"type": "open", "seed": 8, "biome": "kharzan", "fair": true})
	for team in [Sim.ENEMY, Sim.PLAYER]:
		sim.ai[team] = Commander.new(team)
		sim.ai[team].deploy(sim)
	sim.start_battle()
	var last := {}
	var flicks := 0
	var steps := 0
	while sim.winner == -1 and steps < 30 * 240:
		sim.step()
		steps += 1
		for sq in sim.squads:
			if sq.routing:
				continue
			for so in sq.soldiers:
				if not so.alive:
					continue
				var ang: float = so.facing.angle()
				var was: Array = last.get(so, [ang, -999, 0.0])
				var d := angle_difference(float(was[0]), ang)
				was[0] = ang
				if absf(d) > deg_to_rad(60.0):
					if steps - int(was[1]) <= 6 and signf(d) != float(was[2]):
						flicks += 1
					was[1] = steps
					was[2] = signf(d)
				last[so] = was
	check(sim.winner != -1 and flicks < 50, "a whole battle without men flicking left and right (%d flicks, %.0f s)" % [flicks, sim.time])
	sim.dispose()

	print("FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)
