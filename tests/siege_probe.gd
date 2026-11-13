## The siege balance probe (not in the default suite: it fights hundreds of assaults).
## AI against AI on a castle, for each case in docs/siege-engines-plan.md's balance table:
## how often the stormers win, and what the engines did.
##
##   godot --headless --path . --script res://tests/siege_probe.gd -- [seeds] [case...]
extends SceneTree

const Sim = preload("res://scripts/battle/battle_sim.gd")
const Commander = preload("res://scripts/battle/commander_ai.gd")
const Troops = preload("res://scripts/data/troops.gd")
const SiegeWorks = preload("res://scripts/battle/siege_works.gd")

const EVEN := ["infantry", "infantry", "spearmen", "archers", "archers"]
const HALF_AGAIN := ["infantry", "infantry", "infantry", "spearmen", "spearmen", "archers", "archers"]
const TWICE := ["infantry", "infantry", "infantry", "infantry", "spearmen", "spearmen", "spearmen", "archers", "archers", "archers"]
const FULL_TRAIN := ["ram", "ladders", "mantlets", "tower", "thrower", "thrower"]
const FULL_WORKS := ["bolt", "bolt", "bolt", "oil", "yard_thrower", "postern"]
const PLAIN_WORKS := ["bolt", "bolt", "postern"]

## name: [attackers, attacker kit, garrison kit, target wins (low, high)]
const CASES := {
	"even_ladders": [EVEN, ["ladders"], [], [0.0, 0.0]],
	"half_ladders": [HALF_AGAIN, ["ladders"], [], [0.0, 0.35]],
	"half_ram": [HALF_AGAIN, ["ram", "ladders"], [], [0.5, 0.7]],
	"even_full": [EVEN, FULL_TRAIN, PLAIN_WORKS, [0.3, 0.45]],
	"half_full": [HALF_AGAIN, FULL_TRAIN, PLAIN_WORKS, [0.75, 0.85]],
	"half_full_vs_works": [HALF_AGAIN, FULL_TRAIN, FULL_WORKS, [0.5, 0.6]],
	"twice_ladders": [TWICE, ["ladders"], FULL_WORKS, [1.0, 1.0]],
}


static func army(types: Array, base: int) -> Array:
	var out := []
	for i in types.size():
		out.append({"id": base + i, "type": types[i], "men": Troops.full_size(types[i])})
	return out


## One case over `seeds`: {wins, rate, and the engines' averages}.
static func run_case(name: String, seeds: int, verbose: bool = false) -> Dictionary:
	var c: Array = CASES[name]
	var tally := {"wins": 0, "breach": 0, "sections": 0, "docked": 0, "stones": 0, "bolts": 0, "burned_att": 0,
		"burned_def": 0, "pours": 0, "engine_kills": 0, "time": 0.0, "sallies": 0, "lost_att": 0, "lost_def": 0}
	for s in range(1, seeds + 1):
		var sim := Sim.new()
		sim.siege_engines = {"attacker": c[1], "defender": c[2], "attacker_land": "vardish", "defender_land": "vardish"}
		sim.setup(army(c[0], 1), army(EVEN, 100), s, null, Sim.OBJECTIVE_SIEGE)
		sim.ai = [Commander.new(Sim.PLAYER), Commander.new(Sim.ENEMY)]
		sim.start_battle()
		var docked := false
		var sallied := false
		while sim.winner == -1 and sim.time < Sim.TIME_LIMIT + 5.0:
			sim.step()
			for ev in sim.events:
				if ev["type"] == "tower_docked":
					docked = true
				elif ev["type"] == "sally_out":
					sallied = true
			sim.events.clear()
		var r: Dictionary = sim.works.result()
		if sim.winner == Sim.PLAYER:
			tally["wins"] += 1
		if sim.gate_hp <= 0.0:
			tally["breach"] += 1
		tally["sections"] += int(r["sections_broken"])
		tally["docked"] += 1 if docked else 0
		tally["sallies"] += 1 if sallied else 0
		tally["stones"] += int(r["stones"][0])
		tally["bolts"] += int(r["bolts"][1])
		tally["burned_att"] += int(r["burned"][0])
		tally["burned_def"] += int(r["burned"][1])
		tally["pours"] += int(r["pours"])
		tally["engine_kills"] += int(r["engine_kills"][0]) + int(r["engine_kills"][1])
		tally["time"] += sim.time
		tally["lost_att"] += sim.start_men(Sim.PLAYER) - sim.men_on_field(Sim.PLAYER) - sim.reserve_men(Sim.PLAYER)
		tally["lost_def"] += sim.start_men(Sim.ENEMY) - sim.men_on_field(Sim.ENEMY) - sim.reserve_men(Sim.ENEMY)
		if verbose:
			print("  seed %d: %s at %.0fs, gate %s, sections %d, tower %s, stones %d, bolts %d, burned %s, oil %d" % [
				s, "WIN" if sim.winner == Sim.PLAYER else "lost", sim.time, "broken" if sim.gate_hp <= 0.0 else "held",
				r["sections_broken"], "docked" if docked else "-", r["stones"][0], r["bolts"][1], str(r["burned"]), r["pours"]])
		sim.dispose()
	tally["rate"] = float(tally["wins"]) / float(seeds)
	tally["target"] = c[3]
	return tally


func _init() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var seeds := int(args[0]) if args.size() > 0 else 16
	var names: Array = args.slice(1) if args.size() > 1 else CASES.keys()
	var verbose := names.has("-v")
	names.erase("-v")
	for name in names:
		var t0 := Time.get_ticks_msec()
		var r := run_case(String(name), seeds, verbose)
		var n := float(seeds)
		var ok: bool = r["rate"] >= float(r["target"][0]) - 0.001 and r["rate"] <= float(r["target"][1]) + 0.001
		print("%-20s wins %2d/%d (%.0f%%, target %.0f-%.0f%%) %s | gate broken %.0f%%, sections %.1f, tower docked %.0f%%, stones %.0f, bolts %.0f, burned att/def %.1f/%.1f, oil %.1f, sallies %.0f%%, engine kills %.1f, lost att/def %.0f/%.0f, %.0fs [%ds]" % [
			name, r["wins"], seeds, r["rate"] * 100.0, float(r["target"][0]) * 100.0, float(r["target"][1]) * 100.0,
			"ok" if ok else "OFF", r["breach"] / n * 100.0, r["sections"] / n, r["docked"] / n * 100.0, r["stones"] / n,
			r["bolts"] / n, r["burned_att"] / n, r["burned_def"] / n, r["pours"] / n, r["sallies"] / n * 100.0,
			r["engine_kills"] / n, r["lost_att"] / n, r["lost_def"] / n, r["time"] / n, (Time.get_ticks_msec() - t0) / 1000])
	quit()
