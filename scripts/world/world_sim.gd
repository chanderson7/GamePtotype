## The world map as pure logic: no nodes, no drawing. The map screen draws it and feeds
## it orders; tests run it headless.
##
## Parties travel along roads between settlements. Time passes only while the player is
## travelling or waiting, and stops the moment a bandit band blocks the road. Bandit
## bands roam the villages of their own realm, and one that is beaten comes back a day
## later.
##
## Who holds each settlement, which realms are at war and where each realm's capital is
## start as world_data.gd has them, and are the world's own from then on: places change
## hands, and wars begin and end.
extends RefCounted

const Data = preload("res://scripts/world/world_data.gd")
const Captains = preload("res://scripts/data/captains.gd")
const Cultures = preload("res://scripts/data/cultures.gd")
const Troops = preload("res://scripts/data/troops.gd")
const Economy = preload("res://scripts/data/economy.gd")
const Units = preload("res://scripts/data/units.gd")
const Lords = preload("res://scripts/data/lords.gd")
const MarshalArmies = preload("res://scripts/world/marshal_armies.gd")
const AutoResolve = preload("res://scripts/battle/auto_resolve.gd")
const SocialSim = preload("res://scripts/world/social_sim.gd")

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
## A chief who got away from you comes back at the head of a new band this long after.
const CHIEF_RETURN_HOURS := 120.0
## The chance a new band is led by a chief: a few at first, more as the weeks go by.
const CHIEF_CHANCE_START := 0.1
const CHIEF_CHANCE_PER_DAY := 0.01
const CHIEF_CHANCE_MAX := 0.3
## After you withdraw from a band, or it beats you, it leaves you alone this long.
const GRACE_HOURS := 2.0
## Hours lost when your warband is beaten and regroups at your capital.
const REGROUP_HOURS := 12.0
## The world moves in steps no longer than this, so nothing slips past an encounter.
const TICK := 0.25
const PLAYER := "player"
const BAND := "bandit"
const LORD := "lord"


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
	## Whether this band is currently raiding a village.
	var raiding := false
	var raid_village := ""
	var is_chief_band := false
	var chief_name := ""
	## A band's fighters, in the battle sim's army format.
	var army: Array = []
	## Until this hour, this band won't block the player's road again.
	var grace_until := -1.0
	## The lord riding with this party (its id in `lords`), or -1.
	var lord := -1

	func moving() -> bool:
		return next != ""


var rng := RandomNumberGenerator.new()
## Hours since the campaign's first midnight. A campaign starts in the morning.
var hour := 0.0
const START_HOUR := 8.0
var culture := Cultures.VARDISH
var parties: Array = []
## Bands waiting to come back: [{faction, at}].
var respawns: Array = []
## Registry of escaped bandit chiefs: [{name, culture, grudge, escaped_at, times_beaten}].
var escaped_chiefs: Array = []
## Track villages successfully defended from raids: {village_id: count}.
var saved_villages: Dictionary = {}
## What happened since the screen last looked: arrived, waited, encounter, respawn.
var events: Array = []
## The id of the band blocking the player's road, or -1.
var encounter := -1
## Recruits each settlement offers: {settlement id: [{type, culture}]}, and the hour each
## settlement's offers come back after any are taken.
var offers := {}
var offers_back := {}
## Who holds each settlement: id → realm. A village goes with the castle or town it's
## bound to.
var owners := {}
## Realms at war, by pair ("kharzan|vardmark") → {since: hour}. Everyone is at war with
## bandits besides.
var wars := {}
## Each realm's seat and purse: realm → {capital, treasury}. A realm that loses its
## capital moves it.
var realms := {}
## Castle/town id → squads in battle army format. Villages have no standing garrison.
var garrisons := {}
## Social simulation: relationships, court residents, pacts, escrows, and letters.
var social: SocialSim = null
## The lords of the realms, rulers among them: [{id, name, realm, culture, bearing, ruler,
## renown, silver, fief, party, state, back_at, job, target, think_at, raiding, broke_days,
## full, army}]. `party` is the id of his party on the map, or -1 while he regroups (his
## surviving squads wait in `army`).
var lords: Array = []
## Expedition membership references parties; it never duplicates their troops.
var campaign_armies: Array = []
var army_ready_at: Dictionary = {}
var next_army_id := 1
## Villages raiders have burned: id → the hour they're rebuilt.
var burned := {}
## The last day the lords' purses were settled.
var _lord_day := 0
var _next_id := 1
var _adjacent := {}
var _lord_hours := {}


# ---------------------------------------------------------------- setup

## A new world: the player's party stands at their culture's capital, and a bandit
## band roams each realm.
func setup(seed_value: int, player_culture: String) -> void:
	rng.seed = seed_value
	culture = player_culture
	hour = START_HOUR
	_build_roads()
	_start_realms()
	var p := Party.new()
	p.id = _take_id()
	p.kind = PLAYER
	p.name = "Your warband"
	p.node = Data.capital_of_culture(culture)
	parties.append(p)
	for faction in Data.BANDIT_BANDS:
		for k in Data.BANDIT_BANDS[faction].size():
			_spawn_band(faction)
	for id in Data.SETTLEMENTS:
		offers[id] = _new_offers(id)
	_spawn_lords()
	_start_garrisons()
	social = SocialSim.new()
	social.setup(seed_value, lords, Data.SETTLEMENTS)
	_lord_day = int(hour / 24.0)


## The map as it stands at the start of a campaign: every place in its first owner's
## hands, the first wars, each realm's capital where world_data.gd puts it.
func _start_realms() -> void:
	owners = {}
	for id in Data.SETTLEMENTS:
		owners[id] = String(Data.SETTLEMENTS[id]["faction"])
	wars = {}
	for w in Data.WARS:
		wars[war_key(w[0], w[1])] = {"since": 0.0}
	realms = {}
	for f in Data.FACTIONS:
		if f != Data.BANDITS:
			realms[f] = {"capital": String(Data.FACTIONS[f]["capital"]), "treasury": Lords.TREASURY_START, "marshal": -1}


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


# ---------------------------------------------------------------- realms

## The realm holding settlement `id`.
func owner_of(id: String) -> String:
	return String(owners.get(id, Data.settlement(id)["faction"]))


## Every settlement realm `realm` holds; only its villages with `type` VILLAGE.
func holdings_of(realm: String, type: String = "") -> Array:
	var out := []
	for id in Data.SETTLEMENTS:
		if owner_of(id) == realm and (type == "" or Data.settlement(id)["type"] == type):
			out.append(id)
	return out


func villages_of(realm: String) -> Array:
	return holdings_of(realm, Data.VILLAGE)


## Where realm `realm` rules from, or "" if it holds no castle or town.
func capital_of(realm: String) -> String:
	return String(realms.get(realm, {}).get("capital", ""))


static func war_key(a: String, b: String) -> String:
	return "%s|%s" % [a, b] if a < b else "%s|%s" % [b, a]


func at_war(a: String, b: String) -> bool:
	if a == b:
		return false
	if a == Data.BANDITS or b == Data.BANDITS:
		return true
	return wars.has(war_key(a, b))


func declare_war(a: String, b: String) -> void:
	if a != b and not at_war(a, b):
		wars[war_key(a, b)] = {"since": hour}
		events.append({"type": "war", "realms": [a, b]})


func make_peace(a: String, b: String) -> void:
	if wars.erase(war_key(a, b)):
		events.append({"type": "peace", "realms": [a, b]})


## Settlement `id` passes to `realm`, with the villages bound to it. A realm that loses its
## capital rules from its best remaining place: a town if it has one, else a castle.
func set_owner(id: String, realm: String) -> void:
	var was := owner_of(id)
	if was == realm:
		return
	owners[id] = realm
	# Defenders don't change allegiance with their walls. A future siege leaves its
	# survivors here after the transfer; until then the new owner must recruit guards.
	if garrisons.has(id):
		garrisons[id] = []
	for v in Data.SETTLEMENTS:
		if String(Data.SETTLEMENTS[v].get("bound_to", "")) == id:
			owners[v] = realm
	if capital_of(was) == id:
		var seat := ""
		for kind in [Data.TOWN, Data.CASTLE]:
			var held := holdings_of(was, kind)
			if not held.is_empty():
				seat = held[0]
				break
		realms[was]["capital"] = seat
	events.append({"type": "captured", "settlement": id, "realm": realm, "from": was})
	if social != null:
		social.on_settlement_captured(id, realm, was, self)


## "Castle of the Kingdom of Vardmark · Vardish": what a place is, whose it is now, and who
## lives there (its people don't change with its owner).
func describe(id: String) -> String:
	var s := Data.settlement(id)
	var realm := owner_of(id)
	var faction: Dictionary = Data.FACTIONS[realm]
	var line := "%s of the %s" % [String(s["type"]).capitalize(), faction["name"]]
	if capital_of(realm) == id:
		line = "Capital of the %s, seat of %s" % [faction["name"], faction["ruler"]]
	var people: String = Cultures.info(Data.culture_of(s["faction"]))["people"]
	if garrisons.has(id):
		people += " · garrison %d/%d men" % [men_of(garrison_at(id)), garrison_capacity(id)]
	if is_burned(id):
		return "%s · %s · burned by raiders, rebuilding" % [line, people]
	return "%s · %s" % [line, people]


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


## The lords' parties on the map.
func lord_parties() -> Array:
	return parties.filter(func(p): return p.kind == LORD)


## Joined lords share one visible marker, but retain their authoritative parties.
func visible_lord_parties() -> Array:
	return lord_parties().filter(func(p):
		var army := MarshalArmies.for_party(self, p.id)
		return army.is_empty() or army["state"] == "gathering" or int(army["leader"]) == p.id)


func army_parties(p: Party) -> Array:
	var army := MarshalArmies.for_party(self, p.id)
	return [p] if army.is_empty() or army["state"] == "gathering" else MarshalArmies.members(self, army)


func lord_of(p: Party) -> Dictionary:
	return lords[p.lord] if p != null and p.lord >= 0 and p.lord < lords.size() else {}


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
	if is_sea(a, b):
		return SEA_SPEED
	return Lords.SPEED if p.kind == LORD else LAND_SPEED


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
			if band_realm != "" and (bool(n[1]) or owner_of(nxt) != band_realm):
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
		_step_lords(dt)
		if social != null:
			social.step(dt, self)
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
			if Data.is_village(b.node) and rng.randf() < 0.35:
				b.raiding = true
				b.raid_village = b.node
				b.wait = rng.randf_range(4.0, 8.0)
				events.append({"type": "raid_started", "party": b.id, "village": b.node, "hours": b.wait})
		return
	if b.wait > 0.0:
		b.wait = maxf(0.0, b.wait - dt)
		return
	if b.raiding:
		b.raiding = false
		b.raid_village = ""
	var choices: Array = villages_of(b.faction).filter(func(v): return v != b.node)
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


func _generate_chief_name(cult: String) -> String:
	match cult:
		Cultures.KHARZANI:
			var names := ["Tariq the Scarred", "Malik the Swift", "Kadir Bone-breaker", "Jamil the Falcon", "Bashir Red-hand"]
			return names[rng.randi_range(0, names.size() - 1)]
		Cultures.RYUMON:
			var names := ["Kenji the Demon", "Raiden the Exile", "Hidetora Kuro", "Masaru the Wolf", "Kojiro Iron-will"]
			return names[rng.randi_range(0, names.size() - 1)]
		_:
			var names := ["Rask the Red", "Torvald Iron-hand", "Brand the Wolf", "Gunnar the Reaver", "Erik Blood-axe"]
			return names[rng.randi_range(0, names.size() - 1)]


func _spawn_band(faction: String) -> void:
	var names: Array = Data.BANDIT_BANDS[faction].duplicate()
	var at_large := 0
	for b in bands():
		if b.faction == faction:
			at_large += 1
			names.erase(b.name)
	if at_large >= Data.BANDIT_BANDS[faction].size():
		return
	var villages := villages_of(faction)
	if villages.is_empty():
		# A realm with no villages left has no band either, until it wins one back.
		respawns.append({"faction": faction, "at": hour + RESPAWN_HOURS})
		return
	var b := Party.new()
	b.id = _take_id()
	b.kind = BAND
	b.faction = faction
	var band_cult := Data.culture_of(faction)
	b.node = villages[rng.randi_range(0, villages.size() - 1)]
	b.wait = rng.randf_range(BANDIT_WAIT_MIN, BANDIT_WAIT_MAX)
	b.grace_until = hour + 1.0

	var chief_to_return = null
	for i in escaped_chiefs.size():
		var ec: Dictionary = escaped_chiefs[i]
		if ec.get("culture", "") == band_cult and hour >= float(ec.get("escaped_at", 0.0)) + CHIEF_RETURN_HOURS:
			chief_to_return = ec
			escaped_chiefs.remove_at(i)
			break

	if chief_to_return != null:
		b.is_chief_band = true
		b.chief_name = String(chief_to_return["name"])
		b.name = "%s's Host" % b.chief_name
		b.army = _band_army(b.id, band_cult, true, chief_to_return)
		events.append({"type": "chief_returned", "party": b.id, "chief": chief_to_return})
	else:
		var day := int(hour / 24.0)
		var chief_chance := minf(CHIEF_CHANCE_MAX, CHIEF_CHANCE_START + float(day) * CHIEF_CHANCE_PER_DAY)
		if rng.randf() < chief_chance:
			b.is_chief_band = true
			b.chief_name = _generate_chief_name(band_cult)
			b.name = "%s's Band" % b.chief_name
			b.army = _band_army(b.id, band_cult, true, {"name": b.chief_name, "grudge": 0})
		else:
			b.name = String(names[0])
			b.army = _band_army(b.id, band_cult)

	parties.append(b)
	events.append({"type": "respawn", "party": b.id})


## Three to five squads of eight to fourteen men, mostly foot and bows, never more than
## one squad of horse, led by captains of the realm's culture. As days pass, bands
## field tier-2 units more often. If led by a chief, fields a tier-2 bodyguard.
func _band_army(band_id: int, band_culture: String, with_chief: bool = false, chief_data: Dictionary = {}) -> Array:
	var out := []
	var taken := []
	var horse := false
	var day := int(hour / 24.0)
	var tier2_chance := clampf(float(day) * 0.02, 0.0, 0.40)
	var squad_count := rng.randi_range(3, 5)
	if with_chief:
		squad_count = maxi(4, squad_count + 1)
	for i in squad_count:
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
		var unit_id := Units.recruit(band_culture, type)
		var level := 1
		var xp := 0
		var is_bg := false
		var is_ch := false
		var c_name := ""
		if with_chief and i == 0:
			is_bg = true
			is_ch = true
			c_name = String(chief_data.get("name", "Bandit Chief"))
			captain["name"] = c_name
			captain["first"] = c_name.split(" ")[0]
			level = 2
			xp = Troops.XP_PER_LEVEL
			var branch_options := Units.branches(unit_id)
			if not branch_options.is_empty():
				unit_id = branch_options[0]
		elif rng.randf() < tier2_chance:
			var branch_options := Units.branches(unit_id)
			if not branch_options.is_empty():
				unit_id = branch_options[rng.randi_range(0, branch_options.size() - 1)]
				level = 2
				xp = Troops.XP_PER_LEVEL
		var men := rng.randi_range(8, 14)
		if is_bg:
			men = rng.randi_range(12, 16)
		out.append({"id": id, "type": type, "unit": unit_id, "level": level, "xp": xp,
			"men": men, "culture": band_culture,
			"name": ("%s's Bodyguard" % c_name) if is_bg else Captains.company_name(captain, type),
			"captain": captain,
			"is_bodyguard": is_bg, "is_chief": is_ch, "chief_name": c_name})
	return out


# ---------------------------------------------------------------- garrisons

func garrison_at(id: String) -> Array:
	return garrisons.get(id, [])


func garrison_capacity(id: String) -> int:
	var total := 0
	for sq in _garrison_template(id):
		total += Units.full_size(String(sq["unit"]))
	return total


## Fixed slots give rebuilt squads stable ids without consuming the world's random
## stream. Recruits are the settlement's people, even under a foreign owner.
func _garrison_template(id: String) -> Array:
	var kind := String(Data.settlement(id)["type"])
	var roles: Array = Lords.GARRISON_ROLES.get(kind, [])
	var cult := Data.culture_of(String(Data.settlement(id)["faction"]))
	var out := []
	for i in roles.size():
		var type := String(roles[i])
		var unit := Units.recruit(cult, type)
		var level := 1
		if i < int(Lords.GARRISON_TRAINED[kind]):
			unit = Units.branches(unit)[0]
			level = 2
		out.append({"id": 8000000 + Data.SETTLEMENTS.keys().find(id) * 100 + i,
			"type": type, "unit": unit, "culture": cult, "level": level,
			"xp": Troops.XP_PER_LEVEL if level > 1 else 0, "men": 0,
			"name": "%s guard" % Data.settlement(id)["name"], "captain": null})
	return out


## New campaigns and pre-garrison saves start with the same standing guards, for free.
func _start_garrisons() -> void:
	garrisons = {}
	for id in Data.SETTLEMENTS:
		var army := _garrison_template(id)
		if army.is_empty():
			continue
		for sq in army:
			sq["men"] = int(Units.full_size(String(sq["unit"])) * Lords.GARRISON_START_SHARE)
		garrisons[id] = army


## Refill survivors first, then replace missing squads, up to the settlement's cap.
## Buy only affordable men; an empty treasury neither creates troops nor goes negative.
func _garrisons_day() -> void:
	for id in garrisons:
		var army: Array = garrisons[id]
		var kind := String(Data.settlement(id)["type"])
		var budget := mini(int(Lords.GARRISON_RECRUITS_PER_DAY[kind]),
			garrison_capacity(id) - men_of(army))
		var realm: Dictionary = realms[owner_of(id)]
		var candidates := army.duplicate()
		for sq in _garrison_template(id):
			if not army.any(func(have): return int(have["id"]) == int(sq["id"])):
				candidates.append(sq)
		for sq in candidates:
			if budget <= 0:
				break
			var unit := String(sq["unit"])
			var add := mini(budget, Units.full_size(unit) - int(sq["men"]))
			var available := maxi(0, int(realm["treasury"]) - Lords.TREASURY_RESERVE)
			var unit_cost := int(Economy.recruit_cost(unit, 1))
			var escrow_paid := 0
			if social != null:
				escrow_paid = social.consume_escrow_for_recruitment(id, "settlement", add, unit_cost)
			var total_cost := Economy.recruit_cost(unit, add)
			var realm_cost := maxi(0, total_cost - escrow_paid)
			while add > 0 and realm_cost > available:
				add -= 1
				total_cost = Economy.recruit_cost(unit, add)
				realm_cost = maxi(0, total_cost - escrow_paid)
			if add <= 0:
				continue
			if not army.has(sq):
				army.append(sq)
			realm["treasury"] = int(realm["treasury"]) - realm_cost
			sq["men"] = int(sq["men"]) + add
			budget -= add


# ---------------------------------------------------------------- lords

## Each realm's ruler, at its capital, and its lords: the first two hold its castles, the
## rest serve for a stipend and ride out from the capital.
func _spawn_lords() -> void:
	lords = []
	for realm in realms:
		var cult := Data.culture_of(realm)
		var firsts: Array = Cultures.info(cult)["first"].duplicate()
		var houses: Array = Lords.HOUSES[cult].duplicate()
		var castles := holdings_of(realm, Data.CASTLE)
		var ruler := String(Data.FACTIONS[realm]["ruler"])
		_add_lord(realm, cult, ruler, true, 200, capital_of(realm))
		for i in Lords.PER_REALM:
			var first: String = firsts.pop_at(rng.randi_range(0, firsts.size() - 1))
			var house: String = houses.pop_at(rng.randi_range(0, houses.size() - 1))
			var fief: String = castles[i] if i < castles.size() else ""
			_add_lord(realm, cult, "%s %s %s" % [Lords.title(cult), first, house], false,
				int(Lords.START_RENOWN[i % Lords.START_RENOWN.size()]), fief)


func _add_lord(realm: String, cult: String, name: String, ruler: bool, renown: int, fief: String) -> void:
	var l := {"id": lords.size(), "name": name, "realm": realm, "culture": cult,
		"bearing": Lords.BEARINGS[rng.randi_range(0, Lords.BEARINGS.size() - 1)], "ruler": ruler,
		"renown": renown, "silver": Lords.START_SILVER, "fief": fief, "party": -1, "state": "field",
		"back_at": 0.0, "job": "", "target": "", "think_at": hour + rng.randf_range(0.0, Lords.THINK_HOURS),
		"raiding": "", "broke_days": 0, "full": 0, "army": []}
	lords.append(l)
	l["army"] = _lord_army(l)
	for sq in l["army"]:
		l["full"] = int(l["full"]) + int(sq["men"])
	_lord_takes_field(l, seat_of(l))


## Where a lord rests and refills: his fief while his realm holds it, else its capital.
func seat_of(l: Dictionary) -> String:
	var fief := String(l["fief"])
	if fief != "" and owner_of(fief) == l["realm"]:
		return fief
	return capital_of(String(l["realm"]))


## A lord's warband at full strength: squads by his renown, more of them trained as his
## renown grows, under captains of his people.
func _lord_army(l: Dictionary) -> Array:
	var out := []
	var cult := String(l["culture"])
	var taken := []
	var trained := Lords.trained_share(int(l["renown"]))
	for i in Lords.squads_for(int(l["renown"])):
		var roll := rng.randf()
		var type := Troops.INFANTRY
		if roll > 0.8:
			type = Troops.CAVALRY
		elif roll > 0.55:
			type = Troops.ARCHERS
		elif roll > 0.3:
			type = Troops.SPEARMEN
		var unit := Units.recruit(cult, type)
		var level := 1
		if rng.randf() < trained:
			var options := Units.branches(unit)
			if not options.is_empty():
				unit = options[rng.randi_range(0, options.size() - 1)]
				level = 2
		var id := 7000000 + int(l["id"]) * 100 + i
		var captain := Captains.make(rng, id, type, taken, cult)
		taken.append(captain["first"])
		out.append({"id": id, "type": type, "unit": unit, "level": level,
			"xp": Troops.XP_PER_LEVEL if level > 1 else 0, "men": Units.full_size(unit), "culture": cult,
			"name": Captains.company_name(captain, type), "captain": captain})
	return out


## The lord rides out from `at` with his warband.
func _lord_takes_field(l: Dictionary, at: String) -> void:
	if at == "":
		return
	var p := Party.new()
	p.id = _take_id()
	p.kind = LORD
	p.name = String(l["name"])
	p.faction = String(l["realm"])
	p.node = at
	p.lord = int(l["id"])
	p.army = l["army"]
	parties.append(p)
	l["party"] = p.id
	l["state"] = "field"
	l["job"] = ""
	l["raiding"] = ""
	l["think_at"] = hour


func men_of(army: Array) -> int:
	var men := 0
	for sq in army:
		men += int(sq["men"])
	return men


func is_burned(id: String) -> bool:
	return hour < float(burned.get(id, -1.0))


func _step_lords(dt: float) -> void:
	var day := int(hour / 24.0)
	while _lord_day < day:
		_lord_day += 1
		_lords_day()
	MarshalArmies.tick(self, dt)
	for l in lords:
		if not MarshalArmies.for_party(self, int(l["party"])).is_empty():
			continue
		if l["state"] == "regroup":
			if hour >= float(l["back_at"]):
				_lord_takes_field(l, seat_of(l))
			continue
		var p := party(int(l["party"]))
		if p == null:
			continue
		if p.moving():
			if _move(p, dt):
				_lord_arrives(l, p)
		elif p.wait > 0.0:
			p.wait = maxf(0.0, p.wait - dt)
			if p.wait <= 0.0 and String(l["raiding"]) != "":
				_burn(l, String(l["raiding"]))
		if hour >= float(l["think_at"]) or (not p.moving() and p.wait <= 0.0 and l["job"] != "home"):
			l["think_at"] = hour + Lords.THINK_HOURS
			_think_lord(l, p)
	_lord_fights()


## What a lord does next. He goes home when his warband is spent or his purse is empty;
## otherwise he weighs defending his realm's villages, hunting bandits, raiding the enemy
## and patrolling, by his bearing.
func _think_lord(l: Dictionary, p: Party) -> void:
	var bearing := String(l["bearing"])
	var men := men_of(p.army)
	var full := maxi(1, int(l["full"]))
	var seat := seat_of(l)
	if l["job"] == "home" and p.node == seat and not p.moving():
		if men >= full * Lords.REFILLED:
			l["job"] = ""
		else:
			p.wait = Lords.THINK_HOURS
			return
	var low := Lords.REFILL_BELOW + (0.1 if bearing == Lords.CAUTIOUS else 0.0)
	if men < full * low and seat != "":
		_set_job(l, p, "home", seat)
		return
	if String(l["raiding"]) != "":
		return
	var from: String = p.next if p.moving() else p.node
	var best := ["patrol", "", 1.0]
	# Defend: a village of his realm that raiders are burning.
	for other in lords:
		var v := String(other["raiding"])
		if v != "" and owner_of(v) == l["realm"] and at_war(String(other["realm"]), String(l["realm"])):
			var h := _hours(p, from, v)
			if h <= Lords.DEFEND_HOURS:
				var score := 5.0 + (1.0 if bearing in [Lords.CAUTIOUS, Lords.HONORABLE] else 0.0) - h * 0.05
				if score > float(best[2]):
					best = ["defend", v, score]
	# Hunt: bandits raiding a village of his realm, within reach. Bands on the road he
	# leaves to the likes of you.
	for b in bands():
		var at: String = b.next if b.moving() else b.node
		if not b.raiding or owner_of(b.raid_village) != l["realm"]:
			continue
		var h := _hours(p, from, at)
		if h <= Lords.HUNT_HOURS:
			var score := 3.0 + (2.0 if bearing == Lords.HONORABLE else 0.0) - h * 0.05
			if score > float(best[2]):
				best = ["hunt", str(b.id), score]
	# Raid: an enemy village not yet burned, if his warband is strong enough.
	if men >= full * 0.7:
		var reach := Lords.RAID_HOURS_AWAY * (1.5 if bearing == Lords.DARING else (0.4 if bearing == Lords.CAUTIOUS else 1.0))
		for v in Data.SETTLEMENTS:
			if not Data.is_village(v) or is_burned(v) or not at_war(owner_of(v), String(l["realm"])) or owner_of(v) == Data.BANDITS:
				continue
			var h := _hours(p, from, v)
			if h <= reach:
				var score := 2.0 + (2.0 if bearing == Lords.CRUEL else 0.0) + (1.0 if bearing == Lords.DARING else 0.0) \
					- (1.0 if bearing == Lords.HONORABLE else 0.0) - h * 0.03 + rng.randf() * 0.5
				if score > float(best[2]):
					best = ["raid", v, score]
	if best[0] == "patrol":
		if l["job"] == "patrol" and (p.moving() or p.wait > 0.0):
			return
		var own := holdings_of(String(l["realm"])).filter(func(id): return id != p.node)
		if own.is_empty():
			return
		_set_job(l, p, "patrol", own[rng.randi_range(0, own.size() - 1)])
	elif best[0] == "hunt":
		var b := party(int(best[1]))
		_set_job(l, p, "hunt", b.next if b.moving() else b.node)
	else:
		_set_job(l, p, best[0], best[1])


## Hours for lord's party `p` to ride from `from` to `to`. The roads never change, so
## every pair is worked out once.
func _hours(p: Party, from: String, to: String) -> float:
	if from == to:
		return 0.0
	if _lord_hours.is_empty():
		for a in Data.SETTLEMENTS:
			for b in Data.SETTLEMENTS:
				var route := path(a, b) if a != b else []
				var h := 0.0 if a == b else INF
				if not route.is_empty():
					h = 0.0
					var at: String = a
					for nxt in route:
						h += road_length(at, nxt) / _speed(p, at, nxt)
						at = nxt
				_lord_hours["%s>%s" % [a, b]] = h
	return float(_lord_hours.get("%s>%s" % [from, to], INF))


func _set_job(l: Dictionary, p: Party, job: String, target: String) -> void:
	l["job"] = job
	l["target"] = target
	p.wait = 0.0
	var from: String = p.node
	if p.moving():
		# Finish the road he's on first.
		from = p.next
	var route := path(from, target) if from != target else []
	if p.moving():
		p.path = route
	elif route.is_empty():
		_lord_arrives(l, p)
	else:
		p.next = route.pop_front()
		p.along = 0.0
		p.path = route


func _lord_arrives(l: Dictionary, p: Party) -> void:
	if l["job"] == "army": return
	if p.moving() or p.node != String(l["target"]):
		return
	match String(l["job"]):
		"raid":
			if Data.is_village(p.node) and not is_burned(p.node) and at_war(owner_of(p.node), String(l["realm"])):
				l["raiding"] = p.node
				p.wait = Lords.RAID_HOURS
				events.append({"type": "raid_started", "party": p.id, "village": p.node, "hours": Lords.RAID_HOURS})
			else:
				l["job"] = ""
		"home":
			p.wait = Lords.THINK_HOURS
		_:
			p.wait = rng.randf_range(Lords.LINGER_MIN, Lords.LINGER_MAX)
			l["job"] = "patrol"


func _burn(l: Dictionary, village: String) -> void:
	l["raiding"] = ""
	l["job"] = ""
	if is_burned(village):
		return
	burned[village] = hour + Lords.BURNED_DAYS * 24.0
	l["silver"] = int(l["silver"]) + Lords.RAID_LOOT
	events.append({"type": "burned", "village": village, "by": String(l["name"])})


## A day's money. Each realm takes in its places' dues and pays its lords' wages; a lord
## whose realm can't pay him pays from his own purse, and one who can't pay at all loses
## men, as your warband does. A lord resting at his seat refills his squads.
func _lords_day() -> void:
	for realm in realms:
		var income := 0
		for id in holdings_of(realm):
			if not is_burned(id):
				income += int(Lords.INCOME[Data.settlement(id)["type"]])
		realms[realm]["treasury"] = int(realms[realm]["treasury"]) + income
	for l in lords:
		var p := party(int(l["party"]))
		var army: Array = p.army if p != null else l["army"]
		var wages := 0.0
		for sq in army:
			wages += Economy.daily_wage(sq)
		var owed := int(ceil(wages * Lords.WAGE_SHARE))
		var realm: Dictionary = realms[l["realm"]]
		var from_realm := mini(owed, maxi(0, int(realm["treasury"])))
		realm["treasury"] = int(realm["treasury"]) - from_realm
		owed -= from_realm
		var from_lord := mini(owed, maxi(0, int(l["silver"])))
		l["silver"] = int(l["silver"]) - from_lord
		owed -= from_lord
		if owed > 0:
			l["broke_days"] = int(l["broke_days"]) + 1
			for sq in army:
				sq["men"] = int(sq["men"]) - int(ceil(int(sq["men"]) * Economy.DESERTION))
		else:
			l["broke_days"] = 0
		if p != null and not p.moving() and p.node == seat_of(l):
			_refill(l, army)
		army = army.filter(func(sq): return int(sq["men"]) > 0)
		if p != null:
			p.army = army
		l["army"] = army
	_garrisons_day()


## A day's recruits for a lord at his seat, as many as his purse allows, up to his
## warband's full strength. Squads cut down to nothing are raised again.
func _refill(l: Dictionary, army: Array) -> void:
	var budget := int(ceil(int(l["full"]) * Lords.REFILL_PER_DAY))
	if men_of(army) < int(l["full"]) * 0.5 and army.size() < Lords.squads_for(int(l["renown"])):
		for sq in _lord_army(l):
			if army.size() >= Lords.squads_for(int(l["renown"])):
				break
			var used := false
			for have in army:
				if int(have["id"]) == int(sq["id"]):
					used = true
			if not used:
				sq["men"] = 0
				army.append(sq)
	for sq in army:
		if budget <= 0:
			break
		var unit := String(sq.get("unit", ""))
		var full := Units.full_size(unit) if Units.has(unit) else Troops.full_size(String(sq["type"]))
		var add := mini(full - int(sq["men"]), budget)
		if add <= 0:
			continue
		var cost := Economy.recruit_cost(unit if unit != "" else String(sq["type"]), add)
		var unit_cost := int(Economy.recruit_cost(unit if unit != "" else String(sq["type"]), 1))
		var escrow_paid := 0
		if social != null:
			escrow_paid = social.consume_escrow_for_recruitment(str(l["id"]), "lord", add, unit_cost)
		var rem_cost := maxi(0, cost - escrow_paid)
		var realm: Dictionary = realms[l["realm"]]
		if rem_cost > int(l["silver"]) + maxi(0, int(realm["treasury"]) - Lords.TREASURY_RESERVE):
			break
		var own := mini(rem_cost, int(l["silver"]))
		l["silver"] = int(l["silver"]) - own
		realm["treasury"] = int(realm["treasury"]) - (rem_cost - own)
		sq["men"] = int(sq["men"]) + add
		budget -= add


## Lords who meet their enemies on the road fight it out, settled as a fight you send
## your men into would be: lords of realms at war. The loser's party is gone, to regroup
## at his seat with whoever got away. Bandits a hunting lord catches are driven off.
func _lord_fights() -> void:
	var ps: Array = bands() + visible_lord_parties()
	var at := []
	for p in ps:
		at.append(party_pos(p))
	var gone := {}
	var reach := ENCOUNTER_RADIUS * ENCOUNTER_RADIUS
	for i in ps.size():
		var a: Party = ps[i]
		if a.kind != LORD or gone.has(a.id) or party(a.id) == null:
			continue
		# Bands keep out of a lord's way unless he's out hunting them.
		var hunting: bool = lord_of(a).get("job", "") == "hunt"
		for j in ps.size():
			var b: Party = ps[j]
			if j == i or gone.has(b.id) or party(b.id) == null:
				continue
			if b.kind == LORD:
				if j < i or not at_war(a.faction, b.faction):
					continue
			elif not hunting:
				continue
			if (at[i] as Vector2).distance_squared_to(at[j]) > reach:
				continue
			if b.kind == BAND:
				_drive_off(a, b)
				continue
			var loser := _ai_fight(a, b)
			gone[loser.id] = true
			if loser == a:
				break


## Bandits caught raiding by a lord don't stand and fight: they break off and run for
## another village, and the lord turns back to his own business.
func _drive_off(l_party: Party, band: Party) -> void:
	if band.raiding:
		events.append({"type": "driven_off", "party": band.id, "village": band.raid_village, "by": l_party.name})
	band.raiding = false
	band.raid_village = ""
	band.wait = 0.0
	var l := lord_of(l_party)
	l["job"] = ""
	l["think_at"] = hour


## Two parties fight it out; returns the loser.
func _ai_fight(a: Party, b: Party) -> Party:
	var left := army_parties(a)
	var right := army_parties(b)
	var left_troops: Array = []
	var right_troops: Array = []
	for member in left: left_troops.append_array(member.army)
	for member in right: right_troops.append_array(member.army)
	var r := AutoResolve.resolve(left_troops, right_troops, rng, true, null, "rout")
	for member in left: _take_losses(member, r["squads"])
	for member in right: _take_losses(member, r["enemy_squads"])
	var winner := a if r["won"] else b
	var loser := b if r["won"] else a
	var killed := int(r["killed"]) if r["won"] else int(r["lost"])
	var wl := lord_of(winner)
	if not wl.is_empty():
		wl["silver"] = int(wl["silver"]) + Economy.SILVER_PER_KILL * killed
		wl["renown"] = mini(Lords.RENOWN_MAX, int(wl["renown"]) + 1 + killed / 10)
	events.append({"type": "fight", "winner": winner.name, "loser": loser.name, "at": loser.node})
	for member in (right if r["won"] else left): _routed(member)
	var defeated := MarshalArmies.for_party(self, loser.id)
	if not defeated.is_empty(): MarshalArmies.disband(self, defeated, "Army defeated")
	return loser


func _take_losses(p: Party, survivors: Dictionary) -> void:
	for sq in p.army:
		var left = survivors.get(int(sq["id"]))
		if left != null:
			sq["men"] = int(left["men"])
	p.army = p.army.filter(func(sq): return int(sq["men"]) > 0)


## A beaten party leaves the map: a band for good (another rises later), a lord to his
## seat to regroup.
func _routed(p: Party) -> void:
	parties.erase(p)
	if p.kind == BAND:
		respawns.append({"faction": p.faction, "at": hour + RESPAWN_HOURS})
		return
	var l := lord_of(p)
	l["army"] = p.army
	l["party"] = -1
	l["state"] = "regroup"
	l["raiding"] = ""
	l["job"] = ""
	l["back_at"] = hour + Lords.REGROUP_HOURS


# ---------------------------------------------------------------- recruits

## Who will join you at `id`: squads of fresh recruits of the settlement's own culture.
## Villages raise foot and bows, castles spears and horse, towns any of them. Offers that
## were taken come back OFFER_REFRESH_HOURS later.
func offers_at(id: String) -> Array:
	if is_burned(id):
		return []
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
	# Recruits are of the place's own people, whoever holds it now.
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


## The band beat you: the survivors regroup at your people's capital, half a day later.
func lose_encounter() -> void:
	var b := party(encounter)
	encounter = -1
	var p := player()
	p.node = home()
	p.next = ""
	p.along = 0.0
	p.path = []
	p.wait = 0.0
	hour += REGROUP_HOURS
	if b != null:
		b.grace_until = hour + GRACE_HOURS


## Where your warband regroups: your people's capital, wherever their realm now rules from
## (or where it first did, if it holds nothing).
func home() -> String:
	var realm := ""
	for f in Data.FACTIONS:
		if Data.FACTIONS[f]["culture"] == culture:
			realm = f
	var seat := capital_of(realm)
	return seat if seat != "" else Data.capital_of_culture(culture)


# ---------------------------------------------------------------- saving

func to_dict() -> Dictionary:
	var ps := []
	for p in parties:
		ps.append({"id": p.id, "kind": p.kind, "name": p.name, "faction": p.faction, "node": p.node,
			"next": p.next, "along": p.along, "path": p.path.duplicate(), "wait": p.wait,
			"army": p.army.duplicate(true), "grace_until": p.grace_until,
			"raiding": p.raiding, "raid_village": p.raid_village,
			"is_chief_band": p.is_chief_band, "chief_name": p.chief_name, "lord": p.lord})
	return {
		"hour": hour, "culture": culture, "encounter": encounter, "next_id": _next_id,
		"seed": str(rng.seed), "state": str(rng.state),
		"respawns": respawns.duplicate(true), "parties": ps,
		"offers": offers.duplicate(true), "offers_back": offers_back.duplicate(),
		"escaped_chiefs": escaped_chiefs.duplicate(true),
		"saved_villages": saved_villages.duplicate(),
		"owners": owners.duplicate(), "wars": wars.duplicate(true), "realms": realms.duplicate(true),
		"garrisons": garrisons.duplicate(true),
		"campaign_armies": campaign_armies.duplicate(true), "army_ready_at": army_ready_at.duplicate(), "next_army_id": next_army_id,
		"social": social.to_dict() if social != null else null,
		"lords": lords.map(func(l): return _lord_for_save(l)), "burned": burned.duplicate(), "lord_day": _lord_day,
	}


## A lord as saved: his squads only while he regroups (on the map they ride with his party).
func _lord_for_save(l: Dictionary) -> Dictionary:
	var out := l.duplicate(true)
	if int(l["party"]) >= 0:
		out["army"] = []
	return out


## Restore a world saved with to_dict(). JSON turns every number into a float, so counts
## and ids come back as ints.
func from_dict(d: Dictionary) -> void:
	_build_roads()
	# A world saved before places could change hands starts from the map as it was.
	_start_realms()
	var raw_owners = d.get("owners", {})
	for id in raw_owners:
		if Data.SETTLEMENTS.has(String(id)):
			owners[String(id)] = String(raw_owners[id])
	if d.has("wars"):
		wars = {}
		var raw_wars = d["wars"]
		for k in raw_wars:
			wars[String(k)] = {"since": float(raw_wars[k].get("since", 0.0))}
	var raw_realms = d.get("realms", {})
	for f in raw_realms:
		if realms.has(String(f)):
			realms[String(f)]["capital"] = String(raw_realms[f].get("capital", ""))
			realms[String(f)]["treasury"] = int(raw_realms[f].get("treasury", Lords.TREASURY_START))
			realms[String(f)]["marshal"] = int(raw_realms[f].get("marshal", -1))
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
	escaped_chiefs = []
	for ec in d.get("escaped_chiefs", []):
		escaped_chiefs.append({"name": String(ec.get("name", "")), "culture": String(ec.get("culture", "")),
			"grudge": int(ec.get("grudge", 0)), "escaped_at": float(ec.get("escaped_at", 0.0)),
			"times_beaten": int(ec.get("times_beaten", 0))})
	saved_villages = {}
	var raw_saved = d.get("saved_villages", {})
	for k in raw_saved:
		saved_villages[String(k)] = int(raw_saved[k])
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
		p.raiding = bool(e.get("raiding", false))
		p.raid_village = String(e.get("raid_village", ""))
		p.is_chief_band = bool(e.get("is_chief_band", false))
		p.chief_name = String(e.get("chief_name", ""))
		p.lord = int(e.get("lord", -1))
		p.army = clean_army(e["army"])
		parties.append(p)
	burned = {}
	var raw_burned = d.get("burned", {})
	for k in raw_burned:
		burned[String(k)] = float(raw_burned[k])
	lords = []
	if d.has("lords"):
		for e in d["lords"]:
			lords.append(_clean_lord(e))
		for l in lords:
			var lp := party(int(l["party"]))
			if lp != null:
				l["army"] = lp.army
		_lord_day = int(d.get("lord_day", int(hour / 24.0)))
	else:
		# A world saved before there were lords gets its lords now.
		_spawn_lords()
		_lord_day = int(hour / 24.0)

	campaign_armies = d.get("campaign_armies", []).duplicate(true)
	army_ready_at = d.get("army_ready_at", {}).duplicate()
	next_army_id = int(d.get("next_army_id", 1))
	for army in campaign_armies:
		army["id"] = int(army["id"])
		army["leader"] = int(army["leader"])
		army["members"] = army["members"].map(func(id): return int(id))
		next_army_id = maxi(next_army_id, army["id"] + 1)

	if d.has("garrisons"):
		garrisons = {}
		for id in Data.SETTLEMENTS:
			if Lords.GARRISON_ROLES.has(String(Data.settlement(id)["type"])):
				garrisons[id] = clean_army(d["garrisons"].get(id, []))
	else:
		_start_garrisons()

	if d.has("social") and typeof(d["social"]) == TYPE_DICTIONARY:
		social = SocialSim.new()
		social.from_dict(d["social"])
	else:
		social = SocialSim.new()
		social.setup(rng.seed, lords, Data.SETTLEMENTS)


## A lord read back from JSON, with his counts as ints again.
static func _clean_lord(e: Dictionary) -> Dictionary:
	var l := {}
	for k in ["name", "realm", "culture", "bearing", "fief", "state", "job", "target", "raiding"]:
		l[k] = String(e.get(k, ""))
	for k in ["id", "renown", "silver", "party", "broke_days", "full"]:
		l[k] = int(e.get(k, 0))
	l["ruler"] = bool(e.get("ruler", false))
	l["back_at"] = float(e.get("back_at", 0.0))
	l["think_at"] = float(e.get("think_at", 0.0))
	l["army"] = clean_army(e.get("army", []))
	var ordered := {}
	for k in ["id", "name", "realm", "culture", "bearing", "ruler", "renown", "silver", "fief", "party", "state",
			"back_at", "job", "target", "think_at", "raiding", "broke_days", "full", "army"]:
		ordered[k] = l[k]
	return ordered


## Squads read back from JSON, with ids and counts as ints again.
static func clean_army(raw: Array) -> Array:
	var out := []
	for s in raw:
		var squad := {"id": int(s["id"]), "type": String(s["type"]), "men": int(s["men"]), "xp": int(s.get("xp", 0)),
			"name": String(s.get("name", "")), "captain": null}
		if s.has("unit"):
			squad["unit"] = String(s["unit"])
		if s.has("level"):
			squad["level"] = int(s["level"])
		if s.has("culture"):
			squad["culture"] = String(s["culture"])
		if s.has("pending_branch"):
			squad["pending_branch"] = bool(s["pending_branch"])
		if s.has("is_bodyguard"):
			squad["is_bodyguard"] = bool(s["is_bodyguard"])
		if s.has("is_chief"):
			squad["is_chief"] = bool(s["is_chief"])
		if s.has("chief_name"):
			squad["chief_name"] = String(s["chief_name"])
		var c = s.get("captain")
		if typeof(c) == TYPE_DICTIONARY:
			var cap: Dictionary = c.duplicate(true)
			for k in ["id", "wounded", "battles", "kills"]:
				cap[k] = int(cap.get(k, 0))
			squad["captain"] = cap
		out.append(squad)
	return out
