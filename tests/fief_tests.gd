extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const WorldSim = preload("res://scripts/world/world_sim.gd")
const WorldData = preload("res://scripts/world/world_data.gd")
const Cultures = preload("res://scripts/data/cultures.gd")
const Fiefs = preload("res://scripts/data/fiefs.gd")
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
	print("\nRunning Fiefdom & Vassalage Tests (Feature 12)...")
	test_fief_eligibility_and_fealty_grant()
	test_fief_daily_production_and_collection()
	test_garrison_management_and_healing()
	test_manor_improvements_and_reconstruction()
	test_fief_raid_defense()
	test_fief_loss_and_recapture()
	test_fief_recommendation_guidance()
	test_fief_save_load_roundtrip()
	test_fief_renunciation()

	print("\nFiefdom & Vassalage Tests finished: %d passed, %d failed" % [passed, failed])
	if failed > 0:
		quit(1)
	else:
		quit(0)


func _create_game_state() -> GameStateScript:
	var gs = GameStateScript.new()
	gs.persist = false
	var w := WorldSim.new()
	w.game_state = gs
	w.setup(1234, Cultures.VARDISH)
	w.parties = [w.player()]
	w._reindex_parties()
	gs.world = w
	gs.new_warband()
	gs.silver = 1000
	gs.food = 200
	gs.renown = 20
	return gs


func _advance_day(gs: GameStateScript) -> void:
	var left := 24.0
	while left > 0.0:
		var dt := minf(4.0, left)
		left -= dt
		gs.world.wait(dt)
		gs.advance(dt)
		if gs.world.encounter != -1:
			gs.world.encounter = -1


func test_fief_eligibility_and_fealty_grant() -> void:
	print("\n--- Fief Eligibility & Fealty Grant ---")
	var gs := _create_game_state()

	# 1. Under requirements
	assert_true(not gs.has_fief(), "Initially has no fief")
	assert_true(not gs.can_petition_fief("vardmark"), "Cannot petition fief with low renown/relation")

	# 2. Increase renown and relation to meet requirements
	gs.renown = 60
	gs.add_realm_relation("vardmark", 30)
	assert_true(gs.can_petition_fief("vardmark"), "Can petition fief with 60 renown and 30 relation")

	# 3. Available fief candidates
	var candidates: Array = gs.available_fiefs_for_grant("vardmark")
	assert_true(candidates.size() > 0, "Available fief candidates found in Vardmark")
	assert_true(candidates.has("kettlebrook"), "Kettlebrook village is available for grant")

	# 4. Sign mercenary contract first to verify conversion
	gs.sign_contract("vardmark")
	assert_true(gs.has_contract(), "Active contract signed")

	# 5. Accept fealty and fief grant
	var ok: bool = gs.accept_fealty_and_fief("kettlebrook", "vardmark")
	assert_true(ok, "Successfully swore fealty and received Kettlebrook")
	assert_true(gs.has_fief(), "Player now has a fief")
	assert_eq(gs.fief_id(), "kettlebrook", "Fief id is kettlebrook")
	assert_eq(gs.fief_realm(), "vardmark", "Fief realm is vardmark")
	assert_true(gs.is_player_fief("kettlebrook"), "is_player_fief returns true for kettlebrook")
	assert_true(not gs.is_player_fief("ashby"), "is_player_fief returns false for other settlements")
	assert_true(not gs.has_contract(), "Mercenary contract converted into permanent vassalage")
	assert_eq(gs.world.player().faction, "vardmark", "Player party faction is aligned with vardmark")


func test_fief_daily_production_and_collection() -> void:
	print("\n--- Daily Production & Tax Collection ---")
	var gs := _create_game_state()
	gs.renown = 60
	gs.add_realm_relation("vardmark", 30)
	gs.accept_fealty_and_fief("kettlebrook", "vardmark")

	var init_silver: int = int(gs.player_fief.get("silver", 0))
	var init_food: int = int(gs.player_fief.get("food", 0))

	# Advance 24 hours to trigger daily settle()
	_advance_day(gs)

	var daily_t: int = Fiefs.daily_tax(gs.player_fief)
	var daily_f: int = Fiefs.daily_food(gs.player_fief)
	assert_eq(int(gs.player_fief.get("silver", 0)), init_silver + daily_t, "Estate treasury accumulated daily taxes")
	assert_eq(int(gs.player_fief.get("food", 0)), init_food + daily_f, "Estate granary accumulated daily food")

	# Collect taxes
	var prev_purse: int = int(gs.silver)
	var tax_to_collect: int = int(gs.player_fief.get("silver", 0))
	var collected: int = gs.collect_fief_taxes()
	assert_eq(collected, tax_to_collect, "Collected full estate tax amount")
	assert_eq(int(gs.silver), prev_purse + collected, "Company purse credited with estate taxes")
	assert_eq(int(gs.player_fief.get("silver", 0)), 0, "Estate treasury emptied after collection")

	# Collect food
	var prev_rations: int = int(gs.food)
	var food_to_collect: int = int(gs.player_fief.get("food", 0))
	var collected_food: int = gs.collect_fief_food()
	assert_eq(collected_food, food_to_collect, "Collected full estate food amount")
	assert_eq(int(gs.food), prev_rations + collected_food, "Company rations credited with estate food")
	assert_eq(int(gs.player_fief.get("food", 0)), 0, "Estate granary emptied after collection")


func test_garrison_management_and_healing() -> void:
	print("\n--- Garrison Management & Soldier Healing ---")
	var gs := _create_game_state()
	gs.renown = 60
	gs.add_realm_relation("vardmark", 30)
	gs.accept_fealty_and_fief("kettlebrook", "vardmark")

	var initial_army_count: int = gs.army.size()
	assert_true(initial_army_count > 1, "Player has multiple squads")

	var squad_to_station: Dictionary = gs.army[0]
	var sid: int = int(squad_to_station["id"])
	squad_to_station["wounded"] = 2 # Add wounded soldiers to test garrison healing

	# Station in garrison
	var ok: bool = gs.station_squad_in_fief(sid)
	assert_true(ok, "Squad successfully stationed in fief garrison")
	assert_eq(gs.army.size(), initial_army_count - 1, "Warband squad count reduced by 1")
	assert_eq(gs.player_fief.get("garrison", []).size(), 1, "Fief garrison holds 1 squad")
	assert_eq(gs.world.garrisons.get("kettlebrook", []).size(), 1, "world.garrisons tracks stationed squad")

	# Advance 24 hours (triggers _fief_day garrison healing)
	var garr_squad: Dictionary = gs.player_fief["garrison"][0]
	assert_eq(int(garr_squad.get("wounded", 0)), 2, "Squad starts with 2 wounded")
	_advance_day(gs)
	assert_eq(int(garr_squad.get("wounded", 0)), 1, "1 wounded soldier healed in garrison over day")

	# Withdraw squad from garrison
	var withdrawn: bool = gs.withdraw_squad_from_fief(0)
	assert_true(withdrawn, "Squad successfully withdrawn from garrison into warband")
	assert_eq(gs.army.size(), initial_army_count, "Warband squad count restored")
	assert_eq(gs.player_fief.get("garrison", []).size(), 0, "Fief garrison empty after withdrawal")


func test_manor_improvements_and_reconstruction() -> void:
	print("\n--- Manor Improvements & Reconstruction ---")
	var gs := _create_game_state()
	gs.renown = 60
	gs.add_realm_relation("vardmark", 30)
	gs.accept_fealty_and_fief("kettlebrook", "vardmark")
	gs.silver = 2000

	# 1. Build Mill
	var mill_cost: int = int(Fiefs.IMPROVEMENTS[Fiefs.IMPROVEMENT_MILL]["cost"])
	var prev_silver: int = int(gs.silver)
	var r1: Dictionary = gs.build_fief_improvement(Fiefs.IMPROVEMENT_MILL)
	assert_true(r1.get("ok", false), "Built water mill improvement")
	assert_eq(int(gs.silver), prev_silver - mill_cost, "Deducted mill cost in silver")
	assert_true(bool(gs.player_fief["improvements"][Fiefs.IMPROVEMENT_MILL]), "Mill marked as built")
	assert_eq(Fiefs.daily_tax(gs.player_fief), Fiefs.BASE_TAX[WorldData.VILLAGE] + 30, "Mill adds +30 daily tax silver")

	# Cannot build duplicate
	var r1_dup: Dictionary = gs.build_fief_improvement(Fiefs.IMPROVEMENT_MILL)
	assert_true(not r1_dup.get("ok", false), "Cannot build duplicate mill")

	# 2. Build Granary
	var r2: Dictionary = gs.build_fief_improvement(Fiefs.IMPROVEMENT_GRANARY)
	assert_true(r2.get("ok", false), "Built granary improvement")
	assert_eq(Fiefs.max_food_capacity(gs.player_fief), Fiefs.GRANARY_MAX_STORAGE_FOOD, "Food storage capacity expanded to 250")
	assert_eq(Fiefs.daily_food(gs.player_fief), Fiefs.BASE_FOOD[WorldData.VILLAGE] + 15, "Granary adds +15 daily rations")

	# 3. Build Fortifications
	var r3: Dictionary = gs.build_fief_improvement(Fiefs.IMPROVEMENT_FORTIFICATIONS)
	assert_true(r3.get("ok", false), "Built fortifications improvement")
	assert_true(bool(gs.player_fief["improvements"][Fiefs.IMPROVEMENT_FORTIFICATIONS]), "Fortifications marked as built")

	# 4. Reconstruction of damaged fief
	gs.world.burned["kettlebrook"] = gs.world.hour + 48.0
	assert_true(gs.world.is_burned("kettlebrook"), "Fief is in burned state")
	var rep: Dictionary = gs.repair_fief()
	assert_true(rep.get("ok", false), "Successfully repaired burned fief")
	assert_true(not gs.world.is_burned("kettlebrook"), "Burned state cleared after repair")


func test_fief_raid_defense() -> void:
	print("\n--- Fief Raid Defense Integration ---")
	var gs := _create_game_state()
	gs.renown = 60
	gs.add_realm_relation("vardmark", 30)
	gs.accept_fealty_and_fief("kettlebrook", "vardmark")
	gs.build_fief_improvement(Fiefs.IMPROVEMENT_FORTIFICATIONS)

	var w: WorldSim = gs.world
	# Create a mock weak lord raiding party
	var lord_party = w.Party.new()
	lord_party.id = 8888
	lord_party.kind = WorldSim.LORD
	lord_party.name = "Raider Lord"
	lord_party.army = [{"id": 1, "type": Troops.INFANTRY, "men": 4, "xp": 0}] # Very small raiding party (4 men)
	w.parties.append(lord_party)

	var mock_lord := {
		"id": 99,
		"name": "Raider Lord",
		"party": 8888,
		"raiding": "kettlebrook",
		"job": "raid",
		"silver": 100,
	}

	# Trigger raid resolution
	w._burn(mock_lord, "kettlebrook")
	# With 15 militia from village + 15 from fortifications (30 men total) vs 4 raiders,
	# fortified village repulses the raid!
	assert_true(not w.is_burned("kettlebrook"), "Fortified player fief successfully repulsed the weak raid")


func test_fief_loss_and_recapture() -> void:
	print("\n--- Fief Loss and Recapture ---")
	var gs := _create_game_state()
	gs.renown = 60
	gs.add_realm_relation("vardmark", 30)
	gs.accept_fealty_and_fief("kettlebrook", "vardmark")

	var w: WorldSim = gs.world

	# Enemy captures the fief
	w.set_owner("kettlebrook", "kharzan")
	assert_true(bool(gs.player_fief.get("lost", false)), "Fief marked as lost when captured by enemy realm")

	# Friendly realm recaptures the fief
	w.set_owner("kettlebrook", "vardmark")
	assert_true(not bool(gs.player_fief.get("lost", false)), "Fief restored to player when liberated by realm")


func test_fief_recommendation_guidance() -> void:
	print("\n--- Fief Recommendation Guidance ---")
	var gs := _create_game_state()
	gs.renown = 60
	gs.add_realm_relation("vardmark", 30)
	gs.accept_fealty_and_fief("kettlebrook", "vardmark")
	gs.food = 500

	# 1. Uncollected taxes guidance
	gs.player_fief["silver"] = 250
	var rec: Dictionary = gs.recommendation()
	assert_eq(rec.get("title", ""), "Collect estate taxes", "Guidance points to uncollected taxes")
	assert_eq(rec.get("place", ""), "kettlebrook", "Guidance points player to their fief")

	# 2. Ruins guidance
	gs.world.burned["kettlebrook"] = gs.world.hour + 48.0
	var rec_ruins: Dictionary = gs.recommendation()
	assert_eq(rec_ruins.get("title", ""), "Fief in ruins", "Guidance warns that fief is in ruins")
	assert_eq(rec_ruins.get("place", ""), "kettlebrook", "Guidance points player home to repair")


func test_fief_save_load_roundtrip() -> void:
	print("\n--- Save/Load Roundtrip Persistence ---")
	var gs := _create_game_state()
	gs.renown = 60
	gs.add_realm_relation("vardmark", 30)
	gs.accept_fealty_and_fief("kettlebrook", "vardmark")
	gs.build_fief_improvement(Fiefs.IMPROVEMENT_MILL)
	gs.player_fief["silver"] = 120
	gs.player_fief["food"] = 45

	var serialized: Dictionary = gs.to_dict()

	var gs2 = GameStateScript.new()
	gs2.persist = false
	var ok: bool = gs2.from_dict(serialized)
	assert_true(ok, "Loaded game state from dictionary")
	assert_true(gs2.has_fief(), "Restored player fief")
	assert_eq(gs2.fief_id(), "kettlebrook", "Restored fief id matches")
	assert_eq(gs2.fief_realm(), "vardmark", "Restored fief realm matches")
	assert_true(bool(gs2.player_fief["improvements"][Fiefs.IMPROVEMENT_MILL]), "Restored mill improvement")
	assert_eq(int(gs2.player_fief.get("silver", 0)), 120, "Restored estate silver")
	assert_eq(int(gs2.player_fief.get("food", 0)), 45, "Restored estate food")


func test_fief_renunciation() -> void:
	print("\n--- Fealty Renunciation ---")
	var gs := _create_game_state()
	gs.renown = 60
	gs.add_realm_relation("vardmark", 30)
	gs.accept_fealty_and_fief("kettlebrook", "vardmark")

	var prev_rel: int = gs.relation_with_realm("vardmark")
	gs.renounce_fief()

	assert_true(not gs.has_fief(), "Player no longer holds a fief")
	assert_eq(gs.relation_with_realm("vardmark"), prev_rel - 25, "Suffered -25 relation penalty upon renouncing")
	assert_eq(gs.world.player().faction, "", "Player party faction cleared to neutral")
