## Raiding a village yourself: who may, when the militia fight, the loot and the burning,
## what it costs with the realm and your sworn lords, the lords who ride to catch you,
## the map's Raid button and sheet, the town's Raid button, the battle, and saves.
extends SceneTree

const Cultures = preload("res://scripts/data/cultures.gd")
const WorldData = preload("res://scripts/world/world_data.gd")
const Lords = preload("res://scripts/data/lords.gd")
const Troops = preload("res://scripts/data/troops.gd")

var failures := 0
var gs
var scenes


func check(ok: bool, message: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + message)
	if not ok:
		failures += 1


func _go(id: String) -> void:
	var p = gs.world.player()
	p.node = id
	p.next = ""
	p.path = []
	p.wait = 0.0


func _arrive(path: String) -> void:
	for i in 240:
		await process_frame
		if current_scene != null and current_scene.scene_file_path.ends_with(path) and current_scene.is_node_ready():
			return


func _has_text(n: Node, text: String) -> bool:
	if n == null:
		return false
	for c in n.find_children("*", "", true, false):
		if (c is Label or c is Button) and String(c.text).contains(text):
			return true
	return false


## A warband of `n` squads of `men` spearmen each.
func _army(n: int, men: int) -> void:
	var out := []
	for i in n:
		var sq: Dictionary = gs.army[0].duplicate(true) if not gs.army.is_empty() else {}
		sq["id"] = 500 + i
		sq["men"] = men
		sq["wounded"] = 0
		sq["captain"] = null
		out.append(sq)
	gs.army = out


func _village_of(realm: String) -> String:
	for id in WorldData.SETTLEMENTS:
		if WorldData.is_village(id) and gs.world.owner_of(id) == realm and not gs.world.is_burned(id):
			return id
	return ""


func _init() -> void:
	await process_frame
	gs = root.get_node("GameState")
	scenes = root.get_node("Scenes")
	gs.persist = false
	gs.new_campaign(Cultures.VARDISH)
	var w = gs.world
	gs.silver = 500
	gs.food = 100
	check(w.at_war("vardmark", "kharzan"), "Vardmark and Kharzan start at war")
	var v := _village_of("kharzan")
	var v2 := ""
	for id in WorldData.SETTLEMENTS:
		if id != v and WorldData.is_village(id) and w.owner_of(id) == "kharzan":
			v2 = id
			break
	check(v != "" and v2 != "", "Kharzan has villages to raid")
	w.garrisons.erase(v)
	w.garrisons.erase(v2)
	_army(6, 12)

	# ---- who may raid
	_go(v)
	var c: Dictionary = gs.raid_check(v)
	check(not c["ok"] and String(c["reason"]).contains("not at war"), "a free company at peace with Kharzan can't raid it")
	gs.contract = {"realm": "vardmark", "daily_pay": 10, "days_left": 30, "bonus_per_lord": 100}
	check(gs.is_at_war_with("kharzan"), "serving Vardmark puts you at war with Kharzan")
	c = gs.raid_check(v)
	check(c["ok"], "now its village can be raided")
	var castle := ""
	for id in WorldData.SETTLEMENTS:
		if String(WorldData.settlement(id)["type"]) == WorldData.CASTLE and w.owner_of(id) == "kharzan":
			castle = id
			break
	_go(castle)
	check(String(gs.raid_check(castle)["reason"]).contains("walls"), "a castle isn't raided; its walls are stormed")
	check(String(gs.raid_check(v)["reason"]).contains("Ride there"), "you must be at the village")
	var own := _village_of("vardmark")
	_go(own)
	check(not gs.raid_check(own)["ok"], "your own realm's villages can't be raided")

	# ---- when the militia stand
	_go(v)
	c = gs.raid_check(v)
	check(int(c["men"]) == Lords.VILLAGE_MILITIA_MEN, "the militia are %d men" % Lords.VILLAGE_MILITIA_MEN)
	check(not bool(c["stand"]), "72 men scatter them without a fight")
	_army(2, 12)
	check(bool(gs.raid_check(v)["stand"]), "24 men don't: the militia stand")
	_army(6, 12)
	w.garrisons[v] = gs.world.village_militia(v).duplicate(true)
	check(bool(gs.raid_check(v)["stand"]) and int(gs.raid_check(v)["men"]) == Lords.VILLAGE_MILITIA_MEN * 2,
		"soldiers stationed there always stand, with the militia")
	w.garrisons.erase(v)

	# ---- the map offers it
	change_scene_to_file("res://scenes/world_map.tscn")
	await _arrive("world_map.tscn")
	check(_has_text(current_scene, "Raid the village"), "the map's place sheet offers Raid the village")
	current_scene._open_raid(v)
	await process_frame
	check(_has_text(current_scene, "Burn it") and not _has_text(current_scene, "Lead the attack"),
		"the raid sheet: the militia won't stand, so it's Burn it")

	# ---- burning it
	var silver0: int = gs.silver
	var food0: int = gs.food
	var rel0: int = gs.relation_with_realm("kharzan")
	var weary0: float = float(w.realms["kharzan"].get("weariness", 0.0))
	current_scene._on_raid_burn(v)
	await process_frame
	check(w.is_burned(v), "the village burns")
	check(gs.silver == silver0 + Lords.RAID_LOOT and gs.food == food0 + Lords.PLAYER_RAID_FOOD,
		"you carry off %d silver and %d rations" % [Lords.RAID_LOOT, Lords.PLAYER_RAID_FOOD])
	check(gs.relation_with_realm("kharzan") == rel0 + Lords.PLAYER_RAID_REALM, "Kharzan thinks worse of you")
	check(float(w.realms["kharzan"].get("weariness", 0.0)) > weary0, "and grows wearier of the war")
	check(w.player_raiding() == v and is_equal_approx(w.player().wait, Lords.RAID_HOURS),
		"your men stay %d hours loading the carts" % int(Lords.RAID_HOURS))
	check(w.activity_log.any(func(e): return String(e.get("text", "")).contains("burned by your company")),
		"the news says your company burned it")
	check(String(gs.raid_check(v)["reason"]).contains("already"), "a burned village can't be raided again")
	check(_has_text(current_scene, "burns"), "the map says what you took")

	# ---- its lords ride to catch you
	var defender: Dictionary = {}
	for l in w.lords:
		var lp = w.party(int(l["party"]))
		if String(l["realm"]) == "kharzan" and lp != null and not bool(l.get("ruler", false)):
			defender = l
			break
	var dp = w.party(int(defender["party"]))
	var near := ""
	for id in WorldData.SETTLEMENTS:
		if id != v and w._hours(dp, id, v) <= Lords.DEFEND_HOURS * 0.5:
			near = id
			break
	dp.node = near
	dp.next = ""
	dp.path = []
	dp.wait = 0.0
	dp.grace_until = w.hour + 100.0
	defender["job"] = ""
	defender["raiding"] = ""
	defender["grudge"] = false
	for sq in dp.army:
		sq["men"] = maxi(int(sq["men"]), 20)
	defender["full"] = w.men_of(dp.army)
	w._think_lord(defender, dp)
	check(String(defender["job"]) == "defend" and String(defender["target"]) == v, "a Kharzan lord rides to defend it")
	w.player().wait = 0.0
	w.player().node = w.player().node
	w.player_raid["until"] = w.hour
	defender["job"] = ""
	w._think_lord(defender, dp)
	check(w.player_raiding() == "" and String(defender["job"]) != "defend", "once the carts are loaded nobody rides to it")

	# ---- saves keep the raid
	w.player_raid = {"village": v, "until": w.hour + 3.0}
	var round_trip = load("res://scripts/world/world_sim.gd").new()
	round_trip.from_dict(w.to_dict())
	check(String(round_trip.player_raid.get("village", "")) == v, "a save keeps the raid in progress")
	w.player_raid = {}

	# ---- the militia fight: sent in, won and lost
	_go(v2)
	w.garrisons[v2] = gs.world.village_militia(v2).duplicate(true)
	_army(8, 12)
	c = gs.raid_check(v2)
	check(bool(c["stand"]), "with soldiers stationed there, the militia stand")
	current_scene._open_raid(v2)
	await process_frame
	check(_has_text(current_scene, "Lead the attack") and _has_text(current_scene, "Send them in"), "so the sheet offers a fight")
	var lost: Dictionary = gs.auto_resolve_raid(v2)
	check(bool(lost.get("won", false)) == w.is_burned(v2), "it burns only if they broke (%s)" % ("won" if lost.get("won", false) else "lost"))
	check(gs.pending_battle.is_empty(), "the battle is cleared after")

	# A sure loss: a handful against a strong garrison.
	var v3 := ""
	for id in WorldData.SETTLEMENTS:
		if id != v and id != v2 and WorldData.is_village(id) and w.owner_of(id) == "kharzan" and not w.is_burned(id):
			v3 = id
			break
	_go(v3)
	var big: Array = []
	for i in 6:
		var sq: Dictionary = gs.world.village_militia(v3)[0].duplicate(true)
		sq["id"] = 8800 + i
		sq["men"] = 30
		big.append(sq)
	w.garrisons[v3] = big
	_army(1, 5)
	var r: Dictionary = gs.auto_resolve_raid(v3)
	check(not bool(r.get("won", true)) and not w.is_burned(v3), "beaten by the militia, the village doesn't burn")
	w.garrisons.erase(v3)

	# ---- a fight you lead goes to the battle screen
	_army(6, 12)
	w.garrisons[v3] = gs.world.village_militia(v3).duplicate(true)
	gs.start_raid_battle(v3)
	check(String(gs.pending_battle.get("objective", "")) == "raid" and String(gs.pending_battle.get("raid_target", "")) == v3,
		"leading the attack sets up a raid battle")
	change_scene_to_file("res://scenes/battle.tscn")
	await _arrive("battle.tscn")
	for i in 10:
		await process_frame
	check(current_scene != null and String(current_scene.sim.objective) == "raid", "the battle screen fights it")
	var won := {"won": true, "lost": 0, "killed": 15, "squads": {}, "enemy_squads": {}, "objective": "raid"}
	gs.apply_result(won)
	check(w.is_burned(v3), "a won raid battle burns the village")
	change_scene_to_file("res://scenes/main_menu.tscn")
	await process_frame
	w.garrisons.erase(v3)

	# ---- the town's Raid button opens the map's raid sheet
	var v4 := _village_of("kharzan")
	_go(v4)
	w.player().wait = 0.0
	scenes.settlement_arrival_pending = false
	change_scene_to_file("res://scenes/settlement.tscn")
	await _arrive("settlement.tscn")
	var raid_btn := current_scene.find_child("Raid", true, false) as Button
	check(raid_btn != null and raid_btn.text.begins_with("Raid "), "the barred village has a Raid button")
	raid_btn.pressed.emit()
	await _arrive("world_map.tscn")
	check(current_scene.scene_file_path.ends_with("world_map.tscn") and _has_text(current_scene, "Burn it"),
		"it opens the map's raid sheet")
	check(scenes.map_raid == "", "and only once")

	# ---- a crown's lords judge it by their bearing
	gs.new_campaign(Cultures.VARDISH)
	w = gs.world
	gs.renown = 250
	gs.player_fief = {"settlement_id": "ravensford", "realm": w.owner_of("ravensford"), "silver": 0, "food": 20,
		"improvements": {}, "garrison": [], "granted_at": 0.0, "lost": false}
	_go("ravensford")
	check(gs.declare_crown(), "a crown at Ravensford")
	var honorable: Dictionary = {}
	var cruel: Dictionary = {}
	for l in w.lords:
		if bool(l.get("ruler", false)):
			continue
		if honorable.is_empty() and String(l["bearing"]) == Lords.HONORABLE:
			honorable = l
		elif cruel.is_empty() and String(l["bearing"]) == Lords.CRUEL:
			cruel = l
	check(not honorable.is_empty() and not cruel.is_empty(), "there are Honorable and Cruel lords")
	honorable["realm"] = WorldData.CROWN
	cruel["realm"] = WorldData.CROWN
	check(gs.crown_lords().has(honorable) and gs.crown_lords().has(cruel), "both sworn to the crown")
	if not w.at_war(WorldData.CROWN, "kharzan"):
		w.declare_war(WorldData.CROWN, "kharzan", true)
	var v5 := _village_of("kharzan")
	w.garrisons.erase(v5)
	_go(v5)
	_army(6, 12)
	var h0: int = int(gs.lord_relations.get(int(honorable["id"]), 0))
	var c0: int = int(gs.lord_relations.get(int(cruel["id"]), 0))
	var got: Dictionary = gs.raid_village(v5)
	check(not got.is_empty(), "a crown at war raids")
	check(int(gs.lord_relations.get(int(honorable["id"]), 0)) == h0 + Lords.RAID_HONORABLE_REGARD, "an Honorable sworn lord thinks less of you")
	check(int(gs.lord_relations.get(int(cruel["id"]), 0)) == c0 + Lords.RAID_CRUEL_REGARD, "a Cruel one approves")
	check((got["shamed"] as Array).size() >= 1 and (got["liked"] as Array).size() >= 1 and String(got["text"]).contains("Regard"),
		"and the note names them")

	print("\nRaid tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
