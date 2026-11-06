## The king's court: calling the banners to a muster, the war council that sends them out
## (led by you, or by a lord), the host while it's in the field, your lords' petitions,
## and what a king does at his own table (a seat of honour, a grant before everyone, a
## speech, gifts, and the tourney's lists). The rules only; GameState `gs` holds the
## campaign (gs.muster, gs.banners, gs.hosted) and the kingdom and settlement screens say
## them.
extends RefCounted

const Data = preload("res://scripts/world/world_data.gd")
const Lords = preload("res://scripts/data/lords.gd")
const Gatherings = preload("res://scripts/data/gatherings.gd")
const Captains = preload("res://scripts/data/captains.gd")
const LordTalk = preload("res://scripts/world/lord_talk.gd")
const MarshalArmies = preload("res://scripts/world/marshal_armies.gd")

const STORM := "storm"
const RELIEVE := "relieve"
const MARCH := "march"
const RAID := "raid"

## A petition settled or refused isn't brought again for a week.
const PETITION_QUIET_HOURS := 168.0


# ---------------------------------------------------------------- the muster

## Who would answer a call to `place`: [{lord, status, why, hours, men}], those who'll come
## first. status: "comes", "refuses" (a bought lord who thinks too little of you), "holds"
## (under your order to hold a place), "captive", "away" (regrouping or already with an army).
static func roll(gs, place: String) -> Array:
	var w = gs.world
	var out := []
	for l in gs.crown_lords():
		var p = w.party(int(l.get("party", -1)))
		var e := {"lord": l, "status": "comes", "why": "", "hours": 0.0, "men": w.men_of(p.army) if p != null else w.men_of(l.get("army", []))}
		var order: Dictionary = l.get("order", {}) if l.get("order") is Dictionary else {}
		if String(l.get("state", "")) == "prisoner":
			e["status"] = "captive"
			e["why"] = "a captive of %s" % (String(Data.FACTIONS[String(l.get("captive_of", ""))]["name"]) if Data.FACTIONS.has(String(l.get("captive_of", ""))) else "the enemy")
		elif p == null or String(l.get("state", "")) != "field":
			e["status"] = "away"
			e["why"] = "regrouping after a defeat"
		elif not MarshalArmies.for_party(w, p.id).is_empty():
			e["status"] = "away"
			e["why"] = "in the field with an army"
		elif String(order.get("kind", "")) == "guard":
			e["status"] = "holds"
			e["why"] = "holds %s by your order" % Data.settlement(String(order["target"]))["name"]
		elif int(l.get("bought", 0)) == 1 and LordTalk.regard(gs, l) < 0:
			e["status"] = "refuses"
			e["why"] = "bought, and thinks too little of you to come"
		else:
			var from: String = p.next if p.moving() else p.node
			e["hours"] = w._hours(p, from, place)
			e["why"] = _ride_words(float(e["hours"]))
		out.append(e)
	var rank := {"comes": 0, "refuses": 1, "holds": 2, "away": 3, "captive": 4}
	out.sort_custom(func(a, b): return int(rank[a["status"]]) < int(rank[b["status"]]) if a["status"] != b["status"] else float(a["hours"]) < float(b["hours"]))
	return out


static func _ride_words(hours: float) -> String:
	if hours < 1.0:
		return "already there"
	if hours < 20.0:
		return "%d hours' ride" % ceili(hours)
	var d := ceili(hours / 24.0)
	return "%d day%s' ride" % [d, "" if d == 1 else "s"]


## Whether you can call the banners to `place` now. {ok, reason}
static func call_check(gs, place: String) -> Dictionary:
	var w = gs.world
	if not gs.is_crowned():
		return {"ok": false, "reason": "Only a crown calls the banners."}
	if not gs.muster.is_empty():
		return {"ok": false, "reason": "Your banners are already gathering at %s." % Data.settlement(String(gs.muster["place"]))["name"]}
	if not gs.banners.is_empty():
		return {"ok": false, "reason": "Your banners are already in the field."}
	if w.campaign_armies.any(func(a): return String(a["realm"]) == Data.CROWN):
		return {"ok": false, "reason": "Your army is already in the field."}
	if not gs.host_places().has(place):
		return {"ok": false, "reason": "Call them to a castle or town of your own."}
	if w.is_sieged(place):
		return {"ok": false, "reason": "%s is besieged." % Data.settlement(place)["name"]}
	var coming := roll(gs, place).filter(func(e): return e["status"] == "comes").size()
	if coming < Lords.ARMY_MIN_MEMBERS:
		return {"ok": false, "reason": "You need %d lords free to answer (%d %s)." % [Lords.ARMY_MIN_MEMBERS, coming, "is" if coming == 1 else "are"]}
	return {"ok": true, "reason": ""}


## Call every sworn lord to a muster at `place`. Lords free to come ride there and wait;
## a bought lord who thinks too little of you refuses, and is remembered for it.
static func call_banners(gs, place: String) -> bool:
	if not call_check(gs, place)["ok"]:
		return false
	var w = gs.world
	var lords := []
	var refused := []
	for e in roll(gs, place):
		var l: Dictionary = e["lord"]
		match String(e["status"]):
			"comes":
				l["order"] = {"kind": "muster", "target": place}
				l["think_at"] = w.hour
				lords.append(int(l["id"]))
			"refuses":
				LordTalk.change_regard(gs, l, Lords.MUSTER_REFUSED_REGARD)
				refused.append(int(l["id"]))
	gs.muster = {"place": place, "called_hour": w.hour, "lords": lords, "refused": refused,
		"fed_day": int(w.hour / 24.0), "hungry_days": 0}
	w.emit_event({"type": "banners_called", "settlement": place, "lords": lords.size()})
	gs._note("Riders go out with your summons: %d lord%s ride for %s.%s" % [lords.size(), "" if lords.size() == 1 else "s",
		Data.settlement(place)["name"], (" %d refused (%d Regard)." % [refused.size(), Lords.MUSTER_REFUSED_REGARD]) if not refused.is_empty() else ""])
	gs.save_game()
	return true


## The lords of the muster still answering it (not taken, not gone over).
static func muster_lords(gs) -> Array:
	var out := []
	if gs.muster.is_empty():
		return out
	for lid in gs.muster.get("lords", []):
		var l: Dictionary = gs.world.lord_by_id(int(lid))
		if l.is_empty() or String(l.get("realm", "")) != Data.CROWN or String(l.get("state", "")) != "field":
			continue
		var order: Dictionary = l.get("order", {}) if l.get("order") is Dictionary else {}
		if String(order.get("kind", "")) == "muster":
			out.append(l)
	return out


## The lords of the muster already in the hall.
static func arrived(gs) -> Array:
	var w = gs.world
	var place := String(gs.muster.get("place", ""))
	return muster_lords(gs).filter(func(l):
		var p = w.party(int(l.get("party", -1)))
		return p != null and not p.moving() and p.node == place)


## What it costs the treasury a day to feed the muster.
static func muster_upkeep(gs) -> int:
	var men := 0
	for l in muster_lords(gs):
		var p = gs.world.party(int(l.get("party", -1)))
		if p != null:
			men += gs.world.men_of(p.army)
	return int(ceil(men / 10.0)) * Lords.MUSTER_SILVER_PER_10


## Send everyone home: the muster, or the host in the field.
static func dismiss(gs, why: String = "") -> void:
	var w = gs.world
	for l in muster_lords(gs):
		l.erase("order")
		l["think_at"] = w.hour
	if not gs.muster.is_empty():
		gs.muster = {}
		w.army_ready_at[Data.CROWN] = w.hour + Lords.ARMY_COOLDOWN
		gs._note(why if why != "" else "You dismiss the banners. Your lords ride home.")
	if not gs.banners.is_empty():
		_release_host(gs, why if why != "" else "You dismiss the banners. Your lords ride home.")
	gs.save_game()


# ---------------------------------------------------------------- the war council

## Whether the council can sit: enough lords in the hall. {ok, reason}
static func council_check(gs) -> Dictionary:
	if gs.muster.is_empty():
		return {"ok": false, "reason": "Call the banners first."}
	var n := arrived(gs).size()
	if n < Lords.ARMY_MIN_MEMBERS:
		return {"ok": false, "reason": "%d of %d lords in the hall; the council sits with %d." % [n, muster_lords(gs).size(), Lords.ARMY_MIN_MEMBERS]}
	return {"ok": true, "reason": ""}


## What the council could set out to do: [{id, aim, target, label, sub, ok, reason,
## anchors, villages}]. Storm the nearest enemy castles and towns; relieve a holding of
## yours under siege; hold the march between your seat and the border; raid an enemy's
## villages.
static func aims(gs) -> Array:
	var w = gs.world
	var place := String(gs.muster.get("place", w.capital_of(Data.CROWN)))
	var out := []
	var leader = _sample_party(gs)
	var hours := func(to: String) -> float: return w._hours(leader, place, to) if leader != null else 0.0
	# Storm.
	var storm := []
	for id in Data.SETTLEMENTS:
		if Data.is_village(id) or not w.at_war(Data.CROWN, w.owner_of(id)):
			continue
		storm.append(id)
	storm.sort_custom(func(a, b): return hours.call(a) < hours.call(b))
	for id in storm.slice(0, 3):
		out.append({"id": "storm_" + id, "aim": STORM, "target": id, "ok": true, "reason": "",
			"label": "Storm %s" % Data.settlement(id)["name"],
			"sub": "%s · garrison %d" % [_ride_words(hours.call(id)), w.men_of(w.garrison_at(id))]})
	if storm.is_empty():
		out.append({"id": "storm", "aim": STORM, "target": "", "ok": false, "reason": "you're at war with no one who holds walls",
			"label": "Storm a castle", "sub": ""})
	# Relieve.
	var besieged: Array = gs.crown_holdings().filter(func(id): return not w.siege_info(id).is_empty())
	besieged.sort_custom(func(a, b): return hours.call(a) < hours.call(b))
	if besieged.is_empty():
		out.append({"id": "relieve", "aim": RELIEVE, "target": "", "ok": false, "reason": "none of yours is besieged",
			"label": "Relieve a siege", "sub": "none of yours is besieged"})
	else:
		var b: String = besieged[0]
		out.append({"id": "relieve_" + b, "aim": RELIEVE, "target": b, "ok": true, "reason": "",
			"label": "Relieve %s" % Data.settlement(b)["name"],
			"sub": "%s · %d men camped under its walls" % [_ride_words(hours.call(b)), int(w.siege_info(b).get("attackers", 0))]})
	# Hold the march: between the muster and your holding nearest the enemy.
	var edge := ""
	var best := INF
	for id in gs.crown_holdings():
		if id == place:
			continue
		for other in Data.SETTLEMENTS:
			if w.at_war(Data.CROWN, w.owner_of(other)) and w.owner_of(other) != Data.BANDITS:
				var d: float = Data.pos(id).distance_to(Data.pos(other))
				if d < best:
					best = d
					edge = id
	if edge == "":
		out.append({"id": "march", "aim": MARCH, "target": "", "ok": false, "reason": "you hold nowhere else to march to",
			"label": "Hold the march", "sub": "you hold nowhere else to march to"})
	else:
		out.append({"id": "march_" + edge, "aim": MARCH, "target": edge, "anchors": [place, edge], "ok": true, "reason": "",
			"label": "Hold the march", "sub": "ride between %s and %s" % [Data.settlement(place)["name"], Data.settlement(edge)["name"]]})
	# Raid.
	var villages := []
	for id in Data.SETTLEMENTS:
		if Data.is_village(id) and not w.is_burned(id) and w.at_war(Data.CROWN, w.owner_of(id)) and w.owner_of(id) != Data.BANDITS:
			villages.append(id)
	villages.sort_custom(func(a, b): return hours.call(a) < hours.call(b))
	villages = villages.slice(0, Lords.HOST_RAID_VILLAGES)
	if villages.is_empty():
		out.append({"id": "raid", "aim": RAID, "target": "", "ok": false, "reason": "no enemy village to burn",
			"label": "Raid their villages", "sub": "no enemy village within reach"})
	else:
		var realm: String = w.owner_of(villages[0])
		var honorable := arrived(gs).filter(func(l): return String(l.get("bearing", "")) == Lords.HONORABLE).size()
		out.append({"id": "raid_" + realm, "aim": RAID, "target": villages[0], "villages": villages, "ok": true, "reason": "",
			"label": "Raid %s's villages" % gs.realm_word(realm),
			"sub": "%s%s" % [" and ".join(villages.map(func(v): return String(Data.settlement(v)["name"]))),
				(" · %d Honorable lord%s won't ride" % [honorable, "" if honorable == 1 else "s"]) if honorable > 0 else ""]})
	return out


static func _sample_party(gs):
	for l in muster_lords(gs):
		var p = gs.world.party(int(l.get("party", -1)))
		if p != null:
			return p
	return gs.world.player()


## What a lord in the hall says, by bearing: {aim, says}.
static func counsel(gs, l: Dictionary) -> Dictionary:
	var w = gs.world
	var all := aims(gs)
	var first_storm := ""
	var relieve := ""
	for a in all:
		if String(a["aim"]) == STORM and bool(a["ok"]) and first_storm == "":
			first_storm = String(a["target"])
		if String(a["aim"]) == RELIEVE and bool(a["ok"]):
			relieve = String(a["target"])
	var name := func(id: String) -> String: return String(Data.settlement(id)["name"]) if id != "" else "their walls"
	var title := "my king"
	match String(l.get("bearing", "")):
		Lords.DARING:
			return {"aim": STORM, "says": "\"%s. Give me the first ladder, %s.\"" % [name.call(first_storm), title]}
		Lords.CAUTIOUS:
			if relieve != "":
				return {"aim": RELIEVE, "says": "\"%s holds out for us. Break the siege before we start one of our own.\"" % name.call(relieve)}
			return {"aim": MARCH, "says": "\"Hold what we have, %s. Ride the border, and let them come to us.\"" % title}
		Lords.CRUEL:
			return {"aim": RAID, "says": "\"Burn their villages and their lords will come out to us. Cheaper than a siege.\""}
		Lords.HONORABLE:
			if relieve != "":
				return {"aim": RELIEVE, "says": "\"Our people at %s are starving behind their walls. We go to them first.\"" % name.call(relieve)}
			return {"aim": STORM, "says": "\"%s's walls are high. High walls fall to patient men. And we burn no farms on the way.\"" % name.call(first_storm)}
	return {"aim": STORM, "says": "\"I'll ride where you ride.\""}


## Who could lead if you don't: a Daring lord offers; otherwise the most renowned in the hall.
static func lord_marshal(gs) -> Dictionary:
	var here := arrived(gs)
	if here.is_empty():
		return {}
	here.sort_custom(func(a, b):
		var da := String(a.get("bearing", "")) == Lords.DARING
		var db := String(b.get("bearing", "")) == Lords.DARING
		if da != db:
			return da
		return int(a.get("renown", 0)) > int(b.get("renown", 0)))
	return here[0]


## The provisions: {men, days, cost, treasury, paid}. Paid from the treasury, the host stays
## out six days; on what the lords carry, three.
static func provisions(gs) -> Dictionary:
	var men := 0
	for l in arrived(gs):
		var p = gs.world.party(int(l.get("party", -1)))
		if p != null:
			men += gs.world.men_of(p.army)
	var cost := int(ceil(men * Lords.HOST_PROVISION_DAYS / 10.0))
	var treasury: int = gs.crown_treasury()
	return {"men": men, "days": Lords.HOST_PROVISION_DAYS, "cost": cost, "treasury": treasury, "paid": treasury >= cost}


## Whether the council can send this host: `aim` an entry from aims(); led by you or a lord.
static func march_check(gs, aim: Dictionary, led_by_you: bool) -> Dictionary:
	var c := council_check(gs)
	if not c["ok"]:
		return c
	if not bool(aim.get("ok", false)):
		return {"ok": false, "reason": String(aim.get("reason", "not now"))}
	if String(aim["aim"]) == RAID and led_by_you:
		return {"ok": false, "reason": "your company doesn't burn farms; name a lord to lead the raid"}
	var riders := arrived(gs)
	if String(aim["aim"]) == RAID:
		riders = riders.filter(func(l): return String(l.get("bearing", "")) != Lords.HONORABLE)
	if riders.size() < (1 if led_by_you else Lords.ARMY_MIN_MEMBERS):
		return {"ok": false, "reason": "too few lords would ride"}
	return {"ok": true, "reason": ""}


## The council decides. Every lord in the hall rides (+5 Regard, once), except an
## Honorable lord asked to raid, who goes home; a lord whose counsel you passed over
## grumbles; lords still on the road go home. Led by you, the host follows your company and
## fights where you fight; led by a lord, it marches on its own as a marshal's army.
static func march(gs, aim: Dictionary, led_by_you: bool) -> bool:
	if not march_check(gs, aim, led_by_you)["ok"]:
		return false
	var w = gs.world
	var place := String(gs.muster["place"])
	var prov := provisions(gs)
	var riders := []
	var lines := PackedStringArray()
	for l in arrived(gs):
		var c := counsel(gs, l)
		if String(aim["aim"]) == RAID and String(l.get("bearing", "")) == Lords.HONORABLE:
			LordTalk.change_regard(gs, l, Lords.RAID_REFUSED_REGARD)
			l.erase("order")
			l["think_at"] = w.hour
			lines.append("%s will not burn farms, and rides home (%d Regard)." % [LordTalk.short_name(l), Lords.RAID_REFUSED_REGARD])
			continue
		LordTalk.change_regard(gs, l, Lords.MUSTER_RIDE_REGARD)
		if String(c["aim"]) != String(aim["aim"]):
			LordTalk.change_regard(gs, l, Lords.COUNSEL_IGNORED_REGARD)
		riders.append(l)
	# Those still on the road go home.
	for l in muster_lords(gs):
		if not riders.has(l):
			l.erase("order")
			l["think_at"] = w.hour
	var paid: bool = prov["paid"]
	if paid:
		w.realms[Data.CROWN]["treasury"] = int(w.realms[Data.CROWN]["treasury"]) - int(prov["cost"])
	var hours := Lords.HOST_PAID_HOURS if paid else Lords.HOST_UNPAID_HOURS
	var host := {"aim": String(aim["aim"]), "target": String(aim.get("target", "")), "anchors": (aim.get("anchors", []) as Array).duplicate(),
		"villages": (aim.get("villages", []) as Array).duplicate(), "led": "you" if led_by_you else "lord", "army_id": -1,
		"lords": riders.map(func(l): return int(l["id"])), "until": w.hour + hours, "paid": paid, "place": place, "label": String(aim["label"])}
	if led_by_you:
		for l in riders:
			l["order"] = {"kind": "follow", "target": ""}
			l["think_at"] = w.hour
	else:
		var marshal := lord_marshal(gs)
		if not riders.has(marshal):
			marshal = riders[0]
		var army: Dictionary = MarshalArmies.create_host(w, Data.CROWN, riders.map(func(l): return int(l["id"])), int(marshal["id"]), place,
			String(aim["aim"]), String(aim.get("target", "")), host["anchors"], host["villages"], hours)
		if army.is_empty():
			return false
		host["army_id"] = int(army["id"])
		host["marshal"] = int(marshal["id"])
	gs.muster = {}
	gs.banners = host
	w.emit_event({"type": "banners_march", "settlement": place, "aim": String(aim["aim"]), "target": String(aim.get("target", ""))})
	var who := "you lead" if led_by_you else "%s leads" % LordTalk.short_name(w.lord_by_id(int(host["marshal"])))
	var label := String(aim["label"])
	gs._note("The council rises. %d lord%s ride to %s; %s. %s%s" % [riders.size(), "" if riders.size() == 1 else "s", label.left(1).to_lower() + label.substr(1), who,
		("Provisions for six days from the treasury (%d silver)." % int(prov["cost"])) if paid else "The treasury can't pay their provisions: they'll stay out three days.",
		(" " + " ".join(lines)) if not lines.is_empty() else ""])
	gs.save_game()
	return true


# ---------------------------------------------------------------- in the field

## The host you lead: the lords riding with you under your banners.
static func host_lords(gs) -> Array:
	var out := []
	for lid in gs.banners.get("lords", []):
		var l: Dictionary = gs.world.lord_by_id(int(lid))
		if not l.is_empty() and String(l.get("realm", "")) == Data.CROWN and String(l.get("state", "")) == "field":
			out.append(l)
	return out


## The marshal's army of a host a lord leads, or {}.
static func host_army(gs) -> Dictionary:
	var id := int(gs.banners.get("army_id", -1))
	for a in gs.world.campaign_armies:
		if int(a["id"]) == id:
			return a
	return {}


## Where the host stands with its aim: a line for the journal and the Court tab.
static func host_status(gs) -> String:
	var w = gs.world
	var b: Dictionary = gs.banners
	if b.is_empty():
		return ""
	var days := maxf(0.0, (float(b["until"]) - w.hour) / 24.0)
	var left := "%d day%s of provisions" % [ceili(days), "" if ceili(days) == 1 else "s"]
	if String(b["led"]) == "you":
		return "%s · %d lord%s ride with you · %s" % [String(b.get("label", "")), host_lords(gs).size(), "" if host_lords(gs).size() == 1 else "s", left]
	var army := host_army(gs)
	var state := String(army.get("state", "marching"))
	var marshal: Dictionary = w.lord_by_id(int(b.get("marshal", -1)))
	return "%s · led by %s · %s · %s" % [String(b.get("label", "")), LordTalk.short_name(marshal) if not marshal.is_empty() else "a lord", state, left]


static func _release_host(gs, why: String) -> void:
	var w = gs.world
	var b: Dictionary = gs.banners
	if String(b.get("led", "")) == "you":
		for l in host_lords(gs):
			var order: Dictionary = l.get("order", {}) if l.get("order") is Dictionary else {}
			if String(order.get("kind", "")) == "follow":
				l.erase("order")
				l["think_at"] = w.hour
	else:
		var army := host_army(gs)
		if not army.is_empty():
			MarshalArmies.disband(w, army, why)
	gs.banners = {}
	w.army_ready_at[Data.CROWN] = w.hour + Lords.ARMY_COOLDOWN
	gs._note(why)


## Whether the host you lead has done what it set out to do, and how to say so, or "".
static func _host_done(gs) -> String:
	var w = gs.world
	var b: Dictionary = gs.banners
	var target := String(b.get("target", ""))
	match String(b.get("aim", "")):
		STORM:
			if target != "" and w.owner_of(target) == Data.CROWN:
				return "%s is yours. Your banners go home with the glory of it." % Data.settlement(target)["name"]
		RELIEVE:
			if target != "" and w.siege_info(target).is_empty():
				return "The siege of %s is broken. Your banners go home." % Data.settlement(target)["name"] if w.owner_of(target) == Data.CROWN \
					else "%s fell before the siege could be broken. Your banners go home." % Data.settlement(target)["name"]
	return ""


## Each hour: feed the muster day by day, and watch the host in the field.
static func step(gs) -> void:
	var w = gs.world
	if w == null or not gs.is_crowned():
		if not gs.muster.is_empty() or not gs.banners.is_empty():
			gs.muster = {}
			gs.banners = {}
		return
	if not gs.muster.is_empty():
		var today := int(w.hour / 24.0)
		while int(gs.muster.get("fed_day", today)) < today and not gs.muster.is_empty():
			gs.muster["fed_day"] = int(gs.muster["fed_day"]) + 1
			var cost := muster_upkeep(gs)
			if gs.crown_treasury() >= cost:
				w.realms[Data.CROWN]["treasury"] = gs.crown_treasury() - cost
				gs.muster["hungry_days"] = 0
			else:
				gs.muster["hungry_days"] = int(gs.muster.get("hungry_days", 0)) + 1
				if int(gs.muster["hungry_days"]) > Lords.MUSTER_HUNGRY_DAYS:
					dismiss(gs, "The treasury can't feed the muster at %s; your lords ride home." % Data.settlement(String(gs.muster["place"]))["name"])
		if not gs.muster.is_empty() and (w.owner_of(String(gs.muster["place"])) != Data.CROWN or muster_lords(gs).is_empty()):
			dismiss(gs, "The muster at %s breaks up." % Data.settlement(String(gs.muster["place"]))["name"])
	if not gs.banners.is_empty():
		var b: Dictionary = gs.banners
		if String(b["led"]) == "lord":
			if host_army(gs).is_empty():
				var why := String(w.army_outcomes.get(int(b.get("army_id", -1)), "Your banners are home."))
				gs.banners = {}
				gs._note("Your banners are home: %s." % why.to_lower().trim_suffix(".") if not why.ends_with("home.") else why)
			return
		var done := _host_done(gs)
		if done != "":
			_release_host(gs, done)
		elif w.hour >= float(b["until"]):
			_release_host(gs, "Your banners go home: %s." % ("the march held" if String(b["aim"]) == MARCH else "their provisions are spent"))
		elif host_lords(gs).is_empty():
			gs.banners = {}
			gs._note("None of your lords is left to ride with you.")


## The muster and the host in the field, as journal entries.
static func commitments(gs) -> Array:
	var out := []
	var w = gs.world
	if w == null:
		return out
	if not gs.muster.is_empty():
		var place := String(gs.muster["place"])
		var here := arrived(gs).size()
		var all := muster_lords(gs).size()
		var c := council_check(gs)
		out.append({"id": "muster", "kind": "muster", "title": "Your banners gather at %s" % Data.settlement(place)["name"],
			"objective": "%d of %d lords there. %s" % [here, all, "The war council can sit when you're in the hall." if c["ok"] else String(c["reason"])],
			"place": place, "reward": "%d lords' men under your banners" % all,
			"cost": "%d silver a day from the treasury" % muster_upkeep(gs), "hours_left": -1.0, "blocked": ""})
	if not gs.banners.is_empty():
		var b: Dictionary = gs.banners
		var target := String(b.get("target", ""))
		out.append({"id": "banners", "kind": "banners", "title": "Your banners: %s" % String(b.get("label", "in the field")),
			"objective": host_status(gs) + (". They follow you and fight where you fight." if String(b["led"]) == "you" else "."),
			"place": target if Data.SETTLEMENTS.has(target) else "", "reward": "", "cost": "",
			"hours_left": maxf(0.0, float(b["until"]) - w.hour), "blocked": ""})
	return out


static func load_muster(raw) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY or (raw as Dictionary).is_empty():
		return {}
	return {"place": String(raw.get("place", "")), "called_hour": float(raw.get("called_hour", 0.0)),
		"lords": (raw.get("lords", []) as Array).map(func(x): return int(x)), "refused": (raw.get("refused", []) as Array).map(func(x): return int(x)),
		"fed_day": int(raw.get("fed_day", 0)), "hungry_days": int(raw.get("hungry_days", 0))}


static func load_banners(raw) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY or (raw as Dictionary).is_empty():
		return {}
	var b: Dictionary = (raw as Dictionary).duplicate(true)
	b["lords"] = (b.get("lords", []) as Array).map(func(x): return int(x))
	b["army_id"] = int(b.get("army_id", -1))
	b["marshal"] = int(b.get("marshal", -1))
	b["until"] = float(b.get("until", 0.0))
	return b


# ---------------------------------------------------------------- petitions

## What your sworn lords ask of you: [{lord, kind, text, settle, table, refuse}]. kind
## "bandits" (a band preys on their lands: you take the hunt), "fief" (a lord without land
## asks for a castle you have to give), "heard" (a lord who thinks little of you wants to
## be heard), "rebuild" (their seat was burned: silver from the treasury).
static func petitions(gs) -> Array:
	var w = gs.world
	var out := []
	if not gs.is_crowned():
		return out
	var free_fiefs: Array = gs.crown_fiefs().filter(func(id): return gs.holder_of(id).is_empty())
	var bands := {}
	for l in gs.crown_lords():
		if String(l.get("state", "")) != "field":
			continue
		if w.hour < float(LordTalk.record(l).get("petition_at", -100000.0)) + PETITION_QUIET_HOURS:
			continue
		var name := LordTalk.short_name(l)
		var fief := String(l.get("fief", ""))
		if fief == "" and not free_fiefs.is_empty():
			# Each castle you have free is asked for by one lord at a time.
			var want: String = free_fiefs.pop_front()
			out.append({"lord": l, "kind": "fief", "fief": want,
				"text": "%s asks for %s." % [name, Data.settlement(want)["name"]],
				"settle": "Grant it", "table": "a grant before everyone: +%d" % Gatherings.PUBLIC_GRANT_REGARD, "refuse": true})
			continue
		if fief != "" and w.is_burned(fief):
			out.append({"lord": l, "kind": "rebuild", "fief": fief,
				"text": "%s asks for silver to rebuild %s." % [name, Data.settlement(fief)["name"]],
				"settle": "100 silver from the treasury", "table": "", "refuse": true})
			continue
		if LordTalk.regard(gs, l) < 0:
			out.append({"lord": l, "kind": "heard", "text": "%s wishes to be heard." % name,
				"settle": "Hear them out", "table": "an hour at table", "refuse": false})
			continue
		var tr := LordTalk.trouble(gs, l)
		# A band that preys on several lords' lands is one petition, from the first to ask.
		if String(tr.get("kind", "")) == "bandits" and not bands.has(int(tr["band"])):
			bands[int(tr["band"])] = true
			out.append({"lord": l, "kind": "bandits", "text": "%s: %s prey on their lands." % [name, String(tr["name"])],
				"settle": "Take up the hunt", "table": "", "refuse": true})
	return out


## Whether `l` is at your table now (your gathering, on, you both in the hall).
static func at_table(gs, l: Dictionary) -> bool:
	var g: Dictionary = gs.gathering_here()
	return gs.gathering_is_mine(g) and gs.gathering_lords(g).has(l)


## Answer a petition: settled (heard at table if you're both at your gathering: +5 Regard,
## else +2) or refused (−5). {ok, reason, text}
static func answer(gs, p: Dictionary, settle: bool) -> Dictionary:
	var w = gs.world
	var l: Dictionary = p["lord"]
	var table := at_table(gs, l)
	var name := LordTalk.short_name(l)
	if not settle:
		if not bool(p.get("refuse", false)):
			return {"ok": false, "reason": "you can't refuse to hear a lord"}
		LordTalk.change_regard(gs, l, Gatherings.PETITION_REFUSED)
		LordTalk.record(l)["petition_at"] = w.hour
		gs.save_game()
		return {"ok": true, "text": "You refuse %s%s (%d Regard)." % [name, " before the hall" if table else "", Gatherings.PETITION_REFUSED]}
	var gain := Gatherings.PETITION_TABLE if table else Gatherings.PETITION_AFAR
	var text := ""
	match String(p["kind"]):
		"fief":
			var fief := String(p["fief"])
			if table:
				var r := public_grant(gs, fief, int(l["id"]))
				if not bool(r["ok"]):
					return r
				LordTalk.record(l)["petition_at"] = w.hour
				return r
			if not gs.grant_fief(fief, int(l["id"])):
				return {"ok": false, "reason": String(gs.grant_check(fief, int(l["id"]))["reason"])}
			gain = 0
			text = "You grant %s to %s." % [Data.settlement(fief)["name"], name]
		"rebuild":
			if gs.crown_treasury() < 100:
				return {"ok": false, "reason": "the treasury hasn't 100 silver"}
			w.realms[Data.CROWN]["treasury"] = gs.crown_treasury() - 100
			l["silver"] = int(l.get("silver", 0)) + 100
			text = "100 silver from the treasury to rebuild %s." % Data.settlement(String(p["fief"]))["name"]
		"heard":
			if table and w.wait(Gatherings.PETITION_HOURS):
				gs.advance(Gatherings.PETITION_HOURS)
			text = "You hear %s out%s." % [name, ", over the length of an evening" if table else ""]
		"bandits":
			var job: Dictionary = LordTalk.take_trouble(gs, l)
			if job.is_empty():
				return {"ok": false, "reason": "your journal is full, or the band is gone"}
			text = "You take up the hunt for %s." % name
		_:
			return {"ok": false, "reason": ""}
	if gain != 0:
		LordTalk.change_regard(gs, l, gain)
		text += " +%d Regard%s." % [gain, " (heard at your table)" if table else ""]
	LordTalk.record(l)["petition_at"] = w.hour
	if table and not gs.hosted.is_empty():
		(gs.hosted["heard"] as Array).append(int(l["id"]))
	gs.save_game()
	return {"ok": true, "text": text}


# ---------------------------------------------------------------- the king's table

## Whether you're at your own table: your gathering, on, and you in the hall. The gathering, or {}.
static func table(gs) -> Dictionary:
	var g: Dictionary = gs.gathering_here()
	return g if gs.gathering_is_mine(g) else {}


## A seat at your right hand for one lord in the hall; those of more renown feel passed over.
static func honour(gs, lord_id: int) -> Dictionary:
	var g := table(gs)
	if g.is_empty() or int(gs.hosted.get("honoured", -1)) >= 0:
		return {"ok": false}
	var l: Dictionary = gs.world.lord_by_id(lord_id)
	if l.is_empty() or not gs.gathering_lords(g).has(l):
		return {"ok": false}
	gs.hosted["honoured"] = lord_id
	LordTalk.change_regard(gs, l, Gatherings.HONOUR_REGARD)
	var passed := 0
	for o in gs.gathering_lords(g):
		if o != l and int(o.get("renown", 0)) > int(l.get("renown", 0)):
			LordTalk.change_regard(gs, o, Gatherings.PASSED_OVER_REGARD)
			passed += 1
	gs.save_game()
	return {"ok": true, "text": "%s sits at your right hand (+%d Regard).%s" % [LordTalk.short_name(l), Gatherings.HONOUR_REGARD,
		(" %d lord%s of more renown feel passed over (%d)." % [passed, "" if passed == 1 else "s", Gatherings.PASSED_OVER_REGARD]) if passed > 0 else ""]}


## Grant a castle or town before everyone at your table: +30 Regard with the lord rather
## than +15, and every other lord in the hall sees a king who rewards his own (+3).
static func public_grant(gs, fief: String, lord_id: int) -> Dictionary:
	var g := table(gs)
	if g.is_empty():
		return {"ok": false, "reason": "only at your own table"}
	var check: Dictionary = gs.grant_check(fief, lord_id)
	if not check["ok"]:
		return {"ok": false, "reason": String(check["reason"])}
	var l: Dictionary = gs.world.lord_by_id(lord_id)
	gs.grant_fief(fief, lord_id, Gatherings.PUBLIC_GRANT_REGARD)
	var seen := 0
	for o in gs.gathering_lords(g):
		if o != l:
			LordTalk.change_regard(gs, o, Gatherings.PUBLIC_GRANT_WITNESS)
			seen += 1
	gs.save_game()
	return {"ok": true, "text": "Before the whole hall you grant %s to %s (+%d Regard). %d lord%s see a king who rewards his own (+%d)." % [
		Data.settlement(fief)["name"], LordTalk.short_name(l), Gatherings.PUBLIC_GRANT_REGARD, seen, "" if seen == 1 else "s", Gatherings.PUBLIC_GRANT_WITNESS]}


static func speech_check(gs) -> Dictionary:
	if table(gs).is_empty():
		return {"ok": false, "reason": "only at your own table"}
	if bool(gs.hosted.get("speech", false)):
		return {"ok": false, "reason": "spoken once already"}
	if gs.renown < Gatherings.SPEECH_RENOWN:
		return {"ok": false, "reason": "renown %d of %d" % [gs.renown, Gatherings.SPEECH_RENOWN]}
	return {"ok": true, "reason": ""}


## The king stands to speak: everyone in the hall thinks a little better of you; at war,
## it makes the case, and your sworn lords count as ready to ride for a week.
static func speech(gs) -> Dictionary:
	if not speech_check(gs)["ok"]:
		return {"ok": false}
	var w = gs.world
	var g := table(gs)
	gs.hosted["speech"] = true
	var at_war: bool = not w.crown_enemies().is_empty()
	gs.hosted["speech_war"] = at_war
	var n := 0
	for l in gs.gathering_lords(g):
		LordTalk.change_regard(gs, l, Gatherings.SPEECH_REGARD)
		n += 1
		if at_war and String(l.get("realm", "")) == Data.CROWN:
			l["rallied_until"] = w.hour + Gatherings.SPEECH_READY_HOURS
	gs.save_game()
	var words := "\"We hold what we hold because we hold together. Drink to that, and to the ones who aren't here to.\""
	if at_war:
		var foe: String = gs.realm_word(w.crown_enemies()[0])
		words = "\"%s thinks we are a rebellion. Let us show them what a realm looks like.\"" % foe
	return {"ok": true, "text": "%s +%d Regard with %d lord%s.%s" % [words, Gatherings.SPEECH_REGARD, n, "" if n == 1 else "s",
		" Your sworn lords will ride when called, whatever their strength, for a week." if at_war else ""]}


static func gifts_check(gs) -> Dictionary:
	var g := table(gs)
	if g.is_empty():
		return {"ok": false, "reason": "only at your own table", "cost": 0}
	if bool(gs.hosted.get("gifts", false)):
		return {"ok": false, "reason": "given", "cost": 0}
	var cost: int = gs.gathering_lords(g).size() * Gatherings.KING_GIFT_SILVER
	if cost <= 0:
		return {"ok": false, "reason": "no one to give to", "cost": 0}
	if gs.silver < cost:
		return {"ok": false, "reason": "you haven't %d silver" % cost, "cost": cost}
	return {"ok": true, "reason": "", "cost": cost}


## Gifts from the king to every lord in the hall.
static func give_gifts(gs) -> Dictionary:
	var check := gifts_check(gs)
	if not check["ok"]:
		return {"ok": false}
	gs.silver -= int(check["cost"])
	gs.hosted["gifts"] = true
	var lords: Array = gs.gathering_lords(table(gs))
	for l in lords:
		LordTalk.change_regard(gs, l, Gatherings.KING_GIFT_REGARD)
	gs.save_game()
	return {"ok": true, "text": "A gift for every lord at your table (%d silver): +%d Regard with %d." % [int(check["cost"]), Gatherings.KING_GIFT_REGARD, lords.size()]}


# ---------------------------------------------------------------- the tourney

## Your captains fit to ride: [{squad, captain}], the most battles first.
static func tourney_captains(gs) -> Array:
	var out := []
	for s in gs.army:
		var c = s.get("captain")
		if c is Dictionary and int(c.get("wounded", 0)) <= 0:
			out.append({"squad": int(s["id"]), "captain": c})
	out.sort_custom(func(a, b): return int(a["captain"].get("battles", 0)) > int(b["captain"].get("battles", 0)))
	return out


static func tourney_check(gs) -> Dictionary:
	var g := table(gs)
	if g.is_empty() or String(g.get("kind", "")) != Gatherings.TOURNEY:
		return {"ok": false, "reason": "only at your own tourney"}
	if not (gs.hosted.get("tourney", {}) as Dictionary).is_empty():
		return {"ok": false, "reason": "the lists are done"}
	if tourney_captains(gs).is_empty() and gs.gathering_lords(g).size() < 2:
		return {"ok": false, "reason": "too few to ride"}
	return {"ok": true, "reason": ""}


## A captain's strength at the lists, and a lord's champion's: the duel's own measure.
static func _skill(e: Dictionary) -> float:
	if e.has("captain"):
		var c: Dictionary = e["captain"]
		return 60.0 + float(c.get("battles", 0)) * 4.0 + float(c.get("kills", 0)) * 0.1 + (25.0 if bool(c.get("is_hero", false)) else 0.0)
	return 60.0 + float(e["lord"].get("renown", 40)) * 0.25


static func _entrant_name(e: Dictionary) -> String:
	if e.has("captain"):
		return String(e["captain"].get("first", e["captain"].get("name", "your captain")))
	return "%s's champion" % LordTalk.short_name(e["lord"])


## Ride the lists: up to three of your captains (by squad id) and one champion for each
## lord in the hall, in a bracket of single passes. The winner's purse, renown and Regard;
## a captain unhorsed is sometimes hurt, never killed. {ok, lines, winner}
static func ride_tourney(gs, squad_ids: Array) -> Dictionary:
	if not tourney_check(gs)["ok"]:
		return {"ok": false}
	var w = gs.world
	var g := table(gs)
	var rng: RandomNumberGenerator = w.gather_rng
	var field := []
	var mine := []
	for e in tourney_captains(gs):
		if squad_ids.has(int(e["squad"])) and mine.size() < Gatherings.TOURNEY_CAPTAINS:
			field.append(e)
			mine.append(e["captain"])
	var lords: Array = gs.gathering_lords(g)
	for l in lords:
		field.append({"lord": l})
	if field.size() < 2:
		return {"ok": false}
	for i in range(field.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = field[i]
		field[i] = field[j]
		field[j] = t
	var lines := PackedStringArray()
	var passes := ["first", "second", "third"]
	while field.size() > 1:
		var next := []
		if field.size() % 2 == 1:
			next.append(field.pop_back())
		for k in range(0, field.size(), 2):
			var a: Dictionary = field[k]
			var b: Dictionary = field[k + 1]
			var sa := _skill(a)
			var sb := _skill(b)
			var a_wins := rng.randf() < sa / (sa + sb)
			var won: Dictionary = a if a_wins else b
			var lost: Dictionary = b if a_wins else a
			var line := "%s unhorses %s at the %s pass." % [_entrant_name(won), _entrant_name(lost), passes[rng.randi_range(0, 2)]]
			if lost.has("captain") and rng.randf() < Gatherings.TOURNEY_WOUND_CHANCE:
				lost["captain"]["wounded"] = Captains.WOUND_BATTLES
				line += " %s is carried from the lists, hurt." % _entrant_name(lost)
			lines.append(line)
			next.append(won)
		field = next
	var winner: Dictionary = field[0]
	for l in lords:
		LordTalk.change_regard(gs, l, Gatherings.TOURNEY_ENTRY_REGARD)
	var result := ""
	if winner.has("captain"):
		var c: Dictionary = winner["captain"]
		gs.renown += Gatherings.TOURNEY_RENOWN
		gs.silver += Gatherings.TOURNEY_PURSE
		for other in mine:
			if other != c:
				var key_o := str(int(other["id"]))
				var key_c := str(int(c["id"]))
				c["bonds"][key_o] = float(c["bonds"].get(key_o, 0.0)) + Gatherings.TOURNEY_BOND
				other["bonds"][key_c] = float(other["bonds"].get(key_c, 0.0)) + Gatherings.TOURNEY_BOND
		var hist: Dictionary = c.get("history", {}) if c.get("history") is Dictionary else {}
		hist["tourneys"] = int(hist.get("tourneys", 0)) + 1
		c["history"] = hist
		result = "%s wins the %s: the purse (%d silver) and +%d renown for the company." % [_entrant_name(winner), String(g.get("name", "tourney")),
			Gatherings.TOURNEY_PURSE, Gatherings.TOURNEY_RENOWN]
	else:
		var wl: Dictionary = winner["lord"]
		wl["silver"] = int(wl.get("silver", 0)) + Gatherings.TOURNEY_PURSE
		LordTalk.change_regard(gs, wl, Gatherings.TOURNEY_WIN_REGARD)
		result = "%s wins the %s and the purse; %s is delighted (+%d Regard)." % [_entrant_name(winner), String(g.get("name", "tourney")),
			LordTalk.short_name(wl), Gatherings.TOURNEY_WIN_REGARD]
	lines.append(result)
	gs.hosted["tourney"] = {"lines": Array(lines), "winner": _entrant_name(winner)}
	gs.save_game()
	return {"ok": true, "lines": Array(lines), "winner": _entrant_name(winner)}
