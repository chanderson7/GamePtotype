## Test suite for Slice 4.5.1: Standing & Mercenary contracts.
extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const WorldSim = preload("res://scripts/world/world_sim.gd")
const WorldData = preload("res://scripts/world/world_data.gd")
const Cultures = preload("res://scripts/data/cultures.gd")

var _passes := 0
var _failures := 0


func _init() -> void:
	print("Running Mercenary & Standing Tests (Slice 4.5.1)...")
	_test_relations_basics()
	_test_contract_calculation_and_signing()
	_test_war_and_alliance_alignment()
	_test_contract_daily_upkeep()
	_test_break_contract()
	_test_saveload_persistence()
	_test_pay_follows_the_men()
	_test_reparations()

	print("\nMercenary Tests finished: %d passed, %d failed" % [_passes, _failures])
	quit(1 if _failures > 0 else 0)


func _expect(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
		print("  ok    %s" % msg)
	else:
		_failures += 1
		printerr("  FAIL: %s" % msg)


func _setup_gs() -> GameStateScript:
	var gs = GameStateScript.new()
	gs.persist = false
	gs.world = WorldSim.new()
	gs.world.setup(555, Cultures.VARDISH)
	gs.new_warband()
	gs.silver = 1000
	gs.food = 200
	gs.renown = 20
	return gs


func _test_relations_basics() -> void:
	print("\n--- Relations Basics ---")
	var gs := _setup_gs()

	_expect(gs.relation_with_realm("vardmark") == 0, "initial relation with Vardmark is 0")
	_expect(gs.relation_with_realm("kharzan") == 0, "initial relation with Kharzan is 0")

	gs.add_realm_relation("vardmark", 25)
	_expect(gs.relation_with_realm("vardmark") == 25, "relation with Vardmark increases by 25")

	gs.add_realm_relation("vardmark", 150)
	_expect(gs.relation_with_realm("vardmark") == 100, "relation clamps to maximum 100")

	gs.add_realm_relation("vardmark", -250)
	_expect(gs.relation_with_realm("vardmark") == -100, "relation clamps to minimum -100")

	# Lord relations
	_expect(gs.relation_with_lord(1) == 0, "initial lord relation is 0")
	gs.add_lord_relation(1, 40)
	_expect(gs.relation_with_lord(1) == 40, "lord relation updates to 40")


func _test_contract_calculation_and_signing() -> void:
	print("\n--- Contract Calculation & Signing ---")
	var gs := _setup_gs()
	gs.renown = 30 # gives 30 / 5 = 6 bonus
	var expected_pay := GameStateScript.CONTRACT_BASE_PAY + int(30 / 5) + int(gs.total_men() / 2)
	_expect(gs.calculate_contract_pay("vardmark") == expected_pay, "contract pay matches base + renown + troop strength")

	_expect(not gs.has_contract(), "initially has no contract")
	gs.sign_contract("vardmark")

	_expect(gs.has_contract(), "has active contract after signing")
	_expect(gs.contract_realm() == "vardmark", "contract realm is Vardmark")
	_expect(gs.contract.days_left == GameStateScript.CONTRACT_DAYS, "contract duration starts at 30 days")
	_expect(gs.contract_daily_pay() == expected_pay, "contract daily pay matches calculated pay")
	_expect(gs.relation_with_realm("vardmark") == 10, "signing contract grants +10 relation with employer")
	_expect(gs.relation_with_realm("kharzan") == -15, "signing contract penalizes -15 relation with employer's enemies")
	_expect(gs.world.player().faction == "vardmark", "player faction set to employer realm")


func _test_war_and_alliance_alignment() -> void:
	print("\n--- War & Alliance Alignment ---")
	var gs := _setup_gs()
	gs.sign_contract("vardmark")

	# Vardmark and Kharzan are at war
	_expect(gs.is_allied_with("vardmark"), "player is allied with employer Vardmark")
	_expect(gs.is_at_war_with("kharzan"), "player is at war with employer's enemy Kharzan")
	_expect(not gs.is_at_war_with("ryumon"), "player is at peace with neutral Ryumon")

	# World presentation query
	_expect(gs.world.relation_to_player("vardmark") == "friendly", "world reports Vardmark friendly to player")
	_expect(gs.world.relation_to_player("kharzan") == "hostile", "world reports Kharzan hostile to player")
	_expect(gs.world.relation_to_player("ryumon") == "neutral", "world reports Ryumon neutral to player")


func _test_contract_daily_upkeep() -> void:
	print("\n--- Daily Contract Upkeep ---")
	var gs := _setup_gs()
	gs.sign_contract("vardmark")

	var stipend := gs.contract_daily_pay()
	var start_silver := gs.silver
	var wages := gs.daily_wages()

	gs._upkeep()
	_expect(gs.silver == start_silver + stipend - wages, "daily upkeep credits contract pay and deducts wages")
	_expect(gs.contract.days_left == 29, "contract days remaining decrements to 29")

	# Advance to completion (remaining 29 days)
	for d in 29:
		gs._upkeep()

	_expect(not gs.has_contract(), "contract concludes after 30 days")
	_expect(gs.relation_with_realm("vardmark") == 20, "completing contract awards +10 relation in good standing")
	_expect(gs.world.player().faction == "", "player faction resets to neutral sellsword upon completion")


func _test_break_contract() -> void:
	print("\n--- Breaking Contract ---")
	var gs := _setup_gs()
	gs.sign_contract("vardmark")
	_expect(gs.relation_with_realm("vardmark") == 10, "relation after signing is 10")

	gs.break_contract()
	_expect(not gs.has_contract(), "contract cleared after resignation")
	_expect(gs.relation_with_realm("vardmark") == -15, "breaking contract inflicts -25 relation penalty")
	_expect(gs.world.player().faction == "", "player faction cleared after resignation")


func _test_saveload_persistence() -> void:
	print("\n--- Save/Load Roundtrip ---")
	var gs := _setup_gs()
	gs.sign_contract("kharzan")
	gs.add_lord_relation(42, 35)

	var d := gs.to_dict()
	var json_str := JSON.stringify(d)
	var loaded_dict = JSON.parse_string(json_str)

	var copy := GameStateScript.new()
	copy.persist = false
	copy.from_dict(loaded_dict)

	_expect(copy.has_contract(), "loaded game has active contract")
	_expect(copy.contract_realm() == "kharzan", "loaded contract realm is Kharzan")
	_expect(copy.contract_daily_pay() == gs.contract_daily_pay(), "loaded contract pay matches original")
	_expect(copy.relation_with_realm("kharzan") == 10, "loaded relation with Kharzan matches")
	_expect(copy.relation_with_lord(42) == 35, "loaded relation with lord 42 matches")
	_expect(copy.world.player().faction == "kharzan", "loaded player party faction matches employer")


## Contract pay is worked out each day from the men you bring to the field.
func _test_pay_follows_the_men() -> void:
	print("\n--- Contract Pay Follows the Men ---")
	var gs := _setup_gs()
	gs.sign_contract("vardmark")
	var signed := gs.contract_daily_pay()
	for sq in gs.army:
		sq["men"] = 1
	var expected := gs.calculate_contract_pay("vardmark")
	var start := gs.silver
	var wages := gs.daily_wages()
	gs._upkeep()
	_expect(expected < signed and gs.contract_daily_pay() == expected, "a warband cut down is paid for the men it has (%d, signed at %d)" % [expected, signed])
	_expect(gs.silver == start + expected - wages, "and that is what the day pays")


## A realm that bars you for your standing alone can be paid reparations: once a week, at
## a cost that grows with how far below the line you are, back to just above it.
func _test_reparations() -> void:
	print("\n--- Reparations ---")
	var gs := _setup_gs()
	_expect(not gs.is_at_war_with("ryumon") and gs.barred_by("ryumon") == "", "Ryumon doesn't bar a stranger")
	_expect(not gs.reparations_check("ryumon")["ok"], "and needs no reparations")
	gs.add_realm_relation("ryumon", -40)
	_expect(gs.is_at_war_with("ryumon") and gs.barred_by("ryumon") == "standing", "at -40 standing its gates are barred")
	var cost: int = gs.reparations_cost("ryumon")
	_expect(cost == GameStateScript.REPARATIONS_BASE + GameStateScript.REPARATIONS_PER_POINT * 20, "reparations cost more the further below the line (%d)" % cost)
	gs.add_realm_relation("ryumon", -40)
	_expect(gs.reparations_cost("ryumon") > cost, "and more again further down")
	gs.add_realm_relation("ryumon", 40)
	var purse := gs.silver
	var treasury: int = int(gs.world.realms["ryumon"]["treasury"])
	_expect(gs.pay_reparations("ryumon"), "an envoy pays them")
	_expect(gs.silver == purse - cost and int(gs.world.realms["ryumon"]["treasury"]) == treasury + cost, "the silver goes to their treasury")
	_expect(gs.relation_with_realm("ryumon") == GameStateScript.REPARATIONS_RELATION and not gs.is_at_war_with("ryumon"),
		"standing rises to just above the line, and the gates open")
	gs.add_realm_relation("ryumon", -30)
	var again: Dictionary = gs.reparations_check("ryumon")
	_expect(not again["ok"] and String(again["reason"]).contains("day"), "another envoy must wait a week")
	gs.world.hour += GameStateScript.REPARATIONS_DAYS * 24.0
	_expect(gs.reparations_check("ryumon")["ok"], "after which one can go again")
	gs.silver = 0
	_expect(not gs.reparations_check("ryumon")["ok"], "if you can pay")
	# A real war isn't mended with silver.
	gs.silver = 5000
	gs.sign_contract("vardmark")
	_expect(gs.barred_by("kharzan") == "employer" and not gs.reparations_check("kharzan")["ok"], "a war your employer fights can't be bought off")
