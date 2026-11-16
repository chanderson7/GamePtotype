## A feast, as a place: you walk into the host's hall and the herald calls your name.
## The hall is HallScene's, alive with HallLife (the hearth, the lanterns, the candles);
## the lords sit at its tables, the host at the high seat, each breathing and blinking, and
## marked when they've something for you. Tap one to sit with them (the hall talk). What
## you do (toast, gift, listen, dance, or a speech at your own table) is seen in the faces
## and the numbers that rise over them; now and then something happens in the hall
## (hall_moments.gd); and each night ends with what it changed. The rules are GameState's.
extends Control

const Style = preload("res://scripts/ui/style.gd")
const Widgets = preload("res://scripts/ui/widgets.gd")
const CourtUI = preload("res://scripts/ui/court_ui.gd")
const Gatherings = preload("res://scripts/data/gatherings.gd")
const HallScene = preload("res://scripts/ui/hall_scene.gd")
const HallLife = preload("res://scripts/ui/hall_life.gd")
const TalkView = preload("res://scripts/ui/talk_view.gd")
const LordTalk = preload("res://scripts/world/lord_talk.gd")
const LordVoice = preload("res://scripts/data/lord_voice.gd")
const LordPortrait = preload("res://scripts/art/lord_portrait.gd")
const CaptainArt = preload("res://scripts/ui/captain_art.gd")
const LordConversation = preload("res://scripts/world/lord_conversation.gd")
const CrownCourt = preload("res://scripts/world/crown_court.gd")
const Data = preload("res://scripts/world/world_data.gd")
const Heraldry = preload("res://scripts/ui/heraldry.gd")

## The hall's art, and the floor laid on below it for the near table: in hall pixels.
## A tall phone gets more floor, up to the most.
const HALL := Vector2(240, 150)
const STAGE_ROWS_MIN := 190.0
const STAGE_ROWS_MAX := 270.0
## What's kept below the hall for the feast's name, its line, the actions and the door.
const BELOW_MIN := 560.0
## Where the far (high) table stands, in hall pixels from the top, and how deep the near
## table is at the foot of the hall.
const FAR_TABLE := 104.0
const NEAR_DEEP := 22.0
## How large the guests sit (screen pixels to a portrait pixel, at a hall pixel of 3).
const FAR_SCALE := 1.2
const HOST_SCALE := 1.4
const NEAR_SCALE := 1.6
## How much of a seated guest shows above the table.
const FAR_SHOWS := 0.78
const NEAR_SHOWS := 0.7
const FAR_SEATS := 4
const NEAR_SEATS := 4

var g: Dictionary = {}
var place := ""
var culture := "vardish"
var _k := 3.0
var _rows := STAGE_ROWS_MIN
var _t := 0.0
var _still := false
var _stage: Control
var _far: Control
var _near: Control
var _marks: Control
var _floats: Control
var _guests := {}            # lord id -> {node, pic, lord, scale, expr, until, blink, wait, phase, base}
var _whisper: Control
var _title: Label
var _line: Label
var _chips: HFlowContainer
var _actions: GridContainer
var _rest: Button
var _leave: Button
var _overlay: Control
var _talk = null
var _tex := {}
var _moment: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Style.make_theme()
	_still = Style.motion_reduced()
	var w = GameState.world
	g = GameState.gathering_here() if w != null else {}
	if g.is_empty() or GameState.gathering_barred(g):
		_empty("The hall is dark tonight. There's no feast here now.")
		return
	place = String(g["place"])
	culture = String(g.get("culture", Data.culture_of(String(Data.settlement(place)["faction"]))))
	Sound.play_music("feast_" + culture)
	Sound.set_loop("feast_din")
	_build()
	if GameState.feast_needs_herald(g):
		_herald()
	else:
		GameState.feast_tally(g)


func _empty(text: String) -> void:
	var bg := ColorRect.new()
	bg.color = Style.NIGHT
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 24)
	add_child(v)
	var l := Style.label(text, Style.BODY, Style.MUTED)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	var b := Button.new()
	b.name = "Back"
	b.text = "Back"
	b.custom_minimum_size = Vector2(320, Style.TOUCH)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func(): Scenes.go(Scenes.feast_return))
	v.add_child(b)


# ---------------------------------------------------------------- the hall

func _build() -> void:
	for c in get_children():
		c.queue_free()
	_guests.clear()
	_overlay = null
	var view := get_viewport_rect().size
	var insets: Dictionary = Style.safe_insets(get_viewport())
	# A hall pixel: the hall's width across the screen, but never more than half its height.
	_k = minf(view.x / HALL.x, view.y * 0.5 / STAGE_ROWS_MIN)
	_rows = clampf(floorf((view.y - BELOW_MIN) / _k), STAGE_ROWS_MIN, STAGE_ROWS_MAX)
	var stage_h := roundf(_rows * _k)
	var bg := ColorRect.new()
	bg.color = Style.NIGHT
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_stage = Control.new()
	_stage.name = "Hall"
	_stage.position = Vector2.ZERO
	_stage.size = Vector2(view.x, stage_h)
	_stage.clip_contents = true
	add_child(_stage)
	var left := roundf((view.x - HALL.x * _k) * 0.5)
	var art := TextureRect.new()
	art.name = "HallArt"
	art.texture = _stage_texture()
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.position = Vector2(left, 0)
	art.size = Vector2(HALL.x * _k, stage_h)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(art)
	var life_box := Control.new()
	life_box.position = Vector2(left, 0)
	life_box.size = HALL * _k
	life_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(life_box)
	HallLife.over(life_box, culture)
	# The guests, the far table in front of the far row, the near row, the near table.
	_far = Control.new()
	_far.name = "FarRow"
	_far.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_far.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_far)
	var lords: Array = GameState.gathering_lords(g)
	var host_id := int(g.get("host_lord", -1))
	var host: Dictionary = {}
	var others: Array = []
	for l in lords:
		if int(l["id"]) == host_id:
			host = l
		else:
			others.append(l)
	# Half of them at the high table with the host, half at the near one.
	var far_n := mini(FAR_SEATS, int(ceil(others.size() / 2.0)))
	var near_n := mini(NEAR_SEATS, others.size() - far_n)
	if near_n < others.size() - far_n:
		far_n = mini(FAR_SEATS, others.size() - near_n)
	var far: Array = others.slice(0, far_n)
	var near: Array = others.slice(far_n, far_n + near_n)
	_seat_row(_far, far, host, FAR_TABLE, FAR_SCALE, FAR_SHOWS, view.x)
	_stage.add_child(_table(FAR_TABLE, 10.0, view.x, "FarTable"))
	_near = Control.new()
	_near.name = "NearRow"
	_near.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_near.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_near)
	# The more floor there is, the nearer (and larger) the near table's guests sit.
	var nearer := 1.0 + 0.6 * (_rows - STAGE_ROWS_MIN) / STAGE_ROWS_MIN
	_seat_row(_near, near, {}, _near_table(), NEAR_SCALE * nearer, NEAR_SHOWS, view.x)
	_stage.add_child(_table(_near_table(), NEAR_DEEP, view.x, "NearTable"))
	_names(far, host, near)
	_marks = Control.new()
	_marks.name = "Marks"
	_marks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_marks)
	_floats = Control.new()
	_floats.name = "Floats"
	_floats.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_floats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_floats)
	var more := others.size() - far_n - near_n
	if more > 0:
		var mb := Button.new()
		mb.name = "MoreGuests"
		mb.text = "+%d more" % more
		mb.position = Vector2(view.x - 170, stage_h - 70)
		mb.size = Vector2(150, 56)
		mb.pressed.connect(func(): Scenes.go(Scenes.feast_return))
		_stage.add_child(mb)
	# Which night, how many, on what footing: over the top of the hall.
	_chips = HFlowContainer.new()
	_chips.name = "FeastChips"
	_chips.position = Vector2(16, float(insets.get("top", 0.0)) + 12.0)
	_chips.size = Vector2(view.x - 32, 50)
	_chips.add_theme_constant_override("h_separation", 8)
	add_child(_chips)
	# Below the hall: the feast's name, a line of the room, what you can do, and the door.
	# At large text sizes it may run long: then it scrolls rather than spill off the screen.
	var big := _big_text()
	var scroll := ScrollContainer.new()
	scroll.name = "BelowScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.position = Vector2(20, stage_h + 14)
	scroll.size = Vector2(view.x - 40, view.y - stage_h - 14 - float(insets.get("bottom", 0.0)) - 16)
	add_child(scroll)
	var below := VBoxContainer.new()
	below.name = "Below"
	below.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	below.size_flags_vertical = Control.SIZE_EXPAND_FILL
	below.custom_minimum_size = Vector2(0, scroll.size.y)
	below.add_theme_constant_override("separation", 12)
	scroll.add_child(below)
	_title = Style.label(GameState.gathering_title(g), Style.LARGE, Color("f3d891"))
	_title.name = "FeastTitle"
	if Style.display_font() != null:
		_title.add_theme_font_override("font", Style.display_font())
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	below.add_child(_title)
	_line = Style.label("", Style.BODY, Style.TEXT)
	_line.name = "FeastLine"
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.custom_minimum_size = Vector2(0, 70)
	below.add_child(_line)
	# The deeds sit low, above the door, where a thumb finds them.
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	below.add_child(gap)
	_actions = GridContainer.new()
	_actions.name = "Actions"
	_actions.columns = 2 if big else 4
	_actions.add_theme_constant_override("h_separation", 10)
	_actions.add_theme_constant_override("v_separation", 10)
	below.add_child(_actions)
	var hint := Style.label("Tap a guest to sit with them.", Style.SMALL, Style.MUTED)
	hint.name = "FeastHint"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	below.add_child(hint)
	var door := BoxContainer.new()
	door.vertical = big
	door.add_theme_constant_override("separation", 12)
	below.add_child(door)
	_rest = Button.new()
	_rest.name = "Rest"
	_rest.custom_minimum_size = Vector2(0, Style.TOUCH)
	_rest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rest.pressed.connect(_on_rest)
	door.add_child(_rest)
	_leave = Button.new()
	_leave.name = "Leave"
	_leave.text = "Leave the hall"
	_leave.set_meta("back", true)
	_leave.custom_minimum_size = Vector2(0, Style.TOUCH)
	_leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Style.make_primary(_leave)
	_leave.pressed.connect(_on_leave)
	door.add_child(_leave)
	var night: int = GameState.world.gathering_night(g)
	_say(Gatherings.night_line(culture, night, String(g.get("reason", ""))))
	_refresh()


## The hall as HallScene paints it, with its floor carried on below for the near table.
func _stage_texture() -> Texture2D:
	var w = GameState.world
	var owner: String = w.owner_of(place)
	var flag := owner if Heraldry.REALM_SIZES.has(owner) else Heraldry.realm_of_culture(Data.culture_of(owner))
	var when := "night" if TalkView.time_word(w.hour) == "night" else "dusk"
	var hall: Image = HallScene.image(culture, flag, when, place.hash())
	var img := Image.create(int(HALL.x), int(_rows), false, Image.FORMAT_RGB8)
	img.blit_rect(hall, Rect2i(0, 0, int(HALL.x), int(HALL.y)), Vector2i.ZERO)
	for y in range(int(HALL.y), int(_rows)):
		var src := 141 + (y - int(HALL.y)) % 9
		img.blit_rect(hall, Rect2i(0, src, int(HALL.x), 1), Vector2i(0, y))
	return ImageTexture.create_from_image(img)


## Whether the text is set large (1.25x or more): the actions then go two to a row and the
## door's buttons one above the other.
func _big_text() -> bool:
	return Style.text_size(20) >= 25


func _near_table() -> float:
	return _rows - NEAR_DEEP


## Seat `row` (and `host` at the middle of it, larger) behind a table at `table` hall pixels.
func _seat_row(layer: Control, row: Array, host: Dictionary, table: float, scale: float, shows: float, width: float) -> void:
	var people := row.duplicate()
	if not host.is_empty():
		people.insert(people.size() / 2, host)
	if people.is_empty():
		return
	var unit := _k / 3.0
	var sizes := []
	var total := 0.0
	for l in people:
		var s := (HOST_SCALE if l == host else scale) * unit
		sizes.append(s)
		total += LordPortrait.W * s * 0.74
	# Squeeze them in if the row is wider than the hall.
	var squeeze := minf(1.0, (width - 24.0) / (total + LordPortrait.W * sizes[0] * 0.26))
	var x := (width - total * squeeze - LordPortrait.W * float(sizes[-1]) * 0.26 * squeeze) * 0.5
	for i in people.size():
		var l: Dictionary = people[i]
		var s: float = float(sizes[i]) * squeeze
		var sz := Vector2(LordPortrait.W, LordPortrait.H) * s
		var top := table * _k - sz.y * shows - (14.0 * unit if l == host else 0.0)
		_seat(layer, l, Vector2(x, top), sz, s)
		x += LordPortrait.W * s * 0.74


func _seat(layer: Control, l: Dictionary, at: Vector2, sz: Vector2, s: float) -> void:
	var lid := int(l["id"])
	var b := Button.new()
	b.name = "Guest_%d" % lid
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.position = at
	b.size = sz
	b.tooltip_text = LordTalk.short_name(l)
	var none := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, none)
	b.pressed.connect(_sit_with.bind(lid))
	layer.add_child(b)
	var pic := TextureRect.new()
	pic.name = "Face"
	pic.texture = _face(l, "")
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.size = sz
	pic.pivot_offset = Vector2(sz.x * 0.5, sz.y)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(pic)
	_guests[lid] = {"node": b, "pic": pic, "lord": l, "scale": s, "expr": "", "until": 0.0,
		"wait": randf_range(1.5, 5.0), "blink": -1.0, "phase": randf_range(0.0, TAU)}


## A lord's face for the hall: their own portrait with no backdrop, so they sit in the room.
func _face(l: Dictionary, expr: String) -> Texture2D:
	var key := "%d|%s" % [int(l["id"]), expr]
	if _tex.has(key):
		return _tex[key]
	var tex: Texture2D = null
	var rec: Dictionary = LordVoice.portrait_record(l)
	if Style.illustrations_on() and LordPortrait.available():
		var img := LordPortrait.image(rec, false, expr)
		if img != null:
			tex = ImageTexture.create_from_image(img)
	if tex == null:
		tex = CaptainArt.texture(rec, expr)
	_tex[key] = tex
	return tex


## A table across the hall at `top` hall pixels, `deep` of them deep, set for the feast in
## the house's own way.
func _table(top: float, deep: float, width: float, id: String) -> Control:
	var t := Control.new()
	t.name = id
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.position = Vector2(0, top * _k)
	t.size = Vector2(width, deep * _k)
	t.draw.connect(_draw_table.bind(t))
	return t


## A table drawn in hall pixels: its top, its front, and what's set on it.
func _draw_table(t: Control) -> void:
	var k := _k
	var look := culture
	var cols: Array = {"kharzani": [Color("d9a944"), Color("7a2a24"), Color("4a1a14")],
		"ryumon": [Color("7a2418"), Color("5a1a14"), Color("3a1008")]}.get(look, [Color("8a5c34"), Color("6b4426"), Color("4a2e18")])
	t.draw_rect(Rect2(0, 0, t.size.x, 2.0 * k), cols[0])
	t.draw_rect(Rect2(0, 2.0 * k, t.size.x, t.size.y - 2.0 * k), cols[1])
	t.draw_rect(Rect2(0, 2.0 * k, t.size.x, 1.0 * k), cols[2])
	if look == "kharzani":
		for y in range(5, int(t.size.y / k), 5):
			for x in range(3, int(t.size.x / k), 8):
				t.draw_rect(Rect2(x * k, y * k, k, k), Color("d9a944"))
	# What's on the table, every so often along it.
	var n := int(t.size.x / k)
	var i := 0
	for x in range(4, n - 6, 14):
		i += 1
		match look:
			"kharzani":
				if i % 2 == 0:
					t.draw_rect(Rect2(x * k, -2.0 * k, 5.0 * k, 2.0 * k), Color("1f7a6e"))
					t.draw_rect(Rect2((x + 1) * k, -3.0 * k, k, k), Color("a8261c"))
					t.draw_rect(Rect2((x + 3) * k, -3.0 * k, k, k), Color("e8c547"))
				else:
					t.draw_rect(Rect2(x * k, -3.0 * k, 3.0 * k, 3.0 * k), Color("d9a944"))
					t.draw_rect(Rect2((x + 3) * k, -2.0 * k, k, k), Color("d9a944"))
			"ryumon":
				t.draw_rect(Rect2(x * k, -2.0 * k, 2.0 * k, 2.0 * k), Color("ece5d3"))
				if i % 3 == 0:
					t.draw_rect(Rect2((x + 4) * k, -4.0 * k, 2.0 * k, 4.0 * k), Color("ece5d3"))
					t.draw_rect(Rect2((x + 4) * k, -3.0 * k, 2.0 * k, k), Color("c8443c"))
			_:
				t.draw_rect(Rect2(x * k, -3.0 * k, 2.0 * k, 3.0 * k), Color("c8b080"))
				t.draw_rect(Rect2(x * k, -3.0 * k, 2.0 * k, k), Color("e8dcb8"))
				t.draw_rect(Rect2((x + 4) * k, -k, 5.0 * k, k), Color("b07a3a"))
				if i % 3 == 0:
					t.draw_rect(Rect2((x + 10) * k, -2.0 * k, 3.0 * k, 2.0 * k), Color("d9a060"))


## Each guest's first name on the table's edge in front of them.
func _names(far: Array, host: Dictionary, near: Array) -> void:
	for lid in _guests:
		var e: Dictionary = _guests[lid]
		var b: Control = e["node"]
		var l: Dictionary = e["lord"]
		var near_row := near.has(l)
		var y := (_near_table() if near_row else FAR_TABLE) * _k + 3.0 * _k
		var n := Style.label(LordTalk.first_name(l), Style.SMALL, Color("f3d891") if l == host else Style.TEXT)
		n.name = "Name_%d" % int(lid)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		n.add_theme_constant_override("outline_size", 6)
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		n.position = Vector2(b.position.x, y)
		n.size = Vector2(b.size.x, 30)
		_stage.add_child(n)


# ---------------------------------------------------------------- what's shown

func _refresh() -> void:
	if g.is_empty():
		return
	var w = GameState.world
	var mine: bool = GameState.gathering_is_mine(g)
	var inv: Dictionary = GameState.gathering_invite(g)
	for c in _chips.get_children():
		_chips.remove_child(c)
		c.queue_free()
	var night: int = w.gathering_night(g)
	_chips.add_child(Widgets.chip("Night %d of 3" % night, Style.TEXT, "", "moon"))
	_chips.add_child(Widgets.stat("men", "%d" % GameState.gathering_lords(g).size()))
	if mine:
		_chips.add_child(Widgets.chip("Your own", Style.BRASS, "", "crown", true))
	elif bool(inv["invited"]):
		_chips.add_child(Widgets.chip("Invited", Style.MORALE_HIGH))
	else:
		_chips.add_child(Widgets.chip("Uninvited", Style.MORALE_MID))
	_build_actions()
	_build_marks()
	var rest: Dictionary = GameState.feast_rest_check(g)
	_rest.visible = bool(rest["ok"]) and not bool(rest["last"])
	_rest.text = "Sleep till dusk"


func _build_actions() -> void:
	for c in _actions.get_children():
		_actions.remove_child(c)
		c.queue_free()
	if GameState.gathering_is_mine(g):
		var sp: Dictionary = CrownCourt.speech_check(GameState)
		_actions.add_child(_action("Speech", "Speech", "crown", "+%d Regard each" % Gatherings.SPEECH_REGARD, String(sp["reason"]), bool(sp["ok"]), _speech))
		var gc: Dictionary = CrownCourt.gifts_check(GameState)
		_actions.add_child(_action("KingGifts", "Gifts", "chest", "−%d silver" % int(gc.get("cost", 0)), String(gc["reason"]), bool(gc["ok"]), _kings_gifts))
	else:
		var toast: Dictionary = GameState.toast_check(g)
		_actions.add_child(_action("Toast", "Toast", "cup", "+%d Regard each" % Gatherings.TOAST_REGARD, String(toast["reason"]), bool(toast["ok"]), _toast))
		var gift: Dictionary = GameState.gift_check(g)
		var in_silver := String(gift.get("what", "silver")) != "food"
		_actions.add_child(_action("Gift", "Gift", "chest", "−%d %s" % [Gatherings.GIFT_SILVER if in_silver else Gatherings.GIFT_FOOD, "silver" if in_silver else "rations"],
			String(gift["reason"]), bool(gift["ok"]), _gift))
	var gossip: Dictionary = GameState.gossip_check(g)
	_actions.add_child(_action("Listen", "Listen", "talk", "an hour", String(gossip["reason"]), bool(gossip["ok"]), _listen))
	var dance: Dictionary = GameState.dance_check(g)
	var why := String(dance["reason"])
	if why == "it hasn't begun":
		why = "not yet"
	_actions.add_child(_action("Dance", "Dance", "dance", "the music starts", why, bool(dance["ok"]), _dance))


## One thing to do: an icon, a word, and under them what it brings or why not.
func _action(id: String, text: String, icon_key: String, gain: String, why_not: String, ok: bool, act: Callable) -> Button:
	var b := Button.new()
	b.name = "Feast_" + id
	b.disabled = not ok
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 136)
	var box := Style.box(Color("2a2010") if ok else Color(Style.PANEL, 0.7), Color("8a6a2a") if ok else Style.RULE, 2, 14)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, box)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 2)
	b.add_child(v)
	var ic := Widgets.icon_rect(icon_key, 40)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ic.modulate = Style.BRASS if ok else Style.MUTED
	v.add_child(ic)
	var t := Style.label(text, Style.BODY, Style.TEXT if ok else Style.MUTED)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var sub := Style.label(gain if ok else why_not, Style.SMALL - 2, Style.BRASS if ok else Style.MUTED)
	sub.name = "Sub"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.max_lines_visible = 2
	v.add_child(sub)
	b.pressed.connect(func():
		if _overlay == null and _talk == null:
			act.call())
	_fit_to_words(b)
	return b


## Over each guest's head: who hosts, a first word still to be had (+Regard), what you've
## heard about them, a lord who thinks ill of you. And a whisper where there's gossip.
func _build_marks() -> void:
	for c in _marks.get_children():
		_marks.remove_child(c)
		c.queue_free()
	_whisper = null
	var host_id := int(g.get("host_lord", -1))
	var marks: Dictionary = GameState.gathering_record(g)["marks"]
	for lid in _guests:
		var e: Dictionary = _guests[lid]
		var l: Dictionary = e["lord"]
		var b: Control = e["node"]
		var row := HBoxContainer.new()
		row.name = "Mark_%d" % int(lid)
		row.add_theme_constant_override("separation", 4)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if int(lid) == host_id and not GameState.gathering_is_mine(g):
			row.add_child(_mark("host", "crown", Style.BRASS, true))
		var bonus: int = GameState.first_word_bonus(l)
		if bonus > 0:
			row.add_child(_mark("+%d" % bonus, "talk", Style.BRASS, true))
		var heard := String(marks.get(str(int(lid)), ""))
		if heard != "":
			row.add_child(_mark("doubts" if heard.begins_with("sour") else "trouble", "eye", Style.PLAYER_LIGHT))
		if LordTalk.regard(GameState, l) <= -15:
			row.add_child(_mark("", "fight", Style.ENEMY_LIGHT))
		if row.get_child_count() == 0:
			row.free()
			continue
		_marks.add_child(row)
		var s: float = e["scale"]
		row.reset_size()
		row.position = Vector2(b.position.x + b.size.x * 0.5 - row.size.x * 0.5, b.position.y + 6.0 * s - 10.0)
	# Gossip to be had: two guests side by side with their heads together.
	if bool(GameState.gossip_check(g)["ok"]):
		var pair := _gossips()
		if not pair.is_empty():
			var a: Control = _guests[pair[0]]["node"]
			var c: Control = _guests[pair[1]]["node"]
			var bub := Button.new()
			bub.name = "Whisper"
			bub.text = "· · ·"
			bub.focus_mode = Control.FOCUS_NONE
			bub.add_theme_stylebox_override("normal", _bubble_box())
			bub.add_theme_stylebox_override("hover", _bubble_box())
			bub.add_theme_stylebox_override("pressed", _bubble_box())
			bub.custom_minimum_size = Vector2(72, 44)
			bub.mouse_filter = Control.MOUSE_FILTER_STOP
			_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bub.reset_size()
			# Between their heads, at the level of their eyes.
			var mid := (a.position.x + a.size.x + c.position.x) * 0.5
			var s: float = _guests[pair[0]]["scale"]
			bub.position = Vector2(mid - 36.0, minf(a.position.y, c.position.y) + 52.0 * s)
			bub.pressed.connect(func():
				if _overlay == null and _talk == null:
					_listen())
			_marks.add_child(bub)
			_whisper = bub


func _bubble_box() -> StyleBoxFlat:
	var sb := Style.box(Color(Style.NIGHT, 0.88), Style.RULE, 2, 18)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	return sb


## Two guests sitting side by side (never the host) to have their heads together: at the
## near table if two sit there, else at the high table.
func _gossips() -> Array:
	var host_id := int(g.get("host_lord", -1))
	for layer in [_near, _far]:
		var row := []
		for lid in _guests:
			if (_guests[lid]["node"] as Control).get_parent() == layer:
				row.append(lid)
		row.sort_custom(func(a, b): return (_guests[a]["node"] as Control).position.x < (_guests[b]["node"] as Control).position.x)
		for i in range(row.size() - 1, 0, -1):
			if int(row[i]) != host_id and int(row[i - 1]) != host_id:
				return [row[i - 1], row[i]]
	return []


func _mark(text: String, icon_key: String, tone: Color, gold := false) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := Style.box(Color("33290f") if gold else Color(Style.NIGHT, 0.9), tone, 2, 20)
	sb.content_margin_left = 8
	sb.content_margin_right = 10 if text != "" else 8
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	var ic := Widgets.icon_rect(icon_key, 24)
	ic.modulate = tone
	h.add_child(ic)
	if text != "":
		h.add_child(Style.label(text, Style.SMALL - 2, tone))
	return p


func _say(text: String, tone: Color = Style.TEXT) -> void:
	if _line == null:
		return
	_line.text = text
	_line.add_theme_color_override("font_color", tone)


## A number rising over a guest's head and fading: what a deed did to them.
func _float_over(lid: int, text: String, tone: Color) -> void:
	if not _guests.has(lid):
		return
	var b: Control = _guests[lid]["node"]
	_float_at(b.position + Vector2(b.size.x * 0.5, b.size.y * 0.42), text, tone)


func _float_at(at: Vector2, text: String, tone: Color) -> void:
	var l := Style.label(text, Style.LARGE, tone)
	l.name = "Float"
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 8)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(160, 44)
	l.position = at - Vector2(80, 22)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_floats.add_child(l)
	var tw := l.create_tween()
	if not _still:
		tw.tween_property(l, "position:y", l.position.y - 70.0, 1.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(l, "modulate:a", 0.0, 0.6).set_delay(1.0)
	else:
		tw.tween_interval(1.6)
	tw.tween_callback(l.queue_free)


## Show what a deed did: each guest whose Regard moved gets the change over their head.
func _show_changes(before: Dictionary) -> void:
	for lid in _guests:
		var l: Dictionary = _guests[lid]["lord"]
		var d := LordTalk.regard(GameState, l) - int(before.get(lid, LordTalk.regard(GameState, l)))
		if d != 0:
			_float_over(int(lid), "%+d" % d, Style.MORALE_HIGH if d > 0 else Style.MORALE_LOW)


func _regards() -> Dictionary:
	var out := {}
	for lid in _guests:
		out[lid] = LordTalk.regard(GameState, _guests[lid]["lord"])
	return out


## Guests wear `expr` for a while: laughing at a toast, warm at a gift.
func _react(ids: Array, expr: String, seconds: float = 1.8) -> void:
	for lid in ids:
		if not _guests.has(lid):
			continue
		var e: Dictionary = _guests[lid]
		e["expr"] = expr
		e["until"] = _t + seconds
		e["blink"] = -1.0
		(e["pic"] as TextureRect).texture = _face(e["lord"], expr)


func _process(delta: float) -> void:
	if g.is_empty():
		return
	_t += delta
	for lid in _guests:
		var e: Dictionary = _guests[lid]
		var pic: TextureRect = e["pic"]
		if String(e["expr"]) != "" and _t >= float(e["until"]):
			e["expr"] = ""
			pic.texture = _face(e["lord"], "")
		if _still:
			continue
		# They breathe.
		pic.position.y = roundf(sin(_t * 1.4 + float(e["phase"])) * float(e["scale"]))
		if String(e["expr"]) != "":
			continue
		# And blink: half shut, shut, half shut, open.
		if float(e["blink"]) < 0.0:
			e["wait"] = float(e["wait"]) - delta
			if float(e["wait"]) <= 0.0:
				e["blink"] = 0.0
		else:
			e["blink"] = float(e["blink"]) + delta
			var bt: float = e["blink"]
			var want := "/half" if bt < 0.04 or (bt >= 0.11 and bt < 0.15) else ("/shut" if bt < 0.11 else "")
			if bt >= 0.15:
				e["blink"] = -1.0
				e["wait"] = randf_range(2.4, 5.6)
			pic.texture = _face(e["lord"], want)


# ---------------------------------------------------------------- the herald

func _herald() -> void:
	var mine: bool = GameState.gathering_is_mine(g)
	var invited: bool = mine or bool(GameState.gathering_invite(g)["invited"])
	Sound.play("horn" if invited else "page")
	var o := _overlay_panel("Herald", "THE HERALD" if invited else "AT THE DOOR")
	var line := Style.label(GameState.feast_herald(g), Style.LARGE, Color("f3d891") if invited else Style.TEXT)
	line.name = "HeraldLine"
	if invited and Style.display_font() != null:
		line.add_theme_font_override("font", Style.display_font())
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	o.add_child(line)
	# Every head in the hall turns to the door.
	_react(_guests.keys(), "surprised" if invited else "grim", 1.4)
	if invited:
		var sub := Style.label(Gatherings.HERALD_SEEN, Style.BODY, Style.MUTED)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		o.add_child(sub)
		o.add_child(_overlay_button("GoIn", "Go in", true, _enter_hall))
		(_overlay.get_meta("veil") as Control).set_meta("close", _enter_hall)
	else:
		var sub := Style.label(Gatherings.HERALD_NOT_SEEN, Style.BODY, Style.MUTED)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		o.add_child(sub)
		o.add_child(_overlay_button("WalkIn", "Walk in anyway", true, _enter_hall))
		o.add_child(_overlay_button("TurnBack", "Turn back", false, func(): Scenes.go(Scenes.feast_return)))


func _enter_hall() -> void:
	GameState.feast_arrive(g)
	_close_overlay()
	_react(_guests.keys(), "warm", 1.2)


# ---------------------------------------------------------------- overlays

## A card over the hall, low on the screen, with a dim veil behind: the herald, a moment,
## the night's end. Returns the column to fill.
func _overlay_panel(id: String, kicker: String) -> VBoxContainer:
	_close_overlay()
	var o := Control.new()
	o.name = id
	o.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(o)
	var veil := ColorRect.new()
	veil.name = "Veil"
	veil.color = Color(0, 0, 0, 0.55)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	o.add_child(veil)
	o.set_meta("veil", veil)
	var insets: Dictionary = Style.safe_insets(get_viewport())
	var panel := PanelContainer.new()
	panel.name = "Card"
	var sb := Style.box(Color("161208"), Style.BRASS, 3, 22)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 22
	sb.content_margin_bottom = 26
	panel.add_theme_stylebox_override("panel", sb)
	# Low on the screen, above the door, growing upward with what it holds.
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 20.0
	panel.offset_right = -20.0
	panel.offset_bottom = -float(insets.get("bottom", 0.0)) - 30.0
	panel.offset_top = panel.offset_bottom
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	o.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	panel.add_child(v)
	var k := Style.label(kicker, Style.SMALL, Style.BRASS)
	k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(k)
	_overlay = o
	if not _still:
		panel.modulate.a = 0.0
		panel.create_tween().tween_property(panel, "modulate:a", 1.0, 0.25)
	return v


func _overlay_button(id: String, text: String, primary: bool, act: Callable, tag: String = "", ok: bool = true) -> Button:
	var b := Button.new()
	b.name = id
	b.disabled = not ok
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, Style.TOUCH + (28 if tag != "" else 0))
	if primary:
		Style.make_primary(b)
	if tag == "":
		b.text = text
	else:
		var v := VBoxContainer.new()
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", 0)
		b.add_child(v)
		var t := Style.label(text, Style.BODY, Style.BRASS_INK if primary else Style.TEXT)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(t)
		var s := Style.label(tag, Style.SMALL - 2, Color(Style.BRASS_INK, 0.75) if primary else (Style.BRASS if ok else Style.MUTED))
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(s)
	b.pressed.connect(act)
	_fit_to_words(b)
	return b


## A button holding its words in a box of their own grows to fit them as they wrap.
func _fit_to_words(b: Button) -> void:
	if b.get_child_count() == 0:
		return
	var v := b.get_child(0) as Control
	var base := b.custom_minimum_size.y
	v.minimum_size_changed.connect(func():
		if is_instance_valid(b):
			b.custom_minimum_size.y = maxf(base, v.get_combined_minimum_size().y + 16.0))


func _close_overlay() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null


# ---------------------------------------------------------------- deeds

## What you did: shown, then the hall may answer with a moment.
func _after(before: Dictionary) -> void:
	_show_changes(before)
	_refresh()
	var m: Dictionary = GameState.hall_moment(g)
	if not m.is_empty():
		_moment = m
		var t := get_tree().create_timer(0.3 if _still else 1.8)
		t.timeout.connect(func():
			if is_inside_tree() and _overlay == null and _talk == null:
				_show_moment(m))


func _toast() -> void:
	var before := _regards()
	var r: Dictionary = GameState.raise_toast(g)
	if not bool(r.get("ok", false)):
		_refresh()
		return
	Sound.play("cups")
	Sound.play("cheer", -6.0)
	_react(_guests.keys(), "laugh", 1.8)
	_cup_rises("cup")
	_say(String(r["text"]), Color("f3d891"))
	_after(before)


func _gift() -> void:
	var before := _regards()
	var realm_word: String = GameState.realm_word(String(g["realm"]))
	var r: Dictionary = GameState.bring_gift(g)
	if not bool(r.get("ok", false)):
		_refresh()
		return
	Sound.play("coins")
	var host_id := int(g.get("host_lord", -1))
	_react([host_id], "warm", 2.2)
	_cup_rises("chest", host_id)
	_say("%s: %s" % [GameState.gathering_host_name(g), String(r["text"])], Color("f3d891"))
	_float_at(Vector2(_stage.size.x * 0.5, _stage.size.y - 40.0), "%s %+d" % [realm_word, Gatherings.GIFT_REALM], Style.MORALE_HIGH)
	_after(before)


func _listen() -> void:
	var before := _regards()
	var pair := _gossips()
	var r: Dictionary = GameState.hear_gossip(g)
	if not bool(r.get("ok", false)):
		_refresh()
		return
	Sound.play("page")
	# The two with their heads together lean in.
	if pair.size() == 2 and not _still:
		var a: Control = _guests[pair[0]]["pic"]
		var b: Control = _guests[pair[1]]["pic"]
		for side in [[a, 0.07], [b, -0.07]]:
			var tw := (side[0] as Control).create_tween()
			tw.tween_property(side[0], "rotation", float(side[1]), 0.35)
			tw.tween_interval(1.4)
			tw.tween_property(side[0], "rotation", 0.0, 0.4)
	_say("You listen. %s" % String(r["text"]), Style.PLAYER_LIGHT)
	_after(before)


func _dance() -> void:
	GameState.save_game()
	Scenes.dance_return = "res://scenes/feast.tscn"
	Scenes.go("res://scenes/dance.tscn")


func _speech() -> void:
	var before := _regards()
	var r: Dictionary = CrownCourt.speech(GameState)
	if not bool(r.get("ok", false)):
		_refresh()
		return
	Sound.play("horn")
	Sound.play("cheer", -6.0)
	_react(_guests.keys(), "proud", 2.0)
	_say(String(r["text"]), Color("f3d891"))
	_after(before)


func _kings_gifts() -> void:
	var before := _regards()
	var r: Dictionary = CrownCourt.give_gifts(GameState)
	if not bool(r.get("ok", false)):
		_refresh()
		return
	Sound.play("coins")
	_react(_guests.keys(), "warm", 2.0)
	_cup_rises("chest")
	_say(String(r["text"]), Color("f3d891"))
	_after(before)


## A cup (or the gift) rising from your place at the near table: to the host, or to all.
func _cup_rises(icon_key: String, to: int = -1) -> void:
	var ic := Widgets.icon_rect(icon_key, 64)
	ic.modulate = Style.BRASS
	ic.size = Vector2(64, 64)
	var start := Vector2(_stage.size.x * 0.5 - 32.0, _stage.size.y - 80.0)
	ic.position = start
	_floats.add_child(ic)
	var end := start + Vector2(0, -110)
	if _guests.has(to):
		var b: Control = _guests[to]["node"]
		end = b.position + Vector2(b.size.x * 0.5 - 32.0, b.size.y * 0.55)
	var tw := ic.create_tween()
	if _still:
		ic.position = end
		tw.tween_interval(1.2)
	else:
		tw.tween_property(ic, "position", end, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.5)
		tw.tween_property(ic, "modulate:a", 0.0, 0.4)
	tw.tween_callback(ic.queue_free)


## Sit with a guest: the hall talk opens over the hall, and the hall shows what it changed.
func _sit_with(lid: int) -> void:
	if _overlay != null or _talk != null:
		return
	var before := _regards()
	Sound.play("page", -4.0)
	_talk = LordConversation.open(self, GameState, lid, "hall")
	_talk.closed.connect(func():
		_talk = null
		GameState.save_game()
		_after(before))


# ---------------------------------------------------------------- moments

func _show_moment(m: Dictionary) -> void:
	if m.is_empty() or not m.has("title"):
		return
	Sound.play("page")
	var v := _overlay_panel("Moment", "IN THE HALL")
	var lid := int(m.get("lord_id", -1))
	if lid >= 0 and _guests.has(lid):
		_react([lid], {"challenge": "amused", "insult": "tease", "news": "warm", "aside": "thoughtful"}.get(String(m["id"]), ""), 30.0)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	v.add_child(head)
	if lid >= 0:
		var l: Dictionary = GameState.world.lord_by_id(lid)
		if not l.is_empty():
			head.add_child(CourtUI.face(l, 96.0))
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 8)
	head.add_child(words)
	var title := Style.label(String(m["title"]), Style.LARGE, Color("f3d891"))
	if Style.display_font() != null:
		title.add_theme_font_override("font", Style.display_font())
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(title)
	var text := Style.label(String(m["text"]), Style.BODY, Style.TEXT)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(text)
	var first := true
	for c in m["choices"]:
		var ok := bool(c.get("ok", true))
		var tag := String(c.get("tag", "")) if ok else String(c.get("why", ""))
		v.add_child(_overlay_button("Choice_" + String(c["id"]), String(c["text"]), first and ok, choose_moment.bind(String(c["id"])), tag, ok))
		first = false


## Answer the moment on show (also for tests).
func choose_moment(choice: String) -> void:
	if _moment.is_empty():
		return
	var m := _moment
	var before := _regards()
	var r: Dictionary = GameState.hall_moment_choose(g, m, choice)
	if not bool(r.get("ok", false)):
		return
	_moment = {}
	_close_overlay()
	var lid := int(m.get("lord_id", -1))
	if lid >= 0:
		_react([lid], "", 0.0)
	if int(r.get("renown", 0)) != 0:
		Sound.play("cheer", -6.0)
		_float_at(Vector2(_stage.size.x * 0.5, _stage.size.y * 0.62), "%+d renown" % int(r["renown"]), Color("f3d891"))
	if int(r.get("silver", 0)) != 0:
		Sound.play("coins")
	# What the hall does: laughs at an answer, claps a song or a match, knocks its cups.
	var heard := String({"insult/answer": "laugh", "bard/stand": "applause", "bard/pass": "applause", "round/stand": "cups",
		"challenge/accept": "applause", "challenge/decline": "laugh"}.get("%s/%s" % [String(m["id"]), choice], ""))
	if heard != "":
		Sound.play(heard)
	if String(m["id"]) == "challenge" and choice == "accept":
		_react([lid], "laugh" if bool(r.get("won", false)) else "proud", 2.0)
	_show_changes(before)
	_refresh()
	if String(r.get("text", "")) != "":
		_say(String(r["text"]), Color("f3d891"))
	if int(r.get("talk", -1)) >= 0:
		_sit_with(int(r["talk"]))


# ---------------------------------------------------------------- the night's end

func _on_rest() -> void:
	if _overlay != null or _talk != null:
		return
	_night_end("Sleep until dusk", func():
		_close_overlay()
		var r: Dictionary = GameState.feast_rest(g)
		if not bool(r.get("ok", false)):
			_refresh()
			return
		if bool(r.get("stopped", false)):
			Scenes.go("res://scenes/world_map.tscn")
			return
		if bool(r.get("broken", false)):
			Scenes.go(Scenes.feast_return)
			return
		g = GameState.gathering_here()
		_build())


func _on_leave() -> void:
	if _talk != null:
		return
	if _overlay != null:
		return
	if g.is_empty():
		Scenes.go(Scenes.feast_return)
		return
	var s: Dictionary = GameState.feast_night_summary(g)
	if (s["lords"] as Array).is_empty() and int(s["renown"]) == 0 and int(s["silver"]) == 0 and int(s["food"]) == 0:
		GameState.save_game()
		Scenes.go(Scenes.feast_return)
		return
	_night_end("Leave the hall", func():
		GameState.save_game()
		Scenes.go(Scenes.feast_return))


## The night's tally: each face whose Regard moved, renown, what it cost. Then `go`.
func _night_end(go_text: String, go: Callable) -> void:
	var s: Dictionary = GameState.feast_night_summary(g)
	var night := int(s["night"])
	var v := _overlay_panel("NightEnd", "%s · NIGHT %d OF 3" % [GameState.gathering_title(g).to_upper(), maxi(1, night)])
	var lords: Array = s["lords"]
	if lords.is_empty() and int(s["renown"]) == 0:
		var quiet := Style.label(Gatherings.QUIET_NIGHT, Style.BODY, Style.MUTED)
		quiet.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		quiet.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(quiet)
	if not lords.is_empty():
		var faces := HFlowContainer.new()
		faces.name = "NightFaces"
		faces.alignment = FlowContainer.ALIGNMENT_CENTER
		faces.add_theme_constant_override("h_separation", 12)
		faces.add_theme_constant_override("v_separation", 10)
		v.add_child(faces)
		for e in lords:
			var l: Dictionary = GameState.world.lord_by_id(int(e["id"]))
			var cell := VBoxContainer.new()
			cell.add_theme_constant_override("separation", 2)
			cell.add_child(CourtUI.face(l, 76.0))
			var d := int(e["change"])
			var n := Style.label("%s %+d" % [LordTalk.first_name(l), d], Style.SMALL, Style.MORALE_HIGH if d > 0 else Style.MORALE_LOW)
			n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cell.add_child(n)
			faces.add_child(cell)
	var tiles := HBoxContainer.new()
	tiles.alignment = BoxContainer.ALIGNMENT_CENTER
	tiles.add_theme_constant_override("separation", 12)
	for t in [["renown", int(s["renown"])], ["silver", int(s["silver"])], ["food", int(s["food"])]]:
		if int(t[1]) != 0:
			tiles.add_child(Widgets.stat(String(t[0]), "%+d" % int(t[1]), Style.MORALE_HIGH if int(t[1]) > 0 else Style.MORALE_LOW))
	if tiles.get_child_count() > 0:
		v.add_child(tiles)
	var go_b := _overlay_button("NightGo", go_text, true, go)
	v.add_child(go_b)
	v.add_child(_overlay_button("NightStay", "Stay a while", false, _close_overlay))
	(_overlay.get_meta("veil") as Control).set_meta("close", _close_overlay)


# ---------------------------------------------------------------- for tests

## The lords seated in the hall, by id.
func guest_ids() -> Array:
	return _guests.keys()


## Press one of the hall's actions by its id ("Toast", "Gift", "Listen", "Dance", "Speech", "KingGifts").
func act(id: String) -> bool:
	var b := _actions.find_child("Feast_" + id, false, false) as Button if _actions != null else null
	if b == null or b.disabled:
		return false
	b.pressed.emit()
	return true


func moment() -> Dictionary:
	return _moment


func _exit_tree() -> void:
	Sound.set_loop("")
