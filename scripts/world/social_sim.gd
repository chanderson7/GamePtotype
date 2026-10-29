## Pure-logic simulation of social relationships, court residents, courtships,
## house pacts, support escrows, and letters. Owned and serialized by WorldSim.
## No nodes, no drawing, deterministic.
extends RefCounted

const PersonalConversations = preload("res://scripts/data/personal_conversations.gd")
const Relationships = preload("res://scripts/data/relationships.gd")
const RomanceStories = preload("res://scripts/data/romance_stories.gd")
const WorldData = preload("res://scripts/world/world_data.gd")
const Cultures = preload("res://scripts/data/cultures.gd")
const Economy = preload("res://scripts/data/economy.gd")

var personal_conversations: Dictionary = {}
var people: Dictionary = {}
var houses: Dictionary = {}
var relationships: Dictionary = {}
var quests: Dictionary = {}
var pacts: Dictionary = {}
var projects: Dictionary = {}
var letters: Array = []
var limits: Dictionary = {
	"current_partner_id": "",
	"last_grant_hour": -999.0,
	"last_military_help_hour": -999.0,
	"active_military_assignment_id": ""
}
var pending_settlements: Array = []
var scheduled_ceremony: Dictionary = {}

var _next_project_id := 1
var _next_letter_id := 1


func setup(seed_val: int, lords_list: Array, settlements: Dictionary) -> void:
	personal_conversations.clear()
	people.clear()
	houses.clear()
	relationships.clear()
	quests.clear()
	pacts.clear()
	projects.clear()
	letters.clear()
	pending_settlements.clear()
	scheduled_ceremony.clear()
	_next_project_id = 1
	_next_letter_id = 1

	limits = {
		"current_partner_id": "",
		"last_grant_hour": -999.0,
		"last_military_help_hour": -999.0,
		"active_military_assignment_id": ""
	}

	# 1. Initialize houses from lords list.
	for l in lords_list:
		var lord_id: int = int(l.get("id", 0))
		var fief: String = String(l.get("fief", ""))
		var realm: String = String(l.get("realm", ""))
		var house_id := "house_%s_%d" % [realm, lord_id]
		var person_id := "person_lord_%d" % lord_id
		var lord_name := String(l.get("name", "Noble"))

		var p_lord := {
			"id": person_id,
			"content_id": "",
			"name": lord_name,
			"age": 42,
			"pronouns": "he/him",
			"role": "Head of Household",
			"culture": String(l.get("culture", Cultures.VARDISH)),
			"house_id": house_id,
			"lord_id": lord_id,
			"residence": fief if fief != "" else String(l.get("seat", "")),
			"status": "normal",
			"interests": ["warband", "estate"],
			"boundaries": ["defends fief"],
			"memories": []
		}
		people[person_id] = p_lord

		var h := {
			"id": house_id,
			"name": "Household of %s" % lord_name,
			"head_person_id": person_id,
			"member_ids": [person_id],
			"seat": fief if fief != "" else String(l.get("seat", "")),
			"realm": realm,
			"standing": 0
		}
		houses[house_id] = h

	# 2. Initialize authored candidates.
	# Edda is anchored to Ravensford's house.
	var ravensford_house_id := ""
	for h_id in houses:
		if houses[h_id]["seat"] == "ravensford":
			ravensford_house_id = h_id
			break
	if ravensford_house_id == "" and not houses.is_empty():
		ravensford_house_id = houses.keys()[0]

	for cand_id in [RomanceStories.EDDA, RomanceStories.FARID, RomanceStories.KAEDE]:
		var cdata: Dictionary = RomanceStories.candidate_data(cand_id)
		if cdata.is_empty():
			continue
		var pid := "person_%s" % cand_id
		var hid := ravensford_house_id
		if cand_id != RomanceStories.EDDA:
			# Find seat match
			for h_id in houses:
				if houses[h_id]["seat"] == cdata.get("initial_seat", ""):
					hid = h_id
					break

		var p_cand := {
			"id": pid,
			"content_id": cand_id,
			"name": cdata["name"],
			"age": cdata["age"],
			"pronouns": cdata["pronouns"],
			"role": cdata["role"],
			"culture": cdata["culture"],
			"house_id": hid,
			"lord_id": -1,
			"residence": cdata["initial_seat"],
			"status": "normal",
			"interests": cdata["interests"].duplicate(),
			"boundaries": cdata["boundaries"].duplicate(),
			"memories": []
		}
		people[pid] = p_cand
		if houses.has(hid):
			houses[hid]["member_ids"].append(pid)

		# Initial relationship
		relationships[cand_id] = {
			"candidate_id": cand_id,
			"person_id": pid,
			"trust": 0,
			"romantic_intent": false,
			"status": Relationships.UNKNOWN,
			"paused_reasons": [],
			"intent_chosen": false,
			"milestones": {},
			"strained": false,
			"strained_reason": "",
			"memories": []
		}

		# Initial quest
		quests["quest_%s" % cand_id] = {
			"id": "quest_%s" % cand_id,
			"content_id": cand_id,
			"chapter": 1,
			"step": "intro",
			"bound_targets": {"seat": cdata["initial_seat"]},
			"progress": {},
			"chosen_branch": "",
			"start_hour": 0.0,
			"strained_reason": "",
			"consumed_rewards": []
		}


# ---------------------------------------------------------------- serialization

func to_dict() -> Dictionary:
	return {
		"personal_conversations": personal_conversations,
		"people": people,
		"houses": houses,
		"relationships": relationships,
		"quests": quests,
		"pacts": pacts,
		"projects": projects,
		"letters": letters,
		"limits": limits,
		"pending_settlements": pending_settlements,
		"scheduled_ceremony": scheduled_ceremony,
		"next_project_id": _next_project_id,
		"next_letter_id": _next_letter_id
	}


func from_dict(data: Dictionary) -> void:
	personal_conversations = data.get("personal_conversations", {}).duplicate(true)
	people = data.get("people", {}).duplicate(true)
	houses = data.get("houses", {}).duplicate(true)
	relationships = data.get("relationships", {}).duplicate(true)
	quests = data.get("quests", {}).duplicate(true)
	pacts = data.get("pacts", {}).duplicate(true)
	projects = data.get("projects", {}).duplicate(true)
	letters = data.get("letters", []).duplicate(true)
	limits = data.get("limits", {
		"current_partner_id": "",
		"last_grant_hour": -999.0,
		"last_military_help_hour": -999.0,
		"active_military_assignment_id": ""
	}).duplicate(true)
	pending_settlements = data.get("pending_settlements", []).duplicate(true)
	scheduled_ceremony = data.get("scheduled_ceremony", {}).duplicate(true)
	_next_project_id = int(data.get("next_project_id", 1))
	_next_letter_id = int(data.get("next_letter_id", 1))
	# JSON reads all numbers as floats; restore integral identity/progression fields.
	for person in people.values():
		for key in ["age", "lord_id"]:
			if person.has(key): person[key] = int(person[key])
	for house in houses.values():
		if house.has("standing"): house["standing"] = int(house["standing"])
	for relationship in relationships.values():
		if relationship.has("trust"): relationship["trust"] = int(relationship["trust"])
	for quest in quests.values():
		if quest.has("chapter"): quest["chapter"] = int(quest["chapter"])



# ---------------------------------------------------------------- ticking & updates

func step(dt: float, world_ref: RefCounted) -> void:
	var cur_hour: float = world_ref.hour

	# 1. Advance scheduled ceremony if active.
	if scheduled_ceremony.get("active", false) and not scheduled_ceremony.get("completed", false):
		var target_hour := float(scheduled_ceremony.get("scheduled_at_hour", 0.0)) + float(scheduled_ceremony.get("duration_hours", 6.0))
		if cur_hour >= target_hour:
			_conclude_ceremony(world_ref)

	# 2. Check project expiry (7 days).
	for proj_id in projects.keys():
		var p: Dictionary = projects[proj_id]
		if p["status"] == "active":
			if cur_hour >= float(p.get("expiry_hour", 0.0)):
				p["status"] = "expired"
				var rem: int = int(p.get("escrow_remaining", 0))
				if rem > 0:
					p["escrow_refunded"] = int(p.get("escrow_refunded", 0)) + rem
					p["escrow_remaining"] = 0
					pending_settlements.append({
						"type": "refund_silver",
						"amount": rem,
						"project_id": proj_id,
						"reason": "Escrow expired after 7 days"
					})


## Consumes escrow for recruitment when a settlement or lord refills.
## Guarantees invariant: total = remaining + spent + refunded.
func consume_escrow_for_recruitment(target_id: String, target_kind: String, recruit_count: int, unit_cost: int) -> int:
	var needed := recruit_count * unit_cost
	if needed <= 0:
		return 0
	var spent := 0
	for proj_id in projects:
		var p: Dictionary = projects[proj_id]
		if p["status"] == "active" and p["target_id"] == target_id and p["target_kind"] == target_kind:
			var rem: int = int(p["escrow_remaining"])
			if rem > 0:
				var take := mini(needed - spent, rem)
				p["escrow_remaining"] = rem - take
				p["escrow_spent"] = int(p["escrow_spent"]) + take
				p["recruits_funded"] = int(p["recruits_funded"]) + int(ceil(float(take) / maxf(1.0, float(unit_cost))))
				spent += take
				if int(p["escrow_remaining"]) == 0:
					p["status"] = "completed"
				if spent >= needed:
					break
	return spent


## Called when a settlement is captured by an enemy realm.
func on_settlement_captured(settlement_id: String, new_owner: String, old_owner: String, world_ref: RefCounted) -> void:
	# 1. Refund any active escrow projects on this settlement immediately.
	for proj_id in projects:
		var p: Dictionary = projects[proj_id]
		if p["status"] == "active" and p["target_id"] == settlement_id:
			var rem: int = int(p["escrow_remaining"])
			if rem > 0:
				p["escrow_refunded"] = int(p["escrow_refunded"]) + rem
				p["escrow_remaining"] = 0
				pending_settlements.append({
					"type": "refund_silver",
					"amount": rem,
					"project_id": proj_id,
					"reason": "Settlement %s captured by enemy" % settlement_id
				})
			p["status"] = "cancelled"

	# 2. Relocate residents living at settlement_id.
	for pid in people:
		var person: Dictionary = people[pid]
		if person.get("residence", "") == settlement_id:
			_relocate_person(person, new_owner, world_ref)


func _relocate_person(person: Dictionary, new_owner: String, world_ref: RefCounted) -> void:
	var hid: String = person.get("house_id", "")
	var house: Dictionary = houses.get(hid, {})
	var realm: String = house.get("realm", "")

	# Order of relocation:
	# 1. Another holding of the same realm/house
	var candidates: Array = world_ref.holdings_of(realm)
	var new_seat := ""
	for c in candidates:
		if c != person["residence"]:
			new_seat = c
			break
	if new_seat == "":
		new_seat = world_ref.capital_of(realm)

	if new_seat != "":
		person["residence"] = new_seat
		person["status"] = "relocated"
		add_memory(person["id"], "Relocated to %s following the loss of %s." % [
			WorldData.settlement(new_seat)["name"],
			WorldData.settlement(String(person.get("residence", "")))["name"]
		])
		add_letter(person["id"], "relocation", "", world_ref.hour, new_seat)
	else:
		person["status"] = "displaced"
		add_memory(person["id"], "Displaced from %s." % person["residence"])


# ---------------------------------------------------------------- lookups & queries

func residents_at(settlement_id: String) -> Array:
	var list := []
	for pid in people:
		var p: Dictionary = people[pid]
		if p.get("residence", "") == settlement_id and p.get("content_id", "") != "":
			list.append(p)
	return list


func get_person(person_id: String) -> Dictionary:
	return people.get(person_id, {})


func get_candidate_person(candidate_id: String) -> Dictionary:
	var rel: Dictionary = relationships.get(candidate_id, {})
	var pid: String = rel.get("person_id", "")
	return people.get(pid, {})


func get_house(house_id: String) -> Dictionary:
	return houses.get(house_id, {})


func get_relationship(candidate_id: String) -> Dictionary:
	return relationships.get(candidate_id, {})


func get_quest(quest_id: String) -> Dictionary:
	return quests.get(quest_id, {})


func get_pact(house_id: String) -> Dictionary:
	return pacts.get(house_id, {})


func unread_letters_count() -> int:
	var count := 0
	for l in letters:
		if not l.get("read", false):
			count += 1
	return count


func add_memory(person_id: String, text: String) -> void:
	if not people.has(person_id):
		return
	var mems: Array = people[person_id].get("memories", [])
	mems.append(text)
	if mems.size() > 30:
		mems.pop_front()
	people[person_id]["memories"] = mems

	# Also record on relationship if it's a candidate
	for cand_id in relationships:
		if relationships[cand_id]["person_id"] == person_id:
			var r_mems: Array = relationships[cand_id].get("memories", [])
			r_mems.append(text)
			if r_mems.size() > 30:
				r_mems.pop_front()
			relationships[cand_id]["memories"] = r_mems


func add_letter(sender_id: String, template_key: String, quest_id: String, current_hour: float, destination: String) -> Dictionary:
	var l := {
		"id": "let_%d" % _next_letter_id,
		"sender_id": sender_id,
		"template_key": template_key,
		"quest_id": quest_id,
		"created_hour": current_hour,
		"read": false,
		"acknowledged": false,
		"destination": destination
	}
	_next_letter_id += 1
	letters.append(l)
	return l


func drain_pending_settlements() -> Array:
	var list := pending_settlements.duplicate(true)
	pending_settlements.clear()
	return list


# ---------------------------------------------------------------- choices & story engine

static func chapter_for_choice(choice_id: String) -> int:
	match choice_id:
		"know_better", "offer_help", "another_time", "work", "boast", "help":
			return 1
		"villager", "news", "verse":
			return 2
		"fund_muster", "defend_district", "correspondence":
			return 3
		"negotiate", "support_edda", "break_promise", "repair_promise", "decline":
			return 4
		"marry_public", "marry_private", "friendship", "remain_close", "part_respectfully":
			return 5
		_:
			return 0


## Previews consequences and availability of a choice.
func preview_choice(candidate_id: String, choice_id: String, context: Dictionary) -> Dictionary:
	var rel: Dictionary = relationships.get(candidate_id, {})
	var q: Dictionary = quests.get("quest_%s" % candidate_id, {})
	var person: Dictionary = get_candidate_person(candidate_id)
	var house: Dictionary = houses.get(person.get("house_id", ""), {})
	var current_ch: int = int(q.get("chapter", 1))
	var target_ch: int = chapter_for_choice(choice_id)

	var out := {
		"ok": true,
		"reason": "",
		"cost_silver": 0,
		"cost_food": 0,
		"trust_change": 0,
		"standing_change": 0,
		"new_status": "",
		"requires_confirmation": false,
		"confirmation_text": "",
		"reward_claimed": false
	}

	if target_ch > 0 and target_ch != current_ch:
		if target_ch < current_ch:
			out["ok"] = false
			out["reason"] = "Chapter %d is already completed." % target_ch
			return out
		elif target_ch > current_ch:
			out["ok"] = false
			out["reason"] = "Chapter %d prerequisites not yet reached." % target_ch
			return out

	match target_ch:
		1:
			if choice_id in ["know_better", "offer_help", "another_time"]:
				if not q.get("consumed_rewards", []).has("edda_ch1_intro"):
					out["trust_change"] = Relationships.TRUST_INTRO_REWARD
				if choice_id == "know_better":
					var check := Relationships.can_court(rel, person, bool(context.get("invitations_enabled", true)), String(limits.get("current_partner_id", "")))
					if not check["ok"]:
						out["ok"] = false
						out["reason"] = check["reason"]
					else:
						out["new_status"] = Relationships.COURTING
				elif choice_id == "offer_help":
					out["new_status"] = Relationships.ACQUAINTED
		2:
			if not q.get("consumed_rewards", []).has("edda_ch2_personal"):
				out["trust_change"] = Relationships.TRUST_PERSONAL_REWARD
		3:
			var rkey := "edda_ch3_shared"
			var unclaimed: bool = not q.get("consumed_rewards", []).has(rkey)
			if choice_id == "fund_muster":
				out["cost_silver"] = mini(300, int(context.get("player_silver", 0)))
				if out["cost_silver"] < 50:
					out["ok"] = false
					out["reason"] = "Requires at least 50 silver for muster sponsorship."
				if unclaimed:
					out["trust_change"] = Relationships.TRUST_SHARED_REWARD
					out["standing_change"] = Relationships.TRUST_SHARED_REWARD
			elif choice_id in ["defend_district", "correspondence"]:
				if unclaimed:
					out["trust_change"] = Relationships.TRUST_SHARED_REWARD
					out["standing_change"] = Relationships.TRUST_SHARED_REWARD
		4:
			match choice_id:
				"negotiate":
					if not q.get("consumed_rewards", []).has("edda_ch4_negotiate"):
						out["trust_change"] = Relationships.TRUST_CH4_HONEST
						out["standing_change"] = 10
				"support_edda":
					if not q.get("consumed_rewards", []).has("edda_ch4_support"):
						out["trust_change"] = Relationships.TRUST_CH4_HONEST
						out["standing_change"] = -10
				"break_promise":
					out["trust_change"] = Relationships.TRUST_CH4_BREACH
					out["standing_change"] = 10
					out["requires_confirmation"] = true
					out["confirmation_text"] = "Breaking your promise to Edda will damage her trust and strain your relationship."
				"repair_promise":
					if not q.get("consumed_rewards", []).has("edda_ch4_repaired"):
						out["trust_change"] = Relationships.TRUST_CH4_REPAIR
					out["cost_silver"] = 100
					if int(context.get("player_silver", 0)) < 100:
						out["ok"] = false
						out["reason"] = "Requires 100 silver to provide restitution."
		5:
			# In chapter 5, check trust + ch5 final bonus
			var sim_trust: int = int(rel.get("trust", 0))
			if not q.get("consumed_rewards", []).has("edda_ch5_final"):
				sim_trust += Relationships.TRUST_CH5_FINAL
				out["trust_change"] = Relationships.TRUST_CH5_FINAL

			var sim_rel: Dictionary = rel.duplicate()
			sim_rel["trust"] = sim_trust

			match choice_id:
				"marry_public":
					var check := Relationships.can_marry_public(sim_rel, house)
					if not check["ok"]:
						out["ok"] = false
						out["reason"] = check["reason"]
					else:
						out["cost_silver"] = Relationships.PUBLIC_CEREMONY_SILVER
						out["cost_food"] = Relationships.PUBLIC_CEREMONY_FOOD
						if int(context.get("player_silver", 0)) < out["cost_silver"] or int(context.get("player_food", 0)) < out["cost_food"]:
							out["ok"] = false
							out["reason"] = "Requires %d silver and %d rations for public celebration." % [out["cost_silver"], out["cost_food"]]
						out["new_status"] = Relationships.ENGAGED
						out["requires_confirmation"] = true
						out["confirmation_text"] = "Schedule a public ceremony at Ravensford with Edda?"
				"marry_private":
					var check := Relationships.can_marry_private(sim_rel)
					if not check["ok"]:
						out["ok"] = false
						out["reason"] = check["reason"]
					else:
						out["cost_silver"] = 0
						out["cost_food"] = 0
						out["standing_change"] = Relationships.STANDING_PRIVATE_VOWS_PENALTY
						out["new_status"] = Relationships.MARRIED
						out["requires_confirmation"] = true
						out["confirmation_text"] = "Exchange private vows? Bypassing house approval costs 10 standing with House Caldmoor."
				"friendship":
					var check := Relationships.can_swear_friendship(sim_rel, house)
					if not check["ok"]:
						out["ok"] = false
						out["reason"] = check["reason"]
					else:
						out["new_status"] = Relationships.FRIENDSHIP
						out["standing_change"] = Relationships.STANDING_PACT_BONUS
						out["requires_confirmation"] = true
						out["confirmation_text"] = "Swear mutual cooperation and friendship with Edda and her house?"
				"remain_close":
					out["new_status"] = Relationships.COMMITTED
				"part_respectfully":
					out["new_status"] = Relationships.ENDED
					out["requires_confirmation"] = true
					out["confirmation_text"] = "Part ways with Edda? This respectfully concludes courtship while preserving earned standing."

	return out


## Applies a validated choice, updating state and consuming rewards once.
func apply_choice(candidate_id: String, choice_id: String, context: Dictionary) -> Dictionary:
	var prev := preview_choice(candidate_id, choice_id, context)
	if not prev["ok"]:
		return prev

	var rel: Dictionary = relationships[candidate_id]
	var q: Dictionary = quests["quest_%s" % candidate_id]
	var person: Dictionary = get_candidate_person(candidate_id)
	var house: Dictionary = houses[person["house_id"]]
	var target_ch: int = chapter_for_choice(choice_id)
	var reward_claimed := false

	# Apply trust & standing changes
	rel["trust"] = clampi(int(rel["trust"]) + int(prev["trust_change"]), Relationships.TRUST_MIN, Relationships.TRUST_MAX)
	house["standing"] = clampi(int(house["standing"]) + int(prev["standing_change"]), Relationships.STANDING_MIN, Relationships.STANDING_MAX)

	match target_ch:
		1:
			if choice_id in ["know_better", "offer_help", "another_time"]:
				var rkey := "edda_ch1_intro"
				if not q["consumed_rewards"].has(rkey):
					q["consumed_rewards"].append(rkey)
					reward_claimed = true
				if choice_id == "know_better":
					rel["romantic_intent"] = true
					rel["intent_chosen"] = true
					rel["status"] = Relationships.COURTING
					limits["current_partner_id"] = candidate_id
					add_memory(person["id"], "Agreed to court Edda.")
				elif choice_id == "offer_help":
					rel["romantic_intent"] = false
					rel["intent_chosen"] = true
					rel["status"] = Relationships.ACQUAINTED
					add_memory(person["id"], "Offered friendship and service to Edda.")
				q["chapter"] = 2
				add_letter(person["id"], "ch2_invitation", q["id"], float(context.get("current_hour", 0.0)), person["residence"])
		2:
			var rkey := "edda_ch2_personal"
			if not q["consumed_rewards"].has(rkey):
				q["consumed_rewards"].append(rkey)
				reward_claimed = true
			q["chapter"] = 3
			add_memory(person["id"], "Shared personal accounts and verse with Edda.")
		3:
			var rkey := "edda_ch3_shared"
			if not q["consumed_rewards"].has(rkey):
				q["consumed_rewards"].append(rkey)
				reward_claimed = true
			if choice_id == "fund_muster":
				var spent: int = int(prev["cost_silver"])
				if spent > 0:
					sponsor_replacements(house["id"], person["residence"], "settlement", spent, float(context.get("current_hour", 0.0)), house.get("realm", "vardmark"))
			q["chapter"] = 4
			add_memory(person["id"], "Helped protect the border villages.")
		4:
			match choice_id:
				"negotiate":
					var rkey := "edda_ch4_negotiate"
					if not q["consumed_rewards"].has(rkey):
						q["consumed_rewards"].append(rkey)
						reward_claimed = true
					q["chapter"] = 5
					add_memory(person["id"], "Negotiated a balanced defense agreement for the valley.")
				"support_edda":
					var rkey := "edda_ch4_support"
					if not q["consumed_rewards"].has(rkey):
						q["consumed_rewards"].append(rkey)
						reward_claimed = true
					q["chapter"] = 5
					add_memory(person["id"], "Stood firmly with Edda against the elders.")
				"break_promise":
					rel["strained"] = true
					rel["strained_reason"] = "broken_promise"
					q["strained_reason"] = "broken_promise"
					add_memory(person["id"], "Broke your word to Edda before the house council.")
				"repair_promise":
					var rkey := "edda_ch4_repaired"
					if not q["consumed_rewards"].has(rkey):
						q["consumed_rewards"].append(rkey)
						reward_claimed = true
					rel["strained"] = false
					rel["strained_reason"] = ""
					q["strained_reason"] = ""
					q["chapter"] = 5
					add_memory(person["id"], "Repaired your breach of word through honest restitution.")
		5:
			var rkey := "edda_ch5_final"
			if not q["consumed_rewards"].has(rkey):
				q["consumed_rewards"].append(rkey)
				reward_claimed = true
			match choice_id:
				"marry_public":
					rel["status"] = Relationships.ENGAGED
					schedule_ceremony(candidate_id, false, person["residence"], float(context.get("current_hour", 0.0)))
				"marry_private":
					rel["status"] = Relationships.MARRIED
					limits["current_partner_id"] = candidate_id
					add_memory(person["id"], "Exchanged private vows with Edda.")
				"friendship":
					rel["status"] = Relationships.FRIENDSHIP
					_form_pact(house["id"], "friendship", [person["id"], "player"], [person["residence"], "thornwall"], float(context.get("current_hour", 0.0)))
					add_memory(person["id"], "Swore mutual cooperation and friendship with Edda.")
				"remain_close":
					rel["status"] = Relationships.COMMITTED
				"part_respectfully":
					separate(candidate_id)

	prev["reward_claimed"] = reward_claimed
	return prev


# ---------------------------------------------------------------- ceremonies & pacts

func schedule_ceremony(candidate_id: String, is_private: bool, settlement_id: String, cur_hour: float) -> Dictionary:
	var person: Dictionary = get_candidate_person(candidate_id)
	var silver_cost := Relationships.PRIVATE_CEREMONY_SILVER if is_private else Relationships.PUBLIC_CEREMONY_SILVER
	var food_cost := Relationships.PRIVATE_CEREMONY_FOOD if is_private else Relationships.PUBLIC_CEREMONY_FOOD

	scheduled_ceremony = {
		"active": true,
		"candidate_id": candidate_id,
		"person_id": person["id"],
		"is_private": is_private,
		"settlement_id": settlement_id,
		"scheduled_at_hour": cur_hour,
		"duration_hours": Relationships.CEREMONY_HOURS,
		"cost_silver": silver_cost,
		"cost_food": food_cost,
		"completed": false
	}
	return scheduled_ceremony


func _conclude_ceremony(world_ref: RefCounted) -> void:
	if not scheduled_ceremony.get("active", false):
		return
	scheduled_ceremony["completed"] = true
	scheduled_ceremony["active"] = false
	var cand_id: String = String(scheduled_ceremony.get("candidate_id", ""))
	var person: Dictionary = get_candidate_person(cand_id)
	var rel: Dictionary = relationships.get(cand_id, {})
	var hid: String = person.get("house_id", "")
	rel["status"] = Relationships.MARRIED
	limits["current_partner_id"] = cand_id

	add_memory(person["id"], "Wedded in solemn ceremony at %s." % WorldData.settlement(String(scheduled_ceremony["settlement_id"]))["name"])
	if not scheduled_ceremony.get("is_private", false):
		_form_pact(hid, "marriage", [person["id"], "player"], [person["residence"], "thornwall"], world_ref.hour)


func _form_pact(house_id: String, origin: String, signatories: Array, protected_sites: Array, cur_hour: float) -> Dictionary:
	var pact := {
		"house_id": house_id,
		"status": "active",
		"origin": origin,
		"signatories": signatories,
		"protected_sites": protected_sites,
		"created_hour": cur_hour
	}
	pacts[house_id] = pact
	return pact


func separate(candidate_id: String) -> Dictionary:
	var rel: Dictionary = relationships.get(candidate_id, {})
	var person: Dictionary = get_candidate_person(candidate_id)
	rel["status"] = Relationships.ENDED
	if limits.get("current_partner_id", "") == candidate_id:
		limits["current_partner_id"] = ""
	add_memory(person["id"], "Parted ways respectfully.")
	return {"ok": true}


# ---------------------------------------------------------------- pact benefits & economy

func request_grant(house_id: String, world_ref: RefCounted) -> Dictionary:
	var house: Dictionary = houses.get(house_id, {})
	if house.is_empty():
		return {"ok": false, "reason": "Household does not exist."}
	var head_pid: String = house.get("head_person_id", "")
	var head: Dictionary = people.get(head_pid, {})
	var lord_id: int = int(head.get("lord_id", -1))
	var lord = null
	for l in world_ref.lords:
		if int(l["id"]) == lord_id:
			lord = l
			break
	if lord == null:
		return {"ok": false, "reason": "House lord is not available."}

	var check := Relationships.can_grant(lord, world_ref.hour, float(limits.get("last_grant_hour", -999.0)))
	if not check["ok"]:
		return check

	var amount: int = int(check["amount"])
	lord["silver"] = int(lord["silver"]) - amount
	limits["last_grant_hour"] = world_ref.hour
	add_memory(head_pid, "Granted %d silver to the player's warband." % amount)
	return {"ok": true, "amount": amount}


func sponsor_replacements(house_id: String, target_id: String, target_kind: String, amount: int, cur_hour: float, expected_owner: String) -> Dictionary:
	if amount <= 0:
		return {"ok": false, "reason": "Invalid contribution amount."}
	var proj_id := "proj_%d" % _next_project_id
	_next_project_id += 1

	var p := {
		"id": proj_id,
		"type": "sponsor_replacements",
		"house_id": house_id,
		"target_id": target_id,
		"target_kind": target_kind,
		"expected_owner": expected_owner,
		"escrow_total": amount,
		"escrow_remaining": amount,
		"escrow_spent": 0,
		"escrow_refunded": 0,
		"recruits_funded": 0,
		"created_hour": cur_hour,
		"expiry_hour": cur_hour + Relationships.ESCROW_EXPIRY_HOURS,
		"status": "active"
	}
	projects[proj_id] = p
	return {"ok": true, "project": p}


# Optional conversations never call apply_choice or advance the main quest.
func personal_record(person_id: String) -> Dictionary:
	return personal_conversations.get(person_id, {
		"schema_version": 1, "completed": {}, "cosmetic_choices": {},
		"bonus_claims": {}, "in_progress": {}
	}).duplicate(true)


func _personal_candidate(person_id: String) -> String:
	for candidate_id in relationships:
		if relationships[candidate_id].get("person_id", "") == person_id:
			return candidate_id
	return ""


func personal_scene_access(person_id: String, scene_id: String, context: Dictionary) -> Dictionary:
	var candidate_id := _personal_candidate(person_id)
	if not PersonalConversations.ids_for(candidate_id).has(scene_id):
		return {"ok": false, "reason": "This story is not available."}
	var record := personal_record(person_id)
	if record["completed"].has(scene_id):
		return {"ok": true, "replay": true, "reason": "Memory · no rewards or changes."}
	var person: Dictionary = people[person_id]
	var rel: Dictionary = relationships[candidate_id]
	if int(quests.get("quest_" + candidate_id, {}).get("chapter", 1)) < 2:
		return {"ok": false, "reason": "Introduce yourself in an audience first."}
	if rel.get("strained", false):
		return {"ok": false, "reason": "Resolve the broken promise before a new visit."}
	if not ["normal", "relocated"].has(person.get("status", "")):
		return {"ok": false, "reason": "They are currently unavailable for a visit."}
	if String(context.get("settlement_id", "")).is_empty() or context.get("settlement_id") != person.get("residence"):
		return {"ok": false, "reason": "Visit their current residence to spend time together."}
	var scene: Dictionary = PersonalConversations.SCENES[scene_id]
	var prerequisites: Array = scene.get("requires_any", [])
	var unlocked := prerequisites.is_empty()
	for prerequisite in prerequisites:
		if record["completed"].has(prerequisite):
			unlocked = true
	if not unlocked:
		return {"ok": false, "reason": "First share: " + " or ".join(prerequisites.map(func(id): return PersonalConversations.SCENES[id]["title"]))}
	if scene.get("coda", false) and not [Relationships.COMMITTED, Relationships.ENGAGED, Relationships.MARRIED, Relationships.FRIENDSHIP].has(rel.get("status")):
		return {"ok": false, "reason": "First choose commitment or a lasting friendship in the main story."}
	return {"ok": true, "replay": false, "reason": "Optional visit · no time or resources spent."}


func available_personal_conversations(person_id: String, context: Dictionary) -> Array:
	var result: Array = []
	for scene_id in PersonalConversations.ids_for(_personal_candidate(person_id)):
		var item := personal_scene_access(person_id, scene_id, context)
		item["scene_id"] = scene_id
		result.append(item)
	return result


## Only this command mutates personal records. Replays are read-only UI sessions.
func personal_action(person_id: String, scene_id: String, action: String, context: Dictionary, choice: int = -1) -> Dictionary:
	var access := personal_scene_access(person_id, scene_id, context)
	if not access.get("ok", false):
		return access
	if access.get("replay", false):
		return {"ok": false, "reason": "This memory is already complete. Replay cannot change it."}
	var record := personal_record(person_id)
	var scene: Dictionary = PersonalConversations.SCENES[scene_id]
	var progress: Dictionary = record["in_progress"].get(scene_id, {})
	var rel: Dictionary = relationships[_personal_candidate(person_id)]
	if action == "begin":
		if progress.get("scene_id", "") != scene_id or int(progress.get("content_version", 0)) != PersonalConversations.VERSION:
			progress = {"scene_id": scene_id, "node": 0, "choice": -1,
				"content_version": PersonalConversations.VERSION,
				"context": {"completed": record["completed"].keys(), "choices": record["cosmetic_choices"].duplicate(true), "status": rel.get("status", Relationships.UNKNOWN),
					"romantic": bool(rel.get("romantic_intent", false)) and bool(context.get("invitations_enabled", true)) and rel.get("status") != Relationships.ENDED}}
		# A resumed visit reflects the current relationship; completed memories retain their old context.
		progress["context"]["status"] = rel.get("status", Relationships.UNKNOWN)
		progress["context"]["romantic"] = bool(rel.get("romantic_intent", false)) and bool(context.get("invitations_enabled", true)) and rel.get("status") != Relationships.ENDED
		PersonalConversations.normalize_reader(scene_id, progress)
		record["in_progress"][scene_id] = progress
	elif action == "advance" or action == "previous":
		if progress.get("scene_id", "") != scene_id or int(progress.get("content_version", 0)) != PersonalConversations.VERSION:
			return {"ok": false, "reason": "Reopen this visit before continuing."}
		PersonalConversations.normalize_reader(scene_id, progress)
		var sequence := PersonalConversations.beats(scene_id, int(progress["node"]), int(progress["choice"]), progress["context"])
		var next_beat := int(progress["beat"]) + (1 if action == "advance" else -1)
		if next_beat < 0 or next_beat >= sequence.size():
			return {"ok": false, "reason": "You have reached the end of this passage."}
		progress["beat"] = next_beat
		progress["furthest_beat"] = maxi(int(progress["furthest_beat"]), next_beat)
	elif action == "choose":
		if progress.get("scene_id", "") != scene_id or int(progress.get("node", -1)) != 0 or int(progress.get("content_version", 0)) != PersonalConversations.VERSION:
			return {"ok": false, "reason": "Reopen this visit before choosing a response."}
		if choice < 0 or choice >= scene["choices"].size():
			return {"ok": false, "reason": "Choose one of the offered responses."}
		progress["choice"] = choice
		progress["node"] = 1
		progress["beat"] = 0
		progress["furthest_beat"] = 0
		PersonalConversations.normalize_reader(scene_id, progress)
	elif action == "finish" or action == "summary":
		if progress.get("scene_id", "") != scene_id or int(progress.get("content_version", 0)) != PersonalConversations.VERSION:
			return {"ok": false, "reason": "Reopen this visit before completing it."}
		if action == "finish" and int(progress.get("node", -1)) != 1:
			return {"ok": false, "reason": "Choose a response or read the summary first."}
		var delta := 0
		if record["bonus_claims"].size() < Relationships.PERSONAL_CONVERSATION_CAP:
			var old_trust := int(rel.get("trust", 0))
			rel["trust"] = mini(Relationships.TRUST_MAX, old_trust + Relationships.PERSONAL_CONVERSATION_TRUST)
			delta = int(rel["trust"]) - old_trust
			record["bonus_claims"][scene_id] = delta # A claim at 100 still consumes a slot.
		record["completed"][scene_id] = {"content_version": PersonalConversations.VERSION, "context": progress["context"].duplicate(true), "summary": action == "summary"}
		record["cosmetic_choices"][scene_id] = -1 if action == "summary" else int(progress["choice"])
		record["in_progress"].erase(scene_id)
		personal_conversations[person_id] = record
		add_memory(person_id, scene["memory"])
		return {"ok": true, "trust_change": delta, "completed": true}
	else:
		return {"ok": false, "reason": "Unknown conversation action."}
	personal_conversations[person_id] = record
	return {"ok": true, "progress": progress.duplicate(true)}
