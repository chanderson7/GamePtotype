## One field battle as pure logic: no nodes, no drawing.
## The battle screen renders it and feeds it orders; tests run it headless.
##
## Each side has a reserve (its army roster), a command meter that refills over time,
## and a war banner at the back of its half. Deployed squads advance on the nearest
## enemy squad, or on the enemy banner if the field is clear. A squad that loses too
## much morale routs and runs for its own edge; men who escape survive the battle.
extends RefCounted

const Troops = preload("res://scripts/data/troops.gd")

const ARENA := Vector2(720.0, 1100.0)
const MID_Y := 550.0
const PLAYER := 0
const ENEMY := 1
const STEP := 1.0 / 30.0
const TIME_LIMIT := 180.0
const MAX_POINTS := 10.0
const START_POINTS := 5.0
const POINT_REGEN := 1.0 / 1.8
const HAND_SIZE := 4
const ROUT_MORALE := 30.0
## Routers run faster than they march and nobody chases them, so a broken squad
## brings some men home. Without this, a lost battle wipes out the whole warband.
const ROUT_SPEED := 1.4
const BANNER_HP := 2500.0
const BANNER_RADIUS := 30.0
const ENGAGE_RANGE := 60.0
const ARROW_SPEED := 460.0
const CELL := 32.0
const MAX_CORPSES := 260


class Soldier:
	var kind := "soldier"
	var squad = null
	var pos := Vector2.ZERO
	var facing := Vector2.UP
	var hp := 100.0
	var max_hp := 100.0
	var cooldown := 0.0
	var target = null
	var alive := true
	var flash := 0.0
	var runup := 0.0
	var slot := Vector2.ZERO


class Squad:
	var id := 0
	var roster_id := -1
	var team := 0
	var type := ""
	var stats := {}
	var level := 1
	var power := 1.0
	var soldiers: Array = []
	var start_men := 0
	var center := Vector2.ZERO
	var facing := Vector2.UP
	var goal := Vector2.ZERO
	var order := "advance" # advance | move | hold | attack
	var order_point := Vector2.ZERO
	var order_target = null
	var focus = null
	var engaged := false
	var morale := 100.0
	var routing := false
	var escaped := 0
	var kills := 0

	func alive_count() -> int:
		var n := 0
		for s in soldiers:
			if s.alive:
				n += 1
		return n

	func is_active() -> bool:
		return not routing and alive_count() > 0

	func average_pos() -> Vector2:
		var sum := Vector2.ZERO
		var n := 0
		for s in soldiers:
			if s.alive:
				sum += s.pos
				n += 1
		return center if n == 0 else sum / n


class Banner:
	var kind := "banner"
	var team := 0
	var pos := Vector2.ZERO
	var hp := 0.0
	var max_hp := 0.0
	var alive := true
	var flash := 0.0


class Projectile:
	var pos := Vector2.ZERO
	var target = null
	var aim := Vector2.ZERO
	var damage := 0.0
	var source = null
	var done := false


var rng := RandomNumberGenerator.new()
var time := 0.0
var squads: Array = []
var reserves: Array = [[], []]
var points: Array = [START_POINTS, START_POINTS]
var banners: Array = []
var projectiles: Array = []
var corpses: Array = []
var events: Array = []
## Commanders that deploy for a side. null means a human plays that side.
var ai: Array = [null, null]
var winner := -1
var end_reason := ""
var _next_id := 1
var _grid := {}
var _tick := 0


# ---------------------------------------------------------------- setup

## Armies are arrays of {id, type, men, xp}, the same shape GameState keeps.
func setup(player_army: Array, enemy_army: Array, seed_value: int = 0) -> void:
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	reserves = [_to_reserve(player_army), _to_reserve(enemy_army)]
	banners = [_make_banner(PLAYER), _make_banner(ENEMY)]
	points = [START_POINTS, START_POINTS]


func _to_reserve(army: Array) -> Array:
	var out := []
	for entry in army:
		var men := int(entry.get("men", 0))
		if men <= 0:
			continue
		out.append({
			"roster_id": int(entry.get("id", -1)),
			"type": String(entry["type"]),
			"men": men,
			"level": Troops.level_for(int(entry.get("xp", 0))),
		})
	return out


func _make_banner(team: int) -> Banner:
	var b := Banner.new()
	b.team = team
	b.pos = Vector2(ARENA.x * 0.5, ARENA.y - 56.0 if team == PLAYER else 56.0)
	b.hp = BANNER_HP
	b.max_hp = BANNER_HP
	return b


# ---------------------------------------------------------------- deploying

## The cards a side can play right now: the front of its reserve.
func hand(team: int) -> Array:
	return reserves[team].slice(0, HAND_SIZE)


func in_deploy_zone(team: int, at: Vector2) -> bool:
	if at.x < 30.0 or at.x > ARENA.x - 30.0:
		return false
	if team == PLAYER:
		return at.y >= MID_Y + 50.0 and at.y <= ARENA.y - 100.0
	return at.y <= MID_Y - 50.0 and at.y >= 100.0


func can_afford(team: int, index: int) -> bool:
	if index < 0 or index >= mini(HAND_SIZE, reserves[team].size()):
		return false
	return float(points[team]) >= Troops.cost(reserves[team][index]["type"])


func deploy(team: int, index: int, at: Vector2):
	if winner != -1 or not can_afford(team, index) or not in_deploy_zone(team, at):
		return null
	var entry: Dictionary = reserves[team][index]
	reserves[team].remove_at(index)
	var type: String = entry["type"]
	points[team] = float(points[team]) - Troops.cost(type)

	var sq := Squad.new()
	sq.id = _next_id
	_next_id += 1
	sq.roster_id = entry["roster_id"]
	sq.team = team
	sq.type = type
	sq.stats = Troops.stats(type)
	sq.level = entry["level"]
	sq.power = Troops.power_for(sq.level)
	sq.facing = Vector2.UP if team == PLAYER else Vector2.DOWN
	sq.center = at
	sq.goal = at
	var men: int = entry["men"]
	sq.start_men = men
	var spacing: float = float(sq.stats["radius"]) * 2.0 + 5.0
	var slots := _formation_slots(men, spacing)
	for i in men:
		var so := Soldier.new()
		so.squad = sq
		so.slot = slots[i]
		so.pos = at + _slot_world(so.slot, sq.facing)
		so.facing = sq.facing
		so.max_hp = float(sq.stats["hp"]) * sq.power
		so.hp = so.max_hp
		so.cooldown = rng.randf_range(0.0, 0.4)
		sq.soldiers.append(so)
	squads.append(sq)
	events.append({"type": "deploy", "squad": sq})
	return sq


func _formation_slots(men: int, spacing: float) -> Array:
	var cols := mini(5, men)
	var rows := int(ceil(float(men) / cols))
	var out := []
	for i in men:
		var row := int(float(i) / cols)
		var in_row := mini(cols, men - row * cols)
		var col := i - row * cols
		out.append(Vector2((col - (in_row - 1) * 0.5) * spacing, (row - (rows - 1) * 0.5) * spacing))
	return out


## Slot offsets are in squad space: x to the right, y toward the rear.
func _slot_world(slot: Vector2, facing: Vector2) -> Vector2:
	var right := Vector2(-facing.y, facing.x)
	return right * slot.x - facing * slot.y


# ---------------------------------------------------------------- orders

func order_move(sq, point: Vector2) -> void:
	if sq == null or not sq.is_active():
		return
	sq.order = "move"
	sq.order_point = Vector2(clampf(point.x, 20.0, ARENA.x - 20.0), clampf(point.y, 20.0, ARENA.y - 20.0))
	sq.order_target = null


func order_attack(sq, foe) -> void:
	if sq == null or not sq.is_active() or foe == null or not foe.is_active():
		return
	sq.order = "attack"
	sq.order_target = foe


func order_advance(sq) -> void:
	if sq == null:
		return
	sq.order = "advance"
	sq.order_target = null


## The closest squad of `team` with a man within `radius` of `point`.
func squad_at(team: int, point: Vector2, radius: float = 40.0):
	var best = null
	var best_d := radius * radius
	for sq in squads:
		if sq.team != team or sq.alive_count() == 0:
			continue
		for so in sq.soldiers:
			if so.alive:
				var d: float = point.distance_squared_to(so.pos)
				if d < best_d:
					best_d = d
					best = sq
	return best


# ---------------------------------------------------------------- simulation

func step(dt: float = STEP) -> void:
	if winner != -1:
		return
	time += dt
	# Alternate who acts first each tick. Whoever moves first wins ties in the melee,
	# so a fixed order would quietly favor one side.
	_tick += 1
	var flip := _tick % 2 == 1
	for i in 2:
		var t := 1 - i if flip else i
		points[t] = minf(MAX_POINTS, float(points[t]) + POINT_REGEN * dt)
		if ai[t] != null:
			ai[t].update(self, dt)
	for b in banners:
		b.flash = maxf(0.0, b.flash - dt * 4.0)
	_build_grid()
	var order := squads.duplicate()
	if flip:
		order.reverse()
	for sq in order:
		_update_squad(sq, dt)
	for sq in order:
		for so in sq.soldiers:
			if so.alive:
				_update_soldier(so, sq, dt)
	_separate()
	_update_projectiles(dt)
	_check_end()


func _reach(sq) -> float:
	return float(sq.stats["range"]) if sq.stats["ranged"] else float(sq.stats["reach"])


func _update_squad(sq, dt: float) -> void:
	if sq.alive_count() == 0:
		return
	var avg: Vector2 = sq.average_pos()
	if not sq.routing and sq.morale <= ROUT_MORALE:
		sq.routing = true
		sq.focus = null
		events.append({"type": "rout", "squad": sq})
	if sq.routing:
		return
	if sq.order == "attack" and (sq.order_target == null or not sq.order_target.is_active()):
		order_advance(sq)

	var reach := _reach(sq)
	var foe = null
	match sq.order:
		"attack":
			foe = sq.order_target
		"advance":
			foe = nearest_enemy_squad(sq.team, avg, INF)
		"hold":
			foe = nearest_enemy_squad(sq.team, avg, reach + ENGAGE_RANGE + 50.0)
		_:
			foe = null # marching to a point ignores enemies until it arrives
	sq.focus = foe

	if sq.order == "move":
		sq.goal = sq.order_point
		if sq.center.distance_to(sq.order_point) < 6.0:
			sq.order = "hold"
	elif sq.order == "hold":
		sq.goal = sq.order_point
	elif foe != null:
		sq.goal = foe.average_pos()
	else:
		sq.goal = banners[1 - sq.team].pos

	# Engaged squads break formation and fight man to man.
	sq.engaged = false
	if foe != null:
		var slack := 20.0 if sq.stats["ranged"] else ENGAGE_RANGE
		sq.engaged = _squad_gap(sq, foe) <= reach + slack
	elif sq.order == "advance":
		var banner = banners[1 - sq.team]
		sq.engaged = banner.alive and avg.distance_to(banner.pos) - BANNER_RADIUS <= reach + ENGAGE_RANGE
	if sq.engaged:
		sq.center = sq.center.lerp(avg, 0.15)
		return

	var to: Vector2 = sq.goal - sq.center
	var stop := 0.0
	if foe != null and sq.stats["ranged"]:
		stop = reach * 0.85 # archers halt at bow range
	var dist := to.length()
	if dist > stop + 2.0:
		var dir := to / dist
		sq.center += dir * minf(dist - stop, float(sq.stats["speed"]) * dt)
		sq.facing = dir


func _squad_gap(a, b) -> float:
	var best := INF
	for s in a.soldiers:
		if not s.alive:
			continue
		for o in b.soldiers:
			if not o.alive:
				continue
			var d: float = s.pos.distance_squared_to(o.pos)
			if d < best:
				best = d
	if best == INF:
		return INF
	return sqrt(best) - float(a.stats["radius"]) - float(b.stats["radius"])


func _update_soldier(so, sq, dt: float) -> void:
	so.cooldown = maxf(0.0, so.cooldown - dt)
	so.flash = maxf(0.0, so.flash - dt * 5.0)
	so.runup = maxf(0.0, so.runup - 30.0 * dt)
	var speed: float = sq.stats["speed"]

	if sq.routing:
		var exit_y := ARENA.y + 40.0 if sq.team == PLAYER else -40.0
		_walk(so, Vector2(so.pos.x, exit_y), speed * ROUT_SPEED, dt)
		if (sq.team == PLAYER and so.pos.y >= ARENA.y + 20.0) or (sq.team == ENEMY and so.pos.y <= -20.0):
			so.alive = false
			sq.escaped += 1
		return

	if not sq.engaged:
		so.target = null
		so.facing = sq.facing
		so.runup += _walk(so, sq.center + _slot_world(so.slot, sq.facing), speed * 1.25, dt)
		return

	if not _target_ok(so, sq):
		so.target = _pick_target(so, sq)
	if so.target == null:
		so.runup += _walk(so, sq.goal, speed, dt)
		return

	var tpos: Vector2 = so.target.pos
	var trad: float = BANNER_RADIUS if so.target.kind == "banner" else float(so.target.squad.stats["radius"])
	var gap: float = so.pos.distance_to(tpos) - trad - float(sq.stats["radius"])
	if tpos != so.pos:
		so.facing = (tpos - so.pos).normalized()
	var reach := _reach(sq)
	if gap > reach:
		var moved := _walk(so, tpos, speed, dt)
		if gap > reach + 20.0:
			so.runup += moved # only a real run-up counts toward a charge, not shuffling in the melee
	elif so.cooldown <= 0.0:
		_strike(so, sq, so.target, gap)
		so.cooldown = float(sq.stats["cooldown"]) * rng.randf_range(0.85, 1.15)
		so.runup = 0.0


func _walk(so, dest: Vector2, speed: float, dt: float) -> float:
	var before: Vector2 = so.pos
	so.pos = before.move_toward(dest, speed * dt)
	return before.distance_to(so.pos)


func _target_ok(so, sq) -> bool:
	var t = so.target
	if t == null or not t.alive:
		return false
	if t.kind == "banner":
		return sq.focus == null
	if t.squad.team == sq.team or t.squad.routing:
		return false
	# Keep fighting whoever is in front of you, unless your squad was sent elsewhere.
	return sq.focus == null or t.squad == sq.focus or so.pos.distance_to(t.pos) < 50.0


func _pick_target(so, sq):
	var best = null
	var best_d := INF
	if sq.focus != null:
		for e in sq.focus.soldiers:
			if e.alive:
				var d: float = so.pos.distance_squared_to(e.pos)
				if d < best_d:
					best_d = d
					best = e
	for e in _nearby(so.pos, 60.0):
		if e.squad.team != sq.team and not e.squad.routing:
			var d2: float = so.pos.distance_squared_to(e.pos)
			if d2 < best_d * 0.6:
				best_d = d2
				best = e
	if best == null and sq.focus == null:
		var banner = banners[1 - sq.team]
		if banner.alive:
			return banner
	return best


func _strike(so, sq, target, gap: float) -> void:
	var dmg: float = float(sq.stats["damage"]) * sq.power * rng.randf_range(0.8, 1.2)
	var ranged: bool = sq.stats["ranged"]
	if target.kind == "banner":
		if ranged:
			_shoot(so, sq, target, dmg)
		else:
			_hit_banner(target, dmg)
		return
	var target_type: String = target.squad.type
	dmg *= float(sq.stats["bonus"].get(target_type, 1.0))
	var charge := false
	if sq.type == Troops.CAVALRY and so.runup >= Troops.CHARGE_RUNUP and target_type != Troops.SPEARMEN:
		dmg *= Troops.CHARGE_MULTIPLIER
		charge = true
	if ranged:
		if gap < 30.0:
			dmg *= 0.5 # point-blank shots are rushed
		_shoot(so, sq, target, dmg)
	else:
		_damage(target, dmg, sq, charge)
		if charge:
			events.append({"type": "charge", "pos": target.pos})


func _shoot(so, sq, target, dmg: float) -> void:
	var p := Projectile.new()
	p.pos = so.pos
	p.target = target
	p.aim = target.pos
	p.damage = dmg
	p.source = sq
	projectiles.append(p)


func _update_projectiles(dt: float) -> void:
	var travel := ARROW_SPEED * dt
	for p in projectiles:
		if p.target != null and p.target.alive:
			p.aim = p.target.pos
		var to: Vector2 = p.aim - p.pos
		if to.length() <= travel:
			p.done = true
			if p.target != null and p.target.alive:
				if p.target.kind == "banner":
					_hit_banner(p.target, p.damage)
				else:
					_damage(p.target, p.damage, p.source)
		else:
			p.pos += to.normalized() * travel
	projectiles = projectiles.filter(func(p): return not p.done)


func _damage(victim, dmg: float, attacker, charge: bool = false) -> void:
	if not victim.alive:
		return
	victim.hp -= dmg
	victim.flash = 1.0
	var vs = victim.squad
	if charge:
		vs.morale -= 3.0
	if victim.hp <= 0.0:
		victim.alive = false
		vs.morale -= 100.0 / float(vs.start_men) * 0.8 + 2.0
		if attacker != null:
			attacker.kills += 1
		corpses.append({"pos": victim.pos, "team": vs.team})
		if corpses.size() > MAX_CORPSES:
			corpses.pop_front()


func _hit_banner(b, dmg: float) -> void:
	if not b.alive:
		return
	b.hp = maxf(0.0, b.hp - dmg)
	b.flash = 1.0
	if b.hp <= 0.0:
		b.alive = false


# ---------------------------------------------------------------- crowding

func _build_grid() -> void:
	_grid.clear()
	for sq in squads:
		for so in sq.soldiers:
			if so.alive:
				var c := Vector2i(floori(so.pos.x / CELL), floori(so.pos.y / CELL))
				if _grid.has(c):
					_grid[c].append(so)
				else:
					_grid[c] = [so]


func _nearby(pos: Vector2, radius: float) -> Array:
	var out := []
	var c0 := Vector2i(floori((pos.x - radius) / CELL), floori((pos.y - radius) / CELL))
	var c1 := Vector2i(floori((pos.x + radius) / CELL), floori((pos.y + radius) / CELL))
	var r2 := radius * radius
	for cy in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			var cell = _grid.get(Vector2i(cx, cy))
			if cell == null:
				continue
			for so in cell:
				if so.alive and pos.distance_squared_to(so.pos) <= r2:
					out.append(so)
	return out


## Push overlapping men apart. Each pair is resolved once and both move half the
## overlap, so neither side gets shoved back just because it was updated first.
func _separate() -> void:
	for sq in squads:
		var r: float = sq.stats["radius"]
		for so in sq.soldiers:
			if not so.alive:
				continue
			var my_id: int = so.get_instance_id()
			for o in _nearby(so.pos, 22.0):
				if o.get_instance_id() <= my_id:
					continue
				var min_d: float = r + float(o.squad.stats["radius"]) - 1.0
				var diff: Vector2 = so.pos - o.pos
				var d := diff.length()
				if d < 0.01:
					diff = Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
					d = maxf(diff.length(), 0.01)
				if d < min_d:
					var push := diff / d * (min_d - d) * 0.5
					so.pos += push
					o.pos -= push
	for sq in squads:
		if sq.routing:
			continue
		for so in sq.soldiers:
			if so.alive:
				so.pos = Vector2(clampf(so.pos.x, 8.0, ARENA.x - 8.0), clampf(so.pos.y, 8.0, ARENA.y - 8.0))


# ---------------------------------------------------------------- queries

func nearest_enemy_squad(team: int, from: Vector2, max_dist: float):
	var best = null
	var best_d := max_dist
	for sq in squads:
		if sq.team == team or not sq.is_active():
			continue
		var d: float = from.distance_to(sq.average_pos())
		if d < best_d:
			best_d = d
			best = sq
	return best


## The enemy squad closest to this side's banner.
func biggest_threat(team: int):
	return nearest_enemy_squad(team, banners[team].pos, INF)


func has_active(team: int) -> bool:
	for sq in squads:
		if sq.team == team and sq.is_active():
			return true
	return false


func men_on_field(team: int) -> int:
	var n := 0
	for sq in squads:
		if sq.team == team and sq.is_active():
			n += sq.alive_count()
	return n


func men_in_reserve(team: int) -> int:
	var n := 0
	for e in reserves[team]:
		n += int(e["men"])
	return n


func _check_end() -> void:
	for t in 2:
		if not banners[t].alive:
			_finish(1 - t, "banner")
			return
	for t in 2:
		if reserves[t].is_empty() and not has_active(t):
			_finish(1 - t, "rout")
			return
	if time >= TIME_LIMIT:
		var mine: float = banners[PLAYER].hp / banners[PLAYER].max_hp
		var theirs: float = banners[ENEMY].hp / banners[ENEMY].max_hp
		if absf(mine - theirs) > 0.01:
			_finish(PLAYER if mine > theirs else ENEMY, "time")
		else:
			var a := men_on_field(PLAYER) + men_in_reserve(PLAYER)
			var b := men_on_field(ENEMY) + men_in_reserve(ENEMY)
			_finish(PLAYER if a >= b else ENEMY, "time")


## Pull a side off the field. Its men on the field survive; the other side wins.
func concede(team: int) -> void:
	if winner == -1:
		_finish(1 - team, "retreat")


func _finish(team: int, reason: String) -> void:
	winner = team
	end_reason = reason
	events.append({"type": "end", "winner": team})


## Soldiers, squads and their targets point at each other. Call this when a battle is
## over so those reference cycles don't keep the whole battle in memory.
func dispose() -> void:
	for sq in squads:
		for so in sq.soldiers:
			so.squad = null
			so.target = null
		sq.soldiers.clear()
		sq.focus = null
		sq.order_target = null
	squads.clear()
	projectiles.clear()
	events.clear()
	ai = [null, null]


## Survivors per roster entry, for the campaign layer. Escaped routers count as survivors.
func result_for(team: int) -> Dictionary:
	var by_id := {}
	var lost := 0
	var killed := 0
	for e in reserves[team]:
		by_id[e["roster_id"]] = {"men": int(e["men"]), "kills": 0}
	for sq in squads:
		if sq.team != team:
			continue
		var survivors: int = sq.alive_count() + sq.escaped
		by_id[sq.roster_id] = {"men": survivors, "kills": sq.kills}
		lost += sq.start_men - survivors
		killed += sq.kills
	return {"won": winner == team, "reason": end_reason, "squads": by_id, "lost": lost, "killed": killed, "time": time}
