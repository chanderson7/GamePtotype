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
	var cap_label := Style.label(caption(), Style.SMALL, Style.TEXT)
	cap_label.name = "Caption"
	cap.add_child(cap_label)
	_stage.add_child(cap)
	var x := Button.new()
	x.name = "Close"
	x.custom_minimum_size = Vector2(64, 64)
	x.icon = Widgets.icon("cancel")
	x.expand_icon = true
	x.add_theme_stylebox_override("normal", Style.box(Color(Style.NIGHT, 0.75), Style.RULE, 2, 32))
	x.add_theme_stylebox_override("hover", Style.box(Color(Style.NIGHT, 0.85), Style.MUTED, 2, 32))
	x.add_theme_stylebox_override("pressed", Style.box(Style.NIGHT, Style.BRASS, 2, 32))
	x.anchor_left = 1.0
	x.anchor_right = 1.0
	x.offset_left = -84
	x.offset_right = -20
	x.offset_top = 16
	x.offset_bottom = 80
	x.pressed.connect(_leave)
	_stage.add_child(x)
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
		plate.add_child(Widgets.chip("Your captive", Style.MORALE_MID, "·"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var name_label := Style.label(LordTalk.short_name(lord), Style.LARGE, Style.TEXT)
	name_label.name = "LordName"
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
	var heart := Widgets.icon_rect("heart", 22)
	heart.modulate = tone
	h.add_child(heart)
	var sworn := String(lord.get("realm", "")) == Data.CROWN
	var t := Style.label("Sworn to you" if sworn else LordTalk.regard_text(value), Style.SMALL, Style.BRASS if sworn else Style.TEXT)
	t.name = "RegardText"
	h.add_child(t)
	_regard_chip.add_child(h)


# ---------------------------------------------------------------- the talk

## One exchange: your last line, dimmed; their answer; anything to show with it; your replies.
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
	var who := Style.label(LordTalk.first_name(lord).to_upper(), Style.SMALL, Style.BRASS)
	_talk.add_child(who)
	var line := Style.label(speech, Style.BODY, Style.TEXT)
	line.name = "Speech"
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_talk.add_child(line)
	for e in extras:
		_talk.add_child(e)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	_talk.add_child(gap)
	for r in replies:
		_talk.add_child(_reply(r))
	_refresh_regard()
	_scroll.scroll_vertical = 0
	if not Style.motion_reduced():
		_talk.modulate.a = 0.0
		create_tween().tween_property(_talk, "modulate:a", 1.0, 0.18)


## The text of their current answer.
func speech_text() -> String:
	var n := _talk.get_node_or_null("Speech") as Label
	return n.text if n != null else ""


## A reply you can give: {id, text, tag, tone ("plain", "gold", "red", "locked"), act,
## extra (a Control shown inside it)}.
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
	# A button doesn't grow to its children: size it to them once they've measured.
	box.minimum_size_changed.connect(func(): b.custom_minimum_size.y = box.get_combined_minimum_size().y + 20)
	b.custom_minimum_size.y = 72
	if not locked and r.has("act"):
		var act: Callable = r["act"]
		var said := String(r["text"])
		b.pressed.connect(func():
			Sound.play("page", 0.0, 0.05)
			_said = said
			act.call())
	return b


## Press a reply by id, as a tap would (tests and autoplay).
func choose(id: String) -> bool:
	var b := _talk.get_node_or_null("Reply_" + id) as Button
	if b == null or b.disabled:
		return false
	b.pressed.emit()
	return true


func has_reply(id: String, enabled_only: bool = true) -> bool:
	var b := _talk.get_node_or_null("Reply_" + id) as Button
	return b != null and (not enabled_only or not b.disabled)


func _note(text: String, tone: Color = Style.MORALE_HIGH) -> Control:
	var p := PanelContainer.new()
	p.name = "Note"
	p.add_theme_stylebox_override("panel", Style.box(Color(tone, 0.12), Color(tone, 0.6), 2, 12))
	var l := Style.label(text, Style.SMALL, tone.lightened(0.3))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.add_child(l)
	return p


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
	var said := LordVoice.line("greet", lord)
	var a := said.find("\"")
	var b := said.rfind("\"")
	var words := said.substr(a + 1, b - a - 1) if a >= 0 and b > a else "Well met, captain."
	if String(lord.get("realm", "")) == Data.CROWN:
		words = "My liege. %s is held, and my riders are ready." % (Data.settlement(String(lord["fief"]))["name"] if String(lord.get("fief", "")) != "" else "All")
	elif reason == "first":
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
			extras.append(_note("+%d Regard · first word at the table" % bonus))
	_show("\"%s\"" % words, extras, _root_replies())


func _house_line() -> String:
	var fief := String(lord.get("fief", ""))
	if bool(lord.get("ruler", false)):
		return "I rule %s" % Data.the_realm(String(Data.FACTIONS[String(lord["realm"])]["name"])) if Data.FACTIONS.has(String(lord["realm"])) else "I rule here"
	return "I hold %s" % Data.settlement(fief)["name"] if fief != "" else "My house is %s" % String(lord.get("house", ""))


func _root_replies() -> Array:
	var out := []
	var news: Array = world.fresh_news()
	out.append({"id": "news", "text": "Peaceably. What news from the war?" if _beat == "greet" else "What news from the war?",
		"tag": ("%d thing%s you haven't heard" % [news.size(), "" if news.size() == 1 else "s"]) if not news.is_empty() else "no news since you last heard",
		"act": _beat_news})
	out.append({"id": "trouble", "text": "Something weighs on you, %s." % String(lord.get("house", LordTalk.first_name(lord))),
		"tag": "learn what they want", "act": _beat_trouble})
	if not LordTalk.stories(gs, lord).is_empty():
		out.append({"id": "story", "text": "A story for the road?", "tag": "talk · builds Regard", "act": _beat_stories})
	var army_ride: bool = gs.has_contract() and gs.contract_realm() == String(lord.get("realm", "")) and int(lord.get("party", -1)) >= 0
	if army_ride and mode != "hall":
		var pid := int(lord["party"])
		if world.following_party == pid:
			out.append({"id": "part", "text": "I'll ride my own road now.", "tag": "stop riding with them", "act": func():
				world.following_party = -1
				_leave()})
		else:
			out.append({"id": "ride", "text": "Let us ride with you.", "tag": "follow their army", "act": func():
				wants_follow.emit(pid)
				_leave()})
	out.append_array(_order_replies())
	out.append_array(_crown_replies())
	var ch := LordTalk.challenge_check(gs, lord)
	if mode == "hall":
		# No swords under a host's roof: a challenge is a duel outside the walls at dawn.
		if String(lord.get("realm", "")) != Data.CROWN:
			var dc := LordTalk.duel_check(gs, lord)
			out.append({"id": "outside", "text": "Meet me outside the walls at dawn.",
				"tag": ("a duel · no swords under %s roof" % _roof_possessive()) if bool(dc["ok"]) else String(dc["reason"]),
				"tone": "red" if bool(dc["ok"]) else "locked", "act": _beat_duel})
		out.append(_leave_reply(_hall_goodbye()))
		return out
	if bool(ch["ok"]) or String(lord.get("realm", "")) != Data.CROWN:
		out.append({"id": "sword", "text": "Draw your sword.",
			"tag": ("challenge · means war with %s" % _realm_name()) if bool(ch["ok"]) and bool(ch["war"]) else ("challenge" if bool(ch["ok"]) else String(ch["reason"])),
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
	var out := []
	if kind != "follow":
		out.append({"id": "order_follow", "text": "Ride with me.", "tag": "order · they follow you and join your fights", "tone": "gold", "act": func():
			gs.order_lord(lid, "follow")
			_show("\"At your side, then.\"", [_note("%s rides with you." % LordTalk.short_name(lord), Style.BRASS)], [_leave_reply("Good.")])})
	var hold := String(lord.get("fief", ""))
	if hold == "" or not gs.crown_holdings().has(hold):
		hold = world.capital_of(Data.CROWN)
	if hold != "" and not (kind == "guard" and String(order.get("target", "")) == hold):
		out.append({"id": "order_guard", "text": "Hold %s for the crown." % Data.settlement(hold)["name"], "tag": "order · they guard it", "act": func():
			gs.order_lord(lid, "guard", hold)
			_show("\"It will stand.\"", [_note("%s will hold %s." % [LordTalk.short_name(lord), Data.settlement(hold)["name"]], Style.BRASS)], [_leave_reply("Good.")])})
	if kind != "":
		out.append({"id": "order_free", "text": "Go about the realm's business.", "tag": "order · they choose for themselves", "act": func():
			gs.order_lord(lid, "")
			_show("\"As you say.\"", [], [_leave_reply("Go well.")])})
	return out


## The crown lines: open once you're crowned, shown locked before so you know they're coming.
func _crown_replies() -> Array:
	if String(lord.get("realm", "")) == Data.CROWN:
		return []
	var check := LordTalk.persuade_check(gs, lord)
	if not gs.is_crowned():
		return [{"id": "crown", "text": "Swear to my banner.", "tag": "raise your own banner first", "tone": "locked"},
			{"id": "price", "text": "Name your price to change sides.", "tag": "raise your own banner first", "tone": "locked"}]
	if not bool(check["ok"]):
		return [{"id": "crown", "text": "I've come to talk of crowns.", "tag": String(check["reason"]), "tone": "locked"}]
	var c := LordTalk.conviction(gs, lord)
	return [{"id": "crown", "text": "I've come to talk of crowns.", "tag": "win them over · convinced %d / %d" % [c, LordTalk.CONVINCED],
		"tone": "gold", "act": _beat_persuade.bind(true)}]


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
		replies.append({"id": "king", "text": "And what will %s do?" % LordTalk.ruler_name(lord),
			"tag": "their view of their ruler" + (" · counts toward crowns" if gs.is_crowned() else ""), "act": _beat_king})
	if mode != "hall":
		replies.append({"id": "chronicle", "text": "More in the chronicle.", "tag": "opens War & Politics", "act": func(): wants_news.emit()})
	replies.append({"id": "back", "text": "Something else.", "tag": "", "act": _beat_greet_again})
	replies.append(_leave_reply("Thank you. Safe roads."))
	_show(speech, extras, replies)


func _news_chip(e: Dictionary) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Style.box(Style.PANEL, Style.RULE, 2, 10))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var hours: float = world.hour - float(e.get("hour", 0.0))
	var when := "Today" if hours < 24.0 else ("Yesterday" if hours < 48.0 else "%d days ago" % int(hours / 24.0))
	var w := Style.label(when, Style.SMALL - 2, Style.BRASS)
	h.add_child(w)
	var t := Style.label(String(e.get("text", "")), Style.SMALL - 2, Style.TEXT)
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
		if String(s["theme"]) == LordTalk.likes(lord) and LordTalk.like_known(lord):
			tag += " · they like %s" % LordTalk.THEME_WORDS[s["theme"]]
		elif String(s["theme"]) == LordTalk.dislikes(lord) and LordTalk.dislike_known(lord):
			tag += " · they dislike %s" % LordTalk.THEME_WORDS[s["theme"]]
		replies.append({"id": "tell_" + String(s["id"]), "text": String(s["says"]), "tag": tag, "act": _tell.bind(String(s["id"]))})
	replies.append({"id": "back", "text": "Another time.", "act": _beat_greet_again})
	var ask := "\"Go on, then. Tell me something your company did that I won't have heard in a tavern.\""
	_show(ask, [], replies)


func _tell(story_id: String) -> void:
	var r := LordTalk.tell_story(gs, lord, story_id)
	var extras := []
	var change := int(r.get("regard", 0))
	var line := "%s%d Regard." % ["+" if change > 0 else "", change]
	if String(r.get("learned", "")) != "":
		line += " " + String(r["learned"])
	extras.append(_note(line, Style.MORALE_HIGH if change > 0 else Style.MORALE_LOW))
	var replies := []
	if not LordTalk.stories(gs, lord).is_empty():
		replies.append({"id": "story", "text": "Another?", "tag": "tell another", "act": _beat_stories})
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
		replies.append({"id": "take", "text": "I'll clear %s." % String(tr["name"]),
			"tag": "your journal is full" if full else "new job · +%d Regard when done%s" % [LordTalk.JOB_REGARD, " · counts toward crowns" if gs.is_crowned() else ""],
			"tone": "locked" if full else "gold", "act": _take_trouble.bind(0)})
		if int(LordTalk.record(lord).get("haggled", 0)) == 0:
			var cost := LordTalk.haggle_cost(lord)
			replies.append({"id": "haggle", "text": "What would that be worth to you?",
				"tag": "they'd add %d silver%s" % [LordTalk.haggle_silver(lord), (" · %d Regard, %s dislikes haggling" % [cost, String(lord["bearing"])]) if cost != 0 else ""],
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
		{"id": "take", "text": "Done. I'll clear %s." % String(tr.get("name", "them")), "tag": "new job · %d silver · +%d Regard when done" % [silver, LordTalk.JOB_REGARD],
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
		out.append({"id": "arg_" + String(a["id"]), "text": String(a["says"]), "tag": String(a["tag"]), "act": _argue.bind(String(a["id"]))})
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 8)
	chips.add_theme_constant_override("v_separation", 8)
	for amount in LordTalk.SILVER_OFFERS:
		var b := Button.new()
		b.name = "Silver_%d" % amount
		b.text = "%s · +%d" % [Widgets.thousands(amount), amount / LordTalk.SILVER_PER_POINT]
		b.disabled = int(gs.silver) < amount
		b.add_theme_font_size_override("font_size", Style.text_size(Style.SMALL))
		b.custom_minimum_size = Vector2(0, 56)
		b.focus_mode = Control.FOCUS_NONE
		var sb := Style.box(Color("3a2c10"), Style.BRASS, 2, 14)
		b.add_theme_stylebox_override("normal", sb)
		b.pressed.connect(func():
			_said = "Then let me make it worth the risk. %s silver." % Widgets.thousands(amount)
			_offer(amount))
		chips.add_child(b)
	out.append({"id": "silver", "text": "Then let me make it worth the risk.", "tag": "name a sum · from %s" % Widgets.thousands(int(gs.silver)),
		"tone": "gold", "extra": chips})
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
		_show(String(r["reaction"]), [_note("They refuse you: %d Regard, and they won't hear of it for a week." % LordTalk.REFUSAL_REGARD, Style.MORALE_LOW)],
			[_leave_reply("As you like.")])
		return
	if bool(r.get("sworn", false)):
		_beat_sworn()
		return
	var extras := [_conviction_bar()]
	if String(r.get("learned", "")) != "":
		extras.append(_note(String(r["learned"]), Style.BRASS))
	var pts := int(r.get("points", 0))
	extras.push_front(_note("%s%d toward conviction" % ["+" if pts >= 0 else "", pts], Style.MORALE_HIGH if pts > 0 else Style.MORALE_LOW))
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
	var lines := []
	if String(r["fief"]) != "":
		lines.append("%s%s join your realm" % [Data.settlement(String(r["fief"]))["name"], " and its villages" if not (r["villages"] as Array).is_empty() else ""])
	lines.append("%d men" % int(r["men"]))
	lines.append("Bought with silver: may leave if Regard falls below 0" if bool(r["bought"]) else "Sworn in good faith: silver under half the case")
	var body := Style.label(" · ".join(PackedStringArray(lines)), Style.SMALL, Style.TEXT)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(body)
	var from := String(r["from"])
	var cost := Style.label("%s's opinion of your crown −30" % (String(Data.FACTIONS[from]["name"]) if Data.FACTIONS.has(from) else from), Style.SMALL, Style.ENEMY_LIGHT)
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(cost)
	card.add_child(v)
	var fief := String(r["fief"])
	var replies := []
	if fief != "":
		var lid := int(lord["id"])
		replies.append({"id": "hold", "text": "Hold %s for the crown." % Data.settlement(fief)["name"], "tag": "order · they guard their lands", "act": func():
			gs.order_lord(lid, "guard", fief)
			_leave()})
		replies.append({"id": "order_follow", "text": "Ride with me.", "tag": "order · they follow you and join your fights", "act": func():
			gs.order_lord(lid, "follow")
			_leave()})
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
		stakes.add_theme_constant_override("separation", 6)
		var sl := Style.label("You %d · %s %d%s" % [int(st["mine"]), LordTalk.first_name(lord), int(st["theirs"]),
			" · already at war" if not bool(ch.get("war", false)) else " · means war with %s" % _realm_name()], Style.SMALL - 2, Style.TEXT)
		sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stakes.add_child(sl)
		var wl := Style.label("Win: likely your captive, +15 renown, 150 silver · Lose: about %d men, the rest fall back" % int(st["lost"]), Style.SMALL - 2, Style.MUTED)
		wl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stakes.add_child(wl)
		var go := Button.new()
		go.name = "DrawSwords"
		go.text = "Draw swords"
		go.icon = Widgets.icon("fight")
		go.expand_icon = false
		go.custom_minimum_size = Vector2(0, 60)
		go.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		go.add_theme_stylebox_override("normal", Style.box(Style.ENEMY, Color(0, 0, 0, 0), 0, 14))
		go.add_theme_stylebox_override("hover", Style.box(Style.ENEMY.lightened(0.1), Color(0, 0, 0, 0), 0, 14))
		go.add_theme_stylebox_override("pressed", Style.box(Style.ENEMY_DARK, Style.TEXT, 2, 14))
		go.pressed.connect(_draw_swords)
		stakes.add_child(go)
		replies.append({"id": "battle", "text": "Then settle it here, your riders against mine.", "tag": "battle", "tone": "red", "extra": stakes})
	var dc := LordTalk.duel_check(gs, lord)
	replies.append({"id": "duel", "text": "Your champion and mine.", "tag": "single combat · no armies, no war" if bool(dc["ok"]) else String(dc["reason"]),
		"tone": "red" if bool(dc["ok"]) else "locked", "act": _beat_duel})
	var tc := LordTalk.tribute_check(gs, lord)
	if String(lord.get("bearing", "")) == Lords.CRUEL and world.relation_to_player(String(lord.get("realm", ""))) == "hostile":
		replies.append({"id": "tribute", "text": "Here, %d silver for the road." % LordTalk.TRIBUTE,
			"tag": ("tribute · Cruel lords like this · +%d Regard" % LordTalk.TRIBUTE_REGARD) if bool(tc["ok"]) else String(tc["reason"]),
			"tone": "plain" if bool(tc["ok"]) else "locked", "act": _pay_tribute})
	if blocked:
		replies.append_array(_crown_replies().filter(func(r): return String(r.get("tone", "")) != "locked"))
		replies.append({"id": "back", "text": "Let me think.", "tag": "back to the road", "act": _leave})
	else:
		replies.append({"id": "back", "text": "Another time.", "tag": "nothing changes", "act": _beat_greet_again})
	_show(speech, [], replies)


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
		_show("\"Wise. Ride on, then, before I change my mind.\"", [_note("-%d silver, +%d Regard. They let you pass." % [LordTalk.TRIBUTE, LordTalk.TRIBUTE_REGARD], Style.BRASS)],
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
		var n := Style.label(String(cap.get("first", cap.get("name", ""))), Style.SMALL - 2, Style.TEXT)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(n)
		var odds := Style.label("%s · %d%%" % [Troops.TYPES.get(String(c["type"]), {}).get("name", String(c["type"])), roundi(LordTalk.duel_chance(cap, lord) * 100.0)], Style.SMALL - 4, Style.MUTED)
		odds.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(odds)
		b.add_child(v)
		var sid := int(c["squad"])
		var who := String(cap.get("first", "my captain"))
		b.pressed.connect(func():
			_said = "My champion is %s." % who
			_fight_duel(sid))
		row.add_child(b)
	var win := LordTalk.duel_win_regard(lord)
	var stakes := Style.label("Win: +%d Regard%s, +%d renown · Lose: your champion is wounded for %d battles, %d Regard" % [
		win, " (they respect strength)" if win == LordTalk.DUEL_WIN_REGARD else "", LordTalk.DUEL_RENOWN, 2, LordTalk.DUEL_LOSE_REGARD], Style.SMALL - 2, Style.MUTED)
	stakes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.add_child(row)
	box.add_child(stakes)
	_show("\"Ha! A duel, then. Choose your champion. Mine has never lost.\"", [],
		[{"id": "champion", "text": "My champion is...", "tag": "choose a captain", "tone": "red", "extra": box},
		{"id": "back", "text": "On second thought, no.", "tag": "nothing changes", "act": _beat_greet_again}])


func _fight_duel(squad_id: int) -> void:
	var r := LordTalk.duel(gs, lord, squad_id)
	if not bool(r.get("ok", false)):
		_beat_greet_again()
		return
	Sound.play("charge" if bool(r["won"]) else "bell")
	gs.save_game()
	var said := ""
	var note := ""
	if bool(r["won"]):
		said = "\"...Yielded. Your %s fights like a devil. I'll remember this, captain.\"" % String(r["captain"]).split(" ")[0]
		note = "%s won. +%d Regard, +%d renown." % [String(r["captain"]), int(r["regard"]), int(r["renown"])]
	else:
		said = "\"Get your champion to a surgeon. Better luck next time.\""
		note = "%s was beaten and wounded: out for 2 battles. %d Regard." % [String(r["captain"]), int(r["regard"])]
	_show(said, [_note(note, Style.MORALE_HIGH if bool(r["won"]) else Style.MORALE_LOW)],
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
		replies.append({"id": "swear", "text": "Swear to my crown.", "tag": "join your realm" if bool(sw["ok"]) else String(sw["reason"]),
			"tone": "gold" if bool(sw["ok"]) else "locked", "act": func():
				if gs.swear_lord_to_crown(lid):
					Sound.play("horn")
					_banner_realm = "crown"
					_show("\"So be it. I'll serve your crown.\"", [_note("%s swears to your crown." % LordTalk.short_name(lord), Style.BRASS)], [_leave_reply("Welcome.")])})
	else:
		replies.append({"id": "swear", "text": "Swear to my crown.", "tag": "raise your own banner first", "tone": "locked"})
	replies.append({"id": "release", "text": "Go home, and remember who freed you.",
		"tag": "release for honor · +%d Regard · %s +%d" % [gs.RELEASE_REGARD, _realm_name(), gs.RELEASE_REALM], "tone": "gold", "act": func():
			gs.release_lord_for_honor(lid)
			Sound.play("page")
			_show("\"I won't forget it.\"", [_note("Released. +%d Regard." % gs.RELEASE_REGARD)], [_leave_reply("Go.")])})
	var ransom := int(lord.get("ransom_amount", Lords.ransom_for(int(lord.get("renown", 0)))))
	replies.append({"id": "ransom", "text": "Your house will pay %d silver for you." % ransom, "tag": "ransom · +5 Regard", "act": func():
		gs.accept_lord_ransom(lid)
		Sound.play("coins")
		_show("\"They'll pay. Gladly, I expect.\"", [_note("+%d silver." % ransom, Style.BRASS)], [_leave_reply("Go.")])})
	if gs.has_contract() and world.at_war(gs.contract_realm(), String(lord.get("realm", ""))):
		replies.append({"id": "deliver", "text": "My employer will want to see you.", "tag": "deliver for the bounty", "act": func():
			gs.deliver_lord_to_employer(lid)
			Sound.play("coins")
			_leave()})
	replies.append({"id": "chains", "text": "Then you'll stay in chains.", "tag": "%d Regard · Honorable lords hear of it" % LordTalk.CHAINS_REGARD, "tone": "red", "act": func():
		LordTalk.keep_in_chains(gs, lord)
		gs.save_game()
		_show("\"...\"", [_note("%d Regard." % LordTalk.CHAINS_REGARD, Style.MORALE_LOW)], [_leave_reply("Take them back.")])})
	replies.append(_leave_reply("Later."))
	_show(speech, [], replies)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_leave()
