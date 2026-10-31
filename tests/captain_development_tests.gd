extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const Captains = preload("res://scripts/data/captains.gd")
const AutoResolve = preload("res://scripts/battle/auto_resolve.gd")
const Troops = preload("res://scripts/data/troops.gd")
const Economy = preload("res://scripts/data/economy.gd")

var passed := 0
var failed := 0

func assert_true(condition: bool, msg: String) -> void:
	if condition:
		passed += 1
		print("  ok    %s" % msg)
	else:
		failed += 1
		print("  FAIL  %s" % msg)

func assert_eq(a, b, msg: String) -> void:
	if a == b:
		passed += 1
		print("  ok    %s" % msg)
	else:
		failed += 1
		print("  FAIL  %s: got %s, expected %s" % [msg, str(a), str(b)])

func _init() -> void:
	print("\nRunning Captain Development Tests (Phase 5.3)...")
	test_specialization_constants_and_descriptions()
	test_qualification_thresholds()
	test_specialization_assignment()
	test_scout_effects()
	test_quartermaster_effects()
	test_drillmaster_effects()
	test_champion_effects()
	test_save_load_specializations()

	print("\nCaptain Development Tests finished: %d passed, %d failed" % [passed, failed])
	if failed > 0:
		quit(1)
	else:
		quit(0)


func test_specialization_constants_and_descriptions() -> void:
	print("\n--- Specialization Definitions & Constants ---")
	assert_eq(Captains.SCOUT, "Scout", "Scout constant defined")
	assert_eq(Captains.QUARTERMASTER, "Quartermaster", "Quartermaster constant defined")
	assert_eq(Captains.DRILLMASTER, "Drillmaster", "Drillmaster constant defined")
	assert_eq(Captains.CHAMPION, "Champion", "Champion constant defined")

	for spec in Captains.SPECIALIZATIONS:
		assert_true(Captains.SPECIALIZATION_TITLES.has(spec), "Title defined for %s" % spec)
		assert_true(Captains.SPECIALIZATION_DESCRIPTIONS.has(spec), "Description defined for %s" % spec)


func test_qualification_thresholds() -> void:
	print("\n--- Veteran Promotion Qualification ---")
	var c := {"battles": 0, "kills": 0, "specialization": ""}
	assert_true(not Captains.can_specialize(c), "New recruit cannot specialize (0 battles, 0 kills)")

	c["battles"] = 4
	c["kills"] = 14
	assert_true(not Captains.can_specialize(c), "Under both thresholds cannot specialize (4 battles, 14 kills)")

	c["battles"] = 5
	assert_true(Captains.can_specialize(c), "5 battles qualifies for veteran promotion")

	c["battles"] = 1
	c["kills"] = 15
	assert_true(Captains.can_specialize(c), "15 kills qualifies for veteran promotion")

	c["specialization"] = Captains.SCOUT
	assert_true(not Captains.can_specialize(c), "Already specialized captain cannot pick another")


func test_specialization_assignment() -> void:
	print("\n--- Specialization Selection & Assignment ---")
	var gs = GameStateScript.new()
	gs.persist = false
	gs.new_warband()

	var squad: Dictionary = gs.army[0]
	var c: Dictionary = squad["captain"]
	c["battles"] = 5

	assert_true(not gs.has_specialization(Captains.SCOUT), "Warband initially has no Scout")
	var ok := gs.specialize_captain(int(c["id"]), Captains.SCOUT)
	assert_true(ok, "Captain successfully specialized as Scout")
	assert_eq(String(c["specialization"]), Captains.SCOUT, "Captain specialization set to Scout")
	assert_true(gs.has_specialization(Captains.SCOUT), "has_specialization(SCOUT) is true")

	# Attempting to specialize again should fail
	var second_ok := gs.specialize_captain(int(c["id"]), Captains.CHAMPION)
	assert_true(not second_ok, "Cannot re-specialize already specialized captain")


func test_scout_effects() -> void:
	print("\n--- Scout Effects: Sighting & Ambush Risk ---")
	var gs = GameStateScript.new()
	gs.persist = false
	gs.new_warband()

	assert_eq(gs.sighting_distance_mult(), 1.0, "Base sighting distance multiplier is 1.0")

	gs.army[0]["captain"]["specialization"] = Captains.SCOUT
	assert_eq(gs.sighting_distance_mult(), 1.3, "Scout grants +30% sighting distance multiplier (1.3)")


func test_quartermaster_effects() -> void:
	print("\n--- Quartermaster Effects: Supplies & Spoils ---")
	var gs = GameStateScript.new()
	gs.persist = false
	gs.new_warband()

	# Without Quartermaster
	gs.food = 500
	var base_food_days := gs.food_days()

	# With Quartermaster
	gs.army[0]["captain"]["specialization"] = Captains.QUARTERMASTER
	var qm_food_days := gs.food_days()
	assert_true(qm_food_days > base_food_days, "Quartermaster extends food days by reducing daily consumption by 20%")


func test_drillmaster_effects() -> void:
	print("\n--- Drillmaster Effects: Combat XP & Dilution Mitigation ---")
	var gs = GameStateScript.new()
	gs.persist = false
	gs.new_warband()

	var squad: Dictionary = gs.army[0]
	squad["xp"] = 100
	var full := Troops.full_size(squad["type"])
	squad["men"] = int(full * 0.5) # half strength
	gs.silver = 1000

	# Without Drillmaster: dilution keeps 50% XP
	var gs_normal = GameStateScript.new()
	gs_normal.persist = false
	gs_normal.new_warband()
	var s_normal: Dictionary = gs_normal.army[0]
	s_normal["xp"] = 100
	s_normal["men"] = int(full * 0.5)
	gs_normal.silver = 1000
	gs_normal.reinforce_squad(int(s_normal["id"]))
	var normal_diluted_xp: int = s_normal["xp"]

	# With Drillmaster: dilution is halved (keeps 75% XP instead of 50%)
	gs.army[1]["captain"]["specialization"] = Captains.DRILLMASTER
	gs.reinforce_squad(int(squad["id"]))
	var dm_xp: int = squad["xp"]

	assert_true(dm_xp > normal_diluted_xp, "Drillmaster cuts recruit dilution penalty in half (retains more XP)")


func test_champion_effects() -> void:
	print("\n--- Champion Effects: Squad Damage & Strength ---")
	var gs = GameStateScript.new()
	gs.persist = false
	gs.new_warband()

	var squad: Dictionary = gs.army[0]
	var foe := [{"type": Troops.INFANTRY, "men": 10, "xp": 0}]

	# Base auto-resolve strength
	squad["captain"]["specialization"] = ""
	var base_str := AutoResolve.strength([squad], foe)

	# Champion auto-resolve strength (+15%)
	squad["captain"]["specialization"] = Captains.CHAMPION
	var champ_str := AutoResolve.strength([squad], foe)

	assert_true(champ_str > base_str, "Champion captain adds +15% squad strength in auto-resolve")
	var diff_ratio := champ_str / base_str
	assert_true(abs(diff_ratio - 1.15) < 0.02, "Strength boost matches +15% damage bonus")


func test_save_load_specializations() -> void:
	print("\n--- Save/Load Roundtrip: Captain Specializations ---")
	var gs = GameStateScript.new()
	gs.persist = false
	gs.new_warband()

	gs.army[0]["captain"]["specialization"] = Captains.DRILLMASTER
	gs.army[1]["captain"]["specialization"] = Captains.QUARTERMASTER

	var saved := gs.to_dict()
	var loaded_gs = GameStateScript.new()
	loaded_gs.persist = false
	loaded_gs.from_dict(saved)

	assert_eq(String(loaded_gs.army[0]["captain"]["specialization"]), Captains.DRILLMASTER, "Drillmaster specialization preserved")
	assert_eq(String(loaded_gs.army[1]["captain"]["specialization"]), Captains.QUARTERMASTER, "Quartermaster specialization preserved")
	assert_true(loaded_gs.has_specialization(Captains.DRILLMASTER), "has_specialization reflects loaded data")
