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
	check(map._sheet == "talk" and map._talk != null, "you meet them on the road")
	var talk = map._talk

	talk.choose("news")
	talk.choose("chronicle")
	check(map._sheet == "wars", "and ask for news of the war")
	map._close_or_back()
	check(map._sheet == "talk" and talk.visible, "closing the news goes back to the lord")

	map._open_wars()
	map._open_chronicle("war")
	map._close_or_back()
	check(map._sheet == "talk", "so does closing the chronicle opened from it")

	talk.choose("leave")
	check(w.encounter == -1 and not map._sheet_open() and map._talk == null, "parting ways leaves the map free to go on")
	map._open_wars()
	map._close_or_back()
	check(not map._sheet_open(), "with no one waiting, the news just closes")

	# A message that isn't about a fight is titled by where you are, not "After the battle".
	var here: String = w.player().node
	gs.player_fief = {"settlement_id": here, "silver": 274, "food": 60}
	gs.collect_fief_taxes()
	gs.collect_fief_food()
	change_scene_to_file("res://scenes/world_map.tscn")
	await process_frame
	await process_frame
	map = current_scene
	var place := "At %s" % String(Data.settlement(here)["name"])
	check(map._sheet == "notice" and map.sheet_title.text == place, "estate taxes and grain come under the place's name (%s), not a battle" % map.sheet_title.text)
	check(gs.map_notice == "" and gs.map_notice_title == "", "and the message is taken off the queue")
	map._close_sheet()
	gs.player_fief = {}
	# A battle with nothing to say leaves no title behind for the next, unrelated message.
	gs.apply_result({"won": true, "reason": "rout", "lost": 0, "killed": 6, "squads": {}})
	check(gs.map_notice != "" or gs.map_notice_title == "", "a battle with nothing to say leaves no title waiting")
	# One with something to say (here, a line already waiting) comes under the battle's title.
	gs._note("A captain is carried from the field.")
	gs.apply_result({"won": true, "reason": "rout", "lost": 0, "killed": 6, "squads": {}})
	check(gs.map_notice_title == "After the battle", "a battle's result is titled After the battle")
	gs.take_map_notice()

	# Pulling out before the lines meet is riding away: no battle counted, no defeat, no ride home.
	var fought: int = gs.battles
	var at_node: String = w.player().node
	var hour_was: float = w.hour
	gs.pending_battle = {"name": "The Ashen Hands", "objective": "rout"}
	gs.apply_result({"won": false, "reason": "retreat", "before_fight": true, "lost": 0, "killed": 0, "squads": {}})
	check(gs.battles == fought and gs.pending_battle.is_empty(), "leaving before the fight isn't a battle fought")
	check(w.player().node == at_node and w.hour - hour_was < 12.0, "and doesn't send you home beaten")
	gs.take_map_notice()

	print("FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)
