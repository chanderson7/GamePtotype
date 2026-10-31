extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const WorldSim = preload("res://scripts/world/world_sim.gd")
const WorldData = preload("res://scripts/world/world_data.gd")
const Cultures = preload("res://scripts/data/cultures.gd")
const Jobs = preload("res://scripts/data/jobs.gd")
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
	print("\nRunning Settlement Jobs & Local Contracts Tests (Feature 8)...")
	test_job_generation()
	test_job_acceptance_and_cap()
	test_courier_job_completion()
	test_relief_job_completion()
	test_hunt_bounty_auto_completion()
	test_fair_cancellation_and_deadlines()
	test_recommendation_guidance()
	test_save_load_persistence()

	print("\nSettlement Jobs Tests finished: %d passed, %d failed" % [passed, failed])
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
	gs.world = w
	gs.new_warband()
	gs.silver = 1000
	gs.food = 200
	gs.renown = 20
	return gs


func test_job_generation() -> void:
	print("\n--- Job Generation & Templates ---")
	var gs := _create_game_state()
	var w: WorldSim = gs.world

	# 1. Village generation
	var v_jobs := Jobs.generate_jobs_for("kettlebrook", w, w.rng)
	assert_true(v_jobs.size() >= 1, "Village kettlebrook generated at least 1 job")
	var v_type: String = String(v_jobs[0].get("type", ""))
	assert_true(v_type == Jobs.TYPE_RELIEF or v_type == Jobs.TYPE_HUNT, "Village jobs are relief or hunt")

	# 2. Town / Castle generation
	var t_jobs := Jobs.generate_jobs_for("highcliff", w, w.rng)
	assert_true(t_jobs.size() >= 1, "Town highcliff generated jobs")
	for j in t_jobs:
		var jt: String = String(j.get("type", ""))
		assert_true(jt == Jobs.TYPE_COURIER or jt == Jobs.TYPE_HUNT, "Town jobs are courier or hunt")

	# 3. Attributes contract
	var relief_job := Jobs.make_relief_job("kettlebrook", w, w.rng)
	assert_eq(relief_job["type"], Jobs.TYPE_RELIEF, "Relief job has type relief")
	assert_eq(relief_job["food_needed"], 15, "Relief job requires 15 food rations")
	assert_eq(relief_job["reward_silver"], 80, "Relief job reward silver is 80")
	assert_eq(relief_job["reward_renown"], 5, "Relief job reward renown is 5")
	assert_eq(relief_job["reward_relation"], 10, "Relief job reward relation is 10")
	assert_true(float(relief_job["deadline"]) > w.hour, "Relief job has future deadline")

	var courier_job := Jobs.make_courier_job("highcliff", w, w.rng)
	assert_eq(courier_job["type"], Jobs.TYPE_COURIER, "Courier job has type courier")
	assert_true(courier_job["destination_settlement"] != "highcliff", "Courier destination differs from origin")
	assert_eq(courier_job["reward_silver"], 110, "Courier job reward silver is 110")
	assert_eq(courier_job["reward_renown"], 3, "Courier job reward renown is 3")
	assert_eq(courier_job["reward_relation"], 5, "Courier job reward relation is 5")

	var hunt_job := Jobs.make_hunt_job("highcliff", w, w.rng)
	if not hunt_job.is_empty():
		assert_eq(hunt_job["type"], Jobs.TYPE_HUNT, "Hunt job has type hunt")
		assert_true(int(hunt_job["target_party_id"]) >= 0, "Hunt job has valid target party id")
		assert_eq(hunt_job["reward_silver"], 160, "Hunt job reward silver is 160")
		assert_eq(hunt_job["reward_renown"], 5, "Hunt job reward renown is 5")
		assert_eq(hunt_job["reward_relation"], 5, "Hunt job reward relation is 5")


func test_job_acceptance_and_cap() -> void:
	print("\n--- Job Acceptance & 3-Job Cap ---")
	var gs = _create_game_state()
	var w: WorldSim = gs.world

	# Populate settlement jobs manually for deterministic test
	w.settlement_jobs["highcliff"] = [
		{"id": "job_1", "type": Jobs.TYPE_COURIER, "title": "Job 1", "destination_settlement": "ravensford", "deadline": 100.0, "reward_silver": 100},
		{"id": "job_2", "type": Jobs.TYPE_COURIER, "title": "Job 2", "destination_settlement": "khalun", "deadline": 100.0, "reward_silver": 100},
		{"id": "job_3", "type": Jobs.TYPE_COURIER, "title": "Job 3", "destination_settlement": "ryu_capital", "deadline": 100.0, "reward_silver": 100},
		{"id": "job_4", "type": Jobs.TYPE_COURIER, "title": "Job 4", "destination_settlement": "al_duran", "deadline": 100.0, "reward_silver": 100},
	]

	assert_eq(gs.active_jobs.size(), 0, "Starts with 0 active jobs")

	# Accept 1st
	var ok1: bool = gs.accept_job("highcliff", 0)
	assert_true(ok1, "Accepted 1st job")
	assert_eq(gs.active_jobs.size(), 1, "Active jobs count is 1")

	# Accept 2nd
	var ok2: bool = gs.accept_job("highcliff", 0)
	assert_true(ok2, "Accepted 2nd job")
	assert_eq(gs.active_jobs.size(), 2, "Active jobs count is 2")

	# Accept 3rd
	var ok3: bool = gs.accept_job("highcliff", 0)
	assert_true(ok3, "Accepted 3rd job")
	assert_eq(gs.active_jobs.size(), 3, "Active jobs count is 3")

	# Accept 4th (Should fail due to MAX_ACTIVE_JOBS = 3)
	var ok4: bool = gs.accept_job("highcliff", 0)
	assert_true(not ok4, "4th job rejected (exceeds cap)")
	assert_eq(gs.active_jobs.size(), 3, "Active jobs remains capped at 3")

	# Abandon one job
	var init_silver: int = int(gs.silver)
	var init_renown: int = int(gs.renown)
	var abandoned: bool = gs.abandon_job("job_1")
	assert_true(abandoned, "Successfully abandoned job_1")
	assert_eq(gs.active_jobs.size(), 2, "Active jobs count reduced to 2")
	assert_eq(gs.silver, init_silver, "Abandoning does not award silver")
	assert_eq(gs.renown, init_renown, "Abandoning does not award renown")

	# Now 4th job can be accepted
	var ok5: bool = gs.accept_job("highcliff", 0)
	assert_true(ok5, "Accepted another job after freeing a slot")
	assert_eq(gs.active_jobs.size(), 3, "Active jobs count back to 3")


func test_courier_job_completion() -> void:
	print("\n--- Courier Job Completion ---")
	var gs = _create_game_state()
	var w: WorldSim = gs.world

	w.player().node = "highcliff"
	w.player().next = ""
	w.player().along = 0.0

	var courier_job := {
		"id": "courier_test",
		"type": Jobs.TYPE_COURIER,
		"origin_settlement": "highcliff",
		"destination_settlement": "ravensford",
		"title": "Urgent Dispatch to Ravensford",
		"deadline": 100.0,
		"reward_silver": 110,
		"reward_renown": 3,
		"reward_relation": 5,
	}
	gs.active_jobs.append(courier_job)

	# While at Highcliff, cannot complete Ravensford delivery
	assert_true(not gs.can_complete_job(courier_job), "Cannot complete delivery while away from destination")
	assert_eq(gs.active_jobs_completable_at("highcliff").size(), 0, "No deliverable jobs at Highcliff")

	# Move player to Ravensford
	w.player().node = "ravensford"
	assert_eq(w.here(), "ravensford", "Player arrived at Ravensford")
	assert_true(gs.can_complete_job(courier_job), "Can complete delivery at destination")
	assert_eq(gs.active_jobs_completable_at("ravensford").size(), 1, "1 deliverable job at Ravensford")

	var initial_silver: int = int(gs.silver)
	var initial_renown: int = int(gs.renown)
	var res: Dictionary = gs.complete_job("courier_test")

	assert_true(res.get("ok", false), "Courier delivery completed successfully")
	assert_eq(gs.silver, initial_silver + 110, "Awarded 110 silver")
	assert_eq(gs.renown, initial_renown + 3, "Awarded 3 renown")
	assert_eq(gs.active_jobs.size(), 0, "Active jobs cleared")
	assert_eq(gs.completed_jobs.size(), 1, "Completed jobs recorded")

	# Try completing again
	var res2: Dictionary = gs.complete_job("courier_test")
	assert_true(not res2.get("ok", false), "Cannot complete already finished job")


func test_relief_job_completion() -> void:
	print("\n--- Relief Job Completion ---")
	var gs = _create_game_state()
	var w: WorldSim = gs.world

	w.player().node = "kettlebrook"
	w.player().next = ""
	w.player().along = 0.0

	var relief_job := {
		"id": "relief_test",
		"type": Jobs.TYPE_RELIEF,
		"origin_settlement": "kettlebrook",
		"title": "Provisions for Kettlebrook",
		"food_needed": 15,
		"deadline": 100.0,
		"reward_silver": 80,
		"reward_renown": 5,
		"reward_relation": 10,
	}
	gs.active_jobs.append(relief_job)

	# Test insufficient food
	gs.food = 10
	assert_true(not gs.can_complete_job(relief_job), "Cannot complete relief job with only 10 food (15 needed)")

	# Supply sufficient food
	gs.food = 25
	assert_true(gs.can_complete_job(relief_job), "Can complete relief job with 25 food")

	var initial_silver: int = int(gs.silver)
	var initial_renown: int = int(gs.renown)
	var prev_rel: int = gs.relation_with_realm("vardmark")
	var res: Dictionary = gs.complete_job("relief_test")

	assert_true(res.get("ok", false), "Relief job completed successfully")
	assert_eq(gs.food, 10, "Consumed 15 rations (25 - 15 = 10)")
	assert_eq(gs.silver, initial_silver + 80, "Awarded 80 silver")
	assert_eq(gs.renown, initial_renown + 5, "Awarded 5 renown")
	assert_eq(gs.relation_with_realm("vardmark"), prev_rel + 10, "Awarded +10 standing with Vardmark")


func test_hunt_bounty_auto_completion() -> void:
	print("\n--- Hunt Bounty Auto-Completion on Victory ---")
	var gs = _create_game_state()
	var w: WorldSim = gs.world

	var bands := w.bands()
	assert_true(bands.size() > 0, "Bands exist in world")
	var target_band = bands[0]

	var hunt_job := {
		"id": "hunt_test",
		"type": Jobs.TYPE_HUNT,
		"origin_settlement": "highcliff",
		"target_party_id": int(target_band.id),
		"target_name": String(target_band.name),
		"title": "Bounty: Hunt %s" % target_band.name,
		"deadline": 100.0,
		"reward_silver": 160,
		"reward_renown": 5,
		"reward_relation": 5,
	}
	gs.active_jobs.append(hunt_job)

	# Setup battle victory against this band
	w.encounter = target_band.id
	gs.start_encounter_battle()
	assert_eq(gs.pending_battle.get("party_id", -1), target_band.id, "pending_battle tracks target party_id")

	var initial_silver: int = int(gs.silver)
	var initial_renown: int = int(gs.renown)

	# Simulate auto-resolve victory
	var result := {
		"won": true,
		"lost": 0,
		"killed": 10,
		"squads": {},
		"bonds": {},
	}
	gs.apply_result(result)

	assert_eq(gs.active_jobs.size(), 0, "Active hunt job auto-completed on victory")
	assert_eq(gs.completed_jobs.size(), 1, "Hunt job added to completed_jobs")
	assert_true(gs.silver >= initial_silver + 160, "Awarded at least 160 bounty silver")
	assert_true(gs.renown >= initial_renown + 5, "Awarded at least 5 renown")


func test_fair_cancellation_and_deadlines() -> void:
	print("\n--- Fair Cancellation & Deadlines ---")
	var gs = _create_game_state()
	var w: WorldSim = gs.world

	# 1. Target dispersed by another force
	var hunt_job := {
		"id": "hunt_cancelled_test",
		"type": Jobs.TYPE_HUNT,
		"origin_settlement": "highcliff",
		"target_party_id": 999999, # Non-existent party id (dispersed)
		"target_name": "Ghost Raiders",
		"title": "Bounty: Hunt Ghost Raiders",
		"deadline": 100.0,
		"reward_silver": 160,
	}
	gs.active_jobs.append(hunt_job)

	# Trigger check
	gs._check_job_deadlines()
	assert_eq(gs.active_jobs.size(), 0, "Dispersed bandit party cancels hunt job fairly")

	# 2. Deadline expiration
	var courier_job := {
		"id": "courier_expired_test",
		"type": Jobs.TYPE_COURIER,
		"destination_settlement": "ravensford",
		"title": "Old Dispatch",
		"deadline": 10.0,
		"reward_silver": 110,
	}
	gs.active_jobs.append(courier_job)
	w.hour = 12.0
	gs._check_job_deadlines()
	assert_eq(gs.active_jobs.size(), 0, "Expired job removed after deadline passes")


func test_recommendation_guidance() -> void:
	print("\n--- Recommendation Guidance ---")
	var gs := _create_game_state()
	var w: WorldSim = gs.world
	gs.food = 500 # Plenty of food (headcount ~84, so 5+ days)

	var courier_job := {
		"id": "courier_rec",
		"type": Jobs.TYPE_COURIER,
		"destination_settlement": "ravensford",
		"deadline": 50.0,
	}
	gs.active_jobs.append(courier_job)

	var rec: Dictionary = gs.recommendation()
	assert_eq(rec.get("title", ""), "Courier dispatch", "Recommendation points to courier contract")
	assert_eq(rec.get("place", ""), "ravensford", "Recommendation guides player to ravensford")


func test_save_load_persistence() -> void:
	print("\n--- Save/Load Roundtrip Persistence ---")
	var gs = _create_game_state()
	var w: WorldSim = gs.world

	var job := {
		"id": "persisted_job",
		"type": Jobs.TYPE_COURIER,
		"destination_settlement": "ravensford",
		"deadline": 80.0,
		"reward_silver": 110,
	}
	gs.active_jobs.append(job)
	gs.completed_jobs.append({"id": "past_job", "type": Jobs.TYPE_RELIEF})

	w.settlement_jobs["kettlebrook"] = [{"id": "s_job", "type": Jobs.TYPE_RELIEF}]
	w.settlement_jobs_back["kettlebrook"] = 120.0

	var serialized: Dictionary = gs.to_dict()

	var gs2 = GameStateScript.new()
	gs2.persist = false
	var ok: bool = gs2.from_dict(serialized)
	assert_true(ok, "Successfully loaded from dictionary")

	assert_eq(gs2.active_jobs.size(), 1, "Restored 1 active job")
	assert_eq(gs2.active_jobs[0]["id"], "persisted_job", "Restored active job id matches")
	assert_eq(gs2.completed_jobs.size(), 1, "Restored 1 completed job")
	assert_eq(gs2.world.settlement_jobs["kettlebrook"].size(), 1, "Restored settlement jobs on world")
	assert_eq(gs2.world.settlement_jobs_back["kettlebrook"], 120.0, "Restored settlement jobs refresh timer")
