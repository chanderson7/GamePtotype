## Your saves: where you are now (save it here), your own saves, and the two the game
## keeps for you. Tapping one shows what going back to it would undo before it loads.
extends Control

const Page = preload("res://scripts/ui/menu_page.gd")
const Style = preload("res://scripts/ui/style.gd")
const Widgets = preload("res://scripts/ui/widgets.gd")
const SaveSlots = preload("res://scripts/save_slots.gd")
const SettlementVista = preload("res://scripts/ui/settlement_vista.gd")
const CaptainArt = preload("res://scripts/ui/captain_art.gd")
const Data = preload("res://scripts/world/world_data.gd")

const TAGS := {"own": ["Yours", Color("2a3a6c"), Color("a9c4ff")], "battle": ["Battle", Color("4a2420"), Color("ffb7ae")],
	"arrival": ["Arrival", Color("253325"), Color("a8dc9a")]}
const UNDONE_ICONS := {"time": "ride", "battle": "battle", "captain": "men", "rise": "renown", "letter": "mail"}

var _overlay: Control
var _delete_armed := false


func _ready() -> void:
	_build()
	var ask := Scenes.saves_confirm
	Scenes.saves_confirm = ""
	if ask != "":
		var e := SaveSlots.entry(ask)
		if not e.is_empty():
			_confirm(e)


func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_overlay = null
	if GameState.ironman:
		var c := Page.column(self, "Saves", "This is an Ironman campaign. The game saves as you go, and there's no going back.")
		c.add_child(Page.button("Back", _back, true))
		return
	var col := Page.column(self, "Saves", "The game also keeps a save from just before each battle, and one from when you last entered a settlement.")
	if GameState.has_campaign():
		col.add_child(_now_card())
	var mine := SaveSlots.own()
	var head := HBoxContainer.new()
	var title := Widgets.section("Your saves")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(Style.label("%d of %d" % [mine.size(), SaveSlots.MAX_OWN], Style.SMALL, Style.MUTED))
	col.add_child(head)
	for e in mine:
		col.add_child(_row(e))
	if SaveSlots.spaces_left() > 0:
		var empty := Page.note("%d more space%s for saves of your own" % [SaveSlots.spaces_left(), "" if SaveSlots.spaces_left() == 1 else "s"], Style.SMALL)
		empty.name = "SpacesLeft"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(empty)
	var kept := SaveSlots.automatic()
	if not kept.is_empty():
		col.add_child(Widgets.section("Kept for you"))
		for e in kept:
			col.add_child(_row(e))
	col.add_child(Page.button("Back", _back))


# ---------------------------------------------------------------- right now

func _now_card() -> Control:
	var s := SaveSlots.summary(GameState)
	var card := PanelContainer.new()
	card.name = "RightNow"
	var sb := Style.box(Style.PANEL, Color("6d5a2c"), 3, 22)
	sb.content_margin_bottom = 18
	card.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)
	var scene: Dictionary = s.get("scene", {})
	if Style.illustrations_on() and not scene.is_empty():
		var pic := SettlementVista.from_preset(scene, 220.0)
		pic.fade = true
		pic.name = "NowScene"
		v.add_child(pic)
		var words := VBoxContainer.new()
		words.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		words.offset_left = 22
		words.offset_top = -86
		words.offset_bottom = -10
		words.add_theme_constant_override("separation", 0)
		pic.add_child(words)
		words.add_child(Style.label("RIGHT NOW", 18, Style.BRASS))
		words.add_child(_display("Day %d · near %s" % [int(s["day"]), s["place_name"]], 34))
	else:
		v.add_child(Style.label("RIGHT NOW · Day %d · near %s" % [int(s["day"]), s["place_name"]], Style.BODY, Style.BRASS))
	var body := MarginContainer.new()
	for side in ["left", "right"]:
		body.add_theme_constant_override("margin_" + side, 20)
	v.add_child(body)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 14)
	body.add_child(bv)
	bv.add_child(Widgets.chip_row([_stat("men", str(int(s["men"]))), _stat("silver", str(int(s["silver"]))),
		_stat("food", "%dd" % int(s["food"])), _stat("renown", str(int(s["renown"])))]))
	var save := Page.button("Save here", _on_save_here, true)
	save.name = "SaveHere"
	if SaveSlots.spaces_left() == 0:
		save.disabled = true
		save.text = "All %d spaces are used" % SaveSlots.MAX_OWN
		bv.add_child(save)
		bv.add_child(Page.note("Tap ⋯ on one of your saves to save over it, or delete one.", Style.SMALL))
	else:
		bv.add_child(save)
	return card


## A rounded chip with an icon and a number.
func _stat(icon: String, value: String) -> Control:
	var panel := PanelContainer.new()
	var sb := Style.box(Style.RAISED, Style.RULE, 2, 40)
	sb.content_margin_left = 12
	sb.content_margin_right = 16
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	panel.add_child(h)
	h.add_child(Widgets.icon_rect(icon, 28.0))
	h.add_child(Style.label(value, Style.SMALL, Style.TEXT))
	return panel


func _on_save_here() -> void:
	if not SaveSlots.save_own(GameState).is_empty():
		_build()


# ---------------------------------------------------------------- a save

func _row(e: Dictionary) -> Control:
	var s: Dictionary = e["summary"]
	var kind := String(e["kind"])
	var b := Button.new()
	b.name = "Save_" + String(e["id"])
	b.custom_minimum_size = Vector2(0, 132)
	var sb := Style.box(Style.PANEL, Style.RULE, 2, 20)
	for k in ["normal", "hover", "pressed", "focus"]:
		var box := sb.duplicate() as StyleBoxFlat
		if k != "normal":
			box.border_color = Style.BRASS
		b.add_theme_stylebox_override(k, box)
	b.pressed.connect(_confirm.bind(e))
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 14
	row.offset_right = -8
	row.offset_top = 14
	row.offset_bottom = -14
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var scene: Dictionary = s.get("scene", {})
	if Style.illustrations_on() and not scene.is_empty():
		var pic := SettlementVista.from_preset(scene, 104.0)
		pic.custom_minimum_size = Vector2(226, 104)
		pic.size_flags_horizontal = 0
		row.add_child(pic)
		var day := Style.label(" Day %d " % int(s["day"]), 18, Style.TEXT)
		day.position = Vector2(8, 70)
		var tag := Style.box(Color(0.04, 0.05, 0.1, 0.85), Color(0, 0, 0, 0), 0, 8)
		day.add_theme_stylebox_override("normal", tag)
		pic.add_child(day)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 2)
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(words)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	words.add_child(line)
	var name := Style.label(String(e["name"]), Style.BODY, Style.TEXT)
	name.name = "SaveName"
	name.clip_text = true
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(name)
	if kind != SaveSlots.OWN:
		line.add_child(_tag(kind))
	var where := "%s · %02d:00 · %s" % [s["place_name"], int(s["hour"]) % 24, SaveSlots.when(float(e["saved"]))]
	var wl := Style.label(where, 20, Style.MUTED)
	wl.clip_text = true
	wl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	words.add_child(wl)
	var meta := HBoxContainer.new()
	meta.add_theme_constant_override("separation", 6)
	words.add_child(meta)
	for pair in [["men", s["men"]], ["silver", s["silver"]], ["renown", s["renown"]]]:
		meta.add_child(Widgets.icon_rect(String(pair[0]), 24.0))
		var n := Style.label(str(int(pair[1])) + "  ", 20, Style.TEXT)
		meta.add_child(n)
	if kind == SaveSlots.OWN:
		var more := Button.new()
		more.name = "More"
		more.text = "⋯"
		more.flat = true
		more.custom_minimum_size = Vector2(64, 64)
		more.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		more.add_theme_font_size_override("font_size", 34)
		more.pressed.connect(_options.bind(e))
		row.add_child(more)
	return b


func _tag(kind: String) -> Control:
	var t: Array = TAGS.get(kind, TAGS["own"])
	var l := Style.label(String(t[0]).to_upper(), 16, t[2])
	var box := Style.box(t[1], Color(0, 0, 0, 0), 0, 8)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	l.add_theme_stylebox_override("normal", box)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l


func _display(text: String, size: int) -> Label:
	var l := Style.label(text, size, Style.TEXT)
	var f: Font = Style.display_font()
	if f != null:
		l.add_theme_font_override("font", f)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	return l


# ---------------------------------------------------------------- sheets

## A sheet over the list, from the bottom; tapping the dimmed list closes it.
func _sheet(sheet_name: String) -> VBoxContainer:
	_close_sheet()
	_overlay = Control.new()
	_overlay.name = sheet_name
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.05, 0.66)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			_close_sheet())
	_overlay.add_child(dim)
	var stack := VBoxContainer.new()
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(stack)
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(gap)
	var panel := PanelContainer.new()
	var sb := Style.box(Style.PANEL, Style.RULE, 2, 36)
	sb.corner_radius_bottom_left = 0
	sb.corner_radius_bottom_right = 0
	sb.content_margin_left = 32
	sb.content_margin_right = 32
	sb.content_margin_top = 26
	sb.content_margin_bottom = 30 + Style.safe_insets(get_viewport())["bottom"]
	panel.add_theme_stylebox_override("panel", sb)
	stack.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	panel.add_child(v)
	if not Style.motion_reduced():
		Style.ease_in(panel)
	return v


func _close_sheet() -> void:
	_delete_armed = false
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null


## What going back to `e` undoes, then the choice.
func _confirm(e: Dictionary) -> void:
	var then: Dictionary = e["summary"]
	var v := _sheet("GoBackSheet")
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 20)
	v.add_child(head)
	var scene: Dictionary = then.get("scene", {})
	if Style.illustrations_on() and not scene.is_empty():
		var pic := SettlementVista.from_preset(scene, 108.0)
		pic.custom_minimum_size = Vector2(240, 108)
		pic.size_flags_horizontal = 0
		head.add_child(pic)
	var hv := VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(hv)
	var t := _display("Go back to Day %d?" % int(then["day"]), 36)
	t.add_theme_color_override("font_color", Style.BRASS)
	t.name = "GoBackTitle"
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hv.add_child(t)
	var sub := Style.label("%s · %s" % [e["name"], SaveSlots.when(float(e["saved"]))], 20, Style.MUTED)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hv.add_child(sub)
	var now := SaveSlots.summary(GameState) if GameState.has_campaign() else then
	var diff := SaveSlots.changes(then, now)
	v.add_child(_compare(diff["rows"]))
	if not diff["undone"].is_empty():
		v.add_child(Widgets.section("Undone"))
		for u in diff["undone"]:
			v.add_child(_line(Widgets.icon_rect(String(UNDONE_ICONS.get(u[0], "o_back")), 30.0), String(u[1])))
	if not diff["back"].is_empty():
		v.add_child(Widgets.section("Back with you"))
		for c in diff["back"]:
			v.add_child(_line(CaptainArt.portrait(c["face"], Vector2(42, 54)), String(c["text"])))
	var go := Page.button("Go back to Day %d" % int(then["day"]), _load.bind(String(e["id"])), true)
	go.name = "GoBack"
	v.add_child(go)
	var pair := HBoxContainer.new()
	pair.add_theme_constant_override("separation", 14)
	v.add_child(pair)
	var first := Page.button("Save now first", _save_then_load.bind(String(e["id"])))
	first.name = "SaveFirst"
	if SaveSlots.spaces_left() == 0 or not GameState.has_campaign():
		first.disabled = true
		first.text = "No space to save first"
	first.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pair.add_child(first)
	var keep := Page.button("Keep playing", _close_sheet)
	keep.name = "KeepPlaying"
	keep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pair.add_child(keep)
	keep.grab_focus.call_deferred()


func _compare(rows: Array) -> Control:
	var panel := PanelContainer.new()
	var sb := Style.box(Style.NIGHT, Style.RULE, 2, 18)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", sb)
	var grid := GridContainer.new()
	grid.name = "Compare"
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 8)
	panel.add_child(grid)
	for h in ["", "NOW", "", "THEN"]:
		grid.add_child(Style.label(h, 17, Style.MUTED))
	for r in rows:
		var name := Style.label(String(r[0]), Style.SMALL, Style.MUTED)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(name)
		var now := Style.label(String(r[1]), Style.SMALL, Style.TEXT)
		now.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(now)
		grid.add_child(Style.label("→", Style.SMALL, Style.MUTED))
		var differs := String(r[1]) != String(r[2])
		var lower := String(r[2]).is_valid_int() and String(r[1]).is_valid_int() and int(r[2]) < int(r[1])
		var then := Style.label(String(r[2]), Style.SMALL, (Style.ENEMY_LIGHT if lower else Color("a8dc9a")) if differs and r[0] != "Day" else Style.TEXT)
		then.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(then)
	return panel


func _line(pic: Control, text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pic)
	var l := Style.label(text, Style.SMALL, Style.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	return row


## Rename, save over, or delete one of your own saves.
func _options(e: Dictionary) -> void:
	var id := String(e["id"])
	var v := _sheet("OptionsSheet")
	var t := _display(String(e["name"]), 34)
	t.add_theme_color_override("font_color", Style.BRASS)
	v.add_child(t)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var field := LineEdit.new()
	field.name = "NameField"
	field.text = String(e["name"])
	field.max_length = 40
	field.custom_minimum_size = Vector2(0, Style.TOUCH)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(field)
	var rename := Page.button("Rename", func():
		if field.text.strip_edges() != "":
			SaveSlots.rename(id, field.text)
		_build())
	rename.name = "Rename"
	rename.autowrap_mode = TextServer.AUTOWRAP_OFF
	rename.custom_minimum_size = Vector2(170, Style.TOUCH)
	row.add_child(rename)
	field.text_submitted.connect(func(_t: String): rename.pressed.emit())
	var over := Page.button("Save over it with where you are now", func():
		SaveSlots.overwrite(GameState, id)
		_build())
	over.name = "Overwrite"
	over.disabled = not GameState.has_campaign()
	v.add_child(over)
	var del := Page.button("Delete", func(): pass)
	del.name = "Delete"
	del.add_theme_color_override("font_color", Style.ENEMY_LIGHT)
	del.pressed.connect(func():
		if not _delete_armed:
			_delete_armed = true
			del.text = "Tap again to delete"
			return
		SaveSlots.delete(id)
		_build())
	v.add_child(del)
	v.add_child(Page.button("Close", _close_sheet))


# ---------------------------------------------------------------- loading

func _load(id: String) -> void:
	if SaveSlots.load_into(GameState, id):
		Scenes.go("res://scenes/world_map.tscn")


func _save_then_load(id: String) -> void:
	if SaveSlots.save_own(GameState).is_empty():
		return
	_load(id)


func _back() -> void:
	Scenes.go(Scenes.saves_return)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _overlay != null:
			_close_sheet()
		else:
			_back()
		get_viewport().set_input_as_handled()
