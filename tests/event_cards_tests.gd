## The map's news as cards, not a wall of text: each note carries the card it's told on;
## the map deals the ones with something to show (a place taken with its banner changing,
## a fief burned, a captain fallen, an oath, a war) and lists the bookkeeping, each line
## with its mark. A battle's result card says what it was for (the chief, the village, the
## walls). The Three Realms won is a scene of its own. The tourney is ridden in the lists.
extends SceneTree

const Cultures = preload("res://scripts/data/cultures.gd")
const WorldData = preload("res://scripts/world/world_data.gd")
const Gatherings = preload("res://scripts/data/gatherings.gd")
const CrownCourt = preload("res://scripts/world/crown_court.gd")
const Lords = preload("res://scripts/data/lords.gd")

var failures := 0
var gs
var scenes
var EventCards


func check(ok: bool, message: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + message)
	if not ok:
		failures += 1


func _arrive(path: String) -> void:
	for i in 300:
		await process_frame
		if current_scene != null and current_scene.scene_file_path.ends_with(path) and current_scene.is_node_ready() and not scenes._busy:
			for j in 3:
				await process_frame
			return


func _go(id: String) -> void:
	var p = gs.world.player()
	p.node = id
	p.next = ""
	p.path = []


func _cards_of(kind: String) -> Array:
	return gs.map_cards.filter(func(c): return String(c.get("kind", "")) == kind)


func _place(l: Dictionary, id: String) -> void:
	var p = gs.world.party(int(l["party"]))
	p.node = id
	p.next = ""
	p.path = []
	p.wait = 0.0
	l["state"] = "field"
	l["job"] = ""
	l["raiding"] = ""


func _swear(realm: String) -> Dictionary:
	for l in gs.world.lords:
		if l["realm"] == realm and not l["ruler"] and int(l.get("party", -1)) >= 0:
			l["realm"] = WorldData.CROWN
			l["sworn_from"] = realm
			l["fief"] = ""
			l.erase("order")
			gs.world.party(int(l["party"])).faction = WorldData.CROWN
			return l
	return {}


func _init() -> void:
	await process_frame
	gs = root.get_node("GameState")
	scenes = root.get_node("Scenes")
	EventCards = load("res://scripts/ui/event_cards.gd")
	var sound = root.get_node("Sound")
	sound.settings_path = "user://event_cards_tests_settings.cfg"
	sound.set_music_on(false)
	gs.persist = false
	gs.new_campaign(Cultures.VARDISH)
	gs.persist = false
	var w = gs.world
	w.friendly_quiet_until = 1.0e9
	_go("ravensford")

	# ---- every note keeps its card
	gs.clear_notice()
	gs._note("A plain line.")
	check(gs.map_cards.size() == 1 and String(gs.map_cards[0]["kind"]) == "note" and String(gs.map_cards[0]["text"]) == "A plain line.",
		"a note with no card of its own is a line in the ledger")
	var taken: Dictionary = gs.take_map_notice()
	check((taken["cards"] as Array).size() == 1 and gs.map_cards.is_empty(), "the cards are taken with the notice")

	# ---- a castle stormed: a big card, its banner changing hands
	var khalun_was: String = w.owner_of("khalun")
	w.declare_war("vardmark", "kharzan", true, "test") if not w.at_war("vardmark", "kharzan") else null
	w.garrisons["khalun"] = []
	gs._take_walls("khalun", "vardmark", "", 40, "Khalun falls to your assault!")
	var tk := _cards_of("taken")
	check(tk.size() == 1 and bool(tk[0]["big"]) and String(tk[0]["place"]) == "khalun", "a place taken is a big card of that place")
	check(not tk.is_empty() and String(tk[0].get("was", "")) == khalun_was and String(tk[0].get("owner", "")) == "vardmark",
		"painted first under its old banner (%s), then under the new" % khalun_was)
	check(not tk.is_empty() and (tk[0]["tiles"] as Array).any(func(t): return String(t[0]) == "silver" and int(t[1]) > 0), "with the spoils as tiles")
	check(gs.map_notice.contains("now flies the banner of"), "and the notice keeps its words")

	# ---- the siege's nights gather onto one card
	gs.clear_notice()
	gs._note_siege("khalun", "ram", "good")
	gs._note("Your ram stands ready before Khalun.")
	gs._note_siege("khalun", "fire", "bad")
	gs._note("The garrison sallied and set your tower alight.")
	gs._note("Collected 12 silver.", {"kind": "ledger", "row": "silver"})
	var parts: Array = EventCards.split(gs.map_cards)
	check((parts[0] as Array).size() == 1 and (parts[0][0]["rows"] as Array).size() == 2, "a night at the siege is one card with a row for each thing that happened")
	check((parts[1] as Array).size() == 1 and String(parts[1][0]["row"]) == "silver", "bookkeeping is left for the ledger, with its mark")
	gs.clear_notice()
	gs._note("The bandit chief X was slain!", {"kind": "chief", "told": true})
	check((EventCards.split(gs.map_cards)[0] as Array).is_empty() and (EventCards.split(gs.map_cards)[1] as Array).is_empty(),
		"what a battle's result card has already said isn't told again")

	# ---- a fief burned and lost
	gs.clear_notice()
	gs.player_fief = {"settlement_id": "ravensford", "realm": w.owner_of("ravensford"), "silver": 300, "food": 20,
		"improvements": {}, "garrison": [], "granted_at": 0.0, "lost": false}
	gs._on_fief_burned("the Ash Hill brigands")
	var burned := _cards_of("fief_burned")
	check(burned.size() == 1 and bool(burned[0]["big"]) and String(burned[0].get("cond", "")) == "burning", "a fief burned is a big card of it burning")
	check(not burned.is_empty() and int(burned[0]["tiles"][0][1]) == -150, "with what the raiders took from the estate (%s)" % str(burned[0].get("tiles", [])) if not burned.is_empty() else "")
	gs._on_fief_transferred("ravensford", "kharzan", w.owner_of("ravensford"))
	var lost := _cards_of("fief_lost")
	check(lost.size() == 1 and String(lost[0].get("owner", "")) == "kharzan", "a fief lost shows the captor's banner going up")
	gs.player_fief = {}

	# ---- a captain fallen in a fight sent in: a memorial, not a dice line
	gs.clear_notice()
	var sq: Dictionary = gs.army[0]
	var cap: Dictionary = sq["captain"]
	var cards: Array = gs.describe_result_cards({"squads": {int(sq["id"]): {"men": 10, "kills": 3, "captain": {"fate": "killed", "roll": 6, "needed": 16, "kills": 1}}}})
	var fallen_card: Dictionary = cards[0]["card"] if not cards.is_empty() else {}
	check(String(fallen_card.get("kind", "")) == "captain_fallen" and bool(fallen_card.get("big", false)) and (fallen_card.get("captain", {}) as Dictionary).size() > 0,
		"a fallen captain is a big memorial card with their face")
	check(String(cards[0]["text"]).contains("Rolled 6") and String(fallen_card.get("aside", "")).contains("6"), "the die is a quiet line under it")
	check(gs.describe_result({"squads": {int(sq["id"]): {"men": 10, "kills": 3, "captain": {"fate": "killed", "roll": 6, "needed": 16, "kills": 1}}}})[0] == cards[0]["text"],
		"describe_result still gives the words")

	# ---- the map deals the cards, then the ledger
	gs.clear_notice()
	w.set_owner("khalun", "kharzan")
	gs._take_walls("khalun", "vardmark", "", 10, "Khalun falls to your assault!")
	gs._note("Collected 99 silver from estate taxes at Ravensford.", {"kind": "ledger", "row": "silver"})
	scenes.settlement_arrival_pending = false
	change_scene_to_file("res://scenes/world_map.tscn")
	await _arrive("world_map.tscn")
	var map = current_scene
	check(map._deck != null and map.find_child("EventCards", true, false) != null, "back on the map, the news is dealt as cards")
	check(map._deck != null and String(map._deck.current().get("kind", "")) == "taken", "the place taken first")
	var art: Node = map._deck.find_child("Art", true, false) if map._deck != null else null
	check(art != null and art.find_child("SettlementVista", true, false) != null, "painted as the place itself")
	check(art != null and art.find_child("NewBanner", true, false) != null and art.find_child("OldBanner", true, false) != null, "its old banner and the new")
	check(map._deck != null and map._deck.find_child("CardTiles", true, false) != null, "the spoils as tiles")
	if map._deck != null:
		map._deck.next_card()
	await process_frame
	await process_frame
	check(map._deck == null and map._sheet == "notice" and map.find_child("Ledger", true, false) != null, "then the bookkeeping, on the notice sheet")
	check(map.sheet_title.text == "At Ravensford" and map.sheet_body.text == "", "under where you are, a line each, not a block of text")
	map._close_sheet()

	# ---- a battle's result says what it was for
	gs.pending_battle = {"objective": "chief", "chief_name": "Black Ulric"}
	var st: Dictionary = gs.battle_stakes({"won": true, "chief_killed": true})
	check(String(st.get("title", "")).contains("Black Ulric") and String(st.get("tone", "")) == "good", "a chief slain: the stakes say so (%s)" % String(st.get("title", "")))
	st = gs.battle_stakes({"won": true, "chief_escaped": true})
	check(String(st.get("title", "")).contains("got away") and String(st.get("tone", "")) == "bad", "a chief got away")
	var village := ""
	for id in WorldData.SETTLEMENTS:
		if String(WorldData.settlement(id)["type"]) == WorldData.VILLAGE:
			village = id
			break
	gs.pending_battle = {"objective": "village", "raid_village": village}
	st = gs.battle_stakes({"won": true})
	check(String(st.get("place", "")) == village and String(st.get("title", "")).contains("saved"), "a village saved, painted")
	st = gs.battle_stakes({"won": false})
	check(String(st.get("cond", "")) == "burning", "a village lost, burning")
	gs.pending_battle = {"objective": "siege", "siege_target": "khalun", "siege_realm": "vardmark"}
	st = gs.battle_stakes({"won": true})
	check(String(st.get("kind", "")) == "taken" and String(st.get("owner", "")) == "vardmark", "walls taken, under the banner you fought for")
	gs.pending_battle = {"objective": "siege", "siege_target": "khalun", "siege_defend": true}
	check(String(gs.battle_stakes({"won": true}).get("kind", "")) == "walls_held", "walls held")
	gs.pending_battle = {"objective": "rout"}
	check(gs.battle_stakes({"won": true}).is_empty(), "a plain fight has no stakes card")
	gs.pending_battle = {}

	# ---- the lists: ridden, not read
	gs.clear_notice()
	gs.renown = 250
	var seat := "ravensford"
	_go(seat)
	gs.player_fief = {"settlement_id": seat, "realm": w.owner_of(seat), "silver": 0, "food": 20, "improvements": {}, "garrison": [], "granted_at": 0.0, "lost": false}
	check(gs.declare_crown(), "a crown at Ravensford")
	w.make_peace(WorldData.CROWN, "vardmark")
	for x in w.gatherings.duplicate():
		w._end_gathering(x)
	var sworn := [_swear("kharzan"), _swear("kharzan"), _swear("ryumon")]
	for l in sworn:
		_place(l, seat)
	gs.silver = 3000
	gs.food = 2000
	var r: Dictionary = gs.host_gathering(Gatherings.TOURNEY, {"friends": false, "persuade": false, "lieges": false})
	var g: Dictionary = w.gathering_of_realm(WorldData.CROWN)
	for l in sworn:
		_place(l, seat)
	w.hour = float(g["starts_hour"]) + 1.0
	g["state"] = "on"
	check(bool(r["ok"]) and bool(CrownCourt.tourney_check(gs)["ok"]), "a tourney at your seat, the lists open")
	var picks: Array = CrownCourt.tourney_captains(gs).slice(0, 3).map(func(e): return int(e["squad"]))
	var f: Dictionary = CrownCourt.lists_field(gs, picks)
	check(bool(f["ok"]) and (f["field"] as Array).size() == picks.size() + gs.gathering_lords(g).size(), "the field: your riders and a champion for each lord")
	var a: Dictionary = f["field"][0]
	var b: Dictionary = f["field"][1]
	var forced: Dictionary = CrownCourt.lists_bout(gs, a, b, 1, 2)
	check(forced["won"] == a and String(forced["line"]).contains("third pass"), "a bout ridden settles who won, at the pass it was won")
	scenes.lists_squads = picks
	scenes.lists_return = "res://scenes/settlement.tscn"
	change_scene_to_file("res://scenes/lists.tscn")
	await _arrive("lists.tscn")
	var lists = current_scene
	check(lists.find_child("Stands", true, false) != null and lists.find_child("NearRider", true, false) != null and lists.find_child("FarRider", true, false) != null,
		"the lists: a grandstand, the tilt, two riders")
	check(lists.find_child("ToTheLists", true, false) != null, "the first round's pairings, to ride")
	# Ride on until one of yours is up, then strike dead on.
	(lists.find_child("ToTheLists", true, false) as Button).pressed.emit()
	var guard := 0
	while not (lists._yours and lists._t >= 0.0) and guard < 600 and lists._overlay == null:
		await process_frame
		var tl = lists.find_child("ToTheLists", true, false)
		if tl != null:
			tl.pressed.emit()
		guard += 1
	if lists._yours and lists._t >= 0.0:
		check(lists.find_child("Strike", true, false) != null and lists.find_child("StrikeBar", true, false) != null, "your captain's bout: a strike bar and a Strike button")
		lists.strike_at(lists.CHARGE)
		lists._pass_result = {}
		var wait := 0
		while lists._pass_result.is_empty() and wait < 600:
			await process_frame
			wait += 1
		check(int(lists._pass_result.get("q", -1)) == 2, "struck as the lances meet, the lance shatters")
		check(lists._score[0] >= 2, "and scores two")
	else:
		print("  (no bout of yours came up this time)")
	lists.ride_all_to_dice()
	await process_frame
	check(lists.find_child("Champion", true, false) != null and lists.find_child("ChampionName", true, false) != null, "the champion is crowned")
	check(not (gs.hosted.get("tourney", {}) as Dictionary).is_empty() and not bool(CrownCourt.tourney_check(gs)["ok"]), "and the lists are done, the result kept")
	(lists.find_child("Back", true, false) as Button).pressed.emit()
	await _arrive("settlement.tscn")
	check(current_scene.scene_file_path.ends_with("settlement.tscn"), "back to the hall")

	# ---- one crown
	gs.clear_notice()
	for id in gs.crown_capitals():
		w.set_owner(id, WorldData.CROWN)
	gs.crown_won = false
	gs._crown_fate()
	check(gs.victory_pending and gs.crown_won, "every capital held: the victory waits for the map")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(gs.to_dict()))
	gs.from_dict(saved)
	check(gs.victory_pending, "and survives a save")
	_go("ravensford")
	gs.world.friendly_quiet_until = 1.0e9
	change_scene_to_file("res://scenes/world_map.tscn")
	await _arrive("victory.tscn")
	var v = current_scene
	check(v != null and v.scene_file_path.ends_with("victory.tscn"), "the map hands over to the victory scene")
	check(not gs.victory_pending, "once")
	check(v.find_child("Capitals", true, false) != null or v.find_child("OneCrown", true, false) != null, "the three capitals take the crown's banner")
	for i in 600:
		await process_frame
		if v.find_child("OneCrown", true, false) != null:
			break
	check(v.find_child("VictoryTitle", true, false) != null and v.find_child("ChronicleTiles", true, false) != null and v.find_child("RideOn", true, false) != null,
		"then One Crown, the chronicle, and Ride on")
	(v.find_child("RideOn", true, false) as Button).pressed.emit()
	await _arrive("world_map.tscn")
	check(current_scene.scene_file_path.ends_with("world_map.tscn"), "Ride on: the campaign carries on")

	print("\n%s: %d failure(s)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)
