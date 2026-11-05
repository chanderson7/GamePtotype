## Phone screens fit the phone: on the Warband (every tab), a settlement (your fief and
## another), and People (every tab), nothing reaches past the right edge of the screen,
## even for a crowned company with a fief, bonds and captive lords. A row of buttons or a
## line of text that won't wrap stretches the whole page and cuts everything off.
##
## Needs a window, since headless text has no width: run it under xvfb-run, e.g.
##   xvfb-run -a godot --path . --resolution 405x878 -s tests/screen_width_tests.gd
extends SceneTree

var failures := 0
var _over := []


func check(ok: bool, message: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + message)
	if not ok:
		failures += 1


func _overflow(n: Node, w: float) -> void:
	for c in n.get_children():
		_overflow(c, w)
	if n is Control and n.is_visible_in_tree() and n.get_global_rect().end.x > w + 1.0:
		for c in n.get_children():
			if c is Control and c.is_visible_in_tree() and c.get_global_rect().end.x > w + 1.0:
				return
		_over.append("%s %s (%.0f wide)" % [n.get_class(), n.name, n.get_combined_minimum_size().x])


func _fits(label: String) -> void:
	for i in 6:
		await process_frame
	var w: float = root.get_visible_rect().size.x
	_over.clear()
	_overflow(current_scene, w)
	check(_over.is_empty(), "%s fits the screen%s" % [label, "" if _over.is_empty() else ": " + ", ".join(PackedStringArray(_over.slice(0, 3)))])


func _init() -> void:
	await process_frame
	if DisplayServer.get_name() == "headless":
		print("  skip  screen widths need a window (headless text has no width); run under xvfb-run")
		print("FAILURES: 0")
		quit(0)
		return
	var gs = root.get_node("GameState")
	var sc = root.get_node("Scenes")
	gs.persist = false
	gs.new_campaign("vardish")
	gs.renown = 1085
	gs.silver = 4954
	gs.add_realm_relation("vardmark", 40)
	# A crown needs walls: its seat is a castle.
	gs.player_fief = {"settlement_id": "ravensford", "realm": "vardmark", "silver": 0, "food": 20,
		"improvements": {}, "garrison": [], "granted_at": 0.0, "lost": false}
	gs.world.player().node = "ravensford"
	gs.contract = {}
	gs.declare_crown()
	var taken := 0
	for l in gs.world.lords:
		if not l["ruler"] and taken < 2:
			gs.world.capture_lord(int(l["id"]), "player")
			taken += 1
	var caps := []
	for sq in gs.army:
		if sq.get("captain") is Dictionary:
			caps.append(sq["captain"])
	for a in caps:
		for b in caps:
			if a != b:
				a["bonds"][str(b["id"])] = 37.0
	check(gs.is_crowned() and gs.has_fief() and gs.captive_lords().size() == 2 and not gs.bonds().is_empty(),
		"a crowned company with a fief, bonds and captive lords")

	for tab in ["camp", "companies", "deeds"]:
		sc.warband_tab = tab
		change_scene_to_file("res://scenes/main_menu.tscn")
		await _fits("the Warband's %s tab" % tab)
	change_scene_to_file("res://scenes/settlement.tscn")
	await _fits("your fief")
	# The same page with everything built, a squad left in the garrison and the store full.
	gs.player_fief["improvements"] = {"granary": true, "fortifications": true, "mill": true}
	gs.player_fief["silver"] = 1500
	gs.station_squad_in_fief(int(gs.army[gs.army.size() - 1]["id"]))
	change_scene_to_file("res://scenes/settlement.tscn")
	await _fits("your fief, built up and garrisoned")
	current_scene._show_station_sheet()
	await _fits("the station sheet")
	gs.world.player().node = "highcliff"
	change_scene_to_file("res://scenes/settlement.tscn")
	await _fits("another settlement")
	for tab in ["people", "pacts", "letters"]:
		sc.people_tab = tab
		change_scene_to_file("res://scenes/people.tscn")
		await _fits("People's %s tab" % tab)

	print("FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)
