## The campaign: the player's warband, carried between battles, and the world map it
## travels. Saved on the device after every change that matters.
##
## Every squad is led by a named captain. Captains who fall in battle roll for their
## fate: wounded ones sit out a couple of battles, dead ones go on the memorial and a
## veteran from the ranks steps up. Captains who fight side by side build bonds.
extends Node

const Troops = preload("res://scripts/data/troops.gd")
const Captains = preload("res://scripts/data/captains.gd")
const Cultures = preload("res://scripts/data/cultures.gd")
const WorldSim = preload("res://scripts/world/world_sim.gd")
const WorldData = preload("res://scripts/world/world_data.gd")
const Economy = preload("res://scripts/data/economy.gd")
const AutoResolve = preload("res://scripts/battle/auto_resolve.gd")
const BattleSite = preload("res://scripts/battle/battle_site.gd")
const MapTerrain = preload("res://scripts/world/map_terrain.gd")
const Units = preload("res://scripts/data/units.gd")
const Commander = preload("res://scripts/battle/commander_ai.gd")
const Lords = preload("res://scripts/data/lords.gd")
const Achievements = preload("res://scripts/data/achievements.gd")
const MarshalArmies = preload("res://scripts/world/marshal_armies.gd")
const LordVoice = preload("res://scripts/data/lord_voice.gd")
const Heroes = preload("res://scripts/data/heroes.gd")
const Jobs = preload("res://scripts/data/jobs.gd")
const Fiefs = preload("res://scripts/data/fiefs.gd")
const SaveSlots = preload("res://scripts/save_slots.gd")
const LordTalk = preload("res://scripts/world/lord_talk.gd")
const Relationships = preload("res://scripts/data/relationships.gd")
const Gatherings = preload("res://scripts/data/gatherings.gd")
const CrownCourt = preload("res://scripts/world/crown_court.gd")
const Politics = preload("res://scripts/data/politics.gd")
const SAVE_PATH := "user://campaign.json"
const SAVE_VERSION := 6

const CONTRACT_MIN_RENOWN := 10
const CONTRACT_DAYS := 30
const CONTRACT_BASE_PAY := 25
const CONTRACT_LORD_BONUS := 100

## Relations with realms (-100 to 100): "vardmark", "kharzan", "ryumon"
var realm_relations: Dictionary = {"vardmark": 0, "kharzan": 0, "ryumon": 0}
## Relations with individual lords (-100 to 100): lord_id -> int
var lord_relations: Dictionary = {}
## Active mercenary contract: {realm, daily_pay, days_left, bonus_per_lord}
var contract: Dictionary = {}

## Each squad: {id, type, men, xp, level, culture, name, captain}. Kills earn xp; xp
## lets a squad be trained to the next level in a town. A squad's culture is where it
## was raised, which names its men and its captain. A squad that loses every man is
## removed, unless its captain lived to raise it again.
var army: Array = []
## The dead, newest last: {name, company, type, battles, kills, battle, words, bonds}.
var fallen: Array = []
var battles := 0
var wins := 0
var last_result := {}
## Saved per campaign: pending help survives a quit until explicitly acknowledged.
var bond_intro_seen := false
var bond_intro_pair := ""
var bond_intro_ids: Array = []
## Saved bond milestones waiting to be shown, and factual shared history for camp scenes.
var bond_events: Array = []
var bond_records: Dictionary = {}
## Coin, rations (one per man per day) and renown, which lets you lead more squads.
var silver := 0
var food := 0
var renown := 0
## The last day whose wages and food have been settled.
var _paid_day := 0
## The player's culture: their captains' names and where they start.
var culture := Cultures.VARDISH
## The world map, or null before a campaign has started.
var world = null:
	set(v):
		world = v
		if world != null:
			world.game_state = self
## The fight the map has set up for the battle screen: {enemy, culture, temperament,
## name}. Empty when the battle screen should make up its own enemy.
var pending_battle := {}
## What the map should tell the player when they get back from a battle, or "".
var map_notice := ""
## What the waiting message is about, as its card's title: "After the battle" when a fight
## was settled, a crown won or lost; empty for everything else, which the map titles by
## where you are.
var map_notice_title := ""
## Things of one kind done in a row (captives released, lords sworn), kept apart from the
## running notice so the map can show them together, a heading, who, and the totals once,
## rather than a sentence each. Each is {kind, name, ...}: "released" carries the realm,
## "sworn" the seat they'll hold ("" for none).
var map_notice_items: Array = []
## Unread desertion warning survives saving until the player acknowledges it.
var desertion_warning := ""
## Battles the autoplay smoke test has fought this run.
var autoplay_battles := 0
## Casual mode: captains suffer severe wounds instead of permanent death.
var casual_mode := false
## Ironman: the autosave is the only save. No saves of your own, no going back.
var ironman := false
## Unique heroes recruited by the player.
var hired_heroes: Array = []
## Active small settlement jobs / contracts accepted by the company.
var active_jobs: Array = []
## Completed jobs log.
var completed_jobs: Array = []
## Player-held fief and estate (Feature 12).
var player_fief: Dictionary = {}
## The journal: the one commitment pinned to the map card, and how recent ones ended.
var pinned_commitment := ""
var ended_commitments: Array = []
const ENDED_KEEP := 8
## Camp moments the player has already seen (see camp_moments.gd).
var camp_seen: Array = []
## Company deeds (achievements.gd): those earned {id: {day}}, running counts for the ones
## that count events, and the name the company chose to carry ("" for none).
var deeds: Dictionary = {}
var deed_counts: Dictionary = {}
var company_title := ""
## Your crown: the name and colour you give it, whether it has won the Glass Sea, and how
## many days it has held nothing (it falls after CROWN_FALL_DAYS).
var crown_name := ""
var crown_color := 0
var crown_won := false
var crown_empty_days := 0
## What you've done at each gathering: its id (as text) → {spoke: [lord ids], toast, gift,
## gossip_nights: [n], danced_nights: [n], marks: {lord id (text): hint}}.
var gathering_log: Dictionary = {}
## Your own gathering, kept a while after it ends for its afterglow: {id, place,
## ends_hour, guests: [lord ids]}.
var hosted: Dictionary = {}
## When your crown may hold another gathering.
var host_ready_at := 0.0
## Your banners called to a muster: {place, called_hour, lords: [ids], refused: [ids],
## fed_day, hungry_days}, or {} (see CrownCourt).
var muster: Dictionary = {}
## The host that rode from your war council: {aim, target, anchors, villages, led ("you"
## or "lord"), army_id, lords: [ids], until, paid, place}, or {}.
var banners: Dictionary = {}
## Gatherings you've already been told about.
var invites_seen: Array = []
## Progress toward healing wounded soldiers (12h road / 6h rest per man).
var _heal_clock := 0.0
## Set false in tests so nothing touches the save file.
var persist := true
var rng := RandomNumberGenerator.new()
var _next_id := 1
var _next_captain := 1


func _ready() -> void:
	rng.randomize()
	if not load_game():
		new_warband()


## Start over: a fresh warband of `culture_id` standing at its capital, in a new world.
func new_campaign(culture_id: String) -> void:
	culture = culture_id if Cultures.has(culture_id) else Cultures.VARDISH
	world = null
	pending_battle = {}
	gathering_log = {}
	hosted = {}
	host_ready_at = 0.0
	muster = {}
	banners = {}
	invites_seen = []
	new_warband()
	world = WorldSim.new()
	world.setup(rng.randi(), culture)
	# The last campaign's saves go with it.
	if persist or SaveSlots.dir != SaveSlots.DEFAULT_DIR:
		SaveSlots.clear()
	save_game()


func has_campaign() -> bool:
	return world != null


func new_warband() -> void:
	army = []
	fallen = []
	battles = 0
	wins = 0
	last_result = {}
	bond_intro_seen = false
	bond_intro_pair = ""
	bond_intro_ids = []
	bond_events = []
	bond_records = {}
	realm_relations = {"vardmark": 0, "kharzan": 0, "ryumon": 0}
	lord_relations = {}
	contract = {}
	map_notice = ""
	map_notice_title = ""
	map_notice_items = []
	desertion_warning = ""
	hired_heroes = []
	active_jobs = []
	completed_jobs = []
	player_fief = {}
	pinned_commitment = ""
	ended_commitments = []
	camp_seen = []
	deeds = {}
	deed_counts = {}
	company_title = ""
	crown_name = ""
	crown_color = 0
	crown_won = false
	crown_empty_days = 0
	WorldData.set_crown("", 0)
	_heal_clock = 0.0
	casual_mode = false
	ironman = false
	_next_id = 1
	_next_captain = 1
	renown = 0
	_paid_day = 0
	for type in [Troops.INFANTRY, Troops.INFANTRY, Troops.SPEARMEN, Troops.ARCHERS, Troops.CAVALRY]:
		army.append(_new_squad(type))
	silver = Economy.START_SILVER
	food = Economy.START_FOOD_DAYS * total_men()
	save_game()


## A full squad of fresh recruits raised among `squad_culture` (yours by default), with
## a captain of that culture.
func _new_squad(type: String, squad_culture: String = "") -> Dictionary:
	var c := squad_culture if squad_culture != "" else culture
	var captain := _new_captain(type, c)
	var unit_id := Units.recruit(c, type)
	var full := Units.full_size(unit_id)
	var squad := {"id": _next_id, "type": type, "unit": unit_id, "men": full, "wounded": 0, "xp": 0, "level": 1,
		"pending_branch": false, "culture": c, "name": Captains.company_name(captain, type), "captain": captain}
	_next_id += 1
	return squad


func _new_captain(type: String, captain_culture: String = "") -> Dictionary:
	var taken := []
	for s in army:
		if s.get("captain") != null:
			taken.append(s["captain"]["first"])
	var c := Captains.make(rng, _next_captain, type, taken, captain_culture if captain_culture != "" else culture)
	_next_captain += 1
	return c


func total_men() -> int:
	var n := 0
	for s in army:
		n += int(s["men"])
	return n


func total_wounded() -> int:
	var n := 0
	for s in army:
		n += int(s.get("wounded", 0))
	return n


func total_headcount() -> int:
	return total_men() + total_wounded()


func is_wounded() -> bool:
	for s in army:
		var full := Units.full_size(s.get("unit", "")) if Units.has(s.get("unit", "")) else Troops.full_size(s["type"])
		if int(s["men"]) < full or int(s.get("wounded", 0)) > 0:
			return true
	return false


func has_specialization(spec: String) -> bool:
	for s in army:
		var c = s.get("captain")
		if c != null and String(c.get("specialization", "")) == spec:
			return true
	return false


## The captain who holds a veteran role, or {} if no one does. `except_id` leaves one
## captain out, so a profile can ask whether anyone else holds it.
func specialization_holder(spec: String, except_id: int = -1) -> Dictionary:
	for s in army:
		var c = s.get("captain")
		if typeof(c) == TYPE_DICTIONARY and String(c.get("specialization", "")) == spec and int(c.get("id", -1)) != except_id:
			return c
	return {}


func specialize_captain(captain_id: int, spec: String) -> bool:
	if not Captains.SPECIALIZATIONS.has(spec):
		return false
	var c = captain_by_id(captain_id)
	if c == null or not Captains.can_specialize(c):
		return false
	c["specialization"] = spec
	_note("%s has specialized as %s (%s)." % [c["name"], spec, Captains.SPECIALIZATION_TITLES.get(spec, "")])
	save_game()
	return true


func available_heroes_at(settlement_id: String) -> Array:
	var out := []
	for hid in Heroes.HEROES:
		if hired_heroes.has(hid):
			continue
		var h: Dictionary = Heroes.HEROES[hid]
		if String(h.get("origin_settlement", "")) == settlement_id:
			out.append(h.duplicate(true))
	return out


func recruit_hero(hero_id: String) -> bool:
	if hired_heroes.has(hero_id) or not Heroes.HEROES.has(hero_id):
		return false
	if army.size() >= squad_cap():
		return false
	var h: Dictionary = Heroes.hero(hero_id)
	var cost := int(h.get("cost", 200))
	if silver < cost:
		return false
	silver -= cost
	hired_heroes.append(hero_id)
	var captain := Heroes.make_hero_captain(h, _next_captain)
	_next_captain += 1
	var unit_id: String = String(h.get("unit", ""))
	var full := Units.full_size(unit_id) if Units.has(unit_id) else Troops.full_size(String(h.get("type", Troops.INFANTRY)))
	var squad := {
		"id": _next_id,
		"type": String(h.get("type", Troops.INFANTRY)),
		"unit": unit_id,
		"men": full,
		"wounded": 0,
		"xp": 30,
		"level": 2 if Units.tier(unit_id) >= 2 else 1,
		"pending_branch": false,
		"culture": String(h.get("culture", culture)),
		"name": Captains.company_name(captain, String(h.get("type", Troops.INFANTRY))),
		"captain": captain,
	}
	_next_id += 1
	army.append(squad)
	_note("Recruited %s to your company." % String(h.get("name", "Hero")))
	save_game()
	return true


func sighting_distance_mult() -> float:
	return 1.3 if has_specialization(Captains.SCOUT) else 1.0


# ---------------------------------------------------------------- settlement jobs

func jobs_at(settlement_id: String) -> Array:
	if world == null:
		return []
	return world.jobs_at(settlement_id)


func accept_job(settlement_id: String, index: int) -> bool:
	if world == null or active_jobs.size() >= Jobs.MAX_ACTIVE_JOBS:
		return false
	var list := jobs_at(settlement_id)
	if index < 0 or index >= list.size():
		return false
	var candidate: Dictionary = list[index]
	if String(candidate.get("type", "")) == Jobs.TYPE_HUNT:
		var target_pid: int = int(candidate.get("target_party_id", -1))
		for aj in active_jobs:
			if String(aj.get("type", "")) == Jobs.TYPE_HUNT and int(aj.get("target_party_id", -1)) == target_pid:
				return false
	var job: Dictionary = world.take_job(settlement_id, index)
	if job.is_empty():
		return false
	active_jobs.append(job)
	_note("Accepted contract: '%s'." % String(job.get("title", "Contract")))
	save_game()
	return true


func abandon_job(job_id: String) -> bool:
	for i in active_jobs.size():
		if String(active_jobs[i].get("id", "")) == job_id:
			var title := String(active_jobs[i].get("title", "Contract"))
			active_jobs.remove_at(i)
			_note("Abandoned contract: '%s'." % title)
			save_game()
			return true
	return false


func active_jobs_completable_at(settlement_id: String) -> Array:
	var out := []
	for job in active_jobs:
		match String(job.get("type", "")):
			Jobs.TYPE_COURIER:
				if String(job.get("destination_settlement", "")) == settlement_id and can_complete_job(job):
					out.append(job)
			Jobs.TYPE_RELIEF:
				if String(job.get("origin_settlement", "")) == settlement_id and can_complete_job(job):
					out.append(job)
			Jobs.TYPE_HUNT:
				if can_complete_job(job):
					out.append(job)
	return out


func can_complete_job(job: Dictionary) -> bool:
	if world == null:
		return false
	var deadline := float(job.get("deadline", INF))
	if world.hour > deadline:
		return false
	match String(job.get("type", "")):
		Jobs.TYPE_HUNT:
			return String(job.get("status", "")) == "ready_to_claim"
		Jobs.TYPE_COURIER:
			return world.here() == String(job.get("destination_settlement", ""))
		Jobs.TYPE_RELIEF:
			return world.here() == String(job.get("origin_settlement", "")) and food >= int(job.get("food_needed", 0))
	return false


func complete_job(job_id: String) -> Dictionary:
	var target_index := -1
	var job := {}
	for i in active_jobs.size():
		if String(active_jobs[i].get("id", "")) == job_id:
			target_index = i
			job = active_jobs[i]
			break
	if target_index == -1 or not can_complete_job(job):
		return {"ok": false, "reason": "Contract terms are not fulfilled."}

	active_jobs.remove_at(target_index)
	completed_jobs.append(job)
	_award_deeds()

	var r_silver := int(job.get("reward_silver", 0))
	var r_renown := int(job.get("reward_renown", 0))
	var r_rel := int(job.get("reward_relation", 0))

	silver += r_silver
	renown += r_renown

	if String(job.get("type", "")) == Jobs.TYPE_RELIEF:
		var needed := int(job.get("food_needed", 0))
		food = maxi(0, food - needed)
		if world != null:
			var v_id := String(job.get("origin_settlement", ""))
			world.offers[v_id] = world._new_offers(v_id)

	if world != null and r_rel > 0:
		var target_settlement: String = String(job.get("destination_settlement", job.get("origin_settlement", "")))
		if target_settlement != "":
			var owner_realm: String = world.owner_of(target_settlement)
			if owner_realm != "" and owner_realm != WorldData.BANDITS:
				add_realm_relation(owner_realm, r_rel)

	var title: String = String(job.get("title", "Contract"))
	_note("Completed: %s. Claimed %d silver and +%d renown." % [title, r_silver, r_renown])
	var lord_line := LordTalk.job_done(self, job)
	if lord_line != "":
		_note(lord_line)
	if world != null:
		world.emit_event({"type": "job_completed", "company": "Your warband", "title": title, "at": world.here()})

	save_game()
	return {"ok": true, "reward_silver": r_silver, "reward_renown": r_renown}


func _check_job_deadlines() -> void:
	if world == null:
		return
	for i in range(active_jobs.size() - 1, -1, -1):
		var job: Dictionary = active_jobs[i]
		var jtitle := String(job.get("title", "Contract"))
		if world.hour > float(job.get("deadline", INF)):
			active_jobs.remove_at(i)
			_end_commitment(String(job.get("id", "")), jtitle, "Expired: the deadline passed before it was done.")
			_note("Contract expired: The deadline for '%s' has passed." % jtitle)
			continue
		if String(job.get("type", "")) == Jobs.TYPE_HUNT:
			var party_id := int(job.get("target_party_id", -1))
			if party_id >= 0 and world.party(party_id) == null and String(job.get("status", "")) != "ready_to_claim":
				active_jobs.remove_at(i)
				_end_commitment(String(job.get("id", "")), jtitle, "Cancelled: another force scattered the band first.")
				_note("Contract canceled: The marauders of '%s' were dispersed by another force." % jtitle)


# ---------------------------------------------------------------- the wedding

## The planned (or held) public wedding: {} when there is none.
func wedding() -> Dictionary:
	return world.social.wedding if world != null and world.social != null else {}


func wedding_active() -> bool:
	return world != null and world.social != null and world.social.wedding_active()


## Your own seat, where you could host a wedding: your fief, if you still hold it.
func wedding_seat() -> String:
	if not has_fief() or bool(player_fief.get("lost", false)):
		return ""
	return fief_id()


## Where the wedding with `cand` could be: [{id, kind ("hers", "yours", "other"), name,
## hours, ok, reason}]. Her seat and yours first, then up to four friendly towns or castles
## nearest you.
func wedding_places(cand: String) -> Array:
	var out := []
	if world == null or world.social == null:
		return out
	var hers := String(world.social.get_candidate_person(cand).get("residence", ""))
	var seen := {}
	var add := func(id: String, kind: String) -> void:
		if id == "" or seen.has(id) or not WorldData.SETTLEMENTS.has(id):
			return
		seen[id] = true
		var why: String = world.wedding_blocked(id)
		if why == "" and String(WorldData.settlement(id)["type"]) == WorldData.VILLAGE:
			why = "a village is too small for a public wedding"
		out.append({"id": id, "kind": kind, "name": _settlement_name(id), "hours": world.hours_to(id), "ok": why == "", "reason": why})
	add.call(hers, "hers")
	add.call(wedding_seat(), "yours")
	var others := []
	for id in WorldData.SETTLEMENTS:
		if seen.has(id) or String(WorldData.settlement(id)["type"]) == WorldData.VILLAGE or world.wedding_blocked(id) != "":
			continue
		if world.relation_to_player(world.owner_of(id)) != "friendly" and world.owner_of(id) != WorldData.CROWN:
			continue
		others.append([world.hours_to(id), id])
	others.sort_custom(func(x, y): return float(x[0]) < float(y[0]))
	for o in others.slice(0, 4):
		add.call(String(o[1]), "other")
	return out


func choose_wedding_place(place: String) -> Dictionary:
	if not wedding_active():
		return {"ok": false, "reason": "No wedding is planned."}
	var why: String = world.wedding_blocked(place)
	if why != "":
		return {"ok": false, "reason": why}
	var r: Dictionary = world.social.plan_wedding(place, world.hour)
	save_game()
	return r


## Call the wedding off: what was set aside comes back.
func cancel_wedding() -> Dictionary:
	if not wedding_active():
		return {"ok": false, "reason": "No wedding is planned."}
	var r: Dictionary = world.social.cancel_wedding()
	silver += int(r.get("silver", 0))
	food += int(r.get("food", 0))
	save_game()
	return r


## Whether the wedding can begin now: ready, and you are at its place.
func wedding_can_begin() -> bool:
	if not wedding_active():
		return false
	var w := wedding()
	if String(w["state"]) != "ready":
		return false
	var p = world.player()
	return p != null and not p.moving() and p.node == String(w.get("place", ""))


## Who comes to the wedding: {guests: [{kind (host, lord, crown_lord, captain), id, name,
## face (a record CaptainArt draws), regard}], absent: [{name, reason}], gift_from}.
func wedding_guests() -> Dictionary:
	var out := {"guests": [], "absent": [], "gift_from": ""}
	if not wedding_active() and String(wedding().get("state", "")) != "done":
		return out
	var w := wedding()
	var place := String(w.get("place", ""))
	var host_realm: String = world.owner_of(place) if place != "" else ""
	var person: Dictionary = world.social.get_candidate_person(String(w.get("candidate_id", "")))
	var house: Dictionary = world.social.get_house(String(person.get("house_id", "")))
	var host_id := int(world.social.get_person(String(house.get("head_person_id", ""))).get("lord_id", -1))
	var taken := {}
	var can_come := func(l: Dictionary) -> String:
		if l.is_empty():
			return "gone"
		if String(l.get("state", "")) == "prisoner":
			return "a captive"
		var r := String(l.get("realm", ""))
		if r != WorldData.CROWN and world.relation_to_player(r) == "hostile":
			return "your realms are at war"
		if host_realm != "" and r != host_realm and r != WorldData.CROWN and host_realm != WorldData.CROWN and world.at_war(r, host_realm):
			return "at war with the host"
		return ""
	var host: Dictionary = world.lord_by_id(host_id) if host_id >= 0 else {}
	if not host.is_empty():
		taken[host_id] = true
		var why: String = can_come.call(host)
		if why == "":
			out["guests"].append(_wedding_lord_guest(host, "host"))
		else:
			out["absent"].append({"name": String(host["name"]), "reason": why})
	# Your sworn lords first if you wear a crown, then lords who think well of you.
	var crown_lords := []
	var friends := []
	for l in world.lords:
		var id := int(l.get("id", -1))
		if taken.has(id):
			continue
		var regard := LordTalk.regard(self, l)
		if String(l.get("realm", "")) == WorldData.CROWN:
			crown_lords.append(l)
		elif bool(l.get("met_player", false)) and regard >= Relationships.WEDDING_MIN_REGARD:
			friends.append(l)
		elif bool(l.get("met_player", false)) and String(l.get("realm", "")) != WorldData.CROWN and world.relation_to_player(String(l.get("realm", ""))) == "hostile" \
				and out["absent"].size() < 2:
			out["absent"].append({"name": String(l["name"]), "reason": "your realms are at war"})
	friends.sort_custom(func(x, y): return LordTalk.regard(self, x) > LordTalk.regard(self, y))
	var came := 0
	for l in crown_lords.slice(0, Relationships.WEDDING_LORD_GUESTS):
		if can_come.call(l) == "":
			out["guests"].append(_wedding_lord_guest(l, "crown_lord"))
	for l in friends:
		if came >= Relationships.WEDDING_LORD_GUESTS:
			break
		if can_come.call(l) == "":
			out["guests"].append(_wedding_lord_guest(l, "lord"))
			came += 1
	# The host realm's ruler sends a gift if they didn't come.
	if host_realm != "" and host_realm != WorldData.CROWN:
		for l in world.lords_of(host_realm):
			if bool(l.get("ruler", false)) and not out["guests"].any(func(g): return int(g["id"]) == int(l["id"])):
				if LordTalk.regard(self, l) >= 0:
					out["gift_from"] = String(l["name"])
				break
	for sq in army:
		var c = sq.get("captain")
		if c is Dictionary:
			out["guests"].append({"kind": "captain", "id": int(c["id"]), "name": String(c.get("first", c["name"])),
				"face": c, "regard": 0, "battles": int(c.get("battles", 0))})
	return out


func _wedding_lord_guest(l: Dictionary, kind: String) -> Dictionary:
	return {"kind": kind, "id": int(l["id"]), "name": String(l["name"]), "short": LordTalk.short_name(l),
		"face": LordVoice.portrait_record(l), "regard": LordTalk.regard(self, l), "bearing": String(l.get("bearing", "")),
		"realm": String(l.get("realm", ""))}


## Hold the wedding: married, Regard for the lords who came, renown, the pact, the news.
## `words` = {vow, their_vow, toast}. Returns {ok, guests, regard: [{name, amount}], renown, pact}.
func finish_wedding(words: Dictionary) -> Dictionary:
	if not wedding_active():
		return {"ok": false, "reason": "No wedding is planned."}
	var w := wedding()
	var g := wedding_guests()
	var regard := []
	for guest in g["guests"]:
		if String(guest["kind"]) == "captain":
			continue
		var l: Dictionary = world.lord_by_id(int(guest["id"]))
		var amount := Relationships.WEDDING_HOST_REGARD if String(guest["kind"]) == "host" else Relationships.WEDDING_GUEST_REGARD
		LordTalk.change_regard(self, l, amount)
		regard.append({"name": String(guest["name"]), "amount": amount})
	var info := words.duplicate()
	info["guests"] = g["guests"].map(func(x): return String(x["name"]))
	info["seat"] = wedding_seat()
	var r: Dictionary = world.social.finish_wedding(info, world.hour)
	if not bool(r.get("ok", false)):
		return r
	renown += Relationships.WEDDING_RENOWN
	var person: Dictionary = world.social.get_candidate_person(String(w["candidate_id"]))
	world.emit_event({"type": "wedding", "name": String(person.get("name", "")), "settlement": String(w["place"])})
	save_game()
	return {"ok": true, "guests": g["guests"], "regard": regard, "renown": Relationships.WEDDING_RENOWN,
		"pact": world.social.get_pact(String(person.get("house_id", "")))}


## Private vows: keep the words you said with their memory.
func record_private_vows(cand: String, vow: String, their_vow: String) -> void:
	if world == null or world.social == null:
		return
	var person: Dictionary = world.social.get_candidate_person(cand)
	world.social.set_memory_words(String(person.get("id", "")), {"vow": vow, "their_vow": their_vow})
	save_game()


## The wedding as a commitment for the journal, or {}.
func wedding_commitment() -> Dictionary:
	if not wedding_active():
		return {}
	var w := wedding()
	var person: Dictionary = world.social.get_candidate_person(String(w["candidate_id"]))
	var who := String(person.get("name", ""))
	var place := String(w.get("place", ""))
	var cost := "%d silver, %d rations set aside" % [int(w.get("reserved_silver", 0)), int(w.get("reserved_food", 0))]
	var entry := {"id": "wedding", "kind": "ceremony", "title": "Your wedding", "objective": "", "place": place,
		"reward": "Married to %s; a pact with her house" % who, "cost": cost, "hours_left": -1.0, "blocked": ""}
	match String(w["state"]):
		"planning":
			entry["title"] = "Your wedding: choose a place"
			entry["objective"] = "Talk with %s about where you'll marry." % who
			entry["place"] = String(person.get("residence", ""))
		"preparing":
			entry["title"] = "Your wedding at %s" % _settlement_name(place)
			entry["objective"] = "Ride there. It begins when you arrive, from %s." % _when_text(float(w["ready_hour"]))
		"ready":
			entry["title"] = "Your wedding at %s" % _settlement_name(place)
			entry["objective"] = "Ready. Ride to %s; %s waits for you there. No hurry." % [_settlement_name(place), who]
		"postponed":
			entry["title"] = "Your wedding: postponed"
			entry["objective"] = "%s. Talk with %s about a new place." % [String(w.get("postponed_reason", "The place can't host it")).capitalize(), who]
			entry["blocked"] = String(w.get("postponed_reason", ""))
			entry["place"] = String(person.get("residence", ""))
	return entry


## "tomorrow at dusk", "dusk on day 12".
func _when_text(hour: float) -> String:
	var today := int(world.hour / 24.0)
	var day := int(hour / 24.0)
	if day == today:
		return "dusk today"
	if day == today + 1:
		return "tomorrow at dusk"
	return "dusk on day %d" % (day + 1)


## Old marriage pacts protected a hard-coded village; protect her seat and yours instead.
func _fix_marriage_pacts() -> void:
	if world == null or world.social == null:
		return
	for hid in world.social.pacts:
		var pact: Dictionary = world.social.pacts[hid]
		if String(pact.get("origin", "")) != "marriage":
			continue
		var sites: Array = pact.get("protected_sites", [])
		if sites.has("thornwall") and wedding_seat() != "thornwall":
			sites.erase("thornwall")
			if wedding_seat() != "" and not sites.has(wedding_seat()):
				sites.append(wedding_seat())


# ---------------------------------------------------------------- the crown

# ---------------------------------------------------------------- gatherings

## The gathering called or under way at `place`, or {}.
func gathering_at(place: String) -> Dictionary:
	return world.gathering_at(place) if world != null else {}


## The gathering on now where you stand, or {}.
func gathering_here() -> Dictionary:
	if world == null or world.here() == "":
		return {}
	var g: Dictionary = world.gathering_at(world.here())
	return g if world.gathering_on(g) else {}


## What you've done at `g` so far (made on first use).
func gathering_record(g: Dictionary) -> Dictionary:
	var key := str(int(g.get("id", 0)))
	if not gathering_log.has(key):
		gathering_log[key] = {"spoke": [], "toast": false, "gift": false, "gossip_nights": [], "danced_nights": [], "marks": {}}
	return gathering_log[key]


## "Vardmark", "Kharzan", or your crown's name.
func realm_word(realm: String) -> String:
	if realm == WorldData.CROWN:
		return crown_title() if is_crowned() else "the crown"
	return realm.capitalize()


## Whether you're invited to `g`, and why: {invited, why}.
func gathering_invite(g: Dictionary) -> Dictionary:
	var realm := String(g.get("realm", ""))
	if realm == WorldData.CROWN and is_crowned():
		return {"invited": true, "why": "it is your own"}
	if gathering_barred(g):
		return {"invited": false, "why": "you are at war with %s" % realm_word(realm)}
	if has_contract() and contract_realm() == realm:
		return {"invited": true, "why": "you serve %s" % realm_word(realm)}
	if has_fief() and fief_realm() == realm and not bool(player_fief.get("lost", false)):
		return {"invited": true, "why": "you hold land of %s" % realm_word(realm)}
	if is_crowned() and world.allied_with_crown(realm):
		return {"invited": true, "why": "your crowns are allied"}
	var host: Dictionary = world.lord_by_id(int(g.get("host_lord", -1))) if int(g.get("host_lord", -1)) >= 0 else {}
	if not host.is_empty() and LordTalk.regard(self, host) >= Gatherings.INVITE_REGARD:
		return {"invited": true, "why": "%s thinks well of you" % LordTalk.short_name(host)}
	return {"invited": false, "why": ""}


## Whether `g`'s hall is shut to you: it's held by a realm you're at war with, so its
## gates are barred and nobody would seat you at the feast.
func gathering_barred(g: Dictionary) -> bool:
	if world == null or g.is_empty():
		return false
	var owner := String(world.owner_of(String(g.get("place", ""))))
	return is_at_war_with(owner) or is_at_war_with(String(g.get("realm", owner)))


## Who hosts `g`: "King Aldwin", or "you".
func gathering_host_name(g: Dictionary) -> String:
	if int(g.get("host_lord", -1)) < 0 or gathering_is_mine(g):
		return "you"
	var host: Dictionary = world.lord_by_id(int(g["host_lord"]))
	return LordTalk.short_name(host) if not host.is_empty() else "the host"


## "King Aldwin's feast", "your midsummer dance".
func gathering_title(g: Dictionary) -> String:
	var who := gathering_host_name(g)
	return "%s %s" % ["Your" if who == "you" else who + "'s", String(g.get("name", "feast"))]


## The lords in the hall at `g` now, the host first.
func gathering_lords(g: Dictionary) -> Array:
	var here: Array = world.lords_at(String(g["place"]))
	var host_id := int(g.get("host_lord", -1))
	here.sort_custom(func(a, b): return int(a["id"] == host_id) > int(b["id"] == host_id))
	return here


## Regard your first word with `l` at a gathering would bring now: 0 once you've spoken,
## or when no gathering is on where you both are.
func first_word_bonus(l: Dictionary) -> int:
	var g := gathering_here()
	if g.is_empty() or l.is_empty():
		return 0
	if not world.lords_at(String(g["place"])).has(l):
		return 0
	if (gathering_record(g)["spoke"] as Array).has(int(l["id"])):
		return 0
	return Gatherings.FIRST_WORD if bool(gathering_invite(g)["invited"]) else Gatherings.FIRST_WORD_UNINVITED


## Your first word with `l` at the gathering here: the Regard it brought (0 if none).
func first_word(l: Dictionary) -> int:
	var bonus := first_word_bonus(l)
	if bonus <= 0:
		return 0
	(gathering_record(gathering_here())["spoke"] as Array).append(int(l["id"]))
	LordTalk.change_regard(self, l, bonus)
	return bonus


func toast_check(g: Dictionary) -> Dictionary:
	if not world.gathering_on(g):
		return {"ok": false, "reason": "it hasn't begun"}
	if gathering_is_mine(g):
		return {"ok": false, "reason": "at your own table, you speak"}
	if bool(gathering_record(g)["toast"]):
		return {"ok": false, "reason": "raised once already"}
	if not bool(gathering_invite(g)["invited"]):
		return {"ok": false, "reason": "only the invited stand to toast"}
	if renown < Gatherings.TOAST_RENOWN:
		return {"ok": false, "reason": "renown %d of %d" % [renown, Gatherings.TOAST_RENOWN]}
	return {"ok": true, "reason": ""}


## Stand and raise a toast: every lord in the hall thinks a little better of you (a Cruel
## host doesn't care for it). {ok, text, lords}
func raise_toast(g: Dictionary) -> Dictionary:
	if not toast_check(g)["ok"]:
		return {"ok": false}
	gathering_record(g)["toast"] = true
	var warmed := 0
	for l in gathering_lords(g):
		if int(l["id"]) == int(g.get("host_lord", -1)) and String(l.get("bearing", "")) == Lords.CRUEL:
			continue
		LordTalk.change_regard(self, l, Gatherings.TOAST_REGARD)
		warmed += 1
	var text := Gatherings.fill(String(Gatherings.TOASTS.get(String(g.get("culture", "")), Gatherings.TOASTS[Cultures.VARDISH])),
		{"host": gathering_host_name(g)})
	save_game()
	return {"ok": true, "text": text, "lords": warmed}


## A gift for the host: 50 silver, or 50 rations if your purse is short. {ok, reason, what}
func gift_check(g: Dictionary) -> Dictionary:
	if int(g.get("host_lord", -1)) < 0 or gathering_is_mine(g):
		return {"ok": false, "reason": "it's your own", "what": ""}
	if not world.gathering_on(g):
		return {"ok": false, "reason": "it hasn't begun", "what": ""}
	if bool(gathering_record(g)["gift"]):
		return {"ok": false, "reason": "given", "what": ""}
	if silver >= Gatherings.GIFT_SILVER:
		return {"ok": true, "reason": "", "what": "silver"}
	if food >= Gatherings.GIFT_FOOD:
		return {"ok": true, "reason": "", "what": "food"}
	return {"ok": false, "reason": "you haven't %d silver or rations" % Gatherings.GIFT_SILVER, "what": ""}


func bring_gift(g: Dictionary) -> Dictionary:
	var check := gift_check(g)
	if not check["ok"]:
		return {"ok": false}
	if String(check["what"]) == "silver":
		silver -= Gatherings.GIFT_SILVER
	else:
		food -= Gatherings.GIFT_FOOD
	gathering_record(g)["gift"] = true
	var host: Dictionary = world.lord_by_id(int(g["host_lord"]))
	LordTalk.change_regard(self, host, Gatherings.GIFT_REGARD)
	add_realm_relation(String(g["realm"]), Gatherings.GIFT_REALM)
	save_game()
	return {"ok": true, "what": check["what"], "text": String(Gatherings.GIFT_THANKS.get(String(host.get("bearing", "")), "\"Thank you.\""))}


func gossip_check(g: Dictionary) -> Dictionary:
	if not world.gathering_on(g):
		return {"ok": false, "reason": "it hasn't begun"}
	if (gathering_record(g)["gossip_nights"] as Array).has(world.gathering_night(g)):
		return {"ok": false, "reason": "heard tonight"}
	return {"ok": true, "reason": ""}


## Why a lord might be sour with their ruler, from what the world knows, or "".
func sour_reason(l: Dictionary) -> String:
	var realm := String(l.get("realm", ""))
	if bool(l.get("ruler", false)) or realm == WorldData.CROWN or not world.realms.has(realm):
		return ""
	var fief := String(l.get("fief", ""))
	if fief == "":
		return "has no castle of their own"
	if world.owner_of(fief) != realm:
		return "lost %s, and blames the crown" % WorldData.settlement(fief)["name"]
	if world.is_burned(fief):
		return "watched %s burn" % WorldData.settlement(fief)["name"]
	for v in world.villages_of(realm):
		if world.is_burned(v) and String(WorldData.SETTLEMENTS[v].get("bound_to", "")) == fief:
			return "watched %s burn" % WorldData.settlement(v)["name"]
	if world.weariness_of(realm) >= 40.0:
		return "is sick of the war"
	return ""


## Spend an hour listening. The gossip only ever says something true: a lord sour with
## their ruler, a lord's trouble, or the latest war news. {ok, text, lord_id, hint}
func hear_gossip(g: Dictionary) -> Dictionary:
	if not gossip_check(g)["ok"]:
		return {"ok": false}
	var rec := gathering_record(g)
	(rec["gossip_nights"] as Array).append(world.gathering_night(g))
	if world.wait(Gatherings.GOSSIP_HOURS):
		advance(Gatherings.GOSSIP_HOURS)
	var out := {"ok": true, "text": "", "lord_id": -1, "hint": ""}
	var marks: Dictionary = rec["marks"]
	for l in gathering_lords(g):
		var why := sour_reason(l)
		if why != "" and not marks.has(str(int(l["id"]))):
			var ruler := LordTalk.ruler_name(l)
			out["text"] = "%s %s, and says so after the second cup. %s may hear you out." % [LordTalk.short_name(l), why, LordTalk.first_name(l)]
			out["lord_id"] = int(l["id"])
			out["hint"] = "sour with %s" % ruler
			LordTalk.record(l)["doubts_king"] = 1
			marks[str(int(l["id"]))] = out["hint"]
			save_game()
			return out
	for l in gathering_lords(g):
		if marks.has(str(int(l["id"]))):
			continue
		var tr := LordTalk.trouble(self, l)
		if String(tr.get("kind", "")) == "bandits":
			out["text"] = "%s is plagued by %s, and would pay to see them gone." % [LordTalk.short_name(l), String(tr["name"])]
			out["lord_id"] = int(l["id"])
			out["hint"] = "has a trouble"
			marks[str(int(l["id"]))] = out["hint"]
			save_game()
			return out
	for e in world.activity_log:
		if String(e.get("category", "")) in ["war", "siege"] and String(e.get("type", "")) not in ["gathering", "gathering_broken"]:
			out["text"] = "Talk at the table is all of one thing: %s" % String(e["text"])
			save_game()
			return out
	out["text"] = "Talk of the harvest, a horse race, and who wore what. Nothing worth the hour, but the wine was good."
	save_game()
	return out


## Whether there's a dance tonight, and you've a dance left: the last night of a feast,
## every night of a dance.
func dance_check(g: Dictionary) -> Dictionary:
	if not world.gathering_on(g):
		return {"ok": false, "reason": "it hasn't begun"}
	var night: int = world.gathering_night(g)
	if String(g.get("kind", "")) != Gatherings.DANCE and night < 3:
		return {"ok": false, "reason": "the dancing is on the last night"}
	if (gathering_record(g)["danced_nights"] as Array).has(night):
		return {"ok": false, "reason": "you've danced tonight"}
	return {"ok": true, "reason": ""}


## Who you could ask: someone you court who's here, the lords in the hall, or no one (the
## wall). [{kind ("romance", "lord", "wall"), id, name, tag}]
func dance_partners(g: Dictionary) -> Array:
	var out := []
	var social = world.social
	if social != null:
		for person in social.residents_at(String(g["place"])):
			var cid := String(person.get("content_id", ""))
			var rel: Dictionary = social.get_relationship(cid)
			if String(rel.get("status", "")) in [Relationships.COURTING, Relationships.COMMITTED, Relationships.ENGAGED, Relationships.MARRIED]:
				var more := int(rel.get("dances", 0)) < Gatherings.DANCE_TRUST_CAP
				out.append({"kind": "romance", "id": cid, "name": String(person.get("name", "")),
					"tag": "time together · %skept as a memory" % ("+%d trust · " % Gatherings.DANCE_TRUST if more else "")})
	for l in gathering_lords(g):
		var daring := String(l.get("bearing", "")) == Lords.DARING
		out.append({"kind": "lord", "id": str(int(l["id"])), "name": LordTalk.short_name(l),
			"tag": "+%d Regard%s" % [Gatherings.DANCE_DARING if daring else Gatherings.DANCE_LORD, " · Daring: they like a bold ask" if daring else ""]})
	out.append({"kind": "wall", "id": "", "name": "", "tag": "hear the gossip" if gossip_check(g)["ok"] else "just listen"})
	return out


## Dance with a partner from dance_partners(). {ok, kind, text, regard, trust, gossip}
func dance(g: Dictionary, kind: String, id: String) -> Dictionary:
	if not dance_check(g)["ok"]:
		return {"ok": false}
	var night: int = world.gathering_night(g)
	var cult := String(g.get("culture", Cultures.VARDISH))
	var out := {"ok": true, "kind": kind, "text": "", "regard": 0, "trust": 0, "gossip": {}}
	match kind:
		"romance":
			var person: Dictionary = world.social.get_candidate_person(id)
			if person.is_empty():
				return {"ok": false}
			out["text"] = String(Gatherings.DANCE_ROMANCE.get(id, "%s takes your hand." % String(person.get("name", ""))))
			out["trust"] = world.social.dance_with(id, "dance_" + cult, String(Gatherings.DANCE_MEMORY.get(id, "You danced together.")), String(g["place"]), world.hour)
		"lord":
			var l: Dictionary = world.lord_by_id(int(id))
			if l.is_empty() or not gathering_lords(g).has(l):
				return {"ok": false}
			var gain := Gatherings.DANCE_DARING if String(l.get("bearing", "")) == Lords.DARING else Gatherings.DANCE_LORD
			LordTalk.change_regard(self, l, gain)
			out["regard"] = gain
			out["text"] = String(Gatherings.DANCE_LORD_LINES.get(String(l.get("bearing", "")), "They dance well."))
		"wall":
			out["text"] = Gatherings.DANCE_WALL
			if gossip_check(g)["ok"]:
				out["gossip"] = hear_gossip(g)
		_:
			return {"ok": false}
	(gathering_record(g)["danced_nights"] as Array).append(night)
	save_game()
	return out


## Gatherings you're invited to that you haven't been told of yet (marks them told).
func take_new_invitations() -> Array:
	var out := []
	if world == null:
		return out
	for g in world.gatherings:
		var gid := int(g["id"])
		if invites_seen.has(gid) or int(g.get("host_lord", -1)) < 0 or gathering_is_mine(g):
			continue
		invites_seen.append(gid)
		if bool(gathering_invite(g)["invited"]):
			out.append(g)
	return out


## "from tomorrow at dusk", "the second night of three".
func gathering_when(g: Dictionary) -> String:
	var night: int = world.gathering_night(g)
	if night > 0:
		return "%s of three" % Gatherings.night_word(night)
	var day := int(float(g["starts_hour"]) / 24.0)
	var today := int(world.hour / 24.0)
	if day == today:
		return "from dusk today"
	if day == today + 1:
		return "from tomorrow at dusk"
	return "from dusk on day %d" % (day + 1)


## Gatherings you're invited to, as journal entries.
func gathering_commitments() -> Array:
	var out := []
	if world == null:
		return out
	for g in world.gatherings:
		var inv := gathering_invite(g)
		var mine := gathering_is_mine(g)
		if not bool(inv["invited"]) and not mine:
			continue
		var place := String(g["place"])
		var coming: int = world.gathering_guests(g).size()
		var objective := ""
		if mine:
			objective = "Your guests ride in to %s, %s. Be there on the first night to greet them%s." % [_settlement_name(place), gathering_when(g),
				", or the lords you're winning over will notice" if not (hosted.get("persuade", []) as Array).is_empty() else ""]
		else:
			objective = "%s, %s. You're invited: %s. %d lord%s coming." % [gathering_title(g), gathering_when(g), String(inv["why"]), coming, "" if coming == 1 else "s"]
		out.append({"id": "gathering_%d" % int(g["id"]), "kind": "gathering", "title": "The %s at %s" % [String(g["name"]), _settlement_name(place)],
			"objective": objective, "place": place, "reward": "Regard with every lord there", "cost": "",
			"hours_left": maxf(0.0, float(g["ends_hour"]) - world.hour), "blocked": ""})
	return out


# ---------------------------------------------------------------- your own gathering

## Where your crown can hold court: its seat first, then its other castles and towns.
func host_places() -> Array:
	if not is_crowned():
		return []
	var seat: String = world.capital_of(WorldData.CROWN)
	var out := []
	if seat != "" and world.owner_of(seat) == WorldData.CROWN:
		out.append(seat)
	for id in crown_holdings():
		if id != seat and not WorldData.is_village(id):
			out.append(id)
	return out


## The crown lord whose hall `place` is, who would host there in your name, or {} (your
## own seat, or a hall no lord holds).
func host_lord_at(place: String) -> Dictionary:
	if not is_crowned() or place == world.capital_of(WorldData.CROWN):
		return {}
	var l := holder_of(place)
	return l if not l.is_empty() and String(l.get("state", "")) == "field" else {}


## Whether your crown can hold a gathering of `kind` at `place` (your seat when "") now.
## {ok, reason}
func host_check(place: String = "", kind: String = Gatherings.FEAST) -> Dictionary:
	if not is_crowned():
		return {"ok": false, "reason": "Only a crown holds court."}
	if place == "":
		place = world.capital_of(WorldData.CROWN)
	if place == "" or not host_places().has(place):
		return {"ok": false, "reason": "You need a castle or town of your own to hold court in."}
	if not world.gathering_of_realm(WorldData.CROWN).is_empty():
		return {"ok": false, "reason": "Your guests are already on the road."}
	if world.hour < host_ready_at:
		return {"ok": false, "reason": "Your last gathering is still talked about; hold another in %d days." % ceili((host_ready_at - world.hour) / 24.0)}
	var need_silver := Gatherings.HOST_SILVER + (Gatherings.TOURNEY_PURSE if kind == Gatherings.TOURNEY else 0)
	if silver < need_silver:
		return {"ok": false, "reason": "You need %d silver." % need_silver}
	if food < Gatherings.HOST_FOOD:
		return {"ok": false, "reason": "You need %d rations." % Gatherings.HOST_FOOD}
	if world.is_sieged(place):
		return {"ok": false, "reason": "Not under siege."}
	if world.is_burned(place):
		return {"ok": false, "reason": "Not while %s is rebuilding." % WorldData.settlement(place)["name"]}
	for r in world.realms:
		if r != WorldData.CROWN and world.at_war(WorldData.CROWN, r):
			for l in world.lords_of(r):
				var lp = world.party(int(l.get("party", -1)))
				if lp != null and world._hours(lp, String(lp.next) if lp.moving() else String(lp.node), place) <= Gatherings.REACH_HOURS:
					return {"ok": false, "reason": "Not with %s's lords within two days of %s." % [realm_word(r), WorldData.settlement(place)["name"]]}
	return {"ok": true, "reason": ""}


## Who you could invite to `place` (your seat when ""): {sworn: [lords], friends: [lords],
## persuade: [lords], lieges: [lords]}. Sworn lords always come; friends think well of
## you; lords you'd win over come unless they despise you; lieges are the rulers of lords
## you've asked.
func host_invitees(place: String = "") -> Dictionary:
	var out := {"sworn": [], "friends": [], "persuade": [], "lieges": []}
	if not is_crowned():
		return out
	if place == "":
		place = world.capital_of(WorldData.CROWN)
	var host := host_lord_at(place)
	for l in world.lords:
		if l == host or not world._free_to_gather(l):
			continue
		var lp = world.party(int(l["party"]))
		if world._hours(lp, String(lp.next) if lp.moving() else String(lp.node), place) > Gatherings.REACH_HOURS:
			continue
		var realm := String(l.get("realm", ""))
		if realm == WorldData.CROWN:
			out["sworn"].append(l)
		elif world.at_war(WorldData.CROWN, realm):
			continue
		elif bool(l.get("ruler", false)):
			out["lieges"].append(l)
		elif LordTalk.regard(self, l) >= Gatherings.HOST_FRIEND_REGARD:
			out["friends"].append(l)
		elif LordTalk.persuade_check(self, l)["ok"] and LordTalk.regard(self, l) > Gatherings.HOST_SPURN:
			out["persuade"].append(l)
	return out


## Hold a gathering: `kind` feast, dance or tourney, at `place` (your seat when ""; a
## lord's hall means he hosts it in your name); `ask` says which groups beyond your sworn
## lords to invite ({friends, persuade, lieges}). You needn't be there to call it.
## {ok, reason, guests}
func host_gathering(kind: String, ask: Dictionary, place: String = "") -> Dictionary:
	if place == "":
		place = world.capital_of(WorldData.CROWN) if is_crowned() else ""
	var check := host_check(place, kind)
	if not check["ok"]:
		return {"ok": false, "reason": check["reason"], "guests": 0}
	var who := host_invitees(place)
	var ids := []
	for l in who["sworn"]:
		ids.append(int(l["id"]))
	var asked_realms := {}
	var persuade := []
	for group in ["friends", "persuade"]:
		if bool(ask.get(group, false)):
			for l in who[group]:
				ids.append(int(l["id"]))
				asked_realms[String(l["realm"])] = true
				if group == "persuade":
					persuade.append(int(l["id"]))
	if bool(ask.get("lieges", false)):
		for l in who["lieges"]:
			ids.append(int(l["id"]))
	else:
		# Asking a ruler's lords without the ruler is a small snub.
		for l in who["lieges"]:
			if asked_realms.has(String(l["realm"])):
				LordTalk.change_regard(self, l, Gatherings.SNUB_REGARD)
	var host := host_lord_at(place)
	var g: Dictionary = world.call_gathering(WorldData.CROWN, "player", place, kind, ids, int(host["id"]) if not host.is_empty() else -1)
	if g.is_empty():
		return {"ok": false, "reason": "The gathering couldn't be called.", "guests": 0}
	silver -= Gatherings.HOST_SILVER + (Gatherings.TOURNEY_PURSE if kind == Gatherings.TOURNEY else 0)
	food -= Gatherings.HOST_FOOD
	host_ready_at = world.hour + Gatherings.HOST_COOLDOWN_DAYS * 24.0
	if not host.is_empty():
		LordTalk.change_regard(self, host, Gatherings.HOST_IN_NAME_REGARD)
	for lid in g["guests"]:
		var l: Dictionary = world.lord_by_id(int(lid))
		LordTalk.change_regard(self, l, Gatherings.HOST_REGARD)
		# Bought lords' unrest eases: they've been seen at your table.
		if int(l.get("bought", 0)) == 1 and LordTalk.regard(self, l) < 0:
			LordTalk.change_regard(self, l, -LordTalk.regard(self, l))
	hosted = {"id": int(g["id"]), "place": String(g["place"]), "kind": kind, "starts_hour": float(g["starts_hour"]), "ends_hour": float(g["ends_hour"]),
		"guests": (g["guests"] as Array).duplicate(), "persuade": persuade.filter(func(x): return (g["guests"] as Array).has(x)),
		"king_seen": false, "absent_done": false, "honoured": -1, "speech": false, "gifts": false, "heard": [], "tourney": {}}
	invites_seen.append(int(g["id"]))
	save_game()
	return {"ok": true, "reason": "", "guests": (g["guests"] as Array).size()}


## Whether `g` is your own gathering (whoever's hall it's in).
func gathering_is_mine(g: Dictionary) -> bool:
	return not g.is_empty() and String(g.get("reason", "")) == "player" and String(g.get("realm", "")) == WorldData.CROWN


## Your gathering now under way or still to come, as the world has it, or {}.
func my_gathering() -> Dictionary:
	if hosted.is_empty() or world == null:
		return {}
	var g: Dictionary = world.gathering_by_id(int(hosted.get("id", 0)))
	return g if gathering_is_mine(g) else {}


## The king isn't at his own table on the first night: the lords you were winning over
## notice. Seen once you're in the hall while it's on.
func _step_hosted() -> void:
	var g := my_gathering()
	if g.is_empty():
		return
	if world.gathering_on(g) and world.here() == String(g["place"]):
		hosted["king_seen"] = true
	if bool(hosted.get("king_seen", false)) or bool(hosted.get("absent_done", false)):
		return
	if world.hour >= float(hosted.get("starts_hour", 0.0)) + 24.0:
		hosted["absent_done"] = true
		var sore := 0
		for lid in hosted.get("persuade", []):
			var l: Dictionary = world.lord_by_id(int(lid))
			if not l.is_empty():
				LordTalk.change_regard(self, l, Gatherings.ABSENT_KING_REGARD)
				sore += 1
		_note("Your lords drank at %s without you on the first night.%s" % [WorldData.settlement(String(g["place"]))["name"],
			(" The %d you were winning over noticed (%d Regard)." % [sore, Gatherings.ABSENT_KING_REGARD]) if sore > 0 else ""])


## The warmth your own gathering adds to a lord's conviction while it lasts and a few days after.
func gathering_conviction(l: Dictionary) -> int:
	if hosted.is_empty() or world == null:
		return 0
	if world.hour > float(hosted.get("ends_hour", 0.0)) + Gatherings.HOST_AFTER_HOURS:
		return 0
	if not (hosted.get("guests", []) as Array).has(int(l.get("id", -1))):
		return 0
	# A king who made the case for his war at table convinces more.
	return Gatherings.HOST_CONVICTION + (Gatherings.SPEECH_CONVICTION if bool(hosted.get("speech_war", false)) else 0)


## Forget what was done at gatherings long over.
func _prune_gathering_log() -> void:
	if world == null:
		return
	var live := {}
	for g in world.gatherings:
		live[str(int(g["id"]))] = true
	for key in gathering_log.keys():
		if not live.has(String(key)):
			gathering_log.erase(key)
	invites_seen = invites_seen.filter(func(id): return world.gatherings.any(func(g): return int(g["id"]) == int(id)))


const CROWN_RENOWN := 200
## Days at war before the crown can sue for peace, and the enemy weariness it needs.
const CROWN_PEACE_DAYS := 7
const CROWN_PEACE_WEARINESS := 30.0


## Whether the company rules its own realm.
func is_crowned() -> bool:
	return world != null and world.realms.has(WorldData.CROWN)


## Whether the company can raise its own banner now. {ok, reason}.
func crown_check() -> Dictionary:
	if world == null or is_crowned():
		return {"ok": false, "reason": "The crown is already raised."}
	if not has_fief() or bool(player_fief.get("lost", false)):
		return {"ok": false, "reason": "A crown needs a seat: hold a fief of your own first."}
	if String(WorldData.settlement(fief_id())["type"]) == WorldData.VILLAGE:
		return {"ok": false, "reason": "A crown needs walls: your seat is a village. Hold a castle or a town."}
	if has_contract():
		return {"ok": false, "reason": "Serve out or break your contract first."}
	if renown < CROWN_RENOWN:
		return {"ok": false, "reason": "Only a famous company can raise a crown (%d of %d renown)." % [renown, CROWN_RENOWN]}
	if world.here() != fief_id():
		return {"ok": false, "reason": "Raise it at your own seat."}
	return {"ok": true, "reason": ""}


## Cast off the liege and raise the company's own crown at its fief.
func declare_crown() -> bool:
	if not crown_check()["ok"]:
		return false
	var seat := fief_id()
	var liege := fief_realm()
	WorldData.crown_culture = culture
	player_fief["realm"] = WorldData.CROWN
	world.declare_crown(seat)
	world.player().faction = WorldData.CROWN
	add_realm_relation(liege, -60)
	_note("You raise your own banner over %s. %s will not forgive it: it is war." % [
		WorldData.settlement(seat)["name"], WorldData.FACTIONS[liege]["name"] if WorldData.FACTIONS.has(liege) else "Your liege"])
	save_game()
	return true


## What the crown holds: castles, towns and villages.
func crown_holdings() -> Array:
	return world.holdings_of(WorldData.CROWN) if is_crowned() else []


## A day of crown dues: half to the company's purse, half to the crown treasury for its
## garrisons. The fief itself pays through the fief as before.
func _crown_day() -> void:
	if not is_crowned():
		return
	if _crown_fate():
		return
	for name in LordTalk.bought_lords_day(self):
		_note("%s thinks too little of you now to stay bought, and rides back to their old allegiance, castle and all." % name)
	var dues := 0
	for id in crown_holdings():
		if id == fief_id() or world.is_burned(id):
			continue
		dues += int(Lords.INCOME.get(String(WorldData.settlement(id)["type"]), 0))
	if dues <= 0:
		return
	silver += dues / 2
	world.realms[WorldData.CROWN]["treasury"] = int(world.realms[WorldData.CROWN]["treasury"]) + dues - dues / 2


## Lords sworn to the crown.
func crown_lords() -> Array:
	return world.lords_of(WorldData.CROWN) if is_crowned() else []


## Whether a captive lord would swear to the crown. Honorable lords keep faith with the
## realm they serve; rulers never bend the knee.
func swear_check(lord_id: int) -> Dictionary:
	var l: Dictionary = world.lord_by_id(lord_id) if world != null else {}
	if not is_crowned() or l.is_empty() or l.get("state") != "prisoner" or l.get("captive_of") != "player":
		return {"ok": false, "reason": "Only your own captives can swear to your crown."}
	if bool(l.get("ruler", false)):
		return {"ok": false, "reason": "A ruler will not kneel to another crown."}
	if String(l.get("bearing", "")) == Lords.HONORABLE:
		return {"ok": false, "reason": "%s keeps faith with the realm they serve." % l["name"]}
	return {"ok": true, "reason": ""}


## A captive lord swears to the crown: they serve it from a crown castle (or its seat),
## and raise their warband again from the crown treasury.
func swear_lord_to_crown(lord_id: int) -> bool:
	if not swear_check(lord_id)["ok"]:
		return false
	var l: Dictionary = world.lord_by_id(lord_id)
	var was := String(l["realm"])
	var seat := ""
	for id in crown_holdings():
		if String(WorldData.settlement(id)["type"]) == WorldData.CASTLE and id != fief_id() \
				and not crown_lords().any(func(o): return String(o.get("fief", "")) == id):
			seat = id
			break
	l["realm"] = WorldData.CROWN
	l["fief"] = seat
	l["ruler"] = false
	world.release_lord(lord_id)
	add_lord_relation(lord_id, 30)
	if world.realms.has(was):
		add_realm_relation(was, -10)
	_note_item({"kind": "sworn", "name": String(l["name"]),
		"seat": String(WorldData.settlement(seat)["name"]) if seat != "" else ""})
	world.emit_event({"type": "lord_sworn", "lord": String(l["name"]), "from": was})
	save_game()
	return true


## Realms the crown could ally with now.
func crown_allies_possible() -> Array:
	var out := []
	if not is_crowned():
		return out
	for r in world.realms:
		if world.can_ally_crown(r):
			out.append(r)
	return out


func propose_alliance(realm: String) -> bool:
	if not is_crowned() or not world.ally_crown(realm):
		return false
	add_realm_relation(realm, 20)
	_note("%s agrees to an alliance against your common enemies." % WorldData.FACTIONS[realm]["name"])
	save_game()
	return true


## Whether the crown can sue `realm` for peace: at war long enough, and they're weary.
func crown_peace_check(realm: String) -> Dictionary:
	if not is_crowned() or not world.at_war(WorldData.CROWN, realm):
		return {"ok": false, "reason": "You are not at war with them."}
	var since := float(world.wars[world.war_key(WorldData.CROWN, realm)].get("since", world.hour))
	if world.hour - since < CROWN_PEACE_DAYS * 24.0:
		return {"ok": false, "reason": "Too soon: they won't treat with a crown not %d days old in war." % CROWN_PEACE_DAYS}
	if world.weariness_of(realm) < CROWN_PEACE_WEARINESS:
		return {"ok": false, "reason": "They aren't weary enough of the war yet (%d of %d)." % [int(world.weariness_of(realm)), int(CROWN_PEACE_WEARINESS)]}
	return {"ok": true, "reason": ""}


## Peace: whoever is wearier of the war pays the other tribute for a while.
func sue_for_peace(realm: String) -> bool:
	if not crown_peace_check(realm)["ok"]:
		return false
	var terms: Dictionary = world.peace_terms(WorldData.CROWN, realm)
	world._sign_peace_treaty(WorldData.CROWN, realm)
	add_realm_relation(realm, 30)
	var t := ""
	if int(terms["daily"]) > 0:
		t = " They pay you %d silver a day for %d days." % [int(terms["daily"]), int(terms["days"])] if terms["to"] == WorldData.CROWN \
			else " Your treasury pays them %d silver a day for %d days." % [int(terms["daily"]), int(terms["days"])]
	_note("%s accepts peace with your crown. A truce holds.%s" % [WorldData.FACTIONS[realm]["name"], t])
	save_game()
	return true


# ---------------------------------------------------------------- ruling the crown

const CROWN_FALL_DAYS := 3
const GRANT_REGARD := 15
const REVOKE_REGARD := -25
const DISPOSSESSED_REGARD := -15
const DRAW_REGARD := -2
const TREASURY_STEP := 500
const DECLARE_RELATION := -30


## Name your crown and choose its colour.
func set_crown_identity(name: String, color_index: int) -> void:
	crown_name = name.strip_edges().left(32)
	crown_color = clampi(color_index, 0, WorldData.CROWN_COLORS.size() - 1)
	WorldData.set_crown(crown_name, crown_color)
	save_game()


func crown_title() -> String:
	return String(WorldData.FACTIONS[WorldData.CROWN]["name"])


## Every realm's first capital: hold them all and the Glass Sea is yours.
func crown_capitals() -> Array:
	var out := []
	for r in ["vardmark", "kharzan", "ryumon"]:
		out.append(String(WorldData.FACTIONS[r]["capital"]))
	return out


## Once a day: the crown wins when it holds every capital, and falls when it has held
## nothing for CROWN_FALL_DAYS. True if it fell.
func _crown_fate() -> bool:
	var held := crown_holdings()
	if held.is_empty():
		crown_empty_days += 1
		if crown_empty_days >= CROWN_FALL_DAYS:
			fall_crown()
			return true
		_note("Your crown holds nothing. Take back a castle or a town within %d day%s, or it falls." % [
			CROWN_FALL_DAYS - crown_empty_days, "" if CROWN_FALL_DAYS - crown_empty_days == 1 else "s"])
		return false
	crown_empty_days = 0
	if not crown_won and crown_capitals().all(func(id): return held.has(id)):
		crown_won = true
		renown += 100
		world.emit_event({"type": "crown_victory"})
		map_notice_title = "One crown"
		map_notice = "%s holds Highcliff, Khalun and Kurogane. Every realm's capital flies your banner: the Glass Sea has one crown now. (+100 renown)\n\nThe campaign carries on for as long as you like." % WorldData.title_case(crown_title())
	return false


## The crown falls: its lords go back to their old allegiances, its wars end, and the
## company is free again, to raise a banner another day.
func fall_crown() -> void:
	if not is_crowned():
		return
	var gone: Array = world.dissolve_crown()
	player_fief = {}
	world.player().faction = ""
	crown_won = false
	crown_empty_days = 0
	map_notice_title = "The crown falls"
	map_notice = "Your crown has fallen. It held nothing, and %s. The company rides free again; hold a castle or a town and you may raise a banner anew." % (
		"its lords have gone back to their old allegiances" if not gone.is_empty() else "no lord was left to serve it")
	save_game()


## Castles and towns of the crown other than your seat: the ones you rule through lords.
func crown_fiefs() -> Array:
	return crown_holdings().filter(func(id): return String(WorldData.settlement(id)["type"]) != WorldData.VILLAGE and id != fief_id())


## The crown lord holding `id`, or {}.
func holder_of(id: String) -> Dictionary:
	for l in crown_lords():
		if String(l.get("fief", "")) == id:
			return l
	return {}


func grant_check(id: String, lord_id: int) -> Dictionary:
	var l: Dictionary = world.lord_by_id(lord_id) if world != null else {}
	if not is_crowned() or not crown_fiefs().has(id):
		return {"ok": false, "reason": "Only your crown's castles and towns, not your own seat, can be granted."}
	if l.is_empty() or String(l.get("realm", "")) != WorldData.CROWN:
		return {"ok": false, "reason": "Only a lord sworn to you can hold your land."}
	if String(l.get("fief", "")) == id:
		return {"ok": false, "reason": "They already hold it."}
	return {"ok": true, "reason": ""}


## Grant a castle or town to a sworn lord: their seat now, where they rest and refill.
## Whoever held it before loses it, and resents it.
func grant_fief(id: String, lord_id: int, regard: int = GRANT_REGARD) -> bool:
	if not grant_check(id, lord_id)["ok"]:
		return false
	var l: Dictionary = world.lord_by_id(lord_id)
	var before := holder_of(id)
	if not before.is_empty():
		before["fief"] = ""
		add_lord_relation(int(before["id"]), DISPOSSESSED_REGARD)
	l["fief"] = id
	add_lord_relation(lord_id, regard)
	world.emit_event({"type": "fief_given", "lord": String(l["name"]), "settlement": id})
	_note("You grant %s to %s (+%d Regard)." % [WorldData.settlement(id)["name"], l["name"], regard])
	save_game()
	return true


func revoke_fief(lord_id: int) -> bool:
	var l: Dictionary = world.lord_by_id(lord_id) if world != null else {}
	if l.is_empty() or String(l.get("realm", "")) != WorldData.CROWN or String(l.get("fief", "")) == "":
		return false
	var was := String(l["fief"])
	l["fief"] = ""
	add_lord_relation(lord_id, REVOKE_REGARD)
	_note("You take %s back from %s (%d Regard)." % [WorldData.settlement(was)["name"], l["name"], REVOKE_REGARD])
	save_game()
	return true


func crown_treasury() -> int:
	return int(world.realms[WorldData.CROWN].get("treasury", 0)) if is_crowned() else 0


## What the crown takes in a day: dues to your purse and to the treasury.
func crown_income() -> Dictionary:
	var dues := 0
	for id in crown_holdings():
		if id == fief_id() or world.is_burned(id):
			continue
		dues += int(Lords.INCOME.get(String(WorldData.settlement(id)["type"]), 0))
	return {"purse": dues / 2, "treasury": dues - dues / 2}


## Take silver from the treasury for your purse. Your lords notice.
func draw_treasury(amount: int) -> bool:
	if not is_crowned() or amount <= 0 or crown_treasury() < amount:
		return false
	world.realms[WorldData.CROWN]["treasury"] = crown_treasury() - amount
	silver += amount
	for l in crown_lords():
		add_lord_relation(int(l["id"]), DRAW_REGARD)
	_note("You draw %d silver from the treasury. Your lords notice (%d Regard each)." % [amount, DRAW_REGARD])
	save_game()
	return true


## Put silver of your own into the treasury, for garrisons and your lords' men.
func fund_treasury(amount: int) -> bool:
	if not is_crowned() or amount <= 0 or silver < amount:
		return false
	silver -= amount
	world.realms[WorldData.CROWN]["treasury"] = crown_treasury() + amount
	save_game()
	return true


## Station one of your squads in a crown castle or town you're at (your seat has its own
## garrison page). It stands with the garrison until you take it back.
func station_in_holding(squad_id: int) -> bool:
	var id: String = world.here() if world != null else ""
	if not crown_fiefs().has(id):
		return false
	var sq := squad_by_id(squad_id)
	if sq.is_empty() or army.size() <= 1:
		return false
	army.erase(sq)
	sq["stationed_by_company"] = true
	var g: Array = world.garrisons.get(id, [])
	g.append(sq)
	world.garrisons[id] = g
	_note("%s stands with the garrison of %s." % [String(sq.get("name", "The squad")), WorldData.settlement(id)["name"]])
	save_game()
	return true


func stationed_at(id: String) -> Array:
	return world.garrison_at(id).filter(func(sq): return bool(sq.get("stationed_by_company", false))) if world != null else []


func withdraw_from_holding(squad_id: int) -> bool:
	var id: String = world.here() if world != null else ""
	for sq in stationed_at(id):
		if int(sq["id"]) == squad_id:
			world.garrisons[id].erase(sq)
			sq.erase("stationed_by_company")
			army.append(sq)
			save_game()
			return true
	return false


## Order a sworn lord: "guard" a holding, "follow" you (they join your fights), or "" to
## let them go about the realm's business.
func order_lord(lord_id: int, kind: String, target: String = "") -> bool:
	var l: Dictionary = world.lord_by_id(lord_id) if world != null else {}
	if l.is_empty() or String(l.get("realm", "")) != WorldData.CROWN:
		return false
	if kind == "":
		l.erase("order")
	elif kind == "guard" and crown_holdings().has(target):
		l["order"] = {"kind": "guard", "target": target}
	elif kind == "follow":
		l["order"] = {"kind": "follow", "target": ""}
	else:
		return false
	l["think_at"] = world.hour
	save_game()
	return true


## Call your lords to arms against an enemy castle or town: {ok, reason}.
func call_check(target: String) -> Dictionary:
	if not is_crowned():
		return {"ok": false, "reason": "You have no crown to call to arms."}
	if world.campaign_armies.any(func(a): return String(a["realm"]) == WorldData.CROWN):
		return {"ok": false, "reason": "Your army is already in the field."}
	if not Lords.WALLS.has(String(WorldData.settlement(target)["type"])) or not world.at_war(WorldData.CROWN, world.owner_of(target)):
		return {"ok": false, "reason": "Name a castle or town of a realm you're at war with."}
	var ready: Array = MarshalArmies.ready_lords(world, WorldData.CROWN)
	if ready.size() < Lords.ARMY_MIN_MEMBERS:
		return {"ok": false, "reason": "You need %d lords ready to ride (%d are)." % [Lords.ARMY_MIN_MEMBERS, ready.size()]}
	return {"ok": true, "reason": ""}


func call_to_arms(target: String) -> bool:
	if not call_check(target)["ok"]:
		return false
	if not MarshalArmies.create(world, WorldData.CROWN, target):
		return false
	_note("Your lords gather at %s to march on %s. Ride with them from the army's sheet." % [
		WorldData.settlement(world.capital_of(WorldData.CROWN))["name"], WorldData.settlement(target)["name"]])
	save_game()
	return true


func war_check(realm: String) -> Dictionary:
	if not is_crowned() or not world.realms.has(realm) or realm == WorldData.CROWN:
		return {"ok": false, "reason": ""}
	if world.at_war(WorldData.CROWN, realm):
		return {"ok": false, "reason": "Already at war."}
	if world.allied_with_crown(realm):
		return {"ok": false, "reason": "They're your allies."}
	if world.has_truce(WorldData.CROWN, realm):
		return {"ok": false, "reason": "A truce holds for %d more days." % ceili((world.truce_until(WorldData.CROWN, realm) - world.hour) / 24.0)}
	return {"ok": true, "reason": ""}


func declare_crown_war(realm: String) -> bool:
	if not war_check(realm)["ok"]:
		return false
	world.declare_war(WorldData.CROWN, realm, false, "your crown's declaration")
	add_realm_relation(realm, DECLARE_RELATION)
	_note("Your crown declares war on %s." % WorldData.FACTIONS[realm]["name"])
	save_game()
	return true


# ---------------------------------------------------------------- deeds

func _count_deed(id: String) -> void:
	deed_counts[id] = int(deed_counts.get(id, 0)) + 1


## Award the deeds newly reached: a note, a chronicle entry, and a name to carry.
func _award_deeds() -> void:
	for id in Achievements.check(self):
		var d: Dictionary = Achievements.DEEDS[id]
		_note("A deed to remember: the company is now known as %s." % d["title"])
		if world != null:
			world.emit_event({"type": "achievement", "title": String(d["title"]), "text": String(d["goal"])})


## Carry a name the company has earned, or none ("").
func set_company_title(id: String) -> bool:
	if id == "":
		company_title = ""
		return true
	if not deeds.has(id):
		return false
	company_title = id
	return true


# ---------------------------------------------------------------- sieges

## The realm the company fights for: its employer under contract, or its liege as a
## landed vassal. "" for a free company.
func siege_realm() -> String:
	if is_crowned():
		return WorldData.CROWN
	if has_contract():
		return contract_realm()
	if has_fief():
		return fief_realm()
	return ""


## Whether the company can storm the walls of `id` now. {ok, reason, realm, kind, men}.
func siege_check(id: String) -> Dictionary:
	var out := {"ok": false, "reason": "", "realm": "", "kind": "", "men": 0}
	if world == null or not WorldData.SETTLEMENTS.has(id):
		return out
	var kind := String(WorldData.settlement(id)["type"])
	out["kind"] = kind
	if not Lords.WALLS.has(kind):
		out["reason"] = "Only castles and towns have walls to storm."
		return out
	var realm := siege_realm()
	out["realm"] = realm
	var owner: String = world.owner_of(id)
	if realm == "":
		out["reason"] = "A free company takes no walls. Serve a realm at war first."
		return out
	if owner == realm or not world.at_war(realm, owner):
		out["reason"] = "Your realm is not at war with its holder."
		return out
	if world.here() != id:
		out["reason"] = "Ride to its walls first."
		return out
	if total_men() == 0:
		out["reason"] = "You have no men to lead."
		return out
	out["men"] = world.men_of(world.garrisons.get(id, []))
	out["ok"] = true
	return out


## Set up the assault on `id` for the battle screen.
func start_siege_battle(id: String) -> void:
	var check := siege_check(id)
	if not check["ok"]:
		return
	var owner: String = world.owner_of(id)
	pending_battle = {
		"enemy": WorldSim.clean_army(world.garrisons.get(id, [])), "culture": WorldData.culture_of(owner),
		"temperament": "", "name": "The garrison of %s" % WorldData.settlement(id)["name"],
		"party_id": -1, "site": null, "objective": "siege", "siege_target": id,
		"siege_kind": check["kind"], "siege_realm": check["realm"], "enemy_faction": owner, "allies": siege_allies(id),
	}


## Friendly lords standing at `id`'s walls, ready to join an assault on it: their squads,
## marked as allies with their lord, so losses go home to them.
func siege_allies(id: String) -> Array:
	var out := []
	if world == null:
		return out
	for lp in world.lord_parties():
		if lp.node != id or lp.moving() or world.relation_to_player(lp.faction) != "friendly":
			continue
		if not world.at_war(lp.faction, world.owner_of(id)):
			continue
		for sq in lp.army:
			if int(sq.get("men", 0)) > 0:
				var entry: Dictionary = WorldSim.clean_army([sq])[0]
				entry["is_ally"] = true
				entry["lord_id"] = lp.lord
				entry["culture"] = WorldData.culture_of(lp.faction)
				out.append(entry)
	return out


## Storm the walls without leading the men: settled at once, with the walls counted.
func auto_resolve_siege(id: String) -> Dictionary:
	start_siege_battle(id)
	if pending_battle.is_empty():
		return {}
	if pending_battle["enemy"].is_empty():
		var empty := {"won": true, "lost": 0, "killed": 0, "squads": {}, "enemy_squads": {}, "objective": "siege"}
		apply_result(empty)
		return empty
	var fighters := army.filter(func(sq): return int(sq["men"]) > 0)
	fighters.append_array(pending_battle.get("allies", []))
	var result := AutoResolve.resolve(fighters, pending_battle["enemy"], rng, false, null, "rout",
		float(Lords.WALLS[String(pending_battle["siege_kind"])]))
	result["objective"] = "siege"
	apply_result(result)
	return result


## The army an assault call is about, or {}.
func _assault_army() -> Dictionary:
	if world == null or world.pending_assault.is_empty():
		return {}
	for a in world.campaign_armies:
		if int(a["id"]) == int(world.pending_assault["army"]):
			return a
	return {}


## Answer the call to an assault. `fight` sets up the battle for the battle screen;
## otherwise it is settled as before (riding along, or leaving the walls to the garrison).
func answer_assault(fight: bool) -> void:
	var army := _assault_army()
	if army.is_empty():
		if world != null:
			world.pending_assault = {}
		return
	if not fight:
		army["player_answered"] = true
		world.pending_assault = {}
		return
	var role := String(world.pending_assault["role"])
	var target := String(world.pending_assault["target"])
	var lords_squads: Array = []
	for member in MarshalArmies.members(world, army):
		for sq in member.army:
			if int(sq.get("men", 0)) > 0:
				var entry: Dictionary = WorldSim.clean_army([sq])[0]
				entry["lord_id"] = member.lord
				entry["culture"] = WorldData.culture_of(member.faction)
				lords_squads.append(entry)
	var garrison: Array = WorldSim.clean_army(world.garrisons.get(target, []))
	var kind := String(WorldData.settlement(target)["type"])
	var owner: String = world.owner_of(target)
	pending_battle = {"objective": "siege", "siege_target": target, "siege_kind": kind, "site": null,
		"temperament": "", "party_id": -1, "assault_army": int(army["id"])}
	if role == "lead":
		for e in lords_squads:
			e["is_ally"] = true
		pending_battle.merge({"enemy": garrison, "allies": lords_squads, "culture": WorldData.culture_of(owner),
			"name": "The garrison of %s" % WorldData.settlement(target)["name"], "siege_realm": String(army["realm"]),
			"enemy_faction": owner})
	else:
		for e in garrison:
			e["is_ally"] = true
			e["garrison"] = true
		pending_battle.merge({"enemy": lords_squads, "allies": garrison, "culture": WorldData.culture_of(String(army["realm"])),
			"name": "The army of %s" % WorldData.FACTIONS[army["realm"]]["name"], "siege_defend": true,
			"siege_realm": owner, "enemy_faction": String(army["realm"])})


## A siege battle fought beside (or against) a marshal army.
func _army_assault_outcome(result: Dictionary, how: String) -> void:
	var army := _assault_army()
	var target := String(pending_battle.get("siege_target", ""))
	var place: String = WorldData.settlement(target)["name"]
	world.pending_assault = {}
	var won := bool(result.get("won", false))
	var defend := bool(pending_battle.get("siege_defend", false))
	var ours: Dictionary = result.get("squads", {})
	var theirs: Dictionary = result.get("enemy_squads", {})
	# Garrison survivors: on our side when defending, the enemy's when storming.
	var garrison_left: Dictionary = ours if defend else theirs
	var garrison: Array = world.garrisons.get(target, [])
	for sq in garrison:
		var after = garrison_left.get(int(sq["id"]))
		if after != null:
			sq["men"] = int(after.get("men", sq["men"]))
	world.garrisons[target] = garrison.filter(func(sq): return int(sq["men"]) > 0)
	# The army's survivors.
	if not army.is_empty():
		var army_left: Dictionary = theirs if defend else ours
		for member in MarshalArmies.members(world, army):
			for sq in member.army:
				var after = army_left.get(int(sq["id"]))
				if after != null:
					sq["men"] = int(after.get("men", sq["men"]))
			member.army = member.army.filter(func(sq): return int(sq["men"]) > 0)
			var l: Dictionary = world.lord_of(member)
			if not l.is_empty():
				l["army"] = member.army
	var army_won := won != defend
	if not army.is_empty():
		army["player_answered"] = true
		if army_won:
			MarshalArmies.capture_settlement(world, army, "assault")
		else:
			world.emit_event({"type": "siege_repulsed", "army": army["id"], "target": target})
			MarshalArmies.return_home(world, army, "Assault repulsed")
	if won:
		var got := Economy.spoils(int(result.get("killed", 0)))
		got["renown"] = int(got["renown"]) + 20
		silver += int(got["silver"])
		food += int(got["food"])
		renown += int(got["renown"])
		if defend:
			world.emit_event({"type": "fief_defended", "settlement": target, "enemy": String(pending_battle.get("name", "the besiegers"))})
			_note("You held the walls of %s! %s The besiegers fall back. +%d silver, +%d renown." % [place, how, got["silver"], got["renown"]])
		else:
			add_realm_relation(String(pending_battle.get("siege_realm", "")), 15)
			_note("%s falls to the assault you led! %s +%d silver, +%d renown." % [place, how, got["silver"], got["renown"]])
	else:
		if defend:
			_note("%s fell. %s The besiegers hold the walls now." % [place, how])
		else:
			_note("The assault on %s failed. %s The army falls back." % [place, how])


func _siege_outcome(result: Dictionary, how: String) -> void:
	if pending_battle.has("assault_army"):
		_army_assault_outcome(result, how)
		return
	var id := String(pending_battle.get("siege_target", ""))
	var realm := String(pending_battle.get("siege_realm", ""))
	if id == "" or not WorldData.SETTLEMENTS.has(id):
		return
	var place: String = WorldData.settlement(id)["name"]
	var was: String = world.owner_of(id)
	if result.get("won", false):
		world.garrisons[id] = []
		if realm != "" and world.at_war(realm, was):
			world.set_owner(id, realm)
			world.emit_event({"type": "captured", "realm": realm, "settlement": id, "from": was})
		var got := Economy.spoils(int(result.get("killed", 0)))
		got["silver"] = int(got["silver"]) + 200
		got["renown"] = int(got["renown"]) + 30
		silver += int(got["silver"])
		food += int(got["food"])
		renown += int(got["renown"])
		add_realm_relation(realm, 15)
		add_realm_relation(was, -20)
		_note("%s falls to your assault! %s Claimed %d silver and %d renown; %s now flies the banner of %s." % [
			place, how, got["silver"], got["renown"], place, WorldData.FACTIONS[realm]["name"] if WorldData.FACTIONS.has(realm) else realm])
	else:
		# What's left of the garrison stays on the walls.
		var left: Dictionary = result.get("enemy_squads", {})
		var garrison: Array = world.garrisons.get(id, [])
		for sq in garrison:
			var after = left.get(int(sq["id"]))
			if after != null:
				sq["men"] = int(after.get("men", sq["men"]))
		world.garrisons[id] = garrison.filter(func(sq): return int(sq["men"]) > 0)
		_note("The assault on %s failed. %s The survivors fall back from the walls." % [place, how])


# ---------------------------------------------------------------- raids

## Who stands for the village `id` when you raid it: its militia, and any squads
## stationed there.
func raid_defenders(id: String) -> Array:
	var out: Array = WorldSim.clean_army(world.village_militia(id))
	out.append_array(WorldSim.clean_army(world.garrisons.get(id, [])))
	return out


## Whether the company can raid the village `id` now: {ok, reason, men, stand}. `stand`
## says whether its defenders fight: always when soldiers are stationed there, otherwise
## unless your warband outnumbers them RAID_SCATTER_RATIO to one.
func raid_check(id: String) -> Dictionary:
	var out := {"ok": false, "reason": "", "men": 0, "stand": false}
	if world == null or not WorldData.SETTLEMENTS.has(id):
		return out
	if not WorldData.is_village(id):
		out["reason"] = "Only villages can be raided; walls have to be stormed."
		return out
	var owner: String = world.owner_of(id)
	if owner == WorldData.BANDITS or not is_at_war_with(owner):
		out["reason"] = "You are not at war with its realm."
		return out
	if world.is_burned(id):
		out["reason"] = "It has already been burned."
		return out
	if world.here() != id:
		out["reason"] = "Ride there first."
		return out
	if total_men() == 0:
		out["reason"] = "You have no men to lead."
		return out
	out["men"] = world.men_of(raid_defenders(id))
	out["stand"] = not (world.garrisons.get(id, []) as Array).is_empty() \
		or float(total_men()) < float(out["men"]) * Lords.RAID_SCATTER_RATIO
	out["ok"] = true
	return out


## Raid `id` when its militia scatter: it burns now, and your men stay to load the carts.
## Returns what was taken (see _pillage), or {} if it can't be done without a fight.
func raid_village(id: String) -> Dictionary:
	var check := raid_check(id)
	if not check["ok"] or bool(check["stand"]):
		return {}
	var got := _pillage(id)
	var place: String = WorldData.settlement(id)["name"]
	_note("The militia of %s scatter before your warband. %s" % [place, String(got["text"])])
	save_game()
	return got


## Set up the fight with `id`'s militia for the battle screen, fought among its houses.
func start_raid_battle(id: String) -> void:
	var check := raid_check(id)
	if not check["ok"]:
		return
	var owner: String = world.owner_of(id)
	var site := BattleSite.pick(world, world.party_pos(world.player()), "village", hash([id, int(world.hour)]) & 0x7fffffff)
	site["biome"] = String(WorldData.settlement(id)["faction"])
	pending_battle = {
		"enemy": raid_defenders(id), "culture": WorldData.culture_of(owner), "temperament": Commander.PATIENT,
		"name": "The militia of %s" % WorldData.settlement(id)["name"], "party_id": -1, "site": site,
		"objective": "raid", "raid_target": id, "enemy_faction": owner, "allies": [],
	}


## Fight the militia without leading the men: settled at once.
func auto_resolve_raid(id: String) -> Dictionary:
	start_raid_battle(id)
	if pending_battle.is_empty():
		return {}
	var fighters := army.filter(func(sq): return int(sq["men"]) > 0)
	var result := AutoResolve.resolve(fighters, pending_battle["enemy"], rng, false, null, "rout")
	result["objective"] = "raid"
	apply_result(result)
	return result


## After the fight for a village you came to raid: it burns if the militia broke.
func _raid_outcome(result: Dictionary, how: String) -> void:
	var id := String(pending_battle.get("raid_target", ""))
	if id == "" or not WorldData.SETTLEMENTS.has(id):
		return
	var place: String = WorldData.settlement(id)["name"]
	if not bool(result.get("won", false)):
		_note("The militia of %s held their homes. %s Your men fall back from the village." % [place, how])
		return
	var spoils := Economy.spoils(int(result.get("killed", 0)))
	silver += int(spoils["silver"])
	food += int(spoils["food"])
	var got := _pillage(id)
	_note("The militia of %s broke. %s %s" % [place, how, String(got["text"])])


## Burn `id` and take what it has. The village pays nothing and offers no recruits for
## BURNED_DAYS, its realm grows wearier of the war and angrier with you, your sworn lords
## judge it by their bearing, and your men stay RAID_HOURS loading the carts while its
## lords ride to catch them. Returns {silver, food, text}.
func _pillage(id: String) -> Dictionary:
	var owner: String = world.owner_of(id)
	var place: String = WorldData.settlement(id)["name"]
	var got := {"silver": Lords.RAID_LOOT, "food": Lords.PLAYER_RAID_FOOD}
	if has_specialization(Captains.QUARTERMASTER):
		got["silver"] = int(round(got["silver"] * 1.15))
		got["food"] = int(round(got["food"] * 1.15))
	silver += int(got["silver"])
	food += int(got["food"])
	world.burned[id] = world.hour + Lords.BURNED_DAYS * 24.0
	world.offers.erase(id)
	if world.realms.has(owner):
		world.add_weariness(owner, Politics.WEARINESS_LOST_VILLAGE)
	add_realm_relation(owner, Lords.PLAYER_RAID_REALM)
	world.emit_event({"type": "burned", "village": id, "by": "your company"})
	var liked := []
	var shamed := []
	for l in crown_lords():
		match String(l.get("bearing", "")):
			Lords.CRUEL:
				LordTalk.change_regard(self, l, Lords.RAID_CRUEL_REGARD)
				liked.append(LordTalk.short_name(l))
			Lords.HONORABLE:
				LordTalk.change_regard(self, l, Lords.RAID_HONORABLE_REGARD)
				shamed.append(LordTalk.short_name(l))
	var text := "%s burns. Your men carry off %d silver and %d rations; they need %d hours to load the carts." % [
		place, int(got["silver"]), int(got["food"]), int(Lords.RAID_HOURS)]
	if not shamed.is_empty():
		text += " %s won't forget it (%d Regard)." % [", ".join(shamed), Lords.RAID_HONORABLE_REGARD]
	if not liked.is_empty():
		text += " %s approve%s (+%d Regard)." % [", ".join(liked), "s" if liked.size() == 1 else "", Lords.RAID_CRUEL_REGARD]
	got["text"] = text
	got["liked"] = liked
	got["shamed"] = shamed
	world.player_raid = {"village": id, "until": world.hour + Lords.RAID_HOURS}
	world.wait(Lords.RAID_HOURS)
	_count_deed("raids")
	return got


# ---------------------------------------------------------------- journal

## Remember how a commitment ended, so the journal can explain it after the notice is gone.
func _end_commitment(id: String, title: String, outcome: String) -> void:
	var at: float = world.hour if world != null else 0.0
	ended_commitments.push_front({"id": id, "title": title, "outcome": outcome, "hour": at})
	if ended_commitments.size() > ENDED_KEEP:
		ended_commitments.resize(ENDED_KEEP)
	if pinned_commitment == id:
		pinned_commitment = ""


## Where a hunted band is now: the settlement it stands at or rides toward, or "".
func _band_place(party_id: int) -> String:
	var p = world.party(party_id) if world != null and party_id >= 0 else null
	if p == null:
		return ""
	return String(p.next) if p.moving() and String(p.next) != "" else String(p.node)


static func _settlement_name(id: String) -> String:
	return String(WorldData.settlement(id)["name"]) if WorldData.SETTLEMENTS.has(id) else id


## Everything the company has promised to do, newest duties first. Each entry:
## id, kind, title, objective, place (a settlement to show on the map, or ""), reward, cost,
## hours_left (-1 when there's no deadline) and blocked (why it can't be done yet, or "").
## Reading this changes nothing.
func commitments() -> Array:
	var out: Array = []
	if world == null:
		return out
	for job in active_jobs:
		var hours_left := maxf(0.0, float(job.get("deadline", world.hour)) - world.hour)
		var reward := "%d silver, %d renown" % [int(job.get("reward_silver", 0)), int(job.get("reward_renown", 0))]
		var entry := {"id": String(job.get("id", "")), "kind": "job", "title": String(job.get("title", "Job")),
			"objective": String(job.get("description", "")), "place": "", "reward": reward, "cost": "",
			"hours_left": hours_left, "blocked": ""}
		var origin := String(job.get("origin_settlement", ""))
		match String(job.get("type", "")):
			Jobs.TYPE_COURIER:
				entry["place"] = String(job.get("destination_settlement", ""))
				entry["objective"] = "Carry the dispatch to %s." % _settlement_name(entry["place"])
			Jobs.TYPE_RELIEF:
				var need := int(job.get("food_needed", 0))
				entry["place"] = origin
				entry["objective"] = "Bring %d rations to %s." % [need, _settlement_name(origin)]
				entry["cost"] = "%d rations" % need
				if food < need:
					entry["blocked"] = "You carry %d rations; buy %d more first." % [food, need - food]
			Jobs.TYPE_HUNT:
				var target := String(job.get("target_name", "the band"))
				if String(job.get("status", "")) == "ready_to_claim":
					entry["place"] = origin
					entry["objective"] = "%s is scattered. Claim the bounty at %s." % [target, _settlement_name(origin)]
				else:
					entry["place"] = _band_place(int(job.get("target_party_id", -1)))
					entry["objective"] = "Hunt down %s%s." % [target,
						(", last seen near %s" % _settlement_name(entry["place"])) if entry["place"] != "" else ""]
		out.append(entry)
	if has_contract():
		var realm := contract_realm()
		var realm_name: String = WorldData.FACTIONS[realm]["name"] if WorldData.FACTIONS.has(realm) else realm
		var enemies: PackedStringArray = []
		for f in WorldData.FACTIONS:
			if f != WorldData.BANDITS and f != realm and world.at_war(realm, f):
				enemies.append(String(WorldData.FACTIONS[f]["name"]))
		out.append({"id": "contract", "kind": "contract", "title": "Contract with %s" % realm_name,
			"objective": ("Fight %s's enemies: %s." % [realm_name, ", ".join(enemies)]) if not enemies.is_empty()
				else "%s is at peace; the pay still comes." % realm_name,
			"place": world.capital_of(realm),
			"reward": "%d silver a day, +%d silver for each enemy lord delivered" % [contract_daily_pay(), int(contract.get("bonus_per_lord", 0))],
			"cost": "Breaking it early costs standing", "hours_left": float(int(contract.get("days_left", 0))) * 24.0, "blocked": ""})
	for l in captive_lords():
		out.append({"id": "captive_%d" % int(l.get("id", -1)), "kind": "captive", "title": "Captive: %s" % String(l.get("name", "a lord")),
			"objective": "Hold them until their realm's envoy offers ransom, then decide their fate.", "place": "",
			"reward": "%d silver ransom" % int(l.get("ransom_amount", Lords.ransom_for(int(l.get("renown", 0))))),
			"cost": "", "hours_left": -1.0, "blocked": ""})
	var wed := wedding_commitment()
	if not wed.is_empty():
		out.append(wed)
	out.append_array(gathering_commitments())
	out.append_array(CrownCourt.commitments(self))
	if has_fief():
		var f_id := fief_id()
		var lines: PackedStringArray = []
		if world.is_burned(f_id):
			lines.append("It was raided; rebuild it.")
		var taxes := int(player_fief.get("silver", 0))
		if taxes > 0:
			lines.append("%d silver in taxes waits to be collected." % taxes)
		if lines.is_empty():
			lines.append("Keep it safe and its people fed.")
		out.append({"id": "fief", "kind": "fief", "title": "Your fief: %s" % _settlement_name(f_id),
			"objective": " ".join(lines), "place": f_id, "reward": "Taxes and food each day", "cost": "",
			"hours_left": -1.0, "blocked": ""})
	return out


## The commitment pinned to the map card, or {} when none is (or it has ended).
func pinned() -> Dictionary:
	var all := commitments()
	for c in all:
		if c["id"] == pinned_commitment:
			return c
	return {}


func pin_commitment(id: String) -> void:
	pinned_commitment = "" if pinned_commitment == id else id


# ---------------------------------------------------------------- fiefdom & vassalage

func has_fief() -> bool:
	return not player_fief.is_empty() and String(player_fief.get("settlement_id", "")) != ""


func fief_id() -> String:
	return String(player_fief.get("settlement_id", ""))


func is_player_fief(settlement_id: String) -> bool:
	return has_fief() and fief_id() == settlement_id


func fief_realm() -> String:
	return String(player_fief.get("realm", ""))


func can_petition_fief(realm: String) -> bool:
	if has_fief() or world == null:
		return false
	if renown < Fiefs.MIN_RENOWN or relation_with_realm(realm) < Fiefs.MIN_RELATION:
		return false
	if is_at_war_with(realm):
		return false
	return not available_fiefs_for_grant(realm).is_empty()


func available_fiefs_for_grant(realm: String) -> Array:
	if world == null:
		return []
	var candidates := []
	for s_id in world.holdings_of(realm):
		var kind: String = String(WorldData.settlement(s_id).get("type", ""))
		if kind == WorldData.TOWN:
			continue
		var held_by_lord := false
		for l in world.lords:
			if String(l.get("fief", "")) == s_id and String(l.get("realm", "")) == realm:
				held_by_lord = true
				break
		if not held_by_lord:
			candidates.append(s_id)
	return candidates


func accept_fealty_and_fief(settlement_id: String, realm: String) -> bool:
	if not can_petition_fief(realm):
		return false
	var candidates := available_fiefs_for_grant(realm)
	if not candidates.has(settlement_id):
		return false

	if has_contract():
		contract = {}

	player_fief = {
		"settlement_id": settlement_id,
		"realm": realm,
		"silver": 0,
		"food": 20,
		"improvements": {
			Fiefs.IMPROVEMENT_GRANARY: false,
			Fiefs.IMPROVEMENT_FORTIFICATIONS: false,
			Fiefs.IMPROVEMENT_MILL: false,
		},
		"garrison": [],
		"granted_at": world.hour if world != null else 0.0,
		"lost": false,
	}

	if world != null:
		if world.player() != null:
			world.player().faction = realm
		world.garrisons[settlement_id] = []
		add_realm_relation(realm, 20)
		var s_name := String(WorldData.settlement(settlement_id)["name"])
		var r_name := String(WorldData.FACTIONS[realm]["name"])
		var cult := String(WorldData.FACTIONS[realm]["culture"])
		var title := Fiefs.title_for(cult)
		_note("Swore fealty to the %s! Granted lordship of %s as %s of %s." % [
			r_name, s_name, title, s_name
		])
		world.emit_event({
			"type": "fief_granted",
			"company": "Your warband",
			"settlement": settlement_id,
			"realm": realm,
		})

	save_game()
	return true


func renounce_fief() -> void:
	if not has_fief():
		return
	var s_name := String(WorldData.settlement(fief_id())["name"])
	var r := fief_realm()
	player_fief = {}
	if world != null and world.player() != null:
		world.player().faction = ""
	add_realm_relation(r, -25)
	_note("You renounced your fealty to the %s, forfeiting %s." % [
		WorldData.FACTIONS.get(r, {}).get("name", "crown"), s_name
	])
	save_game()


func _fief_day() -> void:
	if not has_fief() or world == null:
		return
	if bool(player_fief.get("lost", false)):
		return
	var is_b: bool = bool(world.is_burned(fief_id()))
	var tax := Fiefs.daily_tax(player_fief, is_b)
	var prov := Fiefs.daily_food(player_fief, is_b)
	player_fief["silver"] = mini(Fiefs.MAX_STORAGE_SILVER, int(player_fief.get("silver", 0)) + tax)
	player_fief["food"] = mini(Fiefs.max_food_capacity(player_fief), int(player_fief.get("food", 0)) + prov)

	var g: Array = player_fief.get("garrison", [])
	for sq in g:
		var w: int = int(sq.get("wounded", 0))
		if w > 0:
			sq["wounded"] = w - 1
			sq["men"] = int(sq["men"]) + 1


func collect_fief_taxes() -> int:
	if not has_fief():
		return 0
	var collected := int(player_fief.get("silver", 0))
	player_fief["silver"] = 0
	silver += collected
	_note("Collected %d silver from estate taxes at %s." % [collected, WorldData.settlement(fief_id())["name"]])
	save_game()
	return collected


func collect_fief_food(amount: int = -1) -> int:
	if not has_fief():
		return 0
	var available := int(player_fief.get("food", 0))
	var take := available if amount <= 0 else mini(amount, available)
	player_fief["food"] = available - take
	food += take
	_note("Collected %d food rations from estate granaries at %s." % [take, WorldData.settlement(fief_id())["name"]])
	save_game()
	return take


func station_squad_in_fief(squad_id: int) -> bool:
	if not has_fief() or world == null:
		return false
	var s_idx := -1
	for i in army.size():
		if int(army[i]["id"]) == squad_id:
			s_idx = i
			break
	if s_idx == -1 or army.size() <= 1:
		return false
	var squad: Dictionary = army[s_idx]
	army.remove_at(s_idx)
	if not player_fief.has("garrison"):
		player_fief["garrison"] = []
	player_fief["garrison"].append(squad)
	world.garrisons[fief_id()] = player_fief["garrison"]
	_note("Stationed %s in the garrison of %s." % [String(squad.get("name", "Squad")), WorldData.settlement(fief_id())["name"]])
	save_game()
	return true


func withdraw_squad_from_fief(garrison_index: int) -> bool:
	if not has_fief() or world == null:
		return false
	var g: Array = player_fief.get("garrison", [])
	if garrison_index < 0 or garrison_index >= g.size():
		return false
	if army.size() >= squad_cap():
		return false
	var squad: Dictionary = g[garrison_index]
	g.remove_at(garrison_index)
	army.append(squad)
	world.garrisons[fief_id()] = g
	_note("Withdrew %s from the garrison into the active warband." % String(squad.get("name", "Squad")))
	save_game()
	return true


func build_fief_improvement(improvement_key: String) -> Dictionary:
	if not has_fief() or not Fiefs.IMPROVEMENTS.has(improvement_key):
		return {"ok": false, "reason": "Invalid improvement"}
	var imp: Dictionary = Fiefs.IMPROVEMENTS[improvement_key]
	var cost := int(imp["cost"])
	if silver < cost:
		return {"ok": false, "reason": "Insufficient silver (%d needed)" % cost}
	var imps: Dictionary = player_fief.get("improvements", {})
	if bool(imps.get(improvement_key, false)):
		return {"ok": false, "reason": "Already constructed"}
	silver -= cost
	imps[improvement_key] = true
	player_fief["improvements"] = imps
	_note("Constructed %s at %s (%d silver)." % [imp["name"], WorldData.settlement(fief_id())["name"], cost])
	save_game()
	return {"ok": true}


func repair_fief() -> Dictionary:
	if not has_fief() or world == null or not world.is_burned(fief_id()):
		return {"ok": false, "reason": "Fief is not damaged"}
	if silver < Fiefs.REPAIR_COST:
		return {"ok": false, "reason": "Insufficient silver (%d needed)" % Fiefs.REPAIR_COST}
	silver -= Fiefs.REPAIR_COST
	world.burned.erase(fief_id())
	_note("Repaired village and granaries at %s (%d silver)." % [WorldData.settlement(fief_id())["name"], Fiefs.REPAIR_COST])
	save_game()
	return {"ok": true}


func _on_fief_transferred(id: String, realm: String, was: String) -> void:
	if not is_player_fief(id):
		return
	var s_name := String(WorldData.settlement(id)["name"])
	if realm != fief_realm():
		var captor_name := String(WorldData.FACTIONS.get(realm, {}).get("name", "the enemy"))
		player_fief["lost"] = true
		_note("Catastrophe! Your fief of %s has fallen to the %s!" % [s_name, captor_name])
		world.emit_event({"type": "fief_lost", "company": "Your warband", "settlement": id, "by": captor_name})
	elif bool(player_fief.get("lost", false)):
		player_fief["lost"] = false
		_note("Rejoice! Your fief of %s has been liberated and returned to your governance!" % s_name)
	save_game()


func _on_fief_burned(raider: String) -> void:
	if not has_fief():
		return
	var cur_silver := int(player_fief.get("silver", 0))
	player_fief["silver"] = int(cur_silver * 0.5)
	var s_name := String(WorldData.settlement(fief_id())["name"])
	_note("Disaster! Raiders led by %s burned your fief of %s and looted the estate treasury!" % [raider, s_name])
	save_game()


func squad_by_id(id: int) -> Dictionary:
	for s in army:
		if int(s["id"]) == id:
			return s
	return {}


# ---------------------------------------------------------------- economy

func squad_cap() -> int:
	return Economy.squad_cap(renown)


## Fresh men and drill masters are found in towns. Before a campaign starts there's no
## map, and the warband can always refill.
func in_town() -> bool:
	return world == null or world.player_in_town()


## Silver a day for the whole warband.
func daily_wages() -> int:
	var total := 0.0
	for s in army:
		total += Economy.daily_wage(s)
	return int(ceil(total))


## Days the food lasts at one ration per man.
func food_days() -> int:
	var head := total_headcount()
	if head <= 0:
		return 999
	var daily_food := head
	if has_specialization(Captains.QUARTERMASTER):
		daily_food = maxi(1, int(ceil(head * 0.8)))
	return food / daily_food


# ---------------------------------------------------------------- guidance

## One honest next step from the current campaign state. This points at existing
## systems and places; it does not create a quest or promise an unavailable siege.
func recommendation() -> Dictionary:
	if world == null:
		return {"title": "Form your company", "body": "Choose a people and begin a campaign.", "action": "home", "place": ""}
	if food_days() < 2:
		var village := _nearest_settlement([WorldData.VILLAGE])
		return {"title": "Buy provisions", "body": "Only %d days of food remain. Villages sell the cheapest supplies." % food_days(),
			"action": "place", "place": village}
	var ready := army.filter(func(s): return can_train(s))
	if not ready.is_empty():
		var town := _nearest_settlement([WorldData.TOWN])
		return {"title": "Training is ready", "body": "%d %s earned a new level. Town drillmasters can promote them." % [ready.size(),
			"company has" if ready.size() == 1 else "companies have"], "action": "place", "place": town}
	for job in active_jobs:
		match String(job.get("type", "")):
			Jobs.TYPE_COURIER:
				var dest_id: String = String(job.get("destination_settlement", ""))
				if dest_id != "":
					var dest_name: String = String(WorldData.settlement(dest_id)["name"])
					var hrs_left: float = maxf(0.0, float(job.get("deadline", 0.0)) - world.hour)
					return {"title": "Courier dispatch", "body": "Deliver urgent dispatch to %s before deadline (%.0fh remaining)." % [
						dest_name, hrs_left], "action": "place", "place": dest_id}
			Jobs.TYPE_RELIEF:
				var orig_id: String = String(job.get("origin_settlement", ""))
				if orig_id != "" and food >= int(job.get("food_needed", 0)):
					var orig_name: String = String(WorldData.settlement(orig_id)["name"])
					return {"title": "Deliver provisions", "body": "Return to %s with %d food rations to complete village relief." % [
						orig_name, int(job.get("food_needed", 0))], "action": "place", "place": orig_id}
			Jobs.TYPE_HUNT:
				var p_id: int = int(job.get("target_party_id", -1))
				var p = world.party(p_id) if p_id >= 0 else null
				if p != null:
					var hrs_left: float = maxf(0.0, float(job.get("deadline", 0.0)) - world.hour)
					return {"title": "Bounty hunt", "body": "Hunt down %s near %s before deadline (%.0fh remaining)." % [
						job.get("target_name", "the marauders"), String(WorldData.settlement(job.get("origin_settlement", ""))["name"]),
						hrs_left], "action": "map", "place": ""}
	if has_fief():
		var f_id := fief_id()
		if world.is_burned(f_id):
			return {"title": "Fief in ruins", "body": "%s was raided and damaged. Return home to reconstruct it." % WorldData.settlement(f_id)["name"],
				"action": "place", "place": f_id}
		var uncollected_tax := int(player_fief.get("silver", 0))
		if uncollected_tax >= 150:
			return {"title": "Collect estate taxes", "body": "%d silver in estate taxes waits at %s." % [uncollected_tax, WorldData.settlement(f_id)["name"]],
				"action": "place", "place": f_id}
	var close_bond := _closest_bond_goal()
	if not close_bond.is_empty():
		return {"title": "A bond is taking shape", "body": "%s are %.1f points from rank %s. Fighting beside one another strengthens it." % [
			close_bond["pair"], close_bond["remaining"], close_bond["rank"]], "action": "warband", "place": ""}
	if army.size() < squad_cap():
		var recruits := _nearest_settlement_with_recruits()
		if recruits != "":
			return {"title": "Room for another company", "body": "Your renown supports %d more %s, and recruits are waiting nearby." % [
				squad_cap() - army.size(), "company" if squad_cap() - army.size() == 1 else "companies"], "action": "place", "place": recruits}
	if is_wounded():
		var town := _nearest_settlement([WorldData.TOWN])
		return {"title": "Rebuild the ranks", "body": "Some companies are below full strength. A town can reinforce them.",
			"action": "place", "place": town}
	if not world.activity_log.is_empty():
		var latest: Dictionary = world.activity_log[0]
		var place := String(latest.get("place", ""))
		if WorldData.SETTLEMENTS.has(place):
			return {"title": "News from the road", "body": String(latest["text"]), "action": "place", "place": place}
	return {"title": "Build your name", "body": "Patrol the roads, protect villages and seek battles to earn silver and renown.",
		"action": "map", "place": ""}


func _nearest_settlement(kinds: Array) -> String:
	var best := ""
	var best_hours := INF
	for id in WorldData.SETTLEMENTS:
		if not kinds.has(String(WorldData.settlement(id)["type"])):
			continue
		var hours: float = world.hours_to(id)
		if hours < best_hours:
			best_hours = hours
			best = id
	return best


func _nearest_settlement_with_recruits() -> String:
	var best := ""
	var best_hours := INF
	for id in WorldData.SETTLEMENTS:
		if world.offers_at(id).is_empty():
			continue
		var hours: float = world.hours_to(id)
		if hours < best_hours:
			best_hours = hours
			best = id
	return best


func _closest_bond_goal() -> Dictionary:
	var best := {}
	for i in army.size():
		var a = army[i].get("captain")
		if a == null:
			continue
		for j in range(i + 1, army.size()):
			var b = army[j].get("captain")
			if b == null:
				continue
			var points := float(a.get("bonds", {}).get(str(b["id"]), 0.0))
			var rank := Captains.rank_for(points)
			if rank >= Captains.RANKS.size() - 1:
				continue
			var remaining: float = Captains.RANK_POINTS[rank + 1] - points
			if remaining <= 3.0 and (best.is_empty() or remaining < float(best["remaining"])):
				best = {"pair": "%s & %s" % [a["first"], b["first"]], "remaining": remaining,
					"rank": Captains.RANKS[rank + 1]}
	return best


## Silver to bring one squad back to full strength.
func reinforce_cost(squad: Dictionary) -> int:
	var unit_id: String = squad.get("unit", "")
	var full := Units.full_size(unit_id) if Units.has(unit_id) else Troops.full_size(squad["type"])
	return Economy.recruit_cost(unit_id if unit_id != "" else squad["type"], full - int(squad["men"]))


## Refill one squad with fresh recruits, in a town, if you can pay. Fresh men water down
## the squad's experience toward its next level, but never undo training it has paid for.
func reinforce_squad(id: int) -> bool:
	var s := squad_by_id(id)
	if s.is_empty() or not in_town():
		return false
	var unit_id: String = s.get("unit", "")
	var full := Units.full_size(unit_id) if Units.has(unit_id) else Troops.full_size(s["type"])
	var cost := reinforce_cost(s)
	if cost <= 0 or cost > silver:
		return false
	silver -= cost
	var dilution_ratio := float(s["men"]) / float(full)
	if has_specialization(Captains.DRILLMASTER):
		dilution_ratio = 1.0 - (1.0 - dilution_ratio) * 0.5
	s["xp"] = int(int(s["xp"]) * dilution_ratio)
	s["men"] = full
	s["wounded"] = 0
	save_game()
	return true


## Refill every squad you can afford, in roster order, spending no more than `budget`
## (all your silver if it's negative). Returns the silver spent.
func reinforce(budget: int = -1) -> int:
	var cap := silver if budget < 0 else mini(budget, silver)
	var spent := 0
	for s in army:
		var cost := reinforce_cost(s)
		if cost > 0 and spent + cost <= cap and reinforce_squad(int(s["id"])):
			spent += cost
	return spent


## True if a squad has the experience for its next level and isn't at the top, or has a pending branch choice.
func can_train(squad: Dictionary) -> bool:
	if squad.get("pending_branch", false):
		return true
	var level := int(squad.get("level", 1))
	return level < Troops.MAX_LEVEL and Troops.level_for(int(squad["xp"])) > level


## Train a squad up a level, in a town. When training to level 2, branch_unit_id picks the
## upgrade path; if left empty, defaults to the first branch. Pending branch upgrades are free.
func train_squad(id: int, branch_unit_id: String = "") -> bool:
	var s := squad_by_id(id)
	if s.is_empty() or not can_train(s) or not in_town():
		return false

	if s.get("pending_branch", false):
		var target := branch_unit_id
		if target == "":
			var branches := Units.branches(s.get("unit", ""))
			if not branches.is_empty():
				target = branches[0]
			else:
				target = s.get("unit", "")
		s["unit"] = target
		s["pending_branch"] = false
		_fit_to_unit(s)
		save_game()
		return true

	var current_level := int(s.get("level", 1))
	if current_level == 1:
		var target := branch_unit_id
		if target == "":
			var branches := Units.branches(s.get("unit", ""))
			if not branches.is_empty():
				target = branches[0]
			else:
				target = s.get("unit", "")
		var cost := Economy.train_cost(s, target)
		if cost > silver:
			return false
		silver -= cost
		s["unit"] = target
		s["level"] = 2
		_fit_to_unit(s)
	else:
		var cost := Economy.train_cost(s)
		if cost > silver:
			return false
		silver -= cost
		s["level"] = current_level + 1

	save_game()
	return true


## A squad trained into a smaller branch keeps its best men and sends the rest home.
func _fit_to_unit(s: Dictionary) -> void:
	if Units.has(String(s.get("unit", ""))):
		s["men"] = mini(int(s["men"]), Units.full_size(String(s["unit"])))


## Hire the recruits offered where you stand, offer number `index`. Fails if you can't
## pay or already lead as many squads as your renown allows.
func hire(place: String, index: int) -> bool:
	if world == null or world.here() != place or army.size() >= squad_cap():
		return false
	var offers: Array = world.offers_at(place)
	if index < 0 or index >= offers.size():
		return false
	var offer: Dictionary = offers[index]
	var unit_id := Units.recruit(String(offer["culture"]), String(offer["type"]))
	var full := Units.full_size(unit_id)
	var cost := Economy.recruit_cost(unit_id, full)
	if cost > silver:
		return false
	silver -= cost
	world.take_offer(place, index)
	army.append(_new_squad(String(offer["type"]), String(offer["culture"])))
	save_game()
	return true


## Buy `rations` of food at the settlement you're in.
func buy_food(rations: int) -> bool:
	if world == null or world.here() == "":
		return false
	var cost := food_cost(rations)
	if cost > silver or rations <= 0:
		return false
	silver -= cost
	food += rations
	save_game()
	return true


func food_cost(rations: int) -> int:
	var kind := String(WorldData.settlement(world.here())["type"]) if world != null and world.here() != "" else "town"
	return int(ceil(rations * float(Economy.FOOD_PRICE.get(kind, 0.3))))


func is_resting() -> bool:
	if world == null:
		return true
	var p = world.player()
	if p == null:
		return true
	return not p.moving() or p.wait > 0.0


func _tick_healing(hours: float) -> void:
	if hours <= 0.0 or total_wounded() == 0:
		if total_wounded() == 0:
			_heal_clock = 0.0
		return
	var speed_mult := 2.0 if is_resting() else 1.0
	_heal_clock += hours * speed_mult
	while _heal_clock >= 12.0:
		_heal_clock -= 12.0
		var step_healed := false
		for s in army:
			var w: int = int(s.get("wounded", 0))
			if w > 0:
				s["wounded"] = w - 1
				s["men"] = int(s["men"]) + 1
				step_healed = true
		if not step_healed:
			_heal_clock = 0.0
			break
	if total_wounded() == 0:
		_heal_clock = 0.0


## Let time pass on the map, then settle wages and food for every day that ended.
func advance(hours: float) -> void:
	if world != null:
		world.step(hours)
		drain_social_settlements()
		_check_job_deadlines()
		settle()
		_step_hosted()
		CrownCourt.step(self)
	_tick_healing(hours)


func drain_social_settlements() -> void:
	if world == null or world.social == null:
		return
	for item in world.social.drain_pending_settlements():
		match String(item.get("type", "")):
			"refund_silver":
				silver += int(item.get("amount", 0))
				_note("Refunded %d silver (%s)." % [int(item.get("amount", 0)), String(item.get("reason", ""))])
			"refund_food":
				food += int(item.get("amount", 0))
				_note("Refunded %d rations (%s)." % [int(item.get("amount", 0)), String(item.get("reason", ""))])


func _social_context() -> Dictionary:
	var sound = get_node_or_null("/root/Sound")
	var invitations := true
	if sound != null and sound.has_method("romance_invitations_enabled"):
		invitations = bool(sound.romance_invitations_enabled())
	return {
		"player_silver": silver,
		"player_food": food,
		"player_renown": renown,
		"current_hour": world.hour,
		"invitations_enabled": invitations
	}


## What a story decision would do, before it's made: {ok, reason, trust_change,
## standing_change, cost_silver, cost_food, new_status, requires_confirmation, ...}.
func preview_social_choice(candidate_id: String, choice_id: String) -> Dictionary:
	if world == null or world.social == null:
		return {"ok": false, "reason": "No world or social simulation active."}
	return world.social.preview_choice(candidate_id, choice_id, _social_context())


func apply_social_choice(candidate_id: String, choice_id: String) -> Dictionary:
	if world == null or world.social == null:
		return {"ok": false, "reason": "No world or social simulation active."}
	var context := _social_context()
	var prev: Dictionary = world.social.preview_choice(candidate_id, choice_id, context)
	if not prev["ok"]:
		return prev

	var c_silver := int(prev.get("cost_silver", 0))
	var c_food := int(prev.get("cost_food", 0))
	if silver < c_silver or food < c_food:
		return {"ok": false, "reason": "Insufficient resources."}
	silver -= c_silver
	food -= c_food

	var res: Dictionary = world.social.apply_choice(candidate_id, choice_id, context)
	save_game()
	return res


func sponsor_replacements(house_id: String, target_id: String, target_kind: String, amount: int) -> Dictionary:
	if world == null or world.social == null:
		return {"ok": false, "reason": "No world active."}
	if amount <= 0 or silver < amount:
		return {"ok": false, "reason": "Cannot afford %d silver contribution." % amount}
	silver -= amount
	var res: Dictionary = world.social.sponsor_replacements(house_id, target_id, target_kind, amount, world.hour, world.owner_of(target_id) if target_kind == "settlement" else "")
	save_game()
	return res


func request_household_grant(house_id: String) -> Dictionary:
	if world == null or world.social == null:
		return {"ok": false, "reason": "No world active."}
	var res: Dictionary = world.social.request_grant(house_id, world)
	if res.get("ok", false):
		silver += int(res.get("amount", 0))
		save_game()
	return res


## Pay wages and feed the men for each day that has ended since the last settling. Men
## who go unpaid or hungry desert. Leaves a note for the map when that happens.
func settle() -> void:
	if world == null:
		return
	var today := int(world.hour / 24.0)
	while _paid_day < today:
		_paid_day += 1
		_upkeep()
		_fief_day()
		_crown_day()
		_prune_gathering_log()
	_award_deeds()


## One day's wages and food. Whatever can't be paid or fed is a share of the men going
## without, and up to DESERTION of them leave: a short day costs a few men, an empty
## purse costs one man in ten.
func _upkeep() -> void:
	var head := total_headcount()
	if head == 0:
		return
	if has_contract():
		var pay := contract_daily_pay()
		silver += pay
		var realm := String(contract.get("realm", ""))
		contract["days_left"] = int(contract["days_left"]) - 1
		if int(contract["days_left"]) <= 0:
			_count_deed("contract")
			_end_commitment("contract", "Contract with %s" % (WorldData.FACTIONS[realm]["name"] if WorldData.FACTIONS.has(realm) else realm),
				"Served in full: the contract ended in good standing.")
			add_realm_relation(realm, 10)
			contract = {}
			if world != null and world.player() != null:
				world.player().faction = ""
			var r_name: String = WorldData.FACTIONS[realm]["name"] if WorldData.FACTIONS.has(realm) else realm
			_note("Your mercenary contract with %s has concluded in good standing." % r_name)
			if world != null:
				world.emit_event({"type": "contract_ended", "company": "Your warband", "realm": realm})
	var food_needed := head
	if has_specialization(Captains.QUARTERMASTER):
		food_needed = maxi(1, int(ceil(head * 0.8)))
	var eaten := mini(food, food_needed)
	food -= eaten
	var wages := daily_wages()
	var paid := mini(silver, wages)
	silver -= paid
	var hungry := 1.0 - float(eaten) / maxf(1.0, float(food_needed))
	var unpaid := 1.0 - float(paid) / maxf(1.0, wages)
	var desertion_rate := Economy.DESERTION
	if has_specialization(Captains.QUARTERMASTER):
		desertion_rate *= 0.5
	var share := desertion_rate * maxf(hungry, unpaid)
	if share <= 0.0:
		return
	var left := 0
	for s in army:
		var m := int(s["men"])
		var gone := mini(m - 1, int(round(m * share)))
		if gone > 0:
			s["men"] = m - gone
			left += gone
	if left == 0:
		return
	var why := "unpaid and hungry" if hungry > 0.0 and unpaid > 0.0 else ("unpaid" if unpaid > 0.0 else "hungry")
	var fix := ""
	if hungry > 0.0:
		fix += "Buy food in any settlement. "
	if unpaid > 0.0:
		fix += "Earn silver from bounties and spoils to pay the rest."
	var message := "End of day %d: %d men left the warband, %s. %s" % [_paid_day, left, why, fix.strip_edges()]
	desertion_warning = message if desertion_warning == "" else desertion_warning + "\n" + message
	_note(message)


func _note(text: String) -> void:
	map_notice = text if map_notice == "" else map_notice + "\n" + text


## A notice item to show grouped with others of its kind (see map_notice_items).
func _note_item(item: Dictionary) -> void:
	map_notice_items.append(item)


## Something waiting to be told on the map: a note or a grouped item.
func has_notice() -> bool:
	return map_notice != "" or not map_notice_items.is_empty()


## The waiting message, its title and its grouped items, taken off the queue:
## {text, title, items}.
func take_map_notice() -> Dictionary:
	var out := {"text": map_notice, "title": map_notice_title, "items": map_notice_items}
	clear_notice()
	return out


## Told: forget the notes, their title and the grouped items.
func clear_notice() -> void:
	map_notice = ""
	map_notice_title = ""
	map_notice_items = []


func relation_with_realm(realm: String) -> int:
	return int(realm_relations.get(realm, 0))


func add_realm_relation(realm: String, amount: int) -> void:
	var cur: int = int(realm_relations.get(realm, 0))
	realm_relations[realm] = clampi(cur + amount, -100, 100)


func relation_with_lord(lord_id: int) -> int:
	return int(lord_relations.get(lord_id, 0))


func add_lord_relation(lord_id: int, amount: int) -> void:
	var cur: int = int(lord_relations.get(lord_id, 0))
	lord_relations[lord_id] = clampi(cur + amount, -100, 100)


func has_contract() -> bool:
	return not contract.is_empty() and int(contract.get("days_left", 0)) > 0


func contract_realm() -> String:
	return String(contract.get("realm", "")) if has_contract() else ""


func contract_daily_pay() -> int:
	return int(contract.get("daily_pay", 0)) if has_contract() else 0


func is_allied_with(realm: String) -> bool:
	if has_contract() and contract_realm() == realm:
		return true
	if is_crowned() and (realm == WorldData.CROWN or world.allied_with_crown(realm)):
		return true
	return relation_with_realm(realm) >= 50


func is_at_war_with(realm: String) -> bool:
	if realm == WorldData.BANDITS:
		return true
	if is_crowned() and realm != WorldData.CROWN and world.at_war(WorldData.CROWN, realm):
		return true
	if relation_with_realm(realm) <= -20:
		return true
	if has_contract() and world != null:
		var emp := contract_realm()
		if emp != "" and world.at_war(emp, realm):
			return true
	return false


func calculate_contract_pay(realm: String) -> int:
	var men := total_men()
	return CONTRACT_BASE_PAY + int(renown / 5) + int(men / 2)


func sign_contract(realm: String) -> void:
	var daily: int = calculate_contract_pay(realm)
	contract = {
		"realm": realm,
		"daily_pay": daily,
		"days_left": CONTRACT_DAYS,
		"bonus_per_lord": CONTRACT_LORD_BONUS,
	}
	if world != null and world.player() != null:
		world.player().faction = realm
	add_realm_relation(realm, 10)
	if world != null:
		for f in WorldData.FACTIONS:
			if f != WorldData.BANDITS and f != realm and world.at_war(realm, f):
				add_realm_relation(f, -15)
	_note("Signed a %d-day mercenary contract with the %s (%d silver/day)." % [
		CONTRACT_DAYS, WorldData.FACTIONS[realm]["name"], daily
	])
	if world != null:
		world.emit_event({"type": "contract_signed", "company": "Your warband", "realm": realm})
	save_game()


func break_contract() -> void:
	if not has_contract():
		return
	var realm := contract_realm()
	contract = {}
	if world != null and world.player() != null:
		world.player().faction = ""
	add_realm_relation(realm, -25)
	_note("You broke your contract with the %s, suffering a loss of honor." % WorldData.FACTIONS[realm]["name"])
	save_game()


func captain_by_id(id: int) -> Variant:
	for s in army:
		var c = s.get("captain")
		if c != null and int(c["id"]) == id:
			return c
	return null


## Every pair of living captains with a bond of rank C or better: [{a, b, points, rank}].
func bonds() -> Array:
	var out := []
	for i in army.size():
		var a = army[i].get("captain")
		if a == null:
			continue
		for j in range(i + 1, army.size()):
			var b = army[j].get("captain")
			if b == null:
				continue
			var points := float(a["bonds"].get(str(b["id"]), 0.0))
			if Captains.rank_for(points) > 0:
				out.append({"a": a, "b": b, "points": points, "rank": Captains.rank_letter(points)})
	out.sort_custom(func(x, y): return x["points"] > y["points"])
	return out


func bond_intro_pending() -> bool:
	return not bond_events.is_empty() or (not bond_intro_seen and bond_intro_pair != "")


## The rank or memorial moment currently waiting for the player. The legacy fields remain
## readable so version-6 campaigns saved during the original rank-C introduction still work.
func bond_intro_event() -> Dictionary:
	if not bond_events.is_empty():
		return bond_events[0]
	if not bond_intro_seen and bond_intro_pair != "":
		return {"kind": "rank", "rank": "C", "a_id": int(bond_intro_ids[0]) if bond_intro_ids.size() > 0 else 0,
			"b_id": int(bond_intro_ids[1]) if bond_intro_ids.size() > 1 else 0, "pair": bond_intro_pair,
			"shared_battles": 1, "points": Captains.RANK_POINTS[1]}
	return {}


func acknowledge_bond_intro() -> void:
	var event := bond_intro_event()
	if not bond_events.is_empty():
		bond_events.pop_front()
	if String(event.get("kind", "")) == "rank" and String(event.get("rank", "")) == "C":
		bond_intro_seen = true
	_sync_bond_intro_legacy()
	save_game()


func bond_intro_captains() -> Array:
	var event := bond_intro_event()
	var out := []
	for id in [int(event.get("a_id", 0)), int(event.get("b_id", 0))]:
		if id <= 0:
			continue
		var captain = _captain_or_memorial(id)
		if captain != null:
			out.append(captain)
	if out.size() < 2 and bond_intro_pair != "":
		for pair in bonds():
			if bond_intro_pair.contains(String(pair["a"]["name"])) and bond_intro_pair.contains(String(pair["b"]["name"])):
				return [pair["a"], pair["b"]]
	return out


func _captain_or_memorial(id: int) -> Variant:
	var living = captain_by_id(id)
	if living != null:
		return living
	for memorial in fallen:
		if int(memorial.get("id", 0)) == id:
			return memorial
	return null


func _bond_key_ids(a_id: int, b_id: int) -> String:
	return "%d|%d" % [mini(a_id, b_id), maxi(a_id, b_id)]


func bond_record(a_id: int, b_id: int) -> Dictionary:
	return bond_records.get(_bond_key_ids(a_id, b_id), {})


func _ensure_bond_record(a_id: int, b_id: int) -> Dictionary:
	var key := _bond_key_ids(a_id, b_id)
	if not bond_records.has(key):
		bond_records[key] = {"shared_battles": 0, "last_battle": 0, "last_outcome": "",
			"last_losses": 0, "milestones": [], "conversations": [], "losses": []}
	return bond_records[key]


func bond_effect_text(points: float) -> String:
	var rank := Captains.rank_for(points)
	if rank <= 0:
		return "No battle effect until rank C."
	var damage := roundi(Captains.RANK_POWER[rank] * 100.0)
	return "+%.1f morale each second nearby%s" % [Captains.RANK_REGEN[rank],
		" · +%d%% damage" % damage if damage > 0 else ""]


func bond_conversation_is_new(a_id: int, b_id: int) -> bool:
	return next_bond_talk(a_id, b_id) != ""


## Talks at the fire go in order, C then B then A, none skipped: the next is the first rank
## reached after the last one read, so a pair that has read A has passed C and B. "" when
## every rank they've reached has been talked through.
func next_bond_talk(a_id: int, b_id: int) -> String:
	var a = captain_by_id(a_id)
	var b = captain_by_id(b_id)
	if a == null or b == null:
		return ""
	var reached := Captains.rank_for(float(a.get("bonds", {}).get(str(b_id), 0.0)))
	var last := 0
	for r in bond_record(a_id, b_id).get("conversations", []):
		last = maxi(last, Captains.RANKS.find(String(r)))
	return String(Captains.RANKS[last + 1]) if last < reached else ""


## A replayable, event-aware camp exchange. It reads campaign facts and changes no combat,
## bond or relationship values; only the "new" marker is acknowledged.
func bond_conversation(a_id: int, b_id: int, at_rank: String = "") -> Dictionary:
	var a = captain_by_id(a_id)
	var b = captain_by_id(b_id)
	if a == null or b == null:
		return {}
	var points := float(a.get("bonds", {}).get(str(b_id), 0.0))
	var rank := Captains.rank_letter(points)
	if rank == "":
		return {}
	# An earlier rank's talk, read again.
	if at_rank != "" and Captains.RANKS.find(at_rank) > 0 and Captains.RANKS.find(at_rank) <= Captains.RANKS.find(rank):
		rank = at_rank
	var record := bond_record(a_id, b_id)
	var shared := int(record.get("shared_battles", 0))
	var passages := []
	if shared > 0:
		passages.append("%s and %s sit near the edge of the fire. They have fought close enough to rely on one another in %d %s." % [
			a["first"], b["first"], shared, "battle" if shared == 1 else "battles"])
	else:
		passages.append("%s and %s sit near the edge of the fire. Their bond was already established before the company began keeping a shared battle record." % [a["first"], b["first"]])
	var outcome := String(record.get("last_outcome", ""))
	if outcome != "":
		passages.append("Their last shared fight ended in %s, with %d of the company lost. Neither needs to make the cost sound smaller." % [
			outcome, int(record.get("last_losses", 0))])
	if int(a.get("wounded", 0)) > 0 or int(b.get("wounded", 0)) > 0:
		var hurt := String(a["first"] if int(a.get("wounded", 0)) > 0 else b["first"])
		var other := String(b["first"] if hurt == String(a["first"]) else a["first"])
		passages.append("%s checks %s's bandages without ceremony. \"You heal. I will keep your place in the line.\"" % [other, hurt])
	var remembered := []
	for captain in [a, b]:
		var history: Dictionary = captain.get("history", {})
		for fallen_name in history.get("fallen_friends", []):
			if not remembered.has(fallen_name):
				remembered.append(fallen_name)
	if not remembered.is_empty():
		passages.append("Before they rise, they speak the names of the absent: %s. The silence afterward is shared, not empty." % ", ".join(PackedStringArray(remembered)))
	match rank:
		"C":
			passages.append("The bond between them is forged in iron (Rank C). Across the watchfire, a shared nod is all that is spoken — when shields lock tomorrow, each knows the other's flank is secure.")
		"B":
			passages.append("Their fellowship runs deep as blood (Rank B). Passing bread and sharpening whetstones in silence, they have pulled each other through the press of pikes and the rain of arrows.")
		"A":
			passages.append("An unbreakable oath of the vanguard (Rank A). Standing together against impossible odds, their names and deeds will forever be spoken together in the annals of the company.")
	passages.append(_bond_voice_line(a, b))
	return {"a": a, "b": b, "rank": rank, "points": points, "shared_battles": shared, "passages": passages,
		"exchange": _bond_exchange(a, b, rank)}


## What two captains say to each other at the fire, by rank and by the first one's
## temper: a short exchange, a line each in turn ({who: "a" or "b", text}).
const BOND_EXCHANGES := {
	"C": {
		Captains.VENGEFUL: ["You were slow on the left today.", "I was covering you. You were fast on everything.", "Then stay close. I'll be slow for you next time.", "Deal."],
		Captains.FRAGILE: ["I couldn't see your banner for a while out there.", "I could see yours. It was shaking.", "...It was the wind.", "It was the wind. I'll stand closer tomorrow."],
		"": ["Same distance tomorrow?", "Close enough to help, far enough to breathe.", "You've thought about this.", "Since the second charge. Bread?"],
	},
	"B": {
		Captains.VENGEFUL: ["The one who cut your arm. I found him.", "I know. I saw. Let it be, now.", "I don't know how to let things be.", "Then sit here until you learn. I'll wait."],
		Captains.FRAGILE: ["Do you ever think we won't come back?", "Every time. Then I look for your squad, and I stop thinking it.", "That's a terrible plan.", "It's worked so far."],
		"": ["I moved my men before you called for it.", "I noticed. I was about to call for it.", "We should stop telling each other things.", "We should. Pass the whetstone."],
	},
	"A": {
		Captains.VENGEFUL: ["If you fall, I finish what reached you.", "Then I'd better stay standing. For their sake.", "You're laughing.", "I'm alive. You're here. It's allowed."],
		Captains.FRAGILE: ["I'm not afraid when you're on my flank. I wanted you to know that.", "I'm afraid all the time. I just stand next to you anyway.", "That's the bravest thing anyone's said to me.", "Don't tell the others."],
		"": ["They'll tell stories about this company someday.", "They'll get it wrong.", "They'll put us in the same verse, at least.", "Then let's earn it again tomorrow."],
	},
}


func _bond_exchange(a: Dictionary, b: Dictionary, rank: String) -> Array:
	var by_temper: Dictionary = BOND_EXCHANGES.get(rank, BOND_EXCHANGES["C"])
	var lines: Array = by_temper.get(String(a.get("temperament", "")), by_temper[""])
	var out := []
	for i in lines.size():
		out.append({"who": "a" if i % 2 == 0 else "b", "text": String(lines[i])})
	return out


func _bond_voice_line(a: Dictionary, b: Dictionary) -> String:
	match String(a.get("temperament", Captains.STEADFAST)):
		Captains.VENGEFUL:
			return "\"If you fall,\" %s says, \"I finish what reached you.\" %s answers, \"Then I had better stay standing.\"" % [a["first"], b["first"]]
		Captains.FRAGILE:
			return "%s admits that the line feels thinner whenever %s is out of sight. %s does not laugh; that is answer enough." % [a["first"], b["first"], b["first"]]
		_:
			return "%s says, \"Same distance tomorrow. Close enough to help, far enough to breathe.\" %s nods." % [a["first"], b["first"]]


## The talk at `rank` has been read (the current rank's, when none is given).
func acknowledge_bond_conversation(a_id: int, b_id: int, rank: String = "") -> void:
	var a = captain_by_id(a_id)
	var b = captain_by_id(b_id)
	if a == null or b == null:
		return
	var reached := Captains.rank_for(float(a.get("bonds", {}).get(str(b_id), 0.0)))
	if rank == "" or Captains.RANKS.find(rank) < 1 or Captains.RANKS.find(rank) > reached:
		rank = String(Captains.RANKS[reached])
	var record := _ensure_bond_record(a_id, b_id)
	if rank != "" and not record["conversations"].has(rank):
		record["conversations"].append(rank)
		save_game()


func _sync_bond_intro_legacy() -> void:
	if bond_events.is_empty():
		bond_intro_pair = ""
		bond_intro_ids = []
		return
	var event: Dictionary = bond_events[0]
	bond_intro_pair = String(event.get("pair", ""))
	bond_intro_ids = [int(event.get("a_id", 0)), int(event.get("b_id", 0))]


## What kind of fight `band` makes of it: "village" if you catch it raiding one, "chief"
## if a chief leads it, "ambush" if it falls on you on a road through the woods, and
## otherwise "rout".
func encounter_objective(band) -> String:
	if band.raiding and band.raid_village != "":
		return "village"
	if band.is_chief_band:
		return "chief"
	var ppos: Vector2 = world.party_pos(world.player())
	if MapTerrain.shared().wooded(ppos) and not world.is_sea(band.node, band.next):
		if has_specialization(Captains.SCOUT) and rng.randf() < 0.5:
			return "rout"
		return "ambush"
	return "rout"


## How the band on the road means to fight: {objective, site, temperament}. Bandits
## charge, except on ground they chose, where they wait for you, and chiefs have minds of
## their own. Worked out from the band and the hour, so the encounter, the battle and Send
## in all see the same fight.
func encounter_plan(band) -> Dictionary:
	var objective := encounter_objective(band)
	var prng := RandomNumberGenerator.new()
	prng.seed = hash([band.id, int(world.hour * 10.0)])
	var site := BattleSite.pick(world, world.party_pos(world.player()), objective, prng.randi() & 0x7fffffff)
	var temperament := Commander.RECKLESS
	var grudge_text := ""
	var has_grudge := false
	if band.kind == WorldSim.LORD:
		var l: Dictionary = world.lord_of(band)
		has_grudge = bool(l.get("grudge", false))
		if has_grudge:
			var cap_name: String = String(l.get("grudge_captain_name", ""))
			var comp_name: String = String(l.get("grudge_company_name", ""))
			var target_desc := comp_name if comp_name != "" else (cap_name if cap_name != "" else "your captains")
			grudge_text = "\"You'll remember %s, I think,\" %s sneers across the line. \"Today we settle the score!\"" % [target_desc, l.get("name", "The lord")]
		match String(l.get("bearing", "")):
			Lords.CAUTIOUS:
				temperament = Commander.PATIENT
			Lords.DARING, Lords.CRUEL:
				temperament = Commander.RECKLESS
			Lords.HONORABLE:
				temperament = Commander.HAMMER
			_:
				temperament = Commander.PATIENT if not site["fair"] else Commander.RECKLESS
	elif not site["fair"]:
		temperament = Commander.PATIENT
	elif objective == "chief":
		temperament = Commander.TEMPERAMENTS[prng.randi_range(0, Commander.TEMPERAMENTS.size() - 1)]
	var can_withdraw: bool = world.can_withdraw() if world != null else true
	return {"objective": objective, "site": site, "temperament": temperament, "can_withdraw": can_withdraw,
		"has_grudge": has_grudge, "grudge_text": grudge_text}


## The army of the party blocking the road, set up for the battle screen.
func start_encounter_battle() -> void:
	if world == null or world.encounter == -1:
		return
	var band = world.party(world.encounter)
	var plan := encounter_plan(band)
	var objective: String = plan["objective"]
	var chief_name := ""
	if objective == "chief":
		chief_name = band.chief_name if band.chief_name != "" else band.name.split("'s")[0]

	var enemy_army := []
	var enemy_parties: Array = world.army_parties(band)
	for p in enemy_parties:
		enemy_army.append_array(WorldSim.clean_army(p.army))

	var is_lord_battle: bool = band.kind == WorldSim.LORD
	var enemy_lid: int = band.lord if is_lord_battle else -1
	var lord_obj: Dictionary = world.lord_of(band) if is_lord_battle else {}
	var has_grudge: bool = bool(lord_obj.get("grudge", false))
	var bearing: String = String(lord_obj.get("bearing", ""))

	if is_lord_battle and not enemy_army.is_empty():
		enemy_army[0]["is_lord"] = true
		enemy_army[0]["lord_id"] = enemy_lid
		enemy_army[0]["lord_name"] = band.name
		enemy_army[0]["has_grudge"] = has_grudge
		enemy_army[0]["bearing"] = bearing

	var allied_squads := []
	if world.following_party != -1:
		var fp = world.party(world.following_party)
		if fp != null and world.relation_to_player(fp.faction) == "friendly":
			for ap in world.army_parties(fp):
				for sq in ap.army:
					if int(sq.get("men", 0)) > 0:
						var entry: Dictionary = sq.duplicate(true)
						entry["is_ally"] = true
						entry["lord_id"] = ap.lord
						entry["culture"] = WorldData.culture_of(ap.faction)
						allied_squads.append(entry)

	# Crown lords riding at your side join in.
	for ep in world.escorts():
		if ep.id == world.following_party or ep.id == band.id:
			continue
		for sq in ep.army:
			if int(sq.get("men", 0)) > 0:
				var entry: Dictionary = sq.duplicate(true)
				entry["is_ally"] = true
				entry["lord_id"] = ep.lord
				entry["culture"] = WorldData.culture_of(ep.faction)
				allied_squads.append(entry)

	pending_battle = {
		"enemy": enemy_army, "culture": WorldData.culture_of(band.faction),
		"temperament": plan["temperament"], "name": band.name,
		"party_id": int(band.id),
		"site": plan["site"],
		"objective": objective,
		"chief_name": chief_name,
		"raid_village": band.raid_village,
		"is_lord": is_lord_battle,
		"enemy_lord_id": enemy_lid,
		"enemy_faction": band.faction,
		"allies": allied_squads,
		"has_grudge": has_grudge,
		"bearing": bearing,
	}


## Send your men in without commanding them. The fight is settled at once, at the cost
## of a few more men than a battle you lead well.
func auto_resolve_encounter() -> Dictionary:
	if world == null or world.encounter == -1:
		return {}
	start_encounter_battle()
	var fighters := []
	for s in army:
		if int(s["men"]) > 0:
			fighters.append(s)
	for a in pending_battle.get("allies", []):
		if int(a.get("men", 0)) > 0:
			fighters.append(a)
	var result := AutoResolve.resolve(fighters, pending_battle["enemy"], rng, false, pending_battle.get("site"), pending_battle.get("objective", "rout"))
	apply_result(result)
	return result


## A fresh enemy host that grows a little every other battle, led by its own captains.
## Used when a battle starts without one set up by the map.
func enemy_army() -> Array:
	var erng := RandomNumberGenerator.new()
	erng.randomize()
	var types := [Troops.INFANTRY, Troops.INFANTRY, Troops.SPEARMEN, Troops.ARCHERS, Troops.CAVALRY]
	for i in mini(4, int(battles / 2.0) + 1):
		types.append(Troops.ORDER[erng.randi_range(0, Troops.ORDER.size() - 1)])
	var xp := mini(battles * 6, Troops.XP_PER_LEVEL * 2)
	var out := []
	var id := 1000
	# No enemy captain shares a name with one of yours.
	var taken := []
	for s in army:
		if s.get("captain") != null:
			taken.append(s["captain"]["first"])
	for type in types:
		var captain := Captains.make(erng, 100000 + id, type, taken)
		taken.append(captain["first"])
		out.append({"id": id, "type": type, "men": Troops.full_size(type), "xp": xp,
			"name": Captains.company_name(captain, type), "captain": captain})
		id += 1
	for i in range(out.size() - 1, 0, -1):
		var j := erng.randi_range(0, i)
		var tmp = out[i]
		out[i] = out[j]
		out[j] = tmp
	return out


## What happened to the captains, in words, for the result screen. Doesn't change anything.
func describe_result(result: Dictionary) -> Array:
	var lines := []
	var by_id: Dictionary = result.get("squads", {})
	for s in army:
		var r = by_id.get(int(s["id"]))
		var c = s.get("captain")
		if r == null or c == null or not r.has("captain"):
			continue
		var cr: Dictionary = r["captain"]
		match String(cr["fate"]):
			"killed":
				if casual_mode:
					lines.append("%s was grievously wounded (rolled %d, needed %d) and will sit out %d battles." % [
						c["name"], cr["roll"], cr["needed"], Captains.CASUAL_WOUND_BATTLES])
				else:
					lines.append("%s fell. Rolled %d, needed %d to live." % [c["name"], cr["roll"], cr["needed"]])
			"wounded":
				lines.append("%s was wounded (rolled %d, needed %d) and will sit out %d battles." % [
					c["name"], cr["roll"], cr["needed"], Captains.WOUND_BATTLES])
	# Bonds on one line, so a first battle that bonds half the army doesn't fill the screen.
	var pairs := PackedStringArray()
	for change in _bond_changes(result):
		pairs.append("%s & %s (%s)" % [change["a"]["first"], change["b"]["first"], change["rank"]])
	if pairs.size() > 3:
		lines.append("New bonds: %s and %d more." % [", ".join(pairs.slice(0, 3)), pairs.size() - 3])
	elif not pairs.is_empty():
		lines.append("New bonds: %s." % ", ".join(pairs))
	return lines


## A complete, read-only account of a battle while the old roster is still intact.
## The result screen and the saved "last battle" card both use this, so rewards,
## captain fates, bonds and progression tell the same story.
func battle_report(result: Dictionary) -> Dictionary:
	var won := bool(result.get("won", false))
	var lost := int(result.get("lost", 0))
	var killed := int(result.get("killed", 0))
	var by_id: Dictionary = result.get("squads", {})
	var squad_rows := []
	var captain_rows := []
	var strongest := {}
	for squad in army:
		var id := int(squad.get("id", 0))
		var outcome = by_id.get(id, by_id.get(str(id)))
		if typeof(outcome) != TYPE_DICTIONARY:
			continue
		var before_men := int(squad.get("men", 0))
		var after_men := int(outcome.get("men", before_men))
		var battle_kills := int(outcome.get("kills", 0))
		var before_xp := int(squad.get("xp", 0))
		var after_xp := before_xp + battle_kills
		var level := int(squad.get("level", Troops.level_for(before_xp)))
		var lost_count := maxi(0, before_men - after_men)
		var wounded_count := int(round(lost_count * 0.5))
		var row := {
			"id": id, "name": String(squad.get("name", "Company")),
			"unit_name": Units.troop_name(squad, culture),
			"men_before": before_men, "men_after": after_men,
			"lost": lost_count, "wounded": wounded_count, "kills": battle_kills,
			"xp_before": before_xp, "xp_after": after_xp,
			"level_before": level, "level_after": Troops.level_for(after_xp),
			"training_ready": Troops.level_for(after_xp) > level,
		}
		squad_rows.append(row)
		if strongest.is_empty() or battle_kills > int(strongest.get("kills", -1)):
			strongest = row
		var captain = squad.get("captain")
		var captain_result = outcome.get("captain")
		if typeof(captain) == TYPE_DICTIONARY and typeof(captain_result) == TYPE_DICTIONARY:
			var fate_str := String(captain_result.get("fate", "standing"))
			if casual_mode and fate_str == "killed":
				fate_str = "wounded"
			captain_rows.append({
				"id": int(captain.get("id", 0)),
				"appearance_id": Captains.ensure_appearance(captain),
				"name": String(captain.get("name", "Captain")),
				"first": String(captain.get("first", "Captain")),
				"company": String(squad.get("name", "Company")),
				"culture": String(captain.get("culture", culture)),
				"fate": fate_str,
				"roll": int(captain_result.get("roll", 0)),
				"needed": int(captain_result.get("needed", 0)),
				"kills": int(captain_result.get("kills", 0)),
				"words": String(captain_result.get("words", "")),
				"face": Captains.face_record(captain),
			})

	var bond_rows := []
	var gained: Dictionary = result.get("bonds", {})
	for key in gained:
		var ids := String(key).split("|")
		if ids.size() != 2:
			continue
		var a = captain_by_id(int(ids[0]))
		var b = captain_by_id(int(ids[1]))
		if a == null or b == null:
			continue
		var before := float(a["bonds"].get(str(b["id"]), 0.0))
		var earned := _bond_points(a, b, float(gained[key]))
		var after := before + earned
		bond_rows.append({
			"a_id": int(a["id"]), "b_id": int(b["id"]),
			"a_name": String(a["first"]), "b_name": String(b["first"]),
			"a_appearance_id": Captains.ensure_appearance(a),
			"b_appearance_id": Captains.ensure_appearance(b),
			"a_culture": String(a.get("culture", culture)),
			"b_culture": String(b.get("culture", culture)),
			"a_face": Captains.face_record(a),
			"b_face": Captains.face_record(b),
			"before": before, "earned": earned, "after": after,
			"rank_before": Captains.rank_letter(before),
			"rank_after": Captains.rank_letter(after),
			"rank_up": Captains.rank_for(after) > Captains.rank_for(before),
		})

	var rewards := {"silver": 0, "food": 0, "renown": 0}
	if won and world != null and not pending_battle.is_empty():
		rewards = Economy.spoils(killed)
		if has_specialization(Captains.QUARTERMASTER):
			rewards["silver"] = int(round(rewards["silver"] * 1.15))
			rewards["food"] = int(round(rewards["food"] * 1.15))
		var objective := String(pending_battle.get("objective", "rout"))
		if objective == "chief" and bool(result.get("chief_killed", false)):
			rewards["silver"] = int(rewards["silver"]) * 2
			rewards["renown"] = int(rewards["renown"]) + 10
		elif objective == "village" and String(pending_battle.get("raid_village", "")) != "":
			rewards["food"] = int(rewards["food"]) + 15

	var story := "The company withdrew from the field." if not won else "The company held the field."
	if not strongest.is_empty() and int(strongest["kills"]) > 0:
		story = "%s bore the hardest fighting, cutting down %d." % [strongest["name"], strongest["kills"]]
		story += " The company held the field." if won else " The survivors withdrew."
	if lost > 0:
		var wounded_count := int(round(lost * 0.5))
		var killed_count := lost - wounded_count
		story += " %d casualties (%d slain, %d wounded in baggage)." % [lost, killed_count, wounded_count]
	return {
		"won": won, "lost": lost, "killed": killed,
		"reason": String(result.get("reason", "")), "story": story,
		"rewards": rewards, "captains": captain_rows, "bonds": bond_rows, "memorials": _report_memorials(captain_rows),
		"squads": squad_rows,
	}


## Bonds this battle ended: for each captain who fell, the captains bound to them.
func _report_memorials(captain_rows: Array) -> Array:
	var out := []
	for row in captain_rows:
		if String(row.get("fate", "")) != "killed":
			continue
		var fallen = captain_by_id(int(row["id"]))
		if fallen == null:
			continue
		for other_id in fallen.get("bonds", {}):
			var survivor = captain_by_id(int(other_id))
			var rank := Captains.rank_letter(float(fallen["bonds"][other_id]))
			if survivor == null or rank == "" or captain_rows.any(func(r): return int(r["id"]) == int(survivor["id"]) and String(r.get("fate", "")) == "killed"):
				continue
			out.append({"survivor": String(survivor["first"]), "fallen": String(fallen["first"]), "rank": rank,
				"survivor_face": Captains.face_record(survivor), "fallen_face": Captains.face_record(fallen),
				"shared": int(bond_record(int(fallen["id"]), int(survivor["id"])).get("shared_battles", 0))})
	return out


## Bonds with a talk at the fire not yet heard: one for each rank reached.
func new_bond_talks() -> Array:
	return bonds().filter(func(b): return bond_conversation_is_new(int(b["a"]["id"]), int(b["b"]["id"])))


func _bond_changes(result: Dictionary) -> Array:
	var out := []
	var gained: Dictionary = result.get("bonds", {})
	for key in gained:
		var ids := String(key).split("|")
		var a = captain_by_id(int(ids[0]))
		var b = captain_by_id(int(ids[1]))
		if a == null or b == null:
			continue
		var before := float(a["bonds"].get(str(b["id"]), 0.0))
		var after := before + _bond_points(a, b, float(gained[key]))
		if Captains.rank_for(after) > Captains.rank_for(before):
			out.append({"a": a, "b": b, "rank": Captains.rank_letter(after)})
	return out


func _bond_rank_events(result: Dictionary) -> Array:
	var out := []
	var gained: Dictionary = result.get("bonds", {})
	for key in gained:
		var ids := String(key).split("|")
		if ids.size() != 2:
			continue
		var a = captain_by_id(int(ids[0]))
		var b = captain_by_id(int(ids[1]))
		if a == null or b == null:
			continue
		var before := float(a["bonds"].get(str(b["id"]), 0.0))
		var after := before + _bond_points(a, b, float(gained[key]))
		for rank_index in range(Captains.rank_for(before) + 1, Captains.rank_for(after) + 1):
			out.append({"a_id": int(a["id"]), "b_id": int(b["id"]), "rank": Captains.RANKS[rank_index],
				"points": after, "pair": "%s & %s" % [a["name"], b["name"]]})
	return out


func _queue_bond_rank_events(events: Array) -> void:
	for event in events:
		var a_id := int(event["a_id"])
		var b_id := int(event["b_id"])
		if captain_by_id(a_id) == null or captain_by_id(b_id) == null:
			continue
		var rank := String(event["rank"])
		var record := _ensure_bond_record(a_id, b_id)
		if record["milestones"].has(rank):
			continue
		record["milestones"].append(rank)
		# Only the company's very first bond stops you, once, to say what bonds do. Every
		# other rank is told in the battle's results, and its talk waits at the fire.
		if rank != "C" or bond_intro_seen or not bond_events.is_empty():
			continue
		var queued: Dictionary = event.duplicate(true)
		queued["kind"] = "rank"
		queued["battle"] = battles
		queued["shared_battles"] = int(record.get("shared_battles", 0))
		bond_events.append(queued)
	_sync_bond_intro_legacy()


func _record_bond_loss(fallen_captain: Dictionary) -> void:
	for other_id in fallen_captain.get("bonds", {}):
		var survivor = captain_by_id(int(other_id))
		if survivor == null:
			continue
		var points := float(fallen_captain["bonds"][other_id])
		var rank := Captains.rank_letter(points)
		if rank == "":
			continue
		var history: Dictionary = survivor.get("history", {"wounds": 0, "fallen_friends": []})
		if not history.get("fallen_friends", []).has(fallen_captain["name"]):
			history["fallen_friends"].append(fallen_captain["name"])
		survivor["history"] = history
		var record := _ensure_bond_record(int(fallen_captain["id"]), int(survivor["id"]))
		if not record["losses"].has(fallen_captain["name"]):
			record["losses"].append(fallen_captain["name"])
		# Remembered in the battle's results and at the fire, not with a screen of its own.
	_sync_bond_intro_legacy()


func _bond_points(a: Dictionary, b: Dictionary, seconds: float) -> float:
	var points := minf(Captains.BOND_POINTS_PER_BATTLE, seconds / Captains.BOND_SECONDS_PER_POINT)
	if a.get("quirk", "") == Captains.MENTOR or b.get("quirk", "") == Captains.MENTOR:
		points *= 1.5
	return points


## Apply a battle result from BattleSim.result_for(PLAYER).
func apply_result(result: Dictionary) -> void:
	# What became of each captain, in words, while the roster still names them.
	var fates := describe_result(result)
	var rank_events := _bond_rank_events(result)
	var report := battle_report(result)
	battles += 1
	var by_id: Dictionary = result.get("squads", {})
	# Bonds first, while every captain who fought is still on the roster.
	var gained: Dictionary = result.get("bonds", {})
	for key in gained:
		var ids := String(key).split("|")
		var a = captain_by_id(int(ids[0]))
		var b = captain_by_id(int(ids[1]))
		if a == null or b == null:
			continue
		var points := float(a["bonds"].get(str(b["id"]), 0.0)) + _bond_points(a, b, float(gained[key]))
		a["bonds"][str(b["id"])] = points
		b["bonds"][str(a["id"])] = points
		var record := _ensure_bond_record(int(a["id"]), int(b["id"]))
		record["shared_battles"] = int(record.get("shared_battles", 0)) + 1
		record["last_battle"] = battles
		record["last_outcome"] = "victory" if bool(result.get("won", false)) else "defeat"
		record["last_losses"] = int(result.get("lost", 0))
	var dead_ids := []
	var fallen_captains := []
	for s in army:
		var id := int(s["id"])
		var c = s.get("captain")
		if by_id.has(id):
			var prev_men := int(s["men"])
			var end_men := int(by_id[id]["men"])
			var lost_men := maxi(0, prev_men - end_men)
			var wounded_count := int(round(lost_men * 0.5))
			s["wounded"] = int(s.get("wounded", 0)) + wounded_count
			s["men"] = end_men
			var kills := int(by_id[id].get("kills", 0))
			var earned_xp := kills
			if has_specialization(Captains.DRILLMASTER):
				earned_xp = int(ceil(kills * 1.25))
			s["xp"] = int(s["xp"]) + earned_xp
		if c == null:
			continue
		var cr = by_id.get(id, {}).get("captain")
		if cr == null:
			# Sat this one out with a wound, and is a battle closer to fighting again.
			if int(c.get("wounded", 0)) > 0:
				c["wounded"] = int(c["wounded"]) - 1
			continue
		c["battles"] = int(c["battles"]) + 1
		c["kills"] = int(c["kills"]) + int(cr.get("kills", 0))
		match String(cr["fate"]):
			"wounded":
				c["wounded"] = Captains.WOUND_BATTLES
				var history: Dictionary = c.get("history", {"wounds": 0, "fallen_friends": [], "scars": []})
				history["wounds"] = int(history.get("wounds", 0)) + 1
				c["history"] = history
			"killed":
				if casual_mode:
					c["wounded"] = Captains.CASUAL_WOUND_BATTLES
					var history: Dictionary = c.get("history", {"wounds": 0, "fallen_friends": [], "scars": []})
					history["wounds"] = int(history.get("wounds", 0)) + 1
					if not history.has("scars"):
						history["scars"] = []
					var scar_desc := "Grievous Battle Wound (Battle %d)" % battles
					if not history["scars"].has(scar_desc):
						history["scars"].append(scar_desc)
					c["history"] = history
					_note("%s suffered a grievous wound in battle %d, but survived (sits out %d battles)." % [
						c["name"], battles, Captains.CASUAL_WOUND_BATTLES
					])
				else:
					dead_ids.append(int(c["id"]))
					fallen_captains.append(c)
					var enemy_lid_for_mem: int = int(pending_battle.get("enemy_lord_id", -1)) if bool(pending_battle.get("is_lord", false)) else -1
					var enemy_lname_for_mem: String = String(pending_battle.get("name", "")) if bool(pending_battle.get("is_lord", false)) else ""
					fallen.append(_memorial(s, c, String(cr.get("words", "")), enemy_lid_for_mem, enemy_lname_for_mem))
					if enemy_lid_for_mem >= 0 and world != null:
						var elord: Dictionary = world.lord_by_id(enemy_lid_for_mem)
						if not elord.is_empty():
							elord["grudge"] = true
							elord["grudge_captain_name"] = String(c["name"])
							elord["grudge_company_name"] = String(s.get("name", ""))
					# A veteran from the ranks takes command, if there's anyone left to lead.
					s["captain"] = _new_captain(String(s["type"])) if int(s["men"]) > 0 else null
	# Reactions are created only for partners who actually survived the whole result.
	for fallen_captain in fallen_captains:
		_record_bond_loss(fallen_captain)
	for s in army:
		var c = s.get("captain")
		if c != null:
			for d in dead_ids:
				c["bonds"].erase(str(d))
	# A squad with no men left is gone, unless its captain lived to raise it again.
	army = army.filter(func(s): return int(s["men"]) > 0 or s.get("captain") != null)
	_queue_bond_rank_events(rank_events)
	if result.get("won", false):
		wins += 1
	if world != null:
		world.return_allied_losses(by_id)
	if world != null and not pending_battle.is_empty():
		var band := String(pending_battle.get("name", "The bandits"))
		var how := "You lost %d men and cut down %d." % [int(result.get("lost", 0)), int(result.get("killed", 0))]
		var obj: String = String(pending_battle.get("objective", "rout"))
		var c_name: String = String(pending_battle.get("chief_name", ""))
		var r_village: String = String(pending_battle.get("raid_village", ""))
		var is_lord: bool = bool(pending_battle.get("is_lord", false))
		var enemy_faction: String = String(pending_battle.get("enemy_faction", ""))
		var enemy_lid: int = int(pending_battle.get("enemy_lord_id", -1))
		if obj == "siege":
			_siege_outcome(result, how)
		elif obj == "raid":
			_raid_outcome(result, how)
		elif result.get("won", false):
			world.win_encounter()
			var got := Economy.spoils(int(result.get("killed", 0)))
			if has_specialization(Captains.QUARTERMASTER):
				got["silver"] = int(round(got["silver"] * 1.15))
				got["food"] = int(round(got["food"] * 1.15))
			if is_lord:
				got["silver"] = int(got["silver"]) + 150
				got["renown"] = int(got["renown"]) + 15
				if enemy_lid >= 0:
					add_lord_relation(enemy_lid, -15)
				if has_contract() and world.at_war(contract_realm(), enemy_faction):
					var bonus: int = int(contract.get("bonus_per_lord", 100))
					got["silver"] = int(got["silver"]) + bonus
					add_realm_relation(contract_realm(), 5)
					_note("Contract bounty: +%d silver from %s." % [bonus, WorldData.FACTIONS[contract_realm()]["name"]])
				if not is_at_war_with(enemy_faction) and relation_with_realm(enemy_faction) > -20:
					add_realm_relation(enemy_faction, -30)
					_note("You attacked a lord of %s while at peace! They declare war upon you." % WorldData.FACTIONS[enemy_faction]["name"])
				_note("%s was defeated! Claimed %d silver and %d renown." % [band, got["silver"], got["renown"]])

				# Vengeance & Lord Fate
				if enemy_lid >= 0 and world != null:
					var elord: Dictionary = world.lord_by_id(enemy_lid)
					var elord_name: String = String(elord.get("name", band))
					if bool(elord.get("grudge", false)):
						var l_cap_name: String = String(elord.get("grudge_captain_name", ""))
						for mem in fallen:
							if int(mem.get("killed_by_lord_id", -1)) == enemy_lid:
								mem["avenged"] = true
								var deed := "slain" if result.get("lord_killed", false) else "captured"
								mem["avenged_words"] = "Avenged: %s was %s." % [elord_name, deed]
						elord["grudge"] = false
						_note("Vengeance! %s, who took %s from your company, has been %s!" % [
							elord_name,
							l_cap_name if l_cap_name != "" else "your captain",
							"slain" if result.get("lord_killed", false) else "brought down"
						])
						world.emit_event({"type": "grudge_avenged", "company": "Your warband", "lord": elord_name})
					if result.get("lord_killed", false):
						var heir: Dictionary = world.kill_lord(enemy_lid, "Player Warband")
						_note("%s fell mortally wounded on the field! An heir, %s, takes up their seat." % [elord_name, heir.get("name", "kin")])
						world.emit_event({"type": "lord_slain", "lord": elord_name, "by": "Your warband"})
					elif result.get("lord_captured", false):
						world.capture_lord(enemy_lid, "player")
						_note("%s was taken prisoner and travels in chains with your baggage." % elord_name)
						world.emit_event({"type": "lord_captured", "lord": elord_name, "captor": "Your warband"})
					else:
						_note("%s cut through the rout and escaped into the hills." % elord_name)
						world.emit_event({"type": "player_victory", "company": "Your warband", "enemy": elord_name, "at": world.here()})
			elif obj == "chief":
				if result.get("chief_killed", false):
					got["silver"] = int(got["silver"]) * 2
					got["renown"] = int(got["renown"]) + 10
					_note("The bandit chief %s was slain! Claimed a double bounty and +10 renown." % c_name)
				elif result.get("chief_escaped", false):
					world.escaped_chiefs.append({"name": c_name, "culture": pending_battle.get("culture", Cultures.VARDISH), "grudge": 1, "escaped_at": world.hour, "times_beaten": 1})
					_note("The bandit chief %s escaped into the hills!" % c_name)
			elif obj == "village" and r_village != "":
				var v_name := String(WorldData.settlement(r_village)["name"])
				got["food"] = int(got["food"]) + 15
				world.saved_villages[r_village] = int(world.saved_villages.get(r_village, 0)) + 1
				world.offers[r_village] = world._new_offers(r_village)
				_note("%s was saved from the raid! The villagers gave 15 rations and offered fresh recruits." % v_name)
			silver += int(got["silver"])
			food += int(got["food"])
			renown += int(got["renown"])
			if not is_lord:
				_note("%s are scattered. %s Spoils: %d silver, %d rations, %d renown." % [
					band, how, got["silver"], got["food"], got["renown"]])
			var b_party_id: int = int(pending_battle.get("party_id", -1))
			var b_party_name: String = String(pending_battle.get("name", ""))
			for job in active_jobs.duplicate():
				if String(job.get("type", "")) == Jobs.TYPE_HUNT:
					if (b_party_id >= 0 and int(job.get("target_party_id", -2)) == b_party_id) or (b_party_name != "" and String(job.get("target_name", "")) == b_party_name):
						job["status"] = "ready_to_claim"
						complete_job(String(job.get("id", "")))
		else:
			world.hurt_band(result.get("enemy_squads", {}))
			world.lose_encounter()
			var home := String(WorldData.settlement(world.here())["name"])
			if total_men() > 0:
				_note("%s beat you. %s The survivors regroup at %s, half a day later." % [band, how, home])
			else:
				_note("%s cut down your whole warband." % band)
		if result.get("won", false):
			match obj:
				"village":
					_count_deed("villages")
				"siege":
					_count_deed("walls")
			if bool(result.get("chief_killed", false)):
				_count_deed("chiefs")
			if bool(result.get("lord_captured", false)):
				_count_deed("lord")
		# How the lord took it, in his own manner.
		if is_lord and enemy_lid >= 0 and obj != "siege":
			var foe: Dictionary = world.lord_by_id(enemy_lid)
			if not foe.is_empty():
				foe["met_player"] = int(foe.get("met_player", 0)) + 1
				_note(LordVoice.line("beaten" if result.get("won", false) else "victor", foe))
		# Notable battles leave a mark: a chronicle line, and a few days of aftermath on
		# the map. Small skirmishes don't.
		var place: String = world.here() if world.here() != "" else world.nearest_place(world.party_pos(world.player()))
		report["place"] = place
		if int(result.get("killed", 0)) + int(result.get("lost", 0)) >= 30 or obj in ["siege", "village", "chief", "raid"] or is_lord:
			world.emit_event({"type": "battle_fought", "at": place, "won": bool(result.get("won", false)),
				"killed": int(result.get("killed", 0)), "lost": int(result.get("lost", 0))})
		for line in fates:
			_note(line)
		settle()
	pending_battle = {}
	last_result = report
	save_game()
	# Whatever it left to say comes under the battle's own title.
	if map_notice != "":
		map_notice_title = "After the battle"


## Attacking a lord of a realm the player is at peace with starts a war.
func attack_neutral_lord(lord_id: int, party_id: int) -> void:
	if world == null:
		return
	var lp = world.party(party_id)
	if lp == null:
		return
	add_realm_relation(lp.faction, -30)
	add_lord_relation(lord_id, -30)
	world.encounter = party_id
	world.emit_event({"type": "encounter", "party": party_id})


func _memorial(squad: Dictionary, c: Dictionary, words: String, killed_by_lid: int = -1, killed_by_lname: String = "") -> Dictionary:
	var friends := []
	for other_id in c["bonds"]:
		var other = captain_by_id(int(other_id))
		var rank := Captains.rank_letter(float(c["bonds"][other_id]))
		if other != null and rank != "":
			friends.append("%s (%s)" % [other["first"], rank])
	return {
		"id": int(c.get("id", 0)), "appearance_id": Captains.ensure_appearance(c),
		"name": c["name"], "first": c.get("first", c["name"]), "company": squad.get("name", ""), "type": squad["type"], "unit": squad.get("unit", ""),
		"culture": squad.get("culture", culture),
		"temperament": c.get("temperament", ""), "quirk": c.get("quirk", ""), "history": c.get("history", {}),
		"battles": int(c["battles"]), "kills": int(c["kills"]), "battle": battles,
		"words": words,
		"bonds": friends,
		"killed_by_lord_id": killed_by_lid,
		"killed_by_lord_name": killed_by_lname,
		"avenged": false,
		"avenged_words": "",
	}


## Lords currently held as prisoners by the player
func captive_lords() -> Array:
	if world == null:
		return []
	return world.captive_lords_of("player")


## Accept ransom offer for a captive lord
func accept_lord_ransom(lord_id: int) -> bool:
	if world == null:
		return false
	var l: Dictionary = world.lord_by_id(lord_id)
	if l.is_empty() or l.get("state") != "prisoner" or l.get("captive_of") != "player":
		return false
	var amount: int = int(l.get("ransom_amount", 200))
	var realm: String = String(l.get("realm", ""))
	if world.realms.has(realm):
		world.realms[realm]["treasury"] = maxi(0, int(world.realms[realm].get("treasury", 0)) - amount)
	silver += amount
	add_lord_relation(lord_id, 5)
	world.release_lord(lord_id)
	_note("%s was ransomed back to %s for %d silver." % [
		l["name"], WorldData.FACTIONS.get(realm, {}).get("name", realm), amount
	])
	world.emit_event({"type": "ransom_paid", "lord": l["name"], "from": "Your warband", "amount": amount})
	save_game()
	return true


## Deliver a captive lord to the player's mercenary employer for the contract bounty
func deliver_lord_to_employer(lord_id: int) -> bool:
	if world == null or not has_contract():
		return false
	var l: Dictionary = world.lord_by_id(lord_id)
	if l.is_empty() or l.get("state") != "prisoner" or l.get("captive_of") != "player":
		return false
	var bonus: int = int(contract.get("bonus_per_lord", 100))
	var emp: String = contract_realm()
	silver += bonus
	add_realm_relation(emp, 10)
	l["captive_of"] = emp
	l["ransom_at"] = world.hour + Lords.AI_RANSOM_HOURS
	_note("Delivered %s into custody of your employer, %s, claiming %d silver bounty." % [
		l["name"], WorldData.FACTIONS.get(emp, {}).get("name", emp), bonus
	])
	save_game()
	return true


## Release a captive lord for honor without ransom: they and their realm remember it.
const RELEASE_REGARD := 25
const RELEASE_REALM := 10
const RELEASE_RENOWN := 10
func release_lord_for_honor(lord_id: int) -> bool:
	if world == null:
		return false
	var l: Dictionary = world.lord_by_id(lord_id)
	if l.is_empty() or l.get("state") != "prisoner" or l.get("captive_of") != "player":
		return false
	var realm: String = String(l.get("realm", ""))
	add_lord_relation(lord_id, RELEASE_REGARD)
	add_realm_relation(realm, RELEASE_REALM)
	renown += RELEASE_RENOWN
	world.release_lord(lord_id)
	_note_item({"kind": "released", "name": String(l["name"]), "realm": realm})
	save_game()
	return true


## Saves the campaign. Before one has started there's nothing worth keeping.
func save_game() -> bool:
	if not persist:
		return true
	if world == null:
		return false
	# Replace only a completely written save, preserving the previous campaign on failure.
	var temporary := SAVE_PATH + ".tmp"
	var f := FileAccess.open(temporary, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(to_dict(), "", true, true))
	f.flush()
	var written := f.get_error() == OK
	f.close()
	if not written:
		DirAccess.remove_absolute(temporary)
		return false
	return DirAccess.rename_absolute(temporary, SAVE_PATH) == OK


## Save, and keep this moment as the before-battle save, so a lost fight can be undone.
func save_before_battle() -> void:
	save_game()
	SaveSlots.checkpoint(self, SaveSlots.BATTLE, "Before battle · " + String(pending_battle.get("name", "a fight")))


## Save, and keep this moment as the save made on entering `id`.
func save_on_arrival(id: String) -> void:
	save_game()
	if WorldData.SETTLEMENTS.has(id):
		SaveSlots.checkpoint(self, SaveSlots.ARRIVAL, "Entering " + String(WorldData.settlement(id)["name"]))


func to_dict() -> Dictionary:
	return {"version": SAVE_VERSION, "culture": culture, "army": army, "fallen": fallen, "battles": battles,
		"wins": wins, "next_id": _next_id, "next_captain": _next_captain,
		"silver": silver, "food": food, "renown": renown, "paid_day": _paid_day,
		"casual_mode": casual_mode, "ironman": ironman, "hired_heroes": hired_heroes.duplicate(), "heal_clock": _heal_clock,
		"realm_relations": realm_relations.duplicate(true), "lord_relations": lord_relations.duplicate(true),
		"contract": contract.duplicate(true),
		"bond_intro_seen": bond_intro_seen, "bond_intro_pair": bond_intro_pair, "bond_intro_ids": bond_intro_ids,
		"bond_events": bond_events, "bond_records": bond_records,
		"active_jobs": active_jobs.duplicate(true), "completed_jobs": completed_jobs.duplicate(true),
		"player_fief": player_fief.duplicate(true),
		"pinned_commitment": pinned_commitment, "ended_commitments": ended_commitments.duplicate(true),
		"camp_seen": camp_seen.duplicate(),
		"deeds": deeds.duplicate(true), "deed_counts": deed_counts.duplicate(), "company_title": company_title,
		"crown_name": crown_name, "crown_color": crown_color, "crown_won": crown_won, "crown_empty_days": crown_empty_days,
		"desertion_warning": desertion_warning, "last_result": last_result,
		"gathering_log": gathering_log.duplicate(true), "hosted": hosted.duplicate(true), "host_ready_at": host_ready_at,
		"muster": muster.duplicate(true), "banners": banners.duplicate(true),
		"invites_seen": invites_seen.duplicate(),
		"world": world.to_dict() if world != null else null}


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(data) != TYPE_DICTIONARY or not data.has("army"):
		return false
	return from_dict(data)


## Restore a campaign saved with to_dict().
func from_dict(data: Dictionary) -> bool:
	culture = String(data.get("culture", Cultures.VARDISH))
	world = null
	if typeof(data.get("world")) == TYPE_DICTIONARY:
		world = WorldSim.new()
		world.from_dict(data["world"])
	battles = int(data.get("battles", 0))
	casual_mode = bool(data.get("casual_mode", false))
	ironman = bool(data.get("ironman", false))
	hired_heroes = data.get("hired_heroes", []) if typeof(data.get("hired_heroes")) == TYPE_ARRAY else []
	active_jobs = data.get("active_jobs", []).duplicate(true) if typeof(data.get("active_jobs")) == TYPE_ARRAY else []
	completed_jobs = data.get("completed_jobs", []).duplicate(true) if typeof(data.get("completed_jobs")) == TYPE_ARRAY else []
	player_fief = data.get("player_fief", {}).duplicate(true) if typeof(data.get("player_fief")) == TYPE_DICTIONARY else {}
	if world != null and world.realms.has(WorldData.CROWN):
		WorldData.crown_culture = culture
	crown_name = String(data.get("crown_name", ""))
	crown_color = int(data.get("crown_color", 0))
	crown_won = bool(data.get("crown_won", false))
	crown_empty_days = int(data.get("crown_empty_days", 0))
	WorldData.set_crown(crown_name, crown_color)
	_fix_marriage_pacts()
	_load_gathering_state(data)
	muster = CrownCourt.load_muster(data.get("muster", {}))
	banners = CrownCourt.load_banners(data.get("banners", {}))
	pinned_commitment = String(data.get("pinned_commitment", ""))
	ended_commitments = data.get("ended_commitments", []).duplicate(true) if typeof(data.get("ended_commitments")) == TYPE_ARRAY else []
	camp_seen = data.get("camp_seen", []).duplicate() if typeof(data.get("camp_seen")) == TYPE_ARRAY else []
	deeds = data.get("deeds", {}).duplicate(true) if typeof(data.get("deeds")) == TYPE_DICTIONARY else {}
	deed_counts = data.get("deed_counts", {}).duplicate() if typeof(data.get("deed_counts")) == TYPE_DICTIONARY else {}
	for k in deed_counts:
		deed_counts[k] = int(deed_counts[k])
	company_title = String(data.get("company_title", ""))
	if has_fief() and world != null:
		world.garrisons[fief_id()] = player_fief.get("garrison", [])
	_heal_clock = float(data.get("heal_clock", 0.0))
	silver = int(data.get("silver", Economy.START_SILVER))
	food = int(data.get("food", -1))
	renown = int(data.get("renown", 0))
	realm_relations = {"vardmark": 0, "kharzan": 0, "ryumon": 0}
	var raw_rr = data.get("realm_relations", {})
	if typeof(raw_rr) == TYPE_DICTIONARY:
		for k in raw_rr:
			realm_relations[String(k)] = int(raw_rr[k])
	lord_relations = {}
	var raw_lr = data.get("lord_relations", {})
	if typeof(raw_lr) == TYPE_DICTIONARY:
		for k in raw_lr:
			lord_relations[int(k)] = int(raw_lr[k])
	contract = {}
	var raw_contract = data.get("contract", {})
	if typeof(raw_contract) == TYPE_DICTIONARY and not raw_contract.is_empty():
		contract = {
			"realm": String(raw_contract.get("realm", "")),
			"daily_pay": int(raw_contract.get("daily_pay", 0)),
			"days_left": int(raw_contract.get("days_left", 0)),
			"bonus_per_lord": int(raw_contract.get("bonus_per_lord", 100)),
		}
	_paid_day = int(data.get("paid_day", int(world.hour / 24.0) if world != null else 0))
	wins = int(data.get("wins", 0))
	last_result = data.get("last_result", {}) if typeof(data.get("last_result")) == TYPE_DICTIONARY else {}
	_next_id = int(data.get("next_id", 1))
	_next_captain = int(data.get("next_captain", 1))
	fallen = data.get("fallen", []).duplicate(true) if typeof(data.get("fallen")) == TYPE_ARRAY else []
	for memorial in fallen:
		if typeof(memorial) == TYPE_DICTIONARY:
			Captains.ensure_appearance(memorial)
			memorial["killed_by_lord_id"] = int(memorial.get("killed_by_lord_id", -1))
			memorial["killed_by_lord_name"] = String(memorial.get("killed_by_lord_name", ""))
			memorial["avenged"] = bool(memorial.get("avenged", false))
			memorial["avenged_words"] = String(memorial.get("avenged_words", ""))
	army = []
	for s in data["army"]:
		if typeof(s) != TYPE_DICTIONARY or not Troops.TYPES.has(String(s.get("type", ""))):
			continue
		# JSON stores numbers as floats; keep ids and counts as ints so results match by key.
		var xp := int(s.get("xp", 0))
		var sq_culture := String(s.get("culture", culture))
		var level := int(s.get("level", Troops.level_for(xp)))
		var unit_id := String(s.get("unit", ""))
		var pending_branch: bool = bool(s.get("pending_branch", false))
		if unit_id == "" or not Units.has(unit_id):
			unit_id = Units.recruit(sq_culture, String(s["type"]))
			if level >= 2:
				pending_branch = true
		var squad := {"id": int(s.get("id", 0)), "type": String(s["type"]), "unit": unit_id,
			"men": int(s.get("men", 0)), "wounded": int(s.get("wounded", 0)), "xp": xp, "level": level, "pending_branch": pending_branch,
			"culture": sq_culture, "name": String(s.get("name", "")), "captain": null}
		var c = s.get("captain")
		if typeof(c) == TYPE_DICTIONARY:
			squad["captain"] = _clean_captain(c, squad["type"])
		army.append(squad)
	for s in army:
		_next_id = maxi(_next_id, int(s["id"]) + 1)
		if s["captain"] != null:
			_next_captain = maxi(_next_captain, int(s["captain"]["id"]) + 1)
	# Warbands saved before captains existed get one per squad.
	for s in army:
		if s["captain"] == null and int(s["men"]) > 0:
			s["captain"] = _new_captain(s["type"])
		if s["name"] == "" and s["captain"] != null:
			s["name"] = Captains.company_name(s["captain"], s["type"])
	bond_intro_seen = bool(data.get("bond_intro_seen", not bonds().is_empty()))
	bond_intro_pair = String(data.get("bond_intro_pair", ""))
	bond_intro_ids = data.get("bond_intro_ids", []) if typeof(data.get("bond_intro_ids")) == TYPE_ARRAY else []
	bond_events = data.get("bond_events", []) if typeof(data.get("bond_events")) == TYPE_ARRAY else []
	bond_records = data.get("bond_records", {}) if typeof(data.get("bond_records")) == TYPE_DICTIONARY else {}
	_clean_bond_state()
	desertion_warning = String(data.get("desertion_warning", ""))
	# And those saved before they needed feeding start with a new warband's rations.
	if food < 0:
		food = Economy.START_FOOD_DAYS * total_men()
	return true


## What you've done at gatherings, read back from JSON (none in saves from before them).
func _load_gathering_state(data: Dictionary) -> void:
	gathering_log = {}
	var raw = data.get("gathering_log", {})
	if typeof(raw) == TYPE_DICTIONARY:
		for key in raw:
			var e: Dictionary = raw[key] if typeof(raw[key]) == TYPE_DICTIONARY else {}
			var marks := {}
			var raw_marks = e.get("marks", {})
			if typeof(raw_marks) == TYPE_DICTIONARY:
				for m in raw_marks:
					marks[str(int(float(m)))] = String(raw_marks[m])
			gathering_log[str(int(float(key)))] = {
				"spoke": (e.get("spoke", []) as Array).map(func(x): return int(x)),
				"toast": bool(e.get("toast", false)), "gift": bool(e.get("gift", false)),
				"gossip_nights": (e.get("gossip_nights", []) as Array).map(func(x): return int(x)),
				"danced_nights": (e.get("danced_nights", []) as Array).map(func(x): return int(x)),
				"marks": marks}
	hosted = {}
	var raw_hosted = data.get("hosted", {})
	if typeof(raw_hosted) == TYPE_DICTIONARY and not raw_hosted.is_empty():
		var ints := func(key: String) -> Array: return (raw_hosted.get(key, []) as Array).map(func(x): return int(x))
		hosted = {"id": int(raw_hosted.get("id", 0)), "place": String(raw_hosted.get("place", "")),
			"kind": String(raw_hosted.get("kind", Gatherings.FEAST)),
			"starts_hour": float(raw_hosted.get("starts_hour", 0.0)),
			"ends_hour": float(raw_hosted.get("ends_hour", 0.0)),
			"guests": ints.call("guests"), "persuade": ints.call("persuade"),
			# An older save's gathering never asks after the absent king.
			"king_seen": bool(raw_hosted.get("king_seen", true)), "absent_done": bool(raw_hosted.get("absent_done", true)),
			"honoured": int(raw_hosted.get("honoured", -1)), "speech": bool(raw_hosted.get("speech", false)),
			"speech_war": bool(raw_hosted.get("speech_war", false)),
			"gifts": bool(raw_hosted.get("gifts", false)), "heard": ints.call("heard"),
			"tourney": (raw_hosted.get("tourney", {}) as Dictionary).duplicate(true) if typeof(raw_hosted.get("tourney", {})) == TYPE_DICTIONARY else {}}
	host_ready_at = float(data.get("host_ready_at", 0.0))
	invites_seen = (data.get("invites_seen", []) as Array).map(func(x): return int(x)) if typeof(data.get("invites_seen")) == TYPE_ARRAY else []


func _clean_captain(c: Dictionary, type: String) -> Dictionary:
	var bonds := {}
	var raw = c.get("bonds", {})
	if typeof(raw) == TYPE_DICTIONARY:
		for k in raw:
			bonds[str(int(float(k)))] = float(raw[k])
	var history := {"wounds": 0, "fallen_friends": [], "scars": []}
	if typeof(c.get("history")) == TYPE_DICTIONARY:
		history["wounds"] = int(c["history"].get("wounds", 0))
		history["fallen_friends"] = c["history"].get("fallen_friends", []) if typeof(c["history"].get("fallen_friends")) == TYPE_ARRAY else []
		history["scars"] = c["history"].get("scars", []) if typeof(c["history"].get("scars")) == TYPE_ARRAY else []
	var clean := {
		"id": int(c.get("id", 0)), "name": String(c.get("name", "Nameless")), "first": String(c.get("first", "Nameless")),
		"culture": String(c.get("culture", Cultures.VARDISH)), "type": type, "temperament": String(c.get("temperament", Captains.STEADFAST)), "quirk": String(c.get("quirk", "")),
		"wounded": int(c.get("wounded", 0)), "battles": int(c.get("battles", 0)), "kills": int(c.get("kills", 0)),
		"specialization": String(c.get("specialization", "")),
		"is_hero": bool(c.get("is_hero", false)),
		"hero_id": String(c.get("hero_id", "")),
		"bonds": bonds, "history": history,
	}
	clean["appearance_id"] = String(c.get("appearance_id", ""))
	Captains.ensure_appearance(clean)
	return clean


func _clean_bond_state() -> void:
	var clean_records := {}
	for raw_key in bond_records:
		var ids := String(raw_key).split("|")
		if ids.size() != 2:
			continue
		var key := _bond_key_ids(int(float(ids[0])), int(float(ids[1])))
		var raw = bond_records[raw_key]
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		clean_records[key] = {
			"shared_battles": int(raw.get("shared_battles", 0)), "last_battle": int(raw.get("last_battle", 0)),
			"last_outcome": String(raw.get("last_outcome", "")), "last_losses": int(raw.get("last_losses", 0)),
			"milestones": raw.get("milestones", []) if typeof(raw.get("milestones")) == TYPE_ARRAY else [],
			"conversations": raw.get("conversations", []) if typeof(raw.get("conversations")) == TYPE_ARRAY else [],
			"losses": raw.get("losses", []) if typeof(raw.get("losses")) == TYPE_ARRAY else [],
		}
	bond_records = clean_records
	var clean_events := []
	for raw in bond_events:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		# Older campaigns queued a screen for every rank and memorial. Only the first
		# bond's introduction still stops you; the rest wait at the fire as new talks.
		if bond_intro_seen or String(raw.get("kind", "rank")) != "rank" or String(raw.get("rank", "")) != "C" or not clean_events.is_empty():
			continue
		var event: Dictionary = raw.duplicate(true)
		event["a_id"] = int(raw.get("a_id", 0))
		event["b_id"] = int(raw.get("b_id", 0))
		event["battle"] = int(raw.get("battle", 0))
		event["shared_battles"] = int(raw.get("shared_battles", 0))
		event["points"] = float(raw.get("points", 0.0))
		clean_events.append(event)
	bond_events = clean_events
	if not bond_events.is_empty():
		_sync_bond_intro_legacy()


func personal_conversation_context() -> Dictionary:
	var sound := get_node_or_null("/root/Sound")
	return {"settlement_id": world.here() if world != null else "",
		"current_hour": world.hour if world != null else 0.0,
		"invitations_enabled": sound.romance_invitations_enabled() if sound != null else true}


func personal_conversation_action(person_id: String, scene_id: String, action: String, choice: int = -1) -> Dictionary:
	if world == null or world.social == null:
		return {"ok": false, "reason": "No active campaign."}
	var before: Dictionary = world.social.to_dict().duplicate(true)
	var result: Dictionary = world.social.personal_action(person_id, scene_id, action, personal_conversation_context(), choice)
	if result.get("ok", false) and not save_game():
		world.social.from_dict(before)
		return {"ok": false, "reason": "Could not save this visit. Your previous progress is unchanged; please try again."}
	return result
