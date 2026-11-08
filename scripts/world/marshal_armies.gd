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
	w.army_outcomes[int(army["id"])] = reason
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
		var aim := String(army.get("aim", "storm"))
		if w.hour >= float(army["expires"]):
			disband(w, army, "The march held" if aim == "march" else "Expedition timed out")
			continue
		if aim != "storm":
			if _host_tick(w, army, p, dt):
				continue
		if aim == "storm" and army["state"] != "returning" and (w.owner_of(army["target"]) != army["target_owner"] or not w.at_war(army["realm"], army["target_owner"])):
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
		var _formed := create(w, realm)

## The members ride with the leader, wherever he is.
static func _keep_together(w, army: Dictionary, p) -> void:
	for member in members(w, army):
		if member == p: continue
		member.node = p.node
		member.next = p.next
		member.along = p.along
		member.path = p.path.duplicate()
		member.wait = 0.0


## A crown host on an aim other than storming walls: relieve a holding under siege, hold
## the march between two holdings, or raid an enemy's villages. True when it has handled
## this tick (the storm flow below is skipped).
static func _host_tick(w, army: Dictionary, p, dt: float) -> bool:
	var aim := String(army.get("aim", ""))
	var state := String(army["state"])
	if state == "returning":
		return false
	if state == "marching":
		if not reachable(w, p, army["destination"]):
			disband(w, army, "No route to destination")
			return true
		if p.moving(): w._move(p, dt)
		_keep_together(w, army, p)
		if p.moving() or p.node != army["destination"]:
			return true
		match aim:
			"relieve":
				if w.owner_of(army["target"]) != army["realm"]:
					return_home(w, army, "%s fell before they came" % Data.settlement(army["target"])["name"])
				else:
					army["state"] = "holding"
					army["hold_since"] = w.hour
			"march":
				var anchors: Array = army.get("anchors", [])
				if anchors.size() >= 2:
					army["destination"] = String(anchors[0]) if army["destination"] == String(anchors[1]) else String(anchors[1])
					w._set_job(w.lord_of(p), p, "army", army["destination"])
			"raid":
				var v := String(army["destination"])
				if w.is_burned(v) or not w.at_war(army["realm"], w.owner_of(v)):
					_next_raid(w, army, p)
				else:
					army["state"] = "raiding"
					army["raid_until"] = w.hour + Lords.RAID_HOURS
		return true
	if state == "holding":
		p.wait = 0.0
		_keep_together(w, army, p)
		if w.owner_of(army["target"]) != army["realm"]:
			return_home(w, army, "%s fell" % Data.settlement(army["target"])["name"])
		elif w.siege_info(army["target"]).is_empty() and w.hour >= float(army.get("hold_since", w.hour)) + Lords.THINK_HOURS:
			return_home(w, army, "The siege of %s is broken" % Data.settlement(army["target"])["name"])
		return true
	if state == "raiding":
		_keep_together(w, army, p)
		if w.hour >= float(army.get("raid_until", 0.0)):
			var l: Dictionary = w.lord_of(p)
			var v := String(army["destination"])
			w._burn(l, v)
			if w.is_burned(v):
				army["raided"] = int(army.get("raided", 0)) + 1
			_next_raid(w, army, p)
		return true
	return false


## On to the next village of the raid, or home once they're done.
static func _next_raid(w, army: Dictionary, p) -> void:
	var villages: Array = army.get("villages", [])
	var at := villages.find(String(army["destination"]))
	for i in range(at + 1, villages.size()):
		var v := String(villages[i])
		if not w.is_burned(v) and w.at_war(army["realm"], w.owner_of(v)) and reachable(w, p, v):
			army["state"] = "marching"
			army["destination"] = v
			w._set_job(w.lord_of(p), p, "army", v)
			return
	var n := int(army.get("raided", 0))
	return_home(w, army, "%d village%s burned" % [n, "" if n == 1 else "s"] if n > 0 else "The raid found nothing to burn")


## Gather an army of `realm`'s lords against its nearest enemy, or against `target` when
## its ruler names one (your crown's call to arms). Returns whether one formed.
static func create(w, realm: String, target: String = "") -> bool:
	var muster: String = w.capital_of(realm)
	if muster == "": return false
	var eligible: Array = []
	for lord in w.lords:
		var p = w.party(int(lord["party"]))
		if lord["realm"] != realm or p == null or lord["raiding"] != "" or not for_party(w, p.id).is_empty(): continue
		if _ordered(lord): continue
		if not _strong_enough(w, lord, p) or not reachable(w, p, muster): continue
		eligible.append(lord)
	eligible.sort_custom(func(a, b): return int(a["renown"]) > int(b["renown"]) if a["renown"] != b["renown"] else int(a["id"]) < int(b["id"]))
	if eligible.size() < Lords.ARMY_MIN_MEMBERS: return false
	var marshal: Dictionary = eligible[0]
	var p = w.party(int(marshal["party"]))
	var best := target
	# A realm's home capital in an enemy's hands is the first thing its army goes for,
	# whatever else is nearer or weaker held.
	if best == "":
		var lost: String = w.lost_capital(realm)
		if lost != "" and w.at_war(realm, w.owner_of(lost)) and not is_inf(w._hours(p, muster, lost)):
			best = lost
	var score := INF
	for id in Data.SETTLEMENTS:
		if best != "": break
		if Data.is_village(id) or not w.at_war(realm, w.owner_of(id)): continue
		var h: float = w._hours(p, muster, id)
		if is_inf(h): continue
		var value: float = h + w.men_of(w.garrison_at(id)) * 0.05
		if Data.settlement(id)["type"] == Data.TOWN: value -= 2.0
		if value < score:
			score = value
			best = id
	if best == "": return false
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
	return true


## Lords of `realm` who could answer a call to arms now.
static func ready_lords(w, realm: String) -> Array:
	var muster: String = w.capital_of(realm)
	var out := []
	for lord in w.lords:
		var p = w.party(int(lord["party"]))
		if lord["realm"] != realm or p == null or lord["raiding"] != "" or not for_party(w, p.id).is_empty(): continue
		if _ordered(lord): continue
		if not _strong_enough(w, lord, p) or muster == "" or not reachable(w, p, muster): continue
		out.append(lord)
	return out


## A lord under your orders (answering a muster, riding with you, holding a place) isn't
## free for a marshal's army.
static func _ordered(lord: Dictionary) -> bool:
	return lord.get("order") is Dictionary and not (lord["order"] as Dictionary).is_empty()


## Strong enough to ride: most of his warband, or rallied by your speech at table.
static func _strong_enough(w, lord: Dictionary, p) -> bool:
	return w.men_of(p.army) >= int(lord["full"]) * Lords.ARMY_READY_SHARE or float(lord.get("rallied_until", 0.0)) > w.hour


## Your war council's host, led by a lord: the lords already at the muster set out at once
## for `aim` ("storm" `target`, "relieve" `target`, "march" between `anchors`, "raid"
## `villages`), for `hours`. Returns the army, or {}.
static func create_host(w, realm: String, lord_ids: Array, marshal_id: int, muster: String, aim: String, target: String,
		anchors: Array, villages: Array, hours: float) -> Dictionary:
	var marshal: Dictionary = w.lord_by_id(marshal_id)
	var p = w.party(int(marshal.get("party", -1))) if not marshal.is_empty() else null
	if p == null:
		return {}
	var dest := target
	if aim == "march":
		dest = String(anchors[1]) if anchors.size() > 1 else target
	elif aim == "raid":
		dest = String(villages[0]) if not villages.is_empty() else ""
	if dest == "" or not reachable(w, p, dest):
		return {}
	var army := {"id": w.next_army_id, "realm": realm, "leader": p.id, "members": [], "state": "marching", "muster": muster,
		"target": dest if aim != "march" else target, "target_owner": w.owner_of(dest), "destination": dest, "deadline": w.hour,
		"expires": w.hour + hours, "reason": "", "aim": aim, "anchors": anchors.duplicate(), "villages": villages.duplicate(), "raided": 0, "host": true}
	w.next_army_id += 1
	for lid in lord_ids:
		var lord: Dictionary = w.lord_by_id(int(lid))
		var member = w.party(int(lord.get("party", -1))) if not lord.is_empty() else null
		if member == null:
			continue
		lord.erase("order")
		army["members"].append(member.id)
		if member != p:
			lord["job"] = "army"
			lord["target"] = dest
	w._set_job(marshal, p, "army", dest)
	w.campaign_armies.append(army)
	w.realms[realm]["marshal"] = marshal_id
	w.emit_event({"type": "army_formed", "army": army["id"], "realm": realm, "marshal": marshal["name"], "target": dest})
	return army

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
	# The player is asked first: to lead the assault beside the army, or to hold the walls
	# of their own fief. Declining lets it be settled as before.
	if not bool(army.get("player_answered", false)) and w.pending_assault.is_empty():
		var role := ""
		var gs = w._active_game_state()
		if player_in_assault:
			role = "lead"
		elif gs != null and gs.is_player_fief(target) and w.here() == target and w.following_party == -1 and w.encounter == -1:
			role = "defend"
		if role != "":
			w.pending_assault = {"army": int(army["id"]), "role": role, "target": target}
			w.emit_event({"type": "assault_ready", "army": army["id"], "role": role, "target": target})
			return
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
