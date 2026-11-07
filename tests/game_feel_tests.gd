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
