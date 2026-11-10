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


## Until the screen change's fade is over (it takes no taps till then).
func _settled() -> void:
	for i in 240:
		if not root.get_node("Scenes")._busy:
			return
		await process_frame


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
	var plate_words: Array = talk._plate.find_children("*", "Label", true, false).map(func(l): return String(l.text))
	check(talk.find_child("TrustBar", true, false) == null and plate_words.has("Not yet met"), "nothing measured on the nameplate before you've met (%s)" % ", ".join(plate_words))

	# ---- a chapter is told a line at a time, then asks
	talk.choose("story")
	var lines_told: int = talk._log.get_children().filter(func(c): return c is HBoxContainer).size()
	check(talk.telling() and talk.reply_node("continue") != null and talk.reply_node("tell_all") != null and talk.reply_node("decide_offer_help") == null,
		"a chapter is told a line at a time, Go on for the next, and asks nothing until it's told")
	talk.reply_node("continue").pressed.emit()
	var lines_now: int = talk._log.get_children().filter(func(c): return c is HBoxContainer).size()
	check(lines_now == lines_told + 1, "Go on brings one line more (%d, then %d)" % [lines_told, lines_now])
	var writing: int = talk._log.find_children("Words", "Label", true, false).filter(func(l): return (l as Label).visible_characters >= 0).size()
	check(writing <= 1, "and only the newest of her lines is still being written out")

	# ---- a decision is marked as one, with what it does
	var topics: Array = talk.reply_ids().filter(func(id): return String(id).begins_with("topic_"))
	check(not topics.is_empty(), "a first audience starts with talk")
	talk.choose(topics[0])
	check(talk.has_reply("decide_offer_help"), "then asks what you mean to be to each other")
	var tag := String(talk._replies.get_node("Reply_decide_offer_help").find_child("Tag", true, false).text)
	check(tag.contains("as a friend") and tag.contains("now acquainted") and not tag.contains("trust"), "a decision says what it is and how things will stand, not a score (%s)" % tag)
	var said := String(talk._replies.get_node("Reply_decide_offer_help").find_child("Text", true, false).text)
	check(said.begins_with("\"") and not said.contains("Offer"), "and it reads as something you say (%s)" % said)
	var trust0 := int(social.get_relationship("edda")["trust"])
	talk.choose("decide_offer_help")
	check(int(social.get_relationship("edda")["trust"]) == trust0 + 10 and social.get_relationship("edda")["status"] == "acquainted", "and does it")
	check(talk._log.find_child("Reaction", true, false) == null or not talk.telling(), "her answer is told before what changed")
	if talk.telling():
		talk.tell_rest()
	check(talk._log.find_child("Reaction", true, false) != null and not talk.log_text().contains("+10"), "what changed is told as how she takes it, not as a number")
	var words: Array = talk._log.find_children("Words", "Label", true, false).filter(func(l): return String(l.text).contains("asks nothing"))
	check(words.size() == 1 and String(words[0].text).begins_with("A friend."), "her answer is her words alone in her bubble, with no quotes or narration inside it")
	check(talk.find_child("TrustBar", true, false) != null, "and trust appears on the nameplate once there is some")
	check(talk._log.find_child("Note", true, false) != null, "and the talk says what changed")

	# ---- visits, from the hub
	talk.choose("back")
	check(talk.has_reply("visit_edda_spare_spoon"), "time together opens after the first audience")
	var vtag := String(talk._replies.get_node("Reply_visit_edda_spare_spoon").find_child("Tag", true, false).text)
	check(vtag.begins_with("time together") and not vtag.contains("trust"), "a visit is offered as time together, with no numbers (%s)" % vtag)
	var vsaid := String(talk._replies.get_node("Reply_visit_edda_spare_spoon").find_child("Text", true, false).text)
	check(not vsaid.contains("Spend time") and not vsaid.contains("The Spare Spoon"), "and as something you say, not a title (%s)" % vsaid)
	talk.choose("visit_edda_spare_spoon")
	for i in 60:
		if not talk.has_reply("continue"):
			break
		talk.choose("continue")
	check(talk._log.find_children("Them", "", true, false).size() > 0 and talk._log.find_children("Narration", "", true, false).size() > 0,
		"their lines are bubbles and narration stands apart")
	# Through every point of the visit, taking the first thing offered at each.
	for i in 200:
		if talk.has_reply("finish"):
			break
		if talk.has_reply("continue"):
			talk.choose("continue")
		else:
			talk.choose(talk.reply_ids().filter(func(id): return String(id).begins_with("say_"))[0])
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
	check(current_scene.reply_node("later") != null and current_scene.reply_node("summary") == null, "which you can leave, and which has no short version")
	await _settled()
	current_scene.choose("later")
	await _arrive("people.tscn")
	await _settled()
	check(current_scene.scene_file_path.ends_with("people.tscn"), "leaving a memory opened from the book goes back to the book")

	# ---- and a decision opens as the moment it was
	current_scene._person = "edda"
	current_scene._build()
	await process_frame
	var visits_before := int(social.get_relationship("edda").get("visits", 0))
	var last_before = social.get_relationship("edda").get("last_visit_hour", -1.0)
	row = current_scene.find_child("Memory_" + String(decision["id"]), true, false)
	check(row != null, "the profile lists the decision too")
	row.pressed.emit()
	await _arrive("personal_conversation.tscn")
	await _settled()
	var moment = current_scene
	check(moment.log_text().contains("Remembered") and moment.log_text().contains("offer my sword") and moment.telling() and moment.reply_node("continue") != null,
		"a decision memory opens on what you said, her answer to come a line at a time")
	while moment.telling():
		moment.reply_node("continue").pressed.emit()
	check(moment.log_text().contains("there's a place at my table") and moment.reply_ids() == ["finish"], "then her answer, and the only way on is to close it")
	check(int(social.get_relationship("edda").get("visits", 0)) == visits_before and social.get_relationship("edda").get("last_visit_hour", -1.0) == last_before,
		"opening a memory is not a visit: nothing is counted")
	moment.choose("finish")
	await _arrive("people.tscn")
	await _settled()
	check(current_scene.scene_file_path.ends_with("people.tscn"), "and closing it goes back to the book")

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
	check(fire._log.find_children("Them", "", true, false).size() > 0 and fire._log.find_children("Other", "", true, false).size() > 0, "and talk in turn")
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

	# ---- she knows what happened since you last came
	gs.world.player().node = "ravensford"
	scenes.active_candidate_id = "edda"
	var cap: Dictionary = gs.army[0]["captain"]
	gs.fallen.append({"id": 999, "name": "Testa Grim", "first": "Testa", "battle": gs.battles + 1, "words": ""})
	change_scene_to_file("res://scenes/conversation.tscn")
	await _arrive("conversation.tscn")
	var first_words: String = current_scene._log.find_children("Words", "Label", true, false)[0].text
	check(first_words.contains("Testa"), "a captain lost since your last visit is her first words (%s)" % first_words)
	gs.fallen.clear()
	cap["wounded"] = 3
	change_scene_to_file("res://scenes/conversation.tscn")
	await _arrive("conversation.tscn")
	first_words = current_scene._log.find_children("Words", "Label", true, false)[0].text
	check(first_words.contains(String(cap["first"])) and first_words.contains("hurt"), "a wounded captain is noticed (%s)" % first_words)
	cap["wounded"] = 0
	var hour0: float = gs.world.hour
	gs.world.hour += 25.0 * 24.0
	gs.world.hour = floor(gs.world.hour / 24.0) * 24.0 + 10.0
	change_scene_to_file("res://scenes/conversation.tscn")
	await _arrive("conversation.tscn")
	first_words = current_scene._log.find_children("Words", "Label", true, false)[0].text
	check(first_words.begins_with("2") and first_words.contains("days"), "a long absence is counted (%s)" % first_words)
	gs.world.hour += 1.0
	change_scene_to_file("res://scenes/conversation.tscn")
	await _arrive("conversation.tscn")
	first_words = current_scene._log.find_children("Words", "Label", true, false)[0].text
	check(Lines.greetings("edda", "acquainted").has(first_words), "with nothing new, a greeting for how things stand (%s)" % first_words)
	var greeted := first_words
	gs.world.hour += 1.0
	change_scene_to_file("res://scenes/conversation.tscn")
	await _arrive("conversation.tscn")
	first_words = current_scene._log.find_children("Words", "Label", true, false)[0].text
	check((Lines.greetings("edda", "acquainted").has(first_words) or Lines.REMEMBERED["edda"].values().has(first_words)) and first_words != greeted,
		"and the next visit, another: the other greeting, or something you said to her (%s)" % first_words)
	for cand in ["edda", "farid", "kaede"]:
		for st in Lines.GREETINGS[cand]:
			check(Lines.greetings(cand, st).size() >= 2, "%s has two greetings when %s" % [cand, st])
	# A wound counts once: the same wounded captain isn't her first words twice.
	cap["wounded"] = 2
	gs.world.hour += 1.0
	change_scene_to_file("res://scenes/conversation.tscn")
	await _arrive("conversation.tscn")
	gs.world.hour += 1.0
	change_scene_to_file("res://scenes/conversation.tscn")
	await _arrive("conversation.tscn")
	first_words = current_scene._log.find_children("Words", "Label", true, false)[0].text
	check(not first_words.contains("hurt"), "a wound she's already seen doesn't open the next visit (%s)" % first_words)
	cap["wounded"] = 0
	# Remember when: more than a page of memories can be paged through.
	for i in 8:
		social.add_memory(pid, "A small thing, number %d." % i)
	current_scene.choose("remember")
	check(current_scene.has_reply("older") and current_scene.choose("older") and current_scene.has_reply("newer"),
		"older memories are a page further back")
	for cand in ["edda", "farid", "kaede"]:
		for key in Lines.OPENING_ORDER:
			var line := Lines.opening(cand, "courting", {key: "Brann" if key in ["fallen", "wounded"] else ("Marchgate" if key == "victory" else (23 if key == "away" else true))})
			check(line != Lines.greeting(cand, "courting") and not line.contains("{"), "%s has a line for %s (%s)" % [cand, key, line.left(40)])
	gs.world.hour = hour0

	# ---- "Remember when" knows what each thing was, and who it was with
	check(Lines.callback({"kind": "ceremony", "private": true, "candidate": "kaede"}) == Lines.PRIVATE_VOWS["kaede"]
		and Lines.callback({"kind": "ceremony", "candidate": "edda"}) == Lines.CEREMONIES["edda"], "vows by one candle and a wedding are told apart")
	check(Lines.callback({"kind": "dance", "dance": 2}, "farid") == Lines.DANCES["farid"][1], "each dance is remembered as itself")
	check(Lines.callback({"kind": "decision", "chapter": 4, "choice": "support_edda"}, "kaede") == Lines.CH4_CHOICES["kaede"]["support_edda"],
		"the council is remembered as what you said there, in her words")

	# ---- the fire: tempers on both sides, a few ways each
	for rank in ["C", "B", "A"]:
		var cells: Dictionary = gs.BOND_EXCHANGES[rank]
		check(cells.size() == 6 and cells.values().all(func(v): return (v as Array).size() >= 2), "rank %s has talks for every pair of tempers, two each" % rank)
	var fa: Dictionary = gs.army[0]["captain"]
	var fb: Dictionary = gs.army[1]["captain"]
	fa["temperament"] = "Fragile"
	fb["temperament"] = "Vengeful"
	var ex: Array = gs._bond_exchange(fa, fb, "C")
	check(String(ex[0]["who"]) == "b", "the vengeful one speaks first, whoever is listed first")
	# ---- a talk by the empty place
	gs.fallen.append({"id": 9990, "name": "Wynn of Holloway", "first": "Wynn", "battle": gs.battles, "words": "Keep the line, lads.",
		"temperament": "", "bonds": [], "bond_points": {str(int(fa["id"])): 13.0}, "type": "infantry"})
	check(gs.remembered_bonds().any(func(rb): return int(rb["b"]["id"]) == 9990), "a fallen friend is remembered as a bond")
	var mem: Dictionary = gs.bond_conversation(int(fa["id"]), 9990)
	check(bool(mem.get("memorial", false)) and " ".join(PackedStringArray(mem["passages"])).contains("Keep the line"), "and the survivor's talk remembers their last words")
	scenes.active_bond_a_id = int(fa["id"])
	scenes.active_bond_b_id = 9990
	scenes.bond_conversation_return = "res://scenes/main_menu.tscn"
	change_scene_to_file("res://scenes/bond_conversation.tscn")
	await _arrive("bond_conversation.tscn")
	check(current_scene._memorial and current_scene.log_text().contains("Keep the line") and current_scene.reply_ids() == ["back"],
		"told by the fire, with the fallen face greyed")
	gs.fallen = gs.fallen.filter(func(f): return int(f.get("id", 0)) != 9990)

	# ---- Farah and Kaede speak in their own words too
	for pair in [["farid", "qasr_hamra", "Farah"], ["kaede", "kitayama", "Kaede"]]:
		gs.world.player().node = String(pair[1])
		scenes.active_candidate_id = String(pair[0])
		change_scene_to_file("res://scenes/conversation.tscn")
		await _arrive("conversation.tscn")
		var t = current_scene
		var opener := String(t._replies.get_node("Reply_story").find_child("Text", true, false).text)
		check(t.has_reply("story") and not opener.contains("Chapter") and not opener.contains("Our story"), "%s's hub opens the story as a line you say (%s)" % [pair[2], opener])
		t.choose("story")
		t.choose("topic_work")
		var spoken: Array = t._log.find_children("Words", "Label", true, false).map(func(l): return String(l.text))
		check(not spoken.is_empty() and spoken.all(func(w): return not w.begins_with("'") and not w.contains(pair[2] + ": ")), "%s's words sit in her bubble without quotes or a name prefix" % pair[2])
		check(t.has_reply("decide_offer_help") and t.choose("decide_offer_help"), "and the first audience ends the same way")
		while t.telling():
			t.tell_rest()
		check(t._log.find_child("Reaction", true, false) != null and not t.log_text().contains("+10"), "%s's reaction is told in words" % pair[2])

	print("FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)
