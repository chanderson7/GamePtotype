## The UI moves the way docs/game-feel-audit.md asks: buttons answer the thumb, sheets
## ease out as they ease in, tabs turn, what changed shows itself, the battle result
## tallies, time passing is seen, the road encounter lands, letters arrive, deeds are
## stamped, talk has a pulse, the dance and the wedding move, and the battle's big
## moments hit. Every motion has a Reduced-motion branch that lands on the end state.
extends SceneTree

var failures := 0
var gs
var sound
var scenes


func check(ok: bool, message: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + message)
	if not ok:
		failures += 1


func _frames(n := 4) -> void:
	for i in n:
		await process_frame


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _arrive(path: String) -> void:
	for i in 240:
		await process_frame
		if current_scene != null and current_scene.scene_file_path.ends_with(path) and current_scene.is_node_ready():
			break
	await _frames(6)


func _init() -> void:
	await process_frame
	gs = root.get_node("GameState")
	sound = root.get_node("Sound")
	scenes = root.get_node("Scenes")
	gs.persist = false
	sound.reduced_motion = false
	gs.new_campaign(preload("res://scripts/data/cultures.gd").VARDISH)
	await _buttons()
	await _sheets()
	await _tabs()
	await _changes()
	await _result()
	await _map_moments()
	await _ribbons()
	print("\nGame feel tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)


# ---- 1. buttons answer the thumb
func _buttons() -> void:
	var host := Control.new()
	host.size = Vector2(720, 400)
	root.add_child(host)
	var b := Button.new()
	b.text = "Hire"
	b.size = Vector2(300, 90)
	host.add_child(b)
	await _frames(2)
	b.button_down.emit()
	await _wait(0.1)
	check(b.scale.x < 0.99 and b.scale.x >= 0.94, "a pressed button sinks under the thumb (%.2f)" % b.scale.x)
	b.button_up.emit()
	await _wait(0.07)
	var mid: float = b.scale.x
	await _wait(0.2)
	check(is_equal_approx(b.scale.x, 1.0) and mid > 0.95, "and springs back when let go (%.3f mid-way)" % mid)
	# A press a scrolling page takes over never sends button_up: it still lets go.
	b.button_down.emit()
	await _wait(0.6)
	check(is_equal_approx(b.scale.x, 1.0), "a press the page takes over doesn't stay sunk")
	# A brass button ticks.
	var p := Button.new()
	p.text = "March"
	host.add_child(p)
	preload("res://scripts/ui/style.gd").make_primary(p)
	var n0: int = sound.haptic_count
	sound.haptics_enabled = true
	p.pressed.emit()
	check(sound.haptic_count == n0 + 1, "a primary button gives a light tick of vibration")
	b.pressed.emit()
	check(sound.haptic_count == n0 + 1, "an ordinary one doesn't")
	# Reduced motion: still, but the tick remains.
	sound.reduced_motion = true
	b.button_down.emit()
	await _wait(0.1)
	check(is_equal_approx(b.scale.x, 1.0), "under Reduced motion a button stays still")
	b.button_up.emit()
	sound.reduced_motion = false
	host.queue_free()
	await _frames(2)


# ---- 2. sheets ease out as they ease in
func _sheets() -> void:
	var Widgets = load("res://scripts/ui/widgets.gd")
	var Style = load("res://scripts/ui/style.gd")
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	await _frames(2)
	var col: VBoxContainer = Widgets.sheet(host, "Test", "TestSheet")
	await _wait(0.3)
	Widgets.close_sheet(col)
	check(host.get_node_or_null("TestSheet") == null, "a closed sheet leaves the page at once")
	var ghost := scenes.get_node_or_null("TestSheet_closing") as Control
	check(ghost != null and ghost.mouse_filter == Control.MOUSE_FILTER_IGNORE, "and fades on the top layer, taking no taps")
	await _wait(0.1)
	check(is_instance_valid(ghost) and (ghost.get_node("SheetPanel") as Control).modulate.a < 0.9, "it fades as it goes")
	await _wait(0.25)
	check(not is_instance_valid(ghost) or ghost.is_queued_for_deletion(), "and is gone in a moment")
	# Reduced motion: gone at once.
	sound.reduced_motion = true
	col = Widgets.sheet(host, "Test", "TestSheet")
	Widgets.close_sheet(col)
	check(scenes.get_node_or_null("TestSheet_closing") == null, "under Reduced motion it's simply gone")
	sound.reduced_motion = false
	host.queue_free()
	# A panel easing out takes no taps, and a fresh ease_in cancels the close.
	var panel := PanelContainer.new()
	panel.size = Vector2(300, 200)
	var inner := Button.new()
	panel.add_child(inner)
	root.add_child(panel)
	await _frames(2)
	var hidden := [false]
	Style.ease_out(panel, func(): hidden[0] = true)
	check(Style.closing(panel) and inner.mouse_filter == Control.MOUSE_FILTER_IGNORE, "a panel easing out is closing, its buttons quiet")
	Style.ease_in(panel)
	await _wait(0.25)
	check(not hidden[0] and not Style.closing(panel) and inner.mouse_filter == Control.MOUSE_FILTER_STOP and is_equal_approx(panel.modulate.a, 1.0),
		"reopened mid-close, it comes back whole")
	panel.queue_free()
	# The map's sheet: closed at once for the game, eased out for the eye.
	change_scene_to_file("res://scenes/world_map.tscn")
	await _arrive("world_map.tscn")
	var m = current_scene
	m._open_journal()
	await _wait(0.3)
	check(m._sheet_open(), "the map's journal is open")
	m._close_sheet()
	check(not m._sheet_open() and m.bottom_bar.visible and m.sheet_panel.visible, "closing it frees the map at once while it fades")
	await _wait(0.3)
	check(not m.sheet_panel.visible and is_equal_approx(m.sheet_panel.modulate.a, 1.0), "then it's hidden, ready to open again")
	m._open_journal()
	m._close_sheet()
	m._open_journal()
	await _wait(0.3)
	check(m._sheet_open() and m.sheet_panel.visible and is_equal_approx(m.sheet_panel.modulate.a, 1.0), "opened again mid-close, it stays open")
	m._close_sheet()
	await _wait(0.3)


# ---- 4. tabs turn, not cut
func _tabs() -> void:
	scenes.settlement_arrival_pending = false
	change_scene_to_file("res://scenes/settlement.tscn")
	await _arrive("settlement.tscn")
	var page = current_scene
	var bar := page.find_child("SettlementTabs", true, false) as Control
	check(bar != null and bar.find_child("TabLine", true, false) != null, "the town's tab bar draws its underline")
	var tabs: Array = []
	for b in bar.find_children("Tab_*", "Button", true, false):
		tabs.append(String(b.name).trim_prefix("Tab_"))
	var first: String = page.tab
	var other: String = tabs[1] if String(tabs[0]) == first else tabs[0]
	# Arriving, the page is simply there.
	var col := bar.get_parent()
	var after := col.get_child(bar.get_index() + 1) as CanvasItem
	check(after != null and is_equal_approx(after.modulate.a, 1.0), "arriving, the page under the tabs is simply there")
	page._on_tab(other)
	await _frames(2)
	bar = page.find_child("SettlementTabs", true, false) as Control
	col = bar.get_parent()
	after = col.get_child(bar.get_index() + 1) as CanvasItem
	check(after != null and after.modulate.a < 0.9, "switching tabs, the page fades up (%.2f)" % (after.modulate.a if after != null else -1.0))
	await _wait(0.4)
	check(is_instance_valid(after) and is_equal_approx(after.modulate.a, 1.0), "and is whole a moment later")
	# Reduced motion: the page is whole at once.
	sound.reduced_motion = true
	page._on_tab(first)
	await _frames(2)
	bar = page.find_child("SettlementTabs", true, false) as Control
	after = bar.get_parent().get_child(bar.get_index() + 1) as CanvasItem
	check(is_equal_approx(after.modulate.a, 1.0), "under Reduced motion the page turns at once")
	sound.reduced_motion = false


# ---- 3. what changed shows itself
func _floats() -> Array:
	return scenes.get_children().filter(func(c): return String(c.name).begins_with("Float_") and not c.is_queued_for_deletion())


func _changes() -> void:
	var Widgets = load("res://scripts/ui/widgets.gd")
	var CourtUI = load("res://scripts/ui/court_ui.gd")
	# The town: buying food floats what it cost off the silver tile.
	scenes.settlement_arrival_pending = false
	change_scene_to_file("res://scenes/settlement.tscn")
	await _arrive("settlement.tscn")
	var page = current_scene
	gs.silver = 2000
	page._build()
	await _wait(0.6)
	for f in _floats():
		f.free()
	page._on_buy_food(gs.total_men() * 3)
	await _frames(3)
	var floats := _floats()
	check(floats.any(func(f): return String(f.name).contains("silver")), "buying food, what it cost rises off the silver")
	check(floats.any(func(f): return String(f.name).contains("food")), "and what it brought rises off the food")
	var f0: Control = floats[0]
	var y0: float = f0.position.y
	await _wait(0.4)
	check(is_instance_valid(f0) and f0.position.y < y0 - 20.0, "the number rises")
	await _wait(1.0)
	check(_floats().is_empty(), "and is gone in a moment")
	# Hiring: the new company glows on the page.
	var offers: Array = gs.world.offers_at(page.place)
	page._on_tab("buy")
	await _frames(2)
	if not offers.is_empty() and page.find_child("Offer_0", true, false) != null:
		page._on_hire(0)
		await _frames(3)
		var squads_tab := page.find_child("Tab_squads", true, false) as Control
		check(squads_tab != null and squads_tab.modulate.r > 1.05, "hiring, the Squads tab glows: that's where the company went")
		await _wait(1.0)
		check(is_instance_valid(squads_tab) and squads_tab.modulate.is_equal_approx(Color.WHITE), "then settles")
	# Training: the company itself glows.
	page._on_tab("squads")
	await _frames(2)
	var sq: Dictionary = gs.army[0]
	page._paid(true, "coins", "Squad_%d" % int(sq["id"]))
	await _frames(3)
	var row := page.find_child("Squad_%d" % int(sq["id"]), true, false) as Control
	check(row != null and row.modulate.r > 1.05, "a company a tap changed glows as the page comes back")
	# Regard rises by the lord's face.
	var l: Dictionary = gs.world.lords[0]
	var host := VBoxContainer.new()
	host.size = Vector2(400, 400)
	root.add_child(host)
	var face: Control = CourtUI.face(l, 80.0)
	host.add_child(face)
	await _frames(2)
	gs.regard_events = [{"id": int(l["id"]) , "amount": 2, "at": Time.get_ticks_msec() - 10000}]
	gs.add_lord_relation(int(l["id"]), 5)
	Widgets.show_regard(host)
	await _frames(2)
	var rf := _floats().filter(func(f): return String(f.name).contains("bond"))
	check(rf.size() == 1, "a lord's new Regard rises by his face, once")
	var txt := ""
	for lab in rf[0].find_children("*", "Label", true, false):
		txt += (lab as Label).text
	check(txt.contains("+5"), "showing what changed just now, not before (%s)" % txt)
	check(gs.regard_events.is_empty(), "and it's told only once")
	# Reduced motion: nothing floats, the numbers on the page say it.
	sound.reduced_motion = true
	gs.add_lord_relation(int(l["id"]), 3)
	for f in _floats():
		f.free()
	Widgets.show_regard(host)
	page._on_buy_food(10)
	await _frames(3)
	check(_floats().is_empty(), "under Reduced motion nothing floats")
	sound.reduced_motion = false
	host.queue_free()
	await _wait(1.2)


# ---- 5. the battle result tells itself
func _battle() -> Node:
	gs.new_campaign("vardish")
	var w = gs.world
	w.encounter = w.bands()[0].id
	gs.start_encounter_battle()
	change_scene_to_file("res://scenes/battle.tscn")
	await _arrive("battle.tscn")
	return current_scene


func _value(n: Node) -> String:
	var v := n.find_child("Value", true, false) as Label
	return v.text if v != null else ""


func _result() -> void:
	var sc = await _battle()
	var Sim = load("res://scripts/battle/battle_sim.gd")
	sc.sim.winner = Sim.PLAYER
	sc._show_result()
	await _frames(2)
	var tally: Node = sc.result_content.get_node_or_null("Tally")
	var rewards: Node = sc.result_content.get_node_or_null("Rewards")
	check(tally != null and (tally as CanvasItem).modulate.a < 0.5, "the tally waits its turn")
	check(rewards == null or _value(rewards) == "+0", "the spoils start from nothing (%s)" % (_value(rewards) if rewards != null else "none"))
	await _wait(0.7)
	check((tally as CanvasItem).modulate.a > 0.5, "then the tally comes up and counts")
	await _wait(1.6)
	check(is_equal_approx((tally as CanvasItem).modulate.a, 1.0) and is_equal_approx(sc.result_title.scale.x, 1.0), "in under two seconds it has all told itself")
	if rewards != null:
		check(_value(rewards).begins_with("+") and _value(rewards) != "+0", "the spoils land on their number (%s)" % _value(rewards))
	# A tap finishes it at once.
	sc._show_result()
	await _frames(2)
	sc.finish_result_sequence()
	await _frames(1)
	var all_in := true
	for c in sc.result_content.get_children():
		if c is CanvasItem and (c as CanvasItem).visible and (c as CanvasItem).modulate.a < 0.99:
			all_in = false
	check(all_in and (rewards == null or _value(sc.result_content.get_node("Rewards")) != "+0"), "a tap and everything is there")
	# Reduced motion: there from the start.
	sound.reduced_motion = true
	sc._show_result()
	await _frames(2)
	var whole := true
	for c in sc.result_content.get_children():
		if c is CanvasItem and (c as CanvasItem).visible and (c as CanvasItem).modulate.a < 0.99:
			whole = false
	check(whole, "under Reduced motion the result is all there at once")
	sound.reduced_motion = false
	change_scene_to_file("res://scenes/main_menu.tscn")
	await _frames(4)


# ---- 6, 7, 8. the clock sweeps, the encounter lands, letters drop in
func _map_moments() -> void:
	gs.new_campaign("vardish")
	var w = gs.world
	w.hour = 30.0
	scenes.map_clock_seen = 20.0
	change_scene_to_file("res://scenes/world_map.tscn")
	await _arrive("world_map.tscn")
	var m = current_scene
	var shown_early: String = m.clock_label.text
	await _wait(1.2)
	check(shown_early != "06:00" and m.clock_label.text == "06:00" and m.day_label.text == "2",
		"time that passed out of sight sweeps by on the clock (%s, then %s)" % [shown_early, m.clock_label.text])
	check(is_equal_approx(scenes.map_clock_seen, w.hour), "and the map remembers the hour it showed")
	# 7. a hostile lord blocks the road: the camera steps in on the two parties.
	var foe = null
	for lp in w.lord_parties():
		if w.relation_to_player(lp.faction) == "hostile":
			foe = lp
			break
	if foe == null:
		for lp in w.lord_parties():
			if lp.faction != "vardmark":
				foe = lp
				break
		gs.realm_relations[String(foe.faction)] = -40
	foe.node = w.player().node
	foe.next = ""
	foe.path = []
	w.encounter = foe.id
	var s0: float = m.cam_scale
	m._open_encounter()
	await _wait(0.6)
	check(m.cam_scale > s0 * 1.1 or is_equal_approx(m.cam_scale, m._view.size.x / m.NARROWEST_VIEW), "a road encounter steps the camera in on the two parties (%.2f → %.2f)" % [s0, m.cam_scale])
	w.encounter = -1
	m._close_sheet()
	await _wait(0.3)
	# 8. a letter drops in from behind the top bar.
	m.letter_banner.offset_top = 200.0
	m.letter_banner.visible = true
	m._drop_banner()
	await _frames(2)
	var mid: float = m.letter_banner.offset_top
	await _wait(0.6)
	check(mid < 190.0 and is_equal_approx(m.letter_banner.offset_top, 200.0), "a letter drops in from behind the top bar and lands (%.0f → %.0f)" % [mid, m.letter_banner.offset_top])
	m.letter_banner.visible = false
	# Reduced motion: the clock and the camera just are.
	sound.reduced_motion = true
	scenes.map_clock_seen = w.hour - 10.0
	m._clock_shown = -1.0
	m._refresh_hud()
	check(m.clock_label.text == "%02d:00" % (int(w.hour) % 24), "under Reduced motion the clock just shows the hour")
	sound.reduced_motion = false


# ---- 9. deeds and promotions get a ribbon
func _ribbons() -> void:
	change_scene_to_file("res://scenes/main_menu.tscn")
	await _arrive("main_menu.tscn")
	scenes.ribbons.clear()
	scenes.ribbon("A deed to remember", "The company is now known as Test.", "renown", "")
	await _frames(3)
	var r := scenes.get_node_or_null("Ribbon") as Control
	check(r != null and (r.find_child("RibbonTitle", true, false) as Label).text == "A deed to remember", "a deed drops in as a ribbon")
	await _wait(0.5)
	check(is_instance_valid(r) and r.position.y >= 0.0, "it holds in view")
	await _wait(2.6)
	check(not is_instance_valid(r) or r.is_queued_for_deletion(), "and rolls away")
	# A captain who becomes ready for a role in a battle gets one, after the battle.
	var Captains = load("res://scripts/data/captains.gd")
	var sq: Dictionary = gs.army[0]
	var c: Dictionary = sq["captain"]
	c["specialization"] = ""
	c["battles"] = Captains.SPECIALIZATION_BATTLES - 1
	c["kills"] = 0
	scenes.ribbons.clear()
	gs.pending_battle = {}
	gs.apply_result({"won": true, "lost": 0, "killed": 3, "squads": {int(sq["id"]): {"men": int(sq["men"]), "kills": 3, "captain": {"fate": "standing", "kills": 0}}}, "enemy_squads": {}})
	check(scenes.ribbons.any(func(x): return String(x["title"]).contains("ready for a role")), "a captain who becomes ready for a role gets a ribbon")
	scenes.ribbons.clear()
