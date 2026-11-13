extends SceneTree
## Measures two things that look wrong in a battle, headless, on a seeded fight the
## computer plays for both sides:
##
## - Facing flicker: a man whose facing turns more than 60 degrees in one step and back
##   within 0.2 s, which reads on screen as a man flicking left and right. Each one is put
##   down to what changed that step (his squad's own facing, its engagement, his target).
## - Crowding: sampled each second while men are fighting: the most men within 50 units of
##   one point and how many companies they come from, how many men stand nearest a man of
##   another friendly company (companies merged), and how many engaged companies fight
##   loose rather than in a line.
##
##   godot --headless --path . -s tools/battle_probe.gd -- [seed] [ours] [theirs] [ground]
##   e.g.  ... -- 40 12 12 open     (the trailer's closing battle)
##         ... -- 4 10 10 woods

const Sim = preload("res://scripts/battle/battle_sim.gd")
const Commander = preload("res://scripts/battle/commander_ai.gd")
const Troops = preload("res://scripts/data/troops.gd")
const Units = preload("res://scripts/data/units.gd")

const BIG := deg_to_rad(60.0)
## A turn back within this many steps (0.2 s) counts as a flick.
const BACK_WITHIN := 6


func _init() -> void:
	_go.call_deferred()


func _army(culture: String, n: int, base: int, shift: int) -> Array:
	var out := []
	for i in n:
		var t: String = Troops.ORDER[(i + shift) % 4]
		var u := Units.recruit(culture, t)
		out.append({"id": base + i, "type": t, "unit": u, "men": Units.full_size(u), "culture": culture, "xp": 0, "level": 1})
	return out


func _go() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_v := int(args[0]) if args.size() > 0 else 40
	var ours := int(args[1]) if args.size() > 1 else 12
	var theirs := int(args[2]) if args.size() > 2 else 12
	var ground := args[3] if args.size() > 3 else "open"
	seed(seed_v)
	var sim = Sim.new()
	sim.setup(_army("vardish", ours, 9000, 0), _army("kharzani", theirs, 9100, 1), seed_v,
		{"type": ground, "seed": seed_v, "biome": "kharzan", "fair": true}, "rout")
	for team in [Sim.ENEMY, Sim.PLAYER]:
		sim.ai[team] = Commander.new(team)
		sim.ai[team].deploy(sim)
	sim.start_battle()

	var last := {}       # man -> [angle, step of his last big turn, its sign]
	var before := {}     # squad -> [facing, engaged]
	var target := {}     # man -> his target before the step
	var squad_turn := {} # squad -> [step of its last big turn, its sign]
	var flicks := {}
	var squad_flicks := {}
	var crowd := {"pile": [], "from": [], "merged": [], "loose": [], "strayed": []}
	var steps := 0
	while sim.winner == -1 and steps < 30 * 300:
		for sq in sim.squads:
			before[sq] = [sq.facing, sq.engaged, sq.goal, sq.center]
			for so in sq.soldiers:
				target[so] = so.target
		sim.step()
		steps += 1
		if steps % 30 == 0:
			_crowd(sim, crowd)
		for sq in sim.squads:
			if sq.routing:
				continue
			var turned: float = Vector2(before[sq][0]).angle_to(sq.facing)
			if not sq.engaged and absf(turned) > BIG:
				var h: Array = squad_turn.get(sq, [-999, 0.0])
				if steps - int(h[0]) <= BACK_WITHIN and signf(turned) != float(h[1]):
					_count(squad_flicks, _squad_why(sim, sq, before[sq]))
				squad_turn[sq] = [steps, signf(turned)]
			for so in sq.soldiers:
				if not so.alive:
					continue
				var a: float = so.facing.angle()
				if not last.has(so):
					last[so] = [a, -999, 0.0]
					continue
				var d := angle_difference(float(last[so][0]), a)
				last[so][0] = a
				if absf(d) < BIG:
					continue
				if steps - int(last[so][1]) <= BACK_WITHIN and signf(d) != float(last[so][2]):
					var why := "same target, he moved past it"
					if absf(turned) > BIG:
						why = "his squad's own facing flipped"
					elif bool(before[sq][1]) != sq.engaged:
						why = "his squad's engagement toggled " + ("on" if sq.engaged else "off")
					elif target.get(so) != so.target:
						why = "his target changed"
					_count(flicks, why)
				last[so][1] = steps
				last[so][2] = signf(d)
	print("seed %d, %d v %d on %s: side %d won after %.1f s" % [seed_v, ours, theirs, ground, sim.winner, sim.time])
	_report("facing flicks (a man turning >60 deg and back within 0.2 s)", flicks)
	_report("squad-facing flicks while not engaged, by what moved its goal", squad_flicks)
	print("crowding, sampled each second of fighting:")
	print("  most men within 50 units of one point   mean %.1f  max %d" % [_mean(crowd["pile"]), _top(crowd["pile"])])
	print("  companies those men come from           mean %.1f  max %d" % [_mean(crowd["from"]), _top(crowd["from"])])
	print("  men nearest a man of another friendly company   %.0f%%" % (100.0 * _mean(crowd["merged"])))
	print("  engaged companies fighting loose, not in a line %.0f%%" % (100.0 * _mean(crowd["loose"])))
	print("  men in a line further from their place than their tether and a body  %.1f%%" % (100.0 * _mean(crowd["strayed"])))
	sim.dispose()
	quit()


## Why an unengaged squad's facing flipped: what its step direction followed.
func _squad_why(sim, sq, was: Array) -> String:
	var role := "cavalry" if sq.type == Troops.CAVALRY else ("archers" if sq.ranged else "foot")
	var from: Vector2 = was[3]
	if sq.wheeling:
		return role + ": wheeling"
	if from.distance_to(sq.center) < 0.001:
		return role + ": standing"
	if Vector2(was[2]).distance_to(sq.goal) > 15.0:
		var foe = sq.focus
		if foe != null and sq.attack_dir != Vector2.ZERO:
			var r0: Vector2 = from - foe.avg
			var r1: Vector2 = sq.center - foe.avg
			if signf(r0.dot(sq.attack_dir)) != signf(r1.dot(sq.attack_dir)):
				return role + ": goal jumped (_side_point: crossed its side's half-plane)"
			var across: Vector2 = sq.attack_dir.orthogonal()
			if signf(r0.dot(across)) != signf(r1.dot(across)):
				return role + ": goal jumped (_side_point: switched corner)"
		return role + ": goal jumped (other)"
	var to_goal: Vector2 = sq.goal - from
	if to_goal.length() < 6.0:
		return role + ": hovering on its goal"
	if absf(sq.facing.angle_to(to_goal)) > deg_to_rad(25.0):
		return role + ": steered round a blocker (_steer)"
	return role + ": straight at its goal"


func _crowd(sim, crowd: Dictionary) -> void:
	var men := []
	var engaged := 0
	var loose := 0
	for sq in sim.squads:
		if sq.routing or not sq.is_active():
			continue
		if sq.engaged:
			engaged += 1
			if not sim.in_line(sq):
				loose += 1
		for so in sq.soldiers:
			if so.alive:
				men.append(so)
	if engaged == 0:
		return
	crowd["loose"].append(float(loose) / engaged)
	var fighting := 0
	var strayed := 0
	for sq in sim.squads:
		if not sim.in_line(sq):
			continue
		var tether: float = sim._leash(sq) + sq.radius * 2.0
		for so in sq.soldiers:
			if not so.alive:
				continue
			fighting += 1
			var home: Vector2 = sq.center + sim._slot_world(so.line_slot, sq.facing, sq.team)
			if so.pos.distance_to(home) > maxf(tether, Sim.WING_LEASH if so.target != null else 0.0):
				strayed += 1
	if fighting > 0:
		crowd["strayed"].append(float(strayed) / fighting)
	var most := 0
	var from := 0
	for c in sim.squads:
		if not c.is_active() or c.routing:
			continue
		var n := 0
		var squads := {}
		for so in men:
			if so.pos.distance_squared_to(c.avg) < 2500.0:
				n += 1
				squads[so.squad] = true
		if n > most:
			most = n
			from = squads.size()
	crowd["pile"].append(most)
	crowd["from"].append(from)
	var merged := 0
	for so in men:
		var nearest = null
		var nd := INF
		for o in men:
			if o != so:
				var d: float = so.pos.distance_squared_to(o.pos)
				if d < nd:
					nd = d
					nearest = o
		if nearest != null and nearest.squad != so.squad and nearest.squad.team == so.squad.team:
			merged += 1
	crowd["merged"].append(float(merged) / maxf(1, men.size()))


func _count(d: Dictionary, k: String) -> void:
	d[k] = int(d.get(k, 0)) + 1


func _report(title: String, d: Dictionary) -> void:
	var total := 0
	for k in d:
		total += int(d[k])
	print("%s: %d" % [title, total])
	var keys := d.keys()
	keys.sort_custom(func(x, y): return d[x] > d[y])
	for k in keys:
		print("  %6d  %5.1f%%  %s" % [d[k], 100.0 * d[k] / maxf(1, total), k])


func _mean(a: Array) -> float:
	var t := 0.0
	for v in a:
		t += float(v)
	return t / maxf(1, a.size())


func _top(a: Array) -> int:
	var m := 0
	for v in a:
		m = maxi(m, int(v))
	return m
