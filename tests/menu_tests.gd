## Focused onboarding, persistence and menu-navigation regression checks.
## godot --headless --path . --script res://tests/menu_tests.gd
extends SceneTree
const State = preload("res://scripts/game_state.gd")
const Cultures = preload("res://scripts/data/cultures.gd")
const SaveSlots = preload("res://scripts/save_slots.gd")
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
	# Saves of the machine's own campaigns must not change what a fresh Home shows.
	SaveSlots.dir = "user://menu_test_saves_%d" % OS.get_process_id()
	sound.set_music_on(true)
	sound.set_sounds_on(true)
	sound.set_illustrations(true)
	_check_bonds()
	gs.world = null
	gs.load_problem = ""
	await open("title")
	check(button("Continue") == null and button("Begin as the Vardish") != null, "fresh Home offers the three peoples without a false Continue")
	var first_learn = current_scene.find_child("FirstLearn", true, false)
	check(first_learn != null and _button_in(first_learn, "Learn to play") != null
		and _button_in(current_scene.find_child("MinorButtons", true, false), "Learn to play") == null,
		"first-time Home puts Learn to play up top, by the peoples, not in the bottom row")
	current_scene.find_child("People_kharzani", true, false).pressed.emit()
	check(button("Begin as the Kharzani") != null, "picking a people on Home names it on the big button")
	button("Begin as the Kharzani").pressed.emit()
	await transition()
	check(current_scene.scene_file_path.ends_with("new_campaign.tscn") and current_scene.find_child("PickedPeople", true, false) != null,
		"and the new-campaign screen opens with that people first")
	check(current_scene._tutorial.button_pressed, "a first campaign on this device starts with the tutorial on")
	var more_body = current_scene.find_child("MoreOptionsBody", true, false)
	check(more_body != null and not more_body.visible and more_body.find_child("IronmanSwitch", true, false) != null
		and more_body.find_child("ModeChoice", true, false) != null,
		"Mortal or Casual and Ironman wait folded under More options")
	current_scene._toggle_more()
	check(more_body.visible and button("Fewer options") != null, "and open with a tap")
	await open("title")
	button("Learn to play").pressed.emit()
	await transition()
	check(current_scene.scene_file_path.ends_with("tutorial.tscn"), "Home opens the optional tutorial")
	button("Skip tutorial").pressed.emit()
	await transition()
	check(current_scene.scene_file_path.ends_with("title.tscn"), "skipping returns Home without starting a campaign")
	gs.new_campaign(Cultures.VARDISH)
	await open("title")
	check(button("Continue") != null and button("Music: on") == null, "saved Home offers Continue and keeps audio in Settings")
	check(current_scene.find_child("CampaignCard", true, false) != null and current_scene.find_child("CaptainFaces", true, false) != null,
		"saved Home shows the company on a card with its captains")
	check(current_scene.find_child("CompanyBanner", true, false) != null, "and under its realm's banner")
	check(current_scene.find_child("HomeCampIllustration", true, false) != null, "saved Home shows the company camp")
	check(current_scene.find_child("NextStepPanel", true, false) != null and _has_text(current_scene, "Next step"),
		"Home shows one recommendation from the current campaign")
	gs.apply_social_choice("edda", "know_better")
	# Her letter comes a day on.
	gs.world.hour += 24.0
	gs.world.social.step(0.0, gs.world)
	await open("title")
	var letters_row = current_scene.find_child("WaitLetters", true, false)
	check(letters_row != null and _has_text(letters_row, "invited you"), "Home lists an unread letter under Waiting for you")
	letters_row.pressed.emit()
	await transition()
	check(current_scene.scene_file_path.ends_with("people.tscn") and current_scene.find_child("Parchment", true, false) != null,
		"and tapping it opens the letter")
	await open("title")
	button("New campaign").pressed.emit()
	check(current_scene.find_child("NewCampaignSheet", true, false) != null and gs.has_campaign(), "replacing a campaign requires an explicit confirmation")
	button("Keep my campaign").pressed.emit()
	await process_frame
	check(current_scene.find_child("NewCampaignSheet", true, false) == null and gs.has_campaign(), "and keeping it closes the sheet")
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
	check(not FileAccess.file_exists(root.get_node("Sound").settings_path + ".tmp"), "and written whole, with no temporary file left behind")
	music.button_pressed = true
	# The whole row is the switch's target, and the switch itself is a full touch target.
	var music_row := current_scene.find_child("Setting_Music", true, false) as Control
	check(music.custom_minimum_size.y >= 80.0 and music_row != null, "a settings switch is a full touch target")
	var on_words := music_row.get_global_rect().position + Vector2(40.0, music_row.size.y * 0.5)
	_tap_at(on_words)
	check(not root.get_node("Sound").music_on and music.text == "Music: off", "a tap on a setting's words flips its switch")
	_tap_at(on_words)
	check(root.get_node("Sound").music_on, "and another flips it back")
	var motion_title := current_scene.find_child("Setting_Reducedmotion", true, false).find_children("*", "Label", true, false)[0] as Label
	check(motion_title.autowrap_mode != TextServer.AUTOWRAP_OFF, "a setting's name wraps at large text")
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
	check(not current_scene._tutorial.button_pressed, "once a campaign is under way (or the lessons were opened), the tutorial switch starts off")
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
	check(current_scene.resource_buttons.size() == 4 and current_scene.resource_buttons["silver"].icon != null
		and current_scene.resource_buttons["men"].icon != null,
		"men, silver, food and renown have labeled icon controls in the HUD")
	check(current_scene.find_child("NextStepButton", true, false) == null, "the top bar carries no goal chip")
	current_scene._close_sheet()
	current_scene._on_menu()
	check(button("Next step") != null, "the next step is one tap away in the menu")
	current_scene._close_sheet()
	# Escape (and a phone's back, which arrives as Escape) opens the menu on the bare map,
	# and closes it again.
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	current_scene._unhandled_key_input(esc)
	check(current_scene._sheet == "menu", "Escape on the bare map opens the campaign menu")
	current_scene._unhandled_key_input(esc)
	check(current_scene._sheet == "", "and Escape again closes it")
	gs.world.wait(6.0)
	current_scene._on_time(0.0)
	var held: float = gs.world.hour
	await create_timer(0.3).timeout
	check(gs.world.hour == held, "pause holds the clock while waiting")
	current_scene._on_time(2.0)
	await create_timer(0.3).timeout
	check(gs.world.hour > held and current_scene.speed == 2.0, "fast resumes it at double speed")
	current_scene._on_time(1.0)
	gs.world.player().wait = 0.0
	current_scene._open_resource("food")
	check(current_scene.sheet_title.text == "Food" and current_scene.sheet_body.text.contains("rations"), "resource icons explain their values when tapped")
	current_scene._close_sheet()
	current_scene._open_preview("highcliff")
	var extra = current_scene.sheet_extra
	check(extra.find_child("SheetHeader", true, false) != null and _has_text(extra, "Kingdom of Vardmark") and extra.find_child("RideTime", true, false) != null
		and not _has_text(extra, "Why it matters:") and current_scene.sheet_body.text == "",
		"settlement preview stays brief: what it is, who holds it and how far (the details wait inside)")
	current_scene._close_sheet()
	gs.world.emit_event({"type": "fight", "winner": "King Aldwin", "loser": "a raiding band", "at": "highcliff"})
	current_scene._open_activity()
	check(_has_text(current_scene.sheet_extra, "King Aldwin defeated") and current_scene.sheet_extra.find_child("Stat_day", true, false) != null,
		"activity feed reports battles with a campaign date")
	var chronicle_reload := State.new()
	chronicle_reload.persist = false
	chronicle_reload.from_dict(JSON.parse_string(JSON.stringify(gs.to_dict())))
	check(not chronicle_reload.world.activity_log.is_empty() and chronicle_reload.world.activity_log[0]["text"].contains("King Aldwin"),
		"activity feed survives saving and loading")
	chronicle_reload.free()
	current_scene._close_sheet()
	var food_before: int = int(gs.food)
	gs.food = 0
	current_scene._open_recommendation()
	check(current_scene.sheet_title.text == "Buy provisions" and current_scene.sheet_body.text.contains("Villages"),
		"next-step guidance responds to actual low food")
	gs.food = food_before
	current_scene._close_sheet()
	# Before the first fight, the next step is a band, and Show on map opens its sheet.
	if gs.battles == 0:
		current_scene._open_recommendation()
		var show_band = current_scene.sheet_row.find_child("Dock_Showonmap", true, false)
		check(current_scene.sheet_title.text.begins_with("Hunt the") and show_band != null,
			"a new company's next step names the nearest band, with Show on map")
		if show_band != null:
			show_band.pressed.emit()
			check(current_scene._sheet == "band", "which opens that band's own sheet")
		current_scene._close_sheet()
	# Wait says what it costs.
	if gs.world.here() != "":
		current_scene._open_here()
		check(current_scene.sheet_row.find_child("Dock_Wait8h", true, false) != null, "Wait says it takes 8 hours")
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
	check(current_scene.sheet_body.text.contains("contract"), "and names contracts, the silver that needs no victory")
	check(_has_text(current_scene.status_chips, "Food short") and _has_text(current_scene.status_chips, "Can't pay"),
		"the low-supply chips say what's wrong in two words")
	check(current_scene.resource_buttons["food"].text.ends_with("d"), "the food pill counts in days")
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
	var bond_a: Dictionary = gs.army[0]["captain"]
	var bond_b: Dictionary = gs.army[1]["captain"]
	bond_a["bonds"][str(bond_b["id"])] = 6.0
	bond_b["bonds"][str(bond_a["id"])] = 6.0
	var live_key := "%d|%d" % [mini(bond_a["id"], bond_b["id"]), maxi(bond_a["id"], bond_b["id"])]
	gs.bond_records[live_key] = {"shared_battles": 1, "last_battle": gs.battles, "last_outcome": "victory",
		"last_losses": 2, "milestones": ["C"], "conversations": [], "losses": []}
	bond_b["wounded"] = 1
	gs.bond_intro_pair = "%s & %s" % [bond_a["name"], bond_b["name"]]
	gs.bond_intro_ids = [bond_a["id"], bond_b["id"]]
	await open("world_map")
	await transition()
	check(current_scene.scene_file_path.ends_with("bond_intro.tscn"), "a pending first bond opens its introduction on return to the map")
	check(current_scene.find_child("BondPortraits", true, false) != null, "rank C introduction shows the two captains")
	hour = gs.world.hour
	await create_timer(0.2).timeout
	check(gs.world.hour == hour and gs.bond_intro_pending(), "the introduction pauses time and waits for acknowledgment")
	button("View my warband").pressed.emit()
	await transition()
	check(current_scene.scene_file_path.ends_with("main_menu.tscn") and gs.bond_intro_seen, "viewing bonds acknowledges the introduction and opens Warband")
	var way_back = scenes._back_button(current_scene)
	check(way_back != null and way_back.name == "BackButton", "Escape and a phone's back find the Warband's way to the map")
	check(current_scene.find_child("WarbandCampIllustration", true, false) != null and current_scene.find_children("CaptainPortrait", "TextureRect", true, false).size() >= gs.army.size(),
		"Warband combines the camp header with stable captain portraits")
	check(current_scene.find_child("CompanyBanner", true, false) != null and current_scene.find_child("WarbandSort", true, false) != null,
		"Warband shows the company banner and selectable roster sorting")
	var pay = current_scene.find_child("NextPayCard", true, false)
	check(pay != null and pay.find_child("Pay_silver", true, false) != null and pay.find_child("Pay_food", true, false) != null,
		"Warband forecasts the next wage and food payment")
	check(_has_text(current_scene, "Active companies") and _has_text(current_scene, "Wounded captains"),
		"active and wounded companies are visually separated")
	check(current_scene.find_children("WarbandMeter", "", true, false).size() >= gs.army.size()
		and current_scene.find_children("LevelPips", "", true, false).size() >= gs.army.size(),
		"each company shows its strength and its level")
	check(current_scene.find_children("CaptainAndTroopArt", "", true, false).size() == gs.army.size(),
		"captain portraits keep their tactical troop icons on a badge")
	check(button("Music: on") == null, "Warband no longer houses audio settings")
	var sort = current_scene.find_child("WarbandSort", true, false)
	sort.find_child("Tab_4", true, false).pressed.emit()
	await process_frame
	await process_frame
	check(scenes.warband_sort == 4 and int(current_scene.find_child("WarbandSort", true, false).get_meta("picked", -1)) == 4,
		"Warband remembers the selected captain-name sort")
	var bonds_tab_button := current_scene.find_child("Tab_bonds", true, false) as Button
	check(bonds_tab_button != null and bonds_tab_button.text.ends_with("1"), "the Bonds tab says a talk waits at the fire")
	current_scene._on_tab("bonds")
	await process_frame
	var talks: Array = current_scene.find_children("BondConversation_*", "Button", true, false)
	var camp_talk: Button = talks[0] if not talks.is_empty() else null
	check(camp_talk != null and camp_talk.find_child("NewDot", true, false).visible
		and current_scene.find_child("SharedBattles", true, false) != null and current_scene.find_child("BondMorale", true, false) != null,
		"bond cards show shared history, exact effects and optional conversation")
	camp_talk.pressed.emit()
	await transition()
	check(current_scene.scene_file_path.ends_with("bond_conversation.tscn") and current_scene.find_child("BondConversationPortraits", true, false) != null,
		"the optional bond conversation presents the paired captains")
	check(_has_text(current_scene, "1 battle") and _has_text(current_scene, "last shared fight") and not _has_text(current_scene, "battle values"),
		"bond dialogue uses campaign facts, with no note about game rules")
	current_scene.choose("back")
	await transition()
	talks = current_scene.find_children("BondConversation_*", "Button", true, false)
	check(current_scene.scene_file_path.ends_with("main_menu.tscn") and not talks.is_empty()
		and not talks[0].find_child("NewDot", true, false).visible,
		"returning to Warband clears only the conversation's new marker")
	var profiled: Dictionary = gs.army[0]["captain"]
	var profile_button: Button = current_scene.find_child("CaptainProfile_%d" % int(profiled["id"]), true, false)
	check(profile_button != null, "the whole captain card is an available profile touch target")
	current_scene._scroll.scroll_vertical = 220
	await process_frame
	var remembered_scroll: int = current_scene._scroll.scroll_vertical
	profile_button.pressed.emit()
	await transition()
	check(current_scene.scene_file_path.ends_with("captain_profile.tscn") and _has_text(current_scene, String(profiled["name"])),
		"captain profile carries identity from the Warband roster")
	check(_has_text(current_scene, "Campaign record") and _has_text(current_scene, "Company progress"),
		"captain profile presents traits, record, progression and bonds")
	check(current_scene.find_child("BackButton", true, false) != null and current_scene.find_child("RecordCard", true, false) != null,
		"captain profile pins Back and shows the record as tiles")
	await _check_promotion(profiled)
	(current_scene.find_child("BackButton", true, false) as Button).pressed.emit()
	await transition()
	await process_frame
	check(current_scene.scene_file_path.ends_with("main_menu.tscn") and current_scene._scroll.scroll_vertical == remembered_scroll,
		"captain profile returns to the remembered Warband position")
	DirAccess.remove_absolute(sound.settings_path)
	SaveSlots.clear()
	DirAccess.remove_absolute(SaveSlots.dir)
	print("Menu failures: %d" % failures)
	quit(1 if failures else 0)

## The veteran promotion: tapping a role only picks it, Promote makes it, and a role
## another captain already holds says so.
func _check_promotion(captain: Dictionary) -> void:
	var was_battles := int(captain.get("battles", 0))
	captain["battles"] = maxi(was_battles, 5)
	captain["specialization"] = ""
	var other: Dictionary = {}
	for s in gs.army:
		var c = s.get("captain")
		if typeof(c) == TYPE_DICTIONARY and int(c["id"]) != int(captain["id"]):
			other = c
			break
	var other_spec := String(other.get("specialization", "")) if not other.is_empty() else ""
	if not other.is_empty():
		other["specialization"] = "Scout"
	current_scene._build()
	await process_frame
	check(current_scene.find_child("PromotionCard", true, false) != null and current_scene.find_child("PromotionReadyChip", true, false) != null,
		"a captain who qualifies sees the promotion card and the ready chip")
	var promote := current_scene.find_child("PromoteButton", true, false) as Button
	check(promote != null and promote.disabled, "Promote waits until a role is picked")
	if not other.is_empty():
		var scout := current_scene.find_child("Option_Scout", true, false)
		check(scout != null and scout.find_child("HeldWarning", true, false) != null,
			"a host-wide role another captain holds says a second adds nothing")
	(current_scene.find_child("Specialization_Champion", true, false) as Button).pressed.emit()
	await process_frame
	check(String(captain.get("specialization", "")) == "" and not promote.disabled and promote.text == "Promote to Champion",
		"tapping a role picks it without making it")
	promote.pressed.emit()
	await process_frame
	await process_frame
	check(String(captain.get("specialization", "")) == "Champion", "Promote makes the picked role")
	check(current_scene.find_child("PromotionCard", true, false) == null and current_scene.find_child("SpecializationChip", true, false) != null
		and _has_text(current_scene, "is now Champion"), "after promotion the card gives way to the new role")
	captain["battles"] = was_battles
	captain["specialization"] = ""
	if not other.is_empty():
		other["specialization"] = other_spec
	current_scene._build()
	await process_frame


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
	check(state.bond_intro_pending() and state.bond_intro_pair.contains(a["name"]) and state.bond_intro_ids == [a["id"], b["id"]],
		"crossing rank C queues an introduction naming and identifying the pair")
	var loaded := State.new()
	loaded.persist = false
	loaded.from_dict(JSON.parse_string(JSON.stringify(state.to_dict())))
	check(loaded.bond_intro_pending() and loaded.bond_intro_captains().size() == 2, "unread introduction and its captain portraits survive saving and loading")
	loaded.acknowledge_bond_intro()
	result["bonds"][key] = 60.0
	result["lost"] = 3
	loaded.apply_result(result)
	check(not loaded.bond_intro_pending() and loaded.bond_conversation_is_new(a["id"], b["id"]) and loaded.new_bond_talks().size() == 1,
		"reaching rank B stops nothing: its talk waits at the fire")
	state.from_dict(JSON.parse_string(JSON.stringify(loaded.to_dict())))
	check(state.bond_record(a["id"], b["id"]).get("milestones", []).has("B") and state.bond_record(a["id"], b["id"]).get("shared_battles") == 3,
		"rank milestones and shared battle history survive saving and loading")
	var conversation := state.bond_conversation(a["id"], b["id"])
	check(conversation.get("rank") == "B" and String(conversation.get("passages", [""])[0]).contains("3 battles") and String(conversation.get("passages", ["", ""])[1]).contains("victory"),
		"optional camp dialogue refers to the pair's actual shared battles and last outcome")
	var silver_before := state.silver
	var food_before := state.food
	var points_before := float(state.captain_by_id(a["id"])["bonds"][str(b["id"])])
	state.acknowledge_bond_conversation(a["id"], b["id"])
	check(state.silver == silver_before and state.food == food_before and is_equal_approx(float(state.captain_by_id(a["id"])["bonds"][str(b["id"])]), points_before),
		"reading a bond conversation changes no resources or bond strength")
	check(not state.bond_conversation_is_new(a["id"], b["id"]), "reading clears only the rank conversation's new marker")
	state.acknowledge_bond_intro()
	state.apply_result(result)
	check(not state.bond_intro_pending(), "ordinary shared battles do not repeat a rank milestone")
	state.apply_result(result)
	check(not state.bond_intro_pending() and state.bond_record(a["id"], b["id"]).get("milestones", []).has("A") and state.bond_conversation_is_new(a["id"], b["id"]),
		"reaching rank A is recorded, with a new talk and no screen")
	check(state.bond_effect_text(24.0).contains("20% damage") and state.bond_effect_text(24.0).contains("2.0 morale"),
		"bond progression states the exact rank A battlefield effect")
	var legacy := loaded.to_dict()
	legacy.erase("bond_intro_seen")
	legacy.erase("bond_intro_pair")
	legacy.erase("bond_intro_ids")
	legacy.erase("bond_events")
	legacy.erase("bond_records")
	state.from_dict(legacy)
	check(state.bond_intro_seen, "older campaigns with existing bonds are not interrupted retroactively")
	state.new_campaign(Cultures.KHARZANI)
	check(not state.bond_intro_seen and not state.bond_intro_pending(), "a new campaign resets bond onboarding")
	# A loss after a bond is formed creates remembrance rather than a living-pair rank event.
	a = state.army[0]["captain"]
	b = state.army[1]["captain"]
	key = "%d|%d" % [a["id"], b["id"]]
	result = {"won": false, "lost": int(state.army[0]["men"]), "bonds": {key: 60.0}, "squads": {
		state.army[0]["id"]: {"men": 0, "kills": 0, "captain": {"fate": "killed", "kills": 0, "roll": 1, "needed": 45}}}}
	a["bonds"][str(b["id"])] = 6.0
	b["bonds"][str(a["id"])] = 6.0
	var rep: Dictionary = state.battle_report(result)
	check(rep.get("memorials", []).size() == 1 and String(rep["memorials"][0]["fallen"]) == String(a["first"]),
		"a bonded captain's death is remembered in the battle's results")
	state.apply_result(result)
	check(not state.bond_intro_pending(), "and stops nothing on the map")
	check(state.captain_by_id(b["id"])["history"]["fallen_friends"].has(a["name"]),
		"the surviving captain keeps the fallen partner in their personal history")
	loaded.new_campaign(Cultures.RYUMON)
	a = loaded.army[0]["captain"]
	b = loaded.army[1]["captain"]
	key = "%d|%d" % [a["id"], b["id"]]
	result = {"won": false, "lost": int(loaded.army[0]["men"]) + int(loaded.army[1]["men"]), "bonds": {key: 60.0}, "squads": {
		loaded.army[0]["id"]: {"men": 0, "kills": 0, "captain": {"fate": "killed", "kills": 0, "roll": 1, "needed": 45}},
		loaded.army[1]["id"]: {"men": 0, "kills": 0, "captain": {"fate": "killed", "kills": 0, "roll": 1, "needed": 45}}}}
	loaded.apply_result(result)
	check(not loaded.bond_intro_pending(), "a mutual loss does not invent a surviving captain's memorial reaction")
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

func _has_text(node: Node, wanted: String) -> bool:
	if node is Label and String(node.text).to_lower().contains(wanted.to_lower()):
		return true
	for child in node.get_children():
		if _has_text(child, wanted):
			return true
	return false

func _check_width(node: Node) -> void:
	if node is Control and node.is_visible_in_tree() and (node is Button or node is Label):
		var rect: Rect2 = node.get_global_rect()
		if rect.position.x < -1 or rect.end.x > root.get_visible_rect().size.x + 1:
			check(false, "horizontal overflow: %s (%s)" % [node.text, rect])
	for child in node.get_children():
		_check_width(child)

## A tap at `at` (viewport coordinates), as a finger would make it.
func _tap_at(at: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = at
	down.global_position = at
	root.push_input(down, true)
	var up := down.duplicate() as InputEventMouseButton
	up.pressed = false
	root.push_input(up, true)
