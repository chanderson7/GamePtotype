## The journal: what the company has promised, where to go, and how promises ended.
extends SceneTree

const WorldData = preload("res://scripts/world/world_data.gd")
const Cultures = preload("res://scripts/data/cultures.gd")
const Jobs = preload("res://scripts/data/jobs.gd")

var gs
var failures := 0


func check(ok: bool, message: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + message)
	if not ok:
		failures += 1


func _find(id: String) -> Dictionary:
	for c in gs.commitments():
		if c["id"] == id:
			return c
	return {}


func _init() -> void:
	await process_frame
	gs = root.get_node("GameState")
	gs.persist = false
	gs.new_campaign(Cultures.VARDISH)
	var w = gs.world
	check(gs.commitments().is_empty(), "a new company has no commitments")

	# Courier: the destination is the place to show.
	var courier: Dictionary = Jobs.make_courier_job("highcliff", w, w.rng)
	gs.active_jobs.append(courier)
	var c := _find(String(courier["id"]))
	check(c.get("place", "") == courier["destination_settlement"] and float(c["hours_left"]) > 0.0,
		"a courier job points at its destination and shows its deadline")

	# Relief: blocked until the company carries the rations.
	var relief: Dictionary = Jobs.make_relief_job("thornwall", w, w.rng)
	gs.active_jobs.append(relief)
	gs.food = 3
	c = _find(String(relief["id"]))
	check(c["place"] == "thornwall" and String(c["blocked"]).contains("3 rations"), "a relief job says why it can't be done yet")
	gs.food = 500
	check(String(_find(String(relief["id"]))["blocked"]) == "", "and stops waiting once there is food")

	# Hunt: the link follows the band as it moves.
	var band = w.bands()[0]
	gs.active_jobs.append({"id": "hunt_test", "type": Jobs.TYPE_HUNT, "origin_settlement": "highcliff", "title": "Bounty",
		"deadline": w.hour + 72.0, "target_party_id": band.id, "target_name": band.name})
	band.node = "kettlebrook"
	band.next = ""
	band.path = []
	check(_find("hunt_test")["place"] == "kettlebrook", "a hunt points where the band is now")
	band.node = "ravensford"
	check(_find("hunt_test")["place"] == "ravensford", "and follows it when it moves")

	# Reading the journal changes nothing.
	var before: String = JSON.stringify(gs.to_dict())
	gs.commitments()
	gs.pinned()
	check(JSON.stringify(gs.to_dict()) == before, "reading the journal changes no campaign state")

	# Pinning survives a save and load, and toggles off.
	gs.pin_commitment(String(courier["id"]))
	check(gs.pinned().get("id", "") == courier["id"], "a commitment can be pinned")
	var gs2 = load("res://scripts/game_state.gd").new()
	gs2.persist = false
	gs2.from_dict(JSON.parse_string(JSON.stringify(gs.to_dict())))
	check(gs2.pinned().get("id", "") == courier["id"], "the pin survives a save and load")
	gs2.free()

	# An expired job leaves the list, explains itself, and drops its pin.
	courier["deadline"] = w.hour - 1.0
	gs._check_job_deadlines()
	check(_find(String(courier["id"])).is_empty(), "an expired job leaves the active list")
	check(not gs.ended_commitments.is_empty() and String(gs.ended_commitments[0]["outcome"]).contains("Expired"),
		"and the journal says how it ended")
	check(gs.pinned().is_empty() and gs.pinned_commitment == "", "and its pin is cleared")

	# The journal on the map: open it, open a commitment, show it on the map without riding.
	gs.map_notice = "" # the expiry notice would open first, as it should
	change_scene_to_file("res://scenes/world_map.tscn")
	await process_frame
	await process_frame
	var map = current_scene
	var hour: float = w.hour
	var moving: bool = w.player().moving()
	map._open_journal()
	check(map.sheet_title.text.begins_with("Journal") and map.sheet_extra.find_child("Commitment_" + String(relief["id"]).validate_node_name(), true, false) != null,
		"the journal lists the commitments")
	map._open_commitment(String(relief["id"]))
	check(map.sheet_title.text == relief["title"] and map.sheet_body.text.contains("Reward"), "a commitment shows its objective and reward")
	map._focus_place("thornwall")
	await process_frame
	check(map._selected == "thornwall" and w.hour == hour and w.player().moving() == moving,
		"Show on map focuses the place without starting travel or time")
	map._on_pin(String(relief["id"]))
	map._open_journal()
	var rows: Node = map.sheet_extra.find_child("JournalRows", true, false)
	var first: Node = rows.get_child(0) if rows != null and rows.get_child_count() > 0 else null
	check(first != null and first.text == String(relief["title"]) and bool(first.get_meta("pinned", false)), "a pinned commitment leads the journal")

	_check_advice()

	print("\nJournal tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)


## The next step a new or a broke company is given, the gate on hiring, and the step up
## for a vassal and for a crown. A campaign of its own, so the journal's is untouched.
func _check_advice() -> void:
	var st = load("res://scripts/game_state.gd").new()
	st.persist = false
	st.new_campaign(Cultures.VARDISH)
	var sw = st.world
	# Before the first fight: the nearest band, by name, with its id to show it.
	var rec: Dictionary = st.recommendation()
	var first_band = sw.party(int(rec.get("party", -1)))
	check(st.battles == 0 and String(rec.get("action", "")) == "band" and first_band != null
		and String(rec.get("title", "")).contains(String(first_band.name)),
		"a new company's first step names the nearest bandit band")
	# Broke: a contract at the nearest town or castle, not a shop.
	st.silver = 5
	rec = st.recommendation()
	var work_place := String(rec.get("place", ""))
	check(String(rec.get("title", "")).begins_with("Take a contract at") and WorldData.SETTLEMENTS.has(work_place)
		and String(WorldData.settlement(work_place)["type"]) != WorldData.VILLAGE,
		"a company that can't pay tomorrow is sent to a notice board")
	st.food = 0
	rec = st.recommendation()
	check(String(rec.get("title", "")).begins_with("Take a contract at"), "even when hungry, if it can't buy a day of food")
	st.silver = 400
	rec = st.recommendation()
	check(String(rec.get("title", "")) == "Buy provisions", "with silver for food, hunger sends it to buy some")
	st.food = 500
	# Every board bare: the weakest band near instead.
	st.silver = 5
	for board in WorldData.SETTLEMENTS:
		if String(WorldData.settlement(board)["type"]) != WorldData.VILLAGE:
			sw.settlement_jobs[board] = []
			sw.settlement_jobs_back[board] = sw.hour + 500.0
	rec = st.recommendation()
	check(String(rec.get("action", "")) == "band" and String(rec.get("body", "")).contains("weakest"),
		"with every notice board bare, the weakest band near")
	# The hire line waits for a purse that can pay the new company for three days.
	st.battles = 1
	st.silver = 400
	rec = st.recommendation()
	check(String(rec.get("title", "")) != "Room for another company", "400 silver isn't told to hire a company it then can't pay")
	st.silver = 5000
	rec = st.recommendation()
	check(String(rec.get("title", "")) == "Room for another company", "a full purse is told there's room for another company")
	# A vassal seated in a village: what the crown needs, and where to ask for walls.
	st.silver = 300
	st.renown = 60
	st.add_realm_relation("vardmark", 30)
	var sworn: bool = st.accept_fealty_and_fief("kettlebrook", "vardmark")
	check(sworn, "(a vassal of Vardmark, seated at Kettlebrook)")
	if sworn:
		st.player_fief["silver"] = 0
		rec = st.recommendation()
		check(String(rec.get("title", "")) == "Toward a crown" and String(rec.get("body", "")).contains("200 renown")
			and String(rec.get("body", "")).contains("liege's court"),
			"a vassal is told the renown a crown needs and to ask at the liege's court for walls")
	# A crown: how many seats fly its banner.
	st.player_fief = {}
	var seats := 0
	var castle_seat := ""
	for sid in WorldData.SETTLEMENTS:
		var kind := String(WorldData.settlement(sid)["type"])
		if kind != WorldData.VILLAGE:
			seats += 1
		if kind == WorldData.CASTLE and castle_seat == "":
			castle_seat = String(sid)
	sw.declare_crown(castle_seat)
	rec = st.recommendation()
	check(st.is_crowned() and String(rec.get("title", "")) == "Bring every seat under the crown"
		and String(rec.get("body", "")).begins_with("1 of %d held" % seats),
		"a crown is told how many seats it holds of all of them")
	st.free()
