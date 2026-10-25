## One field battle as pure logic: no nodes, no drawing.
## The battle screen renders it and feeds it orders; tests run it headless.
##
## A battle has two phases. During deployment each side places its whole army in its
## own half of the field, and time stands still. Once the battle starts, squads hold
## where they were placed until ordered to advance, march or attack. A squad that loses
## too much morale routs and runs for its own edge; men who escape survive the battle.
## The battle ends when one side has no squad left standing.
extends RefCounted

const Troops = preload("res://scripts/data/troops.gd")

const ARENA := Vector2(720.0, 1100.0)
const MID_Y := 550.0
const PLAYER := 0
const ENEMY := 1
const PHASE_DEPLOY := 0
const PHASE_BATTLE := 1
const STEP := 1.0 / 30.0
const TIME_LIMIT := 180.0
## Distance from the midline to the front edge of each side's deployment zone.
const DEPLOY_GAP := 70.0
## Room kept between squads placed side by side.
const SQUAD_GAP := 10.0
const ROUT_MORALE := 30.0
## Routers run faster than they march and nobody chases them, so a broken squad
## brings some men home. Without this, a lost battle wipes out the whole warband.
const ROUT_SPEED := 1.4
const ENGAGE_RANGE := 60.0
## A squad standing still turns to face enemy squads this close.
const FACE_RANGE := 260.0
## How far out of its way (in arena units) an advancing squad goes to fight a squad it
## counters, and how much closer a squad that counters it must be before it takes that fight.
const COUNTER_PULL := 260.0
## An advancing squad only switches targets for one this much more attractive.
const RETARGET_MARGIN := 80.0
## Advancing squads keep to marching pace, so the army arrives together, until their
## target is this close; then they charge at full speed.
const MARCH_SPEED := 48.0
const CHARGE_DISTANCE := 180.0
const ARROW_SPEED := 460.0
const CELL := 32.0
const MAX_CORPSES := 260


class Soldier:
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
	var push := Vector2.ZERO


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
	var order := "hold" # hold | advance | move | attack
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


class Projectile:
	var pos := Vector2.ZERO
	var target = null
	var aim := Vector2.ZERO
	var damage := 0.0
	var source = null
	var done := false


var rng := RandomNumberGenerator.new()
var phase := PHASE_DEPLOY
var time := 0.0
var squads: Array = []
## Every squad each side brought, placed or not, in roster order.
var armies: Array = [[], []]
## The squads each side has not placed yet.
var reserves: Array = [[], []]
var projectiles: Array = []
var corpses: Array = []
var events: Array = []
## Commanders that give orders for a side once the battle starts. null means a human
## plays that side.
var ai: Array = [null, null]
var winner := -1
var end_reason := ""
var _next_id := 1
var _grid := {}


# ---------------------------------------------------------------- setup

## Armies are arrays of {id, type, men, xp}, the same shape GameState keeps.
func setup(player_army: Array, enemy_army: Array, seed_value: int = 0) -> void:
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	armies = [_to_entries(player_army), _to_entries(enemy_army)]
	reserves = [armies[PLAYER].duplicate(), armies[ENEMY].duplicate()]


func _to_entries(army: Array) -> Array:
	var out := []
	var used := {}
	var spare := -2
	for entry in army:
		var men := int(entry.get("men", 0))
		if men <= 0:
			continue
		var id := int(entry.get("id", -1))
		if id < 0 or used.has(id):
			# Placing looks squads up by id, so each one needs its own.
			id = spare
			spare -= 1
		used[id] = true
		out.append({
			"roster_id": id,
			"type": String(entry["type"]),
			"men": men,
			"level": Troops.level_for(int(entry.get("xp", 0))),
		})
	return out


# ---------------------------------------------------------------- deployment

## Every squad a side brought, in roster order, whether placed yet or not.
func roster(team: int) -> Array:
	return armies[team]


func deploy_zone(team: int) -> Rect2:
	if team == PLAYER:
		var top := MID_Y + DEPLOY_GAP
		return Rect2(20.0, top, ARENA.x - 40.0, ARENA.y - 30.0 - top)
	return Rect2(20.0, 30.0, ARENA.x - 40.0, MID_Y - DEPLOY_GAP - 30.0)


func in_deploy_zone(team: int, at: Vector2) -> bool:
	return deploy_zone(team).grow(12.0).has_point(at)


func placed_squad(team: int, roster_id: int):
	for sq in squads:
		if sq.team == team and sq.roster_id == roster_id:
			return sq
	return null


func all_placed(team: int) -> bool:
	return reserves[team].is_empty()


## Put a squad on the field, or move one already placed. Squads dropped on top of each
## other are nudged to the nearest free spot. Returns the squad, or null if it can't go there.
func place(team: int, roster_id: int, at: Vector2):
	if phase != PHASE_DEPLOY or winner != -1 or not in_deploy_zone(team, at):
		return null
	var sq = placed_squad(team, roster_id)
	if sq != null:
		var to = _free_spot(team, at, _footprint(sq.type, sq.start_men), sq)
		if to == null:
			return null
		_move_formation(sq, to)
		return sq
	for i in reserves[team].size():
		var entry: Dictionary = reserves[team][i]
		if entry["roster_id"] != roster_id:
			continue
		var spot = _free_spot(team, at, _footprint(entry["type"], entry["men"]), null)
		if spot == null:
			return null
		reserves[team].remove_at(i)
		return _spawn(team, entry, spot)
	return null


## Place every squad a side has left in a battle line: swords and spears in front,
## bows behind them, horse on the wings. `jitter` shuffles positions a little.
func auto_deploy(team: int, jitter: float = 0.0) -> void:
	if phase != PHASE_DEPLOY or reserves[team].is_empty():
		return
	var by_type := {}
	for type in Troops.ORDER:
		by_type[type] = []
	for e in reserves[team]:
		by_type[e["type"]].append(e)
	# Alternate swords and spears so every stretch of the line has both.
	var line := []
	var inf: Array = by_type[Troops.INFANTRY]
	var spr: Array = by_type[Troops.SPEARMEN]
	for i in maxi(inf.size(), spr.size()):
		if i < inf.size():
			line.append(inf[i])
		if i < spr.size():
			line.append(spr[i])
	var cav: Array = by_type[Troops.CAVALRY]
	var spots := [] # [entry, depth from the midline, x]
	_add_rows(spots, line, 150.0, Vector2(150.0, 570.0) if not cav.is_empty() else Vector2(90.0, 630.0))
	_add_rows(spots, by_type[Troops.ARCHERS], 290.0, Vector2(150.0, 570.0))
	for i in mini(2, cav.size()):
		spots.append([cav[i], 230.0, 85.0 if i == 0 else ARENA.x - 85.0])
	_add_rows(spots, cav.slice(2), 380.0, Vector2(250.0, 470.0))
	for s in spots:
		var depth: float = s[1]
		var x: float = s[2]
		if jitter > 0.0:
			depth += rng.randf_range(-jitter, jitter) * 0.6
			x += rng.randf_range(-jitter, jitter)
		place(team, s[0]["roster_id"], Vector2(x, MID_Y + depth if team == PLAYER else MID_Y - depth))


## Lay squads out in rows across `span` (min x, max x), adding more rows when crowded.
func _add_rows(spots: Array, entries: Array, depth: float, span: Vector2) -> void:
	if entries.is_empty():
		return
	var per_row := int((span.y - span.x) / 110.0) + 1
	var rows := int(ceil(float(entries.size()) / per_row))
	var per := int(ceil(float(entries.size()) / rows))
	var i := 0
	var row := 0
	while i < entries.size():
		var count := mini(per, entries.size() - i)
		var mid := (span.x + span.y) * 0.5
		var gap := 0.0 if count <= 1 else minf(125.0, (span.y - span.x) / (count - 1))
		for k in count:
			spots.append([entries[i + k], depth + row * 70.0, mid + (k - (count - 1) * 0.5) * gap])
		i += count
		row += 1


## Ends deployment. Anything still unplaced is put in the battle line first.
func start_battle() -> void:
	if phase != PHASE_DEPLOY or winner != -1:
		return
	for t in 2:
		auto_deploy(t)
	phase = PHASE_BATTLE


func _spawn(team: int, entry: Dictionary, at: Vector2):
	var type: String = entry["type"]
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
	var men: int = entry["men"]
	sq.start_men = men
	var spacing: float = float(sq.stats["radius"]) * 2.0 + 5.0
	var slots := _formation_slots(men, spacing)
	for i in men:
		var so := Soldier.new()
		so.squad = sq
		so.slot = slots[i]
		so.facing = sq.facing
		so.max_hp = float(sq.stats["hp"]) * sq.power
		so.hp = so.max_hp
		so.cooldown = rng.randf_range(0.0, 0.4)
		sq.soldiers.append(so)
	_move_formation(sq, at)
	squads.append(sq)
	return sq


func _move_formation(sq, at: Vector2) -> void:
	sq.center = at
	sq.goal = at
	sq.order = "hold"
	sq.order_point = at
	for so in sq.soldiers:
		so.pos = at + _slot_world(so.slot, sq.facing)


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


## Half the width and depth a squad covers in formation, with room for spears and bodies.
func _footprint(type: String, men: int) -> Vector2:
	var r := float(Troops.stats(type)["radius"])
	var spacing := r * 2.0 + 5.0
	var cols := mini(5, maxi(1, men))
	var rows := int(ceil(float(men) / cols))
	return Vector2((cols - 1) * spacing * 0.5 + r + 4.0, (rows - 1) * spacing * 0.5 + r + 4.0)


## The free spot in the zone closest to `at` for a squad of footprint `half`, or null.
func _free_spot(team: int, at: Vector2, half: Vector2, ignore):
	var zone := deploy_zone(team)
	var first := _fit(zone, at, half)
	if not _overlaps(team, first, half, ignore):
		return first
	# Search in each side's own frame (+y is toward its rear), so ties between equally
	# good spots break the same way for both armies.
	var back := 1.0 if team == PLAYER else -1.0
	for ring in range(1, 14):
		var radius := ring * 22.0
		var steps := 8 + ring * 2
		var best = null
		var best_d := INF
		for k in steps:
			var a := TAU * float(k) / steps
			var c := _fit(zone, at + Vector2(cos(a), sin(a) * back) * radius, half)
			if _overlaps(team, c, half, ignore):
				continue
			var d := c.distance_squared_to(at)
			if d < best_d:
				best_d = d
				best = c
		if best != null:
			return best
	return null


func _fit(zone: Rect2, at: Vector2, half: Vector2) -> Vector2:
	return Vector2(
		clampf(at.x, zone.position.x + half.x, zone.end.x - half.x),
		clampf(at.y, zone.position.y + half.y, zone.end.y - half.y))


func _overlaps(team: int, at: Vector2, half: Vector2, ignore) -> bool:
	for sq in squads:
		if sq.team != team or sq == ignore:
			continue
		var other := _footprint(sq.type, sq.start_men)
		if absf(at.x - sq.center.x) < half.x + other.x + SQUAD_GAP and absf(at.y - sq.center.y) < half.y + other.y + SQUAD_GAP:
			return true
	return false


# ---------------------------------------------------------------- orders

## Stand where you are and fight anyone who comes close.
func order_hold(sq) -> void:
	if sq == null or not sq.is_active():
		return
	sq.order = "hold"
	sq.order_point = _clamp_to_arena(sq.center)
	sq.order_target = null


## Go after the enemy: each squad picks the enemy squad it fights best (see best_target)
## and keeps fighting until none are left.
func order_advance(sq) -> void:
	if sq == null or not sq.is_active():
		return
	sq.order = "advance"
	sq.order_target = null


## March to a point, ignoring enemies on the way, then hold there.
func order_move(sq, point: Vector2) -> void:
	if sq == null or not sq.is_active():
		return
	sq.order = "move"
	sq.order_point = _clamp_to_arena(point)
	sq.order_target = null


func order_attack(sq, foe) -> void:
	if sq == null or not sq.is_active() or foe == null or not foe.is_active():
		return
	sq.order = "attack"
	sq.order_target = foe


## "advance" or "hold" for every squad a side still has fighting.
func order_all(team: int, order: String) -> void:
	for sq in squads:
		if sq.team != team or not sq.is_active():
			continue
		if order == "hold":
			order_hold(sq)
		else:
			order_advance(sq)


func _clamp_to_arena(p: Vector2) -> Vector2:
	return Vector2(clampf(p.x, 20.0, ARENA.x - 20.0), clampf(p.y, 20.0, ARENA.y - 20.0))


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
	if winner != -1 or phase != PHASE_BATTLE:
		return
	time += dt
	# Who acts first each tick is a coin flip. Acting first or second breaks ties, like
	# which archer looses the first arrow when two lines come into range on the same
	# tick, so a fixed order, or even a strict alternation, quietly favors one side.
	var flip := rng.randi() % 2 == 1
	for i in 2:
		var t := 1 - i if flip else i
		if ai[t] != null:
			ai[t].update(self, dt)
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
			foe = _advance_focus(sq, avg)
		"hold":
			foe = nearest_enemy_squad(sq.team, avg, reach + ENGAGE_RANGE + 50.0)
		_:
			foe = null # marching to a point ignores enemies until it arrives
	sq.focus = foe

	var chasing := false
	if sq.order == "move":
		sq.goal = sq.order_point
		if sq.center.distance_to(sq.order_point) < 6.0:
			sq.order = "hold"
	elif sq.order == "hold":
		sq.goal = sq.order_point
	elif foe != null:
		sq.goal = foe.average_pos()
		chasing = true
	else:
		sq.goal = sq.center

	# Engaged squads break formation and fight man to man.
	sq.engaged = false
	if foe != null:
		var slack := 20.0 if sq.stats["ranged"] else ENGAGE_RANGE
		sq.engaged = _squad_gap(sq, foe) <= reach + slack
	if sq.engaged:
		sq.center = sq.center.lerp(avg, 0.15)
		return

	var to: Vector2 = sq.goal - sq.center
	var stop := reach * 0.85 if chasing and sq.stats["ranged"] else 0.0 # archers halt at bow range
	var dist := to.length()
	if dist > stop + 2.0:
		var dir := to / dist
		var pace: float = sq.stats["speed"]
		if sq.order == "advance" and dist - stop > CHARGE_DISTANCE:
			pace = minf(pace, MARCH_SPEED)
		sq.center += dir * minf(dist - stop, pace * dt)
		sq.facing = dir
	else:
		# Standing still: turn to meet an enemy squad that comes close, otherwise face
		# the enemy's end of the field (so a squad that walked back to its post doesn't
		# stand there facing its own lines).
		var want := Vector2.UP if sq.team == PLAYER else Vector2.DOWN
		var threat = nearest_enemy_squad(sq.team, avg, FACE_RANGE)
		if threat != null and threat.average_pos().distance_to(sq.center) > 1.0:
			want = (threat.average_pos() - sq.center).normalized()
		if sq.facing.dot(want) < 0.995:
			sq.facing = sq.facing.slerp(want, minf(1.0, dt * 2.5)).normalized()


## An advancing squad finishes the fight it is in, and otherwise only changes targets
## for one that is clearly better, so it doesn't dither between two.
func _advance_focus(sq, avg: Vector2):
	var current = sq.focus
	if current == null or not current.is_active():
		return best_target(sq, avg)
	if sq.engaged:
		return current
	var best = best_target(sq, avg)
	if best == null or best == current:
		return current
	if target_score(sq, current, avg) - target_score(sq, best, avg) < RETARGET_MARGIN:
		return current
	return best


## How attractive `foe` is as a target for `sq` standing at `from`; lower is better.
## Distance, less a pull toward squads it counters and squads already shaken, plus a
## push away from the squads that counter it.
func target_score(sq, foe, from: Vector2) -> float:
	var score: float = from.distance_to(foe.average_pos())
	if Troops.COUNTERED_BY[foe.type] == sq.type:
		score -= COUNTER_PULL
	elif Troops.COUNTERED_BY[sq.type] == foe.type:
		score += COUNTER_PULL
	return score - (100.0 - float(foe.morale)) * 0.8


## The enemy squad an advancing squad goes for.
func best_target(sq, from: Vector2):
	var best = null
	var best_score := INF
	for foe in squads:
		if foe.team == sq.team or not foe.is_active():
			continue
		var score := target_score(sq, foe, from)
		if score < best_score:
			best_score = score
			best = foe
	return best


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
	var gap: float = so.pos.distance_to(tpos) - float(so.target.squad.stats["radius"]) - float(sq.stats["radius"])
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
	return best


func _strike(so, sq, target, gap: float) -> void:
	var dmg: float = float(sq.stats["damage"]) * sq.power * rng.randf_range(0.8, 1.2)
	var target_type: String = target.squad.type
	dmg *= float(sq.stats["bonus"].get(target_type, 1.0))
	var charge := false
	if sq.type == Troops.CAVALRY and so.runup >= Troops.CHARGE_RUNUP and target_type != Troops.SPEARMEN:
		dmg *= Troops.CHARGE_MULTIPLIER
		charge = true
	if sq.stats["ranged"]:
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
## overlap. Pushes are summed first and applied together, so the result doesn't depend
## on who happens to be processed first and neither side is quietly favored.
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
					so.push += push
					o.push -= push
	for sq in squads:
		for so in sq.soldiers:
			if not so.alive:
				continue
			so.pos += so.push.limit_length(4.0)
			so.push = Vector2.ZERO
			if not sq.routing:
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


func has_active(team: int) -> bool:
	for sq in squads:
		if sq.team == team and sq.is_active():
			return true
	return false


## Men still fighting: alive, on the field, and not running.
func men_on_field(team: int) -> int:
	var n := 0
	for sq in squads:
		if sq.team == team and sq.is_active():
			n += sq.alive_count()
	return n


## The share of a side's army that is still fighting, from 0 to 1.
func strength(team: int) -> float:
	var start := 0
	for e in armies[team]:
		start += int(e["men"])
	return float(men_on_field(team)) / maxf(1.0, float(start))


func _check_end() -> void:
	var standing := [has_active(PLAYER), has_active(ENEMY)]
	if standing[PLAYER] and standing[ENEMY]:
		if time >= TIME_LIMIT:
			var mine := strength(PLAYER)
			var theirs := strength(ENEMY)
			if absf(mine - theirs) > 0.0001:
				_finish(PLAYER if mine > theirs else ENEMY, "time")
			else:
				_finish(_more(men_on_field(PLAYER), men_on_field(ENEMY)), "time")
		return
	if standing[PLAYER] != standing[ENEMY]:
		_finish(PLAYER if standing[PLAYER] else ENEMY, "rout")
		return
	# Both armies broke on the same tick: whoever has more men left alive holds the field.
	var alive := [0, 0]
	for sq in squads:
		alive[sq.team] += sq.alive_count()
	_finish(_more(alive[PLAYER], alive[ENEMY]), "rout")


## The side with more; a dead heat is a coin flip.
func _more(player_count: int, enemy_count: int) -> int:
	if player_count != enemy_count:
		return PLAYER if player_count > enemy_count else ENEMY
	return rng.randi_range(PLAYER, ENEMY)


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
