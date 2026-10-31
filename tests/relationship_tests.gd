## Automated validation for the Romance and Allies system (docs/romance-and-allies-plan.md).
## Tests state machine, chapter progression, escrow accounting, emergency grant,
## ceremonies, separation, save migration, and UI contracts headless.
extends SceneTree

const Cultures = preload("res://scripts/data/cultures.gd")
const WorldSim = preload("res://scripts/world/world_sim.gd")
const SocialSim = preload("res://scripts/world/social_sim.gd")
const Relationships = preload("res://scripts/data/relationships.gd")
const RomanceStories = preload("res://scripts/data/romance_stories.gd")
const Economy = preload("res://scripts/data/economy.gd")
const WorldData = preload("res://scripts/world/world_data.gd")

var _failures := 0


func _init() -> void:
	print("--- Running Romance & Allies Validation Suite ---")
	_check_initialization()
	_check_edda_story_progression()
	_check_other_story_progression()
	_check_repair_branch()
	_check_friendship_route()
	_check_ceremony_and_pacts()
	_check_escrow_accounting()
	_check_emergency_grant()
	_check_separation()
	_check_relocation_on_capture()
	_check_save_load_and_migration()
	print("--- Completed: %d failures ---" % _failures)
	quit(_failures)


func _expect(cond: bool, msg: String) -> void:
	if cond:
		print("ok ", msg)
	else:
		_failures += 1
		printerr("FAIL: ", msg)


func _check_initialization() -> void:
	var w := WorldSim.new()
	w.setup(1234, Cultures.VARDISH)

	_expect(w.social != null, "social simulation is initialized on world setup")
	_expect(w.social.people.has("person_edda"), "candidate Edda is registered as a person")

	var edda: Dictionary = w.social.get_candidate_person(RomanceStories.EDDA)
	_expect(edda["residence"] == "ravensford", "Edda initially resides at Ravensford")

	var rel: Dictionary = w.social.get_relationship(RomanceStories.EDDA)
	_expect(rel["status"] == Relationships.UNKNOWN, "initial relationship status is unknown")
	_expect(rel["trust"] == 0, "initial trust starts at 0")

	var house: Dictionary = w.social.get_house(edda["house_id"])
	_expect(house["standing"] == 0, "initial house standing starts at 0 (neutral)")
	_expect(w.social.residents_at("ravensford").size() >= 1, "Edda appears in residents_at('ravensford')")


func _check_edda_story_progression() -> void:
	var w := WorldSim.new()
	w.setup(42, Cultures.VARDISH)
	var soc: SocialSim = w.social

	# Chapter 1: Introduction
	var ctx := {"player_silver": 500, "player_food": 500, "current_hour": w.hour, "invitations_enabled": true}
	var res1 := soc.apply_choice(RomanceStories.EDDA, "know_better", ctx)
	_expect(res1.get("ok", false), "ch1 introduction choice succeeds")

	var rel: Dictionary = soc.get_relationship(RomanceStories.EDDA)
	_expect(rel["trust"] == 10, "ch1 awards 10 trust (trust: %d)" % rel["trust"])
	_expect(rel["status"] == Relationships.COURTING, "ch1 intent choice updates status to courting")
	_expect(rel["romantic_intent"] == true, "romantic intent is set")

	# Repeating choice should not duplicate trust reward
	var res1_dup := soc.apply_choice(RomanceStories.EDDA, "know_better", ctx)
	_expect(not res1_dup.get("reward_claimed", false), "ch1 trust reward is only claimed once")
	_expect(rel["trust"] == 10, "trust does not duplicate on repeat action")

	# Chapter 2: Personal ambitions
	var res2 := soc.apply_choice(RomanceStories.EDDA, "verse", ctx)
	_expect(res2.get("ok", false), "ch2 personal choice succeeds")
	_expect(rel["trust"] == 25, "ch2 awards 15 trust (trust: %d)" % rel["trust"])
	_expect(rel["memories"].size() >= 1, "ch2 records a personal memory")

	# Chapter 3: Shared obligation
	var res3 := soc.apply_choice(RomanceStories.EDDA, "correspondence", ctx)
	_expect(res3.get("ok", false), "ch3 shared choice succeeds")
	_expect(rel["trust"] == 40, "ch3 awards 15 trust (trust: %d)" % rel["trust"])
	var edda_person: Dictionary = soc.get_candidate_person(RomanceStories.EDDA)
	var house: Dictionary = soc.get_house(edda_person["house_id"])
	_expect(house["standing"] == 15, "ch3 awards 15 house standing (standing: %d)" % house["standing"])

	# Chapter 4: Honest resolution (negotiate)
	var res4 := soc.apply_choice(RomanceStories.EDDA, "negotiate", ctx)
	_expect(res4.get("ok", false), "ch4 negotiate choice succeeds")
	_expect(rel["trust"] == 55, "ch4 negotiate awards 15 trust (trust: %d)" % rel["trust"])
	_expect(house["standing"] == 25, "ch4 negotiate awards 10 house standing (standing: %d)" % house["standing"])

	# Chapter 5: Final conversation & Public Marriage
	var res5 := soc.apply_choice(RomanceStories.EDDA, "marry_public", ctx)
	_expect(res5.get("ok", false), "ch5 marry_public succeeds when trust >= 60 and standing >= 25")
	_expect(rel["trust"] == 65, "ch5 final conversation brings trust to 65 (trust: %d)" % rel["trust"])
	_expect(rel["status"] == Relationships.ENGAGED, "status becomes engaged upon scheduling ceremony")
	_expect(soc.scheduled_ceremony.get("active", false), "ceremony is scheduled")


func _check_other_story_progression() -> void:
	for candidate_id in [RomanceStories.FARAH, RomanceStories.KAEDE]:
		var w := WorldSim.new()
		w.setup(314, Cultures.VARDISH)
		var soc: SocialSim = w.social
		var person: Dictionary = soc.get_candidate_person(candidate_id)
		var expected_name := "Farah" if candidate_id == RomanceStories.FARAH else "Kaede"
		_expect(person.get("name") == expected_name and person.get("pronouns") == "she/her",
			"%s is registered as a female romance candidate" % expected_name)
		_expect(not RomanceStories.story_data(candidate_id).get("chapters", {}).is_empty(),
			"%s has a complete authored route" % expected_name)
		var ctx := {"player_silver": 500, "player_food": 500, "current_hour": w.hour, "invitations_enabled": true}
		for choice_id in ["know_better", "verse", "correspondence", "negotiate"]:
			_expect(soc.apply_choice(candidate_id, choice_id, ctx).get("ok", false),
				"%s advances through %s" % [expected_name, choice_id])
		var final := soc.apply_choice(candidate_id, "marry_public", ctx)
		_expect(final.get("ok", false) and soc.get_relationship(candidate_id).get("status") == Relationships.ENGAGED,
			"%s route reaches public engagement" % expected_name)


func _check_repair_branch() -> void:
	var w := WorldSim.new()
	w.setup(99, Cultures.VARDISH)
	var soc: SocialSim = w.social
	var ctx := {"player_silver": 500, "player_food": 500, "current_hour": w.hour, "invitations_enabled": true}

	# Run chapters 1-3
	soc.apply_choice(RomanceStories.EDDA, "know_better", ctx)
	soc.apply_choice(RomanceStories.EDDA, "villager", ctx)
	soc.apply_choice(RomanceStories.EDDA, "defend_district", ctx)
	var rel: Dictionary = soc.get_relationship(RomanceStories.EDDA)
	_expect(rel["trust"] == 40, "trust is 40 before chapter 4")

	# Chapter 4: Deliberate Breach
	var res_breach := soc.apply_choice(RomanceStories.EDDA, "break_promise", ctx)
	_expect(res_breach.get("ok", false), "break promise choice executes")
	_expect(rel["trust"] == 30, "breaking promise reduces trust by 10 (trust: %d)" % rel["trust"])
	_expect(rel["strained"] == true, "relationship is marked strained")

	# Attempting marriage while strained must fail
	var q: Dictionary = soc.get_quest("quest_edda")
	q["chapter"] = 5
	var prev_marry := soc.preview_choice(RomanceStories.EDDA, "marry_public", ctx)
	_expect(not prev_marry.get("ok", false), "cannot marry while relationship is strained")

	# Execute repair branch
	q["chapter"] = 4
	var res_repair := soc.apply_choice(RomanceStories.EDDA, "repair_promise", ctx)
	_expect(res_repair.get("ok", false), "repair restitution choice executes")
	_expect(rel["trust"] == 55, "repair awards +25 trust returning to honest total (trust: %d)" % rel["trust"])
	_expect(rel["strained"] == false, "strained flag is cleared after repair")


func _check_friendship_route() -> void:
	var w := WorldSim.new()
	w.setup(777, Cultures.VARDISH)
	var soc: SocialSim = w.social
	var ctx := {"player_silver": 500, "player_food": 500, "current_hour": w.hour, "invitations_enabled": true}

	# Chapter 1: Friendship intent
	soc.apply_choice(RomanceStories.EDDA, "offer_help", ctx)
	var rel: Dictionary = soc.get_relationship(RomanceStories.EDDA)
	_expect(rel["romantic_intent"] == false, "friendship route has romantic_intent = false")
	_expect(rel["status"] == Relationships.ACQUAINTED, "status is acquainted")

	# Complete Ch 2-4
	soc.apply_choice(RomanceStories.EDDA, "news", ctx)
	soc.apply_choice(RomanceStories.EDDA, "correspondence", ctx)
	soc.apply_choice(RomanceStories.EDDA, "negotiate", ctx)

	# Marriage preview must fail without romantic intent
	var prev_marry := soc.preview_choice(RomanceStories.EDDA, "marry_public", ctx)
	_expect(not prev_marry.get("ok", false), "cannot marry without romantic intent")

	# Sworn friendship choice
	var res_friend := soc.apply_choice(RomanceStories.EDDA, "friendship", ctx)
	_expect(res_friend.get("ok", false), "friendship ending succeeds")
	_expect(rel["status"] == Relationships.FRIENDSHIP, "relationship status becomes friendship")

	var p: Dictionary = soc.get_candidate_person(RomanceStories.EDDA)
	var pact: Dictionary = soc.get_pact(p["house_id"])
	_expect(not pact.is_empty(), "house pact is successfully formed via friendship route")
	_expect(pact["origin"] == "friendship", "pact origin is marked friendship")


func _check_ceremony_and_pacts() -> void:
	var w := WorldSim.new()
	w.setup(555, Cultures.VARDISH)
	var soc: SocialSim = w.social

	# Schedule public ceremony
	soc.schedule_ceremony(RomanceStories.EDDA, false, "ravensford", w.hour)
	_expect(soc.scheduled_ceremony.get("active", false), "ceremony is active")
	_expect(soc.scheduled_ceremony.get("cost_silver", 0) == Relationships.PUBLIC_CEREMONY_SILVER, "public ceremony costs 100 silver")

	# Advance world by 6 hours
	# Friendly lords who stop to talk are waved on, as the "Leave" button does.
	w.wait(6.5)
	for i in 20:
		w.step(6.5)
		if w.encounter == -1:
			break
		w.encounter = -1

	_expect(soc.scheduled_ceremony.get("completed", false), "ceremony completed after 6 hours")
	var rel: Dictionary = soc.get_relationship(RomanceStories.EDDA)
	_expect(rel["status"] == Relationships.MARRIED, "status becomes married upon ceremony completion")

	var edda_person: Dictionary = soc.get_candidate_person(RomanceStories.EDDA)
	var pact: Dictionary = soc.get_pact(edda_person["house_id"])
	_expect(not pact.is_empty(), "marriage ceremony formed an active house pact")


func _check_escrow_accounting() -> void:
	var w := WorldSim.new()
	w.setup(333, Cultures.VARDISH)
	var soc: SocialSim = w.social

	# Sponsor 300 silver into Ravensford
	var res := soc.sponsor_replacements("house_vardmark_ravensford", "ravensford", "settlement", 300, w.hour, "vardmark")
	_expect(res.get("ok", false), "sponsor replacements project created")
	var proj_id: String = res["project"]["id"]

	var proj: Dictionary = soc.projects[proj_id]
	_expect(proj["escrow_total"] == 300, "escrow total is 300")
	_expect(proj["escrow_remaining"] == 300, "escrow remaining is 300")

	# Simulate garrison recruitment consuming escrow
	var spent := soc.consume_escrow_for_recruitment("ravensford", "settlement", 10, 15)
	_expect(spent == 150, "escrow paid 150 silver for 10 recruits")
	_expect(proj["escrow_remaining"] == 150, "escrow remaining is now 150")
	_expect(proj["escrow_spent"] == 150, "escrow spent is now 150")

	# Verify accounting invariant
	var invariant_holds: bool = proj["escrow_total"] == proj["escrow_remaining"] + proj["escrow_spent"] + proj["escrow_refunded"]
	_expect(invariant_holds, "escrow invariant total = remaining + spent + refunded holds")


func _check_emergency_grant() -> void:
	var w := WorldSim.new()
	w.setup(888, Cultures.VARDISH)
	var soc: SocialSim = w.social

	var edda_person: Dictionary = soc.get_candidate_person(RomanceStories.EDDA)
	var hid: String = edda_person["house_id"]
	var house: Dictionary = soc.get_house(hid)
	var head: Dictionary = soc.get_person(house["head_person_id"])
	var lord_id: int = int(head["lord_id"])

	# Find lord and ensure adequate purse
	for l in w.lords:
		if int(l["id"]) == lord_id:
			l["silver"] = 500
			break

	var res_grant := soc.request_grant(hid, w)
	_expect(res_grant.get("ok", false), "emergency grant succeeds with solvent lord")
	_expect(res_grant.get("amount", 0) == Relationships.GRANT_MAX_SILVER, "grant awarded max 150 silver")

	# Check lord purse was reduced by exactly grant amount
	for l in w.lords:
		if int(l["id"]) == lord_id:
			_expect(l["silver"] == 350, "lord purse reduced from 500 to 350 (retains >= 300 reserve)")
			break

	# Immediate repeat must be blocked by cooldown
	var res_grant_cd := soc.request_grant(hid, w)
	_expect(not res_grant_cd.get("ok", false), "second grant blocked by 14-day global cooldown")


func _check_separation() -> void:
	var w := WorldSim.new()
	w.setup(111, Cultures.VARDISH)
	var soc: SocialSim = w.social

	soc.limits["current_partner_id"] = RomanceStories.EDDA
	var res := soc.separate(RomanceStories.EDDA)
	_expect(res.get("ok", false), "separation succeeds")

	var rel: Dictionary = soc.get_relationship(RomanceStories.EDDA)
	_expect(rel["status"] == Relationships.ENDED, "relationship status is ended")
	_expect(soc.limits["current_partner_id"] == "", "current partner cleared")


func _check_relocation_on_capture() -> void:
	var w := WorldSim.new()
	w.setup(222, Cultures.VARDISH)
	var soc: SocialSim = w.social

	# Sponsor project at Ravensford
	soc.sponsor_replacements("house_vardmark_ravensford", "ravensford", "settlement", 200, w.hour, "vardmark")

	# Ravensford captured by Kharzan
	w.set_owner("ravensford", "kharzan")

	# Resident relocated
	var edda: Dictionary = soc.get_candidate_person(RomanceStories.EDDA)
	_expect(edda["residence"] != "ravensford", "Edda relocated from captured settlement")

	# Escrow refunded
	var refunds: Array = soc.drain_pending_settlements()
	_expect(refunds.size() == 1, "pending refund queued for captured settlement escrow")
	_expect(refunds[0]["amount"] == 200, "full unspent escrow (200 silver) refunded")


func _check_save_load_and_migration() -> void:
	var w := WorldSim.new()
	w.setup(444, Cultures.VARDISH)
	var ctx := {"player_silver": 500, "player_food": 500, "current_hour": w.hour, "invitations_enabled": true}

	# Advance Edda story to chapter 3
	w.social.apply_choice(RomanceStories.EDDA, "know_better", ctx)
	w.social.apply_choice(RomanceStories.EDDA, "villager", ctx)

	# Serialize
	var dict_data := w.to_dict()
	var json_str := JSON.stringify(dict_data)

	# Deserialize
	var parsed: Dictionary = JSON.parse_string(json_str)
	var w2 := WorldSim.new()
	w2.from_dict(parsed)

	_expect(w2.social != null, "social simulation restored from save")
	var rel2: Dictionary = w2.social.get_relationship(RomanceStories.EDDA)
	_expect(rel2["trust"] == 25, "trust preserved through save/load (trust: %d)" % rel2["trust"])
	_expect(rel2["status"] == Relationships.COURTING, "status preserved through save/load")
	_expect(w2.social.get_quest("quest_edda")["chapter"] == 3, "quest chapter preserved at 3")

	# Test migration from save without social dictionary (older v5 save)
	var dict_v5: Dictionary = dict_data.duplicate(true)
	dict_v5.erase("social")
	var w_migrated := WorldSim.new()
	w_migrated.from_dict(dict_v5)
	_expect(w_migrated.social != null, "old save without social state migrated deterministically")
	_expect(w_migrated.social.people.has("person_edda"), "migrated save initializes candidate Edda")
