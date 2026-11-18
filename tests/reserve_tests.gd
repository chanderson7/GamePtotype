## Reserves you hold back and commit, the battle's last stretch, and the marks that tell
## you who to fight: headless checks of the rules (battle_sim.gd).
##   godot --headless --path . --script res://tests/reserve_tests.gd
extends SceneTree

const Sim = preload("res://scripts/battle/battle_sim.gd")
const Troops = preload("res://scripts/data/troops.gd")

var failures := 0


func check(ok: bool, label: String) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", label])
	if not ok:
		failures += 1


func _army(types: Array, base: int) -> Array:
	var out := []
	for i in types.size():
		out.append({"id": base + i, "type": types[i], "men": 20})
	return out


func _init() -> void:
	var sim := Sim.new()
	sim.setup(_army(["infantry", "spearmen", "cavalry"], 1), _army(["infantry", "infantry"], 100), 3)
	check(sim.hold_back(Sim.PLAYER, 3), "a company not yet placed can be held back before the fight")
	check(sim.is_held(Sim.PLAYER, 3) and sim.reserve_men(Sim.PLAYER) == 20, "it counts as men still to come on")
	check(sim.release_hold(Sim.PLAYER, 3) and not sim.is_held(Sim.PLAYER, 3) and sim.reserves[Sim.PLAYER].size() == 3, "and can be brought up again")
	sim.hold_back(Sim.PLAYER, 3)
	sim.hold_back(Sim.PLAYER, 2)
	check(not sim.hold_back(Sim.PLAYER, 1), "the last company cannot be held: someone has to stand on the field")
	sim.release_hold(Sim.PLAYER, 2)
	sim.auto_deploy(Sim.PLAYER)
	check(sim.all_placed(Sim.PLAYER) and sim.placed_squad(Sim.PLAYER, 3) == null and sim.placed_squad(Sim.PLAYER, 1) != null,
		"Auto-place puts the rest down and leaves the held company off the field")
	check(not sim.commit_reserve(Sim.PLAYER, 3, "left"), "it cannot come on before the fight")
	sim.start_battle()
	check(sim.placed_squad(Sim.PLAYER, 3) == null and sim.is_held(Sim.PLAYER, 3), "the fight begins without it")
	var full := sim.strength(Sim.PLAYER)
	check(is_equal_approx(full, 1.0), "held men count towards the side's strength")
	for i in Sim.ticks_for(60 / 30.0):
		sim.step()
	check(sim.commit_reserve(Sim.PLAYER, 3, "left"), "in the fight it is committed where you say")
	var sq = sim.placed_squad(Sim.PLAYER, 3)
	check(sq != null and sq.center.x < Sim.ARENA.x * 0.25 and sq.center.y > Sim.MID_Y + 100.0 and sq.order == "advance",
		"onto the left flank of your own half, advancing")
	check(not sim.is_held(Sim.PLAYER, 3) and not sim.commit_reserve(Sim.PLAYER, 3, "rear"), "and only once")
	sim.dispose()

	# With the line gone, whoever was held comes on by themselves.
	sim = Sim.new()
	sim.setup(_army(["infantry", "infantry"], 1), _army(["infantry"], 100), 5)
	sim.hold_back(Sim.PLAYER, 2)
	sim.auto_deploy(Sim.PLAYER)
	sim.start_battle()
	for sq2 in sim.squads:
		if sq2.team == Sim.PLAYER:
			sq2.morale = 0.0
			sq2.routing = true
	for i in Sim.ticks_for(30 / 30.0):
		sim.step()
	check(sim.placed_squad(Sim.PLAYER, 2) != null and sim.winner == -1, "a reserve is not kept once the line it was kept for is gone")
	sim.dispose()

	# The last stretch.
	sim = Sim.new()
	sim.setup(_army(["infantry"], 1), _army(["infantry"], 100), 7)
	sim.auto_deploy(Sim.PLAYER)
	sim.start_battle()
	check(not sim.in_final_phase() and sim.squads[0].strain == 1.0, "for most of a battle nerves are as they are")
	sim.time = Sim.TIME_LIMIT - Sim.FINAL_PHASE + 0.1
	sim.step()
	var called := false
	for e in sim.events:
		if String(e["type"]) == "final_phase":
			called = true
	var a = sim.squads[0]
	check(sim.in_final_phase() and called and a.strain == Sim.FINAL_STRAIN, "in its last stretch the battle says so, and every blow to morale falls harder")
	var before: float = a.morale
	a.drop_morale(10.0)
	check(is_equal_approx(before - a.morale, 10.0 * Sim.FINAL_STRAIN), "by half again")
	sim.dispose()

	print("\n%s: %d failure(s)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(failures)
