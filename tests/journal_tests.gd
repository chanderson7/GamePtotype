## The journal: what the company has promised, where to go, and how promises ended.
extends SceneTree

const WorldData = preload("res://scripts/world/world_data.gd")
const Cultures = preload("res://scripts/data/cultures.gd")
const Jobs = preload("res://scripts/data/jobs.gd")

var gs
var failures := 0


func check(ok: bool, message: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + message)
	if not ok:
		failures += 1


func _find(id: String) -> Dictionary:
	for c in gs.commitments():
		if c["id"] == id:
			return c
	return {}


func _init() -> void:
	await process_frame
	gs = root.get_node("GameState")
	gs.persist = false
	gs.new_campaign(Cultures.VARDISH)
	var w = gs.world
	check(gs.commitments().is_empty(), "a new company has no commitments")

	# Courier: the destination is the place to show.
	var courier: Dictionary = Jobs.make_courier_job("highcliff", w, w.rng)
	gs.active_jobs.append(courier)
	var c := _find(String(courier["id"]))
	check(c.get("place", "") == courier["destination_settlement"] and float(c["hours_left"]) > 0.0,
		"a courier job points at its destination and shows its deadline")

	# Relief: blocked until the company carries the rations.
	var relief: Dictionary = Jobs.make_relief_job("thornwall", w, w.rng)
	gs.active_jobs.append(relief)
	gs.food = 3
	c = _find(String(relief["id"]))
	check(c["place"] == "thornwall" and String(c["blocked"]).contains("3 rations"), "a relief job says why it can't be done yet")
	gs.food = 500
	check(String(_find(String(relief["id"]))["blocked"]) == "", "and stops waiting once there is food")

	# Hunt: the link follows the band as it moves.
	var band = w.bands()[0]
	gs.active_jobs.append({"id": "hunt_test", "type": Jobs.TYPE_HUNT, "origin_settlement": "highcliff", "title": "Bounty",
		"deadline": w.hour + 72.0, "target_party_id": band.id, "target_name": band.name})
	band.node = "kettlebrook"
	band.next = ""
	band.path = []
	check(_find("hunt_test")["place"] == "kettlebrook", "a hunt points where the band is now")
	band.node = "ravensford"
	check(_find("hunt_test")["place"] == "ravensford", "and follows it when it moves")

	# Reading the journal changes nothing.
	var before: String = JSON.stringify(gs.to_dict())
	gs.commitments()
	gs.pinned()
	check(JSON.stringify(gs.to_dict()) == before, "reading the journal changes no campaign state")

	# Pinning survives a save and load, and toggles off.
	gs.pin_commitment(String(courier["id"]))
	check(gs.pinned().get("id", "") == courier["id"], "a commitment can be pinned")
	var gs2 = load("res://scripts/game_state.gd").new()
	gs2.persist = false
	gs2.from_dict(JSON.parse_string(JSON.stringify(gs.to_dict())))
	check(gs2.pinned().get("id", "") == courier["id"], "the pin survives a save and load")
	gs2.free()

	# An expired job leaves the list, explains itself, and drops its pin.
	courier["deadline"] = w.hour - 1.0
	gs._check_job_deadlines()
	check(_find(String(courier["id"])).is_empty(), "an expired job leaves the active list")
	check(not gs.ended_commitments.is_empty() and String(gs.ended_commitments[0]["outcome"]).contains("Expired"),
		"and the journal says how it ended")
	check(gs.pinned().is_empty() and gs.pinned_commitment == "", "and its pin is cleared")

	# The journal on the map: open it, open a commitment, show it on the map without riding.
	gs.map_notice = "" # the expiry notice would open first, as it should
	change_scene_to_file("res://scenes/world_map.tscn")
	await process_frame
	await process_frame
	var map = current_scene
	var hour: float = w.hour
	var moving: bool = w.player().moving()
	map._open_journal()
	check(map.sheet_title.text.begins_with("Journal") and map.sheet_body.text.contains("Relief"), "the journal lists the commitments")
	map._open_commitment(String(relief["id"]))
	check(map.sheet_title.text == relief["title"] and map.sheet_body.text.contains("Reward"), "a commitment shows its objective and reward")
	map._focus_place("thornwall")
	await process_frame
	check(map._selected == "thornwall" and w.hour == hour and w.player().moving() == moving,
		"Show on map focuses the place without starting travel or time")
	map._on_pin(String(relief["id"]))
	check(map.pin_button.visible and map.pin_button.text.contains("Relief"), "a pinned commitment shows on the map card")

	print("\nJournal tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
