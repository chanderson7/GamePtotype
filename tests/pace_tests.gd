## Pace on the map: small and mounted companies are quick, big columns slow, and a hostile
## lord who is stronger rides after you, catching you only if he's quicker.
extends SceneTree

const Cultures = preload("res://scripts/data/cultures.gd")
const Troops = preload("res://scripts/data/troops.gd")
const WorldData = preload("res://scripts/world/world_data.gd")
const WorldSim = preload("res://scripts/world/world_sim.gd")

var gs
var w
var failures := 0


func check(ok: bool, message: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + message)
	if not ok:
		failures += 1


func _init() -> void:
	await process_frame
	gs = root.get_node("GameState")
	gs.persist = false
	gs.new_campaign(Cultures.VARDISH)
	w = gs.world

	# 1. Pace by size, horses and wounds.
	check(WorldSim.pace(30) > WorldSim.pace(100) and WorldSim.pace(100) > WorldSim.pace(250),
		"a small company is quicker than a big one (%.2f, %.2f, %.2f)" % [WorldSim.pace(30), WorldSim.pace(100), WorldSim.pace(250)])
	check(is_equal_approx(WorldSim.pace(2000), WorldSim.PACE_MIN) and WorldSim.pace(1) <= WorldSim.PACE_MAX + 0.0001,
		"and pace has a floor and a ceiling")
	check(WorldSim.pace(100, 100) > WorldSim.pace(100, 0), "a mounted company is quicker than one on foot")
	check(WorldSim.pace(100, 0, 50) < WorldSim.pace(100), "carrying wounded slows you down")
	var start_speed: float = w.player_speed()
	check(start_speed > 0.0, "a new company rides at %.0f" % start_speed)
	gs.food = 0
	w._pace_cache.clear()
	check(w.player_speed() < start_speed, "and an empty larder slows it")
	gs.food = 200
	w._pace_cache.clear()

	# 2. Travel times follow your pace.
	var far := ""
	for id in WorldData.SETTLEMENTS:
		if id != w.player().node and not w.path(w.player().node, id).is_empty():
			far = id
			break
	var light: float = w.hours_to(far)
	_set_company(60, Troops.INFANTRY)
	var heavy: float = w.hours_to(far)
	check(heavy > light, "a heavy column takes longer to ride the same roads (%.1f h against %.1f h)" % [heavy, light])

	# 3. A marshal's army moves at the whole army's pace.
	var realm := "vardmark"
	var members: Array = []
	for l in w.lords:
		if l["realm"] == realm and members.size() < 3:
			members.append(int(l["party"]))
	var lone: float = w.party_speed(w.party(members[0]))
	w.campaign_armies.append({"id": 99, "realm": realm, "leader": members[0], "members": members, "state": "marching",
		"target": far, "destination": far})
	w._pace_cache.clear()
	check(w.party_speed(w.party(members[0])) < lone, "a lord in a marshal's army keeps the slower pace of the whole host")
	w.campaign_armies.clear()
	w._pace_cache.clear()

	# 4. A stronger hostile lord who sees you gives chase, and catches you only if quicker.
	gs.contract = {"realm": "vardmark", "daily_pay": 10, "days_left": 30, "bonus_per_lord": 100}
	# Keep the marshals at home, so the lord we watch rides on his own.
	for r in w.realms:
		w.army_ready_at[r] = 1.0e9
	var hunter: Dictionary = {}
	for l in w.lords:
		if l["realm"] == "kharzan" and l["state"] == "field" and w.MarshalArmies.for_party(w, int(l["party"])).is_empty():
			hunter = l
			break
	var hp = w.party(int(hunter["party"]))
	check(w.relation_to_player(hp.faction) == "hostile", "Kharzani lords are hostile while you serve Vardmark")

	# A quick, small company gets away.
	_set_company(12, Troops.CAVALRY, 3)
	var gap: Array = []
	var caught := _run_chase(hp, 160, gap)
	check(not caught and not gap.is_empty() and float(gap[0]) > 0.0,
		"a small mounted company outruns a lord with %d men (the gap grows by %.0f)" % [w.men_of(hp.army), float(gap[0]) if not gap.is_empty() else 0.0])
	# A big column on foot is ridden down.
	# A big column on foot, carrying wounded and out of food, is run down.
	_set_company(40, Troops.INFANTRY, 6)
	for sq in gs.army:
		sq["wounded"] = 30
	gs.food = 0
	gap = []
	caught = _run_chase(hp, 300, gap)
	check(caught or (not gap.is_empty() and float(gap[0]) < 0.0),
		"a slow column is run down by a lord with %d men (%s)" % [w.men_of(hp.army), "caught" if caught else "the gap closes by %.0f" % -float(gap[0])])
	gs.food = 500
	_set_company(70, Troops.INFANTRY, 6)
	# For the withdrawal check: a host of 600, a quarter mounted, a little quicker than you.
	for i in hp.army.size():
		hp.army[i]["men"] = int(ceil(600.0 / hp.army.size()))
		hp.army[i]["type"] = Troops.CAVALRY if i % 4 == 0 else Troops.INFANTRY
	w._pace_cache.clear()

	# 5. Withdrawing: a slower enemy can't ride you down.
	_set_company(12, Troops.CAVALRY, 3)
	w.encounter = hp.id
	var always := true
	for i in 20:
		w.hour += 0.37
		if not w.can_withdraw():
			always = false
	check(always, "you can always withdraw from a lord slower than you")
	_set_company(70, Troops.INFANTRY, 6)
	var ridden := false
	for i in 40:
		w.hour += 0.37
		if not w.can_withdraw():
			ridden = true
	check(ridden, "a quicker, stronger lord sometimes rides a slow column down")
	w.encounter = -1

	# 6. Saved and loaded, a chasing lord is still chasing.
	hunter["job"] = "chase"
	var gs2 = load("res://scripts/game_state.gd").new()
	gs2.persist = false
	gs2.from_dict(JSON.parse_string(JSON.stringify(gs.to_dict())))
	check(String(gs2.world.lord_by_id(int(hunter["id"]))["job"]) == "chase", "a chase survives a save and load")
	gs2.free()

	print("\nPace tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)


func _set_company(men: int, type: String, squads: int = 0) -> void:
	var n: int = squads if squads > 0 else gs.army.size()
	gs.army = gs.army.slice(0, mini(n, gs.army.size()))
	while gs.army.size() < n:
		gs.army.append(gs.army[0].duplicate(true))
		gs.army[-1]["id"] = 900 + gs.army.size()
	for s in gs.army:
		s["men"] = men
		s["type"] = type
		s["unit"] = ""
		s["wounded"] = 0
	w._pace_cache.clear()


## The lord stands at the start of the longest road and you ride away along it with a
## head start; his warband is `lord_men` strong, a quarter of it mounted. True if he
## catches you before you reach the far end, and in `gap` how the distance changed.
func _run_chase(hp, lord_men: int, gap: Array = []) -> bool:
	var per := int(ceil(float(lord_men) / hp.army.size()))
	for i in hp.army.size():
		hp.army[i]["men"] = per
		hp.army[i]["type"] = Troops.CAVALRY if i % 4 == 0 else Troops.INFANTRY
	var l: Dictionary = w.lord_of(hp)
	l["job"] = "patrol"
	l["raiding"] = ""
	hp.grace_until = -1.0
	w.encounter = -1
	for b in w.bands():
		b.grace_until = 1.0e9
	for other in w.lord_parties():
		if other != hp:
			other.grace_until = 1.0e9
	var best_a := ""
	var best_b := ""
	var best_len := 0.0
	for a in WorldData.SETTLEMENTS:
		for n: Array in w._adjacent.get(a, []):
			if not bool(n[1]) and w.road_length(a, n[0]) > best_len:
				best_len = w.road_length(a, n[0])
				best_a = a
				best_b = n[0]
	var p = w.player()
	p.node = best_a
	p.next = best_b
	p.along = 70.0
	p.path = []
	p.wait = 0.0
	hp.node = best_a
	hp.next = ""
	hp.path = []
	hp.along = 0.0
	hp.wait = 0.0
	w._pace_cache.clear()
	var start: float = w.party_pos(hp).distance_to(w.party_pos(p))
	while p.moving():
		w.step(0.25)
		if w.encounter == hp.id:
			gap.append(-start)
			return true
		if w.encounter != -1:
			w.party(w.encounter).grace_until = w.hour + 50.0
			w.encounter = -1
	gap.append(w.party_pos(hp).distance_to(w.party_pos(p)) - start)
	return false
