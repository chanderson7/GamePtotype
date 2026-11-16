## The wedding, on the day. The ceremony, a beat at a time and by your hand: who came, who
## stands with you, her vow and yours (her face answers it), her people's rite done step
## by step, and the question, asked of her and then of you, answered "I do": that is the
## moment you're married. Then the feast (wedding_feast.gd), until you slip away with her.
## Opened while the feast is still going, it goes back to it. Opened from the memory book
## (Scenes.wedding_replay), it tells the day again as it was and changes nothing. The
## rules are in GameState and the social sim.
extends "res://scripts/menu/wedding_feast.gd"

const Stories = preload("res://scripts/data/personal_conversations.gd")
const Rite = preload("res://scripts/ui/wedding_rite.gd")

## The rite as it's done today (Lines.RITE_STEPS for her people) and what you chose in it.
var _rite_steps := {}
var _rite_choice := ""
var _rite: Rite


func _ready() -> void:
	var social = GameState.world.social if GameState.world != null else null
	if social == null:
		_nothing(Lines.NOTHING["no_one"])
		return
	var rejoin := false
	if Scenes.wedding_replay != "":
		_memory = _find_memory(social, Scenes.wedding_replay)
		if _memory.is_empty():
			_nothing(Lines.NOTHING["faded"])
			return
		cand = String(_memory.get("candidate", ""))
		place = String(_memory.get("place", ""))
	elif GameState.wedding_feast_here():
		rejoin = true
		cand = String(GameState.wedding()["candidate_id"])
		place = String(GameState.wedding()["place"])
	else:
		if not GameState.wedding_can_begin():
			_nothing(Lines.NOTHING["not_ready"])
			return
		var w: Dictionary = GameState.wedding()
		cand = String(w["candidate_id"])
		place = String(w["place"])
	var person: Dictionary = social.get_candidate_person(cand)
	person_id = String(person.get("id", ""))
	_name = String(person.get("name", ""))
	culture = String(person.get("culture", ""))
	var alone := bool(_memory.get("private", false))
	var when := TalkView.time_word(GameState.world.hour) if _memory.is_empty() else "dusk"
	if alone:
		when = "night"
	setup(TalkView.room(String(ROOMS.get(cand, "common_room")), "night") if alone else _make_backdrop(when), _caption(when, rejoin))
	if not alone:
		_dress(when)
	set_face("center", _portrait("amused" if rejoin else "warm"), false, 0.9)
	# The ceremony to her people's quiet music; the feast's starts at "I do". Remembered
	# alone with you, the quiet one.
	Sound.play_music(("feast_" if rejoin or (not _memory.is_empty() and not alone) else "camp_") + culture)
	_road = Lines.road(social.memory_book(person_id))
	if not _memory.is_empty():
		_tell_again()
		return
	_guests = GameState.wedding_guests()
	for g in _guests["guests"]:
		if String(g["kind"]) == "host":
			_host = g
	if rejoin:
		_rejoin()
		return
	_their = Lines.their_vow(cand, social.memory_book(person_id))
	_arrive()


static func _find_memory(social, id: String) -> Dictionary:
	for c in ["edda", "farid", "kaede"]:
		var p: Dictionary = social.get_candidate_person(c)
		for m in social.memory_book(String(p.get("id", ""))):
			if String(m.get("id", "")) == id:
				var out: Dictionary = m.duplicate()
				out["candidate"] = String(out.get("candidate", c))
				return out
	return {}


func _caption(when: String, rejoin: bool = false) -> String:
	if bool(_memory.get("private", false)):
		return "%s's room at %s · night" % [_name, _place_name()]
	var what := "Remembered" if not _memory.is_empty() else ("The feast" if rejoin else "Your wedding")
	return "%s at %s · %s" % [what, _place_name(), when]


# ---------------------------------------------------------------- arriving

func _arrive() -> void:
	var lords: int = _guests["guests"].size()
	var guests := TalkView.stage_chip(str(lords), Style.TEXT, "men")
	guests.tooltip_text = "%d guest%s" % [lords, "" if lords == 1 else "s"]
	_set_chips("Wedding day", [guests])
	clear_log()
	var hers := String(GameState.world.social.get_candidate_person(cand).get("residence", ""))
	var kind := "hers" if place == hers else ("yours" if place == GameState.wedding_seat() else "other")
	say("narration", _fill(Lines.ARRIVAL[kind]))
	say("narration", _fill(String(Lines.ARRIVAL_SET.get(culture, Lines.ARRIVAL_SET[Cultures.VARDISH]))))
	add_to_log(_guest_card())
	wait_to_continue(_greet, Lines.GO_ON)


## Her first words to you, and the day waits on yours.
func _greet() -> void:
	say("them", Lines.STAND.get(cand, Lines.STAND["edda"]), _name)
	set_replies([
		{"id": "begin", "text": _fill(Lines.BEGIN), "bare": true, "tone": "gold", "tag": Lines.BEGIN_TAG, "act": _seconds},
		{"id": "later", "text": Lines.NOT_YET, "tone": "quiet", "tag": _fill(Lines.NOT_YET_TAG), "act": close}])


## Who came: their faces in a row, then who stayed away and who sent a gift.
func _guest_card() -> Control:
	var p := PanelContainer.new()
	p.name = "WhoCame"
	p.add_theme_stylebox_override("panel", Style.box(Style.PANEL, Style.RULE, 2, 14))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	v.add_child(Widgets.section("Who came · %d" % _guests["guests"].size()))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 10)
	row.add_theme_constant_override("v_separation", 8)
	v.add_child(row)
	for g in _guests["guests"]:
		var cell := VBoxContainer.new()
		cell.name = "Guest_%s_%d" % [g["kind"], int(g["id"])]
		cell.custom_minimum_size = Vector2(100, 0)
		cell.add_theme_constant_override("separation", 4)
		var face := TextureRect.new()
		face.texture = CaptainArt.texture(g["face"])
		face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.custom_minimum_size = Vector2(72, 96)
		cell.add_child(face)
		var nm := Style.label(String(g.get("short", g["name"])).get_slice(" ", 0), Style.SMALL, Style.TEXT)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.clip_text = true
		cell.add_child(nm)
		cell.add_child(_role_badge(g))
		row.add_child(cell)
		# The guests come in one after another.
		if not Style.motion_reduced():
			cell.modulate.a = 0.0
			cell.create_tween().tween_property(cell, "modulate:a", 1.0, 0.22).set_delay(minf(0.3 + 0.09 * row.get_child_count(), 1.6))
	var bits := PackedStringArray()
	if String(_guests.get("gift_from", "")) != "":
		bits.append("%s sent %s instead." % [_guests["gift_from"], Lines.GIFTS.get(culture, "a gift")])
	for a in _guests["absent"]:
		bits.append(Feast.STAYED_AWAY % [a["name"], a["reason"]])
	if not bits.is_empty():
		var l := Style.label(" ".join(bits), Style.SMALL, Style.MUTED)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	return p


## A guest's part in the day as a badge: the keep for the host, the crown for your lord,
## the company for a captain, and Regard gained for a lord who came.
func _role_badge(g: Dictionary) -> Control:
	var kind := String(g["kind"])
	var badge: PanelContainer
	match kind:
		"lord":
			badge = Widgets.effect("bond", int(g.get("regard", 0)))
		_:
			var key: String = {"host": "keep", "crown_lord": "crown", "captain": "company"}.get(kind, "men")
			badge = Widgets.chip("", Style.BRASS if kind == "host" else Style.MUTED, "", key)
			badge.tooltip_text = {"host": "Host", "crown_lord": "Your lord", "captain": "Captain"}.get(kind, "")
	badge.name = "Role"
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return badge


# ---------------------------------------------------------------- who stands with you

## Who stands with you: a captain from your company, by what they are to you, or no one.
## With no captain left, nobody is asked.
func _seconds() -> void:
	var offered: Array = GameState.wedding_seconds()
	if offered.is_empty():
		_vows()
		return
	clear_log()
	add_to_log(note(Lines.SECOND_PROMPT, Style.BRASS))
	var replies := []
	for s in offered:
		replies.append({"id": "second_%d" % int(s["id"]), "text": String(s["name"]), "bare": true, "tag": String(s["tag"]),
			"face": CaptainArt.texture(s["face"]), "act": _stand.bind(s)})
	replies.append({"id": "second_none", "text": Lines.SECOND_NONE, "tone": "quiet", "act": _stand.bind({})})
	set_replies(replies)


func _stand(s: Dictionary) -> void:
	_second = s
	_second_steps_up()
	_vows()


# ---------------------------------------------------------------- vows

func _vows() -> void:
	Sound.play("bell", 0.0, 0.0)
	_set_chips("Wedding day")
	clear_log()
	if not _second.is_empty():
		say("narration", _fill(String(Lines.SECOND_STANDS.get(String(_second.get("why", "")), Lines.SECOND_STANDS["longest"]))))
	# The head of her house on how you come to be standing here, then the old words.
	if _host.is_empty():
		say("narration", _fill(Lines.OFFICIANT))
	else:
		_say_with_face(Lines.host_word(cand, String(_road.get("council", ""))), Lines.HOST_ROLE % _host_name(), _host["face"])
		say("narration", _fill(Lines.OLD_WORDS))
	wait_to_continue(_vow_hers, Lines.GO_ON)


## What you did for her people, in a line of hers; then her vow.
func _vow_hers() -> void:
	var did := Lines.their_road(cand, String(_road.get("task", "")))
	if did != "":
		say("them", did, _name)
	_their_vow(String(_their.get("text", "")), String(_their.get("scene_id", "")), int(_their.get("day", 0)))
	wait_to_continue(_vow_yours, Lines.GO_ON)


## Then yours: one of three.
func _vow_yours() -> void:
	add_to_log(note(Lines.VOW_PROMPT, Style.MUTED))
	var replies := []
	for v in Lines.yours(cand):
		replies.append({"id": "vow_" + String(v["id"]), "text": String(v["text"]), "tag": String(v["tag"]), "act": _said_vow.bind(String(v["id"]), String(v["text"]))})
	set_replies(replies)


## Her vow, and (when it comes from a time you shared) which one she remembers.
func _their_vow(text: String, scene_id: String, day: int) -> void:
	var holder := say("them", text, _name)
	if scene_id == "" or not Stories.SCENES.has(scene_id):
		return
	var v := (holder.get_child(0) as Control).get_child(0) as VBoxContainer
	var h := HBoxContainer.new()
	h.name = "Remembers"
	h.add_theme_constant_override("separation", 6)
	var i := Widgets.icon_rect("cup", 26)
	i.modulate = Style.ROMANCE_LIGHT
	h.add_child(i)
	h.add_child(Style.label(Lines.REMEMBERS % String(Stories.SCENES[scene_id]["title"]).to_lower(), Style.SMALL, Style.ROMANCE_LIGHT))
	if day > 0:
		h.add_child(Widgets.icon_value("day", str(day), Style.ROMANCE_LIGHT))
	v.add_child(h)


## Your vow, and her answer: her face first (warm to a promise, a held beat then warm to
## honesty, a laugh to the one meant to make her laugh), then a word of her own.
func _said_vow(id: String, text: String) -> void:
	_vow = text
	say("you", text)
	var mood := String(Lines.VOW_FACE.get(id, "warm"))
	express("center", _portrait(mood), mood)
	if mood == "neutral":
		if Style.motion_reduced():
			express("center", _portrait("warm"), "warm")
		else:
			var t := create_tween()
			t.tween_interval(1.1)
			t.tween_callback(express.bind("center", _portrait("warm"), "warm"))
	var answer := Lines.vow_answer(cand, id)
	if answer != "":
		say("them", answer, _name)
	_rite_begin()


# ---------------------------------------------------------------- the rite, by your hand

func _rite_begin() -> void:
	_rite_steps = Lines.rite_steps(culture)
	_rite = Rite.new()
	_rite.name = "Rite"
	_rite.culture = culture
	stage.add_child(_rite)
	# Over the couple and the fade, under the caption and the nameplate.
	var fade := stage.get_node_or_null("Fade")
	if fade != null:
		stage.move_child(_rite, fade.get_index() + 1)
	say("narration", _fill(String(_rite_steps["intro"])))
	if not _second.is_empty():
		say("narration", _fill(String(Lines.SECOND_HANDS.get(culture, Lines.SECOND_HANDS[Cultures.VARDISH]))))
	_rite_step(0)


## The rite's next step as one gold reply; after its plain steps, its choice.
func _rite_step(i: int) -> void:
	var steps: Array = _rite_steps["steps"]
	if i < steps.size():
		var st: Dictionary = steps[i]
		set_replies([{"id": "rite_" + String(st["id"]), "text": _fill(String(st["text"])), "tag": String(st["tag"]), "tone": "gold", "bare": true,
			"act": _did_rite.bind(i)}])
		return
	add_to_log(note(_fill(String(_rite_steps["prompt"])), Style.BRASS))
	var replies := []
	for ch in _rite_steps["choices"]:
		replies.append({"id": "rite_" + String(ch["id"]), "text": _fill(String(ch["text"])), "tag": String(ch["tag"]),
			"bare": bool(ch.get("bare", false)), "act": _chose_rite.bind(ch)})
	set_replies(replies)


func _did_rite(i: int) -> void:
	_rite.advance()
	say("narration", _fill(String(_rite_steps["steps"][i]["line"])))
	_rite_step(i + 1)


func _chose_rite(ch: Dictionary) -> void:
	_rite_choice = String(ch["id"])
	if not bool(ch.get("bare", false)):
		say("you", _fill(String(ch["text"])))
	_rite.choice = _rite_choice
	_rite.advance()
	say("narration", _fill(String(ch["line"])))
	if String(_rite_steps.get("after", "")) != "":
		say("narration", _fill(String(_rite_steps["after"])))
	wait_to_continue(_question, Lines.GO_ON)


# ---------------------------------------------------------------- the question

## The place goes quiet. The host (or the elder) asks her in her people's words, and
## she answers first; then you're asked. "I do" is held (a tap says it too); "Take a
## breath" once first, if you like. There is no other answer.
func _question() -> void:
	_set_chips(Lines.QUESTION_CHIP)
	var d := _dressing()
	if d != null:
		d.hush(true)
	Sound.hush_music(true)
	if not _second.is_empty():
		say("other", Lines.whisper(_second.get("captain", {})), Lines.UNDER_BREATH % _second_name())
	var q := Lines.question(culture)
	if _host.is_empty():
		say("narration", _fill(Lines.ELDER_ASKS))
	_ask(String(q["her"]))
	# Where her people ask more than once, the askings she lets pass are a beat of their own.
	var again: Array = Lines.ASKED_AGAIN.get(culture, [])
	if again.is_empty():
		_she_answers()
		return
	for i in again.size():
		say("narration", _fill(String(again[i])))
		if i < again.size() - 1:
			_ask(String(q["her"]))
	wait_to_continue(func():
		_ask(String(q["her"]))
		_she_answers(), Lines.GO_ON)


## She answers first; then you're asked.
func _she_answers() -> void:
	say("them", String(Lines.ANSWER.get(cand, Lines.ANSWER["edda"])), _name)
	express("center", _portrait("warm"), "warm")
	_ask(String(Lines.question(culture)["you"]))
	_answer_replies(true)


## The question, asked by the host (face beside the name) or the elder (in her people's words).
func _ask(text: String) -> void:
	if _host.is_empty():
		say("narration", "\"%s\"" % _fill(text))
	else:
		_say_with_face(_fill(text), Lines.HOST_ROLE % _host_name(), _host["face"])


func _answer_replies(breath_too: bool) -> void:
	var replies := [{"id": "i_do", "text": Lines.I_DO, "tone": "gold", "bare": true, "hold": true, "tag": Lines.I_DO_TAG, "act": _i_do}]
	if breath_too:
		replies.append({"id": "breath", "text": Lines.BREATHE, "tone": "quiet", "act": _take_breath})
	set_replies(replies)


func _take_breath() -> void:
	_breath = true
	say("narration", Lines.BREATH)
	if not _second.is_empty():
		say("other", Lines.BREATH_SECOND, _second_name())
	else:
		say("narration", Lines.BREATH_ALONE)
	say("narration", String(Lines.BREATH_HER.get(cand, Lines.BREATH_HER["edda"])))
	express("center", _portrait("neutral"), "neutral")
	_answer_replies(false)


## "I do": married, there and then. The hall erupts, "Married" lands across the stage, the
## seal is made, and the feast begins.
func _i_do() -> void:
	say("you", Lines.I_DO)
	var r: Dictionary = GameState.finish_wedding({"vow": _vow, "their_vow": String(_their.get("text", "")),
		"second": int(_second.get("id", -1)), "rite": _rite_choice, "breath": _breath})
	if not bool(r.get("ok", false)):
		add_to_log(note(String(r.get("reason", "Something went wrong.")), Style.MORALE_LOW))
		set_replies([{"id": "leave", "text": Feast.BACK_TO_MAP, "tone": "quiet", "act": close}])
		return
	Sound.play("bell", 0.0, 0.0)
	Sound.play("cheer_1", -4.0, 0.0)
	var d := _dressing()
	if d != null:
		d.hush(false)
		d.burst()
	express("center", _portrait("amused"), "amused")
	_land_married()
	say("narration", _fill(String(Lines.SEAL.get(culture, Lines.SEAL[Cultures.VARDISH]))))
	_rite_away()
	Sound.play_music("feast_" + culture)
	say("narration", String(Feast.OPEN.get(culture, Feast.OPEN[Cultures.VARDISH])))
	_feast()


## "Married", in brass across the stage, said once: it lands, holds, and fades. Under
## Reduced motion it stays until the feast moves on.
func _land_married() -> void:
	var l := Style.label(Lines.MARRIED, Style.TITLE_SIZE + 12, Style.BRASS)
	l.name = "MarriedTitle"
	var font := Style.display_font()
	if font != null:
		l.add_theme_font_override("font", font)
	l.add_theme_constant_override("outline_size", 12)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.08, 0.85))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.anchor_right = 1.0
	l.anchor_top = 0.2
	l.anchor_bottom = 0.46
	stage.add_child(l)
	var fade := stage.get_node_or_null("Fade")
	if fade != null:
		stage.move_child(l, fade.get_index() + 1)
	if Style.motion_reduced():
		return
	l.modulate.a = 0.0
	l.offset_top = 24.0
	l.offset_bottom = 24.0
	var t := l.create_tween()
	t.set_parallel()
	t.tween_property(l, "modulate:a", 1.0, 0.35)
	t.tween_property(l, "offset_top", 0.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "offset_bottom", 0.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.chain().tween_interval(2.6)
	t.chain().tween_property(l, "modulate:a", 0.0, 0.7)
	t.chain().tween_callback(func(): l.visible = false)


## The rite's prop goes, its work done.
func _rite_away() -> void:
	if _rite == null or not is_instance_valid(_rite):
		return
	if Style.motion_reduced():
		_rite.queue_free()
		return
	var t := _rite.create_tween()
	t.tween_property(_rite, "modulate:a", 0.0, 1.2).set_delay(1.4)
	t.tween_callback(_rite.queue_free)


# ---------------------------------------------------------------- remembered

## The day told again, in order, as it was: who stood with you, what she said of what you
## did, both vows and her answer, the rite and your choice in it, the question and both
## answers, the toasts as they were said, your toast, the dance, the custom, her last
## words. A wedding kept before the day was played this way is told as it was kept.
func _tell_again() -> void:
	_set_chips(Lines.TOLD["chip"])
	clear_log()
	var m := _memory
	var alone := bool(m.get("private", false))
	var played := bool(m.get("i_do", false))
	var second_name := String(m.get("second_name", ""))
	var vow_id := Lines.vow_id(cand, String(m.get("vow", "")))
	if alone:
		say("narration", Lines.PRIVATE_SCENE)
		say("them", _fill(Lines.PRIVATE.get(cand, "")), _name)
	else:
		say("narration", Lines.TOLD["day"] % [_place_name(), int(m.get("day", 1))])
		var guests: Array = m.get("guests", [])
		if not guests.is_empty():
			say("narration", Lines.TOLD["guests"] % ", ".join(PackedStringArray(guests)))
		if second_name != "":
			say("narration", Lines.TOLD["second"] % second_name)
		var did := Lines.their_road(cand, String(_road.get("task", "")))
		if played and did != "":
			say("them", did, _name)
	if String(m.get("their_vow", "")) != "":
		say("them", String(m["their_vow"]), _name)
	if String(m.get("vow", "")) != "":
		say("you", String(m["vow"]))
		if played and Lines.vow_answer(cand, vow_id) != "":
			say("them", Lines.vow_answer(cand, vow_id), _name)
	if alone:
		if played:
			say("them", String(Lines.PRIVATE_ASK.get(cand, "")), _name)
			say("you", Lines.I_DO)
			say("them", String(Lines.PRIVATE_ANSWER.get(cand, "")), _name)
	elif played:
		var steps := Lines.rite_steps(culture)
		say("narration", _fill(String(steps["intro"])))
		var ch := Lines.rite_choice(culture, String(m.get("rite", "")))
		if not ch.is_empty():
			say("narration", _fill(String(ch["line"])))
		if String(steps.get("after", "")) != "":
			say("narration", _fill(String(steps["after"])))
		say("them", String(Lines.ANSWER.get(cand, "")), _name)
		if bool(m.get("breath", false)):
			say("narration", Lines.TOLD["breath"] % String(Lines.BREATH_HER.get(cand, "")))
		say("you", Lines.I_DO)
		say("narration", _fill(String(Lines.SEAL.get(culture, ""))))
		for t in m.get("toasts", []):
			for line in t.get("lines", []):
				say("them", String(line.get("text", "")), String(line.get("speaker", "")))
	else:
		for line in Lines.rite(culture):
			say("narration", _fill(String(line)))
	if String(m.get("toast", "")) != "":
		say("you", String(m["toast"]))
	for id in m.get("dance", []):
		say("them", String(Feast.DANCE_ANSWERS.get(cand, {}).get(String(id), "")), _name)
	if String(m.get("custom", "")) != "":
		var c := Feast.custom_choice(culture, String(m["custom"]), second_name != "")
		if not c.is_empty():
			say("narration", Feast.fill(Lines.fill(String(c["line"]), {"name": _name}), {"second": second_name}))
	if String(m.get("last", "")) != "":
		say("them", String(Feast.LAST_ANSWER.get(cand, {}).get(String(m["last"]), "")), _name)
	add_to_log(keepsake(String(m.get("text", "")), "rings"))
	set_replies([{"id": "finish", "text": Lines.TOLD["close"], "tone": "quiet", "act": close}])


func _on_close() -> void:
	Sound.hush_music(false)
	Scenes.wedding_replay = ""
	GameState.save_game()
	Scenes.go(Scenes.wedding_return)
