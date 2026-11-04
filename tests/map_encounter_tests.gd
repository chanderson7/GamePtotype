## A friendly lord on the road: asking for news of the war (and the chronicle from there)
## and closing it goes back to the lord, not to a map paused with nothing to answer.
extends SceneTree

const Data = preload("res://scripts/world/world_data.gd")

var failures := 0


func check(ok: bool, message: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + message)
	if not ok:
		failures += 1


func _init() -> void:
	await process_frame
	var gs = root.get_node("GameState")
	gs.persist = false
	gs.new_campaign("vardish")
	var w = gs.world
	var home: String = Data.realm_of_culture("vardish")
	var lord: Dictionary = {}
	for l in w.lords:
		if l["realm"] == home and l["state"] == "field" and int(l.get("party", -1)) >= 0:
			lord = l
			break
	check(not lord.is_empty(), "a lord of your own realm is out on the road")
	gs.map_notice = ""
	change_scene_to_file("res://scenes/world_map.tscn")
	await process_frame
	await process_frame
	var map = current_scene
	map._close_sheet()
	w.encounter = int(lord["party"])
	map._open_encounter()
	check(map._sheet == "encounter", "you meet them on the road")

	map._open_wars()
	check(map._sheet == "wars", "and ask for news of the war")
	map._close_or_back()
	check(map._sheet == "encounter" and map.sheet_panel.visible, "closing the news goes back to the lord")

	map._open_wars()
	map._open_chronicle("war")
	map._close_or_back()
	check(map._sheet == "encounter", "so does closing the chronicle opened from it")

	map._on_part_ways_friendly()
	check(w.encounter == -1 and not map.sheet_panel.visible, "parting ways leaves the map free to go on")
	map._open_wars()
	map._close_or_back()
	check(not map.sheet_panel.visible, "with no one waiting, the news just closes")

	print("FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)
