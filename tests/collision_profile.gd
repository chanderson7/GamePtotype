## Desktop profile: -- --baseline /absolute/path/battle_sim.gd.
## Alternates version order per seed to reduce warm-up/thermal bias. No rendering.
extends SceneTree
const Sim = preload("res://scripts/battle/battle_sim.gd")
const Plans = preload("res://tests/plans.gd")
func sample(script, copies: int, seed_value: int) -> Dictionary:
	var army: Array = []
	for copy in copies:
		for entry in Plans.army(seed_value):
			var squad: Dictionary = entry.duplicate(true)
			squad["id"] = army.size() + 1
			army.append(squad)
	var sim = script.new()
	sim.setup(army, army.duplicate(true), seed_value)
	sim.start_battle()
	sim.order_all(0, "advance")
	sim.order_all(1, "advance")
	var result := {"elapsed": 0, "ticks": 0, "samples": 0, "penetration": 0.0, "peak_men": 0}
	for tick in 600:
		if sim.winner != -1: break
		var start := Time.get_ticks_usec()
		sim.step()
		result["elapsed"] += Time.get_ticks_usec() - start
		result["ticks"] += 1
		if tick % 30 != 0: continue
		var men: Array = []
		for sq in sim.squads:
			for so in sq.soldiers:
				if so.alive: men.append(so)
		result["peak_men"] = maxi(result["peak_men"], men.size())
		result["samples"] += 1
		for i in men.size():
			for j in range(i + 1, men.size()):
				result["penetration"] += maxf(0.0, men[i].radius + men[j].radius - men[i].pos.distance_to(men[j].pos))
	sim.dispose()
	return result
func _init() -> void:
	var versions: Array = [["current", Sim]]
	var args := OS.get_cmdline_user_args()
	var baseline := args.find("--baseline")
	if baseline >= 0 and baseline + 1 < args.size():
		versions.push_front(["baseline", load(args[baseline + 1])])
	for copies in [1, 2]:
		var totals := {}
		for seed_value in [31, 32, 33]:
			var order := versions.duplicate()
			if seed_value % 2 == 0: order.reverse()
			for version in order:
				var result := sample(version[1], copies, seed_value)
				if not totals.has(version[0]):
					totals[version[0]] = result
				else:
					for key in result:
						if key == "peak_men": totals[version[0]][key] = maxi(totals[version[0]][key], result[key])
						else: totals[version[0]][key] += result[key]
		for name in totals:
			var r: Dictionary = totals[name]
			print("%s copies=%d peak_men=%d ticks=%d ms/tick=%.3f overlap/sample=%.2f" % [name, copies, r["peak_men"], r["ticks"], float(r["elapsed"])/1000/maxi(1,r["ticks"]), r["penetration"]/maxi(1,r["samples"])])
	quit()
