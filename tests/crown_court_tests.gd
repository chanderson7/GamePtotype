## The king's court: holding a gathering at any hall of yours (a lord hosting in your
## name), the absent king, the king's table (a seat of honour, gifts, the speech, petitions
## and a castle granted before everyone), the tourney's lists; calling the banners to a
## muster, feeding it, the war council and what it sends out (led by you, or by a lord to
## raid, relieve or hold the march); saves; and the Court tab and council on screen.
## godot --headless --path . --script res://tests/crown_court_tests.gd
extends SceneTree

const Cultures = preload("res://scripts/data/cultures.gd")
const WorldData = preload("res://scripts/world/world_data.gd")
const Lords = preload("res://scripts/data/lords.gd")
const Gatherings = preload("res://scripts/data/gatherings.gd")
const CrownCourt = preload("res://scripts/world/crown_court.gd")
const MarshalArmies = preload("res://scripts/world/marshal_armies.gd")
const LordTalk = preload("res://scripts/world/lord_talk.gd")

var gs
var failures := 0
const SEAT := "ravensford"


func check(ok: bool, message: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + message)
	if not ok:
		failures += 1


func _go(id: String) -> void:
	var p = gs.world.player()
	p.node = id
	p.next = ""
	p.path = []


## Put a lord's party at `id`, standing still, at full strength.
func _place(l: Dictionary, id: String) -> void:
	var p = gs.world.party(int(l["party"]))
	p.node = id
	p.next = ""
	p.path = []
	p.wait = 0.0
	for s in p.army:
		s["men"] = maxi(int(s["men"]), 30)
	l["full"] = gs.world.men_of(p.army)
	l["raiding"] = ""
	l["job"] = ""
	l["state"] = "field"


func _swear(realm: String, bearing: String) -> Dictionary:
	for l in gs.world.lords:
		if l["realm"] == realm and not l["ruler"] and int(l.get("party", -1)) >= 0:
			l["realm"] = WorldData.CROWN
			l["sworn_from"] = realm
			l["fief"] = ""
			l["bearing"] = bearing
			l.erase("order")
			gs.world.party(int(l["party"])).faction = WorldData.CROWN
			return l
	return {}


func _regard(l: Dictionary) -> int:
	return LordTalk.regard(gs, l)


## Make a lord think exactly `v` of you.
func _set_regard(l: Dictionary, v: int) -> void:
	var id := int(l["id"])
	var base := _regard(l) - int(gs.relation_with_lord(id))
	gs.lord_relations[id] = v - base


func _find(n: Node, name: String) -> Node:
	return n.find_child(name, true, false)


func _init() -> void:
	await process_frame
	gs = root.get_node("GameState")
	gs.persist = false
	gs.new_campaign(Cultures.VARDISH)
	var w = gs.world
	gs.renown = 250
	gs.player_fief = {"settlement_id": SEAT, "realm": w.owner_of(SEAT), "silver": 0, "food": 20,
		"improvements": {}, "garrison": [], "granted_at": 0.0, "lost": false}
	_go(SEAT)
	check(gs.declare_crown(), "a crown at Ravensford")
	w.make_peace(WorldData.CROWN, "vardmark")
	for x in w.gatherings.duplicate():
		w._end_gathering(x)
	var castles := []
	for realm in ["vardmark", "ryumon"]:
		for id in WorldData.SETTLEMENTS:
			if String(WorldData.settlement(id)["type"]) == WorldData.CASTLE and w.owner_of(id) == realm:
				castles.append(id)
	var castle: String = castles[0]
	var castle2: String = castles[1]
	w.set_owner(castle, WorldData.CROWN)
	w.set_owner(castle2, WorldData.CROWN)
	var a := _swear("kharzan", Lords.DARING)
	var b := _swear("kharzan", Lords.CRUEL)
	var c := _swear("ryumon", Lords.HONORABLE)
	var d := _swear("ryumon", Lords.CAUTIOUS)
	check(gs.crown_lords().size() == 4, "four lords sworn to you")
	for l in [a, b, c, d]:
		_place(l, SEAT)
	gs.silver = 3000
	gs.food = 2000

	# ---- a gathering in a lord's hall, in your name
	check(gs.grant_fief(castle, int(a["id"])), "a castle granted to a lord")
	check(gs.host_places() == [SEAT, castle, castle2] or (gs.host_places().has(castle) and gs.host_places()[0] == SEAT),
		"your seat first, then your other castles, as places to hold court")
	check(gs.host_lord_at(castle) == a and gs.host_lord_at(SEAT).is_empty(), "a lord's hall is his to host in your name; your seat is yours")
	_place(a, castle)
	var ra := _regard(a)
	var r: Dictionary = gs.host_gathering(Gatherings.FEAST, {"friends": true, "persuade": true, "lieges": false}, castle)
	var g: Dictionary = w.gathering_of_realm(WorldData.CROWN)
	check(bool(r["ok"]) and String(g["place"]) == castle and int(g["host_lord"]) == int(a["id"]), "called from afar, held in his hall")
	check(gs.gathering_is_mine(g) and gs.gathering_host_name(g) == "you" and gs.gathering_title(g).begins_with("Your"), "and still your own")
	check(_regard(a) == ra + Gatherings.HOST_IN_NAME_REGARD, "he's honoured to host it (+%d)" % Gatherings.HOST_IN_NAME_REGARD)
	check(not gs.gift_check(g)["ok"] and not gs.toast_check(g)["ok"], "no gift to bring to your own table, and no toast: you speak")
	# The absent king.
	var sore: Dictionary = w.lord_by_id(int(w.lords.filter(func(l): return String(l["realm"]) == "vardmark" and not bool(l["ruler"]))[0]["id"]))
	gs.hosted["persuade"] = [int(sore["id"])]
	var rs := _regard(sore)
	w.hour = float(g["starts_hour"]) + 25.0
	gs._step_hosted()
	check(_regard(sore) == rs + Gatherings.ABSENT_KING_REGARD and bool(gs.hosted["absent_done"]), "not there on the first night: the lords you're winning over notice")
	gs._step_hosted()
	check(_regard(sore) == rs + Gatherings.ABSENT_KING_REGARD, "once")
	w._end_gathering(g)
	gs.host_ready_at = 0.0

	# ---- the king's table, at a tourney at your seat
	_go(SEAT)
	for l in [a, b, c, d]:
		_place(l, SEAT)
	var silver0: int = gs.silver
	r = gs.host_gathering(Gatherings.TOURNEY, {"friends": false, "persuade": false, "lieges": false})
	g = w.gathering_of_realm(WorldData.CROWN)
	check(bool(r["ok"]) and String(g["kind"]) == Gatherings.TOURNEY and gs.silver == silver0 - Gatherings.HOST_SILVER - Gatherings.TOURNEY_PURSE,
		"a tourney costs its purse too")
	for l in [a, b, c, d]:
		_place(l, SEAT)
	w.hour = float(g["starts_hour"]) + 1.0
	g["state"] = "on"
	check(gs.gathering_here() == g and not CrownCourt.table(gs).is_empty(), "you sit at your own table")
	var lords_here: Array = gs.gathering_lords(g)
	check(lords_here.size() == 4, "your lords are in the hall")
	# A seat of honour.
	var low: Dictionary = lords_here[0]
	for l in lords_here:
		if int(l.get("renown", 0)) < int(low.get("renown", 0)):
			low = l
	var before := {}
	for l in lords_here:
		before[int(l["id"])] = _regard(l)
	check(bool(CrownCourt.honour(gs, int(low["id"]))["ok"]), "a seat at your right hand")
	check(_regard(low) == int(before[int(low["id"])]) + Gatherings.HONOUR_REGARD, "for one lord (+%d)" % Gatherings.HONOUR_REGARD)
	var passed := lords_here.filter(func(l): return l != low and int(l.get("renown", 0)) > int(low.get("renown", 0)))
	check(passed.all(func(l): return _regard(l) == int(before[int(l["id"])]) + Gatherings.PASSED_OVER_REGARD), "lords of more renown feel passed over")
	check(not bool(CrownCourt.honour(gs, int(a["id"]))["ok"]), "once a gathering")
	# Gifts.
	var s0: int = gs.silver
	var ga := _regard(a)
	check(bool(CrownCourt.give_gifts(gs)["ok"]) and gs.silver == s0 - 4 * Gatherings.KING_GIFT_SILVER and _regard(a) == ga + Gatherings.KING_GIFT_REGARD,
		"gifts from the king: silver a head, Regard each")
	check(not bool(CrownCourt.gifts_check(gs)["ok"]), "once")
	# The speech, at peace.
	var gb := _regard(b)
	check(bool(CrownCourt.speech(gs)["ok"]) and _regard(b) == gb + Gatherings.SPEECH_REGARD, "the king's speech warms the hall")
	check(not bool(CrownCourt.speech_check(gs)["ok"]) and float(b.get("rallied_until", 0.0)) <= w.hour, "once; at peace it rallies no one to war")
	# Petitions at table: a castle granted before everyone.
	var asks: Array = CrownCourt.petitions(gs)
	var fief_ask: Dictionary = {}
	for p in asks:
		if String(p["kind"]) == "fief":
			fief_ask = p
	check(not fief_ask.is_empty() and String(fief_ask["fief"]) == castle2, "a lord without land asks for the castle you have free")
	var asker: Dictionary = fief_ask["lord"]
	var rk := _regard(asker)
	var witnesses := {}
	for l in lords_here:
		witnesses[int(l["id"])] = _regard(l)
	r = CrownCourt.answer(gs, fief_ask, true)
	check(bool(r["ok"]) and String(asker["fief"]) == castle2 and _regard(asker) == rk + Gatherings.PUBLIC_GRANT_REGARD,
		"granted before everyone: +%d" % Gatherings.PUBLIC_GRANT_REGARD)
	check(lords_here.filter(func(l): return l != asker).all(func(l): return _regard(l) == int(witnesses[int(l["id"])]) + Gatherings.PUBLIC_GRANT_WITNESS),
		"and the hall sees a king who rewards his own")
	check(not CrownCourt.petitions(gs).any(func(p): return p["lord"] == asker), "and asks no more this week")
	# A lord who thinks little of you wishes to be heard.
	var sour: Dictionary = {}
	for l in lords_here:
		if CrownCourt.petitions(gs).any(func(p): return p["lord"] == l and String(p["kind"]) == "heard"):
			sour = l
	if sour.is_empty():
		for l in lords_here:
			if l != asker and String(l.get("fief", "")) != "" or (l != asker and l != low):
				_set_regard(l, -12)
				sour = l
				break
	var heard: Array = CrownCourt.petitions(gs).filter(func(p): return p["lord"] == sour and String(p["kind"]) == "heard")
	check(not heard.is_empty(), "a lord who thinks little of you wishes to be heard")
	if not heard.is_empty():
		var rh := _regard(sour)
		r = CrownCourt.answer(gs, heard[0], true)
		check(bool(r["ok"]) and _regard(sour) == rh + Gatherings.PETITION_TABLE, "heard at your table (+%d)" % Gatherings.PETITION_TABLE)
		check(not CrownCourt.answer(gs, heard[0], false)["ok"], "and a lord can't be refused a hearing")
	# The lists.
	check(bool(CrownCourt.tourney_check(gs)["ok"]), "the lists are open at your tourney")
	var squads_before: int = gs.army.size()
	var picks: Array = CrownCourt.tourney_captains(gs).slice(0, 3).map(func(e): return int(e["squad"]))
	var lords_silver := {}
	for l in gs.gathering_lords(g):
		lords_silver[int(l["id"])] = int(l.get("silver", 0))
	var renown0: int = gs.renown
	var silver1: int = gs.silver
	r = CrownCourt.ride_tourney(gs, picks)
	check(bool(r["ok"]) and (r["lines"] as Array).size() >= 2 and String(r["lines"][-1]).contains("wins"), "the passes are ridden, and someone wins (%s)" % String(r.get("winner", "")))
	var mine_won: bool = gs.silver == silver1 + Gatherings.TOURNEY_PURSE and gs.renown == renown0 + Gatherings.TOURNEY_RENOWN
	var lord_won: bool = gs.gathering_lords(g).any(func(l): return int(l.get("silver", 0)) == int(lords_silver[int(l["id"])]) + Gatherings.TOURNEY_PURSE)
	check(mine_won or lord_won, "the purse goes to the winner")
	check(gs.army.size() == squads_before and gs.army.all(func(s): return not (s.get("captain") is Dictionary) or not s["captain"].is_empty()), "no captain dies at the lists")
	check(not bool(CrownCourt.tourney_check(gs)["ok"]), "the lists are ridden once")
	# The speech at war: it makes the case, and rallies your lords (back in the hall after
	# the hour spent hearing a petition).
	for l in [a, b, c, d]:
		_place(l, SEAT)
	w.declare_war(WorldData.CROWN, "kharzan", true, "test")
	gs.hosted["speech"] = false
	check(bool(CrownCourt.speech(gs)["ok"]) and float(a.get("rallied_until", 0.0)) > w.hour, "at war, the speech rallies your sworn lords for a week")
	gs.hosted["persuade"] = [int(sore["id"])]
	(gs.hosted["guests"] as Array).append(int(sore["id"]))
	check(gs.gathering_conviction(sore) == Gatherings.HOST_CONVICTION + Gatherings.SPEECH_CONVICTION, "and convinces the lords you're winning over")
	# The settlement page shows the king's table and the lists.
	change_scene_to_file("res://scenes/settlement.tscn")
	for i in 4:
		await process_frame
	var page = current_scene
	page._on_tab("court")
	await process_frame
	check(_find(page, "KingsTable") != null and _find(page, "Feast_Speech") != null and _find(page, "Feast_Toast") == null, "your hall offers the king's table, with a speech for a toast")
	check(_find(page, "ListsResult") != null, "and the lists' results")
	w._end_gathering(g)

	# ---- calling the banners
	for l in [a, b, c, d]:
		_place(l, castle2)
		l.erase("order")
	d["order"] = {"kind": "guard", "target": castle2}
	_set_regard(c, 5)
	b["bought"] = 1
	_set_regard(b, -5)
	var roll: Array = CrownCourt.roll(gs, SEAT)
	var status := {}
	for e in roll:
		status[int(e["lord"]["id"])] = String(e["status"])
	check(status[int(a["id"])] == "comes" and status[int(c["id"])] == "comes", "free lords answer")
	check(status[int(d["id"])] == "holds" and status[int(b["id"])] == "refuses", "a lord holding a place stays; a bought lord who thinks little of you refuses")
	var rb := _regard(b)
	check(CrownCourt.call_banners(gs, SEAT) and not gs.muster.is_empty(), "the banners are called to your seat")
	check(_regard(b) == rb + Lords.MUSTER_REFUSED_REGARD and (gs.muster["refused"] as Array).has(int(b["id"])), "and the one who won't come is remembered")
	check(String(a["order"]["kind"]) == "muster" and not d["order"].is_empty() and String(d["order"]["kind"]) == "guard", "those who answer ride to the muster")
	check(not CrownCourt.call_check(gs, SEAT)["ok"], "one muster at a time")
	check(not CrownCourt.council_check(gs)["ok"], "the council waits for two lords in the hall")
	# They ride there by their order.
	var pa = w.party(int(a["party"]))
	w._follow_order(a, pa)
	check(String(a["job"]) == "muster" and String(a["target"]) == SEAT, "a lord rides to the muster")
	_place(a, SEAT)
	_place(c, SEAT)
	check(CrownCourt.arrived(gs).size() == 2 and bool(CrownCourt.council_check(gs)["ok"]), "two in the hall: the council can sit")
	check(gs.commitments().any(func(e): return String(e["id"]) == "muster"), "the muster is in the journal")
	# The treasury feeds it.
	w.realms[WorldData.CROWN]["treasury"] = 1000
	var upkeep: int = CrownCourt.muster_upkeep(gs)
	w.hour += 24.0
	CrownCourt.step(gs)
	check(upkeep > 0 and gs.crown_treasury() == 1000 - upkeep, "the treasury feeds the muster (%d a day)" % upkeep)
	# The council: counsel by bearing.
	check(String(CrownCourt.counsel(gs, a)["aim"]) == CrownCourt.STORM, "a Daring lord counsels the storm")
	check(String(CrownCourt.counsel(gs, c)["aim"]) in [CrownCourt.STORM, CrownCourt.RELIEVE], "an Honorable lord counsels the storm or a relief, never a raid")
	var aims: Array = CrownCourt.aims(gs)
	var storm: Dictionary = {}
	var raid: Dictionary = {}
	var hold: Dictionary = {}
	for x in aims:
		if String(x["aim"]) == CrownCourt.STORM and bool(x["ok"]) and storm.is_empty():
			storm = x
		if String(x["aim"]) == CrownCourt.RAID and bool(x["ok"]):
			raid = x
		if String(x["aim"]) == CrownCourt.MARCH and bool(x["ok"]):
			hold = x
	check(not storm.is_empty() and not raid.is_empty(), "at war, the council can storm walls or raid villages")
	check(aims.any(func(x): return String(x["aim"]) == CrownCourt.RELIEVE and not bool(x["ok"])), "relief is offered only when one of yours is besieged")
	check(not CrownCourt.march_check(gs, raid, true)["ok"], "your company doesn't burn farms itself")
	# March, led by you.
	var prov: Dictionary = CrownCourt.provisions(gs)
	var ra2 := _regard(a)
	var rc2 := _regard(c)
	check(CrownCourt.march(gs, storm, true), "the council sends the host to %s, led by you" % String(storm["label"]))
	check(String(gs.map_notice).contains(String(WorldData.settlement(String(storm["target"]))["name"])), "and the notice names the place as it's written")
	check(gs.muster.is_empty() and String(gs.banners["led"]) == "you" and String(a["order"]["kind"]) == "follow" and String(c["order"]["kind"]) == "follow",
		"your lords ride at your side")
	check(_regard(a) == ra2 + Lords.MUSTER_RIDE_REGARD, "a lord whose counsel you took: +%d" % Lords.MUSTER_RIDE_REGARD)
	var c_counsel := String(CrownCourt.counsel(gs, c)["aim"])
	check(_regard(c) == rc2 + Lords.MUSTER_RIDE_REGARD + (0 if c_counsel == CrownCourt.STORM else Lords.COUNSEL_IGNORED_REGARD), "one whose counsel you passed over grumbles")
	check((bool(prov["paid"]) and float(gs.banners["until"]) == w.hour + Lords.HOST_PAID_HOURS) or (not bool(prov["paid"]) and float(gs.banners["until"]) == w.hour + Lords.HOST_UNPAID_HOURS),
		"provisions decide how long the host stays out")
	check(gs.commitments().any(func(e): return String(e["id"]) == "banners"), "the host is in the journal")
	check(w.escorts().size() >= 0 and not MarshalArmies.ready_lords(w, WorldData.CROWN).has(a), "lords riding with you aren't free for a marshal's army")
	w.set_owner(String(storm["target"]), WorldData.CROWN)
	CrownCourt.step(gs)
	check(gs.banners.is_empty() and not a.has("order") and not c.has("order"), "the walls taken, your banners go home")

	# ---- a raid led by a lord: the Honorable stay home
	w.army_ready_at.erase(WorldData.CROWN)
	b["bought"] = 0
	_set_regard(b, 10)
	d.erase("order")
	for l in [a, b, c, d]:
		_place(l, castle2)
	check(CrownCourt.call_banners(gs, SEAT), "the banners called again")
	for l in [a, b, c, d]:
		_place(l, SEAT)
	aims = CrownCourt.aims(gs)
	raid = {}
	for x in aims:
		if String(x["aim"]) == CrownCourt.RAID and bool(x["ok"]):
			raid = x
	var rc3 := _regard(c)
	check(CrownCourt.march(gs, raid, false), "a lord leads the raid")
	var army: Dictionary = CrownCourt.host_army(gs)
	check(not army.is_empty() and String(army["aim"]) == CrownCourt.RAID and String(gs.banners["led"]) == "lord", "as a marshal's army")
	check(_regard(c) == rc3 + Lords.RAID_REFUSED_REGARD and not army["members"].has(int(c["party"])), "an Honorable lord won't burn farms, and rides home")
	var village := String(army["destination"])
	for i in 4000:
		if not w.campaign_armies.has(army) or int(army.get("raided", 0)) > 0:
			break
		w.hour += 0.25
		MarshalArmies.tick(w, 0.25)
	check(int(army.get("raided", 0)) > 0 and w.is_burned(village), "the raid burns %s" % village)
	for i in 4000:
		if not w.campaign_armies.has(army):
			break
		w.hour += 0.25
		MarshalArmies.tick(w, 0.25)
	CrownCourt.step(gs)
	check(gs.banners.is_empty(), "and when the army is home, so are your banners")

	# ---- relieve and hold the march, by a lord
	var lords_ids := [int(a["id"]), int(b["id"])]
	for l in [a, b]:
		_place(l, SEAT)
	var foe_lord: Dictionary = {}
	for l in w.lords:
		if String(l["realm"]) != WorldData.CROWN and not bool(l["ruler"]) and int(l.get("party", -1)) >= 0 and String(l.get("state", "")) == "field":
			foe_lord = l
			break
	var foe_p = w.party(int(foe_lord["party"]))
	foe_p.node = castle2
	foe_p.next = ""
	var siege := {"id": 9001, "realm": String(foe_lord["realm"]), "leader": foe_p.id, "members": [foe_p.id], "state": "besieging", "muster": castle2,
		"target": castle2, "target_owner": WorldData.CROWN, "destination": castle2, "deadline": w.hour, "expires": w.hour + 500.0,
		"siege_prep_until": w.hour + 500.0, "siege_food_until": w.hour + 500.0, "reason": ""}
	w.campaign_armies.append(siege)
	check(not w.siege_info(castle2).is_empty(), "an enemy besieges %s" % castle2)
	var relief: Dictionary = MarshalArmies.create_host(w, WorldData.CROWN, lords_ids, int(a["id"]), SEAT, "relieve", castle2, [], [], 144.0)
	check(not relief.is_empty() and String(relief["state"]) == "marching", "a host rides to relieve it")
	for i in 4000:
		if String(relief["state"]) == "holding" or not w.campaign_armies.has(relief):
			break
		w.hour += 0.25
		MarshalArmies._host_tick(w, relief, MarshalArmies.leader(w, relief), 0.25)
	check(String(relief["state"]) == "holding", "and holds there")
	w.campaign_armies.erase(siege)
	w.hour += Lords.THINK_HOURS + 1.0
	MarshalArmies._host_tick(w, relief, MarshalArmies.leader(w, relief), 0.25)
	check(String(relief["state"]) == "returning" and String(relief["reason"]).contains("broken"), "until the siege is broken (%s)" % String(relief.get("reason", "")))
	MarshalArmies.disband(w, relief, "test")
	for l in [a, b]:
		_place(l, SEAT)
	var patrol: Dictionary = MarshalArmies.create_host(w, WorldData.CROWN, lords_ids, int(a["id"]), SEAT, "march", castle2, [SEAT, castle2], [], 144.0)
	check(not patrol.is_empty() and String(patrol["destination"]) == castle2, "a host rides the march")
	for i in 4000:
		if String(patrol["destination"]) == SEAT or not w.campaign_armies.has(patrol):
			break
		w.hour += 0.25
		MarshalArmies._host_tick(w, patrol, MarshalArmies.leader(w, patrol), 0.25)
	check(String(patrol["destination"]) == SEAT, "and turns back at the far end")
	w.hour = float(patrol["expires"]) + 1.0
	MarshalArmies.tick(w, 0.25)
	check(not w.campaign_armies.has(patrol) and String(w.army_outcomes.get(int(patrol["id"]), "")) == "The march held", "until its days are done: the march held")

	# ---- a hungry muster goes home; saves keep the muster and the host
	for l in [a, b, c, d]:
		_place(l, SEAT)
		l.erase("order")
	w.army_ready_at.erase(WorldData.CROWN)
	check(CrownCourt.call_banners(gs, SEAT), "the banners called a third time")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(gs.to_dict()))
	var State = load("res://scripts/game_state.gd")
	var restored = State.new()
	restored.persist = false
	restored.from_dict(saved)
	check(String(restored.muster.get("place", "")) == SEAT and (restored.muster["lords"] as Array).size() == (gs.muster["lords"] as Array).size(), "a muster survives a save")
	restored.free()
	saved.erase("muster")
	saved.erase("banners")
	var old = State.new()
	old.persist = false
	old.from_dict(saved)
	check(old.muster.is_empty() and old.banners.is_empty(), "an older save has neither")
	old.free()
	w.realms[WorldData.CROWN]["treasury"] = 0
	for i in Lords.MUSTER_HUNGRY_DAYS + 1:
		w.hour += 24.0
		CrownCourt.step(gs)
	check(gs.muster.is_empty() and not a.has("order"), "a muster the treasury can't feed goes home")

	# ---- on screen: the Court tab and the council
	for l in [a, b, c, d]:
		_place(l, SEAT)
	w.realms[WorldData.CROWN]["treasury"] = 1000
	w.army_ready_at.erase(WorldData.CROWN)
	CrownCourt.call_banners(gs, SEAT)
	change_scene_to_file("res://scenes/main_menu.tscn")
	for i in 3:
		await process_frame
	var K = load("res://scripts/world/kingdom_screen.gd")
	var k = K.open(root, gs, "court")
	await process_frame
	check(_find(k, "GatheringCard") != null and _find(k, "BannersCard") != null and _find(k, "PetitionsCard") != null, "the Court tab: gatherings, the banners, petitions")
	var open_c := _find(k, "OpenCouncil") as Button
	check(open_c != null and not open_c.disabled, "the council can be opened from anywhere once two lords are in the hall")
	open_c.pressed.emit()
	await process_frame
	check(_find(k, "Council") != null and _find(k, "March") != null and _find(k, "Lead") != null, "the war council: the lords, the aim, who leads")
	k.queue_free()

	print("\nCrown court failures: %d" % failures)
	quit(1 if failures > 0 else 0)
