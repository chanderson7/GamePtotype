## Playable sieges: walls and a gate on the battlefield, and storming them on campaign.
extends SceneTree

const Sim = preload("res://scripts/battle/battle_sim.gd")
const Commander = preload("res://scripts/battle/commander_ai.gd")
const Troops = preload("res://scripts/data/troops.gd")
const Terrain = preload("res://scripts/battle/terrain.gd")
const Cultures = preload("res://scripts/data/cultures.gd")
const WorldData = preload("res://scripts/world/world_data.gd")
const MarshalArmies = preload("res://scripts/world/marshal_armies.gd")

var gs
var failures := 0


func check(ok: bool, message: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + message)
	if not ok:
		failures += 1


func _army(types: Array, base: int) -> Array:
	var out := []
	for i in types.size():
		out.append({"id": base + i, "type": types[i], "men": Troops.full_size(types[i])})
	return out


## Fight `seeds` AI-vs-AI assaults; [attacker wins, breaches].
func _assaults(att: Array, defn: Array, seeds: int) -> Array:
	var wins := 0
	var breaches := 0
	for s in range(1, seeds + 1):
		var sim := Sim.new()
		sim.setup(_army(att, 1), _army(defn, 100), s, null, Sim.OBJECTIVE_SIEGE)
		sim.ai = [Commander.new(Sim.PLAYER), Commander.new(Sim.ENEMY)]
		sim.start_battle()
		while sim.winner == -1 and sim.time < Sim.TIME_LIMIT + 5.0:
			sim.step()
		if sim.winner == Sim.PLAYER:
			wins += 1
		if sim.gate_hp <= 0.0:
			breaches += 1
		sim.dispose()
	return [wins, breaches]


func _check_battlefield() -> void:
	var sim := Sim.new()
	sim.setup(_army(["infantry", "archers"], 1), _army(["infantry", "spearmen", "archers"], 100), 1, null, Sim.OBJECTIVE_SIEGE)
	var wall_ok := true
	for cx in Terrain.COLS:
		var p := Vector2(cx * 30.0 + 15.0, Sim.WALL_Y)
		var blocked: bool = not sim.terrain.passable(p)
		wall_ok = wall_ok and (blocked != (Sim.GATE_COLS.has(cx) or Sim.LADDER_COLS.has(cx)))
	check(wall_ok, "a wall crosses the field, with the gate and two ladders the only ways over")
	sim.start_battle()
	var behind := true
	var garrison := 0
	for sq in sim.squads:
		if sq.team == Sim.ENEMY:
			garrison += 1
			behind = behind and sq.center.y < Sim.WALL_Y
	check(garrison == 3 and behind, "the whole garrison forms up behind its wall")
	check(not sim.gate_open() and sim.gate_hp == Sim.GATE_HP["castle"], "the gate starts shut at full strength")
	# Nobody walks through a shut gate.
	var so = sim.squads[0].soldiers[0]
	so.pos = Sim.GATE_CENTER + Vector2(0, 40)
	for i in 40:
		sim._walk(so, Sim.GATE_CENTER + Vector2(0, -120), 40.0, 0.1)
	check(so.pos.y > Sim.WALL_Y - 5.0, "no one walks through the shut gate")
	# Men sent to storm the walls by a ladder climb it while the gate holds; others don't.
	var climber = sim.squads[0].soldiers[1]
	var lp: Vector2 = sim.ladder_points()[0]
	climber.pos = lp + Vector2(0, 50)
	sim.squads[0].use_ladders = true
	for i in 120:
		sim._walk(climber, lp + Vector2(0, -120), 40.0, 0.1)
	check(climber.pos.y < Sim.WALL_Y - 15.0, "men sent up a ladder climb over the wall while the gate holds")
	sim.squads[0].use_ladders = false
	climber.pos = lp + Vector2(0, 50)
	for i in 120:
		sim._walk(climber, lp + Vector2(0, -120), 40.0, 0.1)
	check(climber.pos.y > Sim.WALL_Y, "and men not sent to the ladders make for the gate")
	var bows_on_wall := true
	for sq in sim.squads:
		if sq.team == Sim.ENEMY and sq.type == Troops.ARCHERS:
			bows_on_wall = bows_on_wall and absf(sq.center.y - Sim.WALL_Y) < 60.0
	check(bows_on_wall, "the garrison's bows stand on the wall walk")
	# The storm plan: shields to a ladder or the ram, bows shoot; a changed plan is obeyed.
	var foot = sim.squads[0]
	var shooters = sim.squads[1]
	var plan := sim.storm_plan(Sim.PLAYER)
	check(plan.size() == 2 and ["ladder", "ram"].has(plan[foot.id]) and plan[shooters.id] == "bows",
		"the storm plan sends the shields to a ladder or the ram and leaves the bows shooting")
	check(sim.can_climb(foot) and not sim.can_climb(shooters), "only men on foot without shooters can be swapped onto a ladder")
	plan[foot.id] = "ladder"
	sim.order_storm(Sim.PLAYER, plan)
	check(foot.use_ladders and not shooters.use_ladders and foot.order == "advance", "storming by a changed plan sends those companies up the ladders")
	plan[foot.id] = "ram"
	sim.order_storm(Sim.PLAYER, plan)
	check(not foot.use_ladders, "and swapping a company back sends it to the ram")
	# The record of the siege: who climbed first, and how many went over.
	for s2 in foot.soldiers:
		s2.pos = Sim.GATE_CENTER + Vector2(0, 160)
	var up = foot.soldiers[2]
	up.pos = lp
	sim._batter_gate(0.001)
	check(sim.siege_role(foot) == "climb", "a company with a man on a ladder reads as climbing")
	up.pos = lp + Vector2(0, -40)
	sim._batter_gate(0.001)
	check(sim.climbed == 1 and sim.siege_log.any(func(e): return e["kind"] == "first_over" and e["squad"] == foot),
		"the first man over the wall is remembered, with his company")
	for s2 in foot.soldiers:
		s2.pos = Sim.GATE_CENTER + Vector2(0, 30)
	check(sim.siege_role(foot) == "ram", "a company at the gate reads as at the ram")
	check(sim.siege_role(shooters) == "bows", "and archers outside the walls as shooting")
	sim.gate_hp = 1.0
	for sq in sim.squads:
		if sq.team == Sim.PLAYER and sq.type == Troops.INFANTRY:
			for s in sq.soldiers:
				s.pos = Sim.GATE_CENTER + Vector2(0, 20)
	sim._batter_gate(1.0)
	check(sim.gate_open() and sim.events.any(func(e): return e["type"] == "gate_breached"), "men on foot at the gate break it")
	sim.dispose()

	var stronger := _assaults(["infantry", "infantry", "spearmen", "archers", "archers", "infantry", "spearmen"],
		["infantry", "infantry", "spearmen", "archers", "archers"], 4)
	check(stronger[0] >= 3 and stronger[1] >= 3, "half again the garrison breaks the gate and takes the walls (%d/4)" % stronger[0])
	var even := _assaults(["infantry", "infantry", "spearmen", "archers", "archers"],
		["infantry", "infantry", "spearmen", "archers", "archers"], 4)
	check(even[0] <= 1, "an even assault fails against the walls (%d/4 won)" % even[0])
	var bows := _assaults(["archers", "archers", "archers"], ["infantry", "archers"], 2)
	check(bows[1] == 0 and bows[0] == 0, "archers alone can't break a gate, and the walls hold")


func _check_campaign() -> void:
	gs = root.get_node("GameState")
	gs.persist = false
	gs.new_campaign(Cultures.VARDISH)
	var w = gs.world
	# A hostile castle, at war with the realm we will serve.
	var target := ""
	var employer := ""
	for id in WorldData.SETTLEMENTS:
		if String(WorldData.settlement(id)["type"]) != WorldData.CASTLE:
			continue
		for realm in ["vardmark", "kharzan", "ryumon"]:
			if realm != w.owner_of(id) and w.at_war(realm, w.owner_of(id)):
				target = id
				employer = realm
				break
		if target != "":
			break
	check(target != "", "there is a castle held by a realm at war")
	if target == "":
		return
	check(not gs.siege_check(target)["ok"] and String(gs.siege_check(target)["reason"]).contains("free company"),
		"a free company can't storm walls")
	gs.contract = {"realm": employer, "daily_pay": 50, "days_left": 30, "bonus_per_lord": 100}
	check(String(gs.siege_check(target)["reason"]).contains("Ride"), "and must ride to them first")
	var p = w.player()
	p.node = target
	p.next = ""
	p.path = []
	check(gs.siege_check(target)["ok"], "under contract, at the walls of an enemy castle, the assault can begin")
	check(not gs.siege_check(w.capital_of(employer))["ok"], "but never on the employer's own walls")

	# A failed assault leaves the garrison weaker and the castle where it was.
	var owner: String = w.owner_of(target)
	var before: int = w.men_of(w.garrisons[target])
	gs.army = gs.army.slice(0, 1)
	gs.army[0]["men"] = 3
	var r: Dictionary = gs.auto_resolve_siege(target)
	check(not r.get("won", true) and w.owner_of(target) == owner and w.men_of(w.garrisons[target]) <= before,
		"a failed assault leaves the walls with their holder")

	# A strong company takes it for its employer.
	gs.new_campaign(Cultures.VARDISH)
	w = gs.world
	gs.contract = {"realm": employer, "daily_pay": 50, "days_left": 30, "bonus_per_lord": 100}
	p = w.player()
	p.node = target
	p.next = ""
	p.path = []
	w.garrisons[target] = w.garrisons[target].slice(0, 1)
	w.garrisons[target][0]["men"] = 4
	var renown_before: int = gs.renown
	r = gs.auto_resolve_siege(target)
	check(r.get("won", false) and w.owner_of(target) == employer, "a won assault hands the castle to the employer")
	check(gs.renown > renown_before and w.activity_log.any(func(e): return e.get("type", "") == "captured"),
		"and earns renown, and the chronicle records it")
	check(not gs.siege_check(target)["ok"], "and it can't be stormed again by the side that now holds it")

	# The battle screen sets up the walls for a led assault.
	gs.new_campaign(Cultures.VARDISH)
	w = gs.world
	gs.contract = {"realm": employer, "daily_pay": 50, "days_left": 30, "bonus_per_lord": 100}
	p = w.player()
	p.node = target
	p.next = ""
	p.path = []
	gs.start_siege_battle(target)
	check(gs.pending_battle.get("objective", "") == "siege" and gs.pending_battle.get("siege_target", "") == target,
		"leading the assault sets up a siege battle")
	change_scene_to_file("res://scenes/battle.tscn")
	await process_frame
	await process_frame
	var screen = current_scene
	check(screen.sim.objective == Sim.OBJECTIVE_SIEGE and screen.sim.gate_hp > 0.0 and not screen.sim.terrain.passable(Vector2(60, Sim.WALL_Y)),
		"the battle opens with the walls up and the gate shut")
	# Fight it out (the computer leading both sides) and bring the result home.
	var bsim = screen.sim
	bsim.ai[Sim.PLAYER] = Commander.new(Sim.PLAYER)
	if bsim.phase == Sim.PHASE_DEPLOY:
		bsim.start_battle()
	while bsim.winner == -1 and bsim.time < Sim.TIME_LIMIT + 5.0:
		bsim.step()
	var res: Dictionary = screen._result()
	var held: String = w.owner_of(target)
	gs.apply_result(res)
	var landed: bool = (w.owner_of(target) == employer) if res["won"] else (w.owner_of(target) == held)
	check(landed and gs.pending_battle.is_empty(), "a led assault's result comes home (%s, %s)" % ["won" if res["won"] else "lost", res["reason"]])


## Fight `seeds` assaults on walls the player holds; how many the player held.
func _defences(defn: Array, att: Array, seeds: int) -> int:
	var held := 0
	for s in range(1, seeds + 1):
		var sim := Sim.new()
		sim.siege_defender = Sim.PLAYER
		sim.setup(_army(defn, 1), _army(att, 100), s, null, Sim.OBJECTIVE_SIEGE)
		sim.ai = [Commander.new(Sim.PLAYER), Commander.new(Sim.ENEMY)]
		sim.start_battle()
		while sim.winner == -1 and sim.time < Sim.TIME_LIMIT + 5.0:
			sim.step()
		if sim.winner == Sim.PLAYER:
			held += 1
		sim.dispose()
	return held


func _check_defence_battlefield() -> void:
	var sim := Sim.new()
	sim.siege_defender = Sim.PLAYER
	sim.setup(_army(["infantry", "archers"], 1), _army(["infantry", "infantry"], 100), 1, null, Sim.OBJECTIVE_SIEGE)
	sim.start_battle()
	var inside := true
	for sq in sim.squads:
		if sq.team == Sim.PLAYER:
			inside = inside and sim.inside_walls(sq.center)
		else:
			inside = inside and not sim.inside_walls(sq.center)
	check(sim.wall_y > Sim.MID_Y and inside, "defending, your men stand behind a wall on your side of the field")
	sim.dispose()
	var five := ["infantry", "infantry", "spearmen", "archers", "archers"]
	check(_defences(five, five, 4) >= 3, "an even assault on walls you hold mostly fails")


## An army of `realm` with two of its lords, besieging `target`.
func _army_at(w, realm: String, target: String) -> Dictionary:
	var members: Array = []
	for l in w.lords:
		var lp = w.party(int(l["party"]))
		if l["realm"] == realm and lp != null and members.size() < 2:
			lp.node = target
			lp.next = ""
			lp.path = []
			members.append(lp.id)
	var army := {"id": 900, "realm": realm, "leader": members[0], "members": members, "state": "besieging",
		"muster": w.capital_of(realm), "target": target, "target_owner": w.owner_of(target), "destination": target,
		"deadline": w.hour, "expires": w.hour + 200.0, "reason": "", "siege_prep_until": w.hour, "siege_food_until": w.hour + 100.0}
	w.campaign_armies.append(army)
	return army


func _check_army_assaults() -> void:
	gs = root.get_node("GameState")
	gs.persist = false
	gs.new_campaign(Cultures.VARDISH)
	var w = gs.world
	# Find an enemy castle and a realm at war with its holder.
	var target := ""
	var realm := ""
	for id in WorldData.SETTLEMENTS:
		if String(WorldData.settlement(id)["type"]) != WorldData.CASTLE:
			continue
		for r in ["vardmark", "kharzan", "ryumon"]:
			if r != w.owner_of(id) and w.at_war(r, w.owner_of(id)):
				target = id
				realm = r
		if target != "":
			break
	var owner: String = w.owner_of(target)

	# Riding with an army: asked to lead its assault.
	var army := _army_at(w, realm, target)
	w.following_party = int(army["leader"])
	MarshalArmies.assault(w, army)
	check(w.pending_assault.get("role", "") == "lead" and not w.busy() and w.owner_of(target) == owner,
		"riding with an army, you're asked to lead its assault, and the clock waits")
	gs.answer_assault(true)
	var allies: Array = gs.pending_battle.get("allies", [])
	check(gs.pending_battle.get("objective", "") == "siege" and not allies.is_empty() and allies.all(func(e): return e["is_ally"])
		and not bool(gs.pending_battle.get("siege_defend", false)), "leading it, the lords' men fight beside you against the garrison")
	var won := {"won": true, "lost": 5, "killed": 40, "squads": {}, "enemy_squads": {}, "objective": "siege"}
	gs.apply_result(won)
	check(w.owner_of(target) == realm and w.pending_assault.is_empty(), "a won assault hands the castle to the army's realm")

	# Declining lets the army settle it as before.
	gs.new_campaign(Cultures.VARDISH)
	w = gs.world
	army = _army_at(w, realm, target)
	w.following_party = int(army["leader"])
	MarshalArmies.assault(w, army)
	gs.answer_assault(false)
	MarshalArmies.assault(w, army)
	check(w.pending_assault.is_empty() and w.activity_log.any(func(e): return e.get("type", "") in ["captured", "siege_repulsed"]),
		"letting them storm it settles the assault without you")

	# Your own fief, stormed while you're there.
	gs.new_campaign(Cultures.VARDISH)
	w = gs.world
	w.set_owner(target, owner)
	gs.player_fief = {"settlement_id": target, "realm": owner, "silver": 0, "food": 20, "improvements": {}, "garrison": [], "granted_at": 0.0, "lost": false}
	var p = w.player()
	p.node = target
	p.next = ""
	p.path = []
	army = _army_at(w, realm, target)
	MarshalArmies.assault(w, army)
	check(w.pending_assault.get("role", "") == "defend", "an army storming your fief while you're there calls you to its walls")
	gs.answer_assault(true)
	check(bool(gs.pending_battle.get("siege_defend", false)) and gs.pending_battle["allies"].all(func(e): return bool(e.get("garrison", false)))
		and not gs.pending_battle["enemy"].is_empty(), "holding them, the garrison fights beside you against the army")
	gs.apply_result(won)
	check(w.owner_of(target) == owner and String(army["state"]) in ["returning", "disbanded"] or not w.campaign_armies.has(army),
		"holding the walls keeps your fief and sends the army home")

	# The battle screen puts your men behind the wall.
	gs.new_campaign(Cultures.VARDISH)
	w = gs.world
	gs.player_fief = {"settlement_id": target, "realm": owner, "silver": 0, "food": 20, "improvements": {}, "garrison": [], "granted_at": 0.0, "lost": false}
	p = w.player()
	p.node = target
	p.next = ""
	p.path = []
	army = _army_at(w, realm, target)
	MarshalArmies.assault(w, army)
	gs.answer_assault(true)
	change_scene_to_file("res://scenes/battle.tscn")
	await process_frame
	await process_frame
	var screen = current_scene
	check(screen.sim.objective == Sim.OBJECTIVE_SIEGE and screen.sim.siege_defender == Sim.PLAYER and screen.sim.wall_y > Sim.MID_Y,
		"the defence opens with your side behind the wall")


func _init() -> void:
	await process_frame
	_check_battlefield()
	_check_defence_battlefield()
	await _check_campaign()
	await _check_army_assaults()
	print("\nSiege tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
