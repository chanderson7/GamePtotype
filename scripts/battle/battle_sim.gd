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
const Captains = preload("res://scripts/data/captains.gd")

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
## Spent arrows left sticking out of the ground, for the screen.
const MAX_STUCK_ARROWS := 240
## Which side of a squad a blow lands on, by its facing. A squad can't be flanked by the
## squad it's already fighting, only by someone else coming from beside or behind.
const FRONT := 0
const FLANK := 1
const REAR := 2
const FLANK_DOT := 0.3
const REAR_DOT := -0.35
const FLANK_POWER := 1.15
const REAR_POWER := 1.4
## Morale a squad loses in all if every one of its men takes a blow from behind.
const REAR_SHOCK := 6.0
## A squad on Hold that has stood still this long is braced: for its first seconds of
## melee it hits harder, so a line that waits wins the first clash.
const BRACE_SET := 2.0
const BRACE_SECONDS := 6.0
const BRACE_POWER := 1.35
## Room kept between a marching squad and an enemy squad it goes around.
const STEER_MARGIN := 55.0
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
	## Set by a volley: his next arrow goes at the volley's target, harder.
	var volley := false
	## The squad's named captain: hardier, hits harder, and the squad's nerve rests on him.
	var captain := false
	var might := 1.0


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
	# Captain: the soldier leading the squad (null if none or fallen), his record from
	# the warband, and what happened to him.
	var captain = null
	var info := {}
	## Morale lost per man killed is scaled by this: steadier under a captain, worse
	## once he's gone.
	var led := 1.0
	var captain_fate := ""
	var death_roll := 0
	var death_needed := 0
	var captain_kills := 0
	var last_words := ""
	## Seconds of fury left after a bonded friend fell (Vengeful captains).
	var fury := 0.0
	## From bonded captains fighting close by: morale regained a second, extra damage.
	var bond_regen := 0.0
	var bond_power := 0.0
	## Seconds stood still on Hold (braced at BRACE_SET), and seconds of braced fighting left.
	var still := 0.0
	var brace := 0.0
	var engaged_for := 0.0
	## Seconds since an arrow last hit one of its men, counting down from 2.
	var under_fire := 0.0
	var flanked_at := -99.0
	# The squad's ability: seconds until it can be used again and seconds it still runs.
	var ability_cd := 0.0
	var ability_left := 0.0
	var volley_target = null
	var volley_left := 0.0
	var wheeling := false
	var wheel_point := Vector2.ZERO
	var wheel_target = null

	func alive_count() -> int:
		return alive_n

	func is_active() -> bool:
		return not routing and alive_n > 0

	func braced() -> bool:
		return order == "hold" and still >= BRACE_SET and not engaged

	func shield_wall() -> bool:
		return type == Troops.INFANTRY and ability_left > 0.0

	func schiltron() -> bool:
		return type == Troops.SPEARMEN and ability_left > 0.0

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
	var origin := Vector2.ZERO
	var target = null
	var aim := Vector2.ZERO
	var damage := 0.0
	var source = null
	var shooter = null
	var volley := false
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
## Arrows that missed and stuck in the ground: {pos, angle}. Only the screen reads these.
var stuck_arrows: Array = []
var events: Array = []
## Commanders that give orders for a side once the battle starts. null means a human
## plays that side.
var ai: Array = [null, null]
var winner := -1
var end_reason := ""
## Seconds each pair of captains (key "id|id") spent fighting side by side.
var bond_time := {}
var _ranks := {}
var _bond_clock := 0.0
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
		# A wounded captain sits the battle out; his squad fights without him.
		var captain = entry.get("captain")
		if typeof(captain) != TYPE_DICTIONARY or int(captain.get("wounded", 0)) > 0:
			captain = null
		out.append({
			"roster_id": id,
			"type": String(entry["type"]),
			"men": men,
			"level": int(entry.get("level", Troops.level_for(int(entry.get("xp", 0))))),
			"name": String(entry.get("name", "")),
			"captain": captain,
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
## bows behind them, horse on the wings. `jitter` shifts squads sideways a little. It
## never staggers the line front to back: a ragged line meets the enemy a squad at a time.
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
	# Bond ranks between captains on the same side, from the points they've built up.
	for a in squads:
		for b in squads:
			if a.team == b.team and a != b and not a.info.is_empty() and not b.info.is_empty():
				var points := float(a.info.get("bonds", {}).get(str(b.info["id"]), 0.0))
				_ranks[_bond_key(a, b)] = Captains.rank_for(points)
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
	var captain = entry.get("captain")
	if typeof(captain) == TYPE_DICTIONARY:
		# The captain stands at the heart of the squad, with men on every side.
		var lead = sq.soldiers[0]
		for so in sq.soldiers:
			if so.slot.length_squared() < lead.slot.length_squared() - 0.01:
				lead = so
		lead.captain = true
		lead.might = Captains.DAMAGE_MULT
		lead.max_hp *= Captains.HP_MULT
		lead.hp = lead.max_hp
		sq.captain = lead
		sq.info = captain
		sq.led = Captains.LED_BOLD if captain.get("quirk", "") == Captains.BOLD else Captains.LED
	_move_formation(sq, at)
	squads.append(sq)
	return sq


func _move_formation(sq, at: Vector2) -> void:
	sq.center = at
	sq.goal = at
	sq.order = "hold"
	sq.order_point = at
	for so in sq.soldiers:
		so.pos = at + _slot_world(so.slot, sq.facing, sq.team)
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


## Slot offsets are in squad space: x to the right, y toward the rear. The two armies
## face each other across the field as mirror images, so the enemy's formations are
## mirrored too, not turned around: man for man, both sides stand the same way. Turned
## formations broke ties (two enemies equally close) toward each army's own right, which
## added up to a lean that favored one side.
func _slot_world(slot: Vector2, facing: Vector2, team: int) -> Vector2:
	var right := Vector2(-facing.y, facing.x) if team == PLAYER else Vector2(facing.y, -facing.x)
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

## Stand where you are and fight anyone who comes close. A schiltron keeps its ring.
func order_hold(sq) -> void:
	if sq == null or not sq.is_active():
		return
	sq.wheeling = false
	if sq.order != "hold":
		sq.still = 0.0
	sq.order = "hold"
	sq.order_point = _clamp_to_arena(sq.center)
	sq.order_target = null


## Go after the enemy: each squad picks the enemy squad it fights best (see best_target)
## and keeps fighting until none are left.
func order_advance(sq) -> void:
	if sq == null or not sq.is_active():
		return
	_break_off(sq)
	sq.order = "advance"
	sq.order_target = null


## March to a point, going around enemy squads on the way, then hold there.
func order_move(sq, point: Vector2) -> void:
	if sq == null or not sq.is_active():
		return
	_break_off(sq)
	sq.order = "move"
	sq.order_point = _clamp_to_arena(point)
	sq.order_target = null


func order_attack(sq, foe) -> void:
	if sq == null or not sq.is_active() or foe == null or not foe.is_active():
		return
	_break_off(sq)
	sq.order = "attack"
	sq.order_target = foe


## Any order to move ends a wheel and breaks a schiltron.
func _break_off(sq) -> void:
	sq.wheeling = false
	if sq.schiltron():
		sq.ability_left = 0.0


## True if the squad's ability can be used now: it's off cooldown, the squad is still
## fighting, and (for a volley) it has arrows and an enemy in bow range.
func ability_ready(sq) -> bool:
	if sq == null or not sq.is_active() or phase != PHASE_BATTLE or winner != -1:
		return false
	if sq.ability_cd > 0.0 or sq.ability_left > 0.0 or sq.wheeling:
		return false
	if sq.type == Troops.ARCHERS:
		return _volley_target(sq, null) != null
	return true


## Use the squad's ability. `target` is the enemy squad a volley should hit; without
## one it shoots at what it's already shooting at, or the nearest squad in range.
## Returns true if it went off.
func use_ability(sq, target = null) -> bool:
	if not ability_ready(sq):
		return false
	var ab := Troops.ability(sq.type)
	match sq.type:
		Troops.ARCHERS:
			var foe = _volley_target(sq, target)
			sq.volley_target = foe
			sq.volley_left = 1.5
			for so in sq.soldiers:
				if so.alive:
					so.volley = true
					so.target = null
					so.cooldown = rng.randf_range(0.0, 0.3)
		Troops.CAVALRY:
			_start_wheel(sq)
		Troops.SPEARMEN:
			sq.ability_left = float(ab["seconds"])
			sq.wheeling = false
			if sq.order != "hold":
				order_hold(sq)
		_:
			sq.ability_left = float(ab["seconds"])
	sq.ability_cd = float(ab["cooldown"])
	events.append({"type": "ability", "squad": sq, "name": String(ab["name"])})
	return true


func _volley_target(sq, wanted):
	if not sq.ranged or sq.arrows <= 0:
		return null
	for foe in [wanted, sq.focus]:
		if foe != null and foe.team != sq.team and foe.is_active() and _in_range(sq, foe, sq.reach):
			return foe
	var best = null
	var best_d := INF
	for foe in squads:
		if foe.team == sq.team or not foe.is_active():
			continue
		var d: float = sq.avg.distance_to(foe.avg)
		if d < best_d and _in_range(sq, foe, sq.reach):
			best_d = d
			best = foe
	return best


## Cavalry break off from whoever they're fighting, ride clear, then charge them again.
func _start_wheel(sq) -> void:
	var from = sq.focus
	if from == null or not from.is_active():
		from = nearest_enemy_squad(sq.team, sq.avg, INF)
	var away := Vector2.DOWN if sq.team == PLAYER else Vector2.UP
	if from != null and from.avg.distance_to(sq.avg) > 1.0:
		away = (sq.avg - from.avg).normalized()
	var to: Vector2 = sq.avg + away * Troops.WHEEL_DISTANCE
	sq.wheel_point = Vector2(clampf(to.x, 40.0, ARENA.x - 40.0), clampf(to.y, 40.0, ARENA.y - 40.0))
	sq.wheel_target = from
	sq.wheeling = true
	sq.engaged = false
	for so in sq.soldiers:
		so.target = null


func _end_wheel(sq) -> void:
	sq.wheeling = false
	var foe = sq.wheel_target
	sq.wheel_target = null
	if foe != null and foe.is_active():
		order_attack(sq, foe)
	else:
		order_advance(sq)


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
	_update_bonds(dt)
	_check_end()


func _bond_key(a, b) -> String:
	var x := int(a.info["id"])
	var y := int(b.info["id"])
	return "%d|%d" % [mini(x, y), maxi(x, y)]


## Captains fighting near each other build their bond, and bonded pairs lift each other.
func _update_bonds(dt: float) -> void:
	_bond_clock += dt
	if _bond_clock < 0.5:
		return
	var span := _bond_clock
	_bond_clock = 0.0
	for sq in squads:
		sq.bond_regen = 0.0
		sq.bond_power = 0.0
	for i in squads.size():
		var a = squads[i]
		if a.captain == null or not a.is_active():
			continue
		for j in range(i + 1, squads.size()):
			var b = squads[j]
			if b.team != a.team or b.captain == null or not b.is_active():
				continue
			if a.avg.distance_to(b.avg) > Captains.BOND_RANGE:
				continue
			var key := _bond_key(a, b)
			if a.engaged or b.engaged:
				bond_time[key] = float(bond_time.get(key, 0.0)) + span
			var rank: int = _ranks.get(key, 0)
			if rank > 0:
				for sq in [a, b]:
					sq.bond_regen = maxf(sq.bond_regen, Captains.RANK_REGEN[rank])
					sq.bond_power = maxf(sq.bond_power, Captains.RANK_POWER[rank])


func _update_squad(sq, dt: float) -> void:
	if sq.alive_n == 0:
		return
	var avg: Vector2 = sq.avg
	sq.ability_cd = maxf(0.0, sq.ability_cd - dt)
	sq.ability_left = maxf(0.0, sq.ability_left - dt)
	sq.under_fire = maxf(0.0, sq.under_fire - dt)
	sq.volley_left = maxf(0.0, sq.volley_left - dt)
	if sq.fury > 0.0:
		sq.fury = maxf(0.0, sq.fury - dt)
		sq.morale = maxf(sq.morale, Captains.FURY_MORALE_FLOOR)
	if not sq.routing and sq.bond_regen > 0.0:
		sq.morale = minf(100.0, sq.morale + sq.bond_regen * dt)
	if not sq.routing and sq.morale <= ROUT_MORALE:
		sq.routing = true
		sq.focus = null
		sq.wheeling = false
		sq.ability_left = 0.0
		events.append({"type": "rout", "squad": sq})
	if sq.routing:
		return
	if sq.order == "attack" and (sq.order_target == null or not sq.order_target.is_active()):
		order_advance(sq)

	var reach: float = sq.reach
	var foe = null
	if sq.wheeling:
		foe = null # riding clear, not fighting
	elif sq.volley_left > 0.0 and sq.volley_target != null and sq.volley_target.is_active():
		foe = sq.volley_target
	else:
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
	if sq.wheeling:
		sq.goal = sq.wheel_point
		if sq.center.distance_to(sq.wheel_point) < 10.0:
			_end_wheel(sq)
	elif sq.order == "move":
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

	# Engaged squads break formation and fight man to man. A braced line that the enemy
	# reaches gets the first few seconds of the fight on its side.
	var was_engaged: bool = sq.engaged
	sq.engaged = false
	if foe != null:
		var slack := 20.0 if sq.ranged else ENGAGE_RANGE
		sq.engaged = _in_range(sq, foe, reach + slack)
	if sq.engaged:
		if not was_engaged:
			sq.brace = BRACE_SECONDS if sq.order == "hold" and sq.still >= BRACE_SET and not sq.ranged else 0.0
			if sq.brace > 0.0:
				events.append({"type": "braced", "squad": sq})
		sq.brace = maxf(0.0, sq.brace - dt)
		sq.engaged_for += dt
		sq.still = 0.0
		sq.center = sq.center.lerp(avg, 0.15)
		return
	sq.engaged_for = 0.0
	sq.brace = 0.0

	var to: Vector2 = Vector2.ZERO if sq.schiltron() else sq.goal - sq.center
	var stop := reach * 0.85 if chasing and sq.ranged else 0.0 # archers halt at bow range
	var dist := to.length()
	if dist > stop + 2.0:
		var dir := _steer(sq, to / dist, dist, foe)
		var pace := _pace(sq)
		if sq.order == "advance" and not sq.wheeling and dist - stop > CHARGE_DISTANCE:
			pace = minf(pace, MARCH_SPEED)
		sq.center += dir * minf(dist - stop, pace * dt)
		sq.facing = dir
		sq.still = 0.0
	else:
		if sq.order == "hold":
			sq.still += dt
		# Standing still: turn to meet an enemy squad that comes close, otherwise face
		# the enemy's end of the field (so a squad that walked back to its post doesn't
		# stand there facing its own lines).
		var want := Vector2.UP if sq.team == PLAYER else Vector2.DOWN
		var threat = nearest_enemy_squad(sq.team, avg, FACE_RANGE)
		if threat != null and threat.avg.distance_to(sq.center) > 1.0:
			want = (threat.avg - sq.center).normalized()
		if sq.facing.dot(want) < 0.995:
			sq.facing = sq.facing.slerp(want, minf(1.0, dt * 2.5)).normalized()


## Marching pace: a shield wall shuffles forward at half speed.
func _pace(sq) -> float:
	var pace: float = sq.speed
	if sq.shield_wall():
		pace *= Troops.SHIELD_WALL_SPEED
	return pace


## Where to head, given the straight way `dir` to a goal `dist` away: around the first
## enemy squad standing in the way, unless that squad is the one it's going for.
func _steer(sq, dir: Vector2, dist: float, foe) -> Vector2:
	var block = null
	var block_t := dist
	var lateral := 0.0
	for o in squads:
		if o.team == sq.team or o == foe or not o.is_active():
			continue
		var rel: Vector2 = o.avg - sq.center
		var t := rel.dot(dir)
		if t <= 0.0 or t >= block_t:
			continue
		var off := rel.cross(dir)
		if absf(off) < o.extent + sq.extent * 0.5 + STEER_MARGIN:
			block = o
			block_t = t
			lateral = off
	if block == null:
		return dir
	# Pass it on whichever side is nearer the straight line. When it stands dead ahead,
	# take the side with more open field, so both armies break the tie the same way.
	var side := Vector2(-dir.y, dir.x)
	if absf(lateral) < 4.0:
		if side.x * (ARENA.x * 0.5 - block.avg.x) < 0.0:
			side = -side
	elif lateral < 0.0:
		side = -side
	var waypoint: Vector2 = _clamp_to_arena(block.avg + side * (block.extent + sq.extent + STEER_MARGIN))
	var to: Vector2 = waypoint - sq.center
	return dir if to.length_squared() < 1.0 else to.normalized()


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
	var speed := _pace(sq)

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
		so.runup += _walk(so, sq.center + _slot_world(so.slot, sq.facing, sq.team), speed * 1.25, dt)
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
	var boost: float = 1.0 + sq.bond_power + (Captains.FURY_POWER if sq.fury > 0.0 else 0.0)
	if sq.brace > 0.0:
		boost += BRACE_POWER - 1.0
	var dmg: float = sq.damage * so.might * boost * rng.randf_range(0.8, 1.2)
	var target_type: String = target.squad.type
	dmg *= float(sq.bonus.get(target_type, 1.0))
	if sq.ranged:
		if gap < 30.0:
			dmg *= Troops.POINT_BLANK
		var volley: bool = so.volley and sq.volley_left > 0.0
		so.volley = false
		if volley:
			dmg *= Troops.VOLLEY_POWER
		_shoot(so, sq, target, dmg, volley)
		sq.arrows -= 1
		if sq.arrows <= 0:
			_draw_blades(sq)
		return
	# Spears stop a charge unless it takes them from behind while they're pinned.
	var side := _side_of(target, so.pos, sq)
	var charge := false
	if sq.type == Troops.CAVALRY and so.runup >= Troops.CHARGE_RUNUP and (target_type != Troops.SPEARMEN or side == REAR):
		dmg *= Troops.CHARGE_MULTIPLIER
		charge = true
	if side == FLANK:
		dmg *= FLANK_POWER
	elif side == REAR:
		dmg *= REAR_POWER
	elif target.squad.shield_wall():
		dmg *= Troops.SHIELD_WALL_MELEE
	_damage(target, dmg, sq, charge, so, side)
	if charge:
		events.append({"type": "charge", "pos": target.pos, "squad": sq, "victim": target.squad})


## Which side of his squad a blow from `from` lands on. A squad that isn't pinned in a
## fight turns to meet whoever comes, so only a squad already fighting another can be
## caught in the flank or rear, and only by someone else. A schiltron has neither.
func _side_of(victim, from: Vector2, attacker) -> int:
	var vs = victim.squad
	if vs.schiltron() or not vs.engaged or attacker == vs.focus:
		return FRONT
	var to: Vector2 = from - victim.pos
	if to.length_squared() < 0.01:
		return FRONT
	var d: float = vs.facing.dot(to.normalized())
	if d < REAR_DOT:
		return REAR
	if d < FLANK_DOT:
		return FLANK
	return FRONT


## Out of arrows: the squad fights on with short blades, as weak foot soldiers.
func _draw_blades(sq) -> void:
	sq.arrows = 0
	sq.ranged = false
	sq.reach = float(Troops.SIDEARM["reach"])
	sq.damage = float(Troops.SIDEARM["damage"]) * sq.power
	sq.cooldown = float(Troops.SIDEARM["cooldown"])
	sq.bonus = {}
	events.append({"type": "out_of_arrows", "squad": sq})


func _shoot(so, sq, target, dmg: float, volley: bool = false) -> void:
	var p := Projectile.new()
	p.pos = so.pos
	p.origin = so.pos
	p.target = target
	p.aim = target.pos
	p.damage = dmg
	p.source = sq
	p.shooter = so
	p.volley = volley
	projectiles.append(p)


func _update_projectiles(dt: float) -> void:
	var travel := ARROW_SPEED * dt
	for p in projectiles:
		if p.target != null and p.target.alive:
			p.aim = p.target.pos
		var to: Vector2 = p.aim - p.pos
		if to.length() <= travel:
			p.done = true
			if p.target == null or not p.target.alive:
				_stick(p, p.aim)
				continue
			var friends: int = p.source.team if p.source != null else -1
			if friends != -1 and _fighters_near(p.target.pos, friends, 40.0) and rng.randf() < Troops.MELEE_MISS:
				# shot wide to spare their own men in the press
				_stick(p, p.target.pos + Vector2(rng.randf_range(-14.0, 14.0), rng.randf_range(-14.0, 14.0)))
				continue
			var vs = p.target.squad
			var dmg: float = p.damage
			if vs.shield_wall() and vs.facing.dot((p.origin - p.target.pos).normalized()) > FLANK_DOT:
				dmg *= Troops.SHIELD_WALL_ARROWS
			vs.under_fire = 2.0
			if p.volley:
				vs.morale -= Troops.VOLLEY_SHOCK / float(vs.start_men)
			_damage(p.target, dmg, p.source, false, p.shooter)
		else:
			p.pos += to.normalized() * travel
	projectiles = projectiles.filter(func(p): return not p.done)


func _stick(p, at: Vector2) -> void:
	stuck_arrows.append({"pos": at, "angle": (p.aim - p.origin).angle()})
	if stuck_arrows.size() > MAX_STUCK_ARROWS:
		stuck_arrows.pop_front()


func _damage(victim, dmg: float, attacker, charge: bool = false, killer = null, side: int = FRONT) -> void:
	if not victim.alive:
		return
	victim.hp -= dmg
	victim.flash = 1.0
	var vs = victim.squad
	if charge:
		vs.morale -= CHARGE_SHOCK / float(vs.start_men)
	if side != FRONT:
		vs.morale -= REAR_SHOCK / float(vs.start_men) * (1.0 if side == REAR else 0.5)
		if time - vs.flanked_at > 4.0:
			vs.flanked_at = time
			events.append({"type": "flanked", "squad": vs, "pos": victim.pos, "rear": side == REAR})
	if victim.hp <= 0.0:
		_remove(victim)
		vs.morale -= (100.0 / float(vs.start_men) * 0.8 + 2.0) * vs.led
		if attacker != null:
			attacker.kills += 1
			if killer != null and killer.captain and killer.alive:
				attacker.captain_kills += 1
		if victim.captain:
			_captain_falls(vs, victim)
		corpses.append({"pos": victim.pos, "team": vs.team, "type": vs.type})
		if corpses.size() > MAX_CORPSES:
			corpses.pop_front()


## A captain is down. Roll a d100 for his fate: at or under the death chance he's
## killed, over it he's carried off wounded. His squad reels, and captains bonded to him
## take it according to their temperament.
func _captain_falls(sq, victim) -> void:
	sq.captain = null
	sq.led = Captains.LEADERLESS
	sq.morale -= Captains.FALL_SHOCK
	var holding: bool = sq.alive_n >= sq.start_men * 0.5
	var friends := false
	for other in squads:
		if other != sq and other.team == sq.team and other.is_active() and other.avg.distance_to(victim.pos) < Captains.RESCUE_RANGE:
			friends = true
	var chance := Captains.death_chance(sq.info, holding, friends)
	var roll := rng.randi_range(1, 100)
	sq.death_roll = roll
	sq.death_needed = chance + 1
	sq.captain_fate = "killed" if roll <= chance else "wounded"
	var words: Array = Captains.LAST_WORDS if sq.captain_fate == "killed" else Captains.WOUNDED_WORDS
	sq.last_words = words[rng.randi_range(0, words.size() - 1)]
	events.append({"type": "captain_down", "squad": sq, "pos": victim.pos, "fate": sq.captain_fate,
		"roll": roll, "needed": chance + 1, "rescued": holding or friends,
		"holding": holding, "friends": friends, "lucky": sq.info.get("quirk", "") == Captains.LUCKY})
	for other in squads:
		if other.team != sq.team or other.captain == null or other.info.is_empty():
			continue
		if _ranks.get(_bond_key(sq, other), 0) <= 0:
			continue
		match String(other.info.get("temperament", "")):
			Captains.VENGEFUL:
				other.fury = Captains.FURY_SECONDS
			Captains.STEADFAST:
				other.morale = minf(100.0, other.morale + Captains.STEADY_MORALE)
			Captains.FRAGILE:
				other.morale -= Captains.SHAKEN_MORALE
		events.append({"type": "grief", "squad": other, "for": sq, "temperament": other.info.get("temperament", "")})


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
		sq.volley_target = null
		sq.wheel_target = null
		sq.captain = null
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
		if not sq.info.is_empty():
			by_id[sq.roster_id]["captain"] = {
				"id": int(sq.info["id"]),
				"fate": sq.captain_fate if sq.captain_fate != "" else "fine",
				"roll": sq.death_roll,
				"needed": sq.death_needed,
				"kills": sq.captain_kills,
				"words": sq.last_words,
			}
		lost += sq.start_men - survivors
		killed += sq.kills
	var bonds := {}
	for key in bond_time:
		for sq in squads:
			if sq.team == team and not sq.info.is_empty() and String(key).split("|").has(str(sq.info["id"])):
				bonds[key] = bond_time[key]
				break
	return {"won": winner == team, "reason": end_reason, "squads": by_id, "lost": lost, "killed": killed, "time": time, "bonds": bonds}
