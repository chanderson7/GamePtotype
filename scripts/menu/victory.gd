## The Three Realms are one crown: the game's ending, told as a scene rather than a notice.
##
## First the three capitals (Highcliff, Khalun, Kurogane), painted as they stand, one
## above the other under their old banners; one by one each banner comes down and the
## crown's goes up, with a horn and a flash. Then the crown's banner unfurls large in a
## burst of light over the words "One Crown", and the music comes in. Last, the chronicle:
## how long, how many battles, the castles held and the lords sworn, the captains who
## rode to the end and the fallen remembered. Ride on goes back to the map: the campaign
## carries on. A tap hurries each part along; under Reduced motion it's all there at once.
extends Control

const Style = preload("res://scripts/ui/style.gd")
const Widgets = preload("res://scripts/ui/widgets.gd")
const CaptainArt = preload("res://scripts/ui/captain_art.gd")
const SettlementVista = preload("res://scripts/ui/settlement_vista.gd")
const SettlementScene = preload("res://scripts/ui/settlement_scene.gd")
const EventCards = preload("res://scripts/ui/event_cards.gd")
const Data = preload("res://scripts/world/world_data.gd")

const SWAP_EVERY := 1.3

var _still := false
var _view := Vector2.ZERO
var _capitals: Control
var _crowned: Control
var _seq: Array = []
var _phase := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Style.make_theme()
	_still = Style.motion_reduced()
	_view = get_viewport_rect().size
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.045, 0.035)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.gui_input.connect(_tap)
	add_child(bg)
	if GameState.world == null:
		_crown()
		return
	_three_capitals()
	if _still:
		_crown()


func _tap(e: InputEvent) -> void:
	if not ((e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed):
		return
	if _phase == 0:
		for t in _seq:
			if t is Tween and (t as Tween).is_valid():
				(t as Tween).kill()
		_seq.clear()
		_crown()


# ---------------------------------------------------------------- the three capitals

func _three_capitals() -> void:
	_capitals = Control.new()
	_capitals.name = "Capitals"
	_capitals.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_capitals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_capitals)
	var insets: Dictionary = Style.safe_insets(get_viewport())
	var top := float(insets.get("top", 0.0)) + 40.0
	var ids: Array = GameState.crown_capitals()
	var kick := Style.label(" · ".join(PackedStringArray(ids.map(func(id): return String(Data.settlement(id)["name"]).to_upper()))), Style.SMALL, Style.BRASS)
	kick.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kick.position = Vector2(0, top)
	kick.size = Vector2(_view.x, 40)
	_capitals.add_child(kick)
	var strip_h := floorf((_view.y - top - 120.0) / 3.0) - 12.0
	var y := top + 60.0
	var t := create_tween()
	_seq.append(t)
	t.tween_interval(0.6)
	for i in ids.size():
		var id := String(ids[i])
		var box := Control.new()
		box.name = "Capital_%s" % id
		box.clip_contents = true
		box.position = Vector2(0, y)
		box.size = Vector2(_view.x, strip_h)
		_capitals.add_child(box)
		var was := String(Data.settlement(id)["faction"])
		var after := _vista(id, Data.CROWN, box.size)
		box.add_child(after)
		var before := _vista(id, was, box.size)
		box.add_child(before)
		var fsz := Vector2(96, 140)
		var old := Widgets.banner(was, fsz)
		old.position = Vector2(_view.x - 130, 16)
		old.pivot_offset = Vector2(fsz.x * 0.5, 0)
		box.add_child(old)
		var rise := Widgets.banner(Data.CROWN, fsz)
		rise.name = "Crowned"
		rise.position = old.position
		rise.pivot_offset = Vector2(fsz.x * 0.5, 0)
		rise.scale = Vector2(1, 0)
		box.add_child(rise)
		var flash := ColorRect.new()
		flash.color = Color(1, 0.9, 0.6, 0.0)
		flash.size = box.size
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(flash)
		var name_l := Style.label(String(Data.settlement(id)["name"]), Style.LARGE, Color("f3d891"))
		if Style.display_font() != null:
			name_l.add_theme_font_override("font", Style.display_font())
		name_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		name_l.add_theme_constant_override("outline_size", 8)
		name_l.position = Vector2(24, strip_h - 56)
		box.add_child(name_l)
		# Its turn: the old banner comes down, the crown's goes up, the light flares.
		t.tween_property(old, "position:y", strip_h, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(old, "modulate:a", 0.0, 0.5)
		t.parallel().tween_property(before, "modulate:a", 0.0, 0.6)
		t.tween_callback(func():
			Sound.play("horn", -3.0 + i, 0.03)
			Sound.haptic(i == ids.size() - 1))
		t.tween_property(flash, "color:a", 0.45, 0.06)
		t.parallel().tween_property(rise, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(flash, "color:a", 0.0, 0.4)
		t.tween_interval(SWAP_EVERY - 1.0)
		y += strip_h + 12.0
	t.tween_interval(0.6)
	t.tween_callback(_crown)


func _vista(id: String, owner: String, sz: Vector2) -> Control:
	var p: Dictionary = SettlementScene.params(GameState.world, id)
	p["owner"] = owner
	p["player"] = ""
	p["condition"] = "healthy"
	var w := maxf(sz.x, sz.y * SettlementScene.W / SettlementScene.H)
	var v = SettlementVista.from_preset(p, sz.y)
	v.size = Vector2(w, sz.y)
	v.position = Vector2((sz.x - w) * 0.5, 0)
	v.custom_minimum_size = Vector2.ZERO
	v.visible = true
	return v


# ---------------------------------------------------------------- one crown

func _crown() -> void:
	if _phase >= 1:
		return
	_phase = 1
	if _capitals != null:
		if _still:
			_capitals.queue_free()
		else:
			var ft := _capitals.create_tween()
			ft.tween_property(_capitals, "modulate:a", 0.0, 0.5)
			ft.tween_callback(_capitals.queue_free)
	Sound.play("crown_fanfare")
	Sound.play_music("one_crown")
	Sound.haptic(true)
	var insets: Dictionary = Style.safe_insets(get_viewport())
	_crowned = Control.new()
	_crowned.name = "OneCrown"
	_crowned.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_crowned.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_crowned)
	var head_h := roundf(_view.y * 0.36)
	var head := Control.new()
	head.clip_contents = true
	head.size = Vector2(_view.x, head_h)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crowned.add_child(head)
	var rays = EventCards._Rays.new()
	rays.size = head.size
	rays.still = _still
	head.add_child(rays)
	var fsz := Vector2(190, 260)
	var flag := Widgets.banner(Data.CROWN, fsz)
	flag.name = "CrownBanner"
	flag.position = Vector2((_view.x - fsz.x) * 0.5, float(insets.get("top", 0.0)) + 30.0)
	flag.pivot_offset = Vector2(fsz.x * 0.5, 0)
	head.add_child(flag)
	var scroll := ScrollContainer.new()
	scroll.name = "Chronicle"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.position = Vector2(0, head_h - 40)
	scroll.size = Vector2(_view.x, _view.y - head_h + 40 - float(insets.get("bottom", 0.0)))
	_crowned.add_child(scroll)
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 28)
	pad.add_theme_constant_override("margin_bottom", 30)
	scroll.add_child(pad)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	pad.add_child(col)
	var title := Style.label("One Crown", 72, Color("f3d891"))
	title.name = "VictoryTitle"
	if Style.display_font() != null:
		title.add_theme_font_override("font", Style.display_font())
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	title.add_theme_constant_override("outline_size", 8)
	col.add_child(title)
	var crown_name := String(Data.title_case(GameState.crown_title())) if GameState.world != null else "Your crown"
	var sub := Style.label("%s rules the Three Realms. Highcliff, Khalun and Kurogane fly one banner: Vaskaria has one crown." % crown_name,
		Style.BODY, Style.TEXT)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(sub)
	col.add_child(_chronicle())
	col.add_child(_company())
	var fallen := _fallen()
	if fallen != null:
		col.add_child(fallen)
	var on := Style.label("The campaign carries on for as long as you like. Hold every castle and town on the map at once, and the company is remembered as Keepers of the Three Realms.",
		Style.SMALL, Style.MUTED)
	on.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	on.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(on)
	var ride := Button.new()
	ride.name = "RideOn"
	ride.text = "Ride on"
	ride.custom_minimum_size = Vector2(0, Style.TOUCH)
	ride.set_meta("back", true)
	Style.make_primary(ride)
	ride.pressed.connect(func():
		GameState.save_game()
		Scenes.go("res://scenes/world_map.tscn"))
	col.add_child(ride)
	if _still:
		return
	flag.scale = Vector2(1, 0)
	var t := flag.create_tween()
	t.tween_interval(0.3)
	t.tween_property(flag, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	title.modulate.a = 0.0
	title.pivot_offset = Vector2(_view.x * 0.5 - 28.0, 40)
	title.scale = Vector2(1.25, 1.25)
	var tt := title.create_tween().set_parallel()
	tt.tween_property(title, "modulate:a", 1.0, 0.3).set_delay(0.8)
	tt.tween_property(title, "scale", Vector2.ONE, 0.45).set_delay(0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var i := 0
	for c in col.get_children():
		if c == title:
			continue
		(c as CanvasItem).modulate.a = 0.0
		var ct := (c as Control).create_tween()
		ct.tween_interval(1.3 + i * 0.25)
		ct.tween_property(c, "modulate:a", 1.0, 0.4)
		i += 1


## The campaign in numbers.
func _chronicle() -> Control:
	var gs = GameState
	var days := int(gs.world.hour / 24.0) + 1 if gs.world != null else 0
	var holdings: int = gs.crown_holdings().size() if gs.world != null else 0
	var sworn: int = gs.crown_lords().size() if gs.world != null else 0
	var tiles := [
		Widgets.tile("day", str(days), "days"),
		Widgets.tile("fight", str(int(gs.battles)), "battles"),
		Widgets.tile("renown", Widgets.thousands(int(gs.renown)), "renown", Style.BRASS),
		Widgets.tile("keep", str(holdings), "held"),
		Widgets.tile("crown", str(sworn), "lords sworn", Style.BRASS),
		Widgets.tile("skull", str((gs.fallen as Array).size()), "fallen", Style.ENEMY_LIGHT),
	]
	var grid := Widgets.tile_grid(tiles, 3)
	grid.name = "ChronicleTiles"
	return grid


## The captains who rode to the end.
func _company() -> Control:
	var v := VBoxContainer.new()
	v.name = "TheCompany"
	v.add_theme_constant_override("separation", 10)
	v.add_child(Widgets.section("Rode to the end"))
	var row := HFlowContainer.new()
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("h_separation", 10)
	row.add_theme_constant_override("v_separation", 10)
	v.add_child(row)
	var shown := 0
	for sq in GameState.army:
		var c = sq.get("captain")
		if typeof(c) != TYPE_DICTIONARY or shown >= 8:
			continue
		row.add_child(_face(c, String(c.get("first", c.get("name", ""))), false, "proud"))
		shown += 1
	if shown == 0:
		row.add_child(Style.label("The company itself.", Style.SMALL, Style.MUTED))
	return v


## The fallen, remembered.
func _fallen() -> Control:
	var dead: Array = GameState.fallen
	if dead.is_empty():
		return null
	var v := VBoxContainer.new()
	v.name = "Remembered"
	v.add_theme_constant_override("separation", 10)
	v.add_child(Widgets.section("Remembered"))
	var row := HFlowContainer.new()
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("h_separation", 10)
	row.add_theme_constant_override("v_separation", 10)
	v.add_child(row)
	var newest := dead.slice(maxi(0, dead.size() - 8))
	newest.reverse()
	for m in newest:
		var cell := _face(m, String(m.get("first", m.get("name", ""))), true, "/shut")
		var tap := Button.new()
		tap.name = "Remember_%d" % int(m.get("id", 0))
		tap.flat = true
		tap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var none := StyleBoxEmpty.new()
		for st in ["normal", "hover", "pressed", "focus"]:
			tap.add_theme_stylebox_override(st, none)
		var mid := int(m.get("id", -1))
		tap.pressed.connect(func():
			GameState.save_game()
			Scenes.memorial_focus = mid
			Scenes.memorial_gather = false
			Scenes.memorial_return = "res://scenes/world_map.tscn"
			Scenes.go("res://scenes/memorial.tscn"))
		cell.add_child(tap)
		row.add_child(cell)
	if dead.size() > 8:
		var more := Style.label("and %d more" % (dead.size() - 8), Style.SMALL, Style.MUTED)
		more.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(more)
	return v


func _face(rec: Dictionary, label: String, dim: bool, mood: String) -> Control:
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", 2)
	var tex: Texture2D = CaptainArt.texture(rec, mood, true)
	if tex != null:
		var pic := TextureRect.new()
		pic.texture = tex
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		cell.add_child(Widgets.framed(pic, Vector2(72, 90), dim))
	var n := Style.label(label, Style.SMALL - 2, Style.MUTED if dim else Style.TEXT)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.custom_minimum_size = Vector2(72, 0)
	n.clip_text = true
	cell.add_child(n)
	return cell
