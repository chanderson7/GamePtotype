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
const SAVE_PATH := "user://campaign.json"
const SAVE_VERSION := 6

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
var world = null
## The fight the map has set up for the battle screen: {enemy, culture, temperament,
## name}. Empty when the battle screen should make up its own enemy.
var pending_battle := {}
## What the map should tell the player when they get back from a battle, or "".
var map_notice := ""
## Unread desertion warning survives saving until the player acknowledges it.
var desertion_warning := ""
## Battles the autoplay smoke test has fought this run.
var autoplay_battles := 0
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
	new_warband()
	world = WorldSim.new()
	world.setup(rng.randi(), culture)
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
	map_notice = ""
	desertion_warning = ""
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
	var squad := {"id": _next_id, "type": type, "unit": unit_id, "men": full, "xp": 0, "level": 1,
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


func is_wounded() -> bool:
	for s in army:
		var full := Units.full_size(s.get("unit", "")) if Units.has(s.get("unit", "")) else Troops.full_size(s["type"])
		if int(s["men"]) < full:
			return true
	return false


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
	return food / maxi(1, total_men())


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
	s["xp"] = int(int(s["xp"]) * int(s["men"]) / float(full))
	s["men"] = full
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


## Let time pass on the map, then settle wages and food for every day that ended.
func advance(hours: float) -> void:
	if world == null:
		return
	world.step(hours)
	drain_social_settlements()
	settle()


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


func apply_social_choice(candidate_id: String, choice_id: String) -> Dictionary:
	if world == null or world.social == null:
		return {"ok": false, "reason": "No world or social simulation active."}
	var sound = get_node_or_null("/root/Sound")
	var invitations := true
	if sound != null and sound.has_method("romance_invitations_enabled"):
		invitations = bool(sound.romance_invitations_enabled())
	var context := {
		"player_silver": silver,
		"player_food": food,
		"player_renown": renown,
		"current_hour": world.hour,
		"invitations_enabled": invitations
	}
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


## One day's wages and food. Whatever can't be paid or fed is a share of the men going
## without, and up to DESERTION of them leave: a short day costs a few men, an empty
## purse costs one man in ten.
func _upkeep() -> void:
	var men := total_men()
	if men == 0:
		return
	var eaten := mini(food, men)
	food -= eaten
	var wages := daily_wages()
	var paid := mini(silver, wages)
	silver -= paid
	var hungry := 1.0 - float(eaten) / men
	var unpaid := 1.0 - float(paid) / maxf(1.0, wages)
	var share := Economy.DESERTION * maxf(hungry, unpaid)
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
	var a = captain_by_id(a_id)
	var b = captain_by_id(b_id)
	if a == null or b == null:
		return false
	var rank := Captains.rank_letter(float(a.get("bonds", {}).get(str(b_id), 0.0)))
	return rank != "" and not bond_record(a_id, b_id).get("conversations", []).has(rank)


## A replayable, event-aware camp exchange. It reads campaign facts and changes no combat,
## bond or relationship values; only the "new" marker is acknowledged.
func bond_conversation(a_id: int, b_id: int) -> Dictionary:
	var a = captain_by_id(a_id)
	var b = captain_by_id(b_id)
	if a == null or b == null:
		return {}
	var points := float(a.get("bonds", {}).get(str(b_id), 0.0))
	var rank := Captains.rank_letter(points)
	if rank == "":
		return {}
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
	passages.append(_bond_voice_line(a, b))
	return {"a": a, "b": b, "rank": rank, "points": points, "shared_battles": shared, "passages": passages}


func _bond_voice_line(a: Dictionary, b: Dictionary) -> String:
	match String(a.get("temperament", Captains.STEADFAST)):
		Captains.VENGEFUL:
			return "\"If you fall,\" %s says, \"I finish what reached you.\" %s answers, \"Then I had better stay standing.\"" % [a["first"], b["first"]]
		Captains.FRAGILE:
			return "%s admits that the line feels thinner whenever %s is out of sight. %s does not laugh; that is answer enough." % [a["first"], b["first"], b["first"]]
		_:
			return "%s says, \"Same distance tomorrow. Close enough to help, far enough to breathe.\" %s nods." % [a["first"], b["first"]]


func acknowledge_bond_conversation(a_id: int, b_id: int) -> void:
	var a = captain_by_id(a_id)
	var b = captain_by_id(b_id)
	if a == null or b == null:
		return
	var rank := Captains.rank_letter(float(a.get("bonds", {}).get(str(b_id), 0.0)))
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
	if not site["fair"]:
		temperament = Commander.PATIENT
	elif objective == "chief":
		temperament = Commander.TEMPERAMENTS[prng.randi_range(0, Commander.TEMPERAMENTS.size() - 1)]
	return {"objective": objective, "site": site, "temperament": temperament}


## The army of the bandit band blocking the road, set up for the battle screen.
func start_encounter_battle() -> void:
	if world == null or world.encounter == -1:
		return
	var band = world.party(world.encounter)
	var plan := encounter_plan(band)
	var objective: String = plan["objective"]
	var chief_name := ""
	if objective == "chief":
		chief_name = band.chief_name if band.chief_name != "" else band.name.split("'s")[0]

	pending_battle = {
		"enemy": WorldSim.clean_army(band.army), "culture": WorldData.culture_of(band.faction),
		"temperament": plan["temperament"], "name": band.name,
		"site": plan["site"],
		"objective": objective,
		"chief_name": chief_name,
		"raid_village": band.raid_village,
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
		var row := {
			"id": id, "name": String(squad.get("name", "Company")),
			"unit_name": Units.troop_name(squad, culture),
			"men_before": before_men, "men_after": after_men,
			"lost": maxi(0, before_men - after_men), "kills": battle_kills,
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
			captain_rows.append({
				"id": int(captain.get("id", 0)),
				"appearance_id": Captains.ensure_appearance(captain),
				"name": String(captain.get("name", "Captain")),
				"first": String(captain.get("first", "Captain")),
				"company": String(squad.get("name", "Company")),
				"culture": String(captain.get("culture", culture)),
				"fate": String(captain_result.get("fate", "standing")),
				"roll": int(captain_result.get("roll", 0)),
				"needed": int(captain_result.get("needed", 0)),
				"kills": int(captain_result.get("kills", 0)),
				"words": String(captain_result.get("words", "")),
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
			"before": before, "earned": earned, "after": after,
			"rank_before": Captains.rank_letter(before),
			"rank_after": Captains.rank_letter(after),
			"rank_up": Captains.rank_for(after) > Captains.rank_for(before),
		})

	var rewards := {"silver": 0, "food": 0, "renown": 0}
	if won and world != null and not pending_battle.is_empty():
		rewards = Economy.spoils(killed)
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
		story += " %d %s did not return." % [lost, "soldier" if lost == 1 else "soldiers"]
	return {
		"won": won, "lost": lost, "killed": killed,
		"reason": String(result.get("reason", "")), "story": story,
		"rewards": rewards, "captains": captain_rows, "bonds": bond_rows,
		"squads": squad_rows,
	}


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
		if rank == "C" and bond_intro_seen:
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
		bond_events.append({"kind": "memorial", "rank": rank,
			"a_id": int(survivor["id"]), "b_id": int(fallen_captain["id"]),
			"pair": "%s remembers %s" % [survivor["name"], fallen_captain["name"]],
			"fallen_name": String(fallen_captain["name"]), "battle": battles,
			"shared_battles": int(record.get("shared_battles", 0))})
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
			s["men"] = int(by_id[id]["men"])
			s["xp"] = int(s["xp"]) + int(by_id[id]["kills"])
		if c == null:
			continue
		var cr = by_id.get(id, {}).get("captain")
		if cr == null:
			# Sat this one out with a wound, and is a battle closer to fighting again.
			if int(c.get("wounded", 0)) > 0:
				c["wounded"] = int(c["wounded"]) - 1
			continue
		c["battles"] = int(c["battles"]) + 1
		c["kills"] = int(c["kills"]) + int(cr["kills"])
		match String(cr["fate"]):
			"wounded":
				c["wounded"] = Captains.WOUND_BATTLES
				var history: Dictionary = c.get("history", {"wounds": 0, "fallen_friends": []})
				history["wounds"] = int(history.get("wounds", 0)) + 1
				c["history"] = history
			"killed":
				dead_ids.append(int(c["id"]))
				fallen_captains.append(c)
				fallen.append(_memorial(s, c, String(cr.get("words", ""))))
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
	if world != null and not pending_battle.is_empty():
		var band := String(pending_battle.get("name", "The bandits"))
		var how := "You lost %d men and cut down %d." % [int(result.get("lost", 0)), int(result.get("killed", 0))]
		var obj: String = String(pending_battle.get("objective", "rout"))
		var c_name: String = String(pending_battle.get("chief_name", ""))
		var r_village: String = String(pending_battle.get("raid_village", ""))
		if result.get("won", false):
			world.win_encounter()
			var got := Economy.spoils(int(result.get("killed", 0)))
			if obj == "chief":
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
			_note("%s are scattered. %s Spoils: %d silver, %d rations, %d renown." % [
				band, how, got["silver"], got["food"], got["renown"]])
		else:
			world.hurt_band(result.get("enemy_squads", {}))
			world.lose_encounter()
			var home := String(WorldData.settlement(world.here())["name"])
			if total_men() > 0:
				_note("%s beat you. %s The survivors regroup at %s, half a day later." % [band, how, home])
			else:
				_note("%s cut down your whole warband." % band)
		for line in fates:
			_note(line)
		settle()
	pending_battle = {}
	last_result = report
	save_game()


func _memorial(squad: Dictionary, c: Dictionary, words: String) -> Dictionary:
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
	}


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


func to_dict() -> Dictionary:
	return {"version": SAVE_VERSION, "culture": culture, "army": army, "fallen": fallen, "battles": battles,
		"wins": wins, "next_id": _next_id, "next_captain": _next_captain,
		"silver": silver, "food": food, "renown": renown, "paid_day": _paid_day,
		"bond_intro_seen": bond_intro_seen, "bond_intro_pair": bond_intro_pair, "bond_intro_ids": bond_intro_ids,
		"bond_events": bond_events, "bond_records": bond_records,
		"desertion_warning": desertion_warning, "last_result": last_result,
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
	silver = int(data.get("silver", Economy.START_SILVER))
	food = int(data.get("food", -1))
	renown = int(data.get("renown", 0))
	_paid_day = int(data.get("paid_day", int(world.hour / 24.0) if world != null else 0))
	wins = int(data.get("wins", 0))
	last_result = data.get("last_result", {}) if typeof(data.get("last_result")) == TYPE_DICTIONARY else {}
	_next_id = int(data.get("next_id", 1))
	_next_captain = int(data.get("next_captain", 1))
	fallen = data.get("fallen", []) if typeof(data.get("fallen")) == TYPE_ARRAY else []
	for memorial in fallen:
		if typeof(memorial) == TYPE_DICTIONARY:
			Captains.ensure_appearance(memorial)
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
			"men": int(s.get("men", 0)), "xp": xp, "level": level, "pending_branch": pending_branch,
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


func _clean_captain(c: Dictionary, type: String) -> Dictionary:
	var bonds := {}
	var raw = c.get("bonds", {})
	if typeof(raw) == TYPE_DICTIONARY:
		for k in raw:
			bonds[str(int(float(k)))] = float(raw[k])
	var history := {"wounds": 0, "fallen_friends": []}
	if typeof(c.get("history")) == TYPE_DICTIONARY:
		history["wounds"] = int(c["history"].get("wounds", 0))
		history["fallen_friends"] = c["history"].get("fallen_friends", []) if typeof(c["history"].get("fallen_friends")) == TYPE_ARRAY else []
	var clean := {
		"id": int(c.get("id", 0)), "name": String(c.get("name", "Nameless")), "first": String(c.get("first", "Nameless")),
		"culture": String(c.get("culture", Cultures.VARDISH)), "type": type, "temperament": String(c.get("temperament", Captains.STEADFAST)), "quirk": String(c.get("quirk", "")),
		"wounded": int(c.get("wounded", 0)), "battles": int(c.get("battles", 0)), "kills": int(c.get("kills", 0)),
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
