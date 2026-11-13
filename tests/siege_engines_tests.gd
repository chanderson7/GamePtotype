## Siege engines (scripts/battle/siege_works.gd) and laying siege (scripts/world/siege_camp.gd):
## the ram is built, engines need crews and burn, stones bring the wall down into rubble, the
## tower lays its bridge, the walls answer with bolts, oil, fire and sallies; on campaign a
## camp builds, bombards and starves, armies build by their size, works defend, damage stays
## and mends, and auto-resolve counts all of it.
extends SceneTree

const Sim = preload("res://scripts/battle/battle_sim.gd")
const Commander = preload("res://scripts/battle/commander_ai.gd")
const Troops = preload("res://scripts/data/troops.gd")
const Terrain = preload("res://scripts/battle/terrain.gd")
const Cultures = preload("res://scripts/data/cultures.gd")
const WorldData = preload("res://scripts/world/world_data.gd")
const SiegeWorks = preload("res://scripts/battle/siege_works.gd")
const SiegeCamp = preload("res://scripts/world/siege_camp.gd")
const Fiefs = preload("res://scripts/data/fiefs.gd")
const SiegeArt = preload("res://scripts/art/siege_art.gd")

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


func _sim(att: Array, defn: Array, kit: Array, works: Array, land: String = "vardish", seed: int = 3) -> Sim:
	var sim := Sim.new()
	sim.siege_engines = {"attacker": kit, "defender": works, "attacker_land": land, "defender_land": land}
	sim.setup(_army(att, 1), _army(defn, 100), seed, null, Sim.OBJECTIVE_SIEGE)
	return sim


## Every man of `sq` stands at `p`, close together.
func _put(sim, sq, p: Vector2) -> void:
	var i := 0
	for so in sq.soldiers:
		if so.alive:
			so.pos = p + Vector2(float(i % 5) * 9.0 - 18.0, float(i / 5) * 9.0)
			i += 1
	sq.center = p
	sq.refresh()


func _engine(sim, kind: String):
	for e in sim.works.engines:
		if e.kind == kind:
			return e
	return null


func _init() -> void:
	await process_frame
	_check_default()
	_check_ram()
	_check_crews_and_fire()
	_check_walls()
	_check_tower()
	_check_wall_engines()
	_check_lands()
	_check_end_rule()
	_check_art()
	await _check_camp()
	_check_armies_and_works()
	print("Siege engine tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)


# ---------------------------------------------------------------- the field

func _check_default() -> void:
	var sim := Sim.new()
	sim.setup(_army(["infantry", "archers"], 1), _army(["infantry", "archers"], 100), 1, null, Sim.OBJECTIVE_SIEGE)
	check(sim.works != null and sim.works.has("ram") and sim.works.engines.size() == 1 and sim.works.ladder_cols == [4, 23],
		"a siege nobody prepared for is what it always was: a ram and two ladders against bare walls")
	sim.dispose()
	var four := _sim(["infantry"], ["infantry"], ["ram", "ladders", "more_ladders"], [])
	check(four.ladder_points().size() == 4 and four.ladder_held.size() == 4 and four.terrain.passable(Vector2(8 * 30 + 15, four.wall_y)),
		"more ladders: four against the wall")
	four.dispose()


func _check_ram() -> void:
	var dealt := []
	for kit in [["ram", "ladders"], ["ladders"]]:
		var sim := _sim(["infantry"], ["archers"], kit, [])
		sim.start_battle()
		var sq = sim.squads.filter(func(q): return q.team == Sim.PLAYER)[0]
		_put(sim, sq, sim.gate_center + Vector2(0, 30))
		sim.order_hold(sq)
		var before: float = sim.gate_hp
		for i in 300:
			_put(sim, sq, sim.gate_center + Vector2(0, 30))
			sim.step()
		dealt.append(before - sim.gate_hp)
		sim.dispose()
	check(dealt[0] > 0.0 and absf(dealt[1] / dealt[0] - SiegeWorks.GATE_NO_RAM) < 0.08,
		"without a ram the gate takes about a third of the blows (%.0f with, %.0f without)" % [dealt[0], dealt[1]])


func _check_crews_and_fire() -> void:
	var sim := _sim(["infantry", "infantry", "spearmen", "cavalry"], ["infantry"], ["ram", "ladders", "thrower"], [])
	var t = _engine(sim, "thrower")
	sim.start_battle()
	var crew = null
	for sq in sim.squads:
		if sq.crew_of == t:
			crew = sq
	check(crew != null and crew.type == Troops.CAVALRY, "the horse crew the stone thrower (they can't climb)")
	# Away from it, it stands idle.
	_put(sim, crew, Vector2(100, 1200))
	sim.order_hold(crew)
	for i in 300:
		sim.step()
	check(sim.works.stones[Sim.PLAYER] == 0 and not t.crewed(), "an engine nobody stands at does nothing")
	_put(sim, crew, sim.works.crew_post(t))
	for i in 600:
		_put(sim, crew, sim.works.crew_post(t))
		sim.step()
	check(sim.works.stones[Sim.PLAYER] > 0 and t.crewed(), "a company standing at it works it (%d stones)" % sim.works.stones[Sim.PLAYER])
	var hp: float = t.hp
	sim.works.ignite(t)
	for i in 90:
		_put(sim, crew, sim.works.crew_post(t))
		sim.step()
	check(t.hp < hp - 15.0 and t.burning > 0.0, "set alight, it burns")
	check(t.burning < SiegeWorks.BURN_TIME - 3.0 * 1.5, "and a crew at it fights the fire (it goes out twice as fast)")
	t.hp = 5.0
	sim.works.ignite(t)
	for i in 60:
		sim.step()
	check(t.burnt and not t.working() and sim.works.burned[Sim.PLAYER] == 1, "burned out, it's done for")
	sim.dispose()


func _check_walls() -> void:
	var sim := _sim(["infantry", "cavalry"], ["infantry"], ["ram", "ladders", "thrower"], [])
	var t = _engine(sim, "thrower")
	sim.start_battle()
	var crew = sim.squads.filter(func(q): return q.crew_of == t)[0]
	var target: int = sim.works.section_at(11)
	t.aim = {"kind": "section", "ref": target}
	var cols: Array = sim.works.sections[target]["cols"]
	var idx: int = sim.wall_row * Terrain.COLS + int(cols[0])
	check(sim._foot[idx] == 0.0 and not sim.terrain.passable(Vector2(float(cols[0]) * 30.0 + 15.0, sim.wall_y)), "a section of wall stands")
	var limit := 0
	while not sim.works.sections[target]["broken"] and limit < 30 * 400:
		_put(sim, crew, sim.works.crew_post(t))
		sim.step()
		limit += 1
	check(sim.works.sections[target]["broken"], "stones bring it down (in %.0f s)" % (limit / 30.0))
	check(is_equal_approx(sim._foot[idx], SiegeWorks.RUBBLE_PACE) and sim._horse[idx] == 0.0 and sim.on_ladder(Vector2(float(cols[0]) * 30.0 + 15.0, sim.wall_y)),
		"into rubble men on foot can climb (horses can't)")
	check(sim.breaches_at.size() == 1 and sim.works.any_breach(), "and the breach is counted")
	var posts: Array = sim.breach_posts(3, sim.works.section_center(target))
	check(posts.size() == 3 and posts[0].distance_to(sim.works.section_center(target)) > 100.0, "the garrison can meet it in a crescent, as at the gate")
	var state: Dictionary = sim.works.result()["cols"]
	check(state.has(str(cols[0])) and float(state[str(cols[0])]) == 0.0, "and the campaign hears which stretch is down")
	sim.dispose()


func _check_tower() -> void:
	var sim := _sim(["infantry", "infantry", "spearmen"], ["archers"], ["ram", "ladders", "tower"], [])
	var tw = _engine(sim, "tower")
	sim.start_battle()
	var crew = sim.squads.filter(func(q): return q.crew_of == tw)[0]
	check(crew.use_tower and crew.type == Troops.INFANTRY, "the tower takes the shield men nearest it")
	check(not tw.moving, "it waits for the storm")
	sim.order_storm(Sim.PLAYER)
	var limit := 0
	while not tw.docked and limit < 30 * 120 and tw.working():
		sim.step()
		limit += 1
	check(tw.docked, "pushed by its company, it reaches the wall (%.0f s)" % (limit / 30.0))
	var bridge: Array = tw.get_meta("bridge")
	var idx: int = sim.wall_row * Terrain.COLS + int(bridge[0])
	check(is_equal_approx(sim._foot[idx], SiegeWorks.TOWER_CLIMB) and bridge.size() == 2, "and lays a bridge two men wide onto the walk")
	tw.hp = -1.0
	for i in 30:
		sim.step()
	check(tw.burnt and sim._foot[idx] == 0.0, "when it falls, the wall there is whole again")
	sim.dispose()


func _check_wall_engines() -> void:
	# Bolts go through a man into the one behind.
	var sim := _sim(["infantry"], ["archers"], ["ram", "ladders"], ["bolt", "bolt", "oil", "postern"])
	sim.start_battle()
	var b = _engine(sim, "bolt")
	var foot = sim.squads.filter(func(q): return q.team == Sim.PLAYER)[0]
	var a = foot.soldiers[0]
	var c = foot.soldiers[1]
	a.pos = b.pos + Vector2(0, 200)
	c.pos = a.pos + Vector2(0, 12)
	var ha: float = a.hp
	var hc: float = c.hp
	sim._build_grid()
	sim.works._bolt_lands({"kind": "bolt", "team": Sim.ENEMY, "from": b.pos, "to": a.pos, "target": a, "source": b})
	check(a.hp < ha and c.hp < hc and ha - a.hp > hc - c.hp, "a bolt hits a man and goes on into the man behind")
	sim.dispose()
	# Oil on everyone at the gate, the ram set alight, while foot hold the gate tower.
	sim = _sim(["infantry"], ["infantry"], ["ram", "ladders"], ["oil"])
	sim.start_battle()
	var att = sim.squads.filter(func(q): return q.team == Sim.PLAYER)[0]
	var tower = sim.squads.filter(func(q): return q.team == Sim.ENEMY)[0]
	var hp_before := 0.0
	for so in att.soldiers:
		hp_before += so.hp
	for i in 30 * 22:
		_put(sim, att, sim.gate_center + Vector2(0, 26))
		_put(sim, tower, Vector2(sim.gate_center.x, sim.wall_y - Sim.WALK_DEPTH))
		sim.order_hold(att)
		sim.order_hold(tower)
		sim.step()
	check(sim.works.pours >= 1 and sim.works.ram().burning > 0.0, "oil pours on the men at the gate and sets the ram alight")
	sim.dispose()
	# Bows set an engine alight.
	sim = _sim(["infantry", "cavalry"], ["archers"], ["ram", "ladders", "tower"], [])
	sim.start_battle()
	var tw = _engine(sim, "tower")
	var bows = sim.squads.filter(func(q): return q.team == Sim.ENEMY and q.ranged)[0]
	_put(sim, bows, tw.pos + Vector2(0, -150))
	sim.order_hold(bows)
	sim.order_burn(bows, tw)
	var lit := false
	for i in 30 * 10:
		_put(sim, bows, tw.pos + Vector2(0, -150))
		sim.step()
		lit = lit or tw.burning > 0.0
	check(lit and bows.burn_target == tw, "bows told to burn an engine shoot fire at it until it catches")
	sim.dispose()
	# A sally by the postern at a stone thrower, and back.
	sim = _sim(["infantry", "cavalry"], ["infantry", "spearmen"], ["ram", "ladders", "thrower"], ["postern"])
	sim.start_battle()
	var thr = _engine(sim, "thrower")
	for sq in sim.squads:
		if sq.team == Sim.PLAYER:
			_put(sim, sq, Vector2(80, 1200))
			sim.order_hold(sq)
	var sally = sim.squads.filter(func(q): return q.team == Sim.ENEMY)[0]
	check(sim.order_sally(sally, thr), "a garrison company can be sent out by the postern at an engine")
	var went_out := false
	var came_back := false
	for i in 30 * 160:
		sim.step()
		went_out = went_out or not sim.inside_walls(sally.center)
		if went_out and sally.sally_phase == "" and sim.inside_walls(sally.center):
			came_back = true
			break
	check(went_out and (thr.burnt or thr.hp < thr.hp_max), "it goes out through the little door and hacks at the engine")
	check(came_back, "and comes back in by it")
	sim.dispose()
	# Mantlets cover bows standing behind them.
	sim = _sim(["archers", "infantry"], ["archers"], ["ram", "ladders", "mantlets"], [])
	sim.start_battle()
	var m = _engine(sim, "mantlets")
	var my_bows = m.owner
	my_bows.still = 2.0
	check(m != null and is_equal_approx(sim.works.arrow_cover(my_bows.soldiers[0]), SiegeWorks.MANTLET_COVER),
		"mantlets: half the arrows stop in them")
	sim.dispose()


func _check_lands() -> void:
	var v := _sim(["infantry"], ["infantry"], ["ladders", "thrower"], [], "vardish")
	var r := _sim(["infantry"], ["infantry"], ["ladders", "thrower", "mantlets"], [], "ryumon")
	var k := _sim(["infantry"], ["infantry"], ["ladders", "thrower"], [], "kharzani")
	check(v.works.engine_name(_engine(v, "thrower")) == "trebuchet" and k.works.engine_name(_engine(k, "thrower")) == "mangonel",
		"each land builds its own: a Vardish trebuchet, a Kharzani mangonel")
	check(float(v.works.land_of(Sim.PLAYER)["wall"]) > float(r.works.land_of(Sim.PLAYER)["wall"]), "the trebuchet breaks walls best, Ryumon's light thrower least")
	check(r.works.walk_arrows() == SiegeWorks.YAGURA_ARROWS and r.works.thrown_down() == Sim.THROWN_DOWN * 2.0 and r.works.stand_off_share() < 0.85,
		"Ryumon walls have yagura and logs; its bows stand nearer behind bamboo")
	k.start_battle()
	k._build_grid()
	k.works._stone_lands({"to": Vector2(100, 900), "team": Sim.PLAYER, "source": null, "naphtha": true})
	check(k.works.flames.size() == 1, "a Kharzani stone sets the ground burning")
	for s in [v, r, k]:
		s.dispose()


func _check_end_rule() -> void:
	var sim := _sim(["infantry"], ["infantry"], ["ram", "ladders"], [])
	sim.start_battle()
	sim.works._break_section(2)
	sim.time = Sim.TIME_LIMIT + 1.0
	sim._check_end()
	check(sim.end_reason != "walls_held", "a wall broken anywhere isn't a wall that held")
	sim.dispose()


func _check_art() -> void:
	var all_there := true
	for land in ["vardish", "kharzani", "ryumon"]:
		for kind in ["thrower", "tower", "ram", "mantlet", "bolt"]:
			all_there = all_there and SiegeArt.has("%s/%s" % [land, kind]) and SiegeArt.texture("%s/%s" % [land, kind]) != null
	check(all_there, "every land's engines have their pixel art")
	check(SiegeArt.frames("vardish/thrower") == 3 and SiegeArt.frames("vardish/tower") == 3 and SiegeArt.frames("vardish/ram") == 2,
		"a thrower winds, swings and throws; a tower rolls and docks; a ram swings")
	var lit := SiegeArt.texture("vardish/tower").get_image()
	var charred := SiegeArt.texture("vardish/tower", 0, true).get_image()
	var p := Vector2i(16, 40)
	check(charred.get_pixel(p.x, p.y).get_luminance() < lit.get_pixel(p.x, p.y).get_luminance() and charred.get_size() == lit.get_size(),
		"what has burned is drawn charred")
	check(SiegeArt.texture("vardish/thrower", 0, false, true).get_image().get_pixel(16, 24) == Color(0, 0, 0, 1), "and every engine casts a shadow")


# ---------------------------------------------------------------- the campaign

func _check_camp() -> void:
	check(SiegeCamp.build_hours("ram", "vardish", 120) < SiegeCamp.build_hours("ram", "vardish", 60) \
		and SiegeCamp.build_hours("ram", "vardish", 10) == float(SiegeCamp.cost("ram", "vardish")["hours"]) * SiegeCamp.BUILD_SLOWEST,
		"more men build faster, within limits")
	check(int(SiegeCamp.cost("thrower", "ryumon")["silver"]) < int(SiegeCamp.cost("thrower", "vardish")["silver"]), "Ryumon's thrower is cheaper")
	var gs = root.get_node("GameState")
	gs.persist = false
	gs.new_campaign(Cultures.VARDISH)
	var w = gs.world
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
	if target == "":
		check(false, "a castle at war to besiege")
		return
	gs.contract = {"realm": employer, "daily_pay": 50, "days_left": 30, "bonus_per_lord": 100}
	var p = w.player()
	p.node = target
	p.next = ""
	p.path = []
	# Nobody else at those walls: no lord riding out to meet you while the clock runs.
	for other in w.parties:
		if other != p and other.node == target:
			other.node = w.capital_of(employer)
			other.next = ""
			other.path = []
	w.encounter = -1
	check(gs.siege_kit(target) == ["ladders"], "off the march, you storm with two ladders")
	gs.start_siege_battle(target)
	var cfg: Dictionary = gs.pending_battle.get("siege_engines", {})
	check(cfg.get("attacker", []) == ["ladders"] and (cfg.get("defender", []) as Array).has("oil") and (cfg.get("defender", []) as Array).has("bolt"),
		"and the castle meets you with bolt throwers and oil")
	check(gs.lay_siege(target)["ok"] and gs.siege_camp_at(target), "you can lay siege")
	gs.silver = 1000
	var r: Dictionary = gs.siege_build("ram")
	check(r["ok"] and gs.silver == 1000 - 60 and String(gs.siege_camp["building"]) == "ram", "building a ram costs its silver and takes its hours")
	check(not gs.siege_build("tower")["ok"], "one thing at a time")
	_pass(gs, float(r["hours"]) + 1.0)
	check(gs.siege_camp_at(target) and (gs.siege_camp["built"] as Array).has("ram"), "and then it's built")
	check(gs.siege_kit(target).has("ram") and gs.siege_walls(target) < SiegeCamp.walls("castle", SiegeCamp.defences(w, target), ["ladders"]),
		"with a ram the walls count for less")
	# Throwers knock at the walls each day.
	gs.siege_camp["built"].append("thrower")
	_pass(gs, 48.0)
	if gs.siege_camp_at(target):
		check(SiegeCamp.weakest_wall(w, target) < 1.0, "a thrower in the camp knocks at the walls each day (a stretch at %d%%)" % int(SiegeCamp.weakest_wall(w, target) * 100.0))
	# Saved and loaded.
	var saved: Dictionary = gs.to_dict()
	check(saved.has("siege_camp") and (saved["siege_camp"]["built"] as Array).has("ram") and saved["world"].has("siege_damage"),
		"the camp and the walls' damage are saved")
	# Riding off strikes the camp.
	p.node = w.capital_of(employer)
	_pass(gs, 1.0)
	check(not gs.siege_camp_at(target), "riding away from the walls strikes the camp")
	# Starved, the garrison yields.
	p.node = target
	gs.lay_siege(target)
	gs.siege_camp["food_until"] = w.hour + 0.5
	_pass(gs, 1.0)
	check(w.owner_of(target) == employer and gs.siege_camp.is_empty(), "starved, the garrison opens the gate")
	# Damage stays, and mends.
	SiegeCamp.set_damage(w, target, 0.0, {"11": 0.0, "12": 0.0})
	check(SiegeCamp.breached(w, target), "a broken gate and wall are remembered")
	SiegeCamp.mend(w, 24.0 * 5.0, [])
	check(not SiegeCamp.breached(w, target) and SiegeCamp.damage(w, target).is_empty(), "and mend in a few days")


## Let `hours` pass at the walls, as waiting on the map does.
func _pass(gs, hours: float) -> void:
	var until: float = gs.world.hour + hours
	var guard := 0
	while gs.world.hour < until - 0.001 and guard < 2000:
		guard += 1
		var step := minf(1.0, until - gs.world.hour)
		gs.world.encounter = -1
		gs.world.wait(step)
		gs.advance(step)


func _check_armies_and_works() -> void:
	check(SiegeCamp.army_kit(100, "castle") == ["ladders", "ram"] and SiegeCamp.army_kit(260, "castle").count("thrower") == 2 \
		and SiegeCamp.army_kit(260, "castle").has("tower"), "a lord's army builds by its size: a ram always, throwers and a tower when big")
	check(SiegeCamp.army_prep_hours(["ladders", "ram"], "vardish", 300) >= 48.0, "and never storms before two days")
	var gs = root.get_node("GameState")
	var w = gs.world
	var cap: String = w.capital_of("vardmark")
	var castle := ""
	var town := ""
	for id in WorldData.SETTLEMENTS:
		var kind := String(WorldData.settlement(id)["type"])
		if kind == WorldData.CASTLE and castle == "" and id != cap:
			castle = id
		elif kind == WorldData.TOWN and town == "" and id != cap:
			town = id
	check(SiegeCamp.defences(w, castle).has("oil") and not SiegeCamp.defences(w, town).has("oil"), "castles keep oil over the gate; towns don't")
	check(SiegeCamp.defences(w, cap).has("yard_thrower"), "a capital has a stone thrower in its courtyard")
	var bought := SiegeCamp.defences(w, town, {Fiefs.IMPROVEMENT_SIEGE_WORKS: true, Fiefs.IMPROVEMENT_TOWER_BOLTS: true})
	check(bought.has("oil") and bought.has("yard_thrower") and bought.count("bolt") == 3, "a town you hold can buy siege works and tower bolts")
	check(Fiefs.improvements_for(WorldData.VILLAGE).has(Fiefs.IMPROVEMENT_FORTIFICATIONS) and not Fiefs.improvements_for(WorldData.VILLAGE).has(Fiefs.IMPROVEMENT_SIEGE_WORKS) \
		and Fiefs.improvements_for(WorldData.CASTLE).has(Fiefs.IMPROVEMENT_SIEGE_WORKS), "villages build palisades; walls build siege works")
	var bare := SiegeCamp.walls("castle", [], ["ram"])
	check(is_equal_approx(bare, 1.6), "auto-resolve: bare castle walls against a ram count as they always did")
	check(SiegeCamp.walls("castle", [], ["ladders"]) > bare and SiegeCamp.walls("castle", [], ["ram", "thrower", "thrower", "tower"]) < bare - 0.3,
		"no ram counts for the walls; throwers and a tower against them")
	check(SiegeCamp.walls("castle", ["bolt", "bolt", "oil", "yard_thrower"], ["ram"]) > bare and SiegeCamp.walls("castle", [], ["ram"], {"gate": 0.0}) < bare,
		"works count for them; a gate already broken against them")
	check(SiegeCamp.walls("castle", ["bolt", "bolt", "bolt", "oil", "yard_thrower"], ["ladders"]) <= SiegeCamp.WALLS_MAX, "within limits")
