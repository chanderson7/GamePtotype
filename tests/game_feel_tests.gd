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
	await _talk_and_scenes()
	await _turning_points()
	await _battle_beats()
	await _pages_show_change()
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
	var silver_float: Array = floats.filter(func(f): return String(f.name).contains("silver"))
	var tile: Control = null
	for n in page.find_children("Tile_silver", "Control", true, false):
		if Widgets.live(n):
			tile = n
			break
	if not silver_float.is_empty() and tile != null:
		var fr: Rect2 = (silver_float[0] as Control).get_global_rect()
		var tr: Rect2 = tile.get_global_rect()
		check(fr.position.x < tr.end.x and fr.end.x > tr.position.x and absf(fr.get_center().y - tr.get_center().y) < tr.size.y + 60.0,
			"it rises from the silver itself (%s by %s)" % [fr.position, tr.position])
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
	check(r != null and r.size.x > 300.0, "as wide as a banner, not squeezed (%.0f)" % (r.size.x if r != null else 0.0))
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


# ---- pages that were rebuilt in a frame now show what changed: letters unfold, a mark is
# struck, the thing you did glows, numbers count, and captains' faces are alive.
func _pages_show_change() -> void:
	var Widgets = load("res://scripts/ui/widgets.gd")
	var CaptainArt = load("res://scripts/ui/captain_art.gd")
	var Captains = load("res://scripts/data/captains.gd")
	gs.new_campaign("vardish")
	change_scene_to_file("res://scenes/main_menu.tscn")
	await _arrive("main_menu.tscn")
	var host := VBoxContainer.new()
	host.size = Vector2(400, 900)
	root.add_child(host)
	var paper := PanelContainer.new()
	paper.custom_minimum_size = Vector2(300, 200)
	host.add_child(paper)
	Widgets.unfold(paper)
	check(paper.modulate.a < 0.1, "a letter opened starts folded")
	await _frames(4)
	check(paper.scale.y < 0.95, "and unfolds from its top edge (%.2f)" % paper.scale.y)
	await _wait(0.5)
	check(paper.scale.is_equal_approx(Vector2.ONE) and is_equal_approx(paper.modulate.a, 1.0), "to lie open")
	var dot := Control.new()
	dot.custom_minimum_size = Vector2(16, 16)
	host.add_child(dot)
	Widgets.pulse(dot)
	await _wait(0.14)
	check(dot.scale.x > 1.05, "an unread letter's dot beats")
	await _wait(1.0)
	check(dot.scale.is_equal_approx(Vector2.ONE), "and settles")
	var mark := PanelContainer.new()
	mark.custom_minimum_size = Vector2(60, 60)
	host.add_child(mark)
	Widgets.stamp(mark)
	check(mark.modulate.a < 0.1, "a new mark isn't there yet")
	await _frames(4)
	check(mark.scale.x > 1.05, "it comes down large")
	await _wait(0.5)
	check(mark.scale.is_equal_approx(Vector2.ONE) and is_equal_approx(mark.modulate.a, 1.0), "and is struck")
	var changed := Label.new()
	changed.text = "Changed"
	Widgets.flash_soon(changed)
	host.add_child(changed)
	await _frames(5)
	check(changed.modulate.r > 1.05, "what a tap changed glows on the page that comes back, asked for before it was on it")
	var mover := PanelContainer.new()
	mover.custom_minimum_size = Vector2(60, 60)
	host.add_child(mover)
	Widgets.step_in(mover, Vector2(-70, 0))
	await _frames(4)
	var mx: float = mover.position.x
	await _wait(0.6)
	check(mover.position.x > mx + 5.0 and is_equal_approx(mover.modulate.a, 1.0), "someone steps into their place on a page")
	sound.reduced_motion = true
	var still := PanelContainer.new()
	still.custom_minimum_size = Vector2(60, 60)
	host.add_child(still)
	Widgets.unfold(still)
	Widgets.stamp(still)
	Widgets.pulse(still)
	Widgets.flash_soon(still)
	Widgets.step_in(still, Vector2(-70, 0))
	await _frames(4)
	check(still.scale.is_equal_approx(Vector2.ONE) and still.modulate.is_equal_approx(Color.WHITE), "under Reduced motion all of it is simply there")
	sound.reduced_motion = false
	host.queue_free()
	# A captain's face blinks wherever it's shown.
	var cap: Dictionary = gs.army[0]["captain"]
	var shut_tex: Texture2D = CaptainArt.texture(cap, "blink")
	var pic := TextureRect.new()
	pic.texture = CaptainArt.texture(cap)
	root.add_child(pic)
	var blinked := [0]
	var apply := func(tex: Texture2D) -> void:
		pic.texture = tex
		if tex == shut_tex:
			blinked[0] += 1
	CaptainArt.blink_loop(pic, apply, cap)
	await _wait(6.0)
	check(shut_tex != null and shut_tex != CaptainArt.texture(cap) and blinked[0] >= 1, "a captain's portrait blinks (%d in six seconds)" % blinked[0])
	pic.queue_free()
	# A ribbon about a person carries their face.
	scenes.ribbons.clear()
	scenes.ribbon_face("Test joins the company", "Sergeant", CaptainArt.texture(cap), "")
	await _frames(4)
	var rib := scenes.get_node_or_null("Ribbon") as Control
	check(rib != null and rib.find_child("RibbonFace", true, false) != null, "a hero who joins is seen: their face on a ribbon")
	if rib != null:
		scenes._dismiss_ribbon(rib)
	await _frames(2)
	# A promotion: the new role is struck onto the page and told with their proud face.
	cap["specialization"] = ""
	cap["battles"] = Captains.SPECIALIZATION_BATTLES
	scenes.active_captain_id = int(cap["id"])
	change_scene_to_file("res://scenes/captain_profile.tscn")
	await _arrive("captain_profile.tscn")
	var prof = current_scene
	scenes.ribbons.clear()
	prof._picked = String(Captains.SPECIALIZATIONS[0])
	prof._confirm_promotion()
	var chips: Array = prof.find_children("SpecializationChip", "Control", true, false).filter(func(n): return Widgets.live(n))
	check(not chips.is_empty() and (chips[0] as Control).modulate.a < 0.1, "a promotion's new role is about to be struck")
	check(scenes.ribbons.any(func(x): return x.get("face") is Texture2D) or (scenes.get_node_or_null("Ribbon") != null), "and is told with the captain's face")
	await _wait(0.8)
	check(not chips.is_empty() and is_instance_valid(chips[0]) and is_equal_approx((chips[0] as Control).modulate.a, 1.0) and (chips[0] as Control).scale.is_equal_approx(Vector2.ONE), "and is")
	scenes.ribbons.clear()
	if scenes._ribbon != null:
		scenes._dismiss_ribbon(scenes._ribbon)
	# The Warband page counts men in.
	var men: int = gs.total_men()
	scenes.warband_men_seen = men - 3
	change_scene_to_file("res://scenes/main_menu.tscn")
	await _arrive("main_menu.tscn")
	var tile := current_scene.find_child("Tile_men", true, false)
	await _wait(0.9)
	check(tile != null and (tile.find_child("Value", true, false) as Label).text == str(men) and scenes.warband_men_seen == men, "men back on their feet are counted in on the Warband page")
	check(current_scene.find_child("CampTableau", true, false) != null, "with the captains around the fire")
	# A letter unfolds when it's opened.
	var social = gs.world.social
	var kp: Dictionary = social.get_candidate_person("kaede")
	var unread: Dictionary = social.add_letter(kp["id"], "relocation", "", gs.world.hour, "takamine", {"old": "Kitayama"})
	scenes.people_tab = "letters"
	change_scene_to_file("res://scenes/people.tscn")
	await _arrive("people.tscn")
	var people = current_scene
	check(people.find_child("Unread", true, false) != null, "an unread letter is marked")
	people._open_letter(String(unread["id"]))
	var sheet := people.find_children("Parchment", "Control", true, false).filter(func(n): return Widgets.live(n))
	check(not sheet.is_empty() and (sheet[0] as Control).modulate.a < 0.1, "opened, the letter unfolds")
	await _wait(0.7)
	check(not sheet.is_empty() and is_instance_valid(sheet[0]) and (sheet[0] as Control).scale.is_equal_approx(Vector2.ONE) and is_equal_approx((sheet[0] as Control).modulate.a, 1.0), "and lies open to read")
	people._build()
	await _frames(3)
	var again := people.find_children("Parchment", "Control", true, false).filter(func(n): return Widgets.live(n))
	check(not again.is_empty() and is_equal_approx((again[0] as Control).modulate.a, 1.0), "a page rebuilt under it leaves it lying open")
	# The Crown: what you did is said, and the treasury counts.
	gs.renown = 250
	gs.player_fief = {"settlement_id": "ravensford", "realm": gs.world.owner_of("ravensford"), "silver": 0, "food": 20,
		"improvements": {}, "garrison": [], "granted_at": 0.0, "lost": false}
	var p = gs.world.player()
	p.node = "ravensford"
	p.next = ""
	p.path = []
	scenes.ribbons.clear()
	var crowned: bool = gs.declare_crown()
	check(crowned and scenes.ribbons.any(func(x): return bool(x.get("grand", false)) and String(x["title"]) == "A crown is raised"), "raising your crown is marked as the moment it is")
	scenes.ribbons.clear()
	change_scene_to_file("res://scenes/main_menu.tscn")
	await _arrive("main_menu.tscn")
	gs.silver = 5000
	var K = load("res://scripts/world/kingdom_screen.gd")
	var k = K.open(root, gs, "realm")
	await _frames(3)
	var before: int = gs.crown_treasury()
	var fund := k.find_child("Fund", true, false) as Button
	check(fund != null and not fund.disabled, "the treasury can be paid into")
	if fund != null:
		fund.pressed.emit()
	await _frames(6)
	var said: Array = k.find_children("Flash", "Control", true, false).filter(func(n): return Widgets.live(n))
	check(gs.crown_treasury() > before and not said.is_empty() and (said[0] as Control).modulate.r > 1.02, "what you did on the Crown page lands with a glow")
	var chest: Array = k.find_children("Tile_chest", "Control", true, false).filter(func(n): return Widgets.live(n))
	await _wait(0.8)
	check(not chest.is_empty() and ((chest[0] as Node).find_child("Value", true, false) as Label).text == Widgets.thousands(gs.crown_treasury()), "and the treasury counts to its new sum")
	k.queue_free()
	scenes.ribbons.clear()


# ---- the big moments: the captains' talk at the fire is told a line at a time, a bond's
# new rank is struck, a crown raised takes the screen, and the map tells what concerns you.
func _turning_points() -> void:
	var TalkView = load("res://scripts/ui/talk_view.gd")
	var tv = TalkView.new()
	root.add_child(tv)
	tv.setup(TalkView.room("company_camp", "night"), "Test")
	var rest := ImageTexture.create_from_image(Image.create(8, 8, false, Image.FORMAT_RGBA8))
	var shut := ImageTexture.create_from_image(Image.create(8, 8, false, Image.FORMAT_RGBA8))
	tv.set_face("left", rest, true, 0.6)
	tv.set_face("right", rest, true, 0.6)
	await _wait(0.5)
	var lf: TextureRect = tv.face_node("left")
	var rf: TextureRect = tv.face_node("right")
	# Each captain's own face leans into their own line.
	var ly: float = lf.position.y
	var ry: float = rf.position.y
	tv.say("them", "The one on the left speaks.", "A")
	await _wait(0.08)
	check(lf.position.y < ly - 1.0 and is_equal_approx(rf.position.y, ry), "the one on the left leans into their own line")
	await _wait(0.4)
	tv.say("other", "And the one on the right answers.", "B")
	await _wait(0.08)
	check(rf.position.y < ry - 1.0 and is_equal_approx(lf.position.y, ly), "and the one on the right into theirs")
	tv.finish_writing()
	tv.clear_log()
	# Told in turn: all of it is in the talk, one line showing at a time.
	var said := []
	var done := [false]
	var note := func(side: String) -> void: said.append(side)
	var lines := [{"who": "narration", "text": "They sat late by the fire."},
		{"who": "them", "text": "You held the left when it mattered.", "speaker": "A", "then": note},
		{"who": "other", "text": "You'd have done the same.", "speaker": "B", "then": note},
		{"who": "them", "text": "I would have. Badly.", "speaker": "A", "then": note}]
	tv.say_in_turn(lines, func() -> void: done[0] = true)
	var nothing := func() -> void: pass
	tv.set_replies([{"id": "back", "text": "Back", "tone": "primary", "act": nothing}])
	await _frames(3)
	var rows: Array = tv._log.get_children()
	check(rows.size() == 4 and rows[0].visible and not rows[2].visible and not rows[3].visible, "a talk at the fire is told a line at a time")
	check(tv.log_text().contains("I would have. Badly.") and tv.has_reply("back"), "all of it is there to read back, and the way on can be pressed at once")
	await _wait(1.6)
	check(rows[1].visible and said == ["left"] and not done[0], "each line comes in its turn, said by its own speaker (%s)" % str(said))
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	tv._tap(up)
	check(rows.all(func(r): return r.visible) and said == ["left", "right", "left"] and done[0] and not tv.writing(),
		"a tap brings the rest at once (%s)" % str(said))
	check((rows[3].find_child("Words", true, false) as Label).visible_characters == -1, "whole, not half written")
	# The one speaking is lit, the one listening quiet.
	tv.spotlight("left")
	await _wait(0.35)
	check(lf.self_modulate.is_equal_approx(Color.WHITE) and rf.self_modulate.r < 0.7, "the one speaking is lit, the one listening dimmed")
	tv.spotlight("")
	await _wait(0.35)
	check(rf.self_modulate.is_equal_approx(Color.WHITE), "and both are lit once all is said")
	# A face the game draws blinks while it wears its resting look.
	tv.set_blink("left", rest, shut)
	tv._faces["left"]["blink"]["wait"] = 0.01
	await _frames(3)
	check(lf.texture == shut, "a captain blinks")
	await _wait(0.3)
	check(lf.texture == rest, "and opens their eyes again")
	tv.change_face("left", shut)
	tv.change_face("left", ImageTexture.create_from_image(Image.create(8, 8, false, Image.FORMAT_RGBA8)))
	tv._faces["left"]["blink"]["wait"] = 0.01
	await _frames(3)
	check(lf.texture != shut and lf.texture != rest, "but not while wearing an expression")
	sound.reduced_motion = true
	tv.clear_log()
	tv.say_in_turn(lines)
	check(tv._log.get_children().all(func(r): return r.visible) and not tv.writing(), "under Reduced motion a talk is all there at once")
	sound.reduced_motion = false
	tv.queue_free()
	# The fire talk itself: two captains, the first line showing, the way on there.
	var a: Dictionary = gs.army[0]["captain"]
	var b: Dictionary = gs.army[1]["captain"]
	a["bonds"][str(int(b["id"]))] = 25.0
	b["bonds"][str(int(a["id"]))] = 25.0
	scenes.active_bond_a_id = int(a["id"])
	scenes.active_bond_b_id = int(b["id"])
	scenes.bond_conversation_return = "res://scenes/main_menu.tscn"
	change_scene_to_file("res://scenes/bond_conversation.tscn")
	await _arrive("bond_conversation.tscn")
	var fire = current_scene
	var told: Array = fire._log.get_children()
	check(told.size() > 2 and told[0].visible and not told[told.size() - 1].visible and fire.writing(), "by the fire, the captains' talk is told in turn (%d lines)" % told.size())
	check(fire._faces["left"].has("shut") and fire._faces["right"].has("shut"), "and both can blink")
	fire._tap(up)
	await _frames(2)
	check(told.all(func(r): return r.visible) and fire.face_node("left").self_modulate.is_equal_approx(Color.WHITE)
		and fire.face_node("right").self_modulate.is_equal_approx(Color.WHITE), "a tap brings it all, both of them lit")
	# A bond's new rank: the two step toward each other and the rank is struck.
	gs.bond_events = [{"kind": "rank", "rank": "B", "a_id": int(a["id"]), "b_id": int(b["id"]),
		"pair": "%s & %s" % [a["name"], b["name"]], "points": 12.0, "shared_battles": 4}]
	change_scene_to_file("res://scenes/bond_intro.tscn")
	await _arrive("bond_intro.tscn")
	var pair := current_scene.find_child("BondPortraits", true, false) as Control
	var badge := current_scene.find_child("Rank_B", true, false) as Control
	check(pair != null and pair.get_child_count() == 2 and badge != null, "a new rank shows the two captains and the rank")
	await _wait(1.4)
	check(pair != null and is_equal_approx((pair.get_child(0) as Control).modulate.a, 1.0) and badge != null and badge.scale.is_equal_approx(Vector2.ONE)
		and is_equal_approx(badge.modulate.a, 1.0), "they've stepped in and the rank is struck")
	gs.bond_events = []
	# A crown raised takes the screen for a breath.
	change_scene_to_file("res://scenes/main_menu.tscn")
	await _arrive("main_menu.tscn")
	scenes.ribbons.clear()
	scenes.moment("A crown is raised", "Ravensford is the seat of your crown.", "crown", false, "")
	await _frames(4)
	var shade := scenes.get_node_or_null("Moment") as Control
	check(shade != null and (shade.find_child("MomentTitle", true, false) as Label).text == "A crown is raised", "a crown raised takes the screen")
	var flag := shade.find_child("Flag", true, false) as Control if shade != null else null
	check(flag != null and flag.scale.y < 0.9, "its banner unfurls")
	await _wait(1.3)
	check(flag != null and is_instance_valid(flag) and flag.scale.is_equal_approx(Vector2.ONE) and is_equal_approx(shade.modulate.a, 1.0), "and hangs there")
	scenes._dismiss_ribbon(shade)
	await _frames(2)
	check(scenes.get_node_or_null("Moment") == null, "a tap sends it away")
	scenes.moment("Your crown has fallen", "The company rides free again.", "crown", true, "")
	await _frames(4)
	shade = scenes.get_node_or_null("Moment") as Control
	flag = shade.find_child("Flag", true, false) as Control if shade != null else null
	await _wait(1.9)
	check(flag != null and is_instance_valid(flag) and flag.modulate.a < 0.2, "a crown fallen: the banner comes down")
	await _wait(3.2)
	check(scenes.get_node_or_null("Moment") == null, "and the light comes back by itself")
	sound.reduced_motion = true
	scenes.moment("A crown is raised", "", "crown", false, "")
	await _frames(4)
	shade = scenes.get_node_or_null("Moment") as Control
	flag = shade.find_child("Flag", true, false) as Control if shade != null else null
	check(shade != null and is_equal_approx(shade.modulate.a, 1.0) and flag != null and flag.scale.is_equal_approx(Vector2.ONE), "under Reduced motion it is simply there")
	if shade != null:
		scenes._dismiss_ribbon(shade)
	sound.reduced_motion = false
	await _frames(2)
	# The map tells what concerns you, and a holding that changes hands shows it.
	change_scene_to_file("res://scenes/world_map.tscn")
	await _arrive("world_map.tscn")
	var m = current_scene
	var w = gs.world
	m._sheet = ""
	scenes.ribbons.clear()
	w.events.append({"type": "fief_lost", "settlement": "ravensford", "by": "Lord Test"})
	w.events.append({"type": "lord_slain", "lord": "Lord Other", "by": "someone else"})
	w.events.append({"type": "captured", "settlement": "ravensford", "realm": "kharzan", "from": "vardmark"})
	await _frames(3)
	var heard: Array = scenes.ribbons.map(func(x): return String(x["title"]))
	var showing: Node = scenes.get_node_or_null("Ribbon")
	if showing != null:
		heard.append((showing.find_child("RibbonTitle", true, false) as Label).text)
	check(heard.has("Ravensford is lost"), "losing your fief is told on the map (%s)" % str(heard))
	check(not heard.any(func(t): return String(t).contains("Lord Other")), "what doesn't concern you isn't")
	check(m._flag_changes.has("ravensford") and String(m._flag_changes["ravensford"]["from"]) == "vardmark", "a holding that changes hands furls its old banner")
	await _wait(1.8)
	m.queue_redraw()
	await _frames(3)
	check(not m._flag_changes.has("ravensford"), "and flies the new one a moment later")
	sound.reduced_motion = true
	w.events.append({"type": "captured", "settlement": "ravensford", "realm": "vardmark", "from": "kharzan"})
	await _frames(3)
	check(not m._flag_changes.has("ravensford"), "under Reduced motion the banner simply changes")
	sound.reduced_motion = false
	scenes.ribbons.clear()
	if scenes._ribbon != null:
		scenes._dismiss_ribbon(scenes._ribbon)


# ---- the talks you court and befriend in: faces breathe and gesture, only the new line is
# said, replies and keepsakes arrive, trust is seen to change, and the People page shows
# what a visit changed.
## The painted portraits (Edda, Farah, Kaede) blink: each painting has a twin with its
## eyes shut, made from it (tools/portrait_blink.py), and a talk swaps to it for a moment.
func _painted_blink() -> void:
	var StoryArt = load("res://scripts/ui/story_art.gd")
	var TalkView = load("res://scripts/ui/talk_view.gd")
	var made := 0
	var only_eyes := true
	for who in ["edda", "farid", "kaede"]:
		for expression in StoryArt.EXPRESSIONS:
			var path := "res://assets/portraits/%s_%s.png" % [who, expression]
			var open: Texture2D = StoryArt.texture(path)
			var shut: Texture2D = StoryArt.eyes_shut(open)
			if open == null or shut == null or shut == open or shut.get_size() != open.get_size():
				continue
			made += 1
			var a: Image = StoryArt._image(path)
			var b: Image = shut.get_image()
			if a == null or b == null or b.is_empty():
				continue                                  # no pixels to read back without a screen
			b.convert(Image.FORMAT_RGBA8)
			var changed := 0
			for y in a.get_height():
				for x in a.get_width():
					if a.get_pixel(x, y) != b.get_pixel(x, y):
						changed += 1
						if not StoryArt.EYES.has_point(Vector2i(x, y)):
							only_eyes = false
			if changed < 60:
				only_eyes = false
	check(made == 15, "every painted portrait has a picture of its eyes shut (%d of 15)" % made)
	check(only_eyes, "and it is the same painting everywhere but the eyes")
	check(StoryArt.eyes_shut(ImageTexture.create_from_image(Image.create(8, 8, false, Image.FORMAT_RGBA8))) == null, "a picture with no twin has none")
	var tv = TalkView.new()
	root.add_child(tv)
	tv.setup(TalkView.room("common_room", "night"), "Edda")
	var neutral: Texture2D = StoryArt.texture("res://assets/portraits/edda_neutral.png")
	var warm: Texture2D = StoryArt.texture("res://assets/portraits/edda_warm.png")
	tv.set_face("left", neutral, false, 0.98)
	var f: TextureRect = tv.face_node("left")
	check(tv._faces["left"].get("shut") == StoryArt.eyes_shut(neutral), "a painted face in a talk can blink")
	tv._faces["left"]["blink"]["wait"] = 0.01
	await _wait(0.06)
	check(f.texture == StoryArt.eyes_shut(neutral), "she blinks")
	tv.change_face("left", neutral)
	check(f.texture == StoryArt.eyes_shut(neutral), "asked for the face she already wears, mid-blink, nothing jumps")
	await _wait(0.3)
	check(f.texture == neutral, "and her eyes open again")
	tv.express("left", warm, "warm")
	check(f.texture == warm and tv._faces["left"].get("shut") == StoryArt.eyes_shut(warm), "a new expression brings its own shut eyes")
	tv._faces["left"]["blink"]["wait"] = 0.01
	await _wait(0.06)
	check(f.texture == StoryArt.eyes_shut(warm), "and blinks with them")
	tv.express("left", neutral, "")
	check(f.texture == neutral, "an expression that changes mid-blink lands on the new face")
	await _wait(0.3)
	check(f.texture == neutral, "and stays there")
	tv.queue_free()
	# The portrait on a page blinks too; under Reduced motion it doesn't.
	var pic: TextureRect = StoryArt.candidate_portrait("kaede", "neutral", 200)
	root.add_child(pic)
	var rest: Texture2D = pic.texture
	var seen := 0
	for i in 130:
		await _wait(0.05)
		if pic.texture == StoryArt.eyes_shut(rest):
			seen += 1
	check(seen >= 1, "a painted portrait on a page blinks (seen shut %d times in six and a half seconds)" % seen)
	pic.queue_free()
	sound.reduced_motion = true
	var still: TextureRect = StoryArt.candidate_portrait("kaede", "neutral", 200)
	root.add_child(still)
	seen = 0
	for i in 130:
		await _wait(0.05)
		if still.texture != rest:
			seen += 1
	check(seen == 0, "and holds still under Reduced motion")
	sound.reduced_motion = false
	still.queue_free()


func _romance_moves() -> void:
	var TalkView = load("res://scripts/ui/talk_view.gd")
	var tv = TalkView.new()
	root.add_child(tv)
	tv.setup(TalkView.room("common_room", "night"), "Test")
	var tex := ImageTexture.create_from_image(Image.create(8, 8, false, Image.FORMAT_RGBA8))
	var tex2 := ImageTexture.create_from_image(Image.create(8, 8, false, Image.FORMAT_RGBA8))
	tv.set_face("left", tex)
	await _wait(0.5)
	var f: TextureRect = tv.face_node("left")
	var s0: float = f.scale.y
	await _wait(0.4)
	check(not is_equal_approx(f.scale.y, s0), "a face in a talk breathes")
	tv.gesture("left", "lean")
	await _wait(0.45)
	check(f.scale.x > 1.02, "warm, they lean in and stay there (%.3f)" % f.scale.x)
	tv.gesture("left", "back")
	await _wait(0.45)
	check(f.scale.x < 0.98, "concerned, they draw back")
	tv.gesture("left", "")
	await _wait(0.45)
	check(absf(f.scale.x - 1.0) < 0.005, "and are as they were after")
	var y0: float = f.position.y
	tv.gesture("left", "bounce")
	await _wait(0.07)
	check(f.position.y < y0 - 1.0, "amused, they laugh: the face hops")
	tv.say("them", "Ha!", "Test")
	await _wait(0.6)
	check(is_equal_approx(f.position.y, y0), "and lands where it stood, a line said meanwhile or not")
	tv.sway("left")
	await _wait(0.3)
	check(absf(f.rotation) > 0.001, "a partner sways while dancing")
	tv.sway("left", 0.0)
	tv.finish_writing()
	# Laid out again, an old line is simply there; the new one is said.
	tv.write_lines = false
	var heard: Control = tv.say("them", "You have heard this line before.", "Test")
	tv.write_lines = true
	var fresh: Control = tv.say("them", "And this one is new to you.", "Test")
	var fresh_words := fresh.find_child("Words", true, false) as Label
	check((heard.find_child("Words", true, false) as Label).visible_characters == -1 and fresh_words.visible_characters >= 0
		and fresh_words.visible_characters < fresh_words.text.length(), "only the newest line is written out")
	tv.finish_writing()
	var nothing := func() -> void: pass
	tv.set_replies([{"id": "a", "text": "One", "act": nothing}, {"id": "b", "text": "Two", "act": nothing}, {"id": "c", "text": "Three", "act": nothing}])
	var last: Button = tv.reply_node("c")
	check(last.modulate.a < 0.5 and not last.disabled and tv.has_reply("c"), "replies arrive in a short run, and can be pressed at once")
	await _wait(0.5)
	check(is_equal_approx(last.modulate.a, 1.0), "and are all there a moment later")
	var kept: Control = tv.keepsake("A memory kept: the test.")
	tv.add_to_log(kept)
	check(kept.modulate.a < 0.1, "a memory kept lands in the talk")
	await _wait(0.2)
	check(kept.scale.x < 1.0 or kept.modulate.r > 1.0, "settling in with a glow")
	await _wait(1.2)
	check(is_equal_approx(kept.modulate.a, 1.0) and kept.scale.is_equal_approx(Vector2.ONE) and is_equal_approx(kept.modulate.r, 1.0), "and is itself after")
	tv.replace_face("left", tex2)
	check(f.texture == tex2 and f.modulate.a < 0.5, "a new partner steps in")
	await _wait(0.5)
	check(is_equal_approx(f.modulate.a, 1.0), "and is there")
	sound.reduced_motion = true
	tv.gesture("left", "lean")
	var still: Control = tv.keepsake("A memory kept: the still test.")
	tv.add_to_log(still)
	tv.set_replies([{"id": "a", "text": "One", "act": nothing}, {"id": "b", "text": "Two", "act": nothing}])
	await _frames(3)
	check(f.scale.is_equal_approx(Vector2.ONE) and is_equal_approx(f.rotation, 0.0) and is_equal_approx(still.modulate.a, 1.0)
		and is_equal_approx((tv.reply_node("b") as Button).modulate.a, 1.0), "under Reduced motion faces, memories and replies are simply there")
	sound.reduced_motion = false
	tv.queue_free()
	# The petals thrown when you're wed.
	var Dressing = load("res://scripts/ui/wedding_dressing.gd")
	var dr = Dressing.new()
	dr.size = Vector2(400, 300)
	root.add_child(dr)
	dr.burst()
	check(dr._burst > 0.9, "petals are thrown at a wedding")
	await _wait(0.3)
	check(dr._burst < 0.95 and dr._burst > 0.0, "and fall")
	sound.reduced_motion = true
	dr._burst = 0.0
	dr.burst()
	check(dr._burst == 0.0, "not under Reduced motion")
	sound.reduced_motion = false
	dr.queue_free()
	# A visit: trust won is seen on the nameplate.
	var social = gs.world.social
	scenes.active_candidate_id = "edda"
	scenes.conversation_return = "res://scenes/people.tscn"
	change_scene_to_file("res://scenes/conversation.tscn")
	await _arrive("conversation.tscn")
	var talk = current_scene
	talk.choose("story")
	var topics: Array = talk.reply_ids().filter(func(id): return String(id).begins_with("topic_"))
	talk.choose(topics[0])
	for fl in _floats():
		fl.queue_free()
	var before := int(social.get_relationship("edda")["trust"])
	talk.choose("decide_offer_help")
	var trust := int(social.get_relationship("edda")["trust"])
	await _frames(4)
	var meter := talk.find_child("TrustMeter", true, false) as Control
	check(trust > before and meter != null and float(meter.get_meta("frac")) < trust / 100.0 - 0.01,
		"trust won in a visit fills the bar from where it stood (%.2f toward %.2f)" % [float(meter.get_meta("frac")) if meter != null else -1.0, trust / 100.0])
	check(_floats().size() == 1 and not talk.log_text().contains("+%d" % (trust - before)), "a heart rises off their face, and no sum is shown")
	await _wait(1.0)
	check(is_equal_approx(float(meter.get_meta("frac")), trust / 100.0) and (talk.find_child("TrustNumber", true, false) as Label).text == str(trust),
		"and the bar and the number land on the new trust")
	# The People page shows what the visit changed.
	scenes.people_seen = {"edda": {"trust": before, "memories": 0}}
	scenes.people_tab = "people"
	change_scene_to_file("res://scenes/people.tscn")
	await _arrive("people.tscn")
	var bar := current_scene.find_child("TrustBar", true, false) as Control
	check(bar != null and float(bar.get_meta("frac")) < trust / 100.0 - 0.01, "back on People, her trust is seen to have moved")
	check(int(scenes.people_seen["edda"]["trust"]) == trust, "and the page remembers what it has shown")
	await _wait(1.0)
	check(bar != null and is_instance_valid(bar) and is_equal_approx(float(bar.get_meta("frac")), trust / 100.0), "landing on what it is now")


# ---- the lord talk moves as the other talks do: they step in, their line is written out,
# their face answers what you say, Regard is seen to change, and leaving fades.
func _lord_talk(tap: InputEvent) -> void:
	var LordConversation = load("res://scripts/world/lord_conversation.gd")
	var LordTalk = load("res://scripts/world/lord_talk.gd")
	var l: Dictionary = {}
	for x in gs.world.lords:
		if not bool(x.get("ruler", false)) and String(x.get("state", "")) != "prisoner":
			l = x
			break
	var lid := int(l["id"])
	var lt = LordConversation.open(root, gs, lid, "road")
	await _frames(2)
	var lf := lt.get_node("Stage/Face") as TextureRect
	check(lf.modulate.a < 0.99, "a lord steps into the talk, fading up")
	var speech := lt._talk.get_node("Speech") as Label
	check(lt.writing() and speech.visible_characters >= 0 and speech.visible_characters < speech.text.length(),
		"a lord's line is written out (%d of %d)" % [speech.visible_characters, speech.text.length()])
	check(lt.has_reply("leave") and lt.speech_text() == speech.text, "nothing waits on it: the replies are there, and the line is whole to read")
	lt._tap(tap)
	check(not lt.writing() and speech.visible_characters == -1, "a tap finishes the lord's line")
	await _wait(0.6)
	check(is_equal_approx(lf.modulate.a, 1.0) and lt._face_off.length() < 0.5, "and they stand where they stand a moment later")
	var y0: float = lf.position.y
	await _wait(0.5)
	check(not is_equal_approx(lf.position.y, y0), "they breathe")
	# Their face answers what you say.
	var resting: Texture2D = lt._face_texture("")
	lt._show("\"Good.\"", [], [lt._leave_reply()], "warm", "nod")
	check(resting == null or (lf.texture != resting and lf.texture == lt._face_texture("warm")), "a line they like changes their face")
	check(resting == null or lt._face_texture("blink") != resting, "and there's a face with its eyes shut to blink with")
	lt._show("\"What else?\"", [], [lt._leave_reply()])
	check(lf.texture == resting, "the next line, they're themselves again")
	lt._show("\"Enough.\"", [], [lt._leave_reply()], "grim", "away")
	await _wait(0.5)
	check(lf.modulate.r < 0.9 and lt._face_off.x < -8.0, "refused, they turn away and stay turned")
	lt._show("\"What else?\"", [], [lt._leave_reply()])
	await _wait(0.5)
	check(lf.modulate.r > 0.99 and lt._face_off.length() < 0.5, "until the next thing said")
	# Regard is seen to change.
	for f in _floats():
		f.queue_free()
	gs.add_lord_relation(lid, 5)
	var now: int = LordTalk.regard(gs, l)
	lt._show("\"I'll remember it.\"", [], [lt._leave_reply()])
	await _frames(5)
	check(_floats().size() == 1, "Regard won in a talk rises off their face, once (%d)" % _floats().size())
	check(gs.regard_events.filter(func(e): return int(e["id"]) == lid).is_empty(), "and won't rise again on the page you go back to")
	await _wait(0.7)
	check((lt.get_node("Stage").find_child("RegardText", true, false) as Label).text == LordTalk.regard_text(now), "the chip counts to the new Regard")
	# Leaving: the host hears at once, the picture takes a moment.
	var heard := [false]
	lt.closed.connect(func(): heard[0] = true)
	lt._leave()
	check(heard[0] and is_instance_valid(lt) and not lt.is_queued_for_deletion(), "leaving tells the host at once, and fades")
	await _wait(0.4)
	check(not is_instance_valid(lt), "and is gone a moment later")
	# Reduced motion: all of it is simply there.
	sound.reduced_motion = true
	var still = LordConversation.open(root, gs, lid, "road")
	await _frames(2)
	var sf := still.get_node("Stage/Face") as TextureRect
	var words := still._talk.get_node("Speech") as Label
	check(is_equal_approx(sf.modulate.a, 1.0) and not still.writing() and words.visible_characters == -1, "under Reduced motion the lord and the line are there at once")
	var p0: Vector2 = sf.position
	await _wait(0.3)
	check(sf.position == p0 and sf.texture == still._face_texture(""), "and hold still")
	still._leave()
	check(still.is_queued_for_deletion(), "and leaving is a cut")
	sound.reduced_motion = false
	await _frames(2)


# ---- 10, 11. talk has a pulse; the dance, the wedding and the hall move
func _talk_and_scenes() -> void:
	var TalkView = load("res://scripts/ui/talk_view.gd")
	var tv = TalkView.new()
	root.add_child(tv)
	tv.setup(TalkView.room("common_room", "night"), "Test")
	tv.set_face("center", load("res://icon.svg") if ResourceLoader.exists("res://icon.svg") else ImageTexture.create_from_image(Image.create(8, 8, false, Image.FORMAT_RGBA8)))
	await _frames(2)
	var face: Control = tv.find_child("Face_center", true, false)
	check(face != null and face.modulate.a < 0.99, "someone coming into the scene fades and slides in")
	await _wait(0.5)
	check(is_equal_approx(face.modulate.a, 1.0), "and is there a moment later")
	check(tv.find_child("Firelight", true, false) != null, "a room after dark has firelight")
	var line: Control = tv.say("them", "Sit, and tell me what brings you to my hall at this hour.", "Lord")
	await _frames(2)
	var words := line.find_child("Words", true, false) as Label
	check(words.visible_characters >= 0 and words.visible_characters < words.text.length() and tv.writing(), "their words are written out (%d of %d)" % [words.visible_characters, words.text.length()])
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = false
	tv._tap(ev)
	check(words.visible_characters == -1 and not tv.writing(), "a tap finishes the line, and goes no further")
	var mine: Control = tv.say("you", "I came to talk.")
	check((mine.find_child("Words", true, false) as Label).visible_characters == -1, "your own words are there at once")
	sound.instant_text = true
	var quick: Control = tv.say("them", "Then talk.")
	check((quick.find_child("Words", true, false) as Label).visible_characters == -1, "with Text appears at once, theirs are too")
	sound.instant_text = false
	sound.reduced_motion = true
	var still: Control = tv.say("them", "As you wish.")
	check((still.find_child("Words", true, false) as Label).visible_characters == -1, "and under Reduced motion")
	sound.reduced_motion = false
	tv.queue_free()
	await _lord_talk(ev)
	await _romance_moves()
	await _painted_blink()
	# The wedding's bunting sways.
	var Dressing = load("res://scripts/ui/wedding_dressing.gd")
	var d = Dressing.new()
	d.size = Vector2(400, 300)
	root.add_child(d)
	await _wait(0.2)
	check(d._clock > 0.1, "the wedding's bunting and lanterns move with the breeze")
	sound.reduced_motion = true
	var c0: float = d._clock
	await _wait(0.2)
	check(is_equal_approx(d._clock, c0), "and hold still under Reduced motion")
	sound.reduced_motion = false
	d.queue_free()


# ---- 12. the battle's beats
func _battle_beats() -> void:
	var sc = await _battle()
	var Sim = load("res://scripts/battle/battle_sim.gd")
	var foe = null
	for sq in sc.sim.squads:
		if sq.team == Sim.ENEMY:
			foe = sq
			break
	sc._hitstop = 0.0
	sc._captain_down({"squad": foe, "pos": foe.average_pos()})
	check(sc._hitstop >= sc.CAPTAIN_HITSTOP - 0.001, "a captain's fall stops the field for a beat")
	change_scene_to_file("res://scenes/main_menu.tscn")
	await _frames(4)
