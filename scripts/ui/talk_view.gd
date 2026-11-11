## A conversation face to face: a stage (where you are, who you're talking to, a nameplate)
## over a running conversation (their lines on the left, yours on the right, narration in
## the middle) and the replies you can give. Romance talks and the captains' talks at the
## fire are built on it; a subclass fills it.
extends Control

const Style = preload("res://scripts/ui/style.gd")
const Widgets = preload("res://scripts/ui/widgets.gd")
const StoryArt = preload("res://scripts/ui/story_art.gd")

const STAGE_SHARE := 0.46
## The least of the screen the stage keeps while there are answers that need the room.
const ANSWERING_SHARE := 0.30
## The log is never squeezed under this; and what it would like to keep before the stage
## gives way to the answers.
const LOG_MIN := 150.0
const LOG_WANT := 240.0
## The margin at each side of the talk on a phone; a wide window centres a column instead.
const SIDE := 22.0
const FADE := 24.0

## How much of the screen the stage takes; a subclass lowers it while there's a lot to read.
var stage_share := STAGE_SHARE
## Whether the stage gives up room (down to ANSWERING_SHARE) while the answers on offer
## would otherwise crowd the conversation out. A subclass opts in.
var shrink_for_answers := false

signal closed

var stage: Control
var _backdrop: Control
var _plate: VBoxContainer
## The strip under the stage that says where you are in what is being told.
var _header: PanelContainer
var _header_title := ""
var _scroll: ScrollContainer
var _log_pad: MarginContainer
var _log: VBoxContainer
var _log_fade: TextureRect
## The way on between lines: no button, a small mark at the foot of the conversation.
var _cue: Button
## What you can say, pinned to the bottom of the screen: a caption, the answers, and the
## quiet ways out as a row of links.
var _tray: PanelContainer
var _tray_scroll: ScrollContainer
var _tray_pad: MarginContainer
var _prompt: Label
var _replies: VBoxContainer
var _footer: HFlowContainer
var _continue: Callable
var _faces := {}
## Whose name is on the plate: their bubbles don't repeat it.
var _plate_name := ""
## The stage's height now, and where it is easing to.
var _stage_h := -1.0
var _stage_goal := -1.0
var _stage_tween: Tween
var _laid_size := Vector2.ZERO
var _layout_queued := false
var _side := SIDE
## A memory told again: the room and the faces lose their colour.
var _memory_look := false


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


## Lay out the screen with `backdrop` (a Control that fills the stage) and a caption.
func setup(backdrop: Control, caption: String) -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_faces.clear()
	_stage_h = -1.0
	_stage_goal = -1.0
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
	fade.texture = _gradient(Color(Style.NIGHT, 0.0), Color(Style.NIGHT, 0.96))
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
	# Where you are in what is being told: hidden until something sets it.
	_header = PanelContainer.new()
	_header.name = "Header"
	_header.visible = false
	_header.mouse_filter = Control.MOUSE_FILTER_PASS
	var hb := Style.box(Color("131a2e"), Style.RULE, 0, 0)
	hb.border_width_bottom = 2
	hb.content_margin_top = 8
	hb.content_margin_bottom = 8
	_header.add_theme_stylebox_override("panel", hb)
	_header.minimum_size_changed.connect(_queue_layout)
	add_child(_header)
	# The conversation: a log that keeps what's been said. It scrolls; nothing else moves.
	_scroll = ScrollContainer.new()
	_scroll.name = "Talk"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.gui_input.connect(_tap)
	add_child(_scroll)
	_log_pad = MarginContainer.new()
	_log_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_pad.add_theme_constant_override("margin_top", 18)
	_log_pad.add_theme_constant_override("margin_bottom", 18)
	_scroll.add_child(_log_pad)
	_log = VBoxContainer.new()
	_log.name = "Log"
	_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log.add_theme_constant_override("separation", 10)
	_log_pad.add_child(_log)
	# Lines leave under the stage softly, not at a hard edge.
	_log_fade = TextureRect.new()
	_log_fade.name = "LogFade"
	_log_fade.texture = _gradient(Style.NIGHT, Color(Style.NIGHT, 0.0))
	_log_fade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_log_fade.stretch_mode = TextureRect.STRETCH_SCALE
	_log_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_log_fade)
	_cue = _make_cue()
	add_child(_cue)
	# What you can say: pinned to the bottom, growing upward to fit.
	_tray = PanelContainer.new()
	_tray.name = "Tray"
	_tray.visible = false
	var tb := Style.box(Style.NIGHT, Style.RULE, 0, 0)
	tb.border_width_top = 2
	tb.set_content_margin_all(0)
	tb.content_margin_top = 2
	_tray.add_theme_stylebox_override("panel", tb)
	add_child(_tray)
	_tray_scroll = ScrollContainer.new()
	_tray_scroll.name = "TrayScroll"
	_tray_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tray_scroll.gui_input.connect(_tap)
	_tray.add_child(_tray_scroll)
	_tray_pad = MarginContainer.new()
	_tray_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tray_pad.add_theme_constant_override("margin_top", 12)
	_tray_pad.add_theme_constant_override("margin_bottom", 6)
	_tray_pad.minimum_size_changed.connect(_queue_layout)
	_tray_scroll.add_child(_tray_pad)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 8)
	_tray_pad.add_child(col)
	_prompt = Style.label("", Style.SMALL, Style.BRASS)
	_prompt.name = "Prompt"
	_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt.visible = false
	col.add_child(_prompt)
	_replies = VBoxContainer.new()
	_replies.name = "Replies"
	_replies.add_theme_constant_override("separation", 10)
	_replies.visible = false
	col.add_child(_replies)
	_footer = HFlowContainer.new()
	_footer.name = "Footer"
	_footer.alignment = FlowContainer.ALIGNMENT_CENTER
	_footer.add_theme_constant_override("h_separation", 10)
	_footer.add_theme_constant_override("v_separation", 0)
	_footer.visible = false
	col.add_child(_footer)
	if not resized.is_connected(_layout):
		resized.connect(_layout)
	_layout()


static func _gradient(from: Color, to: Color) -> GradientTexture2D:
	var grad := Gradient.new()
	grad.set_color(0, from)
	grad.set_color(1, to)
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 64
	return gt


func _screen() -> Vector2:
	return size if size != Vector2.ZERO else get_viewport_rect().size


func _queue_layout() -> void:
	if _layout_queued:
		return
	_layout_queued = true
	_do_layout.call_deferred()


func _do_layout() -> void:
	_layout_queued = false
	_layout()


## The screen is three bands that keep their places: the stage, the conversation, and the
## tray of what you can say, which sits on the bottom edge and grows upward to fit.
func _layout() -> void:
	if stage == null or not is_instance_valid(stage):
		return
	var s := _screen()
	var goal := _stage_goal_for(s)
	if not is_equal_approx(goal, _stage_goal):
		# The stage gives way to the answers (and takes its room back) over a moment; a
		# resize, or the first layout, simply sets it.
		var jump := _stage_h < 0.0 or s != _laid_size or Style.motion_reduced() or not is_inside_tree()
		_stage_goal = goal
		if _stage_tween != null and _stage_tween.is_valid():
			_stage_tween.kill()
		if jump:
			_stage_h = goal
		else:
			_stage_tween = create_tween()
			_stage_tween.tween_method(_ease_stage, _stage_h, goal, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_laid_size = s
	_place(s)


func _ease_stage(h: float) -> void:
	_stage_h = h
	_place(_screen())


func _tray_want() -> float:
	if not _tray.visible:
		return 0.0
	return ceilf(_tray_pad.get_combined_minimum_size().y + _tray.get_theme_stylebox("panel").get_minimum_size().y)


func _stage_goal_for(s: Vector2) -> float:
	var share := stage_share
	# A wide, short window: the stage would leave no room to read.
	if s.x > s.y and s.y < 900.0:
		share = minf(share, 0.34)
	var full := roundf(s.y * share)
	if not shrink_for_answers:
		return full
	var bottom := float(Style.safe_insets(get_viewport()).get("bottom", 0.0)) if is_inside_tree() else 0.0
	var head := _header.get_combined_minimum_size().y if _header.visible else 0.0
	var need := _tray_want() + head + bottom + LOG_WANT
	return roundf(s.y * minf(share, ANSWERING_SHARE)) if s.y - full < need else full


func _place(s: Vector2) -> void:
	var bottom := float(Style.safe_insets(get_viewport()).get("bottom", 0.0)) if is_inside_tree() else 0.0
	var h := roundf(_stage_h)
	stage.position = Vector2.ZERO
	stage.size = Vector2(s.x, h)
	if _backdrop != null:
		_backdrop.position = Vector2.ZERO
		_backdrop.size = stage.size
	# A wide window: the talk keeps to the column the menus use, centred.
	_side = maxf(SIDE, (s.x - Style.COLUMN_MAX) * 0.5 + SIDE)
	for pad in [_log_pad, _tray_pad]:
		if (pad as MarginContainer).get_theme_constant("margin_left") != int(_side):
			(pad as MarginContainer).add_theme_constant_override("margin_left", int(_side))
			(pad as MarginContainer).add_theme_constant_override("margin_right", int(_side))
	var hb := _header.get_theme_stylebox("panel") as StyleBoxFlat
	if not is_equal_approx(hb.content_margin_left, _side):
		hb.content_margin_left = _side
		hb.content_margin_right = _side
	var head := 0.0
	if _header.visible:
		head = _header.get_combined_minimum_size().y
		_header.position = Vector2(0, h)
		_header.size = Vector2(s.x, head)
	var room := maxf(0.0, s.y - h - head - bottom)
	var want := _tray_want()
	var tray_h := minf(want, maxf(room - LOG_MIN, room * 0.5))
	# The answers scroll inside the tray only when there are more than the screen can hold.
	var mode := ScrollContainer.SCROLL_MODE_AUTO if want > tray_h + 0.5 else ScrollContainer.SCROLL_MODE_SHOW_NEVER
	if _tray_scroll.vertical_scroll_mode != mode:
		_tray_scroll.vertical_scroll_mode = mode
	_tray.position = Vector2(0, s.y - bottom - tray_h)
	_tray.size = Vector2(s.x, tray_h)
	var log_rect := Rect2(0, h + head, s.x, maxf(0.0, room - tray_h))
	var moved := not _scroll.size.is_equal_approx(log_rect.size) or not _scroll.position.is_equal_approx(log_rect.position)
	_scroll.position = log_rect.position
	_scroll.size = log_rect.size
	_log_fade.position = log_rect.position
	_log_fade.size = Vector2(s.x, minf(FADE, log_rect.size.y))
	_cue.reset_size()
	_cue.position = Vector2(s.x - _side - _cue.size.x + 10.0, log_rect.end.y - _cue.size.y - 2.0)
	for side in _faces:
		_place_face(side)
	if moved:
		_scroll_to_end()


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
		art.add_child(_firelight())
	return art


## Warm light over a room after dark that breathes the way a hearth and candles do. Still
## (a steady glow) under Reduced motion.
static func _firelight() -> ColorRect:
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
	face.material = _memory_material() if _memory_look else null
	_faces[side] = {"node": face, "height": height}
	_place_face(side)
	if arriving:
		_enter_face(side)


## Someone comes into the scene: their face slides in from their own side (from below
## for the one in the middle) and fades up.
func _enter_face(side: String) -> void:
	if Style.motion_reduced():
		return
	var face: TextureRect = _faces[side]["node"]
	var rest := face.position
	var from: Vector2 = rest + ({"left": Vector2(-50, 0), "right": Vector2(50, 0)} as Dictionary).get(side, Vector2(0, 30))
	var tint := face.modulate
	face.position = from
	face.modulate = Color(tint, 0.0)
	var t := face.create_tween().set_parallel()
	t.tween_property(face, "position", rest, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(face, "modulate", tint, 0.25)


## Change a face's picture with a short crossfade (none with reduced motion).
func change_face(side: String, tex: Texture2D) -> void:
	var face: TextureRect = _faces.get(side, {}).get("node")
	if face == null or tex == null or face.texture == tex:
		return
	face.texture = tex
	if not Style.motion_reduced():
		face.modulate.a = 0.55
		face.create_tween().tween_property(face, "modulate:a", 1.0, 0.18)


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
		# In a wide window they stand at the head of the column, not in the room's corner.
		face.position = Vector2(maxf(s.x * (0.02 if two else 0.04), _side - SIDE), s.y - h)
	else:
		face.position = Vector2(minf(s.x * 0.98, s.x - _side + SIDE) - w, s.y - h)


## A memory told again looks like one: the room and the faces lose most of their colour
## and a fifth of their light.
func set_memory_look(on: bool) -> void:
	_memory_look = on
	if _backdrop != null:
		_backdrop.material = _memory_material() if on else null
	for side in _faces:
		(_faces[side]["node"] as TextureRect).material = _memory_material() if on else null


var _memory_shader: ShaderMaterial


func _memory_material() -> ShaderMaterial:
	if _memory_shader == null:
		var sh := Shader.new()
		sh.code = "shader_type canvas_item;\nvoid fragment() {\n\tfloat g = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));\n\tCOLOR.rgb = mix(COLOR.rgb, vec3(g), 0.82) * 0.8;\n}\n"
		_memory_shader = ShaderMaterial.new()
		_memory_shader.shader = sh
	return _memory_shader


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
static func marks(r: Dictionary, tone: String, with_icon: bool = true) -> Control:
	var tag := String(r.get("tag", ""))
	var key := String(r.get("icon", "")) if with_icon else ""
	var fx: Array = r.get("fx", [])
	var locked := tone == "locked"
	if tag == "" and key == "" and fx.is_empty() and not (locked and with_icon):
		return null
	var row := HFlowContainer.new()
	row.name = "Marks"
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ink := tone_ink(tone)
	if (locked and with_icon) or key != "":
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
		# The rest of the line: a wrapping label's own minimum is one letter wide, and a
		# flow row would give it no more, a letter to a line.
		tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(tl)
	return row


## The colour a reply's kind is written and drawn in.
static func tone_ink(tone: String) -> Color:
	match tone:
		"gold", "warm":
			return Style.BRASS
		"red":
			return Style.ENEMY_LIGHT
		"heart":
			return Style.ROMANCE
		"locked":
			return Style.MUTED.darkened(0.25)
	return Style.MUTED


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
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(l)
	p.add_child(row)
	if not Style.motion_reduced():
		p.modulate.a = 0.0
		p.create_tween().tween_property(p, "modulate:a", 1.0, 0.3)
	return p


# ---------------------------------------------------------------- the conversation

func clear_log() -> void:
	# A passage still being told belongs to what is being cleared away.
	_pending.clear()
	_pending_then = Callable()
	_skip = Callable()
	for c in _log.get_children():
		_log.remove_child(c)
		c.queue_free()


## A line in the conversation. `who` is "them" (left, under `speaker`), "you" (right, in
## your blue), "other" (right, a second speaker who isn't you, in a neutral bubble) or
## "narration" (no bubble: what happens, in the letter hand, behind a thin rule). The
## speaker's name shows only when it isn't the name on the plate: one on one, the face and
## the plate already say who it is. `instant`: shown whole, not written out (a line already
## heard, shown again). `mark`: "remembered" (they are bringing up something you once
## said: a rose edge and a small cup) or "kept" (an answer of yours they will keep: the
## same small cup, on your own words).
func say(who: String, text: String, speaker: String = "", instant: bool = false, mark: String = "") -> Control:
	var holder := HBoxContainer.new()
	holder.name = "Line"
	if who == "narration":
		holder.add_theme_constant_override("separation", 14)
		var rule := ColorRect.new()
		rule.name = "Rule"
		rule.color = Color(Style.MUTED, 0.35)
		rule.custom_minimum_size = Vector2(3, 0)
		rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(rule)
		var n := Style.label(text, Style.BODY, Style.MUTED)
		# The letter hand runs small beside the talk's own face: a little larger, to match.
		var hand := Style.letter_font(true)
		if hand != null:
			n.add_theme_font_override("font", hand)
			n.add_theme_font_size_override("font_size", Style.text_size(Style.BODY + 3))
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		n.name = "Narration"
		holder.add_child(n)
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
	if mark in ["remembered", "kept"]:
		var remembered := mark == "remembered"
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var cup := Widgets.icon_rect("cup", 24.0)
		cup.name = "Remembered" if remembered else "Kept"
		cup.modulate = Style.ROMANCE if remembered else Color(Style.ROMANCE_LIGHT, 0.7)
		cup.size_flags_vertical = Control.SIZE_SHRINK_END
		row.add_child(cup)
		v.add_child(row)
		if remembered:
			bubble.set_meta("remembered", true)
			bubble.draw.connect(func(): bubble.draw_rect(Rect2(0, 14, 5, maxf(0.0, bubble.size.y - 28.0)), Style.ROMANCE))
	else:
		v.add_child(l)
	bubble.add_child(v)
	if who != "you" and not instant:
		_reveal(l)
		_nudge_speaker()
	var gap := Control.new()
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
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


## A quiet line under something in the log, said once: what a mark on the screen means.
func hint(text: String) -> Label:
	var l := Style.label(text, Style.SMALL, Style.ROMANCE_LIGHT)
	l.name = "Hint"
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log.add_child(l)
	return l


## Their words are written out, about WRITE_SPEED characters a second (never longer than
## WRITE_MAX), so a line feels spoken; a tap on the conversation finishes every line
## being written. Whole at once under Reduced motion or "Text appears at once".
const WRITE_SPEED := 45.0
const WRITE_MAX := 1.5
var _writing: Array = []


func _reveal(l: Label) -> void:
	if Style.motion_reduced() or bool(Sound.instant_text):
		return
	var n := l.text.length()
	if n == 0:
		return
	l.visible_characters = 0
	var t := l.create_tween()
	t.tween_property(l, "visible_characters", n, minf(float(n) / WRITE_SPEED, WRITE_MAX))
	t.tween_callback(func(): l.visible_characters = -1)
	_writing.append(t)


## Whether any line is still being written out.
func writing() -> bool:
	_writing = _writing.filter(func(t): return t is Tween and (t as Tween).is_valid() and (t as Tween).is_running())
	return not _writing.is_empty()


## Every line being written lands whole.
func finish_writing() -> void:
	for t in _writing:
		if t is Tween and (t as Tween).is_valid():
			(t as Tween).custom_step(60.0)
	_writing.clear()


## The one speaking leans in: their face rises a few pixels and settles.
func _nudge_speaker() -> void:
	if Style.motion_reduced():
		return
	for side in ["center", "right", "left"]:
		if _faces.has(side):
			var face: TextureRect = _faces[side]["node"]
			if face == null or not is_instance_valid(face):
				return
			var old = face.get_meta("nudge") if face.has_meta("nudge") else null
			if old is Tween and (old as Tween).is_valid():
				(old as Tween).kill()
			_place_face(side)
			var rest := face.position.y
			var t := face.create_tween()
			face.set_meta("nudge", t)
			t.tween_property(face, "position:y", rest - 6.0, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			t.tween_property(face, "position:y", rest, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
			return


## A passage, a line at a time: each line ({who, text, speaker}) is said in turn, and a tap
## anywhere brings the next, so their words come one after another as they would be spoken;
## "All of it" shows the rest at once. After the last line, `then`, which sets the replies.
## A passage of one line is said, and `then` follows straight away.
var _pending: Array = []
var _pending_then: Callable
## While a scene is leading up to something (lines, and things to say along the way): how
## to go straight to what it leads to. Set by the scene; cleared when it gets there.
var _skip: Callable


func tell_lines(lines: Array, then: Callable = Callable()) -> void:
	_pending = lines.duplicate()
	_pending_then = then
	_tell_on()


## Whether a passage is still being told.
func telling() -> bool:
	return not _pending.is_empty()


func _tell_on() -> void:
	if not _pending.is_empty():
		var line: Dictionary = _pending.pop_front()
		say(String(line.get("who", "narration")), String(line.get("text", "")), String(line.get("speaker", "")))
	if _pending.is_empty():
		_told()
		return
	set_replies([{"id": "continue", "act": _tell_on},
		{"id": "tell_all", "text": "All of it", "tone": "quiet", "act": tell_rest}])


## The rest of the passage, at once.
func tell_rest() -> void:
	finish_writing()
	var rest := _pending.duplicate()
	_pending.clear()
	for line in rest:
		say(String(line.get("who", "narration")), String(line.get("text", "")), String(line.get("speaker", "")), true)
	_told()


func _told() -> void:
	var then := _pending_then
	_pending_then = Callable()
	if then.is_valid():
		then.call()
	else:
		set_replies([])


func add_to_log(ctrl: Control) -> void:
	_log.add_child(ctrl)
	_scroll_to_end()


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
	if not Style.motion_reduced():
		p.modulate.a = 0.0
		p.create_tween().tween_property(p, "modulate:a", 1.0, 0.3)
	return p


# ---------------------------------------------------------------- where you are

## The strip under the stage: what is being told and how far through it you are. `badge`
## is a rank letter (or ""); `pips` points where you say something, `filled` of them
## behind you. `memory`: this is a memory told again, in rose, under the journal's mark.
func set_header(title: String, badge: String = "", pips: int = 0, filled: int = 0, memory: bool = false) -> void:
	for c in _header.get_children():
		_header.remove_child(c)
		c.queue_free()
	_header_title = title
	_header.visible = title != ""
	if title != "":
		var row := HBoxContainer.new()
		row.name = "HeaderRow"
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 12)
		if memory and badge == "":
			var book := Widgets.icon_rect("journal", 30.0)
			book.name = "Memory"
			book.modulate = Style.ROMANCE
			row.add_child(book)
		if badge != "":
			row.add_child(Widgets.rank_badge(badge, 40.0))
		var l := Style.label(title, Style.SMALL, Style.ROMANCE_LIGHT if memory else Style.TEXT)
		l.name = "Title"
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(l)
		if pips > 0:
			row.add_child(Widgets.pips(pips, filled, Style.ROMANCE if memory else Style.BRASS))
		_header.add_child(row)
	_queue_layout()


func clear_header() -> void:
	set_header("")


func header_text() -> String:
	return _header_title


# ---------------------------------------------------------------- what you can say

## Replies you can give: {id, text, tag, icon, fx, tone, act, extra}. Tones: "plain" (an
## answer), "heart" (only a courtship has it: the one rose thing on the screen), "warm" (a
## friend's), "gold" and "red" (decisions), "locked", "primary" (the way on, in brass), and
## "quiet" (a way out or aside, not something anyone says).
##
## They sit in the tray at the bottom of the screen, which never moves: `prompt` (what is
## being asked) as a caption, the answers under it, and the quiet ones as a row of links
## beneath. A reply whose id is "continue" is not drawn as a button at all: a small mark at
## the foot of the conversation shows there is more, and a tap anywhere brings it.
func set_replies(replies: Array, prompt: String = "") -> void:
	for box in [_replies, _footer]:
		for c in box.get_children():
			box.remove_child(c)
			c.queue_free()
	_continue = Callable()
	var answers := []
	var quiet := []
	var go := {}
	for r in replies:
		for rr in (r["row"] if r.has("row") else [r]):
			if String(rr.get("id", "")) == "continue":
				go = rr
			elif String(rr.get("tone", "plain")) == "quiet":
				quiet.append(rr)
			else:
				answers.append(rr)
	for r in answers:
		_replies.add_child(reply_button(r))
	# Quiet ways on are bare words beside the answers; alone, they are what there is to
	# press, and are drawn as that.
	var alone := answers.is_empty() and go.is_empty()
	for r in quiet:
		_footer.add_child(footer_link(r, alone))
	_prompt.text = prompt
	_prompt.visible = prompt != "" and not answers.is_empty()
	_replies.visible = not answers.is_empty()
	_footer.visible = not quiet.is_empty()
	_tray.visible = not (answers.is_empty() and quiet.is_empty())
	if not answers.is_empty() and not Style.motion_reduced() and is_inside_tree():
		_replies.modulate.a = 0.0
		_replies.create_tween().tween_property(_replies, "modulate:a", 1.0, 0.18)
	else:
		_replies.modulate.a = 1.0
	if go.has("act"):
		_continue = go["act"]
	_show_cue(_continue.is_valid())
	_layout()
	_scroll_to_end()


## What is being asked, above the answers ("" when nothing is).
func prompt_text() -> String:
	return _prompt.text if _prompt.visible else ""


## Only a way on: a tap anywhere on the conversation takes it.
func wait_to_continue(act: Callable, _text: String = "") -> void:
	set_replies([{"id": "continue", "act": act}])


const HINTS := "hints"
const TAP_HINT := "talk_tap"
## Whether this player has gone on with a tap before (asked of the settings once).
static var _tap_known := -1


## The mark that there is more: a small chevron at the foot of the conversation, breathing
## (still under Reduced motion). It is named as the reply it stands for, and pressing it
## goes on, as a tap anywhere does. Until you have gone on once, it says how.
func _make_cue() -> Button:
	var b := Button.new()
	b.name = "Reply_continue"
	b.visible = false
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = "Go on"
	b.add_theme_font_size_override("font_size", Style.text_size(Style.SMALL))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, Style.MUTED)
	for state in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxEmpty.new()
		sb.content_margin_left = 12
		sb.content_margin_right = 56
		b.add_theme_stylebox_override(state, sb)
	b.custom_minimum_size = Vector2(68, 52)
	b.draw.connect(func():
		var c := Vector2(b.size.x - 30.0, b.size.y * 0.5)
		b.draw_polyline(PackedVector2Array([c + Vector2(-11, -5), c + Vector2(0, 6), c + Vector2(11, -5)]), Style.BRASS, 3.5, true))
	b.pressed.connect(_go_on)
	return b


func _show_cue(on: bool) -> void:
	var old = _cue.get_meta("pulse") if _cue.has_meta("pulse") else null
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	_cue.modulate.a = 1.0
	_cue.visible = on
	# Room for the mark under the last line while it shows.
	_log_pad.add_theme_constant_override("margin_bottom", 58 if on else 18)
	if not on:
		return
	if _tap_known < 0:
		_tap_known = 1 if Sound.has_seen_hint(HINTS, TAP_HINT) else 0
	_cue.text = "" if _tap_known == 1 else "Tap to go on"
	if not Style.motion_reduced() and is_inside_tree():
		var t := _cue.create_tween().set_loops()
		_cue.set_meta("pulse", t)
		t.tween_property(_cue, "modulate:a", 0.4, 0.7).set_trans(Tween.TRANS_SINE)
		t.tween_property(_cue, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE)


## Go on to the next line: what a tap, the mark, or Enter does.
func _go_on() -> void:
	if not _continue.is_valid():
		return
	if _tap_known != 1:
		_tap_known = 1
		Sound.mark_hint_seen(HINTS, TAP_HINT)
	var act := _continue
	_continue = Callable()
	act.call()


func _gui_input(event: InputEvent) -> void:
	_tap(event)


## A tap (released without a drag) on the stage or the conversation goes on.
## Where the finger went down, so a release after scrolling the talk doesn't count as a tap.
var _tap_from := Vector2.INF
## The last press or release handled: one that reaches here twice (from the conversation
## and again from the screen under it) is one tap.
var _tap_seen := [-1, false]


func _tap(event: InputEvent) -> void:
	var pointer := event is InputEventMouseButton or event is InputEventScreenTouch
	if not pointer or (event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT):
		return
	var stamp := [Engine.get_process_frames(), bool(event.pressed)]
	if stamp == _tap_seen:
		return
	_tap_seen = stamp
	# A tap while words are being written finishes them, and goes no further.
	if not event.pressed and writing():
		finish_writing()
		_tap_from = Vector2.INF
		return
	if not _continue.is_valid():
		return
	if event.pressed:
		_tap_from = event.position
		return
	var dragged: bool = _tap_from != Vector2.INF and _tap_from.distance_to(event.position) > Widgets.TAP_SLOP
	_tap_from = Vector2.INF
	if not dragged:
		_go_on()


## Kinds of answer, each with its own ground and edge, so one can be told from another
## without reading: [fill, edge].
const ANSWER_LOOKS := {
	"gold": [Color("3a2c10"), Style.BRASS],
	"red": [Color("3c1512"), Style.ENEMY],
	"heart": [Color("2a1f26"), Style.ROMANCE],
	"warm": [Style.RAISED, Color(Style.BRASS, 0.6)],
	"primary": [Style.BRASS, Style.BRASS],
}


## An answer: a round badge with its kind's icon, then the words, with what it is and what
## it costs under them. Full width, never shorter than a touch target, as tall as its
## words need.
func reply_button(r: Dictionary) -> Control:
	var tone := String(r.get("tone", "plain"))
	if tone == "quiet":
		return footer_link(r, true)
	var locked := tone == "locked"
	# "primary": the way on or out of a talk, full width in brass, not a line anyone says.
	var primary := tone == "primary"
	var b := Button.new()
	b.name = "Reply_" + String(r["id"])
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.disabled = locked
	b.focus_mode = Control.FOCUS_NONE
	var look: Array = ANSWER_LOOKS.get(tone, [Color(Style.NIGHT, 0.6), Style.RULE.darkened(0.2)] if locked else [Style.RAISED, Style.RULE])
	var bg: Color = look[0]
	var edge: Color = look[1]
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := Style.box(bg if state != "pressed" else bg.darkened(0.2), edge if state != "hover" else edge.lightened(0.2), 2, 16)
		b.add_theme_stylebox_override(state, sb)
	var row := HBoxContainer.new()
	row.name = "Row"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 14
	row.offset_right = -16
	row.offset_top = 10
	row.offset_bottom = -10
	if not primary:
		var key := "lock" if locked else String(r.get("icon", ""))
		if key == "":
			key = "journal" if bool(r.get("bare", false)) else ("book" if tone in ["gold", "red"] else "talk")
		row.add_child(answer_badge(key, tone))
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_theme_constant_override("separation", 2)
	var shown := String(r["text"]) if primary or bool(r.get("bare", false)) else "\"%s\"" % String(r["text"])
	var ink := Style.BRASS_INK if primary else (Style.MUTED if locked else Style.TEXT)
	var text := Style.label(shown, Style.BODY, ink)
	text.name = "Text"
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if primary:
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(text)
	var tag_row := marks(r, tone, false)
	if tag_row != null:
		box.add_child(tag_row)
	if r.has("extra"):
		box.add_child(r["extra"])
	row.add_child(box)
	b.add_child(row)
	# Tall enough for its words, and never under its touch height.
	var floor_y := Style.TOUCH
	row.minimum_size_changed.connect(func(): b.custom_minimum_size.y = maxf(floor_y, row.get_combined_minimum_size().y + 20))
	b.custom_minimum_size.y = floor_y
	if not locked and r.has("act"):
		var act: Callable = r["act"]
		b.pressed.connect(func():
			Sound.play("page", 0.0, 0.05)
			act.call())
	return b


## The round badge at the head of an answer: its kind as an icon (in a node named Kind),
## in the kind's colour.
static func answer_badge(key: String, tone: String) -> Control:
	var ink := tone_ink(tone)
	var c := Control.new()
	c.name = "Badge"
	c.custom_minimum_size = Vector2(44, 44)
	c.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func():
		c.draw_circle(Vector2(22, 22), 21.0, Color(Style.NIGHT, 0.55))
		c.draw_arc(Vector2(22, 22), 20.0, 0.0, TAU, 40, Color(ink, 0.8), 2.0, true))
	var ic := Widgets.icon_rect(key, 26.0)
	ic.name = "Kind"
	ic.modulate = ink
	ic.position = Vector2(9, 9)
	ic.size = Vector2(26, 26)
	c.add_child(ic)
	return c


## A quiet way on or out, in the tray's footer: bare words with a full touch area beside
## the answers; with `alone` (nothing else to press) a slim outlined pill.
func footer_link(r: Dictionary, alone: bool) -> Button:
	var b := Button.new()
	b.name = "Reply_" + String(r["id"])
	b.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "focus"]:
		var sb: StyleBox = Style.box(Color(Style.RAISED, 0.5 if state == "pressed" else 0.0), Style.MUTED if state == "hover" else Style.RULE, 2, 40) if alone else StyleBoxEmpty.new()
		b.add_theme_stylebox_override(state, sb)
	var box := VBoxContainer.new()
	box.name = "Words"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 0)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var pad := 26.0 if alone else 14.0
	box.offset_left = pad
	box.offset_right = -pad
	# As wide as its words, but never wider than the column: then they wrap.
	var room := minf(_screen().x, Style.COLUMN_MAX) - SIDE * 2.0 - pad * 2.0
	var lines := [[String(r["text"]), Style.BODY, Style.TEXT if alone else Style.MUTED, "Text"]]
	if String(r.get("tag", "")) != "":
		lines.append([String(r["tag"]), Style.SMALL, Style.MUTED.darkened(0.15), "Tag"])
	for line in lines:
		var l := Style.label(String(line[0]), int(line[1]), line[2])
		l.name = String(line[3])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var font := l.get_theme_font("font")
		var wide := font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x + 4.0 if font != null else room
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = minf(wide, room)
		box.add_child(l)
	b.add_child(box)
	var fit := func():
		var m := box.get_combined_minimum_size()
		b.custom_minimum_size = Vector2(m.x + pad * 2.0, maxf(Style.TOUCH, m.y + 16.0))
	box.minimum_size_changed.connect(fit)
	fit.call()
	if r.has("act"):
		var act: Callable = r["act"]
		b.pressed.connect(func():
			Sound.play("page", 0.0, 0.05)
			act.call())
	return b


## The reply with this id: an answer or a link in the tray, or the mark that there is more
## ("continue") while it shows.
func reply_node(id: String) -> Button:
	if id == "continue":
		return _cue if _cue != null and _cue.visible else null
	return _tray.find_child("Reply_" + id, true, false) as Button


## Press a reply by id, as a tap would.
func choose(id: String) -> bool:
	# Asked for an answer that comes after what is being told: hear it out first.
	if reply_node(id) == null:
		_hear_out()
	var b := reply_node(id)
	if b == null or b.disabled:
		return false
	b.pressed.emit()
	return true


## Hears out whatever is being told, and goes past anything leading up to the answers.
func _hear_out() -> void:
	for i in 40:
		if telling():
			tell_rest()
		elif _skip.is_valid():
			var skip := _skip
			_skip = Callable()
			skip.call()
		else:
			return


## Whether a reply is on offer (asked about one that comes after a passage still being
## told, the passage is heard out first, as choose() does).
func has_reply(id: String, enabled_only: bool = true) -> bool:
	if reply_node(id) == null:
		_hear_out()
	var b := reply_node(id)
	return b != null and (not enabled_only or not b.disabled)


## The replies on offer once any passage being told has been heard out.
func reply_ids() -> Array:
	_hear_out()
	var out: Array = _tray.find_children("Reply_*", "Button", true, false).map(func(c): return String(c.name).trim_prefix("Reply_"))
	if _cue.visible:
		out.push_front("continue")
	return out


## Everything said so far, as plain text, under what the header says is being told.
func log_text() -> String:
	var out := PackedStringArray()
	if _header_title != "":
		out.append(_header_title)
	for line in _log.find_children("*", "Label", true, false):
		out.append((line as Label).text)
	return "\n".join(out)


var _scrolling := false


## The newest line stays in view, just above what you can say.
func _scroll_to_end() -> void:
	if _scrolling or not is_inside_tree():
		return
	_scrolling = true
	await get_tree().process_frame
	_scrolling = false
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


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
	elif event.is_action_pressed("ui_accept") and _continue.is_valid():
		get_viewport().set_input_as_handled()
		if writing():
			finish_writing()
		else:
			_go_on()
