## Letters with words in them: every letter reads properly, is kept with its words, can be
## answered once (with a preview), survives a save, and arrives on the map as a banner
## that never stops the clock. Also the People & Letters screens built around them.
extends SceneTree

const Cultures = preload("res://scripts/data/cultures.gd")
const Letters = preload("res://scripts/data/letters.gd")
const Relationships = preload("res://scripts/data/relationships.gd")

var failures := 0


func check(ok: bool, message: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + message)
	if not ok:
		failures += 1


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var gs = root.get_node("GameState")
	gs.persist = false
	_check_texts()
	gs.new_campaign(Cultures.VARDISH)
	_check_social(gs)
	await _check_screens(gs)
	await _check_banner(gs)
	print("Letters failures: %d" % failures)
	quit(failures)


func _check_texts() -> void:
	var complete := true
	var count := 0
	for key in Letters.LETTERS:
		for cand in ["edda", "farid", "kaede"]:
			for courting in [true, false]:
				var v := Letters.render(key, cand, courting, {"place": "Ravensford", "old": "Kitayama", "hour": 300.0})
				count += 1
				var text := "%s %s %s %s" % [v["subject"], v["salute"], " ".join(v["body"]), v["sign_title"]]
				complete = complete and v["subject"] != "" and not v["body"].is_empty() and not text.contains("{")
	check(complete and count == Letters.LETTERS.size() * 6, "all %d letters (%d kinds × 3 people × courting or friends) read in full" % [count, Letters.LETTERS.size()])
	var replies_ok := true
	for key in Letters.REPLIES:
		for r in Letters.replies(key):
			for courting in [true, false]:
				var v := Letters.render_reply(key, r["id"], courting, {"name": "Edda", "place": "Ravensford", "old": "Kitayama"})
				replies_ok = replies_ok and v["salute"] == "Edda," and not String(v["body"][0]).contains("{")
	check(replies_ok, "every reply reads in full, addressed by name")
	check(Letters.place_line("Ravensford", 13 * 24 + 21.0) == "Ravensford, the fourteenth day, by lamplight", "letters are dated in words, with the hour")


func _check_social(gs) -> void:
	var social = gs.world.social
	gs.world.hour = 26.0
	var r: Dictionary = gs.apply_social_choice("edda", "know_better")
	check(r["ok"], "courting Edda")
	check(social.letters.filter(func(l): return l["template_key"] == "ch2_invitation").is_empty() and social.pending_letters.size() == 1,
		"agreeing to court her: her invitation is written, and comes a day on")
	check(not gs.preview_social_choice("edda", "villager")["ok"], "the next chapter waits for it")
	gs.world.hour = 50.0
	social.step(0.0, gs.world)
	var mine: Array = social.letters.filter(func(l): return l["template_key"] == "ch2_invitation")
	check(mine.size() == 1 and social.pending_letters.is_empty() and gs.preview_social_choice("edda", "villager")["ok"], "a day on, the letter has come and the chapter is open")
	var l: Dictionary = mine[0]
	check(l["letter"]["subject"] == "A chair by the fire" and String(l["letter"]["place_line"]).begins_with("Ravensford"),
		"the letter's words are written when it arrives, as a courtship letter from Ravensford")
	var kp: Dictionary = social.get_candidate_person("kaede")
	var friend: Dictionary = social.add_letter(kp["id"], "ch2_invitation", "", 60.0, "kitayama")
	check(friend["letter"]["subject"] == "A record that needs witnesses", "someone you aren't courting writes as a friend")
	var moved: Dictionary = social.add_letter(kp["id"], "relocation", "", 70.0, "takamine", {"old": "Kitayama"})
	check(String(moved["letter"]["body"][0]).begins_with("Kitayama is lost"), "a move letter names the place they had to leave")
	# Letters from before letters had words get them when opened.
	var old := friend.duplicate(true)
	old.erase("letter")
	social.letters.append(old)
	check(not social.letter_view(old).is_empty() and old.has("letter"), "an old letter with no words is written out when read")
	social.letters.erase(old)
	# Arrivals are announced once.
	var fresh: Array = social.take_unannounced()
	check(fresh.size() == 3 and social.take_unannounced().is_empty(), "each new letter is announced once")
	# Answering.
	var preview: Dictionary = social.reply_preview(l["id"], "coming", "highcliff")
	check(preview["salute"] == "Edda," and String(preview["body"][0]).contains("Ravensford"), "a reply can be read before it's sent")
	var before := int(social.get_relationship("edda")["trust"])
	var sent: Dictionary = social.reply_letter(l["id"], "coming", "highcliff")
	check(sent["ok"] and int(social.get_relationship("edda")["trust"]) == before + 3 and l["read"], "sending a warm reply warms her a little and files the letter")
	check(not social.reply_letter(l["id"], "plain")["ok"], "a letter is answered once")
	var log: Array = social.get_person(l["sender_id"]).get("memory_log", [])
	check(not log.is_empty() and String(log.back()["text"]).contains("I'll come") and int(log.back()["day"]) == 3, "the reply is remembered, with its day")
	# Saved and loaded.
	var State = load("res://scripts/game_state.gd")
	var restored = State.new()
	restored.persist = false
	restored.from_dict(JSON.parse_string(JSON.stringify(gs.to_dict())))
	var back: Dictionary = restored.world.social.get_letter(l["id"])
	check(back["letter"]["subject"] == "A chair by the fire" and back["reply"]["id"] == "coming"
		and String(back["reply"]["letter"]["body"][0]).contains("Keep the chair"), "letters and replies survive a save")
	restored.free()


func _find(node: Node, name: String) -> Node:
	return node.find_child(name, true, false)


func _check_screens(gs) -> void:
	var social = gs.world.social
	var scenes = root.get_node("Scenes")
	gs.world.player().node = "highcliff"
	gs.world.player().next = ""
	gs.world.player().path = []
	change_scene_to_file("res://scenes/people.tscn")
	await process_frame
	await process_frame
	var s = current_scene
	check(_find(s, "Person_edda") != null and _find(s, "Ride_edda") != null and _find(s, "SpendTime_edda") != null,
		"Edda gets a card with a ride and a spend-time button")
	check(_find(s, "Person_farid") != null, "and someone not yet met still has a row")
	s._open_person("edda")
	await process_frame
	check(_find(s, "ProfileName") != null and _find(s, "Chapter2") != null and _find(s, "Chapter5") != null, "her page shows her story chapter by chapter")
	s._close_person()
	var kp: Dictionary = social.get_candidate_person("kaede")
	var unread: Dictionary = social.add_letter(kp["id"], "relocation", "", gs.world.hour, "takamine", {"old": "Kitayama"})
	scenes.people_letter = unread["id"]
	change_scene_to_file("res://scenes/people.tscn")
	await process_frame
	await process_frame
	s = current_scene
	check(_find(s, "Parchment") != null and unread["read"], "a letter opens straight from the map and is marked read")
	check(_find(s, "Reply_comfort") != null and _find(s, "RideFromLetter") != null, "with replies to choose and a ride to the sender")
	s._preview_reply("comfort")
	await process_frame
	check(_find(s, "ReplyParchment") != null and _find(s, "SendReply") != null, "choosing a reply shows your letter before it goes")
	s._send_reply()
	await process_frame
	check(unread.has("reply") and _find(s, "ReplyParchment") != null and _find(s, "Reply_comfort") == null, "sent, the reply stays with the letter")
	s._ride("takamine")
	check(gs.world.player().next != "" or not gs.world.player().path.is_empty(), "Ride sets the company off for the sender")
	await process_frame
	await process_frame


func _check_banner(gs) -> void:
	var social = gs.world.social
	social.take_unannounced()
	# Ride (above) heads back to the map; wait for it to open.
	for i in 120:
		await process_frame
		if current_scene != null and current_scene.scene_file_path.ends_with("world_map.tscn") and current_scene.letter_banner != null:
			break
	var m = current_scene
	check(m != null and m.scene_file_path.ends_with("world_map.tscn"), "riding off returns to the map")
	if m == null or not m.scene_file_path.ends_with("world_map.tscn"):
		return
	m._close_sheet()
	# A lord who stopped you on the way is sent on: letters wait while you talk.
	if m._talk != null:
		m._talk.choose("leave")
	gs.world.friendly_quiet_until = gs.world.hour + 1000.0
	var ep: Dictionary = social.get_candidate_person("edda")
	social.add_letter(ep["id"], "relocation", "", gs.world.hour, "highcliff", {"old": "Ravensford"})
	m.paused = false
	var hour: float = gs.world.hour
	for i in 30:
		await process_frame
	check(m.letter_banner.visible and m._banner_from.text.contains("Edda"), "a new letter shows a banner on the map")
	# (An encounter on the road may open its own sheet meanwhile; the letter never does.)
	check(gs.world.hour > hour and not m.paused and m._sheet != "letter", "and the clock keeps running")
	check(m.unread_badge.visible, "the menu button counts unread letters")
