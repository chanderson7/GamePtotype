## Focused onboarding, persistence and menu-navigation regression checks.
## godot --headless --path . --script res://tests/menu_tests.gd
extends SceneTree
const State = preload("res://scripts/game_state.gd")
const Cultures = preload("res://scripts/data/cultures.gd")
var failures := 0
var gs
var scenes

func _init() -> void:
	_run.call_deferred()

func check(ok: bool, description: String) -> void:
	print("%s %s" % ["ok" if ok else "FAIL", description])
	if not ok:
		failures += 1

func _run() -> void:
	gs = root.get_node("GameState")
	scenes = root.get_node("Scenes")
	gs.persist = false
	var scratch := OS.get_environment("TMPDIR")
	if scratch == "":
		scratch = OS.get_environment("TEMP")
	if scratch == "":
		scratch = "/tmp"
	var sound = root.get_node("Sound")
	sound.settings_path = scratch.path_join("bannerfall-menu-test-%d.cfg" % OS.get_process_id())
	sound.set_music_on(true)
	sound.set_sounds_on(true)
	_check_bonds()
	gs.world = null
	await open("title")
	check(button("Continue campaign") == null and button("New campaign") != null, "fresh Home offers a new campaign without a false Continue")
	button("Learn to play").pressed.emit()
	await transition()
	check(current_scene.scene_file_path.ends_with("tutorial.tscn"), "Home opens the optional tutorial")
	button("Skip tutorial").pressed.emit()
	await transition()
	check(current_scene.scene_file_path.ends_with("title.tscn"), "skipping returns Home without starting a campaign")
	gs.new_campaign(Cultures.VARDISH)
	await open("title")
	check(button("Continue campaign") != null and button("Music: on") == null, "saved Home offers Continue and keeps audio in Settings")
	button("New campaign").pressed.emit()
	check(current_scene._confirmation.visible and gs.has_campaign(), "replacing a campaign requires an explicit confirmation")
	current_scene._confirmation.canceled.emit()
	current_scene._confirmation.hide()
	button("Settings").pressed.emit()
	await transition()
	check(current_scene.scene_file_path.ends_with("settings.tscn") and button("Music: on") != null, "Home opens the separate Settings page")
	root.get_node("Sound").mark_hint_seen("terrain", "woods")
	var music = button("Music: on")
	music.button_pressed = false
	check(not root.get_node("Sound").music_on and music.text == "Music: off", "audio toggle updates the setting and its visible state")
	check(root.get_node("Sound").has_seen_hint("terrain", "woods"), "audio changes preserve acknowledged hints")
	var config := ConfigFile.new()
	config.load(root.get_node("Sound").settings_path)
	check(not bool(config.get_value("audio", "music", true)), "audio preference is persisted to disk")
	music.button_pressed = true
	button("Open tutorial").pressed.emit()
	await transition()
	for step in 5:
		button("Next").pressed.emit()
		await process_frame
	check(button("Finish tutorial") != null, "tutorial has six short steps and a clear finish")
	button("Previous").pressed.emit()
	await process_frame
	check(current_scene.step == 4, "tutorial supports going back")
	button("Next").pressed.emit()
	await process_frame
	button("Finish tutorial").pressed.emit()
	await transition()
	check(current_scene.scene_file_path.ends_with("settings.tscn"), "finishing a replay returns to Settings")
	button("Back").pressed.emit()
	await transition()
	check(current_scene.scene_file_path.ends_with("title.tscn"), "Settings returns to its caller")
	await open("new_campaign")
	check(not current_scene._tutorial.button_pressed, "new-campaign tutorial is opt-in")
	current_scene._tutorial.button_pressed = true
	current_scene._on_pick(Cultures.RYUMON)
	await transition()
	check(current_scene.scene_file_path.ends_with("tutorial.tscn") and gs.culture == Cultures.RYUMON, "opting in starts the selected campaign then opens the tutorial")
	button("Skip tutorial").pressed.emit()
	await transition()
	check(current_scene.scene_file_path.ends_with("world_map.tscn"), "skipping onboarding continues to the map")
	gs.world.wait(12.0)
	current_scene._on_menu()
	var hour: float = gs.world.hour
	await create_timer(0.2).timeout
	check(gs.world.hour == hour, "campaign menu pauses ongoing travel or waiting")
	current_scene._on_settings()
	await transition()
	hour = gs.world.hour
	await create_timer(0.2).timeout
	check(gs.world.hour == hour, "Settings does not advance the campaign")
	button("Back").pressed.emit()
	await transition()
	check(current_scene.scene_file_path.ends_with("world_map.tscn"), "map Settings returns to the map")
	check(current_scene.resource_buttons.size() == 3 and current_scene.resource_buttons["silver"].icon != null,
		"silver, food and renown have labeled icon controls in the HUD")
	current_scene._open_resource("food")
	check(current_scene.sheet_title.text == "Food" and current_scene.sheet_body.text.contains("rations"), "resource icons explain their values when tapped")
	current_scene._close_sheet()
	gs.food = 0
	gs.silver = 0
	var previous_men: int = gs.total_men()
	gs.world.hour = (int(gs.world.hour / 24.0) + 1) * 24.0
	gs.settle()
	await process_frame
	await process_frame
	check(gs.total_men() < previous_men and current_scene._sheet == "warning", "desertion displays an explicit warning")
	check(current_scene.sheet_body.text.contains("unpaid and hungry") and current_scene.sheet_body.text.contains("Buy food") and current_scene.sheet_body.text.contains("Earn silver"), "warning explains losses, both causes and both remedies")
	hour = gs.world.hour
	await create_timer(0.2).timeout
	check(gs.world.hour == hour, "desertion warning pauses ongoing travel or waiting")
	current_scene._on_menu()
	check(current_scene._sheet == "warning", "map menu cannot hide an unread desertion warning")
	var reload := State.new()
	reload.persist = false
	reload.from_dict(JSON.parse_string(JSON.stringify(gs.to_dict())))
	check(reload.desertion_warning == gs.desertion_warning, "desertion warning survives a reload")
	reload.free()
	button("Understood").pressed.emit()
	check(gs.desertion_warning == "" and not gs.map_notice.contains("men left"), "acknowledgment clears the warning without repeating it")
	gs.food = gs.total_men() * 5
	gs.silver = 400
	gs.bond_intro_seen = false
	gs.bond_intro_pair = "Brann & Hideo"
	await open("world_map")
	await transition()
	check(current_scene.scene_file_path.ends_with("bond_intro.tscn"), "a pending first bond opens its introduction on return to the map")
	hour = gs.world.hour
	await create_timer(0.2).timeout
	check(gs.world.hour == hour and gs.bond_intro_pending(), "the introduction pauses time and waits for acknowledgment")
	button("View my warband").pressed.emit()
	await transition()
	check(current_scene.scene_file_path.ends_with("main_menu.tscn") and gs.bond_intro_seen, "viewing bonds acknowledges the introduction and opens Warband")
	check(button("Music: on") == null, "Warband no longer houses audio settings")
	DirAccess.remove_absolute(sound.settings_path)
	print("Menu failures: %d" % failures)
	quit(1 if failures else 0)

func _check_bonds() -> void:
	var state := State.new()
	state.persist = false
	state.new_campaign(Cultures.VARDISH)
	var a: Dictionary = state.army[0]["captain"]
	var b: Dictionary = state.army[1]["captain"]
	a["quirk"] = ""
	b["quirk"] = ""
	var key := "%d|%d" % [a["id"], b["id"]]
	var result := {"won": true, "squads": {}, "bonds": {key: 20.0}}
	state.apply_result(result)
	check(not state.bond_intro_pending(), "no introduction below rank C")
	result["bonds"][key] = 40.0
	state.apply_result(result)
	check(state.bond_intro_pending() and state.bond_intro_pair.contains(a["name"]), "crossing rank C queues an introduction naming the pair")
	var loaded := State.new()
	loaded.persist = false
	loaded.from_dict(JSON.parse_string(JSON.stringify(state.to_dict())))
	check(loaded.bond_intro_pending(), "unread introduction survives saving and loading")
	loaded.acknowledge_bond_intro()
	loaded.apply_result(result)
	check(not loaded.bond_intro_pending(), "higher ranks do not repeat an acknowledged introduction")
	state.from_dict(loaded.to_dict())
	check(state.bond_intro_seen and not state.bond_intro_pending(), "acknowledgment survives saving and loading")
	var legacy := loaded.to_dict()
	legacy.erase("bond_intro_seen")
	legacy.erase("bond_intro_pair")
	state.from_dict(legacy)
	check(state.bond_intro_seen, "older campaigns with existing bonds are not interrupted retroactively")
	state.new_campaign(Cultures.KHARZANI)
	check(not state.bond_intro_seen and not state.bond_intro_pending(), "a new campaign resets bond onboarding")
	# A pair lost in this battle should not be introduced as living partners.
	a = state.army[0]["captain"]
	b = state.army[1]["captain"]
	key = "%d|%d" % [a["id"], b["id"]]
	result = {"won": false, "bonds": {key: 60.0}, "squads": {
		state.army[0]["id"]: {"men": 0, "kills": 0, "captain": {"fate": "killed", "kills": 0, "roll": 1, "needed": 45}}}}
	state.apply_result(result)
	check(not state.bond_intro_pending(), "a captain killed in the same battle does not trigger the living-pair introduction")
	state.free()
	loaded.free()

func open(scene: String) -> void:
	change_scene_to_file("res://scenes/%s.tscn" % scene)
	await process_frame
	await process_frame
	await process_frame
	_check_width(current_scene)

func transition() -> void:
	await create_timer(0.7).timeout
	_check_width(current_scene)

func button(text: String) -> Button:
	return _button_in(current_scene, text)

func _button_in(node: Node, text: String) -> Button:
	if node is Button and node.text == text:
		return node
	for child in node.get_children():
		var found := _button_in(child, text)
		if found != null:
			return found
	return null

func _check_width(node: Node) -> void:
	if node is Control and node.is_visible_in_tree() and (node is Button or node is Label):
		var rect: Rect2 = node.get_global_rect()
		if rect.position.x < -1 or rect.end.x > root.get_visible_rect().size.x + 1:
			check(false, "horizontal overflow: %s (%s)" % [node.text, rect])
	for child in node.get_children():
		_check_width(child)
