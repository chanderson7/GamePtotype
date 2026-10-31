## The world map as pure logic: no nodes, no drawing. The map screen draws it and feeds
## it orders; tests run it headless.
##
## Parties travel along roads between settlements. Time passes only while the player is
## travelling or waiting, and stops the moment a bandit band blocks the road. Bandit
## bands roam the villages of their own realm, and one that is beaten comes back a day
## later.
##
## Who holds each settlement, which realms are at war and where each realm's capital is
## start as world_data.gd has them, and are the world's own from then on: places change
## hands, and wars begin and end.
extends RefCounted

const Data = preload("res://scripts/world/world_data.gd")
const Captains = preload("res://scripts/data/captains.gd")
const Cultures = preload("res://scripts/data/cultures.gd")
const Troops = preload("res://scripts/data/troops.gd")
const Economy = preload("res://scripts/data/economy.gd")
const Units = preload("res://scripts/data/units.gd")
const Lords = preload("res://scripts/data/lords.gd")
const MarshalArmies = preload("res://scripts/world/marshal_armies.gd")
const AutoResolve = preload("res://scripts/battle/auto_resolve.gd")
const SocialSim = preload("res://scripts/world/social_sim.gd")
const Politics = preload("res://scripts/data/politics.gd")
const Jobs = preload("res://scripts/data/jobs.gd")
const Fiefs = preload("res://scripts/data/fiefs.gd")

## Map units an hour: the player on land and at sea, bandits on land.
const LAND_SPEED := 40.0
const SEA_SPEED := 25.0
const BANDIT_SPEED := 34.0
## A bandit band this close to the player blocks the road.
const ENCOUNTER_RADIUS := 30.0
## A beaten band is replaced this many hours later.
const RESPAWN_HOURS := 24.0
## Hours a band lingers at a village before moving on.
const BANDIT_WAIT_MIN := 2.0
const BANDIT_WAIT_MAX := 6.0
## A chief who got away from you comes back at the head of a new band this long after.
const CHIEF_RETURN_HOURS := 120.0
## The chance a new band is led by a chief: a few at first, more as the weeks go by.
const CHIEF_CHANCE_START := 0.1
const CHIEF_CHANCE_PER_DAY := 0.01
const CHIEF_CHANCE_MAX := 0.3
## After you withdraw from a band, or it beats you, it leaves you alone this long.
const GRACE_HOURS := 2.0
## Hours lost when your warband is beaten and regroups at your capital.
const REGROUP_HOURS := 12.0
## The world moves in steps no longer than this, so nothing slips past an encounter.
const TICK := 0.25
const PLAYER := "player"
const BAND := "bandit"
const LORD := "lord"
const ACTIVITY_LIMIT := 30
const ACTIVITY_TYPES := {
	"war": true, "peace": true, "captured": true, "raid_started": true, "burned": true,
	"driven_off": true, "fight": true, "army_formed": true, "army_departed": true,
	"army_arrived": true, "army_returning": true, "army_disbanded": true, "chief_returned": true,
	"siege_started": true, "siege_assault": true, "siege_repulsed": true,
	"lord_captured": true, "lord_captured_ai": true, "lord_slain": true,
	"ransom_paid": true, "lord_ransomed_ai": true,
	"grudge_avenged": true, "contract_signed": true, "contract_ended": true, "player_victory": true,
	"job_completed": true, "fief_granted": true, "fief_defended": true, "fief_lost": true,
}


class Party:
	var id := 0
	var kind := BAND
	var name := ""
	## The realm a bandit band roams.
	var faction := ""
	## The settlement it stands at, or the one it last left.
	var node := ""
	## The settlement it's heading for on the current road, or "" while standing.
	var next := ""
	## Distance covered along the current road.
	var along := 0.0
	## Settlements still to reach after `next`.
	var path: Array = []
	## Hours left to wait where it stands.
	var wait := 0.0
	## Whether this band is currently raiding a village.
	var raiding := false
	var raid_village := ""
	var is_chief_band := false
	var chief_name := ""
	## A band's fighters, in the battle sim's army format.
	var army: Array = []
	## Until this hour, this band won't block the player's road again.
	var grace_until := -1.0
	## The lord riding with this party (its id in `lords`), or -1.
	var lord := -1

	func moving() -> bool:
		return next != ""


var rng := RandomNumberGenerator.new()
## Hours since the campaign's first midnight. A campaign starts in the morning.
var hour := 0.0
const START_HOUR := 8.0
var culture := Cultures.VARDISH
var parties: Array = []
## Bands waiting to come back: [{faction, at}].
var respawns: Array = []
## Registry of escaped bandit chiefs: [{name, culture, grudge, escaped_at, times_beaten}].
var escaped_chiefs: Array = []
## Track villages successfully defended from raids: {village_id: count}.
var saved_villages: Dictionary = {}
## What happened since the screen last looked: arrived, waited, encounter, respawn.
var events: Array = []
## The recent campaign chronicle. Unlike `events`, these readable entries survive a
## map refresh and a save/load so the player can catch up on the changing world.
var activity_log: Array = []
## The id of the band blocking the player's road, or -1.
var encounter := -1
## The party id of the allied lord/army the player is following, or -1.
var following_party := -1
## GameState back-reference if running under campaign.
var game_state = null
## Recruits each settlement offers: {settlement id: [{type, culture}]}, and the hour each
## settlement's offers come back after any are taken.
var offers := {}
var offers_back := {}
## Local jobs offered at each settlement: {settlement id: [job_dict]}
var settlement_jobs := {}
var settlement_jobs_back := {}
## Who holds each settlement: id → realm. A village goes with the castle or town it's
## bound to.
var owners := {}
## Realms at war, by pair ("kharzan|vardmark") → {since: hour}. Everyone is at war with
## bandits besides.
var wars := {}
## Enforced truces between realms: pair ("kharzan|vardmark") → {until: hour}.
var truces := {}
## Ongoing tribute agreements between realms: [{from, to, daily, days_left}].
var tributes: Array = []
## Each realm's seat and purse: realm → {capital, treasury}. A realm that loses its
## capital moves it.
var realms := {}
## Castle/town id → squads in battle army format. Villages have no standing garrison.
var garrisons := {}
## Social simulation: relationships, court residents, pacts, escrows, and letters.
var social: SocialSim = null
## The lords of the realms, rulers among them: [{id, name, realm, culture, bearing, ruler,
## renown, silver, fief, party, state, back_at, job, target, think_at, raiding, broke_days,
## full, army}]. `party` is the id of his party on the map, or -1 while he regroups (his
## surviving squads wait in `army`).
var lords: Array = []
## Expedition membership references parties; it never duplicates their troops.
var campaign_armies: Array = []
var army_ready_at: Dictionary = {}
var next_army_id := 1
## Villages raiders have burned: id → the hour they're rebuilt.
var burned := {}
## The last day the lords' purses were settled.
var _lord_day := 0
var _next_id := 1
var _adjacent := {}
var _lord_hours := {}
var _path_cache: Dictionary = {}

func clear_path_cache() -> void:
	_path_cache.clear()

func is_sieged(id: String) -> bool:
	for army in campaign_armies:
		if String(army.get("state", "")) == "sieging" and String(army.get("target", "")) == id:
			return true
	return false

func sieging_army(id: String) -> Dictionary:
	for army in campaign_armies:
		if String(army.get("state", "")) == "sieging" and String(army.get("target", "")) == id:
			return army
	return {}


# ---------------------------------------------------------------- setup

## A new world: the player's party stands at their culture's capital, and a bandit
## band roams each realm.
func setup(seed_value: int, player_culture: String) -> void:
	rng.seed = seed_value
	culture = player_culture
	hour = START_HOUR
	events = []
	activity_log = []
	clear_path_cache()
	_build_roads()
	_start_realms()
	var p := Party.new()
	p.id = _take_id()
	p.kind = PLAYER
	p.name = "Your warband"
	p.node = Data.capital_of_culture(culture)
	parties.append(p)
	for faction in Data.BANDIT_BANDS:
		for k in Data.BANDIT_BANDS[faction].size():
			_spawn_band(faction)
	for id in Data.SETTLEMENTS:
		offers[id] = _new_offers(id)
	_spawn_lords()
	_start_garrisons()
	social = SocialSim.new()
	social.setup(seed_value, lords, Data.SETTLEMENTS)
	_lord_day = int(hour / 24.0)


## The map as it stands at the start of a campaign: every place in its first owner's
## hands, the first wars, each realm's capital where world_data.gd puts it.
func _start_realms() -> void:
	owners = {}
	for id in Data.SETTLEMENTS:
		owners[id] = String(Data.SETTLEMENTS[id]["faction"])
	wars = {}
	for w in Data.WARS:
		wars[war_key(w[0], w[1])] = {"since": 0.0}
	realms = {}
	for f in Data.FACTIONS:
		if f != Data.BANDITS:
			realms[f] = {
				"capital": String(Data.FACTIONS[f]["capital"]),
				"treasury": Lords.TREASURY_START,
				"marshal": -1,
				"weariness": 0.0,
			}
	truces = {}
	tributes = []


func _build_roads() -> void:
	_adjacent = {}
	for id in Data.SETTLEMENTS:
		_adjacent[id] = []
	for r in Data.ROADS:
		_adjacent[r[0]].append([r[1], r[2]])
		_adjacent[r[1]].append([r[0], r[2]])


func _take_id() -> int:
	var id := _next_id
	_next_id += 1
	return id


# ---------------------------------------------------------------- realms

## The realm holding settlement `id`.
func owner_of(id: String) -> String:
	return String(owners.get(id, Data.settlement(id)["faction"]))


## Every settlement realm `realm` holds; only its villages with `type` VILLAGE.
func holdings_of(realm: String, type: String = "") -> Array:
	var out := []
	for id in Data.SETTLEMENTS:
		if owner_of(id) == realm and (type == "" or Data.settlement(id)["type"] == type):
			out.append(id)
	return out


func villages_of(realm: String) -> Array:
	return holdings_of(realm, Data.VILLAGE)


## Where realm `realm` rules from, or "" if it holds no castle or town.
func capital_of(realm: String) -> String:
	return String(realms.get(realm, {}).get("capital", ""))


static func war_key(a: String, b: String) -> String:
	return "%s|%s" % [a, b] if a < b else "%s|%s" % [b, a]


func at_war(a: String, b: String) -> bool:
	if a == b:
		return false
	if a == Data.BANDITS or b == Data.BANDITS:
		return true
	return wars.has(war_key(a, b))


func is_at_war(realm: String) -> bool:
	for key in wars:
		var parts: PackedStringArray = key.split("|")
		if parts.has(realm):
			return true
	return false


func _active_game_state():
	if game_state != null:
		return game_state
	var tree = Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null and tree.root.has_node("GameState"):
		return tree.root.get_node("GameState")
	return null


func relation_to_player(realm: String) -> String:
	var gs = _active_game_state()
	if gs != null:
		if gs.is_at_war_with(realm):
			return "hostile"
		if gs.is_allied_with(realm):
			return "friendly"
	var p = player()
	if p != null and p.faction != "":
		if p.faction == realm:
			return "friendly"
		if at_war(p.faction, realm):
			return "hostile"
	var player_realm := Data.realm_of_culture(culture)
	if realm == player_realm:
		return "friendly"
	return "neutral"


func has_truce(a: String, b: String) -> bool:
	if a == b:
		return false
	var key := war_key(a, b)
	if not truces.has(key):
		return false
	return hour < float(truces[key].get("until", 0.0))


func truce_until(a: String, b: String) -> float:
	var key := war_key(a, b)
	return float(truces.get(key, {}).get("until", 0.0))


func add_weariness(realm: String, amount: float) -> void:
	if not realms.has(realm):
		return
	var cur: float = float(realms[realm].get("weariness", 0.0))
	realms[realm]["weariness"] = clampf(cur + amount, 0.0, Politics.WEARINESS_MAX)


func weariness_of(realm: String) -> float:
	return float(realms.get(realm, {}).get("weariness", 0.0))


func mainland_seats_of(realm: String) -> int:
	var count := 0
	for seat in Politics.MAINLAND_SEATS:
		if owner_of(seat) == realm:
			count += 1
	return count


func lords_of(realm: String) -> Array:
	var out := []
	for l in lords:
		if l.get("realm", "") == realm:
			out.append(l)
	return out


func realm_strength(realm: String) -> int:
	var total := 0
	for l in lords_of(realm):
		var p := party(int(l.get("party", -1)))
		if p != null:
			total += men_of(p.army)
		else:
			total += men_of(l.get("army", []))
	for h in holdings_of(realm):
		total += men_of(garrison_at(h))
	return total


func declare_war(a: String, b: String, force: bool = false, reason: String = "") -> void:
	if a != b and not at_war(a, b):
		if not force and has_truce(a, b):
			return
		wars[war_key(a, b)] = {"since": hour}
		var ev := {"type": "war", "realms": [a, b]}
		if reason != "":
			ev["reason"] = reason
		emit_event(ev)


func make_peace(a: String, b: String, truce_days: int = Politics.TRUCE_DAYS, tribute_daily: int = 0, tribute_from: String = "", tribute_days: int = Politics.TRIBUTE_DAYS) -> void:
	if wars.erase(war_key(a, b)):
		if truce_days > 0:
			truces[war_key(a, b)] = {"until": hour + truce_days * 24.0}
		if tribute_daily > 0 and tribute_from != "":
			var tribute_to := b if tribute_from == a else a
			tributes.append({
				"from": tribute_from,
				"to": tribute_to,
				"daily": tribute_daily,
				"days_left": tribute_days,
			})
		emit_event({
			"type": "peace",
			"realms": [a, b],
			"truce_days": truce_days,
			"tribute_from": tribute_from,
			"tribute_daily": tribute_daily,
			"tribute_days": tribute_days,
		})


## Settlement `id` passes to `realm`, with the villages bound to it. A realm that loses its
## capital rules from its best remaining place: a town if it has one, else a castle.
func set_owner(id: String, realm: String) -> void:
	var was := owner_of(id)
	if was == realm:
		return
	owners[id] = realm
	clear_path_cache()
	if Data.settlement(id)["type"] in [Data.CASTLE, Data.TOWN]:
		if realms.has(was):
			add_weariness(was, Politics.WEARINESS_LOST_HOLDING)
		if realms.has(realm):
			add_weariness(realm, -5.0)
	# Defenders don't change allegiance with their walls. A future siege leaves its
	# survivors here after the transfer; until then the new owner must recruit guards.
	if garrisons.has(id):
		garrisons[id] = []
	for l in lords:
		if l.get("fief", "") == id and l.get("realm", "") == was:
			l["fief"] = ""
	for v in Data.SETTLEMENTS:
		if String(Data.SETTLEMENTS[v].get("bound_to", "")) == id:
			owners[v] = realm
	if capital_of(was) == id:
		var seat := ""
		for kind in [Data.TOWN, Data.CASTLE]:
			var held := holdings_of(was, kind)
			if not held.is_empty():
				seat = held[0]
				break
		realms[was]["capital"] = seat
	emit_event({"type": "captured", "settlement": id, "realm": realm, "from": was})
	if social != null:
		social.on_settlement_captured(id, realm, was, self)
	if game_state != null and game_state.has_method("_on_fief_transferred"):
		game_state._on_fief_transferred(id, realm, was)


## "Castle of the Kingdom of Vardmark · Vardish": what a place is, whose it is now, and who
## lives there (its people don't change with its owner).
func describe(id: String) -> String:
	var s := Data.settlement(id)
	var realm := owner_of(id)
	var faction: Dictionary = Data.FACTIONS[realm]
	var line := "%s of the %s" % [String(s["type"]).capitalize(), faction["name"]]
	if capital_of(realm) == id:
		line = "Capital of the %s, seat of %s" % [faction["name"], faction["ruler"]]
	var people: String = Cultures.info(Data.culture_of(s["faction"]))["people"]
	if garrisons.has(id):
		people += " · garrison %d/%d men" % [men_of(garrison_at(id)), garrison_capacity(id)]
	if is_burned(id):
		return "%s · %s · burned by raiders, rebuilding" % [line, people]
	return "%s · %s" % [line, people]


## Information a commander can see before entering: ownership, strength, danger,
## services and strategic value. It deliberately describes only actions the game has.
func settlement_intelligence(id: String) -> String:
	var owner := owner_of(id)
	var lines: Array[String] = []
	lines.append("Owner: %s" % Data.FACTIONS[owner]["name"])
	if garrisons.has(id):
		var men := men_of(garrison_at(id))
		var cap := garrison_capacity(id)
		var strength := "thin" if men < cap * 0.4 else ("strong" if men >= cap * 0.8 else "steady")
		lines.append("Garrison: %d/%d men · %s" % [men, cap, strength])
	else:
		lines.append("Garrison: none")
	var player_rel := relation_to_player(owner)
	var danger := "hostile territory; patrols may oppose you" if player_rel == "hostile" else "quiet roads"
	if is_burned(id):
		danger = "burned by raiders; rebuilding"
	else:
		for p in parties:
			if p.raiding and p.raid_village == id:
				danger = "raid in progress"
				break
		for army in campaign_armies:
			if String(army.get("target", "")) == id and String(army.get("state", "")) != "returning":
				if String(army.get("state", "")) == "besieging":
					var prep_left := maxf(0.0, float(army.get("siege_prep_until", 0.0)) - hour)
					danger = "under siege by %s (assault in %d hrs)" % [Data.FACTIONS[army["realm"]]["name"], int(ceil(prep_left))]
				else:
					danger = "marshal army advancing here"
				break
	lines.append("Danger: %s" % danger)
	var service_names: Array = Data.services(id)
	var recruit_count := offers_at(id).size()
	lines.append("Services: %s · %d recruit %s available" % [", ".join(service_names), recruit_count,
		"company" if recruit_count == 1 else "companies"])
	lines.append("Why it matters: %s" % Data.importance(id))
	return "\n".join(lines)


## Publish a transient simulation event and, when it matters to the campaign, a short
## readable chronicle entry.
func emit_event(event: Dictionary) -> void:
	events.append(event)
	var kind := String(event.get("type", ""))
	if not ACTIVITY_TYPES.has(kind):
		return
	var line := _activity_text(event)
	if line == "":
		return
	var place := String(event.get("settlement", event.get("village", event.get("target", event.get("at", "")))))
	var cat := "war"
	match kind:
		"war", "peace":
			cat = "war"
		"siege_started", "siege_assault", "siege_repulsed", "captured", "burned", "raid_started", "driven_off":
			cat = "siege"
		"grudge_avenged", "contract_signed", "contract_ended", "player_victory", "job_completed", "fief_granted", "fief_defended", "fief_lost":
			cat = "deed"
		"fight", "lord_captured", "lord_captured_ai", "lord_slain", "ransom_paid", "lord_ransomed_ai", "chief_returned":
			cat = "battle"
		_:
			cat = "war"
	activity_log.push_front({
		"hour": hour,
		"type": kind,
		"category": cat,
		"text": line,
		"place": place,
	})
	if activity_log.size() > ACTIVITY_LIMIT:
		activity_log.resize(ACTIVITY_LIMIT)


func _activity_text(event: Dictionary) -> String:
	var kind := String(event.get("type", ""))
	match kind:
		"war", "peace":
			var pair: Array = event.get("realms", [])
			if pair.size() >= 2:
				var r0: String = Data.FACTIONS[String(pair[0])]["name"]
				var r1: String = Data.FACTIONS[String(pair[1])]["name"]
				if kind == "war":
					var reason: String = event.get("reason", "")
					if reason == "balance of power":
						return "%s declared war on %s to preserve the balance of power." % [r0, r1]
					return "%s and %s are now at war." % [r0, r1]
				else:
					var tf: String = String(event.get("tribute_from", ""))
					var td: int = int(event.get("tribute_daily", 0))
					var days: int = int(event.get("tribute_days", 0))
					if td > 0 and tf != "":
						var loser_name: String = Data.FACTIONS[tf]["name"]
						return "%s and %s make peace; %s pays %d silver a day for %d days." % [r0, r1, loser_name, td, days]
					return "%s and %s have made peace." % [r0, r1]
		"captured":
			return "%s captured %s from %s." % [Data.FACTIONS[String(event["realm"])]["name"],
				Data.settlement(String(event["settlement"]))["name"], Data.FACTIONS[String(event["from"])]["name"]]
		"raid_started":
			return "Raiders struck %s." % Data.settlement(String(event["village"]))["name"]
		"burned":
			return "%s was burned by %s." % [Data.settlement(String(event["village"]))["name"], event.get("by", "raiders")]
		"driven_off":
			return "%s drove raiders away from %s." % [event.get("by", "Defenders"), Data.settlement(String(event["village"]))["name"]]
		"fight":
			var where := String(event.get("at", ""))
			return "%s defeated %s%s." % [event.get("winner", "A warband"), event.get("loser", "its foe"),
				" near %s" % Data.settlement(where)["name"] if Data.SETTLEMENTS.has(where) else ""]
		"army_formed":
			return "%s called a marshal army under %s, bound for %s." % [Data.FACTIONS[String(event["realm"])]["name"],
				event.get("marshal", "its marshal"), Data.settlement(String(event["target"]))["name"]]
		"army_departed":
			return "A marshal army departed for %s." % Data.settlement(String(event["target"]))["name"]
		"army_arrived":
			return "A marshal army reached %s." % Data.settlement(String(event["target"]))["name"]
		"army_returning":
			return "%s's marshal army is returning to %s." % [Data.FACTIONS[String(event["realm"])]["name"],
				Data.settlement(String(event["target"]))["name"]]
		"army_disbanded":
			return "%s's marshal army dispersed: %s." % [Data.FACTIONS[String(event["realm"])]["name"], event.get("reason", "the campaign ended")]
		"chief_returned":
			return "%s has returned at the head of a band." % event.get("chief", "A bandit chief")
		"siege_started":
			return "%s laid siege to %s." % [Data.FACTIONS.get(String(event.get("realm", "")), {}).get("name", "An army"),
				Data.settlement(String(event.get("target", "")))["name"]]
		"siege_assault":
			var where := String(event.get("target", ""))
			var p_name: String = String(Data.settlement(where)["name"]) if Data.SETTLEMENTS.has(where) else "the walls"
			if bool(event.get("attacker_won", false)):
				return "The walls of %s were breached and taken in an assault." % p_name
			else:
				return "The assault on %s was repulsed by the garrison." % p_name
		"siege_repulsed":
			var where := String(event.get("target", ""))
			var p_name: String = String(Data.settlement(where)["name"]) if Data.SETTLEMENTS.has(where) else "the fortress"
			return "The siege of %s was lifted after defenders repulsed the attackers." % p_name
		"lord_captured":
			return "%s was taken prisoner by %s." % [event.get("lord", "A lord"), event.get("captor", "their foe")]
		"lord_captured_ai":
			return "%s was taken prisoner in battle by %s." % [event.get("lord", "A lord"), event.get("by", "an enemy")]
		"lord_slain":
			return "%s fell in battle against %s. An heir takes up their sword." % [event.get("lord", "A lord"), event.get("by", "their foe")]
		"ransom_paid", "lord_ransomed_ai":
			return "%s was ransomed for %d silver and returns to his hall." % [event.get("lord", "A lord"), int(event.get("amount", 0))]
		"grudge_avenged":
			return "Vengeance answered! %s struck down %s for past blood." % [event.get("company", "The warband"), event.get("lord", "the enemy lord")]
		"contract_signed":
			var r_name: String = Data.FACTIONS.get(event.get("realm", ""), {}).get("name", event.get("realm", ""))
			return "%s signed a 30-day mercenary contract with %s." % [event.get("company", "The warband"), r_name]
		"contract_ended":
			var r_name: String = Data.FACTIONS.get(event.get("realm", ""), {}).get("name", event.get("realm", ""))
			return "%s fulfilled their contract with %s with honour." % [event.get("company", "The warband"), r_name]
		"player_victory":
			var at := String(event.get("at", ""))
			var place_str := (" near %s" % Data.settlement(at)["name"]) if Data.SETTLEMENTS.has(at) else ""
			return "%s crushed %s%s." % [event.get("company", "The warband"), event.get("enemy", "the enemy"), place_str]
		"job_completed":
			return "%s completed the contract '%s'." % [event.get("company", "The warband"), event.get("title", "Contract")]
		"fief_granted":
			var s_id: String = String(event.get("settlement", ""))
			var s_name := String(Data.settlement(s_id)["name"]) if Data.SETTLEMENTS.has(s_id) else "a fief"
			return "%s was granted lordship of %s as a vassal of the %s." % [
				event.get("company", "The warband"),
				s_name,
				Data.FACTIONS.get(event.get("realm", ""), {}).get("name", "crown")
			]
		"fief_defended":
			var s_id: String = String(event.get("settlement", ""))
			var s_name := String(Data.settlement(s_id)["name"]) if Data.SETTLEMENTS.has(s_id) else "the estate"
			return "The defenders of %s repulsed the raiding party of %s." % [
				s_name,
				event.get("enemy", "raiders")
			]
		"fief_lost":
			var s_id: String = String(event.get("settlement", ""))
			var s_name := String(Data.settlement(s_id)["name"]) if Data.SETTLEMENTS.has(s_id) else "A fief"
			return "%s has fallen to %s!" % [
				s_name,
				event.get("by", "the enemy")
			]
	return ""


# ---------------------------------------------------------------- queries

func player() -> Party:
	return parties[0]


var _parties_by_id: Dictionary = {}
var _bands: Array = []
var _lord_parties: Array = []


func _reindex_parties() -> void:
	_parties_by_id.clear()
	_bands.clear()
	_lord_parties.clear()
	for p in parties:
		_parties_by_id[p.id] = p
		if p.kind == BAND:
			_bands.append(p)
		elif p.kind == LORD:
			_lord_parties.append(p)


func _sync_party_indices() -> void:
	if _parties_by_id.size() != parties.size():
		_reindex_parties()


func party(id: int) -> Party:
	_sync_party_indices()
	return _parties_by_id.get(id)


func bands() -> Array:
	_sync_party_indices()
	return _bands.duplicate()


## The lords' parties on the map.
func lord_parties() -> Array:
	_sync_party_indices()
	return _lord_parties.duplicate()


## Joined lords share one visible marker, but retain their authoritative parties.
func visible_lord_parties() -> Array:
	if campaign_armies.is_empty():
		return lord_parties()
	var hidden := {}
	for army in campaign_armies:
		if army["state"] != "gathering":
			var leader_id: int = int(army["leader"])
			for m_id in army["members"]:
				if m_id != leader_id:
					hidden[m_id] = true
	if hidden.is_empty():
		return lord_parties()
	return lord_parties().filter(func(p): return not hidden.has(p.id))


func army_parties(p: Party) -> Array:
	var army := MarshalArmies.for_party(self, p.id)
	return [p] if army.is_empty() or army["state"] == "gathering" else MarshalArmies.members(self, army)


func lord_of(p: Party) -> Dictionary:
	return lords[p.lord] if p != null and p.lord >= 0 and p.lord < lords.size() else {}


## Where a party is on the map.
func party_pos(p: Party) -> Vector2:
	var a := Data.pos(p.node)
	if not p.moving():
		return a
	var b := Data.pos(p.next)
	return a.lerp(b, clampf(p.along / maxf(1.0, road_length(p.node, p.next)), 0.0, 1.0))


## The settlement the player stands at, or "" on the road.
func here() -> String:
	var p := player()
	return "" if p.moving() else p.node


func player_in_town() -> bool:
	return here() != "" and Data.settlement(here())["type"] == Data.TOWN


## Where the player is headed, or "" if nowhere.
func destination() -> String:
	var p := player()
	if not p.path.is_empty():
		return String(p.path.back())
	return p.next


## The clock runs while the player travels or waits, unless a band blocks the road.
func busy() -> bool:
	var p := player()
	if following_party != -1:
		var target := party(following_party)
		if target != null and (target.moving() or target.wait > 0.0):
			return encounter == -1
	return encounter == -1 and (p.moving() or p.wait > 0.0)


var _sea_roads := {}

func is_sea(a: String, b: String) -> bool:
	var key := a + "|" + b
	if _sea_roads.has(key):
		return bool(_sea_roads[key])
	for n in _adjacent.get(a, []):
		if n[0] == b:
			var s := bool(n[1])
			_sea_roads[key] = s
			return s
	_sea_roads[key] = false
	return false


var _road_lengths := {}

func road_length(a: String, b: String) -> float:
	var key := a + "|" + b
	var len_val = _road_lengths.get(key)
	if len_val != null:
		return float(len_val)
	var d := Data.pos(a).distance_to(Data.pos(b))
	_road_lengths[key] = d
	_road_lengths[b + "|" + a] = d
	return d


func _speed(p: Party, a: String, b: String) -> float:
	if p.kind == BAND:
		return BANDIT_SPEED
	if is_sea(a, b):
		return SEA_SPEED
	return Lords.SPEED if p.kind == LORD else LAND_SPEED


## The quickest way from `from` to `to` by road, as the settlements to pass through
## (not counting `from`). Bands keep to the land of their own realm.
func path(from: String, to: String, band_realm: String = "") -> Array:
	if from == to or not _adjacent.has(from) or not _adjacent.has(to):
		return []
	var cache_key := "%s|%s|%s" % [from, to, band_realm]
	if _path_cache.has(cache_key):
		return (_path_cache[cache_key] as Array).duplicate()
	var cost := {from: 0.0}
	var prev := {}
	var open := [from]
	var done := {}
	while not open.is_empty():
		var best := 0
		for i in open.size():
			if cost[open[i]] < cost[open[best]]:
				best = i
		var cur: String = open[best]
		open.remove_at(best)
		if cur == to:
			break
		done[cur] = true
		for n in _adjacent[cur]:
			var nxt: String = n[0]
			if done.has(nxt):
				continue
			if band_realm != "" and (bool(n[1]) or owner_of(nxt) != band_realm):
				continue
			var speed := BANDIT_SPEED if band_realm != "" else (SEA_SPEED if bool(n[1]) else LAND_SPEED)
			var c: float = cost[cur] + road_length(cur, nxt) / speed
			if not cost.has(nxt) or c < cost[nxt]:
				cost[nxt] = c
				prev[nxt] = cur
				if not open.has(nxt):
					open.append(nxt)
	if not prev.has(to):
		_path_cache[cache_key] = []
		return []
	var out := [to]
	while prev[out[0]] != from:
		out.push_front(prev[out[0]])
	_path_cache[cache_key] = out
	return out.duplicate()


## Hours for the player to ride `route` starting from `from`.
func route_hours(from: String, route: Array) -> float:
	var hours := 0.0
	var a := from
	for b in route:
		hours += road_length(a, b) / (SEA_SPEED if is_sea(a, b) else LAND_SPEED)
		a = b
	return hours


## Hours the player would take to reach `to` from where they are now.
func hours_to(to: String) -> float:
	var p := player()
	if not p.moving():
		return route_hours(p.node, path(p.node, to))
	var onward := (road_length(p.node, p.next) - p.along) / _speed(p, p.node, p.next)
	var back := p.along / _speed(p, p.node, p.next)
	return minf(onward + (route_hours(p.next, path(p.next, to)) if to != p.next else 0.0),
		back + (route_hours(p.node, path(p.node, to)) if to != p.node else 0.0))


# ---------------------------------------------------------------- orders

## Set the player off for `to`. From the middle of a road it turns back if that's quicker.
func travel(to: String) -> bool:
	following_party = -1
	var p := player()
	if encounter != -1 or not Data.SETTLEMENTS.has(to):
		return false
	p.wait = 0.0
	if p.moving():
		var onward := (road_length(p.node, p.next) - p.along) / _speed(p, p.node, p.next)
		var back := p.along / _speed(p, p.node, p.next)
		var via_next := onward + (route_hours(p.next, path(p.next, to)) if to != p.next else 0.0)
		var via_back := back + (route_hours(p.node, path(p.node, to)) if to != p.node else 0.0)
		if via_back < via_next:
			var length := road_length(p.node, p.next)
			var was := p.node
			p.node = p.next
			p.next = was
			p.along = length - p.along
		p.path = path(p.next, to) if to != p.next else []
		return true
	if to == p.node:
		return false
	var route := path(p.node, to)
	if route.is_empty():
		return false
	p.next = route.pop_front()
	p.along = 0.0
	p.path = route
	return true


## Stand where you are for `hours`.
func wait(hours: float) -> bool:
	following_party = -1
	var p := player()
	if p.moving() or encounter != -1:
		return false
	p.wait = hours
	return true


# ---------------------------------------------------------------- time

## Let up to `hours` pass. Time only moves while the player travels or waits, and stops
## at an encounter.
func step(hours: float) -> void:
	var left := hours
	while left > 0.000001 and busy():
		var dt := minf(TICK, left)
		left -= dt
		hour += dt
		_move_player(dt)
		for b in bands():
			_move_band(b, dt)
		_step_lords(dt)
		if social != null:
			social.step(dt, self)
		_respawn()
		_check_encounter()


func _move_player(dt: float) -> void:
	var p := player()
	if following_party != -1:
		var target := party(following_party)
		if target == null or (target.kind == LORD and lord_of(target).get("state", "") != "field"):
			following_party = -1
		else:
			p.node = target.node
			p.next = target.next
			p.along = target.along
			p.path = target.path.duplicate()
			p.wait = target.wait
			return
	if p.moving():
		if _move(p, dt):
			emit_event({"type": "arrived", "at": p.node})
	elif p.wait > 0.0:
		p.wait = maxf(0.0, p.wait - dt)
		if p.wait <= 0.0:
			emit_event({"type": "waited", "at": p.node})


## Move a party along its roads for `dt` hours. True if it reached the end of its path.
func _move(p: Party, dt: float) -> bool:
	var time := dt
	while time > 0.0 and p.moving():
		var speed := _speed(p, p.node, p.next)
		var need := (road_length(p.node, p.next) - p.along) / speed
		if time + 0.000001 < need:
			p.along += speed * time
			return false
		time -= need
		p.node = p.next
		p.along = 0.0
		p.next = "" if p.path.is_empty() else String(p.path.pop_front())
	return not p.moving()


func _move_band(b: Party, dt: float) -> void:
	if b.moving():
		if _move(b, dt):
			b.wait = rng.randf_range(BANDIT_WAIT_MIN, BANDIT_WAIT_MAX)
			if Data.is_village(b.node) and rng.randf() < 0.35:
				b.raiding = true
				b.raid_village = b.node
				b.wait = rng.randf_range(4.0, 8.0)
				emit_event({"type": "raid_started", "party": b.id, "village": b.node, "hours": b.wait})
		return
	if b.wait > 0.0:
		b.wait = maxf(0.0, b.wait - dt)
		return
	if b.raiding:
		b.raiding = false
		b.raid_village = ""
	var choices: Array = villages_of(b.faction).filter(func(v): return v != b.node)
	if choices.is_empty():
		b.wait = BANDIT_WAIT_MAX
		return
	var route := path(b.node, choices[rng.randi_range(0, choices.size() - 1)], b.faction)
	if route.is_empty():
		b.wait = BANDIT_WAIT_MAX
		return
	b.next = route.pop_front()
	b.along = 0.0
	b.path = route


func _check_encounter() -> void:
	var at := party_pos(player())
	var reach_sq := ENCOUNTER_RADIUS * ENCOUNTER_RADIUS
	for b in bands():
		if hour >= b.grace_until and party_pos(b).distance_squared_to(at) <= reach_sq:
			encounter = b.id
			emit_event({"type": "encounter", "party": b.id})
			return
	for lp in lord_parties():
		if lp.id == following_party:
			continue
		if hour >= lp.grace_until and party_pos(lp).distance_squared_to(at) <= reach_sq:
			var rel := relation_to_player(lp.faction)
			if rel == "hostile":
				encounter = lp.id
				emit_event({"type": "encounter", "party": lp.id})
				return
			elif rel == "friendly":
				encounter = lp.id
				lp.grace_until = hour + 12.0
				emit_event({"type": "friendly_encounter", "party": lp.id})
				return


func _respawn() -> void:
	for r in respawns.duplicate():
		if hour >= float(r["at"]):
			respawns.erase(r)
			_spawn_band(String(r["faction"]))


func _generate_chief_name(cult: String) -> String:
	match cult:
		Cultures.KHARZANI:
			var names := ["Tariq the Scarred", "Malik the Swift", "Kadir Bone-breaker", "Jamil the Falcon", "Bashir Red-hand"]
			return names[rng.randi_range(0, names.size() - 1)]
		Cultures.RYUMON:
			var names := ["Kenji the Demon", "Raiden the Exile", "Hidetora Kuro", "Masaru the Wolf", "Kojiro Iron-will"]
			return names[rng.randi_range(0, names.size() - 1)]
		_:
			var names := ["Rask the Red", "Torvald Iron-hand", "Brand the Wolf", "Gunnar the Reaver", "Erik Blood-axe"]
			return names[rng.randi_range(0, names.size() - 1)]


func _spawn_band(faction: String) -> void:
	var names: Array = Data.BANDIT_BANDS[faction].duplicate()
	var at_large := 0
	for b in bands():
		if b.faction == faction:
			at_large += 1
			names.erase(b.name)
	if at_large >= Data.BANDIT_BANDS[faction].size():
		return
	var villages := villages_of(faction)
	if villages.is_empty():
		# A realm with no villages left has no band either, until it wins one back.
		respawns.append({"faction": faction, "at": hour + RESPAWN_HOURS})
		return
	var b := Party.new()
	b.id = _take_id()
	b.kind = BAND
	b.faction = faction
	var band_cult := Data.culture_of(faction)
	b.node = villages[rng.randi_range(0, villages.size() - 1)]
	b.wait = rng.randf_range(BANDIT_WAIT_MIN, BANDIT_WAIT_MAX)
	b.grace_until = hour + 1.0

	var chief_to_return = null
	for i in escaped_chiefs.size():
		var ec: Dictionary = escaped_chiefs[i]
		if ec.get("culture", "") == band_cult and hour >= float(ec.get("escaped_at", 0.0)) + CHIEF_RETURN_HOURS:
			chief_to_return = ec
			escaped_chiefs.remove_at(i)
			break

	if chief_to_return != null:
		b.is_chief_band = true
		b.chief_name = String(chief_to_return["name"])
		b.name = "%s's Host" % b.chief_name
		b.army = _band_army(b.id, band_cult, true, chief_to_return)
		emit_event({"type": "chief_returned", "party": b.id, "chief": chief_to_return})
	else:
		var day := int(hour / 24.0)
		var chief_chance := minf(CHIEF_CHANCE_MAX, CHIEF_CHANCE_START + float(day) * CHIEF_CHANCE_PER_DAY)
		if rng.randf() < chief_chance:
			b.is_chief_band = true
			b.chief_name = _generate_chief_name(band_cult)
			b.name = "%s's Band" % b.chief_name
			b.army = _band_army(b.id, band_cult, true, {"name": b.chief_name, "grudge": 0})
		else:
			b.name = String(names[0])
			b.army = _band_army(b.id, band_cult)

	parties.append(b)
	emit_event({"type": "respawn", "party": b.id})


## Three to five squads of eight to fourteen men, mostly foot and bows, never more than
## one squad of horse, led by captains of the realm's culture. As days pass, bands
## field tier-2 units more often. If led by a chief, fields a tier-2 bodyguard.
func _band_army(band_id: int, band_culture: String, with_chief: bool = false, chief_data: Dictionary = {}) -> Array:
	var out := []
	var taken := []
	var horse := false
	var day := int(hour / 24.0)
	var tier2_chance := clampf(float(day) * 0.02, 0.0, 0.40)
	var squad_count := rng.randi_range(3, 5)
	if with_chief:
		squad_count = maxi(4, squad_count + 1)
	for i in squad_count:
		var roll := rng.randf()
		var type := Troops.INFANTRY
		if roll > 0.9 and not horse:
			type = Troops.CAVALRY
			horse = true
		elif roll > 0.7:
			type = Troops.SPEARMEN
		elif roll > 0.4:
			type = Troops.ARCHERS
		var id := 5000 + band_id * 10 + i
		var captain := Captains.make(rng, 900000 + id, type, taken, band_culture)
		taken.append(captain["first"])
		var unit_id := Units.recruit(band_culture, type)
		var level := 1
		var xp := 0
		var is_bg := false
		var is_ch := false
		var c_name := ""
		if with_chief and i == 0:
			is_bg = true
			is_ch = true
			c_name = String(chief_data.get("name", "Bandit Chief"))
			captain["name"] = c_name
			captain["first"] = c_name.split(" ")[0]
			level = 2
			xp = Troops.XP_PER_LEVEL
			var branch_options := Units.branches(unit_id)
			if not branch_options.is_empty():
				unit_id = branch_options[0]
		elif rng.randf() < tier2_chance:
			var branch_options := Units.branches(unit_id)
			if not branch_options.is_empty():
				unit_id = branch_options[rng.randi_range(0, branch_options.size() - 1)]
				level = 2
				xp = Troops.XP_PER_LEVEL
		var men := rng.randi_range(8, 14)
		if is_bg:
			men = rng.randi_range(12, 16)
		out.append({"id": id, "type": type, "unit": unit_id, "level": level, "xp": xp,
			"men": men, "culture": band_culture,
			"name": ("%s's Bodyguard" % c_name) if is_bg else Captains.company_name(captain, type),
			"captain": captain,
			"is_bodyguard": is_bg, "is_chief": is_ch, "chief_name": c_name})
	return out


# ---------------------------------------------------------------- garrisons

func garrison_at(id: String) -> Array:
	return garrisons.get(id, [])


func garrison_capacity(id: String) -> int:
	var total := 0
	for sq in _garrison_template(id):
		total += Units.full_size(String(sq["unit"]))
	return total


## Fixed slots give rebuilt squads stable ids without consuming the world's random
## stream. Recruits are the settlement's people, even under a foreign owner.
func _garrison_template(id: String) -> Array:
	var kind := String(Data.settlement(id)["type"])
	var roles: Array = Lords.GARRISON_ROLES.get(kind, [])
	var cult := Data.culture_of(String(Data.settlement(id)["faction"]))
	var out := []
	for i in roles.size():
		var type := String(roles[i])
		var unit := Units.recruit(cult, type)
		var level := 1
		if i < int(Lords.GARRISON_TRAINED[kind]):
			unit = Units.branches(unit)[0]
			level = 2
		out.append({"id": 8000000 + Data.SETTLEMENTS.keys().find(id) * 100 + i,
			"type": type, "unit": unit, "culture": cult, "level": level,
			"xp": Troops.XP_PER_LEVEL if level > 1 else 0, "men": 0,
			"name": "%s guard" % Data.settlement(id)["name"], "captain": null})
	return out


## New campaigns and pre-garrison saves start with the same standing guards, for free.
func _start_garrisons() -> void:
	garrisons = {}
	for id in Data.SETTLEMENTS:
		var army := _garrison_template(id)
		if army.is_empty():
			continue
		for sq in army:
			sq["men"] = int(Units.full_size(String(sq["unit"])) * Lords.GARRISON_START_SHARE)
		garrisons[id] = army


## Refill survivors first, then replace missing squads, up to the settlement's cap.
## Buy only affordable men; an empty treasury neither creates troops nor goes negative.
func _garrisons_day() -> void:
	for id in garrisons:
		var army: Array = garrisons[id]
		var kind := String(Data.settlement(id)["type"])
		if not Lords.GARRISON_RECRUITS_PER_DAY.has(kind):
			continue
		var budget := mini(int(Lords.GARRISON_RECRUITS_PER_DAY[kind]),
			garrison_capacity(id) - men_of(army))
		var realm: Dictionary = realms[owner_of(id)]
		var candidates := army.duplicate()
		for sq in _garrison_template(id):
			if not army.any(func(have): return int(have["id"]) == int(sq["id"])):
				candidates.append(sq)
		for sq in candidates:
			if budget <= 0:
				break
			var unit := String(sq["unit"])
			var add := mini(budget, Units.full_size(unit) - int(sq["men"]))
			var available := maxi(0, int(realm["treasury"]) - Lords.TREASURY_RESERVE)
			var unit_cost := int(Economy.recruit_cost(unit, 1))
			var escrow_paid := 0
			if social != null:
				escrow_paid = social.consume_escrow_for_recruitment(id, "settlement", add, unit_cost)
			var total_cost := Economy.recruit_cost(unit, add)
			var realm_cost := maxi(0, total_cost - escrow_paid)
			while add > 0 and realm_cost > available:
				add -= 1
				total_cost = Economy.recruit_cost(unit, add)
				realm_cost = maxi(0, total_cost - escrow_paid)
			if add <= 0:
				continue
			if not army.has(sq):
				army.append(sq)
			realm["treasury"] = int(realm["treasury"]) - realm_cost
			sq["men"] = int(sq["men"]) + add
			budget -= add


# ---------------------------------------------------------------- lords

## Each realm's ruler, at its capital, and its lords: the first two hold its castles, the
## rest serve for a stipend and ride out from the capital.
func _spawn_lords() -> void:
	lords = []
	for realm in realms:
		var cult := Data.culture_of(realm)
		var firsts: Array = Cultures.info(cult)["first"].duplicate()
		var houses: Array = Lords.HOUSES[cult].duplicate()
		var castles := holdings_of(realm, Data.CASTLE)
		var ruler := String(Data.FACTIONS[realm]["ruler"])
		var ruler_house: String = houses[0] if not houses.is_empty() else "Crown"
		_add_lord(realm, cult, ruler, true, 200, capital_of(realm), ruler_house)
		for i in Lords.PER_REALM:
			var first: String = firsts.pop_at(rng.randi_range(0, firsts.size() - 1))
			var house: String = houses.pop_at(rng.randi_range(0, houses.size() - 1))
			var fief: String = castles[i] if i < castles.size() else ""
			_add_lord(realm, cult, "%s %s %s" % [Lords.title(cult), first, house], false,
				int(Lords.START_RENOWN[i % Lords.START_RENOWN.size()]), fief, house)


func _add_lord(realm: String, cult: String, name: String, ruler: bool, renown: int, fief: String, house: String = "") -> void:
	if house == "":
		var parts := name.split(" ")
		house = parts[-1] if not parts.is_empty() else "Noble"
	var l := {"id": lords.size(), "name": name, "realm": realm, "culture": cult, "house": house,
		"bearing": Lords.BEARINGS[rng.randi_range(0, Lords.BEARINGS.size() - 1)], "ruler": ruler,
		"renown": renown, "silver": Lords.START_SILVER, "fief": fief, "party": -1, "state": "field",
		"back_at": 0.0, "job": "", "target": "", "think_at": hour + rng.randf_range(0.0, Lords.THINK_HOURS),
		"raiding": "", "broke_days": 0, "full": 0, "army": [],
		"grudge": false, "grudge_captain_name": "", "grudge_company_name": "",
		"captive_of": "", "ransom_at": 0.0, "ransom_amount": 0, "ransom_offered": false}
	lords.append(l)
	l["army"] = _lord_army(l)
	for sq in l["army"]:
		l["full"] = int(l["full"]) + int(sq["men"])
	_lord_takes_field(l, seat_of(l))


## Where a lord rests and refills: his fief while his realm holds it, else its capital.
func seat_of(l: Dictionary) -> String:
	var fief := String(l["fief"])
	if fief != "" and owner_of(fief) == l["realm"]:
		return fief
	return capital_of(String(l["realm"]))


## A lord's warband at full strength: squads by his renown, more of them trained as his
## renown grows, under captains of his people.
func _lord_army(l: Dictionary) -> Array:
	var out := []
	var cult := String(l["culture"])
	var taken := []
	var trained := Lords.trained_share(int(l["renown"]))
	for i in Lords.squads_for(int(l["renown"])):
		var roll := rng.randf()
		var type := Troops.INFANTRY
		if roll > 0.8:
			type = Troops.CAVALRY
		elif roll > 0.55:
			type = Troops.ARCHERS
		elif roll > 0.3:
			type = Troops.SPEARMEN
		var unit := Units.recruit(cult, type)
		var level := 1
		if rng.randf() < trained:
			var options := Units.branches(unit)
			if not options.is_empty():
				unit = options[rng.randi_range(0, options.size() - 1)]
				level = 2
		var id := 7000000 + int(l["id"]) * 100 + i
		var captain := Captains.make(rng, id, type, taken, cult)
		taken.append(captain["first"])
		out.append({"id": id, "type": type, "unit": unit, "level": level,
			"xp": Troops.XP_PER_LEVEL if level > 1 else 0, "men": Units.full_size(unit), "culture": cult,
			"name": ("%s's Guard" % l["name"]) if i == 0 else Captains.company_name(captain, type),
			"captain": captain,
			"is_lord": i == 0,
			"lord_id": int(l["id"]),
			"lord_name": String(l["name"])})
	return out


## The lord rides out from `at` with his warband.
func _lord_takes_field(l: Dictionary, at: String) -> void:
	if at == "":
		return
	var p := Party.new()
	p.id = _take_id()
	p.kind = LORD
	p.name = String(l["name"])
	p.faction = String(l["realm"])
	p.node = at
	p.lord = int(l["id"])
	p.army = l["army"]
	parties.append(p)
	l["party"] = p.id
	l["state"] = "field"
	l["job"] = ""
	l["raiding"] = ""
	l["think_at"] = hour


func men_of(army: Array) -> int:
	var men := 0
	for sq in army:
		men += int(sq["men"])
	return men


func is_burned(id: String) -> bool:
	return hour < float(burned.get(id, -1.0))


func _step_lords(dt: float) -> void:
	var day := int(hour / 24.0)
	while _lord_day < day:
		_lord_day += 1
		_lords_day()
	MarshalArmies.tick(self, dt)
	var has_armies := not campaign_armies.is_empty()
	for l in lords:
		if has_armies and not MarshalArmies.for_party(self, int(l["party"])).is_empty():
			continue
		if l["state"] == "prisoner":
			if String(l.get("captive_of", "")) == "player":
				if hour >= float(l.get("ransom_at", 0.0)) and not bool(l.get("ransom_offered", false)):
					l["ransom_offered"] = true
					emit_event({"type": "ransom_offer", "lord_id": l["id"], "amount": int(l.get("ransom_amount", 200)), "realm": l["realm"]})
			elif hour >= float(l.get("ransom_at", 0.0)):
				_resolve_ai_ransom(l)
			continue
		if l["state"] == "regroup":
			if hour >= float(l["back_at"]):
				_lord_takes_field(l, seat_of(l))
			continue
		var p := party(int(l["party"]))
		if p == null:
			continue
		if p.moving():
			if _move(p, dt):
				_lord_arrives(l, p)
		elif p.wait > 0.0:
			p.wait = maxf(0.0, p.wait - dt)
			if p.wait <= 0.0 and String(l["raiding"]) != "":
				_burn(l, String(l["raiding"]))
		if hour >= float(l["think_at"]) or (not p.moving() and p.wait <= 0.0 and l["job"] != "home"):
			l["think_at"] = hour + Lords.THINK_HOURS
			_think_lord(l, p)
	_lord_fights()


## What a lord does next. He goes home when his warband is spent or his purse is empty;
## otherwise he weighs defending his realm's villages, hunting bandits, raiding the enemy
## and patrolling, by his bearing.
func _think_lord(l: Dictionary, p: Party) -> void:
	var bearing := String(l["bearing"])
	var men := men_of(p.army)
	var full := maxi(1, int(l["full"]))
	var seat := seat_of(l)
	if l["job"] == "home" and p.node == seat and not p.moving():
		if men >= full * Lords.REFILLED:
			l["job"] = ""
		else:
			p.wait = Lords.THINK_HOURS
			return
	var low := Lords.REFILL_BELOW + (0.1 if bearing == Lords.CAUTIOUS else 0.0)
	if men < full * low and seat != "":
		_set_job(l, p, "home", seat)
		return
	if String(l["raiding"]) != "":
		return
	var from: String = p.next if p.moving() else p.node
	var best := ["patrol", "", 1.0]
	# Defend: a village of his realm that raiders are burning.
	for other in lords:
		var v := String(other["raiding"])
		if v != "" and owner_of(v) == l["realm"] and at_war(String(other["realm"]), String(l["realm"])):
			var h := _hours(p, from, v)
			if h <= Lords.DEFEND_HOURS:
				var score := 5.0 + (1.0 if bearing in [Lords.CAUTIOUS, Lords.HONORABLE] else 0.0) - h * 0.05
				if score > float(best[2]):
					best = ["defend", v, score]
	# Hunt: bandits raiding a village of his realm, within reach. Bands on the road he
	# leaves to the likes of you.
	for b in bands():
		var at: String = b.next if b.moving() else b.node
		if not b.raiding or owner_of(b.raid_village) != l["realm"]:
			continue
		var h := _hours(p, from, at)
		if h <= Lords.HUNT_HOURS:
			var score := 3.0 + (2.0 if bearing == Lords.HONORABLE else 0.0) - h * 0.05
			if score > float(best[2]):
				best = ["hunt", str(b.id), score]
	# Raid: an enemy village not yet burned, if his warband is strong enough.
	if men >= full * 0.7:
		var reach := Lords.RAID_HOURS_AWAY * (1.5 if bearing == Lords.DARING else (0.4 if bearing == Lords.CAUTIOUS else 1.0))
		for v in Data.SETTLEMENTS:
			if not Data.is_village(v) or is_burned(v) or not at_war(owner_of(v), String(l["realm"])) or owner_of(v) == Data.BANDITS:
				continue
			var h := _hours(p, from, v)
			if h <= reach:
				var score := 2.0 + (2.0 if bearing == Lords.CRUEL else 0.0) + (1.0 if bearing == Lords.DARING else 0.0) \
					- (1.0 if bearing == Lords.HONORABLE else 0.0) - h * 0.03 + rng.randf() * 0.5
				if score > float(best[2]):
					best = ["raid", v, score]
	# Grudge: seek out player when near
	if bool(l.get("grudge", false)):
		var ply = player()
		if ply != null:
			var p_node: String = ply.next if ply.moving() else ply.node
			var h := _hours(p, from, p_node)
			if h <= Lords.DEFEND_HOURS:
				var score := 6.5 - h * 0.05
				if score > float(best[2]):
					best = ["grudge_hunt", p_node, score]
	if best[0] == "patrol":
		if l["job"] == "patrol" and (p.moving() or p.wait > 0.0):
			return
		var own := holdings_of(String(l["realm"])).filter(func(id): return id != p.node)
		if own.is_empty():
			return
		_set_job(l, p, "patrol", own[rng.randi_range(0, own.size() - 1)])
	elif best[0] == "hunt":
		var b := party(int(best[1]))
		_set_job(l, p, "hunt", b.next if b.moving() else b.node)
	elif best[0] == "grudge_hunt":
		_set_job(l, p, "grudge_hunt", best[1])
	else:
		_set_job(l, p, best[0], best[1])


## Hours for lord's party `p` to ride from `from` to `to`. The roads never change, so
## every pair is worked out once.
func _hours(p: Party, from: String, to: String) -> float:
	if from == to:
		return 0.0
	if _lord_hours.is_empty():
		for a in Data.SETTLEMENTS:
			for b in Data.SETTLEMENTS:
				var route := path(a, b) if a != b else []
				var h := 0.0 if a == b else INF
				if not route.is_empty():
					h = 0.0
					var at: String = a
					for nxt in route:
						h += road_length(at, nxt) / _speed(p, at, nxt)
						at = nxt
				_lord_hours["%s>%s" % [a, b]] = h
	return float(_lord_hours.get("%s>%s" % [from, to], INF))


func _set_job(l: Dictionary, p: Party, job: String, target: String) -> void:
	l["job"] = job
	l["target"] = target
	p.wait = 0.0
	var from: String = p.node
	if p.moving():
		# Finish the road he's on first.
		from = p.next
	var route := path(from, target) if from != target else []
	if p.moving():
		p.path = route
	elif route.is_empty():
		_lord_arrives(l, p)
	else:
		p.next = route.pop_front()
		p.along = 0.0
		p.path = route


func _lord_arrives(l: Dictionary, p: Party) -> void:
	if l["job"] == "army": return
	if p.moving() or p.node != String(l["target"]):
		return
	match String(l["job"]):
		"raid":
			if Data.is_village(p.node) and not is_burned(p.node) and at_war(owner_of(p.node), String(l["realm"])):
				l["raiding"] = p.node
				p.wait = Lords.RAID_HOURS
				emit_event({"type": "raid_started", "party": p.id, "village": p.node, "hours": Lords.RAID_HOURS})
			else:
				l["job"] = ""
		"home":
			p.wait = Lords.THINK_HOURS
		_:
			p.wait = rng.randf_range(Lords.LINGER_MIN, Lords.LINGER_MAX)
			l["job"] = "patrol"


## Villages have a small defensive militia (peasants, militia spears, bows)
## that defends locally against raids. They have no standing garrison in peace.
func village_militia(village_id: String) -> Array:
	var s := Data.settlement(village_id)
	var cult := Data.culture_of(s["faction"])
	var spear_unit := Units.recruit(cult, Troops.SPEARMEN)
	var archer_unit := Units.recruit(cult, Troops.ARCHERS)
	return [
		{"id": 9000000 + Data.SETTLEMENTS.keys().find(village_id) * 10 + 1,
		 "type": Troops.SPEARMEN, "unit": spear_unit, "culture": cult, "level": 1,
		 "xp": 0, "men": 8, "name": "%s militia spears" % s["name"], "captain": null},
		{"id": 9000000 + Data.SETTLEMENTS.keys().find(village_id) * 10 + 2,
		 "type": Troops.ARCHERS, "unit": archer_unit, "culture": cult, "level": 1,
		 "xp": 0, "men": 7, "name": "%s militia bows" % s["name"], "captain": null},
	]


func _burn(l: Dictionary, village: String) -> void:
	l["raiding"] = ""
	l["job"] = ""
	if is_burned(village):
		return
	var lp := party(int(l.get("party", -1)))
	var is_pf: bool = game_state != null and game_state.is_player_fief(village)
	if lp != null and not lp.army.is_empty():
		var militia := village_militia(village)
		var lord_men := men_of(lp.army)
		var militia_men := men_of(militia)
		var garrison_squads: Array = garrisons.get(village, [])
		var has_forts: bool = is_pf and bool(game_state.player_fief.get("improvements", {}).get(Fiefs.IMPROVEMENT_FORTIFICATIONS, false))
		var bonus_militia := 15 if has_forts else 0
		var def_men := militia_men + men_of(garrison_squads) + bonus_militia
		if has_forts:
			def_men = int(def_men * 1.35)
		if def_men > lord_men and rng.randf() < 0.75:
			emit_event({"type": "fief_defended", "settlement": village, "enemy": String(l["name"])})
			if is_pf:
				game_state._note("Your garrison and militia at %s repulsed the raiding party of %s!" % [Data.settlement(village)["name"], l["name"]])
			return
		elif lord_men < militia_men and rng.randf() < 0.6:
			emit_event({"type": "raid_repulsed", "village": village, "by_militia": true, "lord": l["name"]})
			return
		# Resisting militia inflicts light skirmish attrition (0-2 casualties)
		var skirmish_loss := mini(lord_men - 1, rng.randi_range(0, 2))
		for sq in lp.army:
			if skirmish_loss <= 0:
				break
			var take := mini(skirmish_loss, mini(1, int(sq["men"])))
			sq["men"] = int(sq["men"]) - take
			skirmish_loss -= take
		lp.army = lp.army.filter(func(sq): return int(sq["men"]) > 0)
	burned[village] = hour + Lords.BURNED_DAYS * 24.0
	l["silver"] = int(l["silver"]) + Lords.RAID_LOOT
	var v_owner := owner_of(village)
	if realms.has(v_owner):
		add_weariness(v_owner, Politics.WEARINESS_LOST_VILLAGE)
	emit_event({"type": "burned", "village": village, "by": String(l["name"])})
	if is_pf:
		game_state._on_fief_burned(String(l["name"]))


## A day's money. Each realm takes in its places' dues and pays its lords' wages; a lord
## whose realm can't pay him pays from his own purse, and one who can't pay at all loses
## men, as your warband does. A lord resting at his seat refills his squads.
func _lords_day() -> void:
	for realm in realms:
		var income := 0
		for id in holdings_of(realm):
			if not is_burned(id):
				income += int(Lords.INCOME[Data.settlement(id)["type"]])
		realms[realm]["treasury"] = int(realms[realm]["treasury"]) + income
	for l in lords:
		var p := party(int(l["party"]))
		var army: Array = p.army if p != null else l["army"]
		var wages := 0.0
		for sq in army:
			wages += Economy.daily_wage(sq)
		var owed := int(ceil(wages * Lords.WAGE_SHARE))
		var realm: Dictionary = realms[l["realm"]]
		var from_realm := mini(owed, maxi(0, int(realm["treasury"])))
		realm["treasury"] = int(realm["treasury"]) - from_realm
		owed -= from_realm
		var from_lord := mini(owed, maxi(0, int(l["silver"])))
		l["silver"] = int(l["silver"]) - from_lord
		owed -= from_lord
		if owed > 0:
			l["broke_days"] = int(l["broke_days"]) + 1
			for sq in army:
				sq["men"] = int(sq["men"]) - int(ceil(int(sq["men"]) * Economy.DESERTION))
		else:
			l["broke_days"] = 0
		if p != null and not p.moving() and p.node == seat_of(l):
			_refill(l, army)
		army = army.filter(func(sq): return int(sq["men"]) > 0)
		if p != null:
			p.army = army
		l["army"] = army
	_garrisons_day()
	_politics_day()


func _politics_day() -> void:
	# 1. Weariness tick for at-war and peace
	for f in realms:
		if is_at_war(f):
			add_weariness(f, Politics.WEARINESS_DAY_AT_WAR)
		else:
			add_weariness(f, -Politics.WEARINESS_PEACE_DECAY)

	# 2. Tribute transfers
	var rem_tribs: Array = []
	for t in tributes:
		if int(t.get("days_left", 0)) > 0:
			var debtor: String = String(t.get("from", ""))
			var creditor: String = String(t.get("to", ""))
			var daily: int = int(t.get("daily", 0))
			if realms.has(debtor) and realms.has(creditor):
				var paid: int = mini(daily, maxi(0, int(realms[debtor].get("treasury", 0))))
				realms[debtor]["treasury"] = int(realms[debtor]["treasury"]) - paid
				realms[creditor]["treasury"] = int(realms[creditor]["treasury"]) + paid
			t["days_left"] = int(t.get("days_left", 0)) - 1
			if int(t["days_left"]) > 0:
				rem_tribs.append(t)
	tributes = rem_tribs

	# 3. Clean up expired truces
	var expired_truces: Array = []
	for key in truces:
		if hour >= float(truces[key].get("until", 0.0)):
			expired_truces.append(key)
	for key in expired_truces:
		truces.erase(key)

	# 4. Peace evaluation
	_evaluate_peace()

	# 5. Balance of power (Ryumon intervention)
	_evaluate_balance_of_power()

	# 6. Autonomous war declarations
	_evaluate_war_declarations()


func _evaluate_peace() -> void:
	var war_keys := wars.keys()
	for key in war_keys:
		if not wars.has(key):
			continue
		var parts: PackedStringArray = key.split("|")
		if parts.size() < 2:
			continue
		var a: String = parts[0]
		var b: String = parts[1]
		var w_a := weariness_of(a)
		var w_b := weariness_of(b)

		var a_wants := w_a >= Politics.PEACE_THRESHOLD
		var b_wants := w_b >= Politics.PEACE_THRESHOLD

		if not a_wants and not b_wants:
			continue

		if a_wants and b_wants:
			_sign_peace_treaty(a, b)
			continue

		var suitor := a if a_wants else b
		var respondent := b if suitor == a else a

		var w_resp := weariness_of(respondent)
		var is_fresh := w_resp < Politics.PEACE_ACCEPT_THRESHOLD
		var diff := weariness_of(suitor) - w_resp

		var seats_resp := mainland_seats_of(respondent) if respondent in ["vardmark", "kharzan"] else holdings_of(respondent).size()
		var seats_suitor := mainland_seats_of(suitor) if suitor in ["vardmark", "kharzan"] else holdings_of(suitor).size()
		var winning_clearly := (seats_resp > seats_suitor) or (diff >= 30.0)

		if is_fresh and winning_clearly:
			# Respondent refuses peace; war continues
			continue
		else:
			_sign_peace_treaty(a, b)


func _sign_peace_treaty(a: String, b: String) -> void:
	var w_a := weariness_of(a)
	var w_b := weariness_of(b)
	var diff := absf(w_a - w_b)
	var loser := a if w_a > w_b else b
	var daily_tribute: int = 0
	if diff >= 5.0:
		daily_tribute = int(clampf(
			Politics.TRIBUTE_BASE + diff * Politics.TRIBUTE_PER_WEARINESS_DIFF,
			float(Politics.TRIBUTE_BASE),
			float(Politics.TRIBUTE_MAX)
		))
	make_peace(a, b, Politics.TRUCE_DAYS, daily_tribute, loser, Politics.TRIBUTE_DAYS)


func _evaluate_balance_of_power() -> void:
	for realm in ["vardmark", "kharzan"]:
		var seats := mainland_seats_of(realm)
		if seats >= Politics.HEGEMONY_SEATS_THRESHOLD:
			if not at_war("ryumon", realm):
				declare_war("ryumon", realm, true, "balance of power")


func _evaluate_war_declarations() -> void:
	var pairs := [["vardmark", "kharzan"]]
	for pair in pairs:
		var a: String = pair[0]
		var b: String = pair[1]
		if at_war(a, b) or has_truce(a, b):
			continue
		var w_a := weariness_of(a)
		var w_b := weariness_of(b)
		if w_a <= Politics.WAR_READY_WEARINESS and w_b <= Politics.WAR_READY_WEARINESS:
			var str_a := realm_strength(a)
			var str_b := realm_strength(b)
			var has_edge := absf(float(str_a - str_b)) >= 20.0
			if has_edge or rng.randf() < 0.2:
				var aggressor := a if str_a >= str_b else b
				var defender := b if aggressor == a else a
				declare_war(aggressor, defender)


## A day's recruits for a lord at his seat, as many as his purse allows, up to his
## warband's full strength. Squads cut down to nothing are raised again.
func _refill(l: Dictionary, army: Array) -> void:
	var budget := int(ceil(int(l["full"]) * Lords.REFILL_PER_DAY))
	if men_of(army) < int(l["full"]) * 0.5 and army.size() < Lords.squads_for(int(l["renown"])):
		for sq in _lord_army(l):
			if army.size() >= Lords.squads_for(int(l["renown"])):
				break
			var used := false
			for have in army:
				if int(have["id"]) == int(sq["id"]):
					used = true
			if not used:
				sq["men"] = 0
				army.append(sq)
	for sq in army:
		if budget <= 0:
			break
		var unit := String(sq.get("unit", ""))
		var full := Units.full_size(unit) if Units.has(unit) else Troops.full_size(String(sq["type"]))
		var add := mini(full - int(sq["men"]), budget)
		if add <= 0:
			continue
		var cost := Economy.recruit_cost(unit if unit != "" else String(sq["type"]), add)
		var unit_cost := int(Economy.recruit_cost(unit if unit != "" else String(sq["type"]), 1))
		var escrow_paid := 0
		if social != null:
			escrow_paid = social.consume_escrow_for_recruitment(str(l["id"]), "lord", add, unit_cost)
		var rem_cost := maxi(0, cost - escrow_paid)
		var realm: Dictionary = realms[l["realm"]]
		if rem_cost > int(l["silver"]) + maxi(0, int(realm["treasury"]) - Lords.TREASURY_RESERVE):
			break
		var own := mini(rem_cost, int(l["silver"]))
		l["silver"] = int(l["silver"]) - own
		realm["treasury"] = int(realm["treasury"]) - (rem_cost - own)
		sq["men"] = int(sq["men"]) + add
		budget -= add


## Lords who meet their enemies on the road fight it out, settled as a fight you send
## your men into would be: lords of realms at war. The loser's party is gone, to regroup
## at his seat with whoever got away. Bandits a hunting lord catches are driven off.
func _lord_fights() -> void:
	var l_parties := visible_lord_parties()
	var l_count := l_parties.size()
	var l_pos := []
	for p in l_parties:
		l_pos.append(party_pos(p))
	var gone := {}
	var reach := ENCOUNTER_RADIUS * ENCOUNTER_RADIUS

	# Lord vs Lord fights
	for i in l_parties.size():
		var a: Party = l_parties[i]
		if gone.has(a.id):
			continue
		var a_pos: Vector2 = l_pos[i]
		for j in range(i + 1, l_count):
			var b: Party = l_parties[j]
			if gone.has(b.id) or not at_war(a.faction, b.faction):
				continue
			var b_pos: Vector2 = l_pos[j]
			if a_pos.distance_squared_to(b_pos) > reach:
				continue
			var loser := _ai_fight(a, b)
			gone[loser.id] = true
			if loser == a:
				break

	# Hunting lords vs Bands
	var b_parties: Array = []
	var b_pos := []
	var bands_computed := false
	for i in l_parties.size():
		var a: Party = l_parties[i]
		if gone.has(a.id) or lord_of(a).get("job", "") != "hunt":
			continue
		if not bands_computed:
			b_parties = bands()
			for b in b_parties:
				b_pos.append(party_pos(b))
			bands_computed = true
		var a_pos: Vector2 = l_pos[i]
		for j in b_parties.size():
			var b: Party = b_parties[j]
			if a_pos.distance_squared_to(b_pos[j]) <= reach:
				_drive_off(a, b)


## Bandits caught raiding by a lord don't stand and fight: they break off and run for
## another village, and the lord turns back to his own business.
func _drive_off(l_party: Party, band: Party) -> void:
	if band.raiding:
		emit_event({"type": "driven_off", "party": band.id, "village": band.raid_village, "by": l_party.name})
	band.raiding = false
	band.raid_village = ""
	band.wait = 0.0
	var l := lord_of(l_party)
	l["job"] = ""
	l["think_at"] = hour


## Two parties fight it out; returns the loser.
func _ai_fight(a: Party, b: Party) -> Party:
	var left := army_parties(a)
	var right := army_parties(b)
	var left_troops: Array = []
	var right_troops: Array = []
	for member in left: left_troops.append_array(member.army)
	for member in right: right_troops.append_array(member.army)
	var r := AutoResolve.resolve(left_troops, right_troops, rng, true, null, "rout")
	for member in left:
		var pre := men_of(member.army)
		_take_losses(member, r["squads"])
		var lost := pre - men_of(member.army)
		if lost > 0 and realms.has(member.faction):
			add_weariness(member.faction, float(lost) * Politics.WEARINESS_CASUALTY)
	for member in right:
		var pre := men_of(member.army)
		_take_losses(member, r["enemy_squads"])
		var lost := pre - men_of(member.army)
		if lost > 0 and realms.has(member.faction):
			add_weariness(member.faction, float(lost) * Politics.WEARINESS_CASUALTY)
	var winner := a if r["won"] else b
	var loser := b if r["won"] else a
	var killed := int(r["killed"]) if r["won"] else int(r["lost"])
	var wl := lord_of(winner)
	if not wl.is_empty():
		wl["silver"] = int(wl["silver"]) + Economy.SILVER_PER_KILL * killed
		wl["renown"] = mini(Lords.RENOWN_MAX, int(wl["renown"]) + 1 + killed / 10)
	emit_event({"type": "fight", "winner": winner.name, "loser": loser.name, "at": loser.node})
	var ll := lord_of(loser)
	if not ll.is_empty() and not wl.is_empty():
		var roll := rng.randf()
		if roll < 0.05:
			kill_lord(int(ll["id"]), String(wl["name"]))
		elif roll < 0.55:
			capture_lord(int(ll["id"]), String(wl["realm"]))
			emit_event({"type": "lord_captured_ai", "lord": ll["name"], "by": wl["name"], "realm": wl["realm"]})
	for member in (right if r["won"] else left): _routed(member)
	var defeated := MarshalArmies.for_party(self, loser.id)
	if not defeated.is_empty(): MarshalArmies.disband(self, defeated, "Army defeated")
	return loser


func _take_losses(p: Party, survivors: Dictionary) -> void:
	for sq in p.army:
		var left = survivors.get(int(sq["id"]))
		if left != null:
			sq["men"] = int(left["men"])
	p.army = p.army.filter(func(sq): return int(sq["men"]) > 0)


## A beaten party leaves the map: a band for good (another rises later), a lord to his
## seat to regroup.
func _routed(p: Party) -> void:
	parties.erase(p)
	if p.kind == BAND:
		respawns.append({"faction": p.faction, "at": hour + RESPAWN_HOURS})
		return
	var l := lord_of(p)
	if not l.is_empty():
		l["army"] = p.army
		l["party"] = -1
		if l.get("state") != "prisoner":
			l["state"] = "regroup"
			l["back_at"] = hour + Lords.REGROUP_HOURS
		l["raiding"] = ""
		l["job"] = ""
		if realms.has(String(l.get("realm", ""))):
			add_weariness(String(l["realm"]), Politics.WEARINESS_LORD_ROUTED)


# ---------------------------------------------------------------- settlement jobs

func jobs_at(id: String) -> Array:
	if not settlement_jobs.has(id) or hour >= float(settlement_jobs_back.get(id, INF)):
		settlement_jobs[id] = _new_jobs(id)
		settlement_jobs_back.erase(id)
	return settlement_jobs[id]


func take_job(id: String, index: int) -> Dictionary:
	var list := jobs_at(id)
	if index < 0 or index >= list.size():
		return {}
	var job: Dictionary = list[index]
	list.remove_at(index)
	if not settlement_jobs_back.has(id):
		settlement_jobs_back[id] = hour + Jobs.REFRESH_HOURS
	return job


func _new_jobs(id: String) -> Array:
	return Jobs.generate_jobs_for(id, self, rng)


# ---------------------------------------------------------------- recruits

## Who will join you at `id`: squads of fresh recruits of the settlement's own culture.
## Villages raise foot and bows, castles spears and horse, towns any of them. Offers that
## were taken come back OFFER_REFRESH_HOURS later.
func offers_at(id: String) -> Array:
	if is_burned(id):
		return []
	if not offers.has(id) or hour >= float(offers_back.get(id, INF)):
		offers[id] = _new_offers(id)
		offers_back.erase(id)
	return offers[id]


func take_offer(id: String, index: int) -> Dictionary:
	var list := offers_at(id)
	if index < 0 or index >= list.size():
		return {}
	var offer: Dictionary = list[index]
	list.remove_at(index)
	if not offers_back.has(id):
		offers_back[id] = hour + Economy.OFFER_REFRESH_HOURS
	return offer


func _new_offers(id: String) -> Array:
	var s := Data.settlement(id)
	# Recruits are of the place's own people, whoever holds it now.
	var place_culture := Data.culture_of(s["faction"])
	var kinds: Array
	var count: int
	match String(s["type"]):
		Data.VILLAGE:
			kinds = [Troops.INFANTRY, Troops.SPEARMEN, Troops.ARCHERS]
			count = rng.randi_range(1, 2)
		Data.CASTLE:
			kinds = [Troops.SPEARMEN, Troops.CAVALRY]
			count = 1
		_:
			kinds = Troops.ORDER
			count = rng.randi_range(2, 3)
	var out := []
	for i in count:
		out.append({"type": kinds[rng.randi_range(0, kinds.size() - 1)], "culture": place_culture})
	return out


# ---------------------------------------------------------------- encounters

## Whether the player can withdraw from the current encounter. Hostile lords who are
## faster and significantly stronger can overrun/ride down the player.
func can_withdraw() -> bool:
	if encounter == -1:
		return true
	var b := party(encounter)
	if b == null or b.kind != LORD:
		return true
	var p := player()
	var p_speed: float = _speed(p, p.node, p.next if p.next != "" else p.node)
	var e_speed: float = _speed(b, b.node, b.next if b.next != "" else b.node)
	var p_men: int = men_of(p.army)
	var e_men: int = men_of(b.army)
	if e_speed > p_speed and float(e_men) > float(p_men) * 1.3:
		var prng := RandomNumberGenerator.new()
		prng.seed = hash([b.id, int(hour * 10.0)])
		if prng.randf() < 0.4:
			return false
	return true


## Returns losses to allied lords who fought alongside the player.
func return_allied_losses(squads: Dictionary) -> void:
	if squads.is_empty():
		return
	var touched_parties := {}
	for sq_id in squads:
		var s: Dictionary = squads[sq_id]
		if not bool(s.get("is_ally", false)):
			continue
		var lid: int = int(s.get("lord_id", -1))
		if lid < 0 or lid >= lords.size():
			continue
		var lord: Dictionary = lords[lid]
		var lp := party(int(lord.get("party", -1)))
		var army_list: Array = lp.army if lp != null else lord.get("army", [])
		for lsq in army_list:
			if int(lsq["id"]) == int(sq_id):
				lsq["men"] = int(s["men"])
		if lp != null:
			touched_parties[lp] = true
	for lp in touched_parties:
		lp.army = lp.army.filter(func(sq): return int(sq["men"]) > 0)
		var l: Dictionary = lord_of(lp)
		if not l.is_empty():
			l["army"] = lp.army
		if lp.army.is_empty():
			_routed(lp)


## You beat the band: it's gone, and another rises in its realm a day later. If it was a lord,
## he is routed back to his seat to regroup.
func win_encounter() -> void:
	var b := party(encounter)
	encounter = -1
	if b == null:
		return
	if b.kind == LORD:
		_routed(b)
	else:
		parties.erase(b)
		respawns.append({"faction": b.faction, "at": hour + RESPAWN_HOURS})


## Find lord by ID
func lord_by_id(id: int) -> Dictionary:
	return lords[id] if id >= 0 and id < lords.size() else {}


## Captive lords held by a specific captor (e.g. "player" or realm name)
func captive_lords_of(captor: String) -> Array:
	return lords.filter(func(l): return l.get("state") == "prisoner" and l.get("captive_of") == captor)


## Capture a lord
func capture_lord(id: int, captor: String) -> void:
	var l: Dictionary = lord_by_id(id)
	if l.is_empty():
		return
	l["state"] = "prisoner"
	l["captive_of"] = captor
	l["ransom_at"] = hour + (Lords.RANSOM_HOURS if captor == "player" else Lords.AI_RANSOM_HOURS)
	l["ransom_amount"] = Lords.ransom_for(int(l.get("renown", 40)))
	l["ransom_offered"] = false
	if int(l.get("party", -1)) >= 0:
		var p := party(int(l["party"]))
		if p != null:
			parties.erase(p)
		l["party"] = -1
	if realms.has(String(l.get("realm", ""))):
		add_weariness(String(l["realm"]), Politics.WEARINESS_LORD_ROUTED)


## Release a captive lord back to his realm to regroup
func release_lord(id: int) -> void:
	var l: Dictionary = lord_by_id(id)
	if l.is_empty():
		return
	l["state"] = "regroup"
	l["back_at"] = hour + Lords.REGROUP_HOURS
	l["captive_of"] = ""
	l["ransom_offered"] = false
	l["party"] = -1


## Slay a lord and crown/raise an heir of his house so the world keeps its lords.
func kill_lord(id: int, killer: String = "") -> Dictionary:
	var l: Dictionary = lord_by_id(id)
	if l.is_empty():
		return {}
	var cult: String = String(l["culture"])
	var house: String = String(l.get("house", ""))
	if house == "":
		var parts := String(l["name"]).split(" ")
		house = parts[-1] if not parts.is_empty() else "Noble"
	var firsts: Array = Cultures.info(cult)["first"].duplicate()
	var new_first: String = firsts[rng.randi_range(0, firsts.size() - 1)]
	var prev_name: String = String(l["name"])
	var heir_name := "%s %s %s" % [Lords.title(cult), new_first, house]

	l["name"] = heir_name
	l["house"] = house
	l["renown"] = Lords.START_RENOWN[0]
	l["silver"] = Lords.START_SILVER
	l["bearing"] = Lords.BEARINGS[rng.randi_range(0, Lords.BEARINGS.size() - 1)]
	l["state"] = "regroup"
	l["back_at"] = hour + Lords.REGROUP_HOURS * 1.5
	l["job"] = ""
	l["target"] = ""
	l["raiding"] = ""
	l["grudge"] = false
	l["grudge_captain_name"] = ""
	l["grudge_company_name"] = ""
	l["captive_of"] = ""
	l["ransom_offered"] = false
	if int(l.get("party", -1)) >= 0:
		var p := party(int(l["party"]))
		if p != null:
			parties.erase(p)
		l["party"] = -1
	l["army"] = _lord_army(l)
	l["full"] = men_of(l["army"])
	emit_event({"type": "lord_slain", "lord": prev_name, "heir": heir_name, "realm": l["realm"], "by": killer})
	if realms.has(String(l.get("realm", ""))):
		add_weariness(String(l["realm"]), Politics.WEARINESS_LORD_ROUTED * 1.5)
	return l


func _resolve_ai_ransom(l: Dictionary) -> void:
	var captor_realm: String = String(l.get("captive_of", ""))
	var lord_realm: String = String(l.get("realm", ""))
	var amount: int = int(l.get("ransom_amount", 200))
	if realms.has(captor_realm) and realms.has(lord_realm):
		realms[captor_realm]["treasury"] = int(realms[captor_realm].get("treasury", 0)) + amount
		realms[lord_realm]["treasury"] = maxi(0, int(realms[lord_realm].get("treasury", 0)) - amount)
	l["state"] = "regroup"
	l["back_at"] = hour + Lords.REGROUP_HOURS
	l["captive_of"] = ""
	l["ransom_offered"] = false
	emit_event({"type": "lord_ransomed_ai", "lord": l["name"], "realm": lord_realm, "by_realm": captor_realm, "amount": amount})



## You pull back to the last settlement you passed. The time it takes passes, and the
## band leaves you be for a while.
func withdraw() -> void:
	var b := party(encounter)
	encounter = -1
	var p := player()
	if p.moving():
		hour += p.along / _speed(p, p.node, p.next)
	p.next = ""
	p.along = 0.0
	p.path = []
	p.wait = 0.0
	if b != null:
		b.grace_until = hour + GRACE_HOURS


## The band blocking the road takes its losses: `survivors` maps squad ids to the men
## left ({id: {men}}). A band with nobody left is gone; a lord regroups.
func hurt_band(survivors: Dictionary) -> void:
	var b := party(encounter)
	if b == null or survivors.is_empty():
		return
	for sq in b.army:
		var left = survivors.get(int(sq["id"]))
		if left != null:
			sq["men"] = int(left["men"])
	b.army = b.army.filter(func(sq): return int(sq["men"]) > 0)
	if b.army.is_empty():
		if b.kind == LORD:
			_routed(b)
		else:
			parties.erase(b)
			respawns.append({"faction": b.faction, "at": hour + RESPAWN_HOURS})


## The band beat you: the survivors regroup at your people's capital, half a day later.
func lose_encounter() -> void:
	following_party = -1
	var b := party(encounter)
	encounter = -1
	var p := player()
	p.node = home()
	p.next = ""
	p.along = 0.0
	p.path = []
	p.wait = 0.0
	hour += REGROUP_HOURS
	if b != null:
		b.grace_until = hour + GRACE_HOURS


## Where your warband regroups: your people's capital, wherever their realm now rules from
## (or where it first did, if it holds nothing).
func home() -> String:
	var realm := ""
	for f in Data.FACTIONS:
		if Data.FACTIONS[f]["culture"] == culture:
			realm = f
	var seat := capital_of(realm)
	return seat if seat != "" else Data.capital_of_culture(culture)


# ---------------------------------------------------------------- saving

func to_dict() -> Dictionary:
	var ps := []
	for p in parties:
		ps.append({"id": p.id, "kind": p.kind, "name": p.name, "faction": p.faction, "node": p.node,
			"next": p.next, "along": p.along, "path": p.path.duplicate(), "wait": p.wait,
			"army": p.army.duplicate(true), "grace_until": p.grace_until,
			"raiding": p.raiding, "raid_village": p.raid_village,
			"is_chief_band": p.is_chief_band, "chief_name": p.chief_name, "lord": p.lord})
	return {
		"hour": hour, "culture": culture, "encounter": encounter, "following_party": following_party, "next_id": _next_id,
		"seed": str(rng.seed), "state": str(rng.state),
		"respawns": respawns.duplicate(true), "parties": ps,
		"offers": offers.duplicate(true), "offers_back": offers_back.duplicate(),
		"settlement_jobs": settlement_jobs.duplicate(true), "settlement_jobs_back": settlement_jobs_back.duplicate(),
		"escaped_chiefs": escaped_chiefs.duplicate(true),
		"saved_villages": saved_villages.duplicate(),
		"activity_log": activity_log.duplicate(true),
		"owners": owners.duplicate(), "wars": wars.duplicate(true), "realms": realms.duplicate(true),
		"truces": truces.duplicate(true), "tributes": tributes.duplicate(true),
		"garrisons": garrisons.duplicate(true),
		"campaign_armies": campaign_armies.duplicate(true), "army_ready_at": army_ready_at.duplicate(), "next_army_id": next_army_id,
		"social": social.to_dict() if social != null else null,
		"lords": lords.map(func(l): return _lord_for_save(l)), "burned": burned.duplicate(), "lord_day": _lord_day,
	}


## A lord as saved: his squads only while he regroups (on the map they ride with his party).
func _lord_for_save(l: Dictionary) -> Dictionary:
	var out := l.duplicate(true)
	if int(l["party"]) >= 0:
		out["army"] = []
	return out


## Restore a world saved with to_dict(). JSON turns every number into a float, so counts
## and ids come back as ints.
func from_dict(d: Dictionary) -> void:
	clear_path_cache()
	_build_roads()
	# A world saved before places could change hands starts from the map as it was.
	_start_realms()
	var raw_owners = d.get("owners", {})
	for id in raw_owners:
		if Data.SETTLEMENTS.has(String(id)):
			owners[String(id)] = String(raw_owners[id])
	if d.has("wars"):
		wars = {}
		var raw_wars = d["wars"]
		for k in raw_wars:
			wars[String(k)] = {"since": float(raw_wars[k].get("since", 0.0))}
	var raw_realms = d.get("realms", {})
	for f in raw_realms:
		if realms.has(String(f)):
			realms[String(f)]["capital"] = String(raw_realms[f].get("capital", ""))
			realms[String(f)]["treasury"] = int(raw_realms[f].get("treasury", Lords.TREASURY_START))
			realms[String(f)]["marshal"] = int(raw_realms[f].get("marshal", -1))
			realms[String(f)]["weariness"] = float(raw_realms[f].get("weariness", 0.0))
	truces = {}
	var raw_truces = d.get("truces", {})
	for k in raw_truces:
		truces[String(k)] = {"until": float(raw_truces[k].get("until", 0.0))}
	tributes = []
	var raw_tribs = d.get("tributes", [])
	for t in raw_tribs:
		tributes.append({
			"from": String(t.get("from", "")),
			"to": String(t.get("to", "")),
			"daily": int(t.get("daily", 0)),
			"days_left": int(t.get("days_left", 0)),
		})
	hour = float(d.get("hour", 0.0))
	culture = String(d.get("culture", Cultures.VARDISH))
	encounter = int(d.get("encounter", -1))
	following_party = int(d.get("following_party", -1))
	_next_id = int(d.get("next_id", 1))
	rng.seed = int(String(d.get("seed", "0")))
	rng.state = int(String(d.get("state", "0")))
	offers = {}
	var raw_offers = d.get("offers", {})
	for id in raw_offers:
		var list := []
		for o in raw_offers[id]:
			list.append({"type": String(o["type"]), "culture": String(o["culture"])})
		offers[String(id)] = list
	offers_back = {}
	var raw_back = d.get("offers_back", {})
	for id in raw_back:
		offers_back[String(id)] = float(raw_back[id])
	settlement_jobs = d.get("settlement_jobs", {}).duplicate(true)
	settlement_jobs_back = d.get("settlement_jobs_back", {}).duplicate()
	respawns = []
	for r in d.get("respawns", []):
		respawns.append({"faction": String(r["faction"]), "at": float(r["at"])})
	escaped_chiefs = []
	for ec in d.get("escaped_chiefs", []):
		escaped_chiefs.append({"name": String(ec.get("name", "")), "culture": String(ec.get("culture", "")),
			"grudge": int(ec.get("grudge", 0)), "escaped_at": float(ec.get("escaped_at", 0.0)),
			"times_beaten": int(ec.get("times_beaten", 0))})
	saved_villages = {}
	var raw_saved = d.get("saved_villages", {})
	for k in raw_saved:
		saved_villages[String(k)] = int(raw_saved[k])
	activity_log = []
	for raw in d.get("activity_log", []):
		if typeof(raw) == TYPE_DICTIONARY and String(raw.get("text", "")) != "":
			var kind := String(raw.get("type", ""))
			var cat := String(raw.get("category", ""))
			if cat == "":
				if kind in ["war", "peace"]:
					cat = "war"
				elif kind in ["siege_started", "siege_assault", "siege_repulsed", "captured", "burned", "raid_started", "driven_off"]:
					cat = "siege"
				elif kind in ["grudge_avenged", "contract_signed", "contract_ended", "player_victory"]:
					cat = "deed"
				else:
					cat = "battle"
			activity_log.append({
				"hour": float(raw.get("hour", hour)),
				"type": kind,
				"category": cat,
				"text": String(raw.get("text", "")),
				"place": String(raw.get("place", "")),
			})
	if activity_log.size() > ACTIVITY_LIMIT:
		activity_log.resize(ACTIVITY_LIMIT)
	parties = []
	for e in d.get("parties", []):
		var p := Party.new()
		p.id = int(e["id"])
		p.kind = String(e["kind"])
		p.name = String(e["name"])
		p.faction = String(e["faction"])
		p.node = String(e["node"])
		p.next = String(e["next"])
		p.along = float(e["along"])
		p.path = []
		for s in e["path"]:
			p.path.append(String(s))
		p.wait = float(e["wait"])
		p.grace_until = float(e["grace_until"])
		p.raiding = bool(e.get("raiding", false))
		p.raid_village = String(e.get("raid_village", ""))
		p.is_chief_band = bool(e.get("is_chief_band", false))
		p.chief_name = String(e.get("chief_name", ""))
		p.lord = int(e.get("lord", -1))
		p.army = clean_army(e["army"])
		parties.append(p)
	burned = {}
	var raw_burned = d.get("burned", {})
	for k in raw_burned:
		burned[String(k)] = float(raw_burned[k])
	lords = []
	if d.has("lords"):
		for e in d["lords"]:
			lords.append(_clean_lord(e))
		for l in lords:
			var lp := party(int(l["party"]))
			if lp != null:
				l["army"] = lp.army
		_lord_day = int(d.get("lord_day", int(hour / 24.0)))
	else:
		# A world saved before there were lords gets its lords now.
		_spawn_lords()
		_lord_day = int(hour / 24.0)

	campaign_armies = d.get("campaign_armies", []).duplicate(true)
	army_ready_at = d.get("army_ready_at", {}).duplicate()
	next_army_id = int(d.get("next_army_id", 1))
	for army in campaign_armies:
		army["id"] = int(army["id"])
		army["leader"] = int(army["leader"])
		army["members"] = army["members"].map(func(id): return int(id))
		next_army_id = maxi(next_army_id, army["id"] + 1)

	if d.has("garrisons"):
		garrisons = {}
		for id in Data.SETTLEMENTS:
			if Lords.GARRISON_ROLES.has(String(Data.settlement(id)["type"])):
				garrisons[id] = clean_army(d["garrisons"].get(id, []))
	else:
		_start_garrisons()

	if d.has("social") and typeof(d["social"]) == TYPE_DICTIONARY:
		social = SocialSim.new()
		social.from_dict(d["social"])
	else:
		social = SocialSim.new()
		social.setup(rng.seed, lords, Data.SETTLEMENTS)


## A lord read back from JSON, with his counts as ints again.
static func _clean_lord(e: Dictionary) -> Dictionary:
	var l := {}
	for k in ["name", "realm", "culture", "bearing", "fief", "state", "job", "target", "raiding", "house", "grudge_captain_name", "grudge_company_name", "captive_of"]:
		l[k] = String(e.get(k, ""))
	for k in ["id", "renown", "silver", "party", "broke_days", "full", "ransom_amount"]:
		l[k] = int(e.get(k, 0))
	l["ruler"] = bool(e.get("ruler", false))
	l["grudge"] = bool(e.get("grudge", false))
	l["ransom_offered"] = bool(e.get("ransom_offered", false))
	l["back_at"] = float(e.get("back_at", 0.0))
	l["think_at"] = float(e.get("think_at", 0.0))
	l["ransom_at"] = float(e.get("ransom_at", 0.0))
	l["army"] = clean_army(e.get("army", []))
	var ordered := {}
	for k in ["id", "name", "realm", "culture", "house", "bearing", "ruler", "renown", "silver", "fief", "party", "state",
			"back_at", "job", "target", "think_at", "raiding", "broke_days", "full", "army",
			"grudge", "grudge_captain_name", "grudge_company_name", "captive_of", "ransom_at", "ransom_amount", "ransom_offered"]:
		ordered[k] = l[k]
	return ordered


## Squads read back from JSON, with ids and counts as ints again.
static func clean_army(raw: Array) -> Array:
	var out := []
	for s in raw:
		var squad := {"id": int(s["id"]), "type": String(s["type"]), "men": int(s["men"]), "xp": int(s.get("xp", 0)),
			"name": String(s.get("name", "")), "captain": null}
		if s.has("unit"):
			squad["unit"] = String(s["unit"])
		if s.has("level"):
			squad["level"] = int(s["level"])
		if s.has("culture"):
			squad["culture"] = String(s["culture"])
		if s.has("pending_branch"):
			squad["pending_branch"] = bool(s["pending_branch"])
		if s.has("is_bodyguard"):
			squad["is_bodyguard"] = bool(s["is_bodyguard"])
		if s.has("is_chief"):
			squad["is_chief"] = bool(s["is_chief"])
		if s.has("chief_name"):
			squad["chief_name"] = String(s["chief_name"])
		if s.has("is_lord"):
			squad["is_lord"] = bool(s["is_lord"])
		if s.has("lord_id"):
			squad["lord_id"] = int(s["lord_id"])
		if s.has("lord_name"):
			squad["lord_name"] = String(s["lord_name"])
		var c = s.get("captain")
		if typeof(c) == TYPE_DICTIONARY:
			var cap: Dictionary = c.duplicate(true)
			for k in ["id", "wounded", "battles", "kills"]:
				cap[k] = int(cap.get(k, 0))
			var raw_history = cap.get("history", {})
			if typeof(raw_history) == TYPE_DICTIONARY:
				cap["history"] = {"wounds": int(raw_history.get("wounds", 0)),
					"fallen_friends": raw_history.get("fallen_friends", []).duplicate() if typeof(raw_history.get("fallen_friends", [])) == TYPE_ARRAY else []}
			squad["captain"] = cap
		out.append(squad)
	return out
