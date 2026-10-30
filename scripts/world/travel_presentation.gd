## Read-only presentation facts for travel and arrival. This derives atmosphere from
## the world as it already stands; it never advances time, consumes RNG or changes a save.
extends RefCounted

const Data = preload("res://scripts/world/world_data.gd")
const MapTerrain = preload("res://scripts/world/map_terrain.gd")
const Units = preload("res://scripts/data/units.gd")
const Troops = preload("res://scripts/data/troops.gd")

## Within this many map units, the road sounds like the edge of a settlement.
const SETTLEMENT_EDGE := 72.0
## The softened shoreline can extend onto land; this smaller value keeps the coast audible.
const COAST_INLAND := 0.08


## Everything a screen needs to present the player's current journey.
static func context(world, army: Array = []) -> Dictionary:
	if world == null or world.player() == null:
		return {}
	var party = world.player()
	var pos: Vector2 = world.party_pos(party)
	var nearest: Dictionary = nearest_settlement(pos)
	var nearest_id := String(nearest.get("id", ""))
	var terrain = MapTerrain.shared()
	var sea: bool = party.moving() and world.is_sea(party.node, party.next)
	var at: String = world.here()
	var surface := "open"
	if sea:
		surface = "water"
	elif at != "" or float(nearest.get("distance", INF)) <= SETTLEMENT_EDGE:
		surface = "settlement"
	elif terrain.inland(pos) < COAST_INLAND:
		surface = "water"
	elif terrain.wooded(pos):
		surface = "woods"

	var time := time_band(float(world.hour))
	var ambience := "road_open"
	if time == "night":
		ambience = "road_night"
	else:
		match surface:
			"water": ambience = "water"
			"woods": ambience = "birds"
			"settlement": ambience = "settlement_edge"

	var realm: String = terrain.realm_at(pos)
	var culture := ""
	if realm != "":
		culture = Data.culture_of(realm)
	elif nearest_id != "":
		culture = Data.culture_of(Data.settlement(nearest_id)["faction"])

	var moving: bool = party.moving() and world.busy()
	var contact := "none"
	if moving:
		contact = "wake" if sea else ("cavalry" if mounted_majority(army) else "foot")
	var day := int(float(world.hour) / 24.0)
	var seed_text := "%s|%d|%s|%s" % [nearest_id, day, surface, time]
	return {
		"position": pos,
		"nearest_settlement": nearest_id,
		"nearest_distance": float(nearest.get("distance", INF)),
		"realm": realm,
		"culture": culture,
		"time_band": time,
		"surface": surface,
		"at_settlement": at,
		"destination": world.destination(),
		"moving": moving,
		"movement_contact": contact,
		"ambience": ambience,
		"cosmetic_key": seed_text.hash(),
	}


## A compact, factual arrival heading and condition for the settlement card.
static func arrival(world, id: String) -> Dictionary:
	if world == null or not Data.SETTLEMENTS.has(id):
		return {}
	var info: Dictionary = Data.settlement(id)
	var owner: String = world.owner_of(id)
	var condition := "Quiet roads"
	if world.is_burned(id):
		condition = "Rebuilding after a raid"
	else:
		for party in world.parties:
			if party.raiding and party.raid_village == id:
				condition = "Raiders are active here"
				break
		if condition == "Quiet roads" and world.garrisons.has(id):
			var capacity: int = world.garrison_capacity(id)
			var held: int = world.men_of(world.garrison_at(id))
			if capacity > 0 and held < capacity * 0.4:
				condition = "The walls are thinly held"
		if condition == "Quiet roads":
			var player_realm: String = Data.realm_of_culture(world.culture)
			if world.at_war(player_realm, owner):
				condition = "Hostile territory"
			elif world.capital_of(owner) == id:
				condition = "Realm capital"
	return {
		"name": String(info["name"]),
		"subtitle": "%s · %s" % [String(info["type"]).capitalize(), Data.FACTIONS[owner]["name"]],
		"condition": condition,
		"culture": Data.culture_of(info["faction"]),
		"owner": owner,
	}


static func time_band(hour: float) -> String:
	var h := fposmod(hour, 24.0)
	if h < 5.5 or h >= 20.5:
		return "night"
	if h < 8.0:
		return "dawn"
	if h >= 17.5:
		return "dusk"
	return "day"


## Foot-heavy companies march; a company with at least half its living men mounted rides.
static func mounted_majority(army: Array) -> bool:
	var living := 0
	var mounted := 0
	for squad in army:
		if typeof(squad) != TYPE_DICTIONARY:
			continue
		var men := maxi(0, int(squad.get("men", 0)))
		living += men
		var unit_id := String(squad.get("unit", ""))
		var role := Units.role(unit_id) if Units.has(unit_id) else String(squad.get("type", ""))
		if role == Troops.CAVALRY:
			mounted += men
	return living > 0 and mounted * 2 >= living


static func nearest_settlement(pos: Vector2) -> Dictionary:
	var best := ""
	var distance := INF
	for id in Data.SETTLEMENTS:
		var d: float = pos.distance_to(Data.pos(id))
		if d < distance:
			distance = d
			best = id
	return {"id": best, "distance": distance}
