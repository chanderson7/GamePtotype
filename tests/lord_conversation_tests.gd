## Talking to lords: Regard, stories that teach what they like, their troubles as journal
## jobs, winning them to your crown (arguments, silver, swearing with their lands, a lord
## bought who leaves again), refusals, challenges, single combat, tribute, captives, the
## talk saved with the lord, the conversation screen and the Lords tab in People.
extends SceneTree

const Data = preload("res://scripts/world/world_data.gd")
const WorldSim = preload("res://scripts/world/world_sim.gd")
const Lords = preload("res://scripts/data/lords.gd")
const LordTalk = preload("res://scripts/world/lord_talk.gd")
const LordVoice = preload("res://scripts/data/lord_voice.gd")
const LordLines = preload("res://scripts/data/lord_lines.gd")

var failures := 0


func check(ok: bool, message: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + message)
	if not ok:
		failures += 1


## A field lord of `realm` (not its ruler) holding a castle, if one does.
func _field_lord(w, realm: String, with_fief: bool = true) -> Dictionary:
	for l in w.lords:
		if l["realm"] == realm and not l["ruler"] and l["state"] == "field" and int(l.get("party", -1)) >= 0 \
				and (not with_fief or String(l["fief"]) != ""):
			return l
	return {}


func _init() -> void:
	await process_frame
	# Loaded after the autoloads it uses are up.
	var LordConversation = load("res://scripts/world/lord_conversation.gd")
	var gs = root.get_node("GameState")
	gs.persist = false
	gs.new_campaign("vardish")
	var w = gs.world
	var home: String = Data.realm_of_culture("vardish")
	var cato := _field_lord(w, home)
	check(not cato.is_empty(), "a landed lord of your realm rides the roads")

	# ---- Regard
	var base := LordTalk.regard(gs, cato)
	gs.add_lord_relation(int(cato["id"]), 12)
	check(LordTalk.regard(gs, cato) == base + 12, "Regard rises with what you do for them (%d to %d)" % [base, LordTalk.regard(gs, cato)])
	check(LordTalk.standing(-60) == "Hostile" and LordTalk.standing(-35) == "Bitter" and LordTalk.standing(6) == "Civil" \
		and LordTalk.standing(12) == "Friendly" and LordTalk.standing(31) == "Warm", "and reads in words")

	# ---- stories teach what they like
	cato["bearing"] = Lords.CAUTIOUS
	var before := LordTalk.regard(gs, cato)
	var told := LordTalk.tell_story(gs, cato, "tale_prudence")
	check(bool(told["ok"]) and int(told["regard"]) == LordTalk.STORY_LIKED and LordTalk.regard(gs, cato) == before + LordTalk.STORY_LIKED,
		"a Cautious lord likes a story of prudence (+%d)" % LordTalk.STORY_LIKED)
	check(LordTalk.like_known(cato) and String(told["learned"]).contains("prudence"), "and you learn they value it")
	check(not LordTalk.stories(gs, cato).any(func(s): return s["id"] == "tale_prudence"), "each story is told to each lord once")
	var bold := LordTalk.tell_story(gs, cato, "tale_boldness")
	check(int(bold["regard"]) == LordTalk.STORY_DISLIKED and LordTalk.dislike_known(cato), "a tale of daring sours them a little, and teaches that too")
	w.emit_event({"type": "battle_fought", "at": "ravensford", "won": true, "killed": 40, "lost": 6})
	check(LordTalk.stories(gs, cato).any(func(s): return String(s["id"]).begins_with("log_battle_fought")), "your own chronicle gives you stories to tell")

	# ---- troubles become a journal job
	var band = w.bands()[0]
	band.node = w.seat_of(cato)
	band.next = ""
	band.along = 0.0
	var tr := LordTalk.trouble(gs, cato)
	check(String(tr["kind"]) == "bandits" and int(tr["band"]) == band.id, "a lord with brigands on their lands wants them gone")
	var silver := LordTalk.haggle(gs, cato)
	check(silver == LordTalk.haggle_silver(cato) and LordTalk.haggle_cost(cato) == LordTalk.HAGGLE_REGARD, "haggling gets silver, and costs Regard with a Cautious lord")
	var job := LordTalk.take_trouble(gs, cato, silver)
	check(not job.is_empty() and gs.active_jobs.has(job) and int(job["for_lord"]) == int(cato["id"]), "taking it puts a job in your journal")
	check(String(LordTalk.trouble(gs, cato)["kind"]) == "job", "and they remind you of it until it's done")
	var r0 := LordTalk.regard(gs, cato)
	var s0: int = gs.silver
	job["status"] = "ready_to_claim"
	gs.complete_job(String(job["id"]))
	check(LordTalk.regard(gs, cato) == r0 + LordTalk.JOB_REGARD and gs.silver == s0 + silver, "done, it pays Regard (+%d) and the silver agreed" % LordTalk.JOB_REGARD)
	check(int(LordTalk.record(cato)["jobs_done"]) == 1 and String(LordTalk.record(cato)["job"]) == "", "and counts as a job done for them")
	# It's told on a card of its own, not a line of text: who it was for, their thanks, the pay.
	var overlay = root.get_node("Scenes")
	var card: Dictionary = {}
	for r in overlay.ribbons:
		if bool(r.get("contract", false)):
			card = r
	check(not card.is_empty() and String(card["title"]) == String(job["title"]) and card.get("lord") == cato
		and int(card["regard"]) == LordTalk.JOB_REGARD and int(card["silver"]) == silver and String(card["thanks"]).contains(String(cato["name"]))
		and not gs.map_notice.contains("Completed:"),
		"a contract done comes up on its own card: its name, the lord's face and thanks, and what it paid")
	overlay.ribbons = overlay.ribbons.filter(func(r): return not bool(r.get("contract", false)))

	# ---- before a crown, the crown lines are locked
	check(not LordTalk.persuade_check(gs, cato)["ok"] and String(LordTalk.persuade_check(gs, cato)["reason"]).contains("banner"),
		"before you raise a banner, you can't talk of crowns")

	# ---- raise a crown (at a village far from Cato's lands) and make the case
	var seat := ""
	for id in Data.SETTLEMENTS:
		if Data.settlement(id)["type"] == Data.VILLAGE and w.owner_of(id) == "ryumon":
			seat = id
			break
	w.declare_crown(seat)
	check(gs.is_crowned(), "your company has a crown")
	var ruler: Dictionary = {}
	for l in w.lords:
		if l["realm"] == home and l["ruler"]:
			ruler = l
	check(String(LordTalk.persuade_check(gs, ruler)["reason"]).contains("rulers"), "rulers never change sides")
	check(LordTalk.persuade_check(gs, cato)["ok"], "a lord of a realm at peace with you will hear you out")
	var c0 := LordTalk.conviction(gs, cato)
	var args := LordTalk.arguments(gs, cato)
	var liked: Dictionary = args.filter(func(a): return a["theme"] == LordTalk.PRUDENCE)[0]
	check(String(liked["tag"]).contains("+%d" % LordTalk.ARGUMENT_LIKED), "an argument they like says so, once you know it")
	var ar := LordTalk.argue(gs, cato, String(liked["id"]))
	check(int(ar["points"]) == LordTalk.ARGUMENT_LIKED and LordTalk.conviction(gs, cato) == c0 + LordTalk.ARGUMENT_LIKED, "and moves them %d" % LordTalk.ARGUMENT_LIKED)
	check(not LordTalk.arguments(gs, cato).any(func(a): return a["id"] == liked["id"]), "each argument is made once")
	gs.silver = 5000
	var paid := LordTalk.offer_silver(gs, cato, 500)
	check(bool(paid["ok"]) and int(paid["points"]) == 10 and gs.silver == 4500, "silver counts toward their change of sides (500 for +10)")
	gs.add_lord_relation(int(cato["id"]), 100)
	LordTalk.offer_silver(gs, cato, 1000)
	var fief := String(cato["fief"])
	var villages := []
	for v in Data.SETTLEMENTS:
		if String(Data.SETTLEMENTS[v].get("bound_to", "")) == fief:
			villages.append(v)
	check(LordTalk.conviction(gs, cato) >= LordTalk.CONVINCED, "with their Regard high, a job done and a fair purse, they're convinced (%d)" % LordTalk.conviction(gs, cato))
	var sworn := LordTalk.swear(gs, cato)
	check(bool(sworn["ok"]) and cato["realm"] == Data.CROWN and w.party(int(cato["party"])).faction == Data.CROWN, "convinced, they swear to your crown")
	check(w.owner_of(fief) == Data.CROWN and villages.all(func(v): return w.owner_of(v) == Data.CROWN), "and their castle and its villages join your realm")
	check(not bool(sworn["bought"]) and int(cato.get("bought", 0)) == 0, "won in good faith: silver was under half the case")
	check(gs.relation_with_realm(home) <= -30, "their old realm thinks worse of your crown")

	# ---- a lord bought with silver leaves when they come to dislike you
	var emir := _field_lord(w, "kharzan")
	check(not emir.is_empty(), "an emir rides the roads")
	emir["bearing"] = Lords.DARING
	gs.silver = 9000
	for amount in [1800, 1800, 1800]:
		LordTalk.offer_silver(gs, emir, amount)
	var bought := LordTalk.swear(gs, emir)
	check(bool(bought["ok"]) and bool(bought["bought"]), "a lord won mostly with silver is bought")
	var emir_fief := String(emir["fief"])
	gs.add_lord_relation(int(emir["id"]), -200)
	var gone := LordTalk.bought_lords_day(gs)
	check(gone.has(String(emir["name"])) and emir["realm"] == "kharzan" and w.owner_of(emir_fief) == "kharzan",
		"and leaves, castle and all, once they think badly of you")
	check(not LordTalk.bought_lords_day(gs).has(String(cato["name"])), "a lord sworn in good faith stays")

	# ---- arguments they dislike, twice, and they refuse you for a week
	var daimyo := _field_lord(w, "ryumon", false)
	daimyo["bearing"] = Lords.HONORABLE
	gs.add_lord_relation(int(daimyo["id"]), 40)
	var reg0 := LordTalk.regard(gs, daimyo)
	LordTalk.argue(gs, daimyo, "fear")
	var r2 := LordTalk.argue(gs, daimyo, "fear")
	check(not bool(r2.get("ok", false)), "an argument already made can't be made again")
	gs.add_lord_relation(int(daimyo["id"]), 0)
	LordTalk.record(daimyo)["bristle"] = LordTalk.BRISTLE_LIMIT - 1
	LordTalk.record(daimyo)["args"] = []
	var refused := LordTalk.argue(gs, daimyo, "fear")
	check(bool(refused["refused"]) and not LordTalk.persuade_check(gs, daimyo)["ok"], "push what they dislike and they refuse you")
	check(LordTalk.regard(gs, daimyo) <= reg0 + LordTalk.REFUSAL_REGARD and String(LordTalk.persuade_check(gs, daimyo)["reason"]).contains("days"),
		"at a cost in Regard, and a week's wait")

	# ---- steel: challenges, single combat, tribute
	var other := _field_lord(w, "kharzan", false)
	if other == emir:
		for l in w.lords:
			if l["realm"] == "kharzan" and not l["ruler"] and l != emir and int(l.get("party", -1)) >= 0:
				other = l
				break
	var ch := LordTalk.challenge_check(gs, other)
	check(bool(ch["ok"]) and bool(ch["war"]) == (w.relation_to_player("kharzan") != "hostile"), "a challenge to a lord at peace with you means war")
	check(not LordTalk.challenge_check(gs, cato)["ok"], "you don't challenge your own sworn lords")
	var champs := LordTalk.champions(gs)
	check(not champs.is_empty() and champs.size() <= 3, "up to three captains can stand as champion")
	var cap: Dictionary = champs[0]["captain"]
	var ren0: int = gs.renown
	var reg1 := LordTalk.regard(gs, other)
	var duel := LordTalk.duel(gs, other, int(champs[0]["squad"]))
	if bool(duel["won"]):
		check(gs.renown == ren0 + LordTalk.DUEL_RENOWN and LordTalk.regard(gs, other) == reg1 + LordTalk.duel_win_regard(other), "single combat won: renown and Regard")
	else:
		check(int(cap["wounded"]) == 2 and LordTalk.regard(gs, other) == reg1 + LordTalk.DUEL_LOSE_REGARD, "single combat lost: your champion is wounded")
	check(not LordTalk.duel_check(gs, other)["ok"], "and not again for a few days")
	other["bearing"] = Lords.CRUEL
	w.declare_war(Data.CROWN, "kharzan", true)
	check(w.relation_to_player("kharzan") == "hostile", "at war with Kharzan")
	gs.silver = 1000
	check(LordTalk.pay_tribute(gs, other) and gs.silver == 1000 - LordTalk.TRIBUTE and w.party(int(other["party"])).grace_until > w.hour,
		"a Cruel lord takes tribute and lets you pass")

	# ---- captives
	var captive := _field_lord(w, "ryumon", false)
	captive["bearing"] = Lords.HONORABLE
	w.capture_lord(int(captive["id"]), "player")
	check(not gs.swear_check(int(captive["id"]))["ok"], "an Honorable captive won't swear")
	var honorable: Array = w.lords.filter(func(l): return l != captive and l["bearing"] == Lords.HONORABLE)
	var watched: Dictionary = honorable[0] if not honorable.is_empty() else {}
	var hw0 := LordTalk.regard(gs, watched) if not watched.is_empty() else 0
	var cr0 := LordTalk.regard(gs, captive)
	LordTalk.keep_in_chains(gs, captive)
	check(LordTalk.regard(gs, captive) == cr0 + LordTalk.CHAINS_REGARD, "kept in chains, they resent it")
	check(watched.is_empty() or LordTalk.regard(gs, watched) == hw0 + LordTalk.CHAINS_HONORABLE, "and Honorable lords hear of it")

	# ---- the talk is saved with the lord
	var saved: Dictionary = JSON.parse_string(JSON.stringify(w.to_dict(), "", true, true))
	var w2 := WorldSim.new()
	w2.from_dict(saved)
	var c2: Dictionary = w2.lord_by_id(int(cato["id"]))
	var t2: Dictionary = c2.get("talk", {})
	check(c2["realm"] == Data.CROWN and String(c2.get("sworn_from", "")) == home and int(c2.get("bought", -1)) == 0, "a sworn lord's oath is saved")
	check(int(t2.get("like_known", 0)) == 1 and (t2.get("stories", []) as Array).has("tale_prudence") and int(t2.get("jobs_done", 0)) == 1,
		"and what you've learned of them and done for them")
	var d2: Dictionary = w2.lord_by_id(int(daimyo["id"]))
	check(typeof(d2["talk"]["refused_until"]) == TYPE_FLOAT and float(d2["talk"]["refused_until"]) > w.hour, "and a refusal, with its wait")
	check(not w2.lord_by_id(int(ruler["id"])).has("talk"), "a lord you never talked with saves no talk")

	# ---- the conversation screen
	var fresh := _field_lord(w, home, false)
	if fresh.is_empty():
		fresh = _field_lord(w, "ryumon", false)
	w.player().node = "ravensford"
	w.player().next = ""
	var talk = LordConversation.open(root, gs, int(fresh["id"]), "road", "first")
	await process_frame
	check(talk.caption().begins_with("At Ravensford") and talk.get_node("Stage/Painted") != null, "at a painted place, you talk before its painting")
	check(talk.greeting_kind(0, {}, 0) == "first" and talk.speech_text().contains(talk._house_line()),
		"a lord you've never met says who they are (%s)" % talk.speech_text())
	check(talk.speech_text().contains(LordLines.custom(fresh)) and LordLines.custom(fresh) != "", "and greets you by a custom of their land")
	check(talk.has_reply("news") and talk.has_reply("trouble") and talk.has_reply("leave") and talk.has_reply("crown", false), "you can ask for news, their troubles, talk of crowns or part ways")
	check(talk._talk.get_node_or_null("Footer") != null and talk._talk.get_node("Footer").get_node_or_null("Reply_leave") != null,
		"the way out sits in a footer, not the list of things to say")
	check(not talk.has_reply("price", false), "before a crown, the crown lines are one locked line")
	check(talk._talk.find_child("Reply_trouble", true, false).find_child("Kind", true, false) != null, "a reply shows what kind of thing it is as an icon")
	talk.choose("story")
	check(talk.has_reply("back") and talk._talk.get_children().any(func(c): return String(c.name).begins_with("Reply_tell_")), "asked for a story, you choose which to tell")
	var first_story: String = talk._talk.get_children().filter(func(c): return String(c.name).begins_with("Reply_tell_"))[0].name
	talk.choose(first_story.trim_prefix("Reply_"))
	check(talk._talk.get_node_or_null("Note") != null, "and see what it did")
	talk.choose("back")
	talk.choose("crown")
	check(talk._talk.get_node_or_null("Conviction") != null and talk._talk.get_node_or_null("Reply_think") != null, "talking of crowns shows how convinced they are")
	var closed := [false]
	talk.closed.connect(func(): closed[0] = true)
	talk.choose("think")
	check(closed[0], "and you can leave it there with nothing lost")
	await process_frame
	w.player().node = "ashby" if Data.SETTLEMENTS.has("ashby") else w.player().node
	var night_talk = LordConversation.open(root, gs, int(fresh["id"]), "road")
	await process_frame
	check(night_talk.get_node_or_null("Stage/SettlementVista") != null or Data.SETTLEMENTS.has(w.player().node) and w.player().node in LordConversation.PAINTED,
		"elsewhere, the game paints the place you're at")
	check(not night_talk.speech_text().contains(night_talk._house_line()) and int(LordTalk.record(fresh).get("talks", 0)) >= 2,
		"meeting again, a lord you've talked with greets you as someone they know")
	# What they remember of you chooses the greeting.
	check(night_talk.greeting_kind(2, {}, 0) == "known" and night_talk.greeting_kind(2, {}, 40) == "warm" and night_talk.greeting_kind(2, {}, -30) == "cold",
		"someone they know is greeted by what they think of you")
	fresh["met_player"] = 1
	check(night_talk.greeting_kind(2, {}, 0) == "fought", "a lord you've met in the field remembers the field")
	LordTalk.record(fresh)["jobs_done"] = 1
	check(night_talk.greeting_kind(2, {}, 0) == "owed" and night_talk.greeting_kind(2, {}, -30) == "cold", "a job you did them comes first, unless they've turned against you")
	fresh.erase("met_player")
	LordTalk.record(fresh).erase("jobs_done")
	# They never say the same thing twice running.
	night_talk.choose("story")
	var asked: String = night_talk.speech_text()
	night_talk.choose("back")
	var hub_one: String = night_talk.speech_text()
	night_talk.choose("story")
	night_talk.choose("back")
	check(asked != hub_one and night_talk.speech_text() != hub_one, "back to what else there is to say, they don't repeat themselves (%s / %s)" % [hub_one, night_talk.speech_text()])
	night_talk.queue_free()
	# What they make of a story answers the kind of story it was, in their own voice.
	var seen := {}
	for bearing in Lords.BEARINGS:
		for theme in ["prudence", "boldness", "modesty", "fear"]:
			seen[LordLines.story({"id": 1, "bearing": bearing}, theme)] = true
	check(seen.size() == 16, "sixteen ways to take a story: four kinds, four bearings (%d)" % seen.size())
	# Married into their house: the head of it greets you as kin.
	var kin_house := ""
	for h in w.social.houses:
		if int(w.social.get_person(String(w.social.houses[h]["head_person_id"])).get("lord_id", -1)) == int(fresh["id"]):
			kin_house = String(h)
	w.social._form_pact(kin_house, "marriage", ["person_edda", "player"], [], w.hour)
	var turn := int(LordTalk.record(fresh).get("talks", 0))
	var kin_words: String = LordLines.say("kin", fresh, {}, turn)
	var kin_talk = LordConversation.open(root, gs, int(fresh["id"]), "road")
	await process_frame
	check(kin_house != "" and kin_talk.speech_text().contains(kin_words), "the head of a house you married into greets you as kin (%s)" % kin_talk.speech_text())
	kin_talk.queue_free()
	w.social.pacts.erase(kin_house)
	var camp = LordConversation.open(root, gs, int(captive["id"]), "captive")
	await process_frame
	check(camp.caption().begins_with("Your camp") and camp.has_reply("release") and camp.has_reply("swear", false) and not camp.has_reply("swear"),
		"a captive is talked to at your camp, and an Honorable one won't swear")
	var release: Node = camp._talk.find_child("Reply_release", true, false)
	check(release.find_child("Effect_bond", true, false) != null and release.find_child("Tag", true, false).text == "for honor",
		"releasing shows its Regard as a chip, not in the words")
	camp.choose("release")
	check(captive["state"] == "regroup", "released for honor, they ride home")
	camp.queue_free()
	check(LordConversation.time_word(7.0) == "morning" and LordConversation.time_word(19.0) == "dusk" and LordConversation.time_word(23.0) == "night", "the hour shows in the scene")

	# ---- People: the Lords tab
	var scenes = root.get_node("Scenes")
	scenes.people_tab = "lords"
	change_scene_to_file("res://scenes/people.tscn")
	await process_frame
	await process_frame
	var people = current_scene
	check(people._tab == "lords", "People opens on Lords")
	var rows := []
	var stack: Array = [people]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if String(n.name).begins_with("Lord_"):
			rows.append(n)
		stack.append_array(n.get_children())
	check(rows.size() >= 3, "every lord you've met has a row (%d)" % rows.size())
	check(rows.any(func(r): return String(r.name) == "Lord_%d" % int(cato["id"])), "your sworn lord among them")

	print("FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)
