## Small settlement jobs for independent companies: bounties, couriers, and village relief.
extends RefCounted

const WorldData = preload("res://scripts/world/world_data.gd")
const Cultures = preload("res://scripts/data/cultures.gd")

const TYPE_HUNT := "hunt"
const TYPE_COURIER := "courier"
const TYPE_RELIEF := "relief"
const TYPES := [TYPE_HUNT, TYPE_COURIER, TYPE_RELIEF]

const MAX_ACTIVE_JOBS := 3
const REFRESH_HOURS := 72.0
const HUNT_DEADLINE_HOURS := 72.0
const RELIEF_DEADLINE_HOURS := 96.0

const TITLES_BY_TYPE := {
	TYPE_HUNT: "Bounty: Hunt Marauders",
	TYPE_COURIER: "Courier: Urgent Dispatch",
	TYPE_RELIEF: "Relief: Village Provisions",
}


static func generate_jobs_for(settlement_id: String, world, rng: RandomNumberGenerator) -> Array:
	var out := []
	if world == null or not WorldData.SETTLEMENTS.has(settlement_id):
		return out

	var kind: String = String(WorldData.settlement(settlement_id).get("type", WorldData.VILLAGE))

	if kind == WorldData.VILLAGE:
		# Villages offer 1 job: relief or local marauder hunt
		if rng.randf() < 0.5:
			var relief := make_relief_job(settlement_id, world, rng)
			if not relief.is_empty():
				out.append(relief)
		else:
			var hunt := make_hunt_job(settlement_id, world, rng)
			if not hunt.is_empty():
				out.append(hunt)
			else:
				var relief_fb := make_relief_job(settlement_id, world, rng)
				if not relief_fb.is_empty():
					out.append(relief_fb)
	else:
		# Towns and castles offer up to 2 jobs: courier dispatch and/or hunt
		var courier := make_courier_job(settlement_id, world, rng)
		if not courier.is_empty():
			out.append(courier)
		var hunt_tc := make_hunt_job(settlement_id, world, rng)
		if not hunt_tc.is_empty():
			out.append(hunt_tc)

	return out


static func make_hunt_job(settlement_id: String, world, rng: RandomNumberGenerator) -> Dictionary:
	var bands: Array = world.bands()
	if bands.is_empty():
		return {}

	var s_pos: Vector2 = WorldData.pos(settlement_id)
	var best_band = null
	var best_dist := INF

	# Find closest band to the issuing settlement
	for b in bands:
		var b_pos: Vector2 = world.party_pos(b)
		var d := b_pos.distance_to(s_pos)
		if d < best_dist:
			best_dist = d
			best_band = b

	if best_band == null:
		best_band = bands[rng.randi_range(0, bands.size() - 1)]

	var b_name: String = String(best_band.name)
	var s_name: String = String(WorldData.settlement(settlement_id)["name"])
	var job_id := "hunt_%d_%d" % [int(best_band.id), int(world.hour)]

	return {
		"id": job_id,
		"type": TYPE_HUNT,
		"origin_settlement": settlement_id,
		"title": "Bounty: Hunt %s" % b_name,
		"description": "The marauders of %s have ambushed travelers near %s. Hunt down their band and scatter them." % [b_name, s_name],
		"deadline": world.hour + HUNT_DEADLINE_HOURS,
		"reward_silver": 160,
		"reward_renown": 5,
		"reward_relation": 5,
		"target_party_id": int(best_band.id),
		"target_name": b_name,
	}


static func make_courier_job(settlement_id: String, world, rng: RandomNumberGenerator) -> Dictionary:
	var candidates := []
	var s_pos: Vector2 = WorldData.pos(settlement_id)

	for id in WorldData.SETTLEMENTS:
		if id == settlement_id:
			continue
		var dist := WorldData.pos(id).distance_to(s_pos)
		# Reasonable distance: 150 to 800 units
		if dist >= 150.0 and dist <= 800.0:
			candidates.append(id)

	if candidates.is_empty():
		for id in WorldData.SETTLEMENTS:
			if id != settlement_id:
				candidates.append(id)

	if candidates.is_empty():
		return {}

	var dest_id: String = candidates[rng.randi_range(0, candidates.size() - 1)]
	var dest_name: String = String(WorldData.settlement(dest_id)["name"])
	var dest_kind: String = String(WorldData.settlement(dest_id).get("type", "town"))
	var recipient_title := "Bailiff" if dest_kind == WorldData.CASTLE else ("Magistrate" if dest_kind == WorldData.TOWN else "Elder")

	var travel_hours := 24.0
	if world.has_method("route_hours") and world.has_method("path"):
		var p: Array = world.path(settlement_id, dest_id)
		if not p.is_empty():
			travel_hours = world.route_hours(settlement_id, p)
	elif world.has_method("hours_to"):
		travel_hours = world.hours_to(dest_id)
	var deadline_hours: float = maxf(48.0, travel_hours * 2.5 + 24.0)
	var job_id := "courier_%s_%s_%d" % [settlement_id, dest_id, int(world.hour)]

	return {
		"id": job_id,
		"type": TYPE_COURIER,
		"origin_settlement": settlement_id,
		"destination_settlement": dest_id,
		"recipient_title": "%s of %s" % [recipient_title, dest_name],
		"title": "Courier: Dispatch to %s" % dest_name,
		"description": "Deliver a sealed dispatch to the %s of %s before the deadline." % [recipient_title, dest_name],
		"deadline": world.hour + deadline_hours,
		"reward_silver": 110,
		"reward_renown": 3,
		"reward_relation": 5,
	}


static func make_relief_job(settlement_id: String, world, rng: RandomNumberGenerator) -> Dictionary:
	var s_name: String = String(WorldData.settlement(settlement_id)["name"])
	var job_id := "relief_%s_%d" % [settlement_id, int(world.hour)]
	var food_needed := 15

	return {
		"id": job_id,
		"type": TYPE_RELIEF,
		"origin_settlement": settlement_id,
		"food_needed": food_needed,
		"title": "Relief: Provisions for %s" % s_name,
		"description": "Granaries at %s are running dry. Deliver %d rations of food to sustain the villagers." % [s_name, food_needed],
		"deadline": world.hour + RELIEF_DEADLINE_HOURS,
		"reward_silver": 80,
		"reward_renown": 5,
		"reward_relation": 10,
	}
