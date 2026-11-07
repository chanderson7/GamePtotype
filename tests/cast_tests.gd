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
		for kind in ["greet", "face", "beaten", "victor"]:
			voiced = voiced and LordVoice.line(kind, l).contains("Lord Test")
	check(voiced, "every bearing has a line for meeting, facing, losing and winning, naming the lord")
	check(LordVoice.line("face", {"name": "Lord Test", "bearing": Lords.DARING}) != LordVoice.line("face", {"name": "Lord Test", "bearing": Lords.CRUEL}),
		"different bearings sound different")
	var two_each := true
	for kind in LordVoice.LINES:
		for bearing in Lords.BEARINGS:
			var options: Array = LordVoice.LINES[kind].get(bearing, [])
			two_each = two_each and options.size() >= 2 and options.all(func(t): return String(t).contains("%s"))
	check(two_each and LordVoice.LINES.has("kin") and LordVoice.LINES.has("pact") and LordVoice.LINES.has("known"),
		"every situation has two lines for each bearing, kin and old acquaintances included")
	var l0 := {"name": "Lord Test", "bearing": Lords.HONORABLE}
	check(LordVoice.line("greet", l0, 0) != LordVoice.line("greet", l0, 1), "and meeting again sounds different")
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
