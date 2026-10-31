extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const Troops = preload("res://scripts/data/troops.gd")
const Captains = preload("res://scripts/data/captains.gd")
const Cultures = preload("res://scripts/data/cultures.gd")
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
	print("\nRunning Casualty and Healing Tests (Phase 5.1)...")
	test_casualty_split()
	test_headcount_and_upkeep()
	test_healing_on_road()
	test_healing_while_resting()
	test_reinforcement_clears_wounded()
	test_save_load_wounded_persistence()

	print("\nCasualty and Healing Tests finished: %d passed, %d failed" % [passed, failed])
	if failed > 0:
		quit(1)
	else:
		quit(0)


func test_casualty_split() -> void:
	print("\n--- Casualty Split: Killed vs Wounded ---")
	var gs = GameStateScript.new()
	gs.persist = false
	gs.new_warband()

	var squad: Dictionary = gs.army[0]
	var initial_men: int = squad["men"]
	assert_true(initial_men > 0, "Squad has men initially")
	assert_eq(int(squad.get("wounded", 0)), 0, "Squad starts with 0 wounded")

	# Simulate battle result where squad loses 6 men (end_men = initial_men - 6)
	var lost := 6
	var end_men := initial_men - lost
	var fake_result := {
		"won": true,
		"lost": lost,
		"killed": 10,
		"squads": {
			int(squad["id"]): {"men": end_men, "kills": 2}
		}
	}
	gs.apply_result(fake_result)

	assert_eq(int(squad["men"]), end_men, "Combat deployable men updated to surviving count")
	# 50% of 6 is 3 wounded
	assert_eq(int(squad["wounded"]), 3, "Half of troop losses (3) recorded as wounded in baggage")
	assert_eq(gs.total_wounded(), 3, "total_wounded() reflects 3 wounded soldiers")
	assert_eq(gs.total_headcount(), gs.total_men() + 3, "total_headcount() equals deployable men + wounded")
	assert_true(gs.is_wounded(), "is_wounded() is true when squad has wounded soldiers")


func test_headcount_and_upkeep() -> void:
	print("\n--- Headcount, Food, and Wages Upkeep ---")
	var gs = GameStateScript.new()
	gs.persist = false
	gs.new_warband()

	var squad: Dictionary = gs.army[0]
	squad["men"] = 10
	squad["wounded"] = 4
	# Deployable: 10 + other squads; Headcount: +4
	var base_wages := gs.daily_wages()
	assert_true(base_wages > 0, "Daily wages calculated")

	# Headcount is fed and paid
	var prev_food := 500
	gs.food = prev_food
	gs.silver = 1000
	var head := gs.total_headcount()
	gs._upkeep()

	assert_eq(gs.food, prev_food - head, "Upkeep consumed rations for total headcount including wounded")


func test_healing_on_road() -> void:
	print("\n--- Natural Healing: Road Ticks ---")
	var gs = GameStateScript.new()
	gs.persist = false
	gs.new_warband()
	var w = preload("res://scripts/world/world_sim.gd").new()
	w.setup(42, Cultures.VARDISH)
	gs.world = w

	# Set player party as marching on the road
	var p = w.player()
	p.next = "ravensford"
	p.wait = 0.0
	assert_true(not gs.is_resting(), "Player is marching on the road (not resting)")

	var squad: Dictionary = gs.army[0]
	squad["men"] = 8
	squad["wounded"] = 2

	# 6 hours on the road: speed mult is 1.0, accumulates 6 hours -> not enough for 12h tick
	gs._tick_healing(6.0)
	assert_eq(int(squad["wounded"]), 2, "6 hours on road is not enough to heal (requires 12 hours)")
	assert_eq(int(squad["men"]), 8, "Deployable men unchanged before 12h mark")

	# Advance another 6 hours (total 12 hours on road)
	gs._tick_healing(6.0)
	assert_eq(int(squad["wounded"]), 1, "After 12 hours on road, 1 wounded soldier is healed")
	assert_eq(int(squad["men"]), 9, "Healed soldier returns to active combat men")

	# Advance another 12 hours (total 24 hours)
	gs._tick_healing(12.0)
	assert_eq(int(squad["wounded"]), 0, "After second 12h cycle, remaining wounded soldier is healed")
	assert_eq(int(squad["men"]), 10, "All recovered soldiers returned to ranks")
	assert_eq(gs.total_wounded(), 0, "No wounded remaining in warband")


func test_healing_while_resting() -> void:
	print("\n--- Accelerated Healing: Resting in Camp / Settlement ---")
	var gs = GameStateScript.new()
	gs.persist = false
	gs.new_warband()

	var squad: Dictionary = gs.army[0]
	squad["men"] = 6
	squad["wounded"] = 2

	# When world is null or player not moving, is_resting() is true (2x healing speed)
	assert_true(gs.is_resting(), "Player is considered resting when in camp / stopped")

	# Resting heals 1 man every 6 hours
	gs._tick_healing(6.0)
	assert_eq(int(squad["wounded"]), 1, "Resting heals 1 man in 6 hours (double road speed)")
	assert_eq(int(squad["men"]), 7, "Recovered man added to combat roster")

	gs._tick_healing(6.0)
	assert_eq(int(squad["wounded"]), 0, "Second 6h rest cycle heals second wounded soldier")
	assert_eq(int(squad["men"]), 8, "Both wounded men fully recovered")


func test_reinforcement_clears_wounded() -> void:
	print("\n--- Town Reinforcement ---")
	var gs = GameStateScript.new()
	gs.persist = false
	gs.new_warband()

	var squad: Dictionary = gs.army[0]
	var full := Troops.full_size(squad["type"])
	squad["men"] = full - 4
	squad["wounded"] = 2
	gs.silver = 500

	# Reinforcing in town fills to full and clears wounded to 0
	var ok := gs.reinforce_squad(int(squad["id"]))
	assert_true(ok, "Squad reinforced in town")
	assert_eq(int(squad["men"]), full, "Squad men restored to full capacity")
	assert_eq(int(squad["wounded"]), 0, "Wounded troops cleared/treated upon reinforcement")


func test_save_load_wounded_persistence() -> void:
	print("\n--- Save/Load Roundtrip: Wounded Soldiers & Heal Clock ---")
	var gs = GameStateScript.new()
	gs.persist = false
	gs.new_warband()

	gs.army[0]["men"] = 7
	gs.army[0]["wounded"] = 3
	gs.army[1]["men"] = 9
	gs.army[1]["wounded"] = 1
	gs._heal_clock = 5.5

	var saved := gs.to_dict()
	assert_true(saved.has("heal_clock"), "to_dict includes heal_clock")
	assert_eq(saved["heal_clock"], 5.5, "to_dict stores correct heal_clock value")

	var loaded_gs = GameStateScript.new()
	loaded_gs.persist = false
	var load_ok := loaded_gs.from_dict(saved)
	assert_true(load_ok, "from_dict succeeds")
	assert_eq(int(loaded_gs.army[0]["wounded"]), 3, "Loaded squad 0 retains 3 wounded")
	assert_eq(int(loaded_gs.army[1]["wounded"]), 1, "Loaded squad 1 retains 1 wounded")
	assert_eq(loaded_gs.total_wounded(), 4, "total_wounded() matches saved state")
	assert_eq(loaded_gs._heal_clock, 5.5, "_heal_clock restored accurately")
