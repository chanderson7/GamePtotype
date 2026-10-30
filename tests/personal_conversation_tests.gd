## Optional dialogue state, side-effect isolation, migration, and real menu interactions.
extends SceneTree
const WorldSim = preload("res://scripts/world/world_sim.gd")
const SocialSim = preload("res://scripts/world/social_sim.gd")
const Cultures = preload("res://scripts/data/cultures.gd")
const Stories = preload("res://scripts/data/personal_conversations.gd")
const Relationships = preload("res://scripts/data/relationships.gd")
const PERSON := "person_edda"
const FIRST := "edda_spare_spoon"
var failures := 0
var checks := 0
var ctx := {"settlement_id": "ravensford", "invitations_enabled": true}

func _init() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	print("%s %s" % ["ok" if ok else "FAIL", label])
	if not ok:
		failures += 1

func fresh():
	var w := WorldSim.new()
	w.setup(42, Cultures.VARDISH)
	return w

func finish(social, id: String, choice: int = 0) -> Dictionary:
	social.personal_action(PERSON, id, "begin", ctx)
	social.personal_action(PERSON, id, "choose", ctx, choice)
	return social.personal_action(PERSON, id, "finish", ctx)

func _run() -> void:
	var gs = root.get_node("GameState")
	gs.persist = false
	var w = fresh()
	var soc = w.social
	check(not soc.personal_scene_access(PERSON, FIRST, ctx)["ok"], "introduction is required")
	check(not soc.personal_scene_access("person_farid", FIRST, ctx)["ok"], "candidates cannot access another person's scenes")
	check(Stories.ids_for("farid").size() == 6 and Stories.ids_for("kaede").size() == 6,
		"Farah and Kaede each have six personal conversations")
	soc.apply_choice("farid", "another_time", {})
	soc.apply_choice("kaede", "another_time", {})
	check(soc.personal_scene_access("person_farid", "farid_supper_request", {"settlement_id": "qasr_hamra"})["ok"],
		"Farah's first visit opens at Qasr Hamra")
	check(soc.personal_scene_access("person_kaede", "kaede_useless_map", {"settlement_id": "kitayama"})["ok"],
		"Kaede's first visit opens at Kitayama")
	soc.apply_choice("edda", "another_time", {})
	check(soc.personal_scene_access(PERSON, FIRST, ctx)["ok"], "neutral introduction unlocks optional visits without romantic intent")
	check(not soc.personal_scene_access(PERSON, FIRST, {})["ok"], "missing location rejected in simulation")
	check(not soc.personal_scene_access(PERSON, FIRST, {"settlement_id": "kitayama"})["ok"], "remote first play rejected")
	check(not soc.personal_scene_access(PERSON, "edda_boots_by_door", ctx)["ok"], "optional prerequisite enforced")
	check(not soc.personal_action(PERSON, FIRST, "finish", ctx)["ok"], "cannot claim unstarted scene")
	var baseline: Dictionary = w.to_dict().duplicate(true)
	soc.personal_action(PERSON, FIRST, "begin", ctx)
	check(not soc.personal_action(PERSON, FIRST, "finish", ctx)["ok"], "cannot finish before response")
	check(not soc.personal_action(PERSON, FIRST, "choose", ctx, 99)["ok"], "invalid response rejected")
	check(soc.get_relationship("edda")["trust"] == 10, "begin and interrupted visit grant nothing")
	soc.personal_action(PERSON, FIRST, "choose", ctx, 1)
	var loaded := WorldSim.new()
	loaded.from_dict(JSON.parse_string(JSON.stringify(w.to_dict())))
	var resumed: Dictionary = loaded.social.personal_action(PERSON, FIRST, "begin", ctx)
	check(resumed["progress"]["node"] == 1 and resumed["progress"]["choice"] == 1, "JSON round trip resumes exact response")
	baseline = loaded.to_dict().duplicate(true)
	var reward: Dictionary = loaded.social.personal_action(PERSON, FIRST, "finish", ctx)
	check(reward["trust_change"] == 1, "completion awards one trust")
	var after: Dictionary = loaded.to_dict().duplicate(true)
	# Strip precisely the permitted effects; every other world field must match.
	after["social"]["personal_conversations"] = baseline["social"]["personal_conversations"]
	after["social"]["relationships"]["edda"]["trust"] = baseline["social"]["relationships"]["edda"]["trust"]
	after["social"]["relationships"]["edda"]["memories"] = baseline["social"]["relationships"]["edda"]["memories"]
	after["social"]["people"][PERSON]["memories"] = baseline["social"]["people"][PERSON]["memories"]
	check(after == baseline, "all world, quest, pact, house, army, timer and RNG state unchanged")
	soc = loaded.social
	var saved: Dictionary = soc.to_dict().duplicate(true)
	check(not soc.personal_action(PERSON, FIRST, "finish", ctx)["ok"], "duplicate completion rejected")
	check(not soc.personal_action(PERSON, FIRST, "choose", ctx, 0)["ok"], "replay cannot overwrite campaign choices")
	check(saved == soc.to_dict(), "duplicate requests leave all social state unchanged")
	check(soc.personal_scene_access(PERSON, FIRST, {})["replay"], "archive accessible remotely")
	check(soc.personal_scene_access(PERSON, "edda_boots_by_door", ctx)["ok"], "either opening scene unlocks third")
	soc.relationships["edda"]["strained"] = true
	check(not soc.personal_scene_access(PERSON, "edda_wrong_verse", ctx)["ok"], "strained blocks new scenes")
	check(soc.personal_scene_access(PERSON, FIRST, {})["ok"], "strained preserves archive")
	soc.relationships["edda"]["strained"] = false
	soc.people[PERSON]["status"] = "displaced"
	check(not soc.personal_scene_access(PERSON, "edda_wrong_verse", ctx)["ok"], "displaced contact cannot receive visits")
	soc.people[PERSON]["status"] = "relocated"
	soc.people[PERSON]["residence"] = "kitayama"
	check(not soc.personal_scene_access(PERSON, "edda_wrong_verse", ctx)["ok"], "old residence rejected after relocation")
	check(soc.personal_scene_access(PERSON, "edda_wrong_verse", {"settlement_id": "kitayama"})["ok"], "current residence works after relocation")
	soc.people[PERSON]["residence"] = "ravensford"
	for id in ["edda_wrong_verse", "edda_boots_by_door", "edda_morning_unclaimed", "edda_ledger_blot"]:
		finish(soc, id)
	check(soc.relationships["edda"]["trust"] == 13 and soc.personal_record(PERSON)["bonus_claims"].size() == 3, "five scenes award exactly three total trust")
	check(not soc.personal_scene_access(PERSON, "edda_place_no_task", ctx)["ok"], "coda requires main relationship milestone")
	soc.relationships["edda"]["status"] = Relationships.FRIENDSHIP
	check(finish(soc, "edda_place_no_task")["ok"], "friendship unlocks coda")
	check(soc.personal_record(PERSON)["completed"].size() == 6 and soc.relationships["edda"]["trust"] == 13, "all six scenes complete without exceeding cap")
	soc.separate("edda")
	check(soc.personal_record(PERSON)["bonus_claims"].size() == 3, "separation preserves lifetime bonus claims")
	var legacy: Dictionary = soc.to_dict().duplicate(true)
	legacy.erase("personal_conversations")
	var migrated := SocialSim.new()
	migrated.from_dict(legacy)
	check(migrated.personal_record(PERSON)["completed"].is_empty(), "legacy saves default to empty personal history without backfill")
	check(migrated.relationships == soc.relationships, "legacy migration preserves relationships")
	_check_cap_and_content()
	_check_progress_and_gates()
	await _check_ui(gs)
	print("Personal conversations: %d checks, %d failures" % [checks, failures])
	quit(failures)

func _check_cap_and_content() -> void:
	var w = fresh()
	var soc = w.social
	soc.apply_choice("edda", "know_better", {"invitations_enabled": true})
	soc.relationships["edda"]["trust"] = 100
	for id in [FIRST, "edda_wrong_verse", "edda_boots_by_door"]:
		check(finish(soc, id)["trust_change"] == 0, "trust at 100 consumes a claim without overflow")
	soc.relationships["edda"]["trust"] = 50
	check(finish(soc, "edda_morning_unclaimed")["trust_change"] == 0, "maximum-trust claims cannot be banked for later")
	for choice in 3:
		w = fresh()
		soc = w.social
		soc.apply_choice("edda", "offer_help", {})
		check(finish(soc, FIRST, choice)["trust_change"] == 1, "response %d has the same reward" % choice)
	w = fresh()
	soc = w.social
	soc.apply_choice("edda", "know_better", {"invitations_enabled": true})
	soc.personal_action(PERSON, FIRST, "begin", {"settlement_id": "ravensford", "invitations_enabled": false})
	check(soc.personal_action(PERSON, FIRST, "summary", ctx)["trust_change"] == 1, "summary receives equal reward")
	check(soc.personal_record(PERSON)["cosmetic_choices"][FIRST] == -1, "summary saves neutral choice")
	check(not soc.personal_record(PERSON)["completed"][FIRST]["context"]["romantic"], "invitations off gives neutral context")
	check(soc.relationships["edda"]["romantic_intent"], "neutral visit does not erase existing romance")
	check(not Stories.ending("edda_place_no_task", {}, [], {}).contains("drawer"), "coda handles missing optional opening")
	check(Stories.ending("edda_place_no_task", {"romantic": true}, [FIRST], {}).contains("takes it"), "romantic coda reflects established relationship")
	for id in Stories.SCENES:
		var story: Dictionary = Stories.SCENES[id]
		for response in story["responses"]:
			var count := String(story["opening"] + " " + response + " " + story["closing"]).split(" ", false).size()
			check(count >= 250 and count <= 400, "%s path has 250–400 words (%d)" % [id, count])


func _check_progress_and_gates() -> void:
	var w = fresh()
	var soc = w.social
	soc.apply_choice("edda", "know_better", {"invitations_enabled": true})
	soc.personal_action(PERSON, FIRST, "begin", ctx)
	soc.personal_action(PERSON, FIRST, "choose", ctx, 2)
	soc.personal_action(PERSON, "edda_wrong_verse", "begin", ctx)
	check(soc.personal_action(PERSON, FIRST, "begin", ctx)["progress"]["choice"] == 2, "starting another story preserves unfinished visits")
	var neutral: Dictionary = soc.personal_action(PERSON, FIRST, "begin", {"settlement_id": "ravensford", "invitations_enabled": false})
	check(not neutral["progress"]["context"]["romantic"], "resuming after disabling invitations uses neutral presentation")
	soc.relationships["edda"]["trust"] = 57
	for id in [FIRST, "edda_wrong_verse", "edda_boots_by_door"]:
		soc.personal_action(PERSON, id, "begin", ctx)
		soc.personal_action(PERSON, id, "summary", ctx)
	check(soc.relationships["edda"]["trust"] == 60, "small bonus can tip 57 to 60")
	check(not soc.preview_choice("edda", "marry_private", {})["ok"], "trust threshold cannot bypass main chapters")
	var p: Dictionary = soc.people[PERSON]
	var house: Dictionary = soc.houses[p["house_id"]]
	soc.quests["quest_edda"]["chapter"] = 5
	soc.relationships["edda"]["romantic_intent"] = false
	check(not Relationships.can_marry_private(soc.relationships["edda"])["ok"], "trust cannot replace mutual intent")
	soc.relationships["edda"]["romantic_intent"] = true
	soc.relationships["edda"]["strained"] = true
	check(not Relationships.can_marry_private(soc.relationships["edda"])["ok"], "trust cannot repair a breach")
	soc.relationships["edda"]["strained"] = false
	check(not Relationships.can_marry_public(soc.relationships["edda"], house)["ok"], "trust cannot replace house standing")
	w.setup(42, Cultures.VARDISH)
	check(w.social.personal_record(PERSON)["bonus_claims"].is_empty(), "new campaign resets optional history")

func button(text: String) -> Button:
	return _find(current_scene, text)

func _find(node: Node, text: String) -> Button:
	if node is Button and node.text == text:
		return node
	for child in node.get_children():
		var found := _find(child, text)
		if found != null:
			return found
	return null

func _check_ui(gs) -> void:
	gs.new_campaign(Cultures.VARDISH)
	gs.world.player().node = "ravensford"
	gs.world.social.apply_choice("edda", "offer_help", {})
	var scenes = root.get_node("Scenes")
	scenes.active_person_id = PERSON
	scenes.active_candidate_id = "edda"
	change_scene_to_file("res://scenes/people.tscn")
	await process_frame
	await process_frame
	check(button("Spend time / memories") != null, "People exposes personal conversations")
	change_scene_to_file("res://scenes/conversation.tscn")
	await process_frame
	await process_frame
	check(button("Spend time / memories") != null, "audience exposes personal conversations")
	change_scene_to_file("res://scenes/personal_conversation.tscn")
	await process_frame
	await process_frame
	check(button("Visit: The Spare Spoon") != null, "personal library loads")
	var before: Dictionary = gs.to_dict().duplicate(true)
	button("Visit: The Spare Spoon").pressed.emit()
	check(button("Summary") != null, "reader offers accessible summary")
	_read_to_end()
	button("You missed your own place.").pressed.emit()
	button("Leave").pressed.emit()
	check(button("Resume: The Spare Spoon") != null, "leaving preserves response for resume")
	button("Resume: The Spare Spoon").pressed.emit()
	_read_to_end()
	check(button("Keep this memory") != null, "resume returns to closing passage")
	button("Keep this memory").pressed.emit()
	check(button("Remember: The Spare Spoon") != null, "completed scene enters archive")
	check(gs.silver == before["silver"] and gs.food == before["food"] and gs.renown == before["renown"] and gs.army == before["army"], "UI visit preserves player resources and army")
	var archived: Dictionary = gs.to_dict().duplicate(true)
	button("Remember: The Spare Spoon").pressed.emit()
	_read_to_end()
	button("Who usually arrived late?").pressed.emit()
	_read_to_end()
	button("Close memory").pressed.emit()
	check(archived == gs.to_dict(), "replay through real UI changes no campaign data")
	button("Visit: The Wrong Last Verse").pressed.emit()
	button("Summary").pressed.emit()
	button("Keep this memory").pressed.emit()
	check(gs.world.social.personal_record(PERSON)["completed"].size() == 2, "summary completes through real UI")


func _read_to_end() -> void:
	for i in 60:
		var next := button("Continue")
		if next == null:
			return
		next.pressed.emit()
	check(false, "reader reaches the end in bounded steps")
