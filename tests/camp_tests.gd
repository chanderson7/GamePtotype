## Camp feels like home: the captains around the fire and one optional company moment.
extends SceneTree

const Cultures = preload("res://scripts/data/cultures.gd")
const CampMoments = preload("res://scripts/data/camp_moments.gd")

var gs
var failures := 0


func check(ok: bool, message: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + message)
	if not ok:
		failures += 1


func _state_without_seen() -> String:
	var d: Dictionary = gs.to_dict()
	d.erase("camp_seen")
	return JSON.stringify(d)


func _open_camp() -> Node:
	change_scene_to_file("res://scenes/main_menu.tscn")
	await process_frame
	await process_frame
	return current_scene


func _init() -> void:
	await process_frame
	gs = root.get_node("GameState")
	gs.persist = false
	gs.new_campaign(Cultures.KHARZANI)
	check(CampMoments.pick(gs).is_empty(), "a quiet company has no camp moment")

	# A victory: one moment, from the real report.
	gs.battles = 1
	gs.last_result = {"won": true, "lost": 7, "killed": 31}
	var m: Dictionary = CampMoments.pick(gs)
	check(m.get("kind", "") == "victory" and String(m["text"]).contains("Lost 7, cut down 31"), "a victory gives one moment with its real numbers")
	var before := JSON.stringify(gs.to_dict())
	CampMoments.pick(gs)
	check(JSON.stringify(gs.to_dict()) == before, "picking a moment changes nothing")
	CampMoments.dismiss(gs, m["key"])
	check(CampMoments.pick(gs).is_empty(), "a dismissed moment doesn't come back")

	# A wounded captain rests, and gets a moment of their own.
	var cap: Dictionary = gs.army[1]["captain"]
	cap["wounded"] = 2
	m = CampMoments.pick(gs)
	check(m.get("kind", "") == "wounded" and int(m["captain_id"]) == int(cap["id"]) and String(m["text"]).contains(String(cap["first"])),
		"a wounded captain's moment names them")

	# A captain who fell in the last battle comes first.
	gs.fallen.append({"id": 9999, "name": "Test Fallen", "first": "Testa", "temperament": "", "battle": gs.battles, "type": "infantry"})
	m = CampMoments.pick(gs)
	check(m.get("kind", "") == "fallen" and String(m["text"]).contains("Testa"), "a captain fallen in the last battle is remembered first")

	# What was seen survives a save.
	var gs2 = load("res://scripts/game_state.gd").new()
	gs2.persist = false
	gs2.from_dict(JSON.parse_string(JSON.stringify(gs.to_dict())))
	check(gs2.camp_seen == gs.camp_seen and not gs2.camp_seen.is_empty(), "seen moments survive a save and load")
	gs2.free()

	# The camp screen.
	var camp = await _open_camp()
	var tableau = camp.find_child("CampTableau", true, false)
	var tokens: Array = tableau.find_children("CampCaptain_*", "Button", true, false) if tableau != null else []
	var captains: int = gs.army.filter(func(s): return s.get("captain") is Dictionary).size()
	check(tokens.size() == captains, "every captain has a place at the fire (%d of %d)" % [tokens.size(), captains])
	var hurt_token = camp.find_child("CampCaptain_%d" % int(cap["id"]), true, false)
	check(hurt_token != null and hurt_token.text.contains("resting"), "the wounded captain is shown resting")
	check(camp.find_child("CampMoment", true, false) != null, "the camp shows the moment")
	var state: String = _state_without_seen()
	var dismiss: Button = null
	for b in camp.find_children("*", "Button", true, false):
		if b.text == "Let it be":
			dismiss = b
	if dismiss == null:
		check(false, "the moment can be dismissed")
		quit(1)
		return
	dismiss.pressed.emit()
	await process_frame
	await process_frame
	check(_state_without_seen() == state, "dismissing a moment changes nothing but what was seen")
	camp = await _open_camp()
	var next_moment: Dictionary = CampMoments.pick(gs)
	check(next_moment.get("key", "") != "fallen_9999", "and returning to camp doesn't repeat it")

	# Without illustrations the camp still works: names, no portraits.
	var sound = root.get_node("Sound")
	sound.illustrations_enabled = false
	camp = await _open_camp()
	tokens = camp.find_child("CampTableau", true, false).find_children("CampCaptain_*", "Button", true, false)
	check(tokens.size() == captains and tokens.all(func(t): return t.icon == null and t.text != ""), "with illustrations off, captains are listed by name")
	sound.illustrations_enabled = true

	# A captain token opens that captain's profile.
	var token_id := int(String(tokens[0].name).split("_")[1])
	tokens[0].pressed.emit()
	await create_timer(0.6).timeout
	check(root.get_node("Scenes").active_captain_id == token_id, "a captain at the fire opens their profile")

	print("\nCamp tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
