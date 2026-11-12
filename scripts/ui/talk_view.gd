## A conversation face to face: a stage (where you are, who you're talking to, a nameplate)
## over a running conversation (their lines on the left, yours on the right, narration in
## the middle) and the replies you can give. Romance talks and the captains' talks at the
## fire are built on it; a subclass fills it.
extends Control

const Style = preload("res://scripts/ui/style.gd")
const Widgets = preload("res://scripts/ui/widgets.gd")
const StoryArt = preload("res://scripts/ui/story_art.gd")
const PortraitLife = preload("res://scripts/ui/portrait_life.gd")

const STAGE_SHARE := 0.46

## How much of the screen the stage takes; a subclass lowers it while there's a lot to read.
var stage_share := STAGE_SHARE

signal closed

var stage: Control
var _backdrop: Control
var _plate: VBoxContainer
var _scroll: ScrollContainer
var _log: VBoxContainer
var _replies: VBoxContainer
var _continue: Callable
var _faces := {}
## Whose name is on the plate: their bubbles don't repeat it.
var _plate_name := ""
## Whether their lines are written out as they're added. A screen that lays an old
## exchange out again turns it off for the lines already heard.
var write_lines := true
## Faces breathe, and sway while they dance.
const BREATH := 3.6
## How much a painted face's whole picture swells with a breath.
const PAINTED_BREATH := 0.0012
var _clock := 0.0


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


## Lay out the screen with `backdrop` (a Control that fills the stage) and a caption.
func setup(backdrop: Control, caption: String) -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	theme = Style.make_theme()
	var bg := ColorRect.new()
	bg.color = Style.NIGHT
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	stage = Control.new()
	stage.name = "Stage"
	stage.clip_contents = true
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	_backdrop = backdrop
	if backdrop != null:
		backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(backdrop)
	var fade := TextureRect.new()
	fade.name = "Fade"
	var grad := Gradient.new()
	grad.set_color(0, Color(Style.NIGHT, 0.0))
	grad.set_color(1, Color(Style.NIGHT, 0.96))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 64
	fade.texture = gt
	fade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fade.stretch_mode = TextureRect.STRETCH_SCALE
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.anchor_right = 1.0
	fade.anchor_top = 0.6
	fade.anchor_bottom = 1.0
	stage.add_child(fade)
	var cap := PanelContainer.new()
	cap.name = "CaptionPanel"
	var cb := Style.box(Color(Style.NIGHT, 0.7), Color(0, 0, 0, 0), 0, 18)
	cb.content_margin_left = 16
	cb.content_margin_right = 16
	cap.add_theme_stylebox_override("panel", cb)
	cap.position = Vector2(20, 20)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.add_child(caption_row(caption))
	cap.visible = caption != ""
	stage.add_child(cap)
	stage.add_child(close_button(close))
	_plate = VBoxContainer.new()
	_plate.name = "Nameplate"
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.add_theme_constant_override("separation", 4)
	_plate.anchor_top = 1.0
	_plate.anchor_bottom = 1.0
	_plate.anchor_right = 1.0
	_plate.offset_left = 24
	_plate.offset_right = -24
	_plate.offset_top = -64
	_plate.offset_bottom = -12
	_plate.grow_vertical = Control.GROW_DIRECTION_BEGIN
	stage.add_child(_plate)
	# The conversation: a log that keeps what's been said, then the replies.
	_scroll = ScrollContainer.new()
	_scroll.name = "Talk"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.gui_input.connect(_tap)
	add_child(_scroll)
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_left", 22)
	pad.add_theme_constant_override("margin_right", 22)
	pad.add_theme_constant_override("margin_top", 12)
	pad.add_theme_constant_override("margin_bottom", 28)
	_scroll.add_child(pad)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 12)
	pad.add_child(col)
	_log = VBoxContainer.new()
	_log.name = "Log"
	_log.add_theme_constant_override("separation", 10)
	col.add_child(_log)
	_replies = VBoxContainer.new()
	_replies.name = "Replies"
	_replies.add_theme_constant_override("separation", 10)
	col.add_child(_replies)
	if not resized.is_connected(_layout):
		resized.connect(_layout)
	_layout()


## The faces on the stage are alive: a slow breath, a lean that a gesture set, and a sway
## while dancing. All of it through scale and rotation about their feet, so it never
## fights where the layout or a tween has put them. A painted face does more
## (PortraitLife): its head and hair move, and it blinks, glances and reacts. Still under
## Reduced motion.
func _process(delta: float) -> void:
	if _faces.is_empty():
		return
	if Style.motion_reduced():
		for side in _faces:
			_hold_still(side)
		return
	_clock += delta
	for side in _faces:
		_pose(side)
		if _faces[side].has("frames"):
			_live(side, delta)
		else:
			_blink(side, delta)


## A painted face, a moment on: the face it wears and how its head sits.
func _live(side: String, delta: float) -> void:
	var f: Dictionary = _faces[side]
	var face: TextureRect = f["node"]
	if face == null or not is_instance_valid(face) or not PortraitLife.wears(f, face.texture):
		return
	var now := PortraitLife.step(f, delta)
	if now["texture"] != null and face.texture != now["texture"]:
		face.texture = now["texture"]
	PortraitLife.pose(face, now)


## Under Reduced motion a painted face is as it was painted.
func _hold_still(side: String) -> void:
	var f: Dictionary = _faces[side]
	var face: TextureRect = f["node"]
	if face == null or not is_instance_valid(face) or not f.has("frames"):
		return
	if PortraitLife.wears(f, face.texture) and face.texture != f["rest"]:
		face.texture = f["rest"]
	PortraitLife.pose(face, PortraitLife.STILL)


## The face on `side` does what `kind` is ("brow", "nod", "glance", "soft"), if it's a
## painted face that can. Nothing under Reduced motion.
func life_act(side: String, kind: String) -> void:
	if _faces.has(side) and not Style.motion_reduced():
		PortraitLife.act(_faces[side], kind)


func _pose(side: String) -> void:
	var face: TextureRect = _faces[side]["node"]
	if face == null or not is_instance_valid(face):
		return
	var still := Style.motion_reduced()
	var lean := 1.0 if still else float(face.get_meta("lean", 1.0))
	# A painted face fills the stage and breathes in its head too (PortraitLife): its whole
	# picture swells less.
	var depth := PAINTED_BREATH if _faces[side].has("frames") else 0.004
	var breath := 0.0 if still else sin(_clock * TAU / BREATH + float(side.length())) * depth
	face.pivot_offset = Vector2(face.size.x * 0.5, face.size.y)
	face.scale = Vector2(lean, lean * (1.0 + breath))
	face.rotation = 0.0 if still else sin(_clock * 2.2) * float(face.get_meta("sway", 0.0))


## How long a blink keeps the eyes shut.
const BLINK_TIME := StoryArt.BLINK_TIME


## One tick of a blink's clock, kept in `state` ({wait, left}): "shut" when the eyes
## close now, "open" when they open again, "" between. One place for every face that
## blinks (the talks here, and the lord talk).
static func blink_step(state: Dictionary, delta: float) -> String:
	if float(state.get("left", 0.0)) > 0.0:
		state["left"] = float(state["left"]) - delta
		return "open" if float(state["left"]) <= 0.0 else ""
	state["wait"] = float(state.get("wait", 2.5)) - delta
	if float(state["wait"]) > 0.0:
		return ""
	state["wait"] = randf_range(2.6, 5.5)
	state["left"] = BLINK_TIME
	return "shut"


## A face can blink: `rest` is its resting picture and `shut` the same with its eyes
## closed. It blinks only while it wears `rest`. A face the game draws has one resting
## look (an expression has its own eyes); a painted portrait has a shut-eyed twin for
## every expression, found as each is put on (_painted_life). `talk` is the same face with
## its mouth open on a word: given one, it moves its mouth while its lines are written out.
func set_blink(side: String, rest: Texture2D, shut: Texture2D, half: Texture2D = null, talk: Texture2D = null) -> void:
	if not _faces.has(side) or rest == null or shut == null:
		return
	_faces[side]["rest"] = rest
	_faces[side]["shut"] = shut
	_faces[side]["half"] = half if half != null else shut
	if talk != null:
		_faces[side]["talk"] = talk
	else:
		_faces[side].erase("talk")
	if not _faces[side].has("blink"):
		_faces[side]["blink"] = {"wait": randf_range(1.2, 4.0), "left": 0.0}


## A painted portrait comes alive if its other faces were made (PortraitLife): it gets
## them, and the shader that moves its head and hair. Anything else loses both.
func _painted_life(side: String, tex: Texture2D) -> void:
	var f: Dictionary = _faces[side]
	var face: TextureRect = f["node"]
	if PortraitLife.attach(f, tex):
		var who := StoryArt.painted_who(tex)
		var dress := StoryArt.painted_dress(tex)
		if face.material == null or face.get_meta("life_of", "") != who + dress:
			face.material = StoryArt.life_material(who, dress)
			face.set_meta("life_of", who + dress)
	elif face.material != null and face.has_meta("life_of"):
		face.material = null
		face.remove_meta("life_of")


## A blink in two steps: half shut, shut, half shut, open.
func _blink(side: String, delta: float) -> void:
	var f: Dictionary = _faces[side]
	if not f.has("shut"):
		return
	var face: TextureRect = f["node"]
	if face == null or not is_instance_valid(face):
		return
	var state: Dictionary = f["blink"]
	var half: Texture2D = f.get("half", f["shut"])
	var talk: Texture2D = f.get("talk")
	if face.texture != f["rest"] and face.texture != f["shut"] and face.texture != half and (talk == null or face.texture != talk):
		state["left"] = 0.0
		return
	blink_step(state, delta)
	var left := float(state["left"])
	var want: Texture2D = f["rest"]
	var open := _mouth_moves(f, delta)
	if left > 0.0:
		var into := BLINK_TIME - left
		want = half if into < 0.03 or into > BLINK_TIME - 0.03 else f["shut"]
	elif open and talk != null:
		want = talk
	if face.texture != want:
		face.texture = want


## How long a mouth stays open on a word, and shut between words (seconds).
const MOUTH_OPEN := Vector2(0.08, 0.15)
const MOUTH_SHUT := Vector2(0.05, 0.1)


## The face on `side` talks while `writing` (a write_out tween) runs: its mouth opens and
## closes on the words, and stops when the line is whole (or tapped whole).
func speaking(side: String, writing) -> void:
	if not _faces.has(side) or not running(writing):
		return
	_faces[side]["saying"] = writing
	_faces[side]["flap"] = 0.0
	_faces[side]["mouth_open"] = false


## One tick of a talking mouth: whether it's open now.
func _mouth_moves(f: Dictionary, delta: float) -> bool:
	if not running(f.get("saying")):
		f.erase("saying")
		f["mouth_open"] = false
		return false
	f["flap"] = float(f.get("flap", 0.0)) - delta
	if float(f["flap"]) <= 0.0:
		var open := not bool(f.get("mouth_open", false))
		f["mouth_open"] = open
		f["flap"] = randf_range(MOUTH_OPEN.x, MOUTH_OPEN.y) if open else randf_range(MOUTH_SHUT.x, MOUTH_SHUT.y)
	return bool(f["mouth_open"])


## The colour of a face that is listening, not speaking.
const LISTENING := Color(0.62, 0.62, 0.7)


## Light the face on `side` (the one speaking) and dim the others; "" lights them all.
func spotlight(side: String) -> void:
	for s in _faces:
		var face := face_node(s)
		if face == null or not is_instance_valid(face):
			continue
		var to := Color.WHITE if side == "" or s == side else LISTENING
		var old = (face.get_meta("light") if face.has_meta("light") else null)
		if old is Tween and (old as Tween).is_valid():
			(old as Tween).kill()
		if Style.motion_reduced() or not is_inside_tree():
			face.self_modulate = to
		elif face.self_modulate != to:
			var t := face.create_tween()
			face.set_meta("light", t)
			t.tween_property(face, "self_modulate", to, 0.2)


## The face on `side`, or null.
func face_node(side: String) -> TextureRect:
	return _faces.get(side, {}).get("node")


## What their body does: "bounce" (a laugh), "lean" (in, and stays), "back" (they draw
## back, and stay), "" (as they were). Nothing under Reduced motion.
func gesture(side: String, kind: String) -> void:
	var face := face_node(side)
	if face == null or not is_instance_valid(face):
		return
	var to: float = {"lean": 1.035, "back": 0.965}.get(kind, 1.0)
	var old = (face.get_meta("lean_tween") if face.has_meta("lean_tween") else null)
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	if Style.motion_reduced() or not is_inside_tree():
		face.set_meta("lean", 1.0)
		_pose(side)
		return
	var from := float(face.get_meta("lean", 1.0))
	if not is_equal_approx(from, to):
		var step := func(v: float) -> void:
			face.set_meta("lean", v)
		var lt := face.create_tween()
		face.set_meta("lean_tween", lt)
		lt.tween_method(step, from, to, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if kind == "bounce":
		var prev = (face.get_meta("nudge") if face.has_meta("nudge") else null)
		if prev is Tween and (prev as Tween).is_valid():
			(prev as Tween).kill()
		_place_face(side)
		var rest := face.position.y
		var t := face.create_tween()
		face.set_meta("nudge", t)
		# A line said right after doesn't cut the laugh short.
		face.set_meta("busy_until", Time.get_ticks_msec() + 420)
		for hop in [10.0, 5.0]:
			t.tween_property(face, "position:y", rest - hop, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			t.tween_property(face, "position:y", rest, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## Change the face on `side` to `tex` with the gesture that goes with `mood` (one of
## StoryArt.EXPRESSIONS): a laugh when amused, a lean in when warm, drawn back when
## concerned.
func express(side: String, tex: Texture2D, mood: String) -> void:
	change_face(side, tex)
	gesture(side, {"amused": "bounce", "warm": "lean", "concerned": "back"}.get(mood, ""))
	life_act(side, PortraitLife.for_mood(mood))


## A face sways as it dances (`amount` in radians; 0 stops it).
func sway(side: String, amount: float = 0.035) -> void:
	var face := face_node(side)
	if face != null and is_instance_valid(face):
		face.set_meta("sway", amount)


## Someone new takes the place on `side`: they step in as a first arrival does.
func replace_face(side: String, tex: Texture2D, pixel: bool = false, height: float = 0.92) -> void:
	var face := face_node(side)
	var was: Texture2D = face.texture if face != null and is_instance_valid(face) else null
	if was != null and (was == _faces[side].get("shut") or PortraitLife.wears(_faces[side], was)):
		was = _faces[side].get("rest")          # caught mid-blink or mid-glance: the same face
	if face != null and is_instance_valid(face):
		for key in ["nudge", "enter"]:
			var old = (face.get_meta(key) if face.has_meta(key) else null)
			if old is Tween and (old as Tween).is_valid():
				(old as Tween).kill()
		face.modulate = Color.WHITE
	set_face(side, tex, pixel, height)
	if was != null and was != tex:
		_enter_face(side)


func _layout() -> void:
	var s := size if size != Vector2.ZERO else get_viewport_rect().size
	var insets: Dictionary = Style.safe_insets(get_viewport())
	var h := roundf(s.y * stage_share)
	stage.position = Vector2.ZERO
	stage.size = Vector2(s.x, h)
	_scroll.position = Vector2(0, h)
	_scroll.size = Vector2(s.x, s.y - h - float(insets.get("bottom", 0.0)))
	if _backdrop != null:
		_backdrop.position = Vector2.ZERO
		_backdrop.size = stage.size
	for side in _faces:
		_place_face(side)


func set_stage_share(share: float) -> void:
	if is_equal_approx(stage_share, share):
		return
	stage_share = share
	if stage != null:
		_layout()


## A painted room or place as a backdrop, tinted for the hour.
static func room(id: String, when: String) -> TextureRect:
	var art := TextureRect.new()
	art.name = "Room"
	art.texture = StoryArt.texture("res://assets/locations/%s.png" % id)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.modulate = {"night": Color(0.5, 0.54, 0.78), "dusk": Color(1.0, 0.82, 0.68), "morning": Color(1.0, 0.96, 0.92)}.get(when, Color.WHITE)
	if when in ["dusk", "night"]:
		art.add_child(firelight())
	return art


## Warm light over a room after dark that breathes the way a hearth and candles do. Still
## (a steady glow) under Reduced motion.
static func firelight() -> ColorRect:
	var glow := ColorRect.new()
	glow.name = "Firelight"
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.color = Color(1.0, 0.62, 0.28, 0.07)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = add
	if Style.motion_reduced():
		return glow
	glow.ready.connect(func():
		var t := glow.create_tween().set_loops()
		for step in [[0.11, 0.18], [0.06, 0.25], [0.09, 0.12], [0.05, 0.3], [0.1, 0.2], [0.07, 0.16]]:
			t.tween_property(glow, "color:a", float(step[0]), float(step[1])).set_trans(Tween.TRANS_SINE))
	return glow


## Where and when as marks: a pin and the place, an icon and the gathering, the sun or
## the moon for the hour. `caption` is "Place · gathering · hour" (any part may be
## missing); an hour word becomes its icon, with the word as the tooltip. `middle_icon`
## marks the parts between the place and the hour (a feast, a dance).
static func caption_row(caption: String, middle_icon: String = "") -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "CaptionRow"
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var parts := caption.split(" · ", false)
	for i in parts.size():
		var part := String(parts[i])
		if part in TIME_WORDS:
			var t := Widgets.icon_rect("moon" if part == "night" else "sun", 28.0)
			t.name = "When"
			t.tooltip_text = part
			t.modulate = {"night": Color("c9d4ff"), "dusk": Color("ffb36b"), "morning": Color("ffe6a8")}.get(part, Color("fff1b8"))
			row.add_child(t)
			continue
		var key := "mappin" if i == 0 else middle_icon
		if key != "":
			var ic := Widgets.icon_rect(key, 26.0)
			ic.modulate = Style.MUTED
			row.add_child(ic)
		var l := Style.label(part, Style.SMALL, Style.TEXT)
		l.name = "Caption" if i == 0 else "CaptionPart"
		row.add_child(l)
	return row


const TIME_WORDS := ["morning", "midday", "afternoon", "dusk", "night"]


## The round ✕ at the top right of a stage: a full touch target.
static func close_button(act: Callable) -> Button:
	var x := Button.new()
	x.name = "Close"
	x.custom_minimum_size = Vector2(Style.TOUCH, Style.TOUCH)
	x.icon = Widgets.icon("cancel")
	x.tooltip_text = "Leave"
	x.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	x.add_theme_constant_override("icon_max_width", 36)
	x.add_theme_stylebox_override("normal", Style.box(Color(Style.NIGHT, 0.75), Style.RULE, 2, 40))
	x.add_theme_stylebox_override("hover", Style.box(Color(Style.NIGHT, 0.85), Style.MUTED, 2, 40))
	x.add_theme_stylebox_override("pressed", Style.box(Style.NIGHT, Style.BRASS, 2, 40))
	x.anchor_left = 1.0
	x.anchor_right = 1.0
	x.offset_left = -20 - Style.TOUCH
	x.offset_right = -20
	x.offset_top = 14
	x.offset_bottom = 14 + Style.TOUCH
	x.pressed.connect(act)
	return x


static func time_word(hour: float) -> String:
	var h := fposmod(hour, 24.0)
	if h >= 5.0 and h < 10.0:
		return "morning"
	if h >= 10.0 and h < 14.0:
		return "midday"
	if h >= 14.0 and h < 17.5:
		return "afternoon"
	if h >= 17.5 and h < 20.5:
		return "dusk"
	return "night"


## A face on the stage: "left" (the one speaking with you, large), "left"/"right" for
## two faces, or "center". `pixel` keeps pixel art crisp; `height` is a share of the stage.
func set_face(side: String, tex: Texture2D, pixel: bool = false, height: float = 0.92, dim: bool = false) -> void:
	var face: TextureRect = _faces.get(side, {}).get("node")
	if face == null:
		face = TextureRect.new()
		face.name = "Face_" + side
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(face)
		# Under the fade and the nameplate, over the backdrop.
		stage.move_child(face, 1 if _backdrop != null else 0)
	var arriving := not _faces.has(side) or face.texture == null
	face.texture = tex
	face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if pixel else CanvasItem.TEXTURE_FILTER_LINEAR
	face.modulate = Color(0.5, 0.5, 0.58) if dim else Color.WHITE
	var known: Dictionary = _faces.get(side, {})
	known["node"] = face
	known["height"] = height
	_faces[side] = known
	_painted_life(side, tex)
	_place_face(side)
	if arriving:
		_enter_face(side)


## Someone comes into the scene: their face slides in from their own side (from below
## for the one in the middle) and fades up.
func _enter_face(side: String) -> void:
	var face: TextureRect = _faces[side]["node"]
	enter(face, ({"left": Vector2(-50, 0), "right": Vector2(50, 0)} as Dictionary).get(side, Vector2(0, 30)))


## `face` comes in from `offset` away and fades up to where and how it already is. Nothing
## under Reduced motion.
static func enter(face: Control, offset: Vector2) -> void:
	if Style.motion_reduced():
		return
	var rest := face.position
	var tint := face.modulate
	face.position = rest + offset
	face.modulate = Color(tint, 0.0)
	var t := face.create_tween().set_parallel()
	face.set_meta("enter", t)
	t.tween_property(face, "position", rest, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(face, "modulate", tint, 0.25)


## Change a face's picture with a short crossfade (none with reduced motion).
func change_face(side: String, tex: Texture2D) -> void:
	var face: TextureRect = _faces.get(side, {}).get("node")
	if face == null or tex == null or face.texture == tex:
		return
	if tex == _faces[side].get("rest") and (face.texture in [_faces[side].get("shut"), _faces[side].get("half"), _faces[side].get("talk")] or PortraitLife.wears(_faces[side], face.texture)):
		return                                  # the same face, caught mid-blink, mid-word or mid-glance
	var was := face.texture
	face.texture = tex
	_painted_life(side, tex)
	if not Style.motion_reduced() and was != null:
		_fade_out_over(face, was)


## The picture a face wore lies over its new one for a moment and fades away: the face is
## never see-through while it changes (fading the new picture in let the room show through).
func _fade_out_over(face: TextureRect, was: Texture2D) -> void:
	var old := face.get_node_or_null("Was") as TextureRect
	if old != null:
		old.free()
	old = TextureRect.new()
	old.name = "Was"
	old.mouse_filter = Control.MOUSE_FILTER_IGNORE
	old.texture = was
	old.expand_mode = face.expand_mode
	old.stretch_mode = face.stretch_mode
	old.texture_filter = face.texture_filter
	old.material = face.material                  # the same head, moving with the new one
	old.self_modulate = face.self_modulate
	old.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	face.add_child(old)
	var t := old.create_tween()
	t.tween_property(old, "modulate:a", 0.0, 0.18)
	t.tween_callback(old.queue_free)


func _place_face(side: String) -> void:
	var f: Dictionary = _faces[side]
	var face: TextureRect = f["node"]
	var s := stage.size
	var h := s.y * float(f["height"])
	var w := h * 0.75
	face.size = Vector2(w, h)
	var two := _faces.size() > 1
	if side == "center":
		face.position = Vector2((s.x - w) * 0.5, s.y - h)
	elif side == "left":
		face.position = Vector2(s.x * (0.02 if two else 0.04), s.y - h)
	else:
		face.position = Vector2(s.x * 0.98 - w, s.y - h)
	_pose(side)


## Their name and what stands between you, at the foot of the stage.
func set_plate(name_text: String, chips: Array) -> void:
	for c in _plate.get_children():
		_plate.remove_child(c)
		c.queue_free()
	_plate_name = name_text
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 12)
	row.add_theme_constant_override("v_separation", 6)
	var name_label := Style.name_label(name_text)
	name_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	var display := Style.display_font()
	if display != null:
		name_label.add_theme_font_override("font", display)
	row.add_child(name_label)
	for c in chips:
		(c as Control).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(c)
	_plate.add_child(row)


## A chip on the stage: the shared chip on a darker ground, so it reads over the picture.
## With an icon it leads with the icon in `tone`; without one, with a shape.
static func stage_chip(text: String, tone: Color, icon_key: String = "", shape: String = "") -> PanelContainer:
	var c := Widgets.chip(text, tone, shape, icon_key)
	var sb := (c.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
	sb.bg_color = Color(Style.NIGHT, 0.85)
	c.add_theme_stylebox_override("panel", sb)
	return c


## How things stand with someone you court, as an icon: talk while you're getting to know
## each other, a heart while courting, rings once engaged or wed, a lock when it's over.
static func status_icon(status: String) -> String:
	match status:
		"engaged", "married":
			return "rings"
		"courting", "committed":
			return "heart"
		"ended":
			return "lock"
	return "talk"


## Effects as chips. Each entry is [icon, amount] (a signed change, green up and red
## down), [icon, amount, suffix], [icon, "text"] (a plain quantity), or a realm's banner
## with what changes with it: {"realm": id, "amount": n} or {"realm": id, "text": "war"}.
static func fx_chips(fx: Array) -> Array:
	var out := []
	for e in fx:
		if e is Dictionary:
			out.append(realm_chip(String(e.get("realm", "")), e))
		elif e[1] is String:
			out.append(Widgets.stat(String(e[0]), String(e[1])))
		else:
			out.append(Widgets.effect(String(e[0]), int(e[1]), String(e[2]) if e.size() > 2 else ""))
	return out


static func realm_chip(realm: String, e: Dictionary) -> PanelContainer:
	var p := PanelContainer.new()
	p.name = "Realm_%s" % realm
	var sb := Style.box(Style.RAISED, Style.RULE, 2, 40)
	sb.content_margin_left = 10
	sb.content_margin_right = 16
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	p.add_child(h)
	h.add_child(Widgets.banner(realm, Vector2(20, 30)))
	var text := String(e.get("text", ""))
	var tone := Style.ENEMY_LIGHT if text == "war" else Style.TEXT
	if e.has("amount"):
		var n := int(e["amount"])
		text = "%s%d" % ["+" if n > 0 else ("−" if n < 0 else ""), absi(n)]
		tone = Style.MORALE_HIGH if n > 0 else (Style.ENEMY_LIGHT if n < 0 else Style.MUTED)
	var l := Style.label(text, Style.SMALL, tone)
	l.name = "Text"
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	return p


## What a reply is and does, under its words: the lock if it's shut, its kind as an icon,
## its effects as chips, and any words still needed (in a label named Tag).
static func marks(r: Dictionary, tone: String) -> Control:
	var tag := String(r.get("tag", ""))
	var key := String(r.get("icon", ""))
	var fx: Array = r.get("fx", [])
	var locked := tone == "locked"
	if tag == "" and key == "" and fx.is_empty() and not locked:
		return null
	var row := HFlowContainer.new()
	row.name = "Marks"
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ink: Color = Style.BRASS if tone == "gold" else (Style.ENEMY_LIGHT if tone == "red" else Style.MUTED)
	if locked or key != "":
		var ic := Widgets.icon_rect("lock" if locked else key, 26.0)
		ic.name = "Kind"
		ic.modulate = ink
		row.add_child(ic)
	if not locked:
		for c in fx_chips(fx):
			row.add_child(c)
	if tag != "":
		var tl := Style.label(tag, Style.SMALL, ink)
		tl.name = "Tag"
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		# The words take what's left of the line after the marks before them. Without
		# this a wrapping label in a flow is given no width, and stands one letter a line.
		tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(tl)
	return row


## What changed, as chips with any words after them, for the log. Named "Note", like a
## note, and fades in once: the one animated result of a choice.
static func fx_note(fx: Array, text: String = "", tone: Color = Style.MORALE_HIGH) -> PanelContainer:
	var p := PanelContainer.new()
	p.name = "Note"
	p.add_theme_stylebox_override("panel", Style.box(Color(tone, 0.12), Color(tone, 0.6), 2, 12))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in fx_chips(fx):
		row.add_child(c)
	if text != "":
		var l := Style.label(text, Style.SMALL, tone.lightened(0.3))
		l.name = "Words"
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		# As with a reply's tag: the words take the rest of the line after the chips.
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
	p.add_child(row)
	if not Style.motion_reduced():
		p.modulate.a = 0.0
		p.create_tween().tween_property(p, "modulate:a", 1.0, 0.3)
	return p


# ---------------------------------------------------------------- the conversation

func clear_log() -> void:
	_stop_turn()
	for c in _log.get_children():
		_log.remove_child(c)
		c.queue_free()


## A line in the conversation. `who` is "them" (left, under `speaker`), "you" (right, in
## your blue), "other" (right, a second speaker who isn't you, in a neutral bubble) or
## "narration" (centred, no bubble). The speaker's name shows only when it isn't the name
## on the plate: one on one, the face and the plate already say who it is.
func say(who: String, text: String, speaker: String = "") -> Control:
	var holder := HBoxContainer.new()
	holder.name = "Line"
	if who == "narration":
		var l := Style.label(text, Style.BODY, Style.MUTED)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.name = "Narration"
		holder.add_child(l)
		_log.add_child(holder)
		return holder
	var bubble := PanelContainer.new()
	bubble.name = {"them": "Them", "other": "Other"}.get(who, "You")
	var mine := who == "you"
	var right := who != "them"
	var fill := Color("26304f") if mine else (Color("252a3b") if who == "other" else Color("1d2238"))
	var edge := Style.PLAYER_LIGHT.darkened(0.55) if mine else (Style.MUTED.darkened(0.45) if who == "other" else Style.RULE)
	var sb := Style.box(fill, edge, 2, 16)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	bubble.add_theme_stylebox_override("panel", sb)
	bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bubble.size_flags_stretch_ratio = 5.0
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	if speaker != "" and speaker != _plate_name:
		var who_label := Style.label(speaker, Style.SMALL, Style.BRASS)
		who_label.name = "Speaker"
		if right:
			who_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		v.add_child(who_label)
	var l := Style.label(text, Style.BODY, Style.TEXT)
	l.name = "Words"
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	bubble.add_child(v)
	if who != "you" and write_lines:
		_reveal(l)
		_nudge_speaker(_speaker_side(who))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.size_flags_stretch_ratio = 1.0
	if right:
		holder.add_child(gap)
		holder.add_child(bubble)
	else:
		holder.add_child(bubble)
		holder.add_child(gap)
	_log.add_child(holder)
	return holder


## Their words are written out, about WRITE_SPEED characters a second (never longer than
## WRITE_MAX), so a line feels spoken; a tap on the conversation finishes every line
## being written. Whole at once under Reduced motion or "Text appears at once".
const WRITE_SPEED := 45.0
const WRITE_MAX := 1.5
var _writing: Array = []


func _reveal(l: Label) -> void:
	var t := write_out(l)
	if t != null:
		_writing.append(t)


## Write `l`'s words out; the tween doing it, or null when they're whole at once (Reduced
## motion, "Text appears at once", nothing to write). Finish it early with finish().
static func write_out(l: Label) -> Tween:
	if Style.motion_reduced() or bool(Sound.instant_text):
		return null
	var n := l.text.length()
	if n == 0:
		return null
	l.visible_characters = 0
	var t := l.create_tween()
	t.tween_property(l, "visible_characters", n, minf(float(n) / WRITE_SPEED, WRITE_MAX))
	t.tween_callback(func(): l.visible_characters = -1)
	return t


## Whether a tween from write_out (or any other) is still going.
static func running(t) -> bool:
	return t is Tween and (t as Tween).is_valid() and (t as Tween).is_running()


## Land a tween on its end state now.
static func finish(t) -> void:
	if t is Tween and (t as Tween).is_valid():
		(t as Tween).custom_step(3600.0)


## Whether any line is still being written out.
func writing() -> bool:
	_writing = _writing.filter(func(t): return running(t))
	return not _writing.is_empty()


## Every line being written lands whole.
func finish_writing() -> void:
	# Finishing lines told in turn starts the next one's writing: take them as they come.
	while not _writing.is_empty():
		finish(_writing.pop_back())


## Lines told one after another. They are all in the talk from the start (nothing waits
## on them: the replies under them can be pressed at once), but each shows, and is
## written out, as its turn comes; a tap brings the rest at once. Each is {who, text,
## speaker, then} where `then` (optional) is called with the speaking face's side as the
## line is said ("" for narration); the face that says it moves its mouth as it's written
## (if it can: set_blink). `done` is called after the last. Under Reduced motion or "Text appears
## at once" they are all simply there.
var _turn = null


func say_in_turn(lines: Array, done: Callable = Callable()) -> void:
	_stop_turn()
	var held := []
	write_lines = false
	for line in lines:
		held.append(say(String(line["who"]), String(line["text"]), String(line.get("speaker", ""))))
	write_lines = true
	if Style.motion_reduced() or bool(Sound.instant_text) or not is_inside_tree() or lines.is_empty():
		if done.is_valid():
			done.call()
		return
	for h in held:
		(h as Control).visible = false
	var t := create_tween()
	_turn = t
	_writing.append(t)
	for i in lines.size():
		t.tween_callback(_take_turn.bind(held[i], lines[i]))
		t.tween_interval(turn_time(lines[i]))
	if done.is_valid():
		t.tween_callback(done)


## How long a line has the talk to itself. Something said gets about as long as it takes
## to read; narration sets the scene and is given a glance, so the talk starts soon (it
## stays on the page to be read).
static func turn_time(line: Dictionary) -> float:
	var n := float(String(line["text"]).length())
	if String(line["who"]) == "narration":
		return clampf(n / 60.0, 0.8, 2.2)
	return clampf(n / 18.0, 1.2, 5.0)


func _take_turn(holder: Control, line: Dictionary) -> void:
	if not is_instance_valid(holder):
		return
	holder.visible = true
	var who := String(line["who"])
	if who == "narration":
		holder.modulate.a = 0.0
		holder.create_tween().tween_property(holder, "modulate:a", 1.0, 0.25)
		if line.has("then"):
			(line["then"] as Callable).call("")
	elif who != "you":
		var words := holder.find_child("Words", true, false) as Label
		var w: Tween = write_out(words) if words != null else null
		if w != null:
			_writing.append(w)
		var side := _speaker_side(who)
		_nudge_speaker(side)
		if line.has("then"):
			(line["then"] as Callable).call(side)
		speaking(side, w)
	_follow()


## Keep the newest line in view, unless the reader has scrolled back up to read.
func _follow() -> void:
	if not is_instance_valid(_scroll):
		return
	var bar := _scroll.get_v_scroll_bar()
	if bar.max_value - bar.page - _scroll.scroll_vertical < 140.0:
		_scroll_to_end()


func _stop_turn() -> void:
	if _turn is Tween and (_turn as Tween).is_valid():
		(_turn as Tween).kill()
	_turn = null


## Whose face says a line: a second speaker ("other") is the one on the right; "them" is
## the one on the left, or in the middle.
func _speaker_side(who: String) -> String:
	if who == "other" and _faces.has("right"):
		return "right"
	for side in ["left", "center", "right"]:
		if _faces.has(side):
			return side
	return ""


## The one speaking leans in: their face rises a few pixels and settles.
func _nudge_speaker(speaker: String) -> void:
	if Style.motion_reduced():
		return
	for side in [speaker]:
		if _faces.has(side):
			var face: TextureRect = _faces[side]["node"]
			if face == null or not is_instance_valid(face):
				return
			if Time.get_ticks_msec() < int(face.get_meta("busy_until", 0)):
				return
			var old = (face.get_meta("nudge") if face.has_meta("nudge") else null)
			if old is Tween and (old as Tween).is_valid():
				(old as Tween).kill()
			_place_face(side)
			var rest := face.position.y
			var t := face.create_tween()
			face.set_meta("nudge", t)
			t.tween_property(face, "position:y", rest - 6.0, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			t.tween_property(face, "position:y", rest, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
			return


func add_to_log(ctrl: Control) -> void:
	_log.add_child(ctrl)


## A coloured note (what changed, what you learned) for the log.
func note(text: String, tone: Color = Style.MORALE_HIGH) -> PanelContainer:
	var p := PanelContainer.new()
	p.name = "Note"
	p.add_theme_stylebox_override("panel", Style.box(Color(tone, 0.12), Color(tone, 0.6), 2, 12))
	var l := Style.label(text, Style.SMALL, tone.lightened(0.3))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.add_child(l)
	return p


## A memory kept, in rose: its icon, its words and any chips with it (trust gained).
func keepsake(text: String, icon_key: String = "cup", fx: Array = []) -> PanelContainer:
	var p := PanelContainer.new()
	p.name = "Keepsake"
	p.add_theme_stylebox_override("panel", Style.box(Color("2a1f26"), Style.ROMANCE, 2, 14))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var i := Widgets.icon_rect(icon_key, 36)
	i.modulate = Style.ROMANCE_LIGHT
	h.add_child(i)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l := Style.label(text, Style.SMALL, Style.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	if not fx.is_empty():
		v.add_child(Widgets.chip_row(fx_chips(fx)))
	h.add_child(v)
	p.add_child(h)
	land(p, Color(1.5, 1.1, 1.3))
	return p


## Something kept or won lands in the talk: it fades up, settles from a little small with
## a slight overshoot, and its glow (`glint`) cools to its own colours. Call it before the
## control is in the tree. Simply there under Reduced motion.
static func land(p: Control, glint: Color = Color(1.4, 1.25, 0.8)) -> void:
	if Style.motion_reduced():
		return
	p.modulate = Color(glint, 0.0)
	var go := func() -> void:
		await p.get_tree().process_frame
		if not is_instance_valid(p) or not p.is_inside_tree():
			return
		p.pivot_offset = p.size * 0.5
		p.scale = Vector2(0.94, 0.94)
		var t := p.create_tween().set_parallel()
		t.tween_property(p, "modulate:a", 1.0, 0.2)
		t.tween_property(p, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(p, "modulate", Color.WHITE, 0.9).set_delay(0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	p.ready.connect(go, CONNECT_ONE_SHOT)


## Replies you can give: {id, text, tag, tone ("plain", "gold", "red", "locked", "quiet"),
## act, extra}. A reply with only `act` and "Continue" text is the tap-to-continue.
func set_replies(replies: Array) -> void:
	for c in _replies.get_children():
		_replies.remove_child(c)
		c.queue_free()
	_continue = Callable()
	for r in replies:
		if r.has("row"):
			# Small choices side by side, sharing the width.
			var row := HBoxContainer.new()
			row.name = "Row"
			row.add_theme_constant_override("separation", 10)
			for rr in r["row"]:
				var b := reply_button(rr)
				b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				b.custom_minimum_size.x = 0
				row.add_child(b)
			_replies.add_child(row)
		else:
			_replies.add_child(reply_button(r))
	# The replies arrive in a short run. Nothing waits on it: each can be pressed at once.
	if not Style.motion_reduced():
		var k := 0
		for c in _replies.get_children():
			var part := c as Control
			part.modulate.a = 0.0
			part.create_tween().tween_property(part, "modulate:a", 1.0, 0.16).set_delay(minf(0.045 * k, 0.3))
			k += 1
	_scroll_to_end()


## Only a Continue: tapping anywhere on the conversation does it too.
func wait_to_continue(act: Callable, text: String = "Continue") -> void:
	set_replies([{"id": "continue", "text": text, "tone": "quiet", "act": act}])
	_continue = act


func _gui_input(event: InputEvent) -> void:
	_tap(event)


## A tap (released without a drag) on the stage or the conversation goes on.
## Where the finger went down, so a release after scrolling the talk doesn't count as a tap.
var _tap_from := Vector2.INF


func _tap(event: InputEvent) -> void:
	# A tap while words are being written finishes them, and goes no further.
	var up_now: bool = (event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and not event.pressed)
	if up_now and writing():
		finish_writing()
		_tap_from = Vector2.INF
		return
	if not _continue.is_valid():
		return
	var pointer := event is InputEventMouseButton or event is InputEventScreenTouch
	if pointer and event.pressed:
		_tap_from = event.position
		return
	var up: bool = (event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and not event.pressed)
	if up and _tap_from != Vector2.INF and _tap_from.distance_to(event.position) > Widgets.TAP_SLOP:
		_tap_from = Vector2.INF
		return
	if up:
		_tap_from = Vector2.INF
		var act := _continue
		_continue = Callable()
		act.call()


func reply_button(r: Dictionary) -> Control:
	var tone := String(r.get("tone", "plain"))
	var locked := tone == "locked"
	var quiet := tone == "quiet"
	# "primary": the way on or out of a talk, full width in brass, not a line anyone says.
	var primary := tone == "primary"
	var b := Button.new()
	b.name = "Reply_" + String(r["id"])
	if primary:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		b.size_flags_horizontal = Control.SIZE_SHRINK_END if not quiet else Control.SIZE_SHRINK_CENTER
		var wide := size.x if size.x > 0 else 720.0
		b.custom_minimum_size = Vector2(minf(wide * (0.5 if quiet else 0.84), 620.0), 0)
	b.disabled = locked
	b.focus_mode = Control.FOCUS_NONE
	var bg: Color = {"gold": Color("3a2c10"), "red": Color("3c1512"), "locked": Color(Style.NIGHT, 0.6), "quiet": Color(0, 0, 0, 0),
		"primary": Style.BRASS}.get(tone, Style.RAISED)
	var edge: Color = {"gold": Style.BRASS, "red": Style.ENEMY, "locked": Style.RULE.darkened(0.2), "quiet": Style.RULE,
		"primary": Style.BRASS}.get(tone, Style.RULE)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := Style.box(bg if state != "pressed" else bg.darkened(0.2), edge if state != "hover" else edge.lightened(0.2), 2, 16)
		b.add_theme_stylebox_override(state, sb)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 18
	box.offset_right = -18
	box.offset_top = 10
	box.offset_bottom = -10
	var shown := String(r["text"]) if quiet or primary or bool(r.get("bare", false)) else "\"%s\"" % String(r["text"])
	var ink := Style.BRASS_INK if primary else (Style.MUTED if locked or quiet else Style.TEXT)
	var text := Style.label(shown, Style.BODY, ink)
	text.name = "Text"
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if quiet or primary:
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(text)
	var tag_row := marks(r, tone)
	if tag_row != null:
		box.add_child(tag_row)
	if r.has("extra"):
		box.add_child(r["extra"])
	b.add_child(box)
	# Tall enough for its words, and never under its touch height.
	var floor_y := Style.TOUCH
	box.minimum_size_changed.connect(func(): b.custom_minimum_size.y = maxf(floor_y, box.get_combined_minimum_size().y + 20))
	b.custom_minimum_size.y = floor_y
	if not locked and r.has("act"):
		var act: Callable = r["act"]
		b.pressed.connect(func():
			Sound.play("page", 0.0, 0.05)
			act.call())
	return b


## The reply button with this id, wherever it sits in the column.
func reply_node(id: String) -> Button:
	return _replies.find_child("Reply_" + id, true, false) as Button


## Press a reply by id, as a tap would.
func choose(id: String) -> bool:
	var b := reply_node(id)
	if b == null or b.disabled:
		return false
	b.pressed.emit()
	return true


func has_reply(id: String, enabled_only: bool = true) -> bool:
	var b := reply_node(id)
	return b != null and (not enabled_only or not b.disabled)


func reply_ids() -> Array:
	return _replies.find_children("Reply_*", "Button", true, false).map(func(c): return String(c.name).trim_prefix("Reply_"))


## Everything said so far, as plain text.
func log_text() -> String:
	var out := PackedStringArray()
	for line in _log.find_children("*", "Label", true, false):
		out.append((line as Label).text)
	return "\n".join(out)


var _glide = null


func _scroll_to_end() -> void:
	await get_tree().process_frame
	if not is_instance_valid(_scroll):
		return
	var end := int(_scroll.get_v_scroll_bar().max_value)
	if _glide is Tween and (_glide as Tween).is_valid():
		(_glide as Tween).kill()
	# The talk glides down to the newest line; it doesn't jump.
	if Style.motion_reduced() or absi(end - _scroll.scroll_vertical) < 8:
		_scroll.scroll_vertical = end
		return
	_glide = create_tween()
	(_glide as Tween).tween_property(_scroll, "scroll_vertical", end, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func close() -> void:
	closed.emit()
	_on_close()


## What closing does; a subclass decides where to go.
func _on_close() -> void:
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
