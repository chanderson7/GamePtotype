## Saves from before the journal, deeds, sieges and the crown (made by the game as it was
## at 77fbade) still load, show every screen and play on.
extends SceneTree

const FIXTURE := "res://tests/fixtures/save_2026-10-31_pre_journal.json"

var gs
var failures := 0


func check(ok: bool, message: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + message)
	if not ok:
		failures += 1


func _open(path: String) -> Node:
	change_scene_to_file(path)
	await process_frame
	await process_frame
	return current_scene


func _init() -> void:
	await process_frame
	gs = root.get_node("GameState")
	gs.persist = false
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	gs.from_dict(raw)
	var w = gs.world
	check(w != null and int(w.hour / 24.0) == 12 and gs.total_men() == int(_men(raw)), "an old save loads with its day and its men")
	check(gs.silver == int(raw["silver"]) and gs.army.size() == raw["army"].size(), "its purse and companies are as they were")
	check(gs.active_jobs.size() == raw.get("active_jobs", []).size(), "its jobs carry over")
	check(gs.deeds.is_empty() and gs.company_title == "" and gs.camp_seen.is_empty() and gs.pinned_commitment == "",
		"new features start empty")
	check(not gs.is_crowned() and w.alliances.is_empty() and w.pending_assault.is_empty(), "and no crown, alliances or assault calls appear")
	check(gs.commitments().size() == gs.active_jobs.size() + (1 if gs.has_contract() else 0) + gs.captive_lords().size(),
		"the journal lists what the save was committed to")

	gs.map_notice = ""
	for path in ["res://scenes/world_map.tscn", "res://scenes/main_menu.tscn", "res://scenes/people.tscn", "res://scenes/title.tscn"]:
		var scene = await _open(path)
		check(scene != null and scene.scene_file_path == path, "%s opens with the old save" % path.get_file())

	var guard := 0
	var start: float = w.hour
	while w.hour - start < 240.0 and guard < 2000:
		guard += 1
		if w.encounter != -1:
			var foe = w.party(w.encounter)
			if foe != null:
				foe.grace_until = w.hour + 24.0
			w.encounter = -1
		if not w.pending_assault.is_empty():
			gs.answer_assault(false)
		if not w.busy():
			w.wait(12.0)
		gs.advance(1.0)
	check(w.hour - start >= 240.0, "it plays on for ten more days")
	var once := JSON.stringify(gs.to_dict())
	var gs2 = load("res://scripts/game_state.gd").new()
	gs2.persist = false
	gs2.from_dict(JSON.parse_string(once))
	check(_same(JSON.parse_string(once), JSON.parse_string(JSON.stringify(gs2.to_dict()))),
		"and saves and loads back in the new format (to JSON's float precision)")
	gs2.free()

	# A save from a newer build is refused before anything changes, so it can't be loaded
	# lossy and saved over.
	var gs3 = load("res://scripts/game_state.gd").new()
	gs3.persist = false
	var newer: Dictionary = JSON.parse_string(once)
	newer["version"] = int(newer["version"]) + 1
	check(not gs3.from_dict(newer) and gs3.load_problem == "newer" and gs3.world == null,
		"a save from a newer version is refused, and nothing is loaded")
	check(gs3.from_dict(JSON.parse_string(once)) and gs3.load_problem == "" and gs3.world != null, "while one from this version loads")
	gs3.free()

	print("\nSave compatibility tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)


## Equal, allowing for the last digits JSON can't carry for some floats.
func _same(a, b) -> bool:
	if (typeof(a) == TYPE_FLOAT or typeof(a) == TYPE_INT) and (typeof(b) == TYPE_FLOAT or typeof(b) == TYPE_INT):
		return absf(float(a) - float(b)) <= 1e-6 * maxf(1.0, absf(float(a)))
	if typeof(a) != typeof(b):
		return false
	if a is Dictionary:
		if a.size() != b.size():
			return false
		for k in a:
			if not b.has(k) or not _same(a[k], b[k]):
				return false
		return true
	if a is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not _same(a[i], b[i]):
				return false
		return true
	return a == b


func _men(raw: Dictionary) -> int:
	var n := 0
	for s in raw["army"]:
		n += int(s.get("men", 0))
	return n
