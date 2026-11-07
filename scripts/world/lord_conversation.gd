## Talking to a lord, face to face where you met: the place behind them (a painted
## location, or the settlement as the game paints it, at the hour it is), their portrait
## and banner, what they think of you, and one exchange at a time. You answer with a line,
## tagged with what it does; nothing irreversible happens on a stray tap. The rules are in
## lord_talk.gd; this only says them.
extends Control

const Data = preload("res://scripts/world/world_data.gd")
const Style = preload("res://scripts/ui/style.gd")
const Widgets = preload("res://scripts/ui/widgets.gd")
const Heraldry = preload("res://scripts/ui/heraldry.gd")
const CaptainArt = preload("res://scripts/ui/captain_art.gd")
const SettlementVista = preload("res://scripts/ui/settlement_vista.gd")
const SettlementScene = preload("res://scripts/ui/settlement_scene.gd")
const StoryArt = preload("res://scripts/ui/story_art.gd")
const LordVoice = preload("res://scripts/data/lord_voice.gd")
const Lords = preload("res://scripts/data/lords.gd")
const Troops = preload("res://scripts/data/troops.gd")
const Jobs = preload("res://scripts/data/jobs.gd")
const LordTalk = preload("res://scripts/world/lord_talk.gd")
const HallScene = preload("res://scripts/ui/hall_scene.gd")
const TalkView = preload("res://scripts/ui/talk_view.gd")

## Replies that take you back or away: they sit in a footer of two quiet buttons, not in
## the list of things to say.
const FOOTER_IDS := ["back", "leave"]

## Places with a painted picture of their own.
const PAINTED := ["ravensford", "qasr_hamra", "kitayama"]
## The portrait is drawn at this many screen pixels to one of its own.
const FACE_SCALE := 5.0
const STAGE_SHARE := 0.5
## How much of the stage a painted settlement fills, from the foot up.
const VISTA_SHARE := 0.72

signal closed
## Asked of the screen hosting the talk (the map): show the war news, fight, ride along.
signal wants_news
signal wants_fight
signal wants_follow(party_id: int)

var gs = null
var world = null
var lord: Dictionary = {}
## "road" (met on the road), "hostile" (they've blocked your road), "captive" (at your
## camp), "hall" (indoors, at a settlement where you both are).
var mode := "road"
## Why they stopped you: "first", "news", "army" or "" (you asked to talk).
var reason := ""

var _stage: Control
var _regard_chip: PanelContainer
var _talk: VBoxContainer
var _scroll: ScrollContainer
var _banner_realm := ""
## Who said what last: your line, shown dimmed over their answer.
var _said := ""
var _beat := ""
## The news they told you in this talk.
var _news: Array = []


static func open(parent: Node, game, lord_id: int, how: String = "road", why: String = ""):
	var c = new()
	c.gs = game
	c.world = game.world
	c.lord = game.world.lord_by_id(lord_id)
	c.mode = how
	c.reason = why
	c.name = "LordConversation"
	parent.add_child(c)
	return c


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Style.NIGHT
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_build_stage()
	_scroll = ScrollContainer.new()
	_scroll.name = "Talk"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 24)
	pad.add_theme_constant_override("margin_top", 14)
	pad.add_theme_constant_override("margin_bottom", 28)
	_scroll.add_child(pad)
	_talk = VBoxContainer.new()
	_talk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_talk.add_theme_constant_override("separation", 12)
	pad.add_child(_talk)
	resized.connect(_layout)
	_layout()
	if mode == "captive":
		_beat_captive()
	elif mode == "hostile":
		_beat_challenge(true)
	else:
		_beat_greet()


func _layout() -> void:
	var s := size if size != Vector2.ZERO else get_viewport_rect().size
	var insets: Dictionary = Style.safe_insets(get_viewport())
	var stage_h := roundf(s.y * STAGE_SHARE)
	_stage.position = Vector2.ZERO
	_stage.size = Vector2(s.x, stage_h)
	_scroll.position = Vector2(0, stage_h)
	_scroll.size = Vector2(s.x, s.y - stage_h - float(insets.get("bottom", 0.0)))
	_place_backdrop()


# ---------------------------------------------------------------- the scene

## Where you are: the settlement you're at or nearest, or your camp for a captive.
func place_id() -> String:
	if mode == "captive":
		return "company_camp"
	if mode == "hall" and world.here() != "":
		return world.here()
	var p = world.player()
	if p != null and not p.moving() and Data.SETTLEMENTS.has(p.node):
		return p.node
	return world.nearest_place(world.party_pos(p)) if p != null else ""


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


## "On the road below Ravensford · morning".
func caption() -> String:
	var id := place_id()
	var when := time_word(world.hour)
	if mode == "captive":
		return "Your camp · %s · captive" % when
	if mode == "hall" and Data.SETTLEMENTS.has(id):
		var g: Dictionary = world.gathering_at(id)
		if world.gathering_on(g):
			return "In the hall at %s · %s · %s" % [Data.settlement(id)["name"], world.gathering_name(g), when]
		return "In the hall at %s · %s" % [Data.settlement(id)["name"], when]
	var info: Dictionary = Data.settlement(id) if Data.SETTLEMENTS.has(id) else {}
	if info.is_empty():
		return "On the road · %s" % when
	var name := String(info["name"])
	var p = world.player()
	if p != null and not p.moving() and p.node == id:
		return "At %s · %s" % [name, when]
	if mode == "hostile" and String(info["type"]) != Data.VILLAGE:
		return "Before %s · %s" % [name, when]
	if String(info["type"]) == Data.VILLAGE:
		return "On the road near %s · %s" % [name, when]
	return "On the road below %s · %s" % [name, when]


var _backdrop: Control
var _backdrop_vista := false


func _build_stage() -> void:
	_stage = Control.new()
	_stage.name = "Stage"
	_stage.clip_contents = true
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	var id := place_id()
	var when := time_word(world.hour)
	if mode == "hall" and Data.SETTLEMENTS.has(id):
		var owner: String = world.owner_of(id)
		var flag := owner if Heraldry.REALM_SIZES.has(owner) else Heraldry.realm_of_culture(Data.culture_of(owner))
		_backdrop = HallScene.rect(Data.culture_of(Data.settlement(id)["faction"]), flag, when, id.hash())
	elif id in PAINTED or id == "company_camp":
		var art := TextureRect.new()
		art.name = "Painted"
		art.texture = StoryArt.texture("res://assets/locations/%s.png" % id)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# The painting is by day: dusk warms it and night cools and darkens it.
		art.modulate = {"night": Color(0.42, 0.47, 0.72), "dusk": Color(1.0, 0.78, 0.62), "morning": Color(1.0, 0.95, 0.9)}.get(when, Color.WHITE)
		_backdrop = art
	elif Data.SETTLEMENTS.has(id):
		var p := SettlementScene.params(world, id)
		p["night"] = when == "night"
		var vista := SettlementVista.from_preset(p, 400.0)
		_backdrop = vista
		_backdrop_vista = true
		var sky := ColorRect.new()
		sky.name = "SkyFill"
		sky.color = Color("1b2440") if p["night"] else Color("8fb6dc")
		sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stage.add_child(sky)
		if when == "dusk":
			vista.modulate = Color(1.0, 0.82, 0.68)
			sky.modulate = vista.modulate
	if _backdrop != null:
		_stage.add_child(_backdrop)
	# A dark fade at the foot of the picture, for the name to sit on.
	var fade := TextureRect.new()
	fade.name = "Fade"
	var grad := Gradient.new()
	grad.set_color(0, Color(Style.NIGHT, 0.0))
	grad.set_color(1, Color(Style.NIGHT, 0.95))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 64
	fade.texture = gt
	fade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fade.stretch_mode = TextureRect.STRETCH_SCALE
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.anchor_left = 0.0
	fade.anchor_right = 1.0
	fade.anchor_top = 0.55
	fade.anchor_bottom = 1.0
	_stage.add_child(fade)
	# Where and when, top left; leave, top right.
	var cap := PanelContainer.new()
	var cb := Style.box(Color(Style.NIGHT, 0.7), Color(0, 0, 0, 0), 0, 18)
	cb.content_margin_left = 16
	cb.content_margin_right = 16
	cap.add_theme_stylebox_override("panel", cb)
	cap.position = Vector2(20, 20)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Where, at what gathering, and the hour: a pin, a cup and the sun or the moon.
	var feast: bool = mode == "hall" and Data.SETTLEMENTS.has(id) and world.gathering_on(world.gathering_at(id))
	cap.add_child(TalkView.caption_row(caption(), "cup" if feast else ""))
	_stage.add_child(cap)
	_stage.add_child(TalkView.close_button(_leave))
	# Their face, their banner, and yours.
	var face := TextureRect.new()
	face.name = "Face"
	face.texture = CaptainArt.texture(LordVoice.portrait_record(lord))
	face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(face)
	var realm := String(lord.get("realm", ""))
	_banner_realm = realm if Heraldry.REALM_SIZES.has(realm) else Heraldry.realm_of_culture(String(lord.get("culture", "")))
	var theirs := Widgets.banner(_banner_realm, Vector2(70, 104))
	theirs.name = "TheirBanner"
	_stage.add_child(theirs)
	var yours := PanelContainer.new()
	yours.name = "YourBanner"
	yours.add_theme_stylebox_override("panel", Style.box(Color(Style.NIGHT, 0.8), Style.BRASS, 3, 6))
	yours.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if gs.is_crowned():
		yours.add_child(Widgets.banner("crown", Vector2(56, 64)))
	else:
		yours.add_child(Widgets.icon_rect("company", 56))
	_stage.add_child(yours)
	# The name, and what they think of you.
	var plate := VBoxContainer.new()
	plate.name = "Nameplate"
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_theme_constant_override("separation", 4)
	if String(lord.get("captive_of", "")) == "player":
		plate.add_child(Widgets.chip("Your captive", Style.MORALE_MID, "", "lock"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var name_label := Style.name_label(LordTalk.short_name(lord))
	name_label.name = "LordName"
	name_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	var display := Style.display_font()
	if display != null:
		name_label.add_theme_font_override("font", display)
	row.add_child(name_label)
	_regard_chip = PanelContainer.new()
	row.add_child(_regard_chip)
	plate.add_child(row)
	_stage.add_child(plate)
	_refresh_regard()


## Lay the stage out for its size: picture covering it, face bottom left, banners right.
func _place_backdrop() -> void:
	var s := _stage.size
	if _backdrop != null:
		if _backdrop_vista:
			# The vista is wide and short: stand it on the foot of the stage, centred, its
			# sides cut, and carry its sky up over the top.
			var h := roundf(s.y * VISTA_SHARE)
			var w := maxf(s.x, h * float(SettlementScene.W) / float(SettlementScene.H))
			h = w * float(SettlementScene.H) / float(SettlementScene.W)
			_backdrop.custom_minimum_size = Vector2.ZERO
			_backdrop.position = Vector2((s.x - w) * 0.5, s.y - h)
			_backdrop.size = Vector2(w, h)
			var sky := _stage.get_node_or_null("SkyFill") as ColorRect
			if sky != null:
				sky.size = Vector2(s.x, s.y - h + 2.0)
				var scene: Dictionary = _backdrop.get("_scene")
				if scene.get("sky") is Image:
					sky.color = (scene["sky"] as Image).get_pixel(0, 0)
		else:
			_backdrop.position = Vector2.ZERO
			_backdrop.size = s
	var face := _stage.get_node("Face") as TextureRect
	var fs := Vector2(48, 64) * FACE_SCALE * clampf(s.x / 720.0, 0.6, 1.4)
	face.size = fs
	face.position = Vector2(24, s.y - fs.y - 64)
	var theirs := _stage.get_node("TheirBanner") as Control
	theirs.position = Vector2(face.position.x + fs.x + 6, s.y - 64 - 104 - 24)
	var yours := _stage.get_node("YourBanner") as Control
	yours.position = Vector2(s.x - 24 - 80, s.y * 0.48)
	var plate := _stage.get_node("Nameplate") as Control
	plate.position = Vector2(24, s.y - 60 - (36 if plate.get_child_count() > 1 else 0))
	plate.size = Vector2(s.x - 48, 56)


func _refresh_regard() -> void:
	for c in _regard_chip.get_children():
		_regard_chip.remove_child(c)
		c.queue_free()
	var value := LordTalk.regard(gs, lord)
	var tone := Style.MORALE_HIGH if value >= 10 else (Style.MORALE_MID if value >= -14 else Style.MORALE_LOW)
	var sb := Style.box(Color(Style.NIGHT, 0.85), tone, 2, 20)
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	_regard_chip.add_theme_stylebox_override("panel", sb)
	_regard_chip.name = "Regard"
	_regard_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var heart := Widgets.icon_rect("bond", 26)
	heart.modulate = tone
	h.add_child(heart)
	var sworn := String(lord.get("realm", "")) == Data.CROWN
	var t := Style.label("Sworn to you" if sworn else LordTalk.regard_text(value), Style.SMALL, Style.BRASS if sworn else Style.TEXT)
	t.name = "RegardText"
	h.add_child(t)
	_regard_chip.add_child(h)


# ---------------------------------------------------------------- the talk

## One exchange: your last line, dimmed; their answer (the plate says who); anything to
## show with it; your replies; and a footer with the way back and the way out.
func _show(speech: String, extras: Array, replies: Array) -> void:
	for c in _talk.get_children():
		_talk.remove_child(c)
		c.queue_free()
	if _said != "":
		var said := Style.label("\"%s\"" % _said, Style.SMALL, Style.MUTED)
		said.name = "YouSaid"
		said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		said.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_talk.add_child(said)
	var line := Style.label(speech, Style.BODY, Style.TEXT)
	line.name = "Speech"
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_talk.add_child(line)
	for e in extras:
		_talk.add_child(e)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	_talk.add_child(gap)
	var footer := []
	for r in replies:
		if r.has("row"):
			_talk.add_child(_order_row(r))
		elif String(r.get("id", "")) in FOOTER_IDS:
			footer.append(r)
		else:
			_talk.add_child(_reply(r))
	if not footer.is_empty():
		_talk.add_child(_footer(footer))
	_refresh_regard()
	_scroll.scroll_vertical = 0
	if not Style.motion_reduced():
		_talk.modulate.a = 0.0
		create_tween().tween_property(_talk, "modulate:a", 1.0, 0.18)


## The text of their current answer.
func speech_text() -> String:
	var n := _talk.get_node_or_null("Speech") as Label
	return n.text if n != null else ""


## A reply you can give: {id, text, tone ("plain", "gold", "red", "locked"), act, and
## under its words: icon (what kind of thing it is), fx (what it does, as chips, see
## TalkView.fx_chips), tag (any words still needed), extra (a Control shown inside it)}.
func _reply(r: Dictionary) -> Control:
	var tone := String(r.get("tone", "plain"))
	var locked := tone == "locked"
	var b := Button.new()
	b.name = "Reply_" + String(r["id"])
	b.size_flags_horizontal = Control.SIZE_SHRINK_END
	b.custom_minimum_size = Vector2(minf(size.x * 0.8 if size.x > 0 else 560.0, 600.0), 0)
	b.disabled = locked
	b.focus_mode = Control.FOCUS_NONE
	var bg: Color = {"gold": Color("3a2c10"), "red": Color("3c1512"), "locked": Color(Style.NIGHT, 0.6)}.get(tone, Style.RAISED)
	var edge: Color = {"gold": Style.BRASS, "red": Style.ENEMY, "locked": Style.RULE.darkened(0.2)}.get(tone, Style.RULE)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := Style.box(bg if state != "pressed" else bg.darkened(0.2), edge if state != "hover" else edge.lightened(0.2), 2, 16)
		sb.content_margin_left = 18
		sb.content_margin_right = 18
		sb.content_margin_top = 10
		sb.content_margin_bottom = 10
		b.add_theme_stylebox_override(state, sb)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 18
	box.offset_right = -18
	box.offset_top = 10
	box.offset_bottom = -10
	var text := Style.label("\"%s\"" % String(r["text"]), Style.BODY, Style.MUTED if locked else Style.TEXT)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(text)
	var marks := TalkView.marks(r, tone)
	if marks != null:
		box.add_child(marks)
	if r.has("extra"):
		box.add_child(r["extra"])
	b.add_child(box)
	# A button doesn't grow to its children: size it to them once they've measured, and
	# never under a full touch target.
	box.minimum_size_changed.connect(func(): b.custom_minimum_size.y = maxf(Style.TOUCH, box.get_combined_minimum_size().y + 20))
	b.custom_minimum_size.y = Style.TOUCH
	if not locked and r.has("act"):
		var act: Callable = r["act"]
		var said := String(r["text"])
		b.pressed.connect(func():
			Sound.play("page", 0.0, 0.05)
			_said = said
			act.call())
	return b


## The way back ("Something else", "Another time") and the way out ("Safe roads."), side
## by side under the replies: quiet, with an icon each, the words as you'd say them.
func _footer(replies: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Footer"
	row.add_theme_constant_override("separation", 12)
	for r in replies:
		var b := Button.new()
		b.name = "Reply_" + String(r["id"])
		b.text = String(r["text"])
		b.icon = Widgets.icon("ride" if String(r["id"]) == "leave" else "back")
		b.add_theme_constant_override("icon_max_width", 30)
		b.add_theme_constant_override("h_separation", 10)
		b.custom_minimum_size = Vector2(0, Style.TOUCH)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", Style.text_size(Style.SMALL))
		for state in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(state, Style.box(Color(0, 0, 0, 0), Style.RULE if state != "hover" else Style.MUTED, 2, 16))
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(c, Style.MUTED)
		for c in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
			b.add_theme_color_override(c, Style.MUTED)
		if r.has("act"):
			var act: Callable = r["act"]
			var said := String(r["text"])
			b.pressed.connect(func():
				Sound.play("page", 0.0, 0.05)
				_said = said
				act.call())
		row.add_child(b)
	return row


## Orders to a lord sworn to you, as one row of three: Follow, Hold, Free. The order they
## have now is lit and can't be pressed again. `r` is {"row": [{id, label, icon, tip, lit,
## act}]}.
func _order_row(r: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.name = "Orders"
	box.add_theme_constant_override("separation", 6)
	box.add_child(Widgets.section("Orders"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	for o in r["row"]:
		var lit := bool(o.get("lit", false))
		var b := Widgets.icon_tile(String(o["icon"]), String(o["label"]), lit, func(): pass, "Reply_" + String(o["id"]))
		b.custom_minimum_size = Vector2(0, 100)
		b.tooltip_text = String(o.get("tip", ""))
		b.focus_mode = Control.FOCUS_NONE
		b.disabled = lit or not o.has("act")
		if lit:
			b.add_theme_stylebox_override("disabled", Style.box(Color("33290f"), Style.BRASS, 3))
			b.add_theme_color_override("font_disabled_color", Color("f3d891"))
			b.add_theme_color_override("icon_disabled_color", Style.BRASS)
		if not b.disabled:
			var act: Callable = o["act"]
			var said := String(o.get("says", o["label"]))
			b.pressed.connect(func():
				Sound.play("page", 0.0, 0.05)
				_said = said
				act.call())
		row.add_child(b)
	return box


## Press a reply by id, as a tap would (tests and autoplay).
func choose(id: String) -> bool:
	var b := _talk.find_child("Reply_" + id, true, false) as Button
	if b == null or b.disabled:
		return false
	b.pressed.emit()
	return true


func has_reply(id: String, enabled_only: bool = true) -> bool:
	var b := _talk.find_child("Reply_" + id, true, false) as Button
	return b != null and (not enabled_only or not b.disabled)


func _note(text: String, tone: Color = Style.MORALE_HIGH) -> Control:
	return TalkView.fx_note([], text, tone)


## What changed, as chips (see TalkView.fx_chips) and the words still needed after them.
func _fx_note(fx: Array, text: String = "", tone: Color = Style.MORALE_HIGH) -> Control:
	return TalkView.fx_note(fx, text, tone)


func _leave_reply(text: String = "Safe roads.") -> Dictionary:
	return {"id": "leave", "text": text, "tag": "leave", "act": _leave}


func _leave() -> void:
	set_process(false)
	closed.emit()
	queue_free()


# ---------------------------------------------------------------- greeting

func _beat_greet() -> void:
	_beat = "greet"
	# The greeting is told in the third person on the map; here they say it to your face.
	# Kin by your marriage, or sworn to you by a pact, they greet you as such; someone you've
	# talked with before greets you as someone they know.
	var talked_before := LordTalk.note_talk(lord)
	var pact: Dictionary = world.social.pact_for_lord(int(lord.get("id", -1))) if world.social != null else {}
	var kind := "greet"
	if String(pact.get("origin", "")) == "marriage":
		kind = "kin"
	elif not pact.is_empty():
		kind = "pact"
	elif talked_before > 0:
		kind = "known"
	var said := LordVoice.line(kind, lord, talked_before)
	var a := said.find("\"")
	var b := said.rfind("\"")
	var words := said.substr(a + 1, b - a - 1) if a >= 0 and b > a else "Well met, captain."
	if String(lord.get("realm", "")) == Data.CROWN:
		words = "My liege. %s is held, and my riders are ready." % (Data.settlement(String(lord["fief"]))["name"] if String(lord.get("fief", "")) != "" else "All")
	elif reason == "first" and kind == "greet":
		words = "So you're the captain everyone's talking about. %s. %s" % [_house_line(), words]
	var extras := []
	if mode == "hall":
		var g: Dictionary = world.gathering_at(place_id())
		if world.gathering_on(g) and int(g.get("host_lord", -1)) == int(lord["id"]):
			words = "Welcome to my table, captain. Eat, drink; the speeches come later."
		elif world.gathering_on(g) and int(g.get("host_lord", -1)) < 0:
			words = "Captain. Your table's the talk of the realm tonight, and your wine is better than your reputation."
		elif world.gathering_on(g):
			words = "Captain. Come to drink %s's wine with the rest of us?" % gs.gathering_host_name(g)
		var bonus: int = gs.first_word(lord)
		if bonus > 0:
			extras.append(_fx_note([["bond", bonus]], "first word at the table"))
	_show("\"%s\"" % words, extras, _root_replies())


func _house_line() -> String:
	var fief := String(lord.get("fief", ""))
	if bool(lord.get("ruler", false)):
		return "I rule %s" % Data.the_realm(String(Data.FACTIONS[String(lord["realm"])]["name"])) if Data.FACTIONS.has(String(lord["realm"])) else "I rule here"
	return "I hold %s" % Data.settlement(fief)["name"] if fief != "" else "My house is %s" % String(lord.get("house", ""))


func _root_replies() -> Array:
	var out := []
	var news: Array = world.fresh_news()
	out.append({"id": "news", "text": "Peaceably. What news from the war?" if _beat == "greet" else "What news from the war?", "icon": "book",
		"fx": [["mail", "%d new" % news.size()]] if not news.is_empty() else [],
		"tag": "" if not news.is_empty() else "nothing new", "act": _beat_news})
	out.append({"id": "trouble", "text": "Something weighs on you, %s." % String(lord.get("house", LordTalk.first_name(lord))),
		"icon": "objective", "tag": "learn what they want", "act": _beat_trouble})
	if not LordTalk.stories(gs, lord).is_empty():
		out.append({"id": "story", "text": "A story for the road?", "icon": "talk", "tag": "builds Regard", "act": _beat_stories})
	var army_ride: bool = gs.has_contract() and gs.contract_realm() == String(lord.get("realm", "")) and int(lord.get("party", -1)) >= 0
	if army_ride and mode != "hall":
		var pid := int(lord["party"])
		if world.following_party == pid:
			out.append({"id": "part", "text": "I'll ride my own road now.", "icon": "ride", "tag": "stop riding with them", "act": func():
				world.following_party = -1
				_leave()})
		else:
			out.append({"id": "ride", "text": "Let us ride with you.", "icon": "ride", "tag": "follow their army", "act": func():
				wants_follow.emit(pid)
				_leave()})
	out.append_array(_order_replies())
	out.append_array(_crown_replies())
	var ch := LordTalk.challenge_check(gs, lord)
	if mode == "hall":
		# No swords under a host's roof: a challenge is a duel outside the walls at dawn.
		if String(lord.get("realm", "")) != Data.CROWN:
			var dc := LordTalk.duel_check(gs, lord)
			out.append({"id": "outside", "text": "Meet me outside the walls at dawn.", "icon": "fight",
				"tag": ("a duel · no swords under %s roof" % _roof_possessive()) if bool(dc["ok"]) else String(dc["reason"]),
				"tone": "red" if bool(dc["ok"]) else "locked", "act": _beat_duel})
		out.append(_leave_reply(_hall_goodbye()))
		return out
	if bool(ch["ok"]) or String(lord.get("realm", "")) != Data.CROWN:
		var war: bool = bool(ch["ok"]) and bool(ch["war"])
		out.append({"id": "sword", "text": "Draw your sword.", "icon": "fight",
			"fx": [{"realm": _banner_realm, "text": "war"}] if war else [],
			"tag": "challenge" if bool(ch["ok"]) else String(ch["reason"]),
			"tone": "red" if bool(ch["ok"]) or LordTalk.duel_check(gs, lord)["ok"] else "locked", "act": _beat_challenge.bind(false)})
	out.append(_leave_reply())
	return out


## Whose roof this is, for the guest right: the host of a gathering, else the holder.
func _roof_of() -> String:
	var id := place_id()
	var g: Dictionary = world.gathering_at(id)
	if world.gathering_on(g):
		var who: String = gs.gathering_host_name(g)
		return "your" if who == "you" else who
	var holder: Dictionary = world.holder_lord(id)
	if not holder.is_empty():
		return "your" if int(holder["id"]) == int(lord["id"]) else LordTalk.short_name(holder)
	return "this"


func _roof_possessive() -> String:
	var who := _roof_of()
	return who if who in ["your", "this"] else who + "'s"


func _hall_goodbye() -> String:
	return "Enjoy the feast." if world.gathering_on(world.gathering_at(place_id())) else "Good day."


func _realm_name() -> String:
	var r := String(lord.get("realm", ""))
	return String(Data.FACTIONS[r]["name"]) if Data.FACTIONS.has(r) else r


## Orders, for a lord sworn to you.
func _order_replies() -> Array:
	if String(lord.get("realm", "")) != Data.CROWN or int(lord.get("party", -1)) < 0:
		return []
	var lid := int(lord["id"])
	var order: Dictionary = lord.get("order", {}) if lord.get("order") is Dictionary else {}
	var kind := String(order.get("kind", ""))
	var row := []
	row.append({"id": "order_follow", "label": "Follow", "icon": "company", "says": "Ride with me.", "tip": "They follow you and join your fights",
		"lit": kind == "follow", "act": func():
			gs.order_lord(lid, "follow")
			_show("\"At your side, then.\"", [_note("%s rides with you." % LordTalk.short_name(lord), Style.BRASS)], [_leave_reply("Good.")])})
	var hold := String(lord.get("fief", ""))
	if hold == "" or not gs.crown_holdings().has(hold):
		hold = world.capital_of(Data.CROWN)
	if hold != "":
		var hold_name := String(Data.settlement(hold)["name"])
		row.append({"id": "order_guard", "label": "Hold", "icon": "keep", "says": "Hold %s for the crown." % hold_name, "tip": "They guard %s" % hold_name,
			"lit": kind == "guard" and String(order.get("target", "")) == hold, "act": func():
				gs.order_lord(lid, "guard", hold)
				_show("\"It will stand.\"", [_note("%s will hold %s." % [LordTalk.short_name(lord), hold_name], Style.BRASS)], [_leave_reply("Good.")])})
	row.append({"id": "order_free", "label": "Free", "icon": "mappin", "says": "Go about the realm's business.", "tip": "They choose for themselves",
		"lit": kind == "", "act": func():
			gs.order_lord(lid, "")
			_show("\"As you say.\"", [], [_leave_reply("Go well.")])})
	return [{"row": row}]


## The crown lines: open once you're crowned, shown locked before so you know they're coming.
func _crown_replies() -> Array:
	if String(lord.get("realm", "")) == Data.CROWN:
		return []
	var check := LordTalk.persuade_check(gs, lord)
	if not gs.is_crowned():
		# One locked line, so you know crowns are coming.
		return [{"id": "crown", "text": "I've come to talk of crowns.", "tag": "raise your own banner first", "tone": "locked"}]
	if not bool(check["ok"]):
		return [{"id": "crown", "text": "I've come to talk of crowns.", "tag": String(check["reason"]), "tone": "locked"}]
	var c := LordTalk.conviction(gs, lord)
	return [{"id": "crown", "text": "I've come to talk of crowns.", "icon": "crown", "fx": [["crown", "%d / %d" % [c, LordTalk.CONVINCED]]],
		"tag": "win them over", "tone": "gold", "act": _beat_persuade.bind(true)}]


# ---------------------------------------------------------------- news

func _beat_news() -> void:
	_beat = "news"
	var news: Array = world.fresh_news()
	# Back from the war news they've told already, they say it again.
	if news.is_empty() and not _news.is_empty():
		news = _news
	_news = news
	var extras := []
	var speech := ""
	if news.is_empty():
		speech = "\"Nothing you won't have heard already. The war grinds on.\""
	else:
		var first := String(news[0]["text"])
		speech = "\"%s thing%s since we last met. %s\"" % ["One" if news.size() == 1 else ("Two" if news.size() == 2 else str(news.size())),
			"" if news.size() == 1 else "s", first]
		for e in news.slice(0, 3):
			extras.append(_news_chip(e))
		world.news_heard_at = float(news[0]["hour"])
	var replies := []
	if not bool(lord.get("ruler", false)) and String(lord.get("realm", "")) != Data.CROWN:
		replies.append({"id": "king", "text": "And what will %s do?" % LordTalk.ruler_name(lord), "icon": "crown",
			"tag": "their view of their ruler" + (" · counts toward crowns" if gs.is_crowned() else ""), "act": _beat_king})
	if mode != "hall":
		replies.append({"id": "chronicle", "text": "More in the chronicle.", "icon": "journal", "tag": "War & Politics", "act": func(): wants_news.emit()})
	replies.append({"id": "back", "text": "Something else.", "tag": "", "act": _beat_greet_again})
	replies.append(_leave_reply("Thank you. Safe roads."))
	_show(speech, extras, replies)


func _news_chip(e: Dictionary) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Style.box(Style.PANEL, Style.RULE, 2, 10))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var hours: float = world.hour - float(e.get("hour", 0.0))
	var when := "Today" if hours < 24.0 else ("Yesterday" if hours < 48.0 else "%s ago" % Style.time_short(hours))
	var w := Style.label(when, Style.SMALL, Style.BRASS)
	w.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(w)
	var t := Style.label(String(e.get("text", "")), Style.SMALL, Style.TEXT)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	p.add_child(h)
	return p


func _beat_king() -> void:
	_beat = "king"
	var view := LordTalk.view_of_king(gs, lord)
	var extras := []
	if bool(view["doubts"]) and gs.is_crowned():
		extras.append(_note("They doubt their ruler: that will count when you talk of crowns.", Style.BRASS))
	_show(String(view["says"]), extras, [{"id": "back", "text": "Something else.", "act": _beat_greet_again}, _leave_reply()])


func _beat_greet_again() -> void:
	_beat = "again"
	_show("\"What else?\"", [], _root_replies())


## Back from the war news (the host calls this when it closes).
func resume() -> void:
	visible = true
	_said = ""
	if _beat in ["news", "king"]:
		_beat_news()


# ---------------------------------------------------------------- stories

func _beat_stories() -> void:
	_beat = "stories"
	var replies := []
	var shown := 0
	for s in LordTalk.stories(gs, lord):
		if shown >= 3:
			break
		shown += 1
		var tag := "your chronicle" if String(s["id"]).begins_with("log_") else "a company tale"
		var fx := []
		if String(s["theme"]) == LordTalk.likes(lord) and LordTalk.like_known(lord):
			fx.append(["bond", LordTalk.STORY_LIKED])
			tag += " · they like %s" % LordTalk.THEME_WORDS[s["theme"]]
		elif String(s["theme"]) == LordTalk.dislikes(lord) and LordTalk.dislike_known(lord):
			fx.append(["bond", LordTalk.STORY_DISLIKED])
			tag += " · they dislike %s" % LordTalk.THEME_WORDS[s["theme"]]
		replies.append({"id": "tell_" + String(s["id"]), "text": String(s["says"]), "icon": "journal" if String(s["id"]).begins_with("log_") else "talk",
			"fx": fx, "tag": tag, "act": _tell.bind(String(s["id"]))})
	replies.append({"id": "back", "text": "Another time.", "act": _beat_greet_again})
	var ask := "\"Go on, then. Tell me something your company did that I won't have heard in a tavern.\""
	_show(ask, [], replies)


func _tell(story_id: String) -> void:
	var r := LordTalk.tell_story(gs, lord, story_id)
	var extras := []
	var change := int(r.get("regard", 0))
	extras.append(_fx_note([["bond", change]], String(r.get("learned", "")), Style.MORALE_HIGH if change > 0 else Style.MORALE_LOW))
	var replies := []
	if not LordTalk.stories(gs, lord).is_empty():
		replies.append({"id": "story", "text": "Another?", "icon": "talk", "tag": "tell another", "act": _beat_stories})
	replies.append({"id": "back", "text": "Something else.", "act": _beat_greet_again})
	replies.append(_leave_reply())
	_show(String(r.get("reaction", "")), extras, replies)


# ---------------------------------------------------------------- troubles

func _beat_trouble() -> void:
	_beat = "trouble"
	var tr := LordTalk.trouble(gs, lord)
	var replies := []
	if String(tr["kind"]) == "bandits":
		var full: bool = gs.active_jobs.size() >= Jobs.MAX_ACTIVE_JOBS
		replies.append({"id": "take", "text": "I'll clear %s." % String(tr["name"]), "icon": "journal",
			"fx": [] if full else [["bond", LordTalk.JOB_REGARD]],
			"tag": "your journal is full" if full else "new job · when done%s" % (" · counts toward crowns" if gs.is_crowned() else ""),
			"tone": "locked" if full else "gold", "act": _take_trouble.bind(0)})
		if int(LordTalk.record(lord).get("haggled", 0)) == 0:
			var cost := LordTalk.haggle_cost(lord)
			var haggle_fx := [["silver", LordTalk.haggle_silver(lord)]]
			if cost != 0:
				haggle_fx.append(["bond", cost])
			replies.append({"id": "haggle", "text": "What would that be worth to you?", "icon": "silver", "fx": haggle_fx,
				"tag": ("%s dislikes haggling" % String(lord["bearing"])) if cost != 0 else "",
				"act": _haggle})
		replies.append({"id": "no", "text": "Not my fight.", "tag": "nothing changes", "act": _beat_greet_again})
	else:
		replies.append({"id": "back", "text": "Something else.", "act": _beat_greet_again})
	replies.append(_leave_reply())
	_show(String(tr["text"]), [], replies)


func _haggle() -> void:
	var silver := LordTalk.haggle(gs, lord)
	var said := "\"%d silver, then, when they're gone. Don't make me regret it.\"" % silver
	if String(lord.get("bearing", "")) in [Lords.CAUTIOUS, Lords.HONORABLE]:
		said = "\"Hm. I'd hoped you'd do it for the road's sake. %d silver, then.\"" % silver
	var tr := LordTalk.trouble(gs, lord)
	_show(said, [], [
		{"id": "take", "text": "Done. I'll clear %s." % String(tr.get("name", "them")), "icon": "journal",
			"fx": [["silver", silver], ["bond", LordTalk.JOB_REGARD]], "tag": "new job · when done",
			"tone": "gold", "act": _take_trouble.bind(silver)},
		{"id": "no", "text": "Not for that.", "tag": "nothing changes", "act": _beat_greet_again}])


func _take_trouble(silver: int) -> void:
	var job := LordTalk.take_trouble(gs, lord, silver)
	if job.is_empty():
		_show("\"Then never mind it.\"", [], _root_replies())
		return
	gs.save_game()
	_show("\"Good. Find me when it's done, or don't; I'll hear of it.\"",
		[_note("Added to your journal: %s." % String(job["title"]), Style.BRASS)],
		[{"id": "back", "text": "Something else.", "act": _beat_greet_again}, _leave_reply()])


# ---------------------------------------------------------------- winning them over

func _beat_persuade(first: bool) -> void:
	_beat = "persuade"
	if not LordTalk.persuade_check(gs, lord)["ok"]:
		_beat_greet_again()
		return
	var speech := LordTalk.objection(lord) if first else "\"Go on.\""
	_show(speech, [_conviction_bar()], _persuade_replies())


func _conviction_bar() -> Control:
	var c := LordTalk.conviction(gs, lord)
	var box := VBoxContainer.new()
	box.name = "Conviction"
	var top := HBoxContainer.new()
	top.add_child(Style.label("Convinced", Style.SMALL, Style.MUTED))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(gap)
	var n := Style.label("%d / %d · %s" % [mini(c, LordTalk.CONVINCED), LordTalk.CONVINCED, LordTalk.conviction_word(c)], Style.SMALL, Style.BRASS)
	n.name = "ConvictionText"
	top.add_child(n)
	box.add_child(top)
	box.add_child(Widgets.meter(float(c) / LordTalk.CONVINCED, Style.BRASS, 12.0))
	return box


func _persuade_replies() -> Array:
	var out := []
	for a in LordTalk.arguments(gs, lord):
		# A known effect is a crown chip with its points; "a guess" stays a guess.
		var tag := String(a["tag"])
		var fx := []
		var bits := tag.split(" · ", false)
		if bits.size() > 1 and not tag.begins_with("a guess"):
			fx.append(["crown", int(a["points"])])
			tag = String(bits[1])
		out.append({"id": "arg_" + String(a["id"]), "text": String(a["says"]), "icon": "talk", "fx": fx, "tag": tag, "act": _argue.bind(String(a["id"]))})
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 8)
	chips.add_theme_constant_override("v_separation", 8)
	for amount in LordTalk.SILVER_OFFERS:
		var b := Button.new()
		b.name = "Silver_%d" % amount
		b.text = "%s  +%d" % [Widgets.thousands(amount), amount / LordTalk.SILVER_PER_POINT]
		b.tooltip_text = "%s silver for %d toward conviction" % [Widgets.thousands(amount), amount / LordTalk.SILVER_PER_POINT]
		b.icon = Widgets.icon("silver")
		b.add_theme_constant_override("icon_max_width", 28)
		b.disabled = int(gs.silver) < amount
		b.add_theme_font_size_override("font_size", Style.text_size(Style.SMALL))
		b.custom_minimum_size = Vector2(0, Style.TOUCH)
		b.focus_mode = Control.FOCUS_NONE
		var sb := Style.box(Color("3a2c10"), Style.BRASS, 2, 14)
		b.add_theme_stylebox_override("normal", sb)
		b.pressed.connect(func():
			_said = "Then let me make it worth the risk. %s silver." % Widgets.thousands(amount)
			_offer(amount))
		chips.add_child(b)
	out.append({"id": "silver", "text": "Then let me make it worth the risk.", "icon": "silver", "fx": [["silver", Widgets.thousands(int(gs.silver))]],
		"tag": "name a sum", "tone": "gold", "extra": chips})
	out.append({"id": "think", "text": "Think on it. I'll ride this way again.", "tag": "nothing lost", "act": _leave})
	return out


func _argue(arg_id: String) -> void:
	var r := LordTalk.argue(gs, lord, arg_id)
	_after_case(r)


func _offer(amount: int) -> void:
	var r := LordTalk.offer_silver(gs, lord, amount)
	if bool(r.get("ok", false)):
		Sound.play("coins")
	_after_case(r)


func _after_case(r: Dictionary) -> void:
	if not bool(r.get("ok", false)):
		_beat_persuade(false)
		return
	if bool(r.get("refused", false)):
		gs.save_game()
		_show(String(r["reaction"]), [_fx_note([["bond", LordTalk.REFUSAL_REGARD], ["clock", Style.time_short(LordTalk.REFUSAL_HOURS)]],
			"They refuse you, and won't hear of it again till then.", Style.MORALE_LOW)],
			[_leave_reply("As you like.")])
		return
	if bool(r.get("sworn", false)):
		_beat_sworn()
		return
	var extras := [_conviction_bar()]
	var pts := int(r.get("points", 0))
	# The points, once, with what you learned beside them; the bar below shows the total.
	extras.push_front(_fx_note([["crown", pts]], String(r.get("learned", "")), Style.MORALE_HIGH if pts > 0 else Style.MORALE_LOW))
	_show(String(r.get("reaction", "")), extras, _persuade_replies())


func _beat_sworn() -> void:
	_beat = "sworn"
	var r := LordTalk.swear(gs, lord)
	if not bool(r.get("ok", false)):
		_beat_persuade(false)
		return
	_banner_realm = "crown"
	var theirs := _stage.get_node("TheirBanner")
	var flag := Widgets.banner("crown", Vector2(70, 104))
	flag.name = "TheirBanner"
	flag.position = theirs.position
	_stage.remove_child(theirs)
	theirs.queue_free()
	_stage.add_child(flag)
	Sound.play("horn")
	gs.save_game()
	var card := PanelContainer.new()
	card.name = "Oath"
	card.add_theme_stylebox_override("panel", Style.box(Color("2a2010"), Style.BRASS, 3, 14))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var title := Style.label("%s swears to your crown" % LordTalk.short_name(lord), Style.BODY, Style.BRASS)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(title)
	# What comes with them, as chips: their seat, their men, and what their old realm
	# thinks of it; how they were won, in words.
	var gains := []
	if String(r["fief"]) != "":
		var seat := String(Data.settlement(String(r["fief"]))["name"])
		var villages := (r["villages"] as Array).size()
		gains.append(Widgets.stat("keep", seat + (" +%d" % villages if villages > 0 else "")))
	gains.append(Widgets.stat("men", Widgets.thousands(int(r["men"]))))
	var from := String(r["from"])
	gains.append(TalkView.realm_chip(from if Heraldry.REALM_SIZES.has(from) else Heraldry.realm_of_culture(Data.culture_of(from)), {"amount": -30}))
	var row := Widgets.chip_row(gains)
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	v.add_child(row)
	var how := Style.label("Bought with silver: may leave if Regard falls below 0" if bool(r["bought"]) else "Sworn in good faith",
		Style.SMALL, Style.ENEMY_LIGHT if bool(r["bought"]) else Style.MUTED)
	how.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(how)
	card.add_child(v)
	var fief := String(r["fief"])
	var replies := []
	if fief != "":
		var lid := int(lord["id"])
		var fief_name := String(Data.settlement(fief)["name"])
		replies.append({"row": [
			{"id": "order_follow", "label": "Follow", "icon": "company", "says": "Ride with me.", "tip": "They follow you and join your fights", "act": func():
				gs.order_lord(lid, "follow")
				_leave()},
			{"id": "hold", "label": "Hold", "icon": "keep", "says": "Hold %s for the crown." % fief_name, "tip": "They guard %s" % fief_name, "act": func():
				gs.order_lord(lid, "guard", fief)
				_leave()}]})
	replies.append(_leave_reply("Ride well, and raise your men."))
	_refresh_regard()
	_show("\"Then hear it plainly: House %s stands with your crown, as long as your crown stands.\"" % String(lord.get("house", "")), [card], replies)


# ---------------------------------------------------------------- steel

## A challenge: battle or single combat, with what's at stake shown before you commit.
func _beat_challenge(blocked: bool) -> void:
	_beat = "challenge"
	var speech := ""
	match String(lord.get("bearing", "")):
		Lords.CRUEL:
			speech = "\"My riders have had no sport in a week. Shall I take your head, or your silver?\""
		Lords.DARING:
			speech = "\"Ha! I was hoping you'd say that.\""
		Lords.CAUTIOUS:
			speech = "\"You'd risk your company on my road? Think carefully, captain.\""
		_:
			speech = "\"If it must be steel, let it be clean.\""
	if not blocked and String(lord.get("bearing", "")) != Lords.CRUEL:
		speech = speech
	var replies := []
	var ch := LordTalk.challenge_check(gs, lord)
	if bool(ch["ok"]) or blocked:
		var st := LordTalk.stakes(gs, lord)
		var stakes := VBoxContainer.new()
		stakes.add_theme_constant_override("separation", 8)
		# Your men against theirs, and the war it starts; then what winning and losing bring.
		var sides: Array = [Widgets.stat("men", "%d  v  %d" % [int(st["mine"]), int(st["theirs"])])]
		if bool(ch.get("war", false)):
			sides.append(TalkView.realm_chip(_banner_realm, {"text": "war"}))
		stakes.add_child(Widgets.chip_row(sides))
		stakes.add_child(_win_lose([["lock", "captive"], ["renown", 15], ["silver", 150]], [["men", -int(st["lost"])]], "the rest fall back"))
		var go := Button.new()
		go.name = "DrawSwords"
		go.text = "Draw swords"
		go.icon = Widgets.icon("fight")
		go.expand_icon = false
		go.custom_minimum_size = Vector2(0, Style.TOUCH)
		go.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		go.add_theme_stylebox_override("normal", Style.box(Style.ENEMY, Color(0, 0, 0, 0), 0, 14))
		go.add_theme_stylebox_override("hover", Style.box(Style.ENEMY.lightened(0.1), Color(0, 0, 0, 0), 0, 14))
		go.add_theme_stylebox_override("pressed", Style.box(Style.ENEMY_DARK, Style.TEXT, 2, 14))
		go.pressed.connect(_draw_swords)
		stakes.add_child(go)
		replies.append({"id": "battle", "text": "Then settle it here, your riders against mine.", "icon": "battle", "tag": "battle", "tone": "red", "extra": stakes})
	var dc := LordTalk.duel_check(gs, lord)
	replies.append({"id": "duel", "text": "Your champion and mine.", "icon": "fight", "tag": "single combat · no armies, no war" if bool(dc["ok"]) else String(dc["reason"]),
		"tone": "red" if bool(dc["ok"]) else "locked", "act": _beat_duel})
	var tc := LordTalk.tribute_check(gs, lord)
	if String(lord.get("bearing", "")) == Lords.CRUEL and world.relation_to_player(String(lord.get("realm", ""))) == "hostile":
		replies.append({"id": "tribute", "text": "Here, %d silver for the road." % LordTalk.TRIBUTE, "icon": "silver",
			"fx": [["silver", -LordTalk.TRIBUTE], ["bond", LordTalk.TRIBUTE_REGARD]] if bool(tc["ok"]) else [],
			"tag": "Cruel lords like this" if bool(tc["ok"]) else String(tc["reason"]),
			"tone": "plain" if bool(tc["ok"]) else "locked", "act": _pay_tribute})
	if blocked:
		replies.append_array(_crown_replies().filter(func(r): return String(r.get("tone", "")) != "locked"))
		replies.append({"id": "back", "text": "Let me think.", "tag": "back to the road", "act": _leave})
	else:
		replies.append({"id": "back", "text": "Another time.", "tag": "nothing changes", "act": _beat_greet_again})
	_show(speech, [], replies)


## What's at stake as two columns, Win and Lose, each a column of chips (see
## TalkView.fx_chips) and any words still needed under the Lose side.
func _win_lose(win: Array, lose: Array, lose_words: String = "") -> GridContainer:
	var grid := GridContainer.new()
	grid.name = "Stakes"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 6)
	for side in [["Win", win, Style.MORALE_HIGH, ""], ["Lose", lose, Style.ENEMY_LIGHT, lose_words]]:
		var v := VBoxContainer.new()
		v.name = String(side[0])
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", 6)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(Style.label(String(side[0]).to_upper(), Style.SMALL, side[2]))
		var chips := Widgets.chip_row(TalkView.fx_chips(side[1]))
		chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(chips)
		if String(side[3]) != "":
			var l := Style.label(String(side[3]), Style.SMALL, Style.MUTED)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.add_child(l)
		grid.add_child(v)
	return grid


func _draw_swords() -> void:
	var lid := int(lord["id"])
	var pid := int(lord.get("party", -1))
	var ch := LordTalk.challenge_check(gs, lord)
	if bool(ch.get("war", false)):
		gs.attack_neutral_lord(lid, pid)
		if gs.is_crowned() and world.realms.has(String(lord["realm"])):
			world.declare_war(Data.CROWN, String(lord["realm"]), true, "challenge")
	world.encounter = pid
	world.events.clear()
	set_process(false)
	wants_fight.emit()
	queue_free()


func _pay_tribute() -> void:
	if LordTalk.pay_tribute(gs, lord):
		Sound.play("coins")
		gs.save_game()
		_show("\"Wise. Ride on, then, before I change my mind.\"", [_fx_note([["silver", -LordTalk.TRIBUTE], ["bond", LordTalk.TRIBUTE_REGARD]], "They let you pass.", Style.BRASS)],
			[_leave_reply("Safe roads.")])


func _beat_duel() -> void:
	_beat = "duel"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	for c in LordTalk.champions(gs):
		var cap: Dictionary = c["captain"]
		var b := Button.new()
		b.name = "Champion_%d" % int(c["squad"])
		b.custom_minimum_size = Vector2(150, 200)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_stylebox_override("normal", Style.box(Color("2a1210"), Style.ENEMY, 2, 12))
		var v := VBoxContainer.new()
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		var face := CaptainArt.portrait(cap, Vector2(72, 96))
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(face)
		var n := Style.label(String(cap.get("first", cap.get("name", ""))), Style.SMALL, Style.TEXT)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(n)
		# Their odds, as a number with the fight mark; the troop is on the face already.
		var odds := Widgets.icon_value("fight", "%d%%" % roundi(LordTalk.duel_chance(cap, lord) * 100.0), Style.MUTED)
		odds.alignment = BoxContainer.ALIGNMENT_CENTER
		odds.tooltip_text = String(Troops.TYPES.get(String(c["type"]), {}).get("name", String(c["type"])))
		v.add_child(odds)
		b.add_child(v)
		var sid := int(c["squad"])
		var who := String(cap.get("first", "my captain"))
		b.pressed.connect(func():
			_said = "My champion is %s." % who
			_fight_duel(sid))
		row.add_child(b)
	var win := LordTalk.duel_win_regard(lord)
	var stakes := _win_lose([["bond", win], ["renown", LordTalk.DUEL_RENOWN]], [["wounded", "2 battles"], ["bond", LordTalk.DUEL_LOSE_REGARD]],
		"your champion is hurt")
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.add_child(row)
	box.add_child(stakes)
	_show("\"Ha! A duel, then. Choose your champion. Mine has never lost.\"", [],
		[{"id": "champion", "text": "My champion is...", "icon": "fight", "tag": "choose a captain", "tone": "red", "extra": box},
		{"id": "back", "text": "On second thought, no.", "tag": "nothing changes", "act": _beat_greet_again}])


func _fight_duel(squad_id: int) -> void:
	var r := LordTalk.duel(gs, lord, squad_id)
	if not bool(r.get("ok", false)):
		_beat_greet_again()
		return
	Sound.play("charge" if bool(r["won"]) else "bell")
	gs.save_game()
	var said := ""
	var result: Control
	if bool(r["won"]):
		said = "\"...Yielded. Your %s fights like a devil. I'll remember this, captain.\"" % String(r["captain"]).split(" ")[0]
		result = _fx_note([["bond", int(r["regard"])], ["renown", int(r["renown"])]], "%s won." % String(r["captain"]))
	else:
		said = "\"Get your champion to a surgeon. Better luck next time.\""
		result = _fx_note([["wounded", "2 battles"], ["bond", int(r["regard"])]], "%s was beaten." % String(r["captain"]), Style.MORALE_LOW)
	_show(said, [result],
		[{"id": "back", "text": "Something else.", "act": _beat_greet_again} if mode != "hostile" else {"id": "back", "text": "Back to the road.", "act": _leave}, _leave_reply()])


# ---------------------------------------------------------------- captives

func _beat_captive() -> void:
	_beat = "captive"
	var lid := int(lord["id"])
	var speech := ""
	match String(lord.get("bearing", "")):
		Lords.HONORABLE:
			speech = "\"You have kept me fairly, and fed my men. But I swore to %s, and I do not break oaths. Not for silver, not for fear.\"" % LordTalk.ruler_name(lord)
		Lords.CRUEL:
			speech = "\"Enjoy it while it lasts, sellsword. My house has a long memory.\""
		Lords.DARING:
			speech = "\"Well fought, I'll give you that. So what now? Chains bore me.\""
		_:
			speech = "\"I'd sooner be home. Name your terms and let's be done.\""
	var replies := []
	if gs.is_crowned():
		var sw: Dictionary = gs.swear_check(lid)
		replies.append({"id": "swear", "text": "Swear to my crown.", "icon": "crown", "tag": "join your realm" if bool(sw["ok"]) else String(sw["reason"]),
			"tone": "gold" if bool(sw["ok"]) else "locked", "act": func():
				if gs.swear_lord_to_crown(lid):
					Sound.play("horn")
					_banner_realm = "crown"
					_show("\"So be it. I'll serve your crown.\"", [_note("%s swears to your crown." % LordTalk.short_name(lord), Style.BRASS)], [_leave_reply("Welcome.")])})
	else:
		replies.append({"id": "swear", "text": "Swear to my crown.", "tag": "raise your own banner first", "tone": "locked"})
	replies.append({"id": "release", "text": "Go home, and remember who freed you.", "icon": "bond",
		"fx": [["bond", int(gs.release_reward(lid)["regard"])], {"realm": _banner_realm, "amount": int(gs.release_reward(lid)["realm"])}], "tag": "for honor", "tone": "gold", "act": func():
			gs.release_lord_for_honor(lid)
			Sound.play("page")
			_show("\"I won't forget it.\"", [_note("Released.")], [_leave_reply("Go.")])})
	var ransom: int = int(gs.ransom_offer(lid))
	replies.append({"id": "ransom", "text": "Your house will pay %d silver for you." % ransom, "icon": "silver",
		"fx": [["silver", ransom], ["bond", 5]], "tag": "ransom", "act": func():
			gs.accept_lord_ransom(lid)
			Sound.play("coins")
			_show("\"They'll pay. Gladly, I expect.\"", [_note("Ransomed.", Style.BRASS)], [_leave_reply("Go.")])})
	if gs.has_contract() and world.at_war(gs.contract_realm(), String(lord.get("realm", ""))):
		var employer: String = gs.contract_realm()
		replies.append({"id": "deliver", "text": "My employer will want to see you.", "icon": "lock",
			"fx": [["silver", int(gs.contract.get("bonus_per_lord", 100))], {"realm": employer if Heraldry.REALM_SIZES.has(employer) else "bandits", "amount": 10}],
			"tag": "the bounty", "act": func():
				gs.deliver_lord_to_employer(lid)
				Sound.play("coins")
				_leave()})
	replies.append({"id": "chains", "text": "Then you'll stay in chains.", "icon": "lock", "fx": [["bond", LordTalk.CHAINS_REGARD]],
		"tag": "Honorable lords hear of it", "tone": "red", "act": func():
			LordTalk.keep_in_chains(gs, lord)
			gs.save_game()
			_show("\"...\"", [_note("Kept in chains.", Style.MORALE_LOW)], [_leave_reply("Take them back.")])})
	replies.append(_leave_reply("Later."))
	_show(speech, [], replies)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_leave()
