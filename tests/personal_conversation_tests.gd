## Optional dialogue state, side-effect isolation, migration, and real menu interactions.
extends SceneTree
const WorldSim = preload("res://scripts/world/world_sim.gd")
const SocialSim = preload("res://scripts/world/social_sim.gd")
const Cultures = preload("res://scripts/data/cultures.gd")
const Stories = preload("res://scripts/data/personal_conversations.gd")
const Relationships = preload("res://scripts/data/relationships.gd")
const Lines = preload("res://scripts/data/romance_talk_lines.gd")
const Letters = preload("res://scripts/data/letters.gd")
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

## Plays a visit through: `picks` are the answers wanted, a part each; where none is given
## (or it isn't on offer on this route) the first one offered is taken.
func finish(social, id: String, picks: Array = []) -> Dictionary:
	social._hour += 24.0 # a new visit is one a day
	var progress: Dictionary = social.personal_action(PERSON, id, "begin", ctx).get("progress", {})
	answer_all(social, id, progress, picks)
	return social.personal_action(PERSON, id, "finish", ctx)


func answer_all(social, id: String, progress: Dictionary, picks: Array = []) -> void:
	for part in range(int(progress.get("part", 0)), Stories.part_count(id)):
		var want := int(picks[part]) if part < picks.size() else -1
		if not Stories.offers(id, part, progress["context"], want):
			want = int(Stories.options(id, part, progress["context"])[0]["index"])
		social.personal_action(PERSON, id, "choose", ctx, want)

func _run() -> void:
	var gs = root.get_node("GameState")
	gs.persist = false
	var w = fresh()
	var soc = w.social
	check(not soc.personal_scene_access(PERSON, FIRST, ctx)["ok"], "introduction is required")
	check(not soc.personal_scene_access("person_farid", FIRST, ctx)["ok"], "candidates cannot access another person's scenes")
	check(Stories.ids_for("edda").size() == 8 and Stories.ids_for("farid").size() == 8 and Stories.ids_for("kaede").size() == 8,
		"Edda, Farah and Kaede each have eight visits")
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
	var answered: Dictionary = soc.personal_action(PERSON, FIRST, "choose", ctx, 1)
	check(answered["progress"]["part"] == 1 and answered["progress"]["picks"] == [1] and answered["progress"]["beat"] == 1,
		"an answer moves on to the next part, at her first words back")
	check(not soc.personal_action(PERSON, FIRST, "finish", ctx)["ok"], "cannot finish with points still unanswered")
	var loaded := WorldSim.new()
	loaded.from_dict(JSON.parse_string(JSON.stringify(w.to_dict())))
	var resumed: Dictionary = loaded.social.personal_action(PERSON, FIRST, "begin", ctx)
	check(resumed["progress"]["part"] == 1 and resumed["progress"]["picks"] == [1], "JSON round trip resumes at the exact part, with the answer given")
	answer_all(loaded.social, FIRST, resumed["progress"])
	baseline = loaded.to_dict().duplicate(true)
	var reward: Dictionary = loaded.social.personal_action(PERSON, FIRST, "finish", ctx)
	check(reward["trust_change"] == 1, "completion awards one trust")
	var after: Dictionary = loaded.to_dict().duplicate(true)
	# Strip precisely the permitted effects; every other world field must match.
	after["social"]["personal_conversations"] = baseline["social"]["personal_conversations"]
	after["social"]["relationships"]["edda"]["trust"] = baseline["social"]["relationships"]["edda"]["trust"]
	after["social"]["relationships"]["edda"]["memories"] = baseline["social"]["relationships"]["edda"]["memories"]
	after["social"]["people"][PERSON]["memories"] = baseline["social"]["people"][PERSON]["memories"]
	# The same memory, dated, for the person's page.
	if baseline["social"]["people"][PERSON].has("memory_log"):
		after["social"]["people"][PERSON]["memory_log"] = baseline["social"]["people"][PERSON]["memory_log"]
	else:
		after["social"]["people"][PERSON].erase("memory_log")
	check(after == baseline, "all world, quest, pact, house, army, timer and RNG state unchanged")
	soc = loaded.social
	var saved: Dictionary = soc.to_dict().duplicate(true)
	check(not soc.personal_action(PERSON, FIRST, "finish", ctx)["ok"], "duplicate completion rejected")
	check(not soc.personal_action(PERSON, FIRST, "choose", ctx, 0)["ok"], "replay cannot overwrite campaign choices")
	check(saved == soc.to_dict(), "duplicate requests leave all social state unchanged")
	check(soc.personal_scene_access(PERSON, FIRST, {})["replay"], "archive accessible remotely")
	check(soc.personal_scene_access(PERSON, "edda_boots_by_door", ctx).get("today", false), "the same day, a new visit waits for tomorrow")
	soc._hour += 24.0
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
	check(not soc.personal_scene_access(PERSON, "edda_who_set_your_place", ctx)["ok"], "the last two wait for the sixth")
	check(finish(soc, "edda_place_no_task")["ok"], "friendship unlocks coda")
	check(finish(soc, "edda_who_set_your_place")["ok"] and finish(soc, "edda_home_on_time")["ok"], "and then the two S-rank visits, in order")
	check(soc.personal_record(PERSON)["completed"].size() == 8 and soc.relationships["edda"]["trust"] == 13, "all eight scenes complete without exceeding cap")
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
	_check_intent_later_and_parting()
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
		check(finish(soc, FIRST, [0, 0, choice])["trust_change"] == 1, "answer %d has the same reward" % choice)
	w = fresh()
	soc = w.social
	soc.apply_choice("edda", "know_better", {"invitations_enabled": true})
	soc.personal_action(PERSON, FIRST, "begin", {"settlement_id": "ravensford", "invitations_enabled": false})
	check(soc.personal_action(PERSON, FIRST, "summary", ctx)["trust_change"] == 1, "summary receives equal reward")
	check(soc.personal_record(PERSON)["cosmetic_choices"][FIRST] == -1, "summary saves neutral choice")
	check(not soc.personal_record(PERSON)["completed"][FIRST]["context"]["romantic"], "invitations off gives neutral context")
	check(soc.relationships["edda"]["romantic_intent"], "neutral visit does not erase existing romance")
	_check_content()
	_check_remembering()


func _text(lines: Array) -> String:
	return "\n".join(lines.map(func(b): return String(b["text"])))


## The scenes themselves: eight a person in ranks; two or three things to say at every
## point on either route; never more than six lines before you speak; and everything you
## say that is remembered is brought up again somewhere.
func _check_content() -> void:
	var set_by := {}
	var read := {}
	for id in Stories.SCENES:
		var scene: Dictionary = Stories.SCENES[id]
		var texts: Array = [scene["closing"]]
		for part in scene["parts"]:
			texts.append(part["text"])
			for o in part["options"]:
				texts.append(o.get("reply", ""))
				if o.has("mark"):
					set_by[String(o["mark"])] = id
				check(Stories.TONES.has(String(o.get("tone", ""))), "%s: '%s' says what kind of thing it is" % [id, o["say"]])
		var conditional := false
		for t in texts:
			var from := 0
			while String(t).find("[?", from) >= 0:
				var a := String(t).find("[?", from)
				var b := String(t).find("]", a)
				for c in String(t).substr(a + 2, b - a - 2).split(","):
					read[c.strip_edges().trim_prefix("!")] = true
				conditional = true
				from = b
		var order: int = Stories.ids_for(String(id).split("_")[0]).find(id)
		check(order < 2 or conditional, "%s remembers something from before" % id)
		check(String(scene["rank"]) == ["C", "C", "B", "B", "A", "A", "S", "S"][order], "%s is rank %s" % [id, scene["rank"]])
		check(scene.has("summary") and scene.has("memory") and scene["parts"].size() >= 2, "%s has its short version, its memory and at least two points" % id)
		var hearts := 0
		for romantic in [true, false]:
			var c := {"romantic": romantic, "completed": [], "choices": {}}
			var paths: Array = [[]]
			for part in scene["parts"].size():
				var offered := Stories.options(id, part, c)
				check(offered.size() >= 2 and offered.size() <= 3, "%s point %d offers two or three things to say (%s: %d)" % [id, part, "romance" if romantic else "friendship", offered.size()])
				var next: Array = []
				for path in paths:
					for o in offered:
						next.append(path + [int(o["index"])])
						hearts += 1 if String(o.get("tone", "")) == "heart" else 0
				paths = next
			var longest := 0
			var words_min := 100000
			var words_max := 0
			for path in paths:
				var words := 0
				for part in scene["parts"].size() + 1:
					var seq := Stories.beats(id, part, path, c)
					if part < scene["parts"].size():
						longest = maxi(longest, seq.size() - (1 if part > 0 else 0))
					for b in seq:
						words += String(b["text"]).split(" ", false).size()
				words_min = mini(words_min, words)
				words_max = maxi(words_max, words)
			check(longest <= 6, "%s never runs more than six lines before you speak (%d)" % [id, longest])
			check(words_min >= 200 and words_max <= 520, "%s is a short scene on every path (%d to %d words)" % [id, words_min, words_max])
		check(order < 2 or hearts > 0, "%s has something to say from the heart, on a romantic route" % id)
	for m in set_by:
		check(read.has(m), "what you said is remembered somewhere: %s (%s)" % [m, set_by[m]])
	for r in read:
		check(set_by.has(r) or Stories.SCENES.has(r) or r in ["romantic", "friend"], "a remembered line asks about something real: %s" % r)


## What you say stays said: later visits, her greetings and her letters bring it up; the
## memory book says what you did; an older save's visits still read right.
func _check_remembering() -> void:
	var w = fresh()
	var soc = w.social
	soc.apply_choice("edda", "know_better", {"invitations_enabled": true})
	check(soc.personal_marks(PERSON).is_empty(), "nothing is remembered before you've said anything")
	var plain: Dictionary = soc.personal_action(PERSON, "edda_wrong_verse", "begin", ctx)["progress"]
	check(not _text(Stories.beats("edda_wrong_verse", 0, [], plain["context"])).contains("You've eaten today"), "a visit doesn't bring up what never happened")
	soc.personal_action(PERSON, "edda_wrong_verse", "summary", ctx)
	finish(soc, FIRST, [0, 0, 2])
	check(soc.personal_record(PERSON)["cosmetic_choices"][FIRST] == [0, 0, 2], "a finished visit keeps the answer you gave at each point")
	check(soc.personal_marks(PERSON).has("edda_fed") and soc.personal_marks(PERSON).has("edda_noticed_place"), "and what those answers left behind")
	check(String(soc.memory_book(PERSON).back()["text"]).contains("no place for herself"), "the memory book says what you did (%s)" % soc.memory_book(PERSON).back()["text"])
	soc._hour += 24.0
	var boots: Dictionary = soc.personal_action(PERSON, "edda_boots_by_door", "begin", ctx)["progress"]
	check(_text(Stories.beats("edda_boots_by_door", 0, [], boots["context"])).contains("haven't counted myself"), "a later visit brings up what you did in an earlier one")
	var offered: Array = Stories.options("edda_boots_by_door", 2, boots["context"]).map(func(o): return String(o["tone"]))
	check(offered.has("heart") and not offered.has("warm"), "courting, the last answer can be from the heart (%s)" % ", ".join(offered))
	var friendly: Dictionary = boots["context"].duplicate(true)
	friendly["romantic"] = false
	offered = Stories.options("edda_boots_by_door", 2, friendly).map(func(o): return String(o["tone"]))
	check(offered.has("warm") and not offered.has("heart"), "as friends, a friend's (%s)" % ", ".join(offered))
	check(not soc.personal_action(PERSON, "edda_boots_by_door", "choose", ctx, 0)["progress"].is_empty()
		and not soc.personal_action(PERSON, "edda_boots_by_door", "choose", ctx, 0)["progress"].is_empty()
		and not soc.personal_action(PERSON, "edda_boots_by_door", "choose", ctx, 3)["ok"], "an answer for the other route isn't accepted")
	# Something said in the scene itself shows up later in the same scene.
	var c := {"romantic": false, "completed": [], "choices": {}}
	check(_text(Stories.beats("farid_own_answer", 3, [1, 0, 0], c)).contains("crooked stitch") and not _text(Stories.beats("farid_own_answer", 3, [0, 0, 0], c)).contains("crooked stitch"),
		"what you do in a visit is there at its end")
	# Her greeting and her letters.
	check(Lines.remembered("edda", soc.personal_marks(PERSON), 2) == Lines.REMEMBERED["edda"]["edda_fed"] and Lines.remembered("edda", soc.personal_marks(PERSON), 1) == "",
		"now and then she greets you with something you said")
	check(Lines.opening("edda", "courting", {"fallen": "Brann"}, 2, soc.personal_marks(PERSON)).contains("Brann"), "though what has happened since comes first")
	var letter: Dictionary = Letters.render("no_such_letter", "edda", true, {"sender": "Edda", "marks": soc.personal_marks(PERSON)})
	check(String(letter["ps"]) == Letters.REMEMBERED_PS["edda_fed"], "and a letter with no postscript of its own carries one (%s)" % letter["ps"])
	# An older save: one passage, one answer. It keeps its place and leaves no marks.
	var old: Dictionary = JSON.parse_string(JSON.stringify(w.to_dict()))
	old["social"]["personal_conversations"][PERSON]["cosmetic_choices"][FIRST] = 1
	old["social"]["personal_conversations"][PERSON]["cosmetic_choices"].erase("edda_wrong_verse")
	old["social"]["personal_conversations"][PERSON]["completed"][FIRST]["content_version"] = 1
	old["social"]["personal_conversations"][PERSON]["in_progress"]["edda_boots_by_door"] = {"scene_id": "edda_boots_by_door", "node": 1, "choice": 2,
		"content_version": 1, "context": {"completed": [FIRST], "choices": {FIRST: 1}, "status": "courting", "romantic": true}}
	var older := WorldSim.new()
	older.from_dict(old)
	check(older.social.personal_marks(PERSON).is_empty() and older.social.personal_scene_access(PERSON, FIRST, {})["replay"], "an older save's visit is still a memory, with no marks")
	check(Stories.kept_picks(FIRST, 1) == [-1, -1, -1] and Stories.kept_picks(FIRST, [0, 0, 1]) == [0, 0, 1], "told again, an older visit asks; a new one answers as you did")
	var again: Dictionary = older.social.personal_action(PERSON, "edda_boots_by_door", "begin", ctx)
	check(again["ok"] and again["progress"]["part"] == 0 and again["progress"]["picks"] == [] and not again["progress"].has("node"), "a visit left part way in an older save starts again")


func _check_progress_and_gates() -> void:
	var w = fresh()
	var soc = w.social
	soc.apply_choice("edda", "know_better", {"invitations_enabled": true})
	soc.personal_action(PERSON, FIRST, "begin", ctx)
	soc.personal_action(PERSON, FIRST, "choose", ctx, 1)
	check(not soc.personal_action(PERSON, "edda_wrong_verse", "begin", ctx)["ok"] and soc.personal_scene_access(PERSON, "edda_wrong_verse", ctx).get("today", false),
		"one new visit a day: a second the same day waits")
	soc._hour += 24.0
	soc.personal_action(PERSON, "edda_wrong_verse", "begin", ctx)
	check(soc.personal_action(PERSON, FIRST, "begin", ctx)["progress"]["picks"] == [1], "starting another story preserves unfinished visits")
	var neutral: Dictionary = soc.personal_action(PERSON, FIRST, "begin", {"settlement_id": "ravensford", "invitations_enabled": false})
	check(not neutral["progress"]["context"]["romantic"], "resuming after disabling invitations uses neutral presentation")
	check(neutral["progress"]["part"] == 0 and neutral["progress"]["picks"] == [], "and, the route having changed, from the start")
	soc.relationships["edda"]["trust"] = 57
	for id in [FIRST, "edda_wrong_verse", "edda_boots_by_door"]:
		soc._hour += 24.0
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

## "We'll speak another time" is not final: you've met, and what you mean to be to each
## other can be said at any later chapter. Parting ends new visits, in her words.
func _check_intent_later_and_parting() -> void:
	var w = fresh()
	var soc = w.social
	soc.apply_choice("edda", "another_time", {})
	var rel: Dictionary = soc.relationships["edda"]
	check(rel["status"] == Relationships.ACQUAINTED and not bool(rel["intent_chosen"]), "nothing decided yet: met, not a stranger")
	check(soc.get_quest("quest_edda")["chapter"] == 2 and soc.intent_open("edda"), "the story goes on, and the question stays open")
	var later: Dictionary = soc.preview_choice("edda", "know_better", {"invitations_enabled": true})
	check(later["ok"] and later["new_status"] == Relationships.COURTING and int(later["trust_change"]) == 0,
		"at a later chapter you can still ask to court her (the first audience's trust given once)")
	check(not soc.preview_choice("edda", "another_time", {})["ok"], "and it can't be put off a second time")
	check(soc.apply_choice("edda", "know_better", {"invitations_enabled": true})["ok"] and rel["status"] == Relationships.COURTING
		and bool(rel["romantic_intent"]) and soc.get_quest("quest_edda")["chapter"] == 2 and not soc.intent_open("edda"),
		"courting now, and the story stays at the chapter it reached")
	w = fresh()
	soc = w.social
	soc.apply_choice("edda", "another_time", {})
	soc.quests["quest_edda"]["chapter"] = 5
	soc.relationships["edda"]["status"] = Relationships.COMMITTED
	check(soc.apply_choice("edda", "offer_help", {})["ok"] and soc.relationships["edda"]["status"] == Relationships.COMMITTED,
		"said late, a friendship keeps how close you already are")
	# Parted: no new time together, said in her voice; what you shared can still be told.
	w = fresh()
	soc = w.social
	soc.apply_choice("edda", "offer_help", {})
	soc._hour += 24.0
	finish(soc, FIRST)
	soc.separate("edda")
	soc._hour += 24.0
	var refused: Dictionary = soc.personal_scene_access(PERSON, "edda_wrong_verse", ctx)
	check(not refused["ok"] and String(refused["reason"]).contains("chair"), "parted, she won't start a new visit, and says why (%s)" % refused["reason"])
	check(soc.personal_scene_access(PERSON, FIRST, {})["replay"], "a visit you shared can still be told again")


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
	check(button("Spend time") != null, "People exposes personal conversations")
	change_scene_to_file("res://scenes/conversation.tscn")
	await process_frame
	await process_frame
	var talk = current_scene
	check(talk.has_reply("visit_edda_spare_spoon"), "the talk offers time together")
	check(talk.reply_ids().filter(func(id): return String(id).begins_with("visit_")).size() <= 3, "a few at a time, not a list of every visit")
	change_scene_to_file("res://scenes/personal_conversation.tscn")
	await process_frame
	await process_frame
	talk = current_scene
	check(talk.has_reply("visit_edda_spare_spoon"), "personal library loads")
	var before: Dictionary = gs.to_dict().duplicate(true)
	talk.choose("visit_edda_spare_spoon")
	check(talk.has_reply("summary"), "reader offers accessible summary")
	_read_to_end(talk)
	check(talk.log_text().contains("No wrong answers"), "chat replies say there are no wrong answers")
	var first_point: Array = talk.reply_ids().filter(func(id): return String(id).begins_with("say_"))
	check(first_point == ["say_0", "say_1"] and talk.has_reply("summary"), "the first point comes early: how you join in, two ways (%s)" % ", ".join(first_point))
	var kind := talk._replies.get_node("Reply_say_0").find_child("Tag", true, false) as Label
	check(kind != null and kind.text == Stories.TONES["share"][1] and talk._replies.get_node("Reply_say_0").find_child("Kind", true, false) != null,
		"each thing you could say shows what kind of thing it is")
	talk.choose("say_1")
	check(talk.log_text().contains("Is this an inspection") and talk.log_text().contains("You're failing it") and not talk.has_reply("summary"),
		"she answers what you said, and the short version is no longer offered")
	talk.choose("later")
	check(talk.has_reply("visit_edda_spare_spoon") and String(talk._replies.get_node("Reply_visit_edda_spare_spoon").find_child("Tag", true, false).text).begins_with("resume"),
		"leaving preserves response for resume")
	talk.choose("visit_edda_spare_spoon")
	check(talk.log_text().contains("You're failing it"), "resume returns to where you were, with what was said")
	_read_to_end(talk)
	check(talk.reply_ids().filter(func(id): return String(id).begins_with("say_")).size() == 2, "then a second point: a reaction")
	talk.choose("say_0")
	_read_to_end(talk)
	check(talk.reply_ids().filter(func(id): return String(id).begins_with("say_")).size() == 3, "and last the answer that matters most, three ways")
	talk.choose("say_2")
	_read_to_end(talk)
	check(talk.has_reply("finish"), "after the last answer, the closing")
	talk.choose("finish")
	check(talk.log_text().contains("no place for herself"), "the memory kept says what you did")
	check(talk._log.find_child("Keepsake", true, false) != null, "a kept memory says so")
	check(gs.silver == before["silver"] and gs.food == before["food"] and gs.renown == before["renown"] and gs.army == before["army"], "UI visit preserves player resources and army")
	talk.choose("back")
	check(talk.has_reply("remember"), "shared memories can be brought up")
	var archived: Dictionary = gs.to_dict().duplicate(true)
	talk.choose("remember")
	var mem_ids: Array = talk.reply_ids().filter(func(id): return String(id).begins_with("memory_"))
	check(not mem_ids.is_empty(), "remembering lists your memories")
	var spoon := ""
	for id in mem_ids:
		if String(talk._replies.get_node("Reply_" + id).find_child("Text", true, false).text).contains("inspected"):
			spoon = id
	talk.choose(spoon)
	check(talk.log_text().contains("famine"), "and they answer with what they remember")
	talk.choose("relive")
	_read_to_end(talk)
	check(talk.has_reply("finish") and talk.log_text().contains("Is this an inspection") and talk.log_text().contains("You haven't eaten either.")
		and not talk.log_text().contains("No wrong answers"), "told again, a visit goes as you answered it, start to finish, and asks nothing")
	talk.choose("finish")
	check(archived == gs.to_dict(), "replay through real UI changes no campaign data")
	check(not talk.has_reply("visit_edda_wrong_verse") and talk.has_reply("visits_locked", false), "the day's visit is spent; the talk says so")
	gs.world.hour += 24.0
	talk._hub()
	talk.choose("visit_edda_wrong_verse")
	talk.choose("summary")
	check(gs.world.social.personal_record(PERSON)["completed"].size() == 2, "summary completes through real UI")


func _read_to_end(talk) -> void:
	for i in 60:
		if not talk.has_reply("continue"):
			return
		talk.choose("continue")
	check(false, "reader reaches the end in bounded steps")
