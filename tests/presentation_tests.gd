## Story presentation: legacy cursor migration, UI history, accessibility and asset contracts.
extends SceneTree
const Stories = preload("res://scripts/data/personal_conversations.gd")
const Art = preload("res://scripts/ui/story_art.gd")
const Style = preload("res://scripts/ui/style.gd")
const Cultures = preload("res://scripts/data/cultures.gd")
const CaptainArt = preload("res://scripts/ui/captain_art.gd")
const Captains = preload("res://scripts/data/captains.gd")
const FIRST := "edda_spare_spoon"
const PERSON := "person_edda"
var failures := 0
var checks := 0
var gs
var sound

func _init() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	print("%s %s" % ["ok" if ok else "FAIL", label])
	if not ok:
		failures += 1

func action(kind: String, choice: int = -1) -> Dictionary:
	return gs.personal_conversation_action(PERSON, FIRST, kind, choice)

func button(text: String) -> Button:
	for node in current_scene.find_children("*", "Button", true, false):
		if node.text == text:
			return node
	return null

func _run() -> void:
	gs = root.get_node("GameState")
	sound = root.get_node("Sound")
	gs.persist = false
	sound.settings_path = "/private/tmp/bannerfall-presentation-%d.cfg" % OS.get_process_id()
	sound.set_text_scale(1.0)
	sound.set_reduced_motion(false)
	sound.set_illustrations(true)
	gs.new_campaign(Cultures.VARDISH)
	gs.world.player().node = "ravensford"
	gs.world.social.apply_choice("edda", "offer_help", {})
	check(not action("advance")["ok"], "unstarted reader cannot advance")
	check(action("begin")["progress"]["beat"] == 0, "first visit starts at opening beat")
	var before: Dictionary = gs.to_dict().duplicate(true)
	check(action("advance")["progress"]["beat"] == 1, "advance saves one beat")
	check(action("advance")["progress"]["beat"] == 2, "successive beats persist")
	check(action("previous")["progress"]["beat"] == 1, "previous keeps a saved reading position")
	var after: Dictionary = gs.to_dict().duplicate(true)
	after["world"]["social"]["personal_conversations"] = before["world"]["social"]["personal_conversations"]
	check(after == before, "reading changes only personal progress, not simulation or rewards")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(gs.to_dict()))
	gs.from_dict(saved)
	var resumed := action("begin")
	check(resumed["progress"]["beat"] == 1 and resumed["progress"]["furthest_beat"] == 2, "JSON reload preserves position and history extent")
	action("choose", 1)
	var old: Dictionary = gs.world.social.personal_conversations[PERSON]["in_progress"][FIRST]
	old.erase("beat")
	old.erase("furthest_beat")
	old.erase("reader_version")
	resumed = action("begin")
	check(resumed["progress"]["choice"] == 1 and resumed["progress"]["node"] == 1 and resumed["progress"]["beat"] == 0, "legacy closing visit keeps its selected response")
	check(not action("previous")["ok"], "reader rejects stepping before the first beat")
	var cursor: Dictionary = gs.world.social.personal_conversations[PERSON]["in_progress"][FIRST]
	cursor["beat"] = 900
	cursor["furthest_beat"] = 900
	resumed = action("begin")
	var sequence := Stories.beats(FIRST, 1, 1, resumed["progress"]["context"])
	check(resumed["progress"]["beat"] == sequence.size() - 1, "stale cursor is safely clamped")
	check(not action("advance")["ok"], "reader rejects advancing beyond passage")
	check(action("finish")["trust_change"] == 1, "presentation preserves first-completion reward")
	check(not action("advance")["ok"], "archive commands cannot mutate completed visits")
	for expression in Art.EXPRESSIONS:
		var tex := Art.texture("res://assets/portraits/edda_%s.png" % expression)
		check(tex != null and tex.get_width() == 384 and tex.get_height() == 512, expression + " portrait exported at consistent size")
		if tex != null:
			check(tex.get_image().detect_alpha() != Image.ALPHA_NONE, expression + " retains transparency")
	for name in ["ravensford", "common_room"]:
		var tex := Art.texture("res://assets/locations/%s.png" % name)
		check(tex != null and tex.get_width() == 768, name + " illustration available")
	var camp := Art.texture("res://assets/locations/company_camp.png")
	check(camp != null and camp.get_width() == 768 and camp.get_height() == 512, "company camp has reusable header dimensions")
	for culture in Captains.APPEARANCES:
		for appearance in Captains.APPEARANCES[culture]:
			var tex := Art.texture("res://assets/portraits/captain_%s.png" % appearance)
			check(tex != null and tex.get_width() == 384 and tex.get_height() == 512, appearance + " captain portrait has a consistent crop")
			if tex != null:
				check(tex.get_image().detect_alpha() != Image.ALPHA_NONE, appearance + " captain portrait retains transparency")
	var fallback := Art.texture("res://assets/portraits/captain_fallback.png")
	check(fallback != null and fallback.get_image().detect_alpha() != Image.ALPHA_NONE, "captain fallback is available with transparency")
	check(Art.texture("res://assets/portraits/absent.png") == null, "missing illustration has a text-only fallback")
	await _check_ui()
	DirAccess.remove_absolute(sound.settings_path)
	print("Presentation: %d checks, %d failures" % [checks, failures])
	quit(failures)

func open_scene(path: String) -> void:
	change_scene_to_file("res://scenes/" + path + ".tscn")
	await process_frame
	await process_frame

func _check_ui() -> void:
	root.get_node("Scenes").active_person_id = PERSON
	await open_scene("personal_conversation")
	var baseline: Dictionary = gs.to_dict().duplicate(true)
	button("Remember: The Spare Spoon").pressed.emit()
	button("Continue").pressed.emit()
	button("History").pressed.emit()
	check(button("Return to conversation") != null, "history is available from the reader toolbar")
	check(current_scene._progress["beat"] == 1, "opening history preserves cursor")
	button("Return to conversation").pressed.emit()
	button("Summary").pressed.emit()
	button("Close memory").pressed.emit()
	check(gs.to_dict() == baseline, "replay navigation, history and summary change no campaign state")
	button("Visit: The Wrong Last Verse").pressed.emit()
	button("Continue").pressed.emit()
	var progress: Dictionary = current_scene._progress.duplicate(true)
	button("Leave").pressed.emit()
	button("Resume: The Wrong Last Verse").pressed.emit()
	check(current_scene._progress["beat"] == progress["beat"], "leave and resume returns to exact line")
	button("Summary").pressed.emit()
	button("Keep this memory").pressed.emit()
	check(gs.world.social.relationships["edda"]["trust"] == 12, "summary UI still grants exactly one trust")
	sound.mark_hint_seen("test", "retained")
	sound.set_text_scale(1.5)
	sound.set_reduced_motion(true)
	sound.set_illustrations(false)
	sound.text_scale = 1.0
	sound.reduced_motion = false
	sound.illustrations_enabled = true
	sound._load_settings()
	check(sound.text_scale == 1.5 and sound.reduced_motion and not sound.illustrations_enabled, "presentation preferences survive disk reload")
	check(sound.has_seen_hint("test", "retained"), "presentation preferences preserve tutorial acknowledgements")
	check(Style.text_size(26) == 39, "body text honors 150 percent preference")
	check(Art.texture("res://assets/portraits/edda_neutral.png") == null, "illustrations off also bypasses cached textures")
	await open_scene("settings")
	check(button("Text size: 150%") != null and button("Reduced motion: on") != null, "Settings reflects persisted preferences")
	check(CaptainArt.texture(gs.army[0]["captain"]) == null, "illustrations off bypasses captain portraits")
	var panel := Control.new()
	root.add_child(panel)
	Style.ease_in(panel)
	check(panel.scale == Vector2.ONE and panel.modulate.a == 1.0, "reduced motion skips spring animation")
	panel.queue_free()
	await open_scene("main_menu")
	check(not current_scene.find_child("WarbandCampIllustration", true, false).visible
		and current_scene.find_children("CaptainPortrait", "TextureRect", true, false).is_empty(),
		"text-only Warband keeps unit icons and hides decorative art")
	await open_scene("personal_conversation")
	button("Remember: The Spare Spoon").pressed.emit()
	await process_frame
	await process_frame
	check(not current_scene.find_child("StoryStage", true, false).visible, "text-only reader hides decorative stage")
	check(button("Summary") != null and button("Continue") != null, "text-only reader retains full navigation")
	_check_widths(current_scene)
	sound.set_illustrations(true)
	await open_scene("people")
	_check_widths(current_scene)
	await open_scene("settlement")
	check(current_scene.find_child("LocationIllustration", true, false) != null, "Ravensford arrival shows its illustration")
	_check_widths(current_scene)
	sound.set_text_scale(1.5)
	var bond_a: Dictionary = gs.army[0]["captain"]
	var bond_b: Dictionary = gs.army[1]["captain"]
	bond_a["bonds"][str(bond_b["id"])] = 12.0
	bond_b["bonds"][str(bond_a["id"])] = 12.0
	var bond_key := "%d|%d" % [mini(bond_a["id"], bond_b["id"]), maxi(bond_a["id"], bond_b["id"])]
	gs.bond_records[bond_key] = {"shared_battles": 4, "last_battle": 4, "last_outcome": "victory",
		"last_losses": 2, "milestones": ["C", "B"], "conversations": [], "losses": []}
	await open_scene("main_menu")
	check(current_scene.find_child("WarbandCampIllustration", true, false) != null, "Warband keeps its camp at 150 percent text")
	_check_widths(current_scene)
	root.get_node("Scenes").active_bond_a_id = int(bond_a["id"])
	root.get_node("Scenes").active_bond_b_id = int(bond_b["id"])
	await open_scene("bond_conversation")
	check(current_scene.find_child("BondConversationPortraits", true, false) != null, "bond conversation keeps paired portraits at 150 percent text")
	_check_widths(current_scene)
	gs.bond_events = [{"kind": "rank", "rank": "B", "a_id": int(bond_a["id"]), "b_id": int(bond_b["id"]),
		"pair": "%s & %s" % [bond_a["name"], bond_b["name"]], "points": 12.0, "shared_battles": 4}]
	await open_scene("bond_intro")
	check(button("Spend time at camp") != null, "rank B milestone keeps its optional conversation action at 150 percent text")
	_check_widths(current_scene)
	gs.bond_events = []
	root.get_node("Scenes").active_captain_id = int(gs.army[0]["captain"]["id"])
	await open_scene("captain_profile")
	check(button("Back to Warband") != null, "captain profile keeps its exit at 150 percent text")
	_check_widths(current_scene)
	await open_scene("title")
	check(current_scene.find_child("HomeCampIllustration", true, false) != null, "Home keeps its campaign art at 150 percent text")
	_check_widths(current_scene)
	sound.set_text_scale(1.0)
	sound.set_reduced_motion(false)

func _check_widths(scene: Node) -> void:
	var overflow: Array = []
	var width := root.get_visible_rect().size.x
	for node in scene.find_children("*", "Control", true, false):
		if node is Label or node is Button:
			if node.is_visible_in_tree() and (node.get_global_rect().end.x > width + 1.0 or node.get_global_rect().position.x < -1.0):
				overflow.append(node.name)
	check(overflow.is_empty(), "%s fits horizontally at 150%% text: %s" % [scene.name, str(overflow)])
