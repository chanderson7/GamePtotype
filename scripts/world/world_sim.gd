## The world map as pure logic: no nodes, no drawing. The map screen draws it and feeds
## it orders; tests run it headless.
##
## Parties travel along roads between settlements. Time passes only while the player is
## travelling or waiting, and stops the moment a bandit band blocks the road. Bandit
## bands roam the villages of their own realm, and one that is beaten comes back a day
## later.
extends RefCounted

const Data = preload("res://scripts/world/world_data.gd")
const Captains = preload("res://scripts/data/captains.gd")
const Cultures = preload("res://scripts/data/cultures.gd")
const Troops = preload("res://scripts/data/troops.gd")
const Economy = preload("res://scripts/data/economy.gd")

## Map units an hour: the player on land and at sea, bandits on land.
const LAND_SPEED := 40.0
const SEA_SPEED := 25.0
const BANDIT_SPEED := 34.0
## A bandit band this close to the player blocks the road.
const ENCOUNTER_RADIUS := 30.0
## A beaten band is replaced this many hours later.
const RESPAWN_HOURS := 24.0
## Hours a band lingers at a village before moving on.
const BANDIT_WAIT_MIN := 2.0
const BANDIT_WAIT_MAX := 6.0
## After you withdraw from a band, or it beats you, it leaves you alone this long.
const GRACE_HOURS := 2.0
## Hours lost when your warband is beaten and regroups at your capital.
const REGROUP_HOURS := 12.0
## The world moves in steps no longer than this, so nothing slips past an encounter.
const TICK := 0.25
const PLAYER := "player"
const BAND := "bandit"


class Party:
	var id := 0
	var kind := BAND
	var name := ""
	## The realm a bandit band roams.
	var faction := ""
	## The settlement it stands at, or the one it last left.
	var node := ""
	## The settlement it's heading for on the current road, or "" while standing.
	var next := ""
	## Distance covered along the current road.
	var along := 0.0
	## Settlements still to reach after `next`.
	var path: Array = []
	## Hours left to wait where it stands.
	var wait := 0.0
	## A band's fighters, in the battle sim's army format.
	var army: Array = []
	## Until this hour, this band won't block the player's road again.
	var grace_until := -1.0

	func moving() -> bool:
		return next != ""


var rng := RandomNumberGenerator.new()
var hour := 0.0
var culture := Cultures.VARDISH
var parties: Array = []
## Bands waiting to come back: [{faction, at}].
var respawns: Array = []
## What happened since the screen last looked: arrived, waited, encounter, respawn.
var events: Array = []
## The id of the band blocking the player's road, or -1.
var encounter := -1
## Recruits each settlement offers: {settlement id: [{type, culture}]}, and the hour each
## settlement's offers come back after any are taken.
var offers := {}
var offers_back := {}
var _next_id := 1
var _adjacent := {}


# ---------------------------------------------------------------- setup

## A new world: the player's party stands at their culture's capital, and a bandit
## band roams each realm.
func setup(seed_value: int, player_culture: String) -> void:
	rng.seed = seed_value
	culture = player_culture
	_build_roads()
	var p := Party.new()
	p.id = _take_id()
	p.kind = PLAYER
	p.name = "Your warband"
	p.node = Data.capital_of_culture(culture)
	parties.append(p)
	for faction in Data.BANDIT_BANDS:
		_spawn_band(faction)
	for id in Data.SETTLEMENTS:
		offers[id] = _new_offers(id)


func _build_roads() -> void:
	_adjacent = {}
	for id in Data.SETTLEMENTS:
		_adjacent[id] = []
	for r in Data.ROADS:
		_adjacent[r[0]].append([r[1], r[2]])
		_adjacent[r[1]].append([r[0], r[2]])


func _take_id() -> int:
	var id := _next_id
	_next_id += 1
	return id


# ---------------------------------------------------------------- queries

func player() -> Party:
	return parties[0]


func party(id: int) -> Party:
	for p in parties:
		if p.id == id:
			return p
	return null


func bands() -> Array:
	return parties.filter(func(p): return p.kind == BAND)


## Where a party is on the map.
func party_pos(p: Party) -> Vector2:
	var a := Data.pos(p.node)
	if not p.moving():
		return a
	var b := Data.pos(p.next)
	return a.lerp(b, clampf(p.along / maxf(1.0, a.distance_to(b)), 0.0, 1.0))


## The settlement the player stands at, or "" on the road.
func here() -> String:
	var p := player()
	return "" if p.moving() else p.node


func player_in_town() -> bool:
	return here() != "" and Data.settlement(here())["type"] == Data.TOWN


## Where the player is headed, or "" if nowhere.
func destination() -> String:
	var p := player()
	if not p.path.is_empty():
		return String(p.path.back())
	return p.next


## The clock runs while the player travels or waits, unless a band blocks the road.
func busy() -> bool:
	var p := player()
	return encounter == -1 and (p.moving() or p.wait > 0.0)


func is_sea(a: String, b: String) -> bool:
	for n in _adjacent.get(a, []):
		if n[0] == b:
			return bool(n[1])
	return false


func road_length(a: String, b: String) -> float:
	return Data.pos(a).distance_to(Data.pos(b))


func _speed(p: Party, a: String, b: String) -> float:
	if p.kind == BAND:
		return BANDIT_SPEED
	return SEA_SPEED if is_sea(a, b) else LAND_SPEED


## The quickest way from `from` to `to` by road, as the settlements to pass through
## (not counting `from`). Bands keep to the land of their own realm.
func path(from: String, to: String, band_realm: String = "") -> Array:
	if from == to or not _adjacent.has(from) or not _adjacent.has(to):
		return []
	var cost := {from: 0.0}
	var prev := {}
	var open := [from]
	var done := {}
	while not open.is_empty():
		var best := 0
		for i in open.size():
			if cost[open[i]] < cost[open[best]]:
				best = i
		var cur: String = open[best]
		open.remove_at(best)
		if cur == to:
			break
		done[cur] = true
		for n in _adjacent[cur]:
			var nxt: String = n[0]
			if done.has(nxt):
				continue
			if band_realm != "" and (bool(n[1]) or Data.settlement(nxt)["faction"] != band_realm):
				continue
			var speed := BANDIT_SPEED if band_realm != "" else (SEA_SPEED if bool(n[1]) else LAND_SPEED)
			var c: float = cost[cur] + road_length(cur, nxt) / speed
			if not cost.has(nxt) or c < cost[nxt]:
				cost[nxt] = c
				prev[nxt] = cur
				if not open.has(nxt):
					open.append(nxt)
	if not prev.has(to):
		return []
	var out := [to]
	while prev[out[0]] != from:
		out.push_front(prev[out[0]])
	return out


## Hours for the player to ride `route` starting from `from`.
func route_hours(from: String, route: Array) -> float:
	var hours := 0.0
	var a := from
	for b in route:
		hours += road_length(a, b) / (SEA_SPEED if is_sea(a, b) else LAND_SPEED)
		a = b
	return hours


## Hours the player would take to reach `to` from where they are now.
func hours_to(to: String) -> float:
	var p := player()
	if not p.moving():
		return route_hours(p.node, path(p.node, to))
	var onward := (road_length(p.node, p.next) - p.along) / _speed(p, p.node, p.next)
	var back := p.along / _speed(p, p.node, p.next)
	return minf(onward + (route_hours(p.next, path(p.next, to)) if to != p.next else 0.0),
		back + (route_hours(p.node, path(p.node, to)) if to != p.node else 0.0))


# ---------------------------------------------------------------- orders

## Set the player off for `to`. From the middle of a road it turns back if that's quicker.
func travel(to: String) -> bool:
	var p := player()
	if encounter != -1 or not Data.SETTLEMENTS.has(to):
		return false
	p.wait = 0.0
	if p.moving():
		var onward := (road_length(p.node, p.next) - p.along) / _speed(p, p.node, p.next)
		var back := p.along / _speed(p, p.node, p.next)
		var via_next := onward + (route_hours(p.next, path(p.next, to)) if to != p.next else 0.0)
		var via_back := back + (route_hours(p.node, path(p.node, to)) if to != p.node else 0.0)
		if via_back < via_next:
			var length := road_length(p.node, p.next)
			var was := p.node
			p.node = p.next
			p.next = was
			p.along = length - p.along
		p.path = path(p.next, to) if to != p.next else []
		return true
	if to == p.node:
		return false
	var route := path(p.node, to)
	if route.is_empty():
		return false
	p.next = route.pop_front()
	p.along = 0.0
	p.path = route
	return true


## Stand where you are for `hours`.
func wait(hours: float) -> bool:
	var p := player()
	if p.moving() or encounter != -1:
		return false
	p.wait = hours
	return true


# ---------------------------------------------------------------- time

## Let up to `hours` pass. Time only moves while the player travels or waits, and stops
## at an encounter.
func step(hours: float) -> void:
	var left := hours
	while left > 0.000001 and busy():
		var dt := minf(TICK, left)
		left -= dt
		hour += dt
		_move_player(dt)
		for b in bands():
			_move_band(b, dt)
		_respawn()
		_check_encounter()


func _move_player(dt: float) -> void:
	var p := player()
	if p.moving():
		if _move(p, dt):
			events.append({"type": "arrived", "at": p.node})
	elif p.wait > 0.0:
		p.wait = maxf(0.0, p.wait - dt)
		if p.wait <= 0.0:
			events.append({"type": "waited", "at": p.node})


## Move a party along its roads for `dt` hours. True if it reached the end of its path.
func _move(p: Party, dt: float) -> bool:
	var time := dt
	while time > 0.0 and p.moving():
		var speed := _speed(p, p.node, p.next)
		var need := (road_length(p.node, p.next) - p.along) / speed
		if time + 0.000001 < need:
			p.along += speed * time
			return false
		time -= need
		p.node = p.next
		p.along = 0.0
		p.next = "" if p.path.is_empty() else String(p.path.pop_front())
	return not p.moving()


func _move_band(b: Party, dt: float) -> void:
	if b.moving():
		if _move(b, dt):
			b.wait = rng.randf_range(BANDIT_WAIT_MIN, BANDIT_WAIT_MAX)
		return
	if b.wait > 0.0:
		b.wait = maxf(0.0, b.wait - dt)
		return
	var choices: Array = Data.villages_of(b.faction).filter(func(v): return v != b.node)
	if choices.is_empty():
		b.wait = BANDIT_WAIT_MAX
		return
	var route := path(b.node, choices[rng.randi_range(0, choices.size() - 1)], b.faction)
	if route.is_empty():
		b.wait = BANDIT_WAIT_MAX
		return
	b.next = route.pop_front()
	b.along = 0.0
	b.path = route


func _check_encounter() -> void:
	var at := party_pos(player())
	for b in bands():
		if hour >= b.grace_until and party_pos(b).distance_to(at) <= ENCOUNTER_RADIUS:
			encounter = b.id
			events.append({"type": "encounter", "party": b.id})
			return


func _respawn() -> void:
	for r in respawns.duplicate():
		if hour >= float(r["at"]):
			respawns.erase(r)
			_spawn_band(String(r["faction"]))


func _spawn_band(faction: String) -> void:
	for b in bands():
		if b.faction == faction:
			return
	var villages := Data.villages_of(faction)
	var b := Party.new()
	b.id = _take_id()
	b.kind = BAND
	b.faction = faction
	b.name = String(Data.BANDIT_BANDS[faction])
	b.node = villages[rng.randi_range(0, villages.size() - 1)]
	b.wait = rng.randf_range(BANDIT_WAIT_MIN, BANDIT_WAIT_MAX)
	b.grace_until = hour + 1.0
	b.army = _band_army(b.id, Data.culture_of(faction))
	parties.append(b)
	events.append({"type": "respawn", "party": b.id})


## Three to five squads of eight to fourteen men, mostly foot and bows, never more than
## one squad of horse, led by captains of the realm's culture.
func _band_army(band_id: int, band_culture: String) -> Array:
	var out := []
	var taken := []
	var horse := false
	for i in rng.randi_range(3, 5):
		var roll := rng.randf()
		var type := Troops.INFANTRY
		if roll > 0.9 and not horse:
			type = Troops.CAVALRY
			horse = true
		elif roll > 0.7:
			type = Troops.SPEARMEN
		elif roll > 0.4:
			type = Troops.ARCHERS
		var id := 5000 + band_id * 10 + i
		var captain := Captains.make(rng, 900000 + id, type, taken, band_culture)
		taken.append(captain["first"])
		out.append({"id": id, "type": type, "men": rng.randi_range(8, 14), "xp": 0,
			"name": Captains.company_name(captain, type), "captain": captain})
	return out


# ---------------------------------------------------------------- recruits

## Who will join you at `id`: squads of fresh recruits of the settlement's own culture.
## Villages raise foot and bows, castles spears and horse, towns any of them. Offers that
## were taken come back OFFER_REFRESH_HOURS later.
func offers_at(id: String) -> Array:
	if not offers.has(id) or hour >= float(offers_back.get(id, INF)):
		offers[id] = _new_offers(id)
		offers_back.erase(id)
	return offers[id]


func take_offer(id: String, index: int) -> Dictionary:
	var list := offers_at(id)
	if index < 0 or index >= list.size():
		return {}
	var offer: Dictionary = list[index]
	list.remove_at(index)
	if not offers_back.has(id):
		offers_back[id] = hour + Economy.OFFER_REFRESH_HOURS
	return offer


func _new_offers(id: String) -> Array:
	var s := Data.settlement(id)
	var place_culture := Data.culture_of(s["faction"])
	var kinds: Array
	var count: int
	match String(s["type"]):
		Data.VILLAGE:
			kinds = [Troops.INFANTRY, Troops.SPEARMEN, Troops.ARCHERS]
			count = rng.randi_range(1, 2)
		Data.CASTLE:
			kinds = [Troops.SPEARMEN, Troops.CAVALRY]
			count = 1
		_:
			kinds = Troops.ORDER
			count = rng.randi_range(2, 3)
	var out := []
	for i in count:
		out.append({"type": kinds[rng.randi_range(0, kinds.size() - 1)], "culture": place_culture})
	return out


# ---------------------------------------------------------------- encounters

## You beat the band: it's gone, and another rises in its realm a day later. The player
## carries on wherever they were going.
func win_encounter() -> void:
	var b := party(encounter)
	encounter = -1
	if b == null:
		return
	parties.erase(b)
	respawns.append({"faction": b.faction, "at": hour + RESPAWN_HOURS})


## You pull back to the last settlement you passed. The time it takes passes, and the
## band leaves you be for a while.
func withdraw() -> void:
	var b := party(encounter)
	encounter = -1
	var p := player()
	if p.moving():
		hour += p.along / _speed(p, p.node, p.next)
	p.next = ""
	p.along = 0.0
	p.path = []
	p.wait = 0.0
	if b != null:
		b.grace_until = hour + GRACE_HOURS


## The band blocking the road takes its losses: `survivors` maps squad ids to the men
## left ({id: {men}}). A band with nobody left is gone.
func hurt_band(survivors: Dictionary) -> void:
	var b := party(encounter)
	if b == null or survivors.is_empty():
		return
	for sq in b.army:
		var left = survivors.get(int(sq["id"]))
		if left != null:
			sq["men"] = int(left["men"])
	b.army = b.army.filter(func(sq): return int(sq["men"]) > 0)
	if b.army.is_empty():
		parties.erase(b)
		respawns.append({"faction": b.faction, "at": hour + RESPAWN_HOURS})


## The band beat you: the survivors regroup at your culture's capital, half a day later.
func lose_encounter() -> void:
	var b := party(encounter)
	encounter = -1
	var p := player()
	p.node = Data.capital_of_culture(culture)
	p.next = ""
	p.along = 0.0
	p.path = []
	p.wait = 0.0
	hour += REGROUP_HOURS
	if b != null:
		b.grace_until = hour + GRACE_HOURS


# ---------------------------------------------------------------- saving

func to_dict() -> Dictionary:
	var ps := []
	for p in parties:
		ps.append({"id": p.id, "kind": p.kind, "name": p.name, "faction": p.faction, "node": p.node,
			"next": p.next, "along": p.along, "path": p.path.duplicate(), "wait": p.wait,
			"army": p.army.duplicate(true), "grace_until": p.grace_until})
	return {
		"hour": hour, "culture": culture, "encounter": encounter, "next_id": _next_id,
		"seed": str(rng.seed), "state": str(rng.state),
		"respawns": respawns.duplicate(true), "parties": ps,
		"offers": offers.duplicate(true), "offers_back": offers_back.duplicate(),
	}


## Restore a world saved with to_dict(). JSON turns every number into a float, so counts
## and ids come back as ints.
func from_dict(d: Dictionary) -> void:
	_build_roads()
	hour = float(d.get("hour", 0.0))
	culture = String(d.get("culture", Cultures.VARDISH))
	encounter = int(d.get("encounter", -1))
	_next_id = int(d.get("next_id", 1))
	rng.seed = int(String(d.get("seed", "0")))
	rng.state = int(String(d.get("state", "0")))
	offers = {}
	var raw_offers = d.get("offers", {})
	for id in raw_offers:
		var list := []
		for o in raw_offers[id]:
			list.append({"type": String(o["type"]), "culture": String(o["culture"])})
		offers[String(id)] = list
	offers_back = {}
	var raw_back = d.get("offers_back", {})
	for id in raw_back:
		offers_back[String(id)] = float(raw_back[id])
	respawns = []
	for r in d.get("respawns", []):
		respawns.append({"faction": String(r["faction"]), "at": float(r["at"])})
	parties = []
	for e in d.get("parties", []):
		var p := Party.new()
		p.id = int(e["id"])
		p.kind = String(e["kind"])
		p.name = String(e["name"])
		p.faction = String(e["faction"])
		p.node = String(e["node"])
		p.next = String(e["next"])
		p.along = float(e["along"])
		p.path = []
		for s in e["path"]:
			p.path.append(String(s))
		p.wait = float(e["wait"])
		p.grace_until = float(e["grace_until"])
		p.army = clean_army(e["army"])
		parties.append(p)


## Squads read back from JSON, with ids and counts as ints again.
static func clean_army(raw: Array) -> Array:
	var out := []
	for s in raw:
		var squad := {"id": int(s["id"]), "type": String(s["type"]), "men": int(s["men"]), "xp": int(s.get("xp", 0)),
			"name": String(s.get("name", "")), "captain": null}
		var c = s.get("captain")
		if typeof(c) == TYPE_DICTIONARY:
			var cap: Dictionary = c.duplicate(true)
			for k in ["id", "wounded", "battles", "kills"]:
				cap[k] = int(cap.get(k, 0))
			squad["captain"] = cap
		out.append(squad)
	return out
