## The broader cast becomes recognizable: lords' faces, house colors and voices.
extends SceneTree

const Cultures = preload("res://scripts/data/cultures.gd")
const Lords = preload("res://scripts/data/lords.gd")
const LordVoice = preload("res://scripts/data/lord_voice.gd")

var failures := 0


func check(ok: bool, message: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + message)
	if not ok:
		failures += 1


func _init() -> void:
	await process_frame
	var gs = root.get_node("GameState")
	gs.persist = false
	gs.new_campaign(Cultures.VARDISH)
	var w = gs.world
	var a: Dictionary = w.lords[1]
	var b: Dictionary = w.lords[2]

	var voiced := true
	for bearing in Lords.BEARINGS:
		var l := {"name": "Lord Test", "bearing": bearing}
		for kind in ["face", "again", "beaten", "victor"]:
			voiced = voiced and LordVoice.line(kind, l).contains("Lord Test")
	check(voiced, "every bearing has a line for facing you, facing you again, losing and winning, naming the lord")
	check(LordVoice.line("face", {"name": "Lord Test", "bearing": Lords.DARING}) != LordVoice.line("face", {"name": "Lord Test", "bearing": Lords.CRUEL}),
		"different bearings sound different")
	var two_each := true
	for kind in LordVoice.LINES:
		for bearing in Lords.BEARINGS:
			var options: Array = LordVoice.LINES[kind].get(bearing, [])
			two_each = two_each and options.size() >= 2 and options.all(func(t): return String(t).contains("%s"))
	check(two_each, "every situation on the field has two lines for each bearing")
	# What they say when you talk with them (lord_lines.gd): every beat in all four voices.
	var LordLines = load("res://scripts/data/lord_lines.gd")
	var spoken := true
	var missing: Array = []
	for key in LordLines.LINES:
		for bearing in Lords.BEARINGS:
			var options: Array = LordLines.LINES[key].get(bearing, [])
			if options.is_empty() or options.any(func(t): return String(t).strip_edges() == ""):
				spoken = false
				missing.append("%s/%s" % [key, bearing])
	check(spoken, "every beat of a talk has a line for each bearing (%s)" % ", ".join(missing))
	var varied := true
	for key in ["first", "known", "warm", "cold", "fought", "owed", "kin", "pact", "liege", "again", "trouble_bandits", "objection"]:
		for bearing in Lords.BEARINGS:
			varied = varied and (LordLines.LINES[key][bearing] as Array).size() >= 2
	check(varied, "and greetings, their troubles and their objections have more than one")
	var l0 := {"id": 3, "name": "Lord Test", "bearing": Lords.HONORABLE}
	check(LordLines.say("known", l0, {}, 0) != LordLines.say("known", l0, {}, 1), "meeting again sounds different")
	check(LordLines.say("known", l0) != LordLines.say("known", {"id": 4, "name": "Lord Other", "bearing": Lords.HONORABLE}),
		"and two lords alike don't open alike")
	var distinct := true
	for key in LordLines.LINES:
		var firsts := {}
		for bearing in Lords.BEARINGS:
			firsts[String(LordLines.LINES[key][bearing][0])] = true
		# (A tribute is only ever paid to a Cruel lord: the others share a line.)
		distinct = distinct and (firsts.size() == Lords.BEARINGS.size() or key == "tribute")
	check(distinct, "no two bearings say the same thing in the same place")
	# Every fact a line asks for is one its caller gives it.
	var facts := {"holds": "I hold Ravensford", "fief": "Ravensford", "host": "Lord Host", "count": "Two things", "first": "News.",
		"ruler": "King Aldwin", "capital": "Highcliff", "band": "The Red Hand", "place": "Ashby", "enemy": "The Kharzani",
		"silver": 300, "house": "Fairholt", "champion": "Rowan"}
	var filled := true
	var unfilled: Array = []
	for key in LordLines.LINES:
		for bearing in Lords.BEARINGS:
			for i in (LordLines.LINES[key][bearing] as Array).size():
				var said: String = LordLines.say(key, {"id": 0, "bearing": bearing}, facts, i)
				if said.contains("{") or said.contains("}") or said.contains("%"):
					filled = false
					unfilled.append("%s/%s" % [key, bearing])
	check(filled, "every fact in a line is filled in (%s)" % ", ".join(unfilled))
	var reactions := true
	for bearing in Lords.BEARINGS:
		for theme in ["prudence", "boldness", "modesty", "fear"]:
			reactions = reactions and LordLines.story({"bearing": bearing}, theme) != "A good story. The road's shorter for it."
	check(reactions, "every bearing has something of its own to say to every kind of story")
	var customs := true
	for cult in Cultures.ORDER:
		for bearing in Lords.BEARINGS:
			customs = customs and LordLines.custom({"culture": cult, "bearing": bearing}) != ""
	check(customs, "and a custom of their land to greet a stranger with")
	var assumes_a_man := false
	for key in LordLines.LINES:
		for bearing in Lords.BEARINGS:
			for t in LordLines.LINES[key][bearing]:
				assumes_a_man = assumes_a_man or String(t).contains("a man's business")
	for cult in LordLines.CUSTOM:
		for bearing in LordLines.CUSTOM[cult]:
			var t := String(LordLines.CUSTOM[cult][bearing])
			assumes_a_man = assumes_a_man or t.contains(" his ") or t.contains(" he's ") or t.contains("man's")
	check(not assumes_a_man, "nothing a lord says to you assumes you're a man")
	# A lord may be a lady: her name says so, and her face is drawn as a woman's.
	var CaptainFace = load("res://scripts/art/captain_face.gd")
	var lady := {"id": 7, "name": "Lord Jessa Fairholt", "culture": Cultures.VARDISH, "bearing": Lords.CAUTIOUS, "house": "Fairholt"}
	var lord := {"id": 8, "name": "Lord Piers Fairholt", "culture": Cultures.VARDISH, "bearing": Lords.CAUTIOUS, "house": "Fairholt"}
	check(LordVoice.is_lady(lady) and not LordVoice.is_lady(lord) and LordVoice.is_lady({"name": "Emir Nasrin ibn Malik", "culture": Cultures.KHARZANI})
		and LordVoice.is_lady({"name": "Daimyo Ume Hosokawa", "culture": Cultures.RYUMON}) and not LordVoice.is_lady({"name": "King Aldwin", "culture": Cultures.VARDISH}),
		"a lord whose first name is a woman's is a lady, in every land")
	var bearded := 0
	var lady_hair := true
	for i in 40:
		var rec := LordVoice.portrait_record({"id": i, "name": "Lord %s Test" % ["Jessa", "Elspeth", "Una", "Mira"][i % 4], "culture": Cultures.VARDISH})
		var f: Dictionary = CaptainFace.features(rec)
		if String(f["beard"]) != "none":
			bearded += 1
		lady_hair = lady_hair and String(f["hair"]) in ["braid", "long"]
	check(bearded == 0 and lady_hair, "a lady lord is never drawn with a beard, and wears her hair as the women of her land do")
	var men_bearded := 0
	for i in 40:
		if String(CaptainFace.features(LordVoice.portrait_record({"id": i, "name": "Lord Piers Test", "culture": Cultures.VARDISH}))["beard"]) != "none":
			men_bearded += 1
	check(men_bearded > 0, "and the lords who are men still may be (%d of 40)" % men_bearded)
	# The names of the people you court and the heroes are theirs alone.
	var free := true
	for cult in Cultures.ORDER:
		for n in Cultures.RESERVED:
			free = free and not (Cultures.info(cult)["first"] as Array).has(n)
	for s in gs.army:
		if s.get("captain") is Dictionary:
			free = free and not Cultures.RESERVED.has(String(s["captain"].get("first", "")))
	check(free, "no captain, lord or heir is given Edda's, Farah's, Kaede's or a hero's name")
	check(LordVoice.portrait_record(a)["id"] != LordVoice.portrait_record(b)["id"] and LordVoice.portrait_record(a)["id"] >= LordVoice.PORTRAIT_BASE,
		"each lord has his own face, apart from the captains'")
	check(LordVoice.portrait_record(a) == LordVoice.portrait_record(a), "and it is the same each time")
	var houses := {}
	for l in w.lords:
		houses[str(LordVoice.house_colors(l)[0])] = true
	check(houses.size() > 3, "houses fly different colors (%d)" % houses.size())

	gs.map_notice = ""
	change_scene_to_file("res://scenes/world_map.tscn")
	await process_frame
	await process_frame
	var map = current_scene
	map._close_sheet()
	var lp = w.party(int(a["party"]))
	map._open_lord(lp)
	var header = map.sheet_extra.find_child("SheetHeader", true, false)
	check(header != null and header.find_child("SheetName", true, false).text == lp.name and header.get_child_count() >= 3,
		"a lord's sheet shows his face, banner and name")
	map._open_wars()
	check(not map.sheet_lord_row.visible, "and other sheets don't")

	print("\nCast tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
