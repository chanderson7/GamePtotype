## A conversation face to face: a stage (where you are, who you're talking to, a nameplate)
## over a running conversation (their lines on the left, yours on the right, narration in
## the middle) and the replies you can give. Romance talks and the captains' talks at the
## fire are built on it; a subclass fills it.
extends Control

const Style = preload("res://scripts/ui/style.gd")
const Widgets = preload("res://scripts/ui/widgets.gd")
const StoryArt = preload("res://scripts/ui/story_art.gd")

const STAGE_SHARE := 0.46

signal closed

var stage: Control
var _backdrop: Control
var _plate: VBoxContainer
var _scroll: ScrollContainer
var _log: VBoxContainer
var _replies: VBoxContainer
var _continue: Callable
var _faces := {}


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
	var cap_label := Style.label(caption, Style.SMALL, Style.TEXT)
	cap_label.name = "Caption"
	cap.add_child(cap_label)
	stage.add_child(cap)
	var x := Button.new()
	x.name = "Close"
	x.custom_minimum_size = Vector2(64, 64)
	x.icon = Widgets.icon("cancel")
	x.expand_icon = true
	x.add_theme_stylebox_override("normal", Style.box(Color(Style.NIGHT, 0.75), Style.RULE, 2, 32))
	x.add_theme_stylebox_override("pressed", Style.box(Style.NIGHT, Style.BRASS, 2, 32))
	x.anchor_left = 1.0
	x.anchor_right = 1.0
	x.offset_left = -84
	x.offset_right = -20
	x.offset_top = 16
	x.offset_bottom = 80
	x.pressed.connect(close)
	stage.add_child(x)
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


func _layout() -> void:
	var s := size if size != Vector2.ZERO else get_viewport_rect().size
	var insets: Dictionary = Style.safe_insets(get_viewport())
	var h := roundf(s.y * STAGE_SHARE)
	stage.position = Vector2.ZERO
	stage.size = Vector2(s.x, h)
	_scroll.position = Vector2(0, h)
	_scroll.size = Vector2(s.x, s.y - h - float(insets.get("bottom", 0.0)))
	if _backdrop != null:
		_backdrop.position = Vector2.ZERO
		_backdrop.size = stage.size
	for side in _faces:
		_place_face(side)


## A painted room or place as a backdrop, tinted for the hour.
static func room(id: String, when: String) -> TextureRect:
	var art := TextureRect.new()
	art.name = "Room"
	art.texture = StoryArt.texture("res://assets/locations/%s.png" % id)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.modulate = {"night": Color(0.5, 0.54, 0.78), "dusk": Color(1.0, 0.82, 0.68), "morning": Color(1.0, 0.96, 0.92)}.get(when, Color.WHITE)
	return art


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
	face.texture = tex
	face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if pixel else CanvasItem.TEXTURE_FILTER_LINEAR
	face.modulate = Color(0.5, 0.5, 0.58) if dim else Color.WHITE
	_faces[side] = {"node": face, "height": height}
	_place_face(side)


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
		face.position = Vector2(s.x * (0.02 if two else 0.04), s.y - h)
	else:
		face.position = Vector2(s.x * 0.98 - w, s.y - h)


## Their name and what stands between you, at the foot of the stage.
func set_plate(name_text: String, chips: Array) -> void:
	for c in _plate.get_children():
		_plate.remove_child(c)
		c.queue_free()
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 12)
	row.add_theme_constant_override("v_separation", 6)
	var name_label := Style.label(name_text, Style.LARGE, Style.TEXT)
	name_label.name = "Name"
	var display := Style.display_font()
	if display != null:
		name_label.add_theme_font_override("font", display)
	row.add_child(name_label)
	for c in chips:
		(c as Control).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(c)
	_plate.add_child(row)


## A small chip with an icon, for the nameplate.
static func plate_chip(text: String, tone: Color, icon: String = "") -> PanelContainer:
	var p := PanelContainer.new()
	var sb := Style.box(Color(Style.NIGHT, 0.85), tone, 2, 20)
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	if icon != "":
		var i := Widgets.icon_rect(icon, 22)
		i.modulate = tone
		h.add_child(i)
	h.add_child(Style.label(text, Style.SMALL, Style.TEXT))
	p.add_child(h)
	return p


# ---------------------------------------------------------------- the conversation

func clear_log() -> void:
	for c in _log.get_children():
		_log.remove_child(c)
		c.queue_free()


## A line in the conversation. `who` is "them" (left, under `speaker`), "you" (right) or
## "narration" (centred, no bubble).
func say(who: String, text: String, speaker: String = "") -> Control:
	var holder := HBoxContainer.new()
	holder.name = "Line"
	if who == "narration":
		var l := Style.label(text, Style.BODY - 2, Style.MUTED)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.name = "Narration"
		holder.add_child(l)
		_log.add_child(holder)
		return holder
	var bubble := PanelContainer.new()
	bubble.name = "Them" if who == "them" else "You"
	var mine := who == "you"
	var sb := Style.box(Color("26304f") if mine else Color("1d2238"), Style.PLAYER_LIGHT.darkened(0.55) if mine else Style.RULE, 2, 16)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	bubble.add_theme_stylebox_override("panel", sb)
	bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bubble.size_flags_stretch_ratio = 5.0
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	if speaker != "":
		v.add_child(Style.label(speaker.to_upper(), Style.SMALL - 2, Style.BRASS))
	var l := Style.label(text, Style.BODY, Style.TEXT)
	l.name = "Words"
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	bubble.add_child(v)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.size_flags_stretch_ratio = 1.0
	if mine:
		holder.add_child(gap)
		holder.add_child(bubble)
	else:
		holder.add_child(bubble)
		holder.add_child(gap)
	_log.add_child(holder)
	return holder


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


## Replies you can give: {id, text, tag, tone ("plain", "gold", "red", "locked", "quiet"),
## act, extra}. A reply with only `act` and "Continue" text is the tap-to-continue.
func set_replies(replies: Array) -> void:
	for c in _replies.get_children():
		_replies.remove_child(c)
		c.queue_free()
	_continue = Callable()
	for r in replies:
		_replies.add_child(reply_button(r))
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
	var b := Button.new()
	b.name = "Reply_" + String(r["id"])
	b.size_flags_horizontal = Control.SIZE_SHRINK_END if not quiet else Control.SIZE_SHRINK_CENTER
	var wide := size.x if size.x > 0 else 720.0
	b.custom_minimum_size = Vector2(minf(wide * (0.5 if quiet else 0.84), 620.0), 0)
	b.disabled = locked
	b.focus_mode = Control.FOCUS_NONE
	var bg: Color = {"gold": Color("3a2c10"), "red": Color("3c1512"), "locked": Color(Style.NIGHT, 0.6), "quiet": Color(0, 0, 0, 0)}.get(tone, Style.RAISED)
	var edge: Color = {"gold": Style.BRASS, "red": Style.ENEMY, "locked": Style.RULE.darkened(0.2), "quiet": Style.RULE}.get(tone, Style.RULE)
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
	var shown := String(r["text"]) if quiet or bool(r.get("bare", false)) else "\"%s\"" % String(r["text"])
	var text := Style.label(shown, Style.BODY, Style.MUTED if locked or quiet else Style.TEXT)
	text.name = "Text"
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if quiet:
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(text)
	var tag := String(r.get("tag", ""))
	if tag != "" or locked:
		var tag_row := HBoxContainer.new()
		tag_row.add_theme_constant_override("separation", 6)
		tag_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if locked:
			tag_row.add_child(Widgets.icon_rect("lock", 18))
		var tl := Style.label(tag, Style.SMALL - 2, Style.BRASS if tone == "gold" else (Style.ENEMY_LIGHT if tone == "red" else Style.MUTED))
		tl.name = "Tag"
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag_row.add_child(tl)
		box.add_child(tag_row)
	if r.has("extra"):
		box.add_child(r["extra"])
	b.add_child(box)
	box.minimum_size_changed.connect(func(): b.custom_minimum_size.y = box.get_combined_minimum_size().y + 20)
	b.custom_minimum_size.y = 64 if quiet else 72
	if not locked and r.has("act"):
		var act: Callable = r["act"]
		b.pressed.connect(func():
			Sound.play("page", 0.0, 0.05)
			act.call())
	return b


## Press a reply by id, as a tap would.
func choose(id: String) -> bool:
	var b := _replies.get_node_or_null("Reply_" + id) as Button
	if b == null or b.disabled:
		return false
	b.pressed.emit()
	return true


func has_reply(id: String, enabled_only: bool = true) -> bool:
	var b := _replies.get_node_or_null("Reply_" + id) as Button
	return b != null and (not enabled_only or not b.disabled)


func reply_ids() -> Array:
	return _replies.get_children().map(func(c): return String(c.name).trim_prefix("Reply_"))


## Everything said so far, as plain text.
func log_text() -> String:
	var out := PackedStringArray()
	for line in _log.find_children("*", "Label", true, false):
		out.append((line as Label).text)
	return "\n".join(out)


func _scroll_to_end() -> void:
	await get_tree().process_frame
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
