## Sieges have campaign-scale presence: what the map and settlement sheets show of a siege
## comes from the same state the assault is settled from.
extends SceneTree

const Cultures = preload("res://scripts/data/cultures.gd")
const WorldData = preload("res://scripts/world/world_data.gd")
const TravelPresentation = preload("res://scripts/world/travel_presentation.gd")

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
	var target := ""
	var realm := ""
	for id in WorldData.SETTLEMENTS:
		if String(WorldData.settlement(id)["type"]) != WorldData.CASTLE:
			continue
		for r in ["vardmark", "kharzan", "ryumon"]:
			if r != w.owner_of(id) and w.at_war(r, w.owner_of(id)):
				target = id
				realm = r
		if target != "":
			break
	check(w.siege_info(target).is_empty() and TravelPresentation.settlement_state(w, target)["condition"] != "besieged",
		"a place nobody besieges shows no siege")

	var members: Array = []
	var men := 0
	for l in w.lords:
		var lp = w.party(int(l["party"]))
		if l["realm"] == realm and lp != null and members.size() < 2:
			members.append(lp.id)
			men += w.men_of(lp.army)
	w.campaign_armies.append({"id": 77, "realm": realm, "leader": members[0], "members": members, "state": "besieging",
		"target": target, "destination": target, "siege_prep_until": w.hour + 30.0, "siege_food_until": w.hour + 72.0})
	var info: Dictionary = w.siege_info(target)
	check(info["attackers"] == men and info["defenders"] == w.men_of(w.garrison_at(target)) and info["realm"] == realm,
		"the siege shows the real besiegers and garrison")
	check(int(info["food_hours"]) == 72 and int(info["assault_hours"]) == 30 and info["walls"] > 1.0,
		"its food, the time until the assault, and the walls come from the army's own clock")
	var state: Dictionary = TravelPresentation.settlement_state(w, target)
	check(state["condition"] == "besieged" and String(state["sentence"]).contains("camped"), "the settlement reads as besieged")
	var intel: String = w.settlement_intelligence(target)
	check(intel.contains("under siege") and intel.contains("food for 3 days") and intel.contains("%d men" % men),
		"its sheet gives the numbers that decide the siege")

	gs.map_notice = ""
	change_scene_to_file("res://scenes/world_map.tscn")
	await process_frame
	await process_frame
	check(current_scene != null, "the map draws the siege ring and camp")

	w.campaign_armies[-1]["state"] = "returning"
	check(w.siege_info(target).is_empty() and TravelPresentation.settlement_state(w, target)["condition"] != "besieged",
		"when the army leaves, the siege is gone from the map and the sheet")

	print("\nSiege presence tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
