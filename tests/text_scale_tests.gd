## Big text never pushes a screen wider than the phone. At the Settings text sizes 1.25
## and 1.5, every screen the company commonly sees (the warband's tabs, the map and its
## sheets, the town and the hall, the crown and the war council, a captain, a battle and
## its result) is opened in a phone-shaped window, and nothing may end past its right edge.
extends SceneTree

const WorldData = preload("res://scripts/world/world_data.gd")
const CrownCourt = preload("res://scripts/world/crown_court.gd")
const Lords = preload("res://scripts/data/lords.gd")

var failures := 0
var gs
var scale := 1.0


func check(ok: bool, message: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + message)
	if not ok:
		failures += 1


func _arrive(path: String) -> void:
	for i in 240:
		await process_frame
		if current_scene != null and current_scene.scene_file_path.ends_with(path) and current_scene.is_node_ready():
			break
	for i in 12:
		await process_frame


## Nothing visible on `tag`'s screen ends past the right edge; names the worst offenders.
func _audit(tag: String, scope: Node = null) -> void:
	if scope == null:
		scope = current_scene
	var vpw := root.get_visible_rect().size.x
	var hits := []
	for c in scope.find_children("*", "Control", true, false):
		var ctl := c as Control
		if not ctl.is_visible_in_tree() or ctl is ScrollBar:
			continue
		if ctl.get_global_rect().end.x <= vpw + 2.0:
			continue
		var child_over := false
		for k in ctl.get_children():
			if k is Control and (k as Control).is_visible_in_tree() and (k as Control).get_global_rect().end.x > vpw + 2.0:
				child_over = true
				break
		if not child_over:
			hits.append("%s \"%s\"" % [ctl.name, String(ctl.get("text")).substr(0, 40) if "text" in ctl else ""])
	check(hits.is_empty(), "%s fits at text %.2fx%s" % [tag, scale, "" if hits.is_empty() else ": " + ", ".join(hits.slice(0, 4))])
	# Wrapping words given no room break after every letter, a column of single characters:
	# a wrapping label or button narrower than a short word is squeezed by its row.
	var squeezed := []
	for c in scope.find_children("*", "Control", true, false):
		var ctl := c as Control
		if not ctl.is_visible_in_tree() or not (ctl is Label or ctl is Button):
			continue
		var words: String = String(ctl.get("text")).strip_edges()
		var wrap_mode: int = int(ctl.get("autowrap_mode"))
		if wrap_mode == TextServer.AUTOWRAP_OFF or words.length() < 4:
			continue
		if ctl.size.x < 48.0:
			squeezed.append("%s \"%s\" (%dpx)" % [ctl.name, words.substr(0, 24), int(ctl.size.x)])
	check(squeezed.is_empty(), "%s keeps its words across at text %.2fx%s" % [tag, scale, "" if squeezed.is_empty() else ": " + ", ".join(squeezed.slice(0, 4))])


func _frames(n := 8) -> void:
	for i in n:
		await process_frame

func _place(l: Dictionary, id: String) -> void:
	var p = gs.world.party(int(l["party"]))
	p.node = id; p.next = ""; p.path = []; p.wait = 0.0
	for s in p.army:
		s["men"] = maxi(int(s["men"]), 30)
	l["full"] = gs.world.men_of(p.army); l["raiding"] = ""; l["job"] = ""; l["state"] = "field"

func _swear(realm: String, bearing: String) -> Dictionary:
	for l in gs.world.lords:
		if l["realm"] == realm and not l["ruler"] and int(l.get("party", -1)) >= 0:
			l["realm"] = WorldData.CROWN; l["sworn_from"] = realm; l["fief"] = ""; l["bearing"] = bearing
			l.erase("order")
			gs.world.party(int(l["party"])).faction = WorldData.CROWN
			return l
	return {}


func _init() -> void:
	DisplayServer.window_set_size(Vector2i(720, 1560))
	root.size = Vector2i(720, 1560)
	await process_frame
	gs = root.get_node("GameState")
	var sound = root.get_node("Sound")
	var scenes = root.get_node("Scenes")
	gs.persist = false
	for s in [1.5, 1.25]:
		scale = s
		sound.text_scale = s
		await _company(scenes)
		await _crown(scenes)
	sound.text_scale = 1.0
	print("\nText scale tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)


func _company(scenes) -> void:
	gs.new_campaign(preload("res://scripts/data/cultures.gd").VARDISH)
	var w = gs.world
	gs.contract = {"realm": "vardmark", "daily_pay": 10, "days_left": 30, "bonus_per_lord": 100}
	var here: String = w.here()
	for i in 2:
		if not gs.jobs_at(here).is_empty():
			gs.accept_job(here, 0)
	# Warband, every tab
	change_scene_to_file("res://scenes/main_menu.tscn")
	await _arrive("main_menu.tscn")
	for t in ["camp", "companies", "bonds", "deeds"]:
		current_scene._on_tab(t)
		for i in 6: await process_frame
		_audit("warband/" + t)
	# Tabs grow with the text where their words fit, and wrap rather than trim.
	var biggest := 0
	var trimmed := 0
	for b in current_scene.find_children("Tab_*", "Button", true, false):
		biggest = maxi(biggest, (b as Button).get_theme_font_size("font_size"))
		if (b as Button).text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING or (b as Button).size.y < 80.0:
			trimmed += 1
	check(biggest > roundi(22 * 1.15) and trimmed == 0, "warband tabs take the bigger text at %.2fx and never trim it" % scale)
	# Map: here sheet
	change_scene_to_file("res://scenes/world_map.tscn")
	await _arrive("world_map.tscn")
	_audit("map/here")
	# Map: encounter with a hostile lord
	for lp in w.lord_parties():
		if lp.faction == "kharzan":
			w.encounter = lp.id
			break
	current_scene._open_encounter()
	for i in 6: await process_frame
	_audit("map/encounter")
	w.encounter = -1
	current_scene._open_preview("highcliff")
	for i in 6: await process_frame
	_audit("map/preview")
	# Settlement tabs
	scenes.settlement_arrival_pending = false
	change_scene_to_file("res://scenes/settlement.tscn")
	await _arrive("settlement.tscn")
	_audit("settlement/first")
	for t in ["market", "barracks", "court", "fief", "hall", "contracts"]:
		if current_scene.has_method("_on_tab"):
			current_scene._on_tab(t)
			for i in 6: await process_frame
			_audit("settlement/" + t)
	for sc in ["settings", "people", "saves", "title", "new_campaign", "tutorial"]:
		change_scene_to_file("res://scenes/%s.tscn" % sc)
		await _arrive("%s.tscn" % sc)
		# The title's one-time opening raises a large copy of the wordmark; let it finish.
		for i in 400:
			if current_scene == null or current_scene.get_node_or_null("Opening") == null:
				break
			await process_frame
		_audit(sc)


func _crown(scenes) -> void:
	gs.new_campaign(preload("res://scripts/data/cultures.gd").VARDISH)
	var w = gs.world
	gs.renown = 250
	gs.silver = 3000
	gs.food = 900
	gs.player_fief = {"settlement_id": "ravensford", "realm": w.owner_of("ravensford"), "silver": 0, "food": 20, "improvements": {}, "garrison": [], "granted_at": 0.0, "lost": false}
	var p = w.player(); p.node = "ravensford"; p.next = ""; p.path = []
	gs.declare_crown()
	var lords := [_swear("vardmark", Lords.DARING), _swear("vardmark", Lords.CRUEL), _swear("ryumon", Lords.HONORABLE), _swear("kharzan", Lords.CAUTIOUS)]
	for l in lords:
		if not l.is_empty():
			_place(l, "ravensford")
	w.realms[WorldData.CROWN]["treasury"] = 2000
	w.army_ready_at.erase(WorldData.CROWN)
	if not w.at_war(WorldData.CROWN, "kharzan"):
		w.declare_war(WorldData.CROWN, "kharzan", true)
	CrownCourt.call_banners(gs, "ravensford")
	change_scene_to_file("res://scenes/main_menu.tscn")
	await _frames(10)
	var K = load("res://scripts/world/kingdom_screen.gd")
	var k = K.open(root, gs, "realm")
	await _frames()
	for t in ["realm", "holdings", "lords", "court", "diplomacy"]:
		k._on_tab(t)
		await _frames()
		_audit("crown/" + t, k)
	for pg in ["gathering", "banners", "council"]:
		k._go(pg)
		await _frames()
		_audit("crown/page/" + pg, k)
	var march = k.find_child("March", true, false)
	if march != null and not march.disabled:
		march.pressed.emit()
		await _frames()
		_audit("crown/march sheet", k)
	k.queue_free()
	# Your own gathering, in the hall
	var r: Dictionary = gs.host_gathering("tourney", {"friends": true, "persuade": true, "lieges": true}, "ravensford")
	var g: Dictionary = w.gathering_at("ravensford")
	if not g.is_empty():
		w.hour = float(g["starts_hour"]) + 1.0
		w._step_gatherings()
		for l in w.gathering_guests(g):
			var lp = w.party(int(l["party"]))
			lp.node = "ravensford"; lp.next = ""; lp.path = []
			w._lord_arrives(l, lp)
	scenes.settlement_arrival_pending = false
	change_scene_to_file("res://scenes/settlement.tscn")
	await _frames(20)
	current_scene._on_tab("court")
	await _frames()
	_audit("hall/court (own gathering)")
	# Captain profile
	var cap = gs.army[0].get("captain")
	if cap != null:
		scenes.active_captain_id = int(cap["id"])
		change_scene_to_file("res://scenes/captain_profile.tscn")
		await _frames(20)
		_audit("captain profile")
	# Map sheets
	change_scene_to_file("res://scenes/world_map.tscn")
	await _frames(30)
	var m = current_scene
	m._open_journal(); await _frames(); _audit("map/journal")
	m._open_wars(); await _frames(); _audit("map/wars")
	m._open_chronicle(); await _frames(); _audit("map/chronicle")
	for b in w.bands():
		m._open_band(b); await _frames(); _audit("map/band"); break
	for lp in w.lord_parties():
		m._open_lord(lp); await _frames(); _audit("map/lord"); break
	# Battle and its result
	gs.pending_battle = {"enemy": gs.enemy_army(), "culture": "kharzani", "name": "Test", "objective": "rout"}
	change_scene_to_file("res://scenes/battle.tscn")
	await _frames(40)
	_audit("battle/deploy")
	var sc = current_scene
	var squads := {}
	for sq in gs.army:
		squads[int(sq["id"])] = {"men": int(sq["men"]) - 2, "kills": 5, "captain": {"fate": "wounded", "kills": 1, "roll": 30, "needed": 20}}
	sc._rebuild_result(gs.battle_report({"won": true, "reason": "rout", "lost": 5, "killed": 30, "bonds": {}, "squads": squads}), "Their army broke and fled.")
	sc.result_panel.visible = true
	await _frames()
	_audit("battle/result")
	change_scene_to_file("res://scenes/main_menu.tscn")
	await _frames(5)
