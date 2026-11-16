## The wedding as an event you ride to: saying yes asks where, the place gets ready and
## waits, the day itself played by hand (who came, who stands with you, vows, the rite step
## by step, "I do"), the feast after (the captains' toasts from their own records, the
## first dance, her people's custom, the tables, slipping away, the closing card), leaving
## and rejoining the feast, dawn ending it, the memory told again, calling it off,
## postponement, private vows, and saves (old ones too).
extends SceneTree

const Cultures = preload("res://scripts/data/cultures.gd")
const Relationships = preload("res://scripts/data/relationships.gd")
const WorldData = preload("res://scripts/world/world_data.gd")
const Captains = preload("res://scripts/data/captains.gd")
const Lines = preload("res://scripts/data/wedding_lines.gd")
const Feast = preload("res://scripts/data/wedding_feast_lines.gd")
const CampMoments = preload("res://scripts/data/camp_moments.gd")

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
	# What you did on the way: held the valley, and stood with her against the hall.
	soc.add_memory(person["id"], "The day the company held the valley.", {"kind": "decision", "chapter": 3, "choice": "defend_district", "candidate": "edda"})
	soc.add_memory(person["id"], "The day I stood with Edda against the hall.", {"kind": "decision", "chapter": 4, "choice": "support_edda", "candidate": "edda"})


func _open_talk() -> void:
	scenes.active_candidate_id = "edda"
	scenes.conversation_return = "res://scenes/settlement.tscn"
	change_scene_to_file("res://scenes/conversation.tscn")
	await _arrive("conversation.tscn")


## Edda's public wedding at Ravensford, made ready and waiting, her house's head at home.
func _ready_wedding() -> void:
	_ready_for_ch5()
	gs.apply_social_choice("edda", "marry_public")
	gs.choose_wedding_place("ravensford")
	_wait(96.0)
	gs.world.player().node = "ravensford"
	gs.world.player().next = ""
	var soc = gs.world.social
	var person: Dictionary = soc.get_candidate_person("edda")
	var head := int(soc.get_person(String(soc.get_house(person["house_id"])["head_person_id"])).get("lord_id", -1))
	if head >= 0 and String(gs.world.lord_by_id(head).get("state", "")) == "prisoner":
		gs.world.release_lord(head)


## Open the day itself.
func _open_wedding() -> void:
	scenes.wedding_replay = ""
	scenes.wedding_return = "res://scenes/world_map.tscn"
	change_scene_to_file("res://scenes/wedding.tscn")
	await _arrive("wedding.tscn")


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
		if friend.is_empty() and String(l["realm"]) == "vardmark" and not bool(l.get("ruler", false)):
			var person: Dictionary = soc.get_candidate_person("edda")
			var host_id := int(soc.get_person(String(soc.get_house(person["house_id"])["head_person_id"])).get("lord_id", -1))
			if int(l["id"]) != host_id:
				friend = l
		if foe.is_empty() and String(l["realm"]) == "kharzan":
			foe = l
	# The host is her house's head; the days of waiting can see them taken in a fight, and a
	# captive stays away (rightly), but this checks the usual day, so they're home for it.
	var head_person: Dictionary = soc.get_candidate_person("edda")
	var head_lord := int(soc.get_person(String(soc.get_house(head_person["house_id"])["head_person_id"])).get("lord_id", -1))
	if head_lord >= 0 and String(gs.world.lord_by_id(head_lord).get("state", "")) == "prisoner":
		gs.world.release_lord(head_lord)
	# The same for the friend: whoever it is, they're free to come.
	if String(friend.get("state", "")) == "prisoner":
		gs.world.release_lord(int(friend["id"]))
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
	# The company, as the day will see it: the captain longest with you, two bonded at rank
	# A, a Quartermaster, and the newest, who lost a bonded friend (Rowan) in your service.
	var caps := []
	for sq in gs.army:
		caps.append(sq["captain"])
	var c1: Dictionary = caps[0]
	var c2: Dictionary = caps[1]
	var c3: Dictionary = caps[2]
	var c4: Dictionary = caps[3]
	var c5: Dictionary = caps[4]
	c1["battles"] = 14
	c1["temperament"] = Captains.STEADFAST
	c1["quirk"] = ""
	c1["specialization"] = ""
	c1["wounded"] = 0
	c2["bonds"][str(int(c3["id"]))] = 25.0
	c3["bonds"][str(int(c2["id"]))] = 25.0
	c4["specialization"] = Captains.QUARTERMASTER
	gs.fallen.append({"id": 999, "first": "Rowan", "name": "Rowan of Ashby", "bond_points": {str(int(c5["id"])): 25.0}})

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
	await _open_wedding()
	var day = current_scene
	check(day.get_node_or_null("Stage/Dressing") != null and day.get_node_or_null("Stage/Face_center") != null, "the place is dressed, and she stands at its centre")
	var StoryArt = load("res://scripts/ui/story_art.gd")
	var dressed: Texture2D = StoryArt.texture("res://assets/portraits/edda_wedding_warm.png")
	var bride := day.get_node("Stage/Face_center") as TextureRect
	check(dressed != null and bride.texture == dressed, "she is dressed for her wedding")
	check(day._faces["center"].has("frames") and StoryArt.eyes_shut(dressed) != null, "and blinks and moves as on any other day")
	check(day._portrait("thoughtful") == dressed, "a mood with no dressed painting keeps her dressed")
	var hair_map = (bride.material as ShaderMaterial).get_shader_parameter("hair") if bride.material is ShaderMaterial else null
	check(hair_map is Texture2D and (hair_map as Texture2D).resource_path.ends_with("edda_wedding_hair.png"),
		"her unbound hair is what moves, not the braid she wears every day")
	check(day.find_child("WhoCame", true, false) != null and day.reply_ids() == ["continue"], "the place, what is set out and who came; a tap goes on")
	var sound = root.get_node("Sound")
	check(sound._track == "wedding_vardish" and sound._loop_name == "murmur", "her people's wedding music, and the guests talking low")
	check(String(sound._movement_loop.get_meta("name", "")) == "hearth", "the hearth-fire can be heard")
	day.choose("continue")
	check(day.log_text().contains(Lines.STAND["edda"]) and day.has_reply("begin") and day.has_reply("later"), "her first words, then: take your place, or not yet")

	# ---- who stands with you
	var seconds: Array = gs.wedding_seconds()
	var why := seconds.map(func(e): return String(e["why"]))
	check(seconds.size() <= Relationships.WEDDING_SECONDS_OFFERED and int(seconds[0]["id"]) == int(c1["id"]) and why[0] == "longest",
		"the captain longest with you is offered first")
	check(why.has("bonded") and why.has("newest") and String(seconds[0]["tag"]).contains("14 battles"), "then one of a bonded pair and the newest, each tagged from the record")
	day.choose("begin")
	check(day.has_reply("second_%d" % int(c1["id"])) and day.has_reply("second_none") and day.reply_node("second_%d" % int(c1["id"])).find_child("Face", true, false) != null,
		"who stands with you: captains by face, or no one")
	day.choose("second_%d" % int(c1["id"]))
	check(day.get_node_or_null("Stage/Face_right") != null, "your second stands on the stage")

	# ---- vows
	check(day.reply_ids() == ["continue"] and not day.log_text().contains("You held the valley"), "the head of her house first; her vow waits its turn")
	check(day.log_text().contains("stood against me in my own hall") and day.find_children("SpeakerFace", "", true, false).size() >= 1,
		"the head of her house speaks of the council you stood in, face beside their name")
	day.choose("continue")
	check(day.log_text().contains("You held the valley") and day.reply_ids() == ["continue"], "she says what you did for her people, and then her vow")
	check(day.log_text().contains(Lines.VOWS["edda_spare_spoon"]) and day.find_child("Remembers", true, false) != null, "her vow comes from the time you shared")
	day.choose("continue")
	check(day.has_reply("vow_promise") and day.has_reply("vow_honest") and day.has_reply("vow_laugh"), "three vows of your own")
	day.choose("vow_promise")
	check(day.get_node("Stage/Face_center").texture == dressed, "a promise: her face answers warm")
	check(day.log_text().contains(Lines.VOW_ANSWER["edda"]["promise"]), "and she answers it in words of her own")

	# ---- the rite, by your hand
	var rite = day.get_node_or_null("Stage/Rite")
	check(day.log_text().contains("red cord") and rite != null and rite.step == 0, "the Vardish rite: the cord, its prop on the stage")
	check(day.log_text().contains("%s takes the cord" % String(c1["first"])), "your second hands you what the rite needs")
	check(day.has_reply("rite_wrist") and day.reply_ids().size() == 1, "one step at a time")
	day.choose("rite_wrist")
	check(rite.step == 1 and day.has_reply("rite_wind") and day.log_text().contains("smoke"), "your wrist, over the fire")
	check(sound._last.has("cord"), "and the cord is heard through the smoke")
	day.choose("rite_wind")
	check(rite.step == 2 and day.has_reply("rite_she_ties") and day.has_reply("rite_together"), "then a choice: the knot")
	check(soc.relationships["edda"]["status"] == Relationships.ENGAGED, "not married yet, all through the rite")
	day.choose("rite_together")
	check(rite.step == 3 and day.log_text().contains("comes out lopsided") and day.reply_ids() == ["continue"], "tied together")
	check(sound._last.has("knot"), "the knot is heard pulled tight")
	day.choose("continue")
	check(sound._loop_name == "" and sound._last.has("heartbeat"), "the guests fall silent for the question: only your heart")

	# ---- the question
	check(day.log_text().contains("at the hearth and on the road") and day.log_text().contains(Lines.ANSWER["edda"]),
		"the question in her people's words, and she answers first")
	check(day.log_text().contains("under their breath"), "your second says something under their breath first")
	check(day.find_children("SpeakerFace", "", true, false).size() >= 1, "the host asks it, face beside their name")
	check(day.has_reply("i_do") and day.has_reply("breath") and day.reply_ids().size() == 2, "I do, or a breath first; there is no other answer")
	check(day.reply_node("i_do").find_child("HoldRing", true, false) != null, "I do is held (a tap says it too)")
	check(day.get_node("Stage/Dressing")._hushed, "the place hushes for it")
	check(soc.relationships["edda"]["status"] == Relationships.ENGAGED and gs.renown == renown0, "still engaged while you're asked")
	day.choose("breath")
	check(day.has_reply("i_do") and not day.has_reply("breath") and day.log_text().contains(Lines.BREATH_SECOND),
		"a breath: your second mutters, and then only I do is left")
	day.choose("i_do")
	check(soc.relationships["edda"]["status"] == Relationships.MARRIED and gs.wedding()["state"] == "feast", "married at I do; the feast begins")
	check(sound._last.has("married") and sound._last.has("applause") and sound._track == "feast_vardish" and sound._loop_name == "feast_din",
		"the harp and the bells, the hands, then the feast's music and its din")
	check(day.get_node_or_null("Stage/MarriedTitle") != null and not day.get_node("Stage/Dressing")._hushed, "Married lands across the stage, and the hush lifts")
	check(day.find_children("Keepsake", "", true, false).is_empty() and day.find_child("ClosingCard", true, false) == null, "and is said once: no card yet")
	check(gs.renown == renown0 + Relationships.WEDDING_RENOWN, "renown for a public wedding, at I do")
	check(gs.relation_with_lord(int(host["id"])) == host_rel0 + Relationships.WEDDING_HOST_REGARD and gs.relation_with_lord(int(friend["id"])) == friend_rel0 + Relationships.WEDDING_GUEST_REGARD,
		"Regard for the host and the guest who came")
	check(gs.silver == silver0 and gs.food == food0, "nothing more is taken on the day")
	var person_e: Dictionary = soc.get_candidate_person("edda")
	var pact: Dictionary = soc.get_pact(person_e["house_id"])
	check(pact["origin"] == "marriage" and pact["protected_sites"].has("ravensford") and not pact["protected_sites"].has("thornwall"), "the pact protects her seat, not a village you don't hold")
	check(gs.world.activity_log.any(func(e): return String(e.get("text", e.get("line", ""))).contains("married at Ravensford")), "the news tells of it")
	check(Dictionary(gs.captain_by_id(int(c1["id"]))["history"].get("wedding", {})).get("with", "") == "Edda", "your second remembers standing with you")
	check(gs._clean_captain(gs.captain_by_id(int(c1["id"])), "infantry")["history"].has("wedding"), "and keeps it through a save")

	# ---- the feast: the night is yours
	for id in ["feast_toasts", "feast_dance", "feast_custom", "feast_tables", "slip"]:
		check(day.has_reply(id), "the feast offers %s" % id)
	var toasters: Array = gs.wedding_toasters(int(c1["id"]))
	var toast_kinds := toasters.map(func(t): return String(t["kind"]))
	check(toast_kinds == ["second", "pair", "newest", "mourner"], "who can toast: your second, a bonded pair, the newest, a mourner, each once (%s)" % ", ".join(PackedStringArray(toast_kinds)))
	day.choose("feast_toasts")
	check(day.log_text().contains("%s · your second" % String(c1["first"])) and day.log_text().contains(Feast.SECOND_OPEN[posmod(int(c1["id"]), 2)]),
		"your second speaks first, unasked, as the one who stood with you")
	check(day.log_text().contains("into 14 battles"), "and what they have seen: their fourteen battles")
	check(day.has_reply("drink") and day.has_reply("heckle"), "drink to it, or heckle")
	day.choose("heckle")
	check(day.log_text().contains(Feast.COMEBACKS[Captains.STEADFAST]) and day.log_text().contains(Feast.HER_LAUGH["edda"]), "a heckle gets a comeback, and she laughs")
	var mourner_key := ""
	var pair_key := ""
	for t in toasters:
		if t["kind"] == "mourner":
			mourner_key = String(t["key"])
		if t["kind"] == "pair":
			pair_key = String(t["key"])
	check(day.has_reply("call_" + mourner_key) and day.has_reply("call_" + pair_key) and day.has_reply("toasts_enough"), "who'll speak next, or enough speeches")
	day.choose("call_" + mourner_key)
	check(day.log_text().contains("Rowan had a toast ready for tonight") and day.has_reply("pour") and not day.has_reply("heckle"), "the mourner drinks to Rowan; no heckling that")
	day.choose("pour")
	check(day.log_text().contains("sets it at the end of the table"), "a cup poured for the fallen")
	day.choose("call_" + pair_key)
	check(day.log_text().contains("We couldn't agree which of us should speak") and day.log_text().contains("So that's two things. To you both."),
		"the bonded pair toast together, a line each (rank A)")
	day.choose("drink")
	check(not day.reply_ids().any(func(id): return String(id).begins_with("call_")) and day.has_reply("toast_absent"),
		"three have spoken: the host, then your cup")
	check(String(day.reply_node("toast_absent").find_child("Text", true, false).text).contains("Rowan"), "absent friends names the fallen")
	day.choose("toast_absent")
	check(day.has_reply("feast_toasts", false) and not day.has_reply("feast_toasts"), "the toasts are done: ticked, and shut")
	var mem: Dictionary = {}
	for m in soc.memory_book(person_e["id"]):
		if m["kind"] == "ceremony":
			mem = m
	check(String(mem.get("vow", "")).begins_with("Wherever the war takes") and String(mem.get("toast", "")).contains("Rowan"), "the memory keeps your vow and toast")
	check(mem.get("toasts", []).size() == 3 and String(mem.get("rite", "")) == "together" and bool(mem.get("breath", false)) and String(mem.get("second_name", "")) == String(c1["first"]),
		"and who toasted, the knot, the breath, and who stood with you")

	# ---- the first dance
	day.choose("feast_dance")
	check(day.has_reply("dance_lead") and day.has_reply("dance_follow"), "the first dance: lead, or let her")
	day.choose("dance_lead")
	day.choose("dance_turn")
	check(day.has_reply("dance_company") and day.has_reply("dance_ours"), "three steps, each answered")
	day.choose("dance_company")
	check(day.log_text().contains("still in column") and day.log_text().contains("reel"), "the company comes in for the round")
	check(gs.wedding()["feast"]["dance"] == ["lead", "turn", "company"], "the steps are kept")

	# ---- leave in the middle, and come back
	day.close()
	await _arrive("world_map.tscn")
	check(gs.wedding_feast_open() and gs.wedding_feast_here(), "closed mid-feast: it's still going while you're here")
	scenes.settlement_arrival_pending = false
	change_scene_to_file("res://scenes/settlement.tscn")
	await _arrive("settlement.tscn")
	current_scene._on_tab("court")
	await process_frame
	check(current_scene.find_child("RejoinFeast", true, false) != null, "the Court tab says the feast is still going: Rejoin")
	await _open_wedding()
	day = current_scene
	check(day.log_text().contains("still going") and day.has_reply("feast_dance", false) and not day.has_reply("feast_dance") and day.has_reply("feast_custom"),
		"back at the feast, what's done is ticked")
	check(day.get_node_or_null("Stage/Face_right") != null, "and your second is still beside you")

	# ---- her people's custom
	day.choose("feast_custom")
	check(day.log_text().contains("barred the hall door") and String(day.reply_node("custom_wrestle").find_child("Text", true, false).text).contains(String(c1["first"])),
		"the door toll; your second can arm-wrestle the cook")
	day.choose("custom_wrestle")
	check(gs.wedding()["feast"]["custom"] == "wrestle", "the toll paid is kept")
	check(day.log_text().contains("kisses Edda on the forehead"), "and the cook has the last of it")

	# ---- round the tables
	day.choose("feast_tables")
	check(day.find_child("Gifts", true, false) != null and day.log_text().contains("copper kettle") and day.log_text().contains("wrote down who gave what"),
		"the gifts, the company's with the Quartermaster's receipt")
	var lord_id := "table_lord_%d" % int(friend["id"])
	check(day.has_reply(lord_id) and day.has_reply("table_host_%d" % int(host["id"])), "every guest by face")
	check(not day.has_reply("table_captain_%d" % int(c1["id"]), false) and day.has_reply("table_captain_%d" % int(c4["id"])), "captains who toasted aren't asked again")
	day.choose(lord_id)
	check(day.has_reply(lord_id, false) and not day.has_reply(lord_id) and day.find_children("SpeakerFace", "", true, false).size() >= 1, "a word from the lord, once")
	check(day.has_reply("table_kin_cousin") and day.has_reply("table_kin_cook"), "her own people are at the tables too")
	day.choose("table_kin_cousin")
	check(day.log_text().contains("I took two") and day.has_reply("table_kin_cousin", false) and not day.has_reply("table_kin_cousin"),
		"her cousin, who had a speech, has a word once")
	day.choose("tables_back")

	# ---- slipping away
	check(day.has_reply("slip") and not day.has_reply("feast_tables"), "everything done, the night's end is left")
	day.choose("slip")
	await process_frame
	check(day.get_node_or_null("Stage/Dressing") == null and day.get_node_or_null("Stage/Face_right") == null, "away to her room: no banners, no guests")
	check(sound._last.has("door") and sound._loop_name == "" and sound._track == "wedding_vardish" and String(sound._movement_loop.get_meta("name", "")) == "hearth",
		"the door shuts on the din: her fire, and the wedding music again")
	check(sound._last.has("cups") and sound._last.has("laugh"), "the table was heard: cups for a toast, a laugh for a heckle")
	check(day.log_text().contains(Feast.RECALL["edda"]["breath"]), "she recalls the breath you took")
	check(day.has_reply("last_stay") and day.has_reply("last_sleep"), "one last choice")
	day.choose("last_sleep")
	check(gs.wedding()["state"] == "done" and not gs.wedding_feast_open(), "the night is over")
	check(day.find_child("ClosingCard", true, false) != null and day.has_reply("done"), "one closing card, one way back")
	var night_icons: Node = day.find_child("TheNight", true, false)
	check(night_icons != null and night_icons.get_child_count() == 5, "the night in icons: the rings and all four things done")
	for m in soc.memory_book(person_e["id"]):
		if m["kind"] == "ceremony":
			mem = m
	check(String(mem.get("last", "")) == "sleep" and String(mem.get("custom", "")) == "wrestle" and mem.get("dance", []).size() == 3, "all of it kept")
	check(CampMoments.candidates(gs).any(func(c): return c["kind"] == "wedding" and String(c["text"]).contains(String(c1["first"]))),
		"at the next camp, your second is still telling the toast")

	# ---- married life: the head of her house is kin, and a sixth chapter waits a day on
	var head_e: Dictionary = soc.get_person(String(soc.get_house(person_e["house_id"])["head_person_id"]))
	check(String(soc.pact_for_lord(int(head_e["lord_id"])).get("origin", "")) == "marriage", "the head of her house is kin by marriage")
	check(not bool(soc.post_state("edda", gs.world.hour)["ok"]) and bool(soc.post_state("edda", gs.world.hour + 25.0)["ok"]),
		"and a day after the wedding, one more matter waits (chapter 6)")

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
	var told: String = current_scene.log_text()
	check(told.contains("Wherever the war takes") and told.contains("I do.") and told.contains("lopsided") and current_scene.has_reply("finish"),
		"Relive tells it again: your vow, the knot, I do")
	check(told.contains("You held the valley") and told.contains(Lines.VOW_ANSWER["edda"]["promise"]), "what she said of what you did, and her answer to your vow")
	check(told.contains("Rowan had a toast ready") and told.contains("still in column") and told.contains("I counted myself first"),
		"the toasts as they were said, the dance, her last words")
	check(soc.relationships["edda"]["status"] == Relationships.MARRIED, "and changes nothing")
	# A wedding kept before the day was played by hand is told as it was kept.
	soc.add_memory(person_e["id"], "Married Edda at Ravensford.", {"kind": "ceremony", "scene_id": "wedding", "place": "ravensford",
		"candidate": "edda", "vow": "An old vow.", "toast": "To Edda.", "guests": []})
	scenes.wedding_replay = String(soc.memory_book(person_e["id"]).back()["id"])
	scenes.wedding_return = "res://scenes/world_map.tscn"
	change_scene_to_file("res://scenes/wedding.tscn")
	await _arrive("wedding.tscn")
	told = current_scene.log_text()
	check(told.contains("An old vow.") and told.contains("red cord") and not told.contains("I do."), "an old memory still replays as it was")

	# ---- dawn ends a feast you never went back to; so does riding away
	_ready_wedding()
	soc = gs.world.social
	gs.finish_wedding({"vow": "A vow.", "their_vow": "Hers.", "second": -1})
	check(gs.wedding()["state"] == "feast" and float(gs.wedding()["feast_ends_hour"]) > gs.world.hour, "married; the feast runs until dawn")
	_wait(30.0)
	check(gs.wedding()["state"] == "done" and soc.relationships["edda"]["status"] == Relationships.MARRIED, "dawn ends it quietly, still married")
	_ready_wedding()
	soc = gs.world.social
	gs.finish_wedding({"vow": "A vow.", "their_vow": "Hers.", "second": -1})
	gs.world.player().next = "highcliff"
	soc.step(0.5, gs.world)
	check(gs.wedding()["state"] == "done", "and so does riding away")
	gs.world.player().next = ""
	var saved_w: Dictionary = JSON.parse_string(JSON.stringify(soc.to_dict()))
	soc.from_dict(saved_w)
	check(soc.wedding["state"] == "done" and soc.wedding["second"] is int, "a held wedding survives a save")

	# ---- straight through: the first reply at every beat reaches the closing card
	_ready_wedding()
	soc = gs.world.social
	await _open_wedding()
	day = current_scene
	var taps := 0
	while taps < 120 and not day.has_reply("done"):
		var ids: Array = day.reply_ids().filter(func(id): return day.has_reply(String(id)))
		if ids.is_empty():
			break
		day.choose(String(ids[0]))
		taps += 1
	check(day.has_reply("done") and gs.wedding()["state"] == "done" and soc.relationships["edda"]["status"] == Relationships.MARRIED,
		"autoplay's way through, the first reply each time, gets married and home (%d taps)" % taps)

	# ---- every people's rite: plain steps, then a choice that is kept; its prop draws
	var Rite = load("res://scripts/ui/wedding_rite.gd")
	for cul in [Cultures.VARDISH, Cultures.KHARZANI, Cultures.RYUMON]:
		var steps: Dictionary = Lines.rite_steps(cul)
		check(steps["steps"].size() >= 2 and steps["choices"].size() >= 2 and Lines.question(cul).has("you") and Lines.SEAL.has(cul),
			"the %s rite: steps, a choice, its question and seal" % cul)
		var prop = Rite.new()
		prop.culture = cul
		root.add_child(prop)
		for i in steps["steps"].size() + 1:
			prop.advance()
			await process_frame
		check(prop.step == steps["steps"].size() + 1, "its prop follows every step")
		prop.free()
	check(Lines.ASKED_AGAIN.get(Cultures.KHARZANI, []).size() == 2, "among the Kharzani she is asked three times")
	check(String(Lines.rite_steps(Cultures.KHARZANI).get("after", "")).contains("\"Yes.\""), "and the clause she showed nobody is read out at last")

	# ---- the words: every time you shared has a vow, every vow an answer, every council a word
	var Stories = load("res://scripts/data/personal_conversations.gd")
	for scene_id in Stories.SCENES:
		check(Lines.VOWS.has(scene_id), "a vow from %s" % scene_id)
	for c in ["edda", "farid", "kaede"]:
		for v in Lines.yours(c):
			check(Lines.vow_answer(c, String(v["id"])) != "" and Lines.vow_id(c, String(v["text"])) == String(v["id"]), "%s answers your vow (%s)" % [c, v["id"]])
		for council in ["negotiate", "support_edda", "repair_promise", ""]:
			check(Lines.host_word(c, council) != "", "%s's house has a word for the council (%s)" % [c, council])
		for task in ["fund_muster", "defend_district", "correspondence"]:
			check(Lines.their_road(c, task) != "", "%s says what you did (%s)" % [c, task])
		check(Feast.her_people(c).size() == 2, "%s's own people come" % c)
	var mended: Dictionary = Lines.road([{"kind": "decision", "chapter": 3, "choice": "correspondence"}, {"kind": "decision", "chapter": 4, "choice": "break_promise"},
		{"kind": "visit", "scene_id": "edda_spare_spoon"}, {"kind": "decision", "chapter": 4, "choice": "repair_promise"}])
	check(mended["task"] == "correspondence" and mended["council"] == "repair_promise", "the road here: the task you took, and a broken word mended")
	check(Lines.road([])["council"] == "" and Lines.host_word("edda", "") == Lines.HOST_WORD["edda"][""], "with nothing in the book, the house speaks plainly")
	# Every sound the day asks for is there to be played, and every people has its music.
	var asked := {}
	for v in current_scene.RITE_SOUNDS.values() if current_scene != null and current_scene.get("RITE_SOUNDS") != null else []:
		asked[String(v)] = true
	for nm in ["cord", "knot", "bread", "salt", "quill", "pour", "cup_down", "brush", "seal", "married", "heartbeat", "hearth", "murmur",
			"feast_din", "laugh", "applause", "cups", "lantern", "door"]:
		asked[nm] = true
	for nm in asked:
		check(FileAccess.file_exists("res://assets/audio/sfx/%s.ogg" % nm), "the sound %s exists" % nm)
	for cul in [Cultures.VARDISH, Cultures.KHARZANI, Cultures.RYUMON]:
		check(FileAccess.file_exists("res://assets/audio/music/wedding_%s.ogg" % cul), "the %s wedding has its music" % cul)
	# Nobody is bride or groom, and a lord is never he or she.
	var said := ""
	for path in ["res://scripts/data/wedding_lines.gd", "res://scripts/data/wedding_feast_lines.gd"]:
		for line in FileAccess.get_file_as_string(path).split("\n"):
			if not String(line).strip_edges().begins_with("#"):
				said += String(line).to_lower() + "\n"
	check(not said.contains("groom") and not said.contains("bride"), "nobody is called bride or groom")

	# ---- toasts from the record
	var steady := {"id": 1, "temperament": Captains.STEADFAST, "specialization": Captains.QUARTERMASTER, "culture": Cultures.KHARZANI}
	var toast := Feast.captain_toast(steady)
	check(toast.contains("I'll say what I've seen") and toast.contains("the company's stores") and toast.contains("bread and salt"),
		"a toast is how they start, what they have seen, and how their own people raise a cup")
	check(Feast.know({"wounded": 1, "specialization": Captains.SCOUT}) == Feast.WOUNDED, "wounded tonight comes first")
	check(Feast.know({"battles": 4}).contains("4 battles"), "else their battles")
	check(Feast.toast_lines({"kind": "hero", "captain": {"is_hero": true, "hero_id": "tariq", "first": "Tariq"}})[0]["text"].contains("waterskin"), "a hero speaks in their own voice")
	var pair_lines: Array = Feast.toast_lines({"kind": "pair", "rank": "B", "captain": {"first": "Ilse"}, "other": {"first": "Bren"}})
	check(pair_lines.size() == 4 and pair_lines[1]["who"] == "b" and String(pair_lines[1]["text"]).contains("Ilse"), "a pair takes turns, and names each other")
	gs.army = []
	check(gs.wedding_seconds().is_empty() and gs.wedding_toasters().is_empty(), "with no captains, no one is asked to stand or toast")

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
	check(talk.log_text().contains(Lines.PRIVATE_SCENE), "by one candle, in her room")
	talk.choose("continue")
	check(talk.has_reply("vow_honest"), "the same vows to say")
	talk.choose("vow_honest")
	check(talk.log_text().contains(Lines.PRIVATE_ASK["edda"]) and talk.has_reply("i_do") and talk.reply_ids().size() == 1, "she asks you herself: I do")
	talk.choose("i_do")
	check(talk.log_text().contains(Lines.PRIVATE_ANSWER["edda"]) and talk.find_child("Keepsake", true, false) != null, "and answers it")
	var pm: Dictionary = soc.memory_book(soc.get_candidate_person("edda")["id"]).back()
	check(pm["kind"] == "ceremony" and bool(pm.get("private", false)) and String(pm.get("vow", "")).begins_with("I can't promise") and bool(pm.get("i_do", false)),
		"kept as a memory with your vow, and the question answered")
	check(soc.get_pact(soc.get_candidate_person("edda")["house_id"]).is_empty(), "no pact without the house")

	print("FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)
