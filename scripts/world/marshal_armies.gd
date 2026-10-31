## Saved expedition membership. Troops and purses remain owned by each lord's party.
extends RefCounted
const Data = preload("res://scripts/world/world_data.gd")
const Lords = preload("res://scripts/data/lords.gd")
const AutoResolve = preload("res://scripts/battle/auto_resolve.gd")
const Units = preload("res://scripts/data/units.gd")
const Politics = preload("res://scripts/data/politics.gd")

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
		elif army["state"] == "marching":
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
				if w.owner_of(army["target"]) == army["realm"] or not w.at_war(army["realm"], w.owner_of(army["target"])):
					return_home(w, army, "Target changed or peace declared")
				else:
					army["state"] = "besieging"
					army["destination"] = army["target"]
					army["siege_start"] = w.hour
					army["siege_prep_until"] = w.hour + Lords.SIEGE_PREP_HOURS
					var kind := String(Data.settlement(army["target"])["type"])
					army["siege_food_until"] = w.hour + float(Lords.SIEGE_FOOD_DAYS.get(kind, 5.0)) * 24.0
					w.emit_event({"type": "siege_started", "army": army["id"], "target": army["target"], "realm": army["realm"]})
		elif army["state"] == "besieging":
			p.node = army["target"]
			p.next = ""
			p.along = 0.0
			p.path.clear()
			p.wait = 0.0
			for member in members(w, army):
				member.node = p.node
				member.next = ""
				member.along = 0.0
				member.path.clear()
				member.wait = 0.0
			# Check relief force
			var relief_party = null
			for lp in w.lord_parties():
				if lp.node == army["target"] and not lp.moving() and w.at_war(lp.faction, army["realm"]):
					relief_party = lp
					break
			if relief_party != null:
				var besieger_won := _resolve_relief(w, army, relief_party)
				if not besieger_won or not w.campaign_armies.has(army):
					continue
			# Check food starvation
			if w.hour >= float(army.get("siege_food_until", 0.0)):
				capture_settlement(w, army, "starvation")
				continue
			# Check assault readiness
			if w.hour >= float(army.get("siege_prep_until", 0.0)):
				assault(w, army)
				continue
		elif army["state"] == "returning":
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
		var h: float = w._hours(p, muster, id)
		if is_inf(h): continue
		var value: float = h + w.men_of(w.garrison_at(id)) * 0.05
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

static func _resolve_relief(w, army: Dictionary, relief_party) -> bool:
	var p = leader(w, army)
	if p == null:
		return false
	var loser = w._ai_fight(p, relief_party)
	return loser != p

static func assault(w, army: Dictionary) -> void:
	var target: String = army["target"]
	if w.owner_of(target) == army["realm"] or not w.at_war(army["realm"], w.owner_of(target)):
		return_home(w, army, "Target changed or peace declared")
		return

	var attacker_squads: Array = []
	for member in members(w, army):
		for sq in member.army:
			if int(sq.get("men", 0)) > 0:
				attacker_squads.append(sq)

	var player_in_assault: bool = w.following_party != -1 and army["members"].has(w.following_party)
	var player_p = w.player() if player_in_assault else null
	if player_in_assault and player_p != null:
		for sq in player_p.army:
			if int(sq.get("men", 0)) > 0:
				attacker_squads.append(sq)

	if attacker_squads.is_empty():
		disband(w, army, "No attacking troops remain")
		return

	var garrison: Array = w.garrison_at(target)
	if w.men_of(garrison) == 0:
		capture_settlement(w, army, "assault")
		return

	var kind: String = Data.settlement(target)["type"]
	var wall_mult: float = float(AutoResolve.WALLS.get(kind, 1.4))
	var res: Dictionary = AutoResolve.resolve_siege(attacker_squads, garrison, wall_mult, w.rng)

	for sq in garrison:
		var entry = res["defender_squads"].get(int(sq["id"]))
		if entry:
			sq["men"] = int(entry["men"])
	w.garrisons[target] = garrison.filter(func(sq): return int(sq["men"]) > 0)

	for member in members(w, army):
		for sq in member.army:
			var entry = res["attacker_squads"].get(int(sq["id"]))
			if entry:
				sq["men"] = int(entry["men"])
		member.army = member.army.filter(func(sq): return int(sq["men"]) > 0)

	if player_in_assault and player_p != null:
		for sq in player_p.army:
			var entry = res["attacker_squads"].get(int(sq["id"]))
			if entry:
				sq["men"] = int(entry["men"])
		player_p.army = player_p.army.filter(func(sq): return int(sq["men"]) > 0)
		if res["attacker_won"]:
			w.emit_event({"type": "siege_loot", "silver": 150, "renown": 10, "target": target})

	w.emit_event({
		"type": "siege_assault",
		"army": army["id"],
		"target": target,
		"attacker_won": res["attacker_won"],
		"attacker_lost": res["attacker_lost"],
		"defender_lost": res["defender_lost"],
	})

	if w.has_method("add_weariness"):
		w.add_weariness(army["realm"], float(res["attacker_lost"]) * Politics.WEARINESS_CASUALTY)
		w.add_weariness(w.owner_of(target), float(res["defender_lost"]) * Politics.WEARINESS_CASUALTY)

	if res["attacker_won"]:
		capture_settlement(w, army, "assault")
	else:
		w.emit_event({"type": "siege_repulsed", "army": army["id"], "target": target})
		return_home(w, army, "Assault repulsed")

static func capture_settlement(w, army: Dictionary, reason: String) -> void:
	var target: String = army["target"]
	var realm: String = army["realm"]
	var was: String = w.owner_of(target)

	w.set_owner(target, realm)

	var surviving_attackers := 0
	for member in members(w, army):
		surviving_attackers += w.men_of(member.army)

	var cap: int = w.garrison_capacity(target)
	var desired: int = mini(int(cap * Lords.GARRISON_START_SHARE), int(surviving_attackers * 0.4))
	desired = mini(desired, maxi(0, surviving_attackers - 10))

	if desired > 0:
		var tpl: Array = w._garrison_template(target)
		var placed := 0
		for sq in tpl:
			if placed >= desired:
				break
			var room: int = Units.full_size(String(sq["unit"]))
			var to_add: int = mini(room, desired - placed)
			sq["men"] = to_add
			placed += to_add
		w.garrisons[target] = tpl.filter(func(s): return int(s["men"]) > 0)

		var to_remove := placed
		var mems := members(w, army)
		while to_remove > 0 and not mems.is_empty():
			var taken_this_pass := false
			for member in mems:
				if to_remove <= 0:
					break
				for sq in member.army:
					if int(sq.get("men", 0)) > 1:
						sq["men"] = int(sq["men"]) - 1
						to_remove -= 1
						taken_this_pass = true
						if to_remove <= 0:
							break
			if not taken_this_pass:
				for member in mems:
					if to_remove <= 0:
						break
					for sq in member.army:
						if int(sq.get("men", 0)) > 0:
							sq["men"] = int(sq["men"]) - 1
							to_remove -= 1
							if to_remove <= 0:
								break
				break
		for member in mems:
			member.army = member.army.filter(func(sq): return int(sq["men"]) > 0)

	w.emit_event({
		"type": "settlement_captured",
		"settlement": target,
		"realm": realm,
		"from": was,
		"by_army": army["id"],
		"reason": reason,
	})
	return_home(w, army, "Expedition successful: %s captured" % Data.settlement(target)["name"])
