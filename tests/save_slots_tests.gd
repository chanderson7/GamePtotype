## Saving your own, the saves the game keeps for you, going back, and Ironman; an index
## rebuilt from the files, saves from a newer version left alone, and an autosave that
## won't load never costing the other saves.
extends SceneTree

const SaveSlots = preload("res://scripts/save_slots.gd")
const GameStateScript = preload("res://scripts/game_state.gd")
const Data = preload("res://scripts/world/world_data.gd")

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


func _find(node: Node, wanted: String) -> Node:
	if node.name == wanted:
		return node
	for c in node.get_children():
		var f := _find(c, wanted)
		if f != null:
			return f
	return null


func _button(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text:
		return node
	for c in node.get_children():
		var f := _button(c, text)
		if f != null:
			return f
	return null


func _init() -> void:
	await process_frame
	gs = root.get_node("GameState")
	gs.persist = false
	SaveSlots.dir = "user://test_saves_%d" % Time.get_ticks_usec()
	gs.new_campaign("vardish")
	var w = gs.world

	# ---- your own saves
	var first: Dictionary = SaveSlots.save_own(gs)
	check(not first.is_empty() and SaveSlots.own().size() == 1, "Save game keeps a save of your own")
	check(String(first["name"]).begins_with("Day 1 · "), "named after the day and place: " + String(first["name"]))
	var then: Dictionary = first["summary"]
	check(int(then["silver"]) == gs.silver and int(then["men"]) == gs.total_men() and not then["scene"].is_empty(),
		"its summary holds your silver, men and the place's scene")

	# What happens after it: time passes, a fight is won, silver earned, a captain falls.
	var silver0: int = gs.silver
	var hour0: float = w.hour
	w.hour += 41.0
	gs.silver += 200
	gs.battles += 1
	gs.wins += 1
	var lost := {}
	for e in gs.army:
		if typeof(e.get("captain")) == TYPE_DICTIONARY:
			lost = e["captain"]
			e.erase("captain")
			break
	if not lost.is_empty():
		gs.fallen.append({"id": int(lost["id"]), "name": lost["name"], "first": lost["first"]})
	var diff := SaveSlots.changes(then, SaveSlots.summary(gs))
	var undone := " / ".join(diff["undone"].map(func(u): return String(u[1])))
	check(diff["rows"][2][1] == str(silver0 + 200) and diff["rows"][2][2] == str(silver0), "going back shows silver now and then")
	check(undone.contains("1 day 17 hours") and undone.contains("A battle (won)"), "and what it undoes: " + undone)
	check(lost.is_empty() or (diff["back"].size() == 1 and String(diff["back"][0]["text"]).contains("fallen")),
		"and the captain who'd be back with you")

	check(SaveSlots.load_into(gs, String(first["id"])), "a save loads")
	check(gs.silver == silver0 and is_equal_approx(gs.world.hour, hour0) and gs.battles == 0, "and the campaign is as it was")
	check(lost.is_empty() or gs.fallen.is_empty(), "with the fallen captain back")
	w = gs.world

	# ---- eight spaces, rename, save over, delete
	for i in 7:
		SaveSlots.save_own(gs)
	check(SaveSlots.spaces_left() == 0 and SaveSlots.save_own(gs).is_empty(), "eight saves of your own, and no ninth")
	var some: Dictionary = SaveSlots.own()[3]
	check(SaveSlots.rename(String(some["id"]), "Before the march"), "a save can be renamed")
	gs.silver = 999
	var over := SaveSlots.overwrite(gs, String(some["id"]))
	check(String(over.get("name", "")) == "Before the march" and int(over["summary"]["silver"]) == 999, "saving over one keeps its name")
	check(SaveSlots.delete(String(some["id"])) and SaveSlots.spaces_left() == 1, "and one can be deleted")

	# ---- the saves the game keeps for you
	gs.pending_battle = {"name": "Ash Hill brigands"}
	gs.save_before_battle()
	gs.pending_battle = {}
	var place := String(w.player().node)
	gs.save_on_arrival(place)
	var kept := SaveSlots.automatic()
	check(kept.size() == 2, "a save before battle and one on entering a settlement")
	check(String(SaveSlots.latest()["kind"]) == SaveSlots.ARRIVAL and String(SaveSlots.latest()["name"]).contains(String(Data.settlement(place)["name"])),
		"Revert goes to the newest: " + String(SaveSlots.latest()["name"]))
	gs.save_before_battle()
	check(SaveSlots.automatic().size() == 2, "each is replaced by the next, not added to")

	# ---- screens
	var map = await _open("res://scenes/world_map.tscn")
	map._on_menu()
	await process_frame
	check(_button(map, "Save game") != null and _button(map, "Revert") != null and _find(map, "LastSave") != null,
		"the campaign menu has Save game, Revert and the last save")
	check(_find(map, "MenuNextStep") != null and _find(map, "Menu_Warband") != null and _find(map, "Menu_Journal") != null
		and _find(map, "Menu_People") != null and _find(map, "Menu_War") != null and _find(map, "CloseMenu") != null,
		"and big cards for Next step, Warband, Journal, People and War, with an ✕ to close")
	(_find(map, "CloseMenu") as Button).pressed.emit()
	check(map._sheet == "", "the ✕ closes it")
	var title = await _open("res://scenes/title.tscn")
	var load_button := _find(title, "LoadSave") as Button
	check(load_button != null and load_button.text.ends_with("· %d" % SaveSlots.list().size()), "Home offers Load a save")
	var saves = await _open("res://scenes/saves.tscn")
	check(_find(saves, "RightNow") != null, "the saves screen shows where you are now")
	check(_find(saves, "WhereSavesLive") != null, "and says where the saves live")
	var target: Dictionary = SaveSlots.own()[0]
	var row := _find(saves, "Save_" + String(target["id"])) as Button
	check(row != null, "and each save as a row")
	gs.silver = 12345
	row.pressed.emit()
	await process_frame
	check(_find(saves, "GoBack") != null and _find(saves, "Compare") != null, "tapping one asks first, showing what changes")
	var then_silver := _find(saves, "Then_Silver") as Label
	check(then_silver != null and then_silver.text.begins_with("▼ "), "less silver then is marked ▼, not by colour alone")
	(_find(saves, "GoBack") as Button).pressed.emit()
	await process_frame
	check(gs.silver == int(target["summary"]["silver"]), "Go back loads it")
	for i in 30:
		await process_frame

	# ---- Ironman
	gs.ironman = true
	check(SaveSlots.save_own(gs).is_empty(), "Ironman has no saves of your own")
	var before := SaveSlots.list().size()
	gs.pending_battle = {"name": "x"}
	gs.save_before_battle()
	gs.pending_battle = {}
	check(SaveSlots.list().size() == before, "nor any kept for you")
	map = await _open("res://scenes/world_map.tscn")
	map._on_menu()
	await process_frame
	check(_button(map, "Save game") == null and _button(map, "Revert") == null, "and its menu offers neither")
	title = await _open("res://scenes/title.tscn")
	check(_find(title, "LoadSave") == null and _find(title, "IronmanNote") != null, "Home says it's Ironman")
	check(bool(gs.to_dict()["ironman"]), "Ironman is kept in the save")
	var nc = await _open("res://scenes/new_campaign.tscn")
	check(_find(nc, "IronmanSwitch") != null, "a new campaign can be Ironman")
	gs.ironman = false

	# ---- a damaged or missing index is rebuilt from the save files
	var slot_count := SaveSlots.list().size()
	var slot_names: Array = SaveSlots.list().map(func(x): return String(x["name"]))
	var index_file := FileAccess.open(SaveSlots.dir + "/index.json", FileAccess.WRITE)
	index_file.store_string("[{\"id\": \"own_")
	index_file.close()
	var rebuilt := SaveSlots.list()
	check(rebuilt.size() == slot_count and rebuilt.map(func(x): return String(x["name"])) == slot_names,
		"a damaged index is rebuilt from the save files, names and all")
	check(not FileAccess.file_exists(SaveSlots.dir + "/index.json.tmp") and typeof(JSON.parse_string(FileAccess.get_file_as_string(SaveSlots.dir + "/index.json"))) == TYPE_ARRAY,
		"and written back whole")
	DirAccess.remove_absolute(SaveSlots.dir + "/index.json")
	check(SaveSlots.list().size() == slot_count, "a missing index is rebuilt too")
	var legacy_file := FileAccess.open(SaveSlots.dir + "/own_legacy.json", FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify(gs.to_dict()))
	legacy_file.close()
	DirAccess.remove_absolute(SaveSlots.dir + "/index.json")
	var old_one := SaveSlots.entry("own_legacy")
	check(not old_one.is_empty() and String(old_one["kind"]) == SaveSlots.OWN and int(old_one["summary"]["men"]) == gs.total_men()
		and int(old_one["summary"]["silver"]) == gs.silver, "a save file from before files carried their entry is listed from its campaign")
	SaveSlots.delete("own_legacy")

	# ---- a save from a newer version is shown, never loaded, and left as it is
	gs.ironman = false
	if SaveSlots.spaces_left() == 0:
		SaveSlots.delete(String(SaveSlots.own()[0]["id"]))
	var future: Dictionary = SaveSlots.save_own(gs, "From a newer build")
	var future_path := SaveSlots.dir + "/" + String(future["id"]) + ".json"
	var future_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(future_path))
	future_data["version"] = GameStateScript.SAVE_VERSION + 1
	future_data["slot"]["version"] = GameStateScript.SAVE_VERSION + 1
	var future_text := JSON.stringify(future_data)
	var future_file := FileAccess.open(future_path, FileAccess.WRITE)
	future_file.store_string(future_text)
	future_file.close()
	DirAccess.remove_absolute(SaveSlots.dir + "/index.json")
	var silver_now: int = gs.silver + 7
	gs.silver = silver_now
	check(not SaveSlots.load_into(gs, String(future["id"])), "a save from a newer version won't load")
	check(gs.silver == silver_now and FileAccess.get_file_as_string(future_path) == future_text, "and neither the campaign nor the file is touched")
	saves = await _open("res://scenes/saves.tscn")
	var future_row := _find(saves, "Save_" + String(future["id"])) as Button
	check(future_row != null and future_row.disabled and _find(future_row, "NewerVersion") != null, "the list shows it greyed, saying why")

	# ---- saving over one of your own takes a second tap, as Delete does
	var mine: Dictionary = {}
	for own_save in SaveSlots.own():
		if String(own_save["id"]) != String(future["id"]):
			mine = own_save
	saves._options(mine)
	await process_frame
	var over_button := _find(saves, "Overwrite") as Button
	gs.silver = 4321
	over_button.pressed.emit()
	check(int(SaveSlots.entry(String(mine["id"]))["summary"]["silver"]) != 4321 and over_button.text == "Tap again to save over",
		"the first tap on Save over it only asks again")
	over_button.pressed.emit()
	check(int(SaveSlots.entry(String(mine["id"]))["summary"]["silver"]) == 4321, "the second saves over it")
	for i in 10:
		await process_frame

	# ---- the autosave: a damaged one is kept aside, a newer one left alone
	var keep_world = gs.world
	gs.save_path = SaveSlots.dir + "_autosave.json"
	var auto_file := FileAccess.open(gs.save_path, FileAccess.WRITE)
	auto_file.store_string("{\"version\": 6, \"army\": [")
	auto_file.close()
	check(not gs.load_game() and gs.load_problem == "unreadable", "a damaged autosave doesn't load, and says so")
	check(not FileAccess.file_exists(gs.save_path) and FileAccess.file_exists(gs.save_path + ".bad"), "and is kept aside as .bad, not written over")
	future_data.erase("slot")
	auto_file = FileAccess.open(gs.save_path, FileAccess.WRITE)
	auto_file.store_string(JSON.stringify(future_data))
	auto_file.close()
	check(not gs.load_game() and gs.load_problem == "newer" and FileAccess.file_exists(gs.save_path), "an autosave from a newer version is refused and left in place")

	# ---- Home with no campaign but saves left: Load a save, and starting over asks first
	gs.world = null
	gs.load_problem = "unreadable"
	title = await _open("res://scenes/title.tscn")
	check(_find(title, "StrandedCard") != null and _find(title, "LoadSave") != null and _find(title, "BeginButton") == null,
		"Home says the autosave couldn't be read and offers Load a save")
	var slots_before := SaveSlots.list().size()
	_button(title, "New campaign").pressed.emit()
	await process_frame
	check(_find(title, "NewCampaignSheet") != null and SaveSlots.list().size() == slots_before, "New campaign asks first, and nothing is deleted yet")
	gs.world = keep_world
	gs.load_problem = ""
	DirAccess.remove_absolute(gs.save_path)
	DirAccess.remove_absolute(gs.save_path + ".bad")
	gs.save_path = GameStateScript.SAVE_PATH

	# ---- a new campaign starts clean
	gs.new_campaign("kharzani")
	check(SaveSlots.list().is_empty() and not gs.ironman, "a new campaign leaves the last one's saves behind")

	SaveSlots.clear()
	DirAccess.remove_absolute(SaveSlots.dir)
	print("FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)
