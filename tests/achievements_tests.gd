## Company deeds: earned once from real events, shown with progress, a name to carry.
extends SceneTree

const Cultures = preload("res://scripts/data/cultures.gd")
const WorldData = preload("res://scripts/world/world_data.gd")
const Achievements = preload("res://scripts/data/achievements.gd")

var gs
var failures := 0


func check(ok: bool, message: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + message)
	if not ok:
		failures += 1


func _next_day() -> void:
	gs.world.hour = (int(gs.world.hour / 24.0) + 1) * 24.0 + 1.0
	gs.settle()


func _init() -> void:
	await process_frame
	gs = root.get_node("GameState")
	gs.persist = false
	gs.new_campaign(Cultures.RYUMON)
	var w = gs.world
	check(gs.deeds.is_empty() and Achievements.progress(gs, "jobs") == 0, "a new company has earned nothing yet")

	# A contract served to its end.
	gs.contract = {"realm": "ryumon", "daily_pay": 10, "days_left": 1, "bonus_per_lord": 100}
	_next_day()
	check(gs.deeds.has("contract"), "serving a contract to its end earns a deed")
	check(w.activity_log.any(func(e): return e.get("type", "") == "achievement" and String(e.get("text", "")).contains("contract")),
		"and the chronicle remembers it")

	# Progress, then the deed, for jobs.
	for i in 4:
		gs.completed_jobs.append({"id": "j%d" % i})
	_next_day()
	check(not gs.deeds.has("jobs") and Achievements.progress(gs, "jobs") == 4, "progress shows before a deed is reached (4/5)")
	gs.completed_jobs.append({"id": "j5"})
	_next_day()
	check(gs.deeds.has("jobs"), "the fifth job earns it")

	# A veteran captain.
	gs.army[0]["captain"]["battles"] = 10
	_next_day()
	check(gs.deeds.has("veteran"), "a captain alive through ten battles earns the Old Guard")

	# Earned once only.
	var day: int = int(gs.deeds["contract"]["day"])
	var entries: int = w.activity_log.filter(func(e): return e.get("type", "") == "achievement").size()
	_next_day()
	_next_day()
	check(int(gs.deeds["contract"]["day"]) == day and w.activity_log.filter(func(e): return e.get("type", "") == "achievement").size() == entries,
		"a deed is earned once, and not announced again")

	# Storming walls, by the real siege path.
	var target := ""
	var employer := ""
	for id in WorldData.SETTLEMENTS:
		if String(WorldData.settlement(id)["type"]) != WorldData.CASTLE:
			continue
		for realm in ["vardmark", "kharzan", "ryumon"]:
			if realm != w.owner_of(id) and w.at_war(realm, w.owner_of(id)):
				target = id
				employer = realm
				break
		if target != "":
			break
	gs.contract = {"realm": employer, "daily_pay": 10, "days_left": 30, "bonus_per_lord": 100}
	w.player().node = target
	w.player().next = ""
	w.player().path = []
	w.garrisons[target] = []
	gs.auto_resolve_siege(target)
	check(gs.deeds.has("walls"), "storming a castle earns the Wallbreakers")

	# Names: only earned ones can be carried, and they bring nothing but the name.
	var silver: int = gs.silver
	check(not gs.set_company_title("chiefs") and gs.company_title == "", "an unearned name can't be carried")
	check(gs.set_company_title("walls") and gs.company_title == "walls" and gs.silver == silver, "an earned name can be carried, and gives nothing else")

	# Saved and loaded.
	var gs2 = load("res://scripts/game_state.gd").new()
	gs2.persist = false
	gs2.from_dict(JSON.parse_string(JSON.stringify(gs.to_dict())))
	check(gs2.deeds.keys() == gs.deeds.keys() and gs2.company_title == "walls" and gs2.deed_counts == gs.deed_counts,
		"deeds, counts and the carried name survive a save and load")
	gs2.free()

	# The Warband screen.
	change_scene_to_file("res://scenes/main_menu.tscn")
	await process_frame
	await process_frame
	var screen = current_scene
	check(screen.find_child("DeedsPanel", true, false) != null, "the Warband lists the deeds")
	var title_label = screen.find_child("CompanyTitle", true, false)
	check(title_label != null and title_label.text.contains("Wallbreakers"), "and shows the name the company carries")
	var carry = screen.find_child("CarryTitle_jobs", true, false)
	carry.pressed.emit()
	await process_frame
	check(gs.company_title == "jobs", "a name can be chosen there")

	print("\nAchievement tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
