## Read-only presentation facts for travel and arrival. This derives atmosphere from
## the world as it already stands; it never advances time, consumes RNG or changes a save.
extends RefCounted

const Data = preload("res://scripts/world/world_data.gd")
const MapTerrain = preload("res://scripts/world/map_terrain.gd")
const Units = preload("res://scripts/data/units.gd")
const Troops = preload("res://scripts/data/troops.gd")
const Lords = preload("res://scripts/data/lords.gd")

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

	var realm: String = terrain.realm_at(pos)
	var culture := ""
	if surface == "settlement" and nearest_id != "":
		culture = Data.culture_of(Data.settlement(nearest_id)["faction"])
	elif realm != "":
		culture = Data.culture_of(realm)
	elif nearest_id != "":
		culture = Data.culture_of(Data.settlement(nearest_id)["faction"])
	var time := time_band(float(world.hour))
	var ambience := "road_open"
	if surface == "settlement" and culture != "":
		ambience = "settlement_%s" % culture
	elif time == "night":
		ambience = "road_night"
	else:
		match surface:
			"water": ambience = "water"
			"woods": ambience = "birds"

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
	var state := settlement_state(world, id)
	var owner: String = String(state["owner"])
	return {
		"name": String(info["name"]),
		"subtitle": "%s · %s" % [String(info["type"]).capitalize(), Data.FACTIONS[owner]["name"]],
		"condition": String(state["sentence"]),
		"recent_event": String(state["recent_event"]),
		"culture": Data.culture_of(info["faction"]),
		"owner": owner,
		"state": String(state["condition"]),
	}


## Read-only facts used by the vista, map, arrival card and settlement copy. Every field is
## reconstructed from saved simulation data, so presentation cannot drift from the campaign.
static func settlement_state(world, id: String) -> Dictionary:
	if world == null or not Data.SETTLEMENTS.has(id):
		return {}
	var info: Dictionary = Data.settlement(id)
	var built_by := String(info["faction"])
	var owner := String(world.owner_of(id))
	var relation: String = world.relation_to_player(owner) if world.has_method("relation_to_player") else ("friendly" if owner == Data.realm_of_culture(world.culture) else ("hostile" if world.at_war(Data.realm_of_culture(world.culture), owner) else "neutral"))
	var raid_active := false
	for party in world.parties:
		if party.raiding and party.raid_village == id:
			raid_active = true
			break
	var burned: bool = world.is_burned(id)
	var rebuild_progress := 1.0
	if burned:
		var total := float(Lords.BURNED_DAYS) * 24.0
		var remaining := maxf(0.0, float(world.burned.get(id, world.hour)) - float(world.hour))
		rebuild_progress = clampf(1.0 - remaining / maxf(1.0, total), 0.0, 1.0)

	var held := 0
	var capacity := 0
	var garrison := "none"
	if world.garrisons.has(id):
		held = world.men_of(world.garrison_at(id))
		capacity = world.garrison_capacity(id)
		var share := float(held) / maxf(1.0, float(capacity))
		garrison = "thin" if share < 0.4 else ("strong" if share >= 0.8 else "steady")

	var condition := "healthy"
	if raid_active or (burned and rebuild_progress < 0.5):
		condition = "damaged"
	elif burned:
		condition = "recovering"
	elif owner != built_by:
		condition = "occupied"
	elif relation == "hostile" or garrison == "thin":
		condition = "strained"

	var sentence := ""
	match condition:
		"damaged":
			sentence = "Raiders are active beyond the fields; work has stopped and smoke hangs over the road." if raid_active else "Charred roofs and empty plots show the recent raid; rebuilding has only begun."
		"recovering":
			sentence = "Fresh timber and returning workers mark a settlement rebuilding after the raid."
		"occupied":
			sentence = "New banners fly over familiar streets after the change of rule."
		"strained":
			sentence = "The walls are thinly held; few guards watch the approaches." if garrison == "thin" else "The gates are watchful under a realm at war with your own."
		_:
			match String(info["type"]):
				Data.TOWN: sentence = "Trade and carts keep the streets busy beneath secure banners."
				Data.CASTLE: sentence = "Guards hold the walls while the road below remains orderly."
				_: sentence = "Field work continues and livestock gathers close to the village road."

	var available_services: Array[String] = []
	for service in Data.services(id):
		if not burned or String(service) != "recruits":
			available_services.append(String(service))
	var props: Array[String] = []
	if condition not in ["damaged"]:
		match String(info["type"]):
			Data.TOWN:
				props.append_array(["market", "cart"])
				if available_services.has("training"): props.append("smith")
			Data.CASTLE:
				if held > 0: props.append("guards")
				if available_services.has("provisions"): props.append("cart")
			_:
				props.append_array(["workers", "livestock"])
	if condition == "recovering":
		props = ["workers", "timber"]

	return {
		"id": id, "type": String(info["type"]), "culture": Data.culture_of(built_by),
		"built_by": built_by, "owner": owner, "relation": relation,
		"occupied": owner != built_by, "condition": condition, "sentence": sentence,
		"raid_active": raid_active, "burned": burned, "rebuild_progress": rebuild_progress,
		"garrison": garrison, "garrison_men": held, "garrison_capacity": capacity,
		"services": available_services, "props": props,
		"night": time_band(float(world.hour)) == "night",
		"recent_event": recent_settlement_event(world, id),
	}


## Reuse the saved activity feed rather than maintaining a second presentation history.
static func recent_settlement_event(world, id: String, within_hours: float = 7.0 * 24.0) -> String:
	for entry in world.activity_log:
		if String(entry.get("place", "")) != id:
			continue
		if float(world.hour) - float(entry.get("hour", world.hour)) > within_hours:
			continue
		return String(entry.get("text", ""))
	return ""


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
