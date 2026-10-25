## The player's warband, carried between battles and saved on the device.
## This is the seed of the campaign layer: the war map will read and change this roster.
##
## Every squad is led by a named captain. Captains who fall in battle roll for their
## fate: wounded ones sit out a couple of battles, dead ones go on the memorial and a
## veteran from the ranks steps up. Captains who fight side by side build bonds.
extends Node

const Troops = preload("res://scripts/data/troops.gd")
const Captains = preload("res://scripts/data/captains.gd")
const SAVE_PATH := "user://warband.json"

## Each squad: {id, type, men, xp, name, captain}. A squad that loses every man is
## removed, unless its captain lived to raise it again.
var army: Array = []
## The dead, newest last: {name, company, type, battles, kills, battle, words, bonds}.
var fallen: Array = []
var battles := 0
var wins := 0
var last_result := {}
## Set false in tests so nothing touches the save file.
var persist := true
var rng := RandomNumberGenerator.new()
var _next_id := 1
var _next_captain := 1


func _ready() -> void:
	rng.randomize()
	if not load_game():
		new_warband()


func new_warband() -> void:
	army = []
	fallen = []
	battles = 0
	wins = 0
	last_result = {}
	_next_id = 1
	_next_captain = 1
	for type in [Troops.INFANTRY, Troops.INFANTRY, Troops.SPEARMEN, Troops.SPEARMEN, Troops.ARCHERS, Troops.ARCHERS, Troops.CAVALRY]:
		army.append(_new_squad(type))
	save_game()


func _new_squad(type: String) -> Dictionary:
	var captain := _new_captain(type)
	var squad := {"id": _next_id, "type": type, "men": Troops.full_size(type), "xp": 0,
		"name": Captains.company_name(captain, type), "captain": captain}
	_next_id += 1
	return squad


func _new_captain(type: String) -> Dictionary:
	var taken := []
	for s in army:
		if s.get("captain") != null:
			taken.append(s["captain"]["first"])
	var c := Captains.make(rng, _next_captain, type, taken)
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
	return army.size() < 4


## Refill every squad. A placeholder for recruiting in towns on the war map.
func reinforce() -> void:
	for s in army:
		s["men"] = Troops.full_size(s["type"])
	while army.size() < 4:
		army.append(_new_squad(Troops.ORDER[army.size() % Troops.ORDER.size()]))
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


## A fresh enemy host that grows a little every other battle, led by its own captains.
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
		"name": c["name"], "company": squad.get("name", ""), "type": squad["type"],
		"battles": int(c["battles"]), "kills": int(c["kills"]), "battle": battles,
		"words": words,
		"bonds": friends,
	}


func save_game() -> void:
	if not persist:
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"army": army, "fallen": fallen, "battles": battles, "wins": wins,
		"next_id": _next_id, "next_captain": _next_captain}))


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(data) != TYPE_DICTIONARY or not data.has("army"):
		return false
	battles = int(data.get("battles", 0))
	wins = int(data.get("wins", 0))
	_next_id = int(data.get("next_id", 1))
	_next_captain = int(data.get("next_captain", 1))
	fallen = data.get("fallen", []) if typeof(data.get("fallen")) == TYPE_ARRAY else []
	army = []
	for s in data["army"]:
		if typeof(s) != TYPE_DICTIONARY or not Troops.TYPES.has(String(s.get("type", ""))):
			continue
		# JSON stores numbers as floats; keep ids and counts as ints so results match by key.
		var squad := {"id": int(s.get("id", 0)), "type": String(s["type"]), "men": int(s.get("men", 0)), "xp": int(s.get("xp", 0)),
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
	return true


func _clean_captain(c: Dictionary, type: String) -> Dictionary:
	var bonds := {}
	var raw = c.get("bonds", {})
	if typeof(raw) == TYPE_DICTIONARY:
		for k in raw:
			bonds[str(int(float(k)))] = float(raw[k])
	return {
		"id": int(c.get("id", 0)), "name": String(c.get("name", "Nameless")), "first": String(c.get("first", "Nameless")),
		"type": type, "temperament": String(c.get("temperament", Captains.STEADFAST)), "quirk": String(c.get("quirk", "")),
		"wounded": int(c.get("wounded", 0)), "battles": int(c.get("battles", 0)), "kills": int(c.get("kills", 0)),
		"bonds": bonds,
	}
