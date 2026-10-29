extends SceneTree
const World = preload("res://scripts/world/world_sim.gd")
const Armies = preload("res://scripts/world/marshal_armies.gd")
const Cultures = preload("res://scripts/data/cultures.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	print(("ok " if ok else "FAIL ") + message)
	if not ok: failures += 1
func snapshot(w) -> Dictionary:
	var out := {}
	for p in w.lord_parties(): out[p.id] = p.army.duplicate(true)
	return out
func tick(w, hours: int) -> void:
	for i in hours * 4:
		w.hour += 0.25
		Armies.tick(w, 0.25)
func fixture():
	var w := World.new()
	w.setup(31, Cultures.VARDISH)
	return w
func _init() -> void:
	var w = fixture()
	var before := snapshot(w)
	Armies.tick(w, 0.0)
	check(not w.campaign_armies.is_empty(), "a realm at war calls a muster")
	check(snapshot(w) == before, "forming armies preserves all troops")
	var ids: Array = []
	var unique := true
	for army in w.campaign_armies:
		for id in army["members"]:
			unique = unique and not ids.has(id)
			ids.append(id)
	check(unique, "a lord belongs to only one army")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(w.to_dict()))
	var restored := World.new()
	restored.from_dict(saved)
	tick(w, 8)
	tick(restored, 8)
	check(JSON.parse_string(JSON.stringify(w.to_dict())) == JSON.parse_string(JSON.stringify(restored.to_dict())), "muster save resumes deterministically")
	var marched := false
	for i in 96:
		tick(w, 1)
		if w.campaign_armies.any(func(a): return a["state"] == "marching"):
			marched = true
			break
	check(marched, "gathered lords depart for a hostile settlement")
	check(snapshot(w) == before, "mustering and marching preserve troop ownership")
	var visible := w.visible_lord_parties().size()
	check(visible < w.lord_parties().size(), "joined lords use one map marker")
	var traveling := World.new()
	traveling.from_dict(JSON.parse_string(JSON.stringify(w.to_dict())))
	tick(w, 3)
	tick(traveling, 3)
	check(JSON.parse_string(JSON.stringify(w.to_dict())) == JSON.parse_string(JSON.stringify(traveling.to_dict())), "marching save resumes deterministically")
	var owners: Dictionary = w.owners.duplicate()
	for a in w.campaign_armies.duplicate(): w.make_peace(a["realm"], a["target_owner"])
	tick(w, 150)
	check(w.campaign_armies.is_empty(), "peace returns or disbands every army within its deadline")
	check(w.owners == owners, "formation slice never silently captures settlements")
	check(snapshot(w) == before, "returning and disband preserve troops")
	w = fixture()
	Armies.tick(w, 0.0)
	var army: Dictionary = w.campaign_armies[0]
	var old_id: int = army["id"]
	w.set_owner(army["target"], army["realm"])
	tick(w, 1)
	check(not w.campaign_armies.any(func(a): return int(a["id"]) == old_id), "captured target cancels gathering")
	w = fixture()
	Armies.tick(w, 0.0)
	army = w.campaign_armies[0]
	old_id = army["id"]
	w._routed(w.party(int(army["leader"])))
	tick(w, 1)
	check(not w.campaign_armies.any(func(a): return int(a["id"]) == old_id), "unavailable marshal releases remaining members")
	w = fixture()
	Armies.tick(w, 0.0)
	army = w.campaign_armies[0]
	for member in Armies.members(w, army):
		member.node = army["muster"]
		member.next = ""
		member.path.clear()
	tick(w, 1)
	var marshal = Armies.leader(w, army)
	var group: Array = w.army_parties(marshal)
	var opponent = w.lord_parties().filter(func(p): return p.faction != marshal.faction and w.at_war(p.faction, marshal.faction))[0]
	var before_fight := 0
	for member in group: before_fight += w.men_of(member.army)
	before_fight += w.men_of(opponent.army)
	w._ai_fight(marshal, opponent)
	var after_fight := 0
	for member in group: after_fight += w.men_of(member.army)
	after_fight += w.men_of(opponent.army)
	check(group.size() >= 2 and after_fight < before_fight, "army auto-resolve applies losses to member-owned troops")
	check(group.all(func(p): return w.party(p.id) != null) or group.all(func(p): return w.party(p.id) == null), "defeated army members retreat together")
	w = fixture()
	Armies.tick(w, 0.0)
	army = w.campaign_armies[0]
	old_id = army["id"]
	army["deadline"] = w.hour
	Armies.leader(w, army).next = "ravensford"
	Armies.leader(w, army).node = "zeyra"
	tick(w, 1)
	check(not w.campaign_armies.any(func(a): return int(a["id"]) == old_id), "incomplete muster expires instead of waiting forever")
	var legacy: Dictionary = w.to_dict()
	legacy.erase("campaign_armies")
	legacy.erase("army_ready_at")
	legacy.erase("next_army_id")
	restored.from_dict(legacy)
	check(restored.campaign_armies.is_empty() and restored.next_army_id == 1, "old saves start without expeditions")
	print("Army failures: %d" % failures)
	quit(failures)
