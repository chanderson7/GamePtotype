## Changes screens with a quick fade through black (an autoload), so one screen never
## snaps into the next. Taps are held off while the screen is dark. Under Reduced motion
## the change is a plain cut.
##
## It also holds what every screen shares: a phone's back gesture arrives as Escape, so a
## screen handles both in one place; Escape that no screen used closes the sheet on top, or
## presses the page's Back; and on a computer F11 or Alt+Enter toggles full screen.
extends CanvasLayer

const OUT := 0.15
const IN := 0.25

## Return destinations for standalone help and settings pages.
var settings_return := "res://scenes/title.tscn"
var tutorial_return := "res://scenes/title.tscn"
var people_return := "res://scenes/world_map.tscn"
var saves_return := "res://scenes/title.tscn"
## The saves screen opens asking whether to go back to this save, once.
var saves_confirm := ""
## People & Letters opens on this tab, or straight to this letter, once.
var people_tab := ""
var people_letter := ""
## The map centres on this place when it next opens (then forgets it).
var map_focus := ""
## The last hour the map's clock showed, so time that passed out of sight sweeps by.
var map_clock_seen := -1.0
## The map opens the raid sheet for this village when it next opens (the town's Raid).
var map_raid := ""
## The people picked on Home, shown first on the new-campaign screen.
var new_campaign_pick := ""
var conversation_return := "res://scenes/settlement.tscn"
var personal_conversation_return := "res://scenes/people.tscn"
var captain_profile_return := "res://scenes/main_menu.tscn"
var bond_conversation_return := "res://scenes/main_menu.tscn"
var active_candidate_id := "edda"
var active_person_id := ""
## A shared visit to tell again when the talk opens (from the memory book), or "".
var romance_relive := ""
## What the People page last showed of each person you court or befriend (their trust and
## how many memories you keep), so what a visit changed is seen when you come back to it.
var people_seen := {}
## Where the wedding returns to, and the memory id to tell again ("" for the day itself).
var wedding_return := "res://scenes/world_map.tscn"
var wedding_replay := ""
## Where the dance at a gathering returns to.
var dance_return := "res://scenes/settlement.tscn"
var active_captain_id := -1
var active_bond_a_id := -1
var active_bond_b_id := -1
var warband_scroll := 0
var warband_sort := 0
## The Warband tab last open.
var warband_tab := "camp"
var settlement_scroll := 0
var settlement_place := ""
## Set only by the map's Enter action, so returning from a conversation does not replay
## the short arrival card.
var settlement_arrival_pending := false

var _veil: ColorRect
var _busy := false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_veil = ColorRect.new()
	_veil.color = Color(0.03, 0.04, 0.07, 0.0)
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veil)
	get_tree().node_added.connect(_let_scroll_through)
	_apply_fullscreen(Sound.fullscreen)


# ---------------------------------------------------------------- keys and back

## Android's back (with application/config/quit_on_go_back off, so it never quits the
## game) becomes an Escape press, which every screen already answers as "back".
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		for down in [true, false]:
			var k := InputEventKey.new()
			k.keycode = KEY_ESCAPE
			k.physical_keycode = KEY_ESCAPE
			k.pressed = down
			Input.parse_input_event(k)


func _input(event: InputEvent) -> void:
	if _ribbon != null and (event is InputEventMouseButton or event is InputEventScreenTouch) and event.is_pressed():
		_dismiss_ribbon(_ribbon)
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo or not OS.has_feature("pc"):
		return
	if k.keycode == KEY_F11 or (k.keycode == KEY_ENTER and k.alt_pressed):
		set_fullscreen(not Sound.fullscreen)
		get_viewport().set_input_as_handled()


## Escape that the screen itself didn't use (this autoload hears it last): close the sheet
## on top, or else press the page's Back. Battles keep their own Escape.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel") or _busy:
		return
	var cur := get_tree().current_scene
	if cur == null or cur.scene_file_path.ends_with("battle.tscn"):
		return
	var top: Control = null
	for n in cur.find_children("*", "ColorRect", true, false):
		if n.has_meta("close") and not n.has_meta("dismissed") and (n as Control).is_visible_in_tree():
			top = n as Control
	if top != null:
		(top.get_meta("close") as Callable).call()
		get_viewport().set_input_as_handled()
		return
	var back := _back_button(cur)
	if back != null:
		back.pressed.emit()
		get_viewport().set_input_as_handled()


## The page's way back: a visible, enabled button marked as one (Widgets.back_button marks
## its own; screens that build theirs set the "back" meta), or one simply named Back.
func _back_button(cur: Node) -> Button:
	for n in cur.find_children("*", "Button", true, false):
		var b := n as Button
		if (b.has_meta("back") or b.name == "Back") and b.is_visible_in_tree() and not b.disabled:
			return b
	return null


## Full screen on or off (computers only), remembered with the other settings.
func set_fullscreen(on: bool) -> void:
	Sound.set_fullscreen(on)
	_apply_fullscreen(on)


func _apply_fullscreen(on: bool) -> void:
	if not OS.has_feature("pc") or DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.window_get_mode()
	var full: bool = mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if full != on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)


## Inside a scrolling page, a finger that lands on a card, a panel or a button must still
## reach the page, or the page won't scroll from there. Godot's PanelContainer, Panel,
## buttons and plain backgrounds stop a touch by default, so every one added under a
## ScrollContainer passes it on instead. Buttons still work: they get the press first, and
## cancel it if the page starts to scroll (past the scroll deadzone in project.godot).
## Controls that need the drag themselves (sliders, scroll bars, text fields, lists) are
## left as they are.
func _let_scroll_through(node: Node) -> void:
	var c := node as Control
	if c == null or c.mouse_filter != Control.MOUSE_FILTER_STOP:
		return
	if c is Range or c is LineEdit or c is TextEdit or c is ScrollContainer or c is ItemList or c is Tree:
		return
	if not (c is PanelContainer or c is Panel or c is BaseButton or c is ColorRect or c is TextureRect
			or c is RichTextLabel or c.get_class() == "Control"):
		return
	var up := c.get_parent()
	while up != null:
		if up is ScrollContainer:
			c.mouse_filter = Control.MOUSE_FILTER_PASS
			return
		up = up.get_parent()


# ---------------------------------------------------------------- ribbons

## Moments worth a stamp (a deed, a captain ready for a role) drop in as a ribbon from the
## top of the screen, hold, and roll back up. They queue, and wait until no battle is on
## screen and no screen change is under way. Under Reduced motion they're simply there
## for the hold. The hold grows with the text size (bigger words take longer to read),
## and a tap puts the ribbon away at once. Each is {title, sub, icon, sound}.
const RIBBON_HOLD := 2.2
const RIBBON_IN := 0.32
const RIBBON_OUT := 0.25
var ribbons: Array = []
var _ribbon: Control = null


func ribbon(title: String, sub: String = "", icon_key: String = "renown", sound: String = "promotion") -> void:
	ribbons.append({"title": title, "sub": sub, "icon": icon_key, "sound": sound})
	set_process(true)


func _process(_delta: float) -> void:
	if ribbons.is_empty():
		set_process(false)
		return
	if _ribbon != null or _busy:
		return
	var cur := get_tree().current_scene
	if cur == null or cur.scene_file_path.ends_with("battle.tscn"):
		return
	var next: Dictionary = ribbons.pop_front()
	if bool(next.get("grand", false)):
		_show_moment(next)
	else:
		_show_ribbon(next)


## A turning point (a crown raised, a crown fallen) takes the whole screen for a breath:
## the light drops, a banner unfurls (or falls) over its words, and the light comes back.
## It waits its turn with the ribbons, and a tap sends it away at once. Under Reduced
## motion it is simply there for the hold.
const MOMENT_HOLD := 2.4


func moment(title: String, sub: String = "", banner: String = "crown", falls: bool = false, sound: String = "") -> void:
	ribbons.append({"grand": true, "title": title, "sub": sub, "banner": banner, "falls": falls, "sound": sound})
	set_process(true)


func _show_moment(r: Dictionary) -> void:
	var Style = load("res://scripts/ui/style.gd")
	var Widgets = load("res://scripts/ui/widgets.gd")
	var still: bool = Style.motion_reduced()
	var shade := ColorRect.new()
	shade.name = "Moment"
	shade.theme = Style.make_theme()
	shade.color = Color(0.02, 0.03, 0.07, 0.8)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# It holds the screen while it's up: the tap that sends it away presses nothing under it.
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 20)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.add_child(col)
	var flag_size := Vector2(150, 222)
	var pole := Control.new()
	pole.name = "Pole"
	pole.custom_minimum_size = flag_size
	pole.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pole.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(pole)
	var flag: Control = Widgets.banner(String(r.get("banner", "crown")), flag_size)
	flag.name = "Flag"
	flag.pivot_offset = Vector2(flag_size.x * 0.5, 0)
	pole.add_child(flag)
	var title: Label = Style.label(String(r["title"]), Style.TITLE_SIZE, Color("f3d891"))
	title.name = "MomentTitle"
	var display: Font = Style.display_font()
	if display != null:
		title.add_theme_font_override("font", display)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(title)
	var sub: Label = Style.label(String(r.get("sub", "")), Style.BODY, Style.TEXT)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.visible = sub.text != ""
	col.add_child(sub)
	add_child(shade)
	move_child(shade, _veil.get_index())
	_ribbon = shade
	if String(r.get("sound", "")) != "":
		Sound.play(String(r["sound"]), 0.0, 0.03)
	Sound.haptic(true)
	var falls := bool(r.get("falls", false))
	var tw := shade.create_tween()
	shade.set_meta("tween", tw)
	if not still:
		shade.modulate.a = 0.0
		title.modulate.a = 0.0
		sub.modulate.a = 0.0
		if not falls:
			flag.scale = Vector2(1, 0)
		tw.tween_property(shade, "modulate:a", 1.0, 0.3)
		if falls:
			# The banner hangs a moment, then comes down.
			tw.tween_property(title, "modulate:a", 1.0, 0.3)
			tw.parallel().tween_property(sub, "modulate:a", 1.0, 0.3)
			tw.tween_interval(0.4)
			tw.tween_property(flag, "position:y", 260.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(flag, "rotation", 0.22, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(flag, "modulate:a", 0.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		else:
			tw.tween_property(flag, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(title, "modulate:a", 1.0, 0.3)
			tw.parallel().tween_property(sub, "modulate:a", 1.0, 0.3).set_delay(0.15)
	elif falls:
		flag.modulate.a = 0.35
	tw.tween_interval(MOMENT_HOLD * maxf(1.0, float(Sound.text_scale)))
	if not still:
		tw.tween_property(shade, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func():
		shade.queue_free()
		_ribbon = null)


func _show_ribbon(r: Dictionary) -> void:
	var Style = load("res://scripts/ui/style.gd")
	var Widgets = load("res://scripts/ui/widgets.gd")
	var panel := PanelContainer.new()
	panel.name = "Ribbon"
	panel.theme = Style.make_theme()
	# Taps go through to whatever is under it (the map's top bar sits there); any tap, on it
	# or anywhere else, sends it on its way (see _input).
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: StyleBoxFlat = Style.box(Color("2a2210"), Style.BRASS, 3, 16)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 14
	panel.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	var ic: TextureRect = Widgets.icon_rect(String(r.get("icon", "renown")), 48.0)
	ic.modulate = Style.BRASS
	row.add_child(ic)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 2)
	row.add_child(words)
	var t: Label = Style.label(String(r["title"]), Style.BODY, Color("f3d891"))
	t.name = "RibbonTitle"
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(t)
	if String(r.get("sub", "")) != "":
		var sub: Label = Style.label(String(r["sub"]), Style.SMALL, Style.TEXT)
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		words.add_child(sub)
	add_child(panel)
	move_child(panel, _veil.get_index())
	var vw := get_viewport().get_visible_rect().size.x
	var insets: Dictionary = Style.safe_insets(get_viewport())
	# Its words wrap, so it's given its width (they'd squeeze it to a column otherwise).
	panel.custom_minimum_size.x = minf(vw - 32.0, 640.0)
	_ribbon = panel
	# Wrapped words know their height only once laid out: fit the ribbon after that.
	panel.modulate.a = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(panel):
		_ribbon = null
		return
	panel.size = Vector2(panel.custom_minimum_size.x, 0)
	panel.reset_size()
	panel.modulate.a = 1.0
	var rest_y := float(insets["top"]) + 14.0
	panel.position = Vector2((vw - panel.size.x) * 0.5, rest_y)
	if String(r.get("sound", "")) != "":
		Sound.play(String(r["sound"]), 0.0, 0.03)
	Sound.haptic(false)
	var tw := panel.create_tween()
	panel.set_meta("tween", tw)
	if not Style.motion_reduced():
		panel.position.y = -panel.size.y - 20.0
		tw.tween_property(panel, "position:y", rest_y, RIBBON_IN).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(RIBBON_HOLD * maxf(1.0, float(Sound.text_scale)))
	if not Style.motion_reduced():
		tw.tween_property(panel, "position:y", -panel.size.y - 20.0, RIBBON_OUT).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		panel.queue_free()
		_ribbon = null)


## A tapped ribbon goes at once, and the next in the queue may follow.
func _dismiss_ribbon(panel: Control) -> void:
	if not is_instance_valid(panel) or panel.is_queued_for_deletion():
		return
	var tw = (panel.get_meta("tween") if panel.has_meta("tween") else null)
	if tw is Tween and (tw as Tween).is_valid():
		(tw as Tween).kill()
	panel.queue_free()
	if _ribbon == panel:
		_ribbon = null


## Fade out, change to the scene at `path`, fade back in. Under Reduced motion, a cut.
func go(path: String) -> void:
	if _busy:
		return
	_busy = true
	if bool(Sound.reduced_motion):
		get_tree().change_scene_to_file(path)
		await get_tree().process_frame
		await get_tree().process_frame
		_busy = false
		return
	_veil.mouse_filter = Control.MOUSE_FILTER_STOP
	var out := create_tween()
	out.tween_property(_veil, "color:a", 1.0, OUT)
	await out.finished
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	var back := create_tween()
	back.tween_property(_veil, "color:a", 0.0, IN)
	await back.finished
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
