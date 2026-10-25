## The player's warband, carried between battles and saved on the device.
## This is the seed of the campaign layer: the war map will read and change this roster.
extends Node

const Troops = preload("res://scripts/data/troops.gd")
const SAVE_PATH := "user://warband.json"

## Each squad: {id, type, men, xp}. Squads that lose every man are removed.
var army: Array = []
var battles := 0
var wins := 0
var last_result := {}
var _next_id := 1


func _ready() -> void:
	if not load_game():
		new_warband()


func new_warband() -> void:
	army = []
	battles = 0
	wins = 0
	last_result = {}
	_next_id = 1
	for type in [Troops.INFANTRY, Troops.INFANTRY, Troops.SPEARMEN, Troops.SPEARMEN, Troops.ARCHERS, Troops.ARCHERS, Troops.CAVALRY]:
		army.append(_new_squad(type))
	save_game()


func _new_squad(type: String) -> Dictionary:
	var squad := {"id": _next_id, "type": type, "men": Troops.full_size(type), "xp": 0}
	_next_id += 1
	return squad


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


## A fresh enemy host that grows a little every other battle.
func enemy_army() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var types := [Troops.INFANTRY, Troops.INFANTRY, Troops.SPEARMEN, Troops.ARCHERS, Troops.CAVALRY]
	for i in mini(4, int(battles / 2.0) + 1):
		types.append(Troops.ORDER[rng.randi_range(0, Troops.ORDER.size() - 1)])
	var xp := mini(battles * 3, Troops.XP_PER_LEVEL * 2)
	var out := []
	var id := 1000
	for type in types:
		out.append({"id": id, "type": type, "men": Troops.full_size(type), "xp": xp})
		id += 1
	for i in range(out.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = out[i]
		out[i] = out[j]
		out[j] = tmp
	return out


## Apply a battle result from BattleSim.result_for(PLAYER).
func apply_result(result: Dictionary) -> void:
	var by_id: Dictionary = result.get("squads", {})
	for s in army:
		var id := int(s["id"])
		if by_id.has(id):
			s["men"] = int(by_id[id]["men"])
			s["xp"] = int(s["xp"]) + int(by_id[id]["kills"])
	army = army.filter(func(s): return int(s["men"]) > 0)
	battles += 1
	if result.get("won", false):
		wins += 1
	last_result = {
		"won": bool(result.get("won", false)),
		"lost": int(result.get("lost", 0)),
		"killed": int(result.get("killed", 0)),
		"reason": String(result.get("reason", "")),
	}
	save_game()


func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"army": army, "battles": battles, "wins": wins, "next_id": _next_id}))


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(data) != TYPE_DICTIONARY or not data.has("army"):
		return false
	army = []
	for s in data["army"]:
		if typeof(s) == TYPE_DICTIONARY and Troops.TYPES.has(String(s.get("type", ""))):
			# JSON stores numbers as floats; keep ids as ints so results match by key.
			army.append({"id": int(s.get("id", 0)), "type": String(s["type"]), "men": int(s.get("men", 0)), "xp": int(s.get("xp", 0))})
	battles = int(data.get("battles", 0))
	wins = int(data.get("wins", 0))
	_next_id = maxi(int(data.get("next_id", 1)), army.size() + 1)
	for s in army:
		_next_id = maxi(_next_id, int(s["id"]) + 1)
	return true
