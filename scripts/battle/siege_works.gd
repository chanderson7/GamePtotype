## Siege engines and a wall that can break, on the field of an assault (BattleSim's siege
## objective). What each side brings is set before the battle (BattleSim.siege_engines):
## the stormers' ram, ladders, mantlets, tower and stone throwers; the walls' bolt
## throwers, oil over the gate, a stone thrower in the courtyard and a postern to sally
## from. An engine works while a company stands at it (its crew); wood burns; stones bring
## wall sections down into rubble a man can climb. Without a config, a siege is what it
## always was: a ram and two ladders against bare walls.
extends RefCounted

const Troops = preload("res://scripts/data/troops.gd")
const Terrain = preload("res://scripts/battle/terrain.gd")

const PLAYER := 0
const ENEMY := 1

# ---------------------------------------------------------------- what there is

const RAM := "ram"
const LADDERS := "ladders"
const MORE_LADDERS := "more_ladders"
const MANTLETS := "mantlets"
const TOWER := "tower"
const THROWER := "thrower"
const BOLT := "bolt"
const OIL := "oil"
const YARD := "yard_thrower"
const POSTERN := "postern"
## What a besieger can build (a thrower may be built twice), and what a wall can keep (a
## bolt thrower up to three times).
const STORMERS := [LADDERS, RAM, MANTLETS, MORE_LADDERS, TOWER, THROWER]
const WALL_WORKS := [BOLT, OIL, YARD, POSTERN]
## A siege nobody prepared for: what every assault had before engines.
const DEFAULT_ATTACK := [RAM, LADDERS]

const HP := {RAM: 900.0, MANTLETS: 250.0, TOWER: 2000.0, THROWER: 700.0, BOLT: 500.0, YARD: 700.0}

# ---------------------------------------------------------------- crews and fire

## An engine works while at least CREW_MIN men of its side stand within CREW_REACH of it,
## at a rate rising to full at CREW_FULL.
const CREW_MIN := 6
const CREW_FULL := 12
const CREW_REACH := 100.0
## What's left of an arrow that hits a man at an engine, behind its timbers.
const ENGINE_COVER := 0.6
## Arrows barely mark wood: this much of an arrow's damage reaches an engine.
const ARROW_ON_WOOD := 0.02
## Burning: damage a second, for how long. A crew at a burning engine fights the fire
## (it goes out twice as fast) instead of working it.
const BURN_DPS := 8.0
const BURN_TIME := 12.0
## Men hacking at an engine: damage a second each, and the chance a second that the
## engine catches.
const HACK_DPS := 3.0
const HACK_REACH := 22.0
const HACK_FIRE := 0.12

# ---------------------------------------------------------------- the stormers

## Without a ram, men at the gate hack at it with axes, at this share of a ram's blows, and
## nothing roofs them.
const GATE_NO_RAM := 0.35
## Stone throwers: how far, how often, how true (a fixed scatter plus a share of the
## range), how long a stone is in the air.
const THROW_RANGE := 720.0
## The walls' own thrower stands on a raised platform: it reaches the whole field, so no
## besieger's engine is safe from it.
const YARD_RANGE := 1020.0
const THROW_RELOAD := 10.0
const THROW_SCATTER := 14.0
const THROW_SCATTER_PER := 0.04
const THROW_FLIGHT := 1.6
## What a stone does: to a wall section, to the gate (in ram blows), to every man within
## SPLASH_RADIUS (and a shock to his company's nerve), to an engine within ENGINE_HIT_REACH.
const WALL_HIT := 100.0
const GATE_HIT := 60.0
const STONE_SPLASH := 40.0
const SPLASH_RADIUS := 20.0
const STONE_SHOCK := 3.0
const ENGINE_HIT := 220.0
const ENGINE_HIT_REACH := 26.0
## Throwers aimed at men keep their stones this far from their own side's men.
const FRIENDLY_CLEAR := 70.0
## The throwers stand this far back from the wall, side by side across from the gate (a
## battery one company can work).
const ENGINE_LINE := 560.0
const THROWER_SPREAD := 42.0
## The tower: where it starts, how fast it rolls, what's left of an arrow for the men
## pushing it, and how fast men climb its bridge once it's at the wall.
const TOWER_START := 400.0
const TOWER_PACE := 12.0
const TOWER_COVER := 0.2
const TOWER_CLIMB := 0.9
## Bows behind mantlets take arrows at MANTLET_COVER.
const MANTLET_COVER := 0.5

# ---------------------------------------------------------------- the walls

## Wall sections: hp by kind of place, at most this many cells each; a fallen section
## becomes rubble men on foot cross at RUBBLE_PACE (horses can't).
const WALL_HP := {"castle": 900.0, "town": 650.0}
const WALL_SECTION := 3
const RUBBLE_PACE := 0.6
## Bolt throwers on the wall's towers, either side of the gate (a third over it).
## They reach across the whole of the ground the stormers form up on, so sitting out of
## reach isn't a choice: true within BOLT_SURE, and hitting at worst BOLT_FAR_HIT of the
## time at the end of their range (a miss strikes the ground near the mark).
const BOLT_RANGE := 780.0
const BOLT_SURE := 320.0
const BOLT_FAR_HIT := 0.4
## A bolt thrower on a tower can't aim down at the foot of its own wall: men within this
## of the wall line are dead ground to it (oil and the wall's bows are for them). Standing
## off is what the bolts punish; closing with the walls gets you under them.
const BOLT_DEAD := 90.0
## Engines within this are a bolt thrower's first mark (a rolling tower anywhere in range);
## further off it picks off the men standing about them, and shoots at a far engine only
## when there's nobody to shoot.
const BOLT_ENGINE_REACH := 450.0
const BOLT_RELOAD := 5.0
## A bolt is heavy (an infantryman has 600 hit points, an arrow does 40): four kill a man,
## and the one behind him takes half.
const BOLT_DAMAGE := 150.0
const BOLT_BEHIND := 75.0
const BOLT_ENGINE := 80.0
const BOLT_FLIGHT := 0.15
## Seconds of flight per unit of distance, on top of BOLT_FLIGHT.
const BOLT_PACE := 1.0 / 1800.0
const BOLT_SPREAD := 180.0
const BOLT_FAST := 0.8
## Oil over the gate: a pour this often on everyone within the gate's reach.
const OIL_EVERY := 20.0
const OIL_DAMAGE := 60.0
## Fire arrows at an engine: share of a volley that hits, and the chance a hit sets it
## burning.
const FIRE_HITS := 0.5
const FIRE_ODDS := 0.2
const FIRE_RANGE := 250.0
## The courtyard thrower stands this far inside the wall.
const YARD_BACK := 230.0
const YARD_SIDE := -220.0
## The postern: a small door in the wall this many cells from the right-hand edge; a
## sallying company passes through it this far either side of the wall.
const POSTERN_COL := 25
const POSTERN_STEP := 34.0

## How each land builds: the name of its stone thrower, how often it throws, what its
## stones do to walls, and what's special.
const LANDS := {
	"vardish": {"thrower": "trebuchet", "reload": 11.0, "wall": 1.5},
	"kharzani": {"thrower": "mangonel", "reload": 8.0, "wall": 1.0, "naphtha": true, "fire_pots": true},
	"ryumon": {"thrower": "stone thrower", "reload": 7.0, "wall": 0.7, "bamboo": true, "yagura": true, "logs": true},
}
## Naphtha: a stone that lands sets the ground burning for NAPHTHA_TIME, NAPHTHA_DPS to men
## in it, and sets engines alight.
const NAPHTHA_TIME := 6.0
const NAPHTHA_DPS := 10.0
const NAPHTHA_RADIUS := 20.0
## Ryumon walls: bows in covered yagura take arrows at this (not BattleSim.WALL_ARROWS).
const YAGURA_ARROWS := 0.35


class SiegeEngine:
	var id := 0
	var kind := ""
	var team := 0
	var pos := Vector2.ZERO
	## Where it was set up; for the tower, where it docks against the wall.
	var home := Vector2.ZERO
	var hp := 0.0
	var hp_max := 0.0
	var burning := 0.0
	var reload := 0.0
	## What it's aimed at: {kind: "auto" | "section" | "gate" | "engine" | "squad", ref}.
	var aim := {"kind": "auto"}
	## Men working it this tick.
	var crew := 0
	## The company told to work it (or -1): the screen and the plans use it.
	var crew_squad = null
	var moving := false
	var docked := false
	var section := -1
	## A mantlet's bow company.
	var owner = null
	var shots := 0
	var burnt := false
	## Its land's way of building it (LANDS).
	var land := "vardish"

	func working() -> bool:
		return not burnt

	func crewed() -> bool:
		return crew >= CREW_MIN

	## The share of full speed it works at (0 below a crew).
	func rate() -> float:
		if crew < CREW_MIN:
			return 0.0
		return clampf(float(crew) / float(CREW_FULL), 0.5, 1.0)


var sim = null
var engines: Array = []
## [{cols, hp, hp_max, broken, open}] across the wall, gate and ladders not included.
var sections: Array = []
## Stones and bolts in the air: {kind, team, from, to, t, flight, source, target, naphtha}.
var shots: Array = []
## Ground burning with naphtha: {pos, left}.
var flames: Array = []
## What each side brought (config lists), and its land.
var attack_kit: Array = []
var wall_kit: Array = []
var attack_land := "vardish"
var wall_land := "vardish"
var attacker := PLAYER
var defender := ENEMY
## The ladder columns this siege has (two, or four with more ladders).
var ladder_cols: Array = []
## Columns a man can cross the wall by, besides the gate, and how fast: ladders, a docked
## tower's bridge, rubble.
var crossing := {}
var _oil_clock := 0.0
var _next_id := 1
## Tallies for the result: stones thrown and bolts loosed by team, sections broken, engines
## burned by the side that lost them, pours of oil, men killed by engines by team.
var stones := [0, 0]
var bolts := [0, 0]
var sections_broken := 0
var burned := [0, 0]
var pours := 0
var engine_kills := [0, 0]
var _naming := {}


## Set up from `config` ({attacker, defender, attacker_land, defender_land, damage}) on
## `s`'s field, after its wall is raised.
func setup(s, config: Dictionary) -> void:
	sim = s
	defender = s.siege_defender
	attacker = 1 - defender
	attack_kit = (config.get("attacker", DEFAULT_ATTACK) as Array).duplicate()
	wall_kit = (config.get("defender", []) as Array).duplicate()
	attack_land = String(config.get("attacker_land", "vardish"))
	wall_land = String(config.get("defender_land", "vardish"))
	if not LANDS.has(attack_land):
		attack_land = "vardish"
	if not LANDS.has(wall_land):
		wall_land = "vardish"
	ladder_cols = [4, 23]
	if attack_kit.has(MORE_LADDERS):
		ladder_cols = [4, 8, 19, 23]
	if not attack_kit.has(LADDERS) and not attack_kit.has(MORE_LADDERS):
		# Ladders are lashed together on the march: everyone has two.
		attack_kit.append(LADDERS)
	crossing = {}
	for cx in ladder_cols:
		crossing[cx] = s.LADDER_PACE
	_make_sections(config.get("damage", {}))
	_place_engines()


func has(kind: String, team: int = -1) -> bool:
	for e in engines:
		if e.kind == kind and (team == -1 or e.team == team) and e.working():
			return true
	return false


func count(kind: String, team: int = -1) -> int:
	var n := 0
	for e in engines:
		if e.kind == kind and (team == -1 or e.team == team) and e.working():
			n += 1
	return n


func engine_by_id(id: int):
	for e in engines:
		if e.id == id:
			return e
	return null


## The ram at the gate, if it's built and not burnt.
func ram():
	for e in engines:
		if e.kind == RAM and e.working():
			return e
	return null


func land_of(team: int) -> Dictionary:
	return LANDS[attack_land if team == attacker else wall_land]


## The name an engine goes by, in its land's way ("trebuchet", "mangonel"...).
func engine_name(e) -> String:
	match e.kind:
		THROWER, YARD:
			return String(LANDS.get(e.land, LANDS["vardish"])["thrower"])
		BOLT:
			return "bolt thrower"
		MANTLETS:
			return "bamboo shields" if e.land == "ryumon" else "mantlet"
		TOWER:
			return "siege tower"
	return e.kind


# ---------------------------------------------------------------- the wall

func _make_sections(damage: Dictionary) -> void:
	sections = []
	var run: Array = []
	var blocked := []
	for cx in Terrain.COLS:
		blocked.append(not (sim.GATE_COLS.has(cx) or ladder_cols.has(cx) or cx == POSTERN_COL))
	for cx in Terrain.COLS + 1:
		if cx < Terrain.COLS and blocked[cx]:
			run.append(cx)
			continue
		var i := 0
		while i < run.size():
			var left := run.size() - i
			var take := WALL_SECTION if left > WALL_SECTION + 1 or left == WALL_SECTION else left
			if left == WALL_SECTION + 1:
				take = 2
			sections.append({"cols": run.slice(i, i + take), "hp": 0.0, "hp_max": 0.0, "broken": false, "open": []})
			i += take
		run = []
	var full := float(WALL_HP.get(sim.siege_kind, WALL_HP["castle"]))
	# The campaign keeps damage by column (the sections fall differently with four
	# ladders): a section is as strong as its weakest stretch.
	var hurt: Dictionary = damage.get("cols", {})
	for i in sections.size():
		var share := 1.0
		for cx in sections[i]["cols"]:
			share = minf(share, clampf(float(hurt.get(str(cx), 1.0)), 0.0, 1.0))
		sections[i]["hp_max"] = full
		sections[i]["hp"] = full * share
	if damage.has("gate"):
		sim.gate_hp = sim.gate_max * clampf(float(damage["gate"]), 0.0, 1.0)
	# Damage the place hasn't repaired: what was broken is broken.
	for i in sections.size():
		if sections[i]["hp"] <= 0.0:
			_break_section(i, false)


## The section of the wall at column `cx`, or -1.
func section_at(cx: int) -> int:
	for i in sections.size():
		if (sections[i]["cols"] as Array).has(cx):
			return i
	return -1


func section_center(i: int) -> Vector2:
	var cols: Array = sections[i]["cols"]
	var x := (float(cols[0]) + float(cols[cols.size() - 1]) + 1.0) * 0.5 * Terrain.CELL
	return Vector2(x, sim.wall_y)


## A section comes down: rubble, open to men on foot.
func _break_section(i: int, announce: bool = true) -> void:
	var sec: Dictionary = sections[i]
	if sec["broken"]:
		return
	sec["broken"] = true
	sec["hp"] = 0.0
	# The whole section comes down: a heap of rubble along it.
	var mid: Array = (sec["cols"] as Array).duplicate()
	sec["open"] = mid
	for cx in mid:
		crossing[cx] = RUBBLE_PACE
		var idx: int = sim.wall_row * Terrain.COLS + int(cx)
		sim.terrain.rock[idx] = Terrain.ROCK_NONE
		sim.terrain.foot_speed[idx] = RUBBLE_PACE
		sim.terrain.horse_speed[idx] = 0.0
		sim._foot[idx] = RUBBLE_PACE
		sim._horse[idx] = 0.0
	if announce:
		sections_broken += 1
		sim.breaches_at.append(section_center(i))
		sim.events.append({"type": "wall_breached", "at": section_center(i), "section": i})
		sim._log_siege("section", null)


## Whether any section has come down.
func any_breach() -> bool:
	for sec in sections:
		if sec["broken"]:
			return true
	return false


## The share of the wall's strength left, by column (for the campaign to keep).
func col_state() -> Dictionary:
	var out := {}
	for i in sections.size():
		var frac: float = float(sections[i]["hp"]) / maxf(1.0, float(sections[i]["hp_max"]))
		if frac < 0.999:
			for cx in sections[i]["cols"]:
				out[str(cx)] = snappedf(frac, 0.01)
	return out


# ---------------------------------------------------------------- setting up engines

func _add(kind: String, team: int, at: Vector2):
	var e := SiegeEngine.new()
	e.id = _next_id
	_next_id += 1
	e.kind = kind
	e.team = team
	e.pos = at
	e.home = at
	e.hp_max = float(HP.get(kind, 1.0))
	e.hp = e.hp_max
	e.land = attack_land if team == attacker else wall_land
	e.reload = 2.0 + float(_next_id) * 0.7
	engines.append(e)
	return e


## Out from the wall (toward the stormers' edge of the field).
func outward() -> float:
	return -sim.inward()


func _place_engines() -> void:
	engines = []
	var g: Vector2 = sim.gate_center
	var wy: float = sim.wall_y
	if attack_kit.has(RAM):
		_add(RAM, attacker, g + Vector2(0.0, outward() * 26.0))
	var throwers := mini(2, attack_kit.count(THROWER))
	for i in throwers:
		var sx := -1.0 if i == 0 else 1.0
		_add(THROWER, attacker, Vector2(g.x + sx * THROWER_SPREAD, wy + outward() * ENGINE_LINE))
	if attack_kit.has(TOWER):
		var target := _tower_section()
		var dock := section_center(target) + Vector2(0.0, outward() * 22.0)
		var t = _add(TOWER, attacker, Vector2(dock.x, wy + outward() * TOWER_START))
		t.home = dock
		t.section = target
	var bolt_n := mini(3, wall_kit.count(BOLT))
	for i in bolt_n:
		var x: float = g.x + (-BOLT_SPREAD if i == 0 else (BOLT_SPREAD if i == 1 else 0.0))
		var b = _add(BOLT, defender, Vector2(x, wy + sim.inward() * (sim.WALK_DEPTH + 6.0)))
		if bolt_n == 3:
			b.reload *= BOLT_FAST
	if wall_kit.has(YARD):
		_add(YARD, defender, Vector2(g.x + YARD_SIDE, wy + sim.inward() * YARD_BACK))


## The section the tower makes for: whole wall between the gate and the left-hand ladder.
func _tower_section() -> int:
	var best := -1
	var best_d := INF
	var want: float = (float(ladder_cols[0]) * Terrain.CELL + sim.gate_center.x) * 0.5
	for i in sections.size():
		if sections[i]["broken"] or (sections[i]["cols"] as Array).size() < 2:
			continue
		var d := absf(section_center(i).x - want)
		if d < best_d:
			best_d = d
			best = i
	return best


## Once the companies are on the field: a mantlet for every bow company of the stormers.
func on_spawned() -> void:
	if not attack_kit.has(MANTLETS):
		return
	for sq in sim.squads:
		if sq.team != attacker or not bool(sq.stats["ranged"]):
			continue
		var m = _add(MANTLETS, attacker, sq.center + Vector2(0.0, -outward() * 36.0))
		m.owner = sq


## Where a company crewing engine `e` stands: just behind it (behind the middle of the
## battery, for stone throwers standing together).
func crew_post(e) -> Vector2:
	match e.kind:
		TOWER:
			return e.pos + Vector2(0.0, outward() * 68.0)
		YARD, BOLT:
			return e.pos + Vector2(0.0, sim.inward() * 48.0)
		THROWER:
			var sum := Vector2.ZERO
			var n := 0
			for o in engines:
				if o.kind == THROWER and o.team == e.team and o.working():
					sum += o.pos
					n += 1
			if n > 0:
				return sum / float(n) + Vector2(0.0, outward() * 76.0)
	return e.pos + Vector2(0.0, outward() * 60.0)


## Whether `e` has its crew, or a company on its way to it.
func manned(e) -> bool:
	if e.crewed():
		return true
	for sq in sim.squads:
		if sq.crew_of == e and sq.is_active():
			return true
	return false


## The engines `team` crews, other than the ram, mantlets and fixed works on the walk.
func crewable(team: int) -> Array:
	return engines.filter(func(e): return e.team == team and e.working() and e.kind in [THROWER, TOWER, YARD])


# ---------------------------------------------------------------- the step

func step(dt: float) -> void:
	for e in engines:
		if e.burnt:
			continue
		e.crew = _crew_at(e)
		if e.kind == MANTLETS and e.owner != null:
			_follow_owner(e, dt)
		elif e.kind == RAM:
			e.crew = int(sim.gate_blows)
		_hacked(e, dt)
		if e.burning > 0.0:
			e.hp -= BURN_DPS * dt
			e.burning -= dt * (2.0 if e.crew >= CREW_MIN else 1.0)
			if e.burning <= 0.0:
				e.burning = 0.0
				sim.events.append({"type": "engine_fire_out", "engine": e})
		if e.hp <= 0.0:
			_destroyed(e)
			continue
		match e.kind:
			THROWER, YARD:
				_work_thrower(e, dt)
			BOLT:
				_work_bolt(e, dt)
			TOWER:
				_work_tower(e, dt)
	if wall_kit.has(OIL):
		_pour_oil(dt)
	_fly(dt)
	_burn_ground(dt)
	_fire_arrows(dt)
	_sallies()


func _crew_at(e) -> int:
	if e.kind == BOLT:
		# Bolt throwers are worked by whoever holds the walk beside them.
		return _men_near(e.pos, e.team, CREW_REACH + 20.0, false)
	if e.kind == TOWER:
		return _men_near(e.pos, e.team, CREW_REACH, true)
	if e.kind in [THROWER, YARD]:
		# Anyone can haul on a thrower's ropes, horsemen too.
		return _men_near(e.pos, e.team, CREW_REACH, false)
	return 0


## How many of `team`'s men (on foot if `foot_only`) stand within `r` of `p`.
func _men_near(p: Vector2, team: int, r: float, foot_only: bool) -> int:
	var n := 0
	for so in sim._nearby(p, r):
		var sq = so.squad
		if sq.team != team or sq.routing or (foot_only and sq.type == Troops.CAVALRY):
			continue
		if so.pos.distance_squared_to(p) <= r * r:
			n += 1
	return n


## A mantlet goes where its bows stand, on their side toward the wall.
func _follow_owner(e, dt: float) -> void:
	var sq = e.owner
	if sq == null or not sq.is_active():
		return
	var want: Vector2 = sq.center + Vector2(0.0, -outward() * 36.0)
	e.pos = e.pos.move_toward(want, 60.0 * dt)


## Enemy men standing at an engine with nothing better to do hack at it, and may set it
## alight.
func _hacked(e, dt: float) -> void:
	if e.kind == RAM:
		return
	var n := 0
	for so in sim._nearby(e.pos, HACK_REACH):
		var sq = so.squad
		if sq.team == e.team or sq.routing or sq.ranged or (so.target != null and so.target.alive):
			continue
		if so.pos.distance_squared_to(e.pos) <= HACK_REACH * HACK_REACH:
			n += 1
	if n == 0:
		return
	e.hp -= HACK_DPS * float(n) * dt
	if e.burning <= 0.0 and sim.rng.randf() < 1.0 - pow(1.0 - HACK_FIRE * dt, float(n)):
		ignite(e)


func ignite(e) -> void:
	if e.burnt:
		return
	var was: bool = e.burning > 0.0
	e.burning = BURN_TIME
	if not was:
		sim.events.append({"type": "engine_burning", "engine": e})


func _destroyed(e) -> void:
	e.burnt = true
	e.hp = 0.0
	e.burning = 0.0
	burned[e.team] += 1
	if e.kind == TOWER and e.docked:
		_undock(e)
	sim.events.append({"type": "engine_lost", "engine": e})
	sim._log_siege("engine_lost_%d" % e.team, null)


# ---------------------------------------------------------------- throwers

func reload_of(e) -> float:
	return float(land_of(e.team)["reload"]) if e.kind in [THROWER, YARD] else BOLT_RELOAD


func _work_thrower(e, dt: float) -> void:
	if e.burning > 0.0 and e.crewed():
		return
	var r: float = e.rate()
	if r <= 0.0:
		return
	e.reload -= dt * r
	if e.reload > 0.0:
		return
	var aim := _throw_target(e)
	if aim.is_empty():
		e.reload = 1.0
		return
	e.reload = reload_of(e)
	var to: Vector2 = aim["at"]
	var dist: float = e.pos.distance_to(to)
	var spread := THROW_SCATTER + THROW_SCATTER_PER * dist
	var dir := Vector2(sim.rng.randf_range(-1.0, 1.0), sim.rng.randf_range(-1.0, 1.0)).normalized()
	var land: Vector2 = to + dir * sim.rng.randf_range(0.0, spread)
	shots.append({"kind": "stone", "team": e.team, "from": e.pos, "to": land, "t": 0.0, "flight": THROW_FLIGHT,
		"source": e, "aim": aim, "naphtha": bool(land_of(e.team).get("naphtha", false)) and e.kind == THROWER})
	e.shots += 1
	stones[e.team] += 1
	sim.events.append({"type": "engine_throw", "engine": e})


## Where a thrower aims now: {at, kind, ref}, or {} when nothing it may aim at is in range.
func _throw_target(e) -> Dictionary:
	var aim: Dictionary = e.aim
	match String(aim.get("kind", "auto")):
		"section":
			var i := int(aim["ref"])
			if i >= 0 and i < sections.size() and not sections[i]["broken"] and _in_throw(e, section_center(i)):
				return {"at": section_center(i), "kind": "section", "ref": i}
		"gate":
			if sim.gate_hp > 0.0 and _in_throw(e, sim.gate_center):
				return {"at": sim.gate_center, "kind": "gate"}
		"engine":
			var t = aim.get("ref")
			if t != null and t.working() and _in_throw(e, t.pos):
				return {"at": t.pos, "kind": "engine", "ref": t}
		"squad":
			var sq = aim.get("ref")
			if sq != null and sq.is_active() and _in_throw(e, sq.avg):
				return {"at": sq.avg, "kind": "squad", "ref": sq}
	return _auto_throw(e)


func _in_throw(e, p: Vector2) -> bool:
	return e.pos.distance_to(p) <= (YARD_RANGE if e.kind == YARD else THROW_RANGE)


## A thrower left to itself: the stormers' answer the walls' own thrower first, then keep
## at the weakest section still standing (finish a breach), then the gate; the walls' go
## for the stormers' engines, then their thickest press near the wall.
func _auto_throw(e) -> Dictionary:
	var enemy_engines := engines.filter(func(o): return o.team != e.team and o.working() and o.kind in [THROWER, YARD, TOWER] and _in_throw(e, o.pos))
	if e.team == attacker:
		for o in enemy_engines:
			if o.kind == YARD:
				return {"at": o.pos, "kind": "engine", "ref": o}
		# A breach made: stones on the garrison massed to meet it, never where their own
		# men are close.
		if any_breach():
			var mass = _mass_clear_of_friends(e)
			if mass != null:
				return {"at": mass.avg, "kind": "squad", "ref": mass}
		var best := -1
		var best_hp := INF
		for i in sections.size():
			if sections[i]["broken"] or not _in_throw(e, section_center(i)):
				continue
			# Near the gate is where the men are going: keep the breach near them.
			var score: float = float(sections[i]["hp"]) + absf(section_center(i).x - sim.gate_center.x) * 0.8
			if score < best_hp:
				best_hp = score
				best = i
		if best >= 0:
			return {"at": section_center(best), "kind": "section", "ref": best}
		if sim.gate_hp > 0.0 and _in_throw(e, sim.gate_center):
			return {"at": sim.gate_center, "kind": "gate"}
		return {}
	enemy_engines.sort_custom(func(a, b): return _engine_threat(a) > _engine_threat(b))
	if not enemy_engines.is_empty():
		var o = enemy_engines[0]
		return {"at": o.pos, "kind": "engine", "ref": o}
	var best_sq = null
	var best_n := 0
	for sq in sim.squads:
		if sq.team == e.team or not sq.is_active() or sim.inside_walls(sq.avg) or not _in_throw(e, sq.avg):
			continue
		if sq.alive_n > best_n:
			best_n = sq.alive_n
			best_sq = sq
	if best_sq != null:
		return {"at": best_sq.avg, "kind": "squad", "ref": best_sq}
	return {}


## The enemy company with the most men that `e` can reach and its own side has nobody
## within FRIENDLY_CLEAR of, or null.
func _mass_clear_of_friends(e):
	var best = null
	var best_n := 0
	for sq in sim.squads:
		if sq.team == e.team or not sq.is_active() or not _in_throw(e, sq.avg) or sq.alive_n <= best_n:
			continue
		if sim._fighters_near(sq.avg, e.team, FRIENDLY_CLEAR):
			continue
		best_n = sq.alive_n
		best = sq
	return best


## Which of the stormers' engines the walls fear most.
func _engine_threat(o) -> float:
	match o.kind:
		TOWER:
			return 3.0 + (2.0 if o.moving else 0.0)
		THROWER:
			return 2.0
		YARD:
			return 1.5
	return 1.0


## Stones and bolts in the air land.
func _fly(dt: float) -> void:
	for s in shots:
		s["t"] = float(s["t"]) + dt
		if float(s["t"]) >= float(s["flight"]):
			s["done"] = true
			if s["kind"] == "stone":
				_stone_lands(s)
			elif s["kind"] == "bolt":
				_bolt_lands(s)
	shots = shots.filter(func(s): return not s.get("done", false))


func _stone_lands(s: Dictionary) -> void:
	var p: Vector2 = s["to"]
	var team: int = s["team"]
	var src = s["source"]
	var land: Dictionary = land_of(team)
	sim.events.append({"type": "stone_lands", "at": p, "team": team})
	# The wall.
	if absf(p.y - sim.wall_y) <= 24.0:
		var cx := int(p.x / Terrain.CELL)
		if sim.GATE_COLS.has(cx) and sim.gate_hp > 0.0:
			sim.gate_hp = maxf(0.0, sim.gate_hp - GATE_HIT * float(land["wall"]))
			sim.events.append({"type": "gate_hit", "at": p})
			if sim.gate_hp <= 0.0:
				sim._gate_gives()
		else:
			var i := section_at(cx)
			if i >= 0 and not sections[i]["broken"]:
				sections[i]["hp"] = float(sections[i]["hp"]) - WALL_HIT * float(land["wall"])
				sim.events.append({"type": "wall_hit", "at": p, "section": i})
				if sections[i]["hp"] <= 0.0:
					_break_section(i)
	# Men.
	var shaken := {}
	for so in sim._nearby(p, SPLASH_RADIUS + 8.0):
		if not so.alive or so.pos.distance_to(p) > SPLASH_RADIUS + so.radius:
			continue
		sim._damage(so, STONE_SPLASH, src_squad(src), false, null)
		if not so.alive:
			engine_kills[team] += 1
		shaken[so.squad] = true
	for sq in shaken:
		sq.drop_morale(STONE_SHOCK)
	# Engines.
	for e in engines:
		if e.working() and e != src and e.pos.distance_to(p) <= ENGINE_HIT_REACH:
			e.hp -= ENGINE_HIT
			if bool(s.get("naphtha", false)):
				ignite(e)
	if bool(s.get("naphtha", false)):
		flames.append({"pos": p, "left": NAPHTHA_TIME, "team": team})


## The company an engine's kills are credited to: its crew's, if it has one.
func src_squad(e):
	if e == null:
		return null
	return e.crew_squad


func _burn_ground(dt: float) -> void:
	for f in flames:
		f["left"] = float(f["left"]) - dt
		var p: Vector2 = f["pos"]
		for so in sim._nearby(p, NAPHTHA_RADIUS + 6.0):
			if so.alive and so.pos.distance_to(p) <= NAPHTHA_RADIUS:
				sim._damage(so, NAPHTHA_DPS * dt, null)
	flames = flames.filter(func(f): return float(f["left"]) > 0.0)


# ---------------------------------------------------------------- the tower

func _work_tower(e, dt: float) -> void:
	if e.docked or not e.moving:
		return
	if e.burning > 0.0 and e.crewed():
		return
	var r: float = e.rate()
	if r <= 0.0:
		return
	e.pos = e.pos.move_toward(e.home, TOWER_PACE * r * dt)
	if e.pos.distance_to(e.home) < 1.0:
		_dock(e)


## The tower is at the wall: its bridge is a way onto the walk, two men wide.
func _dock(e) -> void:
	e.docked = true
	e.moving = false
	var sec: Dictionary = sections[e.section]
	var cols: Array = sec["cols"]
	var bridge: Array = cols.slice(0, 2) if cols.size() >= 2 else cols
	e.set_meta("bridge", bridge)
	for cx in bridge:
		crossing[cx] = TOWER_CLIMB
		var idx: int = sim.wall_row * Terrain.COLS + int(cx)
		sim.terrain.rock[idx] = Terrain.ROCK_NONE
		sim.terrain.foot_speed[idx] = TOWER_CLIMB
		sim.terrain.horse_speed[idx] = 0.0
		sim._foot[idx] = TOWER_CLIMB
		sim._horse[idx] = 0.0
	sim.events.append({"type": "tower_docked", "engine": e})
	sim._log_siege("tower", null)


## A burnt tower's bridge falls: the wall is whole there again.
func _undock(e) -> void:
	var bridge: Array = e.get_meta("bridge", [])
	for cx in bridge:
		if crossing.get(cx, 0.0) != TOWER_CLIMB:
			continue
		crossing.erase(cx)
		var idx: int = sim.wall_row * Terrain.COLS + int(cx)
		sim.terrain.rock[idx] = Terrain.ROCK_BLOCKED
		sim.terrain.foot_speed[idx] = 0.0
		sim.terrain.horse_speed[idx] = 0.0
		sim._foot[idx] = 0.0
		sim._horse[idx] = 0.0
	e.docked = false


## The tower rolls when the stormers go.
func roll_tower(team: int) -> void:
	for e in engines:
		if e.kind == TOWER and e.team == team and e.working() and not e.docked:
			e.moving = true


func tower_of(team: int):
	for e in engines:
		if e.kind == TOWER and e.team == team and e.working():
			return e
	return null


## The points where `team`'s foot cross by the tower's bridge (empty until it docks).
func tower_bridge_x() -> Array:
	var out := []
	for e in engines:
		if e.kind == TOWER and e.docked and e.working():
			for cx in e.get_meta("bridge", []):
				out.append((float(cx) + 0.5) * Terrain.CELL)
	return out


# ---------------------------------------------------------------- the walls' engines

func _work_bolt(e, dt: float) -> void:
	if e.burning > 0.0 and e.crewed():
		return
	var r: float = e.rate()
	if r <= 0.0:
		return
	e.reload -= dt * r
	if e.reload > 0.0:
		return
	var target = _bolt_target(e)
	if target == null:
		e.reload = 0.5
		return
	e.reload = BOLT_RELOAD * (BOLT_FAST if count(BOLT, e.team) >= 3 else 1.0)
	var to: Vector2 = target.pos
	var dist: float = e.pos.distance_to(to)
	# Far off, a bolt may miss: it strikes the ground beside its mark.
	if sim.rng.randf() > bolt_hit_chance(dist):
		to += Vector2(sim.rng.randf_range(-1.0, 1.0), sim.rng.randf_range(-1.0, 1.0)).normalized() * sim.rng.randf_range(14.0, 34.0)
		target = null
	shots.append({"kind": "bolt", "team": e.team, "from": e.pos, "to": to, "t": 0.0, "flight": BOLT_FLIGHT + dist * BOLT_PACE,
		"source": e, "target": target})
	e.shots += 1
	bolts[e.team] += 1
	sim.events.append({"type": "engine_bolt", "engine": e})


## The chance a bolt loosed at a mark `dist` away hits it.
static func bolt_hit_chance(dist: float) -> float:
	if dist <= BOLT_SURE:
		return 1.0
	return lerpf(1.0, BOLT_FAR_HIT, clampf((dist - BOLT_SURE) / (BOLT_RANGE - BOLT_SURE), 0.0, 1.0))


## A bolt thrower's mark: what it's been aimed at, else the stormers' engines near enough
## to matter (the tower first, and a rolling tower anywhere in range), else the nearest man
## in range who isn't at the foot of the wall, else any engine in range.
func _bolt_target(e):
	var aim: Dictionary = e.aim
	if String(aim.get("kind", "auto")) == "engine":
		var t = aim.get("ref")
		if t != null and t.working() and e.pos.distance_to(t.pos) <= BOLT_RANGE:
			return t
	if String(aim.get("kind", "auto")) == "squad":
		var sq = aim.get("ref")
		if sq != null and sq.is_active():
			var man = _nearest_man(sq, e.pos, true)
			if man != null and e.pos.distance_to(man.pos) <= BOLT_RANGE:
				return man
	var best_engine = null
	var best_t := 0.0
	var far_engine = null
	for o in engines:
		if o.team == e.team or not o.working() or o.kind in [RAM, MANTLETS] or e.pos.distance_to(o.pos) > BOLT_RANGE:
			continue
		if e.pos.distance_to(o.pos) > BOLT_ENGINE_REACH and not (o.kind == TOWER and o.moving):
			far_engine = o
			continue
		var t := _engine_threat(o)
		if t > best_t:
			best_t = t
			best_engine = o
	if best_engine != null:
		return best_engine
	var best = null
	var best_d := BOLT_RANGE * BOLT_RANGE
	for sq in sim.squads:
		if sq.team == e.team or not sq.is_active():
			continue
		for so in sq.soldiers:
			if not so.alive or sim.inside_walls(so.pos) or under_bolts(so.pos):
				continue
			var d: float = e.pos.distance_squared_to(so.pos)
			if d < best_d:
				best_d = d
				best = so
	return best if best != null else far_engine


## Whether `at` is dead ground to the wall's bolt throwers: at the foot of the wall.
func under_bolts(at: Vector2) -> bool:
	return absf(at.y - sim.wall_y) < BOLT_DEAD


## The man of `sq` nearest `from` (with `bolt_mark`, only one a bolt thrower can aim at).
func _nearest_man(sq, from: Vector2, bolt_mark: bool = false):
	var best = null
	var best_d := INF
	for so in sq.soldiers:
		if so.alive and not (bolt_mark and (sim.inside_walls(so.pos) or under_bolts(so.pos))):
			var d: float = from.distance_squared_to(so.pos)
			if d < best_d:
				best_d = d
				best = so
	return best


func _bolt_lands(s: Dictionary) -> void:
	var target = s["target"]
	var team: int = s["team"]
	if target == null:
		sim.events.append({"type": "bolt_miss", "at": s["to"]})
		return
	if target is SiegeEngine:
		if target.working():
			target.hp -= BOLT_ENGINE
		return
	if target == null or not target.alive:
		return
	var from: Vector2 = s["from"]
	var dir: Vector2 = (target.pos - from).normalized()
	var hit_at: Vector2 = target.pos
	sim._damage(target, BOLT_DAMAGE, src_squad(s["source"]), false, null)
	if not target.alive:
		engine_kills[team] += 1
	# It goes through, into the man behind.
	var behind = null
	var best := 22.0 * 22.0
	for so in sim._nearby(hit_at + dir * 14.0, 22.0):
		if so == target or not so.alive or so.squad.team == team:
			continue
		var d: float = so.pos.distance_squared_to(hit_at + dir * 14.0)
		if d < best:
			best = d
			behind = so
	if behind != null:
		sim._damage(behind, BOLT_BEHIND, src_squad(s["source"]), false, null)
		if not behind.alive:
			engine_kills[team] += 1


## Oil over the gate: a pour every OIL_EVERY while men work at the gate and the garrison
## has foot on the gate tower to tip it.
func _pour_oil(dt: float) -> void:
	if sim.gate_hp <= 0.0:
		return
	_oil_clock += dt
	if _oil_clock < OIL_EVERY:
		return
	var tippers := 0
	for sq in sim.squads:
		if sq.team != defender or not sq.is_active() or sq.ranged or sq.type == Troops.CAVALRY:
			continue
		for so in sq.soldiers:
			if so.alive and sim.on_gate_tower(so.pos):
				tippers += 1
	if tippers == 0 or sim.gate_blows <= 0.0:
		return
	_oil_clock = 0.0
	pours += 1
	var at: Array = []
	for sq in sim.squads:
		if sq.team == defender or not sq.is_active():
			continue
		for so in sq.soldiers:
			if so.alive and so.pos.distance_to(sim.gate_center) <= sim.GATE_REACH + 10.0:
				at.append(so.pos)
				sim._damage(so, OIL_DAMAGE, null)
				if not so.alive:
					engine_kills[defender] += 1
	var r = ram()
	if r != null:
		ignite(r)
	sim.events.append({"type": "oil", "at": at})
	if pours == 1:
		sim._log_siege("oil", null)


## Bows told to burn an engine shoot fire at it, not at men: a volley every cooldown.
func _fire_arrows(dt: float) -> void:
	for sq in sim.squads:
		if sq.burn_target == null or not sq.is_active() or not sq.ranged:
			continue
		var e = sq.burn_target
		if not e.working():
			sq.burn_target = null
			continue
		if sq.avg.distance_to(e.pos) > FIRE_RANGE:
			continue
		sq.burn_clock -= dt
		if sq.burn_clock > 0.0:
			continue
		sq.burn_clock = sq.cooldown
		var hits := int(round(float(sq.alive_n) * FIRE_HITS))
		var odds: float = FIRE_ODDS * (5.0 / 3.0 if bool(land_of(sq.team).get("fire_pots", false)) else 1.0)
		e.hp -= float(hits) * sq.damage * ARROW_ON_WOOD
		if sim.rng.randf() < 1.0 - pow(1.0 - odds, float(hits)):
			ignite(e)
		if sq.arrows > 0:
			sq.arrows = maxi(0, sq.arrows - 1)
		sim.events.append({"type": "fire_arrows", "squad": sq, "engine": e})


# ---------------------------------------------------------------- the postern

## Inside and outside the postern.
func postern_points() -> Array:
	var x := (float(POSTERN_COL) + 0.5) * Terrain.CELL
	return [Vector2(x, sim.wall_y + sim.inward() * POSTERN_STEP), Vector2(x, sim.wall_y + outward() * POSTERN_STEP)]


func has_postern() -> bool:
	return wall_kit.has(POSTERN)


## A company sallies by the postern at `e`: out, at it, and back in.
func order_sally(sq, e) -> bool:
	if not has_postern() or sq.team != defender or e == null or not e.working() or sq.ranged:
		return false
	sq.sally_target = e
	sq.sally_phase = "out"
	sq.sally_home = sq.center
	sim.order_move(sq, postern_points()[0])
	sim.events.append({"type": "sally_out", "squad": sq, "engine": e})
	return true


func _sallies() -> void:
	if not has_postern():
		return
	var pts := postern_points()
	for sq in sim.squads:
		if sq.sally_phase == "" or not sq.is_active():
			continue
		var e = sq.sally_target
		match sq.sally_phase:
			"out":
				if sq.center.distance_to(pts[0]) < 18.0:
					_through(sq, pts[1])
					sq.sally_phase = "hit"
			"hit":
				var spent: bool = e == null or not e.working() or sq.alive_n * 2 < sq.start_men
				if spent:
					sq.sally_phase = "back"
					sim.order_move(sq, pts[1])
				elif sq.order != "move" or sq.order_point.distance_to(e.pos) > 4.0:
					if not sq.engaged:
						sim.order_move(sq, e.pos)
			"back":
				if sq.center.distance_to(pts[1]) < 18.0:
					_through(sq, pts[0])
					sq.sally_phase = ""
					sq.sally_target = null
					sim.order_move(sq, sq.sally_home)
				elif sq.order != "move" and not sq.engaged:
					sim.order_move(sq, pts[1])


## The company files through the little door to `to`.
func _through(sq, to: Vector2) -> void:
	var shift: Vector2 = to - sq.center
	for so in sq.soldiers:
		if so.alive:
			so.pos = to + (so.pos - sq.center).limit_length(20.0)
	sq.center += shift
	sq.goal = sq.center
	sq.waypoints.clear()


# ---------------------------------------------------------------- cover

## What's left of an arrow that hits `victim`, from engines: behind a mantlet, in the
## tower, at an engine's timbers.
func arrow_cover(victim) -> float:
	var sq = victim.squad
	if sq.team == attacker:
		for e in engines:
			if not e.working():
				continue
			if e.kind == TOWER and not e.docked and victim.pos.distance_to(e.pos) <= 64.0 and _behind(victim.pos, e.pos):
				return TOWER_COVER
			# Screens along its front cover the company standing behind them (bamboo bundles
			# move with it).
			if e.kind == MANTLETS and e.owner == sq and (sq.still > 0.5 or bool(LANDS[e.land].get("bamboo", false))):
				return MANTLET_COVER
	for e in engines:
		if e.working() and e.team == sq.team and e.kind in [THROWER, YARD, BOLT] and victim.pos.distance_to(e.pos) <= CREW_REACH:
			return ENGINE_COVER
	return 1.0


## Whether `p` is behind `at` from the wall's side (sheltered by what stands at `at`).
func _behind(p: Vector2, at: Vector2) -> bool:
	return (p.y - at.y) * outward() > -6.0


## What's left of an arrow for a defender on the walk: crenellations, or a yagura.
func walk_arrows() -> float:
	return YAGURA_ARROWS if bool(LANDS[wall_land].get("yagura", false)) else sim.WALL_ARROWS


## Whether arrows at the men at the gate fall on a roof (a ram's).
func ram_roof() -> bool:
	return ram() != null


## Ryumon logs: a held ladder head throws men down twice as hard.
func thrown_down() -> float:
	return sim.THROWN_DOWN * (2.0 if bool(LANDS[wall_land].get("logs", false)) else 1.0)


## Bamboo shields let bows stand nearer: share of their reach they stand off at.
func stand_off_share() -> float:
	return 0.7 if attack_kit.has(MANTLETS) and bool(LANDS[attack_land].get("bamboo", false)) else 0.85


# ---------------------------------------------------------------- for the result

## What the campaign keeps: the wall's state, which engines each side has left, tallies.
func result() -> Dictionary:
	var left := {"attacker": [], "defender": []}
	for e in engines:
		if e.working():
			(left["attacker" if e.team == attacker else "defender"] as Array).append(e.kind)
	return {"gate": snappedf(sim.gate_hp / maxf(1.0, sim.gate_max), 0.01), "cols": col_state(),
		"engines_left": left, "stones": stones.duplicate(), "bolts": bolts.duplicate(),
		"sections_broken": sections_broken, "burned": burned.duplicate(), "pours": pours,
		"engine_kills": engine_kills.duplicate()}
