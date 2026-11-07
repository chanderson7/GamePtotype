## Ruling your crown: a seat needs walls and is no longer renounced like a vassal's; crown
## castles and towns can be granted to sworn lords and garrisoned with your squads; the
## treasury can be drawn on and paid into; lords take orders (ride with you and join your
## fights, hold a place) and answer a call to arms you can ride with; you declare war,
## rivals declare it on you, and peace carries tribute; the crown has a name and a colour;
## holding every capital wins the Glass Sea, and holding nothing brings the crown down.
extends SceneTree

const Cultures = preload("res://scripts/data/cultures.gd")
const WorldData = preload("res://scripts/world/world_data.gd")
const WorldSim = preload("res://scripts/world/world_sim.gd")
const Lords = preload("res://scripts/data/lords.gd")
const MarshalArmies = preload("res://scripts/world/marshal_armies.gd")

var gs
var failures := 0


func check(ok: bool, message: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + message)
	if not ok:
		failures += 1


func _grant(seat: String) -> void:
	gs.player_fief = {"settlement_id": seat, "realm": gs.world.owner_of(seat), "silver": 0, "food": 20,
		"improvements": {}, "garrison": [], "granted_at": 0.0, "lost": false}


func _go(id: String) -> void:
	var p = gs.world.player()
	p.node = id
	p.next = ""
	p.path = []


## A lord of `realm` in the field, sworn to the crown.
func _swear(realm: String) -> Dictionary:
	for l in gs.world.lords:
		if l["realm"] == realm and not l["ruler"] and int(l.get("party", -1)) >= 0:
			l["realm"] = WorldData.CROWN
			l["sworn_from"] = realm
			l["fief"] = ""
			gs.world.party(int(l["party"])).faction = WorldData.CROWN
			return l
	return {}


## Let a lord follow their order alone, out of everyone else's way, until they reach `to`.
func _ride(w, l: Dictionary, p, to: String, ticks: int) -> void:
	for i in ticks:
		w._follow_order(l, p)
		if p.moving():
			if w._move(p, 0.25):
				w._lord_arrives(l, p)
		if p.node == to and not p.moving():
			return


func _texts(n: Node, out: Array) -> void:
	if n is Button:
		out.append((n as Button).text)
	elif n is Label:
		out.append((n as Label).text)
	for c in n.get_children():
		_texts(c, out)


func _init() -> void:
	await process_frame
	gs = root.get_node("GameState")
	gs.persist = false
	gs.new_campaign(Cultures.VARDISH)
	var w = gs.world
	gs.renown = 250

	# ---- a crown needs walls
	_grant("kettlebrook")
	_go("kettlebrook")
	check(not gs.crown_check()["ok"] and String(gs.crown_check()["reason"]).contains("walls"), "a village can't be a crown's seat")
	var seat := "ravensford"
	_grant(seat)
	_go(seat)
	check(gs.declare_crown(), "a town can")
	var liege := "vardmark"

	# ---- the seat's page: a ruler, not a vassal, and nothing to renounce
	change_scene_to_file("res://scenes/settlement.tscn")
	for i in 4:
		await process_frame
	var texts := []
	_texts(current_scene, texts)
	check(texts.any(func(t): return String(t).begins_with("Seat of your crown")), "your seat's page calls you its ruler")
	check(not texts.any(func(t): return String(t).contains("vassal")), "not a sworn vassal")
	check(not texts.any(func(t): return String(t).contains("Renounce")), "and offers nothing to renounce")

	# ---- take a castle and rule it
	var castle := ""
	for id in WorldData.SETTLEMENTS:
		if String(WorldData.settlement(id)["type"]) == WorldData.CASTLE and w.owner_of(id) == liege:
			castle = id
			break
	w.set_owner(castle, WorldData.CROWN)
	check(gs.crown_fiefs().has(castle) and not gs.crown_fiefs().has(seat), "a stormed castle is yours to rule; your seat is your own")
	var a := _swear("kharzan")
	var b := _swear("ryumon")
	check(not a.is_empty() and not b.is_empty() and gs.crown_lords().size() == 2, "two lords are sworn to you")
	var ra: int = gs.relation_with_lord(int(a["id"]))
	check(gs.grant_fief(castle, int(a["id"])) and a["fief"] == castle and w.seat_of(a) == castle, "you grant the castle to a lord, and it's their seat")
	check(gs.relation_with_lord(int(a["id"])) == ra + gs.GRANT_REGARD, "who thinks the better of you for it")
	check(not gs.grant_check(seat, int(b["id"]))["ok"], "your own seat can't be granted")
	var rb_a: int = gs.relation_with_lord(int(a["id"]))
	check(gs.grant_fief(castle, int(b["id"])) and b["fief"] == castle and a["fief"] == "" \
		and gs.relation_with_lord(int(a["id"])) == rb_a + gs.DISPOSSESSED_REGARD, "granted to another, the first holder loses it and resents it")
	var rb: int = gs.relation_with_lord(int(b["id"]))
	check(gs.revoke_fief(int(b["id"])) and b["fief"] == "" and gs.relation_with_lord(int(b["id"])) == rb + gs.REVOKE_REGARD, "taken back, at a cost")

	# ---- your squads in its garrison
	_go(castle)
	var sq: Dictionary = gs.army[0]
	var n: int = gs.army.size()
	check(gs.station_in_holding(int(sq["id"])) and gs.army.size() == n - 1 and gs.stationed_at(castle).has(sq), "you station a squad in a crown castle you're at")
	check(w.garrison_at(castle).has(sq), "and it stands with the garrison")
	check(gs.withdraw_from_holding(int(sq["id"])) and gs.army.size() == n and not w.garrison_at(castle).has(sq), "and take it back")
	change_scene_to_file("res://scenes/settlement.tscn")
	for i in 4:
		await process_frame
	# Granting and stationing each open a sheet from the Crown tab.
	check(current_scene.find_child("GrantHolding", true, false) != null and current_scene.find_child("StationSquad", true, false) != null,
		"the castle's Crown tab offers to grant it and station a squad")
	current_scene._show_grant_sheet()
	current_scene._show_station_sheet(true)
	await process_frame
	check(current_scene.find_child("Grant_%d" % int(a["id"]), true, false) != null and current_scene.find_child("Station_%d" % int(gs.army[0]["id"]), true, false) != null,
		"the castle's Crown tab grants it and stations squads")

	# ---- the treasury
	w.realms[WorldData.CROWN]["treasury"] = 1000
	gs.silver = 0
	var ra2: int = gs.relation_with_lord(int(a["id"]))
	check(gs.draw_treasury(500) and gs.silver == 500 and gs.crown_treasury() == 500 \
		and gs.relation_with_lord(int(a["id"])) == ra2 + gs.DRAW_REGARD, "you can draw on the treasury, and your lords notice")
	check(gs.fund_treasury(500) and gs.silver == 0 and gs.crown_treasury() == 1000, "and pay into it")
	check(w.reserve_of(WorldData.CROWN) < w.reserve_of(liege), "a young crown's garrisons are raised from a small treasury")

	# ---- orders
	_go(seat)
	check(gs.order_lord(int(a["id"]), "follow"), "a lord can be told to ride with you")
	var pa = w.party(int(a["party"]))
	_ride(w, a, pa, seat, 200)
	check(pa.node == seat or w.party_pos(pa).distance_to(w.party_pos(w.player())) < 60.0, "and comes to your side")
	pa.node = w.player().node
	pa.next = ""
	pa.along = 0.0
	check(w.escorts().has(pa), "close enough to join your fights")
	var band = w.bands()[0]
	w.encounter = band.id
	gs.start_encounter_battle()
	check(gs.pending_battle.get("allies", []).any(func(s): return int(s.get("lord_id", -1)) == int(a["id"])), "and joins the battle with you")
	gs.pending_battle = {}
	w.encounter = -1
	check(gs.order_lord(int(b["id"]), "guard", castle), "a lord can be told to hold a place")
	var pb = w.party(int(b["party"]))
	_ride(w, b, pb, castle, 400)
	check(pb.node == castle, "and goes there")
	gs.order_lord(int(a["id"]), "")
	check(not a.has("order"), "or left to their own devices")

	# ---- call to arms
	b.erase("order")
	for l in [a, b]:
		var p = w.party(int(l["party"]))
		p.node = seat
		p.next = ""
		for s in p.army:
			s["men"] = 40
		l["full"] = w.men_of(p.army)
		l["raiding"] = ""
	var target := ""
	for id in WorldData.SETTLEMENTS:
		if String(WorldData.settlement(id)["type"]) == WorldData.CASTLE and w.owner_of(id) == liege and id != castle:
			target = id
			break
	if target == "":
		target = WorldData.FACTIONS[liege]["capital"]
	check(gs.call_check(target)["ok"], "with two lords ready, you can call them to arms against an enemy castle")
	check(gs.call_to_arms(target) and w.campaign_armies.any(func(x): return x["realm"] == WorldData.CROWN and x["target"] == target), "and they gather to march on it")
	check(not gs.call_check(target)["ok"], "one army at a time")
	gs.map_notice = ""

	# ---- war and peace
	var other := "ryumon"
	check(gs.war_check(other)["ok"] and gs.declare_crown_war(other) and w.at_war(WorldData.CROWN, other), "you can declare war")
	w.wars[w.war_key(WorldData.CROWN, other)]["since"] = w.hour - 24.0 * 10.0
	w.realms[other]["weariness"] = 80.0
	w.realms[WorldData.CROWN]["weariness"] = 10.0
	var terms: Dictionary = w.peace_terms(WorldData.CROWN, other)
	check(terms["to"] == WorldData.CROWN and int(terms["daily"]) > 0, "a wearier enemy would pay you tribute")
	check(gs.sue_for_peace(other) and w.tributes.any(func(t): return t["from"] == other and t["to"] == WorldData.CROWN), "and does, once peace is made")
	check(not gs.war_check(other)["ok"] and String(gs.war_check(other)["reason"]).contains("truce"), "no new war during the truce")
	# A rival declares war on a crown worth fearing.
	w.truces.clear()
	w.realms["kharzan"]["weariness"] = 0.0
	if w.at_war("kharzan", WorldData.CROWN):
		w.wars.erase(w.war_key("kharzan", WorldData.CROWN))
	w.alliances.clear()
	var declared := false
	for i in 200:
		w._rivals_of_the_crown()
		if w.at_war("kharzan", WorldData.CROWN) or w.at_war("ryumon", WorldData.CROWN):
			declared = true
			break
	check(declared, "a stronger realm at rest may declare war on your crown")

	# ---- name and colour
	gs.set_crown_identity("the Kingdom of Ash", 1)
	check(gs.crown_title() == "the Kingdom of Ash" and WorldData.crown_color == WorldData.CROWN_COLORS[1], "you name your crown and choose its colour")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(gs.to_dict()))
	gs.set_crown_identity("", 0)
	gs.from_dict(saved)
	check(gs.crown_title() == "the Kingdom of Ash" and WorldData.crown_color == WorldData.CROWN_COLORS[1], "and it's saved")
	w = gs.world
	check(w.lord_by_id(int(a["id"])).get("fief", "x") == "" and String(w.lord_by_id(int(b["id"])).get("sworn_from", "")) == "ryumon", "with your lords as they were")

	# ---- the kingdom screen
	gs.map_notice = ""
	change_scene_to_file("res://scenes/world_map.tscn")
	await process_frame
	await process_frame
	var map = current_scene
	map.paused = true
	map._close_sheet()
	map._open_crown()
	var k = map._kingdom
	check(k != null and k.find_child("CrownTitle", true, false).text == "The Kingdom of Ash", "your crown has its own screen")
	for t in ["holdings", "lords", "diplomacy"]:
		k._on_tab(t)
	check(k.find_child("Realm_kharzan", true, false) != null, "with holdings, lords and the other realms")
	k.close()
	await process_frame
	check(map._kingdom == null and map._sheet == "", "and closes back to the map")

	# ---- every capital: the Glass Sea is yours
	for id in gs.crown_capitals():
		w.set_owner(id, WorldData.CROWN)
	gs.renown = 0
	gs._crown_day()
	check(gs.crown_won and gs.renown >= 100 and gs.map_notice.contains("one crown"), "holding every capital wins the Glass Sea")
	gs.map_notice = ""

	# ---- holding nothing, the crown falls
	for id in gs.crown_holdings():
		w.set_owner(id, liege)
	for i in gs.CROWN_FALL_DAYS:
		gs._crown_day()
	check(not gs.is_crowned() and not w.realms.has(WorldData.CROWN), "holding nothing for %d days, the crown falls" % gs.CROWN_FALL_DAYS)
	var la: Dictionary = w.lord_by_id(int(a["id"]))
	check(la["realm"] == "kharzan" and not w.wars.keys().any(func(k2): return String(k2).contains(WorldData.CROWN)), "its lords go home, and its wars end")
	check(not gs.has_fief() and w.player().faction == "" and gs.map_notice.contains("fallen"), "and the company rides free again")
	for i in 3:
		w.step(24.0)
		gs.settle()
	check(true, "the world carries on without it")

	print("FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)
