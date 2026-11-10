## Camp feels like home: the captains around the fire and one optional company moment.
extends SceneTree

const Cultures = preload("res://scripts/data/cultures.gd")
const CampMoments = preload("res://scripts/data/camp_moments.gd")
const Captains = preload("res://scripts/data/captains.gd")
const CampFx = preload("res://scripts/ui/camp_fx.gd")

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
	check(hurt_token != null and hurt_token.find_child("RestingMark", true, false) != null and String(hurt_token.accessibility_name).contains("resting"),
		"the wounded captain is shown resting")
	var grid_tokens: Array = tableau.find_child("CampCaptains", true, false).get_children() if tableau != null else []
	check(not grid_tokens.is_empty() and grid_tokens.back() == hurt_token, "and sits at the end of the fire, after those ready")
	var fire = camp.find_child("FireChips", true, false)
	check(fire != null and fire.get_parent().name == "WarbandCampStage" and fire.get_child_count() >= 2,
		"who's ready and who's resting is said on the camp picture")
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

	# The camp flies the company's own realm banner, its cloth moving in the wind, over the
	# fire's life; with motion reduced the cloth is drawn flat and nothing moves.
	var flag = camp.find_child("CompanyBanner", true, false)
	check(flag != null and String(flag.get_meta("realm", "")) == "kharzan", "the camp flies the realm's own banner")
	var cloth = flag.find_child("BannerCloth", true, false) if flag != null else null
	check(cloth is TextureRect and (cloth as TextureRect).material is ShaderMaterial and flag.find_child("ClothViewport", true, false) != null,
		"its cloth waves")
	var fx = camp.find_child("CampFx", true, false)
	check(fx != null and fx.is_processing() and fx.light == CampFx.light_for(gs.world.hour), "the fire lives, in the light of the hour")
	check(CampFx.weather_for("marchgate", 12) == CampFx.weather_for("marchgate", 12) and CampFx.weather_for("", 3) == "clear",
		"the weather is the same every time you look")
	var wet := 0
	var snow := false
	for day in 400:
		var w: String = CampFx.weather_for("kitayama", day)
		wet += 1 if w != "clear" else 0
		snow = snow or w == "snow"
	check(wet > 30 and wet < 120 and snow, "and wet on some days, not most (%d of 400), and in Ryumon's mountains it snows" % wet)
	var hurt_face = camp.find_child("CampCaptain_%d" % int(cap["id"]), true, false)
	check(hurt_face != null and hurt_face.icon != null, "the resting captain still shows a face")
	var sound = root.get_node("Sound")
	sound.reduced_motion = true
	camp = await _open_camp()
	flag = camp.find_child("CompanyBanner", true, false)
	fx = camp.find_child("CampFx", true, false)
	check(flag != null and flag.find_child("ClothViewport", true, false) == null and fx != null and not fx.is_processing(),
		"with motion reduced the banner hangs still and the fire is a picture")
	sound.reduced_motion = false

	# Without illustrations the camp still works: names, no portraits.
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

	# Three lines for every moment and temper, in turn: never the same twice running.
	var three := true
	for kind in CampMoments.LINES:
		for temper in CampMoments.LINES[kind]:
			three = three and (CampMoments.LINES[kind][temper] as Array).size() >= 3
	check(three, "every moment has three lines for each temper")
	check(CampMoments.line("victory", Captains.STEADFAST, "Brann", "", 4) != CampMoments.line("victory", Captains.STEADFAST, "Brann", "", 5),
		"one battle's line isn't the next one's")
	# A fall is mourned at the fire even if another battle came first.
	gs.camp_seen = []
	gs.fallen.append({"id": 9997, "name": "Osric of Holloway", "first": "Osric", "temperament": "", "battle": gs.battles - 2,
		"type": "infantry", "mourned": false})
	check(CampMoments.candidates(gs).any(func(c): return String(c["key"]) == "fallen_9997"), "a captain lost two battles ago still waits to be mourned")
	CampMoments.dismiss(gs, "fallen_9997")
	check(not CampMoments.candidates(gs).any(func(c): return String(c["key"]) == "fallen_9997"), "and once mourned, is let be")
	# Last words: what anyone says, and what their own people say.
	for cult in [Cultures.VARDISH, Cultures.KHARZANI, Cultures.RYUMON]:
		check(Captains.CULTURE_LAST_WORDS[cult].size() >= 5 and Captains.words_for(cult, true).size() >= Captains.LAST_WORDS.size() + 5,
			"%s captains have last words of their own" % cult)
	check(Captains.WOUNDED_WORDS.size() >= 10 and Captains.words_for(Cultures.RYUMON, false).has("Help me up. I'm not done."), "and more to say when carried off wounded")
	# A hero keeps their own voice at the fire.
	var mori := {"is_hero": true, "hero_id": "mori", "first": "Mori", "temperament": Captains.VENGEFUL}
	check(CampMoments.line_for("victory", mori, "Mori").contains("naginata"), "a hero speaks in their own voice after a battle")

	print("\nCamp tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
