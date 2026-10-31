extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const Troops = preload("res://scripts/data/troops.gd")
const Captains = preload("res://scripts/data/captains.gd")
const Cultures = preload("res://scripts/data/cultures.gd")

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
	print("\nRunning Casual Mode Tests (Phase 5.2)...")
	test_default_mode()
	test_iron_company_mortality()
	test_casual_mode_wound_interception()
	test_wound_recovery_countdown()
	test_regular_casualties_in_casual_mode()
	test_save_load_casual_mode()

	print("\nCasual Mode Tests finished: %d passed, %d failed" % [passed, failed])
	if failed > 0:
		quit(1)
	else:
		quit(0)


func test_default_mode() -> void:
	print("\n--- Default Campaign Mode ---")
	var gs = GameStateScript.new()
	gs.persist = false
	gs.new_warband()
	assert_true(not gs.casual_mode, "Default mode is Iron Company (casual_mode == false)")


func test_iron_company_mortality() -> void:
	print("\n--- Iron Company: Death Roll Mortality ---")
	var gs = GameStateScript.new()
	gs.persist = false
	gs.new_warband()
	gs.casual_mode = false

	var squad: Dictionary = gs.army[0]
	var captain: Dictionary = squad["captain"]
	var orig_name: String = captain["name"]
	var orig_id: int = captain["id"]

	# Simulate battle where captain fails death roll ("killed")
	var result := {
		"won": false,
		"lost": 4,
		"killed": 2,
		"squads": {
			int(squad["id"]): {
				"men": int(squad["men"]) - 4,
				"captain": {
					"fate": "killed",
					"roll": 10,
					"needed": 45,
					"words": "Remember me."
				}
			}
		}
	}
	gs.apply_result(result)

	assert_eq(gs.fallen.size(), 1, "Fallen captain added to memorial in Iron Company mode")
	assert_eq(String(gs.fallen[0]["name"]), orig_name, "Memorial records fallen captain's name")
	var new_cap = squad.get("captain")
	assert_true(new_cap != null, "Squad promotes a veteran from the ranks")
	assert_true(int(new_cap["id"]) != orig_id, "New captain takes command")


func test_casual_mode_wound_interception() -> void:
	print("\n--- Casual Mode: Severe Wound Interception ---")
	var gs = GameStateScript.new()
	gs.persist = false
	gs.new_warband()
	gs.casual_mode = true

	var squad: Dictionary = gs.army[0]
	var captain: Dictionary = squad["captain"]
	var orig_name: String = captain["name"]
	var orig_id: int = captain["id"]

	# Simulate battle where captain would have died ("killed" roll)
	var result := {
		"won": false,
		"lost": 4,
		"killed": 2,
		"squads": {
			int(squad["id"]): {
				"men": int(squad["men"]) - 4,
				"captain": {
					"fate": "killed",
					"roll": 10,
					"needed": 45,
					"words": "Hold without me!"
				}
			}
		}
	}
	gs.apply_result(result)

	assert_eq(gs.fallen.size(), 0, "No captain added to memorial in Casual Mode")
	assert_eq(int(squad["captain"]["id"]), orig_id, "Captain remains in command of their squad")
	assert_eq(int(squad["captain"]["wounded"]), Captains.CASUAL_WOUND_BATTLES, "Captain sits out 3 battles due to severe injury")
	var scars: Array = squad["captain"].get("history", {}).get("scars", [])
	assert_true(not scars.is_empty(), "Lasting battle wound scar logged in captain history")
	assert_true("Grievous Battle Wound" in scars[0], "Scar describes severe battle wound")


func test_wound_recovery_countdown() -> void:
	print("\n--- Casual Mode: Wound Countdown Across Battles ---")
	var gs = GameStateScript.new()
	gs.persist = false
	gs.new_warband()
	gs.casual_mode = true

	var squad: Dictionary = gs.army[0]
	var captain: Dictionary = squad["captain"]
	captain["wounded"] = 3

	# Battle 1 where captain sits out
	var r1 := {
		"won": true, "lost": 0, "killed": 5,
		"squads": { int(squad["id"]): {"men": int(squad["men"])} }
	}
	gs.apply_result(r1)
	assert_eq(int(captain["wounded"]), 2, "Wound duration decrements by 1 after sitting out (2 left)")

	# Battle 2 where captain sits out
	gs.apply_result(r1)
	assert_eq(int(captain["wounded"]), 1, "Wound duration decrements by 1 after sitting out (1 left)")

	# Battle 3 where captain sits out
	gs.apply_result(r1)
	assert_eq(int(captain["wounded"]), 0, "Captain fully recovered and ready to fight again")


func test_regular_casualties_in_casual_mode() -> void:
	print("\n--- Regular Troop Losses in Casual Mode ---")
	var gs = GameStateScript.new()
	gs.persist = false
	gs.new_warband()
	gs.casual_mode = true

	var squad: Dictionary = gs.army[0]
	var initial_men: int = squad["men"]

	# Regular soldiers still take casualties under standard rules (50% dead, 50% wounded)
	var lost := 8
	var end_men := initial_men - lost
	var result := {
		"won": true, "lost": lost, "killed": 12,
		"squads": { int(squad["id"]): {"men": end_men} }
	}
	gs.apply_result(result)

	assert_eq(int(squad["men"]), end_men, "Regular soldier combat strength reduced")
	assert_eq(int(squad["wounded"]), 4, "Half of regular casualties are wounded in baggage")


func test_save_load_casual_mode() -> void:
	print("\n--- Save/Load Roundtrip: Casual Mode Setting ---")
	var gs = GameStateScript.new()
	gs.persist = false
	gs.new_warband()
	gs.casual_mode = true
	gs.army[0]["captain"]["history"]["scars"] = ["Scar of Ravensford"]

	var saved := gs.to_dict()
	assert_true(saved.has("casual_mode"), "to_dict includes casual_mode")
	assert_eq(saved["casual_mode"], true, "to_dict stores casual_mode == true")

	var loaded_gs = GameStateScript.new()
	loaded_gs.persist = false
	loaded_gs.from_dict(saved)
	assert_true(loaded_gs.casual_mode, "from_dict restores casual_mode == true")
	var scars: Array = loaded_gs.army[0]["captain"]["history"].get("scars", [])
	assert_eq(scars.size(), 1, "Captain scars preserved through save/load")
	assert_eq(scars[0], "Scar of Ravensford", "Exact scar name preserved")
