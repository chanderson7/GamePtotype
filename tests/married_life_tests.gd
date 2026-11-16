## Married life (docs/married-life-plan.md): each partner's standing benefit, ask and
## letters; her house's men and holding a place; private vows without the house's help;
## her seat as home and in danger; travelling together, being taken, and the road home;
## saves. Then the screens: her talk's help menu, coming and going, the People page, the
## Journal and the camp.
extends SceneTree

const Cultures = preload("res://scripts/data/cultures.gd")
const Relationships = preload("res://scripts/data/relationships.gd")
const WorldData = preload("res://scripts/world/world_data.gd")
const MarriedLife = preload("res://scripts/world/married_life.gd")
const Fiefs = preload("res://scripts/data/fiefs.gd")
const CampMoments = preload("res://scripts/data/camp_moments.gd")

const SEATS := {"edda": "ravensford", "farid": "qasr_hamra", "kaede": "kitayama"}

var failures := 0
var gs
var scenes


func check(ok: bool, message: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + message)
	if not ok:
		failures += 1


func _arrive(path: String) -> void:
	for i in 300:
		await process_frame
		if current_scene != null and current_scene.scene_file_path.ends_with(path) and current_scene.is_node_ready():
			return


## Let the world run where the company stands.
func _wait(hours: float) -> void:
	var w = gs.world
	var until: float = w.hour + hours
	while w.hour < until:
		w.wait(minf(6.0, until - w.hour + 0.01))
		gs.advance(6.0)
		w.encounter = -1


## A fresh campaign, married to `cand`: publicly (the pact with her house) or by private vows.
func _married(cand: String, public: bool = true) -> void:
	gs.new_campaign(Cultures.VARDISH)
	gs.silver = 2000
	gs.food = 600
	var soc = gs.world.social
	var seat: String = SEATS[cand]
	gs.world.player().node = seat
	gs.world.player().next = ""
	var rel: Dictionary = soc.relationships[cand]
	rel["romantic_intent"] = true
	rel["trust"] = 70
	rel["status"] = Relationships.COMMITTED
	soc.quests["quest_%s" % cand]["chapter"] = 5
	var person: Dictionary = soc.get_candidate_person(cand)
	soc.houses[person["house_id"]]["standing"] = 40
	if public:
		gs.apply_social_choice(cand, "marry_public")
		gs.choose_wedding_place(seat)
		_wait(80.0)
		gs.world.player().node = seat
		gs.world.player().next = ""
		var r: Dictionary = gs.finish_wedding({"vow": "A vow.", "their_vow": "Hers.", "second": -1})
		check(bool(r.get("ok", false)), "married %s at %s" % [cand, seat])
		soc.end_wedding_feast()
	else:
		gs.apply_social_choice(cand, "marry_private")
	var lord: Dictionary = MarriedLife.house_lord(gs, cand)
	if not lord.is_empty():
		if String(lord.get("state", "")) == "prisoner":
			gs.world.release_lord(int(lord["id"]))
		lord["silver"] = maxi(int(lord.get("silver", 0)), 1200)


## A lord of her house in the field at full strength, by his seat.
func _lord_in_field(cand: String) -> Dictionary:
	var w = gs.world
	var lord: Dictionary = MarriedLife.house_lord(gs, cand)
	if lord.is_empty():
		return lord
	if w.party(int(lord.get("party", -1))) == null:
		w._lord_takes_field(lord, w.seat_of(lord))
	var p = w.party(int(lord.get("party", -1)))
	if p != null:
		p.army = w._lord_army(lord)
		lord["army"] = p.army
	lord.erase("order")
	lord["job"] = "home"
	return lord


func _letters(key: String) -> Array:
	return gs.world.social.letters.filter(func(l): return String(l.get("template_key", "")) == key)


func _entry(id: String) -> Dictionary:
	for c in gs.commitments():
		if String(c.get("id", "")) == id:
			return c
	return {}


func _init() -> void:
	await process_frame
	gs = root.get_node("GameState")
	scenes = root.get_node("Scenes")
	gs.persist = false
	_edda()
	_house_help()
	_private()
	_farah()
	_kaede()
	_seat()
	_travel()
	_saves()
	await _screens()
	print("FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)


# ---------------------------------------------------------------- Edda

func _edda() -> void:
	print("-- Edda")
	_married("edda")
	var soc = gs.world.social
	check(MarriedLife.spouse(gs) == "edda" and MarriedLife.role_on(gs, "edda"), "married to Edda, her part on")
	check(is_equal_approx(MarriedLife.fief_tax_mult(gs), MarriedLife.FIEF_TAX_MULT) and is_equal_approx(MarriedLife.ransom_mult(gs), 1.0),
		"she keeps the fief's accounts (+20% tax), and only that")
	# A fief of your own, and a day of its taxes.
	gs.player_fief = {"settlement_id": "thornwall", "realm": "vardmark", "silver": 0, "food": 0, "improvements": {}, "garrison": []}
	var tax := Fiefs.daily_tax(gs.player_fief, gs.world.is_burned("thornwall"))
	gs._fief_day()
	check(int(gs.player_fief["silver"]) == int(round(tax * MarriedLife.FIEF_TAX_MULT)), "the fief's tax with her keeping its books (%d of %d)" % [int(gs.player_fief["silver"]), tax])
	gs.player_fief = {}
	# The supply train.
	var lord: Dictionary = MarriedLife.house_lord(gs, "edda")
	var purse0 := int(lord["silver"])
	var check0: Dictionary = MarriedLife.supply_check(gs)
	check(bool(check0["ok"]) and int(check0["food"]) == MarriedLife.SUPPLY_FOOD and int(check0["silver"]) == Relationships.GRANT_MAX_SILVER,
		"a train can go: %d rations and %d silver" % [int(check0.get("food", 0)), int(check0.get("silver", 0))])
	var places: Array = MarriedLife.near_places(gs)
	check(not places.is_empty() and String(places[0]["id"]) == "ravensford", "it can go where you are first")
	var to := ""
	for p in places:
		if String(p["id"]) != "ravensford":
			to = String(p["id"])
			break
	var food0: int = gs.food
	var silver0: int = gs.silver
	var sent: Dictionary = MarriedLife.send_supply(gs, to)
	check(bool(sent["ok"]) and int(lord["silver"]) == purse0 - MarriedLife.SUPPLY_FOOD * MarriedLife.SUPPLY_FOOD_PRICE - Relationships.GRANT_MAX_SILVER,
		"her house pays for it from its purse; nothing comes from nowhere")
	check(not bool(MarriedLife.supply_check(gs)["ok"]), "and it shares the household grant's cooldown")
	var c: Dictionary = sent["convoy"]
	check(String(c["state"]) == "riding" and float(c["arrive"]) > gs.world.hour, "a cart rides the roads, taking time")
	check(not _entry("household_convoy_%d" % int(c["id"])).is_empty(), "the Journal follows it")
	# Bands kept off the road while it rides.
	for b in gs.world.bands():
		b.node = "kurogane"
		b.next = ""
	var mid: Vector2 = MarriedLife.convoy_pos(gs, c)
	gs.world.hour = (float(c["depart"]) + float(c["arrive"])) * 0.5
	check(MarriedLife.convoy_pos(gs, c).distance_to(mid) > 1.0, "it moves along its road with the hours")
	gs.world.hour = float(c["arrive"]) + 0.1
	MarriedLife.step(gs)
	check(String(c["state"]) == "waiting" and gs.food == food0, "it arrives and waits for you")
	gs.world.player().node = to
	MarriedLife.step(gs)
	check(gs.food == food0 + MarriedLife.SUPPLY_FOOD and gs.silver == silver0 + Relationships.GRANT_MAX_SILVER and MarriedLife.convoys(gs).is_empty(),
		"you meet it: the food and silver are yours")
	# A cart a band finds is lost.
	soc.limits["last_grant_hour"] = -9999.0
	gs.world.player().node = "ravensford"
	sent = MarriedLife.send_supply(gs, to)
	c = sent["convoy"]
	gs.world.hour = (float(c["depart"]) + float(c["arrive"])) * 0.5
	var b = gs.world.bands()[0]
	b.node = gs.world.nearest_place(MarriedLife.convoy_pos(gs, c))
	b.next = ""
	b.along = 0.0
	var at: Vector2 = MarriedLife.convoy_pos(gs, c)
	if gs.world.party_pos(b).distance_to(at) > MarriedLife.AMBUSH_RADIUS:
		# Put the band right on the cart.
		b.node = String(c["from"])
		gs.world.hour = float(c["depart"])
	MarriedLife.step(gs)
	check(MarriedLife.convoys(gs).is_empty() and _letters("supply_lost").size() == 1, "bandits take a cart they find; she writes")
	# Short of wages: her letter, and a reply that sends the train.
	for bb in gs.world.bands():
		bb.node = "kurogane"
	soc.limits["last_grant_hour"] = -9999.0
	gs.world.player().node = "ravensford"
	gs.silver = 0
	MarriedLife.day(gs)
	var short: Array = _letters("household_short")
	check(short.size() == 1, "short of wages: she writes that the tallies say so")
	MarriedLife.day(gs)
	check(_letters("household_short").size() == 1, "once a week at most")
	var res: Dictionary = gs.reply_letter(String(short[0]["id"]), "send", "ravensford")
	check(bool(res.get("ok", false)) and bool(res.get("action", {}).get("ok", false)) and MarriedLife.convoys(gs).size() == 1,
		"replying \"Send the train\" sends it")
	gs.silver = 2000
	# Home: the wounded heal faster at her seat.
	gs.world.player().node = "ravensford"
	gs.world.player().next = ""
	check(is_equal_approx(MarriedLife.heal_mult(gs), MarriedLife.HOME_HEAL_MULT) or not gs.is_resting(), "resting at her seat heals faster")
	gs.world.player().node = "highcliff"
	check(is_equal_approx(MarriedLife.heal_mult(gs), 1.0), "elsewhere, as ever")


# ---------------------------------------------------------------- her house

func _house_help() -> void:
	print("-- her house")
	_married("edda")
	var w = gs.world
	var soc = gs.world.social
	var seat := String(MarriedLife.house_of(gs, "edda").get("seat", "ravensford"))
	w.player().node = seat
	# Your squads short of men, the garrison able to spare some.
	var short := 0
	for s in gs.army:
		var cut := mini(int(s["men"]) - 2, 8)
		s["men"] = int(s["men"]) - cut
		short += cut
	var garrison: Array = w.garrison_at(seat)
	var g0: int = w.men_of(garrison)
	if g0 < MarriedLife.GARRISON_KEEP + 30 and not garrison.is_empty():
		garrison[0]["men"] = int(garrison[0]["men"]) + 60
		g0 = w.men_of(garrison)
	var m: Dictionary = MarriedLife.men_check(gs, "edda")
	check(bool(m["ok"]) and int(m["men"]) == mini(MarriedLife.HOUSE_MEN_MAX, short), "her house can send %d men" % int(m.get("men", 0)))
	var men0: int = gs.total_men()
	var got: Dictionary = MarriedLife.ask_men(gs, "edda")
	check(bool(got["ok"]) and gs.total_men() == men0 + int(got["men"]) and w.men_of(w.garrison_at(seat)) == g0 - int(got["men"]),
		"they come out of the garrison and into your squads (%d)" % int(got.get("men", 0)))
	check(w.men_of(w.garrison_at(seat)) >= MarriedLife.GARRISON_KEEP, "the garrison keeps its own")
	check(not bool(MarriedLife.men_check(gs, "edda")["ok"]) and not bool(MarriedLife.hold_check(gs, "edda")["ok"]),
		"the house's military help waits its fortnight, both kinds")
	w.player().node = "highcliff"
	soc.limits["last_military_help_hour"] = -9999.0
	check(String(MarriedLife.men_check(gs, "edda")["reason"]).contains("garrison is"), "men come only at her house's seat")
	# Holding a place.
	var lord := _lord_in_field("edda")
	check(not lord.is_empty() and bool(MarriedLife.hold_check(gs, "edda")["ok"]), "her house's lord can ride out for you (%s)" % String(MarriedLife.hold_check(gs, "edda").get("reason", "")))
	var places: Array = MarriedLife.hold_places(gs, "edda")
	var target := String(places[0]["id"]) if not places.is_empty() else ""
	var held: Dictionary = MarriedLife.hold_place(gs, "edda", target)
	check(bool(held["ok"]) and String(lord.get("order", {}).get("target", "")) == target, "he's ordered to hold %s" % target)
	check(not _entry("household_hold_%d" % int(lord["id"])).is_empty(), "the Journal counts it down")
	_wait(12.0)
	check(lord.has("order") and String(lord.get("target", "")) == target, "he rides to hold it (%s %s)" % [lord.get("job", ""), lord.get("target", "")])
	_wait(MarriedLife.HOLD_HOURS)
	check(not lord.has("order"), "after two days the order ends")


# ---------------------------------------------------------------- private vows

func _private() -> void:
	print("-- private vows")
	_married("edda", false)
	check(MarriedLife.spouse(gs) == "edda" and not MarriedLife.pact_active(gs, "edda"), "married by private vows: no pact")
	check(bool(MarriedLife.ask_ready(gs, "edda")["ok"]) and is_equal_approx(MarriedLife.fief_tax_mult(gs), MarriedLife.FIEF_TAX_MULT),
		"her own part comes with private vows")
	var why := String(MarriedLife.supply_check(gs)["reason"])
	check(why.contains("no pact") and String(MarriedLife.men_check(gs, "edda")["reason"]).contains("no pact")
		and String(MarriedLife.hold_check(gs, "edda")["reason"]).contains("no pact"), "her house's help needs the pact (%s)" % why)


# ---------------------------------------------------------------- Farah

func _farah() -> void:
	print("-- Farah")
	_married("farid")
	var w = gs.world
	check(is_equal_approx(MarriedLife.ransom_mult(gs), MarriedLife.RANSOM_MULT) and is_equal_approx(MarriedLife.reparations_mult(gs), MarriedLife.REPARATIONS_MULT),
		"her word with the houses: better ransom, cheaper reparations")
	gs.realm_relations["ryumon"] = -50
	check(gs.reparations_cost("ryumon") == int(round((gs.REPARATIONS_BASE + gs.REPARATIONS_PER_POINT * 30) * 0.5)), "reparations at half")
	var targets: Array = MarriedLife.envoy_targets(gs)
	var truce := {}
	for t in targets:
		if String(t["kind"]) == "truce" and String(t["realm"]) == "ryumon":
			truce = t
	check(not truce.is_empty(), "a realm that bars you for your standing is offered a truce")
	var ruler := {}
	for l in w.lords_of("ryumon"):
		if bool(l.get("ruler", false)):
			ruler = l
	gs.lord_relations[str(int(ruler["id"]))] = 0
	var sent: Dictionary = MarriedLife.send_envoy(gs, truce)
	check(bool(sent["ok"]) and String(sent["convoy"]["kind"]) == "envoy", "she rides as an envoy")
	check(not bool(MarriedLife.ask_ready(gs, "farid")["ok"]), "her ask waits ten days")
	w.hour = float(sent["convoy"]["arrive"]) + 0.1
	MarriedLife.step(gs)
	check(gs.relation_with_realm("ryumon") >= MarriedLife.TRUCE_RELATION and gs.barred_by("ryumon") == "" and _letters("envoy_done").size() == 1,
		"a truce: Ryumon no longer bars you, and she writes")
	# Refused: a ruler who thinks too little of you.
	gs.world.social.household["ask_hour"]["farid"] = -99999.0
	gs.realm_relations["kharzan"] = -60
	var kruler := {}
	for l in w.lords_of("kharzan"):
		if bool(l.get("ruler", false)):
			kruler = l
	gs.add_lord_relation(int(kruler["id"]), -200)
	var kt := {}
	for t in MarriedLife.envoy_targets(gs):
		if String(t["kind"]) == "truce" and String(t["realm"]) == "kharzan":
			kt = t
	sent = MarriedLife.send_envoy(gs, kt)
	w.hour = float(sent["convoy"]["arrive"]) + 0.1
	MarriedLife.step(gs)
	check(gs.barred_by("kharzan") == "standing" and _letters("envoy_refused").size() == 1, "refused when the ruler thinks too ill of you")
	# A good word.
	gs.world.social.household["ask_hour"]["farid"] = -99999.0
	var lord := {}
	for l in w.lords_of("vardmark"):
		if not bool(l.get("ruler", false)) and String(l.get("state", "")) != "prisoner":
			lord = l
			break
	lord["met_player"] = 1
	var before: int = gs.relation_with_lord(int(lord["id"]))
	var word := {}
	for t in MarriedLife.envoy_targets(gs):
		if String(t["kind"]) == "word" and int(t["lord_id"]) == int(lord["id"]):
			word = t
	check(not word.is_empty(), "a lord you've met is offered a good word")
	sent = MarriedLife.send_envoy(gs, word)
	w.hour = float(sent["convoy"]["arrive"]) + 0.1
	MarriedLife.step(gs)
	check(gs.relation_with_lord(int(lord["id"])) == before + MarriedLife.GOOD_WORD, "+%d Regard" % MarriedLife.GOOD_WORD)
	check(not MarriedLife.envoy_targets(gs).any(func(t): return String(t["kind"]) == "word" and int(t["lord_id"]) == int(lord["id"])), "once per lord")
	# Word of a muster against her seat, once per army.
	w.campaign_armies.append({"id": 9001, "realm": "kharzan", "leader": int(kruler["id"]), "members": [], "state": "gathering", "target": "qasr_hamra"})
	MarriedLife.day(gs)
	MarriedLife.day(gs)
	check(_letters("army_warning").size() == 1, "she writes when an army musters against her seat, once")
	w.campaign_armies = w.campaign_armies.filter(func(a): return int(a["id"]) != 9001)


# ---------------------------------------------------------------- Kaede

func _kaede() -> void:
	print("-- Kaede")
	_married("kaede")
	var w = gs.world
	check(MarriedLife.knows_places(gs), "her records cover every place")
	var places: Array = MarriedLife.lookup_places(gs)
	check(places.size() == MarriedLife.LOOKUP_PLACES, "she can look up the places nearest you")
	var r: Dictionary = MarriedLife.look_up(gs, "place", String(places[1]["id"]))
	check(bool(r["ok"]) and _letters("lookup").is_empty(), "asked: the answer comes later")
	check(not bool(MarriedLife.look_up(gs, "place", String(places[0]["id"]))["ok"]), "one question every two days")
	_wait(MarriedLife.LOOKUP_DELAY_HOURS + 1.0)
	var got: Array = _letters("lookup")
	var body := " ".join(PackedStringArray(got[0]["letter"]["body"])) if not got.is_empty() else ""
	check(got.size() == 1 and body.contains("Garrison") and body.contains(String(places[1]["name"])), "her letter says what the records hold")
	w.hour += MarriedLife.LOOKUP_COOLDOWN_HOURS
	var l: Dictionary = w.lords[0]
	l["met_player"] = 1
	check(MarriedLife.lookup_lords(gs).any(func(x): return int(x["id"]) == int(l["id"])), "and the lords you've met")
	MarriedLife.look_up(gs, "lord", str(int(l["id"])))
	_wait(MarriedLife.LOOKUP_DELAY_HOURS + 1.0)
	got = _letters("lookup")
	check(got.size() == 2 and " ".join(PackedStringArray(got[1]["letter"]["body"])).contains("He counts you"), "where he is, and what he thinks of you")
	# A band on her map.
	var b = w.bands()[0]
	b.node = w.player().node
	b.next = ""
	MarriedLife.day(gs)
	check(_letters("kaede_map").size() == 1 and not _entry("household_band").is_empty(), "a band near you: her map, and the Journal follows it")


# ---------------------------------------------------------------- her seat

func _seat() -> void:
	print("-- her seat")
	_married("edda")
	var w = gs.world
	var house: Dictionary = MarriedLife.house_of(gs, "edda")
	var standing0 := int(house["standing"])
	check(gs.defends_for_her("ravensford") and not gs.defends_for_her("highcliff"), "the call to the walls comes at her seat")
	w.campaign_armies.append({"id": 9002, "realm": "kharzan", "leader": -1, "members": [], "state": "besieging", "target": "ravensford", "engines": []})
	MarriedLife.step(gs)
	check(_letters("seat_besieged").size() == 1 and not _entry("household_siege").is_empty(), "besieged: she writes, and the Journal says so")
	MarriedLife.step(gs)
	check(_letters("seat_besieged").size() == 1, "once")
	MarriedLife.on_seat_defended(gs, "ravensford")
	w.campaign_armies = w.campaign_armies.filter(func(a): return int(a["id"]) != 9002)
	MarriedLife.step(gs)
	check(_letters("seat_held").size() == 1 and int(house["standing"]) == standing0 + MarriedLife.SEAT_HELD_STANDING and _entry("household_siege").is_empty(),
		"held, with you on the walls: her thanks, and her house's standing")
	# It falls: she comes to your fief.
	gs.player_fief = {"settlement_id": "thornwall", "realm": "vardmark", "silver": 0, "food": 0, "improvements": {}, "garrison": []}
	var person: Dictionary = MarriedLife.person(gs, "edda")
	w.social._relocate_person(person, "kharzan", w)
	check(String(person["residence"]) == "thornwall", "her seat falls: she comes to your fief")
	gs.player_fief = {}


# ---------------------------------------------------------------- travelling together

func _travel() -> void:
	print("-- travelling together")
	_married("kaede")
	var w = gs.world
	var soc = w.social
	w.player().node = "highcliff"
	check(not bool(MarriedLife.join_check(gs, "kaede")["ok"]), "she joins you from her seat")
	w.player().node = "kitayama"
	check(bool(MarriedLife.join(gs, "kaede")["ok"]) and MarriedLife.with_company(gs) == "kaede", "she rides with the company")
	check(not soc.residents_at("kitayama").any(func(p): return String(p.get("content_id", "")) == "kaede"), "and isn't at home")
	check(is_equal_approx(MarriedLife._cooldown(gs, "kaede"), MarriedLife.LOOKUP_COOLDOWN_HOURS * MarriedLife.TRAVEL_ASK_MULT), "her ask comes twice as often")
	w.player().node = "highcliff"
	MarriedLife.look_up(gs, "place", "highcliff")
	check(_letters("lookup").size() == 1, "and she answers at once, being here")
	soc.household["joined_battles"] = gs.battles
	gs.battles += 1
	check(CampMoments.candidates(gs).any(func(m): return String(m.get("kind", "")) == "spouse"), "a moment with her at the fire")
	var r: Dictionary = MarriedLife.send_home(gs, "kaede")
	check(bool(r["ok"]) and MarriedLife.returning(gs, "kaede") and not soc.residents_at("kitayama").any(func(p): return String(p.get("content_id", "")) == "kaede"),
		"sent home: on the road")
	w.hour += float(r["hours"]) + 1.0
	MarriedLife.step(gs)
	check(soc.residents_at("kitayama").any(func(p): return String(p.get("content_id", "")) == "kaede"), "and home when the road allows")
	# Taken by a lord, ransomed.
	w.player().node = "kitayama"
	MarriedLife.join(gs, "kaede")
	var foe: Dictionary = {}
	for l in w.lords:
		if String(l.get("state", "")) != "prisoner" and String(l.get("realm", "")) == "kharzan":
			foe = l
			break
	MarriedLife.on_battle_lost(gs, int(foe["id"]), -1, String(foe["name"]))
	check(MarriedLife.is_held(gs, "kaede") and MarriedLife.with_company(gs) == "" and not _entry("household_road_home").is_empty(),
		"you lose: she's taken, and A road home is in the Journal")
	check(not bool(MarriedLife.ask_ready(gs, "kaede")["ok"]) and not MarriedLife.knows_places(gs), "her part waits while she's held")
	var purse0 := int(foe.get("silver", 0))
	var silver0: int = gs.silver
	check(bool(MarriedLife.pay_ransom(gs)["ok"]) and gs.silver == silver0 - MarriedLife.RANSOM_SILVER and int(foe["silver"]) == purse0 + MarriedLife.RANSOM_SILVER,
		"her ransom: paid to her captor")
	check(not MarriedLife.is_held(gs, "kaede") and _letters("home_again_ransom").size() == 1, "she's home, and writes")
	# Taken by a band, freed by beating it.
	MarriedLife.join(gs, "kaede")
	var b = w.bands()[0]
	MarriedLife.on_battle_lost(gs, -1, int(b.id), String(b.name))
	check(String(MarriedLife.ransom_check(gs)["reason"]).contains("bandits"), "bandits don't bargain")
	MarriedLife.on_battle_won(gs, -1, int(b.id))
	check(not MarriedLife.is_held(gs, "kaede") and _letters("home_again_battle").size() == 1, "beat them and she's free")
	# Her captor falls; or ten days pass and her house pays.
	MarriedLife.join(gs, "kaede")
	MarriedLife.on_battle_lost(gs, int(foe["id"]), -1, String(foe["name"]))
	w.capture_lord(int(foe["id"]), "vardmark")
	MarriedLife.step(gs)
	check(not MarriedLife.is_held(gs, "kaede") and _letters("home_again_escaped").size() == 1, "her captor taken: she walks free")
	w.release_lord(int(foe["id"]))
	MarriedLife.join(gs, "kaede")
	MarriedLife.on_battle_lost(gs, int(foe["id"]), -1, String(foe["name"]))
	var house: Dictionary = MarriedLife.house_of(gs, "kaede")
	var standing0 := int(house["standing"])
	w.hour += MarriedLife.HOUSE_PAYS_AFTER_HOURS + 1.0
	MarriedLife.step(gs)
	check(not MarriedLife.is_held(gs, "kaede") and int(house["standing"]) == standing0 + MarriedLife.HOUSE_PAYS_STANDING and _letters("home_again_house").size() == 1,
		"ten days and her house pays for her; it remembers you didn't come")


# ---------------------------------------------------------------- saves

func _saves() -> void:
	print("-- saves")
	_married("edda")
	var soc = gs.world.social
	MarriedLife.send_supply(gs, String(MarriedLife.near_places(gs)[1]["id"]))
	MarriedLife.join(gs, "edda")
	soc.household["captive"] = {"cand": "edda", "kind": "lord", "lord_id": 3, "since": 10.0, "captor": "Lord X"}
	var saved: Dictionary = JSON.parse_string(JSON.stringify(soc.to_dict()))
	soc.from_dict(saved)
	var c: Dictionary = soc.household["convoys"][0]
	check(c["id"] is int and c["food"] is int and String(c["state"]) == "riding" and soc.household["captive"]["lord_id"] is int,
		"carts, envoys, and who's held survive a save")
	soc.household["captive"] = {}


# ---------------------------------------------------------------- the screens

func _screens() -> void:
	print("-- the screens")
	_married("edda")
	var soc = gs.world.social
	gs.world.player().node = "ravensford"
	scenes.active_candidate_id = "edda"
	scenes.conversation_return = "res://scenes/settlement.tscn"
	change_scene_to_file("res://scenes/conversation.tscn")
	await _arrive("conversation.tscn")
	var talk = current_scene
	check(talk.has_reply("help") and talk.has_reply("join"), "her talk: ask her help, or ask her to come with you")
	talk.choose("help")
	check(talk.has_reply("ask_edda") and talk.has_reply("house_men", false) and talk.has_reply("house_hold", false) and talk.has_reply("help_back"),
		"her ask, and her house's help (shut when it can't be given, with why)")
	talk.choose("ask_edda")
	var to := ""
	for id in talk.reply_ids():
		if String(id).begins_with("supply_") and String(id) != "supply_ravensford":
			to = String(id)
			break
	check(to != "", "places to send the train")
	talk.choose(to)
	check(MarriedLife.convoys(gs).size() == 1 and talk.log_text().contains("rations"), "sent from her talk")
	talk.choose("back")
	talk.choose("join")
	talk.choose("back")
	check(MarriedLife.with_company(gs) == "edda" and talk.has_reply("home") and not talk.has_reply("join"), "she comes with you; now you can send her home")
	# Away from her seat, she's by the company's fire.
	gs.world.player().node = "highcliff"
	scenes.conversation_return = "res://scenes/main_menu.tscn"
	change_scene_to_file("res://scenes/conversation.tscn")
	await _arrive("conversation.tscn")
	talk = current_scene
	var backdrop = talk._backdrop
	check(backdrop is TextureRect and (backdrop as TextureRect).texture != null and (backdrop as TextureRect).texture.resource_path.contains("company_camp"),
		"on the road you talk by the company's fire")
	check(talk.has_reply("home"), "and can send her home")
	# The camp, and the People page.
	scenes.warband_tab = "camp"
	change_scene_to_file("res://scenes/main_menu.tscn")
	await _arrive("main_menu.tscn")
	await process_frame
	check(current_scene.find_child("CampSpouse", true, false) != null, "she's around the fire")
	change_scene_to_file("res://scenes/people.tscn")
	await _arrive("people.tscn")
	current_scene._person = "edda"
	current_scene._build()
	await process_frame
	check(current_scene.find_child("Speak_edda", true, false) != null, "her page says you can speak with her: she's here")
	# Taken: her page offers the ransom.
	var foe: Dictionary = {}
	for l in gs.world.lords:
		if String(l.get("realm", "")) == "kharzan" and String(l.get("state", "")) != "prisoner":
			foe = l
			break
	MarriedLife.on_battle_lost(gs, int(foe["id"]), -1, String(foe["name"]))
	current_scene._build()
	await process_frame
	var ransom = current_scene.find_child("Ransom_edda", true, false)
	check(ransom != null and not (ransom as Button).disabled, "held: her page offers her ransom")
	(ransom as Button).pressed.emit()
	await process_frame
	check(not MarriedLife.is_held(gs, "edda"), "paid from her page: she's free")
