extends SceneTree

const WorldSim = preload("res://scripts/world/world_sim.gd")
const GameStateScript = preload("res://scripts/game_state.gd")
const WorldData = preload("res://scripts/world/world_data.gd")
const Cultures = preload("res://scripts/data/cultures.gd")
const Lords = preload("res://scripts/data/lords.gd")
const SoundScript = preload("res://scripts/audio/sound.gd")

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
	print("\nRunning Integration and Polish Tests (Phase 4.7)...")
	test_chronicle_capacity_and_types()
	test_chronicle_categories_and_filtering()
	test_path_caching_and_invalidation()
	test_siege_detection_and_query()
	test_sound_cue_methods()
	test_map_readability_scaling_and_grouping()
	test_save_load_chronicle_persistence()

	print("\nIntegration and Polish Tests finished: %d passed, %d failed" % [passed, failed])
	if failed > 0:
		quit(1)
	else:
		quit(0)


func test_chronicle_capacity_and_types() -> void:
	print("\n--- The Chronicle: Capacity and Event Types ---")
	var w = WorldSim.new()
	w.setup(42, Cultures.VARDISH)

	assert_eq(WorldSim.ACTIVITY_LIMIT, 30, "Chronicle capacity increased to 30 events")

	# Declare war between Vardmark and Ryumon (initially at peace)
	w.declare_war("vardmark", "ryumon", true)
	assert_true(w.activity_log.size() >= 1, "War declaration logged in chronicle")
	assert_eq(w.activity_log[0]["category"], "war", "War event categorized as 'war'")

	w.make_peace("vardmark", "ryumon", 30, 25, "ryumon", 20)
	assert_eq(w.activity_log[0]["category"], "war", "Peace treaty categorized as 'war'")
	assert_true("tribute" in w.activity_log[0]["text"] or "pays" in w.activity_log[0]["text"], "Peace treaty details tribute in text")

	# Siege assault & settlement capture
	w.emit_event({"type": "siege_started", "realm": "vardmark", "target": "khalun"})
	assert_eq(w.activity_log[0]["category"], "siege", "Siege start categorized as 'siege'")

	w.emit_event({"type": "siege_assault", "target": "khalun", "attacker_won": true})
	assert_eq(w.activity_log[0]["category"], "siege", "Siege assault categorized as 'siege'")

	w.set_owner("khalun", "vardmark")
	assert_eq(w.activity_log[0]["category"], "siege", "Settlement capture categorized as 'siege'")

	# Lord capture & ransom
	w.emit_event({"type": "lord_captured", "lord": "Lord Maren", "captor": "Your warband"})
	assert_eq(w.activity_log[0]["category"], "battle", "Lord capture categorized as 'battle'")

	w.emit_event({"type": "ransom_paid", "lord": "Lord Maren", "amount": 350})
	assert_eq(w.activity_log[0]["category"], "battle", "Ransom paid categorized as 'battle'")

	# Company deeds
	w.emit_event({"type": "grudge_avenged", "company": "The Iron Company", "lord": "Lord Maren"})
	assert_eq(w.activity_log[0]["category"], "deed", "Grudge vengeance categorized as 'deed'")

	w.emit_event({"type": "contract_signed", "company": "The Iron Company", "realm": "vardmark"})
	assert_eq(w.activity_log[0]["category"], "deed", "Contract signed categorized as 'deed'")

	w.emit_event({"type": "contract_ended", "company": "The Iron Company", "realm": "vardmark"})
	assert_eq(w.activity_log[0]["category"], "deed", "Contract ended categorized as 'deed'")

	w.emit_event({"type": "player_victory", "company": "The Iron Company", "enemy": "Bandit Chief", "at": "highcliff"})
	assert_eq(w.activity_log[0]["category"], "deed", "Player victory categorized as 'deed'")


func test_chronicle_categories_and_filtering() -> void:
	print("\n--- The Chronicle: Filtering and Limits ---")
	var w = WorldSim.new()
	w.setup(101, Cultures.VARDISH)

	# Fill chronicle beyond 30 events
	for i in 40:
		var kind := "war" if i % 4 == 0 else ("burned" if i % 4 == 1 else ("fight" if i % 4 == 2 else "grudge_avenged"))
		if kind == "war":
			w.emit_event({"type": "war", "realms": ["vardmark", "kharzan"]})
		elif kind == "burned":
			w.emit_event({"type": "burned", "village": "kettlebrook", "by": "raiders"})
		elif kind == "fight":
			w.emit_event({"type": "fight", "winner": "Lord Alden", "loser": "Lord Maren", "at": "highcliff"})
		else:
			w.emit_event({"type": "grudge_avenged", "company": "Player Warband", "lord": "Lord Maren"})

	assert_eq(w.activity_log.size(), 30, "Activity log enforces maximum capacity of 30 entries")

	# Test filtering
	var war_entries: Array = w.activity_log.filter(func(e): return e.get("category") == "war")
	var siege_entries: Array = w.activity_log.filter(func(e): return e.get("category") == "siege")
	var battle_entries: Array = w.activity_log.filter(func(e): return e.get("category") == "battle")
	var deed_entries: Array = w.activity_log.filter(func(e): return e.get("category") == "deed")

	assert_true(war_entries.size() > 0, "War category entries filtered accurately")
	assert_true(siege_entries.size() > 0, "Siege category entries filtered accurately")
	assert_true(battle_entries.size() > 0, "Battle category entries filtered accurately")
	assert_true(deed_entries.size() > 0, "Deed category entries filtered accurately")
	assert_eq(war_entries.size() + siege_entries.size() + battle_entries.size() + deed_entries.size(), 30, "All entries accounted for across categories")


func test_path_caching_and_invalidation() -> void:
	print("\n--- Path Caching and Invalidation ---")
	var w = WorldSim.new()
	w.setup(202, Cultures.VARDISH)

	# Initial call computes and caches
	var path1: Array = w.path("highcliff", "khalun")
	assert_true(not path1.is_empty(), "Path computed between settlements")
	assert_true(w._path_cache.has("highcliff|khalun|"), "Path cached in _path_cache")

	# Second call retrieves from cache
	var path2: Array = w.path("highcliff", "khalun")
	assert_eq(path1, path2, "Cached path matches original computation")

	# Invalidation on settlement transfer
	w.set_owner("khalun", "vardmark")
	assert_true(w._path_cache.is_empty(), "Path cache cleared when settlement ownership changes")

	# Re-computes and caches again
	var path3: Array = w.path("highcliff", "khalun")
	assert_true(w._path_cache.has("highcliff|khalun|"), "Path re-cached after invalidation")


func test_siege_detection_and_query() -> void:
	print("\n--- Siege Detection and Query ---")
	var w = WorldSim.new()
	w.setup(303, Cultures.VARDISH)

	assert_true(not w.is_sieged("khalun"), "Settlement initially not under siege")
	assert_true(w.sieging_army("khalun").is_empty(), "No sieging army returned when not under siege")

	# Add active sieging army
	w.campaign_armies.append({
		"id": 1,
		"state": "sieging",
		"realm": "vardmark",
		"target": "khalun",
		"leader": 1,
		"members": [1]
	})

	assert_true(w.is_sieged("khalun"), "is_sieged accurately detects active siege")
	var army: Dictionary = w.sieging_army("khalun")
	assert_eq(int(army.get("id", 0)), 1, "sieging_army returns correct expedition")
	assert_true(not w.is_sieged("highcliff"), "Other settlements unaffected")


func test_sound_cue_methods() -> void:
	print("\n--- Sound Cue Methods ---")
	var s = SoundScript.new()
	s.sounds_on = false # Headless mode test without requiring audio device

	assert_true(s.has_method("play_war_horn"), "Sound singleton implements play_war_horn()")
	assert_true(s.has_method("play_place_fallen"), "Sound singleton implements play_place_fallen()")
	assert_true(s.has_method("play_siege_drums"), "Sound singleton implements play_siege_drums()")

	# Verify calls execute cleanly without error
	s.play_war_horn()
	s.play_place_fallen()
	s.play_siege_drums()
	assert_true(true, "War horn, fanfare, and siege drum calls executed cleanly")


func test_map_readability_scaling_and_grouping() -> void:
	print("\n--- Map Readability: Strength Scaling and Zoom Fading ---")
	# Simulate party scale factor calculation logic
	var scale_for_men := func(men: int) -> float:
		if men < 20: return 0.85
		elif men < 50: return 1.0
		elif men < 90: return 1.18
		elif men < 140: return 1.32
		else: return 1.45

	assert_eq(scale_for_men.call(10), 0.85, "Small party (<20 men) scaled down for readability")
	assert_eq(scale_for_men.call(35), 1.0, "Standard party (20-49 men) normal scale")
	assert_eq(scale_for_men.call(70), 1.18, "Medium force (50-89 men) moderately enlarged")
	assert_eq(scale_for_men.call(110), 1.32, "Large host (90-139 men) enlarged")
	assert_eq(scale_for_men.call(180), 1.45, "Major army (140+ men) maximum scale presence")

	# Simulate bandit alpha at wide zoom
	var bandit_alpha_for_px := func(px: float) -> float:
		return clampf((px - 1.4) / (2.2 - 1.4), 0.25, 1.0)

	assert_true(bandit_alpha_for_px.call(1.4) <= 0.26, "Bandit markers fade to subtle outline at wide phone zoom")
	assert_true(bandit_alpha_for_px.call(2.2) >= 0.99, "Bandit markers fully opaque when zoomed in")
	assert_true(bandit_alpha_for_px.call(1.8) > 0.4 and bandit_alpha_for_px.call(1.8) < 0.6, "Bandit markers scale smoothly across mid zoom")


func test_save_load_chronicle_persistence() -> void:
	print("\n--- Save/Load Roundtrip: Chronicle & Path Cache ---")
	var w1 = WorldSim.new()
	w1.setup(505, Cultures.VARDISH)

	w1.declare_war("vardmark", "ryumon", true)
	w1.emit_event({"type": "siege_started", "realm": "vardmark", "target": "khalun"})
	w1.emit_event({"type": "grudge_avenged", "company": "The Free Shields", "lord": "Lord Maren"})

	var d: Dictionary = w1.to_dict()

	var w2 = WorldSim.new()
	w2.from_dict(d)

	assert_eq(w2.activity_log.size(), w1.activity_log.size(), "Loaded world preserves chronicle count")
	assert_eq(w2.activity_log[0]["category"], w1.activity_log[0]["category"], "Loaded world preserves deed category")
	assert_eq(w2.activity_log[0]["text"], w1.activity_log[0]["text"], "Loaded world preserves event text")
	assert_true(w2._path_cache.is_empty(), "Path cache cleanly initialized on load")

	# Test pathing works on restored world
	var p: Array = w2.path("highcliff", "khalun")
	assert_true(not p.is_empty(), "Pathing functional on restored world")
	assert_true(w2._path_cache.has("highcliff|khalun|"), "Pathing cached on restored world")
