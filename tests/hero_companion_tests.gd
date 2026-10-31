extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const Heroes = preload("res://scripts/data/heroes.gd")
const Captains = preload("res://scripts/data/captains.gd")
const Cultures = preload("res://scripts/data/cultures.gd")
const Troops = preload("res://scripts/data/troops.gd")

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
	print("\nRunning Hero Companion & Bond Polish Tests (Phases 5.4 & 5.5)...")
	test_hero_definitions()
	test_settlement_tavern_presence()
	test_hero_recruitment()
	test_hero_uniqueness_enforcement()
	test_save_load_hero_persistence()
	test_bond_reflection_vignettes()

	print("\nHero Companion & Bond Polish Tests finished: %d passed, %d failed" % [passed, failed])
	if failed > 0:
		quit(1)
	else:
		quit(0)


func test_hero_definitions() -> void:
	print("\n--- Authored Hero Definitions ---")
	assert_true(Heroes.HEROES.has(Heroes.KATHERINE), "Sir Katherine defined in heroes")
	assert_true(Heroes.HEROES.has(Heroes.TARIQ), "Tariq Windrunner defined in heroes")
	assert_true(Heroes.HEROES.has(Heroes.MORI), "Mori the Unbroken defined in heroes")

	var k := Heroes.hero(Heroes.KATHERINE)
	assert_eq(k["culture"], Cultures.VARDISH, "Katherine is Vardish")
	assert_eq(k["origin_settlement"], "highcliff", "Katherine originates in Highcliff")
	assert_eq(k["specialization"], Captains.DRILLMASTER, "Katherine is a Drillmaster")

	var t := Heroes.hero(Heroes.TARIQ)
	assert_eq(t["culture"], Cultures.KHARZANI, "Tariq is Kharzani")
	assert_eq(t["origin_settlement"], "khalun", "Tariq originates in Khalun")
	assert_eq(t["specialization"], Captains.SCOUT, "Tariq is a Scout")

	var m := Heroes.hero(Heroes.MORI)
	assert_eq(m["culture"], Cultures.RYUMON, "Mori is Ryumon")
	assert_eq(m["origin_settlement"], "kurogane", "Mori originates in Kurogane")
	assert_eq(m["specialization"], Captains.CHAMPION, "Mori is a Champion")


func test_settlement_tavern_presence() -> void:
	print("\n--- Tavern Spawning by Settlement ---")
	var gs = GameStateScript.new()
	gs.persist = false
	gs.new_warband()

	var highcliff_heroes := gs.available_heroes_at("highcliff")
	assert_eq(highcliff_heroes.size(), 1, "Highcliff offers 1 hero")
	assert_eq(highcliff_heroes[0]["id"], Heroes.KATHERINE, "Katherine available at Highcliff")

	var khalun_heroes := gs.available_heroes_at("khalun")
	assert_eq(khalun_heroes.size(), 1, "Khalun offers 1 hero")
	assert_eq(khalun_heroes[0]["id"], Heroes.TARIQ, "Tariq available at Khalun")

	var kurogane_heroes := gs.available_heroes_at("kurogane")
	assert_eq(kurogane_heroes.size(), 1, "Kurogane offers 1 hero")
	assert_eq(kurogane_heroes[0]["id"], Heroes.MORI, "Mori available at Kurogane")

	var other_heroes := gs.available_heroes_at("ravensford")
	assert_eq(other_heroes.size(), 0, "No heroes wandering at generic settlement")


func test_hero_recruitment() -> void:
	print("\n--- Hero Recruitment Mechanics ---")
	var gs = GameStateScript.new()
	gs.persist = false
	gs.new_warband()
	gs.silver = 500
	var prev_army_size: int = gs.army.size()

	# Recruit Katherine
	var ok := gs.recruit_hero(Heroes.KATHERINE)
	assert_true(ok, "Successfully recruited Katherine")
	assert_eq(gs.army.size(), prev_army_size + 1, "Army squad count increased by 1")
	assert_eq(gs.silver, 500 - 250, "Silver deducted for Katherine's hiring cost")
	assert_true(gs.hired_heroes.has(Heroes.KATHERINE), "Katherine recorded in hired_heroes")

	var hero_squad: Dictionary = gs.army[gs.army.size() - 1]
	var cap: Dictionary = hero_squad["captain"]
	assert_true(bool(cap.get("is_hero", false)), "Captain flagged as is_hero")
	assert_eq(String(cap.get("hero_id", "")), Heroes.KATHERINE, "Captain hero_id set to katherine")
	assert_eq(String(cap.get("specialization", "")), Captains.DRILLMASTER, "Katherine carries Drillmaster specialization")
	assert_true(gs.has_specialization(Captains.DRILLMASTER), "Company now benefits from Katherine's Drillmaster specialization")


func test_hero_uniqueness_enforcement() -> void:
	print("\n--- Hero Uniqueness Enforcement ---")
	var gs = GameStateScript.new()
	gs.persist = false
	gs.new_warband()
	gs.silver = 1000

	gs.recruit_hero(Heroes.KATHERINE)
	# Katherine should no longer appear at Highcliff
	var highcliff_after := gs.available_heroes_at("highcliff")
	assert_eq(highcliff_after.size(), 0, "Katherine no longer available at Highcliff once recruited")

	# Cannot recruit again
	var duplicate_ok := gs.recruit_hero(Heroes.KATHERINE)
	assert_true(not duplicate_ok, "Cannot recruit duplicate hero")


func test_save_load_hero_persistence() -> void:
	print("\n--- Save/Load Roundtrip: Hired Heroes & Hero Captains ---")
	var gs = GameStateScript.new()
	gs.persist = false
	gs.new_warband()
	gs.silver = 1000
	gs.recruit_hero(Heroes.TARIQ)

	var saved := gs.to_dict()
	assert_true(saved.has("hired_heroes"), "to_dict includes hired_heroes")
	assert_true(Heroes.TARIQ in saved["hired_heroes"], "Tariq recorded in saved hired_heroes")

	var loaded_gs = GameStateScript.new()
	loaded_gs.persist = false
	loaded_gs.from_dict(saved)

	assert_true(loaded_gs.hired_heroes.has(Heroes.TARIQ), "Loaded game retains Tariq in hired_heroes")
	var loaded_tariq := loaded_gs.available_heroes_at("khalun")
	assert_eq(loaded_tariq.size(), 0, "Tariq remains unavailable in tavern after load")

	var loaded_squad: Dictionary = loaded_gs.army[loaded_gs.army.size() - 1]
	var loaded_cap: Dictionary = loaded_squad["captain"]
	assert_true(bool(loaded_cap.get("is_hero", false)), "Loaded captain retains is_hero flag")
	assert_eq(String(loaded_cap.get("hero_id", "")), Heroes.TARIQ, "Loaded captain retains hero_id")
	assert_eq(String(loaded_cap.get("specialization", "")), Captains.SCOUT, "Loaded captain retains Scout specialization")


func test_bond_reflection_vignettes() -> void:
	print("\n--- Bond Reflection Vignettes (Phase 5.5) ---")
	var gs = GameStateScript.new()
	gs.persist = false
	gs.new_warband()

	var a: Dictionary = gs.army[0]["captain"]
	var b: Dictionary = gs.army[1]["captain"]

	# Set bond to Rank C (5.0 points)
	a["bonds"][str(b["id"])] = 6.0
	b["bonds"][str(a["id"])] = 6.0

	var conv_c := gs.bond_conversation(int(a["id"]), int(b["id"]))
	assert_true(not conv_c.is_empty(), "Bond conversation generated for Rank C pair")
	assert_eq(conv_c["rank"], "C", "Conversation reflects Rank C")
	var passages_c: Array = conv_c["passages"]
	var has_c_vignette := false
	for p in passages_c:
		if "Rank C" in String(p):
			has_c_vignette = true
	assert_true(has_c_vignette, "Passages include authored Rank C reflection vignette")

	# Set bond to Rank A (24.0 points)
	a["bonds"][str(b["id"])] = 24.0
	b["bonds"][str(a["id"])] = 24.0
	var conv_a := gs.bond_conversation(int(a["id"]), int(b["id"]))
	assert_eq(conv_a["rank"], "A", "Conversation reflects Rank A")
	var has_a_vignette := false
	for p in conv_a["passages"]:
		if "Rank A" in String(p):
			has_a_vignette = true
	assert_true(has_a_vignette, "Passages include authored Rank A reflection vignette")
