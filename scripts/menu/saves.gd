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

const TAGS := {"own": ["Yours", Color("2a3a6c"), Color("a9c4ff"), "save"], "battle": ["Battle", Color("4a2420"), Color("ffb7ae"), "battle"],
	"arrival": ["Arrival", Color("253325"), Color("a8dc9a"), "keep"]}
const UNDONE_ICONS := {"time": "ride", "battle": "battle", "captain": "men", "rise": "renown", "letter": "mail"}
## The compare grid's rows, by the word save_slots gives them.
const ROW_ICONS := {"Day": "day", "Men": "men", "Silver": "silver", "Renown": "renown", "Food": "food"}
## Room for the bottom bar under the page, above the safe area.
const BAR_ROOM := 124.0
## Said of a save made by a newer version of the game, which this one won't load.
const NEWER := "Made with a newer version of Bannerfall. Update the game to load it."

var _overlay: Control
var _delete_armed := false
var _over_armed := false


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
	var insets := Style.safe_insets(get_viewport())
	var col := Page.frame(self, BAR_ROOM + float(insets["bottom"]))
	col.add_child(Style.label("Saves", 52, Style.BRASS))
	var bar := Widgets.bottom_bar(Widgets.back_button(_back), insets)
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	if GameState.ironman:
		col.add_child(Page.note("This is an Ironman campaign. The game saves as you go, and there's no going back."))
		add_child(bar)
		return
	col.add_child(Page.note("The game also keeps a save from just before each battle, and one from when you last entered a settlement.", Style.SMALL))
	col.add_child(_where_note())
	if GameState.has_campaign():
		col.add_child(_now_card())
	var mine := SaveSlots.own()
	# How many of your own there are, said once.
	var head := HBoxContainer.new()
	var title := Widgets.section("Your saves")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var count := Style.label("%d of %d" % [mine.size(), SaveSlots.MAX_OWN], Style.SMALL, Style.MUTED)
	count.name = "SpacesLeft"
	head.add_child(count)
	col.add_child(head)
	for e in mine:
		col.add_child(_row(e))
	var kept := SaveSlots.automatic()
	if not kept.is_empty():
		col.add_child(Widgets.section("Kept for you"))
		for e in kept:
			col.add_child(_row(e))
	add_child(bar)


## Where the saves are on this device, and how to carry a campaign to another.
func _where_note() -> Label:
	var text := "Your saves stay on this device."
	if OS.has_feature("ios"):
		text = "Your saves are in the Files app, under On My iPhone › Bannerfall. To move a campaign, copy campaign.json and the saves folder to the same place on the other device."
	elif OS.has_feature("pc"):
		text = "Your saves are in %s. To move a campaign, copy campaign.json and the saves folder to the same place on the other computer." % OS.get_user_data_dir()
	var l := Page.note(text, Style.SMALL)
	l.name = "WhereSavesLive"
	return l


## Whether `e` was saved by a newer version of the game (it's shown, but won't load).
func _newer(e: Dictionary) -> bool:
	return GameState.is_newer_save(int(e.get("version", 0)))


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
		words.add_child(Style.label("RIGHT NOW", Style.SMALL, Style.BRASS))
		words.add_child(_display(String(s["place_name"]), 34))
	else:
		var plain := HBoxContainer.new()
		plain.add_theme_constant_override("separation", 16)
		var rn := Style.label("RIGHT NOW", Style.SMALL, Style.BRASS)
		plain.add_child(rn)
		plain.add_child(Widgets.icon_value("mappin", String(s["place_name"]), Style.TEXT, Style.BODY))
		v.add_child(plain)
	var body := MarginContainer.new()
	for side in ["left", "right"]:
		body.add_theme_constant_override("margin_" + side, 20)
	v.add_child(body)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 14)
	body.add_child(bv)
	# The day, then the four numbers as Home shows them.
	bv.add_child(Widgets.icon_value("day", str(int(s["day"])), Style.TEXT, Style.BODY))
	bv.add_child(Widgets.tile_grid([
		Widgets.tile("men", str(int(s["men"])), ""),
		Widgets.tile("silver", Widgets.thousands(int(s["silver"])), ""),
		Widgets.tile("food", str(int(s["food"])), "days"),
		Widgets.tile("renown", str(int(s["renown"])), ""),
	], 4))
	var save := Page.button("Save here", _on_save_here, true)
	save.name = "SaveHere"
	if SaveSlots.spaces_left() == 0:
		save.disabled = true
		bv.add_child(save)
		bv.add_child(Page.note("Every space is used. Open one of your saves to save over it or delete it.", Style.SMALL))
	else:
		bv.add_child(save)
	return card


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
	b.disabled = _newer(e)
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
		var day := PanelContainer.new()
		day.add_theme_stylebox_override("panel", Style.box(Color(0.04, 0.05, 0.1, 0.85), Color(0, 0, 0, 0), 0, 8))
		day.position = Vector2(8, 64)
		day.mouse_filter = Control.MOUSE_FILTER_IGNORE
		day.add_child(Widgets.icon_value("day", str(int(s["day"]))))
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
	var where := "%s · %s" % [s["place_name"], SaveSlots.when(float(e["saved"]))]
	var wl := Style.label(where, Style.SMALL, Style.MUTED)
	wl.clip_text = true
	wl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	words.add_child(wl)
	if b.disabled:
		var newer := Style.label(NEWER, Style.SMALL, Style.ENEMY_LIGHT)
		newer.name = "NewerVersion"
		newer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		words.add_child(newer)
	var meta := HFlowContainer.new()
	meta.add_theme_constant_override("h_separation", 14)
	meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(meta)
	# The day sits on the picture; with no picture it leads the numbers.
	if not (Style.illustrations_on() and not scene.is_empty()):
		meta.add_child(Widgets.icon_value("day", str(int(s["day"]))))
	for pair in [["men", s["men"]], ["silver", s["silver"]], ["food", s.get("food", 0)], ["renown", s["renown"]]]:
		meta.add_child(Widgets.icon_value(String(pair[0]), Widgets.thousands(int(pair[1]))))
	if kind == SaveSlots.OWN:
		var more := Widgets.icon_button("menu", _options.bind(e), "Rename, save over or delete", "More")
		more.flat = true
		row.add_child(more)
	return b


func _tag(kind: String) -> Control:
	var t: Array = TAGS.get(kind, TAGS["own"])
	var c := Widgets.chip(String(t[0]), t[2], "", String(t[3]))
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return c


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
func _sheet(sheet_name: String, title: String) -> VBoxContainer:
	_close_sheet()
	var v := Widgets.sheet(self, title, sheet_name, func():
		_delete_armed = false
		_over_armed = false
		_overlay = null)
	_overlay = get_node(sheet_name)
	return v


func _close_sheet() -> void:
	_delete_armed = false
	_over_armed = false
	if _overlay != null and is_instance_valid(_overlay):
		var o := _overlay
		_overlay = null
		Widgets.close_sheet(o)
		# Gone at once, so a new sheet can take its name.
		if o.get_parent() == self:
			remove_child(o)


## What going back to `e` undoes, then the choice.
func _confirm(e: Dictionary) -> void:
	var then: Dictionary = e["summary"]
	var v := _sheet("GoBackSheet", "Go back?")
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
	var t := _display(String(e["name"]), 30)
	t.name = "GoBackTitle"
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hv.add_child(t)
	var sub := Style.label(SaveSlots.when(float(e["saved"])), Style.SMALL, Style.MUTED)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hv.add_child(sub)
	var now := SaveSlots.summary(GameState) if GameState.has_campaign() else then
	var diff := SaveSlots.changes(then, now)
	v.add_child(_compare(diff["rows"]))
	if not diff["undone"].is_empty():
		v.add_child(Widgets.section("Undone"))
		for u in diff["undone"]:
			v.add_child(_line(Widgets.icon_rect(String(UNDONE_ICONS.get(u[0], "back")), 30.0), String(u[1])))
	if not diff["back"].is_empty():
		v.add_child(Widgets.section("Back with you"))
		for c in diff["back"]:
			v.add_child(_line(CaptainArt.portrait(c["face"], Vector2(42, 54)), String(c["text"])))
	var go := Page.button("Go back", _load.bind(String(e["id"])), true)
	go.name = "GoBack"
	go.icon = Widgets.icon("revert")
	if _newer(e):
		go.disabled = true
		v.add_child(Page.note(NEWER, Style.SMALL, Style.ENEMY_LIGHT))
	v.add_child(go)
	var pair := HBoxContainer.new()
	pair.add_theme_constant_override("separation", 14)
	v.add_child(pair)
	var first := Page.button("Save now first", _save_then_load.bind(String(e["id"])))
	first.name = "SaveFirst"
	if SaveSlots.spaces_left() == 0 or not GameState.has_campaign() or _newer(e):
		first.disabled = true
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
		grid.add_child(Style.label(h, Style.SMALL, Style.MUTED))
	for r in rows:
		var key := String(ROW_ICONS.get(String(r[0]), ""))
		if key != "":
			var ic := Widgets.icon_rect(key, 30.0)
			ic.tooltip_text = String(r[0])
			grid.add_child(ic)
		else:
			grid.add_child(Style.label(String(r[0]), Style.SMALL, Style.MUTED))
		var now := Style.label(String(r[1]), Style.SMALL, Style.TEXT)
		now.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(now)
		grid.add_child(Style.label("→", Style.SMALL, Style.MUTED))
		var differs := String(r[1]) != String(r[2])
		var lower := String(r[2]).is_valid_int() and String(r[1]).is_valid_int() and int(r[2]) < int(r[1])
		# Better or worse reads by its shape as well as its colour: ▲ more then, ▼ less.
		var marked: bool = differs and String(r[0]) != "Day"
		var then_text: String = ("▼ " if lower else "▲ ") + String(r[2]) if marked else String(r[2])
		var then := Style.label(then_text, Style.SMALL, (Style.ENEMY_LIGHT if lower else Color("a8dc9a")) if marked else Style.TEXT)
		then.name = "Then_%s" % String(r[0])
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
	var v := _sheet("OptionsSheet", String(e["name"]))
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
	# Saving over loses what was there, so it asks for a second tap, as Delete does.
	var over := Page.button("Save over it", func(): pass)
	over.name = "Overwrite"
	over.pressed.connect(func():
		if not _over_armed:
			_over_armed = true
			over.text = "Tap again to save over"
			return
		SaveSlots.overwrite(GameState, id)
		_build())
	over.icon = Widgets.icon("save")
	over.disabled = not GameState.has_campaign()
	v.add_child(over)
	v.add_child(Page.note("Saving over puts where you are now in its place.", Style.SMALL))
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


# ---------------------------------------------------------------- loading

func _load(id: String) -> void:
	if SaveSlots.load_into(GameState, id):
		Scenes.go("res://scenes/world_map.tscn")
		return
	# Nothing was changed: say so rather than leave the tap unanswered.
	var e := SaveSlots.entry(id)
	var v := _sheet("CantLoadSheet", "Can't load this save")
	v.add_child(Page.note(NEWER if _newer(e) else "This save couldn't be read. Your campaign is as it was.", Style.SMALL))
	var ok := Page.button("Keep playing", _close_sheet)
	ok.name = "KeepPlaying"
	v.add_child(ok)
	ok.grab_focus.call_deferred()


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
