## Saved expedition membership. Troops and purses remain owned by each lord's party.
extends RefCounted
const Data = preload("res://scripts/world/world_data.gd")
const Lords = preload("res://scripts/data/lords.gd")

static func for_party(w, party_id: int) -> Dictionary:
	for army in w.campaign_armies:
		if army["members"].has(party_id): return army
	return {}

static func members(w, army: Dictionary) -> Array:
	var result: Array = []
	for id in army["members"]:
		var p = w.party(int(id))
		if p != null: result.append(p)
	return result

static func leader(w, army: Dictionary):
	return w.party(int(army["leader"]))

static func disband(w, army: Dictionary, reason: String) -> void:
	for p in members(w, army):
		var lord: Dictionary = w.lord_of(p)
		lord["job"] = ""
		lord["target"] = ""
		lord["think_at"] = w.hour
		p.path.clear() # Finish the current road, then resume independent decisions.
		p.wait = 0.0
	w.emit_event({"type": "army_disbanded", "army": army["id"], "realm": army["realm"], "reason": reason})
	w.realms[army["realm"]]["marshal"] = -1
	w.army_ready_at[army["realm"]] = w.hour + Lords.ARMY_COOLDOWN
	w.campaign_armies.erase(army)

static func return_home(w, army: Dictionary, reason: String) -> void:
	var home: String = w.capital_of(army["realm"])
	var p = leader(w, army)
	if p == null or home == "" or not reachable(w, p, home):
		disband(w, army, reason)
		return
	army["state"] = "returning"
	army["reason"] = reason
	army["destination"] = home
	w.emit_event({"type": "army_returning", "army": army["id"], "realm": army["realm"], "target": home, "reason": reason})
	w._set_job(w.lord_of(p), p, "army", home)

static func reachable(w, p, target: String) -> bool:
	var start: String = p.next if p.moving() else p.node
	return start == target or not w.path(start, target).is_empty()

static func tick(w, dt: float) -> void:
	for army in w.campaign_armies.duplicate():
		var p = leader(w, army)
		if p == null or w.men_of(p.army) == 0:
			disband(w, army, "Marshal unavailable")
			continue
		# Remove defeated or empty members without creating replacement troops.
		army["members"] = army["members"].filter(func(id): return w.party(int(id)) != null and w.men_of(w.party(int(id)).army) > 0)
		if army["members"].size() < Lords.ARMY_MIN_MEMBERS:
			disband(w, army, "Not enough lords remain")
			continue
		if w.hour >= float(army["expires"]):
			disband(w, army, "Expedition timed out")
			continue
		if army["state"] != "returning" and (w.owner_of(army["target"]) != army["target_owner"] or not w.at_war(army["realm"], army["target_owner"])):
			if army["state"] == "gathering":
				disband(w, army, "Target changed or peace declared")
				continue
			return_home(w, army, "Target changed or peace declared")
			if not w.campaign_armies.has(army): continue
		if army["state"] == "gathering":
			if w.owner_of(army["muster"]) != army["realm"]:
				disband(w, army, "Muster site lost")
				continue
			var arrived: Array = []
			for member in members(w, army):
				if member.moving(): w._move(member, dt)
				if not member.moving() and member.node == army["muster"]: arrived.append(member.id)
			if arrived.size() == army["members"].size() or w.hour >= float(army["deadline"]):
				if not arrived.has(p.id) or arrived.size() < Lords.ARMY_MIN_MEMBERS:
					disband(w, army, "Muster timed out")
					continue
				for member in members(w, army):
					if not arrived.has(member.id):
						w.lord_of(member)["job"] = ""
						member.path.clear()
				army["members"] = arrived
				army["state"] = "marching"
				army["destination"] = army["target"]
				w._set_job(w.lord_of(p), p, "army", army["target"])
				w.emit_event({"type": "army_departed", "army": army["id"], "target": army["target"]})
		else:
			if not reachable(w, p, army["destination"]):
				disband(w, army, "No route to destination")
				continue
			if p.moving(): w._move(p, dt)
			for member in members(w, army):
				if member == p: continue
				member.node = p.node
				member.next = p.next
				member.along = p.along
				member.path = p.path.duplicate()
				member.wait = 0.0
			if not p.moving() and p.node == army["destination"]:
				if army["state"] == "marching":
					# Siege resolution is the next slice; expeditions never capture silently.
					w.emit_event({"type": "army_arrived", "army": army["id"], "target": army["target"]})
					return_home(w, army, "Expedition completed; returning home")
				else:
					disband(w, army, army.get("reason", "Returned home"))
	for realm in w.realms:
		if w.hour < float(w.army_ready_at.get(realm, 0.0)): continue
		if w.campaign_armies.any(func(a): return a["realm"] == realm): continue
		w.army_ready_at[realm] = w.hour + Lords.ARMY_RETRY_HOURS
		create(w, realm)

static func create(w, realm: String) -> void:
	var muster: String = w.capital_of(realm)
	if muster == "": return
	var eligible: Array = []
	for lord in w.lords:
		var p = w.party(int(lord["party"]))
		if lord["realm"] != realm or p == null or lord["raiding"] != "" or not for_party(w, p.id).is_empty(): continue
		if w.men_of(p.army) < int(lord["full"]) * Lords.ARMY_READY_SHARE or not reachable(w, p, muster): continue
		eligible.append(lord)
	eligible.sort_custom(func(a, b): return int(a["renown"]) > int(b["renown"]) if a["renown"] != b["renown"] else int(a["id"]) < int(b["id"]))
	if eligible.size() < Lords.ARMY_MIN_MEMBERS: return
	var marshal: Dictionary = eligible[0]
	var p = w.party(int(marshal["party"]))
	var best := ""
	var score := INF
	for id in Data.SETTLEMENTS:
		if Data.is_village(id) or not w.at_war(realm, w.owner_of(id)): continue
		var route: Array = w.path(muster, id)
		if route.is_empty(): continue
		var value: float = w.route_hours(muster, route) + w.men_of(w.garrison_at(id)) * 0.05
		if Data.settlement(id)["type"] == Data.TOWN: value -= 2.0
		if value < score:
			score = value
			best = id
	if best == "": return
	var army := {"id": w.next_army_id, "realm": realm, "leader": p.id, "members": [], "state": "gathering", "muster": muster,
		"target": best, "target_owner": w.owner_of(best), "destination": muster, "deadline": w.hour + Lords.ARMY_MUSTER_HOURS,
		"expires": w.hour + Lords.ARMY_EXPEDITION_HOURS, "reason": ""}
	w.next_army_id += 1
	for lord in eligible.slice(0, Lords.ARMY_MAX_MEMBERS):
		var member = w.party(int(lord["party"]))
		army["members"].append(member.id)
		w._set_job(lord, member, "army", muster)
	w.campaign_armies.append(army)
	w.realms[realm]["marshal"] = int(marshal["id"])
	w.emit_event({"type": "army_formed", "army": army["id"], "realm": realm, "marshal": marshal["name"], "target": best})
