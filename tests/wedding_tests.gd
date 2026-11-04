## The wedding as an event you ride to: saying yes asks where, the place gets ready and
## waits, the day itself (who came, vows, rite, toasts, the closing card), the memory told
## again, calling it off, postponement, private vows, and saves (old ones too).
extends SceneTree

const Cultures = preload("res://scripts/data/cultures.gd")
const Relationships = preload("res://scripts/data/relationships.gd")
const WorldData = preload("res://scripts/world/world_data.gd")

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


## A fresh campaign at Ravensford with Edda's story at its last chapter.
func _ready_for_ch5() -> void:
	gs.new_campaign(Cultures.VARDISH)
	gs.silver = 1000
	gs.food = 500
	var soc = gs.world.social
	gs.world.player().node = "ravensford"
	var rel: Dictionary = soc.relationships["edda"]
	rel["romantic_intent"] = true
	rel["trust"] = 60
	rel["status"] = Relationships.COMMITTED
	soc.quests["quest_edda"]["chapter"] = 5
	var person: Dictionary = soc.get_candidate_person("edda")
	soc.houses[person["house_id"]]["standing"] = 30
	soc.add_memory(person["id"], "Shared the story of Edda's spare spoon.", {"kind": "visit", "scene_id": "edda_spare_spoon"})


func _open_talk() -> void:
	scenes.active_candidate_id = "edda"
	scenes.conversation_return = "res://scenes/settlement.tscn"
	change_scene_to_file("res://scenes/conversation.tscn")
	await _arrive("conversation.tscn")


## Let the world run (the company waiting where it is) until `done` or `hours` pass.
func _wait(hours: float, done: Callable = Callable()) -> void:
	var w = gs.world
	var until: float = w.hour + hours
	while w.hour < until:
		w.wait(6.0)
		gs.advance(6.0)
		w.encounter = -1
		if done.is_valid() and done.call():
			return


func _init() -> void:
	await process_frame
	gs = root.get_node("GameState")
	scenes = root.get_node("Scenes")
	gs.persist = false

	# ---- saying yes asks where
	_ready_for_ch5()
	var soc = gs.world.social
	await _open_talk()
	var talk = current_scene
	talk.choose("story")
	check(talk.has_reply("decide_marry_public"), "the last chapter offers a public wedding")
	talk.choose("decide_marry_public")
	talk.choose("confirm")
	check(gs.silver == 900 and gs.food == 400, "100 silver and 100 rations are set aside (%d, %d)" % [gs.silver, gs.food])
	check(soc.relationships["edda"]["status"] == Relationships.ENGAGED and gs.wedding()["state"] == "planning", "engaged, the place still to choose")
	check(talk.has_reply("place_ravensford") and talk.has_reply("later"), "she asks where: her seat, or later")
	check(not soc.preview_choice("edda", "marry_private", gs._social_context())["ok"], "no second wedding while one is planned")
	talk.choose("place_ravensford")
	var w: Dictionary = gs.wedding()
	check(w["state"] == "preparing" and w["place"] == "ravensford", "the wedding is being made ready at Ravensford")
	check(fposmod(float(w["ready_hour"]), 24.0) == Relationships.WEDDING_DUSK_HOUR and float(w["ready_hour"]) >= gs.world.hour + 24.0, "ready at dusk, a day on")
	var entry: Dictionary = gs.wedding_commitment()
	check(entry["id"] == "wedding" and entry["place"] == "ravensford" and String(entry["title"]).contains("Ravensford"), "the journal holds it, with a pin on the map")
	check(not gs.wedding_can_begin(), "it can't begin before it's ready")
	talk.choose("back")
	check(talk.has_reply("wedding") and not talk.has_reply("story"), "her hub talks about the wedding instead of the last chapter")

	# ---- it gets ready, and waits for you
	_wait(96.0)
	check(gs.wedding()["state"] == "ready", "ready after the preparations")
	check(soc.relationships["edda"]["status"] == Relationships.ENGAGED, "it never marries you by itself, however long you wait")
	check(soc.letters.any(func(l): return l["template_key"] == "wedding_ready"), "she writes when it's ready")
	check(gs.wedding_can_begin(), "at Ravensford, it can begin")
	gs.world.player().node = "highcliff"
	check(not gs.wedding_can_begin(), "anywhere else, it can't")
	gs.world.player().node = "ravensford"

	# ---- who comes
	var friend: Dictionary = {}
	var foe: Dictionary = {}
	for l in gs.world.lords:
		if friend.is_empty() and String(l["realm"]) == "vardmark" and not bool(l.get("ruler", false)) and String(l.get("state", "")) != "prisoner":
			var person: Dictionary = soc.get_candidate_person("edda")
			var host_id := int(soc.get_person(String(soc.get_house(person["house_id"])["head_person_id"])).get("lord_id", -1))
			if int(l["id"]) != host_id:
				friend = l
		if foe.is_empty() and String(l["realm"]) == "kharzan":
			foe = l
	friend["met_player"] = true
	gs.add_lord_relation(int(friend["id"]), 60)
	foe["met_player"] = true
	gs.add_lord_relation(int(foe["id"]), 60)
	gs.add_realm_relation("kharzan", -80)
	var guests: Dictionary = gs.wedding_guests()
	var kinds: Array = guests["guests"].map(func(g): return String(g["kind"]))
	check(kinds.has("host") and kinds.has("captain"), "her house's head hosts and your captains come")
	check(guests["guests"].any(func(g): return int(g["id"]) == int(friend["id"]) and g["kind"] == "lord"), "a lord who thinks well of you comes")
	check(not guests["guests"].any(func(g): return g["kind"] != "captain" and int(g["id"]) == int(foe["id"])), "a lord at war with you stays away")
	gs.fallen.append({"first": "Rowan", "name": "Rowan"})

	# ---- the day
	var renown0: int = gs.renown
	var host: Dictionary = {}
	for g in guests["guests"]:
		if g["kind"] == "host":
			host = gs.world.lord_by_id(int(g["id"]))
	var host_rel0: int = gs.relation_with_lord(int(host["id"]))
	var friend_rel0: int = gs.relation_with_lord(int(friend["id"]))
	var silver0: int = gs.silver
	var food0: int = gs.food
	scenes.wedding_replay = ""
	scenes.wedding_return = "res://scenes/world_map.tscn"
	change_scene_to_file("res://scenes/wedding.tscn")
	await _arrive("wedding.tscn")
	var day = current_scene
	check(day.get_node_or_null("Stage/Dressing") != null and day.get_node_or_null("Stage/Face_center") != null, "the place is dressed, and she stands at its centre")
	check(day.find_child("WhoCame", true, false) != null and day.has_reply("begin") and day.has_reply("later"), "who came, then: take your place, or not yet")
	day.choose("begin")
	check(day.log_text().contains("spare spoon") and day.find_child("Remembers", true, false) != null, "her vow comes from the time you shared")
	check(day.has_reply("vow_promise") and day.has_reply("vow_honest") and day.has_reply("vow_laugh"), "three vows of your own")
	day.choose("vow_promise")
	check(day.log_text().contains("red cord"), "the Vardish rite: the cord")
	check(day.find_children("SpeakerFace", "", true, false).size() >= 1, "a captain toasts, face beside their name")
	check(day.has_reply("toast_absent") and String(day._replies.get_node("Reply_toast_absent").find_child("Text", true, false).text).contains("Rowan"), "absent friends names the fallen")
	day.choose("toast_absent")
	check(soc.relationships["edda"]["status"] == Relationships.MARRIED and gs.wedding()["state"] == "done", "married")
	check(day.find_child("MarriedTitle", true, false) != null and day.has_reply("done"), "one closing card, one way back")
	check(gs.renown == renown0 + Relationships.WEDDING_RENOWN, "renown for a public wedding")
	check(gs.relation_with_lord(int(host["id"])) == host_rel0 + Relationships.WEDDING_HOST_REGARD and gs.relation_with_lord(int(friend["id"])) == friend_rel0 + Relationships.WEDDING_GUEST_REGARD,
		"Regard for the host and the guest who came")
	check(gs.silver == silver0 and gs.food == food0, "nothing more is taken on the day")
	var person_e: Dictionary = soc.get_candidate_person("edda")
	var pact: Dictionary = soc.get_pact(person_e["house_id"])
	check(pact["origin"] == "marriage" and pact["protected_sites"].has("ravensford") and not pact["protected_sites"].has("thornwall"), "the pact protects her seat, not a village you don't hold")
	var mem: Dictionary = {}
	for m in soc.memory_book(person_e["id"]):
		if m["kind"] == "ceremony":
			mem = m
	check(String(mem.get("vow", "")).begins_with("I'll come home") and String(mem.get("toast", "")).contains("Rowan"), "the memory keeps your vow and toast")
	check(gs.world.activity_log.any(func(e): return String(e.get("text", e.get("line", ""))).contains("married at Ravensford")), "the news tells of it")

	# ---- told again from her page
	change_scene_to_file("res://scenes/people.tscn")
	await _arrive("people.tscn")
	current_scene._person = "edda"
	current_scene._build()
	await process_frame
	var row = current_scene.find_child("Memory_" + String(mem["id"]), true, false)
	check(row != null, "her page lists the wedding")
	row.pressed.emit()
	await _arrive("wedding.tscn")
	check(current_scene.log_text().contains("I'll come home") and current_scene.has_reply("finish"), "Relive tells it again with your own vow")
	check(soc.relationships["edda"]["status"] == Relationships.MARRIED, "and changes nothing")

	# ---- calling it off
	_ready_for_ch5()
	soc = gs.world.social
	gs.apply_social_choice("edda", "marry_public")
	gs.choose_wedding_place("ravensford")
	var r: Dictionary = gs.cancel_wedding()
	check(r["ok"] and gs.silver == 1000 and gs.food == 500, "calling it off gives back what was set aside")
	check(soc.relationships["edda"]["status"] == Relationships.COMMITTED and not gs.wedding_active(), "together as before, no wedding planned")
	check(soc.preview_choice("edda", "marry_public", gs._social_context())["ok"], "and you can ask again")

	# ---- postponed
	gs.apply_social_choice("edda", "marry_public")
	gs.choose_wedding_place("ravensford")
	gs.world.burned["ravensford"] = gs.world.hour + 200.0
	_wait(12.0)
	check(gs.wedding()["state"] == "postponed" and String(gs.wedding()["postponed_reason"]).contains("burned"), "a burned town postpones it")
	check(soc.letters.any(func(l): return l["template_key"] == "wedding_postponed"), "and she writes to choose again")
	check(not bool(gs.wedding_places("edda")[0]["ok"]), "it can't be chosen again while it smoulders")
	var other := ""
	for p in gs.wedding_places("edda"):
		if p["ok"]:
			other = String(p["id"])
	check(other != "" and gs.choose_wedding_place(other)["ok"] and gs.wedding()["state"] == "preparing", "a new place resumes it (%s)" % other)

	# ---- saves
	var saved: Dictionary = JSON.parse_string(JSON.stringify(soc.to_dict()))
	soc.from_dict(saved)
	check(soc.wedding["state"] == "preparing" and soc.wedding["place"] == other and soc.wedding["reserved_silver"] is int, "a planned wedding survives a save")
	var old := saved.duplicate(true)
	old.erase("wedding")
	old["scheduled_ceremony"] = {"active": true, "completed": false, "candidate_id": "edda", "person_id": "person_edda",
		"settlement_id": "ravensford", "scheduled_at_hour": 10.0, "cost_silver": 100, "cost_food": 100}
	soc.from_dict(old)
	check(soc.wedding["state"] == "ready" and soc.wedding["place"] == "ravensford" and soc.wedding["reserved_silver"] == 100, "an old save's timed ceremony waits, ready, at its place")

	# ---- private vows
	_ready_for_ch5()
	soc = gs.world.social
	await _open_talk()
	talk = current_scene
	talk.choose("story")
	talk.choose("decide_marry_private")
	talk.choose("confirm")
	check(soc.relationships["edda"]["status"] == Relationships.MARRIED and gs.silver == 1000, "private vows: married at once, no cost")
	check(talk.log_text().contains("one candle") or talk.log_text().contains("A candle"), "by one candle, in her room")
	check(talk.has_reply("vow_honest"), "the same vows to say")
	talk.choose("vow_honest")
	var pm: Dictionary = soc.memory_book(soc.get_candidate_person("edda")["id"]).back()
	check(pm["kind"] == "ceremony" and bool(pm.get("private", false)) and String(pm.get("vow", "")).begins_with("I can't promise"), "kept as a memory with your vow")
	check(soc.get_pact(soc.get_candidate_person("edda")["house_id"]).is_empty(), "no pact without the house")

	print("FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)
