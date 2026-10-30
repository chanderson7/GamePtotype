## Test suite for Phase 4.4: War and peace (politics, weariness, truces, tribute, balance of power).
extends SceneTree

const WorldSim = preload("res://scripts/world/world_sim.gd")
const WorldData = preload("res://scripts/world/world_data.gd")
const Politics = preload("res://scripts/data/politics.gd")
const Lords = preload("res://scripts/data/lords.gd")

var _passes := 0
var _failures := 0


func _init() -> void:
	print("Running Politics Tests (Phase 4.4)...")
	_test_weariness_accumulation()
	_test_weariness_peace_decay()
	_test_peace_and_truce()
	_test_truce_blocks_war()
	_test_tribute_payments()
	_test_balance_of_power()
	_test_saveload_roundtrip()

	print("\nPolitics Tests finished: %d passed, %d failed" % [_passes, _failures])
	quit(1 if _failures > 0 else 0)


func _expect(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
		print("  ok    %s" % msg)
	else:
		_failures += 1
		printerr("  FAIL: %s" % msg)


func _test_weariness_accumulation() -> void:
	print("\n--- Weariness Accumulation ---")
	var w = WorldSim.new()
	w.setup(42, "vardmark")

	_expect(w.weariness_of("vardmark") == 0.0, "initial weariness is 0.0")

	# Casualties in battle
	w.add_weariness("vardmark", 20.0 * Politics.WEARINESS_CASUALTY)
	_expect(is_equal_approx(w.weariness_of("vardmark"), 1.0), "20 casualties add 1.0 weariness")

	# Lost settlement
	w.set_owner("marchgate", "kharzan")
	_expect(is_equal_approx(w.weariness_of("vardmark"), 1.0 + Politics.WEARINESS_LOST_HOLDING),
		"lost castle adds WEARINESS_LOST_HOLDING (15.0)")
	_expect(is_equal_approx(w.weariness_of("kharzan"), 0.0), "capturing realm does not go below 0")

	# Burned village
	var l = w.lords[0]
	w.set_owner("bramblemoor", "vardmark")
	var pre_wear := w.weariness_of("vardmark")
	w._burn(l, "bramblemoor")
	_expect(is_equal_approx(w.weariness_of("vardmark"), pre_wear + Politics.WEARINESS_LOST_VILLAGE),
		"burned village adds WEARINESS_LOST_VILLAGE (3.0)")

	# Routed lord
	var p = w.party(int(l["party"]))
	if p != null:
		var pre_routed := w.weariness_of(String(l["realm"]))
		w._routed(p)
		_expect(is_equal_approx(w.weariness_of(String(l["realm"])), pre_routed + Politics.WEARINESS_LORD_ROUTED),
			"routed lord adds WEARINESS_LORD_ROUTED (5.0)")


func _test_weariness_peace_decay() -> void:
	print("\n--- Weariness Peace Decay ---")
	var w = WorldSim.new()
	w.setup(101, "vardmark")
	w.make_peace("vardmark", "kharzan")

	w.add_weariness("vardmark", 10.0)
	_expect(is_equal_approx(w.weariness_of("vardmark"), 10.0), "weariness set to 10.0")

	w._politics_day()
	_expect(is_equal_approx(w.weariness_of("vardmark"), 10.0 - Politics.WEARINESS_PEACE_DECAY),
		"peaceful realm decays weariness by WEARINESS_PEACE_DECAY per day")


func _test_peace_and_truce() -> void:
	print("\n--- Peace and Truce ---")
	var w = WorldSim.new()
	w.setup(202, "vardmark")

	# Both at war
	_expect(w.at_war("vardmark", "kharzan"), "initially at war")

	# Push Vardmark weariness above PEACE_THRESHOLD
	w.add_weariness("vardmark", Politics.PEACE_THRESHOLD + 10.0)
	w.add_weariness("kharzan", 45.0) # Not fresh, will accept

	w._evaluate_peace()
	_expect(not w.at_war("vardmark", "kharzan"), "weary realm successfully signs peace")
	_expect(w.has_truce("vardmark", "kharzan"), "peace establishes an active truce")
	_expect(not w.tributes.is_empty(), "tribute agreement created on peace treaty")
	_expect(w.tributes[0]["from"] == "vardmark", "wearier realm pays tribute")
	_expect(w.tributes[0]["to"] == "kharzan", "fresher realm receives tribute")


func _test_truce_blocks_war() -> void:
	print("\n--- Truce Enforcement ---")
	var w = WorldSim.new()
	w.setup(303, "vardmark")
	w.make_peace("vardmark", "kharzan", Politics.TRUCE_DAYS)

	_expect(w.has_truce("vardmark", "kharzan"), "truce active immediately after peace")

	# Attempt to declare war during truce
	w.declare_war("vardmark", "kharzan")
	_expect(not w.at_war("vardmark", "kharzan"), "declare_war blocked by active truce")

	# Advance time past truce
	w.hour += (Politics.TRUCE_DAYS + 1) * 24.0
	_expect(not w.has_truce("vardmark", "kharzan"), "truce expired after 30+ days")

	# Now war can be declared
	w.declare_war("vardmark", "kharzan")
	_expect(w.at_war("vardmark", "kharzan"), "war declared successfully after truce expired")


func _test_tribute_payments() -> void:
	print("\n--- Tribute Payments ---")
	var w = WorldSim.new()
	w.setup(404, "vardmark")
	w.make_peace("vardmark", "kharzan", Politics.TRUCE_DAYS, 30, "vardmark", 5)

	var vm_treasury_start: int = int(w.realms["vardmark"]["treasury"])
	var kz_treasury_start: int = int(w.realms["kharzan"]["treasury"])

	w._politics_day()
	_expect(int(w.realms["vardmark"]["treasury"]) == vm_treasury_start - 30, "debtor treasury deducted daily tribute")
	_expect(int(w.realms["kharzan"]["treasury"]) == kz_treasury_start + 30, "creditor treasury credited daily tribute")
	_expect(w.tributes[0]["days_left"] == 4, "tribute days remaining decremented")


func _test_balance_of_power() -> void:
	print("\n--- Balance of Power (Ryumon Intervention) ---")
	var w = WorldSim.new()
	w.setup(505, "vardmark")

	_expect(not w.at_war("ryumon", "vardmark"), "Ryumon starts at peace with Vardmark")
	_expect(not w.at_war("ryumon", "kharzan"), "Ryumon starts at peace with Kharzan")

	# Vardmark holds 3 mainland seats initially: highcliff, ravensford, marchgate
	_expect(w.mainland_seats_of("vardmark") == 3, "Vardmark initially holds 3 mainland seats")

	# Vardmark captures a 4th mainland seat (khalun)
	w.set_owner("khalun", "vardmark")
	_expect(w.mainland_seats_of("vardmark") == 4, "Vardmark now holds 4 mainland seats")

	w._evaluate_balance_of_power()
	_expect(w.at_war("ryumon", "vardmark"), "Ryumon declares war on Vardmark to preserve balance of power")
	_expect(not w.at_war("ryumon", "kharzan"), "Ryumon remains at peace with Kharzan")


func _test_saveload_roundtrip() -> void:
	print("\n--- Save/Load Roundtrip ---")
	var w = WorldSim.new()
	w.setup(606, "vardmark")
	w.add_weariness("vardmark", 35.5)
	w.make_peace("vardmark", "kharzan", 25, 40, "vardmark", 15)

	var saved := JSON.stringify(w.to_dict())
	var copy = WorldSim.new()
	copy.from_dict(JSON.parse_string(saved))
	var restored := JSON.stringify(copy.to_dict())

	_expect(saved == restored, "JSON save/load produces identical string representation")
	_expect(is_equal_approx(copy.weariness_of("vardmark"), 35.5), "weariness preserved across save/load")
	_expect(copy.has_truce("vardmark", "kharzan"), "truce preserved across save/load")
	_expect(copy.tributes.size() == 1 and copy.tributes[0]["daily"] == 40, "tribute preserved across save/load")
