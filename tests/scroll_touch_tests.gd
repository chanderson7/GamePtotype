## A finger that starts a drag on a card, a panel or a button inside a scrolling page must
## still reach the page's ScrollContainer, or the page won't scroll from there. A press
## is pushed at each spot through the viewport, as a touch would be, and the check is
## whether the ScrollContainer behind it saw the press.
## godot --headless --path . --script res://tests/scroll_touch_tests.gd
extends SceneTree

const Cultures = preload("res://scripts/data/cultures.gd")
const Widgets = preload("res://scripts/ui/widgets.gd")

var failures := 0


func _init() -> void:
	_run.call_deferred()


func check(ok: bool, description: String) -> void:
	print("%s %s" % ["ok" if ok else "FAIL", description])
	if not ok:
		failures += 1


func _run() -> void:
	var gs = root.get_node("GameState")
	gs.persist = false
	gs.new_campaign(Cultures.VARDISH)
	change_scene_to_file("res://scenes/main_menu.tscn")
	await process_frame
	await process_frame
	var scene = current_scene
	for tab in ["camp", "companies", "bonds", "deeds"]:
		scene._on_tab(tab)
		await process_frame
		await process_frame
		var scroll := _scroll_of(scene)
		if scroll == null:
			check(false, "the Warband %s tab has a scrolling page" % tab)
			continue
		var cards := 0
		var buttons := 0
		for node in scroll.find_children("*", "Control", true, false):
			var c := node as Control
			if not c.is_visible_in_tree() or c.get_global_rect().size.x < 4.0:
				continue
			# Only spots inside the visible page can be touched: the rest is scrolled out of
			# view, under the bar at the bottom.
			var at := c.get_global_rect().get_center()
			if not scroll.get_global_rect().has_point(at):
				continue
			if c is PanelContainer:
				cards += 1
				check(_press_reaches(scroll, at), "a drag starting on a card (%s) on %s reaches the page" % [c.name, tab])
			elif c is BaseButton and buttons < 4:
				buttons += 1
				check(_press_reaches(scroll, at), "a drag starting on a button (%s) on %s reaches the page" % [c.name, tab])
		check(cards > 0, "the %s tab has cards to try" % tab)
	await _check_taps(scene)
	await _check_bond_talk(gs)
	print("Scroll touch failures: %d" % failures)
	quit(1 if failures else 0)


## Passing touches on must not cost a tap: a button still fires on a tap, and a card made
## tappable with Widgets.on_tap fires on a tap but not at the end of a drag.
func _check_taps(scene: Node) -> void:
	scene._on_tab("camp")
	await process_frame
	await process_frame
	var tab := scene.find_child("Tab_companies", true, false) as Button
	_tap_at(tab.get_global_rect().get_center(), Vector2.ZERO)
	await process_frame
	check(String(scene._tab) == "companies", "a tap on a tab button inside the page still switches the tab")

	var scroll := _scroll_of(scene)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(300, 120)
	var taps := [0]
	Widgets.on_tap(card, func(): taps[0] += 1)
	# Into the page's column, at the top (a MarginContainer would stack it under the rest).
	var column := scroll.find_children("*", "VBoxContainer", true, false)[0] as VBoxContainer
	column.add_child(card)
	column.move_child(card, 0)
	scroll.scroll_vertical = 0
	await process_frame
	await process_frame
	var at := card.get_global_rect().get_center()
	check(_press_reaches(scroll, at), "a card made tappable with on_tap still lets the page scroll")
	taps[0] = 0
	_tap_at(at, Vector2.ZERO)
	check(taps[0] == 1, "a tap on that card opens it")
	_tap_at(at, Vector2(0, Widgets.TAP_SLOP + 24))
	check(taps[0] == 1, "a drag that starts on that card doesn't open it")
	card.queue_free()


## A talk at the fire: a drag that starts on a speech bubble, a note or the button below
## them must scroll the talk.
func _check_bond_talk(gs) -> void:
	var a: Dictionary = gs.army[0]["captain"]
	var b: Dictionary = gs.army[1]["captain"]
	a["bonds"][str(b["id"])] = 25.0
	b["bonds"][str(a["id"])] = 25.0
	root.get_node("Scenes").active_bond_a_id = int(a["id"])
	root.get_node("Scenes").active_bond_b_id = int(b["id"])
	change_scene_to_file("res://scenes/bond_conversation.tscn")
	for i in 3:
		await process_frame
	var scroll := current_scene.find_child("Talk", true, false) as ScrollContainer
	var tried := 0
	for node in scroll.find_children("*", "Control", true, false):
		var c := node as Control
		var at := c.get_global_rect().get_center()
		if not c.is_visible_in_tree() or not scroll.get_global_rect().has_point(at):
			continue
		if c is PanelContainer or c is BaseButton:
			tried += 1
			check(_press_reaches(scroll, at), "a drag starting on %s in a talk at the fire scrolls the talk" % c.name)
	check(tried > 0, "the talk at the fire has bubbles to try")


## Press at `at`, move by `drag`, and release there: a tap when `drag` is zero.
func _tap_at(at: Vector2, drag: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = at
	down.global_position = at
	root.push_input(down, true)
	var to := at + drag
	if drag != Vector2.ZERO:
		var move := InputEventMouseMotion.new()
		move.button_mask = MOUSE_BUTTON_MASK_LEFT
		move.position = to
		move.global_position = to
		move.relative = drag
		root.push_input(move, true)
	var up := down.duplicate() as InputEventMouseButton
	up.pressed = false
	up.position = to
	up.global_position = to
	root.push_input(up, true)


func _scroll_of(scene: Node) -> ScrollContainer:
	for node in scene.find_children("*", "ScrollContainer", true, false):
		if (node as Control).is_visible_in_tree():
			return node
	return null


## Push a press at `at`, drag off and release (so no button fires), and say whether the
## ScrollContainer received the press. Positions are in the viewport's own coordinates:
## the headless window is too small for screen coordinates to land anywhere.
func _press_reaches(scroll: ScrollContainer, at: Vector2) -> bool:
	var seen := [false]
	var watch := func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			seen[0] = true
	scroll.gui_input.connect(watch)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = at
	down.global_position = at
	root.push_input(down, true)
	var away := Vector2(-200, -200)
	var move := InputEventMouseMotion.new()
	move.button_mask = MOUSE_BUTTON_MASK_LEFT
	move.position = away
	move.global_position = away
	move.relative = away - at
	root.push_input(move, true)
	var up := down.duplicate() as InputEventMouseButton
	up.pressed = false
	up.position = away
	up.global_position = away
	root.push_input(up, true)
	scroll.gui_input.disconnect(watch)
	return seen[0]
