## A conversation face to face: a stage (where you are, who you're talking to, a nameplate)
## over a running conversation (their lines on the left, yours on the right, narration in
## the middle) and the replies you can give. Romance talks and the captains' talks at the
## fire are built on it; a subclass fills it.
extends Control

const Style = preload("res://scripts/ui/style.gd")
const Widgets = preload("res://scripts/ui/widgets.gd")
const StoryArt = preload("res://scripts/ui/story_art.gd")

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
	return art


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
		row.add_child(l)
	p.add_child(row)
	if not Style.motion_reduced():
		p.modulate.a = 0.0
		p.create_tween().tween_property(p, "modulate:a", 1.0, 0.3)
	return p


# ---------------------------------------------------------------- the conversation

func clear_log() -> void:
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
	if not Style.motion_reduced():
		p.modulate.a = 0.0
		p.create_tween().tween_property(p, "modulate:a", 1.0, 0.3)
	return p


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
