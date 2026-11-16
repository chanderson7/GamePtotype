extends SceneTree
## Measures the pace of a battle, headless, on seeded fights: how long before the lines
## meet, how men fall over time, how much warning a company gives before it breaks, how
## often the lead changes, and how long the battle runs on after the first break.
## (docs/battle-pace-and-stakes-plan.md, Stage 0.)
##
##   godot --headless --path . -s tools/pace_probe.gd -- battle [seed] [ours] [theirs] [ground] [ai|advance]
##   godot --headless --path . -s tools/pace_probe.gd -- duel [type] [type] [seeds]
##   godot --headless --path . -s tools/pace_probe.gd -- set
##
## Every company is led by a captain, as in a campaign (a led company stands more losses
## before it breaks, so battles run longer than tools/battle_probe.gd's, whose companies
## have none). Add `nocaptains` to any of them to fight without.
##
## `ai` plays the computer on both sides; `advance` is a player who presses Advance all
## the moment the battle starts, against the computer. `set` runs the standard set: the
## four battles of the simplification plan, a 6 v 6 and a 4 v 4 each way, and the duels.

const Sim = preload("res://scripts/battle/battle_sim.gd")
const Commander = preload("res://scripts/battle/commander_ai.gd")
const Troops = preload("res://scripts/data/troops.gd")
const Units = preload("res://scripts/data/units.gd")
const Captains = preload("res://scripts/data/captains.gd")

## Morale at which the screen calls a company wavering (battle_screen.gd WAVER_MORALE).
const WAVER := 35.0
## A side leads when its share of its army still fighting is this far ahead.
const LEAD_MARGIN := 0.04
const BUCKET := 5.0

var _led := true


func _init() -> void:
	_go.call_deferred()


func _army(culture: String, n: int, base: int, shift: int) -> Array:
	var out := []
	var rng := RandomNumberGenerator.new()
	rng.seed = base * 7919
	for i in n:
		var t: String = Troops.ORDER[(i + shift) % 4]
		var u := Units.recruit(culture, t)
		var e := {"id": base + i, "type": t, "unit": u, "men": Units.full_size(u), "culture": culture, "xp": 0, "level": 1}
		if _led:
			e["captain"] = Captains.make(rng, base + i, t)
		out.append(e)
	return out


func _go() -> void:
	var args := Array(OS.get_cmdline_user_args())
	if args.has("nocaptains"):
		_led = false
		args.erase("nocaptains")
	var what: String = String(args[0]) if args.size() > 0 else "set"
	match what:
		"battle":
			var r := _battle(int(args[1]) if args.size() > 1 else 40, int(args[2]) if args.size() > 2 else 10,
				int(args[3]) if args.size() > 3 else 10, String(args[4]) if args.size() > 4 else "open",
				String(args[5]) if args.size() > 5 else "ai")
			_print_battle(r, true)
		"duel":
			_duels(String(args[1]) if args.size() > 1 else Troops.INFANTRY, String(args[2]) if args.size() > 2 else Troops.INFANTRY,
				int(args[3]) if args.size() > 3 else 8)
		_:
			_standard_set()
	quit()


func _standard_set() -> void:
	print("Battles (seconds; `advance` is a player pressing Advance all at once; companies %s):" % ("led by captains" if _led else "without captains"))
	var rows := []
	for spec in [[40, 10, 10, "open"], [8, 10, 10, "open"], [21, 10, 10, "open"], [4, 10, 10, "woods"],
			[40, 6, 6, "open"], [8, 6, 6, "open"], [40, 4, 4, "open"], [8, 4, 4, "open"], [21, 4, 4, "open"]]:
		for mode in ["ai", "advance"]:
			var r := _battle(spec[0], spec[1], spec[2], spec[3], mode)
			rows.append(r)
			_print_battle(r, false)
	_summary(rows)
	print("")
	_duels(Troops.INFANTRY, Troops.INFANTRY, 8)
	_duels(Troops.SPEARMEN, Troops.SPEARMEN, 8)
	_duels(Troops.INFANTRY, Troops.SPEARMEN, 8)


## One battle, stepped to its end. Returns what the pace table needs.
func _battle(seed_v: int, ours: int, theirs: int, ground: String, mode: String) -> Dictionary:
	seed(seed_v)
	var sim = Sim.new()
	sim.setup(_army("vardish", ours, 9000, 0), _army("kharzani", theirs, 9100, 1), seed_v,
		{"type": ground, "seed": seed_v, "biome": "kharzan", "fair": true}, "rout")
	sim.ai[Sim.ENEMY] = Commander.new(Sim.ENEMY)
	sim.ai[Sim.ENEMY].deploy(sim)
	if mode == "ai":
		sim.ai[Sim.PLAYER] = Commander.new(Sim.PLAYER)
		sim.ai[Sim.PLAYER].deploy(sim)
	else:
		sim.auto_deploy(Sim.PLAYER)
	var temper := String(sim.ai[Sim.ENEMY].temperament)
	sim.start_battle()
	if mode != "ai":
		sim.order_all(Sim.PLAYER, "advance")
	var out := _run(sim)
	out["label"] = "%2d v %2d %-5s seed %2d %-7s vs %-8s" % [ours, theirs, ground, seed_v, mode, temper]
	sim.dispose()
	return out


func _run(sim) -> Dictionary:
	var dead := {}        # squad -> men dead so far
	var waver_at := {}    # squad -> when its morale first reached WAVER
	var fought := {}
	var warnings := []    # seconds between wavering and the rout, per company that broke
	var deaths := []      # the time of every death
	var contact := -1.0
	var first_break := -1.0
	var lead := 0
	var lead_changes := 0
	while sim.winner == -1 and sim.time < Sim.TIME_LIMIT + 5.0:
		sim.step()
		for sq in sim.squads:
			if sq.engaged:
				fought[sq] = true
				if contact < 0.0:
					contact = sim.time
			var d: int = sq.start_men - sq.alive_n - sq.escaped
			for i in d - int(dead.get(sq, 0)):
				deaths.append(sim.time)
			dead[sq] = d
			if not waver_at.has(sq) and sq.morale <= WAVER:
				waver_at[sq] = sim.time
			if sq.routing and not waver_at.has(str(sq.id) + "r"):
				waver_at[str(sq.id) + "r"] = sim.time
				warnings.append(sim.time - float(waver_at.get(sq, sim.time)))
				if first_break < 0.0:
					first_break = sim.time
		var diff: float = sim.strength(Sim.PLAYER) - sim.strength(Sim.ENEMY)
		var now := 1 if diff > LEAD_MARGIN else (-1 if diff < -LEAD_MARGIN else 0)
		if now != 0 and now != lead:
			if lead != 0:
				lead_changes += 1
			lead = now
	var lost := [0, 0]
	var start := [0, 0]
	var idle := 0
	for sq in sim.squads:
		lost[sq.team] += int(dead.get(sq, 0))
		start[sq.team] += sq.start_men
		if not fought.has(sq):
			idle += 1
	# The longest stretch with nobody down, from the first contact to the end.
	var quiet := 0.0
	var last := maxf(contact, 0.0)
	for t in deaths:
		if t >= last:
			quiet = maxf(quiet, t - last)
			last = t
	var buckets := []
	for i in int(ceil(sim.time / BUCKET)):
		buckets.append(0)
	for t in deaths:
		buckets[mini(buckets.size() - 1, int(t / BUCKET))] += 1
	return {"time": sim.time, "winner": sim.winner, "reason": sim.end_reason, "contact": contact,
		"first_death": deaths[0] if not deaths.is_empty() else -1.0, "first_break": first_break,
		"after_break": sim.time - first_break if first_break >= 0.0 else 0.0, "quiet": quiet,
		"warnings": warnings, "lead_changes": lead_changes, "idle": idle, "buckets": buckets,
		"lost": lost, "start": start}


func _median(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var s := a.duplicate()
	s.sort()
	return float(s[s.size() / 2])


func _print_battle(r: Dictionary, detail: bool) -> void:
	var w: Array = r["warnings"]
	print("  %s  ends %5.1f (%s)  contact %4.1f  first man down %4.1f  first break %5.1f  then %4.1f more  quiet %4.1f  warning med %3.1f min %3.1f  lead changes %d  never fought %d  lost %d/%d v %d/%d" % [
		r["label"], r["time"], r["reason"], r["contact"], r["first_death"], r["first_break"], r["after_break"],
		r["quiet"], _median(w), (w.min() if not w.is_empty() else 0.0), r["lead_changes"], r["idle"],
		r["lost"][0], r["start"][0], r["lost"][1], r["start"][1]])
	if detail:
		print("  men down in each %d s: %s" % [int(BUCKET), str(r["buckets"])])
		print("  warning before each break (s): %s" % str(w.map(func(x): return snappedf(x, 0.1))))


func _summary(rows: Array) -> void:
	var keys := ["time", "contact", "first_death", "first_break", "after_break", "quiet"]
	var line := "  median of %d:" % rows.size()
	for k in keys:
		line += "  %s %.1f" % [k, _median(rows.map(func(r): return r[k]))]
	var all_w := []
	var changed := 0
	for r in rows:
		all_w.append_array(r["warnings"])
		if int(r["lead_changes"]) > 0:
			changed += 1
	var under2 := all_w.filter(func(x): return x < 2.0).size()
	var under8 := all_w.filter(func(x): return x < 8.0).size()
	print(line)
	print("  warning before a break: median %.1f s over %d breaks; %d%% under 2 s, %d%% under 8 s" % [
		_median(all_w), all_w.size(), 100 * under2 / maxi(1, all_w.size()), 100 * under8 / maxi(1, all_w.size())])
	print("  battles where the lead changed hands: %d of %d" % [changed, rows.size()])


## One company against one, both sent at each other from the usual deployment distance:
## when each man of the loser fell, counted from the first contact.
func _duels(a: String, b: String, seeds: int) -> void:
	print("Duels, %s v %s (the loser's men down, seconds after contact):" % [a, b])
	var firsts := []
	var sevenths := []
	var ends := []
	var warns := []
	var lefts := []
	for s in range(1, seeds + 1):
		var sim = Sim.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = s * 7919
		var one := {"id": 1, "type": a, "men": Troops.full_size(a)}
		var two := {"id": 2, "type": b, "men": Troops.full_size(b)}
		if _led:
			one["captain"] = Captains.make(rng, 1, a)
			two["captain"] = Captains.make(rng, 2, b)
		sim.setup([one], [two], s)
		sim.place(Sim.PLAYER, 1, Vector2(Sim.ARENA.x * 0.5, Sim.MID_Y + 120.0))
		sim.place(Sim.ENEMY, 2, Vector2(Sim.ARENA.x * 0.5, Sim.MID_Y - 120.0))
		sim.start_battle()
		sim.order_all(Sim.PLAYER, "advance")
		sim.order_all(Sim.ENEMY, "advance")
		var contact := -1.0
		var falls := {}
		var waver := {}
		for sq in sim.squads:
			falls[sq] = []
		while sim.winner == -1 and sim.time < Sim.TIME_LIMIT:
			sim.step()
			for sq in sim.squads:
				if sq.engaged and contact < 0.0:
					contact = sim.time
				var d: int = sq.start_men - sq.alive_n - sq.escaped
				while falls[sq].size() < d:
					falls[sq].append(snappedf(sim.time - contact, 1.0))
				if not waver.has(sq) and sq.morale <= WAVER:
					waver[sq] = sim.time
		var loser = null
		var winner = null
		for sq in sim.squads:
			if sq.team != sim.winner:
				loser = sq
			else:
				winner = sq
		var f: Array = falls[loser]
		if f.size() > 0:
			firsts.append(f[0])
		if f.size() > 6:
			sevenths.append(f[6])
		ends.append(sim.time - contact)
		warns.append(sim.time - float(waver.get(loser, sim.time)))
		lefts.append(winner.alive_n)
		print("  seed %d  contact %4.1f  broke %4.1f after  %s" % [s, contact, sim.time - contact, str(f)])
		sim.dispose()
	print("  median: first man down %.0f s, seventh %.0f s, broke %.0f s after contact, wavering %.1f s before the break, winner left with %.0f men" % [
		_median(firsts), _median(sevenths), _median(ends), _median(warns), _median(lefts)])
