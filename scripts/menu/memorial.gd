## The fallen, remembered: the rise at the camp's edge where the company sets out a stone
## for each of its dead (MemorialScene, alive with MemorialLife), the ones not yet laid to
## rest, and the roll of every name. A stone or a name opens that captain's page: their
## face, their epitaph, what they did, where they fell, who killed them and what became of
## him, their last words, who mourns them; a candle to light. Gather the company lays the
## newly dead to rest: the closest friend speaks, the rite in the company's own way, and
## the words said over them, which become their epitaph. The rules are GameState's
## (memorial_gather, light_candle, memorial_epitaph, memorial_slayer, memorial_mourners).
extends Control

const Style = preload("res://scripts/ui/style.gd")
const Widgets = preload("res://scripts/ui/widgets.gd")
const CaptainArt = preload("res://scripts/ui/captain_art.gd")
const MemorialScene = preload("res://scripts/ui/memorial_scene.gd")
const MemorialLife = preload("res://scripts/ui/memorial_life.gd")
const MemorialLines = preload("res://scripts/data/memorial_lines.gd")
const HallScene = preload("res://scripts/ui/hall_scene.gd")
const TalkView = preload("res://scripts/ui/talk_view.gd")
const CampMoments = preload("res://scripts/data/camp_moments.gd")
const Data = preload("res://scripts/world/world_data.gd")

var _still := false
var _view := Vector2.ZERO
var _hill: Control
var _plate: Label
var _scroll: ScrollContainer
var _overlay: Control
var _page_id := -1
var _all_names := false
var _stones: Array = []        # the records shown on the hill, newest first


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Style.make_theme()
	_still = Style.motion_reduced()
	_view = get_viewport_rect().size
	Sound.play_music("lament_" + (GameState.culture if GameState.culture in ["vardish", "kharzani", "ryumon"] else "vardish"))
	_build()
	var focus := Scenes.memorial_focus
	Scenes.memorial_focus = -1
	if focus >= 0 and not GameState.memorial_of(focus).is_empty():
		# Asked for their gathering (the camp moment, the map's card): if they've not been laid
		# to rest, however their empty place was seen at the fire.
		if Scenes.memorial_gather and not bool(GameState.memorial_of(focus).get("mourned", true)):
			_gather(focus)
		else:
			_open_page(focus)
	Scenes.memorial_gather = false


func _company_banner() -> Array:
	var realm := Data.CROWN if GameState.is_crowned() else String(Data.realm_of_culture(GameState.culture))
	return HallScene.BANNERS.get(realm, HallScene.BANNERS["vardmark"])


func _stone_list() -> Array:
	var out: Array = []
	for i in range(GameState.fallen.size() - 1, -1, -1):
		var m = GameState.fallen[i]
		if typeof(m) == TYPE_DICTIONARY:
			out.append(m)
	return out


# ---------------------------------------------------------------- the memorial

func _build() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_overlay = null
	var insets: Dictionary = Style.safe_insets(get_viewport())
	var bg := ColorRect.new()
	bg.color = Style.NIGHT
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_stones = _stone_list()
	var place: Dictionary = MemorialLines.place(GameState.culture)
	var hill_h := roundf(minf(_view.y * 0.42, _view.x * 150.0 / 240.0 * 1.1))
	_hill = _hill_art(Vector2(_view.x, hill_h), 1.0)
	_hill.name = "Hill"
	add_child(_hill)
	# A stone to tap for each of the shown dead.
	var k := maxf(_view.x / 240.0, hill_h / 150.0)
	var off := (Vector2(_view.x, hill_h) - Vector2(240, 150) * k) * 0.5
	for i in mini(_stones.size(), MemorialScene.SHOWN):
		var m: Dictionary = _stones[i]
		var s := MemorialScene.spot(i)
		var base: Vector2 = off + (s["at"] as Vector2) * k
		var w := maxf(Style.TOUCH, 22.0 * float(s["scale"]) * k * 0.5)
		var hh := maxf(Style.TOUCH, 22.0 * float(s["scale"]) * k * 0.6)
		var b := Button.new()
		b.name = "Stone_%d" % int(m.get("id", 0))
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.position = base - Vector2(w * 0.5, hh)
		b.size = Vector2(w, hh)
		var none := StyleBoxEmpty.new()
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, none)
		b.tooltip_text = String(m.get("name", ""))
		b.pressed.connect(_on_stone.bind(int(m.get("id", 0)), base))
		_hill.add_child(b)
	_plate = Style.label("", Style.SMALL, Color("f3d891"))
	_plate.name = "StonePlate"
	_plate.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_plate.add_theme_constant_override("outline_size", 6)
	_plate.visible = false
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hill.add_child(_plate)
	var back_top := Button.new()
	back_top.name = "BackTop"
	back_top.text = "‹ Camp"
	back_top.flat = true
	back_top.position = Vector2(12, float(insets.get("top", 0.0)) + 8.0)
	back_top.custom_minimum_size = Vector2(140, Style.TOUCH)
	back_top.pressed.connect(_leave)
	add_child(back_top)
	# Below the hill: the place, those waiting to be laid to rest, the roll.
	_scroll = ScrollContainer.new()
	_scroll.name = "Roll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.position = Vector2(0, hill_h - 30)
	_scroll.size = Vector2(_view.x, _view.y - hill_h + 30 - float(insets.get("bottom", 0.0)))
	add_child(_scroll)
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 24)
	pad.add_theme_constant_override("margin_bottom", 24)
	_scroll.add_child(pad)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	pad.add_child(col)
	var n := _stones.size()
	col.add_child(Style.label(("THE FALLEN · %d REMEMBERED" % n) if n > 0 else "THE FALLEN", Style.SMALL, Style.BRASS))
	var title := Style.label(String(place["name"]), 44, Color("f3d891"))
	title.name = "PlaceName"
	if Style.display_font() != null:
		title.add_theme_font_override("font", Style.display_font())
	col.add_child(title)
	var line := Style.label(String(place["line"]) if n > 0 else String(place["empty"]), Style.BODY, Style.MUTED)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(line)
	for m in GameState.unmourned():
		col.add_child(_waiting_card(m))
	if n > 0:
		col.add_child(Widgets.section("The roll"))
	var shown := 0
	for m in _stones:
		if shown >= MemorialLines.ROLL_FOLD and not _all_names:
			break
		col.add_child(_roll_row(m))
		shown += 1
	if n > MemorialLines.ROLL_FOLD and not _all_names:
		var more := Button.new()
		more.name = "OlderNames"
		more.text = "Older (%d)" % (n - MemorialLines.ROLL_FOLD)
		more.custom_minimum_size = Vector2(0, Style.TOUCH)
		more.pressed.connect(func():
			_all_names = true
			_build())
		col.add_child(more)
	var back := Button.new()
	back.name = "Back"
	back.text = "Back to camp"
	back.custom_minimum_size = Vector2(0, Style.TOUCH)
	back.pressed.connect(_leave)
	col.add_child(back)


## The rise, `dim` (1 for full light), with its candles.
func _hill_art(sz: Vector2, dim: float) -> Control:
	var box := Control.new()
	box.size = sz
	box.clip_contents = true
	var unmourned: Array = GameState.unmourned()
	var fresh: bool = not _stones.is_empty() and not unmourned.is_empty() and int(unmourned[0].get("id", -1)) == int(_stones[0].get("id", -2))
	var marks: Array = _stones.map(func(m): return {"culture": String(m.get("culture", GameState.culture)), "hero": bool(m.get("is_hero", false))})
	var when := "dusk" if TalkView.time_word(GameState.world.hour if GameState.world != null else 20.0) in ["dusk", "afternoon"] else "night"
	var art := TextureRect.new()
	art.name = "HillArt"
	art.texture = MemorialScene.texture(GameState.culture, marks, fresh, when, _company_banner())
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.size = sz
	art.modulate = Color(dim, dim, dim + 0.04)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(art)
	var lit := []
	for i in mini(_stones.size(), MemorialScene.SHOWN):
		if GameState.candle_lit(_stones[i]):
			lit.append(i)
	MemorialLife.over(art, GameState.culture, lit)
	return box


## A stone tapped: its name on a plate over it; tapped again, their page.
func _on_stone(id: int, base: Vector2) -> void:
	if _overlay != null:
		return
	var m := GameState.memorial_of(id)
	if _plate.visible and _plate.get_meta("id", -1) == id:
		_open_page(id)
		return
	_plate.text = String(m.get("name", ""))
	_plate.set_meta("id", id)
	_plate.reset_size()
	_plate.position = Vector2(clampf(base.x - _plate.size.x * 0.5, 8.0, _view.x - _plate.size.x - 8.0), base.y - 120.0)
	_plate.visible = true
	Sound.play("page", -8.0)


func _face(m: Dictionary, w: float, mood: String = "/shut", dim: bool = true) -> Control:
	var tex: Texture2D = CaptainArt.texture(m, mood, w < 110.0)
	var pic := TextureRect.new()
	pic.name = "FacePic"
	pic.texture = tex
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return Widgets.framed(pic, Vector2(w, roundf(w * 1.25)), dim)


## One not yet laid to rest: their face, where they fell, and Gather the company.
func _waiting_card(m: Dictionary) -> Control:
	var id := int(m.get("id", 0))
	var p := PanelContainer.new()
	p.name = "Waiting_%d" % id
	var sb := Style.box(Color("2a2010"), Style.BRASS, 2, 14)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	p.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	p.add_child(h)
	h.add_child(_face(m, 80.0))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	h.add_child(v)
	var n := Style.label(String(m.get("name", "")), Style.BODY, Color("f3d891"))
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(n)
	var w := Style.label("Fell at %s · not yet laid to rest" % GameState.memorial_where(m), Style.SMALL, Style.MUTED)
	w.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(w)
	var g := Button.new()
	g.name = "Gather_%d" % id
	g.text = "Gather the company"
	g.custom_minimum_size = Vector2(0, Style.TOUCH)
	Style.make_primary(g)
	g.pressed.connect(_gather.bind(id))
	v.add_child(g)
	return p


## A name on the roll: dim face, name, company, battle and foes, avenged.
func _roll_row(m: Dictionary) -> Control:
	var id := int(m.get("id", 0))
	var b := Button.new()
	b.name = "Name_%d" % id
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 112)
	b.pressed.connect(_open_page.bind(id))
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.add_theme_constant_override("separation", 14)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var f := _face(m, 72.0)
	f.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(f)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var name_l := Style.label(String(m.get("name", "")) + ("  ★ avenged" if bool(m.get("avenged", false)) else ""), Style.BODY,
		Color("f3d891") if bool(m.get("is_hero", false)) else Style.TEXT)
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.custom_minimum_size = Vector2(10, 0)
	v.add_child(name_l)
	var sub := Style.label("%s · battle %d · %d foes" % [String(m.get("company", "the company")), int(m.get("battle", 0)), int(m.get("kills", 0))],
		Style.SMALL, Style.MUTED)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(10, 0)
	v.add_child(sub)
	if GameState.candle_lit(m):
		var ic := Widgets.icon_rect("fire", 26)
		ic.modulate = Color("ffcf6a")
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(ic)
	return b


func _leave() -> void:
	GameState.save_game()
	Scenes.go(Scenes.memorial_return)


# ---------------------------------------------------------------- a captain's page

func _overlay_base(id: String) -> VBoxContainer:
	_close_overlay()
	var o := Control.new()
	o.name = id
	o.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(o)
	_overlay = o
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.07)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.set_meta("close", _close_overlay)
	o.add_child(bg)
	var hill := _hill_art(Vector2(_view.x, roundf(_view.y * 0.3)), 0.55)
	hill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	o.add_child(hill)
	var insets: Dictionary = Style.safe_insets(get_viewport())
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.position = Vector2(0, float(insets.get("top", 0.0)))
	scroll.size = Vector2(_view.x, _view.y - float(insets.get("top", 0.0)) - float(insets.get("bottom", 0.0)))
	o.add_child(scroll)
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 24)
	pad.add_theme_constant_override("margin_top", 12)
	pad.add_theme_constant_override("margin_bottom", 24)
	scroll.add_child(pad)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	pad.add_child(col)
	if not _still:
		o.modulate.a = 0.0
		o.create_tween().tween_property(o, "modulate:a", 1.0, 0.25)
	return col


func _close_overlay() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
	_page_id = -1


func _open_page(id: int) -> void:
	var m := GameState.memorial_of(id)
	if m.is_empty():
		return
	_plate.visible = false
	Sound.play("page", -4.0)
	var col := _overlay_base("Page")
	_page_id = id
	var top := HBoxContainer.new()
	var back := Button.new()
	back.name = "PageBack"
	back.text = "‹ The roll"
	back.flat = true
	back.custom_minimum_size = Vector2(160, Style.TOUCH)
	back.pressed.connect(func():
		_close_overlay()
		_build())
	top.add_child(back)
	col.add_child(top)
	# Their face over their stone; tap it to see them as they were.
	var face := _face(m, 220.0)
	face.name = "PageFace"
	face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(face)
	var tap := Button.new()
	tap.name = "AsTheyWere"
	tap.flat = true
	tap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tap.tooltip_text = "As they were"
	var none := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus"]:
		tap.add_theme_stylebox_override(st, none)
	tap.pressed.connect(_as_they_were.bind(face, m))
	face.add_child(tap)
	var name_l := Style.label(String(m.get("name", "")), 44, Color("f3d891"))
	name_l.name = "PageName"
	if Style.display_font() != null:
		name_l.add_theme_font_override("font", Style.display_font())
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(name_l)
	var ep := Style.label("\"%s\"" % GameState.memorial_epitaph(m), Style.BODY, Color("e8d9b0"))
	ep.name = "Epitaph"
	ep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ep.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(ep)
	var hist: Dictionary = m.get("history", {}) if m.get("history") is Dictionary else {}
	var tiles := [Widgets.tile("fight", str(int(m.get("battles", 0))), "battles"), Widgets.tile("skull", str(int(m.get("kills", 0))), "foes")]
	var scars := (hist.get("scars", []) as Array).size() if hist.get("scars") is Array else 0
	tiles.append(Widgets.tile("wounded", str(scars), "scars"))
	if int(hist.get("tourneys", 0)) > 0:
		tiles.append(Widgets.tile("renown", str(int(hist["tourneys"])), "tourneys won", Style.BRASS))
	col.add_child(Widgets.tile_grid(tiles, 3))
	var day := GameState.memorial_day(m)
	var where := "Led %s for %d battle%s. Fell at %s, battle %d%s." % [String(m.get("company", "the company")), int(m.get("battles", 0)),
		"" if int(m.get("battles", 0)) == 1 else "s", GameState.memorial_where(m), int(m.get("battle", 0)), (", on day %d" % day) if day > 0 else ""]
	var wl := Style.label(where, Style.BODY, Style.TEXT)
	wl.name = "WhereTheyFell"
	wl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(wl)
	var sl: Dictionary = GameState.memorial_slayer(m)
	if not sl.is_empty():
		col.add_child(_slayer_row(sl))
	if String(m.get("words", "")) != "":
		var words := Style.label("\"%s\"" % String(m["words"]), Style.BODY, Style.BRASS)
		words.name = "LastWords"
		words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(Style.label("Their last words", Style.SMALL, Style.MUTED))
		col.add_child(words)
	var mourners: Array = GameState.memorial_mourners(m)
	if not mourners.is_empty():
		col.add_child(Widgets.section("Mourned by"))
		var row := HFlowContainer.new()
		row.name = "Mourners"
		row.add_theme_constant_override("h_separation", 12)
		row.add_theme_constant_override("v_separation", 10)
		for e in mourners:
			var c: Dictionary = e["captain"]
			var cell := Button.new()
			cell.name = "Mourner_%d" % int(c["id"])
			cell.flat = true
			cell.custom_minimum_size = Vector2(96, 150)
			cell.tooltip_text = "Sit with %s" % String(c.get("first", ""))
			var v := VBoxContainer.new()
			v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			v.mouse_filter = Control.MOUSE_FILTER_IGNORE
			v.add_theme_constant_override("separation", 2)
			cell.add_child(v)
			var f := _face(c, 80.0, "grief", false)
			f.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			v.add_child(f)
			var nl := Style.label("%s · %s" % [String(c.get("first", "")), String(e["rank"])], Style.SMALL, Style.TEXT)
			nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			v.add_child(nl)
			cell.pressed.connect(_sit_with.bind(int(c["id"]), id))
			row.add_child(cell)
		col.add_child(row)
	var acts := HBoxContainer.new()
	acts.add_theme_constant_override("separation", 12)
	var lit_today: bool = int(m.get("candle_day", -99)) == int(GameState.world.hour / 24.0) if GameState.world != null else false
	var candle := Button.new()
	candle.name = "LightCandle"
	var keep: Dictionary = MemorialLines.place(GameState.culture)
	candle.text = String(keep["lit"]) if lit_today else String(keep["light"])
	candle.disabled = lit_today
	candle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	candle.custom_minimum_size = Vector2(0, Style.TOUCH)
	if not lit_today:
		Style.make_primary(candle)
	candle.pressed.connect(_light.bind(id))
	acts.add_child(candle)
	var record := Button.new()
	record.name = "TheirRecord"
	record.text = "Their record"
	record.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	record.custom_minimum_size = Vector2(0, Style.TOUCH)
	record.pressed.connect(func():
		Scenes.active_captain_id = id
		Scenes.captain_profile_return = "res://scenes/memorial.tscn"
		Scenes.memorial_focus = id
		Scenes.go("res://scenes/captain_profile.tscn"))
	acts.add_child(record)
	col.add_child(acts)


## The lord who killed them: his banner and name, and what became of him; while he rides,
## a way to find him on the map.
func _slayer_row(sl: Dictionary) -> Control:
	var v := VBoxContainer.new()
	v.name = "Slayer"
	v.add_theme_constant_override("separation", 6)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	v.add_child(h)
	if String(sl.get("realm", "")) != "":
		h.add_child(Widgets.banner(String(sl["realm"]), Vector2(40, 56)))
	else:
		var sk := Widgets.icon_rect("skull", 36)
		sk.modulate = Style.ENEMY_LIGHT
		h.add_child(sk)
	var state := String(sl.get("state", ""))
	var what: String = {"rides": "still rides", "captive": "your captive", "taken": "a prisoner", "slain": "dead"}.get(state, "")
	if bool(sl.get("avenged", false)):
		what = "avenged"
	var l := Style.label("Struck down by %s · %s" % [String(sl.get("name", "")), what], Style.SMALL, Style.PLAYER_LIGHT if bool(sl.get("avenged", false)) else Style.ENEMY_LIGHT)
	l.name = "SlayerState"
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	if state == "rides" and String(sl.get("place", "")) != "" and not bool(sl.get("avenged", false)):
		var find := Button.new()
		find.name = "ShowOnMap"
		find.text = "Show on the map"
		find.custom_minimum_size = Vector2(0, Style.TOUCH)
		find.pressed.connect(func():
			GameState.save_game()
			Scenes.map_focus = String(sl["place"])
			Scenes.go("res://scenes/world_map.tscn"))
		v.add_child(find)
	return v


## Tap their face: for a moment, as they were.
func _as_they_were(face: Control, m: Dictionary) -> void:
	var pic := face.find_child("FacePic", true, false) as TextureRect
	if pic == null:
		return
	pic.texture = CaptainArt.texture(m, "proud")
	face.modulate = Color(1.15, 1.15, 1.15)
	var t := get_tree().create_timer(2.5)
	t.timeout.connect(func():
		if is_instance_valid(pic):
			pic.texture = CaptainArt.texture(m, "/shut")
			face.modulate = Color.WHITE)


func _light(id: int) -> void:
	if not GameState.light_candle(id):
		return
	# Each people's own light: a candle, a lamp, incense before the tablet.
	Sound.play("lamp_lit" if GameState.culture == "kharzani" else "candle")
	Sound.play("bell", -10.0)
	Sound.haptic(false)
	_build()
	_open_page(id)


func _sit_with(survivor_id: int, gone_id: int) -> void:
	GameState.save_game()
	Scenes.active_bond_a_id = survivor_id
	Scenes.active_bond_b_id = gone_id
	Scenes.bond_conversation_return = "res://scenes/memorial.tscn"
	Scenes.memorial_focus = gone_id
	Scenes.go("res://scenes/bond_conversation.tscn")


# ---------------------------------------------------------------- the gathering

var _gather_id := -1
var _gather_col: VBoxContainer
var _rite_art: Control


## Lay `id` to rest: the company gathers, the closest friend speaks, the rite, the words.
func _gather(id: int) -> void:
	var m := GameState.memorial_of(id)
	if m.is_empty():
		return
	_gather_id = id
	var place: Dictionary = MemorialLines.place(GameState.culture)
	Sound.play("bell", -8.0)
	var col := _overlay_base("Gathering")
	_overlay.name = "Gathering"
	_gather_col = col
	col.add_child(Style.label("LAYING %s TO REST" % String(m.get("first", m.get("name", ""))).to_upper(), Style.SMALL, Style.BRASS))
	var mourners: Array = GameState.memorial_mourners(m)
	# The company stands around the fresh earth.
	var row := HFlowContainer.new()
	row.name = "TheCompany"
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("h_separation", 8)
	var near := {}
	for e in mourners:
		near[int(e["captain"]["id"])] = true
	var count := 0
	for sq in GameState.army:
		var c = sq.get("captain")
		if not (c is Dictionary) or count >= 8:
			continue
		var f := _face(c, 70.0 if near.has(int(c["id"])) else 58.0, "grief" if near.has(int(c["id"])) else "sad", false)
		row.add_child(f)
		count += 1
	col.add_child(row)
	var friend = mourners[0]["captain"] if not mourners.is_empty() else CampMoments._mourner(GameState, m)
	var said := ""
	if friend is Dictionary:
		said = CampMoments.line_for("mourn", friend, CampMoments._captain_name(friend), String(m.get("first", m.get("name", ""))), GameState.battles)
	else:
		said = CampMoments.line("fallen", String(m.get("temperament", "")), String(m.get("first", m.get("name", ""))), "", GameState.battles)
	var said_l := Style.label(said, Style.BODY, Style.TEXT)
	said_l.name = "FriendSpeaks"
	said_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(said_l)
	_type_out(said_l)
	_rite_art = _Rite.new()
	_rite_art.name = "Rite"
	_rite_art.culture = GameState.culture
	_rite_art.custom_minimum_size = Vector2(0, 180)
	_rite_art.pennant = MemorialScene.PENNANTS.get(String(m.get("culture", GameState.culture)), MemorialScene.PENNANTS["vardish"])
	col.add_child(_rite_art)
	var rite := Button.new()
	rite.name = "Rite_go"
	rite.text = String(place["rite"])
	rite.custom_minimum_size = Vector2(0, Style.TOUCH)
	Style.make_primary(rite)
	rite.pressed.connect(_do_rite.bind(rite))
	col.add_child(rite)


## Words written out a little at a time; a tap anywhere finishes them.
func _type_out(l: Label) -> void:
	if _still:
		return
	l.visible_ratio = 0.0
	var t := l.create_tween()
	t.tween_property(l, "visible_ratio", 1.0, clampf(l.text.length() * 0.025, 0.6, 2.5))


func _do_rite(btn: Button) -> void:
	btn.disabled = true
	var place: Dictionary = MemorialLines.place(GameState.culture)
	var done := func():
		if not is_instance_valid(btn):
			return
		Sound.play("bell", -2.0)
		Sound.haptic(true)
		btn.queue_free()
		var l := Style.label(String(place["rite_done"]), Style.BODY, Color("e8d9b0"))
		l.name = "RiteDone"
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_gather_col.add_child(l)
		_words()
	if GameState.culture == "kharzani":
		Sound.play("lamp_lit")
	if _still:
		_rite_art.progress = 1.0
		_rite_art.queue_redraw()
		done.call()
		return
	var t := _rite_art.create_tween()
	t.tween_method(func(v: float):
		if is_instance_valid(_rite_art):
			var steps := int(v * 6.0)
			if steps > int(_rite_art.progress * 6.0) and GameState.culture != "kharzani":
				# A stone on the cairn; a mallet on the tablet.
				Sound.play("tablet" if GameState.culture == "ryumon" else "stone", -2.0, 0.08)
			_rite_art.progress = v
			_rite_art.queue_redraw(), 0.0, 1.0, 1.8)
	t.tween_callback(done)


## The words said over them: honour, grief, or (when a lord killed them) vengeance.
func _words() -> void:
	var m := GameState.memorial_of(_gather_id)
	var sl: Dictionary = GameState.memorial_slayer(m)
	var mourners: Array = GameState.memorial_mourners(m)
	var friend := String(mourners[0]["captain"].get("first", "")) if not mourners.is_empty() else ""
	_gather_col.add_child(Widgets.section("Words over them"))
	for key in ["honour", "grief", "vengeance"]:
		if key == "vengeance" and sl.is_empty():
			continue
		var w: Dictionary = MemorialLines.WORDS[key]
		var b := Button.new()
		b.name = "Words_%s" % key
		b.custom_minimum_size = Vector2(0, Style.TOUCH + 24)
		var v := VBoxContainer.new()
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(v)
		var t := Style.label(MemorialLines.words(key, GameState.memorial_where(m), friend, String(sl.get("name", ""))), Style.BODY, Style.TEXT)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(t)
		var tag := Style.label(String(w["tag"]), Style.SMALL - 2, Style.BRASS if key != "vengeance" else Style.ENEMY_LIGHT)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(tag)
		b.pressed.connect(say_words.bind(key))
		_gather_col.add_child(b)
	if not _still:
		await get_tree().process_frame
		for c in _overlay.get_children():
			if c is ScrollContainer:
				(c as ScrollContainer).scroll_vertical = 100000


## Say `key`'s words over them (also for tests): the epitaph is cut, a candle lit.
func say_words(key: String) -> void:
	var r: Dictionary = GameState.memorial_gather(_gather_id, key)
	if not bool(r.get("ok", false)):
		return
	Sound.play("bell", 0.0)
	if key == "vengeance":
		Sound.play_war_horn()
	var id := _gather_id
	_close_overlay()
	_build()
	_open_page(id)
	# What the gathering did, at the top of their page.
	var shared: Array = r.get("shared", [])
	var notes := PackedStringArray()
	notes.append(String(MemorialLines.place(GameState.culture)["laid"]))
	for pair in shared:
		notes.append("%s and %s are closer for it." % [String(pair[0]), String(pair[1])])
	if key == "vengeance":
		notes.append("The vow is in your journal.")
	var note := Style.label(" ".join(notes), Style.SMALL, Style.BRASS)
	note.name = "GatheringDone"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var page_col: VBoxContainer = null
	for c in _overlay.find_children("*", "VBoxContainer", true, false):
		page_col = c
		break
	if page_col != null:
		page_col.add_child(note)
		page_col.move_child(note, 1)


# ---------------------------------------------------------------- for tests

func stone_ids() -> Array:
	return _stones.slice(0, MemorialScene.SHOWN).map(func(m): return int(m.get("id", 0)))


func page_open() -> int:
	return _page_id


func gathering_open() -> bool:
	return _overlay != null and _overlay.name == "Gathering"


## The rite, drawn as it's done: a cairn stacked stone by stone, a lamp catching, a tablet
## set and incense rising. `progress` from 0 to 1.
class _Rite extends Control:
	var culture := "vardish"
	var progress := 0.0
	var pennant := Color("4a74d1")

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var k := maxf(3.0, roundf(size.y / 45.0))
		var base := Vector2(size.x * 0.5, size.y - 8.0)
		var px := func(x: float, y: float, w: float, h: float, c: Color):
			draw_rect(Rect2(base.x + x * k, base.y + y * k, w * k, h * k), c)
		# The fresh earth it stands on.
		px.call(-20, -2, 40, 2, Color("4a3424"))
		match culture:
			"kharzani":
				px.call(-5, -16, 10, 14, Color("e8e0cc"))
				for yy in 4:
					px.call(-4 + yy, -20 + yy, 8 - yy * 2, 1, Color("e8e0cc"))
				px.call(8, -5, 4, 3, Color("b08a3a"))
				if progress > 0.3:
					var g := clampf((progress - 0.3) / 0.7, 0.0, 1.0)
					draw_circle(Vector2(base.x + 10 * k, base.y - 7 * k), 10.0 * k * g, Color(1, 0.7, 0.3, 0.25 * g))
					px.call(9.5, -7, 1, 2, Color("ffcf6a"))
			"ryumon":
				var up := int(progress * 14.0)
				px.call(-2, -up, 4, up, Color("c8a878"))
				if up > 8:
					px.call(-2, -up + 3, 4, 2, pennant)
				if progress > 0.6:
					for i in 6:
						var a := (progress - 0.6) / 0.4
						px.call(8 + sin(i + progress * 6.0) * 1.5, -4 - i * 3 * a, 1, 1, Color(0.85, 0.85, 0.9, 0.5 * (1.0 - i / 6.0)))
					px.call(7, -3, 3, 2, Color("6a6a78"))
			_:
				var rows := int(progress * 6.0)
				for r in rows:
					var half := (6 - r) * 2
					px.call(-half, -2 - (r + 1) * 3, half * 2, 3, Color("8a8a96") if r % 2 == 0 else Color("6e6e7a"))
				if progress >= 1.0:
					px.call(0, -38, 1, 18, Color("6b4426"))
					px.call(1, -38, 7, 4, pennant)
