## The romance talk (story decisions shown as decisions, visits as chat), memories you can
## open again, greetings and callbacks, the captains' talks at the fire with a tab per rank,
## and the battle results telling bonds once.
extends SceneTree

const Cultures = preload("res://scripts/data/cultures.gd")
const Lines = preload("res://scripts/data/romance_talk_lines.gd")
const Stories = preload("res://scripts/data/personal_conversations.gd")

var failures := 0


func check(ok: bool, message: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + message)
	if not ok:
		failures += 1


## Wait until the scene ending in `path` is current (fades take a few frames).
func _arrive(path: String) -> void:
	for i in 240:
		await process_frame
		if current_scene != null and current_scene.scene_file_path.ends_with(path) and current_scene.is_node_ready():
			return


func _init() -> void:
	await process_frame
	var gs = root.get_node("GameState")
	var scenes = root.get_node("Scenes")
	gs.persist = false
	gs.new_campaign(Cultures.VARDISH)
	var social = gs.world.social
	gs.world.player().node = "ravensford"
	var edda: Dictionary = social.get_candidate_person("edda")
	var pid := String(edda["id"])

	# ---- the hub
	scenes.active_candidate_id = "edda"
	scenes.conversation_return = "res://scenes/people.tscn"
	change_scene_to_file("res://scenes/conversation.tscn")
	await process_frame
	await process_frame
	var talk = current_scene
	check(talk.log_text().contains(Lines.greeting("edda", "unknown")), "they greet you by how things stand")
	check(talk.has_reply("story") and talk.has_reply("leave"), "one place for your story and for leaving")
	check(talk.get_node_or_null("Stage/Room") != null and talk.get_node_or_null("Stage/Face_left") != null, "face to face, in their room")
	check(talk.find_child("TrustBar", true, false) != null, "with trust on the nameplate")

	# ---- a decision is marked as one, with what it does
	talk.choose("story")
	var topics: Array = talk.reply_ids().filter(func(id): return String(id).begins_with("topic_"))
	check(not topics.is_empty(), "a first audience starts with talk")
	talk.choose(topics[0])
	check(talk.has_reply("decide_offer_help"), "then asks what you mean to be to each other")
	var tag := String(talk._replies.get_node("Reply_decide_offer_help").find_child("Tag", true, false).text)
	check(tag.begins_with("Decision") and tag.contains("+10 trust") and tag.contains("acquainted"), "a decision says what it does (%s)" % tag)
	var trust0 := int(social.get_relationship("edda")["trust"])
	talk.choose("decide_offer_help")
	check(int(social.get_relationship("edda")["trust"]) == trust0 + 10 and social.get_relationship("edda")["status"] == "acquainted", "and does it")
	check(talk._log.find_child("Note", true, false) != null, "and the talk says what changed")

	# ---- visits, from the hub
	talk.choose("back")
	check(talk.has_reply("visit_edda_spare_spoon"), "time together opens after the first audience")
	var vtag := String(talk._replies.get_node("Reply_visit_edda_spare_spoon").find_child("Tag", true, false).text)
	check(vtag.contains("no wrong answers") and not vtag.contains("trust"), "a visit shows no numbers (%s)" % vtag)
	talk.choose("visit_edda_spare_spoon")
	for i in 60:
		if not talk.has_reply("continue"):
			break
		talk.choose("continue")
	check(talk._log.find_children("Them", "", true, false).size() > 0 and talk._log.find_children("Narration", "", true, false).size() > 0,
		"their lines are bubbles and narration stands apart")
	talk.choose("say_0")
	for i in 60:
		if not talk.has_reply("continue"):
			break
		talk.choose("continue")
	talk.choose("finish")
	check(talk._log.find_child("Keepsake", true, false) != null, "a kept memory is shown as one")

	# ---- the memory book
	var book: Array = social.memory_book(pid)
	var visit: Dictionary = {}
	var decision: Dictionary = {}
	for m in book:
		if m["kind"] == "visit":
			visit = m
		if m["kind"] == "decision":
			decision = m
	check(String(visit.get("scene_id", "")) == "edda_spare_spoon" and visit.get("place", "") == "ravensford", "a visit is remembered with its scene and place")
	check(int(decision.get("chapter", 0)) == 1 and String(decision.get("choice", "")) == "offer_help", "a decision with its chapter and choice")
	check(Lines.callback(visit) == Lines.VISITS["edda_spare_spoon"] and Lines.callback(decision) == Lines.CHAPTERS[1], "each has something they say about it")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(social.to_dict()))
	social.from_dict(saved)
	check(social.memory_book(pid).any(func(m): return m["kind"] == "visit" and int(m["day"]) >= 1), "memories keep what they are across a save")
	# An older campaign's plain memories still show.
	var person: Dictionary = social.people[pid]
	var log_backup: Array = person["memory_log"].duplicate(true)
	person["memory_log"] = [{"text": "An old memory.", "day": 3}]
	check(social.memory_book(pid)[0]["kind"] == "note" and social.memory_book(pid)[0]["text"] == "An old memory.", "an old memory reads as a note")
	person["memory_log"] = log_backup

	# ---- the profile's memory book opens a visit again
	change_scene_to_file("res://scenes/people.tscn")
	await process_frame
	await process_frame
	current_scene._person = "edda"
	current_scene._build()
	await process_frame
	var row = current_scene.find_child("Memory_" + String(visit["id"]), true, false)
	check(row != null, "the profile lists memories you can open")
	row.pressed.emit()
	await _arrive("personal_conversation.tscn")
	check(current_scene.has_method("reply_ids") and current_scene.log_text().contains("Remembered"), "a visit memory opens as a replay")

	# ---- captains' talks at the fire, rank by rank
	var a: Dictionary = gs.army[0]["captain"]
	var b: Dictionary = gs.army[1]["captain"]
	a["bonds"][str(b["id"])] = 13.0
	b["bonds"][str(a["id"])] = 13.0
	check(gs.new_bond_talks().size() >= 1, "a new rank has a talk waiting at the fire")
	scenes.active_bond_a_id = int(a["id"])
	scenes.active_bond_b_id = int(b["id"])
	scenes.bond_conversation_return = "res://scenes/main_menu.tscn"
	change_scene_to_file("res://scenes/bond_conversation.tscn")
	await _arrive("bond_conversation.tscn")
	var fire = current_scene
	check(fire.get_node_or_null("BondConversationPortraits/Face_left") != null and fire.get_node_or_null("BondConversationPortraits/Face_right") != null, "two captains face each other by the fire")
	check(fire._log.find_children("Them", "", true, false).size() > 0 and fire._log.find_children("You", "", true, false).size() > 0, "and talk in turn")
	# Talks go in order: a pair that reached B without talking hears C first, then B.
	check(fire._rank == "C" and fire.find_child("RankTabs", true, false) == null, "a rank B bond that hasn't talked starts with its rank C talk, with no tabs to jump about")
	var c_text: String = fire.log_text()
	check(fire.reply_ids() == ["next"] and fire.choose("next"), "and goes on to their next talk")
	check(fire._rank == "B" and fire.log_text() != c_text, "which is rank B's, and reads differently")
	check(fire.reply_ids() == ["back"], "then the only way on is back")
	check(gs.new_bond_talks().is_empty(), "having heard both, nothing waits at the fire")

	# ---- results tell bonds once
	var c: Dictionary = gs.army[2]["captain"]
	var key_ab := "%d|%d" % [mini(int(a["id"]), int(c["id"])), maxi(int(a["id"]), int(c["id"]))]
	var report: Dictionary = gs.battle_report({"won": true, "squads": {}, "bonds": {key_ab: 60.0}})
	check(report["bonds"].size() == 1 and report.has("memorials"), "the report carries bonds and memorials")

	print("FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)
