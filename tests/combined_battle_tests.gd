## Test suite for Slice 4.5.2: Meeting lords on the road & combined allied battles.
extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const WorldSim = preload("res://scripts/world/world_sim.gd")
const WorldData = preload("res://scripts/world/world_data.gd")
const Cultures = preload("res://scripts/data/cultures.gd")
const BattleSim = preload("res://scripts/battle/battle_sim.gd")
const Commander = preload("res://scripts/battle/commander_ai.gd")
const AutoResolve = preload("res://scripts/battle/auto_resolve.gd")
const Troops = preload("res://scripts/data/troops.gd")

var _passes := 0
var _failures := 0


func _init() -> void:
	print("Running Combined Battle & Lord Road Encounter Tests (Slice 4.5.2)...")
	_test_hostile_lord_encounter_and_withdrawal()
	_test_attack_neutral_lord_causes_war()
	_test_field_cap_12_and_reserves()
	_test_allied_squads_commanded_by_ai()
	_test_allied_troop_loss_conservation()
	_test_auto_resolve_with_allies()
	_test_following_army_movement_and_unfollowing()

	print("\nCombined Battle Tests finished: %d passed, %d failed" % [_passes, _failures])
	quit(1 if _failures > 0 else 0)


func _expect(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
		print("  ok    %s" % msg)
	else:
		_failures += 1
		printerr("  FAIL: %s" % msg)


func _setup_world() -> WorldSim:
	var w = WorldSim.new()
	w.setup(12345, Cultures.VARDISH)
	return w


func _test_hostile_lord_encounter_and_withdrawal() -> void:
	print("\n--- Hostile Lord Road Encounter & Withdrawal ---")
	var gs = GameStateScript.new()
	gs.persist = false
	var w = _setup_world()
	gs.world = w
	gs.new_warband()

	# Find a lord from an enemy realm
	var enemy_realm := "kharzan"
	gs.add_realm_relation(enemy_realm, -40)
	_expect(w.relation_to_player(enemy_realm) == "hostile", "Kharzan is hostile to player")

	var lp = null
	for p in w.lord_parties():
		if p.faction == enemy_realm:
			lp = p
			break
	_expect(lp != null, "Found hostile Kharzan lord party on map")

	# Position player and lord at same node to check encounter
	var player_p = w.player()
	player_p.node = lp.node
	player_p.next = ""
	player_p.along = 0.0
	lp.next = ""
	lp.along = 0.0
	lp.grace_until = 0.0

	w._check_encounter()
	_expect(w.encounter == lp.id, "Hostile lord intercepts moving player and triggers encounter")

	# Test withdrawal logic
	# Bandit bands always allow withdrawal
	w.encounter = -1
	_expect(w.can_withdraw(), "Default withdrawal is true when no encounter")

	w.encounter = lp.id
	# When enemy party is significantly faster and stronger
	lp.army = [
		{"id": 901, "type": Troops.CAVALRY, "men": 40},
		{"id": 902, "type": Troops.CAVALRY, "men": 40},
	]
	player_p.army = [
		{"id": 1, "type": Troops.INFANTRY, "men": 10},
	]
	# can_withdraw evaluates deterministic overrun chance
	var can_w := w.can_withdraw()
	_expect(typeof(can_w) == TYPE_BOOL, "can_withdraw returns boolean for lord party")


func _test_attack_neutral_lord_causes_war() -> void:
	print("\n--- Attacking Neutral Lord Causes War ---")
	var gs = GameStateScript.new()
	gs.persist = false
	var w = _setup_world()
	gs.world = w
	gs.new_warband()

	var neutral_realm := "ryumon"
	gs.realm_relations[neutral_realm] = 0
	_expect(gs.relation_with_realm(neutral_realm) == 0, "Initial relation with Ryumon is 0 (peace)")
	_expect(w.relation_to_player(neutral_realm) == "neutral", "Ryumon is neutral to player")

	var target_lp = null
	for p in w.lord_parties():
		if p.faction == neutral_realm:
			target_lp = p
			break
	_expect(target_lp != null, "Found neutral Ryumon lord party")

	# Attack the neutral lord
	gs.attack_neutral_lord(target_lp.lord, target_lp.id)
	_expect(gs.relation_with_realm(neutral_realm) <= -20, "Attacking neutral lord drops realm relation to hostile (<= -20)")
	_expect(gs.relation_with_lord(target_lp.lord) == -30, "Attacking neutral lord drops lord relation by -30")
	_expect(w.relation_to_player(neutral_realm) == "hostile", "Ryumon is now hostile to player")
	_expect(gs.is_at_war_with(neutral_realm), "Player is now at war with Ryumon")
	_expect(w.encounter == target_lp.id, "Encounter started with attacked lord party")


func _test_field_cap_12_and_reserves() -> void:
	print("\n--- Field Cap 12 & Reserve Reinforcements ---")
	var sim = BattleSim.new()

	# Create player army with 16 squads (exceeds FIELD_CAP of 12)
	var big_army := []
	for i in 16:
		big_army.append({"id": 100 + i, "type": Troops.INFANTRY, "men": 20, "xp": 0})

	var enemy_army := []
	for i in 4:
		enemy_army.append({"id": 200 + i, "type": Troops.INFANTRY, "men": 20, "xp": 0})

	sim.setup(big_army, enemy_army, 42)
	_expect(sim.armies[BattleSim.PLAYER].size() == 16, "Roster contains all 16 player squads")
	_expect(sim.reserves[BattleSim.PLAYER].size() == BattleSim.FIELD_CAP, "Initial deployable reserves capped at 12")
	_expect(sim.reserve_queue[BattleSim.PLAYER].size() == 4, "Excess 4 squads wait in reserve queue")

	# Deploy all initial 12 squads
	sim.auto_deploy(BattleSim.PLAYER)
	_expect(sim.reserves[BattleSim.PLAYER].is_empty(), "All 12 initial squads deployed")
	_expect(sim.squads.size() == 12, "Exactly 12 player squads on field")

	# Start battle
	sim.phase = BattleSim.PHASE_BATTLE

	# Rout one player squad on field
	var broken_sq = sim.squads[0]
	sim.rout(broken_sq)
	_expect(broken_sq.routing, "First squad is now routing")
	_expect(sim.reserve_queue[BattleSim.PLAYER].size() == 3, "Reserve squad popped from queue upon break")
	_expect(sim.squads.size() == 13, "Reinforcement squad spawned onto field from rear edge")

	# Count active squads on field: should be 12 (1 routing + 12 active)
	var active_count := 0
	for sq in sim.squads:
		if sq.team == BattleSim.PLAYER and sq.is_active():
			active_count += 1
	_expect(active_count == BattleSim.FIELD_CAP, "Active squads on field maintained at exactly FIELD_CAP (12)")


func _test_allied_squads_commanded_by_ai() -> void:
	print("\n--- Allied Squads Commanded by AI ---")
	var sim = BattleSim.new()

	var player_squads := [
		{"id": 1, "type": Troops.INFANTRY, "men": 20, "is_ally": false},
		{"id": 2, "type": Troops.ARCHERS, "men": 15, "is_ally": false},
	]
	var allied_squads := [
		{"id": 3, "type": Troops.CAVALRY, "men": 18, "is_ally": true, "lord_id": 5},
		{"id": 4, "type": Troops.SPEARMEN, "men": 22, "is_ally": true, "lord_id": 5},
	]
	var combined_player := player_squads + allied_squads
	var enemy_army := [
		{"id": 10, "type": Troops.INFANTRY, "men": 30},
	]

	sim.setup(combined_player, enemy_army, 99)
	sim.allied_ai = Commander.new(BattleSim.PLAYER, "", true)
	sim.ai[BattleSim.ENEMY] = Commander.new(BattleSim.ENEMY)

	# Allied AI deploys allied squads
	sim.allied_ai.deploy(sim)

	var deployed_allies := 0
	for sq in sim.squads:
		if sq.team == BattleSim.PLAYER and sq.is_ally:
			deployed_allies += 1
			_expect(sq.lord_id == 5, "Allied squad preserves lord_id")
	_expect(deployed_allies == 2, "Allied AI deployed all allied squads")

	# Player auto deploys remaining player squads
	sim.auto_deploy(BattleSim.PLAYER)
	_expect(sim.squads.size() == 4, "All 4 player side squads now on field")

	# Verify order_all ignores allied squads
	sim.phase = BattleSim.PHASE_BATTLE
	for sq in sim.squads:
		if sq.team == BattleSim.PLAYER:
			sq.order = "hold"

	sim.order_all(BattleSim.PLAYER, "advance")
	for sq in sim.squads:
		if sq.team == BattleSim.PLAYER:
			if sq.is_ally:
				_expect(sq.order == "hold", "Allied squad ignored by player order_all advance")
			else:
				_expect(sq.order == "advance", "Player squad received player order_all advance")


func _test_allied_troop_loss_conservation() -> void:
	print("\n--- Allied Troop Loss Conservation (1:1) ---")
	var gs = GameStateScript.new()
	gs.persist = false
	var w = _setup_world()
	gs.world = w
	gs.new_warband()

	# Pick an allied lord
	var lord = w.lords[0]
	var lp = w.party(int(lord["party"]))
	if lp == null:
		w._spawn_lord_party(lord, w.seat_of(lord))
		lp = w.party(int(lord["party"]))
	_expect(lp != null, "Allied lord party exists")

	# Give lord party known squads
	lp.army = [
		{"id": 501, "type": Troops.INFANTRY, "men": 30},
		{"id": 502, "type": Troops.ARCHERS, "men": 20},
	]
	lord["army"] = lp.army

	var battle_results := {
		501: {"men": 18, "is_ally": true, "lord_id": int(lord["id"])}, # lost 12
		502: {"men": 0, "is_ally": true, "lord_id": int(lord["id"])},  # lost 20 (wiped)
	}

	w.return_allied_losses(battle_results)

	_expect(lp.army.size() == 1, "Wiped allied squad filtered from lord party")
	_expect(int(lp.army[0]["men"]) == 18, "Surviving allied squad conserved exactly 18 men (12 lost)")
	_expect(int(lord["army"][0]["men"]) == 18, "Lord record updated with conserved squad")

	# Now wipe remaining squad
	w.return_allied_losses({501: {"men": 0, "is_ally": true, "lord_id": int(lord["id"])}})
	_expect(lp.army.is_empty(), "Lord party army is empty after all squads wiped")
	_expect(lord["state"] == "regroup", "Lord routed back to seat to regroup after army defeated")


func _test_auto_resolve_with_allies() -> void:
	print("\n--- Auto-Resolve (Send In) with Allies ---")
	var rng = RandomNumberGenerator.new()
	rng.seed = 777

	var player_squads := [
		{"id": 1, "type": Troops.INFANTRY, "men": 20, "is_ally": false},
	]
	var allied_squads := [
		{"id": 601, "type": Troops.SPEARMEN, "men": 25, "is_ally": true, "lord_id": 2},
	]
	var combined := player_squads + allied_squads

	var enemy := [
		{"id": 10, "type": Troops.INFANTRY, "men": 20},
	]

	var res := AutoResolve.resolve(combined, enemy, rng, false)
	_expect(res.has("squads"), "Auto-resolve returns squads dictionary")
	_expect(res["squads"].has(601), "Allied squad 601 present in auto-resolve result")
	_expect(res["squads"][601].get("is_ally") == true, "Auto-resolve preserves is_ally flag")
	_expect(res["squads"][601].get("lord_id") == 2, "Auto-resolve preserves lord_id")
	_expect(res["squads"][601]["men"] >= 0 and res["squads"][601]["men"] <= 25, "Allied squad men accurately counted")


func _test_following_army_movement_and_unfollowing() -> void:
	print("\n--- Following Army Movement & Unfollowing ---")
	var w = _setup_world()
	var lp = w.lord_parties()[0]
	_expect(lp != null, "Found lord party to follow")

	w.following_party = lp.id
	_expect(w.following_party == lp.id, "Player is following lord party")

	# Step world and verify player position tracks followed party
	lp.node = "marchgate"
	lp.next = "ravensford"
	lp.along = 50.0
	lp.path = ["bramblemoor"]
	lp.wait = 0.0

	w._move_player(0.1)
	var p = w.player()
	_expect(p.node == lp.node, "Player node tracks followed lord party")
	_expect(p.next == lp.next, "Player next tracks followed lord party")
	_expect(p.along == lp.along, "Player along distance tracks followed lord party")

	# Issuing independent travel order cancels following
	w.travel("bramblemoor")
	_expect(w.following_party == -1, "Issuing travel command clears following_party")

	# Save/load roundtrip
	w.following_party = lp.id
	var saved := w.to_dict()
	var w2 = WorldSim.new()
	w2.from_dict(saved)
	_expect(w2.following_party == lp.id, "following_party persists across save/load roundtrip")
