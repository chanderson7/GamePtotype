## Focused crowd contacts and combat regression checks.
extends SceneTree
const Sim = preload("res://scripts/battle/battle_sim.gd")
const Troops = preload("res://scripts/data/troops.gd")
const Terrain = preload("res://scripts/battle/terrain.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	print(("ok " if ok else "FAIL ") + message)
	if not ok: failures += 1
func fixture(n: int = 1, ground = null):
	var sim := Sim.new()
	sim.setup([{"id": 1, "type": Troops.INFANTRY, "men": n}], [{"id": 2, "type": Troops.INFANTRY, "men": 1}], 31, ground)
	sim.start_battle()
	return sim
func penetration(sim) -> float:
	var men: Array = []
	for sq in sim.squads:
		for so in sq.soldiers:
			if so.alive: men.append(so)
	var total := 0.0
	for i in men.size():
		for j in range(i + 1, men.size()):
			total += maxf(0.0, men[i].radius + men[j].radius - men[i].pos.distance_to(men[j].pos))
	return total
func _init() -> void:
	var sim = fixture()
	var a = sim.squads[0].soldiers[0]
	var b = sim.squads[1].soldiers[0]
	a.pos = Vector2(319, 400)
	b.pos = Vector2(321, 400)
	var midpoint: Vector2 = (a.pos + b.pos) * 0.5
	sim._separate()
	check(a.pos.distance_to(b.pos) >= 13.9, "opposing bodies separate across grid-cell boundary in one tick")
	check(((a.pos + b.pos) * 0.5).is_equal_approx(midpoint), "contact correction gives neither side extra displacement")
	a.pos = Vector2(400, 400)
	b.pos = a.pos
	for i in 4: sim._separate()
	check(a.pos.is_finite() and b.pos.is_finite() and a.pos.distance_to(b.pos) >= 13.9, "coincident bodies recover without invalid positions")
	b.alive = false
	b.pos = a.pos
	var before: Vector2 = a.pos
	sim._separate()
	check(a.pos == before, "fallen soldiers do not block survivors")
	b.alive = true
	a.pos = Vector2(400, 400)
	b.pos = Vector2(421, 417)
	a.target = b
	a.cooldown = 10
	sim.squads[0].engaged = true
	sim._update_soldier(a, sim.squads[0], 1.0)
	check(a.pos.distance_to(b.pos) >= a.radius + b.radius, "long movement step stops outside target body")
	a.cooldown = 0
	var health: float = b.hp
	sim._update_soldier(a, sim.squads[0], 0.02)
	check(b.hp < health, "diagonal approach reaches striking distance without rounding deadlock")
	sim.dispose()
	sim = fixture(24)
	for i in sim.squads[0].soldiers.size():
		sim.squads[0].soldiers[i].pos = Vector2(350 + (i % 6) * 6, 450 + int(i / 6) * 6)
	var initial := penetration(sim)
	for i in 15: sim._separate()
	var remaining := penetration(sim)
	check(remaining < initial * 0.02, "dense friendly crowd disperses: overlap %.1f -> %.1f" % [initial, remaining])
	sim.dispose()
	var terrain := Terrain.new()
	terrain.reset()
	for y in Terrain.ROWS:
		for x in range(0, 10): terrain.water[y * Terrain.COLS + x] = Terrain.WATER_DEEP
	sim = fixture(2, terrain)
	a = sim.squads[0].soldiers[0]
	b = sim.squads[0].soldiers[1]
	a.pos = Vector2(301, 400)
	b.pos = Vector2(303, 400)
	for i in 20: sim._separate()
	check(sim._open_ground(a.pos) and sim._open_ground(b.pos), "crowd correction stays out of deep water")
	sim.dispose()
	print("Collision failures: %d" % failures)
	quit(failures)
