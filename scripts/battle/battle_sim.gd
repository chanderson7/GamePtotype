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

const ARENA := Vector2(840.0, 1260.0)
const MID_Y := 630.0
const PLAYER := 0
const ENEMY := 1
const PHASE_DEPLOY := 0
const PHASE_BATTLE := 1
const STEP := 1.0 / 30.0
const TIME_LIMIT := 300.0
## Distance from the midline to the front edge of each side's deployment zone.
const DEPLOY_GAP := 70.0
## Room kept between squads placed side by side.
const SQUAD_GAP := 10.0
const ROUT_MORALE := 30.0
## Routers run faster than they march and nobody chases them, so a broken squad
## brings some men home. Without this, a lost battle wipes out the whole warband.
const ROUT_SPEED := 1.4
## Morale a squad loses in all when every one of its men takes a charging horseman's hit.
const CHARGE_SHOCK := 30.0
const ENGAGE_RANGE := 60.0
## A squad standing still turns to face enemy squads this close.
const FACE_RANGE := 280.0
## How far out of its way (in arena units) an advancing squad goes to fight a squad it
## counters, and how much closer a squad that counters it must be before it takes that fight.
const COUNTER_PULL := 140.0
## An advancing squad only switches targets for one this much more attractive.
const RETARGET_MARGIN := 80.0
## Advancing squads keep to marching pace, so the army arrives together, until their
## target is this close; then they charge at full speed.
const MARCH_SPEED := 38.0
const CHARGE_DISTANCE := 180.0
const ARROW_SPEED := 420.0
const MAX_CORPSES := 500
## Crowding and nearby-enemy lookups use a grid of CELL-sized squares over the field.
## A cell must be wider than the closest two men can stand, so neighbors are always in
## the same or an adjacent cell.
const CELL := 32.0
const GRID_W := int(ARENA.x / CELL) + 1
const GRID_H := int(ARENA.y / CELL) + 1


class Soldier:
	var squad = null
	var radius := 7.0
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
	# For the screen only: distance walked (drives the walk cycle) and time left on the
	# strike pose.
	var stride := 0.0
	var swing := 0.0


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
	# Copied from the troop stats at spawn, since the hot loops read them every tick.
	var radius := 7.0
	var speed := 40.0
	var reach := 14.0
	var ranged := false
	var cooldown := 1.0
	var damage := 10.0
	var bonus := {}
	## Arrows left for the whole squad; -1 for troops that don't shoot.
	var arrows := -1
	# Kept up to date as men fall, and refreshed once a tick, because nearly every
	# decision in the battle asks for them.
	var alive_n := 0
	var avg := Vector2.ZERO
	var extent := 0.0

	func alive_count() -> int:
		return alive_n

	func is_active() -> bool:
		return not routing and alive_n > 0

	## Where the squad's living men are on average, as of the start of this tick.
	func average_pos() -> Vector2:
		return avg

	func refresh() -> void:
		var sum := Vector2.ZERO
		var n := 0
		for s in soldiers:
			if s.alive:
				sum += s.pos
				n += 1
		avg = center if n == 0 else sum / n
		var far := 0.0
		for s in soldiers:
			if s.alive:
				far = maxf(far, avg.distance_squared_to(s.pos))
		extent = sqrt(far)


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
var _cells: Array = []
var _used_cells: Array = []


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
	var front := 120.0
	var back := _add_rows(spots, line, front, Vector2(110.0, ARENA.x - 110.0))
	back = _add_rows(spots, by_type[Troops.ARCHERS], back + 24.0, Vector2(200.0, ARENA.x - 200.0))
	for i in mini(2, cav.size()):
		spots.append([cav[i], front + 110.0, 100.0 if i == 0 else ARENA.x - 100.0])
	_add_rows(spots, cav.slice(2), back + 24.0, Vector2(300.0, ARENA.x - 300.0))
	for s in spots:
		var depth: float = s[1]
		var x: float = s[2]
		if jitter > 0.0:
			depth += rng.randf_range(-jitter, jitter) * 0.6
			x += rng.randf_range(-jitter, jitter)
		place(team, s[0]["roster_id"], Vector2(x, MID_Y + depth if team == PLAYER else MID_Y - depth))


## Lay squads out in rows across `span` (min x, max x), the first row's front edge
## `front` units behind the midline. Returns how far back the last row reaches.
func _add_rows(spots: Array, entries: Array, front: float, span: Vector2) -> float:
	if entries.is_empty():
		return front
	var widest := 0.0
	var deepest := 0.0
	for e in entries:
		var half := _footprint(e["type"], e["men"])
		widest = maxf(widest, half.x * 2.0)
		deepest = maxf(deepest, half.y * 2.0)
	var step := widest + SQUAD_GAP + 8.0
	var per_row := maxi(1, int((span.y - span.x) / step) + 1)
	var rows := int(ceil(float(entries.size()) / per_row))
	var per := int(ceil(float(entries.size()) / rows))
	var mid := (span.x + span.y) * 0.5
	var depth := front + deepest * 0.5
	var i := 0
	while i < entries.size():
		var count := mini(per, entries.size() - i)
		for k in count:
			spots.append([entries[i + k], depth, mid + (k - (count - 1) * 0.5) * step])
		i += count
		if i < entries.size():
			depth += deepest + SQUAD_GAP + 8.0
	return depth + deepest * 0.5


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
	sq.radius = float(sq.stats["radius"])
	sq.speed = float(sq.stats["speed"])
	sq.ranged = bool(sq.stats["ranged"])
	sq.reach = float(sq.stats["range"]) if sq.ranged else float(sq.stats["reach"])
	sq.cooldown = float(sq.stats["cooldown"])
	sq.damage = float(sq.stats["damage"]) * sq.power
	sq.bonus = sq.stats["bonus"]
	sq.facing = Vector2.UP if team == PLAYER else Vector2.DOWN
	var men: int = entry["men"]
	sq.start_men = men
	sq.alive_n = men
	if sq.ranged:
		sq.arrows = men * int(sq.stats["arrows"])
	var slots := _formation_slots(men, sq.radius * 2.0 + 5.0)
	for i in men:
		var so := Soldier.new()
		so.squad = sq
		so.radius = sq.radius
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
	sq.refresh()


## Squads stand three ranks deep, four to eight men wide.
func _files(men: int) -> int:
	return mini(maxi(1, men), clampi(int(ceil(men / 3.0)), 4, 8))


func _formation_slots(men: int, spacing: float) -> Array:
	var cols := _files(men)
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
	var cols := _files(men)
	var rows := int(ceil(float(maxi(1, men)) / cols))
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
	for ring in range(1, 16):
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
		if sq.team != team or sq.alive_n == 0:
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
	for sq in squads:
		sq.refresh()
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


func _update_squad(sq, dt: float) -> void:
	if sq.alive_n == 0:
		return
	var avg: Vector2 = sq.avg
	if not sq.routing and sq.morale <= ROUT_MORALE:
		sq.routing = true
		sq.focus = null
		events.append({"type": "rout", "squad": sq})
	if sq.routing:
		return
	if sq.order == "attack" and (sq.order_target == null or not sq.order_target.is_active()):
		order_advance(sq)

	var reach: float = sq.reach
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
		sq.goal = foe.avg
		chasing = true
	else:
		sq.goal = sq.center

	# Engaged squads break formation and fight man to man.
	sq.engaged = false
	if foe != null:
		var slack := 20.0 if sq.ranged else ENGAGE_RANGE
		sq.engaged = _in_range(sq, foe, reach + slack)
	if sq.engaged:
		sq.center = sq.center.lerp(avg, 0.15)
		return

	var to: Vector2 = sq.goal - sq.center
	var stop := reach * 0.85 if chasing and sq.ranged else 0.0 # archers halt at bow range
	var dist := to.length()
	if dist > stop + 2.0:
		var dir := to / dist
		var pace: float = sq.speed
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
		if threat != null and threat.avg.distance_to(sq.center) > 1.0:
			want = (threat.avg - sq.center).normalized()
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
	var score: float = from.distance_to(foe.avg)
	# Archers with no arrows left have lost what made them dangerous to infantry.
	var armed: bool = sq.ranged or not sq.stats["ranged"]
	if Troops.COUNTERED_BY[foe.type] == sq.type and armed:
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


## True if some man of `a` is within `limit` (the gap between bodies) of some man of `b`.
func _in_range(a, b, limit: float) -> bool:
	var lim: float = limit + a.radius + b.radius
	if a.avg.distance_to(b.avg) - a.extent - b.extent > lim:
		return false
	var lim2 := lim * lim
	for s in a.soldiers:
		if not s.alive:
			continue
		for o in b.soldiers:
			if o.alive and s.pos.distance_squared_to(o.pos) <= lim2:
				return true
	return false


func _update_soldier(so, sq, dt: float) -> void:
	so.cooldown = maxf(0.0, so.cooldown - dt)
	so.flash = maxf(0.0, so.flash - dt * 5.0)
	so.swing = maxf(0.0, so.swing - dt)
	so.runup = maxf(0.0, so.runup - 30.0 * dt)
	var speed: float = sq.speed

	if sq.routing:
		var exit_y := ARENA.y + 40.0 if sq.team == PLAYER else -40.0
		_walk(so, Vector2(so.pos.x, exit_y), speed * ROUT_SPEED, dt)
		if (sq.team == PLAYER and so.pos.y >= ARENA.y + 20.0) or (sq.team == ENEMY and so.pos.y <= -20.0):
			_remove(so)
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
	var gap: float = so.pos.distance_to(tpos) - so.target.radius - so.radius
	if tpos != so.pos:
		so.facing = (tpos - so.pos).normalized()
	var reach: float = sq.reach
	if gap > reach:
		var moved := _walk(so, tpos, speed, dt)
		if gap > reach + 20.0:
			so.runup += moved # only a real run-up counts toward a charge, not shuffling in the melee
	elif so.cooldown <= 0.0:
		_strike(so, sq, so.target, gap)
		so.swing = 0.3
		so.cooldown = sq.cooldown * rng.randf_range(0.85, 1.15)
		so.runup = 0.0


func _walk(so, dest: Vector2, speed: float, dt: float) -> float:
	var before: Vector2 = so.pos
	so.pos = before.move_toward(dest, speed * dt)
	var moved := before.distance_to(so.pos)
	so.stride += moved
	return moved


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
	var dmg: float = sq.damage * rng.randf_range(0.8, 1.2)
	var target_type: String = target.squad.type
	dmg *= float(sq.bonus.get(target_type, 1.0))
	var charge := false
	if sq.type == Troops.CAVALRY and so.runup >= Troops.CHARGE_RUNUP and target_type != Troops.SPEARMEN:
		dmg *= Troops.CHARGE_MULTIPLIER
		charge = true
	if sq.ranged:
		if gap < 30.0:
			dmg *= Troops.POINT_BLANK
		_shoot(so, sq, target, dmg)
		sq.arrows -= 1
		if sq.arrows <= 0:
			_draw_blades(sq)
	else:
		_damage(target, dmg, sq, charge)
		if charge:
			events.append({"type": "charge", "pos": target.pos})


## Out of arrows: the squad fights on with short blades, as weak foot soldiers.
func _draw_blades(sq) -> void:
	sq.arrows = 0
	sq.ranged = false
	sq.reach = float(Troops.SIDEARM["reach"])
	sq.damage = float(Troops.SIDEARM["damage"]) * sq.power
	sq.cooldown = float(Troops.SIDEARM["cooldown"])
	sq.bonus = {}
	events.append({"type": "out_of_arrows", "squad": sq})


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
				var friends: int = p.source.team if p.source != null else -1
				if friends != -1 and _fighters_near(p.target.pos, friends, 40.0) and rng.randf() < Troops.MELEE_MISS:
					continue # shot wide to spare their own men in the press
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
		vs.morale -= CHARGE_SHOCK / float(vs.start_men)
	if victim.hp <= 0.0:
		_remove(victim)
		vs.morale -= 100.0 / float(vs.start_men) * 0.8 + 2.0
		if attacker != null:
			attacker.kills += 1
		corpses.append({"pos": victim.pos, "team": vs.team, "type": vs.type})
		if corpses.size() > MAX_CORPSES:
			corpses.pop_front()


func _remove(so) -> void:
	if so.alive:
		so.alive = false
		so.squad.alive_n -= 1


# ---------------------------------------------------------------- crowding

func _cell_of(p: Vector2) -> int:
	return clampi(floori(p.x / CELL), 0, GRID_W - 1) + clampi(floori(p.y / CELL), 0, GRID_H - 1) * GRID_W


## Sort living men into grid cells. Men off the field (routers leaving) count in the edge cells.
func _build_grid() -> void:
	if _cells.is_empty():
		_cells.resize(GRID_W * GRID_H)
		for i in _cells.size():
			_cells[i] = []
	for c in _used_cells:
		_cells[c].clear()
	_used_cells.clear()
	for sq in squads:
		for so in sq.soldiers:
			if so.alive:
				var c := _cell_of(so.pos)
				var cell: Array = _cells[c]
				if cell.is_empty():
					_used_cells.append(c)
				cell.append(so)


func _nearby(pos: Vector2, radius: float) -> Array:
	var out := []
	var x0 := clampi(floori((pos.x - radius) / CELL), 0, GRID_W - 1)
	var x1 := clampi(floori((pos.x + radius) / CELL), 0, GRID_W - 1)
	var y0 := clampi(floori((pos.y - radius) / CELL), 0, GRID_H - 1)
	var y1 := clampi(floori((pos.y + radius) / CELL), 0, GRID_H - 1)
	var r2 := radius * radius
	for cy in range(y0, y1 + 1):
		for cx in range(x0, x1 + 1):
			for so in _cells[cx + cy * GRID_W]:
				if so.alive and pos.distance_squared_to(so.pos) <= r2:
					out.append(so)
	return out


## True if a living foot or horse soldier (not an archer) of `team` stands within
## `radius` of `pos`: someone an arrow aimed there could hit by mistake.
func _fighters_near(pos: Vector2, team: int, radius: float) -> bool:
	var x0 := clampi(floori((pos.x - radius) / CELL), 0, GRID_W - 1)
	var x1 := clampi(floori((pos.x + radius) / CELL), 0, GRID_W - 1)
	var y0 := clampi(floori((pos.y - radius) / CELL), 0, GRID_H - 1)
	var y1 := clampi(floori((pos.y + radius) / CELL), 0, GRID_H - 1)
	var r2 := radius * radius
	for cy in range(y0, y1 + 1):
		for cx in range(x0, x1 + 1):
			for so in _cells[cx + cy * GRID_W]:
				if so.alive and so.squad.team == team and not so.squad.ranged and pos.distance_squared_to(so.pos) <= r2:
					return true
	return false


## Push overlapping men apart. Each touching pair is found exactly once (within a cell,
## and between a cell and the four cells after it) and both men move half the overlap.
## Pushes are summed first and applied together, so the result doesn't depend on who
## happens to be processed first and neither side is quietly favored.
func _separate() -> void:
	_build_grid() # where everyone stands after this tick's moves
	for c in _used_cells:
		var cell: Array = _cells[c]
		var cx: int = c % GRID_W
		var cy: int = int(c / GRID_W)
		var later: Array = []
		if cx + 1 < GRID_W:
			later.append_array(_cells[c + 1])
		if cy + 1 < GRID_H:
			var below: int = c + GRID_W
			if cx > 0:
				later.append_array(_cells[below - 1])
			later.append_array(_cells[below])
			if cx + 1 < GRID_W:
				later.append_array(_cells[below + 1])
		var n := cell.size()
		for i in n:
			var a = cell[i]
			var ap: Vector2 = a.pos
			var ar: float = a.radius - 1.0
			for j in range(i + 1, n):
				var b = cell[j]
				var diff: Vector2 = ap - b.pos
				var min_d: float = ar + b.radius
				var d2 := diff.length_squared()
				if d2 < min_d * min_d:
					var push := _push_for(diff, d2, min_d)
					a.push += push
					b.push -= push
			for b in later:
				var diff: Vector2 = ap - b.pos
				var min_d: float = ar + b.radius
				var d2 := diff.length_squared()
				if d2 < min_d * min_d:
					var push := _push_for(diff, d2, min_d)
					a.push += push
					b.push -= push
	for sq in squads:
		for so in sq.soldiers:
			if not so.alive:
				continue
			so.pos += so.push.limit_length(4.0)
			so.push = Vector2.ZERO
			if not sq.routing:
				so.pos = Vector2(clampf(so.pos.x, 8.0, ARENA.x - 8.0), clampf(so.pos.y, 8.0, ARENA.y - 8.0))


## Half of the overlap between two men `diff` apart who should be `min_d` apart.
func _push_for(diff: Vector2, d2: float, min_d: float) -> Vector2:
	var d := sqrt(d2)
	if d < 0.01:
		diff = Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
		d = maxf(diff.length(), 0.01)
	return diff / d * (min_d - d) * 0.5


# ---------------------------------------------------------------- queries

func nearest_enemy_squad(team: int, from: Vector2, max_dist: float):
	var best = null
	var best_d := max_dist
	for sq in squads:
		if sq.team == team or not sq.is_active():
			continue
		var d: float = from.distance_to(sq.avg)
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
			n += sq.alive_n
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
		alive[sq.team] += sq.alive_n
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
		var survivors: int = sq.alive_n + sq.escaped
		by_id[sq.roster_id] = {"men": survivors, "kills": sq.kills}
		lost += sq.start_men - survivors
		killed += sq.kills
	return {"won": winner == team, "reason": end_reason, "squads": by_id, "lost": lost, "killed": killed, "time": time}
