extends SceneTree

const WorldSim = preload("res://scripts/world/world_sim.gd")
const GameStateScript = preload("res://scripts/game_state.gd")
const BattleSim = preload("res://scripts/battle/battle_sim.gd")
const AutoResolve = preload("res://scripts/battle/auto_resolve.gd")
const Lords = preload("res://scripts/data/lords.gd")
const Troops = preload("res://scripts/data/troops.gd")
const Cultures = preload("res://scripts/data/cultures.gd")
const WorldData = preload("res://scripts/world/world_data.gd")
const Commander = preload("res://scripts/battle/commander_ai.gd")

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
	print("\nRunning Prisoners, Ransoms, and Lords Who Remember Tests (Phase 4.6)...")
	test_lord_capture_and_death_tactical()
	test_lord_auto_resolve_and_succession()
	test_captive_management_and_ransom_options()
	test_ai_inter_realm_captures_and_ransoms()
	test_grudge_system_and_memorial_vengeance()
	test_grudge_map_seeking_and_dialogue()
	test_save_load_persistence()

	print("\nPrisoners and Grudge Tests finished: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _create_test_world() -> WorldSim:
	var w := WorldSim.new()
	w.setup(12345, Cultures.VARDISH)
	return w


func _create_test_game_state(world: WorldSim) -> GameStateScript:
	var gs := GameStateScript.new()
	gs.persist = false
	gs.world = world
	world.game_state = gs
	gs.new_warband()
	return gs


func test_lord_capture_and_death_tactical() -> void:
	print("\n--- Tactical Battle: Lord Capture and Fatality ---")
	var sim := BattleSim.new()

	var player_army := [
		{"id": 1, "type": Troops.INFANTRY, "unit": "vardish_foot", "men": 30, "level": 1, "name": "Player Foot"},
		{"id": 2, "type": Troops.SPEARMEN, "unit": "vardish_spear", "men": 30, "level": 1, "name": "Player Spear"}
	]
	var enemy_army := [
		{
			"id": 101, "type": Troops.INFANTRY, "unit": "kharzani_foot", "men": 20, "level": 1,
			"name": "Lord Tahir's Guard", "is_lord": true, "lord_id": 5, "lord_name": "Emir Tahir",
			"has_grudge": false, "bearing": Lords.DARING
		}
	]

	sim.setup(player_army, enemy_army, 42)
	assert_true(sim.is_lord, "BattleSim detects enemy lord presence")
	assert_eq(sim.enemy_lord_id, 5, "BattleSim stores enemy lord id")
	assert_eq(sim.enemy_lord_name, "Emir Tahir", "BattleSim stores enemy lord name")

	# Deploy squads
	sim.auto_deploy(BattleSim.PLAYER)
	sim.auto_deploy(BattleSim.ENEMY)
	sim.phase = BattleSim.PHASE_BATTLE

	var e_squad = null
	for sq in sim.squads:
		if sq.team == BattleSim.ENEMY and sq.is_lord:
			e_squad = sq
			break
	assert_true(e_squad != null, "Enemy lord squad deployed on field")
	assert_true(e_squad.is_lord, "Enemy squad tagged as lord guard")
	assert_eq(e_squad.lord_name, "Emir Tahir", "Enemy squad carries lord name")

	# Engage squads and simulate rout while engaged -> lord caught
	e_squad.engaged = true
	sim.rout(e_squad)
	assert_true(sim.lord_broken, "Lord shock triggered upon guard break")
	assert_true(sim.lord_captured or sim.lord_killed, "Lord caught in rout produces capture or death")

	# Check result_for
	sim.concede(BattleSim.ENEMY)
	var res := sim.result_for(BattleSim.PLAYER)
	assert_true(res.get("won", false), "Player won battle")
	assert_true(res.get("is_lord", false), "Result reflects lord battle")
	assert_true(res.get("lord_captured", false) or res.get("lord_killed", false), "Result reflects lord captured or killed")


func test_lord_auto_resolve_and_succession() -> void:
	print("\n--- Auto-Resolve & House Succession ---")
	var rng := RandomNumberGenerator.new()
	rng.seed = 9999

	var player_army := [
		{"id": 1, "type": Troops.INFANTRY, "men": 50, "level": 2}
	]
	var enemy_army := [
		{"id": 201, "type": Troops.INFANTRY, "men": 10, "level": 1, "is_lord": true, "lord_id": 2, "lord_name": "Lord John Ashcombe"}
	]

	var res := AutoResolve.resolve(player_army, enemy_army, rng, true, null, "rout")
	assert_true(res["won"], "Player won auto-resolve against small host")
	assert_true(res["is_lord"], "Auto-resolve identifies lord battle")
	assert_true(res.has("lord_captured"), "Auto-resolve reports lord_captured")
	assert_true(res.has("lord_killed"), "Auto-resolve reports lord_killed")

	# Test succession in world
	var world := _create_test_world()
	var target_lord: Dictionary = world.lords[1]
	var original_name: String = String(target_lord["name"])
	var original_fief: String = String(target_lord["fief"])
	var original_house: String = String(target_lord["house"])

	var heir := world.kill_lord(1, "The Enemy")
	assert_true(heir["name"] != original_name, "Lord name updated to heir: %s" % heir["name"])
	assert_eq(heir["fief"], original_fief, "Heir inherits the ancestral fief")
	assert_eq(heir["house"], original_house, "Heir belongs to the same house: %s" % heir["house"])
	assert_eq(heir["renown"], Lords.START_RENOWN[0], "Heir renown reset to base starting renown")
	assert_eq(heir["state"], "regroup", "Heir regroups at home before taking the field")
	assert_true(heir["army"].size() >= Lords.SQUADS_MIN, "Heir gathers a fresh house warband")


func test_captive_management_and_ransom_options() -> void:
	print("\n--- Captive Management & Ransom Options ---")
	var world := _create_test_world()
	var gs := _create_test_game_state(world)

	# Capture lord 3 (an enemy lord)
	var captive_lord: Dictionary = world.lords[3]
	var captive_realm: String = String(captive_lord["realm"])
	world.capture_lord(3, "player")

	assert_eq(captive_lord["state"], "prisoner", "Lord state is prisoner")
	assert_eq(captive_lord["captive_of"], "player", "Lord is captive of player")
	assert_eq(world.captive_lords_of("player").size(), 1, "World tracks 1 captive for player")
	assert_eq(gs.captive_lords().size(), 1, "GameState reports 1 captive lord")

	var ransom_val: int = Lords.ransom_for(int(captive_lord["renown"]))
	assert_true(ransom_val >= 200, "Ransom value calculated by renown: %d silver" % ransom_val)

	# 1. Accept Ransom Option
	var init_silver := gs.silver
	var init_treasury: int = int(world.realms[captive_realm]["treasury"])
	var success := gs.accept_lord_ransom(3)
	assert_true(success, "Ransom successfully accepted")
	assert_eq(gs.silver, init_silver + ransom_val, "Player silver credited with ransom")
	assert_eq(world.realms[captive_realm]["treasury"], init_treasury - ransom_val, "Captive realm treasury debited")
	assert_eq(captive_lord["state"], "regroup", "Lord released to regroup after ransom")
	assert_eq(captive_lord["captive_of"], "", "Lord is no longer captive")
	assert_true(gs.captive_lords().is_empty(), "Player holds no remaining captives")

	# 2. Release for Honor Option
	world.capture_lord(3, "player")
	var pre_rel_lord := gs.relation_with_lord(3)
	var pre_rel_realm := gs.relation_with_realm(captive_realm)
	var pre_renown := gs.renown

	gs.release_lord_for_honor(3)
	assert_eq(gs.relation_with_lord(3), pre_rel_lord + 20, "Lord relation rises by +20 for honorable release")
	assert_eq(gs.relation_with_realm(captive_realm), pre_rel_realm + 15, "Realm relation rises by +15 for honorable release")
	assert_eq(gs.renown, pre_renown + 10, "Player gains +10 renown for chivalric deed")
	assert_eq(captive_lord["state"], "regroup", "Lord returned to his hall")

	# 3. Deliver to Employer Option
	world.capture_lord(3, "player")
	# Sign contract with an enemy of captive realm
	var employer_realm := "vardmark" if captive_realm != "vardmark" else "kharzan"
	world.declare_war(employer_realm, captive_realm, true)
	gs.sign_contract(employer_realm)

	var pre_emp_rel := gs.relation_with_realm(employer_realm)
	var pre_sil := gs.silver
	gs.deliver_lord_to_employer(3)
	assert_eq(gs.silver, pre_sil + 100, "Collected 100 silver contract capture bounty")
	assert_eq(gs.relation_with_realm(employer_realm), pre_emp_rel + 10, "Employer relation gained +10")
	assert_eq(captive_lord["captive_of"], employer_realm, "Captive transferred to employer realm")


func test_ai_inter_realm_captures_and_ransoms() -> void:
	print("\n--- AI Inter-Realm Captures & Ransoms ---")
	var world := _create_test_world()

	var lord_a: Dictionary = world.lords[1] # Vardmark
	var lord_b: Dictionary = world.lords[5] # Kharzan
	world.declare_war("vardmark", "kharzan", true)

	# Manually capture lord_b by vardmark
	world.capture_lord(5, "vardmark")
	assert_eq(lord_b["state"], "prisoner", "AI lord is prisoner")
	assert_eq(lord_b["captive_of"], "vardmark", "AI lord captured by Vardmark")

	# Advance time past AI ransom threshold
	world.hour = float(lord_b["ransom_at"]) + 1.0
	world._lord_day = int(world.hour / 24.0)
	var v_treasury_init: int = int(world.realms["vardmark"]["treasury"])
	var k_treasury_init: int = int(world.realms["kharzan"]["treasury"])
	var ransom: int = int(lord_b["ransom_amount"])

	world._step_lords(1.0) # triggers AI ransom resolution

	assert_eq(lord_b["state"], "regroup", "AI captive lord ransomed and regrouping")
	assert_eq(lord_b["captive_of"], "", "AI captive lord cleared from custody")
	assert_eq(world.realms["vardmark"]["treasury"], v_treasury_init + ransom, "Captor realm collected ransom silver")
	assert_eq(world.realms["kharzan"]["treasury"], k_treasury_init - ransom, "Debtor realm paid ransom silver")


func test_grudge_system_and_memorial_vengeance() -> void:
	print("\n--- Grudge System & Memorial Vengeance ---")
	var world := _create_test_world()
	var gs := _create_test_game_state(world)

	var enemy_lid := 4
	var enemy_lord: Dictionary = world.lords[enemy_lid]
	var enemy_lord_name: String = String(enemy_lord["name"])

	# Simulate a battle where a player captain dies fighting enemy_lord
	var cap = gs.army[0]["captain"]
	var cap_id: int = int(cap["id"])
	var cap_name: String = String(cap["name"])
	var comp_name: String = String(gs.army[0]["name"])

	gs.pending_battle = {
		"name": enemy_lord_name,
		"is_lord": true,
		"enemy_lord_id": enemy_lid,
		"enemy_faction": enemy_lord["realm"],
		"site": {"name": "Bramble Moor"}
	}

	var defeat_result := {
		"won": false,
		"lost": 20,
		"killed": 10,
		"squads": {
			gs.army[0]["id"]: {
				"men": 0,
				"captain": {
					"id": cap_id,
					"fate": "killed",
					"roll": 1,
					"needed": 20,
					"kills": 3,
					"words": "Hold the line..."
				}
			}
		}
	}

	gs.apply_result(defeat_result)

	# Verify memorial entry recorded the lord
	assert_true(gs.fallen.size() > 0, "Fallen captain added to memorial")
	var mem: Dictionary = gs.fallen[-1]
	assert_eq(mem["killed_by_lord_id"], enemy_lid, "Memorial records killer lord id")
	assert_eq(mem["killed_by_lord_name"], enemy_lord_name, "Memorial records killer lord name")
	assert_true(not mem["avenged"], "Captain death is initially unavenged")

	# Verify lord gained a grudge
	assert_true(enemy_lord["grudge"], "Lord acquired grudge against player")
	assert_eq(enemy_lord["grudge_captain_name"], cap_name, "Lord remembers fallen captain's name")
	assert_eq(enemy_lord["grudge_company_name"], comp_name, "Lord remembers fallen captain's company")

	# Now player encounters this grudge lord and defeats him
	gs.pending_battle = {
		"name": enemy_lord_name,
		"is_lord": true,
		"enemy_lord_id": enemy_lid,
		"enemy_faction": enemy_lord["realm"],
		"site": {"name": "High Crag"}
	}

	var victory_result := {
		"won": true,
		"lost": 5,
		"killed": 25,
		"lord_captured": true,
		"lord_killed": false,
		"squads": {}
	}

	gs.apply_result(victory_result)

	# Verify vengeance
	assert_true(mem["avenged"], "Memorial record marked as avenged")
	assert_true(mem["avenged_words"] != "", "Memorial contains avenged words: %s" % mem["avenged_words"])
	assert_true(not enemy_lord["grudge"], "Grudge resolved and cleared upon capture")
	assert_eq(enemy_lord["state"], "prisoner", "Defeated grudge lord taken into custody")


func test_grudge_map_seeking_and_dialogue() -> void:
	print("\n--- Grudge AI Map Seeking & Dialogue ---")
	var world := _create_test_world()
	var gs := _create_test_game_state(world)

	var lord: Dictionary = world.lords[2]
	lord["grudge"] = true
	lord["grudge_captain_name"] = "Theron"
	lord["grudge_company_name"] = "Iron Shields"

	# Check encounter plan dialogue
	var lp := world.party(int(lord["party"]))
	if lp == null:
		world._lord_takes_field(lord, world.seat_of(lord))
		lp = world.party(int(lord["party"]))

	var plan := gs.encounter_plan(lp)
	assert_true(plan["has_grudge"], "Encounter plan flags grudge")
	assert_true(plan["grudge_text"].contains("Iron Shields"), "Encounter plan quotes captain/company name")
	assert_true(plan["grudge_text"].contains("settle the score"), "Encounter plan contains grudge dialogue")


func test_save_load_persistence() -> void:
	print("\n--- Save/Load Roundtrip Persistence ---")
	var world := _create_test_world()
	var gs := _create_test_game_state(world)

	# Set up captive lord
	world.capture_lord(4, "player")
	var l4: Dictionary = world.lords[4]
	l4["ransom_offered"] = true

	# Set up grudge lord
	var l6: Dictionary = world.lords[6]
	l6["grudge"] = true
	l6["grudge_captain_name"] = "Vael"
	l6["grudge_company_name"] = "Raven Pikes"

	# Set up avenged memorial entry
	gs.fallen.append({
		"id": 999, "name": "Vael", "company": "Raven Pikes", "type": Troops.SPEARMEN,
		"killed_by_lord_id": 6, "killed_by_lord_name": String(l6["name"]),
		"avenged": true, "avenged_words": "Avenged at High Ridge."
	})

	var data := gs.to_dict()
	var new_world := WorldSim.new()
	new_world.from_dict(data["world"])

	var new_gs := GameStateScript.new()
	new_gs.persist = false
	new_gs.world = new_world
	new_world.game_state = new_gs
	var loaded := new_gs.from_dict(data)

	assert_true(loaded, "GameState successfully loaded from dict")

	# Check loaded captive lord
	var loaded_l4: Dictionary = new_world.lords[4]
	assert_eq(loaded_l4["state"], "prisoner", "Loaded lord is prisoner")
	assert_eq(loaded_l4["captive_of"], "player", "Loaded lord captive of player")
	assert_true(loaded_l4["ransom_offered"], "Loaded lord preserves ransom_offered")

	# Check loaded grudge lord
	var loaded_l6: Dictionary = new_world.lords[6]
	assert_true(loaded_l6["grudge"], "Loaded lord preserves grudge")
	assert_eq(loaded_l6["grudge_captain_name"], "Vael", "Loaded lord preserves grudge captain name")

	# Check loaded memorial record
	var loaded_mem: Dictionary = new_gs.fallen[-1]
	assert_eq(loaded_mem["killed_by_lord_id"], 6, "Loaded memorial preserves killed_by_lord_id")
	assert_true(loaded_mem["avenged"], "Loaded memorial preserves avenged flag")
	assert_eq(loaded_mem["avenged_words"], "Avenged at High Ridge.", "Loaded memorial preserves avenged words")
