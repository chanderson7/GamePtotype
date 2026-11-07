## Lords gather: the hall at every town and castle, feasts and dances called in peace,
## guests riding in on a "gather" job, the invitation, the feast's first words, toast,
## gift and gossip, the dance, break-ups, your own gathering as a crown, lords resting at
## their capital, and saves (old ones too).
extends SceneTree

const Cultures = preload("res://scripts/data/cultures.gd")
const Relationships = preload("res://scripts/data/relationships.gd")
const WorldData = preload("res://scripts/world/world_data.gd")
const Gatherings = preload("res://scripts/data/gatherings.gd")
const LordTalk = preload("res://scripts/world/lord_talk.gd")
const MarshalArmies = preload("res://scripts/world/marshal_armies.gd")

var failures := 0
var gs
var scenes


func check(ok: bool, message: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + message)
	if not ok:
		failures += 1


func _arrive(path: String) -> void:
	for i in 240:
		await process_frame
		if current_scene != null and current_scene.scene_file_path.ends_with(path) and current_scene.is_node_ready():
			return


func _go(id: String) -> void:
	var p = gs.world.player()
	p.node = id
	p.next = ""
	p.path = []


## Bring every guest of `g` to its hall at once, as if they'd ridden there.
func _seat_guests(g: Dictionary) -> void:
	var w = gs.world
	for l in w.gathering_guests(g):
		var p = w.party(int(l["party"]))
		p.node = String(g["place"])
		p.next = ""
		p.path = []
		w._lord_arrives(l, p)


## Move the clock to `hour` without the rest of the world moving.
func _clock_to(hour: float) -> void:
	gs.world.hour = hour
	gs.world._step_gatherings()


func _texts(n: Node, out: Array) -> void:
	if n is Button:
		out.append((n as Button).text)
	elif n is Label:
		out.append((n as Label).text)
	for c in n.get_children():
		_texts(c, out)


func _find(n: Node, name: String) -> Node:
	if n.name == name:
		return n
	for c in n.get_children():
		var f := _find(c, name)
		if f != null:
			return f
	return null


func _init() -> void:
	await process_frame
	gs = root.get_node("GameState")
	scenes = root.get_node("Scenes")
	gs.persist = false
	gs.new_campaign(Cultures.VARDISH)
	var w = gs.world
	gs.silver = 2000
	gs.food = 600

	# ---- no gatherings in war
	check(w.at_war("vardmark", "kharzan"), "the campaign starts with Vardmark and Kharzan at war")
	for i in 40:
		w._gatherings_day()
	check(w.gathering_of_realm("vardmark").is_empty() and w.gathering_of_realm("kharzan").is_empty(), "realms at war hold no gatherings")
	for g in w.gatherings.duplicate():
		w._end_gathering(g)
	w.gathering_ended = {}

	# ---- peace brings a peace feast at the capital
	w.make_peace("vardmark", "kharzan")
	check(w.gathering_of_realm("vardmark").is_empty() and w.peace_feasts.has("vardmark"), "peace is feasted from the next day")
	w._gatherings_day()
	var g: Dictionary = w.gathering_of_realm("vardmark")
	check(not g.is_empty() and String(g["reason"]) == "peace" and String(g["place"]) == w.capital_of("vardmark"), "peace brings a peace feast at Highcliff")
	var host: Dictionary = w.lord_by_id(int(g.get("host_lord", -1)))
	check(bool(host.get("ruler", false)), "the king hosts it")
	check(String(g["name"]) == "peace feast" and String(g["state"]) == "announced", "it's announced as the peace feast")
	var starts: float = float(g["starts_hour"])
	check(starts >= w.hour + Gatherings.LEAD_HOURS and is_equal_approx(fposmod(starts, 24.0), Gatherings.DUSK), "it starts at the first dusk a day or more away")
	check(is_equal_approx(float(g["ends_hour"]) - starts, Gatherings.LENGTH_HOURS), "and lasts three nights")
	check(w.activity_log.any(func(e): return String(e["text"]).contains("holds a peace feast at Highcliff")), "the news says the king holds a feast at Highcliff")
	var guests: Array = w.gathering_guests(g)
	check(guests.size() >= 1 and guests.size() <= Gatherings.MAX_GUESTS + 1, "lords ride to it (%d)" % guests.size())
	check(guests.all(func(l): return String(l["job"]) == "gather" and String(l["target"]) == "highcliff"), "each on a gather job bound for Highcliff")
	check(guests.all(func(l): return MarshalArmies.for_party(w, int(l["party"])).is_empty()), "none of them on campaign")

	# ---- the invitation
	check(not bool(gs.gathering_invite(g)["invited"]), "a stranger isn't invited")

	# ---- an enemy's feast: the gates are barred, and the map and the town say so
	gs.realm_relations["vardmark"] = -40
	check(gs.gathering_barred(g), "a feast in a realm at war with you is barred to you")
	var barred_inv: Dictionary = gs.gathering_invite(g)
	check(not bool(barred_inv["invited"]) and String(barred_inv["why"]).contains("at war"), "and no invitation comes from it (%s)" % barred_inv["why"])
	_go("highcliff")
	scenes.settlement_arrival_pending = false
	change_scene_to_file("res://scenes/settlement.tscn")
	await _arrive("settlement.tscn")
	var barred_note: Node = _find(current_scene, "FeastBarred")
	check(barred_note != null and (barred_note as Label).text.contains("no enemy is seated"), "the barred town says why you can't sit at its feast")
	var map_script = load("res://scripts/world/map_screen.gd")
	var map_probe = map_script.new()
	map_probe.world = w
	check(String(map_probe._gathering_plate(g)).ends_with("closed to you"), "the map's plate says it's closed to you")
	map_probe.free()
	gs.realm_relations.erase("vardmark")
	check(not gs.gathering_barred(g), "at peace again, the hall is open")
	gs.contract = {"realm": "vardmark", "daily_pay": 10, "days_left": 30, "bonus_per_lord": 100}
	var inv: Dictionary = gs.gathering_invite(g)
	check(bool(inv["invited"]) and String(inv["why"]).contains("serve Vardmark"), "serving the realm gets you invited (%s)" % inv["why"])
	var told: Array = gs.take_new_invitations()
	check(told.any(func(x): return int(x["id"]) == int(g["id"])), "the invitation arrives once")
	check(not gs.take_new_invitations().any(func(x): return int(x["id"]) == int(g["id"])), "and only once")
	check(gs.commitments().any(func(c): return String(c["id"]) == "gathering_%d" % int(g["id"]) and String(c["place"]) == "highcliff"), "it goes in the journal")

	# ---- the feast begins; guests are in the hall
	_go("highcliff")
	_seat_guests(g)
	_clock_to(starts + 1.0)
	check(w.gathering_on(g) and w.gathering_night(g) == 1, "at dusk it begins: the first night")
	var here: Array = gs.gathering_lords(g)
	check(here.size() >= 2 and int(here[0]["id"]) == int(g["host_lord"]), "the hall holds the host first and the guests (%d)" % here.size())
	check(w.lords_at("highcliff").size() == here.size(), "lords_at lists everyone stopped there")

	# ---- the settlement's Court tab is the feast
	scenes.settlement_arrival_pending = false
	change_scene_to_file("res://scenes/settlement.tscn")
	await _arrive("settlement.tscn")
	var page = current_scene
	page._on_tab("court")
	await process_frame
	var texts := []
	_texts(page, texts)
	check(texts.any(func(t): return String(t).begins_with("Feast · ")), "the tab reads Feast · N")
	check(texts.any(func(t): return String(t).contains("King Aldwin's peace feast")), "the card names the host's feast")
	check(texts.any(func(t): return String(t).contains("first word at the table · +2")), "each lord offers a first word at the table")
	var guest: Dictionary = {}
	for l in here:
		if int(l["id"]) != int(g["host_lord"]):
			guest = l
			break
	var before := LordTalk.regard(gs, guest)
	page._open_lord_talk(int(guest["id"]))
	await process_frame
	var talk = page._talk
	check(talk != null and talk.mode == "hall", "tapping a lord opens the talk indoors")
	var cap := _find(talk, "Caption") as Label
	check(cap != null and cap.text == "In the hall at Highcliff" and talk.caption().begins_with("In the hall at Highcliff · the peace feast")
		and _find(talk, "When") != null, "captioned in the hall, the feast and the hour as marks (%s)" % talk.caption())
	check(_find(talk, "Hall") != null, "with the hall drawn behind them")
	check(LordTalk.regard(gs, guest) == before + Gatherings.FIRST_WORD, "the first word is +2 Regard")
	check(not talk.has_reply("sword", false) and talk.has_reply("outside", false), "no sword under the king's roof: a duel outside the walls instead")
	talk.choose("leave")
	await process_frame
	await process_frame
	page = current_scene
	page._open_lord_talk(int(guest["id"]))
	await process_frame
	check(LordTalk.regard(gs, guest) == before + Gatherings.FIRST_WORD, "the first word counts once")
	page._talk.choose("leave")
	await process_frame

	# ---- toast, gift, gossip
	gs.renown = 50
	check(not bool(gs.toast_check(g)["ok"]), "a toast needs renown")
	gs.renown = 150
	var r0 := LordTalk.regard(gs, guest)
	var toast: Dictionary = gs.raise_toast(g)
	check(bool(toast["ok"]) and LordTalk.regard(gs, guest) == r0 + Gatherings.TOAST_REGARD, "a toast warms every lord there")
	check(not bool(gs.toast_check(g)["ok"]), "once")
	var silver_before: int = gs.silver
	var host_before: int = gs.relation_with_lord(int(host["id"]))
	var realm_before: int = gs.relation_with_realm("vardmark")
	var gift: Dictionary = gs.bring_gift(g)
	check(bool(gift["ok"]) and gs.silver == silver_before - Gatherings.GIFT_SILVER, "a gift costs 50 silver")
	check(gs.relation_with_lord(int(host["id"])) == host_before + Gatherings.GIFT_REGARD and gs.relation_with_realm("vardmark") == realm_before + Gatherings.GIFT_REALM, "the host +5, the realm +2")
	check(not bool(gs.gift_check(g)["ok"]), "once")
	# A guest whose castle burned is sour, and the gossip says so.
	var sour := {}
	for l in here:
		if not bool(l["ruler"]) and String(l.get("fief", "")) != "" and w.owner_of(String(l["fief"])) == "vardmark":
			sour = l
			break
	if not sour.is_empty():
		w.burned[String(sour["fief"])] = w.hour + 200.0
	var hour_before: float = w.hour
	var gossip: Dictionary = gs.hear_gossip(g)
	check(bool(gossip["ok"]) and w.hour >= hour_before + Gatherings.GOSSIP_HOURS - 0.01, "the gossip takes an hour")
	if not sour.is_empty():
		check(int(gossip["lord_id"]) == int(sour["id"]) and String(gossip["text"]).contains(LordTalk.short_name(sour)), "the gossip names the lord whose castle burned (%s)" % gossip["text"])
		check(gs.sour_reason(sour) != "", "and they really are sour")
	else:
		check(String(gossip["text"]) != "", "the gossip says something (%s)" % gossip["text"])
	check(not bool(gs.gossip_check(g)["ok"]), "once a night")

	# ---- the dance: the last night of a feast
	check(not bool(gs.dance_check(g)["ok"]), "no dancing on the first night of a feast")
	_clock_to(starts + 49.0)
	check(w.gathering_night(g) == 3 and bool(gs.dance_check(g)["ok"]), "the last night has dancing")
	scenes.dance_return = "res://scenes/settlement.tscn"
	change_scene_to_file("res://scenes/dance.tscn")
	await _arrive("dance.tscn")
	var dance = current_scene
	var partner := ""
	for id in dance.reply_ids():
		if String(id).begins_with("partner_lord_"):
			partner = String(id)
	check(partner != "" and dance.has_reply("wall"), "the dance offers lords and the wall")
	var dl: Dictionary = w.lord_by_id(int(partner.trim_prefix("partner_lord_")))
	var dr := LordTalk.regard(gs, dl)
	dance.choose(partner)
	var gain := Gatherings.DANCE_DARING if String(dl["bearing"]) == "Daring" else Gatherings.DANCE_LORD
	check(LordTalk.regard(gs, dl) == dr + gain, "a dance with a lord is +%d Regard" % gain)
	check(not bool(gs.dance_check(g)["ok"]), "one partner a night")
	dance.choose("done")
	await _arrive("settlement.tscn")

	# ---- saves mid-gathering
	var saved: Dictionary = gs.to_dict()
	var json: Dictionary = JSON.parse_string(JSON.stringify(saved))
	gs.from_dict(json)
	w = gs.world
	var g2: Dictionary = w.gathering_by_id(int(g["id"]))
	check(not g2.is_empty() and typeof(g2["id"]) == TYPE_INT and typeof(g2["host_lord"]) == TYPE_INT and String(g2["state"]) == "on", "the gathering survives a save")
	check(w.gathering_guests(g2).size() == guests.size(), "and its guests")
	check((gs.gathering_record(g2)["spoke"] as Array).has(int(guest["id"])) and bool(gs.gathering_record(g2)["toast"]), "and what you did there")
	g = g2
	host = w.lord_by_id(int(g["host_lord"]))
	var old: Dictionary = gs.to_dict()
	old["world"].erase("gatherings")
	old["world"].erase("gathering_ended")
	old["world"].erase("next_gathering_id")
	old.erase("gathering_log")
	gs.from_dict(JSON.parse_string(JSON.stringify(old)))
	check(gs.world.gatherings.is_empty() and gs.gathering_log.is_empty(), "an old save loads with no gatherings")
	gs.from_dict(json)
	w = gs.world
	g = w.gathering_by_id(int(g["id"]))

	# ---- war breaks it up
	var guest_ids: Array = w.gathering_guests(g).map(func(l): return int(l["id"]))
	w.declare_war("vardmark", "kharzan", true)
	w._gathering_check = -10.0
	w._step_gatherings()
	check(w.gathering_by_id(int(g["id"])).is_empty(), "war breaks the feast up")
	check(guest_ids.all(func(id): return String(w.lord_by_id(id)["job"]) != "gather"), "and the lords leave")
	check(w.activity_log.any(func(e): return String(e["text"]).contains("broke up: war with")), "the news says why")

	# ---- in peace, about one every two weeks
	var ry_count := 0
	w.gathering_ended = {}
	var start_hour: float = w.hour
	for day in 140:
		w.hour = start_hour + day * 24.0
		var before_n: int = w.gatherings.size()
		w._gatherings_day()
		for x in w.gatherings:
			if String(x["realm"]) == "ryumon" and int(x["id"]) >= 0 and not x.has("_counted"):
				x["_counted"] = true
				ry_count += 1
		w._step_gatherings()
	check(ry_count >= 6 and ry_count <= 14, "a realm at peace holds one about every two weeks (%d in 20 weeks)" % ry_count)

	# ---- a romance dance at her home
	for x in w.gatherings.duplicate():
		w._end_gathering(x)
	w.wars = {}
	w.gathering_ended = {}
	var soc = w.social
	soc.relationships["edda"]["status"] = Relationships.COURTING
	soc.relationships["edda"]["trust"] = 20
	var rg: Dictionary = w.call_gathering("vardmark", "season", "ravensford", Gatherings.DANCE)
	check(not rg.is_empty() and String(rg["kind"]) == Gatherings.DANCE, "a dance at Ravensford")
	_go("ravensford")
	_seat_guests(rg)
	_clock_to(float(rg["starts_hour"]) + 1.0)
	check(bool(gs.dance_check(rg)["ok"]), "every night of a dance has dancing")
	var partners: Array = gs.dance_partners(rg)
	check(partners.any(func(p): return String(p["kind"]) == "romance" and String(p["id"]) == "edda"), "Edda is there to dance with")
	var mems_before: int = soc.memory_book(String(soc.get_candidate_person("edda")["id"])).size()
	var dres: Dictionary = gs.dance(rg, "romance", "edda")
	check(bool(dres["ok"]) and int(soc.relationships["edda"]["trust"]) == 21, "a dance with someone you court is time together: +1 trust")
	var book: Array = soc.memory_book(String(soc.get_candidate_person("edda")["id"]))
	check(book.size() == mems_before + 1 and String(book[book.size() - 1]["kind"]) == "dance", "kept as a memory")
	_clock_to(float(rg["starts_hour"]) + 25.0)
	gs.dance(rg, "romance", "edda")
	_clock_to(float(rg["starts_hour"]) + 49.0)
	gs.dance(rg, "romance", "edda")
	var trust_cap: int = int(soc.relationships["edda"]["trust"])
	check(trust_cap == 20 + Gatherings.DANCE_TRUST_CAP, "dances add trust up to a cap (%d)" % trust_cap)
	var danced: Array = soc.memory_book(String(soc.get_candidate_person("edda")["id"])).filter(func(m): return String(m["kind"]) == "dance")
	var dance_texts := {}
	for m in danced:
		dance_texts[String(m["text"])] = true
	check(danced.size() == 3 and dance_texts.size() == 3 and String(danced[2]["candidate"]) == "edda", "each dance is remembered as itself")

	# ---- the hall on an ordinary day
	for x in w.gatherings.duplicate():
		w._end_gathering(x)
	var holder: Dictionary = w.holder_lord("ravensford")
	check(not holder.is_empty() and String(holder["fief"]) == "ravensford", "Ravensford has a holder")
	var hp = w.party(int(holder["party"]))
	hp.node = "marchgate"
	hp.next = ""
	hp.path = []
	holder["job"] = "patrol"
	holder["target"] = "marchgate"
	change_scene_to_file("res://scenes/settlement.tscn")
	await _arrive("settlement.tscn")
	page = current_scene
	page._on_tab("court")
	await process_frame
	texts = []
	_texts(page, texts)
	check(texts.any(func(t): return String(t).begins_with("Court")), "an ordinary day: the Court tab")
	check(_find(page, "Away_%d" % int(holder["id"])) != null, "the holder is listed as away")
	check(texts.any(func(t): return String(t).contains("near Marchgate") or String(t).contains("Marchgate")), "with where they are")
	check(_find(page, "Person_edda") != null, "the household is in the hall")

	# ---- lords rest at their capital between gatherings
	var rester := {}
	for l in w.lords:
		if String(l["realm"]) == "vardmark" and not bool(l["ruler"]) and int(l.get("party", -1)) >= 0 and String(l["state"]) == "field":
			rester = l
			break
	var rp = w.party(int(rester["party"]))
	rp.node = "kettlebrook"
	rp.next = ""
	rp.path = []
	rester["job"] = ""
	var rested := false
	for i in 60:
		if w._rest_at_capital(rester, rp, "kettlebrook"):
			rested = true
			break
	check(rested and String(rester["job"]) == "gather" and int(rester["gather_id"]) == 0 and String(rester["target"]) == "highcliff", "a lord near the capital sometimes rests there")
	w.hour = float(rester["gather_until"]) + 1.0
	check(not w._keep_gathering(rester, rp) and String(rester["job"]) == "", "and goes about their business when the rest is over")

	# ---- your own gathering, as a crown
	gs.contract = {}
	gs.renown = 250
	gs.player_fief = {"settlement_id": "ravensford", "realm": "vardmark", "silver": 0, "food": 20,
		"improvements": {}, "garrison": [], "granted_at": 0.0, "lost": false}
	_go("ravensford")
	check(gs.declare_crown(), "you raise your crown at Ravensford")
	w.make_peace(WorldData.CROWN, "vardmark")
	for x in w.gatherings.duplicate():
		w._end_gathering(x)
	var sworn := {}
	for l in w.lords:
		if String(l["realm"]) == "ryumon" and not bool(l["ruler"]) and int(l.get("party", -1)) >= 0:
			l["realm"] = WorldData.CROWN
			l["sworn_from"] = "ryumon"
			w.party(int(l["party"])).faction = WorldData.CROWN
			var sp = w.party(int(l["party"]))
			sp.node = "marchgate"
			sp.next = ""
			sp.path = []
			l["job"] = ""
			sworn = l
			break
	gs.silver = 100
	check(not bool(gs.host_check()["ok"]) and String(gs.host_check()["reason"]).contains("silver"), "hosting costs silver")
	gs.silver = 1000
	gs.food = 600
	var hc: Dictionary = gs.host_check()
	check(bool(hc["ok"]), "a crown at peace can hold court (%s)" % hc["reason"])
	var invitees: Dictionary = gs.host_invitees()
	check((invitees["sworn"] as Array).has(sworn), "your sworn lords are on the list")
	change_scene_to_file("res://scenes/settlement.tscn")
	await _arrive("settlement.tscn")
	page = current_scene
	page._on_tab("fief")
	await process_frame
	check(_find(page, "HostCard") != null and _find(page, "SendInvitations") != null, "your seat offers to hold a gathering")
	var hosted: Dictionary = gs.host_gathering(Gatherings.FEAST, {"friends": true, "persuade": true, "lieges": false})
	check(bool(hosted["ok"]) and gs.silver == 1000 - Gatherings.HOST_SILVER and gs.food == 600 - Gatherings.HOST_FOOD, "it costs 300 silver and 200 rations")
	var mine: Dictionary = w.gathering_of_realm(WorldData.CROWN)
	check(not mine.is_empty() and int(mine["host_lord"]) == -1 and String(mine["place"]) == "ravensford", "your gathering is called at your seat")
	check((mine["guests"] as Array).has(int(sworn["id"])) and String(sworn["job"]) == "gather", "your sworn lord rides to it")
	check(not bool(gs.host_check()["ok"]), "one at a time")
	var persuadable := {}
	for lid in mine["guests"]:
		var l: Dictionary = w.lord_by_id(int(lid))
		if String(l["realm"]) != WorldData.CROWN:
			persuadable = l
	if not persuadable.is_empty():
		check(gs.gathering_conviction(persuadable) == Gatherings.HOST_CONVICTION, "lords you'd win over arrive warmer to your case")
	else:
		check(gs.gathering_conviction(sworn) == Gatherings.HOST_CONVICTION, "guests arrive warmer to your case")
	w._end_gathering(mine)
	check(not bool(gs.host_check()["ok"]) and String(gs.host_check()["reason"]).contains("days"), "and then not again for a while")

	print("\n%s: %d failure(s)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)
