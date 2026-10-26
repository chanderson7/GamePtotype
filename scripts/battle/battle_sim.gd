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
const Terrain = preload("res://scripts/battle/terrain.gd")
const TerrainRules = preload("res://scripts/data/terrain_rules.gd")
const BattleSite = preload("res://scripts/battle/battle_site.gd")
const Pathing = preload("res://scripts/battle/pathing.gd")
const Units = preload("res://scripts/data/units.gd")
const Cultures = preload("res://scripts/data/cultures.gd")

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

const OBJECTIVE_ROUT := "rout"
const OBJECTIVE_CHIEF := "chief"
const OBJECTIVE_AMBUSH := "ambush"
const OBJECTIVE_VILLAGE := "village"

const VILLAGE_ZONE_CENTER := Vector2(420.0, 630.0)
const VILLAGE_ZONE_RADIUS := 160.0
const VILLAGE_DURATION := 120.0
## Ambushed: men abreast in the marching column, how long a file of squads may run down
## the middle of the field, and how far apart the files march.
const AMBUSH_FILES := 2
const AMBUSH_COLUMN := 760.0
const AMBUSH_LANE_GAP := 90.0
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
	## Javelins left to throw before contact.
	var javelins := 0


class Squad:
	var id := 0
	var roster_id := -1
	var team := 0
	var type := ""
	var unit := ""
	var stats := {}
	var mechanics := {}
	var armor := 0.0
	var piercing := 0.0
	var level := 1
	var power := 1.0
	var is_bodyguard := false
	var is_chief := false
	var chief_name := ""
	var soldiers: Array = []
	var start_men := 0
	var center := Vector2.ZERO
	var facing := Vector2.UP
	var goal := Vector2.ZERO
	var order := "hold" # hold | advance | move | attack
	var order_point := Vector2.ZERO
	## The way the squad faces when it stands with no enemy close, set by a line the
	## player drew. Zero: toward the enemy's end of the field.
	var face := Vector2.ZERO
	## Men abreast, set by a line the player drew. Zero: the usual width for its size.
	var files := 0
	## Archers told to hold fire keep their arrows: they loose none, and fight anyone who
	## reaches them with their blades.
	var hold_fire := false
	## How much further its bows carry from where it stands at whoever it's shooting at.
	var range_mult := 1.0
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
	## Pathfinding waypoints around obstacles and across river fords.
	var waypoints: Array = []
	var path_timer := 0.0
	var last_path_goal := Vector2.INF
	## Horse only: whether it has a clear run at each enemy squad, by squad id, and when
	## that was last looked at.
	var clear_run := {}
	var clear_run_at := -INF

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

	func drop_morale(amount: float) -> void:
		if mechanics.get("steady", false):
			amount *= 0.8
		morale -= amount

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
	var kind := "arrow" # arrow | javelin
	var piercing := 0.0
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
## Objective of this battle: "rout", "chief", "ambush", or "village".
var objective := OBJECTIVE_ROUT
var chief_name := ""
var chief_killed := false
var chief_escaped := false
var chief_broken := false
## Scheduled reinforcements: [{team, entries, at_time, edge, spawned}].
var scheduled_reinforcements: Array = []
## Battlefield ground: hills, woods, river fords, and rocks.
var terrain: RefCounted = null
## Anything on the ground at all. On an open, level field the terrain rules all come to
## nothing, so the battle skips them.
var _rough := false
## A rise of the ground per unit of distance, as the slope TerrainRules works in.
const SLOPE_SCALE := TerrainRules.SLOPE_SAMPLE_DIST / TerrainRules.SLOPE_MAX_RISE
## Seconds each pair of captains (key "id|id") spent fighting side by side.
var bond_time := {}
var _ranks := {}
var _bond_clock := 0.0
var _next_id := 1
var _cells: Array = []
var _used_cells: Array = []


# ---------------------------------------------------------------- setup

## Armies are arrays of {id, type, men, xp}, the same shape GameState keeps.
## site_or_terrain can be a site Dictionary {type, seed, ...}, a Terrain object, or null.
func setup(player_army: Array, enemy_army: Array, seed_value: int = 0, site_or_terrain = null, obj: String = OBJECTIVE_ROUT) -> void:
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	objective = obj
	chief_killed = false
	chief_escaped = false
	chief_broken = false
	scheduled_reinforcements.clear()
	if site_or_terrain is Dictionary:
		terrain = BattleSite.generate(site_or_terrain)
	elif site_or_terrain != null:
		terrain = site_or_terrain
	elif terrain == null:
		terrain = Terrain.new()
	set_terrain(terrain)
	armies = [_to_entries(player_army), _to_entries(enemy_army)]
	reserves = [armies[PLAYER].duplicate(), armies[ENEMY].duplicate()]
	if objective == OBJECTIVE_CHIEF:
		_setup_chief()
	elif objective == OBJECTIVE_VILLAGE:
		_setup_village_waves()


func set_objective(obj: String, c_name: String = "") -> void:
	objective = obj
	if c_name != "":
		chief_name = c_name
	if objective == OBJECTIVE_CHIEF:
		_setup_chief()
	elif objective == OBJECTIVE_VILLAGE:
		_setup_village_waves()


func set_terrain(t: RefCounted) -> void:
	terrain = t
	terrain.bake()
	_rough = not terrain.flat


func _setup_chief() -> void:
	var found := false
	for e in armies[ENEMY]:
		if e.get("is_bodyguard", false) or e.get("is_chief", false):
			found = true
			if chief_name == "":
				chief_name = String(e.get("chief_name", "Bandit Chief"))
			break
	if not found and not armies[ENEMY].is_empty():
		var chief_entry: Dictionary = armies[ENEMY][0]
		chief_entry["is_bodyguard"] = true
		chief_entry["is_chief"] = true
		if chief_name == "":
			chief_name = "Rask the Red"
		chief_entry["chief_name"] = chief_name
		for r in reserves[ENEMY]:
			if r["roster_id"] == chief_entry["roster_id"]:
				r["is_bodyguard"] = true
				r["is_chief"] = true
				r["chief_name"] = chief_name


func _setup_village_waves() -> void:
	if not scheduled_reinforcements.is_empty():
		return
	if armies[ENEMY].size() >= 3:
		var total: int = armies[ENEMY].size()
		var wave2_count := 1
		var wave1_count := 1
		if total >= 5:
			wave1_count = 2
		var wave2_entries: Array = armies[ENEMY].slice(total - wave2_count)
		var wave1_entries: Array = armies[ENEMY].slice(total - wave2_count - wave1_count, total - wave2_count)
		var initial_entries: Array = armies[ENEMY].slice(0, total - wave2_count - wave1_count)
		armies[ENEMY] = initial_entries
		reserves[ENEMY] = initial_entries.duplicate()
		add_reinforcements(ENEMY, wave1_entries, 30.0, "north")
		add_reinforcements(ENEMY, wave2_entries, 60.0, "east")


func add_reinforcements(team: int, p_entries: Array, at_time: float, edge: String) -> void:
	var processed := _to_entries(p_entries)
	scheduled_reinforcements.append({
		"team": team,
		"entries": processed,
		"at_time": at_time,
		"edge": edge,
		"spawned": false,
	})


func _has_pending_reinforcements(team: int) -> bool:
	for r in scheduled_reinforcements:
		if not r.get("spawned", false) and int(r.get("team", -1)) == team:
			return true
	return false


func _spawn_reinforcements(team: int, p_entries: Array, edge: String) -> void:
	var n: int = p_entries.size()
	if n == 0:
		return
	var spacing := 65.0
	for i in n:
		var entry: Dictionary = p_entries[i]
		armies[team].append(entry)
		var offset := (float(i) - float(n - 1) * 0.5) * spacing
		var pos := Vector2.ZERO
		var face := Vector2.DOWN
		match edge:
			"north":
				pos = Vector2(clampf(ARENA.x * 0.5 + offset, 80.0, ARENA.x - 80.0), 60.0)
				face = Vector2.DOWN
			"south":
				pos = Vector2(clampf(ARENA.x * 0.5 + offset, 80.0, ARENA.x - 80.0), ARENA.y - 60.0)
				face = Vector2.UP
			"east":
				pos = Vector2(ARENA.x - 60.0, clampf(MID_Y + offset, 80.0, ARENA.y - 80.0))
				face = Vector2.LEFT
			"west":
				pos = Vector2(60.0, clampf(MID_Y + offset, 80.0, ARENA.y - 80.0))
				face = Vector2.RIGHT
			_:
				pos = Vector2(clampf(ARENA.x * 0.5 + offset, 80.0, ARENA.x - 80.0), 60.0)
				face = Vector2.DOWN
		if _rough and not terrain.passable(pos):
			pos = _passable_slot(Vector2(ARENA.x * 0.5, MID_Y), pos)
		var sq = _spawn(team, entry, pos)
		if sq != null:
			sq.facing = face
			if objective == OBJECTIVE_VILLAGE and team == ENEMY:
				sq.order = "move"
				sq.order_point = VILLAGE_ZONE_CENTER
			else:
				sq.order = "advance"
	events.append({"type": "reinforcements", "team": team, "edge": edge, "count": n})


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
		var unit_id := String(entry.get("unit", ""))
		if unit_id == "" and entry.has("type"):
			var cult: String = String(entry.get("culture", Cultures.VARDISH))
			unit_id = Units.recruit(cult, String(entry["type"]))
		var is_bodyguard: bool = bool(entry.get("is_bodyguard", false))
		var is_chief: bool = bool(entry.get("is_chief", false))
		var c_name: String = String(entry.get("chief_name", ""))
		out.append({
			"roster_id": id,
			"type": String(entry["type"]),
			"unit": unit_id,
			"men": men,
			"level": int(entry.get("level", Troops.level_for(int(entry.get("xp", 0))))),
			"name": String(entry.get("name", "")),
			"captain": captain,
			"is_bodyguard": is_bodyguard,
			"is_chief": is_chief,
			"chief_name": c_name,
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
	if phase != PHASE_DEPLOY or winner != -1 or not in_deploy_zone(team, at) or caught_on_march(team):
		return null
	var sq = placed_squad(team, roster_id)
	if sq != null:
		var to = _free_spot(team, at, _footprint(sq.type, sq.start_men, sq.files), sq)
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
	if objective == OBJECTIVE_AMBUSH:
		_auto_deploy_ambush(team, jitter)
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


## Ambushed: the player's warband stands in its marching column, with no time to form up
## until the fighting starts.
func caught_on_march(team: int) -> bool:
	return objective == OBJECTIVE_AMBUSH and team == PLAYER


func _auto_deploy_ambush(team: int, jitter: float = 0.0) -> void:
	if reserves[team].is_empty():
		return
	if team == PLAYER:
		# Caught on the march: the warband strung out along the road, two men abreast, in
		# as many files of squads as it takes to fit between the ambushers, nobody braced.
		var to_deploy: Array = reserves[team].duplicate()
		var n: int = to_deploy.size()
		var depths := []
		var total := 0.0
		for e in to_deploy:
			var depth: float = _footprint(e["type"], e["men"], AMBUSH_FILES).y * 2.0
			depths.append(depth)
			total += depth + SQUAD_GAP
		var lanes := clampi(int(ceil(total / AMBUSH_COLUMN)), 1, 3)
		var per_lane := int(ceil(float(n) / lanes))
		for lane in lanes:
			var first := lane * per_lane
			var last := mini(n, first + per_lane)
			var length := -SQUAD_GAP
			for i in range(first, last):
				length += depths[i] + SQUAD_GAP
			var x := ARENA.x * 0.5 + (float(lane) - float(lanes - 1) * 0.5) * AMBUSH_LANE_GAP
			if jitter > 0.0:
				x += rng.randf_range(-jitter, jitter)
			var y := MID_Y - length * 0.5
			for i in range(first, last):
				var e: Dictionary = to_deploy[i]
				var spot := Vector2(x, y + depths[i] * 0.5)
				y += depths[i] + SQUAD_GAP
				reserves[team].erase(e)
				var sq = _spawn(team, e, spot)
				if sq != null:
					_reform(sq, AMBUSH_FILES)
					sq.still = 0.0
					sq.facing = Vector2.UP
	else:
		var to_deploy: Array = reserves[team].duplicate()
		var n: int = to_deploy.size()
		var north_n := maxi(1, int(ceil(float(n) * 0.5)))
		var step := 90.0
		for i in n:
			var e: Dictionary = to_deploy[i]
			reserves[team].erase(e)
			var is_north := i < north_n
			var idx := i if is_north else i - north_n
			var count_in_group := north_n if is_north else n - north_n
			var x := ARENA.x * 0.5 + (float(idx) - float(count_in_group - 1) * 0.5) * step
			var y := 100.0 if is_north else ARENA.y - 100.0
			var spot := Vector2(x, y)
			if jitter > 0.0:
				spot.x += rng.randf_range(-jitter, jitter)
			var sq = _spawn(team, e, spot)
			if sq != null:
				sq.facing = Vector2.DOWN if is_north else Vector2.UP
				sq.order = "advance"


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
	if objective == OBJECTIVE_AMBUSH:
		for sq in squads:
			if sq.team == ENEMY:
				order_advance(sq)
	# Bond ranks between captains on the same side, from the points they've built up.
	for a in squads:
		for b in squads:
			if a.team == b.team and a != b and not a.info.is_empty() and not b.info.is_empty():
				var points := float(a.info.get("bonds", {}).get(str(b.info["id"]), 0.0))
				_ranks[_bond_key(a, b)] = Captains.rank_for(points)
	phase = PHASE_BATTLE


func _spawn(team: int, entry: Dictionary, at: Vector2):
	var type: String = entry["type"]
	var unit_id: String = entry.get("unit", "")
	var sq := Squad.new()
	sq.id = _next_id
	_next_id += 1
	sq.roster_id = entry["roster_id"]
	sq.team = team
	sq.type = type
	sq.unit = unit_id
	sq.level = entry["level"]
	sq.power = Troops.power_for(sq.level)
	sq.is_bodyguard = bool(entry.get("is_bodyguard", false))
	sq.is_chief = bool(entry.get("is_chief", false))
	sq.chief_name = String(entry.get("chief_name", ""))

	if unit_id != "" and Units.has(unit_id):
		sq.stats = Units.stats(unit_id, sq.level)
		sq.mechanics = Units.mechanics(unit_id, sq.level)
	else:
		sq.stats = Troops.stats(type)
		sq.mechanics = {}

	sq.armor = float(sq.mechanics.get("armor", 0.0))
	sq.piercing = float(sq.mechanics.get("piercing", 0.0))
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
		sq.arrows = men * int(sq.stats.get("arrows", 8))
	var slots := _formation_slots(men, sq.radius * 2.0 + 5.0)
	var javelins_per_man: int = int(sq.mechanics.get("javelins", 0))
	for i in men:
		var so := Soldier.new()
		so.squad = sq
		so.radius = sq.radius
		so.slot = slots[i]
		so.facing = sq.facing
		so.max_hp = float(sq.stats["hp"]) * sq.power
		so.hp = so.max_hp
		so.cooldown = rng.randf_range(0.0, 0.4)
		so.javelins = javelins_per_man
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
	sq.waypoints.clear()
	sq.last_path_goal = at
	for so in sq.soldiers:
		var slot_dest := at + _slot_world(so.slot, sq.facing, sq.team)
		if _rough and not terrain.passable(slot_dest):
			slot_dest = _passable_slot(at, slot_dest)
		so.pos = slot_dest
	sq.refresh()


## Nudge a formation slot back toward the squad center until it lands on passable ground.
func _passable_slot(center: Vector2, slot_dest: Vector2) -> Vector2:
	if not _rough or terrain.passable(slot_dest):
		return slot_dest
	var dist := slot_dest.distance_to(center)
	if dist < 0.01:
		return center
	# Half a cell at a time toward the middle of the squad, looking the ground up directly:
	# while a squad crosses a ford, many of its men do this every tick.
	var dir := (center - slot_dest) / dist
	var walked := 0.0
	while walked < dist:
		walked = minf(dist, walked + 12.0)
		var cur := slot_dest + dir * walked
		if cur.x >= 0.0 and cur.x < ARENA.x and cur.y >= 0.0 and cur.y < ARENA.y \
				and terrain.foot_speed[int(cur.y / Terrain.CELL) * Terrain.COLS + int(cur.x / Terrain.CELL)] > 0.0:
			return cur
	return center


## Squads stand three ranks deep, four to eight men wide.
func _files(men: int) -> int:
	return mini(maxi(1, men), clampi(int(ceil(men / 3.0)), 4, 8))


## Slots for `men` in ranks `files` wide (or the usual width), the front rank first.
func _formation_slots(men: int, spacing: float, files: int = 0) -> Array:
	var cols := mini(maxi(1, men), files) if files > 0 else _files(men)
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


## Half the width and depth a squad covers in formation, with room for spears and
## bodies, `files` men wide (or the usual width).
func _footprint(type: String, men: int, files: int = 0) -> Vector2:
	var r := float(Troops.stats(type)["radius"])
	var spacing := r * 2.0 + 5.0
	var cols := mini(maxi(1, men), files) if files > 0 else _files(men)
	var rows := int(ceil(float(maxi(1, men)) / cols))
	return Vector2((cols - 1) * spacing * 0.5 + r + 4.0, (rows - 1) * spacing * 0.5 + r + 4.0)


## The free spot in the zone closest to `at` for a squad of footprint `half`, or null.
func _free_spot(team: int, at: Vector2, half: Vector2, ignore):
	var zone := deploy_zone(team)
	var first := _fit(zone, at, half)
	if not _overlaps(team, first, half, ignore) and (not _rough or terrain.passable(first)):
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
			if _overlaps(team, c, half, ignore) or (_rough and not terrain.passable(c)):
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
		var other := _footprint(sq.type, sq.start_men, sq.files)
		if absf(at.x - sq.center.x) < half.x + other.x + SQUAD_GAP and absf(at.y - sq.center.y) < half.y + other.y + SQUAD_GAP:
			return true
	return false


# ---------------------------------------------------------------- orders

## Archers keep their arrows (`on`), or loose at will again. Others ignore it.
func set_hold_fire(sq, on: bool) -> void:
	if sq == null or not sq.is_active() or not sq.ranged:
		return
	sq.hold_fire = on
	for so in sq.soldiers:
		so.target = null


## How close a squad has to be to fight: bow range, or arm's length for archers holding
## their fire (and for everyone who fights hand to hand).
func _fighting_reach(sq) -> float:
	if sq.ranged and sq.hold_fire:
		return float(Troops.SIDEARM["reach"])
	return sq.reach


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
	sq.waypoints.clear()
	sq.last_path_goal = sq.center


## Go after the enemy: each squad picks the enemy squad it fights best (see best_target)
## and keeps fighting until none are left.
func order_advance(sq) -> void:
	if sq == null or not sq.is_active():
		return
	_break_off(sq)
	sq.face = Vector2.ZERO
	sq.order = "advance"
	sq.order_target = null


## March to a point, going around enemy squads on the way, then hold there.
func order_move(sq, point: Vector2) -> void:
	if sq == null or not sq.is_active():
		return
	_break_off(sq)
	sq.face = Vector2.ZERO
	sq.order = "move"
	sq.order_point = _clamp_to_arena(point)
	sq.order_target = null


# ---------------------------------------------------------------- lines

## Ranks a squad keeps when a line spreads it out: never fewer than two.
const LINE_MIN_RANKS := 2
## The fewest men abreast in a line: two for a squad drawn on its own (a column), three
## when squads share a line.
const LINE_MIN_FILES := 2
const SHARED_MIN_FILES := 3
## Space between squads sharing a line.
const LINE_GAP := SQUAD_GAP * 2.0


## Where squads would stand along the line from `a` to `b`, in the order given, each
## in its own stretch of it: [{squad, at, files, half}] (`half` is the half width and
## depth it will cover). A squad alone fills the whole line, widening or deepening its
## ranks to match; several share it in proportion to their usual width, with a gap
## between. Where they can't fit, the line grows from its middle.
func line_spots(line_squads: Array, a: Vector2, b: Vector2) -> Array:
	var n := line_squads.size()
	if n == 0:
		return []
	var dir := (b - a).normalized() if a.distance_to(b) > 1.0 else Vector2.RIGHT
	var widths := []
	var total_usual := 0.0
	for sq in line_squads:
		var w := _footprint(sq.type, _men_of(sq)).x * 2.0
		widths.append(w)
		total_usual += w
	var room := maxf(0.0, a.distance_to(b) - LINE_GAP * (n - 1))
	var spots := []
	var total := LINE_GAP * (n - 1)
	for i in n:
		var sq = line_squads[i]
		var men := _men_of(sq)
		var r := float(Troops.stats(sq.type)["radius"])
		var spacing := r * 2.0 + 5.0
		var share: float = room * widths[i] / maxf(1.0, total_usual)
		var most := maxi(1, int(ceil(float(men) / LINE_MIN_RANKS)))
		var fewest := mini(most, LINE_MIN_FILES if n == 1 else SHARED_MIN_FILES)
		var files := clampi(int(round((share - 2.0 * r - 8.0) / spacing)) + 1, fewest, most)
		var half := _footprint(sq.type, men, files)
		spots.append({"squad": sq, "files": files, "half": half})
		total += half.x * 2.0
	var at := (a + b) * 0.5 - dir * total * 0.5
	for s in spots:
		var half: Vector2 = s["half"]
		s["at"] = at + dir * half.x
		at += dir * (half.x * 2.0 + LINE_GAP)
	return spots


## Form squads up along the line from `a` to `b`: the one squad given, or else every
## squad of `team` still fighting (and, before the battle, any not yet placed). They
## take their stretches in the order they already stand along the line, so their paths
## don't cross, and face away from the line toward the enemy. Before the battle they're
## placed there at once; during it they march there and hold. Returns the spots, as
## line_spots does.
func order_line(team: int, a: Vector2, b: Vector2, only = null) -> Array:
	if winner != -1 or (phase == PHASE_DEPLOY and caught_on_march(team)):
		return []
	if only == null and phase == PHASE_DEPLOY:
		# Anyone still in reserve joins the line; they start from its middle.
		for entry in reserves[team].duplicate():
			reserves[team].erase(entry)
			_spawn(team, entry, _fit(deploy_zone(team), (a + b) * 0.5, _footprint(entry["type"], entry["men"])))
	var spots := line_preview(team, a, b, only)
	var face := line_face(team, a, b)
	for s in spots:
		var sq = s["squad"]
		_reform(sq, int(s["files"]))
		if phase == PHASE_DEPLOY:
			sq.facing = face
			_move_formation(sq, s["at"])
		else:
			order_move(sq, s["at"])
		sq.face = face
	return spots


## Where order_line would put everyone, without moving anyone: for showing the line
## while it's being drawn. Squads not yet placed stand in for themselves from the
## line's middle; before the battle, spots are kept inside the deployment zone.
func line_preview(team: int, a: Vector2, b: Vector2, only = null) -> Array:
	if winner != -1:
		return []
	var line_squads := []
	if only != null:
		if only.is_active():
			line_squads.append(only)
	else:
		for sq in squads:
			if sq.team == team and sq.is_active():
				line_squads.append(sq)
		if phase == PHASE_DEPLOY:
			for entry in reserves[team]:
				var stand_in := Squad.new()
				stand_in.type = entry["type"]
				stand_in.start_men = int(entry["men"])
				stand_in.center = (a + b) * 0.5
				line_squads.append(stand_in)
	if line_squads.is_empty():
		return []
	var dir := (b - a).normalized() if a.distance_to(b) > 1.0 else Vector2.RIGHT
	line_squads.sort_custom(func(x, y): return x.center.dot(dir) < y.center.dot(dir))
	var spots := line_spots(line_squads, a, b)
	if phase == PHASE_DEPLOY:
		for s in spots:
			s["at"] = _fit(deploy_zone(team), s["at"], s["half"])
	return spots


## Which way a line faces: square to it, toward the enemy's army (or its end of the field).
func line_face(team: int, a: Vector2, b: Vector2) -> Vector2:
	var dir := (b - a).normalized() if a.distance_to(b) > 1.0 else Vector2.RIGHT
	var normal := Vector2(-dir.y, dir.x)
	var enemy := Vector2(ARENA.x * 0.5, 0.0 if team == PLAYER else ARENA.y)
	var sum := Vector2.ZERO
	var n := 0
	for sq in squads:
		if sq.team != team and sq.is_active():
			sum += sq.avg
			n += 1
	if n > 0:
		enemy = sum / n
	return normal if normal.dot(enemy - (a + b) * 0.5) >= 0.0 else -normal


## The men a squad has to form up with: those still standing once the battle is on.
func _men_of(sq) -> int:
	return sq.alive_n if sq.alive_n > 0 else sq.start_men


## Re-form a squad `files` men wide: its living men fill the new ranks from the front,
## with the captain at the heart, and walk to their new places.
func _reform(sq, files: int) -> void:
	if files == sq.files:
		return
	sq.files = files
	var living: Array = sq.soldiers.filter(func(so): return so.alive)
	var slots := _formation_slots(living.size(), sq.radius * 2.0 + 5.0, files)
	for i in living.size():
		living[i].slot = slots[i]
	if sq.captain != null and sq.captain.alive:
		var heart = living[0]
		for so in living:
			if so.slot.length_squared() < heart.slot.length_squared() - 0.01:
				heart = so
		var keep: Vector2 = heart.slot
		heart.slot = sq.captain.slot
		sq.captain.slot = keep
	if phase == PHASE_DEPLOY:
		_move_formation(sq, sq.center)


func order_attack(sq, foe) -> void:
	if sq == null or not sq.is_active() or foe == null or not foe.is_active():
		return
	_break_off(sq)
	sq.face = Vector2.ZERO
	sq.order = "attack"
	sq.order_target = foe


## Any order to move ends a wheel and breaks a schiltron.
func _break_off(sq) -> void:
	sq.wheeling = false
	if sq.schiltron():
		sq.ability_left = 0.0
	sq.waypoints.clear()
	sq.last_path_goal = Vector2.INF


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
			sq.hold_fire = false
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
			var dur: float = float(ab["seconds"])
			if sq.mechanics.get("longer_schiltron", false):
				dur *= 1.5
			sq.ability_left = dur
			sq.wheeling = false
			if sq.order != "hold":
				order_hold(sq)
		_:
			sq.ability_left = float(ab["seconds"])
	var cd: float = float(ab["cooldown"])
	if sq.type == Troops.CAVALRY and sq.mechanics.has("wheel_cooldown_mult"):
		cd *= float(sq.mechanics["wheel_cooldown_mult"])
	elif sq.type == Troops.ARCHERS and sq.mechanics.has("volley_cooldown_mult"):
		cd *= float(sq.mechanics["volley_cooldown_mult"])
	sq.ability_cd = cd
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
	for r in scheduled_reinforcements:
		if not r.get("spawned", false) and time >= float(r.get("at_time", 0.0)):
			r["spawned"] = true
			_spawn_reinforcements(int(r.get("team", ENEMY)), r.get("entries", []), String(r.get("edge", "north")))
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
		if sq.is_bodyguard or sq.is_chief:
			_trigger_chief_shock(sq)
	if sq.routing:
		return
	if sq.order == "attack" and (sq.order_target == null or not sq.order_target.is_active()):
		order_advance(sq)

	var reach := _fighting_reach(sq)
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
	sq.range_mult = 1.0
	if sq.ranged and not sq.hold_fire and foe != null and _rough:
		sq.range_mult = TerrainRules.height_range_mult(terrain.height_at(sq.avg) - terrain.height_at(foe.avg))
		reach *= sq.range_mult

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

	# Skirmishing: horse archers and kiting desert archers keep distance from approaching foot
	var is_skirmisher: bool = sq.ranged and sq.arrows > 0 and (sq.mechanics.get("horse_archer", false) or sq.mechanics.get("kite", false))
	if is_skirmisher and not sq.wheeling:
		var threat = _nearest_enemy_foot(sq, 130.0)
		if threat != null and not sq.engaged:
			var away: Vector2 = (sq.center - threat.avg).normalized()
			if away == Vector2.ZERO:
				away = Vector2.DOWN if sq.team == PLAYER else Vector2.UP
			sq.goal = sq.center + away * 90.0
			chasing = false

	# Engaged squads break formation and fight man to man. A braced line that the enemy
	# reaches gets the first few seconds of the fight on its side.
	var was_engaged: bool = sq.engaged
	sq.engaged = false
	if foe != null:
		var slack := 20.0 if sq.ranged and not sq.hold_fire else ENGAGE_RANGE
		sq.engaged = _in_range(sq, foe, reach + slack)
	if sq.engaged:
		if is_skirmisher and sq.mechanics.get("horse_archer", false) and not sq.wheeling and sq.engaged_for >= 0.3:
			# Horse archers ride clear when engaged in melee while arrows remain
			_start_wheel(sq)
			return
		if not was_engaged:
			var can_brace: bool = sq.order == "hold" and sq.still >= BRACE_SET and not sq.ranged
			if can_brace and _rough and terrain.water_at(sq.center) == Terrain.WATER_SHALLOW:
				can_brace = false
			sq.brace = BRACE_SECONDS if can_brace else 0.0
			if sq.brace > 0.0:
				events.append({"type": "braced", "squad": sq})
		sq.brace = maxf(0.0, sq.brace - dt)
		sq.engaged_for += dt
		sq.still = 0.0
		sq.center = sq.center.lerp(avg, 0.15)
		return
	sq.engaged_for = 0.0
	sq.brace = 0.0

	# Pathfinding update: re-plan route every 1.0s or when goal shifts significantly
	sq.path_timer += dt
	if sq.last_path_goal.distance_squared_to(sq.goal) > 3600.0 or sq.path_timer >= 1.0:
		sq.path_timer = 0.0
		sq.last_path_goal = sq.goal
		if _rough and not sq.schiltron() and sq.goal.distance_squared_to(sq.center) > 100.0:
			sq.waypoints = Pathing.find_path(terrain, sq.center, sq.goal, sq.type == Troops.CAVALRY)
		else:
			sq.waypoints.clear()

	var target_pt: Vector2 = sq.goal
	if not sq.waypoints.is_empty():
		while not sq.waypoints.is_empty() and sq.center.distance_to(sq.waypoints[0]) < 25.0:
			sq.waypoints.pop_front()
		if not sq.waypoints.is_empty():
			target_pt = sq.waypoints[0]

	var to: Vector2 = Vector2.ZERO if sq.schiltron() else target_pt - sq.center
	var is_final_leg: bool = sq.waypoints.is_empty()
	var stop := reach * 0.85 if chasing and sq.ranged and is_final_leg else 0.0 # archers halt at bow range on final leg
	var dist := to.length()
	if dist > stop + 2.0:
		var dir := _steer(sq, to / dist, dist, foe)
		var pace := _pace(sq)
		if sq.order == "advance" and not sq.wheeling and dist - stop > CHARGE_DISTANCE:
			pace = minf(pace, MARCH_SPEED)
		var s_factor := 1.0
		if _rough:
			s_factor = _ground_pace(sq.center, sq.type == Troops.CAVALRY, dir)
		sq.center = _slide(sq.center, sq.center + dir * minf(dist - stop, pace * s_factor * dt))
		sq.facing = dir
		sq.still = 0.0
	else:
		if sq.order == "hold":
			if not _rough or terrain.water_at(sq.center) != Terrain.WATER_SHALLOW:
				sq.still += dt
			else:
				sq.still = 0.0
		# Standing still: turn to meet an enemy squad that comes close, otherwise face
		# the way its line was drawn, or the enemy's end of the field (so a squad that
		# walked back to its post doesn't stand there facing its own lines).
		var want: Vector2 = sq.face if sq.face != Vector2.ZERO else (Vector2.UP if sq.team == PLAYER else Vector2.DOWN)
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
	score -= (100.0 - float(foe.morale)) * 0.8
	# Terrain: Cavalry don't choose targets across water or through woods
	if sq.type == Troops.CAVALRY and _rough:
		if terrain.in_woods(foe.avg) or terrain.in_woods(from):
			score += 300.0
		if terrain.water_at(foe.avg) != Terrain.WATER_NONE:
			score += 400.0
		elif not _clear_run(sq, foe, from):
			score += 200.0
	return score


## Whether horse at `from` can ride straight at `foe` without deep water or rock in the
## way. Worked out afresh every half second; squads don't move far in between.
func _clear_run(sq, foe, from: Vector2) -> bool:
	if time - sq.clear_run_at >= 0.5:
		sq.clear_run.clear()
		sq.clear_run_at = time
	if not sq.clear_run.has(foe.id):
		sq.clear_run[foe.id] = Pathing.has_line_of_sight(terrain, from, foe.avg)
	return sq.clear_run[foe.id]


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
	var lim: float = limit
	if a.ranged and not a.hold_fire and _rough:
		var diff: float = terrain.height_at(a.avg) - terrain.height_at(b.avg)
		lim *= TerrainRules.height_range_mult(diff)
	lim += a.radius + b.radius
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

	# Javelins: thrown as the enemy closes to within 90 units, before the lines meet.
	if so.javelins > 0 and so.cooldown <= 0.0 and not sq.engaged:
		var j_target = _find_javelin_target(so, sq, 90.0)
		if j_target != null:
			_throw_javelin(so, sq, j_target)
			so.javelins -= 1
			so.cooldown = 1.0
			so.swing = 0.3

	if not sq.engaged:
		so.target = null
		so.facing = sq.facing
		var slot_dest: Vector2 = sq.center + _slot_world(so.slot, sq.facing, sq.team)
		if not _open_ground(slot_dest):
			slot_dest = _passable_slot(sq.center, slot_dest)
		so.runup += _walk(so, slot_dest, speed * 1.25, dt)
		return

	if not _target_ok(so, sq):
		so.target = _pick_target(so, sq)
	if so.target == null:
		var goal_dest: Vector2 = sq.goal
		if not _open_ground(goal_dest):
			goal_dest = _passable_slot(sq.center, goal_dest)
		so.runup += _walk(so, goal_dest, speed, dt)
		return

	var tpos: Vector2 = so.target.pos
	var gap: float = so.pos.distance_to(tpos) - so.target.radius - so.radius
	if tpos != so.pos:
		so.facing = (tpos - so.pos).normalized()
	var reach: float = _fighting_reach(sq) * sq.range_mult
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
	if _rough:
		so.pos = _rough_step(before, dest, speed * dt, so.squad.type == Troops.CAVALRY)
	else:
		so.pos = before.move_toward(dest, speed * dt)
	var moved := before.distance_to(so.pos)
	so.stride += moved
	return moved


## Where a man at `from` heading for `dest` ends up after a step of `step` on level open
## ground, with the ground he stands on speeding or slowing him, kept off deep water and
## rock. _ground_pace and _open_ground in one, since every man takes a step every tick.
## One who somehow stands on rock or in deep water walks straight out of it.
func _rough_step(from: Vector2, dest: Vector2, step: float, mounted: bool) -> Vector2:
	if from.x >= 0.0 and from.x < ARENA.x and from.y >= 0.0 and from.y < ARENA.y:
		var i := int(from.y / Terrain.CELL) * Terrain.COLS + int(from.x / Terrain.CELL)
		var pace: float = terrain.horse_speed[i] if mounted else terrain.foot_speed[i]
		if pace <= 0.0:
			return from.move_toward(dest, step)
		step *= pace
		var up: float = terrain.rise[i].dot(from.direction_to(dest))
		if up != 0.0:
			step *= TerrainRules.slope_speed_mult(clampf(up * SLOPE_SCALE, -1.0, 1.0))
	var to := from.move_toward(dest, step)
	if to.x < 0.0 or to.x >= ARENA.x or to.y < 0.0 or to.y >= ARENA.y \
			or terrain.foot_speed[int(to.y / Terrain.CELL) * Terrain.COLS + int(to.x / Terrain.CELL)] > 0.0:
		return to
	return _slide(from, to)


## How the ground at `p` speeds or slows a man heading `dir` (a unit vector): woods and
## fords slow him, climbing slows him, going downhill speeds him a little. Off the field
## nothing does.
func _ground_pace(p: Vector2, mounted: bool, dir: Vector2) -> float:
	if p.x < 0.0 or p.x >= ARENA.x or p.y < 0.0 or p.y >= ARENA.y:
		return 1.0
	var i := int(p.y / Terrain.CELL) * Terrain.COLS + int(p.x / Terrain.CELL)
	var pace: float = terrain.horse_speed[i] if mounted else terrain.foot_speed[i]
	var up: float = terrain.rise[i].dot(dir)
	if up != 0.0:
		pace *= TerrainRules.slope_speed_mult(clampf(up * SLOPE_SCALE, -1.0, 1.0))
	return pace


## Where a man stepping from `from` toward `to` ends up: all the way on open ground, else
## along the bank or the rock face, else where he stood.
func _slide(from: Vector2, to: Vector2) -> Vector2:
	if _open_ground(to):
		return to
	var along_x := Vector2(to.x, from.y)
	if _open_ground(along_x):
		return along_x
	var along_y := Vector2(from.x, to.y)
	if _open_ground(along_y):
		return along_y
	return from


## Whether a man can stand at `p`. Off the field counts as open: routers leave by it.
func _open_ground(p: Vector2) -> bool:
	if not _rough or p.x < 0.0 or p.x >= ARENA.x or p.y < 0.0 or p.y >= ARENA.y:
		return true
	return terrain.foot_speed[int(p.y / Terrain.CELL) * Terrain.COLS + int(p.x / Terrain.CELL)] > 0.0


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
	if sq.ranged and sq.hold_fire:
		# Holding fire: a short blade, no arrow spent.
		dmg = float(Troops.SIDEARM["damage"]) * sq.power * so.might * boost * rng.randf_range(0.8, 1.2)
	elif sq.ranged:
		if gap < 30.0:
			if sq.mechanics.get("samurai_sidearm", false):
				# Ryumon yumi samurai fight like infantry when caught in melee
				dmg = 13.0 * sq.power * so.might * boost * rng.randf_range(0.8, 1.2)
				_damage(target, dmg, sq, false, so, _side_of(target, so.pos, sq))
				return
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
	var can_charge: bool = sq.type == Troops.CAVALRY and so.runup >= Troops.CHARGE_RUNUP and (target_type != Troops.SPEARMEN or side == REAR)
	if can_charge and _rough:
		# No charge bonus when charging uphill
		if terrain.height_at(so.pos) < terrain.height_at(target.pos):
			can_charge = false
		# No charges into or out of woods
		elif terrain.in_woods(so.pos) or terrain.in_woods(target.pos):
			can_charge = false
		# No charges through water
		elif terrain.water_at(so.pos) == Terrain.WATER_SHALLOW or terrain.water_at(target.pos) == Terrain.WATER_SHALLOW:
			can_charge = false
	if can_charge:
		var charge_mult: float = float(sq.mechanics.get("charge_mult", Troops.CHARGE_MULTIPLIER))
		if sq.mechanics.get("lance", false):
			charge_mult = maxf(charge_mult, 6.5)
		dmg *= charge_mult
		charge = true
	if side == FLANK:
		dmg *= FLANK_POWER
	elif side == REAR:
		dmg *= REAR_POWER
	elif target.squad.shield_wall():
		dmg *= Troops.SHIELD_WALL_MELEE
	# Melee armor and piercing
	var eff_armor := maxf(0.0, target.squad.armor * (1.0 - sq.piercing))
	dmg *= (1.0 - minf(0.5, eff_armor * 0.5))
	if _rough:
		# Height advantage / penalty
		var att_h: float = terrain.height_at(so.pos)
		var def_h: float = terrain.height_at(target.pos)
		dmg *= TerrainRules.height_damage_mult(att_h, def_h)
		# Men in water take +25% damage
		if terrain.water_at(target.pos) == Terrain.WATER_SHALLOW:
			dmg *= TerrainRules.WATER_DAMAGE_TAKEN_MULT
	_damage(target, dmg, sq, charge, so, side)
	if charge:
		events.append({"type": "charge", "pos": target.pos, "squad": sq, "victim": target.squad})
	if sq.mechanics.get("sweep", false):
		var second = _find_sweep_target(so, sq, target, _fighting_reach(sq) + 10.0)
		if second != null:
			_damage(second, dmg * 0.5, sq, false, so, _side_of(second, so.pos, sq))


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
	sq.hold_fire = false
	if sq.type == Troops.CAVALRY:
		sq.reach = 14.0
		if sq.mechanics.get("weak_melee", false):
			sq.damage = 8.0 * sq.power
			sq.cooldown = 1.1
		elif sq.mechanics.get("good_melee", false):
			sq.damage = 14.0 * sq.power
			sq.cooldown = 1.0
			sq.bonus = Troops.TYPES[Troops.CAVALRY]["bonus"].duplicate()
		else:
			sq.damage = float(sq.stats.get("damage", 15.0)) * sq.power
			sq.cooldown = float(sq.stats.get("cooldown", 1.0))
	elif sq.mechanics.get("samurai_sidearm", false):
		sq.reach = 14.0
		sq.damage = 13.0 * sq.power
		sq.cooldown = 1.0
		sq.bonus = Troops.TYPES[Troops.INFANTRY]["bonus"].duplicate()
	else:
		sq.reach = float(Troops.SIDEARM["reach"])
		sq.damage = float(Troops.SIDEARM["damage"]) * sq.power
		sq.cooldown = float(Troops.SIDEARM["cooldown"])
		sq.bonus = {}
	events.append({"type": "out_of_arrows", "squad": sq})


func _shoot(so, sq, target, dmg: float, volley: bool = false, kind: String = "arrow") -> void:
	var p := Projectile.new()
	p.pos = so.pos
	p.origin = so.pos
	p.target = target
	p.aim = target.pos
	p.damage = dmg
	p.source = sq
	p.shooter = so
	p.volley = volley
	p.kind = kind
	p.piercing = sq.piercing
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
			# Arrows into woods: 50% hit trees (they stick there)
			if _rough and terrain.in_woods(p.target.pos) and rng.randf() < TerrainRules.WOODS_ARROW_BLOCK:
				_stick(p, p.target.pos + Vector2(rng.randf_range(-10.0, 10.0), rng.randf_range(-10.0, 10.0)))
				continue
			var vs = p.target.squad
			var dmg: float = p.damage
			if vs.shield_wall() and vs.facing.dot((p.origin - p.target.pos).normalized()) > FLANK_DOT:
				var wall_block := 1.0 - Troops.SHIELD_WALL_ARROWS
				if vs.mechanics.get("shield_wall_boost", 0.0) > 0.0:
					wall_block += float(vs.mechanics["shield_wall_boost"])
				wall_block *= (1.0 - p.piercing)
				dmg *= (1.0 - minf(0.95, wall_block))
			# Armor on target
			var eff_armor := maxf(0.0, vs.armor * (1.0 - p.piercing))
			dmg *= (1.0 - minf(0.8, eff_armor))
			vs.under_fire = 2.0
			if p.volley:
				var shock: float = Troops.VOLLEY_SHOCK / float(vs.start_men)
				if _rough and terrain.in_woods(p.target.pos):
					shock *= TerrainRules.WOODS_VOLLEY_SHOCK
				vs.drop_morale(shock)
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
		vs.drop_morale(CHARGE_SHOCK / float(vs.start_men))
	if side != FRONT:
		vs.drop_morale(REAR_SHOCK / float(vs.start_men) * (1.0 if side == REAR else 0.5))
		if time - vs.flanked_at > 4.0:
			vs.flanked_at = time
			events.append({"type": "flanked", "squad": vs, "pos": victim.pos, "rear": side == REAR})
	if victim.hp <= 0.0:
		_remove(victim)
		vs.drop_morale((100.0 / float(vs.start_men) * 0.8 + 2.0) * vs.led)
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
	sq.drop_morale(Captains.FALL_SHOCK)
	if sq.mechanics.get("ronin", false):
		sq.fury = Captains.FURY_SECONDS
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
	if sq.is_bodyguard or sq.is_chief:
		_trigger_chief_shock(sq)
		if sq.captain_fate == "killed":
			chief_killed = true
			chief_escaped = false
			events.append({"type": "chief_slain", "squad": sq, "chief_name": sq.chief_name})
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


func _find_javelin_target(so, sq, max_dist: float):
	var best = null
	var best_d := INF
	for e in _nearby(so.pos, max_dist):
		if e.squad.team != sq.team and not e.squad.routing:
			var d: float = so.pos.distance_to(e.pos)
			if d < best_d:
				best_d = d
				best = e
	return best


func _throw_javelin(so, sq, target) -> void:
	_shoot(so, sq, target, 35.0 * sq.power, false, "javelin")


func _find_sweep_target(so, sq, primary, max_dist: float):
	for e in _nearby(so.pos, max_dist):
		if e != primary and e.squad.team != sq.team and not e.squad.routing:
			return e
	return null


func _nearest_enemy_foot(sq, max_dist: float):
	var best = null
	var best_d := max_dist
	for foe in squads:
		if foe.team != sq.team and foe.is_active() and not foe.ranged and foe.type != Troops.CAVALRY:
			var d: float = sq.center.distance_to(foe.avg)
			if d < best_d:
				best_d = d
				best = foe
	return best


func _trigger_chief_shock(sq) -> void:
	if chief_broken:
		return
	chief_broken = true
	events.append({"type": "chief_broken", "squad": sq, "chief_name": sq.chief_name})
	for other in squads:
		if other != sq and other.team == sq.team and other.is_active():
			other.drop_morale(35.0)


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
			if so.push != Vector2.ZERO:
				var to: Vector2 = so.pos + so.push.limit_length(4.0)
				# _open_ground(to), written out: this runs for most men every tick.
				if not _rough or to.x < 0.0 or to.x >= ARENA.x or to.y < 0.0 or to.y >= ARENA.y \
						or terrain.foot_speed[int(to.y / Terrain.CELL) * Terrain.COLS + int(to.x / Terrain.CELL)] > 0.0:
					so.pos = to
				else:
					so.pos = _slide(so.pos, to)
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
	if objective == OBJECTIVE_VILLAGE and time >= VILLAGE_DURATION:
		var p_count := 0
		var e_count := 0
		for sq in squads:
			for so in sq.soldiers:
				if so.alive and so.pos.distance_to(VILLAGE_ZONE_CENTER) <= VILLAGE_ZONE_RADIUS:
					if sq.team == PLAYER:
						p_count += 1
					else:
						e_count += 1
		if p_count > e_count:
			_finish(PLAYER, "village_held")
		else:
			_finish(ENEMY, "village_lost")
		return

	var standing := [has_active(PLAYER) or _has_pending_reinforcements(PLAYER),
		has_active(ENEMY) or _has_pending_reinforcements(ENEMY)]
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
	# A chief who wasn't cut down gets away from a lost field, hurt or not. One who won it
	# stays at the head of his band.
	if objective == OBJECTIVE_CHIEF:
		chief_escaped = winner == PLAYER and not chief_killed
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
	return {"won": winner == team, "reason": end_reason, "squads": by_id, "lost": lost, "killed": killed, "time": time, "bonds": bonds,
		"objective": objective, "chief_killed": chief_killed, "chief_escaped": chief_escaped}
