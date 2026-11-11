## Phone screens fit the phone: on the Warband (every tab), a settlement (your fief and
## another), People (every tab, and each person's page at normal and at the largest text)
## and the talk, nothing reaches past the right edge of the screen,
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

	# A person's page, for each of them, at normal and at the largest text: a line that
	# won't wrap (a long house name on a tile) once stretched the page 174 past the screen,
	# and the bottom bar read "Spen" for "Spend time".
	var sound = root.get_node("Sound")
	gs.world.social.apply_choice("edda", "know_better", {"invitations_enabled": true})
	gs.world.player().node = String(gs.world.social.get_candidate_person("edda").get("residence", "ravensford"))
	sc.people_tab = "people"
	for scale in [1.0, 1.5]:
		sound.text_scale = scale
		var at := "" if scale == 1.0 else " at %d%% text" % int(scale * 100.0)
		change_scene_to_file("res://scenes/people.tscn")
		for i in 4:
			await process_frame
		for cand in ["edda", "farid", "kaede"]:
			current_scene._open_person(cand)
			await _fits("%s's page%s" % [cand.capitalize(), at])
			var cut := []
			for b in current_scene.find_child("BottomBar", true, false).find_children("*", "Button", true, false):
				if not _whole(b):
					cut.append("%s (%s)" % [b.name, b.text])
			for b in current_scene.find_child("ProfileTabs", true, false).get_children():
				if not _whole(b):
					cut.append("%s (%s)" % [b.name, b.text])
			check(cut.is_empty(), "and none of its buttons' words are cut short%s%s" % [at, "" if cut.is_empty() else ": " + ", ".join(PackedStringArray(cut))])
			current_scene._go_to_section("memories")
			await _fits("%s's memories%s" % [cand.capitalize(), at])
			current_scene._close_person()
			for i in 2:
				await process_frame
		# The talk itself: the hub, a chapter's lines and its answers.
		sc.active_candidate_id = "edda"
		sc.active_person_id = "person_edda"
		sc.conversation_return = "res://scenes/people.tscn"
		change_scene_to_file("res://scenes/conversation.tscn")
		await _fits("the talk%s" % at)
		var talk = current_scene
		var first_visit: Array = talk.reply_ids().filter(func(id): return String(id).begins_with("visit_"))
		var why := ""
		if first_visit.is_empty() and talk.reply_node("visits_locked") != null:
			why = String(talk.reply_node("visits_locked").find_child("Tag", true, false).text)
		check(not first_visit.is_empty(), "the talk offers a visit to try (%s)" % why)
		if not first_visit.is_empty():
			talk.choose(first_visit[0])
			await _fits("a visit, being told%s" % at)
			for i in 20:
				if talk.reply_node("continue") == null:
					break
				talk.choose("continue")
			await _fits("a visit's answers%s" % at)
			var tray: Control = talk._tray
			check(is_equal_approx(tray.position.y + tray.size.y, talk.size.y) and talk._scroll.size.y >= talk.LOG_MIN - 1.0,
				"the answers sit on the bottom edge and leave the talk room to be read%s (%.0f for the talk)" % [at, talk._scroll.size.y])
			var short: Array = talk._tray.find_children("Reply_*", "Button", true, false).filter(func(b): return (b as Button).size.y < 79.5)
			check(short.is_empty(), "and each is a full touch target%s" % at)
	sound.text_scale = 1.0
	# A wide window (a computer's): the talk keeps to the column the menus use.
	var was := root.size
	root.size = Vector2i(1280, 800)
	change_scene_to_file("res://scenes/conversation.tscn")
	for i in 8:
		await process_frame
	var wide = current_scene
	var view: float = root.get_visible_rect().size.x
	if view > 900.0:
		var log_rect: Rect2 = wide._log.get_global_rect()
		check(log_rect.size.x <= 720.0 and absf(log_rect.get_center().x - view * 0.5) < 2.0,
			"in a wide window the talk reads in a centred column (%.0f wide in %.0f)" % [log_rect.size.x, view])
		var answers: Rect2 = wide._replies.get_global_rect()
		check(answers.size.x <= 720.0 and absf(answers.get_center().x - view * 0.5) < 2.0, "and so do the answers")
		var face: Rect2 = wide.get_node("Stage/Face_left").get_global_rect()
		check(face.position.x >= log_rect.position.x - 30.0, "with her portrait at the head of the column, not in the room's far corner")
	else:
		print("  skip  the window could not be made wide here (%.0f)" % view)
	root.size = was

	print("FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)


## Whether a button shows all of its words: they fit on one line at its size, or wrap.
func _whole(b: Button) -> bool:
	if b.text == "" or b.autowrap_mode != TextServer.AUTOWRAP_OFF:
		return true
	var font := b.get_theme_font("font")
	var room := b.size.x - b.get_theme_stylebox("normal").get_minimum_size().x
	if b.icon != null:
		var cap := b.get_theme_constant("icon_max_width")
		room -= (float(cap) if cap > 0 else float(b.icon.get_width())) + b.get_theme_constant("h_separation")
	return font.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, b.get_theme_font_size("font_size")).x <= room + 1.0
