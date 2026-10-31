## Story presentation: legacy cursor migration, UI history, accessibility and asset contracts.
extends SceneTree
const Stories = preload("res://scripts/data/personal_conversations.gd")
const Art = preload("res://scripts/ui/story_art.gd")
const Style = preload("res://scripts/ui/style.gd")
const Cultures = preload("res://scripts/data/cultures.gd")
const CaptainArt = preload("res://scripts/ui/captain_art.gd")
const Captains = preload("res://scripts/data/captains.gd")
const TravelPresentation = preload("res://scripts/world/travel_presentation.gd")
const WorldData = preload("res://scripts/world/world_data.gd")
const WorldSim = preload("res://scripts/world/world_sim.gd")
const SettlementVista = preload("res://scripts/ui/settlement_vista.gd")
const Lords = preload("res://scripts/data/lords.gd")
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
	sound.settings_path = "user://bannerfall-presentation-%d.cfg" % OS.get_process_id()
	sound.set_text_scale(1.0)
	sound.set_reduced_motion(false)
	sound.set_illustrations(true)
	for cue in ["footsteps", "camp", "morale_low", "bond_rank", "promotion", "road_open", "road_night", "settlement_edge",
			"settlement_vardish", "settlement_kharzani", "settlement_ryumon"]:
		check(sound._stream("res://assets/audio/sfx/%s.ogg" % cue, cue in ["footsteps", "camp", "road_open", "road_night", "settlement_edge",
			"settlement_vardish", "settlement_kharzani", "settlement_ryumon"]) != null,
			"%s cue loads from the generated audio source" % cue)
	check(sound._movement_loop != sound._loop, "battle movement and terrain ambience use separate audio channels")
	check(sound._loop_alt != sound._loop, "ambience has two channels for uninterrupted crossfades")
	sound.set_loop("road_open")
	sound.set_loop("road_night")
	check(sound._loop_name == "road_night", "road ambience changes through the crossfade controller")
	sound.set_loop("")
	_check_travel_context()
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
	for candidate_id in ["edda", "farid", "kaede"]:
		for expression in Art.EXPRESSIONS:
			var tex := Art.texture("res://assets/portraits/%s_%s.png" % [candidate_id, expression])
			check(tex != null and tex.get_width() == 384 and tex.get_height() == 512,
				"%s %s portrait exported at consistent size" % [candidate_id, expression])
			if tex != null:
				check(tex.get_image().detect_alpha() != Image.ALPHA_NONE,
					"%s %s retains transparency" % [candidate_id, expression])
	for name in ["ravensford", "common_room", "qasr_hamra", "envoy_room", "kitayama", "archive_room"]:
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


func _check_travel_context() -> void:
	var travel_world = WorldSim.new()
	travel_world.setup(731, Cultures.VARDISH)
	var foot := [{"unit": "vardish_infantry", "type": "infantry", "men": 20}]
	var cavalry := [{"unit": "vardish_cavalry", "type": "cavalry", "men": 20}]
	var before := JSON.stringify(travel_world.to_dict())
	var at_home := TravelPresentation.context(travel_world, foot)
	check(at_home["surface"] == "settlement" and at_home["ambience"] == "settlement_vardish",
		"standing near a settlement selects its culture ambience")
	check(at_home["nearest_settlement"] == travel_world.here() and at_home["culture"] != "",
		"travel context carries location and culture without screen state")
	check(JSON.stringify(travel_world.to_dict()) == before, "deriving travel presentation does not mutate the world")
	travel_world.hour = 23.0
	check(TravelPresentation.context(travel_world, foot)["ambience"] == "settlement_vardish",
		"night settlements retain their quiet culture ambience")
	travel_world.hour = 10.0
	var land_road: Array = []
	var sea_road: Array = []
	for road in WorldData.ROADS:
		if bool(road[2]) and sea_road.is_empty():
			sea_road = road
		elif not bool(road[2]) and land_road.is_empty():
			land_road = road
	var party = travel_world.player()
	party.node = String(land_road[0])
	party.next = String(land_road[1])
	party.path = []
	party.along = travel_world.road_length(party.node, party.next) * 0.5
	var foot_context := TravelPresentation.context(travel_world, foot)
	var cavalry_context := TravelPresentation.context(travel_world, cavalry)
	check(foot_context["movement_contact"] == "foot" and cavalry_context["movement_contact"] == "cavalry",
		"living company composition selects foot or cavalry road contact")
	check(foot_context["cosmetic_key"] == TravelPresentation.context(travel_world, foot)["cosmetic_key"],
		"cosmetic travel variation is stable and consumes no RNG")
	travel_world.hour = 23.0
	check(TravelPresentation.context(travel_world, foot)["ambience"] == "road_night",
		"night atmosphere takes priority on the open road")
	travel_world.hour = 10.0
	party.node = String(sea_road[0])
	party.next = String(sea_road[1])
	party.along = travel_world.road_length(party.node, party.next) * 0.5
	var sea_context := TravelPresentation.context(travel_world, foot)
	check(sea_context["surface"] == "water" and sea_context["movement_contact"] == "wake",
		"sea travel selects water ambience and a visual wake")
	var arrival := TravelPresentation.arrival(travel_world, party.node)
	check(arrival.has("name") and arrival.has("subtitle") and arrival.has("condition"),
		"arrival presentation is composed entirely from settlement facts")
	_check_settlement_conditions()


func _check_settlement_conditions() -> void:
	var w = WorldSim.new()
	w.setup(832, Cultures.VARDISH)
	var local_ambience: Array[String] = []
	for capital in ["highcliff", "khalun", "kurogane"]:
		w.player().node = capital
		w.player().next = ""
		local_ambience.append(String(TravelPresentation.context(w, [])["ambience"]))
	check(local_ambience == ["settlement_vardish", "settlement_kharzani", "settlement_ryumon"],
		"each culture selects its own settlement ambience family")
	var baseline := JSON.stringify(w.to_dict())
	var cultures := {}
	var types := {}
	for id in WorldData.SETTLEMENTS:
		var state := TravelPresentation.settlement_state(w, id)
		cultures[String(state.get("culture", ""))] = true
		types[String(state.get("type", ""))] = true
		var vista := SettlementVista.make(id, w, 180.0)
		check(not state.is_empty() and String(state["sentence"]) != "" and vista.place == id,
			"%s has a coherent culture, type and condition composition" % id)
		vista.free()
	check(cultures.size() == 3 and types.size() == 3, "all three cultures and settlement types use the shared composition")
	check(JSON.stringify(w.to_dict()) == baseline, "deriving all 21 settlement compositions changes no campaign state")
	var town := TravelPresentation.settlement_state(w, "highcliff")
	check(town["props"].has("market") and town["props"].has("smith"), "town services stage market and smith activity")
	var castle := TravelPresentation.settlement_state(w, "ravensford")
	check(castle["props"].has("guards") and castle["garrison"] != "none", "castle staging reflects its standing guards")
	var village := TravelPresentation.settlement_state(w, "thornwall")
	check(village["props"].has("workers") and village["props"].has("livestock"), "healthy village staging reflects field work")

	for squad in w.garrisons["ravensford"]:
		squad["men"] = 0
	var thin := TravelPresentation.settlement_state(w, "ravensford")
	check(thin["condition"] == "strained" and thin["garrison"] == "thin" and "thinly held" in thin["sentence"],
		"low garrison produces the same strained state and warning copy")

	w.set_owner("ravensford", "kharzan")
	var occupied := TravelPresentation.settlement_state(w, "ravensford")
	check(occupied["condition"] == "occupied" and occupied["owner"] == "kharzan" and occupied["recent_event"] != "",
		"captured settlement carries new ownership and the saved activity entry")

	var band = w.bands()[0]
	band.raiding = true
	band.raid_village = "thornwall"
	var raided := TravelPresentation.settlement_state(w, "thornwall")
	check(raided["condition"] == "damaged" and raided["raid_active"] and raided["props"].is_empty(),
		"active raid removes ordinary village activity and stages damage")
	band.raiding = false
	band.raid_village = ""
	w.burned["thornwall"] = w.hour + Lords.BURNED_DAYS * 24.0
	var damaged := TravelPresentation.settlement_state(w, "thornwall")
	check(damaged["condition"] == "damaged" and not damaged["services"].has("recruits"),
		"newly burned village shows damage and no recruit service")
	w.hour += Lords.BURNED_DAYS * 12.0 + 1.0
	var recovering := TravelPresentation.settlement_state(w, "thornwall")
	check(recovering["condition"] == "recovering" and recovering["props"].has("timber"),
		"later rebuild phase replaces ruin staging with workers and fresh timber")
	w.hour = floor(w.hour / 24.0) * 24.0 + 23.0
	check(TravelPresentation.settlement_state(w, "thornwall")["night"], "settlement composition derives night lighting from campaign time")

	var saved: Dictionary = JSON.parse_string(JSON.stringify(w.to_dict()))
	var restored = WorldSim.new()
	restored.from_dict(saved)
	var before_reload := TravelPresentation.settlement_state(w, "thornwall")
	var after_reload := TravelPresentation.settlement_state(restored, "thornwall")
	check(before_reload["condition"] == after_reload["condition"]
		and before_reload["owner"] == after_reload["owner"]
		and before_reload["garrison"] == after_reload["garrison"],
		"settlement condition remains stable across save and reload")

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
	gs.world.player().node = "highcliff"
	gs.world.player().next = ""
	root.get_node("Scenes").settlement_arrival_pending = true
	# Visiting restocks recruit offers and jobs that are due; that is the visit, not the arrival card.
	gs.world.offers_at("highcliff")
	gs.world.jobs_at("highcliff")
	var arrival_baseline: Dictionary = gs.to_dict().duplicate(true)
	await open_scene("settlement")
	check(current_scene.find_child("LocationIllustration", true, false) != null, "capital arrival shows its culture-specific illustration")
	check(current_scene.find_child("ArrivalOverlay", true, false) != null
		and current_scene.find_child("ArrivalVista", true, false) != null,
		"entering from the map stages a dismissible illustrated arrival")
	var settlement_condition := current_scene.find_child("SettlementCondition", true, false)
	check(settlement_condition != null and String(settlement_condition.text) != "",
		"settlement sheet leads with the same compact condition used by the vista")
	check(_scene_has_text(current_scene, "ARRIVED") and _scene_has_text(current_scene, "Tap to continue"),
		"arrival card has a readable text path and dismissal instruction")
	current_scene._show_arrival_card()
	check(current_scene.find_children("ArrivalOverlay", "Control", true, false).size() == 1,
		"repeated arrival requests cannot stack cards")
	current_scene._dismiss_arrival()
	await process_frame
	check(gs.to_dict() == arrival_baseline, "showing and dismissing arrival changes no campaign state")
	check(_scene_has_text(current_scene, "Why it matters:") and _scene_has_text(current_scene, "Services:"),
		"essential settlement intelligence remains readable outside the illustration")
	_check_widths(current_scene)
	sound.set_text_scale(1.0)
	await open_scene("settlement")
	_check_widths(current_scene)
	sound.set_text_scale(1.5)
	sound.set_illustrations(false)
	root.get_node("Scenes").settlement_arrival_pending = true
	await open_scene("settlement")
	check(current_scene.find_child("ArrivalOverlay", true, false) != null
		and current_scene.find_child("ArrivalVista", true, false) == null
		and _scene_has_text(current_scene, "ARRIVED"),
		"illustrations off keeps the complete text-only arrival card")
	current_scene._dismiss_arrival()
	sound.set_illustrations(true)
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
	await open_scene("world_map")
	current_scene._open_preview("khalun")
	await process_frame
	check(button("Ride there") != null and button("Ride there").get_global_rect().end.y <= root.get_visible_rect().size.y,
		"map keeps the primary travel action reachable at 150 percent text")
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
	check(overflow.is_empty(), "%s fits horizontally at %d%% text: %s" % [scene.name, roundi(sound.text_scale * 100.0), str(overflow)])


func _scene_has_text(node: Node, wanted: String) -> bool:
	if node is Label and String(node.text).contains(wanted):
		return true
	for child in node.get_children():
		if _scene_has_text(child, wanted):
			return true
	return false
