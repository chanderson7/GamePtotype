## Consequences follow the company: battle and capture aftermath on the map, named places,
## and camp reactions from the captains who were there.
extends SceneTree

const Cultures = preload("res://scripts/data/cultures.gd")
const WorldData = preload("res://scripts/world/world_data.gd")
const CampMoments = preload("res://scripts/data/camp_moments.gd")

var gs
var failures := 0


func check(ok: bool, message: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + message)
	if not ok:
		failures += 1


func _init() -> void:
	await process_frame
	gs = root.get_node("GameState")
	gs.persist = false
	gs.new_campaign(Cultures.VARDISH)
	var w = gs.world
	check(w.aftermath().is_empty(), "a new world bears no aftermath")

	# Storm a castle: the battle and the new banner mark it on the map.
	var target := ""
	var employer := ""
	for id in WorldData.SETTLEMENTS:
		if String(WorldData.settlement(id)["type"]) != WorldData.CASTLE:
			continue
		for r in ["vardmark", "kharzan", "ryumon"]:
			if r != w.owner_of(id) and w.at_war(r, w.owner_of(id)):
				target = id
				employer = r
		if target != "":
			break
	gs.contract = {"realm": employer, "daily_pay": 10, "days_left": 30, "bonus_per_lord": 100}
	w.player().node = target
	w.player().next = ""
	w.player().path = []
	w.garrisons[target] = w.garrisons[target].slice(0, 1)
	w.garrisons[target][0]["men"] = 6
	gs.auto_resolve_siege(target)
	var marks: Array = w.aftermath()
	check(marks.any(func(a): return a["place"] == target and a["kind"] == "battle"), "a battle leaves crossed blades at its place")
	check(marks.any(func(a): return a["place"] == target and a["kind"] == "banner"), "a capture leaves a fresh banner")
	check(String(gs.last_result.get("place", "")) == target, "the battle report names where it was fought")
	check(w.activity_log.any(func(e): return e.get("type", "") == "battle_fought" and e.get("place", "") == target),
		"and the chronicle records it at the same place")

	# Saved and loaded, the aftermath is the same.
	var gs2 = load("res://scripts/game_state.gd").new()
	gs2.persist = false
	gs2.from_dict(JSON.parse_string(JSON.stringify(gs.to_dict())))
	check(gs2.world.aftermath().size() == marks.size(), "the aftermath survives a save and load")
	gs2.free()

	# The camp: the captain who did the most speaks of the victory, and names the place.
	var star: Dictionary = gs.army[2]["captain"]
	gs.last_result["captains"] = [{"id": int(gs.army[0]["captain"]["id"]), "fate": "standing", "kills": 1},
		{"id": int(star["id"]), "fate": "standing", "kills": 9}]
	gs.camp_seen = []
	var m: Dictionary = CampMoments.pick(gs)
	check(m.get("kind", "") == "victory" and int(m.get("captain_id", -1)) == int(star["id"])
		and String(m["text"]).contains(String(WorldData.settlement(target)["name"])),
		"the captain who did the most speaks of the victory, and of where it was won")

	# A captain who fell is mourned by a bonded friend.
	var friend: Dictionary = gs.army[1]["captain"]
	gs.fallen.append({"id": 9998, "name": "Test Fallen", "first": "Wynn", "temperament": "", "battle": gs.battles,
		"type": "infantry", "bonds": ["%s (C)" % friend["first"]]})
	m = CampMoments.pick(gs)
	check(m.get("kind", "") == "fallen" and String(m["text"]).contains(String(friend["first"])) and String(m["text"]).contains("Wynn"),
		"a fallen captain is mourned by the friend they were bonded to")
	CampMoments.dismiss(gs, m["key"])
	check(CampMoments.pick(gs).get("key", "") != m["key"], "and the reaction isn't repeated")

	# The map draws it; after a few days it is gone, but the chronicle keeps it.
	change_scene_to_file("res://scenes/world_map.tscn")
	await process_frame
	await process_frame
	check(current_scene != null, "the map draws the aftermath")
	w.hour += 4.0 * 24.0
	check(w.aftermath().is_empty() and w.activity_log.any(func(e): return e.get("type", "") == "battle_fought"),
		"after three days the marks are gone, and the chronicle still remembers")

	print("\nAftermath tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
