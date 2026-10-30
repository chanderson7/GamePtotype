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

	# --- Siege auto-resolve wall multiplier and quantitative gate ---
	const AutoResolve = preload("res://scripts/battle/auto_resolve.gd")
	var garrison_squads: Array = w.garrison_at("ravensford").duplicate(true)
	var g_men: int = w.men_of(garrison_squads)
	# Raw garrison strength:
	var g_str: float = AutoResolve.strength(garrison_squads, [])
	var test_rng := RandomNumberGenerator.new()
	test_rng.seed = 12345
	# Attacker with twice the garrison's strength:
	var twice_squads: Array = [
		{"id": 1, "type": "infantry", "unit": "vard_foot", "culture": "vardish", "level": 1, "xp": 0, "men": int(g_men * 2.2), "captain": null}
	]
	var twice_wins := 0
	for seed_i in 50:
		test_rng.seed = 20000 + seed_i
		var res: Dictionary = AutoResolve.resolve_siege(twice_squads, garrison_squads, AutoResolve.WALLS["castle"], test_rng)
		if res["won"]: twice_wins += 1
	var twice_win_rate := float(twice_wins) / 50.0
	check(twice_win_rate >= 0.80, "gate: twice garrison strength takes settlement >= 80%% (got %.1f%%)" % [twice_win_rate * 100.0])

	# Attacker with less than garrison's strength:
	var weak_squads: Array = [
		{"id": 1, "type": "infantry", "unit": "vard_foot", "culture": "vardish", "level": 1, "xp": 0, "men": int(g_men * 0.7), "captain": null}
	]
	var weak_wins := 0
	for seed_i in 50:
		test_rng.seed = 30000 + seed_i
		var res: Dictionary = AutoResolve.resolve_siege(weak_squads, garrison_squads, AutoResolve.WALLS["castle"], test_rng)
		if res["won"]: weak_wins += 1
	var weak_win_rate := float(weak_wins) / 50.0
	check(weak_win_rate <= 0.20, "gate: less than garrison strength succeeds <= 20%% (got %.1f%%)" % [weak_win_rate * 100.0])

	# --- Siege lifecycle: march, besiege, assault, capture, garrison stationing & troop conservation ---
	w = fixture()
	Armies.tick(w, 0.0)
	army = w.campaign_armies[0]
	var siege_target: String = army["target"]
	var target_owner: String = w.owner_of(siege_target)
	var attacker_realm: String = army["realm"]
	# Move gathered lords to target to initiate siege:
	army["state"] = "marching"
	army["destination"] = siege_target
	var l_party = Armies.leader(w, army)
	l_party.node = siege_target
	l_party.next = ""
	l_party.along = 0.0
	l_party.path.clear()
	for m in Armies.members(w, army):
		m.node = siege_target
		m.next = ""
		m.path.clear()
	Armies.tick(w, 0.25)
	check(army["state"] == "besieging", "arriving army establishes siege camp")
	check(army.has("siege_prep_until") and army.has("siege_food_until"), "siege tracks ladder/ram preparation and defender food")

	# Fast forward past preparation to trigger assault:
	w.hour = float(army["siege_prep_until"]) + 0.1
	# Count attacker troops before assault:
	var atk_troops_before := 0
	for m in Armies.members(w, army): atk_troops_before += w.men_of(m.army)
	Armies.tick(w, 0.25)
	check(w.owner_of(siege_target) == attacker_realm, "successful assault captures settlement and changes owner")
	var new_garrison_men: int = w.men_of(w.garrison_at(siege_target))
	check(new_garrison_men > 0, "surviving attackers are stationed in the captured garrison")
	var atk_troops_after := 0
	for m in Armies.members(w, army): atk_troops_after += w.men_of(m.army)
	check(atk_troops_after + new_garrison_men <= atk_troops_before, "troop conservation: garrison troops come from attacking squads")

	# Check bound villages followed the castle:
	var bound_ok := true
	for v in World.Data.SETTLEMENTS:
		if String(World.Data.SETTLEMENTS[v].get("bound_to", "")) == siege_target:
			bound_ok = bound_ok and w.owner_of(v) == attacker_realm
	check(bound_ok, "bound villages follow captured settlement")

	# --- Capital relocation and landless fief-holder ---
	w = fixture()
	var vard_cap: String = w.capital_of("vardmark")
	var lord_with_cap = null
	for l in w.lords:
		if l["realm"] == "vardmark" and l["fief"] == vard_cap:
			lord_with_cap = l
			break
	w.set_owner(vard_cap, "kharzan")
	check(w.capital_of("vardmark") != vard_cap and w.capital_of("vardmark") != "", "captured capital relocates to another holding")
	if lord_with_cap != null:
		check(lord_with_cap["fief"] == "", "old fief holder becomes landless upon loss of seat")

	# --- Starvation capture ---
	w = fixture()
	Armies.tick(w, 0.0)
	army = w.campaign_armies[0]
	siege_target = army["target"]
	target_owner = w.owner_of(siege_target)
	army["state"] = "besieging"
	army["destination"] = siege_target
	army["siege_start"] = w.hour
	army["siege_prep_until"] = w.hour + 999.0 # Delay assault so starvation triggers first
	army["siege_food_until"] = w.hour + 24.0
	w.hour += 25.0
	Armies.tick(w, 0.25)
	check(w.owner_of(siege_target) == army["realm"], "starvation forces garrison surrender without assault")

	# --- Village militia ---
	var militia: Array = w.village_militia("kettlebrook")
	check(militia.size() == 2 and w.men_of(militia) == 15, "villages have a small defensive militia (15 men)")

	# --- Relief battle ---
	w = fixture()
	Armies.tick(w, 0.0)
	army = w.campaign_armies[0]
	siege_target = army["target"]
	army["state"] = "besieging"
	army["destination"] = siege_target
	l_party = Armies.leader(w, army)
	l_party.node = siege_target
	# Spawn a strong relief party of defender's realm at the settlement:
	var relief_lord = w.lord_parties().filter(func(p): return p.faction == army["target_owner"])[0]
	relief_lord.node = siege_target
	relief_lord.next = ""
	relief_lord.path.clear()
	# Give relief lord huge army to guarantee breaking siege:
	relief_lord.army = [{"id": 9999, "type": "cavalry", "unit": "kharz_sipahi", "culture": "kharzani", "level": 2, "xp": 100, "men": 300, "captain": null}]
	Armies.tick(w, 0.25)
	check(army["state"] == "returning" or not w.campaign_armies.has(army), "victorious relief force breaks the siege")

	print("Army failures: %d" % failures)
	quit(failures)
