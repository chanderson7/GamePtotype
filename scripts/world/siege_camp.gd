## Laying siege on campaign. A company that camps at enemy walls builds engines there
## (each with its hours and silver; more men build faster), throwers knock at the walls
## each day, and the garrison may sally at night to burn what's been built. The walls have
## works of their own by their kind, their land and what their holder paid for; damage done
## to them stays until it's mended. The battle reads all of it as BattleSim.siege_engines
## (battle_config); auto-resolve as a wall multiplier composed from it (walls).
extends RefCounted

const WorldData = preload("res://scripts/world/world_data.gd")
const SiegeWorks = preload("res://scripts/battle/siege_works.gd")
const Lords = preload("res://scripts/data/lords.gd")
const Fiefs = preload("res://scripts/data/fiefs.gd")

## What a besieger can build: hours for BUILD_MEN men, silver, how many at most, and what
## it needs first. Ladders are lashed together on arrival.
const BUILD := {
	"ram": {"hours": 16.0, "silver": 60, "max": 1, "name": "Ram",
		"blurb": "A roofed ram: the gate falls about three times as fast as to axes, and the roof keeps off most arrows."},
	"mantlets": {"hours": 8.0, "silver": 40, "max": 1, "name": "Mantlets",
		"blurb": "Wooden screens for your bows: half the arrows from the wall stop in them."},
	"more_ladders": {"hours": 6.0, "silver": 0, "max": 1, "name": "More ladders",
		"blurb": "Four ladders against the wall, not two."},
	"tower": {"hours": 40.0, "silver": 160, "max": 1, "name": "Siege tower",
		"blurb": "Pushed to the wall when you storm, it lays a bridge onto the walk two men wide. It burns."},
	"thrower": {"hours": 30.0, "silver": 120, "max": 2, "name": "Stone thrower",
		"blurb": "Knocks sections of the wall down from beyond bowshot, and every day you camp it knocks at them."},
}
## The order they're offered in.
const ORDER := ["ram", "mantlets", "more_ladders", "tower", "thrower"]
const BUILD_MEN := 60.0
const BUILD_FASTEST := 0.5
const BUILD_SLOWEST := 2.0
## Ryumon's hand-hauled thrower is lighter.
const LIGHT_THROWER := {"hours": 20.0, "silver": 80}

## Each day a thrower stands in a camp it takes this share off a stretch of wall, and kills
## a man or few on it.
const BOMBARD_HIT := 0.25
const BOMBARD_KILLS := Vector2i(0, 2)
## The stretches of wall a bombardment works at, by column (either side of the gate).
const BOMBARD_SPANS := [[10, 11, 12], [15, 16, 17]]
## A garrison sallies at a camp on a night with this chance (more for a big garrison).
const NIGHT_SALLY := 0.15
## Damage mends at this share a day (the gate in two days, a stretch of wall in four);
## paying hurries it all at once.
const REPAIR_GATE := 0.5
const REPAIR_WALL := 0.25
const REPAIR_COST := 120

## The works every walled place keeps, and what its kind and seat add.
const WORKS_BASE := ["bolt", "bolt", "postern"]

## The wall multiplier auto-resolve uses, composed (see walls()).
const WALLS_BASE := {"castle": 1.6, "town": 1.4}
const WALLS_MIN := 1.0
const WALLS_MAX := 2.2


# ---------------------------------------------------------------- what's built, and what it costs

static func land_of(culture: String) -> Dictionary:
	return SiegeWorks.LANDS.get(culture, SiegeWorks.LANDS["vardish"])


## An engine's name in `culture`'s way ("trebuchet" for a Vardish stone thrower).
static func engine_name(kind: String, culture: String) -> String:
	if kind == "thrower":
		return String(land_of(culture)["thrower"]).capitalize()
	if kind == "mantlets" and culture == "ryumon":
		return "Bamboo shields"
	return String(BUILD.get(kind, {}).get("name", kind))


## {hours, silver} for `kind`, by `culture`, for BUILD_MEN men.
static func cost(kind: String, culture: String) -> Dictionary:
	var b: Dictionary = BUILD.get(kind, {})
	if kind == "thrower" and culture == "ryumon":
		return LIGHT_THROWER.duplicate()
	return {"hours": float(b.get("hours", 0.0)), "silver": int(b.get("silver", 0))}


## Hours to build `kind` with `men` at it.
static func build_hours(kind: String, culture: String, men: int) -> float:
	var factor := clampf(BUILD_MEN / float(maxi(1, men)), BUILD_FASTEST, BUILD_SLOWEST)
	return float(cost(kind, culture)["hours"]) * factor


## What a marshal army storms with when nothing else is known.
const DEFAULT_ARMY_KIT := ["ladders", "ram"]


## What a marshal army builds before it storms, by its size and the walls.
static func army_kit(men: int, kind: String) -> Array:
	var kit := ["ladders", "ram"]
	if men > 150:
		kit.append("thrower")
	if men > 250:
		kit.append("thrower")
	if kind == "castle" and men > 200:
		kit.append("tower")
	return kit


## How long an army of `men` takes over its whole kit (they build it all at once).
static func army_prep_hours(kit: Array, culture: String, men: int) -> float:
	var hours: float = Lords.SIEGE_PREP_HOURS
	for k in kit:
		if BUILD.has(k):
			hours = maxf(hours, build_hours(String(k), culture, men))
	return hours


# ---------------------------------------------------------------- the walls' works and damage

## What `id`'s walls keep: bolt throwers and a postern everywhere, oil over a castle's gate,
## a stone thrower in a capital's courtyard, and what a holder paid for.
static func defences(world, id: String, improvements: Dictionary = {}) -> Array:
	var kind := String(WorldData.settlement(id).get("type", ""))
	if not WALLS_BASE.has(kind):
		return []
	var out: Array = WORKS_BASE.duplicate()
	if kind == "castle":
		out.append("oil")
	var capital := false
	if world != null:
		for realm in world.realms:
			if String(world.capital_of(realm)) == id:
				capital = true
	if capital:
		out.append("yard_thrower")
	if bool(improvements.get(Fiefs.IMPROVEMENT_SIEGE_WORKS, false)):
		if not out.has("oil"):
			out.append("oil")
		if not out.has("yard_thrower"):
			out.append("yard_thrower")
	if bool(improvements.get(Fiefs.IMPROVEMENT_TOWER_BOLTS, false)):
		out.append("bolt")
	return out


## The damage `id`'s walls carry: {gate: share left, cols: {column: share left}}.
static func damage(world, id: String) -> Dictionary:
	if world == null:
		return {}
	return (world.siege_damage.get(id, {}) as Dictionary).duplicate(true)


## Keep what a battle (or a bombardment) did to `id`'s walls.
static func set_damage(world, id: String, gate: float, cols: Dictionary) -> void:
	if world == null:
		return
	var d := {"gate": clampf(gate, 0.0, 1.0), "cols": {}}
	for k in cols:
		var v := clampf(float(cols[k]), 0.0, 1.0)
		if v < 0.999:
			d["cols"][str(k)] = v
	if d["gate"] >= 0.999 and (d["cols"] as Dictionary).is_empty():
		world.siege_damage.erase(id)
	else:
		world.siege_damage[id] = d


## Whether anything at `id` is broken: the gate or a stretch of wall down.
static func breached(world, id: String) -> bool:
	var d := damage(world, id)
	if d.is_empty():
		return false
	if float(d.get("gate", 1.0)) <= 0.0:
		return true
	for k in d.get("cols", {}):
		if float(d["cols"][k]) <= 0.0:
			return true
	return false


## The share of a stretch of wall left at `id`, the weakest of it (1 when whole).
static func weakest_wall(world, id: String) -> float:
	var d := damage(world, id)
	var low := 1.0
	for k in d.get("cols", {}):
		low = minf(low, float(d["cols"][k]))
	return low


## The wall multiplier auto-resolve settles an assault with: the place's walls, more for
## its works, more again with no ram against its gate, less for each thrower and a tower,
## and less for whatever's already broken.
static func walls(kind: String, works: Array, attacker_kit: Array, dmg: Dictionary = {}) -> float:
	var m := float(WALLS_BASE.get(kind, 1.4))
	m += 0.05 * float(works.count("bolt")) + (0.05 if works.has("oil") else 0.0) + (0.10 if works.has("yard_thrower") else 0.0)
	if not attacker_kit.has("ram"):
		m += 0.25
	m -= 0.10 * float(mini(2, attacker_kit.count("thrower")))
	if attacker_kit.has("tower"):
		m -= 0.15
	if float(dmg.get("gate", 1.0)) <= 0.0:
		m -= 0.30
	var down := 0
	for k in dmg.get("cols", {}):
		if float(dmg["cols"][k]) <= 0.0:
			down += 1
	m -= 0.20 * float(mini(2, int(ceil(down / 3.0))))
	return clampf(m, WALLS_MIN, WALLS_MAX)


## BattleSim.siege_engines for an assault on `id`: what the stormers brought, the walls'
## works, each side's land, and the damage the walls carry.
static func battle_config(world, id: String, attacker_kit: Array, attacker_culture: String, improvements: Dictionary = {}) -> Dictionary:
	return {"attacker": attacker_kit.duplicate(), "defender": defences(world, id, improvements),
		"attacker_land": attacker_culture, "defender_land": WorldData.culture_of(WorldData.settlement(id)["faction"]),
		"damage": damage(world, id)}


## Walls mend, day by day, unless someone is camped before them.
static func mend(world, hours: float, besieged: Array) -> void:
	if world == null:
		return
	for id in world.siege_damage.keys():
		if besieged.has(id):
			continue
		var d: Dictionary = world.siege_damage[id]
		var gate := minf(1.0, float(d.get("gate", 1.0)) + REPAIR_GATE * hours / 24.0)
		var cols := {}
		for k in d.get("cols", {}):
			cols[k] = minf(1.0, float(d["cols"][k]) + REPAIR_WALL * hours / 24.0)
		set_damage(world, String(id), gate, cols)


## A day's bombardment on `id` by `throwers`: a stretch of wall knocked at, a man or two
## on it killed. Returns {cols, kills}.
static func bombard(world, id: String, throwers: int, rng: RandomNumberGenerator) -> Dictionary:
	if throwers <= 0 or world == null:
		return {"cols": 0, "kills": 0}
	var d := damage(world, id)
	var cols: Dictionary = d.get("cols", {})
	var gate := float(d.get("gate", 1.0))
	# Keep at the stretch already weakest; start on one beside the gate.
	var span: Array = BOMBARD_SPANS[rng.randi_range(0, BOMBARD_SPANS.size() - 1)]
	var low := 2.0
	for s in BOMBARD_SPANS:
		var here := 1.0
		for cx in s:
			here = minf(here, float(cols.get(str(cx), 1.0)))
		if here < low:
			low = here
			span = s
	var hit := BOMBARD_HIT * float(throwers)
	for cx in span:
		cols[str(cx)] = maxf(0.0, float(cols.get(str(cx), 1.0)) - hit)
	set_damage(world, id, gate, cols)
	var kills := 0
	for i in throwers:
		kills += rng.randi_range(BOMBARD_KILLS.x, BOMBARD_KILLS.y)
	var garrison: Array = world.garrisons.get(id, [])
	var left := kills
	for sq in garrison:
		if left <= 0:
			break
		var take := mini(left, maxi(0, int(sq["men"]) - 1))
		sq["men"] = int(sq["men"]) - take
		left -= take
	return {"cols": span.size(), "kills": kills - left}


# ---------------------------------------------------------------- the company's camp

## A fresh camp at `id`, begun at `hour`: two ladders, the garrison's food counting down.
static func new_camp(id: String, hour: float) -> Dictionary:
	var kind := String(WorldData.settlement(id).get("type", "castle"))
	return {"place": id, "since": hour, "built": ["ladders"], "building": "", "left": 0.0, "bombard": true,
		"food_until": hour + float(Lords.SIEGE_FOOD_DAYS.get(kind, 5.0)) * 24.0, "day": int(hour / 24.0)}


## Whether `kind` can be built in `camp` now: {ok, reason}.
static func can_build(camp: Dictionary, kind: String, culture: String, silver: int) -> Dictionary:
	if camp.is_empty():
		return {"ok": false, "reason": "Lay siege first."}
	if not BUILD.has(kind):
		return {"ok": false, "reason": "Nothing like that can be built."}
	if String(camp.get("building", "")) != "":
		return {"ok": false, "reason": "Your men are building %s already." % engine_name(String(camp["building"]), culture).to_lower()}
	var built: Array = camp.get("built", [])
	if built.count(kind) >= int(BUILD[kind]["max"]):
		return {"ok": false, "reason": "Built."}
	var c := cost(kind, culture)
	if silver < int(c["silver"]):
		return {"ok": false, "reason": "Needs %d silver." % int(c["silver"])}
	return {"ok": true, "reason": ""}


## The camp's hours pass: what's building gets built. Returns the engine finished, or "".
static func build_step(camp: Dictionary, hours: float) -> String:
	var kind := String(camp.get("building", ""))
	if kind == "":
		return ""
	camp["left"] = float(camp["left"]) - hours
	if float(camp["left"]) > 0.0:
		return ""
	(camp["built"] as Array).append(kind)
	camp["building"] = ""
	camp["left"] = 0.0
	return kind


## What the camp would storm with now.
static func kit(camp: Dictionary) -> Array:
	return (camp.get("built", ["ladders"]) as Array).duplicate()


## After an assault from the camp: the engines that came back stay; the rest are gone.
static func keep_survivors(camp: Dictionary, left: Array) -> void:
	var kept := ["ladders"]
	var pool := left.duplicate()
	for k in camp.get("built", []):
		if k == "ladders" or k == "more_ladders":
			if not kept.has(k):
				kept.append(k)
			continue
		if pool.has(k):
			pool.erase(k)
			kept.append(k)
	camp["built"] = kept
