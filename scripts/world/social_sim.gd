## Pure-logic simulation of social relationships, court residents, courtships,
## house pacts, support escrows, and letters. Owned and serialized by WorldSim.
## No nodes, no drawing, deterministic.
extends RefCounted

const PersonalConversations = preload("res://scripts/data/personal_conversations.gd")
const Gatherings = preload("res://scripts/data/gatherings.gd")
const Relationships = preload("res://scripts/data/relationships.gd")
const RomanceStories = preload("res://scripts/data/romance_stories.gd")
const WorldData = preload("res://scripts/world/world_data.gd")
const Cultures = preload("res://scripts/data/cultures.gd")
const Economy = preload("res://scripts/data/economy.gd")
const Letters = preload("res://scripts/data/letters.gd")

var personal_conversations: Dictionary = {}
var people: Dictionary = {}
var houses: Dictionary = {}
var relationships: Dictionary = {}
var quests: Dictionary = {}
var pacts: Dictionary = {}
var projects: Dictionary = {}
var letters: Array = []
## Letters written but not yet come: each arrives at its created_hour.
var pending_letters: Array = []
var limits: Dictionary = {
	"current_partner_id": "",
	"last_grant_hour": -999.0,
	"last_military_help_hour": -999.0,
	"active_military_assignment_id": ""
}
var pending_settlements: Array = []
## The public wedding, from the proposal to the day (see plan_wedding): {} when none.
var wedding: Dictionary = {}

var _next_project_id := 1
var _next_letter_id := 1
## The world's hour as of the last step, for dating memories.
var _hour := 0.0


func setup(seed_val: int, lords_list: Array, settlements: Dictionary) -> void:
	personal_conversations.clear()
	people.clear()
	houses.clear()
	relationships.clear()
	quests.clear()
	pacts.clear()
	projects.clear()
	letters.clear()
	pending_letters.clear()
	pending_settlements.clear()
	wedding.clear()
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
		"pending_letters": pending_letters,
		"limits": limits,
		"pending_settlements": pending_settlements,
		"wedding": wedding,
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
	pending_letters = data.get("pending_letters", []).duplicate(true)
	limits = data.get("limits", {
		"current_partner_id": "",
		"last_grant_hour": -999.0,
		"last_military_help_hour": -999.0,
		"active_military_assignment_id": ""
	}).duplicate(true)
	pending_settlements = data.get("pending_settlements", []).duplicate(true)
	wedding = data.get("wedding", {}).duplicate(true)
	# Older saves: a ceremony on a six-hour timer waits, ready, at its place instead.
	var old_ceremony: Dictionary = data.get("scheduled_ceremony", {})
	if wedding.is_empty() and bool(old_ceremony.get("active", false)) and not bool(old_ceremony.get("completed", false)):
		var oc := String(old_ceremony.get("candidate_id", ""))
		wedding = {"state": "ready", "candidate_id": oc, "person_id": String(old_ceremony.get("person_id", "")),
			"place": String(old_ceremony.get("settlement_id", "")), "chosen_hour": float(old_ceremony.get("scheduled_at_hour", 0.0)),
			"ready_hour": float(old_ceremony.get("scheduled_at_hour", 0.0)), "reserved_silver": int(old_ceremony.get("cost_silver", 0)),
			"reserved_food": int(old_ceremony.get("cost_food", 0)), "postponed_reason": ""}
	for k in ["reserved_silver", "reserved_food", "day"]:
		if wedding.has(k):
			wedding[k] = int(wedding[k])
	_next_project_id = int(data.get("next_project_id", 1))
	_next_letter_id = int(data.get("next_letter_id", 1))
	# JSON reads all numbers as floats; restore integral identity/progression fields.
	for person in people.values():
		for key in ["age", "lord_id"]:
			if person.has(key): person[key] = int(person[key])
		for m in person.get("memory_log", []):
			m["day"] = int(m.get("day", 1))
			if m.has("chapter"):
				m["chapter"] = int(m["chapter"])
	for house in houses.values():
		if house.has("standing"): house["standing"] = int(house["standing"])
	for relationship in relationships.values():
		if relationship.has("trust"): relationship["trust"] = int(relationship["trust"])
	for quest in quests.values():
		if quest.has("chapter"): quest["chapter"] = int(quest["chapter"])



# ---------------------------------------------------------------- ticking & updates

func step(dt: float, world_ref: RefCounted) -> void:
	var cur_hour: float = world_ref.hour
	_hour = cur_hour
	_deliver_letters(cur_hour)

	# 1. A planned wedding gets ready, or is put off when its place can't host it.
	_step_wedding(cur_hour, world_ref)

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
		var old_seat: String = String(person.get("residence", ""))
		person["residence"] = new_seat
		person["status"] = "relocated"
		add_memory(person["id"], "Relocated to %s following the loss of %s." % [
			Letters.place_name(new_seat), Letters.place_name(old_seat)], {"kind": "move", "place": new_seat})
		add_letter(person["id"], "relocation", "", world_ref.hour, new_seat, {"old": Letters.place_name(old_seat)})
	else:
		person["status"] = "displaced"
		add_memory(person["id"], "Displaced from %s." % person["residence"], {"kind": "move"})


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


## What the next memory is about (set around a chapter decision), merged into it.
var _memory_info := {}


## Everything remembered with `person_id`, oldest first, each {id, day, kind, text, place,
## and what it points back to}. Memories from before kinds were kept read as notes.
func memory_book(person_id: String) -> Array:
	var person: Dictionary = people.get(person_id, {})
	var out := []
	var log: Array = person.get("memory_log", [])
	if log.is_empty():
		for i in (person.get("memories", []) as Array).size():
			out.append({"id": "old_%d" % i, "day": 0, "kind": "note", "text": String(person["memories"][i]), "place": ""})
		return out
	for i in log.size():
		var e: Dictionary = log[i].duplicate()
		if not e.has("kind"):
			e["kind"] = "note"
		if not e.has("id"):
			e["id"] = "log_%d" % i
		out.append(e)
	return out


## Remember `text` with `person_id`. `info` says what it was: {kind (visit, decision, letter,
## ceremony, move, note), scene_id, chapter, choice, letter_id, place}, so the memory book can
## open it again.
func add_memory(person_id: String, text: String, info: Dictionary = {}) -> void:
	if not people.has(person_id):
		return
	var mems: Array = people[person_id].get("memories", [])
	mems.append(text)
	if mems.size() > 30:
		mems.pop_front()
	people[person_id]["memories"] = mems
	# The same memory with the day it happened, for the person's page.
	var log: Array = people[person_id].get("memory_log", [])
	var entry := {"text": text, "day": int(_hour / 24.0) + 1, "kind": "note", "id": "m%d_%d" % [int(_hour * 10.0), log.size()]}
	entry.merge(_memory_info, true)
	entry.merge(info, true)
	if not entry.has("place"):
		entry["place"] = String(people[person_id].get("residence", ""))
	log.append(entry)
	if log.size() > 30:
		log.pop_front()
	people[person_id]["memory_log"] = log

	# Also record on relationship if it's a candidate
	for cand_id in relationships:
		if relationships[cand_id]["person_id"] == person_id:
			var r_mems: Array = relationships[cand_id].get("memories", [])
			r_mems.append(text)
			if r_mems.size() > 30:
				r_mems.pop_front()
			relationships[cand_id]["memories"] = r_mems


## A letter from `sender_id`, written now (its words are kept with it). `extra` fills the
## letter's blanks beyond the place it's written from (e.g. {"old": the seat they left}).
## A letter that should come later is given `deliver_hour`: it is written now, dated then,
## and arrives (is announced, counted, answerable) when the world reaches that hour.
func add_letter(sender_id: String, template_key: String, quest_id: String, current_hour: float, destination: String, extra: Dictionary = {}, deliver_hour: float = -1.0) -> Dictionary:
	_hour = maxf(_hour, current_hour)
	var later := deliver_hour > current_hour
	var l := {
		"id": "let_%d" % _next_letter_id,
		"sender_id": sender_id,
		"template_key": template_key,
		"quest_id": quest_id,
		"created_hour": deliver_hour if later else current_hour,
		"read": false,
		"acknowledged": false,
		"announced": false,
		"destination": destination,
		"extra": extra.duplicate(),
	}
	l["letter"] = _render_letter(l)
	_next_letter_id += 1
	if later:
		pending_letters.append(l)
	else:
		letters.append(l)
	return l


## Letters whose hour has come arrive.
func _deliver_letters(cur_hour: float) -> void:
	var due := pending_letters.filter(func(l): return float(l.get("created_hour", 0.0)) <= cur_hour)
	for l in due:
		pending_letters.erase(l)
		letters.append(l)


## Whether the candidate's current chapter can be played now: {ok, reason}. A chapter
## opens a day after the last decision, with her letter; the last one waits until she
## trusts you enough to be asked anything.
func chapter_open(candidate_id: String, hour: float) -> Dictionary:
	var q: Dictionary = quests.get("quest_%s" % candidate_id, {})
	var opens := float(q.get("opens_hour", -1.0))
	if hour < opens:
		var left := opens - hour
		return {"ok": false, "reason": "tomorrow; she'll write" if left <= 24.0 else "in %d days; she'll write" % ceili(left / 24.0)}
	if int(q.get("chapter", 1)) == 5 and int(relationships.get(candidate_id, {}).get("trust", 0)) < Relationships.TRUST_CH5_OPEN:
		return {"ok": false, "reason": "when %s trusts you more" % String(get_candidate_person(candidate_id).get("name", "she"))}
	return {"ok": true, "reason": ""}


## The story moves to chapter `n`: it opens a day on, and her letter comes with it.
func _open_chapter(q: Dictionary, person: Dictionary, n: int, hour: float) -> void:
	q["chapter"] = n
	q["opens_hour"] = hour + Relationships.CHAPTER_GAP_HOURS
	add_letter(person["id"], "ch%d_invitation" % n, q["id"], hour, person["residence"], {}, float(q["opens_hour"]))


## Whether you and the candidate are courting (or further along) rather than friends.
func is_courting(candidate_id: String) -> bool:
	var rel: Dictionary = relationships.get(candidate_id, {})
	if bool(rel.get("romantic_intent", false)):
		return true
	return [Relationships.COURTING, Relationships.COMMITTED, Relationships.ENGAGED, Relationships.MARRIED].has(String(rel.get("status", "")))


func _render_letter(l: Dictionary) -> Dictionary:
	var sender: Dictionary = people.get(String(l.get("sender_id", "")), {})
	var cand := _personal_candidate(String(l.get("sender_id", "")))
	var ctx: Dictionary = l.get("extra", {}).duplicate()
	ctx["place"] = Letters.place_name(String(l.get("destination", "")))
	ctx["hour"] = float(l.get("created_hour", 0.0))
	ctx["sender"] = String(sender.get("name", "A friend"))
	if not ctx.has("old"):
		ctx["old"] = "the old seat"
	return Letters.render(String(l.get("template_key", "")), cand, is_courting(cand), ctx)


func get_letter(letter_id: String) -> Dictionary:
	for l in letters:
		if l["id"] == letter_id:
			return l
	return {}


## The letter's words. Letters from saves before they had words get them now, once.
func letter_view(l: Dictionary) -> Dictionary:
	if not l.has("letter") or (l["letter"] as Dictionary).is_empty():
		l["letter"] = _render_letter(l)
	return l["letter"]


## Letters that came while you weren't looking: shown once as a banner on the map.
func take_unannounced() -> Array:
	var out := []
	for l in letters:
		if not bool(l.get("announced", true)) and not bool(l.get("read", false)):
			l["announced"] = true
			out.append(l)
	return out


## The candidate behind a letter, or "".
func letter_candidate(l: Dictionary) -> String:
	return _personal_candidate(String(l.get("sender_id", "")))


## Your reply, as it would read if sent: {salute, body, close, sign, ...}, or {}.
func reply_preview(letter_id: String, reply_id: String, from_place: String = "") -> Dictionary:
	var l := get_letter(letter_id)
	if l.is_empty():
		return {}
	var cand := letter_candidate(l)
	var sender: Dictionary = people.get(String(l.get("sender_id", "")), {})
	var ctx: Dictionary = l.get("extra", {}).duplicate()
	ctx["place"] = Letters.place_name(String(l.get("destination", "")))
	ctx["name"] = String(sender.get("name", ""))
	ctx["from"] = Letters.place_name(from_place) if from_place != "" else ""
	ctx["hour"] = _hour
	if not ctx.has("old"):
		ctx["old"] = "the old seat"
	return Letters.render_reply(String(l.get("template_key", "")), reply_id, is_courting(cand), ctx)


## Send a reply to a letter (one per letter). It warms them a little, by the reply's trust.
func reply_letter(letter_id: String, reply_id: String, from_place: String = "") -> Dictionary:
	var l := get_letter(letter_id)
	if l.is_empty():
		return {"ok": false, "reason": "No such letter."}
	if l.has("reply"):
		return {"ok": false, "reason": "You've already answered this letter."}
	var r := Letters.reply(String(l.get("template_key", "")), reply_id)
	if r.is_empty():
		return {"ok": false, "reason": "That isn't an answer to this letter."}
	var sent := reply_preview(letter_id, reply_id, from_place)
	l["read"] = true
	l["reply"] = {"id": reply_id, "label": r["label"], "hour": _hour, "letter": sent}
	var cand := letter_candidate(l)
	var gain := int(r.get("trust", 0))
	if cand != "" and relationships.has(cand):
		var rel: Dictionary = relationships[cand]
		rel["trust"] = clampi(int(rel.get("trust", 0)) + gain, Relationships.TRUST_MIN, Relationships.TRUST_MAX)
	var sender: Dictionary = people.get(String(l.get("sender_id", "")), {})
	if not sender.is_empty():
		add_memory(String(sender["id"]), "You wrote back to %s: \"%s.\"" % [sender.get("name", ""), r["label"]], {"kind": "letter", "letter_id": String(letter_id)})
	return {"ok": true, "trust_change": gain}


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
	var candidate_name := String(person.get("name", "this person"))
	var reward_prefix := candidate_id

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

	if target_ch == 5 and wedding_active(candidate_id):
		out["ok"] = false
		out["reason"] = "Your wedding is already being planned."
		return out
	if target_ch > 0 and target_ch != current_ch:
		if target_ch < current_ch:
			out["ok"] = false
			out["reason"] = "Chapter %d is already completed." % target_ch
			return out
		elif target_ch > current_ch:
			out["ok"] = false
			out["reason"] = "Chapter %d prerequisites not yet reached." % target_ch
			return out
	if target_ch > 1:
		var open := chapter_open(candidate_id, float(context.get("current_hour", _hour)))
		if not bool(open["ok"]):
			out["ok"] = false
			out["reason"] = "Not yet: %s." % String(open["reason"])
			return out

	match target_ch:
		1:
			if choice_id in ["know_better", "offer_help", "another_time"]:
				if not q.get("consumed_rewards", []).has("%s_ch1_intro" % reward_prefix):
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
			if not q.get("consumed_rewards", []).has("%s_ch2_personal" % reward_prefix):
				out["trust_change"] = Relationships.TRUST_PERSONAL_REWARD
		3:
			var rkey := "%s_ch3_shared" % reward_prefix
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
					if not q.get("consumed_rewards", []).has("%s_ch4_negotiate" % reward_prefix):
						out["trust_change"] = Relationships.TRUST_CH4_HONEST
						out["standing_change"] = 10
				"support_edda":
					if not q.get("consumed_rewards", []).has("%s_ch4_support" % reward_prefix):
						out["trust_change"] = Relationships.TRUST_CH4_HONEST
						out["standing_change"] = -10
				"break_promise":
					out["trust_change"] = Relationships.TRUST_CH4_BREACH
					out["standing_change"] = 10
					out["requires_confirmation"] = true
					out["confirmation_text"] = "Breaking your promise to %s will damage her trust and strain your relationship." % candidate_name
				"repair_promise":
					if not q.get("consumed_rewards", []).has("%s_ch4_repaired" % reward_prefix):
						out["trust_change"] = Relationships.TRUST_CH4_REPAIR
					out["cost_silver"] = 100
					if int(context.get("player_silver", 0)) < 100:
						out["ok"] = false
						out["reason"] = "Requires 100 silver to provide restitution."
		5:
			# In chapter 5, check trust + ch5 final bonus
			var sim_trust: int = int(rel.get("trust", 0))
			if not q.get("consumed_rewards", []).has("%s_ch5_final" % reward_prefix):
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
						out["confirmation_text"] = "Ask %s to marry you before her house? 100 silver and 100 rations are set aside for the wedding, and come back if it's called off." % candidate_name
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
						out["confirmation_text"] = "Exchange private vows? Bypassing house approval costs 10 standing with %s." % String(house.get("name", "the household"))
				"friendship":
					var check := Relationships.can_swear_friendship(sim_rel, house)
					if not check["ok"]:
						out["ok"] = false
						out["reason"] = check["reason"]
					else:
						out["new_status"] = Relationships.FRIENDSHIP
						out["standing_change"] = Relationships.STANDING_PACT_BONUS
						out["requires_confirmation"] = true
						out["confirmation_text"] = "Swear mutual cooperation and friendship with %s and her house?" % candidate_name
				"remain_close":
					out["new_status"] = Relationships.COMMITTED
				"part_respectfully":
					out["new_status"] = Relationships.ENDED
					out["requires_confirmation"] = true
					out["confirmation_text"] = "Part ways with %s? This respectfully concludes courtship while preserving earned standing." % candidate_name

	return out


## The line the memory book keeps for a story choice: the authored one, else `fallback`.
func _choice_memory(candidate_id: String, choice_id: String, fallback: String) -> String:
	var m := String(RomanceStories.choice_data(candidate_id, choice_id).get("memory", ""))
	return m if m != "" else fallback


## Applies a validated choice, updating state and consuming rewards once.
func apply_choice(candidate_id: String, choice_id: String, context: Dictionary) -> Dictionary:
	_hour = float(context.get("current_hour", _hour))
	var prev := preview_choice(candidate_id, choice_id, context)
	if not prev["ok"]:
		return prev

	var rel: Dictionary = relationships[candidate_id]
	var q: Dictionary = quests["quest_%s" % candidate_id]
	var person: Dictionary = get_candidate_person(candidate_id)
	var house: Dictionary = houses[person["house_id"]]
	var target_ch: int = chapter_for_choice(choice_id)
	_memory_info = {"kind": "decision", "chapter": target_ch, "choice": choice_id, "candidate": candidate_id}
	var reward_claimed := false
	var candidate_name := String(person.get("name", "this person"))
	var reward_prefix := candidate_id

	# Apply trust & standing changes
	rel["trust"] = clampi(int(rel["trust"]) + int(prev["trust_change"]), Relationships.TRUST_MIN, Relationships.TRUST_MAX)
	house["standing"] = clampi(int(house["standing"]) + int(prev["standing_change"]), Relationships.STANDING_MIN, Relationships.STANDING_MAX)

	match target_ch:
		1:
			if choice_id in ["know_better", "offer_help", "another_time"]:
				var rkey := "%s_ch1_intro" % reward_prefix
				if not q["consumed_rewards"].has(rkey):
					q["consumed_rewards"].append(rkey)
					reward_claimed = true
				if choice_id == "know_better":
					rel["romantic_intent"] = true
					rel["intent_chosen"] = true
					rel["status"] = Relationships.COURTING
					limits["current_partner_id"] = candidate_id
					add_memory(person["id"], _choice_memory(candidate_id, choice_id, "Agreed to court %s." % candidate_name))
				elif choice_id == "offer_help":
					rel["romantic_intent"] = false
					rel["intent_chosen"] = true
					rel["status"] = Relationships.ACQUAINTED
					add_memory(person["id"], _choice_memory(candidate_id, choice_id, "Offered friendship and service to %s." % candidate_name))
				_open_chapter(q, person, 2, float(context.get("current_hour", _hour)))
		2:
			var rkey := "%s_ch2_personal" % reward_prefix
			if not q["consumed_rewards"].has(rkey):
				q["consumed_rewards"].append(rkey)
				reward_claimed = true
			_open_chapter(q, person, 3, float(context.get("current_hour", _hour)))
			add_memory(person["id"], _choice_memory(candidate_id, choice_id, "Shared personal stories with %s." % candidate_name))
		3:
			var rkey := "%s_ch3_shared" % reward_prefix
			if not q["consumed_rewards"].has(rkey):
				q["consumed_rewards"].append(rkey)
				reward_claimed = true
			if choice_id == "fund_muster":
				var spent: int = int(prev["cost_silver"])
				if spent > 0:
					sponsor_replacements(house["id"], person["residence"], "settlement", spent, float(context.get("current_hour", 0.0)), house.get("realm", "vardmark"))
			_open_chapter(q, person, 4, float(context.get("current_hour", _hour)))
			add_memory(person["id"], _choice_memory(candidate_id, choice_id, "Completed a shared service with %s." % candidate_name))
		4:
			match choice_id:
				"negotiate":
					var rkey := "%s_ch4_negotiate" % reward_prefix
					if not q["consumed_rewards"].has(rkey):
						q["consumed_rewards"].append(rkey)
						reward_claimed = true
					_open_chapter(q, person, 5, float(context.get("current_hour", _hour)))
					add_memory(person["id"], _choice_memory(candidate_id, choice_id, "Negotiated a balanced defense agreement for the valley."))
				"support_edda":
					var rkey := "%s_ch4_support" % reward_prefix
					if not q["consumed_rewards"].has(rkey):
						q["consumed_rewards"].append(rkey)
						reward_claimed = true
					_open_chapter(q, person, 5, float(context.get("current_hour", _hour)))
					add_memory(person["id"], _choice_memory(candidate_id, choice_id, "Stood firmly with %s before the council." % candidate_name))
				"break_promise":
					rel["strained"] = true
					rel["strained_reason"] = "broken_promise"
					q["strained_reason"] = "broken_promise"
					add_memory(person["id"], _choice_memory(candidate_id, choice_id, "Broke your word to %s before the house council." % candidate_name))
				"repair_promise":
					var rkey := "%s_ch4_repaired" % reward_prefix
					if not q["consumed_rewards"].has(rkey):
						q["consumed_rewards"].append(rkey)
						reward_claimed = true
					rel["strained"] = false
					rel["strained_reason"] = ""
					q["strained_reason"] = ""
					_open_chapter(q, person, 5, float(context.get("current_hour", _hour)))
					add_memory(person["id"], _choice_memory(candidate_id, choice_id, "Repaired your breach of word through honest restitution."))
		5:
			var rkey := "%s_ch5_final" % reward_prefix
			if not q["consumed_rewards"].has(rkey):
				q["consumed_rewards"].append(rkey)
				reward_claimed = true
			match choice_id:
				"marry_public":
					rel["status"] = Relationships.ENGAGED
					add_memory(person["id"], "%s said yes." % candidate_name)
					_memory_info = {}
					wedding = {"state": "planning", "candidate_id": candidate_id, "person_id": String(person["id"]), "place": "",
						"chosen_hour": float(context.get("current_hour", 0.0)), "ready_hour": 0.0,
						"reserved_silver": int(prev["cost_silver"]), "reserved_food": int(prev["cost_food"]), "postponed_reason": ""}
				"marry_private":
					rel["status"] = Relationships.MARRIED
					limits["current_partner_id"] = candidate_id
					_memory_info = {}
					add_memory(person["id"], "Exchanged private vows with %s, by one candle." % candidate_name,
						{"kind": "ceremony", "private": true, "scene_id": "wedding", "candidate": candidate_id,
						"place": String(person.get("residence", ""))})
				"friendship":
					rel["status"] = Relationships.FRIENDSHIP
					_form_pact(house["id"], "friendship", [person["id"], "player"], [person["residence"]], float(context.get("current_hour", 0.0)))
					add_memory(person["id"], "Swore mutual cooperation and friendship with %s." % candidate_name)
				"remain_close":
					rel["status"] = Relationships.COMMITTED
				"part_respectfully":
					separate(candidate_id)

	_memory_info = {}
	prev["reward_claimed"] = reward_claimed
	return prev


# ---------------------------------------------------------------- ceremonies & pacts

## Whether a public wedding is planned and not yet held (or called off).
func wedding_active(candidate_id: String = "") -> bool:
	if wedding.is_empty() or not (String(wedding.get("state", "")) in ["planning", "preparing", "ready", "postponed"]):
		return false
	return candidate_id == "" or String(wedding.get("candidate_id", "")) == candidate_id


## The first dusk at least a day after `hour`: when a wedding chosen then is ready.
static func wedding_ready_hour(hour: float) -> float:
	var day_start := floorf(hour / 24.0) * 24.0
	var dusk := day_start + Relationships.WEDDING_DUSK_HOUR
	while dusk < hour + Relationships.WEDDING_PREPARE_HOURS:
		dusk += 24.0
	return dusk


## Hold the wedding at `place`: it is ready at the first dusk a day from now.
func plan_wedding(place: String, cur_hour: float) -> Dictionary:
	if not wedding_active():
		return {"ok": false, "reason": "No wedding is planned."}
	if String(wedding["state"]) == "ready" and String(wedding.get("place", "")) == place:
		return {"ok": true, "wedding": wedding}
	wedding["place"] = place
	wedding["state"] = "preparing"
	wedding["chosen_hour"] = cur_hour
	wedding["ready_hour"] = wedding_ready_hour(cur_hour)
	wedding["postponed_reason"] = ""
	wedding["letter_sent"] = false
	return {"ok": true, "wedding": wedding}


func _step_wedding(cur_hour: float, world_ref: RefCounted) -> void:
	if not wedding_active():
		return
	var state := String(wedding["state"])
	var place := String(wedding.get("place", ""))
	if place == "" or state == "postponed":
		return
	var blocked: String = world_ref.wedding_blocked(place) if world_ref != null and world_ref.has_method("wedding_blocked") else ""
	if blocked != "":
		wedding["state"] = "postponed"
		wedding["postponed_reason"] = blocked
		add_letter(String(wedding["person_id"]), "wedding_postponed", "", cur_hour, String(get_person(String(wedding["person_id"])).get("residence", place)),
			{"old": WorldData.settlement(place)["name"] if WorldData.SETTLEMENTS.has(place) else place})
		return
	if state == "preparing" and cur_hour >= float(wedding.get("ready_hour", 0.0)):
		wedding["state"] = "ready"
		if not bool(wedding.get("letter_sent", false)):
			wedding["letter_sent"] = true
			add_letter(String(wedding["person_id"]), "wedding_ready", "", cur_hour, place)


## The wedding is held: married, remembered with your words, and (publicly) a pact.
## `info` = {vow, their_vow, toast, guests (names), seat (your seat, or "")}.
func finish_wedding(info: Dictionary, cur_hour: float) -> Dictionary:
	if not wedding_active():
		return {"ok": false, "reason": "No wedding is planned."}
	_hour = maxf(_hour, cur_hour)
	var cand_id := String(wedding["candidate_id"])
	var person: Dictionary = get_candidate_person(cand_id)
	var rel: Dictionary = relationships.get(cand_id, {})
	rel["status"] = Relationships.MARRIED
	limits["current_partner_id"] = cand_id
	var place := String(wedding["place"])
	var place_name := String(WorldData.settlement(place)["name"]) if WorldData.SETTLEMENTS.has(place) else place
	wedding["state"] = "done"
	wedding["day"] = int(cur_hour / 24.0) + 1
	for k in ["vow", "their_vow", "toast"]:
		wedding[k] = String(info.get(k, ""))
	add_memory(String(person["id"]), "Married %s at %s." % [person.get("name", ""), place_name],
		{"kind": "ceremony", "scene_id": "wedding", "place": place, "candidate": cand_id, "vow": String(info.get("vow", "")),
		"their_vow": String(info.get("their_vow", "")), "toast": String(info.get("toast", "")), "guests": info.get("guests", []).duplicate()})
	var sites := [String(person.get("residence", ""))]
	var seat := String(info.get("seat", ""))
	if seat != "" and not sites.has(seat):
		sites.append(seat)
	_form_pact(String(person.get("house_id", "")), "marriage", [person["id"], "player"], sites, cur_hour)
	return {"ok": true, "wedding": wedding}


## Call the wedding off: back to committed, and what was set aside comes back.
func cancel_wedding() -> Dictionary:
	if not wedding_active():
		return {"ok": false, "reason": "No wedding is planned."}
	var cand_id := String(wedding["candidate_id"])
	var refund := {"ok": true, "silver": int(wedding.get("reserved_silver", 0)), "food": int(wedding.get("reserved_food", 0))}
	var rel: Dictionary = relationships.get(cand_id, {})
	rel["status"] = Relationships.COMMITTED
	# The chapter's last talk can be had again; its trust was given once already.
	var q: Dictionary = quests.get("quest_%s" % cand_id, {})
	q["chapter"] = 5
	wedding["state"] = "cancelled"
	wedding["reserved_silver"] = 0
	wedding["reserved_food"] = 0
	add_memory(String(wedding["person_id"]), "Called off the wedding, for now.", {"kind": "note", "candidate": cand_id})
	return refund


## Keep your words with the most recent memory of `person_id` (the private vows).
## A dance with someone you court at a gathering: a little trust (kept apart from the
## visits' cap, up to a few dances over the courtship) and a memory. Returns the trust gained.
func dance_with(candidate_id: String, scene_id: String, memory_text: String, place: String, _cur_hour: float) -> int:
	var rel: Dictionary = relationships.get(candidate_id, {})
	if rel.is_empty():
		return 0
	var had := int(rel.get("dances", 0))
	var delta := 0
	if had < Gatherings.DANCE_TRUST_CAP:
		var old := int(rel.get("trust", 0))
		rel["trust"] = mini(Relationships.TRUST_MAX, old + Gatherings.DANCE_TRUST)
		delta = int(rel["trust"]) - old
	rel["dances"] = had + 1
	add_memory(String(rel.get("person_id", "")), memory_text, {"kind": "dance", "scene_id": scene_id, "place": place})
	return delta


func set_memory_words(person_id: String, words: Dictionary) -> void:
	var log: Array = people.get(person_id, {}).get("memory_log", [])
	if not log.is_empty():
		(log[log.size() - 1] as Dictionary).merge(words, true)


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
	add_memory(person["id"], "Parted ways respectfully.", {"kind": "decision", "choice": "part_respectfully"})
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
		"bonus_claims": {}, "in_progress": {}, "last_visit_day": -1
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
	# One new visit a day; one begun earlier can always be picked up.
	if not record["in_progress"].has(scene_id) and int(record.get("last_visit_day", -1)) == _day_of(context):
		return {"ok": false, "today": true, "reason": "It's late. Another day."}
	return {"ok": true, "replay": false, "reason": "Optional visit · no time or resources spent."}


func _day_of(context: Dictionary) -> int:
	return floori(float(context.get("current_hour", _hour)) / 24.0)


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
			record["last_visit_day"] = _day_of(context)
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
		add_memory(person_id, scene["memory"], {"kind": "visit", "scene_id": scene_id})
		return {"ok": true, "trust_change": delta, "completed": true}
	else:
		return {"ok": false, "reason": "Unknown conversation action."}
	personal_conversations[person_id] = record
	return {"ok": true, "progress": progress.duplicate(true)}
