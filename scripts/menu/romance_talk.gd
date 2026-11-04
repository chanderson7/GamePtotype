## Talking with someone you court or befriend, face to face in their room: one place for
## your story together (decisions, shown as decisions, with what they do), time spent
## together (visits, where every answer is welcome and nothing is scored), their letters,
## and the memories you share. Built on talk_view.gd; the rules stay in the social sim.
extends "res://scripts/ui/talk_view.gd"

const Relationships = preload("res://scripts/data/relationships.gd")
const RomanceStories = preload("res://scripts/data/romance_stories.gd")
const Stories = preload("res://scripts/data/personal_conversations.gd")
const Lines = preload("res://scripts/data/romance_talk_lines.gd")
const Letters = preload("res://scripts/data/letters.gd")

## Where each person is usually found.
const ROOMS := {"edda": "common_room", "farid": "envoy_room", "kaede": "archive_room"}
const CHAPTERS := 5

## How this screen was opened: "audience" (the story first) or "visits" (time together).
@export var opened_as := "audience"

var cand := "edda"
var person_id := ""
var _name := ""
var _scene_id := ""
var _progress := {}
var _replay := false
var _ch1_topic_done := false


func _ready() -> void:
	cand = Scenes.active_candidate_id if Scenes.active_candidate_id != "" else "edda"
	var social = _social()
	if social == null:
		setup(null, "")
		say("narration", "No one to talk to here.")
		set_replies([{"id": "leave", "text": "Back", "tone": "quiet", "act": close}])
		return
	if opened_as == "visits" and Scenes.active_person_id != "":
		for c in ROOMS:
			if String(social.get_candidate_person(c).get("id", "")) == Scenes.active_person_id:
				cand = c
	var person: Dictionary = social.get_candidate_person(cand)
	person_id = String(person.get("id", ""))
	_name = String(person.get("name", cand.capitalize()))
	setup(TalkView.room(String(ROOMS.get(cand, "common_room")), TalkView.time_word(GameState.world.hour)), _caption())
	set_face("left", _portrait(_expression()), false, 0.98)
	_refresh_plate()
	Sound.set_loop("camp")
	_hub(true)
	if Scenes.romance_relive != "":
		var sid := Scenes.romance_relive
		Scenes.romance_relive = ""
		if _social().personal_record(person_id)["completed"].has(sid):
			_visit(sid, true)


func _exit_tree() -> void:
	Sound.set_loop("")


const TalkView = preload("res://scripts/ui/talk_view.gd")


func _social():
	return GameState.world.social if GameState.world != null else null


func _rel() -> Dictionary:
	return _social().get_relationship(cand)


func _house() -> Dictionary:
	return _social().get_house(String(_social().get_candidate_person(cand).get("house_id", "")))


func _status() -> String:
	return String(_rel().get("status", Relationships.UNKNOWN))


func _chapter() -> int:
	return int(_social().get_quest("quest_%s" % cand).get("chapter", 1))


func _caption() -> String:
	var res := String(_social().get_candidate_person(cand).get("residence", ""))
	var place := Letters.place_name(res) if res != "" else ""
	return "With %s%s · %s" % [_name, (" at %s" % place) if place != "" else "", TalkView.time_word(GameState.world.hour)]


func _portrait(expression: String) -> Texture2D:
	var tex := StoryArt.texture("res://assets/portraits/%s_%s.png" % [cand, expression])
	return tex if tex != null else StoryArt.texture("res://assets/portraits/%s_neutral.png" % cand)


## How they look at you, by how things stand.
func _expression() -> String:
	var status := _status()
	if bool(_rel().get("strained", false)) or status == Relationships.ENDED:
		return "concerned"
	if int(_rel().get("trust", 0)) >= 50 or status in [Relationships.COURTING, Relationships.COMMITTED, Relationships.ENGAGED, Relationships.MARRIED]:
		return "warm"
	return "neutral" if status == Relationships.UNKNOWN else "thoughtful"


func _refresh_plate() -> void:
	var trust := int(_rel().get("trust", 0))
	var chips := [TalkView.plate_chip(Relationships.status_label(_status()), Color("e88aa0"), "heart")]
	chips.append(_trust_bar(trust))
	if bool(_rel().get("strained", false)):
		chips.append(TalkView.plate_chip("Strained: a broken promise", Style.ENEMY, "lock"))
	set_plate(_name, chips)


## Trust as a bar, marked where vows and a wedding open.
func _trust_bar(trust: int) -> Control:
	var box := PanelContainer.new()
	box.name = "TrustBar"
	var sb := Style.box(Color(Style.NIGHT, 0.85), Style.RULE, 2, 20)
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	box.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.add_child(Style.label("Trust %d" % trust, Style.SMALL, Style.TEXT))
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(120, 14)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.draw.connect(func():
		var r := Rect2(Vector2.ZERO, bar.size)
		bar.draw_rect(r, Color("1a1f33"))
		bar.draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(trust / 100.0, 0.0, 1.0), r.size.y)), Color("e88aa0"))
		var mark := r.size.x * Relationships.TRUST_PUBLIC_WEDDING / 100.0
		bar.draw_line(Vector2(mark, -2), Vector2(mark, r.size.y + 2), Style.BRASS, 2.0))
	h.add_child(bar)
	box.add_child(h)
	return box


func _after_change() -> void:
	_refresh_plate()
	change_face("left", _portrait(_expression()))


# ---------------------------------------------------------------- the hub

func _hub(first: bool = false) -> void:
	_scene_id = ""
	clear_log()
	say("them", Lines.greeting(cand, _status()) if first else "What else is on your mind?", _name)
	if bool(_rel().get("strained", false)):
		add_to_log(note("Things are strained between you since a broken promise. %s will hear you out on it." % _name, Style.MORALE_LOW))
	var replies := []
	# The story first.
	var ch := _chapter()
	var story: Dictionary = RomanceStories.story_data(cand)
	var cinfo: Dictionary = story.get("chapters", {}).get(ch, {})
	if not cinfo.is_empty() and _status() != Relationships.ENDED and not (ch >= CHAPTERS and _status() in [Relationships.MARRIED, Relationships.FRIENDSHIP]):
		replies.append({"id": "story", "text": "Our story · Chapter %d: %s" % [ch, cinfo.get("title", "")], "bare": true,
			"tag": "decisions · they change how things stand", "tone": "gold", "act": _story})
	# Time together.
	var visits: Array = _social().available_personal_conversations(person_id, GameState.personal_conversation_context())
	var record: Dictionary = _social().personal_record(person_id)
	var open := visits.filter(func(v): return bool(v.get("ok", false)) and not bool(v.get("replay", false)))
	var locked := visits.filter(func(v): return not bool(v.get("ok", false)))
	for v in open.slice(0, 3):
		var id := String(v["scene_id"])
		var resume: bool = record["in_progress"].has(id)
		replies.append({"id": "visit_" + id, "text": ("Resume: %s" if resume else "Spend time: %s") % Stories.SCENES[id]["title"], "bare": true,
			"tag": "in progress" if resume else "new · about 2 minutes · no wrong answers", "act": _visit.bind(id, false)})
	if open.is_empty() and not locked.is_empty():
		replies.append({"id": "visits_locked", "text": "%d more time%s together" % [locked.size(), "" if locked.size() == 1 else "s"], "bare": true,
			"tag": String(locked[0].get("reason", "not yet")), "tone": "locked"})
	# Their letters.
	for l in _social().letters:
		if String(l.get("sender_id", "")) == person_id and not bool(l.get("read", false)):
			var lid := String(l.get("id", ""))
			replies.append({"id": "letter", "text": "About your letter…", "tag": "read and answer it", "act": func():
				Scenes.people_letter = lid
				Scenes.go("res://scenes/people.tscn")})
			break
	if not _social().memory_book(person_id).is_empty():
		replies.append({"id": "remember", "text": "Remember when…", "tag": "your memories together", "act": _remember})
	replies.append({"id": "leave", "text": "Another time.", "tag": "leave", "act": close})
	set_replies(replies)


# ---------------------------------------------------------------- your story

func _story() -> void:
	var ch := _chapter()
	var cinfo: Dictionary = RomanceStories.story_data(cand).get("chapters", {}).get(ch, {})
	clear_log()
	_tell(String(cinfo.get("text", "")))
	var replies := []
	var strained := bool(_rel().get("strained", false))
	var repair: Dictionary = cinfo.get("repair", {})
	if strained and not repair.is_empty():
		replies.append(_decision(String(repair["id"]), String(repair["text"]), String(repair.get("response", ""))))
	match ch:
		1:
			if not _ch1_topic_done:
				add_to_log(note("Talk first; then say what you mean to be to %s." % _name, Style.MUTED))
				for c in cinfo.get("choices", []):
					var resp := String(c["response"])
					var said := String(c["text"])
					replies.append({"id": "topic_" + String(c["id"]), "text": said, "tag": "talk", "act": func():
						_ch1_topic_done = true
						say("you", said)
						say("them", _strip_quotes(resp), _name)
						_intents(cinfo)})
			else:
				_intents(cinfo)
				return
		2, 4:
			if ch == 4 and strained:
				pass
			else:
				for c in cinfo.get("choices", []):
					replies.append(_decision(String(c["id"]), String(c["text"]), String(c["response"])))
		3:
			for v in cinfo.get("variants", []):
				replies.append(_decision(String(v["id"]), "%s: %s" % [v["name"], v["text"]], String(v["response"])))
		5:
			if bool(_rel().get("romantic_intent", false)):
				replies.append(_decision("marry_public", "Marry me, before your house and everyone.", "%s accepts. Preparations begin for a public wedding." % _name))
				replies.append(_decision("marry_private", "Let's make our vows quietly, just us.", "In a quiet place, you and %s exchange vows." % _name))
			replies.append(_decision("friendship", "Let's swear friendship, and stand by each other's houses.", "You and %s make a lasting pledge of friendship." % _name))
			replies.append(_decision("remain_close", "Let's stay close, and let time decide.", "You agree to let time and quiet companionship guide what comes next."))
			replies.append(_decision("part_respectfully", "I think our roads part here.", "With respect and fond memories, you agree to walk separate paths."))
	replies.append({"id": "back", "text": "Not now.", "tone": "quiet", "act": _hub})
	set_replies(replies)


func _intents(cinfo: Dictionary) -> void:
	add_to_log(note(String(cinfo.get("intent_prompt", "What do you mean to be to each other?")), Style.BRASS))
	var replies := []
	for it in cinfo.get("intent_choices", []):
		replies.append(_decision(String(it["id"]), String(it["text"]), String(it["response"])))
	replies.append({"id": "back", "text": "Not now.", "tone": "quiet", "act": _hub})
	set_replies(replies)


## Narration and their words from a chapter's text: quoted passages are theirs.
func _tell(text: String) -> void:
	for para in text.split("\n\n", false):
		var p := String(para).strip_edges()
		if p.begins_with("'") or p.begins_with("\""):
			say("them", _strip_quotes(p), _name)
		else:
			say("narration", p)


static func _strip_quotes(s: String) -> String:
	var t := s.strip_edges()
	if (t.begins_with("'") and t.ends_with("'")) or (t.begins_with("\"") and t.ends_with("\"")):
		return t.substr(1, t.length() - 2)
	return t


## A story decision, marked as one, with what it does.
func _decision(choice_id: String, text: String, response: String) -> Dictionary:
	var prev: Dictionary = GameState.preview_social_choice(cand, choice_id)
	if not bool(prev.get("ok", false)):
		return {"id": "decide_" + choice_id, "text": text, "tag": String(prev.get("reason", "not now")), "tone": "locked"}
	return {"id": "decide_" + choice_id, "text": text, "tag": "Decision · " + _effects(prev), "tone": "gold",
		"act": _decide.bind(choice_id, text, response, prev)}


func _effects(prev: Dictionary) -> String:
	var bits := PackedStringArray()
	var t := int(prev.get("trust_change", 0))
	if t != 0:
		bits.append("%s%d trust" % ["+" if t > 0 else "", t])
	var st := int(prev.get("standing_change", 0))
	if st != 0:
		bits.append("%s%d house standing" % ["+" if st > 0 else "", st])
	if int(prev.get("cost_silver", 0)) > 0:
		bits.append("%d silver" % int(prev["cost_silver"]))
	if int(prev.get("cost_food", 0)) > 0:
		bits.append("%d rations" % int(prev["cost_food"]))
	var ns := String(prev.get("new_status", ""))
	if ns != "" and ns != _status():
		bits.append("now %s" % Relationships.status_label(ns).to_lower())
	return " · ".join(bits) if not bits.is_empty() else "it stays between you"


func _decide(choice_id: String, text: String, response: String, prev: Dictionary, confirmed: bool = false) -> void:
	if bool(prev.get("requires_confirmation", false)) and not confirmed:
		say("you", text)
		add_to_log(note(String(prev.get("confirmation_text", "Are you sure?")), Style.BRASS))
		set_replies([
			{"id": "confirm", "text": "Yes. I mean it.", "tag": "Decision · " + _effects(prev), "tone": "gold", "act": _decide.bind(choice_id, text, response, prev, true)},
			{"id": "back", "text": "Not yet.", "tone": "quiet", "act": _story}])
		return
	var res: Dictionary = GameState.apply_social_choice(cand, choice_id)
	if not bool(res.get("ok", false)):
		add_to_log(note(String(res.get("reason", "That can't be done now.")), Style.MORALE_LOW))
		return
	if not confirmed:
		say("you", text)
	say("them", _strip_quotes(response), _name)
	add_to_log(note(_effects(prev).capitalize() + ".", Style.MORALE_HIGH if int(prev.get("trust_change", 0)) >= 0 else Style.MORALE_LOW))
	_ch1_topic_done = false
	_after_change()
	set_replies([{"id": "back", "text": "Something else.", "tone": "quiet", "act": _hub},
		{"id": "leave", "text": "Another time.", "tag": "leave", "act": close}])


# ---------------------------------------------------------------- time together

func _visit(scene_id: String, replay: bool) -> void:
	_replay = replay
	_scene_id = scene_id
	if replay:
		var rec: Dictionary = _social().personal_record(person_id)
		_progress = {"node": 0, "choice": -1, "context": rec["completed"][scene_id]["context"].duplicate(true)}
		Stories.normalize_reader(scene_id, _progress)
	else:
		var r: Dictionary = GameState.personal_conversation_action(person_id, scene_id, "begin")
		if not bool(r.get("ok", false)):
			add_to_log(note(String(r.get("reason", "Not now.")), Style.MORALE_LOW))
			return
		_progress = r["progress"]
	var setting := String(Stories.SCENES[scene_id].get("setting", ROOMS.get(cand, "common_room")))
	if _backdrop is TextureRect and StoryArt.texture("res://assets/locations/%s.png" % setting) != null:
		(_backdrop as TextureRect).texture = StoryArt.texture("res://assets/locations/%s.png" % setting)
	_render_visit()


func _sequence() -> Array:
	return Stories.beats(_scene_id, int(_progress["node"]), int(_progress["choice"]), _progress["context"])


func _render_visit() -> void:
	clear_log()
	var scene: Dictionary = Stories.SCENES[_scene_id]
	say("narration", ("Remembered · %s" if _replay else "%s") % scene["title"])
	var shown := []
	if int(_progress["node"]) == 1:
		shown.append_array(Stories.beats(_scene_id, 0, -1, _progress["context"]))
	var seq := _sequence()
	shown.append_array(seq.slice(0, int(_progress["beat"]) + 1))
	var face := ""
	for beat in shown:
		var who := String(beat["speaker"])
		if who == "Narrator":
			say("narration", String(beat["text"]))
		elif who == "You":
			say("you", String(beat["text"]))
		else:
			say("them", String(beat["text"]), _name)
			face = String(beat.get("expression", face))
	if face != "":
		change_face("left", _portrait(face))
	var pos := int(_progress["beat"])
	var quiet := [{"id": "summary", "text": "Short version", "tone": "quiet", "act": _summary}] if not _replay else []
	if pos < seq.size() - 1:
		var replies := [{"id": "continue", "text": "Continue", "tone": "quiet", "act": _advance}]
		replies.append_array(quiet)
		replies.append({"id": "later", "text": "Another time", "tone": "quiet", "act": _hub})
		set_replies(replies)
		_continue = _advance
	elif int(_progress["node"]) == 0:
		add_to_log(note("No wrong answers.", Style.MUTED))
		var replies := []
		for i in scene["choices"].size():
			replies.append({"id": "say_%d" % i, "text": String(scene["choices"][i]), "act": _respond.bind(i)})
		replies.append_array(quiet)
		set_replies(replies)
	elif _replay:
		set_replies([{"id": "finish", "text": "Close the memory", "tone": "quiet", "act": _hub}])
	else:
		set_replies([{"id": "finish", "text": "Keep this memory", "tone": "gold", "bare": true, "act": _finish.bind("finish")}])


func _advance() -> void:
	if _replay:
		_progress["beat"] = mini(int(_progress["beat"]) + 1, _sequence().size() - 1)
	else:
		var r: Dictionary = GameState.personal_conversation_action(person_id, _scene_id, "advance")
		if not bool(r.get("ok", false)):
			return
		_progress = r["progress"]
	_render_visit()


func _respond(choice: int) -> void:
	if _replay:
		_progress["choice"] = choice
		_progress["node"] = 1
		_progress["beat"] = 0
	else:
		var r: Dictionary = GameState.personal_conversation_action(person_id, _scene_id, "choose", choice)
		if not bool(r.get("ok", false)):
			return
		_progress = r["progress"]
	_render_visit()


func _summary() -> void:
	clear_log()
	say("narration", String(Stories.SCENES[_scene_id]["summary"]))
	_finish("summary")


func _finish(action: String) -> void:
	var scene: Dictionary = Stories.SCENES[_scene_id]
	var r: Dictionary = GameState.personal_conversation_action(person_id, _scene_id, action)
	if not bool(r.get("ok", false)):
		add_to_log(note(String(r.get("reason", "Not now.")), Style.MORALE_LOW))
		return
	var claims: int = _social().personal_record(person_id)["bonus_claims"].size()
	var line := "A memory kept: %s" % scene["memory"]
	if int(r.get("trust_change", 0)) > 0:
		line += "\nTime together: +%d trust (%d of %d)." % [int(r["trust_change"]), claims, Relationships.PERSONAL_CONVERSATION_CAP]
	add_to_log(_keepsake(line))
	_after_change()
	set_replies([{"id": "back", "text": "Something else.", "tone": "quiet", "act": _hub},
		{"id": "leave", "text": "Another time.", "tag": "leave", "act": close}])


func _keepsake(text: String) -> Control:
	var p := PanelContainer.new()
	p.name = "Keepsake"
	p.add_theme_stylebox_override("panel", Style.box(Color("2a1f26"), Color("e88aa0"), 2, 14))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.add_child(Widgets.icon_rect("cup", 36))
	var l := Style.label(text, Style.SMALL, Style.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	p.add_child(h)
	if not Style.motion_reduced():
		p.modulate.a = 0.0
		p.create_tween().tween_property(p, "modulate:a", 1.0, 0.3)
	return p


# ---------------------------------------------------------------- remembering

func _remember() -> void:
	clear_log()
	say("you", "Remember when…")
	say("them", "Which time?", _name)
	var replies := []
	var book: Array = _social().memory_book(person_id)
	book.reverse()
	for m in book.slice(0, 6):
		var when := ("Day %d" % int(m["day"])) if int(m.get("day", 0)) > 0 else ""
		replies.append({"id": "memory_" + String(m["id"]), "text": String(m["text"]), "bare": true, "tag": when, "act": _recall.bind(m)})
	replies.append({"id": "back", "text": "Something else.", "tone": "quiet", "act": _hub})
	set_replies(replies)


func _recall(m: Dictionary) -> void:
	clear_log()
	say("narration", String(m["text"]))
	say("them", Lines.callback(m), _name)
	var replies := []
	var sid := String(m.get("scene_id", ""))
	if String(m.get("kind", "")) == "visit" and _social().personal_record(person_id)["completed"].has(sid):
		replies.append({"id": "relive", "text": "Tell it again", "bare": true, "tag": "a memory · changes nothing", "act": _visit.bind(sid, true)})
	replies.append({"id": "more", "text": "Remember something else.", "tone": "quiet", "act": _remember})
	replies.append({"id": "back", "text": "Something else.", "tone": "quiet", "act": _hub})
	set_replies(replies)


func _on_close() -> void:
	Scenes.go(Scenes.personal_conversation_return if opened_as == "visits" else Scenes.conversation_return)
