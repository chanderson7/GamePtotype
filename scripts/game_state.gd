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
const SAVE_PATH := "user://campaign.json"
const SAVE_VERSION := 3

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
	var squad := {"id": _next_id, "type": type, "men": Troops.full_size(type), "xp": 0, "level": 1,
		"culture": c, "name": Captains.company_name(captain, type), "captain": captain}
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
		if int(s["men"]) < Troops.full_size(s["type"]):
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
	return Economy.recruit_cost(squad["type"], Troops.full_size(squad["type"]) - int(squad["men"]))


## Refill one squad with fresh recruits, in a town, if you can pay. Fresh men water down
## the squad's experience toward its next level, but never undo training it has paid for.
func reinforce_squad(id: int) -> bool:
	var s := squad_by_id(id)
	if s.is_empty() or not in_town():
		return false
	var full := Troops.full_size(s["type"])
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


## True if a squad has the experience for its next level and isn't at the top.
func can_train(squad: Dictionary) -> bool:
	var level := int(squad.get("level", 1))
	return level < Troops.MAX_LEVEL and Troops.level_for(int(squad["xp"])) > level


## Train a squad up a level, in a town. Each level makes its men tougher and deadlier,
## and costs more in wages.
func train_squad(id: int) -> bool:
	var s := squad_by_id(id)
	if s.is_empty() or not can_train(s) or not in_town():
		return false
	var cost := Economy.train_cost(s)
	if cost > silver:
		return false
	silver -= cost
	s["level"] = int(s.get("level", 1)) + 1
	save_game()
	return true


## Hire the recruits offered where you stand, offer number `index`. Fails if you can't
## pay or already lead as many squads as your renown allows.
func hire(place: String, index: int) -> bool:
	if world == null or world.here() != place or army.size() >= squad_cap():
		return false
	var offers: Array = world.offers_at(place)
	if index < 0 or index >= offers.size():
		return false
	var offer: Dictionary = offers[index]
	var cost := Economy.recruit_cost(offer["type"], Troops.full_size(offer["type"]))
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
	settle()


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
	var fix := "Buy food in any settlement." if hungry > 0.0 else "Beat bandits for their spoils to pay the rest."
	_note("End of day %d: %d men left the warband, %s. %s" % [_paid_day, left, why, fix])


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


## The army of the bandit band blocking the road, set up for the battle screen.
func start_encounter_battle() -> void:
	if world == null or world.encounter == -1:
		return
	var band = world.party(world.encounter)
	var site = BattleSite.pick(world, world.player_pos, "rout")
	pending_battle = {
		"enemy": WorldSim.clean_army(band.army), "culture": WorldData.culture_of(band.faction),
		"temperament": "Reckless", "name": band.name,
		"site": site,
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
	var result := AutoResolve.resolve(fighters, pending_battle["enemy"], rng, false, pending_battle.get("site"))
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


func _bond_points(a: Dictionary, b: Dictionary, seconds: float) -> float:
	var points := minf(Captains.BOND_POINTS_PER_BATTLE, seconds / Captains.BOND_SECONDS_PER_POINT)
	if a.get("quirk", "") == Captains.MENTOR or b.get("quirk", "") == Captains.MENTOR:
		points *= 1.5
	return points


## Apply a battle result from BattleSim.result_for(PLAYER).
func apply_result(result: Dictionary) -> void:
	# What became of each captain, in words, while the roster still names them.
	var fates := describe_result(result)
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
	var dead_ids := []
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
			"killed":
				dead_ids.append(int(c["id"]))
				fallen.append(_memorial(s, c, String(cr.get("words", ""))))
				# A veteran from the ranks takes command, if there's anyone left to lead.
				s["captain"] = _new_captain(String(s["type"])) if int(s["men"]) > 0 else null
	for s in army:
		var c = s.get("captain")
		if c != null:
			for d in dead_ids:
				c["bonds"].erase(str(d))
	# A squad with no men left is gone, unless its captain lived to raise it again.
	army = army.filter(func(s): return int(s["men"]) > 0 or s.get("captain") != null)
	if result.get("won", false):
		wins += 1
	if world != null and not pending_battle.is_empty():
		var band := String(pending_battle.get("name", "The bandits"))
		var how := "You lost %d men and cut down %d." % [int(result.get("lost", 0)), int(result.get("killed", 0))]
		if result.get("won", false):
			world.win_encounter()
			var got := Economy.spoils(int(result.get("killed", 0)))
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
	last_result = {
		"won": bool(result.get("won", false)),
		"lost": int(result.get("lost", 0)),
		"killed": int(result.get("killed", 0)),
		"reason": String(result.get("reason", "")),
	}
	save_game()


func _memorial(squad: Dictionary, c: Dictionary, words: String) -> Dictionary:
	var friends := []
	for other_id in c["bonds"]:
		var other = captain_by_id(int(other_id))
		var rank := Captains.rank_letter(float(c["bonds"][other_id]))
		if other != null and rank != "":
			friends.append("%s (%s)" % [other["first"], rank])
	return {
		"name": c["name"], "company": squad.get("name", ""), "type": squad["type"], "culture": squad.get("culture", culture),
		"battles": int(c["battles"]), "kills": int(c["kills"]), "battle": battles,
		"words": words,
		"bonds": friends,
	}


## Saves the campaign. Before one has started there's nothing worth keeping.
func save_game() -> void:
	if not persist or world == null:
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(to_dict()))


func to_dict() -> Dictionary:
	return {"version": SAVE_VERSION, "culture": culture, "army": army, "fallen": fallen, "battles": battles,
		"wins": wins, "next_id": _next_id, "next_captain": _next_captain,
		"silver": silver, "food": food, "renown": renown, "paid_day": _paid_day,
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
	_next_id = int(data.get("next_id", 1))
	_next_captain = int(data.get("next_captain", 1))
	fallen = data.get("fallen", []) if typeof(data.get("fallen")) == TYPE_ARRAY else []
	army = []
	for s in data["army"]:
		if typeof(s) != TYPE_DICTIONARY or not Troops.TYPES.has(String(s.get("type", ""))):
			continue
		# JSON stores numbers as floats; keep ids and counts as ints so results match by key.
		var xp := int(s.get("xp", 0))
		var squad := {"id": int(s.get("id", 0)), "type": String(s["type"]), "men": int(s.get("men", 0)), "xp": xp,
			"level": int(s.get("level", Troops.level_for(xp))), "culture": String(s.get("culture", culture)),
			"name": String(s.get("name", "")), "captain": null}
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
	return {
		"id": int(c.get("id", 0)), "name": String(c.get("name", "Nameless")), "first": String(c.get("first", "Nameless")),
		"culture": String(c.get("culture", Cultures.VARDISH)), "type": type, "temperament": String(c.get("temperament", Captains.STEADFAST)), "quirk": String(c.get("quirk", "")),
		"wounded": int(c.get("wounded", 0)), "battles": int(c.get("battles", 0)), "kills": int(c.get("kills", 0)),
		"bonds": bonds,
	}
